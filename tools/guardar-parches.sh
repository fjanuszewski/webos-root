#!/bin/bash
# guardar-parches.sh — guarda nuestros cambios a los archivos de LG como parches (patches/…/archivo.patch):
# compara el original de LG (.originales/, se baja con armar-mods.sh) contra el modificado (home-mod/, etc.).
# Correrlo después de editar un archivo de home-mod/, saver-mod/ o inputcommon-mod/.
set -euo pipefail
cd "$(dirname "$0")/.."
. tools/mods-lista.sh
for line in $MODS; do
  IFS='|' read -r local app file <<< "$line"
  orig=".originales/$app/$file"
  [ -s "$orig" ] || { echo "Falta $orig: correr primero tools/armar-mods.sh (antes de editar)"; exit 1; }
  mkdir -p "$(dirname "patches/$local/$file")"
  diff -u --label "original/$file" --label "modificado/$file" "$orig" "$local/$file" > "patches/$local/$file.patch" || true
done
echo "guardar-parches: listo → patches/"; find patches -name "*.patch" | wc -l
