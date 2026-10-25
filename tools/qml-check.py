#!/usr/bin/env python3
"""qml-check.py — validación rápida de los QML/JS antes de subirlos a la TV (no hay qmllint para Qt 5.6).

Detecta lo que ya nos rompió el Home:
  - propiedad asignada dos veces en el mismo objeto ("Property value set multiple times" => MainView no compila)
  - llaves / paréntesis / corchetes desbalanceados
  - sintaxis de componente inline `component X:` (no existe en Qt 5.6)
  - propiedades propias que pisan las de Item (`property var data`, etc.)
Uso: tools/qml-check.py archivo.qml [...]   (sale con código 1 si hay problemas)
"""
import re
import sys

problems = 0
for path in sys.argv[1:]:
    text = open(path, encoding='utf-8').read()
    # Deja solo el código: saca textos entre comillas y comentarios // y /* */, recorriendo carácter por carácter.
    out, i, n, quote, block = [], 0, len(text), None, False
    while i < n:
        c = text[i]
        if block:
            if text.startswith('*/', i): block = False; i += 2; continue
            if c == '\n': out.append(c)
            i += 1; continue
        if quote:
            if c == '\\': i += 2; continue
            if c == quote or c == '\n': quote = None
            if c == '\n': out.append(c)
            i += 1; continue
        if c in '"\'`': quote = c; out.append('""'); i += 1; continue
        if text.startswith('//', i):
            j = text.find('\n', i); i = n if j < 0 else j; continue
        if text.startswith('/*', i): block = True; i += 2; continue
        out.append(c); i += 1
    clean = ''.join(out)
    for a, b in ('{}', '()', '[]'):
        d = clean.count(a) - clean.count(b)
        if d:
            print(f'{path}: "{a}{b}" desbalanceado ({d:+d})'); problems += 1
    if path.endswith('.qml'):
        if re.search(r'^\s*component\s+\w+\s*:', clean, re.M):
            print(f'{path}: usa "component X:" (no soportado en Qt 5.6)'); problems += 1
        # Propiedades propias con nombres que ya usa Item: rompen el objeto entero (ej. "data" es donde van los hijos)
        for m in re.finditer(r'^\s*(?:readonly\s+)?property\s+\w+\s+(data|children|resources|parent|visibleChildren|anchors|states|transitions)\b', clean, re.M):
            print(f'{path}: "property ... {m.group(1)}" choca con una propiedad de Item'); problems += 1
        # propiedades repetidas dentro del mismo objeto
        stack = []
        for n, line in enumerate(clean.split('\n'), 1):
            m = re.match(r'^\s*([a-zA-Z][\w.]*)\s*:(?!:)', line)
            if m and stack and not line.strip().startswith(('case ', 'default')):
                name, seen = m.group(1), stack[-1]
                if not name.startswith('on') and name in seen:
                    print(f'{path}:{n}: "{name}" ya asignada en la línea {seen[name]} del mismo objeto'); problems += 1
                seen[name] = n
            for ch in line:
                if ch == '{':
                    stack.append({})
                elif ch == '}' and stack:
                    stack.pop()

if problems:
    print(f'qml-check: {problems} problema(s). No se despliega.')
    sys.exit(1)
print(f'qml-check: OK ({len(sys.argv) - 1} archivos)')
