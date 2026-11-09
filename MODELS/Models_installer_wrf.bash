#!/bin/bash
#----------------------------------------------------------------------------------------------------
#       WRF / WPS
#
#  Variáveis (ou flags do main):
#     WRF_VERSION / --wrf-version   tag do WRF (ex.: v4.6.1). Vazio = branch padrão (mais recente)
#     WPS_VERSION / --wps-version   tag do WPS (ex.: v4.6.0). Vazio = branch padrão
#     WRF_CONFIG_OPT / --wrf-config número da opção do ./configure do WRF (ex.: 34 = GNU dmpar)
#     WRF_NEST_OPT   / --wrf-nest   opção de aninhamento (padrão 1 = basic)
#     WPS_CONFIG_OPT / --wps-config número da opção do ./configure do WPS
#     Sem *_CONFIG_OPT o ./configure abre o menu interativo, como antes.
#     WRF_SKIP_NETCDF_CHECK=1 (padrão) desativa o teste de NetCDF do configure do WRF,
#     que dá falso negativo com NetCDF estático. Use 0 para manter o teste.
#----------------------------------------------------------------------------------------------------
install_wrf(){
    define_compilers "$GNU_MPI"

    # CORRIGIDO: antes testava $GNU_MPICH (variável inexistente)
    if [ "$GNU_MPI" -ge 1 ]; then
        mpi_setup
    fi

    export LDFLAGS="-L$LIBS_DIR/lib"
    export CPPFLAGS="-I$LIBS_DIR/include"
    export WRFIO_NCD_NO_LARGE_FILE_SUPPORT=1

    cd "$MODEL_DIR_INSTALL"
    rm -rf WRF
    # --recurse-submodules: o WRF 4.4+ precisa do submódulo NoahMP
    git clone --recurse-submodules ${WRF_VERSION:+--branch "$WRF_VERSION"} "$GIT_URL_WRF" WRF
    cd WRF
    ./clean -a

    if [ "${WRF_SKIP_NETCDF_CHECK:-1}" -eq 1 ]; then
        # Bypass NetCDF check failure (falso positivo com NetCDF estático)
        sed -i 's/if \[ \$retval -ne 0/if [ 0 -ne 0/g' configure
    fi

    if [ -n "${WRF_CONFIG_OPT:-}" ]; then
        echo ">> ./configure do WRF com opção $WRF_CONFIG_OPT / nest ${WRF_NEST_OPT:-1} (não interativo)"
        printf '%s\n%s\n' "$WRF_CONFIG_OPT" "${WRF_NEST_OPT:-1}" | ./configure
    else
        ./configure
    fi

    if [ ! -f configure.wrf ]; then
        echo ">> ERRO: configure.wrf não foi gerado."
        exit 1
    fi
    sed -i "s|-L/usr/lib|-L$LIBS_DIR/lib|g" configure.wrf
    sed -i "s|-I/usr/include|-I$LIBS_DIR/include|g" configure.wrf
    # Modos 1 e 2: NetCDF/HDF5 estáticos -> precisa linkar HDF5 + zlib explicitamente
    if [ "$GNU_MPI" -ge 1 ]; then
        sed -i 's/-lnetcdff -lnetcdf/-lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lz -ldl/g' configure.wrf
    fi

    echo ">> Compilando WRF (em_real)... log: $PWD/compile_wrf.log"
    ./compile -j "$CPU_HALF_EVEN" em_real > compile_wrf.log 2>&1 || true

    if [ -f "main/wrf.exe" ]; then
        echo ">> WRF compilado com sucesso!"
        ls -l main/*.exe
    else
        echo ">> ERRO: WRF falhou. Últimas linhas de compile_wrf.log:"
        grep -iE ' error|Error:' compile_wrf.log | tail -n 20 || true
        tail -n 20 compile_wrf.log
        exit 1
    fi
    pause_step "Press ENTER to continue to WPS..."
}


#-----------------------------------------------------------------------------------
# MODEL: WPS (GNU) - VERSÃO HÍBRIDA (0=System, 1=Serial Custom, 2=Parallel)
#-----------------------------------------------------------------------------------
install_wps(){
    define_compilers "$GNU_MPI"
    cd "$MODEL_DIR_INSTALL"

    if [ ! -f "WRF/main/wrf.exe" ]; then
        echo "ERRO CRÍTICO: WRF não encontrado/compilado em $MODEL_DIR_INSTALL/WRF."
        exit 1
    fi

    rm -rf WPS
    git clone ${WPS_VERSION:+--branch "$WPS_VERSION"} "$GIT_URL_WPS" WPS
    cd WPS
    ./clean -a

    export WRF_DIR="$MODEL_DIR_INSTALL/WRF"
    export NETCDF="$LIBS_DIR"
    export JASPERLIB="$LIBS_DIR/lib"
    export JASPERINC="$LIBS_DIR/include"

    if [ -n "${WPS_CONFIG_OPT:-}" ]; then
        echo ">> ./configure do WPS com opção $WPS_CONFIG_OPT (não interativo)"
        printf '%s\n' "$WPS_CONFIG_OPT" | ./configure
    else
        ./configure
    fi

    if [ ! -f configure.wps ]; then
        echo "ERRO: configure.wps não gerado!"
        exit 1
    fi

    echo ">> Ajustando configure.wps..."
    sed -i "s|^COMPRESSION_LIBS.*|COMPRESSION_LIBS = -L$LIBS_DIR/lib -ljasper -lpng -lz|g" configure.wps
    sed -i "s|^COMPRESSION_INC.*|COMPRESSION_INC = -I$LIBS_DIR/include|g" configure.wps

    # Flags do gfortran >= 10 (vazias em versões antigas, que não as aceitam)
    if [ -n "${fallow_argument}${boz_argument}" ]; then
        sed -i "s/FFLAGS[[:space:]]*=/FFLAGS = $fallow_argument $boz_argument /g" configure.wps
    fi

    if [ "$GNU_MPI" -ge 1 ]; then
        echo ">> Aplicando correções para MODO 1/2 (ISOLADO)..."
        sed -i 's|-lnetcdff -lnetcdf|-lnetcdff -lnetcdf -lpnetcdf -lhdf5_hl -lhdf5 -lz -ldl -lm -lpthread|g' configure.wps
        sed -i "s|^DM_FC.*|DM_FC = $MPIFC|" configure.wps
        sed -i "s|^DM_CC.*|DM_CC = $MPICC|" configure.wps
        sed -i "s|^SFC.*|SFC = $MPIFC|" configure.wps
        sed -i "s|^SCC.*|SCC = $MPICC|" configure.wps
    else
        echo ">> Aplicando correções para MODO 0 (SYSTEM SERIAL)..."
        sed -i 's|-lnetcdff -lnetcdf|-lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lz -ldl -lm -lpthread|g' configure.wps
    fi

    echo ">> Compiling WPS... log: $PWD/compile_wps.log"
    ./compile > compile_wps.log 2>&1 || true

    if [ -f "geogrid/src/geogrid.exe" ] && [ -f "metgrid/src/metgrid.exe" ] && [ -f "ungrib/src/ungrib.exe" ]; then
        echo "=================================================================="
        echo "   WPS COMPILADO COM SUCESSO! "
        echo "=================================================================="
        ls -l geogrid/src/geogrid.exe metgrid/src/metgrid.exe ungrib/src/ungrib.exe
    else
        echo "=================================================================="
        echo "   ERRO CRÍTICO: FALHA NA COMPILAÇÃO DO WPS"
        echo "=================================================================="
        [ -f "geogrid/src/geogrid.exe" ] || echo " -> Falta: geogrid.exe"
        [ -f "metgrid/src/metgrid.exe" ] || echo " -> Falta: metgrid.exe"
        [ -f "ungrib/src/ungrib.exe" ]   || echo " -> Falta: ungrib.exe"
        echo "Verifique o arquivo compile_wps.log para detalhes."
        tail -n 20 compile_wps.log
        exit 1
    fi

    pause_step "WPS build process finished. Press ENTER..."
}
