#!/usr/bin/env python3
# ADR-0013 실내 단일 면 타일 추출 글루 (ADR-0001 허용: 임포트 단계 크롭).
#
# create_topdown_tileset(32px)은 Wang 16타일 아틀라스를 준다. 실내 바닥·벽 같은
# 단일 면 타일은 그 중 "네 코너가 모두 같은 terrain"인 base 타일 한 장만 필요하다.
# 메타데이터(corners + bounding_box)로 그 타일을 찾아 아틀라스에서 32×32로 잘라낸다.
# (§8.1 교훈: 단일 면 타일은 tiles_pro 금지 → topdown base 경로. 이 글루가 그 추출.)
#
# 사용: python3 extract_base_tile.py <metadata.json> <image.png> <lower|upper> <out.png>
import json
import sys
from PIL import Image


def main() -> None:
    if len(sys.argv) != 5:
        print("usage: extract_base_tile.py <meta.json> <img.png> <lower|upper> <out.png>")
        raise SystemExit(1)
    meta_path, img_path, which, out_path = sys.argv[1:5]
    meta = json.load(open(meta_path))
    img = Image.open(img_path).convert("RGBA")
    for tile in meta["tileset_data"]["tiles"]:
        c = tile["corners"]
        if all(c[k] == which for k in ("NE", "NW", "SE", "SW")):
            b = tile["bounding_box"]
            crop = img.crop((b["x"], b["y"], b["x"] + b["width"], b["y"] + b["height"]))
            crop.save(out_path)
            print(f"{out_path} <- {which} base {crop.width}x{crop.height}")
            return
    raise SystemExit(f"no all-{which} base tile found in {meta_path}")


if __name__ == "__main__":
    main()
