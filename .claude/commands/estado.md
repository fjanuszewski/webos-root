---
description: Revisa cómo está la tele (memoria, procesador, qué está corriendo y si todo arrancó bien) sin cambiar nada
---

Usá el agente `auditor-tele` para revisar la tele **sin cambiar nada**. Después contale a la persona el resultado en español simple:

- ¿Arrancó todo solo? (último renglón de `/var/lib/webosbrew/cytv-debloat.log`, montajes, vigilante de apps)
- Memoria libre y memoria de emergencia (swap), comparadas con lo esperado (ver `AUDITORIA.md`)
- Si hay apps abiertas que no está usando, o servicios que deberían estar apagados y volvieron
- Cualquier cosa rara, con lo que proponés hacer (y que no se hace sin su OK)

$ARGUMENTS
