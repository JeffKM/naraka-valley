#!/usr/bin/env python3
"""표정 변형 일러스트 → 대화용 초상화 에셋 (ADR-0003 "표정=별도 일러스트 초상화").

make_portrait.py의 후속 — 기본 1종이 아니라 캐릭터별 표정 4종(smile/shy/sad/talk)을
기존 기본 초상화와 *같은 비율*(머리+어깨 버스트, 320 정사각, 전신 상단 46% 크롭)로 찍어낸다.

ADR-0001 허용 글루: 변환 엔진 제작이 아니라 받은 일러스트를 정리(배경 제거·크롭)하는 단계.
입력은 Gemini 생성 전신 일러스트. 배경이 셋으로 갈려 자동 판정해 제거한다:
  - 이미 투명(모서리 alpha=0)           → bbox 크롭만
  - 그린스크린(모서리 초록이 r·b 압도)   → 디스필 포함 색 제거(make_portrait와 동일 결)
  - 체커보드/무채색 배경(Gemini가 투명을 회색 체커로 렌더) → 모서리 연결 flood-fill
    (색만 보면 캐릭터의 흰 레이스·안경알에 구멍이 나므로, 모서리에서 4방향으로 이어진
     무채색·밝은 영역만 지운다 — 검은 라인아트에서 전파가 막혀 캐릭터 내부는 보존)
"""
from __future__ import annotations
import os
import sys
from collections import deque
from PIL import Image

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "portraits")
SRC_ROOT = "/Users/jefflee/Desktop/naraka"
BUST_SIZE = 320       # 기존 기본 초상화와 동일한 버스트 정사각 한 변
BUST_TOP_RATIO = 0.46 # 전신(크롭본)에서 머리+어깨가 차지하는 상단 비율 — make_portrait와 동일

EXPR = ["smile", "shy", "sad", "talk"]  # 사용자가 올린 순서

# 출력stem(게임 화자키) → 디스크 폴더 → [표정 순서대로 4개 파일]
SOURCES = {
    "okja": ("okja", [
        "Gemini_Generated_Image_4v1f7d4v1f7d4v1f-removebg-preview.png",  # smile (이미 투명)
        "Gemini_Generated_Image_m0bu94m0bu94m0bu.png",                   # shy
        "Gemini_Generated_Image_kusjg0kusjg0kusj.png",                   # sad
        "Gemini_Generated_Image_nw25qhnw25qhnw25.png",                   # talk
    ]),
    "miho": ("miho", [
        "Gemini_Generated_Image_gw5zaqgw5zaqgw5z.png",
        "Gemini_Generated_Image_3woxwz3woxwz3wox.png",
        "Gemini_Generated_Image_cvtf6rcvtf6rcvtf.png",
        "Gemini_Generated_Image_9lleit9lleit9lle.png",
    ]),
    "bana": ("vana", [
        "Gemini_Generated_Image_6ttexb6ttexb6tte.png",
        "Gemini_Generated_Image_gpia59gpia59gpia.png",
        "Gemini_Generated_Image_ywb47ywb47ywb47y.png",
        "Gemini_Generated_Image_8rgmt98rgmt98rgm.png",
    ]),
    "mel": ("mell", [
        "Gemini_Generated_Image_vqinlpvqinlpvqin.png",
        "Gemini_Generated_Image_tt6hp9tt6hp9tt6h.png",
        "Gemini_Generated_Image_noddp0noddp0nodd.png",
        "Gemini_Generated_Image_8ka09i8ka09i8ka0.png",
    ]),
}


def corners(im: Image.Image):
    w, h = im.size
    return [im.getpixel(p) for p in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]]


def bg_kind(im: Image.Image) -> str:
    cs = corners(im)
    if all(c[3] == 0 for c in cs):
        return "transparent"
    greens = sum(1 for r, g, b, _ in cs if g > 90 and g > r * 1.35 and g > b * 1.35)
    if greens >= 3:
        return "green"
    return "checker"  # 무채색/체커/단색 밝은 배경


def is_green_bg(r: int, g: int, b: int) -> bool:
    return g > 90 and g > r * 1.35 and g > b * 1.35


def remove_green(im: Image.Image) -> Image.Image:
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if is_green_bg(r, g, b):
                px[x, y] = (r, g, b, 0)
            elif g > r and g > b:
                cap = (r + b) // 2 + 12  # 디스필: 보존 픽셀의 초록 fringe 억제
                if g > cap:
                    px[x, y] = (r, cap, b, a)
    return im


def remove_checker(im: Image.Image) -> Image.Image:
    """모서리에서 4방향으로 이어진 '무채색·밝은' 영역만 flood-fill로 투명화."""
    w, h = im.size
    data = list(im.getdata())

    def is_bg(i: int) -> bool:
        r, g, b, a = data[i]
        if a == 0:
            return True
        # 무채색(채널 편차 작음) + 밝음 → 체커/회색 배경. 와인색·검정·살색은 탈락.
        return (max(r, g, b) - min(r, g, b)) <= 30 and max(r, g, b) >= 130

    visited = bytearray(w * h)
    dq: deque[int] = deque()
    for cx, cy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        i = cy * w + cx
        if is_bg(i) and not visited[i]:
            visited[i] = 1
            dq.append(i)
    while dq:
        i = dq.popleft()
        x, y = i % w, i // w
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h:
                j = ny * w + nx
                if not visited[j] and is_bg(j):
                    visited[j] = 1
                    dq.append(j)
    out = [(r, g, b, 0) if visited[i] else (r, g, b, a)
           for i, (r, g, b, a) in enumerate(data)]
    im.putdata(out)
    return im


def make_bust(body: Image.Image) -> Image.Image:
    w, h = body.size
    bust = body.crop((0, 0, w, int(h * BUST_TOP_RATIO)))
    bw, bh = bust.size
    s = min(BUST_SIZE / bw, BUST_SIZE / bh)
    nw, nh = max(1, int(bw * s)), max(1, int(bh * s))
    bust = bust.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (BUST_SIZE, BUST_SIZE), (0, 0, 0, 0))
    canvas.paste(bust, ((BUST_SIZE - nw) // 2, (BUST_SIZE - nh) // 2), bust)
    return canvas


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    for stem, (folder, files) in SOURCES.items():
        for expr, fname in zip(EXPR, files):
            path = os.path.join(SRC_ROOT, folder, fname)
            if not os.path.exists(path):
                print(f"  ! {stem}_{expr}: 원본 없음 {path}")
                continue
            im = Image.open(path).convert("RGBA")
            kind = bg_kind(im)
            if kind == "green":
                im = remove_green(im)
            elif kind == "checker":
                im = remove_checker(im)
            bbox = im.getbbox() or (0, 0, im.width, im.height)
            bust = make_bust(im.crop(bbox))
            out = os.path.join(OUT_DIR, f"{stem}_{expr}.png")
            bust.save(out)
            print(f"  ✓ {stem}_{expr}: {kind:11s} → bust {bust.size}")
    print(f"저장 → {os.path.abspath(OUT_DIR)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
