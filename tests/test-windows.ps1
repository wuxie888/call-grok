$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Plugin = Join-Path $Root 'plugins\call-grok'
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ('call-grok-windows-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Pass([string]$Message) {
    Write-Host "[PASS] $Message" -ForegroundColor Green
}

function Invoke-IsolatedPowerShell {
    param([string]$ScriptPath, [string[]]$Arguments = @())
    $engine = (Get-Process -Id $PID).Path
    $output = @(& $engine -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1)
    return [ordered]@{
        exit_code = [int]$LASTEXITCODE
        text = [string]::Join([Environment]::NewLine, [string[]]$output)
    }
}

try {
    $marketplace = Get-Content -LiteralPath (Join-Path $Root '.agents\plugins\marketplace.json') -Raw | ConvertFrom-Json
    $manifest = Get-Content -LiteralPath (Join-Path $Plugin '.codex-plugin\plugin.json') -Raw | ConvertFrom-Json
    Assert-True ($marketplace.name -eq 'call-grok') 'unexpected marketplace name'
    Assert-True ($marketplace.plugins[0].policy.authentication -eq 'ON_USE') 'unexpected auth policy'
    Assert-True ($manifest.name -eq 'call-grok') 'unexpected plugin name'
    Assert-True ($manifest.version -eq '1.1.0') 'unexpected plugin version'
    Pass 'marketplace and plugin manifests'

    foreach ($skill in @('call-grok', 'grok-x', 'grok-video')) {
        $skillFile = Join-Path $Plugin "skills\$skill\SKILL.md"
        Assert-True (Test-Path -LiteralPath $skillFile -PathType Leaf) "missing $skillFile"
        $text = Get-Content -LiteralPath $skillFile -Raw
        Assert-True ($text -match "(?m)^name:\s*$([Regex]::Escape($skill))\s*$") "frontmatter name mismatch for $skill"
        Assert-True ($text -match '(?m)^description:\s*\S') "frontmatter description missing for $skill"
    }
    Pass 'skill frontmatter and folder names'

    $powerShellScripts = @(
        (Join-Path $Plugin 'skills\call-grok\scripts\grok-bootstrap.ps1'),
        (Join-Path $Plugin 'skills\grok-x\scripts\run-x-intel.ps1'),
        (Join-Path $Plugin 'skills\grok-video\scripts\run-video.ps1'),
        (Join-Path $Root 'tests\test-windows.ps1')
    )
    foreach ($script in $powerShellScripts) {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors)
        Assert-True ($errors.Count -eq 0) "PowerShell parser errors in $script`: $($errors -join '; ')"
    }
    & node --check (Join-Path $Plugin 'skills\grok-x\scripts\extract-final-json.mjs')
    Assert-True ($LASTEXITCODE -eq 0) 'Node extractor syntax failed'
    & node --check (Join-Path $Root 'tests\check-markdown-links.mjs')
    Assert-True ($LASTEXITCODE -eq 0) 'Markdown checker syntax failed'
    Pass 'PowerShell and Node syntax'

    & node (Join-Path $Root 'tests\check-markdown-links.mjs')
    Assert-True ($LASTEXITCODE -eq 0) 'Markdown link checker failed'
    Pass 'local Markdown links and media targets'

    $bootstrap = Join-Path $Plugin 'skills\call-grok\scripts\grok-bootstrap.ps1'
    $missingPath = Join-Path $TempRoot 'missing-grok.exe'
    $missing = Invoke-IsolatedPowerShell -ScriptPath $bootstrap -Arguments @('-Action', 'Check', '-Capability', 'core', '-GrokBin', $missingPath)
    Assert-True ($missing.exit_code -eq 10) "missing CLI returned $($missing.exit_code) instead of 10: $($missing.text)"
    $missingJson = $missing.text | ConvertFrom-Json
    Assert-True ($missingJson.status -eq 'missing_cli') 'missing CLI status mismatch'
    Assert-True ($missingJson.auth -eq 'unknown') 'preflight must not inspect credentials'
    Pass 'native Windows missing-CLI preflight'

    $fakeGrok = Join-Path $TempRoot 'grok.cmd'
    @'
@echo off
if "%1"=="--version" (
  echo grok 0.0-test
  exit /b 0
)
if "%1"=="--help" (
  echo login update
  exit /b 0
)
exit /b 0
'@ | Set-Content -LiteralPath $fakeGrok -Encoding Ascii

    $ready = Invoke-IsolatedPowerShell -ScriptPath $bootstrap -Arguments @('-Action', 'Check', '-Capability', 'core', '-GrokBin', $fakeGrok)
    Assert-True ($ready.exit_code -eq 0) "ready preflight returned $($ready.exit_code): $($ready.text)"
    $readyJson = $ready.text | ConvertFrom-Json
    Assert-True ($readyJson.status -eq 'ready_local') 'ready status mismatch'
    Assert-True ($readyJson.version -eq 'grok 0.0-test') 'fake version was not captured'
    Assert-True ($readyJson.commands.login -eq $true) 'login capability was not detected'
    Pass 'native Windows ready preflight with mocked Grok CLI'

    $videoRunner = Join-Path $Plugin 'skills\grok-video\scripts\run-video.ps1'
    $video = Invoke-IsolatedPowerShell -ScriptPath $videoRunner
    Assert-True ($video.exit_code -eq 3) "unconfirmed video returned $($video.exit_code) instead of 3"
    Assert-True ($video.text -match 'requires -Confirmed') 'missing paid-action confirmation message'
    Pass 'Windows video paid-action confirmation gate'

    $fixture = Get-Content -LiteralPath (Join-Path $Root 'tests\fixtures\grok-structured-output-recovery.json') -Raw
    $recovered = $fixture | & node (Join-Path $Plugin 'skills\grok-x\scripts\extract-final-json.mjs')
    Assert-True ($LASTEXITCODE -eq 0) 'structured output extractor failed'
    $recovered | & node (Join-Path $Root 'tests\assert-recovery.mjs')
    Assert-True ($LASTEXITCODE -eq 0) 'structured output recovery assertion failed'
    Pass 'structured-output recovery regression'

    $privacyPattern = '/Users/(myfuture|vibecoding)|/home/[^/]+|BEGIN (RSA |OPENSSH )?PRIVATE KEY|[A-Za-z0-9_]*(API_KEY|TOKEN|SECRET|PASSWORD)='
    $violations = @()
    $skipNames = @('README.md', 'README.en.md', 'SECURITY.md', 'test.sh', 'test-windows.ps1')
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -Force -File) {
        if ($file.FullName -match '[\\/]\.git[\\/]') { continue }
        if ($skipNames -contains $file.Name) { continue }
        if ($file.Extension -in @('.png', '.jpg', '.jpeg', '.gif', '.mp4', '.mov')) { continue }
        try { $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop } catch { continue }
        if ($content -match $privacyPattern) { $violations += $file.FullName }
    }
    Assert-True ($violations.Count -eq 0) "private paths or secrets found: $($violations -join ', ')"
    Pass 'public-repository privacy scan'

    Write-Host ''
    Write-Host 'All native Windows offline tests passed. No Grok login, X search, or media generation was performed.'
} finally {
    if (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
