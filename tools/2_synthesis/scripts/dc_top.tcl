set PROJECT_ROOT $::env(PROJECT_ROOT)

set TOOLS_DIR $::env(TOOLS_DIR)
set SETUP_DIR $::env(SETUP_DIR)
set SYNTHESIS_DIR $::env(SYNTHESIS_DIR)
set SCRIPTS_DIR $::env(SCRIPTS_DIR)

# 3. Muda o diretório de execução para a pasta dos scripts 
# Isso permite que os arquivos chamem uns aos outros de forma estritamente relativa
cd $SCRIPTS_DIR

# 4. Executa os scripts usando caminhos relativos à pasta atual (scripts/)
source "${SETUP_DIR}/setup.tcl"
source "${SCRIPTS_DIR}/dc_setup.tcl"
source "${SCRIPTS_DIR}/01_read.tcl"
source "${SCRIPTS_DIR}/02_constraints.tcl"
source "${SCRIPTS_DIR}/03_compile.tcl"

exit
