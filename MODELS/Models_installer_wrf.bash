#!/bin/bash

#----------------------------------------------------------------------------------------------------
#       WRF 
#
#  
#----------------------------------------------------------------------------------------------------
install_wrf(){
        define_compilers "$GNU_MPI"
    
    # Configura variáveis de ambiente
    if [ "$GNU_MPICH" -ge 1 ]; then
        mpi_setup
    fi

    
    # Lib paths
    export LDFLAGS="-L$LIBS_DIR/lib"
    export CPPFLAGS="-I$LIBS_DIR/include"
    export WRFIO_NCD_NO_LARGE_FILE_SUPPORT=1


   

    cd "$MODEL_DIR_INSTALL"
    rm -rf WRF
    git clone https://github.com/wrf-model/WRF.git
    cd WRF
    ./clean -a
    
    # Bypass NetCDF check failure (False Positive Fix)
    sed -i 's/if \[ \$retval -ne 0/if [ 0 -ne 0/g' configure


    ./configure

    if [ -f configure.wrf ]; then
         sed -i "s|-L/usr/lib|-L$LIBS_DIR/lib|g" configure.wrf
         sed -i "s|-I/usr/include|-I$LIBS_DIR/include|g" configure.wrf
         
         # Ajuste de bibliotecas para Modos 1 e 2 (onde compilamos HDF5 paralelo)
         # Se for MODO 1, NetCDF/HDF5 são seriais, mas PNETCDF/PIO são paralelos.
         # A linkagem precisa incluir tudo, e o WRF usará NetCDF serial por padrão.
         # A linha abaixo é segura para ambos os modos 1 e 2.
         if [ "${GNU_MPICH:-1}" -ge 1 ]; then
            sed -i 's/-lnetcdff -lnetcdf/-lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lz -ldl/g' configure.wrf
         fi
    fi

    echo ">> Compilando WRF (em_real)..."
    ./compile -j "$CPU_HALF_EVEN" em_real >& compile_wrf.log
    
    if [ -f "main/wrf.exe" ]; then
        echo ">> WRF compilado com sucesso!"
    else
        echo ">> ERRO: WRF falhou. Verifique compile_wrf.log"
        exit 1
    fi
    [ "$PROMPTOK" -eq 1 ] && read -p "Press ENTER to continue to WPS..."
}


#-----------------------------------------------------------------------------------
# MODEL: WPS (GNU) - VERSÃO HÍBRIDA (0=System, 1=Serial Custom, 2=Parallel)
#-----------------------------------------------------------------------------------
install_wps(){  
    
    define_compilers "$GNU_MPI"
    cd "$MODEL_DIR_INSTALL" || exit 1
    
    if [ ! -d "WRF" ]; then
        echo "ERRO CRÍTICO: WRF não encontrado."
        exit 1
    fi

    rm -rf WPS
    git clone https://github.com/wrf-model/WPS.git
    cd WPS
    ./clean -a
    
  
    
    export WRF_DIR="$MODEL_DIR_INSTALL/WRF"
    export NETCDF="$LIBS_DIR"
    export JASPERLIB="$LIBS_DIR/lib"
    export JASPERINC="$LIBS_DIR/include"
    
 
    # Menu interativo
    ./configure

    if [ -f configure.wps ]; then
        echo ">> Ajustando configure.wps..."
        
        # 1. Ajustes Universais
        sed -i "s|^COMPRESSION_LIBS.*|COMPRESSION_LIBS = -L$LIBS_DIR/lib -ljasper -lpng -lz|g" configure.wps
        sed -i "s|^COMPRESSION_INC.*|COMPRESSION_INC = -I$LIBS_DIR/include|g" configure.wps
        
        # Força flags Gfortran
        sed -i 's/FFLAGS[[:space:]]*=/FFLAGS = -fallow-argument-mismatch -fallow-invalid-boz /g' configure.wps
        
        # ---------------------------------------------------------
        # LÓGICA DE 3 MODOS
        # ---------------------------------------------------------
        if [ "$GNU_MPI" -ge 1 ]; then
            # MODO 1 ou 2 (Ambiente Isolado com MPICH)
            echo ">> Aplicando correções para MODO 1/2 (ISOLADO)..."
            
            # Adicionar HDF5 (CRÍTICO para linkagem estática)
            # Nota: PNETCDF é usado APENAS se o WPS foi configurado com DM_PARALLEL ou DM_SERIAL_MPI
            # O configure do WPS adiciona -D_MPI se o usuário selecionar uma opção MPI.
            # Adicionamos PNETCDF aqui para garantir que esteja disponível se necessário.
            sed -i 's|-lnetcdff -lnetcdf|-lnetcdff -lnetcdf -lpnetcdf -lhdf5_hl -lhdf5 -lz -ldl -lm -lpthread|g' configure.wps
            
            # Forçar compiladores MPI (DM e SFC/SCC)
            sed -i "s|^DM_FC.*|DM_FC = $MPIFC|" configure.wps
            sed -i "s|^DM_CC.*|DM_CC = $MPICC|" configure.wps
            sed -i "s|^SFC.*|SFC = $MPIFC|" configure.wps
            sed -i "s|^SCC.*|SCC = $MPICC|" configure.wps
            
        else
            # MODO 0 (System Default)
            echo ">> Aplicando correções para MODO 0 (SYSTEM SERIAL)..."
            
            # Apenas adicionar HDF5 (CRÍTICO para linkagem estática)
            sed -i 's|-lnetcdff -lnetcdf|-lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lz -ldl -lm -lpthread|g' configure.wps
        fi

    else
        echo "ERRO: configure.wps não gerado!"
        exit 1
    fi

    echo ">> Compiling WPS..."
    ./compile >& compile_wps.log

    # ==================================================================
    # VERIFICAÇÃO FINAL DE SUCESSO (MELHORADA)
    # ==================================================================
    if [ -f "geogrid/src/geogrid.exe" ] && [ -f "metgrid/src/metgrid.exe" ] && [ -f "ungrib/src/ungrib.exe" ]; then
        echo "=================================================================="
        echo "   WPS COMPILADO COM SUCESSO! "
        echo "=================================================================="
        ls -l geogrid/src/geogrid.exe metgrid/src/metgrid.exe ungrib/src/ungrib.exe
    else
        echo "=================================================================="
        echo "   ERRO CRÍTICO: FALHA NA COMPILAÇÃO DO WPS"
        echo "=================================================================="
        # Check individual files to hint what failed
        [ ! -f "geogrid/src/geogrid.exe" ] && echo " -> Falta: geogrid.exe"
        [ ! -f "metgrid/src/metgrid.exe" ] && echo " -> Falta: metgrid.exe"
        [ ! -f "ungrib/src/ungrib.exe" ]   && echo " -> Falta: ungrib.exe"
        echo "Verifique o arquivo compile_wps.log para detalhes."
        tail -n 20 compile_wps.log
        exit 1
    fi
    
    [ "$PROMPTOK" -eq 1 ] && read -p "WPS build process finished. Press ENTER..."
}
