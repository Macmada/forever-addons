#!/usr/bin/env python3
"""ForeverGazette -> Discord.

Lit le fichier SavedVariables de ForeverGazette (écrit par le jeu à la déconnexion ou après /reload) et poste
chaque édition dans un salon Discord par un webhook, avec la photo de une si elle est dans le dossier Screenshots.

Python 3.8+, bibliothèque standard seulement. Configuration : gazette_discord.ini à côté du script
(voir gazette_discord.example.ini). Usage :

    python gazette_discord.py              # poste les éditions des jours terminés pas encore postées
    python gazette_discord.py --today      # poste aussi l'édition du jour (mise à jour si elle change)
    python gazette_discord.py --weekly     # poste aussi l'Hebdo (une fois par jour)
    python gazette_discord.py --watch      # tourne en continu : vérifie toutes les minutes
    python gazette_discord.py --dry-run    # affiche ce qui serait posté, sans rien envoyer
"""
from __future__ import annotations

import argparse
import configparser
import datetime as dt
import glob
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
CHUNK = 1900                      # limite Discord : 2 000 caractères par message
MAX_FILE = 9 * 1024 * 1024        # limite des pièces jointes d'un webhook (10 Mo), avec marge
USER_AGENT = "ForeverGazette-Discord (https://github.com/Macmada/forever-addons, 1.0)"


# ---------------------------------------------------------------------------
# Lecture d'un fichier SavedVariables (sous-ensemble de Lua : tables, chaînes, nombres, booléens, nil)
# ---------------------------------------------------------------------------
class LuaParser:
    def __init__(self, text: str):
        self.s, self.i = text, 0

    def error(self, msg):
        raise ValueError(f"{msg} (position {self.i})")

    def skip(self):
        s = self.s
        while self.i < len(s):
            c = s[self.i]
            if c in " \t\r\n,;":
                self.i += 1
            elif s.startswith("--", self.i):
                if s.startswith("--[[", self.i):
                    end = s.find("]]", self.i)
                    self.i = len(s) if end < 0 else end + 2
                else:
                    end = s.find("\n", self.i)
                    self.i = len(s) if end < 0 else end + 1
            else:
                break

    def assignments(self) -> dict:
        out = {}
        while True:
            self.skip()
            if self.i >= len(self.s):
                return out
            m = re.compile(r"[A-Za-z_][A-Za-z0-9_]*").match(self.s, self.i)
            if not m:
                self.error("nom de variable attendu")
            name = m.group(0)
            self.i = m.end()
            self.skip()
            if self.s[self.i] != "=":
                self.error("« = » attendu")
            self.i += 1
            out[name] = self.value()

    def value(self):
        self.skip()
        s, c = self.s, self.s[self.i]
        if c == "{":
            return self.table()
        if c in "\"'":
            return self.string()
        for word, val in (("true", True), ("false", False), ("nil", None)):
            if s.startswith(word, self.i):
                self.i += len(word)
                return val
        m = re.compile(r"-?(0x[0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+)").match(s, self.i)
        if m:
            self.i = m.end()
            t = m.group(0)
            if "x" in t.lower():
                return int(t, 16)
            return float(t) if any(ch in t for ch in ".eE") else int(t)
        self.error(f"valeur inattendue « {c} »")

    def string(self) -> str:
        q = self.s[self.i]
        self.i += 1
        out = []
        esc = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "\n": "\n", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}
        raw = bytearray()

        def flush():
            if raw:
                out.append(raw.decode("utf-8", errors="replace"))
                raw.clear()

        while True:
            c = self.s[self.i]
            if c == q:
                self.i += 1
                break
            if c == "\\":
                n = self.s[self.i + 1]
                if n.isdigit():
                    m = re.compile(r"\d{1,3}").match(self.s, self.i + 1)
                    raw.append(int(m.group(0)) & 0xFF)
                    self.i = m.end()
                    continue
                flush()
                out.append(esc.get(n, n))
                self.i += 2
                continue
            flush()
            out.append(c)
            self.i += 1
        flush()
        return "".join(out)

    def table(self):
        self.i += 1
        items, arr = {}, []
        while True:
            self.skip()
            if self.s[self.i] == "}":
                self.i += 1
                break
            if self.s[self.i] == "[":
                self.i += 1
                key = self.value()
                self.skip()
                if self.s[self.i] != "]":
                    self.error("« ] » attendu")
                self.i += 1
                self.skip()
                self.i += 1          # « = »
                items[key] = self.value()
            else:
                m = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)").match(self.s, self.i)
                if m:
                    self.i = m.end()
                    items[m.group(1)] = self.value()
                else:
                    arr.append(self.value())
        if arr and not items:
            return arr
        for n, v in enumerate(arr, 1):
            items[n] = v
        return items


def read_saved_variables(path: str) -> dict:
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    # le jeu écrit le fichier avec des octets UTF-8 : relire en binaire pour les séquences \ddd
    return LuaParser(text).assignments()


# ---------------------------------------------------------------------------
# Discord
# ---------------------------------------------------------------------------
def http(method: str, url: str, body: bytes | None = None, ctype: str = "application/json"):
    req = urllib.request.Request(url, data=body, method=method, headers={"User-Agent": USER_AGENT, "Content-Type": ctype})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                data = r.read()
                return json.loads(data) if data else None
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 3:
                wait = float(json.loads(e.read() or b"{}").get("retry_after", 2))
                time.sleep(wait + 0.5)
                continue
            if e.code == 404 and method in ("PATCH", "DELETE"):
                return None
            raise RuntimeError(f"Discord a répondu {e.code} : {e.read()[:300]!r}") from None


def split_chunks(text: str) -> list[str]:
    chunks, cur = [], ""
    for line in text.split("\n"):
        while len(line) > CHUNK:
            chunks.append(line[:CHUNK])
            line = line[CHUNK:]
        if len(cur) + len(line) + 1 > CHUNK:
            chunks.append(cur.rstrip("\n"))
            cur = ""
        cur += line + "\n"
    if cur.strip():
        chunks.append(cur.rstrip("\n"))
    return chunks


def post(webhook: str, content: str, username: str, file_path: str | None = None) -> str:
    url = webhook + ("&" if "?" in webhook else "?") + "wait=true"
    payload = {"content": content, "username": username, "allowed_mentions": {"parse": []}}
    if not file_path:
        return http("POST", url, json.dumps(payload).encode())["id"]
    boundary = uuid.uuid4().hex
    name = os.path.basename(file_path)
    with open(file_path, "rb") as f:
        data = f.read()
    payload["attachments"] = [{"id": 0, "filename": name}]
    parts = [
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"payload_json\"\r\nContent-Type: application/json\r\n\r\n".encode()
        + json.dumps(payload).encode() + b"\r\n",
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"files[0]\"; filename=\"{name}\"\r\n"
        f"Content-Type: {'image/png' if name.endswith('.png') else 'image/jpeg'}\r\n\r\n".encode() + data + b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ]
    return http("POST", url, b"".join(parts), f"multipart/form-data; boundary={boundary}")["id"]


def edit(webhook: str, msg_id: str, content: str):
    base = webhook.split("?")[0]
    http("PATCH", f"{base}/messages/{msg_id}", json.dumps({"content": content, "allowed_mentions": {"parse": []}}).encode())


def delete(webhook: str, msg_id: str):
    base = webhook.split("?")[0]
    http("DELETE", f"{base}/messages/{msg_id}")


# ---------------------------------------------------------------------------
# Photos de une
# ---------------------------------------------------------------------------
SHOT_RE = re.compile(r"WoWScrnShot_(\d{6})_(\d{6})\.(jpg|png|tga)$", re.I)


def find_shot(dirs: list[str], name: str | None) -> str | None:
    if not name:
        return None
    for d in dirs:
        p = os.path.join(d, name)
        if os.path.isfile(p):
            return p
    m = SHOT_RE.search(name)
    if not m:
        return None
    want = dt.datetime.strptime(m.group(1) + m.group(2), "%m%d%y%H%M%S")
    best = None
    for d in dirs:
        for p in glob.glob(os.path.join(d, "WoWScrnShot_*")):
            mm = SHOT_RE.search(os.path.basename(p))
            if not mm:
                continue
            t = dt.datetime.strptime(mm.group(1) + mm.group(2), "%m%d%y%H%M%S")
            gap = abs((t - want).total_seconds())
            if gap <= 5 and (best is None or gap < best[0]):
                best = (gap, p)
    return best[1] if best else None


# ---------------------------------------------------------------------------
# Programme
# ---------------------------------------------------------------------------
def load_config(path: str) -> dict:
    cp = configparser.ConfigParser()
    if not cp.read(path, encoding="utf-8"):
        sys.exit(f"Fichier de configuration introuvable : {path} (copie gazette_discord.example.ini)")
    c = cp["gazette"]
    webhook = c.get("webhook", "").strip()
    if not webhook.startswith("https://"):
        sys.exit("Renseigne « webhook = https://discord.com/api/webhooks/… » dans la configuration.")
    dirs = [d.strip() for d in c.get("wow_dirs", "").split(";") if d.strip()]
    if not dirs:
        sys.exit("Renseigne « wow_dirs » (dossier du client, ex. C:\\Program Files (x86)\\World of Warcraft\\_anniversary_).")
    chars = [x.strip().lower() for x in c.get("characters", "").split(",") if x.strip()]
    return {"webhook": webhook, "dirs": dirs, "chars": chars, "username": c.get("username", "ForeverGazette").strip()}


def saved_files(dirs: list[str]) -> list[tuple[str, str]]:
    out = []
    for d in dirs:
        for p in glob.glob(os.path.join(d, "WTF", "Account", "*", "*", "*", "SavedVariables", "ForeverGazette.lua")):
            out.append((d, p))
    return out


def load_state(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {"posted": {}}


def save_state(path: str, state: dict):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=1)
    os.replace(tmp, path)


def publish(cfg, state, key, text, shot_path, dry, log):
    digest = hashlib.sha256(text.encode()).hexdigest()
    prev = state["posted"].get(key)
    if prev and prev.get("hash") == digest:
        return False
    chunks = split_chunks(text)
    if dry:
        log(f"[essai] {key} : {len(chunks)} message(s){' + photo ' + os.path.basename(shot_path) if shot_path else ''}")
        print(text, end="\n\n")
        return True
    ids = prev.get("ids", []) if prev else []
    if prev and len(ids) == len(chunks):
        for msg_id, chunk in zip(ids, chunks):
            edit(cfg["webhook"], msg_id, chunk)
        log(f"{key} : mise à jour ({len(chunks)} message(s))")
    else:
        for msg_id in ids:
            delete(cfg["webhook"], msg_id)
        ids = []
        for n, chunk in enumerate(chunks):
            photo = shot_path if (n == 0 and shot_path and os.path.getsize(shot_path) <= MAX_FILE) else None
            ids.append(post(cfg["webhook"], chunk, cfg["username"], photo))
            time.sleep(0.6)
        log(f"{key} : postée ({len(chunks)} message(s){', avec photo' if shot_path else ''})")
    state["posted"][key] = {"hash": digest, "ids": ids, "at": int(time.time())}
    return True


def run_once(cfg, state_path, args, log) -> int:
    state = load_state(state_path)
    today = dt.date.today().isoformat()
    done = 0
    files = saved_files(cfg["dirs"])
    if not files:
        log("Aucun fichier ForeverGazette.lua trouvé (le jeu l'écrit à la déconnexion ou après /reload).")
    for wow_dir, path in files:
        try:
            ex = (read_saved_variables(path).get("ForeverGazetteDB") or {}).get("exports")
        except (OSError, ValueError, IndexError) as e:
            log(f"Lecture impossible de {path} : {e}")
            continue
        if not isinstance(ex, dict):
            continue
        name, realm = ex.get("name") or "?", ex.get("realm") or ""
        if cfg["chars"] and name.lower() not in cfg["chars"]:
            continue
        shots = [os.path.join(wow_dir, "Screenshots")]
        for day, e in sorted((ex.get("days") or {}).items()):
            if not isinstance(e, dict) or not e.get("md"):
                continue
            if day > today or (day == today and not args.today):
                continue
            key = f"{realm}/{name}/{day}"
            if day < today and key in state["posted"] and not state["posted"][key].get("today"):
                continue            # jour terminé déjà posté : on n'y touche plus
            if publish(cfg, state, key, e["md"], find_shot(shots, e.get("shot")), args.dry_run, log):
                done += 1
                if not args.dry_run:
                    state["posted"][key]["today"] = day == today
        wk = ex.get("weekly")
        if args.weekly and isinstance(wk, dict) and wk.get("md"):
            key = f"{realm}/{name}/hebdo/{wk.get('key')}"
            if key not in state["posted"] and publish(cfg, state, key, wk["md"], None, args.dry_run, log):
                done += 1
        if not args.dry_run:
            save_state(state_path, state)
    return done


def main():
    ap = argparse.ArgumentParser(description="Poste les éditions de ForeverGazette sur Discord.")
    ap.add_argument("--config", default=os.path.join(HERE, "gazette_discord.ini"))
    ap.add_argument("--today", action="store_true", help="poste aussi l'édition du jour et la met à jour")
    ap.add_argument("--weekly", action="store_true", help="poste aussi l'Hebdo (une fois par jour)")
    ap.add_argument("--watch", action="store_true", help="vérifie toutes les minutes (à laisser tourner)")
    ap.add_argument("--dry-run", action="store_true", help="affiche sans rien envoyer")
    args = ap.parse_args()
    cfg = load_config(args.config)
    state_path = os.path.join(os.path.dirname(os.path.abspath(args.config)), "gazette_discord_state.json")

    def log(msg):
        print(time.strftime("%H:%M:%S"), msg, flush=True)

    if not args.watch:
        n = run_once(cfg, state_path, args, log)
        log(f"{n} édition(s) envoyée(s).")
        return
    last = None
    log("Surveillance : Ctrl+C pour arrêter.")
    while True:
        stamp = tuple((p, os.path.getmtime(p)) for _, p in saved_files(cfg["dirs"])) + (dt.date.today().isoformat(),)
        if stamp != last:
            last = stamp
            try:
                run_once(cfg, state_path, args, log)
            except RuntimeError as e:
                log(str(e))
        time.sleep(60)


if __name__ == "__main__":
    main()
