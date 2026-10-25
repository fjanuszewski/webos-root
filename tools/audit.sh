#!/bin/sh
# audit.sh — relevamiento de SOLO LECTURA de la TV (corre como root en la TV; no cambia nada).
# Uso desde la Mac: tools/audit-run.sh  (sube este script, lo corre con tvroot y trae el resultado)
OUT=/tmp/cytv-audit.txt
exec > "$OUT" 2>&1

sec() { echo; echo "===== $* ====="; }

sec "GENERAL"
date; uptime; cat /proc/loadavg
cat /proc/cpuinfo | grep -c ^processor | sed 's/^/núcleos: /'
free
grep -E "MemTotal|MemFree|MemAvailable|Buffers|^Cached|SwapCached|Active:|Inactive:|AnonPages|Mapped|Shmem:|Slab|SwapTotal|SwapFree|CmaTotal|CmaFree" /proc/meminfo
cat /proc/swaps
for f in /sys/block/zram*/disksize /sys/block/zram*/mem_used_total /sys/block/zram*/comp_algorithm; do [ -f $f ] && echo "$f: $(cat $f)"; done
echo "swappiness: $(cat /proc/sys/vm/swappiness)"
grep -E "^cpu " /proc/stat

sec "CPU EN 10 s (por proceso: ticks de CPU usados en la ventana; 100 ticks = 1 núcleo durante 1 s)"
for p in /proc/[0-9]*; do n=${p#/proc/}; set -- $(cat $p/stat 2>/dev/null | sed 's/^.*) //'); [ -n "$1" ] && echo "$n $(( ${12} + ${13} ))"; done > /tmp/a1
S1=$(grep -E "^cpu " /proc/stat)
sleep 10
S2=$(grep -E "^cpu " /proc/stat)
for p in /proc/[0-9]*; do n=${p#/proc/}; set -- $(cat $p/stat 2>/dev/null | sed 's/^.*) //'); [ -n "$1" ] && echo "$n $(( ${12} + ${13} ))"; done > /tmp/a2
echo "cpu antes:   $S1"; echo "cpu después: $S2"
awk 'NR==FNR{a[$1]=$2;next} ($1 in a){d=$2-a[$1]; if(d>0) print d, $1}' /tmp/a1 /tmp/a2 | sort -rn | head -25 | while read d pid; do
  echo "$d ticks  pid=$pid  $(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null | cut -c1-110)"
done

sec "PROCESOS (RSS = RAM real, SWAP = mandado a swap; en kB) ordenados por RSS+SWAP"
echo "RSS SWAP PID PPID ESTADO CPU_TOTAL(s) NOMBRE / COMANDO"
for p in /proc/[0-9]*; do
  n=${p#/proc/}
  [ -r $p/status ] || continue
  rss=$(awk '/^VmRSS/{print $2}' $p/status); sw=$(awk '/^VmSwap/{print $2}' $p/status)
  [ -z "$rss" ] && continue
  st=$(awk '/^State/{print $2}' $p/status); pp=$(awk '/^PPid/{print $2}' $p/status)
  set -- $(sed 's/^.*) //' $p/stat 2>/dev/null)
  cpu=$(( (${12:-0} + ${13:-0}) / 100 ))
  cmd=$(tr '\0' ' ' < $p/cmdline 2>/dev/null | cut -c1-120)
  echo "$rss ${sw:-0} $n $pp $st $cpu $cmd"
done | sort -k1,1nr -k2,2nr | awk '{t=$1+$2; print t" "$0}' | sort -rn | cut -d' ' -f2- | head -90
echo
echo "total procesos: $(ls -d /proc/[0-9]* | wc -l)  hilos kernel en D: $(for p in /proc/[0-9]*; do awk '/^State/{print $2}' $p/status 2>/dev/null; done | grep -c D)"

sec "UPSTART: trabajos corriendo"
initctl list 2>/dev/null | grep -E "start/running" | sort
sec "UPSTART: trabajos parados"
initctl list 2>/dev/null | grep -E "stop/waiting" | awk '{print $1}' | tr '\n' ' '; echo

sec "APPS ABIERTAS (applicationManager)"
luna-send -n 1 -f luna://com.webos.applicationManager/running '{}' 2>/dev/null | grep -E '"id"|"processid"|"defaultWindowType"' | tr -d ' ' | paste - - - 2>/dev/null
sec "PRECARGA DE APPS (preloadmanager)"
ls -la /etc/palm/preloadmanager* /usr/share/preloadmanager* /var/preferences/preloadmanager* 2>/dev/null
for f in $(ls /etc/palm/preloadmanager*/* /usr/share/preloadmanager*/* 2>/dev/null | head -10); do echo "--- $f"; head -c 1500 $f; echo; done
grep -h "NL_APP_LAUNCH_BEGIN" /var/log/messages | grep preloadmanager | sed 's/.*app_id":"\([^"]*\)".*/\1/' | sort | uniq -c | sort -rn

sec "CHECKPOINTS CRIU (apps congeladas listas para abrir rápido)"
du -sk /tmp/checkpoint/* /mnt/lg/cmn_data/checkpoint/* 2>/dev/null

sec "DISCOS"
df -k 2>/dev/null | grep -v -E "^(tmpfs|devtmpfs)" | head -40
echo; df -k 2>/dev/null | grep -E "tmpfs"

sec "TEMPORALES Y REGISTROS (kB)"
du -sk /tmp /var/tmp /var/log /var/log/* /var/spool /var/cache /var/crash /mnt/lg/cmn_data/* /var/lib/* /var/db 2>/dev/null | sort -rn | head -40
echo; echo "--- más grandes en /tmp"
du -sk /tmp/* 2>/dev/null | sort -rn | head -15
echo; echo "--- core dumps / crash"
ls -la /var/log/crashd /var/log/reports /tmp/*core* /var/crash 2>/dev/null | head -30

sec "ARRANQUE: init.d de webosbrew y scripts propios"
ls -la /var/lib/webosbrew/init.d /var/lib/webosbrew/startup.sh 2>/dev/null
tail -n 5 /var/lib/webosbrew/cytv-debloat.log 2>/dev/null
sec "ARRANQUE: trabajos de upstart que se inician solos (start on ...) — cantidad y lista"
ls /etc/init/*.conf 2>/dev/null | wc -l
for f in /etc/init/*.conf; do s=$(grep -m1 -E "^start on" $f | cut -c1-80); echo "$(basename $f .conf): $s"; done 2>/dev/null | head -250

sec "SERVICIOS DE RED ESCUCHANDO"
netstat -ltnup 2>/dev/null | head -50 || netstat -ltn | head -50

sec "MONTAJES PROPIOS"
mount | grep -E "webosbrew|/etc/hosts"
echo FIN
