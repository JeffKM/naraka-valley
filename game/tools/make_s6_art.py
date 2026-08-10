#!/usr/bin/env python3
# ★[S6-T8 / ADR-0064 아트 스코프] 카페 슬라이스 아트 패스 1 후처리 글루
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab 생성 raw → 게임 규격으로 굳힌다. 규칙은 make_t10_icons.py(숲 아트 패스)와 **같다** —
#   [asset-ruleset §8.1] 하드 알파 · [§9] 저승 muted · [ADR-0050] 32-native · [§3] 발치 앵커
# 새 규칙을 세우지 않는다(두 패스가 갈리면 인벤 한 줄에서 톤이 튄다).
#
#   1) 메뉴 아이콘 16종        32×32   assets/menu/<menu id>.png
#   2) 곳간 찬장 프롭          32×64   assets/props/larder.png
#   3) 출하함 궤짝 프롭        32×32   assets/props/ship_bin.png
#   4) HUD 배지 2종            24×24   assets/ui/{cheki_camera,cocktail_shaker}.png
#   5) 익명 손님 상 2종+변주   32×48   assets/characters/guest_anon_<n>.png
#   6) 주방요괴 시트          80×320  assets/characters/kitchen_youkai.png   ★[S6-T9] 아트 패스 2
#
# ★ 멱등: raw에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: python3 tools/make_s6_art.py   (game/ 에서)
import colorsys
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MENU = os.path.join(ROOT, "assets", "menu")
PROPS = os.path.join(ROOT, "assets", "props")
UI = os.path.join(ROOT, "assets", "ui")
CHARS = os.path.join(ROOT, "assets", "characters")

TILE = 32
ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)

# [§9] 저승 muted — 아이콘 계수는 make_t10_icons.py와 **동일**(0.90/0.97). 메뉴 아이콘은
# 채집물·어획물과 같은 인벤 격자에 섞여 뜨므로 계수가 다르면 그 칸만 튄다.
ICON_SAT = 0.90
ICON_VAL = 0.97
# 프롭 계수(아이콘보다 깊게 — 실내 가구·프롭 톤 정합. make_t10_icons.build_tapper_prop과 같은 값).
PROP_SAT = 0.85
PROP_VAL = 0.95


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


# 익명 손님 변주 틴트 — 한 장을 혼(魂)빛으로 물들여 여러 손님을 만든다. 규칙은 씨앗 봉지
# (make_t10_icons.tint)에서 그대로 가져왔다: **hue는 완전히 갈아끼우고**(부분 lerp는 엉뚱한 색에
# 착지) **어두운 외곽선은 제외**(v>_TINT_V_MIN — 안 그러면 검은 테가 색 테로 바뀐다).
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


def _fit(img: Image.Image, w: int, h: int, anchor: str) -> Image.Image:
    """콘텐츠를 w×h 캔버스에 다시 앉힌다. anchor='center'(아이콘) / 'bottom'(월드 프롭)."""
    box = img.getbbox()
    if box is None:
        return img
    content = img.crop(box)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = (w - content.width) // 2
    y = (h - content.height) // 2 if anchor == "center" else h - content.height
    out.paste(content, (x, max(0, y)), content)
    return out


# ── 1) 메뉴 아이콘 16종 ───────────────────────────────────────────────────────
# 파일명 = **MenuCatalog의 메뉴 id** = 배선(main.MENU_ICONS가 그 id로 preload한다).
# ★ 크기를 손대지 않는다: 32-native 생성물을 그대로 쓴다([ADR-0050] "AI 축소본은 뭉개진다").
#   콘텐츠만 32² 안에서 가운데로 다시 앉힌다(슬롯이 아이콘을 통째로 늘려 그리므로 여백이
#   한쪽으로 몰리면 옆 슬롯과 눈금이 어긋나 보인다 — make_t10_icons.build_icon과 같은 이유).
MENU_IDS = [
    # 기본 4(무재료·항시 — 잔이 소박하다)
    "menu_americano", "menu_cold_water", "menu_barley_tea", "menu_hot_milk",
    # 융합 12 — 음료 7(판매 전용) + 요리 5(곁들이, MenuCatalog.SIDE_DISHES)
    "menu_honryeongcho_latte", "menu_pianhwa_ade", "menu_hobak_latte",
    "menu_podo_smoothie", "menu_haepari_ade", "menu_dongbaek_milktea",
    "menu_honjeong_einspanner",
    "menu_bulsagwa_tart", "menu_bungeo_ppang", "menu_domi_panini",
    "menu_songi_soup", "menu_danpung_pancake",
]


def build_menu_icons() -> None:
    made = 0
    for menu_id in MENU_IDS:
        raw = os.path.join(MENU, "raw", menu_id + "_raw.png")
        if not os.path.exists(raw):
            print("  ! raw 없음: %s" % raw)
            continue
        img = Image.open(raw).convert("RGBA")
        hard_alpha(img)
        apply_px(img, lambda c: mute(c, ICON_SAT, ICON_VAL))
        _fit(img, TILE, TILE, "center").save(os.path.join(MENU, menu_id + ".png"))
        made += 1
    print("  menu: %d/%d개" % (made, len(MENU_IDS)))


# ── 2·3) 카페 설비 프롭 ───────────────────────────────────────────────────────
# 곳간은 **세로 2칸(32×64)** — 벽에 기대선 찬장이라 바닥 한 칸에만 앉히면 사물함처럼 납작해진다.
# LARDER_TILE(9,88) 바닥에 발치정렬해 위 칸(9,87 — 빈 뒷벽)으로 솟는다. 출하함은 바닥 궤짝이라 1칸.
# ★ 둘 다 재고 표식(_draw_larder / _draw_ship_bin)은 코드가 스프라이트 **위에** 얹으므로 여기선
#   빈 설비만 굽는다(재고가 그림에 박히면 비었을 때도 차 보인다).
def build_fixtures() -> None:
    for raw_name, out_name, w, h in [
        ("larder_raw", "larder", TILE, TILE * 2),
        ("ship_bin_raw", "ship_bin", TILE, TILE),
    ]:
        raw_path = os.path.join(PROPS, "raw", raw_name + ".png")
        if not os.path.exists(raw_path):
            print("  ! raw 없음: %s" % raw_path)
            continue
        img = Image.open(raw_path).convert("RGBA")
        hard_alpha(img)
        apply_px(img, lambda c: mute(c, PROP_SAT, PROP_VAL))
        out = _fit(img, w, h, "bottom")
        out.save(os.path.join(PROPS, out_name + ".png"))
        print("  props/%s.png %dx%d" % ((out_name,) + out.size))


# ── 4) 미니게임 HUD 배지 2종 ─────────────────────────────────────────────────
# 체키 판·칵테일 판이 **같은 자리에 같은 크기**로 뜨므로(_CHUD_*/_KHUD_* 상수 동일), 판 왼쪽의
# 배지 하나가 "지금 무슨 미니게임인가"를 말한다. 24² = 판 높이(34) 안에 여백을 두고 앉는 최대치.
BADGE = 24


def build_badges() -> None:
    for raw_name, out_name in [("cheki_camera_raw", "cheki_camera"),
                               ("cocktail_shaker_raw", "cocktail_shaker")]:
        raw_path = os.path.join(UI, "raw", raw_name + ".png")
        if not os.path.exists(raw_path):
            print("  ! raw 없음: %s" % raw_path)
            continue
        img = Image.open(raw_path).convert("RGBA")
        hard_alpha(img)
        # 배지는 어두운 한지 판 위 작은 표식이라 아이콘 계수보다 얕게(눌러 두면 판에 묻힌다).
        apply_px(img, lambda c: mute(c, 0.94, 1.0))
        out = _fit(img, BADGE, BADGE, "center")
        out.save(os.path.join(UI, out_name + ".png"))
        print("  ui/%s.png %dx%d" % ((out_name,) + out.size))


# ── 5) 익명 손님 상 ──────────────────────────────────────────────────────────
# 스툴에 앉은 이름 없는 혼(魂). **명명 손님은 기존 주민 시트를 그대로 쓰므로**(신규 생성 0,
# ADR-0064 결정 8) 여기서 굽는 건 익명 볼륨용 상뿐이다.
# ★ 32×48 = 한 칸 폭 · 한 칸 반 높이. 스툴(y90)에 발치정렬로 앉으면 상반신이 위 칸으로 올라와
#   카운터 너머에서도 보인다(그레이박스 _draw_graybox_figure가 쓰던 자리와 같은 앵커).
# ★ 변주는 **틴트 파생**이다(원본 2장 → 8인). 익명은 정체가 없으므로 실루엣이 갈릴 필요가 없고,
#   오히려 혼빛만 다른 무리가 "이름 없는 손님들"로 읽힌다(씨앗 봉지 9종과 같은 판단).
# ★[S6-T9] a3·b3 추가 — **신규 생성 0**(같은 raw 2장의 틴트 파생). 좌석 5석 + 밤 바 5석이 같은
#   날 굴러가므로 6상이면 한 화면에 같은 혼빛이 겹쳐 앉는 일이 잦았다. hue는 기존 4색이 비워 둔
#   자리에만 꽂는다(0.10 · 0.36 · 0.58 · 0.86 → 사이의 0.72 · 0.98) — 두 손님의 혼빛이 서로
#   "같은 색의 다른 명도"로 보이면 변주를 늘린 값이 사라진다.
GUEST_TINTS = [
    ("a0", 0, None, 0.00, 1.00),   # 원본 톤(틴트 없음)
    ("a1", 0, 0.58, 0.16, 0.96),   # 서늘한 청
    ("a2", 0, 0.86, 0.14, 1.00),   # 옅은 자보라
    ("a3", 0, 0.72, 0.15, 0.95),   # ★[S6-T9] 깊은 남보라(청 ↔ 자보라 사이)
    ("b0", 1, None, 0.00, 1.00),
    ("b1", 1, 0.10, 0.18, 0.94),   # 마른 갈금
    ("b2", 1, 0.36, 0.14, 0.98),   # 이끼빛 청록
    ("b3", 1, 0.98, 0.16, 0.93),   # ★[S6-T9] 삭은 진홍(자보라 ↔ 갈금 사이)
]
GUEST_W, GUEST_H = TILE, 48


def build_guests() -> None:
    srcs = []
    for i in range(2):
        p = os.path.join(CHARS, "guest_raw", "guest_anon_%d_raw.png" % i)
        srcs.append(Image.open(p).convert("RGBA") if os.path.exists(p) else None)
    made = 0
    for name, idx, hue, sat_add, val in GUEST_TINTS:
        if srcs[idx] is None:
            print("  ! 손님 raw 없음: guest_anon_%d_raw.png" % idx)
            continue
        img = srcs[idx].copy()
        hard_alpha(img)
        if hue is None:
            apply_px(img, lambda c: mute(c, ICON_SAT, ICON_VAL * val))
        else:
            apply_px(img, lambda c: tint(c, hue, sat_add, val))
        out = _fit(img, GUEST_W, GUEST_H, "bottom")
        out.save(os.path.join(CHARS, "guest_anon_%s.png" % name))
        made += 1
    print("  characters: 익명 손님 %d상(원본 2 + 틴트 파생)" % made)


# ── 6) ★[S6-T9] 주방요괴 시트 ────────────────────────────────────────────────
# 80×320 = 프레임 80² · **1열**(정지 rotation) × 4행(down/up/right/left). 주방요괴는 자리가
# 하나뿐이라 실제로 안 걷는다 → 워크 4프레임을 안 뽑는 게 맞다(네오·풀무·무골·옹이와 같은
# 상주 정지 NPC 규약 — 워크 첫 프레임은 스트라이드라 서 있어야 할 NPC가 걷는 듯 보인다).
# 계수·발치선은 make_mob_art.build_shopkeeper와 **같은 값**이다(0.94/0.98 · FOOT_Y 74) —
# 카페 무대에서 옥자·멜과 나란히 서므로 다른 값을 쓰면 이 한 사람만 톤이 튄다.
CHAR_FRAME = 80        # char_sprite.gd FRAME=80
CHAR_FOOT_Y = 74       # 출하 캐스트 5종 실측 발치선
CHAR_ROWS = ["south", "north", "east", "west"]   # 행 순서 = down/up/right/left
CAST_SAT, CAST_VAL = 0.94, 0.98


def build_kitchen_youkai() -> None:
    src = os.path.join(CHARS, "kitchen_youkai_raw")
    if not os.path.isdir(src):
        print("  ! kitchen_youkai_raw 폴더 없음(건너뜀)")
        return
    sheet = Image.new("RGBA", (CHAR_FRAME, CHAR_FRAME * len(CHAR_ROWS)), (0, 0, 0, 0))
    for row, d in enumerate(CHAR_ROWS):
        p = os.path.join(src, d + ".png")
        if not os.path.exists(p):
            print("  ! kitchen_youkai %s 없음 — 빈 행" % d)
            continue
        raw = Image.open(p).convert("RGBA")
        hard_alpha(raw)
        apply_px(raw, lambda c: mute(c, CAST_SAT, CAST_VAL))
        box = raw.getbbox()
        if box is None:
            continue
        content = raw.crop(box)
        frame = Image.new("RGBA", (CHAR_FRAME, CHAR_FRAME), (0, 0, 0, 0))
        frame.paste(content, ((CHAR_FRAME - content.width) // 2,
                              max(0, CHAR_FOOT_Y - content.height)), content)
        sheet.paste(frame, (0, row * CHAR_FRAME))
    sheet.save(os.path.join(CHARS, "kitchen_youkai.png"))
    print("  characters/kitchen_youkai.png %dx%d" % sheet.size)


if __name__ == "__main__":
    print("S6-T8·T9 카페 아트 패스 후처리")
    build_menu_icons()
    build_fixtures()
    build_badges()
    build_guests()
    build_kitchen_youkai()
