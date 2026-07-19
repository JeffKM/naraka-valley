#!/usr/bin/env python3
"""Gemini 3지형 시트 → 씸리스 코히어런트 base 필드 3장(single_source/).
공유 팔레트 양자화(코히어런스) + 256→128 BOX 다운스케일 + 씸-힐링(엣지 wrap 블렌드).
재현: python3 extract_fields.py gemini_sheet.png  → ss_grass/dirt/water.png"""
import sys, math
from PIL import Image
src = sys.argv[1] if len(sys.argv) > 1 else 'gemini_sheet.png'
im = Image.open(src).convert('RGB')
pal = im.quantize(colors=28, method=Image.MEDIANCUT)   # 시트 전체 1팔레트 = 코히어런스
# 밴드 안쪽 256²(물은 좌측=✦ 회피). owner가 시트 바꾸면 좌표만 조정.
crops = {'grass': (300,60,556,316), 'dirt': (300,580,556,836), 'water': (120,1120,376,1376)}
def make_seamless(im2, b=14):
    im2 = im2.convert('RGBA'); px = im2.load(); W,H = im2.size; o = im2.copy(); oo = o.load()
    bl = lambda a,c,w: tuple(int(a[i]*(1-w)+c[i]*w) for i in range(4))
    for x in range(b):
        w = 0.5*(1-x/b)
        for y in range(H): oo[x,y]=bl(px[x,y],px[W-1-x,y],w); oo[W-1-x,y]=bl(px[W-1-x,y],px[x,y],w)
    t = [[oo[x,y] for x in range(W)] for y in range(H)]
    for y in range(b):
        w = 0.5*(1-y/b)
        for x in range(W): oo[x,y]=bl(t[y][x],t[H-1-y][x],w); oo[x,H-1-y]=bl(t[H-1-y][x],t[y][x],w)
    return o
for name, box in crops.items():
    c = im.crop(box).resize((128,128), Image.BOX).quantize(palette=pal, dither=Image.NONE).convert('RGBA')
    h = make_seamless(c,14).convert('RGB').quantize(palette=pal, dither=Image.NONE).convert('RGBA')
    h.save(f'ss_{name}.png')
    print(f'ss_{name}.png (128 seamless)')
