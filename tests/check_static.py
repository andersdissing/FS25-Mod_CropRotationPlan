"""Static checks for the mod in Build/: XML is well-formed, Lua parses, l10n keys exist.

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

for f in glob.glob(root + "/**/*.xml", recursive=True):
    try:
        ET.parse(f)
    except Exception as e:
        ok = False
        print("XML FAIL", f, e)

desc = ET.parse(root + "/modDesc.xml").getroot()
keys = {t.get("name") for t in desc.iter("text")}

for t in desc.iter("text"):
    for lang in ("en", "da"):
        if t.find(lang) is None:
            ok = False
            print("MISSING", lang, "for l10n", t.get("name"))

for f in glob.glob(root + "/scripts/*.lua"):
    src = open(f, encoding="utf-8").read()
    try:
        ast.parse(src)
    except Exception as e:
        ok = False
        print("LUA FAIL", f, str(e)[:300])
    for a, b in re.findall(r'\bt\("([^"]+)"\)|getText\("([^"]+)"\)', src):
        key = a or b
        if key not in keys:
            ok = False
            print("MISSING l10n", f, key)

print("OK" if ok else "FAILED")
sys.exit(0 if ok else 1)
