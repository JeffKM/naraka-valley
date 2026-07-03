#!/usr/bin/env python3
# 가축 스프라이트 구운 접지 그림자 제거 글루 (ADR-0001 허용: 배치 전 정리).
#
# 왜 필요한가: Gemini가 가축을 뽑을 때 발밑에 어두운 타원 접지 그림자를 구워 넣었다.
#   우리 규약(gemini-demo-sprites-spec §0.2)은 가축 = self-shadow only — 접지 그림자는
#   코드(_draw_ranch/Y-sort)가 그린다(§7-2 결정, owner 2026-07-03). 스프라이트에 구운
#   그림자를 두면 코드 그림자와 이중이 되므로 제거한다. (혼백도 나무만 구운 그림자 예외.)
#
# 판정: 접지 그림자 = 어두운 남보라/회보라(V<0.45) · 저채도(S<0.6) · 푸른끼(B>=R) ·
#   bbox 하단 영역(몸통 상단 음영 보호). 동물 몸통은 밝은 석양/회백(V>0.5)이라 명도로
#   갈린다. 갈색 발굽(B<R)은 푸른끼 조건에서 제외돼 보호된다. 마지막에 최대 연결성분만
#   남겨 몸통과 분리된 잔여(반짝이·그림자 조각)를 청소한다. (PIL만 — numpy 미의존.)
#
# 사용: python3 tools/strip_baked_shadow.py <src.png> <dst.png> [bottom_frac=0.52]
import sys
from PIL import Image


def main() -> None:
    if len(sys.argv) < 3:
        print("usage: strip_baked_shadow.py <src.png> <dst.png> [bottom_frac]")
        sys.exit(1)
    src, dst = sys.argv[1], sys.argv[2]
    bottom_frac = float(sys.argv[3]) if len(sys.argv) > 3 else 0.52
    hoof_margin = int(sys.argv[4]) if len(sys.argv) > 4 else 6  # 발굽 허용 두께(px)

    im = Image.open(src).convert("RGBA")
    W, H = im.size
    px = im.load()
    bbox = im.getbbox()
    if bbox is None:
        im.save(dst)
        return
    x0, y0, x1, y1 = bbox
    shadow_top = y0 + int((y1 - y0) * bottom_frac)

    # 열(x)별 위→아래 스캔. 다리 보호: 밝은 몸통/다리 픽셀에 "연속으로 붙은" 어두운
    # 부분(발굽·다리 하단 음영)은 구조로 보고 살린다. 투명 간격(a==0)을 거쳐 나온 어두운
    # 그림자후보(발 바깥·발 사이로 퍼진 타원)만 제거한다. 색이 다리와 같아도 위상으로 갈린다.
    n_shadow = 0
    for x in range(x0, x1):
        bright_above = False  # 위에 밝은 다리/몸통이 (gap 없이) 있었는가
        hoof = 0              # 밝은 구조 아래로 이어진 어두운 픽셀 수(발굽 카운터)
        for y in range(shadow_top, y1):
            r, g, b, a = px[x, y]
            if a == 0:
                bright_above = False  # 투명 간격 → 다리 연속 끊김
                hoof = 0
                continue
            mx = max(r, g, b)
            mn = min(r, g, b)
            v = mx / 255.0
            s = 0.0 if mx == 0 else (mx - mn) / mx
            is_shadow_color = v < 0.45 and s < 0.6 and b >= r - 8
            if v >= 0.5:
                bright_above = True    # 밝은 다리/몸통
                hoof = 0
            elif is_shadow_color:
                # 밝은 구조 바로 아래 hoof_margin px까지만 발굽으로 보호, 초과는 그림자.
                if bright_above and hoof < hoof_margin:
                    hoof += 1
                else:
                    px[x, y] = (r, g, b, 0)
                    n_shadow += 1
            else:
                bright_above = True    # 어둡지만 그림자색 아님(발굽 갈색 등) = 구조
                hoof = 0

    n_blobs = _keep_largest_component(px, W, H)
    im.save(dst)
    print(f"  {src.split('/')[-1]} -> {dst.split('/')[-1]} "
          f"(그림자px {n_shadow}, 고립성분 제거 {n_blobs})")


def _keep_largest_component(px, W, H):
    """알파>10 4-이웃 연결성분 중 최대만 남기고 나머지 알파=0. 제거한 성분 수 반환."""
    labels = [[0] * W for _ in range(H)]
    cur = 0
    sizes = [0]
    for sy in range(H):
        for sx in range(W):
            if px[sx, sy][3] <= 10 or labels[sy][sx] != 0:
                continue
            cur += 1
            cnt = 0
            stack = [(sy, sx)]
            labels[sy][sx] = cur
            while stack:
                y, x = stack.pop()
                cnt += 1
                if y + 1 < H and labels[y + 1][x] == 0 and px[x, y + 1][3] > 10:
                    labels[y + 1][x] = cur; stack.append((y + 1, x))
                if y - 1 >= 0 and labels[y - 1][x] == 0 and px[x, y - 1][3] > 10:
                    labels[y - 1][x] = cur; stack.append((y - 1, x))
                if x + 1 < W and labels[y][x + 1] == 0 and px[x + 1, y][3] > 10:
                    labels[y][x + 1] = cur; stack.append((y, x + 1))
                if x - 1 >= 0 and labels[y][x - 1] == 0 and px[x - 1, y][3] > 10:
                    labels[y][x - 1] = cur; stack.append((y, x - 1))
            sizes.append(cnt)
    if cur <= 1:
        return 0
    best = 1
    for i in range(1, cur + 1):
        if sizes[i] > sizes[best]:
            best = i
    for y in range(H):
        for x in range(W):
            lb = labels[y][x]
            if lb != 0 and lb != best:
                r, g, b, a = px[x, y]
                px[x, y] = (r, g, b, 0)
    return cur - 1


if __name__ == "__main__":
    main()
