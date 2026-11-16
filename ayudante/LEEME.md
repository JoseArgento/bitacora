# Ayudante de capturas de Bitácora

*(English below.)*

El juego no deja que ningún addon **cree carpetas**, **lea el portapapeles** ni **vea qué archivos hay**. Por eso, para poner una imagen en una nota de Bitácora había que crear la carpeta a mano, copiar el archivo y escribir su nombre sin equivocarse. Este ayudante hace esas tres cosas desde afuera del juego:

| | |
|---|---|
| **Instalar.bat** | Lo abrís una vez. Busca el juego, crea `Interface\AddOns\BitacoraImagenes` con su lista, convierte las imágenes que ya tuvieras ahí y deja en el Escritorio el atajo **Pegar captura en Bitácora** con **Ctrl+Alt+V**. |
| **Ctrl+Alt+V** (o `Pegar captura.bat`) | Guarda la imagen que copiaste: un recorte de pantalla (**Win+Shift+S**), una imagen copiada de una página, o un archivo de imagen copiado en el Explorador. Si no hay ninguna imagen copiada, trae tu última captura del juego. |
| **Traer capturas del juego.bat** | Copia tus últimas 10 capturas (`Screenshots\WoWScrnShot_*.jpg`) adonde Bitácora puede mostrarlas: aparecen en el Álbum, con la foto, y en la lista de imágenes de las notas. Para traer más: `"Traer capturas del juego.bat" -Cuantas 30`. |

Después, **en el juego**: en una nota, *Agregar imagen* → *Recargar* (un `/reload`) → la elegís de la lista, con su miniatura. Sin escribir nombres.

## Cómo se usa, paso a paso

1. Bajá esta carpeta (`ayudante`) a donde quieras: [descargar el repositorio como zip](https://github.com/JoseArgento/bitacora/archive/refs/heads/main.zip) y sacá de ahí la carpeta `ayudante`.
2. Doble clic en **Instalar.bat**. Si no encuentra el juego solo, te pide que elijas la carpeta `_forever_`.
3. Si el juego estaba abierto, cerralo y abrilo una vez (para que vea la carpeta nueva). Es la única vez.
4. Jugando: **Win+Shift+S**, recortás lo que querés, **Ctrl+Alt+V**. Un globo te avisa que se guardó.
5. En Bitácora: *Agregar imagen* → *Recargar* → elegís la captura.

Si movés la carpeta `ayudante` a otro lado, abrí **Instalar.bat** otra vez para que el atajo apunte al lugar nuevo.

## Qué hace y qué no (para quien quiera revisarlo)

Son un script de PowerShell (`Capturas.ps1`) y tres `.bat` de una línea que lo llaman. Es texto: abrilos con el Bloc de notas.

- **No usa la red.** No baja ni manda nada.
- **No pide permisos de administrador.**
- **Escribe solo en tres lugares:** la carpeta `Interface\AddOns\BitacoraImagenes` del juego; `%APPDATA%\BitacoraCapturas\juego.txt` (dónde está el juego); y, al instalar, el atajo del Escritorio.
- **Lee** el portapapeles solo cuando apretás Ctrl+Alt+V (no se queda corriendo ni mirando), y tu carpeta `Screenshots` cuando le pedís traer capturas.
- **No borra nada tuyo.** Las imágenes que ya estaban en la carpeta quedan; al lado aparece su versión `.tga`.
- Los `.bat` lo llaman con `-ExecutionPolicy Bypass` (solo para ese archivo, esa vez) porque Windows, de fábrica, no deja correr scripts de PowerShell con doble clic.

Las pruebas (`tests/test_ayudante.py`) lo corren de verdad en Windows, con Windows PowerShell 5.1 y PowerShell 7, en cada cambio (GitHub Actions).

### Por qué TGA, por qué "huecos"

- Cada imagen se guarda como **TGA con lados potencia de dos** (hasta 1024×512): es el formato que el juego carga seguro. La imagen se aprieta para entrar en ese cuadro y su forma verdadera se anota en la lista; Bitácora la muestra con esa forma.
- El juego solo conoce los archivos que existían **cuando arrancó**. Un archivo nuevo no lo ve hasta reiniciar, pero uno que ya existía y cambió, sí (con `/reload`). Por eso la carpeta tiene 24 **huecos** (`captura_001.tga`, …): archivos mínimos que una captura pisa. Cuando el juego está cerrado, el ayudante repone los huecos usados. ⏳ Esto está pensado así por cómo se comportan los clientes modernos; en Forever todavía no lo vi con mis ojos: si una captura recién pegada no aparece después de *Recargar*, reiniciá el juego y contame.
- La lista es `Indice.lua`, un addon mínimo (solo datos). Bitácora la revisa entrada por entrada antes de usarla.

## Si algo no anda

- **"No encontré la carpeta _forever_"**: abrí `Instalar.bat` y elegila a mano (está adentro de `World of Warcraft`).
- **Ctrl+Alt+V no hace nada**: los atajos de Windows solo funcionan si el acceso directo sigue en el Escritorio. Probá `Pegar captura.bat`.
- **La captura no aparece en la lista**: tocá *Recargar* en la tarjeta de imágenes. Si igual no aparece, reiniciá el juego una vez.
- **La imagen se ve como un cuadrado verde**: el juego no encontró el archivo. Suele ser una nota vieja con el nombre mal escrito: sacala de la nota y elegila de la lista.

---

# Bitácora capture helper

The game does not let any addon **create folders**, **read the clipboard** or **see which files exist**. This helper does those three things from outside the game:

- **Instalar.bat** (run once): finds the game, creates `Interface\AddOns\BitacoraImagenes` with its list, converts the pictures already there and puts a shortcut on your Desktop with **Ctrl+Alt+V**.
- **Ctrl+Alt+V** (or `Pegar captura.bat`): saves the picture you copied (a snip with **Win+Shift+S**, a picture copied from a page, or an image file copied in Explorer). With no picture in the clipboard, it brings your last game screenshot.
- **Traer capturas del juego.bat**: copies your last 10 game screenshots where Bitácora can show them (the Album gets the photos, and they appear in the notes' picture list). More: `-Cuantas 30`.

Then, in the game: in a note, *Add image* → *Reload* → pick it from the list.

It is a PowerShell script and three one-line `.bat` files: plain text you can read. No network, no administrator rights, nothing deleted; it writes only to the game's `BitacoraImagenes` folder, to `%APPDATA%\BitacoraCapturas\juego.txt` and, on install, the Desktop shortcut. It reads the clipboard only when you press Ctrl+Alt+V. Pictures are saved as power-of-two TGA textures (what the game is sure to load); their real shape goes in the list and Bitácora shows them with it. The tests run it for real on Windows (PowerShell 5.1 and 7) on every change.
