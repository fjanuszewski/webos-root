#!/bin/sh
# CleanYourTV - corre en cada boot via webosbrew autostart (Activity Manager).
# 1) adblock  2) Home limpio (QML modificados)  3) debloat de servicios y preloads.

# --- 1) Bloqueo de dominios de ads/recomendaciones/telemetria ---
if [ -f /var/lib/webosbrew/hosts ] && ! mount | grep -q " /etc/hosts "; then
  mount --bind /var/lib/webosbrew/hosts /etc/hosts 2>/dev/null
fi

# --- 2) Home limpio: barra superior + fila de apps (sin ads, trending ni carrusel) ---
# Kill switch: crear /var/lib/webosbrew/home-mod/DISABLED para no aplicarlo.
H=/usr/palm/applications/com.webos.app.fullhome/qml
M=/var/lib/webosbrew/home-mod
if [ ! -f "$M/DISABLED" ]; then
  for f in Model/ShelfList.js UserInterfaceLayer/Containers/Main/TopShelf.qml UserInterfaceLayer/GlobalStyle.qml UserInterfaceLayer/Containers/MainView.qml UserInterfaceLayer/Containers/Main/TopGlobalAction.qml UserInterfaceLayer/Containers/Main/Hero.qml; do
    if [ -f "$M/$f" ] && ! mount | grep -q " $H/$f "; then
      mount --bind "$M/$f" "$H/$f" 2>/dev/null
    fi
  done
  # El Home arranca desde un snapshot CRIU armado con los archivos originales:
  # se borra y se relanza para que lea los archivos montados.
  rm -rf /tmp/checkpoint/com.webos.app.fullhome /mnt/lg/cmn_data/checkpoint/com.webos.app.fullhome
  pkill -9 -f com.webos.app.fullhome 2>/dev/null
  sleep 2
  luna-send -n 1 luna://com.webos.applicationManager/launch '{"id":"com.webos.app.fullhome","params":{"snapshot":false},"preload":"full"}' >/dev/null 2>&1
fi

# --- 2b) Protector de pantalla con fotos del álbum de Google Photos ---
# Kill switch: crear /var/lib/webosbrew/saver-mod/DISABLED (vuelve el protector original de LG).
S=/usr/palm/applications/com.webos.app.screensaver/qml/Containers/MainView.qml
SM=/var/lib/webosbrew/saver-mod/Containers/MainView.qml
if [ ! -f /var/lib/webosbrew/saver-mod/DISABLED ] && [ -f "$SM" ] && ! mount | grep -q " $S "; then
  mount --bind "$SM" "$S" 2>/dev/null
  rm -rf /tmp/checkpoint/com.webos.app.screensaver /mnt/lg/cmn_data/checkpoint/com.webos.app.screensaver
  pkill -9 -f com.webos.app.screensaver 2>/dev/null
fi
# Archivos modificados de las entradas (inputcommon): el protector de fotos en "Sin señal" (PhotoSlide.qml) y la
# barra de LG sin el botón "Grabaciones" (DvrMainView.qml). Se monta TODO lo que haya en inputcommon-mod/.
IQ=/usr/palm/applications/com.webos.app.inputcommon/qml
IMD=/var/lib/webosbrew/inputcommon-mod
if [ ! -f /var/lib/webosbrew/saver-mod/DISABLED ] && [ -d "$IMD" ]; then
  CHANGED=0
  for f in $(cd "$IMD" && find . -type f -name "*.qml"); do
    if [ -f "$IQ/$f" ] && ! mount | grep -q " $IQ/${f#./} "; then mount --bind "$IMD/$f" "$IQ/$f" 2>/dev/null && CHANGED=1; fi
  done
  if [ $CHANGED = 1 ]; then
    rm -rf /tmp/checkpoint/com.webos.app.inputcommon /mnt/lg/cmn_data/checkpoint/com.webos.app.inputcommon
    kill -9 $(pidof com.webos.app.inputcommon) 2>/dev/null
  fi
fi
# Grabaciones (DVR): el usuario no las usa → servicios apagados (solo los usaba la Guía de canales de antena).
for j in rec-listmgr rec-info-adapter; do initctl stop $j 2>/dev/null; done
# Tareas de fondo del inicio y del protector (álbum de fotos cada 6 h, calendario cada cal/refresh segundos, y
# enseguida si una pantalla de edición lo pide). Todo en cleanhome/bucles.sh, un solo juego de bucles.
[ -f /var/lib/webosbrew/cleanhome/bucles.sh ] && nohup sh /var/lib/webosbrew/cleanhome/bucles.sh </dev/null >/dev/null 2>&1 &

# --- 3 y 4) Precarga de apps y servicios bloat: EN SEGUNDO PLANO Y DESACOPLADO ---
# IMPORTANTE (2026-10-26): esto antes corría en primer plano con ~40 s de "sleep". Homebrew ejecuta este script
# con run-parts y ESPERA a que termine antes de cerrar su "modo a prueba de fallos" (failsafe). Esos 40 s dejaban
# el failsafe abierto: si la tele se apagaba/prendía en ese rato (fácil con el inicio rápido), el arranque
# siguiente entraba en failsafe y DESACTIVABA todo lo nuestro (lo que pasó el 2026-10-26). Ahora el debloat se
# lanza con setsid en segundo plano, así este script vuelve en 2-3 s y la ventana peligrosa casi desaparece.
# Kill switch de todo esto: crear /var/lib/webosbrew/appcloser/DISABLED. Detalle en PERSISTENCIA.md.
setsid sh -c '
  OPT=/var/lib/webosbrew; AC=/var/lib/webosbrew/appcloser
  # Precarga de apps apagada (la tele abría sola YouTube, Netflix, Amazon, Assistant... ~230 MB)
  [ -f "$AC/DISABLED" ] || initctl stop webos-preload-manager 2>/dev/null
  # Parar servicios bloat/ads/telemetria (esperar a que el sistema levante). La voz y el navegador NO se tocan.
  # iepg NO se para: el menú de entradas (botón INPUT) espera su respuesta para dibujarse. Opcionales por archivo:
  #   apagar-transmision → AirPlay/Miracast/DLNA/ThinQ/HomeKit (~100 MB); apagar-audio-bt → audio Bluetooth.
  sleep 12
  for pass in 1 2 3; do
    for j in admanager contentminer uploadd remotelogger; do initctl stop $j 2>/dev/null; done
    kill "$(pidof admanager)" 2>/dev/null
    if [ -f "$OPT/apagar-transmision" ]; then
      for j in airplay-adaptor second-screen-gateway miracast dmr ssdp-discovery-lgtv; do initctl stop $j 2>/dev/null; done
      for p in airplay ss.gateway miracast dmr upnpd; do kill "$(pidof $p)" 2>/dev/null; done
      kill -9 "$(pidof homekit)" 2>/dev/null
      initctl stop iot-client 2>/dev/null; kill -9 "$(pidof iot-client)" 2>/dev/null
    fi
    [ -f "$OPT/apagar-audio-bt" ] && for j in btaudiosnk btaudiosrc; do initctl stop $j 2>/dev/null; done
    kill "$(pidof acr2)" 2>/dev/null
    [ -f "$AC/DISABLED" ] || initctl stop webos-preload-manager 2>/dev/null
    sleep 6
  done
' </dev/null >/dev/null 2>&1 &

# --- 5) Vigilante de apps: al cambiar de app cierra las demás (y las que abrió la precarga) ---
# Desde 2026-10-25 corre DENTRO de botones.py (botones/vigilante.py, Python, ~4 MB en total) en vez del viejo
# appcloser.js (Node, ~32 MB). Apagar solo el vigilante: appcloser/VIGILANTE-OFF (appcloser/DISABLED apaga además
# el corte de la precarga). Si quedó el viejo de una instalación anterior, se para.
for p in $(pidof node); do tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null | grep -q "appcloser/appcloser.js" && kill $p; done
for p in $(pidof sh); do tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null | grep -q "appcloser/run.sh" && kill $p; done

# --- 6) Botones del control con otra función (Configuración → Control remoto; ver BOTONES.md) + vigilante ---
# Solo agarra el control si hay algún botón asignado. Apagar todo el programa: /var/lib/webosbrew/botones/DISABLED.
BT=/var/lib/webosbrew/botones
if [ ! -f "$BT/DISABLED" ] && [ -f "$BT/run.sh" ] && ! { [ -f /tmp/cytv-botones.pid ] && kill -0 "$(cat /tmp/cytv-botones.pid)" 2>/dev/null; }; then
  ( setsid sh "$BT/run.sh" </dev/null >/dev/null 2>&1 & )
fi
echo "cytv applied $(date) uptime=$(cut -d' ' -f1 /proc/uptime) homemod=$(mount | grep -c fullhome) saver=$(mount | grep -c screensaver) botones=$(cat /tmp/cytv-botones.pid 2>/dev/null)" >> /var/lib/webosbrew/cytv-debloat.log
