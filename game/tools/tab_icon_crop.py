#!/usr/bin/env python3
# 탭 아이콘 글루 — PixelLab 128² 원본을 24×24 UI 아이콘으로 변환.
# 도구 아이콘(assets/tools/)과 동일 파이프라인: alpha bbox crop → BOX uniform-fit
# → 24×24 캔버스 중앙정렬 → 하드 알파(반투명 정리, 청키 픽셀 경계 보존).
# 사용: python3 tools/tab_icon_crop.py <src.png> <dst.png> [target] [pad]
import sys
from PIL import Image


def process(src: str, dst: str, target: int = 24, pad: int = 2) -> None:
    im = Image.open(src).convert("RGBA")
    # 1) 알파 bbox 크롭(피사체만 남김 — 여백 제거)
    mask = im.getchannel("A").point(lambda a: 255 if a > 40 else 0)
    bbox = mask.getbbox()
    if bbox:
        im = im.crop(bbox)
    # 2) uniform-fit(비율 유지, inner=target-2*pad 안에) — BOX 다운샘플(픽셀아트 축소)
    inner = target - 2 * pad
    w, h = im.size
    scale = min(inner / w, inner / h)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    im = im.resize((nw, nh), Image.BOX)
    # 3) 하드 알파(반투명 → 불투명/투명 이분, 청키 경계)
    a = im.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    im.putalpha(a)
    # 4) 24×24 투명 캔버스 중앙정렬
    canvas = Image.new("RGBA", (target, target), (0, 0, 0, 0))
    canvas.paste(im, ((target - nw) // 2, (target - nh) // 2), im)
    canvas.save(dst)
    print(f"{dst}  {canvas.size}  (content {nw}x{nh})")


if __name__ == "__main__":
    t = int(sys.argv[3]) if len(sys.argv) > 3 else 24
    p = int(sys.argv[4]) if len(sys.argv) > 4 else 2
    process(sys.argv[1], sys.argv[2], t, p)
