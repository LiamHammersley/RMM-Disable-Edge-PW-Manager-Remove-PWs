# -----------------------------------------------------------------------------
# Copyright (c) 2026 Liam J Hammersley
# Licensed under the MIT License. See LICENSE file in the project root.
#
# You are free to use, modify, and distribute this script, provided that the
# above copyright notice and this permission notice are retained in all copies
# or substantial portions of the software.
#
# Attribution is appreciated. If you use or build upon this work, please credit
# the original author: Liam J Hammersley
# -----------------------------------------------------------------------------
 

#requires -version 5.1
<#
.SYNOPSIS
  Disables Microsoft Edge Password Manager and deletes saved password databases
  for ALL local user profiles and ALL Edge profiles on the device.

.DESCRIPTION
  Actions performed:
   1) Disable Edge Password Manager via registry policy (HKLM) (prevents new saves)
   2) Stop Edge processes to unlock DB files
   3) For every user under C:\Users, and every Edge profile folder (Default, Profile 1, Profile 2, ...),
      delete BOTH credential DB variants:
        - "Login Data" and "Login Data-journal"
        - "Login Data for Account" and "Login Data for Account-journal"

.EXITCODES (Datto-friendly)
  0 = Success (policy applied; deletions attempted; no failures)
  1 = Partial success (policy applied but some deletions failed/locked)
  2 = Failed (could not apply policy or fatal error)
#>

$ErrorActionPreference = "Stop"

function Write-Log {
  param([string]$Message)
  Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Ensure-EdgePasswordManagerDisabled {
  # Disable Edge password manager: PasswordManagerEnabled = 0 (HKLM policy)
  $edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
  if (-not (Test-Path $edgePolicyPath)) {
    New-Item -Path $edgePolicyPath -Force | Out-Null
  }
  New-ItemProperty -Path $edgePolicyPath -Name "PasswordManagerEnabled" -PropertyType DWord -Value 0 -Force | Out-Null
}

function Stop-EdgeProcesses {
  Write-Log "Stopping Edge processes to unlock databases..."
  Get-Process msedge, msedgewebview2 -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
}

function Remove-FileIfExists {
  param([Parameter(Mandatory=$true)][string]$Path)

  if (Test-Path -LiteralPath $Path) {
    Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
    return $true
  }
  return $false
}

# Counters
[int]$failures = 0
[int]$deletedFiles = 0
[int]$edgeProfilesCheckedTotal = 0
$policyApplied = $false

# Track Windows user profiles checked (count only)
$userProfilesCheckedCount = 0

try {
  Write-Log "Applying policy: Disable Edge Password Manager..."
  Ensure-EdgePasswordManagerDisabled
  $policyApplied = $true
  Write-Log "Policy applied: HKLM\SOFTWARE\Policies\Microsoft\Edge\PasswordManagerEnabled=0"

  Stop-EdgeProcesses

  Write-Log "Enumerating local Windows user profiles under C:\Users ..."
  $userDirs = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction Stop |
    Where-Object { $_.Name -notin @("Public","Default","Default User","All Users") }

  foreach ($u in $userDirs) {
    $userProfilesCheckedCount++

    $userDataRoot = Join-Path $u.FullName "AppData\Local\Microsoft\Edge\User Data"
    if (-not (Test-Path -LiteralPath $userDataRoot)) {
      continue
    }

    # Edge profile folders: Default, Profile 1, Profile 2, ...
    $edgeProfiles = Get-ChildItem -Path $userDataRoot -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match '^(Default|Profile \d+)$' }

    foreach ($p in $edgeProfiles) {
      $edgeProfilesCheckedTotal++

      $targets = @(
        (Join-Path $p.FullName "Login Data"),
        (Join-Path $p.FullName "Login Data-journal"),
        (Join-Path $p.FullName "Login Data for Account"),
        (Join-Path $p.FullName "Login Data for Account-journal")
      )

      foreach ($t in $targets) {
        try {
          if (Remove-FileIfExists -Path $t) {
            $deletedFiles++
            Write-Log "Deleted: $t"
          }
        }
        catch {
          $failures++
          Write-Log "FAILED: $t  Error: $($_.Exception.Message)"
          # Continue attempting remaining files/profiles
        }
      }
    }
  }

  # --- Summary ---
  Write-Log ("PolicyApplied: {0} | UserProfilesChecked: {1} | EdgeProfilesChecked: {2} | FilesDeleted: {3} | Failures: {4}" -f `
    $policyApplied, $userProfilesCheckedCount, $edgeProfilesCheckedTotal, $deletedFiles, $failures)

  if (-not $policyApplied) { exit 2 }
  if ($failures -gt 0) { exit 1 }
  exit 0
}
catch {
  Write-Log "FATAL: $($_.Exception.Message)"

  # Still emit a summary line if we can
  Write-Log ("PolicyApplied: {0} | UserProfilesChecked: {1} | EdgeProfilesChecked: {2} | FilesDeleted: {3} | Failures: {4}" -f `
    $policyApplied, $userProfilesCheckedCount, $edgeProfilesCheckedTotal, $deletedFiles, ($failures + 1))

  exit 2
}
