#!/bin/bash
# armar-mods.sh — arma los archivos modificados de LG (home-mod/, saver-mod/, inputcommon-mod/) a partir de:
#   - el ORIGINAL de LG, que se baja de la propia TV (/old_root/... = sistema de fábrica, sin nuestros montajes)
#     y queda en .originales/ (no se publica: es código de LG con licencia confidencial);
#   - nuestros cambios, que están en patches/ (eso sí se publica: solo las líneas que tocamos).
# Lo corren deploy-home.sh y deploy-saver.sh antes de subir. Para editar: cambiar el archivo en home-mod/ (etc.)
# y después correr tools/guardar-parches.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
. tools/mods-lista.sh
SSH=(ssh -i "$HOME/.ssh/tv_webos_dec" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
     -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -o ConnectTimeout=15 -p 2222 root@127.0.0.1)
for line in $MODS; do
  IFS='|' read -r local app file <<< "$line"
  orig=".originales/$app/$file"
  if [ ! -s "$orig" ]; then
    mkdir -p "$(dirname "$orig")"
    "${SSH[@]}" "cat /old_root/usr/palm/applications/$app/$file" > "$orig.tmp" && [ -s "$orig.tmp" ] && mv "$orig.tmp" "$orig" \
      || { rm -f "$orig.tmp"; echo "ERROR: no pude bajar el original $app/$file de la TV"; exit 1; }
  fi
  patchf="patches/$local/$file.patch"
  out="$local/$file"
  mkdir -p "$(dirname "$out")"
  cp "$orig" "$out.nuevo"
  if [ -s "$patchf" ]; then
    patch -s --no-backup-if-mismatch "$out.nuevo" < "$patchf" || { rm -f "$out.nuevo"; echo "ERROR: el parche $patchf no aplica sobre el original de esta TV"; exit 1; }
  fi
  mv "$out.nuevo" "$out"
done
echo "armar-mods: $(echo "$MODS" | grep -c '|') archivos armados desde los originales + patches/"
