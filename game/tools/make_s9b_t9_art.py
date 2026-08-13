#!/usr/bin/env python3
# ★[S9b-T9 / ADR-0068 아트 스코프] 조연 코러스 9인 + 척추 아트 패스 후처리 글루
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab 생성 raw → 게임 규격으로 굳힌다. 규칙·계수는 make_s6_art.py(주방요괴)·
# make_s9_t9_art.py(T1 슬라이스)와 **같다** — 패스마다 계수가 갈리면 한 화면에서 새것만 톤이 튄다.
#   [asset-ruleset §8.1] 하드 알파 · [§9] 저승 muted · [ADR-0050] 32-native · [§3] 발치 앵커
#
#   1) 조연 9인 워크 시트   80×320   assets/characters/{9인}.png
#   2) 명부 혼례 부적       32×32    assets/materials/myeongbu_charm.png
#
# ★ 멱등: raw에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: python3 tools/make_s9b_t9_art.py   (game/ 에서)
import colorsys
import os
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHARS = os.path.join(ROOT, "assets", "characters")
MATERIALS = os.path.join(ROOT, "assets", "materials")

ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)

# [§9] 저승 muted — 계수는 make_s6_art.py와 **동일**이다.
CAST_SAT, CAST_VAL = 0.94, 0.98   # 캐스트(출하 5종과 나란히 서는 층 — 아주 얕게)
ICON_SAT, ICON_VAL = 0.90, 0.97   # 아이콘(인벤 격자에서 광물·메뉴·혼례 부적과 나란히 뜬다)

# char_sprite.gd 시트 규약
CHAR_FRAME = 80
CHAR_FOOT_Y = 74                                 # 출하 캐스트 5종 실측 발치선
CHAR_ROWS = ["south", "north", "east", "west"]   # 행 순서 = down/up/right/left

# 조연 9인 — 전부 `<id>_raw/{south,north,east,west}.png`에서 굽는다.
# 켄·프로스티만 size=56으로 생성해 콘텐츠가 한 뼘 크다(그레이박스 BODY_SIZE 22×4x = 거인 둘).
ROSTER = ["kkaebi", "ken", "seolhwa", "scarlet", "mir", "luca", "frosty", "gangrim", "serena"]


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


def interior_mask(img: Image.Image) -> set:
    """외곽선을 뺀 '몸 안' 픽셀 집합 — 바깥 투명에 인접한 불투명 픽셀은 외곽선으로 본다.
    (make_naru_art2.py 모찌 글루와 같은 판정 — 얼굴 지우기가 실루엣을 갉지 않게 한다.)"""
    px = img.load()
    w, h = img.size
    outside = [[False] * w for _ in range(h)]
    q: deque = deque()

    def seed(x, y):
        if px[x, y][3] == 0 and not outside[y][x]:
            outside[y][x] = True
            q.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)
    while q:
        cx, cy = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < w and 0 <= ny < h and not outside[ny][nx] and px[nx, ny][3] == 0:
                outside[ny][nx] = True
                q.append((nx, ny))
    inner = set()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or outside[ny][nx]:
                    edge = True
                    break
            if not edge:
                inner.add((x, y))
    return inner


# ★ north(뒷모습) 얼굴 지우기 — [§15.6/§17.4]가 옹이에서 박제한 PixelLab standard의 알려진 결함이다
#   ("north 프레임에 얼굴이 그려진다"). 옹이·풀무·무골은 **정지 NPC**라 walk_down 행만 화면에 들어
#   인게임에선 안 보였지만, 조연 9인은 **셋 다 자리를 옮겨 다니는 스케줄**이라 뒷모습이 실제로 뜬다
#   → 눈감아 줄 수 없다.
#   지우기는 모찌 글루(make_naru_art2._move_face(hide=True))와 **같은 연산**이다: 머리 띠 안의
#   '몸보다 어두운 내부 픽셀'을 이웃 몸 색으로 메운다. 털이 앞뒤 같은 색인 인물(프로스티)에서만
#   성립하는 처방이라, 머리카락으로 뒤통수가 이미 갈리는 8인에겐 걸지 않는다(육안 검수로 확인).
def erase_north_face(img: Image.Image, band_ratio: float, lum_cut: int) -> Image.Image:
    img = img.copy()
    px = img.load()
    box = img.getbbox()
    if box is None:
        return img
    x0, y0, x1, y1 = box
    band_bottom = y0 + int((y1 - y0) * band_ratio)
    inner = interior_mask(img)
    doomed = set()
    for y in range(y0, min(band_bottom, y1)):
        for x in range(x0, x1):
            if px[x, y][3] == 0 or (x, y) not in inner:
                continue
            if max(px[x, y][:3]) < lum_cut:
                doomed.add((x, y))
    if not doomed:
        return img
    # 이웃(비-대상 불투명 픽셀)에서 색을 끌어와 반복 충전 — 한 번에 못 메우는 안쪽까지 번진다.
    remaining = set(doomed)
    for _ in range(32):
        if not remaining:
            break
        filled = []
        for (x, y) in remaining:
            for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1),
                           (-1, -1), (1, -1), (-1, 1), (1, 1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) in remaining or not (0 <= nx < img.width and 0 <= ny < img.height):
                    continue
                if px[nx, ny][3] != 0 and max(px[nx, ny][:3]) >= lum_cut:
                    filled.append(((x, y), px[nx, ny][:3]))
                    break
        if not filled:
            break
        for (xy, c) in filled:
            px[xy[0], xy[1]] = (c[0], c[1], c[2], 255)
            remaining.discard(xy)
    return img


# ── 1) 조연 9인 워크 시트 ────────────────────────────────────────────────────
# 배선은 **코드 0줄** — 각 `<id>.gd`의 `CharSprite.make("res://assets/characters/<id>.png")`가
# 이미 있던 훅이라 파일을 놓는 것이 배선의 전부다(없으면 그레이박스 `_draw()`로 자동 폴백).
# 1열(정지 rotation)인 이유: 워크 4프레임은 이 패스 밖이다. char_sprite가 열 수를 파일에서
# 읽으므로 나중에 워크 시트가 오면 **코드 무수정**으로 열이 는다(모찌와 같은 자리).
NORTH_FACE_FIX = {
    # 프로스티만 — 앞뒤가 같은 흰 털이라 모델이 뒷통수에도 얼굴을 그렸다(실측 확인).
    "frosty": (0.34, 200),   # (머리 띠 = 콘텐츠 높이의 위 34% , 이보다 어두우면 얼굴로 본다)
}


# ★ 살빛 치환 — [§11.4 네오] "살빛(h 10~60°)을 백자 오프화이트로 치환(명도 계조 보존)"과 같은 연산.
#   세레나만 건다: v3 회전본이 상반신을 **따뜻한 갈색 살빛**으로 구워 왔는데, 그레이박스
#   `serena.gd _draw` 실루엣 설계 ㉣이 "**두 색** — 하반신 짙은 청록 / 상반신 창백한 물빛"을
#   정체성으로 못 박았다(강림의 무채색 최하단과 반대편에 서는 근거). 따뜻한 색이 들어오면
#   그 대비가 무너지고, 로스터에서 세레나만 난색이 된다.
#   목표색 = 그레이박스 상반신 Color(0.76,0.84,0.86) = 물빛(h≈188°).
#   ★ 청록 머리·꼬리(h≈160~180°)는 창을 안 건드린다 — 난색 창(h 5~40°)만 잡는다.
SKIN_RECOLOR = {"serena": (5.0, 40.0, 188.0 / 360.0, 0.40, 1.06)}


def recolor_skin(img: Image.Image, h_lo: float, h_hi: float,
                 h_to: float, sat_mul: float, val_mul: float) -> Image.Image:
    def fn(rgb):
        r, g, b = (c / 255.0 for c in rgb)
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if s <= 0.12 or not (h_lo / 360.0 <= h <= h_hi / 360.0):
            return rgb
        s = max(0.0, min(1.0, s * sat_mul))
        v = max(0.0, min(1.0, v * val_mul))
        r, g, b = colorsys.hsv_to_rgb(h_to, s, v)
        return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))
    return apply_px(img, fn)


def build_sheet(name: str) -> None:
    src = os.path.join(CHARS, name + "_raw")
    if not os.path.isdir(src):
        print("  ! %s_raw 폴더 없음(건너뜀)" % name)
        return
    sheet = Image.new("RGBA", (CHAR_FRAME, CHAR_FRAME * len(CHAR_ROWS)), (0, 0, 0, 0))
    for row, d in enumerate(CHAR_ROWS):
        p = os.path.join(src, d + ".png")
        if not os.path.exists(p):
            print("  ! %s %s 없음 — 빈 행" % (name, d))
            continue
        raw = Image.open(p).convert("RGBA")
        hard_alpha(raw)
        apply_px(raw, lambda c: mute(c, CAST_SAT, CAST_VAL))
        if name in SKIN_RECOLOR:
            recolor_skin(raw, *SKIN_RECOLOR[name])
        if d == "north" and name in NORTH_FACE_FIX:
            band, cut = NORTH_FACE_FIX[name]
            raw = erase_north_face(raw, band, cut)
        box = raw.getbbox()
        if box is None:
            continue
        content = raw.crop(box)
        frame = Image.new("RGBA", (CHAR_FRAME, CHAR_FRAME), (0, 0, 0, 0))
        frame.paste(content, ((CHAR_FRAME - content.width) // 2,
                              max(0, CHAR_FOOT_Y - content.height)), content)
        sheet.paste(frame, (0, row * CHAR_FRAME))
    sheet.save(os.path.join(CHARS, name + ".png"))
    print("  characters/%s.png %dx%d" % (name, sheet.size[0], sheet.size[1]))


# ── 2) 명부 혼례 부적 아이콘 ─────────────────────────────────────────────────
# 배선: main.MINE_ICONS에 한 줄 — [S8-T9] 혼례 부적(wedding_charm) **바로 옆**이다.
# 계수는 §21.1 부적과 같은 아이콘 값(0.90/0.97)이라 인벤 한 격자에서 둘이 한 집으로 읽힌다.
def build_charm() -> None:
    raw_path = os.path.join(MATERIALS, "raw", "myeongbu_charm_raw.png")
    if not os.path.exists(raw_path):
        print("  ! myeongbu_charm_raw.png 없음(건너뜀)")
        return
    img = Image.open(raw_path).convert("RGBA")
    hard_alpha(img)
    apply_px(img, lambda c: mute(c, ICON_SAT, ICON_VAL))
    box = img.getbbox()
    content = img.crop(box) if box else img
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    out.paste(content, ((32 - content.width) // 2, (32 - content.height) // 2), content)
    out.save(os.path.join(MATERIALS, "myeongbu_charm.png"))
    print("  materials/myeongbu_charm.png 32x32")


# ── 3) 도트 대화 초상화 5인 ─────────────────────────────────────────────────
# [§15.6 옹이 · §17.4 풀무]와 **같은 규격·같은 경로**: 위 시트의 south 프레임을 16색 P모드로
# 양자화해 create_portrait_character(character_to_portrait, result_size=128)에 넣고, 받은 raw를
# 하드 알파 → ×2 nearest(128→256)로 굳힌다.
# ★ 표정 파일은 만들지 않는다 — `_set_portrait`가 smile/shy/sad 파일이 없으면 idle로 떨어지므로
#   idle 한 장이 대사 전량을 덮는다(네오·뱃사공·옹이·풀무와 같은 규약).
# ★ **비인간 4인(켄·미르·루카·프로스티)은 아예 시도하지 않았다** — §15.6이 박제한
#   `character_to_portrait`의 "비인간 재질 → 사람 피부 되돌림"에 가장 불리한 입력이고(백골·털뭉치·
#   늑대 주둥이·비늘), 한 장이 25 gen이다. `portrait_stem=""` 유지 + owner-Gemini 큐 1순위다.
PORTRAITS = os.path.join(ROOT, "assets", "portraits")
PORTRAIT_ROSTER = ["kkaebi", "seolhwa", "scarlet", "gangrim", "serena"]


def build_portraits() -> None:
    for name in PORTRAIT_ROSTER:
        raw_path = os.path.join(PORTRAITS, name + "_raw.png")
        if not os.path.exists(raw_path):
            print("  ! %s_raw.png 없음(건너뜀)" % name)
            continue
        img = Image.open(raw_path).convert("RGBA")
        hard_alpha(img)
        out = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
        out.save(os.path.join(PORTRAITS, name + ".png"))
        print("  portraits/%s.png %dx%d" % (name, out.size[0], out.size[1]))


if __name__ == "__main__":
    print("S9b-T9 조연 코러스 9인 + 척추 아트 패스 후처리")
    for _n in ROSTER:
        build_sheet(_n)
    build_charm()
    build_portraits()
