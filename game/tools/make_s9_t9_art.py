#!/usr/bin/env python3
# ★[S9-T9 / ADR-0067 아트 스코프] T1 2인 슬라이스 아트 패스 후처리 글루
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab 생성 raw → 게임 규격으로 굳힌다. 규칙은 make_s8_art.py(관계 심화 패스)와 **같다** —
#   [asset-ruleset §8.1] 하드 알파 · [§9] 저승 muted · [ADR-0050] 32-native · [§3] 발치 앵커
# 새 규칙을 세우지 않는다(패스마다 계수가 갈리면 인벤 한 줄·실내 한 방에서 톤이 튄다).
#
#   1) 우편함 프롭        32×32     assets/props/mailbox.png
#   2) 책 아이콘          32×32     assets/books/book_icon.png
#   3) 노트 아이콘        32×32     assets/books/note_icon.png
#   4) 혼백관 서가 좌대   32×12     assets/props/museum_shelf.png
#   5) 편지지 대화창      1400×405  assets/ui/letter_window.png   ← ★생성 0(파생물)
#
# ★ 5)만 PixelLab 생성물이 아니라 **기존 대화창(dialog_window.png)에서 파생**한다. 편지 읽기 UI는
#   신규 위젯이 아니라 *같은 창의 다른 종이*라는 것이 T3의 설계고(읽기 UI = 대화창 재사용),
#   그 "결 정합"을 보장하는 가장 확실한 방법은 같은 원본에서 굽는 것이다 — 프레임·초상화 칸·
#   이름판 비율이 픽셀 단위로 동일해야 main의 DLG_F_* 상수가 두 스킨에 그대로 맞는다.
#   (새로 생성하면 그 비율이 반드시 어긋나고, 그 순간 이름판·초상화가 프레임 밖으로 샌다.)
#
# ★ 멱등: raw에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: python3 tools/make_s9_t9_art.py   (game/ 에서)
import colorsys
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROPS = os.path.join(ROOT, "assets", "props")
BOOKS = os.path.join(ROOT, "assets", "books")
UI = os.path.join(ROOT, "assets", "ui")

TILE = 32
ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)

# [§9] 저승 muted — 계수는 make_s8_art.py와 **동일**이다.
ICON_SAT, ICON_VAL = 0.90, 0.97   # 아이콘(인벤 격자에서 광물·메뉴·부적과 나란히 뜬다)
PROP_SAT, PROP_VAL = 0.85, 0.95   # 월드 프롭(우편함은 집 마당 기물 층 — 우물·화분 옆에 선다)
# 혼백관 서가만 한 단 더 죽인다: 생성물이 붉은 칠 목재로 나왔는데 그 방의 기존 좌대는
# draw_rect 어두운 갈색(0.26,0.24,0.22)이다. 같은 방 같은 줄에 서므로 붉음을 눌러 합류시킨다.
SHELF_SAT, SHELF_VAL = 0.62, 0.90


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
    """콘텐츠를 w×h 캔버스에 다시 앉힌다. anchor='center'(아이콘) / 'bottom'(월드 프롭) / 'top'."""
    box = img.getbbox()
    if box is None:
        return img
    content = img.crop(box)
    if content.width > w or content.height > h:
        content = content.resize((min(content.width, w), min(content.height, h)), Image.NEAREST)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = (w - content.width) // 2
    if anchor == "center":
        y = (h - content.height) // 2
    elif anchor == "top":
        y = 0
    else:
        y = h - content.height
    out.paste(content, (x, max(0, y)), content)
    return out


def _bake(raw_path: str, out_path: str, w: int, h: int, anchor: str,
          sat: float, val: float, crop_bottom: int = 0) -> None:
    """raw → 하드 알파 → muted → (아래 crop_bottom줄 버림) → w×h 앵커 재정렬 → 저장.

    crop_bottom = 생성물이 구워 온 **접지 그림자**를 걷어내는 줄 수다([§1] 그림자는 오버레이라
    아트에 굽지 않는다). 콘텐츠 bbox 기준으로 자르므로 여백 위치에 안 흔들린다.
    """
    if not os.path.exists(raw_path):
        print("  ! raw 없음: %s" % raw_path)
        return
    img = Image.open(raw_path).convert("RGBA")
    hard_alpha(img)
    apply_px(img, lambda c: mute(c, sat, val))
    if crop_bottom > 0:
        box = img.getbbox()
        if box is not None and box[3] - box[1] > crop_bottom:
            img = img.crop((box[0], box[1], box[2], box[3] - crop_bottom))
    out = _fit(img, w, h, anchor)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out.save(out_path)
    print("  %s %dx%d" % (os.path.relpath(out_path, ROOT), out.size[0], out.size[1]))


# ── 1) 우편함 프롭 ──────────────────────────────────────────────────────────
# HOME 야외 MAILBOX_TILE(46,10) 한 칸. `_prop_tex("mailbox")`가 파일만 있으면 자동으로 집는다
# (main.gd 무수정 — `_draw_mailbox`가 이미 텍스처 우선 분기다).
# ★★ **미독 깃발을 굽지 않는다.** 붉은 깃발은 `_draw_mailbox`가 상태에 따라 절차로 덧그린다 —
#    아트에 구우면 읽은 뒤에도 깃발이 남아 배지가 거짓말을 한다(상태를 아트에 굽지 않는 규율).
# ★ 세로 32 고정: 발치 앵커(`oy + TILE - h`)라 32를 넘기면 위로 솟고, 깃발이 서는 자리
#    (ox+23, oy+3)를 함 몸통이 덮어 깃발이 안 보인다.
def build_mailbox() -> None:
    _bake(os.path.join(PROPS, "raw", "mailbox_raw.png"),
          os.path.join(PROPS, "mailbox.png"), TILE, TILE, "bottom", PROP_SAT, PROP_VAL)


# ── 2·3) 책·노트 아이콘 ─────────────────────────────────────────────────────
# CAT_BOOK 23종(책 8 + 노트 15)이 **이 두 장을 공유한다**(권별 아트 0). 근거: 인벤 슬롯에서
# 책은 "무엇인지"가 아니라 "책인지"만 읽히면 되고, 어느 권인지는 툴팁·제목이 이미 말한다.
# 23장을 따로 구우면 32² 격자에서 서로 구분도 안 되면서 교체 비용만 23배가 된다.
# ★ 두 장을 **한눈에 가르는 것이 유일한 요구**다: 책 = 그을린 남색 + 금박(두껍고 각짐) /
#   노트 = 바랜 종이 + 접힌 자국(얇고 찌그러짐). 폴백 색박스가 쓰던 색 언어를 그대로 잇는다
#   (item_catalog.tool_color_of — 책 #47..3d5c · 노트 #c7b894).
def build_book_icons() -> None:
    _bake(os.path.join(BOOKS, "raw", "book_icon_raw.png"),
          os.path.join(BOOKS, "book_icon.png"), TILE, TILE, "center", ICON_SAT, ICON_VAL)
    _bake(os.path.join(BOOKS, "raw", "note_icon_raw.png"),
          os.path.join(BOOKS, "note_icon.png"), TILE, TILE, "center", ICON_SAT, ICON_VAL)


# ── 4) 혼백관 서가 좌대 ─────────────────────────────────────────────────────
# 8좌가 40px 간격으로 늘어선 서가 줄의 좌대 한 칸(`_draw_museum_room`). 폭 32는 간격 40 안에
# 8px 여유를 남긴다 — 40을 넘기면 옆 좌대와 겹치고 방(x8..19) 우측 벽을 뚫는다.
# ★ 높이 12: 원래 draw_rect가 Rect2(bp, (20,10))라 좌대 윗면이 bp.y다. 그 위에 꽂힌 책등
#   (bp+(6,-14), 8×14)이 **서는 바닥**이 그 선이므로, 아트도 bp.y에서 아래로만 자라야 한다
#   (= top 앵커). 위로 자라면 책등을 가린다.
# ★ crop_bottom=3: 생성물이 좌대 밑에 접지 그림자를 구워 왔다. 이 방의 좌대는 벽 서가라
#   바닥 그림자가 붙을 자리가 아니고(§1 그림자 = 오버레이), 남기면 8좌가 전부 떠 보인다.
def build_museum_shelf() -> None:
    _bake(os.path.join(PROPS, "raw", "museum_shelf_raw.png"),
          os.path.join(PROPS, "museum_shelf.png"), TILE, 12, "top", SHELF_SAT, SHELF_VAL,
          crop_bottom=3)


# ── 5) 편지지 대화창(생성 0 — dialog_window.png 파생) ───────────────────────
# 편지·책 읽기에만 서는 **같은 창의 다른 종이**다. 두 가지만 바꾼다:
#   ㉠ 종이를 한 단 **밝고 덜 붉게**(그을린 한지 → 갓 접힌 편지지). 채도만 눌러 프레임 장식·
#      먹 나비의 형태는 그대로 남긴다 — 창이 바뀐 게 아니라 종이가 바뀐 것으로 읽혀야 한다.
#   ㉡ **가로 접은 자국 두 줄**(3등분 — 편지를 접는 방식). 어두운 1px 밑에 밝은 1px을 붙여
#      "눌린 골"로 읽히게 한다. 알파가 있는 픽셀에만 그어 프레임 밖으로 새지 않는다.
# ★★ 크기·비율을 **절대 바꾸지 않는다**(1400×405 그대로). main의 DLG_F_TEXT/PORT/NAME은 창
#    크기 대비 **비율 상수**라, 두 스킨의 크기가 다르면 한쪽에서 초상화·이름판이 어긋난다.
FOLD_DARK = 0.86     # 접힌 골(어둡게)
FOLD_LIGHT = 1.07    # 골 바로 위 능선(밝게)
PAPER_SAT, PAPER_VAL = 0.74, 1.06   # 그을린 한지 → 편지지(덜 붉고 한 단 밝게)


def build_letter_window() -> None:
    src = os.path.join(UI, "dialog_window.png")
    if not os.path.exists(src):
        print("  ! 원본 없음: %s" % src)
        return
    img = Image.open(src).convert("RGBA")
    apply_px(img, lambda c: mute(c, PAPER_SAT, PAPER_VAL))
    px = img.load()
    w, h = img.size
    for k in (1, 2):                       # 3등분 = 접은 자국 두 줄
        y = h * k // 3
        for x in range(w):
            for yy, mul in ((y, FOLD_DARK), (y - 1, FOLD_LIGHT)):
                if yy < 0 or yy >= h:
                    continue
                r, g, b, a = px[x, yy]
                if a < ALPHA_CUT:
                    continue               # 프레임 밖(투명)에는 안 긋는다
                px[x, yy] = (min(255, int(r * mul)), min(255, int(g * mul)),
                             min(255, int(b * mul)), a)
    img.save(os.path.join(UI, "letter_window.png"))
    print("  assets/ui/letter_window.png %dx%d" % img.size)


if __name__ == "__main__":
    print("S9-T9 T1 2인 슬라이스 아트 패스 후처리")
    build_mailbox()
    build_book_icons()
    build_museum_shelf()
    build_letter_window()
