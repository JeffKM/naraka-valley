#!/usr/bin/env python3
# Phase C 글루(ADR-0001 허용 보정) — PixelLab가 "transparent"라 보고하지만 실제 다운로드 PNG는
# 불투명 회색(~141,136,140) 배경이라 인게임에서 건물이 회색 패드 위에 떠 보인다. 엣지에서 flood-fill로
# 배경과 연결된 회색만 투명화한다(단색 외곽선이 경계라 건물 내부 회색·창은 보존). 풀에 융화시키는 목적.
import sys
from collections import deque
from PIL import Image

def strip(src_path, dst_path, tol=46):
    im = Image.open(src_path).convert("RGBA")
    w, h = im.size
    px = im.load()
    # 배경 시드 = 네 코너 평균(균일 배경 가정)
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    sr = sum(c[0] for c in corners) / 4
    sg = sum(c[1] for c in corners) / 4
    sb = sum(c[2] for c in corners) / 4

    def is_bg(p):
        return p[3] > 0 and ((p[0]-sr)**2 + (p[1]-sg)**2 + (p[2]-sb)**2) ** 0.5 <= tol

    visited = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            q.append((x, y))
    cleared = 0
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
        cleared += 1
        q.extend([(x+1, y), (x-1, y), (x, y+1), (x, y-1)])
    im.save(dst_path)
    return w, h, cleared

if __name__ == "__main__":
    # (src, dst) 쌍 — 인자로 받음
    args = sys.argv[1:]
    for j in range(0, len(args), 2):
        w, h, c = strip(args[j], args[j + 1])
        print(f"  {args[j].split('/')[-1]} {w}x{h} cleared={c} -> {args[j+1].split('/')[-1]}")
