// cal/sync.js — baja el calendario PÚBLICO de Google (formato iCal) y deja los eventos de las próximas
// semanas en cal/events.json, que lee el Home (CleanCalendar.qml).
// Corre como root en la TV con su Node 0.12 (sintaxis ES5 a propósito), al prender y cada 10 min.
//
// Config: cal/config.json -> { "ics": "https://calendar.google.com/calendar/ical/<id>/public/basic.ics" }
// Salida:  cal/events.json -> { updated, name, from, to, events: [ { start, end, allDay, day, title, location, description } ] }
//   start/end en ms (epoch); day = "YYYY-MM-DD" local; los de todo el día se repiten en cada día que abarcan.
//
// Soporta: eventos simples, todo el día, multi-día, recurrentes (RRULE: DAILY/WEEKLY/MONTHLY/YEARLY con
// INTERVAL, COUNT, UNTIL, BYDAY —incluye "2MO", "-1FR"—, BYMONTHDAY), EXDATE, excepciones (RECURRENCE-ID)
// y cancelados. Zonas horarias: UTC ("Z"), Argentina (UTC-3, sin horario de verano) y "flotante" = hora local.
var cp = require('child_process');
var fs = require('fs');
var path = require('path');

var DIR = __dirname;
var LOG = '/tmp/cleanhome-cal.log';
var DAY = 86400000;
var LOCAL_OFF = -new Date().getTimezoneOffset() * 60000;   // TV en -03:00 -> -10800000

function log(m) { try { fs.appendFileSync(LOG, new Date().toISOString() + ' ' + m + '\n'); } catch (e) {} }
function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

// Modo demostración (tools/modo-demo.sh): no se pisa el archivo de mentira
if (fs.existsSync(path.join(DIR, '..', 'DEMO'))) { log('modo demo: no actualizo'); process.exit(0); }
var conf;
try { conf = JSON.parse(fs.readFileSync(path.join(DIR, 'config.json'), 'utf8')); }
catch (e) { log('sin config.json'); process.exit(1); }

// El usuario puede pegar el enlace del calendario ("...calendar/u/0?cid=BASE64"), su ID ("xxx@group.calendar.google.com")
// o el enlace iCal directo: se normaliza a la URL pública .ics. (La pantalla de edición guarda {"source": "..."}.)
function toIcs(src) {
  src = String(src || '').replace(/^\s+|\s+$/g, '');
  if (/\.ics(\?|$)/.test(src) || src.indexOf('/ical/') >= 0) return src;
  var m = /[?&]cid=([^&#]+)/.exec(src);
  var id = src;
  if (m) {
    id = decodeURIComponent(m[1]);
    if (id.indexOf('@') < 0) { try { id = new Buffer(id, 'base64').toString('utf8'); } catch (e) {} }
  } else if ((m = /[?&]src=([^&#]+)/.exec(src))) {
    id = decodeURIComponent(m[1]);
  }
  return 'https://calendar.google.com/calendar/ical/' + encodeURIComponent(id) + '/public/basic.ics';
}
var ICS = toIcs(conf.source || conf.ics);
cp.exec('curl -sL --max-time 40 ' + q(ICS), { timeout: 60000, maxBuffer: 16 * 1024 * 1024 }, function (err, out) {
  var text = String(out || '');
  if (err || text.indexOf('BEGIN:VCALENDAR') < 0) { log('no pude bajar el calendario — queda el anterior'); return; }
  try { build(text); } catch (e) { log('error armando eventos: ' + e); }
});

// ---------- iCal ----------
function unfold(text) { return text.replace(/\r\n/g, '\n').replace(/\n[ \t]/g, ''); }
function unescape(v) { return v.replace(/\\n/gi, '\n').replace(/\\,/g, ',').replace(/\\;/g, ';').replace(/\\\\/g, '\\'); }
function cleanText(v) {
  return unescape(v).replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]+>/g, '').replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
    .replace(/\n{3,}/g, '\n\n').replace(/^\s+|\s+$/g, '');
}

function parse(text) {
  var lines = unfold(text).split('\n'), out = [], cur = null, cal = {};
  for (var i = 0; i < lines.length; i++) {
    var ln = lines[i];
    if (ln === 'BEGIN:VEVENT') { cur = { exdates: [] }; continue; }
    if (ln === 'END:VEVENT') { if (cur) out.push(cur); cur = null; continue; }
    var c = ln.indexOf(':'); if (c < 0) continue;
    var left = ln.slice(0, c), val = ln.slice(c + 1);
    var parts = left.split(';'), name = parts[0].toUpperCase(), params = {};
    for (var k = 1; k < parts.length; k++) { var e = parts[k].split('='); params[e[0].toUpperCase()] = e[1]; }
    if (!cur) { if (name === 'X-WR-CALNAME') cal.name = unescape(val); if (name === 'X-WR-TIMEZONE') cal.tz = val; continue; }
    if (name === 'DTSTART') cur.start = parseDate(val, params, cal.tz);
    else if (name === 'DTEND') cur.end = parseDate(val, params, cal.tz);
    else if (name === 'DURATION') cur.duration = parseDuration(val);
    else if (name === 'SUMMARY') cur.title = cleanText(val);
    else if (name === 'LOCATION') cur.location = cleanText(val);
    else if (name === 'DESCRIPTION') cur.description = cleanText(val);
    else if (name === 'STATUS') cur.status = val.toUpperCase();
    else if (name === 'UID') cur.uid = val;
    else if (name === 'RRULE') cur.rrule = parseRule(val);
    else if (name === 'RECURRENCE-ID') cur.recurId = parseDate(val, params, cal.tz);
    else if (name === 'EXDATE') { var xs = val.split(','); for (var x = 0; x < xs.length; x++) cur.exdates.push(parseDate(xs[x], params, cal.tz).t); }
  }
  return { cal: cal, events: out };
}

// Fecha iCal -> { t: epoch ms, allDay, wall: ms "de pared" (para repetir sin correrse de hora), off }
function tzOffset(tzid) {
  if (!tzid) return LOCAL_OFF;
  if (/Argentina|Montevideo|Sao_Paulo|Santiago/.test(tzid)) return -3 * 3600000;
  if (/^(UTC|GMT|Etc\/UTC)$/.test(tzid)) return 0;
  return LOCAL_OFF;   // otras zonas: se aproxima con la de la TV
}
function parseDate(v, params, calTz) {
  var m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/.exec(v.replace(/^\s+|\s+$/g, ''));
  if (!m) return { t: NaN, allDay: false, wall: NaN, off: 0 };
  var wall = Date.UTC(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0));
  var allDay = (params && params.VALUE === 'DATE') || !m[4];
  var off = allDay ? LOCAL_OFF : (m[7] ? 0 : tzOffset(params && params.TZID || calTz));
  // Hora UTC ("Z"): se pasa a hora de pared local para repetir bien las recurrencias
  if (m[7]) { off = LOCAL_OFF; wall = wall + LOCAL_OFF; }
  return { t: wall - off, allDay: allDay, wall: wall, off: off };
}
function parseDuration(v) {
  var m = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(v);
  if (!m) return 0;
  return ((+m[2] || 0) * 7 * DAY + (+m[3] || 0) * DAY + (+m[4] || 0) * 3600000 + (+m[5] || 0) * 60000 + (+m[6] || 0) * 1000) * (m[1] === '-' ? -1 : 1);
}
function parseRule(v) {
  var r = {}, ps = v.split(';');
  for (var i = 0; i < ps.length; i++) { var e = ps[i].split('='); r[e[0].toUpperCase()] = e[1]; }
  return r;
}

// ---------- Recurrencias (en "hora de pared": Date UTC usado como calendario sin zona) ----------
var WD = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 };
function addMonths(d, n) { return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + n, 1, d.getUTCHours(), d.getUTCMinutes(), d.getUTCSeconds())); }
function nthWeekday(year, month, wd, n, h, mi, s) {   // n>0: n-ésimo; n<0: desde el final
  if (n > 0) {
    var first = new Date(Date.UTC(year, month, 1)).getUTCDay();
    var day = 1 + ((wd - first + 7) % 7) + (n - 1) * 7;
    var d = new Date(Date.UTC(year, month, day, h, mi, s));
    return d.getUTCMonth() === month ? d : null;
  }
  var lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  var lastWd = new Date(Date.UTC(year, month, lastDay)).getUTCDay();
  var dd = lastDay - ((lastWd - wd + 7) % 7) + (n + 1) * 7;
  return dd >= 1 ? new Date(Date.UTC(year, month, dd, h, mi, s)) : null;
}

// Devuelve los inicios (hora de pared) de las repeticiones entre [fromWall, toWall)
function expand(ev, fromWall, toWall) {
  var r = ev.rrule, start = new Date(ev.start.wall), out = [];
  if (!r) { out.push(ev.start.wall); return out; }
  var freq = r.FREQ, interval = +(r.INTERVAL || 1), count = r.COUNT ? +r.COUNT : 0;
  var until = r.UNTIL ? parseDate(r.UNTIL, {}, null) : null;
  var untilWall = until ? (until.allDay ? until.wall + DAY - 1 : until.t + LOCAL_OFF) : Infinity;
  var byday = r.BYDAY ? r.BYDAY.split(',') : null;
  var bymd = r.BYMONTHDAY ? r.BYMONTHDAY.split(',').map(Number) : null;
  var h = start.getUTCHours(), mi = start.getUTCMinutes(), s = start.getUTCSeconds();
  var n = 0, guard = 0;

  function emit(w) {
    if (w < ev.start.wall) return true;
    if (w > untilWall) return false;
    n++;
    if (count && n > count) return false;
    if (w >= fromWall && w < toWall) out.push(w);
    return !(w >= toWall && !count);
  }

  if (freq === 'DAILY') {
    for (var w = ev.start.wall; guard++ < 20000; w += interval * DAY) {
      if (byday) { var wdd = new Date(w).getUTCDay(), okd = false; for (var b = 0; b < byday.length; b++) if (WD[byday[b].slice(-2)] === wdd) okd = true; if (!okd) continue; }
      if (!emit(w)) break;
    }
  } else if (freq === 'WEEKLY') {
    var days = byday ? byday.map(function (x) { return WD[x.slice(-2)]; }).sort() : [start.getUTCDay()];
    // semana que arranca el lunes (WKST=MO por defecto en Google)
    var wk0 = ev.start.wall - ((start.getUTCDay() + 6) % 7) * DAY - (h * 3600000 + mi * 60000 + s * 1000);
    for (var wk = wk0; guard++ < 5000; wk += interval * 7 * DAY) {
      var stop = false;
      for (var j = 0; j < days.length; j++) {
        var wd = (days[j] + 6) % 7;
        if (!emit(wk + wd * DAY + h * 3600000 + mi * 60000 + s * 1000)) { stop = true; break; }
      }
      if (stop || wk > toWall + 7 * DAY && !count) break;
    }
  } else if (freq === 'MONTHLY' || freq === 'YEARLY') {
    var step = freq === 'MONTHLY' ? interval : 12 * interval;
    for (var mo = addMonths(start, 0); guard++ < 3000; mo = addMonths(mo, step)) {
      var y = mo.getUTCFullYear(), m = mo.getUTCMonth(), cands = [];
      if (freq === 'YEARLY' && r.BYMONTH) m = +r.BYMONTH - 1;
      if (byday) {
        for (var k = 0; k < byday.length; k++) {
          var mm = /^([+-]?\d+)?(\w\w)$/.exec(byday[k]);
          if (mm && mm[1]) { var dn = nthWeekday(y, m, WD[mm[2]], +mm[1], h, mi, s); if (dn) cands.push(dn.getTime()); }
          else if (mm) { for (var dd = 1; dd <= 31; dd++) { var dx = new Date(Date.UTC(y, m, dd, h, mi, s)); if (dx.getUTCMonth() === m && dx.getUTCDay() === WD[mm[2]]) cands.push(dx.getTime()); } }
        }
      } else {
        var mds = bymd || [start.getUTCDate()];
        for (var z = 0; z < mds.length; z++) {
          var md = mds[z] < 0 ? new Date(Date.UTC(y, m + 1, 0)).getUTCDate() + mds[z] + 1 : mds[z];
          var dm = new Date(Date.UTC(y, m, md, h, mi, s));
          if (dm.getUTCMonth() === m) cands.push(dm.getTime());   // 31 en meses de 30: se saltea (como Google)
        }
      }
      cands.sort(function (a, b2) { return a - b2; });
      var stop2 = false;
      for (var c = 0; c < cands.length; c++) if (!emit(cands[c])) { stop2 = true; break; }
      if (stop2 || (Date.UTC(y, m, 1) > toWall && !count)) break;
    }
  }
  return out;
}

// ---------- Armado ----------
function ymd(t) {   // t en ms epoch -> día local
  var d = new Date(t + LOCAL_OFF);
  return d.getUTCFullYear() + '-' + ('0' + (d.getUTCMonth() + 1)).slice(-2) + '-' + ('0' + d.getUTCDate()).slice(-2);
}
function build(text) {
  var p = parse(text), now = Date.now();
  // Desde el lunes de esta semana hasta 4 semanas después
  var todayWall = Math.floor((now + LOCAL_OFF) / DAY) * DAY;
  var monWall = todayWall - ((new Date(todayWall).getUTCDay() + 6) % 7) * DAY;
  var fromWall = monWall - DAY, toWall = monWall + 28 * DAY;

  var overrides = {}, list = [];
  p.events.forEach(function (ev) { if (ev.recurId && ev.uid) overrides[ev.uid + '|' + ev.recurId.t] = ev; });

  p.events.forEach(function (ev) {
    if (!ev.start || isNaN(ev.start.t)) return;
    var dur = ev.end && !isNaN(ev.end.t) ? ev.end.t - ev.start.t : (ev.duration || (ev.start.allDay ? DAY : 0));
    if (ev.recurId) {   // excepción de una serie: se agrega tal cual (si no está cancelada)
      if (ev.status !== 'CANCELLED') push(ev, ev.start.t, dur);
      return;
    }
    if (ev.status === 'CANCELLED') return;
    var starts = expand(ev, fromWall - 40 * DAY, toWall);
    for (var i = 0; i < starts.length; i++) {
      var t = starts[i] - ev.start.off;
      if (ev.exdates.indexOf(t) >= 0) continue;
      if (ev.uid && overrides[ev.uid + '|' + t]) continue;   // la reemplaza la excepción
      push(ev, t, dur);
    }
  });

  function push(ev, t, dur) {
    var end = t + Math.max(dur, 0);
    if (end <= fromWall - LOCAL_OFF || t >= toWall - LOCAL_OFF) return;
    var base = { start: t, end: end, allDay: ev.start.allDay, title: ev.title || '(sin título)',
                 location: ev.location || '', description: (ev.description || '').slice(0, 400) };
    // Un renglón por cada día que toca (para la vista de semana)
    var d0 = ymd(t), last = ymd(Math.max(t, end - 1));
    for (var k = 0, day = d0; k < 40; k++) {
      var copy = {}; for (var x in base) copy[x] = base[x];
      copy.day = day; copy.first = day === d0;
      list.push(copy);
      if (day === last) break;
      var dd = day.split('-');
      day = ymd(Date.UTC(+dd[0], +dd[1] - 1, +dd[2]) - LOCAL_OFF + DAY + 3600000);
    }
  }

  list.sort(function (a, b) {
    if (a.day !== b.day) return a.day < b.day ? -1 : 1;
    if (a.allDay !== b.allDay) return a.allDay ? -1 : 1;
    return a.start - b.start;
  });
  var outObj = { updated: now, name: p.cal.name || 'Calendario', from: ymd(monWall - LOCAL_OFF), to: ymd(toWall - LOCAL_OFF - 1), events: list };
  fs.writeFileSync(path.join(DIR, 'events.json.tmp'), JSON.stringify(outObj));
  fs.renameSync(path.join(DIR, 'events.json.tmp'), path.join(DIR, 'events.json'));
  log('calendario "' + outObj.name + '": ' + list.length + ' eventos entre ' + outObj.from + ' y ' + outObj.to);
}
