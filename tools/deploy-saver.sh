#!/bin/bash
# deploy-saver.sh — sube el protector de pantalla con fotos, arma la lista del álbum y lo lanza para probarlo.
#   cleanhome/CleanSaver.qml, PhotoLayer.qml, saver/  -> /var/lib/webosbrew/cleanhome/
#   saver-mod/Containers/MainView.qml                  -> montado sobre el MainView.qml del protector de LG
#   inputcommon-mod/TvComponent/ScreenSaver/PhotoSlide.qml -> montado sobre el fondo del protector "Sin señal"
#                                                         de las entradas (HDMI sin señal, etc.); reinicia inputcommon
# Uso: tools/deploy-saver.sh [captura.png]        (sin captura: tools/deploy-saver.sh -)
# OJO: los luna-send van en PRIMER PLANO: por el SSH directo (dropbear) lo que queda en segundo plano se corta al cerrar la sesión.
set -euo pipefail
cd "$(dirname "$0")/.."
SHOT="${1:-saver.png}"
SSH=(ssh -i "$HOME/.ssh/tv_webos_dec" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
     -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa
     -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -o ConnectTimeout=15
     -p 2222 root@127.0.0.1)

echo "== archivos de LG modificados (originales de la TV + patches/) =="
tools/preparar-mods.sh
echo "== validando QML =="
python3 tools/qml-check.py cleanhome/CleanSaver.qml cleanhome/PhotoLayer.qml saver-mod/Containers/MainView.qml $(find inputcommon-mod -name '*.qml') || exit 1
node --check cleanhome/saver/sync.js
LOGLINES=$(./tvroot.sh 'wc -l < /var/log/messages' 2>/dev/null | tr -dc '0-9'); LOGLINES=${LOGLINES:-0}

echo "== subiendo archivos =="
tar czf - cleanhome saver-mod inputcommon-mod init.d-50-cytv-debloat.sh | "${SSH[@]}" 'cat > /tmp/saver-deploy.tgz' 2>/dev/null

./tvroot.sh '
set -e
rm -rf /tmp/sd && mkdir /tmp/sd && tar xzf /tmp/saver-deploy.tgz -C /tmp/sd
mkdir -p /var/lib/webosbrew/cleanhome /var/lib/webosbrew/saver-mod/Containers
# lo que el usuario eligió en la TV (pantallas de edición) no se pisa con lo del repo
for c in cal/config.json saver/config.json settings.json; do [ -f /var/lib/webosbrew/cleanhome/$c ] && rm -f /tmp/sd/cleanhome/$c; done
cp -r /tmp/sd/cleanhome/. /var/lib/webosbrew/cleanhome/
cat /tmp/sd/init.d-50-cytv-debloat.sh > /var/lib/webosbrew/init.d/50-cytv-debloat; chmod +x /var/lib/webosbrew/init.d/50-cytv-debloat
# mismo inode para que el bind-mount vea el cambio
cat /tmp/sd/saver-mod/Containers/MainView.qml > /var/lib/webosbrew/saver-mod/Containers/MainView.qml
S=/usr/palm/applications/com.webos.app.screensaver/qml/Containers/MainView.qml
mount | grep -q " $S " || mount --bind /var/lib/webosbrew/saver-mod/Containers/MainView.qml $S
node /var/lib/webosbrew/cleanhome/saver/sync.js
tail -n 2 /tmp/cleanhome-saver.log
# tareas de fondo (álbum y calendario): si ya corren no se duplican (lo arranca también el script de boot)
nohup sh /var/lib/webosbrew/cleanhome/bucles.sh ya </dev/null >/dev/null 2>&1 &
pkill -9 -f com.webos.app.screensaver || true
# archivos modificados de las entradas (protector "Sin señal" y barra sin "Grabaciones"): todo inputcommon-mod/
IQ=/usr/palm/applications/com.webos.app.inputcommon/qml
cd /tmp/sd/inputcommon-mod
for f in $(find . -type f -name "*.qml"); do
  mkdir -p "/var/lib/webosbrew/inputcommon-mod/$(dirname $f)"
  cat "$f" > "/var/lib/webosbrew/inputcommon-mod/$f"
  mount | grep -q " $IQ/${f#./} " || mount --bind "/var/lib/webosbrew/inputcommon-mod/$f" "$IQ/$f"
done
cd /tmp
# grabaciones (DVR) apagadas
for j in rec-listmgr rec-info-adapter; do initctl stop $j 2>/dev/null || true; done
rm -rf /tmp/checkpoint/com.webos.app.inputcommon /mnt/lg/cmn_data/checkpoint/com.webos.app.inputcommon
FG=$(grep -o "lastInputApp\":\"[^\"]*" /var/log/fullhome | tail -n 1 | cut -d\" -f3)
kill -9 $(pidof com.webos.app.inputcommon) 2>/dev/null || true
sleep 3
[ -n "$FG" ] && luna-send -n 1 luna://com.webos.applicationManager/launch "{\"id\":\"$FG\"}" >/dev/null 2>&1
echo "inputcommon reiniciado (entrada: ${FG:-?})"
' 2>&1 | grep -vE '^\[exec|returnValue=|WARNING' || true

[ "$SHOT" = "-" ] && exit 0
echo "== lanzando el protector =="
./tvroot.sh 'luna-send -n 1 luna://com.webos.applicationManager/launch "{\"id\":\"com.webos.app.screensaver\"}"' >/dev/null 2>&1 || true
sleep 15
tools/tvshot.sh "$SHOT"
echo "== log del protector desde este despliegue =="
./tvroot.sh "tail -n +$((LOGLINES + 1)) /var/log/messages | grep -iE 'screensaver|CleanSaver|PhotoLayer|cytv' | grep -iE 'cytv|error|warn|qml' | tail -n 25" 2>/dev/null | grep -vE '^\[exec|returnValue=' || true
