#!/bin/bash
set -eo pipefail
exec < /dev/null
export TERM=dumb

# build-doxygen.sh  LIB_DOXY  [PROJ_DOXY]
# Builds library doxygen (HTML+XML) and optionally project doxygen (XML only).
# Pass empty string for PROJ_DOXY to skip project build.

LIB_DOXY="$1"
PROJ_DOXY="$2"

if [ -n "$LIB_DOXY" ]; then
    echo "=========================================="
    echo "Building library docs..."
    echo "=========================================="
    cd "$LIB_DOXY"
    doxygen Doxyfile
    echo "Library docs: done"
fi

if [ -n "$PROJ_DOXY" ]; then
    echo "=========================================="
    echo "Building project docs..."
    echo "=========================================="
    cd "$PROJ_DOXY"
    doxygen Doxyfile
    echo "Project docs: done"
fi
