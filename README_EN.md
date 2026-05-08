# Disable_Win_update 🛡️

> 🌏 [中文版 README](./README.md)

A toolkit for disabling Windows automatic updates, Microsoft PC Manager, and gaming features. It supports both scheduled auto-execution and manual execution, and offers multiple configuration variants to fit different needs.

## 📁 File Overview

| File | Description |
|---|---|
| `0.create_scheduled_task.ps1` | Scheduled-task creation script; sets up timed execution |
| `disable_update_daily.bat` | Main execution script; disables services, applies registry config, and cleans up files |
| `disable_windows_update.reg` | The registry config currently in use |
| `disable_windows_update-mini.reg` | Minimal registry config (disables Windows Update only) |
| `disable_windows_update-nogame.reg` | Game-friendly registry config (Windows Update + PC Manager, leaves gaming features intact) |
| `PsExec.exe` | System utility used for high-privilege execution |
| `0.reset_windows_update.bat` | Resets Windows Update–related services to restore automatic updates |

## 🔧 Registry Configuration Variants

### Full Version (`disable_windows_update.reg`)
- ✅ Disables Windows automatic updates
- ✅ Blocks Microsoft PC Manager installation
- ✅ Disables Xbox Game Bar and gaming features
- ✅ Blocks consumer features and automatic Microsoft Store downloads
- ✅ Disables related system services

### Minimal Version (`disable_windows_update-mini.reg`)
- ✅ Disables Windows automatic updates
- ✅ Basic update-blocking policies
- ❌ Does **not** block PC Manager
- ❌ Does **not** disable gaming features

### Game-Friendly Version (`disable_windows_update-nogame.reg`)
- ✅ Disables Windows automatic updates
- ✅ Blocks Microsoft PC Manager installation
- ✅ Blocks consumer features and automatic Microsoft Store downloads
- ❌ Does **not** disable gaming features

## 📝 How to Choose a Version

| Scenario | Recommended | Notes |
|---|---|---|
| General users, disable everything | **Full** | Most comprehensive; suits most users |
| Gamers | **Game-Friendly** | Keeps gaming features; still blocks updates and PC Manager |
| Maximum compatibility | **Minimal** | Smallest footprint; only disables Windows Update |
| Enterprise environments | **Minimal** or **Game-Friendly** | Choose based on your corporate policy |

## 🔄 Switching Between Versions

1. Back up your current `disable_windows_update.reg`.
2. Rename the variant you want to use to `disable_windows_update.reg`.
3. Re-run the script, or wait for the scheduled task to fire.

## 🚀 Quick Start

### Option 1: Manual Execution

```bat
:: Run as administrator
disable_update_daily.bat
```

### Option 2: Create a Scheduled Task (Recommended)

```powershell
# Normal install: run PowerShell as administrator
.\0.create_scheduled_task.ps1

# Install and test immediately
.\0.create_scheduled_task.ps1 -Test

# Uninstall
.\0.create_scheduled_task.ps1 -Uninstall
```

## ⚙️ Features

- **Service management**: stops and disables update-related services such as `wuauserv`, `UsoSvc`, and `WaaSMedicSvc`.
- **Registry configuration**: applies registry tweaks that disable automatic updates.
- **File cleanup**: removes the `$WINDOWS.~BT` upgrade folder and the `SoftwareDistribution` update cache.
- **Smart triggers**: runs at system startup, on schedule (00:00 / 03:00 / 06:00 / 12:00 / 18:00 / 21:00), or manually.
- **Logging**: records every run in detail, with automatic log-size management (trims to half once the log exceeds 50,000 lines).

## 📊 Trigger Mechanism

| Trigger | Condition | Notes |
|---|---|---|
| System startup | Runs after boot | Ensures updates are disabled every time the PC starts |
| Scheduled | Daily at 00/03/06/12/18/21 | Runs after 3 minutes of user idle time |
| Manual | Double-click the script | Executes immediately |

## 📝 Log File

- **Location**: `update_disable_log.txt`, in the same directory as the script.
- **Contents**: execution time, trigger type, operation results, and error codes.
- **Management**: once the log exceeds 50,000 lines, it's automatically trimmed to keep the most recent 25,000.

## ⚠️ Important Notes

- **Administrator privileges**: all operations require admin rights.
- **Antivirus software**: may flag the scripts — add them to your allowlist.
- **System compatibility**: works on Windows 10 / 11.
- **Backup recommendation**: create a system restore point before first use.
- **Version choice**: pick the registry variant that matches your needs.
- **Gamers**: if you use Xbox-related features, use the game-friendly variant.

## 🔧 Troubleshooting

### Common Error Codes

- `0` — Success
- `2` — Service does not exist or is already stopped
- `5` — Access denied
- `1060` — Service is not installed
- `1062` — Service has not been started

### Inspecting the Logs

Open `update_disable_log.txt` for detailed execution history and error messages. Also verify:

1. The correct registry config file is in place.
2. The script is being run with administrator privileges.
3. Your antivirus is not blocking execution.

### Version-Related Issues

- **Features seem incomplete**: check whether you're using the minimal variant.
- **Game problems**: switch to the game-friendly variant.
- **Compatibility issues**: try the minimal variant.

## 🔄 Restoring Windows Update

If you need to re-enable Windows automatic updates:

```bat
:: Run as administrator
0.reset_windows_update.bat
```

## 📞 Support

If you run into issues, please check:

1. Whether the script was run as administrator.
2. Whether antivirus software is blocking execution.
3. The log file for the specific error.
4. Try switching to the minimal variant to test compatibility.