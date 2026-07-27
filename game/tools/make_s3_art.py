#!/usr/bin/env python3
# ★[S3-T9 / ADR-0061 결정 10] 삼도천·황천해 아트 패스 1 후처리 글루
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab MCP 생성 raw → 게임 규격으로 굳힌다:
#   [asset-ruleset §0.1] 2px 청키 · [§1.1] NW 광원 · [§2] 정면 facade 남향 · [§3] bottom-center 앵커 ·
#   [§8.1] 하드 알파 · [§9] 저승 muted · [ADR-0050] 환경 32-native.
#
#   1) sand_field      128×128  백사장 base 필드 — 32px 변주 12장을 결정적 해시로 4×4에 깔아 self-tile
#                               (자갈 광장 cobble_field와 같은 문법 — 셀마다 다른 변주라 32px 격자가 안 읽힌다)
#   2) museum_ext      224×192  혼백관 외관 — MUSEUM_EXT_RECT(7×6)와 폭 1:1
#   3) fishshop_ext    224×192  생선가게 외관 — FISHSHOP_EXT_RECT(7×6)와 폭 1:1
#   4) rowboat          64×96   나룻배(2×3칸) — 발치 bottom-flush
#   5) pier_post        32×32   잔교 말뚝(1×1칸) — 발치 bottom-flush
#   6) beach_shell / beach_seaweed  32×32  백사장 지면 데칼 — 기존 ground_* 데칼 크기 관례에 맞춰 축소
#
# ★ 멱등: raw에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: python3 tools/make_s3_art.py   (game/ 에서)
import colorsys
import hashlib
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "assets", "buildings")
PROPS = os.path.join(ROOT, "assets", "props")
SS = os.path.join(ROOT, "assets", "terrain16", "single_source")
RAW = os.path.join(ROOT, "assets", "terrain16", "s3_raw")

TILE = 32          # [ADR-0050] 32-native
ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)


def hard_alpha(img: Image.Image) -> Image.Image:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= ALPHA_CUT else 0)
    return img


def mute(rgb, sat_mul: float, val_mul: float, val_add: float = 0.0):
    """[§9] 저승 muted — 채도·명도만 눌러 형태·정체색은 보존."""
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    s = max(0.0, min(1.0, s * sat_mul))
    v = max(0.0, min(1.0, v * val_mul + val_add))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))


def apply_px(img: Image.Image, fn) -> None:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if len(p) == 4:
                if p[3] < ALPHA_CUT:
                    px[x, y] = (0, 0, 0, 0)
                    continue
                px[x, y] = fn(p[:3]) + (255,)
            else:
                px[x, y] = fn(p)


def _h(x: int, y: int, salt: int) -> int:
    return int(hashlib.md5(("%d_%d_%d" % (x, y, salt)).encode()).hexdigest()[:8], 16)


# ── 1) 백사장 base 필드 ───────────────────────────────────────────────────────
# ★ 왜 "타일 붙이기"가 아니라 절차 합성인가(1차 시도 폐기 기록):
#   create_tiles_pro(square_topdown / top-down / segmentation)가 32px 모래 16변주를 냈고, 자갈 광장
#   (cobble_field) 문법대로 4×4로 깔아 봤다. **육안 리젝** — 변주마다 모티프(물결선·해칭·다이아 메시)가
#   타일 **중앙에** 몰려 있어 4×4 배치가 통째로 32px 격자로 읽혔다(레벨을 맞춰 톤 체커를 지워도
#   모티프 격자는 남는다). 판석은 원래 격자 물건이라 그게 통했지만 모래는 무정형이라 못 통한다.
#   기준선인 `dirt_field`(2×2 육안)는 32 격자가 전혀 없는 **무정형 저주파 얼룩**이다 — 그 구조를 맞춘다.
#   → 생성물에서 **팔레트만** 취하고(아트 권위는 PixelLab), 구조는 주기 노이즈로 seamless 합성한다.
#     `make_terrain_fields.py`(soil·water 절차 필드) 선례와 같은 층위다 — "구조적 패턴은 절차가 깔끔".
# 팔레트 = 생성 타일 실측 최빈색(tile_0~2 / tile_12): 베이스·하이라이트·중간·그늘·젖은 모래.
SAND_BASE = (229, 222, 194)
SAND_LIGHT = (240, 232, 197)
SAND_MID = (221, 209, 178)
SAND_DARK = (209, 198, 170)
SAND_GRAIN = (186, 170, 145)   # 굵은 모래알·조가비 부스러기(극희소 점)
SAND_WET_HI = (197, 173, 152)  # 젖은 모래(tile_12~15 실측) — 물가 테두리 전용
SAND_WET = (186, 170, 145)
SAND_WET_LO = (177, 153, 131)


def _pnoise(x: int, y: int, g: int, salt: int) -> float:
    """주기 값 노이즈 — 격자 인덱스를 g로 감아(mod) 128 필드가 **씸리스**하게 타일링된다.
    셀 코너 4점 해시를 smoothstep bilinear 보간(dirt_field의 무정형 얼룩과 같은 결)."""
    cell = 128.0 / g
    fx = x / cell
    fy = y / cell
    x0 = int(fx) % g
    y0 = int(fy) % g
    x1 = (x0 + 1) % g
    y1 = (y0 + 1) % g
    tx = fx - int(fx)
    ty = fy - int(fy)
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)

    def hv(a, b):
        return (_h(a, b, salt) % 10000) / 10000.0

    n0 = hv(x0, y0) + (hv(x1, y0) - hv(x0, y0)) * tx
    n1 = hv(x0, y1) + (hv(x1, y1) - hv(x0, y1)) * tx
    return n0 + (n1 - n0) * ty


def _lerp(a, b, t):
    return tuple(int(a[c] + (b[c] - a[c]) * t + 0.5) for c in range(3))


def _sand_image(pal_lo, pal_mid, pal_hi, grain, sat: float, val: float) -> Image.Image:
    """3옥타브 주기 노이즈로 seamless 모래 한 장. ★진폭을 작게 잡는다 — 백사장은 9행 × 전 폭이라
    저주파 결이 세면 필드 주기(256px = 8칸)가 **반복 얼룩**으로 눈에 든다(1차 덤프 육안). 옥타브를
    셋으로 늘려 큰 결 하나가 도드라지지 않게 흩고, 팔레트 폭도 좁혀 '평평한 모래 + 미세 그레인'으로."""
    out = Image.new("RGB", (128, 128))
    px = out.load()
    for y in range(128):
        for x in range(128):
            t = (_pnoise(x, y, 8, 31) * 0.42
                 + _pnoise(x, y, 16, 32) * 0.33
                 + _pnoise(x, y, 32, 35) * 0.25)
            if t < 0.5:
                c = _lerp(pal_lo, pal_mid, t / 0.5)
            else:
                c = _lerp(pal_mid, pal_hi, (t - 0.5) / 0.5)
            n = (_h(x, y, 33) % 1000) / 1000.0 - 0.5
            c = tuple(max(0, min(255, c[k] + int(n * 9))) for k in range(3))   # 미세 그레인
            if (_h(x, y, 34) % 1000) > 993:
                c = grain                                                       # 굵은 모래알(극희소)
            px[x, y] = c
    # 생성 팔레트가 크림빛으로 너무 밝다(V≈0.90) — 무채도 잔디·탁한 물 옆에 서면 혼자 형광으로 뜬다.
    apply_px(out, lambda cc: mute(cc, sat, val))
    return out


def build_sand_field() -> None:
    dry = _sand_image(SAND_MID, SAND_BASE, SAND_LIGHT, SAND_GRAIN, 1.12, 0.80)
    dry.save(os.path.join(SS, "sand_field.png"))
    print("sand_field.png 128x128 (PixelLab 팔레트 + 3옥타브 주기 노이즈 seamless · muted)")
    # ★ 젖은 모래(물가) — 물↔땅 손그림 shore 마스크의 **테두리 클래스**가 쓰는 필드다. 손그림 테두리
    #   픽셀은 연못·강용 붉은 흙빛이라 백사장에 그대로 쓰면 바다 경계에 **붉은 줄**이 그어진다(1차 덤프
    #   육안). 생성 타일 12~15(젖은 모래) 실측 팔레트로 같은 결의 한 톤 어두운 필드를 구워 대신 쓴다.
    wet = _sand_image(SAND_WET_LO, SAND_WET, SAND_WET_HI, SAND_WET_LO, 1.10, 0.80)
    wet.save(os.path.join(SS, "sand_wet_field.png"))
    print("sand_wet_field.png 128x128 (젖은 모래 팔레트 · 물가 테두리 전용)")


# ── 2·3) 건물 외관 ───────────────────────────────────────────────────────────
# [§11.0 공통 규약] 폭 = footprint 폭 정확히 / 높이 ≥ footprint 높이(지붕이 위로 솟음).
# PixelLab은 캔버스 대비 콘텐츠 여백이 생성마다 흔들려 캔버스로는 못 맞춘다 → half-res(16논리px)
# 격자에서 NEAREST로 맞춘 뒤 ×2(=§0.1 2px 청키 보장). make_naru_art2.fit_facade와 같은 함수다.
def fit_facade(raw: Image.Image, tiles_w: int, tiles_h: int) -> Image.Image:
    box = raw.getbbox()
    content = raw.crop(box)
    hw = tiles_w * TILE // 2
    hh = round(content.height * hw / content.width)
    hh = max(hh, tiles_h * TILE // 2)
    small = content.resize((hw, hh), Image.NEAREST)
    return hard_alpha(small.resize((hw * 2, hh * 2), Image.NEAREST).convert("RGBA"))


# [§1.3] 건물 base는 **투명**이어야 한다 — 지면을 구우면 백사장 위에 tan 타원이 뜨고(실제 지형이 안 비침),
# 무엇보다 bbox가 아래로 늘어나 bottom-center 앵커가 밀린다 = 아트 문이 문 타일과 어긋난다.
# 생성물이 굽고 나온 지면만 **바깥에서 정확 색 매칭 flood-fill**로 걷어낸다(cafe_ext 트림과 같은 결이되,
# 색 허용오차 대신 실측 팔레트 정확 매칭 — 궤짝·항아리의 비슷한 나무색으로 새지 않게).
# 실측 지면 팔레트 + 허용오차 — 정확 매칭만 쓰면 디더 가장자리 픽셀이 **모래 알갱이처럼 남는다**
# (1차 트림 육안). 궤짝·항아리는 어두운 외곽선에 둘러싸여 있어 바깥 flood-fill이 못 넘어오므로
# 허용오차를 줘도 새지 않는다(색이 아니라 **연결성**이 방벽이다).
BAKED_GROUND = [
    (210, 191, 144), (207, 187, 143), (175, 158, 121), (169, 153, 116),
    (127, 106, 86), (118, 98, 78), (111, 94, 72), (104, 87, 67),
]
BAKED_TOL = 34


def _is_baked_ground(p) -> bool:
    for g in BAKED_GROUND:
        if sum((p[c] - g[c]) ** 2 for c in range(3)) <= BAKED_TOL * BAKED_TOL:
            return True
    return False


def trim_baked_ground(img: Image.Image) -> int:
    w, h = img.size
    px = img.load()
    seen = [[False] * w for _ in range(h)]
    stack = [(x, y) for x in range(w) for y in (0, h - 1)]
    stack += [(x, y) for y in range(h) for x in (0, w - 1)]
    cleared = 0
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y][x]:
            continue
        seen[y][x] = True
        p = px[x, y]
        if p[3] >= ALPHA_CUT and not _is_baked_ground(p):
            continue          # 불투명 비-지면 = 건물 → 여기서 막힌다
        if p[3] >= ALPHA_CUT:
            px[x, y] = (0, 0, 0, 0)
            cleared += 1
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return cleared


def build_facades() -> None:
    for raw_name, out_name in [("museum_ext_raw", "museum_ext"), ("fishshop_ext_raw", "fishshop_ext")]:
        raw = Image.open(os.path.join(BUILD, raw_name + ".png")).convert("RGBA")
        n = trim_baked_ground(raw)
        if n:
            print("  %s: 구운 지면 %d px 투명화" % (raw_name, n))
        img = fit_facade(raw, 7, 6)          # MUSEUM/FISHSHOP_EXT_RECT = 7×6
        apply_px(img, lambda c: mute(c, 0.88, 0.96))   # [§9] 저승 muted 소폭(만물상과 같은 계수)
        img.save(os.path.join(BUILD, out_name + ".png"))
        print("  %s.png %dx%d" % ((out_name,) + img.size))


# ── 4·5) 프롭 ────────────────────────────────────────────────────────────────
# [§3] 야외 바닥 프롭은 발치 기준(foot-referenced) — `_draw_props_for`가 art 하단을 발치로 잡으므로
# 프레임 바닥에 붙이지 않으면 접지 그림자·Y-split이 통째로 공중에 뜬다.
def foot_flush(raw: Image.Image, w: int, h: int, scale_w: int = 0) -> Image.Image:
    box = raw.getbbox()
    body = raw.crop(box)
    if scale_w and body.width != scale_w:
        sh = max(1, round(body.height * scale_w / body.width))
        body = body.resize((scale_w, sh), Image.NEAREST)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(body, ((w - body.width) // 2, h - body.height))
    return hard_alpha(out)


def build_props() -> None:
    boat = foot_flush(Image.open(os.path.join(PROPS, "rowboat_raw.png")).convert("RGBA"), 64, 96)
    apply_px(boat, lambda c: mute(c, 0.85, 0.95))
    boat.save(os.path.join(PROPS, "rowboat.png"))
    print("  rowboat.png %dx%d (발치 bottom-flush · muted)" % boat.size)

    post = foot_flush(Image.open(os.path.join(PROPS, "pier_post_raw.png")).convert("RGBA"), 32, 32)
    apply_px(post, lambda c: mute(c, 0.85, 0.95))
    post.save(os.path.join(PROPS, "pier_post.png"))
    print("  pier_post.png %dx%d (발치 bottom-flush · muted)" % post.size)


# ── 6) 백사장 지면 데칼 ───────────────────────────────────────────────────────
# 기존 지면 데칼(ground_pebble 14×6 · ground_weed_dry 18×12 · scatter_stone_b 12×13) 관례 =
# 32 프레임 안에 **아주 작고 납작한** 콘텐츠. 생성물은 그보다 커서 그대로 쓰면 지면이 아니라
# 오브젝트로 읽힌다 → 폭을 관례치로 줄이고 발치 정렬한다.
def build_beach_decals() -> None:
    shell = foot_flush(Image.open(os.path.join(PROPS, "beach_shell_raw.png")).convert("RGBA"),
                       32, 32, scale_w=16)
    apply_px(shell, lambda c: mute(c, 0.80, 0.94))
    shell.save(os.path.join(PROPS, "beach_shell.png"))
    print("  beach_shell.png %dx%d" % shell.size)

    weed = foot_flush(Image.open(os.path.join(PROPS, "beach_seaweed_raw.png")).convert("RGBA"),
                      32, 32, scale_w=16)
    apply_px(weed, lambda c: mute(c, 0.72, 0.92))
    weed.save(os.path.join(PROPS, "beach_seaweed.png"))
    print("  beach_seaweed.png %dx%d" % weed.size)


if __name__ == "__main__":
    build_sand_field()
    build_facades()
    build_props()
    build_beach_decals()
