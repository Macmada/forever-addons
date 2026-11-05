"""Mise en page d'une édition ForeverGazette en pages de journal (PNG et PDF), avec les captures d'écran.

Nécessite Pillow (pip install pillow). Entrée : la liste de blocs exportée par l'addon
({k = type, t = texte, q = qualité d'objet, f = capture, e = type d'événement}).
"""
from __future__ import annotations

import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

W, H = 1240, 1754                    # A4 à 150 ppp
M = 70
GUTTER = 40
PAPER, INK, SOFT, RED, BOX = (236, 226, 200), (40, 28, 16), (95, 75, 50), (120, 30, 20), (226, 212, 178)
QCOLOR = {3: (0, 90, 180), 4: (120, 40, 170), 5: (200, 100, 0), 6: (200, 100, 0)}

# Polices à empattement : Windows d'abord, puis Linux / macOS
FONT_CANDIDATES = {
    "bold": ["georgiab.ttf", "timesbd.ttf", "EBGaramond12-Bold.otf", "EBGaramond-Bold.ttf", "LiberationSerif-Bold.ttf", "DejaVuSerif-Bold.ttf", "Georgia Bold.ttf"],
    "regular": ["georgia.ttf", "times.ttf", "EBGaramond12-Regular.otf", "LiberationSerif-Regular.ttf", "DejaVuSerif.ttf", "Georgia.ttf"],
    "italic": ["georgiai.ttf", "timesi.ttf", "EBGaramond12-Italic.otf", "LiberationSerif-Italic.ttf", "DejaVuSerif-Italic.ttf", "Georgia Italic.ttf"],
}
FONT_DIRS = [os.path.join(os.environ.get("WINDIR", "C:\\Windows"), "Fonts"),
             os.path.expanduser("~/AppData/Local/Microsoft/Windows/Fonts"),
             "/usr/share/fonts", "/Library/Fonts", "/System/Library/Fonts/Supplemental", os.path.expanduser("~/.fonts")]


def _has_glyphs(path: str, chars: str = "ÉÈÊÀÇÔéèêàçôœ") -> bool:
    """Vrai si la police dessine ces caractères (sinon elle afficherait des carrés)."""
    try:
        f = ImageFont.truetype(path, 40)
    except OSError:
        return False
    def shape(c):
        m = f.getmask(c)
        return m.size, bytes(m)
    missing = shape("\U0010FFFD")
    return all(shape(c) != missing for c in chars)


def _find_font(style: str) -> str | None:
    for name in FONT_CANDIDATES[style]:
        for d in FONT_DIRS:
            p = os.path.join(d, name)
            if not os.path.isfile(p) and os.path.isdir(d) and d.startswith("/usr/share/fonts"):
                p = next((os.path.join(root, name) for root, _, files in os.walk(d) if name in files), "")
            if p and os.path.isfile(p) and _has_glyphs(p):
                return p
    return None


_font_cache: dict = {}


def font(style: str, size: int):
    key = (style, size)
    if key not in _font_cache:
        path = _find_font(style)
        _font_cache[key] = ImageFont.truetype(path, size) if path else ImageFont.load_default()
    return _font_cache[key]


class Page:
    def __init__(self, seed: int):
        random.seed(seed)
        img = Image.new("RGB", (W, H), PAPER)
        noise = Image.effect_noise((W, H), 18).convert("L")
        img = Image.composite(img, Image.new("RGB", (W, H), (214, 200, 165)), noise.point(lambda v: 255 if v > 118 else 225))
        vign = Image.new("L", (W, H), 0)
        ImageDraw.Draw(vign).rectangle([0, 0, W, H], outline=255, width=60)
        vign = vign.filter(ImageFilter.GaussianBlur(70))
        self.img = Image.composite(Image.new("RGB", (W, H), (190, 170, 130)), img, vign.point(lambda v: v // 2))
        self.d = ImageDraw.Draw(self.img)


class Renderer:
    def __init__(self, blocks: list[dict], screenshot_dirs: list[str], find_shot, footer: str):
        self.blocks = [b for b in blocks if isinstance(b, dict)]
        self.dirs, self.find_shot, self.footer = screenshot_dirs, find_shot, footer
        self.pages: list[Page] = []
        self.f_mast, self.f_ed = font("bold", 80), font("italic", 26)
        self.f_head, self.f_lede = font("bold", 48), font("italic", 27)
        self.f_sec, self.f_txt = font("bold", 25), font("regular", 24)
        self.f_small, self.f_stats = font("italic", 19), font("regular", 23)
        self._measure = ImageDraw.Draw(Image.new("RGB", (10, 10)))

    # --- outils
    def wrap(self, text, f, width):
        lines, cur = [], ""
        for w in (text or "").split(" "):
            t = (cur + " " + w).strip()
            if self._measure.textlength(t, font=f) <= width:
                cur = t
            else:
                if cur:
                    lines.append(cur)
                while self._measure.textlength(w, font=f) > width and len(w) > 1:   # mot trop long
                    cut = len(w)
                    while cut > 1 and self._measure.textlength(w[:cut], font=f) > width:
                        cut -= 1
                    lines.append(w[:cut])
                    w = w[cut:]
                cur = w
        if cur:
            lines.append(cur)
        return lines or [""]

    def text_h(self, text, f, width, gap=6):
        return len(self.wrap(text, f, width)) * (f.size + gap)

    def draw_text(self, page, x, y, text, f, width, fill=INK, center=False, gap=6):
        for ln in self.wrap(text, f, width):
            tw = page.d.textlength(ln, font=f)
            page.d.text((x + (width - tw) / 2 if center else x, y), ln, font=f, fill=fill)
            y += f.size + gap
        return y

    def load_photo(self, name):
        path = self.find_shot(self.dirs, name) if name else None
        if not path:
            return None
        try:
            im = Image.open(path)
            im.draft("RGB", (im.width // 2, im.height // 2))   # JPEG 5K : décodage réduit, plus rapide
            return im.convert("RGB")
        except OSError:
            return None

    def fit_photo(self, im, width, max_h, max_ratio):
        """Largeur imposée ; les captures trop larges (écran 21:9 ou 32:9) sont recadrées au centre à max_ratio,
        les trop hautes à max_h. Dans WoW, le personnage est au centre de l'écran."""
        if im.width / im.height > max_ratio:
            cw = int(im.height * max_ratio)
            left = (im.width - cw) // 2
            im = im.crop((left, 0, left + cw, im.height))
        h = int(width * im.height / im.width)
        if h > max_h:
            return ImageOps.fit(im, (width, max_h), Image.LANCZOS, centering=(0.5, 0.45))
        return im.resize((width, h), Image.LANCZOS)

    def paste_photo(self, page, im, x, y, caption, width):
        page.img.paste(im, (x, y))
        page.d.rectangle([x - 1, y - 1, x + im.width, y + im.height], outline=INK, width=2)
        y += im.height + 6
        if caption:
            y = self.draw_text(page, x, y, caption, self.f_small, width, fill=SOFT, center=True, gap=2)
        return y

    def new_page(self):
        p = Page(len(self.pages) + 7)
        self.pages.append(p)
        return p

    # --- rendu
    def render(self) -> list[Image.Image]:
        get = lambda k: [b for b in self.blocks if b.get("k") == k]
        page = self.new_page()
        y = 46
        mast = (get("masthead") or [{"t": "ForeverGazette"}])[0]["t"].upper()
        y = self.draw_text(page, M, y, mast, self.f_mast, W - 2 * M, center=True) + 2
        self.rule(page, y, True)
        y += 16
        ed = get("edition")
        if ed:
            y = self.draw_text(page, M, y, ed[0]["t"], self.f_ed, W - 2 * M, fill=SOFT, center=True)
        self.rule(page, y + 4, True)
        y += 26
        head = get("headline")
        if head:
            y = self.draw_text(page, M, y, head[0]["t"], self.f_head, W - 2 * M, center=True, gap=4) + 10
        une = next((b for b in self.blocks if b.get("k") == "photo"), None)
        im = self.load_photo(une.get("f")) if une else None
        if im:
            pw = W - 2 * M - 160
            im = self.fit_photo(im, pw, 400, 2.35)
            y = self.paste_photo(page, im, M + 80 + (pw - im.width) // 2 + 0, y, None, pw) + 10
        lede = get("lede")
        if lede:
            y = self.draw_text(page, M + 60, y, lede[0]["t"], self.f_lede, W - 2 * M - 120, fill=SOFT, center=True) + 10
        self.rule(page, y)
        y += 18

        # rubriques -> éléments à placer en colonnes ; « Bilan » à part (encadré pleine largeur)
        colw = (W - 2 * M - GUTTER) // 2
        sections, cur = [], None
        for b in self.blocks:
            k = b.get("k")
            if k == "section":
                cur = {"title": b["t"], "items": []}
                sections.append(cur)
            elif cur is not None and k in ("line", "item", "stats", "note"):
                cur["items"].append(b)
        stats = [s for s in sections if s["items"] and all(i.get("k") == "stats" for i in s["items"])]
        sections = [s for s in sections if s not in stats]

        items = []          # (hauteur, fonction de dessin)
        for s in sections:
            items.append(("title", self.f_sec.size + 16, s["title"]))
            for b in s["items"]:
                items.append(("line", self.text_h("• " + b["t"], self.f_txt, colw - 10, 4) + 4, b))
                ph = self.load_photo(b.get("f")) if b.get("f") else None
                if ph:
                    ph = self.fit_photo(ph, colw, 220, 1.9)
                    items.append(("photo", ph.height + 10 + self.text_h(b["t"], self.f_small, colw, 2) + 12, (ph, b)))
            items.append(("space", 18, None))
        for st in stats:
            # deux colonnes si chaque ligne y tient, sinon une seule (le bilan était coupé : « Expérience gagnée : … »)
            half = (colw - 12) // 2
            fits = all(self._measure.textlength("• " + it["t"], font=self.f_stats) <= half - 6 for it in st["items"])
            st["cols"] = 2 if fits else 1
            rows = (len(st["items"]) + st["cols"] - 1) // st["cols"]
            items.append(("stats", self.f_sec.size + 26 + rows * (self.f_stats.size + 8) + 12, st))

        bottom = H - 110
        # groupes insécables : titre + première ligne (+ sa photo), ligne + sa photo
        groups, n = [], 0
        while n < len(items):
            g = [items[n]]
            n += 1
            if g[-1][0] == "title" and n < len(items) and items[n][0] == "line":
                g.append(items[n]); n += 1
            if g[-1][0] == "line" and n < len(items) and items[n][0] == "photo":
                g.append(items[n]); n += 1
            if n < len(items) and items[n][0] == "space":
                g.append(items[n]); n += 1
            groups.append(g)
        gh = [sum(h for _, h, _ in g) for g in groups]
        x_cols = [M, M + colw + GUTTER]

        def draw(page, x, cy, kind, data):
            if kind == "title":
                page.d.text((x, cy), data.upper(), font=self.f_sec, fill=RED)
                page.d.line([(x, cy + self.f_sec.size + 6), (x + colw, cy + self.f_sec.size + 6)], fill=RED, width=1)
            elif kind == "line":
                color = QCOLOR.get(int(data["q"]) if isinstance(data.get("q"), (int, float)) else -1, INK)
                self.draw_text(page, x + 4, cy, "• " + data["t"], self.f_txt, colw - 10, fill=color, gap=4)
            elif kind == "photo":
                ph, b = data
                self.paste_photo(page, ph, x, cy + 4, b["t"], colw)
            elif kind == "stats":
                cols = data.get("cols", 2)
                rows = (len(data["items"]) + cols - 1) // cols
                bh = self.f_sec.size + 26 + rows * (self.f_stats.size + 8) + 4
                page.d.rectangle([x - 6, cy, x + colw + 6, cy + bh], fill=BOX, outline=INK, width=1)
                page.d.text((x + 6, cy + 8), data["title"].upper(), font=self.f_sec, fill=RED)
                page.d.line([(x + 6, cy + self.f_sec.size + 14), (x + colw - 6, cy + self.f_sec.size + 14)], fill=RED, width=1)
                half = (colw - 12) // cols
                for i, it in enumerate(data["items"]):
                    tx = x + 8 + (i // rows) * half
                    ty = cy + self.f_sec.size + 22 + (i % rows) * (self.f_stats.size + 8)
                    t = "• " + it["t"]
                    while page.d.textlength(t, font=self.f_stats) > half - 6 and len(t) > 4:
                        t = t[:-2] + "…"
                    page.d.text((tx, ty), t, font=self.f_stats, fill=INK)

        def place(page, top, gs, limit):
            """Répartit les groupes gs sur deux colonnes équilibrées si possible ; renvoie (groupes restants, bas)."""
            avail = limit - top
            hs = [sum(h for _, h, _ in g) for g in gs]
            best = None
            for k in range(len(gs) + 1):
                left, right = sum(hs[:k]), sum(hs[k:])
                if left <= avail and right <= avail and (best is None or max(left, right) < best[0]):
                    best = (max(left, right), k)
            if best is not None:
                k, rest = best[1], []
                cols = [gs[:k], gs[k:]]
            else:                      # trop long pour une page : on remplit à ras bord
                cols, used, c, rest = [[], []], [0, 0], 0, []
                for i, g in enumerate(gs):
                    h = hs[i]
                    if used[c] + h > avail and used[c] > 0:
                        c += 1
                    if c > 1:
                        rest = gs[i:]
                        break
                    cols[c].append(g)
                    used[c] += h
            ends = []
            for c, glist in enumerate(cols):
                cy = top
                for g in glist:
                    for kind, h, data in g:
                        draw(page, x_cols[c], cy, kind, data)
                        cy += h
                ends.append(cy)
            self.separator(page, top, max(ends) - 10)
            return rest, max(ends)

        remaining = groups
        remaining, used_bottom = place(page, y, remaining, bottom)
        while remaining:
            page = self.new_page()
            top = self.continued_header(page)
            remaining, used_bottom = place(page, top, remaining, bottom)

        for n, p in enumerate(self.pages, 1):
            self.rule(p, H - 96)
            label = self.footer + (f"  ·  page {n}/{len(self.pages)}" if len(self.pages) > 1 else "")
            self.draw_text(p, M, H - 84, label, self.f_small, W - 2 * M, fill=SOFT, center=True, gap=2)
        return [p.img for p in self.pages]

    def rule(self, page, y, double=False):
        page.d.line([(M, y), (W - M, y)], fill=INK, width=3 if double else 1)
        if double:
            page.d.line([(M, y + 6), (W - M, y + 6)], fill=INK, width=1)

    def separator(self, page, y0, y1):
        if y1 > y0:
            x = M + (W - 2 * M - GUTTER) // 2 + GUTTER // 2
            page.d.line([(x, y0), (x, y1)], fill=SOFT, width=1)

    def continued_header(self, page) -> int:
        mast = next((b["t"] for b in self.blocks if b.get("k") == "masthead"), "ForeverGazette")
        ed = next((b["t"] for b in self.blocks if b.get("k") == "edition"), "")
        y = self.draw_text(page, M, 50, f"{mast.upper()} — {ed}", self.f_ed, W - 2 * M, fill=SOFT, center=True)
        self.rule(page, y + 4, True)
        return y + 30


def render_edition(blocks, screenshot_dirs, find_shot, out_base: str, footer: str = "ForeverGazette",
                   png=True, pdf=True) -> list[str]:
    """Écrit out_base.pdf et out_base.png (out_base-p2.png… si plusieurs pages). Renvoie les fichiers écrits."""
    pages = Renderer(blocks, screenshot_dirs, find_shot, footer).render()
    written = []
    os.makedirs(os.path.dirname(os.path.abspath(out_base)), exist_ok=True)
    if png:
        for n, im in enumerate(pages, 1):
            path = out_base + (".png" if n == 1 else f"-p{n}.png")
            im.save(path, optimize=True)
            written.append(path)
    if pdf:
        path = out_base + ".pdf"
        pages[0].save(path, "PDF", resolution=150, save_all=True, append_images=pages[1:])
        written.append(path)
    return written
