# codex-account-windows

A PowerShell utility for switching between multiple Codex accounts by swapping `auth.json` snapshots and synchronizing them via Google Cloud Storage.

This tool is a Windows-optimized port of the [denysdovhan/codex-account](https://github.com/denysdovhan/codex-account) utility, adding native process management and cloud synchronization features.

## ✨ Features

- **Account Snapshots** - Save and name your authenticated sessions to avoid constant re-logging
- **Process Management** - Automatically closes and restarts the Codex app during switches
- **GCP Sync** - Push and pull your account vault to a private Google Cloud Storage bucket
- **Auto-Detection** - Identifies which account is currently "live" based on file hashes
- **Session Safety** - Creates automatic backups when switching accounts

## 📦 Installation

### 1. Setup the Script

1. Create a dedicated folder for your personal scripts (e.g., `C:\Scripts`)
2. Save your script as `codex-account.ps1` into that folder
3. Add that folder path to your Windows PATH Environment Variable

### 2. Create the Command Shim

To run the command simply as `codex-account` from any terminal, create a file named `codex-account.cmd` in the same folder:

```cmd
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0codex-account.ps1" %*
```

### 3. Configure GCP

Open your `codex-account.ps1` file and update the `$GCSBucket` variable with your Google Cloud Storage bucket name:

```powershell
$GCSBucket = "gs://your-bucket-name"
```

## 🚀 Usage

### Saving Accounts

Log into a Codex account normally through the CLI or Browser, then "capture" the session locally:

```powershell
codex-account save personal
```

### Switching Accounts

To move to a different saved account (the script will handle closing and restarting Codex for you):

```powershell
codex-account work
```

### Creating a New Login

Use this command when you want to clear the current Codex auth and sign in to a new account:

```powershell
codex-account newlogin
```

### Cloud Synchronization

Keep your account vault in sync across your local machine and your remote Google Cloud VMs:

**Upload all local accounts to your GCP bucket:**
```powershell
codex-account push
```

**Download cloud accounts to a new machine or VM:**
```powershell
codex-account pull
```

### Managing the Vault

Launch an interactive account picker with `list`. Use arrow keys to navigate, Enter to switch, and Esc to cancel. The active account is marked with `**`, and only the changed rows are redrawn as you move:

```powershell
codex-account list
```

## 📋 Commands Summary

| Command | Description |
|---------|-------------|
| `newlogin` | Kills Codex and clears active auth to allow a fresh login |
| `save [name]` | Saves the active `auth.json` as `[name]` |
| `list` | Interactive picker; `**` marks the active account |
| `push` | Uploads the accounts folder to your GCP bucket |
| `pull` | Downloads the accounts folder from your GCP bucket |
| `[name]` | Shorthand to switch to a specific saved account |

## 🔧 Technical Details

- **Storage Path:** `~/.codex/.codex-account/accounts`
- **Identity Check:** The script uses SHA256 hashes to verify if a saved snapshot matches the live `auth.json`
- **Requirements:** 
  - Google Cloud SDK (for push/pull functionality)
  - PowerShell 5.1+

## 📝 Example Workflow

```powershell
# Save your personal account
codex-account save personal

# Save your work account
codex-account save work

# List all accounts
codex-account list

# Create a new login session
codex-account newlogin

# Switch to work account
codex-account work

# Push accounts to cloud
codex-account push

# On another machine, pull accounts
codex-account pull

# Switch back to personal
codex-account personal
```

## 🛠️ Troubleshooting

**Issue:** Command not recognized
- **Solution:** Ensure the script folder is in your PATH environment variable

**Issue:** Execution policy error
- **Solution:** Run PowerShell as Administrator and execute:
  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

**Issue:** GCP sync fails
- **Solution:** Verify Google Cloud SDK is installed and authenticated:
  ```powershell
  gcloud auth login
  ```

## 📄 License

MIT © Steven LeBlanc (Inspired by Denys Dovhan)

---

**Made for seamless Codex account management on Windows**
