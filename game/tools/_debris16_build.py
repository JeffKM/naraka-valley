#!/usr/bin/env python3
# debris 16논리 파이프라인 + 대조 시트(임시 검사용, staging).
#  raw 64 → downscale 32(NEAREST) → chunkify(÷2 BOX+alpha thresh+×2 NEAREST=2px 청키/16논리).
import os
from PIL import Image, ImageDraw

ST = "assets/props/_debris16_staging"
GRASS = "assets/terrain16/grass_field.png"

def threshold_alpha(im, t=128):
    px = im.load(); w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= t else 0)
    return im

def chunkify(im):  # enforce_chunk.py 로직: ÷2 BOX → alpha thresh → ×2 NEAREST
    w, h = im.size
    half = im.resize((w // 2, h // 2), Image.BOX).convert("RGBA")
    half = threshold_alpha(half)
    return half.resize((w, h), Image.NEAREST)

types = [("weeds", "debris_weeds"), ("ember", "debris_ember_stone"), ("stump", "debris_petrified_stump")]
finals = {}  # (type,v) -> Image 32x32
for tname, _ in types:
    for v in (1, 2, 3):
        raw = Image.open(f"{ST}/raw_{tname}_{v}.png").convert("RGBA")
        d32 = raw.resize((32, 32), Image.NEAREST)      # 64→32
        fin = chunkify(d32)                            # 2px 청키(16논리)
        fin.save(f"{ST}/{tname}_v{v}_32.png")
        finals[(tname, v)] = fin

# 지면 타일 배경(32px crop)
grass = Image.open(GRASS).convert("RGBA")
tile = grass.crop((0, 0, 32, 32)) if grass.size >= (32, 32) else Image.new("RGBA", (32, 32), (74, 107, 61, 255))

# ── 대조 시트 ──────────────────────────────────────────────
Z = 7                      # 확대 배율
cell = 32 * Z              # 224
padx, pady = 16, 40
lblw = 96
cols, rows = 3, 3
W = lblw + cols * (cell + padx) + padx
H = pady + rows * (cell + pady)
sheet = Image.new("RGBA", (W, H), (24, 22, 26, 255))
dr = ImageDraw.Draw(sheet)
dr.text((padx, 12), "DEBRIS 16-logical (32px file, 2px chunky) on grass tile  x7", fill=(220, 210, 200, 255))
rlabel = {"weeds": "이승의미련\n(weeds/낫)", "ember": "업화석\n(ember/곡괭이)", "stump": "석화고목\n(stump/도끼)"}
for ri, (tname, _) in enumerate(types):
    cy = pady + ri * (cell + pady)
    dr.text((padx, cy + cell // 2 - 8), f"{tname}", fill=(230, 200, 160, 255))
    for ci, v in enumerate((1, 2, 3)):
        cx = lblw + padx + ci * (cell + padx)
        # 지면 위 합성 → 확대
        base = tile.copy()
        art = finals[(tname, v)]
        base.alpha_composite(art)
        big = base.resize((cell, cell), Image.NEAREST)
        sheet.paste(big, (cx, cy))
        dr.rectangle([cx, cy, cx + cell - 1, cy + cell - 1], outline=(90, 80, 70, 255))
        if ri == 0:
            dr.text((cx + cell // 2 - 10, pady - 22), f"v{v}", fill=(200, 200, 210, 255))
sheet.save(f"{ST}/_CONTACT_SHEET.png")
print("finals:", ", ".join(f"{t}_v{v}" for (t, v) in finals))
print("sheet:", f"{ST}/_CONTACT_SHEET.png", sheet.size)
