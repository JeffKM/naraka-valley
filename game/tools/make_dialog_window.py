#!/usr/bin/env python3
"""제미나이 대화창 아트 → 게임 UI 에셋 정리 (ADR-0001 허용 글루: 배경제거·크롭·정돈).

owner가 프롬프트대로 생성한 대화 윈도우 통짜(좌 텍스트칸·우 정사각 초상화칸·이름판·
그을린 한지 테두리·먹 나비). 제미나이가 투명을 회색 체커로 렌더하므로:
  ① 모서리에서 연결된 무채색 체커만 flood-fill 제거(따뜻한 종이·먹 장식 보존)
  ② 알파 bbox 오토크롭
  ③ assets/ui/dialog_window.png 저장 + 크기 출력
사용: python3 tools/make_dialog_window.py <src.png>
"""
from __future__ import annotations
import os
import sys
from collections import deque
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "dialog_window.png")


def is_checker(p) -> bool:
    r, g, b = p[0], p[1], p[2]
    sat = max(r, g, b) - min(r, g, b)   # 무채도
    bri = (r + g + b) // 3
    return sat < 26 and 60 <= bri <= 225


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 else \
        "/Users/jefflee/Downloads/Gemini_Generated_Image_dhyc35dhyc35dhyc.png"
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    dq = deque()
    # 테두리 전 픽셀에서 시작(체커인 것만)
    for x in range(w):
        for y in (0, h - 1):
            dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            dq.append((x, y))
    removed = 0
    while dq:
        x, y = dq.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        p = px[x, y]
        if p[3] == 0 or not is_checker(p):
            continue
        px[x, y] = (p[0], p[1], p[2], 0)
        removed += 1
        dq.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    bbox = im.getbbox()
    im = im.crop(bbox) if bbox else im
    cw, ch = im.size
    # 인게임 표시폭(~912px)의 넉넉한 2배 이내로 다운스케일 — 로드/메모리 비용↓, 룩 동일.
    MAX_W = 1400
    if cw > MAX_W:
        im = im.resize((MAX_W, round(ch * MAX_W / cw)), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im.save(OUT)
    print(f"  ✓ dialog_window.png  {im.size}  (crop {cw}x{ch}, src {w}x{h}, 배경 {removed}px 제거)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
