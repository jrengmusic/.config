@echo off
setlocal

set ROOT=%~1
if "%ROOT%"=="" set ROOT=.
set BUILD_DIR=%ROOT%\Builds\Ninja

echo ==========================================
echo Cleaning Ninja build directory...
echo ==========================================

if exist "%BUILD_DIR%" (
    rmdir /s /q "%BUILD_DIR%"
)

echo Clean complete.
endlocal
