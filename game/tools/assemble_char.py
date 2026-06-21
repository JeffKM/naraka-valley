#!/usr/bin/env python3
"""PixelLab 캐릭터(방향별 개별 PNG) → CharSprite 시트 + hole-fill (글루, ADR-0001 허용).

PixelLab은 캐릭터를 시트가 아니라 방향별 개별 PNG로 준다(§4.4). v3는 8방향 출력이라
CharSprite 규약(4행 down/up/right/left = south/north/east/west)에 맞춰 4방향만 뽑아
한 시트로 합성한다. 워크는 방향당 N프레임, 대기(idle)는 방향당 1프레임.

배치(char_sprite.gd 규약): 48×48 프레임, 콘텐츠 발치를 y≈FOOT_Y(40)에, 가로 중앙 정렬.
v3 콘텐츠는 이미 ~28-30px 높이라 16×32 타겟에 맞아 *스케일 없이* 발치정렬만 한다(선명도 보존).

★ hole-fill(§5.2): PixelLab 프레임은 외곽선에 갇힌 투명 구멍을 남긴다(흰 꼬리·옷 속).
경계 flood-fill로 "외부 투명"과 "갇힌 hole"을 구분 → hole만 인접 불투명색으로 메운다.

사용:
  assemble_char.py <입력디렉터리> <출력.png>
  입력디렉터리 구조:
    idle : south.png north.png east.png west.png        (방향당 1장)
    walk : south/000.png 001.png ... , north/... 식 하위폴더(방향당 프레임 순번)
"""
from __future__ import annotations
import os
import sys
from collections import deque
from PIL import Image

ROW_DIRS = ["south", "north", "east", "west"]   # 시트 행 순서 = down/up/right/left
FRAME = 80         # standard size56 통일본 콘텐츠(최대 ~70px, 옥자 모자)+마진을 native로 담는 프레임
FOOT_Y = 76        # 콘텐츠 발치(아래)를 둘 y (char_sprite offset -36과 맞물림)
TARGET_H = 0       # >0이면 콘텐츠를 이 높이로 다운스케일(덩치 조절). 0=네이티브.


def hole_fill(im: Image.Image) -> Image.Image:
    """외곽선에 갇힌 투명 hole을 인접 불투명색으로 메워 새 이미지를 반환."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    outside = [[False] * w for _ in range(h)]
    q: deque = deque()

    def seed(x, y):
        if px[x, y][3] == 0 and not outside[y][x]:
            outside[y][x] = True
            q.append((x, y))

    for x in range(w):
        seed(x, 0); seed(x, h - 1)
    for y in range(h):
        seed(0, y); seed(w - 1, y)
    while q:
        cx, cy = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < w and 0 <= ny < h and not outside[ny][nx] and px[nx, ny][3] == 0:
                outside[ny][nx] = True
                q.append((nx, ny))
    holes = [(x, y) for y in range(h) for x in range(w)
             if px[x, y][3] == 0 and not outside[y][x]]
    guard = 0
    while holes and guard < 64:
        guard += 1
        remaining = []
        for x, y in holes:
            best = None
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] != 0:
                    best = px[nx, ny]; break
            if best is not None:
                px[x, y] = (best[0], best[1], best[2], 255)
            else:
                remaining.append((x, y))
        if len(remaining) == len(holes):
            break
        holes = remaining
    return im


def _union_bbox(cells):
    """여러 프레임의 콘텐츠를 모두 감싸는 공통 bbox(워크 사이클 움직임 보존)."""
    box = None
    for c in cells:
        bb = c.getbbox()
        if bb is None:
            continue
        box = bb if box is None else (
            min(box[0], bb[0]), min(box[1], bb[1]),
            max(box[2], bb[2]), max(box[3], bb[3]))
    return box


def place_dir(cells):
    """한 방향의 프레임들을 hole-fill → 공통 bbox로 크롭 → 48×48에 발치정렬(가로중앙).
    공통 bbox라 프레임 간 떨림 없이 사이클 내 상하 흔들림·팔다리 스윙이 보존된다."""
    cells = [hole_fill(c) for c in cells]
    box = _union_bbox(cells)
    out = []
    if box is None:
        return [Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0)) for _ in cells]
    bw, bh = box[2] - box[0], box[3] - box[1]
    scale = 1.0
    if TARGET_H > 0 and bh > 0:
        scale = TARGET_H / bh
        bw, bh = max(1, round(bw * scale)), max(1, round(bh * scale))
    ox = (FRAME - bw) // 2
    oy = max(0, FOOT_Y - bh)
    for c in cells:
        crop = c.crop(box)
        if scale != 1.0:
            crop = crop.resize((bw, bh), Image.LANCZOS)
        frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        frame.paste(crop, (ox, oy), crop)
        out.append(frame)
    return out


def _load_dir_frames(in_dir: str, d: str):
    sub = os.path.join(in_dir, d)
    if os.path.isdir(sub):
        files = sorted(f for f in os.listdir(sub) if f.endswith(".png"))
        return [os.path.join(sub, f) for f in files]
    flat = os.path.join(in_dir, d + ".png")
    return [flat] if os.path.exists(flat) else []


def main(argv) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    in_dir, out_path = argv[1], argv[2]
    if "--targeth" in argv:
        globals()["TARGET_H"] = int(argv[argv.index("--targeth") + 1])
    rows = {d: _load_dir_frames(in_dir, d) for d in ROW_DIRS}
    cols = max((len(v) for v in rows.values()), default=0)
    if cols == 0:
        print(f"  ! {in_dir}: 방향 PNG를 못 찾음")
        return 1

    sheet = Image.new("RGBA", (FRAME * cols, FRAME * len(ROW_DIRS)), (0, 0, 0, 0))
    for r, d in enumerate(ROW_DIRS):
        frames = rows[d]
        if not frames:
            print(f"  ! {os.path.basename(out_path)}: 방향 {d} 없음 — 빈 행")
            continue
        placed = place_dir([Image.open(p) for p in frames])
        for c in range(cols):
            cell = placed[min(c, len(placed) - 1)]
            sheet.paste(cell, (c * FRAME, r * FRAME), cell)

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    sheet.save(out_path)
    print(f"  ✓ {os.path.basename(out_path)}: {sheet.size}  ({len(ROW_DIRS)}행 × {cols}열)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
