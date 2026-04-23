<#
.SYNOPSIS
  skills-installer one-line installer for Windows PowerShell.

.DESCRIPTION
  Installs, lists or removes agent skills into Cursor / Claude Code /
  Codex / Windsurf skills directories. Intended to be piped from the web:

    iwr -useb https://raw.githubusercontent.com/2029193370/skills/main/scripts/install.ps1 | iex

  To pass flags to a piped script, use the -- convention via &{ ... } args:

    & ([ScriptBlock]::Create((iwr -useb .../install.ps1))) -Agent cursor -Skills superpowers

.NOTES
  Requires PowerShell 5.1 or newer (built into Windows 10/11).
  git and curl.exe are required; both ship with recent Windows.
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
  [ValidateSet('all','cursor','claude','codex','windsurf')]
  [string]$Agent = 'all',

  [ValidateSet('global','project')]
  [string]$Scope = 'global',

  [string]$Skills = 'all',

  [ValidateSet('install','uninstall','list')]
  [string]$Action = 'install',

  [switch]$Offline,
  [switch]$Force,
  [switch]$DryRun,
  [switch]$Yes,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'
$Repo = $env:SKILLS_INSTALLER_REPO; if (-not $Repo) { $Repo = '2029193370/skills' }
$Ref  = $env:SKILLS_INSTALLER_REF;  if (-not $Ref)  { $Ref  = 'main' }
$BaseUrl = "https://raw.githubusercontent.com/$Repo/$Ref"

$script:TmpRoot = $null
$script:MirrorRoot = $null

function Write-Info($msg)  { Write-Host "[skills] $msg"                      -ForegroundColor Blue }
function Write-Ok($msg)    { Write-Host "[skills] $msg"                      -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "[skills] $msg"                      -ForegroundColor Yellow }
function Write-Err2($msg)  { Write-Host "[skills] $msg"                      -ForegroundColor Red }
function Write-Step($msg)  { Write-Host ""; Write-Host "==> $msg"            -ForegroundColor Magenta }

function Show-Banner {
@"

  +----------------------------------------------------+
  |   skills-installer * one-command skills manager    |
  +----------------------------------------------------+
"@ | Write-Host -ForegroundColor Cyan
}

function Show-Help {
@"
Usage: install.ps1 [-Agent ...] [-Scope ...] [-Skills ...] [flags]

Actions:
  -Action install        (default)
  -Action uninstall
  -Action list

Selection:
  -Agent  all|cursor|claude|codex|windsurf
  -Scope  global|project
  -Skills all|name1,name2,...

Modes:
  -Offline               Use the bundled MIT mirror, no network
  -Force                 Overwrite existing skill directories
  -DryRun                Show what would happen; do not write
  -Yes                   Assume yes to all prompts

Examples:
  iwr -useb $BaseUrl/scripts/install.ps1 | iex
  & ([ScriptBlock]::Create((iwr -useb $BaseUrl/scripts/install.ps1))) -Agent cursor
  .\install.ps1 -Offline -Skills superpowers,find-skills
"@ | Write-Host
}

function Test-Command($name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Assert-Dependencies {
  $missing = @()
  if (-not (Test-Command git))   { $missing += 'git' }
  # Windows PowerShell ships Invoke-WebRequest; no need for curl. But git is required for sparse clone.
  if ($missing.Count -gt 0) {
    Write-Err2 "Missing dependencies: $($missing -join ', ')"
    Write-Err2 "Install Git for Windows from https://git-scm.com/download/win and try again."
    exit 1
  }
}

function Cleanup {
  if ($script:TmpRoot -and (Test-Path $script:TmpRoot)) {
    Remove-Item -Recurse -Force $script:TmpRoot -ErrorAction SilentlyContinue
  }
}

# ----- agent detection ------------------------------------------------------
function Get-AgentHome($agent) {
  switch ($agent) {
    'cursor'   { Join-Path $env:USERPROFILE '.cursor' }
    'claude'   {
      if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR }
      else { Join-Path $env:USERPROFILE '.claude' }
    }
    'codex'    { Join-Path $env:USERPROFILE '.codex' }
    'windsurf' { Join-Path $env:USERPROFILE '.codeium\windsurf' }
  }
}

function Get-AgentSkillsDir($agent, $scope) {
  $home2 = Get-AgentHome $agent
  $proj  = $PWD.Path
  switch ("$agent,$scope") {
    'cursor,global'    { Join-Path $home2 'skills' }
    'cursor,project'   { Join-Path $proj  '.cursor\skills' }
    'claude,global'    { Join-Path $home2 'skills' }
    'claude,project'   { Join-Path $proj  '.claude\skills' }
    'codex,global'     { Join-Path $home2 'skills' }
    'codex,project'    { Join-Path $proj  '.codex\skills' }
    'windsurf,global'  { Join-Path $home2 'skills' }
    'windsurf,project' { Join-Path $proj  '.windsurf\skills' }
    default { throw "unknown agent/scope $agent/$scope" }
  }
}

function Get-DetectedAgents {
  @('cursor','claude','codex','windsurf') | Where-Object { Test-Path (Get-AgentHome $_) }
}

function Get-SelectedAgents {
  if ($Agent -eq 'all') {
    $d = Get-DetectedAgents
    if (-not $d) { return @() }
    return $d
  }
  return @($Agent)
}

# ----- tar extraction (Windows-safe) ----------------------------------------
# Prefer Windows' bundled bsdtar (System32\tar.exe) which understands drive
# letters. Fall back to whatever tar is on PATH (Git Bash ships a busybox
# tar that treats C:\ as a host:path spec and breaks).
function Expand-Tar($tarPath, $destDir) {
  $exe = 'tar'
  if ($env:SystemRoot) {
    $systemTar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (Test-Path -LiteralPath $systemTar) { $exe = $systemTar }
  }
  & $exe -xzf $tarPath -C $destDir
  if ($LASTEXITCODE -ne 0) {
    throw "tar extraction failed for $tarPath (exit $LASTEXITCODE)"
  }
}

# ----- registry -------------------------------------------------------------
function Fetch-Registry {
  $script:TmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("skills-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $script:TmpRoot | Out-Null

  $localRoot = $env:SKILLS_INSTALLER_LOCAL_ROOT
  if ($localRoot -and (Test-Path (Join-Path $localRoot 'registry.json'))) {
    Write-Info "using local repo root: $localRoot"
    $script:MirrorRoot = (Resolve-Path $localRoot).Path
    return (Join-Path $script:MirrorRoot 'registry.json')
  }

  if ($Offline) {
    Write-Info "offline mode: downloading repo snapshot $Ref"
    $tarUrl = "https://codeload.github.com/$Repo/tar.gz/$Ref"
    $tarPath = Join-Path $script:TmpRoot 'snapshot.tar.gz'
    Invoke-WebRequest -UseBasicParsing -Uri $tarUrl -OutFile $tarPath
    Expand-Tar $tarPath $script:TmpRoot
    Remove-Item -Force $tarPath
    $script:MirrorRoot = (Get-ChildItem -Directory $script:TmpRoot | Select-Object -First 1).FullName
    return (Join-Path $script:MirrorRoot 'registry.json')
  }
  else {
    Write-Info "fetching registry from $BaseUrl/registry.json"
    $regPath = Join-Path $script:TmpRoot 'registry.json'
    Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/registry.json" -OutFile $regPath
    return $regPath
  }
}

function Parse-Registry($path) {
  $json = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
  return $json.skills
}

function Get-SelectedSkills($all) {
  if ($Skills -eq 'all') { return $all }
  $names = $Skills -split ','
  return $all | Where-Object { $names -contains $_.name }
}

# ----- skill fetch / mirror resolution --------------------------------------
function Fetch-UpstreamTree($upstream, $branch, $paths) {
  $wd = Join-Path $script:TmpRoot ("src-" + [guid]::NewGuid().ToString('N'))
  & git clone --depth 1 --filter=blob:none --sparse --branch $branch $upstream $wd 2>$null | Out-Null
  Push-Location $wd
  try {
    & git sparse-checkout set @paths 2>$null | Out-Null
  } finally { Pop-Location }
  return $wd
}

function Resolve-SkillSource($skill) {
  if ($Offline) {
    $redist = $true
    if ($skill.PSObject.Properties.Match('redistributable').Count) { $redist = [bool]$skill.redistributable }
    if (-not $redist) {
      Write-Warn2 "skill '$($skill.name)' is not redistributable under --offline (license: $($skill.license)); skipping"
      return $null
    }
    $mirrored = Join-Path $script:MirrorRoot ("skills/" + $skill.name)
    if (-not (Test-Path $mirrored)) {
      Write-Err2 "offline mirror missing for '$($skill.name)' at $mirrored"
      return $null
    }
    return [pscustomobject]@{ Root = $mirrored; IsMirror = $true }
  }
  else {
    $branch = 'main'; if ($skill.branch) { $branch = $skill.branch }
    $wd = Fetch-UpstreamTree $skill.upstream $branch @($skill.paths)
    return [pscustomobject]@{ Root = $wd; IsMirror = $false }
  }
}

# ----- install a single skill to a single agent's skills dir ----------------
function Install-Skill($agent, $skill) {
  $dir = Get-AgentSkillsDir $agent $Scope
  $src = Resolve-SkillSource $skill
  if ($null -eq $src) { return }

  $targets = New-Object System.Collections.ArrayList
  $paths = @($skill.paths)
  $installAs = $skill.installAs
  $flatten = $false
  if ($skill.PSObject.Properties.Match('flatten').Count) { $flatten = [bool]$skill.flatten }

  if ($installAs) {
    foreach ($p in $paths) {
      $base = Split-Path -Leaf $p
      $fromPath = if ($src.IsMirror) { Join-Path $src.Root $base } else { Join-Path $src.Root $p }
      [void]$targets.Add([pscustomobject]@{ Dst = (Join-Path $dir "$installAs\$base"); From = $fromPath })
    }
  }
  elseif ($flatten) {
    $root = if ($src.IsMirror) { $src.Root } else { Join-Path $src.Root $paths[0] }
    Get-ChildItem -Directory $root | ForEach-Object {
      [void]$targets.Add([pscustomobject]@{ Dst = (Join-Path $dir ($skill.name + "\" + $_.Name)); From = $_.FullName })
    }
  }
  else {
    foreach ($p in $paths) {
      $fromPath = if ($src.IsMirror) { $src.Root }
                  elseif ($p -eq '.') { $src.Root }
                  else { Join-Path $src.Root $p }
      [void]$targets.Add([pscustomobject]@{ Dst = (Join-Path $dir $skill.name); From = $fromPath })
    }
  }

  foreach ($t in $targets) {
    if ($DryRun) { Write-Info "would install $($skill.name) -> $($t.Dst)"; continue }
    if ((Test-Path $t.Dst) -and -not $Force) {
      if ($Yes -or -not $Host.UI.RawUI) {
        Write-Warn2 "$($t.Dst) exists; keeping (pass -Force to overwrite)"; continue
      }
      $ans = Read-Host "[skills] $($t.Dst) exists. Overwrite? [y/N]"
      if ($ans -notmatch '^(y|Y|yes|YES)$') { Write-Info "skipped $($t.Dst)"; continue }
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $t.Dst) | Out-Null
    if (Test-Path $t.Dst) { Remove-Item -Recurse -Force $t.Dst }
    Copy-Item -Recurse -Force $t.From $t.Dst
    Write-Ok "installed $($skill.name) -> $($t.Dst)"
    Record-Manifest $dir $skill.name $t.Dst
  }
}

function Record-Manifest($dir, $name, $installed) {
  $file = Join-Path $dir '.skills-installer.json'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null

  $entries = New-Object System.Collections.ArrayList
  if (Test-Path -LiteralPath $file) {
    try {
      $existing = Get-Content -Raw -Encoding UTF8 $file | ConvertFrom-Json
      foreach ($e in @($existing.entries)) {
        if (-not ($e.name -eq $name -and $e.path -eq $installed)) {
          [void]$entries.Add([pscustomobject]@{ name = $e.name; path = $e.path; ts = $e.ts; ref = $e.ref })
        }
      }
    } catch {
      Write-Warn2 "manifest $file is unreadable, rewriting: $_"
    }
  }
  [void]$entries.Add([pscustomobject]@{
    name = $name
    path = $installed
    ts   = [int][double]::Parse((Get-Date -UFormat %s))
    ref  = $Ref
  })

  $out = [pscustomobject]@{
    version   = 1
    installer = 'skills-installer'
    ref       = $Ref
    entries   = @($entries)
  }
  ($out | ConvertTo-Json -Depth 6) | Out-File -Encoding UTF8 $file
}

# ----- actions --------------------------------------------------------------
function Invoke-List($regPath) {
  Write-Step 'Planned installation'
  $all = Parse-Registry $regPath
  $picked = Get-SelectedSkills $all
  foreach ($a in Get-SelectedAgents) {
    $d = Get-AgentSkillsDir $a $Scope
    Write-Host "  $a  ($Scope scope)" -ForegroundColor White
    Write-Host "    -> $d" -ForegroundColor DarkGray
    foreach ($s in $picked) { Write-Host "       - $($s.name)" }
  }
}

function Invoke-Install($regPath) {
  $agents = Get-SelectedAgents
  if (-not $agents) { Write-Err2 'no target agent (neither detected nor specified)'; exit 3 }
  $all = Parse-Registry $regPath
  $picked = Get-SelectedSkills $all
  Write-Step 'Installing skills'
  foreach ($a in $agents) {
    Write-Step "Agent: $a ($Scope)"
    foreach ($s in $picked) {
      try { Install-Skill $a $s } catch { Write-Warn2 "failed to install $($s.name): $_" }
    }
  }
  Write-Ok 'done'
  if ($DryRun) { Write-Info '(dry-run: no files were written)' }
}

function Invoke-Uninstall {
  $agents = Get-SelectedAgents
  $selectedNames = if ($Skills -eq 'all') { $null } else { @($Skills -split ',') }
  foreach ($a in $agents) {
    $dir = Get-AgentSkillsDir $a $Scope
    $mf  = Join-Path $dir '.skills-installer.json'
    if (-not (Test-Path $mf)) { Write-Warn2 "no manifest at $mf; skipping $a"; continue }
    $data = Get-Content -Raw -Encoding UTF8 $mf | ConvertFrom-Json
    $keep = New-Object System.Collections.ArrayList
    foreach ($e in @($data.entries)) {
      $matches2 = ($null -eq $selectedNames) -or ($selectedNames -contains $e.name)
      if ($matches2) {
        if (Test-Path -LiteralPath $e.path) {
          if ($DryRun) {
            Write-Info "would remove $($e.path)"
          }
          else {
            Remove-Item -Recurse -Force -LiteralPath $e.path
            Write-Ok "removed $($e.path)"
          }
        }
        else {
          Write-Warn2 "already gone: $($e.path)"
        }
      }
      else {
        [void]$keep.Add($e)
      }
    }
    if (-not $DryRun) {
      $new = [pscustomobject]@{
        version   = 1
        installer = 'skills-installer'
        ref       = $Ref
        entries   = @($keep)
      }
      ($new | ConvertTo-Json -Depth 6) | Out-File -Encoding UTF8 $mf

      # Prune empty parent directories up to (but not including) the agent skills dir.
      Get-ChildItem -Recurse -Directory $dir -ErrorAction SilentlyContinue |
        Sort-Object -Property FullName -Descending |
        ForEach-Object {
          if (-not (Get-ChildItem -Force -Recurse $_.FullName -ErrorAction SilentlyContinue)) {
            Remove-Item -Force $_.FullName -ErrorAction SilentlyContinue
          }
        }
    }
  }
}

# ----- interactive TUI (only when no selection flags used) ------------------
function Maybe-Prompt {
  if (-not [Environment]::UserInteractive) { return }
  if ($Agent -ne 'all' -or $Scope -ne 'global' -or $Skills -ne 'all') { return }
  if ($Action -ne 'install') { return }
  Show-Banner
  $detected = Get-DetectedAgents
  if (-not $detected) { $detected = @('cursor','claude','codex','windsurf') }
  Write-Host "Detected agents: $($detected -join ', ')" -ForegroundColor White
  Write-Host ""
  $a = Read-Host 'Install to which agent? [all/cursor/claude/codex/windsurf]'
  if ($a) { $script:Agent = $a }
  $sc = Read-Host 'Scope? [global/project]'
  if ($sc) { $script:Scope = $sc }
  $sk = Read-Host 'Skills? [all or comma-separated]'
  if ($sk) { $script:Skills = $sk }
}

# ----- main -----------------------------------------------------------------
try {
  if ($Help) { Show-Help; exit 0 }
  Assert-Dependencies
  Maybe-Prompt
  $regPath = Fetch-Registry
  switch ($Action) {
    'list'      { Invoke-List $regPath }
    'install'   { Invoke-Install $regPath }
    'uninstall' { Invoke-Uninstall }
  }
}
finally {
  Cleanup
}
