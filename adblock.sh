#!/bin/bash
# adblock.sh on|off  — monta/desmonta el bloqueo de dominios de ads de LG (sin reiniciar).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
case "${1:-on}" in
  on)  "$HERE/tvroot.sh" 'mount | grep -q " /etc/hosts " && echo "ya activo" || { mount --bind /var/lib/webosbrew/hosts /etc/hosts && echo "adblock ON"; }' ;;
  off) "$HERE/tvroot.sh" 'umount /etc/hosts 2>/dev/null && echo "adblock OFF" || echo "no estaba montado"' ;;
  *) echo "uso: $0 on|off"; exit 1 ;;
esac
