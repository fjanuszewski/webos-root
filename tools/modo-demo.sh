#!/bin/bash
# modo-demo.sh — para sacar capturas sin datos personales: pone en la tele un calendario inventado y fotos libres
# (picsum.photos, licencia Unsplash) en el protector. Tus archivos se guardan aparte y vuelven con "off".
# Mientras está prendido, cal/sync.js y saver/sync.js no pisan nada (ven el archivo DEMO).
# Uso: tools/modo-demo.sh on | off
# Lo que NO cubre: nombres de redes Wi-Fi vecinas (taparlos en la captura) y la ciudad del clima.
set -euo pipefail
cd "$(dirname "$0")/.."
C=/var/lib/webosbrew/cleanhome
SSH=(ssh -i "$HOME/.ssh/tv_webos_dec" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
     -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa
     -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -o ConnectTimeout=15
     -p 2222 root@127.0.0.1)

case "${1:-}" in
on)
  # Eventos de mentira para esta semana (hora de la tele: UTC-3) y fotos libres
  python3 - > /tmp/demo-events.json <<'EOF'
import json, time, datetime
tz = datetime.timezone(datetime.timedelta(hours=-3))
hoy = datetime.datetime.now(tz).replace(hour=0, minute=0, second=0, microsecond=0)
def ev(dias, h, m, dur, titulo, todo=False):
    ini = hoy + datetime.timedelta(days=dias, hours=0 if todo else h, minutes=0 if todo else m)
    fin = ini + (datetime.timedelta(days=1) if todo else datetime.timedelta(minutes=dur))
    return {"start": int(ini.timestamp() * 1000), "end": int(fin.timestamp() * 1000), "allDay": todo,
            "day": ini.strftime("%Y-%m-%d"), "title": titulo, "location": "", "description": ""}
evs = [ev(-1, 18, 0, 60, "Clase de guitarra"), ev(0, 19, 30, 90, "Fútbol 5"), ev(0, 21, 0, 120, "Cena con amigos"),
       ev(1, 0, 0, 0, "Cumple de Ana", True), ev(1, 13, 0, 180, "Asado familiar"), ev(2, 10, 30, 45, "Dentista"),
       ev(3, 18, 0, 60, "Clase de inglés"), ev(4, 9, 0, 60, "Reunión de trabajo"), ev(5, 20, 0, 150, "Cine")]
d = {"updated": int(time.time() * 1000), "name": "Demo", "from": evs[0]["start"], "to": evs[-1]["end"], "events": evs}
print(json.dumps(d))
EOF
  python3 - > /tmp/demo-index.json <<'EOF'
import json, time
# fotos de picsum.photos (licencia Unsplash). "?d" hace que el "=w..-h.." que agrega el protector quede como parámetro
h = [1018, 1015, 1016, 1036, 1039, 1043, 1044, 1047, 1050, 1057, 15, 28, 29, 54, 65]
v = [1025, 1062, 177, 237, 1074]
ts = int(time.time() * 1000) - 86400000 * 400
ph = [{"url": "https://picsum.photos/id/%d/1920/1080?d" % i, "w": 1920, "h": 1080, "ts": ts - n * 86400000 * 37} for n, i in enumerate(h)]
ph += [{"url": "https://picsum.photos/id/%d/1080/1920?d" % i, "w": 1080, "h": 1920, "ts": ts - n * 86400000 * 53} for n, i in enumerate(v)]
print(json.dumps({"updated": int(time.time() * 1000), "total": len(ph), "photos": ph}))
EOF
  "${SSH[@]}" "cat > /tmp/demo-events.json" < /tmp/demo-events.json
  "${SSH[@]}" "cat > /tmp/demo-index.json" < /tmp/demo-index.json
  rm -f /tmp/demo-events.json /tmp/demo-index.json
  "${SSH[@]}" "set -e; C=$C
    if [ ! -f \$C/DEMO ]; then
      cp \$C/cal/events.json \$C/cal/events.json.real 2>/dev/null || true
      cp \$C/saver/index.json \$C/saver/index.json.real 2>/dev/null || true
    fi
    touch \$C/DEMO
    cp /tmp/demo-events.json \$C/cal/events.json; cp /tmp/demo-index.json \$C/saver/index.json
    echo 'modo demo prendido (calendario y fotos de mentira)'"
  ;;
off)
  "${SSH[@]}" "C=$C
    [ -f \$C/cal/events.json.real ] && mv \$C/cal/events.json.real \$C/cal/events.json
    [ -f \$C/saver/index.json.real ] && mv \$C/saver/index.json.real \$C/saver/index.json
    rm -f \$C/DEMO; touch \$C/cal/pedido
    echo 'modo demo apagado (volvieron tu calendario y tus fotos)'"
  ;;
*) echo "uso: $0 on | off"; exit 1;;
esac
