# -*- coding: utf-8 -*-
# vigilante.py — cierra las apps que quedan abiertas atrás y le devuelve memoria a la tele. Python 2.7.
# Corre dentro de botones.py (un solo programa liviano, ~4 MB). Antes era appcloser/appcloser.js (Node, ~32 MB).
#
# Qué hace:
#   - cada 5 s pregunta qué app está al frente (getForegroundAppInfo; NO usa suscripciones: después de que la
#     tele "despierta" del quick start quedan muertas sin avisar);
#   - cuando pasás a otra app o entrada (Netflix → YouTube, YouTube → HDMI de la Xbox), a los 5 s cierra las
#     demás apps de usuario que sigan abiertas atrás;
#   - si el inicio queda a la vista 1 minuto, también cierra las de atrás (antes Netflix quedaba abierto, 60-90 MB).
#     Ojo: con el inicio encima de Netflix la tele sigue diciendo que al frente está Netflix; por eso se usa la
#     nota que deja el inicio (/tmp/cytv-inicio-visible);
#   - entradas (HDMI): el protector de fotos deja la parte de entradas de LG en ~110 MB en vez de ~83. Si estás en
#     otra cosa (app o inicio) hace más de 2 min y esa parte ocupa más de 100 MB, se cierra por detrás; LG la
#     vuelve a abrir sola cuando elegís la entrada (desde su copia "congelada", liviana);
#   - antes de cerrar algo vuelve a preguntar qué está al frente: nunca cierra lo que estás viendo. Si la tele
#     no contesta, no cierra nada. Si la tele estuvo "dormida" (el reloj saltó), espera 30 s;
#   - cada 5 min, una pasada por las que la tele abre sola (navegador precargado, etc.). Si en la instalación se
#     apagó la transmisión desde el celular (apagar-transmision), también vuelve a parar ThinQ (iot-client, ~5 MB)
#     y "compartir pantalla" (ss.gateway, ~25 MB), que a veces reaparecen solos después del arranque.
# No toca: el inicio, las entradas al frente, el protector, menús del sistema ni Configuración.
# Apagarlo (solo el vigilante): crear /var/lib/webosbrew/appcloser/VIGILANTE-OFF. (appcloser/DISABLED, además,
# deja de cortar la precarga de apps en el arranque.)
import json
import os
import re
import time

LOG = "/tmp/cytv-appcloser.log"
OFF = ["/var/lib/webosbrew/appcloser/VIGILANTE-OFF", "/var/lib/webosbrew/appcloser/DISABLED"]
NO_CAST = "/var/lib/webosbrew/apagar-transmision"
POLL = 5            # s entre preguntas
DELAY = 5           # s después de un cambio de app antes de cerrar (que termine la transición)
MIN_AGE = 8         # s: no cierra una app que recién aparece (puede estar abriéndose)
HOME_IDLE = 60      # s con el inicio al frente → cierra las de atrás
INPUTS_IDLE = 120   # s sin usar las entradas → si ocupan mucho, se cierran
INPUTS_MAX_KB = 100 * 1024
PERIODIC = 300      # s entre pasadas generales
HOME = "com.webos.app.fullhome"
HOME_NOTE = "/tmp/cytv-inicio-visible"   # "1"/"0": lo escribe el inicio (CleanRecents.qml) al mostrarse/esconderse
INPUTS_PROC = "com.webos.app.inputcommon"

# Apps del sistema que sí conviene cerrar (las abre la precarga y quedan colgadas). El asistente de Google no.
CLOSE_SYSTEM = set(["com.webos.app.livemenu", "com.webos.app.tips", "com.webos.app.browser", "amazon.alexa.view"])
VOICE = set(["amazon.alexa.view"])     # solo al cambiar de app, no en la pasada periódica (por si estás hablando)
SYSTEM_PREFIX = ("com.webos.", "com.palm.", "com.lge.", "org.webosbrew.", "lg.")
INPUT_APP = re.compile(r"^com\.webos\.app\.(hdmi|livetv|externalinput|av|comp|scart)")
REAL_SYSTEM = re.compile(r"^com\.webos\.app\.(hdmi|livetv|externalinput|photovideo|mediaplayer|browser)")


def log(msg):
    try:
        if os.path.exists(LOG) and os.path.getsize(LOG) > 200 * 1024:
            open(LOG, "w").close()
        with open(LOG, "a") as f:
            f.write("%s %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg))
    except (IOError, OSError):
        pass


def apagado():
    return any(os.path.exists(f) for f in OFF)


def is_system(i):
    return i.startswith(SYSTEM_PREFIX)


def is_real_app(i):
    """Cuenta como "cambiar de app": una app de usuario o una entrada. El protector, el inicio, el volumen o un
    menú encima de Netflix NO cierran Netflix."""
    return not is_system(i) or bool(REAL_SYSTEM.match(i))


def closeable(i, periodic):
    if i == "airplay" and not os.path.exists(NO_CAST):
        return False                  # si se usa mandar desde el celular, la app de AirPlay se respeta
    if i in CLOSE_SYSTEM:
        return not (periodic and i in VOICE)
    return not is_system(i)


def home_visible_since():
    """Desde cuándo (epoch s) se ve el inicio, o None si no se ve."""
    try:
        with open(HOME_NOTE) as f:
            if f.read(1) != "1":
                return None
        return os.path.getmtime(HOME_NOTE)
    except (IOError, OSError):
        return None


def proc_kb(name):
    """RAM + swap (KB) del proceso con ese nombre, o 0."""
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open("/proc/%s/cmdline" % pid) as f:
                if not f.read().split("\0")[0].endswith(name):
                    continue
            kb = 0
            with open("/proc/%s/status" % pid) as f:
                for line in f:
                    if line.startswith(("VmRSS:", "VmSwap:")):
                        kb += int(line.split()[1])
            return kb, int(pid)
        except (IOError, OSError, ValueError):
            continue
    return 0, 0


# Servicios de transmisión que reaparecen solos: (nombre del proceso, trabajo de upstart)
CAST_RESPAWN = [("iot-client", "iot-client"), ("ss.gateway", "second-screen-gateway")]


def stop_cast_respawn():
    if not os.path.exists(NO_CAST):
        return
    for name, job in CAST_RESPAWN:
        kb, pid = proc_kb(name)
        if not pid:
            continue
        os.system("initctl stop %s >/dev/null 2>&1" % job)
        try:
            os.kill(pid, 9)
        except OSError:
            pass
        log("transmisión apagada: %s había vuelto (%d MB), parado otra vez" % (name, kb // 1024))


class Vigilante(object):
    def __init__(self, luna):
        self.luna = luna
        self.log = log
        self.fg = ""                  # última app "real" al frente
        self.raw_fg = ""              # lo que está al frente, sea lo que sea
        self.raw_since = time.time()
        self.inputs_used = time.time()   # última vez que una entrada estuvo al frente
        self.quiet_until = 0
        self.first_seen = {}
        self.tries = {}
        self.home_swept = None        # momento del inicio visible que ya se limpió

    def ask_fg(self):
        r = self.luna("luna://com.webos.applicationManager/getForegroundAppInfo", {}, timeout=4)
        if not r or r.get("returnValue") is False:
            return None
        return r.get("appId", "") or ""

    def sweep(self, reason):
        if apagado():
            return
        if time.time() < self.quiet_until:
            self.log("pasada salteada (la tele recién despertó): " + reason)
            return
        now_fg = self.ask_fg()
        if now_fg is None:
            self.log("pasada salteada: la tele no dijo qué está al frente (%s)" % reason)
            return
        periodic = reason == "pasada periódica"
        # Con el inicio a la vista, la app que la tele dice "al frente" está tapada: también se cierra, pero solo si
        # el inicio se sigue viendo en este momento.
        home = reason.startswith("inicio") and home_visible_since() is not None
        if reason.startswith("inicio") and not home:
            return
        r = self.luna("luna://com.webos.applicationManager/running", {}, timeout=6) or {}
        now = time.time()
        seen = set()
        for app in r.get("running", []):
            i = app.get("id", "")
            seen.add(i)
            if i not in self.first_seen:
                self.first_seen[i] = 0 if reason == "arranque" else now
            if not i or (not home and (i == now_fg or i == self.fg)):
                continue                          # lo que está al frente NUNCA se cierra (salvo tapado por el inicio)
            if not closeable(i, periodic) or now - self.first_seen[i] < MIN_AGE:
                continue
            if self.tries.get(i, 0) >= 2:
                # app "terca": dice que se cerró pero sigue (ej. la web de AirPlay)
                self.tries[i] = 0
                if app.get("webprocessid"):
                    p = self.luna("luna://com.palm.webappmanager/killApp", {"appId": i, "reason": "cytv-appcloser"}) or {}
                    self.log("forzada %s (killApp, no cerraba)%s" % (i, "" if p.get("returnValue") else " ERROR"))
                else:
                    try:
                        os.kill(int(app.get("processid", 0)), 9)
                        self.log("forzada %s (no cerraba)" % i)
                    except (OSError, ValueError) as e:
                        self.log("no pude forzar %s: %s" % (i, e))
                continue
            p = self.luna("luna://com.webos.applicationManager/closeByAppId", {"id": i}) or {}
            self.tries[i] = self.tries.get(i, 0) + 1
            if i == self.fg:
                self.fg = ""                      # (cerrada desde el inicio: si se vuelve a abrir, cuenta como cambio)
            self.log("cerrada %s (al frente: %s, motivo: %s)%s" % (i, now_fg or "?", reason, "" if p.get("returnValue") else " ERROR"))
        for k in list(self.first_seen):
            if k not in seen:
                self.first_seen.pop(k, None)
                self.tries.pop(k, None)

    def check_inputs(self):
        """Libera la memoria que el protector de fotos dejó en la parte de entradas, si no se está usando."""
        if time.time() - self.inputs_used < INPUTS_IDLE:
            return
        kb, pid = proc_kb(INPUTS_PROC)
        if kb < INPUTS_MAX_KB or not pid:
            return
        now_fg = self.ask_fg()                 # confirmar justo antes: ninguna entrada al frente
        if now_fg is None or INPUT_APP.match(now_fg) or now_fg == "":
            return
        try:
            os.kill(pid, 9)
            self.log("entradas: ocupaban %d MB sin usarse; cerradas (LG las vuelve a abrir al elegir una)" % (kb // 1024))
        except OSError as e:
            self.log("entradas: no pude cerrarlas: %s" % e)
        self.inputs_used = time.time()         # no reintentar enseguida

    def run(self):
        self.log("vigilante iniciado (dentro de botones.py, pid %d)" % os.getpid())
        last = time.time()
        last_periodic = last
        pending = None                         # (cuándo, motivo) de la próxima pasada
        while True:
            time.sleep(POLL)
            t = time.time()
            if t - last > 60:
                self.quiet_until = t + 30
                self.log("la tele despertó (%d s sin correr): espero 30 s antes de cerrar nada" % (t - last))
            last = t
            if apagado():
                continue
            try:
                i = self.ask_fg()
                if i is not None:
                    if i != self.raw_fg:
                        self.raw_fg, self.raw_since = i, t
                    if INPUT_APP.match(i):
                        self.inputs_used = t
                    if i and i != self.fg and is_real_app(i):
                        prev, self.fg = self.fg, i
                        self.log("al frente: %s%s" % (i, " (antes: %s)" % prev if prev else ""))
                        pending = (t + DELAY, "cambio de app" if prev else "arranque")
                hs = home_visible_since()
                if hs and hs != self.home_swept and t - hs >= HOME_IDLE:
                    self.home_swept = hs
                    pending = (t, "inicio a la vista 1 min")
                if pending and t >= pending[0]:
                    reason = pending[1]
                    pending = None
                    self.sweep(reason)
                elif t - last_periodic >= PERIODIC:
                    last_periodic = t
                    self.sweep("pasada periódica")
                    stop_cast_respawn()
                self.check_inputs()
            except Exception as e:             # nunca tirar el programa (también maneja el control)
                self.log("vigilante: %s" % e)


def start(luna, start_thread):
    if apagado():
        log("vigilante apagado (VIGILANTE-OFF o DISABLED): no cierra nada hasta que se borre")
    v = Vigilante(luna)
    start_thread(v.run, ())
    return v
