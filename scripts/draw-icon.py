#!/usr/bin/env python3
"""くびふうせんのアイコン（1024x1024、透過なし）。絵本の水彩の空：夕暮れの空に星、水彩の雲、ねむった顔の風船。

使い方: python3 scripts/draw-icon.py
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")


def hexc(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def sky():
    top, mid, bot = hexc("#2B285F"), hexc("#7A4E93"), hexc("#EE9388")
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        t = y / (S - 1)
        c = lerp(top, mid, t / 0.55) if t < 0.55 else lerp(mid, bot, (t - 0.55) / 0.45)
        for x in range(S):
            px[x, y] = c
    return img.convert("RGBA")


def layer():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def paste_blur(base, lay, r):
    """にじませて重ねる。色を透明度で重みづけしてぼかす（縁が黒くにごらないように）"""
    import numpy as np

    arr = np.asarray(lay, dtype=np.float32) / 255
    a = arr[..., 3:4]
    pre = Image.fromarray((arr[..., :3] * a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r))
    al = lay.split()[3].filter(ImageFilter.GaussianBlur(r))
    pa = np.asarray(pre, dtype=np.float32) / 255
    aa = np.asarray(al, dtype=np.float32)[..., None] / 255
    rgb = np.where(aa > 0.002, pa / np.maximum(aa, 0.002), 0)
    out = np.concatenate([np.clip(rgb, 0, 1), aa], axis=2)
    return Image.alpha_composite(base, Image.fromarray((out * 255).astype(np.uint8), "RGBA"))


def main():
    img = sky()
    rnd = random.Random(7)
    # 地平線の光
    g = layer()
    ImageDraw.Draw(g).ellipse((-200, 760, 1224, 1300), fill=hexc("#FFC59E", 170))
    img = paste_blur(img, g, 90)
    # 水彩のむら
    g = layer()
    d = ImageDraw.Draw(g)
    for _ in range(6):
        x, y, r = rnd.randint(0, S), rnd.randint(0, 700), rnd.randint(200, 380)
        d.ellipse((x - r, y - r // 2, x + r, y + r // 2), fill=hexc("#2B285F" if rnd.random() > 0.5 else "#7A4E93", 50))
    img = paste_blur(img, g, 70)
    # 星
    g = layer()
    d = ImageDraw.Draw(g)
    for i in range(46):
        x, y = rnd.randint(20, S - 20), rnd.randint(20, 470)
        r = 5 if i % 8 == 0 else rnd.choice([2, 2.5, 3])
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, rnd.randint(150, 240)))
        if i % 8 == 0:
            d.line((x - 16, y, x + 16, y), fill=(255, 255, 255, 120), width=2)
            d.line((x, y - 16, x, y + 16), fill=(255, 255, 255, 120), width=2)
    img = Image.alpha_composite(img, g)
    # 夕陽
    g = layer()
    ImageDraw.Draw(g).ellipse((560, 700, 1000, 1140), fill=hexc("#FFC59E", 160))
    img = paste_blur(img, g, 80)
    g = layer()
    ImageDraw.Draw(g).ellipse((660, 790, 900, 1030), fill=hexc("#FFB185", 245))
    img = paste_blur(img, g, 3)

    # 水彩の雲
    def cloud(cx, cy, w, alpha):
        nonlocal img
        puffs = [(-0.32, 0.06, 0.2), (-0.12, -0.08, 0.27), (0.12, -0.12, 0.3), (0.34, 0.04, 0.21), (0.0, 0.1, 0.26)]
        m = layer()
        dm = ImageDraw.Draw(m)
        for dx, dy, r in puffs:
            rr = w * r
            dm.ellipse((cx + w * dx - rr, cy + w * dy - rr * 0.85, cx + w * dx + rr, cy + w * dy + rr * 0.85), fill=hexc("#F5C3CF", alpha))
        img = paste_blur(img, m, w * 0.03)
        sh = layer()
        ImageDraw.Draw(sh).ellipse((cx - w * 0.45, cy + w * 0.06, cx + w * 0.45, cy + w * 0.34), fill=hexc("#8F61A3", 120))
        sh = sh.filter(ImageFilter.GaussianBlur(w * 0.05))
        mask = m.split()[3]
        sh.putalpha(ImageChops.multiply(sh.split()[3], mask))
        img = Image.alpha_composite(img, sh)

    cloud(150, 690, 420, 225)
    cloud(860, 560, 360, 215)
    cloud(560, 930, 520, 230)

    # 丘
    g = layer()
    d = ImageDraw.Draw(g)
    pts = [(0, S)] + [(x, 930 - 30 * math.sin(x / S * math.pi * 1.3 + 0.8)) for x in range(0, S + 1, 16)] + [(S, S)]
    d.polygon(pts, fill=hexc("#3F3166", 230))
    img = paste_blur(img, g, 2)

    # 風船
    cx, top, bw, bh = 470, 150, 520, 600
    bal = layer()
    db = ImageDraw.Draw(bal)

    def bpath(scale=1.0):
        out = []
        for i in range(200):
            a = i / 200 * 2 * math.pi
            # 上が丸く、下がすぼまる形（しずくの逆さ）
            x = math.sin(a) * bw / 2 * scale * (1 - 0.18 * max(0, math.cos(a + math.pi)) ** 2)
            y = -math.cos(a) * bh / 2 * scale
            if y > 0:
                x *= 1 - 0.45 * (y / (bh / 2)) ** 2.2
            out.append((cx + x, top + bh / 2 + y))
        return out

    shape = bpath()
    db.polygon(shape, fill=hexc("#F08B72"))
    mask = bal.split()[3]
    # 縁にたまる色
    rim = layer()
    ImageDraw.Draw(rim).line(shape + [shape[0]], fill=hexc("#A94C3E", 110), width=60)
    rim = rim.filter(ImageFilter.GaussianBlur(26))
    rim.putalpha(ImageChops.multiply(rim.split()[3], mask))
    bal = Image.alpha_composite(bal, rim)
    # 中の明るさ
    lit = layer()
    ImageDraw.Draw(lit).ellipse((cx - 210, top + 60, cx + 40, top + 320), fill=hexc("#FFD8C6", 200))
    lit = lit.filter(ImageFilter.GaussianBlur(50))
    lit.putalpha(ImageChops.multiply(lit.split()[3], mask))
    bal = Image.alpha_composite(bal, lit)
    db = ImageDraw.Draw(bal)
    db.ellipse((cx - 150, top + 95, cx - 95, top + 140), fill=(255, 255, 255, 235))
    # 結び目とひも
    ky = top + bh
    db.polygon([(cx - 28, ky + 34), (cx + 28, ky + 34), (cx, ky - 6)], fill=hexc("#D45F4C"))
    s_pts = [(cx + 60 * math.sin(t / 30 * math.pi * 1.2), ky + 34 + t * 4) for t in range(0, 70)]
    db.line(s_pts, fill=hexc("#5E4F72", 220), width=8, joint="curve")
    # 輪郭
    db.line(shape + [shape[0]], fill=hexc("#A94C3E", 210), width=9, joint="curve")
    # 顔
    ey = top + bh * 0.5
    for dx in (-85, 85):
        db.arc((cx + dx - 34, ey - 50, cx + dx + 34, ey + 10), start=25, end=155, fill=hexc("#3B2A3E"), width=12)
    db.arc((cx - 22, ey + 10, cx + 22, ey + 52), start=15, end=165, fill=hexc("#3B2A3E", 200), width=10)
    ch = layer()
    for dx in (-150, 150):
        ImageDraw.Draw(ch).ellipse((cx + dx - 42, ey + 10, cx + dx + 42, ey + 60), fill=hexc("#E2486A", 130))
    ch = ch.filter(ImageFilter.GaussianBlur(10))
    ch.putalpha(ImageChops.multiply(ch.split()[3], mask))
    bal = Image.alpha_composite(bal, ch)
    # 少し傾ける
    bal = bal.rotate(-8, resample=Image.BICUBIC, center=(cx, top + bh * 0.4))
    shadow = layer()
    shadow.putalpha(bal.split()[3].point(lambda v: int(v * 0.25)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    img = Image.alpha_composite(img, ImageChops.offset(shadow, 10, 24))
    img = Image.alpha_composite(img, bal)

    img.convert("RGB").save(OUT)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
