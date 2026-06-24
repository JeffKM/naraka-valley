#!/usr/bin/env python3
"""Phase 2.8 T1 — 피안절(봄) 베이스 톤 리컬러 (ADR-0001 허용 색보정 글루 = Aseprite 보정).

베이스 팔레트를 *피안절 봄 톤*으로 확정·잠근다(grill 2026-06-24 잠금 ③④). 기존 베이스는
저승 무채도 묘지 이끼(#306f33, desaturate_grass.py 산출)였다. 피안절은 그보다 *살짝 따뜻한*
봄 이끼 — 지상 봄처럼 화사하지 않게, 저승 무드는 유지하되 새싹의 생기를 한 톤 얹는다.
신규 구역(T3~)이 전부 이 톤에 맞춰지도록 T1에서 선행 확정한다.

두 패스(모두 gen 0, 순수 후처리 — 리컬러 우선):
  ① 터레인 풀(grass_path·soil_grass): 원본 *_raw.png(형광 그린)에서 출발해 녹색 픽셀만
     hue를 노랑 쪽으로 살짝 회전(웜)·채도 절제·명도 살짝 상향 → 따뜻한 봄 이끼.
     desaturate_grass.py(#306f33)를 *대체*하는 새 베이스 톤 단계. 흙(갈색)은 hue로 보존.
  ② 코어 외관·실내·가구: 이미 brighten.py가 적용된 *현재* PNG가 베이스이므로 _raw(=pre-brighten)
     가 아니라 tools/.t1_pian_src/(gdignore) 백업에서 출발해 멱등 처리. 정체성을 해치지 않는
     아주 옅은 웜 캐스트(R↑·B↓)만 얹어 풀 톤과 한 무대로 읽히게 한다.

좌표·로직·세이브 불변(아트만). 터레인 PNG 교체 후 pixellab_tileset_converter.gd 재실행으로
combined_terrain.tres 임베드 아틀라스를 재생성해야 드롭인이 완료된다(이 스크립트 밖, 호출부 참조).

사용: python3 tools/retone_pianjeol.py
"""
import colorsys
import os
import shutil
from PIL import Image, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
TILES = os.path.join(HERE, "..", "assets", "tiles")
PROPS = os.path.join(HERE, "..", "assets", "props")
BUILDINGS = os.path.join(HERE, "..", "assets", "buildings")
PIAN_SRC = os.path.join(HERE, ".t1_pian_src")          # 멱등 백업(현재 brighten 상태 보존)

# ── 패스 ① 피안절 봄 톤 풀 변환 계수 (마스터 팔레트 잠금) ──────────────────────
# 원본 형광 그린(hue ~120°)을 봄 이끼로: 노랑 쪽으로 살짝 회전(웜) + 절제 채도 + 봄 명도.
# 결과 앵커 ≈ #417431(따뜻한 봄 이끼) — 묘지 이끼 #306f33보다 따뜻하고 한 톤 밝다.
HUE_LO, HUE_HI = 80, 175      # 녹색~청록 계열만(흙 갈색은 보존)
HUE_WARM_DEG = 15.0           # 노랑 쪽으로 회전(120°→~105°) = "살짝 따뜻"
HUE_FLOOR = 78.0              # 회전 하한(너무 노래지지 않게 — 화사 방지)
SAT_MUL = 0.58                # 채도 절제(저승 무드 — 지상 봄 채도 아님)
VAL_MUL = 0.92                # 명도 살짝 상향(묘지 이끼 ×0.82보다 밝게 = 봄 생기)
GRASS_TARGETS = ["grass_path_image.png", "soil_grass_image.png"]

# ── 패스 ② 코어 외관·실내·가구 웜 캐스트 (정체성 보존 = 아주 옅게) ──────────────
WARM_R, WARM_G, WARM_B = 1.035, 1.005, 0.955   # 살짝 웜(R↑·B↓) — "살짝"이라 미세
CORE_TILES = ["house_floor.png", "cafe_floor.png", "wall.png",
              "house_wall.png", "cafe_wall.png"]
CORE_FACADES = ["house_ext.png", "cafe_ext.png", "miho_house_ext.png",
                "mel_house_ext.png", "bana_house_ext.png"]
CORE_PROPS = ["cafe_cabinet.png", "cafe_clock.png", "cafe_counter.png",
              "cafe_frame.png", "cafe_shelf.png", "cafe_stool.png",
              "cafe_table.png", "house_bed.png", "house_bookshelf.png",
              "house_fireplace.png", "house_rug.png", "house_table.png",
              "soul_lantern.png", "spirit_pot.png"]


def retone_grass(path: str) -> int:
    """녹색 픽셀만 피안절 봄 톤으로(원본 *_raw.png에서 멱등 출발)."""
    raw = path.replace(".png", "_raw.png")
    if not os.path.exists(raw):
        Image.open(path).save(raw)            # 최초 1회 원본 백업
    im = Image.open(raw).convert("RGBA")      # 항상 원본에서(멱등)
    px = im.load()
    touched = 0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            hd = h * 360
            if HUE_LO <= hd <= HUE_HI and s > 0.15:
                hd = max(HUE_FLOOR, hd - HUE_WARM_DEG)         # 웜 회전
                nr, ng, nb = colorsys.hsv_to_rgb(hd / 360, s * SAT_MUL, v * VAL_MUL)
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
                touched += 1
    im.save(path)
    return touched


def warm_cast(name: str, src_dir: str) -> None:
    """코어 외관/실내/가구에 옅은 웜 캐스트(현재 상태 백업에서 멱등 출발, 알파 보존)."""
    path = os.path.join(src_dir, name)
    backup = os.path.join(PIAN_SRC, name)
    if not os.path.exists(backup):
        shutil.copy2(path, backup)            # 최초 1회 현재(brighten 적용) 상태 백업
    im = Image.open(backup).convert("RGBA")   # 항상 백업에서(멱등 — brighten 보존)
    alpha = im.getchannel("A")
    r, g, b = im.convert("RGB").split()
    r = r.point(lambda v: min(255, int(v * WARM_R)))
    g = g.point(lambda v: min(255, int(v * WARM_G)))
    b = b.point(lambda v: min(255, int(v * WARM_B)))
    out = Image.merge("RGB", (r, g, b)).convert("RGBA")
    out.putalpha(alpha)
    out.save(path)


def main() -> None:
    print("① 피안절 봄 톤 풀 리컬러 (터레인):")
    for n in GRASS_TARGETS:
        cnt = retone_grass(os.path.join(TILES, n))
        print(f"   {n}: {cnt} green px → 봄 이끼")
    print("② 코어 외관·실내·가구 웜 캐스트:")
    for n in CORE_TILES:
        warm_cast(n, TILES)
    for n in CORE_FACADES:
        warm_cast(n, BUILDINGS)
    for n in CORE_PROPS:
        warm_cast(n, PROPS)
    print(f"   타일 {len(CORE_TILES)} + 외관 {len(CORE_FACADES)} + 가구 {len(CORE_PROPS)} 리컬러")
    print("done — 다음: pixellab_tileset_converter.gd 재실행(터레인 .tres 드롭인)")


if __name__ == "__main__":
    main()
