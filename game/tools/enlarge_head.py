#!/usr/bin/env python3
"""v3 도트의 머리(얼굴) 부분만 키워 얼굴을 또렷하게 (글루, ADR-0001 허용 색보정/리터치).

ADR-0003은 표정을 초상화로 살리지만, 사용자 요청 = "v3 도트는 유지하되 얼굴만 좀더 뚜렷".
v3는 머리 비율을 못 바꾸므로 *생성 후* 시트에서 콘텐츠 상단(머리)만 배율 확대해 다시 얹는다.
원본 v3 픽셀을 그대로 키우는 거라 v3 룩을 유지하면서 얼굴 픽셀 수만 늘린다(바블헤드化).

★ 확대는 NEAREST(도트 보존). LANCZOS면 머리만 흐려져 또렷한 몸과 "따로 노는" 느낌이 난다
(사용자 피드백 — 얼굴도 몸처럼 또렷해야 함).

사용: enlarge_head.py <in_sheet.png> <out_sheet.png> [factor] [head_ratio]
  factor    : 머리 배율(기본 1.35)
  head_ratio: 콘텐츠 높이 중 머리로 볼 상단 비율(기본 0.46 = ~2.5등신 치비)
시트 규약: 48×48 프레임, 행=방향, 열=프레임. 발치 y≈FOOT_Y 유지.
"""
from __future__ import annotations
import sys
from PIL import Image

FRAME = 48
FOOT_Y = 40


def enlarge_frame(cell: Image.Image, factor: float, head_ratio: float) -> Image.Image:
    bb = cell.getbbox()
    if bb is None:
        return cell
    content = cell.crop(bb)
    cw, ch = content.size
    head_h = max(1, round(ch * head_ratio))
    head = content.crop((0, 0, cw, head_h))
    body = content.crop((0, head_h, cw, ch))
    bw, bh = body.size

    shw, shh = max(1, round(cw * factor)), max(1, round(head_h * factor))
    head_big = head.resize((shw, shh), Image.NEAREST)   # 도트 보존(몸과 같은 크리스프)

    # 합성 캔버스: 가로 = 머리/몸 중 넓은 쪽, 세로 = 키운머리 + 몸(목 2px 겹침)
    overlap = 2
    total_w = max(shw, bw)
    total_h = shh + bh - overlap
    canvas = Image.new("RGBA", (total_w, total_h), (0, 0, 0, 0))
    cx = total_w // 2
    # 몸: 아래쪽, 가로중앙
    canvas.alpha_composite(body, (cx - bw // 2, shh - overlap))
    # 키운 머리: 위쪽, 가로중앙(원래 머리도 콘텐츠 가로중앙이라 정렬 유지)
    canvas.alpha_composite(head_big, (cx - shw // 2, 0))

    # 48 프레임에 발치정렬(가로중앙). 너무 크면 위가 잘릴 수 있어 그대로 둠.
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    ox = (FRAME - total_w) // 2
    oy = FOOT_Y - total_h
    frame.alpha_composite(canvas, (ox, max(0, oy)))
    return frame


def main(argv) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    src, out = argv[1], argv[2]
    factor = float(argv[3]) if len(argv) > 3 else 1.35
    head_ratio = float(argv[4]) if len(argv) > 4 else 0.46
    sheet = Image.open(src).convert("RGBA")
    cols = sheet.width // FRAME
    rows = sheet.height // FRAME
    res = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for r in range(rows):
        for c in range(cols):
            cell = sheet.crop((c * FRAME, r * FRAME, c * FRAME + FRAME, r * FRAME + FRAME))
            res.paste(enlarge_frame(cell, factor, head_ratio), (c * FRAME, r * FRAME))
    res.save(out)
    print(f"  ✓ {out}: head×{factor}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
