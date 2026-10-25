# Debloat de la LG 50UM7360 — qué hicimos y resultados

Aplicado en vivo el **2026-10-23**. Objetivo: bajar la presión de **swap sobre flash**
(el thrashing que hace lenta la TV) liberando RAM de bloat y apps precargadas.

## Resultado (medido)

| Métrica | Base | Después | Ganancia |
|---|---|---|---|
| RAM usada | 701 MB | **596 MB** | −105 MB |
| Swap en uso | 359 MB | **269 MB** | **−90 MB** |
| Disponible | 222 MB | **322 MB** | +100 MB |

Nada se rompió. Netflix/YouTube siguen abriendo normal (solo pierden un pelín de
arranque la primera vez, porque ya no están precargados).

## Qué se paró y cómo

| Objetivo | RAM aprox | Cómo se para | Nota |
|---|---|---|---|
| Netflix (preload GIBBON) | 67 MB | `pkill -f netflix.bin` | se rearma al abrir la app |
| YouTube (preload cobalt) | 66 MB | `pkill -f youtube.leanback.v4/cobalt` | idem |
| `acr2` (ACR/ads) | 10 MB | `kill` (on-demand del bus) | privacidad + RAM |
| `ss.gateway` | 9 MB | `initctl stop second-screen-gateway` | upstart (el usuario no usa mandar desde el celular) |
| ~~`iepg` (guía EPG)~~ | 6 MB | **ya no se para** (2026-10-23) | el menú de entradas del botón INPUT espera su respuesta: sin `iepg` el menú no se dibuja y el botón salta directo al HDMI |
| `airplay` | 7 MB | `initctl stop airplay-adaptor` + `kill` | no se usa |
| `iot-client` (ThinQ) | 5 MB | `initctl stop iot-client` + `kill -9` | ignora SIGTERM; no se usa |

Lo que **no** se tocó: la Home (`fullhome`), el compositor (`surface-manager`),
`inputcommon` (entradas HDMI), los `WebAppMgr` activos (romperían la UI), y
Homebrew Channel / Dev Mode (nuestro acceso).

## Fase 2 — optimización para el uso real (2026-10-23 noche)

Uso real de la tele: **Xbox por HDMI y apps de películas**. El usuario usa la voz y el navegador. **No usa** el audio Bluetooth ni mandar contenido desde el celular.
Relevamiento completo en [AUDITORIA.md](AUDITORIA.md) (script de solo lectura `tools/audit.sh`).

| Cambio | Ganancia | Cómo |
|---|---|---|
| Publicidad en video del Home bloqueada (`alphonso.tv` en `hosts.block`) | ~50 MB + 35–50 % de un núcleo con el Home oculto | `hosts.block` |
| Caché de publicidad vaciada (`/mnt/lg/cmn_data/admanager/cache`) | 61 MB de disco | ⚠ el banner oculto (Hero) quedó reintentando; lo neutraliza el Hero.qml de home-mod (otra sesión) |
| Precarga de apps apagada (`initctl stop webos-preload-manager`) | ~230 MB (YouTube, Netflix, Amazon, Assistant, Guía, Tips, navegador) | init.d sección 3 |
| **Vigilante de apps** (`botones/vigilante.py`, dentro de `botones.py`) | cierra las apps de usuario que quedan abiertas y libera la memoria que el protector deja en las entradas | init.d sección 6; log `/tmp/cytv-appcloser.log` |
| Mandar desde el celular apagado: `airplay-adaptor`, `second-screen-gateway` (ss.gateway, app ThinQ), `miracast`, `dmr`, `upnpd`, `ssdp-discovery-lgtv`, `homekit` | ~100 MB (la app AirPlay sola: 75 MB) | init.d sección 4 |
| Audio Bluetooth apagado (`btaudiosnk`, `btaudiosrc`) | ~5 MB | init.d sección 4; el control Magic Remote sigue andando (`lginput2`) |
| Restos temporales míos en `/tmp` (está en RAM) | 26 MB | borrados |

**Resultado medido** (en reposo, HDMI sin señal): RAM disponible **138 → 377 MB**, swap usada **353 → ~270 MB**, procesador ocupado **69 % → ~26 %**.

### Vigilante de apps — reglas
Desde el 2026-10-25 es `botones/vigilante.py` y corre **dentro del mismo programa que los botones del control**
(`botones/botones.py`, Python 2.7 que ya trae la tele). Antes era `appcloser/appcloser.js` en Node: el motor de Node
solo ya ocupaba ~32 MB; ahora el programa entero (botones + vigilante) ocupa ~4 MB.

- Cada 5 s le pregunta a la tele qué app está al frente (`getForegroundAppInfo` con `luna-send`, sin suscripción:
  ver "Error del 2026-10-24" abajo). Al cambiar a otra app o entrada (Netflix → YouTube, Netflix → HDMI de la Xbox),
  a los 5 s cierra las demás **apps de usuario** abiertas.
- **Inicio quieto 1 minuto → cierra las de atrás.** Antes, si salías de Netflix al inicio, Netflix quedaba abierto
  (60–90 MB) hasta abrir otra app.
- **Entradas sin usar 2 minutos y con más de 100 MB → se cierran por detrás.** El protector de fotos de "Sin señal"
  deja la parte de entradas de LG (`com.webos.app.inputcommon`, que también es la que muestra el HDMI) en ~110 MB en
  vez de ~83 MB. Si estás en otra cosa, se cierra; LG la vuelve a abrir sola al elegir una entrada.
- **Antes de cerrar vuelve a preguntar qué está al frente en ese momento.** Si la tele no contesta, no cierra nada;
  lo que está al frente no se cierra nunca. Si la tele estuvo dormida (el reloj saltó más de 60 s), espera 30 s.
- No cierra nada del sistema (`com.webos.*`, `com.palm.*`, `com.lge.*`) salvo lo que abre la precarga: Guía
  (livemenu), Consejos, navegador y Alexa. El Asistente de Google se deja abierto: la tele lo reabre sola.
- Apps "tercas" que siguen abiertas después de 2 pedidos de cierre (ej. la app web de AirPlay): si son web se cierran
  con `luna://com.palm.webappmanager/killApp`; si son nativas, con SIGKILL.
- Que aparezca el protector, el volumen, el menú de entradas o el asistente encima de Netflix **no** cuenta como
  cambio de app: la película pausada no se cierra.
- Cada 5 min hace una pasada para cerrar lo que se haya abierto solo.
- `luna-send` sin terminal a veces no hace la llamada: el programa le da una terminal de mentira (`os.openpty`).
- Apagar **solo el vigilante**: crear `/var/lib/webosbrew/appcloser/VIGILANTE-OFF` (se lee en cada vuelta, no hace
  falta reiniciar). Con `appcloser/DISABLED` se apaga también el corte de la precarga de apps al prender.
- **Error del 2026-10-24:** el vigilante viejo se suscribía a `getForegroundAppInfo`. Cuando la tele "despierta" del
  quick start sin reiniciarse, la suscripción queda muerta sin avisar, y el vigilante seguía creyendo que al frente
  estaba el HDMI: cada 5 minutos cerraba YouTube mientras se miraba. Por eso pregunta en cada vuelta y verifica justo
  antes de cerrar.
- Lo sube `tools/deploy-home.sh` (carpeta `botones/` → `/var/lib/webosbrew/botones/`) y lo arranca el inicio
  automático (sección 6) con `botones/run.sh`, que lo vuelve a prender si se cierra.

### Lecciones
- **Antes de parar un servicio, ver si una pantalla del sistema lo espera.** El menú de entradas (`/usr/lib/qt5/qml/InputPicker`) solo se dibuja cuando responden 6 servicios, entre ellos `iepg`.
- Vaciar el caché de publicidad hace que el banner oculto reintente sin parar: hay que neutralizar `Hero.qml`.
- Algunos servicios los lanza el bus a pedido (su padre es `ls-hubd`): vuelven solos si algo los llama (`upnpd`, `homekit`, `admanager`).

## Cómo se aplica

Todo se aplica **solo, cada vez que se prende la tele**, desde `/var/lib/webosbrew/init.d/50-cytv-debloat`
(este repo: `init.d-50-cytv-debloat.sh`). Lo dispara el arranque automático de Homebrew Channel; cómo se logró
eso, y por qué no se pudo usar `start-devmode.sh` (LG lo firma), está en [PERSISTENCIA.md](PERSISTENCIA.md).

```bash
tools/reinstalar-todo.sh   # sube todo y pregunta qué servicios opcionales apagar
./restore-services.sh      # deshace sin reiniciar (relanza los servicios)
```

Opciones (archivos que crea o borra `reinstalar-todo.sh` en la tele):
- `/var/lib/webosbrew/apagar-transmision` → apaga AirPlay, Miracast, DLNA, app LG ThinQ, HomeKit e `iot-client` (~100 MB).
- `/var/lib/webosbrew/apagar-audio-bt` → apaga el audio Bluetooth. El control remoto sigue andando.

## Publicidad / "Tendencia ahora" / recomendaciones del Home

El Home (`com.webos.app.fullhome`) arma esas filas con datos de servicios locales
**y de servidores de LG**. Dos capas:

1. **Servicios parados** (en el arranque, sección 4): `admanager` (ads), `contentminer`
   (recomendaciones), `uploadd` + `remotelogger` (telemetría que sube tu uso).
2. **Bloqueo de dominios** (lo que realmente vacía las filas): bind-mount de un
   `/etc/hosts` propio (`/var/lib/webosbrew/hosts`) que manda los dominios de ads /
   recomendaciones / telemetría de LG a `0.0.0.0`. El rootfs es read-only, por eso se
   monta encima con `mount --bind` (se re-monta en cada boot desde el init.d).

Dominios bloqueados: `*.lgsmartad.com`, `ad.lgappstv.com`, `ngfts.lge.com`,
`aic-ngfts.lge.com`, `snc.lge.com`, `lge.com.edgesuite.net`,
`eic.lgchhomeapp.lgtvcommon.com` (Home), `yumenetworks.com`, `smartclip.net`, y
telemetría `eic.lgtviot.com`, `*.lgthinq.com`, `config/tracking.lgtvsdp.com`.
Lista completa en `hosts.block`. (NO se bloquean los dominios de la tienda de apps.)

Control sin reiniciar:
```bash
./adblock.sh on     # monta el bloqueo
./adblock.sh off    # lo saca
```

Para que el Home refleje el bloqueo hay que recargarlo (cerrar/abrir la app Home o
reiniciar la TV); si no, muestra lo cacheado.

## Rootfs es solo-lectura

El `/` de la TV es un overlay `ro`, así que no se pueden editar `/etc/init` ni los
registros de servicio. Por eso el debloat se hace parando procesos/jobs en caliente
(y se repite en cada arranque vía el `init.d/` de webosbrew en `/var`, que sí es escribible).
