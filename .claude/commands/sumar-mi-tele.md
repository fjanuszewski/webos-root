---
description: Arma la fila de tu tele para la tabla de teles compatibles y te ayuda a mandarla (issue o pull request)
---

Ayudá a la persona a sumar su tele a la tabla "Teles compatibles" del `README.md` (ver `CONTRIBUTING.md`).

1. Si hay conexión, sacá los datos de la tele **solo leyendo** (`./tvroot.sh`): modelo, versión de webOS y firmware (por ejemplo `cat /var/run/nyx/os_info.json`, `nyx-cmd OSInfo query`, o `luna://com.webos.service.tv.systemproperty/getSystemInfo`). Si no hay conexión, preguntáselos y decile dónde verlos (Configuración → Soporte → Información de la TV).
2. Preguntale qué anduvo: root, pantalla de inicio, protector, optimización (✅ anda · ⚠️ con cambios · ❌ no anda · ➖ no probado), y si tuvo que cambiar algo.
3. Armá la fila con el formato de la tabla y mostrásela.
4. **Revisá que no haya datos personales** (IP, número de serie, enlaces del álbum o calendario). Podés usar el agente `revisor-privacidad`.
5. Ofrecele dos caminos y hacé el que elija, **con su OK antes de publicar nada**:
   - abrir un issue en `fjanuszewski/webos-root` con `gh issue create` (título `Tele: <modelo>`);
   - o un fork + pull request agregando la fila al README.

$ARGUMENTS
