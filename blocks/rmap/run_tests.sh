#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RTL_DIR="${SCRIPT_DIR}/rtl"
TESTS_DIR="${SCRIPT_DIR}/tests"
BUILD_DIR="${SCRIPT_DIR}/build"
WAVES_DIR="${SCRIPT_DIR}/waves"

VERILATOR_FLAGS="-Wall --assert --language 1800-2017 --timing \
--trace-structs --binary -Wno-fatal -j 0 \
--trace-fst --x-assign unique --x-initial unique"

mkdir -p "${BUILD_DIR}"
mkdir -p "${WAVES_DIR}"

if [ -z "${1:-}" ]; then
    echo "Digite o nome do teste:"
    read nome_do_teste
else
    nome_do_teste="$1"
fi

function cleanup {
    echo "Limpando arquivos temporarios..."
    rm -rf obj_dir
    rm -rf "${BUILD_DIR}"
    rm -rf "${WAVES_DIR}"
}

function run_rmap_crc8_test {
    echo "Executando teste rmap_crc8"
    verilator --top-module tb_rmap_crc8 \
        "${TESTS_DIR}/tb_rmap_crc8.sv" \
        "${RTL_DIR}/rmap_crc8.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_rmap_crc8
}

function run_RMAP_test {
    echo "Executando teste RMAP"
    verilator --top-module tb_RMAP \
        "${TESTS_DIR}/tb_RMAP.sv" \
        "${RTL_DIR}/RMAP.sv" \
        "${RTL_DIR}/rmap_crc8.sv" \
        "${RTL_DIR}/rmap_reg_bank.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_RMAP
}

case "${nome_do_teste}" in
    rmap_crc8)
        run_rmap_crc8_test
        ;;
    RMAP)
        run_RMAP_test
        ;;
    clean)
        cleanup
        ;;
    help)
        echo "Exemplo: ./run_tests.sh flow_control_tx"
        ;;
    *)
        echo "Teste desconhecido: ${nome_do_teste}"
        ;;
esac

exit 0