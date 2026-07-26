#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ─────────────────────────────────────────────────────────────────────────────
# 다진 흙길(PATH) 전용 베이스 필드 생성기 — S1R 폴리시 / ADR-0057 "길 타일 분리"
#
# 왜 필요한가: 단일출처(_TERRAIN_SINGLE_SOURCE) 전환 뒤 main.gd는 마당 맨흙(_bf_earth)과
#   길(_bf_dirt)에 **같은 dirt_field.png**를 물려 썼다(`_bf_earth = _bf_dirt.duplicate()`).
#   그래서 안식 마당의 십자 길이 tan-on-tan으로 완전히 소실됐다(ADR-0057 지적 그대로).
#   스타듀도 마당 흙과 다진 길은 별개 타일이다.
#
# 왜 오프라인인가(ADR-0058 물가 정책과 같은 결): 지형 톤은 런타임 절차 후처리로 만들지 않는다.
#   이 유틸을 **한 번 실행**해 정적 필드 PNG를 굽고 커밋한다 — 런타임은 그 PNG만 읽는다.
#
# 파이프라인: single_source/dirt_field.png(팔레트-락 단일출처) → 픽셀 순수 HSV 톤맵 → path_field.png.
#   *같은 출처*를 톤만 눌러 파생하므로 팔레트 계열·그레인·씸리스(타일링 이음매)가 그대로 보존된다.
#   단조 매핑이라 색 수는 늘지 않는다(ADR-0057 저색 crisp 원칙).
#
# 톤 방향(asset-ruleset §17 "채도 아닌 **명도**로 구분", §9 warm 베이스 유지):
#   · 명도 ↓ (다져져 그늘진 흙) — 마당 맨흙과 mean L* 약 13 차 → 셀 경계에서 확실히 읽힘
#   · 채도 ↓ (모래빛 노랑 → 가라앉은 회갈색)
#   · 색상은 warm 갈색 계열 유지(살짝만 붉은 쪽 — 팔레트 이탈 방지)
#   외곽선 없음(지형=무외곽선 락). 결정적(난수 없음·픽셀 순수 함수).
#
# 사용: python3 game/tools/make_path_field.py
# 산출: game/assets/terrain16/single_source/path_field.png (+ stdout 톤 리포트)
# ─────────────────────────────────────────────────────────────────────────────
import colorsys
import os

from PIL import Image

VAL_MUL = 0.78    # 명도 배율(다짐 그늘)
SAT_MUL = 0.80    # 채도 배율(회갈색화)
HUE_LERP = 0.30   # 색상을 HUE_TARGET 쪽으로 당기는 가중치
HUE_TARGET = 0.075  # 살짝 붉은 갈색(원본 tan hue ≈ 0.10) — warm 계열 유지


def tone(rgb):
    r, g, b = [v / 255.0 for v in rgb]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    h = h + (HUE_TARGET - h) * HUE_LERP
    s = min(1.0, s * SAT_MUL)
    v = min(1.0, v * VAL_MUL)
    r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
    return tuple(int(round(c * 255.0)) for c in (r2, g2, b2))


def lstar(rgb):
    """sRGB → CIE L* (명도 차 정량 리포트용)."""
    def lin(u):
        u /= 255.0
        return u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4
    y = 0.2126 * lin(rgb[0]) + 0.7152 * lin(rgb[1]) + 0.0722 * lin(rgb[2])
    return 116.0 * (y ** (1.0 / 3.0) if y > 0.008856 else 7.787 * y + 16.0 / 116.0) - 16.0


def mean_lstar(counts):
    total = sum(n for n, _ in counts)
    return sum(n * lstar(c) for n, c in counts) / total


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ss = os.path.normpath(os.path.join(here, "..", "assets", "terrain16", "single_source"))
    src_path = os.path.join(ss, "dirt_field.png")
    out_path = os.path.join(ss, "path_field.png")

    src = Image.open(src_path).convert("RGB")
    lut = {}
    out = Image.new("RGB", src.size)
    sp = src.load()
    op = out.load()
    for y in range(src.size[1]):
        for x in range(src.size[0]):
            c = sp[x, y]
            if c not in lut:
                lut[c] = tone(c)
            op[x, y] = lut[c]
    out.save(out_path)

    sc = src.getcolors(1 << 20)
    oc = out.getcolors(1 << 20)
    l_src = mean_lstar(sc)
    l_out = mean_lstar(oc)
    print("✅ 저장:", out_path, "(%dx%d)" % out.size)
    print("  색 수: 마당 흙 %d → 길 %d (저색 유지)" % (len(sc), len(oc)))
    print("  mean L*: 마당 흙 %.1f → 길 %.1f (차 %.1f)" % (l_src, l_out, l_src - l_out))
    print("  대표색: %s L*=%.1f → %s L*=%.1f"
          % (max(sc)[1], lstar(max(sc)[1]), tone(max(sc)[1]), lstar(tone(max(sc)[1]))))


if __name__ == "__main__":
    main()
