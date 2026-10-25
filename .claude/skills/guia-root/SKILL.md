---
name: guia-root
description: Guiar a una persona (no técnica) para rootear una tele LG webOS con faultmanager-autoroot, dejar el acceso permanente sin modo desarrollador e instalar lo de este repo. Usala cuando alguien quiera rootear su tele LG, tenga dudas con Developer Mode, Dev Manager, Homebrew Channel, la cuenta de LG, la conexión con la tele o el celular de puente.
---

# Guiar el root de una tele LG

Fuente de verdad: `GUIA-ROOT.md` (lo que ve la persona) y `CLAUDE.md` (lo que hacés vos, con comandos exactos). Leelos antes de empezar.

## Cómo guiar
- Español simple, sin jerga en inglés. Frases cortas. De a un paso.
- Decí **qué tiene que hacer ella** ("en la tele, abrí la app Developer Mode y prendé Key Server") y **qué hiciste vos** en una línea.
- Esperá su confirmación antes de seguir. Pedí OK antes de cada cambio en la tele.
- Si se traba, no la apures: preguntale qué ve en pantalla.

## Orden (no cambiarlo)
0. Compu lista: Claude Code abierto en la carpeta del repo.
1. Cuenta de LG = cuenta de desarrollador. Entrar a webostv.developer.lge.com con el mismo usuario y **aceptar los términos**.
2. App **Developer Mode** en la tele: "Dev Mode Status" ON (reinicia) y después "Key Server" ON. Pedile IP y passphrase.
3. Red: probá si la compu ve la tele (`nc -z -w 3 IP 9922`). Si no, celular de puente (`/conectar`).
4. **Dev Manager**: dale la tabla de datos de `CLAUDE.md` (host, puerto 9922, usuario `prisoner`, passphrase).
5. Root: el comando de faultmanager-autoroot en la terminal de Dev Manager. Verificar Homebrew Channel → root activo.
6. **Llave** `~/.ssh/tv_webos_dec` desde el Key Server (puerto 9991) + passphrase, **mientras el modo desarrollador siga activo**.
7. Homebrew → **SSH Server** ON → `tools/reinstalar-todo.sh` → verificar root por SSH 2222 sin modo desarrollador.
8. Recién ahí, con OK: desinstalar la app Developer Mode (por qué: `PERSISTENCIA.md`).
9. Prueba de corte de luz y `/estado`.
10. Ofrecer `/sumar-mi-tele`.

## Si algo sale mal
- No conecta: `/conectar`.
- Dev Manager no entra: Key Server apagado, passphrase vieja (cambia al reactivar el modo desarrollador) o IP cambiada.
- El autoroot falla: anotá el mensaje exacto. Revisá la versión de webOS (Configuración → Soporte). Puede que ese firmware no sea compatible: no inventes alternativas sin buscar en el repo de faultmanager-autoroot y en webosbrew.org.
- Después del root, si el menú de entradas no aparece o algo de LG deja de andar: revisá la lección de `iepg` en `CLAUDE.md` antes de apagar más servicios.
