#!/usr/bin/env python3
"""App アイコン（1024x1024、透過なし PNG）を作る。Linux のセッションで Pillow を使う。

使い方:
  python3 scripts/make-icon.py --bg "#1E6F5C" --fg "#FFFFFF" --glyph circle
  python3 scripts/make-icon.py --bg "#F2A541" --fg "#2B2D42" --glyph text --text "水"

App Store のアイコンは透過（アルファ）を含められないため、RGB で保存する。
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
OUT = os.path.join(
    os.path.dirname(__file__), "..", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png"
)


def hex_color(value: str) -> tuple[int, int, int]:
    v = value.lstrip("#")
    if len(v) != 6:
        raise argparse.ArgumentTypeError(f"#RRGGBB で指定してください: {value}")
    return tuple(int(v[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--bg", type=hex_color, required=True)
    p.add_argument("--fg", type=hex_color, required=True)
    p.add_argument("--glyph", choices=["circle", "ring", "square", "text"], default="circle")
    p.add_argument("--text", default="", help="--glyph text のときの1〜2文字")
    p.add_argument("--font", default="", help="TrueType フォントのパス（日本語を描くとき）")
    p.add_argument("--out", default=OUT)
    a = p.parse_args()

    img = Image.new("RGB", (SIZE, SIZE), a.bg)
    d = ImageDraw.Draw(img)
    c, r = SIZE // 2, SIZE // 4
    if a.glyph == "circle":
        d.ellipse((c - r, c - r, c + r, c + r), fill=a.fg)
    elif a.glyph == "ring":
        d.ellipse((c - r, c - r, c + r, c + r), outline=a.fg, width=SIZE // 14)
    elif a.glyph == "square":
        d.rounded_rectangle((c - r, c - r, c + r, c + r), radius=SIZE // 12, fill=a.fg)
    else:
        if not a.text:
            p.error("--glyph text には --text が要ります")
        font = ImageFont.truetype(a.font, SIZE // 2) if a.font else ImageFont.load_default(size=SIZE // 2)
        d.text((c, c), a.text, fill=a.fg, font=font, anchor="mm")

    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    img.save(a.out, "PNG", optimize=True)
    print(f"wrote {os.path.relpath(a.out)} ({img.mode}, {img.size[0]}x{img.size[1]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
