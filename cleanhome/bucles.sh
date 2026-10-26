#!/bin/sh
# bucles.sh — tareas de fondo de la pantalla de inicio y del protector (las arranca init.d al prender, y deploy).
#   - álbum de fotos (saver/sync.js): al minuto de prender y cada 1 h (lista nueva de fotos; el álbum entero lo
#     relee cada 6 h), o ENSEGUIDA si existe saver/pedido (ahí relee el álbum entero)
#   - calendario (cal/sync.js): al minuto y cada cal/refresh segundos (mín. 60, por defecto 600), o enseguida con cal/pedido
#   - wifi (wifi/reconecta.js): cada 30 s, si el wifi no está conectado y hay redes guardadas, se reconecta sola
#     (primero a la última red, después a las otras guardadas). No corre si existe /var/lib/webosbrew/no-guardar-wifi.
#   - fondos: lista de fotos de /var/lib/webosbrew/fondos/ en fondos/index.json (fondos.sh indice; la lee Configuración → Tema)
#   - VIGILANTE DE PERSISTENCIA: cada 30 s revisa que nuestros montajes sigan puestos; si webOS los pisó
#     (p. ej. al despertar del inicio rápido, o una restauración del snapshot), vuelve a aplicar todo solo.
#     Así la tele no queda nunca "de fábrica" por un pisón de webOS. Se apaga con home-mod/DISABLED.
# Las pantallas de edición (CleanEdit.qml) escriben los "pedido" y cal/refresh. Se revisa cada 30 s.
# Un solo juego de bucles: si ya corren (pid vivo), no se arrancan otros.
C=/var/lib/webosbrew/cleanhome
PIDF=/tmp/cleanhome-bucles.pid
if [ -f $PIDF ] && kill -0 "$(cat $PIDF)" 2>/dev/null; then exit 0; fi
echo $$ > $PIDF
[ "$1" = "ya" ] || sleep 60
TS=0; TC=0
while true; do
  if [ $TS -le 0 ] || [ -f $C/saver/pedido ]; then
    YA=; [ -f $C/saver/pedido ] && YA=ya
    rm -f $C/saver/pedido; node $C/saver/sync.js $YA >/dev/null 2>&1; TS=3600
  fi
  if [ $TC -le 0 ] || [ -f $C/cal/pedido ]; then
    rm -f $C/cal/pedido; node $C/cal/sync.js >/dev/null 2>&1
    TC=$(cat $C/cal/refresh 2>/dev/null); [ "${TC:-0}" -ge 60 ] 2>/dev/null || TC=600
  fi
  if [ ! -f /var/lib/webosbrew/no-guardar-wifi ] && [ -s /var/lib/webosbrew/privado/wifi.json ]; then
    # chequeo barato sin node: ¿wlan0 tiene IP? ¿hay cable? (luna-send sin terminal no devuelve nada acá)
    if ! ip -4 addr show wlan0 2>/dev/null | grep -q "inet " && [ "$(cat /sys/class/net/eth0/carrier 2>/dev/null)" != "1" ]; then
      node $C/wifi/reconecta.js >/dev/null 2>&1 &   # en segundo plano: probar redes tarda hasta ~30 s cada una
    fi
  fi
  sh $C/fondos.sh indice     # por si alguien agregó o borró fotos a mano (Agregar foto ya la arma sola)
  # Vigilante de persistencia: si webOS pisó los montajes del inicio, re-aplicar todo (init.d es idempotente:
  # si ya está puesto no hace nada). Solo si no se pidió desactivar (home-mod/DISABLED).
  if [ ! -f /var/lib/webosbrew/home-mod/DISABLED ] && \
     ! mount | grep -q " /usr/palm/applications/com.webos.app.fullhome/qml/"; then
    echo "$(date) montajes caídos: re-aplico el inicio" >> /var/lib/webosbrew/cytv-debloat.log
    setsid sh /var/lib/webosbrew/init.d/50-cytv-debloat </dev/null >/dev/null 2>&1 &
  fi
  sleep 30; TS=$((TS - 30)); TC=$((TC - 30))
done
