#!/usr/bin/env python3
# ★[ADR-0056 후속] 절벽 lip/코너의 초록을 평지 잔디(grass_field.png = _bf_grass) 톤에 맞춘다(glue·ADR-0001).
#   고지 평지를 잔디-지배로 바꾸자, 절벽 lip 에셋의 웜·밝은 초록이 평지의 쿨·차분한 초록과 안 맞아 "이어지는
#   타일과 다른 잔디"로 읽혔다(owner). _harmonize_grass_variants 결 — grass 픽셀만 평균을 field로 평행이동
#   (per-pixel 텍스처 변주는 그대로 보존, 평탄화 X). face/base의 흙·돌 픽셀은 안 건드림(초록만 대상).
#
# 사용: python3 tools/match_cliff_grass_to_field.py  (game/ 기준). 실행 후 godot --headless --import 필요.
from PIL import Image

FIELD = (60, 119, 83)   # grass_field.png 초록 평균(타깃 톤)
TARGETS = ["cliff_s_lip", "cliff_corner_sw", "cliff_corner_se",
           "cliff_corner_sw_b", "cliff_corner_se_b"]


def is_grass(r, g, b):
    return g > r and g > b   # 초록 우세 = 잔디 픽셀(흙·돌 제외)


def match(name):
    p = f"assets/tiles/{name}.png"
    im = Image.open(p).convert("RGBA")
    w, h = im.size
    px = im.load()
    rs = gs = bs = n = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a >= 128 and is_grass(r, g, b):
                rs += r; gs += g; bs += b; n += 1
    if n == 0:
        print(f"  {name}: 초록 없음 → 스킵")
        return
    mr, mg, mb = rs // n, gs // n, bs // n
    dr, dg, db = FIELD[0] - mr, FIELD[1] - mg, FIELD[2] - mb
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a >= 128 and is_grass(r, g, b):
                px[x, y] = (max(0, min(255, r + dr)),
                            max(0, min(255, g + dg)),
                            max(0, min(255, b + db)), a)
    im.save(p)
    print(f"  {name}: grass ({mr},{mg},{mb}) → field {FIELD}  Δ({dr:+d},{dg:+d},{db:+d})  {n}px")


if __name__ == "__main__":
    for t in TARGETS:
        match(t)
    print("  ※ 실행 후: godot --headless --import 로 .ctex 재생성 필요")
