#!/bin/bash

if [ -z "${PROJECT_ROOT:-}" ]; then
    echo "ERROR: Variáveis de ambiente não encontradas. Rode 'source setup.sh' na raiz do projeto primeiro!" >&2
    exit 1
fi

TMP_DIR="${DC_DIR}/.tmp"
SCRIPTS_DIR="${DC_DIR}/scripts"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

echo ">> Running Synthesis..."
cd "$TMP_DIR"

dc_shell -f "$SCRIPTS_DIR/dc_top.tcl" 2>&1 | tee -i syn.log

echo ">> Synthesis Done!"
