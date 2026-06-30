#!/usr/bin/env python3
"""지면 타일 *부드러운* warm 보정 ([ADR-0042]) — 청키(÷2)·하드 5색 스냅 폐기.

기존 quantize_to_palette.py는 5색 램프 nearest 스냅 + ÷2 청키화로 *과장되게 울퉁불퉁·포스터화*된
타일을 만들었다(owner 지적). 이 도구는 PixelLab 원본(*_raw.png)의 **계조·디테일을 보존**한 채
부드러운 HSV 보정만 한다: 풀=candy green→warm-moss(저대비), 흙/밭=warm 갈색, 물=영혼빛 보존.
청키화 없음·하드 스냅 없음. ADR-0001 허용 색보정. idempotent(_raw에서 출발).

사용: python3 tools/recolor_ground_soft.py
"""
import colorsys
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TILES = os.path.join(HERE, "..", "assets", "tiles")
FILES = ["grass_path_image.png", "path_soil_image.png", "soil_grass_image.png", "water_grass_image.png"]


def soft_pixel(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    hd = h * 360
    # 어두운 저채도 = 외곽선/그림자(보존)
    if v < 0.13 and s < 0.5:
        return (r, g, b)
    # 영혼빛 물(보존) — 청록 162° 포함
    if 153 <= hd <= 255 and s > 0.12:
        return (r, g, b)
    # 풀(녹색) → warm-moss: hue를 90°로 당기되 약간의 변주 유지, 채도 down, 명도 보존
    if 70 <= hd < 153 and s > 0.12:
        nh = 90 + (hd - 110) * 0.35           # 좁은 warm 범위로 수렴(계조 유지)
        ns = s * 0.46                          # 저채도(candy→muted)
        nv = v * 0.98
        nr, ng, nb = colorsys.hsv_to_rgb((nh % 360) / 360, ns, nv)
        return (int(nr * 255), int(ng * 255), int(nb * 255))
    # 흙/밭(red~yellow, 차가운 maroon 포함) → warm 갈색: hue 22°로 통일, 명도 보존
    if hd <= 60 or hd >= 300:
        ns = max(0.3, min(0.58, s * 0.85))
        nv = v
        nr, ng, nb = colorsys.hsv_to_rgb(22 / 360, ns, nv)
        return (int(nr * 255), int(ng * 255), int(nb * 255))
    # 그 외(회색조) 보존
    return (r, g, b)


def process(name):
    path = os.path.join(TILES, name)
    raw = path.replace(".png", "_raw.png")
    if not os.path.exists(raw):
        Image.open(path).save(raw)
    im = Image.open(raw).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            nr, ng, nb = soft_pixel(r, g, b)
            px[x, y] = (nr, ng, nb, a)
    im.save(path)   # 청키화·스냅 없이 그대로 저장(부드러움 유지)


for n in FILES:
    process(n)
    print(f"{n}: 부드러운 warm 보정(청키·스냅 없음)")
print("done — 컨버터 재실행으로 tres 재굽기 필요")
