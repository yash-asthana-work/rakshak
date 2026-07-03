<#
.SYNOPSIS
  Stage an untrusted repo into a disposable, read-only workspace and launch Claude Code
  in quarantine mode (enforcement layers 1-2). Layer 0 (OS/network sandbox) is the real
  boundary and is NOT something this script can fully provide on a normal host - see NOTES.

.DESCRIPTION
  Steps:
    1. Copies (or shallow-clones) the target into a fresh workspace OUTSIDE your projects.
    2. Marks the copied target read-only (belt-and-suspenders; the deny-list is the control).
    3. Writes a per-run settings.json with the guard hook's absolute path filled in.
    4. Sets TRIAGE_MODE / TRIAGE_TARGET / TRIAGE_AUDIT_LOG for the guard hook.
    5. Optionally runs the static scanner first.
    6. Launches Claude Code with --settings pointing at the quarantine profile.

.PARAMETER Source
  Local path to an untrusted repo, OR a git URL to shallow-clone. (Clone does not run repo hooks.)

.PARAMETER Mode
  strict (default) or hardened. Strict = read-only, no exec, no network.

.PARAMETER Scan
  Also run scripts/scan_untrusted.py against the staged target before launching.

.EXAMPLE
  .\launch-triage.ps1 -Source C:\Downloads\some-cloned-repo -Scan
  .\launch-triage.ps1 -Source https://github.com/someone/thing -Mode strict

.NOTES
  A TRUE boundary requires OS-level containment this script cannot guarantee on a
  developer laptop. For anything you actually distrust, run this INSIDE a throwaway VM or
  container with: network egress denied, no host credentials mounted, the repo on a
  read-only mount. Treat the app-layer controls here as defense-in-depth, not the wall.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [ValidateSet("strict", "hardened")][string]$Mode = "strict",
  [switch]$Scan
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Split-Path -Parent $here            # wrapper/ sits at the repo root
$guard = Join-Path $here "hooks\triage_guard.py"
$settingsTemplate = Join-Path $here "settings.quarantine.json"
$scanner = Join-Path $repo "skills\untrusted-code-triage\scripts\scan_untrusted.py"

# 1. Fresh disposable workspace (timestamped, outside your normal projects).
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$workspace = Join-Path $env:TEMP "triage\$stamp"
$target = Join-Path $workspace "target"
New-Item -ItemType Directory -Force -Path $target | Out-Null
Write-Host "[triage] workspace: $workspace" -ForegroundColor Cyan

# 2. Stage the source (copy local, or shallow-clone a URL - neither executes the code).
if ($Source -match '^(https?|git|ssh)://' -or $Source -match '\.git$') {
  Write-Host "[triage] shallow-cloning (no hooks run on clone): $Source" -ForegroundColor Cyan
  git clone --depth 1 --no-tags $Source $target 2>&1 | Write-Host
  Remove-Item -Recurse -Force (Join-Path $target ".git\hooks") -ErrorAction SilentlyContinue
} else {
  if (-not (Test-Path $Source)) { throw "Source path not found: $Source" }
  Write-Host "[triage] copying local source (read-only, no execution)..." -ForegroundColor Cyan
  Copy-Item -Recurse -Force -Path (Join-Path $Source "*") -Destination $target
}

# 3. Mark the staged target read-only (defense-in-depth; the deny-list is the real app control).
Get-ChildItem -Recurse -File -Path $target -ErrorAction SilentlyContinue | ForEach-Object {
  try { $_.IsReadOnly = $true } catch {}
}

# 4. Materialize a per-run settings.json with the guard's absolute path.
$auditLog = Join-Path $workspace "audit.log"
$guardEsc = ($guard -replace '\\', '\\')
$runSettings = Join-Path $workspace "settings.json"
(Get-Content $settingsTemplate -Raw) `
  -replace 'REPLACE_WITH_ABSOLUTE_PATH/triage_guard\.py', $guardEsc |
  Set-Content -Path $runSettings -Encoding utf8

# In hardened mode, relax the static deny-list (the hook still gates exec/net/writes).
if ($Mode -eq "hardened") {
  $cfg = Get-Content $runSettings -Raw | ConvertFrom-Json
  $cfg.permissions.deny = @("Write", "Edit", "MultiEdit", "NotebookEdit")
  $cfg.permissions.defaultMode = "default"
  ($cfg | ConvertTo-Json -Depth 20) | Set-Content -Path $runSettings -Encoding utf8
}

# 5. Guard-hook environment.
$env:TRIAGE_MODE = $Mode
$env:TRIAGE_TARGET = $target
$env:TRIAGE_AUDIT_LOG = $auditLog
Write-Host "[triage] mode=$Mode  target=$target" -ForegroundColor Cyan
Write-Host "[triage] audit log: $auditLog" -ForegroundColor Cyan

# 6. Optional static pre-scan (opens files as data; executes nothing).
if ($Scan) {
  Write-Host "[triage] running static scanner..." -ForegroundColor Cyan
  python $scanner $target
}

# 7. Launch Claude Code in the workspace with the quarantine profile.
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Write-Warning "The 'claude' CLI was not found on PATH. Staging is complete; launch manually:"
  Write-Host "  cd `"$workspace`"; claude --settings `"$runSettings`"" -ForegroundColor Yellow
  return
}
Push-Location $workspace
try {
  Write-Host "[triage] launching Claude Code (quarantine). Ask it to run /untrusted-code-triage on ./target" -ForegroundColor Green
  claude --settings "$runSettings"
} finally {
  Pop-Location
  Write-Host "[triage] session ended. Audit trail at: $auditLog" -ForegroundColor Cyan
  Write-Host "[triage] to discard everything: Remove-Item -Recurse -Force `"$workspace`"" -ForegroundColor DarkGray
}
