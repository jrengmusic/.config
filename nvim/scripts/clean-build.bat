@echo off
setlocal

set ROOT=%~1
if "%ROOT%"=="" set ROOT=.
set BUILD_DIR=%ROOT%\Builds\Ninja

echo ==========================================
echo Cleaning Ninja build directory...
echo ==========================================

:: Kill any dangling cmake/ninja instance still holding this project's build
:: tree (can happen if a previous build was abruptly interrupted). Scoped by
:: command line to this BUILD_DIR specifically — never touches cmake/ninja
:: instances building something else elsewhere.
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='cmake.exe' or Name='ninja.exe'\" | Where-Object { $_.CommandLine -like '*%BUILD_DIR%*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>nul

if exist "%BUILD_DIR%" (
    rmdir /s /q "%BUILD_DIR%"
)

echo Clean complete.
endlocal
