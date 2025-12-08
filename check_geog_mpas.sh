#!/usr/bin/env bash
# MPAS-A GEOG validator (versão compatível, sem arrays associativos)
set -euo pipefail

NAMELIST="${1:-namelist.init_atmosphere}"
[[ -f "$NAMELIST" ]] || { echo "[ERRO] Namelist não encontrado: $NAMELIST"; exit 2; }

get_nl_val() {
  local key="$1"
  grep -E "^\s*${key}\s*=" "$NAMELIST" | tail -n1 \
    | sed -E "s/.*${key}\s*=\s*'([^']+)'.*/\1/" | tr -d '[:space:]'
}

GEOG="$(get_nl_val config_geog_data_path)"
LUSE="$(get_nl_val config_landuse_data | tr '[:lower:]' '[:upper:]')"
[[ -n "$GEOG" ]] || { echo "[ERRO] config_geog_data_path não definido"; exit 2; }
[[ -d "$GEOG" ]] || { echo "[ERRO] Diretório inexistente: $GEOG"; exit 2; }

# Função utilitária: retorna o primeiro candidato existente; senão, vazio
find_first_dir() {
  local base="$1"; shift
  local candidates="$*"
  for d in $candidates; do
    [[ -d "$base/$d" ]] && { echo "$d"; return 0; }
  done
  echo ""  # não achou
  return 1
}

# Conjuntos com os nomes que você possui
C_TOPO="topo_gmted2010_30s"
C_LANDUSE_MODIS="modis_landuse_20class_30s_with_lakes"
C_GREENFRAC="greenfrac_fpar_modis"
C_ALBEDO="albedo_modis"
C_LAI="lai_modis_30s lai_modis_10m"
C_SOIL_TOP="soiltype_top_30s"
C_SOIL_BOT="soiltype_bot_30s"
C_SOILTEMP="soiltemp_1deg"
C_VARSSO="varsso varsso_2m varsso_5m varsso_10m"

# Ordem de verificação
ORDER="topo landuse soiltype_top soiltype_bot greenfrac albedo lai soiltemp varsso"

# Mapeia chave -> candidatos
candidates_for() {
  case "$1" in
    topo)         echo "$C_TOPO" ;;
    landuse)      echo "$C_LANDUSE_MODIS" ;;  # você tem MODIS
    soiltype_top) echo "$C_SOIL_TOP" ;;
    soiltype_bot) echo "$C_SOIL_BOT" ;;
    greenfrac)    echo "$C_GREENFRAC" ;;
    albedo)       echo "$C_ALBEDO" ;;
    lai)          echo "$C_LAI" ;;
    soiltemp)     echo "$C_SOILTEMP" ;;
    varsso)       echo "$C_VARSSO" ;;
    *)            echo "" ;;
  esac
}

# Ajuste de landuse conforme namelist
LUSE_LBL="MODIS"
if [[ "$LUSE" == "USGS" ]]; then
  LUSE_LBL="USGS (mas você não tem USGS; mantendo MODIS)"
fi

echo "== MPAS-A GEOG check =="
echo "  Namelist           : $NAMELIST"
echo "  geog path          : $GEOG"
echo "  landuse (namelist) : $LUSE_LBL"

missing=0
for key in $ORDER; do
  CAND="$(candidates_for "$key")"
  FOUND="$(find_first_dir "$GEOG" $CAND || true)"
  if [[ -n "$FOUND" ]]; then
    printf "  [ OK ] %-14s → %s/%s\n" "$key" "$GEOG" "$FOUND"
  else
    printf "  [MISS] %-14s → faltando. Procure: {%s}\n" "$key" "$CAND"
    missing=1
  fi
done

echo "---- Extras detectados (se existirem) ----"
for grp in \
  "lake_depth" \
  "urbfrac_nlcd2011" \
  "NUDAPT44_1km" \
  "nlcd2011_ll_9s nlcd2011_can_ll_9s nlcd2011_imp_ll_9s" \
  "orogwd_1deg orogwd_2deg orogwd_10m orogwd_20m orogwd_30m" \
  "soilgrids clayfrac_5m sandfrac_5m groundwater irrigation crop" \
  "ssib_landuse_5m ssib_landuse_10m"
do
  HIT=""
  for c in $grp; do
    [[ -d "$GEOG/$c" ]] && HIT+="$c "
  done
  [[ -n "$HIT" ]] && echo "  [+] $HIT"
done

if [[ $missing -ne 0 ]]; then
  echo
  echo "[RESUMO] Existem datasets faltando. Confira o log do init_atmosphere:"
  echo "  grep -E \"BEGIN INTERPOLATION|interpolate|geog/\" log.* | sed 's|.*/geog/|geog/|' | sort -u"
  exit 1
else
  echo
  echo "[RESUMO] Tudo certo: todos os datasets esperados foram encontrados."
  exit 0
fi
