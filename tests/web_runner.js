// node tests/web_runner.js <file.lua>: prints parseLua(file) as JSON (used by test_web.py)
const fs = require("fs");
const core = require(require("path").join(__dirname, "..", "web", "core.js"));
const out = {};
for (const f of process.argv.slice(2)) {
  try { out[f] = { ok: core.parseLua(fs.readFileSync(f)) }; } catch (e) { out[f] = { error: e.message }; }
}
process.stdout.write(JSON.stringify(out));
