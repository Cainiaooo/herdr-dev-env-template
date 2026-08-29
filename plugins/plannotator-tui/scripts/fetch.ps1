# Download the pinned plannotator-tui Windows binary into bin/ and onto PATH.
# Herdr runs this as a plugin build step (cwd = plugin root).
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if ($env:HERDR_PLUGIN_ROOT) {
    $root = $env:HERDR_PLUGIN_ROOT
    if ($root.StartsWith('\\?\')) { $root = $root.Substring(4) }
}

$versionFile = Join-Path $root 'plannotator-tui.version'
$version = (Get-Content -Raw $versionFile).Trim()
if (-not $version) { throw 'plannotator-tui.version is empty' }

$binDir = Join-Path $root 'bin'
New-Item -ItemType Directory -Force -Path $binDir | Out-Null
$dest = Join-Path $binDir 'plannotator-tui.exe'
$stamp = Join-Path $binDir 'plannotator-tui.version'

$asset = 'plannotator-tui-x86_64-pc-windows-msvc.exe'
$pathCopy = Join-Path $env:LOCALAPPDATA 'plannotator\plannotator-tui.exe'

if ($env:PLANNOTATOR_TUI_BIN) {
    if (-not (Test-Path -LiteralPath $env:PLANNOTATOR_TUI_BIN)) {
        throw "PLANNOTATOR_TUI_BIN is not a file: $($env:PLANNOTATOR_TUI_BIN)"
    }
    Copy-Item -LiteralPath $env:PLANNOTATOR_TUI_BIN -Destination $dest -Force
    Set-Content -LiteralPath $stamp -Value $version -NoNewline
    Write-Host "installed plannotator-tui from $env:PLANNOTATOR_TUI_BIN (stamped $version)"
} elseif ((Test-Path -LiteralPath $dest) -and (Test-Path -LiteralPath $stamp) -and ((Get-Content -Raw $stamp).Trim() -eq $version)) {
    Write-Host "plannotator-tui $version already installed"
} else {
    $base = "https://github.com/plannotator/plannotator-tui/releases/download/v$version"
    $tmp = Join-Path $env:TEMP "plannotator-tui-$version-$PID"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $assetPath = Join-Path $tmp $asset
        $sumsPath = Join-Path $tmp 'SHA256SUMS'
        Write-Host "downloading $base/$asset"
        & curl.exe -fsSL --retry 3 -o $assetPath "$base/$asset"
        if ($LASTEXITCODE -ne 0) { throw "download failed: $base/$asset" }
        & curl.exe -fsSL --retry 3 -o $sumsPath "$base/SHA256SUMS"
        if ($LASTEXITCODE -ne 0) { throw "download failed: $base/SHA256SUMS" }

        $expected = $null
        foreach ($line in Get-Content $sumsPath) {
            if ($line -match ('^[0-9a-fA-F]{64}\s+' + [regex]::Escape($asset) + '\s*$')) {
                $expected = ($line -split '\s+')[0].ToLowerInvariant()
                break
            }
        }
        if (-not $expected) { throw "$asset is not listed in SHA256SUMS" }

        $actual = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) {
            throw "sha256 mismatch for ${asset}: expected ${expected}, got ${actual}"
        }

        Copy-Item -LiteralPath $assetPath -Destination $dest -Force
        Set-Content -LiteralPath $stamp -Value $version -NoNewline
        Write-Host "installed plannotator-tui $version ($asset)"
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$pathDir = Split-Path -Parent $pathCopy
if (Test-Path -LiteralPath $pathDir) {
    Copy-Item -LiteralPath $dest -Destination $pathCopy -Force
    Write-Host "copied to $pathCopy (already on user PATH)"
}
