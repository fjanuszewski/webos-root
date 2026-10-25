// saver/sync.js — arma la lista de fotos de un álbum COMPARTIDO de Google Photos para el protector.
// Corre como root en la TV con su Node 0.12 (sintaxis ES5 a propósito).
//
// Por qué así: desde el 31/03/2025 Google cerró la API de Photos para apps externas. Un álbum
// compartido "con link" sigue siendo una página pública que trae las fotos en sus datos
// (AF_initDataCallback 'ds:1'): URL de cada foto, ancho, alto y fecha. No es una API oficial:
// si Google cambia ese formato, el sync falla pero queda el index.json anterior.
//
// La página trae solo los primeros 300 elementos y un código para pedir los siguientes: el resto se pide de a
// 300 (como hace la página al bajar), por el mismo canal que usa ella (batchexecute, "snAcKc").
//
// No baja las fotos: solo guarda la lista. El protector elige una al azar y la carga
// directo de Google en memoria (URL + "=w1920-h1080"), así la TV no guarda el álbum en disco.
//
// Lo corre bucles.sh cada 1 h. Dos pasos:
//   1) leer el álbum entero (lo pesado, ~30 pedidos): solo si la copia guardada (album.json) tiene más de 6 h,
//      si cambió el enlace del álbum o si se pidió (saver/pedido lo borra bucles.sh antes de llamar: se pasa "ya");
//   2) armar la lista del protector (index.json) con "max" fotos al azar que TODAVÍA NO SALIERON en esta vuelta
//      (usadas.json). Cuando salieron todas, empieza otra vuelta. Así la lista es chica y pasan todas.
//
// Config: saver/config.json -> { "album": "https://photos.app.goo.gl/XXXX", "max": 300 }
// Salida:  saver/index.json -> { updated, total, vuelta: { usadas, total }, photos: [ { url, w, h, ts } ] }
// Guarda:  saver/album.json (todas las fotos del álbum), saver/usadas.json (las que ya salieron en esta vuelta)
var cp = require('child_process');
var fs = require('fs');
var path = require('path');

var DIR = __dirname;
var LOG = '/tmp/cleanhome-saver.log';

function log(m) {
  var line = new Date().toISOString() + ' ' + m + '\n';
  try { fs.appendFileSync(LOG, line); } catch (e) {}
}
function sh(cmd, cb) {
  cp.exec(cmd, { timeout: 60000, maxBuffer: 16 * 1024 * 1024 }, function (err, out) { cb(err, String(out || '')); });
}
function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

// Modo demostración (tools/modo-demo.sh): no se pisa el archivo de mentira
if (fs.existsSync(path.join(DIR, '..', 'DEMO'))) { log('modo demo: no actualizo'); process.exit(0); }
var conf;
try { conf = JSON.parse(fs.readFileSync(path.join(DIR, 'config.json'), 'utf8')); }
catch (e) { log('sin config.json'); process.exit(1); }
var MAX = conf.max || 300;
var RELEER = 6 * 3600 * 1000;    // cada cuánto se lee el álbum entero
var FORZAR = process.argv[2] === 'ya';
var MAX_PAGES = 100;   // hasta 30.000 elementos
// El usuario puede pegar el enlace del álbum compartido o solo su código (lo que va después de photos.app.goo.gl/)
var ALBUM = String(conf.source || conf.album || '').replace(/^\s+|\s+$/g, '');
if (ALBUM && ALBUM.indexOf('/') < 0) ALBUM = 'https://photos.app.goo.gl/' + ALBUM;
else if (ALBUM && !/^https?:/.test(ALBUM)) ALBUM = 'https://' + ALBUM;

// Versiones anteriores bajaban las fotos a saver/img: si quedó esa carpeta, se borra
(function cleanOld() {
  var img = path.join(DIR, 'img');
  try { fs.readdirSync(img).forEach(function (n) { fs.unlinkSync(path.join(img, n)); }); fs.rmdirSync(img); } catch (e) {}
})();

function readJson(n) { try { return JSON.parse(fs.readFileSync(path.join(DIR, n), 'utf8')); } catch (e) { return null; } }
function writeJson(n, o) {
  fs.writeFileSync(path.join(DIR, n + '.tmp'), JSON.stringify(o));
  fs.renameSync(path.join(DIR, n + '.tmp'), path.join(DIR, n));
}

var guardado = readJson('album.json');
if (!FORZAR && guardado && guardado.album === ALBUM && guardado.photos && guardado.photos.length &&
    Date.now() - guardado.updated < RELEER) {
  armarLista(guardado.photos);   // solo el paso 2, sin internet
} else {
  leerAlbum();
}

// 2) La lista del protector: "max" fotos que no salieron en esta vuelta
function armarLista(todas) {
  var u = readJson('usadas.json');
  var usadas = {};
  if (u && u.album === ALBUM && u.ids) u.ids.forEach(function (id) { usadas[id] = 1; });
  var quedan = todas.filter(function (f) { return !usadas[f.id]; });
  var elegidas = sample(quedan, MAX);
  if (elegidas.length < MAX && todas.length > elegidas.length) {
    // se terminó la vuelta: se completa con fotos de la vuelta nueva
    usadas = {};
    var ya = {};
    elegidas.forEach(function (f) { ya[f.id] = 1; });
    elegidas = elegidas.concat(sample(todas.filter(function (f) { return !ya[f.id]; }), MAX - elegidas.length));
    log('álbum: terminó una vuelta completa, empieza otra');
  }
  elegidas.forEach(function (f) { usadas[f.id] = 1; });
  var ids = Object.keys(usadas);
  writeJson('usadas.json', { album: ALBUM, ids: ids });
  writeJson('index.json', {
    updated: Date.now(), album: ALBUM, total: todas.length, vuelta: { usadas: ids.length, total: todas.length },
    photos: elegidas.map(function (f) { return { url: f.url, w: f.w, h: f.h, ts: f.ts }; })
  });
  log('álbum: lista nueva de ' + elegidas.length + ' fotos; en esta vuelta salieron ' + ids.length + ' de ' + todas.length);
}

// 1) Leer el álbum entero
function leerAlbum() {
// Resolver el link corto: sin user-agent de navegador, Google responde 302 a la URL real del álbum
sh('curl -sI --max-time 20 ' + q(ALBUM), function (err, head) {
  var m = /^location:\s*(\S+)/im.exec(head);
  var shareUrl = m ? m[1] : ALBUM;
  // 2) Bajar la página del álbum y sacar las fotos de 'ds:1'
  sh('curl -sL --max-time 40 ' + q(shareUrl), function (err2, html) {
    var re = /AF_initDataCallback\(\{key: 'ds:1'[\s\S]*?data:(\[[\s\S]*?\]), sideChannel/;
    var m = re.exec(html), data = null;
    try { data = m ? JSON.parse(m[1]) : null; } catch (e) { data = null; }
    if (!data) { log('no encontré fotos (¿cambió el formato de Google?) — queda la lista anterior'); return; }
    var fotos = [], seen = {}, total = data[1] ? data[1].length : 0;
    parse(data, fotos, seen);
    // 3) Las tandas siguientes: [ id del álbum, código de la tanda, null, clave del enlace ]
    var albumId = data[3] && data[3][0];
    var km = /[?&]key=([^&#]+)/.exec(shareUrl);
    var pages = 1;
    (function next(tok) {
      if (!tok || !albumId || !km || pages >= MAX_PAGES) return done(!tok);
      var req = JSON.stringify([[['snAcKc', JSON.stringify([albumId, tok, null, km[1]]), null, 'generic']]]);
      sh('curl -s --max-time 40 -X POST -H ' + q('Content-Type: application/x-www-form-urlencoded;charset=UTF-8') +
         ' --data-urlencode ' + q('f.req=' + req) + ' https://photos.google.com/_/PhotosUi/data/batchexecute',
        function (err3, out) {
          var p = null;
          out.split('\n').forEach(function (l) {
            if (p || l.indexOf('"wrb.fr"') < 0) return;
            try { p = JSON.parse(JSON.parse(l)[0][2]); } catch (e) { p = null; }
          });
          if (!p) { log('álbum: falló la tanda ' + (pages + 1) + ', sigo con lo que hay'); return done(false); }
          pages++;
          total += p[1] ? p[1].length : 0;
          parse(p, fotos, seen);
          next(p[2]);
        });
    })(data[2]);

    function done(complete) {
      if (!fotos.length) { log('no encontré fotos (¿cambió el formato de Google?) — queda la lista anterior'); return; }
      log('álbum: ' + fotos.length + ' fotos de ' + total + ' elementos (sin videos, ' + pages + ' tandas' +
          (complete ? '' : ', INCOMPLETO') + ')');
      // si quedó incompleto y la copia anterior tenía más, se sigue usando la anterior (y se reintenta en 6 h)
      if (!complete && guardado && guardado.album === ALBUM && guardado.photos && guardado.photos.length > fotos.length) {
        guardado.updated = Date.now();
        writeJson('album.json', guardado);
        return armarLista(guardado.photos);
      }
      writeJson('album.json', { updated: Date.now(), album: ALBUM, photos: fotos });
      armarLista(fotos);
    }
  });
});
}

// Elige n al azar (sin repetir)
function sample(arr, n) {
  var a = arr.slice();
  for (var i = a.length - 1; i > 0; i--) { var j = Math.floor(Math.random() * (i + 1)), t = a[i]; a[i] = a[j]; a[j] = t; }
  return a.slice(0, n);
}

function parse(data, out, seen) {
  (function walk(x) {
    if (Object.prototype.toString.call(x) !== '[object Array]') return;
    // Patrón de una foto: [ "AF1Qip...", [ "https://lh3.googleusercontent.com/pw/...", ancho, alto, ... ], fechaMs, ... ]
    if (x.length >= 3 && typeof x[0] === 'string' && x[0].indexOf('AF1Qip') === 0 &&
        x[1] && typeof x[1][0] === 'string' && x[1][0].indexOf('googleusercontent') >= 0 && !seen[x[0]]) {
      seen[x[0]] = 1;
      if (!isVideo(x)) out.push({ id: x[0], url: x[1][0], w: x[1][1], h: x[1][2], ts: x[2] });
    }
    for (var i = 0; i < x.length; i++) walk(x[i]);
  })(data);
}

// Solo fotos: los videos traen un objeto con la clave '76647426' (duración en ms, resolución, URL del video).
// Las "fotos con movimiento" traen '146008172' y se dejan: se muestran como foto fija.
function isVideo(item) {
  for (var i = 3; i < item.length; i++) {
    var e = item[i];
    if (e && typeof e === 'object' && Object.prototype.toString.call(e) !== '[object Array]' && e['76647426']) return true;
  }
  return false;
}
