#!/bin/bash
# restore-services.sh — deshace la optimización (sección 3, 4 y 5 del arranque) SIN reiniciar, relanzando los servicios.
# (Un reboot de la TV también restaura todo por sí solo.)
# Los preloads de Netflix/YouTube se rearman solos al abrir la app o al reiniciar.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== Relanzando servicios LG =="
"$HERE/tvroot.sh" '
initctl start iepg 2>/dev/null || true
initctl start second-screen-gateway 2>/dev/null || true
initctl start airplay-adaptor 2>/dev/null || true
initctl start iot-client 2>/dev/null || true
# fase 2 (optimización 2026-10-23 noche)
touch /var/lib/webosbrew/appcloser/VIGILANTE-OFF   # vigilante que cierra apps (corre dentro de botones.py)
for j in webos-preload-manager btaudiosnk btaudiosrc miracast dmr ssdp-discovery-lgtv; do initctl start $j 2>/dev/null || true; done
echo "servicios relanzados (acr2/airplay/iot/homekit/upnpd vuelven on-demand o al reiniciar)"
'
echo "Vigilante apagado (appcloser/VIGILANTE-OFF; para prenderlo de nuevo, borrar ese archivo)."
echo "Para que tampoco se corte la precarga al prender: crear /var/lib/webosbrew/appcloser/DISABLED"
echo "y sacar las líneas de la sección 4 de /var/lib/webosbrew/init.d/50-cytv-debloat (o borrar ese archivo)."
echo "Publicidad del Home: ./adblock.sh off"

echo "== Estado =="
"$HERE/tvroot.sh" 'for p in acr2 ss.gateway airplay iepg iot-client; do
  pidof $p >/dev/null 2>&1 && echo "  $p: VIVO" || echo "  $p: abajo (vuelve on-demand/al reboot)"; done'
echo "Nota: lo más seguro para revertir 100% es reiniciar la TV."
