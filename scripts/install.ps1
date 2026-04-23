# ----------------------------------------------------------------------------
# ci-templates one-line installer (Windows PowerShell 5+ / PowerShell 7+)
#
# Usage (from the root of your project):
#   iwr -useb https://raw.githubusercontent.com/2029193370/ci-templates/main/scripts/install.ps1 | iex
#
# Or, to pin to a specific tag (recommended for reproducibility):
#   iwr -useb https://raw.githubusercontent.com/2029193370/ci-templates/v2.0.0/scripts/install.ps1 | iex
#
# Environment overrides:
#   $env:CI_TEMPLATES_REF   = 'v2.0.0'  # branch or tag (default: main)
#   $env:CI_TEMPLATES_FORCE = '1'       # overwrite existing ci.yml without prompting
# ----------------------------------------------------------------------------

#Requires -Version 5
$ErrorActionPreference = 'Stop'

$Repo   = '2029193370/ci-templates'
$Ref    = if ($env:CI_TEMPLATES_REF)   { $env:CI_TEMPLATES_REF }   else { 'main' }
$Force  = ($env:CI_TEMPLATES_FORCE -eq '1')
$Target = '.github/workflows/ci.yml'
$Url    = "https://raw.githubusercontent.com/$Repo/$Ref/starter/.github/workflows/ci.yml"

function Write-Info([string]$m) { Write-Host "[ci-templates] $m" -ForegroundColor Cyan }
function Write-Ok  ([string]$m) { Write-Host "[ci-templates] $m" -ForegroundColor Green }
function Write-Err2([string]$m) { Write-Host "[ci-templates] $m" -ForegroundColor Red }

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor DarkCyan
Write-Host "  |   ci-templates  |  one-line installer    |" -ForegroundColor DarkCyan
Write-Host "  +------------------------------------------+" -ForegroundColor DarkCyan
Write-Host ""

if (-not (Test-Path '.git')) {
    Write-Err2 "Not inside a git repository."
    Write-Err2 "Run this from the root of the project you want to enable CI on."
    exit 1
}

if ((Test-Path $Target) -and -not $Force) {
    $ans = Read-Host "[ci-templates] $Target already exists. Overwrite? [y/N]"
    if ($ans -notmatch '^(y|Y|yes|YES)$') {
        Write-Info "Aborted without changes."
        exit 0
    }
}

$dir = Split-Path -Parent $Target
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

Write-Info "Downloading starter from $Url"
try {
    Invoke-WebRequest -Uri $Url -OutFile $Target -UseBasicParsing
} catch {
    Write-Err2 "Download failed: $($_.Exception.Message)"
    exit 1
}

if ((Get-Item $Target).Length -le 0) {
    Write-Err2 "Downloaded file is empty - network issue or bad ref '$Ref'."
    Remove-Item $Target -Force
    exit 1
}

Write-Ok "Installed: $Target"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Review the file   :  Get-Content $Target"
Write-Host "  2. Commit the change :  git add $Target; git commit -m 'ci: adopt ci-templates'"
Write-Host "  3. Push              :  git push"
Write-Host ""
Write-Host "Docs    : https://github.com/$Repo#readme" -ForegroundColor Cyan
Write-Host "Landing : https://2029193370.github.io/ci-templates/" -ForegroundColor Cyan
