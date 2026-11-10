#!/usr/bin/env python3
"""CI のスクリーンショットで、機械的に見つけられる不具合を探す（黒い丸・まっ黒な画面）。
使い方: python3 scripts/shot-check.py <screenshots を展開したフォルダ>
見つかれば exit 1。自己申告ではなく、この結果を今日の Issue に貼る。"""
import sys, glob, os
from PIL import Image
def dark_ratio(im, box):
    reg = im.crop(box).convert('L'); px = list(reg.tobytes())
    return sum(1 for p in px if p < 30) / max(1, len(px))
bad = []
for f in sorted(glob.glob(os.path.join(sys.argv[1], '**', '*.png'), recursive=True)):
    im = Image.open(f); w, h = im.size; name = os.path.basename(f)
    whole = dark_ratio(im.resize((w // 8, h // 8)), (0, 0, w // 8, h // 8))
    if whole > 0.97:
        bad.append(f"{name}: 画面がほぼまっ黒（{whole:.0%}）"); continue
    y0, y1 = int(h * .02), int(h * .12)
    r = dark_ratio(im, (int(w * .80), y0, int(w * .97), y1))
    bg = dark_ratio(im, (int(w * .50), y0, int(w * .70), y1))
    if r > 0.08 and bg < 0.02:
        bad.append(f"{name}: 右上に黒い丸（暗い画素 {r:.0%}）。TabView(.page)・repeatForever を疑う")
for b in bad: print(b)
print(f"検査した画面: {len(glob.glob(os.path.join(sys.argv[1], '**', '*.png'), recursive=True))}、見つかった問題: {len(bad)}")
sys.exit(1 if bad else 0)
