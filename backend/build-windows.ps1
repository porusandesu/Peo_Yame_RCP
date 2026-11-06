$ErrorActionPreference = "Stop"

$sqliteVersion = "3500400"
$sqliteArchiveName = "sqlite-tools-win-x64-$sqliteVersion.zip"
$sqliteUrl = "https://www.sqlite.org/2025/$sqliteArchiveName"
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("peo-yame-build-" + [guid]::NewGuid().ToString("N"))
$sqliteArchive = Join-Path $temporaryDirectory $sqliteArchiveName
$sqliteExtracted = Join-Path $temporaryDirectory "sqlite"
$vendorDirectory = Join-Path $PSScriptRoot "vendor"
$distributionDirectory = Join-Path $PSScriptRoot "dist"
$sqliteAsset = Join-Path $vendorDirectory "sqlite3.exe"
$createdSqliteAsset = $false

New-Item -ItemType Directory -Path $temporaryDirectory, $sqliteExtracted, $vendorDirectory, $distributionDirectory -Force | Out-Null

try {
  Write-Host "Preparing the bundled SQLite helper..."
  Invoke-WebRequest -Uri $sqliteUrl -OutFile $sqliteArchive
  Expand-Archive -Path $sqliteArchive -DestinationPath $sqliteExtracted -Force
  $sqliteExecutable = Get-ChildItem -Path $sqliteExtracted -Filter "sqlite3.exe" -Recurse | Select-Object -First 1
  if (-not $sqliteExecutable) { throw "sqlite3.exe was not found in the official SQLite tools archive." }
  if (-not (Test-Path $sqliteAsset)) {
    Copy-Item -Path $sqliteExecutable.FullName -Destination $sqliteAsset
    $createdSqliteAsset = $true
  }

  Write-Host "Building the standalone Windows executable..."
  npx --yes pkg@5.8.1 launcher.js --targets node18-win-x64 --output (Join-Path $distributionDirectory "Peo-Yame-Backend.exe") --compress GZip
  if ($LASTEXITCODE -ne 0) { throw "The Windows executable build failed with exit code $LASTEXITCODE." }

  Write-Host "Starting the built executable for a startup check..."
  $smokeDataDirectory = Join-Path $temporaryDirectory "runtime-data"
  $smokeOutput = Join-Path $temporaryDirectory "startup.stdout.log"
  $smokeError = Join-Path $temporaryDirectory "startup.stderr.log"
  $previousDataDirectory = $env:APP_DATA_DIR
  $previousPort = $env:PORT
  $previousHost = $env:HOST
  $previousNoBrowser = $env:NO_BROWSER
  $env:APP_DATA_DIR = $smokeDataDirectory
  $env:PORT = "3188"
  $env:HOST = "127.0.0.1"
  $env:NO_BROWSER = "1"
  $smokeProcess = Start-Process -FilePath (Join-Path $distributionDirectory "Peo-Yame-Backend.exe") -PassThru -NoNewWindow -RedirectStandardOutput $smokeOutput -RedirectStandardError $smokeError
  $health = $null
  try {
    for ($attempt = 0; $attempt -lt 45; $attempt++) {
      if ($smokeProcess.HasExited) {
        $stdoutText = if (Test-Path $smokeOutput) { Get-Content $smokeOutput -Raw } else { "" }
        $stderrText = if (Test-Path $smokeError) { Get-Content $smokeError -Raw } else { "" }
        throw "The EXE exited during startup. $stdoutText $stderrText"
      }
      try {
        $health = Invoke-RestMethod -Uri "http://127.0.0.1:3188/api/health" -TimeoutSec 2
        break
      } catch {
        Start-Sleep -Seconds 1
      }
    }
    if (-not $health -or $health.status -ne "ok") { throw "The EXE did not become healthy within 45 seconds." }
    $null = Invoke-WebRequest -Uri "http://127.0.0.1:3188/" -UseBasicParsing -TimeoutSec 5
    if (-not (Test-Path (Join-Path $smokeDataDirectory "storage-monitor.sqlite"))) { throw "The EXE did not create its user database." }
    Write-Host "Packaged EXE startup check passed."
  }
  finally {
    if (-not $smokeProcess.HasExited) { Stop-Process -Id $smokeProcess.Id -Force }
    if ($null -eq $previousDataDirectory) { Remove-Item Env:APP_DATA_DIR -ErrorAction SilentlyContinue } else { $env:APP_DATA_DIR = $previousDataDirectory }
    if ($null -eq $previousPort) { Remove-Item Env:PORT -ErrorAction SilentlyContinue } else { $env:PORT = $previousPort }
    if ($null -eq $previousHost) { Remove-Item Env:HOST -ErrorAction SilentlyContinue } else { $env:HOST = $previousHost }
    if ($null -eq $previousNoBrowser) { Remove-Item Env:NO_BROWSER -ErrorAction SilentlyContinue } else { $env:NO_BROWSER = $previousNoBrowser }
  }

  $instructions = @'
PEO YAME STORAGE MONITOR - WINDOWS BACKEND

1. Extract this ZIP file to a folder you can write to, such as your Desktop.
2. Double-click Peo-Yame-Backend.exe.
3. Your dashboard opens in your web browser. Keep the black server window open
   while using the dashboard; close that window to stop the backend.

Your saved readings and activity log are kept in your Windows Local AppData folder.
No Node.js, npm, SQLite installation, or command prompt knowledge is needed.

To use the dashboard from a phone on the same Wi-Fi, open the PC's local network
address in the phone browser. The backend uses plain local-network HTTP and is
intended only for a controlled demonstration.
'@
  Set-Content -Path (Join-Path $distributionDirectory "Read Me - Start Here.txt") -Value $instructions -Encoding UTF8

  $zipPath = Join-Path $distributionDirectory "Peo-Yame-Backend.zip"
  Compress-Archive -Path (Join-Path $distributionDirectory "Peo-Yame-Backend.exe"), (Join-Path $distributionDirectory "Read Me - Start Here.txt") -DestinationPath $zipPath -Force
  Write-Host "Ready: $zipPath"
}
finally {
  Remove-Item -Path $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
  if ($createdSqliteAsset) { Remove-Item -Path $sqliteAsset -Force -ErrorAction SilentlyContinue }
}
