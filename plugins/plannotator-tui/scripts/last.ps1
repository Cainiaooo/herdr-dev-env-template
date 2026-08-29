# Windows last-message launcher.
#
# Upstream `plannotator-tui herdr last` takes the process name as PLANNOTATOR_TUI_HOST.
# On Windows that name is `grok.exe` / `codex.exe` / `cursor-agent.cmd`. detect_host()
# does not strip extensions, does not know Grok or Cursor, and then defaults to
# Claude Code — which opens some other repo's ~/.claude/projects transcript.
#
# This script strips .exe/.cmd, reads Grok and Cursor session files, and only then
# hands Claude/Codex/pi/copilot/droid to upstream last. `agent` is Cursor's CLI
# alias; Grok also ships agent.exe — pane.agent from Herdr decides.

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function ConvertFrom-JsonDeep([string]$Json) {
    Add-Type -AssemblyName System.Web.Extensions
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $ser.MaxJsonLength = [int]::MaxValue
    return $ser.DeserializeObject($Json)
}

function Get-Prop($Obj, [string[]]$Path) {
    $cur = $Obj
    foreach ($p in $Path) {
        if ($null -eq $cur) { return $null }
        if ($cur -is [System.Collections.IDictionary]) {
            if (-not $cur.ContainsKey($p)) { return $null }
            $cur = $cur[$p]
        } else {
            return $null
        }
    }
    return $cur
}

function Get-HerdrBin {
    if ($env:HERDR_BIN_PATH -and (Test-Path -LiteralPath $env:HERDR_BIN_PATH)) {
        return $env:HERDR_BIN_PATH
    }
    return 'herdr'
}

function Invoke-HerdrJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$HerdrArgs
    )
    $bin = Get-HerdrBin
    $raw = & $bin @HerdrArgs 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "herdr $($HerdrArgs -join ' ') failed: $raw"
    }
    return ConvertFrom-JsonDeep $raw
}

function Normalize-HostName([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { return '' }
    $n = $Name.Trim().ToLowerInvariant()
    $n = [System.IO.Path]::GetFileName($n)
    foreach ($ext in @('.exe', '.cmd', '.bat', '.ps1')) {
        if ($n.EndsWith($ext)) {
            $n = $n.Substring(0, $n.Length - $ext.Length)
            break
        }
    }
    return $n
}

function Get-FocusedPaneId {
    if ($env:HERDR_PLUGIN_CONTEXT_JSON) {
        $ctx = ConvertFrom-JsonDeep $env:HERDR_PLUGIN_CONTEXT_JSON
        $id = Get-Prop $ctx @('focused_pane_id')
        if ($id) { return [string]$id }
    }
    if ($env:HERDR_PANE_ID) { return $env:HERDR_PANE_ID }
    throw 'no focused pane: click the agent pane, then Ctrl+B Shift+O'
}

function Get-BinaryHost([string]$Name) {
    switch (Normalize-HostName $Name) {
        'claude' { 'claude' }
        'claude-code' { 'claude' }
        'codex' { 'codex' }
        'pi' { 'pi' }
        'copilot' { 'copilot' }
        'copilot-cli' { 'copilot' }
        'droid' { 'droid' }
        'factory' { 'droid' }
        default { $null }
    }
}

function Test-GrokName([string]$Name) {
    return ((Normalize-HostName $Name) -eq 'grok')
}

function Test-CursorName([string]$Name) {
    switch (Normalize-HostName $Name) {
        'cursor' { $true }
        'cursor-agent' { $true }
        'agent' { $true }
        default { $false }
    }
}

# Herdr labels Cursor Agent CLI as `cursor`. The process is `cursor-agent` or the
# `agent` alias. Grok also ships `~\.grok\bin\agent.exe` — never treat `agent` as
# Cursor when the pane is already detected as grok.
function Resolve-LastKind {
    param(
        [string]$PaneAgent,
        [string]$ProcName
    )
    $pane = Normalize-HostName $PaneAgent
    $proc = Normalize-HostName $ProcName
    if (Test-GrokName $pane) { return 'grok' }
    if ($pane -eq 'cursor') { return 'cursor' }
    $bin = Get-BinaryHost $pane
    if ($bin) { return 'binary' }
    if (Test-GrokName $proc) { return 'grok' }
    if ($proc -eq 'cursor-agent' -or $proc -eq 'cursor') { return 'cursor' }
    $bin = Get-BinaryHost $proc
    if ($bin) { return 'binary' }
    if ($proc -eq 'agent' -and -not (Test-GrokName $pane)) { return 'cursor' }
    if ($pane -eq 'agy' -or $proc -eq 'agy') { return 'screen' }
    return 'screen'
}

function Find-GrokChatHistory([string]$SessionId) {
    if ([string]::IsNullOrWhiteSpace($SessionId)) { return $null }
    $root = Join-Path $env:USERPROFILE '.grok\sessions'
    if (-not (Test-Path -LiteralPath $root)) { return $null }
    foreach ($cwdDir in Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue) {
        $history = Join-Path (Join-Path $cwdDir.FullName $SessionId) 'chat_history.jsonl'
        if (Test-Path -LiteralPath $history) { return $history }
    }
    return $null
}

function Get-CursorProjectSlug([string]$Cwd) {
    if ([string]::IsNullOrWhiteSpace($Cwd)) { return $null }
    $p = $Cwd.TrimEnd('\', '/')
    if ($p.Length -ge 2 -and $p[1] -eq [char]':') {
        $drive = $p.Substring(0, 1).ToLowerInvariant()
        $rest = $p.Substring(2).TrimStart('\', '/')
        $rest = $rest -replace '[\\/]', '-'
        return "$drive-$rest"
    }
    return ($p -replace '[\\/]', '-')
}

function Find-CursorTranscript([string]$SessionId, [string]$Cwd) {
    $root = Join-Path $env:USERPROFILE '.cursor\projects'
    if (-not (Test-Path -LiteralPath $root)) { return $null }
    if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
        foreach ($proj in Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue) {
            $nested = Join-Path (Join-Path (Join-Path $proj.FullName 'agent-transcripts') $SessionId) ($SessionId + '.jsonl')
            if (Test-Path -LiteralPath $nested) { return $nested }
            $flat = Join-Path (Join-Path $proj.FullName 'agent-transcripts') ($SessionId + '.jsonl')
            if (Test-Path -LiteralPath $flat) { return $flat }
        }
    }
    $slug = Get-CursorProjectSlug $Cwd
    if ($slug) {
        $dir = Join-Path (Join-Path $root $slug) 'agent-transcripts'
        if (Test-Path -LiteralPath $dir) {
            $newest = Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.jsonl' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            if ($newest) { return $newest.FullName }
        }
    }
    return $null
}

function Get-JsonlAssistantTexts {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][scriptblock]$Pick
    )
    $texts = New-Object System.Collections.Generic.List[string]
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $ser.MaxJsonLength = [int]::MaxValue
    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $obj = $ser.DeserializeObject($line)
        if ($null -eq $obj) { continue }
        $chunk = & $Pick $obj
        if (-not [string]::IsNullOrWhiteSpace($chunk)) { $texts.Add($chunk.Trim()) }
    }
    return $texts
}

function Get-TextParts($Content) {
    if ($Content -is [string]) { return [string]$Content }
    if ($Content -is [System.Collections.IEnumerable]) {
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($part in $Content) {
            if ($part -is [System.Collections.IDictionary] -and [string]$part['type'] -eq 'text') {
                $t = [string]$part['text']
                if (-not [string]::IsNullOrWhiteSpace($t)) { $parts.Add($t) }
            }
        }
        if ($parts.Count -gt 0) { return [string]::Join("`n", $parts.ToArray()) }
    }
    return $null
}

function Get-GrokAssistantTexts([string]$HistoryPath) {
    return Get-JsonlAssistantTexts $HistoryPath {
        param($obj)
        if (-not ($obj -is [System.Collections.IDictionary])) { return $null }
        if ([string]$obj['type'] -ne 'assistant') { return $null }
        return Get-TextParts $obj['content']
    }
}

function Get-CursorAssistantTexts([string]$HistoryPath) {
    return Get-JsonlAssistantTexts $HistoryPath {
        param($obj)
        if (-not ($obj -is [System.Collections.IDictionary])) { return $null }
        if ([string]$obj['role'] -ne 'assistant') { return $null }
        $message = $obj['message']
        if ($message -is [System.Collections.IDictionary]) {
            return Get-TextParts $message['content']
        }
        return Get-TextParts $obj['content']
    }
}

function Write-Utf8File([string]$Path, [string]$Text) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

function New-LastMarkdown([string]$HostName, [string[]]$Bodies) {
    $lines = New-Object System.Collections.Generic.List[string]
    $title = if ($Bodies.Count -le 1) { "# $HostName · last reply" } else { "# $HostName · last replies" }
    $lines.Add($title)
    $lines.Add('')
    $n = $Bodies.Count
    for ($i = 0; $i -lt $n; $i++) {
        # Newest first: index 0 is the latest assistant text.
        $title = if ($i -eq 0) { '## Newest' } else { "## Older $($i)" }
        $lines.Add($title)
        $lines.Add('')
        $lines.Add($Bodies[$i])
        $lines.Add('')
    }
    return [string]::Join("`n", $lines.ToArray())
}

function Open-DocPane {
    param(
        [Parameter(Mandatory = $true)][string]$Cwd,
        [Parameter(Mandatory = $true)][string]$DeliverTo,
        [string]$DeliverAgent,
        [string]$File,
        [string]$MessagePid,
        [string]$HostName,
        [string]$MessageCwd
    )
    $bin = Get-HerdrBin
    $argv = @(
        'plugin', 'pane', 'open',
        '--plugin', 'plannotator-tui',
        '--entrypoint', 'doc',
        '--placement', 'overlay',
        '--focus',
        '--cwd', $Cwd
    )
    if ($File) {
        $argv += @('--env', "PLANNOTATOR_TUI_FILE=$File")
    }
    if ($MessagePid) {
        $argv += @('--env', "PLANNOTATOR_TUI_MESSAGE_PID=$MessagePid")
        if ($HostName) { $argv += @('--env', "PLANNOTATOR_TUI_HOST=$HostName") }
        if ($MessageCwd) { $argv += @('--env', "PLANNOTATOR_TUI_CWD=$MessageCwd") }
    }
    $argv += @('--env', "PLANNOTATOR_TUI_DELIVER_TO=$DeliverTo")
    if ($DeliverAgent) { $argv += @('--env', "PLANNOTATOR_TUI_DELIVER_AGENT=$DeliverAgent") }
    $raw = & $bin @argv 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "herdr plugin pane open failed: $raw"
    }
    if ($raw.Trim()) { Write-Output $raw.Trim() }
}

function Open-TextAsLast {
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][string]$PaneId,
        [Parameter(Mandatory = $true)][string]$Markdown
    )
    $tmp = Join-Path $env:TEMP 'plannotator-tui-last.md'
    Write-Utf8File $tmp $Markdown
    if ($env:PLANNOTATOR_TUI_LAST_PRINT -eq '1') {
        Write-Output $Markdown
        return
    }
    Open-DocPane -Cwd ([System.IO.Path]::GetDirectoryName($tmp)) -DeliverTo $PaneId -DeliverAgent $HostName -File $tmp
}

function Open-NewestAssistant {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)]$Texts,
        [Parameter(Mandatory = $true)][string]$PaneId
    )
    $arr = @($Texts)
    if ($arr.Count -eq 0) {
        throw "$Label session has no assistant text yet"
    }
    $md = New-LastMarkdown $Label @($arr[$arr.Count - 1])
    Open-TextAsLast -HostName $Label -PaneId $PaneId -Markdown $md
}

$paneId = Get-FocusedPaneId
$paneInfo = Invoke-HerdrJson @('pane', 'get', $paneId)
$agent = [string](Get-Prop $paneInfo @('result', 'pane', 'agent'))
$sessionId = [string](Get-Prop $paneInfo @('result', 'pane', 'agent_session', 'value'))
$paneCwd = [string](Get-Prop $paneInfo @('result', 'pane', 'cwd'))
if (-not $paneCwd) { $paneCwd = (Get-Location).Path }

$procName = $agent
$procPid = $null
try {
    $procInfo = Invoke-HerdrJson @('pane', 'process-info', '--pane', $paneId)
    $procs = Get-Prop $procInfo @('result', 'process_info', 'foreground_processes')
    if ($procs) {
        $bestScore = -1
        foreach ($p in $procs) {
            $n = Normalize-HostName ([string]$p['name'])
            if (-not $n) { continue }
            $score = 1
            if (Test-GrokName $n) { $score = 100 }
            elseif ($n -eq 'cursor-agent') { $score = 90 }
            elseif ($n -eq 'cursor') { $score = 80 }
            elseif (Get-BinaryHost $n) { $score = 70 }
            elseif ($n -eq 'agent') { $score = 10 }
            if ($score -gt $bestScore) {
                $bestScore = $score
                $procName = $n
                $procPid = $p['pid']
            }
        }
    }
} catch {
    # process-info is best-effort; pane.agent is enough for Grok/Cursor.
}

$hostName = Normalize-HostName $procName
if (-not $hostName) { $hostName = Normalize-HostName $agent }

$binaryHost = Get-BinaryHost $agent
if (-not $binaryHost) { $binaryHost = Get-BinaryHost $hostName }

$kind = Resolve-LastKind -PaneAgent $agent -ProcName $procName

if ($kind -eq 'grok') {
    $history = Find-GrokChatHistory $sessionId
    if (-not $history) {
        throw "no Grok chat_history.jsonl for session $sessionId (looked under $env:USERPROFILE\.grok\sessions)"
    }
    Open-NewestAssistant 'grok' (Get-GrokAssistantTexts $history) $paneId
    exit 0
}

if ($kind -eq 'cursor') {
    $history = Find-CursorTranscript $sessionId $paneCwd
    if (-not $history) {
        throw "no Cursor agent-transcripts jsonl for session $sessionId cwd $paneCwd (looked under $env:USERPROFILE\.cursor\projects)"
    }
    Open-NewestAssistant 'cursor' (Get-CursorAssistantTexts $history) $paneId
    exit 0
}

if ($kind -eq 'binary' -and $binaryHost -and $procPid) {
    if ($env:PLANNOTATOR_TUI_LAST_PRINT -eq '1') {
        Write-Output "would open upstream last host=$binaryHost pid=$procPid pane=$paneId"
        exit 0
    }
    Open-DocPane -Cwd $paneCwd -DeliverTo $paneId -DeliverAgent $binaryHost -MessagePid ([string]$procPid) -HostName $binaryHost -MessageCwd $paneCwd
    exit 0
}

# Unknown / Agy (protobuf conversations): pane screen, never Claude Code default.
$bin = Get-HerdrBin
$screen = & $bin agent read $paneId --source recent-unwrapped --format text 2>$null | Out-String
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($screen)) {
    $label = $hostName
    if (-not $label) { $label = $agent }
    if (-not $label) { $label = 'unknown' }
    throw "$label is not supported by plannotator-tui last, and herdr agent read returned nothing"
}
$label = $hostName
if (-not $label) { $label = $agent }
if (-not $label) { $label = 'agent' }
$md = New-LastMarkdown $label @($screen.Trim())
Open-TextAsLast -HostName $label -PaneId $paneId -Markdown $md
