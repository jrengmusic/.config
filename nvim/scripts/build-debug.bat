@echo off
setlocal

set ROOT=%~1
set SCHEME=%~2
set FORMAT=%~3
if "%SCHEME%"=="" set SCHEME=Debug
if "%FORMAT%"=="" set FORMAT=VST3
:: Scheme-keyed dir, matching build-debug.sh:13 and configurations.lua's
:: own convention (root/Builds/Ninja/<Scheme>) — Ninja is a single-config
:: generator (CMAKE_BUILD_TYPE fixed at configure time, --config is a no-op
:: for it), so Debug/Release must not share one directory or switching
:: scheme silently keeps building whichever was configured first.
set BUILD_DIR=%ROOT%\Builds\Ninja\%SCHEME%

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

if not defined VSCMD_VER (
    echo Setting up MSVC x64 environment...
    call "%VCVARSALL%" x64
)

:: Use VS-bundled ninja (avoids MSYS2 ld.exe conflict)
set PATH=%VS_PATH%\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%

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
:: Find target name for this format — mirrors build-debug.sh:33-42.
:: juce_add_plugin Standalone -> NAME_Standalone; juce_add_gui_app -> bare NAME
set TARGET=
if "%FORMAT%"=="Standalone" (
    for /f "delims=:" %%t in ('ninja -C "%BUILD_DIR%" -t targets ^| findstr /c:"_Standalone: phony"') do if not defined TARGET set TARGET=%%t
    if not defined TARGET (
        :: AppBuilder.cmake pure-app project: no NAME_Standalone target exists,
        :: the app itself is the bare NAME target. Find any phony target that
        :: isn't a known plugin-format suffix or a CMake/JUCE utility target.
        for /f "delims=:" %%t in ('ninja -C "%BUILD_DIR%" -t targets ^| findstr /c:": phony" ^| findstr /v /c:"_VST3: phony" ^| findstr /v /c:"_AU: phony" ^| findstr /v /c:"_AAX: phony" ^| findstr /v /c:"_AUv3: phony" ^| findstr /v /c:"_Unity: phony" ^| findstr /v /c:"_VST: phony" ^| findstr /v /c:"_Standalone: phony" ^| findstr /v /c:"_All: phony" ^| findstr /v /c:"_CLAP: phony" ^| findstr /v /c:"edit_cache: phony" ^| findstr /v /c:"rebuild_cache: phony" ^| findstr /v /c:"install: phony" ^| findstr /v /c:"list_install_components: phony" ^| findstr /v /c:"codegen: phony" ^| findstr /v /c:"_BinaryData"') do if not defined TARGET set TARGET=%%t
    )
) else (
    for /f "delims=:" %%t in ('ninja -C "%BUILD_DIR%" -t targets ^| findstr /c:"_%FORMAT%: phony"') do if not defined TARGET set TARGET=%%t
)

if not defined TARGET (
    echo ERROR: No target found for format %FORMAT%
    exit /b 1
)

echo ==========================================
echo Building %TARGET% (%SCHEME%)...
echo ==========================================
cmake --build "%BUILD_DIR%" --config %SCHEME% --target %TARGET%
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
