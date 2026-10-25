# 🤝 Cómo colaborar

¡Buenísimo que quieras sumarte! Hay varias formas, de la más fácil a la más técnica.

## 📺 1 · Sumá tu tele a la tabla de compatibles

Es lo que más ayuda. Si probaste la guía en tu tele, contalo, **haya salido bien o mal**: que algo no ande también sirve, así el siguiente no pierde el tiempo.

### Qué datos necesito

| Dato | Dónde lo ves |
|---|---|
| Modelo | Etiqueta de atrás de la tele, o Configuración → Soporte → Información de la TV |
| Año | El del modelo (si no lo sabés, dejalo vacío) |
| Versión de webOS | Configuración → Soporte → Información de la TV, o en Homebrew Channel |
| Firmware | Configuración → Soporte → Información de la TV ("versión de software") |
| Qué anduvo | Root, pantalla de inicio, protector, optimización: ✅ anda · ⚠️ anda con cambios · ❌ no anda · ➖ no probado |

### Cómo mandarlo

- **Sin saber git:** abrí un [issue](../../issues/new) con el título `Tele: LG XXXXX` y pegá los datos. Yo la sumo a la tabla.
- **Con git:** hacé un fork, agregá una fila a la tabla de "Teles compatibles" del [README](README.md) y mandá un pull request. Si algo necesitó cambios, contalo en el PR.

> 🔒 **No pegues datos tuyos:** ni IP, ni número de serie de la tele o del celular, ni enlaces de tu álbum o tu calendario. El modelo y la versión alcanzan.

## 🐛 2 · Reportá un problema

Abrí un [issue](../../issues/new) contando:

- tu tele (modelo y versión de webOS);
- en qué paso de la guía estabas;
- qué esperabas que pase y qué pasó;
- si podés, la salida del comando o el error (sin datos personales).

## 🛠️ 3 · Mejorá el código o la guía

1. Hacé un fork y una rama: `git checkout -b mi-mejora`.
2. Hacé el cambio. Algunas reglas de la casa:
   - **Nada destructivo y todo reversible.** Si apagás algo, que se pueda volver a prender, y documentá cómo.
   - **Antes de apagar un servicio, fijate si alguna pantalla del sistema lo espera.** Nos pasó con `iepg`: el menú de entradas no se dibujaba (está en [CLAUDE.md](CLAUDE.md), en "Lecciones").
   - **El QML es Qt 5.6:** nada de `component X:` en línea, y nunca una propiedad repetida en el mismo objeto. Antes de subir: `python3 tools/qml-check.py`.
   - **No subas código de LG.** Los cambios a archivos de LG van como parches en `patches/`: editá el archivo armado y corré `tools/guardar-parches.sh`.
   - **No subas datos personales.** Las configuraciones reales (`config.local.sh`, `cleanhome/*/config.json`) están en `.gitignore`. Si agregás una nueva, sumala ahí y dejá un `.example`.
   - Documentos y mensajes, en español.
3. Probalo en tu tele y contá en el PR en cuál.
4. Mandá el pull request.

## 💬 ¿Dudas?

Abrí un issue y lo vemos.
