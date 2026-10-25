#!/bin/bash
# reinstalar-todo.sh — vuelve a dejar la TV como la tenemos, de un solo comando.
# Para usar si alguna vez hubo que volver a rootear / reinstalar Homebrew Channel.
#
# Antes (en la TV): abrir Homebrew Channel → Configuración → encender "SSH Server".
#   La llave (/home/root/.ssh/authorized_keys) y los ajustes (/var/luna/preferences/webosbrew_*) viven en una
#   partición que no se borra, así que normalmente alcanza con eso para que entremos por el puerto 22.
#
# Qué hace:
#   1. Reconecta la cadena Mac → teléfono → TV (restore-chain.sh).
#   2. Deja el acceso propio: nuestra llave, SSH de Homebrew encendido, telnet sin contraseña apagado.
#   3. Pregunta qué activar y sube todo: pantalla de inicio, protector, calendario, bloqueo de publicidad, vigilante de apps y script de arranque.
#      Pregunta si apagar la transmisión desde el celular y el audio Bluetooth (marcas apagar-transmision y
#      apagar-audio-bt en la TV; variables APAGAR_TRANSMISION / APAGAR_AUDIO_BT = s|n para no preguntar).
#      También si guardar las contraseñas de Wi-Fi (marca no-guardar-wifi; variable NO_GUARDAR_WIFI = s|n).
#   4. Registra el arranque automático de Homebrew (se pierde al reinstalarlo) y lo corre.
set -euo pipefail
cd "$(dirname "$0")/.."
SSHOPTS=(-i "$HOME/.ssh/tv_webos_dec" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
         -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -o ConnectTimeout=15)

echo "== 1. Conexión =="
./restore-chain.sh >/dev/null 2>&1 || true
if ! ssh "${SSHOPTS[@]}" -o BatchMode=yes -p 2222 root@127.0.0.1 true 2>/dev/null; then
  echo "No puedo entrar por el SSH de Homebrew (puerto 22)."
  echo "En la TV: Homebrew Channel → Configuración → encender 'SSH Server' (si ya estaba, apagar y prender), y volver a correr esto."
  echo "(tvroot.sh intenta igual por el modo desarrollador si estuviera activo.)"
fi

echo "== 2. Acceso propio (llave, SSH de Homebrew, sin telnet) =="
PUB=$(ssh-keygen -y -f "$HOME/.ssh/tv_webos_dec")
./tvroot.sh "mkdir -p /home/root/.ssh && chmod 700 /home/root/.ssh
grep -qF '${PUB}' /home/root/.ssh/authorized_keys 2>/dev/null || echo '${PUB} tv-mac' >> /home/root/.ssh/authorized_keys
chmod 600 /home/root/.ssh/authorized_keys; chown -R 0:0 /home/root/.ssh
touch /var/luna/preferences/webosbrew_sshd_enabled /var/luna/preferences/webosbrew_telnet_disabled
pkill telnetd 2>/dev/null; echo acceso-ok"

echo "== 2b. Qué activar y qué no (marcas en la TV; init.d y la pantalla de inicio las respetan) =="
# Respuesta por teclado, o sin preguntar con la variable (s|n). Sin terminal y sin variable: queda como estaba.
#   apagar-transmision → AirPlay, Miracast, DLNA, LG ThinQ/second-screen, HomeKit, SSDP (mandar cosas desde el celular)
#   apagar-audio-bt    → audio por Bluetooth (auriculares/barra). El control remoto Magic Remote sigue andando.
#   no-guardar-wifi    → el panel de Wi-Fi no guarda contraseñas y la tele no se reconecta sola a redes guardadas
#                        (para quien no quiere que las claves queden en un archivo de la tele). Borra las ya guardadas.
preguntar() {   # $1 = variable  $2 = marca en la TV  $3 = pregunta
  local resp="${!1:-}" marca="/var/lib/webosbrew/$2"
  if [ -z "$resp" ] && [ -t 0 ]; then read -r -p "$3 (s/N) " resp; resp="${resp:-n}"; fi
  case "$resp" in
    s|S|si|sí|SI|Sí) ./tvroot.sh "echo 1 > $marca" >/dev/null; echo "  → sí (desde el próximo arranque)";;
    n|N|no|NO|No)    ./tvroot.sh "rm -f $marca" >/dev/null; echo "  → no";;
    *)               echo "  → sin respuesta: queda como estaba";;
  esac
}
preguntar APAGAR_TRANSMISION apagar-transmision "¿Apagar servicios de transmisión desde el celular (AirPlay, Miracast, DLNA)? Ahorra memoria."
preguntar APAGAR_AUDIO_BT apagar-audio-bt "¿Apagar audio Bluetooth (auriculares/barra)? El control remoto sigue andando."
preguntar NO_GUARDAR_WIFI no-guardar-wifi "¿NO guardar contraseñas de Wi-Fi en la tele? (sin ellas no se reconecta sola a tus redes)"

echo "== 3. Subir todo =="
ssh "${SSHOPTS[@]}" -p 2222 root@127.0.0.1 'mkdir -p /var/lib/webosbrew/appcloser'
ssh "${SSHOPTS[@]}" -p 2222 root@127.0.0.1 'cat > /var/lib/webosbrew/hosts' < hosts.block
# (appcloser/ queda solo para los interruptores VIGILANTE-OFF y DISABLED: el vigilante ahora va en botones/,
#  que sube deploy-home.sh. Si hay restos del vigilante viejo en Node, se borran.)
ssh "${SSHOPTS[@]}" -p 2222 root@127.0.0.1 'rm -f /var/lib/webosbrew/appcloser/appcloser.js /var/lib/webosbrew/appcloser/run.sh'
tools/deploy-saver.sh - | tail -n 3
tools/deploy-home.sh - | tail -n 2
# fotos de fondo que la persona dejó en fondos/ (Configuración → Tema → Fondo → Foto)
ls fondos/*.jpg fondos/*.jpeg fondos/*.png fondos/*.JPG fondos/*.PNG >/dev/null 2>&1 && tools/subir-fondo.sh | tail -n 1
rm -f -- ./-

echo "== 4. Arranque automático de Homebrew =="
# luna-send solo muestra la respuesta con una terminal real (-tt)
ssh -tt "${SSHOPTS[@]}" -p 2222 root@127.0.0.1 'rm -f /tmp/webosbrew_startup
luna-send-pub -n 1 -w 60000 luna://org.webosbrew.hbchannel.service/autostart "{}"
luna-send -n 1 luna://com.palm.activitymanager/list "{\"details\":true,\"subscribers\":false,\"internal\":false,\"current\":false}" | tr "," "\n" | grep -c "hbchannel.service.autostart" | sed "s/^/actividad registrada: /"
exit' 2>/dev/null | tr -d '\r'
sleep 40
./tvroot.sh 'tail -n 1 /var/lib/webosbrew/cytv-debloat.log'
echo "== Listo =="
