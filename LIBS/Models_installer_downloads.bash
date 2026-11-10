#!/bin/bash
#-------------------------------------------------------------------------------
#
#                 MÓDULO DE DOWNLOADS (URLs, espelhos e verificação)
#
#  Todas as URLs do instalador ficam AQUI. As funções install_* chamam:
#
#       fetch <pacote>        -> baixa (ou reaproveita) o arquivo em $DOWNLOADS
#                                e define FETCHED_FILE com o nome do arquivo.
#       extract_archive <arq> -> extrai .tar.gz/.tgz/.tar.xz/.tar.bz2/.zip
#       check_downloads       -> testa se todos os links estão ativos.
#
#  Cada pacote tem uma lista de fontes "arquivo_local|url". A primeira é a
#  oficial; as seguintes são espelhos usados se a primeira falhar.
#-------------------------------------------------------------------------------

# Repositórios git (clonados, não baixados como tarball)
GIT_URL_AEC="${GIT_URL_AEC:-https://gitlab.dkrz.de/k202009/libaec.git}"
GIT_URL_WRF="${GIT_URL_WRF:-https://github.com/wrf-model/WRF.git}"
GIT_URL_WPS="${GIT_URL_WPS:-https://github.com/wrf-model/WPS.git}"
GIT_URL_MPAS="${GIT_URL_MPAS:-https://github.com/MPAS-Dev/MPAS-Model.git}"

# Pacotes que têm tarball (ordem usada pelo check_downloads)
DOWNLOAD_PACKAGES=(mpich zlib libpng jasper hdf5 pnetcdf netcdf_c netcdf_fortran pio openjpeg eccodes cdi openblas libxml2)

#-------------------------------------------------------------------------------
# pkg_sources <pacote>  -> preenche o array PKG_SOURCES ("arquivo|url" ...)
#-------------------------------------------------------------------------------
pkg_sources() {
    PKG_SOURCES=()
    case "$1" in
        mpich)
            PKG_SOURCES=(
              "mpich-$Mpich_Version.tar.gz|https://www.mpich.org/static/downloads/$Mpich_Version/mpich-$Mpich_Version.tar.gz"
              "mpich-$Mpich_Version.tar.gz|https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz" ) ;;
        zlib)
            # zlib.net só mantém a versão atual na raiz; as antigas vão para /fossils
            PKG_SOURCES=(
              "zlib-$Zlib_Version.tar.gz|https://www.zlib.net/zlib-$Zlib_Version.tar.gz"
              "zlib-$Zlib_Version.tar.gz|https://www.zlib.net/fossils/zlib-$Zlib_Version.tar.gz"
              "zlib-$Zlib_Version.tar.gz|https://github.com/madler/zlib/releases/download/v$Zlib_Version/zlib-$Zlib_Version.tar.gz" ) ;;
        libpng)
            PKG_SOURCES=(
              "libpng-$Libpng_Version.tar.gz|https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz"
              "libpng-$Libpng_Version.tar.gz|https://github.com/pnggroup/libpng/archive/refs/tags/v$Libpng_Version.tar.gz" ) ;;
        jasper)
            # O site antigo (uvic) distribui .zip; o espelho da UCAR (tutorial do WRF) distribui .tar.gz
            PKG_SOURCES=(
              "jasper-$Jasper_Version.zip|https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip"
              "jasper-$Jasper_Version.tar.gz|https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-$Jasper_Version.tar.gz" ) ;;
        hdf5)
            PKG_SOURCES=(
              "hdf5-$HDF5_Version.tar.gz|https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-$HDF5_Version.tar.gz" ) ;;
        pnetcdf)
            PKG_SOURCES=(
              "pnetcdf-$Pnetcdf_Version.tar.gz|https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz" ) ;;
        netcdf_c)
            PKG_SOURCES=(
              "netcdf-c-$Netcdf_C_Version.tar.gz|https://downloads.unidata.ucar.edu/netcdf-c/$Netcdf_C_Version/netcdf-c-$Netcdf_C_Version.tar.gz"
              "netcdf-c-$Netcdf_C_Version.tar.gz|https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz" ) ;;
        netcdf_fortran)
            PKG_SOURCES=(
              "netcdf-fortran-$Netcdf_Fortran_Version.tar.gz|https://downloads.unidata.ucar.edu/netcdf-fortran/$Netcdf_Fortran_Version/netcdf-fortran-$Netcdf_Fortran_Version.tar.gz"
              "netcdf-fortran-$Netcdf_Fortran_Version.tar.gz|https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz" ) ;;
        pio)
            PKG_SOURCES=(
              "pio$Pio_Version.tar.gz|https://github.com/NCAR/ParallelIO/archive/refs/tags/pio$Pio_Version.tar.gz" ) ;;
        openjpeg)
            PKG_SOURCES=(
              "v$jpeg_version.tar.gz|https://github.com/uclouvain/openjpeg/archive/refs/tags/v$jpeg_version.tar.gz" ) ;;
        eccodes)
            PKG_SOURCES=(
              "eccodes-$ecc_version-Source.tar.gz|https://confluence.ecmwf.int/download/attachments/45757960/eccodes-$ecc_version-Source.tar.gz" ) ;;
        cdi)
            PKG_SOURCES=(
              "libcdi-cdi-$Cdi_Version.tar.gz|https://gitlab.dkrz.de/mpim-sw/libcdi/-/archive/cdi-$Cdi_Version/libcdi-cdi-$Cdi_Version.tar.gz" ) ;;
        openblas)
            PKG_SOURCES=(
              "OpenBLAS-$OpenBlas_Version.tar.gz|https://github.com/OpenMathLib/OpenBLAS/archive/refs/tags/v$OpenBlas_Version.tar.gz" ) ;;
        libxml2)
            PKG_SOURCES=(
              "libxml2-$LIBXML2_VERSION.tar.xz|https://download.gnome.org/sources/libxml2/$libxml2_version/libxml2-$LIBXML2_VERSION.tar.xz" ) ;;
        *)
            echo "[ERRO] pacote desconhecido no módulo de downloads: $1" >&2
            return 1 ;;
    esac
}

#-------------------------------------------------------------------------------
# validate_archive <arquivo>  -> 0 se o arquivo está íntegro
#-------------------------------------------------------------------------------
validate_archive() {
    local f="$1"
    [ -s "$f" ] || return 1
    case "$f" in
        *.zip)             unzip -tq "$f" >/dev/null 2>&1 ;;
        *.tar.gz|*.tgz)    tar_clean -tzf "$f" >/dev/null 2>&1 ;;
        *.tar.xz)          tar_clean -tJf "$f" >/dev/null 2>&1 ;;
        *.tar.bz2)         tar_clean -tjf "$f" >/dev/null 2>&1 ;;
        *)                 return 0 ;;
    esac
}

#-------------------------------------------------------------------------------
# extract_archive <arquivo>  -> extrai no diretório atual
#-------------------------------------------------------------------------------
extract_archive() {
    local f="$1"
    case "$f" in
        *.zip)             run_clean unzip -q -o "$f" ;;
        *.tar.gz|*.tgz)    tar_clean -xzf "$f" ;;
        *.tar.xz)          tar_clean -xJf "$f" ;;
        *.tar.bz2)         tar_clean -xjf "$f" ;;
        *) echo "[ERRO] formato não suportado: $f" >&2; return 1 ;;
    esac
}

#-------------------------------------------------------------------------------
# _download <url> <destino>  -> usa wget ou curl, com novas tentativas
#-------------------------------------------------------------------------------
_download() {
    local url="$1" out="$2"
    if command -v wget >/dev/null 2>&1; then
        wget -q --tries=3 --timeout=60 -O "$out" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --connect-timeout 60 -o "$out" "$url"
    else
        echo "[ERRO] nem wget nem curl estão instalados." >&2
        return 1
    fi
}

#-------------------------------------------------------------------------------
# fetch <pacote>
#   Reaproveita o arquivo já baixado (se íntegro), senão tenta cada fonte.
#   Resultado: FETCHED_FILE=<nome do arquivo em $DOWNLOADS>
#   FORCE_DOWNLOAD=1 força baixar de novo.
#-------------------------------------------------------------------------------
fetch() {
    local pkg="$1" entry file url tmp
    FETCHED_FILE=""
    pkg_sources "$pkg" || return 1
    mkdir -p "$DOWNLOADS"

    # 1) Já existe um arquivo válido de alguma das fontes?
    if [ "${FORCE_DOWNLOAD:-0}" -ne 1 ]; then
        for entry in "${PKG_SOURCES[@]}"; do
            file="${entry%%|*}"
            if validate_archive "$DOWNLOADS/$file"; then
                echo ">> [$pkg] usando arquivo já baixado: $DOWNLOADS/$file"
                FETCHED_FILE="$file"
                return 0
            fi
        done
    fi

    # 2) Baixa, tentando as fontes em ordem
    for entry in "${PKG_SOURCES[@]}"; do
        file="${entry%%|*}"; url="${entry#*|}"
        tmp="$DOWNLOADS/.$file.part"
        echo ">> [$pkg] baixando: $url"
        if _download "$url" "$tmp" && validate_archive "$tmp"; then
            mv -f "$tmp" "$DOWNLOADS/$file"
            FETCHED_FILE="$file"
            echo ">> [$pkg] OK -> $DOWNLOADS/$file"
            return 0
        fi
        echo "   [AVISO] falhou ou arquivo inválido: $url" >&2
        rm -f "$tmp" 2>/dev/null || true
    done

    echo "[ERRO] [$pkg] não foi possível baixar de nenhuma fonte." >&2
    echo "       Baixe manualmente e coloque em $DOWNLOADS um destes arquivos:" >&2
    for entry in "${PKG_SOURCES[@]}"; do echo "         ${entry%%|*}  <- ${entry#*|}" >&2; done
    return 1
}

#-------------------------------------------------------------------------------
# _url_alive <url>  -> imprime o código HTTP (200/206 = ativo)
#-------------------------------------------------------------------------------
_url_alive() {
    local url="$1"
    if command -v curl >/dev/null 2>&1; then
        # Range 0-0: baixa só 1 byte (alguns servidores rejeitam HEAD)
        curl -sL -r 0-0 -o /dev/null -w '%{http_code}' --max-time 30 "$url"
    else
        if wget -q --spider --timeout=30 "$url"; then echo 200; else echo 000; fi
    fi
}

#-------------------------------------------------------------------------------
# check_downloads  -> testa todos os links e repositórios git
#-------------------------------------------------------------------------------
check_downloads() {
    local ok=0 fail=0 pkg entry url code st name repo tag any
    echo "=================================================================="
    echo " VERIFICAÇÃO DOS LINKS DE DOWNLOAD"
    echo "=================================================================="
    printf "%-15s %-5s %-6s %s\n" "PACOTE" "HTTP" "STATUS" "URL"
    for pkg in "${DOWNLOAD_PACKAGES[@]}"; do
        pkg_sources "$pkg"
        any=0
        for entry in "${PKG_SOURCES[@]}"; do
            url="${entry#*|}"
            code=$(_url_alive "$url")
            if [[ "$code" == 200 || "$code" == 206 ]]; then st="\033[0;32mOK\033[0m"; any=1
            else st="\033[0;31mFALHA\033[0m"; fi
            printf "%-15s %-5s %-6b %s\n" "$pkg" "$code" "$st" "$url"
            pkg="  +espelho"
        done
        if [ "$any" -eq 1 ]; then ok=$((ok+1)); else fail=$((fail+1)); fi
    done
    echo
    local gits=( "AEC|$GIT_URL_AEC|" "WRF|$GIT_URL_WRF|${WRF_VERSION:-}" "WPS|$GIT_URL_WPS|${WPS_VERSION:-}" ) v
    for v in ${MPAS_VERSION//,/ }; do
        v="${v#v}"
        case "$v" in
            latest|master) gits+=( "MPAS($v)|$GIT_URL_MPAS|" ) ;;
            *)             gits+=( "MPAS|$GIT_URL_MPAS|v$v" ) ;;
        esac
    done
    for entry in "${gits[@]}"; do
        IFS='|' read -r name repo tag <<<"$entry"
        if [ -n "$tag" ]; then
            timeout 60 git ls-remote --tags --heads "$repo" "$tag" 2>/dev/null | grep -q . && st=OK || st=FALHA
        else
            timeout 60 git ls-remote --heads "$repo" >/dev/null 2>&1 && st=OK || st=FALHA
        fi
        if [ "$st" = OK ]; then ok=$((ok+1)); else fail=$((fail+1)); fi
        printf "%-15s %-5s %-6s %s %s\n" "$name" "git" "$st" "$repo" "$tag"
    done
    echo
    echo "Resumo: $ok pacotes OK, $fail com falha (um pacote conta como OK se ao menos uma fonte responder)."
    [ "$fail" -eq 0 ]
}
