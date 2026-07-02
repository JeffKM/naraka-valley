#!/usr/bin/env python3
# ★캐논 청크 단위 강제(asset-ruleset §0.1, owner 잠금 2026-07-01).
# "1 논리px = 2 화면px(2px 블록)"을 전 에셋 공통으로 강제한다. 1px(고운) 자산만 골라
# ÷2(BOX 평균)→알파 임계→×2 nearest로 청키화한다(이미 2px인 것은 건너뜀 — 이중청키 방지).
#
# 사용:
#   python3 tools/enforce_chunk.py            # dry-run(측정·대상 보고만)
#   python3 tools/enforce_chunk.py --apply    # 실제 청키화(제자리 덮어쓰기)
#   python3 tools/enforce_chunk.py --apply assets/props   # 특정 경로만
import sys, os, glob
from PIL import Image

CHUNK_THRESHOLD = 0.70   # 2x2 블록 비율 < 0.70 이면 1px(고움) → 청키화 대상
# ★캐릭터 제외(owner 결정 2026-07-02): 2px 청키화가 인게임 캐릭터 형태를 뭉개
#   "형태가 안 보일 정도로 흐려짐" → 캐릭터는 선명도 우선으로 청크 캐논 예외.
#   타일·props·건물은 캐논 유지. 명시 경로 인자를 주면(assets/characters) 그때만 처리됨.
SCAN_DIRS = ["assets/tiles", "assets/props", "assets/buildings"]


def block2_ratio(im):
    im = im.convert("RGBA"); w, h = im.size; px = im.load(); tot = 0; blk = 0
    for y in range(0, h - 1, 2):
        for x in range(0, w - 1, 2):
            a = px[x, y]
            if a[3] == 0:
                continue
            tot += 1
            if px[x + 1, y] == a and px[x, y + 1] == a and px[x + 1, y + 1] == a:
                blk += 1
    return (blk / tot) if tot else 1.0


def threshold_alpha(im, t=128):
    px = im.load(); w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= t else 0)
    return im


def chunkify(im):
    # ÷2 BOX(색 평균) → 알파 임계 → ×2 nearest = 2px 블록. 짝수 아니면 //2 내림 후 원크기 복원.
    w, h = im.size
    half = im.resize((max(1, w // 2), max(1, h // 2)), Image.BOX).convert("RGBA")
    half = threshold_alpha(half)
    return half.resize((w, h), Image.NEAREST)


def main():
    apply = "--apply" in sys.argv
    dirs = [a for a in sys.argv[1:] if not a.startswith("--")] or SCAN_DIRS
    files = []
    for d in dirs:
        files += sorted(glob.glob(os.path.join(d, "*.png")))
    # _raw/_src 원본·아틀라스 임포트 부산물은 건너뜀(런타임 미사용). 아틀라스 본체는 포함.
    files = [f for f in files if not f.endswith("_raw.png") and "_staging" not in f]
    chunked = 0
    for f in files:
        try:
            im = Image.open(f)
        except Exception:
            continue
        r = block2_ratio(im)
        if r < CHUNK_THRESHOLD:
            tag = "CHUNK" if apply else "would-chunk"
            print(f"  [{tag}] {r*100:5.1f}%  {f}  {im.size}")
            if apply:
                chunkify(im.convert("RGBA")).save(f)
                chunked += 1
        # 이미 2px(≥threshold)는 조용히 건너뜀
    print(f"\n{'적용' if apply else 'dry-run'}: 대상 {chunked if apply else sum(1 for _ in [0])} · 스캔 {len(files)}개")
    if not apply:
        print("→ 실제 적용: python3 tools/enforce_chunk.py --apply")


if __name__ == "__main__":
    main()
