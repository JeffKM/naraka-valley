#!/usr/bin/env python3
# ★[S4-T9 / ADR-0062 결정 10] 저승 숲·미혹의 숲 아트 패스 1 후처리 글루
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab 생성 raw → 게임 규격(발치 flush · 하드 알파 · 저승 muted · 2px 청키)로 굳힌다.
#
# ★지형은 여기서 굽지 않는다 — 구역 톤은 `main._g16_ground_tone`(그리기 시점 곱셈)이 든다.
#   파생 필드 PNG를 구워 `_g16_field`만 갈아끼우는 1차 안은 **폐기**했다(재시도 금지):
#   `_wang_tiles`(잔디↔흙 전환 타일)가 전역 1회 캐시라 구역 오염이 나고, 물가 shore 합성·길 갓길이
#   각자 base를 직접 읽어 **경계에만 원톤이 남는다**(연못 둘레·길 옆이 형광 tan으로 뜬 실측).
#
# 규격 근거: [asset-ruleset §0.1] 2px 청키 · [§1.1] NW 광원 · [§3] 발치 앵커 · [§8.1] 하드 알파 ·
#           [§9] 저승 muted · [ADR-0050] 환경 32-native
#
# ★ 멱등: raw·단일출처에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: python3 tools/make_forest_art.py   (game/ 에서)
import colorsys
import hashlib
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROPS = os.path.join(ROOT, "assets", "props")
SS = os.path.join(ROOT, "assets", "terrain16", "single_source")

ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)


def _h(x: int, y: int, salt: int) -> int:
    return int(hashlib.md5(("%d_%d_%d" % (x, y, salt)).encode()).hexdigest()[:8], 16)


def hard_alpha(img: Image.Image) -> Image.Image:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= ALPHA_CUT else 0)
    return img


def shift(rgb, sat_mul: float, val_mul: float, hue_add: float = 0.0):
    """[§9] 저승 muted + 색상 미세 이동 — 형태는 그대로, 톤만 옮긴다."""
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    h = (h + hue_add) % 1.0
    s = max(0.0, min(1.0, s * sat_mul))
    v = max(0.0, min(1.0, v * val_mul))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))


def apply_px(img: Image.Image, fn) -> None:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if len(p) == 4:
                if p[3] < ALPHA_CUT:
                    px[x, y] = (0, 0, 0, 0)
                    continue
                px[x, y] = fn(p[:3]) + (255,)
            else:
                px[x, y] = fn(p)


# ── ② 프롭 규격화 ─────────────────────────────────────────────────────────────
def chunk_ratio(img: Image.Image) -> float:
    """[§0.1] 2×2 블록 비율 — 0.95↑면 2px 청키, 0.70↓면 1px 고움(재청키화 대상).
    ★격자에 **정렬해서**(stride 2) 센다 — tools/enforce_chunk.block2_ratio와 같은 척도여야
    두 글루가 같은 자산을 같게 판정한다(stride 1로 세면 완벽한 청키도 ~0.27로 나온다)."""
    px = img.load()
    w, h = img.size
    same = 0
    tot = 0
    for y in range(0, h - 1, 2):
        for x in range(0, w - 1, 2):
            if px[x, y][3] < ALPHA_CUT:
                continue
            tot += 1
            if (px[x + 1, y] == px[x, y] and px[x, y + 1] == px[x, y]
                    and px[x + 1, y + 1] == px[x, y]):
                same += 1
    return same / tot if tot else 1.0


def chunkify(img: Image.Image) -> Image.Image:
    """÷2(BOX 평균) → 알파 임계 → ×2 nearest. 이미 청키하면 건너뛴다(이중 청키 방지)."""
    if chunk_ratio(img) >= 0.70:
        return img
    w, h = img.size
    small = img.resize((max(1, w // 2), max(1, h // 2)), Image.BOX)
    return hard_alpha(small.resize((w, h), Image.NEAREST).convert("RGBA"))


def foot_flush(raw: Image.Image, w: int, h: int, size: tuple = ()) -> Image.Image:
    """[§3] 야외 바닥 프롭 = 발치 기준. `_draw_props_for`가 art 하단을 발치로 잡으므로
    프레임 바닥에 붙이지 않으면 접지 그림자·Y-split이 통째로 공중에 뜬다.
    size=(w,h)를 주면 그 치수로 강제한다(비율을 깨서라도 실루엣을 잡는 경우 — 낮고 넓은 덤불)."""
    box = raw.getbbox()
    body = raw.crop(box)
    if size:
        body = body.resize(size, Image.NEAREST)
    if body.width > w or body.height > h:
        k = min(w / body.width, h / body.height)
        body = body.resize((max(1, int(body.width * k)), max(1, int(body.height * k))), Image.NEAREST)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(body, ((w - body.width) // 2, h - body.height))
    return hard_alpha(out)


# 파일명 → (프레임 w, h, 콘텐츠 강제 치수(()=원본비), 채도, 명도)
PROP_SPECS = [
    # ── 나무 3폼 + 그루터기 ──────────────────────────────────────────────────
    # 데이터 5단계 → 아트 3폼 매핑은 스펙카드(gemini-regen-batch §14)에 잠금:
    #   stage1~2=묘목(32×32) · stage3~4=중간(64×64) · stage5=성숙(64×128) · stump=그루터기(32×32).
    # ★세 폼의 **키 계단**이 그 매핑의 유일한 시각 근거다 — 프레임이 1/2/4칸으로 갈리므로
    #   한 화면에 셋이 서면 "자라는 중"이 읽힌다. 치수를 흔들면 계단이 무너진다.
    ("tree_forest_dark", 64, 128, (), 0.78, 0.86),
    ("tree_mid", 64, 64, (), 0.80, 0.88),
    ("tree_sapling", 32, 32, (20, 22), 0.84, 0.92),
    ("tree_stump", 32, 32, (22, 16), 0.86, 0.92),     # 보통 그루터기 = 낮고 작다(큰 그루터기와 대조)
    # ── ★채집 덤불 ───────────────────────────────────────────────────────────
    # 능선 SOLID 덤불(bush.png 64×64 — 어둡고 넓은 **톱니** dome)과 **다른 실루엣**이어야 한다.
    # 같은 그림이면 "저 벽도 흔들 수 있나"로 읽혀 §2-2 역할 분리가 시각에서 무너진다(owner 큐).
    # 분리 축 셋: ㉠크기 32×32 = 1/4 면적 ㉡실루엣 = 매끈한 **낮고 넓은** 반구(28×18로 눌러 못 박는다)
    #            ㉢톤 = 한 단 밝은 초록(능선 덤불은 어둡다).
    ("forest_berry_bush", 32, 32, (28, 18), 0.82, 0.98),
    # 이끼 — 성숙목 밑동에 얹는 **납작한 얼룩**(부피 있는 덩이면 덤불과 헷갈린다)
    ("forest_moss", 32, 32, (24, 12), 0.88, 0.96),
    # ── 저승 숲 장식 ─────────────────────────────────────────────────────────
    ("forest_mushroom", 32, 32, (20, 18), 0.86, 0.94),
    ("forest_fern", 32, 32, (26, 20), 0.80, 0.90),
    # ── 미혹의 숲 장식 ───────────────────────────────────────────────────────
    ("mihok_dead_snag", 64, 96, (), 0.72, 0.84),
    ("mihok_rare_mushroom", 32, 32, (18, 22), 1.00, 1.00),  # 발광종 — 유일하게 톤을 안 죽인다(§17 pop)
    # ── 큰 장애물(도끼 티어 게이트) ───────────────────────────────────────────
    # 보통 그루터기와의 대비가 곧 "이건 도끼 티어가 필요하다"의 신호라 **칸을 꽉 채운다**(32×28/32×24).
    ("large_stump", 32, 32, (32, 28), 0.80, 0.86),
    ("large_log", 32, 32, (32, 24), 0.78, 0.84),
]


def build_props() -> None:
    for name, w, h, size, sat, val in PROP_SPECS:
        raw_path = os.path.join(PROPS, name + "_raw.png")
        if not os.path.exists(raw_path):
            print("  ⏭ %s — raw 없음(건너뜀)" % name)
            continue
        raw = Image.open(raw_path).convert("RGBA")
        img = foot_flush(raw, w, h, size=size)
        apply_px(img, lambda c, s=sat, v=val: shift(c, s, v))
        before = chunk_ratio(img)
        img = chunkify(img)
        img.save(os.path.join(PROPS, name + ".png"))
        print("  %s.png %dx%d (청키 %.2f→%.2f · 채도×%.2f 명도×%.2f)"
              % (name, w, h, before, chunk_ratio(img), sat, val))


if __name__ == "__main__":
    build_props()
