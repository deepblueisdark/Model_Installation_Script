#!/bin/bash

#-------------------------------------------------------------------------------
#
#       WRF AND MPAS MODEL INSTALLER
#
#       INSTALLS ALL LIBRARIES REQUIRED TO BUILD THE WRF AND MPAS MODELS.
#       EVERYTHING IS USER-DEFINED AND MODIFIABLE.
#
#       REGINALDO VENTURA DE SA - RVS - (reginaldo.venturadesa@gmail.com)
#       20/03/2025 : WRF
#       15/04/2025 : MPAS
# ------------------------------------------------------------
#
#  29/05 -  python 3 tests and  gfortran version tests  (RVS)
#
#-------------------------------------------------------------------------------
#---------------------------------------------------------------------------
#
# PROMPTOK=1 means the script will pause after each installation step
#
#----------------------------------------------------------------------------
PROMPTOK=1

#-----------------------------------------------------------------------------
#
#                        OPTIONS
#
# Each entry in the OPTIONS array corresponds to a specific step.
# If set to 1, that step will be executed; if 0, it will be skipped.
#
OPTIONS=(
    0  #### [0]  Update system packages       WRF/MPAS/ICON
    0  #### [1]  Create directories           WRF/MPAS/ICON 
    0  #### [2]  Download necessary files     WRF/MPAS/ICON
    0  #### [3]  MPICH                        WRF/MPAS/ICON 
    0  #### [4]  ZLIB (serial)                WRF/MPAS/ICON
    0  #### [5]  libpng                       WRF/MPAS/ICON
    0  #### [6]  jasper                       WRF/MPAS/ICON
    0  #### [7]  HDF5 (serial)                WRF/MPAS/ICON
    0  #### [8]  Parallel NetCDF              WRF/MPAS/ 
    0  #### [9]  NetCDF-C                     WRF/MPAS/ICON 
    0  #### [10] NetCDF-Fortran               WRF/MPAS/ICON
    0  #### [11] PIO                          MPAS
    0  #### [12] aec                          ICON
    0  #### [13] OPENJPG                      ICON ( WRF ??? /MPAS ???)
    0  #### [14] ECCODES                      ICON
    0  #### [15] CDI                          ICON 
    0  #### [16] OPENBLAS                     ICON ( WRF ??? /MPAS ???) 
    0  #### [17] LIBXML2                      ICON ( WRF ??? /MPAS ???)
   )
#-------------------------------------------------------------------------------
MODELS=(
    1  ### [0] WRF 
    0  ### [1] WPS
    0  ### [2] MPAS
    0  ### [3] GEOG (DADOS TERRENO)         MPAS/WRF 
    0  ### [4] MAPS 7.0 
    0  ### [5] ICON  (AINDA NAO IMPLEMENTADO)

 )

 # -----------------------------------------------------------------------
#
#            COMPILER (default: gnu) 
#
#
# Use default COMPILER if not defined by user
#COMPILER=
COMPILER=${COMPILER:-GNU}

#---------------------------------------------------------------------------
#
#        INSTALL LOCAL 
#
#
HOME_DIR=$HOME
INSTALLATION_PATH="$HOME_DIR/MODELS"
export INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/"
GEOG="$HOME_DIR/MODELS/GEOG/"

#------------------------------------------------------------------------------
#
# Define download directory
#
#
#
export DOWNLOADS="$HOME/Downloads"



#-------------------------------------------------------------------------------------------------
# PARALLEL_VERSION
# 0: Build in serial mode — libraries are compiled with the base compilers (CC/CXX/FC).
# 1: Build in MPI mode — all libraries are compiled using MPI wrapper compilers, i.e.:
#    CC  -> MPICC   (mpicc or mpiicc)
#    CXX -> MPICXX  (mpicxx or mpiicpc)
#    FC  -> MPIFC   (mpifort or mpiifort)
#    The exact wrappers are selected by mpi_setup():
#      - MPICH when INTEL_MPI=0 (any COMPILER)
#      - Intel MPI when COMPILER=INTEL and INTEL_MPI=1
#    Make sure the chosen MPI is on PATH (and its libs on LD_LIBRARY_PATH) before building.
#    Note: Only the compilation of libraries/programs switches to wrappers; system tools
#    (tar, ls, etc.) should run in a clean environment when oneAPI is loaded.
#
# Directory layout also reflects this choice (see INSTALL_DIR/LIBS_DIR/MPI_DIR rules).
#------------------------------------------------------------------------------------------
#   - GNU/NVIDIA:
#       PARALLEL_VERSION=0  -> INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/"
#       PARALLEL_VERSION=1  -> INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/MPICH"
#   - INTEL:
#       INTEL_MPI=0, PARALLEL_VERSION=0 -> "$INSTALLATION_PATH/INTEL/"
#       INTEL_MPI=0, PARALLEL_VERSION=1 -> "$INSTALLATION_PATH/INTEL/MPICH"
#       INTEL_MPI=1, PARALLEL_VERSION=0 -> "$INSTALLATION_PATH/INTEL/MPI_INTEL"
#       INTEL_MPI=1, PARALLEL_VERSION=1 -> "$INSTALLATION_PATH/INTEL/MPI_MPICH_INTEL"
#---------------------------------------------------------------------------------------------
PARALLEL_VERSION=${PARALLEL_VERSION:-0}

# -----------------------------------------------------------------------------
# INTEL MPI MODE (COMPILER=INTEL, PARALLEL_VERSION=1, INTEL_MPI=1)
# -----------------------------------------------------------------------------
# Summary
#   When building in parallel with Intel MPI, ALL third-party libraries and models
#   are compiled with Intel MPI wrapper compilers:
#       CC  -> mpiicc      (C with Intel MPI)
#       CXX -> mpiicpc     (C++ with Intel MPI)
#       FC  -> mpiifort    (Fortran with Intel MPI; uses ifx when available)
#   The script’s mpi_setup() exports MPICC/MPICXX/MPIFC accordingly.


# Environment prerequisites
#   - Load oneAPI environment before running this script:
#         source /opt/intel/oneapi/setvars.sh
#     This sets I_MPI_ROOT and adds Intel MPI tools to PATH.
#   - Ensure PATH and LD_LIBRARY_PATH include Intel MPI dirs:
#         PATH="$I_MPI_ROOT/bin:$PATH"
#         LD_LIBRARY_PATH="$I_MPI_ROOT/lib:$LD_LIBRARY_PATH"
#
# Directory layout (derived automatically by the script)
#   INSTALL_DIR="$INSTALLATION_PATH/INTEL/MPI_MPICH_INTEL"
#   LIBS_DIR="$INSTALL_DIR/"
#   MPI_DIR="$LIBS_DIR/"
#   (Name reflects “parallel + Intel MPI” per project convention.)
#
# Build switches
#   - Set PARALLEL_VERSION=1 and INTEL_MPI=1.
#   - Skip MPICH build step (OPTIONS[3]=0) — Intel MPI replaces it.
#
# Autotools/CMake tips
#   - Autotools packages: just rely on the wrappers; do NOT hardcode -lmpi.
#       env CC=mpiicc CXX=mpiicpc FC=mpiifort ./configure ...
#   - CMake packages: you can hint the MPI compilers explicitly if needed:
#       -DMPI_C_COMPILER=mpiicc -DMPI_CXX_COMPILER=mpiicpc -DMPI_Fortran_COMPILER=mpiifort
#   - Do NOT mix MPI stacks (e.g., MPICH headers/libs) with Intel MPI in the same build.
#
# Verification
#   - which mpiifort ; mpiifort --version
#   - which mpirun   ; mpirun  --version
#   - At runtime: mpirun -np <N> ./your_program
#
# Known pitfalls / notes
#   - Do not override CC/CXX/FC with base compilers when PARALLEL_VERSION=1; wrappers must be used.
#   - Avoid leaking other MPI implementations into PATH ahead of $I_MPI_ROOT/bin.
#   - For Fortran logical interop warnings when building HDF5 Fortran with ifx, add:
#         FCFLAGS="... -fpscomp logicals"
#   - You generally don’t need to add -lmpi manually; wrappers handle link lines.
# -----------------------------------------------------------------------------

INTEL_MPI=${INTEL_MPI:-0}

#-----------------------------------------------------------------------------
#
#   Library versions   
#
#
# ----------------------------------------------------------------------------
#


export HDF5_Version="1_14_2"
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


#----------------------------------------------------------------------------------------
#
#                     CPU RESOURCE MANAGEMENT
#
#----------------------------------------------------------------------------------------
#
#
# Set to true if you want to force the use of all available CPU cores
USE_ALL_CORES=false
#
#
# Detect total number of CPU cores available on the system
CPU_CORE=$(nproc)
echo "TOTAL AVAILABLE CPU CORES: $CPU_CORE"
#
#
# Threshold to define a low-core system (adjustable)
CPU_CORE_LIMIT=8

#
#
# Check if the user wants to use all cores
if [ "$USE_ALL_CORES" = true ]; then
  CPU_HALF_EVEN=$CPU_CORE
  echo "USING ALL AVAILABLE CORES AS CONFIGURED"
else
  # Calculate half the cores and ensure it's an even number
  CPU_HALF=$((CPU_CORE / 2))
  CPU_HALF_EVEN=$((CPU_HALF - (CPU_HALF % 2)))

  # If system has few cores (≤ 12), force only 2 cores to be used
  if [ $CPU_CORE -le $CPU_CORE_LIMIT ]; then
    CPU_HALF_EVEN=2
    echo "LOW-CORE SYSTEM DETECTED – FORCING USAGE OF 2 CORES ONLY"
  fi
fi
#
#
# Export the final value to be used in parallel commands (e.g., make -j$CPU_HALF_EVEN)
#
export CPU_HALF_EVEN
echo "CORES TO BE USED BY THE SCRIPT: $CPU_HALF_EVEN"


#-----------------------------------------------------------------------------
#
#
#   Test block to check if Python version is greater than or equal to 3
#
#
#-------------------------------------------------------------------------------
#
#
#
PYTHON_CMD=$(command -v python3 || command -v python)

if [ -z "$PYTHON_CMD" ]; then
    echo "Nenhuma versão do Python encontrada."
    exit 1
fi

PYTHON_VERSION=$("$PYTHON_CMD" -c 'import sys; print(sys.version_info[0])')

if [ "$PYTHON_VERSION" -ge 3 ]; then
    echo "$PYTHON_CMD é Python 3 ou superior."
else
    echo "$PYTHON_CMD é inferior à versão 3."
    exit 1
fi




# --------------------------------------------------------------------
# Layout de diretórios por COMPILER / PARALLEL_VERSION / INTEL_MPI
# --------------------------------------------------------------------
: "${PARALLEL_VERSION:=0}"   # 0=serial, 1=parallel (MPI)
: "${INTEL_MPI:=0}"          # só vale quando COMPILER=INTEL (0=MPICH, 1=Intel MPI)

if [ "$COMPILER" = "INTEL" ]; then
    if [ "$PARALLEL_VERSION" = "1" ]; then
        if [ "$INTEL_MPI" = "1" ]; then
            export INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/MPI_MPICH_INTEL"
            export I_MPI_F90=ifx 
            export I_MPI_CC=icx 
        else
            export INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/MPICH"
        fi
    else
        if [ "$INTEL_MPI" = "1" ]; then
            export INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/MPI_INTEL"
            export I_MPI_F90 =ifx 
            export I_MPI_CC=icx 
        else
            export INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/"
        fi
    fi
else
    # GNU e NVIDIA
    if [ "$PARALLEL_VERSION" = "1" ]; then
        export INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/MPICH"
    else
        export INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/"
    fi
fi

export LIBS_DIR="$INSTALL_DIR/"
export MPI_DIR="$LIBS_DIR/"

echo ">>> COMPILER=$COMPILER  PARALLEL_VERSION=$PARALLEL_VERSION  INTEL_MPI=$INTEL_MPI"
echo ">>> INSTALL_DIR=$INSTALL_DIR"
echo ">>> LIBS_DIR=$LIBS_DIR"
echo ">>> MPI_DIR=$MPI_DIR"



# --------------------------------------------------------------------
# MPI: selecionar wrappers
# - INTEL + INTEL_MPI=1        -> Intel MPI (mpiifort/mpiicc)
# - INTEL + INTEL_MPI=0 (padrão)-> MPICH; se existir em $LIBS_DIR/bin, usa esse
# - GNU/NVIDIA                  -> MPICH ($LIBS_DIR/bin se existir, senão PATH)
# OBS: Esta função é pensada para compilar MODELOS (dmpar), mesmo que as libs sejam seriais.
# --------------------------------------------------------------------
mpi_setup() {
  export MPI_FLAVOR="none"

  if [ "$COMPILER" = "INTEL" ] && [ "${INTEL_MPI:-0}" = "1" ]; then
    # ---- Intel MPI ----
    if [ -z "${I_MPI_ROOT:-}" ] && ! command -v mpiifort >/dev/null 2>&1; then
      echo "ERROR: Intel MPI não encontrado (rode 'source /opt/intel/oneapi/setvars.sh')."
      return 1
    fi
    export MPIFC="$(command -v mpiifort)"
    export MPICC="$(command -v mpiicc)"
    export MPICXX="$(command -v mpiicpc)"
    export MPIF77="$MPIFC" ; export MPIF90="$MPIFC"
    export MPI_FLAVOR="intelmpi"
  else
    # ---- MPICH (preferir o que você instalou no LIBS_DIR) ----
    if [ -x "$LIBS_DIR/bin/mpifort" ] && [ -x "$LIBS_DIR/bin/mpicc" ]; then
      case ":$PATH:" in *":$LIBS_DIR/bin:"*) : ;; *) export PATH="$LIBS_DIR/bin:$PATH";; esac
      if [ -d "$LIBS_DIR/lib" ]; then
        case ":$LD_LIBRARY_PATH:" in *":$LIBS_DIR/lib:"*) : ;; *) export LD_LIBRARY_PATH="$LIBS_DIR/lib:$LD_LIBRARY_PATH";; esac
      fi
      export MPIFC="$LIBS_DIR/bin/mpifort"
      export MPICC="$LIBS_DIR/bin/mpicc"
      export MPICXX="$LIBS_DIR/bin/mpicxx"
      export MPIF77="$MPIFC" ; export MPIF90="$MPIFC"
      export MPI_FLAVOR="mpich(from-LIBS_DIR)"
    else
      # Fallback: MPICH do sistema/ambiente
      export MPIFC="$(command -v mpifort || command -v mpif90 || true)"
      export MPICC="$(command -v mpicc   || true)"
      export MPICXX="$(command -v mpicxx || true)"
      export MPIF77="$MPIFC" ; export MPIF90="$MPIFC"
      export MPI_FLAVOR="mpich(PATH)"
    fi
  fi

  # Sanidade:
  if [ -z "$MPIFC" ] || [ -z "$MPICC" ] || [ -z "$MPICXX" ]; then
    echo "ERROR: wrappers MPI indisponíveis (MPIFC='$MPIFC' MPICC='$MPICC' MPICXX='$MPICXX')."
    return 1
  fi

  echo ">>> MPI_FLAVOR=$MPI_FLAVOR"
  echo ">>> MPIFC=$MPIFC"
  echo ">>> MPICC=$MPICC"
  echo ">>> MPICXX=$MPICXX"
}



#============================================
# UNIVERSAL FUNCTION TO SELECT COMPILERS
#============================================

define_compilers() {
  if [ "$PARALLEL_VERSION" = "1" ]; then
    mpi_setup
    export COMPILERS="CC=$MPICC FC=$MPIFC CXX=$MPICXX F90=$MPIF90 F77=$MPIF77"
    echo ">>> Modo paralelo: usando wrappers MPI"
  else
    # Serial: usa os compiladores base já definidos (GNU/INTEL/NVIDIA)
    export COMPILERS="CC=$CC FC=$FC CXX=$CXX F90=$F90 F77=$F77"
    echo ">>> Modo serial: usando compiladores base ($COMPILER)"
  fi
}

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






#------------------------------------------------------------------------------
#
# Compiler configuration based on the COMPILER variable
#
#



if [ "$COMPILER" == "GNU" ]; then
    export CC=gcc
    export CXX=g++
    export FC=gfortran
    export F90=$FC
    export F77=$FC

    export CFLAGS="-O3 -fPIC -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-error=incompatible-pointer-types"
    export CXXFLAGS="-O3 -fPIC"
    export FFLAGS="-O3 -fPIC"
    export FCFLAGS="-O3 -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -fPIC -fno-second-underscore -ffree-form   -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types"
    export LDFLAGS="-fPIC"


elif [ "$COMPILER" == "INTEL" ]; then
    # Detecta se é Intel clássico (ifort) ou Intel OneAPI (ifx)
    if command -v ifx &>/dev/null; then
        export CC=icx
        export CXX=icpx
        export FC=ifx
    else
        export CC=icc
        export CXX=icpc
        export FC=ifort
    fi

    export CFLAGS="-O2 -fPIC "

    export CXXFLAGS="-O2 -fPIC"
    export CXXFLAGS="-O2 -fPIC"
    export FFLAGS="-O2 -fPIC"
    export FCFLAGS="-O2 -fPIC -free"
    export LDFLAGS="-fPIC"

elif [ "$COMPILER" == "NVIDIA" ]; then
    export CC=nvc
    export CXX=nvc++
    export FC=nvfortran

    export CFLAGS="-O2 -fPIC"
    export CXXFLAGS="-O2 -fPIC"
    export FFLAGS="-O2 -fPIC"
    export FCFLAGS="-O2 -fPIC -Mfreeform"
    export LDFLAGS="-fPIC"

else
    echo "ERRO: Valor inválido para COMPILER. Use: GNU, INTEL ou NVIDIA."
    exit 1
fi







#-------------------------------------------------------------------------------------
#
# Step [0] - Update system and install required development packages
#
# This step prepares the system by installing compilers, development tools,
# libraries and utilities required to build all dependencies and run the WRF model.
#
# The Linux distribution is detected automatically using /etc/os-release.
# Supported distributions:
#   - REDHAT-based (Rocky, AlmaLinux, CentOS, Fedora)
#   - UBUNTU
#   - DEBIAN
#

# Detect system distribution
if [ -f /etc/os-release ]; then
    DISTRO_ID=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
else
    echo "ERROR: Cannot determine Linux distribution. '/etc/os-release' not found."
    exit 1
fi

if [ "${OPTIONS[0]}" -eq 1 ]; then
    echo ">>> [0] Detected system: $DISTRO_ID"
    echo ">>> Updating system and installing required packages..."

    #
    # --------------------------
    # Red Hat-based systems
    # --------------------------
    #
    if [[ "$DISTRO_ID" == "rhel" || "$DISTRO_ID" == "rocky" || "$DISTRO_ID" == "fedora" || "$DISTRO_ID" == "centos" ]]; then
        sudo dnf update -y
        sudo dnf upgrade -y

        # Compilers and core development tools
        sudo dnf install -y gcc gcc-gfortran gcc-c++ libtool \
                            automake autoconf make m4 cmake patch curl tar unzip wget

        # Java (some tools like Jasper or viewers may require it)
        sudo dnf install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel

        # Shells and useful utilities
        sudo dnf install -y csh ksh tcsh time git bash-completion wget git

        # Core libraries for building dependencies
        sudo dnf install -y zlib zlib-devel libpng libpng-devel jasper jasper-devel \
                            hdf5 hdf5-devel netcdf netcdf-fortran

        # Visualization tools and required X11 components
        sudo dnf install -y ncview ncl \
                            libX11-devel libXaw-devel libXmu-devel libXt-devel

        # Full development environment (equivalent to build-essential)
        sudo dnf groupinstall -y "Development Tools"

    #
    # --------------------------
    # Ubuntu systems
    # --------------------------
    #
    elif [[ "$DISTRO_ID" == "ubuntu" ]]; then
        sudo apt update -y
        sudo apt upgrade -y

        # Compilers and core development tools
        sudo apt install -y build-essential gfortran g++ libtool \
                            automake autoconf make m4 cmake patch curl tar unzip wget

        # Java
        sudo apt install -y openjdk-8-jdk

        # Shells and utilities
        sudo apt install -y csh ksh tcsh time git bash-completion wget git 

        # Libraries
        sudo apt install -y zlib1g-dev libpng-dev libjasper-dev \
                            libhdf5-serial-dev libnetcdf-dev libnetcdff-dev

        # Visualization and X11 support
        sudo apt install -y ncview ncl-ncarg \
                            libx11-dev libxaw7-dev libxmu-dev libxt-dev

    #
    # --------------------------
    # Debian systems
    # --------------------------
    #
    elif [[ "$DISTRO_ID" == "debian" ]]; then
        sudo apt update -y
        sudo apt upgrade -y

        # Compilers and core development tools
        sudo apt install -y build-essential gfortran g++ libtool \
                            automake autoconf make m4 cmake patch curl tar unzip wget

        # Java
        sudo apt install -y default-jdk

        # Shells and utilities
        sudo apt install -y csh ksh tcsh time git bash-completion wget git 

        # Libraries
        sudo apt install -y zlib1g-dev libpng-dev libjasper-dev \
                            libhdf5-dev libnetcdf-dev libnetcdff-dev

        # Visualization and X11 support
        sudo apt install -y ncview ncl-ncarg \
                            libx11-dev libxaw7-dev libxmu-dev libxt-dev

    #
    # --------------------------
    # Unsupported or unknown
    # --------------------------
    #
    else
        echo "ERROR: Unsupported or unknown Linux distribution: '$DISTRO_ID'"
        exit 1
    fi

    #
    # Pause if PROMPTOK is enabled
    #
    if [ "$PROMPTOK" -eq 1 ]; then
        read -p "System update complete. Press ENTER to continue..."
    fi
fi






#-----------------------------------------------------------------------------
#
# Step [1] - Create working directories
#
if [ "${OPTIONS[1]}" -eq 1 ]; then
    echo ">>> [1] Creating working directories..."

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$LIBS_DIR"
    mkdir -p "$GEOG"
    mkdir -p "$DOWNLOADS"
	mkdir -p "$MPI_DIR"
    
    if [ "$PROMPTOK" -eq 1 ]; then read -p "Press ENTER to continue..."; fi
fi



#--------------------------------------------------------------------------------
#
# Step [2] - Download all libraries in a single session
#



if [ "${OPTIONS[2]}" -eq 1 ]; then

    echo ">>> [2] Downloading all required libraries..."
    
    # Go to the download directory
    cd "$DOWNLOADS"

    #
    # ZLIB
    #
    wget -nc https://www.zlib.net/zlib-$Zlib_Version.tar.gz

    #
    # MPICH
    #
    wget -nc https://www.mpich.org/static/downloads/$Mpich_Version/mpich-$Mpich_Version.tar.gz

    #
    # LIBPNG
    #
    wget -nc https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz

    #
    # JASPER
    #
    wget -nc https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip

    #
    # HDF5
    #
    wget -nc https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-$HDF5_Version.tar.gz
    # Example: https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-1_14_2.tar.gz

    #
    # NETCDF-C
    #
    wget -nc https://downloads.unidata.ucar.edu/netcdf-c/$Netcdf_C_Version/netcdf-c-$Netcdf_C_Version.tar.gz

    #
    # NETCDF-FORTRAN
    #
    wget -nc https://downloads.unidata.ucar.edu/netcdf-fortran/$Netcdf_Fortran_Version/netcdf-fortran-$Netcdf_Fortran_Version.tar.gz

    #
    # PARALLEL NETCDF
    #
    echo "------------------------------"
    wget -nc https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz
    echo "------------------------------"

    #
    # PIO (optional, for coupled models)
    #
    #wget -nc https://github.com/NCAR/ParallelIO/archive/refs/tags/pio$Pio_Version.tar.gz
    #wget -nc https://github.com/NCAR/ParallelIO/archive/refs/tags/pio2_5_9.tar.gz
    wget -nc https://github.com/NCAR/ParallelIO/archive/refs/tags/pio$Pio_Version.tar.gz

    #
    # JPEG 
    #
   	wget -nc https://github.com/uclouvain/openjpeg/archive/refs/tags/v$jpeg_version.tar.gz


    echo " Problens of Downlaod ? https://confluence.ecmwf.int/display/ECC/Releases"
    wget -nc  https://confluence.ecmwf.int/download/attachments/45757960/eccodes-$ecc_version-Source.tar.gz

  # Pause after downloads if PROMPTOK is enabled
    if [ "$PROMPTOK" -eq 1 ]; then
        read -p "Downloads complete. Press ENTER to continue..."
    fi
fi





# --------------------------------------------------------------------
# Toolchain sanity + version-specific workarounds (GNU / INTEL / NVIDIA)
# --------------------------------------------------------------------
case "$COMPILER" in
  GNU)
    # Verifica presença
    for t in gcc g++ gfortran; do
      command -v "$t" >/dev/null || { echo "ERROR: $t not found. Instale com o gerenciador da sua distro."; exit 1; }
    done
    # Versões
    GCC_VERSION=$(gcc -dumpfullversion 2>/dev/null)
    GXX_VERSION=$(g++ -dumpfullversion 2>/dev/null)
    GFORTRAN_VERSION=$(gfortran -dumpfullversion 2>/dev/null)
    [[ -n "$GCC_VERSION" && -n "$GXX_VERSION" && -n "$GFORTRAN_VERSION" ]] || { echo "ERROR: Não foi possível detectar versões GNU."; exit 1; }
    GCC_MAJOR=${GCC_VERSION%%.*}
    GXX_MAJOR=${GXX_VERSION%%.*}
    GFORTRAN_MAJOR=${GFORTRAN_VERSION%%.*}
    # Workarounds só para GNU ≥ 10
    if [ "$GCC_MAJOR" -ge 10 ] || [ "$GXX_MAJOR" -ge 10 ] || [ "$GFORTRAN_MAJOR" -ge 10 ]; then
      export fallow_argument="-fallow-argument-mismatch"
      export boz_argument="-fallow-invalid-boz"
      echo ">>> GNU toolchain ≥ 10 – habilitando flags de compatibilidade do gfortran."
    else
      export fallow_argument=""
      export boz_argument=""
      echo ">>> GNU toolchain < 10 – sem flags de compatibilidade."
    fi
    ;;

  INTEL)
    # oneAPI (icx/ifx) preferido; senão clássico (icc/ifort)
    if command -v icx >/dev/null 2>&1 && command -v ifx >/dev/null 2>&1; then
      ICX_VER=$(icx --version 2>&1 | sed -n 's/.* \([0-9][0-9.]*\).*/\1/p' | head -n1)
      IFX_VER=$(ifx --version 2>&1 | sed -n 's/.* \([0-9][0-9.]*\).*/\1/p' | head -n1)
      echo ">>> Intel oneAPI detectado: icx $ICX_VER / ifx $IFX_VER"
    elif command -v icc >/dev/null 2>&1 && command -v ifort >/dev/null 2>&1; then
      ICC_VER=$(icc -V 2>&1 | sed -n 's/.*Version \([0-9][0-9.]*\).*/\1/p' | head -n1)
      IFORT_VER=$(ifort -V 2>&1 | sed -n 's/.*Version \([0-9][0-9.]*\).*/\1/p' | head -n1)
      echo ">>> Intel classic detectado: icc $ICC_VER / ifort $IFORT_VER"
    else
      echo "ERROR: Toolchain Intel não encontrado (icx/ifx ou icc/ifort). Já executou 'source /opt/intel/oneapi/setvars.sh'?"
      exit 1
    fi
    # Workarounds do GNU não se aplicam
    export fallow_argument=""
    export boz_argument=""
    ;;

  NVIDIA)
    for t in nvc nvc++ nvfortran; do
      command -v "$t" >/dev/null || { echo "ERROR: $t not found. Instale o NVIDIA HPC SDK."; exit 1; }
    done
    NVF_VER=$(nvfortran --version 2>&1 | sed -n 's/.* \([0-9][0-9.]*\).*/\1/p' | head -n1)
    echo ">>> NVIDIA HPC SDK detectado: nvfortran $NVF_VER"
    # Workarounds do GNU não se aplicam
    export fallow_argument=""
    export boz_argument=""
    ;;

  *)
    echo "ERROR: COMPILER='$COMPILER' não suportado nesta checagem."
    exit 1
    ;;
esac

[ "$PROMPTOK" -eq 1 ] && read -p ">>> Verificação do toolchain ($COMPILER) concluída. Pressione ENTER para continuar..."


# --- Utilitários para evitar "vazamento" das libs Intel em binários do sistema ---
# Executa um comando com PATH mínimo e sem LD_PRELOAD/LD_LIBRARY_PATH
run_clean() {
  env -i \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    HOME="$HOME" \
    TERM="${TERM:-xterm}" \
    LC_ALL=C \
    "$@"
}

# Versões “limpas” para tar e ls
tar_clean() { run_clean tar "$@"; }
ls_clean()  { run_clean ls  "$@"; }

# (Diagnóstico rápido, opcional)
echo "INFO: LD_PRELOAD='${LD_PRELOAD:-<vazio>}'"
echo "INFO: LD_LIBRARY_PATH começa com: $(echo "${LD_LIBRARY_PATH:-<vazio>}" | cut -d: -f1)"




#-----------------------------------------------------------------------------------
#
#  MPICH Compilation and Installation
#
#  10/03/2025 - GNU OK
#  25/04/2025 - INTEL OK 
#   
#  TODO: 
#  NVIDIA  
#-----------------------------------------------------------------------------------
if [ "${OPTIONS[3]}" -eq 1 ] && [ "$INTEL_MPI" -eq 0 ]; then
    echo ">>> [3] Starting MPICH installation..."

    cd "$DOWNLOADS" || { echo "ERROR: Cannot access download directory $DOWNLOADS"; exit 1; }

    # Remove any previous source directory
    rm -rf "mpich-$Mpich_Version/"

    # Extract the source tarball
    tar_clean -xvzf "mpich-$Mpich_Version.tar.gz"
    cd "mpich-$Mpich_Version/" || { echo "ERROR: Cannot enter MPICH source directory"; exit 1; }

    # Configure MPICH
    #
    # Only if LIBS_DIR different MPI_DIR para PARALLEL_VERSION=1
    #

	  if [ "$LIBS_DIR" != "$MPI_DIR" ]; then
		./configure --prefix="$MPI_DIR" --with-device=ch3  FFLAGS=$fallow_argument FCFLAGS=$fallow_argument
    else 
		./configure --prefix="$LIBS_DIR" --with-device=ch3 FFLAGS=$fallow_argument FCFLAGS=$fallow_argument
    fi

    # Compile, install and check
    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install
    make -j "$CPU_HALF_EVEN" check

    # List installed binaries
    echo ""
    echo ">>> MPICH installed in: $MPI_BIN/bin"
    ls_clean -ltr $MPI_DIR/bin
    ls_clean -ltr $MPI_DIR/lib 
    

    # Prompt to continue if enabled
    if [ "$PROMPTOK" -eq 1 ]; then
        read -p ">>> MPICH installation complete. Press enter to continue..."
    fi
fi


# ===============================
#        ZLIB Installation
#
#  10/03/2025 - GNU OK
#  25/04/2025 - INTEL OK 
#  
# TODO:
# NVIDIA 
# ===============================
if [ "${OPTIONS[4]}" -eq 1 ]; then
    define_compilers
    echo "$COMPILERS"

    cd "$DOWNLOADS" || { echo "ERRO: sem acesso a $DOWNLOADS"; exit 1; }

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

    # Compilação (usa seu ambiente atual, inclusive Intel)
    # Sugestão: force icx quando INTEL:
    if [ "$COMPILER" = "INTEL" ] && command -v icx >/dev/null 2>&1; then
        export CC=icx
    fi

    FFLAGS=$fallow_argument
    FCFLAGS=$fallow_argument

    eval "$COMPILERS FCFLAGS=\"$FCFLAGS\" CFLAGS=\"$CFLAGS\" ./configure --prefix=\"$LIBS_DIR\""
    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    echo -e "\n>> ZLIB installed in $LIBS_DIR/lib"
    ls_clean -ltr "$LIBS_DIR/lib"
    [ "$PROMPTOK" -eq 1 ] && read -p "ZLIB installed. Press enter to continue..."
fi




# ===============================
#        LIBPNG Installation
#  10/03/2025 - GNU OK
#  25/04/2025 - INTEL OK 
#  
# TODO:
# NVIDIA 
# ===============================
if [ "${OPTIONS[5]}" -eq 1 ]; then
    define_compilers
    cd "$DOWNLOADS"
    rm -rf "libpng-$Libpng_Version/"
    tar_clean -xvzf "libpng-$Libpng_Version.tar.gz"
    cd "libpng-$Libpng_Version/"

    autoreconf -i -f
    eval "$COMPILERS FCFLAGS=\"$FCFLAGS\" CFLAGS=\"$CFLAGS\" ./configure --prefix=\"$LIBS_DIR/\""
    automake -a -f
    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    echo -e "\n>> LIBPNG installed in $LIBS_DIR/lib"
    ls_clean -ltr "$LIBS_DIR/lib"
    [ "$PROMPTOK" -eq 1 ] && read -p "LIBPNG installed. Press enter to continue..."
fi


# ===============================
#        JASPER Installation
#  10/03/2025 - GNU OK
#  25/04/2025 - INTEL OK 
#  
# TODO:
# NVIDIA 
#
# ===============================
if [ "${OPTIONS[6]}" -eq 1 ]; then
    define_compilers
    cd "$DOWNLOADS" || { echo "ERRO: sem acesso a $DOWNLOADS"; exit 1; }

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

    # -------- Flags apenas para ESTE pacote (não poluem o resto) --------
    if [ "$COMPILER" = "INTEL" ]; then
        # icx: tolera código legado e suprime warnings desconhecidos
        JAS_CFLAGS="-O3 -fPIC -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-error=incompatible-pointer-types -Wno-unknown-warning-option"
    else
        # GNU
        JAS_CFLAGS="-O3 -fPIC -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-error=incompatible-pointer-types"
    fi
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

    echo -e "\n>> JASPER instalado em $LIBS_DIR/lib"
    if command -v ls_clean >/dev/null 2>&1; then ls_clean -ltr "$LIBS_DIR/lib"; else ls -ltr "$LIBS_DIR/lib"; fi
    [ "$PROMPTOK" -eq 1 ] && read -p "JASPER instalado. Pressione ENTER para continuar..."
fi



# ===================================================================================================
#       HDF5 Installation
#       (C + Fortran, serial)
#  10/03/2025 - GNU OK
#  25/04/2025 - INTEL OK 
#  
# TODO:
# It works with INTEL or GNU. Tem que implementar para o NVIDIA.
# NVIDIA  
# ===================================================================================================

if [ "${OPTIONS[7]}" -eq 1 ]; then
    define_compilers

    cd "$DOWNLOADS" || { echo "ERRO: sem acesso a $DOWNLOADS"; exit 1; }

    # Escolhe tar/ls "limpos" se você já criou essas funções; senão usa padrão
    if command -v tar_clean >/dev/null 2>&1; then TARCMD=tar_clean; else TARCMD=tar; fi
    if command -v ls_clean  >/dev/null 2>&1; then LSCMD=ls_clean;  else LSCMD=ls;  fi

    SRCARC="hdf5-$HDF5_Version.tar.gz"
    SRCDIR="hdf5-hdf5-$HDF5_Version"

    rm -rf "$SRCDIR"
    $TARCMD -xzf "$SRCARC" || { echo "ERRO: falha ao extrair $SRCARC"; exit 1; }
    cd "$SRCDIR" || { echo "ERRO: diretório-fonte $SRCDIR não encontrado"; exit 1; }

    # Evita conflito de módulos antigos gerados por outro compilador
    rm -f "$LIBS_DIR/include"/H5*.mod "$LIBS_DIR/include"/h5*.mod 2>/dev/null || true

    # FLAGS específicas por compilador
    if [ "$COMPILER" = "INTEL" ]; then
        H5_CFLAGS="-O2 -fPIC -Wno-unknown-warning-option"
        H5_FCFLAGS="-O2 -fPIC -free -fpscomp logicals"
        # Remover flags do ICC clássico que o ICX não aceita
        CFLAGS="$H5_CFLAGS ${CFLAGS//-Wp64/}"
        CXXFLAGS="$H5_CFLAGS ${CXXFLAGS//-Wp64/}"
        # (opcional) alguns ambientes colocam -Wl,-s; se te incomodar:
        LDFLAGS="${LDFLAGS//-Wl,-s/}"
    else
        H5_CFLAGS="-O3 -fPIC"
        H5_FCFLAGS="-O3 -fPIC -ffree-form"
        # Remover flags do ICC clássico que o ICX não aceita

    fi

    autoreconf -i -f

    # ==========================
    # FORÇA WRAPPERS MPI SE PARALLEL_VERSION=1 (mantendo seu padrão)
    # ==========================
    if [ "${PARALLEL_VERSION:-0}" -eq 1 ]; then
        # Se LD_LIBRARY_PATH começar com .../MPICH/lib (ou similar), injeta .../bin no PATH
        if [ -n "${LD_LIBRARY_PATH:-}" ]; then
            _first_lib="${LD_LIBRARY_PATH%%:*}"
            case "$_first_lib" in
                */MPICH/lib|*/mpich/lib|*/openmpi/lib|*/intelmpi/lib)
                    _mpi_root="${_first_lib%/lib}"
                    [ -d "$_mpi_root/bin" ] && export PATH="$_mpi_root/bin:$PATH"
                    ;;
            esac
        fi
        # Preferência: Intel MPI (mpiicx/mpiifx); senão MPICH/OpenMPI (mpicc/mpif90)
        if command -v mpiicx >/dev/null 2>&1 && command -v mpiifx >/dev/null 2>&1; then
            COMPILERS="CC=mpiicx CXX=mpiicpc FC=mpiifx F77=mpiifort"
        elif command -v mpicc >/dev/null 2>&1 && command -v mpif90 >/dev/null 2>&1; then
            COMPILERS="CC=mpicc CXX=mpicxx FC=mpif90 F77=mpif77"
        else
            echo "ERRO: wrappers MPI não encontrados (mpiicx/mpiifx OU mpicc/mpif90)."; exit 1;
        fi
    fi

    echo ">>> COMPILERS: $COMPILERS"

    # IMPORTANTE: zera CPPFLAGS/LDFLAGS para não “puxar” includes/libs globais aqui
    # (evita misturar .mod antigos)
    eval "$COMPILERS \
         CPPFLAGS='' LDFLAGS='$LDFLAGS' \
           CFLAGS='$H5_CFLAGS' FCFLAGS='$H5_FCFLAGS' \
         ./configure --prefix='$LIBS_DIR' \
                     --with-zlib='$LIBS_DIR' \
                     --enable-hl \
                     --disable-tests \
                     --enable-fortran \
                     --$( [ "${PARALLEL_VERSION:-0}" -eq 1 ] && echo enable || echo disable )-parallel \
                     --disable-shared" \
    || { echo "ERRO: configure do HDF5"; exit 1; }

    make -j "$CPU_HALF_EVEN" || { echo "ERRO: make HDF5"; exit 1; }
    make -j "$CPU_HALF_EVEN" install || { echo "ERRO: make install HDF5"; exit 1; }

    echo -e "\n>> HDF5 instalado em $LIBS_DIR/lib"
    $LSCMD -ltr "$LIBS_DIR/lib"

    [ "$PROMPTOK" -eq 1 ] && read -p "HDF5 instalado. Pressione ENTER para continuar..."
fi





# ===================================================================================================================
# PNETCDF Installation — SOMENTE PARALELO
# Requer Intel oneAPI carregado (setvars.sh) quando COMPILERS=INTEL
# ===================================================================================================================
if [ "${OPTIONS[8]}" -eq 1 ]; then
    echo ">>> PNETCDF: preparando compilação paralela"

    # --- Ambiente Intel (se aplicável) ---
    if [ "${COMPILERS:-INTEL}" = "INTEL" ]; then
        # Garante bibliotecas/paths do oneAPI
        if [ -f /opt/intel/oneapi/setvars.sh ]; then
            # evita recarregar n vezes
            if ! env | grep -q 'ONEAPI_ROOT='; then
                # shellcheck disable=SC1091
                source /opt/intel/oneapi/setvars.sh
            fi
        fi
        # Amarra wrappers ao icx/ifx
        export I_MPI_CC=${I_MPI_CC:-icx}
        export I_MPI_FC=${I_MPI_FC:-ifx}
    fi

    if mpi_setup; then
        echo ">>> PNETCDF: usando wrappers MPI: MPICC=$MPICC  MPIFC=$MPIFC"
    else
        echo ">>> PNETCDF: SKIP — wrappers MPI não disponíveis (verifique $LIBS_DIR/bin)."
        [ "$PROMPTOK" -eq 1 ] && read -p "PNETCDF skipped. Press ENTER to continue..."
        :
    fi

    if [ -n "$MPICC" ] && [ -n "$MPIFC" ]; then
        cd "$DOWNLOADS" || { echo "AVISO: sem acesso a $DOWNLOADS — pulando PnetCDF."; }

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

            # --- FLAGS SEGURAS POR COMPILADOR ---
            local_CFLAGS="-O2 -fPIC"
            local_FCFLAGS="-O2 -fPIC"

            # Zera flags GNU quando for Intel (evita -fallow-argument-mismatch, etc.)
            if [ "${COMPILERS:-INTEL}" = "INTEL" ]; then
                # não herdar variáveis globais de GNU
                unset fallow_argument boz_argument
            else
                [ -n "$fallow_argument" ] && local_FCFLAGS="$local_FCFLAGS $fallow_argument"
                [ -n "$boz_argument" ]   && local_FCFLAGS="$local_FCFLAGS $boz_argument"
            fi

            # Para Intel MPI, o caminho ajuda o configure a achar includes/libs do mpi
            MPI_ROOT_GUESS="${I_MPI_ROOT:-/opt/intel/oneapi/mpi/latest}"

            # --- CONFIGURE ---
            CC="$MPICC" FC="$MPIFC" CFLAGS="$local_CFLAGS" FCFLAGS="$local_FCFLAGS" \
            ./configure \
                --prefix="$LIBS_DIR" \
                --disable-shared \
                --enable-static \
                --disable-dependency-tracking \
                ${MPI_ROOT_GUESS:+--with-mpi="$MPI_ROOT_GUESS"}

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

                echo -e "\n>> PNETCDF instalado em $LIBS_DIR/lib"
                command -v ls_clean >/dev/null 2>&1 && ls_clean -ltr "$LIBS_DIR/lib" || ls -ltr "$LIBS_DIR/lib"

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
fi




# ===============================
#       NETCDF-C Installation


# ===============================
if [ "${OPTIONS[9]}" -eq 1 ]; then
    define_compilers
    cd "$DOWNLOADS"
    rm -rf "netcdf-c-$Netcdf_C_Version"
    tar_clean -xzvf "netcdf-c-$Netcdf_C_Version.tar.gz"
    cd "netcdf-c-$Netcdf_C_Version"

    autoreconf -i -f 
    
    # NetCDF-C configure (estático), com e sem PnetCDF
    if [ "${PARALLEL_VERSION:-0}" -eq 1 ]; then
        CC=mpicc 
        CXX=mpicxx 
        FC=mpif90
        echo ">>> NETCDF-C (PARALLELO + PNETCDF)"
        eval "$COMPILERS" \
            CPPFLAGS="-I$LIBS_DIR/include" \
            LDFLAGS="-L$LIBS_DIR/lib" \
            ./configure --prefix="$NETCDF" \
                --disable-dap --disable-byterange --disable-libxml2 \
                --enable-netcdf-4 --enable-cdf5 --disable-shared \
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

    echo -e "\n>> NETCDF-C installed in $LIBS_DIR/lib"
    ls_clean -ltr "$LIBS_DIR/lib"
    [ "$PROMPTOK" -eq 1 ] && read -p "NETCDF-C installed. Press enter to continue..."
fi

# ===============================
#   NETCDF-FORTRAN Installation
#  10/03/2025 - GNU OK
#  25/04/2025 - INTEL OK 
#  
# TODO:
# NVIDIA  
# ===============================
# ===============================
#   NETCDF-FORTRAN Installation
# ===============================
if [ "${OPTIONS[10]}" -eq 1 ]; then
    define_compilers
    cd "$DOWNLOADS"
    rm -rf "netcdf-fortran-$Netcdf_Fortran_Version"
    tar_clean -xvzf "netcdf-fortran-$Netcdf_Fortran_Version.tar.gz"
    cd "netcdf-fortran-$Netcdf_Fortran_Version"

    # Garante que o nc-config do NetCDF-C está acessível
    NC_CONFIG="$NETCDF/bin/nc-config"
    if [ ! -x "$NC_CONFIG" ]; then
        echo "ERRO: não encontrei $NC_CONFIG (NetCDF-C não instalado em $NETCDF?)."
        exit 1
    fi

    # Flags derivadas do NetCDF-C (ordem correta e libs completas p/ estático)
    NETCDF_CFLAGS="$($NC_CONFIG --cflags)"
    NETCDF_LIBS="$($NC_CONFIG --libs --static)"   # <- inclui -lnetcdf e dependências

    autoreconf -i -f

    # Observação:
    # - CPPFLAGS inclui includes locais + do NetCDF-C
    # - LDFLAGS só aponta diretórios; as libs (e ordem) ficam TODAS em LIBS
    eval "$COMPILERS \
        CPPFLAGS=\"-I$LIBS_DIR/include -I$NETCDF/include $NETCDF_CFLAGS\" \
        LDFLAGS=\"-L$LIBS_DIR/lib -L$NETCDF/lib\" \
        LIBS=\"$NETCDF_LIBS\" \
        ./configure --prefix=\"$NETCDF\" --disable-shared"

    automake -a -f
    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" check
    make -j "$CPU_HALF_EVEN" install

    echo -e "\n>> NETCDF-FORTRAN installed in $LIBS_DIR/lib"
    ls_clean -ltr "$LIBS_DIR/lib"
    [ "$PROMPTOK" -eq 1 ] && read -p "NETCDF-FORTRAN installed. Press enter to continue..."
fi




# ===============================
#            PIO
# ===============================
if [ "${OPTIONS[11]}" -eq 1 ]; then
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
            cd "$DOWNLOADS" || { echo "AVISO: sem acesso a $DOWNLOADS — pulando PIO."; }
            rm -rf "ParallelIO-pio$Pio_Version"
            if tar_clean -xzf "pio$Pio_Version.tar.gz"; then
                cd "ParallelIO-pio$Pio_Version" || { echo "AVISO: fonte PIO não encontrado — pulando."; }
                rm -rf build && mkdir build && cd build
# ... (tudo igual até criar o diretório build)

# ... (seu código até criar o diretório build)

# Ambiente restrito SÓ para o PIO:
(
  # ============ INTEL oneAPI safeguards ============
  if [ "${COMPILERS:-INTEL}" = "INTEL" ]; then
    # Carrega oneAPI apenas se ainda não estiver carregado
    if ! env | grep -q '^ONEAPI_ROOT=' && [ -f /opt/intel/oneapi/setvars.sh ]; then
      # shellcheck disable=SC1091
      source /opt/intel/oneapi/setvars.sh
    fi
    # Força wrappers a usarem icx/ifx (evita fallback no ifort)
    export I_MPI_CC=${I_MPI_CC:-icx}
    export I_MPI_CXX=${I_MPI_CXX:-icpx}
    export I_MPI_FC=${I_MPI_FC:-ifx}
  fi

  # Garante que MPIFC use mpiifx se estivermos no stack Intel
  if [ "${COMPILERS:-INTEL}" = "INTEL" ] && [ -n "${MPIFC:-}" ]; then
    base="$(basename "$MPIFC")"
    if [ "$base" = "mpiifort" ]; then
      MPIFC="$(dirname "$MPIFC")/mpiifx"
    fi
  fi

  # Bind explícito dos wrappers aqui dentro
  export CC="$MPICC"
  export CXX="$MPICXX"
  export FC="$MPIFC"

  # Preflight: compila um "hello" Fortran para falhar cedo se o wrapper estiver ruim
  echo "      program p; print *, 'ok'; end" > .f90test.f90
  if ! "$FC" -c .f90test.f90 -o .f90test.o >/dev/null 2>&1; then
    echo "ERRO: Wrapper Fortran ($FC) não compila teste simples. Verifique setvars.sh / I_MPI_FC=ifx."
    exit 1
  fi
  rm -f .f90test.f90 .f90test.o

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
    -DPIO_USE_MALLOC=ON \
    -DPIO_ENABLE_TIMING=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DPIO_ENABLE_PNETCDF=OFF \
    ..

  if [ $? -eq 0 ]; then
    JN="${CPU_HALF_EVEN:-1}"
    make -j "$JN" && make -j "$JN" install || echo "AVISO: 'make install' do PIO falhou."
  else
    echo "AVISO: 'cmake' do PIO falhou — limpe o cache e confira I_MPI_FC=ifx / setvars.sh."
  fi
)  # fim do subshell


            else
                echo "AVISO: falha ao extrair pio$Pio_Version.tar.gz — pulando PIO."
            fi
        fi
    fi

    [ "$PROMPTOK" -eq 1 ] && read -p "PIO step finished (built or skipped). Press ENTER to continue..."
fi




# ===============================
#        AEC Installation
#  20/09/2025 - GNU OK
#  
# TODO:
# INTEL
# NVIDIA  
# ===============================
if [ "${OPTIONS[12]}" -eq 1 ]; then
    echo ">>> AEC: preparando compilação estática para uso no ECCODES..."
    
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

    echo -e "\n>> AEC instalado estaticamente em $LIBS_DIR/lib"
    ls -ltr "$LIBS_DIR/lib" | grep aec
    [ "$PROMPTOK" -eq 1 ] && read -p "AEC build done. Press enter to continue..."
fi


# ===============================
#        OPENJPEG Installation
#  20/09/2025 - GNU OK
#  
# TODO:
# INTEL
# NVIDIA  
# ===============================
# ===============================
if [ "${OPTIONS[13]}" -eq 1 ]; then
    cd "$DOWNLOADS"
    rm -rf openjpeg-$jpeg_version
    tar -xzvf v$jpeg_version.tar.gz
    cd openjpeg-$jpeg_version/
    mkdir -p build
    cd build/

    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$LIBS_DIR \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DBUILD_SHARED_LIBS=OFF

    make -j "$CPU_HALF_EVEN"
    make -j "$CPU_HALF_EVEN" install

    echo -e "\n>> OPENJPEG (static) installed in $LIBS_DIR/lib"
    ls -ltr "$LIBS_DIR/lib"
    [ "$PROMPTOK" -eq 1 ] && read -p "OPENJPEG build done. Press enter to continue..."
fi



# ===============================
#        ECCODES (STATIC)
#  20/09/2025 - GNU OK
#  
# TODO:
# INTEL
# NVIDIA  
# ===============================
# ===============================
if [ "${OPTIONS[14]}" -eq 1 ]; then
    echo ">>> ECCODES: compilando versão ESTÁTICA..."
    
    cd "$DOWNLOADS"
    rm -rf eccodes-2.41.0-Source
    tar -xf eccodes-2.41.0-Source.tar.gz
    cd eccodes-2.41.0-Source
    mkdir -p build
    cd build

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
    make install

    echo -e "\n>> ECCODES instalado estaticamente em $LIBS_DIR/lib:"
    ls -lh "$LIBS_DIR/lib" | grep eccodes
    [ "$PROMPTOK" -eq 1 ] && read -p "ECCODES estático finalizado. Pressione Enter..."
fi

# ===============================
#        CDI (STATIC, externo)
#  20/09/2025 - GNU OK
#  
# TODO:
# INTEL
# NVIDIA  
# ===============================
# ===============================
if [ "${OPTIONS[15]}" -eq 1 ]; then
    echo ">>> CDI: baixando e compilando ESTÁTICO (ecCodes, COM Fortran) ..."

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

export CC=gcc
export FC=gfortran

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
echo 'int main(){return 0;}' > /tmp/t.c
if ! gcc /tmp/t.c $CPPFLAGS $LDFLAGS $LIBS -o /tmp/t.exe ; then
    echo ">>> FALHA no link de teste com as libs detectadas."
    echo ">>> CPPFLAGS: $CPPFLAGS"
    echo ">>> LDFLAGS : $LDFLAGS"
    echo ">>> LIBS    : $LIBS"
    exit 1
fi
rm -f /tmp/t.c /tmp/t.exe

./configure \
  --build="$BUILD_TRIPLET" \
  --prefix="$LIBS_DIR" \
  
  --libdir="$LIBS_DIR/lib" \
  --includedir="$LIBS_DIR/include" \
  --disable-shared --enable-static \
  --with-eccodes="$LIBS_DIR" \
  --enable-iso-c-interface



    make -j "$CPU_HALF_EVEN"
    make install

    echo ">>> Verificando CDI em $LIBS_DIR:"
    ls -lh "$LIBS_DIR/lib"/libcdi*.a || true
    ls -lh "$LIBS_DIR/include"/cdi*.mod "$LIBS_DIR/include"/cdi/cdi*.mod 2>/dev/null || true

    [ "$PROMPTOK" -eq 1 ] && read -p "CDI estático (com Fortran) finalizado. Pressione Enter..."
fi


# ===============================
#        OPENBLAS (STATIC)
#  20/09/2025 - GNU OK
#  
# TODO:
# INTEL
# NVIDIA  
# ===============================
# ===============================
if [ "${OPTIONS[16]}" -eq 1 ]; then
    echo ">>> OPENBLAS: compilando versão ESTÁTICA..."

    cd "$DOWNLOADS"
    # Baixe a versão desejada (ex.: 0.3.27)
    [ -f OpenBLAS-0.3.27.tar.gz ] || wget https://github.com/xianyi/OpenBLAS/archive/refs/tags/v0.3.27.tar.gz -O OpenBLAS-0.3.27.tar.gz

    rm -rf OpenBLAS-0.3.27
    tar -xf OpenBLAS-0.3.27.tar.gz
    cd OpenBLAS-0.3.27

    # Build 100% estático, sem OpenMP para evitar precisar de -fopenmp/-lgomp
    make -j "$CPU_HALF_EVEN" NO_SHARED=1 USE_OPENMP=0
    #make PREFIX="$LIBS_DIR" install
    make NO_SHARED=1 USE_OPENMP=0 PREFIX="$LIBS_DIR" install

    echo ">>> Criando symlinks compatíveis (blas/lapack) -> openblas"
    cd "$LIBS_DIR/lib"
    ln -sf libopenblas.a libblas.a
    ln -sf libopenblas.a liblapack.a

    echo ">>> OK: instalados:"
    ls -lh "$LIBS_DIR/lib"/lib{openblas,blas,lapack}.a
    [ "$PROMPTOK" -eq 1 ] && read -p "OpenBLAS estático finalizado. Pressione Enter..."
fi

# ===============================
#        LIBXML2 (STATIC)
#  20/09/2025 - GNU OK
#  
# TODO:
# INTEL
# NVIDIA  
# ===============================
# ===============================
if [ "${OPTIONS[17]}" -eq 1 ]; then
    echo ">>> LIBXML2: compilando versão ESTÁTICA..."

    cd "$DOWNLOADS"
    LIBXML2_VERSION="2.11.7"
    LIBXML2_TAR="libxml2-${LIBXML2_VERSION}.tar.xz"
    LIBXML2_DIR="libxml2-${LIBXML2_VERSION}"

    # Baixar do repositório GNOME (novo caminho)
    [ -f "$LIBXML2_TAR" ] || \
        wget https://download.gnome.org/sources/libxml2/2.11/$LIBXML2_TAR

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
    make install

    echo ">>> Verificando arquivos instalados:"
    ls -lh "$LIBS_DIR/lib/libxml2.a"
    ls -lh "$LIBS_DIR/include/libxml2"

    [ "$PROMPTOK" -eq 1 ] && read -p "libxml2 estático finalizado. Pressione Enter..."
fi









##-----------------------------------------------------------------------------------
#
#                    WRF - VERSÃO MAIS RECENTE 
#
#  SE INTEL E PARALLEL_VERSION =1   : NÃO ESTÁ 100% IMPLEMENTADO, AINDA USANDO 
#                                     export NETCDF_classic=1   
#   20/03/2025 -  GNU OK 
#   15/05/2025 -  INTEL  
#                  Foram criadas criticas para rodar compilador intel              
#
#
#
#-----------------------------------------------------------------------------------------
#
#
if [ "${MODELS[0]}" -eq 1 ]; then

patch_wrfnc4_block() {
  set -euo pipefail
  local cfg="${1:-./configure}"
  [ -f "$cfg" ] || { echo "ERRO: $cfg não existe."; return 1; }

  # Idempotência: se já tiver nosso marcador, não faz nada
  if grep -q "nc-config verified" "$cfg"; then
    echo ">>> configure já patchado (nc-config verified)."
    return 0
  fi

  # Backup
  cp -p "$cfg" "${cfg}.bak"

  # Bloco novo (substitui todo o trecho '# testing for netcdf4 IO features' original)
  local blk
  blk="$(mktemp)"
  cat > "$blk" <<'EOF_BLK'
# testing for netcdf4 IO features
if [ -n "$NETCDF4" ] ; then
  if [ $NETCDF4 -eq 1 ] ; then

    # Caminho rápido: se nc-config reporta NC4, não precisa compilar o teste
    if [ -x "$NETCDF_C/bin/nc-config" ] && [ "`$NETCDF_C/bin/nc-config --has-nc4 2>/dev/null`" = "yes" ]; then
      echo "*****************************************************************************"
      echo "This build of WRF will use NETCDF4 with HDF5 compression (nc-config verified)"
      echo "*****************************************************************************"
      echo " "

    # Override manual (opcional): usuário pode forçar o skip do teste
    elif [ "${NETCDF_ASSUME_NC4:-0}" = "1" ]; then
      echo "*****************************************************************************"
      echo "This build of WRF will use NETCDF4 with HDF5 compression (forced by NETCDF_ASSUME_NC4=1)"
      echo "*****************************************************************************"
      echo " "

    else
      # Caminho legado: roda o teste de link se não houve confirmação por nc-config
      NC_INC="$("$NETCDF/bin/nc-config" --includedir 2>/dev/null)"
      NC_LIBS="$("$NETCDF/bin/nc-config" --libs 2>/dev/null)"
      export NC_INC NC_LIBS
      if [ -n "$HDF5" ] && [ -d "$HDF5/lib" ]; then
        export H5_LIBS="-L$HDF5/lib -lhdf5_hl -lhdf5"
      fi

      make nc4_test > tools/nc4_test.log 2>&1
      retval=-1
      if  [ -f tools/nc4_test.exe ] ; then
        retval=0
        rm -f tools/nc4_test.log
      fi
      if [ $retval -ne 0  ] ; then
        echo "************************** W A R N I N G ************************************"
        echo "NETCDF4 IO features are requested, but this installation of NetCDF           "
        echo "  $NETCDF"
        echo "DOES NOT support these IO features.                                          "
        echo
        echo "Please make sure NETCDF version is 4.1.3 or later and was built with         "
        echo "--enable-netcdf4                                                             "
        echo
        echo "OR set NETCDF_classic variable                                               "
        echo "   bash/ksh : export NETCDF_classic=1                                        "
        echo "        csh : setenv NETCDF_classic 1                                        "
        echo 
        echo "Then re-run this configure script                                            "
        echo
        echo "!!! configure.wrf has been REMOVED !!!"
        echo
        echo "*****************************************************************************"
        rm -f configure.wrf
      else
        echo "*****************************************************************************"
        echo "This build of WRF will use NETCDF4 with HDF5 compression"
        echo "*****************************************************************************"
        echo " "
      fi
    fi

  fi
else
  echo "*****************************************************************************"
  echo "This build of WRF will use classic (non-compressed) NETCDF format"
  echo "*****************************************************************************"
  echo " "
fi
EOF_BLK

  # AWK: substitui o bloco original inteiro pelo nosso, preservando o resto
  local out
  out="$(mktemp)"
  awk -v repl="$blk" '
    function printfile(f,  l){ while ((getline l < f) > 0) print l; close(f) }
    BEGIN{ inblk=0; depth=0; started=0 }
    # Detecta o início do bloco
    /^# testing for netcdf4 IO features/ {
      if (started==0) {
        started=1; inblk=1; depth=0;
        printfile(repl);
        next
      }
    }
    # Enquanto dentro do bloco original, controlamos a profundidade de if/fi
    inblk {
      # Conta if/fi apenas no início da linha (robusto o suficiente p/ esse trecho)
      if ($0 ~ /^[[:space:]]*if[[:space:]]*\[/) depth++
      if ($0 ~ /^[[:space:]]*fi[[:space:]]*$/) {
        if (depth==0) { inblk=0; next } else { depth--; next }
      }
      next
    }
    { print }
  ' "$cfg" > "$out"

  mv "$out" "$cfg"
  rm -f "$blk"
    chmod +x "$cfg"
  echo ">>> configure patch aplicado com sucesso (backup em ${cfg}.bak)."
}

# Exemplo de uso (ajuste o caminho se necessário):
#   cd "$INSTALL_DIR/WRF"
#   patch_wrfnc4_block "./configure"



# ===============================================================
# Funções auxiliares para proteger o ./compile (WRF/WPS) contra
# conflito de IFUNC (ex: cosf) entre libimf.so (Intel oneAPI) e
# libm.so.6 da glibc quando /bin/csh é invocado.
#
# Contexto:
# - Durante a compilação, ./compile chama /bin/csh.
# - Se LD_LIBRARY_PATH aponta para libimf.so (Intel), o csh pode
#   crashar com "Relink libimf.so with /lib64/libm.so.6 for IFUNC cosf".
# - Solução: forçar o preload da libm da glibc OU limpar o LD_LIBRARY_PATH.
# ===============================================================

# ---------------------------------------------------------------
# detect_glibc_libm:
#   Localiza a libm.so.6 da glibc (implementação de funções matemáticas).
#   - Caminho varia conforme a distro (RedHat, Debian, Ubuntu...).
#   - Primeiro tenta locais conhecidos.
#   - Se não encontrar, consulta ldconfig como fallback.
# ---------------------------------------------------------------
detect_glibc_libm() {
  for p in /lib64/libm.so.6 /usr/lib64/libm.so.6 /usr/lib/x86_64-linux-gnu/libm.so.6; do
    [ -f "$p" ] && { echo "$p"; return 0; }
  done
  # Último recurso: consulta cache do ldconfig
  if command -v ldconfig >/dev/null 2>&1; then
    ldconfig -p | awk '/libm\.so\.6/{print $NF; exit}'
  fi
}

# ---------------------------------------------------------------
# wps_compile_safe:
#   Executa o ./compile do WPS protegido contra crash do csh.
#   - Se libm encontrada: usa LD_PRELOAD apontando explicitamente
#     para a libm da glibc.
#   - Se não encontrada: filtra o LD_LIBRARY_PATH para excluir
#     diretórios da Intel oneAPI, rodando csh num ambiente limpo.
# ---------------------------------------------------------------
# wps_compile_safe() {
#   local libm; libm="$(detect_glibc_libm)"
#   if [ -n "$libm" ]; then
#     echo ">>> WPS compile: LD_PRELOAD=$libm (protegendo csh do IFUNC cosf)"
#     env LD_PRELOAD="$libm" ./compile
#   else
#     local CLEAN_LDLP
#     CLEAN_LDLP="$(echo "${LD_LIBRARY_PATH:-}" | tr ':' '\n' | grep -v '/opt/intel/oneapi/compiler/' | paste -sd: -)"
#     echo ">>> WPS compile: rodando com LD_LIBRARY_PATH saneado (sem oneAPI compiler)"
#     env LD_LIBRARY_PATH="$CLEAN_LDLP" ./compile
#   fi
# }
wrf_compile_safe() {
  local libm logf
  logf="build_wrf_$(date +%F_%H%M).log"

  libm="$(detect_glibc_libm)"
  if [ -n "$libm" ]; then
    echo ">>> WRF compile: LD_PRELOAD=$libm (protegendo /bin/csh do IFUNC cosf)"
    echo ">>> Log em: $logf"
    env LD_PRELOAD="$libm" ./compile -j "${CPU_HALF_EVEN:-1}" em_real \
      2>&1 | tee "$logf"
  else
    local CLEAN_LDLP
    CLEAN_LDLP="$(echo "${LD_LIBRARY_PATH:-}" | tr ':' '\n' | grep -v '/opt/intel/oneapi/compiler/' | paste -sd: -)"
    echo ">>> WRF compile: rodando com LD_LIBRARY_PATH saneado para /bin/csh"
    echo ">>> Log em: $logf"
    env LD_LIBRARY_PATH="$CLEAN_LDLP" ./compile -j "${CPU_HALF_EVEN:-1}" em_real \
      2>&1 | tee "$logf"
  fi

  echo ">>> Fim da compilação do WRF — veja $logf"
}

# ---------------------------------------------------------------
# wrf_compile_safe:
#   Igual ao wps_compile_safe, mas invoca a compilação do WRF.
#   - Inclui paralelismo (-j) e o target padrão em_real.
# ---------------------------------------------------------------


# Check if the WRF installation option is enabled

    
    echo ">> Starting WRF installation..."
	 # Enable support for large NetCDF files
	export WRFIO_NCD_LARGE_FILE_SUPPORT=1
	export PNETCDF="$LIBS_DIR"
    export PNETCDF_PATH="$LIBS_DIR"
    export PNETCDF_LIB="-L$LIBS_DIR/lib -lpnetcdf"
    export PNETCDF_INC="-I$LIBS_DIR/include"
    export NETCDF_C="$LIBS_DIR"
    # Set compiler flags to include headers and link libraries from NetCDF and MPI
    export CPPFLAGS="-I$LIBS_DIR/include -I$MPI_DIR/include"
    export LDFLAGS="-L$LIBS_DIR/lib -L$MPI_DIR/lib"

    # oneAPI e wrappers
  if [ "${COMPILERS:-INTEL}" = "INTEL" ]; then
    [ -f /opt/intel/oneapi/setvars.sh ] && source /opt/intel/oneapi/setvars.sh
    export I_MPI_CC=${I_MPI_CC:-icx}
    export I_MPI_CXX=${I_MPI_CXX:-icpx}
    export I_MPI_FC=${I_MPI_FC:-ifx}
  fi


   #export NETCDF_classic=1
    # Navigate to the installation directory and clone the WRF repository
    cd $INSTALL_DIR
    rm -rf WRF  # Remove any previous WRF directory to avoid conflicts
    git clone https://github.com/wrf-model/WRF.git
    cd WRF

    # Clean any previous build artifacts
    ./clean
    patch_wrfnc4_block "./configure"
    # Launch interactive configuration
    # Option 34 = dmpar (distributed memory) + gfortran
    # Option 1  = basic nesting
    ./configure

    # Optional manual review/editing of configure.wrf file
    #vim configure.wrf

    # Compile WRF with parallel jobs based on available CPU cores
    wrf_compile_safe

    # Display the resulting executables
    echo -e "\n>> WRF build completed."
    ls_clean -ltr main/*.exe

    # Prompt user to continue (if enabled)
    [ "$PROMPTOK" -eq 1 ] && read -p "WRF build done. Press enter to continue..."
fi




# =============================================================================================
#
#            WPS  - VERSÃO MAIS RECENTE 
#
#   14/02/2020 -  INTEL  OK 
#   27/09/2025  - INTEL MPÍCH OK 
#   
#
# ===============================================================================================
if [ "${MODELS[1]}" -eq 1 ]; then

  # Protege /bin/csh do IFUNC cosf (não altera flags do build)
  detect_glibc_libm() {
    for p in /lib64/libm.so.6 /usr/lib64/libm.so.6 /usr/lib/x86_64-linux-gnu/libm.so.6; do
      [ -f "$p" ] && { echo "$p"; return 0; }
    done
    command -v ldconfig >/dev/null 2>&1 && ldconfig -p | awk '/libm\.so\.6/{print $NF; exit}'
  }
  safe_run_csh() {
    local libm; libm="$(detect_glibc_libm)"
    if [ -n "$libm" ]; then env LD_PRELOAD="$libm" "$@"; else env -u LD_LIBRARY_PATH "$@"; fi
  }

  # (re)clona WPS
  cd "$INSTALL_DIR" || { echo "ERRO: não consegui entrar em $INSTALL_DIR"; { return 1; } 2>/dev/null || exit 1; }
  rm -rf WPS
  git clone https://github.com/wrf-model/WPS.git
  cd WPS || { echo "ERRO: WPS não clonado"; { return 1; } 2>/dev/null || exit 1; }
  ./clean

  # configure (sem forçar nada; você escolhe no menu)
  safe_run_csh ./configure

  if [ ! -f configure.wps ]; then
    echo ">>> ERRO: 'configure.wps' não foi gerado. Verifique mensagens do ./configure acima."
    { return 1; } 2>/dev/null || exit 1
  fi

# Detecta PnetCDF
HAS_PNETCDF=0
for d in "${PNETCDF:-$LIBS_DIR}/lib" "${PNETCDF:-$LIBS_DIR}/lib64"; do
  [ -e "$d/libpnetcdf.a" ] || [ -e "$d/libpnetcdf.so" ] && HAS_PNETCDF=1
done

# 1) Se houver PnetCDF, injeta em QUALQUER linha que contenha "-lnetcdff -lnetcdf"
if [ "$HAS_PNETCDF" -eq 1 ]; then
  # evita duplicar se já tiver -lpnetcdf
  if ! grep -q '\-lpnetcdf' configure.wps; then
    sed -i 's/-lnetcdff[[:space:]]*-lnetcdf/-lnetcdff -lnetcdf -lpnetcdf -lhdf5_hl -lhdf5 -lz -ldl/g' configure.wps
  fi
else
  # 2) Sem PnetCDF, ao menos garanta HDF5/z/dl após -lnetcdf
  # (só adiciona se ainda não houver hdf5_hl na mesma linha)
  if ! grep -q '\-lhdf5_hl' configure.wps; then
    sed -i 's/-lnetcdff[[:space:]]*-lnetcdf/-lnetcdff -lnetcdf -lhdf5_hl -lhdf5 -lz -ldl/g' configure.wps
  fi
fi
  # ----------------------------------
  sed -i 's/^SFC *=.*/SFC = $(DM_FC)/' configure.wps
  sed -i 's/^SCC *=.*/SCC = $(DM_CC)/' configure.wps
  sed -i 's/^FC *=.*/FC = $(DM_FC)/'   configure.wps
  sed -i 's/^CC *=.*/CC = $(DM_CC)/'   configure.wps
  sed -i 's/^LD *=.*/LD = $(FC)/'      configure.wps

  export I_MPI_F90=ifx
  export I_MPI_CC=icx
  # compile (conforme o que o configure definiu)
  if safe_run_csh ./compile; then
    echo -e "\n>> WPS: build finalizado — executáveis presentes:"
  else
    echo ">>> AVISO: ./compile retornou erro (verifique o log acima)."
  fi

  for exe in geogrid/src/geogrid.exe metgrid/src/metgrid.exe ungrib/src/ungrib.exe; do
    [ -f "$exe" ] && ls -ltr "$exe" || echo ">>> AVISO: faltou gerar $exe"
  done
fi







################################# MPAS-ATMOSPHERE ################################
# USE_PIO2 over PIO1
##################################################################################
if [ "${MODELS[2]}" -eq 1 ]; then
  echo ">> Starting MPAS installation..."

  # --- Prefixo LIMPO (sem / no final) e wrappers MPI do seu MPICH ---
  PREFIX="${LIBS_DIR%/}"
  export PATH="$PREFIX/bin:$PATH"
  hash -r

  # --- Paths para as libs (o Makefile do MPAS usa isso) ---
  export NETCDF="$PREFIX"
  export PNETCDF="$PREFIX"
  export PIO="$PREFIX"
  export HDF5="$PREFIX"
  export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"

  # (ajuda a linkar estático quando necessário)
  export MPAS_EXTERNAL_INCLUDES="-I$LIBS_DIR/include"
  export MPAS_EXTERNAL_LIBS="\
  $LIBS_DIR/lib/libpiof.a \
  $LIBS_DIR/lib/libpioc.a \
  $LIBS_DIR/lib/libnetcdff.a \
  $LIBS_DIR/lib/libnetcdf.a \
  $LIBS_DIR/lib/libhdf5_hl.a \
  $LIBS_DIR/lib/libhdf5.a \
  -lz -ldl -lm -lpthread"   # acrescente -lcurl se o seu netcdf precisar

  # --- Escolhe wrappers MPI locais (MPICH do PREFIX/bin). Fallback p/ mpif90 se mpifort não existir ---
  MPICC="$PREFIX/bin/mpicc"
  MPICXX="$PREFIX/bin/mpicxx"
  MPIFC="$PREFIX/bin/mpifort"; [ -x "$MPIFC" ] || MPIFC="$PREFIX/bin/mpif90"

  # Sanidade mínima
  [ -x "$MPICC" ] || { echo "ERRO: não achei $MPICC"; exit 1; }
  [ -x "$MPIFC" ] || { echo "ERRO: não achei $MPIFC"; exit 1; }
  [ -f "$PREFIX/include/pnetcdf.h" ] || { echo "ERRO: faltando $PREFIX/include/pnetcdf.h"; exit 1; }
  [ -f "$PREFIX/lib/libpnetcdf.a" ] || { echo "ERRO: faltando $PREFIX/lib/libpnetcdf.a"; exit 1; }

  # --- Clone limpo ---
  cd "$INSTALL_DIR"
  rm -rf MPAS-Model
  git clone https://github.com/MPAS-Dev/MPAS-Model.git
  cd MPAS-Model

  # --- TESTE RÁPIDO do PnetCDF com o SEU mpicc (evita erro críptico do Makefile) ---
  # rm -f pnetcdf.out
  # "$MPICC" pnetcdf.c -I"$PREFIX/include" -L"$PREFIX/lib" -lpnetcdf -o pnetcdf.out \
  #   || { echo "ERRO: falhou o teste pnetcdf.c com $MPICC. Verifique include/lib do PREFIX."; exit 1; }

  # --- Build coerente com o COMPILER e forçando os wrappers paralelos ---
  case "$COMPILER" in
    GNU)
      echo ">> MPAS compiling with GNU (gfortran target)"
      make gfortran CORE=init_atmosphere USE_PIO2=true PRECISION=single \
           CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC"
      make clean CORE=atmosphere USE_PIO2=true PRECISION=single
      make gfortran CORE=atmosphere USE_PIO2=true PRECISION=single -j"$CPU_HALF_EVEN" \
           CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC"
      ;;
    INTEL)
      echo ">> MPAS compiling with INTEL (intel target)"
      make intel CORE=init_atmosphere USE_PIO2=true PRECISION=single \
           CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC"
      make clean CORE=atmosphere USE_PIO2=true PRECISION=single
      make intel CORE=atmosphere USE_PIO2=true PRECISION=single -j"$CPU_HALF_EVEN" \
           CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC"
      ;;
    NVIDIA)
      echo ">> MPAS compiling with NVIDIA HPC (nvhpc target)"
      make nvhpc CORE=init_atmosphere USE_PIO2=true PRECISION=single \
           CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC"
      make clean CORE=atmosphere USE_PIO2=true PRECISION=single
      make nvhpc CORE=atmosphere USE_PIO2=true PRECISION=single -j"$CPU_HALF_EVEN" \
           CC_PARALLEL="$MPICC" CXX_PARALLEL="$MPICXX" FC_PARALLEL="$MPIFC"
      ;;
    *)
      echo "ERRO: COMPILER=$COMPILER não reconhecido para MPAS."; exit 1;;
  esac

  [ "$PROMPTOK" -eq 1 ] && read -p "MPAS build done. Press enter to continue..."
fi



#-----------------------------------------------------------------------------------
################################# MPAS-ATMOSPHERE ################################
# VERSÃO ESPECÍFICA: v7.0  (PIO2)
#-----------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------
################################# MPAS-ATMOSPHERE ################################
# VERSAO ESPECIFICA: v7.0 (PIO2)
#-----------------------------------------------------------------------------------
if [ "${MODELS[4]}" -eq 1 ]; then
    echo ">> Starting MPAS 7.0 installation..."

    cd "$INSTALL_DIR"
    rm -rf MPAS-7.0
    git clone https://github.com/MPAS-Dev/MPAS-Model.git MPAS-7.0
    cd MPAS-7.0
    git checkout tags/v7.0

    # ---- Prefixos das bibliotecas (AJUSTE se necessário) ----
      # você informou que é aqui
    export NETCDF="$LIBS_DIR"          # prefixo do NetCDF (include/ e lib/)
    export PNETCDF="$LIBS_DIR"         # prefixo do PnetCDF (include/ e lib/)
    export PIOSRC="$DOWNLOADS/ParallelIO-pio$Pio_Version/"    
    # (opcional) para .so
    export LD_LIBRARY_PATH="$PIO/lib:$PNETCDF/lib:$NETCDF/lib:${LD_LIBRARY_PATH:-}"
    export PIO=$DOWNLOADS"/pio" 
    echo $PIO
    read -p "q"
    # ---- Compilação ----
    if [ "$COMPILER" = "GNU" ]; then
        echo ">> MPAS compiling with GNU (fix BOZ)"
        # fix BOZ: necessário para gfortran >= 10
        EXTRA_FFLAGS="-fallow-invalid-boz -std=legacy"

        # init_atmosphere
        make gfortran CORE=init_atmosphere USE_PIO2=true PRECISION=single \
              NETCDF="$NETCDF" PNETCDF="$PNETCDF"               \
             FFLAGS+="$EXTRA_FFLAGS" || exit 2

        make clean CORE=atmosphere

        # atmosphere
        make gfortran CORE=atmosphere      USE_PIO2=true PRECISION=single \
              NETCDF="$NETCDF" PNETCDF="$PNETCDF"               \
             FFLAGS+="$EXTRA_FFLAGS" || exit 2

    elif [ "$COMPILER" = "INTEL" ]; then
        echo ">> MPAS compiling with INTEL"
        make intel   CORE=init_atmosphere USE_PIO2=true PRECISION=single  \
             PIO="$PIO" NETCDF="$NETCDF" PNETCDF="$PNETCDF" || exit 2

        make clean   CORE=atmosphere

        make intel   CORE=atmosphere      USE_PIO2=true PRECISION=single  \
             PIO="$PIO" NETCDF="$NETCDF" PNETCDF="$PNETCDF" || exit 2

    elif [ "$COMPILER" = "NVIDIA" ]; then
        echo ">> MPAS compiling with NVIDIA HPC"
        make nvhpc   CORE=init_atmosphere USE_PIO2=true PRECISION=single  \
             PIO="$PIO" NETCDF="$NETCDF" PNETCDF="$PNETCDF" || exit 2

        make clean   CORE=atmosphere

        make nvhpc   CORE=atmosphere      USE_PIO2=true PRECISION=single  \
             PIO="$PIO" NETCDF="$NETCDF" PNETCDF="$PNETCDF" || exit 2
    fi

    [ "$PROMPTOK" -eq 1 ] && read -p "MPAS build done. Press enter to continue..."
fi



if [ "${OPTIONS[3]}" -eq 1 ]; then


    cd "$DOWNLOADS"

    wget -nc https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_high_res_mandatory.tar.gz
    wget -nc https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_noahmp.tar.gz
    wget -nc https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_thompson28_chem.tar.gz
    wget -nc https://www2.mmm.ucar.edu/wrf/src/wps_files/irrigation.tar.gz
    wget -nc https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_px.tar.gz
    wget -nc https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_urban.tar.gz
    wget -nc https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_ssib.tar.gz
    wget -nc https://www2.mmm.ucar.edu/wrf/src/wps_files/lake_depth.tar.bz2
    wget -nc https://www2.mmm.ucar.edu/wrf/src/wps_files/modis_landuse_20class_30s_with_lakes.tar.bz2
    wget -nc https://www2.mmm.ucar.edu/wrf/src/wps_files/modis_landuse_20class_30s.tar.bz2
    tar -xvzf geog_high_res_mandatory.tar.gz -C $GEOG/WPS_GEOG
    tar -xvzf geog_thompson28_chem.tar.gz -C $GEOG/WPS_GEOG
    tar -xvzf geog_noahmp.tar.gz -C $GEOG/WPS_GEOG
    tar -xvzf irrigation.tar.gz -C $GEOG/WPS_GEOG
    tar -xvzf geog_px.tar.gz -C $GEOG/WPS_GEOG
    tar -xvzf geog_urban.tar.gz -C $GEOG/WPS_GEOG
    tar -xvzf geog_ssib.tar.gz -C $GEOG/WPS_GEOG
    tar -xvf lake_depth.tar.bz2 -C $GEOG/WPS_GEOG
    tar -xvf modis_landuse_20class_30s_with_lakes.tar.bz2 -C $GEOG/WPS_GEOG
    tar -xvf modis_landuse_20class_30s.tar.bz2 -C $GEOG/WPS_GEOG
    # Prompt user to continue (if enabled)
    [ "$PROMPTOK" -eq 1 ] && read -p "GEOG pronto. verifique. Press enter to continue."

fi
