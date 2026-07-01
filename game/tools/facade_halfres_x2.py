#!/usr/bin/env python3
# 글루(ADR-0001) — PixelLab로 생성한 *half-res 네이티브* 건물 facade를 본가와 동일 파이프라인
# (half-res → ×2 NEAREST)으로 굳혀 2px 청크 캐논([asset-ruleset §0.1])을 지키면서도 선명하게 배치.
#
# ★왜 place_facade.py(÷2 청키화)를 안 쓰나 (2026-07-02, owner 확정 A안):
#   place_facade는 *풀해상* 원본을 ÷2로 줄여 2px 블록을 만드는데, 이 ÷2 다운샘플이 선명한 기와·
#   판자결을 뭉갠다(창고·축사가 본가보다 흐릿·뭉툭해 보인 진범). 본가는 애초에 half-res(house_src
#   144px)로 생성돼 ÷2 뭉갬 없이 ×2만 거쳐 선명하다. 창고·축사도 half-res로 *재생성*하면 같은 결과 —
#   2px 캐논 준수 + 본가급 선명도. (B=÷2 청키화는 캐논O·선명X, C=원본 1px는 선명O·캐논X, A=이 경로가 둘 다O.)
#
# 파이프라인: half-res PNG → 알파 하드 임계 → ×2 NEAREST → 내용 bbox 트림(art 바텀=밑단).
# 사용: python3 tools/facade_halfres_x2.py <halfres_src.png> <dst_ext.png>
import sys
from PIL import Image


def main(src, dst):
    im = Image.open(src).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= 128 else 0)   # 반투명 잔재 → 하드 알파
    out = im.resize((w * 2, h * 2), Image.NEAREST)          # half-res → ×2 (본가와 동일)
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)                                 # art 바텀 = 건물 밑단(_blit_facade_anchored 앵커 전제)
    out.save(dst)
    n = len({c for c in out.getdata() if c[3] > 0})
    print(f"  {src} -> {dst}  ({out.size[0]}x{out.size[1]}, {n} colors)")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
