#!/usr/bin/env python3
# ★ 건물 실내 바닥·벽 타일 절차 생성 (barn/coop/storehouse × floor·wall 6종).
#   ADR-0048 §5 "실내타일=Claude 즉시 절차". 로스터 §2 maker=claude.
#   - 청크 캐논(asset-ruleset §0.1): 16 논리px × 2 = 32 화면px. 여기서 16×16 논리로 그린 뒤
#     ×2 nearest 업스케일 → 2px 블록 보장(enforce_chunk 불필요, 이미 청키).
#   - 이음새(seam): 타일은 반복되므로 가장자리(x=15↔x=0)에서 하드라인이 안 생기게
#     plank 세로 이음선을 타일 중앙(x=8)에만 두고 좌/우 가장자리는 판재 중앙으로 둔다.
#   - NW 광원(asset-ruleset): 상/좌를 밝게, 하/우를 어둡게 미세 셰이딩.
#   - 저승 따뜻한 베이스(asset-ruleset §): 흙·나무·볏짚 warm 톤 기조. 집(허니 나무)·
#     카페(다크 월넛)와 구분되게 barn=거친 흙+볏짚, coop=밝은 볏짚, storehouse=돌.
from PIL import Image

L = 16          # 논리 해상도(칸)
S = 2           # 청크 배율 → 32px 출력
OUT = "assets/tiles"


def _h(x, y, salt):
    # 결정적 해시(0..1) — 픽셀별 노이즈. 타일 내부에서만 쓰므로 반복은 무방.
    n = (x * 374761393 + y * 668265263 + salt * 2246822519) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def _mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def _save(name, px):
    im = Image.new("RGBA", (L, L), (0, 0, 0, 255))
    ip = im.load()
    for y in range(L):
        for x in range(L):
            r, g, b = px[y][x]
            ip[x, y] = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)), 255)
    im = im.resize((L * S, L * S), Image.NEAREST)
    im.save(f"{OUT}/{name}.png")
    print(f"  {name}.png {im.size}")


def _grid(base):
    return [[base for _ in range(L)] for _ in range(L)]


# ── 넋우릿간(barn) — 대형 축사: 다진 흙바닥 + 흩뿌린 볏짚 ──────────────────
def barn_floor():
    dirt = (86, 66, 46)          # 따뜻한 다진 흙
    dark = (66, 49, 33)
    straw = (150, 120, 62)       # 볏짚 금빛
    px = _grid(dirt)
    for y in range(L):
        for x in range(L):
            n = _h(x, y, 11)
            c = _mix(dirt, dark, 0.35) if n < 0.22 else dirt
            if n > 0.90:
                c = _mix(dirt, dark, 0.6)   # 흙 뭉침(어두운 알갱이)
            # NW 미세 셰이딩
            shade = 1.0 + (0.05 if (x + y) < 8 else -0.05 if (x + y) > 22 else 0.0)
            c = tuple(int(v * shade) for v in c)
            px[y][x] = c
    # 흩뿌린 볏짚 낱개(짧은 대각선) — 결정적 위치, 가장자리 피함(이음새 방지)
    for sx, sy, dxi in [(3, 4, 1), (10, 3, -1), (6, 9, 1), (11, 11, 1), (2, 12, -1), (13, 7, -1)]:
        for k in range(3):
            x = sx + k * dxi
            y = sy + (k // 2)
            if 0 < x < L - 1 and 0 < y < L - 1:
                px[y][x] = _mix(straw, dirt, 0.15 * k)
    _save("barn_floor", px)


def barn_wall():
    # 세로 판재 축사 벽 — 거칠고 어두운 나무, 판 사이 어두운 이음.
    wood = (92, 66, 44)
    grain = (74, 52, 34)
    seam = (48, 34, 22)
    hi = (112, 84, 56)
    px = _grid(wood)
    seams_x = {0, 8}              # 세로 이음(x=8 중앙, x=0 가장자리는 다음 타일 x=... 와 맞물림)
    for y in range(L):
        for x in range(L):
            c = wood
            if x in seams_x:
                c = seam
            elif (x - 1) in seams_x:
                c = hi                # 이음 오른쪽 밝은 모서리(NW 광원)
            else:
                n = _h(x, y, 22)
                if n < 0.30:
                    c = grain
                elif n > 0.92:
                    c = _mix(wood, hi, 0.5)
            px[y][x] = c
    _save("barn_wall", px)


# ── 넋둥우리(coop) — 소형 닭장: 밝은 볏짚 깔개 ───────────────────────────
def coop_floor():
    straw = (168, 138, 78)       # 밝은 볏짚
    lo = (140, 112, 60)
    hi = (190, 162, 100)
    px = _grid(straw)
    for y in range(L):
        for x in range(L):
            n = _h(x, y, 31)
            # 볏짚 결: 짧은 가로 획으로 지푸라기 느낌
            if n < 0.34:
                c = lo
            elif n > 0.78:
                c = hi
            else:
                c = straw
            # 가로 지푸라기 하이라이트
            if _h(x // 2, y, 37) > 0.86:
                c = _mix(c, hi, 0.5)
            shade = 1.0 + (0.04 if y < 6 else -0.04 if y > 12 else 0.0)
            px[y][x] = tuple(int(v * shade) for v in c)
    _save("coop_floor", px)


def coop_wall():
    # 가로 판재(닭장 널빤지) — 밝은 나무, 가로 이음.
    wood = (150, 116, 74)
    grain = (128, 98, 60)
    seam = (96, 72, 44)
    hi = (176, 142, 96)
    px = _grid(wood)
    seams_y = {0, 8}             # 가로 이음
    for y in range(L):
        for x in range(L):
            c = wood
            if y in seams_y:
                c = seam
            elif (y - 1) in seams_y:
                c = hi                # 이음 아래 밝은 상단(NW)
            else:
                n = _h(x, y, 42)
                if n < 0.28:
                    c = grain
                elif n > 0.93:
                    c = _mix(wood, hi, 0.5)
            px[y][x] = c
    _save("coop_wall", px)


# ── 갈무리방(storehouse) — 저장고: 돌 판석 바닥 ─────────────────────────
def storehouse_floor():
    stone = (110, 104, 96)       # 서늘한 회갈 돌
    lo = (88, 82, 76)
    mortar = (64, 60, 56)        # 줄눈
    hi = (132, 126, 118)
    px = _grid(stone)
    for y in range(L):
        for x in range(L):
            n = _h(x, y, 51)
            c = _mix(stone, lo, 0.5) if n < 0.35 else stone
            if n > 0.90:
                c = _mix(stone, hi, 0.5)
            px[y][x] = c
    # 판석 줄눈(오프셋 벽돌 배열) — 가로선 y=0,8 / 세로선 위칸 x=8, 아래칸 x=0
    for x in range(L):
        px[0][x] = mortar
        px[8][x] = mortar
    for y in range(1, 8):
        px[y][8] = mortar
    for y in range(9, 16):
        px[y][0] = mortar
    # 줄눈 아래 하이라이트(입체)
    for x in range(L):
        if px[1][x] != mortar:
            px[1][x] = _mix(px[1][x], hi, 0.4)
        if px[9][x] != mortar:
            px[9][x] = _mix(px[9][x], hi, 0.4)
    _save("storehouse_floor", px)


def storehouse_wall():
    # 쌓은 돌벽(저장고 벽) — 가로 켜, 어두운 줄눈.
    stone = (100, 94, 86)
    lo = (80, 74, 68)
    mortar = (54, 50, 46)
    hi = (124, 118, 110)
    px = _grid(stone)
    for y in range(L):
        for x in range(L):
            n = _h(x, y, 61)
            c = _mix(stone, lo, 0.5) if n < 0.4 else stone
            if n > 0.9:
                c = _mix(stone, hi, 0.45)
            px[y][x] = c
    # 가로 켜 줄눈 y=0,5,10,15 (돌 층) + 엇갈린 세로 줄눈
    for y in (0, 5, 10, 15):
        for x in range(L):
            px[y][x] = mortar
    for y, sx in ((2, 8), (7, 4), (12, 8)):
        px[y][sx] = mortar
    # 켜 아래 하이라이트
    for y in (1, 6, 11):
        for x in range(L):
            if px[y][x] != mortar:
                px[y][x] = _mix(px[y][x], hi, 0.35)
    _save("storehouse_wall", px)


if __name__ == "__main__":
    print("실내 바닥·벽 타일 생성:")
    barn_floor(); barn_wall()
    coop_floor(); coop_wall()
    storehouse_floor(); storehouse_wall()
    print("완료.")
