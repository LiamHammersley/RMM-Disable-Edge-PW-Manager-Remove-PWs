# Disable Microsoft Edge Password Manager and Remove Passwords

> **Copyright (c) 2026 Liam J Hammersley** — Licensed under the [MIT License](LICENSE)

A PowerShell script that disables the Microsoft Edge Password Manager via the Registry and removes all saved password databases across every local user profile on a Windows device.

Designed to be Datto RMM-compatible with meaningful exit codes, but works equally well as a standalone script or deployed via any RMM platform.

---

## What It Does

1. **Disables Edge Password Manager** — Applies a registry policy under `HKLM\SOFTWARE\Policies\Microsoft\Edge` that prevents Edge from saving new passwords.
2. **Stops Edge processes** — Terminates `msedge` and `msedgewebview2` to release locks on credential database files.
3. **Deletes saved password databases** — Removes all credential DB files from every Windows user profile and every Edge profile (`Default`, `Profile 1`, `Profile 2`, etc.) found under `C:\Users`.

### Files Removed Per Edge Profile

| File | Description |
|------|-------------|
| `Login Data` | Primary saved passwords database |
| `Login Data-journal` | SQLite journal for the above |
| `Login Data for Account` | Microsoft Account synced passwords database |
| `Login Data for Account-journal` | SQLite journal for the above |

---

## Requirements

- PowerShell 5.1 or later
- Must be run as **Administrator** (required to write HKLM registry keys and access other users' AppData)
- Windows OS with Microsoft Edge installed

---

## Usage

```powershell
# Run directly as Administrator
.\Disable-EdgePasswordManager.ps1
```

Or deploy silently via RMM:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "Disable-EdgePasswordManager.ps1"
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success — policy applied, all deletions completed |
| `1` | Partial success — policy applied, but one or more files could not be deleted (e.g. still locked) |
| `2` | Failed — policy could not be applied, or a fatal error occurred |

---

## Output / Logging

The script writes timestamped log lines to stdout, for example:

```
2026-03-26 10:15:01 - Applying policy: Disable Edge Password Manager...
2026-03-26 10:15:01 - Policy applied: HKLM\SOFTWARE\Policies\Microsoft\Edge\PasswordManagerEnabled=0
2026-03-26 10:15:01 - Stopping Edge processes to unlock databases...
2026-03-26 10:15:03 - Deleted: C:\Users\John\AppData\Local\Microsoft\Edge\User Data\Default\Login Data
2026-03-26 10:15:03 - PolicyApplied: True | UserProfilesChecked: 2 | EdgeProfilesChecked: 3 | FilesDeleted: 4 | Failures: 0
```

These logs are captured automatically by Datto RMM and most other RMM platforms.

---

## Notes

- The registry policy (`PasswordManagerEnabled = 0`) persists after the script runs and will prevent Edge from saving passwords going forward.
- If a file deletion fails (exit code `1`), it is likely still locked by an Edge process. Re-running the script after ensuring Edge is fully closed should resolve this.
- Profiles skipped: `Public`, `Default`, `Default User`, `All Users`.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.  
Attribution is appreciated. If you use or build upon this work, please credit the original author: **Liam J Hammersley**.
