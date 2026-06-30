#!/usr/bin/env python3
# Phase C 청키 파이프라인(ADR-0001 허용 글루). 스타듀식 굵은 도트 그레인을 위해:
#  ① 배경 투명화 — PixelLab가 "transparent"라 보고해도 큰 캔버스(특히 본가)는 불투명 회색 배경이라
#     엣지 flood-fill로 배경 연결 영역만 투명화(단색 외곽선이 경계라 내부 보존).
#  ② 청키화 — 1아트픽셀:1화면픽셀이면 알갱이가 곱다(MV/MZ 룩). 2px 블록 그레인으로:
#     - half-res 생성물(target의 절반)은 ×2 nearest 업스케일.
#     - 동일크기 생성물(32px 최소 제약으로 절반 생성 불가)은 ÷2(box)→알파 임계→×2 nearest in-place.
import sys
from collections import deque
from PIL import Image


def strip_bg(im, tol=46):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    corners = [px[0, 0], px[w-1, 0], px[0, h-1], px[w-1, h-1]]
    # 코너 중 불투명한 것만 시드(이미 투명이면 배경 제거 불필요)
    opaque = [c for c in corners if c[3] > 0]
    if not opaque:
        return im
    sr = sum(c[0] for c in opaque)/len(opaque)
    sg = sum(c[1] for c in opaque)/len(opaque)
    sb = sum(c[2] for c in opaque)/len(opaque)

    def is_bg(p):
        return p[3] > 0 and ((p[0]-sr)**2+(p[1]-sg)**2+(p[2]-sb)**2) ** 0.5 <= tol
    visited = bytearray(w*h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h-1))
    for y in range(h):
        q.append((0, y)); q.append((w-1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y*w+x
        if visited[i]:
            continue
        visited[i] = 1
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend([(x+1, y), (x-1, y), (x, y+1), (x, y-1)])
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


def process(src, dst, target_w, target_h, mode):
    im = strip_bg(Image.open(src))
    sw, sh = im.size
    if mode == "x2":
        # half-res 생성물 → ×2 nearest
        out = im.resize((target_w, target_h), Image.NEAREST)
    else:  # "chunk" — 동일크기 → ÷2 box(색 평균) → 알파 임계 → ×2 nearest
        half = im.resize((max(1, target_w//2), max(1, target_h//2)), Image.BOX)
        half = threshold_alpha(half)
        out = half.resize((target_w, target_h), Image.NEAREST)
    out.save(dst)
    return sw, sh, out.size


# manifest: src_key, dst_path, target_w, target_h, mode
MANIFEST = [
    ("house",      "assets/buildings/house_ext.png",        288, 256, "x2"),
    ("storehouse", "assets/buildings/storehouse_ext.png",   192, 192, "x2"),
    ("barn",       "assets/buildings/barn_ext.png",         192, 128, "x2"),
    ("rock",       "assets/props/rock.png",                  64,  64, "x2"),
    ("stump",      "assets/props/stump_log.png",             64,  32, "chunk"),
    ("fence",      "assets/props/farm_fence.png",            32,  32, "chunk"),
    ("scarecrow",  "assets/props/farm_scarecrow.png",        32,  64, "chunk"),
    ("planter",    "assets/props/farm_planter.png",          32,  32, "chunk"),
    ("flowerpatch","assets/props/spirit_flower_patch.png",   32,  32, "chunk"),
]

if __name__ == "__main__":
    base = "assets/_staging_phaseC/chunky"
    for key, dst, tw, th, mode in MANIFEST:
        sw, sh, osz = process(f"{base}/{key}_src.png", dst, tw, th, mode)
        print(f"  {key}: src {sw}x{sh} [{mode}] -> {osz[0]}x{osz[1]} {dst}")
