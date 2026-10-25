#!/bin/bash
# tvshot.sh — captura la pantalla de la TV (lo que dibuja el compositor: Home QML, apps web, menús)
# Uso: tools/tvshot.sh [salida.png]   (por defecto ./tvshot.png)
# OJO: los luna-send van en PRIMER PLANO: por el SSH directo (dropbear) lo que queda en segundo plano se corta al cerrar la sesión.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-tvshot.png}"
"$HERE/tvroot.sh" 'rm -f /tmp/cap.png; luna-send -n 1 luna://com.webos.surfacemanager/captureCompositorOutput "{\"output\":\"/tmp/cap.png\",\"format\":\"PNG\"}" >/dev/null 2>&1; for i in 1 2 3 4 5 6 7 8; do [ -s /tmp/cap.png ] && break; sleep 1; done; sleep 1; chmod 644 /tmp/cap.png' >/dev/null 2>&1
ssh -i "$HOME/.ssh/tv_webos_dec" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa \
  -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -o ConnectTimeout=15 \
  -p 2222 root@127.0.0.1 'cat /tmp/cap.png' > "$OUT" 2>/dev/null
echo "captura: $OUT ($(stat -f %z "$OUT") bytes)"
