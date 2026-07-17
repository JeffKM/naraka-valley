#!/usr/bin/env python3
# ★[ADR-0058] Gemini SHORELINE 조각 → 물↔흙 16-corner-wang(4_0) 아틀라스 재조립 (ADR-0001 글루).
#
# 왜: 측면 물가(4_0)를 Gemini 손그림 유기 곡선으로 통일(흙벽·코너·물은 이미 Gemini). 그러나
#   Gemini SHORELINE 시트는 12조각(방향 엣지·단순코너)이라 16-corner-wang을 다 못 채운다.
#   owner 확정(2026-07-18): 명확한 canonical 2종(엣지1 + 오목코너1)만 쓰고, 나머지 16타일은
#   *형태만* 90°회전/미러/색스왑으로 생성한다. 채움 면은 게임 base(_bf_water/_bf_earth)라
#   광원/톤은 안 깨진다(_paint_shore_cell이 물=base·흙=base·테두리=이 이미지 픽셀만 사용).
#
# 파이프라인 0수정: 4_0_metadata.json·_build_shore_masks·_paint_shore_cell 그대로.
#   이 스크립트는 4_0_image.png(128×128) 소스만 교체한다.
#
# 사용: python3 tools/rebuild_shore_4_0.py <sheet.png> [--dry <out.png>]
import sys
import json
from PIL import Image

T = Image.Transpose
TILE = 32
WANG = "assets/terrain16/wang/"
META = WANG + "4_0_metadata.json"
DST = WANG + "4_0_image.png"

# 시트 SHORELINE 섹션 셀 좌표(연결요소 검출로 확정, 2026-07-18).
#   canonical만 사용: EDGE=r0c1(남 흙엣지 1100), CORNER=r2c0(단일흙 오목코너 0010).
EDGE_BOX = (1454, 890, 1643, 1056)
CORNER_BOX = (1266, 1265, 1408, 1431)

# dihedral 코너 순열(측정값). new_corner[c] = source[perm[c]]. 코너 index 0=NW 1=NE 2=SW 3=SE.
PERM = {
    "id":        (0, 1, 2, 3),
    "flipLR":    (1, 0, 3, 2),
    "flipTB":    (2, 3, 0, 1),
    "rot90":     (1, 3, 0, 2),
    "rot180":    (3, 2, 1, 0),
    "rot270":    (2, 0, 3, 1),
    "transpose": (0, 2, 1, 3),
    "transverse":(3, 1, 2, 0),
}
OP = {
    "id":        None,
    "flipLR":    T.FLIP_LEFT_RIGHT,
    "flipTB":    T.FLIP_TOP_BOTTOM,
    "rot90":     T.ROTATE_90,
    "rot180":    T.ROTATE_180,
    "rot270":    T.ROTATE_270,
    "transpose": T.TRANSPOSE,
    "transverse":T.TRANSVERSE,
}


def apply_bits(src, op):
    p = PERM[op]
    return tuple(src[p[c]] for c in range(4))


def find_op(src, target):
    for op in PERM:
        if apply_bits(src, op) == target:
            return op
    return None


def xform(img, op):
    return img if OP[op] is None else img.transpose(OP[op])


def crop_cell(sheet, box):
    return sheet.crop(box).resize((TILE, TILE), Image.NEAREST).convert("RGBA")


def classify(c, water_ref, earth_ref, keep=0.20):
    """픽셀 → 0=물 1=흙 2=테두리 (RGB 거리)."""
    r, g, b = c[0] / 255, c[1] / 255, c[2] / 255
    def d(ref):
        return ((r - ref[0]) ** 2 + (g - ref[1]) ** 2 + (b - ref[2]) ** 2) ** 0.5
    dw, de = d(water_ref), d(earth_ref)
    if dw < keep and dw <= de:
        return 0
    if de < keep:
        return 1
    return 2


def avg_region(img, x0, y0, x1, y1):
    px = img.load()
    r = g = b = n = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            p = px[x, y]
            if p[3] < 10:
                continue
            r += p[0]; g += p[1]; b += p[2]; n += 1
    if n == 0:
        return (0, 0, 0)
    return (r / n / 255, g / n / 255, b / n / 255)


def color_swap(img, water_ref, earth_ref):
    """물↔흙 색 스왑(테두리 유지). 마스크 반전 효과 → 단일흙코너를 단일물코너로."""
    out = img.copy()
    px = img.load()
    ox = out.load()
    wr = tuple(int(v * 255) for v in water_ref)
    er = tuple(int(v * 255) for v in earth_ref)
    for y in range(TILE):
        for x in range(TILE):
            cls = classify(px[x, y], water_ref, earth_ref)
            if cls == 0:
                ox[x, y] = (er[0], er[1], er[2], 255)   # 물자리→흙색
            elif cls == 1:
                ox[x, y] = (wr[0], wr[1], wr[2], 255)   # 흙자리→물색
            # 테두리(2)는 유지
    return out


def composite_diag(corner_a, corner_b, water_ref, earth_ref):
    """대각(1001/0110): 두 단일흙코너의 흙 영역 합집합(흙 우선)."""
    out = corner_a.copy()
    pa = corner_a.load(); pb = corner_b.load(); po = out.load()
    for y in range(TILE):
        for x in range(TILE):
            # b가 흙(1)이면 b 픽셀 채택, 아니면 a 유지
            if classify(pb[x, y], water_ref, earth_ref) == 1:
                po[x, y] = pb[x, y]
    return out


def solid(color):
    c = tuple(int(v * 255) for v in color) + (255,)
    im = Image.new("RGBA", (TILE, TILE), c)
    return im


def build(sheet):
    edge = crop_cell(sheet, EDGE_BOX)      # 1100 (흙 위/물 아래)
    corner = crop_cell(sheet, CORNER_BOX)  # 0010 (SW 흙, 나머지 물)
    # 대표색: EDGE 위중앙=흙, 아래중앙=물
    earth_ref = avg_region(edge, 10, 2, 22, 8)
    water_ref = avg_region(edge, 10, 24, 22, 30)
    corner_inv = color_swap(corner, water_ref, earth_ref)  # 1101 (SW 물, 나머지 흙)

    EDGE_BITS = (1, 1, 0, 0)
    CORNER_BITS = (0, 0, 1, 0)
    CORNER_INV_BITS = (1, 1, 0, 1)

    water_tile = solid(water_ref)
    earth_tile = solid(earth_ref)

    def gen(target):
        ne = sum(target)
        if ne == 0:
            return water_tile
        if ne == 4:
            return earth_tile
        if ne == 1:
            op = find_op(CORNER_BITS, target)
            return xform(corner, op)
        if ne == 3:
            op = find_op(CORNER_INV_BITS, target)
            return xform(corner_inv, op)
        # ne == 2
        op = find_op(EDGE_BITS, target)
        if op is not None:
            return xform(edge, op)
        # 대각(1001/0110): 두 단일흙코너 합성
        nw, nex, sw, se = target
        singles = []
        for idx, on in enumerate(target):
            if on:
                t = [0, 0, 0, 0]; t[idx] = 1
                o = find_op(CORNER_BITS, tuple(t))
                singles.append(xform(corner, o))
        return composite_diag(singles[0], singles[1], water_ref, earth_ref)

    meta = json.load(open(META))
    atlas = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    order = []
    pos_of = {}
    for t in meta["tileset_data"]["tiles"]:
        cc = t["corners"]
        target = (
            1 if cc["NW"] == "upper" else 0,
            1 if cc["NE"] == "upper" else 0,
            1 if cc["SW"] == "upper" else 0,
            1 if cc["SE"] == "upper" else 0,
        )
        bb = t["bounding_box"]
        tile = gen(target)
        atlas.paste(tile, (int(bb["x"]), int(bb["y"])))
        order.append((target, (bb["x"], bb["y"])))
        pos_of[target] = (int(bb["x"]), int(bb["y"]))
    return atlas, order, pos_of


# ★[ADR-0058·코너 정합] 북벽 코너(corner_nw/ne, 32×64)를 측면 shoreline과 잇는다.
#   위 32px(흙벽 정면 감김)는 원본(백업 *_orig.png)에서 보존, 아래 32px를 측면 타일(nw=서측면 1010·
#   ne=동측면 0101)로 교체 → 코너 아래 측면 셀과 픽셀 연속(경계 x 계단 제거·outline 통일). 이음매(y32) 블렌드.
CORNER_DIR = "assets/tiles/pond_cliff/"


def rebuild_corners(atlas, pos_of):
    side_tile = {
        "nw": atlas.crop((*pos_of[(1, 0, 1, 0)], pos_of[(1, 0, 1, 0)][0] + TILE, pos_of[(1, 0, 1, 0)][1] + TILE)),  # 1010 서측면
        "ne": atlas.crop((*pos_of[(0, 1, 0, 1)], pos_of[(0, 1, 0, 1)][0] + TILE, pos_of[(0, 1, 0, 1)][1] + TILE)),  # 0101 동측면
    }
    for side in ("nw", "ne"):
        path = CORNER_DIR + "corner_%s.png" % side
        orig = CORNER_DIR + "corner_%s_orig.png" % side
        import os
        if not os.path.exists(orig):
            Image.open(path).save(orig)   # 최초 실행: 원본 1회 백업
        src = Image.open(orig).convert("RGBA")
        out = Image.new("RGBA", (TILE, TILE * 2), (0, 0, 0, 0))
        out.paste(src.crop((0, 0, TILE, TILE)), (0, 0))       # 위 32px = 흙벽 정면(원본)
        out.paste(side_tile[side], (0, TILE))                 # 아래 32px = 측면 shoreline
        # 흙벽 최하단 밑동(어두운 outline)이 측면 tan과 안 어울려 "어두운 띠"를 만든다.
        #   흙벽 하단 _SEAM px를 경계로 갈수록 측면 상단 픽셀로 페이드 → 밑동이 측면으로 자연 소멸.
        po = out.load()
        up = src.crop((0, 0, TILE, TILE)).load()
        dn = side_tile[side].load()
        _SEAM = 8
        for dy in range(_SEAM):
            yy = TILE - 1 - dy                 # 흙벽 하단부(경계 위쪽)
            t = (_SEAM - dy) / (_SEAM + 1.0)   # 경계에 가까울수록 측면 비중↑
            for x in range(TILE):
                cu = up[x, yy]
                cd = dn[x, min(TILE - 1, _SEAM - dy)]
                r = round(cu[0] * (1 - t) + cd[0] * t)
                g = round(cu[1] * (1 - t) + cd[1] * t)
                b = round(cu[2] * (1 - t) + cd[2] * t)
                a = max(cu[3], cd[3])
                po[x, yy] = (r, g, b, a)
        out.save(path)
        print(f"  rebuilt corner_{side}.png")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: rebuild_shore_4_0.py <sheet.png> [--dry <out.png>]")
        sys.exit(1)
    sheet = Image.open(sys.argv[1]).convert("RGB")
    atlas, order, pos_of = build(sheet)
    out = DST
    dry = "--dry" in sys.argv
    if dry:
        out = sys.argv[sys.argv.index("--dry") + 1]
    atlas.save(out)
    print(f"wrote {out}")
    if not dry:
        rebuild_corners(atlas, pos_of)
    for target, pos in order:
        print(f"  bits{target} @ {pos}")
