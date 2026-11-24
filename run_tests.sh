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

function run_sw_route_table_test {
    echo "Executando teste sw_route_table"
    verilator --top-module tb_sw_route_table \
        "${TESTS_DIR}/router/tb_sw_route_table.sv" \
        "${RTL_DIR}/router/sw_route_table.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_sw_route_table
}

function run_sw_out_arb_test {
    echo "Executando teste sw_out_arb"
    verilator --top-module tb_sw_out_arb \
        "${TESTS_DIR}/router/tb_sw_out_arb.sv" \
        "${RTL_DIR}/router/sw_out_arb.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_sw_out_arb
}

function run_sw_in_ctrl_test {
    echo "Executando teste sw_in_ctrl"
    verilator --top-module tb_sw_in_ctrl \
        "${RTL_DIR}/spw_pkg.sv" \
        "${TESTS_DIR}/router/tb_sw_in_ctrl.sv" \
        "${RTL_DIR}/router/sw_in_ctrl.sv" \
        "${RTL_DIR}/router/sw_route_table.sv" \
        "${RTL_DIR}"/common/*.sv \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_sw_in_ctrl
}

function run_sw_tc_unit_test {
    echo "Executando teste sw_tc_unit"
    verilator --top-module tb_sw_tc_unit \
        "${TESTS_DIR}/router/tb_sw_tc_unit.sv" \
        "${RTL_DIR}/router/sw_tc_unit.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_sw_tc_unit
}

function run_spw_switch_test {
    echo "Executando teste spw_switch"
    verilator --top-module tb_spw_switch \
        "${RTL_DIR}/spw_pkg.sv" \
        "${TESTS_DIR}/router/tb_spw_switch.sv" \
        "${RTL_DIR}"/router/*.sv \
        "${RTL_DIR}"/common/*.sv \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_spw_switch
}

function run_spw_router_test {
    echo "Executando teste spw_router"
    verilator --top-module tb_spw_router \
        "${RTL_DIR}/spw_pkg.sv" \
        "${TESTS_DIR}/top/tb_spw_router.sv" \
        "${RTL_DIR}"/top/*.sv \
        "${RTL_DIR}"/router/*.sv \
        "${RTL_DIR}"/common/*.sv \
        "${RTL_DIR}/rmap/RMAP.sv" \
        "${RTL_DIR}/rmap/rmap_crc8.sv" \
        "${RTL_DIR}/rmap/rmap_reg_bank.sv" \
        "${RTL_DIR}/rmap/coded_port_zero.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_spw_router
}

function run_rmap_crc8_test {
    echo "Executando teste rmap_crc8"
    verilator --top-module tb_rmap_crc8 \
        "${TESTS_DIR}/rmap/tb_rmap_crc8.sv" \
        "${RTL_DIR}/rmap/rmap_crc8.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_rmap_crc8
}

function run_RMAP_test {
    echo "Executando teste RMAP"
    verilator --top-module tb_RMAP \
        "${RTL_DIR}/spw_pkg.sv" \
        "${TESTS_DIR}/rmap/tb_RMAP.sv" \
        "${RTL_DIR}/rmap/RMAP.sv" \
        "${RTL_DIR}/rmap/rmap_crc8.sv" \
        "${RTL_DIR}/rmap/rmap_reg_bank.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_RMAP
}

function run_coded_port_zero_test {
    echo "Executando teste Port Zero"
    verilator --top-module tb_coded_port_zero \
        "${RTL_DIR}/spw_pkg.sv" \
        "${TESTS_DIR}/rmap/tb_coded_port_zero.sv" \
        "${RTL_DIR}/rmap/coded_port_zero.sv" \
        "${RTL_DIR}"/common/*.sv \
        "${RTL_DIR}/rmap/RMAP.sv" \
        "${RTL_DIR}/rmap/rmap_crc8.sv" \
        "${RTL_DIR}/rmap/rmap_reg_bank.sv" \
        ${VERILATOR_FLAGS}
    ./obj_dir/Vtb_coded_port_zero
}

ROUTER_TESTS="sw_route_table sw_out_arb sw_in_ctrl sw_tc_unit spw_switch spw_router rmap_crc8 RMAP coded_port_zero"
ALL_TESTS="${ROUTER_TESTS}"

# Roda cada teste da lista em outro processo (bash "$0" <teste>), com log em logs/<teste>.log.
# PASS = codigo de saida 0 e nenhum "%Error" no log. Um FAIL nao interrompe os demais.
function run_suite {
    local logs_dir="${SCRIPT_DIR}/logs"
    local teste log rc resumo
    local total=0 passou=0
    local resultados=()

    mkdir -p "${logs_dir}"

    for teste in "$@"; do
        log="${logs_dir}/${teste}.log"
        total=$((total + 1))
        echo "==> ${teste}"

        rc=0
        bash "$0" "${teste}" > "${log}" 2>&1 || rc=$?

        if [ "${rc}" -eq 0 ] && ! grep -q "%Error" "${log}"; then
            passou=$((passou + 1))
            resultados+=("PASS  ${teste}")
            resumo="$(grep "RESUMO" "${log}" | tail -n 1 || true)"
            if [ -n "${resumo}" ]; then
                echo "    PASS  ${resumo}"
            else
                echo "    PASS"
            fi
        else
            resultados+=("FAIL  ${teste}")
            echo "    FAIL  (codigo ${rc}, ver ${log})"
        fi
    done

    echo ""
    echo "================ RESULTADO ================"
    printf '%s\n' "${resultados[@]}"
    echo "==========================================="
    echo "${passou} de ${total} passaram"
    echo "Logs em: ${logs_dir}/"

    if [ "${passou}" -ne "${total}" ]; then
        exit 1
    fi
    exit 0
}


case "${nome_do_teste}" in
    sw_route_table)
        run_sw_route_table_test
        ;;
    sw_out_arb)
        run_sw_out_arb_test
        ;;
    sw_in_ctrl)
        run_sw_in_ctrl_test
        ;;
    sw_tc_unit)
        run_sw_tc_unit_test
        ;;
    spw_switch)
        run_spw_switch_test
        ;;
    spw_router)
        run_spw_router_test
        ;;
    rmap_crc8)
        run_rmap_crc8_test
        ;;
    RMAP)
        run_RMAP_test
        ;;
    coded_port_zero)
        run_coded_port_zero_test
        ;;
    router)
        run_suite ${ROUTER_TESTS}
        ;;
    all)
        run_suite ${ALL_TESTS}
        ;;
    clean)
        cleanup
        ;;
    help)
        echo "Uso: ./run_tests.sh <teste>"
        echo ""
        echo "Testes individuais:"
        echo "  ${ALL_TESTS}"
        echo ""
        echo "Grupos (rodam varios testes, logs em logs/<teste>.log e resumo no final;"
        echo "saem com codigo 1 se algum teste falhar):"
        echo "  router  -> ${ROUTER_TESTS}"
        echo "  all     -> todos os testes acima"
        echo ""
        echo "Outros:"
        echo "  clean   -> apaga obj_dir, build e waves"
        echo ""
        echo "Exemplos:"
        echo "  ./run_tests.sh sw_route_table"
        echo "  ./run_tests.sh router"
        ;;
    *)
        echo "Teste desconhecido: ${nome_do_teste}"
        ;;
esac

exit 0