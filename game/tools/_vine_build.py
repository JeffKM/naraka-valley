#!/usr/bin/env python3
# 넝쿨(vine) 32-native 정규화: PixelLab 128 커튼 → 32×64 세로 드리움 드롭인
# 규약(roster §2·gemini §5.5): 크기 32×64 유지·투명배경·bottom-center·그림자 미포함·객체 외곽선 유지
from PIL import Image

RAW = 'assets/props/_vine_staging/vine_raw_128.png'
OUT = 'assets/props/_vine_staging/vine_32x64.png'

im = Image.open(RAW).convert('RGBA')
bbox = im.getbbox()               # 알파 콘텐츠 경계
im = im.crop(bbox)                # 105×123
w, h = im.size

# ① 종횡비 보존: 높이 64에 맞춤(넝쿨=세로 드리움이 정체성)
TH = 64
tw = max(1, round(w * TH / h))
im = im.resize((tw, TH), Image.BOX)   # 부드러운 축소(32-native, 하드청키 금지)

# ② 중앙 32폭 crop(좌우 잘라 절벽면 붙은 스트립화) — 넝쿨은 상단 무성/중앙 밀집이라 손실 최소
TW = 32
if tw >= TW:
    x0 = (tw - TW) // 2
    im = im.crop((x0, 0, x0 + TW, TH))
else:
    # 폭이 32 미만이면 중앙 배치 패딩
    canvas = Image.new('RGBA', (TW, TH), (0, 0, 0, 0))
    canvas.paste(im, ((TW - tw) // 2, 0))
    im = canvas

# ③ 경량 양자화(팔레트 정리, 부드러움 우선) — 반투명 가장자리는 알파 임계로 정돈
r, g, b, a = im.split()
a = a.point(lambda v: 0 if v < 24 else (255 if v > 220 else v))
im = Image.merge('RGBA', (r, g, b, a))

im.save(OUT)
print('out', im.size, 'src_bbox', bbox, 'scaled_w', tw)
# 알파 히스토그램 확인(세로 밀도)
px = im.load()
rows = []
for y in range(64):
    c = sum(1 for x in range(32) if px[x, y][3] > 40)
    rows.append(c)
print('alpha-per-row(0..63):', rows)
