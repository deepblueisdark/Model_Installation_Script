#!/bin/bash 

# ################################# MPAS-ATMOSPHERE ################################
# # USE_PIO2 over PIO1
# ##################################################################################
# if [ "${MODELS[2]}" -eq 1 ]; then
#   echo ">> Starting MPAS installation..."

#   # --- Prefixo LIMPO (sem / no final) e wrappers MPI do seu MPICH ---
#   PREFIX="${LIBS_DIR%/}"
#   export PATH="$PREFIX/bin:$PATH"
#   hash -r

#   # --- Paths para as libs (o Makefile do MPAS usa isso) ---
#   export NETCDF="$PREFIX"
#   export PNETCDF="$PREFIX"
#   export PIO="$PREFIX"
#   export HDF5="$PREFIX"
#   export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"

#   # (ajuda a linkar estático quando necessário)
#   export MPAS_EXTERNAL_INCLUDES="-I$LIBS_DIR/include"
#   export MPAS_EXTERNAL_LIBS="\
#   $LIBS_DIR/lib/libpiof.a \
#   $LIBS_DIR/lib/libpioc.a \
#   $LIBS_DIR/lib/libnetcdff.a \
#   $LIBS_DIR/lib/libnetcdf.a \
#   $LIBS_DIR/lib/libhdf5_hl.a \
#   $LIBS_DIR/lib/libhdf5.a \
#   -lz -ldl -lm -lpthread"   # acrescente -lcurl se o seu netcdf precisar

#   # --- Escolhe wrappers MPI locais (MPICH do PREFIX/bin). Fallback p/ mpif90 se mpifort não existir ---
#   MPICC="$PREFIX/bin/mpicc"
#   MPICXX="$PREFIX/bin/mpicxx"
#   MPIFC="$PREFIX/bin/mpifort"; [ -x "$MPIFC" ] || MPIFC="$PREFIX/bin/mpif90"

#   # Sanidade mínima
#   [ -x "$MPICC" ] || { echo "ERRO: não achei $MPICC"; exit 1; }
#   [ -x "$MPIFC" ] || { echo "ERRO: não achei $MPIFC"; exit 1; }
#   [ -f "$PREFIX/include/pnetcdf.h" ] || { echo "ERRO: faltando $PREFIX/include/pnetcdf.h"; exit 1; }
#   [ -f "$PREFIX/lib/libpnetcdf.a" ] || { echo "ERRO: faltando $PREFIX/lib/libpnetcdf.a"; exit 1; }

#   # --- Clone limpo ---
#   cd "$INSTALL_DIR"
#   rm -rf MPAS-Model
#   git clone https://github.com/MPAS-Dev/MPAS-Model.git
#   cd MPAS-Model

#   # --- TESTE RÁPIDO do PnetCDF com o SEU mpicc (evita erro críptico do Makefile) ---
#   # rm -f pnetcdf.out
#   # "$MPICC" pnetcdf.c -I"$PREFIX/include" -L"$PREFIX/lib" -lpnetcdf -o pnetcdf.out \
#   #   || { echo "ERRO: falhou o teste pnetcdf.c com $MPICC. Verifique include/lib do PREFIX."; exit 1; }

#   # --- Build coerente com o COMPILER e forçando os wrappers paralelos ---
#   case "$COMPILER" in
#     GNU)
#       echo ">> MPAS compiling with GNU (gfortran target)"
#       make gfortran CORE=init_atmosphere USE_PIO2=true PRECISION=single \
#            CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC"
#       make clean CORE=atmosphere USE_PIO2=true PRECISION=single
#       make gfortran CORE=atmosphere USE_PIO2=true PRECISION=single -j"$CPU_HALF_EVEN" \
#            CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC"
#       ;;
#     INTEL)
#       echo ">> MPAS compiling with INTEL (intel target)"
#       make intel CORE=init_atmosphere USE_PIO2=true PRECISION=single \
#            CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC"
#       make clean CORE=atmosphere USE_PIO2=true PRECISION=single
#       make intel CORE=atmosphere USE_PIO2=true PRECISION=single -j"$CPU_HALF_EVEN" \
#            CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC"
#       ;;
#     NVIDIA)
#       echo ">> MPAS compiling with NVIDIA HPC (nvhpc target)"
#       make nvhpc CORE=init_atmosphere USE_PIO2=true PRECISION=single \
#            CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC"
#       make clean CORE=atmosphere USE_PIO2=true PRECISION=single
#       make nvhpc CORE=atmosphere USE_PIO2=true PRECISION=single -j"$CPU_HALF_EVEN" \
#            CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC"
#       ;;
#     *)
#       echo "ERRO: COMPILER=$COMPILER não reconhecido para MPAS."; exit 1;;
#   esac

#   [ "$PROMPTOK" -eq 1 ] && read -p "MPAS build done. Press enter to continue..."
# fi

#-----------------------------------------------------------------------------------
# MODEL: MPAS (GNU)
#-----------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------
install_MPAS_V801(){
    local mpas_version="${MPAS_VERSION:-8.0.1}"
    
    define_compilers "$GNU_MPI"
    export MPAS_EXTERNAL_INCLUDES="-I$LIBS_DIR/include"
    # MPAS SEMPRE USA TODAS AS LIBS DE I/O PARALELAS (PIO, NETCDF, HDF5, PNETCDF)
    export MPAS_EXTERNAL_LIBS="$LIBS_DIR/lib/libpiof.a \
                            $LIBS_DIR/lib/libpioc.a \
                            $LIBS_DIR/lib/libnetcdff.a \
                            $LIBS_DIR/lib/libnetcdf.a \
                            $LIBS_DIR/lib/libhdf5_hl.a \
                            $LIBS_DIR/lib/libhdf5.a -lz -ldl -lm -lpthread"

    cd "$MODEL_DIR_INSTALL"
    rm -rf "MPAS-${mpas_version}"
    git clone --branch "v${mpas_version}" --depth 1 https://github.com/MPAS-Dev/MPAS-Model.git "MPAS-${mpas_version}" || return 1
    cd "MPAS-${mpas_version}" || return 1
    # Confirma o pin antes de compilar; evita seguir com o branch padrão se o checkout falhar.
    if [ "$(git describe --tags --exact-match 2>/dev/null)" != "v${mpas_version}" ]; then
        echo "ERRO: o MPAS não está na versão esperada v${mpas_version}."
        return 1
    fi
  

    echo ">> Compiling MPAS..."
    make gfortran CORE=init_atmosphere USE_PIO2=true PRECISION=single "${MAKE_OVERRIDES[@]}"
    make clean CORE=atmosphere USE_PIO2=true PRECISION=single
    make gfortran CORE=atmosphere USE_PIO2=true PRECISION=single -j"$CPU_HALF_EVEN" "${MAKE_OVERRIDES[@]}"
    check_lib_success "atmosphere_model" "$MODEL_DIR_INSTALL/MPAS-${mpas_version}/atmosphere_model"
    check_lib_success "init_atmosphere" "$MODEL_DIR_INSTALL/MPAS-${mpas_version}/init_atmosphere_model"
    
  [ "$PROMPTOK" -eq 1 ] && read -p "MPAS build done. Press ENTER..."
}

#-----------------------------------------------------------------------------------
# MODEL: MPAS (GNU)
#-----------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------------
install_MPAS(){
    
    define_compilers "$GNU_MPI"
    export MPAS_EXTERNAL_INCLUDES="-I$LIBS_DIR/include"
    # MPAS SEMPRE USA TODAS AS LIBS DE I/O PARALELAS (PIO, NETCDF, HDF5, PNETCDF)
    export MPAS_EXTERNAL_LIBS="$LIBS_DIR/lib/libpiof.a \
                            $LIBS_DIR/lib/libpioc.a \
                            $LIBS_DIR/lib/libnetcdff.a \
                            $LIBS_DIR/lib/libnetcdf.a \
                            $LIBS_DIR/lib/libhdf5_hl.a \
                            $LIBS_DIR/lib/libhdf5.a -lz -ldl -lm -lpthread"

    cd "$MODEL_DIR_INSTALL"
    rm -rf MPAS-Model 
    git clone https://github.com/MPAS-Dev/MPAS-Model.git
    cd MPAS-Model
    
  

    echo ">> Compiling MPAS..."
    make gfortran CORE=init_atmosphere USE_PIO2=true PRECISION=single "${MAKE_OVERRIDES[@]}"
    make clean CORE=atmosphere USE_PIO2=true PRECISION=single
    make gfortran CORE=atmosphere USE_PIO2=true PRECISION=single -j"$CPU_HALF_EVEN" "${MAKE_OVERRIDES[@]}"
    check_lib_success "atmosphere_model" "$MODEL_DIR_INSTALL/MPAS-Model/atmosphere_model"
    check_lib_success "init_atmosphere" "$MODEL_DIR_INSTALL/MPAS-Model/init_atmosphere_model"
    
  [ "$PROMPTOK" -eq 1 ] && read -p "MPAS build done. Press ENTER..."
}