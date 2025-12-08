#!/bin/bash 





#-----------------------------------------------------------------------------
#   HELPER FUNCTIONS FOR VERIFICATION (SIMPLIFIED TO CHECK ONLY 'lib')
#-------------------------------------------------------------------------------
check_lib_success() {
    local lib_name=$1
    local check_file=$2
    
    # Verifica APENAS no caminho padrão ($LIBS_DIR/lib)
    if [ -f "$check_file" ]; then
        echo -e "\033[0;32m[SUCCESS]\033[0m $lib_name installed successfully ($check_file found)."
        return 0
    fi
    
    # Falha real
    echo -e "\033[0;31m[ERROR]\033[0m $lib_name failed to install! Missing: $check_file"
    echo "A biblioteca não foi instalada na pasta 'lib'."
    echo "Verifique os logs de compilação acima."
    exit 1
}


run_clean() { env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$HOME" TERM="${TERM:-xterm}" LC_ALL=C "$@"; }
tar_clean() { run_clean tar "$@"; }
ls_clean()  { run_clean ls  "$@"; }

