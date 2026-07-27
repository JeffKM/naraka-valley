#!/usr/bin/env python3
# ★[S3-T10 / ADR-0061 결정 10] 낚시 아이템 아이콘·뱃사공 아트 후처리 글루
# (ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# PixelLab MCP 생성 raw → 게임 규격으로 굳힌다:
#   [asset-ruleset §8.1] 하드 알파 · [§9] 저승 muted · [ADR-0050] 32-native ·
#   [make_naru_art2.py] 캐릭터 시트 규약(FRAME 80 · 행=south/north/east/west · 발치 y=74).
#
#   1) 물고기 아이콘 18종 + 게잡이통 통용물 3종  32×32  assets/fish/<id>.png
#   2) 기어 아이콘 11종(낚싯대4·미끼3·태클3·게잡이통1)  32×32  assets/gear/<id>.png
#   3) 뱃사공 시트  80×320  assets/characters/boatman.png (정지 1열 × 4방향 — neo 선례)
#   4) 뱃사공 초상화  320×320  assets/portraits/boatman.png (도트 스톱갭 — neo 선례)
#
# ★ 멱등: raw에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: python3 tools/make_s3_icons.py   (game/ 에서)
import colorsys
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FISH = os.path.join(ROOT, "assets", "fish")
GEAR = os.path.join(ROOT, "assets", "gear")
CHARS = os.path.join(ROOT, "assets", "characters")
PORTRAITS = os.path.join(ROOT, "assets", "portraits")

ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)
FRAME = 80         # 캐릭터 시트 규약(char_sprite.gd FRAME=80)
ROW_DIRS = ["south", "north", "east", "west"]   # 행 순서 = down/up/right/left
FOOT_Y = 74        # 출하 캐스트 5종 실측 발치선(make_naru_art2.py 주석 참조)

# [§9] 저승 muted — 아이콘은 인벤 슬롯에서 서로 구분돼야 하므로 프롭(0.85/0.95)보다 얕게 누른다.
ICON_SAT = 0.90
ICON_VAL = 0.97


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


# ── 1·2) 아이템 아이콘 ────────────────────────────────────────────────────────
# ★ 크기를 손대지 않는다: 32-native 생성물을 그대로 쓴다([ADR-0050] "AI 축소본은 뭉개진다").
#   콘텐츠만 32² 안에서 가운데로 다시 앉힌다 — 슬롯(inv_frame `_draw_icon`)이 아이콘을 통째로
#   늘려 그리므로 여백이 한쪽에 몰리면 옆 슬롯과 눈금이 어긋나 보인다.
def build_icon(raw_path: str, out_path: str) -> None:
    img = Image.open(raw_path).convert("RGBA")
    hard_alpha(img)
    apply_px(img, lambda c: mute(c, ICON_SAT, ICON_VAL))
    box = img.getbbox()
    if box is not None:
        content = img.crop(box)
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        img.paste(content, ((32 - content.width) // 2, (32 - content.height) // 2), content)
    img.save(out_path)


# 어획물(FishCatalog 18종 + ItemCatalog.POT_GOODS 3종) — id = 파일명 = 아이템 id.
FISH_IDS = [
    "neok_bungeo", "jaetbit_songsari", "yeoul_pirami", "chorong_chi",
    "sangyeotgil_ingeo", "dokkaebi_megi", "angae_ssogari", "meokbit_jangeo",
    "neok_myeolchi", "eunbineul_cheongeo", "mulmaru_gajami", "honbul_haepari",
    "jeonyeoknol_domi", "satgat_ojingeo", "mulbineul_nongeo", "neoul_beomchi",
    "geomeunyeoul_daemegi", "simyeon_manjangeo",
    "neok_ge", "hon_jogae", "jaetbit_sora",
]
# 기어(GearCatalog 10종 + 게잡이통) — 게잡이통 텍스처는 인벤 아이콘과 월드 설치물이 공유한다.
GEAR_IDS = [
    "rod_t1", "rod_t2", "rod_t3", "rod_t4",
    "bait_basic", "bait_lure", "bait_pledge",
    "tackle_cork", "tackle_sinker", "tackle_quality",
    "crab_pot",
]


def build_icons() -> None:
    for group, ids in ((FISH, FISH_IDS), (GEAR, GEAR_IDS)):
        for item_id in ids:
            raw = os.path.join(group, "raw", item_id + "_raw.png")
            if not os.path.exists(raw):
                print("  ! raw 없음: %s" % raw)
                continue
            build_icon(raw, os.path.join(group, item_id + ".png"))
        print("  %s: %d개" % (os.path.basename(group), len(ids)))


# ── 3) 뱃사공 스프라이트 시트 ────────────────────────────────────────────────
# 네오(§11.4)와 같은 **정지 rotation 1열** 시트다 — 상주 NPC라 워크 첫 프레임(스트라이드)을 쓰면
# 서 있어야 할 사람이 걷는 듯 보인다([p2.0-spike §10.12] 미호 교훈).
def place_frame(content: Image.Image) -> Image.Image:
    """콘텐츠를 80×80 프레임에 발치정렬(가로중앙)."""
    frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    frame.paste(content, ((FRAME - content.width) // 2, max(0, FOOT_Y - content.height)), content)
    return frame


# 노 팔레트 — south 프레임 실측(자루 본색 · NW 하이라이트 · SE 그늘 · 외곽선).
OAR_MID = (125, 97, 84)
OAR_HI = (150, 119, 103)
OAR_LO = (96, 74, 64)
OAR_LINE = (44, 39, 38)


def _stamp_oar(img: Image.Image, box, face_right: bool) -> None:
    """옆모습 프레임에 노를 얹는다 — **뒤쪽 어깨에 세워 든 자루 + 밑동 노깃**.

    ★ 왜 후처리인가: PixelLab standard가 south/north엔 노를 굽고 east/west엔 안 굽는다(3방향
      일관성이 standard의 알려진 한계 — [p2.0-spike §10.11] 네오 태엽 키와 같은 사례). 노는
      삿갓과 함께 뱃사공의 **정체성 실루엣 2요소**(boatman.gd 그레이박스가 정한 것)이므로 빠지면
      옆모습이 "삿갓 쓴 행인"이 된다. 그래서 손으로 얹는다.
    ★ 얹는 쪽 = **바라보는 방향의 반대**(뒤쪽 어깨). 앞쪽에 두면 자루가 얼굴·손을 가린다.
    """
    px = img.load()
    x0, y0, x1, y1 = box
    # ★ 실루엣에 **붙여** 세운다(떼면 옆에 세워 둔 말뚝으로 읽힌다 — 1차 판 육안 리젝).
    ax = x0 if face_right else (x1 - 3)   # 자루 왼쪽 열
    top = y0 + 2
    bot = y1 - 3

    def put(x, y, c):
        if 0 <= x < img.width and 0 <= y < img.height:
            px[x, y] = c + (255,)

    for y in range(top, bot + 1):
        put(ax - 1, y, OAR_LINE)
        put(ax, y, OAR_HI)
        put(ax + 1, y, OAR_LO)
        put(ax + 2, y, OAR_LINE)
    # 밑동 노깃(물갈퀴) — 자루보다 넓은 주걱. 실루엣 아래쪽에 무게를 줘 "노"로 읽히게 한다.
    for y in range(bot - 8, bot + 1):
        put(ax - 2, y, OAR_LINE)
        put(ax - 1, y, OAR_MID)
        put(ax, y, OAR_HI)
        put(ax + 1, y, OAR_MID)
        put(ax + 2, y, OAR_LO)
        put(ax + 3, y, OAR_LINE)
    for x in range(ax - 2, ax + 4):   # 노깃 아래 마감선
        put(x, bot + 1, OAR_LINE)


def build_boatman() -> None:
    sheet = Image.new("RGBA", (FRAME, FRAME * len(ROW_DIRS)), (0, 0, 0, 0))
    for row, d in enumerate(ROW_DIRS):
        raw = Image.open(os.path.join(CHARS, "boatman_raw", d + ".png")).convert("RGBA")
        hard_alpha(raw)
        apply_px(raw, lambda c: mute(c, 0.94, 0.98))   # 캐스트와 나란히 서므로 아주 얕게만
        if d in ("east", "west"):
            _stamp_oar(raw, raw.getbbox(), d == "east")
        frame = place_frame(raw.crop(raw.getbbox()))
        sheet.paste(frame, (0, row * FRAME), frame)
    sheet.save(os.path.join(CHARS, "boatman.png"))
    print("  boatman.png %dx%d" % sheet.size)


# ── 4) 뱃사공 초상화 ─────────────────────────────────────────────────────────
# PixelLab `create_portrait_character(character_to_portrait)`가 위 시트 south 프레임에서 뽑은 160²
# 버스트 → 하드 알파 + ×2 nearest(320²). [portrait-spec-card §4] 출력 규격.
# ★ 네오(§11.6)와 같은 **도트 스톱갭**이다 — 기존 4인은 소프트 일러스트라 화풍이 다르다(교체 1순위).
def build_boatman_portrait() -> None:
    raw_path = os.path.join(PORTRAITS, "boatman_raw.png")
    if not os.path.exists(raw_path):
        print("  ! 초상화 raw 없음(건너뜀): %s" % raw_path)
        return
    raw = Image.open(raw_path).convert("RGBA")
    hard_alpha(raw)
    img = raw.resize((raw.width * 2, raw.height * 2), Image.NEAREST)
    img.save(os.path.join(PORTRAITS, "boatman.png"))
    print("  boatman.png(portrait) %dx%d" % img.size)


def main() -> None:
    print("[S3-T10] 낚시 아이콘·뱃사공 아트 후처리")
    build_icons()
    build_boatman()
    build_boatman_portrait()


if __name__ == "__main__":
    main()
