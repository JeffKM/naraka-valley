#!/usr/bin/env python3
"""참조 일러스트 → 대화용 초상화 에셋 (ADR-0003 "별도 일러스트 초상화").

ADR-0001 허용 글루: 변환 엔진 제작이 아니라 받은 일러스트를 정리(배경 제거·크롭)하는
색보정/임포트 단계다. 입력은 제미나이 생성 컨셉 일러스트(원작 IP 진실의 원천, §5.1).

처리:
  1) 그린스크린 제거 + 디스필(초록 fringe 억제) — 단, 입력이 이미 투명배경이면 건너뜀
  2) 알파 바운딩박스로 오토크롭
  3) 두 산출물:
     - <name>.png       : 얼굴 중심 버스트(머리+어깨) 정사각 캔버스 — 대화창용
     - <name>_full.png  : 배경만 지운 전신(투명) — 보관/대안용
"""
from __future__ import annotations
import os
import sys
from PIL import Image

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "portraits")
BUST_SIZE = 320      # 버스트 정사각 캔버스 한 변
FULL_H = 512         # 전신 표준 높이

# 입력: (출력이름, 절대경로)
SOURCES = [
    ("okja", "/Users/jefflee/Downloads/Gemini_Generated_Image_jyxj0ajyxj0ajyxj-removebg-preview.png"),
    ("miho", "/Users/jefflee/Downloads/Gemini_Generated_Image_vprnq2vprnq2vprn.png"),
    ("bana", "/Users/jefflee/Downloads/Gemini_Generated_Image_fyrbpifyrbpifyrb.png"),
    ("mel",  "/Users/jefflee/Downloads/Gemini_Generated_Image_ao997eao997eao99.png"),
]


def is_green_bg(r: int, g: int, b: int) -> bool:
    """그린스크린 배경 판정: 초록이 r·b를 뚜렷이 압도."""
    return g > 90 and g > r * 1.35 and g > b * 1.35


def already_transparent(im: Image.Image) -> bool:
    """모서리 4픽셀이 모두 투명하면 배경 제거가 끝난 입력으로 본다."""
    w, h = im.size
    for x, y in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if im.getpixel((x, y))[3] != 0:
            return False
    return True


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
                # 디스필: 보존 픽셀의 초록 fringe를 r·b 평균으로 눌러 윤곽 초록기 제거
                cap = (r + b) // 2 + 12
                if g > cap:
                    px[x, y] = (r, cap, b, a)
    return im


def content_bbox(im: Image.Image):
    bbox = im.getbbox()  # 알파 포함 RGBA면 비투명 영역
    return bbox if bbox else (0, 0, im.width, im.height)


def make_bust(body: Image.Image) -> Image.Image:
    """전신(크롭됨)에서 머리+어깨를 잘라 정사각 투명 캔버스에 중앙 배치."""
    w, h = body.size
    # ~2.5등신 치비: 머리+어깨는 상단 약 46%
    bust_h = int(h * 0.46)
    bust = body.crop((0, 0, w, bust_h))
    # 정사각 캔버스에 가로 기준 contain
    bw, bh = bust.size
    scale = min(BUST_SIZE / bw, BUST_SIZE / bh)
    nw, nh = max(1, int(bw * scale)), max(1, int(bh * scale))
    bust = bust.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (BUST_SIZE, BUST_SIZE), (0, 0, 0, 0))
    canvas.paste(bust, ((BUST_SIZE - nw) // 2, (BUST_SIZE - nh) // 2), bust)
    return canvas


def make_full(body: Image.Image) -> Image.Image:
    w, h = body.size
    scale = FULL_H / h
    nw = max(1, int(w * scale))
    return body.resize((nw, FULL_H), Image.LANCZOS)


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, path in SOURCES:
        if not os.path.exists(path):
            print(f"  ! {name}: 원본 없음 {path}")
            continue
        im = Image.open(path).convert("RGBA")
        if not already_transparent(im):
            im = remove_green(im)
        bbox = content_bbox(im)
        body = im.crop(bbox)
        bust = make_bust(body)
        full = make_full(body)
        bust.save(os.path.join(OUT_DIR, f"{name}.png"))
        full.save(os.path.join(OUT_DIR, f"{name}_full.png"))
        print(f"  ✓ {name}: bust {bust.size} / full {full.size}  (src {im.size})")
    print(f"저장 → {os.path.abspath(OUT_DIR)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
