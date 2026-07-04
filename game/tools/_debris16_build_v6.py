#!/usr/bin/env python3
# debris v6 — 32-native(디테일·부드러움). 64→32 BOX, 알파하드, 가벼운 정리(과한 양자화·하드청키 없음).
# 통나무는 ~35° 회전(32에선 대각선 읽힘). 잡초/바위는 원본 유지.
from PIL import Image, ImageDraw, ImageEnhance
ST="assets/props/_debris16_staging"; GRASS="assets/terrain16/grass_field.png"

def to32(raw):
    im=raw.convert("RGBA").resize((32,32), Image.BOX)
    rgb=im.convert("RGB"); rgb=ImageEnhance.Color(rgb).enhance(1.1); rgb=ImageEnhance.Contrast(rgb).enhance(1.06)
    q=rgb.quantize(colors=24, method=Image.MEDIANCUT).convert("RGB")   # 가벼운 정리(디테일 보존)
    r,g,b=q.split(); a=im.split()[3].point(lambda v:255 if v>=115 else 0)
    return Image.merge("RGBA",(r,g,b,a))

def rot(src, ang):
    im=Image.open(f"{ST}/{src}").convert("RGBA").rotate(ang, expand=True, resample=Image.BICUBIC)
    bb=im.getbbox(); im=im.crop(bb); s=max(im.size)
    cv=Image.new("RGBA",(s,s),(0,0,0,0)); cv.paste(im,((s-im.width)//2,(s-im.height)//2)); return cv

# 소스 준비
srcs={}
for t,fn in [("weeds",["v4_weeds_1.png","v4_weeds_2.png","v4_weeds_3.png"]),
             ("ember",["v4_ember_1.png","v4_ember_2.png","v4_ember_3.png"])]:
    for i,f in enumerate(fn,1): srcs[(t,i)]=Image.open(f"{ST}/{f}")
# 통나무 대각선: 2 왼쪽(-35) + 1 오른쪽(+35)
srcs[("stump",1)]=rot("branchsrc_1.png",-35); srcs[("stump",2)]=rot("branchsrc_2.png",-35); srcs[("stump",3)]=rot("branchsrc_3.png",35)

finals={}
for t in ("weeds","ember","stump"):
    for v in (1,2,3):
        fin=to32(srcs[(t,v)]); fin.save(f"{ST}/final32_{t}_v{v}.png"); finals[(t,v)]=fin

grass=Image.open(GRASS).convert("RGBA"); tile=grass.crop((0,0,32,32))
Z=7; cell=32*Z; padx,pady=16,40; lblw=96
W=lblw+3*(cell+padx)+padx; H=pady+3*(cell+pady)
sheet=Image.new("RGBA",(W,H),(24,22,26,255)); dr=ImageDraw.Draw(sheet)
dr.text((padx,12),"DEBRIS v6 — 32-native (detailed/soft)  x7  weeds=scythe ember=pickaxe log=axe",fill=(220,210,200,255))
for ri,t in enumerate(("weeds","ember","stump")):
    cy=pady+ri*(cell+pady); dr.text((padx,cy+cell//2-8),t,fill=(230,200,160,255))
    for ci,v in enumerate((1,2,3)):
        cx=lblw+padx+ci*(cell+padx); base=tile.copy(); base.alpha_composite(finals[(t,v)])
        sheet.paste(base.resize((cell,cell),Image.NEAREST),(cx,cy)); dr.rectangle([cx,cy,cx+cell-1,cy+cell-1],outline=(90,80,70,255))
        if ri==0: dr.text((cx+cell//2-10,pady-22),f"v{v}",fill=(200,200,210,255))
sheet.save(f"{ST}/_CONTACT_SHEET_v6.png"); print("done")
