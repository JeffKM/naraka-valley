#!/usr/bin/env python3
# ★[단계3-④] 남향 절벽 벽 좌우 끝 곡선 코너 절차 파생 (cliff-tileset-spec §10.2 단계3).
#
# 옛 90° 각진 벽 끝(SW/SE)을 스타듀식 곡선 대각 전이로. cliff_s_face(벽면)·cliff_s_base(밑동)의
# 바깥 세로 엣지를 1/4 코사인 곡선으로 깎아 cliff_s_lip 상단 풀로 전이한다. Face(위)+Base(아래)
# 두 타일의 곡선이 세로로 매끄럽게 이어져(전역 세로좌표 Yg=0..63) 벽 밑끝이 둥글게 잔디로 물러난다.
# 결정적(PixelLab/Gemini 불요 — §10.1 절차 파생 방침). 잔디는 lip 상단(둘 다 SOLID_TEX·_harmonize
# 미적용)이라 톤 일관. 곡선 경계는 2px 그리드 양자화(청크 캐논 유지 — enforce_chunk 불요).
#
# 산출: cliff_corner_{sw,se}.png(Face 톤) · cliff_corner_{sw,se}_b.png(Base 톤)
# 사용: python3 tools/make_cliff_corners.py
import math
from PIL import Image

T = "assets/tiles/"
face = Image.open(T + "cliff_s_face.png").convert("RGBA")
base = Image.open(T + "cliff_s_base.png").convert("RGBA")
# ★[ADR-0056 REV5 ②] 코너의 물러난 영역 = *투명*(고정 잔디 X). 런타임에 _build_ground16이 그 투명 픽셀을
#   *주변 타일 지형*(노치 코너=tan 통로 / 맵끝=저지 등, 이웃 셀 샘플)으로 채운다 → 코너가 주변 타일을
#   인식해 이어짐(owner "잔디타일이 이어졌자나" 교정). 여기선 벽(불투명)만 남기고 물러난 영역을 비운다.
W, H = face.size            # 32,32
WALL_H = H * 2              # Face+Base = 논리 세로 64
R = 18                     # 밑동에서 물러나는 최대 폭(px) — dump 보고 조정 가능
JIT = 3                    # ★ 경계 raggedness 진폭(px) — 코사인 곡선에 격자 파쇄 주입(벽↔주변 경계 유기화)


def noise(x, y):
    # 결정적 유기 노이즈(격자 파쇄) — 경계를 ±JIT px 불규칙하게 삐치게
    h = (x * 73856093) ^ (y * 19349663) ^ 0x517CC1B7
    return ((h & 0x7FFFFFFF) % 1000) / 1000.0   # 0..1


def boundary(yg):
    # 전역 세로 Yg(0..63): 위=0(직선), 아래=R(최대 물러남). 1/4 코사인 → 밑끝이 둥글게.
    b = R * (1.0 - math.cos(math.pi / 2 * yg / (WALL_H - 1)))
    return round(b / 2) * 2   # 2px 그리드 양자화(청크 캐논)


def carve(src, y_off, side):
    out = src.copy()
    for y in range(H):
        yg = y + y_off
        # ★ 매끄러운 코사인 경계에 유기 노이즈 주입 — 벽↔주변 지형 경계가 불규칙하게 삐침.
        for x in range(W):
            b = boundary(yg) + int((noise(x, yg) - 0.5) * 2.0 * JIT)   # ±JIT 지터
            retreated = (x < b) if side == "sw" else (x > W - 1 - b)
            if retreated:
                out.putpixel((x, y), (0, 0, 0, 0))   # 투명 — 런타임에 주변 지형이 채움
    return out


carve(face, 0, "sw").save(T + "cliff_corner_sw.png")
carve(base, H, "sw").save(T + "cliff_corner_sw_b.png")
carve(face, 0, "se").save(T + "cliff_corner_se.png")
carve(base, H, "se").save(T + "cliff_corner_se_b.png")
print("✅ 곡선 코너 4장 저장 (R=%d): cliff_corner_{sw,se}{,_b}.png" % R)
