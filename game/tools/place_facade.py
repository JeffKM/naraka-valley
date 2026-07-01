#!/usr/bin/env python3
# 글루(ADR-0001) — PixelLab 산출 건물 facade를 2px 청크 캐논(ADR-0036)에 맞춰 배치.
#  ① 이미 투명 배경(PixelLab) — bg strip 불필요.
#  ② 청크화: ÷2 BOX(색 평균) → 알파 임계 → ×2 NEAREST (기존 본가·창고·축사 chunkiness=1.00과 정합).
#  ③ 내용 bbox 트림(art 바텀 = 건물 밑단 — _blit_facade_anchored bottom-center 앵커의 전제).
# 사용: python3 tools/place_facade.py <src.png> <dst_ext.png>
import sys
from PIL import Image


def threshold_alpha(im, t=128):
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= t else 0)
    return im


def chunkify(im):
    w, h = im.size
    half = im.resize((max(1, w // 2), max(1, h // 2)), Image.BOX)
    half = threshold_alpha(half)
    return half.resize((w, h), Image.NEAREST)


def main(src, dst):
    im = Image.open(src).convert("RGBA")
    im = chunkify(im)
    bbox = im.getbbox()          # 투명 아닌 내용 경계
    if bbox:
        im = im.crop(bbox)
    im.save(dst)
    print(f"  {src} -> {dst}  ({im.size[0]}x{im.size[1]})")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
