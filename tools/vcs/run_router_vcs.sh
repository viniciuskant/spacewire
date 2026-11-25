#!/bin/bash
# Testes do roteador no vcs (matriz, RMAP e topo)
#   bash tools/vcs/run_router_vcs.sh
#   bash tools/vcs/run_router_vcs.sh --verdi   (Não testei com o verdi no meu pc)
#
# logs em ~/vcs_work/<teste>/

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$REPO" || exit 1
source setup.sh > /dev/null 2>&1

if ! command -v vcs > /dev/null; then
    echo "ERRO: vcs nao encontrado. Confira se o modulo vcs existe neste servidor (module avail vcs)."
    exit 1
fi

VERDI=0
if [ "${1:-}" = "--verdi" ]; then
    VERDI=1; shift
    if [ $# -eq 0 ]; then
        set -- spw_router            # default = roteador completo
    elif [ $# -gt 1 ]; then
        echo "Uso: bash tools/vcs/run_router_vcs.sh --verdi [teste]   (um teste por vez)"; exit 1
    fi
fi

#Trava a semente, conferir router depois
SEED=${SEED:-2} 

TESTS="${*:-sw_route_table sw_out_arb sw_in_ctrl sw_tc_unit spw_switch spw_router rmap_crc8 RMAP coded_port_zero}"

# Todo RTL do roteador
RTL=("$REPO"/rtl/spw_pkg.sv "$REPO"/rtl/router/*.sv "$REPO"/rtl/rmap/*.sv \
     "$REPO"/rtl/top/*.sv "$REPO"/rtl/common/*.sv)

falhas=0
for t in $TESTS; do
    tb=$(find "$REPO/tests" -name "tb_$t.sv" | head -1)
    W=~/vcs_work/$t
    rm -rf "$W"; mkdir -p "$W/waves"; cd "$W" || exit 1

    if [ -z "$tb" ]; then
        echo "$t: FAIL (tb_$t.sv nao encontrado)"; falhas=$((falhas+1)); continue
    fi

    if [ $VERDI -eq 1 ]; then
        DBG="-debug_access+all -kdb"   # guarda para o verdi
    else
        DBG=""
    fi

    if ! vcs -full64 -sverilog -timescale=1ns/1ps $DBG "${RTL[@]}" "$tb" -top "tb_$t" -l comp.log > /dev/null 2>&1; then
        echo "$t: FAIL na compilacao (veja $W/comp.log)"; falhas=$((falhas+1)); continue
    fi

    if [ $VERDI -eq 1 ]; then
        printf 'fsdbDumpfile waves.fsdb\nfsdbDumpvars 0 tb_%s +all\nrun\nquit\n' "$t" > dump.tcl
        ./simv +ntb_random_seed=$SEED -ucli -do dump.tcl -l run.log > /dev/null 2>&1
    else
        ./simv +ntb_random_seed=$SEED -l run.log > /dev/null 2>&1
    fi
    resumo=$(grep -m1 "RESUMO" run.log)

    if grep -q 'finish at simulation time' run.log && ! grep -qE '^(Error|Fatal)|\*\*\* FAIL' run.log; then
        echo "$t: PASS  $resumo"
    else
        echo "$t: FAIL  $resumo (veja $W/run.log)"; falhas=$((falhas+1))
    fi
done

echo "----"
echo "Falhas: $falhas"

if [ $VERDI -eq 1 ]; then
    W=~/vcs_work/$TESTS
    if [ ! -f "$W/waves.fsdb" ]; then
        echo "As ondas nao foram gravadas (veja $W/run.log)."
    elif [ -z "${DISPLAY:-}" ]; then
        echo "Sem tela nesta sessao (DISPLAY vazio). Ondas gravadas em $W/waves.fsdb."
        echo "Para abrir, entre no servidor com \"ssh -Y\" e rode:"
        echo "  cd $W && verdi -dbdir simv.daidir -ssf waves.fsdb &"
    else
        echo "Abrindo o Verdi..."
        cd "$W" && verdi -dbdir simv.daidir -ssf waves.fsdb > verdi.log 2>&1 &
    fi
fi

exit $falhas
