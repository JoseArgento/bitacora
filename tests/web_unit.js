// node tests/web_unit.js: unit checks of web/core.js; prints "ok" or throws.
const assert = require("assert");
const core = require(require("path").join(__dirname, "..", "web", "core.js"));

// screenshots: exact stamp first, then the nearest within 10 s, each file once
const entries = [{ stamp: "110426_160500" }, { stamp: "110526_221200" }, { stamp: "110726_100000" }];
const files = [{ name: "WoWScrnShot_110426_160501.jpg" }, { name: "WoWScrnShot_110526_221200.jpg" }, { name: "WoWScrnShot_110526_221205.jpg" }, { name: "foto.png" }];
const { pairs, loose } = core.matchShots(entries, files);
assert.deepStrictEqual(pairs.map((p) => p.file && p.file.name), ["WoWScrnShot_110426_160501.jpg", "WoWScrnShot_110526_221200.jpg", null]);
assert.deepStrictEqual(loose.map((f) => f.name), ["WoWScrnShot_110526_221205.jpg", "foto.png"]);
assert.strictEqual(core.shotStamp("WoWScrnShot_123126_235959.tga"), "123126_235959");
assert.strictEqual(core.stampSeconds("010127_000000") - core.stampSeconds("123126_235959"), 1); // across the new year

// WoW markup to HTML, escaped
const html = core.markupToHtml('|cffa335ee|Hitem:17078::|h[Drape]|h|r <b>"x"</b>\nline|TInterface\\x:12|t');
assert.strictEqual(html, '<span class="q4"><span class="link" data-kind="item">[Drape]</span></span> &lt;b&gt;&quot;x&quot;&lt;/b&gt;<br>line');
assert.strictEqual(core.plain("|cffffffff|Hquest:1|h[Q]|h|r ok"), "[Q] ok");

// image names the addon accepts (Notes.lua ValidImageName: [%w_%-%.]+ with an image extension)
for (const [input, want] of [["Mapa de Ony (1).JPG", "Mapa_de_Ony_1.png"], ["../../x.png", "x.png"], ["ñandú.webp", "nandu.png"], ["", "imagen.png"]]) {
  assert.strictEqual(core.imageName(input), want);
  assert.match(want, /^[\w-]+\.png$/);
}
assert.strictEqual(core.powerOfTwoAtMost(700, 1024), 512);

// journal text and the demo file
const fs = require("fs");
const db = core.readDB(fs.readFileSync(require("path").join(__dirname, "fixtures", "BitacoraDB.lua")));
const jose = db.chars.find((c) => c.name === "Josecito");
assert.strictEqual(jose.album.length, 2);
assert.deepStrictEqual(jose.album[1].group, ["Ana", "Beto", "Caro"]);
assert.ok(core.journalMarkdown(jose, "es").includes("¡Derrotó a Edwin VanCleef por primera vez!"));
assert.ok(core.notesMarkdown(db, "es").includes("## Onyxia"));
const s = core.summary(jose);
assert.deepStrictEqual([s.level, s.bosses, s.deaths, s.played], [18, 1, 1, 23400]);
assert.throws(() => core.readDB("Other = {}"), /BitacoraDB/);
assert.deepStrictEqual(core.levelSeries(jose).map((p) => p.level), [1, 2, 3, 4, 5, 10, 18]);
const trip = core.tripStats(jose);
assert.deepStrictEqual(trip.deaths, [{ zone: "Páramos de Poniente", count: 1 }]);
assert.deepStrictEqual(trip.bosses.map((b) => [b.name, b.count]), [["Edwin VanCleef", 1]]);
assert.strictEqual(trip.loot.length, 1);
assert.strictEqual(core.searchEntries(jose.journal, "murloc", "es").length, 1);
assert.strictEqual(core.searchEntries(jose.journal, "  ", "es").length, jose.journal.length);
process.stdout.write("ok");

// a postcard of one day
{
  const day = jose.journal[0].d.slice(0, 10);
  const p = core.postcardData(jose, day, "es");
  assert.strictEqual(p.name, "Josecito");
  assert.strictEqual(p.day, day);
  assert.ok(p.lines.length >= 1 && p.lines.length <= 6);
  assert.ok(p.lines.every((l) => typeof l === "string" && !l.includes("|c")));
  assert.ok(p.levelFrom === null || p.levelFrom <= p.levelTo);
  const none = core.postcardData(jose, "1999-01-01", "es");
  assert.deepStrictEqual([none.lines, none.levelFrom, none.shotStamp], [[], null, null]);
}

// time per level and companions (the demo: Josecito 1->5 in 30 min, Anabel 1->6 with known splits)
assert.deepStrictEqual(core.splits(db.chars.find((c) => c.name === "Anabel")).map((s) => [s.level, s.seconds / 60]), [[1, 12], [2, 20], [3, 25], [4, 30], [5, 40]]);
const best = core.bestSplits(db.chars);
assert.strictEqual(best.get(1).name, "Anabel");
assert.deepStrictEqual(db.companions.map((p) => [p.name, p.class, p.times]), [["Beto", "PRIEST", 1], ["Caro", "ROGUE", 1], ["Ana", "WARRIOR", 1]]);

// round 8: Legacy points, campsite and blueprint entries, characters side by side, the guild chronicle
assert.strictEqual(core.summary(jose).legacy, 3);
assert.ok(core.entryText(jose.journal.find((e) => e.legacy), "en").includes("Legacy challenge") && core.entryText(jose.journal.find((e) => e.legacy), "en").includes("+3"));
assert.strictEqual(core.entryText(jose.journal.find((e) => e.kind === "camp"), "es"), "Armó su primer campamento.");
assert.strictEqual(core.entryText(jose.journal.find((e) => e.kind === "blueprint"), "en"), "Learned the Anvil blueprint (Blacksmithing).");
const cmp = core.compareChars(db.chars);
assert.deepStrictEqual(cmp.map((c) => c.name).sort(), ["Anabel", "Josecito"]);
const cj = cmp.find((c) => c.name === "Josecito");
assert.deepStrictEqual([cj.legacy, cj.distinctBosses, cj.quests, cj.levelsTimed], [3, 1, 2, 6]);
assert.strictEqual(cmp.reduce((n, c) => n + c.bests, 0), core.bestSplits(db.chars).size);
assert.strictEqual(db.guilds.length, 1);
assert.strictEqual(db.guilds[0].name, "Los Del Fondo");
assert.strictEqual(db.guilds[0].entries.length, 6);
assert.strictEqual(core.chronicleText(db.guilds[0].entries.find((e) => e.kind === "boss"), "es"), "Caro mató por primera vez a Edwin VanCleef");
assert.strictEqual(core.chronicleText(db.guilds[0].entries.find((e) => e.kind === "loot"), "en"), "Ana got Sapphiron Drape");
assert.strictEqual(core.chronicleText(db.guilds[0].entries.find((e) => e.kind === "achievement"), "en"), "Beto earned Diez misiones");
const last = db.guilds[0].entries[db.guilds[0].entries.length - 1].t;
const week = core.guildWeek(db.guilds[0].entries, last);
assert.strictEqual(week.entries.length, 6);
assert.deepStrictEqual(week.people[0], { who: "Ana", n: 3 });
assert.strictEqual(core.guildWeek(db.guilds[0].entries, last - 7 * 86400).entries.length, 0);

// round 9: the start entry without a zone, and consecutive level-ups of one day folded into one row
assert.strictEqual(core.entryText({ kind: "start", level: 1, zone: "" }, "es"), "Empezó el diario en nivel 1.");
assert.strictEqual(core.entryText({ kind: "start", level: 1, zone: "Elwynn" }, "en"), "Started the journal at level 1 in Elwynn.");
const lv = (n, d, zone = "Elwynn") => ({ kind: "level", level: n, t: n, d, zone });
const folded = core.groupLevels([{ kind: "start", level: 1, d: "2026-11-04 15:10" }, lv(2, "2026-11-04 15:25"), lv(3, "2026-11-04 15:33"), lv(4, "2026-11-04 15:44"), { kind: "zone", name: "Westfall", d: "2026-11-04 16:00" }, lv(5, "2026-11-04 16:10"), lv(6, "2026-11-05 10:00"), lv(7, "2026-11-05 10:30")]);
assert.deepStrictEqual(folded.map((e) => (e.group ? `${e.from}-${e.level}` : e.kind)), ["start", "2-4", "zone", "level", "6-7"]);
assert.strictEqual(core.entryText(folded[1], "es"), "Niveles 2 a 4.");
assert.strictEqual(folded[1].d, "2026-11-04 15:44");
assert.strictEqual(core.groupLevels([lv(2, "2026-11-04 15:25")]).length, 1);
