#!/bin/bash
# preparar-mods.sh — antes de instalar: deja listos los archivos modificados de LG (home-mod/, saver-mod/, inputcommon-mod/).
#   - Si ya están armados y tenemos los originales (.originales/): se guardan los cambios como parches (por si se editaron).
#   - Si no (por ejemplo, alguien que bajó el proyecto): se arman desde el original de SU TV + patches/.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -d .originales ] && [ -d home-mod ] && [ -d saver-mod ] && [ -d inputcommon-mod ]; then
  tools/guardar-parches.sh >/dev/null
else
  tools/armar-mods.sh
fi
