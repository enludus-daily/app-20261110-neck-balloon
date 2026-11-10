#!/usr/bin/env python3
"""Theme の色を HSL にして、StudyReel のトーンに合うかを出す（app-quality-bar の look.md §0）。

使い方: python3 scripts/tone-check.py [App/Sources]
- 主な色（accent）の目安: 明度 L 0.72〜0.86
- 強い色: 明度 0.40〜0.65 かつ彩度 0.6 以上（鮮やかな赤・朱・原色の黄・橙）。警告・削除などの小さな点だけに使う
  （StudyReel の ThemeColor.swift・ReelTheme.swift は 0 件。濃い文字用の deep は明度 0.40 未満か彩度が低く、当たらない）
強い色が見つかったら exit 1（使い道が小さな点だけなら、その理由を Issue に書く）。
"""
import colorsys
import re
import sys
from pathlib import Path

HEX = re.compile(r"(?:0x|#)([0-9A-Fa-f]{6})\b")
RGB = re.compile(r"Color\(\s*red:\s*([\d.]+)\s*,\s*green:\s*([\d.]+)\s*,\s*blue:\s*([\d.]+)")


def colors(text):
    for m in HEX.finditer(text):
        h = m.group(1)
        yield m.start(), "#" + h.upper(), tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    for m in RGB.finditer(text):
        rgb = tuple(float(v) for v in m.groups())
        yield m.start(), "rgb" + str(rgb), rgb


def main(argv):
    root = Path(argv[1] if len(argv) > 1 else "App/Sources")
    strong = []
    for path in sorted(root.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for pos, label, rgb in colors(text):
            h, l, s = colorsys.rgb_to_hls(*rgb)
            line = text.count("\n", 0, pos) + 1
            kind = "strong" if 0.40 <= l < 0.65 and s >= 0.6 else ("pastel" if 0.72 <= l <= 0.86 else "")
            print(f"{path}:{line}\t{label}\tL={l:.2f}\tS={s:.2f}\t{kind}")
            if kind == "strong":
                strong.append(f"{path}:{line} {label}")
    if strong:
        print("\n強い色（明度 0.40〜0.65 かつ 彩度 >= 0.6）:", *strong, sep="\n- ")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
