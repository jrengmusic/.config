#!/bin/bash
set -e

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
    CACHED_TYPE=$(grep -E "^CMAKE_BUILD_TYPE:" "$BUILD_DIR/CMakeCache.txt" | cut -d= -f2)
    if [ "$CACHED_TYPE" != "$SCHEME" ]; then
        echo "Build type changed: $CACHED_TYPE -> $SCHEME"
        NEEDS_CONFIG=1
    fi
fi

if [ "$NEEDS_CONFIG" -eq 1 ]; then
    echo "Configuring CMake ($SCHEME)..."
    mkdir -p "$ROOT/Builds"
    # Build only native architecture for fast iteration (not universal binary)
    NATIVE_ARCH=$(uname -m)
    cmake -B "$BUILD_DIR" -G Ninja \
        -DCMAKE_BUILD_TYPE="$SCHEME" \
        -DCMAKE_OSX_ARCHITECTURES="$NATIVE_ARCH" \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
fi

# Find target name for this format
TARGET=$(ninja -C "$BUILD_DIR" -t targets 2>/dev/null | grep -E "_${FORMAT}: phony" | cut -d: -f1 | head -1)

if [ -z "$TARGET" ]; then
    echo "ERROR: No target found for format $FORMAT"
    exit 1
fi

echo "=========================================="
echo "Building $TARGET ($SCHEME)..."
echo "=========================================="
cmake --build "$BUILD_DIR" --config "$SCHEME" --target "$TARGET"

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
esac

echo "=========================================="
echo "✓ $FORMAT ($SCHEME) build complete"
echo "=========================================="
