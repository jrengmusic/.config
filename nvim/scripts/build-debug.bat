@echo off
chcp 65001 >nul
echo         ██████  ██████████████  ████████████  ████      ████      ██████████  ████
echo         ██████  ██████████████  ████████████  ██████    ████    ████████████  ████
echo         ░░████  ████░░░░░░████  ████░░░░░░░░  ████████  ████  ██████░░░░░░░░  ████
echo ████      ████  ████    ██████  ████████      ██████████████  ████░░    ████  ████
echo ██████    ████  ████████████░░  ████░░░░      ████░░████████  ████      ████  ████
echo ░░████████████  ████████████    ████████████  ████  ░░██████  ██████████████  ░░░░
echo   ░░██████████  ████░░░░██████  ████████████  ████    ░░████  ██████████████  ████
echo     ░░░░░░░░░░  ░░░░    ░░░░░░  ░░░░░░░░░░░░  ░░░░      ░░░░  ░░░░░░░░░░░░░░  ░░░░
echo.
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
:: Memory-aware parallelism: jobs = min(cores/2, (RAM_GB - reserve) / per-job).
:: A JUCE debug TU peaks around 1GB per cl.exe instance; the reserve covers
:: OS + nvim + clangd + a running app/DAW. On a low-RAM machine cores/2
:: alone overcommits physical memory - the OS then evicts the editor's
:: working set and every page-in contends with link.exe's PDB writes
:: (measured: nvim RSS 41MB -> 12MB, 23k page faults, 6.9s UI stalls).
:: Fewer non-thrashing jobs beat more thrashing ones in wall-clock too.
set RAM_RESERVE_GB=3
set RAM_PER_JOB_GB=1
set /a HALF_CORES=%NUMBER_OF_PROCESSORS%/2
for /f %%m in ('powershell -NoProfile -Command "[math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)"') do set TOTAL_RAM_GB=%%m
set /a RAM_JOBS=(%TOTAL_RAM_GB%-%RAM_RESERVE_GB%)/%RAM_PER_JOB_GB%
if %RAM_JOBS% lss 1 set RAM_JOBS=1
set BUILD_JOBS=%HALF_CORES%
if %RAM_JOBS% lss %HALF_CORES% set BUILD_JOBS=%RAM_JOBS%
echo Parallel jobs: %BUILD_JOBS% (cores/2=%HALF_CORES%, ram-capped=%RAM_JOBS%)
cmake --build "%BUILD_DIR%" --config %SCHEME% --target %TARGET% --parallel %BUILD_JOBS%
if errorlevel 1 ( echo Build FAILED & exit /b 1 )

:: Copy-to-system-directory is owned by PluginBuilder.cmake/AppBuilder.cmake
:: POST_BUILD steps (JUCE's COPY_PLUGIN_AFTER_BUILD, plus AAX wraptool
:: signing for Release) — never duplicated here. A second copy after
:: cmake --build returns would re-copy the raw artifact straight from the
:: Ninja build tree over cmake's already-placed system-path copy.
echo ==========================================
echo %FORMAT% (%SCHEME%) build complete.
echo ==========================================
endlocal
