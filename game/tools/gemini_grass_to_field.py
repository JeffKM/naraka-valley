#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
# Gemini 지형 텍스처 → 실험 필드 변환 글루 (ADR-0001 허용 = 에셋 정리/임포트 글루).
#
# owner가 Gemini로 뽑은 고해상(2048²) 지형 필드 텍스처를 16px 룩 실험 하네스가
# 쓰는 저해상 "필드 타일"로 변환한다:
#   1) Gemini 우하단 sparkle 워터마크 제거(고정 박스 → 좌상단 clean 패치 덮기).
#      seamless 텍스처라 코너 내용이 유사하고, 바깥 가장자리 행은 손대지 않아 타일링 보존.
#   2) FIELD px로 BOX(area) 다운스케일 → 청키 그레인(2026-07-04 grill: 필드 128 채택).
#
# 입력:  game/assets/_staging_tile16/raw/{grass_a,grass_b,grass_c,dirt}.png  (원본, 워터마크 有)
# 출력:  game/assets/_staging_tile16/{grass_a,grass_b,grass_c,dirt}_field.png (128², 워터마크 제거)
# 하네스는 grass_a_field + dirt_field 만 사용(Q5: b/c 클럼프는 스캐터 프롭 별도).
#
# 사용:  cd game && python3 tools/gemini_grass_to_field.py
# ─────────────────────────────────────────────────────────────────────────────
import os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
STAGE = os.path.normpath(os.path.join(HERE, "..", "assets", "_staging_tile16"))
RAW = os.path.join(STAGE, "raw")

FIELD = 128                       # 다운스케일 목표(grill 확정 청키감)
NAMES = ["grass_a", "grass_b", "grass_c", "dirt"]
# Gemini sparkle 고정 박스(2048² 기준, 우하단). 넉넉히 잡아 4각별 전체 커버.
WM = (1680, 1695, 1920, 1935)

def dewatermark(im: Image.Image) -> Image.Image:
    W, H = im.size
    # 좌표를 원본 비율로 스케일(항상 2048이 아닐 수 있으니 방어)
    sx = W / 2048.0; sy = H / 2048.0
    bx0, by0, bx1, by1 = (int(WM[0]*sx), int(WM[1]*sy), int(WM[2]*sx), int(WM[3]*sy))
    bw, bh = bx1 - bx0, by1 - by0
    # clean 소스 = 좌상단(민무늬). seamless라 코너 유사.
    ox, oy = int(W*0.03), int(H*0.03)
    patch = im.crop((ox, oy, ox + bw, oy + bh))
    im = im.copy()
    im.paste(patch, (bx0, by0))
    return im

def main():
    if not os.path.isdir(RAW):
        print(f"✗ 원본 폴더 없음: {RAW}\n  owner가 Gemini 원본 4장을 raw/{{grass_a,grass_b,grass_c,dirt}}.png 로 저장하세요.")
        sys.exit(1)
    done = []
    for name in NAMES:
        src = os.path.join(RAW, name + ".png")
        if not os.path.exists(src):
            print(f"  · {name}: 원본 없음(건너뜀)")
            continue
        im = Image.open(src).convert("RGB")
        # 큰 Gemini raw(2048급)만 워터마크 제거. 작은 사전제작 타일(<512)은 clean 취급 → 스킵.
        if im.size[0] >= 512:
            im = dewatermark(im)
        # 필드로: 다운스케일=BOX(area·청키), 업스케일=NEAREST(픽셀 보존)
        method = Image.BOX if im.size[0] >= FIELD else Image.NEAREST
        field = im.resize((FIELD, FIELD), method)
        # ※ make_seamless(평균 블렌드)는 크리스프 픽셀을 뭉개고 미러 대칭 무늬를 만들어 폐기.
        #   타일링 주기 반복감은 seam이 아니라 *클럼프 스캐터*(Q5)로 깬다(home16_dump).
        out = os.path.join(STAGE, name + "_field.png")
        field.save(out)
        done.append(f"{name}({im.size[0]}²→{FIELD}²)")
        # ★ 실게임 Wang 베이스 타일 = 자기 타일링되는 32px 청키 소프트 타일.
        #   128 필드는 128주기 seamless → BOX÷8=16px(여전히 seamless) → NEAREST×2=32px 청키.
        if name in ("grass_a", "dirt"):
            base16 = field.resize((16, 16), Image.BOX)          # seamless 유지
            base32 = base16.resize((32, 32), Image.NEAREST)     # 청키(16 유효) 32px 타일
            base32.save(os.path.join(STAGE, name + "_base32.png"))
            done[-1] += "+base32"
    print("✅ 변환:", ", ".join(done) if done else "(없음)")
    print("   → 하네스: cd game && ./run_tile16.sh")

if __name__ == "__main__":
    main()
