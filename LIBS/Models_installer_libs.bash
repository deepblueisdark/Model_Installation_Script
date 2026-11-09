#!/bin/bash
#----------------------------------------------------------------------------------------------------
#
#   INSTALAÇÃO DAS BIBLIOTECAS
#
#   Cada install_* roda dentro de run_step (subshell com 'set -e'): qualquer
#   comando que falhe interrompe SÓ aquela etapa, e o erro aparece no log.
#   Downloads: função fetch (LIBS/Models_installer_downloads.bash).
#
#----------------------------------------------------------------------------------------------------


#----------------------------------------------------------------------------------------------------
#          INSTALAÇÃO MPICH
#----------------------------------------------------------------------------------------------------
install_mpich(){
    define_compilers 1   #### aqui tem que ser 1 porque para compilar o MPICH precisamos
                         #### dos compiladores do sistema

    cd "$DOWNLOADS" || { echo "ERROR: Cannot access download directory $DOWNLOADS"; exit 1; }
    fetch mpich

    rm -rf "mpich-$Mpich_Version/"
    extract_archive "$FETCHED_FILE"
    cd "mpich-$Mpich_Version/" || { echo "ERROR: Cannot enter MPICH source directory"; exit 1; }

    ./configure --prefix="$LIBS_DIR" --with-device=ch3 FFLAGS="$fallow_argument" FCFLAGS="$fallow_argument"

    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install
    run_checks make -j "$CPU_HALF_EVEN" check

    echo ""
    echo ">>> MPICH installed in: $LIBS_DIR/bin"
    ls_clean -ltr "$LIBS_DIR"/bin/mpi* || true
    ls_clean -ltr "$LIBS_DIR"/lib/libmpi* || true
    check_lib_success "MPICH" "$LIBS_DIR/lib/libmpi.a"
    check_lib_success "MPICH" "$LIBS_DIR/lib/libmpifort.a"

    pause_step ">>> MPICH installation complete. Press enter to continue..."
}


#-------------------------------------------------------------------------------------------------
#        ZLIB
#-------------------------------------------------------------------------------------------------
install_zlib(){
    define_compilers "$GNU_MPI"

    cd "$DOWNLOADS" || { echo "ERRO: sem acesso a $DOWNLOADS"; exit 1; }
    fetch zlib
    SRCDIR="zlib-$Zlib_Version"

    rm -rf "$SRCDIR"
    extract_archive "$FETCHED_FILE"
    cd "$SRCDIR" || { echo "ERRO: diretório-fonte $SRCDIR não existe após extração"; exit 1; }

    CFLAGS="$CFLAGS" ./configure --prefix="$LIBS_DIR"
    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "ZLIB" "$LIBS_DIR/lib/libz.a"
    pause_step "ZLIB installed. Press enter to continue..."
}


#-------------------------------------------------------------------------------------------------
#        LIBPNG
#-------------------------------------------------------------------------------------------------
install_libpng(){
    define_compilers "$GNU_MPI"
    cd "$DOWNLOADS"
    fetch libpng
    rm -rf "libpng-$Libpng_Version/"
    extract_archive "$FETCHED_FILE"
    cd "libpng-$Libpng_Version/"

    autoreconf -i -f
    CFLAGS="$CFLAGS" ./configure --prefix="$LIBS_DIR"
    automake -a -f || true
    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "LIBPNG" "$LIBS_DIR/lib/libpng.a"
    pause_step "LIBPNG installed. Press enter to continue..."
}


#-------------------------------------------------------------------------------------------------
#        JASPER
#-------------------------------------------------------------------------------------------------
install_jasper(){
    define_compilers "$GNU_MPI"     # CORRIGIDO: antes "define_compilers define_compilers $GNU_MPI"
    cd "$DOWNLOADS" || { echo "ERRO: sem acesso a $DOWNLOADS"; exit 1; }
    fetch jasper                    # .zip (uvic) ou .tar.gz (espelho UCAR)

    SRCDIR="jasper-$Jasper_Version"
    rm -rf "$SRCDIR"
    extract_archive "$FETCHED_FILE"
    cd "$SRCDIR" || { echo "ERRO: fonte Jasper não encontrado"; exit 1; }

    # --- PATCH: garante protótipo de jas_eprintf para icx/clang ---
    JAS_GETOPT="src/libjasper/base/jas_getopt.c"
    [ -f "$JAS_GETOPT" ] || JAS_GETOPT="src/base/jas_getopt.c"
    if [ -f "$JAS_GETOPT" ] && ! grep -q 'jasper/jas_debug.h' "$JAS_GETOPT"; then
        sed -i '1i #include "jasper/jas_debug.h"' "$JAS_GETOPT"
    fi

    JAS_CFLAGS="-O3 -fPIC -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-error=incompatible-pointer-types"
    JAS_CPPFLAGS="-I$PWD/src/libjasper/include"

    # Regera autotools se disponível, mas sem travar se não houver
    { command -v autoreconf >/dev/null 2>&1 && autoreconf -i -f; } || true

    CPPFLAGS="$JAS_CPPFLAGS" LDFLAGS="" CFLAGS="$JAS_CFLAGS" \
        ./configure --prefix="$LIBS_DIR" --disable-shared --enable-static

    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "JASPER" "$LIBS_DIR/lib/libjasper.a"
    pause_step "JASPER instalado. Pressione ENTER para continuar..."
}


#-------------------------------------------------------------------------------------------------
#        HDF5
#-------------------------------------------------------------------------------------------------
install_hdf5(){
    define_compilers "$GNU_MPI"

    cd "$DOWNLOADS" || { echo "ERRO: sem acesso a $DOWNLOADS"; exit 1; }
    fetch hdf5

    SRCDIR="hdf5-hdf5-$HDF5_Version"
    rm -rf "$SRCDIR"
    extract_archive "$FETCHED_FILE"
    cd "$SRCDIR" || { echo "ERRO: diretório-fonte $SRCDIR não encontrado"; exit 1; }

    # Evita conflito de módulos antigos gerados por outro compilador
    rm -f "$LIBS_DIR/include"/H5*.mod "$LIBS_DIR/include"/h5*.mod 2>/dev/null || true

    H5_CFLAGS="-O3 -fPIC"
    H5_FCFLAGS="-O3 -fPIC -ffree-form"
    if [ "${GNU_MPI:-1}" -eq 2 ]; then H5_PARALLEL="--enable-parallel"; else H5_PARALLEL="--disable-parallel"; fi

    autoreconf -i -f

    CPPFLAGS="" LDFLAGS="$LDFLAGS" CFLAGS="$H5_CFLAGS" FCFLAGS="$H5_FCFLAGS" \
        ./configure --prefix="$LIBS_DIR" \
                    --with-zlib="$LIBS_DIR" \
                    --enable-hl \
                    --disable-tests \
                    --enable-fortran \
                    $H5_PARALLEL \
                    --disable-shared

    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "HDF5"     "$LIBS_DIR/lib/libhdf5.a"
    check_lib_success "HDF5-HL"  "$LIBS_DIR/lib/libhdf5_hl.a"
    check_lib_success "HDF5 FC"  "$LIBS_DIR/lib/libhdf5_fortran.a"
    # CORRIGIDO: o nome da lib HL-Fortran varia (autotools x cmake); aceita qualquer um
    check_any_lib_success "HDF5 HL_FC" "$LIBS_DIR/lib/libhdf5hl_fortran.a" "$LIBS_DIR/lib/libhdf5_hl_fortran.a"

    pause_step "HDF5 instalado. Pressione ENTER para continuar..."
}


#-------------------------------------------------------------------------------------------------
#        PNETCDF — SOMENTE PARALELO
#-------------------------------------------------------------------------------------------------
install_pnetcdf(){
    define_compilers 2  ####### exige paralelo
    echo ">>> PNETCDF: preparando compilação paralela"

    if [ -z "$MPICC" ] || [ -z "$MPIFC" ]; then
        echo "ERRO: wrappers MPI não encontrados. Instale o MPICH antes (--libs mpich)."
        exit 1
    fi

    cd "$DOWNLOADS"
    fetch pnetcdf
    SRCDIR="pnetcdf-$Pnetcdf_Version"
    rm -rf "$SRCDIR"
    extract_archive "$FETCHED_FILE"
    cd "$SRCDIR"

    { command -v autoreconf >/dev/null 2>&1 && autoreconf -i -f; } || true

    local_CFLAGS="-O2 -fPIC"
    local_FCFLAGS="-O2 -fPIC"
    [ -n "$fallow_argument" ] && local_FCFLAGS="$local_FCFLAGS $fallow_argument"
    [ -n "$boz_argument" ]   && local_FCFLAGS="$local_FCFLAGS $boz_argument"

    echo ">>> PNETCDF configure:  CC=$MPICC  FC=$MPIFC  ${MPI_WITH_FLAG:-(sem --with-mpi)}"

    if ! CC="$MPICC" FC="$MPIFC" CFLAGS="$local_CFLAGS" FCFLAGS="$local_FCFLAGS" \
        ./configure \
            --prefix="$LIBS_DIR" \
            --disable-shared \
            --enable-static \
            --disable-dependency-tracking \
            ${MPI_WITH_FLAG:-}; then
        echo "ERRO: 'configure' do PnetCDF falhou — últimas linhas do config.log:"
        tail -n 60 config.log 2>/dev/null | sed 's/^/    /' || true
        exit 1
    fi

    make -j "$CPU_HALF_EVEN" || { echo "AVISO: 'make' paralelo falhou — tentando -j1"; make -j1; }
    make -j1 install

    if [ -x "$LIBS_DIR/bin/mpiexec" ]; then
        run_checks make -j1 check MPIRUN="$LIBS_DIR/bin/mpiexec -n 2"
    fi

    check_lib_success "PNETCDF" "$LIBS_DIR/lib/libpnetcdf.a"

    if [ -x "$LIBS_DIR/bin/pnetcdf-config" ]; then
        echo ">> pnetcdf-config --all:"
        "$LIBS_DIR/bin/pnetcdf-config" --all | grep -Ei 'version|cc=|fc=|mpi' || true
    fi

    pause_step "PNETCDF finished. Press ENTER to continue..."
}


#-------------------------------------------------------------------------------------------------
#        NETCDF-C
#-------------------------------------------------------------------------------------------------
install_netcdf_c(){
    define_compilers "$GNU_MPI"
    cd "$DOWNLOADS"
    fetch netcdf_c
    rm -rf "netcdf-c-$Netcdf_C_Version"
    extract_archive "$FETCHED_FILE"
    cd "netcdf-c-$Netcdf_C_Version"

    autoreconf -i -f

    NC_OPTS=( --prefix="$NETCDF"
              --disable-dap --disable-byterange --disable-libxml2
              --enable-netcdf-4 --enable-cdf5 --disable-shared
              --with-hdf5="$LIBS_DIR" --with-zlib="$LIBS_DIR" )

    if [ "${GNU_MPI:-1}" -eq 2 ]; then
        echo ">>> NETCDF-C (PARALELO + PNETCDF)"
        NC_OPTS+=( --enable-netcdf-2 --enable-pnetcdf --with-pnetcdf="$LIBS_DIR" )
    else
        echo ">>> NETCDF-C (SERIAL, sem PNETCDF)"
    fi

    CPPFLAGS="-I$LIBS_DIR/include" LDFLAGS="-L$LIBS_DIR/lib" ./configure "${NC_OPTS[@]}"

    automake -a -f || true
    make -j "$CPU_HALF_EVEN"
    run_checks make -j "$CPU_HALF_EVEN" check
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "NETCDF-C" "$LIBS_DIR/lib/libnetcdf.a"
    pause_step "NETCDF-C installed. Press enter to continue..."
}


#-------------------------------------------------------------------------------------------------
#        NETCDF-FORTRAN
#-------------------------------------------------------------------------------------------------
install_netcdf_fortran() {
    define_compilers "$GNU_MPI"
    export F77="$FC"   # garante que F77 != vazio para o libtool

    cd "$DOWNLOADS"
    fetch netcdf_fortran
    rm -rf "netcdf-fortran-$Netcdf_Fortran_Version"
    extract_archive "$FETCHED_FILE"
    cd "netcdf-fortran-$Netcdf_Fortran_Version"

    NC_CONFIG="$LIBS_DIR/bin/nc-config"
    if [ ! -x "$NC_CONFIG" ]; then
        echo "ERRO: não encontrei $NC_CONFIG (NetCDF-C não instalado em $LIBS_DIR?)."
        exit 1
    fi

    NETCDF_CFLAGS="$("$NC_CONFIG" --cflags)"
    NETCDF_LIBS="$("$NC_CONFIG" --libs)"   # sem --static
    echo "CFLAGS do NETCDF-C: $NETCDF_CFLAGS"
    echo "LIBS   do NETCDF-C: $NETCDF_LIBS"

    autoreconf -i -f

    CPPFLAGS="-I$LIBS_DIR/include $NETCDF_CFLAGS" \
    LDFLAGS="-L$LIBS_DIR/lib -L/usr/lib64" \
    LIBS="$NETCDF_LIBS" \
        ./configure --prefix="$LIBS_DIR" --disable-shared

    automake -a -f || true
    make -j "$CPU_HALF_EVEN"
    run_checks make -j "$CPU_HALF_EVEN" check
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "NETCDF-FORTRAN" "$LIBS_DIR/lib/libnetcdff.a"
    pause_step "NETCDF-FORTRAN installed. Press enter to continue..."
}


#-------------------------------------------------------------------------------------------------
#        PIO  (exige NetCDF-C, NetCDF-Fortran, HDF5 e PnetCDF)
#-------------------------------------------------------------------------------------------------
install_pio(){
    define_compilers 2
    echo ">>> PIO: compilação com wrappers MPI (MPICH do LIBS_DIR/bin, se presente)."

    missing=()
    [ -f "$LIBS_DIR/lib/libnetcdf.a"  ] || missing+=("NetCDF-C")
    [ -f "$LIBS_DIR/lib/libnetcdff.a" ] || missing+=("NetCDF-Fortran")
    [ -f "$LIBS_DIR/lib/libpnetcdf.a" ] || missing+=("PnetCDF")    # PIO é compilado com -DPIO_ENABLE_PNETCDF=ON
    { [ -f "$LIBS_DIR/lib/libhdf5.a" ] || [ -f "$LIBS_DIR/lib/libhdf5_serial.a" ]; } || missing+=("HDF5")

    # CORRIGIDO: antes o check_lib_success rodava mesmo quando o PIO era pulado
    if [ "${#missing[@]}" -gt 0 ]; then
        echo "ERRO: PIO — dependências ausentes: ${missing[*]}"
        echo "      Instale antes, ex.: --libs netcdf_c,netcdf_fortran,pnetcdf"
        exit 1
    fi
    if [ -z "$MPICC" ] || [ -z "$MPICXX" ] || [ -z "$MPIFC" ]; then
        echo "ERRO: PIO — wrappers MPI não disponíveis (verifique MPICH em $LIBS_DIR/bin)."
        exit 1
    fi
    echo "    MPICC=$MPICC  MPICXX=$MPICXX  MPIFC=$MPIFC"

    cd "$DOWNLOADS"
    fetch pio
    rm -rf "ParallelIO-pio$Pio_Version"
    extract_archive "$FETCHED_FILE"
    cd "ParallelIO-pio$Pio_Version"
    rm -rf build && mkdir build && cd build

    export CMAKE_PREFIX_PATH="$LIBS_DIR:${CMAKE_PREFIX_PATH:-}"

    cmake \
        -DCMAKE_C_COMPILER="$MPICC" \
        -DCMAKE_CXX_COMPILER="$MPICXX" \
        -DCMAKE_Fortran_COMPILER="$MPIFC" \
        -DNetCDF_C_PATH="$LIBS_DIR" \
        -DNetCDF_Fortran_PATH="$LIBS_DIR" \
        -DPnetCDF_PATH="$LIBS_DIR" \
        -DHDF5_PATH="$LIBS_DIR" \
        -DCMAKE_INSTALL_PREFIX="$LIBS_DIR" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DPIO_USE_MALLOC=ON \
        -DPIO_ENABLE_TIMING=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DPIO_ENABLE_PNETCDF=ON \
        ..

    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "PIO-C"       "$LIBS_DIR/lib/libpioc.a"
    check_lib_success "PIO-Fortran" "$LIBS_DIR/lib/libpiof.a"
    pause_step "PIO finished. Press ENTER to continue..."
}


#-------------------------------------------------------------------------------------------------
#        AEC  (git)
#-------------------------------------------------------------------------------------------------
install_aec(){
    define_compilers "$GNU_MPI"
    cd "$DOWNLOADS"
    rm -rf libaec
    git clone --depth 1 "$GIT_URL_AEC" libaec
    cd libaec/
    mkdir -p build
    cd build/

    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$LIBS_DIR" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DBUILD_SHARED_LIBS=OFF

    make -j "$CPU_HALF_EVEN"
    make install

    check_lib_success "AEC" "$LIBS_DIR/lib/libaec.a"
    pause_step "AEC build done. Press enter to continue..."
}


#-------------------------------------------------------------------------------------------------
#        OPENJPEG
#-------------------------------------------------------------------------------------------------
install_openjpeg(){
    define_compilers "$GNU_MPI"

    echo ">>> Installing OpenJPEG..."
    cd "$DOWNLOADS"
    fetch openjpeg
    rm -rf "openjpeg-$jpeg_version"
    extract_archive "$FETCHED_FILE"
    cd "openjpeg-$jpeg_version"
    mkdir -p build && cd build

    # CORRIGIDO: antes usava $LOCAL_CC/$LOCAL_CXX, que nunca eram definidos
    cmake .. -DCMAKE_INSTALL_PREFIX="$LIBS_DIR" \
             -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_SHARED_LIBS=OFF \
             -DBUILD_STATIC_LIBS=ON \
             -DBUILD_DOC=OFF \
             -DBUILD_TESTING=OFF \
             -DCMAKE_INSTALL_LIBDIR=lib \
             -DCMAKE_DISABLE_FIND_PACKAGE_TIFF=ON \
             -DCMAKE_DISABLE_FIND_PACKAGE_LCMS2=ON \
             -DCMAKE_C_COMPILER="$CC" \
             -DCMAKE_CXX_COMPILER="$CXX"

    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "OPENJPEG" "$LIBS_DIR/lib/libopenjp2.a"
    pause_step "OPENJPEG installed. Press enter..."
}


#-------------------------------------------------------------------------------------------------
#        ECCODES (STATIC)
#-------------------------------------------------------------------------------------------------
install_eccodes(){
    define_compilers "$GNU_MPI"

    cd "$DOWNLOADS"
    fetch eccodes
    rm -rf "eccodes-$ecc_version-Source"
    extract_archive "$FETCHED_FILE"
    cd "eccodes-$ecc_version-Source"
    mkdir -p build && cd build

    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$LIBS_DIR" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DBUILD_SHARED_LIBS=OFF \
        -DENABLE_NETCDF=OFF \
        -DENABLE_GRIB_API_COMPAT=ON \
        -DENABLE_JPG=OFF \
        -DENABLE_PNG=OFF \
        -DENABLE_AEC=ON \
        -DENABLE_FORTRAN=ON \
        -DCMAKE_PREFIX_PATH="$LIBS_DIR" \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,--start-group $LIBS_DIR/lib/libaec.a $LIBS_DIR/lib/libz.a -ldl -Wl,--end-group"

    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "ECCODES"     "$LIBS_DIR/lib/libeccodes.a"
    check_lib_success "ECCODES_F90" "$LIBS_DIR/lib/libeccodes_f90.a"
    pause_step "ECCODES estático finalizado. Pressione Enter..."
}


#-------------------------------------------------------------------------------------------------
#        CDI (STATIC)
#-------------------------------------------------------------------------------------------------
install_cdi(){
    define_compilers "$GNU_MPI"

    # CORRIGIDO: antes a versão era fixa ("cdi-2.5.3") e ignorava Cdi_Version
    CDI_VER="cdi-${Cdi_Version}"

    cd "$DOWNLOADS"
    rm -rf libcdi "libcdi-${CDI_VER}"
    fetch cdi
    extract_archive "$FETCHED_FILE"
    mv "libcdi-${CDI_VER}" libcdi
    cd libcdi

    # Se faltar ./configure, gera (alguns tarballs já vêm prontos)
    if [ ! -x "./configure" ]; then
        echo ">>> 'configure' ausente; executando autogen.sh/autoreconf ..."
        if [ -x "./autogen.sh" ]; then ./autogen.sh; else autoreconf -fi; fi
    fi

    # Triplet de build (corrige "cannot guess build type")
    BUILD_TRIPLET="$(./config.guess 2>/dev/null || echo "$(uname -m)-pc-linux-gnu")"

    # garanta que o seu .pc vem primeiro
    export PKG_CONFIG_PATH="$LIBS_DIR/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    export PKG_CONFIG_ALL_STATIC=1
    echo ">>> PKG_CONFIG_PATH=$PKG_CONFIG_PATH"

    USE_PC=0
    if PKGCFG_CFLAGS="$(pkg-config --cflags eccodes 2>/dev/null)" \
       && PKGCFG_LIBS="$(pkg-config --libs --static eccodes 2>/dev/null)"; then
        echo ">>> eccodes.pc encontrado"
        echo "    CFLAGS: $PKGCFG_CFLAGS"
        echo "    LIBS  : $PKGCFG_LIBS"
        case " $PKGCFG_LIBS " in
          *" -L$LIBS_DIR/lib "*) USE_PC=1 ;;
          *) USE_PC=0 ;;
        esac
    fi

    if [ "$USE_PC" -eq 1 ]; then
        echo ">>> Usando pkg-config do seu prefixo (estático)"
        export CPPFLAGS="$PKGCFG_CFLAGS"
        export LIBS="$PKGCFG_LIBS -lstdc++"     # gcc não puxa libstdc++ sozinho
    else
        echo ">>> ATENÇÃO: eccodes.pc ausente/incompleto — usando fallback manual."
        export CPPFLAGS="-I$LIBS_DIR/include"
        export LIBS="-Wl,--start-group \
          $LIBS_DIR/lib/libeccodes.a \
          $LIBS_DIR/lib/libeccodes_f90.a \
          $LIBS_DIR/lib/libaec.a \
          $LIBS_DIR/lib/libz.a \
          -ldl -lpthread -lm -lstdc++ -Wl,--end-group"
        if [ -f "$LIBS_DIR/lib/libopenjp2.a" ]; then LIBS="$LIBS -lopenjp2"; fi
        if [ -f "$LIBS_DIR/lib/libpng.a" ];     then LIBS="$LIBS -lpng"; fi
        if [ -f "$LIBS_DIR/lib/libnetcdf.a" ];  then LIBS="$LIBS -lnetcdf"; fi
        if [ -f "$LIBS_DIR/lib/libhdf5_hl.a" ]; then LIBS="$LIBS -lhdf5_hl -lhdf5"; fi
        if [ -f "$LIBS_DIR/lib/libsz.a" ];      then LIBS="$LIBS -lsz"; fi
    fi

    export FCFLAGS="-I$LIBS_DIR/include -I$LIBS_DIR/include/cdi"
    export LDFLAGS="-L$LIBS_DIR/lib"

    ./configure \
      --build="$BUILD_TRIPLET" \
      --prefix="$LIBS_DIR" \
      --libdir="$LIBS_DIR/lib" \
      --includedir="$LIBS_DIR/include" \
      --disable-shared --enable-static \
      --with-eccodes="$LIBS_DIR" \
      --with-netcdf="$LIBS_DIR" \
      --enable-iso-c-interface

    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "Libcdi"       "$LIBS_DIR/lib/libcdi.a"
    check_lib_success "libcdi_f2003" "$LIBS_DIR/lib/libcdi_f2003.a"
    pause_step "CDI estático (com Fortran) finalizado. Pressione Enter..."
}


#-------------------------------------------------------------------------------------------------
#        OPENBLAS (STATIC)
#-------------------------------------------------------------------------------------------------
install_openblas(){
    define_compilers "$GNU_MPI"
    echo ">>> OPENBLAS: compilando versão ESTÁTICA..."

    cd "$DOWNLOADS"
    fetch openblas
    rm -rf "OpenBLAS-${OpenBlas_Version}"
    extract_archive "$FETCHED_FILE"
    cd "OpenBLAS-${OpenBlas_Version}"

    # Build 100% estático, sem OpenMP para evitar precisar de -fopenmp/-lgomp
    make -j "$CPU_HALF_EVEN" NO_SHARED=1 USE_OPENMP=0
    make NO_SHARED=1 USE_OPENMP=0 PREFIX="$LIBS_DIR" install

    echo ">>> Criando symlinks compatíveis (blas/lapack) -> openblas"
    cd "$LIBS_DIR/lib"
    ln -sf libopenblas.a libblas.a
    ln -sf libopenblas.a liblapack.a

    check_lib_success "OPENBLAS" "$LIBS_DIR/lib/libopenblas.a"
    pause_step "OpenBLAS estático finalizado. Pressione Enter..."
}


#-------------------------------------------------------------------------------------------------
#        LIBXML2 (STATIC)
#-------------------------------------------------------------------------------------------------
install_libxml2(){
    define_compilers "$GNU_MPI"

    cd "$DOWNLOADS"
    fetch libxml2
    LIBXML2_DIR="libxml2-${LIBXML2_VERSION}"
    rm -rf "$LIBXML2_DIR"
    extract_archive "$FETCHED_FILE"
    cd "$LIBXML2_DIR"

    ./configure \
        --prefix="$LIBS_DIR" \
        --disable-shared \
        --enable-static \
        --without-python \
        --without-lzma \
        --without-zlib

    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "LIBXML2" "$LIBS_DIR/lib/libxml2.a"
    pause_step "libxml2 estático finalizado. Pressione Enter..."
}
