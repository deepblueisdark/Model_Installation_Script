#!/bin/bash
#--------------------------------------------------------------------------
#
#                       LIB PATHS  (fonte única das variáveis de ambiente)
#
#  Chamado pelo main logo após setup_install_libs_dir.
#--------------------------------------------------------------------------

# Base paths for core scientific libraries (all installed under $LIBS_DIR)
export NETCDF=$LIBS_DIR            # NetCDF (C and Fortran)
export HDF5=$LIBS_DIR              # HDF5
export HDF5_DIR=$LIBS_DIR          # HDF5
export PIO=$LIBS_DIR
export PNETCDF=$LIBS_DIR           # Parallel NetCDF
export HDF5_PLUGIN_PATH=$LIBS_DIR

# Specific paths for Jasper library (used for GRIB2 support in WRF)
export JASPERLIB=$LIBS_DIR/lib
export JASPERINC=$LIBS_DIR/include

export JPEG_LIBRARY=$LIBS_DIR/lib
export JPEG_INCLUDE_DIR=$LIBS_DIR/include

# Binários instalados pelo script (MPICH, nc-config, etc.) têm prioridade
case ":$PATH:" in *":$LIBS_DIR/bin:"*) : ;; *) export PATH="$LIBS_DIR/bin:$PATH" ;; esac

# Runtime library path (ensures dynamic libraries are found at runtime)
export LD_LIBRARY_PATH="$LIBS_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Compiler flags
export CFLAGS="-O3 -fPIC -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-error=incompatible-pointer-types"
export CXXFLAGS="-O3 -fPIC"
export FFLAGS="-O3 -fPIC"
export FCFLAGS="-O3 -fPIC"  ### -fno-second-underscore -ffree-form"

# Include/link paths
# (CORRIGIDO: antes o LDFLAGS era sobrescrito por "-fPIC" e perdia o -L)
export CPPFLAGS="-I$LIBS_DIR/include"
export LDFLAGS="-L$LIBS_DIR/lib"
