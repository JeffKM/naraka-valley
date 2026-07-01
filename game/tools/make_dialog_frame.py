#!/usr/bin/env python3
"""나라카 대화창 「태운 한지(burnt hanji)」 9-slice 프레임 + 먹 나비 생성 (ADR-0001 허용 글루).

owner 참조(나라카 채키, /tmp/naraka_frame_ref.png)의 미감을 UI로 번역:
  - 따뜻한 한지 양피 바탕(아기자기·따뜻)
  - 그을린/타들어간 불규칙 딱지 테두리(저승, 딱딱하지 않게)
  - 수묵 먹 나비(민속 나비=혼) = 시그니처 인디케이터

산출(assets/ui/):
  - hanji_frame.png : 9-slice(STRETCH) — 한지 중앙 + 그을린 딱지 테두리(margin 16)
  - hanji_plate.png : 이름판용 작은 9-slice(margin 10)
  - soul_moth.png   : 먹 나비 아이콘(다음 표시·이름 옆)
전부 청키(작은 native·nearest 렌더 전제). 결정적(seed 고정).
"""
from __future__ import annotations
import math
import os
import random
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")
random.seed(20260701)  # 결정적

# ── 팔레트(참조에서 뽑아 UI용으로 보정) ────────────────────────────────
PARCH      = (0xd8, 0xc9, 0xa8)  # 한지 베이스(밝은 따뜻)
PARCH_D    = (0xc6, 0xb4, 0x8f)  # 얼룩 어둠
PARCH_L    = (0xe8, 0xdc, 0xc0)  # 얼룩 밝음·베벨 하이라이트
# ── 프레임 밴드(또렷한 "틀") : 그을린 목재/가죽 톤 + NW 광원 베벨 ──
OUTLINE    = (0x1c, 0x14, 0x0e)  # 최외곽 크리스프 선(정의)
BAND_D     = (0x43, 0x2d, 0x1c)  # 밴드 어둠(SE 그림자)
BAND       = (0x6b, 0x49, 0x2c)
BAND_L     = (0x8f, 0x66, 0x3d)  # 밴드 밝음(NW 광원)
ACCENT     = (0x40, 0x18, 0x18)  # 안쪽 크리스프 선 = 마스터 외곽선 마룬(월드 정합)
STUD       = (0xc9, 0x9a, 0x50)  # 코너 장식(앰버 금)
STUD_HI    = (0xe8, 0xc4, 0x78)
STUD_D     = (0x6e, 0x4a, 0x22)
INK        = (0x2a, 0x21, 0x18)  # 먹빛


def _mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def make_frame(size: int, margin: int, path: str, studs: bool = True) -> None:
    """또렷한 프레임 밴드(크리스프 외곽선 + 베벨 + 마룬 내곽선) + 한지 중앙 + 코너 앰버 장식.
    스타듀 나무테처럼 '틀'로 읽히게 정의감을 준다(단, 그을린 한지 톤)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    band = margin  # 프레임 밴드 폭
    for y in range(size):
        for x in range(size):
            d = min(x, y, size - 1 - x, size - 1 - y)  # 가장자리까지 거리
            n = random.random()
            if d >= band:
                # ── 한지 중앙: 따뜻한 양피 + 저주파 얼룩 + 은은한 가로 섬유 ──
                lf = 0.5 + 0.5 * math.sin(x / 5.0 + 1.3) * math.sin(y / 5.0 + 0.7)
                base = _mix(PARCH_D, PARCH_L, max(0.0, min(1.0, lf * 0.6 + (n - 0.5) * 0.35)))
                if (y * 7 + int(3 * math.sin(x / 9.0))) % 6 == 0:  # 가로 한지 섬유(연하게)
                    base = _mix(base, PARCH_D, 0.28)
                px[x, y] = (base[0], base[1], base[2], 255)
            elif d <= 1:
                px[x, y] = (*OUTLINE, 255)                       # 크리스프 외곽선(2px)
            elif d >= band - 2:
                px[x, y] = (*ACCENT, 255)                        # 크리스프 내곽선(마룬 2px)
            elif d == band - 3:
                px[x, y] = (*PARCH_L, 255)                       # 내곽 하이라이트 1px(베벨 팝)
            else:
                # 밴드 본체 — NW 광원 베벨(좌상 밝고 우하 어둡게)
                lit = 1.0 - (x + y) / float(2 * size)            # 0(SE)~1(NW)
                col = _mix(BAND_D, BAND_L, max(0.0, min(1.0, 0.25 + lit * 0.9)))
                col = _mix(col, BAND, 0.25 + (n - 0.5) * 0.12)   # 결 노이즈
                px[x, y] = (col[0], col[1], col[2], 255)
    # ── 코너 앰버 장식(스터드) — 4모서리 밴드 중앙에 작은 못/매듭 ──
    if studs:
        cc = band // 2
        for (ox, oy) in [(cc, cc), (size - 1 - cc, cc), (cc, size - 1 - cc), (size - 1 - cc, size - 1 - cc)]:
            for yy in range(oy - 3, oy + 4):
                for xx in range(ox - 3, ox + 4):
                    if 0 <= xx < size and 0 <= yy < size:
                        r = abs(xx - ox) + abs(yy - oy)          # 다이아몬드
                        if r <= 1:
                            px[xx, yy] = (*STUD_HI, 255)
                        elif r == 2:
                            px[xx, yy] = (*STUD, 255)
                        elif r == 3:
                            px[xx, yy] = (*STUD_D, 255)           # 장식 외곽
    img.save(os.path.join(OUT, path))
    print(f"  ✓ {path} ({size}x{size}, band {margin}, studs={studs})")


def make_moth(path: str) -> None:
    """수묵 먹 나비(대칭, 붓끝 거친 결). ~24px."""
    S = 24
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    cx = S / 2.0
    # 나비 실루엣: 위·아래 날개 타원 2쌍 + 몸통
    def wing(x, y):
        dx = abs(x - cx)
        # 윗날개(큰), 아랫날개(작)
        up = ((dx - 6.0) ** 2) / 22.0 + ((y - 8.0) ** 2) / 14.0
        lo = ((dx - 4.5) ** 2) / 12.0 + ((y - 15.0) ** 2) / 12.0
        return up < 1.0 or lo < 1.0
    for y in range(S):
        for x in range(S):
            body = abs(x - cx) < 1.2 and 4 < y < 19
            if body or wing(x, y):
                n = random.random()
                if n > 0.14:  # 붓끝 거친 결(가끔 뚫림)
                    col = INK if n < 0.6 else _mix(INK, (0, 0, 0), 0.4)
                    px[x, y] = (col[0], col[1], col[2], 255 if n > 0.3 else 200)
    # 더듬이
    for i in range(4):
        px[int(cx) - 1 - i, 4 - 0] = (*INK, 255) if 4 - 0 >= 0 else (0, 0, 0, 0)
        px[int(cx) + i, 4] = (*INK, 255)
    img.save(os.path.join(OUT, path))
    print(f"  ✓ {path} ({S}x{S})")


def make_foxfire(path: str) -> None:
    """여우불 wisp — 파란 불꽃 티어드롭(다음 버튼/저승 포인트). ~16×20."""
    W, H = 16, 20
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    cx = W / 2.0
    BASE = (0x2a, 0x6c, 0xc8)
    MID = (0x5a, 0xb4, 0xf0)
    TIP = (0x9a, 0xe4, 0xff)
    CORE = (0xe8, 0xf8, 0xff)
    for y in range(H):
        ty = y / float(H - 1)                # 0 위(뾰족)~1 아래(둥근)
        halfw = (0.6 + 3.4 * ty) * (1.0 - 0.15 * ty)  # 아래로 갈수록 넓게
        wob = 0.9 * math.sin(y / 3.0 + 0.6)  # 흔들림
        for x in range(W):
            dx = x - (cx + wob)
            if abs(dx) <= halfw:
                edge = abs(dx) / max(0.6, halfw)   # 0 중심~1 가장자리
                h = (1 - ty)                       # 위=차가운 팁
                if edge < 0.35 and ty > 0.35:
                    col = CORE
                elif h > 0.62:
                    col = TIP
                elif edge > 0.72:
                    col = BASE
                else:
                    col = MID
                a = 255 if edge < 0.85 else 180
                px[x, y] = (col[0], col[1], col[2], a)
    img.save(os.path.join(OUT, path))
    print(f"  ✓ {path} ({W}x{H})")


def make_ink_arrow(path: str) -> None:
    """수묵 먹 아래화살표(다음) — 붓으로 찍은 듯 거친 결·먹빛. 먹 나비와 톤 정합. ~18×16."""
    W, H = 18, 16
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    cx = (W - 1) / 2.0
    tip_y = H - 1
    for y in range(H):
        ty = y / float(H - 1)              # 0 위(넓음)~1 아래(뾰족)
        half = (W * 0.5 - 1.0) * (1.0 - ty) # 아래로 갈수록 좁게(삼각형)
        for x in range(W):
            dx = abs(x - cx)
            if dx <= half:
                n = random.random()
                edge = dx / max(0.6, half)
                # 가장자리 붓 결(가끔 뚫림)·중심 진함
                if edge > 0.82 and n > 0.45:
                    continue
                col = INK if n < 0.7 else _mix(INK, (0, 0, 0), 0.35)
                a = 255 if edge < 0.7 else (210 if n > 0.3 else 150)
                px[x, y] = (col[0], col[1], col[2], a)
    # 붓 시작 꼬리(위쪽 중앙 짧은 세로 획)
    for y in range(0, 3):
        for x in (int(cx), int(cx) + 1):
            if random.random() > 0.25:
                px[x, y] = (*INK, 230)
    img.save(os.path.join(OUT, path))
    print(f"  ✓ {path} ({W}x{H})")


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    make_frame(72, 18, "hanji_frame.png")
    make_frame(40, 9, "hanji_plate.png", studs=False)
    make_moth("soul_moth.png")
    make_ink_arrow("ink_arrow.png")
    print(f"저장 → {os.path.abspath(OUT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
