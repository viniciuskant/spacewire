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

function run_flow_control_tx_test {
    echo "Executando teste flow_control_tx"
    verilator --top-module tb_flow_control_tx \
        "${TESTS_DIR}/tb_flow_control_tx.sv" \
        "${RTL_DIR}/flow_control_tx.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_flow_control_tx
}

function run_flow_control_rx_test {
    echo "Executando teste flow_control_rx"
    verilator --top-module tb_flow_control_rx \
        "${TESTS_DIR}/tb_flow_control_rx.sv" \
        "${RTL_DIR}/flow_control_rx.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_flow_control_rx
}

case "${nome_do_teste}" in
    flow_control_tx)
        run_flow_control_tx_test
        ;;
    flow_control_rx)
        run_flow_control_rx_test
        ;;
    all)
        run_flow_control_tx_test
        run_flow_control_rx_test
        echo "Todos os testes foram executados."
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