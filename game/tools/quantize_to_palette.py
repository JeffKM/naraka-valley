#!/usr/bin/env python3
"""마스터 팔레트 warm 베이스 리컬러 + 청키화 (asset-ruleset §16 / §0).

기존 바닥 전환 타일셋(풀↔길·길↔밭·밭↔풀·물↔풀)의 *_raw.png(원본 candy/저승톤)를
docs/design/master-palette.md의 확정 warm 램프(풀=C warm-moss / 흙길 / 밭흙)로 리컬러한 뒤
청키화(÷2 BOX → ×2 nearest = 2px 블록, §0 16논리×2)한다.

ADR-0001 허용 글루(색보정·임포트). 변환 엔진 제작 아님. 원본 _raw.png는 건드리지 않아 idempotent.

리컬러 규율:
- 픽셀을 hue로 분류 → 재질 램프에 value 버킷으로 매핑(원본 음영 구조 보존).
  - green(70~175°)  → GRASS_C
  - earth(≤60° or ≥300°) → EARTH(=SOIL+DIRT를 luminance로 합친 통합 램프) — dirt는 밝아 위쪽, soil은 어두워 아래쪽으로 자연 분리
  - blue/teal(175~250°) → 물(영혼빛) 보존(§3.4b)
  - 매우 어두운 저채도 → 외곽선 #401818
- value 매핑은 절대 범위 클램프(green 0.28~0.72 / earth 0.14~0.78)로 안정적.

사용: python3 tools/quantize_to_palette.py
"""
import colorsys
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TILES = os.path.join(HERE, "..", "assets", "tiles")


def hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h / 360, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))


# === 확정 warm 램프 (master-palette.md 잠금, dark→light) ===
GRASS_C = [hsv(*c) for c in [(100, .55, .28), (98, .52, .40), (96, .50, .50), (92, .46, .60), (88, .42, .70)]]
DIRT = [hsv(*c) for c in [(24, .50, .32), (22, .48, .45), (20, .46, .56), (22, .40, .66), (26, .34, .74)]]
SOIL = [hsv(*c) for c in [(20, .55, .20), (18, .52, .28), (16, .50, .36), (20, .42, .45), (24, .34, .54)]]
OUTLINE = (0x40, 0x18, 0x18)

# EARTH 통합 램프 = SOIL(어두움) + DIRT(밝음)를 perceived luminance로 정렬.
def _lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
EARTH = sorted(SOIL + DIRT, key=_lum)


def _bucket(v, lo, hi, ramp):
    """value v를 [lo,hi] 정규화 → ramp 인덱스(원본 음영 보존)."""
    t = (v - lo) / (hi - lo)
    t = max(0.0, min(1.0, t))
    idx = int(round(t * (len(ramp) - 1)))
    return ramp[idx]


def recolor_pixel(r, g, b, earth_ramp):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    hd = h * 360
    # 매우 어두운 저채도 = 외곽선/깊은 그림자
    if v < 0.16 and s < 0.45:
        return OUTLINE
    # 영혼빛 물(보존) — 청록 물(hue~162)은 풀(최대 ~147)과 153°에서 분리
    if 153 <= hd <= 255 and s > 0.12:
        return (r, g, b)
    # 녹색 → GRASS_C
    if 70 <= hd < 153 and s > 0.12:
        return _bucket(v, 0.28, 0.72, GRASS_C)
    # 흙/밭 (red~yellow-brown) → EARTH
    if hd <= 60 or hd >= 300:
        return _bucket(v, 0.14, 0.78, earth_ramp)
    # 그 외(채도 낮은 회색조) = 명도로 earth에 흡수
    return _bucket(v, 0.14, 0.78, earth_ramp)


def chunkify(im):
    """÷2 BOX → 알파 임계 → ×2 nearest = 2px 블록(§0 청키)."""
    w, h = im.size
    small = im.resize((w // 2, h // 2), Image.BOX)
    # 알파 하드 임계(§8.1 헤일로 방지)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= 128 else 0)
    return small.resize((w, h), Image.NEAREST)


# 파일별: earth 램프 선택(grass_path=DIRT만 / soil_grass=SOIL만 / path_soil·water_grass는 통합 EARTH)
CONFIG = {
    "grass_path_image.png": DIRT,
    "soil_grass_image.png": SOIL,
    "path_soil_image.png": EARTH,
    "water_grass_image.png": EARTH,  # 물은 hue로 보존, 잔여 흙빛 거의 없음
}


def process(name, earth_ramp):
    path = os.path.join(TILES, name)
    raw = path.replace(".png", "_raw.png")
    if not os.path.exists(raw):
        Image.open(path).save(raw)  # 최초 1회 원본 백업
    im = Image.open(raw).convert("RGBA")
    px = im.load()
    touched = 0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            nr, ng, nb = recolor_pixel(r, g, b, earth_ramp)
            if (nr, ng, nb) != (r, g, b):
                touched += 1
            px[x, y] = (nr, ng, nb, a)
    im = chunkify(im)
    im.save(path)
    return touched


for name, ramp in CONFIG.items():
    n = process(name, ramp)
    print(f"{name}: recolor {n}px + chunkify → {os.path.basename(name)}")
print("done — 다음: 컨버터 재실행으로 combined_terrain_homestead.tres 재굽기")
