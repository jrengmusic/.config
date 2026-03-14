@echo off
setlocal

set ROOT=%~1
set SCHEME=%~2
set FORMAT=%~3
if "%SCHEME%"=="" set SCHEME=Debug
if "%FORMAT%"=="" set FORMAT=VST3
set BUILD_DIR=%ROOT%\Builds\Ninja

:: Find vcvarsall.bat via vswhere
set VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe
if not exist "%VSWHERE%" (
    echo ERROR: vswhere.exe not found. Is Visual Studio installed?
    exit /b 1
)

for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -property installationPath`) do set VS_PATH=%%i

set VCVARSALL=%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat
if not exist "%VCVARSALL%" (
    echo ERROR: vcvarsall.bat not found at %VCVARSALL%
    exit /b 1
)

echo Setting up MSVC x64 environment...
call "%VCVARSALL%" x64

:: Check if reconfiguration is needed
if not exist "%BUILD_DIR%\CMakeCache.txt" goto :configure
if not exist "%BUILD_DIR%\build.ninja" goto :configure
goto :build

:configure
echo Configuring CMake (%SCHEME%)...
if not exist "%ROOT%\Builds" mkdir "%ROOT%\Builds"
cmake -S "%ROOT%" -B "%BUILD_DIR%" -G Ninja -DCMAKE_BUILD_TYPE=%SCHEME% -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
if errorlevel 1 ( echo CMake configure FAILED & exit /b 1 )

:build
echo ==========================================
echo Building %FORMAT% (%SCHEME%)...
echo ==========================================
cmake --build "%BUILD_DIR%" --config %SCHEME%
if errorlevel 1 ( echo Build FAILED & exit /b 1 )

echo ==========================================
echo Copying %FORMAT% to system directory...
echo ==========================================

if "%FORMAT%"=="VST3" (
    for /d %%d in ("%BUILD_DIR%\*.vst3") do (
        echo Copying %%~nxd...
        xcopy /E /Y /I "%%d" "C:\Program Files\Common Files\VST3\%%~nxd" >nul
        echo OK: %%~nxd
    )
)

if "%FORMAT%"=="VST" (
    for %%d in ("%BUILD_DIR%\*.dll") do (
        echo Copying %%~nxd...
        copy /Y "%%d" "C:\Program Files\Common Files\VST2\" >nul
        echo OK: %%~nxd
    )
)

if "%FORMAT%"=="Standalone" (
    echo Standalone app built - no copy needed.
)

echo ==========================================
echo %FORMAT% (%SCHEME%) build complete.
echo ==========================================
endlocal
