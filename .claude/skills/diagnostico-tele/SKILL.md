---
name: diagnostico-tele
description: Medir e interpretar cómo está una tele LG webOS rooteada (memoria, swap, procesador, procesos, servicios, apps abiertas, si el arranque automático corrió). Usala cuando pregunten por qué la tele está lenta, cuánta memoria tiene, qué está corriendo, o para verificar después de un reinicio o un corte de luz.
---

# Diagnóstico de la tele (solo lectura)

**Nunca cambies nada durante un diagnóstico.** Si encontrás algo para arreglar, proponelo y pedí OK.

## Medición completa
`tools/audit-run.sh` → guarda `audit/audit-FECHA.txt` (no se publica). Incluye: memoria, swap/zram, procesador en 10 s por proceso, procesos por RAM+swap, trabajos de upstart, precargas, checkpoints CRIU, discos, temporales y arranque.

## Chequeos rápidos (`./tvroot.sh '...'`)
- ¿Arrancó lo nuestro? `tail -n 1 /var/lib/webosbrew/cytv-debloat.log` (tiene que tener la fecha del último encendido, `homemod=…`, `saver=…`, `botones=…`).
- Montajes: `mount | grep -E "fullhome|screensaver|inputcommon|hosts"`.
- Vigilante (corre dentro de `botones.py`): `tail /tmp/cytv-appcloser.log` y `cat /tmp/cytv-botones.pid`.
- Memoria: `grep -E "MemAvailable|SwapFree|SwapTotal" /proc/meminfo`.
- Apps abiertas: desde Node, `require('/usr/lib/nodejs/palmbus')` → `luna://com.webos.applicationManager/running` (`luna-send` sin terminal sale vacío).

## Cómo interpretar
- **"load average" ~30**: es normal en este chip. Son hilos del driver de video en estado D, no carga real. Medí el procesador con `/proc/stat`.
- **kswapd0 alto**: falta RAM. Mirá qué apps hay abiertas y si la precarga volvió.
- **Valores de referencia** (LG 50UM7360, en reposo): ~280–380 MB disponibles, swap <300 MB, procesador ~25 %. Antes de optimizar: 138 MB y 69 %. Ver `AUDITORIA.md`.
- `admanager`, `upnpd` u `homekit` vivos: los lanza el bus a pedido (padre `ls-hubd`). No es grave si la publicidad está bloqueada.
- Pantalla de inicio gastando procesador estando oculta: buscá publicidad en `/var/log/fullhome` (`Promotion`, `mediaPlayer`, `Hero`).
- Capturas (`tools/tvshot.sh`): sobre video o HDMI pueden salir con la parte de abajo negra. Es la captura, no la tele.
