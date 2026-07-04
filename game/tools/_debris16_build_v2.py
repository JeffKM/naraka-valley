#!/usr/bin/env python3
# debris v2 — 이중블러 제거 파이프라인. raw64 → 16(단일 다운스케일) → 대비보강 → ×2 NEAREST(=32px,16논리).
import os
from PIL import Image, ImageEnhance

ST = "assets/props/_debris16_staging"
GRASS = "assets/terrain16/grass_field.png"

def to16(raw):
    # 64 → 16 단일 BOX(부드러운 축소) → 채도/대비 살짝 부스트 → 알파 하드에지 → ×2 NEAREST.
    im = raw.convert("RGBA").resize((16, 16), Image.BOX)
    rgb = Image.merge("RGB", im.split()[:3])
    rgb = ImageEnhance.Color(rgb).enhance(1.25)          # 채도 +25%
    rgb = ImageEnhance.Contrast(rgb).enhance(1.12)       # 대비 +12%
    r, g, b = rgb.split(); a = im.split()[3]
    a = a.point(lambda v: 255 if v >= 110 else 0)        # 알파 하드에지(반투명 테두리 제거)
    im16 = Image.merge("RGBA", (r, g, b, a))
    return im16.resize((32, 32), Image.NEAREST)          # 2px 청키·16논리

types = ["weeds", "ember", "stump"]
finals = {}
for t in types:
    for v in (1, 2, 3):
        raw = Image.open(f"{ST}/v2_{t}_{v}.png")
        fin = to16(raw); fin.save(f"{ST}/final_{t}_v{v}.png"); finals[(t, v)] = fin

grass = Image.open(GRASS).convert("RGBA")
tile = grass.crop((0, 0, 32, 32))

Z = 7; cell = 32 * Z; padx, pady = 16, 40; lblw = 96
W = lblw + 3 * (cell + padx) + padx; H = pady + 3 * (cell + pady)
sheet = Image.new("RGBA", (W, H), (24, 22, 26, 255))
from PIL import ImageDraw
dr = ImageDraw.Draw(sheet)
dr.text((padx, 12), "DEBRIS v2 — 16-logical on grass tile  x7  (weeds=scythe / ember=pickaxe / log=axe)", fill=(220, 210, 200, 255))
for ri, t in enumerate(types):
    cy = pady + ri * (cell + pady)
    dr.text((padx, cy + cell // 2 - 8), t, fill=(230, 200, 160, 255))
    for ci, v in enumerate((1, 2, 3)):
        cx = lblw + padx + ci * (cell + padx)
        base = tile.copy(); base.alpha_composite(finals[(t, v)])
        sheet.paste(base.resize((cell, cell), Image.NEAREST), (cx, cy))
        dr.rectangle([cx, cy, cx + cell - 1, cy + cell - 1], outline=(90, 80, 70, 255))
        if ri == 0:
            dr.text((cx + cell // 2 - 10, pady - 22), f"v{v}", fill=(200, 200, 210, 255))
sheet.save(f"{ST}/_CONTACT_SHEET_v2.png")
print("finals:", ", ".join(f"{t}_v{v}" for (t, v) in finals))
print("sheet:", sheet.size)
