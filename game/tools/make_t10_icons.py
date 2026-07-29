#!/usr/bin/env python3
# ★[S4-T10 / ADR-0062 결정 10 ㉣㉤㉥] 숲 아트 패스 2 후처리 글루
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab 생성 raw → 게임 규격으로 굳힌다:
#   [asset-ruleset §8.1] 하드 알파 · [§9] 저승 muted · [§0.1] 2px 청키 · [ADR-0050] 32-native ·
#   [§2] 정면 facade 남향 · [§3] bottom-center 앵커 · 캐릭터 시트 규약(FRAME 80 · 발치 y=74)
#
#   1) 채집물 아이콘 24종            32×32   assets/forage/<id>.png
#   2) 자재·수액·씨앗 아이콘 12종    32×32   assets/materials/<id>.png
#   3) 씨앗 봉지 9종(절기 틴트 파생)  32×32   assets/materials/seed_<crop id>.png
#   4) 건물 외관 2종                        assets/buildings/{woodshop,okja_hut}_ext.png
#   5) 옹이 시트                     80×320  assets/characters/ongi.png
#   6) 옹이 초상화                   256×256 assets/portraits/ongi.png
#   7) 수액 채취기 월드 프롭         32×32   assets/props/sap_tapper.png
#
# ★ 멱등: raw에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: python3 tools/make_t10_icons.py   (game/ 에서)
import colorsys
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FORAGE = os.path.join(ROOT, "assets", "forage")
MATERIALS = os.path.join(ROOT, "assets", "materials")
BUILD = os.path.join(ROOT, "assets", "buildings")
CHARS = os.path.join(ROOT, "assets", "characters")
PORTRAITS = os.path.join(ROOT, "assets", "portraits")
PROPS = os.path.join(ROOT, "assets", "props")

TILE = 32
ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)
FRAME = 80         # 캐릭터 시트 규약(char_sprite.gd FRAME=80)
ROW_DIRS = ["south", "north", "east", "west"]   # 행 순서 = down/up/right/left
FOOT_Y = 74        # 출하 캐스트 5종 실측 발치선(make_naru_art2.py 주석 참조)

# [§9] 저승 muted — 아이콘은 슬롯에서 서로 구분돼야 하므로 프롭(0.85/0.95)보다 얕게 누른다
#   (make_s3_icons.py가 어획물 32종에 쓴 계수 그대로 — 낚시 아이콘과 나란히 놓여도 톤이 안 튄다).
ICON_SAT = 0.90
ICON_VAL = 0.97


def hard_alpha(img: Image.Image) -> Image.Image:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= ALPHA_CUT else 0)
    return img


def mute(rgb, sat_mul: float, val_mul: float):
    """[§9] 저승 muted — 채도·명도만 눌러 형태·정체색은 보존."""
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    s = max(0.0, min(1.0, s * sat_mul))
    v = max(0.0, min(1.0, v * val_mul))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))


# 씨앗 봉지 틴트 — 한 장을 절기색으로 물들여 아홉 종을 만든다(build_seed_packets 참조).
# ★두 번의 실패에서 얻은 규칙(1차 육안 리젝):
#   ㉠ **hue_lerp는 1.0이어야 한다.** 0.5로 두면 tan(0.09)에서 청록(0.56)으로 가는 절반 지점인
#      **초록**에 착지해, 성야(청백)와 유화(초록)가 같은 색이 됐다. 부분 lerp는 "색을 섞는" 게
#      아니라 "엉뚱한 색에 멈추는" 것이다.
#   ㉡ **sat_add가 없으면 흰 비단 주머니는 안 물든다.** 채도 0 픽셀은 hue를 어디로 돌려도 흰색
#      그대로다 — 희귀 모종 4종이 전부 같은 흰 주머니로 나온 원인. 그래서 채도를 *더한다*.
#      단 **어두운 외곽선은 제외**(v>_TINT_V_MIN) — 안 그러면 검은 테가 색 테로 바뀌어 [§1]
#      단일 외곽선 규약이 깨진다.
_TINT_V_MIN = 0.35


def tint(rgb, hue_to: float, sat_add: float, val_mul: float):
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v > _TINT_V_MIN:
        h = hue_to % 1.0
        s = max(0.0, min(1.0, s * ICON_SAT + sat_add))
    v = max(0.0, min(1.0, v * val_mul * ICON_VAL))
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


# ── 1·2) 아이템 아이콘 ────────────────────────────────────────────────────────
# ★ 크기를 손대지 않는다: 32-native 생성물을 그대로 쓴다([ADR-0050] "AI 축소본은 뭉개진다").
#   콘텐츠만 32² 안에서 가운데로 다시 앉힌다 — 슬롯(inv_frame `_draw_icon`)이 아이콘을 통째로
#   늘려 그리므로 여백이 한쪽에 몰리면 옆 슬롯과 눈금이 어긋나 보인다.
def build_icon(raw_path: str, out_path: str) -> None:
    img = Image.open(raw_path).convert("RGBA")
    hard_alpha(img)
    apply_px(img, lambda c: mute(c, ICON_SAT, ICON_VAL))
    box = img.getbbox()
    if box is not None:
        content = img.crop(box)
        img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        img.paste(content, ((TILE - content.width) // 2, (TILE - content.height) // 2), content)
    img.save(out_path)


# 채집물(ItemCatalog.FORAGEABLES 21 + 덤불 열매 2 + 저승 이끼 1) — 파일명 = 아이템 id = 배선.
# ★불사과(CropCatalog.BULSAGWA)는 여기 없다 — 이미 작물 3프레임 아트가 있어 CROP_SPRITES가
#   mature 프레임을 인벤 아이콘으로 재사용한다(중복 생성 0 원칙).
FORAGE_IDS = [
    # 저승 숲 일반 12(절기당 3)
    "neok_gosari", "jaetbit_naengi", "jeoseung_dallae",
    "jeoseung_sandalgi", "honip_bakha", "jaetbit_deodeok",
    "jaetbit_dotori", "angae_doraji", "neok_songi",
    "eonhon_ppuri", "seori_dongbaek", "seongya_solbangul",
    # 미혹 희소 4(절기당 1)
    "mihok_nancho", "yuryeongcho", "myeongwol_beoseot", "seori_honbaekcho",
    # 미혹 심층 1(+불사과는 작물 아트 재사용)
    "jeoseung_sam",
    # 황천해 해변 4(절기 무관)
    "hwangcheon_sanho", "neok_seonggae", "yuri_godung", "mulbineul_jogae",
    # 덤불 열매 2(ADR-0062 결정 9 ㉠) + 저승 이끼(㉡)
    "neok_dalgi", "jaetbit_bokbunja", "jeoseung_ikki",
]

# 자재·수액·나무 씨앗 — 파일명 = 아이템 id.
MATERIAL_IDS = [
    "wood", "hardwood", "sap",                             # 벌목 산출(기축 자재)
    "solneokjin", "neoksuji", "myeongdanpung_kkul",        # 수액 3종(채취기 산출)
    "seed_jeoseungsol", "seed_myeongdanpung", "seed_neokcham",   # 나무 씨앗 3종
    # ★곁들여 메운 **기존 슬라이스 색박스 5종**. 스코프 밖이었지만 이번 인벤 덤프에서
    #   원목 바로 옆 칸에 나란히 떠 색박스인 게 드러났다 — 같은 CAT_MATERIAL 줄에서 절반만
    #   도트면 새 아이콘 쪽이 오히려 튄다. 한 패스에서 자재 카테고리 폴백을 0으로 닫는다.
    #   (개간 드랍 3: 석화 목재·혼백 섬유·업화석 조각 / 목축 1: 건초 / 낚시 잡동사니 1: 삭은 그물)
    "petrified_wood", "soul_fiber", "ember_shard", "hay", "rotten_net",
]


def build_icons() -> None:
    for group, ids in ((FORAGE, FORAGE_IDS), (MATERIALS, MATERIAL_IDS)):
        made = 0
        for item_id in ids:
            raw = os.path.join(group, "raw", item_id + "_raw.png")
            if not os.path.exists(raw):
                print("  ! raw 없음: %s" % raw)
                continue
            build_icon(raw, os.path.join(group, item_id + ".png"))
            made += 1
        print("  %s: %d/%d개" % (os.path.basename(group), made, len(ids)))
    # 수액 채취기 인벤 아이콘 = 통만 든 판(월드 프롭은 나무에 박힌 판 — 아래 build_tapper_prop).
    #   ★게잡이통(S3-T7)은 아이콘·월드가 한 텍스처였지만 채취기는 갈랐다: 채취기는 *나무에 박히는*
    #     물건이라 월드 판엔 줄기가 있어야 읽히고, 그 줄기가 인벤 슬롯에선 군더더기다.
    tap_raw = os.path.join(MATERIALS, "raw", "sap_tapper_icon_raw.png")
    if os.path.exists(tap_raw):
        build_icon(tap_raw, os.path.join(MATERIALS, "sap_tapper.png"))
        print("  materials: sap_tapper.png(인벤 아이콘)")


# ── 3) 씨앗 봉지 9종 = 원본 2장의 절기 틴트 파생 ──────────────────────────────
# 야생·혼합·희귀 씨앗은 **인벤에서 작물 id로 조회된다**(`_draw_crop_tex(ItemCatalog.crop_of(id))`)
# → 파일명이 작물 id다. 아홉 종을 따로 그리지 않는 이유:
#   ㉠ 스타듀의 야생 씨앗도 전부 같은 봉지 실루엣이고 절기색만 다르다(문법 상속),
#   ㉡ 봉지 9장을 각자 생성하면 실루엣이 제각각으로 흔들려 오히려 "한 계열"로 안 읽힌다,
#   ㉢ [ADR-0001] 큐레이션 — 아이콘 예산은 채집물 24종이 이미 천장이다.
# 틴트는 hue를 절기색으로 *당기고*(lerp) 채도만 살짝 올린다 — 종이 질감·묶은 끈의 명암은 보존된다.
# (hue, sat_add, val_mul). hue=None이면 틴트 없이 muted만(혼합 = 어느 절기도 아니라 종이색 그대로).
SEED_TINTS = {
    "honhap": (None, 0.0, 1.00),           # 혼합 — 무채 종이(색으로도 "섞인 것" = 중립)
    "yasaeng_pian": (0.98, 0.22, 0.98),    # 피안절 — 붉음(피안화)
    "yasaeng_yuhwa": (0.30, 0.20, 1.00),   # 유화절 — 초록(성하)
    "yasaeng_mangyeon": (0.07, 0.34, 0.84),  # 망연절 — 짙은 황갈(낙엽). ★명도를 눌러야 무채 종이와 갈린다
    "yasaeng_seongya": (0.55, 0.22, 1.06),   # 성야절 — 청백(서리)
}
# 희귀 모종 4 = 흰 비단 주머니(금끈·봉랍) 판을 종별 색으로 물들인다(원종 꽃색과 짝지어).
#   ★흰 바탕이라 sat_add를 야생 봉지보다 크게 준다(안 그러면 넷이 전부 흰 주머니 — 1차 리젝).
RARE_TINTS = {
    "mihok_nancho_wild": (0.80, 0.34, 1.00),       # 미혹난초 — 자보라
    "yuryeongcho_wild": (0.42, 0.32, 1.02),        # 유령초 — 창백한 청록
    "myeongwol_beoseot_wild": (0.62, 0.34, 1.00),  # 명월버섯 — 달빛 파랑
    "seori_honbaekcho_wild": (0.12, 0.30, 1.02),   # 서리혼백초 — 옅은 금빛(위 셋과 색환에서 떼어 놓는다)
}


def _tint_packet(raw_path: str, out_path: str, hue, sat_add: float, val: float) -> None:
    img = Image.open(raw_path).convert("RGBA")
    hard_alpha(img)
    if hue is None:
        apply_px(img, lambda c: mute(c, ICON_SAT, ICON_VAL * val))
    else:
        apply_px(img, lambda c: tint(c, hue, sat_add, val))
    box = img.getbbox()
    if box is not None:
        content = img.crop(box)
        img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        img.paste(content, ((TILE - content.width) // 2, (TILE - content.height) // 2), content)
    img.save(out_path)


def build_seed_packets() -> None:
    plain = os.path.join(MATERIALS, "raw", "seed_packet_raw.png")
    rare = os.path.join(MATERIALS, "raw", "seed_pouch_rare_raw.png")
    n = 0
    for src, table in ((plain, SEED_TINTS), (rare, RARE_TINTS)):
        if not os.path.exists(src):
            print("  ! 봉지 raw 없음: %s" % src)
            continue
        for crop_id, (hue, sat_add, val) in table.items():
            _tint_packet(src, os.path.join(MATERIALS, crop_id + ".png"), hue, sat_add, val)
            n += 1
    print("  materials: 씨앗 봉지 %d종(틴트 파생)" % n)


# ── 4) 건물 외관 ─────────────────────────────────────────────────────────────
# [§11.0 공통 규약] 폭 = footprint 폭 정확히 / 높이 ≥ footprint 높이(지붕이 위로 솟음).
# PixelLab은 캔버스 대비 콘텐츠 여백이 생성마다 흔들려 캔버스로는 못 맞춘다 → half-res(16논리px)
# 격자에서 NEAREST로 맞춘 뒤 ×2(=§0.1 2px 청키 보장). make_s3_art.fit_facade와 같은 함수다.
def fit_facade(raw: Image.Image, tiles_w: int, tiles_h: int) -> Image.Image:
    box = raw.getbbox()
    content = raw.crop(box)
    hw = tiles_w * TILE // 2
    hh = round(content.height * hw / content.width)
    hh = max(hh, tiles_h * TILE // 2)
    small = content.resize((hw, hh), Image.NEAREST)
    return hard_alpha(small.resize((hw * 2, hh * 2), Image.NEAREST).convert("RGBA"))


def build_facades() -> None:
    # 목공방 = WOODSHOP_EXT_RECT Rect2i(6,14,7,6) — 폭 7칸(224) 1:1.
    # 옥자 집 = OKJA_HUT_EXT_RECT Rect2i(54,24,8,7) — 폭 8칸(256) 1:1.
    for raw_name, out_name, tw, th, sat, val in [
        ("woodshop_ext_raw", "woodshop_ext", 7, 6, 0.88, 0.96),
        # 옥자 집은 **잠긴 폐가**라 한 단 더 눌러 톤으로도 "사람이 안 사는 집"이 읽히게 한다
        #   (목공방 0.88/0.96 대비 채도↓·명도↓ — 두 채가 나란히 서지 않으므로 대비는 구역 간).
        ("okja_hut_ext_raw", "okja_hut_ext", 8, 7, 0.80, 0.90),
    ]:
        raw_path = os.path.join(BUILD, "raw", raw_name + ".png")
        if not os.path.exists(raw_path):
            print("  ! raw 없음: %s" % raw_path)
            continue
        raw = Image.open(raw_path).convert("RGBA")
        hard_alpha(raw)
        img = fit_facade(raw, tw, th)
        apply_px(img, lambda c: mute(c, sat, val))
        img.save(os.path.join(BUILD, out_name + ".png"))
        print("  %s.png %dx%d" % ((out_name,) + img.size))


# ── 5) 옹이 스프라이트 시트 ──────────────────────────────────────────────────
# 네오(§11.4)·뱃사공(§13.3)과 같은 **정지 rotation 1열** 시트다 — 상주 점주라 워크 첫 프레임
# (스트라이드)을 쓰면 서 있어야 할 사람이 걷는 듯 보인다([p2.0-spike §10.12] 미호 교훈).
# 옹이 스케줄은 목공방 카운터 한 칸 고정이라 실제로 방향 전환도 안 한다(walk_down만 재생된다).
def place_frame(content: Image.Image) -> Image.Image:
    """콘텐츠를 80×80 프레임에 발치정렬(가로중앙)."""
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    frame.paste(content, ((FRAME - content.width) // 2, max(0, FOOT_Y - content.height)), content)
    return frame


def build_ongi() -> None:
    src = os.path.join(CHARS, "ongi_raw")
    if not os.path.isdir(src):
        print("  ! 옹이 raw 폴더 없음(건너뜀)")
        return
    sheet = Image.new("RGBA", (FRAME, FRAME * len(ROW_DIRS)), (0, 0, 0, 0))
    for row, d in enumerate(ROW_DIRS):
        p = os.path.join(src, d + ".png")
        if not os.path.exists(p):
            print("  ! 옹이 %s 없음" % d)
            continue
        raw = Image.open(p).convert("RGBA")
        hard_alpha(raw)
        apply_px(raw, lambda c: mute(c, 0.94, 0.98))   # 캐스트와 나란히 서므로 아주 얕게만
        box = raw.getbbox()
        if box is None:
            continue
        frame = place_frame(raw.crop(box))
        sheet.paste(frame, (0, row * FRAME), frame)
    sheet.save(os.path.join(CHARS, "ongi.png"))
    print("  ongi.png %dx%d" % sheet.size)


# ── 6) 옹이 초상화 ───────────────────────────────────────────────────────────
# PixelLab `create_portrait_character(character_to_portrait)`가 위 시트 south 프레임에서 뽑은 128²
# 버스트 → 하드 알파 + ×2 nearest(256²). ★네오·뱃사공과 같은 **도트 스톱갭**이다(교체 1순위).
def build_ongi_portrait() -> None:
    raw_path = os.path.join(PORTRAITS, "ongi_raw.png")
    if not os.path.exists(raw_path):
        print("  ! 초상화 raw 없음(건너뜀): %s" % raw_path)
        return
    raw = Image.open(raw_path).convert("RGBA")
    hard_alpha(raw)
    img = raw.resize((raw.width * 2, raw.height * 2), Image.NEAREST)
    img.save(os.path.join(PORTRAITS, "ongi.png"))
    print("  ongi.png(portrait) %dx%d" % img.size)


# ── 7) 수액 채취기 월드 프롭 ─────────────────────────────────────────────────
# [§3] 야외 바닥 프롭은 발치 기준 — 32² 프레임 **바닥에 붙여** 앉힌다(_draw_tappers가 타일
# 좌상단에 그리므로 콘텐츠가 위로 뜨면 나무 밑동이 아니라 허공에 통이 걸린다).
def build_tapper_prop() -> None:
    raw_path = os.path.join(MATERIALS, "raw", "sap_tapper_raw.png")
    if not os.path.exists(raw_path):
        print("  ! 채취기 프롭 raw 없음(건너뜀)")
        return
    raw = Image.open(raw_path).convert("RGBA")
    hard_alpha(raw)
    apply_px(raw, lambda c: mute(c, 0.85, 0.95))   # 프롭 계수(아이콘보다 깊게 — 숲 프롭과 톤 정합)
    box = raw.getbbox()
    body = raw.crop(box)
    out = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    out.paste(body, ((TILE - body.width) // 2, TILE - body.height), body)
    out.save(os.path.join(PROPS, "sap_tapper.png"))
    print("  props/sap_tapper.png %dx%d" % out.size)


def main() -> None:
    print("[S4-T10] 숲 아이콘·외관·옹이 아트 후처리")
    build_icons()
    build_seed_packets()
    build_facades()
    build_ongi()
    build_ongi_portrait()
    build_tapper_prop()
    print("완료")


if __name__ == "__main__":
    main()
