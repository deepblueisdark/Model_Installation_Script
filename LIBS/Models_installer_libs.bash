#!/bin/bash 


#----------------------------------------------------------------------------------------------------
#
#          INSTALAÇÃO MPICH 
#
#----------------------------------------------------------------------------------------------------
install_mpich(){
    define_compilers 1   #### aqui tem que ser 1 por que para compilar  o MPICH precisamos  dos
                         #### compialdores do sistema

    cd "$DOWNLOADS" || { echo "ERROR: Cannot access download directory $DOWNLOADS"; exit 1; }
    wget -nc https://www.mpich.org/static/downloads/$Mpich_Version/mpich-$Mpich_Version.tar.gz

    # Remove any previous source directory
    rm -rf "mpich-$Mpich_Version/"

    # Extract the source tarball
    tar_clean -xvzf "mpich-$Mpich_Version.tar.gz"
    cd "mpich-$Mpich_Version/" || { echo "ERROR: Cannot enter MPICH source directory"; exit 1; }
  
	./configure --prefix="$LIBS_DIR" --with-device=ch3 FFLAGS=$fallow_argument FCFLAGS=$fallow_argument
    

    # Compile, install and check
    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install
    make -j "$CPU_HALF_EVEN" check

    # List installed binaries
    echo ""
    echo ">>> MPICH installed in: $MPI_BIN/bin"
    ls_clean -ltr $LIBS_DIR/bin/mpi*.* 
    ls_clean -ltr $LIBS_DIR/lib/libmpi*  
    check_lib_success "MPICH" "$LIBS_DIR/lib/libmpi.a"
    check_lib_success "MPICH" "$LIBS_DIR/lib/libmpifort.a"

    # Prompt to continue if enabled
    if [ "$PROMPTOK" -eq 1 ]; then
        
        read -p ">>> MPICH installation complete. Press enter to continue..."
        
    fi

} 



#-------------------------------------------------------------------------------------------------
#        ZLIB InstallatION 
# 
#
# ------------------------------------------------------------------------------------------------
install_zlib(){
    define_compilers $GNU_MPI
    echo "$COMPILERS"

    cd "$DOWNLOADS" || { echo "ERRO: sem acesso a $DOWNLOADS"; exit 1; }
    wget -nc https://www.zlib.net/zlib-$Zlib_Version.tar.gz
    TARFILE="zlib-$Zlib_Version.tar.gz"
    SRCDIR="zlib-$Zlib_Version"

    # Sanidade
    [ -f "$TARFILE" ] || { echo "ERRO: $TARFILE não encontrado em $DOWNLOADS"; exit 1; }

    # Teste de integridade do tarball (ambiente limpo)
    tar_clean -tzf "$TARFILE" >/dev/null || { echo "ERRO: $TARFILE corrompido"; exit 1; }

    # Recomeça “limpo”
    rm -rf "$SRCDIR"
    tar_clean -xzf "$TARFILE" || { echo "ERRO: falha ao extrair $TARFILE"; exit 1; }

    cd "$SRCDIR" || { echo "ERRO: diretório-fonte $SRCDIR não existe após extração"; exit 1; }

    FFLAGS=$fallow_argument
    FCFLAGS=$fallow_argument

    eval "$COMPILERS FCFLAGS=\"$FCFLAGS\" CFLAGS=\"$CFLAGS\" ./configure --prefix=\"$LIBS_DIR\""
    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "ZLIB" "$LIBS_DIR/lib/libz.a"
    [ "$PROMPTOK" -eq 1 ] && read -p "ZLIB installed. Press enter to continue..."
}

#------------------------------------------------------------------------------------------------------------
#          
#   LIBPNG INSTALATION 
#
#-------------------------------------------------------------------------------------------------------------
install_libpng(){   
    define_compilers $GNU_MPI
    echo "$COMPILERS"
    cd "$DOWNLOADS"
    wget -nc https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
    rm -rf "libpng-$Libpng_Version/"
    tar_clean -xvzf "libpng-$Libpng_Version.tar.gz"
    cd "libpng-$Libpng_Version/"

    autoreconf -i -f
    eval "$COMPILERS FCFLAGS=\"$FCFLAGS\" CFLAGS=\"$CFLAGS\" ./configure --prefix=\"$LIBS_DIR/\""
    automake -a -f
    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    check_lib_success "LIBPNG" "$LIBS_DIR/lib/libpng.a"

    [ "$PROMPTOK" -eq 1 ] && read -p "LIBPNG installed. Press enter to continue..."
} 

#-----------------------------------------------------------------------------------------------------------------
#        JASPER Installation
#  
# -----------------------------------------------------------------------------------------------------------------
install_jasper(){
    define_compilers define_compilers $GNU_MPI
    cd "$DOWNLOADS" || { echo "ERRO: sem acesso a $DOWNLOADS"; exit 1; }
    wget -nc https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip

    ZIP="jasper-$Jasper_Version.zip"
    SRCDIR="jasper-$Jasper_Version"

    rm -rf "$SRCDIR"
    [ -f "$ZIP" ] || { echo "ERRO: $ZIP não encontrado em $DOWNLOADS"; exit 1; }

    # unzip "limpo" se existir run_clean; senão, unzip normal
    if command -v run_clean >/dev/null 2>&1; then
        run_clean unzip "$ZIP"
    else
        unzip "$ZIP"
    fi
    cd "$SRCDIR" || { echo "ERRO: fonte Jasper não encontrado"; exit 1; }

    # --- PATCH: garante protótipo de jas_eprintf para icx/clang ---
    JAS_GETOPT="src/libjasper/base/jas_getopt.c"
    [ -f "$JAS_GETOPT" ] || JAS_GETOPT="src/base/jas_getopt.c"  # fallback em alguns tarballs
    if [ -f "$JAS_GETOPT" ] && ! grep -q 'jasper/jas_debug.h' "$JAS_GETOPT"; then
        sed -i '1i #include "jasper/jas_debug.h"' "$JAS_GETOPT"
    fi
    
    JAS_CFLAGS="-O3 -fPIC -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-error=incompatible-pointer-types"
    JAS_CPPFLAGS="-I$PWD/src/libjasper/include"
    JAS_LDFLAGS=""

    # Regera autotools se disponível, mas sem travar se não houver
    command -v autoreconf >/dev/null 2>&1 && autoreconf -i -f || true

    # Configure usando SOMENTE as flags locais acima
    eval "$COMPILERS env \
         CPPFLAGS='$JAS_CPPFLAGS' \
         LDFLAGS='$JAS_LDFLAGS' \
         CFLAGS='$JAS_CFLAGS' \
         ./configure --prefix='$LIBS_DIR' --disable-shared --enable-static" \
         || { echo 'ERRO: configure Jasper'; exit 1; }

    make -j "$CPU_HALF_EVEN"              || { echo 'ERRO: make Jasper'; exit 1; }
    make -j "$CPU_HALF_EVEN" install      || { echo 'ERRO: make install Jasper'; exit 1; }


     check_lib_success "JASPER" "$LIBS_DIR/lib/libjasper.a"
    [ "$PROMPTOK" -eq 1 ] && read -p "JASPER instalado. Pressione ENTER para continuar..."
}



# ---------------------------------------------------------------------------------------------------------------
#       HDF5 Installation
#      
# ===================================================================================================
install_hdf5(){   
    define_compilers $GNU_MPI

    cd "$DOWNLOADS" || { echo "ERRO: sem acesso a $DOWNLOADS"; exit 1; }
    wget -nc https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-$HDF5_Version.tar.gz


    # Escolhe tar/ls "limpos" se você já criou essas funções; senão usa padrão
    if command -v tar_clean >/dev/null 2>&1; then TARCMD=tar_clean; else TARCMD=tar; fi
    if command -v ls_clean  >/dev/null 2>&1; then LSCMD=ls_clean;  else LSCMD=ls;  fi

    SRCARC="hdf5-$HDF5_Version.tar.gz"
    SRCDIR="hdf5-hdf5-$HDF5_Version"
    H5_CSTD=""
    EXTRA_CPPFLAGS=""
    rm -rf "$SRCDIR"
    $TARCMD -xzf "$SRCARC" || { echo "ERRO: falha ao extrair $SRCARC"; exit 1; }
    cd "$SRCDIR" || { echo "ERRO: diretório-fonte $SRCDIR não encontrado"; exit 1; }

    # Evita conflito de módulos antigos gerados por outro compilador
    rm -f "$LIBS_DIR/include"/H5*.mod "$LIBS_DIR/include"/h5*.mod 2>/dev/null || true

    H5_CFLAGS="-O3 -fPIC $H5_CSTD"
    H5_FCFLAGS="-O3 -fPIC -ffree-form"

    autoreconf -i -f


    eval "$COMPILERS \
         CPPFLAGS='$EXTRA_CPPFLAGS' LDFLAGS='$LDFLAGS' \
           CFLAGS='$H5_CFLAGS' FCFLAGS='$H5_FCFLAGS' \
         ./configure --prefix='$LIBS_DIR' \
                     --with-zlib='$LIBS_DIR' \
                     --enable-hl \
                     --disable-tests \
                     --enable-fortran \
                     --$( [ "${GNU_MPI:-1}" -eq 2 ] && echo enable || echo disable )-parallel \
                     --disable-shared" \
    || { echo "ERRO: configure do HDF5"; exit 1; }

    make -j "$CPU_HALF_EVEN" || { echo "ERRO: make HDF5"; exit 1; }
    make -j "$CPU_HALF_EVEN" install || { echo "ERRO: make install HDF5"; exit 1; }

    check_lib_success "HDF5" "$LIBS_DIR/lib/libhdf5.a"
    check_lib_success "HDF5-HL" "$LIBS_DIR/lib/libhdf5_hl.a"   
    check_lib_success "HDF5 _HL_FC" "$LIBS_DIR/lib/libhdf5_hl_fortran.a"
    check_lib_success "HDF5 HL_FC" "$LIBS_DIR/lib/libhdf5hl_fortran.a"
    check_lib_success "HDF5 FC" "$LIBS_DIR/lib/libhdf5_fortran.a"
    


    [ "$PROMPTOK" -eq 1 ] && read -p "HDF5 instalado. Pressione ENTER para continuar..."


}



# --------------------------------------------------------------------------------------------------------------------
#
# PNETCDF Installation — SOMENTE PARALELO
#
#
#---------------------------------------------------------------------------------------------------------------------
install_pnetcdf(){
    define_compilers 2  ####### exige paralelo 
    echo ">>> PNETCDF: preparando compilação paralela"

    



    if [ -n "$MPICC" ] && [ -n "$MPIFC" ]; then
        cd "$DOWNLOADS" || { echo "AVISO: sem acesso a $DOWNLOADS — pulando PnetCDF."; }
        wget -nc https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz
        SRCTGZ="pnetcdf-$Pnetcdf_Version.tar.gz"
        SRCDIR="pnetcdf-$Pnetcdf_Version"

        rm -rf "$SRCDIR"
        if command -v tar_clean >/dev/null 2>&1; then
            tar_clean -xzf "$SRCTGZ" || { echo "AVISO: falha ao extrair $SRCTGZ — pulando."; SRCTGZ=""; }
        else
            tar -xzf "$SRCTGZ"       || { echo "AVISO: falha ao extrair $SRCTGZ — pulando."; SRCTGZ=""; }
        fi

        if [ -n "$SRCTGZ" ] && cd "$SRCDIR" 2>/dev/null; then
            command -v autoreconf >/dev/null 2>&1 && autoreconf -i -f || true

            # ---- FLAGS SEGURAS POR COMPILADOR ---
            local_CFLAGS="-O2 -fPIC"
            local_FCFLAGS="-O2 -fPIC"

           
                [ -n "$fallow_argument" ] && local_FCFLAGS="$local_FCFLAGS $fallow_argument"
                [ -n "$boz_argument" ]   && local_FCFLAGS="$local_FCFLAGS $boz_argument"
            
   

            echo ">>> PNETCDF configure:"
            echo "    CC=$MPICC"
            echo "    FC=$MPIFC"
            [ -n "$MPI_WITH_FLAG" ] && echo "    extra: $MPI_WITH_FLAG" || echo "    extra: (sem --with-mpi)"

            CC="$MPICC" FC="$MPIFC" CFLAGS="$local_CFLAGS" FCFLAGS="$local_FCFLAGS" \
            ./configure \
                --prefix="$LIBS_DIR" \
                --disable-shared \
                --enable-static \
                --disable-dependency-tracking \
                ${MPI_WITH_FLAG}


            if [ $? -eq 0 ]; then
                JN="${CPU_HALF_EVEN:-1}"
                make -j "$JN"      || { echo "AVISO: 'make' do PnetCDF falhou — tentando -j1"; make -j1 || true; }
                make -j1 install   || echo "AVISO: 'make install' do PnetCDF falhou."

                # Teste rápido com mpiexec (2 ranks)
                if [ -x "$LIBS_DIR/bin/mpiexec" ]; then
                    make -j1 check MPIRUN="$LIBS_DIR/bin/mpiexec -n 2" || echo "AVISO: 'make check' teve falhas."
                else
                    echo "AVISO: mpiexec não encontrado em $LIBS_DIR/bin — pulando 'make check'."
                fi

                check_lib_success "PNETCDF" "$LIBS_DIR/lib/libpnetcdf.a"

                if [ -x "$LIBS_DIR/bin/pnetcdf-config" ]; then
                    echo ">> pnetcdf-config --all:"
                    "$LIBS_DIR/bin/pnetcdf-config" --all | egrep -i 'version|cc=|fc=|mpi'
                fi
            else
                echo "AVISO: 'configure' do PnetCDF falhou — dumping últimas linhas do config.log:"
                tail -n 60 config.log 2>/dev/null | sed 's/^/    /'
                echo "AVISO: pulando sem interromper o script."
            fi
        else
            echo "AVISO: fonte $SRCDIR não acessível — pulando PnetCDF."
        fi
    fi

    [ "$PROMPTOK" -eq 1 ] && read -p "PNETCDF step finished (built or skipped). Press ENTER to continue..."
}



#-------------------------------------------------------------------------------------------------------------------
#       NETCDF-C Installation
#
# -------------------------------------------------------------------------------------------------------------------
install_netcdf_c(){
    define_compilers $GNU_MPI
    cd "$DOWNLOADS"
    wget -nc https://downloads.unidata.ucar.edu/netcdf-c/$Netcdf_C_Version/netcdf-c-$Netcdf_C_Version.tar.gz
    rm -rf "netcdf-c-$Netcdf_C_Version"
    tar_clean -xzvf "netcdf-c-$Netcdf_C_Version.tar.gz"
    cd "netcdf-c-$Netcdf_C_Version"

    autoreconf -i -f 
    

    # NetCDF-C configure (estático), com e sem PnetCDF
    if [ "${GNU_MPI:-1}" -eq 2 ]; then
   
        echo ">>> NETCDF-C (PARALLELO + PNETCDF)"
        eval "$COMPILERS" \
            CPPFLAGS="-I$LIBS_DIR/include" \
            LDFLAGS="-L$LIBS_DIR/lib" \
            ./configure --prefix="$NETCDF" \
                --disable-dap --disable-byterange --disable-libxml2 \
                --enable-netcdf-4  --enable-netcdf-2  --enable-cdf5 --disable-shared \
                --with-hdf5="$LIBS_DIR" --with-zlib="$LIBS_DIR" \
                --enable-pnetcdf --with-pnetcdf="$LIBS_DIR"
    else
        echo ">>> NETCDF-C (SERIAL, sem PNETCDF)"
        eval "$COMPILERS" \
            CPPFLAGS="-I$LIBS_DIR/include" \
            LDFLAGS="-L$LIBS_DIR/lib" \
            ./configure --prefix="$NETCDF" \
                --disable-dap --disable-byterange --disable-libxml2 \
                --enable-netcdf-4 --enable-cdf5 --disable-shared \
                --with-hdf5="$LIBS_DIR" --with-zlib="$LIBS_DIR"
    fi

    automake -a -f
make -j "$CPU_HALF_EVEN"
make -j "$CPU_HALF_EVEN" check
make -j "$CPU_HALF_EVEN" install

 check_lib_success "NETCDF-C" "$LIBS_DIR/lib/libnetcdf.a"
    [ "$PROMPTOK" -eq 1 ] && read -p "NETCDF-C installed. Press enter to continue..."
}



#-------------------------------------------------------------------------------------------------------------------
#   NETCDF-FORTRAN Install
# 
#
#
#--------------------------------------------------------------------------------------------------------------------
install_netcdf_fortran() { 
    define_compilers "$GNU_MPI"
    export F77="$FC"   # garante que F77 != vazio para o libtool

    cd "$DOWNLOADS" || exit 1
        wget -nc https://downloads.unidata.ucar.edu/netcdf-fortran/$Netcdf_Fortran_Version/netcdf-fortran-$Netcdf_Fortran_Version.tar.gz
    rm -rf "netcdf-fortran-$Netcdf_Fortran_Version"
    tar_clean -xvzf "netcdf-fortran-$Netcdf_Fortran_Version.tar.gz"
    cd "netcdf-fortran-$Netcdf_Fortran_Version" || exit 1

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

    eval "$COMPILERS \
        CPPFLAGS='-I$LIBS_DIR/include $NETCDF_CFLAGS' \
        LDFLAGS='-L$LIBS_DIR/lib -L/usr/lib64' \
        LIBS='$NETCDF_LIBS' \
        ./configure --prefix='$LIBS_DIR' --disable-shared"

    automake -a -f
    make -j "${CPU_HALF_EVEN:-4}"
    make -j "${CPU_HALF_EVEN:-4}" check || echo "AVISO: make check falhou, mas vou tentar instalar assim mesmo"
    make -j "${CPU_HALF_EVEN:-4}" install

    check_lib_success "NETCDF-FORTRAN" "$LIBS_DIR/lib/libnetcdff.a"
    [ "${PROMPTOK:-0}" -eq 1 ] && read -p "NETCDF-FORTRAN installed. Press enter to continue..."
}






#----------------------------------------------------------------------
#            PIO
#----------------------------------------------------------------------
install_pio(){
    define_compilers 2   
    echo ">>> PIO: preparando compilação com wrappers MPI (MPICH do LIBS_DIR/bin, se presente)."

    # Dependências mínimas (no mesmo prefixo $LIBS_DIR)
    missing=()
    [ -f "$LIBS_DIR/lib/libnetcdf.a"  ]   || missing+=("NetCDF-C")
    [ -f "$LIBS_DIR/lib/libnetcdff.a" ]   || missing+=("NetCDF-Fortran")
    [ -f "$LIBS_DIR/lib/libpnetcdf.a" ] || missing+=("PnetCDF")   # NÃO exigir PnetCDF
    { [ -f "$LIBS_DIR/lib/libhdf5.a" ] || [ -f "$LIBS_DIR/lib/libhdf5_serial.a" ]; } || missing+=("HDF5")

    if [ "${#missing[@]}" -gt 0 ]; then
        echo ">>> PIO: SKIP — dependências ausentes: ${missing[*]}"
        echo "          Construa primeiro as libs acima (podem ser seriais; PnetCDF é opcional)."
        [ "$PROMPTOK" -eq 1 ] && read -p "PIO skipped (missing deps). Press ENTER to continue..."
    else
        # Seleciona wrappers MPI (não depende de PARALLEL_VERSION)
        if mpi_setup; then
            echo ">>> PIO: usando wrappers MPI:"
            echo "    MPICC=$MPICC"
            echo "    MPICXX=$MPICXX"
            echo "    MPIFC=$MPIFC"
        else
            echo ">>> PIO: SKIP — wrappers MPI não disponíveis (verifique MPICH em $LIBS_DIR/bin)."
            [ "$PROMPTOK" -eq 1 ] && read -p "PIO skipped (no wrappers). Press ENTER to continue..."
        fi

        if [ -n "$MPICC" ] && [ -n "$MPICXX" ] && [ -n "$MPIFC" ]; then
            cd "$DOWNLOADS" || { echo "AVISO: sem acesso a $DOWNLOADS — pulando PIO.";
             }
                 wget -nc https://github.com/NCAR/ParallelIO/archive/refs/tags/pio$Pio_Version.tar.gz

    #
            rm -rf "ParallelIO-pio$Pio_Version"
            if tar_clean -xzf "pio$Pio_Version.tar.gz"; then
                cd "ParallelIO-pio$Pio_Version" || { echo "AVISO: fonte PIO não encontrado — pulando."; }
                rm -rf build && mkdir build && cd build
                # Evita CMake cache sujo
                rm -f CMakeCache.txt
                rm -rf CMakeFiles

                export CMAKE_PREFIX_PATH="$LIBS_DIR:${CMAKE_PREFIX_PATH:-}"

                cmake \
                    -DCMAKE_C_COMPILER="$MPICC" \
                    -DCMAKE_CXX_COMPILER="$MPICXX" \
                    -DCMAKE_Fortran_COMPILER="$MPIFC" \
                    -DNetCDF_C_PATH="$LIBS_DIR" \
                    -DNetCDF_Fortran_PATH="$LIBS_DIR" \
                    -DHDF5_PATH="$LIBS_DIR" \
                    -DCMAKE_INSTALL_PREFIX="$LIBS_DIR" \
                    -DCMAKE_INSTALL_LIBDIR=lib \
                    -DPIO_USE_MALLOC=ON \
                    -DPIO_ENABLE_TIMING=OFF \
                    -DBUILD_SHARED_LIBS=OFF \
                    -DPIO_ENABLE_PNETCDF=ON \
                    ..

                if [ $? -eq 0 ]; then
                    JN="${CPU_HALF_EVEN:-1}"
                    make -j "$JN" && make -j "$JN" install || echo "AVISO: 'make install' do PIO falhou."
                else
                    echo "AVISO: 'cmake' do PIO falhou — limpe o cache e confira I_MPI_FC=ifx / setvars.sh."
                fi
         
            else
                echo "AVISO: falha ao extrair pio$Pio_Version.tar.gz — pulando PIO."
            fi
        fi
    fi
      check_lib_success "PIO-C" "$LIBS_DIR/lib/libpioc.a"
      check_lib_success "PIO-Fortran" "$LIBS_DIR/lib/libpiof.a"
    [ "$PROMPTOK" -eq 1 ] && read -p "PIO step finished (built or skipped). Press ENTER to continue..."
}


# ----------------------------------------------------------------------------------------------
#        AEC Installation
#  20/09/2025 - GNU OK
#-----------------------------------------------------------------------------------------------
install_aec(){
     define_compilers "$GNU_MPI"
    cd "$DOWNLOADS"
    rm -rf libaec
    git clone https://gitlab.dkrz.de/k202009/libaec.git
    cd libaec/
    mkdir -p build
    cd build/

    cmake .. \
        -DCMAKE_INSTALL_PREFIX=$LIBS_DIR \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DBUILD_SHARED_LIBS=OFF

    make -j "$CPU_HALF_EVEN"
    make install

       check_lib_success "AEC" "$LIBS_DIR/lib/libaec.a"
    [ "$PROMPTOK" -eq 1 ] && read -p "AEC build done. Press enter to continue..."
}



# ----------------------------------------------------------------------
# [13] OPENJPEG
# ----------------------------------------------------------------------
 install_openjpeg(){
 define_compilers "$GNU_MPI"


    echo ">>> [13] Installing OpenJPEG..."
    cd "$DOWNLOADS"
        wget -nc https://github.com/uclouvain/openjpeg/archive/refs/tags/v$jpeg_version.tar.gz

    rm -rf "openjpeg-$jpeg_version"
    tar_clean -xzf "v$jpeg_version.tar.gz"
    cd "openjpeg-$jpeg_version"
    mkdir -p build && cd build
    
    # --- CORREÇÃO DE LINKER E PASTA DE INSTALAÇÃO ---
    # Usamos $LOCAL_CC e $LOCAL_CXX diretamente no CMAKE para garantir o caminho completo.
    cmake .. -DCMAKE_INSTALL_PREFIX="$LIBS_DIR" \
             -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_SHARED_LIBS=OFF \
             -DBUILD_STATIC_LIBS=ON \
             -DBUILD_DOC=OFF \
             -DBUILD_TESTING=OFF \
             -DCMAKE_INSTALL_LIBDIR=lib \
             -DCMAKE_DISABLE_FIND_PACKAGE_TIFF=ON \
             -DCMAKE_DISABLE_FIND_PACKAGE_LCMS2=ON \
             -DCMAKE_C_COMPILER="$LOCAL_CC" \
             -DCMAKE_CXX_COMPILER="$LOCAL_CXX" 
             
    make -j "$CPU_HALF_EVEN" && make -j "$CPU_HALF_EVEN" install
    
    # VERIFICAÇÃO OPENJPEG (agora checa APENAS $LIBS_DIR/lib)
    check_lib_success "OPENJPEG" "$LIBS_DIR/lib/libopenjp2.a"
    
    [ "$PROMPTOK" -eq 1 ] && read -p "OPENJPEG installed. Press enter..."
 }


# --------------------------------------------------------------------------------------------------
#        ECCODES (STATIC)
#
#----------------------------------------------------------------------------------------------------
install_eccodes(){
    define_compilers "$GNU_MPI"
 
   cd "$DOWNLOADS"
      wget -nc  https://confluence.ecmwf.int/download/attachments/45757960/eccodes-$ecc_version-Source.tar.gz
        rm -rf "eccodes-$ecc_version-Source"
    tar_clean -xzf "eccodes-$ecc_version-Source.tar.gz"
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
    make -j "$CPU_HALF_EVEN"  install

    check_lib_success "ECCODES" "$LIBS_DIR/lib/libeccodes.a"
    check_lib_success "ECCODES_F90" "$LIBS_DIR/lib/libeccodes_f90.a"
    [ "$PROMPTOK" -eq 1 ] && read -p "ECCODES estático finalizado. Pressione Enter..."
}

#----------------------------------------------------------------------------------------------------
#        CDI (STATIC, externo)
#  20/09/2025 - GNU OK
#  
#----------------------------------------------------------------------------------------------------
install_cdi(){
        define_compilers "$GNU_MPI"
    
    CDI_VER="cdi-2.5.3"             # troque se quiser outro tag
    CDI_TGZ="libcdi-${CDI_VER}.tar.gz"

    cd "$DOWNLOADS"
    rm -rf libcdi libcdi-* "$CDI_TGZ"

    # Baixa tarball oficial do GitLab (público)
    wget -O "$CDI_TGZ" "https://gitlab.dkrz.de/mpim-sw/libcdi/-/archive/${CDI_VER}/libcdi-${CDI_VER}.tar.gz" || {
        echo "!!! ERRO: não consegui baixar $CDI_TGZ"
        exit 1
    }

    tar -xzf "$CDI_TGZ"
    mv "libcdi-${CDI_VER}" libcdi
    cd libcdi

    # Se faltar ./configure, gera (alguns tarballs já vêm prontos)
    if [ ! -x "./configure" ]; then
        echo ">>> 'configure' ausente; executando autogen.sh/autoreconf ..."
        if [ -x "./autogen.sh" ]; then
            ./autogen.sh
        else
            autoreconf -fi
        fi
    fi

    # Triplet de build (corrige "cannot guess build type")
    BUILD_TRIPLET="$(./config.guess 2>/dev/null || echo $(uname -m)-pc-linux-gnu)"

# export CC=gcc
# export FC=gfortran

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
    # só use se apontar para seu prefixo
    case " $PKGCFG_LIBS " in
      *" -L$LIBS_DIR/lib "*) USE_PC=1 ;;
      *) USE_PC=0 ;;
    esac
fi

if [ "$USE_PC" -eq 1 ]; then
    echo ">>> Usando pkg-config do seu prefixo (estático)"
    export CPPFLAGS="$PKGCFG_CFLAGS"
    # gcc não puxa libstdc++ sozinho; some -lstdc++
    export LIBS="$PKGCFG_LIBS -lstdc++"
else
    echo ">>> ATENÇÃO: eccodes.pc ausente/incompleto — usando fallback manual."
    export CPPFLAGS="-I$LIBS_DIR/include"
    export LIBS="-Wl,--start-group \
      $LIBS_DIR/lib/libeccodes.a \
      $LIBS_DIR/lib/libeccodes_f90.a \
      $LIBS_DIR/lib/libaec.a \
      $LIBS_DIR/lib/libz.a \
      -ldl -lpthread -lm -lstdc++ -Wl,--end-group"

    # acrescente extras se você os habilitou no ecCodes
    [ -f "$LIBS_DIR/lib/libopenjp2.a" ] && LIBS="$LIBS -lopenjp2"
    [ -f "$LIBS_DIR/lib/libpng.a" ]     && LIBS="$LIBS -lpng"
    [ -f "$LIBS_DIR/lib/libnetcdf.a" ]  && LIBS="$LIBS -lnetcdf"
    [ -f "$LIBS_DIR/lib/libhdf5_hl.a" ] && LIBS="$LIBS -lhdf5_hl -lhdf5"
    [ -f "$LIBS_DIR/lib/libsz.a" ]      && LIBS="$LIBS -lsz"
fi

export FCFLAGS="-I$LIBS_DIR/include -I$LIBS_DIR/include/cdi"
export LDFLAGS="-L$LIBS_DIR/lib"

# --- teste rápido de link (diagnóstico pré-configure) ---
# echo 'int main(){return 0;}' > /tmp/t.c
# if ! gcc /tmp/t.c $CPPFLAGS $LDFLAGS $LIBS -o /tmp/t.exe ; then
#     echo ">>> FALHA no link de teste com as libs detectadas."
#     echo ">>> CPPFLAGS: $CPPFLAGS"
#     echo ">>> LDFLAGS : $LDFLAGS"
#     echo ">>> LIBS    : $LIBS"
#     exit 1
# fi
# rm -f /tmp/t.c /tmp/t.exe

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
    make -j "$CPU_HALF_EVEN"  install

    check_lib_success "Libcdi" "$LIBS_DIR/lib/libcdi.a"  
    check_lib_success "libcdi_f2003" "$LIBS_DIR/lib/libcdi_f2003.a" 

    [ "$PROMPTOK" -eq 1 ] && read -p "CDI estático (com Fortran) finalizado. Pressione Enter..."
}


#----------------------------------------------------------------------------------------------------
#        OPENBLAS (STATIC)
#  
#----------------------------------------------------------------------------------------------------
install_openblas(){
        define_compilers "$GNU_MPI"

    echo ">>> OPENBLAS: compilando versão ESTÁTICA..."

    cd "$DOWNLOADS"
    # Baixe a versão desejada (ex.: 0.3.27)
    [ -f OpenBLAS-${OpenBlas_Version}.tar.gz ] || wget https://github.com/xianyi/OpenBLAS/archive/refs/tags/v${OpenBlas_Version}.tar.gz -O OpenBLAS-${OpenBlas_Version}.tar.gz

   
    rm -rf OpenBLAS-${OpenBlas_Version}
    tar -xf OpenBLAS-${OpenBlas_Version}.tar.gz
    cd OpenBLAS-${OpenBlas_Version}

    # Build 100% estático, sem OpenMP para evitar precisar de -fopenmp/-lgomp
    make -j "$CPU_HALF_EVEN" NO_SHARED=1 USE_OPENMP=0
    #make PREFIX="$LIBS_DIR" install
    make NO_SHARED=1 USE_OPENMP=0 PREFIX="$LIBS_DIR" install

    echo ">>> Criando symlinks compatíveis (blas/lapack) -> openblas"
    cd "$LIBS_DIR/lib"
    ln -sf libopenblas.a libblas.a
    ln -sf libopenblas.a liblapack.a

   check_lib_success "OPENBLAS" "$LIBS_DIR/lib/libopenblas.a"
    
    [ "$PROMPTOK" -eq 1 ] && read -p "OpenBLAS estático finalizado. Pressione Enter..."
} 

#----------------------------------------------------------------------------------------------------
#         LIBXML2 (STATIC)
#  
#----------------------------------------------------------------------------------------------------
install_libxml2(){
    define_compilers "$GNU_MPI"


    cd "$DOWNLOADS"

    LIBXML2_TAR="libxml2-${LIBXML2_VERSION}.tar.xz"
    LIBXML2_DIR="libxml2-${LIBXML2_VERSION}"

    # Baixar do repositório GNOME (novo caminho)
    [ -f "$LIBXML2_TAR" ] || \
        wget https://download.gnome.org/sources/libxml2/${libxml2_version}/$LIBXML2_TAR

    # Extrair e entrar no diretório
    rm -rf "$LIBXML2_DIR"
    tar -xf "$LIBXML2_TAR"
    cd "$LIBXML2_DIR"

    # Configuração para build estático, sem Python
    ./configure \
        --prefix="$LIBS_DIR" \
        --disable-shared \
        --enable-static \
        --without-python \
        --without-lzma \
        --without-zlib

    # Compilar e instalar
    make -j "$CPU_HALF_EVEN"
    make -j  "$CPU_HALF_EVEN" install

       
    check_lib_success "LIBXML2" "$LIBS_DIR/lib/libxml2.a"

    [ "$PROMPTOK" -eq 1 ] && read -p "libxml2 estático finalizado. Pressione Enter..."
}
