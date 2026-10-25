#!/bin/sh
# run.sh — corre botones.py (botones del control con otra función) y lo vuelve a prender si se cierra (a los 5 s).
# Lo arranca /var/lib/webosbrew/init.d/50-cytv-debloat al prender la tele. Su pid queda en /tmp/cytv-botones.pid.
# Si se cierra 5 veces seguidas en menos de 30 s cada una, deja de insistir (el control sigue andando de fábrica).
# Apagarlo: crear /var/lib/webosbrew/botones/DISABLED y matar el proceso python (kill del pid de botones.py).
B=/var/lib/webosbrew/botones
echo $$ > /tmp/cytv-botones.pid
fallas=0
while [ ! -f "$B/DISABLED" ]; do
  inicio=$(date +%s)
  python "$B/botones.py" </dev/null >/dev/null 2>/tmp/cytv-botones.err
  codigo=$?
  if [ $(( $(date +%s) - inicio )) -lt 30 ]; then fallas=$((fallas + 1)); else fallas=0; fi
  echo "$(date) botones.py terminó (código $codigo), se reinicia en 5 s — ver /tmp/cytv-botones.err" >> /tmp/cytv-botones.log
  if [ "$fallas" -ge 5 ]; then
    echo "$(date) botones.py no arranca: dejo de insistir (el control anda de fábrica)" >> /tmp/cytv-botones.log
    exit 1
  fi
  sleep 5
done
