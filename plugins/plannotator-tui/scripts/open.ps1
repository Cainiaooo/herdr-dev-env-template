# Choose the folder/file `plannotator-tui herdr open` should receive.
#
# The TUI walker is a compiled skip list (node_modules/target/…); this shim cannot
# add names to it. What we can do: on prefix+o, if the focused pane cwd looks like a
# source tree (Engine/src/node_modules/…) and a docs-like subfolder exists, open that
# subfolder instead of the whole repo. Ctrl-clicked files and explicit paths pass through.

$script:PreferDirs = @(
    'docs', 'documentation', 'doc', 'plans', 'plan', 'specs', 'spec'
)

# Presence of any of these (case-insensitive) means "code repo, not a docs folder".
$script:SourceTreeMarkers = @(
    'src', 'source', 'lib', 'pkg', 'crates', 'cmd', 'app', 'internal',
    'engine', 'content', 'intermediate', 'binaries', 'deriveddatacache', 'saved',
    'node_modules', 'target', 'vendor', 'packages', 'third_party', 'thirdparty'
)

function ConvertFrom-PlannotatorFileUri {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }
    try {
        $uri = [Uri]$Url
        if ($uri.Scheme -ne 'file') { return $null }
        return $uri.LocalPath
    } catch {
        return $null
    }
}

function Test-PlannotatorMarkdownFile {
    param([string]$Path)
    if (-not $Path) { return $false }
    $ext = [System.IO.Path]::GetExtension($Path)
    if (-not $ext) { return $false }
    return $ext.TrimStart('.').ToLowerInvariant() -in @('md', 'markdown', 'mdx')
}

function Test-PlannotatorTopLevelMarkdown {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $false }
    $files = Get-ChildItem -LiteralPath $Dir -File -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        if (Test-PlannotatorMarkdownFile $f.FullName) { return $true }
    }
    return $false
}

function Test-PlannotatorSourceTree {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $false }
    foreach ($name in $script:SourceTreeMarkers) {
        $candidate = Join-Path $Dir $name
        if (Test-Path -LiteralPath $candidate -PathType Container) { return $true }
    }
    return $false
}

function Get-PlannotatorPreferredDocsDir {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $null }
    $children = @(Get-ChildItem -LiteralPath $Dir -Directory -ErrorAction SilentlyContinue)
    foreach ($want in $script:PreferDirs) {
        foreach ($child in $children) {
            if ($child.Name.ToLowerInvariant() -eq $want) {
                return $child.FullName
            }
        }
    }
    return $null
}

# File stays a file. A source-tree folder with docs/plans/… is narrowed to that
# subfolder so the TUI's first-file BFS never list()s Engine/Intermediate/node_modules.
function Select-PlannotatorOpenTarget {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full -PathType Leaf) {
        return $full
    }
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        return $full
    }
    if (-not (Test-PlannotatorSourceTree $full)) {
        return $full
    }
    $preferred = Get-PlannotatorPreferredDocsDir $full
    if ($preferred) { return $preferred }
    return $full
}

function Resolve-PlannotatorOpenPath {
    param(
        [string]$ClickedUrl,
        [string]$FocusedCwd,
        [string]$WorkspaceCwd,
        [string]$ProcessCwd = (Get-Location).Path
    )
    $raw = $null
    if ($ClickedUrl) {
        $raw = ConvertFrom-PlannotatorFileUri $ClickedUrl
    }
    if (-not $raw -and $FocusedCwd) { $raw = $FocusedCwd }
    if (-not $raw -and $WorkspaceCwd) { $raw = $WorkspaceCwd }
    if (-not $raw) { $raw = $ProcessCwd }

    if (-not [System.IO.Path]::IsPathRooted($raw)) {
        $raw = Join-Path $ProcessCwd $raw
    }
    return Select-PlannotatorOpenTarget $raw
}

function Resolve-PlannotatorOpenPathFromEnv {
    $clicked = $null
    $focused = $null
    $workspace = $null
    if ($env:HERDR_PLUGIN_CONTEXT_JSON) {
        try {
            $ctx = $env:HERDR_PLUGIN_CONTEXT_JSON | ConvertFrom-Json
            if ($ctx.clicked_url) { $clicked = [string]$ctx.clicked_url }
            if ($ctx.focused_pane_cwd) { $focused = [string]$ctx.focused_pane_cwd }
            if ($ctx.workspace_cwd) { $workspace = [string]$ctx.workspace_cwd }
        } catch {
            # Fall through to process cwd.
        }
    }
    return Resolve-PlannotatorOpenPath -ClickedUrl $clicked -FocusedCwd $focused -WorkspaceCwd $workspace
}

function Invoke-PlannotatorOpenSelfTest {
    $root = Join-Path $env:TEMP ("plannotator-tui-open-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $script:OpenSelfTestFailed = 0
    function Assert-Eq($got, $want, $label) {
        if ($got -ne $want) {
            Write-Host "FAIL $label`n  got:  $got`n  want: $want"
            $script:OpenSelfTestFailed++
        }
    }
    try {
        $docsOnly = Join-Path $root 'docs-only'
        New-Item -ItemType Directory -Force -Path (Join-Path $docsOnly 'docs') | Out-Null
        Set-Content -Encoding utf8 (Join-Path $docsOnly 'README.md') '# r'
        Set-Content -Encoding utf8 (Join-Path (Join-Path $docsOnly 'docs') 'plan.md') '# p'
        Assert-Eq (Select-PlannotatorOpenTarget $docsOnly) ([System.IO.Path]::GetFullPath($docsOnly)) 'docs-only repo stays at root'

        $srcTree = Join-Path $root 'src-tree'
        New-Item -ItemType Directory -Force -Path (Join-Path $srcTree 'src') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $srcTree 'docs') | Out-Null
        Set-Content -Encoding utf8 (Join-Path $srcTree 'README.md') '# r'
        Set-Content -Encoding utf8 (Join-Path (Join-Path $srcTree 'docs') 'plan.md') '# p'
        Assert-Eq (Select-PlannotatorOpenTarget $srcTree) ([System.IO.Path]::GetFullPath((Join-Path $srcTree 'docs'))) 'src+docs prefers docs'

        $ue = Join-Path $root 'ue'
        New-Item -ItemType Directory -Force -Path (Join-Path $ue 'Engine') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $ue 'Intermediate') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $ue 'documentation') | Out-Null
        Set-Content -Encoding utf8 (Join-Path (Join-Path $ue 'documentation') 'api.md') '# a'
        Assert-Eq (Select-PlannotatorOpenTarget $ue) ([System.IO.Path]::GetFullPath((Join-Path $ue 'documentation'))) 'UE tree prefers documentation'

        $fat = Join-Path $root 'fat-no-docs'
        New-Item -ItemType Directory -Force -Path (Join-Path $fat 'Engine') | Out-Null
        Assert-Eq (Select-PlannotatorOpenTarget $fat) ([System.IO.Path]::GetFullPath($fat)) 'source tree without docs stays at root'

        $md = Join-Path $srcTree 'README.md'
        Assert-Eq (Select-PlannotatorOpenTarget $md) ([System.IO.Path]::GetFullPath($md)) 'file path is unchanged'

        $clicked = ([Uri](Join-Path $srcTree 'README.md')).AbsoluteUri
        $got = Resolve-PlannotatorOpenPath -ClickedUrl $clicked -FocusedCwd $srcTree
        Assert-Eq $got ([System.IO.Path]::GetFullPath($md)) 'clicked file:// wins over pane cwd'

        $got = Resolve-PlannotatorOpenPath -FocusedCwd $srcTree
        Assert-Eq $got ([System.IO.Path]::GetFullPath((Join-Path $srcTree 'docs'))) 'prefix+o on source tree uses docs'
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($script:OpenSelfTestFailed -gt 0) {
        throw "$($script:OpenSelfTestFailed) open.ps1 self-test(s) failed"
    }
    Write-Host 'open.ps1 self-test ok'
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($args -contains '-SelfTest') {
        Invoke-PlannotatorOpenSelfTest
    }
}
