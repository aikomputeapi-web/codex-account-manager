param(
    [Parameter(Mandatory=$false, Position=0)]
    [string]$Action,

    [Parameter(Mandatory=$false, Position=1)]
    [string]$AccountName
)

# --- Configuration ---
$CodexDir      = "$HOME\.codex"
$StorageDir    = "$CodexDir\.codex-account\accounts"
$AuthFile      = "$CodexDir\auth.json"
$CurrentMarker = "$CodexDir\.codex-account\current"
$CodexPath     = "$env:LocalAppData\Programs\codex\Codex.exe"

# --- GCP Cloud Storage Config ---
$GCSBucket     = "gs://YOUR_BUCKET_NAME_HERE" 

# Ensure storage directories exist
if (!(Test-Path $StorageDir)) { New-Item -ItemType Directory -Path $StorageDir -Force | Out-Null }

# --- Helper Functions ---
function Stop-Codex {
    Write-Host "Closing Codex..." -ForegroundColor Gray
    Stop-Process -Name "Codex" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# --- Command Logic ---
switch ($Action) {
    "login" {
        Stop-Codex
        if (Test-Path $AuthFile) { Remove-Item $AuthFile -Force }
        Write-Host "Opening login flow..." -ForegroundColor Yellow
        codex auth login
        Write-Host "✔ Done. Run: codex-account save <name>" -ForegroundColor Cyan
    }

    "save" {
        if (-not $AccountName) { Write-Error "Please provide a name."; return }
        Copy-Item -Path $AuthFile -Destination "$StorageDir\$AccountName.auth.json" -Force
        $AccountName | Out-File -FilePath $CurrentMarker -Encoding utf8
        Write-Host "✔ Account '$AccountName' saved locally." -ForegroundColor Green
    }

    "push" {
        Write-Host "Pushing accounts to GCP ($GCSBucket)..." -ForegroundColor Cyan
        gcloud storage cp "$StorageDir\*.auth.json" "$GCSBucket/accounts/"
        Write-Host "✔ Upload complete." -ForegroundColor Green
    }

    "pull" {
        Write-Host "Pulling accounts from GCP..." -ForegroundColor Cyan
        gcloud storage cp "$GCSBucket/accounts/*.auth.json" "$StorageDir/"
        Write-Host "✔ Download complete." -ForegroundColor Green
    }

    "list" {
        $LiveHash = if (Test-Path $AuthFile) { (Get-FileHash $AuthFile).Hash } else { "" }
        Write-Host "`nSaved Accounts:" -ForegroundColor Gray
        
        Get-ChildItem $StorageDir -Filter *.auth.json | Where-Object { $_.Name -notmatch "-backup" } | ForEach-Object {
            $name = $_.BaseName.Replace(".auth", "")
            $isLive = ($LiveHash -eq (Get-FileHash $_.FullName).Hash)
            
            if ($isLive) {
                Write-Host "  * $name (active)" -ForegroundColor Green
            } else {
                Write-Host "    $name" -ForegroundColor White
            }
        }
        Write-Host ""
    }

    "switch" {
        $Source = "$StorageDir\$AccountName.auth.json"
        if (Test-Path $Source) {
            Stop-Codex
            $CurrentAcc = if (Test-Path $CurrentMarker) { Get-Content $CurrentMarker } else { "unknown" }
            
            # Backup current before swapping
            if (Test-Path $AuthFile) {
                Copy-Item -Path $AuthFile -Destination "$StorageDir\$CurrentAcc-backup.auth.json" -Force
            }

            Copy-Item -Path $Source -Destination $AuthFile -Force
            $AccountName | Out-File -FilePath $CurrentMarker -Encoding utf8
            
            if (Test-Path $CodexPath) { Start-Process $CodexPath }
            Write-Host "✔ Switched to '$AccountName'." -ForegroundColor Green
        } else {
            Write-Error "Account '$AccountName' not found."
        }
    }

    Default {
        if ($Action -and (Test-Path "$StorageDir\$Action.auth.json")) {
            & $PSCommandPath "switch" $Action
        } else {
            Write-Host "Usage: codex-account [login | save | push | pull | list | <name>]"
        }
    }
}