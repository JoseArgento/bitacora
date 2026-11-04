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
