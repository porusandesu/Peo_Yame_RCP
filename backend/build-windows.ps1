$ErrorActionPreference = "Stop"

$sqliteVersion = "3500400"
$sqliteArchiveName = "sqlite-tools-win-x64-$sqliteVersion.zip"
$sqliteUrl = "https://www.sqlite.org/2025/$sqliteArchiveName"
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("peo-yame-build-" + [guid]::NewGuid().ToString("N"))
$sqliteArchive = Join-Path $temporaryDirectory $sqliteArchiveName
$sqliteExtracted = Join-Path $temporaryDirectory "sqlite"
$vendorDirectory = Join-Path $PSScriptRoot "vendor"
$distributionDirectory = Join-Path $PSScriptRoot "dist"
$runtimeDirectory = Join-Path $distributionDirectory "runtime"
$sqliteAsset = Join-Path $vendorDirectory "sqlite3.exe"
$iconPath = Join-Path $PSScriptRoot "..\Peo_Yame_logo_assets\Peo_Yame_Dev_Assets\windows\PeoYame.ico"
$launcherSource = Join-Path $PSScriptRoot "WindowsLauncher.cs"
$pkgCacheDirectory = Join-Path $temporaryDirectory "pkg-cache"
$createdSqliteAsset = $false

New-Item -ItemType Directory -Path $temporaryDirectory, $sqliteExtracted, $vendorDirectory, $distributionDirectory, $runtimeDirectory -Force | Out-Null

try {
  $sqliteExecutablePath = $env:SQLITE3_PATH
  if (-not $sqliteExecutablePath -or -not (Test-Path $sqliteExecutablePath)) {
    Write-Host "Downloading the official SQLite command-line tools..."
    Invoke-WebRequest -Uri $sqliteUrl -OutFile $sqliteArchive
    Expand-Archive -Path $sqliteArchive -DestinationPath $sqliteExtracted -Force
    $sqliteExecutable = Get-ChildItem -Path $sqliteExtracted -Filter "sqlite3.exe" -Recurse | Select-Object -First 1
    if (-not $sqliteExecutable) { throw "sqlite3.exe was not found in the official SQLite tools archive." }
    $sqliteExecutablePath = $sqliteExecutable.FullName
  }
  if (-not (Test-Path $sqliteAsset)) {
    Copy-Item -Path $sqliteExecutablePath -Destination $sqliteAsset
    $createdSqliteAsset = $true
  }

  if (-not (Test-Path $iconPath)) { throw "The Peo Yame Windows icon was not found at $iconPath." }
  if (-not (Test-Path $launcherSource)) { throw "The Windows tray launcher source was not found at $launcherSource." }

  $previousPkgCache = $env:PKG_CACHE_PATH
  $env:PKG_CACHE_PATH = $pkgCacheDirectory
  Write-Host "Building the standalone Windows backend runtime..."
  $backendExecutable = Join-Path $runtimeDirectory "Peo-Yame-Backend-Core.exe"
  npx --yes pkg@5.8.1 package.json --targets node18-win-x64 --output $backendExecutable --compress GZip
  if ($LASTEXITCODE -ne 0) { throw "The Windows backend package failed with exit code $LASTEXITCODE." }

  Write-Host "Building the branded system-tray launcher..."
  $csharpCompiler = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
  if (-not (Test-Path $csharpCompiler)) {
    $csharpCompiler = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"
  }
  if (-not (Test-Path $csharpCompiler)) { throw "The Windows C# compiler was not found." }
  $launcherExecutable = Join-Path $distributionDirectory "Peo-Yame-Backend.exe"
  & $csharpCompiler /nologo /target:winexe /r:System.Windows.Forms.dll /r:System.Drawing.dll "/win32icon:$iconPath" "/out:$launcherExecutable" $launcherSource
  if ($LASTEXITCODE -ne 0) { throw "The Windows system-tray launcher build failed with exit code $LASTEXITCODE." }

  Write-Host "Smoke-testing packaged backend startup and its HTTP endpoints..."
  $smokeDataDirectory = Join-Path $temporaryDirectory "runtime-data"
  $smokeOutput = Join-Path $temporaryDirectory "startup.stdout.log"
  $smokeError = Join-Path $temporaryDirectory "startup.stderr.log"
  $previousDataDirectory = $env:APP_DATA_DIR
  $previousDatabasePath = $env:DATABASE_PATH
  $previousActionLogPath = $env:ACTION_LOG_PATH
  $previousSqlitePath = $env:SQLITE3_PATH
  $previousPort = $env:PORT
  $previousHost = $env:HOST
  $previousNoBrowser = $env:NO_BROWSER
  $env:APP_DATA_DIR = $smokeDataDirectory
  $env:DATABASE_PATH = Join-Path $smokeDataDirectory "storage-monitor.sqlite"
  $env:ACTION_LOG_PATH = Join-Path $smokeDataDirectory "actions.jsonl"
  Remove-Item Env:SQLITE3_PATH -ErrorAction SilentlyContinue
  $env:PORT = "3188"
  $env:HOST = "127.0.0.1"
  $env:NO_BROWSER = "1"
  $smokeProcess = Start-Process -FilePath $backendExecutable -PassThru -NoNewWindow -RedirectStandardOutput $smokeOutput -RedirectStandardError $smokeError
  try {
    $health = $null
    for ($attempt = 0; $attempt -lt 45; $attempt++) {
      if ($smokeProcess.HasExited) {
        $stdoutText = if (Test-Path $smokeOutput) { Get-Content $smokeOutput -Raw } else { "" }
        $stderrText = if (Test-Path $smokeError) { Get-Content $smokeError -Raw } else { "" }
        throw "The packaged backend exited during startup. $stdoutText $stderrText"
      }
      try {
        $health = Invoke-RestMethod -Uri "http://127.0.0.1:3188/api/health" -TimeoutSec 2
        break
      } catch { Start-Sleep -Seconds 1 }
    }
    if (-not $health -or $health.status -ne "ok") { throw "The packaged backend did not become healthy within 45 seconds." }
    $page = Invoke-WebRequest -Uri "http://127.0.0.1:3188/" -UseBasicParsing -TimeoutSec 5
    if ($page.StatusCode -ne 200) { throw "The packaged web dashboard did not return HTTP 200." }
    $crops = Invoke-RestMethod -Uri "http://127.0.0.1:3188/api/crops" -TimeoutSec 5
    if (@($crops).Count -lt 24) { throw "The packaged backend did not return all starter crop profiles." }
    if (-not (Test-Path $env:DATABASE_PATH)) { throw "The packaged backend did not create its SQLite database." }
    Write-Host "Packaged backend smoke test passed: health, dashboard, crops and user data database."
  }
  finally {
    if (-not $smokeProcess.HasExited) { Stop-Process -Id $smokeProcess.Id -Force }
    if ($null -eq $previousDataDirectory) { Remove-Item Env:APP_DATA_DIR -ErrorAction SilentlyContinue } else { $env:APP_DATA_DIR = $previousDataDirectory }
    if ($null -eq $previousDatabasePath) { Remove-Item Env:DATABASE_PATH -ErrorAction SilentlyContinue } else { $env:DATABASE_PATH = $previousDatabasePath }
    if ($null -eq $previousActionLogPath) { Remove-Item Env:ACTION_LOG_PATH -ErrorAction SilentlyContinue } else { $env:ACTION_LOG_PATH = $previousActionLogPath }
    if ($null -eq $previousSqlitePath) { Remove-Item Env:SQLITE3_PATH -ErrorAction SilentlyContinue } else { $env:SQLITE3_PATH = $previousSqlitePath }
    if ($null -eq $previousPort) { Remove-Item Env:PORT -ErrorAction SilentlyContinue } else { $env:PORT = $previousPort }
    if ($null -eq $previousHost) { Remove-Item Env:HOST -ErrorAction SilentlyContinue } else { $env:HOST = $previousHost }
    if ($null -eq $previousNoBrowser) { Remove-Item Env:NO_BROWSER -ErrorAction SilentlyContinue } else { $env:NO_BROWSER = $previousNoBrowser }
    if ($null -eq $previousPkgCache) { Remove-Item Env:PKG_CACHE_PATH -ErrorAction SilentlyContinue } else { $env:PKG_CACHE_PATH = $previousPkgCache }
  }

  $instructions = @'
PEO YAME STORAGE MONITOR - WINDOWS QUICK START

1. Extract this folder somewhere convenient.
2. Double-click Peo-Yame-Backend.exe. Peo Yame starts quietly in the system tray.
3. Right-click its tray icon and choose Open Peo Yame dashboard.
4. To connect a phone, use the dashboard's connection instructions. Keep the
   phone and Windows PC on the same Wi-Fi network and allow Peo Yame through the
   Windows firewall on private networks if Windows asks.
5. Use the tray menu to restart or stop the backend, or choose Exit Peo Yame to
   stop the backend and close the tray app.

Your database and action history are stored in your Windows user profile under
Local AppData\Peo Yame\data. No Node.js or SQLite installation is required.
'@
  Set-Content -Path (Join-Path $distributionDirectory "Read Me - Start Here.txt") -Value $instructions -Encoding UTF8

  $zipPath = Join-Path $distributionDirectory "Peo-Yame-Backend.zip"
  Copy-Item -Path (Join-Path $PSScriptRoot "Stop Peo Yame.bat") -Destination $distributionDirectory -Force
  Compress-Archive -Path $launcherExecutable, $runtimeDirectory, (Join-Path $distributionDirectory "Stop Peo Yame.bat"), (Join-Path $distributionDirectory "Read Me - Start Here.txt") -DestinationPath $zipPath -Force
  Write-Host "Ready: $zipPath"
}
finally {
  Remove-Item -Path $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
  if ($createdSqliteAsset) { Remove-Item -Path $sqliteAsset -Force -ErrorAction SilentlyContinue }
}
