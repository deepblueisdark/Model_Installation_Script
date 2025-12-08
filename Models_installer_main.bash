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
#
#    Define o compialdor (defaul:GNU)
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
export PROMPTOK=0
#
#  local dos downloads das bibliotecas. 
#
export DOWNLOADS=/home/regis/Downloads/
#
#  Modulo com as Funcoes de sistema e dos compialdores
#
source ./Models_installer_init.bash 
#
# Modulo com funções diversas 
#
source Models_installer_functions.bash
#
#  Modulo com as instalações das bibliotecas (em forma de funções) 
#
source Models_installer_libs.bash
#
# Instalador do WRF e WPS e outras aplicações relacionadas. 
#
source Models_installer_wrf.bash 
#
# Instalador do MPAS 
#
source Models_installer_MPAS.bash
#
#  Veirfica qual distribuição e depois atualzia o sistema 
# 
Detect_system_distribution_and_update 
#
#  Baseado na configuração, cria as variaveis ambientais 
#  LIBS_DIR, INSTALL_DIR e define  NETCDF, HDF, etc.. 
#
setup_install_libs_dir   ##sempre ativa!!! 
#
#  cria as variaveis ambientes. Sempre ativo!!!
#
source Models_installer_enviroment.bash
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
install_zlib              ## ZLIB  (WRF/MPAS/ICON)
ensure_zstd_in_libs_dir   ## verificar libstd para compatibilidade NETCDF/HDF5
install_libpng            ## OPENPNG  (WRF/MPAS/ICON)
install_openjpeg          ## OPENJPG   (ICON)
install_jasper            ## JASPER  (WRF/MPAS/ICON)
install_libxml2           ## LIBXML2   (ICON)
install_openblas          ## OPENBLAS  (ICON)
install_hdf5              ## HDF5   (WRF/MPAS/ICON)
install_pnetcdf           ## PNETCDF   (WRF/MPAS/ICON)
install_netcdf_c          ## NETCDF-C   (WRF/MPAS/ICON)
install_netcdf_fortran    ## NETCDF-FORTRAN   (WRF/MPAS/ICON)
install_pio               ## PIO   (MPAS)
install_aec               ## AEC   (ICON)
install_eccodes           ## ECCODES  (ICON)
install_cdi               ## CDI   (ICON)
#
# MODELOS
#
install_wrf               ### versão mais atual 
install_wps               ### versão mais atual 
install_MPAS_V801         ### versão 8.0.1 
#install_MPAS              ### versão mais atual (nem sempre funciona)