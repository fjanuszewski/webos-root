# Botones del control con otra función

En **Configuración → Control remoto** se elige qué hace cada uno de estos botones del Magic Remote
(probado con el MR20, modelo AKB75855501):

NETFLIX · Prime Video · Rojo · Verde · Amarillo · Azul · MOVIES · Reproducir · Pausa

Los demás botones (flechas, OK, ATRÁS, volumen, números, el puntero) siempre funcionan de fábrica.

## Qué se le puede asignar

| Opción | Qué hace |
|---|---|
| De fábrica | Lo normal del botón |
| Abrir una app | Se elige del mismo listado de apps |
| Ir a una entrada | HDMI, AV o TV |
| Abrir una página web | Abre el navegador en esa dirección |
| Activar el protector de pantalla | En una entrada HDMI sin señal aparece el protector de fotos de esa entrada |
| Apagar solo la pantalla | El sonido sigue; cualquier botón la vuelve a prender (ese toque no hace nada más) |
| Temporizador para apagar | Cada toque: 30 → 60 → 90 minutos → apagado, con un aviso en pantalla |
| Abrir un panel | Wi‑Fi, Entradas, calendario de hoy o clima por hora |
| Volumen fijo | Lleva el volumen a un número |
| Cambiar la salida de sonido | Parlantes de la tele ↔ Bluetooth. **Solo aparece si no se apagó el audio Bluetooth** en la instalación (`APAGAR_AUDIO_BT`) |
| No hacer nada | Para que no pase nada si se toca sin querer |

**Otra forma de asignar:** en el listado de apps, mantener apretado OK sobre una app → **Asignar a un botón**.
Aparece el dibujo del control: se toca el botón que se quiere usar (ATRÁS cancela).

**Volver todo atrás:** en la misma pantalla, **Volver todo a fábrica**.

## Cómo funciona

- `botones/botones.py` (Python 2.7, viene en la tele) "agarra" el control y le pasa a la tele todo lo que no
  tenga algo asignado. Si el programa se cierra, el control vuelve a andar de fábrica solo.
- **Si no hay ningún botón asignado, ni toca el control.**
- `botones/run.sh` lo vuelve a prender si se cierra; si falla 5 veces seguidas, deja de insistir.
- Lo arranca el inicio automático (`init.d-50-cytv-debloat.sh`, punto 6). Lo sube `tools/deploy-home.sh`.
- Lo elegido queda en `/var/lib/webosbrew/cleanhome/botones.json` (se relee solo al cambiar).
- Registro: `/tmp/cytv-botones.log`.

## Apagarlo

```sh
./tvroot.sh 'touch /var/lib/webosbrew/botones/DISABLED; kill $(cat /tmp/cytv-botones.pid); pkill -f "botones/[b]otones.py"'
```

(El `[b]` evita que el comando se cierre a sí mismo.) Para volver a prenderlo: borrar ese archivo `DISABLED` y reiniciar la tele (o correr `tools/deploy-home.sh`).

## Otro control u otra tele

Los números de cada botón están en `KEYS` de `botones/botones.py`. Para medir uno que falte (por ejemplo
MOVIES): abrir **Asignar a un botón**, tocar ese botón y mirar el registro:

```sh
./tvroot.sh 'grep "sin nombre" /tmp/cytv-botones.log | tail -3'
```

Ahí aparece `código N`: agregarlo a `KEYS` (o a `MOVIES_CODES`) y subir de nuevo. Si tu control es otro modelo,
el dibujo (`cleanhome/img/control-mr20.png`) y las zonas de cada botón (`cleanhome/botones.js` → `KEYS`)
también hay que adaptarlos; contalo en un issue (ver `CONTRIBUTING.md`).
