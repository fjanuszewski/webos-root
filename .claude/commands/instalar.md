---
description: Instala (o reinstala) en la tele la pantalla de inicio, el protector de fotos, el Wi-Fi que recuerda redes, el bloqueo de publicidad y la optimización de memoria, preguntando antes qué activar
---

Instalá todo lo del repositorio en la tele con `tools/reinstalar-todo.sh`. Antes:

1. Verificá que haya conexión de administrador (`./tvroot.sh 'id -u'` → `0`). Si no, seguí lo de `/conectar`.
2. **Preguntale qué quiere activar y qué no, antes de instalar.** Mostrale la lista con una frase simple de para qué sirve cada cosa, y que todo se puede cambiar después (pidiéndoselo a Claude):
   - **Álbum de fotos en el protector** y **calendario familiar** en la pantalla de inicio. Si los quiere y no existen `cleanhome/saver/config.json` y `cleanhome/cal/config.json`, creálos copiando los `config.example.json` y pedile los enlaces; si no los tiene, explicale cómo sacarlos (secciones "El calendario familiar" y "El álbum de fotos" de `GUIA-ROOT.md`). Si no los quiere, dejá el ejemplo: el protector y el panel quedan vacíos sin romper nada.
   - **Mandar cosas desde el celular** (AirPlay, compartir pantalla). Si no lo usa → `APAGAR_TRANSMISION=s` (ahorra ~100 MB).
   - **Auriculares o barra de sonido por Bluetooth.** Si no los usa → `APAGAR_AUDIO_BT=s`. El control remoto sigue andando igual.
   - **Wi-Fi que recuerda tus redes**: el panel de Configuración guarda las contraseñas de las redes a las que te conectás y, si se corta el wifi, la tele se reconecta sola (primero a la última red, después a las otras guardadas). Las claves quedan **solo en la tele**, en un archivo que solo lee el administrador; nunca se suben al repositorio. Si prefiere no dejar sus claves guardadas → `NO_GUARDAR_WIFI=s` (borra las que hubiera y apaga la reconexión automática; el panel de Wi-Fi sigue andando, pero pide la contraseña cada vez). Si sí → `NO_GUARDAR_WIFI=n`.
   - **Foto de fondo** para la pantalla de inicio (opcional): si quiere una, pedile la imagen (JPG o PNG), copiala a la carpeta `fondos/` del repo (no se publica) y el instalador la sube a la tele (`/var/lib/webosbrew/fondos/`, que se crea sola). Después se elige en la tele: engranaje → Configuración → **Tema** → Fondo → Foto. Más adelante se suben otras con `tools/subir-fondo.sh foto.jpg`.
   - Lo demás de la pantalla de inicio se cambia después desde la propia tele: **Configuración → Widgets** (qué widgets van, dónde y de qué tamaño), **Configuración → Tema** (fondo, colores, letra) y **Editar** en cada panel y en el protector.
3. Repasá con la persona lo que eligió y pedile el OK.
4. Con su OK, corré: `APAGAR_TRANSMISION=… APAGAR_AUDIO_BT=… NO_GUARDAR_WIFI=… tools/reinstalar-todo.sh`.
5. Al terminar, contale qué quedó instalado y proponele la prueba de corte de luz (desenchufar 10 s, prender, esperar 90 s) y después `/estado`.

$ARGUMENTS
