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
$rceditExecutable = Join-Path $temporaryDirectory "rcedit-x64.exe"
$rceditUrl = "https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe"
$applicationIcon = Join-Path $PSScriptRoot "..\assets\branding\peo-yame.ico"
$pkgCacheDirectory = Join-Path $temporaryDirectory "pkg-cache"
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

  Write-Host "Preparing the Peo Yame Windows application icon..."
  Invoke-WebRequest -Uri $rceditUrl -OutFile $rceditExecutable
  if (-not (Test-Path $applicationIcon)) { throw "The Peo Yame Windows icon was not found at $applicationIcon." }

  $previousPkgCache = $env:PKG_CACHE_PATH
  $env:PKG_CACHE_PATH = $pkgCacheDirectory
  Write-Host "Preparing the standalone Windows runtime..."
  $backendExecutable = Join-Path $distributionDirectory "Peo-Yame-Backend.exe"
  npx --yes pkg@5.8.1 package.json --targets node18-win-x64 --output $backendExecutable --compress GZip
  if ($LASTEXITCODE -ne 0) { throw "The Windows executable build failed with exit code $LASTEXITCODE." }

  # pkg appends its application snapshot to a cached Node runtime. Apply the
  # icon to that base runtime, then package again so its appended payload stays intact.
  $runtimeBinary = Get-ChildItem -Path $pkgCacheDirectory -Recurse -File -Filter "fetched-v18.5.0-win-x64" | Select-Object -First 1
  if (-not $runtimeBinary) { throw "The pkg Windows runtime was not found in its cache." }
  & $rceditExecutable $runtimeBinary.FullName --set-icon $applicationIcon
  if ($LASTEXITCODE -ne 0) { throw "Could not set the Peo Yame icon on the Windows runtime." }

  Write-Host "Building the branded standalone Windows executable..."
  npx --yes pkg@5.8.1 package.json --targets node18-win-x64 --output $backendExecutable --compress GZip
  if ($LASTEXITCODE -ne 0) { throw "The branded Windows executable build failed with exit code $LASTEXITCODE." }

  # Reapply branding to the finished package as pkg may retain the stock icon
  # from its cached runtime when it creates the distributable executable.
  & $rceditExecutable $backendExecutable --set-icon $applicationIcon
  if ($LASTEXITCODE -ne 0) { throw "Could not set the Peo Yame icon on the packaged executable." }

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
    if ($null -eq $previousPkgCache) { Remove-Item Env:PKG_CACHE_PATH -ErrorAction SilentlyContinue } else { $env:PKG_CACHE_PATH = $previousPkgCache }
  }

  $instructions = @'
PEO YAME - QUICK START

1. Extract this folder somewhere easy to find.
2. Double-click "Start Peo Yame.vbs". Your dashboard opens in your browser.
3. To use your phone, put it on the same Wi-Fi, open Connect mobile app on the
   dashboard, then scan the code in Peo Yame Settings.
4. To stop Peo Yame, double-click "Stop Peo Yame.bat".

Your information is saved on this computer. You do not need to install anything.
'@
  Set-Content -Path (Join-Path $distributionDirectory "Read Me - Start Here.txt") -Value $instructions -Encoding UTF8

  $zipPath = Join-Path $distributionDirectory "Peo-Yame-Backend.zip"
  Copy-Item -Path (Join-Path $PSScriptRoot "Start Peo Yame.vbs"), (Join-Path $PSScriptRoot "Stop Peo Yame.bat") -Destination $distributionDirectory -Force
  Compress-Archive -Path (Join-Path $distributionDirectory "Peo-Yame-Backend.exe"), (Join-Path $distributionDirectory "Start Peo Yame.vbs"), (Join-Path $distributionDirectory "Stop Peo Yame.bat"), (Join-Path $distributionDirectory "Read Me - Start Here.txt") -DestinationPath $zipPath -Force
  Write-Host "Ready: $zipPath"
}
finally {
  Remove-Item -Path $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
  if ($createdSqliteAsset) { Remove-Item -Path $sqliteAsset -Force -ErrorAction SilentlyContinue }
}
