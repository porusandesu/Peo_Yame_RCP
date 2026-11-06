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
  npx --yes pkg@5.8.1 server.js --targets node18-win-x64 --output (Join-Path $distributionDirectory "Peo-Yame-Backend.exe") --compress GZip
  if ($LASTEXITCODE -ne 0) { throw "The Windows executable build failed with exit code $LASTEXITCODE." }

  $instructions = @'
PEO YAME STORAGE MONITOR - WINDOWS BACKEND

1. Extract this ZIP file to a folder you can write to, such as your Desktop.
2. Double-click Peo-Yame-Backend.exe.
3. Your dashboard opens in your web browser. Keep the black server window open
   while using the dashboard; close that window to stop the backend.

Your saved readings and activity log are kept in the data folder beside the EXE.
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
