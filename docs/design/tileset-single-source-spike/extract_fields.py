#!/usr/bin/env python3
"""Gemini 소스 → 씸리스 코히어런트 base 필드(single_source/).
grass = gemini_grass2.png(대비·톤패치 개선본, NEAREST=블레이드), dirt/water = gemini_sheet.png(BOX).
공유 팔레트 = [grass + 시트 dirt밴드 + 시트 water밴드] 몽타주 64색(코히어런스). 씸-힐링(엣지 wrap).
재현: python3 extract_fields.py"""
import math
from PIL import Image, ImageFilter
grass = Image.open('gemini_grass2.png').convert('RGB')
sheet = Image.open('gemini_sheet.png').convert('RGB')
GW, GH = grass.size
mont = Image.new('RGB', (768, 768*3))
mont.paste(grass.resize((768,768)), (0,0))
mont.paste(sheet.crop((0,532,2816,1045)).resize((768,768)), (0,768))
mont.paste(sheet.crop((0,1064,2816,1536)).resize((768,768)), (0,1536))
pal = mont.quantize(colors=64, method=Image.MEDIANCUT)
def seamless(im, b=12):
    im = im.convert('RGBA'); px = im.load(); W,H = im.size; o = im.copy(); oo = o.load()
    bl = lambda a,c,w: tuple(int(a[i]*(1-w)+c[i]*w) for i in range(4))
    for x in range(b):
        w = 0.5*(1-x/b)
        for y in range(H): oo[x,y]=bl(px[x,y],px[W-1-x,y],w); oo[W-1-x,y]=bl(px[W-1-x,y],px[x,y],w)
    t = [[oo[x,y] for x in range(W)] for y in range(H)]
    for y in range(b):
        w = 0.5*(1-y/b)
        for x in range(W): oo[x,y]=bl(t[y][x],t[H-1-y][x],w); oo[x,H-1-y]=bl(t[H-1-y][x],t[y][x],w)
    return o
def flatten(im, radius=24):
    """high-pass: 큰 톤패치 제거(블레이드 유지) → 타일정렬 색블록(네모) 방지. out=px-blur+mean."""
    im=im.convert('RGB'); W,H=im.size; px=im.load(); bx=im.filter(ImageFilter.GaussianBlur(radius)).load()
    n=W*H; mean=[sum(px[x,y][i] for y in range(H) for x in range(W))/n for i in range(3)]
    o=Image.new('RGB',(W,H)); oo=o.load()
    for y in range(H):
        for x in range(W): oo[x,y]=tuple(max(0,min(255,int(px[x,y][i]-bx[x,y][i]+mean[i]))) for i in range(3))
    return o

def field(imgsrc, box, method, flat=False):
    c = imgsrc.crop(box).resize((128,128), method)
    if flat: c = flatten(c, 24)
    c = c.quantize(palette=pal, dither=Image.NONE).convert('RGBA')
    return seamless(c,12).convert('RGB').quantize(palette=pal, dither=Image.NONE).convert('RGBA')
S = int(GH*0.26)
field(grass, (int(GW*0.55),int(GH*0.02),int(GW*0.55)+S,int(GH*0.02)+S), Image.NEAREST, flat=True).save('ss_grass.png')
field(sheet, (300,580,556,836), Image.BOX).save('ss_dirt.png')
field(sheet, (120,1120,376,1376), Image.BOX).save('ss_water.png')
print('ss_grass/dirt/water.png (128 seamless, 64-shared pal)')
