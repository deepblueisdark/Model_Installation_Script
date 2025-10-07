🌎 Automated Atmospheric Model Installation Script (WRF/MPAS/ICON)
🧾 Descrição / Description
🇧🇷 Descrição em Português

O script instalador automatizado de modelos atmosféricos (WRF/MPAS/ICON) foi desenvolvido para simplificar e padronizar o processo de instalação, configuração e compilação de modelos numéricos de previsão do tempo e clima em ambientes Linux de alto desempenho (HPC).

Ele automatiza todas as etapas necessárias para preparar o ambiente científico, desde a detecção do sistema operacional e compiladores disponíveis, até a compilação completa dos modelos. O script é modular e flexível, permitindo ao usuário escolher entre diferentes compilações (serial ou paralela), bem como selecionar o compilador desejado (GNU, Intel ou NVIDIA) e o tipo de MPI (MPICH, Intel MPI, OpenMPI, etc.).

Entre as principais funcionalidades, estão:

Detecção automática do sistema operacional e arquitetura (Rocky Linux, Ubuntu, CentOS, etc.);

Configuração dinâmica de compiladores e variáveis de ambiente (PATH, LD_LIBRARY_PATH, OMP_STACKSIZE);

Download, extração e compilação automatizada das bibliotecas científicas necessárias (NetCDF, HDF5, Jasper, Zlib, LibPNG, PnetCDF, Eccodes, CDI, entre outras);

Suporte a múltiplas versões de cada modelo e biblioteca, com logs e verificações de sucesso em cada etapa;

Compilação completa dos modelos WRF, WPS, MPAS-A e ICON, com opções para MPI e OpenMP;

Testes automáticos de integridade e geração de logs de compilação (úteis para depuração e auditoria);

Modo não interativo, ideal para automação via crontab ou execução remota em clusters HPC.

O objetivo é fornecer um instalador padronizado, reprodutível e robusto, reduzindo erros humanos e garantindo consistência entre diferentes ambientes e servidores.

🇺🇸 English Description

The Automated Atmospheric Model Installation Script (WRF/MPAS/ICON) is designed to streamline and standardize the installation, configuration, and compilation process of numerical weather and climate models in high-performance computing (HPC) environments.

This script automates the entire setup workflow — from system and compiler detection to full model compilation. It is modular and flexible, allowing users to choose between serial and parallel builds, select preferred compilers (GNU, Intel, NVIDIA), and specify the MPI implementation (MPICH, Intel MPI, OpenMPI, etc.).

Key features include:

Automatic detection of operating system and architecture (Rocky Linux, Ubuntu, CentOS, etc.);

Dynamic configuration of compilers and environment variables (PATH, LD_LIBRARY_PATH, OMP_STACKSIZE);

Automated download, extraction, and build of all required scientific libraries (NetCDF, HDF5, Jasper, Zlib, LibPNG, PnetCDF, Eccodes, CDI, etc.);

Support for multiple versions of both models and libraries, with compilation logs and verification checks;

Full compilation of WRF, WPS, MPAS-A, and ICON models with MPI and OpenMP options;

Automated integrity tests and log generation for troubleshooting and reproducibility;

Non-interactive mode, enabling scheduled or remote installation on HPC clusters.

The goal is to provide a standardized, reproducible, and robust installer, minimizing human error and ensuring consistent model environments across different systems.
