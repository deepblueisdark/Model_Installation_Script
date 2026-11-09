#!/usr/bin/env bash
#--------------------------------------------------------------------------
#  Verifica se todos os links de download do instalador estão ativos.
#  Atalho para:  ./Models_installer_main.bash --check-downloads
#  (as URLs ficam em LIBS/Models_installer_downloads.bash)
#--------------------------------------------------------------------------
exec bash "$(dirname "${BASH_SOURCE[0]}")/Models_installer_main.bash" --check-downloads "$@"
