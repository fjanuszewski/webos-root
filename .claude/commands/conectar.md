---
description: Revisa y arregla la conexión entre la compu y la tele (directa o con el celular de puente)
---

Diagnosticá la conexión con la tele, en este orden, contándole a la persona en palabras simples qué encontrás:

1. **¿Ya tiene acceso de administrador?** Probá `./tvroot.sh 'echo ok; id -u'`. Si responde `ok` y `0`, la conexión anda: avisale y terminá.
2. **¿Usa el celular de puente?** Si existe `config.local.sh`:
   - `adb devices`: ¿aparece el celular? Si no, que lo conecte por USB, desbloquee la pantalla y toque "Permitir" en el cartel de depuración USB.
   - `./restore-chain.sh`: levanta los relays y los `adb forward`.
3. **¿Conexión directa?** Pedile la IP de la tele (la muestra la app Developer Mode, o Configuración → Red) y probá `nc -z -w 3 IP 22` y `nc -z -w 3 IP 9922`.
   - Si no responde ninguno: el router probablemente aísla los aparatos. Explicale las opciones de la sección "Conexión" de `GUIA-ROOT.md` (celular de puente, apagar el aislamiento en el router, cable de red).
4. **¿Todavía no rooteó?** La conexión es la de Dev Manager (puerto 9922, usuario `prisoner`): revisá que el "Key Server" esté prendido en la app Developer Mode.

No cambies nada en la tele sin OK.

$ARGUMENTS
