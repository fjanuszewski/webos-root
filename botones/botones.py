# -*- coding: utf-8 -*-
# botones.py — le da a cada botón del control (Magic Remote) la función que se elija en
# Configuración → Control remoto (cleanhome/RemoteEditor.qml). Python 2.7 (viene en la tele). Ver BOTONES.md.
# En el mismo programa corre el vigilante de apps (vigilante.py: cierra las apps que quedan abiertas atrás).
#
# La Python de la tele viene recortada: no trae "threading" ni "pty" (se usan "thread" y os.openpty).
# Cómo funciona (la misma idea que magic_mapper, github.com/andrewfraley/magic_mapper):
#   - "agarra" en exclusiva el dispositivo del control ("LGE M-RCU - Builtin [0]", EVIOCGRAB): la tele deja de
#     recibir sus botones directamente;
#   - cada evento que llega se reenvía tal cual a otro dispositivo del control que ya existe ("Builtin [1]" o [2]),
#     salvo los botones que tienen algo asignado: esos no se reenvían y se hace lo elegido;
#   - si este programa se cae o se cierra, el sistema suelta el control solo y todo vuelve a funcionar de fábrica.
#   - solo agarra el control si hay al menos un botón con algo asignado (o si se está eligiendo uno desde la
#     pantalla: "modo elegir"); si no, ni lo toca.
#
# Archivos:
#   /var/lib/webosbrew/cleanhome/botones.json   qué hace cada botón (lo escribe la pantalla; se relee solo)
#       { "red": {"type": "input", "id": "com.webos.app.hdmi1", "label": "Entrada HDMI 1"}, ... }
#       tipos: app (id), input (id), url (url), screensaver, screenoff, sleep, panel (panel),
#              volume (volume), soundout, none. Botón ausente = de fábrica.
#   /tmp/cytv-botones-captura   "modo elegir": la pantalla lo escribe (con la hora en ms) mientras espera que se
#                               toque un botón; el próximo botón asignable que se toque NO hace nada y se anota en
#   /tmp/cytv-botones-tocado    {"key": "red", "t": <ms>} (la pantalla lo lee y guarda la asignación)
#   /tmp/cytv-abrir-panel       para "Abrir un panel": {"panel": "wifi", "t": <ms>}; lo lee el inicio al aparecer
#   /tmp/cytv-botones.log       registro (se recorta solo)
from __future__ import print_function
import errno
import fcntl
import json
import os
import select
import struct
import subprocess
import sys
import thread
import time

import vigilante

CONFIG = "/var/lib/webosbrew/cleanhome/botones.json"
CAPTURE = "/tmp/cytv-botones-captura"
TOUCHED = "/tmp/cytv-botones-tocado"
PANEL_NOTE = "/tmp/cytv-abrir-panel"
LOG = "/tmp/cytv-botones.log"
STATE = "/tmp/cytv-botones-estado.json"   # para la pantalla: {"bt": si la tele tiene audio Bluetooth}
NO_BT = "/var/lib/webosbrew/apagar-audio-bt"
INPUT_NAME = "LGE M-RCU - Builtin [0]"
OUTPUT_NAMES = ["LGE M-RCU - Builtin [2]", "LGE M-RCU - Builtin [1]"]

EVIOCGRAB = 1074021776
EV_SYN, EV_KEY = 0, 1
EVENT = "llHHi"
EVENT_SIZE = struct.calcsize(EVENT)

# Botones que se pueden cambiar (códigos del Magic Remote MR20, AKB75855501).
KEYS = {
    1037: "netflix",
    1038: "prime",
    398: "red",
    399: "green",
    400: "yellow",
    401: "blue",
    207: "play",
    119: "pause",
}
MOVIES_CODES = [1039]   # medido: abre com.webos.app.discovery (películas de LG)
for c in MOVIES_CODES:
    KEYS[c] = "movies"

def log(msg):
    try:
        if os.path.exists(LOG) and os.path.getsize(LOG) > 256 * 1024:
            open(LOG, "w").close()
        with open(LOG, "a") as f:
            f.write("%s %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg))
    except (IOError, OSError):
        pass


def now_ms():
    return int(time.time() * 1000)


# ---------- luna ----------
# luna-send sin terminal a veces no hace la llamada (ver CLAUDE.md): se le da una terminal de mentira (pty).
def luna(url, payload, app=None, timeout=8):
    cmd = ["/usr/bin/luna-send", "-n", "1"]
    if app:
        cmd += ["-a", app]
    cmd += [url, json.dumps(payload)]
    master, slave = os.openpty()
    try:
        p = subprocess.Popen(cmd, stdin=slave, stdout=slave, stderr=slave, close_fds=True)
    except OSError as e:
        os.close(master)
        os.close(slave)
        log("luna-send no arrancó: %s" % e)
        return None
    os.close(slave)
    out = b""
    end = time.time() + timeout
    while time.time() < end:
        r = select.select([master], [], [], 0.2)[0]
        if r:
            try:
                chunk = os.read(master, 4096)
            except OSError:
                break
            if not chunk:
                break
            out += chunk
            if b"returnValue" in out and out.rstrip().endswith(b"}"):
                break
        elif p.poll() is not None:
            break
    try:
        p.kill()
    except OSError:
        pass
    p.wait()
    os.close(master)
    text = out.decode("utf-8", "replace")
    i = text.find("{")
    if i < 0:
        return None
    try:
        return json.loads(text[i:text.rfind("}") + 1])
    except ValueError:
        return None


def toast(msg):
    luna("luna://com.webos.notification/createToast", {"sourceId": "webosbrew", "message": msg}, app="webosbrew")


def launch(app_id, params=None):
    p = {"id": app_id}
    if params:
        p["params"] = params
    return luna("luna://com.webos.applicationManager/launch", p)


def foreground():
    r = luna("luna://com.webos.applicationManager/getForegroundAppInfo", {})
    return (r or {}).get("appId", "") if r else ""


# ---------- lo que puede hacer un botón ----------
state = {"screen_off": False}
state_lock = thread.allocate_lock()


def act(a):
    t = a.get("type")
    if t == "app" or t == "input":
        launch(a.get("id", ""))
    elif t == "url":
        launch("com.webos.app.browser", {"target": a.get("url", "")})
    elif t == "screensaver":
        luna("luna://com.webos.service.tvpower/power/turnOnScreenSaver", {})
    elif t == "screenoff":
        r = luna("luna://com.webos.service.tvpower/power/turnOffScreen", {})
        if r and r.get("returnValue"):
            with state_lock:
                state["screen_off"] = True
    elif t == "sleep":
        r = luna("luna://com.webos.settingsservice/getSystemSettings", {"category": "time", "keys": ["sleepTimer"]})
        cur = ((r or {}).get("settings") or {}).get("sleepTimer", "off")
        nxt = {"off": "30", "30": "60", "60": "90"}.get(str(cur), "off")
        luna("luna://com.webos.settingsservice/setSystemSettings", {"category": "time", "settings": {"sleepTimer": nxt}})
        toast("Temporizador apagado" if nxt == "off" else "La tele se apaga en %s minutos" % nxt)
    elif t == "panel":
        with open(PANEL_NOTE, "w") as f:
            f.write(json.dumps({"panel": a.get("panel", ""), "t": now_ms()}))
        launch("com.webos.app.fullhome")
    elif t == "volume":
        v = max(0, min(100, int(a.get("volume", 15))))
        luna("luna://com.webos.audio/setVolume", {"volume": v})
        toast("Volumen %d" % v)
    elif t == "soundout":
        r = luna("luna://com.webos.settingsservice/getSystemSettings", {"category": "sound", "keys": ["soundOutput"]})
        cur = ((r or {}).get("settings") or {}).get("soundOutput", "tv_speaker")
        if cur.startswith("bt_"):
            nxt = a.get("back", "tv_speaker")
        else:
            nxt = "bt_soundbar"
        luna("luna://com.webos.settingsservice/setSystemSettings", {"category": "sound", "settings": {"soundOutput": nxt}})
        toast("Sonido por Bluetooth" if nxt.startswith("bt_") else "Sonido por la tele")
    # "none": no hace nada


def run_action(name, a):
    def go():
        try:
            log("%s → %s" % (name, a.get("type")))
            act(a)
        except Exception as e:  # una acción que falla no tiene que tirar el programa
            log("falló %s: %s" % (name, e))
    thread.start_new_thread(go, ())


# ---------- configuración ----------
config_cache = {"mtime": -1, "map": {}}


def load_config():
    try:
        m = os.stat(CONFIG).st_mtime
    except OSError:
        m = 0
    if m == config_cache["mtime"]:
        return config_cache["map"]
    config_cache["mtime"] = m
    mp = {}
    if m:
        try:
            with open(CONFIG) as f:
                raw = json.load(f)
            for k, v in raw.items():
                if isinstance(v, dict) and v.get("type") and v.get("type") != "default":
                    mp[k] = v
        except (IOError, OSError, ValueError) as e:
            log("botones.json ilegible: %s" % e)
    config_cache["map"] = mp
    log("configuración: %s" % (", ".join("%s=%s" % (k, v.get("type")) for k, v in sorted(mp.items())) or "todo de fábrica"))
    return mp


def capturing():
    try:
        with open(CAPTURE) as f:
            t = int(f.read().strip() or 0)
        return now_ms() - t < 60000
    except (IOError, OSError, ValueError):
        return False


def needed():
    return bool(load_config()) or capturing()


# ---------- dispositivos ----------
def devices():
    out = {}
    name = None
    try:
        with open("/proc/bus/input/devices") as f:
            for line in f:
                if line.startswith("N: Name="):
                    name = line.strip()[len("N: Name="):].strip('"')
                elif line.startswith("H: Handlers=") and name:
                    for h in line.split("=", 1)[1].split():
                        if h.startswith("event"):
                            out[name] = "/dev/input/" + h
    except IOError:
        pass
    return out


def main_loop():
    devs = devices()
    src = devs.get(INPUT_NAME)
    dst = None
    for n in OUTPUT_NAMES:
        if devs.get(n):
            dst = devs[n]
            break
    if not src or not dst:
        log("no encuentro el control (%s) o por dónde reenviar (%s): no agarro nada" % (src, dst))
        return 2
    fd = os.open(src, os.O_RDONLY)
    out = os.open(dst, os.O_WRONLY)
    grabbed = False
    swallowed = set()           # botones cuyo "apretar" no se reenvió: tampoco se reenvía su "soltar"
    log("control en %s, reenvío por %s" % (src, dst))
    try:
        while True:
            want = needed()
            if want and not grabbed:
                fcntl.ioctl(fd, EVIOCGRAB, 1)
                grabbed = True
                log("control agarrado")
            elif not want and grabbed:
                fcntl.ioctl(fd, EVIOCGRAB, 0)
                grabbed = False
                swallowed.clear()
                log("control suelto (nada asignado)")
            r = select.select([fd], [], [], 2)[0]
            if not r:
                continue
            data = os.read(fd, EVENT_SIZE * 64)
            if not grabbed:
                continue                # sin agarrarlo la tele recibe todo sola
            mp = config_cache["map"]
            cap = None
            for i in range(0, len(data) - EVENT_SIZE + 1, EVENT_SIZE):
                ev = data[i:i + EVENT_SIZE]
                sec, usec, typ, code, value = struct.unpack(EVENT, ev)
                if typ == EV_KEY:
                    with state_lock:
                        off = state["screen_off"]
                    if off:
                        # pantalla apagada: cualquier botón la prende (y no hace nada más)
                        if value == 1:
                            with state_lock:
                                state["screen_off"] = False
                            log("pantalla apagada: un botón la prende")
                            luna_async("luna://com.webos.service.tvpower/power/turnOnScreen", {})
                        swallowed.add(code)
                        continue
                    name = KEYS.get(code)
                    if name:
                        if cap is None:
                            cap = capturing()
                        if value == 1 and cap:
                            with open(TOUCHED, "w") as f:
                                f.write(json.dumps({"key": name, "t": now_ms()}))
                            log("modo elegir: tocaron %s" % name)
                            swallowed.add(code)
                            continue
                    elif value == 1:
                        if cap is None:
                            cap = capturing()
                        if cap:
                            # para medir botones nuevos (ej. MOVIES): queda el número en el log y sigue de largo
                            log("modo elegir: botón sin nombre, código %d" % code)
                    if name:
                        a = mp.get(name)
                        if a:
                            if value == 1:
                                run_action(name, a)
                            swallowed.add(code)
                            continue
                    if code in swallowed:
                        if value == 0:
                            swallowed.discard(code)
                        continue
                os.write(out, ev)
    finally:
        if grabbed:
            try:
                fcntl.ioctl(fd, EVIOCGRAB, 0)
            except IOError:
                pass
        os.close(fd)
        os.close(out)


def luna_async(url, payload):
    thread.start_new_thread(lambda: luna(url, payload), ())


if __name__ == "__main__":
    # --durar N: se cierra solo a los N segundos (para probar sin riesgo: si algo sale mal, el control vuelve solo)
    if "--durar" in sys.argv:
        secs = int(sys.argv[sys.argv.index("--durar") + 1])

        def killer():
            time.sleep(secs)
            log("fin de la prueba (--durar %d)" % secs)
            os._exit(0)
        thread.start_new_thread(killer, ())
    log("arranca botones.py (pid %d)" % os.getpid())
    try:
        with open(STATE, "w") as f:
            f.write(json.dumps({"bt": not os.path.exists(NO_BT)}))
    except (IOError, OSError):
        pass
    vigilante.start(luna, thread.start_new_thread)
    try:
        while True:
            code = main_loop() or 0
            # Sin control a la vista no se agarra nada, pero el programa sigue (el vigilante corre igual) y
            # vuelve a buscarlo en un minuto.
            log("control no disponible (código %d): reintento en 60 s" % code)
            time.sleep(60)
    except KeyboardInterrupt:
        sys.exit(0)
