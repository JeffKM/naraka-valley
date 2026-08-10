#!/usr/bin/env python3
# ★[S7-T9 / ADR-0065 결정 12] 절기·날씨·축제 슬라이스 아트 패스 후처리 글루
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab 생성 raw → 게임 규격으로 굳힌다. 규칙은 `make_s6_art.py`(카페 슬라이스)와 **같다** —
#   [asset-ruleset §8.1] 하드 알파 · [§9] 저승 muted · [ADR-0050] 32-native · [§3] 발치 앵커
# 새 규칙을 세우지 않는다(패스마다 규칙이 갈리면 한 화면에서 톤이 튄다).
#
#   1) 점괘 거울 프롭        32×64   assets/props/fortune_mirror.png     (집 북벽 걸이 — 결정 6)
#   2) 더비 부스 프롭        32×48   assets/props/derby_booth.png        (피안 12일 — 결정 9)
#   3) 야시장 매대 프롭      32×48   assets/props/night_market.png       (성야 15일 — 결정 9)
#   4) HUD 날씨 아이콘 4종   16×16   assets/ui/weather_icon_<종>.png     (결정 10)
#
# ★ 청키화(enforce_chunk)는 **걸지 않는다**: 현행 shipping 프롭(larder 0.068·ship_bin 0.136)과
#   같은 1px 결이라 여기만 2px로 굳히면 실내 한 벽에서 이 하나만 굵어진다(§0.1 캐논보다
#   "한 화면 한 그레인"이 우선 — S6 패스가 이미 선 그은 자리).
# ★ 멱등: raw에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
#
# 사용: python3 tools/make_s7_art.py   (game/ 에서)
import colorsys
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROPS = os.path.join(ROOT, "assets", "props")
UI = os.path.join(ROOT, "assets", "ui")

ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)
PROP_SAT, PROP_VAL = 0.85, 0.95   # [§9] 프롭 계수 — make_s6_art.build_fixtures와 동일 값
# HUD 아이콘은 어두운 한지 바 위 16px 표식이라 얕게 누른다(깊게 누르면 바에 묻혀 안 읽힌다 —
# make_s6_art.build_badges가 배지에 쓴 것과 같은 계수).
ICON_SAT, ICON_VAL = 0.94, 1.0


def hard_alpha(img: Image.Image) -> Image.Image:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= ALPHA_CUT else 0)
    return img


def mute(img: Image.Image, sat_mul: float, val_mul: float) -> Image.Image:
    """[§9] 저승 muted — 채도·명도만 눌러 형태·정체색은 보존."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            s = min(1.0, max(0.0, s * sat_mul))
            v = min(1.0, max(0.0, v * val_mul))
            nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (int(nr * 255 + 0.5), int(ng * 255 + 0.5), int(nb * 255 + 0.5), a)
    return img


def fit(img: Image.Image, w: int, h: int, anchor: str) -> Image.Image:
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


def build(raw_dir: str, out_dir: str, jobs, sat: float, val: float, anchor: str) -> None:
    for raw_name, out_name, w, h in jobs:
        raw_path = os.path.join(raw_dir, "raw", raw_name + ".png")
        if not os.path.exists(raw_path):
            print("  ! raw 없음: %s" % raw_path)
            continue
        img = Image.open(raw_path).convert("RGBA")
        hard_alpha(img)
        mute(img, sat, val)
        out = fit(img, w, h, anchor)
        out.save(os.path.join(out_dir, out_name + ".png"))
        print("  %s.png %dx%d" % ((out_name,) + out.size))


# ── 1~3) 월드 프롭 3종 ────────────────────────────────────────────────────────
# 점괘 거울은 **세로 2칸(32×64)** — 북벽에 걸린 체경이라 한 칸에 앉히면 손거울로 읽힌다.
# MIRROR_TILE(17,68) 바닥에 발치정렬(+WALL_PROP_LIFT)로 걸린다.
# 부스·매대는 32×48 — 한 칸 폭에 한 칸 반 높이라, 차양이 위 칸으로 솟아 "천막"이 읽힌다
# (익명 손님 상 32×48과 같은 규격·같은 이유). 행사일에만 그려지므로 충돌은 애초에 없다.
PROP_JOBS = [
    ("fortune_mirror_raw", "fortune_mirror", 32, 64),
    ("derby_booth_raw", "derby_booth", 32, 48),
    ("night_market_raw", "night_market", 32, 48),
]

# ── 4) HUD 날씨 아이콘 4종 ────────────────────────────────────────────────────
# 파일명 = 배선 키(main/clock_hud가 이 이름으로 preload). 16×16 = **절기 아이콘과 같은 규격**
# 이라야 한 줄에 나란히 섰을 때 눈금이 맞는다(clock_hud.ICON_PX=16).
# ★ 이 4장이 T8의 절차 청크 글리프(`ClockHud.weather_chunks`)를 HUD에서 대체한다 — 그 표는
#   오프라인 합성 덤프(tools/weather_dump.gd)가 읽는 데이터라 **지우지 않고 남긴다**.
ICON_JOBS = [
    ("weather_icon_calm_raw", "weather_icon_calm", 16, 16),
    ("weather_icon_rain_raw", "weather_icon_rain", 16, 16),
    ("weather_icon_snow_raw", "weather_icon_snow", 16, 16),
    ("weather_icon_soulwind_raw", "weather_icon_soulwind", 16, 16),
]


def main() -> None:
    print("① 월드 프롭 3종(거울·부스·매대):")
    build(PROPS, PROPS, PROP_JOBS, PROP_SAT, PROP_VAL, "bottom")
    print("② HUD 날씨 아이콘 4종:")
    build(UI, UI, ICON_JOBS, ICON_SAT, ICON_VAL, "center")
    print("done — 다음: godot --headless --import (임포트 캐시 갱신)")


if __name__ == "__main__":
    main()
