#!/usr/bin/env python3
# 글루(ADR-0001) — 제미나이(Gemini)로 생성한 고해상 건물 facade를 3건물 공통 파이프라인으로
# 굳혀 2px 청크 캐논([asset-ruleset §0.1])과 선명도를 *일관되게* 강제한다. 본가·창고·축사를
# 같은 스크립트·같은 그레인(1타일=16논리px)·같은 양자화로 통과시켜 청키·선명도를 100% 동일화.
#
# ★선명도 핵심([ADR-0046] 재생성, gemini-building-prompt.md §2 — owner "흐림" 피드백 2026-07-02):
#   렌더(_blit_facade_anchored)는 PNG를 네이티브 1:1로 그려 → 청키·선명도는 소스 PNG가 결정.
#   제미나이는 고해상 raster라 다운스케일하면 LANCZOS가 색을 연속 램프로 섞어(수천 색) 2px 블록
#   안이 그라데이션 = 흐림. → **median-cut 팔레트 양자화(무-디더)로 램프를 플랫 색에 스냅**해
#   크리스프한 도트(asset-ruleset §16 미디엄 양자화)를 강제한다. 이게 없으면 청키하지만 흐리다.
#
# 파이프라인: content bbox 오토크롭 → half-res 다운스케일(LANCZOS, 1타일=16px) → 하드 알파 임계
#            → **팔레트 양자화(median-cut·무디더·기본 48색)** → ×2 NEAREST(2px 블록) → 최종 bbox 트림.
# 사용: python3 tools/gemini_facade_to_chunky.py <src.png> <dst.png> <target_render_width_px> [ncolors=48]
#   target_render_width_px = footprint 타일폭 × 32 (예: 본가 10칸=320 / 창고 6칸=192).
import sys
from PIL import Image


def main(src, dst, target_w, ncolors=48):
    im = Image.open(src).convert("RGBA")
    # ① content bbox 오토크롭 — 투명 여백 제거(스케일을 캔버스가 아닌 건물 기준으로).
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    cw, ch = im.size
    # ② half-res 다운스케일(1타일=16논리px). target_w의 절반 폭, 아스펙트 보존.
    half_w = max(1, target_w // 2)
    half_h = max(1, round(ch * half_w / cw))
    small = im.resize((half_w, half_h), Image.LANCZOS)
    # ③ 하드 알파 임계 — 반투명 AA 엣지 제거(헤일로 방지, §8.1).
    r, g, b, a = small.split()
    a = a.point(lambda v: 255 if v >= 128 else 0)
    # 투명 픽셀 RGB는 팔레트 슬롯을 낭비/오염하므로 검정으로 눌러 한 슬롯에 몰아넣는다(어차피 비침).
    rgb = Image.composite(Image.merge("RGB", (r, g, b)), Image.new("RGB", small.size, (0, 0, 0)), a)
    # ④ 팔레트 양자화(median-cut·무디더) — 연속 램프 → 플랫 색 스냅 = 크리스프(선명도 핵심).
    q = rgb.quantize(colors=ncolors, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    out = q.convert("RGBA")
    out.putalpha(a)
    # ⑤ ×2 NEAREST — 모든 논리픽셀 → 2×2 블록(캐논 §0.1, 100% 청키). ⑥ 최종 트림.
    out = out.resize((half_w * 2, half_h * 2), Image.NEAREST)
    b2 = out.getbbox()
    if b2:
        out = out.crop(b2)
    out.save(dst)
    n = len({c for c in out.getdata() if c[3] > 0})
    print(f"  {src} -> {dst}  ({out.size[0]}x{out.size[1]}, {n} colors, target_w={target_w}, ncolors={ncolors})")


if __name__ == "__main__":
    nc = int(sys.argv[4]) if len(sys.argv) > 4 else 48
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]), nc)
