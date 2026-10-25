# Instrucciones para Claude — guiar el root y la instalación

Este repo rootea una tele LG webOS (probado: LG 50UM7360, webOS 4.10.2) y le instala lo nuestro. La guía para la persona está en `GUIA-ROOT.md`. Acá está lo que **vos** (Claude) tenés que hacer en cada paso.

**Asumí que la persona no es técnica**, salvo que te demuestre lo contrario. Puede ser que ni siquiera tenga el repo bajado: si te pide "bajá el repo", clonalo (`git clone https://github.com/fjanuszewski/webos-root.git`, o bajá el ZIP si no hay git), entrá a la carpeta y seguí desde ahí.

## Herramientas del repo (`.claude/`)

| Tipo | Nombre | Para qué |
|---|---|---|
| Comando | `/rootear` | Guía completa desde cero (usa la skill `guia-root`) |
| Comando | `/conectar` | Diagnostica y arregla la conexión compu ↔ tele |
| Comando | `/instalar` | `tools/reinstalar-todo.sh` con las preguntas de qué activar (álbum, calendario, transmisión, audio Bluetooth, guardar claves de Wi-Fi) |
| Comando | `/estado` | Revisión sin cambios (usa el agente `auditor-tele`) |
| Comando | `/deshacer` | Volver atrás lo que la persona elija |
| Comando | `/sumar-mi-tele` | Fila para la tabla de teles compatibles + issue o PR |
| Skill | `guia-root` | Cómo guiar el root paso a paso |
| Skill | `diagnostico-tele` | Cómo medir e interpretar el estado de la tele |
| Skill | `modificar-pantalla-inicio` | Cómo cambiar lo visual (QML, parches, deploy, trampas de Qt 5.6) |
| Agente | `auditor-tele` | Revisa la tele **sin cambiar nada** y devuelve un resumen |
| Agente | `revisor-privacidad` | Antes de publicar: busca datos personales o código de LG |

Si la persona escribe con sus palabras ("no me conecta", "está lenta", "quiero cambiar las fotos"), elegí vos la herramienta que corresponde.

## Cómo hablarle a la persona
- **En español simple**, sin jerga en inglés. Decí "pantalla de inicio" (no "Home"), "enlace" (no "link"), "vista previa" (no "mock").
- Explicá qué pasa en la tele y qué tiene que hacer ella. Lo técnico lo hacés vos.
- **Pedí OK antes de cada cambio** en la tele. Todo tiene que poder deshacerse.
- Nunca subas a git sus datos personales: `config.local.sh`, `cleanhome/saver/config.json` y `cleanhome/cal/config.json` están en `.gitignore`, y así tienen que quedar. Antes de cualquier commit, PR o issue, pasá el agente `revisor-privacidad`.
- Para contribuir al repo (tele nueva, arreglos), seguí `CONTRIBUTING.md`.

## Orden de los pasos (importa)

### 1–2. Cuenta y app Developer Mode (lo hace la persona)
La cuenta de LG y la de desarrollador son **la misma**. Tiene que entrar a webostv.developer.lge.com con ese usuario y **aceptar los términos**: si no, la app Developer Mode no le deja iniciar sesión. En la app: prender "Dev Mode Status" (reinicia la tele) y después "Key Server". Pedile la **IP** y la **frase de acceso** (passphrase) que muestra la app.

### 3. Dev Manager (la persona; vos le das los datos)
webOS Dev Manager: github.com/webosbrew/dev-manager-desktop. Al agregar el dispositivo:

| Casillero | Valor |
|---|---|
| Nombre | cualquiera (ej. `tele`) |
| Dirección / Host | la IP que muestra la app Developer Mode — o **`127.0.0.1`** si se usa el celular de puente |
| Puerto | `9922` (con puente: el `adb forward tcp:9922` de `restore-chain.sh`) |
| Usuario | `prisoner` |
| Autenticación | "Dev Mode passphrase" → la frase de 6 caracteres de la app |

Si no conecta: el Key Server tiene que estar prendido, y la compu y la tele tienen que verse en la red (ver "Red").

### 4. Root (la persona, en la terminal de Dev Manager)
```sh
curl -L -o /tmp/autoroot.sh -- 'https://raw.githubusercontent.com/throwaway96/faultmanager-autoroot/refs/heads/main/autoroot.sh' &&
sh /tmp/autoroot.sh
```
Instala Homebrew Channel con root. Para verificarlo: Homebrew Channel → Configuración → root activo.

### 5. Llave en la compu (vos, MIENTRAS el modo desarrollador siga activo)
Todos los scripts usan la llave `~/.ssh/tv_webos_dec`. Se saca del Key Server y se desencripta con la passphrase:
```sh
curl -s "http://IP_TV:9991/webos_rsa" -o ~/.ssh/tv_webos_rsa
openssl rsa -in ~/.ssh/tv_webos_rsa -out ~/.ssh/tv_webos_dec -passin pass:PASSPHRASE
chmod 600 ~/.ssh/tv_webos_*
```
Con esa llave ya anda el camino de respaldo de `tvroot.sh`: SSH `prisoner@:9922` + `luna://org.webosbrew.hbchannel.service/exec`, que corre como root.

### 6. Puerta trasera permanente
1. La persona: Homebrew Channel → Configuración → **SSH Server** encendido.
2. Vos: `tools/reinstalar-todo.sh`. Instala esa misma llave en `/home/root/.ssh/authorized_keys`, deja encendido el SSH de Homebrew (dropbear, puerto 22, solo con llave), apaga el telnet sin contraseña, sube todo y registra el arranque automático de Homebrew.
3. **Verificá** que entrás como root sin el modo desarrollador: `ssh -p 2222 root@127.0.0.1` (o el puerto 22 de la tele, según la red).
4. Solo después de verificarlo, y con OK: **desinstalar la app Developer Mode**. Por qué: si su sesión vence, `/etc/init/devmode.conf` borra `/media/developer`, que es Homebrew Channel. Detalle en `PERSISTENCIA.md`.
   ```sh
   ./tvroot.sh 'luna-send -n 1 luna://com.webos.appInstallService/remove "{\"id\":\"com.palmdts.devmode\"}"'
   ```
5. Prueba de corte de luz: que la persona desenchufe la tele 10 s y la vuelva a prender. A los ~90 s comprobá: `tail -n 1 /var/lib/webosbrew/cytv-debloat.log`, los montajes (`mount | grep -E "fullhome|screensaver|inputcommon|hosts"`) y el vigilante (`/tmp/cytv-appcloser.log`).

### 7. Instalar todo
`tools/reinstalar-todo.sh` pregunta, o se le pasan las respuestas con variables:
- **Transmisión desde el celular** (AirPlay, Miracast, DLNA, ThinQ, HomeKit): `APAGAR_TRANSMISION=s|n`. Ahorra ~100 MB. **Preguntale a la persona** si manda contenido desde el celular.
- **Audio Bluetooth**: `APAGAR_AUDIO_BT=s|n`. Preguntale si usa auriculares o barra por Bluetooth. El control remoto anda igual.
- **Guardar claves de Wi-Fi** (y reconectarse sola a las redes guardadas): `NO_GUARDAR_WIFI=s|n`. **Preguntale** si le parece bien que las contraseñas queden en un archivo de la tele (solo lo lee el administrador; nunca va al repo). Si no → `s`: el panel pide la clave cada vez y no hay reconexión automática. Detalle en `HOME-MOD.md`.
- **Álbum y calendario:** copiá `cleanhome/saver/config.example.json` a `config.json` y `cleanhome/cal/config.example.json` a `config.json`, y completalos con los enlaces que te dé la persona.
- Los archivos modificados de LG **no están en el repo** (licencia de LG). `tools/armar-mods.sh` baja los originales de la propia tele (`/old_root`) y les aplica `patches/`. Lo corren solos los scripts de deploy.

## Red
- Primero probá si la compu ve a la tele directo (`nc -z IP_TV 9922`). Si no, es el router (aislamiento de clientes): **puente por celular Android**. Guiá a la persona con la sección "Conexión" de `GUIA-ROOT.md`: modo desarrollador del celular + "Depuración por USB", tele en el hotspot del celular, `adb` instalado, `config.local.sh` completo.
- `restore-chain.sh` levanta en el celular los relays `nc -L` (2222→TV:22, 9922→TV:9922, 9991→TV:9991) y los `adb forward` en la compu. Los scripts entran por `127.0.0.1:2222`. Con puente, la llave del paso 5 se baja de `http://127.0.0.1:9991/webos_rsa`.
- Si la compu ve a la tele directo: alcanza con que `127.0.0.1:2222` apunte a `IP_TV:22`, por ejemplo con `socat TCP-LISTEN:2222,fork,reuseaddr TCP:IP_TV:22 &`.

## Lecciones (no repetirlas)
- **Antes de apagar un servicio, revisá si alguna pantalla del sistema lo espera.** El menú de entradas (`/usr/lib/qt5/qml/InputPicker`) solo se dibuja cuando responden eim, asm, foreground, iepg, utp y system: con `iepg` apagado, el botón de entradas saltaba directo al HDMI.
- `luna-send` sin terminal sale vacío. Usá `ssh -tt`, o desde Node `require('/usr/lib/nodejs/palmbus')`.
- `pkill -f TEXTO` puede matar tu propia sesión SSH si el texto está en el comando. Usá `kill $(pidof nombre)`.
- Vaciar el caché de publicidad hace que el banner oculto del Home reintente sin parar: el `Hero.qml` de los parches lo neutraliza.
- **No confíes en suscripciones de luna a largo plazo**: después de que la tele "despierta" del quick start pueden quedar muertas sin avisar. Para decisiones que cierran cosas, preguntá en el momento (el vigilante cerraba YouTube creyendo que al frente estaba el HDMI).
- Por SSH (dropbear con `-tt`), lo que se deja corriendo muere al cerrar la sesión: lanzalo con `setsid nohup … &`.
- Algunas apps "tercas" (ej. la web de AirPlay) no se cierran con `closeByAppId`: hay que usar `luna://com.palm.webappmanager/killApp`.
- Qt 5.6: nada de `component X:` en línea, nunca una propiedad repetida en el mismo objeto (rompe el Home). Antes de subir QML: `python3 tools/qml-check.py`.
