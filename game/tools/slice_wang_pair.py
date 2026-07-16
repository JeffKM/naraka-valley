#!/usr/bin/env python3
# PixelLab tileset을 game/assets/terrain16/wang/ 에셋으로 다운로드·검증하는 글루.
# (ADR-0001 허용: 임포트 단계 정리. 변환 엔진 아님.)
# 16 코너조합(4코너×2값) 전부 커버되는지 확인해 누락을 조기 발견한다.
#
# 사용: python3 slice_wang_pair.py <tileset_id> <lo_surf> <up_surf>
#   lo/up = surf 코드(0맨흙 1잔디 2길 3밭 4물). 파일명 <lo>_<up>_{image.png,metadata.json}.
import json
import os
import subprocess
import sys

BASE = "https://api.pixellab.ai/mcp/tilesets"


def main() -> None:
    if len(sys.argv) != 4:
        print("usage: slice_wang_pair.py <tileset_id> <lo> <up>")
        raise SystemExit(1)
    tid, lo, up = sys.argv[1:4]
    out = os.path.join(os.path.dirname(__file__), "..", "assets", "terrain16", "wang")
    os.makedirs(out, exist_ok=True)
    stem = f"{lo}_{up}"
    img = os.path.join(out, f"{stem}_image.png")
    meta = os.path.join(out, f"{stem}_metadata.json")
    # -L: PixelLab download는 302로 backblaze로 리다이렉트.
    subprocess.run(["curl", "-sSL", "-o", img, f"{BASE}/{tid}/image"], check=True)
    subprocess.run(["curl", "-sSL", "-o", meta, f"{BASE}/{tid}/metadata"], check=True)
    d = json.load(open(meta))
    tiles = d["tileset_data"]["tiles"]
    seen = set()
    for t in tiles:
        c = t["corners"]
        bits = ((1 if c["NW"] == "upper" else 0)
                | (1 if c["NE"] == "upper" else 0) << 1
                | (1 if c["SW"] == "upper" else 0) << 2
                | (1 if c["SE"] == "upper" else 0) << 3)
        seen.add(bits)
    missing = [b for b in range(16) if b not in seen]
    status = "OK" if not missing else f"⚠️ 누락 {missing} (렌더 시 base 폴백)"
    print(f"{stem} <- {tid}: {len(seen)}/16 코너조합 {status}")
    if missing:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
