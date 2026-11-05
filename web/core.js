/* Bitácora web: reading the addon's SavedVariables and matching screenshots. No DOM here, so Node can test it. */
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.BitacoraCore = factory();
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  // ---------------------------------------------------------------- Lua table literals
  // The client writes SavedVariables as "Name = { ["key"] = value, ... }" with "-- [n]" comments.
  // This reads any Lua literal (strings with escapes, long strings, numbers, booleans, nested tables).

  class LuaError extends Error {}

  function parseLua(input) {
    const b = typeof input === "string" ? new TextEncoder().encode(input) : new Uint8Array(input);
    const n = b.length;
    const dec = new TextDecoder("utf-8");
    let p = 0;
    if (b[0] === 0xef && b[1] === 0xbb && b[2] === 0xbf) p = 3;
    const isSpace = (c) => c === 32 || c === 9 || c === 10 || c === 13 || c === 11 || c === 12;
    const isDigit = (c) => c >= 48 && c <= 57;
    const isAlpha = (c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c === 95;
    const fail = (msg) => {
      let line = 1;
      for (let i = 0; i < p && i < n; i++) if (b[i] === 10) line++;
      throw new LuaError(`${msg} (line ${line})`);
    };

    function longBracketLevel(at) {
      // at points to "[": returns level for [==[ or -1
      let q = at + 1, level = 0;
      while (b[q] === 61) { level++; q++; }
      return b[q] === 91 ? level : -1;
    }
    function readLong(level) {
      // p is at the opening "[" of [==[
      p += level + 2;
      if (b[p] === 13) p++;
      if (b[p] === 10) p++;
      const start = p;
      while (p < n) {
        if (b[p] === 93) {
          let q = p + 1, l = 0;
          while (b[q] === 61) { l++; q++; }
          if (l === level && b[q] === 93) {
            const s = b.subarray(start, p);
            p = q + 1;
            return s;
          }
        }
        p++;
      }
      fail("unfinished long string");
    }
    function skip() {
      for (;;) {
        while (p < n && isSpace(b[p])) p++;
        if (b[p] === 45 && b[p + 1] === 45) {
          p += 2;
          if (b[p] === 91) {
            const level = longBracketLevel(p);
            if (level >= 0) { readLong(level); continue; }
          }
          while (p < n && b[p] !== 10) p++;
          continue;
        }
        return;
      }
    }
    function readString(q) {
      p++;
      const out = [];
      while (p < n && b[p] !== q) {
        let c = b[p];
        if (c === 10) fail("unfinished string");
        if (c !== 92) { out.push(c); p++; continue; }
        p++;
        c = b[p];
        const simple = { 110: 10, 116: 9, 114: 13, 97: 7, 98: 8, 102: 12, 118: 11, 92: 92, 34: 34, 39: 39, 10: 10 };
        if (c in simple) { out.push(simple[c]); p++; if (c === 10 && b[p] === 13) p++; continue; }
        if (c === 13) { out.push(10); p++; if (b[p] === 10) p++; continue; }
        if (isDigit(c)) {
          let v = 0, k = 0;
          while (k < 3 && isDigit(b[p])) { v = v * 10 + (b[p] - 48); p++; k++; }
          if (v > 255) fail("escape too large");
          out.push(v);
          continue;
        }
        if (c === 120) {
          const hex = String.fromCharCode(b[p + 1], b[p + 2]);
          if (!/^[0-9a-fA-F]{2}$/.test(hex)) fail("bad \\x escape");
          out.push(parseInt(hex, 16));
          p += 3;
          continue;
        }
        if (c === 122) { p++; while (p < n && isSpace(b[p])) p++; continue; }
        fail("bad escape");
      }
      if (p >= n) fail("unfinished string");
      p++;
      return dec.decode(new Uint8Array(out));
    }
    function readNumber() {
      const start = p;
      if (b[p] === 45) p++;
      if (b[p] === 48 && (b[p + 1] === 120 || b[p + 1] === 88)) {
        p += 2;
        while (p < n && /[0-9a-fA-F]/.test(String.fromCharCode(b[p]))) p++;
      } else {
        while (p < n && (isDigit(b[p]) || b[p] === 46)) p++;
        if (b[p] === 101 || b[p] === 69) {
          p++;
          if (b[p] === 43 || b[p] === 45) p++;
          while (p < n && isDigit(b[p])) p++;
        }
      }
      const text = dec.decode(b.subarray(start, p));
      const v = /^-?0[xX]/.test(text) ? (text[0] === "-" ? -1 : 1) * parseInt(text.replace(/^-?0[xX]/, ""), 16) : Number(text);
      if (!Number.isFinite(v) && !/inf/i.test(text)) fail("bad number");
      return v;
    }
    function readName() {
      const start = p;
      while (p < n && (isAlpha(b[p]) || isDigit(b[p]))) p++;
      return dec.decode(b.subarray(start, p));
    }

    let depth = 0;
    function value() {
      skip();
      const c = b[p];
      if (c === 123) return table();
      if (c === 34 || c === 39) return readString(c);
      if (c === 91) {
        const level = longBracketLevel(p);
        if (level >= 0) return dec.decode(readLong(level));
      }
      if (isDigit(c) || (c === 45 && (isDigit(b[p + 1]) || b[p + 1] === 46)) || (c === 46 && isDigit(b[p + 1]))) return readNumber();
      if (isAlpha(c)) {
        const word = readName();
        if (word === "true") return true;
        if (word === "false") return false;
        if (word === "nil") return null;
        fail(`unexpected "${word}"`);
      }
      fail("expected a value");
    }
    function table() {
      if (++depth > 200) fail("tables nested too deep");
      p++;
      const entries = [];
      let next = 1, positional = false;
      for (;;) {
        skip();
        if (b[p] === 125) { p++; break; }
        let key, val;
        if (b[p] === 91 && longBracketLevel(p) < 0) {
          p++;
          key = value();
          skip();
          if (b[p] !== 93) fail('expected "]"');
          p++;
          skip();
          if (b[p] !== 61) fail('expected "="');
          p++;
          val = value();
        } else if (isAlpha(b[p])) {
          const save = p;
          const word = readName();
          skip();
          if (b[p] === 61 && b[p + 1] !== 61) {
            p++;
            key = word;
            val = value();
          } else {
            p = save;
            key = next++;
            val = value();
            positional = true;
          }
        } else {
          key = next++;
          val = value();
          positional = true;
        }
        if (key !== null) entries.push([key, val, positional]);
        positional = false;
        skip();
        if (b[p] === 44 || b[p] === 59) { p++; continue; }
        if (b[p] === 125) { p++; break; }
        fail('expected "," or "}"');
      }
      depth--;
      return toJs(entries);
    }

    const out = {};
    for (;;) {
      skip();
      if (p >= n) break;
      if (!isAlpha(b[p])) fail("expected a variable name");
      const name = readName();
      skip();
      if (b[p] !== 61) fail('expected "="');
      p++;
      out[name] = value();
      skip();
      if (b[p] === 59) p++;
    }
    return out;
  }

  // A Lua table as JS: a sequence 1..n becomes an array, anything else an object with string keys.
  // As in Lua, positional items win over an explicit [n] = ... for the same index, and nil removes.
  function toJs(entries) {
    const m = new Map();
    for (const [k, v, pos] of entries) if (!pos) m.set(k, v);
    for (const [k, v, pos] of entries) if (pos) m.set(k, v);
    for (const [k, v] of [...m]) if (v === null) m.delete(k);
    if (m.size === 0) return [];
    const keys = [...m.keys()];
    const nums = keys.every((k) => typeof k === "number" && Number.isInteger(k) && k >= 1 && k <= m.size);
    if (nums) return keys.sort((a, b) => a - b).map((k) => m.get(k));
    const o = {};
    for (const [k, v] of m) o[String(k)] = v;
    return o;
  }

  const list = (v) => (Array.isArray(v) ? v : v && typeof v === "object" ? Object.keys(v).sort((a, b) => Number(a) - Number(b)).map((k) => v[k]) : []);

  // ---------------------------------------------------------------- the database

  function readDB(text) {
    const vars = parseLua(text);
    const db = vars.BitacoraDB;
    if (!db || typeof db !== "object" || Array.isArray(db)) throw new LuaError("this file has no BitacoraDB: open WTF/Account/<account>/SavedVariables/Bitacora_Datos.lua");
    const chars = Object.entries(db.chars && !Array.isArray(db.chars) ? db.chars : {}).map(([key, c]) => ({
      key,
      name: c.name || key.split("-")[0],
      realm: c.realm || key.split("-").slice(1).join("-"),
      class: c.class || "",
      race: c.race || "",
      level: c.level || 0,
      created: c.created || 0,
      journal: list(c.journal),
      album: list(c.album).map((s, i) => ({ ...s, index: i + 1, group: list(s.group) })),
      visited: Object.keys(c.visited && !Array.isArray(c.visited) ? c.visited : {}).length,
      played: c.played || null,
    }));
    const companions = Object.entries(db.companions && !Array.isArray(db.companions) ? db.companions : {})
      .map(([key, c]) => ({ key, name: c.name || key.split("-")[0], realm: c.realm || "", class: c.class || "", first: c.first || 0, last: c.last || 0, zone: c.zone || "", times: c.times || 0 }))
      .sort((a, b) => b.last - a.last || a.key.localeCompare(b.key));
    chars.sort((a, b) => (b.journal.length ? b.journal[b.journal.length - 1].t : 0) - (a.journal.length ? a.journal[a.journal.length - 1].t : 0));
    // the guild chronicle: one list per guild the account's characters were in ({ who, kind, n, name, t })
    const guilds = Object.entries(db.guild && !Array.isArray(db.guild) ? db.guild : {}).map(([key, entries]) => ({
      key, name: key.split("-")[0], entries: list(entries).filter((e) => e && e.who && e.kind).sort((a, b) => (a.t || 0) - (b.t || 0)),
    })).filter((g) => g.entries.length).sort((a, b) => b.entries[b.entries.length - 1].t - a.entries[a.entries.length - 1].t);
    const sections = list(db.sections);
    const notes = Object.values(db.notes && !Array.isArray(db.notes) ? db.notes : {}).map((x) => ({ ...x, images: list(x.images) }));
    const reminders = list(db.reminders);
    return { version: db.version || 0, settings: db.settings || {}, chars, sections, notes, reminders, companions, guilds };
  }

  // ---------------------------------------------------------------- screenshots

  // WoWScrnShot_MMDDYY_HHMMSS.jpg (local time). Seconds on a naive clock, only to compare stamps.
  const SHOT_RE = /WoWScrnShot_(\d{2})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})/i;
  function stampSeconds(stamp) {
    const m = SHOT_RE.exec("WoWScrnShot_" + String(stamp || "").replace(/^WoWScrnShot_/i, ""));
    if (!m) return null;
    const [, mo, d, y, h, mi, s] = m.map(Number);
    return Date.UTC(2000 + y, mo - 1, d, h, mi, s) / 1000;
  }
  function shotStamp(filename) {
    const m = SHOT_RE.exec(filename || "");
    return m ? `${m[1]}${m[2]}${m[3]}_${m[4]}${m[5]}${m[6]}` : null;
  }

  // Pair album entries with screenshot files: same stamp, or the closest within `slack` seconds
  // (the event can land a second after the file name's time). Each file is used once.
  function matchShots(entries, files, slack = 10) {
    const pool = files.map((f) => ({ file: f, stamp: shotStamp(f.name), used: false })).filter((x) => x.stamp);
    const pairs = entries.map((e) => ({ entry: e, file: null }));
    for (const pair of pairs) {
      const hit = pool.find((x) => !x.used && x.stamp === pair.entry.stamp);
      if (hit) { hit.used = true; pair.file = hit.file; }
    }
    for (const pair of pairs) {
      if (pair.file) continue;
      const want = stampSeconds(pair.entry.stamp);
      if (want == null) continue;
      let best = null, bestGap = slack + 1;
      for (const x of pool) {
        if (x.used) continue;
        const gap = Math.abs(stampSeconds(x.stamp) - want);
        if (gap < bestGap) { best = x; bestGap = gap; }
      }
      if (best) { best.used = true; pair.file = best.file; }
    }
    const loose = pool.filter((x) => !x.used).map((x) => x.file);
    const unnamed = files.filter((f) => !shotStamp(f.name));
    return { pairs, loose: loose.concat(unnamed) };
  }

  // ---------------------------------------------------------------- WoW text markup

  const QUALITY = { "9d9d9d": "q0", ffffff: "q1", "1eff00": "q2", "0070dd": "q3", a335ee: "q4", ff8000: "q5", e6cc80: "q6", "00ccff": "q7", ffff00: "qq", ffd100: "qq" };
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

  // "|cffa335ee|Hitem:..|h[Sapphiron Drape]|h|r" -> <span class="link q4">[Sapphiron Drape]</span>
  function markupToHtml(s) {
    let html = esc(s || "");
    html = html.replace(/\|T[^|]*\|t/g, "").replace(/\|A[^|]*\|a/g, "");
    html = html.replace(/\|c([0-9a-fA-F]{2})([0-9a-fA-F]{6})(.*?)\|r/g, (_, _a, rgb, inner) => `<span class="${QUALITY[rgb.toLowerCase()] || "qx"}">${inner}</span>`);
    html = html.replace(/\|H([a-z]+):[^|]*\|h(.*?)\|h/g, (_, kind, text) => `<span class="link" data-kind="${esc(kind)}">${text}</span>`);
    html = html.replace(/\|n/g, "\n").replace(/\|\|/g, "|");
    return html.replace(/\n/g, "<br>");
  }
  function plain(s) {
    return String(s || "")
      .replace(/\|H[^|]*\|h(.*?)\|h/g, "$1")
      .replace(/\|c[0-9a-fA-F]{8}/g, "")
      .replace(/\|r/g, "")
      .replace(/\|T[^|]*\|t/g, "");
  }

  // ---------------------------------------------------------------- journal text (mirrors Journal.lua)

  const TEXT = {
    es: {
      start: (e) => (e.zone ? `Empezó el diario en nivel ${e.level || 1}, en ${e.zone}.` : `Empezó el diario en nivel ${e.level || 1}.`),
      level: (e) => (e.group ? `Niveles ${e.from} a ${e.level}` : `Llegó a nivel ${e.level}.`),
      zone: (e) => `Llegó por primera vez a ${e.name || e.zone}.`,
      boss: (e) => (e.first ? `¡Derrotó a ${e.name} por primera vez!` : `Derrotó a ${e.name}.`),
      death: (e) => `Murió en ${e.zone || "?"}.`,
      quest: (e) => (e.title ? `Completó: ${e.title}.` : `Completó la misión ${e.quest}.`),
      loot: (e) => `Consiguió ${e.link || e.name}.`,
      achievement: (e) => (e.legacy ? `Desafío del Legado: ${e.link || e.name} (+${e.legacy} puntos).` : `Logro: ${e.link || e.name}.`),
      money: (e) => `Primera vez con ${Math.floor((e.amount || 0) / 10000)} de oro.`,
      played: (e) => `Tiempo jugado: ${duration(e.total, "es")}.`,
      note: (e) => e.text || "",
      camp: () => "Armó su primer campamento.",
      blueprint: (e) => `Aprendió el plano de ${e.name} (${e.profession}).`,
    },
    en: {
      start: (e) => (e.zone ? `Started the journal at level ${e.level || 1} in ${e.zone}.` : `Started the journal at level ${e.level || 1}.`),
      level: (e) => (e.group ? `Levels ${e.from} to ${e.level}` : `Reached level ${e.level}.`),
      zone: (e) => `Arrived in ${e.name || e.zone} for the first time.`,
      boss: (e) => (e.first ? `Defeated ${e.name} for the first time!` : `Defeated ${e.name}.`),
      death: (e) => `Died in ${e.zone || "?"}.`,
      quest: (e) => (e.title ? `Completed: ${e.title}.` : `Completed quest ${e.quest}.`),
      loot: (e) => `Got ${e.link || e.name}.`,
      achievement: (e) => (e.legacy ? `Legacy challenge: ${e.link || e.name} (+${e.legacy} points).` : `Achievement: ${e.link || e.name}.`),
      money: (e) => `First time with ${Math.floor((e.amount || 0) / 10000)} gold.`,
      played: (e) => `Time played: ${duration(e.total, "en")}.`,
      note: (e) => e.text || "",
      camp: () => "Built a first campsite.",
      blueprint: (e) => `Learned the ${e.name} blueprint (${e.profession}).`,
    },
  };
  const MILESTONES = new Set(["start", "level", "zone", "boss", "death", "achievement", "loot", "money", "note", "camp", "blueprint"]);
  function entryText(e, lang) {
    const f = (TEXT[lang] || TEXT.es)[e.kind];
    return f ? f(e) : e.kind;
  }
  function isMilestone(e) {
    return MILESTONES.has(e.kind) && !(e.kind === "boss" && !e.first);
  }
  // The milestones view: consecutive level-ups of one day fold into a single row ("Niveles 2 a 9"),
  // which keeps the last level-up's time and place. Same rule as the addon's J.Grouped.
  function groupLevels(entries) {
    const out = [];
    let run = null;
    const flush = () => { if (run) { out.push(run.entries.length > 1 ? run : run.entries[0]); run = null; } };
    for (const e of entries) {
      const day = (e.d || "").slice(0, 10);
      if (e.kind === "level" && run && run.day === day && (e.level || 0) === (run.level || 0) + 1) {
        run.level = e.level; run.t = e.t; run.d = e.d; run.zone = e.zone; run.sub = e.sub;
        run.entries.push(e);
      } else {
        flush();
        if (e.kind === "level") run = { kind: "level", group: true, day, from: e.level, level: e.level, t: e.t, d: e.d, zone: e.zone, sub: e.sub, entries: [e] };
        else out.push(e);
      }
    }
    flush();
    return out;
  }
  function duration(seconds, lang) {
    const s = Math.max(0, Math.floor(seconds || 0));
    const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
    const parts = [];
    if (d) parts.push(lang === "en" ? `${d} d` : `${d} d`);
    if (h) parts.push(`${h} h`);
    if (m || !parts.length) parts.push(`${m} min`);
    return parts.join(" ");
  }

  function summary(c) {
    let bosses = 0, deaths = 0, loot = 0, legacy = 0, quests = 0;
    const distinct = new Set();
    for (const e of c.journal) {
      if (e.kind === "boss") { bosses++; distinct.add(e.boss != null ? e.boss : e.name); }
      else if (e.kind === "death") deaths++;
      else if (e.kind === "loot") loot++;
      else if (e.kind === "quest") quests++;
      else if (e.kind === "achievement" && typeof e.legacy === "number") legacy += e.legacy;
    }
    const played = c.played ? c.played.total : null;
    return { level: c.level, bosses, distinctBosses: distinct.size, deaths, loot, quests, legacy, zones: c.visited, played, since: c.journal.length ? c.journal[0].t : c.created };
  }

  // Every character side by side (mirrors the Progress tab's numbers), plus how many levels each holds
  // the account's best time for.
  function compareChars(chars) {
    const best = bestSplits(chars);
    return chars.map((c) => {
      const s = summary(c);
      let bests = 0;
      for (const b of best.values()) if (b.name === c.name) bests++;
      return { key: c.key, name: c.name, realm: c.realm, class: c.class, ...s, bests, levelsTimed: splits(c).length };
    });
  }

  // The guild chronicle's text (mirrors Chronicle.lua C.Describe); names were looked up by the addon.
  const CHRON = {
    es: {
      level: (e) => `${e.who} llegó a nivel ${e.n}`,
      boss: (e) => `${e.who} mató por primera vez a ${e.name || "#" + e.n}`,
      achievement: (e) => `${e.who} consiguió ${e.name || "el logro #" + e.n}`,
      loot: (e) => `${e.who} consiguió ${e.name || "el objeto #" + e.n}`,
      start: (e) => `${e.who} empezó una aventura nueva`,
    },
    en: {
      level: (e) => `${e.who} reached level ${e.n}`,
      boss: (e) => `${e.who} killed ${e.name || "#" + e.n} for the first time`,
      achievement: (e) => `${e.who} earned ${e.name || "achievement #" + e.n}`,
      loot: (e) => `${e.who} got ${e.name || "item #" + e.n}`,
      start: (e) => `${e.who} started a new adventure`,
    },
  };
  function chronicleText(e, lang) {
    const f = (CHRON[lang] || CHRON.es)[e.kind];
    return f ? f(e) : `${e.who} · ${e.kind}`;
  }
  // The chronicle's entries of the 7 days ending at `end` (epoch), oldest first; who did the most.
  function guildWeek(entries, end) {
    const from = end - 7 * 86400;
    const week = entries.filter((e) => e.t > from && e.t <= end);
    const by = new Map();
    for (const e of week) by.set(e.who, (by.get(e.who) || 0) + 1);
    const people = [...by].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).map(([who, n]) => ({ who, n }));
    return { from, end, entries: week, people };
  }

  // Level over time: the journal's start and every level-up, never going down (a re-rolled journal could).
  function levelSeries(c) {
    const pts = [];
    for (const e of c.journal) {
      if ((e.kind === "start" || e.kind === "level") && e.level != null && e.t) {
        if (!pts.length || e.level > pts[pts.length - 1].level) pts.push({ t: e.t, level: e.level, d: e.d });
      }
    }
    return pts;
  }

  // How long each level took (mirrors Progress.lua P.Splits): from the "played" seconds the addon writes at
  // the start and at every level-up. [{ level, seconds, at }]
  function splits(c) {
    const out = [];
    let prev = null;
    for (const e of c.journal) {
      if ((e.kind === "start" || e.kind === "level") && typeof e.level === "number" && typeof e.played === "number") {
        if (prev && e.kind === "level" && e.level > prev.level && e.played >= prev.played) out.push({ level: prev.level, seconds: e.played - prev.played, at: e.t });
        prev = e;
      }
    }
    return out;
  }
  // The account's fastest time at each level: Map(level -> { seconds, name }).
  function bestSplits(chars) {
    const best = new Map();
    for (const c of chars) for (const s of splits(c)) if (!best.has(s.level) || s.seconds < best.get(s.level).seconds) best.set(s.level, { seconds: s.seconds, name: c.name });
    return best;
  }

  // The trip in a few lists: where you died most, bosses (first kill, times), loot.
  function tripStats(c) {
    const deaths = new Map(), bosses = new Map(), loot = [];
    for (const e of c.journal) {
      if (e.kind === "death") {
        const z = e.zone || "?";
        deaths.set(z, (deaths.get(z) || 0) + 1);
      } else if (e.kind === "boss") {
        const b = bosses.get(e.name) || { name: e.name, first: e.d, count: 0 };
        b.count++;
        bosses.set(e.name, b);
      } else if (e.kind === "loot") loot.push({ link: e.link || e.name, d: e.d, quality: e.quality });
    }
    return {
      deaths: [...deaths].map(([zone, count]) => ({ zone, count })).sort((a, b) => b.count - a.count || a.zone.localeCompare(b.zone)),
      bosses: [...bosses.values()].sort((a, b) => (a.first < b.first ? -1 : 1)),
      loot,
    };
  }

  function searchEntries(entries, query, lang) {
    const words = String(query || "").toLowerCase().split(/\s+/).filter(Boolean);
    if (!words.length) return entries;
    return entries.filter((e) => {
      const hay = plain(`${entryText(e, lang)} ${e.zone || ""} ${e.sub || ""}`).toLowerCase();
      return words.every((w) => hay.includes(w));
    });
  }

  // Days in local time of the entries (the "d" field the addon wrote, "YYYY-MM-DD HH:MM").
  function groupByDay(entries) {
    const days = [];
    for (const e of entries) {
      const day = (e.d || "").slice(0, 10) || "?";
      let g = days[days.length - 1];
      if (!g || g.day !== day) days.push((g = { day, entries: [] }));
      g.entries.push(e);
    }
    return days;
  }

  // ---------------------------------------------------------------- images for the notebook

  function powerOfTwoAtMost(x, max) {
    let v = 1;
    while (v * 2 <= Math.min(x, max)) v *= 2;
    return Math.max(v, 8);
  }
  // A safe file name for Interface\AddOns\BitacoraImagenes: what Notes.lua's ValidImageName accepts.
  function imageName(name) {
    let base = String(name || "imagen").replace(/\.[^.]*$/, "");
    base = base.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^\w-]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 60);
    return (base || "imagen") + ".png";
  }

  function notesMarkdown(db, lang) {
    const out = [`# ${lang === "en" ? "Notebook" : "Libreta"}`];
    for (const s of db.sections) {
      const notes = db.notes.filter((n) => n.section === s.id).sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0) || b.updated - a.updated);
      if (!notes.length) continue;
      out.push("", `## ${s.name}`);
      for (const n of notes) {
        out.push("", `### ${n.title || plain(n.body).split("\n")[0] || "—"}`);
        if (n.attach) out.push(`*${lang === "en" ? "Attached to" : "Pegada a"}: ${n.attach.label || n.attach.key}*`);
        if (n.body) out.push("", plain(n.body));
        if (n.images.length) out.push("", n.images.map((i) => `- ${i}`).join("\n"));
      }
    }
    return out.join("\n") + "\n";
  }

  function journalMarkdown(c, lang) {
    const out = [`# ${c.name} (${c.realm})`];
    for (const g of groupByDay(c.journal)) {
      out.push("", `## ${g.day}`);
      for (const e of g.entries) out.push(`- ${(e.d || "").slice(11)} · ${plain(entryText(e, lang))}${e.zone && e.kind !== "zone" ? ` (${e.zone})` : ""}`);
    }
    return out.join("\n") + "\n";
  }

  // One day of the journal as a postcard: what to write on it. The page draws it (app.js).
  function postcardData(c, day, lang) {
    const entries = c.journal.filter((e) => (e.d || "").slice(0, 10) === day);
    const levels = entries.map((e) => e.level).filter((l) => typeof l === "number");
    const zones = [];
    for (const e of entries) if (e.zone && !zones.includes(e.zone)) zones.push(e.zone);
    const count = (kind) => entries.filter((e) => e.kind === kind).length;
    const picked = entries.filter(isMilestone);
    const lines = (picked.length ? picked : entries).slice(0, 6).map((e) => plain(entryText(e, lang)));
    const shot = c.album.find((a) => (a.d || "").slice(0, 10) === day);
    return {
      name: c.name,
      day,
      levelFrom: levels.length ? Math.min(...levels) : null,
      levelTo: levels.length ? Math.max(...levels) : null,
      zones: zones.slice(0, 3),
      deaths: count("death"),
      bosses: count("boss"),
      quests: count("quest"),
      lines,
      more: Math.max(0, (picked.length ? picked : entries).length - lines.length),
      shotStamp: shot ? shot.stamp : null,
    };
  }

  return { compareChars, chronicleText, guildWeek, splits, bestSplits, postcardData, levelSeries, tripStats, searchEntries, LuaError, parseLua, readDB, stampSeconds, shotStamp, matchShots, markupToHtml, plain, entryText, isMilestone, groupLevels, duration, summary, groupByDay, powerOfTwoAtMost, imageName, notesMarkdown, journalMarkdown };
});
