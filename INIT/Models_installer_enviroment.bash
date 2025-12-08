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



#-----------------------------------------------------------------------------
#   Library versions   
#
# ----------------------------------------------------------------------------

export HDF5_Version="1_12_2"
export Zlib_Version="1.3.1"
export Netcdf_C_Version="4.9.2"
export Netcdf_Fortran_Version="4.6.1"
export Mpich_Version="4.2.1"
export Libpng_Version="1.6.39"
export Jasper_Version="1.900.1"
export Pnetcdf_Version="1.12.3"
export Pio_Version="2_5_9"
export jpeg_version="2.5.3"
export ecc_version=2.41.0
export Aec_Version="1.0.6"
export Cdi_Version="2.5.3" 
export Cdi_volume="30033" 
export OpenBlas_Version="0.3.27"

##https://download.gnome.org/sources/libxml2/${libxml2_version}/"libxml2-${LIBXML2_VERSION}.tar.xz"
export LIBXML2_VERSION="2.11.7" ## sub-versão 
export libxml2_version="2.11"



export MPAS_VERSION="MPAS-8.0.1"