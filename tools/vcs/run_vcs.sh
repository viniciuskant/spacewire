#!/bin/bash

# Define os caminhos base
RUN_DIR="$VCS_DIR/run"
FILELIST="$TESTS_DIR/filelist.f"
TOP_TB="tb_codec"
SIM_TIME="100000" # Em ns

# Cria os diretórios necessários
mkdir -p "$VCS_DIR/tmp"
chmod 700 "$VCS_DIR/tmp"
export TMPDIR="$VCS_DIR/tmp"

mkdir -p "$RUN_DIR"
mkdir -p "$RUN_DIR/waves" # Necessário para evitar erro de VCD dump

cd "$RUN_DIR" || exit 1

if [ "$PDK_MACRO" == "SAED90" ]; then
    SRAM_FILES="${PDK_CONFIG}/saed90/MEMORIE/verilog/SRAM16x16.v ${PDK_CONFIG}/saed90/MEMORIE/verilog/SRAM16x64.v"
elif [ "$PDK_MACRO" == "SAED32" ]; then
    SRAM_FILES="/pdk/synopsys/saed32/SAED32_EDK/lib/sram/verilog/saed32sram.v"
else
    echo "WARNING: Nenhuma SRAM definida para $PDK_MACRO"
    SRAM_FILES=""
fi

CM_HIER_FLAG=""
if [ -f "cm_hier.file" ]; then
    CM_HIER_FLAG="-cm_hier cm_hier.file"
fi

vcs -full64 -sverilog -debug_access+all -kdb -lca \
    -cm line+cond+fsm+tgl+branch $CM_HIER_FLAG \
    -F "$FILELIST" \
    $SRAM_FILES \
    -top $TOP_TB \
    -l vcs_comp.log

if [ $? -ne 0 ]; then
    echo "ERRO: Falha na compilação. Verifique $RUN_DIR/vcs_comp.log"
    exit 1
fi

./simv -cm line+cond+fsm+tgl+branch +vcs+finish+$SIM_TIME -l vcs_run.log

if [ $? -ne 0 ]; then
    echo "ERRO: Falha na simulação. Verifique $RUN_DIR/vcs_run.log"
    exit 1
fi

verdi -dbdir simv.daidir -cov -covdir simv.vdb &