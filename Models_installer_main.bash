#!/bin/bash
#-------------------------------------------------------------------------
#
#                   INSTALADOR DE MODELOS WRF, MPAS E ICON
#
#--------------------------------------------------------------------------
#
# Autor: Reginaldo Ventura de Sá (reginaldo.venturadesa@gmail.com)
#
#----------------------------------------------------------------------------
#  Versão GNU: 09/11/2026
#
#  Uso rápido:
#     ./Models_installer_main.bash --help
#     ./Models_installer_main.bash --libs mpas --models mpas --jobs 8
#     ./Models_installer_main.bash --dry-run          (mostra o plano)
#
#  Cada etapa grava um log próprio em $INSTALL_DIR/logs/<data>/<etapa>.log
#  e o que já está instalado é pulado (use --force para reinstalar).
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Versões das bibliotecas e dos modelos.
# Ajuste as versões somente neste bloco.
#-------------------------------------------------------------------------------
export HDF5_Version="1_12_2"
export Zlib_Version="1.4"
export Netcdf_C_Version="4.9.2"
export Netcdf_Fortran_Version="4.6.1"
export Mpich_Version="4.2.1"
export Libpng_Version="1.6.39"
export Jasper_Version="1.900.1"
export Pnetcdf_Version="1.12.3"
export Pio_Version="2_5_9"
export jpeg_version="2.5.3"
export ecc_version="2.41.0"
export Aec_Version="1.0.6"
export Cdi_Version="2.5.3"
export Cdi_volume="30033"
export OpenBlas_Version="0.3.27"
export LIBXML2_VERSION="2.11.7"
export libxml2_version="2.11"
export MPAS_VERSION="${MPAS_VERSION:-8.0.1}"     # X.Y.Z | latest | master | lista "8.0.1,latest" (--mpas-version)
export WRF_VERSION="${WRF_VERSION:-}"            # vazio = mais recente (--wrf-version v4.6.1)
export WPS_VERSION="${WPS_VERSION:-}"            # vazio = mais recente (--wps-version v4.6.0)

#-------------------------------------------------------------------------------
# O que instalar quando o script é executado SEM --libs / --models.
# (Dependências faltantes são adicionadas automaticamente; o que já
#  está instalado é pulado.)
#
#   Presets de libs: wrf | mpas | icon | all | none
#   Libs: mpich zlib zstd libpng openjpeg jasper libxml2 openblas hdf5
#         pnetcdf netcdf_c netcdf_fortran pio aec eccodes cdi
#   Modelos: wrf wps mpas
#-------------------------------------------------------------------------------
DEFAULT_LIBS="${DEFAULT_LIBS:-mpich,pnetcdf,pio}"
DEFAULT_MODELS="${DEFAULT_MODELS:-wrf,wps,mpas}"

# Diretório base de instalação. Pode ser sobrescrito (--prefix ou variável).
export HOME_DIR="${HOME_DIR:-$HOME}"
export INSTALLATION_PATH="${INSTALLATION_PATH:-$HOME_DIR/MODELS}"
#
# Define o compilador (default: GNU). Não mexer!
#
export COMPILER=${COMPILER:-GNU}
#
#   GNU_MPI=0  : Busca compiladores no sistema atual e/ou Miniconda. Não recomendável!!!
#   GNU_MPI=1  : Utilizado para SMP mas pode ser usado em DM_PAR.
#                Compilações são feitas no modo serial (CC/gfortran), exceto PIO e PNETCDF.
#   GNU_MPI=2  : Todas as bibliotecas são compiladas pelos wrappers do MPI.
#   (flag: --mode 0|1|2)
#
export GNU_MPI=${GNU_MPI:-1}
#
# PROMPTOK=1 pausa a cada etapa (modo DEBUG). Flag: --prompt
#
export PROMPTOK=${PROMPTOK:-0}
#
# Local dos downloads das bibliotecas. Flag: --downloads DIR
#
export DOWNLOADS="${DOWNLOADS:-$HOME_DIR/Downloads}"
#
# Núcleos: false = metade, true = todos. Flags: --jobs N / --all-cores
#
export USE_ALL_CORES=${USE_ALL_CORES:-false}

#-------------------------------------------------------------------------------
#  Módulos (caminhos relativos à pasta do script: pode ser chamado de qualquer lugar)
#-------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/INIT/Models_installer_functions.bash"   # funções diversas
source "$SCRIPT_DIR/INIT/Models_installer_init.bash"        # sistema e compiladores
source "$SCRIPT_DIR/INIT/Models_installer_cli.bash"         # flags, plano e etapas
source "$SCRIPT_DIR/LIBS/Models_installer_downloads.bash"   # URLs e downloads
source "$SCRIPT_DIR/LIBS/Models_installer_libs.bash"        # bibliotecas
source "$SCRIPT_DIR/MODELS/Models_installer_wrf.bash"       # WRF e WPS
source "$SCRIPT_DIR/MODELS/Models_installer_MPAS.bash"      # MPAS

#-------------------------------------------------------------------------------
#  1) Flags
#-------------------------------------------------------------------------------
parse_args "$@"

# Ações que não precisam de diretórios nem compiladores
if [ "$ACTION" = "check-downloads" ]; then
    check_downloads
    exit $?
fi

#-------------------------------------------------------------------------------
#  2) Diretórios e ambiente (sempre ativos)
#-------------------------------------------------------------------------------
setup_install_libs_dir || exit 1
source "$SCRIPT_DIR/INIT/Models_installer_enviroment.bash"
export LOG_DIR="${LOG_DIR:-$INSTALL_DIR/logs/$(date +%Y%m%d_%H%M%S)}"

build_plan

if [ "$ACTION" = "list" ]; then
    list_status
    exit 0
fi

print_plan

if [ "$ACTION" = "download-only" ]; then
    download_plan
    exit "$FAILED"
fi

#-------------------------------------------------------------------------------
#  3) Sistema, CPU e compiladores
#-------------------------------------------------------------------------------
if [ "$UPDATE_SYSTEM" -eq 1 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then echo ">>> [dry-run] Detect_system_distribution_and_update"
    else Detect_system_distribution_and_update; fi
fi

cpu_resource
check_initial_compilers
Toolchain_check_GNU

#-------------------------------------------------------------------------------
#  4) Instalação (bibliotecas e depois modelos, na ordem do plano)
#-------------------------------------------------------------------------------
[ "$DRY_RUN" -eq 1 ] || mkdir -p "$LOG_DIR"

START_ALL=$SECONDS
run_plan
print_summary
echo "   Tempo total: $(_fmt_time $((SECONDS - START_ALL)))"

[ "$FAILED" -eq 0 ] && write_env_file
exit "$FAILED"
