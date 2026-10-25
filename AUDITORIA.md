# Auditoría de recursos — 2026-10-23 18:55

> Los datos crudos (`audit/audit-*.txt`) no se publican: tienen identificadores de la TV. Se generan en tu TV con `tools/audit-run.sh`.


Datos crudos: `audit/audit-20261023-1855.txt` (script de solo lectura `tools/audit.sh`, se corre con `tools/audit-run.sh`).
Momento de la medición: tele en HDMI 1 **sin señal**, con nuestro protector de fotos andando; 2 h 43 min encendida.

Uso real de la tele: **Xbox por HDMI + apps de películas** (Netflix, YouTube, Amazon…). Nada de antena/cable.

## 1. Memoria (lo más justo)
| | MB |
|---|---|
| RAM total | 964 |
| Reservada para video (CMA, no se toca) | 168 |
| Libre de verdad (MemAvailable) | **~138** |
| Swap usada (comprimida en zram, ocupa ~110 MB de RAM) | **353** de 700 |
| `swappiness` | 100 (manda a swap muy agresivamente) |

`kswapd0` (el hilo del kernel que mueve memoria a swap) gastó **26 % de un núcleo** en 10 s: la tele está corta de RAM y pierde tiempo comprimiendo/descomprimiendo.

### Quién ocupa memoria (RAM + swap, MB)
| Proceso | RAM | Swap | Total | ¿Hace falta? |
|---|---|---|---|---|
| YouTube (`cobalt`) | 75 | 44 | **119** | precargado, no se estaba usando |
| Home de LG (`fullhome`) | 81 | 26 | 107 | sí (incluye nuestro Home) |
| Entradas (`inputcommon`, HDMI) | 76 | 28 | 104 | sí (incluye el protector) |
| Netflix (`netflix.bin`) | 62 | 30 | **92** | precargado, no se estaba usando |
| Compositor (`surface-manager`) | 49 | 18 | 67 | sí, dibuja todo |
| Reproductor de video (`starfish-media-pipeline`) | 46 | 3 | **49** | **publicidad del Home** (ver 3) |
| Motor de apps web (`WebAppMgr` + renderer) | 35 | 28 | 63 | sí para apps web (Prime, etc.) |
| Teclado en pantalla (`MaliitServer`) | 13 | 19 | 32 | sí para escribir en búsquedas |
| Servicio root de Homebrew (`hbchannel.service`) | 19 | 6 | 25 | lo levantan mis comandos; se cierra solo |
| Sintonizador de TV (`RELEASE lg.service.special.broadcast`) | 11 | 12 | 23 | núcleo de la tele, **no tocar** |
| Pantalla compartida con celulares (`ss.gateway`) | 10 | 13 | 23 | vuelve solo aunque el debloat lo pare |
| Guía/Live menu congelado (`cr_zygote livemenu`) | 20 | 0 | 20 | precarga |
| Ayudante modo desarrollador (`node devmode-helper`) | 1 | 17 | 18 | sí (root/SSH) |
| Otros ~240 procesos | — | — | ~150 | |

## 2. Procesador (10 s de medición, en reposo con el protector)
4 núcleos, **69 % ocupado** estando la tele "quieta".
> El "load average 31" que muestra la tele es engañoso: son 30 hilos del driver de video en estado D, no carga real.

| Proceso | % de un núcleo | Qué es |
|---|---|---|
| `surface-manager` | 52 % | dibuja la pantalla (protector con movimiento + Home) |
| `fullhome` | 50 % (35 % en 2ª medición) | **Home oculto reproduciendo publicidad** + animaciones nuestras |
| `RELEASE` (broadcast) | 33 % | servicio de TV/entradas |
| `kswapd0` | 26 % | falta de RAM (swap) |
| `inputcommon` | 20 % | nuestro protector de fotos (solo en reposo) |
| `memchute` | 14 % | vigilante de memoria de LG (trabaja por la falta de RAM) |
| `admanager` | 10 % | **publicidad** |
| `SettingsService` | 10 % | configuración |
| `lginput2` | 8 % | control remoto |
| YouTube en segundo plano | 8 % | precargado |
| `gm`, `sdx`, `ocf-onboarding`, `amazon-alexa-adapter`, `iot-client`, `bluetooth`… | 2–7 % c/u | |

## 3. Hallazgo: el Home reproduce publicidad en video aunque no se vea
`/var/log/fullhome` 18:55:41 → `[Promotion] url: https://cdn-aas-campaigns.alphonso.tv/campaigns/videos/115769/2583590.mp4` → `mediaPlayer … player.play()` → 30 s de reproducción.
El banner grande (`Hero.qml`, "HomeBigCarousel") está oculto por nuestro mod, pero sigue pidiendo anuncios a `admanager` y reproduciéndolos: abre un reproductor (~49 MB), usa CPU y baja video de internet. `alphonso.tv` (empresa de publicidad/ACR) **no** estaba en `hosts.block`.
`admanager` lo lanza el bus del sistema a pedido (padre = `ls-hubd`), por eso "vuelve" aunque el debloat lo mate al arrancar.

## 4. Precarga de apps (`webos-preload-manager`)
Abre apps en segundo plano para que arranquen rápido. Lanzamientos vistos en el registro desde que se prendió:
Google Assistant ×5, YouTube ×3, Netflix ×3, Amazon ×2, HDMI 2 ×2, Tips ×1, Guía (livemenu) ×1, Navegador ×1.
Nuestro debloat mata Netflix/YouTube una vez al prender, pero la precarga los vuelve a abrir.

## 5. Servicios que corren y probablemente no se usan (a confirmar con el usuario)
- **Publicidad / seguimiento**: `admanager`, `sdx` (datos de servidores de LG para el Home), `pbs`, `user-context-manager` (registra qué mirás para recomendaciones), `rdxd` + `crashreportd` (reportes a LG), `aiservice` (ThinQ AI).
- **Voz**: `voiceconductor`, `voiceinput`, `nlpmanager`, `amazon-alexa-adapter`, Google Assistant (precargado), `tts` (lector de pantalla).
- **Casa inteligente**: `iot-client`, `ocf-onboarding`, `homekit`.
- **Compartir pantalla / transmitir desde el celular**: `miracast`, `dmr` + `upnpd` (DLNA), `ssdp-discovery-lgtv`, `ss.gateway`, `avahi` (AirPlay / app LG ThinQ).
- **Bluetooth**: `webos-bluetooth-service`, `btaudiosnk/src`, `asc` → **el control Magic Remote usa Bluetooth: no tocar** (salvo audio BT si no se usa).
- **No tocar**: `surface-manager`, `sam`, `ls-hubd`, `tvservice/RELEASE`, `eim` (entradas), `umediaserver` + `starfish-media-pipeline` (video de apps), `WebAppMgr`, `MaliitServer`, `lginput2`, `SettingsService`, `iepg` (lo espera el menú de entradas).

## 6. Disco y temporales
`/var` (partición de datos): **80 % lleno, 95 MB libres**.
| Carpeta | MB | Qué es |
|---|---|---|
| `/mnt/lg/cmn_data/webbrowser` | 127 | caché del navegador de LG |
| `/var/lib/wam` | 69 | caché de apps web |
| `/mnt/lg/cmn_data/checkpoint` | 77 | apps "congeladas" (Home 20, Home viejo 12, Entradas 26, Guía 19) |
| `/mnt/lg/cmn_data/admanager` | **61** | caché de publicidad |
| `/var/lib/webosbrew` | 23 | Homebrew + nuestros archivos |
| `/mnt/lg/cmn_data/channel_logo` | 8 | logos de canales |

`/tmp` está en **RAM**: 33 MB, de los cuales ~26 MB son **restos míos** de esta sesión (`/tmp/home_qml` 22 MB, `chd`, `sd`, `ss_bk`, `*.tgz`, `cap.png`).
Sin volcados de errores (`/var/log/crashd` vacío). Registros chicos (<1 MB).

## 7. Arranque
- 172 trabajos de upstart definidos; ~80 corriendo.
- Nuestro script: `/var/lib/webosbrew/init.d/50-cytv-debloat` (corrió a los 71 s del arranque).
- `pulseaudio` arranca con `--log-level=debug` (registro detallado innecesario).

## Plan propuesto (todo reversible, se aplica solo con OK)
1. **Cortar la publicidad en video del Home**: agregar `alphonso.tv` y CDNs de anuncios a `hosts.block` + que el Home no cree el reproductor del banner + bloquear `admanager` en el bus. → ~50 MB, CPU y datos.
2. **Apagar la precarga de apps** → ~230 MB (YouTube, Netflix, Amazon, Assistant…). Costo: la primera apertura de cada app tarda unos segundos más.
3. **Bloquear servicios que no se usan** (según lo que confirme el usuario) para que no vuelvan solos.
4. **Limpiar**: restos míos en `/tmp` (26 MB de RAM), caché de publicidad (61 MB de disco), checkpoint del Home viejo (12 MB), caché del navegador si no se usa (127 MB).
5. Revisar que nuestras animaciones del Home se pausen cuando el Home no se ve.

## Resultado aplicado (2026-10-23 ~19:10)
Datos crudos posteriores: `audit/audit-20261023-1906.txt`, más mediciones sueltas.
- RAM disponible: **138 MB → 377 MB**.
- Swap usada: 353 MB → ~270 MB.
- Procesador ocupado en reposo: **69 % → ~26 %** (el Home oculto ya no gasta: 0 %).
- Apps abiertas en segundo plano: Netflix, YouTube, Assistant, Guía, AirPlay → ninguna (las cierra el vigilante).
- Pendiente: el protector de fotos ocupa ~164 MB dentro de `inputcommon` mientras está activo. Ahora pide las fotos al tamaño de la pantalla; falta medir si libera la memoria al salir.
- Pendiente (otra sesión): neutralizar el banner `Hero.qml`, que reintenta sin parar desde que se vació el caché de publicidad.
Detalle de los cambios en [DEBLOAT.md](DEBLOAT.md) → "Fase 2".

## 2026-10-25 — Segunda auditoría: menú, protector, vigilante y velocidad
Memoria = RAM + swap de cada proceso. "Libre" = `MemAvailable`.

| Qué | Medido | Comentario |
|---|---|---|
| Inicio original de LG (`fullhome` sin nuestros cambios) | 102 → 126 MB en 2,5 min | sigue subiendo con la publicidad |
| Nuestro inicio, recién arrancado | 91,5 MB | con Configuración, Wi-Fi, widgets, tema, control remoto… |
| Abrir Configuración, Wi-Fi, Widgets, Tema, Control remoto, apps | +2 a +5 MB en total | las pantallas ya están cargadas |
| Protector de fotos en HDMI (antes) | entradas 83 → 174 MB; quedaban 109 al cerrarlo | `FastBlur` (~60 MB) + fotos a 1920 |
| Protector de fotos en HDMI (ahora) | entradas 83 → 101 MB; vuelve a 83 al cerrarlo | detalle en SCREENSAVER.md |
| Procesador con el protector (antes / ahora) | 30 % → **11 %** de toda la tele | movimiento a 10 cuadros/s en vez de 60 |
| Vigilante de apps (antes / ahora) | 31,6 MB (Node) → **4,4 MB** junto con los botones | `botones/vigilante.py` |
| Vigilante: procesador | 0,3 % de un núcleo | pregunta cada 5 s |
| Netflix abierto atrás al volver al inicio | 60–90 MB que quedaban ocupados | ahora se cierra al minuto |
| ThinQ (`iot-client`) y compartir pantalla (`ss.gateway`) | ~30 MB que reaparecían solos | el vigilante los vuelve a parar (si se eligió apagar la transmisión) |
| Libre recién prendida | **426 MB** (al principio de todo: 138) | |
| Botón HOME → inicio a la vista | 0,5–1 s | |
| Reabrir la entrada HDMI después de cerrarla | ~1 s | LG la restaura de su copia congelada |

Lo que se dejó como está: las copias congeladas de LG en `/tmp/checkpoint` (77 MB: hacen que las apps abran rápido),
el teclado en pantalla (`MaliitServer`, 40 MB) y el motor de apps web (`WebAppMgr`, 50 MB): los usan apps que se usan.

