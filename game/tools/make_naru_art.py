#!/usr/bin/env python3
# ★[S2-T9] 나루 마을 환경 아트 후처리 글루 (ADR-0001 허용 = 생성물 정리·임포트 보정, 변환 엔진 아님).
#
# PixelLab MCP 생성 raw → 게임 규격(ADR-0050 32-native · asset-ruleset §3 피벗 · §8.1 하드알파 ·
# §9/§16 팔레트)으로 굳힌다. 입력 raw는 `assets/**/*_raw.png`(repo 관례), 출력은 그 옆 최종 PNG.
#
#   1) village_tree_cherry  64×128  벚꽃 나무 — 발치 bottom-flush 재정렬 + 저승 muted 톤 보정
#   2) village_stone_wall   32×32   돌담 — 좌우 edge-extend(연속 런) + farm_fence 발치 관례 정렬
#   3) plank_field         128×128  다리 목판 base 필드 — 90° 회전(판자가 통행 방향에 직교) +
#                                   보랏빛 제거(warm 목재) + 32→128 self-tile
#
# 사용: python3 tools/make_naru_art.py   (game/ 에서)
import colorsys
import hashlib
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROPS = os.path.join(ROOT, "assets", "props")
SS = os.path.join(ROOT, "assets", "terrain16", "single_source")
RAW = os.path.join(ROOT, "assets", "terrain16", "naru_raw")

ALPHA_CUT = 128   # §8.1 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)


def hard_alpha(img: Image.Image) -> Image.Image:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= ALPHA_CUT else 0)
    return img


def mute(rgb, sat_mul: float, val_mul: float, val_add: float = 0.0):
    """§9 저승 muted — 채도·명도만 눌러 형태·정체색은 보존."""
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    s = max(0.0, min(1.0, s * sat_mul))
    v = max(0.0, min(1.0, v * val_mul + val_add))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))


def warm_hue(rgb, target_h: float, blend: float):
    """자주/보랏빛 색상환을 따뜻한 목재 쪽으로 끌어온다(명도·채도 보존)."""
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # 색상환 최단 경로로 target_h를 향해 blend만큼 이동
    d = (target_h - h + 0.5) % 1.0 - 0.5
    h = (h + d * blend) % 1.0
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))


# ── 1) 벚꽃 나무 ─────────────────────────────────────────────────────────────
# tree_spirit_a/b와 같은 64×128(2×4칸) 드롭인. PixelLab 산출은 프레임 안에서 떠 있으므로
# (bbox 하단 112 < 128) 발치를 프레임 바닥에 붙인다 — [asset-ruleset §3] 야외 바닥 프롭은
# 발치 기준(foot-referenced)이고 `_draw_props_for`가 art_h로 발치를 잡기 때문에 여기서 어긋나면
# 충돌바·Y-split·접지 그림자가 통째로 공중에 뜬다.
def build_cherry_tree() -> None:
    src = Image.open(os.path.join(PROPS, "village_tree_cherry_raw.png")).convert("RGBA")
    box = src.getbbox()
    body = src.crop(box)
    out = Image.new("RGBA", (64, 128), (0, 0, 0, 0))
    out.paste(body, ((64 - body.width) // 2, 128 - body.height))
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < ALPHA_CUT:
                px[x, y] = (0, 0, 0, 0)
                continue
            _, _, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if v < 0.42:
                # 밑둥·가지 = 자주빛 → 따뜻한 저승 목재 갈색(§16 목재 갈회 램프 방향)
                r, g, b = warm_hue((r, g, b), 0.06, 0.75)
                r, g, b = mute((r, g, b), 0.85, 1.0)
            else:
                # 수관 = 벚꽃 정체색(분홍)은 남기되 캔디 채도를 눌러 저승 톤에 앉힌다
                r, g, b = mute((r, g, b), 0.72, 0.92)
            px[x, y] = (r, g, b, 255)
    out.save(os.path.join(PROPS, "village_tree_cherry.png"))
    print("village_tree_cherry.png 64x128 (발치 bottom-flush · muted)")


# ── 2) 돌담 ──────────────────────────────────────────────────────────────────
# farm_fence(32×32 · bbox 가로 0..32 꽉 참 · 하단 28) 관례에 맞춘다. PixelLab 산출은 좌우에
# 2px 여백이 있어 가로로 이으면 4px 구멍이 난다 → 양끝 열을 edge-extend해 연속 런을 만든다.
FENCE_BOTTOM = 28


def build_stone_wall() -> None:
    src = Image.open(os.path.join(PROPS, "village_stone_wall_raw.png")).convert("RGBA")
    box = src.getbbox()
    body = src.crop(box)
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    out.paste(body, (box[0], FENCE_BOTTOM - body.height))
    px = out.load()
    # 좌우 edge-extend — 몸통 첫/끝 열을 프레임 끝까지 복제(가로 런이 끊기지 않게)
    for y in range(32):
        left = px[box[0], y]
        for x in range(0, box[0]):
            px[x, y] = left
        right = px[box[2] - 1, y]
        for x in range(box[2], 32):
            px[x, y] = right
    hard_alpha(out)
    out.save(os.path.join(PROPS, "village_stone_wall.png"))
    print("village_stone_wall.png 32x32 (edge-extend 연속 런 · 발치 %d)" % FENCE_BOTTOM)


# ── 3) 다리 목판 base 필드 ────────────────────────────────────────────────────
# PixelLab Wang 세트의 순수 upper(판자) 타일 한 장을 단일출처 128 필드로 굳힌다.
#   · 90° 회전 = 판자가 통행 방향(남북 다리)에 **직교**로 눕는다(실제 교량 데크 문법).
#   · 보랏빛 제거 = 산출물이 자홍 기미라 warm 목재로 되돌린다(§9 따뜻한 베이스 정합).
def build_plank_field() -> None:
    src = Image.open(os.path.join(RAW, "plank_tile_raw.png")).convert("RGB")
    tile = src.transpose(Image.ROTATE_90)
    px = tile.load()
    for y in range(tile.height):
        for x in range(tile.width):
            r, g, b = px[x, y]
            r, g, b = warm_hue((r, g, b), 0.075, 0.85)   # 자홍/보라 → 목재 갈색
            px[x, y] = mute((r, g, b), 0.80, 1.0)
    out = Image.new("RGB", (128, 128))
    for ty in range(0, 128, tile.height):
        for tx in range(0, 128, tile.width):
            out.paste(tile, (tx, ty))
    out.save(os.path.join(SS, "plank_field.png"))
    print("plank_field.png 128x128 (회전 90° · warm 목재 · self-tile)")


# ── 4) 자갈 광장 base 필드 ────────────────────────────────────────────────────
# [ADR-0057] "베이스 타일은 단순하게, 디테일은 그 위 오브젝트로" + [ADR-0058] "변종으로 반복 제거".
# create_topdown_tileset은 자갈을 두 번 다 기계적 격자(줄무늬·벽돌)로 뽑아 폐기했고, create_tiles_pro
# (segmentation)가 크기 제각각인 판석 4변주 + 판석 빠진 마모 2변주를 냈다. 그 6장을 결정적 해시로
# 4×4에 깔아 128 필드를 만든다 — 셀마다 다른 변종이라 32px 반복 격자가 안 읽힌다.
#   · **flip 금지** — 좌우/상하 뒤집으면 이웃과 거울쌍이 생겨 나비 무늬로 튄다(실측 후 폐기).
#   · 판석은 타일 가장자리에서 잘려 있어 이음매가 모르타르 줄눈으로 읽힌다(별도 씸 힐 불필요).
COBBLE_MAIN = [0, 4, 8, 12]     # 판석 꽉 찬 변주
COBBLE_WORN = [9, 13]           # 판석 몇 장이 빠져 흙이 드러난 마모 변주
COBBLE_WORN_RATE = 1            # 10칸 중 몇 칸을 마모 변주로(↑=낡은 광장)


def _h(x: int, y: int, salt: int) -> int:
    return int(hashlib.md5(("%d_%d_%d" % (x, y, salt)).encode()).hexdigest()[:8], 16)


def build_cobble_field() -> None:
    main = [Image.open(os.path.join(RAW, "cobble_tile_raw_%d.png" % i)).convert("RGB")
            for i in COBBLE_MAIN]
    worn = [Image.open(os.path.join(RAW, "cobble_worn_raw_%d.png" % i)).convert("RGB")
            for i in COBBLE_WORN]
    out = Image.new("RGB", (128, 128))
    for cy in range(4):
        for cx in range(4):
            if _h(cx, cy, 4) % 10 < COBBLE_WORN_RATE:
                tile = worn[_h(cx, cy, 5) % len(worn)]
            else:
                tile = main[_h(cx, cy, 1) % len(main)]
            out.paste(tile, (cx * 32, cy * 32))
    px = out.load()
    for y in range(128):
        for x in range(128):
            px[x, y] = mute(px[x, y], 0.90, 0.97)   # §9 살짝 가라앉힌 warm(잔디·흙 베이스와 같은 결)
    out.save(os.path.join(SS, "cobble_field.png"))
    print("cobble_field.png 128x128 (판석 6변주 · 무-flip · muted)")


# ── 5) 카페 외관 배경 트림 ────────────────────────────────────────────────────
# cafe_ext.png는 알파가 전부 255고 배경이 #8c8681 회색으로 **구워져** 있어, 마을에 서면 건물 둘레에
# 회색 사각형이 뜬다(village_dump 육안). [asset-ruleset §1.3] "건물 base = 투명 — 실제 지형이 비쳐
# 자연 연결되게" 위반. 테두리에서 flood-fill로 배경 회색만 걷어낸다(안쪽에 같은 회색이 있어도
# 벽·지붕에 갇혀 있으면 보존 — 단순 색 키잉이 아니라 연결성 기준).
CAFE_BG_TOL = 26        # 배경 회색 판정 허용 오차(채널 최대 편차)


def trim_cafe_facade() -> None:
    path = os.path.join(ROOT, "assets", "buildings", "cafe_ext.png")
    raw = os.path.join(ROOT, "assets", "buildings", "cafe_ext_raw.png")
    img = Image.open(path).convert("RGBA")
    if not os.path.exists(raw):
        img.save(raw)   # 원본 1회 백업(idempotent — 재실행해도 덮어쓰지 않음)
    src = Image.open(raw).convert("RGBA")
    px = src.load()
    w, h = src.size
    bg = px[0, 0][:3]

    def is_bg(p):
        return p[3] > 0 and max(abs(p[i] - bg[i]) for i in range(3)) <= CAFE_BG_TOL

    seen = [[False] * w for _ in range(h)]
    stack = [(x, y) for x in range(w) for y in (0, h - 1)]
    stack += [(x, y) for y in range(h) for x in (0, w - 1)]
    cleared = 0
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y][x]:
            continue
        seen[y][x] = True
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        cleared += 1
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    hard_alpha(src)
    src.save(path)
    print("cafe_ext.png 배경 트림 — %d px 투명화(원본 cafe_ext_raw.png)" % cleared)


if __name__ == "__main__":
    build_cherry_tree()
    build_stone_wall()
    build_plank_field()
    build_cobble_field()
    trim_cafe_facade()
