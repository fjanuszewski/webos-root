#!/bin/bash
# tvroot.sh — ejecuta un comando como ROOT en la TV LG webOS.
# Uso: ./tvroot.sh 'comando shell'
#
# Camino principal (desde 2026-10-23): SSH propio de Homebrew Channel (dropbear, root, SOLO con nuestra llave),
#   TV:22 <- relay del teléfono :2222 <- adb forward tcp:2222 en la Mac. No depende del modo desarrollador.
# Camino de respaldo: SSH del modo desarrollador (prisoner, :9922) + bridge exec de Homebrew Channel
#   (luna://org.webosbrew.hbchannel.service/exec). Solo si el principal no responde.
set -o pipefail
CMD="$*"
SSHOPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
         -o PubkeyAcceptedAlgorithms=+ssh-rsa -o HostKeyAlgorithms=+ssh-rsa
         -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1
         -o ConnectTimeout=10 -o BatchMode=yes -i "$HOME/.ssh/tv_webos_dec")

# 1) Directo como root (puerto 2222). Con terminal (-tt): sin terminal, luna-send falla de forma intermitente
#    (a veces no hace la llamada y no avisa). Con -tt la salida trae \r y stderr va junto con stdout.
#    OJO: lo que se deje corriendo en segundo plano tiene que ir con nohup (al cerrar la terminal llega SIGHUP).
#    El comando viaja en base64 y se corre desde un archivo temporal: así su texto NUNCA aparece en la línea de
#    comandos de un proceso, y un `pkill -f algo` dentro del comando no mata a la propia sesión.
B64=$(printf '%s' "$CMD" | base64 | tr -d '\n')
ssh -tt "${SSHOPTS[@]}" -p 2222 root@127.0.0.1 \
  "F=/tmp/tvroot.\$\$.sh; echo $B64 | base64 -d > \$F; sh \$F </dev/null; R=\$?; rm -f \$F; exit \$R" </dev/null | tr -d '\r'
RC=${PIPESTATUS[0]}
[ "$RC" -ne 255 ] && exit "$RC"     # 255 = no se pudo conectar; cualquier otro código es del comando

# 2) Respaldo: modo desarrollador + bridge exec
echo "[tvroot] SSH directo no responde: uso el modo desarrollador (9922) como respaldo" >&2
CMD_B64=$(printf '%s' "$CMD" | base64 | tr -d '\n')
RESP=$(ssh "${SSHOPTS[@]}" -p 9922 prisoner@127.0.0.1 \
  "/usr/bin/luna-send-pub -n 1 -t 1 luna://org.webosbrew.hbchannel.service/exec '{\"command\":\"echo $CMD_B64 | base64 -d | sh\"}'" 2>&1)
python3 - "$RESP" <<'PY'
import sys, re, base64, json
resp = sys.argv[1]
m = re.findall(r'payload (\{.*\})', resp)
if not m:
    sys.stderr.write("[sin payload / error de conexion]\n" + resp + "\n"); sys.exit(1)
d = json.loads(m[-1])
if not d.get("returnValue", False):
    sys.stderr.write("[exec returnValue=false] " + json.dumps(d)[:300] + "\n")
sys.stdout.write(base64.b64decode(d.get("stdoutBytes", "")).decode(errors="replace"))
err = base64.b64decode(d.get("stderrBytes", "")).decode(errors="replace")
if err.strip():
    sys.stderr.write("[stderr]\n" + err)
PY
