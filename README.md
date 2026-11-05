# Bitácora

El diario de a bordo de tus personajes de **WoW Forever**: una libreta, un diario que se escribe solo, un álbum de capturas y recordatorios, en una sola ventana. Si querés solo una parte, cada una viene también como addon aparte. Tiene además una página web para leer todo eso fuera del juego.

[Read in English](README.en.md)

![La página web de Bitácora: el diario como libro de a bordo](docs/web.png)

**La web, en vivo:** [Bitácora](https://joseargento.github.io/bitacora/) · [Taberna](https://joseargento.github.io/bitacora/taberna.html)

**Contenido**

- [Qué hace](#qué-hace)
- [Las partes sueltas](#las-partes-sueltas)
- [Instalar](#instalar)
- [Imágenes en la libreta](#imágenes-en-la-libreta)
- [La página web](#la-página-web)
- [Privacidad](#privacidad)
- [Cómo se probó](#cómo-se-probó)
- [Límites](#límites)
- [Desarrollo](#desarrollo)
- [Apoyar](#apoyar)

## Qué hace

- **Libreta**
  - Notas con pestañas propias ("General", "Onyxia", lo que quieras) y búsqueda.
  - Una nota puede ser de todos tus personajes o de uno solo.
  - Shift-click en un ítem, una misión o un logro lo linkea en la nota.
  - **Notas pegadas a cosas:** pegás una nota a un PNJ (tu objetivo), a un ítem linkeado o a la zona. Aparece en el tooltip del PNJ o del ítem, y te avisa en el chat cuando entrás a esa zona.
  - **Imágenes:** hasta 4 por nota (ver más abajo).
- **Diario**
  - Se escribe solo: el día que empezó, cada nivel, la primera vez en cada zona, jefes (marca la primera vez), muertes, misiones, botín de la calidad que elijas (épico por defecto), logros, oro (1, 10, 100, 1000) y tiempo jugado.
  - **Lo de Forever:** los desafíos del Legado salen con sus puntos ("Desafío del Legado: Explorador (+3 puntos)"), tu primer campamento y cada plano de campamento que aprendés.
  - **"Dónde estaba":** si volvés a un personaje después de unos días (2 por defecto), una línea en el chat te dice cuándo fue la última vez, dónde, en qué nivel y tu última nota.
  - Podés escribir tus propias entradas.
  - Filtro de "hitos" para leerlo como una historia.
- **Álbum**
  - Cada vez que sacás una captura (Impr Pant) anota cuándo, dónde, en qué nivel y con quién estabas.
  - Le podés poner un epígrafe.
  - La página web junta esas anotaciones con las fotos.
- **Recordatorios**
  - "Cuando entre a Forjaz, vender el paño", "al llegar a 40, la montura", "al abrir el correo", "al entrar al juego", "los martes a las 20:30", "6 horas antes del reinicio semanal".
  - Pueden ser de un solo personaje o repetirse.
  - Avisan en el centro de la pantalla, con sonido, y en una ventanita con botones para **posponer** 5, 10 o 15 minutos (se puede apagar).
  - Los de día y hora van por el reloj de tu compu o, si lo elegís en las opciones, por el del reino. Si uno venció mientras no jugabas, salta al entrar (una vez; mira hasta 30 días atrás, desde la última vez que corrió el addon).
  - **De la guild:** un oficial (rango 0 o 1) puede mandar uno por día y hora a toda la guild ("jueves 19:45, raid: traigan pociones"). Salta a la misma hora para todos, se muestra en tu hora local, y solo lo puede borrar quien lo creó.
  - **Del calendario del juego:** al entrar mira los eventos de la guild (y los que te invitaron) de los próximos 7 días y, por cada uno nuevo, pregunta "¿Te aviso antes de «Onyxia» (jue 12/11 20:30)?" con Sí / No / Siempre. "Siempre" los crea sin preguntar de ahí en más; se apaga en las opciones. El aviso salta 60 minutos antes (en tu hora local).
  - **"Recordale a":** `/bita a Pepito: traé agua` le manda el recordatorio a alguien de tu guild o de tu lista de amigos por mensaje de addon (susurro), y le salta al instante. Solo se aceptan de gente de la guild o amigos; de cualquier otro se ignora en silencio.
  - **El campamento:** 5 minutos antes de que venza el buff del campamento te avisa (se apaga en las opciones). ⏳ Los hechizos y buffs de Forever todavía no tienen IDs conocidos: se reconocen por nombre.
- **Progreso**
  - Tus números: días jugados, zonas pisadas, misiones, jefes distintos, primeras muertes de jefes, botín, muertes, dónde más moriste y los puntos del Legado (del personaje y de la cuenta).
  - Cada mazmorra y banda de la guía de aventuras del juego, con cuántos jefes mataste ("Minas de la Muerte: 2 de 3").
  - Logros por categoría.
  - **Tiempo por nivel:** cuánto tardaste en cada nivel y, si otro personaje tuyo lo hizo más rápido, cuál y en cuánto. Se cuenta desde que el addon vio el nivel; si escribís `/played`, el conteo del juego manda.
  - **Compañeros:** con quién agrupaste (de toda la cuenta): clase, cuántos grupos, cuándo fue el último y dónde. Hasta 500; se van los más viejos.
- **Guild** (la crónica, apagada si no la prendés)
  - Si la prendés en las opciones, tus hitos (cada 10 niveles y el último, primeros jefes, logros, botín) les llegan a los de tu guild que tengan Bitácora, y ves los de ellos.

**La ventana es un libro abierto:** dos páginas de pergamino dentro de una tapa de cuero, con el lomo en el medio, marcadores de tela que asoman por el borde derecho como pestañas (el de la página abierta es dorado), el título en una cinta y un sello de lacre para cerrar. Tinta oscura y tipografía de manuscrito (Cinzel para los títulos, Alegreya para el cuerpo; fuentes OFL que van dentro del addon). Cada pestaña usa las dos páginas: la libreta tiene la lista a la izquierda y la nota a la derecha; el diario, las entradas a la izquierda y el resumen del personaje más la entrada que tocaste a la derecha; el álbum, las capturas y la que elegiste; los recordatorios, el formulario y la lista; el progreso, tus números y las mazmorras; la crónica, los hitos y la semana. Al abrirla se ve la tapa un instante y se abre (se puede apagar). Es la piel **Pergamino**, que comparten todos los addons de la familia: vive en `Bitacora_Datos/Libs/Pergamino` (repo [pergamino](https://github.com/JoseArgento/pergamino)) y no usa ninguna plantilla ni arte de Blizzard.

Se abre con `/bitacora` (o `/bita`), con una tecla (Opciones → Atajos → Bitácora) o desde el botón de addons junto al minimapa.

- `/bita nota <texto>` guarda una nota rápida.
- `/bita entrada <texto>` escribe en el diario.
- `/bita a Nombre: texto` le manda un recordatorio a alguien de la guild o amigo.
- `/bita chat nunca|importante|todo` mide lo que va al chat: nada, lo importante una vez por sesión (una captura anotada, las notas de una zona, "dónde estaba"), o todo. Las respuestas a comandos siempre salen.
- `/bita idioma es|en|auto` elige el idioma del addon, aunque el cliente esté en inglés (casi toda LatAm juega así). Lo mismo en Opciones.
- `/bita opciones` abre su página en Opciones → AddOns: tooltips, avisos, misiones en el diario, calidad del botín, el reloj, el chat, el idioma y la tapa del libro.

La primera vez que se abre el libro, una tarjeta cuenta qué hay en cada marcador; después, cada marcador lo dice al pasar el mouse (con la tecla que abre el libro, si la asignaste). En el diario, los niveles seguidos de un mismo día se pliegan en una línea ("Niveles 2 a 9") en la vista de hitos; en "Todo" está cada uno.

## Las partes sueltas

| Addon | Qué trae | Se abre con |
|---|---|---|
| `Bitacora` | todo junto, 6 pestañas | `/bitacora`, `/bita` |
| `Bitacora_Libreta` | la libreta y las notas pegadas a cosas | `/libreta` |
| `Bitacora_Diario` | el diario, con Progreso y la crónica de la guild | `/diario` |
| `Bitacora_Album` | el álbum | `/album` |
| `Bitacora_Recordatorios` | los recordatorios | `/recordatorios`, `/recordar` |

**Recordame** es aparte: son los recordatorios como addon propio, con sus datos y sin `Bitacora_Datos`, para quien quiere solo eso ([RECORDAME.md](RECORDAME.md)). Sale en su propio zip.

Las partes de arriba usan `Bitacora_Datos`, que es donde se guardan tus cosas. Por eso podés mezclarlos como quieras: si hoy usás solo el diario y mañana instalás la libreta, el diario sigue ahí. Si tenés instalado el `Bitacora` completo, las partes sueltas no hacen nada (te avisan en el chat) para que nada se anote dos veces.

## Instalar

1. Copiá a `Interface\AddOns\`, dentro de la carpeta de Forever del juego, la carpeta `Bitacora_Datos` y además `Bitacora` (todo junto) o las partes que quieras.
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
- el diario como un libro de a bordo, día por día, con buscador, un gráfico de niveles en el tiempo y un resumen (jefes, dónde más moriste, botín);
- **postales:** cada día tiene un botón "Postal" que arma una imagen de 1200×630 (el tamaño que Discord muestra bien) con el día, los niveles, las zonas y lo más importante, y la captura de ese día si la soltaste en el álbum;
- el diario entero para copiar o bajar como Markdown (`.md`), para un blog o un Discord;
- el álbum con tus capturas: las soltás y se emparejan por la hora del nombre del archivo (`WoWScrnShot_MMDDYY_HHMMSS.jpg`);
- **tus personajes lado a lado:** nivel, jugado, muertes, jefes, zonas, misiones, puntos del Legado y en cuántos niveles tiene el mejor tiempo de la cuenta;
- **la crónica de la guild**, semana por semana, con una "Postal de la semana" (1200×630) con los hitos de todos para pegar en Discord;
- la libreta y los recordatorios, con "Copiar como Markdown";
- la herramienta de imágenes.

`dist/taberna.html` es la misma página con otro look: madera, pergamino y cartas con el color de la clase de cada compañero. Nada sale de tu compu.

## ¿Y Forever Journal o Forever Told?

Hay otros diarios para Forever, y son buenos: [Forever Journal](https://www.curseforge.com/wow/addons/forever-journal) tiene el viaje por capítulos, metas, compañeros, un libro de misiones y recordatorios dentro del juego; [Forever Told](https://www.curseforge.com/wow/addons/forever-told) tiene crónica de guild, "se busca", epitafios Hardcore y capturas automáticas. Si querés eso, instalalos. Lo que Bitácora tiene y ellos no: **la página web** (el libro de a bordo, las postales, el álbum armado con tus capturas reales, los personajes lado a lado, la crónica de la guild semana a semana), las **notas que salen en el tooltip** del PNJ o del ítem, **imágenes** en las notas, los hitos propios de Forever (Legado, campamento, planos), el calendario del juego como recordatorios, castellano de verdad, y 178 tests que se corren contra la API de Forever antes de cada versión.

## Privacidad

El addon no manda nada tuyo a nadie si no prendés la crónica de la guild. Lo único que manda sin que lo prendas es un pedido vacío (`Q|1`) a tu guild al entrar, para recibir los recordatorios de tus oficiales; se apaga en las opciones. Los recordatorios de guild solo se aceptan de quien el roster dice que es oficial, y su texto se guarda sin el carácter `|` ni caracteres de control, cortado a 120 letras.

**La crónica** viene apagada. Si la prendés, manda por el canal de la guild, y nada más, un texto corto por hito: `M|1|level|20` o `M|1|boss|2746|Edwin VanCleef`. Lo que recibe se lee con patrones y se arma con textos propios: los nombres de logros y objetos se buscan en tu juego a partir del número, y el único texto libre (el nombre de un jefe) se guarda sin el carácter `|`, que es el que usa el juego para colores y links, y cortado a 40 letras. Nunca ejecuta nada de lo que llega. Acepta hasta 5 mensajes cada 10 segundos por persona y guarda los últimos 300. Las cuentas de prueba no pueden mandar mensajes de addon: ven la crónica pero no mandan la suya. Los nombres de tu grupo en el álbum son los que el juego muestra; si el juego los oculta (valores "secretos" de Forever), no se anotan.

## Cómo se probó

**Probado:**
- ✅ **Cada función, evento y template existe en Forever 1.60.1.** Lo revisa `tools/check_api.py` contra los dumps de [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources) y el código de la UI de [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source), rama `forever`. Ejemplos: `ChatFrameUtil.InsertLink` (Forever no tiene `ChatEdit_InsertLink`), `RaidWarningUtil.AddMessage` (`RaidNotice_AddMessage` solo existe con los alias viejos), `TooltipDataProcessor`, `ScrollingEditBoxTemplate`, el compartimento de addons de Forever. El script encuentra nombres inventados o mal escritos.
- ✅ [forever-lint](https://github.com/JoseArgento/forever-lint): solo la nota FL012 (las cuentas de prueba no pueden mandar mensajes de addon), que la crónica ya maneja. [Addon Sentry](https://github.com/JoseArgento/addon-sentry) da "Sin señales de riesgo".
- ✅ **178 tests.**
  - 147 corren el addon en Lua 5.1 (el Lua de WoW), con un reemplazo chico del cliente (`tests/wow_mock.lua`): eventos, datos guardados y recargados, recordatorios (incluido el semanal), tooltips, links con shift-click, nombres de imágenes, patrones de botín en varios idiomas, valores secretos, cada pestaña armándose sin errores de Lua, el progreso contra una guía de aventuras de prueba, la crónica (mensajes malos, con códigos de color o con código adentro, inundación, tope de 300, dos jugadores pasándose hitos), los reportes de la beta (muertes dobles, zona vieja al llegar), el tiempo por nivel (incluido el reajuste con `/played`), los compañeros (tope, valores secretos, otros reinos), los recordatorios que vencieron mientras no jugabas, posponer y el reloj del reino, el libro (páginas, marcadores, tapa, fuentes) y las partes sueltas: cada una sola, varias juntas compartiendo los datos, y el completo con una parte (la parte se hace a un lado).
  - El resto prueban la página: lee el archivo igual que Lua 5.1, empareja capturas y arma los textos.
- ✅ Las dos páginas probadas en Chromium: cada pestaña, el tiempo por nivel y los compañeros, capturas y PNG reales, escritorio y celular, claro y oscuro, y que no aparezca ningún "null" ni "undefined" en pantalla.

**Sin probar ⏳.** Todo esto se prueba dentro del juego, y yo no tengo Forever:
- **La ventana:** cómo se ve de verdad el libro en el cliente (texturas TGA, fuentes TTF propias, marcadores, tamaños, anclas, listas, menús), y la animación de la tapa. Está verificado en una maqueta HTML con las mismas medidas y en el mock de Lua, no en el juego.
- **Las imágenes:** que el juego cargue PNG desde `BitacoraImagenes`, una carpeta sin `.toc`.
- **Los nombres de archivo:** que las capturas de Forever se llamen `WoWScrnShot_MMDDYY_HHMMSS`.
- **Los eventos:** que `ENCOUNTER_END` o `BOSS_KILL` salten en las mazmorras de Forever.
- **La guía de aventuras:** que Forever liste sus mazmorras y bandas en `EJ_GetInstanceByIndex` (el orden de lo que devuelve `EJ_GetEncounterInfo` sí está verificado en el código de Blizzard).
- **La ruta:** la carpeta exacta de Forever donde queda `WTF`.
- **El reloj del reino:** que `C_DateAndTime.GetCurrentCalendarTime` dé la hora del reino en Forever (existe en el dump).
- **La ventanita de posponer:** cómo se ve el `StaticPopup` con cuatro botones.

## Límites

- No sabe qué te mató: en Forever el combat log está restringido para los addons.
- Las notas no se comparten entre jugadores; solo los hitos de la crónica, si la prendés.

## Desarrollo

```bash
pip install pytest lupa
pytest                                        # addon en Lua 5.1 + página
python tools/make_demo_db.py                  # regenera el ejemplo (tests/fixtures/BitacoraDB.lua) jugando con el addon real
python tools/build_editions.py                # rearma las partes sueltas desde Bitacora/ (un test avisa si te olvidaste)
python tools/make_textures.py                 # la tapa del libro (Bitacora_Datos/Media); la piel viene de Libs/Pergamino
python tools/build_web.py                     # dist/bitacora.html y dist/taberna.html
python tools/check_api.py --bir ../BlizzardInterfaceResources --ui ../wow-ui-source --scanner ../addon-sentry/src --addon Bitacora_Diario
```

Las partes sueltas y Recordame se generan: el código se edita solo en `Bitacora/`. Un tag `v*` arma dos zips con el packager de BigWigs (las seis carpetas de Bitácora, y Recordame con `.pkgmeta-recordame`) (`.github/workflows/release.yml`).

## Apoyar

Todo esto es gratis y de código abierto, y va a seguir así: no hay funciones pagas ni nada antes para quien aporta. Si te sirvió y querés bancar el tiempo de mantenerlo (con cada parche de Blizzard hay que actualizar los datos y arreglar lo que se rompe), podés hacerlo en [Patreon](https://www.patreon.com/cw/DoblePupi). Gracias ♥

Sin relación con Blizzard Entertainment. World of Warcraft es marca registrada de Blizzard Entertainment, Inc. Licencia MIT.
