---
name: modificar-pantalla-inicio
description: Cambiar la pantalla de inicio, el protector de fotos o la pantalla de entradas de la tele LG (QML de cleanhome/ o parches sobre archivos de LG). Usala cuando pidan agregar o cambiar un panel, colores, textos, el álbum, el calendario, o cualquier cosa visual de la tele.
---

# Modificar lo visual de la tele

## Dónde está cada cosa
- **Nuestro código** (se publica): `cleanhome/*.qml` (paneles, cajón de apps, entradas, protector), `cleanhome/settings.js` (valores por defecto), `cleanhome/saver/`, `cleanhome/cal/`.
- **Archivos de LG modificados** (NO se publican): se arman en `home-mod/`, `saver-mod/`, `inputcommon-mod/` con `tools/armar-mods.sh`, que baja el original de la tele (`/old_root`) y le aplica `patches/`. La lista está en `tools/mods-lista.sh`.
- Vista previa en el navegador: `design/launcher.html`.

## Flujo
1. Si vas a tocar un archivo de LG: `tools/armar-mods.sh`, editá el archivo armado y después `tools/guardar-parches.sh` para actualizar `patches/`.
2. **Validá siempre:** `python3 tools/qml-check.py <archivos>`.
3. Subí:
   - pantalla de inicio: `tools/deploy-home.sh` (reinicia la pantalla de inicio y saca una captura; si un archivo de LG no compila, lo desmonta solo);
   - protector o entradas: `tools/deploy-saver.sh` (reinicia la parte de entradas).
   Avisale a la persona antes, porque la pantalla se reinicia.
4. Si el cambio es visual, actualizá también `design/launcher.html`.

## Trampas de Qt 5.6 (la tele es vieja)
- Nada de `component X:` en línea. Cada componente, en su archivo.
- **Nunca** asignar dos veces la misma propiedad en un objeto: "Property value set multiple times" rompe todo `MainView` y el botón HOME deja de andar.
- `ListView`/`GridView` con `interactive: false` ignora las flechas.
- La pantalla de inicio de LG maneja ATRÁS y OK **al soltar** la tecla (`Keys.onReleased`). Los paneles propios tienen que actuar al soltar y aceptar presionar y soltar. Si no, el evento lo agarra otra fila y abre otra app.
- La pantalla de inicio arranca desde un "congelado" (CRIU): para que tome cambios hay que borrar `/tmp/checkpoint/com.webos.app.fullhome` y `/mnt/lg/cmn_data/checkpoint/com.webos.app.fullhome` y relanzarla con `snapshot:false` (los scripts de deploy ya lo hacen).
- `console.log` no sale en el log: usá `console.warn`. Log: `/var/log/fullhome`.
