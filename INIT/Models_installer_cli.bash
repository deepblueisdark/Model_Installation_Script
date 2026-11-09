#!/bin/bash
#-------------------------------------------------------------------------------
#
#         LINHA DE COMANDO (flags), PLANO DE INSTALAÇÃO E EXECUÇÃO POR ETAPAS
#
#   - parse_args        : lê as flags
#   - build_plan        : expande presets, resolve dependências, ordena
#   - run_plan          : executa cada etapa com log próprio (run_step)
#   - print_summary     : tabela final OK / FALHA / PULADO
#
#-------------------------------------------------------------------------------

# Ordem canônica de instalação (dependências sempre antes)
LIB_ORDER=(mpich zlib zstd libpng openjpeg jasper libxml2 openblas hdf5 pnetcdf netcdf_c netcdf_fortran pio aec eccodes cdi)
MODEL_ORDER=(wrf wps mpas)

# Valores padrão das flags (podem vir do ambiente)
DRY_RUN=${DRY_RUN:-0}
FORCE=${FORCE:-0}
NO_DEPS=${NO_DEPS:-0}
KEEP_GOING=${KEEP_GOING:-0}
VERBOSE=${VERBOSE:-0}
RUN_CHECKS=${RUN_CHECKS:-0}
UPDATE_SYSTEM=${UPDATE_SYSTEM:-0}
ACTION="install"          # install | check-downloads | download-only | list

#-------------------------------------------------------------------------------
usage(){
cat <<EOF
Uso: ./Models_installer_main.bash [opções]

Sem opções, instala o que estiver em DEFAULT_LIBS / DEFAULT_MODELS no main
(atualmente: libs="$DEFAULT_LIBS"  modelos="$DEFAULT_MODELS").

SELEÇÃO
  -l, --libs LISTA        Bibliotecas, separadas por vírgula. Aceita nomes e presets:
                            presets: wrf | mpas | icon | all | none
                            nomes  : ${LIB_ORDER[*]}
                          Ex.: --libs mpas      --libs zlib,hdf5,netcdf
  -m, --models LISTA      Modelos: wrf, wps, mpas | all | none
  -x, --skip LISTA        Remove itens do plano (ex.: --skip jasper,wps)
      --no-deps           Não adiciona dependências automaticamente
  -f, --force             Reinstala mesmo o que já está instalado
                          (por padrão, o que já existe é PULADO)

CONFIGURAÇÃO
      --mode 0|1|2        0=sistema  1=GNU serial + MPICH (padrão)  2=tudo via wrappers MPI
  -p, --prefix DIR        Diretório base (INSTALLATION_PATH). Padrão: \$HOME/MODELS
  -d, --downloads DIR     Onde ficam os tarballs. Padrão: \$HOME/Downloads
  -j, --jobs N            Núcleos para compilar   (--all-cores usa todos)
      --mpas-version V    Ex.: 8.0.1 (padrão) | 8.2.2 | latest
      --wrf-version TAG   Ex.: v4.6.1  (padrão: mais recente)
      --wps-version TAG   Ex.: v4.6.0  (padrão: mais recente)
      --wrf-config N      Opção do ./configure do WRF (ex.: 34 = GNU dmpar). Sem isso, abre o menu.
      --wrf-nest N        Opção de aninhamento do WRF (padrão 1)
      --wps-config N      Opção do ./configure do WPS (ex.: 1 = serial, 3 = dmpar)

EXECUÇÃO
  -n, --dry-run           Mostra o plano sem compilar nada
  -v, --verbose           Mostra a compilação na tela (além do log)
  -k, --keep-going        Continua nas etapas seguintes se uma falhar
      --checks            Roda os 'make check' (mais lento)
      --prompt            Pausa a cada etapa (modo debug, antigo PROMPTOK=1)
      --update-system     Atualiza o sistema e instala pacotes (dnf/apt, usa sudo)

AÇÕES AVULSAS
      --check-downloads   Só testa se os links de download estão ativos
      --download-only     Só baixa os tarballs do plano (útil antes de ir p/ máquina offline)
      --list              Mostra libs/modelos e o que já está instalado
  -h, --help              Esta ajuda

EXEMPLOS
  ./Models_installer_main.bash --libs mpas --models mpas --jobs 8
  ./Models_installer_main.bash --libs wrf --models wrf,wps --wrf-config 34 --wps-config 3
  ./Models_installer_main.bash --mode 2 --prefix /opt/MODELS --libs all --models none
  ./Models_installer_main.bash --libs hdf5 --force --verbose
  ./Models_installer_main.bash --list
EOF
}

die(){ echo -e "\033[0;31m[ERRO]\033[0m $*" >&2; exit 1; }

#-------------------------------------------------------------------------------
parse_args(){
    local opt val
    while [ $# -gt 0 ]; do
        opt="$1"; val=""
        # aceita --opcao=valor
        if [[ "$opt" == --*=* ]]; then val="${opt#*=}"; opt="${opt%%=*}"; set -- "$opt" "$val" "${@:2}"; fi
        case "$opt" in
            -l|--libs)          [ -n "${2:-}" ] || die "$opt precisa de um valor"; CLI_LIBS="$2"; shift ;;
            -m|--models)        [ -n "${2:-}" ] || die "$opt precisa de um valor"; CLI_MODELS="$2"; shift ;;
            -x|--skip)          [ -n "${2:-}" ] || die "$opt precisa de um valor"; CLI_SKIP="$2"; shift ;;
            --no-deps)          NO_DEPS=1 ;;
            -f|--force)         FORCE=1 ;;
            --mode)             [[ "${2:-}" =~ ^[012]$ ]] || die "--mode aceita 0, 1 ou 2"; GNU_MPI="$2"; shift ;;
            -p|--prefix)        [ -n "${2:-}" ] || die "$opt precisa de um valor"; INSTALLATION_PATH="$2"; shift ;;
            -d|--downloads)     [ -n "${2:-}" ] || die "$opt precisa de um valor"; DOWNLOADS="$2"; shift ;;
            -j|--jobs)          [[ "${2:-}" =~ ^[0-9]+$ ]] && [ "$2" -ge 1 ] || die "--jobs precisa de um número"; JOBS="$2"; shift ;;
            --all-cores)        USE_ALL_CORES=true ;;
            --mpas-version)     [ -n "${2:-}" ] || die "$opt precisa de um valor"; MPAS_VERSION="${2#v}"; shift ;;
            --wrf-version)      [ -n "${2:-}" ] || die "$opt precisa de um valor"; WRF_VERSION="$2"; shift ;;
            --wps-version)      [ -n "${2:-}" ] || die "$opt precisa de um valor"; WPS_VERSION="$2"; shift ;;
            --wrf-config)       [[ "${2:-}" =~ ^[0-9]+$ ]] || die "--wrf-config precisa de um número"; WRF_CONFIG_OPT="$2"; shift ;;
            --wrf-nest)         [[ "${2:-}" =~ ^[0-9]+$ ]] || die "--wrf-nest precisa de um número"; WRF_NEST_OPT="$2"; shift ;;
            --wps-config)       [[ "${2:-}" =~ ^[0-9]+$ ]] || die "--wps-config precisa de um número"; WPS_CONFIG_OPT="$2"; shift ;;
            -n|--dry-run)       DRY_RUN=1 ;;
            -v|--verbose)       VERBOSE=1 ;;
            -k|--keep-going)    KEEP_GOING=1 ;;
            --checks)           RUN_CHECKS=1 ;;
            --prompt)           PROMPTOK=1 ;;
            --update-system)    UPDATE_SYSTEM=1 ;;
            --check-downloads)  ACTION="check-downloads" ;;
            --download-only)    ACTION="download-only" ;;
            --list)             ACTION="list" ;;
            -h|--help)          usage; exit 0 ;;
            *)                  usage; die "opção desconhecida: $opt" ;;
        esac
        shift
    done
    export GNU_MPI INSTALLATION_PATH DOWNLOADS JOBS USE_ALL_CORES MPAS_VERSION WRF_VERSION WPS_VERSION \
           WRF_CONFIG_OPT WRF_NEST_OPT WPS_CONFIG_OPT DRY_RUN FORCE VERBOSE RUN_CHECKS PROMPTOK
}

#-------------------------------------------------------------------------------
#  Normalização de nomes, presets e dependências
#-------------------------------------------------------------------------------
_norm(){ local s="${1,,}"; s="${s//-/_}"; echo "$s"; }

_in_list(){ local x="$1"; shift; local y; for y in "$@"; do [ "$x" = "$y" ] && return 0; done; return 1; }

# _lib_alias <nome> -> preenche _EXP com as libs (retorna 1 se desconhecido)
_lib_alias(){
    case "$1" in
        none|"") _EXP=() ;;
        all)     _EXP=("${LIB_ORDER[@]}") ;;
        wrf)     _EXP=(mpich zlib libpng jasper hdf5 netcdf_c netcdf_fortran) ;;
        mpas)    _EXP=(mpich zlib libpng jasper hdf5 pnetcdf netcdf_c netcdf_fortran pio) ;;
        icon)    _EXP=(mpich zlib libpng openjpeg jasper libxml2 openblas hdf5 netcdf_c netcdf_fortran aec eccodes cdi) ;;
        netcdf)  _EXP=(netcdf_c netcdf_fortran) ;;
        png)     _EXP=(libpng) ;;
        jpeg|openjpg) _EXP=(openjpeg) ;;
        *)       _in_list "$1" "${LIB_ORDER[@]}" || return 1
                 _EXP=("$1") ;;
    esac
}

_model_alias(){
    case "$1" in
        none|"") _EXP=() ;;
        all)     _EXP=("${MODEL_ORDER[@]}") ;;
        mpas_a|mpas_atmosphere) _EXP=(mpas) ;;
        *)       _in_list "$1" "${MODEL_ORDER[@]}" || return 1
                 _EXP=("$1") ;;
    esac
}

# expand_libs "lista" -> EXPANDED (array). Roda no shell principal para o 'die' funcionar.
expand_libs(){
    local item; EXPANDED=()
    for item in ${1//,/ }; do
        item="$(_norm "$item")"
        _lib_alias "$item" || die "biblioteca desconhecida: '$item'  (opções: ${LIB_ORDER[*]} | wrf mpas icon all none)"
        EXPANDED+=("${_EXP[@]}")
    done
}

expand_models(){
    local item; EXPANDED=()
    for item in ${1//,/ }; do
        item="$(_norm "$item")"
        _model_alias "$item" || die "modelo desconhecido: '$item'  (opções: wrf wps mpas | all none)"
        EXPANDED+=("${_EXP[@]}")
    done
}

# Dependências diretas de cada item (libs e modelos)
step_deps(){
    local mpi=""; [ "${GNU_MPI:-1}" -ge 1 ] && mpi="mpich"
    case "$1" in
        libpng)          echo zlib ;;
        hdf5)            echo zlib; [ "${GNU_MPI:-1}" -eq 2 ] && echo mpich ;;
        pnetcdf)         echo $mpi ;;
        netcdf_c)        echo hdf5 zlib; [ "${GNU_MPI:-1}" -eq 2 ] && echo pnetcdf ;;
        netcdf_fortran)  echo netcdf_c ;;
        pio)             echo netcdf_fortran pnetcdf $mpi ;;
        eccodes)         echo aec zlib ;;
        cdi)             echo eccodes netcdf_c ;;
        wrf)             echo netcdf_fortran $mpi ;;
        wps)             echo wrf jasper libpng zlib netcdf_fortran ;;
        mpas)            echo pio pnetcdf netcdf_fortran $mpi ;;
    esac
    return 0
}

# Arquivo que indica "já instalado" (vazio = sempre executa)
step_marker(){
    case "$1" in
        mpich)          echo "$LIBS_DIR/bin/mpifort" ;;
        zlib)           echo "$LIBS_DIR/lib/libz.a" ;;
        zstd)           echo "" ;;
        libpng)         echo "$LIBS_DIR/lib/libpng.a" ;;
        openjpeg)       echo "$LIBS_DIR/lib/libopenjp2.a" ;;
        jasper)         echo "$LIBS_DIR/lib/libjasper.a" ;;
        libxml2)        echo "$LIBS_DIR/lib/libxml2.a" ;;
        openblas)       echo "$LIBS_DIR/lib/libopenblas.a" ;;
        hdf5)           echo "$LIBS_DIR/lib/libhdf5_fortran.a" ;;
        pnetcdf)        echo "$LIBS_DIR/lib/libpnetcdf.a" ;;
        netcdf_c)       echo "$LIBS_DIR/lib/libnetcdf.a" ;;
        netcdf_fortran) echo "$LIBS_DIR/lib/libnetcdff.a" ;;
        pio)            echo "$LIBS_DIR/lib/libpiof.a" ;;
        aec)            echo "$LIBS_DIR/lib/libaec.a" ;;
        eccodes)        echo "$LIBS_DIR/lib/libeccodes_f90.a" ;;
        cdi)            echo "$LIBS_DIR/lib/libcdi_f2003.a" ;;
        wrf)            echo "$MODEL_DIR_INSTALL/WRF/main/wrf.exe" ;;
        wps)            echo "$MODEL_DIR_INSTALL/WPS/metgrid/src/metgrid.exe" ;;
        mpas)           echo "$MODEL_DIR_INSTALL/$(mpas_dir_name)/atmosphere_model" ;;
    esac
}

step_func(){
    case "$1" in
        zstd) echo ensure_zstd_in_libs_dir ;;
        wrf)  echo install_wrf ;;
        wps)  echo install_wps ;;
        mpas) echo install_MPAS ;;
        *)    echo "install_$1" ;;
    esac
}

#-------------------------------------------------------------------------------
#  build_plan -> PLAN_LIBS e PLAN_MODELS (ordenados, com dependências)
#-------------------------------------------------------------------------------
build_plan(){
    local -A want=() skip=() added=()
    local x d changed

    expand_libs   "${CLI_LIBS-$DEFAULT_LIBS}";     for x in "${EXPANDED[@]}"; do want[$x]=1; done
    expand_models "${CLI_MODELS-$DEFAULT_MODELS}"; for x in "${EXPANDED[@]}"; do want[$x]=1; done

    # --skip aceita nomes individuais (wrf/wps/mpas aqui = o MODELO, não o preset)
    if [ -n "${CLI_SKIP:-}" ]; then
        for x in ${CLI_SKIP//,/ }; do
            x="$(_norm "$x")"
            if _model_alias "$x" || _lib_alias "$x"; then
                for d in "${_EXP[@]}"; do skip[$d]=1; done
            else
                die "--skip: item desconhecido '$x'"
            fi
        done
    fi

    # Fecho transitivo das dependências
    if [ "$NO_DEPS" -ne 1 ]; then
        changed=1
        while [ "$changed" -eq 1 ]; do
            changed=0
            for x in "${!want[@]}"; do
                for d in $(step_deps "$x"); do
                    if [ -z "${want[$d]:-}" ] && [ -z "${skip[$d]:-}" ]; then
                        want[$d]=1; added[$d]=1; changed=1
                    fi
                done
            done
        done
    fi

    PLAN_LIBS=(); PLAN_MODELS=(); PLAN_AUTO=()
    for x in "${LIB_ORDER[@]}";   do [ -n "${want[$x]:-}" ] && [ -z "${skip[$x]:-}" ] && PLAN_LIBS+=("$x"); done
    for x in "${MODEL_ORDER[@]}"; do [ -n "${want[$x]:-}" ] && [ -z "${skip[$x]:-}" ] && PLAN_MODELS+=("$x"); done
    for x in "${!added[@]}"; do PLAN_AUTO+=("$x"); done
    return 0
}

print_plan(){
    local x st m
    echo "=================================================================="
    echo " PLANO DE INSTALAÇÃO"
    echo "   Modo      : $GNU_MPI ($MODE_NAME)"
    echo "   LIBS_DIR  : $LIBS_DIR"
    echo "   Modelos em: $MODEL_DIR_INSTALL"
    echo "   Downloads : $DOWNLOADS"
    echo "   Logs      : $LOG_DIR"
    [ "$FORCE" -eq 1 ] && echo "   --force   : reinstala tudo do plano"
    echo "------------------------------------------------------------------"
    for x in "${PLAN_LIBS[@]}" "${PLAN_MODELS[@]}"; do
        m="$(step_marker "$x")"
        if [ -n "$m" ] && [ -e "$m" ] && [ "$FORCE" -ne 1 ]; then st="já instalado -> será pulado"
        else st="será instalado"; fi
        _in_list "$x" "${PLAN_AUTO[@]}" && st="$st  (dependência automática)"
        printf "   %-15s %s\n" "$x" "$st"
    done
    [ ${#PLAN_LIBS[@]} -eq 0 ] && [ ${#PLAN_MODELS[@]} -eq 0 ] && echo "   (nada selecionado)"
    echo "=================================================================="
}

list_status(){
    local x m st
    echo "Bibliotecas (ordem de instalação)  —  LIBS_DIR=$LIBS_DIR"
    for x in "${LIB_ORDER[@]}"; do
        m="$(step_marker "$x")"
        if [ -n "$m" ] && [ -e "$m" ]; then st="instalado"; else st="-"; fi
        printf "   %-15s %-10s deps: %s\n" "$x" "$st" "$(step_deps "$x" | tr '\n' ' ')"
    done
    echo "Modelos  —  em $MODEL_DIR_INSTALL"
    for x in "${MODEL_ORDER[@]}"; do
        m="$(step_marker "$x")"
        if [ -n "$m" ] && [ -e "$m" ]; then st="instalado"; else st="-"; fi
        printf "   %-15s %-10s deps: %s\n" "$x" "$st" "$(step_deps "$x" | tr '\n' ' ')"
    done
    echo "Presets de --libs: wrf, mpas, icon, all, none"
}

#-------------------------------------------------------------------------------
#  Execução de uma etapa
#-------------------------------------------------------------------------------
STEP_NAMES=(); STEP_STATUS=(); STEP_TIME=(); STEP_INFO=()
_record(){ STEP_NAMES+=("$1"); STEP_STATUS+=("$2"); STEP_TIME+=("$3"); STEP_INFO+=("${4:-}"); }

_fmt_time(){ local s=$1; printf "%02d:%02d:%02d" $((s/3600)) $((s%3600/60)) $((s%60)); }

# Roda a função num subshell com 'set -e': falha em qualquer comando = etapa falha
_step_shell(){
    set -eE -o pipefail
    trap 'echo "[ERRO] comando falhou (código $?) em ${FUNCNAME[0]:-main}, linha $LINENO: $BASH_COMMAND" >&2' ERR
    "$1"
}

run_step(){
    local name="$1" func log marker mode rc t0 dt
    func="$(step_func "$name")"
    log="$LOG_DIR/$name.log"
    marker="$(step_marker "$name")"

    if [ "$FORCE" -ne 1 ] && [ -n "$marker" ] && [ -e "$marker" ]; then
        echo -e ">>> [$name] \033[0;33mPULADO\033[0m (já instalado: $marker)"
        _record "$name" "PULADO" 0 "já instalado"
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        echo ">>> [dry-run] $name -> $func   (log: $log)"
        _record "$name" "DRY-RUN" 0
        return 0
    fi
    declare -F "$func" >/dev/null || { _record "$name" "FALHA" 0 "função $func não existe"; return 1; }

    # Como mostrar a saída:
    #   direct = configure interativo do WRF/WPS (menu precisa do terminal)
    #   tee    = --verbose ou --prompt (tela + log)
    #   quiet  = só no log (padrão)
    mode="quiet"
    { [ "$VERBOSE" -eq 1 ] || [ "${PROMPTOK:-0}" -eq 1 ]; } && mode="tee"
    { [ "$name" = wrf ] && [ -z "${WRF_CONFIG_OPT:-}" ]; } && mode="direct"
    { [ "$name" = wps ] && [ -z "${WPS_CONFIG_OPT:-}" ]; } && mode="direct"

    t0=$SECONDS
    echo -n ">>> [$name] instalando... "
    case "$mode" in
        quiet)  echo "(log: $log)"
                ( _step_shell "$func" ) >"$log" 2>&1 </dev/null; rc=$? ;;
        tee)    echo "(log: $log)"
                ( _step_shell "$func" ) 2>&1 | tee "$log"; rc=${PIPESTATUS[0]} ;;
        direct) echo "(configure interativo; use --${name}-config N para automatizar)"
                ( _step_shell "$func" ); rc=$?
                echo "(saída exibida no terminal; log de compilação dentro da pasta do modelo)" > "$log" ;;
    esac
    dt=$((SECONDS - t0))

    if [ "$rc" -eq 0 ]; then
        echo -e ">>> [$name] \033[0;32mOK\033[0m em $(_fmt_time $dt)"
        _record "$name" "OK" "$dt"
        return 0
    fi

    echo -e ">>> [$name] \033[0;31mFALHA\033[0m (código $rc) após $(_fmt_time $dt)"
    if [ "$mode" = quiet ]; then
        echo "------------------------- últimas linhas do log -------------------------"
        tail -n 25 "$log" | sed 's/^/   | /'
        echo "-------------------------------------------------------------------------"
        echo "   Log completo: $log"
    fi
    _record "$name" "FALHA" "$dt" "ver $log"
    return 1
}

run_plan(){
    local x rc
    FAILED=0
    for x in "${PLAN_LIBS[@]}" "${PLAN_MODELS[@]}"; do
        # ATENÇÃO: não chamar run_step dentro de 'if'/'||' — isso desativa o
        # 'set -e' de dentro da etapa (comportamento do bash).
        run_step "$x"; rc=$?
        if [ "$rc" -ne 0 ]; then
            FAILED=1
            if [ "$KEEP_GOING" -ne 1 ]; then
                echo ">>> Interrompendo (use --keep-going para continuar após falhas)."
                break
            fi
        fi
    done
    return 0
}

download_plan(){
    local x
    FAILED=0
    for x in "${PLAN_LIBS[@]}"; do
        _in_list "$x" "${DOWNLOAD_PACKAGES[@]}" || { echo ">> [$x] sem tarball (git ou sistema) — ignorado"; continue; }
        if [ "$DRY_RUN" -eq 1 ]; then echo ">> [dry-run] fetch $x"; continue; fi
        ( cd "$DOWNLOADS" && fetch "$x" ) || FAILED=1
    done
}

print_summary(){
    local i st color
    echo
    echo "=================================================================="
    echo " RESUMO"
    echo "=================================================================="
    for i in "${!STEP_NAMES[@]}"; do
        st="${STEP_STATUS[$i]}"
        case "$st" in OK) color="\033[0;32m";; FALHA) color="\033[0;31m";; *) color="\033[0;33m";; esac
        printf "   %-15s ${color}%-8s\033[0m %s  %s\n" "${STEP_NAMES[$i]}" "$st" "$(_fmt_time "${STEP_TIME[$i]}")" "${STEP_INFO[$i]}"
    done
    [ ${#STEP_NAMES[@]} -eq 0 ] && echo "   (nenhuma etapa executada)"
    echo "   Logs: $LOG_DIR"
    echo "=================================================================="
}

# Gera um arquivo para carregar o ambiente depois:  source $LIBS_DIR/env.sh
write_env_file(){
    [ "$DRY_RUN" -eq 1 ] && return 0
    cat > "$LIBS_DIR/env.sh" <<EOF
# Gerado por Models_installer_main.bash em $(date '+%Y-%m-%d %H:%M')
# Uso:  source $LIBS_DIR/env.sh
export LIBS_DIR="$LIBS_DIR"
export NETCDF="\$LIBS_DIR" HDF5="\$LIBS_DIR" PNETCDF="\$LIBS_DIR" PIO="\$LIBS_DIR"
export JASPERLIB="\$LIBS_DIR/lib" JASPERINC="\$LIBS_DIR/include"
export PATH="\$LIBS_DIR/bin:\$PATH"
export LD_LIBRARY_PATH="\$LIBS_DIR/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export OMP_STACKSIZE=\${OMP_STACKSIZE:-512M}
EOF
    echo ">> Ambiente salvo em: $LIBS_DIR/env.sh   (use: source $LIBS_DIR/env.sh)"
}
