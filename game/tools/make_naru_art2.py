#!/usr/bin/env python3
# ★[S2-T10] 나루 마을 아트 패스 2 후처리 글루 — 건물 외관·NPC 스프라이트
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab MCP 생성 raw → 게임 규격으로 굳힌다:
#   [asset-ruleset §0/§0.1] 2px 청키 그레인 · [§2] 정면 facade 남향 · [§3] bottom-center 앵커 ·
#   [§8.1] 하드 알파 · [§9] 저승 muted · [ADR-0012] 캐릭터 시트 규약(char_sprite.gd).
#
#   1) store_ext        192×160  만물상 외관 — STORE_EXT_RECT(6×5)에 1:1
#   2) village_house_a/b 128×128  주민 집 — 기존 한옥(miho_house_ext) 지붕 색상만 재도색 2종
#      ([residents.md] "기존 집 에셋 재사용 → 본체 제작 시 재도색")
#   3) village_house_c  128×128 / village_house_wide 160×136  초가집 — 4칸/5칸 폭 2종
#   4) neo              80×320   네오 정지 4방향 시트(1열 idle — 상주 NPC)
#   5) mochi            80×320   모찌 정지 4방향 시트(슬라임 — 얼굴만 방향 이동)
#
# ★ 멱등: raw에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: python3 tools/make_naru_art2.py   (game/ 에서)
import colorsys
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "assets", "buildings")
CHARS = os.path.join(ROOT, "assets", "characters")

TILE = 32          # [ADR-0050] 32-native
ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)

# 캐릭터 시트 규약(char_sprite.gd FRAME=80·FOOT_OFFSET_Y=-36).
FRAME = 80
ROW_DIRS = ["south", "north", "east", "west"]   # 행 순서 = down/up/right/left
# ★ 발치선 = 74. char_sprite 기하학상 '정확한' 값은 76이지만, 출하된 캐스트 5종이 전부 74에
#   서 있다(mel·okja·bana·miho·player 실측). 신규 NPC가 옆에 서면 2px 어긋나 보이므로
#   기하학적 정답이 아니라 **캐스트 실측치**에 맞춘다(나란히 섰을 때의 정합이 우선).
FOOT_Y = 74


def hard_alpha(img: Image.Image) -> Image.Image:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= ALPHA_CUT else 0)
    return img


def mute(rgb, sat_mul: float, val_mul: float):
    """[§9] 저승 muted — 채도·명도만 눌러 형태·정체색은 보존."""
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    s = max(0.0, min(1.0, s * sat_mul))
    v = max(0.0, min(1.0, v * val_mul))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))


def apply_px(img: Image.Image, fn) -> Image.Image:
    """불투명 픽셀마다 fn((r,g,b)) -> (r,g,b) 적용."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            nr, ng, nb = fn((r, g, b))
            px[x, y] = (nr, ng, nb, a)
    return img


# ── facade: 풋프린트 정합 ────────────────────────────────────────────────────
# 기존 건물 6종(house·cafe·storehouse·barn·coop·mel/miho/bana house)이 전부 **아트 폭 =
# footprint 폭 정확히**, 아트 높이 ≥ footprint 높이를 지킨다(_blit_facade_anchored가 bottom-center
# 앵커라 폭이 어긋나면 건물이 WALL 박스보다 좁거나 넓게 앉는다). PixelLab은 캔버스 대비 콘텐츠
# 여백 비율이 생성마다 달라(0.80~0.96 실측) 캔버스 크기로는 폭을 못 맞춘다.
# → **half-res(16논리px) 격자에서 NEAREST로 목표 크기에 맞춘 뒤 ×2**. ×2가 마지막 연산이라
#   모든 픽셀이 2×2 블록이 되어 [§0.1] 청키 규약을 정의상 만족한다.
def fit_facade(raw: Image.Image, tiles_w: int, tiles_h: int) -> Image.Image:
    box = raw.getbbox()
    content = raw.crop(box)
    hw = tiles_w * TILE // 2                      # 목표 half-res 폭
    hh = round(content.height * hw / content.width)
    hh = max(hh, tiles_h * TILE // 2)             # 아트 높이 ≥ footprint 높이(지붕은 위로 솟음)
    small = content.resize((hw, hh), Image.NEAREST)
    return hard_alpha(small.resize((hw * 2, hh * 2), Image.NEAREST).convert("RGBA"))


def build_store():
    raw = Image.open(os.path.join(BUILD, "store_ext_raw.png")).convert("RGBA")
    img = fit_facade(raw, 6, 5)                   # STORE_EXT_RECT = Rect2i(58,14,6,5)
    apply_px(img, lambda c: mute(c, 0.88, 0.96))  # [§9] 저승 muted 소폭
    out = os.path.join(BUILD, "store_ext.png")
    img.save(out)
    print("  store_ext.png %dx%d" % img.size)


def build_cottage():
    raw = Image.open(os.path.join(BUILD, "village_cottage_raw.png")).convert("RGBA")
    for name, tw, th in [("village_house_c", 4, 4), ("village_house_wide", 5, 4)]:
        img = fit_facade(raw, tw, th)
        apply_px(img, lambda c: mute(c, 0.88, 0.96))
        img.save(os.path.join(BUILD, name + ".png"))
        print("  %s.png %dx%d" % ((name,) + img.size))


# ── 주민 집 재도색 ───────────────────────────────────────────────────────────
# [residents.md] "기존 집 에셋 재사용 → 본체 제작 시 외관 재도색". 원본 = 미호 한옥(128×128,
# 4×4 주민 집 풋프린트와 1:1). 지붕이 화면의 대부분이라 **지붕 색상(hue)만** 돌리면 같은
# 실루엣이 다른 집으로 읽힌다(형태 재생성 0 = ADR-0014 점진 추가 비용 방어).
# 원본 지붕 = 청색 계열 h≈212~250(실측). 그 밴드만 목표 hue로 옮기고 명도·채도는 보존한다.
ROOF_H_LO, ROOF_H_HI = 195.0, 255.0    # 재도색 대상 hue 밴드(도) — 지붕·외곽선 남색
GOURD_H_LO, GOURD_H_HI = 5.0, 30.0     # 처마밑 호박 주황(변주마다 다른 작물로)


def _repaint(rgb, roof_h, roof_s, gourd_h):
    """★ 두 밴드를 **원본 hue 기준으로 한 번에** 가른다. 순차 적용하면 지붕을 옮긴 결과 hue가
    다음 밴드(호박 주황 5~30)에 다시 걸려 두 번 돌아간다(테라코타 지붕이 올리브로 뭉개짐)."""
    r, g, b = (c / 255.0 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 0.25:
        return rgb
    deg = h * 360.0
    if ROOF_H_LO <= deg <= ROOF_H_HI:
        target, s = roof_h, max(0.0, min(1.0, s * roof_s))
    elif GOURD_H_LO <= deg <= GOURD_H_HI:
        target = gourd_h
    else:
        return rgb
    r, g, b = colorsys.hsv_to_rgb(target / 360.0, s, v)
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))


def build_village_houses():
    src = Image.open(os.path.join(BUILD, "miho_house_ext.png")).convert("RGBA")
    # (파일명, 지붕 hue, 지붕 채도배율, 호박 hue)
    variants = [
        ("village_house_a", 18.0, 0.75, 48.0),    # 따뜻한 테라코타 기와 · 노란 박
        ("village_house_b", 150.0, 0.50, 95.0),   # 이끼 청록 기와 · 초록 박
    ]
    for name, roof_h, roof_s, gourd_h in variants:
        img = src.copy()
        apply_px(img, lambda c, rh=roof_h, rs=roof_s, gh=gourd_h: _repaint(c, rh, rs, gh))
        # ★ 원본 한옥은 128 캔버스 안에서 콘텐츠가 95×86뿐이다(투명 여백이 넓다) — 그대로 쓰면
        #   4×4 풋프린트 위에 3칸짜리 인형집이 앉아 건물 발치 맨흙 패드가 훤히 드러난다(덤프 확인).
        #   초가집과 같은 fit_facade로 풋프린트를 꽉 채운다.
        img = fit_facade(img, 4, 4)
        img.save(os.path.join(BUILD, name + ".png"))
        print("  %s.png %dx%d" % ((name,) + img.size))


# ── 캐릭터 시트 ─────────────────────────────────────────────────────────────
def place_frame(content: Image.Image) -> Image.Image:
    """콘텐츠를 80×80 프레임에 발치정렬(가로중앙)."""
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    ox = (FRAME - content.width) // 2
    oy = max(0, FOOT_Y - content.height)
    frame.paste(content, (ox, oy), content)
    return frame


def save_sheet(dir_frames: dict, out_path: str):
    """{방향: [프레임…]} → 시트 PNG(행=방향, 열=프레임)."""
    cols = max(len(v) for v in dir_frames.values())
    sheet = Image.new("RGBA", (FRAME * cols, FRAME * len(ROW_DIRS)), (0, 0, 0, 0))
    for r, d in enumerate(ROW_DIRS):
        for c, fr in enumerate(dir_frames[d]):
            sheet.paste(fr, (c * FRAME, r * FRAME), fr)
    sheet.save(out_path)
    print("  %s %dx%d" % (os.path.basename(out_path), sheet.width, sheet.height))


def interior_mask(img: Image.Image):
    """불투명 픽셀 중 4이웃이 전부 불투명인 것(=외곽선이 아닌 내부)의 좌표 집합."""
    px = img.load()
    w, h = img.size
    inner = set()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            ok = True
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny][3] == 0:
                    ok = False
                    break
            if ok:
                inner.add((x, y))
    return inner


# 네오 = [residents.md §2.2] 백자 오프화이트 오토마타 · 머리 위 태엽 키 · 이모티콘 눈.
# PixelLab standard가 살빛 민머리로 구웠다(3회 시도 전부) — [p2.0-spike §10.11]의 교훈
# ("볼홍조·안경·코 같은 face 디테일은 standard가 baked → 프롬프트보다 후처리가 확실") 대로
# 후처리로 정체성을 맞춘다: ① 살빛 → 백자(차가운 오프화이트) ② 머리 위 태엽 키 스탬프.
PORCELAIN = (233, 231, 226)     # 백자 본색(neo.gd 그레이박스 0.86/0.84/0.80과 같은 계열)
BRASS = (150, 122, 62)          # 태엽 키 놋쇠
BRASS_HI = (196, 166, 92)       # 키 NW 하이라이트


def _to_porcelain(c):
    """따뜻한 살빛(h 15~55·채도 중간)만 백자로. 검정 옷·놋쇠 단추는 건드리지 않는다."""
    r, g, b = c
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    if not (10.0 <= h * 360.0 <= 60.0) or s < 0.06 or v < 0.45:
        return c
    # 명도 계조는 보존하고 색상만 백자 쪽으로(차가운 회백) — 계단식 음영(§1)이 살아 있게.
    k = v
    return (int(PORCELAIN[0] * k + 0.5), int(PORCELAIN[1] * k + 0.5), int(PORCELAIN[2] * k + 0.5))


def _stamp_windup_key(img: Image.Image):
    """머리 꼭대기 중앙에 태엽 키(세로 줄기 + 가로 챙)를 얹는다 — neo.gd 그레이박스와 같은 모티프.
    ★ 2px 청키 그레인([§0.1])을 지키려 전부 2px 블록으로 찍는다."""
    box = img.getbbox()
    if box is None:
        return img
    px = img.load()
    top = box[1]
    # 머리 꼭대기 행의 불투명 x 범위 중앙을 키 위치로(방향마다 머리가 좌우로 치우쳐도 따라간다)
    xs = [x for x in range(box[0], box[2]) if px[x, top][3] != 0]
    if not xs:
        return img
    cx = (min(xs) + max(xs)) // 2

    def blk(x, y, col):
        for dy in range(2):
            for dx in range(2):
                if 0 <= x + dx < img.width and 0 <= y + dy < img.height:
                    px[x + dx, y + dy] = (col[0], col[1], col[2], 255)
    cx -= cx % 2
    blk(cx, top - 4, BRASS)          # 줄기(위)
    blk(cx, top - 2, BRASS)          # 줄기(아래 — 머리에 닿음)
    blk(cx - 2, top - 6, BRASS_HI)   # 가로 챙 좌(NW 하이라이트)
    blk(cx + 2, top - 6, BRASS)      # 가로 챙 우
    blk(cx, top - 6, BRASS_HI)       # 가로 챙 중앙
    return img


def build_neo():
    frames = {}
    for d in ROW_DIRS:
        raw = Image.open(os.path.join(CHARS, "neo_raw", d + ".png")).convert("RGBA")
        hard_alpha(raw)
        apply_px(raw, _to_porcelain)
        content = raw.crop(raw.getbbox())
        # 키를 얹을 여백 6px을 위에 붙여 놓고 스탬프(콘텐츠 상단에 붙어 있어 크롭에 안 잘리게)
        pad = Image.new("RGBA", (content.width, content.height + 6), (0, 0, 0, 0))
        pad.paste(content, (0, 6), content)
        _stamp_windup_key(pad)
        frames[d] = [place_frame(pad.crop(pad.getbbox()))]
    save_sheet(frames, os.path.join(CHARS, "neo.png"))


# 모찌 = [residents.md 비인간 §1] 투명 에메랄드 슬라임 · 도트 눈입 · 머리 위 찹쌀떡.
# PixelLab은 남향 한 장만 만들었다(비인간이라 create_character 휴머노이드 골격이 안 맞는다).
# 방향은 **얼굴만 옮겨** 만든다 — 덩이 실루엣은 방향에 무관하고(슬라임), NW 광원 하이라이트·
# 찹쌀떡은 제자리에 둬야 [§1] 광원 일관성이 깨지지 않는다(좌우 미러 금지의 이유).
# 얼굴이 있는 띠(콘텐츠 크기 대비 비율) — 덩이 아래-가운데. 전역으로 "어두운 픽셀"을 잡으면
# 덩이 내부의 윤곽·음영 조각(찹쌀떡 밑그늘·밑동 주름)까지 얼굴로 오인해 방향 변형이 깨진다.
FACE_BAND = (0.20, 0.50, 0.80, 0.80)   # (x0, y0, x1, y1) 비율


def _face_pixels(img: Image.Image):
    """얼굴 띠 안의 얼굴 픽셀 = 어두운 점(눈·입) + 분홍 볼홍조.
    어두운 점은 내부(외곽선 아님)만 — 볼홍조는 외곽선에 닿아 있어도 잡는다(안 그러면 뒷모습에
    분홍 점만 남는다)."""
    px = img.load()
    inner = interior_mask(img)
    w, h = img.size
    x0, y0 = int(w * FACE_BAND[0]), int(h * FACE_BAND[1])
    x1, y1 = int(w * FACE_BAND[2]), int(h * FACE_BAND[3])
    out = []
    for y in range(y0, min(y1 + 1, h)):
        for x in range(x0, min(x1 + 1, w)):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if r > 140 and r - g > 50 and b > g:                    # 볼홍조
                out.append((x, y, (r, g, b)))
            elif max(r, g, b) < 110 and (x, y) in inner:            # 눈·입
                out.append((x, y, (r, g, b)))
    return out


def _move_face(img: Image.Image, dx: int, hide: bool = False) -> Image.Image:
    """얼굴 픽셀을 지우고(주변 몸 색으로 메움) dx만큼 옮겨 다시 찍는다. hide=True면 안 찍는다(뒷모습)."""
    img = img.copy()
    px = img.load()
    face = _face_pixels(img)
    if not face:
        return img
    for (x, y, _c) in face:                       # 지우기 = 바로 위 몸 픽셀 색으로
        fill = None
        for dy in range(1, 6):
            if y - dy >= 0 and px[x, y - dy][3] != 0 and max(px[x, y - dy][:3]) >= 110:
                fill = px[x, y - dy][:3]
                break
        if fill is not None:
            px[x, y] = (fill[0], fill[1], fill[2], 255)
    if hide:
        return img
    for (x, y, c) in face:                        # 옮겨 찍기(몸 안에 남는 것만)
        nx = x + dx
        if 0 <= nx < img.width and px[nx, y][3] != 0:
            px[nx, y] = (c[0], c[1], c[2], 255)
    return img


def build_mochi():
    raw = Image.open(os.path.join(CHARS, "mochi_raw.png")).convert("RGBA")
    hard_alpha(raw)
    apply_px(raw, lambda c: mute(c, 0.92, 0.98))   # [§9] 저승 muted 소폭
    south = raw.crop(raw.getbbox())
    frames = {
        "south": [place_frame(south)],
        "north": [place_frame(_move_face(south, 0, hide=True))],   # 뒷모습 = 얼굴 없음
        "east": [place_frame(_move_face(south, 3))],
        "west": [place_frame(_move_face(south, -3))],
    }
    save_sheet(frames, os.path.join(CHARS, "mochi.png"))


# 네오 대화 초상화 — [portrait-spec-card.md] §4 출력 규격 320×320 투명 PNG.
# PixelLab `create_portrait_character(character_to_portrait)`가 위 neo 스프라이트에서 뽑은 160²
# 버스트를 ×2 nearest로 굳힌다(슬롯이 186px라 320이 필요·[§0.1] 청키 유지).
# ⚠️ 기존 4인(미호·멜·바나·옥자) 초상화는 owner-Gemini 소프트 일러스트라 **화풍이 다르다** —
#    이건 "얼굴 없음"을 메우는 도트 스톱갭이고, 정식 교체는 스펙 카드 큐로 넘긴다.
PORTRAITS = os.path.join(ROOT, "assets", "portraits")


def build_neo_portrait():
    raw = Image.open(os.path.join(PORTRAITS, "neo_raw.png")).convert("RGBA")
    hard_alpha(raw)
    img = raw.resize((raw.width * 2, raw.height * 2), Image.NEAREST)
    img.save(os.path.join(PORTRAITS, "neo.png"))
    print("  neo.png(portrait) %dx%d" % img.size)


def main():
    print("[S2-T10] 나루 아트 패스 2 후처리")
    build_store()
    build_cottage()
    build_village_houses()
    build_neo()
    build_mochi()
    build_neo_portrait()
    print("완료 — `godot --headless --import`로 임포트 캐시 갱신 필요")


if __name__ == "__main__":
    main()
