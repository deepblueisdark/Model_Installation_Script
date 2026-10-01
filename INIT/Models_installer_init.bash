#!/bin/bash

setup_install_libs_dir(){
HOME_DIR="${HOME_DIR:-$HOME}"
INSTALLATION_PATH="${INSTALLATION_PATH:-$HOME_DIR/MODELS}"
export HOME_DIR INSTALLATION_PATH
export INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/"

case $GNU_MPI in 
    0)  
        echo " CONFIGURACAO DO SISTEMA"
        export INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/"
        export LIBS_DIR="$INSTALL_DIR/SISTEM" 
        ;;
    1)  
        echo " CONFIGURACAO GNU SERIAL + MPICH"
        export INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/"
        export LIBS_DIR="$INSTALL_DIR/SERIAL/"      
        ;;
    2) 
         echo " CONFIGURACAO TUDO MPICH "
        export INSTALL_DIR="$INSTALLATION_PATH/$COMPILER/"
        export LIBS_DIR="$INSTALL_DIR/MPICH/"      
        ;;
    *)
        echo "[ERRO] Modo inválido: $mode"
        echo "Use 0 (sistema )  1  GNU   2  (GNU via MPI wrappers)."
        return 1
            ;;
    esac
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$LIBS_DIR"
    mkdir -p "$DOWNLOADS"
    # Se MODEL_DIR_INSTALL não existir ou estiver vazio, usar INSTALL_DIR
    export MODEL_DIR_INSTALL="${MODEL_DIR_INSTALL:-$LIBS_DIR}"

    # Criar diretório (mesmo que já exista)
    mkdir -p "$MODEL_DIR_INSTALL"

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
export CFLAGS="-O3 -fPIC -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-error=incompatible-pointer-types"
export CXXFLAGS="-O3 -fPIC"
export FFLAGS="-O3 -fPIC"
export FCFLAGS="-O3 -fPIC"  ### -fno-second-underscore -ffree-form"
export LDFLAGS="-fPIC"
}

ensure_zstd_in_libs_dir() {
    echo "===================================================="
    echo " Verificando ZSTD no diretório de bibliotecas"
    echo " LIBS_DIR: $LIBS_DIR"
    echo "===================================================="

    local TARGET_DIR="$LIBS_DIR/lib"

    # Confere se o destino existe
    if [ ! -d "$TARGET_DIR" ]; then
        echo "[ERRO] Diretório destino não existe: $TARGET_DIR"
        return 1
    fi

    # Lista de libs a verificar
    local ZSTD_LIBS=(
        "libzstd.so"
        "libzstd.so.1"
        "libzstd.a"
    )

    local MISSING=0

    echo ">> Checando bibliotecas ZSTD em $TARGET_DIR..."

    for lib in "${ZSTD_LIBS[@]}"; do
        if [ -e "$TARGET_DIR/$lib" ]; then
            echo "   [OK] $lib presente"
        else
            echo "   [FALTA] $lib"
            MISSING=1
        fi
    done

    # Se todas existem — nada a fazer
    if [ "$MISSING" -eq 0 ]; then
        echo ">> Todas as bibliotecas ZSTD já estão presentes."
        echo "===================================================="
        return 0
    fi

    echo
    echo ">> Procurando libzstd no sistema (/usr/lib64)..."
    echo

    # Local melhor para Rocky/Fedora/RHEL
    local SRC_DIR="/usr/lib64"

    for lib in "${ZSTD_LIBS[@]}"; do
        if [ -e "$SRC_DIR/$lib" ]; then
            echo "   Encontrado: $SRC_DIR/$lib"
            echo "   Copiando para $TARGET_DIR..."
            cp -f "$SRC_DIR/$lib" "$TARGET_DIR/" || {
                echo "[ERRO] Não consegui copiar $lib"
                return 1
            }
        fi
    done

    echo
    echo ">> Ajustando permissões..."
    chmod 755 "$TARGET_DIR"/libzstd* 2>/dev/null

    echo
    echo ">> Verificação final:"
    ls -l "$TARGET_DIR"/libzstd*

    echo "===================================================="
    echo " Bibliotecas ZSTD garantidas em: $TARGET_DIR"
    echo "===================================================="
}


#----------------------------------------------------------------------------------------
#                     CPU RESOURCE MANAGEMENT
#----------------------------------------------------------------------------------------
cpu_resource(){

USE_ALL_CORES=${USE_ALL_CORES:-false}
export CPU_CORE=$(nproc)
echo "================================================================"
echo "                CPU RESOURCE MANAGEMENT                         "
echo "-- "
echo "-- TOTAL AVAILABLE CPU CORES: $CPU_CORE"
CPU_CORE_LIMIT=8

if [ "$USE_ALL_CORES" = true ]; then
  CPU_HALF_EVEN=$CPU_CORE
  echo "USING ALL AVAILABLE CORES AS CONFIGURED"
else
  CPU_HALF=$((CPU_CORE / 2))
  CPU_HALF_EVEN=$((CPU_HALF - (CPU_HALF % 2)))
  if [ $CPU_CORE -le $CPU_CORE_LIMIT ]; then
    CPU_HALF_EVEN=2
    echo "LOW-CORE SYSTEM DETECTED – FORCING USAGE OF 2 CORES ONLY"
  fi
fi
export CPU_HALF_EVEN
echo "CORES TO BE USED BY THE SCRIPT: $CPU_HALF_EVEN"
echo "================================================================"
}




#-----------------------------------------------------------------------------
#   CHECK INITIAL COMPILERS
#-----------------------------------------------------------------------------
check_initial_compilers() {
    echo "=================================================================="
    echo " VERIFICANDO COMPILADORES NO SISTEMA"
    echo " MODO SELECIONADO: $GNU_MPI -> $MODE_NAME"
    echo " DIR DE INSTALAÇÃO: $INSTALL_DIR"
    echo "=================================================================="

    # Função auxiliar: detecta se um caminho vem de conda/miniconda
    is_from_conda() {
        local path="$1"
        [[ "$path" == *"conda"* || "$path" == *"miniconda"* || "$path" == *"mambaforge"* || "$path" == *"micromamba"* ]]
    }

    # --- VERIFICAÇÃO DE SEGURANÇA: MPICC VIA CONDA ---
    DETECT_MPICC=$(command -v mpicc 2>/dev/null || true)
    if [[ -n "$DETECT_MPICC" ]] && is_from_conda "$DETECT_MPICC"; then
        echo ""
        echo "##################################################################"
        echo " PERIGO: MPICC DO CONDA DETECTADO"
        echo " Caminho: $DETECT_MPICC"
        echo " O uso de compiladores/MPI do Conda costuma falhar na compilação"
        echo " de modelos como WRF/MPAS (bibliotecas incompatíveis)."
        echo " Recomenda-se fortemente desativar o ambiente Conda:"
        echo "     conda deactivate    (pode ser necessário várias vezes)"
        echo "##################################################################"
        echo ""
        exit
    fi
    
    #-----------------------------------------------------------------
    #  COMPILADORES SERIAIS GNU (BASE)
    #-----------------------------------------------------------------
    echo "--- Compiladores Seriais GNU (base) ---"
    for cmd in gcc g++ gfortran; do
        if command -v "$cmd" >/dev/null 2>&1; then 
            path_cmd=$(command -v "$cmd")
            echo "  [OK] $cmd encontrado -> $path_cmd"

            if is_from_conda "$path_cmd"; then
                echo "    [ALERTA] $cmd está vindo de um ambiente CONDA:"
                echo "             $path_cmd"
                echo "             Para compilar WRF/MPAS, é recomendável usar compiladores"
                echo "             do sistema (por exemplo /usr/bin/gcc) e NÃO os do Conda."
            fi
        else 
            echo "  [!!] $cmd NÃO encontrado (CRÍTICO se você for usar GNU)"
        fi
    done

    #-----------------------------------------------------------------
    #  COMPILADORES INTEL (classic + oneAPI)
    #-----------------------------------------------------------------
    echo "--- Compiladores Intel (classic / oneAPI) ---"
    intel_found=0
    for cmd in icc icpc ifort icx icpx ifx; do
        if command -v "$cmd" >/dev/null 2>&1; then
            path_cmd=$(command -v "$cmd")
            echo "  [OK] $cmd encontrado -> $path_cmd"
            intel_found=1
        fi
    done
    if [[ "$intel_found" -eq 0 ]]; then
        echo "  [--] Nenhum compilador Intel encontrado no PATH."
    fi

    #-----------------------------------------------------------------
    #  COMPILADORES NVIDIA (NVHPC)
    #-----------------------------------------------------------------
    echo "--- Compiladores NVIDIA (NVHPC) ---"
    nvidia_found=0
    for cmd in nvc nvc++ nvfortran; do
        if command -v "$cmd" >/dev/null 2>&1; then
            path_cmd=$(command -v "$cmd")
            echo "  [OK] $cmd encontrado -> $path_cmd"
            nvidia_found=1
        fi
    done
    if [[ "$nvidia_found" -eq 0 ]]; then
        echo "  [--] Nenhum compilador NVIDIA (NVHPC) encontrado no PATH."
    fi

    #-----------------------------------------------------------------
    #  COMPILADORES PARALELOS (MPI)
    #-----------------------------------------------------------------
    if [ "$GNU_MPI" -eq 0 ]; then
        echo "--- Compiladores Paralelos (MPI do sistema) ---"
        echo "    (Modo 0 usará estes se existirem)"

        for cmd in mpicc mpicxx mpif90 mpifort; do
            if command -v "$cmd" >/dev/null 2>&1; then 
                path_cmd=$(command -v "$cmd")
                echo "  [OK] $cmd encontrado -> $path_cmd"

                if is_from_conda "$path_cmd"; then
                    echo "    [ALERTA] $cmd está vindo de um ambiente CONDA:"
                    echo "             $path_cmd"
                    echo "             MPI do Conda costuma causar problemas na linkedição"
                    echo "             com bibliotecas externas (NetCDF, PnetCDF, PIO, etc.)."
                fi
            else 
                echo "  [--] $cmd NÃO encontrado no PATH atual."
            fi
        done

        echo "--- Wrappers MPI específicos Intel (se houver) ---"
        intel_mpi_found=0
        for cmd in mpiicc mpiicpc mpiifort; do
            if command -v "$cmd" >/dev/null 2>&1; then
                path_cmd=$(command -v "$cmd")
                echo "  [OK] $cmd encontrado -> $path_cmd"
                intel_mpi_found=1
            fi
        done
        if [[ "$intel_mpi_found" -eq 0 ]]; then
            echo "  [--] Nenhum wrapper MPI Intel (mpiicc/mpiifort) encontrado."
        fi
    else
     
        echo "    (Modo $GNU_MPI compilará seu próprio MPICH. Ignorando MPI do sistema.)"
    fi

    echo "=================================================================="
    echo "="
    echo "="
    echo "="
    
  
}


Toolchain_check_GNU(){

for t in gcc g++ gfortran; do command -v "$t" >/dev/null || { echo "ERROR: $t not found."; exit 1; }; done
GCC_MAJOR=$(gcc -dumpfullversion | cut -d. -f1)
if [ "$GCC_MAJOR" -ge 10 ]; then
  export fallow_argument="-fallow-argument-mismatch"
  export boz_argument="-fallow-invalid-boz"
else
  export fallow_argument=""
  export boz_argument=""
fi
} 



define_compilers() {
    local mode="$1"

    echo "========================================="
    echo " Definindo compiladores (GNU) — Modo $mode"
    echo "========================================="

    case "$mode" in

        #-----------------------------------------------
        #  MODO 0 — Compiladores do sistema (não recomendado se estiver em ambiente miniconda) 
        #-----------------------------------------------
        0)
            echo ">> MODO 0: Configuração existente no sistema"

            export CC=$(command -v gcc)
            export CXX=$(command -v g++)
            export FC=$(command -v gfortran)

            export MPICC=$(command -v mpicc)
            export MPICXX=$(command -v mpicxx)
            export MPIFC=$(command -v mpifort || command -v mpif90)
            ;;
        #-----------------------------------------------
        #  MODO 1 — Compiladores GNU normais
        #-----------------------------------------------
        1)
            echo ">> MODO 1: GNU padrão (gcc/gfortran + mpicc/mpifort)"

         export CC=$(command -v gcc)
         export CXX=$(command -v g++)
         export FC=$(command -v gfortran)
            
            mpi_setup 
   
            ;;
        #-----------------------------------------------
        #  MODO 2 — Usar Wrappers MPI como compiladores
        #-----------------------------------------------
        2)
            echo ">> MODO 2: Usando MPI como compiladores (mpicc/mpifort)"
            
            mpi_setup 
            export CC=$MPICC
            export CXX=$MPICXX
            export FC=$MPIF90 

            ;;
            
        #-----------------------------------------------
        #  ERRO
        #-----------------------------------------------
        *)
            echo "[ERRO] Modo inválido: $mode"
            echo "Use 0 (sistema )  1  GNU   2  (GNU via MPI wrappers)."
            return 1
            ;;
    esac

     export F77="$FC"
     export MPIF90="$MPIFC"  
    echo ""
    echo ">> Variáveis definidas:"
    echo "   CC     = $CC"
    echo "   CXX    = $CXX"
    echo "   FC     = $FC"
    echo "   F77    = $F77"
    echo "   MPICC  = $MPICC"
    echo "   MPICXX = $MPICXX"
    echo "   MPIFC  = $MPIFC"
    echo "   MPIF90 = $MPIF90"
    echo "   LD_LIBRARY_PATH = $LD_LIBRARY_PATH"
    echo "   LIBS_DIR        = $LIBS_DIR  (onde tudo acontece)"
    echo "   INSTALL_DIR     = $INSTALL_DIR"
    echo "   DOWNLOADS       = $DOWNLOADS"
    echo "  MODEL_DIR_INSTALL = $MODEL_DIR_INSTALL"
    echo "========================================="
}


# --------------------------------------------------------------------
# MPI: selecionar wrappers (Apenas MPICH)
# --------------------------------------------------------------------
mpi_setup() {
  export MPI_FLAVOR="none"

  # ---- MPICH (GNU Padrão) ----
  if [ -x "$LIBS_DIR/bin/mpifort" ] && [ -x "$LIBS_DIR/bin/mpicc" ]; then
    # Prioridade para o MPICH compilado pelo script (Modo 1 e 2)
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
    
    # --- CORREÇÃO DE SEGURANÇA CONDA (Fallback) ---
    CURRENT_MPICC=$(command -v mpicc)
    if [[ "$CURRENT_MPICC" == *"conda"* ]] || [[ "$CURRENT_MPICC" == *"miniconda"* ]]; then
        echo "WARNING: Conda MPI detected ($CURRENT_MPICC)."
        echo "Attempting to switch to SYSTEM MPI..."
        exit 1
        
        # # NOTE: Manter /usr/lib64 aqui é aceitável, pois estamos apenas definindo o PATH
        # # para o MPI do sistema, que tem bibliotecas lá.
        # if [ -x /usr/lib64/openmpi/bin/mpicc ]; then
        #     export PATH=/usr/lib64/openmpi/bin:$PATH
        #     export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:$LD_LIBRARY_PATH
        #     echo ">> Switched to System OpenMPI: /usr/lib64/openmpi/bin/mpicc"
        # elif [ -x /usr/lib64/mpich/bin/mpicc ]; then
        #     export PATH=/usr/lib64/mpich/bin:$PATH
        #     export LD_LIBRARY_PATH=/usr/lib64/mpich/lib:$LD_LIBRARY_PATH
        #      echo ">> Switched to System MPICH: /usr/lib64/mpich/bin/mpicc"
        # elif [ -x /usr/lib/x86_64-linux-gnu/openmpi/bin/mpicc ]; then
        #     export PATH=/usr/lib/x86_64-linux-gnu/openmpi/bin:$PATH
        #      echo ">> Switched to System OpenMPI (Debian): /usr/lib/x86_64-linux-gnu/openmpi/bin/mpicc"
        # fi
    fi

    export MPIFC="$(command -v mpifort || command -v mpif90 || true)"
    export MPICC="$(command -v mpicc   || true)"
    export MPICXX="$(command -v mpicxx || true)"
    export MPIF77="$MPIFC" ; export MPIF90="$MPIF90"
    export MPI_FLAVOR="mpich(PATH)"
  fi


}


Detect_system_distribution_and_update(){
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
        sudo dnf install -y gcc gcc-gfortran gcc-c++ libtool  \
                            automake autoconf make m4 cmake patch curl tar unzip wget
        sudo dnf install -y dnf-plugins-core
        sudo dnf config-manager --set-enabled crb
        sudo dnf clean all
        sudo dnf makecache
        ### necessário ICON 
        sudo dnf install -y libstdc++-static 
        sudo dnf install -y ruby
        # Java (some tools like Jasper or viewers may require it)
        sudo dnf install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel

        # Shells and useful utilities
        sudo dnf install -y csh ksh tcsh time git bash-completion wget git

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


}  


