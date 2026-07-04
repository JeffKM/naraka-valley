#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
# 32px 아트 → 16px 유효해상도 "청키화" 글루 (ADR-0049 downstream = 16px 전환 프로그램).
#
# GO(16px 논리) 전환은 코드가 아니라 *아트만* 바꾼다: 온스크린 크기·월드 TILE=32·충돌·
# 세이브·터레인 ID·.tres 구조는 전부 불변인 채, 각 스프라이트/아틀라스를
#   ÷2 (BOX, area 평균 = 깔끔 다운스케일)  →  ×2 (NEAREST, 크리스프 청키 업스케일)
# 로 바꿔 유효 해상도만 절반(=스타듀 청키 그레인)으로 만든다. 드롭인 교체(회귀 0).
#
# ADR-0012 시절 "흐릿함"과 다른 점: 그땐 뭉개는 리사이즈였고, 여기선 crisp NEAREST + alpha
# 하드에지(반투명 가장자리 뭉갬 방지). 캐릭터/프롭/건물/실내에 일괄.
#
# ⚠️ 지형 베이스(잔디·흙)는 이 글루가 아니라 새 소프트 Gemini 필드로 교체(Q1 무외곽선·소프트).
#    청키화는 *기존에 잘 나온 객체* 자산을 16 밀도에 맞출 때만.
#
# 사용:
#   python3 tools/chunkify_asset.py assets/buildings/barn_ext.png            # 제자리 교체(_pre32 백업)
#   python3 tools/chunkify_asset.py IN.png OUT.png                           # 별도 출력
#   python3 tools/chunkify_asset.py --grid 32 assets/tiles/xxx_atlas.png     # 아틀라스=타일 단위로 청키화
# ─────────────────────────────────────────────────────────────────────────────
import sys, os
from PIL import Image

def chunkify(im: Image.Image, grid: int = 0) -> Image.Image:
    im = im.convert("RGBA")
    if grid and (im.width % grid == 0) and (im.height % grid == 0):
        # 아틀라스: 타일 칸마다 독립 청키화(칸 경계 넘는 평균 방지)
        out = Image.new("RGBA", im.size)
        for ty in range(0, im.height, grid):
            for tx in range(0, im.width, grid):
                cell = im.crop((tx, ty, tx + grid, ty + grid))
                out.paste(_chunk_cell(cell), (tx, ty))
        return out
    return _chunk_cell(im)

def _chunk_cell(cell: Image.Image) -> Image.Image:
    w, h = cell.size
    half = cell.resize((max(1, w // 2), max(1, h // 2)), Image.BOX)   # ÷2 area
    big = half.resize((w, h), Image.NEAREST)                          # ×2 crisp
    # alpha 하드에지(반투명 가장자리 = 뭉갬 방지, asset-ruleset 하드에지 규약)
    px = big.load()
    for y in range(big.height):
        for x in range(big.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= 128 else 0)
    return big

def main(argv):
    grid = 0
    args = []
    i = 0
    while i < len(argv):
        if argv[i] == "--grid":
            grid = int(argv[i + 1]); i += 2
        else:
            args.append(argv[i]); i += 1
    if not args:
        print("사용: chunkify_asset.py [--grid N] IN.png [OUT.png]"); sys.exit(1)
    src = args[0]
    dst = args[1] if len(args) > 1 else src
    im = Image.open(src)
    if dst == src:
        bak = src.replace(".png", "_pre32.png")
        if not os.path.exists(bak):
            im.save(bak)   # 원본 1회 백업(idempotent)
    chunkify(im, grid).save(dst)
    print(f"✅ 청키화: {os.path.basename(src)} ({im.width}×{im.height}, grid={grid or '전체'}) → {os.path.basename(dst)}")

if __name__ == "__main__":
    main(sys.argv[1:])
