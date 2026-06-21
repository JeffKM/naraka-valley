#!/usr/bin/env python3
"""P2.5③ 통일 패널 스킨 후처리 글루 (ADR-0001 허용 — brighten·hole-fill 결).

PixelLab로 생성한 패널 프레임(`assets/ui/panel_frame_raw.png`, 64×64, 투명 여백 +
대각 광택)을 9-slice StyleBoxTexture에 쓸 수 있게 정리한다:
  ① 투명 여백 크롭(콘텐츠 bbox)
  ② 가운데 대각 광택을 균일한 어둠으로 평탄화 — 9-slice가 가운데를 늘릴 때 광택이
     일그러지지 않게. 바깥 MARGIN px(둥근 모서리 + 앰버 코너 + 곧은 테두리)는 보존.
결과 `assets/ui/panel_frame.png`를 ui_theme.tres가 texture_margin=MARGIN으로 9-slice.

사용: python3 tools/make_panel.py
"""
from PIL import Image

RAW = "assets/ui/panel_frame_raw.png"
OUT = "assets/ui/panel_frame.png"
MARGIN = 9          # 9-slice 고정 테두리 폭(둥근 모서리+앰버 코너 보존)
FILL = (44, 44, 50, 255)  # 평탄화한 가운데(차분한 저승 차콜, 약간 차갑게)

raw = Image.open(RAW).convert("RGBA")
img = raw.crop(raw.getbbox())          # ① 투명 여백 크롭
W, H = img.size
px = img.load()

# ② 바깥 MARGIN 링은 보존, 안쪽은 균일 채움(불투명 어둠)
for y in range(MARGIN, H - MARGIN):
    for x in range(MARGIN, W - MARGIN):
        px[x, y] = FILL

img.save(OUT)
print(f"✅ {OUT} ({W}x{H}, margin {MARGIN})")
