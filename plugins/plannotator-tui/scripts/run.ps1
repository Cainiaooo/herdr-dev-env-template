# Launch the bundled plannotator-tui.exe. Herdr Windows pane spawn does not
# resolve plugin-relative programs, so the manifest uses HERDR_PLUGIN_ROOT.
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Mode
)

$ErrorActionPreference = 'Stop'

$root = $env:HERDR_PLUGIN_ROOT
if (-not $root) { Write-Error 'HERDR_PLUGIN_ROOT is missing'; exit 69 }
if ($root.StartsWith('\\?\')) { $root = $root.Substring(4) }

$exe = Join-Path $root 'bin\plannotator-tui.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    $msg = 'plannotator-tui is not installed. From herdr-dev-env: powershell -File plugins/plannotator-tui/scripts/fetch.ps1'
    [Console]::Error.WriteLine($msg)
    if ($env:HERDR_BIN_PATH) {
        & $env:HERDR_BIN_PATH notification show 'Annotate: review pane unavailable' --body $msg 2>$null | Out-Null
    }
    exit 1
}

if ($Mode -eq 'last') {
    # Do not call `plannotator-tui herdr last` on Windows: process names are
    # grok.exe/codex.exe, the binary then defaults to Claude Code.
    & (Join-Path $PSScriptRoot 'last.ps1')
    exit $LASTEXITCODE
}

$subcommand = switch ($Mode) {
    'pane' { @('herdr', 'pane') }
    'open' {
        # prefix+o / Ctrl-click. Narrow source-tree cwd to docs/ when we can;
        # the TUI skip list is compiled in and this shim cannot extend it.
        . (Join-Path $PSScriptRoot 'open.ps1')
        $target = Resolve-PlannotatorOpenPathFromEnv
        Show-PlannotatorFolderSendWarning $target
        @('herdr', 'open', $target)
    }
    default { throw "unknown mode $Mode (expected pane, open, last)" }
}

& $exe @subcommand
exit $LASTEXITCODE
