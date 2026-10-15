export PROJECT_ROOT=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

export TOOLS_DIR="$PROJECT_ROOT/tools"
export SYNTHESIS_DIR="$TOOLS_DIR/2_synthesis"

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