#!/bin/bash
# subir-fondo.sh — sube una o más fotos a la carpeta de fondos de la tele (/var/lib/webosbrew/fondos/).
# Después se eligen en la tele: engranaje de arriba → Configuración → Tema → Fondo → Foto.
#   - Achica cada foto a 1920 de ancho como máximo (con sips, que viene en la Mac) para que la tele no se trabe.
#   - Les pone un nombre simple (minúsculas, sin espacios ni acentos).
#   - Sin argumentos, sube todo lo que haya en la carpeta fondos/ del repo (no se publica: está en .gitignore).
# Uso: tools/subir-fondo.sh foto.jpg [otra.png …]
#      tools/subir-fondo.sh --borrar nombre.jpg      (saca una foto de la tele)
set -euo pipefail
cd "$(dirname "$0")/.."
SSH=(ssh -i "$HOME/.ssh/tv_webos_dec" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
     -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -o ConnectTimeout=15 -p 2222 root@127.0.0.1)
DEST=/var/lib/webosbrew/fondos

if [ "${1:-}" = "--borrar" ]; then
  [ -n "${2:-}" ] || { echo "Falta el nombre de la foto a borrar"; exit 1; }
  "${SSH[@]}" "rm -f '$DEST/$(basename "$2")' && ls $DEST"
  exit 0
fi

FILES=("$@")
if [ ${#FILES[@]} -eq 0 ]; then
  shopt -s nullglob nocaseglob
  FILES=(fondos/*.jpg fondos/*.jpeg fondos/*.png)
  [ ${#FILES[@]} -gt 0 ] || { echo "No hay fotos: pasá una (tools/subir-fondo.sh foto.jpg) o ponelas en la carpeta fondos/ del repo."; exit 1; }
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
"${SSH[@]}" "mkdir -p $DEST"
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "No existe: $f"; continue; }
  ext=$(echo "${f##*.}" | tr 'A-Z' 'a-z'); [ "$ext" = "jpeg" ] && ext=jpg
  name=$(basename "$f" | sed 's/\.[^.]*$//' | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//')
  [ -n "$name" ] || name="fondo-$(date +%s)"
  out="$TMP/$name.$ext"
  cp "$f" "$out"
  if command -v sips >/dev/null 2>&1; then         # solo si es más grande (sips -Z también agranda)
    big=$(sips -g pixelWidth -g pixelHeight "$out" 2>/dev/null | awk '/pixel/ {if ($2 > m) m = $2} END {print m + 0}')
    [ "$big" -gt 1920 ] && { sips -Z 1920 "$out" >/dev/null 2>&1 || true; }
  fi
  "${SSH[@]}" "cat > '$DEST/$name.$ext'" < "$out"
  echo "subida: $name.$ext ($(du -k "$out" | cut -f1) KB)"
done
echo "Listo. En la tele: engranaje → Tema → Fondo → Foto (la lista se actualiza en menos de un minuto)."
