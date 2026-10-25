// reconecta.js — si la tele se quedó sin wifi, se reconecta sola a una red guardada (Node 0.12, ES5).
// Lo llama bucles.sh cada 30 s, solo cuando wlan0 no tiene dirección IP y no hay cable conectado.
// Orden: primero la última red a la que estuvo conectada, después las otras guardadas (de la más reciente a la
// más vieja), y solo las que están al alcance. Si una no conecta en 30 s, prueba la siguiente.
// Las contraseñas las guarda el panel Configuración (CleanSettings.qml) en /var/lib/webosbrew/privado/wifi.json:
//   { "<ssid>": { "security": "psk", "pass": "…", "last": <ms de la última conexión> } }
// No hace nada si:
//   - existe /var/lib/webosbrew/no-guardar-wifi (la persona eligió no guardar contraseñas),
//   - el panel de wifi está en uso (/tmp/cytv-wifi-ocupado renovado hace menos de 60 s),
//   - la tele está conectada por cable, o el wifi está apagado.
// Log: /tmp/cytv-wifi.log (nunca escribe contraseñas).
// Habla con el sistema por palmbus, como el vigilante (luna-send sin terminal no devuelve respuestas).
var pb;
try { pb = require('palmbus'); } catch (e) {
  try { pb = require('/usr/lib/nodejs/palmbus'); } catch (e2) { pb = require('/usr/palm/nodejs/palmbus'); }
}
var fs = require('fs');

var STORE = '/var/lib/webosbrew/privado/wifi.json';
var OFF = '/var/lib/webosbrew/no-guardar-wifi';
var BUSY = '/tmp/cytv-wifi-ocupado';
var LOG = '/tmp/cytv-wifi.log';
var LOCK = '/tmp/cytv-wifi-reconecta.pid';

function log(msg) {
  try { fs.appendFileSync(LOG, new Date().toISOString() + ' ' + msg + '\n'); } catch (e) {}
}
function exists(p) { try { fs.statSync(p); return true; } catch (e) { return false; } }

var h = new pb.Handle('', false);
// Una respuesta por llamada; si el sistema no contesta en 20 s, cb(null).
function luna(url, params, cb) {
  var fired = false, c;
  var t = setTimeout(function () { if (fired) return; fired = true; try { c.cancel(); } catch (e) {} cb(null); }, 20000);
  c = h.call(url, JSON.stringify(params || {}));
  c.addListener('response', function (m) {
    if (fired) return;
    fired = true; clearTimeout(t);
    var j = null;
    try { j = JSON.parse(m.payload()); } catch (e) { j = null; }
    try { c.cancel(); } catch (e) {}
    cb(j);
  });
}

function busy() {
  try { return Date.now() - fs.statSync(BUSY).mtime.getTime() < 60000; } catch (e) { return false; }
}

function loadSaved() {
  try { return JSON.parse(fs.readFileSync(STORE, 'utf8')) || {}; } catch (e) { return {}; }
}
function saveLast(ssid) {
  var all = loadSaved();          // se relee por si el panel cambió algo mientras tanto
  if (!all[ssid]) return;
  all[ssid].last = Date.now();
  try {
    fs.writeFileSync(STORE + '.tmp', JSON.stringify(all));
    fs.renameSync(STORE + '.tmp', STORE);
  } catch (e) { log('no pude guardar la fecha de ' + ssid); }
}

function connected(st) { return !!(st && st.networkInfo && st.networkInfo.connectState === 'ipConfigured'); }

// Prueba las redes de "list" en orden; corta en la primera que conecta.
function tryList(list, i) {
  if (i >= list.length) { log('ninguna red guardada conectó'); return done(); }
  if (busy()) { log('el panel de wifi está en uso: dejo de probar'); return done(); }
  var n = list[i];
  // Red sin clave: solo el nombre (con { securityType: 'none' } el sistema contesta "Invalid parameters").
  var p = { ssid: n.ssid };
  if (n.security !== 'none') p.security = { securityType: n.security || 'psk', simpleSecurity: { passKey: n.pass } };
  log('probando ' + n.ssid);
  luna('luna://com.webos.service.wifi/connect', p, function () {
    var start = Date.now();
    (function poll() {
      setTimeout(function () {
        luna('luna://com.webos.service.wifi/getstatus', {}, function (st) {
          if (connected(st) && st.networkInfo.ssid === n.ssid) {
            log('conectada a ' + n.ssid);
            saveLast(n.ssid);
            return done();
          }
          if (Date.now() - start > 30000) { log(n.ssid + ' no conectó'); return tryList(list, i + 1); }
          poll();
        });
      }, 2000);
    })();
  });
}

// palmbus deja el proceso vivo: al terminar se sale a mano.
function done() { try { fs.unlinkSync(LOCK); } catch (e) {} process.exit(0); }

function main() {
  if (exists(OFF) || busy()) return process.exit(0);
  // un solo intento a la vez (si el anterior sigue probando redes, no arrancar otro)
  try {
    var old = parseInt(fs.readFileSync(LOCK, 'utf8'), 10);
    if (old) { process.kill(old, 0); return process.exit(0); }
  } catch (e) {}
  fs.writeFileSync(LOCK, String(process.pid));

  var saved = loadSaved();
  var names = Object.keys(saved).filter(function (k) {
    var v = saved[k];
    return v && (v.security === 'none' || v.pass);
  });
  if (!names.length) return done();

  luna('luna://com.webos.service.connectionmanager/getstatus', {}, function (cm) {
    if (cm && cm.wired && cm.wired.state === 'connected') return done();     // por cable: no hace falta
    luna('luna://com.webos.service.wifi/getstatus', {}, function (st) {
      if (!st || st.status === 'serviceDisabled' || connected(st)) return done();
      luna('luna://com.webos.service.wifi/scan', {}, function () {
        setTimeout(function () {
          luna('luna://com.webos.service.wifi/findnetworks', {}, function (fn) {
            var here = {};
            ((fn && fn.foundNetworks) || []).forEach(function (f) {
              if (f.networkInfo && f.networkInfo.ssid) here[f.networkInfo.ssid] = true;
            });
            // de la más reciente a la más vieja; las que nunca registraron fecha, al final en el orden guardado
            var list = names.filter(function (k) { return here[k]; }).map(function (k, idx) {
              return { ssid: k, security: saved[k].security, pass: saved[k].pass, last: saved[k].last || 0, idx: idx };
            }).sort(function (a, b) { return (b.last - a.last) || (a.idx - b.idx); });
            if (!list.length) return done();
            tryList(list, 0);
          });
        }, 3000);
      });
    });
  });
}

main();
