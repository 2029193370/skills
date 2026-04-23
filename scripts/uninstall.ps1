<#
.SYNOPSIS
  Uninstall skills previously installed by skills-installer.

.EXAMPLE
  iwr -useb https://raw.githubusercontent.com/2029193370/skills/main/scripts/uninstall.ps1 | iex
#>
#Requires -Version 5.1
param(
  [string]$Agent = 'all',
  [string]$Scope = 'global',
  [string]$Skills = 'all',
  [switch]$DryRun
)

$Repo = $env:SKILLS_INSTALLER_REPO; if (-not $Repo) { $Repo = '2029193370/skills' }
$Ref  = $env:SKILLS_INSTALLER_REF;  if (-not $Ref)  { $Ref  = 'main' }
$url  = "https://raw.githubusercontent.com/$Repo/$Ref/scripts/install.ps1"

$script = Invoke-WebRequest -UseBasicParsing -Uri $url
$block  = [ScriptBlock]::Create($script.Content)
& $block -Action uninstall -Agent $Agent -Scope $Scope -Skills $Skills -DryRun:$DryRun
