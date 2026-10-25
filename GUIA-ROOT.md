# Guía paso a paso: rootear la tele LG y dejarla como la mía

**Es para cualquiera, no hace falta saber de programación.** Si sabés instalar una app y seguir instrucciones, alcanza. Lo técnico lo hace Claude: vos vas haciendo lo que pasa en la tele y en la compu, y cuando algo no queda claro, se lo preguntás a Claude como le preguntarías a un amigo.

Probado en una **LG 50UM7360** (webOS 4.10, año 2019). En otras LG con webOS 4 a 6 debería andar parecido, pero no está probado. Fijate la tabla de teles compatibles del [README](README.md).

> ⚠️ Rootear una tele es bajo tu responsabilidad: puede afectar la garantía. Todo lo que instalamos se puede deshacer (ver "Deshacer" al final).

**Cuánto tarda:** una hora más o menos, la primera vez.
**Qué necesitás:** la tele, una computadora (Mac, Windows o Linux) en la misma casa y una cuenta de Claude.

---

## Paso 0 — Preparar la computadora

### 0.1 · Instalá Claude

Claude es el que te va a guiar y el que hace la parte técnica. Necesitás una cuenta de Claude con un plan que incluya **Claude Code** (por ejemplo Pro).

- **La forma más fácil:** bajá la app de escritorio de Claude desde **claude.ai/download**, instalala, iniciá sesión y abrí la pestaña **Code**.
- **Si ya usás la terminal:** instalá Claude Code siguiendo **docs.claude.com/claude-code** y corré `claude`.

### 0.2 · Bajá este repositorio

El "repositorio" es esta carpeta con todos los archivos. Tenés tres formas de bajarla, elegí una:

- **Pedíselo a Claude (recomendado):** en Claude Code, elegí una carpeta tuya (por ejemplo "Documentos") y escribile:
  > *Bajá el repositorio https://github.com/fjanuszewski/webos-root y abrilo.*

  Claude lo baja y se pone a trabajar ahí.
- **Desde la web, sin instalar nada:** entrá a **github.com/fjanuszewski/webos-root**, tocá el botón verde **Code → Download ZIP**, descomprimí el archivo y abrí esa carpeta en Claude Code.
- **Con git** (si ya lo usás): `git clone https://github.com/fjanuszewski/webos-root.git`

### 0.3 · Arrancá

Con Claude Code abierto en la carpeta `webos-root`, escribí:

> **/rootear**

Eso arranca el modo guía: Claude lee las instrucciones del repositorio y te lleva paso a paso por todo lo que sigue. Podés ir leyendo esta guía al mismo tiempo para saber qué viene.

**Otros comandos que podés usar en cualquier momento:**

| Escribís | Qué hace |
|---|---|
| `/rootear` | Te guía por todo, desde cero |
| `/conectar` | Revisa y arregla la conexión entre la compu y la tele |
| `/instalar` | Instala (o reinstala) todo lo nuestro en la tele |
| `/estado` | Revisa cómo está la tele: memoria, qué está corriendo, si todo arrancó bien |
| `/deshacer` | Vuelve atrás lo que elijas |
| `/sumar-mi-tele` | Arma tu fila para la tabla de teles compatibles |

Y si no sabés qué comando usar, escribile lo que querés con tus palabras: *"no me conecta la tele"*, *"quiero cambiar el álbum de fotos"*, *"¿por qué está lenta?"*.

---

## Paso 1 — Cuenta de LG y de desarrollador (es la misma)

1. Creá una **cuenta de LG** si no tenés (desde la tele o desde la web de LG).
2. Entrá a la web de desarrolladores de LG, **webostv.developer.lge.com**, con **el mismo usuario y la misma contraseña**. No hay que crear otra cuenta.
3. Te va a pedir que **aceptes los términos y condiciones** de desarrollador. Aceptalos: sin eso, la app del paso 2 no te deja iniciar sesión.

## Paso 2 — App "Developer Mode" en la tele

1. En la tele abrí la tienda de apps de LG (**LG Content Store**) y buscá **Developer Mode**. Instalala.
2. Abrila e iniciá sesión con tu cuenta.
3. Prendé **"Dev Mode Status"**. La tele se reinicia.
4. Volvé a abrir la app y prendé **"Key Server"**.
5. La app muestra la **dirección IP** de la tele y una **frase de acceso** (passphrase, 6 letras/números). Pasáselas a Claude.

## Paso 3 — Dev Manager en la computadora

1. Instalá **webOS Dev Manager** en tu PC o Mac (es gratis): github.com/webosbrew/dev-manager-desktop → Releases.
2. Agregá la tele como dispositivo. **Claude te dice exactamente qué poner** en cada casillero (nombre, dirección, puerto, usuario y frase de acceso).
3. Conectate.

> **¿No conecta?** Si tu router no deja que la computadora y la tele se vean entre sí (pasa con muchos routers que "aíslan" los aparatos), usá un **celular Android como puente**, con su modo desarrollador activado. Está explicado paso a paso en ["Conexión"](#conexión-si-el-router-no-deja-conectarte-usá-tu-celular-de-puente), más abajo.

## Paso 4 — Rootear

En Dev Manager, abrí la **terminal** conectada a la tele y pegá este comando:

```sh
curl -L -o /tmp/autoroot.sh -- 'https://raw.githubusercontent.com/throwaway96/faultmanager-autoroot/refs/heads/main/autoroot.sh' &&
sh /tmp/autoroot.sh
```

Esto rootea la tele (usa el método *faultmanager-autoroot* de throwaway96) e instala **Homebrew Channel**, la "tienda" de apps caseras. Al terminar vas a ver Homebrew Channel entre tus apps. Abrilo → Configuración: tiene que decir que el root está activo.

## Paso 5 — La "puerta trasera" (que nada se pierda)

Sin esto, el root depende del modo desarrollador: si su sesión vence o se corta la luz, la tele puede volver a como estaba. Claude lo hace con vos:

1. En la tele: **Homebrew Channel → Configuración → prender "SSH Server"**.
2. Claude instala **tu llave** para entrar como administrador (solo con esa llave, sin contraseña) y apaga el acceso sin contraseña que Homebrew trae prendido de fábrica.
3. Claude **desinstala la app Developer Mode** (a propósito: si su sesión vence, al prender la tele borraría Homebrew Channel; sin la app, eso no pasa) y registra el **arranque automático** de Homebrew.
4. **Prueba de fuego:** desenchufá la tele 10 segundos, volvé a enchufarla y prendela. Al minuto y medio Claude comprueba que todo volvió solo.

## Paso 6 — Instalar todo lo nuestro

Claude corre `tools/reinstalar-todo.sh`, que sube:

- **Bloqueo de publicidad** y de seguimiento de LG.
- **Pantalla de inicio propia**: reloj, clima, panel de dólar y Bitcoin, calendario, últimas apps usadas, lista completa de apps, panel de entradas.
- **Protector de pantalla con tus fotos** de un álbum compartido de Google Photos.
- **Optimización de memoria**: apaga la apertura automática de apps, servicios que no se usan, y un **vigilante** que cierra las apps que quedan abiertas cuando cambiás de app.

Antes te pregunta:

- **¿Querés apagar los servicios de transmisión desde el celular?** (AirPlay, compartir pantalla/Miracast, DLNA y la conexión con la app LG ThinQ). Si no mandás contenido desde el celular a la tele, ahorra unos **100 MB** de memoria.
- El enlace de **tu álbum** de Google Photos y de **tu calendario** (se guardan solo en tu computadora, no se publican). Cómo conseguirlos, abajo.

### El calendario familiar (Google Calendar)

La tele lee el calendario por un enlace, sin iniciar sesión, así que tiene que ser un calendario **compartido públicamente**. Te recomiendo crear uno aparte para la familia y no usar el personal.

1. En la computadora, entrá a **calendar.google.com**.
2. A la izquierda, en **"Otros calendarios"**, tocá **+ → Crear calendario**. Ponele un nombre (por ejemplo "Familia") y **Crear calendario**.
3. Si querés que otros carguen eventos: en la configuración de ese calendario → **"Compartir con personas específicas"** → agregá a tu familia con permiso para hacer cambios.
4. En la misma configuración → **"Permisos de acceso a los eventos"** → marcá **"Hacer que esté disponible para el público"** y elegí **"Ver todos los detalles de los eventos"**.
5. Bajá hasta **"Integrar calendario"** y copiá la **"Dirección pública en formato iCal"**: termina en `basic.ics`. Ese enlace es el que le pasás a Claude.

> ⚠️ Público quiere decir que **cualquiera que tenga el enlace** puede ver los eventos. No está publicado en ningún lado, pero no lo compartas, y no cargues ahí nada que no quieras que se vea (direcciones, datos médicos, etc.).

### El álbum de fotos (Google Photos)

1. En **photos.google.com** (o en la app), creá un **álbum** y agregale las fotos que quieras ver en la tele.
2. Tocá **Compartir → Crear vínculo** (en algunas versiones: "Compartir vínculo" o activar "Compartir vínculo"). Copiá el enlace: empieza con `https://photos.app.goo.gl/`.
3. Ese enlace es el que le pasás a Claude. Cuando agregás o sacás fotos del álbum, la tele se entera sola: actualiza la lista cada 6 horas.

> ⚠️ Igual que el calendario: **cualquiera con el enlace** puede ver el álbum. Los videos del álbum se ignoran; solo se muestran fotos.

---

## Conexión: si el router no deja conectarte, usá tu celular de puente

Muchos routers de casa **no dejan que dos aparatos se hablen entre sí** (lo llaman "aislamiento de clientes"). Se nota porque Dev Manager no conecta aunque los datos estén bien. En ese caso se puede usar un **celular Android como puente**: la tele se conecta a internet por el celular, y la computadora le habla a la tele a través del celular.

**Qué necesitás:** un celular Android, su cable USB y la computadora.

1. **Activá el modo desarrollador del celular** (sin esto no se pueden habilitar los puertos del puente):
   - En el celular: **Ajustes → Acerca del teléfono → tocá 7 veces "Número de compilación"**. Aparece el mensaje "Ahora sos desarrollador". En algunos celulares está en "Información de software".
   - Después: **Ajustes → Sistema → Opciones para desarrolladores → prendé "Depuración por USB"**.
2. **Prendé el hotspot del celular** (Ajustes → Red → Zona Wi-Fi) y **conectá la tele a esa red** (en la tele: Configuración → Red → Wi-Fi).
3. **Conectá el celular a la computadora por USB.** En el celular aparece "¿Permitir depuración por USB?": tocá **Permitir** (y "permitir siempre desde esta computadora").
4. En la computadora hace falta **adb** (las herramientas de Android). Claude te ayuda a instalarlo (en Mac: `brew install android-platform-tools`).
5. Copiá `config.example.sh` como `config.local.sh` y completá:
   - el número de serie del celular (lo muestra `adb devices`);
   - la IP de la tele en el hotspot (la muestra la app Developer Mode, o la tele en Configuración → Red).
6. Claude corre `restore-chain.sh`, que arma el puente: abre en el celular los puertos que reenvían a la tele (el del modo desarrollador para rootear, el de la llave, y el del acceso permanente de después).

Con el puente, **en Dev Manager la dirección de la tele pasa a ser `127.0.0.1`** (la propia computadora), no la IP de la tele. Claude te dice los datos exactos.

> Si el celular se reinicia o se desconecta, el puente se cae: Claude vuelve a correr `restore-chain.sh`. El celular tiene que quedar conectado por USB mientras trabajás con la tele (después, para usarla normalmente, no hace falta).

**Otras opciones sin celular:** apagar el aislamiento de clientes en la configuración del router (a veces está en la "red de invitados"), o conectar la tele al router por **cable de red**.

## Deshacer

- Volver servicios y precarga a como estaban (sin reiniciar): `./restore-services.sh`.
- Apagar la publicidad bloqueada: `./adblock.sh off`.
- Apagar todo lo nuestro al prender: borrar `/var/lib/webosbrew/init.d/50-cytv-debloat` en la tele.
- Cada parte tiene su propia "llave de apagado" (archivos `DISABLED`): ver `DEBLOAT.md`, `HOME-MOD.md` y `SCREENSAVER.md`.

## Más detalle

| Tema | Documento |
|---|---|
| Cómo funciona la persistencia y la puerta trasera | `PERSISTENCIA.md` |
| Qué se apaga y por qué, y cuánto ahorra | `DEBLOAT.md`, `AUDITORIA.md` |
| Pantalla de inicio propia | `HOME-MOD.md` |
| Protector con fotos | `SCREENSAVER.md` |
| Comandos útiles | `COMANDOS.md` |
