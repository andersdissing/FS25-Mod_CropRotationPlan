"""Static checks for the mod in Build/:
- XML is well-formed
- Lua parses, and uses nothing newer than Lua 5.1 (the game's Lua): no goto, no //, no table.unpack
- every l10n key used in Lua exists in modDesc.xml, with en and da
- en and da texts have the same format placeholders (%d, %s) in the same order

Usage: python tests/check_static.py [mod_dir]      (default: Build)
Needs: pip install luaparser
"""
import glob
import re
import sys
import xml.etree.ElementTree as ET

from luaparser import ast

root = sys.argv[1] if len(sys.argv) > 1 else "Build"
ok = True


def fail(*args):
    global ok
    ok = False
    print(*args)


for f in glob.glob(root + "/**/*.xml", recursive=True):
    try:
        ET.parse(f)
    except Exception as e:
        fail("XML FAIL", f, e)

desc = ET.parse(root + "/modDesc.xml").getroot()
texts = {t.get("name"): t for t in desc.iter("text")}
# Base game keys the mod uses
BASE_KEYS = {"button_ok"}
# Key prefixes built at runtime: prefix + value
PREFIXES = ("crp_month_", "crp_action_", "crp_display_", "crp_position_")

placeholder = re.compile(r"%[ds]")
for name, t in texts.items():
    en, da = t.find("en"), t.find("da")
    if en is None or da is None:
        fail("MISSING en/da for l10n", name)
        continue
    if placeholder.findall(en.text or "") != placeholder.findall(da.text or ""):
        fail("PLACEHOLDERS differ en/da", name, placeholder.findall(en.text or ""), placeholder.findall(da.text or ""))

used = set()
for f in glob.glob(root + "/scripts/*.lua"):
    src = open(f, encoding="utf-8").read()
    try:
        ast.parse(src)
    except Exception as e:
        fail("LUA FAIL", f, str(e)[:300])
    code = re.sub(r"--[^\n]*", "", src)
    for pattern, what in ((r"\bgoto\b", "goto"), (r"//", "integer division //"), (r"table\.unpack", "table.unpack")):
        if re.search(pattern, code):
            fail("LUA 5.1", f, "uses", what)
    for key in re.findall(r'\b(?:t|tf|getText)\("([A-Za-z_]+)"', src):
        used.add((f, key))
    for key in re.findall(r'"(crp_[A-Za-z_]+)"', src):
        used.add((f, key))

for f, key in sorted(used):
    if key in texts or key in BASE_KEYS or key in PREFIXES:
        continue
    fail("MISSING l10n", f, key)

for prefix in PREFIXES:
    if not any(name.startswith(prefix) for name in texts):
        fail("MISSING l10n prefix", prefix)

print("OK" if ok else "FAILED")
sys.exit(0 if ok else 1)
