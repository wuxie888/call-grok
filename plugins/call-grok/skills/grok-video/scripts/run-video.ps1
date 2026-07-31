[CmdletBinding()]
param(
    [string]$Image,
    [string]$Prompt,
    [string]$PromptFile,

    [ValidateSet(6, 10)]
    [int]$Duration,

    [ValidateSet('480p', '720p')]
    [string]$Resolution,

    [string]$OutputDir,
    [switch]$Confirmed,
    [string]$GrokBin
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message, [int]$Code) {
    [Console]::Error.WriteLine($Message)
    exit $Code
}

function Resolve-GrokPath {
    if ($GrokBin) {
        if (Test-Path -LiteralPath $GrokBin -PathType Leaf) { return (Resolve-Path -LiteralPath $GrokBin).Path }
        return $null
    }
    if ($env:GROK_BIN -and (Test-Path -LiteralPath $env:GROK_BIN -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $env:GROK_BIN).Path
    }
    $command = Get-Command grok -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        if ($command.Path) { return $command.Path }
        return $command.Source
    }
    foreach ($candidate in @((Join-Path $HOME '.grok\bin\grok.exe'), (Join-Path $HOME '.grok\bin\grok'))) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    return $null
}

if (-not $Confirmed) { Fail 'Video generation requires -Confirmed after explicit approval of the exact paid action.' 3 }
if (-not $Image -or -not (Test-Path -LiteralPath $Image -PathType Leaf)) { Fail '-Image must point to a readable source image.' 2 }
if ($Prompt -and $PromptFile) { Fail 'Use either -Prompt or -PromptFile, not both.' 2 }
if ($PromptFile) {
    if (-not (Test-Path -LiteralPath $PromptFile -PathType Leaf)) { Fail '-PromptFile must be readable.' 2 }
    $Prompt = Get-Content -LiteralPath $PromptFile -Raw
}
if (-not $Prompt -or -not $Prompt.Trim()) { Fail 'A non-empty -Prompt or -PromptFile is required.' 2 }
if (-not $Duration) { Fail '-Duration must be 6 or 10 seconds for the tested CLI path.' 2 }
if (-not $Resolution) { Fail '-Resolution must be 480p or 720p.' 2 }
if (-not $OutputDir) { Fail '-OutputDir is required.' 2 }

$ffmpegCommand = Get-Command ffmpeg -ErrorAction SilentlyContinue | Select-Object -First 1
$ffprobeCommand = Get-Command ffprobe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $ffmpegCommand) { Fail 'ffmpeg is required.' 127 }
if (-not $ffprobeCommand) { Fail 'ffprobe is required.' 127 }
$ffmpeg = if ($ffmpegCommand.Path) { $ffmpegCommand.Path } else { $ffmpegCommand.Source }
$ffprobe = if ($ffprobeCommand.Path) { $ffprobeCommand.Path } else { $ffprobeCommand.Source }

$resolvedGrok = Resolve-GrokPath
if (-not $resolvedGrok) { Fail 'Grok CLI is not installed. Use call-grok to install and log in, then resume.' 127 }

$imagePath = (Resolve-Path -LiteralPath $Image).Path
$workDir = Split-Path -Parent $imagePath
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$outputPath = (Resolve-Path -LiteralPath $OutputDir).Path

$taskPrompt = @"
Execute one approved video-generation tool call and nothing else. Use image_to_video exactly once with image="$imagePath", prompt="$Prompt", duration=$Duration, resolution_name="$Resolution". Do not plan shots, do not generate or edit an image, do not use reference_to_video, do not call any tool more than once, and do not retry if generation fails. After the tool returns, report the saved video path and stop.
"@
$systemPrompt = 'You are a bounded Grok Imagine execution worker. Call image_to_video exactly once with the user-supplied arguments. Do not plan, rewrite the prompt, call other tools, retry, or perform any other work. After the tool result, return only the saved path.'

$arguments = @(
    '--cwd', $workDir,
    '--single', $taskPrompt,
    '--output-format', 'json',
    '--tools', 'image_to_video',
    '--max-turns', '2',
    '--no-subagents',
    '--no-memory',
    '--no-plan',
    '--reasoning-effort', 'low',
    '--permission-mode', 'dontAsk',
    '--sandbox', 'workspace',
    '--system-prompt-override', $systemPrompt
)

$rawLines = @(& $resolvedGrok @arguments 2>&1)
$runStatus = $LASTEXITCODE
$rawOutput = [string]::Join([Environment]::NewLine, [string[]]$rawLines)
if ($runStatus -ne 0) {
    if ($rawOutput -match 'Zero Data Retention' -or $rawOutput -match 'output\.upload_url') {
        Fail 'Grok blocked direct video output under Zero Data Retention. Stop without retrying; choose explicit Opt in or configure an owned R2/S3 upload URL.' 20
    }
    Fail $rawOutput $runStatus
}

try {
    $envelope = $rawOutput | ConvertFrom-Json
} catch {
    Fail 'Grok completed but its JSON envelope could not be parsed; refusing to guess the output path.' 21
}

$sessionId = [string]$envelope.sessionId
if (-not $sessionId) { Fail 'Grok completed but no sessionId could be extracted; refusing to guess the output path.' 21 }

$sessionsRoot = Join-Path $HOME '.grok\sessions'
if (-not (Test-Path -LiteralPath $sessionsRoot -PathType Container)) { Fail "No Grok sessions directory exists for session $sessionId." 22 }
$video = Get-ChildItem -LiteralPath $sessionsRoot -Recurse -File -Filter '*.mp4' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match [Regex]::Escape($sessionId) -and $_.FullName -match '[\\/]videos[\\/]' } |
    Sort-Object LastWriteTimeUtc |
    Select-Object -Last 1
if (-not $video -or $video.Length -le 0) { Fail "No non-empty MP4 was found for Grok session $sessionId." 22 }

$deliveredPath = Join-Path $outputPath "grok-$sessionId-${Duration}s-$Resolution.mp4"
Copy-Item -LiteralPath $video.FullName -Destination $deliveredPath -Force

$probeLines = @(& $ffprobe -v error -select_streams 'v:0' -show_entries 'stream=codec_name,width,height,r_frame_rate,duration' -show_entries 'format=duration,size' -of json $deliveredPath 2>&1)
if ($LASTEXITCODE -ne 0) { Fail ([string]::Join([Environment]::NewLine, [string[]]$probeLines)) 23 }
$probeText = [string]::Join([Environment]::NewLine, [string[]]$probeLines)
try { $probe = $probeText | ConvertFrom-Json } catch { Fail 'ffprobe returned invalid JSON.' 23 }

$actualDuration = $null
if ($probe.format -and $probe.format.duration) { $actualDuration = [double]$probe.format.duration }
elseif ($probe.streams -and $probe.streams[0].duration) { $actualDuration = [double]$probe.streams[0].duration }
if ($null -eq $actualDuration) { Fail 'ffprobe could not determine video duration.' 23 }
if ([Math]::Abs($actualDuration - $Duration) -gt 1.0) { Fail "Generated video duration $actualDuration differs materially from requested ${Duration}s." 24 }

$width = [int]$probe.streams[0].width
$height = [int]$probe.streams[0].height
$shortEdge = [Math]::Min($width, $height)
$expectedEdge = if ($Resolution -eq '480p') { 480 } else { 720 }
if ([Math]::Abs($shortEdge - $expectedEdge) -gt 32) { Fail "Generated video ${width}x${height} does not match requested resolution class $Resolution." 25 }

$sha256 = (Get-FileHash -LiteralPath $deliveredPath -Algorithm SHA256).Hash.ToLowerInvariant()
$framesDir = Join-Path $outputPath "grok-$sessionId-frames"
New-Item -ItemType Directory -Path $framesDir -Force | Out-Null
$midpoint = ($actualDuration / 2.0).ToString('0.000', [Globalization.CultureInfo]::InvariantCulture)
$ending = ([Math]::Max(0, $actualDuration - 0.5)).ToString('0.000', [Globalization.CultureInfo]::InvariantCulture)

$frameRequests = @(
    [ordered]@{ time = '0.5'; path = (Join-Path $framesDir 'start.jpg') },
    [ordered]@{ time = $midpoint; path = (Join-Path $framesDir 'middle.jpg') },
    [ordered]@{ time = $ending; path = (Join-Path $framesDir 'end.jpg') }
)
foreach ($frame in $frameRequests) {
    & $ffmpeg -hide_banner -loglevel error -ss $frame.time -i $deliveredPath -frames:v 1 -q:v 2 $frame.path
    if ($LASTEXITCODE -ne 0) { Fail "ffmpeg could not extract QA frame at $($frame.time)s." 26 }
}

$result = [ordered]@{
    status = 'generated_needs_visual_qa'
    session_id = $sessionId
    source_session_path = $video.FullName
    delivered_path = $deliveredPath
    frames_dir = $framesDir
    sha256 = $sha256
    requested = [ordered]@{ duration_seconds = $Duration; resolution = $Resolution }
    ffprobe = $probe
    tool_calls = 1
    retried = $false
}
$result | ConvertTo-Json -Depth 12
