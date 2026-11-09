#!/bin/bash

#----------------------------------------------------------------------------------------
#  setup_install_libs_dir
#  Define INSTALL_DIR, LIBS_DIR e MODEL_DIR_INSTALL conforme o modo GNU_MPI.
#  (As variáveis NETCDF/HDF5/CPPFLAGS/... ficam em Models_installer_enviroment.bash)
#----------------------------------------------------------------------------------------
setup_install_libs_dir(){
    HOME_DIR="${HOME_DIR:-$HOME}"
    INSTALLATION_PATH="${INSTALLATION_PATH:-$HOME_DIR/MODELS}"
    export HOME_DIR INSTALLATION_PATH
    export INSTALL_DIR="${INSTALLATION_PATH%/}/$COMPILER"

    case "$GNU_MPI" in
        0)
            export MODE_NAME="SISTEMA (compiladores/MPI do sistema)"
            export LIBS_DIR="$INSTALL_DIR/SISTEM"
            ;;
        1)
            export MODE_NAME="GNU SERIAL + MPICH"
            export LIBS_DIR="$INSTALL_DIR/SERIAL"
            ;;
        2)
            export MODE_NAME="TUDO VIA WRAPPERS MPICH"
            export LIBS_DIR="$INSTALL_DIR/MPICH"
            ;;
        *)
            echo "[ERRO] Modo inválido: GNU_MPI=$GNU_MPI"
            echo "Use 0 (sistema), 1 (GNU serial + MPICH) ou 2 (GNU via wrappers MPI)."
            return 1
            ;;
    esac
    echo " CONFIGURACAO: $MODE_NAME"

    # Se MODEL_DIR_INSTALL não existir ou estiver vazio, usar LIBS_DIR
    export MODEL_DIR_INSTALL="${MODEL_DIR_INSTALL:-$LIBS_DIR}"

    if [ "${DRY_RUN:-0}" -ne 1 ]; then
        mkdir -p "$INSTALL_DIR" "$LIBS_DIR" "$LIBS_DIR/lib" "$DOWNLOADS" "$MODEL_DIR_INSTALL"
    fi
}

#----------------------------------------------------------------------------------------
#  ensure_zstd_in_libs_dir
#  Copia libzstd do sistema para $LIBS_DIR/lib (compatibilidade NETCDF/HDF5).
#----------------------------------------------------------------------------------------
ensure_zstd_in_libs_dir() {
    echo "===================================================="
    echo " Verificando ZSTD no diretório de bibliotecas"
    echo " LIBS_DIR: $LIBS_DIR"
    echo "===================================================="

    local TARGET_DIR="$LIBS_DIR/lib"
    mkdir -p "$TARGET_DIR"

    local ZSTD_LIBS=( "libzstd.so" "libzstd.so.1" "libzstd.a" )
    local MISSING=0 lib src copied=0

    echo ">> Checando bibliotecas ZSTD em $TARGET_DIR..."
    for lib in "${ZSTD_LIBS[@]}"; do
        if [ -e "$TARGET_DIR/$lib" ]; then
            echo "   [OK] $lib presente"
        else
            echo "   [FALTA] $lib"
            MISSING=1
        fi
    done

    if [ "$MISSING" -eq 0 ]; then
        echo ">> Todas as bibliotecas ZSTD já estão presentes."
        return 0
    fi

    # RHEL/Rocky/Fedora: /usr/lib64 — Debian/Ubuntu: /usr/lib/x86_64-linux-gnu
    for src in /usr/lib64 /usr/lib/x86_64-linux-gnu /usr/lib; do
        for lib in "${ZSTD_LIBS[@]}"; do
            if [ -e "$src/$lib" ] && [ ! -e "$TARGET_DIR/$lib" ]; then
                echo "   Copiando $src/$lib -> $TARGET_DIR/"
                cp -fL "$src/$lib" "$TARGET_DIR/"
                copied=1
            fi
        done
    done

    if [ "$copied" -eq 0 ]; then
        echo "[AVISO] libzstd não encontrada no sistema. Instale 'libzstd-devel' (RHEL) ou 'libzstd-dev' (Ubuntu)."
        return 0
    fi

    chmod 755 "$TARGET_DIR"/libzstd* 2>/dev/null || true
    ls -l "$TARGET_DIR"/libzstd* || true
    echo " Bibliotecas ZSTD garantidas em: $TARGET_DIR"
}


#----------------------------------------------------------------------------------------
#                     CPU RESOURCE MANAGEMENT
#  JOBS=N (ou --jobs N) força o número de núcleos.
#----------------------------------------------------------------------------------------
cpu_resource(){
    USE_ALL_CORES=${USE_ALL_CORES:-false}
    export CPU_CORE=$(nproc)
    echo "================================================================"
    echo "                CPU RESOURCE MANAGEMENT                         "
    echo "-- TOTAL AVAILABLE CPU CORES: $CPU_CORE"
    CPU_CORE_LIMIT=8

    if [ -n "${JOBS:-}" ]; then
        CPU_HALF_EVEN=$JOBS
        echo "USING $JOBS CORES (definido por --jobs/JOBS)"
    elif [ "$USE_ALL_CORES" = true ]; then
        CPU_HALF_EVEN=$CPU_CORE
        echo "USING ALL AVAILABLE CORES AS CONFIGURED"
    else
        CPU_HALF=$((CPU_CORE / 2))
        CPU_HALF_EVEN=$((CPU_HALF - (CPU_HALF % 2)))
        if [ "$CPU_CORE" -le "$CPU_CORE_LIMIT" ]; then
            CPU_HALF_EVEN=2
            echo "LOW-CORE SYSTEM DETECTED – FORCING USAGE OF 2 CORES ONLY"
        fi
    fi
    [ "$CPU_HALF_EVEN" -ge 1 ] 2>/dev/null || CPU_HALF_EVEN=1
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
        exit 1
    fi

    echo "--- Compiladores Seriais GNU (base) ---"
    for cmd in gcc g++ gfortran; do
        if command -v "$cmd" >/dev/null 2>&1; then
            path_cmd=$(command -v "$cmd")
            echo "  [OK] $cmd encontrado -> $path_cmd"
            if is_from_conda "$path_cmd"; then
                echo "    [ALERTA] $cmd está vindo de um ambiente CONDA: $path_cmd"
                echo "             Para compilar WRF/MPAS, use os compiladores do sistema (ex.: /usr/bin/gcc)."
            fi
        else
            echo "  [!!] $cmd NÃO encontrado (CRÍTICO se você for usar GNU)"
        fi
    done

    echo "--- Compiladores Intel (classic / oneAPI) ---"
    intel_found=0
    for cmd in icc icpc ifort icx icpx ifx; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "  [OK] $cmd encontrado -> $(command -v "$cmd")"
            intel_found=1
        fi
    done
    [[ "$intel_found" -eq 0 ]] && echo "  [--] Nenhum compilador Intel encontrado no PATH."

    echo "--- Compiladores NVIDIA (NVHPC) ---"
    nvidia_found=0
    for cmd in nvc nvc++ nvfortran; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "  [OK] $cmd encontrado -> $(command -v "$cmd")"
            nvidia_found=1
        fi
    done
    [[ "$nvidia_found" -eq 0 ]] && echo "  [--] Nenhum compilador NVIDIA (NVHPC) encontrado no PATH."

    if [ "$GNU_MPI" -eq 0 ]; then
        echo "--- Compiladores Paralelos (MPI do sistema) ---"
        for cmd in mpicc mpicxx mpif90 mpifort; do
            if command -v "$cmd" >/dev/null 2>&1; then
                path_cmd=$(command -v "$cmd")
                echo "  [OK] $cmd encontrado -> $path_cmd"
                if is_from_conda "$path_cmd"; then
                    echo "    [ALERTA] $cmd vem do CONDA; costuma causar problemas de linkedição."
                fi
            else
                echo "  [--] $cmd NÃO encontrado no PATH atual."
            fi
        done
    else
        echo "    (Modo $GNU_MPI compilará seu próprio MPICH. Ignorando MPI do sistema.)"
    fi
    echo "=================================================================="
    return 0
}


Toolchain_check_GNU(){
    for t in gcc g++ gfortran; do
        command -v "$t" >/dev/null || { echo "ERROR: $t not found."; exit 1; }
    done
    GCC_MAJOR=$(gcc -dumpfullversion -dumpversion | cut -d. -f1)
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
        #  MODO 0 — Compiladores do sistema (não recomendado em ambiente miniconda)
        0)
            echo ">> MODO 0: Configuração existente no sistema"
            export CC=$(command -v gcc)
            export CXX=$(command -v g++)
            export FC=$(command -v gfortran)
            export MPICC=$(command -v mpicc || true)
            export MPICXX=$(command -v mpicxx || true)
            export MPIFC=$(command -v mpifort || command -v mpif90 || true)
            ;;
        #  MODO 1 — Compiladores GNU normais
        1)
            echo ">> MODO 1: GNU padrão (gcc/gfortran + mpicc/mpifort)"
            export CC=$(command -v gcc)
            export CXX=$(command -v g++)
            export FC=$(command -v gfortran)
            mpi_setup
            ;;
        #  MODO 2 — Usar Wrappers MPI como compiladores
        2)
            echo ">> MODO 2: Usando MPI como compiladores (mpicc/mpifort)"
            mpi_setup
            export CC=$MPICC
            export CXX=$MPICXX
            export FC=$MPIFC
            ;;
        *)
            echo "[ERRO] Modo inválido: $mode"
            echo "Use 0 (sistema), 1 (GNU) ou 2 (GNU via MPI wrappers)."
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
    echo "   LD_LIBRARY_PATH   = $LD_LIBRARY_PATH"
    echo "   LIBS_DIR          = $LIBS_DIR  (onde tudo acontece)"
    echo "   INSTALL_DIR       = $INSTALL_DIR"
    echo "   DOWNLOADS         = $DOWNLOADS"
    echo "   MODEL_DIR_INSTALL = $MODEL_DIR_INSTALL"
    echo "========================================="
}


# --------------------------------------------------------------------
# MPI: selecionar wrappers (Apenas MPICH)
# --------------------------------------------------------------------
mpi_setup() {
    export MPI_FLAVOR="none"

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
        # Fallback: MPI do sistema/ambiente — recusa MPI do Conda
        CURRENT_MPICC=$(command -v mpicc || true)
        if [[ "$CURRENT_MPICC" == *"conda"* ]] || [[ "$CURRENT_MPICC" == *"miniconda"* ]]; then
            echo "ERRO: MPI do Conda detectado ($CURRENT_MPICC)."
            echo "      Rode 'conda deactivate' ou instale o MPICH com --libs mpich."
            exit 1
        fi

        export MPIFC="$(command -v mpifort || command -v mpif90 || true)"
        export MPICC="$(command -v mpicc   || true)"
        export MPICXX="$(command -v mpicxx || true)"
        # CORRIGIDO: antes era MPIF90="$MPIF90" (ficava vazio)
        export MPIF77="$MPIFC" ; export MPIF90="$MPIFC"
        export MPI_FLAVOR="mpich(PATH)"
    fi
    return 0
}


Detect_system_distribution_and_update(){
#-------------------------------------------------------------------------------------
# Step [0] - Update system and install required development packages
# (ativado com --update-system)
# Supported distributions: RHEL-based (Rocky, AlmaLinux, CentOS, Fedora), Ubuntu, Debian
#-------------------------------------------------------------------------------------
    if [ -f /etc/os-release ]; then
        DISTRO_ID=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    else
        echo "ERROR: Cannot determine Linux distribution. '/etc/os-release' not found."
        exit 1
    fi

    echo ">>> [0] Detected system: $DISTRO_ID"
    echo ">>> Updating system and installing required packages..."

    case "$DISTRO_ID" in
        rhel|rocky|almalinux|fedora|centos)
            sudo dnf update -y
            sudo dnf install -y gcc gcc-gfortran gcc-c++ libtool \
                                automake autoconf make m4 cmake patch curl tar unzip wget xz bzip2
            sudo dnf install -y dnf-plugins-core
            [ "$DISTRO_ID" != fedora ] && sudo dnf config-manager --set-enabled crb || true
            [ "$DISTRO_ID" != fedora ] && sudo dnf install -y epel-release || true   # necessário p/ ncl/ncview
            sudo dnf makecache
            sudo dnf install -y libstdc++-static libzstd-devel ruby          # ICON
            sudo dnf install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel || true
            sudo dnf install -y csh ksh tcsh time git bash-completion
            sudo dnf install -y ncview ncl libX11-devel libXaw-devel libXmu-devel libXt-devel \
                || echo "[AVISO] ncview/ncl não instalados (verifique o EPEL)."
            sudo dnf groupinstall -y "Development Tools"
            ;;
        ubuntu|debian)
            sudo apt update -y
            sudo apt upgrade -y
            sudo apt install -y build-essential gfortran g++ libtool \
                                automake autoconf make m4 cmake patch curl tar unzip wget xz-utils bzip2 libzstd-dev
            sudo apt install -y default-jdk || true
            sudo apt install -y csh ksh tcsh time git bash-completion
            # Libs do sistema (usadas só no modo 0). libjasper-dev foi REMOVIDO:
            # não existe no Ubuntu 22.04+ e derrubava a linha inteira do apt.
            sudo apt install -y zlib1g-dev libpng-dev libhdf5-dev libnetcdf-dev libnetcdff-dev \
                || echo "[AVISO] algumas libs do sistema não foram instaladas."
            sudo apt install -y ncview ncl-ncarg libx11-dev libxaw7-dev libxmu-dev libxt-dev \
                || echo "[AVISO] ncview/ncl não instalados."
            ;;
        *)
            echo "ERROR: Unsupported or unknown Linux distribution: '$DISTRO_ID'"
            exit 1
            ;;
    esac

    pause_step "System update complete. Press ENTER to continue..."
}
