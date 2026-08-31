#!/usr/bin/env python3
# ★[폴리시 2회차 · 시각/아트 배치] 후처리 글루(ADR-0001 허용 = 생성물 정리·규격 정합, 변환 엔진 아님).
#
# 규칙은 make_s10_t9_art.py와 **같다** — 새 계수를 세우지 않는다(패스마다 계수가 갈리면 한 방
# 안에서 톤이 튄다):
#   [asset-ruleset §8.1] 하드 알파 · [§9] 저승 muted · [ADR-0050] 32-native · [§3] 발치 앵커
#
# ★ 멱등: raw에서 매번 새로 굽는다(최종 PNG를 재입력으로 쓰지 않음).
# 사용: python3 tools/make_polish_r2_art.py   (game/ 에서)
import colorsys
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROPS = os.path.join(ROOT, "assets", "props")
PROPS_RAW = os.path.join(PROPS, "raw")
UI = os.path.join(ROOT, "assets", "ui")
UI_RAW = os.path.join(UI, "raw")

TILE = 32
ALPHA_CUT = 128    # [§8.1] 하드 알파(반투명 AA 엣지 금지 — 헤일로 방지)

# [§9] 저승 muted — S10-T9 패스의 계수를 그대로 물려받는다.
ICON_SAT, ICON_VAL = 0.90, 0.97     # 인벤·매대 격자 아이콘
PROP_SAT, PROP_VAL = 0.85, 0.95     # 월드 프롭(기물 층)
# 혼백관 실내 진열 — S10-T9가 museum_shelf·열람대·안치대에 건 그 계수. 그 방의 기존 좌대가
# draw_rect 어두운 갈색(0.26,0.24,0.22)이라 생성물의 밝은 목재를 그대로 두면 새것만 튄다.
MUSEUM_SAT, MUSEUM_VAL = 0.68, 0.88


def hard_alpha(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= ALPHA_CUT else (0, 0, 0, 0)
    return img


def mute(img: Image.Image, sat_mul: float, val_mul: float) -> Image.Image:
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(p[0] / 255.0, p[1] / 255.0, p[2] / 255.0)
            r, g, b = colorsys.hsv_to_rgb(h, min(1.0, s * sat_mul), min(1.0, v * val_mul))
            px[x, y] = (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5), 255)
    return img


def block2_ratio(img: Image.Image) -> float:
    """[§0.1] 2×2 청크 비율 — 0.70 미만이면 1px 고움(재청키화 대상)."""
    px = img.load()
    tot = blk = 0
    for y in range(0, img.height - 1, 2):
        for x in range(0, img.width - 1, 2):
            a = px[x, y]
            if a[3] == 0:
                continue
            tot += 1
            if px[x + 1, y] == a and px[x, y + 1] == a and px[x + 1, y + 1] == a:
                blk += 1
    return (blk / tot) if tot else 1.0


def widen(unit: Image.Image, out_w: int, cap: int) -> Image.Image:
    """단품 카운터(32px)를 카운터 줄 전체 폭으로 늘린다 — **3분할 반복**(늘이기 아님).

    좌 `cap`px = 왼쪽 마구리 · 우 `cap`px = 오른쪽 마구리 · 그 사이 몸통을 반복해 채운다.
    단품을 통째로 6번 붙이면 마구리가 여섯 벌 서서 "작은 카운터 여섯 개"로 읽힌다(실측).
    """
    w, h = unit.size
    body = unit.crop((cap, 0, w - cap, h))
    bw = body.width
    out = Image.new("RGBA", (out_w, h), (0, 0, 0, 0))
    out.paste(unit.crop((0, 0, cap, h)), (0, 0))
    x = cap
    while x < out_w - cap:
        seg = min(bw, out_w - cap - x)
        out.paste(body.crop((0, 0, seg, h)), (x, 0))
        x += seg
    out.paste(unit.crop((w - cap, 0, w, h)), (out_w - cap, 0))
    return out


def bake(src: str, dst: str, sat: float, val: float, out_w: int = 0, cap: int = 6) -> None:
    img = hard_alpha(Image.open(src))
    if out_w and out_w != img.width:
        img = widen(img, out_w, cap)
    img = mute(img, sat, val)
    img.save(dst)
    print("  %-28s %sx%s  청크비 %.2f" % (
        os.path.basename(dst), img.width, img.height, block2_ratio(img)))


def main() -> None:
    # ── ① 길드 실내(회백 절석 방) ────────────────────────────────────────────
    # 카운터 = 응대 줄 6칸(x25..30) → 192px. 무기 걸이는 2×1칸 그대로.
    print("길드:")
    bake(os.path.join(PROPS_RAW, "guild_counter_raw.png"),
         os.path.join(PROPS, "guild_counter.png"), PROP_SAT, PROP_VAL, out_w=192, cap=6)
    # ★ S5-T9의 옛 무기 걸이(가는 선 그림)를 새 raw로 교체한다 — 같은 64×32라 배선 무변경.
    bake(os.path.join(PROPS_RAW, "guild_weapon_rack_raw.png"),
         os.path.join(PROPS, "guild_weapon_rack.png"), PROP_SAT, PROP_VAL)

    # ── ② 목공방 실내(따뜻한 목재 방) ────────────────────────────────────────
    print("목공방:")
    bake(os.path.join(PROPS_RAW, "woodshop_counter_raw.png"),
         os.path.join(PROPS, "woodshop_counter.png"), PROP_SAT, PROP_VAL, out_w=192, cap=6)
    bake(os.path.join(PROPS_RAW, "woodshop_workbench_raw.png"),
         os.path.join(PROPS, "woodshop_workbench.png"), PROP_SAT, PROP_VAL)
    bake(os.path.join(PROPS_RAW, "woodshop_logs_raw.png"),
         os.path.join(PROPS, "woodshop_logs.png"), PROP_SAT, PROP_VAL)
    # 작업물 = **상태 오버레이**다(건축 진행 중에만 작업대 위에 얹힌다) — 작업대에 굽지 않는다.
    bake(os.path.join(PROPS_RAW, "woodshop_workpiece_raw.png"),
         os.path.join(PROPS, "woodshop_workpiece.png"), PROP_SAT, PROP_VAL)

    # ── ③ 가구 세트 매대 아이콘(만물상 격자와 같은 인벤 층) ──────────────────
    print("가구 세트 아이콘:")
    for sid in ["jaetnun", "jeoseungsol"]:
        bake(os.path.join(UI_RAW, "deco_%s_raw.png" % sid),
             os.path.join(UI, "deco_%s.png" % sid), ICON_SAT, ICON_VAL)

    # ── ④ 혼백관 진열(유품 좌대 = 레어크로우 좌대와 공용 · 기증대) ───────────
    print("혼백관 진열:")
    bake(os.path.join(PROPS_RAW, "museum_pedestal_raw.png"),
         os.path.join(PROPS, "museum_pedestal.png"), MUSEUM_SAT, MUSEUM_VAL)
    bake(os.path.join(PROPS_RAW, "museum_donate_table_raw.png"),
         os.path.join(PROPS, "museum_donate_table.png"), MUSEUM_SAT, MUSEUM_VAL)

    # ── ⑤ 나락 아레나 하강 구멍 ──────────────────────────────────────────────
    # ★ 밴드 톤(`_mine_cast`)을 **안 얹는 자리**라 여기서도 덜 죽인다: 구멍은 [F]를 누르는
    #   상호작용 지점이고, [§17]이 "게임플레이 중요 오브젝트는 명도로 배경에서 뜬다"를 요구한다.
    #   심연 자보라 지면 위에서 테두리가 안 읽히면 구멍이 아니라 얼룩이 된다(1차 판정).
    bake(os.path.join(PROPS_RAW, "narak_shaft_raw.png"),
         os.path.join(PROPS, "narak_shaft.png"), PROP_SAT, PROP_VAL)

    # ── ⑥ 집·창고 저장 상자 ─────────────────────────────────────────────────
    # ★ 한 장이 두 자리를 덮는다(집 CHEST_TILE · 갈무리방 STOREHOUSE_CHEST_TILE) — 같은 궤짝이다.
    #   "보관 중" 밝은 점은 여전히 코드가 뚜껑 위에 얹는다(상태를 아트에 굽지 않는다).
    print("저장 상자:")
    bake(os.path.join(PROPS_RAW, "storage_chest_raw.png"),
         os.path.join(PROPS, "storage_chest.png"), PROP_SAT, PROP_VAL)

    # ── ⑦ 시련 게시판 v3(먹빛 판면 + 목재 틀) ────────────────────────────────
    # ★ v2(현행 trial_board.png)는 **판면이 밝은 회백**이라 그 위에 얹히는 흰 쪽지가 판에 묻혀
    #   "무늬 없는 회백 사각"으로 읽혔다(1차 판정). v3는 판면을 먹빛으로 굽고 틀만 목재로 세운다 —
    #   쪽지·도장은 여전히 코드가 그 위에 그린다(상태를 아트에 굽지 않는다).
    print("시련 게시판:")
    bake(os.path.join(PROPS_RAW, "trial_board_v3_raw.png"),
         os.path.join(PROPS, "trial_board.png"), PROP_SAT, PROP_VAL)


if __name__ == "__main__":
    main()
