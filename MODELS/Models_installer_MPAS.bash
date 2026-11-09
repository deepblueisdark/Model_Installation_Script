#!/bin/bash
#-----------------------------------------------------------------------------------
# MODEL: MPAS-A (GNU)
#
#   MPAS_VERSION / --mpas-version
#       8.0.1   (padrão) -> clona a tag v8.0.1 em  $MODEL_DIR_INSTALL/MPAS-8.0.1
#       X.Y.Z            -> clona a tag vX.Y.Z  em  $MODEL_DIR_INSTALL/MPAS-X.Y.Z
#       latest           -> clona o branch padrão em $MODEL_DIR_INSTALL/MPAS-Model
#                           (nem sempre funciona)
#   MPAS_PRECISION (padrão single)
#-----------------------------------------------------------------------------------

# Diretório onde o MPAS fica (usado também pela verificação "já instalado")
mpas_dir_name(){
    if [ "${MPAS_VERSION:-8.0.1}" = latest ]; then echo "MPAS-Model"; else echo "MPAS-${MPAS_VERSION:-8.0.1}"; fi
}

install_MPAS(){
    local mpas_version="${MPAS_VERSION:-8.0.1}"
    local mpas_dir; mpas_dir="$(mpas_dir_name)"
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
    if [ "$mpas_version" = latest ]; then
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
