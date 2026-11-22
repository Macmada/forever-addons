#!/usr/bin/env python3
"""Base d'objets du prêtre soigneur pour ForeverCompagnon, tirée du simulateur wowsims/forever (licence MIT).

    python3 tools/wowsims_extract.py                # télécharge assets/database/db.json (dernier commit) et écrit
                                                    # ForeverCompagnon/Loot/Items.lua
    python3 tools/wowsims_extract.py --db db.json --commit <sha>    # depuis un fichier déjà téléchargé

Garde les objets qu'un prêtre peut porter (tissu, cou, doigts, bijoux, dos, masses à une main, dagues, bâtons, objets
tenus en main gauche, baguettes) et qui ont au moins une caractéristique utile à un soigneur. Par objet :
emplacement, niveau requis, niveau d'objet, qualité, phase, faction, puissance des soins, intelligence, esprit, mp5,
critique, hâte, endurance, nom anglais, provenances (butin, quête, marchand, artisanat, réputation, JcJ).
Les noms des PNJ, zones et quêtes sont gardés en anglais : l'addon demande au jeu le nom dans ta langue quand il le peut.
Relancé avec tools/update-att-data.sh (rappel friday mensuel des sources).
"""
import argparse
import json
import subprocess
import sys
import urllib.request
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "ForeverCompagnon" / "Loot" / "Items.lua"
REPO = "https://github.com/wowsims/forever"

# common.proto : énumérations de wowsims
ST_STA, ST_INT, ST_HEAL, ST_SPI, ST_CRIT, ST_HASTE, ST_MP5 = "2", "3", "4", "13", "18", "19", "31"
SLOT = {1: 1, 2: 2, 3: 3, 4: 15, 5: 5, 6: 9, 7: 10, 8: 6, 9: 7, 10: 8, 11: 11, 12: 13}   # ItemType -> emplacement du jeu
PROF = {1: "alchemy", 2: "blacksmithing", 3: "enchanting", 4: "engineering", 8: "leatherworking", 11: "tailoring"}


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def slot_of(it):
    t = it.get("type")
    if t in SLOT:
        if t not in (2, 4, 11, 12) and it.get("armorType") not in (1, None, 0):      # armure : tissu seulement
            return None
        return SLOT[t]
    if t == 13:
        wt, ht = it.get("weaponType"), it.get("handType")
        if wt == 8:                      # bâton : à deux mains
            return 116
        if wt == 5:                      # objet tenu en main gauche
            return 17
        if wt in (2, 4) and ht in (1, 2):    # dague, masse : main droite ou une main
            return 16
        return None
    if t == 14 and it.get("rangedWeaponType") == 5:      # baguette
        return 18
    return None


def sources(it, npcs):
    out = []
    for s in it.get("sources") or []:
        k, v = next(iter(s.items()))
        if k == "drop":
            npc = v.get("npcId") or 0
            out.append(["drop", npc, v.get("zoneId") or 0, npcs.get(npc, "") or v.get("otherName", "")])
        elif k == "quest":
            out.append(["quest", v.get("id") or 0, v.get("name", ""), v.get("faction") or 0])
        elif k == "soldBy":
            out.append(["vendor", v.get("npcId") or 0, v.get("zoneId") or 0, v.get("npcName", ""), v.get("faction") or 0])
        elif k == "crafted":
            out.append(["craft", PROF.get(v.get("profession"), "other")])
        elif k == "rep":
            out.append(["rep", v.get("repFactionId") or 0, v.get("repLevel") or 0, v.get("factionId") or 0])
        elif k == "pvp":
            out.append(["pvp"])
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--db", help="db.json déjà téléchargé")
    ap.add_argument("--commit", help="commit de wowsims/forever (sinon : dernier)")
    args = ap.parse_args()
    commit = args.commit or subprocess.run(["git", "ls-remote", REPO, "HEAD"], capture_output=True, text=True,
                                           check=True).stdout.split()[0]
    if args.db:
        raw = Path(args.db).read_text(encoding="utf-8")
    else:
        url = f"https://raw.githubusercontent.com/wowsims/forever/{commit}/assets/database/db.json"
        raw = urllib.request.urlopen(url, timeout=60).read().decode("utf-8")
    d = json.loads(raw)
    npcs = {n["id"]: n["name"] for n in d["npcs"]}
    zones = {z["id"]: z["name"] for z in d["zones"]}
    factions = {f["id"]: f["name"] for f in d["factions"]}
    rows, used_zones, used_factions = [], set(), set()
    for it in d["items"]:
        ca = it.get("classAllowlist")
        if ca and 5 not in ca:               # 5 = prêtre
            continue
        if it.get("randomSuffixOptions"):
            continue
        slot = slot_of(it)
        if slot is None:
            continue
        sc = (it.get("scalingOptions") or {}).get("0") or {}
        st = sc.get("stats") or {}
        vals = [int(st.get(k, 0)) for k in (ST_HEAL, ST_INT, ST_SPI, ST_MP5, ST_CRIT, ST_HASTE, ST_STA)]
        if not any(vals[:6]):
            continue
        src = sources(it, npcs)
        for s in src:
            if s[0] in ("drop", "vendor") and s[2]:
                used_zones.add(s[2])
            if s[0] == "rep":
                used_factions.add(s[1])
        flags = ("u" if it.get("unique") else "") + ("e" if it.get("itemEffects") else "")
        rows.append((it["id"], slot, it.get("reqLvl") or 0, sc.get("ilvl") or 0, it.get("quality") or 1, it.get("phase") or 1,
                     it.get("factionRestriction") or 0, vals, it["name"], src, flags, it.get("setName") or ""))
    rows.sort()
    out = [
        f"-- Généré par tools/wowsims_extract.py depuis wowsims/forever ({REPO}, licence MIT), commit {commit[:12]},",
        f"-- le {date.today():%d/%m/%Y}. Ne pas modifier à la main : relancer l'outil.",
        "-- Objets portables par un prêtre avec au moins une caractéristique de soigneur. Par objet : { emplacement (116 = bâton",
        "-- à deux mains), niveau requis, niveau d'objet, qualité, phase, faction (1 Alliance, 2 Horde), { soins, intelligence,",
        "-- esprit, mp5, critique, hâte, endurance }, nom anglais, provenances, marques (u : unique, e : effet), set }",
        "-- Provenances : { \"drop\", PNJ, zone, nom } { \"quest\", n°, nom, faction } { \"vendor\", PNJ, zone, nom, faction }",
        "-- { \"craft\", métier } { \"rep\", n° de faction, niveau (8 = exalté), faction } { \"pvp\" }",
        'local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverLoot") end',
        f'ns.ItemsInfo = {{ commit = {lua_str(commit[:12])}, date = {lua_str(f"{date.today():%Y-%m-%d}")}, count = {len(rows)} }}',
        "ns.Items = {",
    ]
    for (iid, slot, req, ilvl, q, ph, fac, vals, name, src, flags, setn) in rows:
        s = ",".join("{" + ",".join(lua_str(x) if isinstance(x, str) else str(x) for x in e) + "}" for e in src)
        out.append(f"  [{iid}] = {{ {slot}, {req}, {ilvl}, {q}, {ph}, {fac}, {{ {','.join(map(str, vals))} }}, {lua_str(name)}, "
                   f"{{ {s} }}, {lua_str(flags)}, {lua_str(setn)} }},")
    out.append("}")
    out.append("ns.ItemZones = {")
    for z in sorted(used_zones):
        if z in zones:
            out.append(f"  [{z}] = {lua_str(zones[z])},")
    out.append("}")
    out.append("ns.ItemFactions = {")
    for f in sorted(used_factions):
        if f in factions:
            out.append(f"  [{f}] = {lua_str(factions[f])},")
    out.append("}")
    OUT.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)} : {len(rows)} objets, {len(used_zones)} zones, {len(used_factions)} factions (wowsims {commit[:12]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
