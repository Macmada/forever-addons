#!/usr/bin/env python3
"""Base d'objets du prêtre et du paladin pour ForeverCompagnon, tirée du simulateur wowsims/forever (licence MIT).

    python3 tools/wowsims_extract.py                # télécharge assets/database/db.json (dernier commit) et écrit
                                                    # ForeverCompagnon/Loot/Items.lua
    python3 tools/wowsims_extract.py --db db.json --commit <sha>    # depuis un fichier déjà téléchargé

Garde les objets qu'un prêtre (tissu, dagues, masses, bâtons, objets tenus en main gauche, baguettes) ou un paladin
(mailles, plaques, haches, masses, armes d'hast, épées, boucliers, objets tenus en main gauche, librams) peut porter, avec
leurs caractéristiques (n° de wowsims), le DPS des armes, le niveau requis, la faction, la phase et les provenances
(butin, quête, marchand, artisanat, réputation, JcJ).
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

# common.proto : énumérations de wowsims. Caractéristiques gardées (n° de wowsims), et 100 = DPS de l'arme
KEEP = (0, 1, 2, 3, 4, 5, 9, 13, 14, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 31)
DPS = 100
SLOT = {1: 1, 2: 2, 3: 3, 4: 15, 5: 5, 6: 9, 7: 10, 8: 6, 9: 7, 10: 8, 11: 11, 12: 13}   # ItemType -> emplacement du jeu
PROF = {1: "alchemy", 2: "blacksmithing", 3: "enchanting", 4: "engineering", 8: "leatherworking", 11: "tailoring"}
# classes servies (n° de classe du jeu dans wowsims) : prêtre 5, paladin 2 ; masque dans Items.lua : 1 prêtre, 2 paladin
CLASSES = {5: 1, 2: 2}
ARMOR = {5: (0, 1), 2: (0, 1, 2, 3, 4)}                 # tissu ; toutes (le paladin porte aussi tissu et cuir)
WEAPONS = {5: (2, 4, 8), 2: (1, 4, 6, 9)}               # dague, masse, bâton ; hache, masse, arme d'hast, épée
OFFHAND = {5: (5,), 2: (5, 7)}                          # objet tenu en main gauche ; bouclier
RANGED = {5: 5, 2: 7}                                   # baguette ; libram


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def slot_of(it):
    """(emplacement, n° d'arme) : 116 = arme à deux mains, 17 = main gauche ; arme 105 = baguette, 107 = libram."""
    t = it.get("type")
    if t in SLOT:
        return SLOT[t], 0
    if t == 13:
        wt, ht = it.get("weaponType"), it.get("handType")
        if wt in (5, 7):
            return 17, wt
        if ht == 4:
            return 116, wt
        if ht in (1, 2):
            return 16, wt
        if ht == 3:
            return 17, wt
        return None, 0
    if t == 14 and it.get("rangedWeaponType") in (5, 7):
        return 18, 100 + it["rangedWeaponType"]
    return None, 0


def classes_of(it, slot, wtype):
    mask = 0
    ca = it.get("classAllowlist")
    for cls, bit in CLASSES.items():
        if ca and cls not in ca:
            continue
        armor = it.get("armorType") or 0
        t = it.get("type")
        if t in SLOT:
            if t in (2, 11, 12) or armor in ARMOR[cls] or (t == 4 and armor in (0, 1)):
                mask |= bit
        elif slot == 18:
            if wtype == 100 + RANGED[cls]:
                mask |= bit
        elif slot == 17 and wtype in (5, 7):
            if wtype in OFFHAND[cls]:
                mask |= bit
        elif wtype in WEAPONS[cls]:
            mask |= bit
    return mask


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
        if it.get("randomSuffixOptions"):
            continue
        slot, wtype = slot_of(it)
        if slot is None:
            continue
        mask = classes_of(it, slot, wtype)
        if not mask:
            continue
        sc = (it.get("scalingOptions") or {}).get("0") or {}
        raw = sc.get("stats") or {}
        st = {int(k): int(round(v)) for k, v in raw.items() if int(k) in KEEP and v}
        if sc.get("unroundedDps") and slot in (16, 116):
            st[DPS] = round(float(sc["unroundedDps"]), 1)
        useful = {k: v for k, v in st.items() if k not in (27, DPS)}
        if not useful and (it.get("quality") or 1) < 2:
            continue                               # objet blanc sans caractéristique : jamais un conseil
        if not st and not it.get("itemEffects"):
            continue                               # (librams, bijoux à effet : gardés même sans caractéristique)
        src = sources(it, npcs)
        for s_ in src:
            if s_[0] in ("drop", "vendor") and s_[2]:
                used_zones.add(s_[2])
            if s_[0] == "rep":
                used_factions.add(s_[1])
        flags = ("u" if it.get("unique") else "") + ("e" if it.get("itemEffects") else "")
        rows.append((it["id"], slot, it.get("reqLvl") or 0, sc.get("ilvl") or 0, it.get("quality") or 1, it.get("phase") or 1,
                     it.get("factionRestriction") or 0, st, it["name"], src, flags, it.get("setName") or "",
                     it.get("armorType") or 0, wtype, mask))
    rows.sort()
    out = [
        f"-- Généré par tools/wowsims_extract.py depuis wowsims/forever ({REPO}, licence MIT), commit {commit[:12]},",
        f"-- le {date.today():%d/%m/%Y}. Ne pas modifier à la main : relancer l'outil.",
        "-- Objets portables par un prêtre ou un paladin. Par objet : { emplacement (116 = arme à deux mains, 17 = main gauche),",
        "-- niveau requis, niveau d'objet, qualité, phase, faction (1 Alliance, 2 Horde), { [n° de caractéristique de wowsims] =",
        "-- valeur ; 100 = DPS de l'arme }, nom anglais, provenances, marques (u : unique, e : effet), set, armure (1 tissu,",
        "-- 2 cuir, 3 mailles, 4 plaques), arme (n° de wowsims ; 105 baguette, 107 libram), classes (1 prêtre, 2 paladin) }",
        "-- Provenances : { \"drop\", PNJ, zone, nom } { \"quest\", n°, nom, faction } { \"vendor\", PNJ, zone, nom, faction }",
        "-- { \"craft\", métier } { \"rep\", n° de faction, niveau (8 = exalté), faction } { \"pvp\" }",
        'local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverLoot") end',
        f'ns.ItemsInfo = {{ commit = {lua_str(commit[:12])}, date = {lua_str(f"{date.today():%Y-%m-%d}")}, count = {len(rows)} }}',
        "ns.Items = {",
    ]
    for (iid, slot, req, ilvl, q, ph, fac, st, name, src, flags, setn, armor, wtype, mask) in rows:
        s = ",".join("{" + ",".join(lua_str(x) if isinstance(x, str) else str(x) for x in e) + "}" for e in src)
        stats = ",".join(f"[{k}]={v}" for k, v in sorted(st.items()))
        out.append(f"  [{iid}] = {{ {slot}, {req}, {ilvl}, {q}, {ph}, {fac}, {{ {stats} }}, {lua_str(name)}, "
                   f"{{ {s} }}, {lua_str(flags)}, {lua_str(setn)}, {armor}, {wtype}, {mask} }},")
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
