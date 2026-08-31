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

# Matches plannotator-tui-schema sanitize_tag / project_name so leftover records
# are looked up under the same <project> folder the TUI uses.
function Get-PlannotatorSanitizeTag {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $out = [System.Text.StringBuilder]::new()
    $pending = $false
    foreach ($ch in $Name.ToLowerInvariant().Trim().ToCharArray()) {
        $c = $ch
        if ([char]::IsWhiteSpace($c) -or $c -eq '_') { $c = [char]'-' }
        if ($c -eq '-') {
            $pending = $true
        } elseif ($c -ge 'a' -and $c -le 'z' -or ($c -ge '0' -and $c -le '9')) {
            if ($pending -and $out.Length -gt 0) { [void]$out.Append('-') }
            $pending = $false
            [void]$out.Append($c)
        }
    }
    $s = $out.ToString()
    if ($s.Length -gt 30) { $s = $s.Substring(0, 30) }
    $s = $s.Trim('-')
    if ($s.Length -lt 2) { return $null }
    return $s
}

function Get-PlannotatorGitToplevel {
    param([string]$Folder)
    try {
        $git = & git -C $Folder rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $git) { return $git.Trim() }
    } catch {
        return $null
    }
    return $null
}

function Get-PlannotatorProjectName {
    param([string]$Folder)
    $git = Get-PlannotatorGitToplevel $Folder
    $base = $null
    if ($git) {
        $base = Split-Path -Leaf $git
    }
    if (-not $base) {
        $base = Split-Path -Leaf $Folder
    }
    $tag = Get-PlannotatorSanitizeTag $base
    if ($tag) { return $tag }
    return '_unknown'
}

function Format-PlannotatorRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )
    $full = [System.IO.Path]::GetFullPath($Path)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $prefix = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    if ($full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($prefix.Length)
    }
    if ($full.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return '.'
    }
    return $full
}

function Get-PlannotatorDataDir {
    $explicit = $env:PLANNOTATOR_DATA_DIR
    if ($explicit) {
        $explicit = $explicit.Trim()
        if ($explicit -eq '~') { return $env:USERPROFILE }
        if ($explicit.StartsWith('~/') -or $explicit.StartsWith('~\')) {
            return Join-Path $env:USERPROFILE $explicit.Substring(2)
        }
        return $explicit
    }
    return Join-Path $env:USERPROFILE '.plannotator'
}

# Records with a non-empty annotations array. Folder-mode Send dumps all of these
# for the git project, even when the tree shows 0 and collapsed dirs have no badge.
function Get-PlannotatorLeftoverAnnotationFiles {
    param(
        [Parameter(Mandatory = $true)][string]$Project,
        [string]$DataDir = (Get-PlannotatorDataDir)
    )
    $root = Join-Path $DataDir "clients\plannotator-tui\annotations\$Project"
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return @() }
    $found = [System.Collections.Generic.List[string]]::new()
    $records = Get-ChildItem -LiteralPath $root -Recurse -Filter 'annotations.json' -File -ErrorAction SilentlyContinue
    foreach ($file in $records) {
        try {
            $rec = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8 | ConvertFrom-Json
        } catch {
            continue
        }
        $n = @($rec.annotations).Count
        if ($n -le 0) { continue }
        if ($rec.path) {
            $found.Add([string]$rec.path)
        } else {
            $found.Add($file.Directory.Name)
        }
    }
    return @($found)
}

function Get-PlannotatorHerdrBin {
    $bin = $env:HERDR_BIN_PATH
    if ($bin -and $bin.StartsWith('\\?\')) { $bin = $bin.Substring(4) }
    if ($bin -and (Test-Path -LiteralPath $bin)) { return $bin }
    return 'herdr'
}

function Show-PlannotatorFolderSendWarning {
    param([Parameter(Mandatory = $true)][string]$Target)
    if (-not (Test-Path -LiteralPath $Target -PathType Container)) { return }
    $project = Get-PlannotatorProjectName $Target
    $files = @(Get-PlannotatorLeftoverAnnotationFiles -Project $project)
    if ($files.Count -eq 0) { return }
    $repo = Get-PlannotatorGitToplevel $Target
    if (-not $repo) { $repo = $Target }
    $limit = 12
    $rels = @(
        $files | ForEach-Object { Format-PlannotatorRelativePath -Path $_ -Root $repo } | Sort-Object -Unique
    )
    $shownPaths = $rels | Select-Object -First $limit
    $extra = $rels.Count - $shownPaths.Count
    $list = ($shownPaths -join "`n")
    if ($extra -gt 0) { $list = "$list`n… and $extra more" }
    $title = 'TUI leftover comments will be sent'
    $body = @"
Repo $project still has $($rels.Count) markdown file(s) with TUI comments (paths relative to repo root):

$list

Folder Send includes them even if the tree shows 0 and collapsed folders have no badge.

Open a single file to send only that file, or press x on the old comments first.
"@
    $bin = Get-PlannotatorHerdrBin
    $toastShown = $false
    try {
        $raw = & $bin notification show $title --body $body --sound request 2>&1 | Out-String
        if ($raw -match '"shown"\s*:\s*true') { $toastShown = $true }
    } catch {
        $toastShown = $false
    }
    # This machine keeps [ui.toast] delivery = off, so notification.show is a no-op.
    # Fall back to a dialog. When toast is later enabled, skip the dialog.
    if (-not $toastShown) {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show(
            $body,
            $title,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
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

        Assert-Eq (Get-PlannotatorSanitizeTag 'My Repo_Name!') 'my-repo-name' 'sanitize tag'
        Assert-Eq (Get-PlannotatorSanitizeTag 'x') $null 'sanitize too short'

        $relRoot = Join-Path $root 'rel'
        New-Item -ItemType Directory -Force -Path (Join-Path $relRoot 'plugins\plannotator-tui\skills') | Out-Null
        $relFile = Join-Path $relRoot 'plugins\plannotator-tui\skills\SKILL.md'
        Set-Content -Encoding utf8 $relFile '# s'
        Assert-Eq (Format-PlannotatorRelativePath $relFile $relRoot) 'plugins\plannotator-tui\skills\SKILL.md' 'relative leftover path'

        $data = Join-Path $root 'data'
        $recDir = Join-Path $data 'clients\plannotator-tui\annotations\demo\annotate-plan-md-deadbeef'
        New-Item -ItemType Directory -Force -Path $recDir | Out-Null
        '{"path":"D:\\work\\demo\\docs\\plan.md","annotations":[{"id":"local_1"}],"deliveries":[]}' |
            Set-Content -Encoding utf8 (Join-Path $recDir 'annotations.json')
        $emptyDir = Join-Path $data 'clients\plannotator-tui\annotations\demo\annotate-old-md-cafebabe'
        New-Item -ItemType Directory -Force -Path $emptyDir | Out-Null
        '{"path":"D:\\work\\demo\\docs\\old.md","annotations":[],"deliveries":[]}' |
            Set-Content -Encoding utf8 (Join-Path $emptyDir 'annotations.json')
        $left = @(Get-PlannotatorLeftoverAnnotationFiles -Project 'demo' -DataDir $data)
        Assert-Eq $left.Count 1 'leftover count ignores empty records'
        Assert-Eq $left[0] 'D:\work\demo\docs\plan.md' 'leftover path'
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
