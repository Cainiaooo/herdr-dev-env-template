param(
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$repoRoot = Split-Path -Parent $PSScriptRoot
$tuiSource = Join-Path $repoRoot 'plugins\plannotator-tui\skills\plannotator-tui'
$skillRoots = @(
    (Join-Path $env:USERPROFILE '.agents\skills'),
    (Join-Path $env:USERPROFILE '.claude\skills')
)
$skillNames = @(
    'plannotator',
    'plannotator-review',
    'plannotator-annotate',
    'plannotator-last',
    'plannotator-tui'
)

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    if ($WhatIf) {
        Write-Host "Would update $Path"
        return
    }
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Updated $Path"
}

function Set-ExplicitFrontmatter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillFile
    )

    if (-not (Test-Path -LiteralPath $SkillFile)) {
        Write-Warning "Skill not installed: $SkillFile"
        return
    }

    $content = [System.IO.File]::ReadAllText($SkillFile)
    $frontmatter = [regex]::Match($content, '\A---\r?\n(?<body>.*?)\r?\n---', 'Singleline')
    if (-not $frontmatter.Success) {
        throw "Invalid SKILL.md frontmatter: $SkillFile"
    }

    if ($frontmatter.Groups['body'].Value -match '(?m)^disable-model-invocation:\s*true\s*$') {
        Write-Host "Already explicit: $SkillFile"
        return
    }

    $newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $updatedBody = $frontmatter.Groups['body'].Value + $newline + 'disable-model-invocation: true'
    $updated = $content.Substring(0, $frontmatter.Groups['body'].Index) +
        $updatedBody +
        $content.Substring($frontmatter.Groups['body'].Index + $frontmatter.Groups['body'].Length)
    Write-Utf8NoBom -Path $SkillFile -Content $updated
}

function Set-OpenAiExplicitPolicy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillDirectory
    )

    $metadataFile = Join-Path $SkillDirectory 'agents\openai.yaml'
    if (-not (Test-Path -LiteralPath $metadataFile)) {
        return
    }

    $content = [System.IO.File]::ReadAllText($metadataFile)
    if ($content -notmatch '(?m)^\s*allow_implicit_invocation:\s*(true|false)\s*$') {
        throw "Missing allow_implicit_invocation policy: $metadataFile"
    }

    $updated = [regex]::Replace(
        $content,
        '(?m)^(\s*allow_implicit_invocation:\s*)true(\s*)$',
        '${1}false${2}'
    )
    if ($updated -eq $content) {
        Write-Host "Already explicit: $metadataFile"
        return
    }
    Write-Utf8NoBom -Path $metadataFile -Content $updated
}

if (-not (Test-Path -LiteralPath $tuiSource)) {
    throw "Repository TUI skill is missing: $tuiSource"
}

foreach ($skillRoot in $skillRoots) {
    $tuiDestination = Join-Path $skillRoot 'plannotator-tui'
    if ($WhatIf) {
        Write-Host "Would sync $tuiSource to $tuiDestination"
    } else {
        New-Item -ItemType Directory -Path $tuiDestination -Force | Out-Null
        Get-ChildItem -LiteralPath $tuiSource -Force |
            Copy-Item -Destination $tuiDestination -Recurse -Force
        Write-Host "Synced $tuiDestination"
    }

    foreach ($skillName in $skillNames) {
        $skillDirectory = Join-Path $skillRoot $skillName
        Set-ExplicitFrontmatter -SkillFile (Join-Path $skillDirectory 'SKILL.md')
        Set-OpenAiExplicitPolicy -SkillDirectory $skillDirectory
    }
}

Write-Host 'All installed Notator skills are explicit-only.'
