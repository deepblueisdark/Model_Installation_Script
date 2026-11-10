# 🌎 Automated Atmospheric Model Installation Script (WRF/MPAS/ICON)

## 🧾 Descrição

O script instalador automatizado de modelos atmosféricos (WRF/MPAS/ICON) foi desenvolvido para simplificar e padronizar o processo de instalação, configuração e compilação de modelos numéricos de previsão do tempo e clima em ambientes Linux de alto desempenho (HPC).

Ele automatiza todas as etapas necessárias para preparar o ambiente científico, desde a detecção do sistema operacional e compiladores disponíveis até a compilação completa dos modelos.

Principais funcionalidades:

- Detecção automática do sistema operacional (Rocky Linux, AlmaLinux, Fedora, Ubuntu, Debian);
- Configuração dinâmica de compiladores e variáveis de ambiente (PATH, LD_LIBRARY_PATH, NETCDF, HDF5...);
- Download (com espelhos alternativos e verificação de integridade), extração e compilação das bibliotecas científicas (MPICH, Zlib, LibPNG, Jasper, HDF5, PnetCDF, NetCDF-C/Fortran, PIO, OpenJPEG, LibXML2, OpenBLAS, AEC, ecCodes, CDI);
- Compilação de WRF, WPS e MPAS-A;
- Seleção do que instalar por **flags** de linha de comando, com **dependências resolvidas automaticamente**;
- O que já está instalado é **pulado** — dá para rodar de novo depois de uma falha;
- **Um log por etapa** e resumo final (OK / FALHA / PULADO);
- Modo não interativo (incluindo o `./configure` do WRF/WPS), ideal para clusters HPC.

---

## 🚀 Como usar

```bash
git clone https://github.com/deepblueisdark/Model_Installation_Script.git
cd Model_Installation_Script

./Models_installer_main.bash --help        # todas as opções
./Models_installer_main.bash --dry-run     # mostra o plano sem compilar nada
./Models_installer_main.bash --check-downloads   # testa os links de download
```

Sem nenhuma flag, o script instala o que estiver em `DEFAULT_LIBS` e `DEFAULT_MODELS` (topo do `Models_installer_main.bash`).

### Exemplos

```bash
# MPAS completo (libs + modelo) usando 8 núcleos
./Models_installer_main.bash --libs mpas --models mpas --jobs 8

# MPAS 8.0.1 e a versão mais recente, cada uma na sua pasta
./Models_installer_main.bash --models mpas --mpas-version 8.0.1,latest

# WRF + WPS sem nenhuma pergunta (opção 34 = GNU dmpar; WPS opção 3 = dmpar)
./Models_installer_main.bash --libs wrf --models wrf,wps --wrf-config 34 --wps-config 3

# Só as bibliotecas do ICON, tudo via wrappers MPI, em outro prefixo
./Models_installer_main.bash --mode 2 --prefix /opt/MODELS --libs icon --models none

# Reinstalar só o HDF5, mostrando a compilação na tela
./Models_installer_main.bash --libs hdf5 --models none --no-deps --force --verbose

# Baixar tudo antes (ex.: para depois compilar numa máquina sem internet)
./Models_installer_main.bash --libs all --download-only

# Ver o que já está instalado
./Models_installer_main.bash --list
```

### Flags

| Flag | Descrição |
|---|---|
| `-l, --libs LISTA` | Bibliotecas (vírgula). Nomes ou presets `wrf`, `mpas`, `icon`, `all`, `none` |
| `-m, --models LISTA` | Modelos: `wrf`, `wps`, `mpas`, `all`, `none` |
| `-x, --skip LISTA` | Remove itens do plano |
| `--no-deps` | Não adiciona dependências automaticamente |
| `-f, --force` | Reinstala mesmo o que já existe |
| `--mode 0\|1\|2` | Modo de compilação (tabela abaixo) |
| `-p, --prefix DIR` | Diretório base (padrão `$HOME/MODELS`) |
| `-d, --downloads DIR` | Pasta dos tarballs (padrão `$HOME/Downloads`) |
| `-j, --jobs N` / `--all-cores` | Núcleos para compilar (padrão: metade) |
| `--mpas-version V` | `8.0.1` (padrão), `X.Y.Z`, `latest` (última versão lançada) ou `master` (desenvolvimento). Aceita lista: `8.0.1,latest` instala as duas lado a lado (`MPAS-8.0.1/`, `MPAS-8.4.2/`...) |
| `--wrf-version TAG` / `--wps-version TAG` | Fixa a versão (ex.: `v4.6.1`). Padrão: mais recente |
| `--wrf-config N` / `--wrf-nest N` / `--wps-config N` | Respostas do `./configure` (sem menu) |
| `-n, --dry-run` | Mostra o plano e não compila |
| `-v, --verbose` | Mostra a compilação na tela (além do log) |
| `-k, --keep-going` | Continua nas próximas etapas se uma falhar |
| `--checks` | Executa os `make check` |
| `--prompt` | Pausa a cada etapa (modo debug) |
| `--update-system` | Atualiza o sistema e instala pacotes (dnf/apt, usa `sudo`) |
| `--check-downloads` | Só testa os links |
| `--download-only` | Só baixa os tarballs do plano |
| `--list` | Lista libs/modelos e o que já está instalado |

Todas as flags também podem ser passadas por variável de ambiente (ex.: `GNU_MPI=2 JOBS=8 ./Models_installer_main.bash`).

### Modos de compilação (`--mode`)

| Modo | Diretório | Descrição |
|---|---|---|
| `0` | `$PREFIX/GNU/SISTEM` | Compiladores e MPI do sistema (não recomendado com Conda ativo) |
| `1` (padrão) | `$PREFIX/GNU/SERIAL` | Libs compiladas em serial (gcc/gfortran) + MPICH próprio; PnetCDF e PIO em paralelo |
| `2` | `$PREFIX/GNU/MPICH` | Tudo compilado pelos wrappers do MPICH (HDF5/NetCDF paralelos) |

### Presets de bibliotecas

| Preset | Bibliotecas |
|---|---|
| `wrf` | mpich zlib libpng jasper hdf5 netcdf_c netcdf_fortran |
| `mpas` | preset `wrf` + pnetcdf pio |
| `icon` | mpich zlib libpng openjpeg jasper libxml2 openblas hdf5 netcdf_c netcdf_fortran aec eccodes cdi |
| `all` | todas |

### Logs e ambiente

- Cada etapa grava `$PREFIX/GNU/logs/<data_hora>/<etapa>.log`. Em caso de falha, as últimas linhas do log aparecem na tela.
- Ao final, é gerado `$LIBS_DIR/env.sh`. Para usar os modelos depois: `source $LIBS_DIR/env.sh`.

### Versões

As versões ficam no bloco do topo de `Models_installer_main.bash`. As URLs (com espelhos) ficam em `LIBS/Models_installer_downloads.bash`.

---

## 📁 Estrutura

```
Models_installer_main.bash          # versões, padrões e fluxo principal
check_downloads.sh                  # atalho para --check-downloads
check_geog_mpas.sh                  # valida os dados GEOG do MPAS-A
INIT/Models_installer_cli.bash      # flags, plano, dependências, logs, resumo
INIT/Models_installer_init.bash     # diretórios, CPU, compiladores, MPI, update do sistema
INIT/Models_installer_enviroment.bash  # variáveis de ambiente (NETCDF, HDF5, CPPFLAGS...)
INIT/Models_installer_functions.bash   # funções auxiliares
LIBS/Models_installer_downloads.bash   # URLs, espelhos, fetch, check_downloads
LIBS/Models_installer_libs.bash        # install_* das bibliotecas
MODELS/Models_installer_wrf.bash       # WRF e WPS
MODELS/Models_installer_MPAS.bash      # MPAS-A
```

---

## 🇺🇸 English

The **Automated Atmospheric Model Installation Script (WRF/MPAS/ICON)** streamlines and standardizes the installation and compilation of numerical weather and climate models on Linux HPC systems.

It detects the OS and compilers, downloads (with mirrors and integrity checks) and builds all required libraries (MPICH, Zlib, LibPNG, Jasper, HDF5, PnetCDF, NetCDF-C/Fortran, PIO, OpenJPEG, LibXML2, OpenBLAS, AEC, ecCodes, CDI), and compiles WRF, WPS and MPAS-A.

Quick start:

```bash
./Models_installer_main.bash --help
./Models_installer_main.bash --libs mpas --models mpas --jobs 8
./Models_installer_main.bash --libs wrf --models wrf,wps --wrf-config 34 --wps-config 3
```

Dependencies are resolved automatically, already-installed components are skipped (`--force` to rebuild), every step writes its own log, and a summary table is printed at the end. See the tables above for all flags, build modes and presets.

**Author:** Reginaldo Ventura de Sá — reginaldo.venturadesa@gmail.com
