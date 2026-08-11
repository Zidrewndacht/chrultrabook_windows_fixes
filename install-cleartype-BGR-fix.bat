@echo off
setlocal EnableDelayedExpansion

:: Self-elevate if not admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb runAs"
    exit /b
)

set "PS1=%~dp0cleartype.ps1"
set "TASK=ClearTypeRotationMonitor"

if not exist "%PS1%" (
    echo ERROR: cleartype.ps1 not found in same folder as this batch file.
    pause
    exit /b 1
)

echo Installing scheduled task: %TASK%

:: Delete old task if exists
schtasks /Delete /TN "%TASK%" /F >nul 2>&1

:: Create new task — run at logon, highest privileges, hidden
schtasks /Create ^
    /TN "%TASK%" ^
    /TR "powershell.exe -WindowStyle Hidden -STA -ExecutionPolicy Bypass -File \"%PS1%\"" ^
    /SC ONLOGON ^
    /RL HIGHEST ^
    /F >nul 2>&1

if %errorLevel% neq 0 (
    echo FAILED to create task via schtasks.
    pause
    exit /b 1
)

:: Remove 3-day execution limit and configure battery-friendly settings
powershell -NoProfile -Command ^
    "$task=Get-ScheduledTask -TaskName '%TASK%' -ErrorAction Stop;" ^
    "$task.Settings.DisallowStartIfOnBatteries=$false;" ^
    "$task.Settings.StopIfGoingOnBatteries=$false;" ^
    "$task.Settings.IdleSettings.StopOnIdleEnd=$false;" ^
    "$task.Settings.ExecutionTimeLimit='PT0S';" ^
    "$task | Set-ScheduledTask | Out-Null"

echo.
echo Task installed successfully.
echo Starting now...

schtasks /Run /TN "%TASK%" >nul 2>&1

echo Done. The monitor is running and will auto-start at logon.
echo.
pause