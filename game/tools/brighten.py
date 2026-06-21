#!/usr/bin/env python3
# P2.3② 실내 도트 밝기/대비/채도 후처리 글루 (ADR-0001 허용: Aseprite 보정에 해당하는
# 색보정). "muted underworld palette"로 생성된 가구·바닥·벽이 어두운 배경에 묻혀 탁해
# 보이는 문제를 완화한다 — 저승 톤은 유지하되 또렷하게(brightness·contrast·saturation).
# 투명 배경(가구)은 알파를 보존한다.
#
# 사용: python3 brighten.py <in.png> <out.png> [bright] [contrast] [sat]
#   기본 bright=1.3 contrast=1.18 sat=1.22
import sys
from PIL import Image, ImageEnhance


def main() -> None:
    if len(sys.argv) < 3:
        print("usage: brighten.py <in.png> <out.png> [bright] [contrast] [sat]")
        raise SystemExit(1)
    src, dst = sys.argv[1], sys.argv[2]
    bright = float(sys.argv[3]) if len(sys.argv) > 3 else 1.3
    contrast = float(sys.argv[4]) if len(sys.argv) > 4 else 1.18
    sat = float(sys.argv[5]) if len(sys.argv) > 5 else 1.22

    img = Image.open(src).convert("RGBA")
    alpha = img.getchannel("A")          # 알파 백업(보정은 RGB에만)
    rgb = img.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(bright)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    rgb = ImageEnhance.Color(rgb).enhance(sat)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    out.save(dst)
    print(f"{src} -> {dst}  bright={bright} contrast={contrast} sat={sat}")


if __name__ == "__main__":
    main()
