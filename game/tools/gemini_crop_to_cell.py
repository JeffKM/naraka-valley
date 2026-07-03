#!/usr/bin/env python3
# raw 작물/오브젝트 → 셀 크기 bottom-center 스프라이트 (ADR-0001 배치 글루).
#
# 왜 필요한가: raw는 큰 캔버스에 콘텐츠가 중앙 작게 놓여 여백이 크다.
#   process_chunky_phaseC.py는 bbox 크롭·앵커 없이 target으로 stretch만 해서 raw엔 안 맞는다.
#   이 글루는 배경 투명화 → 콘텐츠 bbox 크롭 → bottom-center 배치.
#
# ★ 선명도(2px 청크 예외, ADR-0047 §4): 작물은 PixelLab이 이미 32×32 네이티브 픽셀아트로
#   생성한다. 예전엔 ÷2 BOX→×2 로 "2px 청키화"했으나, 이는 해상도를 절반으로 죽이고 BOX가
#   색을 평균내 뭉개서 인게임 형태 가독성을 해쳤다(캐릭터가 겪은 문제와 동일). 그래서 작물도
#   캐릭터처럼 청크 캐논의 예외로 두고, 원본 픽셀을 1:1 보존한다: 절대 확대하지 않고,
#   셀을 초과할 때만 NEAREST로 축소(BOX 금지). threshold_alpha로 가장자리를 하드에지 정리.
#
# 사용: python3 tools/gemini_crop_to_cell.py <src.png> <dst.png> <cell_w> <cell_h>
#   트렐리스 작물 = 32 64 (밑동 접지·위로 1칸 솟음), 일반 작물 = 32 32.
import sys
from collections import deque
from PIL import Image


def strip_bg(im, tol=46):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    opaque = [c for c in corners if c[3] > 0]
    if not opaque:  # 이미 배경 투명(removebg) → 그대로
        return im
    sr = sum(c[0] for c in opaque) / len(opaque)
    sg = sum(c[1] for c in opaque) / len(opaque)
    sb = sum(c[2] for c in opaque) / len(opaque)

    def is_bg(p):
        return p[3] > 0 and ((p[0] - sr) ** 2 + (p[1] - sg) ** 2 + (p[2] - sb) ** 2) ** 0.5 <= tol

    visited = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if visited[i]:
            continue
        visited[i] = 1
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    return im


def threshold_alpha(im, t=128):
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= t else 0)
    return im


def process(src, dst, cell_w, cell_h):
    im = strip_bg(Image.open(src))
    bbox = im.getbbox()  # 알파>0 콘텐츠 bbox
    if bbox:
        im = im.crop(bbox)
    cw, ch = im.size
    # 네이티브 1:1 — 절대 확대 안 함(scale≤1). 셀을 초과할 때만 NEAREST 축소(BOX 금지 = 색 뭉갬 방지).
    scale = min(cell_w / cw, cell_h / ch, 1.0)
    nw, nh = max(1, round(cw * scale)), max(1, round(ch * scale))
    if (nw, nh) != (cw, ch):
        im = im.resize((nw, nh), Image.NEAREST)
    im = threshold_alpha(im)  # 반투명 가장자리 → 하드에지(선명 윤곽)
    # bottom-center 배치 (셀 하단 접지)
    canvas = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((cell_w - nw) // 2, cell_h - nh))
    canvas.save(dst)
    return (cw, ch), canvas.size


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("usage: gemini_crop_to_cell.py <src.png> <dst.png> <cell_w> <cell_h>")
        sys.exit(1)
    src, dst, cw, ch = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    (scw, sch), osz = process(src, dst, cw, ch)
    print(f"  {src} (content {scw}x{sch}) -> {osz[0]}x{osz[1]} {dst}")
