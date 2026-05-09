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
    "newlogin" {
        Stop-Codex
        if (Test-Path $AuthFile) { Remove-Item $AuthFile -Force }
        Write-Host "Opening new account login flow..." -ForegroundColor Yellow
        codex auth login
        Write-Host "Done. Run: codex-account save NAME" -ForegroundColor Cyan
    }

    "save" {
        if (-not $AccountName) { Write-Error "Please provide a name."; return }
        Copy-Item -Path $AuthFile -Destination "$StorageDir\$AccountName.auth.json" -Force
        $AccountName | Out-File -FilePath $CurrentMarker -Encoding utf8
        Write-Host "Account '$AccountName' saved locally." -ForegroundColor Green
    }

    "push" {
        Write-Host "Pushing accounts to GCP ($GCSBucket)..." -ForegroundColor Cyan
        gcloud storage cp "$StorageDir\*.auth.json" "$GCSBucket/accounts/"
        Write-Host "Upload complete." -ForegroundColor Green
    }

    "pull" {
        Write-Host "Pulling accounts from GCP..." -ForegroundColor Cyan
        gcloud storage cp "$GCSBucket/accounts/*.auth.json" "$StorageDir/"
        Write-Host "Download complete." -ForegroundColor Green
    }

    "list" {
        $LiveHash = if (Test-Path $AuthFile) { (Get-FileHash $AuthFile).Hash } else { "" }
        $accounts = @(Get-ChildItem $StorageDir -Filter *.auth.json | Where-Object { $_.Name -notmatch "-backup" } | ForEach-Object {
            $_.BaseName.Replace(".auth", "")
        })

        if ($accounts.Count -eq 0) { Write-Host "No saved accounts." -ForegroundColor Yellow; return }

        $cursor = 0

        function Ensure-MenuBuffer($menuTop, $itemCount) {
            $requiredHeight = [Math]::Max($menuTop + $itemCount + 2, [Console]::WindowHeight + 1)
            if ([Console]::BufferHeight -lt $requiredHeight) {
                try {
                    [Console]::SetBufferSize([Console]::BufferWidth, $requiredHeight)
                } catch {
                    # If the host refuses buffer resizing, keep going and rely on the current buffer.
                }
            }
        }

        function Write-MenuLine($index, $selected, $accounts, $LiveHash) {
            $targetTop = $script:menuTop + $index
            Ensure-MenuBuffer $script:menuTop $accounts.Count
            if ($targetTop -ge [Console]::BufferHeight) { return }
            [Console]::SetCursorPosition(0, $targetTop)
            $name = $accounts[$index]
            $isLive = ($LiveHash -eq (Get-FileHash "$StorageDir\$name.auth.json").Hash)
            $label = if ($isLive) { "** $name (active)" } else { "   $name" }

            if ($selected) {
                Write-Host ($label.PadRight(40)) -NoNewline -ForegroundColor Black -BackgroundColor Green
            } else {
                $color = if ($isLive) { "Green" } else { "White" }
                Write-Host ($label.PadRight(40)) -NoNewline -ForegroundColor $color
            }
        }

        Write-Host ""
        Write-Host "Saved Accounts (arrows to move, Enter to switch, Esc to cancel):" -ForegroundColor Gray
        Write-Host ""
        $script:menuTop = [Console]::CursorTop
        Ensure-MenuBuffer $script:menuTop $accounts.Count
        for ($i = 0; $i -lt $accounts.Count; $i++) {
            Write-Host ""
        }

        for ($i = 0; $i -lt $accounts.Count; $i++) {
            Write-MenuLine $i ($i -eq $cursor) $accounts $LiveHash
        }

        while ($true) {
            $key = [Console]::ReadKey($true)
            $previousCursor = $cursor

            if     ($key.Key -eq 'UpArrow')   { $cursor = ($cursor - 1 + $accounts.Count) % $accounts.Count }
            elseif ($key.Key -eq 'DownArrow') { $cursor = ($cursor + 1) % $accounts.Count }
            elseif ($key.Key -eq 'Enter') {
                [Console]::SetCursorPosition(0, $script:menuTop + $accounts.Count)
                Write-Host ""
                & $PSCommandPath "switch" $accounts[$cursor]
                return
            }
            elseif ($key.Key -eq 'Escape') {
                [Console]::SetCursorPosition(0, $script:menuTop + $accounts.Count)
                Write-Host ""
                return
            }

            if ($cursor -ne $previousCursor) {
                Write-MenuLine $previousCursor $false $accounts $LiveHash
                Write-MenuLine $cursor $true $accounts $LiveHash
            }
        }
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
            Write-Host "Switched to '$AccountName'." -ForegroundColor Green
        } else {
            Write-Error "Account '$AccountName' not found."
        }
    }

    Default {
        if ($Action -and (Test-Path "$StorageDir\$Action.auth.json")) {
            & $PSCommandPath "switch" $Action
        } else {
            Write-Host "Usage: codex-account [newlogin | save | push | pull | list | NAME]"
        }
    }
}