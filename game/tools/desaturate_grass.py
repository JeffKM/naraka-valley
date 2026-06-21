#!/usr/bin/env python3
"""P2.3 풀 채도 하향(ADR-0001 허용 색보정 글루 = Aseprite 보정에 해당).

PixelLab 전환 타일셋의 *녹색 계열* 픽셀만 골라 채도·명도를 낮춰 저승 묘지 톤으로
당긴다(P2.0 발견 '풀 채도 과함 #10c800 → 하향 1순위' 이행). 흙(갈색)은 hue로 가려
보존한다. 원본은 *_raw.png로 한 번만 백업해 재실행해도 같은 결과(idempotent).
사용: python3 tools/desaturate_grass.py
"""
import colorsys
import os
from PIL import Image

# 녹색 픽셀 보정 계수
HUE_LO, HUE_HI = 80, 175      # 녹색~청록 계열(도)
SAT_MUL = 0.55                # 채도 ↓(순녹 → 이끼/올리브)
VAL_MUL = 0.82                # 명도 살짝 ↓(저승의 가라앉은 톤)

HERE = os.path.dirname(os.path.abspath(__file__))
TILES = os.path.join(HERE, "..", "assets", "tiles")
TARGETS = ["grass_path_image.png", "soil_grass_image.png"]


def desaturate(path: str) -> int:
    raw = path.replace(".png", "_raw.png")
    if not os.path.exists(raw):
        Image.open(path).save(raw)          # 최초 1회 원본 백업
    im = Image.open(raw).convert("RGBA")    # 항상 원본에서 출발(idempotent)
    px = im.load()
    touched = 0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if HUE_LO <= h * 360 <= HUE_HI and s > 0.15:
                nr, ng, nb = colorsys.hsv_to_rgb(h, s * SAT_MUL, v * VAL_MUL)
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
                touched += 1
    im.save(path)
    return touched


for name in TARGETS:
    p = os.path.join(TILES, name)
    n = desaturate(p)
    print(f"{name}: {n} green px 보정")
print("done")
