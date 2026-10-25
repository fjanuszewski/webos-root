#!/bin/sh
# fondos.sh — fotos de fondo de la pantalla de inicio (/var/lib/webosbrew/fondos/). Lo usa Configuración → Tema →
# "Agregar foto" (FondoAgregar.qml, por luna://org.webosbrew.hbchannel.service/exec) y bucles.sh (la lista).
#   indice              arma fondos/index.json (la más nueva primero)
#   listar usb|tele     fotos del pendrive (/tmp/usb/…) o de la memoria de la tele (/media/internal: descargas del
#                       navegador y demás), las 40 más nuevas, en JSON: {"discos":N,"fotos":[{"p":ruta,"n":nombre,"k":KB}]}
#   copiar RUTA ID      copia esa foto a fondos/   } en segundo plano: contesta enseguida y deja el resultado en
#   bajar ENLACE ID     baja la foto de internet   } /tmp/cytv-fondo.json → {"id":ID,"estado":"…","texto":"…","foto":"…"}
# La tele no puede achicar fotos (no hay con qué): se acepta hasta MAX_KB y solo si queda lugar. La pantalla igual
# las dibuja livianas (sourceSize de 1920). Solo JPG y PNG, revisando los primeros bytes (no el nombre). Qt 5.6 / busybox.
F=${FONDOS_DIR:-/var/lib/webosbrew/fondos}      # (FONDOS_DIR y FONDOS_ESTADO: solo para probar)
EST=${FONDOS_ESTADO:-/tmp/cytv-fondo.json}
MAX_KB=15360        # 15 MB por foto
LIBRE_KB=51200      # dejar al menos 50 MB libres en la memoria de la tele

esc() { sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r\t'; }
estado() { printf '{"id":"%s","estado":"%s","texto":"%s","foto":"%s"}\n' "$ID" "$1" "$(printf %s "$2" | esc)" "$3" > $EST.tmp && mv $EST.tmp $EST; }
indice() {
  [ -d $F ] || return 0
  L=$(cd $F && ls -1t 2>/dev/null | grep -iE '\.(jpe?g|png)$' | esc_linea | tr '\n' ',' | sed 's/,$//')
  [ "[$L]" != "$(cat $F/index.json 2>/dev/null)" ] && echo "[$L]" > $F/index.json
  return 0
}
esc_linea() { sed 's/\\/\\\\/g; s/"/\\"/g; s/.*/"&"/'; }
# jpg | png | "" según los primeros bytes
tipo() {
  m=$(head -c 4 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n')
  case "$m" in ffd8ff*) echo jpg ;; 89504e47) echo png ;; *) echo "" ;; esac
}
# nombre simple y libre en fondos/: minúsculas, sin espacios ni acentos; si ya existe, -2, -3…
nombre_libre() {
  b=$(printf %s "$1" | sed 's/\.[^.]*$//; s/á/a/g; s/Á/a/g; s/é/e/g; s/É/e/g; s/í/i/g; s/Í/i/g; s/ó/o/g; s/Ó/o/g; s/ú/u/g; s/Ú/u/g; s/ü/u/g; s/Ü/u/g; s/ñ/n/g; s/Ñ/n/g' | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-40)
  [ -n "$b" ] || b="foto-$(date +%s)"
  n="$b.$2"; i=2
  while [ -e "$F/$n" ]; do n="$b-$i.$2"; i=$((i + 1)); done
  echo "$n"
}
hay_lugar() {   # $1 = KB de la foto
  libre=$(df -Pk $F 2>/dev/null | awk 'NR == 2 {print $4}')
  [ -n "$libre" ] && [ $((libre - $1)) -ge $LIBRE_KB ]
}
# Revisa y guarda una foto ya bajada/copiada en $1 (temporal) con nombre basado en $2
guardar() {
  t=$(tipo "$1")
  [ -n "$t" ] || { rm -f "$1"; estado error "Eso no es una foto JPG o PNG"; return 1; }
  kb=$(( ($(wc -c < "$1") + 1023) / 1024 ))
  [ $kb -le $MAX_KB ] || { rm -f "$1"; estado error "La foto es muy pesada (más de 15 MB)"; return 1; }
  hay_lugar $kb || { rm -f "$1"; estado error "No queda lugar en la tele para más fotos"; return 1; }
  n=$(nombre_libre "$2" "$t")
  mv "$1" "$F/$n" && chmod 644 "$F/$n" || { rm -f "$1"; estado error "No pude guardar la foto"; return 1; }
  indice
  estado listo "Listo: la foto ya está en la tele" "$n"
}

# copiar y bajar corren en segundo plano: la pantalla pregunta /tmp/cytv-fondo.json cada un rato
if [ "$1" = copiar ] || [ "$1" = bajar ]; then
  if [ -z "$FONDO_HIJO" ]; then
    ID="$3"; estado trabajando "$([ "$1" = bajar ] && echo "Bajando la foto…" || echo "Copiando la foto…")"
    FONDO_HIJO=1 setsid nohup sh "$0" "$@" </dev/null >/dev/null 2>&1 &
    echo '{"ok":true}'
    exit 0
  fi
fi
mkdir -p $F

case "$1" in
  indice) indice ;;
  listar)
    if [ "$2" = usb ]; then
      R=$(mount | awk '$3 ~ /^\/tmp\/usb\// {print $3}')
    else
      R=/media/internal
    fi
    D=0; [ -n "$R" ] && D=$(echo "$R" | wc -l)
    printf '{"discos":%s,"fotos":[' "$D"
    first=1
    for r in $R; do
      find "$r" -maxdepth 5 -name '.*' ! -path "$r" -prune -o -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print 2>/dev/null
    done | head -500 | while IFS= read -r p; do
      stat -c '%Y %s %n' "$p" 2>/dev/null
    done | sort -rn | head -40 | while read -r t sz p; do
      [ $first = 1 ] && first=0 || printf ','
      printf '{"p":"%s","n":"%s","k":%s}' "$(printf %s "$p" | esc)" "$(basename "$p" | esc)" $(( (sz + 1023) / 1024 ))
    done
    printf ']}\n'
    ;;
  copiar)
    ID="$3"; src="$2"
    case "$src" in /tmp/usb/*|/media/internal/*) ;; *) estado error "Esa foto no está en el pendrive ni en la tele"; exit 1 ;; esac
    case "$src" in *..*) estado error "Ruta inválida"; exit 1 ;; esac
    [ -f "$src" ] || { estado error "No encuentro la foto. ¿Sacaste el pendrive?"; exit 1; }
    tmp=$F/.copiando.$$
    cp "$src" "$tmp" 2>/dev/null || { rm -f "$tmp"; estado error "No pude leer la foto"; exit 1; }
    guardar "$tmp" "$(basename "$src")"
    ;;
  bajar)
    ID="$3"; url="$2"
    case "$url" in http://*|https://*) ;; *) estado error "El enlace tiene que empezar con http:// o https://"; exit 1 ;; esac
    tmp=$F/.bajando.$$
    set -- -fsSL -A "Mozilla/5.0 (webOS TV)" --max-filesize $((MAX_KB * 1024)) -m 90 --retry 1 -o "$tmp"
    curl "$@" "$url"; rc=$?
    # la lista de certificados de la tele es vieja: si falla solo por eso, se reintenta (igual se revisa que sea una foto)
    [ $rc = 60 ] || [ $rc = 51 ] || [ $rc = 35 ] && { curl -k "$@" "$url"; rc=$?; }
    if [ $rc != 0 ]; then
      rm -f "$tmp"
      case $rc in
        6|7) estado error "No hay internet o no encuentro esa dirección" ;;
        22) estado error "La página no dejó bajar la foto (¿el enlace es público?)" ;;
        28) estado error "Tardó demasiado. Probá de nuevo" ;;
        63) estado error "La foto es muy pesada (más de 15 MB)" ;;
        *) estado error "No pude bajar la foto (error $rc)" ;;
      esac
      exit 1
    fi
    nom=$(printf %s "$url" | sed 's/[?#].*$//; s/\/*$//; s/.*\///')
    case "$nom" in *.*) ;; *) nom="enlace-$(date +%s)" ;; esac
    guardar "$tmp" "$nom"
    ;;
  *) echo "uso: fondos.sh indice | listar usb|tele | copiar RUTA ID | bajar ENLACE ID" >&2; exit 1 ;;
esac
