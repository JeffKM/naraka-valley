#!/usr/bin/env python3
"""★[S7-T9 / ADR-0065 결정 11] 절기 팔레트 파생 — 지형 필드 3절기 오프라인 베이크.

`retone_pianjeol.py`(피안절 봄 톤 확정)의 **직계 후속**이다. 그때는 베이스 팔레트 *한 벌*을
피안절로 잠갔고, 여기서는 그 잠긴 피안 필드를 **원본으로 삼아** 나머지 세 절기의 변주를 굽는다.
그래서 규칙이 하나 더 붙는다 — **피안은 파일을 한 바이트도 만들지 않는다**(런타임이 경로만
분기하므로 피안 = 기존 파일 그대로 = 기존 골든 덤프 불변).

  피안절(0) = 원본 그대로            (산출 0장 — 경로 분기만)
  유화절(1) = 녹음 짙고 따뜻한 한여름 (짙은 녹색 + 웜 캐스트)
  망연절(2) = 황금·적갈 낙엽의 절기   (풀을 황금으로 크게 돌리고 흙을 적갈로)
  성야절(3) = 잿빛 한랭              (채도를 걷어내고 쿨 캐스트 — 눈기(雪) 없이 톤만)

## 두 겹 변환 (색수 증가 0 = ADR-0057 저색 crisp 보존)

  ① HSV  — 색상(wrap-aware 최단호 lerp)·채도·명도
  ② RGB 캐스트 — 절기의 공기(웜/쿨)를 옅게 한 겹

둘 다 **픽셀값 → 픽셀값 순수 함수**라 같은 입력색은 반드시 같은 출력색이 된다 = 출력 색수는
입력 색수를 절대 넘지 않는다(충돌로 줄 수는 있다). 스크립트가 매번 in/out 색수를 찍어 이 불변식을
눈으로 확인시킨다 — ADR-0050 32-native·ADR-0057 저색 crisp 결을 리톤이 깨뜨리지 않는다는 증거다.

## 소스 선택 (런타임이 실제로 읽는 파일과 1:1)

`main._load_big_fields`가 읽는 파일만 굽는다. 지금 `_TERRAIN_SINGLE_SOURCE=true`라 잔디·흙·길은
`single_source/`가 실소스이고 밭흙만 `terrain16/` 직속이다. 물·모래·포석·판자는 **안 굽는다**
(ADR-0065 결정 11 "지형 필드 최소 세트 = grass/dirt 계열" — 물은 얼지 않고 마을 포석·백사장은
안식 마당 밖이다). 안 구운 필드는 런타임 폴백이 원본을 집으므로 절기와 무관하게 그대로 뜬다.

## 멱등

원본은 **읽기 전용**이고 산출은 `seasons/<슬러그>/` 병렬 디렉터리다. 몇 번을 돌려도 같은 입력에서
같은 출력이 나온다(retone_pianjeol이 `_raw` 백업으로 얻은 멱등을, 여기선 디렉터리 분리로 얻는다).

사용: python3 tools/retone_seasons.py      (game/ 에서)
"""
import collections
import colorsys
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TERRAIN = os.path.join(HERE, "..", "assets", "terrain16")
OUT_ROOT = os.path.join(TERRAIN, "seasons")

# ── 소스 → 계열(profile family) ──────────────────────────────────────────────
# 경로는 `terrain16/` 기준 상대. 계열이 레버 묶음을 고른다(파일마다 따로 튜닝하지 않는다 —
# 같은 계열이 서로 다른 절기감을 내면 한 화면에서 흙끼리 톤이 갈린다).
FIELDS = [
    ("single_source/grass_field.png", "grass"),   # 마당·들판 잔디(_bf_grass)
    ("single_source/dirt_field.png", "earth"),    # 마당 맨흙(_bf_earth) — 스타듀 농장 tan 지면
    ("single_source/path_field.png", "earth"),    # 다진 흙길(_bf_dirt)
    ("soil_field.png", "soil"),                   # 갈아엎은 밭흙(_bf_soil)
]

# ── 절기 레버 ────────────────────────────────────────────────────────────────
# hue_to/hue_w = 색상 목표(도)와 당기는 정도(0=그대로 1=목표). sat/val = HSV 배율.
# cast = ② RGB 캐스트(절기의 공기 — 웜은 R↑B↓, 쿨은 B↑R↓). 전부 "옅게" 가 원칙이다:
#   세게 걸면 저승 무드가 지상 계절 사진으로 넘어간다(피안절 잠금 때 owner가 그은 선).
#
# ★ 밭흙(soil)이 흙(earth)보다 늘 얕은 이유: 밭은 플레이어가 *방금 판 자리*라 "젖은 검은 흙"이
#   정체성이다. 절기로 크게 물들이면 갈아엎은 칸과 안 갈아엎은 칸의 구분이 흐려진다.
PROFILES = {
    "yuhwa": {   # 유화절(여름) — 녹음이 짙어지고 볕이 따갑다
        # ★1차 베이크가 피안과 거의 구분이 안 갔다(A/B 시트 육안) → 색상을 더 당기고 채도를
        #   올리되 명도를 내려 "짙은" 쪽으로. 여름은 밝아지는 게 아니라 **진해지는** 절기다.
        "grass": dict(hue_to=108.0, hue_w=0.58, sat=1.32, val=0.89, cast=(1.02, 1.01, 0.94)),
        "earth": dict(hue_to=32.0, hue_w=0.35, sat=1.12, val=1.02, cast=(1.04, 1.00, 0.93)),
        "soil": dict(hue_to=28.0, hue_w=0.20, sat=1.06, val=1.00, cast=(1.02, 1.00, 0.97)),
    },
    "mangyeon": {   # 망연절(가을) — 잎이 물들고 흙이 적갈로 내려앉는다
        # ★1차에서 흙이 점토빛 주황으로 튀어 채도를 도로 내렸다(가을 흙은 선명한 게 아니라
        #   **가라앉은** 적갈이다 — 저승 muted 팔레트의 하한을 지킨다).
        "grass": dict(hue_to=34.0, hue_w=0.82, sat=1.14, val=1.04, cast=(1.04, 1.00, 0.92)),
        "earth": dict(hue_to=22.0, hue_w=0.45, sat=1.00, val=0.94, cast=(1.03, 0.99, 0.93)),
        "soil": dict(hue_to=18.0, hue_w=0.30, sat=1.04, val=0.97, cast=(1.03, 0.99, 0.95)),
    },
    "seongya": {   # 성야절(겨울) — 잿빛 한랭. ★눈(雪)은 굽지 않는다: 눈은 날씨(잿눈)의 몫이고
                   #   여기는 "빛이 식은 땅" 톤만 낸다(ADR-0065 결정 11 — 톤만).
                   # ★ hue_w=0 인 이유: 갈색(35°)을 파랑(215°)으로 lerp하면 최단호가 초록을 지나
                   #   흙이 이끼색으로 착지한다. 한랭은 **채도를 걷고 쿨 캐스트를 얹어** 낸다.
        # ★1차 흙이 백사장처럼 밝아 "잿빛"이 아니라 "모래빛"으로 읽혔다 → 명도를 눌러 재로 내린다.
        "grass": dict(hue_to=0.0, hue_w=0.0, sat=0.22, val=0.96, cast=(0.94, 0.98, 1.10)),
        "earth": dict(hue_to=0.0, hue_w=0.0, sat=0.34, val=0.88, cast=(0.95, 0.98, 1.08)),
        "soil": dict(hue_to=0.0, hue_w=0.0, sat=0.60, val=0.92, cast=(0.97, 0.99, 1.05)),
    },
}


def hue_lerp(h_deg: float, target: float, w: float) -> float:
    """색환 최단호로 target 쪽으로 w만큼 당긴다(0°↔360° 경계 안전)."""
    if w <= 0.0:
        return h_deg
    d = ((target - h_deg + 180.0) % 360.0) - 180.0
    return (h_deg + d * w) % 360.0


def convert(rgb, lv) -> tuple:
    """한 색 → 한 색(순수 함수 — 색수 불변식의 근거). ① HSV → ② RGB 캐스트."""
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    h = hue_lerp(h * 360.0, lv["hue_to"], lv["hue_w"]) / 360.0
    s = min(1.0, max(0.0, s * lv["sat"]))
    v = min(1.0, max(0.0, v * lv["val"]))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    cr, cg, cb = lv["cast"]
    return (
        int(min(255.0, max(0.0, r * 255.0 * cr)) + 0.5),
        int(min(255.0, max(0.0, g * 255.0 * cg)) + 0.5),
        int(min(255.0, max(0.0, b * 255.0 * cb)) + 0.5),
    )


def bake(src_path: str, dst_path: str, lv) -> tuple:
    """필드 한 장을 절기 변주로 굽는다. 반환 = (입력 색수, 출력 색수)."""
    im = Image.open(src_path).convert("RGBA")
    px = im.load()
    lut = {}                       # 색 → 색 캐시(같은 색은 한 번만 계산 = 순수 함수의 실증)
    seen_in = set()
    seen_out = set()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            key = (r, g, b)
            seen_in.add(key)
            if key not in lut:
                lut[key] = convert(key, lv)
            nr, ng, nb = lut[key]
            seen_out.add((nr, ng, nb))
            px[x, y] = (nr, ng, nb, a)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    im.save(dst_path)
    return len(seen_in), len(seen_out)


def main() -> None:
    total = 0
    for slug in ["yuhwa", "mangyeon", "seongya"]:
        print("── %s ──" % slug)
        for rel, family in FIELDS:
            src = os.path.normpath(os.path.join(TERRAIN, rel))
            if not os.path.exists(src):
                print("   ! 소스 없음(건너뜀): %s" % rel)
                continue
            dst = os.path.join(OUT_ROOT, slug, os.path.basename(rel))
            n_in, n_out = bake(src, dst, PROFILES[slug][family])
            flag = "" if n_out <= n_in else "  ⚠︎색수 증가!"
            print("   %-16s [%-5s] 색 %d → %d%s"
                  % (os.path.basename(rel), family, n_in, n_out, flag))
            total += 1
    print("done — %d장. 다음: godot --headless --import (임포트 캐시 갱신)" % total)


if __name__ == "__main__":
    main()
