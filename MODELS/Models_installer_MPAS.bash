#!/bin/bash
#-----------------------------------------------------------------------------------
# MODEL: MPAS-A (GNU)
#
#   MPAS_VERSION / --mpas-version   (aceita lista: --mpas-version 8.0.1,latest)
#       8.0.1   (padrão) -> clona a tag v8.0.1 em  $MODEL_DIR_INSTALL/MPAS-8.0.1
#       X.Y.Z            -> clona a tag vX.Y.Z  em  $MODEL_DIR_INSTALL/MPAS-X.Y.Z
#       latest           -> última versão LANÇADA (tag mais recente), ex.: MPAS-8.4.2
#       master           -> branch de desenvolvimento em $MODEL_DIR_INSTALL/MPAS-Model
#                           (nem sempre funciona)
#   Cada versão fica na sua pasta, então várias podem coexistir.
#   MPAS_PRECISION (padrão single)
#-----------------------------------------------------------------------------------

# Diretório onde o MPAS fica (usado também pela verificação "já instalado")
mpas_dir_name(){
    local v="${1:-${MPAS_VERSION:-8.0.1}}"
    case "$v" in
        master) echo "MPAS-Model" ;;
        *)      echo "MPAS-${v#v}" ;;
    esac
}

# resolve_mpas_version <versão> -> imprime a versão real (latest -> X.Y.Z da tag mais nova)
resolve_mpas_version(){
    local v="${1#v}" newest
    if [ "$v" = latest ]; then
        newest=$(timeout 60 git ls-remote --tags --refs "$GIT_URL_MPAS" 'v*' 2>/dev/null \
                 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)
        if [ -n "$newest" ]; then
            echo "${newest#v}"
        else
            echo "[AVISO] não consegui consultar as tags do MPAS; 'latest' não resolvido." >&2
            echo "latest"
        fi
    else
        echo "$v"
    fi
}

#-----------------------------------------------------------------------------------
# patch_mpas_c_ptr
#   Contorna o bug do gfortran >= 13 (GCC PR 103931):
#     "Error: Type name 'c_ptr' at (1) is ambiguous"  em mpas_init_atm_static.F
#   O c_ptr chega por dois caminhos (use iso_c_binding direto + reexportado por
#   outro módulo). Importamos o c_ptr com outro nome (mpas_cptr_t) só nesse
#   arquivo, eliminando a ambiguidade. É seguro também em gfortran antigos.
#-----------------------------------------------------------------------------------
patch_mpas_c_ptr(){
    local f="src/core_init_atmosphere/mpas_init_atm_static.F"
    [ -f "$f" ] || return 0
    if grep -qi 'mpas_cptr_t' "$f"; then
        echo ">> patch c_ptr: já aplicado."
        return 0
    fi
    if grep -qiE '^\s*use\s+iso_c_binding\s*,\s*only\s*:.*\bc_ptr\b' "$f"; then
        sed -i -E 's/^(\s*use\s+iso_c_binding\s*,\s*only\s*:.*)\bc_ptr\b/\1mpas_cptr_t => c_ptr/I' "$f"
        sed -i -E 's/type\s*\(\s*c_ptr\s*\)/type(mpas_cptr_t)/Ig' "$f"
        echo ">> patch c_ptr aplicado em $f (contorno do bug do gfortran >= 13)."
        grep -niE 'mpas_cptr_t' "$f" | head -5
    fi
    return 0
}

install_MPAS(){
    local mpas_version; mpas_version="$(resolve_mpas_version "${MPAS_VERSION:-8.0.1}")"
    if [ "$mpas_version" = latest ]; then
        echo "ERRO: não foi possível descobrir a versão mais recente do MPAS (sem acesso ao GitHub?)."
        exit 1
    fi
    local mpas_dir; mpas_dir="$(mpas_dir_name "$mpas_version")"
    local precision="${MPAS_PRECISION:-single}"

    define_compilers "$GNU_MPI"
    mpi_setup     # MPAS sempre compila com os wrappers MPI

    export MPAS_EXTERNAL_INCLUDES="-I$LIBS_DIR/include"
    # MPAS SEMPRE USA TODAS AS LIBS DE I/O PARALELAS (PIO, NETCDF, HDF5, PNETCDF)
    export MPAS_EXTERNAL_LIBS="$LIBS_DIR/lib/libpiof.a \
                            $LIBS_DIR/lib/libpioc.a \
                            $LIBS_DIR/lib/libnetcdff.a \
                            $LIBS_DIR/lib/libnetcdf.a \
                            $LIBS_DIR/lib/libhdf5_hl.a \
                            $LIBS_DIR/lib/libhdf5.a -lz -ldl -lm -lpthread"

    # CORRIGIDO: MAKE_OVERRIDES era usado mas nunca definido. Agora força os wrappers do MPICH.
    if [ "${#MAKE_OVERRIDES[@]}" -eq 0 ]; then
        MAKE_OVERRIDES=( CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC" )
    fi

    cd "$MODEL_DIR_INSTALL"
    rm -rf "$mpas_dir"
    echo ">> MPAS versão: $mpas_version  ->  $MODEL_DIR_INSTALL/$mpas_dir"
    if [ "$mpas_version" = master ]; then
        git clone "$GIT_URL_MPAS" "$mpas_dir"
        cd "$mpas_dir"
    else
        git clone --branch "v${mpas_version}" --depth 1 "$GIT_URL_MPAS" "$mpas_dir"
        cd "$mpas_dir"
        # Confirma o pin antes de compilar
        if [ "$(git describe --tags --exact-match 2>/dev/null)" != "v${mpas_version}" ]; then
            echo "ERRO: o MPAS não está na versão esperada v${mpas_version}."
            exit 1
        fi
    fi

    patch_mpas_c_ptr

    echo ">> Compiladores usados:"
    echo "   gfortran: $(gfortran --version | head -1)"
    echo "   mpif90  : $(command -v mpif90) -> $("${MPIFC:-mpif90}" --version 2>/dev/null | head -1)"

    echo ">> Compiling MPAS ($mpas_dir, PRECISION=$precision)..."
    make gfortran CORE=init_atmosphere USE_PIO2=true PRECISION="$precision" "${MAKE_OVERRIDES[@]}"
    make clean CORE=atmosphere USE_PIO2=true PRECISION="$precision"
    make gfortran CORE=atmosphere USE_PIO2=true PRECISION="$precision" -j"$CPU_HALF_EVEN" "${MAKE_OVERRIDES[@]}"

    check_lib_success "atmosphere_model" "$MODEL_DIR_INSTALL/$mpas_dir/atmosphere_model"
    check_lib_success "init_atmosphere"  "$MODEL_DIR_INSTALL/$mpas_dir/init_atmosphere_model"

    pause_step "MPAS build done. Press ENTER..."
}

# Compatibilidade com o nome antigo
install_MPAS_V801(){ MPAS_VERSION=8.0.1 install_MPAS; }
