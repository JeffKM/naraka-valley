#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ─────────────────────────────────────────────────────────────────────────────
# 영혼빛 연못 유기형(blobby) 형태 마스크 생성기 — S1R-T5 / ADR-0059 결정2 P3·C-5
#
# 왜 오프라인인가(ADR-0058 기각 정책 준수): 물가는 owner 7차 반복으로 확정된 최민감 영역이라
#   *런타임 절차 후처리*는 금지다. 대신 이 유틸을 **한 번 실행**해 정적 형태 마스크 PNG를 굽고
#   커밋한다 — 런타임은 이 손그림-등가 정적 마스크만 읽는다(절차 후처리 아님).
#
# 파이프라인(ADR-0059 결정2): 메타볼(원 합성) → 등고선 추출(Moore 경계 추적) → Chaikin ≤3회
#   스무딩 → 채워 래스터화 → 셀/픽셀 마스크. Perlin/구형 value 노이즈는 축정렬 줄무늬라 배제.
#   ※메타볼 필드 등고선은 해석적으로 매끈(marching-squares 등고선과 동일한 레벨셋)하므로, 픽셀
#     이진 영역의 Moore 경계를 추적해 Chaikin으로 재평활한 뒤 점-내포 판정으로 견고하게 채운다
#     (연속 필드 marching-squares 폴리곤 스티칭은 안장점에서 자기교차 → 채움 붕괴라 이 경로 채택).
#
# 규약(현행 4_0 손그림 마스크와 동일): 0=물 / 1=흙 / 2=테두리(물가 전이 링).
#   출력은 픽셀 마스크(POND_ACTIVITY_RECT 12×11셀 × CELL_PX). 런타임은 셀 중심 픽셀을 샘플해
#   물/흙을 정하고, 물 셀만 `_grid`에 WATER로 심는다(경계 셀별 합성=기존 Wang 4_0 경로가 처리).
#
# 불변식:
#   · 북벽 불변 — 물 최상단 행(world y35)은 rect 폭(x26..33)으로 직선 고정(북단=세로 흙절벽).
#     남·동·서 3변만 blobby.
#   · SPIRIT_POND_RECT(26,34,8,7) 물 영역(y35..40 × x26..33)은 **항상 물로 강제**(바이트 불변·앵커 보존).
#   · POND_ACTIVITY_RECT(24,32,12,11) 밖으로 형태 확장 금지(존 침범 금지).
#   · 결정적(고정 파라미터·난수 없음).
#
# 사용: python3 game/tools/make_pond_mask.py
# 산출: game/assets/terrain16/pond_shape_mask.png  (+ stdout ASCII 프리뷰)
# ─────────────────────────────────────────────────────────────────────────────
import os
from PIL import Image

# ── 좌표(main.gd 상수 거울) ──────────────────────────────────────────────────
ACT_X, ACT_Y, ACT_W, ACT_H = 24, 32, 12, 11      # POND_ACTIVITY_RECT (world 셀)
POND_X, POND_Y, POND_W, POND_H = 26, 34, 8, 7     # SPIRIT_POND_RECT
POND_WATER_Y0 = POND_Y + 1                        # y35 — 물 최상단(y34=CLIFF_BANK)
POND_WATER_Y1 = POND_Y + POND_H                   # y41 (배타) → 물 행 y35..40
CELL_PX = 32                                       # 마스크 픽셀/셀
OUT_W, OUT_H = ACT_W * CELL_PX, ACT_H * CELL_PX

# ── 팔레트(0물/1흙/2테두리) — Read 육안 판정용 + 런타임 최근접 분류 ───────────
COL_WATER = (46, 102, 158)
COL_EARTH = (74, 58, 44)
COL_BORDER = (216, 206, 128)
BORDER_PX = 3   # 물 가장자리에서 이 픽셀 이내 흙 = 테두리(2)

# ── 형태(로컬 셀 좌표: 원점 = POND_ACTIVITY_RECT 좌상단) ──────────────────────
#   몸통 = 슈퍼타원(둥근-사각) — rect(로컬 x[2,10) y[3,9))를 ~1셀 여백으로 온전히 덮되 *직선 변이 없는*
#   부드러운 곡선(원 합성의 매끈 판 — 원-union의 뾰족 cusp 없음). 여기에 저주파 각도 워블을 곱해
#   남·동·서를 유기적으로 넘실대게 한다(북은 클립으로 직선=절벽 정합). Chaikin이 픽셀 계단을 편다.
#   결정적(고정 위상·난수 없음).
import math as _m
CX, CY = 5.7, 5.9        # 슈퍼타원 중심(로컬 셀) — 중심 살짝 서쪽(남 아치가 PATH 훅 x33 전에 수그러들게)
AX, AY = 5.05, 3.95      # 반축(rect 코너 포함·짧은변 과팽창 없음)
SE_N = 3.0               # 슈퍼타원 지수(↓=타원↑ 중앙 아치 남측 — 평평 바닥·PATH 플랭킹 방지)
WOBBLE_A = 0.15          # 유기 워블 진폭(경계 반경 ±%)


def _wobble(theta):
    # 저주파 결정적 주기함수(평균≈0, 범위≈[-1,1]) — 남·동·서에 넘실대는 유기 굴곡.
    return (0.55 * _m.sin(3.0 * theta + 0.7)
            + 0.30 * _m.sin(5.0 * theta + 2.1)
            + 0.15 * _m.sin(2.0 * theta - 1.2))


def _shape_water(lx, ly):
    dx = lx - CX
    dy = ly - CY
    s = abs(dx / AX) ** SE_N + abs(dy / AY) ** SE_N
    th = _m.atan2(dy, dx)
    return s <= 1.0 + WOBBLE_A * _wobble(th)


# ── 1) 형태(슈퍼타원 몸통 × 저주파 워블) → 픽셀 이진 물영역 ───────────────────
def field_water():
    water = [[False] * OUT_W for _ in range(OUT_H)]
    for py in range(OUT_H):
        ly = (py + 0.5) / CELL_PX
        for px in range(OUT_W):
            lx = (px + 0.5) / CELL_PX
            if _shape_water(lx, ly):
                water[py][px] = True
    return water


# ── 2) Moore 경계 추적 → 단일 닫힌 윤곽(픽셀 좌표) ───────────────────────────
#   시계방향 8-이웃(N부터). 표준 Moore-Neighbor tracing + Jacob 정지조건.
_NB = [(0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1)]
_NB_IDX = {d: i for i, d in enumerate(_NB)}


def trace_contour(water):
    start = None
    for y in range(OUT_H):
        for x in range(OUT_W):
            if water[y][x]:
                start = (x, y)
                break
        if start:
            break
    if start is None:
        return []

    def is_w(x, y):
        return 0 <= x < OUT_W and 0 <= y < OUT_H and water[y][x]

    contour = [start]
    p = start
    b = (start[0] - 1, start[1])   # 진입 배경 셀 = 서(스캔상 왼쪽은 배경)
    guard = 0
    limit = OUT_W * OUT_H * 4
    while guard < limit:
        guard += 1
        di = _NB_IDX[(b[0] - p[0], b[1] - p[1])]
        found = False
        for k in range(1, 9):
            idx = (di + k) % 8
            d = _NB[idx]
            c = (p[0] + d[0], p[1] + d[1])
            if is_w(c[0], c[1]):
                pd = _NB[(idx - 1) % 8]           # 직전(배경) 이웃
                b = (p[0] + pd[0], p[1] + pd[1])
                p = c
                found = True
                break
        if not found:
            break
        if p == start:
            break
        contour.append(p)
    return contour


# ── 3) Chaikin(닫힌 폴리곤) N회 ─────────────────────────────────────────────
def chaikin_closed(pts, iters):
    for _ in range(iters):
        n = len(pts)
        out = []
        for i in range(n):
            p = pts[i]
            q = pts[(i + 1) % n]
            out.append((0.75 * p[0] + 0.25 * q[0], 0.75 * p[1] + 0.25 * q[1]))
            out.append((0.25 * p[0] + 0.75 * q[0], 0.25 * p[1] + 0.75 * q[1]))
        pts = out
    return pts


# ── 4) 단일 단순 폐곡선 채우기(even-odd 스캔라인) ────────────────────────────
def fill_polygon(poly):
    water = [[False] * OUT_W for _ in range(OUT_H)]
    n = len(poly)
    if n < 3:
        return water
    for py in range(OUT_H):
        yc = py + 0.5
        xs = []
        for i in range(n):
            x1, y1 = poly[i]
            x2, y2 = poly[(i + 1) % n]
            if (y1 <= yc < y2) or (y2 <= yc < y1):
                xs.append(x1 + (yc - y1) * (x2 - x1) / (y2 - y1))
        xs.sort()
        for k in range(0, len(xs) - 1, 2):
            xa = int(round(xs[k]))
            xb = int(round(xs[k + 1]))
            for px in range(max(0, xa), min(OUT_W, xb)):
                water[py][px] = True
    return water


def apply_clips(water):
    """북벽 불변 + rect 물 강제 + 활동존 클립."""
    top_cell = POND_WATER_Y0 - ACT_Y          # world y35 → local cell 3
    rect_lx0 = POND_X - ACT_X                 # 2
    rect_lx1 = POND_X + POND_W - ACT_X        # 10
    rect_ly1 = POND_WATER_Y1 - ACT_Y          # y41 → local 9
    for py in range(OUT_H):
        ly = py / CELL_PX
        for px in range(OUT_W):
            lx = px / CELL_PX
            if ly < top_cell:                              # ① 물 최상단행 위 = 물 금지(북 절벽)
                water[py][px] = False
                continue
            if ly < top_cell + 1 and not (rect_lx0 <= lx < rect_lx1):  # ② 최상단행=rect폭만(직선)
                water[py][px] = False
    for py in range(top_cell * CELL_PX, rect_ly1 * CELL_PX):          # ③ rect 물 강제(바이트 불변)
        for px in range(rect_lx0 * CELL_PX, rect_lx1 * CELL_PX):
            water[py][px] = True
    return water


def build_class(water):
    cls = [[1] * OUT_W for _ in range(OUT_H)]
    for py in range(OUT_H):
        for px in range(OUT_W):
            if water[py][px]:
                cls[py][px] = 0
    for py in range(OUT_H):
        for px in range(OUT_W):
            if cls[py][px] != 1:
                continue
            near = False
            for dy in range(-BORDER_PX, BORDER_PX + 1):
                for dx in range(-BORDER_PX, BORDER_PX + 1):
                    ny, nx = py + dy, px + dx
                    if 0 <= ny < OUT_H and 0 <= nx < OUT_W and water[ny][nx]:
                        near = True
                        break
                if near:
                    break
            if near:
                cls[py][px] = 2
    return cls


def save_png(cls, path):
    im = Image.new("RGB", (OUT_W, OUT_H))
    px = im.load()
    for y in range(OUT_H):
        for x in range(OUT_W):
            c = cls[y][x]
            px[x, y] = COL_WATER if c == 0 else (COL_BORDER if c == 2 else COL_EARTH)
    im.save(path)


def cell_class(cls, cx, cy):
    return cls[cy * CELL_PX + CELL_PX // 2][cx * CELL_PX + CELL_PX // 2]


def ascii_preview(cls):
    print("\n연못 셀 마스크(원점 world x%d,y%d · ~=물 .=테두리 #=흙 · R=rect물):" % (ACT_X, ACT_Y))
    ext = 0
    for cy in range(ACT_H):
        row = ""
        for cx in range(ACT_W):
            c = cell_class(cls, cx, cy)
            wx, wy = ACT_X + cx, ACT_Y + cy
            in_rect = (POND_X <= wx < POND_X + POND_W and POND_WATER_Y0 <= wy < POND_WATER_Y1)
            ch = "~" if c == 0 else ("." if c == 2 else "#")
            if in_rect and c == 0:
                ch = "R"
            if c == 0 and not in_rect:
                ext += 1
            row += ch
        print("  y%2d %s" % (ACT_Y + cy, row))
    print("  rect 밖 확장 물 셀 = %d" % ext)


def _area(w):
    return sum(sum(1 for v in row if v) for row in w)


def main():
    water = field_water()
    a0 = _area(water)
    # 진짜 Chaikin 평활: 메타볼 영역의 Moore 윤곽 추적 → Chaikin 3회 → 재채움.
    # 추적/채움이 비정상(면적 급변)이면 원 필드로 안전 폴백(견고성).
    contour = trace_contour(water)
    print("contour pts=%d, field 셀=%.1f" % (len(contour), a0 / (CELL_PX * CELL_PX)))
    if len(contour) >= 8:
        smooth = chaikin_closed(contour, 3)
        filled = fill_polygon(smooth)
        a1 = _area(filled)
        if a1 >= 0.7 * a0:
            water = filled
            print("Chaikin 적용: %.1f 셀" % (a1 / (CELL_PX * CELL_PX)))
        else:
            print("Chaikin 폴백(면적 %.1f<%.1f) → 원 필드 사용" % (a1 / 1024.0, 0.7 * a0 / 1024.0))
    water = apply_clips(water)
    cls = build_class(water)
    here = os.path.dirname(os.path.abspath(__file__))
    out_path = os.path.normpath(os.path.join(here, "..", "assets", "terrain16", "pond_shape_mask.png"))
    save_png(cls, out_path)
    print("✅ 저장:", out_path, "(%dx%d)" % (OUT_W, OUT_H))
    ascii_preview(cls)


if __name__ == "__main__":
    main()
