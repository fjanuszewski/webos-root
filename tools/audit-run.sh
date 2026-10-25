#!/bin/bash
# audit-run.sh — sube tools/audit.sh a la TV, lo corre como root (solo lectura) y guarda el resultado en audit/.
set -euo pipefail
cd "$(dirname "$0")/.."
SSH=(ssh -i "$HOME/.ssh/tv_webos_dec" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
     -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa
     -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -o ConnectTimeout=15 -o LogLevel=ERROR
     -p 2222 root@127.0.0.1)
mkdir -p audit
OUT="audit/audit-$(date +%Y%m%d-%H%M).txt"
"${SSH[@]}" 'cat > /tmp/cytv-audit.sh' < tools/audit.sh
./tvroot.sh 'sh /tmp/cytv-audit.sh; chmod 644 /tmp/cytv-audit.txt' >/dev/null 2>&1 || true
"${SSH[@]}" 'cat /tmp/cytv-audit.txt' > "$OUT"
echo "$OUT ($(wc -l < "$OUT") líneas)"
