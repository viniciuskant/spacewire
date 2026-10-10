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

function run_rx_signal_test {
    echo "Executando teste rx_signal"
    verilator --top-module tb_rx_signal \
        "${TESTS_DIR}/tb_rx_signal.sv" \
        "${RTL_DIR}/rx_signal.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_rx_signal
}

function run_rx_char_test {
    echo "Executando teste rx_char"
    verilator --top-module tb_rx_char \
        "${TESTS_DIR}/tb_rx_char.sv" \
        "${RTL_DIR}/rx_char.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_rx_char
}

function run_rx_completo_test {
    echo "Executando teste rx_completo"
    verilator --top-module tb_rx_completo \
        "${TESTS_DIR}/tb_rx_completo.sv" \
        "${RTL_DIR}/rx_completo.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_rx_completo
}

function run_tx_signal_test {
    echo "Executando teste tx_signal"
    verilator --top-module tb_tx_signal \
        "${TESTS_DIR}/tb_tx_signal.sv" \
        "${RTL_DIR}/tx_signal.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_tx_signal
}

function run_codec_test {
    echo "Executando teste codec_"
    verilator --top-module tb_codec \
        "${TESTS_DIR}/tb_codec.sv" \
        "${RTL_DIR}/codec.sv" \
        "${RTL_DIR}/flow_control.sv" \
        "${RTL_DIR}/flow_control_rx.sv" \
        "${RTL_DIR}/flow_control_tx.sv" \
        "${RTL_DIR}/state_machine.sv" \
        "${RTL_DIR}/rx.sv" \
        "${RTL_DIR}/rx_char.sv" \
        "${RTL_DIR}/rx_signal.sv" \
        "${RTL_DIR}/tx.sv" \
        "${RTL_DIR}/tx_char.sv" \
        "${RTL_DIR}/tx_signal.sv" \
        "${RTL_DIR}/rx_fifo.sv" \
        "${RTL_DIR}/tx_fifo.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_codec
}


function run_fifo_rx2fifo_test {
    echo "Executando teste fifo1"
    verilator --top-module tb_fifo1 \
        "${RTL_DIR}/fifo_rx2fifo/tests/tb_fifo1.sv" \
        "${RTL_DIR}/fifo_rx2fifo/rtl/fifo1.sv" \
        "${RTL_DIR}/fifo_rx2fifo/rtl/fifomem.sv" \
        "${RTL_DIR}/fifo_rx2fifo/rtl/rptr_empty.sv" \
        "${RTL_DIR}/fifo_rx2fifo/rtl/sync_r2w.sv" \
        "${RTL_DIR}/fifo_rx2fifo/rtl/sync_w2r.sv" \
        "${RTL_DIR}/fifo_rx2fifo/rtl/wptr_full.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_fifo1
}


case "${nome_do_teste}" in
    flow_control_tx)
        run_flow_control_tx_test
        ;;
    flow_control_rx)
        run_flow_control_rx_test
        ;;
    codec)
        run_codec_test
        ;;
    rx_signal)
        run_rx_signal_test
        ;;
    rx_char)
        run_rx_char_test
        ;;
    rx_completo)
        run_rx_completo_test
        ;;
    tx_signal)
        run_tx_signal_test
        ;;
    fifo_rx2fifo)
        run_fifo_rx2fifo_test
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