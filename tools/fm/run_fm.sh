#!/bin/bash

if [ -z "${PROJECT_ROOT:-}" ]; then
    echo "ERROR: Project environment not initialized. Run 'source setup.sh' from the project root." >&2
    exit 1
fi

if [ ! -d "${DC_DIR}/current_run" ]; then
    echo "ERROR: DC run directory not found: '${DC_DIR}/curente_run'." >&2
    echo "       Please run Design Compiler (dc) before starting Formality." >&2
    exit 1
fi

TMP_DIR="${FM_DIR}/.tmp"
SCRIPTS_DIR="${FM_DIR}/scripts"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

echo ">> Starting Formality synthesis..."
cd "$TMP_DIR"

fm_shell -f "$SCRIPTS_DIR/fm_top.tcl" 2>&1 | tee -i fm.log

echo ">> Formality synthesis completed!"