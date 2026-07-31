[CmdletBinding()]
param(
    [ValidateSet('Check', 'Install', 'Login')]
    [string]$Action = 'Check',

    [ValidateSet('core', 'x', 'video')]
    [string]$Capability = 'core',

    [switch]$Approved,

    [ValidateSet('oauth', 'device-auth')]
    [string]$LoginMode = 'oauth',

    [string]$GrokBin
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Test-NativeWindows {
    return $env:OS -eq 'Windows_NT'
}

function Get-Architecture {
    $value = $env:PROCESSOR_ARCHITECTURE
    switch ($value) {
        'AMD64' { return 'x86_64' }
        'x86' { return 'x86_64' }
        'ARM64' { return 'aarch64' }
        default {
            if ($value) { return $value.ToLowerInvariant() }
            return 'unknown'
        }
    }
}

function Resolve-GrokPath {
    if ($GrokBin) {
        if (Test-Path -LiteralPath $GrokBin -PathType Leaf) {
            return (Resolve-Path -LiteralPath $GrokBin).Path
        }
        return $null
    }

    if ($env:GROK_BIN -and (Test-Path -LiteralPath $env:GROK_BIN -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $env:GROK_BIN).Path
    }

    $discovered = Get-Command grok -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($discovered) {
        if ($discovered.Path) { return $discovered.Path }
        if ($discovered.Source) { return $discovered.Source }
    }

    foreach ($candidate in @(
        (Join-Path $HOME '.grok\bin\grok.exe'),
        (Join-Path $HOME '.grok\bin\grok')
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Invoke-NativeCapture {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    try {
        $lines = @(& $FilePath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) { $exitCode = 0 }
        return [ordered]@{
            exit_code = [int]$exitCode
            text = [string]::Join([Environment]::NewLine, [string[]]$lines)
        }
    } catch {
        return [ordered]@{
            exit_code = 1
            text = $_.Exception.Message
        }
    }
}

function Get-CheckResult {
    $status = 'ready_local'
    $path = ''
    $version = ''
    $loginSupported = $false
    $updateSupported = $false
    $missing = @()

    if (-not (Test-NativeWindows)) {
        $status = 'unsupported_platform'
    } else {
        $resolved = Resolve-GrokPath
        if (-not $resolved) {
            $status = 'missing_cli'
        } else {
            $path = $resolved
            $versionResult = Invoke-NativeCapture -FilePath $resolved -Arguments @('--version')
            if ($versionResult.exit_code -ne 0) {
                $status = 'broken_cli'
            } else {
                $version = $versionResult.text.Trim()
                $helpResult = Invoke-NativeCapture -FilePath $resolved -Arguments @('--help')
                $loginSupported = $helpResult.text -match '(?im)(^|\s)login(\s|$)'
                $updateSupported = $helpResult.text -match '(?im)(^|\s)update(\s|$)'
            }
        }
    }

    if ($status -eq 'ready_local') {
        if ($Capability -eq 'x') {
            if (-not (Get-Command node -ErrorAction SilentlyContinue)) { $missing += 'node' }
        } elseif ($Capability -eq 'video') {
            foreach ($dependency in @('ffmpeg', 'ffprobe')) {
                if (-not (Get-Command $dependency -ErrorAction SilentlyContinue)) { $missing += $dependency }
            }
        }
        if ($missing.Count -gt 0) { $status = 'missing_dependency' }
    }

    return [ordered]@{
        status = $status
        capability = $Capability
        path = $path
        version = $version
        auth = 'unknown'
        platform = [ordered]@{
            os = if (Test-NativeWindows) { 'Windows' } else { [Environment]::OSVersion.Platform.ToString() }
            arch = Get-Architecture
        }
        commands = [ordered]@{
            login = [bool]$loginSupported
            update_check = [bool]$updateSupported
        }
        remote_capabilities = [ordered]@{
            x_search = 'unknown_until_run'
            video = 'unknown_until_run'
        }
        missing_dependencies = @($missing)
    }
}

function Write-CheckAndExit {
    $result = Get-CheckResult
    $result | ConvertTo-Json -Compress -Depth 8
    switch ($result.status) {
        'ready_local' { exit 0 }
        'missing_cli' { exit 10 }
        'broken_cli' { exit 11 }
        'missing_dependency' { exit 12 }
        'unsupported_platform' { exit 13 }
        default { exit 1 }
    }
}

function Install-Grok {
    if (-not $Approved) {
        [Console]::Error.WriteLine('Installation requires -Approved after explicit user authorization.')
        exit 3
    }
    if (-not (Test-NativeWindows)) {
        Write-CheckAndExit
    }
    if (Resolve-GrokPath) { return }

    $installerUri = [Uri]'https://x.ai/cli/install.ps1'
    if ($installerUri.Scheme -ne 'https' -or $installerUri.Host -ne 'x.ai') {
        [Console]::Error.WriteLine('Refusing a non-official Grok installer URL.')
        exit 15
    }

    $taskTemp = Join-Path ([IO.Path]::GetTempPath()) ('grok-bootstrap-' + [Guid]::NewGuid().ToString('N'))
    $installerPath = Join-Path $taskTemp 'install.ps1'
    New-Item -ItemType Directory -Path $taskTemp -Force | Out-Null

    $oldChannel = $env:GROK_CHANNEL
    $oldBinDir = $env:GROK_BIN_DIR
    try {
        Invoke-WebRequest -Uri $installerUri.AbsoluteUri -UseBasicParsing -OutFile $installerPath
        $header = Get-Content -LiteralPath $installerPath -TotalCount 8 | Out-String
        if ($header -notmatch 'Grok CLI installer for PowerShell' -or $header -notmatch 'https://x\.ai/cli/install\.ps1') {
            [Console]::Error.WriteLine('Downloaded content did not identify itself as the official Grok CLI PowerShell installer.')
            exit 15
        }

        $env:GROK_CHANNEL = 'stable'
        $env:GROK_BIN_DIR = Join-Path $HOME '.grok\bin'
        $engine = (Get-Process -Id $PID).Path
        & $engine -NoProfile -ExecutionPolicy Bypass -File $installerPath
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        $env:PATH = "$env:GROK_BIN_DIR;$env:PATH"
    } finally {
        $env:GROK_CHANNEL = $oldChannel
        $env:GROK_BIN_DIR = $oldBinDir
        if (Test-Path -LiteralPath $taskTemp) {
            Remove-Item -LiteralPath $taskTemp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Login-Grok {
    if (-not $Approved) {
        [Console]::Error.WriteLine('Login requires -Approved after explicit user authorization.')
        exit 3
    }

    $resolved = Resolve-GrokPath
    if (-not $resolved) {
        [Console]::Error.WriteLine('Grok CLI is not installed; run Install with -Approved first.')
        exit 10
    }

    if ($LoginMode -eq 'device-auth') {
        & $resolved login --device-auth
    } else {
        & $resolved login --oauth
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

switch ($Action) {
    'Check' { Write-CheckAndExit }
    'Install' {
        Install-Grok
        Write-CheckAndExit
    }
    'Login' { Login-Grok }
}
