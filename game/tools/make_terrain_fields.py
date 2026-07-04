#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
# 밭흙·저승물 16px 필드 텍스처 생성 (ADR-0049 슬라이스 A — 연못/밭 정식화).
#
# grass/dirt는 Gemini 필드지만, soil(밭 고랑)·water(저승 연못)는 구조적 패턴이라 절차 생성이
# 깔끔하다. 128px seamless(주기함수로 타일링 보장) + 새 소프트 룩(무외곽선·저대비·warm/spirit).
# home16_dump가 grass처럼 월드좌표 ×2 샘플(16 유효)로 필드 타일링.
#
# 팔레트(master-palette / CONTEXT): 밭흙 warm #332016..#896d5a / 저승물 spirit #2068e8→#60d8f0 저채도.
# 사용: cd game && python3 tools/make_terrain_fields.py   → _staging_tile16/{soil,water}_field.png
# ─────────────────────────────────────────────────────────────────────────────
import os, math
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
STAGE = os.path.normpath(os.path.join(HERE, "..", "assets", "_staging_tile16"))
F = 128

def h01(x, y, salt):
    n = ((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0x7fffffff
    return (n % 100000) / 100000.0

def lerp(a, b, t):
    return tuple(int(a[c] + (b[c] - a[c]) * t) for c in range(3))

def soil():
    # 다져진 밭흙 + 가로 고랑(ridge 밝게/groove 어둡게), warm 저채도. 고랑 주기=16px(=1 논리타일).
    groove = (0x33, 0x20, 0x16); base = (0x5b, 0x3a, 0x2d); ridge = (0x72, 0x52, 0x42)
    im = Image.new("RGB", (F, F)); px = im.load()
    period = 16.0
    for y in range(F):
        # 고랑 단면(사인) — seamless(F가 period의 정수배)
        s = math.sin(y / period * 2 * math.pi)           # -1..1
        row = lerp(groove, ridge, (s + 1) / 2)
        for x in range(F):
            n = h01(x, y, 21) - 0.5
            c = lerp(base, row, 0.6)                       # base와 고랑 톤 섞기
            c = tuple(max(0, min(255, c[k] + int(n * 14))) for k in range(3))
            # 드문 흙덩이(어두운 점)
            if h01(x, y, 22) > 0.985:
                c = groove
            px[x, y] = c
    return im

def water():
    # 저승 연못 — 저채도 딥 teal 베이스 + 완만한 가로 물결 밴드 + 드문 spirit 하이라이트 글린트.
    deep = (0x18, 0x3a, 0x4a); mid = (0x22, 0x54, 0x63); glint = (0x60, 0xd8, 0xf0)
    im = Image.new("RGB", (F, F)); px = im.load()
    for y in range(F):
        for x in range(F):
            # 두 주기 물결 합(seamless: 정수 파수)
            w = 0.5 + 0.25 * math.sin((x / F * 4 + y / F * 2) * 2 * math.pi) \
                    + 0.25 * math.sin((y / F * 6) * 2 * math.pi)
            c = lerp(deep, mid, max(0.0, min(1.0, w)))
            n = h01(x, y, 31) - 0.5
            c = tuple(max(0, min(255, c[k] + int(n * 8))) for k in range(3))
            # 저채도 spirit 윤슬(희소)
            if h01(x, y, 32) > 0.992:
                c = lerp(c, glint, 0.7)
            px[x, y] = c
    return im

def main():
    os.makedirs(STAGE, exist_ok=True)
    soil().save(os.path.join(STAGE, "soil_field.png"))
    water().save(os.path.join(STAGE, "water_field.png"))
    print("✅ soil_field.png / water_field.png (128², seamless, 새 16px 룩)")

if __name__ == "__main__":
    main()
