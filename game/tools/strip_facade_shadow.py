#!/usr/bin/env python3
# 건물 facade 구운 접지 그림자 제거 — 반투명 픽셀 컷 (ADR-0001 배치 글루).
#
# 왜 필요한가: Gemini facade가 하단에 반투명 회색 접지 그림자를 구워온다. FRAMING 규약
#   (gemini-building-prompt §1)은 "no cast shadow baked in — 접지 그림자는 엔진이 그림".
#   gemini_facade_to_chunky의 ③ 알파 임계(v>=128)로는 진한 그림자(α~224)가 살아남고,
#   ① bbox가 그 그림자까지 잡아 건물이 붕 떠 보인다(앵커=밑단 전제 위반).
#
# 판정: 건물 본체는 불투명(α=255), 구운 그림자·AA 헤일로는 반투명(0<α<T)이라 알파 임계로
#   그림자만 깎는다. 경계 AA도 함께 깎이지만 facade_to_chunky가 어차피 하드에지(§0.1)로
#   굳히므로 무해. facade_to_chunky **앞단**에 통과시킨다.
#
# 사용: python3 tools/strip_facade_shadow.py <src> <dst> [threshold=250]
import sys
from PIL import Image


def main() -> None:
    if len(sys.argv) < 3:
        print("usage: strip_facade_shadow.py <src> <dst> [threshold]")
        sys.exit(1)
    src, dst = sys.argv[1], sys.argv[2]
    thr = int(sys.argv[3]) if len(sys.argv) > 3 else 250
    im = Image.open(src).convert("RGBA")
    px = im.load()
    W, H = im.size
    n = 0
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            if 0 < a < thr:
                px[x, y] = (r, g, b, 0)
                n += 1
    im.save(dst)
    print(f"  {src.split('/')[-1]} -> {dst.split('/')[-1]} (반투명 제거 {n}px, T={thr})")


if __name__ == "__main__":
    main()
