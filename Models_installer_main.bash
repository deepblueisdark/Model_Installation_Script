#!/bin/bash
#-------------------------------------------------------------------------
#
#                   INSTALADOR DE MODELOS WRF. MAPS E ICON 
#
#
#--------------------------------------------------------------------------
#
# Autor: Reginaldo Ventura de Sà (reginadlo.venturadesa@gmail.com)
#
#---------------------------------------------------------------------------- 
#  Versão GNU: 10/4/2025 
#    
#
# TODO:
#  Direcionar as saídas das instalações para NULL. 
#
#
#
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Versões das bibliotecas e dos modelos.
# Ajuste as versões somente neste bloco.
#-------------------------------------------------------------------------------
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
export ecc_version="2.41.0"
export Aec_Version="1.0.6"
export Cdi_Version="2.5.3"
export Cdi_volume="30033"
export OpenBlas_Version="0.3.27"
export LIBXML2_VERSION="2.11.7"
export libxml2_version="2.11"
export MPAS_VERSION="8.0.1"

# Diretório base de instalação. Pode ser sobrescrito antes de executar o script.
export HOME_DIR="${HOME_DIR:-$HOME}"
export INSTALLATION_PATH="${INSTALLATION_PATH:-$HOME_DIR/MODELS}"
#
# export INSTALLATION_PATH="${INSTALLATION_PATH:-$HOME_DIR/REGIS/TESTE/MODELS}"
#
# Define o compialdor (defaul:GNU)
#    Não mexer!
#
export COMPILER=${COMPILER:-GNU}
#
#   GNU_MPI=0  : Busca Compialdores no sistema atual e/ou Miniconda 
#   Não recomendável!!!  
#
#   GNU_MPI=1  :  Utilizado para SMP mas  pode ser usado em DM_PAR
#                 Compilações são feita no modo serial (CC/gfortran)
#                 Exceto PIO e PNETCDF. 
#
#
#   GNU_MPI=2  :   Todas as biblioetcas são compiladas pelos wrappers do MPI. 
# 
#    
export GNU_MPI=${GNU_MPI:-1}
#
# SE =1 , a cada etapa pede  para pressioanr uma tecla. 
#         modo DEBUG
#
#  
export PROMPTOK=1
#
#  local dos downloads das bibliotecas. 
#
export DOWNLOADS=/home/regis/Downloads/
#
#  Modulo com as Funcoes de sistema e dos compialdores
#
source ./INIT/Models_installer_init.bash 
#
# Modulo com funções diversas 
#
source ./INIT/Models_installer_functions.bash
#
#  Modulo com as instalações das bibliotecas (em forma de funções) 
#
source ./LIBS/Models_installer_libs.bash
#
# Instalador do WRF e WPS e outras aplicações relacionadas. 
#
source ./MODELS/Models_installer_wrf.bash 
#
# Instalador do MPAS 
#
source ./MODELS/Models_installer_MPAS.bash
#
#  Veirfica qual distribuição e depois atualzia o sistema 
# 
#Detect_system_distribution_and_update 
#
#  Baseado na configuração, cria as variaveis ambientais 
#  LIBS_DIR, INSTALL_DIR e define  NETCDF, HDF, etc.. 
#
setup_install_libs_dir   ##sempre ativa!!! 
#
#  cria as variaveis ambientes. Sempre ativo!!!
#
source ./INIT/Models_installer_enviroment.bash
#
#  controla  uso dos processadores
#  nos processos de compilação 
#                   
export USE_ALL_CORES=${USE_ALL_CORES:-false}        ### usa metade de false. usa tudo se true.  
cpu_resource

#
# faz verificacao de compialdores
#
check_initial_compilers

#
# coisas do GNU
#
Toolchain_check_GNU

#
#  Processo de Instalação das bibliotecas 
#  
#
# MPICH  (obrigatorio para GNU_MPI=1 e GNU_MPI=2)
#
install_mpich
# 
#  Bibliotecas. Comente A biblioteca que não for necessária ou que já foi compilada=.]  
# 
#
#
#install_zlib              ## ZLIB  (WRF/MPAS/ICON)
#ensure_zstd_in_libs_dir   ## verificar libstd para compatibilidade NETCDF/HDF5
#install_libpng            ## OPENPNG  (WRF/MPAS/ICON)
#install_openjpeg          ## OPENJPG   (ICON)
#install_jasper            ## JASPER  (WRF/MPAS/ICON)
#install_libxml2           ## LIBXML2   (ICON)
#install_openblas          ## OPENBLAS  (ICON)
#install_hdf5              ## HDF5   (WRF/MPAS/ICON)
install_pnetcdf           ## PNETCDF   (WRF/MPAS/ICON)
#install_netcdf_c          ## NETCDF-C   (WRF/MPAS/ICON)
#install_netcdf_fortran    ## NETCDF-FORTRAN   (WRF/MPAS/ICON)
install_pio               ## PIO   (MPAS)
#install_aec               ## AEC   (ICON)
#install_eccodes           ## ECCODES  (ICON)
#install_cdi               ## CDI   (ICON)
#
# MODELOS
#
install_wrf               ### versão mais atual 
install_wps               ### versão mais atual 
install_MPAS_V801         ### versão 8.0.1 
#install_MPAS              ### versão mais atual (nem sempre funciona)
