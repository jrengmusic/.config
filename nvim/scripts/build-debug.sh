#!/bin/bash
set -eo pipefail

# cmake 4.3+ opens interactive TUI when stdin or stdout is a TTY
# exec < /dev/null: nulls stdin for all subprocesses (including cmake spawned by ninja)
# TERM=dumb + 2>&1 | cat on cmake calls: nulls stdout TTY detection
exec < /dev/null
export TERM=dumb

ROOT="$1"
SCHEME="${2:-Debug}"
FORMAT="${3:-VST3}"
BUILD_DIR="$ROOT/Builds/Ninja"

# Check if reconfiguration is needed
NEEDS_CONFIG=0
if [ ! -f "$BUILD_DIR/CMakeCache.txt" ]; then
    NEEDS_CONFIG=1
else
    # Check cached build type
    CACHED_TYPE=$(grep -E "^CMAKE_BUILD_TYPE:" "$BUILD_DIR/CMakeCache.txt" | cut -d= -f2 || true)
    if [ "$CACHED_TYPE" != "$SCHEME" ]; then
        echo "Build type changed: $CACHED_TYPE -> $SCHEME"
        NEEDS_CONFIG=1
    fi
fi

if [ "$NEEDS_CONFIG" -eq 1 ] || [ ! -f "$BUILD_DIR/build.ninja" ]; then
    echo "Configuring CMake ($SCHEME)..."
    mkdir -p "$ROOT/Builds"
    # Build only native architecture for fast iteration (not universal binary)
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
        TARGET=$(ninja -C "$BUILD_DIR" -t targets 2>/dev/null | grep -E "^[A-Za-z][A-Za-z0-9_]*: phony" | grep -v -E "_(VST3|AU|AAX|AUv3|Unity|VST|Standalone|All): phony" | grep -v -E "^(edit_cache|rebuild_cache|install|list_install_components|codegen|.*_BinaryData): phony" | cut -d: -f1 | head -1 || true)
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
cmake --build "$BUILD_DIR" --config "$SCHEME" --target "$TARGET" 2>&1 | cat

echo "=========================================="
echo "Copying $FORMAT to system directory..."
echo "=========================================="

ARTEFACTS="$BUILD_DIR"

case "$FORMAT" in
    VST3)
        find "$ARTEFACTS" -name "*.vst3" -type d 2>/dev/null | while read -r plugin; do
            name=$(basename "$plugin")
            dest="$HOME/Library/Audio/Plug-Ins/VST3/$name"
            rm -rf "$dest"
            cp -R "$plugin" "$dest"
            echo "✓ VST3: $name"
        done
        ;;
    AU)
        find "$ARTEFACTS" -name "*.component" -type d 2>/dev/null | while read -r plugin; do
            name=$(basename "$plugin")
            dest="$HOME/Library/Audio/Plug-Ins/Components/$name"
            rm -rf "$dest"
            cp -R "$plugin" "$dest"
            echo "✓ AU: $name"
        done
        ;;
    VST)
        find "$ARTEFACTS" -name "*.vst" -type d 2>/dev/null | while read -r plugin; do
            name=$(basename "$plugin")
            dest="$HOME/Library/Audio/Plug-Ins/VST/$name"
            rm -rf "$dest"
            cp -R "$plugin" "$dest"
            echo "✓ VST: $name"
        done
        ;;
    AAX)
        find "$ARTEFACTS" -name "*.aaxplugin" -type d 2>/dev/null | while read -r plugin; do
            name=$(basename "$plugin")
            dest="/Library/Application Support/Avid/Audio/Plug-Ins/$name"
            rm -rf "$dest"
            cp -R "$plugin" "$dest"
            echo "✓ AAX: $name"
        done
        ;;
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
