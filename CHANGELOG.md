# Changelog

## 0.2.0 (unreleased)

- **Progress**: time per level, with the account's fastest character for each level (the count follows the addon's own sessions and re-anchors to `/played`); **companions**, who you grouped with (class, groups shared, last seen where), account-wide and capped at 500.
- **Reminders**: snooze 5/10/15 min from a small popup (optional); day-and-time reminders that came due while you were logged out fire at login, once, looking back up to 30 days; a setting to follow the realm's clock instead of your computer's. Same in Recordame.
- Web: time per level and companions in the journal overview, both looks.
- Look: the book cover is drawn for the window's shape (the compass rose no longer stretches); list rows take ink and gold on the tavern skin instead of the default teal; on the tavern web page the open ribbon and the main button are gold and crimson rather than blue, a pushpin that floated beside the notes is gone, and on a phone the tabs fit and the level chart keeps readable labels.

## 0.1.0 (unreleased)

First version, for WoW Forever 1.60.1.

- **Notebook**: tabs, search, item/quest/achievement links, notes attached to NPCs, items and zones (shown in tooltips and on arrival), up to 4 images per note.
- **Journal**: writes itself (start, levels, first visit of each zone, bosses, deaths, quests, loot of a chosen quality, achievements, gold, time played) plus your own entries, milestones filter and search.
- **Album**: every screenshot noted with when, where, level and group; captions.
- **Reminders**: by zone, level, login, mailbox, bank, vendor, auction house, day and time, or hours before the weekly reset; per character or for all, once or repeating. Officers can send day-and-time reminders to the whole guild.
- **Progress**: your numbers, every dungeon and raid of the Adventure Guide with the bosses killed, achievements by category.
- **Guild chronicle** (off by default): milestones shared with guildmates who have the addon.
- **Tavern look**: parchment pages, wooden title bar and a book cover that opens.
- Standalone parts (Libreta, Diario, Album, Recordatorios) sharing `Bitacora_Datos`, and **Recordame** as a fully independent reminders addon.
- Web companion (two looks) that reads the save file: journal day by day with search and a level chart, album paired with your screenshots, notebook, postcards of a day, Markdown export, image tool.
- Handles Forever beta quirks: double `PLAYER_DEAD`, stale zone text after travel, double window events.
