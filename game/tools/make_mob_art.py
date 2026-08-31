#!/usr/bin/env python3
# ★[S5-T10 / ADR-0063 아트 스코프] 잡귀·점주·아이콘 아트 패스 2 후처리 글루
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab 생성 raw → 게임 규격으로 굳힌다:
#   [asset-ruleset §0.1] 2px 청키 · [§1.1] NW 광원 · [§8.1] 하드 알파 · [§9] 저승 muted ·
#   [ADR-0050] 32-native · 캐릭터 시트 규약(FRAME 80 · 발치 y=74 · §11.4 size=44)
#
#   1) 잡귀 스프라이트 12종   32×32 / 보스 64×64   assets/mobs/<종 id>.png
#   2) 아이템 아이콘 27종     32×32               assets/materials/<아이템 id>.png
#   3) 갱도 어종 2종          32×32               assets/fish/<어종 id>.png
#   4) 점주 2인 시트          80×320              assets/characters/{pulmu,mugol}.png
#   5) 풀무 도트 초상화       256×256             assets/portraits/pulmu.png
#   6) 업화로 화덕 프롭       64×32               assets/props/smithy_forge.png
#
# ★ 멱등: raw에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: cd game && python3 tools/make_mob_art.py
import colorsys
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOBS = os.path.join(ROOT, "assets", "mobs")
MATERIALS = os.path.join(ROOT, "assets", "materials")
FISH = os.path.join(ROOT, "assets", "fish")
PROPS = os.path.join(ROOT, "assets", "props")
CHARS = os.path.join(ROOT, "assets", "characters")
PORTRAITS = os.path.join(ROOT, "assets", "portraits")

TILE = 32
ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)
FRAME = 80         # 캐릭터 시트 규약(char_sprite.gd FRAME=80)
FOOT_Y = 74        # 출하 캐스트 5종 실측 발치선(make_t10_icons.py 주석 참조)
ROW_DIRS = ["south", "north", "east", "west"]   # 행 순서 = down/up/right/left

# [§9] 저승 muted 계수.
#   · 아이콘 = make_t10_icons/make_s3_icons와 **같은 값**(0.90/0.97) — 한 슬롯 줄에 나란히 놓여도
#     톤이 안 튄다. 아이콘 카테고리 전체가 한 계수로 잠겨 있어야 새 아이콘만 튀지 않는다.
#   · 잡귀 = 아이콘과 같은 얕은 값. 프롭 계수(0.72~0.86)로 누르면 업화 밴드(주홍 지면) 위에서
#     잡귀가 배경에 잠긴다 — 몹은 **밴드 톤 곱셈 대상이 아니라** 그 위에 서는 판정 대상이다.
ICON_SAT, ICON_VAL = 0.90, 0.97
MOB_SAT, MOB_VAL = 0.90, 0.98
CAST_SAT, CAST_VAL = 0.94, 0.98    # 점주 = 출하 캐스트와 나란히 서므로 아주 얕게(옹이와 같은 값)


# ── 공통 픽셀 유틸(make_t10_icons.py / make_mine_art.py와 같은 규약) ───────────
def hard_alpha(img: Image.Image) -> Image.Image:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= ALPHA_CUT else (0, 0, 0, 0)
    return img


def mute(rgb, sat_mul: float, val_mul: float):
    """[§9] 저승 muted — 채도·명도만 눌러 형태·정체색은 보존."""
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    s = max(0.0, min(1.0, s * sat_mul))
    v = max(0.0, min(1.0, v * val_mul))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))


def apply_px(img: Image.Image, fn) -> Image.Image:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if p[3] < ALPHA_CUT:
                px[x, y] = (0, 0, 0, 0)
                continue
            px[x, y] = fn(p[:3]) + (255,)
    return img


def center_in(img: Image.Image, w: int, h: int) -> Image.Image:
    """콘텐츠를 w×h 프레임 **가운데**로 다시 앉힌다(아이콘 — 슬롯이 통째로 늘려 그리므로
    여백이 한쪽에 몰리면 옆 슬롯과 눈금이 어긋나 보인다)."""
    box = img.getbbox()
    if box is None:
        return img
    body = img.crop(box)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(body, ((w - body.width) // 2, (h - body.height) // 2), body)
    return out


def foot_flush(img: Image.Image, w: int, h: int) -> Image.Image:
    """콘텐츠를 w×h 프레임 **바닥**에 붙인다([§3] 발치 앵커 — 몹·프롭 공용)."""
    box = img.getbbox()
    if box is None:
        return img
    body = img.crop(box)
    if body.width > w or body.height > h:
        k = min(w / body.width, h / body.height)
        body = body.resize((max(1, int(body.width * k)), max(1, int(body.height * k))), Image.NEAREST)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(body, ((w - body.width) // 2, h - body.height), body)
    return out


# ── 종색 틴트 ────────────────────────────────────────────────────────────────
# ★[§15.3 교훈 승계] 원본 한 장 + 종색 곱셈으로 계열을 파생한다(씨앗 봉지 9종 = 원본 2 선례).
#   틴트 규칙 3개 — 앞 두 개는 §15.3이 두 번의 실패로 얻은 것이고, 세 번째가 이 카드의 몫이다:
#   ㉠ **hue는 통째로 갈아끼운다**(부분 lerp 금지 — 중간에 엉뚱한 색으로 착지한다).
#   ㉡ **어두운 외곽선은 건드리지 않는다**(v ≤ _TINT_V_MIN) — 검은 테가 색 테로 바뀌면
#      [§1] 단일 외곽선 규약이 깨진다.
#   ㉢ ★**채도는 원본이 아니라 종색이 운전한다.** 원본(청록 결정·황금 주괴)의 채도를 그대로
#      곱하면 넋수정(거의 흰색)이 청록으로 남는다 — 원본 채도는 *결의 세기*로만 쓰고(±),
#      절대값은 종색이 준다. [§16.1]이 램프를 "팔레트는 소스·단계는 글루"로 가른 것과 같은 분업.
_TINT_V_MIN = 0.35


def species_tint(rgb, color):
    """rgb를 종색(color = 0~1 RGB 튜플)으로 물들인다. 명도(=형태)는 보존한다."""
    ch, cs, cv = colorsys.rgb_to_hsv(*color)
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v > _TINT_V_MIN:
        h = ch
        s = max(0.0, min(1.0, cs * (0.55 + 0.75 * s)))     # ㉢ 절대값 = 종색 · 변조 = 원본
    v = max(0.0, min(1.0, v * (0.70 + 0.42 * cv) * ICON_VAL))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))


def prismatic_tint(rgb, y: int, h_total: int):
    """오색혼옥(프리즈마틱) 전용 — 종색이 **하나가 아닌** 유일한 아이템이라 세로 위치로 색상환을
    한 바퀴 돌린다. 단색 틴트로는 "오색"이 성립하지 않는다(다른 보석 4종과 같은 그림이 된다)."""
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v > _TINT_V_MIN:
        h = (y / max(1.0, float(h_total)) + 0.08) % 1.0
        s = max(0.0, min(1.0, 0.34 + 0.42 * s))
        v = max(0.0, min(1.0, v * 1.04 * ICON_VAL))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))


# ══ 1) 잡귀 스프라이트 12종 ═══════════════════════════════════════════════════
# 파일명 = MobCatalog 종 id에서 "mob_"/"boss_" 접두를 뗀 이름 = main._MOB_TEX 배선.
# ★프레임 크기가 **부류를 가른다**: 갱도·나락 강몹 32² / 관문 보스 64². 그레이박스가 보스를
#   1.7배로 그리던 규칙("저건 다른 급이다"를 실루엣이 먼저 말한다)의 아트판이고, 그래서 보스는
#   raw부터 64로 뽑았다(32를 늘리면 청키가 4px로 깨진다 — [ADR-0050] 축소·확대 금지의 대칭).
# ★전 종 **발치 flush**다. 그리기가 m.pos(픽셀 연속 위치) 기준 bottom 앵커라, 프레임 안에서
#   콘텐츠가 뜨면 잡귀가 공중에 뜬 채 걷는다(부유형 어둑깨비·화귀도 마찬가지 — 부유는 그림이
#   맡지 프레임 여백이 맡지 않는다).
MOB_IDS = [
    # 갱도 6종(밴드당 2 · 아키타입 4 커버)
    "heotgeot", "eodukkaebi", "dalgyal", "geuseundae", "bulgasari", "hwagwi",
    # 나락 강몹 3종
    "yacha", "nachal", "agwi",
]
BOSS_IDS = ["boss_okjol", "boss_nachalwang", "boss_daeagwi"]


def build_mobs() -> None:
    made = 0
    for mob_id, size in [(m, 32) for m in MOB_IDS] + [(b, 64) for b in BOSS_IDS]:
        raw_path = os.path.join(MOBS, "raw", mob_id + "_raw.png")
        if not os.path.exists(raw_path):
            print("  ! 잡귀 raw 없음: %s" % raw_path)
            continue
        img = Image.open(raw_path).convert("RGBA")
        hard_alpha(img)
        apply_px(img, lambda c: mute(c, MOB_SAT, MOB_VAL))
        foot_flush(img, size, size).save(os.path.join(MOBS, mob_id + ".png"))
        made += 1
    print("  mobs: 잡귀 %d종(갱도 6 · 나락 3 · 보스 3)" % made)


# ══ 2) 아이템 아이콘 ═════════════════════════════════════════════════════════
# 파일명 = ItemCatalog/WeaponCatalog 아이템 id = 배선(main.MINE_ICONS가 파일명으로 preload).
#
# ★생성물은 **9장뿐**이고 나머지 18종은 그 위의 종색 틴트다(§15.3 씨앗 봉지 선례):
#   광석 4 = ore_base 1 · 주괴 4 = ingot_base 1 · 보석 3 = gem_base 1 ·
#   보석 2(명부금강·오색혼옥) = gem_brilliant 1 · 지오드 2 = geode_base 1 ·
#   검 4 = sword_base 1 · 업화도 = sword_dao 1  (+ 단품 혼탄·환약·계단·열쇠·혼정·넋가루·혼불씨)
#
# ★★ 보석만 원본이 **둘**인 이유(이 카드가 새로 얻은 판단): 넋수정(투명 백)과 명부금강(백청)은
#    _MINE_NODE_COLORS에서 색이 거의 붙어 있다. 같은 결정 다발 실루엣에 그 둘을 얹으면 32²
#    슬롯에서 **같은 아이콘 두 개**가 된다([§15.0] 리젝 ① "같은 계열 두 종이 같은 실루엣").
#    색으로 못 가르면 **형태 계급을 가른다** — 다발(원석) ↔ 한 알 브릴리언트(가공석). 겸사겸사
#    최상위 2종이 "가공된 보석"으로 격이 올라가 등급이 실루엣에 실린다.
# ★검 5종은 **통짜 틴트**다(칼자루까지). 날만 물들이면 티어가 32²에서 안 읽힌다 — [§16.3]이
#   광맥 몸통까지 함께 물들여야 했던 것과 같은 이유이고, 업화도만 **굽은 도(刀)**라 형태부터
#   갈린다(엔드게임 한 자루는 색이 아니라 실루엣으로 서야 한다).

# 종색의 단일 출처 = main._MINE_NODE_COLORS / _NARAK_NODE_COLORS / WeaponCatalog.color.
#   ★여기 값이 그 표와 어긋나면 **인벤 아이콘과 층 광맥·바닥 반짝이의 색이 갈린다**(같은 광물이
#     무대에 따라 다른 색). 종색을 바꿀 땐 반드시 양쪽을 같이 고친다.
ORE_TINTS = {
    "ore_myeongdong": (0.86, 0.36, 0.16),        # 명동 — 붉은 구리
    "ore_yucheol": (0.40, 0.56, 0.82),           # 유철 — 푸른 강철
    "ore_hwangcheongeum": (0.90, 0.75, 0.30),    # 황천금 — 황금
    "ore_narakcheol": (0.72, 0.52, 0.86),        # 나락철 — 보랏빛 금속(나락 전용)
}
# 주괴 = 같은 금속의 **정련된** 꼴. 광석과 색상은 같되 한 단 밝고 진하다(원석 ↔ 주괴가 인벤에서
# 갈려야 제련 사슬이 눈에 보인다 — 형태(덩이 ↔ 사다리꼴 바)가 1차, 명도가 2차 단서).
INGOT_TINTS = {
    "ingot_myeongdong": (0.88, 0.52, 0.32),
    "ingot_yucheol": (0.68, 0.74, 0.84),
    "ingot_hwangcheongeum": (1.00, 0.84, 0.36),
    "ingot_narakcheol": (0.82, 0.62, 0.96),
}
GEM_TINTS = {                                     # 결정 다발(원석 3종)
    "gem_neoksujeong": (0.86, 0.90, 0.94),        # 넋수정 — 투명 백
    "gem_myeongok": (0.42, 0.78, 0.62),           # 명옥 — 옥빛
    "gem_yeomjuseok": (0.60, 0.36, 0.72),         # 염주석 — 자주
}
GEODE_TINTS = {
    "geode_neokal": (0.52, 0.46, 0.38),           # 넋알돌 — 흙빛 덩어리
    "geode_eophwa": (0.62, 0.34, 0.24),           # 업화알돌 — 달군 흙빛
}
SWORD_TINTS = {                                   # 곧은 검 4티어(WeaponCatalog.color 1:1)
    "sword_rusty": (0.52, 0.44, 0.36),            # 녹슨 혼검 — 흙빛 붉은 녹
    "sword_myeongdong": (0.78, 0.44, 0.28),       # 명동검
    "sword_yucheol": (0.58, 0.62, 0.70),          # 유철검
    "sword_hwangcheongeum": (0.90, 0.75, 0.30),   # 황천금검
}
# 단품 아이콘(틴트 파생 아님) — raw 파일명 = 아이템 id.
PLAIN_IDS = [
    "hontan",            # 혼탄 — 제련 연료(석탄 대응)
    "myeongbuhwan",      # 명부환 — HP 회복 환약(길드 판매)
    "stairs",            # 계단 — 층 스킵 1회용
    "narak_key",         # 나락 열쇠 — 60층 보상 상자 산출
    "narak_honjeong",    # 나락혼정 — 관문 보스 확정 드랍
    "neokgaru",          # 넋가루 — 잡귀 범용 드랍
    "honbulssi",         # 혼불씨 — 심층 잡귀 드랍
]


def _bake(raw_path: str, out_path: str, fn) -> bool:
    if not os.path.exists(raw_path):
        print("  ! raw 없음: %s" % raw_path)
        return False
    img = Image.open(raw_path).convert("RGBA")
    hard_alpha(img)
    fn(img)
    center_in(img, TILE, TILE).save(out_path)
    return True


def build_icons() -> None:
    raw_dir = os.path.join(MATERIALS, "raw")
    made = 0
    for base, table in (("ore_base", ORE_TINTS), ("ingot_base", INGOT_TINTS),
                        ("gem_base", GEM_TINTS), ("geode_base", GEODE_TINTS),
                        ("sword_base", SWORD_TINTS)):
        src = os.path.join(raw_dir, base + "_raw.png")
        for item_id, col in table.items():
            if _bake(src, os.path.join(MATERIALS, item_id + ".png"),
                     lambda im, c=col: apply_px(im, lambda p: species_tint(p, c))):
                made += 1
    # 업화도 = 굽은 도(刀) 원본 + 업화 불빛 틴트
    if _bake(os.path.join(raw_dir, "sword_dao_raw.png"),
             os.path.join(MATERIALS, "sword_eophwado.png"),
             lambda im: apply_px(im, lambda p: species_tint(p, (0.86, 0.38, 0.22)))):
        made += 1
    # 명부금강(백청) = 브릴리언트 한 알 + 단색 틴트 / 오색혼옥 = 같은 알 + 색상환 한 바퀴
    brill = os.path.join(raw_dir, "gem_brilliant_raw.png")
    if _bake(brill, os.path.join(MATERIALS, "gem_myeongbu_geumgang.png"),
             lambda im: apply_px(im, lambda p: species_tint(p, (0.72, 0.90, 0.98)))):
        made += 1
    if os.path.exists(brill):
        img = Image.open(brill).convert("RGBA")
        hard_alpha(img)
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                p = px[x, y]
                if p[3] < ALPHA_CUT:
                    px[x, y] = (0, 0, 0, 0)
                    continue
                px[x, y] = prismatic_tint(p[:3], y, img.height) + (255,)
        center_in(img, TILE, TILE).save(os.path.join(MATERIALS, "gem_osaek_honok.png"))
        made += 1
    for item_id in PLAIN_IDS:
        if _bake(os.path.join(raw_dir, item_id + "_raw.png"),
                 os.path.join(MATERIALS, item_id + ".png"),
                 lambda im: apply_px(im, lambda p: mute(p, ICON_SAT, ICON_VAL))):
            made += 1
    print("  materials: 아이콘 %d종(원본 9 + 틴트 파생 18)" % made)


# ══ 3) 갱도 어종 2종 ═════════════════════════════════════════════════════════
# ★[S3-T10] 어획물 아이콘 20종과 **같은 계수**(0.90/0.97)로 굽는다 — 어롱·매대에서 삼도천·황천해
#   어종과 한 목록에 서므로 톤이 갈리면 갱도 둘만 튄다.
FISH_IDS = ["dolbineul_chi", "eophwa_bungjangeo"]


def build_fish() -> None:
    made = 0
    for fish_id in FISH_IDS:
        if _bake(os.path.join(FISH, "raw", fish_id + "_raw.png"),
                 os.path.join(FISH, fish_id + ".png"),
                 lambda im: apply_px(im, lambda p: mute(p, ICON_SAT, ICON_VAL))):
            made += 1
    print("  fish: 갱도 어종 %d종" % made)


# ══ 4) 점주 2인 시트 ═════════════════════════════════════════════════════════
# 네오(§11.4)·뱃사공(§13.3)·옹이(§15.6)와 같은 **정지 rotation 1열** 시트다 — 상주 점주라 워크
# 첫 프레임(스트라이드)을 쓰면 서 있어야 할 사람이 걷는 듯 보인다.
# 풀무는 모루 옆, 무골은 길드 카운터 뒤에 고정이라 방향 전환도 안 한다(walk_down만 재생된다).
def place_frame(content: Image.Image) -> Image.Image:
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    frame.paste(content, ((FRAME - content.width) // 2, max(0, FOOT_Y - content.height)), content)
    return frame


def build_shopkeeper(stem: str) -> None:
    src = os.path.join(CHARS, stem + "_raw")
    if not os.path.isdir(src):
        print("  ! %s raw 폴더 없음(건너뜀)" % stem)
        return
    sheet = Image.new("RGBA", (FRAME, FRAME * len(ROW_DIRS)), (0, 0, 0, 0))
    for row, d in enumerate(ROW_DIRS):
        p = os.path.join(src, d + ".png")
        if not os.path.exists(p):
            print("  ! %s %s 없음" % (stem, d))
            continue
        raw = Image.open(p).convert("RGBA")
        hard_alpha(raw)
        apply_px(raw, lambda c: mute(c, CAST_SAT, CAST_VAL))
        box = raw.getbbox()
        if box is None:
            continue
        sheet.paste(place_frame(raw.crop(box)), (0, row * FRAME))
    sheet.save(os.path.join(CHARS, stem + ".png"))
    print("  %s.png %dx%d" % (stem, sheet.size[0], sheet.size[1]))


# ══ 5) 풀무 도트 초상화 ══════════════════════════════════════════════════════
# PixelLab `create_portrait_character(character_to_portrait)`가 위 시트 south 프레임에서 뽑은 128²
# 버스트 → 하드 알파 + ×2 nearest(256²). 네오·뱃사공·옹이와 같은 **도트 스톱갭**이다(교체 큐).
def build_portrait(stem: str) -> None:
    raw_path = os.path.join(PORTRAITS, stem + "_raw.png")
    if not os.path.exists(raw_path):
        print("  ! 초상화 raw 없음(건너뜀): %s" % raw_path)
        return
    raw = Image.open(raw_path).convert("RGBA")
    hard_alpha(raw)
    raw.resize((raw.width * 2, raw.height * 2), Image.NEAREST).save(
        os.path.join(PORTRAITS, stem + ".png"))
    print("  %s.png(portrait) %dx%d" % (stem, raw.width * 2, raw.height * 2))


# ══ 6) 업화로 화덕 프롭 ══════════════════════════════════════════════════════
# [§16.6]이 자리를 예약해 둔 마지막 실내 그레이박스(붉은 사각 + 주홍 심지)의 교체분.
# 크기 64×32(2×1칸) = 모루(smithy_anvil)와 같은 규격이라 드로우가 같은 문법으로 앉는다.
# ★raw는 64×48(아치 + 후드가 세로로 서는 물건이라 그 비율로 뽑았다)이고, 여기서 **높이 32에
#   맞춰 비례 축소**한다 — 벽 링을 안 덮는다는 §16.6 규칙을 지키려면 화덕이 방 첫 줄(y+1)
#   안에 온전히 들어와야 한다. 늘리지 않고 줄이기만 하므로 청키는 보존된다.
def build_forge() -> None:
    raw_path = os.path.join(PROPS, "smithy_forge_raw.png")
    if not os.path.exists(raw_path):
        print("  ! 화덕 raw 없음(건너뜀)")
        return
    img = Image.open(raw_path).convert("RGBA")
    hard_alpha(img)
    apply_px(img, lambda c: mute(c, 0.86, 0.94))   # 대장간 외관(smithy_ext)과 같은 검댕 계수
    foot_flush(img, TILE * 2, TILE).save(os.path.join(PROPS, "smithy_forge.png"))
    print("  props/smithy_forge.png %dx%d" % (TILE * 2, TILE))


def main() -> None:
    print("[S5-T10] 잡귀·점주·아이콘 아트 후처리")
    build_mobs()
    build_icons()
    build_fish()
    build_shopkeeper("pulmu")
    build_shopkeeper("mugol")
    build_portrait("pulmu")
    build_forge()
    print("완료")


if __name__ == "__main__":
    main()
