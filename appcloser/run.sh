#!/bin/sh
# run.sh — corre el vigilante de apps y lo vuelve a prender si se cierra (a los 10 s).
# Lo arranca /var/lib/webosbrew/init.d/50-cytv-debloat al prender la tele. Su pid queda en /tmp/cytv-appcloser.pid.
# Apagar SOLO el vigilante: crear /var/lib/webosbrew/appcloser/VIGILANTE-OFF y matar el proceso node (kill del pid de node).
# (appcloser/DISABLED también lo apaga, y además deja de cortar la precarga de apps en el arranque.)
AC=/var/lib/webosbrew/appcloser
echo $$ > /tmp/cytv-appcloser.pid
export NODE_PATH=/usr/lib/nodejs
while [ ! -f "$AC/DISABLED" ] && [ ! -f "$AC/VIGILANTE-OFF" ]; do
  node "$AC/appcloser.js" </dev/null >/dev/null 2>/tmp/cytv-appcloser.err
  echo "$(date) vigilante terminó (código $?), se reinicia en 10 s — ver /tmp/cytv-appcloser.err" >> /tmp/cytv-appcloser.log
  sleep 10
done
