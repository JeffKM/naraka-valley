#!/usr/bin/env python3
# ★ Track B 건물 실내 가구 프롭 절차 생성 (여물통·보관 크레이트).
#   ADR-0048 Phase E — `_draw_feed_trough`/`_draw_storehouse_crates` 그레이박스를 아트로 승격.
#   farm-infra(silo/well/forage)와 같은 결: assets/props/<name>.png 훅 + 그레이박스 폴백.
#   - 청크 캐논: 16 논리px × 2. feed_trough=32×16(16×8 논리)·crate=32×32(16×16 논리).
#   - feed_trough는 가로 타일링(draw_texture_rect tile=true)이라 세로 이음선 없이 균일하게.
#   - NW 광원. 저승 따뜻한 나무 톤(축사/창고 가구).
from PIL import Image

S = 2
OUT = "assets/props"


def _h(x, y, salt):
    n = (x * 374761393 + y * 668265263 + salt * 2246822519) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def _mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def _save(name, w, h, px):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ip = im.load()
    for y in range(h):
        for x in range(w):
            c = px[y][x]
            if c is None:
                continue
            r, g, b = c
            ip[x, y] = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)), 255)
    im = im.resize((w * S, h * S), Image.NEAREST)
    im.save(f"{OUT}/{name}.png")
    print(f"  {name}.png {im.size}")


# ── 여물통(feed_trough) — 32×16(16×8 논리), 가로 타일링 세그먼트 ──────────────
#   뒤 rim(밝은 나무) → 안쪽 여물칸(어두운 recess, 건초가 코드 오버레이로 여기 담김) → 앞 lip(나무).
def feed_trough():
    W, H = 16, 8
    rim = (150, 116, 74)      # 밝은 나무(뒤 테두리, NW 상단)
    rim_hi = (176, 142, 96)
    inner = (58, 42, 26)      # 여물칸 안쪽(어두움 — 건초 오버레이 대비)
    front = (110, 82, 52)     # 앞면 나무
    front_lo = (78, 56, 34)   # 앞면 아래 그늘
    px = [[None] * W for _ in range(H)]
    for x in range(W):
        for y in range(H):
            if y == 0:
                c = rim_hi                      # 최상단 하이라이트 선(NW)
            elif y == 1:
                c = rim
            elif y in (2, 3, 4):
                c = inner                       # 여물칸(건초 담김)
                if _h(x, y, 71) > 0.85:
                    c = _mix(inner, front, 0.4)  # 안쪽 나뭇결 티끌
            elif y == 5:
                c = front
            elif y == 6:
                c = _mix(front, front_lo, 0.5)
            else:
                c = front_lo                    # 바닥 그늘선
            px[y][x] = c
    _save("feed_trough", W, H, px)


# ── 보관 크레이트(storehouse_crate) — 32×32(16×16 논리), 발치 앵커 ─────────────
def storehouse_crate():
    N = 16
    frame = (120, 88, 52)     # 나무 프레임(밝은 판)
    frame_hi = (146, 110, 70)
    plank = (98, 70, 42)      # 안쪽 판재
    dark = (60, 42, 24)       # 이음/외곽 그늘
    px = [[None] * N for _ in range(N)]
    for y in range(N):
        for x in range(N):
            edge = (x == 0 or y == 0 or x == N - 1 or y == N - 1)
            if edge:
                c = dark if (x == N - 1 or y == N - 1) else frame_hi   # SE 어둡게·NW 밝게
            elif x in (1, 2) or x in (N - 3, N - 2) or y in (1, 2) or y in (N - 3, N - 2):
                c = frame                       # 프레임 테두리 띠
            else:
                c = plank
                if _h(x, y, 81) < 0.28:
                    c = _mix(plank, dark, 0.4)  # 판 나뭇결
                elif _h(x, y, 83) > 0.9:
                    c = _mix(plank, frame_hi, 0.4)
            px[y][x] = c
    # X 대각 보강대(크레이트 느낌)
    for i in range(2, N - 2):
        px[i][i] = _mix(frame, dark, 0.3)
        px[i][N - 1 - i] = _mix(frame, dark, 0.3)
    # 상단 뚜껑 이음선
    for x in range(1, N - 1):
        px[3][x] = _mix(frame, dark, 0.5) if px[3][x] != dark else px[3][x]
    _save("storehouse_crate", N, N, px)


if __name__ == "__main__":
    print("Track B 실내 가구 프롭 생성:")
    feed_trough()
    storehouse_crate()
    print("완료.")
