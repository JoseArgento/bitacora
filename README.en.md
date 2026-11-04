# Bitácora

A logbook for your **WoW Forever** characters: a notebook, a journal that writes itself, a screenshot album and reminders, in one window, plus a web page to read it all outside the game.

- **Notebook**: notes with your own tabs and search, for all characters or one; shift-click links items, quests and achievements. Notes can be **attached** to an NPC (your target), a linked item or a zone: they show in the NPC's or item's tooltip, and you get a chat line when you enter the zone. Up to 4 **images** per note.
- **Journal**: written for you. Levels, first visit of each zone, bosses (first kills marked), deaths, quests, loot of the quality you choose, achievements, gold (1/10/100/1000), time played, and your own entries. A "milestones" filter reads it like a story.
- **Album**: every screenshot (Print Screen) is noted with when, where, level and who you were with; add a caption. The web page pairs the notes with the photos.
- **Progress**: your numbers (days played, zones, quests, bosses, first kills, loot, deaths and where you died most), every dungeon and raid of the game's Adventure Guide with how many bosses you killed, and achievements by category.
- **Guild chronicle** (off unless you turn it on): your milestones go to guildmates who have Bitácora, and you see theirs.
- **Reminders**: "when I enter Ironforge", "at level 40", "when I open the mailbox", "when I log in", "Tuesdays at 20:30"; per character or for all, once or repeating. Center-screen alert with sound.

Open it with `/bitacora` (or `/bita`), a key binding, or the addon compartment by the minimap. `/bita note <text>` and `/bita entry <text>` save without opening it. `/bita options` opens its settings page, where you can also switch the window to the **Tavern** look: parchment pages, a wooden title bar and a book cover that opens.

**Install**: copy `Bitacora_Datos` (where your data is saved) plus either `Bitacora` (everything) or the parts you want into `Interface\AddOns\`. Each part is also its own addon: `Bitacora_Libreta` (`/libreta`), `Bitacora_Diario` (`/diario`), `Bitacora_Album` (`/album`), `Bitacora_Recordatorios` (`/recordatorios`). They share the same data, so you can mix them; when the full `Bitacora` is installed the parts step aside so nothing is logged twice.

**Images**: the game only loads images from the AddOns folder, as PNG, JPG, TGA or BLP with power-of-2 sides; a new file appears after `/reload`. Put them in `Interface\AddOns\BitacoraImagenes\` (outside the addon's folder, so updates keep them) and type the file name in the note. The web page's Images tab resizes any picture to a power of 2 and tells you the name to type.

**Web page**: `dist/bitacora.html` (or `dist/taberna.html`, the same page in a tavern look), one file that works offline. Open `WTF\Account\<ACCOUNT>\SavedVariables\Bitacora_Datos.lua` to read the journal day by day (each day can become a 1200×630 postcard image, with that day's screenshot if you dropped it in; the whole journal copies or downloads as Markdown), drop your screenshots to build the album, read and copy the notebook. Nothing leaves your computer.

**Privacy**: unless you turn on the guild chronicle, the addon sends nothing to anyone. The chronicle (off by default) sends one short line per milestone on the GUILD channel only; what arrives is parsed with patterns, turned into text with the addon's own strings (achievement and item names are looked up in your own client), and never run. Group members' names are only noted when the game does not hide them.

**Tested**: every global, event and template it uses was checked against Forever 1.60.1's API dumps and UI source (`tools/check_api.py`); forever-lint only shows the FL012 note (trial accounts and the chronicle's addon messages, handled) and Addon Sentry finds no risk signals; 106 tests run the addon (each part alone, several together, and full plus a part included) in Lua 5.1 with a small client stand-in and test the page's file reader against Lua. **Not tested in the game** (no Forever client here): how the window looks, PNG loading from `BitacoraImagenes`, Forever's screenshot file names, boss events in Forever dungeons, and the exact Forever folder name.

Not affiliated with Blizzard Entertainment. MIT license.
