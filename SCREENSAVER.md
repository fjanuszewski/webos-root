# Protector de pantalla con fotos de Google Photos

Estado (2026-10-23): **funcionando** en la pantalla "Sin señal" de las entradas (HDMI sin señal). Verificado con capturas: fotos del álbum, verticales con fondo desenfocado, fecha y hora.

## Qué hace
- Álbum: `cleanhome/saver/config.json` → tu álbum compartido (`https://photos.app.goo.gl/…`). Se recorre el álbum entero (el nuestro: ~8.400 ítems, ~7.500 fotos; los videos se descartan) El álbum entero se relee cada 6 h (`saver/album.json`) y **cada 1 h** se arma una lista nueva de `max` fotos (300 por defecto) elegidas al azar entre las que **todavía no salieron** en la vuelta (`saver/usadas.json`): la lista es liviana y pasan todas (con ~7.500 fotos, una vuelta completa en ~25 h).
- De a **una foto al azar**, cargada directo de Google en memoria (`URL=w1920-h1080`). En disco solo queda la lista (`saver/index.json`, ~60 KB).
- Como máximo 2 fotos en memoria: la que se ve y la siguiente, que se precarga. La vieja se vacía después del fundido (1,5 s).
- Cada foto se ve **10 s como mínimo**. Si la siguiente no llegó, espera. Con **190 s** sin llegar prueba otra; si da error, otra a los 5 s. No repite las últimas ~30.
- La primera foto de cada vez es, si hay, una "de un día como hoy" de otro año ("Hace N años").
- Textos: fecha de la foto, hora, clima de Córdoba (open-meteo).
- **Editor visual** (2026-10-24): el botón del protector (barra de arriba) lo abre; "Editar" muestra el mismo protector con 6 partes marcadas (arriba y abajo: izquierda, centro, derecha). En cada parte se elige qué va (Nada, Hora, Fecha, Hora y fecha, Clima, Hora + fecha + clima, Evento de ahora, Próximo evento, Fecha de la foto) y el tamaño (chica, mediana, grande). Al medio: encendido, segundos por foto y álbum. Archivos: `SaverEditor.qml` (editor), `SaverWidget.qml` (cada pieza), `settings.js` (`SAVER_SLOTS`, `SAVER_WIDGETS`, `SAVER_SIZES`, `saverLayout()`). Se guarda en `settings.json → saver.layout`; si no existe, se usa la distribución de siempre (eventos arriba, fecha de la foto abajo a la izquierda, hora + fecha + clima abajo a la derecha).
- Modo noche de 0 a 7 h (oscurece). El texto se corre unos píxeles por minuto para no marcar la pantalla.

## Dónde se engancha (hay DOS protectores en la TV)
| Cuándo aparece | App de LG | Archivo reemplazado (bind-mount) | Nuestra copia |
|---|---|---|---|
| Entrada sin señal (HDMI, AV) | `com.webos.app.inputcommon`, componente `photoSlide` (fotos de stock de LG: Berlín, Bora Bora, Hallstatt) | `qml/TvComponent/ScreenSaver/PhotoSlide.qml` | `inputcommon-mod/TvComponent/ScreenSaver/PhotoSlide.qml` |
| Home / apps de LG quietas | `com.webos.app.screensaver` (burbujas + modo publicidad) | `qml/Containers/MainView.qml` | `saver-mod/Containers/MainView.qml` (sin publicidad) |

Los dos cargan `file:///var/lib/webosbrew/cleanhome/CleanSaver.qml` (+ `PhotoLayer.qml`). Si no carga o la lista está vacía, queda el original de LG como respaldo.

Ojo: si la entrada **tiene** señal (un aparato conectado con su propio protector) o una app como YouTube está abierta, se ve el protector de ese aparato/app, no el nuestro.

## Archivos
- `cleanhome/CleanSaver.qml`, `cleanhome/PhotoLayer.qml` — el protector.
- `cleanhome/saver/sync.js` — arma la lista (Node 0.12, ES5). Lee la página pública del álbum compartido: `AF_initDataCallback` `ds:1`, cada ítem `["AF1Qip…", [url, ancho, alto], fechaMs, …]`. La página trae solo los primeros 300 ítems y un código de continuación (`data[2]`): las tandas siguientes se piden de a 300 con un POST a `https://photos.google.com/_/PhotosUi/data/batchexecute`, `f.req=[[["snAcKc","[idÁlbum, código, null, key]",null,"generic"]]]` (`key` es el de la dirección del álbum). Google no tiene forma oficial de pedir una foto al azar: por eso se arma la lista. Video = ítem con un objeto con clave `76647426`. "Foto con movimiento" = `146008172` (se deja).
- `saver-backup/`, `inputcommon-backup/` — originales de LG. En la TV también en `/var/lib/webosbrew/screensaver-backup/`.
- Log del sync: `/tmp/cleanhome-saver.log`. Log del protector de entradas: `/var/log/inputcommon` (buscar `[cytv]`).

## Comandos
```bash
tools/deploy-saver.sh -          # sube todo, arma la lista, monta y reinicia inputcommon (sin captura)
tools/tvshot.sh captura.png      # captura (en video/HDMI la parte de abajo puede salir negra: es la captura, no la tele)
```
- Al prender: `init.d-50-cytv-debloat.sh` monta los dos archivos y arranca el loop de sync (al minuto y cada 6 h, pid en `/tmp/cleanhome-saver.pid`). El protector relee la lista cada hora.
- **Apagarlo**: crear `/var/lib/webosbrew/saver-mod/DISABLED` y reiniciar la tele (o `umount` de los dos archivos y matar `com.webos.app.inputcommon` / `com.webos.app.screensaver`).

## Gotchas
- Los checkpoints CRIU: `inputcommon` arranca de `/tmp/checkpoint/com.webos.app.inputcommon` → hay que borrarlo y matar el proceso para que lea el archivo montado.
- `prisoner` no puede leer `/var/lib/webosbrew/cleanhome` → verificar como root (`tvroot.sh`).
- `luna-send launch com.webos.app.screensaver` y `tvpower/power/turnOnScreenSaver` no lo muestran a pedido; se prueba dejando la tele quieta.
- No hacer `grep -r` grandes en la tele (load ~31 por hilos del kernel; un grep quedó colgado comiendo CPU).
