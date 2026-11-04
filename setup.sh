export PROJECT_ROOT=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

export RTL_DIR="$PROJECT_ROOT/rtl"
export TESTS_DIR="$PROJECT_ROOT/tests"
export VERIF_DIR="$PROJECT_ROOT/verif"
export CONSTRAINTS_DIR="$PROJECT_ROOT/common/constraints"
export PDK_CONFIG="$PROJECT_ROOT/common/pdk"
export SETUP_DIR="$PROJECT_ROOT/common/setup"

export TOOLS_DIR="$PROJECT_ROOT/tools"
export DC_DIR="${TOOLS_DIR}/dc"
export FC_DIR="${TOOLS_DIR}/fc"
export FM_DIR="${TOOLS_DIR}/dc/fm"
export VCS_DIR="${TOOLS_DIR}/dc/vcs"


export PDK_MACRO=SAED90   # or SAED32, or SAED90, or IHP130, or NULL
export TOP_MODULE_NAME="codec"

### MODULES
MODULES=(
    "syn/W-2024.09-SP5-2"
    "fusioncompiler/W-2024.09-SP3"
    "designcompiler/W-2024.09-SP5-4"
    "vcs/W-2024.09-SP2-3"
    "verdi/W-2024.09-SP2-6"
    "fm/W-2024.09-SP5"
)

for mod in "${MODULES[@]}"; do
    module load "${mod}" 2>/dev/null || true
done

