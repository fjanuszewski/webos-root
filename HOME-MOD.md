# Home limpio — modificación del Home de LG (com.webos.app.fullhome)

Aplicado y verificado en la TV el **2026-10-23**. Resultado: el Home muestra solo la
barra superior (Buscar / Ajustes / Notificaciones) y la fila de apps. Sin publicidad,
sin "Tendencia ahora", sin recomendaciones, sin dashboard y sin el carrusel "Sponsored".

## Cómo está hecho el Home (webOS 4.5)

- Es una app **QML** (no HTML): `/usr/palm/applications/com.webos.app.fullhome/qml/`.
- Las filas se llaman **shelves** y se definen por `shelfId` en `qml/Model/Constants.js`.
  En producción: `HOME_SH_TOP` (barra superior), `HOME_SH_RECOMMENDED` (Tendencia ahora),
  `HOME_SH_APPS` (apps), `HOME_SH_HOMEDASHBOARD`. Aparte: `HOME_SH_ADVERTISEMENT`,
  `HOME_SH_CONTENT_PREVIEW` y shelves que manda el servidor de LG (SDX).
- El carrusel "Sponsored" **no es un shelf**: es el componente `Hero` dentro de
  `qml/UserInterfaceLayer/Containers/Main/TopShelf.qml`.
- El rootfs es read-only → los archivos se reemplazan con `mount --bind` desde
  `/var/lib/webosbrew/home-mod/`.

## Los dos archivos modificados

| Archivo | Cambio |
|---|---|
| `Model/ShelfList.js` | En `_filterShelfItem()`: whitelist, solo pasan `HOME_SH_TOP` y `HOME_SH_APPS`. |
| `UserInterfaceLayer/Containers/Main/TopShelf.qml` | Oculta `topShelfContainer` (Hero + flechas) y `TopDefaultAppsGuide`; altura del shelf = solo la barra de íconos; el foco ↓ desde los íconos va a las apps. |

Originales y modificados en este repo: `home-backup/` (originales) y `home-mod/` (modificados).
Backup completo del Home en la TV: `/var/lib/webosbrew/fullhome-backup/`.

## Gotchas (lo que costó descubrir)

1. **Snapshot CRIU.** El Home no se carga leyendo el QML: SAM lo restaura desde un
   checkpoint CRIU (`/tmp/checkpoint/com.webos.app.fullhome` y
   `/mnt/lg/cmn_data/checkpoint/com.webos.app.fullhome`). Reiniciar el proceso no
   alcanza: hay que **borrar el checkpoint** y relanzar con `{"snapshot":false}`.
2. **`HOME_SH_TOP` es estructural.** Dejar solo `HOME_SH_APPS` deja la pantalla en
   negro. El TOP se mantiene y se le oculta el carrusel por dentro.
3. **Blocklist no alcanza.** El servidor de LG agrega shelves que no conocíamos
   (quedaban "cargando" debajo de las apps). Por eso se usa **whitelist**.
4. **No matar procesos de más.** Muchos `kill -9` seguidos sobre el Home dejaron la
   TV sin compositor (pantalla negra). Se recuperó con un reboot.
5. Validar antes de subir: `ShelfList.js` con `node --check` (sacando las líneas
   `.import`); el QML revisando balance de llaves/paréntesis y el diff.

## Persistencia

El script de arranque (`/var/lib/webosbrew/init.d/50-cytv-debloat`, copia en
`init.d-50-cytv-debloat.sh`) en cada boot: monta los dos archivos, borra el
checkpoint del Home y lo relanza sin snapshot. Ver [PERSISTENCIA.md](PERSISTENCIA.md).

## Revertir

```bash
# Desactivar en el próximo arranque (kill switch)
./tvroot.sh 'touch /var/lib/webosbrew/home-mod/DISABLED'
# Revertir ya, sin reiniciar
./tvroot.sh 'H=/usr/palm/applications/com.webos.app.fullhome/qml; umount $H/Model/ShelfList.js; umount $H/UserInterfaceLayer/Containers/Main/TopShelf.qml; rm -rf /tmp/checkpoint/com.webos.app.fullhome /mnt/lg/cmn_data/checkpoint/com.webos.app.fullhome; pkill -9 -f com.webos.app.fullhome'
# y apretar HOME en el control
```

Si la pantalla queda negra y no hay SSH: reiniciar la TV; sin los mounts vuelve el Home original
(salvo que el init.d los reaplique — en ese caso crear el `DISABLED` apenas haya acceso).

## Fase 2 — Home propio dentro del Home de LG (QML)

Diseño de referencia: `design/launcher.html` (artifact "Home Limpio LG").

Se descartó el launcher como app web (Chromium 53 en WebAppMgr): costaba ~87 MB extra además
del Home de LG (65 MB) y HOME seguía abriendo el de LG. Se desinstaló (`com.fjanu.home`).
Ahora todo vive **dentro del Home nativo**: un solo proceso, HOME nativo, íconos y apps del sistema.

### Componentes propios (`cleanhome/` → `/var/lib/webosbrew/cleanhome/`)
Se cargan con `Loader` desde archivos de LG modificados: si un componente falla, el Home sigue andando.

| Archivo | Qué hace | Lo carga |
|---|---|---|
| `CleanTop.qml` | Reloj, fecha, clima de Córdoba (open-meteo), dólar blue con variación vs ayer y vs mismo día del mes pasado (dolarapi + argentinadatos), tabla Oficial/MEP/Cripto, BTC 30 días (CoinGecko). Letra widgets ×1.35, secundarios ×1.5 extra. | `TopShelf.qml` |
| `CleanRecents.qml` | Primera fila: últimas 5 apps usadas (`systemProperties.recentAppsData`, que el Home ya recibe de `com.webos.service.recent`), completa con las primeras del launcher. | `MainView.qml` (appListArea) |
| `CleanDrawer.qml` | Cajón a pantalla completa con todas las apps en filas de 5 (`interfaces.launchPoints.launchPointsModel`). ▼ desde la fila lo abre; ▲ en la 1ª fila o ATRÁS (`WebOS.Key_webOS_Back`) lo cierra; OK abre con `interfaces.launchPoints.doLaunch(entry)`. | `MainView.qml` (raíz, z 1000) |
| `CleanGlow.qml` | Fondo que se tiñe con el color de la app enfocada: muestrea el ícono en un Canvas (píxel más saturado), si no usa `iconColor`/`bgColor`. | `MainView.qml` (dentro de `shelfListContainer`, antes de `topArea`) |
| `Panel.qml` | Pieza de los widgets (fondo y borde de cada panel). | `CleanTop.qml` |
| `fonts/`, `img/` | Bricolage Grotesque + Instrument Sans (TTF), íconos del clima, flechita ▼. | — |

### Archivos de LG modificados (`home-mod/`, bind-mount)
| Archivo | Cambio |
|---|---|
| `Model/ShelfList.js` | Whitelist: solo `HOME_SH_TOP` y `HOME_SH_APPS`. |
| `Containers/Main/TopShelf.qml` | Oculta carrusel; altura = `styleSheet.topShelf.height`; `Loader` de CleanTop. |
| `UserInterfaceLayer/GlobalStyle.qml` | `topShelf.height` 492 → **750** (si no, las apps pisan los widgets). |
| `Containers/MainView.qml` | ▼ desde la fila: abre el cajón (antes mandaba el foco a una lista vacía y se perdía); flechita animada; fila de recientes en lugar de la nativa (alto 126 → 170); Loaders de CleanGlow y CleanDrawer. |

### Gotchas de esta fase
- La posición de las apps sale de `styleSheet.topShelf.height` (GlobalStyle), **no** de la altura real del TopShelf.
- El Home tiene rectángulos negros opacos dentro de `shelfListContainer`: el fondo propio tiene que ir **después** de ellos.
- Los `console.log` de QML no quedan en el log; los **errores** sí: `/var/log/fullhome`.
- QML 5.6: nada de `component X:` inline; los tipos propios van en archivos sueltos de la misma carpeta.

### Herramientas
- `tools/deploy-home.sh [captura.png]` — sube `cleanhome/`, `home-mod/` y el script de arranque, monta, borra el snapshot CRIU, relanza el Home y saca captura.
- `tools/tvshot.sh [salida.png]` — captura real de la pantalla (`com.webos.surfacemanager/captureCompositorOutput`).

### Pendiente
- Panel de **Entradas** (HDMI con nombre del equipo, antena, AV) — datos de `com.webos.service.eim/getAllInputStatus`.
- Verificar todo tras un reboot real (persistencia del init.d con los 4 mounts).

## Calendario familiar + clima por horas + mercados (2026-10-23)
Captura: `capturas/inicio-calendario-2026-10-23.png`.
- **Dos columnas** debajo del reloj. Izquierda: clima y mercados. Derecha: `CleanCalendar.qml`.
- **Clima** (`CleanTop.qml`): temperatura actual grande con ícono y condición, y abajo una tira con las próximas horas cada 2 h (open-meteo `hourly`). De noche usa `img/moon.png` y `img/moon-partly.png` (hechos con rsvg-convert en el estilo de los otros íconos).
- **Mercados**: lista de 3 renglones (dólar blue, Bitcoin, dólar cripto), con gráfico de 30 días con línea punteada de referencia, píldora sólida con la variación del día y, abajo, la variación contra el mes pasado (o 30 días para BTC). Historial del cripto: `api.argentinadatos.com/v1/cotizaciones/dolares/cripto`.
- **Calendario**: iCal público de Google, `cleanhome/cal/config.json`. Lo procesa `cleanhome/cal/sync.js` (Node 0.12, root) al prender y cada 10 min (pid en `/tmp/cleanhome-cal.pid`, registro en `/tmp/cleanhome-cal.log`) y deja `cal/events.json`. Expande recurrencias (RRULE diaria/semanal/mensual/anual, BYDAY "2MO"/"-1FR", COUNT/UNTIL), EXDATE, excepciones RECURRENCE-ID y cancelados. El panel lo relee cada minuto.
- **Banner Hero**: `home-mod/.../Main/Hero.qml` no crea componentes (ni imagen ni video de anuncios). Sin la caché de admanager entraba en un loop de reintentos que llenaba `/var/log/fullhome`.
- **Gotchas**:
  - `property var data` rompe todo el objeto: `data` es la propiedad de Item donde van los hijos. Ahora lo detecta `qml-check.py`.
  - El Loader de CleanTop es asíncrono: la captura de `deploy-home.sh` (8 s) puede salir sin el bloque de arriba aunque esté bien. Mirá `CleanYourTV: CleanTop.qml cargado` en el log.
  - `console.log` no llega al log, usar `console.warn`.
- **v2 (2026-10-23 19:26)**: letra +11 % (`fs` 1.5), paneles hasta y 790 (clima 292, mercados 302, calendario 614) y el calendario desde AYER (ayer, hoy y los 5 días siguientes), con píldoras de hasta 3 líneas. Captura: `capturas/inicio-2026-10-23-v2.png`.
- **Bug "siempre abre Disney / abre YouTube además"**: CleanRecents y CleanDrawer abrían la app al APRETAR OK. El Home empezaba a cerrarse, el foco pasaba a la fila nativa oculta (`Selectable.qml` abre en `Keys.onReleased`) y al SOLTAR abría SU app. Ahora abren al soltar y aceptan las dos mitades del evento (`okDown`). Regla: en el Home de LG todo lo que reacciona a OK/ATRÁS lo hace al soltar.
- **v3 (2026-10-23 19:42)**: reloj 35 % más chico (r(55)) con la fecha a la derecha; los paneles arrancan en y 96 (clima 330, mercados 344, calendario 694) y la letra sube a `fs` 1.65. Calendario estilo "Weekly Calendar" del ejemplo del usuario: tabla de 7 días desde ayer con títulos (4/2/1 renglones según cuántos eventos haya), barrita de avance de la semana, y abajo "HOY" (solo lo que no terminó) | "MAÑANA" (o "PRÓXIMOS" si mañana no hay nada). Captura: `capturas/inicio-2026-10-23-v3.png`.
- **Puntero del control (Magic Remote)**: CleanRecents, CleanDrawer y CleanInputs no tenían MouseArea, así que el puntero no hacía nada. Ahora pasar por encima selecciona y el click abre/elige. Los fondos del cajón y del panel de entradas tienen un MouseArea que tapa el puntero para que no seleccione la fila de abajo.
- **v4 (2026-10-23 20:38)**: paneles SELECCIONABLES (CleanTop es un FocusScope: `sel` 0 clima / 1 mercados / 2 calendario, con el día elegido en `calendar.selDay`; borde blanco como las apps; puntero: pasar por encima selecciona, click abre). OK al soltar o click abre `CleanDetail.qml` (MainView, z 1002, `mainView.cleanDetail`): "day" (eventos del día completos), "wx" (24 horas: hora, ícono, temperatura, lluvia, viento), "fx" (blue, oficial, MEP, cripto con compra/venta + Bitcoin y Ethereum, variación del día y 30 días, gráfico de 30 días). Navegación: los íconos de arriba y ▼ van a los paneles; ▲ desde arriba vuelve a los íconos; ▼ desde abajo baja a las apps (señales `exitUp`/`exitDown` atendidas en TopShelf.qml). Clima: la semana (7 días). Mercados: blue, cripto, Bitcoin. Calendario: sin título ni "act.", hora de inicio arriba de cada evento. Captura: `capturas/inicio-2026-10-23-v4.png`.
- **Ruedita del control (2026-10-23)**: `MainView.wheelScroll()` pasaba al estado "list" (secciones de LG, vacías) y mostraba una pantalla en blanco. Ahora, con la fila de recientes activa: abajo abre el cajón de apps y arriba sube a los paneles. Dentro del cajón, un MouseArea con `acceptedButtons: Qt.NoButton` (no roba clicks ni el pasar por encima) mueve una fila por "clic" de la rueda y cierra desde la primera fila.

## Pantallas de edición y ajustes (2026-10-23 noche)
- **Ajustes**: `cleanhome/settings.json` (lo escribe la propia pantalla de inicio con XHR `PUT` a `file://`, porque corre como root). Valores por defecto y lectura/escritura en `cleanhome/settings.js`. Secciones:
  - `wx`: encendido, `refresh` (s, mín. 300), ciudad (`name`/`lat`/`lon`/`tz`, se busca con geocoding de open-meteo) y `unit` (celsius/fahrenheit).
  - `fx`: encendido, `refresh` (mín. 60) y `widget`: hasta 3 de blue, oficial, bolsa (MEP), cripto, contadoconliqui (CCL), tarjeta, mayorista, btc y eth.
  - `cal`: encendido, `refresh` (también en `cal/refresh`) y `source` (enlace o ID; también en `cal/config.json`).
  - `saver`: encendido, `interval` (segundos por foto, mín. 5) y `source` (álbum; también en `saver/config.json`).
- **Botón "✎ Editar"** (y OK) en cada ventana de detalle → `CleanEdit.qml`: interruptor, segundos y el formulario propio de cada panel. Piezas: `CButton`, `CSwitch` y `CField` (TextInput que abre el teclado de la TV con `Qt.inputMethod.show()`). ATRÁS vuelve sin guardar. Al guardar, la ventana se cierra y el inicio toma los cambios en ≤20 s.
- **Panel apagado**: tarjeta "X apagado / OK para editar", que sigue seleccionable.
- **Botón Protector** en la barra de arriba (orden de izquierda a derecha: Entradas · Protector · Buscar · Ajustes; la barra se arma de derecha a izquierda). Abre `CleanDetail` "saver" con el estado, el álbum, "Ver ahora" (vista previa con `CleanSaver.qml`) y "Editar".
- **Tareas de fondo**: `cleanhome/bucles.sh` (lo arranca init.d con nohup) sincroniza el álbum cada 6 h y el calendario cada `cal/refresh`, y enseguida si existe `saver/pedido` o `cal/pedido`. Revisa cada 30 s.
- **Los instaladores no pisan** `settings.json`, `cal/config.json` ni `saver/config.json` si ya existen en la TV.
- **Grabaciones apagadas (2026-10-23)**: el botón "Grabaciones" de la barra de LG en las entradas (`DvrMainView.qml`, `id: recording`) quedó oculto (`inputcommon-mod/TvComponent/DvrProgressBar/View/DvrMainView.qml`, original en `inputcommon-backup/`). Los servicios `rec-listmgr` (`com.webos.service.reclistmgr`) y `rec-info-adapter` (`com.webos.service.recinfoadp`) se paran al arrancar, en el bloque 2b de init.d. Solo los usaba la Guía (livemenu). El menú de entradas no los espera: su `isInitDone` solo pide eim, asm, foreground, iepg, utp y system. init.d y deploy-saver ahora montan todo `inputcommon-mod/`.

## Configuración propia y Wi-Fi que recuerda redes (2026-10-24)
El engranaje de la barra de arriba abre `cleanhome/CleanSettings.qml` (Loader `cleanSettings` en `MainView.qml`, z 1003; `TopGlobalAction.qml` → `case "settings"`). Mismo estilo que el panel de Entradas (`Card.qml`, `RoundIcon.qml`).
- **Menú:** tarjetas "Wi-Fi" (red actual) y "Ajustes de LG" (abre `goToSettingsMain()`, la configuración original).
- **Wi-Fi:** lista de redes ordenada (conectada, guardadas, señal). Busca sola cada 5 s sin animación; al entrar y con el botón ⟳ la búsqueda es "a la vista": el botón se pone azul y la flecha gira hasta que llegan las redes (`scan` → 2,5 s → `findnetworks`).
  - Servicio `com.webos.service.wifi` desde QML con `import WebOSServices 1.0` y `appId: "com.webos.app.fullhome"`: `scan`, `findnetworks`, `connect {ssid, security:{securityType, simpleSecurity:{passKey}}}`, `getstatus` (`networkInfo.connectState === "ipConfigured"`).
  - Red guardada → conecta sin pedir contraseña. Si la guardada falla, se olvida y se pide de nuevo.
- **Contraseñas:** `/var/lib/webosbrew/privado/wifi.json` (carpeta 700, solo root; **nunca va al repo**, está en `.gitignore`). Formato `{ "<ssid>": { security, pass, last } }`; `last` = última conexión (ms).
- **Reconexión automática:** `cleanhome/wifi/reconecta.js` (Node, palmbus). `bucles.sh` lo llama cada 30 s si `wlan0` no tiene IP y no hay cable. Prueba las guardadas que están al alcance, de la más reciente a la más vieja, 30 s cada una. No se mete si el panel de wifi está en uso (`/tmp/cytv-wifi-ocupado`, renovado por el panel en cada búsqueda). Log: `/tmp/cytv-wifi.log` (sin contraseñas).
- **Opcional:** con la marca `/var/lib/webosbrew/no-guardar-wifi` (contenido `1`; la pone `reinstalar-todo.sh` con `NO_GUARDAR_WIFI=s`) el panel no guarda claves, no hay reconexión automática y el deploy borra `wifi.json`. Para volver a activarlo: `rm /var/lib/webosbrew/no-guardar-wifi`.

## Opciones de una app y protector desde la barra (2026-10-24)
- **Mantener apretada una app** (OK sostenido 0,7 s o click largo con el puntero), en la fila de recientes (`CleanRecents.qml`) o en la lista completa (`CleanDrawer.qml`) → `cleanhome/CleanAppMenu.qml` (Loader `cleanAppMenu` en `MainView.qml`, z 1004): Abrir · Quitar de recientes (`interfaces.launchPoints.removeRecent`) · Eliminar de la tele, con confirmación (`uiController.removeLaunchPoint({launchPointId})`, lo mismo que el modo de edición de LG; solo si `entry.removable`).
- **Fila de recientes:** si al rearmarla queda igual, no se reemplaza la lista (antes se recreaban los 5 íconos cada vez que se abría el inicio y la fila "saltaba").
- **Botón del protector** (barra de arriba): abre el protector directamente (`CleanDetail` modo "saver") con "Editar" y ✕ arriba al centro (se esconden a los 5 s). OK edita, ATRÁS sale; al guardar vuelve al protector con los cambios.
- Marca en el registro: `[cytv] inicio visible=true/false` cada vez que se abre o cierra el inicio (sirve para medir con capturas).

## Widgets en cuadrícula y tema (2026-10-24)
- **Cuadrícula de 4×4** sobre la zona de widgets (x 64…1856, y 96…790 en base 1920; casilla 433 × 158,5, separación 20). `settings.json → home.grid = [{ w, c, r, cw, rh }]`. Por defecto: clima 2×2 arriba a la izquierda, mercados 2×2 abajo a la izquierda, calendario 2×4 a la derecha (igual que antes).
- **Widgets disponibles y tamaños** en `settings.js → HOME_WIDGETS` (clima 1×1, 2×1, 2×2, 4×2 · mercados 1×1, 1×2, 2×1, 2×2 · calendario 2×2 a 4×4). Para sumar uno nuevo: agregarlo ahí y dibujarlo en `CleanTop.qml` con `rectOf(id)`. Cada panel se acomoda: clima angosto = solo temperatura y ciudad; clima bajo = sin la semana; mercados = tantas filas como entren (sin gráfico si es angosto); calendario bajo = solo la tabla (sin Hoy/Mañana).
- Navegación entre widgets: al más cercano en la dirección de la flecha (`CleanTop.go()`); en el calendario ◀ ▶ recorren los días primero.
- **Configuración → Widgets** (`WidgetsEditor.qml`): casillas con flechas o puntero; OK en un widget → tamaños, Mover (flechas + OK; ATRÁS cancela), Quitar; OK en una vacía o el botón fijo "Agregar widget" → los que faltan. Al mover, agrandar o agregar, los demás se acomodan solos con `Settings.gridRelayout()`: al lugar libre más cercano y, si no entran, a un tamaño menor (prueba combinaciones con un límite de 3000 intentos); si no entran de ninguna forma quedan afuera y se avisa. La fila de apps recientes y la flechita aparecen recién cuando la parte de arriba tiene su alto (sin saltos al arrancar) y `CleanTop` se carga sincrónico. Guarda en cada cambio y avisa con `mainView.cleanRev` (propiedad nueva en `MainView.qml`), que hace releer los ajustes a CleanTop, CleanGlow, CleanRecents y CleanDrawer.
- **Configuración → Tema** (`ThemeEditor.qml`, `Swatch.qml`): `settings.json → theme = { bg: dynamic|color|photo, bgColor, photo, photoDim, panel: dark|gray|clear, accent, font: s|m|l }`. El fondo lo dibuja `CleanGlow.qml`; los paneles toman `Settings.panelColor()`; el borde de lo elegido (widgets, días del calendario, apps) usa `accent`; la letra de los widgets se multiplica por `Settings.fontFactor()`.
- **Fotos de fondo**: carpeta `/var/lib/webosbrew/fondos/` (la crea `deploy-home.sh`). Se suben con `tools/subir-fondo.sh foto.jpg` (achica a 1920 y simplifica el nombre) o dejándolas en `fondos/` del repo (no se publica) antes de `reinstalar-todo.sh`. `bucles.sh` arma `fondos/index.json` cada 30 s.

## Control remoto y "Asignar a un botón" (2026-10-24/25)
- **Configuración → Control remoto** (`RemoteEditor.qml`, `RemoteDrawing.qml`, `botones.js`): el dibujo del Magic
  Remote MR20 (`img/control-mr20.png`, sacado de la vista previa) con los 9 botones que se pueden cambiar; la lista a la
  derecha y, con OK, la ventanita de opciones. Lo elegido va a `cleanhome/botones.json`, que lee `botones/botones.py`.
- **Listado de apps → mantener OK → Asignar a un botón** (`CleanAppMenu.qml`): abre el mismo editor en "modo elegir"
  (`/tmp/cytv-botones-captura`); el próximo botón que se toca no hace nada y queda asignado a esa app.
- "Abrir una app" usa el mismo listado de apps en modo "elegir" (`CleanDrawer.openPick()`); "Abrir un panel" deja una
  nota (`/tmp/cytv-abrir-panel`) que cada panel lee al aparecer el inicio.
- Detalle del programa, cómo se mide un botón nuevo y cómo apagarlo: [BOTONES.md](BOTONES.md).
- El inicio también anota si está a la vista (`/tmp/cytv-inicio-visible`, desde `CleanRecents.qml`) para el vigilante.
