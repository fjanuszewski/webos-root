#!/bin/bash
# restore-chain.sh — restaura la cadena de acceso Mac -> telefono -> TV webOS.
# Lo que se cae con cada reboot/desconexion es el `adb forward` (y a veces el relay).
# Correr esto deja todo operativo de nuevo. Es idempotente.
set -euo pipefail

# Datos de esta instalación (serial del teléfono e IP de la TV): config.local.sh, que no se publica.
# Modelo: config.example.sh
. "$(dirname "$0")/config.local.sh" 2>/dev/null || { echo "Falta config.local.sh (copiá config.example.sh y completalo)"; exit 1; }
KEY="$HOME/.ssh/tv_webos_dec"

echo "== 1. Telefono por adb =="
adb devices -l | grep -q "$PHONE" || { echo "ERROR: no veo el telefono $PHONE por adb (conecta USB / autoriza)"; exit 1; }
echo "OK: $PHONE conectado"

echo "== 2. Relay nc en el telefono =="
# puerto en el teléfono → puerto en la TV:
#   2222 → 22   SSH root propio de Homebrew (acceso principal)
#   9922 → 9922 SSH del modo desarrollador (solo mientras exista; para rootear con Dev Manager)
#   9991 → 9991 Key Server del modo desarrollador (para bajar la llave)
for par in "2222 22" "9922 9922" "9991 9991"; do
  set -- $par
  if adb -s "$PHONE" shell "toybox ps -A -o ARGS 2>/dev/null | grep -q 'nc -L -p $1 '"; then
    echo "OK: relay $1 → TV:$2 ya vivo"
  else
    echo "Relay $1 caído → levantando (TV:$2)"
    adb -s "$PHONE" shell "nohup nc -L -p $1 nc $TV_IP $2 >/dev/null 2>&1 &"
  fi
done
sleep 2

echo "== 3. adb forward en la Mac =="
adb -s "$PHONE" forward tcp:2222 tcp:2222
adb -s "$PHONE" forward tcp:9922 tcp:9922
adb -s "$PHONE" forward tcp:9991 tcp:9991
adb -s "$PHONE" forward --list

echo "== 4. Probar SSH (prisoner) + root =="
"$(dirname "$0")/tvroot.sh" 'echo root_ok: $(id -u); free -m | awk "/Mem|Swap/{print}"'

echo "== Listo: cadena operativa =="
