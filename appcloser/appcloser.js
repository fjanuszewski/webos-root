// appcloser.js — cierra las apps que quedan abiertas en segundo plano (pedido del usuario: "no quiero dejar apps abiertas").
// Corre como root en la TV (Node 0.12, ES5) y habla con el sistema por palmbus (luna-send no devuelve respuestas acá).
//
// Cómo funciona:
//   - cada 3 s le pregunta a la tele qué app está al frente (applicationManager/getForegroundAppInfo).
//     NO usa la suscripción: cuando la tele "despierta" del quick start sin reiniciarse, la suscripción
//     queda muerta sin avisar, y el vigilante creía que seguía al frente la app vieja (2026-10-24: cerraba
//     YouTube mientras se miraba, y la tele saltaba al HDMI);
//   - cuando cambia (abriste Netflix, pasaste al HDMI de la Xbox, etc.), espera unos segundos y cierra
//     las demás apps de usuario que sigan abiertas (Netflix, YouTube, Amazon, apps instaladas...);
//   - ANTES de cerrar, vuelve a preguntar qué está al frente en ese momento. Si la tele no contesta, no cierra
//     nada. Nunca cierra lo que está al frente;
//   - si nota que la tele estuvo "dormida" (el reloj saltó), espera 30 s antes de cerrar nada;
//   - al arrancar hace una pasada para cerrar las que la tele abrió sola (precarga).
// No toca: el Home, las entradas (HDMI/TV), el protector, menús del sistema ni Configuración.
// Apagar SOLO el vigilante: crear /var/lib/webosbrew/appcloser/VIGILANTE-OFF (run.sh y este proceso lo respetan).
// (appcloser/DISABLED es otra cosa: además apaga el corte de la precarga de apps en el arranque.)
// palmbus vive en /usr/lib/nodejs: los servicios de la tele lo encuentran por NODE_PATH, pero al arrancar desde
// el script de inicio (o por SSH) esa variable no está → se busca también por ruta fija.
var pb;
try { pb = require('palmbus'); } catch (e) {
  try { pb = require('/usr/lib/nodejs/palmbus'); } catch (e2) { pb = require('/usr/palm/nodejs/palmbus'); }
}
var fs = require('fs');

var LOG = '/tmp/cytv-appcloser.log';
var OFF = ['/var/lib/webosbrew/appcloser/VIGILANTE-OFF', '/var/lib/webosbrew/appcloser/DISABLED'];
var POLL = 3000;             // cada cuánto pregunta qué app está al frente
var FG_TIMEOUT = 3000;       // si la tele no contesta en este tiempo, no se cierra nada
var DELAY = 5000;            // espera después de un cambio de app (que termine la transición)
var MIN_AGE = 8000;          // no cierra una app que apareció hace menos de esto (puede estar abriéndose)

// Apps del sistema que sí conviene cerrar (las abre la precarga o el asistente y quedan colgadas)
// (El Asistente de Google NO va acá: el usuario usa la voz y la tele lo reabre sola; cerrarlo gasta más de lo que ahorra.)
var CLOSE_SYSTEM = {
  'com.webos.app.livemenu': 1,
  'com.webos.app.tips': 1,
  'com.webos.app.browser': 1,
  'amazon.alexa.view': 1
};

// Asistentes de voz: solo se cierran al cambiar de app (no en la pasada periódica, por si estás hablando)
var VOICE = { 'amazon.alexa.view': 1 };

function log(m) {
  try {
    var st = fs.existsSync(LOG) ? fs.statSync(LOG) : null;
    if (st && st.size > 200000) fs.writeFileSync(LOG, '');
    fs.appendFileSync(LOG, new Date().toISOString() + ' ' + m + '\n');
  } catch (e) {}
}

function isSystem(id) {
  return id.indexOf('com.webos.') === 0 || id.indexOf('com.palm.') === 0 || id.indexOf('com.lge.') === 0 ||
         id.indexOf('org.webosbrew.') === 0 || id.indexOf('lg.') === 0;
}
// Si el usuario NO apagó la transmisión desde el celular, la app de AirPlay se respeta (es la que recibe el video)
function keepCasting() {
  try { return !fs.existsSync('/var/lib/webosbrew/apagar-transmision'); } catch (e) { return true; }
}
function closeable(id, fg, periodic) {
  if (!id || id === fg) return false;
  if (id === 'airplay' && keepCasting()) return false;
  if (CLOSE_SYSTEM[id]) return !(periodic && VOICE[id]);   // el asistente de voz no se cierra en la pasada periódica
  return !isSystem(id);
}
// Solo cuenta como "cambiar de app" pasar a una app de usuario o a una entrada (HDMI de la Xbox, TV...).
// El protector, el Home, el volumen, el menú de entradas o el asistente encima de Netflix NO cierran Netflix.
function isRealApp(id) {
  return !isSystem(id) || /^com\.webos\.app\.(hdmi|livetv|externalinput|photovideo|mediaplayer|browser)/.test(id);
}

var h = new pb.Handle('', false);
function call(uri, params, cb) {
  var c = h.call(uri, JSON.stringify(params || {}));
  c.addListener('response', function (m) {
    var p = {};
    try { p = JSON.parse(m.payload()); } catch (e) {}
    if (cb) cb(p);
  });
  return c;
}

function apagado() {
  for (var i = 0; i < OFF.length; i++) { try { if (fs.existsSync(OFF[i])) return true; } catch (e) {} }
  return false;
}

var fg = '';                 // última app "real" al frente (de usuario o entrada)
var quietUntil = 0;          // no cerrar nada hasta este momento (después de despertar)
var firstSeen = {};          // id -> ms desde que la vimos abierta
var timer = null;
var tries = {};              // id -> cuántas veces se pidió cerrarla y siguió abierta

// Pregunta qué está al frente AHORA. cb(appId) o cb(null) si la tele no contestó a tiempo.
function askFg(cb) {
  var done = false;
  var t = setTimeout(function () { if (!done) { done = true; cb(null); } }, FG_TIMEOUT);
  call('luna://com.webos.applicationManager/getForegroundAppInfo', {}, function (r) {
    if (done) return;
    done = true; clearTimeout(t);
    cb(r && r.returnValue !== false ? (r.appId || '') : null);
  });
}

function sweep(reason) {
  if (apagado()) return;
  if (Date.now() < quietUntil) { log('pasada salteada (la tele recién despertó): ' + reason); return; }
  askFg(function (now) {
    if (now === null) { log('pasada salteada: la tele no dijo qué está al frente (' + reason + ')'); return; }
    sweepWith(reason, now);
  });
}

function sweepWith(reason, fgNow) {
  var periodic = reason === 'pasada periódica';
  if (fgNow && isRealApp(fgNow) && fgNow !== fg) { log('al frente (corregido): ' + fgNow + ' (creía: ' + (fg || '?') + ')'); fg = fgNow; }
  call('luna://com.webos.applicationManager/running', {}, function (r) {
    var now = Date.now(), list = r.running || [], seen = {};
    for (var i = 0; i < list.length; i++) {
      var id = list[i].id;
      seen[id] = 1;
      if (firstSeen[id] === undefined) firstSeen[id] = now;
      if (id === fgNow || id === fg) continue;     // lo que está al frente NUNCA se cierra
      if (closeable(id, fg, periodic) && now - firstSeen[id] >= MIN_AGE) {
        (function (app) {
          var id = app.id;
          // Apps "tercas": el sistema dice que la cerró pero sigue abierta (ej. la app web de AirPlay, que
          // tiene enableBackgroundRun). Si ya se pidió cerrarla 2 veces y sigue:
          //   - app web → se la cierra desde el motor de apps web (webappmanager/killApp), que sí la cierra;
          //   - app nativa → se termina su proceso a la fuerza.
          if ((tries[id] || 0) >= 2) {
            tries[id] = 0;
            if (app.webprocessid) {
              call('luna://com.palm.webappmanager/killApp', { appId: id, reason: 'cytv-appcloser' }, function (p) {
                log('forzada ' + id + ' (killApp, no cerraba)' + (p.returnValue ? '' : ' ERROR ' + (p.errorText || '')));
              });
            } else {
              var pid = parseInt(app.processid, 10);
              if (pid > 1) {
                try { process.kill(pid, 'SIGKILL'); log('forzada ' + id + ' (pid ' + pid + ', no cerraba)'); } catch (e) { log('no pude forzar ' + id + ': ' + e.message); }
              }
            }
            return;
          }
          call('luna://com.webos.applicationManager/closeByAppId', { id: id }, function (p) {
            tries[id] = (tries[id] || 0) + 1;
            log('cerrada ' + id + ' (al frente: ' + (fg || '?') + ', motivo: ' + reason + ')' + (p.returnValue ? '' : ' ERROR ' + (p.errorText || '')));
          });
        })(list[i]);
      }
    }
    for (var k in firstSeen) if (!seen[k]) { delete firstSeen[k]; delete tries[k]; }
  });
}

function schedule(reason) {
  if (timer) clearTimeout(timer);
  timer = setTimeout(function () { timer = null; sweep(reason); }, DELAY);
}

// Mantiene registro de cuándo aparece cada app (para no cerrar una que se está abriendo).
// Las que ya estaban abiertas cuando arranca el vigilante cuentan como "viejas" (se pueden cerrar enseguida).
var firstList = true;
call('luna://com.webos.applicationManager/running', { subscribe: true }, function (r) {
  var now = firstList ? 0 : Date.now(), list = r.running || [];
  firstList = false;
  for (var i = 0; i < list.length; i++) if (firstSeen[list[i].id] === undefined) firstSeen[list[i].id] = now;
});

// Cada 3 s: qué app está al frente. Si cambió a una app real, pasada a los 5 s.
var lastPoll = Date.now();
var fails = 0;
setInterval(function () {
  var t = Date.now(), gap = t - lastPoll;
  lastPoll = t;
  if (gap > 60000) {                          // el reloj saltó: la tele estuvo dormida (quick start)
    quietUntil = t + 30000;
    log('la tele despertó (' + Math.round(gap / 1000) + ' s sin correr): espero 30 s antes de cerrar nada');
  }
  if (apagado()) return;
  askFg(function (id) {
    if (id === null) {
      // La tele no contesta: puede ser que la conexión con el sistema haya quedado muerta después de dormir.
      // Con 5 fallas seguidas se sale, y run.sh lo vuelve a arrancar en 10 s con una conexión nueva.
      if (++fails >= 5) { log('la tele no contesta hace ' + fails + ' intentos: reinicio el vigilante'); process.exit(3); }
      return;
    }
    fails = 0;
    if (!id || id === fg) return;
    if (!isRealApp(id)) return;               // protector, Home, volumen, menús encima: no es cambio de app
    var prev = fg;
    fg = id;
    log('al frente: ' + fg + (prev ? ' (antes: ' + prev + ')' : ''));
    schedule(prev ? 'cambio de app' : 'arranque');
  });
}, POLL);

log('appcloser iniciado (pid ' + process.pid + ')');
// Pasada cada 5 min: cierra lo que se haya abierto solo (navegador precargado, etc.); nunca la app al frente
setInterval(function () { sweep('pasada periódica'); }, 300000);
