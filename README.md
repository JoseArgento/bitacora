# Bitácora

El diario de a bordo de tus personajes de **WoW Forever**: una libreta, un diario que se escribe solo, un álbum de capturas y recordatorios, en una sola ventana. Tiene además una página web para leer todo eso fuera del juego.

[Read in English](README.en.md)

## Qué hace

- **Libreta**
  - Notas con pestañas propias ("General", "Onyxia", lo que quieras) y búsqueda.
  - Una nota puede ser de todos tus personajes o de uno solo.
  - Shift-click en un ítem, una misión o un logro lo linkea en la nota.
  - **Notas pegadas a cosas:** pegás una nota a un PNJ (tu objetivo), a un ítem linkeado o a la zona. Aparece en el tooltip del PNJ o del ítem, y te avisa en el chat cuando entrás a esa zona.
  - **Imágenes:** hasta 4 por nota (ver más abajo).
- **Diario**
  - Se escribe solo: el día que empezó, cada nivel, la primera vez en cada zona, jefes (marca la primera vez), muertes, misiones, botín de la calidad que elijas (épico por defecto), logros, oro (1, 10, 100, 1000) y tiempo jugado.
  - Podés escribir tus propias entradas.
  - Filtro de "hitos" para leerlo como una historia.
- **Álbum**
  - Cada vez que sacás una captura (Impr Pant) anota cuándo, dónde, en qué nivel y con quién estabas.
  - Le podés poner un epígrafe.
  - La página web junta esas anotaciones con las fotos.
- **Recordatorios**
  - "Cuando entre a Forjaz, vender el paño", "al llegar a 40, la montura", "al abrir el correo", "al entrar al juego", "los martes a las 20:30".
  - Pueden ser de un solo personaje o repetirse.
  - Avisan en el centro de la pantalla, con sonido.

Se abre con `/bitacora` (o `/bita`), con una tecla (Opciones → Atajos → Bitácora) o desde el botón de addons junto al minimapa.

- `/bita nota <texto>` guarda una nota rápida.
- `/bita entrada <texto>` escribe en el diario.

## Instalar

1. Copiá la carpeta `Bitacora` a `Interface\AddOns\`, dentro de la carpeta de Forever del juego.
2. Si vas a usar imágenes, creá también `Interface\AddOns\BitacoraImagenes\`. Está afuera de la carpeta del addon para que una actualización no te borre las imágenes.

## Imágenes en la libreta

El juego no puede abrir archivos de cualquier lado: solo carga imágenes de la carpeta de addons. Por eso:
- **Formato:** PNG, JPG, TGA o BLP.
- **Medidas:** lados potencia de 2 (64, 128, 256, 512…).
- **Sin reiniciar:** un archivo nuevo aparece con `/reload` (desde 9.0.1, según [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API:TextureBase_SetTexture)).
- **El nombre lo escribís vos:** el addon no puede listar la carpeta. Solo acepta un nombre simple (`mapa.png`), así una nota no puede apuntar a otra parte.

La pestaña **Imágenes** de la página web lleva cualquier imagen a potencia de 2, con márgenes transparentes si no es cuadrada, y te dice qué nombre escribir.

## La página web

`dist/bitacora.html` (se arma con `python tools/build_web.py`) es un solo archivo que funciona sin internet. Le das el archivo que el juego guarda al salir, `WTF\Account\<TU_CUENTA>\SavedVariables\Bitacora.lua`, y muestra:
- el diario como un libro de a bordo, día por día;
- el álbum con tus capturas: las soltás y se emparejan por la hora del nombre del archivo (`WoWScrnShot_MMDDYY_HHMMSS.jpg`);
- la libreta y los recordatorios, con "Copiar como Markdown";
- la herramienta de imágenes.

Nada sale de tu compu.

## Privacidad

El addon no manda nada a nadie: no usa mensajes de addon ni chat, solo escribe en tu propia ventana. Lo único que guarda está en tu `SavedVariables`. Los nombres de tu grupo en el álbum son los que el juego muestra; si el juego los oculta (valores "secretos" de Forever), no se anotan.

## Cómo se probó

**Probado:**
- ✅ **Cada función, evento y template existe en Forever 1.60.1.** Lo revisa `tools/check_api.py` contra los dumps de [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources) y el código de la UI de [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), rama `forever`. Ejemplos: `ChatFrameUtil.InsertLink` (Forever no tiene `ChatEdit_InsertLink`), `RaidWarningUtil.AddMessage` (`RaidNotice_AddMessage` solo existe con los alias viejos), `TooltipDataProcessor`, `ScrollingEditBoxTemplate`, el compartimento de addons de Forever. El script encuentra nombres inventados o mal escritos.
- ✅ [forever-lint](https://github.com/JoseArgento/forever-lint) no encuentra problemas. [Addon Sentry](https://github.com/JoseArgento/addon-sentry) da "Sin señales de riesgo".
- ✅ **57 tests.**
  - 49 corren el addon en Lua 5.1 (el Lua de WoW), con un reemplazo chico del cliente (`tests/wow_mock.lua`): eventos, datos guardados y recargados, recordatorios (incluido el semanal), tooltips, links con shift-click, nombres de imágenes, patrones de botín en varios idiomas, valores secretos, y cada pestaña armándose sin errores de Lua.
  - El resto prueban la página: lee el archivo igual que Lua 5.1, empareja capturas y arma los textos.
- ✅ La página probada en Chromium: cada pestaña, capturas y PNG reales, escritorio y celular, claro y oscuro.

**Sin probar ⏳.** Todo esto se prueba dentro del juego, y yo no tengo Forever:
- **La ventana:** que se vea bien (tamaños, anclas, pestañas, listas, menús, ventanas de texto).
- **Las imágenes:** que el juego cargue PNG desde `BitacoraImagenes`, una carpeta sin `.toc`.
- **Los nombres de archivo:** que las capturas de Forever se llamen `WoWScrnShot_MMDDYY_HHMMSS`.
- **Los eventos:** que `ENCOUNTER_END` o `BOSS_KILL` salten en las mazmorras de Forever.
- **La ruta:** la carpeta exacta de Forever donde queda `WTF`.

## Límites

- No sabe qué te mató: en Forever el combat log está restringido para los addons.
- Las notas no se comparten entre jugadores. Sería con mensajes de addon, y las cuentas de prueba no pueden mandarlos.

## Desarrollo

```bash
pip install pytest lupa
pytest                                        # addon en Lua 5.1 + página
python tools/make_demo_db.py                  # regenera el ejemplo (tests/fixtures/BitacoraDB.lua) jugando con el addon real
python tools/build_web.py                     # dist/bitacora.html
python tools/check_api.py --bir ../BlizzardInterfaceResources --ui ../wow-ui-source --scanner ../addon-sentry/src
```

Un tag `v*` empaqueta el addon con el packager de BigWigs (`.github/workflows/release.yml`).

Sin relación con Blizzard Entertainment. World of Warcraft es marca registrada de Blizzard Entertainment, Inc. Licencia MIT.
