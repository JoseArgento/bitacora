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
    chars.sort((a, b) => (b.journal.length ? b.journal[b.journal.length - 1].t : 0) - (a.journal.length ? a.journal[a.journal.length - 1].t : 0));
    const sections = list(db.sections);
    const notes = Object.values(db.notes && !Array.isArray(db.notes) ? db.notes : {}).map((x) => ({ ...x, images: list(x.images) }));
    const reminders = list(db.reminders);
    return { version: db.version || 0, settings: db.settings || {}, chars, sections, notes, reminders };
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
      start: (e) => `Empezó el diario en nivel ${e.level || 1}, en ${e.zone || "?"}.`,
      level: (e) => `Llegó a nivel ${e.level}.`,
      zone: (e) => `Llegó por primera vez a ${e.name || e.zone}.`,
      boss: (e) => (e.first ? `¡Derrotó a ${e.name} por primera vez!` : `Derrotó a ${e.name}.`),
      death: (e) => `Murió en ${e.zone || "?"}.`,
      quest: (e) => (e.title ? `Completó: ${e.title}.` : `Completó la misión ${e.quest}.`),
      loot: (e) => `Consiguió ${e.link || e.name}.`,
      achievement: (e) => `Logro: ${e.link || e.name}.`,
      money: (e) => `Primera vez con ${Math.floor((e.amount || 0) / 10000)} de oro.`,
      played: (e) => `Tiempo jugado: ${duration(e.total, "es")}.`,
      note: (e) => e.text || "",
    },
    en: {
      start: (e) => `Started the journal at level ${e.level || 1} in ${e.zone || "?"}.`,
      level: (e) => `Reached level ${e.level}.`,
      zone: (e) => `Arrived in ${e.name || e.zone} for the first time.`,
      boss: (e) => (e.first ? `Defeated ${e.name} for the first time!` : `Defeated ${e.name}.`),
      death: (e) => `Died in ${e.zone || "?"}.`,
      quest: (e) => (e.title ? `Completed: ${e.title}.` : `Completed quest ${e.quest}.`),
      loot: (e) => `Got ${e.link || e.name}.`,
      achievement: (e) => `Achievement: ${e.link || e.name}.`,
      money: (e) => `First time with ${Math.floor((e.amount || 0) / 10000)} gold.`,
      played: (e) => `Time played: ${duration(e.total, "en")}.`,
      note: (e) => e.text || "",
    },
  };
  const MILESTONES = new Set(["start", "level", "zone", "boss", "death", "achievement", "loot", "money", "note"]);
  function entryText(e, lang) {
    const f = (TEXT[lang] || TEXT.es)[e.kind];
    return f ? f(e) : e.kind;
  }
  function isMilestone(e) {
    return MILESTONES.has(e.kind) && !(e.kind === "boss" && !e.first);
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
    let bosses = 0, deaths = 0, loot = 0;
    for (const e of c.journal) {
      if (e.kind === "boss") bosses++;
      else if (e.kind === "death") deaths++;
      else if (e.kind === "loot") loot++;
    }
    return { level: c.level, bosses, deaths, loot, zones: c.visited, played: c.played ? c.played.total : null, since: c.journal.length ? c.journal[0].t : c.created };
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

  return { levelSeries, tripStats, searchEntries, LuaError, parseLua, readDB, stampSeconds, shotStamp, matchShots, markupToHtml, plain, entryText, isMilestone, duration, summary, groupByDay, powerOfTwoAtMost, imageName, notesMarkdown, journalMarkdown };
});
