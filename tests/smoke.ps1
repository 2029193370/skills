<#
.SYNOPSIS
  Minimal end-to-end smoke test for install.ps1. Safe on developer machines: it
  points USERPROFILE at a temp folder, so nothing in the real home is touched.

.EXAMPLE
  pwsh tests/smoke.ps1
#>
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$root     = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$fakeHome = Join-Path ([IO.Path]::GetTempPath()) ("skills-smoke-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path (Join-Path $fakeHome '.cursor') | Out-Null
$env:USERPROFILE = $fakeHome
$env:SKILLS_INSTALLER_LOCAL_ROOT = $root
if (-not $env:SKILLS_INSTALLER_REPO) { $env:SKILLS_INSTALLER_REPO = '2029193370/skills' }
if (-not $env:SKILLS_INSTALLER_REF)  { $env:SKILLS_INSTALLER_REF  = 'main' }

try {
  Write-Host '[1/4] -Action list (offline MIT subset)'
  & (Join-Path $root 'scripts\install.ps1') -Action list -Offline -Agent cursor `
    -Skills 'find-skills,ui-ux-pro-max'

  Write-Host '[2/4] -DryRun (offline)'
  & (Join-Path $root 'scripts\install.ps1') -DryRun -Offline -Yes -Agent cursor `
    -Skills 'find-skills,ui-ux-pro-max'

  Write-Host '[3/4] install offline find-skills + ui-ux-pro-max + superpowers'
  & (Join-Path $root 'scripts\install.ps1') -Offline -Yes -Agent cursor `
    -Skills 'find-skills,ui-ux-pro-max,superpowers'

  foreach ($p in @(
    "$fakeHome\.cursor\skills\find-skills\SKILL.md",
    "$fakeHome\.cursor\skills\ui-ux-pro-max\SKILL.md",
    "$fakeHome\.cursor\skills\superpowers",
    "$fakeHome\.cursor\skills\.skills-installer.json"
  )) {
    if (-not (Test-Path $p)) { throw "FAIL: missing $p" }
  }

  Write-Host '[4/4] uninstall'
  & (Join-Path $root 'scripts\install.ps1') -Action uninstall -Yes -Agent cursor `
    -Skills 'find-skills,ui-ux-pro-max,superpowers'
  if (Test-Path "$fakeHome\.cursor\skills\find-skills")  { throw 'find-skills should have been removed' }
  if (Test-Path "$fakeHome\.cursor\skills\superpowers")  { throw 'superpowers should have been removed' }

  Write-Host ''
  Write-Host 'All smoke tests passed.' -ForegroundColor Green
}
finally {
  Remove-Item -Recurse -Force $fakeHome -ErrorAction SilentlyContinue
}
