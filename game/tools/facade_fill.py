#!/usr/bin/env python3
# ★ Phase 2.8 외관 full-bleed 글루(ADR-0001 허용 = 받기·임포트 단계, 변환 엔진 아님).
#
# PixelLab create_map_object 외관 생성본은 (a) 투명 배경이거나 (b) 다운로드 시 단색 배경(회색)으로
# 플래튼돼 온다. 둘 다 그대로 WALL 박스 위에 그리면 박스가 어두운/회색으로 새 보인다(T3① "어두운 박스").
# 이 스크립트는 *경계에서 flood-fill*로 배경(투명 또는 경계 지배색)만 피안절 풀색(#417331)으로 바꿔
# 건물만 남기고 full-bleed화한다(storehouse/barn 컨벤션 일치). 건물 내부의 비슷한 색은 경계와 안 이어져
# 보존된다(flood-fill 안전).
#
# 사용: python3 facade_fill.py <in.png> <out.png> [tol]
import sys
from collections import deque
from PIL import Image

GRASS = (65, 115, 49, 255)   # 피안절 풀색 #417331 (storehouse/barn 외관 배경과 동일)


def main() -> None:
    if len(sys.argv) < 3:
        print("usage: facade_fill.py <in.png> <out.png> [tol]")
        raise SystemExit(1)
    src, dst = sys.argv[1], sys.argv[2]
    tol = int(sys.argv[3]) if len(sys.argv) >= 4 else 30
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    px = im.load()

    # 경계 지배색 = 배경색 추정(투명이면 알파<16을 배경으로).
    from collections import Counter
    border = Counter()
    for x in range(w):
        border[px[x, 0]] += 1
        border[px[x, h - 1]] += 1
    for y in range(h):
        border[px[0, y]] += 1
        border[px[w - 1, y]] += 1
    bg = border.most_common(1)[0][0]
    bg_transparent = bg[3] < 16

    def is_bg(c):
        if bg_transparent:
            return c[3] < 16
        if c[3] < 16:
            return True
        return max(abs(c[0] - bg[0]), abs(c[1] - bg[1]), abs(c[2] - bg[2])) <= tol

    # 경계에서 BFS flood-fill — 배경과 이어진 칸만 풀색으로.
    seen = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_bg(px[x, y]) and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_bg(px[x, y]) and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    filled = 0
    while q:
        x, y = q.popleft()
        px[x, y] = GRASS
        filled += 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and is_bg(px[nx, ny]):
                seen[ny][nx] = True
                q.append((nx, ny))

    im.save(dst)
    print(f"{src} {w}x{h} bg={bg} transparent={bg_transparent} -> {dst} (filled {filled}px grass)")


if __name__ == "__main__":
    main()
