#!/bin/bash
set -eo pipefail
exec < /dev/null
export TERM=dumb

# build-doxygen.sh  JUCE_DOXY  JUCE_OUT  LIB_DOXY  [PROJ_DOXY]
# Builds JUCE (HTML+XML+tagfile), library (HTML+XML), optionally project (XML only).
# Pass empty string for any optional dir to skip that build.
# JUCE: upstream Doxyfile is @INCLUDEd via temp wrapper so OUTPUT_DIRECTORY
# can be redirected without editing the upstream juce-framework/JUCE clone.

JUCE_DOXY="$1"
JUCE_OUT="$2"
LIB_DOXY="$3"
PROJ_DOXY="$4"

if [ -n "$JUCE_DOXY" ] && [ -n "$JUCE_OUT" ]; then
    echo "=========================================="
    echo "Building JUCE docs..."
    echo "=========================================="
    WRAPPER="$(mktemp)"
    {
        echo "@INCLUDE = $JUCE_DOXY/Doxyfile"
        echo "OUTPUT_DIRECTORY = $JUCE_OUT"
    } > "$WRAPPER"
    cd "$JUCE_DOXY" && doxygen "$WRAPPER"
    rm -f "$WRAPPER"
    echo "JUCE docs: done"
fi

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
