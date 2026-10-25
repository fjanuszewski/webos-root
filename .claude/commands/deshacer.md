---
description: Vuelve atrás lo que la persona elija (servicios, publicidad, pantalla de inicio, protector, vigilante de apps o todo)
---

Preguntale a la persona **qué quiere deshacer** y explicale qué pasa con cada opción:

| Opción | Cómo | Efecto |
|---|---|---|
| Servicios y apertura automática de apps (ahora) | `./restore-services.sh` | vuelven en el momento, sin reiniciar; al prender la tele se vuelven a apagar |
| Solo el vigilante que cierra apps | `touch /var/lib/webosbrew/appcloser/VIGILANTE-OFF` (lo lee solo en segundos; no hace falta matar nada) | las apps quedan abiertas al cambiar; la precarga sigue apagada |
| Apertura automática de apps y vigilante (siempre) | `touch /var/lib/webosbrew/appcloser/DISABLED` y reiniciar | la tele vuelve a precargar apps y nadie las cierra |
| Solo la transmisión desde el celular | borrar `/var/lib/webosbrew/apagar-transmision` y reiniciar la tele | AirPlay, Miracast, etc. vuelven |
| Solo el audio Bluetooth | borrar `/var/lib/webosbrew/apagar-audio-bt` y reiniciar | |
| Bloqueo de publicidad | `./adblock.sh off` | vuelve la publicidad de LG |
| Pantalla de inicio propia | `touch /var/lib/webosbrew/home-mod/DISABLED` y reiniciar | vuelve la de LG |
| Protector de fotos | `touch /var/lib/webosbrew/saver-mod/DISABLED` y reiniciar | vuelve el de LG |
| Todo lo nuestro al prender | borrar `/var/lib/webosbrew/init.d/50-cytv-debloat` y reiniciar | la tele arranca como de fábrica (el root y el acceso quedan) |

Confirmá lo que elige, pedí OK, hacelo con `./tvroot.sh` y verificá que quedó como esperaba. Si dudás de un nombre de archivo, revisá `init.d-50-cytv-debloat.sh` antes.

$ARGUMENTS
