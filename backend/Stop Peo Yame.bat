@echo off
taskkill /IM Peo-Yame-Backend-Core.exe /T /F >nul 2>&1
if errorlevel 1 (
  echo Peo Yame is not running.
) else (
  echo Peo Yame has stopped.
)
pause
