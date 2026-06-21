#!/usr/bin/env python3
# P2.3② 가구·장식 다운스케일 글루 (ADR-0001 허용: 트림+다운스케일 임포트 단계).
#
# create_map_object 최소 캔버스가 32px라 16타일 규격(ADR-0003)과 어긋난다(§4.4 발견).
# 생성본(32×32 또는 32×64)을 게임 규격(16×16 / 16×32)으로 정수배 축소한다 —
# 도트가 깨지지 않게 NEAREST(2:1)로만 줄인다.
#
# 사용: python3 downscale_prop.py <입력.png> <출력.png> [목표_w] [목표_h]
#   목표 생략 시 입력의 절반(2:1)으로 축소.
import sys
from PIL import Image


def main() -> None:
    if len(sys.argv) < 3:
        print("usage: downscale_prop.py <in.png> <out.png> [w] [h]")
        raise SystemExit(1)
    src_path, dst_path = sys.argv[1], sys.argv[2]
    img = Image.open(src_path).convert("RGBA")
    if len(sys.argv) >= 5:
        w, h = int(sys.argv[3]), int(sys.argv[4])
    else:
        w, h = img.width // 2, img.height // 2
    out = img.resize((w, h), Image.NEAREST)
    out.save(dst_path)
    print(f"{src_path} {img.width}x{img.height} -> {dst_path} {w}x{h}")


if __name__ == "__main__":
    main()
