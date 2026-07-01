#!/usr/bin/env python3
"""옥자 5표정 시트(제미나이) → 대화 초상화 5장 (ADR-0001 허용 글루: 크롭·리사이즈).

owner가 한 장에 5표정(Neutral/Talk/Smile/Shy/Sad)을 생성.
**2026-07-01 재개정 — 입력 레이아웃 변경:** owner가 배경 제거된(투명 알파) 500² 원화에
헤드&체스트 버스트 5개를 **2행 그리드**로 배치(위 3 = 중립·말하기·미소 / 아래 2 = 수줍음·슬픔).
옛 파이프라인(체커 배경·가로 1줄·골짜기 분할·텍스트밴드 크롭)은 이 입력엔 안 맞아 폐기.
새 처리(투명 배경이 이미 배경 제거를 해줌 → strip_bg/find_cuts/sever 불필요):
  ① 얼굴별 고정 사각 크롭(RECTS — 열 경계·행 경계는 얼굴 사이 여백). 행 경계는 위 얼굴
     가슴 자락이 아래 크롭에 물리지 않게 y를 충분히 내려 잡음.
  ② 크롭 안에서 **최대 연결성분(keep_largest)** 만 — 경계에 물린 이웃 머리/모자 조각 제거.
  ③ 알파 오토크롭 → 320² 정사각 캔버스 contain(to_bust) → 내부 구멍 메움(fill_holes).
주의: 모자 꼭대기는 소스 원화 y=0에서 이미 잘려 있음(헤드룸 없음) — 5장 모두 동일하게
잘려 일관성은 유지되나, 복원 불가(owner 원화 단계 이슈).
산출: portrait-spec-card.md 규격(320² 투명). 기본은 /tmp 검수, --commit 시 assets/portraits.
사용: python3 tools/make_okja_portraits.py [<sheet.png>] [--commit]
"""
from __future__ import annotations
import os
import sys
from collections import deque
from PIL import Image

SHEET_DEFAULT = "/Users/jefflee/Downloads/Gemini_Generated_Image_itinplitinplitin-removebg-preview.png"
BUST = 320
# 얼굴별 고정 크롭 사각 (stem, x0, y0, x1, y1) — 500² 2행 그리드 기준.
# 위 3(중립·말하기·미소) y 0~250 / 아래 2(수줍음·슬픔) y 256~500(위 가슴띠 아래로 내림).
RECTS = [
    ("okja",       0,   0,   165, 250),  # 중립(입 다뭄)
    ("okja_talk",  165, 0,   333, 250),  # 말하기(입 열림) — 폴백 허브
    ("okja_smile", 333, 0,   500, 250),  # 미소
    ("okja_shy",   0,   256, 250, 500),  # 수줍음(분홍테 안경·홍조)
    ("okja_sad",   250, 256, 500, 500),  # 슬픔(눈 내리깜)
]
ASSETS = os.path.join(os.path.dirname(__file__), "..", "assets", "portraits")


def keep_largest(im: Image.Image) -> Image.Image:
    """불투명 픽셀의 최대 연결성분(=초상화)만 남기고 나머지(텍스트 blob) 투명화."""
    w, h = im.size
    px = im.load()
    label = [0] * (w * h)
    best_id, best_sz, cur = 0, 0, 0
    comps = {}
    for sy in range(h):
        for sx in range(w):
            i0 = sy * w + sx
            if label[i0] or px[sx, sy][3] == 0:
                continue
            cur += 1
            sz = 0
            dq = deque([(sx, sy)])
            label[i0] = cur
            while dq:
                x, y = dq.popleft()
                sz += 1
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not label[j] and px[nx, ny][3] != 0:
                            label[j] = cur
                            dq.append((nx, ny))
            comps[cur] = sz
            if sz > best_sz:
                best_sz, best_id = sz, cur
    for y in range(h):
        for x in range(w):
            if label[y * w + x] != best_id:
                p = px[x, y]
                if p[3] != 0:
                    px[x, y] = (p[0], p[1], p[2], 0)
    return im


def fill_holes(im: Image.Image) -> Image.Image:
    """실루엣 내부의 enclosed 투명 구멍(테두리에 안 닿는 투명)을 이웃 색으로 메운다.
    주로 to_bust의 LANCZOS 다운스케일이 알파에 만든 구멍이 '지워진' 것처럼 보이는 것 방지
    (strip_bg가 판 구멍도 함께 처리). 가장자리로 열린 투명(레이스/베일 사이)은 배경이라 유지.
    **to_bust 뒤에 호출**(리사이즈가 구멍을 만들므로)."""
    w, h = im.size
    px = im.load()
    # ① 테두리에서 연결된 투명 = 배경. flood로 마킹.
    bg = bytearray(w * h)
    dq = deque()
    for x in range(w):
        dq.append((x, 0)); dq.append((x, h - 1))
    for y in range(h):
        dq.append((0, y)); dq.append((w - 1, y))
    while dq:
        x, y = dq.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if bg[i] or px[x, y][3] != 0:
            continue
        bg[i] = 1
        dq.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    # ② 배경 아닌 투명 = 내부 구멍. 이웃 불투명색으로 반복 확산 채움.
    holes = [(x, y) for y in range(h) for x in range(w)
             if px[x, y][3] == 0 and not bg[y * w + x]]
    guard = 0
    while holes and guard < 64:
        guard += 1
        rest = []
        for x, y in holes:
            best = None
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] != 0:
                    best = px[nx, ny]
                    break
            if best is not None:
                px[x, y] = (best[0], best[1], best[2], 255)
            else:
                rest.append((x, y))
        if len(rest) == len(holes):
            break
        holes = rest
    return im


def to_bust(im: Image.Image) -> Image.Image:
    bbox = im.getbbox()
    body = im.crop(bbox) if bbox else im
    bw, bh = body.size
    s = min(BUST / bw, BUST / bh)
    nw, nh = max(1, round(bw * s)), max(1, round(bh * s))
    body = body.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (BUST, BUST), (0, 0, 0, 0))
    canvas.paste(body, ((BUST - nw) // 2, (BUST - nh) // 2), body)
    return canvas


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--commit"]
    commit = "--commit" in sys.argv
    sheet = args[0] if args else SHEET_DEFAULT
    out_dir = ASSETS if commit else "/tmp/okja_portraits"
    os.makedirs(out_dir, exist_ok=True)
    im = Image.open(sheet).convert("RGBA")
    montage = Image.new("RGBA", (BUST * len(RECTS), BUST), (30, 24, 32, 255))
    for c, (stem, x0, y0, x1, y1) in enumerate(RECTS):
        seg = keep_largest(im.crop((x0, y0, x1, y1)))  # 크롭 후 이웃 조각 제거
        bust = to_bust(seg)
        bust = fill_holes(bust)  # LANCZOS 다운스케일이 알파에 낸 내부 구멍 메움('지워진' 느낌 방지)
        bust.save(os.path.join(out_dir, stem + ".png"))
        montage.paste(bust, (c * BUST, 0), bust)
        print(f"  ✓ {stem}.png")
    montage.save("/tmp/okja_montage.png")
    print(f"저장 → {out_dir}  (검수 몽타주 /tmp/okja_montage.png)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
