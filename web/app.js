/* Bitácora web: the page's behaviour, shared by every skin (page.html, tavern.html). Needs core.js. */
(function () {
  "use strict";
  const C = BitacoraCore;
  const T = {
    es: {
      tagline: "El diario de a bordo de tus personajes de WoW Forever: lo que anotó el addon Bitácora, tus capturas y tu libreta, para leer fuera del juego.",
      openWhere: "Abrí el archivo que el addon guarda al salir del juego, dentro de la carpeta de Forever:",
      account: "TU_CUENTA",
      openFile: "Abrir Bitacora.lua",
      loadDemo: "Ver el ejemplo",
      demoNotice: "<strong>Ejemplo.</strong> Son datos de prueba que generó el addon. Abrí tu archivo para ver los tuyos.",
      fileNotice: (n) => `Abierto: ${n}.`,
      readError: "No se pudo leer el archivo",
      tabJournal: "Diario", tabAlbum: "Álbum", tabNotes: "Libreta", tabImages: "Imágenes",
      privacy: "Todo se lee dentro de esta página: el archivo y las capturas no salen de tu compu ni se suben a ningún lado.",
      level: "Nivel", played: "jugado", bosses: (n) => `${n} jefe${n === 1 ? "" : "s"}`, deaths: (n) => `${n} muerte${n === 1 ? "" : "s"}`,
      zones: (n) => `${n} zona${n === 1 ? "" : "s"}`, loot: (n) => `${n} botín`, since: "desde",
      milestones: "Hitos", all: "Todo",
      copyJournal: "Copiar el diario", copied: "Copiado", copyFail: "No se pudo copiar: seleccioná el texto",
      colHour: "Hora", colLevel: "Nv.", colEntry: "Anotación", colPlace: "Lugar",
      kinds: { start: "inicio", level: "nivel", zone: "zona", boss: "jefe", death: "muerte", quest: "misión", loot: "botín", achievement: "logro", money: "oro", played: "tiempo", note: "nota" },
      journalEmpty: "Todavía no hay nada anotado para este personaje.",
      noMatches: "Nada coincide con la búsqueda.",
      searchJournal: "Buscar en el diario",
      levelChart: "Niveles en el tiempo",
      hoursLater: (h) => `${h} h después`,
      tripBosses: "Jefes", tripDeaths: "Dónde más moriste", tripLoot: "Botín",
      dropShots: "Soltá acá tus capturas (la carpeta Screenshots del juego) o elegilas. Las juntamos con lo que anotó el addon por la hora del nombre del archivo.",
      chooseShots: "Elegir capturas",
      missing: (f) => `${f}`,
      missingHint: "falta la foto",
      with: (names) => `con ${names}`,
      looseTitle: (n) => `${n} captura${n === 1 ? "" : "s"} sin anotación`,
      albumEmpty: "Este personaje no tiene capturas anotadas. En el juego, sacá una con Impr Pant.",
      search: "Buscar en la libreta",
      allSections: "Todas",
      pinned: "Fijada",
      attached: (x) => `Pegada a ${x}`,
      onlyChar: (x) => `Solo ${x}`,
      notesEmpty: "No hay notas que coincidan.",
      copyNotes: "Copiar como Markdown",
      reminders: "Recordatorios",
      rKinds: { zone: (v) => `al entrar a ${v}`, level: (v) => `al llegar a nivel ${v}`, login: () => "al entrar al juego", place: (v) => `al abrir ${({ MAIL: "el correo", BANK: "el banco", MERCHANT: "un vendedor", AUCTION: "la subasta" })[v] || v}`, time: (v) => `${v.wday ? ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"][v.wday - 1] : "todos los días"} ${String(v.hour).padStart(2, "0")}:${String(v.min).padStart(2, "0")}` },
      repeats: "se repite", done: "hecho",
      prepTitle: "Preparar una imagen para la libreta",
      prepIntro: "El juego solo muestra imágenes con lados potencia de 2 (64, 128, 256…). Elegí una imagen y la dejamos lista.",
      pick: "Imagen", size: "Tamaño", fit: "Ajuste", name: "Nombre del archivo",
      fitPad: "Entera, con márgenes transparentes", fitCrop: "Recortada para llenar", fitStretch: "Estirada",
      save: "Guardar PNG", saveHint: "Si tu navegador no guarda el archivo, hacé clic derecho en la imagen y elegí «Guardar imagen como».",
      saved: "Guardado.", saveDeclined: "No se guardó.",
      stepsTitle: "Después:",
      step1: (f) => `Guardala en <code>Interface\\AddOns\\BitacoraImagenes\\${f}</code> (creá la carpeta la primera vez; fuera de la carpeta del addon, así las actualizaciones no la borran).`,
      step2: "En el juego escribí <code>/reload</code>.",
      step3: (f) => `En la nota, «Agregar imagen» y escribí <code>${f}</code>.`,
      prepEmpty: "Elegí una imagen para ver cómo queda.",
    },
    en: {
      tagline: "The logbook of your WoW Forever characters: what the Bitácora addon wrote down, your screenshots and your notebook, to read outside the game.",
      openWhere: "Open the file the addon saves when you leave the game, inside the Forever folder:",
      account: "YOUR_ACCOUNT",
      openFile: "Open Bitacora.lua",
      loadDemo: "See the example",
      demoNotice: "<strong>Example.</strong> Test data made by the addon. Open your file to see yours.",
      fileNotice: (n) => `Opened: ${n}.`,
      readError: "The file could not be read",
      tabJournal: "Journal", tabAlbum: "Album", tabNotes: "Notebook", tabImages: "Images",
      privacy: "Everything is read inside this page: the file and the screenshots never leave your computer and are not uploaded anywhere.",
      level: "Level", played: "played", bosses: (n) => `${n} boss${n === 1 ? "" : "es"}`, deaths: (n) => `${n} death${n === 1 ? "" : "s"}`,
      zones: (n) => `${n} zone${n === 1 ? "" : "s"}`, loot: (n) => `${n} loot`, since: "since",
      milestones: "Milestones", all: "All",
      copyJournal: "Copy the journal", copied: "Copied", copyFail: "Could not copy: select the text",
      colHour: "Time", colLevel: "Lv.", colEntry: "Entry", colPlace: "Place",
      kinds: { start: "start", level: "level", zone: "zone", boss: "boss", death: "death", quest: "quest", loot: "loot", achievement: "achievement", money: "gold", played: "played", note: "note" },
      journalEmpty: "Nothing written down for this character yet.",
      noMatches: "Nothing matches the search.",
      searchJournal: "Search the journal",
      levelChart: "Levels over time",
      hoursLater: (h) => `${h} h later`,
      tripBosses: "Bosses", tripDeaths: "Where you died most", tripLoot: "Loot",
      dropShots: "Drop your screenshots here (the game's Screenshots folder) or pick them. They are matched to the addon's notes by the time in the file name.",
      chooseShots: "Choose screenshots",
      missing: (f) => `${f}`,
      missingHint: "photo missing",
      with: (names) => `with ${names}`,
      looseTitle: (n) => `${n} screenshot${n === 1 ? "" : "s"} without a note`,
      albumEmpty: "This character has no noted screenshots. In the game, take one with Print Screen.",
      search: "Search the notebook",
      allSections: "All",
      pinned: "Pinned",
      attached: (x) => `Attached to ${x}`,
      onlyChar: (x) => `Only ${x}`,
      notesEmpty: "No notes match.",
      copyNotes: "Copy as Markdown",
      reminders: "Reminders",
      rKinds: { zone: (v) => `when entering ${v}`, level: (v) => `at level ${v}`, login: () => "when logging in", place: (v) => `when opening ${({ MAIL: "the mailbox", BANK: "the bank", MERCHANT: "a vendor", AUCTION: "the auction house" })[v] || v}`, time: (v) => `${v.wday ? ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][v.wday - 1] : "every day"} ${String(v.hour).padStart(2, "0")}:${String(v.min).padStart(2, "0")}` },
      repeats: "repeats", done: "done",
      prepTitle: "Prepare an image for the notebook",
      prepIntro: "The game only shows images whose sides are a power of 2 (64, 128, 256…). Pick an image and we get it ready.",
      pick: "Image", size: "Size", fit: "Fit", name: "File name",
      fitPad: "Whole, with transparent margins", fitCrop: "Cropped to fill", fitStretch: "Stretched",
      save: "Save PNG", saveHint: "If your browser does not save the file, right-click the image and choose “Save image as”.",
      saved: "Saved.", saveDeclined: "Not saved.",
      stepsTitle: "Then:",
      step1: (f) => `Save it as <code>Interface\\AddOns\\BitacoraImagenes\\${f}</code> (create the folder the first time; it is outside the addon's folder so updates do not delete it).`,
      step2: "In the game, type <code>/reload</code>.",
      step3: (f) => `In the note, “Add image” and type <code>${f}</code>.`,
      prepEmpty: "Pick an image to see how it turns out.",
    },
  };

  // A page skin (the tavern page) can replace some texts: window.BITACORA_SKIN_TEXTS = { es: {...}, en: {...} }
  const skinTexts = (typeof window !== "undefined" && window.BITACORA_SKIN_TEXTS) || {};
  for (const l of Object.keys(T)) Object.assign(T[l], skinTexts[l] || {});

  let lang = "es";
  try { const s = localStorage.getItem("bitacora-lang"); if (s === "es" || s === "en") lang = s; } catch (e) {}
  const state = { db: null, demo: true, char: null, filter: "milestones", section: null, query: "", shots: [], urls: [], prep: { file: null, img: null, size: 256, fit: "pad", name: "imagen.png" } };
  const $ = (s) => document.querySelector(s);
  const el = (tag, attrs, ...kids) => {
    const n = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (k === "class") n.className = v;
      else if (k === "text") n.textContent = v;
      else if (k === "html") n.innerHTML = v;
      else if (k.startsWith("on")) n.addEventListener(k.slice(2), v);
      else if (v !== false && v != null) n.setAttribute(k, v === true ? "" : v);
    }
    for (const k of kids.flat()) if (k != null && k !== false) n.append(k);
    return n;
  };
  const L = () => T[lang];
  const put = (node, ...kids) => node.replaceChildren(...kids.flat().filter((k) => k != null && k !== false));
  const fmtDay = (day) => {
    const [y, m, d] = day.split("-").map(Number);
    if (!y) return day;
    return new Date(Date.UTC(y, m - 1, d, 12)).toLocaleDateString(lang === "es" ? "es-AR" : "en-US", { weekday: "long", day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
  };
  const fmtDate = (epoch) => (epoch ? new Date(epoch * 1000).toLocaleDateString(lang === "es" ? "es-AR" : "en-US", { day: "numeric", month: "short", year: "numeric" }) : "");

  // ------------------------------------------------------------ loading
  function load(text, name, demo) {
    try {
      state.db = C.readDB(text);
    } catch (err) {
      $("#status").replaceChildren(el("span", { class: "error", text: `${L().readError}: ${err.message}` }));
      return;
    }
    state.demo = demo;
    state.name = name;
    if (!state.db.chars.some((c) => c.key === state.char)) state.char = state.db.chars.length ? state.db.chars[0].key : null;
    render();
  }
  $("#dbfile").addEventListener("change", async (e) => {
    const f = e.target.files[0];
    if (f) load(new Uint8Array(await f.arrayBuffer()), f.name, false);
    e.target.value = "";
  });
  $("#demo").addEventListener("click", () => load(BITACORA_DEMO, "BitacoraDB.lua", true));

  function current() {
    return state.db && state.db.chars.find((c) => c.key === state.char);
  }

  // ------------------------------------------------------------ header parts
  function renderHeader() {
    document.documentElement.lang = lang;
    document.querySelectorAll("[data-t]").forEach((n) => { const v = L()[n.dataset.t]; if (typeof v === "string") n.textContent = v; });
    document.querySelectorAll(".lang button").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.lang === lang)));
    $("#status").innerHTML = state.demo ? L().demoNotice : "";
    if (!state.demo && state.name) $("#status").textContent = L().fileNotice(state.name);
    const crew = $("#crew");
    crew.replaceChildren(...(state.db ? state.db.chars : []).map((c) =>
      el("button", { type: "button", "aria-pressed": String(c.key === state.char), "data-class": (c.class || "").toLowerCase(), onclick: () => { state.char = c.key; render(); } },
        el("b", { text: c.name }),
        el("span", { text: `${c.realm} · ${L().level} ${c.level || "?"}` }))));
    const c = current();
    const p = $("#particulars");
    if (!c) { p.replaceChildren(); return; }
    const s = C.summary(c);
    const item = (label, value) => el("li", {}, label ? label + " " : "", el("b", { text: value }));
    // replaceChildren would print a null as the word "null": only real nodes go in
    put(p,
      item(L().level, String(s.level || "?")),
      s.played != null ? el("li", {}, el("b", { text: C.duration(s.played, lang) }), " " + L().played) : null,
      el("li", { text: L().bosses(s.bosses) }),
      el("li", { text: L().deaths(s.deaths) }),
      el("li", { text: L().zones(s.zones) }),
      s.since ? item(L().since, fmtDate(s.since)) : null);
  }

  // ------------------------------------------------------------ journal
  function renderJournal() {
    const c = current();
    const root = el("div", { class: "journal" });
    const copy = el("button", { type: "button", class: "btn quiet", text: L().copyJournal, onclick: () => copyText(C.journalMarkdown(c, lang), copy, L().copyJournal) });
    const search = el("input", { type: "search", id: "jq", placeholder: L().searchJournal, "aria-label": L().searchJournal, value: state.jquery || "" });
    root.append(el("div", { class: "bar" },
      el("div", { class: "copy-row" },
        el("div", { class: "seg", role: "group" },
          el("button", { type: "button", "aria-pressed": String(state.filter === "milestones"), text: L().milestones, onclick: () => { state.filter = "milestones"; render(); } }),
          el("button", { type: "button", "aria-pressed": String(state.filter === "all"), text: L().all, onclick: () => { state.filter = "all"; render(); } })),
        search),
      c ? copy : null));
    if (c) {
      const chart = levelChart(c);
      const trip = tripSummary(c);
      if (chart || trip) root.append(el("div", { class: "overview" }, chart, trip));
    }
    const holder = el("div");
    root.append(holder);
    function draw() {
      const all = c ? c.journal.filter((e) => state.filter === "all" || C.isMilestone(e)) : [];
      const entries = C.searchEntries(all, state.jquery, lang);
      if (!entries.length) {
        put(holder, el("p", { class: "empty", text: all.length ? L().noMatches : L().journalEmpty }));
        return;
      }
      put(holder, C.groupByDay(entries).reverse().map((g) => {
        const rows = g.entries.slice().reverse().map((e) =>
          el("tr", { class: e.kind === "note" ? "note" : "" },
            el("td", { class: "t", text: (e.d || "").slice(11, 16) }),
            el("td", { class: "lv", text: e.level != null ? String(e.level) : "" }),
            el("td", { class: "entry" }, el("span", { class: `kind k-${e.kind}`, text: L().kinds[e.kind] || e.kind }), el("span", { html: C.markupToHtml(C.entryText(e, lang)) }),
              el("span", { class: "inline-place", text: [e.sub, e.zone].filter(Boolean).join(", ") })),
            el("td", { class: "place", text: [e.sub, e.zone].filter(Boolean).join(", ") })));
        return el("section", { class: "day" },
          el("h2", {}, fmtDay(g.day), el("small", { text: g.day })),
          el("div", { class: "ledger-wrap" }, el("table", { class: "ledger" },
            el("thead", {}, el("tr", {}, el("th", { text: L().colHour }), el("th", { text: L().colLevel }), el("th", { text: L().colEntry }), el("th", { class: "place", text: L().colPlace }))),
            el("tbody", {}, rows))));
      }));
    }
    search.addEventListener("input", () => { state.jquery = search.value; draw(); });
    draw();
    return root;
  }

  // Level over time, drawn to scale: x = days since the journal started, y = level. One series, so no legend.
  function levelChart(c) {
    const pts = C.levelSeries(c);
    if (pts.length < 2) return null;
    const W = 640, H = 170, padL = 34, padR = 14, padT = 12, padB = 26;
    const t0 = pts[0].t, t1 = Math.max(pts[pts.length - 1].t, t0 + 3600);
    const maxLevel = Math.max(10, Math.ceil(pts[pts.length - 1].level / 10) * 10);
    const x = (t) => padL + ((t - t0) / (t1 - t0)) * (W - padL - padR);
    const y = (lv) => padT + (1 - (lv - 1) / (maxLevel - 1)) * (H - padT - padB);
    const ns = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(ns, "svg");
    svg.setAttribute("viewBox", `0 0 ${W} ${H}`);
    svg.setAttribute("class", "levels");
    svg.setAttribute("role", "img");
    svg.setAttribute("aria-label", L().levelChart);
    const add = (tag, attrs, text) => {
      const n = document.createElementNS(ns, tag);
      for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v);
      if (text != null) n.textContent = text;
      svg.append(n);
      return n;
    };
    const step = maxLevel <= 20 ? 5 : 10;
    for (let lv = step; lv <= maxLevel; lv += step) {
      add("line", { x1: padL, x2: W - padR, y1: y(lv), y2: y(lv), class: "grid" });
      add("text", { x: padL - 6, y: y(lv) + 4, class: "tick", "text-anchor": "end" }, String(lv));
    }
    add("text", { x: padL - 6, y: y(1) + 4, class: "tick", "text-anchor": "end" }, "1");
    add("line", { x1: padL, x2: W - padR, y1: y(1), y2: y(1), class: "axis" });
    const days = (t1 - t0) / 86400;
    add("text", { x: padL, y: H - 6, class: "tick" }, fmtDate(t0));
    add("text", { x: W - padR, y: H - 6, class: "tick", "text-anchor": "end" }, days >= 1 ? fmtDate(t1) : L().hoursLater(Math.round((t1 - t0) / 3600)));
    let d = `M${x(pts[0].t)},${y(pts[0].level)}`;
    for (let i = 1; i < pts.length; i++) d += ` H${x(pts[i].t)} V${y(pts[i].level)}`;
    add("path", { d, class: "line" });
    pts.forEach((p, i) => {
      const dot = add("circle", { cx: x(p.t), cy: y(p.level), r: i === pts.length - 1 ? 5 : 3.5, class: i === pts.length - 1 ? "dot end" : "dot" });
      const tip = document.createElementNS(ns, "title");
      tip.textContent = `${L().level} ${p.level} · ${p.d || ""}`;
      dot.append(tip);
    });
    const last = pts[pts.length - 1];
    add("text", { x: Math.min(x(last.t), W - padR) - 8, y: y(last.level) - 9, class: "endlabel", "text-anchor": "end" }, `${L().level} ${last.level}`);
    return el("figure", { class: "chart" }, el("figcaption", { class: "chart-title", text: L().levelChart }), svg);
  }

  function tripSummary(c) {
    const s = C.tripStats(c);
    if (!s.deaths.length && !s.bosses.length && !s.loot.length) return null;
    const block = (title, items) => (items.length ? el("div", {}, el("h3", { text: title }), el("ul", {}, items)) : null);
    return el("div", { class: "trip" },
      block(L().tripBosses, s.bosses.map((b) => el("li", {}, el("span", { text: b.name }), el("span", { class: "n", text: b.count > 1 ? `×${b.count}` : (b.first || "").slice(0, 10) })))),
      block(L().tripDeaths, s.deaths.slice(0, 5).map((d) => el("li", {}, el("span", { text: d.zone }), el("span", { class: "n", text: `×${d.count}` })))),
      block(L().tripLoot, s.loot.slice(-5).reverse().map((l) => el("li", {}, el("span", { html: C.markupToHtml(l.link) }), el("span", { class: "n", text: (l.d || "").slice(0, 10) })))));
  }

  // ------------------------------------------------------------ album
  function renderAlbum() {
    const c = current();
    const root = el("div", { class: "album", style: "display:grid;gap:22px" });
    const input = el("input", { type: "file", id: "shots", accept: "image/*", multiple: true, onchange: (e) => { addShots(e.target.files); e.target.value = ""; } });
    const drop = el("div", { class: "drop" },
      el("p", { text: L().dropShots }),
      el("label", { class: "btn quiet", for: "shots" }, L().chooseShots, input));
    ["dragenter", "dragover"].forEach((t) => drop.addEventListener(t, (e) => { e.preventDefault(); drop.classList.add("over"); }));
    ["dragleave", "drop"].forEach((t) => drop.addEventListener(t, (e) => { e.preventDefault(); drop.classList.remove("over"); }));
    drop.addEventListener("drop", (e) => addShots(e.dataTransfer.files));
    root.append(drop);
    const album = c ? c.album.slice().reverse() : [];
    if (!album.length) {
      root.append(el("p", { class: "empty", text: L().albumEmpty }));
    }
    const { pairs, loose } = C.matchShots(album, state.shots);
    if (album.length) {
      root.append(el("div", { class: "plates" }, pairs.map(({ entry, file }) => {
        const fname = `WoWScrnShot_${entry.stamp}.jpg`;
        const photo = file
          ? el("div", { class: "photo" }, el("img", { src: urlFor(file), alt: entry.caption || entry.zone || "" }))
          : el("div", { class: "photo missing" }, el("span", {}, fname, el("br"), L().missingHint));
        const where = [entry.sub, entry.zone].filter(Boolean).join(", ");
        const bits = [entry.d, where, entry.group.length ? L().with(entry.group.join(", ")) : null, entry.level ? `${L().level} ${entry.level}` : null];
        return el("figure", { class: "plate" }, photo,
          el("figcaption", {},
            entry.caption ? el("span", { class: "cap", text: entry.caption }) : null,
            el("span", { class: "meta", text: bits.filter(Boolean).join(" · ") })));
      })));
    }
    if (loose.length) {
      root.append(el("h2", { class: "day", style: "font:400 24px var(--display);margin:6px 0 0", text: L().looseTitle(loose.length) }));
      root.append(el("div", { class: "plates" }, loose.map((f) =>
        el("figure", { class: "plate" }, el("div", { class: "photo" }, el("img", { src: urlFor(f), alt: f.name })),
          el("figcaption", {}, el("span", { class: "meta", text: f.name }))))));
    }
    return root;
  }
  function addShots(list) {
    const files = Array.from(list || []).filter((f) => /^image\//.test(f.type) || /\.(jpe?g|png|tga)$/i.test(f.name));
    const known = new Set(state.shots.map((f) => f.name + f.size));
    for (const f of files) if (!known.has(f.name + f.size)) state.shots.push(f);
    render();
  }
  const urlCache = new Map();
  function urlFor(file) {
    if (!urlCache.has(file)) urlCache.set(file, URL.createObjectURL(file));
    return urlCache.get(file);
  }

  // ------------------------------------------------------------ notebook
  function renderNotes() {
    const db = state.db;
    const root = el("div", { style: "display:grid;gap:18px" });
    const search = el("input", { type: "search", id: "q", placeholder: L().search, "aria-label": L().search, value: state.query });
    search.addEventListener("input", () => { state.query = search.value; drawNotes(); });
    const copy = el("button", { type: "button", class: "btn quiet", text: L().copyNotes, onclick: () => copyText(C.notesMarkdown(db, lang), copy, L().copyNotes) });
    const chips = el("div", { class: "chips", role: "group" },
      el("button", { type: "button", "aria-pressed": String(state.section == null), text: L().allSections, onclick: () => { state.section = null; render(); } }),
      db.sections.map((s) => el("button", { type: "button", "aria-pressed": String(state.section === s.id), text: s.name, onclick: () => { state.section = s.id; render(); } })));
    root.append(el("div", { class: "bar" }, chips, el("div", { class: "copy-row" }, search, copy)));
    const holder = el("div");
    root.append(holder);
    function drawNotes() {
      const words = state.query.toLowerCase().split(/\s+/).filter(Boolean);
      const c = current();
      const notes = db.notes
        .filter((n) => state.section == null || n.section === state.section)
        .filter((n) => !n.char || !c || n.char === c.key)
        .filter((n) => { const hay = C.plain(`${n.title || ""}\n${n.body || ""}\n${n.attach ? n.attach.label || "" : ""}`).toLowerCase(); return words.every((w) => hay.includes(w)); })
        .sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0) || (b.updated || 0) - (a.updated || 0));
      if (!notes.length) { holder.replaceChildren(el("p", { class: "empty", text: L().notesEmpty })); return; }
      holder.replaceChildren(el("div", { class: "notes" }, notes.map((n) => {
        const meta = [n.attach ? L().attached(n.attach.label || n.attach.key) : null, n.char ? L().onlyChar(n.char) : null, fmtDate(n.updated)].filter(Boolean).join(" · ");
        return el("article", { class: "note" },
          n.pinned ? el("span", { class: "pin", text: L().pinned }) : null,
          el("h3", { text: n.title || C.plain(n.body).split("\n")[0] || "—" }),
          n.body ? el("p", { class: "body", html: C.markupToHtml(n.body) }) : null,
          n.images.length ? el("ul", { class: "files" }, n.images.map((f) => el("li", { text: f }))) : null,
          el("span", { class: "meta", text: meta }));
      })));
    }
    drawNotes();
    const c = current();
    const rem = db.reminders.filter((r) => !r.char || !c || r.char === c.key);
    if (rem.length) {
      root.append(el("section", { class: "reminders" }, el("h2", { text: L().reminders }),
        el("ul", {}, rem.map((r) => {
          const f = L().rKinds[r.kind];
          const when = f ? f(r.value || "") : r.kind;
          return el("li", { class: r.done ? "done" : "" }, el("b", { text: r.text, style: "font-weight:400" }),
            el("span", { text: [when, r.repeating ? L().repeats : null, r.done ? L().done : null, r.char].filter(Boolean).join(" · ") }));
        }))));
    }
    return root;
  }

  // ------------------------------------------------------------ images
  function renderImages() {
    const P = state.prep;
    const root = el("div", { class: "prep" });
    const canvas = el("canvas", { id: "prepcanvas", width: P.size, height: P.size });
    const sizes = [64, 128, 256, 512, 1024];
    const nameInput = el("input", { type: "text", id: "imgname", value: P.name, spellcheck: "false" });
    const status = el("p", { class: "notice", role: "status" });
    const steps = el("ol", { class: "steps" });
    const form = el("form", { onsubmit: (e) => e.preventDefault() },
      el("h2", { style: "font:400 26px/1.2 var(--display);margin:0", text: L().prepTitle }),
      el("p", { class: "notice", text: L().prepIntro }),
      el("label", {}, L().pick, el("input", { type: "file", id: "imgfile", accept: "image/*", onchange: async (e) => {
        const f = e.target.files[0];
        if (!f) return;
        P.file = f;
        P.img = await loadImage(f);
        P.name = C.imageName(f.name);
        nameInput.value = P.name;
        draw();
      } })),
      el("label", {}, L().size, el("select", { id: "imgsize", onchange: (e) => { P.size = Number(e.target.value); draw(); } },
        sizes.map((s) => el("option", { value: s, selected: s === P.size }, `${s} × ${s}`)))),
      el("label", {}, L().fit, el("select", { id: "imgfit", onchange: (e) => { P.fit = e.target.value; draw(); } },
        [["pad", L().fitPad], ["crop", L().fitCrop], ["stretch", L().fitStretch]].map(([v, t]) => el("option", { value: v, selected: v === P.fit }, t)))),
      el("label", {}, L().name, nameInput),
      el("div", { class: "copy-row" }, el("button", { type: "button", class: "btn", id: "savepng", text: L().save, onclick: savePng }), status),
      el("p", { class: "notice", text: L().saveHint }),
      el("div", {}, el("strong", { text: L().stepsTitle }), steps));
    nameInput.addEventListener("change", () => { P.name = C.imageName(nameInput.value); nameInput.value = P.name; draw(); });
    const preview = el("div", { class: "canvas-wrap" }, P.img ? canvas : el("p", { class: "empty", text: L().prepEmpty }));
    root.append(form, preview);
    function draw() {
      steps.replaceChildren(el("li", { html: L().step1(P.name) }), el("li", { html: L().step2 }), el("li", { html: L().step3(P.name) }));
      if (!P.img) return;
      preview.replaceChildren(canvas);
      canvas.width = canvas.height = P.size;
      const ctx = canvas.getContext("2d");
      ctx.clearRect(0, 0, P.size, P.size);
      const w = P.img.naturalWidth, h = P.img.naturalHeight;
      if (P.fit === "stretch") ctx.drawImage(P.img, 0, 0, P.size, P.size);
      else {
        const scale = P.fit === "pad" ? Math.min(P.size / w, P.size / h) : Math.max(P.size / w, P.size / h);
        const dw = w * scale, dh = h * scale;
        ctx.imageSmoothingQuality = "high";
        ctx.drawImage(P.img, (P.size - dw) / 2, (P.size - dh) / 2, dw, dh);
      }
    }
    async function savePng() {
      if (!P.img) return;
      const blob = await new Promise((res) => canvas.toBlob(res, "image/png"));
      try {
        const done = await saveFile(P.name, blob);
        status.textContent = done ? L().saved : "";
      } catch (e) {
        status.textContent = L().saveDeclined;
      }
    }
    draw();
    return root;
  }
  function loadImage(file) {
    return new Promise((res, rej) => { const img = new Image(); img.onload = () => res(img); img.onerror = rej; img.src = urlFor(file); });
  }

  // Inside claude.ai the page offers files through the viewer's "downloads" capability; as a plain local
  // file it uses a normal download link.
  async function saveFile(filename, blob) {
    if (window.claude && window.claude.use) {
      const dl = await window.claude.use("downloads");
      if (!dl) return false;
      await dl.save({ filename, data: blob });
      return true;
    }
    const a = el("a", { href: URL.createObjectURL(blob), download: filename });
    document.body.append(a);
    a.click();
    a.remove();
    return true;
  }
  async function copyText(text, button, label) {
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = L().copied;
    } catch (e) {
      button.textContent = L().copyFail;
      const area = el("textarea", { style: "width:100%;min-height:200px;font:13px var(--mono)", readonly: true }, text);
      button.closest(".bar, .journal, div").after(area);
      area.select();
    }
    setTimeout(() => { button.textContent = label; }, 2000);
  }

  // ------------------------------------------------------------ routing
  const VIEWS = { diario: renderJournal, album: renderAlbum, libreta: renderNotes, imagenes: renderImages };
  function viewName() {
    const h = location.hash.replace("#", "");
    return VIEWS[h] ? h : "diario";
  }
  function render() {
    renderHeader();
    const name = viewName();
    document.querySelectorAll(".tabs a").forEach((a) => a.setAttribute("aria-current", a.dataset.view === name ? "page" : "false"));
    $("#view").replaceChildren(state.db || name === "imagenes" ? VIEWS[name]() : el("p", { class: "empty" }));
  }
  window.addEventListener("hashchange", render);
  document.querySelectorAll(".lang button").forEach((b) => b.addEventListener("click", () => {
    lang = b.dataset.lang;
    try { localStorage.setItem("bitacora-lang", lang); } catch (e) {}
    render();
  }));

  load(BITACORA_DEMO, "BitacoraDB.lua", true);
})();
