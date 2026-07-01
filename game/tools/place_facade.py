#!/usr/bin/env python3
# ⚠️ DEPRECATED (2026-07-02): 큰 건물 facade엔 쓰지 말 것 — ÷2 다운샘플이 선명한 기와·판자를 뭉갠다
#   (창고·축사가 본가보다 흐릿했던 근본 원인). [asset-ruleset §0] 정석대로 **half-res 네이티브 생성 →
#   `tools/facade_halfres_x2.py`(×2 nearest)** 를 쓰면 2px 캐논 + 선명도 둘 다 잡힌다. 이 스크립트는
#   ÷2 청키화가 실제로 필요한 ≤32px 소형 자산의 참고용으로만 남긴다. 상세=gemini-shed-barn-spec.md [REVISION 3].
#
# 글루(ADR-0001) — PixelLab 산출 건물 facade를 2px 청크 캐논(ADR-0036)에 맞춰 배치.
#  ① 이미 투명 배경(PixelLab) — bg strip 불필요.
#  ② 청크화: ÷2 NEAREST → 알파 임계 → ×2 NEAREST (기존 본가·창고·축사 chunkiness=1.00과 정합).
#     ★교정(2026-07-02): BOX(색 평균)는 픽셀 경계에 중간톤을 만들어 색 수를 폭발(축사 2080·창고
#     3019색)시켜 스타듀식 하드 엣지를 뭉갰다. 본가(232색·nearest ×2)와 청크 그레인이 어긋난 원인.
#     원본 src는 이미 선명(barn 136·store 222색)하므로 NEAREST 다운샘플로 색을 보존해 본가와 통일한다.
#  ③ 내용 bbox 트림(art 바텀 = 건물 밑단 — _blit_facade_anchored bottom-center 앵커의 전제).
# 사용: python3 tools/place_facade.py <src.png> <dst_ext.png>
import sys
from PIL import Image


def threshold_alpha(im, t=128):
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= t else 0)
    return im


def chunkify(im):
    w, h = im.size
    half = im.resize((max(1, w // 2), max(1, h // 2)), Image.NEAREST)
    half = threshold_alpha(half)
    return half.resize((w, h), Image.NEAREST)


def main(src, dst):
    im = Image.open(src).convert("RGBA")
    im = chunkify(im)
    bbox = im.getbbox()          # 투명 아닌 내용 경계
    if bbox:
        im = im.crop(bbox)
    im.save(dst)
    print(f"  {src} -> {dst}  ({im.size[0]}x{im.size[1]})")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
