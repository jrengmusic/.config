#!/bin/bash
set -eo pipefail
exec < /dev/null
export TERM=dumb

# build-doxygen.sh  JUCE_DOXYFILE  JUCE_RUN_DIR  JUCE_ROOT  LIB_DOXYFILE  LIB_ROOT  [PROJ_DOXY]
#
# JUCE_DOXYFILE : pre-substituted temp file (Doxyfile.juce wrapper)
# JUCE_RUN_DIR  : cd here before running doxygen (JUCE/docs/doxygen/ — assets resolve correctly)
# JUCE_ROOT     : root where DOCS.html is written
# LIB_DOXYFILE  : pre-substituted temp file (Doxyfile.lib with markers expanded)
# LIB_ROOT      : lib root — cd {LIB_ROOT}/docs, write {LIB_ROOT}/DOCS.html
# PROJ_DOXY     : project doxygen/ dir (XML only, optional)
# Pass empty string for any arg to skip that build.

JUCE_DOXYFILE="$1"
JUCE_RUN_DIR="$2"
JUCE_ROOT="$3"
LIB_DOXYFILE="$4"
LIB_ROOT="$5"
PROJ_DOXY="$6"

DOCS_HTML='<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0; url=docs/html/index.html"></head></html>'

if [ -n "$JUCE_DOXYFILE" ] && [ -n "$JUCE_RUN_DIR" ]; then
    echo "=========================================="
    echo "Building JUCE docs..."
    echo "=========================================="
    cd "$JUCE_RUN_DIR" && doxygen "$JUCE_DOXYFILE"
    echo "$DOCS_HTML" > "$JUCE_ROOT/DOCS.html"
    echo "JUCE docs: done"
fi

if [ -n "$LIB_DOXYFILE" ] && [ -n "$LIB_ROOT" ]; then
    echo "=========================================="
    echo "Building library docs..."
    echo "=========================================="
    mkdir -p "$LIB_ROOT/docs"
    cd "$LIB_ROOT/docs" && doxygen "$LIB_DOXYFILE"
    echo "$DOCS_HTML" > "$LIB_ROOT/DOCS.html"
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
