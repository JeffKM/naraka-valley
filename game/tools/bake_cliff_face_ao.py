#!/usr/bin/env python3
# ★[ADR-0056 ②] 절벽 FACE 원근 AO 베이크(glue·ADR-0001) — cliff_s_face.png에만 세로 감쇄 음영을
#   구워 넣는다(상단=고원 광원 원본 1.0 → 하단 16px로 은은히 감쇄). 코드(main.gd)는 안 건드리는
#   '아트 자산 교체' 트랙. cliff_s_base.png는 [cliff-tileset-spec §10.2] 단계1·2에서 접지 그림자가
#   이미 구워져 있어 **손대지 않는다**(이중 그림자 금지). 결정적·per-row 곱셈이라 strata 텍스처 보존.
#
# 사용: python3 tools/bake_cliff_face_ao.py   (game/ 기준). 실행 후 godot --headless --import 필요.
import sys
from PIL import Image

FACE = "assets/tiles/cliff_s_face.png"
STRENGTH = 0.24   # 하단 최대 감쇄율(1.0 - 0.24 = 0.76). 은은하게(스타듀 룩).
GAMMA = 2.0       # 곡선(높을수록 상단 평평·하단 집중 = "하단 16px로 갈수록").


def bake(path: str) -> None:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    for y in range(h):
        t = y / (h - 1) if h > 1 else 0.0
        factor = 1.0 - STRENGTH * (t ** GAMMA)   # y=0 → 1.0, y=h-1 → 1-STRENGTH
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            px[x, y] = (int(r * factor), int(g * factor), int(b * factor), a)
    im.save(path)
    print(f"  baked AO into {path} ({w}x{h}, strength={STRENGTH}, gamma={GAMMA})")


if __name__ == "__main__":
    bake(FACE)
    print("  ※ cliff_s_base.png = 접지 그림자 이미 존재 → 미변경(이중 금지)")
    print("  ※ 실행 후: godot --headless --import 로 .ctex 재생성 필요")
