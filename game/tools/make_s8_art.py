#!/usr/bin/env python3
# ★[S8-T9 / ADR-0066 아트 스코프] 관계 심화 슬라이스 아트 패스 후처리 글루
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab 생성 raw → 게임 규격으로 굳힌다. 규칙은 make_s6_art.py(카페 아트 패스)와 **같다** —
#   [asset-ruleset §8.1] 하드 알파 · [§9] 저승 muted · [ADR-0050] 32-native · [§3] 발치 앵커
# 새 규칙을 세우지 않는다(패스마다 계수가 갈리면 인벤 한 줄·실내 한 방에서 톤이 튄다).
#
#   1) 혼례 부적 아이콘        32×32   assets/materials/wedding_charm.png
#   2) 2인용 침대 프롭         32×64   assets/props/house_bed_double.png
#
# ★ 멱등: raw에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: python3 tools/make_s8_art.py   (game/ 에서)
import colorsys
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MATERIALS = os.path.join(ROOT, "assets", "materials")
PROPS = os.path.join(ROOT, "assets", "props")

TILE = 32
ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)

# [§9] 저승 muted — 계수는 make_s6_art.py와 **동일**이다.
ICON_SAT, ICON_VAL = 0.90, 0.97   # 아이콘(인벤 격자에서 나락 열쇠·환약과 나란히 뜬다)
PROP_SAT, PROP_VAL = 0.85, 0.95   # 월드 프롭(실내 가구 톤 — 1인 침대·장롱 옆에 선다)


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


# ── 1) 혼례 부적 아이콘 ──────────────────────────────────────────────────────
# CAT_MATERIAL이라 나락 열쇠와 같은 칸을 탄다 → 아이콘 계수(0.90/0.97)·center 앉힘도 같다.
# ★ 크기를 손대지 않는다: 32-native 생성물을 그대로 쓰고 콘텐츠만 32² 안에서 가운데로 다시
#   앉힌다([ADR-0050] "AI 축소본은 뭉개진다" · 슬롯이 아이콘을 통째로 늘려 그리므로 여백이
#   한쪽으로 몰리면 옆 슬롯과 눈금이 어긋나 보인다).
def build_wedding_charm() -> None:
    raw = os.path.join(MATERIALS, "raw", "wedding_charm_raw.png")
    if not os.path.exists(raw):
        print("  ! raw 없음: %s" % raw)
        return
    img = Image.open(raw).convert("RGBA")
    hard_alpha(img)
    apply_px(img, lambda c: mute(c, ICON_SAT, ICON_VAL))
    out = _fit(img, TILE, TILE, "center")
    out.save(os.path.join(MATERIALS, "wedding_charm.png"))
    print("  materials/wedding_charm.png %dx%d" % out.size)


# ── 2) 2인용 침대 프롭 ──────────────────────────────────────────────────────
# 세로 2칸(32×64) = 1인 침대(house_bed.png)와 **같은 규격**이다. 안방(확장부) 북벽에
# 발치정렬로 앉아 위 칸으로 솟는다(WALL_PROP_LIFT로 크림 트림에 밀착). 가구 계수(0.85/0.95)는
# 1인 침대·장롱과 같은 값 — 같은 방에 나란히 서므로 다른 값이면 이 한 점만 톤이 튄다.
def build_bed_double() -> None:
    raw = os.path.join(PROPS, "raw", "house_bed_double_raw.png")
    if not os.path.exists(raw):
        print("  ! raw 없음: %s" % raw)
        return
    img = Image.open(raw).convert("RGBA")
    hard_alpha(img)
    apply_px(img, lambda c: mute(c, PROP_SAT, PROP_VAL))
    out = _fit(img, TILE, TILE * 2, "bottom")
    out.save(os.path.join(PROPS, "house_bed_double.png"))
    print("  props/house_bed_double.png %dx%d" % out.size)


if __name__ == "__main__":
    print("S8-T9 관계 심화 아트 패스 후처리")
    build_wedding_charm()
    build_bed_double()
