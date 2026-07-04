#!/usr/bin/env python3
# debris v3 — 레퍼런스 팔레트 양자화. raw64 → 16(BOX) → 레퍼런스 팔레트 스냅 → 알파하드 → ×2 NEAREST.
import sys
from PIL import Image, ImageDraw

ST = "assets/props/_debris16_staging"
GRASS = "assets/terrain16/grass_field.png"

def hexes(*hs):
    return [tuple(int(h[i:i+2], 16) for i in (1, 3, 5)) for h in hs]

PAL = {
 "stump": hexes("#2a1610","#542418","#603018","#783c18","#844824","#905424","#a86024","#c07840","#d8a86c","#ecc890"),
 "ember": hexes("#241820","#48303c","#543c48","#604854","#786060","#846c6c","#907878","#a89494","#c0b0b0","#c05820","#e89040"),
 "weeds": hexes("#04180f","#003024","#0c3c24","#005424","#0c6024","#2a8a3a","#5ab84e","#8fd86a","#caa028"),
}

def snap(rgb, pal):
    r, g, b = rgb
    best = min(pal, key=lambda c: (c[0]-r)**2 + (c[1]-g)**2 + (c[2]-b)**2)
    return best

def to16(raw, pal):
    im = raw.convert("RGBA").resize((16, 16), Image.BOX)
    px = im.load()
    for y in range(16):
        for x in range(16):
            r, g, b, a = px[x, y]
            if a < 110:
                px[x, y] = (0, 0, 0, 0)
            else:
                nr, ng, nb = snap((r, g, b), pal)
                px[x, y] = (nr, ng, nb, 255)
    return im.resize((32, 32), Image.NEAREST)

RAW = {  # type -> object_id
 "weeds": "8d07f09e-0c75-405a-a73d-2f48f07d6ed7",
 "ember": "f279a170-28a8-45a4-b001-8bb0973be617",
 "stump": "7ce2bab9-a0f0-481f-b989-1af3a7f0bad6",
}
# picks 인자: type=idx,idx,idx (build 호출 시 넘김)
picks = eval(sys.argv[1]) if len(sys.argv) > 1 else {}

finals = {}
for t in ("weeds", "ember", "stump"):
    for v in (1, 2, 3):
        raw = Image.open(f"{ST}/v3_{t}_{v}.png")
        fin = to16(raw, PAL[t]); fin.save(f"{ST}/final_{t}_v{v}.png"); finals[(t, v)] = fin

grass = Image.open(GRASS).convert("RGBA"); tile = grass.crop((0, 0, 32, 32))
Z = 7; cell = 32*Z; padx, pady = 16, 40; lblw = 96
W = lblw + 3*(cell+padx) + padx; H = pady + 3*(cell+pady)
sheet = Image.new("RGBA", (W, H), (24, 22, 26, 255)); dr = ImageDraw.Draw(sheet)
dr.text((padx, 12), "DEBRIS v3 (ref-palette) on grass  x7  weeds=scythe ember=pickaxe log=axe", fill=(220,210,200,255))
for ri, t in enumerate(("weeds","ember","stump")):
    cy = pady + ri*(cell+pady); dr.text((padx, cy+cell//2-8), t, fill=(230,200,160,255))
    for ci, v in enumerate((1,2,3)):
        cx = lblw+padx+ci*(cell+padx); base = tile.copy(); base.alpha_composite(finals[(t,v)])
        sheet.paste(base.resize((cell,cell), Image.NEAREST), (cx, cy))
        dr.rectangle([cx,cy,cx+cell-1,cy+cell-1], outline=(90,80,70,255))
        if ri==0: dr.text((cx+cell//2-10, pady-22), f"v{v}", fill=(200,200,210,255))
sheet.save(f"{ST}/_CONTACT_SHEET_v3.png"); print("done", sheet.size)
