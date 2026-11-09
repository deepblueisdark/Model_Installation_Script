#!/bin/bash

#-----------------------------------------------------------------------------
#   HELPER FUNCTIONS FOR VERIFICATION (SIMPLIFIED TO CHECK ONLY 'lib')
#-----------------------------------------------------------------------------
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

#-----------------------------------------------------------------------------
#  check_any_lib_success <nome> <arq1> [arq2 ...]
#  Sucesso se QUALQUER um dos arquivos existir (nomes variam entre versões,
#  ex.: libhdf5hl_fortran.a x libhdf5_hl_fortran.a).
#-----------------------------------------------------------------------------
check_any_lib_success() {
    local lib_name=$1; shift
    local f
    for f in "$@"; do
        if [ -f "$f" ]; then
            echo -e "\033[0;32m[SUCCESS]\033[0m $lib_name installed successfully ($f found)."
            return 0
        fi
    done
    echo -e "\033[0;31m[ERROR]\033[0m $lib_name failed to install! Nenhum encontrado: $*"
    exit 1
}

#-----------------------------------------------------------------------------
#  pause_step "mensagem"  -> pausa somente se PROMPTOK=1 (modo debug)
#  (sempre retorna 0, seguro com 'set -e')
#-----------------------------------------------------------------------------
pause_step() {
    if [ "${PROMPTOK:-0}" -eq 1 ]; then
        read -r -p "$1 " _
    fi
    return 0
}

#-----------------------------------------------------------------------------
#  run_checks <comando...>  -> roda testes (make check) só se RUN_CHECKS=1.
#  Falhas nos testes geram AVISO, mas não interrompem a instalação.
#-----------------------------------------------------------------------------
run_checks() {
    if [ "${RUN_CHECKS:-0}" -eq 1 ]; then
        echo ">> Executando testes: $*"
        "$@" || echo "[AVISO] testes falharam ($*). Continuando."
    else
        echo ">> Testes ignorados (use --checks para executar): $*"
    fi
    return 0
}

run_clean() { env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$HOME" TERM="${TERM:-xterm}" LC_ALL=C "$@"; }
tar_clean() { run_clean tar "$@"; }
ls_clean()  { run_clean ls  "$@"; }
