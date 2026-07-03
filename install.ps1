<#
.SYNOPSIS
  Install the two skills into your Claude Code skills directory (Windows).
  The enforcement wrapper (wrapper\) is deployed separately - see README "Rolling it out".
#>
[CmdletBinding()]
param([string]$SkillsDir = "$env:USERPROFILE\.claude\skills")

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null

foreach ($s in @("agentic-security-audit", "untrusted-code-triage")) {
  $dest = Join-Path $SkillsDir $s
  if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
  Copy-Item -Recurse -Force (Join-Path $here "skills\$s") $dest
  Write-Host "[install] skill: $s -> $dest"
}

Write-Host ""
Write-Host "[install] done. Next steps:"
Write-Host "  1. Triage untrusted code:  $here\wrapper\launch-triage.ps1 -Source <repo-or-url> -Scan"
Write-Host "  2. For true isolation, run inside $here\devcontainer\ (see its README)."
Write-Host "  3. Org-wide enforcement: put wrapper\settings.quarantine.json's deny-list + hook"
Write-Host "     into Claude Code managed-settings. See README 'Rolling it out'."
