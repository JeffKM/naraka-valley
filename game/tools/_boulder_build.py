#!/usr/bin/env python3
# boulder(2×2, 64×64) 빌드 — PixelLab 128 후보 → 64-native 드롭인.
# 파이프라인(debris v6 계승): 128→64 BOX 다운스케일 · 경량 양자화(디테일 보존) · 알파 하드 ·
# 발치 y57 정렬(현행 rock.png 프레이밍 정합) · 대조 시트(잔디 위 실배율).
# 사용: python3 tools/_boulder_build.py cand_0.png cand_1.png ...
import sys
from PIL import Image, ImageEnhance

ST = "assets/props/_boulder_staging"
GRASS = "assets/terrain16/grass_field.png"
FOOT_Y = 57   # 현행 rock.png 발치선(64 프레임 내)

def build64(raw):
    # 1) 128(혹은 임의) → 64 BOX 다운스케일(청키 방지·부드러움 우선)
    im = raw.convert("RGBA").resize((64, 64), Image.BOX)
    # 2) 경량 색보정 + 양자화(디테일 보존, debris v6와 동일 강도)
    rgb = im.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(1.08)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.06)
    q = rgb.quantize(colors=28, method=Image.MEDIANCUT).convert("RGB")
    r, g, b = q.split()
    a = im.split()[3].point(lambda v: 255 if v >= 115 else 0)
    out = Image.merge("RGBA", (r, g, b, a))
    # 3) 발치 y57 정렬(가로 중앙) — 콘텐츠 bbox 기준 64 프레임에 재배치
    bb = out.getbbox()
    if bb:
        content = out.crop(bb)
        cv = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        cx = (64 - content.width) // 2
        cy = FOOT_Y - content.height   # 밑단이 FOOT_Y에 오게
        if cy < 0:
            cy = 0
        cv.alpha_composite(content, (cx, cy))
        out = cv
    return out

def contact_sheet(finals):
    grass = Image.open(GRASS).convert("RGBA")
    # 64 프레임 = 2×2 타일 → 잔디 배경 64×64
    bg = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    for ty in range(0, 64, grass.height):
        for tx in range(0, 64, grass.width):
            bg.alpha_composite(grass, (tx, ty))
    Z = 5
    cell = 64 * Z
    padx, pady, lblw = 18, 44, 20
    n = len(finals)
    W = lblw + n * (cell + padx) + padx
    H = pady + cell + pady
    from PIL import ImageDraw
    sheet = Image.new("RGBA", (W, H), (24, 22, 26, 255))
    dr = ImageDraw.Draw(sheet)
    dr.text((padx, 12), "BOULDER (2x2, 64-native) candidates", fill=(220, 210, 200, 255))
    for i, fin in enumerate(finals):
        cx = lblw + padx + i * (cell + padx)
        cy = pady
        base = bg.copy()
        base.alpha_composite(fin)
        sheet.paste(base.resize((cell, cell), Image.NEAREST), (cx, cy))
        dr.rectangle([cx, cy, cx + cell - 1, cy + cell - 1], outline=(90, 80, 70, 255))
        dr.text((cx + cell // 2 - 12, pady - 24), f"v{i+1}", fill=(200, 200, 210, 255))
    sheet.save(f"{ST}/_CONTACT_SHEET.png")
    print("contact sheet ->", f"{ST}/_CONTACT_SHEET.png")

def main():
    files = sys.argv[1:]
    finals = []
    for i, f in enumerate(files, 1):
        raw = Image.open(f)
        fin = build64(raw)
        outp = f"{ST}/boulder_v{i}.png"
        fin.save(outp)
        finals.append(fin)
        print("built", outp)
    contact_sheet(finals)

if __name__ == "__main__":
    main()
