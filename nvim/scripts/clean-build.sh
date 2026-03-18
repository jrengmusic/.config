#!/bin/bash
set -e

# Accept project root as argument, default to current directory
ROOT="${1:-.}"
BUILD_DIR="$ROOT/Builds/Ninja"

echo "=========================================="
echo "Cleaning Ninja build directory..."
echo "=========================================="
rm -rf "$BUILD_DIR"

echo "✓ Clean complete"
