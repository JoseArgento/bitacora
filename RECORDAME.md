# Recordame

Recordatorios para **WoW Forever** que saltan cuando importan. Es la pestaña de recordatorios de [Bitácora](README.md) como addon aparte: no necesita nada más.

- **Cuándo avisa:** al entrar a una zona o subzona ("cuando llegue a Forjaz, vender el paño"), al llegar a un nivel ("al 40, la montura"), al entrar al juego, al abrir el correo, el banco, un vendedor o la subasta, un día a una hora ("los martes a las 20:30") o unas horas antes del reinicio semanal.
- Cada uno puede ser de un personaje o de todos, de una vez o repetido. Avisa en el centro de la pantalla, con sonido.
- **Posponer:** cada aviso abre una ventanita con "5, 10 o 15 min después" (se apaga en las opciones). Si uno por día y hora venció mientras no jugabas, salta al entrar, una vez (mira hasta 30 días atrás). Los de día y hora van por el reloj de tu compu o por el del reino, a elección.
- **De la guild:** un oficial (rango 0 o 1) puede mandar un recordatorio por día y hora a toda la guild. Salta a la misma hora para todos, en la hora de cada uno. Les llega a los que tengan Recordame o Bitácora.
- **Del calendario del juego:** al entrar mira los eventos de la guild (y los que te invitaron) de los próximos 7 días y por cada uno nuevo pregunta "¿Te aviso antes de «Onyxia» (jue 12/11 20:30)?" con Sí / No / Siempre. Avisa 60 minutos antes, en tu hora. Se apaga en las opciones.
- **"Recordale a":** `/recordame a Pepito: traé agua` le manda el recordatorio a alguien de tu guild o de tu lista de amigos (mensaje de addon por susurro) y le salta al instante. Solo se aceptan de gente de la guild o amigos; de otros se ignora en silencio.
- **El campamento:** 5 minutos antes de que venza el buff del campamento, un aviso (se apaga en las opciones; ⏳ los IDs de Forever no se conocen, se reconoce por nombre).
- `/recordame` abre la ventana; también desde el botón de addons junto al minimapa. La ventana es una página de pergamino dentro de una tapa de cuero (la piel **Pergamino**, que va dentro del addon en `Libs/Pergamino`, con sus fuentes OFL): el formulario arriba, la lista abajo.

**Qué manda:** nada tuyo por su cuenta. Al entrar le pide a tu guild (`Q|1`, un pedido vacío) los recordatorios de los oficiales; se apaga en las opciones. Si sos oficial, manda los que escribas para la guild; si usás "recordale a", ese texto va por susurro a esa persona. Lo que llega solo se acepta de oficiales (los de guild) o de gente de la guild y amigos (los susurrados), se limpia y nunca se ejecuta.

**Con Bitácora instalado:** son dos addons con datos separados, así que cada uno tiene sus propios recordatorios. Los de la guild salen una sola vez.

**Instalar:** copiá la carpeta `Recordame` a `Interface\AddOns\`, dentro de la carpeta de Forever del juego.

**Cómo se probó:** con el mismo código y los mismos tests que los recordatorios de Bitácora (en Lua 5.1, contra la API de Forever 1.60.1), más tests propios: solo, guardado y cargado, junto con Bitácora completo. ⏳ Falta verlo en el juego.

---

**English:** Reminders for WoW Forever, as their own addon (Bitácora's reminders, standalone): by zone, level, login, mailbox, bank, vendor, auction house, day and time, or hours before the weekly reset, with snooze, catch-up of what came due while you were out, and your computer's or the realm's clock. Officers (ranks 0-1) can send day-and-time reminders to the whole guild. It sends nothing of yours; at login it asks the guild for the officers' reminders with an empty `Q|1` (can be turned off). `/recordame`.

Sin relación con Blizzard Entertainment. Licencia MIT.
