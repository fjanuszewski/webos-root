# Persistencia del debloat al arranque — investigación y solución

Resuelto el **2026-10-23**. **SÍ se puede dejar automático al encendido**, pese al
candado de firma de LG. Esta es la evidencia para no volver a investigarlo.

## El problema

El debloat (parar preloads + servicios bloat) baja ~90 MB de swap, pero se pierde en
cada **reinicio real** de la TV. Queríamos que se aplicara solo en cada arranque.

## Camino 1 (BLOQUEADO): start-devmode.sh — candado de firma de LG

La vía clásica de persistencia en TVs rooteadas (RootMyTV) es el script
`start-devmode.sh` que Developer Mode corre al boot. Pero en `/etc/init/devmode.conf`:

```sh
DEVSHFILE=.../com.palmdts.devmode.service/start-devmode.sh
[ "$(openssl dgst -sha512 -verify pub.pem -signature start-devmode.sig $DEVSHFILE)" == "Verified OK" ]
# si no valida -> DESACTIVA developer mode (y borra /media/developer)
```

LG agregó (2021) verificación de **firma digital** con su clave pública `pub.pem`. No
tenemos la clave privada, y meter un script sin firmar **desactiva Dev Mode** (se
pierde el acceso). ❌ Inviable. (Confirmado también por el issue #256 de webosbrew.)

## Camino 2 (FUNCIONA): autostart vía Activity Manager

El Homebrew Channel moderno NO usa start-devmode.sh para persistir. Usa el
**Activity Manager de webOS** con un trigger sobre la señal de boot. Del código
(`services/service.ts` de webos-homebrew-channel):

```js
// Register activity to call /autostart on boot
activity = {
  name: "org.webosbrew.hbchannel.service.autostart",
  type: { foreground:true, persist:true, continuous:true, explicit:true },
  trigger: {
    method: "luna://com.webos.bootManager/getBootStatus",
    params: { subscribe: true },
    where: { prop:["signals","core-boot-done"], op:"=", val:true }
  },
  callback: { method: "luna://org.webosbrew.hbchannel.service/autostart" }
}
luna://com.palm.activitymanager/create { activity, start:true, replace:true }
```

Flujo en cada boot:
`core-boot-done` → Activity Manager dispara la actividad → llama
`luna://org.webosbrew.hbchannel.service/autostart` → (si corre como root) copia y
ejecuta `/var/lib/webosbrew/startup.sh` → corre los scripts de
`/var/lib/webosbrew/init.d/*`. **Sin firmas. Sin tocar start-devmode.sh.**

## Cómo lo activamos

1. Script de debloat en `/var/lib/webosbrew/init.d/50-cytv-debloat` (ejecutable).
2. Llamamos al método del service para registrar la actividad:
   ```sh
   luna-send-pub -n 1 luna://org.webosbrew.hbchannel.service/autostart '{}'
   ```
   (El handler `autostart`, al ser llamado por nosotros y no por el Activity Manager,
   además de correr el startup **registra la actividad** vía `registerActivity`.)
   OJO: el handler sale temprano si existe `/tmp/webosbrew_startup` (lock del boot) —
   hay que borrarlo antes: `rm -f /tmp/webosbrew_startup`.
3. Verificado por efectos secundarios: el lock se recreó y `startup.sh` corrió →
   `autostart` se ejecutó de verdad (las respuestas luna vuelven vacías por el bridge,
   pero **ejecutan igual**).

## Gotchas aprendidos

- Las llamadas `luna-send(-pub)` desde el bridge `exec` **devuelven stdout vacío**
  pero **sí se ejecutan**. Verificar por efectos secundarios, no por la respuesta.
- Métodos del service como `registerActivity`/`getConfiguration` son de **bus privado**
  (solo los llama la app). `exec` y `autostart` sí responden desde el público.
- `autostart` requiere que el service corra **como root** en el boot (lo está, por la
  elevación persistente de hbchannel) — si no, hace `return "Not running as root"`.
- Para que el debloat atrape servicios que arrancan durante el boot, el script espera
  (`sleep 12`) y hace **3 pasadas**.

## Reversión

- Quitar el debloat del boot: `rm /var/lib/webosbrew/init.d/50-cytv-debloat`.
- Desregistrar la actividad: `luna-send-pub -n 1 luna://com.palm.activitymanager/cancel '{"activityName":"org.webosbrew.hbchannel.service.autostart"}'`.
- O directamente un reboot deja de aplicar el debloat si se borró el script.

## Fuentes
- Código: github.com/webosbrew/webos-homebrew-channel → `services/service.ts`, `services/startup.sh`
- Issue firma: github.com/webosbrew/webos-homebrew-channel/issues/256
- RootMyTV: github.com/RootMyTV/RootMyTV.github.io

---

# Actualización 2026-10-23 (noche): acceso propio y nada se pierde con un corte de luz

## Qué pasó
Al desenchufar la TV volvió todo a fábrica. Causa, leída en `/etc/init/devmode.conf`: en cada arranque,
**si no existe `/var/luna/preferences/devmode_enabled`, borra `/media/developer`**, que es donde vive Homebrew
Channel. La sesión del modo desarrollador se había cerrado (o vencido): la app del modo desarrollador borró
`devmode_enabled`, y en el siguiente arranque se fue Homebrew. Sin Homebrew no corre nada al prender.
Nuestros archivos (`/var/lib/webosbrew/*`) NO se borraron: viven en otra partición.

## Cómo quedó (probado con dos cortes de luz reales)
1. **Acceso propio, sin modo desarrollador**: SSH de Homebrew Channel (dropbear) como root en el puerto 22,
   **solo con nuestra llave** (`/home/root/.ssh/authorized_keys`, root no tiene contraseña: `root:*`).
   Se enciende en cada arranque por `/var/luna/preferences/webosbrew_sshd_enabled`.
   Telnet de root sin contraseña **apagado** (`webosbrew_telnet_disabled`).
   Camino: Mac `127.0.0.1:2222` → adb forward → teléfono `nc -L -p 2222` → TV:22. `tvroot.sh` y los
   scripts de `tools/` ya usan este camino (el modo desarrollador quedó solo como respaldo en `tvroot.sh`).
2. **App "Developer Mode" desinstalada** (`com.palmdts.devmode`, vía `com.webos.appInstallService/remove`).
   Sin esa app, `devmode.conf` no encuentra `start-devmode.sh`, no apaga nada, y como `devmode_enabled`
   sigue existiendo (ahora es una CARPETA, la dejó así el rooteo: la app no la puede borrar),
   **nunca borra `/media/developer`**.
3. **Arranque automático re-registrado**: la actividad `org.webosbrew.hbchannel.service.autostart`
   (`persist: true`, dispara en `core-boot-done`) se pierde al reinstalar Homebrew. Se registra llamando a
   `luna://org.webosbrew.hbchannel.service/autostart` (borrando antes `/tmp/webosbrew_startup`).

Pruebas: dos desenchufes reales (con y sin la app del modo desarrollador). En ambos, a los ~76 s del
encendido: SSH propio arriba, `cytv applied ... homemod=6 saver=1 botones=…`, 9 montajes, calendario.

## Si alguna vez hay que volver a rootear
1. Rootear e instalar Homebrew Channel como siempre.
2. En la TV: Homebrew Channel → Configuración → encender **SSH Server**.
3. En la Mac: `tools/reinstalar-todo.sh` (llave + ajustes + sube todo + registra el arranque automático).

## Gotchas
- `luna-send` por SSH **solo muestra la respuesta con terminal real**: `ssh -tt ...`. Sin `-tt` sale vacío
  (por eso antes parecía que "no respondía"), aunque la llamada se ejecuta igual.
- `activitymanager/getDetails` por nombre falla ("name/creator pair not found") si no lo pide el creador;
  usar `activitymanager/list` con `{"details":true,"subscribers":false,"internal":false,"current":false}`.

## Gotchas del SSH directo (dropbear) — aprendidos el 2026-10-23
- **Sin terminal, `luna-send` falla de forma intermitente** (no hace la llamada y no avisa). `tvroot.sh` usa siempre `ssh -tt` y saca los `\r` de la salida.
- **Lo que queda en segundo plano se corta al cerrar la sesión** (SIGHUP): los `luna-send` de los scripts van en primer plano y los loops con `nohup`.
- **`pkill -f TEXTO` se puede matar a sí mismo** si el texto aparece en la línea de comandos de la sesión (el comando viaja en texto plano). `tvroot.sh` manda el comando en base64 y lo corre desde un archivo temporal, igual que hacía el bridge viejo. Para matar apps, mejor `kill $(pidof nombre)`.

# Actualización 2026-10-26: la tele amaneció "de fábrica" (modo a prueba de fallos de Homebrew)

## Qué pasó
Una mañana la tele apareció sin nada de lo nuestro (inicio de LG, con publicidad). **No se perdió nada:** todos
los archivos seguían en `/var/lib/webosbrew/`. Homebrew había entrado en su **modo a prueba de fallos (failsafe)**:
abre un telnet de emergencia en el puerto 23, no levanta dropbear (SSH) ni corre los hooks de `init.d/`, así que
la tele queda como LG de fábrica.

## La causa
Homebrew corre `init.d/*` con `run-parts` y **espera** a que terminen para recién cerrar el failsafe (pone una
marca `/var/luna/preferences/webosbrew_failsafe` al empezar y la borra 10 s después de que `run-parts` vuelve).
Nuestro `50-cytv-debloat` tenía **~40 s de `sleep`** (el debloat, 3 pasadas con esperas) en primer plano, así que
la marca de failsafe quedaba puesta ~40 s en cada arranque. Si en ese rato la tele se apagaba y prendía —fácil con
el **inicio rápido** de LG, que hace encendidos cortos—, el arranque siguiente veía la marca y entraba en failsafe.

## La solución (aplicada)
1. **El debloat se lanza en segundo plano** (`setsid … &`): el `init.d` ahora vuelve en ~3 s en vez de ~40 s, así
   la ventana peligrosa casi desaparece. El debloat igual se hace (medido: publicidad/precarga apagadas, 400+ MB
   libres). El inicio, el protector y los montajes van primero y rápido.
2. **Vigilante de persistencia en `bucles.sh`:** cada 30 s revisa que el montaje del inicio siga puesto; si webOS
   lo pisó (inicio rápido, restauración del snapshot), vuelve a correr el `init.d` (que es idempotente). Probado:
   se desmonta todo a mano y a los ~30 s vuelve solo. Queda registrado en `cytv-debloat.log` ("montajes caídos").
3. **Opcional, a prueba de balas:** apagar el inicio rápido de LG (`quickStartMode`) para que cada encendido sea un
   arranque completo. Cuesta ~10-20 s más de encendido; lo decide la persona.

## Recuperación manual si vuelve a pasar
Por el puente del celular: `nc $TV_IP 23` (telnet de emergencia, da root). Después: relanzar dropbear
(`/media/developer/apps/usr/palm/services/org.webosbrew.hbchannel.service/bin/dropbear -R &`) y correr
`sh /var/lib/webosbrew/init.d/50-cytv-debloat`. Vuelve todo en segundos.
