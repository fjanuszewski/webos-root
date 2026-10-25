#!/bin/bash
# deploy-home.sh — sube el Home limpio a la TV, lo relanza al frente y saca una captura.
#   cleanhome/  -> /var/lib/webosbrew/cleanhome/   (componentes propios: CleanTop.qml, fuentes, íconos)
#   home-mod/   -> /var/lib/webosbrew/home-mod/    (archivos del Home de LG modificados, montados con bind)
#   botones/    -> /var/lib/webosbrew/botones/     (botones del control con otra función; se reinicia)
# Uso: tools/deploy-home.sh [captura.png]
# OJO: los luna-send van en PRIMER PLANO: por el SSH directo (dropbear) lo que queda en segundo plano se corta al cerrar la sesión.
set -euo pipefail
cd "$(dirname "$0")/.."
SHOT="${1:-tvshot.png}"
SSH=(ssh -i "$HOME/.ssh/tv_webos_dec" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
     -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa
     -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -o ConnectTimeout=15
     -p 2222 root@127.0.0.1)

echo "== archivos de LG modificados (originales de la TV + patches/) =="
tools/preparar-mods.sh
echo "== validando QML =="
# Archivos de pantalla (QML/JS del Home). Los programas de fondo (saver/, cal/) son Node: se validan con node --check.
python3 tools/qml-check.py $(find cleanhome home-mod \( -path cleanhome/saver -o -path cleanhome/cal -o -path cleanhome/wifi \) -prune -o \( -name "*.qml" -o -name "*.js" \) -print) || exit 1
for f in cleanhome/saver/sync.js cleanhome/cal/sync.js cleanhome/wifi/reconecta.js; do node --check "$f" || exit 1; done
python3 -I -c "compile(open('botones/botones.py').read(), 'botones.py', 'exec')" || exit 1
LOGLINES=$(./tvroot.sh 'wc -l < /var/log/fullhome' 2>/dev/null | tr -dc '0-9'); LOGLINES=${LOGLINES:-0}

echo "== subiendo archivos =="
tar czf - cleanhome home-mod botones init.d-50-cytv-debloat.sh | "${SSH[@]}" 'cat > /tmp/cleanhome-deploy.tgz' 2>/dev/null

./tvroot.sh '
set -e
cd /tmp && rm -rf /tmp/chd && mkdir /tmp/chd && tar xzf /tmp/cleanhome-deploy.tgz -C /tmp/chd
mkdir -p /var/lib/webosbrew/cleanhome
# fotos de fondo (Configuración → Tema → Fondo → Foto): las sube tools/subir-fondo.sh
mkdir -p /var/lib/webosbrew/fondos
# contraseñas de wifi guardadas por el panel Configuración: carpeta solo para root
mkdir -p /var/lib/webosbrew/privado && chmod 700 /var/lib/webosbrew/privado
# lo que el usuario eligió en la TV (pantallas de edición) no se pisa con lo del repo
for c in cal/config.json saver/config.json settings.json; do [ -f /var/lib/webosbrew/cleanhome/$c ] && rm -f /tmp/chd/cleanhome/$c; done
cp -r /tmp/chd/cleanhome/. /var/lib/webosbrew/cleanhome/
# si la persona eligió no guardar contraseñas de wifi, se borran las que hubiera
[ -f /var/lib/webosbrew/no-guardar-wifi ] && rm -f /var/lib/webosbrew/privado/wifi.json
# tareas de fondo (álbum, calendario, reconexión de wifi): se reinician para que tomen el bucles.sh nuevo
[ -f /tmp/cleanhome-bucles.pid ] && kill "$(cat /tmp/cleanhome-bucles.pid)" 2>/dev/null || true
rm -f /tmp/cleanhome-bucles.pid
setsid nohup sh /var/lib/webosbrew/cleanhome/bucles.sh ya </dev/null >/dev/null 2>&1 &
# script de arranque (persistencia)
cat /tmp/chd/init.d-50-cytv-debloat.sh > /var/lib/webosbrew/init.d/50-cytv-debloat; chmod +x /var/lib/webosbrew/init.d/50-cytv-debloat
# botones del control: se reemplaza el programa y se reinicia (si no hay nada asignado, no agarra el control)
mkdir -p /var/lib/webosbrew/botones && cp /tmp/chd/botones/*.py /tmp/chd/botones/*.sh /var/lib/webosbrew/botones/
[ -f /tmp/cytv-botones.pid ] && kill "$(cat /tmp/cytv-botones.pid)" 2>/dev/null || true
pkill -f "botones/botones.py" 2>/dev/null || true
if [ ! -f /var/lib/webosbrew/botones/DISABLED ]; then ( setsid sh /var/lib/webosbrew/botones/run.sh </dev/null >/dev/null 2>&1 & ); fi
# copiar sobre el mismo archivo (mismo inode) para que el bind-mount vea el cambio
cd /tmp/chd/home-mod
for f in $(find . -type f); do mkdir -p "/var/lib/webosbrew/home-mod/$(dirname $f)"; cat "$f" > "/var/lib/webosbrew/home-mod/$f"; done
H=/usr/palm/applications/com.webos.app.fullhome/qml
for f in Model/ShelfList.js UserInterfaceLayer/Containers/Main/TopShelf.qml UserInterfaceLayer/GlobalStyle.qml UserInterfaceLayer/Containers/MainView.qml UserInterfaceLayer/Containers/Main/TopGlobalAction.qml UserInterfaceLayer/Containers/Main/Hero.qml; do
  mount | grep -q " $H/$f " || mount --bind "/var/lib/webosbrew/home-mod/$f" "$H/$f"
done
rm -rf /tmp/checkpoint/com.webos.app.fullhome /mnt/lg/cmn_data/checkpoint/com.webos.app.fullhome
pkill -9 -f com.webos.app.fullhome || true
sleep 2
luna-send -n 1 luna://com.webos.applicationManager/launch "{\"id\":\"com.webos.app.fullhome\",\"params\":{\"snapshot\":false}}" >/dev/null 2>&1
for i in 1 2 3 4 5 6 7 8 9 10; do pidof com.webos.app.fullhome >/dev/null && break; sleep 1; done
echo "Home pid: $(pidof com.webos.app.fullhome || echo NINGUNO)"
' 2>&1 | grep -vE '^\[exec|returnValue=|WARNING' || true

echo "== esperando que dibuje =="
sleep 8
tools/tvshot.sh "$SHOT"
echo "== errores de compilación QML desde este despliegue =="
# Si un archivo modificado de LG no compila, el Home no abre (HOME no responde): se desmonta solo y se relanza.
ERRS=$(./tvroot.sh "tail -n +$((LOGLINES + 1)) /var/log/fullhome | grep -E 'Property value set multiple times|is not a type|Expected token|Syntax error|Cannot assign to non-existent|Invalid property|Unexpected token|Type .* unavailable' | grep -oE '(Model/ShelfList.js|Containers/Main/TopShelf.qml|Containers/Main/TopGlobalAction.qml|Containers/Main/Hero.qml|UserInterfaceLayer/GlobalStyle.qml|Containers/MainView.qml|cleanhome/[A-Za-z]+.qml)[:0-9]*[^\"]*' | sort -u" 2>/dev/null | grep -vE '^\[exec|returnValue=' || true)
if [ -n "$ERRS" ]; then
  echo "!! ERRORES:"; echo "$ERRS"
  BAD=$(echo "$ERRS" | grep -oE 'Model/ShelfList.js|Containers/Main/TopShelf.qml|Containers/Main/TopGlobalAction.qml|Containers/Main/Hero.qml|UserInterfaceLayer/GlobalStyle.qml|Containers/MainView.qml' | sort -u | sed 's#^Containers#UserInterfaceLayer/Containers#' | tr '\n' ' ')
  if [ -n "$BAD" ]; then
    echo "!! desmontando: $BAD (vuelve el original de LG) y relanzando el Home"
    ./tvroot.sh "H=/usr/palm/applications/com.webos.app.fullhome/qml; for f in $BAD; do umount \$H/\$f 2>/dev/null; done; rm -rf /tmp/checkpoint/com.webos.app.fullhome /mnt/lg/cmn_data/checkpoint/com.webos.app.fullhome; pkill -9 -f com.webos.app.fullhome; sleep 2; luna-send -n 1 luna://com.webos.applicationManager/launch '{\"id\":\"com.webos.app.fullhome\",\"params\":{\"snapshot\":false}}' >/dev/null 2>&1" >/dev/null 2>&1
  fi
  exit 2
fi
echo "sin errores de compilación"
