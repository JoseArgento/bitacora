# Recordame

Recordatorios para **WoW Forever** que saltan cuando importan. Es la pestaña de recordatorios de [Bitácora](README.md) como addon aparte: no necesita nada más.

- **Cuándo avisa:** al entrar a una zona o subzona ("cuando llegue a Forjaz, vender el paño"), al llegar a un nivel ("al 40, la montura"), al entrar al juego, al abrir el correo, el banco, un vendedor o la subasta, un día a una hora ("los martes a las 20:30") o unas horas antes del reinicio semanal.
- Cada uno puede ser de un personaje o de todos, de una vez o repetido. Avisa en el centro de la pantalla, con sonido.
- **De la guild:** un oficial (rango 0 o 1) puede mandar un recordatorio por día y hora a toda la guild. Salta a la misma hora para todos, en la hora de cada uno. Les llega a los que tengan Recordame o Bitácora.
- `/recordame` abre la ventana; también desde el botón de addons junto al minimapa.

**Qué manda:** nada tuyo. Al entrar le pide a tu guild (`Q|1`, un pedido vacío) los recordatorios de los oficiales; se apaga en las opciones. Si sos oficial, manda los que escribas para la guild. Lo que llega solo se acepta de oficiales, se limpia y nunca se ejecuta.

**Con Bitácora instalado:** son dos addons con datos separados, así que cada uno tiene sus propios recordatorios. Los de la guild salen una sola vez.

**Instalar:** copiá la carpeta `Recordame` a `Interface\AddOns\`, dentro de la carpeta de Forever del juego.

**Cómo se probó:** con el mismo código y los mismos tests que los recordatorios de Bitácora (en Lua 5.1, contra la API de Forever 1.60.1), más tests propios: solo, guardado y cargado, junto con Bitácora completo. ⏳ Falta verlo en el juego.

---

**English:** Reminders for WoW Forever, as their own addon (Bitácora's reminders, standalone): by zone, level, login, mailbox, bank, vendor, auction house, day and time, or hours before the weekly reset. Officers (ranks 0-1) can send day-and-time reminders to the whole guild. It sends nothing of yours; at login it asks the guild for the officers' reminders with an empty `Q|1` (can be turned off). `/recordame`.

Sin relación con Blizzard Entertainment. Licencia MIT.
