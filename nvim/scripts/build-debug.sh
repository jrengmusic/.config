#!/bin/bash
set -eo pipefail

echo "        ██████  ██████████████  ████████████  ████      ████      ██████████  ████"
echo "        ██████  ██████████████  ████████████  ██████    ████    ████████████  ████"
echo "        ░░████  ████░░░░░░████  ████░░░░░░░░  ████████  ████  ██████░░░░░░░░  ████"
echo "████      ████  ████    ██████  ████████      ██████████████  ████░░    ████  ████"
echo "██████    ████  ████████████░░  ████░░░░      ████░░████████  ████      ████  ████"
echo "░░████████████  ████████████    ████████████  ████  ░░██████  ██████████████  ░░░░"
echo "  ░░██████████  ████░░░░██████  ████████████  ████    ░░████  ██████████████  ████"
echo "    ░░░░░░░░░░  ░░░░    ░░░░░░  ░░░░░░░░░░░░  ░░░░      ░░░░  ░░░░░░░░░░░░░░  ░░░░"
echo ""

# cmake 4.3+ opens interactive TUI when stdin or stdout is a TTY
# exec < /dev/null: nulls stdin for all subprocesses (including cmake spawned by ninja)
# TERM=dumb + 2>&1 | cat on cmake calls: nulls stdout TTY detection
exec < /dev/null
export TERM=dumb

ROOT="$1"
SCHEME="${2:-Debug}"
FORMAT="${3:-VST3}"
BUILD_DIR="$ROOT/Builds/Ninja/$SCHEME"

NO_NOTARIZE=0
for arg in "$@"; do
    case "$arg" in
        nonotarize) NO_NOTARIZE=1 ;;
    esac
done

# Check if reconfiguration is needed
if [ ! -f "$BUILD_DIR/CMakeCache.txt" ] || [ ! -f "$BUILD_DIR/build.ninja" ]; then
    echo "Configuring CMake ($SCHEME)..."
    mkdir -p "$BUILD_DIR"
    NATIVE_ARCH=$(uname -m)
    cmake -S "$ROOT" -B "$BUILD_DIR" -G Ninja \
        -DCMAKE_BUILD_TYPE="$SCHEME" \
        -DCMAKE_OSX_ARCHITECTURES="$NATIVE_ARCH" \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON 2>&1 | cat
fi

# Find target name for this format
# juce_add_plugin Standalone → NAME_Standalone; juce_add_gui_app → bare target NAME
if [ "$FORMAT" = "Standalone" ]; then
    TARGET=$(ninja -C "$BUILD_DIR" -t targets 2>/dev/null | grep -E "_Standalone: phony" | cut -d: -f1 | head -1 || true)
    if [ -z "$TARGET" ]; then
        TARGET=$(ninja -C "$BUILD_DIR" -t targets 2>/dev/null | grep -E "^[A-Za-z][A-Za-z0-9_]*: phony" | grep -v -E "_(VST3|AU|AAX|AUv3|Unity|VST|Standalone|All|CLAP): phony" | grep -v -E "^(edit_cache|rebuild_cache|install|list_install_components|codegen|.*_BinaryData): phony" | cut -d: -f1 | head -1 || true)
    fi
else
    TARGET=$(ninja -C "$BUILD_DIR" -t targets 2>/dev/null | grep -E "_${FORMAT}: phony" | cut -d: -f1 | head -1 || true)
fi

if [ -z "$TARGET" ]; then
    echo "ERROR: No target found for format $FORMAT"
    echo "Available targets:"
    ninja -C "$BUILD_DIR" -t targets 2>/dev/null | grep "phony" | grep -v "cmake" | head -10 || true
    exit 1
fi

echo "=========================================="
echo "Building $TARGET ($SCHEME)..."
echo "=========================================="
# Memory-aware parallelism: jobs = min(cores/2, (RAM_GB - reserve) / per-job).
# Same formula as build-debug.bat — see the rationale comment there. On
# machines with ample RAM this resolves to cores/2 unchanged.
RAM_RESERVE_GB=3
RAM_PER_JOB_GB=1
HALF_CORES=$(( $(sysctl -n hw.ncpu) / 2 ))
TOTAL_RAM_GB=$(( $(sysctl -n hw.memsize) / 1073741824 ))
RAM_JOBS=$(( (TOTAL_RAM_GB - RAM_RESERVE_GB) / RAM_PER_JOB_GB ))
[ "$RAM_JOBS" -lt 1 ] && RAM_JOBS=1
BUILD_JOBS=$(( RAM_JOBS < HALF_CORES ? RAM_JOBS : HALF_CORES ))
echo "Parallel jobs: $BUILD_JOBS (cores/2=$HALF_CORES, ram-capped=$RAM_JOBS)"
NOTARIZE_VALUE=$( [ "$NO_NOTARIZE" -eq 1 ] && echo OFF || echo ON )
JAM_NOTARIZE="$NOTARIZE_VALUE" KANJUT_NOTARIZE="$NOTARIZE_VALUE" cmake --build "$BUILD_DIR" --config "$SCHEME" --target "$TARGET" --parallel "$BUILD_JOBS" 2>&1 | cat

# Copy-to-system-directory is owned by PluginBuilder.cmake/AppBuilder.cmake
# POST_BUILD steps (JUCE's COPY_PLUGIN_AFTER_BUILD, plus the QA-build +
# sign + copy-signed-back chain for Release) — never duplicated here. A
# second copy after cmake --build returns would re-copy the raw, unsigned
# artifact straight from the Ninja build tree over cmake's already-signed
# system-path copy.
case "$FORMAT" in
    Standalone)
        echo "✓ Standalone app built (no copy needed)"
        # macOS Tahoe+: re-sign with get-task-allow so codelldb (or any debugger)
        # can launch/attach to the process. CMake debug builds are ad-hoc signed
        # with no entitlements; without get-task-allow the kernel refuses ptrace.
        if [[ "$(uname)" == "Darwin" ]]; then
            ENTITLEMENTS_FILE=$(mktemp /tmp/debug-entitlements-XXXX.xml)
            cat > "$ENTITLEMENTS_FILE" << 'ENTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.get-task-allow</key>
    <true/>
</dict>
</plist>
ENTEOF
            find "$BUILD_DIR" -path "*App_artefacts*" -name "*.app" -type d 2>/dev/null | while read -r app; do
                app_name=$(basename "$app" .app)
                bin="$app/Contents/MacOS/$app_name"
                if [[ -x "$bin" ]]; then
                    codesign --force --sign - --entitlements "$ENTITLEMENTS_FILE" "$bin"
                    echo "✓ Re-signed for debugging: $app_name"
                fi
            done
            rm -f "$ENTITLEMENTS_FILE"
        fi
        ;;
esac

echo "=========================================="
echo "✓ $FORMAT ($SCHEME) build complete"
echo "=========================================="
