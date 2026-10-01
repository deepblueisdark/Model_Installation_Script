#!/bin/bash 


#--------------------------------------------------------------------------
#
#
#                       LIB PATHS 
#
#
#---------------------------------------------------------------------------

# Base paths for core scientific libraries (all installed under $LIBS_DIR)
export NETCDF=$LIBS_DIR            # NetCDF (C and Fortran)
export HDF5=$LIBS_DIR              # HDF5
export HDF5_DIR=$LIBS_DIR              # HDF5
export PIO=$LIBS_DIR 
export PNETCDF=$LIBS_DIR           # Parallel NetCDF
export HDF5_PLUGIN_PATH=$LIBS_DIR 


# Specific paths for Jasper library (used for GRIB2 support in WRF)
export JASPERLIB=$LIBS_DIR/lib
export JASPERINC=$LIBS_DIR/include

export JPEG_LIBRARY=$LIBS_DIR/lib 
export JPEG_INCLUDE_DIR=$LIBS_DIR/include 

# Compiler flags for include and link paths
export CPPFLAGS="-I$LIBS_DIR/include"     # Include headers
export LDFLAGS="-L$LIBS_DIR/lib"          # Link libraries

# Runtime library path (ensures dynamic libraries are found at runtime)
export LD_LIBRARY_PATH=$LIBS_DIR/lib:$MPI_DIR/lib:$LD_LIBRARY_PATH
export CFLAGS="-O3 -fPIC -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-error=incompatible-pointer-types"
export CXXFLAGS="-O3 -fPIC"
export FFLAGS="-O3 -fPIC"
export FCFLAGS="-O3 -fPIC"  ### -fno-second-underscore -ffree-form"
export LDFLAGS="-fPIC"



