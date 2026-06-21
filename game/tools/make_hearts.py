#!/usr/bin/env python3
"""P2.5② 하트 스프라이트 후처리 글루 (ADR-0001 허용 — brighten·hole-fill 결).

PixelLab로 생성한 채운 하트 32px(`assets/ui/heart_full_32.png`)에서
  ① 16px 다운스케일 → heart_full.png (표시용 native)
  ② 같은 실루엣의 빈 하트 파생 → heart_empty.png
     (외곽 링만 어둡게 남기고 속은 비워, 미충족 단계가 한눈에 구분되게)
둘을 PixelLab로 따로 생성하면 실루엣이 어긋나므로, 빈 하트는 채운 하트에서 파생한다.

사용: python3 tools/make_hearts.py
"""
from PIL import Image, ImageFilter

SRC = "assets/ui/heart_full_32.png"
OUT_FULL = "assets/ui/heart_full.png"
OUT_EMPTY = "assets/ui/heart_empty.png"
DISPLAY = 16  # 표시 크기(16px native, UI 16px 폰트 행에 맞춤)

full32 = Image.open(SRC).convert("RGBA")

# ① 채운 하트: 16px nearest 다운스케일(픽셀 또렷)
full32.resize((DISPLAY, DISPLAY), Image.NEAREST).save(OUT_FULL)

# ② 빈 하트: 16px에서 알파를 1px 침식해 내부를 떼고 외곽 링만 남긴다.
#    (32px에서 침식 후 다운스케일하면 링이 얇아져 끊긴다 → 표시 크기에서 직접 1px 링)
full16 = full32.resize((DISPLAY, DISPLAY), Image.NEAREST)
opaque = full16.getchannel("A").point(lambda a: 255 if a > 64 else 0)  # 불투명 마스크
inner = opaque.filter(ImageFilter.MinFilter(3))            # 1px 침식(내부)
empty = Image.new("RGBA", full16.size, (0, 0, 0, 0))
px_o, px_i = opaque.load(), inner.load()
ep = empty.load()
RING = (150, 140, 155, 255)   # 미충족 = 차분한 회보라(저승 톤)
HOLLOW = (60, 55, 70, 70)     # 속은 아주 옅은 어둠(있는 듯 없는 듯)
for y in range(full16.height):
    for x in range(full16.width):
        if px_o[x, y] == 0:
            continue
        ep[x, y] = HOLLOW if px_i[x, y] else RING
empty.save(OUT_EMPTY)

print(f"✅ {OUT_FULL} · {OUT_EMPTY} ({DISPLAY}px)")
