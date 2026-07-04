#!/usr/bin/env python3
# debris v5 — 볼드: 팔레트 축소 + 하드 실루엣 외곽선. 잡초는 NEAREST 축소(페탈 결 보존).
import sys
from PIL import Image, ImageDraw

ST = "assets/props/_debris16_staging"
GRASS = "assets/terrain16/grass_field.png"

def hexes(*hs): return [tuple(int(h[i:i+2],16) for i in (1,3,5)) for h in hs]

# 첫 원소 = 외곽선(가장 어두움). 값 수를 줄여 볼드하게.
PAL = {
 "weeds": hexes("#04180f","#0a3d1c","#1c7a2e","#4fb43e","#9ee06a","#c8a828"),
 "ember": hexes("#241820","#4c3644","#786060","#a08c8c","#cabaBa","#d8802e"),
 "stump": hexes("#241009","#5a2c16","#8a4a22","#b87038","#e6bc84"),
}
DOWN = {"weeds": Image.NEAREST, "ember": Image.BOX, "stump": Image.BOX}

def snap(rgb, pal):
    r,g,b=rgb; return min(pal, key=lambda c:(c[0]-r)**2+(c[1]-g)**2+(c[2]-b)**2)

def outline_pass(im, oc):
    px=im.load(); w,h=im.size; edges=[]
    for y in range(h):
        for x in range(w):
            if px[x,y][3]==0: continue
            for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                nx,ny=x+dx,y+dy
                if nx<0 or ny<0 or nx>=w or ny>=h or px[nx,ny][3]==0:
                    edges.append((x,y)); break
    for x,y in edges: px[x,y]=(oc[0],oc[1],oc[2],255)
    return im

def to16(raw, t):
    pal=PAL[t]; im=raw.convert("RGBA").resize((16,16), DOWN[t]); px=im.load()
    for y in range(16):
        for x in range(16):
            r,g,b,a=px[x,y]
            if a<110: px[x,y]=(0,0,0,0)
            else:
                nr,ng,nb=snap((r,g,b),pal); px[x,y]=(nr,ng,nb,255)
    im=outline_pass(im, pal[0])       # 실루엣 하드 외곽선
    return im.resize((32,32), Image.NEAREST)

finals={}
for t in ("weeds","ember","stump"):
    for v in (1,2,3):
        p=f"{ST}/v5_{t}_{v}.png"
        raw=Image.open(p); fin=to16(raw,t); fin.save(f"{ST}/final_{t}_v{v}.png"); finals[(t,v)]=fin

grass=Image.open(GRASS).convert("RGBA"); tile=grass.crop((0,0,32,32))
Z=7; cell=32*Z; padx,pady=16,40; lblw=96
W=lblw+3*(cell+padx)+padx; H=pady+3*(cell+pady)
sheet=Image.new("RGBA",(W,H),(24,22,26,255)); dr=ImageDraw.Draw(sheet)
dr.text((padx,12),"DEBRIS v5 BOLD (outline+reduced palette)  x7  weeds=scythe ember=pickaxe log=axe",fill=(220,210,200,255))
for ri,t in enumerate(("weeds","ember","stump")):
    cy=pady+ri*(cell+pady); dr.text((padx,cy+cell//2-8),t,fill=(230,200,160,255))
    for ci,v in enumerate((1,2,3)):
        cx=lblw+padx+ci*(cell+padx); base=tile.copy(); base.alpha_composite(finals[(t,v)])
        sheet.paste(base.resize((cell,cell),Image.NEAREST),(cx,cy))
        dr.rectangle([cx,cy,cx+cell-1,cy+cell-1],outline=(90,80,70,255))
        if ri==0: dr.text((cx+cell//2-10,pady-22),f"v{v}",fill=(200,200,210,255))
sheet.save(f"{ST}/_CONTACT_SHEET_v5.png"); print("done")
