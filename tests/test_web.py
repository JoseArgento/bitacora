"""The web page's Lua reader (web/core.js) against real Lua: what Lua 5.1 loads, core.js must read the same."""

import json
import shutil
import subprocess
from pathlib import Path

import pytest

lupa = pytest.importorskip("lupa.lua51")
pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="node is not installed")

ROOT = Path(__file__).resolve().parents[1]
FIX = Path(__file__).parent / "fixtures"


def node(*files):
    proc = subprocess.run(["node", str(ROOT / "tests" / "web_runner.js"), *map(str, files)], capture_output=True, text=True, check=True)
    return json.loads(proc.stdout)


def lua_to_js(v):
    """Same rule as core.js toJs: a 1..n sequence is a list, anything else an object with string keys."""
    if lupa.lua_type(v) == "table":
        items = list(v.items())
        keys = [k for k, _ in items]
        if items and keys == list(range(1, len(items) + 1)):
            return [lua_to_js(x) for _, x in items]
        if not items:
            return []
        out = {}
        for k, x in items:
            if isinstance(k, bool):
                k = "true" if k else "false"
            elif isinstance(k, float) and k.is_integer():
                k = str(int(k))
            out[k if isinstance(k, str) else (k.decode() if isinstance(k, bytes) else str(k))] = lua_to_js(x)
        return out
    if isinstance(v, bytes):
        return v.decode("utf-8", "replace")
    if isinstance(v, float) and v.is_integer():
        return int(v)
    return v


def lua_load(text):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    env = lua.eval("function(src) local env = {} local f = assert(loadstring(src)) setfenv(f, env) f() return env end")(text)
    return {k.decode() if isinstance(k, bytes) else k: lua_to_js(v) for k, v in env.items()}


TRICKY = r"""
-- a comment
--[==[ a long
comment ]==]
T = {
  "a\tb\n\"q\"\\", 'single \'', [[long
string]], [==[with ]] inside]==],
  "\065\066\067 caf\195\169", "line\
break",
  1, -2, 3.5, -0.25, 1e3, 0x1F, -0x10,
  true, false, nil, 7,
  ["key with spaces"] = { [1] = "x", [2] = "y" },
  [10] = "ten", [true] = "yes", plain = "p";
  nested = { { {} } },
}
U = "ü"
"""


def test_reads_the_demo_saved_variables_like_lua():
    f = FIX / "BitacoraDB.lua"
    got = node(f)[str(f)]
    assert "ok" in got, got
    assert got["ok"] == lua_load(f.read_text(encoding="utf-8"))


def test_reads_tricky_literals_like_lua(tmp_path):
    f = tmp_path / "t.lua"
    f.write_text(TRICKY, encoding="utf-8")
    got = node(f)[str(f)]
    assert "ok" in got, got
    assert got["ok"] == lua_load(TRICKY)


@pytest.mark.parametrize("bad", ['T = { "unclosed }', "T = { 1 2 }", "T = ", "= {}", 'T = "a\\q"'])
def test_bad_files_give_an_error_not_a_crash(tmp_path, bad):
    f = tmp_path / "bad.lua"
    f.write_text(bad, encoding="utf-8")
    assert "error" in node(f)[str(f)]


def test_core_units():
    out = subprocess.run(["node", str(ROOT / "tests" / "web_unit.js")], capture_output=True, text=True)
    assert out.returncode == 0 and out.stdout == "ok", out.stderr
