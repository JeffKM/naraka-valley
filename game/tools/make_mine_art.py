#!/usr/bin/env python3
# ★[S5-T9 / ADR-0063 아트 스코프] 업화 갱도·나락 아트 패스 1 후처리 글루
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab 생성 raw → 게임 규격(발치 flush · 하드 알파 · 저승 muted · 2px 청키)으로 굳힌다.
#
# ★밴드 3톤(잿길·넋골·업화)은 **여기서 굽지 않는다** — 층 지면 톤은 `main._g16_ground_tone`
#   (그리기 시점 곱셈)이 든다. 밴드마다 파생 필드 PNG를 구우면 [S4-T9 §14.6]이 폐기한 그 길로
#   되돌아간다(재시도 금지): 한 필드를 세 벌로 늘리면 교체 큐가 3배가 되고, 밴드 경계에서 두 필드가
#   같은 화면에 서는 순간 톤이 아니라 **다른 재질**로 읽힌다. 곱셈은 합성 결과 전부에 균일하게 걸린다.
#
# 규격 근거: [asset-ruleset §0.1] 2px 청키 · [§1.1] NW 광원 · [§3] 발치 앵커 · [§8.1] 하드 알파 ·
#           [§9] 저승 muted · [ADR-0050] 환경 32-native
#
# ★ 멱등: raw·단일출처에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: cd game && python3 tools/make_mine_art.py
import colorsys
import hashlib
import math
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROPS = os.path.join(ROOT, "assets", "props")
BUILD = os.path.join(ROOT, "assets", "buildings")
TERR = os.path.join(ROOT, "assets", "terrain16")
MSRC = os.path.join(TERR, "mine_src")

TILE = 32
FIELD = 128        # 단일출처 필드 규약(런타임 ×2=256이 월드 타일링 주기)
ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)


# ── 공통 픽셀 유틸(make_forest_art.py와 같은 규약) ────────────────────────────
def hard_alpha(img: Image.Image) -> Image.Image:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= ALPHA_CUT else (0, 0, 0, 0)
    return img


def mute(rgb, sat_mul: float, val_mul: float, hue_add: float = 0.0):
    """[§9] 저승 muted + 색상 미세 이동 — 형태는 그대로, 톤만 옮긴다."""
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    h = (h + hue_add) % 1.0
    s = max(0.0, min(1.0, s * sat_mul))
    v = max(0.0, min(1.0, v * val_mul))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))


def apply_px(img: Image.Image, fn) -> None:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if p[3] < ALPHA_CUT:
                px[x, y] = (0, 0, 0, 0)
                continue
            px[x, y] = fn(p[:3]) + (255,)


def foot_flush(raw: Image.Image, w: int, h: int, size: tuple = ()) -> Image.Image:
    """[§3] 프롭 = 발치 기준. `draw_texture_rect`가 art 하단을 발치로 잡으므로 프레임 바닥에
    붙이지 않으면 접지·정렬이 통째로 뜬다."""
    box = raw.getbbox()
    body = raw.crop(box)
    if size:
        body = body.resize(size, Image.NEAREST)
    if body.width > w or body.height > h:
        k = min(w / body.width, h / body.height)
        body = body.resize((max(1, int(body.width * k)), max(1, int(body.height * k))), Image.NEAREST)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(body, ((w - body.width) // 2, h - body.height))
    return hard_alpha(out)


def fit_facade(raw: Image.Image, tiles_w: int, tiles_h: int) -> Image.Image:
    """[§11 건물] 아트 폭 = footprint 폭 정확히. 반해상으로 눌렀다 ×2로 되살려 2px 청키를 강제한다
    (make_t10_icons.fit_facade와 같은 규약 — 두 글루가 같은 규격을 뱉어야 교체 큐가 성립한다)."""
    box = raw.getbbox()
    content = raw.crop(box)
    hw = tiles_w * TILE // 2
    hh = round(content.height * hw / content.width)
    hh = max(hh, tiles_h * TILE // 2)
    small = content.resize((hw, hh), Image.NEAREST)
    return hard_alpha(small.resize((hw * 2, hh * 2), Image.NEAREST).convert("RGBA"))


# ══ ① 지면 필드 2종 — 팔레트만 취하고 구조는 절차 합성 ════════════════════════
# ★★ 왜 생성 타일을 그대로 안 깔았나(§12.3 백사장 선례의 재확인 — 재시도 금지):
#   갱도 바닥·암반은 **무정형**이다. 32px 변주를 모자이크로 깔면 변주마다 모티프가 타일 중앙에 몰려
#   배치가 통째로 32px 격자로 읽힌다(§12.3이 육안 리젝한 그 실패). 판석(§10.3 cobble)은 원래 격자
#   물건이라 통했을 뿐이다. 무정형 지형의 정배는 `dirt_field`·`sand_field` 계열의 절차 합성이다.
#   그래서 PixelLab 타일에서는 **팔레트(명도 램프)만** 뽑고 구조는 여기서 짓는다.
#
# ★ 청키: 노이즈를 FIELD/2(64)로 짓고 ×2로 키운다 → 2px 블록이 구조적으로 보장된다([§0.1]).
# ★ 이음매: 주기 노이즈(격자 코너를 wrap)라 128 경계가 끊기지 않는다(seamless).

def _h01(x: int, y: int, salt: int) -> float:
    n = int(hashlib.md5(("%d_%d_%d" % (x, y, salt)).encode()).hexdigest()[:8], 16)
    return (n % 100000) / 100000.0


def _value_noise(w: int, h: int, cells: int, salt: int) -> list:
    """주기 value 노이즈(bilinear + smoothstep). cells로 나눈 격자 코너를 wrap해 seamless."""
    cw = w / cells
    ch = h / cells
    grid = [[_h01(gx, gy, salt) for gx in range(cells)] for gy in range(cells)]
    out = []
    for y in range(h):
        gy = int(y / ch)
        fy = (y - gy * ch) / ch
        fy = fy * fy * (3.0 - 2.0 * fy)
        row = []
        for x in range(w):
            gx = int(x / cw)
            fx = (x - gx * cw) / cw
            fx = fx * fx * (3.0 - 2.0 * fx)
            v00 = grid[gy % cells][gx % cells]
            v10 = grid[gy % cells][(gx + 1) % cells]
            v01 = grid[(gy + 1) % cells][gx % cells]
            v11 = grid[(gy + 1) % cells][(gx + 1) % cells]
            row.append((v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy)
        out.append(row)
    return out


def _ramp(paths: list, levels: int, lo: float, hi: float) -> list:
    """소스 타일들의 색을 명도순으로 세워 `levels` 단계 램프를 뽑는다(팔레트만 상속).
    ★lo~hi 백분위로 **잘라서** 쓴다 — 전 구간을 쓰면 소스의 극단 픽셀(까만 균열 한 점·흰 하이라이트
      한 점)이 램프 양끝을 차지해 필드 전체가 그 두 색으로 출렁인다(1차 산출 육안: 바닥이 진흙
      위장무늬, 암반이 새까만 공동). 가운데 구간만 쓰면 '한 재질의 결'이 된다."""
    # ★**픽셀 목록이 아니라 고유색 목록**으로 뽑는다. 픽셀 백분위로 자르면 저색(crisp) 소스에서
    #   한 색이 화면의 80%를 먹어 전 구간이 그 색 하나로 붕괴한다(1차 산출: 램프 12단계가 실색
    #   3종으로 접혀 필드가 민무늬가 됐다). 고유색을 명도순으로 세우고 그 사이를 보간해야 램프가
    #   램프가 된다 — 팔레트(색 정체)는 소스에서, 단계(결의 세기)는 여기서.
    hist = {}
    for p in paths:
        im = Image.open(p).convert("RGBA")
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if a < ALPHA_CUT:
                    continue
                hist[(r, g, b)] = hist.get((r, g, b), 0) + 1
    total = sum(hist.values())
    if total == 0:
        raise SystemExit("팔레트 소스가 비었다")
    # 극소수 아웃라이어(전체의 0.4% 미만) 제거 — 한 점짜리 하이라이트가 램프 끝을 잡는 걸 막는다.
    keys = [c for c, n in hist.items() if n >= total * 0.004]
    if len(keys) < 3:
        keys = list(hist.keys())
    keys.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
    m = len(keys) - 1
    out = []
    for i in range(levels):
        t = (lo + (hi - lo) * (i + 0.5) / levels) * m
        j = min(m - 1, max(0, int(t)))
        f = min(1.0, max(0.0, t - j))
        a_, b_ = keys[j], keys[j + 1] if m > 0 else keys[j]
        out.append(tuple(int(a_[k] + (b_[k] - a_[k]) * f + 0.5) for k in range(3)))
    return out


def build_field(name: str, srcs: list, octaves: list, chip: float, chip_shift: int,
                sat: float, val: float, band: tuple = (0.20, 0.90)) -> None:
    """octaves = [(cells, weight), ...] · chip = 잔돌 알갱이 밀도 · chip_shift = 알갱이 램프 이동."""
    half = FIELD // 2
    levels = 12
    ramp = _ramp([os.path.join(MSRC, s + ".png") for s in srcs], levels, band[0], band[1])
    fields = [(_value_noise(half, half, c, 700 + i * 13), w) for i, (c, w) in enumerate(octaves)]
    tot = sum(w for _, w in octaves)
    img = Image.new("RGBA", (half, half))
    px = img.load()
    for y in range(half):
        for x in range(half):
            v = sum(f[y][x] * w for f, w in fields) / tot
            lv = min(levels - 1, max(0, int(v * levels)))
            if _h01(x, y, 991) < chip:
                lv = min(levels - 1, max(0, lv + chip_shift))
            px[x, y] = ramp[lv] + (255,)
    big = img.resize((FIELD, FIELD), Image.NEAREST)
    apply_px(big, lambda c: mute(c, sat, val))
    out = os.path.join(TERR, name + ".png")
    big.save(out)
    print("  %s.png %dx%d" % (name, FIELD, FIELD))


# ══ ② 광맥 2층 분해 — 몸통(회색 돌) / 광물(틴트 대상) ══════════════════════════
# ★ 왜 종마다 PNG를 굽지 않는가: 광맥 종이 11이다(광석 3 + 혼탄 + 보석 4 + 지오드 2 + 나락철).
#   11장을 구우면 owner 교체 큐가 11칸이 되는데, 실제로 갈리는 건 **광물 색 하나**뿐이다.
#   그래서 한 장을 두 층으로 쪼갠다: 몸통은 그대로 그리고, 광물 층만 `_MINE_NODE_COLORS`로
#   곱셈한다(씨앗 봉지 9종 = 원본 2장 + 절기 틴트 §15.3와 같은 판단).
# ★ 광물 층은 **명도만 남긴 회백**으로 정규화한다 — 원본 색(청록 너깃·시안 결정)이 남아 있으면
#   곱셈 결과가 두 색의 곱이 되어 명동(구리)이 탁한 올리브로 나온다.

def split_node(raw_name: str, body_name: str, ore_name: str, sat_thr: float,
               sat: float, val: float) -> None:
    raw = Image.open(os.path.join(PROPS, raw_name + ".png")).convert("RGBA")
    hard_alpha(raw)
    body = Image.new("RGBA", raw.size, (0, 0, 0, 0))
    ore = Image.new("RGBA", raw.size, (0, 0, 0, 0))
    rp, bp, op = raw.load(), body.load(), ore.load()
    # 몸통 채움색 = 광물이 아닌 픽셀들의 중앙 명도색(광물 자리를 돌로 메워 구멍을 없앤다).
    stone = []
    for y in range(raw.height):
        for x in range(raw.width):
            r, g, b, a = rp[x, y]
            if a == 0:
                continue
            s = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)[1]
            if s < sat_thr:
                stone.append((0.299 * r + 0.587 * g + 0.114 * b, (r, g, b)))
    stone.sort(key=lambda c: c[0])
    fill = stone[len(stone) // 2][1] if stone else (110, 110, 116)
    # 광물 마스크 — 채도로 1차 판정한 뒤 **1px 팽창**한다. 팽창이 없으면 너깃 하이라이트(채도가
    # 낮아 돌로 분류된 밝은 점)가 마스크에서 빠져 광물이 서너 점으로 쪼개진다(1차 산출 육안:
    # 종색이 32px에서 안 읽혔다 = "광석 4종 식별 가능" 판정 실패).
    mask = [[False] * raw.width for _ in range(raw.height)]
    for y in range(raw.height):
        for x in range(raw.width):
            r, g, b, a = rp[x, y]
            if a == 0:
                continue
            if colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)[1] >= sat_thr:
                mask[y][x] = True
    grown = [row[:] for row in mask]
    for y in range(raw.height):
        for x in range(raw.width):
            if not mask[y][x]:
                continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < raw.height and 0 <= nx < raw.width and rp[nx, ny][3]:
                        grown[ny][nx] = True
    for y in range(raw.height):
        for x in range(raw.width):
            r, g, b, a = rp[x, y]
            if a == 0:
                continue
            if grown[y][x]:
                bp[x, y] = fill + (255,)
                lum = 0.299 * r + 0.587 * g + 0.114 * b
                # 명도만 남긴 회백 — 곱셈 틴트가 종색 그대로 나오도록 정규화(0.45~1.0로 펼침).
                k = int(115 + 140 * min(1.0, lum / 210.0))
                op[x, y] = (k, k, k, 255)
            else:
                bp[x, y] = (r, g, b, 255)
    # ★두 층은 **같은 변환**으로 앉혀야 한다 — 각자 bbox로 foot_flush하면 광물 층이 자기 bbox
    #   중앙으로 끌려가 몸통에서 어긋난다(층 분해의 유일한 함정). raw의 bbox 하나를 공유한다.
    box = raw.getbbox()
    ox = (TILE - (box[2] - box[0])) // 2
    oy = TILE - (box[3] - box[1])
    outs = []
    for layer in (body, ore):
        frame = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        frame.paste(layer.crop(box), (ox, oy))
        outs.append(hard_alpha(frame))
    apply_px(outs[0], lambda c: mute(c, sat, val))
    outs[0].save(os.path.join(PROPS, body_name + ".png"))
    outs[1].save(os.path.join(PROPS, ore_name + ".png"))
    print("  %s.png + %s.png (2층 분해)" % (body_name, ore_name))


def build_greyed(raw_name: str, out_name: str, w: int, h: int) -> None:
    """지오드처럼 **전체가 한 재질**인 프롭 — 통째로 회백 정규화해 종색 곱셈에 맡긴다."""
    raw = Image.open(os.path.join(PROPS, raw_name + ".png")).convert("RGBA")
    hard_alpha(raw)
    img = foot_flush(raw, w, h)
    apply_px(img, lambda c: mute(c, 0.14, 1.0))   # 채도만 죽이고 명암(입체)은 보존
    img.save(os.path.join(PROPS, out_name + ".png"))
    print("  %s.png %dx%d (회백 정규화)" % ((out_name,) + img.size))


# ══ ③ 일반 프롭 ═══════════════════════════════════════════════════════════════
PROP_SPECS = [
    # (raw, out, w, h, 강제 콘텐츠 치수, 채도, 명도)
    # 깨는 돌 — 층 바닥을 뒤덮는 물건이라 칸을 꽉 채우면 바닥이 안 보인다(28×26로 여백 2px).
    ("mine_rock_raw", "mine_rock", TILE, TILE, (28, 26), 0.72, 0.94),
    # 사다리 — 세로로 칸을 관통해야 "타고 내려간다"가 읽힌다(폭은 좁게).
    ("mine_ladder_raw", "mine_ladder", TILE, TILE, (18, 30), 0.80, 1.00),
    ("mine_chest_raw", "mine_chest", TILE, TILE, (26, 22), 0.82, 0.96),
    # 봉인석 — 나락 아레나 고리 위에 올라앉는다. 낮고 넓게(고리 ROCK 띠를 덮지 않게).
    ("narak_seal_raw", "narak_seal", TILE, TILE, (26, 24), 0.86, 0.92),
    # 실내 2종 — 2×1칸(64×32). 방이 좁아 세로로 크면 카운터·NPC를 가린다.
    ("smithy_anvil_raw", "smithy_anvil", TILE * 2, TILE, (), 0.78, 0.96),
    ("guild_weapon_rack_raw", "guild_weapon_rack", TILE * 2, TILE, (), 0.80, 0.98),
]


def build_props() -> None:
    for raw_name, out_name, w, h, size, sat, val in PROP_SPECS:
        p = os.path.join(PROPS, raw_name + ".png")
        if not os.path.exists(p):
            print("  ! raw 없음: %s" % p)
            continue
        raw = Image.open(p).convert("RGBA")
        hard_alpha(raw)
        img = foot_flush(raw, w, h, size)
        apply_px(img, lambda c: mute(c, sat, val))
        img.save(os.path.join(PROPS, out_name + ".png"))
        print("  %s.png %dx%d" % ((out_name,) + img.size))


# ══ ④ 외관 2채 ════════════════════════════════════════════════════════════════
# 대장간 = SMITHY_EXT_RECT Rect2i(4,37,6,5) · 길드 = GUILD_EXT_RECT Rect2i(22,37,6,5) — 둘 다 6×5칸.
# ★두 채가 **한 화면에 나란히 선다**(남단 입구 서·동). 숲 2채(§15.4)와 정반대 조건이라 대비를
#   구역 간이 아니라 **채 간**으로 내야 한다: 대장간=검댕 슬레이트+불빛 / 길드=밝은 회백 석재.
FACADE_SPECS = [
    ("smithy_ext_raw", "smithy_ext", 6, 5, 0.86, 0.92),
    ("guild_ext_raw", "guild_ext", 6, 5, 0.84, 1.02),
]


def _scrub_roman_sign(img: Image.Image) -> None:
    """길드 간판의 로마자("Guild")를 지운다 — 저승 세계관에 라틴 문자가 서면 안 된다.
    간판 판 안쪽을 판 테두리색으로 메우고 각진 각자(刻字) 세 덩이를 새겨 "새긴 현판"으로 읽게 한다.
    (재생성 시엔 프롬프트에서 글자 자체를 빼는 게 낫다 — 이 함수는 그때 지워도 된다.)"""
    px = img.load()
    w, h = img.size
    # 간판 = 상단 1/3의 가장 노란(hue 0.08~0.16) 밝은 가로 띠. 그 bbox를 찾아 안쪽을 덮는다.
    xs, ys = [], []
    for y in range(h // 6, h // 2):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hh, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if 0.06 <= hh <= 0.18 and s > 0.30 and v > 0.45:
                xs.append(x)
                ys.append(y)
    if len(xs) < 40:
        return
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    if x1 - x0 < 8 or y1 - y0 < 4:
        return
    border = px[x0, y0][:3]
    for y in range(y0 + 1, y1):
        for x in range(x0 + 1, x1):
            if px[x, y][3] == 0:
                continue
            px[x, y] = border + (255,)
    # 각자 3덩이 — 균등 배치의 짧은 세로 홈(문자가 아니라 조각 자국으로 읽히는 최소 형태).
    cy = (y0 + y1) // 2
    dark = tuple(max(0, c - 60) for c in border)
    span = x1 - x0
    for i in range(3):
        gx = x0 + span * (i * 2 + 2) // 8
        for dy in range(-1, 2):
            for dx in range(2):
                if 0 <= gx + dx < w and 0 <= cy + dy < h and px[gx + dx, cy + dy][3]:
                    px[gx + dx, cy + dy] = dark + (255,)


def build_facades() -> None:
    for raw_name, out_name, tw, th, sat, val in FACADE_SPECS:
        p = os.path.join(BUILD, "raw", raw_name + ".png")
        if not os.path.exists(p):
            print("  ! raw 없음: %s" % p)
            continue
        raw = Image.open(p).convert("RGBA")
        hard_alpha(raw)
        img = fit_facade(raw, tw, th)
        if out_name == "guild_ext":
            _scrub_roman_sign(img)
        apply_px(img, lambda c: mute(c, sat, val))
        img.save(os.path.join(BUILD, out_name + ".png"))
        print("  %s.png %dx%d" % ((out_name,) + img.size))


def main() -> None:
    print("① 지면 필드(팔레트 상속 + 절차 합성)")
    # 바닥 = 잔 알갱이가 촘촘한 다짐 흙. **고주파 비중을 크게** 잡는다 — 저주파가 이기면 128 주기의
    #   큰 얼룩이 "위장무늬"로 읽힌다(1차 육안 리젝). 밝은 알갱이(chip)가 자갈 결을 낸다.
    build_field("mine_floor_field", ["floor_a", "floor_b"],
                [(5, 2), (11, 3), (21, 4)], chip=0.070, chip_shift=3, sat=0.64, val=1.02,
                band=(0.22, 0.86))
    # 암반 = 바닥보다 한 단 어둡고 결이 굵다(덩어리 비중↑). 다만 **공동(새까망)이면 안 된다** —
    #   벽으로 읽히려면 명암이 살아 있어야 한다(1차 val 0.74는 통째로 검은 판이 됐다).
    build_field("mine_bedrock_field", ["rock_a", "rock_b"],
                [(4, 3), (9, 3), (18, 2)], chip=0.075, chip_shift=-3, sat=0.60, val=1.16,
                band=(0.10, 0.80))
    print("② 광맥 2층 분해")
    split_node("mine_node_ore_raw", "mine_node_ore", "mine_node_ore_vein", 0.30, 0.34, 0.98)
    split_node("mine_node_gem_raw", "mine_node_gem", "mine_node_gem_core", 0.28, 0.30, 0.96)
    build_greyed("mine_node_geode_raw", "mine_node_geode", TILE, TILE)
    print("③ 프롭")
    build_props()
    print("④ 외관 2채")
    build_facades()
    print("완료")


if __name__ == "__main__":
    main()
