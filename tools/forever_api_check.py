#!/usr/bin/env python3
"""Appels à des fonctions absentes du client de WoW Forever, sans solution de repli.

Liste de référence : tests/data/forever_api.json, relevé de l'API du client Forever (6 045 fonctions globales,
269 espaces de noms C_*) fait par Thunderz, https://github.com/Thunderz96/forever-addon-kit (MIT), build 1.60.1.69893.

Pour chaque fichier Lua, chaque appel « Nom( » ou « C_Espace.Fonction( » vers une fonction que ce client n'a pas est
signalé, sauf s'il est protégé dans le même fichier : test de présence (« Nom and », « if Nom », « not Nom »,
« Nom then »), repli (« or Nom », « (C_X and C_X.Nom) or Nom »), fonction définie par l'addon, ou appel sous pcall.

Signale aussi les fonctions présentes mais interdites aux addons (ReloadUI), sauf protection explicite.

Usage : python3 tools/forever_api_check.py [dossiers…]   (par défaut ForeverPretre ForeverGazette ForeverGFX ForeverMacros)
Code de sortie 1 s'il reste un appel non protégé.
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = os.path.join(ROOT, "tests", "data", "forever_api.json")

# Fonctions du langage Lua et de la bibliothèque de WoW absentes du relevé (qui ne liste que l'API du jeu)
LUA = set("""assert error ipairs pairs next pcall xpcall select type tostring tonumber setmetatable getmetatable rawget rawset
rawequal unpack require loadstring load print date time wipe tinsert tremove strsplit strjoin strtrim strlower strupper
format floor ceil abs max min sqrt random gsub gmatch sort concat collectgarbage dofile loadfile""".split())

CALL = re.compile(r"(?<![\w.:])((?:C_\w+\.)?[A-Z]\w*)\s*\(")
DEF = re.compile(r"(?:local\s+function\s+|function\s+|local\s+)([A-Z]\w*)\b")


def load_api() -> tuple[set, dict]:
    with open(API, encoding="utf-8") as f:
        d = json.load(f)
    return set(d.get("functions", [])), {k: set(v) for k, v in d.get("namespaces", {}).items()}


def present(name: str, funcs: set, ns: dict) -> bool:
    if "." in name:
        space, fn = name.split(".", 1)
        return fn in ns.get(space, set())
    return name in funcs


def guarded(name: str, text: str) -> bool:
    n = re.escape(name)
    pats = [rf"{n}\s+and\b", rf"\bif\s+{n}\b", rf"\bnot\s+{n}\b", rf"{n}\s+then\b", rf"\bor\s+{n}\b",
            rf"\band\s+{n}\b", rf"pcall\(\s*{n}\b", rf"{n}\s*~=\s*nil", rf"{n}\s*==\s*nil"]
    return any(re.search(p, text) for p in pats)


def strip(text: str) -> str:
    """Commentaires et chaînes retirés (approximatif, suffisant ici), zones « forever-api: off … on » vidées."""
    code = re.sub(r"forever-api: off.*?forever-api: on", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    code = re.sub(r"--\[\[.*?\]\]", lambda m: "\n" * m.group(0).count("\n"), code, flags=re.S)
    code = re.sub(r"--[^\n]*", "", code)
    code = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', code)
    return re.sub(r"'(?:\\.|[^'\\\n])*'", "''", code)


def scan(path: str, funcs: set, ns: dict) -> list[tuple[int, str]]:
    with open(path, encoding="utf-8", errors="replace") as f:
        code = strip(f.read())
    defined = set(DEF.findall(code)) | set(re.findall(r"\b([A-Z]\w*)\s*=\s*", code))
    for names in re.findall(r"local\s+([\w\s,]+?)\s*=", code):     # local A, B, C = …
        defined |= {n.strip() for n in names.split(",") if n.strip()}
    out = []
    for i, line in enumerate(code.split("\n"), 1):
        for name in CALL.findall(line):
            base = name.split(".")[0]
            if name in LUA or base in defined or name in defined or present(name, funcs, ns):
                continue
            if "." in name and base not in ns:      # espace de noms inconnu du jeu : table de l'addon
                continue
            if guarded(name, code):
                continue
            out.append((i, name))
    return out


# Fonctions présentes mais interdites aux addons sur Forever (client moderne) : signalées sauf protection explicite
PROTECTED = {"ReloadUI": "taper /reload soi-même"}


def scan_protected(path: str) -> list[tuple[int, str]]:
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = strip(f.read()).split("\n")
    out = []
    for i, line in enumerate(lines, 1):
        for name in PROTECTED:
            if re.search(rf"(?<![\w.:]){name}\s*\(", line):
                out.append((i, name))
    return out


def main() -> int:
    funcs, ns = load_api()
    dirs = sys.argv[1:] or ["ForeverPretre", "ForeverGazette", "ForeverGFX", "ForeverMacros"]
    bad = 0
    for d in dirs:
        for base, _, files in os.walk(os.path.join(ROOT, d)):
            for fn in sorted(files):
                if not fn.endswith(".lua"):
                    continue
                p = os.path.join(base, fn)
                for line, name in scan(p, funcs, ns):
                    print(f"{os.path.relpath(p, ROOT)}:{line}: {name} absent du client Forever, sans repli")
                    bad += 1
                for line, name in scan_protected(p):
                    print(f"{os.path.relpath(p, ROOT)}:{line}: {name} interdit aux addons sur Forever ({PROTECTED[name]})")
                    bad += 1
    print(f"{bad} appel(s) non protégé(s) vers une fonction absente du client Forever")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
