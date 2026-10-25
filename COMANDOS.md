# COMANDOS — Retomar el acceso a la TV

Guía para retomarlo vos mismo si yo no estoy. Todo desde la Mac, en esta carpeta
(la carpeta del repo).

## TL;DR — retomar de un tiro

```bash
cd webos-root
./restore-chain.sh
```

Si imprime `root_ok: 0` al final, está todo operativo.

---

## Paso a paso (si querés entender/depurar)

### 1. ¿Está el teléfono conectado por adb?
```bash
adb devices -l
```
Tiene que aparecer el serial de tu teléfono (`$PHONE` en `config.local.sh`). Si no, conectá el USB y
aceptá la depuración en el teléfono.

### 2. ¿Está vivo el relay en el teléfono?
```bash
adb -s $PHONE shell 'toybox ps -A -o ARGS | grep "nc -L"'
```
Deberías ver dos `nc -L -p 9922 ...` y `nc -L -p 9991 ...` apuntando a
`$TV_IP`. Si no están, levantalos:
```bash
adb -s $PHONE shell "nohup sh -c 'nc -L -p 9922 nc $TV_IP 9922 & nc -L -p 9991 nc $TV_IP 9991 & wait' >/dev/null 2>&1 &"
```

### 3. Restaurar los forwards de la Mac (ESTO es lo que se cae siempre)
```bash
adb forward tcp:9922 tcp:9922
adb forward tcp:9991 tcp:9991
adb forward --list     # verificar
```

### 4. SSH directo a la TV (como `prisoner`)
```bash
ssh -i ~/.ssh/tv_webos_dec \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa \
  -p 9922 prisoner@127.0.0.1
```

### 5. Ejecutar como ROOT (vía bridge de Homebrew Channel)
```bash
./tvroot.sh 'id'            # -> uid=0(root)
./tvroot.sh 'free -m'       # estado de memoria/swap
./tvroot.sh 'ps -A -o pid,rss,args | sort -k2 -n -r | head -30'   # top RAM
```

---

## Diagnóstico rápido de memoria
```bash
./tvroot.sh 'free -m; echo ---; cat /proc/swaps'
```

## Comprobar que Homebrew Channel está vivo
```bash
./tvroot.sh 'ls -la /media/developer/apps/usr/palm/services/org.webosbrew.hbchannel.service 2>/dev/null; echo ---; luna-send-pub -n 1 -t 1 luna://com.webos.applicationManager/listApps "{}" 2>&1 | head -c 200'
```

---

## Notas
- La clave que funciona es `~/.ssh/tv_webos_dec` (desencriptada). `tv_webos` es la
  encriptada original.
- Si la TV se reinició: root sigue aplicado (Homebrew Channel persiste). Solo hay
  que rehacer forwards (paso 3) y, si hace falta, el relay (paso 2).
- Si cambió la IP de la TV (DHCP del hotspot): actualizá `TV_IP` en
  `restore-chain.sh` y en el comando del relay. Para ver la IP actual desde el
  teléfono, mirá a dónde apuntan los `nc` o revisá el AP.
