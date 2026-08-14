#!/usr/bin/env python3
# ★[S10-T9 / ADR-0069 아트 스코프] 엔드게임 롱테일 아트 패스 후처리 글루
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab 생성 raw → 게임 규격으로 굳힌다. 규칙은 make_s9_t9_art.py·make_s9b_t9_art.py와 **같다** —
#   [asset-ruleset §8.1] 하드 알파 · [§9] 저승 muted · [ADR-0050] 32-native · [§3] 발치 앵커
# 새 규칙을 세우지 않는다(패스마다 계수가 갈리면 인벤 한 줄·한 밭에서 톤이 튄다).
#
# ★ 멱등: raw에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: python3 tools/make_s10_t9_art.py   (game/ 에서)
import colorsys
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROPS = os.path.join(ROOT, "assets", "props")
MATERIALS = os.path.join(ROOT, "assets", "materials")
UI = os.path.join(ROOT, "assets", "ui")
CHARS = os.path.join(ROOT, "assets", "characters")

TILE = 32
ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)

# [§9] 저승 muted — 계수는 선행 패스에서 그대로 물려받는다.
ICON_SAT, ICON_VAL = 0.90, 0.97     # 아이콘(§18.1 메뉴·§21.1 부적과 같은 인벤 격자)
PROP_SAT, PROP_VAL = 0.85, 0.95     # 월드 프롭(§18.2 곳간·§20.1 점괘 거울과 같은 기물 층)
CAST_SAT, CAST_VAL = 0.94, 0.98     # 캐릭터 시트(§23.0 조연 9인과 같은 층)
# 혼백관 실내 두 창구만 한 단 더 죽인다: 그 방의 기존 좌대·진열장이 draw_rect 어두운 갈색
# (0.26,0.24,0.22)이라, 생성물의 밝은 목재·이끼 초록을 그대로 두면 새 두 개만 방에서 튄다
# (§22.0이 museum_shelf에 0.62/0.90을 건 그 판단 1:1).
MUSEUM_SAT, MUSEUM_VAL = 0.68, 0.88
# 레어크로우 8종만 한 단 더: **8기가 한 밭에 나란히 선다.** 종별 소품 색(등롱 금빛·볏단 노랑·탈
# 붉음)이 생성물 그대로면 밭에서 그 둘만 형광으로 튀어 "순수 스킨"이 아니라 등급으로 읽힌다.
# 기존 프롭 허수아비(farm_scarecrow)의 어두운 갈색에 8종을 통째로 합류시킨다.
CROW_SAT, CROW_VAL = 0.74, 0.90
# 시련 게시판만 한 단 더: 생성물이 **밝은 회백 판재**로 나와(평균 명도 0.46 · 최댓값 0.95) 나락
# 진입로 곁 방의 어두운 자줏빛 암반 위에서 형광 간판처럼 떴다(T9 1차 덤프 실측). 같은 방 매대
# (0.18)와 옛 그레이박스 판(V 0.34 · 상단 하이라이트 0.48)의 값 대역으로 끌어내린다.
BOARD_SAT, BOARD_VAL = 0.85, 0.60

# ★[S10-T2] 스프링클러 티어 종색 — main `_draw_sprinklers`의 그레이박스 몸통 색이 단일 출처다
#   (청록 → 남빛 → 금빛). 아트도 **같은 세 색**을 쓰므로 티어 신호가 그레이박스와 한 글자도 안 갈린다.
#   틴트 파생인 이유: 티어 차이는 이미 **급수 범위 크기**가 말하고(4/8/24칸 하이라이트), 색은 거드는
#   신호다(그 결정의 자구). 실루엣을 셋으로 갈라 생성하면 "다른 기계 셋"으로 오독된다.
SPRINKLER_HUES = [
    colorsys.rgb_to_hsv(0.30, 0.50, 0.58)[0],   # 티어1 청록
    colorsys.rgb_to_hsv(0.28, 0.36, 0.62)[0],   # 티어2 남빛
    colorsys.rgb_to_hsv(0.62, 0.52, 0.24)[0],   # 티어3 금빛
]
TINT_SAT_FLOOR = 0.15   # 이 아래(외곽선·무채 하이라이트)는 색을 안 건드린다 — 실루엣 선이 물들면 탁해진다

CHAR_FRAME = 80
CHAR_FOOT_Y = 74                                 # 출하 캐스트 5종 실측 발치선(§23.0)
CHAR_ROWS = ["south", "north", "east", "west"]   # 행 순서 = down/up/right/left

MOUNT_FRAME = 48                                 # 먹갈기 시트 프레임(콘텐츠 최대 42×41 — 48이 최소 정수 프레임)


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
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if p[3] < ALPHA_CUT:
                px[x, y] = (0, 0, 0, 0)
                continue
            px[x, y] = fn(p[:3]) + (255,)
    return img


def hue_to(img: Image.Image, target_h: float) -> Image.Image:
    """채도가 있는 픽셀의 색상만 target_h로 갈아끼운다(명암 계단·외곽선은 불변)."""
    def fn(rgb):
        r, g, b = (c / 255.0 for c in rgb)
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if s < TINT_SAT_FLOOR:
            return rgb
        r, g, b = colorsys.hsv_to_rgb(target_h, s, v)
        return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))
    return apply_px(img, fn)


def largest_blob(img: Image.Image) -> Image.Image:
    """가장 큰 연결 성분만 남긴다 — 생성물이 캔버스 구석에 흘린 부스러기(워터마크·점)를 지운다."""
    px = img.load()
    w, h = img.size
    seen = [[False] * w for _ in range(h)]
    best: list = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or px[sx, sy][3] < ALPHA_CUT:
                continue
            stack = [(sx, sy)]
            seen[sy][sx] = True
            blob = []
            while stack:
                x, y = stack.pop()
                blob.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] \
                            and px[nx, ny][3] >= ALPHA_CUT:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            if len(blob) > len(best):
                best = blob
    keep = set(best)
    for y in range(h):
        for x in range(w):
            if (x, y) not in keep:
                px[x, y] = (0, 0, 0, 0)
    return img


def _fit(img: Image.Image, w: int, h: int, anchor: str) -> Image.Image:
    """콘텐츠를 w×h 캔버스에 다시 앉힌다. anchor='center'(아이콘) / 'bottom'(월드 프롭) / 'top'."""
    box = img.getbbox()
    if box is None:
        return img
    content = img.crop(box)
    if content.width > w or content.height > h:
        content = content.resize((min(content.width, w), min(content.height, h)), Image.NEAREST)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = (w - content.width) // 2
    if anchor == "center":
        y = (h - content.height) // 2
    elif anchor == "top":
        y = 0
    else:
        y = h - content.height
    out.paste(content, (x, max(0, y)), content)
    return out


def bake(raw_path: str, out_path: str, w: int, h: int, anchor: str,
         sat: float, val: float, crop_bottom: int = 0, tint_h=None,
         declutter: bool = False) -> None:
    """raw → 하드 알파 → (부스러기 제거) → muted → (틴트) → (밑단 crop) → w×h 앵커 재정렬."""
    if not os.path.exists(raw_path):
        print("  ! raw 없음: %s" % raw_path)
        return
    img = Image.open(raw_path).convert("RGBA")
    hard_alpha(img)
    if declutter:
        largest_blob(img)
    apply_px(img, lambda c: mute(c, sat, val))
    if tint_h is not None:
        hue_to(img, tint_h)
    if crop_bottom > 0:
        box = img.getbbox()
        if box is not None and box[3] - box[1] > crop_bottom:
            img = img.crop((box[0], box[1], box[2], box[3] - crop_bottom))
    out = _fit(img, w, h, anchor)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out.save(out_path)
    print("  %s %dx%d" % (os.path.relpath(out_path, ROOT), out.size[0], out.size[1]))


# ── 1) 혼백관 실내 두 창구 ───────────────────────────────────────────────────
# 열람대(도감)·안치대(반딧넋)는 **기증대와 한 줄에 나란히** 선다(x9·x13·x17, 전부 y46).
# ★ 높이 27인 이유: 두 창구 모두 타일 **좌상단**에 그려지고(`draw_texture(tex, cpx)`), 진행 눈금
#   막대가 타일 하단 y27..30에 깔린다. 아트가 32를 다 쓰면 눈금이 아트 위를 가로질러 "여기까지
#   찼다"가 아니라 "받침에 그은 금"으로 읽힌다 — 그레이박스 도형도 y26에서 끝났다(같은 기하).
# ★★ 상태를 굽지 않는다: 등롱 불빛(안치 수)·완주 트로피·게이트 표식·눈금은 전부 원장 파생 코드다.
def build_museum_stands() -> None:
    bake(os.path.join(PROPS, "raw", "codex_stand_raw.png"),
         os.path.join(PROPS, "codex_stand.png"), TILE, 27, "bottom",
         MUSEUM_SAT, MUSEUM_VAL)
    bake(os.path.join(PROPS, "raw", "firefly_stand_raw.png"),
         os.path.join(PROPS, "firefly_stand.png"), TILE, 27, "bottom",
         MUSEUM_SAT, MUSEUM_VAL, crop_bottom=2)


# ── 2) 저승 보부상 좌판 ──────────────────────────────────────────────────────
# 나루 다리 남단 부두 한 칸(PEDDLER_TILE). 32×48 발치 앵커라 타일 위로 16px 솟는다 —
# 야시장 매대(props/night_market.png)와 **완전 동형**이다(같은 크기·같은 앵커·같은 오버레이 결).
# ★ 보부상 본인을 좌판에 함께 굽는다: 대사 노드가 없는 임시 오버레이라 NPC 시트를 따로 두면
#   서 있기만 하는 몸이 하나 늘고, 그 몸은 스케줄도 초상도 없어 "말 없는 사람"이 된다.
# ★ 무대가 **어두운 판자 부두**라 실루엣이 어두우면 통째로 뭉개진다(1차 생성 실측 — 지게·봇짐·
#   사람이 한 덩이 검은 얼룩이 됐다. [asset-ruleset §17] dark-on-dark 위험 그 자체다). 2차는
#   **밝은 삿갓 원반 + 밝은 짚 자리**로 명도 대비를 만들어 32px에서 형태가 서게 했다.
def build_peddler_stall() -> None:
    bake(os.path.join(PROPS, "raw", "peddler_stall_v2_raw.png"),
         os.path.join(PROPS, "peddler_stall.png"), TILE, 48, "bottom",
         PROP_SAT, PROP_VAL)


# ── 3) 코지 펫 둘(삽사리 · 물그릇) ───────────────────────────────────────────
# ★★ 물그릇에 **물을 굽지 않는다.** 채운 물은 `_draw_sapsari`가 오늘 몫을 보고 절차로 덧그린다
#    (아트가 들어와도 그 표식은 남게 배선을 고쳤다) — 구우면 안 채운 날에도 차 보인다.
def build_pet() -> None:
    bake(os.path.join(PROPS, "raw", "sapsari_raw.png"),
         os.path.join(PROPS, "sapsari.png"), TILE, TILE, "bottom", PROP_SAT, PROP_VAL)
    bake(os.path.join(PROPS, "raw", "pet_bowl_raw.png"),
         os.path.join(PROPS, "pet_bowl.png"), TILE, TILE, "bottom", PROP_SAT, PROP_VAL)


# ── 4) 팬닝·결정기 둘 ────────────────────────────────────────────────────────
# ★★ 결정기 안을 **비운 채로** 굽는다: 든 보석·여문 정도·남은 일수 눈금은 전부 원장 파생 코드다
#    (`_draw_crystalariums`). 안에 결정을 구우면 빈 기계도 찬 것으로 보인다.
# ★ 팬닝 스폿은 중앙 앵커다 — 바닥에 깔리는 표식이라 발치가 없다(§11 접지 그림자도 없음: 높이 0).
def build_mine_devices() -> None:
    bake(os.path.join(PROPS, "raw", "crystalarium_v2_raw.png"),
         os.path.join(PROPS, "crystalarium.png"), TILE, TILE, "bottom", PROP_SAT, PROP_VAL)
    bake(os.path.join(PROPS, "raw", "panning_spot_raw.png"),
         os.path.join(PROPS, "panning_spot.png"), TILE, TILE, "center", PROP_SAT, PROP_VAL)


# ── 5) 화분 ──────────────────────────────────────────────────────────────────
# ★★ 심은 것을 굽지 않는다: 작물 스프라이트는 화분 입구 위로 `_draw_garden_pots`가 얹고, 젖은 흙도
#    같은 함수가 오늘 물 준 칸에만 그린다. 아트는 **마른 빈 화분**이다.
def build_garden_pot() -> None:
    bake(os.path.join(PROPS, "raw", "garden_pot_raw.png"),
         os.path.join(PROPS, "garden_pot.png"), TILE, TILE, "bottom", PROP_SAT, PROP_VAL)


# ── 6) 스프링클러 3티어(생성 1 · 틴트 파생 3) ────────────────────────────────
# 한 실루엣을 종색 셋으로 굴린다(SPRINKLER_HUES 주석 참조). 세 파일은 **월드 설치물과 인벤
# 아이콘을 공용**한다([asset-ruleset §15] "드롭/설치 아이템 = UI 아이콘 공용" — 게잡이통 선례).
def build_sprinklers() -> None:
    for i, h in enumerate(SPRINKLER_HUES):
        bake(os.path.join(PROPS, "raw", "sprinkler_raw.png"),
             os.path.join(PROPS, "sprinkler_t%d.png" % (i + 1)), TILE, TILE, "bottom",
             PROP_SAT, PROP_VAL, tint_h=h)


# ── 7) 레어크로우 8종(월드 32×64 + 인벤 아이콘 32×32 파생) ───────────────────
# ★ 8종 전부 **기존 프롭 허수아비(farm_scarecrow.png)를 init 이미지로 삼은 img2img 파생**이다 —
#   기능이 같은 순수 스킨이라 실루엣이 갈리면 안 되고(결정 4 자구), 8기가 한 밭에 나란히 선다.
# ★ 인벤 아이콘 = 월드 스프라이트의 **위 절반 crop**(생성 0). 종을 가르는 것은 머리에 얹거나 문
#   소품 한 조각이고 그건 전부 위 절반에 있다. 32²로 통째로 욱여넣으면 8종이 다 같은 갈색 막대가
#   된다(형태가 아니라 세로 압축이 정체를 지운다).
CROW_IDS = ["rarecrow_%d" % i for i in range(1, 9)]


def build_rarecrows() -> None:
    for cid in CROW_IDS:
        raw = os.path.join(PROPS, "raw", cid + "_raw.png")
        bake(raw, os.path.join(PROPS, cid + ".png"), TILE, 64, "bottom", CROW_SAT, CROW_VAL)
        world = os.path.join(PROPS, cid + ".png")
        if not os.path.exists(world):
            continue
        img = Image.open(world).convert("RGBA")
        box = img.getbbox()
        if box is None:
            continue
        head = img.crop((0, box[1], TILE, min(box[1] + TILE, img.height)))
        icon = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        icon.paste(head, (0, 0), head)
        icon.save(os.path.join(PROPS, cid + "_icon.png"))
    print("  props/rarecrow_1..8.png (32x64) + _icon.png (32x32)")


# ── 8) 명부 시련장 실내 프롭 둘 ──────────────────────────────────────────────
# ★★ 걸린 시련 쪽지·붉은 도장·시련패 잔고 눈금은 전부 원장 파생 코드다(`_draw_trial_room`).
#    게시판 판면은 **비워** 굽고, 매대 상판도 **비워** 굽는다.
# ★ 매대 높이 22 = 그레이박스 몸통(y10..32)과 같은 기하다. 잔고 패는 그 위(y8)에 뜬다.
def build_trial_room() -> None:
    bake(os.path.join(PROPS, "raw", "trial_board_v2_raw.png"),
         os.path.join(PROPS, "trial_board.png"), TILE, TILE, "bottom", BOARD_SAT, BOARD_VAL)
    bake(os.path.join(PROPS, "raw", "trial_stall_raw.png"),
         os.path.join(PROPS, "trial_stall.png"), TILE, 22, "bottom", PROP_SAT, PROP_VAL)


# ── 9) 반딧넋 ────────────────────────────────────────────────────────────────
# ★ 몸(넋 나방)만 굽는다 — 둘레 할로는 `_draw_firefly_souls`가 반투명 원으로 깐다([§8.1] 하드 알파
#   스프라이트에 번짐을 구울 수 없고, 발광은 런타임 몫이라는 §8.3의 결).
# ★ muted를 안 건다: [혼불](따뜻한 주홍)과 갈리는 **차가운 넋빛**이 정체 그 자체라, 채도를 눌러
#   회색으로 만들면 "불이 아니라 넋"이라는 색 언어(CONTEXT [반딧넋])가 사라진다. 발광 오브젝트를
#   muted에서 빼는 것은 [§9] "물·영혼빛은 저승 액센트" 예외의 이행이다.
def build_firefly_soul() -> None:
    bake(os.path.join(PROPS, "raw", "firefly_soul_raw.png"),
         os.path.join(PROPS, "firefly_soul.png"), TILE, TILE, "center", 1.0, 1.0)


# ── 10) 아이콘 3종 ───────────────────────────────────────────────────────────
# 시련패 = **엽전이 아닌 화폐**라는 것이 이 아이콘의 전부다(만물상 셸을 빌려 쓰므로 값 옆에 뜨는
# 아이콘 하나가 "이건 냥이 아니다"를 말한다 — `_trial_token_icon` 훅의 이유).
def build_icons() -> None:
    bake(os.path.join(UI, "raw", "trial_token_raw.png"),
         os.path.join(UI, "trial_token.png"), TILE, TILE, "center", ICON_SAT, ICON_VAL)
    bake(os.path.join(MATERIALS, "raw", "crystalarium_part_raw.png"),
         os.path.join(MATERIALS, "crystalarium_part.png"), TILE, TILE, "center",
         ICON_SAT, ICON_VAL)
    bake(os.path.join(MATERIALS, "raw", "mount_whistle_raw.png"),
         os.path.join(MATERIALS, "mount_whistle.png"), TILE, TILE, "center",
         ICON_SAT, ICON_VAL)


# ── 11) 동행 혼 워크 시트 ────────────────────────────────────────────────────
# `soul_child.gd`가 `CharSprite.make("res://assets/characters/soul_child.png")` 훅을 이미 깔아 뒀다
# (§23.1 조연 9인과 같은 결 — 파일을 놓는 것이 배선의 전부).
# ★ size 24로 생성한 이유 = 그레이박스가 스펙이다: `_BODY`가 사람형 16×32의 **절반 키**(12×16)라
#   "한눈에 작다"가 실루엣의 전부다. 사람 규격 44의 절반이 24다.
def build_soul_child() -> None:
    src = os.path.join(CHARS, "soul_child_v2_raw")
    if not os.path.isdir(src):
        print("  ! soul_child_v2_raw 폴더 없음(건너뜀)")
        return
    sheet = Image.new("RGBA", (CHAR_FRAME, CHAR_FRAME * len(CHAR_ROWS)), (0, 0, 0, 0))
    for row, d in enumerate(CHAR_ROWS):
        p = os.path.join(src, d + ".png")
        if not os.path.exists(p):
            print("  ! soul_child %s 없음 — 빈 행" % d)
            continue
        raw = Image.open(p).convert("RGBA")
        hard_alpha(raw)
        apply_px(raw, lambda c: mute(c, CAST_SAT, CAST_VAL))
        box = raw.getbbox()
        if box is None:
            continue
        content = raw.crop(box)
        frame = Image.new("RGBA", (CHAR_FRAME, CHAR_FRAME), (0, 0, 0, 0))
        frame.paste(content, ((CHAR_FRAME - content.width) // 2,
                              max(0, CHAR_FOOT_Y - content.height)), content)
        sheet.paste(frame, (0, row * CHAR_FRAME))
    sheet.save(os.path.join(CHARS, "soul_child.png"))
    print("  characters/soul_child.png %dx%d" % sheet.size)


# ── 12) 먹갈기 승마 합성 시트 ────────────────────────────────────────────────
# [ADR-0069] 결정 6이 "승마 합성 시트는 아트 패스(T9)"로 넘긴 그 시트다. 규약은 캐릭터 시트와
# **같은 결**(1열 × 4행 = down/up/right/left)이되 프레임이 48이다 — 말은 사람보다 옆으로 넓고
# (east/west 콘텐츠 42px) 80 프레임을 쓰면 시트가 필요 이상으로 커진다.
# ★ 발치정렬: 플레이어가 말 **위에** 앉은 것으로 읽히려면 말 발굽이 플레이어 발치와 같은 y에 서야
#   한다 — `_draw_mount`가 프레임 하단을 플레이어 발치에 맞춘다(프레임 안 발치 = 프레임 바닥).
# ★ declutter: 생성물 south 프레임 좌상단에 워터마크 부스러기가 붙어 왔다(가장 큰 성분만 남긴다).
def build_mount_sheet() -> None:
    src = os.path.join(PROPS, "raw", "mount_horse_raw")
    if not os.path.isdir(src):
        print("  ! mount_horse_raw 폴더 없음(건너뜀)")
        return
    sheet = Image.new("RGBA", (MOUNT_FRAME, MOUNT_FRAME * len(CHAR_ROWS)), (0, 0, 0, 0))
    for row, d in enumerate(CHAR_ROWS):
        p = os.path.join(src, d + ".png")
        if not os.path.exists(p):
            print("  ! mount %s 없음 — 빈 행" % d)
            continue
        raw = Image.open(p).convert("RGBA")
        hard_alpha(raw)
        largest_blob(raw)
        apply_px(raw, lambda c: mute(c, PROP_SAT, PROP_VAL))
        box = raw.getbbox()
        if box is None:
            continue
        content = raw.crop(box)
        if content.width > MOUNT_FRAME or content.height > MOUNT_FRAME:
            content = content.resize((min(content.width, MOUNT_FRAME),
                                      min(content.height, MOUNT_FRAME)), Image.NEAREST)
        frame = Image.new("RGBA", (MOUNT_FRAME, MOUNT_FRAME), (0, 0, 0, 0))
        frame.paste(content, ((MOUNT_FRAME - content.width) // 2,
                              MOUNT_FRAME - content.height), content)
        sheet.paste(frame, (0, row * MOUNT_FRAME))
    sheet.save(os.path.join(PROPS, "mount_horse.png"))
    print("  props/mount_horse.png %dx%d" % sheet.size)


if __name__ == "__main__":
    print("S10-T9 엔드게임 롱테일 아트 패스 후처리")
    build_museum_stands()
    build_peddler_stall()
    build_pet()
    build_mine_devices()
    build_garden_pot()
    build_sprinklers()
    build_rarecrows()
    build_trial_room()
    build_firefly_soul()
    build_icons()
    build_soul_child()
    build_mount_sheet()
