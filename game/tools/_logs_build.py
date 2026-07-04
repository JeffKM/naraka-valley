#!/usr/bin/env python3
# ★[prop-regen-roster §5.3] 통나무(logs) 5종 정규화 파이프라인 (2026-07-04, owner 방향)
#   PixelLab create_1_direction_object raw(정사각) → alpha bbox crop → 목표 박스에 비율유지
#   contain fit(눌림 없이) → bottom-center 정렬 → 32-native 최종본. 발치가 캔버스 밑단에 오게
#   해 코드 bottom-center 앵커·타원 그림자와 정렬. 하드청키/과양자화 금지(부드러움 우선 — [ADR-0050]).
#
#   최종 크기(footprint 칸): long=96×32(3×1)·short=64×32(2×1)·upright/diag_a/diag_b=32×32(1×1).
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
STAGING = os.path.join(HERE, "..", "assets", "props", "_logs_staging")
OUT = os.path.join(HERE, "..", "assets", "props")

SPECS = [
    # (raw,             최종 파일명,               W,  H,  fit,       rot)  rot=시계방향 보정 각도(deg)
    #   ※ long: PixelLab이 정사각 캔버스에 통나무를 ~1.5:1로만 그려 3×1(96×32)이 안 나온다. 통나무는
    #     원통이라 가로 stretch에 관대(단면=타원, 스타듀 긴 통나무도 그 형태)라 96×32로 늘려 "ㅡ자 긴 통나무"로.
    #     ★재생성(owner 2026-07-05): 회전 보정 통나무는 실루엣만 수평이고 나뭇결이 대각으로 흘러 기울어
    #     보였다 → 나뭇결이 수평인 후보로 재생성([0]) → 회전 불필요(rot 0), stretch로 3×1 채움.
    ("raw_long.png",    "stump_log_long.png",    96, 32, "stretch", 0),
    ("raw_short.png",   "stump_log_short.png",   64, 32, "contain",   0),
    ("raw_upright.png", "stump_log_upright.png", 32, 32, "contain",   0),
    ("raw_diag_a.png",  "stump_log_diag_a.png",  32, 32, "contain",   0),
    #   diag_b: 원본이 거의 수평이라 -45° 회전 → 밝은 대각(diag_a ＼)과 대칭(／) 쌍(owner 2026-07-04).
    ("raw_diag_b.png",  "stump_log_diag_b.png",  32, 32, "contain", -45),
]


def bbox_crop(im: Image.Image) -> Image.Image:
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def keep_largest(im: Image.Image, thr: int = 48) -> Image.Image:
    """최대 연결 덩어리(통나무 본체)만 남기고 분리된 부스러기·잔조각을 지운다(8-이웃 BFS)."""
    px = im.load()
    w, h = im.size
    seen = [[False] * w for _ in range(h)]
    best: list = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx]:
                continue
            if px[sx, sy][3] < thr:
                seen[sy][sx] = True
                continue
            stack = [(sx, sy)]
            seen[sy][sx] = True
            comp = []
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] >= thr:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if len(comp) > len(best):
                best = comp
    keep = set(best)
    for y in range(h):
        for x in range(w):
            if (x, y) not in keep:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
    return im


def process(src: str, dst: str, W: int, H: int, fit: str = "contain", rot: float = 0) -> None:
    im = Image.open(os.path.join(STAGING, src)).convert("RGBA")
    im = keep_largest(im)
    if rot:
        # 시계방향 보정(PIL rotate는 반시계 양수 → 시계방향은 음수). expand로 잘림 방지.
        im = im.rotate(rot, resample=Image.BICUBIC, expand=True)
    im = bbox_crop(im)
    w, h = im.size
    if fit == "stretch":
        # 목표 박스에 꽉 차게 늘림(원통 통나무 — 가로로 길게). BOX 다운스케일.
        nw, nh = W, H
    else:
        # 비율 유지 contain fit (원통 형태 눌림 방지 — 폭·높이 중 작은 스케일)
        scale = min(W / w, H / h)
        nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    # BOX(area-average) 다운스케일 = 픽셀아트 다운에 계단·번짐 최소
    im = im.resize((nw, nh), Image.BOX)
    # alpha 임계 정리(다운스케일 반투명 잔털 제거 — 발치·외곽 깔끔하게)
    px = im.load()
    for y in range(nh):
        for x in range(nw):
            r, g, b, a = px[x, y]
            if a < 48:
                px[x, y] = (r, g, b, 0)
            elif a > 200:
                px[x, y] = (r, g, b, 255)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ox = (W - nw) // 2
    oy = H - nh  # bottom align (발치 = 캔버스 밑단)
    canvas.alpha_composite(im, (ox, oy))
    canvas.save(os.path.join(OUT, dst))
    print(f"{dst:26s} {W}x{H}  <- crop {w}x{h}  scaled {nw}x{nh}  at ({ox},{oy})")


if __name__ == "__main__":
    for src, dst, W, H, fit, rot in SPECS:
        process(src, dst, W, H, fit, rot)
    print("done.")
