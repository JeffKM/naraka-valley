extends Node2D
# T1.4 — 16×16 타일맵 더미 맵 1개 (그레이박스).
#
# 목적: 회색 캐릭터가 "진짜 타일맵"(TileMapLayer) 위를 돌아다니며
#       밭·집·카페 세 구역을 시각적으로 구분할 수 있는지 검증한다.
#       회색 도형만(ADR-0001). 타일 16×16 · 내부해상도 320×180(ADR-0003).
#
# 설계 메모:
#   - 에셋 없이(ADR-0001) 타일맵을 쓰기 위해, 단색 16×16 블록을 코드로 그려
#     아틀라스 텍스처를 만들고 TileSet을 런타임에 조립한다. "도트화 툴"이 아니라
#     그레이박스용 플레이스홀더 생성이다.
#   - 맵(40×24 = 640×384)은 화면(320×180)보다 커서, 카메라가 캐릭터를 따라가며
#     맵 경계에서 멈춘다 → "돌아다니며"가 의미를 가진다.
#   - 온보딩 동선(CONTEXT '온보딩': 도착→집→밭→카페)을 염두에 둔 배치다.
#     길(PATH)이 도착 지점에서 허브로 올라가 집·밭·카페로 갈라진다.
#
# 보는 법:
#   - 방향키로 이동. 집/카페는 벽으로 둘러싸여 문으로만 드나든다(통과 불가).
#   - 밭은 벽 없는 열린 구역. 각 구역 위에 떠 있는 라벨(집/밭/카페/도착)로 식별.
#   - 좌상단 readout에 현재 구역·위치·FPS가 뜬다.

# ── 규격 ────────────────────────────────────────────────────────────────
const TILE := 32                       # 월드 타일 한 칸(px). 캐릭터 2배(v3 size64)에 맞춰 환경도 2배(C). 좌표·카메라·배치는 이 값.
const TILE_ART := 32                    # 소스 도트 아트의 타일 픽셀 = TILE. ADR-0013: 환경 아트를 32px native로 상향(캐릭터 선명도 일치). 타일맵 스케일 1:1 — 더는 ×2 업스케일 안 함.
const MAP_W := 40                      # 맵 가로(타일) = 640px
const MAP_H := 52                      # 맵 세로(타일). 외부(0..23) + 실내 전용 구역(아래쪽). 실내 방은
                                       # 외부에서 멀리 떨어진 별도 구역에 두고 카메라로 격리한다(스타듀식 외부↔실내 분리).
const OUTDOOR_H := 24                  # 외부 영역 세로(타일). 카메라가 외부 모드에서 여기까지만 비춘다(아래 실내 구역은 안 보임).
const INDOOR_BAND_H := MAP_H - OUTDOOR_H  # =28. 외부 아래 실내 전용 띠 높이(구역 공유). 구역 그리드 세로 = 외부 높이 + 이 띠(코지-와이드 C1).

# ── P2.4 대화 초상화: 화자 표시이름 → 초상화 파일 stem ───────────────────────
# ADR-0003 "표정=대화 시 별도 일러스트 초상화". 인게임 도트(작은 실루엣)와 달리 얼굴을
# 또렷이 살리는 자리. 키는 각 NPC display_name()(미호/옥자/멜/바나)과 일치시킨다.
# 표정 변형은 stem_<expr>.png(예: miho_smile.png) — 대사 줄 맨 앞 인라인 태그
# [smile]/[shy]/[sad]/[surprised]/[talk]로 줄마다 지정한다(대사 속 [E] 등 조작키 안내는 화이트리스트
# 밖이라 표정으로 오인하지 않는다). ★owner 2026-07-02: talk(입벌림)은 부자연 → 폐기. talk·무태그·
# 표정파일 누락은 모두 idle(표정 없는 기본 stem.png, 입 닫힌 중립)로 폴백한다.
const PORTRAIT_DIR := "res://assets/portraits/"
const PORTRAIT_STEM := {
	"미호": "miho",
	"옥자": "okja",
	"멜": "mel",
	"바나": "bana",
}
const PORTRAIT_EXPRS := ["smile", "shy", "sad", "surprised", "talk"]  # 인라인 태그 화이트리스트(surprised=놀람 활성화; talk는 태그로 인식·본문서 제거하되 idle로 렌더)
const PORTRAIT_FALLBACK_EXPR := ""  # 무태그 기본 = idle(기본 stem.png). talk 폐기(owner 2026-07-02, _set_portrait 참조)

# ── 대화창 「태운 한지」 룩(S0-6, owner 제미나이 윈도우 아트) ──
# 윈도우 1장(dialog_window.png) 위에 본문·초상화·이름을 오버레이. 내부칸 = 측정 비율.
const DLG_WINDOW_TEX := "res://assets/ui/dialog_window.png"
const DLG_ARROW_TEX := "res://assets/ui/ink_arrow.png"
const DLG_FONT := "res://assets/fonts/neodgm.ttf"
const DLG_WINDOW := Rect2(16, 172, 608, 176)          # 640×360 논리, CanvasLayer scale 1.5
const DLG_F_TEXT := Rect2(0.0523, 0.1372, 0.6675, 0.7306)
const DLG_F_PORT := Rect2(0.7844, 0.1423, 0.1545, 0.5519)  # 프레임 아트의 초상화 칸(고정)
const DLG_F_NAME := Rect2(0.7645, 0.7830, 0.1952, 0.1151)
const DLG_INK := Color(0.16, 0.12, 0.085)             # 먹빛 본문
const DLG_NAME_INK := Color(0.20, 0.14, 0.09)         # 이름(먹빛)
var _dlg_name: Label = null                            # 이름판(화자명)
var _dlg_arrow: TextureRect = null                     # 다음 화살표(먹빛)

# ── 타일 종류(아틀라스 인덱스 = 이 순서) ──────────────────────────────────
const GROUND := 0   # 바깥 바닥(걷기 O)
const PATH := 1     # 길 — 온보딩 동선(걷기 O)
const SOIL := 2     # 밭 흙(걷기 O)
const HOUSE := 3    # 집 바닥(걷기 O)
const CAFE := 4     # 카페 바닥(걷기 O)
const WALL := 5     # 외벽·건물 외관(통과 X, 공용 어두운 벽돌)
const VOID := 6     # 실내 구역 방 바깥(아무것도 안 그림 → 검은 배경이 비친다, 통과 X). 카메라 격리용 여백.
const HOUSE_WALL := 7  # 집 실내 벽(아늑한 나무·크림 wainscoting — 통과 X)
const CAFE_WALL := 8   # 카페 실내 벽(앤틱 버건디·우드 패널 — 통과 X)
const WATER := 9    # 강물·바다·연못·호수(통과 X). ★T2 — corner terrain으로 승격(물↔풀 Wang). 통과 불가 충돌 유지.
const TREE := 10    # 나무(통과 X — 저승 숲·미혹의 숲 밀집 나무, M4.1). 그레이박스 단색(도트 나무는 Phase 2)
const ROCK := 11    # 바위(통과 X — 업화 갱도 바위 절벽·암반, M5.1). 그레이박스 단색(도트 바위는 Phase 2)
# ★ [ADR-0044 §1] pseudo-Z 다단 절벽 단면(통과 X). 높이=2D평면+절벽 충돌+계단(통과)이라 z축 아님.
# 절벽면이 고지(하늘 목장)의 동·남 가장자리를 2행(H=2)으로 두르고, 동향 계단 노치로만 진입한다.
# CLIFF_FACE는 WALL과 같은 결로 SOLID source에 들어가 통과 불가 충돌을 받는다(cliff_face.png 도트).
const CLIFF_FACE := 12      # 남향/동향 절벽면(단면, SOLID)
# ★ [S1-2 / ADR-0044 §1] pseudo-Z 원시어휘. CLIFF_LIP=고지 밑단(밝은 상단 하이라이트·**걷기 O**·고지 배치
#   하단 한계), CLIFF_FACE_BASE=절벽 접지(SOLID·접지 그림자 베이크). 방향(N/S/E/W)·코너 아트 변종은
#   S1-10(그레이박스는 방향 무의미). z축 아님(ADR-0013 2D 평면 불변).
#   ※ 옛 1타일 CLIFF_CORNER_L/R/INNER는 [S1-3] _build_cliffs 재작성으로 폐기 → 본 cleanup서 상수 제거·넘버 재정렬.
const CLIFF_LIP := 13       # 고지 밑단(걷기 O — 충돌 루프 제외)
const CLIFF_FACE_BASE := 14 # 절벽 접지(SOLID)
# ★ [S1-10 / ADR-0044 §2] 물가 강둑 단차 — 흙 상단 + 물가 돌 ledge(SOLID). 물(연못·강) 북단에 깔려
#   수면이 '낮게' 읽히는 pseudo-Z 강둑을 만든다(owner 참고 스크린샷). 물 Wang은 불변, 위에 강둑만 얹음.
const CLIFF_BANK := 15      # 물가 강둑 단차(SOLID)
# ★ [ADR-0048 §2] 건물 실내 전용 바닥·벽 — barn/coop/storehouse가 집 HOUSE/HOUSE_WALL 재사용을
#   벗고 각자 룩을 갖는다(넋우릿간=거친 흙+볏짚·넋둥우리=밝은 볏짚·갈무리방=돌 판석/돌켜).
#   floor는 걷기 O(충돌 없음), *_WALL은 WORLD_SOLID_TILES에 넣어 통과 X. 아트=절차(make_interior_tiles.py).
const BARN_FLOOR := 16       # 넋우릿간 바닥(다진 흙+볏짚, 걷기 O)
const BARN_WALL := 17        # 넋우릿간 벽(세로 어두운 판재, 통과 X)
const COOP_FLOOR := 18       # 넋둥우리 바닥(밝은 볏짚 깔개, 걷기 O)
const COOP_WALL := 19        # 넋둥우리 벽(가로 밝은 널빤지, 통과 X)
const STOREHOUSE_FLOOR := 20 # 갈무리방 바닥(돌 판석, 걷기 O)
const STOREHOUSE_WALL := 21  # 갈무리방 벽(쌓은 돌켜, 통과 X)
# ★[단계3-④ / cliff-tileset-spec §10.2] 남향 절벽 벽 좌우 끝 곡선 대각 전이 코너. 옛 90° 각진 벽 끝을
#   스타듀식 곡선으로 마감 — Face(위)+Base(아래) 두 타일의 1/4 코사인 곡선이 세로로 이어져 벽 밑끝이
#   둥글게 잔디로 물러난다. 전부 SOLID(절벽 못 넘음). 아트=make_cliff_corners.py 절차 파생(§10.1 방침).
const CLIFF_CORNER_SW := 22   # 남서 벽면 곡선(Face 톤, SOLID)
const CLIFF_CORNER_SW_B := 23 # 남서 밑동 곡선(Base 톤, SOLID)
const CLIFF_CORNER_SE := 24   # 남동 벽면 곡선(Face 톤, SOLID)
const CLIFF_CORNER_SE_B := 25 # 남동 밑동 곡선(Base 톤, SOLID)
const N_TILES := 26

# ── P2.3 지형 도트: terrain TileSet + 실내/벽 도트 source ───────────────────
# combined_terrain_homestead.tres = PixelLab Wang 4세트(풀↔길·길↔밭·밭↔풀·물↔풀)를 합친
# corner 오토타일. 안식 농원 구역 지형셋(스타듀 룩 재생성, tileset-ruleset §5 스펙 카드).
# terrain_set_0의 terrain 순서는 컨버터 인자 순서로 고정(0=길,1=풀,2=밭,3=물).
# GROUND/PATH/SOIL은 이 terrain으로 자동 전환해 칠하고, HOUSE/CAFE/WALL(실내·벽)은
# 전환이 필요 없는 단일 면이라 별도 source(SOLID)에 16×16 도트 타일로 깐다.
const TERRAIN_TILESET_PATH := "res://assets/tiles/combined_terrain_homestead.tres"
const TERRAIN_SET := 0
const TR_PATH := 0    # dirt path
const TR_GRASS := 1   # muted grass
const TR_SOIL := 2    # tilled farm soil
const TR_WATER := 3   # ★T2 — 저승 물(피안절 톤 물↔풀 Wang). 컨버터 4번째 쌍(water_grass)이 terrain id 3으로 고정.
# 타일 종류 → terrain id(GROUND/PATH/SOIL/WATER를 terrain으로 칠한다)
# ★T2 — WATER를 SOLID 단색 절차 타일에서 corner terrain으로 승격(물 Wang 스파이크 게이트). 통과 불가
#   충돌은 유지(아트만 — 충돌은 _build_tileset이 source 0 물 타일에 단다). 풀↔물 경계가 corner 전환된다.
const TILE_TERRAIN := {GROUND: TR_GRASS, PATH: TR_PATH, SOIL: TR_SOIL, WATER: TR_WATER}
# 실내/벽 source: 별도 source_id에 HOUSE/CAFE/WALL 등 단일 면 타일만 둔다.
const SOLID_SRC_ID := 1
# ★[ADR-0043] 길 디테일 source — 길 base 톤에 절차적 다짐 결+잔자갈을 입힌 변종 3종(owner: "길 너무 깨끗").
#   길 칸은 결정적 해시로 이 변종 중 하나를 깐다(그리드 반복 방지·임의 아님). 충돌 없음(걷는 길).
const PATH_SRC_ID := 2
const PATH_VARIANTS := 3
# ★[ADR-0043 §6 후속] 건물 둘레 갈색 path 링 제거는 grass 직접 채우기(솔버 0)로 흡수됨 — RING_FIX 폐지.
const SOLID_TILES := [HOUSE, CAFE, WALL, HOUSE_WALL, CAFE_WALL, TREE, ROCK,
	CLIFF_FACE, CLIFF_LIP, CLIFF_FACE_BASE, CLIFF_BANK,
	BARN_FLOOR, BARN_WALL, COOP_FLOOR, COOP_WALL, STOREHOUSE_FLOOR, STOREHOUSE_WALL,
	CLIFF_CORNER_SW, CLIFF_CORNER_SW_B, CLIFF_CORNER_SE, CLIFF_CORNER_SE_B]   # 아틀라스 가로 배치 순서(= atlas x)
# ★ [S1-2] 통과 불가 타일의 단일 진실원(SOLID). _build_tileset 충돌 루프 + is_solid()가 이걸 참조해
#   충돌 정의 중복을 제거한다(옛 하드코딩 리스트 대체). 주의:
#   · WATER는 terrain corner라 여기 없고 _has_water_corner로 따로 판정(회귀 보존).
#   · HOUSE/CAFE는 SOLID_TILES(단일 면 아틀라스) 멤버지만 걷는 바닥이라 여기 없음(충돌 없음).
#   · CLIFF_LIP은 아틀라스엔 있으나 걷기 O라 여기서 제외(충돌 없음). CLIFF_FACE_BASE는 신규 SOLID.
const WORLD_SOLID_TILES := [WALL, HOUSE_WALL, CAFE_WALL, TREE, ROCK,
	CLIFF_FACE, CLIFF_FACE_BASE, CLIFF_BANK,
	BARN_WALL, COOP_WALL, STOREHOUSE_WALL,
	CLIFF_CORNER_SW, CLIFF_CORNER_SW_B, CLIFF_CORNER_SE, CLIFF_CORNER_SE_B]   # ★[ADR-0048] 실내 벽 3종 + [단계3-④] 곡선 코너 4종도 통과 X
# ★[ADR-0053/0054 흙-지배 flip 리그레션 픽스] 절벽 계열 전체(LIP 오버행·FACE·BASE·BANK·곡선코너 = 전부
#   자체 SOLID_TEX로 렌더). 지면 오버레이(_build_ground16/_ground_detail_tex)가 이 셀을 tan/잔디로 덮으면
#   타일맵 절벽이 사라진다 → _g16_surface가 -1(투명)로 분류해 밑 절벽 텍스처가 비치게 한다(HOUSE/CAFE 결).
const CLIFF_TILES := [CLIFF_FACE, CLIFF_LIP, CLIFF_FACE_BASE, CLIFF_BANK,
	CLIFF_CORNER_SW, CLIFF_CORNER_SW_B, CLIFF_CORNER_SE, CLIFF_CORNER_SE_B]
# ★ T2 — WATER는 더 이상 SOLID가 아니다(terrain으로 승격). TREE/ROCK는 아직 SOLID 단색(도트는 후속 T7~T9).
# ★ M4.1 — TREE도 같은 결(도트 텍스처 없음 → COLORS 단색 절차 생성, 통과 불가 충돌). 숲 무대의 밀집 나무.
# ★ M5.1 — ROCK도 같은 결(도트 텍스처 없음 → COLORS 단색 절차 생성, 통과 불가 충돌). 갱도 무대의 바위 절벽·암반.
# P2.3② 단색 교체: 실내 바닥·벽을 도트 타일(create_tiles_pro 산출 16×16 PNG)로 깐다.
# 아틀라스 결은 단색 시절과 동일(SOLID_SRC_ID 가로 배치) — _build_tileset이 fill 대신
# 이 텍스처를 blit한다. WALL 충돌·칠 순서는 불변(지형 위에 덮어 깔기 그대로).
const SOLID_TEX := {
	HOUSE: "res://assets/tiles/house_floor.png",  # 허니톤 나무 마루(아늑한 집 바닥)
	CAFE: "res://assets/tiles/cafe_floor.png",    # 다크 월넛 헤링본 파켓(앤틱 카페 바닥)
	WALL: "res://assets/tiles/wall.png",          # 어두운 회청 벽돌(외벽·외관 공용)
	HOUSE_WALL: "res://assets/tiles/house_wall.png",  # 나무·크림 wainscoting(아늑한 집 벽)
	CAFE_WALL: "res://assets/tiles/cafe_wall.png",    # 버건디·우드 패널(앤틱 카페 벽)
	# ★ [S1-10] 다단 절벽 흙 세트(cliff-tileset-spec.md, PixelLab tiles_pro → 청키·warm 흙+풀오버행).
	#   LIP=고지 풀 오버행(밝은 상단) / FACE=흙 strata 벽 / FACE_BASE=어두운 접지+SE 슬레이트 그림자.
	#   옛 회색 암석 cliff_face.png 폐기. LIP은 걷기 O지만 렌더 텍스처 필요(placeholder 색 제거).
	CLIFF_FACE: "res://assets/tiles/cliff_s_face.png",
	CLIFF_LIP: "res://assets/tiles/cliff_s_lip.png",
	CLIFF_FACE_BASE: "res://assets/tiles/cliff_s_base.png",
	CLIFF_BANK: "res://assets/tiles/cliff_bank.png",  # [S1-10 §2] 물가 강둑(흙+돌 ledge)
	# ★ [ADR-0048 §2] 건물 실내 전용 바닥·벽(make_interior_tiles.py 절차 — 16 논리×2 청키·이음새 없음).
	BARN_FLOOR: "res://assets/tiles/barn_floor.png",              # 넋우릿간 바닥(다진 흙+볏짚)
	BARN_WALL: "res://assets/tiles/barn_wall.png",                # 넋우릿간 벽(세로 어두운 판재)
	COOP_FLOOR: "res://assets/tiles/coop_floor.png",              # 넋둥우리 바닥(밝은 볏짚)
	COOP_WALL: "res://assets/tiles/coop_wall.png",                # 넋둥우리 벽(가로 밝은 널빤지)
	STOREHOUSE_FLOOR: "res://assets/tiles/storehouse_floor.png",  # 갈무리방 바닥(돌 판석)
	STOREHOUSE_WALL: "res://assets/tiles/storehouse_wall.png",    # 갈무리방 벽(쌓은 돌켜)
	# ★[단계3-④] 남향 절벽 곡선 코너(make_cliff_corners.py 절차 파생 — cliff_s_face/base + lip 풀 곡선 전이)
	CLIFF_CORNER_SW: "res://assets/tiles/cliff_corner_sw.png",
	CLIFF_CORNER_SW_B: "res://assets/tiles/cliff_corner_sw_b.png",
	CLIFF_CORNER_SE: "res://assets/tiles/cliff_corner_se.png",
	CLIFF_CORNER_SE_B: "res://assets/tiles/cliff_corner_se_b.png",
}

# ── T2.1/T2.3 밭 오버레이 타일(Field 레이어 아틀라스 인덱스) ───────────────
# Ground의 SOIL 위에 겹쳐 그리는 칸 상태 표시. 미경작 칸은 오버레이 없음(맨 흙).
# 인덱스 = 외형단계(APPEAR) × 2 + 젖음(0 마름 / 1 젖음). 코드로 한 번에 생성한다.
#   외형단계: 0=빈 고랑(작물 없음) / 1=씨앗 / 2=새싹 / 3=수확가능
# ADR-0013/작물 연결: 오버레이는 흙 고랑(DRY/WET 톤)만 그린다. 성장단계 시각은 더 이상
# 그레이박스 점이 아니라 _draw_crops가 작물 스프라이트(seed/sprout/mature)로 얹는다.
# 외형단계 인덱스는 _overlay_index 호환을 위해 유지하되, 8타일 모두 흙 톤만 다르다(젖음).
const AP_EMPTY := 0    # 경작만(고랑)
const AP_SEED := 1     # 갓 심음
const AP_SPROUT := 2   # 자라는 중
const AP_MATURE := 3   # 다 자람(수확 가능)
const N_APPEAR := 4
const N_OV := N_APPEAR * 2  # 외형 4 × 젖음 2 = 8타일

# (경작 고랑 DRY/WET 색은 밭흙 terrain base에서 파생 — _build_field_tileset 참조)
# ── 작물 스프라이트(ADR-0013: 32px native, P2.2 산출) — 성장단계별 3프레임 ──────
# field.growth_stage(t): 0=씨앗 / 1=새싹 / 2=수확가능 → 이 배열의 같은 인덱스 프레임.
# 작물 id(CropCatalog)별로 묶어 _draw_crops가 심긴 칸 위에 바닥정렬로 그린다.
const CROP_SPRITES := {
	CropCatalog.HONRYEONGCHO: [
		preload("res://assets/crops/honryeongcho_seed.png"),
		preload("res://assets/crops/honryeongcho_sprout.png"),
		preload("res://assets/crops/honryeongcho_mature.png"),
	],
	CropCatalog.PIANHWA: [
		preload("res://assets/crops/pianhwa_seed.png"),
		preload("res://assets/crops/pianhwa_sprout.png"),
		preload("res://assets/crops/pianhwa_mature.png"),
	],
	CropCatalog.YEONGHON_HOBAK: [
		preload("res://assets/crops/yeonghon_hobak_seed.png"),
		preload("res://assets/crops/yeonghon_hobak_sprout.png"),
		preload("res://assets/crops/yeonghon_hobak_mature.png"),
	],
	# ★ [S1-5a] 황천포도 = 트렐리스 작물. 프레임은 32×64(밑동 접지·위로 1칸 솟음, _draw_crops 트렐리스 훅).
	CropCatalog.HWANGCHEON_PODO: [
		preload("res://assets/crops/hwangcheon_podo_seed.png"),
		preload("res://assets/crops/hwangcheon_podo_sprout.png"),
		preload("res://assets/crops/hwangcheon_podo_mature.png"),
	],
	# ★ [S1-4] 불사과 = 다절기 프레스티지(표준 32² 3프레임 — 트렐리스 아님).
	CropCatalog.BULSAGWA: [
		preload("res://assets/crops/bulsagwa_seed.png"),
		preload("res://assets/crops/bulsagwa_sprout.png"),
		preload("res://assets/crops/bulsagwa_mature.png"),
	],
}

# ── ★ [S1-5b/S1-10] 혼의 나무 과수 스프라이트 — 종별 3단계 프레임(96×160=3타일폭×5높이, bottom-center
#   앵커). _draw_orchard가 단계(0=묘목/1=성목/2=결실)로 인덱싱. 그레이박스 정준 1종(혼백도)만.
const ORCHARD_SPRITES := {
	FruitTreeCatalog.HONBAEKDO: [
		preload("res://assets/crops/honbaekdo_sapling.png"),
		preload("res://assets/crops/honbaekdo_growing.png"),
		preload("res://assets/crops/honbaekdo_fruiting.png"),
	],
}

# 비-작물 CAT_HARVEST 수확물 인벤 아이콘(32²) — 과일·가축 산물은 CropCatalog에 없어 CROP_SPRITES 밖.
# 핫바·출하함·알림 아이콘 맵에 병합(CAT_HARVEST id로 조회). 대형 산물(_large)은 기준 아이콘 재사용
# (_item_icon·hotbar._draw_crop_tex가 _large_base로 접미 벗겨 조회). _draw_crop_tex가 crop_icons.get(id)로 찾는다.
const EXTRA_ICONS := {
	FruitTreeCatalog.HONBAEKDO: preload("res://assets/crops/honbaekdo.png"),   # 혼백도(혼의 나무 과일)
	AnimalCatalog.HONBAEK_RAN: preload("res://assets/crops/honbaek_ran.png"),  # 노을알(노을닭 산물)
	AnimalCatalog.HONBAEK_YU: preload("res://assets/crops/honbaek_yu.png"),    # 안개젖(안개소 산물)
}

# ★ [아트정리패스, ADR-0048 개정 §1] 도구 아이콘 5종 — 옛 임시 색박스(tool_color_of) 대체.
# 아이콘만(핫바·인벤); 휘두름/손든 스프라이트는 캐릭터 시트 재생성 트랙 defer(도구-사용 애니 부재).
# id "hoe" 등은 crop id와 불충돌하므로 icons dict(범용 id→아이콘 맵)에 병합해 _draw_icon이 조회한다.
const TOOL_ICONS := {
	ItemCatalog.HOE: preload("res://assets/tools/hoe.png"),                     # 괭이
	ItemCatalog.WATERING_CAN: preload("res://assets/tools/watering_can.png"),  # 물뿌리개
	ItemCatalog.SCYTHE: preload("res://assets/tools/scythe.png"),              # 낫
	ItemCatalog.PICKAXE: preload("res://assets/tools/pickaxe.png"),            # 곡괭이
	ItemCatalog.AXE: preload("res://assets/tools/axe.png"),                    # 도끼
}

# ★ [아트정리패스] 비료 아이콘 5종(색박스 대체 — PixelLab, S1-6 카탈로그 2군 XOR).
# 품질군 3(기초·품질·디럭스=삼베 포대·등급 액센트 상승) / 성장촉진군 2(성장촉진·하이퍼=영혼빛 물약병).
# TOOL_ICONS와 동형: icons dict에 병합→hotbar·inv_frame `_draw_icon` CAT_FERTILIZER 텍스처화(색박스 폴백).
const FERT_ICONS := {
	FertilizerCatalog.FERT_BASIC: preload("res://assets/fertilizer/fert_basic.png"),      # 기초 비료
	FertilizerCatalog.FERT_QUALITY: preload("res://assets/fertilizer/fert_quality.png"),  # 품질 비료
	FertilizerCatalog.FERT_DELUXE: preload("res://assets/fertilizer/fert_deluxe.png"),    # 디럭스 비료
	FertilizerCatalog.FERT_SPEED: preload("res://assets/fertilizer/fert_speed.png"),      # 성장촉진 비료
	FertilizerCatalog.FERT_HYPER: preload("res://assets/fertilizer/fert_hyper.png"),      # 하이퍼 비료
}

# ★ [아트정리패스] 묘목 아이콘(색박스 대체 — PixelLab). 과수 종당 1개("<과일종>_sapling", S1-5b 규약).
# 현재 혼백도 1종. TOOL/FERT_ICONS와 동형: icons 병합→inv_frame·hotbar `_draw_icon` CAT_SAPLING 텍스처화.
const SAPLING_ICONS := {
	"honbaekdo_sapling": preload("res://assets/saplings/honbaekdo_sapling.png"),   # 혼백도 묘목
}

# 각 타일의 그레이박스 색(밝기·미세 색조로만 구분, 회색 기조 유지). WALL이 가장 밝다.
const COLORS := [
	Color(0.16, 0.18, 0.16),  # GROUND — 어두운 풀밭 톤
	Color(0.46, 0.43, 0.38),  # PATH   — 밝은 흙길(동선이 눈에 띄게)
	Color(0.31, 0.25, 0.20),  # SOIL   — 갈색 밭흙
	Color(0.33, 0.32, 0.41),  # HOUSE  — 푸른 실내
	Color(0.42, 0.37, 0.30),  # CAFE   — 따뜻한 실내
	Color(0.56, 0.56, 0.62),  # WALL   — 가장 밝은 회색(외벽)
	Color(0.0, 0.0, 0.0),     # VOID   — 검정(실내 방 바깥 여백, 실제로는 안 그려 배경이 비친다)
	Color(0.40, 0.34, 0.28),  # HOUSE_WALL — 따뜻한 나무 톤(폴백)
	Color(0.30, 0.16, 0.18),  # CAFE_WALL  — 버건디 톤(폴백)
	Color(0.16, 0.28, 0.42),  # WATER  — ★T2 후 미사용(terrain으로 승격). 폴백·과거 참조용 잔존.
	Color(0.11, 0.20, 0.13),  # TREE   — 저승 숲 나무(어두운 침엽 녹 — 풀 GROUND보다 짙어 빈터와 구분, 그레이박스)
	Color(0.34, 0.22, 0.20),  # ROCK   — 업화 갱도 바위(불그스름한 암반 — 풀 GROUND보다 따뜻해 빈터와 구분, 그레이박스)
	Color(0.30, 0.27, 0.24),  # CLIFF_FACE     — 절벽 단면(SOLID_TEX 있음 — 폴백 미사용, 인덱스 정렬용)
	Color(0.50, 0.54, 0.42),  # CLIFF_LIP       — ★S1-2 밝은 하이라이트 톤(고지 밑단·걷기 O — pseudo-Z 상단이 밝게)
	Color(0.19, 0.16, 0.14),  # CLIFF_FACE_BASE — ★S1-2 어두운 접지 톤(SOLID·접지 그림자 — 3티어 최하 명암)
	Color(0.28, 0.26, 0.28),  # CLIFF_BANK      — ★S1-10 물가 강둑(SOLID_TEX 있음 — 폴백 미사용, 인덱스 정렬용)
	# ★[ADR-0048 §2] 실내 전용 타일(전부 SOLID_TEX 있음 — 폴백 미사용, 인덱스 정렬용)
	Color(0.34, 0.26, 0.18),  # BARN_FLOOR      — 다진 흙 톤
	Color(0.36, 0.26, 0.17),  # BARN_WALL       — 어두운 판재 톤
	Color(0.66, 0.54, 0.31),  # COOP_FLOOR      — 밝은 볏짚 톤
	Color(0.59, 0.45, 0.29),  # COOP_WALL       — 밝은 널빤지 톤
	Color(0.43, 0.41, 0.38),  # STOREHOUSE_FLOOR — 회색 판석 톤
	Color(0.39, 0.37, 0.34),  # STOREHOUSE_WALL  — 돌켜 톤
	# ★[단계3-④] 곡선 코너(전부 SOLID_TEX 있음 — 폴백 미사용, 인덱스 정렬용). Face=벽면 톤·B=밑동 톤.
	Color(0.30, 0.27, 0.24),  # CLIFF_CORNER_SW
	Color(0.19, 0.16, 0.14),  # CLIFF_CORNER_SW_B
	Color(0.30, 0.27, 0.24),  # CLIFF_CORNER_SE
	Color(0.19, 0.16, 0.14),  # CLIFF_CORNER_SE_B
]

# ── 실내 가구·장식(create_map_object 산출, ADR-0013: 32px raw native 직접 사용) ────
# 손님·잡귀처럼 노드 없이 main의 _draw에서 바닥정렬로 그린다(캐릭터·손님 *아래* —
# props를 가장 먼저 그려 자식 노드들이 위에 올라온다). 충돌은 없다(WALL 타일만 충돌,
# 가구는 순수 장식 — art 패스라 새 시스템·이동 변화 금지). 침대만 32×64(1×2칸), 나머지는
# 32×32. 카운터=좌석(스툴) 뒤·직원 앞 줄(바 배치) / 선반=뒷벽 / 등불·화분=구역 분위기.
const PROP_BED := preload("res://assets/props/house_bed.png")        # 32×64
const PROP_COUNTER := preload("res://assets/props/cafe_counter.png")
const PROP_STOOL := preload("res://assets/props/cafe_stool.png")
const PROP_SHELF := preload("res://assets/props/cafe_shelf.png")
const PROP_LANTERN := preload("res://assets/props/soul_lantern.png")
const PROP_POT := preload("res://assets/props/spirit_pot.png")
# ★ T3③ 스타듀식 입체 북벽 — 집 방 북쪽을 2타일 벽 밴드로(y67 plank 상단벽 + y68 wainscoting 걸레받이).
#   plank 텍스처를 _draw_house_wall_band가 y67 행에 깔고(가구 *아래*), 가구가 그 위로 솟아 벽을 덮는다
#   (스타듀 2.5D — 벽에 밀착·입체). 가로 타일(좌우 이음매 0)이라 방 폭만큼 반복해 그린다.
const TEX_HOUSE_WALL_BAND := preload("res://assets/tiles/house_wall_upper.png")
# 집 실내 가구(넓은 방을 아늑하게 채운다, PixelLab 산출 32px native). 러그 96×64(3×2칸),
# 벽난로·책장 64×64(2×2칸), 테이블 32×32(1칸). 충돌 없는 순수 장식(손님·가구와 같은 결).
const PROP_RUG := preload("res://assets/props/house_rug.png")
const PROP_FIREPLACE := preload("res://assets/props/house_fireplace.png")
const PROP_BOOKSHELF := preload("res://assets/props/house_bookshelf.png")
const PROP_TABLE := preload("res://assets/props/house_table.png")
# 카페 실내 앤틱 가구(넓은 방을 채운다, PixelLab 산출). 괘종시계 32×64, 와인 캐비닛 64×64,
# 액자·카페 테이블 32×32. 모두 충돌 없는 순수 장식(어두운 우드·버건디 — 앤틱 카페 톤).
const PROP_FRAME := preload("res://assets/props/cafe_frame.png")
const PROP_CLOCK := preload("res://assets/props/cafe_clock.png")
const PROP_CABINET := preload("res://assets/props/cafe_cabinet.png")
const PROP_CAFE_TABLE := preload("res://assets/props/cafe_table.png")
# ★ Phase 2.8 T3 — 안식 농원 외부 농장 장식(PixelLab create_map_object, 32px native·피안절 무채도 톤).
# 충돌·세이브 없는 순수 장식(_draw_props_for) — 밭을 '농장'으로 읽히게 프레임한다(밀도 상한 4종).
const PROP_FENCE := preload("res://assets/props/farm_fence.png")              # 32×32 — 밭 경계 울타리(가로 레일·통과 불가 SOLID)
const PROP_SCARECROW := preload("res://assets/props/farm_scarecrow.png")      # 32×64 — 허수아비(1×2칸) 밑 1칸 SOLID·위 1칸 통과+fade(나무·바위 인프라)
const PROP_PLANTER := preload("res://assets/props/farm_planter.png")          # 32×32 — 길가 화분
const PROP_FLOWER_PATCH := preload("res://assets/props/spirit_flower_patch.png")  # 32×32 — 꽃 패치(피안화)
# ★ Phase 2.8 T3⑤ — 안식 농원 테두리 프레이밍 장식(PixelLab create_map_object, 피안절 톤 통일
# retone_props_p28t3.py). 나무·바위 = 통과 불가 SOLID(맵 경계 벽 — 채집·채광 상호작용은 Phase 3).
# 풀·덤불·그루터기 = 통과 가능 순수 장식. 가장자리·빈 코너만 두르고 밭·동선은 연다(테두리 프레이밍).
const PROP_TREE_A := preload("res://assets/props/tree_spirit_a.png")    # ★[roster] 64×128 — 저승 봄나무 침엽(2×4칸): 밑둥 1칸 SOLID·수관 통과+occlusion fade
const PROP_TREE_B := preload("res://assets/props/tree_spirit_b.png")    # ★[roster] 64×128 — 저승 봄나무 활엽(2×4칸): 밑둥 1칸 SOLID·수관 통과+occlusion fade
const PROP_GRASS := preload("res://assets/props/grass_tuft.png")        # 32×32 — 풀 무더기(장식)
const PROP_BUSH := preload("res://assets/props/bush.png")               # 64×64 — 덤불(2×2칸, 장식)
const PROP_ROCK := preload("res://assets/props/rock.png")               # 64×64 — 바위·돌(2×2칸, SOLID)
# ★[prop-regen-roster §5.3 / owner 2026-07-04~05] 통나무(logs) 5종 재생성(PixelLab create_1_direction_object
#   → tools/_logs_build.py 정규화). 옛 PROP_STUMP(단일 그루터기, 맵 미배치)를 대체(stump_log.png 폐기).
#   ★통과 불가 SOLID(owner "통나무 통과X"). 크기가 3종(96×32/64×32/32×32)이라 debris식 변주배열이
#   아니라 개별 프롭으로 배선(발치·Y-Sort·충돌이 크기 파생). 코드 그림자(_draw_prop_shadow 타원)만 얹는다.
const PROP_LOG_LONG := preload("res://assets/props/stump_log_long.png")        # 96×32 — 긴 통나무(3×1칸, ㅡ자)
const PROP_LOG_SHORT := preload("res://assets/props/stump_log_short.png")      # 64×32 — 짧은 통나무(2×1칸)
const PROP_LOG_UPRIGHT := preload("res://assets/props/stump_log_upright.png")  # 32×32 — 세워진 그루터기(1×1칸, 위 나이테)
const PROP_LOG_DIAG_A := preload("res://assets/props/stump_log_diag_a.png")    # 32×32 — 대각 통나무 밝은(1×1칸, ＼)
const PROP_LOG_DIAG_B := preload("res://assets/props/stump_log_diag_b.png")    # 32×32 — 대각 통나무 어두운(1×1칸, ／)
# ★[roster 2026-07-04] 덤불 능선 수풀 2변주(어두운 톱니+베리 / 밝은 라임 dome — PixelLab 32-native 재생성,
#   owner 레퍼런스). debris와 동일한 좌표 결정적 해시로 능선에서 dark↔bright 교대(단조로움 완화). 순수 시각 —
#   크기 64×64 동일·PROP_BUSH 정체성(PROP_SHADOW_SET·레지스트리·_ridge_body 통행·배치 좌표) 전부 불변.
const PROP_BUSH_V2 := preload("res://assets/props/bush_v2.png")         # 64×64 — 덤불 밝은 라임 변주
const BUSH_VARIANTS := {
	PROP_BUSH: [PROP_BUSH, PROP_BUSH_V2],
}
# ★ ADR-0035 Phase B — 안식 재설계 신규 PROP(Phase A 마스터 스타일 생성). 계단·넝쿨·덤불 덮개·debris 3종.
const PROP_STAIRS := preload("res://assets/props/stairs_east.png")      # ★S1-10 96×64 동향 돌계단(고지=서/왼쪽↔저지=동/오른쪽, 노치 3칸 폭, 통과 O). 옛 남향 stairs.png placeholder 교체
const PROP_VINE := preload("res://assets/props/vine.png")               # 32×64 — 넝쿨(절벽 이음매 덮개, 통과 O)
const PROP_DEBRIS_WEEDS := preload("res://assets/props/debris_weeds.png")          # 32×32 — 이승의 미련·잡초(낫, 통과 O 장식)
const PROP_DEBRIS_EMBER := preload("res://assets/props/debris_ember_stone.png")    # ★[roster §5.2] 32×32(1칸, 64→32 축소) — 업화석(곡괭이, 통과 X SOLID)
const PROP_DEBRIS_STUMP := preload("res://assets/props/debris_petrified_stump.png")  # ★[roster §5.2] 32×32(1칸) — 석화 고목(도끼, 통과 X SOLID)
# ★ [S1-8] 개간 debris 텍스처 → DebrisCatalog kind. 배치(어느 타일에 무슨 debris)는 PROP_LAYOUT_HOME
#   시드에 잠겨 있고, 여기서 텍스처로 kind를 역인한다. 드로우/충돌 skip-filter·개간 디스패치가 참조한다.
#   ※ PROP_STUMP(장식 통나무)는 여기 없음 = debris 아님(치울 수 없는 순수 장식).
const DEBRIS_KIND := {
	PROP_DEBRIS_WEEDS: DebrisCatalog.WEEDS,
	PROP_DEBRIS_EMBER: DebrisCatalog.EMBER,
	PROP_DEBRIS_STUMP: DebrisCatalog.STUMP,
}
# ★ [roster §5.2 / ADR-0050] 32-native 재생성 — kind별 3변주(좌표해시로 결정적 선택 → 같은 kind가 맵에서
#   3형태로 다양). 정체성 토큰(위 const=v1)은 DEBRIS_KIND·SOLID_PROPS·충돌·reclaim가 그대로 키잉하고,
#   변주는 *순수 그리기 관심사*(3장 전부 32×32 동일 크기라 발치·그림자·Y-split·충돌 불변).
const PROP_DEBRIS_WEEDS_V2 := preload("res://assets/props/debris_weeds_v2.png")
const PROP_DEBRIS_WEEDS_V3 := preload("res://assets/props/debris_weeds_v3.png")
const PROP_DEBRIS_EMBER_V2 := preload("res://assets/props/debris_ember_stone_v2.png")
const PROP_DEBRIS_EMBER_V3 := preload("res://assets/props/debris_ember_stone_v3.png")
const PROP_DEBRIS_STUMP_V2 := preload("res://assets/props/debris_petrified_stump_v2.png")
const PROP_DEBRIS_STUMP_V3 := preload("res://assets/props/debris_petrified_stump_v3.png")
const DEBRIS_VARIANTS := {
	PROP_DEBRIS_WEEDS: [PROP_DEBRIS_WEEDS, PROP_DEBRIS_WEEDS_V2, PROP_DEBRIS_WEEDS_V3],
	PROP_DEBRIS_EMBER: [PROP_DEBRIS_EMBER, PROP_DEBRIS_EMBER_V2, PROP_DEBRIS_EMBER_V3],
	PROP_DEBRIS_STUMP: [PROP_DEBRIS_STUMP, PROP_DEBRIS_STUMP_V2, PROP_DEBRIS_STUMP_V3],
}
# ★[asset-ruleset §11] 접지 그림자 대상 = 부피 있는 야외 바닥 프롭. 스프라이트에 굽지 않고
#   별도 반투명 타원을 밑단 아래에 깔아 "뜬 느낌"을 없앤다(건물 facade는 _blit_facade_anchored가
#   자체 처리). 납작한 소품(풀·꽃·잡초·울타리·화분·계단·넝쿨·러그·등불)과 실내 벽 가구는 제외 —
#   높이가 낮아 그림자가 어색하고 사인오프된 실내 배치를 건드리지 않기 위함.
const PROP_SHADOW_SET := [PROP_TREE_A, PROP_TREE_B, PROP_ROCK, PROP_BUSH,
	PROP_DEBRIS_EMBER, PROP_DEBRIS_STUMP, PROP_SCARECROW,
	PROP_LOG_LONG, PROP_LOG_SHORT, PROP_LOG_UPRIGHT, PROP_LOG_DIAG_A, PROP_LOG_DIAG_B]  # ★통나무 5종 접지 그림자
# ★ 지면 디테일(지형별 확률 시스템 — docs/design/ground-composition.md). 결정적 절차 배치로
#   GROUND/PATH 칸마다 자기 지형 테이블로 가중 1롤 → 베이스 위에 디테일을 *구역 빌드 때 1회 베이크*
#   (런타임 정적 오버레이, _draw에서 1 draw call). 손배치 grass_tuft 폐기 → 이 시스템이 대체.
const GD_GRASS1 := preload("res://assets/props/ground_grass1.png")     # 잔디 1단계(짧은 풀포기)
const GD_GRASS2 := preload("res://assets/props/ground_grass2.png")     # 잔디 2단계(중간)
const GD_GRASS3 := preload("res://assets/props/ground_grass3.png")     # 잔디 3단계(더 자란 덤불)
const GD_WEED_U := preload("res://assets/props/ground_weed_under.png") # 저승 잡초
const GD_WEED_D := preload("res://assets/props/ground_weed_dry.png")   # 노란 마른 잡초
const GD_FLOWER := preload("res://assets/props/ground_flower.png")     # 영혼 들꽃
const GD_PEBBLE := preload("res://assets/props/ground_pebble.png")     # 잔돌
const GD_DIRT := preload("res://assets/props/ground_dirt.png")         # 맨 흙 패치
const GD_GRAVEL := preload("res://assets/props/ground_gravel.png")     # 길 자갈 무리
const GD_EMBED := preload("res://assets/props/ground_embed.png")       # 길 박힌 잔돌
const GD_CRACK := preload("res://assets/props/ground_crack.png")       # 길 갈라짐·바퀴자국
# ★[스캐터 재생성 2026-07-16 — scatter-asset-regen-analysis.md] 스타듀 초기 농장식 다종 스캐터.
#   PixelLab create_map_object(single color outline·basic shading·high top-down·32-native, 저색·크리스프).
#   잡초/풀만이 아니라 갈색 twig·회색 stone이 tan을 색대비로 깨는 밀도의 핵심. Style A(debris)와 동일 규율.
const GD_TWIG1 := preload("res://assets/props/scatter_twig_a.png")     # 마른 교차 나뭇가지(진한 외곽선)
const GD_TWIG2 := preload("res://assets/props/scatter_twig_b.png")     # 잎 달린 가지(변주)
const GD_STONE1 := preload("res://assets/props/scatter_stone_a.png")   # 돌 3개 무리
const GD_STONE2 := preload("res://assets/props/scatter_stone_b.png")   # 단독 슬레이트
# ★[단계3-③ / owner Gemini 가이드 2차] 풀 클러스터 노이즈 레버 — 스타듀식 "민무늬 베이스 80~90% +
#   특정 영역에만 풀 덩어리". _gd_cluster(x,y) < GD_CLUSTER_CUT인 넓은 영역은 풀 포기 없이 민무늬로 비운다.
#   CUT↑ = 풀 영역 축소(여백↑). BLOCK = 덩어리 크기(칸). GROUND만 게이트(길은 자체 밀도).
const GD_CLUSTER_CUT := 0.60     # 이 노이즈값 미만 = 민무늬 베이스(풀 포기 skip)
const GD_CLUSTER_BLOCK := 5      # 저주파 블록 크기(클수록 큰 덩어리)
# 지형 종류 → 디테일 테이블. 항목 = [텍스처(null=맨 타일), 가중치, SE그림자]. (§3.1 잔디 / §3.2 길)
var _GD_TABLES := {
	# ★ [ADR-0042] 증분2 — 큰 청키 클럼프(GD_GRASS3 덤불) 폐기 → 작은 *부드러운* tuft 위주.
	#   잔디 풀포기는 그림자 없이(평면, 스타듀 tuft) 베이스에 녹이고(_gd_soft_image로 저대비·반투명),
	#   잡초·꽃·잔돌만 미세 그림자로 살짝 입체. 맨 잔디 비중 ↑(스타듀식 여백·차분함).
	GROUND: [
		[null, 44, false],                  # 맨 잔디(대부분 — 차분한 여백)
		[GD_GRASS1, 30, false],             # 짧은 풀포기 — 주력(소프트·평면·좌우반전 변종)
		[GD_GRASS2, 5, false],              # 중간 풀포기(소프트·평면·드문 warm 액센트)
		[GD_WEED_U, 4, false],              # 저승 잡초(작게·소프트)
		[GD_WEED_D, 3, true],               # 노란 마른 잡초(액센트)
		[GD_FLOWER, 2, true],               # 영혼 들꽃(희소)
		[GD_PEBBLE, 1, true],               # 잔돌(극희소)
		# ★[후속 배치 2026-07-17] GD_DIRT(맨 흙 패치) 제거 — PixelLab 재생성이 평면 흙패치를 계속
		#   보라빛 입체 블롭으로 뽑아 실패. tan 베이스 위 극희소(가중1)라 손실 미미 → 나쁜 에셋 대신 렌더 제외.
		# ★[스캐터 재생성] 스타듀식 갈색 twig·회색 stone 다종(색대비로 tan 밀도) — 크리스프(mute 대상 아님)
		[GD_TWIG1, 4, false],               # 마른 교차 나뭇가지(평면)
		[GD_TWIG2, 3, false],               # 잎 가지 변주(평면)
		[GD_STONE1, 4, true],               # 돌 3개 무리(미세 그림자)
		[GD_STONE2, 3, true],               # 단독 슬레이트(미세 그림자)
	],
	PATH: [
		[null, 78, false],                  # 맨 길(대부분)
		[GD_EMBED, 9, false],               # 박힌 잔돌(재생성 크리스프)
		# ★[후속 배치 2026-07-17] GD_GRAVEL 제거 — PixelLab이 흩뿌린 자갈을 계속 입체 블롭으로 뽑아 실패.
		#   얇은 길 디테일이라 embed(박힌 잔돌)+crack으로 충분 → Style B 블러 자갈 렌더 제외.
		[GD_CRACK, 4, false],               # 갈라짐·바퀴자국(재생성 크리스프 크랙)
		[GD_WEED_D, 3, true],               # 가장자리 마른 풀
	],
}
# ★[스캐터 확산 2026-07-16 — ②tan 전역] 빈 tan(클러스터 게이트 밖)에 뿌리는 *마른 clutter* 테이블.
#   스타듀 초기 농장은 나뭇가지·돌을 밭 전역에 흩뿌린다(풀 tuft는 무리에만). 풀 없이 twig·stone·잔돌·마른잡초만.
#   null 없음(밀도는 _GD_SPARSE_DENSITY 해시 게이트가 담당 — 통과 셀은 반드시 1개 clutter).
var _GD_SPARSE := [
	[GD_TWIG1, 5, false],   # 마른 교차 나뭇가지
	[GD_TWIG2, 3, false],   # 잎 가지
	[GD_STONE1, 4, true],   # 돌 무리
	[GD_STONE2, 4, true],   # 단독 슬레이트
	[GD_PEBBLE, 2, true],   # 잔돌
	[GD_WEED_D, 2, true],   # 마른 잡초(개활지)
]
const _GD_SPARSE_DENSITY := 0.12   # 빈 tan 셀 중 clutter가 놓일 비율(↑=빽빽). 스타듀 개활지 밀도.

# ★[ADR-0058] 구역-키드 스캐터 테이블 — 각 구역 고유 clutter 정체성(심심함 최대 레버).
#   비면 전역 _GD_TABLES/_GD_SPARSE 폴백(회귀 0). 구역이 지어질 때 자기 엔트리를 채운다.
#   구조: { region_id: { GROUND:[[tex,weight,shadow]...], PATH:[...] } }. Task 2에서 home 채움.
var _REGION_GD_TABLES := {
	# ★[ADR-0058] 안식 농원 = 풀무리 증가(owner 2026-07-17). 전역 대비 GD_GRASS 가중↑·맨 여백↓.
	#   ⚠️ base는 tan-지배 유지(ADR-0053) — 이건 스캐터 tuft 데칼 밀도이지 잔디패치 아님.
	RegionCatalog.HOME: {
		GROUND: [
			[null, 34, false],       # 맨 잔디 여백 44→34(풀무리 체감↑)
			[GD_GRASS1, 38, false],  # 짧은 풀포기 주력 30→38
			[GD_GRASS2, 9, false],   # 중간 풀포기 5→9
			[GD_WEED_U, 4, false],
			[GD_WEED_D, 3, true],
			[GD_FLOWER, 2, true],
			[GD_PEBBLE, 1, true],
			[GD_TWIG1, 4, false],
			[GD_TWIG2, 3, false],
			[GD_STONE1, 4, true],
			[GD_STONE2, 3, true],
		],
		# PATH는 전역 폴백(오버라이드 없음).
	},
}
var _REGION_GD_SPARSE := {}

# 현재 구역(_region)의 terrain 스캐터 테이블 — 구역 오버라이드 → 전역 폴백.
func _gd_table_for(terrain: int) -> Array:
	var rt: Dictionary = _REGION_GD_TABLES.get(_region, {})
	if rt.has(terrain):
		return rt[terrain]
	return _GD_TABLES.get(terrain, [])

func _gd_sparse_for() -> Array:
	return _REGION_GD_SPARSE.get(_region, _GD_SPARSE)

# ★[ADR-0058 B] 구역별 풀무리 문턱(↓=clump 면적↑). 안식은 풀무리↑라 전역보다 낮춘다.
var _REGION_CLUSTER_CUT := { RegionCatalog.HOME: 0.52 }   # 전역 GD_CLUSTER_CUT=0.60

# 풀무리 마스크 — 저주파 seed + CA 이웃-확산(스타듀 풀 확산 본뜸). 결정적·셀단위·2패스 상한.
#   _gd_cluster로 seed(GROUND만) → 이웃≥5 성장·<2 사멸 2패스 → 유기적 clump. _g16_cluster_cleanup 계보.
var _scatter_clump: Array = []

func _compute_scatter_clump() -> void:
	var W := _grid_w
	var H := _outdoor_h
	var cut: float = _REGION_CLUSTER_CUT.get(_region, GD_CLUSTER_CUT)
	var mask := []
	for y in H:
		var row := []
		for x in W:
			row.append(1 if (_grid[y][x] == GROUND and _gd_cluster(x, y) >= cut) else 0)
		mask.append(row)
	for _p in 2:
		var snap: Array = mask.duplicate(true)
		for y in H:
			for x in W:
				if _grid[y][x] != GROUND:
					mask[y][x] = 0
					continue
				var gn := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and nx < W and ny >= 0 and ny < H and snap[ny][nx] == 1:
							gn += 1
				if snap[y][x] == 1 and gn < 2:
					mask[y][x] = 0
				elif snap[y][x] == 0 and gn >= 5:
					mask[y][x] = 1
	_scatter_clump = mask

func _scatter_is_clump(x: int, y: int) -> bool:
	if _scatter_clump.is_empty():
		return _gd_cluster(x, y) >= _REGION_CLUSTER_CUT.get(_region, GD_CLUSTER_CUT)  # 안전 폴백
	return _scatter_clump[y][x] == 1

# 구역 → 그 구역이 그리는 PROP 레이아웃 키(지면 디테일이 PROP 점유 칸을 비껴가게 함).
var _REGION_PROP_KEYS := {
	RegionCatalog.HOME: ["HOME"],
	RegionCatalog.NARU_VILLAGE: ["CAFE", "VILLAGE_HOUSE"],
}
var _ground_detail_tex: ImageTexture = null   # 구역별 베이크된 지면 디테일 오버레이
var _gd_shadow_stamp: Image = null            # 재사용 SE 그림자 스탬프
# ★[ADR-0049] 16px 소프트 지면 big-field 캐시(256²=필드128×2, 월드좌표 타일링용). 최초 1회 로드.
var _bf_grass: Image = null
var _bf_grass_mute := true   # 재생성 crisp 잔디를 muted somber로(home_pilot_dump는 false=순수 톤 검증)
var _bf_dirt: Image = null
var _bf_soil: Image = null
var _bf_water: Image = null
var _bf_earth: Image = null   # ★[스타듀 농장 룩] 마당 베이스 = 따뜻한 황갈색 맨흙(dirt_field 리톤). 잔디는 위에 패치로만.
# ★[지면 채도 A/B 실험] _retone_earth 계수 — 기본값=현행이라 baseline 완전 불변(회귀 안전).
#   ground_ab_dump.gd가 프리셋마다 이 값을 오버라이드 → _bf_earth 재계산 → 실제 코드 경로로 A/B 렌더.
var _earth_hue_lerp := 0.55   # 붉은 흙 hue를 노란-갈색(0.095)으로 당기는 가중치
var _earth_sat_mul := 0.80    # 채도 배율(현행: 완화). 스타듀 골든머스타드 방향이면 >1
var _earth_val_mul := 1.22    # 명도 배율(현행: 크게 밝힘 → 파스텔 원인)
var _earth_val_add := 0.14    # 명도 가산(현행: 추가로 밝힘)
var _gd_soft_cache := {}                       # ★[ADR-0042] 디테일 texture→부드럽게 보정한 Image 캐시
var _base_variant_cache := {}                  # ★[ADR-0043 §6] terrain id→base 변종 좌표 배열 캐시
var _facade_base_cache := {}                   # facade tex→밑단선 span{line_y,center,half}(캐스트 그림자 발 앵커)
var _facade_shadow_sil_cache := {}             # facade tex→소프트(블러) 검정 실루엣 텍스처(SE 캐스트 그림자용)
const _SHADOW_MARGIN := 4                       # 캐스트 그림자 실루엣 블러 번짐 여백(px)
# 외부 건물 외관(PixelLab/Gemini 산출). 통과 불가 WALL 박스 위에 덮어(bottom-center 앵커) 그려
# "닫힌 건물"로 보이게 한다(_draw_facades). 집=320×292(제미나이 재생성·[ADR-0046] 짝수 10폭·2칸 문,
# 지붕 오버행으로 8칸 footprint 위로 솟음), 카페=256×224(8×7칸).
const FACADE_HOUSE := preload("res://assets/buildings/house_ext.png")
const FACADE_CAFE := preload("res://assets/buildings/cafe_ext.png")
# ★ M2.5 — 나루 마을 메인 집 3채(미호·멜·바나)를 본체 캐릭터별로 외관 재도색(residents.md
# "본체별 외관 재도색", ADR-0014 점진 추가). 카페 외관과 같은 결로 통과 불가 WALL 박스 위에
# 1:1로 덮어 "그 캐릭터의 집"으로 읽히게 한다(미호=한옥·여우불 / 멜=청록·돈 부적 / 바나=고딕·박쥐).
# 박스 크기와 1:1: 미호·바나=128×128(4×4칸), 멜=160×160(5×5칸). 만물상·주민 집은 이번 패스
# 범위 밖이라 그레이박스 라벨 유지(본체 제작 시 함께 재도색 — 미리 테마링 안 해 낭비 0).
const FACADE_MIHO_HOUSE := preload("res://assets/buildings/miho_house_ext.png")
const FACADE_MEL_HOUSE := preload("res://assets/buildings/mel_house_ext.png")
const FACADE_BANA_HOUSE := preload("res://assets/buildings/bana_house_ext.png")
# ★ 안식 농원 서비스 건물 외관 — 창고=제미나이 재생성(tools/gemini_facade_to_chunky.py: 다운스케일→양자화
# →×2 nearest, 2px 캐논+선명, [ADR-0046]) 192×196 · 축사=PixelLab half-res(facade_halfres_x2.py) 150×166.
# footprint = 창고 6×6칸(STOREHOUSE_EXT_RECT)·넋우릿간 4×3칸(NEOKURITGAN_EXT_RECT). art는 지붕 윗면 노출로
# footprint보다 위로 솟아(bottom-center 앵커) 본가와 지붕 시점 통일. 창고·동물 2건물 모두 enterable(실내 방).
const FACADE_STOREHOUSE := preload("res://assets/buildings/storehouse_ext.png")
const FACADE_BARN := preload("res://assets/buildings/barn_ext.png")
const FACADE_COOP := preload("res://assets/buildings/coop_ext.png")
# P2.3③ 소울 등불 자리(단일 출처) — 가구 그리기(PROP_LAYOUT)와 밤 빛웅덩이(lighting)가
# 이 배열을 공유한다(좌표가 어긋나면 등불 그림과 빛이 따로 놀므로).
# ★ M1.4 — 카페가 나루 마을로 이주하며 등불도 구역이 갈렸다: 안식 농원 길가 둘 / 나루 마을 카페
#   구석 하나. 구역마다 자기 등불만 켜지게(다른 구역 등불이 떠다니지 않게) 둘로 나눈다.
const LANTERN_TILES_HOME := [Vector2i(39, 17), Vector2i(45, 17)]  # ★ADR-0035 Phase B: 스타터 패치(x40..44) 남단 입구 양옆 등불(외부)
const LANTERN_TILES_CAFE := [Vector2i(18, 91)]                    # 나루 마을 카페 구석(실내) ★C3: +48
# [텍스처, [놓을 타일들]]. 타일 좌표는 실내 레이아웃(직원 y40 / 카운터 y41 / 좌석 y42 /
# 스폿 y44) 위에 얹어 "장소"로 읽히게 배치한다. 좌석 스툴 위에는 손님 박스가 덮여 그려진다.
# ★ M1.4 — 카페 이주로 가구도 구역이 갈렸다: 안식 농원(집 가구·길가 등불·화분) / 나루 마을(카페
#   무대 가구·카페 등불). _draw_props가 현재 구역(_region)의 배열만 그린다(다른 구역 가구가
#   떠다니지 않게). 카페 내부 좌표는 안식 농원 시절과 동일하게 유지(좌표 대이동 최소화·회귀 0).
# ★ C2 — HOME 집 실내가 HOME 밴드(y67+, outdoor_h 65 아래)로 내려가 가구도 +41(=65-24) 이동.
# ★ C3 — 마을이 100×72로 커져 마을 실내(카페·공유 집)도 마을 밴드(y72+ 아래)로 +48(=72-24) 이동.
#   가구도 같은 +48 — 작동 검증된 카페/집 내부 레이아웃이 상대배치 그대로 내려간다(회귀 0).
# ★ T3③ — 벽 가구 시각 보정(픽셀). HOUSE_WALL 아트가 크림 트림+갈색 wainscoting 반높이라, 벽 바로
#   아래 y68 가구는 갈색 wainscoting이 바닥색과 섞여 "한 칸 떠 보인다". 상단 벽 가구를 위로 살짝 올려
#   크림 트림에 밀착시킨다(좌표·충돌은 floor 칸 그대로 — 시각만). PROP_LAYOUT 엔트리 3번째 원소=픽셀 yo.
const WALL_PROP_LIFT := -18
# ★ T3③' — 통과 불가 실내 가구(젬나이 피드백). 러그(바닥 깔개)·등불·꽃·울타리 등은 제외(통과 O).
#   이 텍스처들은 실내 레이아웃에만 쓰여(카페/외부 props는 다른 텍스처) 충돌이 실내 가구에만 걸린다.
const SOLID_PROPS := [PROP_BED, PROP_FIREPLACE, PROP_BOOKSHELF, PROP_TABLE, PROP_POT,
	PROP_TREE_A, PROP_TREE_B, PROP_ROCK,   # ★ T3⑤ 나무·바위 = 통과 불가(맵 경계 벽)
	PROP_BUSH,                             # ★[roster] 덤불 = 능선 벽(풀 2×2 SOLID·FOOT_BAR 아님 = 전체 막음, owner "막 지나가지길 원해")
	PROP_DEBRIS_EMBER, PROP_DEBRIS_STUMP,  # ★ ADR-0035 업화석·석화 고목 = 통과 불가(계단 하드 게이트·overgrown 장애물)
	PROP_LOG_LONG, PROP_LOG_SHORT, PROP_LOG_UPRIGHT, PROP_LOG_DIAG_A, PROP_LOG_DIAG_B,  # ★통나무 5종 = 통과 불가(owner 2026-07-05·FOOT_BAR 아님=풀타일 장애물, 낮은 프롭)
	PROP_SCARECROW,                        # ★허수아비(1×2) = 밑 1칸 SOLID·위 1칸 통과+fade(나무·바위 인프라, owner 2026-07-05) — FOOT_BAR_PROPS·FADE_PROPS 동반
	PROP_FENCE]                            # ★울타리 = 통과 불가(owner 2026-07-05 "못 지나가게"·FOOT_BAR 아님=풀타일 경계벽·낮은 프롭). 패치 남단 여백(y17)이라 진입은 북쪽 본가 문·옆구리 x39/x45 우회로 유지
# ★[asset-ruleset §5] 발치 충돌 바 — 키 큰 야외 프롭(나무·바위)은 풀타일 충돌 대신 *발치 밑단 바*(폭×반높이)만
#   막아 "머리는 통과"(§6 Y-split의 물리 짝 — 캐노피 뒤로 지나감). 하드게이트 debris(업화석·석화고목)는
#   개간 게이트라 풀타일 유지(Slice 1 전환)·실내 벽 가구는 벽 flush라 풀타일 유지(회귀 보존). 맵 이탈은
#   _border_body(둘레)가 막으므로 야외 트리 축소는 경계 안전.
const FOOT_BAR_PROPS := [PROP_TREE_A, PROP_TREE_B, PROP_ROCK, PROP_SCARECROW]
const FOOT_BAR_H := 16   # 밑단 바 높이(8 논리 = 반 타일) — FADE_PROPS 밖 부피 프롭용(현재 예약, 향후 반타일 프롭)
# ★[roster] 저승 봄나무(2×4칸)·바위(2×2칸) = 밑둥/밑행만 SOLID(폭 전체 × 젤밑 1칸)·그 위는 통과 O(캐릭터가 뒤로 지나감).
#   owner 결정: "젤밑 두 칸만 막고 그 위는 통과". 나무·바위 발치바는 FOOT_BAR_H 대신 1칸(TILE) 높이(FADE_PROPS 소속).
const TREE_FOOT_H := TILE
# ★[roster] 수관/바위 뒤 캐릭터 occlusion fade — 앞 패스(플레이어보다 앞)로 그려지는 부피 프롭이 플레이어를 덮으면
#   살짝 반투명해 "뒤에 있음"을 드러낸다(스타듀식). 프롭별 alpha를 _tree_fade에 lerp(순수 시각).
#   ★바위(PROP_ROCK)도 여기 합류 = 나무와 동일 인프라(밑행 1칸 SOLID + 뒤로 지나갈 때 반투명). owner 2026-07-04.
#   ★허수아비(PROP_SCARECROW·1×2)도 합류(owner 2026-07-05 "밑 1×1 못 지나가고 위 1×1은 뒤로 통과+반투명") —
#     TREE_FOOT_H=TILE이라 32×64의 밑 1칸만 SOLID·위 1칸(몸통·머리)은 통과 O + occlusion fade.
const FADE_PROPS := [PROP_TREE_A, PROP_TREE_B, PROP_ROCK, PROP_SCARECROW]
const TREE_FADE_MIN := 0.45   # 겹칠 때 최소 알파(완전 투명 X — 나무가 남아 보이게)
const TREE_FADE_SPEED := 8.0  # 알파 전환 속도(초당 — move_toward, 부드러운 페이드)
# ★ ADR-0025 ② — PROP 좌표 데이터 외부화. 텍스처는 *코드가* 정의하고(키↔Texture2D 레지스트리),
# layout.json은 *위치만* 담는다. 직렬화 때 tex→키, 로드 때 키→tex. PROP_LAYOUT에 새 텍스처를
# 쓰면 이 레지스트리에도 등록해야 한다(미등록 tex는 export에서 빈 키로 경고·로드에서 스킵).
const PROP_TEX_REGISTRY := {
	"BED": PROP_BED, "COUNTER": PROP_COUNTER, "STOOL": PROP_STOOL, "SHELF": PROP_SHELF,
	"LANTERN": PROP_LANTERN, "POT": PROP_POT, "RUG": PROP_RUG, "FIREPLACE": PROP_FIREPLACE,
	"BOOKSHELF": PROP_BOOKSHELF, "TABLE": PROP_TABLE, "FRAME": PROP_FRAME, "CLOCK": PROP_CLOCK,
	"CABINET": PROP_CABINET, "CAFE_TABLE": PROP_CAFE_TABLE, "FENCE": PROP_FENCE,
	"SCARECROW": PROP_SCARECROW, "PLANTER": PROP_PLANTER, "FLOWER_PATCH": PROP_FLOWER_PATCH,
	# ★ T3⑤ 테두리 장식 6종
	"TREE_A": PROP_TREE_A, "TREE_B": PROP_TREE_B, "GRASS": PROP_GRASS,
	"BUSH": PROP_BUSH, "ROCK": PROP_ROCK,
	# ★통나무 5종(prop-regen-roster §5.3)
	"LOG_LONG": PROP_LOG_LONG, "LOG_SHORT": PROP_LOG_SHORT, "LOG_UPRIGHT": PROP_LOG_UPRIGHT,
	"LOG_DIAG_A": PROP_LOG_DIAG_A, "LOG_DIAG_B": PROP_LOG_DIAG_B,
	# ★ ADR-0035 Phase B 안식 재설계 5종(계단·넝쿨·debris)
	"STAIRS": PROP_STAIRS, "VINE": PROP_VINE, "DEBRIS_WEEDS": PROP_DEBRIS_WEEDS,
	"DEBRIS_EMBER": PROP_DEBRIS_EMBER, "DEBRIS_STUMP": PROP_DEBRIS_STUMP,
}
const PROP_LAYOUT_HOME := [
	# ── ★ T3③ 실내 가구(HOME_HOUSE_RECT x8..19 y67..75, 실내 바닥 x9..18 y68..74) — 전부 벽 flush ──
	# 침대·벽난로·책장은 상단 벽 가구라 y68(floor)에 두되 WALL_PROP_LIFT로 크림 트림에 밀착, 화분은
	# 세 구석에(상단 화분만 lift). 문(13,75) 앞은 비운다. 통과 불가는 SOLID_PROPS·_rebuild_prop_collision.
	[PROP_RUG, [Vector2i(11, 71)]],                                                      # 집: 중앙 바닥 러그(맨 먼저 — 바닥, x11..13)
	[PROP_BED, [Vector2i(9, 68)], WALL_PROP_LIFT],                                       # 집: 좌상단 침대(상단·좌벽 flush)
	[PROP_FIREPLACE, [Vector2i(12, 68)], WALL_PROP_LIFT],                                # 집: 상단 벽 벽난로(flush, x12..13)
	[PROP_BOOKSHELF, [Vector2i(15, 68)], WALL_PROP_LIFT],                                # 집: 상단 벽 책장(flush, x15..16)
	[PROP_TABLE, [Vector2i(12, 72)]],                                                    # 집: 러그 위 작은 테이블
	[PROP_LANTERN, LANTERN_TILES_HOME],                                                  # ★ADR-0035 스타터 패치 입구 등불 둘(외부)
	[PROP_POT, [Vector2i(18, 68)], WALL_PROP_LIFT],                                      # 집 우상단 화분(상단 벽 flush)
	[PROP_POT, [Vector2i(9, 74), Vector2i(18, 74)]],                                     # 집 좌하·우하 화분(하단 벽 — lift 없음)
	# ── ★ [단계3 남향 재배향] 하늘 목장 게이트·능선 프롭(owner Gemini 가이드 2026-07-04) ────────────
	# 남향 개간 게이트 = 남향 벽 관통 계단 노치(x9..10 y26..28). 넝쿨 장벽(비-SOLID 시각) + 저지측 발치
	#   debris 하드게이트(SOLID)로 개간 전 물리 차단. 옛 동향 게이트(x21,x24)를 남향으로 90° 회전.
	[PROP_VINE, [Vector2i(9, 26)]],             # 넝쿨 장벽(계단 입구 시각 — 통과 O, 32×64)
	# 하드 게이트 debris(노치 발치 — 통과 X SOLID로 게이트 물리 차단, 개간 온보딩). ★[roster §5.2] 32×32=1×1칸이
	#   되며 옛 2×2 한 개론 2칸 노치(x9..10)를 못 막으므로 열마다 2타일(x9+x10)로 폭을 채운다(안 그러면 x10이
	#   뚫려 게이트 누출). 앵커 (9,28)/(9,30)은 보존 — _debris_kind_at·reclaim_test 단언 불변.
	[PROP_DEBRIS_EMBER, [Vector2i(9, 28), Vector2i(10, 28)]],   # 업화석(곡괭이) — 노치 입구 폭 x9..10 y28
	[PROP_DEBRIS_STUMP, [Vector2i(9, 30), Vector2i(10, 30)]],   # 석화 고목(도끼) — 접근로 폭 x9..10 y30
	# ★[단계3-③ 잔디 입체화 / 2026-07-04 owner "막 지나가지길 원해·한 줄"] 동향 잔디 능선 수풀 = x20 한 줄
	#   세로 스택(y1~25 2칸 간격 13개 = 2×2 블록이 y1~26 빈틈 없이 이어짐). bush=SOLID(풀 2×2)로 전환 →
	#   덤불 자체가 통행 벽(옛 비-SOLID+_ridge_body 시각만 → 이제 덤불에 직접 부딪힘). _ridge_body는 백업으로
	#   유지(y0 틈·남단 안전망). 남단(y25 블록=y25~26)이 남향 벽(y26)과 자연 연결(SE 코너 폐쇄).
	#   ★변주 교대: 한 줄이라 x 고정 → (x+y)%2가 y홀수만 남아 단색이 되므로, bush 변주는 (x + y/2)%2로
	#   y 스택을 따라 dark↔bright 교대(_draw_props_for·home_full_dump 동일 식).
	[PROP_BUSH, [
		Vector2i(20, 1), Vector2i(20, 3), Vector2i(20, 5), Vector2i(20, 7),
		Vector2i(20, 9), Vector2i(20, 11), Vector2i(20, 13), Vector2i(20, 15),
		Vector2i(20, 17), Vector2i(20, 19), Vector2i(20, 21), Vector2i(20, 23),
		Vector2i(20, 25)]],
	# ── overgrown debris 밭(저지 — 통과 O 잡초 + 통과 X 업화석·석화 고목 산포, 동선·건물·패치·연못 비껴) ──
	[PROP_DEBRIS_WEEDS, [Vector2i(50, 22), Vector2i(56, 38), Vector2i(35, 44), Vector2i(60, 52),
		Vector2i(46, 24), Vector2i(30, 54), Vector2i(58, 20), Vector2i(52, 56), Vector2i(34, 26)]],  # 이승의 미련(잡초·낫)
	[PROP_DEBRIS_EMBER, [Vector2i(54, 44), Vector2i(48, 50), Vector2i(33, 48)]],         # 업화석(SOLID, overgrown 장애물)
	[PROP_DEBRIS_STUMP, [Vector2i(60, 40), Vector2i(45, 52), Vector2i(28, 50)]],         # 석화 고목(SOLID, overgrown 장애물)
	# ── 농경 장식(스타터 패치 곁 — 통과 O) ──────────────────────────────────────
	[PROP_SCARECROW, [Vector2i(37, 14), Vector2i(46, 14)]],                              # 허수아비 둘(패치 양옆 GROUND — 스파인·패치 비껴)
	[PROP_PLANTER, [Vector2i(42, 11), Vector2i(46, 11)]],                                # 본가 문~패치 접근로 화분(등불·울타리 비껴)
	[PROP_FENCE, [Vector2i(40, 17), Vector2i(41, 17), Vector2i(42, 17), Vector2i(43, 17), Vector2i(44, 17)]],  # 패치 남단 가로 울타리(연속 런·통과 불가 SOLID·옆구리 x39/x45 우회)
	[PROP_FLOWER_PATCH, [
		Vector2i(8, 12), Vector2i(16, 8), Vector2i(70, 18), Vector2i(72, 44), Vector2i(20, 56), Vector2i(62, 56),
		Vector2i(4, 20), Vector2i(74, 10), Vector2i(50, 8), Vector2i(64, 34), Vector2i(56, 60), Vector2i(36, 56),
	]],  # 꽃 패치 산재(고지·동/남 코지 여백 — 휑함 완화, 클러터 X)
	# ── ★[roster 2026-07-04] 저승 봄나무 재도입(2×4칸·밑둥 1칸 SOLID·수관 통과+occlusion fade). owner가
	#   2026-07-03에 옛 나무를 "안 어울림"으로 걷어냈으나, 스타듀 룩 2×4 재생성본으로 테두리 프레이밍 복귀.
	#   전부 빈 코너·가장자리(밭·동선·건물·연못·debris·능선 회피 — 아래 좌표는 그 밖의 잔디 잉여지대). ──
	[PROP_TREE_A, [
		Vector2i(54, 3), Vector2i(68, 4), Vector2i(74, 3),   # 우상단 코너 클러스터
		Vector2i(76, 54), Vector2i(70, 58),                  # 우하단 코너
		Vector2i(44, 60), Vector2i(3, 50),                   # 하단·좌하단
		Vector2i(4, 33),                                     # 좌중(넋우릿간 아래·연못 서편)
	]],  # 침엽수 8
	[PROP_TREE_B, [
		Vector2i(61, 2), Vector2i(77, 11),                   # 우상단 코너·우측 가장자리
		Vector2i(72, 46), Vector2i(64, 49),                  # 우하단 코너
		Vector2i(52, 61),                                    # 하단 가장자리
		Vector2i(10, 54), Vector2i(18, 58),                  # 좌하단 코너
		Vector2i(3, 24),                                     # 좌중
	]],  # 활엽수 8
	# ★[roster 바위 재도입] 저승 바위(2×2·밑행 SOLID·수관처럼 뒤로 지나가면 occlusion fade) — 빈 밭에
	#   산재해 부피감·프레이밍(나무 사이 보완). 밭·동선·건물·연못·debris·능선·꽃/울타리 회피(라이브 그리드 검증).
	[PROP_ROCK, [
		Vector2i(58, 15), Vector2i(67, 24), Vector2i(68, 36),   # 우측 빈 밭 산재
		Vector2i(52, 40),                                        # 중앙-하 밭
		Vector2i(10, 22), Vector2i(14, 46),                     # 좌측(연못 서편·좌하 빈 밭)
	]],  # 바위 6
	# ★[prop-regen-roster §5.3 / owner 2026-07-04] 통나무 5종 산재(통과 O 순수 장식·발치 타원 그림자만).
	#   벌목/자연 쓰러진 나무 느낌으로 나무 클러스터 곁·빈 가장자리에 배치. 라이브 검증(SOLID·기존 프롭·건물
	#   EXT·연못·패치·방목 겹침 0 — tools/logs_place_check.gd)으로 좌표 확정.
	[PROP_LOG_LONG, [Vector2i(63, 6), Vector2i(6, 40), Vector2i(66, 55)]],                       # 긴 통나무(3×1) 3
	[PROP_LOG_SHORT, [Vector2i(50, 5), Vector2i(14, 50), Vector2i(56, 32)]],                     # 짧은 통나무(2×1) 3
	[PROP_LOG_UPRIGHT, [Vector2i(58, 7), Vector2i(72, 50), Vector2i(7, 45), Vector2i(66, 29)]],  # 세워진 그루터기(1×1) 4
	[PROP_LOG_DIAG_A, [Vector2i(60, 9), Vector2i(16, 50), Vector2i(12, 38)]],                    # 대각 통나무 밝은(1×1) 3
	[PROP_LOG_DIAG_B, [Vector2i(52, 9), Vector2i(15, 52), Vector2i(68, 30)]],                    # 대각 통나무 어두운(1×1) 3
	# ── ★ 옛 테두리 스캐터 프롭 제거(owner 2026-07-03): 안 어울리는 나무(tree_spirit)·바위(rock)·
	#   그루터기(stump)·덤불(bush)을 맵에서 걷어냈다. 맵 이탈 방어는 _build_border(4변 경계벽)가 이미
	#   맡으므로 SOLID 프레이밍 트리 없이도 경계 안전. 텍스처 상수·레지스트리는 남겨 둔다(회귀·재사용).
	#   과수(혼백나무 등 최근 생성분)는 orchard 시스템 소관이라 여기서 안 건드림. 절벽/계단은 아트 재생성.
]
# ★C3 — 카페 실내가 마을 밴드(y86+)로 +48 평행이동(아래 CAFE_RECT 참조). 가구도 같은 +48이라
#   작동 검증된 카페 내부 레이아웃이 상대 배치 그대로 내려간다(상대배치 무위험·회귀 0).
const PROP_LAYOUT_CAFE := [
	[PROP_COUNTER, [Vector2i(10, 89), Vector2i(11, 89), Vector2i(12, 89), Vector2i(13, 89), Vector2i(14, 89), Vector2i(15, 89), Vector2i(16, 89)]],  # 카페 바 카운터
	[PROP_STOOL, [Vector2i(11, 90), Vector2i(14, 90), Vector2i(17, 90)]],                # 카페 좌석 스툴(= SEAT_TILES)
	[PROP_SHELF, [Vector2i(11, 87), Vector2i(13, 87), Vector2i(15, 87)]],                # 카페 뒷벽 선반
	[PROP_CLOCK, [Vector2i(9, 86)]],                                                     # 카페: 좌측 뒷벽 괘종시계
	[PROP_FRAME, [Vector2i(10, 86), Vector2i(16, 86)]],                                  # 카페: 뒷벽 앤틱 액자 둘
	[PROP_CABINET, [Vector2i(18, 86)]],                                                  # 카페: 우측 뒷벽 와인 캐비닛
	[PROP_CAFE_TABLE, [Vector2i(11, 93), Vector2i(15, 93)]],                             # 카페: 하단 손님 테이블 둘
	[PROP_LANTERN, LANTERN_TILES_CAFE],                                                  # 나루 마을 카페 구석 등불
]
# ★ M2.2 — 나루 마을 메인/주민 집 실내는 안식 농원 집 가구를 *재사용*한다("기존 집 에셋 재사용",
# residents.md). PROP_LAYOUT_HOME에서 외부 전용인 길가 등불(LANTERN_TILES_HOME)만 뺀 가구 묶음 —
# 한 공유 집 방(HOUSE_RECT)에 그린다. 들어간 집 안일 때만 그린다(_is_in_house_interior). 점유자
# (주민 NPC)는 후속 슬라이스에서 붙고, 그때 각 집이 자기 방을 가진다(ADR-0014 점진 추가).
# ★C3 — 마을 공유 집 실내가 마을 밴드(y74+)로 +48 평행이동(아래 HOUSE_RECT 참조). 가구도 같은 +48.
const PROP_LAYOUT_VILLAGE_HOUSE := [
	# ★ T3③ HOME 집 실내 flush 배치를 그대로 +7(마을 공유 집 밴드 y74)로 미러 — 같은 아늑함·lift 공유.
	[PROP_RUG, [Vector2i(11, 78)]],
	[PROP_BED, [Vector2i(9, 75)], WALL_PROP_LIFT],
	[PROP_FIREPLACE, [Vector2i(12, 75)], WALL_PROP_LIFT],
	[PROP_BOOKSHELF, [Vector2i(15, 75)], WALL_PROP_LIFT],
	[PROP_TABLE, [Vector2i(12, 79)]],
	[PROP_POT, [Vector2i(18, 75)], WALL_PROP_LIFT],
	[PROP_POT, [Vector2i(9, 81), Vector2i(18, 81)]],
]
# ★ ADR-0025 ② — 시드(코드 하드코딩) 묶음. layout.json이 없을 때의 출발점이자 회귀 비교 기준.
# 키 = 묶음 이름(json 최상위 키 — 구역이 아니라 "어느 가구 세트"). 멱등 이주: _SEED_LAYOUTS를
# 직렬화→역직렬화한 결과가 _prop_layouts이며, 시드와 바이트 동등하면 회귀 0(좌표만 데이터로 나감).
const _SEED_LAYOUTS := {
	"HOME": PROP_LAYOUT_HOME,
	"CAFE": PROP_LAYOUT_CAFE,
	"VILLAGE_HOUSE": PROP_LAYOUT_VILLAGE_HOUSE,
}
const LAYOUT_PATH := "res://layout.json"   # 진실의 원천(git 추적). 없으면 시드에서 1회 생성.
# 런타임 PROP 배열(로드됨). 소비처(_draw_props_for·_rebuild_prop_collision)가 const 대신 이걸 참조.
# 구조는 시드와 동일: { "HOME": [[tex, [Vector2i...], yo?], ...], ... }.
var _prop_layouts: Dictionary = {}

# ★ ADR-0025 ① 인게임 배치 모드 상태(디버그/에디터 전용 저작 도구). _toggle_edit_mode·_unhandled_input·
# _draw_edit_overlay가 참조. 등불(LANTERN)은 빛 좌표가 코드 상수(LANTERN_TILES_*)라 편집 팔레트서 제외
# (여기서 옮겨도 빛이 안 따라옴 — 빛 동기화는 후속). 새로 놓는 외부 장식만 팔레트에 둔다([ ] 순환).
const _EDIT_PALETTE := ["TREE_A", "TREE_B", "GRASS", "BUSH", "ROCK",
	"LOG_LONG", "LOG_SHORT", "LOG_UPRIGHT", "LOG_DIAG_A", "LOG_DIAG_B",
	"FENCE", "SCARECROW", "PLANTER", "FLOWER_PATCH", "POT"]
var _edit_mode := false
var _edit_sel_entry := -1     # 선택된 _prop_layouts[key] 엔트리 인덱스(-1=없음)
var _edit_sel_tile := -1      # 그 엔트리 안 타일 인덱스(한 엔트리가 여러 인스턴스)
var _edit_dragging := false
var _edit_palette := 0        # _EDIT_PALETTE 인덱스(새로 놓을 텍스처)
# ★ 맥북 F키(F10이 시스템 키)·단축키가 안 먹어 배치 모드를 마우스 버튼으로 완결(화면 좌상단 패널).
# 팔레트 영어 키 → 한글 별칭(라벨 가독). 패널 위젯 참조는 토글 시 갱신(_edit_update_ui).
const _EDIT_PAL_NAMES := {
	"TREE_A": "침엽수", "TREE_B": "활엽수", "GRASS": "풀", "BUSH": "덤불", "ROCK": "바위",
	"LOG_LONG": "긴통나무", "LOG_SHORT": "짧은통나무", "LOG_UPRIGHT": "그루터기",
	"LOG_DIAG_A": "대각통나무(밝)", "LOG_DIAG_B": "대각통나무(어둠)",
	"FENCE": "울타리", "SCARECROW": "허수아비", "PLANTER": "화분",
	"FLOWER_PATCH": "꽃", "POT": "항아리",
}
var _edit_btn_toggle: Button = null
var _edit_row: Control = null
var _edit_pal_label: Label = null

# ★ [S1-9] 집 꾸미기 모드 상태(플레이어-facing — F10 저작 도구와 별개, §11.5). 집 실내("집")에서만
#   KEY_C로 토글 진입. 마우스 커서 배치 + 키 팔레트(레이어·세트·아이템 순환)·회전. 순수 코스메틱(비용0).
var _deco_mode := false
var _deco_layer := 0     # 0=바닥재 / 1=벽지 / 2=가구 (_DECO_LAYERS 인덱스)
var _deco_set := 0       # HomeDecoCatalog.set_ids() 인덱스(현재 팔레트 세트)
var _deco_item := 0      # 현재 세트·레이어의 items_of_layer 인덱스
var _deco_rot := 0       # 새로 놓을 가구 회전(0..3)
const _DECO_LAYERS := [HomeDecoCatalog.L_FLOOR, HomeDecoCatalog.L_WALL, HomeDecoCatalog.L_FURNITURE]
const _DECO_LAYER_NAMES := {"floor": "바닥재", "wall": "벽지", "furniture": "가구"}

# ── 외부↔실내 분리(구역 사각형, 타일 좌표 Rect2i(x, y, 폭, 높이)) ─────────────
# 건물은 외부에선 통과 불가 "외관"으로 보이고, 문에 닿으면 fade로 맵 아래 별도 실내 구역으로
# 텔레포트한다(스타듀식 외부↔실내 — 문=같은 구역 안 특수 워프, _transition_to). 실내 NPC·가구·
# 좌석·_zone_at이 전부 이 상수들을 참조하므로, 좌표를 그대로 두면 참조 코드는 손대지 않아도 된다.
# ★ M1.4 — 카페가 나루 마을로 이주했다. 집(외관·실내)은 안식 농원에, 카페(외관·실내)는 나루
#   마을에 지어진다(_build_home / _build_naru_village). 카페 좌표는 안식 농원 시절과 *동일하게*
#   유지하되 마을 그리드의 같은 칸에 둔다 — 좌표 대이동 없이 카페 시뮬·NPC·좌석 상수가 그대로
#   따라온다(회귀 0). 어느 구역에서 어느 칸이 실제로 도달 가능한지는 _zone_at이 구역으로 가른다.

# 외부 외관. 통과 불가 박스 + 문 한 칸만 트리거. 집=안식 농원 / 카페=나루 마을(같은 칸 좌표 재사용).
const HOUSE_EXT_RECT := Rect2i(40, 2, 10, 8)   # ★ADR-0035/[ADR-0046] x40..49, y2..9 (북중앙 본가 — 저지, 창고 오른쪽 병렬). 9→10 짝수폭(2칸 문 정중앙) 제미나이 재생성 정합(아트 320×292)
# ★ M2.1 — 카페 외관을 나루 마을 *서편*으로 이전(world-map.md '서:카페·메인집'). 도착 칸 바로 위라
#   도착하자마자 카페가 보이는 출근 동선. 실내 좌표(CAFE_RECT·NPC·좌석)는 따로 +48 평행이동(아래
#   ★C3)이라 카페 운영·시뮬은 회귀 0 — 바뀌는 건 외관 위치·문·동선뿐. 8×7 = FACADE_CAFE 아트 1:1.
#   ★C3 — 100×72 코지-와이드: 외관을 서편 도착(3,36) 위쪽 x5..12 y25..31로 옮긴다(코지 여백).
const CAFE_EXT_RECT := Rect2i(5, 25, 8, 7)    # x5..12, y25..31 (나루 마을 서편, 도착 동선 위)
const HOUSE_EXT_DOOR := Vector2i(44, 9)     # ★ADR-0035/[ADR-0046] 외관 본가 문 서패널(닿으면 진입) — 아래벽 x40..49 중심 straddle → 2칸 문 x44·x45, 남쪽 스타터 패치로 열림
const HOUSE_EXT_DOOR_E := Vector2i(45, 9)   # ★[ADR-0046] 본가 2칸 문 동패널(짝수폭 정중앙 2칸 — 문/진입로/트리거 폭 정합). 진입 트리거는 양 칸 다 수용.
const CAFE_EXT_DOOR := Vector2i(8, 31)    # 외관 카페 문(닿으면 진입, 아트 문 로컬 x3=rect.x+3와 정렬) — _carve_village_paths 동선과 연결

# ── ★ M2.1 나루 마을 허브 야외 건물(강+다리 동/서 분할 레이아웃) ───────────────────
# 카페만 실내가 있고(M1.4 이주), 메인 집 3(미호·멜·바나)·만물상·주민 집은 이 슬라이스에선
# 그레이박스 외관(통과 불가 WALL 박스 + 문 리세스 1칸) + 라벨이다. 실내·만물상 서비스·축제는
# 후속 슬라이스(M2.2~). "기존 집 에셋 재사용 외관 재도색"(residents.md)도 후속 에셋 단계.
# ★ ADR-0018 C3 — 100×72 코지-와이드: 강(WATER)이 x49·50 세로로 흐르며 마을을 서/동으로 가르고,
#   다리(BRIDGE_Y 36 = 메인 가로 복도)가 유일한 도하점. 8채 외관을 넓은 무대에 코지하게 분산한다
#   (서: 카페·미호·멜·바나 / 동: 만물상·주민집3). 건물 *크기*는 외관 아트 1:1이라 불변, *위치*만 펼침.
const RIVER_X := [49, 50]          # 강 세로 칸(WATER, 통과 X) — 동/서 분할(맵 중앙)
const RIVER_Y0 := 1                # 강 시작 y(맨 위 경계벽 바로 아래 — 북쪽 우회 도하 차단)
const RIVER_Y1 := 70               # 강 끝 y(아래 경계벽 y71 바로 위 — 남쪽 우회 도하 차단)
const BRIDGE_Y := 36               # 다리 = 강 위 PATH 한 줄(메인 가로 복도와 같은 줄 — 유일한 도하점)
# 서편(도착·서워프 옆): 카페(도착 위, CAFE_EXT_RECT 위쪽 정의) + 메인 집 3(미호·멜·바나). 코지 여백으로 흩어 둔다.
const MEL_HOUSE_RECT := Rect2i(20, 14, 5, 5)   # 멜 집 — 서편 상단 우
const MEL_HOUSE_DOOR := Vector2i(22, 18)
const MIHO_HOUSE_RECT := Rect2i(5, 44, 4, 4)   # 미호 집 — 서편 하단 좌
const MIHO_HOUSE_DOOR := Vector2i(6, 47)
const BANA_HOUSE_RECT := Rect2i(30, 44, 4, 4)  # 바나 집 — 서편 하단 우
const BANA_HOUSE_DOOR := Vector2i(31, 47)
# 동편(다리 건너): 만물상(상단 좌) + 주민 집 3(점진 추가의 시작 — 더 많은 주민 집은 후속).
const STORE_EXT_RECT := Rect2i(58, 14, 6, 5)   # 만물상
const STORE_EXT_DOOR := Vector2i(60, 18)
const RESIDENT_HOUSE_RECTS := [
	Rect2i(80, 14, 5, 4),  # 주민 집 1 — 동편 상단 우
	Rect2i(58, 44, 4, 4),  # 주민 집 2 — 동편 하단 좌
	Rect2i(82, 44, 4, 4),  # 주민 집 3 — 동편 하단 우
]
const RESIDENT_HOUSE_DOORS := [Vector2i(82, 17), Vector2i(59, 47), Vector2i(83, 47)]

# 실내 방(맵 아래 별도 구역, 외부와 멀리 떨어져 카메라로 격리). 넓게 잡아 방 안을 돌아다닐 공간을 둔다.
# ★C3 — 마을 공유 집·카페 실내를 마을 밴드(y72+)로 +48 평행이동(마을 전용 상수라 in-place 이동 —
#   다른 구역 MUSEUM/SMITHY/GUILD는 별도 상수라 무관). 방 크기·문·내부 레이아웃 보존, y만 띠 아래로.
const HOUSE_RECT := Rect2i(8, 74, 12, 9)    # x8..19,  y74..82 (마을 공유 집 6채 전용. HOME 집은 HOME_HOUSE_RECT)
const CAFE_RECT := Rect2i(8, 86, 13, 10)    # x8..20,  y86..95 (카페 실내 13×10)
const HOUSE_DOOR := Vector2i(13, 82)        # 실내 집 문(닿으면 퇴장) — 아래벽 중앙
const CAFE_DOOR := Vector2i(14, 95)         # 실내 카페 문 — 아래벽 중앙

# 진입/퇴장 텔레포트 칸. 워프 직후 같은 프레임에 재트리거되지 않게 문 칸 자체가 아니라
# 한 칸 안/밖에 내려놓는다(실내=문 위, 외부=문 아래).
const HOUSE_IN_TILE := Vector2i(13, 81)     # 실내 집 문 안쪽 (+48)
const CAFE_IN_TILE := Vector2i(14, 94)      # 실내 카페 문 안쪽 (+48)
const HOUSE_OUT_TILE := HOUSE_EXT_DOOR + Vector2i(0, 1)  # 외관 본가 문 앞 (44,10) — 저지 북중앙
const CAFE_OUT_TILE := CAFE_EXT_DOOR + Vector2i(0, 1)    # 외관 카페 문 앞 (5,10) — 서편 카페 동선

# ── ★ C2 — 안식 농원 전용 집 실내(HOME 밴드 y67+) ─────────────────────────────
# HOME outdoor_h이 24→65로 커져, 공유 HOUSE_RECT(y26 띠)는 이제 HOME *외부*(밭/여백)와 충돌한다.
# → HOME 집 실내만 HOME 밴드(y65~92)로 분리: HOUSE_*(y26)에 +41(=65-24)을 더한 좌표. 내부 레이아웃
# (방 12×9·문·카메라 폭)은 똑같이 보존하고 y만 띠 아래로 내린다. 마을 6채는 HOUSE_*(y26) 그대로 공유
# → 마을·타 7구역 회귀 0. 외관(HOUSE_EXT_*·HOUSE_OUT_TILE)은 외부 NW라 +41 대상 아님(위 그대로).
const HOME_HOUSE_RECT := Rect2i(8, 67, 12, 9)     # x8..19, y67..75 (HOUSE_RECT + (0,41))
const HOME_HOUSE_DOOR := Vector2i(13, 75)         # 실내 집 문 서칸(아래벽 중앙, 방 x8..19) — HOUSE_DOOR + (0,41)
const HOME_HOUSE_DOOR_E := Vector2i(14, 75)       # ★[ADR-0046] 실내 본가 문 동칸 — 실내문≡외관문(2칸·중앙). 방 12폭 중앙 seam x13/x14 straddle. 퇴장 트리거 양 칸 수용.
const HOME_HOUSE_IN_TILE := Vector2i(13, 74)      # 실내 집 문 안쪽(진입 착지) — HOUSE_IN_TILE + (0,41)
const HOME_HOUSE_CAM_RECT := Rect2i(2, 65, 20, 13)  # 집 방 둘레 — HOUSE_CAM_RECT + (0,41)
# ★ ADR-0048 Phase D — 저장 상자 칸(집 실내 북벽 flush, 침대(9,68) 옆). 플레이어가 (11,69)에서 위를
# 바라보며(facing_chest) 우클릭으로 상자 패널을 연다. 집 바닥(HOUSE, 걷기 O)이라 좌표만 정하면 되고(충돌
# 없는 순수 배치 — 상태는 chest 노드가 든다), _indoor=="집"으로 가드해 다른 구역 같은 좌표엔 무반응.
const CHEST_TILE := Vector2i(11, 68)

# ── ★ ADR-0035 Phase B — 80×65 안식 비대칭 Overgrown 개간 재배치 ──────────────────
# 본가+창고(북동 저지 병렬, 자재 동선) / 5×5 스타터 패치(본가/창고 남쪽, debris 0%·즉경작) /
# 영혼빛 연못(중앙-약간서) / 고지 하늘 목장(NW, 절벽+계단으로만 진입 — debris 하드 게이트) /
# 나머지 저지=overgrown debris 밭. 옛 FARM_RECT 중앙 대형 밭은 삭제(스타터 패치 + overgrown으로 대체).
const STARTER_PATCH_RECT := Rect2i(40, 12, 5, 5)  # x40..44, y12..16 (본가/창고 남쪽 5×5 — debris 0%·즉경작 SOIL)
# ★ [ADR-0055] 재점령(잡초 재생) 스캔 범위 — overgrown 저지 마당(debris 밭 x28..60·y20..56을 여유로 감쌈).
#   이 rect 안의 빈 맨땅(GROUND·프롭·밭 미점유)만 밤새 잡초가 다시 덮는다. NW 하늘 목장·먼 코너 나무숲·
#   남단 seam은 밖(마당 밖 잔디는 재점령 대상 아님 — cozy 스코프). 정밀 범위는 Phase 3 밸런싱 레버.
const ENCROACH_SCAN_RECT := Rect2i(26, 18, 36, 40)  # x26..61, y18..57
const SPIRIT_POND_RECT := Rect2i(26, 34, 8, 7)    # ★ADR-0035 영혼빛 연못 x26..33, y34..40 (WATER — 물뿌리개·낚시 앵커, 메카닉 Slice 3)
const SPAWN_TILE := Vector2i(40, 60)       # 도착 지점(남단 중앙) — 불변(구역 경계 seam)

# 실내 모드 카메라 경계(타일). 각 방을 비추되 외부·다른 방·경계벽이 화면에 들어오지 않게 잡는다.
# 폭 20타일 = 화면폭이라 가로는 고정되고, 세로만 방을 따라 스크롤한다. 방 밖은 VOID(검정).
# 외부 모드 경계는 Rect2i(0, 0, MAP_W, OUTDOOR_H)로 코드에서 만든다(아래 실내 구역 제외).
const HOUSE_CAM_RECT := Rect2i(2, 72, 20, 13)   # 집 방(x8..19 y74..82) 둘레 — ★C3 +48(마을 공유 집 전용, HOME=HOME_HOUSE_CAM_RECT)
const CAFE_CAM_RECT := Rect2i(2, 85, 20, 13)    # 카페 방(x8..20 y86..95) 둘레 — ★C3 +48
# ── ★ M2.2 만물상 실내 방 ───────────────────────────────────────────────────
# 집 방(HOUSE_RECT, x8..19) *옆* 칸(x23..32, 같은 y26..34 띠)에 둔다 — 세로 스택 대신 가로 배치라
# MAP_H를 안 늘리고도(warp_test의 grid 크기 불변식 유지) 만물상 전용 방을 추가한다. 집(HOUSE) 대신
# 카페(CAFE) 타일을 깔아 6채 메인/주민 집(아늑한 청회)과 시각으로 구분한다(상업 톤). 만물상 *서비스*
# (점주 T2·매대)는 다음 슬라이스 — 이 슬라이스에선 enterable graybox 방까지만.
const STORE_RECT := Rect2i(23, 74, 10, 9)       # x23..32, y74..82 (집 방 옆, 같은 띠) — ★C3 +48
const STORE_DOOR := Vector2i(27, 82)            # 실내 만물상 문(닿으면 퇴장) — 아래벽 (+48)
const STORE_IN_TILE := Vector2i(27, 81)         # 실내 만물상 문 안쪽(진입 착지) (+48)
const STORE_CAM_RECT := Rect2i(21, 72, 14, 13)  # 만물상 방 둘레(집 방 x2..21·카페 y85..과 안 겹침) — ★C3 +48
# ── ★ 안식 농원 확장 — 창고(enterable 그레이박스 방) ─────────────────────────
# HOME 외부 동편(카페 이주로 비워진 x30..35 y4..9)에 창고 외관을 세우고, 실내 띠 동편
# (x23..32 y38..46 — 카페 방 x8..20·만물상 방 y26..34과 안 겹침)에 들어갈 수 있는 빈 방을 둔다.
# M2.2 만물상 방 패턴(_build_building_catalog 데이터 주도)을 그대로 재사용 — 출입·카메라·세이브가
# 자동으로 굴러간다(하드코딩 0). 저장(아이템 보관) 메카닉은 후속(도구/아이템 시스템 생길 때) —
# 지금은 enterable 빈 방까지. MAP_H 불변(가로 배치, warp_test 그리드 불변식). 집 톤(HOUSE) 바닥을
# 재사용하되 카탈로그 kind="storehouse"라 _draw 가구 분기(_is_in_house_interior/카페/만물상) 어디에도
# 안 걸려 *빈* 방으로 그려진다(분기 추가 0 — "그 외 graybox"의 자연 표현).
# ★ C2 — 외관은 80×65 북동(NE)으로, 실내는 HOME 밴드(+41)로 이동(집 실내 옆 띠와 안 겹침).
const STOREHOUSE_EXT_RECT := Rect2i(28, 3, 6, 6)    # ★ADR-0035 Phase B x28..33, y3..8 (본가 왼쪽 병렬 — 자재 동선·서쪽=계단/고지 방향)
const STOREHOUSE_EXT_DOOR := Vector2i(30, 8)       # 외관 창고 문 서패널(닿으면 진입) — 아래벽 x28..33 중심 straddle → 2칸 양문 x30·x31, _carve_paths 서편 레인 연결
const STOREHOUSE_EXT_DOOR_E := Vector2i(31, 8)     # ★ 창고 양문 동패널(아트 문이 2칸이라 리세스·진입로도 2칸 — 문/길 폭 정합). 진입 트리거는 서패널만.
const STOREHOUSE_RECT := Rect2i(23, 79, 10, 9)     # x23..32, y79..87 (HOME 밴드 — 집 방 y67..75 아래, 안 겹침)
const STOREHOUSE_DOOR := Vector2i(27, 87)          # 실내 창고 문 서칸(닿으면 퇴장) — 아래벽 중앙(방 x23..32, end.y-1)
const STOREHOUSE_DOOR_E := Vector2i(28, 87)        # ★[ADR-0046] 실내 창고 문 동칸 — 실내문≡외관문(2칸). 방 10폭 중앙 seam x27/x28. 퇴장 트리거 양 칸 수용.
const STOREHOUSE_IN_TILE := Vector2i(27, 86)       # 실내 창고 문 안쪽(진입 착지)
const STOREHOUSE_CAM_RECT := Rect2i(22, 78, 14, 13)  # 창고 방 둘레(집 방 CAM y65..77과 안 겹침)
# ★ ADR-0048 Phase E — 갈무리방(창고) 저장 상자 칸(실내 북서 벽 flush, 문(27,86)·짐승 없는 빈 창고라 자유
# 배치). 플레이어가 (25,82)에서 위를 바라보며(facing_storehouse_chest) 우클릭으로 상자 패널을 연다. 창고
# 바닥(HOUSE, 걷기 O)이라 좌표만 정하면 되고(충돌 없는 순수 배치 — 상태는 storehouse_chest 노드가 든다).
const STOREHOUSE_CHEST_TILE := Vector2i(25, 81)
# ── ★ [Track B B1-a] 동물 2건물 분리·진입 실내 — 넋우릿간(대형·안개소) + 넋둥우리(소형·노을닭) ──
# S1-7의 단일 비진입 축사를 SDV처럼 2건물(대형/소형)로 갈라 각각 enterable로 승격한다(farm-buildings-
# roster §1·§3, track-b 설계 memo Q2=A "들어가서 실내 돌봄"). 창고(STOREHOUSE_*) 패턴을 그대로 재사용 —
# 외관 WALL 박스 + 남향 2칸 문(고지 방목지로 열림) / HOME 실내 밴드(y65+, 집·창고 방과 안 겹침)에 빈
# 그레이박스 방 / _build_building_catalog dict 등록으로 출입·카메라·세이브가 데이터 주도 자동. 짐승은
# 실내에 거주하고 돌봄도 실내에서 이뤄진다(방목 왕래 pathing=B1-a.2·여물통=B1-a.3). 고지 footprint는
# 현 남단 고지(x0..20 y12..25)가 2건물+방목지를 이미 수용하므로 terraform 불요 → 여물광 자리가 필요한
# B1-a.3로 이연. 실내 방은 x38+ 열에 배치(집 x8..19·창고 x22..35 CAM과 안 겹침).
# 넋우릿간(대형·barn형·안개소) — 현 축사 외관 자리 유지, enterable 승격.
const NEOKURITGAN_EXT_RECT := Rect2i(3, 14, 6, 4)   # x3..8, y14..17 (남단 고지 — 6×4 대형, owner 2026-07-03d·절벽=천연 울타리)
const NEOKURITGAN_EXT_DOOR := Vector2i(6, 17)       # 외관 문 동패널(닿으면 진입) — 아래벽 x3..8 중심 straddle → 2칸 문 x5·x6, 남향 방목지로 열림
const NEOKURITGAN_EXT_DOOR_W := Vector2i(5, 17)     # 외관 2패널 문 서패널(아트 문 2칸 = 리세스·진입로 2칸 정합). 진입 트리거는 양 칸 수용.
const NEOKURITGAN_RECT := Rect2i(38, 67, 12, 9)     # 실내 x38..49, y67..75 (HOME 밴드 — 집·창고 방과 안 겹침)
const NEOKURITGAN_DOOR := Vector2i(43, 75)          # 실내 문 서칸(닿으면 퇴장) — 아래벽 중앙(방 x38..49, end.y-1)
const NEOKURITGAN_DOOR_E := Vector2i(44, 75)        # 실내 문 동칸(실내문≡외관문 2칸). 퇴장 트리거 양 칸 수용.
const NEOKURITGAN_IN_TILE := Vector2i(43, 74)       # 실내 문 안쪽(진입 착지)
const NEOKURITGAN_CAM_RECT := Rect2i(37, 66, 14, 11)  # 넋우릿간 방 둘레(창고 CAM x22..35과 안 겹침)
# 넋둥우리(소형·coop형·노을닭) — 신설, 넋우릿간 동편 병렬(고지 위).
const NEOKDUNGURI_EXT_RECT := Rect2i(10, 14, 4, 2)  # x10..13, y14..15 (coop 4×2·소형, owner 2026-07-03; 넋우릿간 6×4 동쪽 1칸 간격 병렬)
const NEOKDUNGURI_EXT_DOOR := Vector2i(13, 15)      # 외관 문 동패널 — 아래벽 x10..13 우측 2칸 문 x12·x13(스타듀 coop식·아트 문 우측 정합), 남향 방목지로 열림
const NEOKDUNGURI_EXT_DOOR_W := Vector2i(12, 15)    # 외관 2패널 문 서패널(coop 문=우측 배치, barn 중앙과 갈림)
const NEOKDUNGURI_RECT := Rect2i(38, 79, 12, 9)     # 실내 x38..49, y79..87 (넋우릿간 방 y67..75 아래, 창고 방 x22..32과 안 겹침)
const NEOKDUNGURI_DOOR := Vector2i(43, 87)          # 실내 문 서칸(닿으면 퇴장)
const NEOKDUNGURI_DOOR_E := Vector2i(44, 87)        # 실내 문 동칸
const NEOKDUNGURI_IN_TILE := Vector2i(43, 86)       # 실내 문 안쪽(진입 착지)
const NEOKDUNGURI_CAM_RECT := Rect2i(37, 78, 14, 11)  # 넋둥우리 방 둘레(넋우릿간 CAM y66..76·창고 CAM과 안 겹침)
# 동물 건물 id(세이브 _indoor 직렬화 값 — 안정 고정). 실내 돌봄·pathing이 소속 판정에 쓴다.
const ANIMAL_BUILDINGS := ["넋우릿간", "넋둥우리"]
# ★ [S1-7] 하늘 목장 방목지 — 두 건물 남쪽 고지 평면(phaseB §5.4 단일 방목 Zone·절벽=천연 펜). B1-a.1에선
#   짐승이 실내 거주라 방목지는 비어 있고(B1-a.2 pathing이 낮 방목으로 채움), 문 앞 진입로만 깐다.
const PASTURE_SCAN_RECT := Rect2i(3, 18, 11, 6)   # x3..13, y18..23 (두 건물 문 아래 방목 평면 — B1-a.2 방목 목적지; 넋둥우리 x13 확대 반영)
# ★ [B1-a.3] 여물광(Silo·비진입 저장 건물) — 고지 동편 자유 풀밭(건물 x3..12 동쪽, 계단 x21 서쪽). 낫으로
#   벤 사료풀이 여기 쌓인다(Ranch._silo_hay). 문·실내 없음 = WALL 박스 그레이박스(아트 후행, 넋둥우리 결).
const SILO_EXT_RECT := Rect2i(15, 14, 3, 3)       # x15..17, y14..16 (넋둥우리 x10..13 동쪽 자유 고지, 1칸 간격)
# ★ [B1-a.3] 사료풀 밭 — 낫으로 베어 건초를 얻는 고지 풀(재생·겨울정지). 여물광 남쪽 자유 풀밭(방목지
#   x3..12과 안 겹침 — 방목 짐승과 분리). main이 이 rect의 비-SOLID 타일을 Forage에 시드한다.
const FORAGE_SCAN_RECT := Rect2i(14, 21, 6, 3)    # x14..19, y21..23 (여물광 아래 동편 고지 풀밭 — 방목지 x3..13과 안 겹침)
# ★ [B2 · 혼우물] 물뿌리개 리필 우물(Well) — 비진입 그레이박스 구조물(문·실내 없음 = WALL 박스, 여물광 결).
#   ⚠️ 리필 메카닉은 아직 없다(유한 물뿌리개 = 별도 grill 후 도입) → 지금은 farm-infra 자리만 잡는 shell.
#   스타터 밭(x40..44 y12..16) 남쪽 1칸 아래(y17 여백) — "밭에 물 대는 우물"로 읽히는 farm-infra 존.
const WELL_RECT := Rect2i(40, 18, 3, 3)           # x40..42, y18..20 (밭 남쪽 — 중앙 스파인 x38 곁, 접근 스퍼로 연결)
# ── ★ M3.1 삼도천(강 낚시 무대 + 혼백관) ───────────────────────────────────────
# 셋째 실데이터 구역(ADR-0015 "빌드는 한 구역씩"). 낚시 메카닉은 만들지 않는다(Phase 3) — 강(WATER)
# 무대 + 강 낚시터(라벨만) + 혼백관(enterable 빈 방)까지 그레이박스로 깐다.
# ★ ADR-0018 C4 — 낚시 무대 코지-와이드 56×40 재배치. 나루 마을 나룻터(52,1)에서 배로 건너 남단
#   spawn(28,38)에 도착하고, 동단 하구(54,20)가 황천해로 가는 워프(점등). 강을 굵은 상단 가로 띠
#   (y1..8 — 낚시 무대다운 진짜 강)로 흘려 그 아래 둑(y9..39)은 한 덩어리(다리 불필요·flood-fill 단순).
const SAMDO_RIVER_Y0 := 1                       # 강(WATER) 상단 띠 시작 y(경계벽 y0 바로 아래)
const SAMDO_RIVER_Y1 := 8                       # ★C4 강 띠 끝 y(굵은 강) — y9 이하가 강 낚시터 둑(land)
const SAMDO_FISHING_LABEL_TILE := Vector2i(28, 10)  # ★C4 강 낚시터 라벨 자리(물가 둑, 낚시 메카닉 Phase 3)
# 혼백관(enterable 빈 방) — 외관(land)·실내 방(삼도천 밴드). 창고·만물상 결의 데이터 주도 출입.
# kind="museum"이라 _draw 가구 분기(house/cafe)에 안 걸려 빈 방으로 그려진다(분기 추가 0).
# ★C4 — outdoor_h 40>26이라 공유 실내 띠(y26~)가 외부(둑)와 겹쳐 → 실내 방·문·카메라를 삼도천 밴드로
#   +18 평행이동(y44~ — HOME +41·마을 +48 결). 외관은 둑 서편(y14~19, 굵은 강 아래)으로 재배치.
const MUSEUM_EXT_RECT := Rect2i(6, 14, 7, 6)    # ★C4 x6..12, y14..19 (굵은 강 아래 둑 서편)
const MUSEUM_EXT_DOOR := Vector2i(9, 19)        # 외관 혼백관 문(닿으면 진입) — _carve_samdocheon_paths 동선 연결
const MUSEUM_RECT := Rect2i(8, 44, 12, 9)       # ★C4 x8..19, y44..52 (실내 방 — 삼도천 밴드 +18)
const MUSEUM_DOOR := Vector2i(13, 52)           # 실내 혼백관 문(닿으면 퇴장) — 아래벽 중앙(+18)
const MUSEUM_IN_TILE := Vector2i(13, 51)        # 실내 문 안쪽(진입 착지, +18)
const MUSEUM_CAM_RECT := Rect2i(2, 42, 20, 13)  # ★C4 혼백관 방 둘레(외부·다른 방 격리, +18)
# ── ★ M3.2 황천해(바다 낚시 무대 + 생선가게) ──────────────────────────────────
# 넷째 실데이터 구역(막다른 바다). 낚시 메카닉은 만들지 않는다(Phase 3) — 바다(WATER) 무대 + 부두(잔교)
# + 바다 낚시터(라벨만) + 생선가게(enterable 빈 방)까지. 삼도천 하구에서 서단 spawn(2,15)에 도착.
# ★ ADR-0018 C5 — 64×44 코지-와이드("넓은 바다·개방감"). 바다는 ㄴ자 만(남측 y≥SEA_Y0 + 동측 x≥SEA_X0)
# 으로 깔려 SE가 탁 트인 수면이고, 그 NW가 한 덩어리 land(x1~SEA_X0-1, y1~SEA_Y0-1 — flood-fill 단순).
# 부두(PATH)가 복도에서 남측 바다로 길게 뻗어 그 끝(PIER_Y1)이 바다 낚시터(Phase 3 캐스팅 자리). 강(삼도천)과
# 같은 WATER 타일 재사용(물 색 차별화는 후속). 조수웅덩이는 미룸(낚시 메카닉/에셋 Phase — 만에 공간만 확보).
const SEA_X0 := 38                              # ★C5 동측 바다(WATER) 띠 시작 x — 그 왼쪽(x1~37)이 land
const SEA_Y0 := 28                              # ★C5 남측 바다 띠 시작 y — 그 위(y1~27)가 land. ㄴ자 만(남+동)
const PIER_X := 24                              # 부두(잔교) 세로 칸 — 남측 바다로 뻗음(WATER 위 PATH 덮어 걸을 수 있게)
const PIER_Y0 := 15                             # 부두 시작 y(복도 y15 — 복도에서 바다로 내려가는 잔교 진입)
const PIER_Y1 := 37                             # ★C5 부두 끝 y(남측 바다 한가운데 = 바다 낚시터, ~10칸 돌출)
const SEA_FISHING_LABEL_TILE := Vector2i(24, 36)   # ★C5 바다 낚시터 라벨 자리(부두 끝, 낚시 메카닉 Phase 3)
# 생선가게(enterable 빈 방) — 외관(NW land)·실내 방(황천해 밴드). 혼백관·창고 결의 데이터 주도 출입.
# kind="fishshop"이라 _draw 가구 분기에 안 걸려 빈 방(도구·미끼·물고기 거래 서비스는 후속).
# ★C5 — outdoor_h 44>26이라 공유 실내 띠(y26~)가 외부(land)와 겹쳐 → 실내 방·문·카메라를 황천해 밴드로
#   +20 평행이동(y46~ — 혼백관 +18·창고 +41·마을 +48 결). 외관은 NW land(굵은 바다 위쪽)에 유지.
const FISHSHOP_EXT_RECT := Rect2i(5, 5, 7, 6)   # x5..11, y5..10 (NW land, 바다 위쪽)
const FISHSHOP_EXT_DOOR := Vector2i(8, 10)      # 외관 생선가게 문(닿으면 진입) — _carve_hwangcheonhae_paths 동선 연결
const FISHSHOP_RECT := Rect2i(8, 46, 12, 9)     # ★C5 x8..19, y46..54 (실내 방 — 황천해 밴드 +20)
const FISHSHOP_DOOR := Vector2i(13, 54)         # 실내 생선가게 문(닿으면 퇴장) — 아래벽 중앙(+20)
const FISHSHOP_IN_TILE := Vector2i(13, 53)      # 실내 문 안쪽(진입 착지, +20)
const FISHSHOP_CAM_RECT := Rect2i(2, 44, 20, 13)  # ★C5 생선가게 방 둘레(외부·다른 방 격리, +20 — y44~ VOID 띠)
# ── ★ M4.1 / ★ ADR-0018 C6 저승 숲(채집 무대 + 목공방) ──────────────────────────
# 다섯째 실데이터 구역(ADR-0015 "빌드는 한 구역씩"). 채집 메카닉은 만들지 않는다(Phase 3) — 나무(TREE)
# 무대 + 채집지(라벨만) + 목공방(enterable 빈 방)까지. ★ M5.1: 업화 갱도가 지어져 남단 spawn은 갱도
# 북단 숲길에서 도착(정규 토폴로지 복원). 동단이 미혹의 숲 워프(M4.2 점등).
# ★ ADR-0018 C6 — 60×44 코지-와이드 재배치("빽빽한 가장자리 + 안쪽 빈터"). 가장자리 TREE 밴드가 깊은
#   숲을 둘러싸고(자연 경계 — 강·바다 결), 안쪽 빈터(GROUND)에 채집지 3곳이 흩어진다. 통과형(막다른
#   미혹의 숲 C7과 달리) — spawn(30,42, 남단·갱도에서 도착)·미혹 워프(58,22, 동단)·목공방(서편 land).
# 동선 = 가로 복도(y22, 서 목공방 9 ~ 동 미혹 58) + 남단 세로(x30, spawn 30,42·갱도 워프 30,43) + 목공방 문.
# 나무는 동선·목공방·워프 칸·빈터를 비껴간 밴드+군집으로 둬 숲 정체성을 주되 flood-fill 무 soft-lock(빈터=GROUND).
const FOREST_TREE_RECTS := [   # 나무(TREE) — 가장자리 밴드(상·하·좌·우) + 내부 악센트. 동선·워프·빈터 비껴감
	# 상단 밴드(y2~4, 가운데 빈터·공기 틈)
	Rect2i(2, 2, 12, 3),    # 북서 상단 x2..13
	Rect2i(24, 2, 14, 3),   # 북중 상단 x24..37
	Rect2i(48, 2, 9, 3),    # 북동 상단 x48..56
	# 좌측 밴드(x2~4, 복도 y22 비껴 위·아래)
	Rect2i(2, 8, 3, 8),     # 서 상부 y8..15
	Rect2i(2, 26, 3, 12),   # 서 하부 y26..37
	# 우측 밴드(x55~57, 미혹 워프 y22 비껴 위·아래)
	Rect2i(55, 6, 3, 12),   # 동 상부 y6..17
	Rect2i(55, 26, 3, 12),  # 동 하부 y26..37
	# 하단 밴드(y39~41, 남단 spawn 틈 x26~33 비껴 좌·우)
	Rect2i(4, 39, 22, 3),   # 남서 x4..25
	Rect2i(34, 39, 22, 3),  # 남동 x34..55
	# 내부 악센트 군집(빈터를 갈라 숲 밀도)
	Rect2i(10, 26, 6, 5),   # 내부 남서 x10..15, y26..30
	Rect2i(38, 14, 6, 4),   # 내부 북동 x38..43, y14..17
	Rect2i(46, 28, 7, 5),   # 내부 남동 x46..52, y28..32
]
const FOREST_FORAGE_LABEL_TILE := Vector2i(20, 8)   # ★C6 채집지 빈터①(북, 채집 메카닉 Phase 3)
const FOREST_FORAGE_LABEL_TILE_2 := Vector2i(45, 10) # ★C6 채집지 빈터②(북동)
const FOREST_FORAGE_LABEL_TILE_3 := Vector2i(42, 34) # ★C6 채집지 빈터③(남)
# 목공방(enterable 빈 방) — 외관(서편 land·나무 곁)·실내 방(아래 실내 띠). 혼백관·생선가게 결의 데이터 주도 출입.
# kind="woodshop"이라 _draw 가구 분기에 안 걸려 빈 방(집·농장 업그레이드 서비스, 로빈 대응은 후속).
# ★C6 — outdoor_h 44>26이라 공유 실내 띠(y26~)가 외부(land)와 겹쳐 → 실내 방·문·카메라를 저승 숲 밴드로
#   +20 평행이동(y46~ — 생선가게 +20·창고 +41 결). 외관은 서편 land(나무 곁)에 유지.
const WOODSHOP_EXT_RECT := Rect2i(6, 14, 7, 6)   # ★C6 x6..12, y14..19 (서편 land, 좌측 나무 밴드 곁)
const WOODSHOP_EXT_DOOR := Vector2i(9, 19)      # 외관 목공방 문(닿으면 진입) — _carve_jeoseung_forest_paths 동선 연결
const WOODSHOP_RECT := Rect2i(8, 46, 12, 9)     # ★C6 x8..19, y46..54 (실내 방 — 저승 숲 밴드 +20)
const WOODSHOP_DOOR := Vector2i(13, 54)         # 실내 목공방 문(닿으면 퇴장) — 아래벽 중앙(+20)
const WOODSHOP_IN_TILE := Vector2i(13, 53)      # 실내 문 안쪽(진입 착지, +20)
const WOODSHOP_CAM_RECT := Rect2i(2, 44, 20, 13)  # ★C6 목공방 방 둘레(외부·다른 방 격리, +20 — y44~ VOID 띠)
# ── ★ M4.2 / ★ ADR-0018 C7 미혹의 숲(특수 채집 무대 + 옥자 집) ──────────────────────
# 여섯째 실데이터 구역(막다른 깊은 숲). 채집 메카닉은 만들지 않는다(Phase 3) — 더 어둡고 깊은 숲(TREE
# 밀도↑ + 연못 WATER)·특수 채집지(라벨만)까지. 저승 숲 동단(58,22)에서 서단 spawn(2,22)에 도착(점등).
# ★ ADR-0018 C7 — 64×44 코지-와이드 재배치(황천해와 동일 footprint·종착 무게감). 저승 숲(통과형, 곧은
#   척추)과 달리 "곧은 척추 없음 — 굽이치는 동선": 에워싸는 빽빽한 외곽 나무 밴드 안을 ㄹ자로 헤쳐 동쪽
#   깊은 끝 옥자 집(숨겨진 종착)에 닿는다(미혹 = 굽이쳐 헤침). 연못은 키워 깊은 숲 무드·자연 장애물로 쓴다.
# ★ 옥자 집(마녀의 오두막)은 '숨겨진·게이트' — 잠긴 외관(비-enterable). _build_facade만(실내 방 없음),
#   _build_building_catalog에 미등록 → 문에 닿아도 진입 안 됨(축사 결). 실내·게이트 해제는 Phase 3 시나리오.
const MIHOK_TREE_RECTS := [   # ★C7 나무(TREE) — 에워싸는 빽빽한 외곽 밴드(4변, 저승보다 짙음) + 내부 악센트. spawn 틈·동선·옥자 집·연못·채집지 비껴감
	# 상단 밴드(y1~3, 가운데 공기 틈 x28~33)
	Rect2i(2, 1, 26, 3),    # 북서 x2..27
	Rect2i(34, 1, 28, 3),   # 북동 x34..61
	# 하단 밴드(y40~42)
	Rect2i(2, 40, 60, 3),   # 남 x2..61
	# 좌측 밴드(x2~4, spawn 틈 y19~24 비껴 위·아래)
	Rect2i(2, 4, 3, 15),    # 서 상부 y4..18
	Rect2i(2, 25, 3, 15),   # 서 하부 y25..39
	# 우측 밴드(x59~61, 옥자 집 비껴 위)
	Rect2i(59, 4, 3, 19),   # 동 상부 y4..22
	# 내부 악센트 군집(빈터를 갈라 깊은 숲 밀도 + 굽이 강조 — 동선·연못·채집지 비껴감)
	Rect2i(7, 5, 9, 4),     # 북서 내부 x7..15, y5..8
	Rect2i(40, 14, 6, 5),   # 중동 내부 x40..45, y14..18
	Rect2i(10, 33, 8, 4),   # 남서 내부 x10..17, y33..36
	Rect2i(48, 23, 5, 6),   # 옥자 집 서편 가림 x48..52, y23..28 (집 숨김)
]
const MIHOK_POND_RECT := Rect2i(26, 14, 12, 6)   # ★C7 연못(WATER, 통과 X) — 키운 물웅덩이(깊은 숲 "연못·이끼·고목", 동선이 위로 돈다)
const MIHOK_FORAGE_LABEL_TILE := Vector2i(50, 6)    # ★C7 특수 채집지①(북동 깊은 빈터, 채집 메카닉 Phase 3)
const MIHOK_FORAGE_LABEL_TILE_2 := Vector2i(30, 36) # ★C7 특수 채집지②(남 깊은 빈터)
# 옥자 집(마녀의 오두막) — 잠긴 외관(비-enterable). WALL 박스 + 문 리세스(시각 일관)만, 실내·카탈로그 없음.
const OKJA_HUT_EXT_RECT := Rect2i(54, 24, 8, 7)  # ★C7 x54..61, y24..30 (동쪽 깊은 끝, 숨겨진 잠긴 외관)
const OKJA_HUT_DOOR := Vector2i(57, 30)          # ★C7 문 리세스(남면, 시각 일관 — 진입 트리거 아님, 카탈로그 미등록)

# ── 업화 갱도(★ ADR-0018 C8 코지-와이드 재배치 — 채광/전투 무대·대장간·길드) ──────────
# 일곱째 실데이터 구역을 40×24 → 64×44로 역할별 재배치(ADR-0018 결정4 C8, C2~C7 결). 정체성 = "넓은
# 진폭으로 굽이치는 세로 협곡 + 남→북 위험 구배": 남단 입구(서비스) → 중단 채광 협곡 → 북단 봉인 심연 포켓.
# 채광·전투 메카닉은 만들지 않는다(Phase 3) — 바위(ROCK) 협곡벽·호수(WATER) 무대 + 대장간·길드(enterable
# 빈 방) + 던전 입구·나락 진입로(둘 다 잠긴 외관, 비-enterable, 옥자 집 결). 나루 마을 산길에서 남단
# spawn(14,42), 북단(40,1)에서 숲길로 저승 숲. 지그재그 세로 채널(x14→48→18→40)이 두 워프를 잇고,
# 협곡벽이 좌우로 번갈아 죈다(저승=곧은 가로 척추 / 미혹=분기 미로 / 갱도=분기 없이 굽이치는 단일 세로 협곡).
const MINE_ROCK_RECTS := [   # 바위(ROCK) 협곡벽 — 지그재그 채널(x14→48→18→40)을 좌우로 번갈아 죄어 "굽이치는 협곡"(동선·문·게이트·라벨·호수 비껴감)
	Rect2i(2, 2, 18, 5),     # 북서벽(심연 포켓 서편 막음)
	Rect2i(52, 2, 11, 14),   # 동북벽
	Rect2i(1, 8, 11, 12),    # 서벽 상부(x0 경계벽 곁 — 좌상단 ROCK 보장)
	Rect2i(20, 14, 18, 4),   # 중앙 가로 암반(세로 채널 굽이 사이 죔)
	Rect2i(50, 18, 13, 18),  # 동벽 중하부
	Rect2i(2, 27, 11, 9),    # 서벽 중하부
	Rect2i(44, 33, 16, 8),   # 남동벽
	Rect2i(20, 34, 16, 7),   # 남단 바닥 암반(길드 위 — 입구 빈터와 채광 협곡 분리)
]
const MINE_LAKE_RECT := Rect2i(3, 22, 8, 5)     # 호수(WATER, 통과 X) — world-map "호수"(남서 니치, 채널이 위로 돌아 비껴감 — 미혹 연못 결 8×5)
const MINE_ORE_LABEL_TILES := [   # 채광지 라벨 자리 3곳(빈터, 채광 메카닉 Phase 3) — 채광 본진이라 숲 채집(미혹 2곳)보다 촘촘, 협곡 굽이 포켓마다
	Vector2i(22, 13),   # 채광지①(북, seg6 곁)
	Vector2i(33, 21),   # 채광지②(중, seg4 곁)
	Vector2i(44, 30),   # 채광지③(남동, seg2/seg3 곁)
]
# 대장간(업화로 — 도구·무기, enterable 빈 방). 외관=남단 입구 서편, 실내=실내 띠(y≥44, fishshop/woodshop 결).
const SMITHY_EXT_RECT := Rect2i(4, 37, 6, 5)    # x4..9, y37..41 (남단 입구 서편)
const SMITHY_EXT_DOOR := Vector2i(6, 41)        # 외관 대장간 문(닿으면 진입) — 남단 apron으로 carve
const SMITHY_RECT := Rect2i(8, 46, 12, 9)       # x8..19, y46..54 (실내 방 — 실내 띠, 구역별 빌드라 좌표 겹쳐도 무해)
const SMITHY_DOOR := Vector2i(13, 54)           # 실내 대장간 문(닿으면 퇴장) — 아래벽 중앙
const SMITHY_IN_TILE := Vector2i(13, 53)        # 실내 문 안쪽(진입 착지)
const SMITHY_CAM_RECT := Rect2i(2, 44, 20, 13)  # 대장간 방 둘레(외부·다른 방 격리)
# 모험가 길드(전투 장비, enterable 빈 방). 외관=남단 입구 동편, 실내=대장간 방 옆 칸(cam 비겹침).
const GUILD_EXT_RECT := Rect2i(22, 37, 6, 5)    # x22..27, y37..41 (남단 입구 동편)
const GUILD_EXT_DOOR := Vector2i(24, 41)        # 외관 길드 문(닿으면 진입) — 남단 apron으로 carve
const GUILD_RECT := Rect2i(23, 46, 10, 9)       # x23..32, y46..54 (실내 방 — 대장간 방 옆, 같은 띠)
const GUILD_DOOR := Vector2i(27, 54)            # 실내 길드 문(닿으면 퇴장) — 아래벽
const GUILD_IN_TILE := Vector2i(27, 53)         # 실내 문 안쪽(진입 착지)
const GUILD_CAM_RECT := Rect2i(21, 44, 14, 13)  # 길드 방 둘레(대장간 CAM x2..21과 안 겹침)
# 갱도 끝 전투 던전 입구 — 잠긴 외관(비-enterable). 북단 심연 포켓 서편. 채광으로 뚫고 내려가 전투(ADR-0015)는 Phase 3라 잠김.
# WALL 박스 + 문 리세스만(실내·카탈로그 없음 — 옥자 집 결). 나락(별개 공간)과 다른 잠긴 외관.
const DUNGEON_GATE_EXT_RECT := Rect2i(22, 2, 5, 5)  # x22..26, y2..6 (북단 심연 포켓 서, 잠긴 던전 입구)
const DUNGEON_GATE_DOOR := Vector2i(24, 6)          # 문 리세스(시각 일관 — 진입 트리거 아님, 카탈로그 미등록)
# 나락 진입로 — 잠긴 외관(비-enterable). 독립 전투 던전(나락)으로 가는 '서랍' 진입로라 Phase 3 전투에서 점등.
# WALL 박스 + 문 리세스만(실내·카탈로그 없음, 라이브 워프 없음 — 옥자 집 결).
const NARAK_GATE_EXT_RECT := Rect2i(30, 2, 5, 5)    # x30..34, y2..6 (북단 심연 포켓 동, 잠긴 나락 진입로)
const NARAK_GATE_DOOR := Vector2i(32, 6)            # 문 리세스(시각 일관 — 진입 트리거 아님, 카탈로그 미등록)

# ── 나락(M5.2 빌드 → ADR-0018 C9 코지-와이드 재배치) ─────────────────────────────
# 여덟째 실데이터 구역(독립 전투 전용). 전투 메카닉은 만들지 않는다(Phase 3) — 심연·업화·봉인 모티프의 빈
# 전투장 무대까지. 진입로는 업화 갱도의 잠긴 외관(비-enterable)이라 인게임 진입 없음 — 헤드리스 테스트가
# _region 직접 세팅해 빌드·검증한다(잠긴 진입로, world-map §5 '서랍'). spawn=(32,22) 전투장 정중앙.
# ★ C9(2026-06-24): 64×44로 키우며 ROCK 배치를 "깨진 봉인 고리"로 — 경계벽 안쪽 둘레로 ROCK 띠를 두르되
#   네 변 중앙(잡귀 누출구)과 네 모서리를 끊어 8세그먼트로. 봉인(고리)+심연(중앙 열린 공동)+끊긴 틈=탈주
#   잡귀 누출(CONTEXT lore). 중앙 아레나(x9..54·y9..34)는 완전 개방 = 전투 캔버스(A 일관성 패스, 동선 미설계).
const NARAK_ROCK_RECTS := [
	# 상변(y6..8) — 중앙 x28..36 틈(누출구)·양 모서리 개방
	Rect2i(10, 6, 18, 3),  Rect2i(37, 6, 18, 3),
	# 하변(y35..37)
	Rect2i(10, 35, 18, 3), Rect2i(37, 35, 18, 3),
	# 좌변(x6..8) — 중앙 y20..24 틈(누출구)
	Rect2i(6, 12, 3, 8),   Rect2i(6, 25, 3, 8),
	# 우변(x55..57)
	Rect2i(55, 12, 3, 8),  Rect2i(55, 25, 3, 8),
]
# ★ M2.2 — 공유 집 실내(HOUSE_RECT)를 쓰는 나루 마을 6채(메인 집 3 + 주민 집 3). 외관 문·퇴장
# 칸만 건물마다 다르고 실내 방·문·카메라는 한 방을 공유한다(_build_building_catalog·가구 재사용).
const HOUSE_IDS := ["미호집", "멜집", "바나집", "주민집1", "주민집2", "주민집3"]
# T3.2 미호 밭 자리 — 밭 남쪽 입구(도착→복도→밭 동선의 첫 밭 칸). 길에서 위를 바라보면
# 바로 미호를 향하게 되어, 멘토가 밭 문 앞에서 맞이하는 자연스러운 첫 만남. 이 칸은 미호가
# 카페로 출근한 오후에도 농사 대상에서 제외한다(_is_farmable — 돌아올 자리는 비워 둔다).
const MIHO_FIELD_TILE := Vector2i(42, 14)   # ★ADR-0035 Phase B: 스타터 패치(40,12,5,5) 안 — 농사 멘토 미호 자리
# T5.6 미호 카페 출근 자리 — 카페 뒷벽 줄(y=5)에서 멜(33,5) 오른쪽. 영업 시작(15시)부터
# 미호가 여기로 출근해 직원이 오후 카페에 모이는 무대를 만든다(ADR-0007). 카페 바닥이라
# 농사 대상이 아니고(밭과 안 겹침), 좌석(y=7)·문(33,10)·멜·옥자 칸과도 갈린다.
const MIHO_CAFE_TILE := Vector2i(15, 88)   # 카페 직원 줄(y88, ★C3 +48), 멜 오른쪽
# T4.1 옥자가 오프닝 통보 때 서는 칸 — 스폰(20,21) 바로 위. 도착하자마자 옥자를 마주본다.
# 통보가 끝나면 옥자는 이 자리에서 사라지고 카페(OKJA_CAFE_TILE)로 상주를 옮긴다(T5.6).
const OKJA_INTRO_TILE := Vector2i(40, 58)   # ★ADR-0035 Phase B: 스폰(40,60) 바로 위 — 도착하자마자 옥자를 마주본다(저지 도달 가능 칸)
# T5.6 옥자 카페 상주 자리 — 카페 뒷벽 줄(y=5)에서 멜(33,5) 왼쪽. 통보를 마친 뒤(NOTICE
# 단계 지남) 여기로 옮겨 매일 보는 사장이 된다(풀 관계 트랙 없음, ADR-0005). 멜(33,5)·
# 미호 출근 자리(35,5)와 한 줄에 나란히 서고, 좌석·문 동선과는 칸이 갈린다.
const OKJA_CAFE_TILE := Vector2i(10, 88)   # 카페 직원 줄(y88, ★C3 +48), 멜 왼쪽
# T5.1 멜이 서 있는 칸 — 카페 안 뒷벽 가운데(카운터 자리). 카페 문(33,10)으로 들어와
# 위로 올라오면 바로 멜을 마주본다. 카페 바닥이라 농사 대상이 아니고(밭과 안 겹침),
# 카페 출하대(T3.1)도 멜이 카운터 얼굴이라 멜을 바라볼 때만 연다(T5.3 — 무인 카운터
# 제거, 멜 앞에서 E=대화·F=출하대·G=선물 세 동사를 한 접점으로 통합).
const MEL_TILE := Vector2i(13, 88)   # 카페 직원 줄(y88, ★C3 +48) 가운데(카운터 얼굴)
# T5.4 카페 손님 좌석 칸 — 카페 안 한 줄(멜 카운터 33,5 아래). 손님이 여기 앉고,
# 플레이어가 아래 칸(y=8)에 서서 위를 바라보며 E로 서빙한다. 카페 바닥이라 농사 대상이
# 아니고(밭과 안 겹침), 멜·문 동선과도 칸이 갈린다. 인덱스 = Cafe._seats 인덱스(좌석 0..2).
const SEAT_TILES := [Vector2i(11, 90), Vector2i(14, 90), Vector2i(17, 90)]   # 카페 좌석 줄(y90, ★C3 +48)
const CUST := Color(0.55, 0.42, 0.50)  # 손님 그레이박스(회색 기조 + 옅은 자줏빛, NPC들과 구분)
# T6.1 바나가 서는 밤 무대 칸 — 카페 뒷벽 직원 줄(옥자31·멜33·미호35,5) 맨 오른쪽 끝(미호
# 옆, x37은 벽). 바나는 밤(빈 밤 슬롯 19시=Cafe.CLOSE_MIN)에만 드러나는 밤 무대 호스트라
# (미호 출퇴근·옥자 상주 station 패턴) 낮엔 숨고 밤에만 보인다. 카페 바닥이라 농사 대상이
# 아니고(밭과 안 겹침), 좌석(y=7)·문(33,10)·다른 직원 칸과도 칸이 갈린다. 밤 영업창
# 옵트인(T6.3)·막기(T6.4)는 범위 밖 — T6.1은 배치 + 대사 텍스트박스만(ADR-0006 그레이박스 최소).
const BANA_NIGHT_TILE := Vector2i(17, 88)   # 카페 직원 줄(y88, ★C3 +48) 오른쪽 끝(밤 무대)
# T6.3 잡귀가 깃드는 밤 스폿 칸 — 카페 안 앞줄(문 33,10 안쪽 y=9), 밤에 바를 열면 잡귀가
# 여기 기어든다. 카페 좌석(y=7)·직원 줄(y=5)과 칸이 갈리고(낮 카페와 시간도 갈림 — 카페
# 15–19시 마감 후 밤 19–24시), 카페 바닥이라 농사 대상이 아니다(밭과 안 겹침). 인덱스 =
# NightBar._spots 인덱스(스폿 0..2). 막기 E·이중 손실(T6.4)은 이 칸을 바라볼 때 얹힌다.
const NIGHT_SPOT_TILES := [Vector2i(11, 92), Vector2i(14, 92), Vector2i(17, 92)]   # 카페 잡귀 스폿 줄(y92, ★C3 +48, 좌석과 같은 x)
const JOBGUI := Color(0.26, 0.40, 0.30)  # 잡귀 그레이박스(탁한 청록 — 손님 CUST·NPC들과 구분)
# M2.3 네오(만물상 점주 — 바이블 오토마타, T1 비인간)가 서 있는 칸 — 만물상 방(STORE_RECT x23..32,y74..82) 안 뒷벽
# 가운데(매대 자리). 만물상 문(STORE_DOOR 27,82)으로 들어와 위로 올라오면 바로 네오를 마주본다.
# 멜과 같은 결 — 네오를 바라볼 때만 E=대화·F=매대 두 동사를 한 접점으로 연다(무인 매대 없음).
# 만물상 방은 카메라로 격리돼(STORE_CAM_RECT) 만물상에 들어왔을 때만 화면에 보인다. 만물상 방
# 바닥이라 농사·좌석과 안 겹친다(다른 구역·방에선 카메라 밖이라 안 보이고, 닿을 수도 없다).
const NEO_TILE := Vector2i(27, 76)   # 만물상 방 뒷벽 가운데(★C3 +48 = STORE_RECT y74+ 안)
# ★ Phase 2.7 C2 — 무인 출하함 칸(카페 안 뒷줄 오른쪽 끝, NPC 줄 y88에서 바나(17) 오른쪽 x19).
# 멜 F 게이트를 떼고(ADR-0021 출하대 무인화) 여기 *상자 오브젝트*를 세운다 — 플레이어가 아래 칸
# (19,89)에 서서 위를 바라보며(facing_bin) 우클릭으로 출하함 패널을 연다. 카페 바닥(CAFE)이라
# 농사 대상이 아니고(밭과 안 겹침), 좌석(y90)·NPC(x10/13/15/17)·문과도 칸이 갈린다.
const SHIP_BIN_TILE := Vector2i(19, 88)   # 카페 직원 줄(y88) 오른쪽 끝(무인 출하함 자리)

@onready var ground: TileMapLayer = $Ground
@onready var field_layer: TileMapLayer = $Field           # T2.1 밭 상태 오버레이
@onready var player: CharacterBody2D = $Player
# ★[asset-ruleset §6] Y-split 프론트 프롭 오버레이(플레이어 위 z 레이어)와 재분할 트리거.
#   플레이어가 타일 행을 넘을 때만 앞/뒤 프롭을 다시 나눠 그린다(매 프레임 아님 — 값싸게).
var _front_props: Node2D = null
var _last_player_tile_y: int = -9999
# ★[roster] 나무 occlusion fade — key=나무 앵커 타일(Vector2i), value=현재 알파(1.0=불투명). 매 프레임
#   플레이어 겹침을 판정해 target(TREE_FADE_MIN/1.0)으로 lerp, 변화가 있으면 _front_props를 다시 그린다.
var _tree_fade: Dictionary = {}
# ★ T3③' 실내 가구 충돌 — 구역 빌드마다 SOLID_PROPS 칸에 사각 충돌을 다시 세운다(러그 제외).
#   타일맵 벽과 같은 물리 레이어(기본 1)라 플레이어 move_and_slide가 통과 못 한다.
var _prop_body: StaticBody2D = null
# ★ 맵 경계 충돌체 — 옛 WALL 띠(시각)를 풀로 바꾸고(ADR-0026 룩 정합) 충돌만 외부 둘레에 둘러
#   맵 밖 이탈을 막는다(_build_border가 구역 빌드마다 다시 세운다).
var _border_body: StaticBody2D = null
var _ridge_body: StaticBody2D = null   # ★[단계3] 고지 동향 잔디 능선 통행 차단 충돌바(HOME 전용, _build_ridge_barrier)
# ★ [S1-5a] 트렐리스 넝쿨 충돌체 — 통과 불가(황천포도) 넝쿨이 심긴 칸에 사각 충돌을 세운다.
#   진실원 = farm.is_crop_solid/solid_crop_tiles(로직), 여긴 물리만(greybox-spec §6.2). 안식 농원 전용.
#   _prop_body 패턴과 동형(구역/상태 변화마다 재구성). 테스트·봇은 실내를 물리로 안 걷는다(직접 좌표).
var _trellis_body: StaticBody2D = null
# ★ [S1-5b] 혼의 나무 밑동 충돌체 — 3×3 과수의 밑동(앵커 1칸)만 SOLID로 세운다(수관 8칸 통과).
#   진실원 = orchard._trees(로직·자체 좌표계), 여긴 물리만(greybox-spec §7.4). 안식 농원 전용.
#   _trellis_body와 동형 패턴(orchard.changed·구역 빌드마다 재구성).
var _orchard_body: StaticBody2D = null
# ★ [S1-5b] 혼의 나무 과수 상태(심긴 나무·나이·결실). FarmField와 완전 분리된 자체 노드(코드 생성 —
#   에디터 프로퍼티가 없어 .tscn에 안 넣고 _trellis_body처럼 .new()로 붙인다). save.gd·main이 조율.
var orchard: Orchard = null
# ★ [S1-7] 혼의 짐승 목축 상태(배치 짐승·우정·기분·산물). FarmField/Orchard와 완전 분리된 자체 노드
#   (코드 생성 — .new()로 붙인다). 짐승은 비-SOLID(통과 가능)라 밑동 같은 충돌체가 없다(Orchard보다 단순).
#   하늘 목장(남단 고지) 전용. save.gd·main이 배치·돌봄·수집·세이브를 조율(디커플링).
var ranch: Ranch = null
# ★ [S1-8] overgrown 개간 상태(치운 debris 좌표 델타). FarmField/Orchard/Ranch와 완전 분리된 얇은 원장
#   노드(코드 생성 — .new()). debris 배치는 PROP_LAYOUT_HOME 시드에 잠겨 있고, 이 노드는 "무엇을 치웠나"
#   델타만 소유한다. main이 드로우/충돌 skip·farmable 판정에서 질의(디커플링 — Reclaim은 화면·지형 무지).
var reclaim: Reclaim = null
var _hinted_encroach := false        # ★ [ADR-0055] 첫 재점령 멘토 힌트를 한 번만 띄웠는지(세션 로컬 — 세이브 무관)
# ★ [B1-a.3] 사료풀 상태(낫으로 베어 건초를 얻는 고지 풀 — 재생·겨울정지). FarmField/Orchard/Ranch/
#   Reclaim와 완전 분리된 얇은 원장 노드(코드 생성 — .new()). main이 고지 자유 풀밭을 시드하고, 벤 결과를
#   여물광(Ranch.store_hay)에 적재한다(경제 양끝 잇기). 드로우는 main이 이 상태를 질의(디커플링).
var forage: Forage = null
# ★ ADR-0052 §118 채집 꽃 패치 상태(안식 피안화 손수확 → 채집물+채집 XP, 재생). Forage(사료풀)와 좌표·
#   도구가 갈린 별개 원장 노드(코드 생성 — .new()). main이 layout.json 꽃 패치 좌표를 시드하고, 딴 결과를
#   인벤토리·채집 XP에 잇는다(경제 양끝 잇기). 수확 등급은 채집 레벨/전문직이 소스(main이 주입, 디커플링).
var flower: FlowerPatch = null
# ★ [S1-9] 집 꾸미기 상태(집 내부 3레이어 코스메틱 배치 + 해금 세트). F10 저작 도구(layout.json·
#   _prop_layouts)와 완전 분리된 얇은 원장 노드(코드 생성 — .new()). 플레이어 세이브 델타만 소유하고
#   layout.json 시드는 안 건드린다(회귀 0). main이 유효 배치 칸을 주입하고 드로우/충돌 훅에서 질의(디커플링).
var home_deco: HomeDeco = null
@onready var readout: Label = $CanvasLayer/Readout
@onready var clock: GameClock = $Clock                     # T1.5 시계
@onready var clock_label: Label = $CanvasLayer/ClockLabel
@onready var sleep_prompt: Label = $CanvasLayer/SleepPrompt
@onready var interact_prompt: Label = $CanvasLayer/InteractPrompt  # T2.1 [E] 안내
@onready var farm: FarmField = $FarmField                  # T2.1 밭 칸 상태
@onready var crop_label: Label = $CanvasLayer/CropLabel    # ★ C3 핫바 든 아이템 요약(핫바 위, 하단 중앙)
@onready var energy: SoulEnergy = $SoulEnergy              # T2.4 혼력
@onready var saver: SaveManager = $SaveManager            # T2.5 세이브/로드
# ★멀티 슬롯(§3.4·§7-g) — 인게임 저장(취침·F5)·로드·삭제가 겨냥하는 활성 슬롯. 부팅 기본 0
#   (= 레거시 save.dat, 현행 동작 동일). 타이틀 [Load Game]/[새 게임]이 슬롯을 고르면 그 값을
#   여기 심어 이후 저장이 그 슬롯으로 간다(타이틀 배선 = 후속 증분).
var _active_slot := 0
@onready var wallet: Wallet = $Wallet                     # T3.1 골드
@onready var inventory: Inventory = $Inventory            # T3.1 수확물·씨앗 재고
@onready var gold_label: Label = $CanvasLayer/GoldLabel        # T3.1 골드 HUD
@onready var shop_panel: Panel = $CanvasLayer/ShopPanel    # T3.1 카페 출하대 패널 배경
@onready var shop_text: Label = $CanvasLayer/ShopPanel/Text    # T3.1 패널 본문
@onready var miho: Miho = $Miho                               # T3.2 미호 NPC(그레이박스)
@onready var dialogue: DialogueBox = $Dialogue                # T3.2 대사 진행기
@onready var dialogue_panel: Panel = $CanvasLayer/DialoguePanel  # T3.2 대화 텍스트박스 배경
@onready var dialogue_text: Label = $CanvasLayer/DialoguePanel/Text  # T3.2 대화 본문
@onready var dialogue_portrait: TextureRect = $CanvasLayer/DialoguePortrait  # P2.4 대화 초상화 슬롯
@onready var affinity: Affinity = $Affinity                   # T3.3 미호 호감도(하트)
@onready var okja: Okja = $Okja                               # T4.1 옥자 NPC(오프닝 통보)
@onready var mel: Mel = $Mel                                 # T5.1 멜 NPC(카페 운영·그레이박스)
@onready var bana: Bana = $Bana                             # T6.1 바나 NPC(밤 무대·그레이박스)
@onready var mel_affinity: Affinity = $MelAffinity           # T5.2 멜 호감도(하트, affinity.gd 재사용)
@onready var bana_affinity: Affinity = $BanaAffinity         # T6.2 바나 호감도(하트, affinity.gd 재사용)
@onready var neo: Neo = $Neo                                 # M2.3 네오 NPC(만물상 점주·그레이박스)
@onready var neo_affinity: Affinity = $NeoAffinity           # M2.3 네오 호감도(하트, affinity.gd 재사용 — 단골 할인 파생원)
@onready var cafe: Cafe = $Cafe                               # T5.4 카페 운영(손님 서빙·일일 정산)
@onready var night_bar: NightBar = $NightBar                 # T6.3 나라카 바(밤 옵트인·잡귀 등장 게이팅)
@onready var cafe_summary_panel: Panel = $CanvasLayer/CafeSummaryPanel  # T5.4 마감 정산 팝업 배경
@onready var cafe_summary_text: Label = $CanvasLayer/CafeSummaryPanel/Text  # T5.4 정산 본문
@onready var milestone_label: Label = $CanvasLayer/MilestoneLabel             # T7.2 카페 마일스톤 진행 바 HUD
@onready var milestone_panel: Panel = $CanvasLayer/MilestonePanel         # T7.2 "카페 2단계!" 달성 팝업 배경
@onready var milestone_text: Label = $CanvasLayer/MilestonePanel/Text         # T7.2 달성 팝업 본문
@onready var onboarding: Onboarding = $Onboarding             # T4.1 온보딩 단계 머신
@onready var onboarding_label: Label = $CanvasLayer/OnboardingLabel  # T4.1 안내 배너
@onready var ending_panel: ColorRect = $CanvasLayer/EndingPanel        # T4.2/T7.3 슬라이스 마무리 화면 배경
@onready var ending_text: Label = $CanvasLayer/EndingPanel/Text        # T4.2 점수판 본문
@onready var ending_restart: Button = $CanvasLayer/EndingPanel/Restart  # 마우스 클릭 "처음부터 다시 시작"(맥북 등 F8 없는 환경용 — F8 데브키와 같은 _delete_save_and_restart)
@onready var fade: ColorRect = $CanvasLayer/Fade

# P2.3③ 밤 라이팅(CanvasModulate + 등불). 월드 캔버스에 코드로 붙인다(타일셋·입력처럼
# 런타임 조립). 무상태(시각 파생)라 세이브 대상이 아니다 — _setup_lighting에서 생성.
var lighting: DayNightLighting

# P2.6 사운드(BGM 시간대 라우팅 + 이벤트 SFX + 음소거). lighting과 같은 결 — 코드 생성
# 자식 노드, 무상태(세이브 대상 아님). _setup_audio에서 생성, _process가 매 프레임 시각으로
# BGM을 잇고, 각 이벤트 자리에서 audio.sfx(...) 한 줄로 효과음을 쏜다.
var audio: GameAudio

# ★ ADR-0024 핫바 HUD(하단 12칸 슬롯 바). lighting·audio와 같은 결 — 코드 생성 자식, 무상태
# (인벤토리는 별도 세이브). _setup_hotbar에서 생성·주입하고, 인벤토리 changed로만 다시 그린다.
var hotbar: HotbarHud

# ★ Phase 2.7 C2 — 무인 출하함(대기 재고 + 익일 정산). wallet·inventory 결의 상태 노드지만 코드
# 생성으로 붙인다(lighting·hotbar 결 — 새 tscn 노드 추가 회피). 세이브는 별도 조각으로 main이 조율.
var ship_bin: ShippingBin

# ★ ADR-0048 Phase D — 저장 상자(집 실내 순수 보관 컨테이너, 경제 0). ship_bin과 같은 결의 상태 노드 —
# 코드 생성으로 붙이고(_setup_chest), 세이브는 별도 조각으로 main이 조율한다. 프레임 CTX_CHEST가 참조.
var chest: StorageChest
# ★ ADR-0048 Phase E — 갈무리방(창고) 저장 상자(ADR-0048 §4 "집/창고"). 집 상자와 독립된 두 번째 컨테이너.
# 두 상자는 같은 CTX_CHEST 패널을 공유하되, 여는 순간 _active_chest로 대상을 바꾼다(프레임은 활성 상자만 앎).
var storehouse_chest: StorageChest
var _active_chest: StorageChest   # 지금 열려 있는(마주 본) 상자 — 프레임 보관/회수 핸들러가 이걸 조작.

# ★ ADR-0048 Phase D — 게임 설정(볼륨·전체화면). audio·DisplayServer와 분리된 UX 환경설정(user://settings.cfg).
# 값은 이 노드가 들고, 실제 적용(버스 볼륨·창모드)은 main이 한다(데이터/적용 디커플링).
var settings: GameSettings

# ★ Phase 2.7 C2 — 공통 인벤토리 프레임(메뉴/출하함/매대 컨텍스트 스위칭 UI 셸). hotbar와 같은 결 —
# 코드 생성 자식 Control, 무상태(인벤토리·출하함이 상태). _setup_frame에서 생성·주입한다.
var frame: InventoryFrame

# ★ Phase 2.7 C3 — 미니멀 HUD 두 조각(hotbar와 같은 결 — 코드 생성 자식 Control, 무상태). 좌하단
# 알림 피드(일시 이벤트 큐)와 우하단 혼력 바(+체력 바 자리 예약). _setup_hud_overlays에서 생성·주입.
var notice_feed: NoticeFeed
var vitals: VitalsHud
var clock_hud: ClockHud             # ★ Phase C 우상단 시계 클러스터(절기·일차·시각·때·골드·마일스톤)
var context_popup: ContextPopup     # ★ Phase C 좌하단 컨텍스트 팝업(근처 NPC 초상화 + 한 줄)
var hud_tooltip: HudTooltip         # ★ Phase C 마우스 호버 툴팁(핫바 슬롯 아이템명)
var onboarding_banner: OnboardingBanner  # ★ owner 2026-07-03 상단-중앙 온보딩 안내 팝업 배너
# ★ 실내 카메라 격리 마스크(코지-와이드 회귀 수정) — 실내일 때 방 바깥을 검정으로 가린다.
# 월드보다 위·다른 HUD/패널보다 아래 레이어(맨 앞 자식)에 깔아 외부 풀밭·이웃 방을 덮되 HUD·대화는
# 그 위에 보이게 한다.
var indoor_mask: IndoorMask

var _grid: Array = []  # _grid[y][x] = 타일 id
# ★ 코지-와이드 C1 — 현재 구역 그리드 치수(RegionCatalog.size_of(_region) 파생). 전역 상수
# MAP_W/MAP_H/OUTDOOR_H 대신 빌드 경로(_build_*/_set_tile/_build_border/_is_farmable)가 이걸 읽어
# 구역마다 외부 크기를 달리할 수 있게 한다. _build_grid 최상단에서 매 재빌드마다 갱신(=_region과 항상 동기).
# 이번 패스(C1)는 8구역 전부 size=(40,24)라 값이 상수와 동일 = 회귀 0.
var _grid_w := MAP_W          # 현재 구역 외부 가로(타일)
var _outdoor_h := OUTDOOR_H   # 현재 구역 외부 세로(타일)
var _grid_h := MAP_H          # 그리드 전체 세로 = _outdoor_h + INDOOR_BAND_H
# M1.3 — 구역 라벨(밭·도착 등) 노드 추적. 구역 전환(_rebuild_region) 시 이전 구역 라벨을
# 걷어내고 새로 깔기 위해 _add_label이 여기 모은다(중복 누적 방지).
var _labels: Array[Node] = []
var _sleeping := false  # T1.5 취침 연출 중이면 이동·입력 잠금

# 외부↔실내 분리. _indoor = "" 바깥 / 건물 id(현재 어느 건물 안인가). 문 칸에 닿으면 fade로
# 전환하며, _transitioning은 그 fade 연출 중 입력·중복 트리거를 막는다(취침 연출과 같은 결).
# _cam은 코드 생성 추적 카메라 — 모드가 바뀔 때 경계만 바꿔 시야를 격리한다(_apply_camera_limits).
# ★ M2.2 — id는 "집"(홈 집)·"카페"·"만물상" + HOUSE_IDS 6채(메인/주민 집). 건물별 실내 데이터
#   (외관 문·진입/퇴장 칸·실내 문·카메라)는 _buildings 카탈로그가 들고, 출입·카메라·세이브 복원이
#   그 데이터로 굴러간다(하드코딩 match 제거 — 8개 건물이 한 데이터 흐름). _build_building_catalog가 채운다.
var _indoor := ""
var _buildings := {}
var _transitioning := false
var _cam: Camera2D

# M1.1 — 현재 구역(8구역 세계, ADR-0015). M1.2가 _build/_paint·카메라를 이 값 기준으로
# 일반화했고, M1.3 가장자리/길 워프(_maybe_warp_edge → _warp → _rebuild_region)가 이 값을
# 바꾼다. 지금은 이웃(나루 마을)이 stub이라 모든 가장자리 워프가 휴면 상태라 실제로는
# 홈베이스 고정이다(회귀 0). M1.4가 나루 마을을 지으면 그 워프가 자동으로 산다.
var _region := RegionCatalog.HOME

# T5.6 미호가 지금 서 있는 칸(출퇴근으로 시간대마다 바뀐다 — 아침=밭, 15시부터=카페).
# 말 걸기 판정(facing_miho)·농사 제외가 이 값을 따라간다. 시간에서 매 프레임 파생되는
# 일시 상태라 세이브하지 않는다(다음 부팅 때 그 시각으로 다시 결정된다).
var _miho_tile := MIHO_FIELD_TILE

var _target := Vector2i(-1, -1)  # T2.1 바라보는 앞 칸(상호작용 대상)
var _target_valid := false       # 그 칸이 밭(SOIL)이라 상호작용 가능한가

# T2.3 현재 심을 작물. Q로 카탈로그(빠른 성장 순)를 순환 선택한다.
# 그레이박스에선 도구·씨앗 인벤토리 UI 없이 이 한 변수로 작물 종류를 고른다.
var _selected_crop: String = CropCatalog.HONRYEONGCHO

# ★ C3 — 알림 피드(좌하단 큐, notice_feed)가 표시 타이머를 스스로 들므로 _notice_secs는 폐기됐다.
const NOTICE_SECS := 2.0          # 기본 알림 표시 시간(저장됨 등 짧은 확인 문구)
const FLAVOR_SECS := 3.5          # T3.5 사연 한 줄은 읽을 시간을 더 길게 준다

# 세이브 삭제+새 시작(F8)은 되돌릴 수 없어 2단 확인을 받는다 — 첫 F8이 이 시간(초)만큼
# '무장' 상태를 켜고, 그 안에 한 번 더 F8을 누르면 실제로 삭제·재시작한다. 0이면 비무장.
var _delete_armed_secs := 0.0
const DELETE_CONFIRM_SECS := 3.0  # 2단 확인 대기 시간(이 안에 다시 F8이면 실행)

# T3.5 작물(영혼)별 수확 누적 횟수. 수확마다 +1 해 SoulMemory.line의 index로 넘겨
# 사연이 순환되게 한다(같은 작물을 거둘 때마다 다음 사연으로). 일시적 표시용 진척이라
# 세이브하지 않는다(대화와 같은 결 — SaveManager·main 세이브 불변).
var _harvest_seen: Dictionary = {}

# ★ Phase 2.7 C2 — 멜 출하대(_shop_open)·만물상 매대(_store_open) 토글 플래그는 폐기됐다.
# 판매는 무인 출하함(ship_bin, 드롭→익일 정산)으로, 구매·메뉴·매대는 공통 프레임(frame)으로
# 옮겨갔다. "패널이 열려 있는가"는 frame.is_open()/frame.context가 단일 출처다(별도 플래그 제거).

# T4.2 슬라이스(RunSummary.RUN_DAYS일)가 끝났는가(마무리 화면 표시 중). true면 _process가 모든
# 게임 입력을 막고 마무리 화면만 유지한다. 끝남 자체는 GameClock.day에서 파생되므로
# (RunSummary.is_over) 세이브할 상태가 아니고, 이 플래그는 한 프레임 표시 래치일 뿐이다.
var _run_over := false
# T4.1 — 직전 프레임의 온보딩 안내 문구. 단계가 바뀔 때(이 값과 달라질 때)만 알림을 한 번 띄운다
# (상시 중앙 배너 폐기 — 피드백 2026-06-25). 일시 표시라 세이브하지 않는다.
var _last_onboarding_guide := ""
# T4.2 이번 슬라이스에서 거둔 영혼(수확) 총수 — 마무리 점수판용. 일시 표시용인
# _harvest_seen(사연 순환 index)과 달리 점수판이 재개에도 맞아야 하므로 저장한다.
var _run_harvested := 0

# ★ S1-6(§8.9) 농사 숙련 XP(main 스칼라, 별도 노드 없음 — Q4). 수확 성공마다 작물 base 판매가가
# 쌓이고, FarmSkill이 이 값을 레벨·혼력 감산 계수로 옮긴다(순수 함수 파생). 누적 진행이라 저장한다
# (_run_harvested 점수판과 같은 결 — main 세이브에 한 조각, SaveManager 불변).
var _farming_xp := 0

# ★ ADR-0052 그레이박스 — 채집 스킬 XP(농사와 대칭·main 스칼라). XP 곡선은 FarmSkill을 *공유*한다
# (XP_THRESHOLDS/level_for_xp는 스킬-불특정 순수 곡선 — ADR-0052는 5스킬 공통 기반). 라이브 채집
# 루프(숲·야생씨앗)가 아직 없어 지금은 XP 소스 미배선(프레임워크 우선) — 헬퍼·상태·조회만 잠근다.
var _foraging_xp := 0
# ★ ADR-0052 전문직 선택 상태 — {skill_id: {tier(5/10): prof_id}}. 빈 = 미선택("평평≠막힘", L0도
# 활동 100% 가동, 전문직은 곱셈 편의). ProfessionCatalog가 규칙(무상태), 이 dict가 세이브 상태
# (_farming_xp↔FarmSkill 관계와 동일). main이 세이브 dict에 한 조각으로 끼운다(SaveManager 불변).
var _professions := {}

# T5.1 직전(현재) 대화 상대의 표시 이름 — 대화 종료 시 온보딩 전진을 '누구와의
# 대화였나'로 가르는 데 쓴다. 멜이 카페에 상주하면서 온보딩 도중(미호 멘토 단계)에도
# 말 걸 수 있게 됐기 때문 — 화자 구분 없이 단계로만 가르면 멜 대화가 미호 단계를
# 잘못 전진시킨다. 일시 상태라 세이브하지 않는다(대화와 같은 결).
var _talking_to := ""

# T5.4 카페 마감 정산 팝업을 띄워 두는 잔여 시간(초). 0이 되면 팝업을 숨긴다. 손님과
# 같은 결로 일시 표시용이라 세이브하지 않는다(cafe.gd 세이브 무상태와 일관).
var _cafe_summary_secs := 0.0
const CAFE_SUMMARY_SECS := 5.0  # 마감 정산 팝업 표시 시간(읽을 시간을 넉넉히)

# T7.2 카페 마일스톤 1단의 "누적 서빙 매출"(카페 손님 서빙 + 밤 바 응대). 출하대 raw 판매는
# 빼고 *카페를 운영한* 매출만 센다(ADR-0009 — 마일스톤은 카페를 굴리는 쪽으로 당긴다). 매크로
# 목표의 누적 진행이라 슬라이스를 넘어 보존돼야 하므로 저장한다(_run_harvested 점수판과 같은 결 —
# 멜·바나 affinity처럼 main 세이브에 한 조각 추가, SaveManager 불변). 거둔 영혼은 _run_harvested,
# 세 호감도는 affinity 노드들에서 파생되므로 마일스톤이 새로 저장하는 건 이 한 조각뿐이다.
var _cafe_revenue_total := 0
# T7.2 1단 달성("카페 2단계!") 팝업을 이미 띄웠는가(한 번만 뜨게 하는 래치). 달성 여부 자체는
# 누적값에서 파생되므로(CafeMilestone.is_complete — 세이브 무상태) 저장하지 않는다. 이 래치는
# 일시 표시용으로, _ready에서 "이미 완료된 세이브를 이어받았으면 true"로 초기화해 재개 시
# 팝업이 다시 터지지 않게 한다(완료 상태는 HUD가 상시 보여 줌 — RunSummary.is_over와 같은 결).
var _milestone_celebrated := false
# T7.2 달성 팝업 표시 잔여 시간(초). 카페 마감 정산 팝업과 같은 결(비차단 자동 해제).
var _milestone_popup_secs := 0.0
const MILESTONE_POPUP_SECS := 6.0  # 달성 팝업 표시 시간(2단 미리보기를 읽을 시간을 넉넉히)

func _ready() -> void:
	_ensure_input_actions()
	# ★ 최소 창 크기 = 내부 뷰포트(960×540)로 제한. stretch=viewport라 이 이하로 줄이면 1배 미만
	# 축소로 고정 좌표 UI(메뉴 패널·탭·글자)가 슬롯/탭 경계 밖으로 삐져나온다(owner 관찰). 픽셀아트
	# 표준대로 반응형 재계산 대신 하한을 막는다(그 위로는 자유 리사이즈·정수배 아니어도 stretch가 처리).
	get_window().min_size = Vector2i(960, 540)
	_build_building_catalog()   # ★ M2.2 건물 출입·카메라·세이브 복원이 참조 → 카메라·로드보다 먼저
	ground.tile_set = _build_tileset()
	field_layer.tile_set = _build_field_tileset()
	# 지형·밭 타일맵을 캐릭터·가구보다 한 단계 뒤(z -1)로 내린다. main의 _draw로 그리는
	# 가구(_draw_props)·손님·밭 커서는 *부모* 그리기라, 기본 트리순서상 자식인 타일맵
	# *아래*에 깔려 바닥 타일에 가려진다(Godot: 자식이 부모 _draw 위에 그려짐). 타일맵 z만
	# 내리면 _draw 오버레이가 바닥 위·캐릭터(자식 노드 z0) 아래로 올바르게 낀다.
	ground.z_index = -1
	field_layer.z_index = -1
	farm.tile_changed.connect(_on_tile_changed)
	ending_restart.pressed.connect(_delete_save_and_restart)   # 엔딩 화면 "처음부터 다시 시작" 버튼
	_prop_body = StaticBody2D.new()   # ★ T3③' 가구 충돌체(_build_grid가 칸을 다시 채운다)
	add_child(_prop_body)
	_trellis_body = StaticBody2D.new()   # ★ [S1-5a] 트렐리스 넝쿨 충돌체(tile_changed·구역빌드가 재구성)
	add_child(_trellis_body)
	_orchard_body = StaticBody2D.new()   # ★ [S1-5b] 혼의 나무 밑동 충돌체(orchard.changed·구역빌드가 재구성)
	add_child(_orchard_body)
	orchard = Orchard.new()              # ★ [S1-5b] 과수 상태 노드(코드 생성 — 자체 좌표계, FarmField와 분리)
	orchard.name = "Orchard"
	add_child(orchard)
	orchard.changed.connect(_on_orchard_changed)   # 심기·결실·수확·복원 시 밑동 충돌·화면 갱신
	ranch = Ranch.new()                  # ★ [S1-7] 목축 상태 노드(코드 생성 — 자체 좌표계, 짐승은 비-SOLID라 충돌체 없음)
	ranch.name = "Ranch"
	add_child(ranch)
	ranch.changed.connect(_on_ranch_changed)       # 배치·돌봄·산물·수집·복원 시 화면·HUD 갱신
	reclaim = Reclaim.new()              # ★ [S1-8] 개간 상태 노드(코드 생성 — 치운 debris 좌표 델타 원장)
	reclaim.name = "Reclaim"
	add_child(reclaim)
	reclaim.changed.connect(_on_reclaim_changed)   # 개간·복원 시 드로우/충돌 skip 반영
	forage = Forage.new()                # ★ [B1-a.3] 사료풀 상태 노드(코드 생성 — 낫 채집·재생 원장, 여물광 건초 소스)
	forage.name = "Forage"
	add_child(forage)
	forage.changed.connect(_on_ranch_changed)      # 베기·재생·복원 시 드로우 갱신(짐승과 같은 훅 재사용 — 둘 다 고지 그레이박스)
	flower = FlowerPatch.new()           # ★ ADR-0052 꽃 패치 채집 상태 노드(코드 생성 — 손수확·재생 원장, 채집물+XP 소스)
	flower.name = "FlowerPatch"
	add_child(flower)
	flower.changed.connect(_on_ranch_changed)      # 따기·재생·복원 시 드로우 갱신(사료풀과 같은 훅 재사용 — 둘 다 야외 그레이박스)
	home_deco = HomeDeco.new()           # ★ [S1-9] 집 꾸미기 상태 노드(코드 생성 — 3레이어 배치 + 해금 델타)
	home_deco.name = "HomeDeco"
	add_child(home_deco)
	home_deco.changed.connect(_on_home_deco_changed)   # 배치·삭제·회전·해금·복원 시 드로우/충돌 훅 갱신
	_configure_home_deco_bounds()   # ★ [S1-9] 유효 배치 칸 주입(집 룸 rect 파생 — 좌표 정적이라 1회)
	_ensure_prop_layouts()   # ★ ADR-0025 ② PROP 좌표 데이터 외부화 로드(_build_grid 충돌 재구성 전)
	_build_grid()
	_paint_grid()
	_place_labels()
	_setup_player_and_camera()
	# ★[asset-ruleset §6] 플레이어(z0)보다 높은 z의 프론트 프롭 오버레이 — "플레이어보다 앞(발치 아래)"
	#   프롭을 여기서 다시 그려 캐릭터가 나무·바위 뒤로 가려지게 한다(그리기 로직은 main이 단일 출처).
	_front_props = preload("res://front_props.gd").new()
	_front_props.host = self
	_front_props.z_index = 1
	add_child(_front_props)
	_setup_lighting()
	_setup_audio()
	_setup_hotbar()
	_setup_shipping_bin()   # ★ C2 무인 출하함(프레임이 참조 → 프레임보다 먼저)
	_setup_chest()          # ★ Phase D 저장 상자(프레임이 참조 → 프레임보다 먼저)
	_setup_hud_overlays()   # ★ C3 좌하단 알림 피드 + 우하단 혼력 바(프레임보다 먼저 → 모달이 위에)
	_setup_frame()          # ★ C2 공통 인벤토리 프레임(메뉴/출하함/매대/상자)
	_setup_settings()       # ★ Phase D 설정(볼륨·전체화면 — audio·프레임 존재 후, 프레임 신호 연결·적용)
	_skin_panel_text()      # ★ Phase B 한지 테마(밝은 배경) 위 라벨을 먹빛으로(대비 확보)
	_setup_clock()
	# T3.2/T5.6 미호를 현재 시간대의 자리(아침=밭 / 15시부터=카페)에 세우고, 대사 진행
	# 시그널을 패널·이동잠금에 연결한다. 초기 위치는 _miho_tile(기본 밭)로 두고, 로드 후
	# 시각이 영업창이면 _update_miho_station이 카페로 옮긴다.
	miho.position = _tile_center_px(_miho_tile)
	# T4.1 옥자를 통보 자리에 세우되 평소엔 숨긴다(오프닝 통보 때만 등장). 통보를 마치면
	# T5.6 _refresh_okja_station이 카페 상주 자리로 옮겨 다시 드러낸다.
	okja.position = _tile_center_px(OKJA_INTRO_TILE)
	okja.visible = false
	# T5.1 멜을 카페 안 카운터 칸 중앙에 세운다(미호처럼 상시 상주, 항상 보임).
	mel.position = _tile_center_px(MEL_TILE)
	# T6.1 바나를 밤 무대 칸에 세우되 평소엔 숨긴다(밤에만 등장 — 미호 출퇴근·옥자 상주처럼
	# 시각에서 파생되는 무상태 배치). 위치는 고정이고 가시성만 _update_bana_station이 토글한다.
	bana.position = _tile_center_px(BANA_NIGHT_TILE)
	bana.visible = false
	# M2.3 네오를 만물상 방 안 매대 칸에 세운다(멜처럼 상시 상주). 만물상 방은 카메라로 격리돼
	# (STORE_CAM_RECT) 만물상에 들어왔을 때만 보이므로, 멜과 같이 visible 토글 없이 위치만 고정한다
	# (다른 구역·방에선 카메라 밖 → 안 보이고, NEO_TILE에 닿을 수도 없다).
	neo.position = _tile_center_px(NEO_TILE)
	# T5.2 멜 선호 선물은 피안화(미호=영혼 호박과 선물 경제 분산). affinity.gd 인스턴스
	# 하나를 멜용으로 재사용하되, 이 한 값만 멜로 바꾼다(곡선 상수는 미호와 공유).
	mel_affinity.preferred_crop = CropCatalog.PIANHWA
	# T6.2 바나 선호 선물은 혼령초(미호=영혼 호박·멜=피안화와 분리 — 세 작물에 선물 경제를
	# 고르게 분산. 남은 세 번째 작물이라 자연 확정). 같은 affinity.gd 인스턴스를 바나용으로
	# 재사용하되 이 한 값만 바꾼다(하트 곡선 상수는 미호·멜과 공유 — miho-heart-arc).
	bana_affinity.preferred_crop = CropCatalog.HONRYEONGCHO
	dialogue.changed.connect(_on_dialogue_changed)
	dialogue.finished.connect(_on_dialogue_finished)
	_build_dialogue_ui()   # S0-6 「태운 한지」 대화창 룩(윈도우 아트 + 오버레이)
	# T5.4 카페 영업 마감(19시) → 일일 정산 팝업. 손님 상태 변화는 매 프레임 _draw에서
	# 그리므로 changed는 따로 듣지 않는다(영업 중엔 _process가 queue_redraw로 바를 갱신).
	cafe.closed.connect(_on_cafe_closed)
	# T6.3 밤 바 마감(취침 = 밤의 자연스러운 끝, end_day가 쏨) → 밤 정산 요약. 잡귀·손님 상태
	# 변화는 카페 손님처럼 매 프레임 _draw에서 그리므로 changed는 따로 듣지 않는다(밤이면
	# _process가 queue_redraw로 접근·인내심 바를 갱신).
	night_bar.closed.connect(_on_night_closed)
	# T6.4 막기 해소 계약(★ {repelled, raided}) → 이중 손실 ㉮ 적용. 잡귀가 돌파하면(막기 실패)
	# resolved가 약탈량을 싣고 오고, main이 그만큼 낮에 쌓은 수확물을 덜어낸다(미래 자산 — 내일
	# 카페가 굶음). night_bar는 재고를 모른 채 계약만 쏘고, '어떻게 격퇴했는지'도 모른다(디커플링,
	# field.gd가 Foxfire 모르는 패턴 — Phase 3 전투가 구현만 교체해도 이 핸들러는 그대로).
	night_bar.resolved.connect(_on_night_resolved)
	# ★타이틀(§3.4) — 실제 실행에서만 타이틀을 띄우고 게임 시작(로드/신규)을 선택까지 미룬다.
	#   테스트는 main을 수동 add_child라 current_scene≠self → 종전대로 즉시 부팅(타이틀 없음·무영향).
	if get_tree().current_scene == self:
		_show_title()
	else:
		_begin_game(false)

# ── ★타이틀 배선 — 게임 시작 finalize(부팅/타이틀 공용). 세이브 로드(이어하기) 또는 신규
#   셋업 후 시드·직원배치·축제·마일스톤·인트로까지 잇는다(구 _ready 부팅 tail을 함수로 승격).
#   is_new_game=true면 세이브가 있어도 신규 셋업(타이틀 [새 게임]/빈 슬롯). ──
func _begin_game(is_new_game: bool) -> void:
	# T2.5 세이브가 있으면(이어하기) 복원, 아니면(신규) 스타터 셋업 → "껐다 켜도 그대로".
	if not is_new_game and saver.has_save(_active_slot):
		_load_game()
	else:
		# ★ [S1-7] 신규 게임: 하늘 목장에 스타터 짐승을 배치한다(START_KIT 결 — 세이브가 없을 때만,
		# _grid는 부팅 HOME 그대로라 방목지 좌표계가 유효). 세이브에 짐승이 있으면 load_save가 복원한다.
		_ensure_starter_animals()
		# ★ [S1-9] 신규 게임: 스타터 테마 세트를 무상 해금한다(§11.4 — 상점=Slice2 하류, 지금은 START).
		#   세이브가 있으면 home_deco.load_save가 해금 집합을 복원한다(구세이브=해금 0, 방어적).
		for sid in HomeDecoCatalog.STARTER_SETS:
			home_deco.unlock(sid)
	# ★ [B1-a.3] 사료풀 시드 — 고지 자유 풀밭(FORAGE_SCAN_RECT 비-SOLID)을 Forage에 등록한다. 신규·복원
	#   양쪽에서 부른다: seed는 멱등이라 복원된 사료풀 상태(cut_day)를 보존하고 맵상 새 타일만 더한다.
	_seed_forage_tiles()
	# ★ ADR-0052 꽃 패치 시드 — layout.json HOME의 FLOWER_PATCH 좌표를 FlowerPatch에 등록한다(신규·복원
	#   양쪽). seed는 멱등이라 복원된 딴 상태(picked_day)를 보존하고 배치상 새 타일만 더한다(_seed_forage_tiles 결).
	_seed_flower_patches()
	# T5.6 복원 직후 NPC 상주/출근 상태를 현재(복원된) 진행·시각에 맞춘다. 통보를 이미
	# 마친 세이브면 옥자가 카페에 보이고, 복원 시각이 영업창(15시+)이면 미호가 카페로 출근해
	# 있다("껐다 켜도 그대로" — 직원 배치까지 재개에 맞는다). 둘 다 세이브 무상태(시각·단계
	# 에서 파생)라 SaveManager는 불변이다(메모대로 세이브 통합은 멜 affinity 한 조각뿐).
	_refresh_okja_station()
	_update_miho_station()
	# T6.1 복원 시각이 밤(19시+)이면 바나가 밤 무대에 이미 서 있도록 가시성을 맞춘다
	# (옥자·미호와 같은 결 — 껐다 켜도 그대로). 통보 단계면 가드에 걸려 아직 안 보인다.
	_update_bana_station()
	# M2.4 복원/신규 직후 오늘이 이벤트 데이면 의상·카페 보너스를 맞춘다(껐다 켜도 그대로 —
	# 14일째에 저장했다 재개하면 그 축제 차림으로 재개된다). 세이브 무상태라 day에서 파생.
	_refresh_festival()
	# T7.2 이어받은 세이브가 이미 카페 1단을 채웠으면 달성 래치를 켜 둔다 — 재개 때 "카페 2단계!"
	# 팝업이 다시 터지지 않게(완료 상태는 마일스톤 HUD가 상시 보여 준다). 신규/미완료면 false로,
	# 플레이 중 채우는 순간 _process가 한 번 팝업을 띄운다(RunSummary.is_over 재개 안전과 같은 결).
	_milestone_celebrated = _milestone_complete()
	# T4.2 이어받은 세이브가 이미 슬라이스를 넘겼으면(RUN_DAYS+1일째 아침) 바로 마무리 화면을 띄운다.
	# 그 경우 온보딩 컷신은 띄우지 않는다(슬라이스가 끝났으므로).
	if RunSummary.is_over(clock.day):
		_end_run()
	else:
		# T4.1 신규 시작(또는 통보 단계 복원)이면 옥자 오프닝 통보를 자동으로 띄운다.
		_maybe_start_intro()
	# ★ ADR-0025 ① 배치 모드 패널(좌상단, 디버그/에디터 전용). 맥 F키·단축키 없이 마우스로 조작.
	# is_debug_build = 에디터·디버그 실행 true·릴리스 export만 false(run_game.sh=에디터 바이너리라 true).
	if OS.is_debug_build():
		_make_edit_ui()
	# 온보딩 안내는 상시 배너 대신 단계 전환 시 좌하단 알림으로 띄운다(_process의 guidance 비교 블록).
	# 배너 노드는 끈 채 유지(참조·회귀 안전).
	onboarding_label.visible = false

# ★타이틀 화면을 띄우고 게임 시작을 선택까지 미룬다(실제 실행 전용). 월드는 이미 _ready에서
#   빌드됐고(HOME 스폰), 타이틀이 그 위를 덮으며 트리를 일시정지(월드 시뮬 정지·입력 격리)한다.
func _show_title() -> void:
	get_tree().paused = true
	# ★ B2 타이틀 BGM(로파이 코지) — 트리가 멈춰도 audio는 ALWAYS라 곡이 깔린다. 게임 시작 시
	#   _process의 update_music이 farm/cafe/night/ending으로 크로스페이드해 넘어간다(phase 전환).
	if audio != null:
		audio.set_phase(GameAudio.PHASE_TITLE)
	var title := TitleScreen.new()
	title.name = "TitleScreen"
	add_child(title)
	title.setup(saver, settings)   # ★ B2 설정 값 원천 주입(_setup_settings가 먼저 생성 — 부팅 순서 보장)
	title.start_game.connect(_on_title_start)
	title.quit_game.connect(_on_title_quit)
	# ★ B2 타이틀 설정 조작 → 옵션 탭과 *같은* 핸들러로 실제 적용·영속(단일 값 원천 GameSettings 공유).
	title.music_nudged.connect(_on_music_vol_changed)
	title.sfx_nudged.connect(_on_sfx_vol_changed)
	title.fullscreen_nudged.connect(_on_fullscreen_toggled)

# 타이틀에서 슬롯을 골라 시작 — 활성 슬롯을 심고(이후 저장이 그 슬롯으로), 신규면 그 슬롯을
#   비운 뒤 게임 시작 finalize를 돌린다. 일시정지 해제·타이틀 제거.
func _on_title_start(slot: int, is_new: bool) -> void:
	_active_slot = slot
	if is_new:
		saver.delete_save(slot)
	var t := get_node_or_null("TitleScreen")
	if t != null:
		t.queue_free()
	get_tree().paused = false
	_begin_game(is_new)

# 타이틀 [종료].
func _on_title_quit() -> void:
	get_tree().quit()

# 입력 액션을 코드로 등록한다. project.godot 수동 편집 대신 런타임 조립 — 이 프로젝트의
# TileSet·벽 생성과 같은 결이고, 직렬화 포맷 깨질 위험이 없다.
# ★ ADR-0024(마우스 커서 조작 피벗) — 예전 단일 키 E(interact)·Q(cycle_crop)를 폐기하고,
#   LMB(use_tool)=든 도구 사용 · RMB(action)=맨손 액션/대화 2채널 + 핫바(숫자키·휠) 선택으로 간다.
func _ensure_input_actions() -> void:
	if InputMap.has_action("use_tool"):
		return
	# LMB = 손에 든 도구 사용(괭이질·물주기·씨앗 심기). 커서 밑 인접 1칸에 작용.
	InputMap.add_action("use_tool")
	var ev_lmb := InputEventMouseButton.new()
	ev_lmb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("use_tool", ev_lmb)
	# RMB = 액션/대화(맨손 수확·NPC 대화·서빙·밤 막기·취침·대사 넘기기). 컨텍스트 단일 버튼.
	InputMap.add_action("action")
	var ev_rmb := InputEventMouseButton.new()
	ev_rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("action", ev_rmb)
	# 핫바 선택: 숫자키 1~9·0·-·= → 슬롯 0..11. 12칸을 한 줄로 직접 고른다(스타듀 동일).
	var hotbar_keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]
	for i in hotbar_keys.size():
		var act_name := "hotbar_%d" % i
		InputMap.add_action(act_name)
		var ev_h := InputEventKey.new()
		ev_h.physical_keycode = hotbar_keys[i]
		InputMap.action_add_event(act_name, ev_h)
	# 핫바 휠 선택(다음/이전 슬롯 순환). 마우스 휠 업=이전, 다운=다음(스타듀 동일).
	InputMap.add_action("hotbar_next")
	var ev_wd := InputEventMouseButton.new()
	ev_wd.button_index = MOUSE_BUTTON_WHEEL_DOWN
	InputMap.action_add_event("hotbar_next", ev_wd)
	InputMap.add_action("hotbar_prev")
	var ev_wu := InputEventMouseButton.new()
	ev_wu.button_index = MOUSE_BUTTON_WHEEL_UP
	InputMap.action_add_event("hotbar_prev", ev_wu)
	# T2.5 수동 저장(F5)·불러오기(F9). 자동 저장(취침)과 별개로 검증·편의용.
	InputMap.add_action("save_game")
	var ev_f5 := InputEventKey.new()
	ev_f5.physical_keycode = KEY_F5
	InputMap.action_add_event("save_game", ev_f5)
	InputMap.add_action("load_game")
	var ev_f9 := InputEventKey.new()
	ev_f9.physical_keycode = KEY_F9
	InputMap.action_add_event("load_game", ev_f9)
	# 세이브 삭제 후 새로 시작(F8). 저장(F5)·불러오기(F9) 옆 데브 키로 묶되, 게임플레이
	# 키(E·Q·S·B·F·G)와 멀어 실수 위험이 낮다. 되돌릴 수 없어 2단 확인을 받는다(_process).
	InputMap.add_action("delete_save")
	var ev_f8 := InputEventKey.new()
	ev_f8.physical_keycode = KEY_F8
	InputMap.action_add_event("delete_save", ev_f8)
	# ★ C2 — 멜 출하대 즉시판매(S)·구매(B)는 폐기됐다(무인 출하함 드롭=마우스 클릭, 구매=네오 매대
	# 클릭). shop_sell/shop_buy 액션 제거 — 판매·구매는 프레임 클릭으로만 이뤄진다(키 충돌면 정리).
	# 만물상 매대·나라카 바 열기(F). 네오/바나를 바라볼 때만 처리하므로 대화(우클릭)·밭 작업과 갈린다.
	InputMap.add_action("shop_toggle")
	var ev_f := InputEventKey.new()
	ev_f.physical_keycode = KEY_F
	InputMap.action_add_event("shop_toggle", ev_f)
	# ★ C2 메뉴 열기/닫기(Tab) — 어디서든 토글. 인벤토리·관계 탭 셸을 띄운다(모달, 이동 잠금).
	InputMap.add_action("menu_toggle")
	var ev_tab := InputEventKey.new()
	ev_tab.physical_keycode = KEY_TAB
	InputMap.action_add_event("menu_toggle", ev_tab)
	# ★ C2 메뉴 탭 순환(E) — 메뉴가 열렸을 때만 인벤토리 ↔ 관계를 오간다(마우스 클릭과 병행).
	InputMap.add_action("menu_tab")
	var ev_e := InputEventKey.new()
	ev_e.physical_keycode = KEY_E
	InputMap.action_add_event("menu_tab", ev_e)
	# T3.3 미호에게 선물(G). 미호를 바라볼 때만 처리하므로 밭 작업 키와 충돌하지 않는다.
	InputMap.add_action("gift_item")
	var ev_g := InputEventKey.new()
	ev_g.physical_keycode = KEY_G
	InputMap.action_add_event("gift_item", ev_g)
	# P2.6 오디오 음소거 토글(M). 게임플레이 키(E·Q·S·B·F·G)와 멀고, 어디서든 받는 UX 토글.
	InputMap.add_action("mute_audio")
	var ev_m := InputEventKey.new()
	ev_m.physical_keycode = KEY_M
	InputMap.action_add_event("mute_audio", ev_m)
	# 전체화면 토글(F11). 창↔전체화면을 어디서든 받는다(음소거와 같은 결 — 게임 상태 무관 UX 토글).
	InputMap.add_action("toggle_fullscreen")
	var ev_f11 := InputEventKey.new()
	ev_f11.physical_keycode = KEY_F11
	InputMap.action_add_event("toggle_fullscreen", ev_f11)
	# ★ ADR-0025 ① 인게임 배치 모드 토글(F10, 디버그/에디터 전용). F9=load_game이라 비어있는 F10로.
	# 배치 모드 ON이면 게임 시뮬·입력을 멈추고(저작 전용) 마우스로 장식을 옮긴다(아래 _process_edit).
	InputMap.add_action("place_mode")
	var ev_f10 := InputEventKey.new()
	ev_f10.physical_keycode = KEY_F10
	InputMap.action_add_event("place_mode", ev_f10)
	# ★ [S1-9] 집 꾸미기 모드 토글(C — 플레이어-facing, 맥 F키 이슈 회피). 집 실내에서만 발동(_can_deco).
	InputMap.add_action("deco_mode")
	var ev_c := InputEventKey.new()
	ev_c.physical_keycode = KEY_C
	InputMap.action_add_event("deco_mode", ev_c)

# 창 ↔ 전체화면 토글(F11). 픽셀은 nearest+fractional 스케일이라 전체화면에서도 화면을 꽉 채우되
# 또렷하다(ADR-0018 갱신 — 스타듀식 채움). 창 복귀 시 1920×1080 override로 돌아간다.
func _toggle_fullscreen() -> void:
	var now_full := get_window().mode != Window.MODE_WINDOWED
	_apply_fullscreen(not now_full)
	# ★ Phase D — 설정 값·영속을 F11에서도 맞춘다(옵션 탭 체크박스와 단일 값 원천). 부팅 극초기(settings
	#   생성 전 F11)엔 아직 없을 수 있어 null 가드.
	if settings != null and settings.set_fullscreen(not now_full):
		settings.save_settings()

# ── TileSet 조립: terrain 도트(source 0) + 실내/벽 단색(source 1) + WALL 충돌 ──
func _build_tileset() -> TileSet:
	# 1) PixelLab Wang 3세트를 합친 corner 오토타일 TileSet을 로드한다(source 0 =
	#    풀/길/밭 terrain). 런타임에 단색 source와 물리 레이어를 얹으므로 공유 캐시를
	#    건드리지 않게 복제본을 쓴다.
	var ts: TileSet = (load(TERRAIN_TILESET_PATH) as TileSet).duplicate(true)
	# 컨버터 .tres는 mode=CORNERS_AND_SIDES로 나오지만 Wang 타일은 코너만 설정하므로
	# MATCH_CORNERS로 강제한다(side peering 미설정 → 매칭 깨짐 방지).
	if ts.get_terrain_sets_count() > 0:
		ts.set_terrain_set_mode(TERRAIN_SET, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	# ★ [ADR-0042] 증분3 — 농원 지형 타일셋을 lush full-grass + pro raggedness 유기적 경계로 *재생성*
	#   (mode=pro·medium detail). 세 grass 세트의 톤 불일치(특히 water_grass)는 2단계로 잡는다:
	#   ① 소스(recolor_terrain_warm.py): 이미지 전체 풀 평균을 평준화 → *경계 타일*(연못 둘레 등) 정합.
	#   ② 런타임(_harmonize_grass_variants): base all-grass 3변종의 평균을 공통 톤으로 정밀 정합 →
	#      *필드 체커* 제거. 둘 다 평행이동만(평탄화 X)이라 lush 풀결은 그대로 보존된다.
	_harmonize_grass_variants(ts)
	# ★ [ADR-0043] 타일 배치 규칙(owner: "규칙 있을 곳엔 규칙, 없어도 되는 곳엔 임의").
	_apply_placement_rules(ts)

	# 2) HOUSE/CAFE/WALL 도트 타일(16×16 PNG)을 가로로 이어 붙인 아틀라스 → source 1.
	#    P2.3② 전엔 단색 fill이었던 자리. 결(가로 배치·source id)은 그대로 두고 픽셀만
	#    텍스처로 교체한다 → _paint_grid·WALL 충돌은 손 안 대도 그대로 동작한다.
	var n := SOLID_TILES.size()
	var img := Image.create_empty(TILE_ART * n, TILE_ART, false, Image.FORMAT_RGBA8)
	for i in n:
		var tile: int = SOLID_TILES[i]
		var src_img: Image
		if SOLID_TEX.has(tile):
			src_img = (load(SOLID_TEX[tile]) as Texture2D).get_image()
			if src_img.get_format() != Image.FORMAT_RGBA8:
				src_img.convert(Image.FORMAT_RGBA8)
		else:
			# ★ M2.1 — 도트 텍스처가 없는 타일(WATER)은 COLORS 단색으로 절차 생성(그레이박스).
			src_img = Image.create_empty(TILE_ART, TILE_ART, false, Image.FORMAT_RGBA8)
			src_img.fill(COLORS[tile])
		img.blit_rect(src_img, Rect2i(0, 0, TILE_ART, TILE_ART), Vector2i(i * TILE_ART, 0))
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_ART, TILE_ART)
	for i in n:
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, SOLID_SRC_ID)
	# ★[ADR-0043] 길 디테일 변종 source(다짐 결+잔자갈) 조립.
	_build_path_detail_source(ts)

	# 3) 물리 레이어 추가 + 벽 타일(외벽 WALL·실내 벽 HOUSE_WALL·CAFE_WALL·TREE·ROCK)에 꽉 찬 사각
	#    충돌 폴리곤(타일 중심 −8..8) → 통과 불가. 바닥(HOUSE/CAFE)은 충돌 없이 걷는다.
	var SOLID_POLY := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	ts.add_physics_layer()
	for solid in WORLD_SOLID_TILES:   # ★ [S1-2] 정준 SOLID 목록 참조(옛 하드코딩 대체 — CLIFF_FACE_BASE 포함)
		var sx := SOLID_TILES.find(solid)
		var td := src.get_tile_data(Vector2i(sx, 0), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, SOLID_POLY)
	# ★ T2 — 물(terrain)도 통과 불가. WATER는 corner terrain이라 SOLID source가 아니라 terrain
	#   source(0)에 든다. 물 칸에 깔리는 타일 = TR_WATER 코너를 *하나라도* 가진 타일들뿐이므로
	#   (풀 칸은 4코너 모두 풀이라 물 코너 0 → 충돌 없음), 그 전부에 같은 −8..8 충돌을 단다.
	#   = 옛 SOLID WATER와 동일한 통과 불가 집합(회귀 0)이되 corner 전환 아트가 입혀진다.
	var tsrc := ts.get_source(0) as TileSetAtlasSource
	for i in tsrc.get_tiles_count():
		var coord := tsrc.get_tile_id(i)
		var td := tsrc.get_tile_data(coord, 0)
		if td.terrain_set != TERRAIN_SET:
			continue
		if _has_water_corner(td):
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, SOLID_POLY)
	return ts

# ── [잔디 muted 조율] 풀(녹색) 픽셀을 warm-moss·저채도(세이지)로 수렴하는 공통 규칙 ──────────
# terrain 타일셋(_harmonize_grass_variants 패스A)과 프롭 잔디 오버레이(ground_grass·grass_tuft)가
# 같은 필드 톤을 공유하도록 단일 소스로 둔다(ADR-0001 런타임 글루 — 원본 에셋 보존). in-place.
# owner: 필드 잔디를 muted(청록끼↓·채도↓ 올리브 세이지)로. 형광 잔디뭉치 프롭도 같은 톤에 매칭.
const _MG_CANON_H := 95.0 / 360.0   # warm-moss 기준 hue
# 프롭 잔디 오버레이 — 이 텍스처들은 blit 전 _mute_grass_pixels로 필드 톤에 맞춘다.
const _GD_GRASS_MUTE := [GD_GRASS1, GD_GRASS2, GD_GRASS3, PROP_GRASS]
# ★ owner "초록 전부" — 화면의 초목 프롭(잔디뭉치·잡초·나무·덤불)을 필드 잔디와 같은 muted 톤으로.
#   _draw_props_for가 정체성 tex로 키잉(변주는 draw_tex를 _muted_prop_tex로 캐시). 갈색 밑둥은 hue 필터로 보존.
const _MUTE_GREEN_PROPS := [PROP_GRASS, PROP_DEBRIS_WEEDS, PROP_TREE_A, PROP_TREE_B, PROP_BUSH]
# 목본(나무·덤불) — 입체감이 채도에서 오므로 hue만 통일하고 채도는 덜 낮춘다(완화 강도).
# 잔디류(바닥 잔디·잡초·잔디뭉치)는 기본값(강함)으로 형광을 확실히 죽인다.
const _MUTE_WOODY := [PROP_TREE_A, PROP_TREE_B, PROP_BUSH]
const _WOODY_SAT_MUL := 0.85   # 목본 채도 계수(기본 0.74보다 덜 깎음)
const _WOODY_SAT_CAP := 0.50   # 목본 채도 캡(기본 0.38보다 높게 — 생기 유지, 밝은 라임만 억제)
func _mute_grass_pixels(img: Image, sat_mul := 0.74, sat_cap := 0.38) -> void:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.5 or c.s < 0.18:
				continue   # 투명·외곽선/회색은 보존
			var hd := c.h * 360.0
			if hd < 60.0 or hd > 158.0:
				continue   # 갈색(<60)·청록 물·soul-blue(>158) 제외 → 풀만
			var nh: float = lerpf(c.h, _MG_CANON_H, 0.72)  # hue를 warm-moss로 수렴(청록끼 제거·올리브)
			var ns: float = minf(c.s * sat_mul, sat_cap)   # 채도 캡(잔디류=강함 0.38 / 목본=완화 0.50)
			var nv: float = c.v * 0.96
			img.set_pixel(x, y, Color.from_hsv(nh, ns, nv, c.a))

# 프롭 잔디 스프라이트(grass_tuft)를 muted 톤으로 변환한 ImageTexture 캐시 —
# _draw_props_for는 프롭을 draw_texture_rect로 직접 그려 ground-detail muted 경로를 안 지난다.
# 원본 텍스처는 보존하고, 그리기용 muted 사본만 lazy 생성(ADR-0001 런타임 글루).
var _muted_prop_cache: Dictionary = {}
func _muted_prop_tex(tex: Texture2D, woody := false) -> Texture2D:
	if _muted_prop_cache.has(tex):
		return _muted_prop_cache[tex]
	var im: Image = tex.get_image()
	if im.get_format() != Image.FORMAT_RGBA8:
		im.convert(Image.FORMAT_RGBA8)
	im = im.duplicate()
	if woody:
		_mute_grass_pixels(im, _WOODY_SAT_MUL, _WOODY_SAT_CAP)   # 나무·덤불 완화(입체감 보존)
	else:
		_mute_grass_pixels(im)                                    # 잔디류 기본(형광 확실히 억제)
	var t := ImageTexture.create_from_image(im)
	_muted_prop_cache[tex] = t
	return t

# ── [ADR-0042] 증분3 — 잔디 변종 톤 평준화(체커 제거, lush 결 보존) ──────────
# 재생성한 Wang 4세트는 grass-bearing 3세트(grass_path·soil_grass·water_grass)가 각자 all-grass
# 타일을 만든다. grass base id로 체인해도 desaturate가 water_grass만 좁은 hue로 처리해 그 타일이
# 밝은 노랑으로 튀어 "톤 체커"가 생긴다. → 세 all-grass 타일의 *평균색만* 공통 톤(채널별 중앙값,
# 밝은 이상치에 강건)으로 옮기고 **국소 텍스처(lush 풀결)는 그대로 보존**한다(평탄화·변조 없음).
# 결과: 세 변종이 같은 톤·다른 풀결 → 체커 소멸·자연스러운 변주 유지. 런타임 글루(ADR-0001).
func _harmonize_grass_variants(ts: TileSet) -> void:
	var src := ts.get_source(0) as TileSetAtlasSource
	if src == null:
		return
	var img: Image = src.texture.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	# ── 패스 A: 모든 풀(녹색) 픽셀을 warm-moss·저채도(세이지)로 수렴(hue·채도) ───────────────
	# 세트마다 다른 풀 톤(특히 water_grass의 노랑)·연못 둘레 링·candy 채도를 한 번에 정리한다.
	# 갈색(길·밭)·청록 물·soul-blue는 hue 범위로 제외돼 보존. 명도(v)는 거의 유지 → lush 풀결 보존.
	# ★ 규칙은 프롭 잔디 오버레이(ground_grass·grass_tuft)와 공유 → _mute_grass_pixels 단일 소스.
	_mute_grass_pixels(img)
	# ── 패스 B: base all-grass 3변종의 *평균색*을 공통 톤(채널별 중앙값)으로 평행이동 ──
	# 패스 A로 hue/채도는 맞았으나 세트별 *명도* 차이가 남아 필드에 밝기 체커가 보일 수 있다.
	# base 타일 평균만 정합(텍스처는 평행이동이라 보존). 좌표는 터레인 비트로 robust 탐색.
	var rs: int = src.texture_region_size.x
	var coords: Array[Vector2i] = []
	for i in src.get_tiles_count():
		var co := src.get_tile_id(i)
		var td := src.get_tile_data(co, 0)
		if td.terrain_set != TERRAIN_SET:
			continue
		if td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER) == TR_GRASS \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER) == TR_GRASS \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER) == TR_GRASS \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER) == TR_GRASS:
			coords.append(co)
	if coords.size() >= 2:
		coords.sort()
		var n := float(rs * rs)
		var means := []
		var rch := []; var gch := []; var bch := []
		for coord in coords:
			var ox := coord.x * rs
			var oy := coord.y * rs
			var sr := 0.0; var sg := 0.0; var sb := 0.0
			for yy in rs:
				for xx in rs:
					var p := img.get_pixel(ox + xx, oy + yy)
					sr += p.r; sg += p.g; sb += p.b
			var m := Color(sr / n, sg / n, sb / n)
			means.append(m)
			rch.append(m.r); gch.append(m.g); bch.append(m.b)
		rch.sort(); gch.sort(); bch.sort()
		var mid := coords.size() / 2
		var target := Color(rch[mid], gch[mid], bch[mid])
		# ★[ADR-0043 → owner Gemini 가이드 2차 2026-07-04] base grass 무늬(lush 풀잎) 대비 감쇠 —
		#   target + (p−tile_mean)*(1−DAMP). owner "필드가 자글자글 지저분 → 민무늬 베이스 80~90%"(스타듀식)
		#   가이드로 0.42→0.82 대폭 상향: 국소 무늬(풀잎 텍스처)를 18%만 남겨 "은은한 질감의 민무늬 베이스"로
		#   (Gemini 1단계 "연한 픽셀 감각" — 완전 단색 아님). 풀 입체감은 클러스터 오버레이(_gd_cluster)가 담당.
		const _GD_CLUMP_DAMP := 0.82
		for idx in coords.size():
			var coord: Vector2i = coords[idx]
			var ox := coord.x * rs
			var oy := coord.y * rs
			var tile_mean: Color = means[idx]
			for yy in rs:
				for xx in rs:
					var p := img.get_pixel(ox + xx, oy + yy)
					var r := target.r + (p.r - tile_mean.r) * (1.0 - _GD_CLUMP_DAMP)
					var g := target.g + (p.g - tile_mean.g) * (1.0 - _GD_CLUMP_DAMP)
					var b := target.b + (p.b - tile_mean.b) * (1.0 - _GD_CLUMP_DAMP)
					img.set_pixel(ox + xx, oy + yy, Color(
						clampf(r, 0, 1), clampf(g, 0, 1), clampf(b, 0, 1), p.a))
	src.texture = ImageTexture.create_from_image(img)

# ── [ADR-0043] 길 디테일 변종 source(다짐 결 + 잔자갈) ──────────────────────
# 길 base가 평면 갈색이라 "너무 깨끗"(owner). 길 base 톤에서 절차적으로 미세 다짐 결(가로 rut)+
# 저주파 mottle + 작은 잔자갈을 입힌 변종을 PATH_VARIANTS개 만들어 별도 source(PATH_SRC_ID)에 둔다.
# 길 칸은 _paint_grid에서 결정적 해시로 변종 선택(그리드 반복 방지, 단 결정적이라 임의 아님).
func _build_path_detail_source(ts: TileSet) -> void:
	var src0 := ts.get_source(0) as TileSetAtlasSource
	if src0 == null:
		return
	var rs: int = src0.texture_region_size.x
	# path base 좌표(4코너 모두 길) 탐색.
	var pcoord := Vector2i(-1, -1)
	for i in src0.get_tiles_count():
		var co := src0.get_tile_id(i)
		var td := src0.get_tile_data(co, 0)
		if td.terrain_set != TERRAIN_SET:
			continue
		if td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER) == TR_PATH \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER) == TR_PATH \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER) == TR_PATH \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER) == TR_PATH:
			pcoord = co
			break
	if pcoord.x < 0:
		return
	var atlas: Image = src0.texture.get_image()
	if atlas.get_format() != Image.FORMAT_RGBA8:
		atlas.convert(Image.FORMAT_RGBA8)
	var base := Image.create(rs, rs, false, Image.FORMAT_RGBA8)
	base.blit_rect(atlas, Rect2i(pcoord.x * rs, pcoord.y * rs, rs, rs), Vector2i.ZERO)
	var out := Image.create(rs * PATH_VARIANTS, rs, false, Image.FORMAT_RGBA8)
	for v in PATH_VARIANTS:
		var t := base.duplicate()
		_texture_path_tile(t, v)
		out.blit_rect(t, Rect2i(0, 0, rs, rs), Vector2i(v * rs, 0))
	var psrc := TileSetAtlasSource.new()
	psrc.texture = ImageTexture.create_from_image(out)
	psrc.texture_region_size = Vector2i(rs, rs)
	for v in PATH_VARIANTS:
		psrc.create_tile(Vector2i(v, 0))
	ts.add_source(psrc, PATH_SRC_ID)

# 길 타일 한 장에 절차적 다짐 결 + 잔자갈을 입힌다(저대비·은은 — 노이즈 안 되게).
func _texture_path_tile(img: Image, variant: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var salt := 700 + variant * 17
	# 1) 저주파 mottle(±) + 가로 다짐 결(rut) — 평면 갈색에 결을 준다.
	for y in h:
		for x in w:
			var p := img.get_pixel(x, y)
			if p.a < 0.5:
				continue
			var n := (_gd_h01(x / 4, y / 4, salt) - 0.5) * 0.10   # ±5% 저주파 얼룩
			var rut := sin((y + variant * 5) * 0.55) * 0.022      # 가로 다짐 결
			var f := 1.0 + n + rut
			img.set_pixel(x, y, Color(clampf(p.r * f, 0, 1), clampf(p.g * f, 0, 1), clampf(p.b * f, 0, 1), p.a))
	# 2) 잔자갈 — 작고 드물게(밝은 점 + 1px SE 그림자). 저대비.
	for k in 4:
		var cx := 3 + int(_gd_h01(k, variant, salt + 1) * (w - 6))
		var cy := 3 + int(_gd_h01(k, variant, salt + 2) * (h - 6))
		var lighten: bool = _gd_h01(k, variant, salt + 3) > 0.45
		for dy in 2:
			for dx in 2:
				var p := img.get_pixel(cx + dx, cy + dy)
				var f2 := 1.18 if lighten else 0.86
				img.set_pixel(cx + dx, cy + dy, Color(clampf(p.r * f2, 0, 1), clampf(p.g * f2, 0, 1), clampf(p.b * f2, 0, 1), p.a))
		# 1px SE 미세 그림자(잔자갈 입체)
		var ps := img.get_pixel(cx + 2, cy + 2)
		img.set_pixel(cx + 2, cy + 2, Color(ps.r * 0.82, ps.g * 0.82, ps.b * 0.82, ps.a))

# ── [ADR-0043] 타일 배치 규칙 — "규칙 있을 곳엔 규칙, 없어도 되는 곳엔 임의" (owner) ──────
# Wang 오토타일은 코너 config로 *올바른 전환 타일*을 이미 규칙대로 고른다(구조는 결정적). 문제는
# 같은 config 안에 변종이 여럿이면 *어디서나 균일 랜덤*으로 뽑아, 경계·건물 옆 같은 구조적 맥락이
# "아무거나" 배치된 느낌이 드는 것. → **전환/경계 config는 결정적(변종 1개), 빈 들판(all-grass)만
# 변종 랜덤**으로 가른다. 구현: Godot TileData.probability — 전환 config의 중복 변종은 0(=안 뽑힘),
# all-grass 변종만 1(랜덤). 이러면 경계는 규칙적·의도적이고, 자연 변화는 빈 들판에만 남는다.
func _apply_placement_rules(ts: TileSet) -> void:
	var src := ts.get_source(0) as TileSetAtlasSource
	if src == null:
		return
	var seen := {}   # 전환 config 키 → 이미 활성 변종이 있나
	for i in src.get_tiles_count():
		var co := src.get_tile_id(i)
		var td := src.get_tile_data(co, 0)
		if td == null or td.terrain_set != TERRAIN_SET:
			continue
		var tl := td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER)
		var tr := td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER)
		var bl := td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER)
		var br := td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER)
		if tl == TR_GRASS and tr == TR_GRASS and bl == TR_GRASS and br == TR_GRASS:
			td.probability = 1.0   # 빈 들판 = 변종 랜덤 유지(자연 변화)
		else:
			var key := "%d,%d,%d,%d" % [tl, tr, bl, br]
			if seen.has(key):
				td.probability = 0.0   # 같은 전환 config 중복 변종 → 비활성(결정적·규칙적)
			else:
				seen[key] = true
				td.probability = 1.0

# 타일이 TR_WATER 코너를 하나라도 가지나(= 물 칸에 깔리는 타일 → 통과 불가 대상).
func _has_water_corner(td: TileData) -> bool:
	for corner in [TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]:
		if td.get_terrain_peering_bit(corner) == TR_WATER:
			return true
	return false

# 타일 종류 → 단색 source의 아틀라스 좌표(HOUSE/CAFE/WALL만)
func _solid_atlas(tile: int) -> Vector2i:
	return Vector2i(SOLID_TILES.find(tile), 0)

# ★ [S1-2] 타일 id가 통과 불가(SOLID)인가 — 정준 predicate. 테스트(cliff_test 등)·충돌 정의가 공용한다.
#   WATER(terrain corner)는 여기 없고 _has_water_corner로 따로 판정한다(회귀 보존). CLIFF_LIP은 걷기 O.
func is_solid(id: int) -> bool:
	return id in WORLD_SOLID_TILES

# terrain source(0)에서 그 terrain의 base 타일(4코너 모두 같은 terrain) 좌표를 찾는다.
# 1칸 폭 동선처럼 corner 전환에 묻히는 지형을 base로 또렷하게 깔 때 쓴다.
func _terrain_base_atlas(terrain: int) -> Vector2i:
	var src := ground.tile_set.get_source(0) as TileSetAtlasSource
	for i in src.get_tiles_count():
		var coord := src.get_tile_id(i)
		var td := src.get_tile_data(coord, 0)
		if td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER) == terrain \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER) == terrain \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER) == terrain \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER) == terrain:
			return coord
	return Vector2i.ZERO

# ★[ADR-0043 §6 후속] 그 terrain의 base 타일(4코너 동일)을 *전부* 모은다. _paint_grid 직접 채우기에서
# 빈 들판 풀 칸을 결정적 해시로 변종 분산할 때 쓴다(set_cells_terrain_connect의 probability 랜덤을
# 대체 — 재빌드·워프 재진입에 동일 결과라 깜빡임 0, 격자 반복도 해시가 깬다). 캐시(타일셋당 1회).
func _terrain_base_variants(terrain: int) -> Array:
	if _base_variant_cache.has(terrain):
		return _base_variant_cache[terrain]
	var out: Array[Vector2i] = []
	var src := ground.tile_set.get_source(0) as TileSetAtlasSource
	for i in src.get_tiles_count():
		var coord := src.get_tile_id(i)
		var td := src.get_tile_data(coord, 0)
		if td.terrain_set != TERRAIN_SET:
			continue
		if td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER) == terrain \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER) == terrain \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER) == terrain \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER) == terrain:
			out.append(coord)
	_base_variant_cache[terrain] = out
	return out

# 밭흙(soil) terrain base 타일의 16×16 이미지를 추출한다(field 오버레이의 도트 톤 원본).
func _extract_soil_base() -> Image:
	var ts: TileSet = load(TERRAIN_TILESET_PATH)
	var src := ts.get_source(0) as TileSetAtlasSource
	for i in src.get_tiles_count():
		var coord := src.get_tile_id(i)
		var td := src.get_tile_data(coord, 0)
		if td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER) == TR_SOIL \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER) == TR_SOIL \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER) == TR_SOIL \
			and td.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER) == TR_SOIL:
			return src.texture.get_image().get_region(src.get_tile_texture_region(coord, 0))
	# fallback: 밭흙 단색(soil base를 못 찾을 때)
	var f := Image.create_empty(TILE_ART, TILE_ART, false, Image.FORMAT_RGBA8)
	f.fill(COLORS[SOIL])
	return f

# soil 이미지를 어둡게(mul) + 약간 푸르게(blue_add) 틴트해 경작 고랑 상태색을 만든다.
func _tint_soil(soil: Image, mul: float, blue_add: float) -> Image:
	var o := Image.create_empty(TILE_ART, TILE_ART, false, Image.FORMAT_RGBA8)
	for y in TILE_ART:
		for x in TILE_ART:
			var p := soil.get_pixel(x, y)
			o.set_pixel(x, y, Color(p.r * mul, p.g * mul, minf(p.b * mul + blue_add, 1.0), 1.0))
	return o

# ── T2.1/T2.3 밭 오버레이 TileSet: 칸 상태 8종(충돌 없음) ──────────────────
# P2.3: 단색 고랑 대신 밭흙(soil) terrain 베이스를 파생해 경작 칸 흙을 도트 톤으로
# 칠한다 — DRY=경작된 마른 고랑(밭흙보다 어둡게)·WET=물 준 젖은 고랑(더 어둡고
# 푸르게). 무외곽선(ROADMAP 컨벤션). 인덱스 = 외형단계 × 2 + 젖음. 가운데 새싹 점은
# 성장단계 표시용 그레이박스 유지(P2.2 작물 스프라이트 연결은 T2.3 seam).
func _build_field_tileset() -> TileSet:
	var soil := _extract_soil_base()
	var dry := _tint_soil(soil, 0.80, 0.0)    # 경작된 마른 고랑
	var wet := _tint_soil(soil, 0.55, 0.10)   # 물 준 젖은 고랑(짙고 푸른빛)
	var img := Image.create_empty(TILE_ART * N_OV, TILE_ART, false, Image.FORMAT_RGBA8)
	for ap in N_APPEAR:
		for wet_i in 2:
			var i := ap * 2 + wet_i
			var bg: Image = wet if wet_i == 1 else dry
			# ADR-0013/작물 연결: 오버레이는 경작 고랑(DRY/WET 흙)만 그린다. 성장단계 표시는
			# 더 이상 그레이박스 점이 아니라 _draw_crops가 작물 스프라이트로 얹는다(외형단계
			# 인덱스는 _overlay_index 호환 위해 유지하되 시각은 흙 톤만 — 점 제거).
			img.blit_rect(bg, Rect2i(0, 0, TILE_ART, TILE_ART), Vector2i(i * TILE_ART, 0))
	var tex := ImageTexture.create_from_image(img)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_ART, TILE_ART)
	for i in N_OV:
		src.create_tile(Vector2i(i, 0))

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_ART, TILE_ART)
	ts.add_source(src, 0)
	return ts

# ── 맵 데이터 구성 ────────────────────────────────────────────────────────
# M1.2 — 현재 구역(_region) 하나만 빌드한다(구현 (b): 현재 구역만 메모리, 전환 시 재빌드).
# 지금은 홈베이스(안식 농원)뿐이라 _build_home으로 분기하고, M1.4부터 구역이 늘면 여기에
# per-region 빌더를 추가한다. 미지 구역은 홈베이스로 폴백(부팅 안 죽음 — RegionCatalog 방어와 결).
func _build_grid() -> void:
	# ★ 코지-와이드 C1 — match 분기 직전에 구역 치수를 캐시한다. 8개 빌더·_set_tile·_build_border·
	# _is_farmable가 전역 상수 대신 이 멤버를 읽어 구역별 외부 크기를 따른다. size_of가 ZERO(미빌드
	# stub·미지 id)면 홈 외부 무대로 폴백 — 아래 match의 `_:`→_build_home 방어 폴백과 정합(빈 맵 방지).
	var sz := RegionCatalog.size_of(_region)
	if sz == Vector2i.ZERO:
		sz = Vector2i(MAP_W, OUTDOOR_H)
	_grid_w = sz.x
	_outdoor_h = sz.y
	_grid_h = _outdoor_h + INDOOR_BAND_H
	# ★[단계3] 고지 능선 충돌바는 HOME 전용 — 매 구역 빌드 전 비우고(스테일 방지), _build_home만 재생성.
	if _ridge_body != null and is_instance_valid(_ridge_body):
		_ridge_body.queue_free()
		_ridge_body = null
	match _region:
		RegionCatalog.HOME:
			_build_home()
		RegionCatalog.NARU_VILLAGE:
			_build_naru_village()
		RegionCatalog.SAMDOCHEON:
			_build_samdocheon()
		RegionCatalog.HWANGCHEONHAE:
			_build_hwangcheonhae()
		RegionCatalog.JEOSEUNG_FOREST:
			_build_jeoseung_forest()
		RegionCatalog.MIHOK_FOREST:
			_build_mihok_forest()
		RegionCatalog.EOPHWA_MINE:
			_build_eophwa_mine()
		RegionCatalog.NARAK:
			_build_narak()
		_:
			push_warning("알 수 없는 구역 '%s' — 홈베이스로 폴백" % _region)
			_build_home()
	_rebuild_prop_collision()   # ★ T3③' 현재 구역 실내 가구 통과 불가 충돌 재구성(러그 제외)
	_rebuild_trellis_collision()   # ★ [S1-5a] 트렐리스 넝쿨 통과 불가 충돌 재구성(안식 농원 전용)
	_rebuild_orchard_collision()   # ★ [S1-5b] 혼의 나무 밑동 통과 불가 충돌 재구성(안식 농원 전용)

# ★ T3③' 프롭 충돌 재구성 — 현재 구역 레이아웃에서 SOLID_PROPS 텍스처 칸에만 사각 충돌을
# 단다(러그·등불·꽃·debris(개간분)는 제외 = 통과 O. ★울타리는 2026-07-05 SOLID 편입 = 통과 불가).
# 시각 lift(WALL_PROP_LIFT)와 같은 오프셋을 충돌에도 줘
# 보이는 가구와 막히는 자리를 일치시킨다. 구역마다 가구 밴드가 달라(HOME y67~/마을 y74~) 외부 이동엔
# 무관 — 빌드/워프(_build_grid)마다 한 번 세운다. 테스트·봇은 실내를 물리로 안 걷는다(직접 좌표 세팅).
func _rebuild_prop_collision() -> void:
	if _prop_body == null:
		return
	for c in _prop_body.get_children():
		c.queue_free()
	# ★ ADR-0025 ② 런타임 데이터 참조(const PROP_LAYOUT_* 대신). 구역 → 묶음 키 매핑.
	var layout: Array = []
	match _region:
		RegionCatalog.HOME:
			layout = _prop_layouts.get("HOME", [])
		RegionCatalog.NARU_VILLAGE:
			layout = _prop_layouts.get("VILLAGE_HOUSE", [])
	for entry in layout:
		if not entry[0] in SOLID_PROPS:
			continue
		var sz: Vector2 = entry[0].get_size()
		var yo: int = entry[2] if entry.size() > 2 else 0
		var foot_bar: bool = entry[0] in FOOT_BAR_PROPS   # ★[§5] 키 큰 야외 프롭 = 발치 바
		var is_debris: bool = DEBRIS_KIND.has(entry[0])   # ★ [S1-8] 치운 SOLID debris는 충돌 skip(통과 O)
		for t in entry[1]:
			# ★ [S1-8 §10.3] 개간한 debris 타일은 충돌을 안 세운다(하드게이트 열림·overgrown 장애물 제거).
			if is_debris and reclaim != null and reclaim.is_cleared(t):
				continue
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			if foot_bar:
				# 발치 바 = 프롭 폭 × 밑단 높이, art 밑단(발치)에 정렬. 상단(머리·캐노피)은 통과 O.
				# ★[roster] 나무(2×4)·바위(2×2)는 밑행 1칸(TREE_FOOT_H)만 막고 그 위는 통과(FADE_PROPS 소속).
				#   FADE_PROPS 밖 부피 프롭은 반타일(FOOT_BAR_H) — 현재 예약(FADE_PROPS==FOOT_BAR_PROPS라 미사용).
				var fh: float = TREE_FOOT_H if entry[0] in FADE_PROPS else FOOT_BAR_H
				rect.size = Vector2(sz.x, fh)
				cs.shape = rect
				cs.position = Vector2(t.x * TILE + sz.x * 0.5, t.y * TILE + yo + sz.y - fh * 0.5)
			else:
				# 풀타일(실내 벽 가구·하드게이트 debris) — 회귀 보존.
				rect.size = sz
				cs.shape = rect
				cs.position = Vector2(t.x * TILE, t.y * TILE + yo) + sz * 0.5
			_prop_body.add_child(cs)

# ★ [S1-5a] 트렐리스 넝쿨 충돌 재구성(greybox-spec §6.2) — farm.solid_crop_tiles()의 각 칸에
# 16×16 사각 충돌을 세운다(터레인 SOLID_POLY −8..8과 동형). 넝쿨은 안식 농원(밭)에만 있으므로
# 다른 구역에선 비운다(field_layer.clear와 같은 결). tile_changed(심기/수확/제거)·구역 빌드마다 호출.
# 로직은 몰라도 되는 순수 물리 배선 — solid 판정은 farm.is_crop_solid가 유일 진실원.
func _rebuild_trellis_collision() -> void:
	if _trellis_body == null:
		return
	for c in _trellis_body.get_children():
		c.queue_free()
	if _region != RegionCatalog.HOME:
		return
	for t in farm.solid_crop_tiles():
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE, TILE)
		cs.shape = rect
		cs.position = Vector2(t.x * TILE + TILE * 0.5, t.y * TILE + TILE * 0.5)
		_trellis_body.add_child(cs)

# ★ [S1-5b] 혼의 나무 밑동 충돌 재구성(greybox-spec §7.4) — orchard.trunk_tiles() 앵커마다 밑동 1칸
# SOLID(수관 8칸은 통과 가능 — 3×3 벽 회피). _rebuild_trellis_collision과 동형(안식 농원 전용).
# orchard.changed(심기·복원)·구역 빌드에서 호출. 결실·수확은 풋프린트가 안 변해 충돌 불변이지만
# 멱등이라 같이 재구성해도 무해하다.
func _rebuild_orchard_collision() -> void:
	if _orchard_body == null or orchard == null:
		return
	for c in _orchard_body.get_children():
		c.queue_free()
	if _region != RegionCatalog.HOME:
		return
	for t in orchard.trunk_tiles():
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE, TILE)
		cs.shape = rect
		cs.position = Vector2(t.x * TILE + TILE * 0.5, t.y * TILE + TILE * 0.5)
		_orchard_body.add_child(cs)

# orchard 상태가 바뀐 프레임(심기·결실·수확·세이브 복원). 밑동 충돌을 다시 세우고 화면을 갱신한다
# (FarmField.tile_changed → _on_tile_changed와 같은 결의 디커플링 훅).
func _on_orchard_changed() -> void:
	_rebuild_orchard_collision()
	queue_redraw()

# ★ [S1-7] ranch 상태가 바뀐 프레임(배치·돌봄·산물·수집·세이브 복원). 짐승은 비-SOLID라 충돌 재구성은
# 없고 화면(placeholder 드로우)·HUD만 갱신한다(_on_orchard_changed의 충돌 없는 짝).
func _on_ranch_changed() -> void:
	queue_redraw()

# ★ [S1-8] reclaim 상태가 바뀐 프레임(개간·세이브 복원). 치운 debris는 드로우/충돌 skip-filter가
# reclaim.is_cleared로 질의하므로, 프롭 충돌을 다시 세우고(치운 SOLID debris 통과) 화면·앞프롭을 갱신한다.
func _on_reclaim_changed() -> void:
	if _region == RegionCatalog.HOME:
		_rebuild_prop_collision()
	queue_redraw()
	if _front_props != null:
		_front_props.queue_redraw()

# ★ ADR-0025 ② — PROP 좌표 외부화 로드. 부팅 시 한 번(_ready, _build_grid 전). res://layout.json이
# 있으면 거기서, 없거나 깨졌으면 시드에서 부팅하고 layout.json을 1회 생성(에디터/디버그 빌드만 write).
# 멱등: 시드 round-trip(_serialize→_deserialize)이 시드와 동등 → 회귀 0. 텍스처·SOLID·등불 빛은
# 여전히 코드(레지스트리·SOLID_PROPS·LANTERN_TILES_*) — 데이터는 *위치만*.
func _ensure_prop_layouts() -> void:
	if FileAccess.file_exists(LAYOUT_PATH):
		var f := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				_prop_layouts = _deserialize_layouts(parsed)
				return
			push_warning("layout.json 파싱 실패 → 시드 사용")
	# 없거나 실패 → 시드 round-trip으로 부팅 + 최초 이주 write
	_prop_layouts = _deserialize_layouts(_serialize_layouts(_SEED_LAYOUTS))
	_save_layouts()

# 묶음 Dictionary({key: [[tex,[Vector2i...],yo?],...]}) → JSON-safe Dictionary({key:[{tex,tiles,yo?}]}).
# 배치 모드 저장(_prop_layouts)과 최초 이주(_SEED_LAYOUTS) 둘 다 이 함수를 쓴다(입력 구조 동일).
func _serialize_layouts(layouts: Dictionary) -> Dictionary:
	var out := {}
	for key in layouts:
		var arr := []
		for entry in layouts[key]:
			var tiles := []
			for t in entry[1]:
				tiles.append([t.x, t.y])
			var rec := {"tex": _tex_key(entry[0]), "tiles": tiles}
			if entry.size() > 2:
				rec["yo"] = entry[2]
			arr.append(rec)
		out[key] = arr
	return out

# JSON Dictionary → 런타임 묶음(시드와 동일 구조: [tex, [Vector2i...], yo?]).
func _deserialize_layouts(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data:
		var arr := []
		for rec in data[key]:
			var tex: Texture2D = PROP_TEX_REGISTRY.get(rec.get("tex", ""), null)
			if tex == null:
				push_warning("layout.json 미등록 tex 키: " + str(rec.get("tex")))
				continue
			var tiles := []
			for xy in rec.get("tiles", []):
				tiles.append(Vector2i(int(xy[0]), int(xy[1])))
			var entry: Array = [tex, tiles]
			if rec.has("yo"):
				entry.append(int(rec["yo"]))
			arr.append(entry)
		out[key] = arr
	return out

# 텍스처 → 레지스트리 키(역방향 조회). 미등록이면 빈 키 + 경고(직렬화 누락 방지).
func _tex_key(tex: Texture2D) -> String:
	for k in PROP_TEX_REGISTRY:
		if PROP_TEX_REGISTRY[k] == tex:
			return k
	push_warning("PROP_TEX_REGISTRY 미등록 텍스처: " + str(tex.resource_path))
	return ""

# 런타임 묶음 → res://layout.json. 릴리스 빌드는 layout.json read-only라 write를 막는다
# (배치 모드·최초 이주 모두 에디터/디버그에서만). \t 들여쓰기로 git diff 가독성 확보.
func _save_layouts() -> void:
	if not OS.has_feature("editor"):
		return
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("layout.json 저장 실패: " + str(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(_serialize_layouts(_prop_layouts), "\t"))
	f.close()

# ════ ★ ADR-0025 ① 인게임 배치 모드 — 디버그/에디터 전용 저작 도구(얇은 한 겹) ════
# F10 토글. ON이면 _process가 시뮬을 멈추고(저작 전용) 마우스로 현재 묶음의 장식을 옮긴다:
#   LMB 드래그 = 집어 이동(타일 스냅) · LMB 빈칸 = 팔레트 텍스처 새로 놓기 · Del/⌫ = 삭제 ·
#   [ ] = 팔레트 순환 · Ctrl+S = layout.json 저장. 좌표는 _prop_layouts에 직접 쓰고 _save_layouts로 영속.
func _toggle_edit_mode() -> void:
	_edit_mode = not _edit_mode
	_edit_sel_entry = -1
	_edit_sel_tile = -1
	_edit_dragging = false
	_edit_update_ui()   # 안내는 패널 버튼·오버레이가 한다(중앙 _notice 길게 안 띄움)
	queue_redraw()

# ★ 맥 친화 배치 모드 패널(좌상단). 키 없이 마우스만으로: [배치 모드] 토글 + (ON시) [이전][팔레트명]
# [다음][저장][삭제]. 디버그/에디터 전용(_ready에서 OS.has_feature("editor")일 때만 생성).
func _make_edit_ui() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(6, 34)   # 상단 Readout(디버그 가로줄 y6~30) 아래로 내려 안 겹치게
	box.add_theme_constant_override("separation", 2)
	# ★ 패널 전용 작은 폰트 — CanvasLayer scale 1.5를 먹으므로 9px(=화면 ~14px)로 컴팩트하게.
	# 상시 HUD(16px)보다 작게 둬 디버그 도구가 화면을 안 잡아먹게 한다(자식 버튼·라벨 상속).
	var th := Theme.new()
	th.default_font_size = 9
	box.theme = th
	$CanvasLayer.add_child(box)
	_edit_btn_toggle = Button.new()
	_edit_btn_toggle.focus_mode = Control.FOCUS_NONE
	_edit_btn_toggle.pressed.connect(_toggle_edit_mode)
	box.add_child(_edit_btn_toggle)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	_edit_row = row
	var b_prev := Button.new()
	b_prev.text = "◀ 이전"
	b_prev.focus_mode = Control.FOCUS_NONE
	b_prev.pressed.connect(_edit_cycle_palette.bind(-1))
	row.add_child(b_prev)
	_edit_pal_label = Label.new()
	_edit_pal_label.custom_minimum_size = Vector2(72, 0)
	_edit_pal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_edit_pal_label)
	var b_next := Button.new()
	b_next.text = "다음 ▶"
	b_next.focus_mode = Control.FOCUS_NONE
	b_next.pressed.connect(_edit_cycle_palette.bind(1))
	row.add_child(b_next)
	var b_save := Button.new()
	b_save.text = "저장"
	b_save.focus_mode = Control.FOCUS_NONE
	b_save.pressed.connect(_edit_save_clicked)
	row.add_child(b_save)
	var b_del := Button.new()
	b_del.text = "삭제"
	b_del.focus_mode = Control.FOCUS_NONE
	b_del.pressed.connect(_edit_delete)
	row.add_child(b_del)
	_edit_update_ui()

# 패널 위젯 상태 동기화(토글·팔레트 순환 때마다).
func _edit_update_ui() -> void:
	if _edit_btn_toggle == null:
		return
	_edit_btn_toggle.text = "🛠 배치 모드 끄기" if _edit_mode else "🛠 배치 모드 켜기"
	_edit_row.visible = _edit_mode
	_edit_pal_label.text = _EDIT_PAL_NAMES.get(_EDIT_PALETTE[_edit_palette], _EDIT_PALETTE[_edit_palette])

func _edit_cycle_palette(dir: int) -> void:
	_edit_palette = (_edit_palette + dir + _EDIT_PALETTE.size()) % _EDIT_PALETTE.size()
	_edit_update_ui()
	queue_redraw()

func _edit_save_clicked() -> void:
	_save_layouts()
	_notice("layout.json 저장됨")

# 현재 _draw가 그리는 묶음 키(구역 따라). 배치 모드 편집 대상 = 화면에 보이는 그 묶음.
func _edit_key() -> String:
	match _region:
		RegionCatalog.HOME:
			return "HOME"
		RegionCatalog.NARU_VILLAGE:
			return "VILLAGE_HOUSE" if _is_in_house_interior() else "CAFE"
	return ""

func _mouse_tile() -> Vector2i:
	var w := get_global_mouse_position()
	return Vector2i(int(floor(w.x / TILE)), int(floor(w.y / TILE)))

# 마우스 타일을 덮는 (entry, tile) 인덱스. 위에 그려진 것(배열 뒤) 우선. 없으면 (-1,-1).
func _edit_pick(tile: Vector2i) -> Vector2i:
	var layout: Array = _prop_layouts.get(_edit_key(), [])
	for ei in range(layout.size() - 1, -1, -1):
		var entry: Array = layout[ei]
		var sz: Vector2 = entry[0].get_size()
		var wcells := int(ceil(sz.x / TILE))
		var hcells := int(ceil(sz.y / TILE))
		var tiles: Array = entry[1]
		for ti in tiles.size():
			var o: Vector2i = tiles[ti]
			if tile.x >= o.x and tile.x < o.x + wcells and tile.y >= o.y and tile.y < o.y + hcells:
				return Vector2i(ei, ti)
	return Vector2i(-1, -1)

func _unhandled_input(event: InputEvent) -> void:
	if _deco_mode:
		_deco_input(event)
		return
	if not _edit_mode:
		return
	var key := _edit_key()
	if key == "":
		return
	var layout: Array = _prop_layouts.get(key, [])
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var pick := _edit_pick(_mouse_tile())
			if pick.x >= 0:
				_edit_sel_entry = pick.x
				_edit_sel_tile = pick.y
				_edit_dragging = true
			else:
				_edit_place_new(_mouse_tile())   # 빈칸 → 팔레트 텍스처 새로 놓기
		else:
			if _edit_dragging:
				_rebuild_prop_collision()   # 드래그 끝 — 보이는 자리와 막히는 자리 일치
			_edit_dragging = false
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _edit_dragging and _edit_sel_entry >= 0:
		layout[_edit_sel_entry][1][_edit_sel_tile] = _mouse_tile()
		queue_redraw()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_edit_delete()
		elif event.ctrl_pressed and event.keycode == KEY_S:
			_save_layouts()
			_notice("layout.json 저장됨")
		elif event.keycode == KEY_BRACKETLEFT:
			_edit_palette = (_edit_palette - 1 + _EDIT_PALETTE.size()) % _EDIT_PALETTE.size()
			_notice("팔레트: " + _EDIT_PALETTE[_edit_palette])
		elif event.keycode == KEY_BRACKETRIGHT:
			_edit_palette = (_edit_palette + 1) % _EDIT_PALETTE.size()
			_notice("팔레트: " + _EDIT_PALETTE[_edit_palette])
		queue_redraw()

func _edit_place_new(tile: Vector2i) -> void:
	var key := _edit_key()
	var tex: Texture2D = PROP_TEX_REGISTRY.get(_EDIT_PALETTE[_edit_palette], null)
	if tex == null:
		return
	_prop_layouts[key].append([tex, [tile]])
	_edit_sel_entry = _prop_layouts[key].size() - 1
	_edit_sel_tile = 0
	_edit_dragging = true   # 놓자마자 드래그로 미세조정
	_rebuild_prop_collision()

func _edit_delete() -> void:
	if _edit_sel_entry < 0:
		return
	var layout: Array = _prop_layouts.get(_edit_key(), [])
	if _edit_sel_entry >= layout.size():
		return
	var tiles: Array = layout[_edit_sel_entry][1]
	tiles.remove_at(_edit_sel_tile)
	if tiles.is_empty():
		layout.remove_at(_edit_sel_entry)
	_edit_sel_entry = -1
	_edit_sel_tile = -1
	_rebuild_prop_collision()
	queue_redraw()

# 배치 모드 오버레이(월드 좌표) — 선택 노란 테두리 + 마우스 칸 청록 격자 + 팔레트 고스트.
func _draw_edit_overlay() -> void:
	var layout: Array = _prop_layouts.get(_edit_key(), [])
	if _edit_sel_entry >= 0 and _edit_sel_entry < layout.size():
		var entry: Array = layout[_edit_sel_entry]
		var o: Vector2i = entry[1][_edit_sel_tile]
		draw_rect(Rect2(Vector2(o.x * TILE, o.y * TILE), entry[0].get_size()), Color(1, 0.9, 0.1, 0.95), false, 2.0)
	var mt := _mouse_tile()
	var ptex: Texture2D = PROP_TEX_REGISTRY.get(_EDIT_PALETTE[_edit_palette], null)
	if ptex != null:
		draw_texture_rect(ptex, Rect2(Vector2(mt.x * TILE, mt.y * TILE), ptex.get_size()), false, Color(1, 1, 1, 0.45))
	draw_rect(Rect2(Vector2(mt.x * TILE, mt.y * TILE), Vector2(TILE, TILE)), Color(0.2, 1, 1, 0.8), false, 1.0)

# ── ★ [S1-9] 집 꾸미기 모드(플레이어-facing 3레이어 코스메틱, greybox-spec §11.5) ─────────────
# F10 저작 도구(_edit_*)와 완전 분리 — 독립 상태·오버레이·팔레트. 집 실내("집")에서만 진입, 마우스
# 커서 배치, 키 팔레트/회전, 순수 코스메틱(에너지·골드·시간 소모 0). 배치 델타는 home_deco가 소유한다.

# 꾸미기 모드 진입 가능 위치인가(집 실내 전용 게이트).
func _can_deco() -> bool:
	return _region == RegionCatalog.HOME and _indoor == "집"

func _toggle_deco_mode() -> void:
	_deco_mode = not _deco_mode
	if _deco_mode:
		_notice("집 꾸미기 (C=끄기 · 좌클릭=놓기 · 우클릭=지우기 · Q/E=레이어 · [/]=세트 · ,/.=아이템 · R=회전)", 4.0, true)
	queue_redraw()

# 현재 선택 레이어 키(FLOOR/WALL/FURNITURE).
func _deco_cur_layer() -> String:
	return _DECO_LAYERS[_deco_layer]

# 현재 팔레트 세트 id.
func _deco_cur_set() -> String:
	var ids := HomeDecoCatalog.set_ids()
	return str(ids[_deco_set]) if _deco_set >= 0 and _deco_set < ids.size() else ""

# 현재 세트·레이어의 아이템 key 목록(팔레트 순환 범위).
func _deco_item_keys() -> Array:
	return HomeDecoCatalog.items_of_layer(_deco_cur_set(), _deco_cur_layer())

# 현재 선택 아이템 key("" = 이 세트·레이어에 아이템 없음).
func _deco_cur_item() -> String:
	var keys := _deco_item_keys()
	if keys.is_empty():
		return ""
	return str(keys[clampi(_deco_item, 0, keys.size() - 1)])

func _deco_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_deco_place(_mouse_tile())
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_deco_remove(_mouse_tile())
			get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_deco_layer = posmod(_deco_layer - 1, _DECO_LAYERS.size())
				_deco_item = 0
				_notice("레이어: " + _DECO_LAYER_NAMES[_deco_cur_layer()])
			KEY_E:
				_deco_layer = posmod(_deco_layer + 1, _DECO_LAYERS.size())
				_deco_item = 0
				_notice("레이어: " + _DECO_LAYER_NAMES[_deco_cur_layer()])
			KEY_BRACKETLEFT:
				_deco_set = posmod(_deco_set - 1, HomeDecoCatalog.set_ids().size())
				_deco_item = 0
				_notice("세트: " + HomeDecoCatalog.set_name(_deco_cur_set()))
			KEY_BRACKETRIGHT:
				_deco_set = posmod(_deco_set + 1, HomeDecoCatalog.set_ids().size())
				_deco_item = 0
				_notice("세트: " + HomeDecoCatalog.set_name(_deco_cur_set()))
			KEY_COMMA:
				var n1 := _deco_item_keys().size()
				if n1 > 0:
					_deco_item = posmod(_deco_item - 1, n1)
			KEY_PERIOD:
				var n2 := _deco_item_keys().size()
				if n2 > 0:
					_deco_item = posmod(_deco_item + 1, n2)
			KEY_R:
				_deco_rot = posmod(_deco_rot + 1, 4)   # 새로 놓을 가구 회전(0..3)
				var uc := _mouse_tile()   # 마우스 아래 이미 놓인 가구가 있으면 그것도 함께 돌린다
				if home_deco.has_any(HomeDecoCatalog.L_FURNITURE, uc):
					home_deco.rotate_furniture(uc)
		queue_redraw()

# 마우스 칸에 현재 팔레트 아이템을 놓는다. 순수 코스메틱 — energy/wallet/skill을 부르지 않는다(§11.6).
func _deco_place(cell: Vector2i) -> void:
	var item_key := _deco_cur_item()
	if item_key == "":
		return
	var rot := _deco_rot if _deco_cur_layer() == HomeDecoCatalog.L_FURNITURE else 0
	if not home_deco.place(cell, _deco_cur_set(), item_key, rot):
		_notice("여기엔 놓을 수 없어요")   # 경계 밖·미해금(방어)

# 마우스 칸의 현재 레이어 배치를 지운다(레이어 간 공존이라 지금 레이어만).
func _deco_remove(cell: Vector2i) -> void:
	home_deco.remove(_deco_cur_layer(), cell)

# ★ [S1-9 §11.2] 유효 배치 칸을 계산해 home_deco에 주입한다. 좌표가 정적(HOME_HOUSE_RECT)이라 _ready에서
# 1회. 바닥 칸(FLOOR·FURNITURE) = 룸 실내 바닥(북벽 2행 밴드·문 아래벽 제외), 벽 밴드 칸(WALL) = 북벽 2행.
# HomeDeco는 기하를 모르므로(디커플링) main이 여기서 유일하게 좌표를 안다.
func _configure_home_deco_bounds() -> void:
	var r := HOME_HOUSE_RECT
	var floor_cells: Array = []
	# 바닥 = 내부 x(rect.x+1 .. rect.end.x-2), y(rect.y+2 .. rect.end.y-2). y+2로 북벽(y0)+밴드(y1) 건너뜀.
	for x in range(r.position.x + 1, r.end.x - 1):
		for y in range(r.position.y + 2, r.end.y - 1):
			floor_cells.append(Vector2i(x, y))
	var wall_cells: Array = []
	# 벽 밴드 = 북벽 2행(y0·y1)의 내부 x(_draw_house_wall_band 범위와 동일).
	for x in range(r.position.x + 1, r.end.x - 1):
		wall_cells.append(Vector2i(x, r.position.y))
		wall_cells.append(Vector2i(x, r.position.y + 1))
	home_deco.set_bounds(floor_cells, wall_cells)

# ★ [S1-9] 집 꾸미기 배치를 그린다(그레이박스 placeholder — 세트 색 블록·회전 표기. 실제 아트=S1-11).
# 레이어 순서 = 바닥재(바닥 위) → 벽지(벽 밴드 위) → 가구(그 위). HOME _draw 분기에서만 호출(집 실내
# 카메라 격리라 방 안에서만 보임). 순수 시각 — 충돌은 그레이박스에서 없다(§11.5, is_solid는 하류 훅).
func _draw_home_deco() -> void:
	if home_deco == null:
		return
	# 바닥재: 칸을 세트 색으로 반투명 칠(밑 바닥 타일이 살짝 비쳐 '깔린' 결).
	for cell in home_deco.layer_dict(HomeDecoCatalog.L_FLOOR):
		var e: Dictionary = home_deco.layer_dict(HomeDecoCatalog.L_FLOOR)[cell]
		var c := HomeDecoCatalog.color_of(e["set"], e["item"])
		c.a = 0.7
		draw_rect(Rect2(Vector2(cell.x * TILE, cell.y * TILE), Vector2(TILE, TILE)), c)
	# 벽지: 벽 밴드 칸을 세트 색으로 불투명 칠(벽 위 덮개).
	for cell in home_deco.layer_dict(HomeDecoCatalog.L_WALL):
		var ew: Dictionary = home_deco.layer_dict(HomeDecoCatalog.L_WALL)[cell]
		draw_rect(Rect2(Vector2(cell.x * TILE, cell.y * TILE), Vector2(TILE, TILE)), HomeDecoCatalog.color_of(ew["set"], ew["item"]))
	# 가구: 세트 색 박스 + 회전 표기(rot 방향 밝은 노치 — 4방 데이터, 그레이박스 표기).
	for cell in home_deco.layer_dict(HomeDecoCatalog.L_FURNITURE):
		var ef: Dictionary = home_deco.layer_dict(HomeDecoCatalog.L_FURNITURE)[cell]
		var px := Vector2(cell.x * TILE, cell.y * TILE)
		draw_rect(Rect2(px + Vector2(TILE * 0.15, TILE * 0.15), Vector2(TILE * 0.7, TILE * 0.7)), HomeDecoCatalog.color_of(ef["set"], ef["item"]))
		_draw_deco_rot_notch(px, int(ef.get("rot", 0)))

# 회전 노치 — rot(0=상·1=우·2=하·3=좌) 방향 가장자리에 밝은 점(4방 표기, 그레이박스).
func _draw_deco_rot_notch(px: Vector2, rot: int) -> void:
	var pts := [Vector2(0.5, 0.12), Vector2(0.88, 0.5), Vector2(0.5, 0.88), Vector2(0.12, 0.5)]
	var o: Vector2 = pts[posmod(rot, 4)]
	draw_circle(px + Vector2(TILE * o.x, TILE * o.y), TILE * 0.09, Color(1, 1, 1, 0.9))

# 꾸미기 모드 오버레이 — 마우스 칸 하이라이트 + 유효/무효 표시 + 현재 팔레트 고스트.
func _draw_deco_overlay() -> void:
	var mt := _mouse_tile()
	var layer := _deco_cur_layer()
	var valid := HomeDecoCatalog.has_item(_deco_cur_set(), _deco_cur_item())
	var ec := Color(0.2, 1, 1, 0.85)
	draw_rect(Rect2(Vector2(mt.x * TILE, mt.y * TILE), Vector2(TILE, TILE)), ec, false, 1.5)
	if valid:   # 팔레트 고스트(현재 아이템 색 반투명)
		var gc := HomeDecoCatalog.color_of(_deco_cur_set(), _deco_cur_item())
		gc.a = 0.45
		draw_rect(Rect2(Vector2(mt.x * TILE, mt.y * TILE), Vector2(TILE, TILE)), gc)

# ★ [S1-9] home_deco 변경(배치·삭제·회전·해금·복원) → 화면 갱신. 충돌은 그레이박스에서 없다(무충돌,
# §11.5). ⚠️ 하류 훅: 훗날 아트를 입혀 is_solid 가구 충돌을 켤 때, 여기서 _rebuild_prop_collision
# 동형의 얇은 런타임 충돌 빌더를 호출하게 확장한다(파이프라인 자리만 마련 — 지금은 통과 가능).
func _on_home_deco_changed() -> void:
	queue_redraw()

# 홈베이스(안식 농원): 외부 풀밭 + 밭(열린 흙) + 집·카페 실내 방(sub) 스택.
# 외부(0..OUTDOOR_H-1)는 풀밭, 그 아래 실내 전용 구역은 검은 여백(VOID)으로 기본을 깐 뒤,
# 우선순위 순서로 덮어쓴다. 실내 방 바깥의 VOID는 안 그려져 검은 배경이 비치고, 카메라가
# 실내 모드에서 방만 비추므로(아래 _apply_camera_limits) "건물 안에 들어온" 느낌을 준다.
# ★ 홈베이스 grid 크기는 MAP_W×MAP_H(외부 + 아래 실내 방). 구역-레벨 외부 크기는
#   RegionCatalog.HOME.size(40×24 = MAP_W×OUTDOOR_H)와 같고, 카메라가 그 값으로 외부를 격리한다.
# ★ M1.4 — 카페가 나루 마을로 이주해 안식 농원엔 더는 카페 외관·실내가 없다. 집·밭만 남고,
#   동쪽 복도 끝(38,16)이 나루 마을로 가는 길 워프가 된다(_carve_paths가 동쪽 끝까지 길을 잇는다).
func _build_home() -> void:
	_grid = []
	for y in _grid_h:
		var row: Array = []
		for x in _grid_w:
			row.append(GROUND if y < _outdoor_h else VOID)
		_grid.append(row)

	_build_cliffs()                                 # ★ADR-0035 고지(하늘 목장 NW) 둘레 절벽 단면 + 충돌(계단 틈만 열림)
	_fill_rect(SPIRIT_POND_RECT, WATER)             # ★ADR-0035 영혼빛 연못(중앙-약간서, WATER terrain·통과 X)
	# ★ [S1-10 / ADR-0044 §2 → ADR-0056 ④] 연못 북단 강둑 단차 2행 — 옛 하드코딩 루프를 SPIRIT_POND_RECT
	#   북단에서 유도하는 로컬 sibling 자동화로 대체(위 물 fill 뒤라야 유효).
	_autotile_pond_siblings()
	_fill_rect(STARTER_PATCH_RECT, SOIL)            # ★ADR-0035 5×5 스타터 패치(즉경작 SOIL)
	_build_facade(HOUSE_EXT_RECT, HOUSE_EXT_DOOR)   # 외부 본가 외관(통과 불가 박스 + 문 트리거)
	_set_tile(HOUSE_EXT_DOOR_E.x, HOUSE_EXT_DOOR_E.y, PATH)  # ★[ADR-0046] 본가 2칸 문 동칸도 리세스(짝수폭 중앙 2칸 = 아트 정합)
	_build_facade(STOREHOUSE_EXT_RECT, STOREHOUSE_EXT_DOOR)  # ★ 창고 외관(본가 왼쪽 병렬)
	_set_tile(STOREHOUSE_EXT_DOOR_E.x, STOREHOUSE_EXT_DOOR_E.y, PATH)  # ★ 2칸 양문 동칸도 리세스(문 폭 2칸 = 아트 정합)
	# ★ [B1-a.1] 동물 2건물 외관(고지 위, enterable — 카탈로그 등록). 남향 2칸 문이 방목지로 열림.
	_build_facade(NEOKURITGAN_EXT_RECT, NEOKURITGAN_EXT_DOOR)   # 넋우릿간(대형·안개소)
	_set_tile(NEOKURITGAN_EXT_DOOR_W.x, NEOKURITGAN_EXT_DOOR_W.y, PATH)  # 2패널 문 서칸도 리세스(문 폭 2칸 = 아트 정합)
	_build_facade(NEOKDUNGURI_EXT_RECT, NEOKDUNGURI_EXT_DOOR)   # 넋둥우리(소형·노을닭)
	_set_tile(NEOKDUNGURI_EXT_DOOR_W.x, NEOKDUNGURI_EXT_DOOR_W.y, PATH)  # 2패널 문 서칸도 리세스
	_fill_rect(SILO_EXT_RECT, WALL)                            # ★ [B1-a.3] 여물광(비진입 저장 건물) WALL 박스 — 문·실내 없음(낫 채집·게이지=_draw_silo)
	_fill_rect(WELL_RECT, WALL)                                # ★ [B2] 혼우물(비진입 리필 우물) WALL 박스 — 문·실내 없음(리필 메카닉=별도 grill, 드로우=_draw_well)
	_build_room(HOME_HOUSE_RECT, HOUSE, HOUSE_WALL, HOME_HOUSE_DOOR)   # ★C2 실내 집 방(HOME 밴드 y67+, 마을 공유 방과 분리)
	_set_tile(HOME_HOUSE_DOOR_E.x, HOME_HOUSE_DOOR_E.y, HOUSE)  # ★[ADR-0046] 실내 본가 문 동칸 개방(2칸·중앙 — 실내문≡외관문)
	# ★ T3③ 북벽 2타일 밴드 — 상단 벽 한 행(y68 실내)을 더 벽으로(스타듀식 입체 벽, plank는 _draw 오버레이).
	#   바닥은 y69~74로 한 줄 줄지만 충돌·취침(zone)·문·카메라 불변. 가구가 이 벽에 기대 윗부분이 벽을 덮는다.
	for x in range(HOME_HOUSE_RECT.position.x + 1, HOME_HOUSE_RECT.end.x - 1):
		_set_tile(x, HOME_HOUSE_RECT.position.y + 1, HOUSE_WALL)
	# ★[ADR-0048 §2] 건물별 실내 전용 바닥·벽(집 HOUSE/HOUSE_WALL 재사용 탈피). 문 개방 칸도 각 바닥으로.
	_build_room(STOREHOUSE_RECT, STOREHOUSE_FLOOR, STOREHOUSE_WALL, STOREHOUSE_DOOR)  # ★ 실내 창고 방(돌 판석 — kind=storehouse)
	_set_tile(STOREHOUSE_DOOR_E.x, STOREHOUSE_DOOR_E.y, STOREHOUSE_FLOOR)  # ★[ADR-0046] 실내 창고 문 동칸 개방(2칸·중앙 — 실내문≡외관문)
	# ★ [B1-a.1] 동물 2건물 실내 방(짐승은 _draw_ranch가 그림, 여물통=B1-a.3). 실내문≡외관문 2칸.
	_build_room(NEOKURITGAN_RECT, BARN_FLOOR, BARN_WALL, NEOKURITGAN_DOOR)  # 넋우릿간 실내(다진 흙+볏짚)
	_set_tile(NEOKURITGAN_DOOR_E.x, NEOKURITGAN_DOOR_E.y, BARN_FLOOR)
	_build_room(NEOKDUNGURI_RECT, COOP_FLOOR, COOP_WALL, NEOKDUNGURI_DOOR)  # 넋둥우리 실내(밝은 볏짚)
	_set_tile(NEOKDUNGURI_DOOR_E.x, NEOKDUNGURI_DOOR_E.y, COOP_FLOOR)
	_carve_paths()                         # 외부 동선(외관 문까지 — 맨 위에 덮어 길 강조)
	_build_border()                        # 맵 4변 경계벽(마지막에 보장)

# ★ M2.1 — 나루 마을(허브) 본격 레이아웃. 강(WATER)이 세로로 흘러 마을을 *서/동*으로 가르고,
# ★C3 — 100×72 코지-와이드: 다리(가로 복도 BRIDGE_Y 36)가 유일한 도하점이다(강 x49·50이 위·아래
#   경계까지 닿아 우회 도하 차단). 8채를 넓은 무대에 코지 분산한다:
#   · 서편: 카페(이주·실내 있음) + 메인 집 3(미호·멜·바나) — 도착(spawn 3,36)·서워프 옆.
#   · 동편: 만물상 + 주민 집 3 — 다리 건너. 북동 나룻터(→삼도천·혼백관)·동 산길(→갱도)은 워프
#     발동 칸까지 길이 닿되 목적 구역이 stub이라 휴면(M1.x 패턴, 그 구역 빌드 시 점등).
# 외부 풀밭 y0~71 + 아래 실내 띠(카페·공유 집·만물상, ★C3 +48 → y72~99)를 VOID로 격리한 스택.
# 카페 내부 좌표는 일괄 +48 평행이동이라 상대 배치가 보존돼 카페 시뮬·NPC·좌석·잡귀가 그대로 따라온다(회귀 0).
func _build_naru_village() -> void:
	_grid = []
	for y in _grid_h:
		var row: Array = []
		for x in _grid_w:
			row.append(GROUND if y < _outdoor_h else VOID)
		_grid.append(row)

	# 강(WATER, 통과 X) — 세로 두 칸 폭. 다리(BRIDGE_Y 36)는 뒤의 _carve가 PATH로 덮어 도하점이 된다.
	for rx in RIVER_X:
		for y in range(RIVER_Y0, RIVER_Y1 + 1):
			_set_tile(rx, y, WATER)

	# 서편: 카페(실내 있음) + 메인 집 3. 동편: 만물상 + 주민 집 3. 모두 통과 불가 외관 + 문 리세스.
	_build_facade(CAFE_EXT_RECT, CAFE_EXT_DOOR)         # 서편 카페 외관
	_build_facade(MEL_HOUSE_RECT, MEL_HOUSE_DOOR)       # 서편 멜 집
	_build_facade(MIHO_HOUSE_RECT, MIHO_HOUSE_DOOR)     # 서편 미호 집
	_build_facade(BANA_HOUSE_RECT, BANA_HOUSE_DOOR)     # 서편 바나 집
	_build_facade(STORE_EXT_RECT, STORE_EXT_DOOR)       # 동편 만물상
	for i in RESIDENT_HOUSE_RECTS.size():
		_build_facade(RESIDENT_HOUSE_RECTS[i], RESIDENT_HOUSE_DOORS[i])  # 동편 주민 집들
	_build_room(CAFE_RECT, CAFE, CAFE_WALL, CAFE_DOOR)  # 실내 카페 방(앤틱 벽 — VOID 스택)
	# ★ M2.2 — 메인/주민 집 6채가 공유하는 집 실내 방(아늑한 청회) + 만물상 전용 방(상업 톤).
	# 카페 옆 VOID 띠(y26~34)에 가로로 놓아 MAP_H 불변(warp_test grid 크기 불변식 유지). 한 번에
	# 하나의 건물만 방문하므로 6채가 한 방을 공유해도 충분(점유자 없는 그레이박스 — 가구만 재사용).
	_build_room(HOUSE_RECT, HOUSE, HOUSE_WALL, HOUSE_DOOR)   # 공유 집 실내(메인·주민 집 재사용)
	_build_room(STORE_RECT, CAFE, CAFE_WALL, STORE_DOOR)     # 만물상 실내(카페 타일 = 상업 톤)
	_carve_village_paths()                 # 마을 동선(복도·다리·각 문·워프 발동 칸까지)
	_build_border()                        # 맵 4변 경계벽(마지막에 보장)

# ★ M3.1 — 삼도천(강 낚시 무대 + 혼백관). 안식 농원·나루 마을과 같은 스택(외부 풀밭 y0~23 + 아래
# 실내 혼백관 방, VOID 격리). 낚시 메카닉은 만들지 않는다(Phase 3) — 강(WATER) 무대·강 낚시터(라벨만)·
# 혼백관(enterable 빈 방)까지. 강은 상단 가로 띠(y1~3)로 흘러 그 아래 land(y4~23)가 한 덩어리라
# 다리 없이도 모든 칸이 닿는다(flood-fill 단순·무 soft-lock). 나룻터 spawn(20,22)에서 동선이 혼백관
# 문·하구 워프 칸까지 닿는다. 혼백관은 그레이박스 WALL 박스(만물상·창고 결 — _draw 외관 텍스처 없음).
func _build_samdocheon() -> void:
	_grid = []
	for y in _grid_h:
		var row: Array = []
		for x in _grid_w:
			row.append(GROUND if y < _outdoor_h else VOID)
		_grid.append(row)

	# 강(WATER, 통과 X) — 상단 가로 띠. 그 아래 둑(y4~)이 강 낚시터(Phase 3에서 캐스팅 자리).
	for y in range(SAMDO_RIVER_Y0, SAMDO_RIVER_Y1 + 1):
		for x in range(1, _grid_w - 1):
			_set_tile(x, y, WATER)

	_build_facade(MUSEUM_EXT_RECT, MUSEUM_EXT_DOOR)            # 혼백관 외관(통과 불가 박스 + 문)
	_build_room(MUSEUM_RECT, HOUSE, HOUSE_WALL, MUSEUM_DOOR)   # 실내 혼백관 빈 방(kind=museum)
	_carve_samdocheon_paths()              # 동선(나룻터 도착 → 혼백관 문·하구 워프 칸)
	_build_border()                        # 맵 4변 경계벽(마지막에 보장)

# ★ M3.1 / ★C4 — 삼도천 동선(56×40). 가로 복도(y20)가 혼백관 쪽과 동단 하구 워프(54,20)를 잇고, 남단
# 나룻터(spawn 28,38·복귀 워프 28,39)에서 복도로 올라온다. 혼백관 문(9,19)은 세로로 복도까지 잇는다.
# land가 한 덩어리라 길은 동선 안내용이고, 워프 발동 칸까지 닿아 무 soft-lock.
func _carve_samdocheon_paths() -> void:
	_carve_h(20, 1, 54)                    # 가로 복도(동단 하구 워프 54,20까지)
	_carve_v(28, 20, 39)                   # 나룻터 도착(28,38)·복귀 워프(28,39) → 복도
	_carve_v(MUSEUM_EXT_DOOR.x, MUSEUM_EXT_DOOR.y, 20)  # 혼백관 문(9,19) → 복도(y20)

# ★ M3.2 / ★C5 — 황천해(바다 낚시 무대 + 생선가게). 삼도천과 같은 패턴(외부 land + 아래 실내 생선가게 방,
# VOID 격리). 낚시 메카닉은 만들지 않는다(Phase 3) — 바다(WATER) 무대·부두·바다 낚시터(라벨만)·생선가게
# (enterable 빈 방)까지. ★C5 64×44 — 바다는 ㄴ자 만(남측 y≥SEA_Y0 + 동측 x≥SEA_X0)으로 흘러 SE가 탁
# 트인 수면이고, 그 NW(x1~SEA_X0-1, y1~SEA_Y0-1)가 한 덩어리 land(flood-fill 단순). 부두(PATH)가 남측
# 바다로 길게 뻗어 그 끝(PIER_Y1)이 바다 낚시터. 막다른 구역이라 워프는 삼도천 복귀 하나.
func _build_hwangcheonhae() -> void:
	_grid = []
	for y in _grid_h:
		var row: Array = []
		for x in _grid_w:
			row.append(GROUND if y < _outdoor_h else VOID)
		_grid.append(row)

	# 바다(WATER, 통과 X) — ㄴ자 만(남측 가로 띠 y≥SEA_Y0 + 동측 세로 띠 x≥SEA_X0). NW가 한 덩어리 land로
	# 남고, 부두 끝(남측 바다 한가운데)이 바다 낚시터(Phase 3 캐스팅 자리). 경계벽은 뒤에서 외곽 링을 덮는다.
	for y in range(1, _outdoor_h):
		for x in range(1, _grid_w - 1):
			if x >= SEA_X0 or y >= SEA_Y0:
				_set_tile(x, y, WATER)

	_build_facade(FISHSHOP_EXT_RECT, FISHSHOP_EXT_DOOR)            # 생선가게 외관(통과 불가 박스 + 문)
	_build_room(FISHSHOP_RECT, HOUSE, HOUSE_WALL, FISHSHOP_DOOR)   # 실내 생선가게 빈 방(kind=fishshop)
	_carve_hwangcheonhae_paths()           # 동선(서단 도착 → 생선가게 문·부두)
	_build_border()                        # 맵 4변 경계벽(마지막에 보장)

# ★ M3.2 / ★C5 — 황천해 동선. 가로 복도(y15)가 서단 도착·복귀 워프(spawn 2,15·at 1,15)와 생선가게·부두를
# 잇고, 부두(PIER_X)가 복도에서 남측 바다로 세로로 뻗는다(WATER 위에 PATH를 덮어 걸을 수 있는 잔교 — _build
# 순서상 바다 fill 뒤에 carve라 PATH가 이긴다). 부두 끝(바다 낚시터)까지 닿아 무 soft-lock.
func _carve_hwangcheonhae_paths() -> void:
	_carve_h(15, 1, PIER_X)                # 가로 복도(서워프 1,15 ~ 부두 x24)
	_carve_v(FISHSHOP_EXT_DOOR.x, FISHSHOP_EXT_DOOR.y, 15)  # 생선가게 문(8,10) → 복도(y15)
	_carve_v(PIER_X, PIER_Y0, PIER_Y1)     # 부두(잔교) — 복도(y15)에서 남측 바다로 길게 뻗음(WATER 위 PATH)

# ★ M4.1 — 저승 숲(채집 무대 + 목공방). 삼도천·황천해와 같은 스택(외부 land y0~23 + 아래 실내 목공방
# 방, VOID 격리). 채집 메카닉은 만들지 않는다(Phase 3) — 나무(TREE) 무대·채집지(라벨만)·목공방(enterable
# 빈 방)까지. 나무 군집(FOREST_TREE_RECTS)을 동선·목공방·워프 칸을 비껴 흩어 숲 정체성을 주고, 빈터
# (GROUND)와 carve 복도로 모든 워프 칸·목공방 문이 닿는다(flood-fill 무 soft-lock). 목공방은 그레이박스
# WALL 박스(혼백관·생선가게 결 — _draw 외관 텍스처 없음, _paint_grid가 칠함).
func _build_jeoseung_forest() -> void:
	_grid = []
	for y in _grid_h:
		var row: Array = []
		for x in _grid_w:
			row.append(GROUND if y < _outdoor_h else VOID)
		_grid.append(row)

	# 나무(TREE, 통과 X) 군집 — 빈터(GROUND) 사이에 흩어 숲 밀도를 준다(동선·목공방·워프 비껴감).
	for r in FOREST_TREE_RECTS:
		_fill_rect(r, TREE)

	_build_facade(WOODSHOP_EXT_RECT, WOODSHOP_EXT_DOOR)            # 목공방 외관(통과 불가 박스 + 문)
	_build_room(WOODSHOP_RECT, HOUSE, HOUSE_WALL, WOODSHOP_DOOR)   # 실내 목공방 빈 방(kind=woodshop)
	_carve_jeoseung_forest_paths()         # 동선(spawn·워프·목공방 문 — 나무 군집을 덮어 길 보장)
	_build_border()                        # 맵 4변 경계벽(마지막에 보장)

# ★ M4.1 / ★C6 — 저승 숲 동선(60×44). 가로 복도(y22)가 서 목공방 열(x9)·동단 미혹 워프(58,22)를 잇고,
# 남단 세로(x30, spawn 30,42·갱도 워프 30,43)에서 복도로 올라온다. 목공방 문(9,19)은 세로로 복도까지 잇는다.
# carve는 나무 fill *뒤*라 PATH가 이겨 동선 칸엔 나무가 없다(무 soft-lock). 가장자리 밴드는 동선·워프 틈을 비껴 깔렸다.
func _carve_jeoseung_forest_paths() -> void:
	_carve_h(22, WOODSHOP_EXT_DOOR.x, 58)  # 가로 복도(서 목공방 9 ~ 동 미혹 워프 58,22)
	_carve_v(30, 22, 43)                   # 남단 spawn(30,42)·갱도 숲길 워프(30,43) → 복도(y22)
	_carve_v(WOODSHOP_EXT_DOOR.x, WOODSHOP_EXT_DOOR.y, 22)  # 목공방 문(9,19) → 복도(y22)

# ★ M4.2 / ★C7 — 미혹의 숲(특수 채집 무대 + 옥자 집). 저승 숲과 같은 스택이되 실내 방이 없다(옥자 집은
# 잠긴 외관 = 비-enterable). 64×44 막다른 깊은 숲: 에워싸는 빽빽한 외곽 나무 밴드 + 키운 연못(WATER),
# TREE 밀도↑(저승보다 짙음). 채집 메카닉은 만들지 않는다(Phase 3). 옥자 집은 _build_facade만(WALL 박스 +
# 문 리세스) — 실내·카탈로그 없어 진입 불가(축사 결, '숨겨진·게이트'). 동쪽 깊은 끝에 숨긴다(서편 가림 군집).
func _build_mihok_forest() -> void:
	_grid = []
	for y in _grid_h:
		var row: Array = []
		for x in _grid_w:
			row.append(GROUND if y < _outdoor_h else VOID)
		_grid.append(row)

	# 연못(WATER, 통과 X) — 깊은 숲 한가운데 물웅덩이. 나무(TREE) 군집 — 빈터 사이에 빽빽이(저승 숲보다 짙음).
	_fill_rect(MIHOK_POND_RECT, WATER)
	for r in MIHOK_TREE_RECTS:
		_fill_rect(r, TREE)

	# 옥자 집 = 잠긴 외관(비-enterable). 통과 불가 WALL 박스 + 문 리세스만(실내 방·카탈로그 없음 — 축사 결).
	_build_facade(OKJA_HUT_EXT_RECT, OKJA_HUT_DOOR)
	_carve_mihok_forest_paths()            # 동선(서단 도착 → 옥자 집 문·복귀 워프)
	_build_border()                        # 맵 4변 경계벽(마지막에 보장)

# ★ M4.2 / ★C7 — 미혹의 숲 동선. "곧은 척추 없음 — ㄹ자 굽이"(미혹 = 굽이쳐 헤침): 서단 입구에서 북→동→
# 남→동으로 꺾어 동쪽 깊은 끝 옥자 집 문(57,30)에 닿는다. 막다른 구역이라 워프는 서단 하나(복귀 1,22).
# carve는 나무·연못 fill 뒤라 PATH가 이겨 동선 칸엔 나무·물이 없다(무 soft-lock). 연못(x26~37)은 ③의 위(y10)로 돈다.
func _carve_mihok_forest_paths() -> void:
	_carve_h(22, 1, 20)                    # ① 서단 입구(복귀 1,22·spawn 2,22) → 동 x20
	_carve_v(20, 10, 22)                   # ② 북으로 꺾음 x20 (y22→y10)
	_carve_h(10, 20, 44)                   # ③ 동으로 x20→44 (연못 위로 돈다)
	_carve_v(44, 10, 32)                   # ④ 남으로 꺾음 x44 (y10→y32)
	_carve_h(32, 44, 57)                   # ⑤ 동으로 x44→57 (옥자 집 아래)
	_carve_v(OKJA_HUT_DOOR.x, OKJA_HUT_DOOR.y, 32)  # ⑥ 옥자 집 문(57,30) → 복도(y32)

# ★ M5.1 — 업화 갱도(채광/전투 무대 + 대장간·길드). 삼도천·숲 빌더와 같은 스택(외부 land y0~23 + 아래
# 실내 대장간·길드 방, VOID 격리). 채광·전투 메카닉은 만들지 않는다(Phase 3) — 바위(ROCK)·호수(WATER)
# 무대·채광지(라벨만)·대장간/길드(enterable 빈 방)·갱도 끝 던전 입구·나락 진입로(둘 다 잠긴 외관)까지.
# 바위 군집(MINE_ROCK_RECTS)을 동선(세로 x20·가로 y16)·문·게이트를 비껴 흩어 갱도 정체성을 주고, 빈터
# (GROUND)와 carve 복도로 두 워프 칸·대장간/길드 문이 닿는다(flood-fill 무 soft-lock). 대장간·길드는
# 그레이박스 WALL 박스(목공방·혼백관 결), 던전 입구·나락 진입로는 잠긴 외관(옥자 집 결 — 카탈로그 미등록).
func _build_eophwa_mine() -> void:
	_grid = []
	for y in _grid_h:
		var row: Array = []
		for x in _grid_w:
			row.append(GROUND if y < _outdoor_h else VOID)
		_grid.append(row)

	# 바위(ROCK, 통과 X) 군집 + 호수(WATER, 통과 X) — 빈터(GROUND) 사이에 흩어 갱도 밀도를 준다(동선·문·게이트 비껴감).
	for r in MINE_ROCK_RECTS:
		_fill_rect(r, ROCK)
	_fill_rect(MINE_LAKE_RECT, WATER)

	_build_facade(SMITHY_EXT_RECT, SMITHY_EXT_DOOR)              # 대장간 외관(통과 불가 박스 + 문)
	_build_facade(GUILD_EXT_RECT, GUILD_EXT_DOOR)               # 모험가 길드 외관(통과 불가 박스 + 문)
	_build_facade(DUNGEON_GATE_EXT_RECT, DUNGEON_GATE_DOOR)     # 갱도 끝 던전 입구 — 잠긴 외관(비-enterable, 카탈로그 미등록)
	_build_facade(NARAK_GATE_EXT_RECT, NARAK_GATE_DOOR)         # 나락 진입로 — 잠긴 외관(비-enterable, 카탈로그·워프 없음)
	_build_room(SMITHY_RECT, HOUSE, HOUSE_WALL, SMITHY_DOOR)    # 실내 대장간 빈 방(kind=smithy)
	_build_room(GUILD_RECT, CAFE, CAFE_WALL, GUILD_DOOR)        # 실내 길드 빈 방(kind=guild — 만물상 결 상업 톤)
	_carve_eophwa_mine_paths()             # 동선(spawn·두 워프·대장간/길드 문·게이트 — 바위 군집을 덮어 길 보장)
	_build_border()                        # 맵 4변 경계벽(마지막에 보장)

# ★ ADR-0018 C8 — 업화 갱도 동선(지그재그 세로 협곡). 남단 spawn(14,42)에서 채널이 x14→48→18→40으로
# 넓게 굽이쳐 북단 저승 워프(40,1)에 닿는다(7세그먼트). 북단 심연 포켓 곁가지(y7)가 던전·나락 게이트 문을
# 척추(x40)에서 가르고(잠긴 외관이라 닿아도 진입 안 됨 — 시각·동선 일관만), 남단 입구 두 서비스 문은 apron
# (y42)으로 내린다. carve는 바위·호수 fill·외관 *뒤*라 PATH가 이겨 동선 칸엔 바위·물이 없다(무 soft-lock).
func _carve_eophwa_mine_paths() -> void:
	# 지그재그 세로 채널(남 spawn 14,42 → 북 저승 워프 40,1): x14↑→ y32→ x48↑→ y20→ x18↑→ y12→ x40↑
	_carve_v(14, 32, 43)                   # 남단 채널(나루 워프 14,43·spawn 14,42 → y32)
	_carve_h(32, 14, 48)                   # 동으로 굽이(x14 → 48)
	_carve_v(48, 20, 32)                   # 동편 채널(y32 → 20)
	_carve_h(20, 18, 48)                   # 서로 굽이(x48 → 18)
	_carve_v(18, 12, 20)                   # 서편 채널(y20 → 12)
	_carve_h(12, 18, 40)                   # 동으로 굽이(x18 → 40)
	_carve_v(40, 1, 12)                    # 북단 채널(y12 → 저승 워프 40,1)
	# 북단 심연 포켓 곁가지(막다른) — 던전·나락 게이트 문을 척추(x40)에서 가른다(잠김 — 시각·동선 일관)
	_carve_h(7, 24, 40)                    # 곁가지(게이트 문 ~ 척추 x40)
	_carve_v(DUNGEON_GATE_DOOR.x, DUNGEON_GATE_DOOR.y, 7)   # 던전 입구 문(24,6) → 곁가지(y7)
	_carve_v(NARAK_GATE_DOOR.x, NARAK_GATE_DOOR.y, 7)       # 나락 진입로 문(32,6) → 곁가지(y7)
	# 남단 입구 두 서비스 문 → apron(y42, spawn 동선)
	_carve_v(SMITHY_EXT_DOOR.x, SMITHY_EXT_DOOR.y, 42)     # 대장간 문(6,41) → apron(y42)
	_carve_v(GUILD_EXT_DOOR.x, GUILD_EXT_DOOR.y, 42)       # 길드 문(24,41) → apron(y42)

# ★ M5.2 — 나락(독립 전투 던전 스테이지). 빈 전투장 — 외부 land 한 덩어리(VOID 스택 띠는 카메라 격리용으로
# 유지하되 실내 방 없음). 전투 메카닉은 만들지 않는다(Phase 3) — 심연·업화·봉인 모티프의 바위(ROCK) 둘레만.
# 진입로는 업화 갱도의 잠긴 외관이라 인게임 진입 없음(헤드리스 빌드·검증 전용). spawn(20,12) 중앙은 걸을 수 있다.
func _build_narak() -> void:
	_grid = []
	for y in _grid_h:
		var row: Array = []
		for x in _grid_w:
			row.append(GROUND if y < _outdoor_h else VOID)
		_grid.append(row)

	# 바위(ROCK, 통과 X) — 빈 전투장 네 구석에 흩어 '심연 갱' 분위기(spawn 중앙·동선 비껴감). 라이브 워프·건물 없음.
	for r in NARAK_ROCK_RECTS:
		_fill_rect(r, ROCK)
	_build_border()                        # 맵 4변 경계벽(둘레)

# 외부에서 보이는 건물 외관 — 통과 불가 박스(WALL)로 채우고 문 한 칸만 PATH로 뚫는다. 그 문 칸에
# 닿으면 _process(_maybe_enter_building)가 실내로 fade 전환한다. 그레이박스 단계라 외관은 회색
# WALL 박스 + 라벨이고, 도트 외관 스프라이트는 다음 패스에서 얹는다(ADR-0001: 그레이박스 먼저).
func _build_facade(rect: Rect2i, door: Vector2i) -> void:
	_fill_rect(rect, WALL)
	_set_tile(door.x, door.y, PATH)

# ★ [ADR-0044 개정 / 단계3 남향-only] 하늘 목장 고지 = NW 사각(x0..HIGHLAND_E, y0..HIGHLAND_S).
#   owner Gemini 가이드(2026-07-04, 선택지 B 남향 재배향) 확정 문법:
#   · 남향(아래)만 바위벽 — _autotile_south_cliffs가 마스크에서 Lip/Face/Base 자동 생성.
#   · 동향(x21 seam) = 바위벽 없는 "잔디 능선" — _build_ridge_barrier 충돌바 + 수풀 프롭(PROP_LAYOUT_HOME)이 폐쇄.
#   · 북/서 = 맵 경계(_build_border). 개간 게이트 = 남향 벽 관통 계단 노치(옛 동향 게이트 90° 회전).
const HIGHLAND_E := 20                    # 고지 동단 x(포함) — x21부터 저지(능선 seam)
const HIGHLAND_S := 26                    # 고지 남단 y(포함, =Lip 행) — y27/28=남향 벽(옛 남향밴드와 동일 위치·목장 손실 0)
const RANCH_GATE_X := 9                   # 남향 개간 게이트 노치 서칸 x(2칸 폭 x9..10)
const RANCH_GATE_W := 2

# ★ [S1-3 → 단계3 재작성] 계단·하드게이트 debris·수풀은 PROP(_draw_props). z축 아님(ADR-0013 2D 평면 불변).
func _build_cliffs() -> void:
	# ① 남향-only 오토타일러 — 고지 사각 마스크에서 남쪽 경계만 Lip/Face/Base 바위벽으로 굽는다.
	_autotile_south_cliffs(func(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x <= HIGHLAND_E and c.y <= HIGHLAND_S)
	# ② 남향 개간 게이트 — 남향 벽(y26 Lip / y27 Face / y28 Base)을 관통하는 2칸 계단 노치. 저지측 발치(y28~)는
	#    debris 하드 게이트(PROP·SOLID)로 개간 전 물리 차단(온보딩 — CONTEXT "평평≠막힘", 고지만 도구 게이트).
	_carve_stair_notch(Rect2i(RANCH_GATE_X, HIGHLAND_S, RANCH_GATE_W, 3))   # x9..10, y26..28
	# ★[ADR-0056 ③ FINAL] 노치 좌우 벽 끝을 곡선 코너로 라운딩(직각 마감 완화·스타듀식 말아넣기).
	_round_south_notch(RANCH_GATE_X, RANCH_GATE_W)
	# ③ 동향 잔디 능선 — 바위벽 없이 충돌바(x21 seam)로 고지를 자연 능선으로 폐쇄(수풀 프롭이 시각 완성).
	_build_ridge_barrier()

# ── ★ [S1-2 / ADR-0044 §1 → 단계3-⑥ 정리] pseudo-Z 절벽 원시어휘 (남향밴드·계단노치) ────────────────
# 남향-only 피벗으로 옛 동향 측벽(_lay_east_band)·90° 코너 스텝(_lay_corner_step)은 폐기했다(라이브 참조 0,
# cliff_test에서만 썼음 → 함께 정리). 남은 2종은 cliff_test 격리 검증에 쓰이는 "문법":
# 모두 _grid에 타일종만 쓴다(z축 아님 — ADR-0013 2D 평면 불변). 걷기/충돌은 타일종이 결정한다:
#   CLIFF_LIP=걷기 O / CLIFF_FACE·CLIFF_FACE_BASE=SOLID(is_solid). 그레이박스 색은 COLORS(LIP 밝음→FACE 중간→BASE 어둠).
# 라이브 home맵은 _autotile_south_cliffs가 남향 벽을 굽는다(밴드 헬퍼는 격리 테스트 전용).

# 남향 절벽 밴드(고지의 남쪽 가장자리) — y=Lip행 / y+1=Face행 / y+2=Face_Base행(접지 그림자).
# [x0, x1] 폐구간. ADR-0044 §1 남향 = Lip1+Face1+Base1(논리 3행 = 64px H=2 볼륨).
func _lay_south_band(x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1 + 1):
		_set_tile(x, y, CLIFF_LIP)
		_set_tile(x, y + 1, CLIFF_FACE)
		_set_tile(x, y + 2, CLIFF_FACE_BASE)

# 계단 노치 — 절벽 밴드를 종단하는 통로. rect(밴드 단면 전체 × 종단 길이)의 SOLID를 해제해 GROUND(걷기 O)로.
# 노치 폭 = 밴드 깊이(남향=2행 종단 / 동향=3열 종단 — ADR-0044 "2폭"↔§5"3열" 정합). STAIRS 프롭은 layout(S1-3).
func _carve_stair_notch(rect: Rect2i) -> void:
	_fill_rect(rect, GROUND)

# ★[ADR-0056 ③ FINAL] 노치(계단 통로) 직각 마감 라운딩 — 통로와 마주하는 절벽 좌우 끝 벽 셀을 곡선 코너
#   타일종으로 스위칭해 수직 단절을 스타듀식으로 말아넣는다. 새 타일 ID 0·순수 그리드 로직(세이브 불변).
#   좌벽의 동측 끝(노치 서변) → CORNER_SE / 우벽의 서측 끝(노치 동변) → CORNER_SW (오토타일러 west/east end
#   시맨틱과 동일). Face행=HIGHLAND_S+1 / Base행=HIGHLAND_S+2. 코너는 전부 SOLID라 통로 폭·충돌 불변.
func _round_south_notch(gate_x: int, gate_w: int) -> void:
	var fy: int = HIGHLAND_S + 1
	var by: int = HIGHLAND_S + 2
	var left: int = gate_x - 1
	var right: int = gate_x + gate_w
	if left >= 0:   # 좌벽 동측 끝(노치를 향한 면) → SE 곡선
		if _grid[fy][left] == CLIFF_FACE:
			_set_tile(left, fy, CLIFF_CORNER_SE)
		if _grid[by][left] == CLIFF_FACE_BASE:
			_set_tile(left, by, CLIFF_CORNER_SE_B)
	if right < _grid_w:   # 우벽 서측 끝(노치를 향한 면) → SW 곡선
		if _grid[fy][right] == CLIFF_FACE:
			_set_tile(right, fy, CLIFF_CORNER_SW)
		if _grid[by][right] == CLIFF_FACE_BASE:
			_set_tile(right, by, CLIFF_CORNER_SW_B)

# ★[ADR-0056 ④] 연못 북단 뱅크 로컬 sibling 자동화 — SPIRIT_POND_RECT 북단 경계선에서 강둑 2행을 유도
#   생성한다(옛 _build_home 하드코딩 루프 대체). 물/길 교차 full 오토타일 일반화(B안)·cliff_bank_water
#   전이 타일은 [cliff-tileset-spec §8]대로 S2/S3 연기 — 여기선 연못 하나에 대한 국소 유도만.
#   y-1=CLIFF_FACE(흙 strata 밴크) / y0=CLIFF_BANK(흙+돌 ledge)로 물 최상단 grass 전이행을 덮어 돌 ledge가
#   수면과 바로 맞닿게 한다(둘 다 SOLID·물 Wang은 y+1부터 자동 정합). 좌표=옛 하드코딩과 바이트 동일
#   → 세이브·연못 낚시/물뿌리개 앵커(Slice 3 예약) 불변. 순수 유도라 멱등(중복 호출 안전).
#   ★반드시 물(_fill_rect WATER)·_build_cliffs 뒤에 부른다(_build_home 결).
func _autotile_pond_siblings() -> void:
	var top: int = SPIRIT_POND_RECT.position.y
	for bx in range(SPIRIT_POND_RECT.position.x, SPIRIT_POND_RECT.end.x):
		_set_tile(bx, top - 1, CLIFF_FACE)
		_set_tile(bx, top, CLIFF_BANK)

# ★ [ADR-0044 개정 / 단계3] 남향-only 절벽 오토타일러 — 고지 불리언 마스크(is_hi)에서 스타듀 남향 문법을 굽는다.
#   각 고지 셀 중 *바로 아래가 저지*인 셀만 남쪽 경계로 보고 y=Lip(걷기O 오버행) / y+1=Face(SOLID) /
#   y+2=Base(SOLID·접지 그림자 베이크)로 3티어 바위벽을 세운다(Face/Base는 아래 저지 2행을 소비).
#   동/서/북 경계는 바위벽 없음(잔디 능선 — _build_ridge_barrier 충돌바 + 수풀 프롭이 폐쇄). SW/SE 곡선
#   전이 코너·Front 립은 단계3 후속 증분. z축 아님(ADR-0013) — 걷기/충돌은 타일종(is_solid)이 결정.
func _autotile_south_cliffs(is_hi: Callable) -> void:
	for y in range(_outdoor_h):
		for x in range(_grid_w):
			if not is_hi.call(Vector2i(x, y)):
				continue
			if is_hi.call(Vector2i(x, y + 1)):
				continue                                   # 아래도 고지 → 내부 평면(풀 그대로)
			# 남쪽이 저지 → 남향 절벽. Face/Base는 맵 안·저지일 때만(다른 고지 침범 금지).
			_set_tile(x, y, CLIFF_LIP)
			# ★[단계3-④] 벽의 서/동 바깥 끝(이웃이 고지 아님 = 맵경계·능선과 만나는 진짜 끝) → 곡선 코너로
			#   마감(각진 90° 대신 스타듀식 곡선 전이). 게이트 노치는 오토타일 후 GROUND로 덮이므로 여기선
			#   벽 셀만 보고 판정 — 노치 옆은 이웃이 아직 고지라 코너 아님(진짜 바깥 끝만).
			var west_end: bool = not is_hi.call(Vector2i(x - 1, y))
			var east_end: bool = not is_hi.call(Vector2i(x + 1, y))
			var face_id: int = CLIFF_CORNER_SW if west_end else (CLIFF_CORNER_SE if east_end else CLIFF_FACE)
			var base_id: int = CLIFF_CORNER_SW_B if west_end else (CLIFF_CORNER_SE_B if east_end else CLIFF_FACE_BASE)
			if y + 1 < _outdoor_h and not is_hi.call(Vector2i(x, y + 1)):
				_set_tile(x, y + 1, face_id)
			if y + 2 < _outdoor_h and not is_hi.call(Vector2i(x, y + 2)):
				_set_tile(x, y + 2, base_id)

# ★ [단계3] 동향 잔디 능선 = 바위벽 없이 통행만 막는 충돌바(고지 x≤HIGHLAND_E ↔ 저지 x≥+1 seam). 타일은
#   풀 그대로 두고(옛 동향 바위벽 폐기) 수풀 프롭(PROP_LAYOUT_HOME)이 시각적 능선을 완성한다 —
#   owner Gemini 가이드 "수풀과 낭떠러지로 가로막혀 갈 수 없는 자연스러운 산등성이 능선". _border_body와 동형
#   패턴(구역 빌드마다 _build_grid가 먼저 비우고, HOME만 _build_cliffs에서 재생성). HOME 전용.
func _build_ridge_barrier() -> void:
	if _ridge_body != null and is_instance_valid(_ridge_body):
		_ridge_body.queue_free()
	_ridge_body = StaticBody2D.new()
	add_child(_ridge_body)
	var seam_x := (HIGHLAND_E + 1) * TILE            # x21 왼쪽 경계(고지 x20 ↔ 저지 x21 사이)
	var bar_h := (HIGHLAND_S + 1) * TILE             # y0..HIGHLAND_S(고지 동단 전 구간)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(8, bar_h)                       # 8px 두께 seam 바(터널링 방지, 시각 없음)
	cs.shape = rs
	cs.position = Vector2(seam_x, bar_h * 0.5)
	_ridge_body.add_child(cs)

func _build_border() -> void:
	# ADR-0026 룩 정합 — 옛 WALL 경계 띠(스타듀에 없는 맵 둘레 벽)를 시각에서 없앤다. 외부
	# 경계칸은 풀(GROUND, _build_grid가 이미 깔아둠)로 남기고, 외부 영역(0..grid_w × 0..outdoor_h)
	# 바로 바깥 둘레에 StaticBody 충돌 막대 4개를 둘러 맵 밖 이탈만 막는다(시각=자연 지형·충돌만
	# 유지). 가장자리 나무·바위 PROP이 그 위에 서서 "숲에 안긴" 경계를 완성한다(가장자리 프레이밍).
	if _border_body != null and is_instance_valid(_border_body):
		_border_body.queue_free()
	_border_body = StaticBody2D.new()
	add_child(_border_body)
	var w := _grid_w * TILE
	var h := _outdoor_h * TILE
	for bar in [
		Rect2(0, -TILE, w, TILE),      # 상(맵 위 바깥)
		Rect2(0, h, w, TILE),          # 하(외부 아래 바깥)
		Rect2(-TILE, 0, TILE, h),      # 좌
		Rect2(w, 0, TILE, h),          # 우
	]:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = bar.size
		cs.shape = rs
		cs.position = bar.position + bar.size * 0.5
		_border_body.add_child(cs)

func _build_room(rect: Rect2i, floor_id: int, wall_id: int, door: Vector2i) -> void:
	# 바닥으로 채운 뒤 둘레를 (실내) 벽으로 두르고, 문 한 칸만 바닥으로 되돌려 통로로 연다
	# (실내 방이라 외부 흙길 PATH 대신 방 바닥으로 — 문 칸은 퇴장 트리거). 집·카페가 각자
	# 다른 실내 벽(HOUSE_WALL/CAFE_WALL)을 써 분위기를 가른다(아늑/앤틱).
	_fill_rect(rect, floor_id)
	for x in range(rect.position.x, rect.end.x):
		_set_tile(x, rect.position.y, wall_id)
		_set_tile(x, rect.end.y - 1, wall_id)
	for y in range(rect.position.y, rect.end.y):
		_set_tile(rect.position.x, y, wall_id)
		_set_tile(rect.end.x - 1, y, wall_id)
	_set_tile(door.x, door.y, floor_id)

func _carve_paths() -> void:
	# ★ ADR-0035 Phase B 구불 흙길(시각 안내 — GROUND/SOIL이 열려 도달성은 자동, 길은 *안내*다).
	#   스폰(40,60)에서 중앙 스파인(x38, 스타터 패치 x40..44 비껴)으로 북상해 본가 문(44,9)·창고 문(30,8)·
	#   스타터 패치로 갈라지고, 동워프(78,32)로 동편 갈래가 닿는다(스타듀식 가장자리 워프).
	_carve_v(38, 10, 60)                        # 중앙 스파인: 스폰(40,60) 곁 → 북(x38, 패치 비껴)
	_carve_h(10, 38, 45)                        # 본가 문 레인(y10, x38..45 — 2칸 문 폭까지)
	_carve_v(44, 9, 10)                         # 본가 문 서칸(44,9)까지
	_carve_v(45, 9, 10)                         # ★[ADR-0046] 본가 문 동칸(45,9) 진입로 — 2칸 문에 맞춰 입구 앞 2칸 폭
	_carve_h(20, 30, 38)                        # 창고 갈래(y20, x30..38)
	_carve_v(30, 8, 20)                         # 창고 문 서칸(30,8)까지 — 2패널 양문 서레인
	_carve_v(31, 8, 20)                         # ★ 창고 문 동칸(31) 진입로 — 2칸 양문에 맞춰 입구 앞 2칸 폭
	_carve_h(32, 38, 78)                        # 동워프 레인(y32, 스파인 → 동쪽 길 워프 78,32)
	# ★ [B1-a.1] 동물 2건물 2칸 문 앞 진입로 — 2패널 문(x4·x5 / x10·x11)에 맞춰 2칸 폭 흙길을 남향
	#   방목지로 뻗어 문과 잇는다. (y16 리세스는 아트 밑에 가려 안 보임 → y17부터 깔아야 문 밑단과 이어진다.)
	for py in range(18, 21):  # 넋우릿간(6×4, 아래벽 y17) 진입로 y18..20
		_set_tile(NEOKURITGAN_EXT_DOOR_W.x, py, PATH)  # 넋우릿간 서칸 레인(x5, y18..20)
		_set_tile(NEOKURITGAN_EXT_DOOR.x, py, PATH)    # 넋우릿간 동칸 레인(x6, y18..20)
	for py in range(16, 19):  # 넋둥우리(4×2, 아래벽 y15) 진입로 y16..18 (문 우측 x12·x13)
		_set_tile(NEOKDUNGURI_EXT_DOOR_W.x, py, PATH)  # 넋둥우리 서칸 레인(x12, y16..18)
		_set_tile(NEOKDUNGURI_EXT_DOOR.x, py, PATH)    # 넋둥우리 동칸 레인(x13, y16..18)
	# ★ [B2] 혼우물 접근 스퍼 — 중앙 스파인(x38)에서 우물 서면(x40,y19)까지 한 칸 잇는 흙길(시각 안내).
	#   우물 자체(x40..42)는 WALL이라 덮지 않는다(스퍼는 x39에서 멈춤 → 우물 서면과 인접).
	_carve_h(19, 38, 39)                        # 스파인(38,19) → 우물 서면 앞(39,19)

# ★ M2.1 / ★C3 — 나루 마을 동선. 메인 가로 복도(BRIDGE_Y 36)가 서/동을 잇되 강(x49,50)을 만나
# *다리*로만 건넌다. 서편: 서워프(1,36)·도착(3,36) ~ 다리 서단(48,36). 동편: 다리 동단(51,36) ~ 98,36.
# 각 건물 문은 복도까지 세로 스포크로 잇는다(시각 안내). 워프 발동 칸(나룻터 52,1 / 산길 98,18)까지도
# 길이 닿되 목적 구역 stub이라 휴면(M1.x 패턴). _carve_v/_carve_h = 세로/가로 한 줄 PATH(끝칸 포함).
func _carve_village_paths() -> void:
	# ★C3 — 100×72 코지-와이드 동선. 메인 가로 복도(BRIDGE_Y 36)가 좌우 가장자리를 잇되 강(x49·50)을
	#   다리로만 건넌다. GROUND이 열려 도달성은 자동(C2 결) — 문 스포크는 시각 안내 레인이다.
	for x in range(1, 49):
		_set_tile(x, BRIDGE_Y, PATH)            # 서편 가로 복도(서워프·도착 ~ 다리 서단)
	for x in range(51, 99):
		_set_tile(x, BRIDGE_Y, PATH)            # 동편 가로 복도(다리 동단 ~ 동 가장자리)
	for rx in RIVER_X:
		_set_tile(rx, BRIDGE_Y, PATH)           # 다리 — 강 위 PATH(유일한 도하점)

	# 서편 문 → 복도(문이 복도 위면 위→아래, 아래면 아래→위로 잇는다).
	_carve_v(CAFE_EXT_DOOR.x, CAFE_EXT_DOOR.y, BRIDGE_Y)      # 카페 문(8,31) → 복도
	_carve_v(MEL_HOUSE_DOOR.x, MEL_HOUSE_DOOR.y, BRIDGE_Y)    # 멜 문(22,18) → 복도
	_carve_v(MIHO_HOUSE_DOOR.x, BRIDGE_Y, MIHO_HOUSE_DOOR.y)  # 미호 문(6,47) → 복도(아래)
	_carve_v(BANA_HOUSE_DOOR.x, BRIDGE_Y, BANA_HOUSE_DOOR.y)  # 바나 문(31,47) → 복도(아래)

	# 동편 문 → 복도.
	_carve_v(STORE_EXT_DOOR.x, STORE_EXT_DOOR.y, BRIDGE_Y)                          # 만물상 문(60,18) → 복도
	_carve_v(RESIDENT_HOUSE_DOORS[0].x, RESIDENT_HOUSE_DOORS[0].y, BRIDGE_Y)        # 주민집1 문(82,17) → 복도
	_carve_v(RESIDENT_HOUSE_DOORS[1].x, BRIDGE_Y, RESIDENT_HOUSE_DOORS[1].y)        # 주민집2 문(59,47) → 복도(아래)
	_carve_v(RESIDENT_HOUSE_DOORS[2].x, BRIDGE_Y, RESIDENT_HOUSE_DOORS[2].y)        # 주민집3 문(83,47) → 복도(아래)

	# 워프 발동 칸까지 길(목적 구역 stub → 휴면, 그 구역 빌드 시 점등).
	_carve_v(52, RIVER_Y0, BRIDGE_Y)        # 나룻터(52,1) → 삼도천(혼백관) — 강 동안 북단 강변로
	_carve_v(98, 18, BRIDGE_Y)              # 산길(98,18) → 업화 갱도 — 동편 가장자리

func _paint_grid() -> void:
	# ★[ADR-0043 §6 후속] 빌드 최적화 = "풀 base는 직접 채우고(솔버 0), soil/water만 terrain-connect".
	#   기존 병목은 *전 지형 7200칸*을 풀로 terrain-solve(~1.6s, 변종 수 무관)한 첫 호출이었다.
	#   대신 모든 지형 칸을 풀 변종으로 *직접* 깐다(OLD의 첫 grass 솔브를 대체 — 같은 "전부 풀", 솔버 0).
	#   soil/water 오버레이는 OLD 그대로 set_cells_terrain_connect로 얹어 전환 타일을 *오버레이 칸 자신*에
	#   싣고(풀 이웃 불변 — 둑이 걷기 가능·강 둑 충돌 0 회귀 보존). 풀이 직접 채움이라(솔브 X) 건물 둘레
	#   갈색 path 링 원인(OLD의 grass terrain-solve가 빈 코너를 terrain 0=PATH로 처리)도 사라진다
	#   (RING_FIX 불필요). 결과: ~1.6s → ~0.2s(워프 프리즈 해소 + interior_test _settle 헤드룸 ~180ms→~1.3s).
	#   ※ 풀로 *먼저 깔아야* 솔버가 전환을 오버레이 칸에 싣는다 — 오버레이 칸을 자기 base로 미리 채우면
	#     "이미 완전한 그 terrain"이라 솔버가 전환을 *풀 이웃 쪽*으로 밀어 둑이 충돌을 갖는다(진단됨).
	#   ※ 길(path)은 terrain 오버레이 안 함 — §6(b) 유기경계 재도입은 *기술적 비호환*으로 보류(③ 참조):
	#     마을 1칸 폭 복도가 corner-match 전환에 묻혀 사라진다. 빌드 예산은 이제 충분하나 길 가시성이 우선.
	var path_cells: Array[Vector2i] = []
	var soil_cells: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []   # ★T2 — 풀 베이스 위에 물 terrain으로 덮어 풀↔물 corner 전환
	var grass_cells: Array[Vector2i] = []   # 모든 지형 칸(풀 변종으로 직접 채움 — GROUND·PATH·SOIL·WATER 전부)
	var solids: Array = []   # [[cell, tile_id], ...] — terrain 칠 *뒤*에 덮는다
	# M1.2 — 현재 구역 _grid의 실제 크기를 따른다(MAP_H/MAP_W 상수 대신). 홈베이스는
	# MAP_H×MAP_W라 동일하지만, 구역마다 grid 크기가 달라질 M1.4+에 그대로 따라온다.
	for y in _grid.size():
		for x in _grid[y].size():
			var cell := Vector2i(x, y)
			var t: int = _grid[y][x]
			if t == VOID:
				continue   # 실내 방 바깥 여백 — 칠하지 않아 검은 배경이 비친다(카메라 격리용)
			if TILE_TERRAIN.has(t):
				grass_cells.append(cell)   # 전 지형 칸을 일단 풀로(검은 구멍 0)
				if t == PATH:
					path_cells.append(cell)
				elif t == SOIL:
					soil_cells.append(cell)
				elif t == WATER:
					water_cells.append(cell)
			else:
				solids.append([cell, t])
	# ① 풀 직접 채우기(솔버 0) — 모든 지형 칸을 all-grass 변종으로 깐다. OLD의 7200칸 grass 솔브를
	#    대체(같은 "전부 풀" 상태). 변종은 결정적 해시로 분산(probability 랜덤 대체 — 재빌드·재진입에
	#    동일이라 깜빡임 0·격자 반복은 해시가 깬다). 그 위에 ②에서 soil/water 오버레이, ③에서 길 직칠.
	var grass_vars := _terrain_base_variants(TR_GRASS)
	var gvn := grass_vars.size()
	var grass_base := _terrain_base_atlas(TR_GRASS)
	for c in grass_cells:
		if gvn > 0:
			ground.set_cell(c, 0, grass_vars[int(_gd_h01(c.x, c.y, 5) * gvn) % gvn])
		else:
			ground.set_cell(c, 0, grass_base)
	# ② 오버레이(OLD 그대로) — soil/water를 풀 위에 terrain으로 얹어 풀↔밭·풀↔물 경계를 corner 전환.
	#    오버레이 칸이 풀 pre-state라 전환이 *오버레이 칸*에 실리고 풀 이웃은 안 바뀐다(둑 보존).
	#    ignore_empty_terrains=true: 빈 코너(solid/void) 무시 → 건물 둘레 갈색 링 0(RING_FIX 불필요).
	if soil_cells.size() > 0:
		ground.set_cells_terrain_connect(soil_cells, TERRAIN_SET, TR_SOIL, true)
	if water_cells.size() > 0:
		ground.set_cells_terrain_connect(water_cells, TERRAIN_SET, TR_WATER, true)
	# ③ 길은 base+디테일로 *직접* 깐다(OLD 그대로 — terrain 오버레이 X). ★[ADR-0043 §6(b) 갱신:
	#   길↔풀 유기경계 재도입은 *보류 유지* — 단, 이유가 성능에서 *기술적 비호환*으로 바뀌었다.] 빌드는
	#   ~1.6s→~0.2s로 충분히 빨라졌지만, 마을 동선이 *1칸 폭 복도*(BRIDGE_Y 가로 복도·문→복도 세로길)라
	#   corner-match 지형으로 얹으면 1칸 폭 길이 전환 타일에 *통째로 묻혀 사라진다*(육안 회귀로 확인 —
	#   OLD 선명한 갈색 복도 → terrain 오버레이 시 흐릿한 풀로 소멸). "끝까지 플레이>예쁨" 원칙상 길
	#   가시성이 우선 → 길은 솔리드 base+디테일로 또렷하게(_terrain_base_atlas가 corner 전환에 안 묻히는
	#   base를 깐다). 유기경계는 *grass 쪽 raggedness*(길은 그대로 두고 인접 풀칸만 들쭉날쭉) 같은 별도
	#   기법이 필요 — 폭≥2 길에 한정하거나 비-terrain 방식으로. 결정적 해시로 디테일 변종 선택(비반복).
	var has_pd: bool = ground.tile_set.has_source(PATH_SRC_ID)
	var path_base := _terrain_base_atlas(TR_PATH)
	for c in path_cells:
		if has_pd:
			var pv := int(_gd_h01(c.x, c.y, 9) * PATH_VARIANTS) % PATH_VARIANTS
			ground.set_cell(c, PATH_SRC_ID, Vector2i(pv, 0))
		else:
			ground.set_cell(c, 0, path_base)
	# ④ 단색(HOUSE/CAFE/WALL)은 terrain 위에 덮어 깐다(아직 도트 전, 단계 ②에서 교체).
	for s in solids:
		ground.set_cell(s[0], SOLID_SRC_ID, _solid_atlas(s[1]))
	# ★ [ADR-0042] 증분3 — 오버레이 모델 폐기(owner: "타일 가운데 박아놓은 느낌"). 풀의 생동감·연결은
	#   *오버레이가 아니라 풀로 꽉 찬 변종 베이스 타일 + 유기적 경계 변종 타일*(터레인 alternative)로 낸다.
	#   debris/forage(점적 장식)는 Phase 3 게임플레이 오브젝트로(설계 §5). 오버레이 호출 비활성.
	#_build_ground_details()
	# ★[ADR-0043 §6(b)] 길↔풀 유기경계 = grass 쪽 raggedness(비-terrain 기법). *중앙 박기* 디테일 오버레이는
	#   폐기 유지하되, *경계 fringe* 오버레이만 재도입한다 — 길은 솔리드 base 그대로(1칸 폭 복도 보존)·
	#   인접 풀칸 경계만 들쭉날쭉. terrain corner-match(복도 소멸) 대신 오버레이라 grid·충돌·테스트 불변.
	# ★[ADR-0049 라이브 통합] 안식 농원 = 새 16px 소프트 필드 지면(잔디·흙길·밭·물 필드 타일링 +
	#   경계 지터 디더)을 한 장 베이크해 _ground_detail_tex에 실어 기존 draw call로 그린다(씸-프리,
	#   grid·충돌·terrain 로직 불변). 그 외 구역은 기존 fringe 유지.
	if _region == RegionCatalog.HOME:
		_build_ground16()
	else:
		_build_path_grass_fringe()

# ── 지면 디테일(지형별 확률 시스템 — docs/design/ground-composition.md) ──────
# 결정적 해시 좌표라 프레임·세이브·재방문에 고정(깜빡임 0). 구역 빌드 때 한 장으로 베이크해
# _draw에서 1 draw call(타일 위·프롭/플레이어 아래). 손배치 grass_tuft를 대체.
func _gd_h01(x: int, y: int, salt: int) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	n = n & 0x7fffffff
	return float(n % 100000) / 100000.0

# ★[단계3-③ / owner Gemini 가이드 2차 2026-07-04] 저주파 값 노이즈(블록 해시 bilinear+smoothstep) —
#   풀 포기 클러스터 마스크(0~1). 스타듀식 "넓은 민무늬 베이스 + 특정 영역에만 풀 덩어리"를 위해, 칸별
#   독립 배치(자글자글) 대신 GD_CLUSTER_BLOCK칸 단위 저주파로 3~4칸 무리를 만든다. 결정적(해시 기반).
func _gd_cluster(x: int, y: int) -> float:
	var s := GD_CLUSTER_BLOCK
	var gx := x / s
	var gy := y / s
	var fx := float(x - gx * s) / s
	var fy := float(y - gy * s) / s
	fx = fx * fx * (3.0 - 2.0 * fx)   # smoothstep(격자 각짐 완화)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var v00 := _gd_h01(gx, gy, 30)
	var v10 := _gd_h01(gx + 1, gy, 30)
	var v01 := _gd_h01(gx, gy + 1, 30)
	var v11 := _gd_h01(gx + 1, gy + 1, 30)
	return lerpf(lerpf(v00, v10, fx), lerpf(v01, v11, fx), fy)

func _gd_shadow() -> Image:
	if _gd_shadow_stamp != null:
		return _gd_shadow_stamp
	var w := 20
	var h := 10
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := w / 2.0
	var cy := h / 2.0
	for yy in h:
		for xx in w:
			var fx := (xx - cx) / (w / 2.0)
			var fy := (yy - cy) / (h / 2.0)
			var d := fx * fx + fy * fy
			if d <= 1.0:
				img.set_pixel(xx, yy, Color(0, 0, 0, 0.28 * (1.0 - d * 0.55)))
	_gd_shadow_stamp = img
	return img

# ★ [ADR-0042] 증분2 — 잔디 풀포기를 *부드럽게* 만든다(스타듀 tuft = 저대비·베이스에 녹음).
# 청키·고대비 원본을 그대로 얹으면 "울퉁불퉁·박힌 느낌". 불투명 픽셀을 자기 평균색으로 끌어
# 내부 대비를 낮추고(SOFT_LERP), 알파를 살짝 낮춰(SOFT_ALPHA) 베이스에 스며들게 한다. texture당 1회 캐시.
const _GD_SOFT_SET := [GD_GRASS1, GD_GRASS2, GD_WEED_U]  # 부드럽게 녹일 풀포기·잡초
# ★[스캐터 재생성 2026-07-16] 소프트-멜트 약화 — 재생성 tuft는 외곽선·블레이드 구조가 핵심(스타듀식).
#   구값(0.34/0.86)은 크리스프 소스를 평균색으로 씻어 구조를 뭉갰다. flip 변주·mute(GRASS_MUTE)는 유지하되
#   멜트만 약하게(대비·알파 거의 보존) → 재생성 tuft가 또렷하게 얹힌다.
const _GD_SOFT_LERP := 0.10   # 평균색으로 끌어당기는 비율(내부 대비 완화) — 재생성 tuft는 약하게
const _GD_SOFT_ALPHA := 0.95  # 전체 알파 배수(베이스에 스며듦) — 거의 불투명
func _gd_soft_image(tex: Texture2D, flip := false) -> Image:
	var ckey := [tex, flip]
	if _gd_soft_cache.has(ckey):
		return _gd_soft_cache[ckey]
	var im: Image = tex.get_image()
	if im.get_format() != Image.FORMAT_RGBA8:
		im.convert(Image.FORMAT_RGBA8)
	im = im.duplicate()
	if flip:
		im.flip_x()   # 좌우 반전 변종(같은 풀포기가 도장처럼 반복되지 않게)
	if _GD_GRASS_MUTE.has(tex):
		_mute_grass_pixels(im)   # ★ 프롭 잔디 오버레이도 필드 톤에 맞춰 muted(평균/저대비화 전)
	var w := im.get_width()
	var h := im.get_height()
	# 불투명 픽셀 평균색
	var sr := 0.0; var sg := 0.0; var sb := 0.0; var cnt := 0
	for yy in h:
		for xx in w:
			var p := im.get_pixel(xx, yy)
			if p.a > 0.01:
				sr += p.r; sg += p.g; sb += p.b; cnt += 1
	if cnt == 0:
		_gd_soft_cache[ckey] = im
		return im
	var mr := sr / cnt; var mg := sg / cnt; var mb := sb / cnt
	for yy in h:
		for xx in w:
			var p := im.get_pixel(xx, yy)
			if p.a <= 0.01:
				continue
			im.set_pixel(xx, yy, Color(
				lerpf(p.r, mr, _GD_SOFT_LERP),
				lerpf(p.g, mg, _GD_SOFT_LERP),
				lerpf(p.b, mb, _GD_SOFT_LERP),
				p.a * _GD_SOFT_ALPHA))
	_gd_soft_cache[ckey] = im
	return im

# ── [ADR-0043 §6(b)] 길↔풀 유기경계 = grass 쪽 raggedness (비-terrain 오버레이) ──────────
# 길은 솔리드 base로 또렷하게 두고(1칸 폭 복도 보존), *경계선만* 유기적으로 들쭉날쭉하게 만든다.
# terrain 전환(corner-match)은 1칸 폭 길을 통째로 먹어 폐기했으므로, 대신 경계를 오버레이 한 장으로
# 베이크(_ground_detail_tex 재활용 — _draw에서 1 draw call, 타일 위·프롭 아래, grid/충돌/테스트 불변).
#
# ★[owner 피드백 2026-07-01] 초판은 *풀만 길 위로 더해* 한쪽으로만 부풀어(밑 풀 타일은 그대로라 "깎이는"
#   오목부가 없어) 부자연스러웠다. → **부호 있는 물결선 하나**로 개정: 위치마다 오프셋이 +면 풀이 길로
#   *볼록* 튀어나오고(풀 픽셀을 길칸에), -면 길 흙이 풀로 *오목* 파고든다(길 픽셀을 풀칸에 = 풀이 깎임).
#   → 레퍼런스처럼 경계가 양방향으로 자연스레 물결친다.
# 톤: 풀은 인접 풀칸의 실제 배치 변종 타일에서, 흙은 그 길칸의 실제 배치 길 변종 타일에서 픽셀 샘플 →
#   색이 자연히 이어짐. 오프셋은 월드 경계좌표 결정적 해시(재빌드·워프 동일=깜빡임 0)·~3px 코히어런트(풀날
#   뭉텅이·노이즈 아님)·경계 따라 칸 넘어 연속. |오프셋|이 DEAD 이하는 평평(그리드선 유지 — 과도한 흔들림 방지).
const _FR_MAX := 6        # 경계가 볼록/오목으로 넘나드는 최대 깊이(px, TILE 32의 ~19%)
const _FR_DEAD := 0.12    # |signed| 이 값 이하 = 평평 구간(경계선 그대로) — 균일 물결 방지
func _build_path_grass_fringe() -> void:
	_ground_detail_tex = null
	var bw := _grid_w * TILE
	var bh := _outdoor_h * TILE
	if bw <= 0 or bh <= 0:
		return
	var src0 := ground.tile_set.get_source(0) as TileSetAtlasSource
	if src0 == null:
		return
	var atlas: Image = src0.texture.get_image()
	if atlas.get_format() != Image.FORMAT_RGBA8:
		atlas.convert(Image.FORMAT_RGBA8)
	var rs: int = src0.texture_region_size.x   # =TILE(32), tres 확인 — 1:1 샘플
	var gvars := _terrain_base_variants(TR_GRASS)
	var gvn := gvars.size()
	if gvn == 0:
		return
	# 길 흙 샘플 원본: PATH_SRC_ID 디테일 변종(있으면) — 없으면 terrain base path 타일로 폴백.
	var has_pd: bool = ground.tile_set.has_source(PATH_SRC_ID)
	var patlas: Image
	var prs := rs
	var pbase := Vector2i.ZERO   # 폴백 시 source0 내 path base 아틀라스 좌표
	if has_pd:
		var psrc := ground.tile_set.get_source(PATH_SRC_ID) as TileSetAtlasSource
		patlas = psrc.texture.get_image()
		if patlas.get_format() != Image.FORMAT_RGBA8:
			patlas.convert(Image.FORMAT_RGBA8)
		prs = psrc.texture_region_size.x
	else:
		patlas = atlas
		pbase = _terrain_base_atlas(TR_PATH)
	var out := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	# dir: 0=N(위 풀) 1=S(아래 풀) 2=W(왼 풀) 3=E(오른 풀). 길칸 기준 그 방향 이웃이 풀이면 그 경계 물결.
	var neigh: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for y in range(_outdoor_h):
		for x in range(_grid_w):
			if _grid[y][x] != PATH:
				continue
			var pox := x * TILE
			var poy := y * TILE
			# 이 길칸이 _paint_grid에서 고른 흙 변종(salt 9 재현) → 길 아틀라스 원점.
			var pv := int(_gd_h01(x, y, 9) * PATH_VARIANTS) % PATH_VARIANTS
			var pax := (pv * prs) if has_pd else (pbase.x * prs)
			var pay := 0 if has_pd else (pbase.y * prs)
			for dir in 4:
				var nx := x + neigh[dir].x
				var ny := y + neigh[dir].y
				if nx < 0 or ny < 0 or nx >= _grid_w or ny >= _outdoor_h:
					continue
				if _grid[ny][nx] != GROUND:
					continue   # 풀(GROUND) 이웃만 — 흙·물·건물 경계는 제외
				# 인접 풀칸이 _paint_grid에서 고른 변종 아틀라스 좌표(같은 해시 salt 5 재현).
				var gco: Vector2i = gvars[int(_gd_h01(nx, ny, 5) * gvn) % gvn]
				var gax := gco.x * rs
				var gay := gco.y * rs
				var horiz := dir <= 1   # N/S = 가로 경계(along = 월드 x) / W/E = 세로 경계(along = 월드 y)
				# 평행한 다른 경계를 구분할 perp 고정 좌표(그 경계선의 월드 위치).
				var perp := poy
				if dir == 1:
					perp = poy + TILE
				elif dir == 2:
					perp = pox
				elif dir == 3:
					perp = pox + TILE
				for i in TILE:
					var along := (pox + i) if horiz else (poy + i)
					# 부호 있는 오프셋: 월드 경계좌표 결정적(~3px 코히어런트) + per-px 미세 지터.
					var signed := _gd_h01(int(along / 3), perp, 610 + dir) - 0.5   # -0.5..0.5
					if absf(signed) <= _FR_DEAD:
						continue   # 평평(경계선 그대로)
					var micro := _gd_h01(along, perp, 620 + dir)
					var mag := (absf(signed) - _FR_DEAD) / (0.5 - _FR_DEAD)   # 0..1
					var depth := 1 + int(mag * (_FR_MAX - 1) + micro * 1.5)
					depth = clampi(depth, 1, _FR_MAX)
					var grass_out := signed > 0.0   # +: 풀 볼록(길로) / -: 흙 오목(풀로, 풀 깎임)
					for j in depth:
						# 목적지(dx,dy: 월드 오프셋 from cell 원점) + 샘플(sx,sy: 원본 타일 로컬).
						var dx := 0
						var dy := 0
						var sx := 0
						var sy := 0
						if grass_out:
							# 풀이 길칸 안쪽으로 j만큼 — 인접 풀칸 경계열 픽셀을 이어붙임.
							match dir:
								0: dx = i; dy = j; sx = i; sy = rs - 1 - j
								1: dx = i; dy = TILE - 1 - j; sx = i; sy = j
								2: dx = j; dy = i; sx = rs - 1 - j; sy = i
								3: dx = TILE - 1 - j; dy = i; sx = j; sy = i
							var gp := atlas.get_pixel(gax + sx, gay + sy)
							if gp.a < 0.5:
								continue
							if j == depth - 1:   # blade 팁 = 살짝 어둡게(풀날 윤곽)
								gp = Color(gp.r * 0.78, gp.g * 0.78, gp.b * 0.82, gp.a)
							out.set_pixel(pox + dx, poy + dy, gp)
						else:
							# 길 흙이 풀칸 안쪽으로 j만큼 — 이 길칸 경계열 흙 픽셀로 풀을 깎음.
							match dir:
								0: dx = i; dy = -1 - j; sx = i; sy = j
								1: dx = i; dy = TILE + j; sx = i; sy = prs - 1 - j
								2: dx = -1 - j; dy = i; sx = j; sy = i
								3: dx = TILE + j; dy = i; sx = prs - 1 - j; sy = i
							var tx := pox + dx
							var ty := poy + dy
							if tx < 0 or ty < 0 or tx >= bw or ty >= bh:
								continue
							var dp := patlas.get_pixel(pax + sx, pay + sy)
							if dp.a < 0.5:
								continue
							out.set_pixel(tx, ty, dp)
	_ground_detail_tex = ImageTexture.create_from_image(out)

# ★[ADR-0049 라이브 통합] 16px 소프트 지면 오버레이 베이크(home16_dump 로직 이식).
#   필드(잔디·흙길·밭·물)를 월드좌표로 타일링(단위셀 반복 아님·격자 반복은 스캐터로 별도) +
#   길↔풀 경계 지터 디더. 성능: 셀 단위 blit_rect(빠름) + 경계 셀만 per-pixel 지터.
#   HOUSE/CAFE(실내 바닥)은 건너뛰어(투명) 타일맵 실내 바닥이 비치게 한다.
const _GF := 128         # 필드 한 변
const _GJIT := 5         # 경계 지터 진폭(px)

# ── Wang 경계 전환 타일 (spec 2026-07-16) ──────────────────────────────
# 표면 위계: 잔디>흙>길>밭>물. 경계에서 위계 높은 쪽이 upper(오버행=볼록).
const _SURF_RANK := {1: 4, 0: 3, 2: 2, 3: 1, 4: 0}
var _wang_tiles: Dictionary = {}   # pair_key → { corner_bits(0..15): Image }
const _WANG_DIR := "res://assets/terrain16/wang/"

func _surf_rank(s: int) -> int:
	return int(_SURF_RANK.get(s, -1))

func _corner_bits(nw: int, ne: int, sw: int, se: int) -> int:
	return nw | (ne << 1) | (sw << 2) | (se << 3)

func _wang_pair_key(lo: int, up: int) -> int:
	return lo * 10 + up

# 꼭짓점 (vx,vy)를 공유하는 최대 4셀 중 위계 최대 표면(-1=건물/절벽 제외, 없으면 -1).
func _wang_vertex_surf(surf: Array, vx: int, vy: int) -> int:
	var best := -1
	var best_r := -1
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var cx := vx + d.x
		var cy := vy + d.y
		if cx < 0 or cy < 0 or cx >= _grid_w or cy >= _outdoor_h:
			continue
		var s: int = surf[cy][cx]
		if s < 0:
			continue
		var r := _surf_rank(s)
		if r > best_r:
			best_r = r
			best = s
	return best

# 에셋 폴더의 <lo>_<up>_metadata.json + _image.png를 슬라이스해 코너키→Image 캐시.
func _load_wang_pairs() -> void:
	if not _wang_tiles.is_empty():
		return
	var dir := DirAccess.open(_WANG_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with("_metadata.json"):
			continue
		var stem := f.replace("_metadata.json", "")   # "lo_up"
		var parts := stem.split("_")
		if parts.size() != 2:
			continue
		var lo := int(parts[0])
		var up := int(parts[1])
		var png := _WANG_DIR + stem + "_image.png"
		if not ResourceLoader.exists(png):
			continue
		var jf := FileAccess.open(_WANG_DIR + f, FileAccess.READ)
		var meta: Dictionary = JSON.parse_string(jf.get_as_text())
		jf.close()
		var atlas: Image = (load(png) as Texture2D).get_image()
		if atlas.get_format() != Image.FORMAT_RGBA8:
			atlas.convert(Image.FORMAT_RGBA8)
		var tmap: Dictionary = {}
		for t in meta["tileset_data"]["tiles"]:
			var c: Dictionary = t["corners"]
			var bits := _corner_bits(
				1 if c["NW"] == "upper" else 0,
				1 if c["NE"] == "upper" else 0,
				1 if c["SW"] == "upper" else 0,
				1 if c["SE"] == "upper" else 0)
			var b: Dictionary = t["bounding_box"]
			tmap[bits] = atlas.get_region(Rect2i(int(b["x"]), int(b["y"]), int(b["width"]), int(b["height"])))
		_wang_tiles[_wang_pair_key(lo, up)] = tmap

func _load_big_fields() -> void:
	if _bf_grass != null:
		return
	_bf_grass = _big_field("res://assets/terrain16/grass_field.png", Color(0.29, 0.42, 0.24))
	# ★ 재생성 crisp 잔디 타일(PixelLab 저색, 형광 채도)을 muted somber green으로 톤 보정(owner "둘 다").
	#   grass_field.png는 crisp 소스로 보존하고 런타임에서만 muted(ADR-0001). 파일럿(순수 톤 검증)은 off.
	if _bf_grass_mute:
		_mute_grass_pixels(_bf_grass)
	_bf_dirt = _big_field("res://assets/terrain16/dirt_field.png", Color(0.52, 0.40, 0.29))
	_bf_soil = _big_field("res://assets/terrain16/soil_field.png", Color(0.35, 0.22, 0.16))
	_bf_water = _big_field("res://assets/terrain16/water_field.png", Color(0.13, 0.33, 0.39))
	# ★[스타듀 농장 룩] 마당 맨흙 = dirt_field(다져진 붉은 흙 길)을 더 밝고 노란 tan으로 리톤.
	#   스타듀 시작 농장의 모래빛 황갈색 지면 + 저승 warm 팔레트 정합. PATH(_bf_dirt)보다 밝아 길과 구분.
	_bf_earth = _retone_earth(_bf_dirt)

func _big_field(path: String, fallback: Color) -> Image:
	var img: Image
	if ResourceLoader.exists(path):
		img = (load(path) as Texture2D).get_image()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != _GF:
			img.resize(_GF, _GF, Image.INTERPOLATE_NEAREST)
	else:
		img = Image.create(_GF, _GF, false, Image.FORMAT_RGBA8)
		img.fill(fallback)
	img.resize(_GF * 2, _GF * 2, Image.INTERPOLATE_NEAREST)   # ×2 = 256 (월드 타일링 주기)
	return img

# ★[스타듀 농장 룩] 다져진 붉은 흙(dirt_field)을 마당 베이스용 밝은 황갈색(tan) 맨흙으로 리톤.
#   HSV로 명도↑·채도 약간↓·색상을 노란 쪽으로 살짝 이동 → 그레인(다짐 결)은 보존하되 스타듀 시작
#   농장의 모래빛 지면 톤으로. 결정적(픽셀 순수 함수)이라 재빌드·재진입 동일.
func _retone_earth(src: Image) -> Image:
	var img: Image = src.duplicate()
	var w := img.get_width()
	var h := img.get_height()
	for yy in h:
		for xx in w:
			var c := img.get_pixel(xx, yy)
			if c.a <= 0.01:
				continue
			var hh := c.h
			# 붉은 흙(hue ~0.05)을 노란-갈색(hue ~0.095)으로 당김(가중 평균, 과이동 방지).
			hh = lerpf(hh, 0.095, _earth_hue_lerp)
			var ss := clampf(c.s * _earth_sat_mul, 0.0, 1.0)   # 채도 배율(A/B 계수)
			var vv := clampf(c.v * _earth_val_mul + _earth_val_add, 0.0, 1.0)  # 명도(A/B 계수)
			img.set_pixel(xx, yy, Color.from_hsv(hh, ss, vv, c.a))
	return img

func _build_ground16() -> void:
	_ground_detail_tex = null
	_load_big_fields()
	_load_wang_pairs()
	var bw := _grid_w * TILE
	var bh := _outdoor_h * TILE
	if bw <= 0 or bh <= 0:
		return
	var out := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	var P := _GF * 2   # 256 = 월드좌표 타일링 주기(=8칸)
	# ★[스타듀 농장 룩] 표면 종류를 셀마다 1회 산출(0=맨흙 1=잔디패치 2=길 3=밭 4=물 -1=건물바닥).
	#   마당(GROUND)은 이제 *흙이 기본*이고 잔디는 저주파 클럼프로 흩뿌린 패치로만(흙 지배). 재계산 없이
	#   ①blit·②지터가 이 표면 그리드를 공유(per-pixel _grid 재해석 제거 — 잔디패치 경계도 유기적으로).
	var surf: Array = []
	for y in _outdoor_h:
		var row: Array = []
		for x in _grid_w:
			row.append(_g16_surface(x, y))
		surf.append(row)
	# ★[ADR-0053 후속 GDD — 잔디 군락화] 낱개 1×1 고립 금지 + 최소 유기 군락 강제. seed(클럼프+셀해시)는
	#   경계에서 단일 잔디 셀을 낳을 수 있어 격자 스케일이 드러난다("개발 격자 테스트 화면"). CA 정리로 응집.
	_g16_cluster_cleanup(surf)
	# ★[ADR-0054 건물 접지 — 잔디억제 패드] 건물 발치 링(footprint + _G16_BUILD_PAD칸)은 맨흙으로 강제해
	#   깔끔한 tan 접지(잔디 패치가 벽에 어색하게 맞닿는 것 방지·남향 문앞 성역화와 결). CA가 발치에 잔디를
	#   되심을 수 있어(맨흙 8이웃≥5 생성) *cluster_cleanup 뒤*에 최종 오버라이드로 적용한다. 순수 시각.
	for y in _outdoor_h:
		for x in _grid_w:
			if int(surf[y][x]) == 1 and _g16_near_building(x, y):
				surf[y][x] = 0
	# ① 셀 단위 필드 blit(빠름) — 건물바닥(-1)은 투명(실내 바닥 비침)
	for y in _outdoor_h:
		for x in _grid_w:
			var s0: int = surf[y][x]
			if s0 < 0:
				continue
			out.blit_rect(_g16_field(s0), Rect2i((x * TILE) % P, (y * TILE) % P, TILE, TILE), Vector2i(x * TILE, y * TILE))
	# ② Wang 경계 전환 — 4코너 표면이 2종 이상인 경계 셀에 손그림 전환 타일 blit(지터 대체).
	#    위계 상위 2표면을 (lo,up) 쌍으로 취해 그 tileset의 코너키 타일을 셀에 통째로 덮는다.
	#    삼중점(3종+)은 상위 2종만 쌍으로, 최하위 코너는 lower로 흡수(스타듀 폴백). 순수 셀·미생성
	#    쌍·미커버 코너조합은 스킵(①의 base blit 유지). _grid·충돌·세이브 불변(픽셀만).
	for y in _outdoor_h:
		for x in _grid_w:
			if int(surf[y][x]) < 0:
				continue   # 건물·절벽 = 오버레이 투명(절벽 오버레이가 덮음)
			var c_nw := _wang_vertex_surf(surf, x, y)
			var c_ne := _wang_vertex_surf(surf, x + 1, y)
			var c_sw := _wang_vertex_surf(surf, x, y + 1)
			var c_se := _wang_vertex_surf(surf, x + 1, y + 1)
			var uniq := {}
			for cv: int in [c_nw, c_ne, c_sw, c_se]:
				if cv >= 0:
					uniq[cv] = true
			if uniq.size() < 2:
				continue   # 순수 셀 = ① base blit 유지
			var ks: Array = uniq.keys()
			ks.sort_custom(func(a, b): return _surf_rank(a) > _surf_rank(b))
			var up_s: int = ks[0]
			var lo_s: int = ks[1]
			var pk := _wang_pair_key(lo_s, up_s)
			if not _wang_tiles.has(pk):
				continue   # 이 쌍 미생성(스킵된 쌍) → base 유지
			var bits := _corner_bits(
				1 if c_nw == up_s else 0,
				1 if c_ne == up_s else 0,
				1 if c_sw == up_s else 0,
				1 if c_se == up_s else 0)
			var tmap: Dictionary = _wang_tiles[pk]
			if not tmap.has(bits):
				continue   # 미커버 코너조합 → base 유지
			out.blit_rect(tmap[bits] as Image, Rect2i(0, 0, TILE, TILE), Vector2i(x * TILE, y * TILE))
	# ★[ADR-0056 REV4 ①] LIP 상단 텍스처 평지화 — CLIFF_LIP 타일 상단(잔디부)을 평지 _bf_grass로 오버레이해
	#   윗면 평지와 텍스처 문법 100% 일치. 고지 잔디화 뒤 lip은 톤은 맞으나 블레이드 패턴이 평지와 이질 →
	#   _bf_grass를 월드 타일링으로 끌어와(위 평지 grass와 씸리스 연속) lip 상단 _LIP_GRASS_H px에 그린다.
	#   잔디↔바위 엣지 경계는 raggedness 지터로 유기화(하드컷 방지). lip 하단 바위 엣지는 남김(out 투명).
	#   surf=-1로 lip은 오버레이 투명이라 여기 그린 grass가 밑 타일맵 lip 상단을 덮음. _grid·충돌·세이브 불변.
	for y in _outdoor_h:
		for x in _grid_w:
			if _grid[y][x] != CLIFF_LIP:
				continue
			var lox := x * TILE
			var loy := y * TILE
			for i in TILE:
				# 잔디↔바위 경계 깊이(평지 잔디가 lip 위로 삐죽하게 내려옴 — raggedness)
				var edge: int = _LIP_GRASS_H + int((_gd_h01(lox + i, loy, 650) - 0.5) * 2.0 * _LIP_EDGE_JIT)
				for j in range(maxi(0, edge)):
					out.set_pixel(lox + i, loy + j, _bf_grass.get_pixel((lox + i) % P, (loy + j) % P))
	# ★[ADR-0056 ④ FINAL] BASE 발치 접지 그림자 밴드 — CLIFF_BASE(및 곡선 base) 바로 아래(Y+1) tan 셀 상단에
	#   검은 알파 감쇄 밴드를 얹어 절벽 발치를 접지시킨다(ADR-0054 건물 접지 정신). _grid는 순수 tan 유지
	#   (충돌·세이브 불변) — 오버레이 픽셀만 어둡게. 아래가 tan(GROUND)일 때만(물·건물·다른 절벽 제외).
	#   ★[REV5] 곡선 base는 물러난(투명) 열엔 벽이 없으니 그 열 그림자는 스킵(코너에서 절벽 끊기는데 그림자가
	#   이어지던 것 교정 — owner). 벽(불투명) 열 아래에만 접지 그림자를 깐다.
	for y in _outdoor_h:
		for x in _grid_w:
			var bcid: int = _grid[y][x]
			if not (bcid in _CLIFF_BASE_TILES):
				continue
			var sby: int = y + 1
			if sby >= _outdoor_h or _grid[sby][x] != GROUND:
				continue
			# 곡선 코너 base면 그 타일의 최하단 행 불투명 마스크(벽=불투명 / 물러남=투명)로 열을 게이트.
			var bimg: Image = _corner_img(bcid) if (bcid == CLIFF_CORNER_SW_B or bcid == CLIFF_CORNER_SE_B) else null
			var sbx0: int = x * TILE
			var sby0: int = sby * TILE
			for i in TILE:
				if bimg != null and bimg.get_pixel(i, TILE - 1).a < 0.5:
					continue   # 코너 물러난 열 = 벽 없음 → 그림자 없음
				for j in _G16_APRON_H:
					var amt: float = (1.0 - float(j) / _G16_APRON_H) * _G16_APRON_MAX   # 상단 진함 → 아래로 0
					out.set_pixel(sbx0 + i, sby0 + j, out.get_pixel(sbx0 + i, sby0 + j).darkened(amt))
	# ★[ADR-0056 REV5 ②] 코너 컨텍스트 필 — 곡선 코너의 물러난(투명) 영역을 *주변 타일 지형*으로 채운다.
	#   코너 PNG는 벽만 불투명·물러난 영역 투명(make_cliff_corners). 그 투명 픽셀을 이웃 셀 지형으로 채워
	#   "절벽이 정면 아닐 때 주변 타일을 인식해 이어짐"(owner "잔디타일이 이어졌자나" 교정). SW=서쪽/SE=동쪽
	#   이웃 샘플(노치 코너=tan 통로 / 맵끝=저지). 벽 픽셀은 타일맵이 그림. _grid·충돌·세이브 불변.
	for y in _outdoor_h:
		for x in _grid_w:
			var cid: int = _grid[y][x]
			if not (cid in _CLIFF_CORNER_TILES):
				continue
			var cimg: Image = _corner_img(cid)
			if cimg == null:
				continue
			var ndx: int = -1 if (cid == CLIFF_CORNER_SW or cid == CLIFF_CORNER_SW_B) else 1
			var ns: int = -1
			if x + ndx >= 0 and x + ndx < _grid_w:
				ns = _g16_surface(x + ndx, y)
			if ns < 0:
				ns = 0   # 이웃이 절벽/건물/맵밖 → tan 폴백
			var fld: Image = _g16_field(ns)
			var cx0: int = x * TILE
			var cy0: int = y * TILE
			for j in TILE:
				for i in TILE:
					if cimg.get_pixel(i, j).a < 0.5:   # 코너 PNG 투명(물러난 영역) → 주변 지형
						out.set_pixel(cx0 + i, cy0 + j, fld.get_pixel((cx0 + i) % P, (cy0 + j) % P))
	# ★[P2 프로토타입] tan 위 오브젝트 스캐터(스타듀 잡초/tuft 모델) — 채움 패치를 끈 만큼 초록을 데칼로.
	if _G16_SCATTER:
		_compute_scatter_clump()   # ★[ADR-0058 B] 풀무리 CA 마스크 1회 계산(스캐터가 참조)
		_g16_blend_scatter(out)
	_ground_detail_tex = ImageTexture.create_from_image(out)

# ★[P2 프로토타입 2026-07-16] tan 베이스 위에 잡초/tuft/잔돌 데칼을 흩뿌린다(스타듀 농장: 초록=바닥 아닌
#   오브젝트). 기존 지면 디테일 시스템(_GD_TABLES 가중 롤 + _gd_cluster 여백 게이트 + _gd_soft_image 소프트
#   tuft + _gd_shadow 미세 그림자)을 _build_ground16의 out에 직접 blend(단일 텍스처·단일 draw call 유지).
#   프롭 점유 칸 회피·결정적 해시(재빌드/재방문 고정)·순수 시각. 구 _build_ground_details(비활성) 로직 이식.
func _g16_blend_scatter(out: Image) -> void:
	var occupied := {}
	for key in _REGION_PROP_KEYS.get(_region, []):
		for entry in _prop_layouts.get(key, []):
			for t in entry[1]:
				occupied[Vector2i(t.x, t.y)] = true
	var shadow := _gd_shadow()
	var sw := shadow.get_width()
	var sh := shadow.get_height()
	for y in range(_outdoor_h):
		for x in range(_grid_w):
			var terrain: int = _grid[y][x]
			if not _GD_TABLES.has(terrain):
				continue   # GROUND/PATH만 스캐터(밭·물·건물·절벽 제외)
			if occupied.has(Vector2i(x, y)):
				continue   # 나무·바위·가구 위엔 안 얹음
			# ★[스캐터 확산 ②] GROUND는 클러스터면 full 테이블(풀 무리), 빈 tan이면 sparse 마른 clutter(twig·stone)만.
			var table: Array
			if terrain == GROUND:
				if _scatter_is_clump(x, y):          # 구 _gd_cluster(x,y) >= GD_CLUSTER_CUT
					table = _gd_table_for(GROUND)      # 풀 무리 구역 — 풀 tuft 포함 전체(구역-키드, 폴백=전역)
				elif _gd_h01(x, y, 71) < _GD_SPARSE_DENSITY:
					table = _gd_sparse_for()           # 빈 tan — 나뭇가지·돌 저밀도 확산(스타듀 개활지, 구역-키드)
				else:
					continue                           # 대부분의 빈 tan = 민무늬(여백)
			else:
				table = _gd_table_for(terrain)         # PATH 등(구역-키드, 폴백=전역)
			var total := 0
			for e in table:
				total += int(e[1])
			var pick := int(_gd_h01(x, y, 2) * total)
			var acc := 0
			var chosen: Variant = null
			for e in table:
				acc += int(e[1])
				if pick < acc:
					chosen = e
					break
			if chosen == null or chosen[0] == null:
				continue   # 맨 타일(오버레이 없음)
			var ctex: Texture2D = chosen[0] as Texture2D
			var timg: Image
			if _GD_SOFT_SET.has(ctex):
				timg = _gd_soft_image(ctex, _gd_h01(x, y, 5) < 0.5)   # 소프트 tuft(저대비·좌우반전 변종)
			else:
				timg = ctex.get_image()
				if timg.get_format() != Image.FORMAT_RGBA8:
					timg.convert(Image.FORMAT_RGBA8)
				if _GD_GRASS_MUTE.has(ctex):
					_mute_grass_pixels(timg)   # 잔디류 오버레이도 필드 톤에 맞춰 muted
			var dw := timg.get_width()
			var dh := timg.get_height()
			var jx := int((_gd_h01(x, y, 3) - 0.5) * 8)
			var jy := int((_gd_h01(x, y, 4) - 0.5) * 6)
			var px := x * TILE + (TILE - dw) / 2 + jx
			var py := y * TILE + (TILE - dh) + jy   # bottom-center 피벗
			if bool(chosen[2]):
				var sx := x * TILE + TILE / 2 + jx - sw / 2 + 1
				var sy := y * TILE + TILE - 1 + jy - sh / 2
				out.blend_rect(shadow, Rect2i(0, 0, sw, sh), Vector2i(sx, sy))
			out.blend_rect(timg, Rect2i(0, 0, dw, dh), Vector2i(px, py))

# ★[스타듀 농장 룩] 지면 표면 결정 헬퍼(_build_ground16 전용) ─────────────────────────────
const _G16_GRASS_THR := 0.66   # 잔디 패치 문턱(↑=잔디↓·흙↑). 스타듀 시작 농장 ≈ 흙 지배(잔디 ~28%).
# ★[P2 프로토타입 2026-07-16 — docs/design/stardew-boundary-tile-analysis.md] 스타듀 농장은 채움 잔디
#   바닥 패치도 잔디↔흙 경계선도 없다. 초록은 전부 tan 위에 흩뿌린 오브젝트(잡초/tuft/나무)다. 그래서
#   저지 마당의 채움 잔디 패치를 끄고(→전부 tan) 초록을 스캐터 데칼로만 낸다 → 흙↔잔디 Wang 경계(0_1)·
#   외곽선 문제가 통째로 소멸. 순수 시각(out 픽셀만)·_grid/충돌/세이브 불변. false=스타듀식/true=구 채움패치.
const _G16_GRASS_PATCHES := false
const _G16_SCATTER := true      # tan 위 잡초/tuft/잔돌 데칼 스캐터(기존 _GD_TABLES/_gd_cluster 재활용)
# ★[ADR-0056 ④ FINAL] BASE 발치 접지 그림자 밴드 레버(_build_ground16 순수 시각 오버레이).
const _CLIFF_BASE_TILES := [CLIFF_FACE_BASE, CLIFF_CORNER_SW_B, CLIFF_CORNER_SE_B]   # 접지 대상 = 벽 최하단
# ★[ADR-0056 REV5 ②] 곡선 코너 4종 — 물러난 투명 영역을 이웃 지형으로 채우는 컨텍스트 필 대상.
const _CLIFF_CORNER_TILES := [CLIFF_CORNER_SW, CLIFF_CORNER_SW_B, CLIFF_CORNER_SE, CLIFF_CORNER_SE_B]
const _G16_APRON_H := 7        # 그림자 밴드 높이(px, 아래 tan 셀 상단부터)
const _G16_APRON_MAX := 0.42   # 상단 최대 어둠(Color.darkened amount) → 아래로 0 감쇄
# ★[ADR-0056 REV4 ①] LIP 상단 텍스처 평지화 레버(평지 _bf_grass를 lip 상단에 오버레이).
const _LIP_GRASS_H := 18       # lip 상단에 평지 잔디를 덮을 높이(px) — 하단 바위 엣지는 남김
const _LIP_EDGE_JIT := 3       # 잔디↔바위 경계 raggedness 진폭(px)

# 마당(GROUND) 칸이 잔디 패치인가 — 저주파 클럼프(넓은 초록 영역) + 셀 해시(작은 무리로 분해).
# 결정적(좌표 해시)이라 재빌드·재진입 동일. true=잔디(grass_field), false=맨흙(earth). 이것은 *seed*이고,
# 낱개/최소군락 정리는 _g16_cluster_cleanup(surf)가 CA로 후처리한다(격자 스케일 노출 방지).
func _g16_is_grass_patch(x: int, y: int) -> bool:
	var score := _gd_cluster(x, y) * 0.6 + _gd_h01(x, y, 41) * 0.4
	return score >= _G16_GRASS_THR

# ★[ADR-0053 후속 GDD — 잔디 군락화] seed 잔디 마스크를 셀룰러 오토마타로 응집시켜 *낱개 1×1 고립 금지 +
#   최소 유기 군락*을 강제한다. surf(0맨흙/1잔디/2+하드)에 in-place. 셀 단위(per-pixel 아님)·결정적.
#   ① CA 2패스: 잔디 8이웃<2 → 사멸(고립·촉수 제거) / 맨흙 8이웃≥5 → 잔디 생성(오목부 채움·응집).
#   ② 최소군락 필터: 잔디 4-연결 컴포넌트가 _G16_MIN_PATCH 미만이면 맨흙으로 흡수(작은 조각 제거).
const _G16_MIN_PATCH := 5      # 이보다 작은 잔디 덩어리는 맨흙으로 흡수(격자 스케일 노출 방지)
func _g16_cluster_cleanup(surf: Array) -> void:
	var W := _grid_w
	var H := _outdoor_h
	for _p in 2:
		var snap: Array = surf.duplicate(true)
		for y in H:
			for x in W:
				var s: int = snap[y][x]
				if s < 0 or s > 1:
					continue   # 맨흙(0)/잔디(1)만 대상 — 길·밭·물·건물 불변
				var gn := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < W and ny < H and int(snap[ny][nx]) == 1:
							gn += 1
				if s == 1 and gn < 2:
					surf[y][x] = 0
				elif s == 0 and gn >= 5:
					surf[y][x] = 1
	# 최소군락 필터(4-연결 BFS 컴포넌트 크기)
	var seen := {}
	for y in H:
		for x in W:
			if int(surf[y][x]) != 1 or seen.has(Vector2i(x, y)):
				continue
			var comp: Array = []
			var stack: Array = [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				comp.append(c)
				for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var n: Vector2i = c + d
					if n.x >= 0 and n.y >= 0 and n.x < W and n.y < H \
							and int(surf[n.y][n.x]) == 1 and not seen.has(n):
						seen[n] = true
						stack.append(n)
			if comp.size() < _G16_MIN_PATCH:
				for cc in comp:
					surf[cc.y][cc.x] = 0

# ★[ADR-0056 REV5 ②] 곡선 코너 PNG 이미지 캐시(id→Image) — 컨텍스트 필이 투명(물러난) 마스크를 읽는다.
var _corner_img_cache: Dictionary = {}
func _corner_img(id: int) -> Image:
	if _corner_img_cache.has(id):
		return _corner_img_cache[id]
	var img: Image = null
	if SOLID_TEX.has(id):
		img = (load(SOLID_TEX[id]) as Texture2D).get_image()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
	_corner_img_cache[id] = img
	return img

# 셀의 지면 표면 종류(0=맨흙 1=잔디 2=길 3=밭 4=물, -1=건물바닥 skip).
func _g16_surface(x: int, y: int) -> int:
	var c: int = _grid[y][x]
	if c == HOUSE or c == CAFE:
		return -1
	if c in CLIFF_TILES:
		return -1   # ★ 절벽 = 자체 SOLID_TEX로 렌더 → 오버레이 투명 통과(flip 리그레션 픽스, 안 그러면 tan이 덮어 절벽 사라짐)
	if c == PATH:
		return 2
	if c == SOIL:
		return 3
	if c == WATER:
		return 4
	# ★[ADR-0056 후속 — 절벽 top 연결] 하늘 목장(고지 평지 NW 사각)은 잔디-지배로 둔다 — 초록 lip과 이어져
	#   절벽 top이 tan 줄무늬 단절 없이 자연스럽게 연속(스타듀 elevated=grassy). 저지 마당만 흙-지배 flip
	#   (ADR-0053) 유지 → 목장=잔디 vs 농장=흙 대비. 건물 발치 tan 패드는 _build_ground16의
	#   _g16_near_building 오버라이드가 그대로 유지(surf=1이어도 발치는 tan으로 되돌림).
	if x <= HIGHLAND_E and y <= HIGHLAND_S:
		return 1
	# GROUND(및 벽/void — 프롭·facade가 덮음): 흙 베이스 + 잔디 패치(저지 마당 흙-지배)
	# ★[P2 프로토타입] 스타듀 농장 모델 — 채움 잔디 패치를 끄면(_G16_GRASS_PATCHES=false) 저지 마당은
	#   전부 tan(earth)이 되고, 초록은 _g16_blend_scatter의 오브젝트 데칼(잡초/tuft)로만 표현된다.
	if not _G16_GRASS_PATCHES:
		return 0
	return 1 if _g16_is_grass_patch(x, y) else 0

func _g16_field(s: int) -> Image:
	match s:
		1: return _bf_grass
		2: return _bf_dirt
		3: return _bf_soil
		4: return _bf_water
		_: return _bf_earth

# ★[ADR-0054 건물 접지 — 잔디억제 패드] 안식 농원 건물 footprint 목록(facade WALL 박스 + 비진입 사일로·우물).
#   발치 링을 맨흙으로 깔기 위한 기준. 문(door)은 별도로 PATH라 이 검사와 무관(성역화 = 남향 흙 진입로 유지).
const _G16_BUILD_PAD := 1   # footprint 바깥 몇 칸까지 맨흙 패드로 볼지(1 = 발치 한 겹)
const _HOME_BUILDING_RECTS: Array[Rect2i] = [
	HOUSE_EXT_RECT, STOREHOUSE_EXT_RECT, NEOKURITGAN_EXT_RECT, NEOKDUNGURI_EXT_RECT,
	SILO_EXT_RECT, WELL_RECT,
]

# 셀 (x,y)가 어느 건물 footprint의 발치 패드(rect를 _G16_BUILD_PAD칸 확장) 안인가.
func _g16_near_building(x: int, y: int) -> bool:
	var p := _G16_BUILD_PAD
	for r in _HOME_BUILDING_RECTS:
		if x >= r.position.x - p and x < r.end.x + p and y >= r.position.y - p and y < r.end.y + p:
			return true
	return false

func _build_ground_details() -> void:
	_ground_detail_tex = null
	var bw := _grid_w * TILE
	var bh := _outdoor_h * TILE
	if bw <= 0 or bh <= 0:
		return
	var out := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	# 현재 구역 PROP 점유 칸 회피(나무·바위·가구 위에 디테일 안 얹음)
	var occupied := {}
	for key in _REGION_PROP_KEYS.get(_region, []):
		for entry in _prop_layouts.get(key, []):
			for t in entry[1]:
				occupied[Vector2i(t.x, t.y)] = true
	var shadow := _gd_shadow()
	var sw := shadow.get_width()
	var sh := shadow.get_height()
	for y in range(_outdoor_h):
		for x in range(_grid_w):
			var terrain: int = _grid[y][x]
			if not _GD_TABLES.has(terrain):
				continue   # 디테일 테이블 없는 지형(밭·물·건물 등)
			if occupied.has(Vector2i(x, y)):
				continue
			# ★[owner Gemini 2차] 클러스터 게이트 — 풀(GROUND)은 저주파 노이즈 낮은 영역을 민무늬 베이스로
			#   비운다(스타듀식 80~90% 여백, 자글자글 제거). 길(PATH)은 자체 밀도라 게이트 안 함.
			if terrain == GROUND and _gd_cluster(x, y) < GD_CLUSTER_CUT:
				continue
			var table: Array = _GD_TABLES[terrain]
			var total := 0
			for e in table:
				total += int(e[1])
			var pick := int(_gd_h01(x, y, 2) * total)
			var acc := 0
			var chosen: Variant = null
			for e in table:
				acc += int(e[1])
				if pick < acc:
					chosen = e
					break
			if chosen == null or chosen[0] == null:
				continue   # 맨 타일(오버레이 없음)
			var ctex: Texture2D = chosen[0] as Texture2D
			var timg: Image
			if _GD_SOFT_SET.has(ctex):
				# ★[ADR-0042] 풀포기는 부드럽게 녹여 얹고, 결정적 해시로 좌우 반전 변종(반복 완화).
				timg = _gd_soft_image(ctex, _gd_h01(x, y, 5) < 0.5)
			else:
				timg = ctex.get_image()
				if timg.get_format() != Image.FORMAT_RGBA8:
					timg.convert(Image.FORMAT_RGBA8)
				if _GD_GRASS_MUTE.has(ctex):
					_mute_grass_pixels(timg)   # ★ non-soft 잔디 오버레이도 필드 톤에 맞춰 muted
			var dw := timg.get_width()
			var dh := timg.get_height()
			var jx := int((_gd_h01(x, y, 3) - 0.5) * 8)
			var jy := int((_gd_h01(x, y, 4) - 0.5) * 6)
			var px := x * TILE + (TILE - dw) / 2 + jx
			var py := y * TILE + (TILE - dh) + jy   # bottom-center 피벗
			if bool(chosen[2]):
				var sx := x * TILE + TILE / 2 + jx - sw / 2 + 1
				var sy := y * TILE + TILE - 1 + jy - sh / 2
				out.blend_rect(shadow, Rect2i(0, 0, sw, sh), Vector2i(sx, sy))
			out.blend_rect(timg, Rect2i(0, 0, dw, dh), Vector2i(px, py))
	_ground_detail_tex = ImageTexture.create_from_image(out)

# ── 구역 라벨(월드 좌표, 카메라 따라 스크롤) ──────────────────────────────
func _place_labels() -> void:
	# 집·카페는 도트 외관(간판·건물 형태)으로 식별되므로 라벨을 빼고, 아직 그레이박스인
	# 밭·도착·구역 동선 안내만 라벨로 남긴다(외관 위 텍스트 중복 제거).
	# ★ M1.4 — 구역마다 자기 라벨만 깐다(_rebuild_region이 전환 시 _clear_labels로 걷어낸다).
	match _region:
		RegionCatalog.HOME:
			# ★ADR-0035 Phase B — 스타터 패치(밭)·연못·고지(하늘 목장)·계단·overgrown을 새 좌표로 안내.
			_add_label("스타터 밭", _rect_center_px(STARTER_PATCH_RECT))
			_add_label("도착", Vector2(SPAWN_TILE.x * TILE + TILE * 0.5, (SPAWN_TILE.y - 1) * TILE))
			# ★C2 — 동쪽 길 워프(78,32) 안내 — 마을로 가는 길임을 그레이박스로 일러둔다.
			_add_label("나루 마을 →", _tile_center_px(Vector2i(74, 31)))
			_add_label("창고", _tile_center_px(Vector2i(30, 5)))   # ★ADR-0035 본가 왼쪽 창고 외관
			_add_label("영혼빛 연못", _tile_center_px(Vector2i(29, 41)))  # ★ADR-0035 연못(x26..33,y34..40) 아래
			_add_label("넋우릿간", _tile_center_px(Vector2i(4, 13)))    # ★[B1-a.1] 대형·안개소(고지 서편)
			_add_label("넋둥우리", _tile_center_px(Vector2i(10, 13)))   # ★[B1-a.1] 소형·노을닭(넋우릿간 동편)
			_add_label("혼우물(리필 예정)", _tile_center_px(Vector2i(41, 21)))  # ★[B2] 밭 남쪽 우물 아래(리필 메카닉=별도 grill)
			_add_label("계단(막힘 — 개간 후)", _tile_center_px(Vector2i(10, 33)))  # ★ADR-0035 계단 발치 debris 하드 게이트
		RegionCatalog.NARU_VILLAGE:
			# ★ M2.5 — 카페·메인 집 3(미호·멜·바나)은 도트 외관으로 식별되므로 라벨 없음(카페 컨벤션).
			# 아직 그레이박스인 동편(만물상·주민 집) + 워프(나룻터·산길·서워프) + 다리만 라벨로 식별.
			# ★C3 — 100×72 재배치에 맞춰 라벨도 새 건물·워프 위치로 옮긴다(외관 위·워프 가장자리 옆).
			_add_label("만물상", _tile_center_px(Vector2i(60, 12)))
			_add_label("주민 집", _tile_center_px(Vector2i(82, 12)))
			_add_label("주민 집", _tile_center_px(Vector2i(59, 42)))
			_add_label("주민 집", _tile_center_px(Vector2i(83, 42)))
			_add_label("다리", _tile_center_px(Vector2i(48, 34)))
			_add_label("← 안식 농원", _tile_center_px(Vector2i(4, 35)))   # 서워프(1,36) 안내
			_add_label("나룻터 → 삼도천", _tile_center_px(Vector2i(53, 3)))  # ★ M3.1 북동 나룻터(혼백관, 점등 — ★C3 52,1)
			_add_label("산길 → 업화 갱도", _tile_center_px(Vector2i(94, 17)))   # ★ M5.1 동 산길(정규 복원 — 갱도로 점등, ★C3 98,18)
		RegionCatalog.SAMDOCHEON:
			# ★ M3.1 / ★C4 — 혼백관은 그레이박스 WALL 박스라 라벨로 식별(만물상·창고 컨벤션). 강 낚시터·워프 안내(56×40).
			_add_label("혼백관", _tile_center_px(Vector2i(9, 13)))           # ★C4 외관(y14~19) 위
			_add_label("강 낚시터(Phase 3)", _tile_center_px(SAMDO_FISHING_LABEL_TILE))
			_add_label("나룻터 → 나루 마을", _tile_center_px(Vector2i(28, 37)))  # ★C4 남단 복귀 워프(28,39) 안내
			_add_label("하구 → 황천해", _tile_center_px(Vector2i(51, 20)))      # ★C4 동단 하구 워프(54,20) 안내
		RegionCatalog.HWANGCHEONHAE:
			# ★ M3.2 / ★C5 — 생선가게는 그레이박스 WALL 박스라 라벨로 식별. 부두·바다 낚시터·복귀 워프 안내(64×44).
			_add_label("생선가게", _tile_center_px(Vector2i(8, 7)))
			_add_label("부두", _tile_center_px(Vector2i(PIER_X, 24)))           # ★C5 부두 잔교(남측 바다 위) 안내
			_add_label("바다 낚시터(Phase 3)", _tile_center_px(SEA_FISHING_LABEL_TILE))
			_add_label("하구 → 삼도천", _tile_center_px(Vector2i(4, 15)))       # ★C5 서단 복귀 워프(1,15) 안내
		RegionCatalog.JEOSEUNG_FOREST:
			# ★ M4.1 / ★C6 — 목공방은 그레이박스 WALL 박스라 라벨로 식별. 채집지 3곳(빈터)·워프 안내(60×44).
			_add_label("목공방", _tile_center_px(Vector2i(9, 16)))
			_add_label("채집지(Phase 3)", _tile_center_px(FOREST_FORAGE_LABEL_TILE))
			_add_label("채집지(Phase 3)", _tile_center_px(FOREST_FORAGE_LABEL_TILE_2))
			_add_label("채집지(Phase 3)", _tile_center_px(FOREST_FORAGE_LABEL_TILE_3))
			_add_label("숲 안쪽 → 미혹의 숲", _tile_center_px(Vector2i(54, 22)))  # ★C6 동단 워프(58,22, 점등)
			_add_label("숲길 → 업화 갱도", _tile_center_px(Vector2i(30, 40)))   # ★C6 남단 숲길 워프(30,43, 점등)
		RegionCatalog.EOPHWA_MINE:
			# ★ ADR-0018 C8 — 대장간·길드는 그레이박스 WALL 박스라 라벨로 식별(목공방 컨벤션). 던전 입구·나락
			# 진입로는 잠긴 외관(비-enterable)이라 라벨로 위상 명시(옥자 집 컨벤션). 채광지 3·호수·두 워프 안내(64×44).
			_add_label("대장간", _tile_center_px(Vector2i(6, 36)))
			_add_label("모험가 길드", _tile_center_px(Vector2i(24, 36)))
			for ore in MINE_ORE_LABEL_TILES:
				_add_label("채광지(Phase 3)", _tile_center_px(ore))
			_add_label("호수", _tile_center_px(Vector2i(6, 24)))
			_add_label("던전 입구 (잠김 — 전투 Phase 3)", _tile_center_px(Vector2i(24, 8)))
			_add_label("나락 진입로 (잠김 — 전투 Phase 3)", _tile_center_px(Vector2i(32, 8)))
			_add_label("산길 → 나루 마을", _tile_center_px(Vector2i(14, 40)))   # 남단 산길 워프(14,43) 안내
			_add_label("숲길 → 저승 숲", _tile_center_px(Vector2i(40, 3)))       # 북단 숲길 워프(40,1) 안내
		RegionCatalog.NARAK:
			# ★ M5.2 — 독립 전투 던전 스테이지(헤드리스 빌드·검증). 인게임 진입은 잠긴 외관(업화 갱도)이라 없음.
			_add_label("나락 (전투 — Phase 3)", _tile_center_px(Vector2i(32, 18)))   # ★C9: 중앙 위(spawn 32,22 비껴감)
		RegionCatalog.MIHOK_FOREST:
			# ★ M4.2 / ★C7 — 옥자 집은 잠긴 외관(비-enterable)이라 라벨로 위상 명시(축사 컨벤션). 특수 채집지 2곳·연못·복귀 워프 안내.
			_add_label("옥자 집 (잠김 — 미결의 죄 해결 후)", _tile_center_px(Vector2i(57, 27)))  # ★C7 동쪽 깊은 끝
			_add_label("특수 채집지(Phase 3)", _tile_center_px(MIHOK_FORAGE_LABEL_TILE))
			_add_label("특수 채집지(Phase 3)", _tile_center_px(MIHOK_FORAGE_LABEL_TILE_2))
			_add_label("연못", _tile_center_px(Vector2i(31, 21)))            # ★C7 연못(x26..37,y14..19) 아래
			_add_label("숲 안쪽 → 저승 숲", _tile_center_px(Vector2i(4, 22)))   # ★C7 서단 복귀 워프(1,22) 안내

func _add_label(text: String, center_px: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(48, 12)
	lbl.position = center_px - Vector2(24, 6)
	lbl.z_index = 10
	add_child(lbl)
	_labels.append(lbl)   # M1.3 구역 전환 시 걷어낼 수 있게 추적

# M1.3 구역 전환 시 이전 구역 라벨을 걷어낸다(_rebuild_region에서 새로 깔기 전).
func _clear_labels() -> void:
	for l in _labels:
		l.queue_free()
	_labels.clear()

# ── 플레이어 스폰 + 추적 카메라 ───────────────────────────────────────────
func _setup_player_and_camera() -> void:
	player.position = _tile_center_px(SPAWN_TILE)
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = false  # 정수배 픽셀 크리스프 유지(ADR-0003)
	player.add_child(_cam)
	_cam.make_current()
	_apply_camera_limits()                   # 초기 외부 모드 경계

# 카메라 경계를 현재 모드(_indoor)에 맞춘다. 외부는 현재 구역(_region) 전체, 실내는 그 방 둘레만
# 비춘다 — 실내 모드에선 카메라가 방 밖(외부·다른 방·경계벽)을 비추지 못해 "건물 안"이 격리된다(방 밖은 VOID 검정).
# M1.2 — 외부(구역 레벨) 경계는 RegionCatalog.size_of(_region)에서 파생한다(안식 농원·나루 마을
# 둘 다 40×24 = MAP_W×OUTDOOR_H). 집(안식 농원)·카페(나루 마을) 실내는 방 둘레 rect(HOUSE/
# CAFE_CAM_RECT)로 격리한다 — 좌표가 두 구역에서 같아 _indoor 모드만으로 갈라도 안전하다(★ M1.4).
func _apply_camera_limits() -> void:
	var r := Rect2i(Vector2i.ZERO, RegionCatalog.size_of(_region))   # 외부 = 현재 구역 전체
	# ★ M2.2 — 실내면 그 건물의 방 둘레로 격리한다(카탈로그가 건물별 cam을 들고 있다 —
	# "집"→HOUSE_CAM·"카페"→CAFE_CAM·공유 집 6채→HOUSE_CAM·만물상→STORE_CAM, 한 데이터 흐름).
	if _indoor != "" and _buildings.has(_indoor):
		r = _buildings[_indoor]["cam"]
	_cam.limit_left = r.position.x * TILE
	_cam.limit_top = r.position.y * TILE
	_cam.limit_right = r.end.x * TILE
	_cam.limit_bottom = r.end.y * TILE

# ── P2.3③ 밤 라이팅 ────────────────────────────────────────────────────────
# CanvasModulate(화면 색조) + 소울 등불 자리 빛웅덩이를 월드 캔버스에 붙인다. 등불 위치는
# 현재 구역의 LANTERN_TILES_*(가구 그리기와 같은 출처)에서 픽셀 중심으로 환산해 그림과 빛을 한
# 자리에 둔다(★ M1.4 — 구역별 등불). 첫 색조는 즉시 적용해 부팅 첫 프레임부터 시각에 맞는 톤이 뜬다.
func _setup_lighting() -> void:
	lighting = DayNightLighting.new()
	add_child(lighting)
	_setup_region_lamps()
	lighting.apply(clock.minutes)

# ★ M1.4 — 현재 구역(_region)의 등불 자리만 빛웅덩이로 깐다(카페 이주로 등불이 구역마다 갈렸다).
# lighting.setup이 멱등이라(이전 등불 거두고 새로 깖) 구역 전환(_rebuild_region)마다 다시 부른다 —
# 안식 농원에선 길가 등불만, 나루 마을에선 카페 등불만 켜져 다른 구역 등불이 떠다니지 않는다.
# ★ M3.1 — 등불 없는 구역(삼도천 등)은 빈 목록 → 다른 구역 등불이 떠다니지 않는다(명시 분기·empty default).
func _setup_region_lamps() -> void:
	var tiles: Array = []
	match _region:
		RegionCatalog.HOME:
			tiles = LANTERN_TILES_HOME
		RegionCatalog.NARU_VILLAGE:
			tiles = LANTERN_TILES_CAFE
	var lamp_px := PackedVector2Array()
	for t in tiles:
		lamp_px.append(_tile_center_px(t))
	lighting.setup(lamp_px)

# ── P2.6 사운드 ────────────────────────────────────────────────────────────
# 오디오 노드를 코드로 붙이고(라이팅과 같은 결), 현재 시각에 맞는 BGM을 즉시 깐다.
# 이후엔 _process가 매 프레임 update_music으로 시간대 전환을 잇고, 각 이벤트 핸들러가
# audio.sfx(...)로 효과음을 쏜다. 음소거 토글(M)은 _ensure_input_actions가 등록한다.
func _setup_audio() -> void:
	audio = GameAudio.new()
	add_child(audio)
	audio.update_music(clock.minutes, _run_over, _in_cafe())

# ── ★ ADR-0024 핫바 HUD ───────────────────────────────────────────────────────
# 하단 12칸 슬롯 바를 CanvasLayer에 붙이고, 인벤토리와 작물 아이콘(CROP_SPRITES의 mature 프레임)을
# 주입한다. 씨앗·수확물은 이 작물 도트를 재사용해 그리고, 도구는 색박스(그레이박스). 인벤토리
# changed로만 다시 그린다(폴링 없이 디커플링). lighting·audio와 같은 결의 코드 생성 자식.
func _setup_hotbar() -> void:
	hotbar = HotbarHud.new()
	$CanvasLayer.add_child(hotbar)
	var icons := {}
	for crop_id in CROP_SPRITES:
		icons[crop_id] = CROP_SPRITES[crop_id][2]  # mature 프레임을 인벤 아이콘으로 재사용
	for extra_id in EXTRA_ICONS:
		icons[extra_id] = EXTRA_ICONS[extra_id]    # ★ [S1-10] 비-작물 수확물 아이콘(혼백도·노을알·안개젖)
	for tool_id in TOOL_ICONS:
		icons[tool_id] = TOOL_ICONS[tool_id]       # ★ [아트정리패스] 도구 아이콘(색박스 대체)
	for fert_id in FERT_ICONS:
		icons[fert_id] = FERT_ICONS[fert_id]       # ★ [아트정리패스] 비료 아이콘(색박스 대체)
	for sapling_id in SAPLING_ICONS:
		icons[sapling_id] = SAPLING_ICONS[sapling_id]   # ★ [아트정리패스] 묘목 아이콘(색박스 대체)
	hotbar.setup(inventory, icons)

# ── ★ C2 무인 출하함 ──────────────────────────────────────────────────────────
# wallet·inventory 결의 상태 노드(대기 재고 + 익일 정산)지만, lighting·hotbar처럼 코드로 붙인다
# (새 tscn 노드 추가 회피). 대기 내용은 main 세이브에 한 조각으로 직렬화된다(롤백·정산 보존).
func _setup_shipping_bin() -> void:
	ship_bin = ShippingBin.new()
	ship_bin.name = "ShippingBin"
	add_child(ship_bin)

# ── ★ ADR-0048 Phase D/E 저장 상자 ──────────────────────────────────────────────
# ship_bin과 같은 결의 상태 노드(집·창고 실내 순수 보관). 프레임(CTX_CHEST)이 참조하므로 프레임보다 먼저.
# ★ Phase E: 집 상자 + 갈무리방(창고) 상자 둘. 두 노드는 독립 보관(세이브 조각도 각각), 프레임은 여는
# 순간의 활성 상자(_active_chest)만 그린다(기본 = 집 상자).
func _setup_chest() -> void:
	chest = StorageChest.new()
	chest.name = "StorageChest"
	add_child(chest)
	storehouse_chest = StorageChest.new()
	storehouse_chest.name = "StorehouseChest"
	add_child(storehouse_chest)
	_active_chest = chest   # 기본 활성 = 집 상자(프레임 초기 참조와 정합)

# ── ★ ADR-0048 Phase D 설정(볼륨·전체화면) ──────────────────────────────────────
# GameSettings를 붙여 디스크에서 읽고 즉시 적용한다(버스 볼륨·창모드). 옵션 탭 조작은 프레임 신호로 받아
# 값 갱신→적용→영속한다(데이터/적용 디커플링 — GameSettings는 audio·DisplayServer를 모른다).
func _setup_settings() -> void:
	settings = GameSettings.new()
	settings.name = "GameSettings"
	add_child(settings)
	settings.load_settings()
	_apply_audio_volumes()
	_apply_fullscreen(settings.fullscreen)
	# 옵션 탭 설정 조작 신호(볼륨 −/+·전체화면 토글) — main이 실제 적용·영속을 수행.
	frame.music_vol_changed.connect(_on_music_vol_changed)
	frame.sfx_vol_changed.connect(_on_sfx_vol_changed)
	frame.fullscreen_toggled.connect(_on_fullscreen_toggled)

# 현재 설정 볼륨을 오디오 버스에 적용한다(음악·효과음 각 0..1 → dB, audio가 변환).
func _apply_audio_volumes() -> void:
	if audio == null or settings == null:
		return
	audio.set_music_volume(settings.music_volume)
	audio.set_sfx_volume(settings.sfx_volume)

# 창 ↔ 전체화면 적용(값→창모드). 실제 창 상태만 바꾸고 값은 GameSettings가 든다.
func _apply_fullscreen(on: bool) -> void:
	var win := get_window()
	win.mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED

# 옵션 탭 볼륨 −/+ 핸들러 — 값 증감 시에만 적용·영속(불필요한 IO 회피).
func _on_music_vol_changed(delta: float) -> void:
	if settings.nudge_music(delta):
		audio.set_music_volume(settings.music_volume)
		audio.sfx("ui")
		settings.save_settings()

func _on_sfx_vol_changed(delta: float) -> void:
	if settings.nudge_sfx(delta):
		audio.set_sfx_volume(settings.sfx_volume)
		audio.sfx("ui")   # 조정 즉시 효과음으로 새 볼륨을 들려준다
		settings.save_settings()

# 옵션 탭 전체화면 체크박스 핸들러 — 현재 창모드의 반대로 토글(F11과 같은 결·같은 값 원천).
func _on_fullscreen_toggled() -> void:
	var now_full := get_window().mode != Window.MODE_WINDOWED
	_apply_fullscreen(not now_full)
	if settings.set_fullscreen(not now_full):
		settings.save_settings()

# ── ★ C2 공통 인벤토리 프레임(메뉴/출하함/매대 컨텍스트 스위칭) ────────────────
# 하단 백팩 공통 + 상단 레이어 교체. 핫바와 같은 CanvasLayer에 핫바 *위*로 붙여(나중 자식) 열렸을
# 때 클릭을 가로챈다(모달). 출하함 드롭·롤백·구매는 시그널로 받아 main이 wallet·inventory를 조율한다.
# ★ Phase B — 전역 Panel 테마를 검정 panel_frame → 태운 한지(hanji_frame)로 바꾸면서
# (ui_theme.tres), 한지 위 라벨 대비를 위해 마일스톤·상점·카페정산 본문을 먹빛으로 준다.
# 전역 default_font_color를 바꾸면 어두운 월드 위 HUD 라벨(시계·골드)까지 어두워지므로 국소 처리.
# 대화창은 StyleBoxEmpty로 테마를 덮어 dialog_window를 따로 그리니 여기 대상이 아니다.
const HANJI_INK := Color(0.16, 0.12, 0.085)   # 먹빛(대화 본문 DLG_INK와 같은 톤)
func _skin_panel_text() -> void:
	# ★ Phase D — 엔딩 본문도 포함. 옛 엔딩은 어두운 ColorRect라 흰 글자였으나, 이제 밝은 한지 카드
	#   (EndingPanel/Card, 전역 Panel 테마 = hanji_frame) 위에 얹혀 먹빛이라야 읽힌다.
	for lb in [milestone_text, shop_text, cafe_summary_text, ending_text]:
		if lb != null:
			lb.add_theme_color_override("font_color", HANJI_INK)
	_skin_ending_button()

# ★ Phase D — 엔딩 "처음부터 다시 시작" 버튼을 한지 판(hanji_plate)으로 스킨한다(raw Godot 버튼 제거).
# HanjiUi.PLATE는 프레임·플레이트 9-slice의 단일 출처(규격 박제 — 같은 파일명 Gemini 결과로 무수정 교체).
func _skin_ending_button() -> void:
	if ending_restart == null:
		return
	var sb := StyleBoxTexture.new()
	sb.texture = HanjiUi.PLATE
	sb.set_texture_margin_all(HanjiUi.PLATE_MARGIN)
	for st in ["normal", "hover", "pressed", "focus"]:
		ending_restart.add_theme_stylebox_override(st, sb)
	ending_restart.add_theme_font_override("font", HanjiUi.font())
	ending_restart.add_theme_color_override("font_color", HanjiUi.INK)
	ending_restart.add_theme_color_override("font_hover_color", HanjiUi.GOLD)
	ending_restart.add_theme_color_override("font_pressed_color", HanjiUi.INK)

func _setup_frame() -> void:
	frame = InventoryFrame.new()
	$CanvasLayer.add_child(frame)
	var icons := {}
	for crop_id in CROP_SPRITES:
		icons[crop_id] = CROP_SPRITES[crop_id][2]   # 핫바와 같은 작물 아이콘 재사용
	for extra_id in EXTRA_ICONS:
		icons[extra_id] = EXTRA_ICONS[extra_id]     # ★ [S1-10] 비-작물 수확물 아이콘(혼백도·노을알·안개젖)
	for tool_id in TOOL_ICONS:
		icons[tool_id] = TOOL_ICONS[tool_id]        # ★ [아트정리패스] 도구 아이콘(색박스 대체)
	for fert_id in FERT_ICONS:
		icons[fert_id] = FERT_ICONS[fert_id]        # ★ [아트정리패스] 비료 아이콘(색박스 대체)
	for sapling_id in SAPLING_ICONS:
		icons[sapling_id] = SAPLING_ICONS[sapling_id]    # ★ [아트정리패스] 묘목 아이콘(색박스 대체)
	frame.setup(inventory, ship_bin, icons)
	frame.set_chest(chest)   # ★ Phase D 저장 상자 주입(CTX_CHEST 상단 그리드)
	frame.deposit_slot.connect(_on_frame_deposit)
	frame.takeback_id.connect(_on_frame_takeback)
	frame.buy_pressed.connect(_on_frame_buy)
	frame.save_pressed.connect(_on_frame_save)   # ★ Phase B 옵션 탭
	frame.quit_pressed.connect(_on_frame_quit)
	frame.chest_store.connect(_on_frame_chest_store)   # ★ Phase D 상자 보관
	frame.chest_take.connect(_on_frame_chest_take)     # ★ Phase D 상자 회수
	frame.profession_chosen.connect(_on_frame_profession)   # ★ ADR-0052 숙련 탭 전문직 선택

# ── ★ C3 미니멀 HUD 오버레이(좌하단 알림 피드 + 우하단 혼력 바) ─────────────────
# hotbar·frame과 같은 결 — 코드 생성 자식 Control(무상태). 프레임보다 *먼저* 붙여(앞 자식) 메뉴·
# 출하함·매대 모달이 열리면 그 위로 덮이게 한다(피드·혼력은 모달 백드롭 뒤로 어두워질 뿐 안 가린다).
func _setup_hud_overlays() -> void:
	notice_feed = NoticeFeed.new()
	notice_feed.name = "NoticeFeed"
	$CanvasLayer.add_child(notice_feed)
	notice_feed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notice_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals = VitalsHud.new()
	vitals.name = "VitalsHud"
	$CanvasLayer.add_child(vitals)
	vitals.setup(energy)
	# ★ Phase C 우상단 시계 클러스터(raw ClockLabel/GoldLabel/MilestoneLabel을 한지 플레이트로 통합).
	clock_hud = ClockHud.new()
	clock_hud.name = "ClockHud"
	$CanvasLayer.add_child(clock_hud)
	clock_hud.setup()
	# ★ Phase C 좌하단 컨텍스트 팝업(근처 NPC 초상화 + 한 줄 안내). 초상화는 대화창과 같은 매핑 재사용.
	context_popup = ContextPopup.new()
	context_popup.name = "ContextPopup"
	$CanvasLayer.add_child(context_popup)
	context_popup.setup()
	# ★ Phase C 마우스 호버 툴팁(핫바 슬롯 위 아이템명·품질). 핫바 슬롯 히트박스를 질의한다.
	hud_tooltip = HudTooltip.new()
	hud_tooltip.name = "HudTooltip"
	$CanvasLayer.add_child(hud_tooltip)
	hud_tooltip.setup(hotbar, inventory)
	# ★ owner 2026-07-03 — 상단-중앙 온보딩 안내 배너(옛 좌하단 wide notice 대체 · 잠깐 떴다 페이드).
	onboarding_banner = OnboardingBanner.new()
	onboarding_banner.name = "OnboardingBanner"
	$CanvasLayer.add_child(onboarding_banner)
	onboarding_banner.setup()
	# 실내 마스크는 *맨 앞 자식*(index 0)으로 — 월드 위에 깔리되 씬 패널(대화·페이드)·HUD보다 아래라
	# 방 바깥만 검게 가리고 그 위로 대화·HUD·페이드가 정상 표시된다.
	indoor_mask = IndoorMask.new()
	indoor_mask.name = "IndoorMask"
	$CanvasLayer.add_child(indoor_mask)
	$CanvasLayer.move_child(indoor_mask, 0)

# P2.6 BGM 위치 분기: 플레이어가 카페 안인가(밭↔카페 낮 BGM을 가른다). audio는 이 불리언만
# 받고 출처(지금=구역 판정, 나중=건물 내부 전환)는 모른다 — Phase 3 내부 전환이 와도 불변.
func _in_cafe() -> bool:
	return _zone_at(player.global_position) == "카페"

# ── T1.5 하루 사이클 ──────────────────────────────────────────────────────
func _setup_clock() -> void:
	# 24:00에 도달하면(쓰러짐) 위치에 상관없이 강제 취침시킨다.
	clock.collapsed.connect(_on_collapsed)
	# T2.3 취침으로 새 날이 시작되면 작물이 하루치 자란다(물 준 칸만). 시그널 디커플링.
	# T2.4 같은 훅에 혼력 회복도 나란히 붙는다(취침 시 가득).
	clock.day_advanced.connect(_on_day_advanced)

# 새 날 시작 → 밭 전체 하루 경과 처리 + 혼력 가득 회복.
# T3.4 여우불 성장 촉진(관계 보상형 A): 미호 호감도 하트가 높을수록 여우불 도움이
# 강해진다 — 물 준 칸이 더 빨리 자라고(가속) 물 못 준 칸도 돌본다(범위). 하트→세기
# 매핑은 Foxfire가 들고, farm은 그 값만 받아 적용한다(Affinity를 모름, 디커플링).
func _on_day_advanced(day: int) -> void:
	# T5.4 새 날 시작 시 카페 상태를 리셋한다(영업 중 잠들어 abandon한 경우 정리 —
	# 손님은 일시적이라 다음 영업창이 깨끗이 다시 연다, cafe.gd 세이브 무상태와 일관).
	cafe.end_day()
	# T6.3 밤 바도 리셋한다 — 옵트인을 꺼 다음 밤을 *새 선택*으로 돌린다(매일 세금 아님,
	# ADR-0010 #6). 옵트인한 채 자정 전에 잤어도 잡귀·약탈이 매일로 이월되지 않는다(손실 0).
	# 바를 열었던 밤이면 end_day가 정산 요약(closed → _on_night_closed)을 먼저 쏴, 옵트인의
	# 대가가 0이었음을 한 줄로 보인다(밤의 끝 = 취침이라 이 훅이 카페 19시 마감의 자리).
	night_bar.end_day()
	# ★ C2 무인 출하함 익일 정산: 어젯밤 출하함에 넣어 둔 수확물을 판매가로 환산해 골드로 정산하고
	# 상자를 비운다(즉시판매 제거 — 스타듀 출하상자 결, ADR-0021). ★ 이 raw 판매는 *카페를 운영한*
	# 매출이 아니라 마일스톤 누적(_cafe_revenue_total)엔 넣지 않는다(서빙 매출만 — ADR-0009).
	var ship_gold := ship_bin.settle()
	if ship_gold > 0:
		wallet.earn(ship_gold)
		audio.sfx("gold")                     # 출하 정산 골드 "치링"
		_notice("출하함 정산 +%d골드" % ship_gold)
	# T4.2 슬라이스의 끝. 취침으로 RUN_DAYS+1일째 아침이 오면 더 진행하지 않고(작물 성장·
	# 혼력 회복도 생략) 마무리 화면을 띄운다. 끝 판정은 RunSummary가 day로 내린다.
	if RunSummary.is_over(day):
		_end_run()
		return
	# ★ [ADR-0051] 밤 까마귀(미련까마귀) 습격 — 성장(advance_day) *전에* 무방비 작물을 영구 소실시킨다
	#   (밤새 쪼임 → 살아남은 작물만 아침에 자람). 허수아비 반경이 덮은 칸은 안전. 3중 안전장치
	#   (작물 문턱·한 밤 상한·반경 보호)는 CrowRaid가 판정하고, day 시드로 결정적이다(헤드리스 재현).
	var eaten := CrowRaid.resolve(farm.planted_tiles(), _scarecrow_tiles(), CrowRaid.BASE_RADIUS, day)
	for et in eaten:
		farm.remove_plant(et)                 # 작물만 제거·흙/비료 보존(tile_changed로 오버레이 갱신)
	if eaten.size() > 0:
		_notice("까마귀가 작물 %d개를 쪼아먹었다 — 허수아비로 막을 수 있다" % eaten.size())
	var h := affinity.hearts()
	farm.advance_day(Foxfire.accel(h), Foxfire.reach(h))
	orchard.advance_day(day)   # ★ [S1-5b] 성숙+제철 나무는 결실 +1(비제철 정지·영속). day는 무상태 절기 판정(ADR-0045)
	# ★ [B1-a.2] 밤 pathing 정산 — advance_day 정산 *전에* 방목 짐승을 자동 귀가시켜(penned) 격리 성공을
	#   확정하고, 문 닫혀 못 들어온 짐승은 실외 고립으로 남긴다(penned 미설정 → advance_day가 M_NIGHT_EXPOSED).
	var night := ranch.settle_night()
	if int(night.get("exposed", 0)) > 0:
		_notice("짐승 %d마리가 밖에 갇혔다 — 문을 열어 둬야 귀가한다" % int(night["exposed"]))
	ranch.advance_day()        # ★ [S1-7] 짐승 데일리 정산 — 케어 플래그로 우정·기분 갱신·산물 생성·플래그 리셋(§4.1)
	# ★ [B1-a.2] 새 아침 방목 방출 — advance_day가 플래그를 리셋한 *뒤*, 문 열린 건물 짐승을 방목지로 내보낸다
	#   (grazed=이번 새 날치). 평온·낮 게이트는 _release_open_buildings 안에서(_weather_calm 스텁=항상 평온).
	_release_open_buildings()
	# ★ [B1-a.3] 사료풀 재생 — 벤 지 REGROW_DAYS 지난 풀이 다시 자란다. 겨울(성야절)엔 재생 정지(Q7 굶음 긴장).
	forage.advance_day(day, GameClock.season_index_for_day(day) == 3)
	# ★ ADR-0052 꽃 패치 재생 — 딴 지 REGROW_DAYS 지난 패치가 다시 핀다(절기 무관 — 피안화는 저승 꽃).
	flower.advance_day(day)
	# ★ [ADR-0055] 안식 재점령 — 빈 맨땅 1~2칸에 밤새 잡초(이승의 미련)가 다시 돋는다(구조물·밭·작물 성역).
	#   겨울(잿눈)엔 정지(Forage와 같은 저승 성장정지). 자격 빈 맨땅 후보는 main이 계산해 전달(디커플링).
	if reclaim != null:
		var new_weeds := reclaim.advance_day(_encroach_candidates(), day, GameClock.season_index_for_day(day) == 3)
		if new_weeds.size() > 0 and not _hinted_encroach:
			_hinted_encroach = true          # 첫 재점령 1회만 멘토 힌트(봉인 법칙 — 순수 앰비언트, ADR-0055 §5)
			_notice("땅은 잠깐만 안 돌봐도 금세 거칠어진다 — 낫으로 잡초를 벨 수 있다")
	energy.refill()
	# T4.1 물 준 작물이 다 자라면 온보딩을 '수확하라' 단계로 넘긴다(그 단계일 때만).
	if farm.any_mature():
		onboarding.crop_ready()
	# M2.4 새 날이 이벤트 데이(2주마다)면 메인 4인 의상·카페 보너스를 켠다(아니면 끈다).
	_refresh_festival()

# ★ [ADR-0051] 배치된 허수아비의 보호 중심 칸 목록 — 밤 까마귀 판정(CrowRaid) 입력.
#   안식 농원 장식으로 세운 허수아비(_prop_layouts["HOME"]의 PROP_SCARECROW)가 곧 방어 인프라다
#   (보이는 아트 = 실제 보호). 스프라이트는 1×2칸(위→아래)이라, 말뚝 밑동(앵커+아래 1칸)을 반경 중심으로 쓴다.
func _scarecrow_tiles() -> Array:
	var out: Array = []
	for entry in _prop_layouts.get("HOME", []):
		if entry[0] == PROP_SCARECROW:
			for t in entry[1]:
				out.append(t + Vector2i(0, 1))
	return out

# ── M2.4 카페 이벤트 데이 ────────────────────────────────────────────────────
# 오늘(clock.day)이 이벤트 데이인가를 한 곳에서 파생해, 메인 4인(미호·멜·바나·옥자) 의상과
# 카페 손님 보너스를 그 상태로 맞춘다. Festival은 세이브 무상태(day에서 파생, store_discount
# 결)라 신규·복원·취침 어디서 불러도 멱등이다(set_festive·spawn_scale 모두 idempotent). 카페
# 축제 장식(가랜드·카펫)은 _draw가 같은 Festival.is_event_day로 파생하므로 여기선 redraw만 친다.
func _refresh_festival() -> void:
	var f := Festival.is_event_day(clock.day)
	miho.set_festive(f)
	mel.set_festive(f)
	bana.set_festive(f)
	okja.set_festive(f)
	cafe.spawn_scale = Festival.spawn_scale(clock.day)   # ★seam 3: 이벤트일 손님 붐빔(단가 불침범)
	queue_redraw()                                       # 카페 축제 장식(_draw)을 새 상태로 다시 그림

func _on_collapsed() -> void:
	_do_sleep()  # 어디서든 쓰러져 다음 날 아침으로

# ── ★ M2.2 건물 실내 카탈로그 ───────────────────────────────────────────────
# 각 건물(8채) 실내 데이터를 한 곳에 모은다 — region(어느 구역), ext_door(외관 문=진입 트리거),
# in_tile(진입 착지), out_tile(퇴장 착지=외관 문 앞), door(실내 문=퇴장 트리거), cam(실내 카메라
# 둘레), kind(house/cafe/store — 가구·서비스 분기용). 출입(_maybe_toggle_building)·카메라
# (_apply_camera_limits)·세이브 복원(_restore_location)이 모두 이 데이터로 굴러간다(하드코딩 제거).
# ★ 공유 집 실내: 메인 집 3 + 주민 집 3(HOUSE_IDS)은 한 방(HOUSE_RECT)을 공유한다 — in_tile·
#   door·cam은 같고 ext_door·out_tile만 건물마다 다르다(들어온 그 집으로 정확히 퇴장). 점유자
#   (주민 NPC)가 붙을 때 각 집이 자기 방을 갖는다("기존 집 에셋 재사용", 그레이박스 우선·ADR-0001).
func _build_building_catalog() -> void:
	_buildings = {}
	# 홈 집(유일하게 취침 가능 — _zone_at "집"). id·동작·카메라 불변(회귀 0).
	_buildings["집"] = {
		"region": RegionCatalog.HOME, "kind": "house",
		"ext_door": HOUSE_EXT_DOOR, "ext_door2": HOUSE_EXT_DOOR_E, "out_tile": HOUSE_OUT_TILE,
		# ★C2 — HOME 집 실내는 HOME 밴드 전용 좌표(마을 6채는 HOUSE_* 공유, 아래 루프).
		# ★[ADR-0046] 2칸 문 = ext_door2/door2로 양 칸 트리거 수용(진입·퇴장 어느 칸에서나).
		"in_tile": HOME_HOUSE_IN_TILE, "door": HOME_HOUSE_DOOR, "door2": HOME_HOUSE_DOOR_E, "cam": HOME_HOUSE_CAM_RECT,
	}
	# 나루 마을 카페(실데이터 실내 — 시뮬·NPC·좌석). id·동작·카메라 불변(회귀 0).
	_buildings["카페"] = {
		"region": RegionCatalog.NARU_VILLAGE, "kind": "cafe",
		"ext_door": CAFE_EXT_DOOR, "out_tile": CAFE_OUT_TILE,
		"in_tile": CAFE_IN_TILE, "door": CAFE_DOOR, "cam": CAFE_CAM_RECT,
	}
	# 나루 마을 만물상(전용 방 — 서비스는 다음 슬라이스, 지금은 enterable graybox).
	_buildings["만물상"] = {
		"region": RegionCatalog.NARU_VILLAGE, "kind": "store",
		"ext_door": STORE_EXT_DOOR, "out_tile": STORE_EXT_DOOR + Vector2i(0, 1),
		"in_tile": STORE_IN_TILE, "door": STORE_DOOR, "cam": STORE_CAM_RECT,
	}
	# ★ 안식 농원 창고(HOME 구역 — enterable 빈 방). kind="storehouse"라 가구 분기 미적용(빈 방).
	# 저장 메카닉은 후속, 지금은 들어갔다 나오는 그레이박스 방까지. 세이브는 이 dict로 자동 복원.
	_buildings["창고"] = {
		"region": RegionCatalog.HOME, "kind": "storehouse",
		"ext_door": STOREHOUSE_EXT_DOOR, "ext_door2": STOREHOUSE_EXT_DOOR_E, "out_tile": STOREHOUSE_EXT_DOOR + Vector2i(0, 1),
		"in_tile": STOREHOUSE_IN_TILE, "door": STOREHOUSE_DOOR, "door2": STOREHOUSE_DOOR_E, "cam": STOREHOUSE_CAM_RECT,
	}
	# ★ [B1-a.1] 동물 2건물(HOME 구역 — enterable). kind="barn"/"coop"이라 _draw 가구 분기 미적용(빈 방) —
	# 짐승은 _draw_ranch가 실내 타일에 그린다. 세이브·카메라·출입은 이 dict로 데이터 주도 자동(창고와 동형).
	_buildings["넋우릿간"] = {
		"region": RegionCatalog.HOME, "kind": "barn",
		"ext_door": NEOKURITGAN_EXT_DOOR, "ext_door2": NEOKURITGAN_EXT_DOOR_W, "out_tile": NEOKURITGAN_EXT_DOOR + Vector2i(0, 1),
		"in_tile": NEOKURITGAN_IN_TILE, "door": NEOKURITGAN_DOOR, "door2": NEOKURITGAN_DOOR_E, "cam": NEOKURITGAN_CAM_RECT,
	}
	_buildings["넋둥우리"] = {
		"region": RegionCatalog.HOME, "kind": "coop",
		"ext_door": NEOKDUNGURI_EXT_DOOR, "ext_door2": NEOKDUNGURI_EXT_DOOR_W, "out_tile": NEOKDUNGURI_EXT_DOOR + Vector2i(0, 1),
		"in_tile": NEOKDUNGURI_IN_TILE, "door": NEOKDUNGURI_DOOR, "door2": NEOKDUNGURI_DOOR_E, "cam": NEOKDUNGURI_CAM_RECT,
	}
	# ★ M3.1 삼도천 혼백관(SAMDOCHEON 구역 — enterable 빈 방). kind="museum"이라 가구 분기 미적용(빈 방).
	# 유품·기억 전시는 후속(서사 작업), 지금은 들어갔다 나오는 그레이박스 방까지. 세이브는 이 dict로 자동 복원.
	_buildings["혼백관"] = {
		"region": RegionCatalog.SAMDOCHEON, "kind": "museum",
		"ext_door": MUSEUM_EXT_DOOR, "out_tile": MUSEUM_EXT_DOOR + Vector2i(0, 1),
		"in_tile": MUSEUM_IN_TILE, "door": MUSEUM_DOOR, "cam": MUSEUM_CAM_RECT,
	}
	# ★ M3.2 황천해 생선가게(HWANGCHEONHAE 구역 — enterable 빈 방). kind="fishshop"이라 가구 분기 미적용(빈 방).
	# 도구·미끼·물고기 거래(윌리 대응)는 후속(낚시/아이템 시스템 의존), 지금은 들어갔다 나오는 그레이박스 방까지.
	_buildings["생선가게"] = {
		"region": RegionCatalog.HWANGCHEONHAE, "kind": "fishshop",
		"ext_door": FISHSHOP_EXT_DOOR, "out_tile": FISHSHOP_EXT_DOOR + Vector2i(0, 1),
		"in_tile": FISHSHOP_IN_TILE, "door": FISHSHOP_DOOR, "cam": FISHSHOP_CAM_RECT,
	}
	# ★ M4.1 저승 숲 목공방(JEOSEUNG_FOREST 구역 — enterable 빈 방). kind="woodshop"이라 가구 분기 미적용(빈 방).
	# 집·농장 업그레이드(로빈 대응)는 후속(아이템/업그레이드 시스템 의존), 지금은 들어갔다 나오는 그레이박스 방까지.
	_buildings["목공방"] = {
		"region": RegionCatalog.JEOSEUNG_FOREST, "kind": "woodshop",
		"ext_door": WOODSHOP_EXT_DOOR, "out_tile": WOODSHOP_EXT_DOOR + Vector2i(0, 1),
		"in_tile": WOODSHOP_IN_TILE, "door": WOODSHOP_DOOR, "cam": WOODSHOP_CAM_RECT,
	}
	# ★ M5.1 업화 갱도 대장간(EOPHWA_MINE 구역 — enterable 빈 방). kind="smithy"라 가구 분기 미적용(빈 방).
	# 업화로 도구·무기 벼림(클린트 대응)은 후속(도구/업그레이드 시스템 의존), 지금은 들어갔다 나오는 그레이박스 방까지.
	_buildings["대장간"] = {
		"region": RegionCatalog.EOPHWA_MINE, "kind": "smithy",
		"ext_door": SMITHY_EXT_DOOR, "out_tile": SMITHY_EXT_DOOR + Vector2i(0, 1),
		"in_tile": SMITHY_IN_TILE, "door": SMITHY_DOOR, "cam": SMITHY_CAM_RECT,
	}
	# ★ M5.1 업화 갱도 모험가 길드(EOPHWA_MINE 구역 — enterable 빈 방). kind="guild"라 가구 분기 미적용(빈 방).
	# 전투 장비 거래(말론 대응)는 후속(전투/아이템 시스템 의존, Phase 3), 지금은 들어갔다 나오는 그레이박스 방까지.
	_buildings["길드"] = {
		"region": RegionCatalog.EOPHWA_MINE, "kind": "guild",
		"ext_door": GUILD_EXT_DOOR, "out_tile": GUILD_EXT_DOOR + Vector2i(0, 1),
		"in_tile": GUILD_IN_TILE, "door": GUILD_DOOR, "cam": GUILD_CAM_RECT,
	}
	# 메인 집 3 + 주민 집 3 — 공유 집 실내(HOUSE_RECT). 외관 문은 건물마다, 실내는 한 방.
	var house_ext := {
		"미호집": MIHO_HOUSE_DOOR, "멜집": MEL_HOUSE_DOOR, "바나집": BANA_HOUSE_DOOR,
		"주민집1": RESIDENT_HOUSE_DOORS[0], "주민집2": RESIDENT_HOUSE_DOORS[1], "주민집3": RESIDENT_HOUSE_DOORS[2],
	}
	for id in house_ext:
		var ext: Vector2i = house_ext[id]
		_buildings[id] = {
			"region": RegionCatalog.NARU_VILLAGE, "kind": "house",
			"ext_door": ext, "out_tile": ext + Vector2i(0, 1),
			"in_tile": HOUSE_IN_TILE, "door": HOUSE_DOOR, "cam": HOUSE_CAM_RECT,
		}

# 현재 공유 집 실내에 들어와 있는가(나루 마을 6채 중 하나). _draw가 이때만 집 가구를 재사용해
# 그린다(만물상은 graybox·카페는 자기 무대 가구). 홈 집("집")은 _draw HOME 분기가 따로 그린다.
func _is_in_house_interior() -> bool:
	return _indoor in HOUSE_IDS

# ── 외부↔실내 건물 출입(fade 전환) ──────────────────────────────────────────
# 자동 출입: 외부에선 외관 문 칸에 닿으면 그 건물 실내로, 실내에선 방 문 칸에 닿으면 밖으로
# fade 전환한다(문에 닿으면 자동 — 스타듀식). 워프 직후 같은 문에서 곧장 되돌지 않게, 도착
# 칸을 문에서 한 칸 떨어뜨려 둔다(HOUSE_IN_TILE 등). 전환 중·취침 중엔 트리거하지 않는다.
# ★ M2.2 — 8개 건물 출입을 한 카탈로그 흐름으로. 바깥(_indoor=="")이면 현재 구역의 건물 중
# 외관 문(ext_door)에 닿은 것을 찾아 그 실내로(진입 칸 in_tile), 실내면 그 건물의 실내 문(door)에
# 닿으면 그 건물 외관 문 앞(out_tile)으로 전환한다. 공유 집 6채는 실내 문이 같아도(_indoor가
# 어느 집인지 기억하므로) 들어온 그 집 외관으로 정확히 나간다(out_tile이 건물마다 다름).
func _maybe_toggle_building() -> void:
	if _transitioning or _sleeping:
		return
	var t := _player_tile()
	if _indoor == "":
		for id in _buildings:
			var b: Dictionary = _buildings[id]
			# ★[ADR-0046] 2칸 문 = ext_door(대표칸) + ext_door2(있으면) 양 칸 트리거 수용.
			if b["region"] == _region and (t == b["ext_door"] or (b.has("ext_door2") and t == b["ext_door2"])):
				_transition_to(id, b["in_tile"])
				# ★ [S1-9 §11.6] 디제시스 최소 스텁 — 꾸며진 집에 들어오면 앰비언트 한 줄(관계 미터·버프 0,
				#   순수 감상). Slice 8 NPC/배우자 반응이 붙기 전의 자기완결 신호(CONTEXT '앰비언트 한정').
				if id == "집" and home_deco != null and home_deco.is_decorated():
					_notice("집이 아늑하다.")
				return
	elif _buildings.has(_indoor):
		var ib: Dictionary = _buildings[_indoor]
		if t == ib["door"] or (ib.has("door2") and t == ib["door2"]):   # ★[ADR-0046] 실내 문도 2칸 수용
			_transition_to("", ib["out_tile"])

func _player_tile() -> Vector2i:
	return Vector2i(int(player.global_position.x) / TILE, int(player.global_position.y) / TILE)

# M1.3 — 가장자리/길 워프(스타듀식 구역 전환). 외부에서 현재 구역의 워프 테이블
# (RegionCatalog.warps_of)을 훑어, 플레이어가 워프 발동 칸(at)에 닿으면 그 구역으로 전환한다.
# 문(건물 출입)과 같은 _warp 실행기를 쓰되 구역 자체가 바뀐다(문=구역 불변 특수 워프).
# ★ 가드: 목적 구역이 아직 안 지어졌으면(is_built=false) 발동하지 않는다 — M1.3에선 이웃이
#   다 stub이라 모든 가장자리 워프가 휴면이다(회귀 0). M1.4가 나루 마을을 지으면 자동으로 산다.
#   at이 아직 미정(TILE_TBD)인 워프도 건너뛴다(좌표 미정 = 무대 미완).
func _maybe_warp_edge() -> void:
	if _transitioning or _sleeping or _indoor != "":
		return
	var t := _player_tile()
	for w in RegionCatalog.warps_of(_region):
		if w["at"] == RegionCatalog.TILE_TBD or t != w["at"]:
			continue
		if not RegionCatalog.is_built(w["to"]):
			return   # 목적 구역 미완 → 휴면. M1.4에서 산다.
		_warp(w["to"], "", _warp_dest(w))
		return

# 워프 도착 칸: 워프가 dest를 명시했으면 그 칸, 아니면(TBD) 목적 구역의 기본 스폰으로 폴백.
# (도착 칸은 목적 구역이 지어져야 정해지므로, 그 전까진 구역 스폰이 안전한 기본값이다.)
func _warp_dest(w: Dictionary) -> Vector2i:
	var dest: Vector2i = w["dest"]
	return dest if dest != RegionCatalog.TILE_TBD else RegionCatalog.spawn_of(w["to"])

# M1.3 — 일반 워프 실행기. 검은 fade가 가장 어두운 순간에 (구역·실내 모드·플레이어 위치·
# 카메라)를 한 번에 바꾼다. 끊김이 안 보이는 취침 연출과 같은 fade 패턴(CanvasLayer라 카메라와
# 무관). 워프는 두 종류를 한 실행기로 다룬다:
#   · 건물 문(_transition_to) = 같은 구역 안 특수 워프(to_region == _region → 재빌드 없음, 실내 토글만).
#   · 가장자리/길 워프(_maybe_warp_edge) = 구역 자체 전환(to_region != _region → _rebuild_region).
# 구역 재빌드도 fade가 덮은 동안 일어나 새 맵이 깔리는 게 안 보인다(M1.2 구현 (b): 현재 구역만 메모리).
func _warp(to_region: String, new_indoor: String, dest_tile: Vector2i) -> void:
	if _transitioning:
		return
	_transitioning = true
	player.set_physics_process(false)  # 연출 중 이동 잠금
	player.velocity = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.22)
	tw.tween_callback(func() -> void:
		if to_region != _region:
			_rebuild_region(to_region)   # 구역 전환 = 새 구역 재빌드(그리드·페인트·라벨)
		_indoor = new_indoor
		player.position = _tile_center_px(dest_tile)
		_apply_camera_limits()
		queue_redraw())
	tw.tween_interval(0.08)
	tw.tween_property(fade, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func() -> void:
		_transitioning = false
		if not _run_over:
			player.set_physics_process(true))

# 건물 문 = 같은 구역 안의 특수 워프(구역 불변, 실내 모드만 토글). 기존 호출부(_maybe_toggle_
# building)·테스트(building_test)가 그대로 이 시그니처를 쓴다 — "문=특수 워프"(_warp에 위임).
func _transition_to(new_indoor: String, dest_tile: Vector2i) -> void:
	_warp(_region, new_indoor, dest_tile)

# M1.3 — 구역 전환 시 새 구역을 메모리에 빌드한다(M1.2 구현 (b): 현재 구역만 메모리, 전환 시 재빌드).
# 이전 구역의 타일·라벨을 걷어낸 뒤 _build/_paint/_place로 새로 깐다. 플레이어 위치·카메라는
# _warp이 이어서 잡는다(여기선 월드만 다시 세운다). fade가 덮은 어두운 순간에 호출돼 안 보인다.
# ★ M1.4 — 카페 이주로 이 경로가 인게임에서 살았다(안식 농원↔나루 마을 길 워프). 그리드·페인트·
#   라벨에 더해 (1) 밭 오버레이(field_layer)를 비웠다가 안식 농원으로 돌아오면 다시 칠하고,
#   (2) 등불을 현재 구역 자리로 다시 깐다 — 다른 구역의 작물·고랑·등불이 떠다니지 않게 한다.
#   NPC 가시성은 시각·구역에서 매 프레임 파생되므로(_update_miho_station 등) 여기서 손대지 않는다.
func _rebuild_region(to_region: String) -> void:
	_region = to_region
	ground.clear()
	field_layer.clear()                # 밭 오버레이는 안식 농원 전용 — 구역 전환 시 비운다
	_clear_labels()
	_build_grid()
	_paint_grid()
	_place_labels()
	_setup_region_lamps()              # 등불을 현재 구역 자리로 다시 깐다(멱등)
	# ★[§6] 구역이 바뀌면 Y-split 캐시를 무효화 → 다음 _process가 앞/뒤 프롭을 재분할(신선도 보장).
	_last_player_tile_y = -9999
	if _front_props != null:
		_front_props.queue_redraw()
	if to_region == RegionCatalog.HOME:
		_repaint_field_overlays()      # 안식 농원으로 복귀 → 밭 고랑·작물 오버레이 복원

# ★ M1.4 — 경작된 칸의 밭 오버레이(고랑·젖음·성장단계)를 field_layer에 다시 칠한다. 구역을
# 오갈 때 field_layer를 비웠으므로(다른 구역에 떠다니지 않게), 안식 농원으로 돌아오면 farm
# 상태에서 오버레이를 재구성한다(_load_game이 칸마다 tile_changed로 칠하는 것과 같은 결).
func _repaint_field_overlays() -> void:
	for t in farm.tilled_tiles():
		_on_tile_changed(t)

# 취침 가능 조건: 집 구역 안 + 연출 중이 아님. 그레이박스라 침대 오브젝트 없이
# '집에 있으면 잘 수 있다'로 단순화한다(에셋·가구는 Phase 2).
func _can_sleep() -> bool:
	return not _sleeping and _zone_at(player.global_position) == "집"

func _do_sleep() -> void:
	if _sleeping:
		return
	_sleeping = true
	clock.running = false
	audio.sfx("sleep")                 # P2.6 하루를 닫는 부드러운 하강 패드
	player.set_physics_process(false)  # 연출 중 이동 잠금
	player.velocity = Vector2.ZERO
	sleep_prompt.visible = false
	# 검은 화면으로 페이드 → 날짜 넘기기 → 다시 밝아짐. CanvasLayer라 카메라와 무관.
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.4)
	tw.tween_callback(clock.sleep)       # day +1, 06:00 리셋
	tw.tween_interval(0.3)
	tw.tween_property(fade, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_on_sleep_done)

func _on_sleep_done() -> void:
	_sleeping = false
	# T4.2 슬라이스가 끝났으면(이 취침이 RUN_DAYS+1일째를 불렀음) 이동 잠금을 풀지 않고
	# 마무리 화면을 유지한다. 진행은 보존하므로 다시 켜도 마무리 화면이 뜬다.
	if not _run_over:
		player.set_physics_process(true)
	# T2.5 스타듀식 자동 저장: 한 날이 끝나 잠들 때마다 진행을 보존한다.
	_save_game()

# ── T2.5 세이브/로드 조율 ──────────────────────────────────────────────────
# 각 시스템 노드는 자기 상태만 직렬화한다(단일 책임). main은 그 조각들을 모아
# SaveManager에 넘기고(파일 IO), 불러올 땐 받은 조각을 각 노드에 분배한다.
# T3.1 경제가 붙으며 "wallet"(골드)·"inventory"(수확물·씨앗) 두 조각이 추가됐다.
# SaveManager는 IO만 책임지므로 저장 항목이 늘어도 손대지 않는다(설계대로).
func _save_game() -> void:
	var data := {
		"clock": clock.to_save(),
		"energy": energy.to_save(),
		"farm": farm.to_save(),
		"orchard": orchard.to_save(),   # ★ [S1-5b] 심긴 혼의 나무(앵커·나이·결실). 영속·나이가 planted_day 파생이라 최소
		"ranch": ranch.to_save(),       # ★ [S1-7] 배치 짐승·우정·기분·대기 산물(데일리 돌봄 상태)
		"reclaim": reclaim.to_save(),   # ★ [S1-8] 개간한 debris 좌표 델타(치운 것만 — 배치는 layout.json 시드)
		"forage": forage.to_save(),     # ★ [B1-a.3] 사료풀 벤/재생 상태(여물광 건초 재고는 ranch에 포함)
		"flower_patch": flower.to_save(),  # ★ ADR-0052 꽃 패치 딴/재생 상태(배치는 layout.json 시드, 델타만)
		"home_deco": home_deco.to_save(),   # ★ [S1-9] 집 꾸미기 3레이어 배치 + 해금 세트(세이브별 코스메틱 델타)
		"wallet": wallet.to_save(),
		"inventory": inventory.to_save(),
		"shipping_bin": ship_bin.to_save(),   # ★ C2 출하 대기(롤백·익일 정산 보존)
		"chest": chest.to_save(),   # ★ Phase D 저장 상자 보관 내용(순수 보관 — 세이브별 델타)
		"storehouse_chest": storehouse_chest.to_save(),   # ★ Phase E 갈무리방(창고) 저장 상자(집 상자와 독립)
		"affinity": affinity.to_save(),
		"mel_affinity": mel_affinity.to_save(),
		"bana_affinity": bana_affinity.to_save(),
		"neo_affinity": neo_affinity.to_save(),   # M2.3 네오(만물상 점주) 호감도 — 매대 할인 파생원
		"onboarding": onboarding.to_save(),
		"run_harvested": _run_harvested,
		"farming_xp": _farming_xp,   # ★ S1-6 농사 숙련 XP(혼력 감산 파생원)
		"foraging_xp": _foraging_xp,   # ★ ADR-0052 채집 숙련 XP(전문직 게이트·퍼크 파생원)
		"professions": _professions_to_save(),   # ★ ADR-0052 전문직 선택 {skill:{tier:id}}
		"cafe_revenue_total": _cafe_revenue_total,
		"selected_crop": _selected_crop,
		# M1.5 — 현재 구역·실내 모드·플레이어 위치(껐다 켜도 '있던 자리'에서 재개). region은
		# 영문 id(RegionCatalog 키, 가볍고 안정적), indoor는 ""/건물 id(_buildings 키), 위치는 타일 좌표.
		# SaveManager는 IO만 책임지므로(불변) 세 키가 늘어도 손대지 않는다 — main이 조율한다.
		"region": _region,
		"indoor": _indoor,
		"player_tile": _player_tile(),
	}
	# ★ 활성 슬롯에 저장 + 코지 다이어리 메타(날짜·혼력) 헤더를 얹는다(타이틀 슬롯 UI가
	#   전체 로드 없이 [N년차 절기 D일 / 혼력]을 읽도록). meta는 SaveManager엔 불투명 blob.
	if saver.save_game(data, _active_slot, {"day": clock.day, "soul": energy.current}):
		_notice("저장됨")

func _load_game() -> void:
	var data := saver.load_game(_active_slot)
	if data.is_empty():
		return
	# 옛 오버레이를 먼저 비운다(F9 재로드 대비). 이후 FarmField.load_save가
	# 칸마다 tile_changed를 발화해 main이 새 상태로 다시 칠한다.
	field_layer.clear()
	if data.has("clock"):
		clock.load_save(data["clock"])
	if data.has("energy"):
		energy.load_save(data["energy"])
	if data.has("farm"):
		farm.load_save(data["farm"])
	if data.has("orchard"):   # ★ [S1-5b] — 키 없는 구버전 세이브는 나무 0으로 시작(changed가 밑동 충돌 재구성)
		orchard.load_save(data["orchard"])
	if data.has("ranch"):     # ★ [S1-7] — 키 없는 구버전 세이브는 짐승 0으로 시작(changed가 화면·HUD 갱신)
		ranch.load_save(data["ranch"])
	if data.has("reclaim"):   # ★ [S1-8] — 키 없는 구버전은 치운 것 0(전 debris 유지). changed가 드로우/충돌 skip 반영
		reclaim.load_save(data["reclaim"])
	if data.has("forage"):    # ★ [B1-a.3] — 키 없는 구버전은 사료풀 0(부팅 후 _seed_forage_tiles가 맵에서 시드). changed가 드로우 갱신
		forage.load_save(data["forage"])
	if data.has("flower_patch"):  # ★ ADR-0052 — 키 없는 구세이브는 딴 상태 0(부팅 후 _seed_flower_patches가 배치에서 시드). changed가 드로우 갱신
		flower.load_save(data["flower_patch"])
	if data.has("home_deco"):   # ★ [S1-9] — 키 없는 구버전은 배치·해금 0(빈 집). changed가 드로우 갱신
		home_deco.load_save(data["home_deco"])
	if data.has("wallet"):
		wallet.load_save(data["wallet"])
	if data.has("inventory"):
		inventory.load_save(data["inventory"])
	if data.has("shipping_bin"):   # ★ C2 — 키 없는 구버전 세이브는 빈 출하함으로 시작(롤백·정산 무상태)
		ship_bin.load_save(data["shipping_bin"])
	if data.has("chest"):   # ★ Phase D — 키 없는 구버전 세이브는 빈 상자로 시작(보관 무상태)
		chest.load_save(data["chest"])
	if data.has("storehouse_chest"):   # ★ Phase E — 창고 상자(키 없는 구버전 = 빈 상자)
		storehouse_chest.load_save(data["storehouse_chest"])
	if data.has("affinity"):
		affinity.load_save(data["affinity"])
	if data.has("mel_affinity"):
		mel_affinity.load_save(data["mel_affinity"])
	if data.has("bana_affinity"):
		bana_affinity.load_save(data["bana_affinity"])
	if data.has("neo_affinity"):   # M2.3 — 키 없는 구버전 세이브는 ♡0으로 시작(정가, 무막힘)
		neo_affinity.load_save(data["neo_affinity"])
	if data.has("onboarding"):
		onboarding.load_save(data["onboarding"])
	# T4.2 슬라이스 점수판 누적(거둔 영혼 총수). 손상 방어로 음수는 0으로 자른다.
	_run_harvested = maxi(int(data.get("run_harvested", 0)), 0)
	# ★ S1-6 농사 숙련 XP 복원(키 없는 구세이브는 0 = L0, 무막힘). 손상 방어로 음수는 0.
	_farming_xp = maxi(int(data.get("farming_xp", 0)), 0)
	# ★ ADR-0052 채집 숙련 XP·전문직 복원(키 없는 구세이브 = 0/미선택, 무막힘·정합 재검증은 _load_professions).
	_foraging_xp = maxi(int(data.get("foraging_xp", 0)), 0)
	_load_professions(data.get("professions", {}))
	# T7.2 카페 마일스톤 누적 서빙 매출. 손상 방어로 음수는 0으로 자른다(키 없는 구버전 세이브는 0).
	_cafe_revenue_total = maxi(int(data.get("cafe_revenue_total", 0)), 0)
	var sel: String = data.get("selected_crop", CropCatalog.HONRYEONGCHO)
	_selected_crop = sel if CropCatalog.has_crop(sel) else CropCatalog.HONRYEONGCHO
	# M1.5 — 마지막에 구역·실내 모드·위치를 되돌린다. farm.load_save가 칸마다 발화한 밭
	# 오버레이는 안식 농원 기준이라, 복원 구역이 다르면 _rebuild_region이 걷어내고(현재 구역만
	# 그림) 같으면 그대로 둔다 — 그래서 farm 복원 뒤에 둔다(_save_game의 짝).
	_restore_location(data)
	# M2.4 F9 재로드(이 함수 직접 호출 경로)에서도 복원된 day로 의상·보너스를 맞춘다(멱등).
	_refresh_festival()
	_notice("불러옴")

# M1.5 — 세이브된 현재 구역·실내 모드·플레이어 위치를 복원한다. SaveManager는 IO만 책임지므로
# (불변), '무엇을 어떻게 되돌리나'의 조율은 main이 맡는다(_save_game·_warp과 같은 결).
# 부팅 기본은 _region=HOME·SPAWN_TILE 외부(이미 _build_grid·_setup_player_and_camera가 깖)라,
# 복원은 그 위에 (a) 저장 구역이 다르면 _rebuild_region, (b) 실내 모드·위치·카메라를 얹는다.
# ★ 미지 구역 폴백: 저장된 구역 id가 (안 지어졌거나 알 수 없어) is_built=false면 홈베이스(안식
#   농원) 외부 스폰으로 떨군다 — 깨진/구버전 세이브로 빈 맵·VOID에 갇히지 않게(미지 id 방어).
func _restore_location(data: Dictionary) -> void:
	var saved_region: String = str(data.get("region", RegionCatalog.HOME))
	if not RegionCatalog.is_built(saved_region):
		push_warning("[M1.5] 미지/미빌드 구역 '%s' — 홈베이스 스폰으로 폴백" % saved_region)
		if _region != RegionCatalog.HOME:
			_rebuild_region(RegionCatalog.HOME)
		_indoor = ""
		player.position = _tile_center_px(SPAWN_TILE)
		_apply_camera_limits()
		return
	# 정상 복원: 저장 구역이 부팅 구역(HOME)과 다르면 그 구역을 재빌드한다(_warp과 같은 결 —
	# 현재 구역만 메모리, M1.2 구현 (b)). 같으면(HOME) 이미 빌드돼 있어 재빌드 불필요.
	if saved_region != _region:
		_rebuild_region(saved_region)
	# 실내 모드는 카탈로그로 방어한다(★ M2.2 — 8채로 늘어 화이트리스트 대신 _buildings 조회).
	# 알 수 없는 id거나 복원 구역과 다른 구역의 건물이면 바깥("")으로 — 카메라가 외부 경계로
	# 안전 복귀(예: region=홈인데 indoor=만물상 같은 손상/구버전 세이브로 격리방에 갇히지 않게).
	var saved_indoor: String = str(data.get("indoor", ""))
	if saved_indoor != "" and _buildings.has(saved_indoor) and _buildings[saved_indoor]["region"] == saved_region:
		_indoor = saved_indoor
	else:
		_indoor = ""
	# 위치 복원(저장 타일 중심). 손상 방어 — Vector2i가 아니면 구역 스폰으로(빈 맵 방지).
	var saved_tile := RegionCatalog.spawn_of(saved_region)
	var raw_tile: Variant = data.get("player_tile", saved_tile)
	if typeof(raw_tile) == TYPE_VECTOR2I:
		saved_tile = raw_tile
	player.position = _tile_center_px(saved_tile)
	_apply_camera_limits()

# ★ C3 — 일시 이벤트 한 줄을 좌하단 알림 피드(큐)에 민다(저장됨·서빙·약탈·사연 한 줄 등).
# 저장됨 등은 짧게(NOTICE_SECS), T3.5 사연 한 줄은 읽을 수 있게 길게(FLAVOR_SECS). 피드가 스스로
# 시간 경과로 흐려지며 사라지므로(상시 라벨 폐기), 여기선 한 줄을 밀어 넣기만 한다.
func _notice(msg: String, secs: float = NOTICE_SECS, wide: bool = false) -> void:
	if notice_feed != null:
		notice_feed.push(msg, secs, wide)

# ★ Phase C — 아이템 획득 토스트(좌하단 알림에 아이콘+이름 +수량). 게임플레이 획득 지점(수확·수집·
# 개간 드랍)에서만 부른다 — 세이브 로드·구매·회수는 각자 알림/무알림이라 이중 토스트·로드 스팸 회피.
func _toast_item(id: String, n: int) -> void:
	if notice_feed == null or n <= 0 or not ItemCatalog.has_item(id):
		return
	notice_feed.push("%s +%d" % [ItemCatalog.name_of(id), n], 2.2, false, _item_icon(id))

# 아이템 아이콘(토스트·툴팁 공용) — 작물군(수확물·씨앗)은 mature 스프라이트 재사용, 그 외(과일·산물·
# 재료·도구)는 그레이박스라 스프라이트 없음 → null(텍스트만). 핫바 _draw_icon과 같은 매핑 결.
func _item_icon(id: String) -> Texture2D:
	var crop := ""
	match ItemCatalog.category_of(id):
		ItemCatalog.CAT_HARVEST:
			crop = id
		ItemCatalog.CAT_SEED:
			crop = ItemCatalog.crop_of(id)
	if crop != "" and CROP_SPRITES.has(crop):
		return CROP_SPRITES[crop][2]
	if crop != "" and EXTRA_ICONS.has(crop):   # ★ [S1-10] 비-작물 수확물(혼백도·노을알·안개젖)
		return EXTRA_ICONS[crop]
	if TOOL_ICONS.has(id):                     # ★ [아트정리패스] 도구 아이콘(토스트·알림에서 텍스트→아이콘)
		return TOOL_ICONS[id]
	if FERT_ICONS.has(id):                     # ★ [아트정리패스] 비료 아이콘(토스트·알림)
		return FERT_ICONS[id]
	if SAPLING_ICONS.has(id):                  # ★ [아트정리패스] 묘목 아이콘(토스트·알림)
		return SAPLING_ICONS[id]
	var base := ItemCatalog._large_base(id)    # 대형 산물(_large)이면 기준 산물 아이콘 재사용
	if base != "" and EXTRA_ICONS.has(base):
		return EXTRA_ICONS[base]
	return null

# ★ Phase C — 농사 XP 적립 + 레벨업 감지(숙련 알림). _farming_xp를 직접 더하던 자리를 이 헬퍼로
# 감싸, 더하기 전후 FarmSkill.level_for_xp를 비교해 레벨이 오른 순간만 금박 알림을 띄운다(래치 불요 —
# 경계를 넘는 프레임에만 after>before). 숙련 탭(관계 탭과 대칭)에 진행은 상시 파생되므로 여기선 알림만.
func _gain_farm_xp(amount: int) -> void:
	if amount <= 0:
		return
	var before := FarmSkill.level_for_xp(_farming_xp)
	_farming_xp += amount
	var after := FarmSkill.level_for_xp(_farming_xp)
	if after > before and notice_feed != null:
		notice_feed.push("숙련 ▲ 농사 Lv %d" % after, 4.0, false, null, true)  # gold=금박 강조
		audio.sfx("ui")

# ★ ADR-0052 그레이박스 — 채집 XP 적립 + 레벨업 감지(_gain_farm_xp 대칭). 라이브 채집 루프(숲·
# 야생씨앗)가 붙으면 그 산출 지점에서 호출(현재 프레임워크 우선이라 소스 미배선 — 테스트가 직접 구동).
func _gain_forage_xp(amount: int) -> void:
	if amount <= 0:
		return
	var before := FarmSkill.level_for_xp(_foraging_xp)
	_foraging_xp += amount
	var after := FarmSkill.level_for_xp(_foraging_xp)
	if after > before and notice_feed != null:
		notice_feed.push("숙련 ▲ 채집 Lv %d" % after, 4.0, false, null, true)
		audio.sfx("ui")

# ── ADR-0052 전문직 선택·조회 API ──────────────────────────────────────────────
# 스킬의 현재 레벨(FarmSkill 곡선 공유). 채집·농사만 XP 소스 존재, 나머지는 0(각 슬라이스에서 XP 배선).
func _skill_level(skill: String) -> int:
	match skill:
		ProfessionCatalog.FARMING: return FarmSkill.level_for_xp(_farming_xp)
		ProfessionCatalog.FORAGING: return FarmSkill.level_for_xp(_foraging_xp)
		_: return 0

# (skill,tier)에 이미 고른 전문직 id("" = 미선택).
func _profession_at(skill: String, tier: int) -> String:
	return String(_professions.get(skill, {}).get(tier, ""))

func has_profession(skill: String, prof_id: String) -> bool:
	var chosen: Dictionary = _professions.get(skill, {})
	for tier in chosen:
		if chosen[tier] == prof_id:
			return true
	return false

# 선택 유효성: ①실존 전문직 ②스킬 레벨 ≥ tier(5/10 게이트, "평평≠막힘"과 별개 — 이건 곱셈 편의 해금)
# ③해당 tier 슬롯 비어있음(재선택 금지 — 스타듀는 책으로만 변경, 그레이박스는 1회) ④tier10은 부모 lvl5 선택됨.
func _can_choose_profession(skill: String, prof_id: String) -> bool:
	if not ProfessionCatalog.is_valid(skill, prof_id):
		return false
	var tier := ProfessionCatalog.tier_of(skill, prof_id)
	if _skill_level(skill) < tier:
		return false
	if _profession_at(skill, tier) != "":
		return false
	if tier == 10:
		var parent := ProfessionCatalog.requires_of(skill, prof_id)
		if _profession_at(skill, 5) != parent:
			return false
	return true

# 전문직 선택(유효하면 슬롯 세팅 후 true). UI/테스트가 호출.
func choose_profession(skill: String, prof_id: String) -> bool:
	if not _can_choose_profession(skill, prof_id):
		return false
	var tier := ProfessionCatalog.tier_of(skill, prof_id)
	if not _professions.has(skill):
		_professions[skill] = {}
	_professions[skill][tier] = prof_id
	if notice_feed != null:
		notice_feed.push("전문직 ▲ %s" % ProfessionCatalog.name_of(skill, prof_id), 4.0, false, null, true)
		audio.sfx("ui")
	return true

# 지금 고를 수 있는 tier(5 또는 10, 없으면 0) — UI 배지·온보딩용. 레벨 도달·슬롯 빔·부모 충족 판정.
func _pending_profession_tier(skill: String) -> int:
	for tier in [5, 10]:
		for p in ProfessionCatalog.tier_profs(skill, tier):
			if _can_choose_profession(skill, p["id"]):
				return tier
	return 0

# 선택한 전문직들의 퍼크에서 dim의 값(여럿이면 max). 로더(loop)가 base 위에 얹을 때 읽는다. ADR-0052
# 비-가치 차원만 존재(+판매가/마진은 여기 없음 — 관계 곱셈기 전용). 미선택/미배선이면 default_val.
func _perk_value(skill: String, dim: String, default_val: float) -> float:
	var best := default_val
	var chosen: Dictionary = _professions.get(skill, {})
	for tier in chosen:
		for perk in ProfessionCatalog.perks_of(skill, String(chosen[tier])):
			if perk["dim"] == dim:
				best = maxf(best, float(perk["value"]))
	return best

# 편의 조회(채집 파일럿) — 라이브 루프가 호출할 인터페이스. 약초학자 → Q_IRIDIUM, 채집꾼 → 0.20 등.
func forage_quality_floor() -> int:
	return int(_perk_value(ProfessionCatalog.FORAGING, ProfessionCatalog.DIM_QUALITY_FLOOR, 0.0))

func forage_double_drop_chance() -> float:
	return _perk_value(ProfessionCatalog.FORAGING, ProfessionCatalog.DIM_DOUBLE_DROP, 0.0)

# ★ ADR-0052 채집물 기본 품질(채집 레벨 → 등급). 스타듀 결(레벨이 오를수록 상위 등급) 결정적 그레이박스
#   버전: L0~3 일반 / L4~6 은 / L7+ 금. 이리듐(최고)은 base로 안 나오고 약초학자 전문직 하한으로만
#   닿는다(ADR-0052 §채집 "약초학자 → 이리듐 고정" — 퍼크가 의미를 갖게). _pick_flower가 하한과 max.
func _forage_base_quality(level: int) -> int:
	if level >= 7:
		return ItemCatalog.Q_GOLD
	if level >= 4:
		return ItemCatalog.Q_SILVER
	return ItemCatalog.Q_NORMAL

# 세이브 직렬화 — _professions를 {skill: {tier: id}} 그대로(var_to_str가 중첩 dict/int키 왕복). 로드 시
# 카탈로그로 재검증해 손상/구버전 잔여를 버린다(유효 전문직만 복원, tier/부모 정합).
func _professions_to_save() -> Dictionary:
	return _professions.duplicate(true)

func _load_professions(raw) -> void:
	_professions = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for skill in raw:
		if not (skill is String) or typeof(raw[skill]) != TYPE_DICTIONARY:
			continue
		for tier in raw[skill]:
			var pid := String(raw[skill][tier])
			var t := int(tier)
			# 유효성: 실존·tier 일치. tier10 부모 정합은 아래 2패스로(부모 먼저 실릴 수 있게).
			if ProfessionCatalog.is_valid(skill, pid) and ProfessionCatalog.tier_of(skill, pid) == t:
				if not _professions.has(skill):
					_professions[skill] = {}
				_professions[skill][t] = pid
	# 2패스: tier10인데 부모 lvl5가 세이브에 없거나 불일치면 폐기(정합 보장).
	for skill in _professions.keys():
		var slots: Dictionary = _professions[skill]
		if slots.has(10):
			var parent := ProfessionCatalog.requires_of(skill, String(slots[10]))
			if String(slots.get(5, "")) != parent:
				slots.erase(10)

# ★ Phase C — NPC idle 초상화(컨텍스트 팝업용). 대화창과 같은 PORTRAIT 매핑을 쓰되 표정 없는 기본
# 얼굴(stem.png)을 로드해 캐시한다(매 프레임 load 회피). 초상화 없는 인물(네오)은 null(팝업은 이름만).
var _idle_portrait_cache: Dictionary = {}
func _idle_portrait(speaker: String) -> Texture2D:
	if _idle_portrait_cache.has(speaker):
		return _idle_portrait_cache[speaker]
	var stem: String = PORTRAIT_STEM.get(speaker, "")
	var tex: Texture2D = null
	if stem != "":
		var path := PORTRAIT_DIR + stem + ".png"
		if ResourceLoader.exists(path):
			tex = load(path)
	_idle_portrait_cache[speaker] = tex
	return tex

# 컨텍스트 팝업 관계 한 줄 — 하트 수(♥ 글리프는 폰트 리스크라 텍스트로). 호감도 없는 인물은 별도 문구.
func _rel_line(aff: Affinity) -> String:
	return "친밀도 %d/%d" % [aff.hearts(), Affinity.MAX_HEARTS]

# F8 세이브 삭제+새 시작의 2단 확인. 비무장이면 무장만 하고 안내를 띄운다(실수로 한 번
# 누른 것으로 진행을 날리지 않게). 무장(DELETE_CONFIRM_SECS 안) 중에 또 누르면 실행한다.
func _arm_or_confirm_delete() -> void:
	if _delete_armed_secs > 0.0:
		_delete_save_and_restart()
	else:
		_delete_armed_secs = DELETE_CONFIRM_SECS
		_notice("한 번 더 [F8]: 세이브 삭제 후 새로 시작", DELETE_CONFIRM_SECS)

# 세이브를 지우고 씬을 다시 로드해 즉시 새 게임으로 시작한다. 세이브가 사라졌으므로 새
# 씬의 _ready가 자동 복원 없이 옥자 오프닝 통보부터 다시 연다(README의 "지우고 재실행"을
# 게임 안에서 한 키로). reload_current_scene은 프레임 끝에 안전하게 처리된다.
func _delete_save_and_restart() -> void:
	saver.delete_save(_active_slot)
	get_tree().reload_current_scene()

func _process(delta: float) -> void:
	# P2.3③ 밤 라이팅: 시각으로 화면 색조·등불 세기를 매 프레임 잇는다(연속 보간이라 부드럽게
	# 흐른다). 입력 가드보다 먼저 둬, 대화·정산 패널 뒤로 보이는 월드도 밤이면 밤으로 유지된다.
	# 취침 연출 중엔 시간이 멈춰(clock.running=false) 색조도 자연히 정지하고, 검은 페이드가 덮는다.
	lighting.apply(clock.minutes)
	# P2.6 BGM: 시각·종료·위치(카페 안인가)에서 phase(밭/카페/밤/엔딩)를 파생해 BGM을 잇는다
	# (같은 phase면 즉시 반환, 라이팅과 같은 무상태 결). 시각이 멈춘 취침 연출 중에도 위치는
	# 잠겨 있어(이동 잠금) phase가 안정적이다.
	audio.update_music(clock.minutes, _run_over, _in_cafe())
	# ★[asset-ruleset §6] Y-split 재분할 — 플레이어가 타일 행을 넘을 때만 앞/뒤 프롭을 다시 그린다
	#   (매 프레임 아님·값쌈). HOME 야외에서만 의미(다른 구역은 _draw_props_for가 PASS_ALL로 전부 그림).
	if _region == RegionCatalog.HOME and player != null:
		var _pty := int(player.global_position.y) / TILE
		if _pty != _last_player_tile_y:
			_last_player_tile_y = _pty
			queue_redraw()
			if _front_props != null:
				_front_props.queue_redraw()
		_update_tree_fade(delta)   # ★[roster] 수관 뒤 캐릭터 occlusion fade(행 넘김과 별개 — 매 프레임 부드럽게)
	# 음소거 토글(M) — 연출·대화·마무리 화면 어디서든 받는다(입력 가드보다 위, UX 토글이라
	# 게임 상태와 무관). audio가 Music·SFX 버스를 함께 음소거한다.
	if Input.is_action_just_pressed("mute_audio"):
		audio.toggle_mute()
	# 전체화면 토글(F11) — 음소거와 같은 결로 입력 가드보다 위에서 어디서든 받는다.
	if Input.is_action_just_pressed("toggle_fullscreen"):
		_toggle_fullscreen()
	# ★ ADR-0025 ① 배치 모드 토글(F10, 디버그/에디터 전용 — 패널 버튼과 같은 가드). 맥은 fn+F10.
	if OS.is_debug_build() and Input.is_action_just_pressed("place_mode"):
		_toggle_edit_mode()
	# 배치 모드 ON이면 게임플레이 입력·시뮬 스텝을 멈춘다(저작 전용 — 시계·이동 정지). 마우스 드래그·
	# 단축키는 _unhandled_input이 처리하고, 오버레이는 _draw가 그린다. queue_redraw로 갱신 유지.
	if _edit_mode:
		queue_redraw()
		return
	# ★ [S1-9] 집 꾸미기 모드 토글(C) — 집 실내("집")에서만. 켜면 게임플레이 입력·시뮬을 멈추고(코스메틱
	#   저작 전용, 배치 모드와 같은 결) 마우스·키로 3레이어를 꾸민다. 나가면 다시 게임(멱등 토글).
	if Input.is_action_just_pressed("deco_mode") and (_deco_mode or _can_deco()):
		_toggle_deco_mode()
	if _deco_mode:
		queue_redraw()
		return
	# ★ 상시 HUD(우하단 혼력 바·하단 핫바)는 런타임 add_child라 씬 패널(대화·정산·마일스톤·마무리)
	# 보다 위에 그려진다 → 그 패널들이 하단을 덮을 때 겹쳐 보였다(스크린샷 버그 — 대화창·초상화가
	# 핫바를, 정산창이 혼력 바를 덮음). 모달/패널이 열린 동안 둘 다 숨겨 안 겹치게 한다(상시 HUD는
	# 패널 밖에서만 — 미니멀 결). _process가 가시성 단일 출처라 _open/_close_frame의 hotbar 토글과
	# 일관(프레임 열림도 아래 조건에 포함).
	var _hud_hidden := dialogue.is_open() or frame.is_open() or _sleeping \
		or cafe_summary_panel.visible or milestone_panel.visible or ending_panel.visible
	if vitals != null:
		vitals.visible = not _hud_hidden
	if hotbar != null:
		hotbar.visible = not _hud_hidden
	# ★ Phase C — 시계 클러스터·컨텍스트 팝업·툴팁도 상시 HUD라 모달/대화/정산 뒤로 숨긴다(겹침 방지·
	#   대화창 초상화와 컨텍스트 팝업 중복 회피). notice_feed는 정산 알림을 계속 보여야 해 제외(기존 결).
	if clock_hud != null:
		clock_hud.visible = not _hud_hidden
	if context_popup != null:
		context_popup.visible = not _hud_hidden
	if hud_tooltip != null:
		hud_tooltip.visible = not _hud_hidden
	# ★ 실내 카메라 격리 마스크 — 실내일 때 방(cam rect) 바깥을 검정으로 가린다(외부 풀밭·이웃 방
	# 누출 차단, 코지-와이드 회귀 수정). 카메라가 방을 따라 움직일 수 있어 매 프레임 방 rect를 주입해
	# 다시 그린다. 외부면 active=false라 아무것도 안 그린다.
	if indoor_mask != null:
		if _indoor != "" and _buildings.has(_indoor):
			var cr: Rect2i = _buildings[_indoor]["cam"]
			indoor_mask.set_room(true, Rect2(cr.position.x * TILE, cr.position.y * TILE, \
				cr.size.x * TILE, cr.size.y * TILE))
		else:
			indoor_mask.set_room(false, Rect2())
	# T4.2 슬라이스가 끝났으면 마무리 화면만 유지하고 모든 게임 입력을 막는다
	# (이동은 _do_sleep/_end_run에서 이미 잠갔다). 마무리 화면은 _end_run이 한 번
	# 세웠으므로 여기선 더 손대지 않는다.
	if _run_over:
		# 마무리 화면에서도 세이브 삭제+새 시작(F8)은 받는다 — 슬라이스가 끝나(보호할 진행이
		# 없음) "다시 처음부터"가 가장 자연스러운 자리다. 여긴 곧바로 실행한다(2단 확인 없음).
		if Input.is_action_just_pressed("delete_save"):
			_delete_save_and_restart()
		return
	# 건물 진입/퇴장 fade 연출 중엔 모든 게임 입력·시뮬을 멈춘다(취침 연출과 같은 결 — 이동은
	# _transition_to에서 이미 잠갔다). lighting·BGM은 위에서 이미 이었으므로 그대로 흐른다.
	if _transitioning:
		return
	# T3.2 대화 중엔 다른 모든 입력을 막고 대사 넘기기(RMB=action)만 처리한다. 이동은 대화
	# 시작 시 player 물리를 꺼 잠가 두었고(_start_dialogue), 끝나면 다시 켠다.
	# 패널 본문은 dialogue.changed 시그널로 갱신되므로 여기선 입력만 본다.
	if dialogue.is_open():
		onboarding_label.visible = false  # T4.1 대화가 화면을 채우는 동안 배너 숨김
		if onboarding_banner != null:
			onboarding_banner.hide_now()  # 대화가 화면을 채우면 상단 안내 배너도 즉시 숨김
		if Input.is_action_just_pressed("action"):
			dialogue.advance()
		return

	# ★ C2 메뉴 토글(Tab): 어디서든 메뉴를 열고/닫는다(대화·연출 밖에서만 — 위 가드 통과 후).
	if not _sleeping and Input.is_action_just_pressed("menu_toggle"):
		if frame.context == InventoryFrame.CTX_MENU:
			_close_frame()
		elif not frame.is_open():
			_open_frame(InventoryFrame.CTX_MENU)

	# ★ C2 프레임(메뉴/출하함/매대)이 열려 있으면 모달이다 — 이동은 잠겨 있고(physics off), 클릭은
	# 프레임이 _gui_input으로 받는다. 여기선 닫기(Esc)·탭 순환(E)만 처리하고 다른 모든 게임 입력을
	# 막는다(대화 모달과 같은 결). 관계 탭이면 하트 값을 매 프레임 흘려넣어 읽기 전용으로 보인다.
	if frame.is_open():
		onboarding_label.visible = false
		if Input.is_action_just_pressed("ui_cancel") or (frame.context != InventoryFrame.CTX_MENU and Input.is_action_just_pressed("menu_toggle")):
			_close_frame()
		elif frame.context == InventoryFrame.CTX_MENU and Input.is_action_just_pressed("menu_tab"):
			frame.cycle_tab()
		if frame.context == InventoryFrame.CTX_MENU and frame.menu_tab == InventoryFrame.TAB_REL:
			frame.set_hearts(_heart_rows())
		elif frame.context == InventoryFrame.CTX_MENU and frame.menu_tab == InventoryFrame.TAB_SKILL:
			frame.set_skills(_skill_rows())   # ★ Phase B 숙련 탭(관계 탭과 대칭 — 읽기 전용 파생)
		elif frame.context == InventoryFrame.CTX_MENU and frame.menu_tab == InventoryFrame.TAB_OPTIONS:
			frame.set_settings(settings.music_volume, settings.sfx_volume, settings.fullscreen)   # ★ Phase D 설정 값 주입
		if frame.context == InventoryFrame.CTX_STORE:
			frame.store_text = _store_text()
		return

	# 건물 외관 문에 닿으면 실내로, 실내 문에 닿으면 밖으로 — 자동 fade 전환(스타듀식 출입).
	_maybe_toggle_building()
	# M1.3 구역 가장자리/길 워프 칸에 닿으면 인접 구역으로 전환(목적 구역이 지어졌을 때만 —
	# M1.3 현재는 이웃이 stub이라 휴면). 문과 같은 _warp 실행기를 거친다.
	_maybe_warp_edge()

	# 취침 입력: 집 안에서 Enter/Space(ui_accept)
	if _can_sleep() and Input.is_action_just_pressed("ui_accept"):
		_do_sleep()

	# T2.5 수동 저장/불러오기(연출 중 제외). F5 저장 · F9 불러오기.
	if not _sleeping and Input.is_action_just_pressed("save_game"):
		_save_game()
	if not _sleeping and Input.is_action_just_pressed("load_game"):
		_load_game()
	# 세이브 삭제+새 시작(F8). 되돌릴 수 없어 2단 확인 — 첫 F8은 무장만, 무장 중 다시 F8이면
	# 실행. 연출(취침) 중엔 받지 않는다(저장/불러오기와 같은 결).
	if not _sleeping and Input.is_action_just_pressed("delete_save"):
		_arm_or_confirm_delete()

	# F8 무장 시간이 지나면 조용히 해제한다(확인 문구 자체는 _notice가 같은 시간에 거둔다).
	if _delete_armed_secs > 0.0:
		_delete_armed_secs -= delta

	# ★ C3 — 알림 피드(좌하단 큐)는 스스로 시간 경과로 항목을 거둔다(별도 표시 타이머 폐기).

	# T5.4 카페 마감 정산 팝업 표시 시간이 지나면 숨긴다(자동 해제 — 비차단 팝업).
	if _cafe_summary_secs > 0.0:
		_cafe_summary_secs -= delta
		if _cafe_summary_secs <= 0.0:
			cafe_summary_panel.visible = false

	# T7.2 카페 1단 달성 팝업 표시 시간이 지나면 숨긴다(카페 정산 팝업과 같은 결 — 비차단 자동 해제).
	if _milestone_popup_secs > 0.0:
		_milestone_popup_secs -= delta
		if _milestone_popup_secs <= 0.0:
			milestone_panel.visible = false

	# ★ ADR-0024 핫바 선택: 숫자키(1~0,-,=)로 슬롯 직접 선택 + 휠로 순환. 든 것이 LMB 동사를 정한다.
	# Q 작물 순환은 폐기 — 씨앗은 이제 핫바 아이템(ADR-0020 데이터 주도 아이템 위에서).
	if not _sleeping:
		for i in Inventory.SIZE:
			# ★ 핫바 키는 12개(1234567890-=)만 등록 → 슬롯 12~15는 액션 미등록. has_action 가드로
			#   미등록 슬롯 조회를 건너뛴다(안 그러면 매 프레임 "hotbar_15 doesn't exist" 에러 스팸).
			if InputMap.has_action("hotbar_%d" % i) and Input.is_action_just_pressed("hotbar_%d" % i):
				inventory.select(i)
		if Input.is_action_just_pressed("hotbar_next"):
			inventory.select_next()
		elif Input.is_action_just_pressed("hotbar_prev"):
			inventory.select_prev()
	# 선택 슬롯이 씨앗/수확물이면 _selected_crop(선물·구매·HUD 기준 작물)을 그 작물군으로 따라가게 한다.
	_sync_selected_crop()

	# ★ ADR-0024 2채널 상호작용: 대상 칸 = 커서 밑 인접 1칸. LMB(use_tool)=든 도구 동사
	# (괭이질·물주기·심기), RMB(action)=맨손 액션(수확·대화·서빙·막기·취침). 도구가 칸 상태에
	# 안 맞으면 무동작(자동 분기 없음). T2.4 행동 한 번마다 혼력 소모, 바닥나면 막힌다.
	_update_target()
	# T5.6 미호 출퇴근: 현재 시각에 맞춰 미호를 밭/카페 자리로 옮긴다(facing 판정 전에 갱신해
	# 같은 프레임에 새 자리로 말 걸 수 있게 한다).
	_update_miho_station()
	# T6.1 바나 밤 등장: 현재 시각에 맞춰 밤 무대 가시성을 토글한다(밤이면 보이고 낮이면 숨김).
	# facing 판정 전에 갱신해 같은 프레임에 밤이 오면 바로 말 걸 수 있게 한다(미호 station과 같은 결).
	_update_bana_station()
	# T3.2/T5.6 미호에게 말 걸기: 바라보는 칸이 미호의 현재 자리(_miho_tile — 아침=밭/
	# 15시부터=카페)면 E로 대화를 연다(밭 동작보다 우선 — 미호 자리는 농사 대상에서 빠져
	# 있어 둘이 겹치지 않는다). facing_miho는 아래 하단 프롬프트에서도 재사용한다.
	var facing_miho := not _sleeping and _target == _miho_tile
	# T5.1 멜에게 말 걸기: 바라보는 칸이 멜 칸이면 우클릭으로 대화를 연다. ★ C2 — 출하대 F가
	# 사라져(ADR-0021 무인화) 멜은 *대화(우클릭)·선물(G)만* 남는다(판매는 무인 출하함으로 이전).
	var facing_mel := not _sleeping and _target == MEL_TILE
	# ★ C2 무인 출하함: 카페 안에서 출하함 칸을 바라볼 때 우클릭으로 출하함 패널을 연다. NPC·좌석·
	# 밭과 칸이 갈리고(SHIP_BIN_TILE 단일), _indoor로 가드해 다른 구역 같은 좌표에 닿아도 무반응.
	var facing_bin := not _sleeping and _indoor == "카페" and _target == SHIP_BIN_TILE
	# ★ Phase D 저장 상자: 집 실내에서 상자 칸을 바라볼 때 우클릭으로 상자 패널을 연다(_indoor로 가드해
	# 다른 구역 같은 좌표에 닿아도 무반응 — facing_bin과 같은 결). 집 안 상호작용은 상자 하나뿐이라 안 겹친다.
	var facing_chest := not _sleeping and _indoor == "집" and _target == CHEST_TILE
	# ★ Phase E 갈무리방(창고) 저장 상자: 창고 실내에서 상자 칸을 바라볼 때(_indoor로 가드해 다른 구역 같은
	# 좌표 무반응). 집 상자와 좌표·건물이 갈려 안 겹친다.
	var facing_storehouse_chest := not _sleeping and _indoor == "창고" and _target == STOREHOUSE_CHEST_TILE
	# T5.6 옥자(카페 상주)에게 말 걸기: 통보를 마친 뒤(NOTICE 단계 지남)에만 카페에 보인다.
	# 호감도·선물·출하대 없는 메인 서사 앵커라(ADR-0005) E 일상 대화만 받는다.
	var facing_okja := not _sleeping and okja.visible and onboarding.step > Onboarding.NOTICE \
		and _target == OKJA_CAFE_TILE
	# T6.1 바나(밤 무대)에게 말 걸기: 밤에 바나가 보일 때(bana.visible) 그 칸을 바라보면 E로
	# 대화를 연다. 호감도·선물·막기(T6.2+)는 범위 밖이라 지금은 E 대화만(옥자 일상 대화와 같은 결).
	var facing_bana := not _sleeping and bana.visible and _target == BANA_NIGHT_TILE
	# M2.3 네오(만물상 점주)에게 말 걸기/매대 열기: 만물상 안에서 네오 칸을 바라볼 때. _indoor로
	# 한 번 더 가드해(다른 구역의 같은 좌표에 닿아도 만물상 밖이면 무반응) 멜 출하대와 칸이 갈린다.
	var facing_neo := not _sleeping and _indoor == "만물상" and _target == NEO_TILE
	# ★ Phase C 좌하단 컨텍스트 팝업 — 마주 본 주민의 초상화 + 이름 + 관계 한 줄(상시 HUD, 대화창과 별개).
	if context_popup != null:
		if facing_miho:
			context_popup.set_target(_idle_portrait("미호"), "미호", _rel_line(affinity))
		elif facing_mel:
			context_popup.set_target(_idle_portrait("멜"), "멜", _rel_line(mel_affinity))
		elif facing_bana:
			context_popup.set_target(_idle_portrait("바나"), "바나", _rel_line(bana_affinity))
		elif facing_neo:
			context_popup.set_target(_idle_portrait("네오"), "네오", _rel_line(neo_affinity))
		elif facing_okja:
			context_popup.set_target(_idle_portrait("옥자"), "옥자", "저승 카페 사장")
		else:
			context_popup.clear()
	# T5.4 카페 손님 시뮬레이션을 굴린다(연출 중 제외). 영업창(15–19시) 안에서만 손님이
	# 오고 인내심이 돈다. 영업 중이면 인내심 바가 매 프레임 줄어드므로 다시 그린다.
	# T5.5 멜 마진 주입(관계 곱셈기, ADR-0008): 멜 하트 → 서빙 단가 배수를 cafe에 얹는다.
	# foxfire가 farm.advance_day(accel,reach)로 하트를 흘려넣는 것과 같은 다리 — cafe는
	# margin 파라미터만 받고 멜 호감도를 모른다(디커플링). 매 프레임 파생해 HUD 단가·
	# serve_price가 항상 현재 하트를 반영한다(♡0 ×1.0 base → ♡5 ×2.0, 평평≠막힘).
	cafe.margin = CafeMargin.margin(mel_affinity.hearts())
	if not _sleeping:
		cafe.tick(delta, clock.minutes)
	if cafe.is_open():
		queue_redraw()
	# T6.5 바나 이중 보호 곱셈기 주입(관계 곱셈기, ADR-0008·ADR-0010 #7): 바나 하트 → 밤 보호
	# 세 축을 night_bar seam에 얹는다. cafe.margin과 같은 다리 — night_bar는 바나 호감도를 모르고
	# 파라미터만 받는다(디커플링). 매 프레임 파생해 HUD·정산이 항상 현재 하트를 반영하고, F로
	# 바를 여는 순간(_open_night_bar는 아래 입력에서 처리)의 auto_block도 최신 값이 채워진다.
	# ♡0이면 세 축 모두 night_bar 기본값 = 바나 잠듦(평평≠막힘, ADR-0008). 막기 판정 *위* 레이어라
	# Phase 3 전투가 막기 구현을 갈아껴도 이 주입은 그대로 산다(ADR-0010 #8).
	var bana_hearts := bana_affinity.hearts()
	night_bar.raid_amount = BanaGuard.raid_amount(bana_hearts)      # ㉠ 약탈량↓
	night_bar.auto_block = BanaGuard.auto_block(bana_hearts)        # ㉠ 창고 잡귀 자동 차단↑
	night_bar.patience_secs = BanaGuard.patience_secs(bana_hearts)  # ㉡ 카운터 빈 사이 인내심↑
	# T6.3 밤 바 시뮬레이션을 굴린다(연출 중 제외). 잡귀는 *바를 연 밤(옵트인)* 의 19–24시
	# 창 안에서만 깃들고 접근한다 — 안 열면 빈 밤이라 아무 일도 없다(ADR-0010 #6 옵트인).
	# 활성(잡귀 접근 중)이면 접근 바가 매 프레임 줄어드므로 다시 그린다(카페 손님과 같은 결).
	if not _sleeping:
		night_bar.tick(delta, clock.minutes)
	if night_bar.is_active():
		queue_redraw()
	# 바라보는 칸이 손님 좌석이면 그 좌석 인덱스(없으면 -1). 서빙 대상 판정·프롬프트에 쓴다.
	# 낮 카페 손님(15–19시)·밤 바 손님(19–24시)이 같은 좌석 줄(y=7)을 시간대로 나눠 쓴다
	# (둘은 시간이 겹치지 않아 한 번에 한쪽만 is_waiting — cafe/night_bar 활성으로 분기).
	var facing_seat := SEAT_TILES.find(_target) if not _sleeping else -1
	# T6.4 바라보는 칸이 밤 잡귀 스폿이면 그 스폿 인덱스(없으면 -1). 막기 대상 판정·프롬프트에 쓴다.
	# 좌석 줄(y=7)·잡귀 스폿 줄(y=9)이 카페 통로(y=8)를 사이에 둬, 플레이어가 위를 보면 응대·
	# 아래를 보면 막기 — 한 번에 한쪽만 마주본다(★ 막기↔응대 경쟁의 공간적 뿌리, ADR-0010 #4).
	var facing_spot := NIGHT_SPOT_TILES.find(_target) if not _sleeping else -1
	# ── ADR-0024 RMB(action) 컨텍스트 체인 ───────────────────────────────────────
	# RMB는 맨손 액션/대화 — 우선순위대로 하나만 잡고 return으로 가른다. 대상 칸 종류(NPC·좌석·
	# 스폿·밭)는 서로 배타적이라 충돌하지 않는다. 선물(G)·바 열기/출하대(F)는 별개 키라 그대로 둔다.
	if facing_miho and Input.is_action_just_pressed("action"):
		_start_dialogue()
		return
	# T3.3 미호 선물(G): 바라볼 때 선택 작물 수확물 1개를 건넨다(호감도↑, 하루 1회).
	if facing_miho and Input.is_action_just_pressed("gift_item"):
		_try_gift()
		return
	# T5.6 옥자 일상 대화(RMB): 카페 상주 옥자. 호감도·선물 없는 일상이라 G는 없다.
	if facing_okja and Input.is_action_just_pressed("action"):
		_start_okja_dialogue()
		return
	# T6.1 바나 대화(RMB) / T6.2 선물(G): 밤 무대의 바나를 바라볼 때. 좌석·밭보다 먼저 잡고 return.
	if facing_bana and Input.is_action_just_pressed("action"):
		_start_bana_dialogue()
		return
	if facing_bana and Input.is_action_just_pressed("gift_item"):
		_try_bana_gift()
		return
	# T6.3 나라카 바 옵트인(F): 밤에 바나를 바라보며 바를 연다(별개 키 — RMB 대화와 안 겹친다).
	# 안 열면 빈 밤 — 옵트인은 그 밤의 선택이지 매일 세금이 아니다(ADR-0010 #6, ADR-0008 평평≠막힘).
	if facing_bana and not night_bar.is_opened() and Input.is_action_just_pressed("shop_toggle"):
		_open_night_bar()
		return
	# ★ C2 무인 출하함 열기(RMB): 카페 출하함 칸을 바라보며 우클릭으로 패널을 연다(좌석·밭보다 먼저
	# 잡고 return — 출하함 칸은 다른 대상과 안 겹친다). 패널은 모달이라 위 frame.is_open 가드로 닫힌다.
	if facing_bin and Input.is_action_just_pressed("action"):
		_open_frame(InventoryFrame.CTX_BIN)
		return
	# ★ Phase D 저장 상자 열기(RMB): 집 실내 상자 칸을 바라보며 우클릭으로 보관 패널을 연다(모달 —
	# 위 frame.is_open 가드로 닫힌다). 집 안 취침(ui_accept)·상자(action)는 키가 갈려 안 겹친다.
	if facing_chest and Input.is_action_just_pressed("action"):
		_open_chest(chest)
		return
	# ★ Phase E 창고 상자 열기(RMB): 집 상자와 같은 결 — 활성 상자만 바꿔 같은 CTX_CHEST 패널을 연다.
	if facing_storehouse_chest and Input.is_action_just_pressed("action"):
		_open_chest(storehouse_chest)
		return
	# T5.1 멜 대화(RMB) / T5.2 선물(G): ★ C2 — 출하대 F가 사라져 가드(not _shop_open)도 불필요하다.
	if facing_mel and Input.is_action_just_pressed("action"):
		_start_mel_dialogue()
		return
	if facing_mel and Input.is_action_just_pressed("gift_item"):
		_try_mel_gift()
		return
	# M2.3 네오 대화(RMB): 만물상에서 네오를 바라보며(일일 대화로 호감도↑).
	if facing_neo and Input.is_action_just_pressed("action"):
		_start_neo_dialogue()
		return
	# ★ C2 만물상 매대 열기(F): 네오를 바라보며 F로 매대 프레임을 연다(대화=우클릭과 갈린다, 무인 바 F와 같은 결).
	if facing_neo and Input.is_action_just_pressed("shop_toggle"):
		_open_frame(InventoryFrame.CTX_STORE)
		return
	# T5.4 손님 서빙(RMB): 기다리는 손님 좌석을 바라보며. 보유 재료 1개를 자동 소모하고 정액 골드.
	if facing_seat >= 0 and cafe.is_waiting(facing_seat) and Input.is_action_just_pressed("action"):
		_try_serve(facing_seat)
		return
	# T6.4 막기(RMB): 밤에 잡귀가 깃든 스폿을 바라보며 즉시 격퇴(★ 막기↔응대 경쟁, ADR-0010 #2·#4).
	if facing_spot >= 0 and night_bar.is_threat(facing_spot) and Input.is_action_just_pressed("action"):
		_try_block(facing_spot)
		return
	# T6.4 밤 손님 응대(RMB): 바 손님 좌석을 바라보며 정액 밤 매출(재료 무소모 — 현재 자산, ADR-0010 #5).
	if facing_seat >= 0 and night_bar.is_waiting(facing_seat) and Input.is_action_just_pressed("action"):
		_try_night_serve(facing_seat)
		return
	# ★ [B1-a.2] 동물 건물 실내 방목 문 토글(F) — 문을 열면 짐승이 낮에 방목지로 나간다(즉시 방출·grazed),
	#   닫으면 실내에 머문다. 나간 뒤 귀가(밤) 전에 닫으면 실외 고립(M_NIGHT_EXPOSED, 엣지①). SDV 헛간 문 결.
	if not _sleeping and _indoor in ANIMAL_BUILDINGS and Input.is_action_just_pressed("shop_toggle"):
		var opened := ranch.toggle_door(_indoor)
		audio.sfx("ui")
		if opened:
			_release_open_buildings()   # 낮이면 이 건물 짐승 즉시 방목지로(밤엔 _release가 스스로 가드).
			_notice("%s 방목 문 열림 — 짐승이 방목지로 나간다" % _indoor)
		else:
			_notice("%s 방목 문 닫힘 — 나간 짐승은 밤 귀가 전 다시 열어 둬야 한다" % _indoor)
		return
	# ★ [B1-a.2→B1-a.3] 동물 건물 실내 RMB = 여물통 급여(여물광 건초로) + 잠자리 청소. 방목·격리는 pathing이
	#   자동으로 세우므로(문 방출→grazed·밤 귀가→penned), 실내 돌봄은 급여+청소만 남는다(SDV 건물 안 돌봄).
	#   급여는 여물광(Ranch._silo_hay)에서 짐승당 1단 뽑는다 — 비면 굶는다(낫으로 미리 쌓아야, Q7). 짐승을
	#   직접 바라볼 땐 아래 on_animal의 쓰다듬/수집(손급여)이 우선 → 여기선 짐승 밖 실내 칸에서만.
	if not _sleeping and _indoor in ANIMAL_BUILDINGS and not ranch.has_animal(_target) \
			and Input.is_action_just_pressed("action"):
		var fed_ct := ranch.feed_from_silo_in(_indoor)
		var cleaned := ranch.clean_all_in(_indoor)
		if fed_ct > 0 or cleaned:
			audio.sfx("ui")
			if fed_ct > 0:
				_notice("%s 여물 급여 %d마리 + 청소 (여물광 %d단 남음)" % [_indoor, fed_ct, ranch.silo_hay()])
			else:
				_notice("%s 청소 완료 — 여물광이 비어 급여 못 함" % _indoor if ranch.silo_hay() <= 0 else "%s 청소 완료 — 잠자리를 정갈히" % _indoor)
		elif ranch.silo_hay() <= 0:
			_notice("여물광이 비었다 — 낫으로 사료풀을 베어 채워야 한다")
		return
	# ★ [S1-7→B1-a.1] 짐승 상호작용 — 짐승은 실내 바닥(비-SOIL) 위라 _target_valid 게이트 밖에서 따로 디스패치한다.
	#   LMB=건초 급여(_use_tool 내 hay 분기)·RMB=쓰다듬/산물 수집(_try_harvest 내 짐승 분기). 건물 실내에서 이뤄진다.
	var on_animal := not _sleeping and _region == RegionCatalog.HOME and ranch.has_animal(_target)
	if on_animal and Input.is_action_just_pressed("use_tool"):
		_use_tool()
	if on_animal and Input.is_action_just_pressed("action"):
		_try_harvest()
	# ★ [S1-8 §10.1] 개간 — debris는 GROUND(비-SOIL) 위라 _target_valid 게이트 밖에서 따로 디스패치한다.
	#   LMB(맞는 도구 든 채)=개간(_use_tool 내 개간 분기). 도구·debris 매칭은 그 안에서 판정(틀린 도구=무동작).
	var on_debris := not _sleeping and _debris_kind_at(_target) != ""
	if on_debris and Input.is_action_just_pressed("use_tool"):
		_use_tool()
	# ★ [ADR-0055] 재점령 잡초 낫질 — 잡초는 GROUND(비-SOIL) 위라 _target_valid 게이트 밖에서 따로 디스패치.
	#   LMB(낫 든 채)=베기(_use_tool 내 개간 분기 → clear_weed). 낫 아니면 그 안에서 무동작.
	var on_weed := not _sleeping and _region == RegionCatalog.HOME and reclaim != null and reclaim.has_weed(_target)
	if on_weed and Input.is_action_just_pressed("use_tool"):
		_use_tool()
	# ★ [B1-a.3] 낫 풀베기 — 사료풀은 GROUND(비-SOIL·비-짐승) 위라 _target_valid 게이트 밖에서 따로 디스패치.
	#   LMB(낫 든 채)=베기(_use_tool 내 사료풀 분기 → 여물광 +1). 낫 아니거나 안 자란 풀이면 그 안에서 무동작.
	var on_forage := not _sleeping and _region == RegionCatalog.HOME \
			and inventory.selected_id() == ItemCatalog.SCYTHE and forage.is_grown(_target)
	if on_forage and Input.is_action_just_pressed("use_tool"):
		_use_tool()
	# ★ ADR-0052 꽃 패치 채집 — 피안화는 GROUND(비-SOIL·비-짐승·비-나무) 위라 _target_valid 밖에서 따로 디스패치.
	#   RMB 맨손(줍기=혼력0, ADR-0033 #1)=따기(_pick_flower → 채집물+채집 XP). 안 폈으면 무동작. 아래 일반
	#   RMB 수확(_try_harvest)은 _target_valid(SOIL)에서만 도니 겹치지 않는다(꽃 패치는 GROUND).
	var on_flower := not _sleeping and _region == RegionCatalog.HOME and flower.is_bloomed(_target)
	if on_flower and Input.is_action_just_pressed("action"):
		_pick_flower(_target)
	# ★ ADR-0024 LMB = 든 도구 사용(괭이질·물주기·씨앗 심기). 커서 밑 인접 1칸 밭에 작용.
	if not _sleeping and _target_valid and Input.is_action_just_pressed("use_tool"):
		_use_tool()
	# ★ ADR-0024 RMB 맨손 수확: 다 자란 칸을 바라보며 거둔다(낫 없음 — 수확=맨손).
	if not _sleeping and _target_valid and Input.is_action_just_pressed("action"):
		_try_harvest()
	# ★ ADR-0024 취침(RMB): 집 안이면 RMB로도 잠든다(위 ui_accept와 병행 — 어느 쪽이든).
	if _can_sleep() and Input.is_action_just_pressed("action"):
		_do_sleep()

	# ★ C2 — 멜 출하대(_process_shop)·만물상 매대(_process_store) 폴링은 폐기됐다. 판매는 무인
	# 출하함(위 facing_bin 우클릭 → 모달 프레임), 구매는 매대 프레임(위 facing_neo F)으로 옮겼다.

	var p := player.global_position
	# ★ owner 2026-07-03 — 좌상단 디버그 Readout(방향키·구역·좌표·FPS)은 화면을 가려 상시 숨김.
	#   텍스트는 계속 갱신해 둬(F-키 등 향후 디버그 토글 시 값 즉시 노출). 표시만 끈다.
	readout.text = "방향키 이동   구역: %s   위치(%d, %d)   FPS %d" % [
		_zone_at(p), int(p.x), int(p.y), Engine.get_frames_per_second()
	]
	readout.visible = false
	# ★ Phase C 시계 클러스터(우상단): raw ClockLabel/GoldLabel/MilestoneLabel을 한지 플레이트
	# 하나로 통합했다(clock_hud). 절기 내 일차 = (day-1)%28+1(요일은 도메인에 없음 — clock_hud 주석).
	# 날씨(☀)는 백엔드 부재로 보류(ADR-0048).
	var _dos := (clock.day - 1) % GameClock.DAYS_PER_SEASON + 1
	if clock_hud != null:
		clock_hud.set_state(GameClock.season_name(clock.season_index()), _dos, clock.clock_string(),
			clock.phase(), wallet.gold, CafeMilestone.compact(_run_harvested, _cafe_revenue_total, _milestone_hearts()))
	clock_label.visible = false
	# ★ owner 2026-07-03 HUD 가이드 A — 하단 중앙 날것 텍스트("핫바 N번 · 든 것…")는 화면을 가리고
	#   몰입을 깬다. 핫바가 이제 단축키 인덱스·선택 금박·개수 배지를 다 보여줘 이 요약은 중복 → 숨김.
	#   씨앗 보유 수·성장일 상세는 핫바 호버 툴팁(HudTooltip)이 담당. 텍스트는 계산 유지(향후 토글).
	crop_label.text = _hotbar_summary()
	crop_label.visible = false
	# ★ Phase C 골드는 시계 클러스터(clock_hud)로 이전 — raw 라벨 숨김.
	gold_label.visible = false
	# ★ C3 — 혼력은 우하단 혼력 바(vitals)가, 하트(미호·멜·바나·네오)는 메뉴 관계 탭이 그린다(프레임이
	#   열렸을 때 위 입력 핸들러가 set_hearts로 값을 흘려넣는다 — 모달이라 이 HUD 블록엔 안 온다).
	#   여우불·카페 마진·바나 경비·네오 할인 같은 관계 곱셈기도 관계 탭 효과 줄에서 복기한다(_heart_rows).
	#   카페·밤 영업의 일시 이벤트(서빙·약탈·정산)는 알림 피드(_notice)로 흐른다 — 상시 상태 라벨
	#   난립을 미니멀 HUD로 정리(ADR-0018).
	# ★ C3 카페 마일스톤(시계 클러스터 곁 작은 진행 표시 — 매크로 목표, ADR-0009). 세 루프 산출물
	# (거둔 영혼·누적 서빙 매출·세 동료 하트 합)에서 매번 파생한 compact 한 줄(바+%). 완료되면 ★.
	# ★ Phase C 마일스톤은 시계 클러스터(clock_hud)로 이전해 화면 표시 — raw 라벨은 숨긴다. 단 값은
	# 계속 채워 둔다(비가시라 raw 0 유지 + milestone_test가 이 문자열을 단언). 표시는 clock_hud가 맡는다.
	milestone_label.text = CafeMilestone.compact(_run_harvested, _cafe_revenue_total, _milestone_hearts())
	milestone_label.visible = false
	# 채우는 순간 한 번 "카페 2단계!" 팝업을 띄운다(래치 — 매 프레임 재팝업 방지). 달성 여부는
	# 누적값에서 파생되므로(세이브 무상태), 재개 시엔 _ready가 래치를 미리 켜 둬 다시 안 터진다.
	if not _milestone_celebrated and _milestone_complete():
		_milestone_celebrated = true
		_show_milestone_reached()
	# T4.1 온보딩 안내: 상시 중앙 배너가 "계속 떠서 불편"(피드백 2026-06-25) → 단계가 *바뀔 때만*
	# 잠깐 띄운다. ★owner 2026-07-03 3차 HUD 가이드 — 좌하단 wide notice(화면 폭 날것 띠)를 폐기하고
	# 전용 상단-중앙 팝업 배너(한지 플레이트·외곽선·페이드)로 교체. 매 프레임 guidance()를 보되 직전과
	# 다를 때만 show_guide(=단계 전환 1회). 모달 중엔 위 early-return이라 비교 보존.
	var guide := onboarding.guidance()
	if guide != _last_onboarding_guide:
		_last_onboarding_guide = guide
		if guide != "" and onboarding_banner != null:
			onboarding_banner.show_guide(guide)   # 상단 중앙 배너, HOLD 후 부드럽게 페이드아웃
	onboarding_label.visible = false
	# ★ C2 — 옛 ShopPanel(멜 출하대·네오 매대 텍스트)은 폐기됐다. 매대·출하함은 공통 프레임이
	# 그리므로 ShopPanel 노드는 상시 숨긴다(tscn 노드는 남되 미사용 — 회귀 0, frame이 대체).
	shop_panel.visible = false
	# 집 안에서만 취침 안내를 띄운다(연출 중엔 숨김).
	sleep_prompt.visible = _can_sleep()
	# 하단 프롬프트(집은 sleep_prompt, 카페·밭은 interact_prompt — 구역이 달라 겹치지 않음).
	# 우선순위: 출하함 > 미호 > 옥자 > 바나(밤) > 네오(매대) > 멜(대화·선물) > 손님 서빙 > 밭 동작.
	# ★ ADR-0024 — 대화·서빙·막기·수확은 RMB(우클릭), 도구질은 LMB(좌클릭). 선물(G)·바·매대(F)는 별개 키.
	if facing_chest or facing_storehouse_chest:
		# ★ Phase D/E 저장 상자를 바라볼 때: 우클릭으로 보관 패널을 연다(순수 보관 — 판매 아님).
		interact_prompt.visible = true
		interact_prompt.text = "[우클릭] 저장 상자 (아이템 보관 · 판매 아님)"
	elif facing_bin:
		# ★ C2 무인 출하함을 바라볼 때: 우클릭으로 패널을 연다(드롭→익일 정산, 멜 F 소멸).
		interact_prompt.visible = true
		interact_prompt.text = "[우클릭] 무인 출하함 (수확물 드롭 → 다음 아침 정산)"
	elif facing_neo:
		# M2.3 네오(만물상 점주)를 바라볼 때: 대화·매대 한 줄 안내(네오가 매대 얼굴). 이 슬라이스는
		# 선물(G) 없이 일일 대화로만 친해진다(풀 T1 트랙은 후속, ADR-0014).
		interact_prompt.visible = true
		interact_prompt.text = "[우클릭] 대화   [F] 매대"
	elif facing_miho:
		interact_prompt.visible = true
		interact_prompt.text = "[우클릭] 대화   [G] %s 선물" % CropCatalog.name_of(_selected_crop)
	elif facing_okja:
		# T5.6 옥자를 바라볼 때: 일상 대화만(호감도·선물·출하대 없음 — 매일 보는 사장).
		interact_prompt.visible = true
		interact_prompt.text = "[우클릭] 대화"
	elif facing_bana:
		# T6.1/T6.2 바나(밤 무대)를 바라볼 때: 대화·선물 안내. T6.3 바를 아직 안 열었으면
		# [F] 바 열기(옵트인)를 덧붙이고, 이미 열었으면 영업 중임을 알린다(막기는 T6.4+ 몫).
		interact_prompt.visible = true
		var bana_hint := "[우클릭] 대화   [G] %s 선물" % CropCatalog.name_of(_selected_crop)
		if night_bar.is_opened():
			bana_hint += "   (나라카 바 영업 중)"
		else:
			bana_hint += "   [F] 나라카 바 열기"
		interact_prompt.text = bana_hint
	elif facing_mel:
		# T5.1/T5.2 멜을 바라볼 때: ★ C2 — 출하대 F가 사라져 대화·선물만 안내한다(판매는 무인 출하함).
		interact_prompt.visible = true
		interact_prompt.text = "[우클릭] 대화   [G] %s 선물" % CropCatalog.name_of(_selected_crop)
	elif facing_spot >= 0 and night_bar.is_threat(facing_spot):
		# T6.4 잡귀가 깃든 스폿을 바라볼 때: 우클릭으로 막는다(즉시 격퇴). 막으러 오느라 카운터를
		# 비운 사이 손님이 닳는 게 ★ 막기↔응대 경쟁의 비용이다(ADR-0010 #4).
		interact_prompt.visible = true
		interact_prompt.text = "[우클릭] 막기 (잡귀 격퇴 · 재고 지킴)"
	elif facing_seat >= 0 and cafe.is_waiting(facing_seat):
		# T5.4 기다리는 손님을 바라볼 때: 재료가 있으면 서빙, 없으면 막힌 이유를 안내.
		interact_prompt.visible = true
		interact_prompt.text = "[우클릭] 서빙 (+%d골드)" % cafe.serve_price() if _has_any_harvest() \
			else "서빙할 재료 없음 — 수확물 필요"
	elif facing_seat >= 0 and night_bar.is_waiting(facing_seat):
		# T6.4 밤 바 손님을 바라볼 때: 우클릭으로 응대(정액 밤 매출, 재료 무소모 — 현재 자산).
		interact_prompt.visible = true
		interact_prompt.text = "[우클릭] 응대 (+%d골드)" % NightBar.SERVE_PRICE
	elif _region == RegionCatalog.HOME and ranch.has_animal(_target):
		# ★ [S1-7→B1-a.1] 짐승을 바라볼 때(실내): 산물 있으면 수집, 없으면 쓰다듬 / 든 게 건초면 급여 안내.
		interact_prompt.visible = not _sleeping
		interact_prompt.text = _animal_prompt(_target)
	elif _indoor in ANIMAL_BUILDINGS and ranch.animals_in(_indoor).size() > 0:
		# ★ [B1-a.1] 동물 건물 실내(짐승 밖 칸): 우클릭으로 그 건물 방목·격리·청결 일괄(실내 돌봄 리추얼).
		interact_prompt.visible = not _sleeping
		interact_prompt.text = "[우클릭] %s 돌봄 (방목·격리·청결)" % _indoor
	elif _debris_kind_at(_target) != "":
		# ★ [S1-8] 개간 대상 debris를 바라볼 때: 맞는 도구를 들었으면 [좌클릭] 개간, 아니면 필요한 도구 안내.
		interact_prompt.visible = not _sleeping
		interact_prompt.text = _debris_prompt(_debris_kind_at(_target))
	elif _region == RegionCatalog.HOME and reclaim != null and reclaim.has_weed(_target):
		# ★ [ADR-0055] 밤새 돋은 재점령 잡초를 바라볼 때: 낫을 들었으면 [좌클릭] 풀베기, 아니면 낫 안내.
		interact_prompt.visible = not _sleeping
		interact_prompt.text = _debris_prompt(DebrisCatalog.WEEDS)
	elif _region == RegionCatalog.HOME and flower.is_bloomed(_target):
		# ★ ADR-0052 활짝 핀 꽃 패치를 바라볼 때: 우클릭 맨손 채집(혼력0). 채집물+채집 XP.
		interact_prompt.visible = not _sleeping
		interact_prompt.text = "[우클릭] 피안화 채집 (채집 숙련)"
	else:
		# 밭 칸을 바라볼 때만 안내. 든 도구·칸 상태로 동사를 파생한다(LMB 도구질 / RMB 맨손 수확).
		var prompt := _farm_prompt()
		interact_prompt.visible = not _sleeping and prompt != ""
		interact_prompt.text = prompt

# ── ADR-0024 LMB 도구 사용 / RMB 맨손 수확 ──────────────────────────────────
# ★ 핵심 피벗(ADR-0024 §2): 든 도구가 동사를 정한다(자동 분기 없음). 괭이→hoe·물뿌리개→water·
# 씨앗→plant. 도구가 칸 상태에 안 맞으면(예: 미경작 칸에 물뿌리개) field 사전조건이 false라
# 무동작 — "선택 도구가 장식이 되지 않게"(ADR-0020). 한 동작이 실제로 일어났을 때만 혼력·SFX·
# 온보딩을 소비한다. 혼력이 바닥나면(can_act false) 아무 도구도 안 듣는다(T2.4).
# ★ S1-6(§8.9) 농사 동작 1회 혼력 비용 = 기본 × 숙련 감산 계수(FarmSkill.energy_factor).
# 밭 갈기·심기·물주기·비료·수확·과수수확 — 농사 동작에만 감산 적용(ADR-0019 스킬=활동별). energy.gd는
# 레벨을 모르고, main이 여기서 계산해 spend/can_act에 주입한다(디커플링). L0=10 그대로·L10→7.
func _farming_energy_cost() -> int:
	return int(round(SoulEnergy.COST_PER_ACTION * FarmSkill.energy_factor(FarmSkill.level_for_xp(_farming_xp))))

func _use_tool() -> void:
	var cost := _farming_energy_cost()        # ★ S1-6 숙련 감산 반영 비용
	if not energy.can_act(cost):
		return
	var item := inventory.selected_id()
	var cat := ItemCatalog.category_of(item)
	var verb := ""
	if item == ItemCatalog.HOE:
		if farm.hoe(_target):
			verb = "괭이질"
	elif item == ItemCatalog.WATERING_CAN:
		if farm.water(_target):
			verb = "물주기"
	elif cat == ItemCatalog.CAT_SEED:
		# 든 씨앗의 작물군을 심는다(경작된 빈 칸에만 — plant 사전조건). 심으면 씨앗 1개 소모.
		var crop := ItemCatalog.crop_of(item)
		if inventory.has_seed(crop) and farm.plant(_target, crop):
			inventory.take_seed(crop)
			verb = "심기"
	elif cat == ItemCatalog.CAT_FERTILIZER:
		# ★ [S1-6] 든 비료를 경작 칸에 뿌린다(§8.4 — 심김/빈칸 무관, 다른 비료면 overwrite). 뿌리면 1개 소모.
		if farm.fertilize(_target, item):
			inventory.remove_item(item, 1)
			verb = "비료"
	elif cat == ItemCatalog.CAT_SAPLING and _region == RegionCatalog.HOME:
		# ★ [S1-5b] 든 묘목으로 혼의 나무를 심는다(안식 농원 전용). 앵커=조준 칸, 3×3 판정 통과 시.
		# is_blocked = 맵밖 or is_solid(절벽·프롭) or is_crop_solid(트렐리스) — 지형 게이팅을 여기서 합성해
		# orchard에 주입한다(orchard는 지형을 모름, greybox-spec §7.4). 심으면 묘목 1개 소모.
		var fruit := ItemCatalog.fruit_of(item)
		if inventory.has_sapling(fruit) and orchard.plant(_target, fruit, clock.day, _is_tree_blocked):
			inventory.take_sapling(fruit)
			verb = "심기"
	elif item == ItemCatalog.HAY and _region == RegionCatalog.HOME:
		# ★ [S1-7] 든 건초로 조준 칸의 짐승을 급여한다(§4.1 — 하늘 목장 전용, 하루 1회). 급여 시 건초 1개 소모.
		if ranch.has_animal(_target) and ranch.feed(_target):
			inventory.remove_item(ItemCatalog.HAY, 1)
			verb = "급여"
	elif item == ItemCatalog.SCYTHE and _region == RegionCatalog.HOME and forage.is_grown(_target):
		# ★ [B1-a.3] 든 낫으로 조준 칸의 다 자란 사료풀을 벤다 → 여물광에 건초 +1(가득/초과 시 소멸, Q7).
		#   낫은 개간(debris)에도 쓰이지만 사료풀 분기를 먼저 둬(둘은 좌표가 안 겹침) 풀 위에선 베기가 잡힌다.
		if forage.cut(_target, clock.day):
			var stored := ranch.store_hay(1)
			verb = "풀베기"
			if stored > 0:
				_notice("사료풀을 베어 여물광에 건초 +1 (%d/%d단)" % [ranch.silo_hay(), Ranch.SILO_CAP])
			else:
				_notice("사료풀을 벴지만 여물광이 가득 차 건초가 흩어졌다")
	elif DebrisCatalog.is_reclaim_tool(item) and _region == RegionCatalog.HOME:
		# ★ [S1-8 §10.3] 든 개간 도구(낫/곡괭이/도끼)로 조준 칸의 debris를 친다. 맞는 도구면 reclaim이 치우고
		# 드랍을 반환한다(틀린 도구·미지 kind·이미 치움이면 {} → 무동작). 드랍은 인벤토리에 적재(경제 양끝 잇기).
		var kind := _debris_kind_at(_target)
		if kind != "":
			var res := reclaim.clear(_target, kind, item)
			if not res.is_empty():
				inventory.add_item(str(res["drop"]), int(res["count"]))
				_toast_item(str(res["drop"]), int(res["count"]))   # ★ Phase C 획득 토스트
				verb = "개간"
		elif reclaim.has_weed(_target):
			# ★ [ADR-0055] 밤새 돋은 재점령 잡초를 낫으로 벤다(WEEDS 드랍 = 혼백섬유 ×1). 낫 아니면 무동작.
			var wres := reclaim.clear_weed(_target, item)
			if not wres.is_empty():
				inventory.add_item(str(wres["drop"]), int(wres["count"]))
				_toast_item(str(wres["drop"]), int(wres["count"]))
				verb = "풀베기"
	if verb == "":
		return  # 든 도구가 칸 상태에 안 맞음 → 무동작(자동 분기 없음, ADR-0024 §2)
	# P2.6 밭 동작 SFX. 괭이질·심기는 흙 다지는 둔탁한 "턱"(hoe 재사용), 물주기·비료는 물/뿌리는 소리.
	audio.sfx({"괭이질": "hoe", "심기": "hoe", "물주기": "water", "비료": "water", "급여": "water", "개간": "hoe", "풀베기": "harvest"}.get(verb, ""))
	_advance_onboarding(verb)                 # T4.1 이 동작이 온보딩 단계를 다음으로 넘긴다
	energy.spend(cost)                        # 한 동작당 혼력 소모(숙련 감산)
	queue_redraw()                            # 새 상태가 바로 보이도록

# RMB 맨손 수확(ADR-0024 §3 — 낫 없음, 수확=맨손). 다 자란 칸만 거두고, 거둔 영혼을 인벤토리에
# 쌓아 경제의 양끝을 잇는다(밭→재고→판매·서빙). 다 안 자랐거나 혼력 부족이면 무동작.
func _try_harvest() -> void:
	var cost := _farming_energy_cost()        # ★ S1-6 숙련 감산 반영 비용(과수·밭 공통)
	if not energy.can_act(cost):
		return
	# ★ [S1-7] 혼의 짐승 RMB 우선(§4.1) — 조준 칸에 짐승이 있으면: 대기 산물이 있으면 수집(인벤토리 적재),
	# 없으면 쓰다듬(우정·기분 데일리 케어). 밭·과수보다 먼저 본다(짐승 타일은 방목지라 겹침 없음). 안식 농원 전용.
	if _region == RegionCatalog.HOME and ranch.has_animal(_target):
		if ranch.has_product(_target):
			var got := ranch.collect(_target)   # {product_id, quality, is_large}
			if not got.is_empty():
				# 대형 산물은 "<산물>_large" 아이템(판매가 ×2)으로, 아니면 기준 산물로 적재(§8.6). 품질 등급 실림.
				var pid: String = ItemCatalog.large_product_id(got["product_id"]) if bool(got["is_large"]) else str(got["product_id"])
				inventory.add_item(pid, 1, int(got["quality"]))
				_toast_item(pid, 1)                 # ★ Phase C 획득 토스트(산물 수집)
				audio.sfx("harvest")
				energy.spend(cost)
				queue_redraw()
		elif ranch.pet(_target):                # 산물 없음 → 쓰다듬(하루 1회 실효)
			audio.sfx("ui")
			energy.spend(cost)
			queue_redraw()
		return   # 짐승 칸이면 밭·과수로 흘려보내지 않는다(이미 처리했거나 오늘 케어 완료)
	# ★ [S1-5b] 혼의 나무 과수 수확 우선(greybox-spec §7.6) — 조준 칸이 성숙+결실 나무 풋프린트에 들면
	# 매달린 과일을 전량 거둔다. 작물 밭(SOIL)이 아니라 과수라 farm 경로보다 먼저 본다. 안식 농원 전용.
	if _region == RegionCatalog.HOME:
		var anchor := orchard.tree_at(_target)
		if orchard.has_tree(anchor):
			var picked := orchard.harvest(anchor, clock.day)   # {fruit_id,count,quality_tier} / {} = 미성숙·무결실
			if not picked.is_empty():
				# ★ [S1-6 §8.8] 나이 등급(quality_tier)을 슬롯 quality로 실적재(§7.7 소비 실현). 나무 나이가
				# 소스라 나무 한 그루의 이번 결실은 전량 동일 등급(밭 비료 roll과 달리 결정적).
				var fq := int(picked["quality_tier"])
				for _i in int(picked["count"]):
					inventory.add_item(picked["fruit_id"], 1, fq)   # 과일 = CAT_HARVEST(등급 실림)
				_toast_item(str(picked["fruit_id"]), int(picked["count"]))   # ★ Phase C 획득 토스트
				_gain_farm_xp(FruitTreeCatalog.fruit_sell(picked["fruit_id"]))  # ★ 과수 수확도 농사 XP(§8.9)+레벨업 감지
				audio.sfx("harvest")
				energy.spend(cost)
				queue_redraw()
				return
	if not farm.is_mature(_target):
		return
	var harvested_crop := farm.crop_of(_target)  # harvest 뒤엔 칸이 비거나(SINGLE) 되감기(REGROW) 되므로 미리 확보
	var quality := farm.roll_quality(_target)    # ★ [S1-6 §8.5] 칸을 비우기 전에 품질 확보(비료→등급 roll)
	farm.harvest(_target)
	# ★ [S1-5a] 다수확(황천포도 2~3) — yield_range를 굴려 그만큼 적재(greybox-spec §6.5, 데이터는 S1-4 검증).
	#   기본형(1~1)은 1개 그대로. 점수판(_run_harvested)·사연은 수확 액션당 1(영혼 1 = 사연 1)로 둔다.
	#   ★ [S1-6 §8.5] 품질 격리: 주 수확분(첫 1개)만 roll 등급, 다수확 추가분은 Q0 강제.
	var yr := CropCatalog.yield_range(harvested_crop)
	var count := randi_range(yr.x, yr.y)
	for i in count:
		inventory.add_harvest(harvested_crop, 1, quality if i == 0 else 0)
	_toast_item(ItemCatalog.harvest_id(harvested_crop), count)   # ★ Phase C 획득 토스트(수확)
	_gain_farm_xp(CropCatalog.sell_price(harvested_crop))  # ★ 수확 성공 XP(§8.9)+레벨업 감지
	_run_harvested += 1                       # T4.2 슬라이스 점수판: 거둔 영혼 총수(수확 액션당 1)
	_show_flavor(harvested_crop)              # T3.5 그 영혼의 생전 사연 한 줄을 띄운다
	audio.sfx("harvest")                      # P2.6 수확은 밝은 팝
	_advance_onboarding("수확")               # T4.1 첫 수확 → 온보딩 완료(DONE)
	energy.spend(cost)                        # 한 동작당 혼력 소모(숙련 감산)
	queue_redraw()                            # 새 상태가 바로 보이도록

# ★ ADR-0052 §118 · ADR-0033 — 안식 꽃 패치(피안화) 손수확. 라이브 채집 루프의 XP 소스이자 전문직 퍼크
#   실효점. 전체 사슬을 살린다: 따기 → 채집물+채집 XP → 레벨업 → picker 전문직 선택 → 퍼크(품질 하한·2배)
#   실효. ★혼력 0(ADR-0033 #1 "줍기=혼력0" — 유일 무비용 산출 루프, "평평≠막힘" 안전판). 품질·수량은
#   채집 레벨/전문직이 소스(밭 비료 roll과 대비 — 스킬 주도 replace, ADR-0033 #3 개정).
func _pick_flower(tile: Vector2i) -> void:
	if not flower.pick(tile, clock.day):
		return   # 안 폈거나 패치 아님(디스패치가 걸렀지만 방어)
	var lvl := _skill_level(ProfessionCatalog.FORAGING)
	# 품질 = 채집 레벨 기본 등급, 약초학자 하한(이리듐)과 max(퍼크가 base를 끌어올림). ADR-0052.
	var quality := maxi(_forage_base_quality(lvl), forage_quality_floor())
	# 수량 = 기본 1, 채집꾼이면 double_drop 확률로 2배(추가분도 동일 등급 — 채집물은 밭 다수확과 달리
	#   품질 격리 없음: 한 포기에서 두 송이라 등급 동일). ADR-0052 DIM_DOUBLE_DROP.
	var count := 1
	if randf() < forage_double_drop_chance():
		count = 2
	inventory.add_item(ItemCatalog.SPIRIT_FLOWER, count, quality)
	_toast_item(ItemCatalog.SPIRIT_FLOWER, count)   # ★ Phase C 획득 토스트
	_gain_forage_xp(ItemCatalog.price_of(ItemCatalog.SPIRIT_FLOWER))  # ★ 채집 XP(기준가 기반, 수확=farm XP 결)+레벨업 감지
	audio.sfx("harvest")                      # 채집도 밝은 팝(수확 결)
	# ★ 혼력 소모 없음(ADR-0033 #1) · 온보딩은 농사 동사 체인이라 여긴 안 건드림. queue_redraw로 새 상태 반영.
	queue_redraw()

# 선택 슬롯이 씨앗/수확물이면 _selected_crop(선물·구매·HUD 기준 작물)을 그 작물군으로 맞춘다.
# 도구를 들었을 땐 마지막 작물을 유지한다(선물·매대가 기억된 작물로 동작). Q 작물 순환의 대체 —
# 이제 작물 선택은 핫바에서 씨앗·수확물을 고르는 것으로 자연히 따라온다(별도 순환 키 없음).
func _sync_selected_crop() -> void:
	var sid := inventory.selected_id()
	var cat := ItemCatalog.category_of(sid)
	if cat == ItemCatalog.CAT_SEED:
		_selected_crop = ItemCatalog.crop_of(sid)
	elif cat == ItemCatalog.CAT_HARVEST:
		_selected_crop = sid

# ★ ADR-0024 핫바 HUD 한 줄: 선택 슬롯 번호 + 든 아이템 이름 + 선택 안내. 든 게 씨앗이면 보유 수·
# 성장일수를, 수확물이면 보유 수를 덧붙여 "지금 무엇을 들고 무엇을 할 수 있나"를 한눈에 보인다.
func _hotbar_summary() -> String:
	var sid := inventory.selected_id()
	var held := ItemCatalog.name_of(sid) if sid != "" else "(빈 손)"
	var line := "핫바 %d번 · 든 것: %s   [1~0,-,= / 휠] 선택" % [inventory.selected_index + 1, held]
	match ItemCatalog.category_of(sid):
		ItemCatalog.CAT_SEED:
			line += "  (보유 %d · %d일)" % [inventory.count_of(sid), CropCatalog.growth_days(ItemCatalog.crop_of(sid))]
		ItemCatalog.CAT_HARVEST:
			line += "  (보유 %d)" % inventory.count_of(sid)
	return line

# ★ [S1-7] 짐승 프롬프트: 조준한 짐승에 대해 산물 수집/쓰다듬(RMB)·건초 급여(LMB, 든 게 건초일 때) 안내.
# 우정 하트를 곁들여 "지금 이 짐승에 뭘 할 수 있나"를 한눈에 보인다. 오늘 케어가 끝났으면 완료 안내.
func _animal_prompt(t: Vector2i) -> String:
	var nm := AnimalCatalog.name_of(ranch.species_at(t))
	var hearts := ranch.hearts_of(t)
	# ★ [Phase E/S1-15] 새끼는 이름에 성장 상태를 붙인다(산물은 안 냄 — 급여·쓰다듬으로 우정만 쌓임).
	var baby: bool = not ranch.is_adult(t)
	var label := nm
	if baby:
		label = "%s 새끼 (성장 중 %d일 남음)" % [nm, ranch.days_to_adult(t)]
	var parts: Array = []
	if ranch.has_product(t):   # 산물은 성체만 낸다 → 새끼는 이 분기에 안 걸린다.
		parts.append("[우클릭] %s 산물 수집" % nm)
	elif not ranch.is_petted(t):
		parts.append("[우클릭] %s 쓰다듬기" % label)
	if inventory.selected_id() == ItemCatalog.HAY and not ranch.is_fed(t):
		parts.append("[좌클릭] 건초 급여")   # 새끼도 급여로 우정을 쌓아 성체 되는 즉시 좋은 산물.
	if parts.is_empty():
		return "%s ♥%d — 오늘 돌봄 완료" % [label, hearts]
	return "%s   (♥%d)" % ["  ".join(parts), hearts]

# ★ [S1-8] 개간 프롬프트: 조준한 debris에 대해 맞는 도구면 [좌클릭] 개간, 아니면 필요한 도구를 안내한다.
# 든 도구가 맞을 때만 동사를 보이는 ADR-0024 §2의 HUD 짝(틀린 도구 = "무슨 도구가 필요한지"만).
func _debris_prompt(kind: String) -> String:
	var tool_id := DebrisCatalog.tool_for(kind)
	var tool_nm := ItemCatalog.name_of(tool_id)
	if inventory.selected_id() == tool_id:
		if not energy.can_act(_farming_energy_cost()):
			return "혼력 부족 — 집에서 취침"
		return "[좌클릭] 개간 (%s)" % tool_nm
	return "%s 필요 — 개간 대상" % tool_nm

# 밭 칸 프롬프트: 든 도구·칸 상태에서 다음에 할 수 있는 동작을 파생한다("" = 안내 없음).
# 맨손 수확(RMB)은 도구와 무관하게 다 자란 칸이면 항상 안내한다. 그 외엔 든 도구가 칸 상태에
# 맞을 때만 [좌클릭] 동사를 보인다(안 맞으면 "" — 자동 분기 없음의 HUD 짝, ADR-0024 §2).
func _farm_prompt() -> String:
	# ★ [S1-5b] 혼의 나무 우선(밭 SOIL 판정과 무관 — 과수는 풋프린트 조준). 성숙+결실이면 수확 안내,
	# 든 게 묘목이면 심기 안내(안식 농원 전용). _target_valid(SOIL) 게이트보다 먼저 본다.
	if _region == RegionCatalog.HOME:
		var anchor := orchard.tree_at(_target)
		if orchard.has_tree(anchor):
			if not energy.can_act():
				return "혼력 부족 — 집에서 취침"
			var n := orchard.fruit_count_of(anchor)
			if orchard.is_mature(anchor, clock.day) and n > 0:
				return "[우클릭] 혼의 나무 수확 (%d개)" % n
			return ""   # 아직 안 자랐거나 결실 없음 — 조용히(비제철/성장 중)
		var held := inventory.selected_id()
		if ItemCatalog.category_of(held) == ItemCatalog.CAT_SAPLING:
			var fruit := ItemCatalog.fruit_of(held)
			if inventory.has_sapling(fruit):
				if not energy.can_act():
					return "혼력 부족 — 집에서 취침"
				if orchard.can_plant(_target, _is_tree_blocked):
					return "[좌클릭] %s 묘목 심기 (3×3)" % FruitTreeCatalog.name_of(fruit)
				return "여기엔 못 심음 — 3×3 빈 자리 필요"
	if not _target_valid:
		return ""
	if not energy.can_act():
		return "혼력 부족 — 집에서 취침"
	if farm.is_mature(_target):
		return "[우클릭] 수확"
	var item := inventory.selected_id()
	if item == ItemCatalog.HOE and not farm.is_tilled(_target):
		return "[좌클릭] 괭이질"
	if item == ItemCatalog.WATERING_CAN and farm.is_planted(_target) and not farm.is_watered(_target):
		return "[좌클릭] 물주기"
	if ItemCatalog.category_of(item) == ItemCatalog.CAT_SEED and farm.is_tilled(_target) and not farm.is_planted(_target):
		var crop := ItemCatalog.crop_of(item)
		if inventory.has_seed(crop):
			return "[좌클릭] %s 심기" % CropCatalog.name_of(crop)
		return "%s 씨앗 없음 — 카페·만물상에서 구매" % CropCatalog.name_of(crop)
	# ★ [S1-6] 든 게 비료면 경작 칸에 뿌리기 안내(심김/빈칸 무관 — overwrite, §8.4).
	if ItemCatalog.category_of(item) == ItemCatalog.CAT_FERTILIZER and farm.is_tilled(_target):
		return "[좌클릭] %s 뿌리기" % ItemCatalog.name_of(item)
	return ""

# ── T3.5 사연 한 줄 ────────────────────────────────────────────────────────
# 방금 거둔 작물(영혼)의 생전 사연 한 줄을 팝업으로 띄운다(CONTEXT '사연 한 줄').
# 작물별 수확 누적 횟수를 index로 넘겨 거둘 때마다 다음 사연으로 순환시킨다(결정적).
# 사연 데이터(SoulMemory)는 알지만 어떻게 표시할지는 main이 정한다(데이터 디커플링).
func _show_flavor(crop_id: String) -> void:
	var seen: int = _harvest_seen.get(crop_id, 0)
	var line := SoulMemory.line(crop_id, seen)
	_harvest_seen[crop_id] = seen + 1
	if line == "":
		return  # 사연이 없는 작물이면 조용히 넘어간다(표시할 게 없음)
	_notice(line, FLAVOR_SECS)

# ── ★ C2 공통 프레임 열기/닫기(메뉴/출하함/매대 모달) ───────────────────────
# 프레임을 컨텍스트로 연다 — 이동을 잠그고(대화·취침과 같은 결) 핫바를 숨긴다(프레임이 백팩을
# 그리므로 이중 표시 방지). 닫으면 되돌린다. 메뉴는 Tab 어디서든, 출하함은 facing_bin 우클릭,
# 매대는 facing_neo F가 부른다(위 _process 입력 체인). 한 번에 한 컨텍스트만 열린다.
func _open_frame(ctx: int) -> void:
	if ctx == InventoryFrame.CTX_STORE:
		frame.store_text = _store_text()   # 첫 그림부터 매대 본문이 차 있게(한 프레임 빈 패널 방지)
	frame.open(ctx)
	hotbar.visible = false
	player.set_physics_process(false)   # 모달 — 이동 잠금
	player.velocity = Vector2.ZERO
	audio.sfx("ui")                     # 패널 열림 블립(옛 출하대·매대와 같은 SFX)

func _close_frame() -> void:
	frame.close()
	hotbar.visible = true
	player.set_physics_process(true)

# ── ★ C2 무인 출하함 드롭/롤백(프레임 시그널 핸들러) ──────────────────────────
# 출하함 패널에서 백팩 수확물 슬롯을 클릭하면 그 슬롯을 통째로 출하 대기에 넣는다(인벤토리에서
# 빠짐 → ship_bin pending). 수확물만 받는다(씨앗·도구는 드롭 불가 — 출하 = 판매). 익일 아침
# day_advanced에서 settle이 골드로 정산한다(즉시판매 제거 — 스타듀 출하상자 결, ADR-0021).
func _on_frame_deposit(slot_index: int) -> void:
	var id := inventory.id_at(slot_index)
	if id == "" or ItemCatalog.category_of(id) != ItemCatalog.CAT_HARVEST:
		return   # 수확물 외(씨앗·도구·비료)는 출하 대상이 아니다 — 무동작
	var n := inventory.count_at(slot_index)
	var q := inventory.quality_at(slot_index)   # ★ S1-6 이 슬롯의 등급을 함께 출하(worst-first 오염 방지 = 슬롯 지정 제거)
	if not inventory.remove_at(slot_index, n):
		return
	ship_bin.add(id, n, q)
	audio.sfx("ui")
	var qtag := (ItemCatalog.quality_name(q) + " ") if q > 0 else ""
	_notice("출하함에 %s%s %d개 (다음 아침 정산)" % [qtag, ItemCatalog.name_of(id), n])

# 출하함 대기 슬롯을 클릭하면 그 분을 통째로 인벤토리에 도로 넣는다(취침 전 롤백 — "잘못 넣었네"
# 회수). 인벤토리가 가득 차 일부만 들어가면 그만큼만 빼낸다(들어간 만큼만 대기에서 차감).
func _on_frame_takeback(id: String) -> void:
	# ★ S1-6: 품질별로 나눠 회수해 등급을 보존한다(출하함이 은/금을 나눠 들므로, 그대로 슬롯에 되돌림).
	var quals: Array = ship_bin.qualities_of(id)
	if quals.is_empty():
		return
	var restored := 0
	for q in quals.duplicate():   # 회수하며 pending을 줄이므로 키 스냅샷
		var cnt := ship_bin.count_of_quality(id, int(q))
		var added := 0
		for _i in cnt:
			if not inventory.add_item(id, 1, int(q)):
				break   # 인벤토리 가득 — 더는 못 받는다
			added += 1
		if added > 0:
			ship_bin.take_back(id, added, int(q))
			restored += added
	if restored > 0:
		audio.sfx("ui")
		_notice("출하함에서 %s %d개 회수" % [ItemCatalog.name_of(id), restored])

# ★ Phase E — 상자를 연다. 활성 상자를 target으로 바꾸고(프레임에 주입) CTX_CHEST 패널을 연다. 집·창고
# 상자가 같은 패널을 공유하되 여는 순간 대상이 갈린다(보관/회수 핸들러는 _active_chest를 조작).
func _open_chest(target: StorageChest) -> void:
	if target == null:
		return
	_active_chest = target
	frame.set_chest(target)
	_open_frame(InventoryFrame.CTX_CHEST)

# ── ★ ADR-0048 Phase D 저장 상자 보관/회수(프레임 시그널 핸들러) ────────────────
# 백팩 슬롯을 통째로 상자에 옮긴다(경제 0 — 판매 아님). 출하함 드롭과 달리 종류 제한이 없다(도구·씨앗·
# 수확물 다 보관). 상자가 가득이면 못 넣는다(store 반환 0). 넣은 만큼만 백팩에서 뺀다(부분 이동 안전).
func _on_frame_chest_store(slot_index: int) -> void:
	if _active_chest == null:   # ★ Phase E — 활성 상자(집/창고, 여는 순간 결정)에 넣는다.
		return
	var id := inventory.id_at(slot_index)
	if id == "":
		return
	var n := inventory.count_at(slot_index)
	var q := inventory.quality_at(slot_index)
	var stored := _active_chest.store(id, n, q)
	if stored <= 0:
		_notice("저장 상자가 가득 찼습니다")
		return
	inventory.remove_at(slot_index, stored)   # 넣은 만큼만 차감(상자 가득 부분 이동 안전)
	audio.sfx("ui")
	_notice("저장 상자에 %s %d개 보관" % [ItemCatalog.name_of(id), stored])

# 상자 슬롯을 통째로 백팩에 되돌린다. 백팩이 가득 차 일부만 들어가면 그만큼만 상자에서 뺀다(출하함 회수 결).
func _on_frame_chest_take(chest_index: int) -> void:
	if _active_chest == null:   # ★ Phase E — 활성 상자에서 회수.
		return
	var e: Dictionary = _active_chest.peek(chest_index)
	if e.is_empty():
		return
	var id: String = str(e.get("id", ""))
	var q := int(e.get("quality", 0))
	var cnt := int(e.get("count", 0))
	var added := 0
	for _i in cnt:
		if not inventory.add_item(id, 1, q):
			break   # 백팩 가득 — 더는 못 받는다
		added += 1
	if added <= 0:
		_notice("백팩이 가득 찼습니다")
		return
	_active_chest.remove_at(chest_index, added)
	audio.sfx("ui")
	_notice("저장 상자에서 %s %d개 회수" % [ItemCatalog.name_of(id), added])

# ── ★ C2 네오 만물상 매대 구매(프레임 시그널 핸들러) ──────────────────────────
# 매대에서 [구매] 버튼을 클릭하면 선택 작물 씨앗을 네오 할인가로 산다. bulk(Shift)=대량(BULK개,
# 골드 닿는 데까지). ★ 만물상은 *구매 전용·구매 일원화* — 멜 출하대 씨앗 구매(_buy_seed)가
# 사라져 씨앗은 네오 매대에서만 산다(ADR-0021 구매 네오 일원화). 판매는 무인 출하함.
const STORE_BULK := 5   # Shift 대량 구매 묶음 크기(스타듀 묶음 결)
func _on_frame_buy(bulk: bool) -> void:
	_buy_seed_store_n(_selected_crop, STORE_BULK if bulk else 1)

# 선택 작물 씨앗 1개를 *네오 할인가*로 산다(매대 클릭 단건). 골드가 모자라면 막는다.
func _buy_seed_store(crop_id: String) -> void:
	_buy_seed_store_n(crop_id, 1)

# 선택 작물 씨앗을 네오 할인가로 n개까지 산다(골드 닿는 데까지 — 부분 구매 허용). 한 개도 못
# 사면 골드 부족을 알린다. 가격은 정가(seed_cost)에 네오 호감도 할인을 먹인 값(StoreDiscount).
func _buy_seed_store_n(crop_id: String, n: int) -> void:
	var base := CropCatalog.seed_cost(crop_id)
	if base <= 0 or n <= 0:
		return
	var unit := StoreDiscount.price(base, neo_affinity.hearts())
	var bought := 0
	for _i in n:
		if not wallet.spend(unit):
			break
		inventory.add_seed(crop_id)
		bought += 1
	if bought == 0:
		_notice("골드 부족(%d 필요)" % unit)
		return
	audio.sfx("ui")                           # 매대 거래 블립(씨앗 구매)
	_notice("%s 씨앗 ×%d −%d골드 (만물상)" % [CropCatalog.name_of(crop_id), bought, unit * bought])

# 네오 만물상 매대 패널 본문(프레임 상단에 그릴 텍스트 — 골드·할인율·씨앗 할인가). 정가 대비
# 할인가를 함께 보여 줘 "친해질수록 싸진다"는 퍼크를 거래 시점에 체감하게 한다(읽기용 문자열).
func _store_text() -> String:
	var sel := _selected_crop
	var base := CropCatalog.seed_cost(sel)
	var hearts := neo_affinity.hearts()
	var cost := StoreDiscount.price(base, hearts)
	# 할인이 걸렸으면 "정가→할인가"를, 정가면 가격 하나만 보인다(♡0 평평≠막힘).
	var price_line := "%s 씨앗  −%d골드  · 보유 %d" % [CropCatalog.name_of(sel), cost, inventory.seed_count(sel)]
	if cost < base:
		price_line = "%s 씨앗  정가 %d → −%d골드  · 보유 %d" % [CropCatalog.name_of(sel), base, cost, inventory.seed_count(sel)]
	return "\n".join([
		"── 네오의 만물상 매대 ──",
		"골드 %d" % wallet.gold,
		StoreDiscount.summary(hearts),
		price_line,
	])

# 관계 탭(메뉴) 하트 행 — 미호·멜·바나·네오 호감도를 읽기 전용으로 프레임에 넘긴다(HeartBar 재사용).
# affinity 노드들에서 매번 파생하므로 별도 상태가 없다(여기서 호감도를 바꾸지 않는다 — 읽기 전용).
# ★ C3 — 각 캐릭터의 관계 곱셈기(여우불·마진·경비·할인)를 effect 줄로 함께 넘긴다. 상시 HUD에서
#   걷어낸 그 정보가 사라지지 않고 관계 탭에서 복기되게 한다(ADR-0008 관계=곱셈기를 한자리에).
func _heart_rows() -> Array:
	return [
		{"name": "미호", "filled": affinity.hearts(), "total": Affinity.MAX_HEARTS,
			"effect": Foxfire.summary(affinity.hearts())},
		{"name": "멜", "filled": mel_affinity.hearts(), "total": Affinity.MAX_HEARTS,
			"effect": CafeMargin.summary(mel_affinity.hearts())},
		{"name": "바나", "filled": bana_affinity.hearts(), "total": Affinity.MAX_HEARTS,
			"effect": BanaGuard.summary(bana_affinity.hearts())},
		{"name": "네오", "filled": neo_affinity.hearts(), "total": Affinity.MAX_HEARTS,
			"effect": StoreDiscount.summary(neo_affinity.hearts())},
	]

# ★ Phase B 숙련 탭 행(_heart_rows와 대칭 — FarmSkill에서 레벨·진행 파생, 읽기 전용). 현재 농사 1종.
# floor_xp=현 레벨 진입 임계, next_xp=다음 레벨 임계(만렙이면 0). 프레임이 (xp-floor)/(next-floor)로 진행바.
func _skill_rows() -> Array:
	# ★ ADR-0052 — 농사·채집 2행(FarmSkill 곡선 공유). 전문직 요약·선택가능 tier도 파생(읽기 전용).
	return [
		_skill_row("농사", ProfessionCatalog.FARMING, _farming_xp),
		_skill_row("채집", ProfessionCatalog.FORAGING, _foraging_xp),
	]

# 한 스킬 행 조립 — 레벨/진행바 + 고른 전문직 이름 요약 + 지금 고를 수 있는 tier(0=없음).
func _skill_row(display_name: String, skill: String, xp: int) -> Dictionary:
	var lv := FarmSkill.level_for_xp(xp)
	var floor_xp := 0 if lv <= 0 else int(FarmSkill.XP_THRESHOLDS[lv - 1])
	var next_xp := 0 if lv >= FarmSkill.MAX_LEVEL else int(FarmSkill.XP_THRESHOLDS[lv])
	var chosen: Array = []
	for tier in [5, 10]:
		var pid := _profession_at(skill, tier)
		if pid != "":
			chosen.append(ProfessionCatalog.name_of(skill, pid))
	# 지금 고를 수 있는 전문직 목록(프레임이 버튼으로 그림 — main이 자격 판정, 프레임은 무상태 렌더).
	# pt==0이면 tier_profs가 빈 배열이라 options=[](선택 UI 미표시).
	var pt := _pending_profession_tier(skill)
	var options: Array = []
	for p in ProfessionCatalog.tier_profs(skill, pt):
		if _can_choose_profession(skill, p["id"]):
			options.append({"id": p["id"], "name": p["name"], "desc": p["desc"]})
	return {"name": display_name, "level": lv, "max": FarmSkill.MAX_LEVEL, "xp": xp,
		"floor_xp": floor_xp, "next_xp": next_xp,
		"skill": skill, "profession": ", ".join(chosen), "pending_tier": pt, "options": options}

# ★ Phase B 옵션 탭 핸들러 — 프레임은 신호만, 실제 저장·종료는 main이 수행(지갑·세이브 소유).
# ★ ADR-0052 — 숙련 탭 전문직 선택 버튼 핸들러. choose_profession이 자격을 재검증(레벨/슬롯/부모)하므로
# 프레임 신호를 그대로 위임한다(프레임은 지갑·상태를 모름 — 옵션 탭 저장/나가기와 같은 결). 다음 프레임
# set_skills가 옵션을 갱신하지만 즉시 반영을 위해 재주입한다(버튼이 바로 사라지고 요약이 갱신되게).
func _on_frame_profession(skill: String, prof_id: String) -> void:
	if choose_profession(skill, prof_id):
		frame.set_skills(_skill_rows())

func _on_frame_save() -> void:
	_save_game()
	_notice("저장했습니다")

func _on_frame_quit() -> void:
	_save_game()
	get_tree().quit()

# ── T4.1 온보딩 ────────────────────────────────────────────────────────────
# 신규 시작(또는 통보 단계 복원)이면 옥자 오프닝 통보를 자동으로 띄운다(CONTEXT
# '온보딩': 도착 → 옥자 통보). 옥자를 드러내고 이동을 잠근 뒤 통보 대사를 시작한다.
# 통보 단계가 아니거나 이미 대화 중이면 아무 일도 하지 않는다(중복·오작동 방어).
func _maybe_start_intro() -> void:
	if not onboarding.is_intro() or dialogue.is_open():
		return
	okja.visible = true
	player.set_physics_process(false)  # 통보 중 이동 잠금(미호 대화·취침과 같은 결)
	player.velocity = Vector2.ZERO
	_talking_to = okja.display_name()
	dialogue.start(okja.display_name(), okja.lines())

# ── T5.6 NPC 상주/출퇴근 ────────────────────────────────────────────────────
# 미호 출퇴근: 카페 영업 시작(15시, Cafe.OPEN_MIN)을 경계로 아침엔 밭, 오후엔 카페로
# 자리를 옮긴다(하루 1회 전환 — 직원이 오후 카페에 모이는 무대, ADR-0007). 칸이 실제로
# 바뀔 때만 위치를 옮긴다(매 프레임 호출되지만 전환은 하루 한 번뿐). 위치는 main이
# 소유하므로(미호 메모) 여기서 칸을 정하고, facing/농사 제외는 _miho_tile을 따라간다.
# T5.6/★M1.4 — 미호 출퇴근이 구역 경계를 넘는다: 아침엔 안식 농원 밭(MIHO_FIELD_TILE), 영업
# 시작(15시)부터 나루 마을 카페(MIHO_CAFE_TILE). 두 자리가 서로 다른 구역이라, 위치 갱신에 더해
# *가시성*도 구역으로 가른다 — 플레이어가 미호와 같은 구역에 있을 때만 보인다(밭 자리는 농원,
# 카페 자리는 마을). 이 게이팅이 없으면 마을 야외(밭 좌표와 겹침)에 미호가 떠 보인다. 위치는
# 항상 현재 station 칸 중앙으로 둔다(세이브 무상태 — 헤드리스 테스트가 위치/칸으로 검증).
func _update_miho_station() -> void:
	var t := MIHO_CAFE_TILE if clock.minutes >= Cafe.OPEN_MIN else MIHO_FIELD_TILE
	if t != _miho_tile:
		_miho_tile = t
		miho.position = _tile_center_px(_miho_tile)
	var miho_region := RegionCatalog.NARU_VILLAGE if _miho_tile == MIHO_CAFE_TILE else RegionCatalog.HOME
	miho.visible = _region == miho_region

# 옥자 상주: 오프닝 통보를 마친 뒤(NOTICE 단계를 지남)엔 카페 상주 자리에 드러낸다(매일
# 보는 사장 — 풀 관계 트랙 없음, ADR-0005). 통보 단계(또는 세이브 없는 신규 시작)면 통보
# 흐름(_maybe_start_intro)이 위치·표시를 관리하므로 여기선 손대지 않는다. 멱등이라 로드
# 직후·통보 종료 양쪽에서 불려도 안전하다(세이브 무상태 — 단계에서 매번 파생).
func _refresh_okja_station() -> void:
	if onboarding.step > Onboarding.NOTICE:
		okja.position = _tile_center_px(OKJA_CAFE_TILE)
		okja.visible = true

# T6.1 바나 밤 등장: 밤(빈 밤 슬롯 19시, Cafe.CLOSE_MIN)에만 밤 무대에 드러난다(낮엔 숨김 —
# 미호 출퇴근·옥자 상주처럼 시각에서 매 프레임 파생되는 무상태 배치). 통보(NOTICE) 도중엔
# 숨겨 둔다(옥자 가드와 같은 결 — 오프닝 컷신 동안 밤 무대가 끼어들지 않게). 위치는 _ready에서
# 한 번 고정했으므로 여기선 가시성만 토글한다. 밤 영업창 옵트인·잡귀(T6.3+)는 범위 밖이라,
# 지금은 바나가 밤에 그냥 서 있어 말 걸 수 있을 뿐이다(T6.1 — 배치 + 대사 텍스트박스).
func _update_bana_station() -> void:
	bana.visible = clock.minutes >= Cafe.CLOSE_MIN and onboarding.step > Onboarding.NOTICE

# ── T4.2/T7.3 슬라이스 종료 ─────────────────────────────────────────────────
# 슬라이스가 끝나면(또는 그 세이브를 이어받으면) 시계를 멈추고 이동을 잠근 뒤 마무리
# 점수판을 띄운다. 멱등(_run_over 가드)이라 취침 종료·로드 양쪽에서 불려도 한 번만
# 세운다. 끝 판정·문구는 RunSummary가, 표시·잠금은 main이 맡는다(데이터/표시 디커플링).
func _end_run() -> void:
	if _run_over:
		return
	_run_over = true
	clock.running = false
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	# T5.4 카페 정산 팝업은 마무리 화면보다 위에 그려질 수 있어 명시적으로 숨긴다.
	cafe_summary_panel.visible = false
	# 알림 피드·디버그 리드아웃은 코드로 $CanvasLayer에 나중 추가돼 EndingPanel 위에
	# 그려지므로(트리순서상 위), 마무리 화면이 깔끔히 덮이게 같이 숨긴다.
	if notice_feed != null:
		notice_feed.visible = false
	readout.visible = false
	# 그 밖의 패널·프롬프트는 마무리 화면(전체 화면 불투명 패널)이 덮으므로 따로 숨기지 않는다.
	ending_text.text = RunSummary.text(
		clock.day, wallet.gold, affinity.heart_bar(),
		affinity.hearts(), Affinity.MAX_HEARTS, _run_harvested
	)
	ending_panel.visible = true

# 밭 동작 한 번이 온보딩 단계를 다음으로 넘긴다(각자 해당 단계일 때만 — 멱등·순서
# 안전). 밭의 강제 순서(괭이질→심기→물주기→수확)가 그대로 튜토리얼 진행이 된다.
func _advance_onboarding(action: String) -> void:
	match action:
		"괭이질":
			onboarding.tilled()
		"심기":
			onboarding.planted()
		"물주기":
			onboarding.watered()
		"수확":
			onboarding.harvested()

# ── T3.2 미호 대화 ─────────────────────────────────────────────────────────
# 말 걸면 텍스트박스가 뜨고, E로 끝까지 넘기면 닫힌다(완료기준). 대사 내용은 미호가
# 들고 오고(ADR-0005), 진행·열림은 DialogueBox가, 패널 표시·이동잠금은 main이 맡는다.
func _start_dialogue() -> void:
	# T3.3 일일 대화: 오늘 첫 대화면 호감도를 소폭 올린다(하루 1회, Affinity가 게이팅).
	# 보상 여부(first_today)와 현재 하트 단계로 어떤 대사를 들려줄지 미호가 고른다.
	var first_today := affinity.daily_talk(clock.day)
	var lines := miho.lines(affinity.hearts(), first_today)
	# 대사가 없으면 시작하지 않는다(이동을 잠근 채 못 닫는 상태 방지).
	if lines.is_empty():
		return
	player.set_physics_process(false)  # 대화 중 이동 잠금(취침 연출과 같은 결)
	player.velocity = Vector2.ZERO
	_talking_to = miho.display_name()
	dialogue.start(miho.display_name(), lines)

# ── T5.1/T5.2 멜 대화 ──────────────────────────────────────────────────────
# 말 걸면 텍스트박스가 뜨고, E로 끝까지 넘기면 닫힌다. 미호 대화와 같은 결 — 대사는
# 멜이 들고 오고(ADR-0005), 진행·열림은 DialogueBox가, 표시·이동잠금은 main이 맡는다.
# T5.2 일일 대화: 오늘 첫 대화면 멜 호감도를 소폭 올린다(하루 1회, MelAffinity가 게이팅).
# 보상 여부(first_today)와 현재 하트 단계로 어떤 대사를 들려줄지 멜이 고른다(_start_dialogue 대칭).
func _start_mel_dialogue() -> void:
	var first_today := mel_affinity.daily_talk(clock.day)
	var lines := mel.lines(mel_affinity.hearts(), first_today)
	if lines.is_empty():
		return
	player.set_physics_process(false)  # 대화 중 이동 잠금(미호 대화와 같은 결)
	player.velocity = Vector2.ZERO
	_talking_to = mel.display_name()
	dialogue.start(mel.display_name(), lines)

# ── M2.3 네오(만물상 점주) 대화 ─────────────────────────────────────────────
# 만물상에서 네오에게 말 걸면 대사를 들려준다(멜 대화와 같은 결 — 대사는 네오가 든다, ADR-0005).
# 일일 대화: 오늘 첫 대화면 네오 호감도를 소폭 올린다(하루 1회, neo_affinity가 게이팅). ★ 이 슬라이스는
# 선물 채널 없이 *대화 한 채널*로만 친해진다 — 네오의 풀 T1 트랙(선물·하트 이벤트·결혼)은 후속(ADR-0014
# 한 명씩). 보상 여부(first_today)와 현재 하트로 어떤 대사(낯섦/단골/친근)를 들려줄지 네오가 고른다(_start_mel_dialogue 대칭).
# 화자(_talking_to=네오)는 온보딩 단계 화자가 아니라 _on_dialogue_finished에서 그냥 닫힌다(멜과 동일).
func _start_neo_dialogue() -> void:
	var first_today := neo_affinity.daily_talk(clock.day)
	var lines := neo.lines(neo_affinity.hearts(), first_today)
	if lines.is_empty():
		return
	player.set_physics_process(false)  # 대화 중 이동 잠금(멜 대화와 같은 결)
	player.velocity = Vector2.ZERO
	_talking_to = neo.display_name()
	dialogue.start(neo.display_name(), lines)

# ── T5.6 옥자(카페 상주) 일상 대화 ──────────────────────────────────────────
# 통보 후 카페에 상주하는 옥자에게 말 걸면 일상 대사를 들려준다(미호·멜 대화와 같은 결).
# 호감도·선물 없는 메인 서사 앵커라(ADR-0005) 일일 게이팅·점수 보상 없이 대사만 — 매번
# 같은 묶음(미결의 죄 떡밥 톤)을 들려준다. 대화 종료(_on_dialogue_finished)에서 옥자 화자는
# NOTICE 단계가 아니므로(상주는 통보를 지난 뒤) 온보딩을 전진시키지 않고 그냥 닫힌다.
func _start_okja_dialogue() -> void:
	var lines := okja.lines_resident()
	if lines.is_empty():
		return
	player.set_physics_process(false)  # 대화 중 이동 잠금(미호·멜 대화와 같은 결)
	player.velocity = Vector2.ZERO
	_talking_to = okja.display_name()
	dialogue.start(okja.display_name(), lines)

# ── T6.1/T6.2 바나(밤 무대) 대화 ────────────────────────────────────────────
# 말 걸면 텍스트박스가 뜨고, E로 끝까지 넘기면 닫힌다(완료기준). 미호·멜·옥자 대화와 같은
# 결 — 대사는 바나가 들고 오고(ADR-0005), 진행·열림은 DialogueBox가, 표시·이동잠금은 main이
# 맡는다. T6.2 일일 대화: 오늘 첫 대화면 바나 호감도를 소폭 올린다(하루 1회, BanaAffinity가
# 게이팅). 보상 여부(first_today)와 현재 하트 단계로 어떤 대사를 들려줄지 바나가 고른다
# (_start_dialogue·_start_mel_dialogue 대칭). _talking_to를 바나로 두지만, 바나는 온보딩 화자
# (옥자=NOTICE·미호=MEET_MIHO)가 아니라 _on_dialogue_finished의 두 분기를 모두 비껴가 온보딩을
# 전진시키지 않는다(멜과 같은 결 — 오전진 0).
func _start_bana_dialogue() -> void:
	var first_today := bana_affinity.daily_talk(clock.day)
	var lines := bana.lines(bana_affinity.hearts(), first_today)
	if lines.is_empty():
		return
	player.set_physics_process(false)  # 대화 중 이동 잠금(미호·멜·옥자 대화와 같은 결)
	player.velocity = Vector2.ZERO
	_talking_to = bana.display_name()
	dialogue.start(bana.display_name(), lines)

# T6.2 바나 선물: 선택 작물(_selected_crop) 수확물 1개를 건네 바나 호감도를 올린다. 선호
# 작물(혼령초)이면 더 크게 오른다. 하루 1회만(BanaAffinity가 게이팅). _try_mel_gift와 대칭.
func _try_bana_gift() -> void:
	var crop := _selected_crop
	if inventory.harvest_count(crop) <= 0:
		_notice("%s 수확물이 없다" % CropCatalog.name_of(crop))
		return
	if not bana_affinity.can_gift(clock.day):
		_notice("오늘은 이미 바나에게 선물했다")
		return
	inventory.take_harvest(crop)              # 선물한 수확물 1개 소모
	var gained := bana_affinity.gift(crop, clock.day)
	var tag := "(선호!) " if bana_affinity.is_preferred(crop) else ""
	audio.sfx("ui")                           # P2.6 선물 건넴 확인 블립(바나)
	_notice("바나에게 %s 선물 %s+%d 호감도" % [CropCatalog.name_of(crop), tag, gained])

# ── T6.3 나라카 바 옵트인 ────────────────────────────────────────────────────
# 밤 창(19–24시)에 바나를 바라보며 F면 바를 연다 — 잡귀·손님이 깃들기 시작하는 옵트인. 안 열면
# 밤은 빈 밤이라 잡귀도 손실도 없다(매일 세금 아님, ADR-0010 #6). open_bar가 창·중복을
# 방어하므로(창 밖이면 false) 여기선 성공했을 때만 알린다.
func _open_night_bar() -> void:
	if night_bar.open_bar(clock.minutes):
		_notice("나라카 바를 열었다 — 잡귀가 깃들고 손님이 든다")

# T6.4 밤 마감(취침 = 밤의 자연스러운 끝) 밤 정산. 이중 손실(약탈 재고·이탈 손님)과 밤 매출을
# 한 줄로 보인다. 자정 전에 자거나 옵트인을 안 했으면 약탈·매출 모두 0이다(ADR-0010 #5·#6).
func _on_night_closed(raided: int, revenue: int, left: int) -> void:
	if revenue > 0:
		audio.sfx("gold")                     # P2.6 밤 바 정산 매출 골드
	_notice("나라카 바 마감 · 밤 매출 %d골드 · 약탈 %d개 · 놓친 손님 %d명" % [revenue, raided, left])

# T6.4 ★ 막기 해소 계약 소비(이중 손실 ㉮ — 막기 실패→재고 약탈). 잡귀가 돌파하면(resolved에
# repelled=false) 약탈량만큼 낮에 쌓은 수확물을 덜어낸다 — *내일* 카페가 굶는 미래 자산 손실
# (잡귀가 낮 농사 산물을 노리니 밤이 밭→재고→서빙 사슬에 묶인다, 직조). 격퇴 성공(repelled)은
# 손실이 없어 흘려보낸다. night_bar는 '어떻게 격퇴했는지'도 재고가 무엇인지도 모른 채 계약만
# 쏘고, 약탈의 실제 적용은 여기서 한다(디커플링 — Phase 3 전투가 막기 구현만 교체해도 불변).
func _on_night_resolved(result: Dictionary) -> void:
	# T6.5 ㉠ 자동 차단: 내가 못 막은 돌파를 바나가 대신 막았다(약탈 0). '내 막기'와 구분해
	# 안내하되 손실은 없다 — 못 간 스폿을 바나가 받쳐주는 체감(여우불 '범위'의 밤판, ADR-0010 #7).
	if result.get("auto", false):
		_notice("바나가 못 막은 잡귀를 대신 막았다 (자동 차단)")
		return
	if result.get("repelled", false):
		return
	var want: int = result.get("raided", 0)
	if want <= 0:
		return
	var stolen := _raid_inventory(want)
	if stolen > 0:
		_notice("막지 못했다 — 잡귀가 재고 %d개를 약탈했다" % stolen)
	else:
		_notice("잡귀가 뚫었지만 약탈할 재고가 없었다")  # 무막힘(빈 재고면 잃을 것도 없다)

# 보유 수확물을 앞에서부터(가장 싼 것부터) n개까지 덜어내고 실제 약탈량을 돌려준다. 정액
# 서빙처럼 가장 싼 작물부터 가져간다(비싼 작물은 그래도 남을 확률↑ — 손실의 결을 서빙과 맞춤).
# 재고가 모자라면 있는 만큼만 가져간다(무막힘 — 없는 재고는 잃지 않는다).
func _raid_inventory(n: int) -> int:
	var taken := 0
	while taken < n:
		var id := _cheapest_harvest()
		if id == "":
			break
		inventory.take_harvest(id)
		taken += 1
	return taken

# T6.4 막기: 바라보는 스폿의 잡귀를 즉시 격퇴한다. block이 막기 해소 계약 {repelled, raided}를
# 돌려주고(성공이라 raided=0), 성공도 resolved를 쏘지만 손실이 없어 _on_night_resolved가 흘린다.
# 여기선 격퇴 알림만(HP·무기 없는 얇은 방어 — 전투는 Phase 3 구현 교체, ADR-0010 #2·#8).
func _try_block(spot: int) -> void:
	var result := night_bar.block(spot)
	if result.get("repelled", false):
		audio.sfx("block")                    # P2.6 잡귀를 쳐내는 타격 "퍽"
		_notice("잡귀를 쫓아냈다")

# T6.4 밤 손님 응대: 바 손님을 응대해 정액 밤 매출을 즉시 번다(현재 자산). 카페 서빙과 달리
# 재료를 소모하지 않는다(미래 자산인 재고는 잡귀 약탈 쪽 — ADR-0010 #5 현재/미래 분리).
func _try_night_serve(seat: int) -> void:
	var revenue := night_bar.serve(seat)
	if revenue > 0:
		wallet.earn(revenue)
		_cafe_revenue_total += revenue        # T7.2 카페 마일스톤 누적(밤 응대도 카페/바 운영 매출)
		audio.sfx("serve")                    # P2.6 밤 손님 응대도 같은 서빙 종
		_notice("밤 손님 응대 +%d골드" % revenue)

# T5.2 멜 선물: 선택 작물(_selected_crop) 수확물 1개를 건네 멜 호감도를 올린다. 선호
# 작물(피안화)이면 더 크게 오른다. 하루 1회만(MelAffinity가 게이팅). _try_gift와 대칭.
func _try_mel_gift() -> void:
	var crop := _selected_crop
	if inventory.harvest_count(crop) <= 0:
		_notice("%s 수확물이 없다" % CropCatalog.name_of(crop))
		return
	if not mel_affinity.can_gift(clock.day):
		_notice("오늘은 이미 멜에게 선물했다")
		return
	inventory.take_harvest(crop)              # 선물한 수확물 1개 소모
	var gained := mel_affinity.gift(crop, clock.day)
	var tag := "(선호!) " if mel_affinity.is_preferred(crop) else ""
	audio.sfx("ui")                           # P2.6 선물 건넴 확인 블립(멜)
	_notice("멜에게 %s 선물 %s+%d 호감도" % [CropCatalog.name_of(crop), tag, gained])

# ── T5.4 카페 손님 서빙 ─────────────────────────────────────────────────────
# 기다리는 손님이 앉은 좌석을 서빙한다. 보유 재료(농사 산출물) 1개를 자동 소모하고
# 정액 P 골드를 즉시 번다(농사↔카페를 잇는 첫 매듭). 재료가 없으면 막지만 벌칙은 없다
# (무막힘 — 손님은 인내심이 다하면 그냥 떠난다). 어떤 재료를 쓸지는 가장 싼 수확물부터
# 고른다 — 정액가라 비싼 작물(피안화·영혼 호박)은 raw 판매로 남겨 두는 게 이득이므로
# (공급사슬 긴장: raw 덤프 vs 서빙). 특정 작물 요구·손님 다양성은 2층 서랍(범위 밖).
func _try_serve(seat: int) -> void:
	var material := _cheapest_harvest()
	if material == "":
		_notice("서빙할 재료가 없다 — 수확물이 필요하다")
		return
	inventory.take_harvest(material)          # 서빙 재료 1개 소모(아무 재료 1회)
	var revenue := cafe.serve(seat)           # 정액 P × margin(T5.5에서 마진 분화)
	wallet.earn(revenue)                      # 서빙 즉시 지갑 반영
	_cafe_revenue_total += revenue            # T7.2 카페 마일스톤 누적(서빙 매출 — 카페를 운영한 매출)
	audio.sfx("serve")                        # P2.6 카운터 종 "딩"
	_notice("%s 서빙 +%d골드" % [CropCatalog.name_of(material), revenue])

# 보유 수확물이 하나라도 있는가(서빙 가능 판정·프롬프트용).
func _has_any_harvest() -> bool:
	return inventory.total_harvest() > 0

# 서빙에 쓸 가장 싼 수확물 id("" = 보유 수확물 없음). 정액 서빙가라 비싼 작물은 raw
# 판매로 남기고 싼 작물부터 서빙하는 게 합리적이라, 자동 소모는 최저가 작물을 고른다.
func _cheapest_harvest() -> String:
	var best := ""
	var best_price := -1
	for id in inventory.harvest_ids():
		var price := CropCatalog.sell_price(id)
		if best == "" or price < best_price:
			best = id
			best_price = price
	return best

# T5.4 영업 마감(19시) 정산 팝업. cafe가 그날 누적한 매출·서빙·이탈 수를 받아 한 장으로
# 띄운다(비차단 — CAFE_SUMMARY_SECS 뒤 자동으로 사라진다). cafe는 끝남·수치만, 표시는
# main이 맡는다(RunSummary 점수판과 같은 데이터/표시 디커플링).
func _on_cafe_closed(revenue: int, served: int, left: int) -> void:
	cafe_summary_text.text = "\n".join([
		"── 오늘 카페 영업 마감 ──",
		"매출  +%d골드" % revenue,
		"서빙한 손님  %d명" % served,
		"놓친 손님  %d명" % left,
	])
	cafe_summary_panel.visible = true
	_cafe_summary_secs = CAFE_SUMMARY_SECS
	if revenue > 0:
		audio.sfx("gold")                     # P2.6 카페 일일 정산 매출 골드

# ── T7.2 카페 마일스톤 1단 ──────────────────────────────────────────────────
# 관계 루프 산출물 = 세 동료 하트의 합(미호+멜+바나). 곱셈기들이 각자 하트를 곱셈기로 환류하듯
# (Foxfire·CafeMargin·BanaGuard), 마일스톤은 같은 하트를 *관계 산출물*로 합산해 요구한다 —
# 세 affinity 노드에서 매번 파생되므로 마일스톤이 따로 저장하는 관계 상태는 없다(세이브 무상태).
func _milestone_hearts() -> int:
	return affinity.hearts() + mel_affinity.hearts() + bana_affinity.hearts()

# 카페 1단 완료 여부 — 세 루프 산출물이 *각각* 목표치를 넘었나(AND 게이트, CafeMilestone). 누적
# 거둔 영혼·누적 서빙 매출·세 동료 하트 합에서 파생한다(끝남이 day에서 파생되는 RunSummary와 같은 결).
func _milestone_complete() -> bool:
	return CafeMilestone.is_complete(_run_harvested, _cafe_revenue_total, _milestone_hearts())

# 1단을 채우는 순간 "카페 2단계!" + 2단 미리보기 한 줄을 팝업으로 띄운다(비차단 자동 해제 —
# 카페 마감 정산 팝업과 같은 결). 진짜 2단 콘텐츠는 Phase 3 — 여기선 깊이를 *암시*만 한다
# (ADR-0009, T3.5 사연 한 줄처럼 저비용). 측정 신호 "1단 깨니 2단 갈망하나"의 갈망을 거는 자리.
func _show_milestone_reached() -> void:
	milestone_text.text = CafeMilestone.reached_text()
	milestone_panel.visible = true
	_milestone_popup_secs = MILESTONE_POPUP_SECS

# T3.3 미호 선물: 선택 작물(_selected_crop) 수확물 1개를 건네 호감도를 올린다.
# 선호 작물(영혼 호박)이면 더 크게 오른다. 하루 1회만 가능(Affinity가 게이팅).
func _try_gift() -> void:
	var crop := _selected_crop
	if inventory.harvest_count(crop) <= 0:
		_notice("%s 수확물이 없다" % CropCatalog.name_of(crop))
		return
	if not affinity.can_gift(clock.day):
		_notice("오늘은 이미 선물했다")
		return
	inventory.take_harvest(crop)              # 선물한 수확물 1개 소모
	var gained := affinity.gift(crop, clock.day)
	var tag := "(선호!) " if affinity.is_preferred(crop) else ""
	audio.sfx("ui")                           # P2.6 선물 건넴 확인 블립(미호)
	_notice("%s 선물 %s+%d 호감도" % [CropCatalog.name_of(crop), tag, gained])

# S0-6 대화창 「태운 한지」 룩 구성(HUD처럼 코드로). 기존 3노드(패널·본문·초상화)를
# 윈도우 아트 위 오버레이로 재배치하고, 이름판·먹 화살표를 새로 얹는다. main.tscn 무수정.
func _build_dialogue_ui() -> void:
	var font := load(DLG_FONT) as FontFile
	# ① 패널 = 윈도우 컨테이너(배경 투명)
	dialogue_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	dialogue_panel.position = DLG_WINDOW.position
	dialogue_panel.size = DLG_WINDOW.size
	var wtex := load(DLG_WINDOW_TEX) as Texture2D
	# ② 그림자 + 윈도우 아트(본문보다 뒤로 → 먼저 add 후 앞으로 당김)
	var shadow := _dlg_texrect(wtex, Rect2(Vector2(4, 6), DLG_WINDOW.size), false)
	shadow.modulate = Color(0, 0, 0, 0.32)
	dialogue_panel.add_child(shadow)
	dialogue_panel.move_child(shadow, 0)
	var art := _dlg_texrect(wtex, Rect2(Vector2.ZERO, DLG_WINDOW.size), false)
	dialogue_panel.add_child(art)
	dialogue_panel.move_child(art, 1)
	# ③ 본문(먹빛, 좌 텍스트칸 + 안쪽 여백)
	var tr := _dlg_local(DLG_F_TEXT)
	dialogue_text.position = tr.position + Vector2(30, 6)   # ★좌측 나비 장식 피해 첫 줄 안 잘리게(10→30, 나비 폭 회피)
	dialogue_text.size = tr.size - Vector2(40, 12)
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font:
		dialogue_text.add_theme_font_override("font", font)
	dialogue_text.add_theme_font_size_override("font_size", 15)
	dialogue_text.add_theme_color_override("font_color", DLG_INK)
	# ④ 이름판(화자명, 가운데)
	_dlg_name = Label.new()
	var nr := _dlg_local(DLG_F_NAME)
	_dlg_name.position = nr.position
	_dlg_name.size = nr.size
	_dlg_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dlg_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font:
		_dlg_name.add_theme_font_override("font", font)
	_dlg_name.add_theme_font_size_override("font_size", 13)
	_dlg_name.add_theme_color_override("font_color", DLG_NAME_INK)
	dialogue_panel.add_child(_dlg_name)
	# ⑤ 다음 화살표(먹빛, 우하단, 위아래 bob)
	_dlg_arrow = _dlg_texrect(load(DLG_ARROW_TEX), Rect2(tr.position + tr.size - Vector2(22, 20), Vector2(18, 16)), false)
	dialogue_panel.add_child(_dlg_arrow)
	var y0 := _dlg_arrow.position.y
	var tw := create_tween().set_loops()
	tw.tween_property(_dlg_arrow, "position:y", y0 + 3.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_dlg_arrow, "position:y", y0, 0.6).set_trans(Tween.TRANS_SINE)
	# ⑥ 초상화(우 칸) — 여백 없이 꽉(COVER+clip, 매팅 제거). CanvasLayer 직계(패널 위).
	var pr := _dlg_abs(DLG_F_PORT)
	dialogue_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialogue_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	dialogue_portrait.clip_contents = true
	dialogue_portrait.position = pr.position
	dialogue_portrait.size = pr.size

func _dlg_local(f: Rect2) -> Rect2:
	return Rect2(f.position * DLG_WINDOW.size, f.size * DLG_WINDOW.size)

func _dlg_abs(f: Rect2) -> Rect2:
	var l := _dlg_local(f)
	return Rect2(DLG_WINDOW.position + l.position, l.size)

func _dlg_texrect(tex: Texture2D, r: Rect2, nearest: bool) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if nearest else CanvasItem.TEXTURE_FILTER_LINEAR
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = r.position
	t.size = r.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

# 현재 줄이 바뀔 때마다(시작·넘기기) 패널을 갱신한다. 마지막 줄이면 "닫기"로 안내.
func _on_dialogue_changed(speaker: String, line: String) -> void:
	dialogue_panel.visible = true
	audio.sfx("dialogue")                     # P2.6 대사 한 줄 진행마다 부드러운 비프
	# P2.4 인라인 표정 태그 파싱: 줄 맨 앞 [smile]/[shy]/[sad]/[talk]만 표정으로 떼고,
	# 본문에서 제거한다. 화이트리스트 밖([E] 등)은 그대로 본문에 남긴다.
	var expr := PORTRAIT_FALLBACK_EXPR
	var body := line
	if line.begins_with("["):
		var close := line.find("]")
		if close > 1:
			var tag := line.substr(1, close - 1)
			if PORTRAIT_EXPRS.has(tag):
				expr = tag
				body = line.substr(close + 1).strip_edges()
	_set_portrait(speaker, expr)
	if _dlg_name:
		_dlg_name.text = speaker                # 화자명 → 이름판(별도 탭)
	var hint := "[E] 닫기" if dialogue.is_last() else "[E] 다음"
	# 화자명은 이름판이 맡으므로 본문은 대사 + 진행/안내만
	dialogue_text.text = "%s\n\n%s   %s" % [body, dialogue.progress(), hint]

# P2.4 화자+표정 → 초상화 슬롯. 매핑에 없는 화자(그레이박스 손님·잡귀 등)는 슬롯을 끈다.
# ★owner 2026-07-02: talk(입벌림)은 부자연스러워 폐기 — talk·무태그·표정파일 누락은 모두 idle(기본
#   stem.png, 입 닫힌 중립)로. 명시 감정 태그(smile/shy/sad)만 해당 표정 파일을 쓴다.
func _set_portrait(speaker: String, expr: String) -> void:
	var stem: String = PORTRAIT_STEM.get(speaker, "")
	if stem == "":
		dialogue_portrait.visible = false
		return
	# smile/shy/sad 등 명시 감정만 표정 파일 시도(talk 제외 — idle로 보냄).
	if expr != "" and expr != "talk":
		var p: String = PORTRAIT_DIR + stem + "_" + expr + ".png"
		if ResourceLoader.exists(p):
			dialogue_portrait.texture = load(p)
			dialogue_portrait.visible = true
			return
	# talk·무태그·누락 → idle(기본 stem.png)
	var base := PORTRAIT_DIR + stem + ".png"
	if ResourceLoader.exists(base):
		dialogue_portrait.texture = load(base)
		dialogue_portrait.visible = true
	else:
		dialogue_portrait.visible = false

# 마지막 줄까지 넘겨 닫혔을 때: 패널을 숨기고 이동 잠금을 푼다.
# T4.1 온보딩 전진: 방금 어떤 대화였는지는 현재 단계로 가른다(NOTICE=옥자 통보 /
# MEET_MIHO=미호 멘토). 온보딩이 끝난 뒤(DONE)의 일상 미호 대화는 두 분기 모두
# 단계가 달라 no-op이 된다(Onboarding._advance_from의 단계 가드 — 안전).
func _on_dialogue_finished() -> void:
	dialogue_panel.visible = false
	dialogue_portrait.visible = false  # P2.4 초상화 슬롯도 함께 닫는다
	player.set_physics_process(true)
	# T5.1 온보딩 전진은 '누구와의 대화였나'(_talking_to)로도 가른다 — 멜이 카페에
	# 상주하며 미호 멘토 단계 도중에도 말 걸 수 있게 됐기 때문(화자 구분 없이 단계로만
	# 가르면 멜 대화가 미호 단계를 잘못 전진시킨다). 멜 대화는 온보딩과 무관하다.
	if _talking_to == okja.display_name() and onboarding.step == Onboarding.NOTICE:
		onboarding.notice_seen()
		# T5.6 옥자는 통보를 끝내면 통보 자리에서 사라지고 카페로 상주를 옮긴다(이전엔 그냥
		# 숨겼지만, 이제 매일 보는 사장으로 카페에 자리 잡는다 — _refresh_okja_station이
		# NOTICE를 지난 단계를 보고 카페 자리에 다시 드러낸다).
		_refresh_okja_station()
	elif _talking_to == miho.display_name() and onboarding.step == Onboarding.MEET_MIHO:
		onboarding.talked_to_miho()
	_talking_to = ""

# ── ADR-0024 상호작용 대상 칸(마우스 커서) / 시각화 ─────────────────────────
# 대상 칸 = 마우스 커서 밑 타일. 단 플레이어 인접 1칸 반경(주변 8칸 + 발밑)으로 클램프한다 —
# 커서가 멀면 그 방향의 가장 가까운 인접 칸으로 당긴다(사거리 = 인접 1칸, AoE는 Phase 3 예약).
# 도구를 쓸 때 캐릭터가 커서 쪽으로 돌아본다(이동 WASD와 별개 축 — 스타듀 동일).
func _update_target() -> void:
	var old_target := _target
	var old_valid := _target_valid
	var foot := player.global_position
	var ft := Vector2i(int(foot.x) / TILE, int(foot.y) / TILE)
	# 커서 글로벌 좌표 → 타일. 카메라가 따라가므로 get_global_mouse_position이 월드 좌표를 준다.
	var cursor := get_global_mouse_position()
	var ct := Vector2i(int(cursor.x) / TILE, int(cursor.y) / TILE)
	# 발 칸 기준 인접 1칸으로 클램프(각 축 -1..+1). 발밑(0,0) 포함 — 발밑 칸도 작용 가능.
	var dx := clampi(ct.x - ft.x, -1, 1)
	var dy := clampi(ct.y - ft.y, -1, 1)
	_target = ft + Vector2i(dx, dy)
	_target_valid = _is_farmable(_target)
	# 도구 사용·조준 방향 표시를 위해 플레이어가 커서 쪽(대상 칸 방향)으로 돌아본다(발밑이면 유지).
	if _target != ft:
		player.face_toward(_target_center_px(_target))
	if _target != old_target or _target_valid != old_valid:
		queue_redraw()  # 커서 위치/표시 갱신

# 타일 중심 월드 좌표(facing 방향 계산용). _tile_center_px와 같은 결.
func _target_center_px(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE * 0.5, t.y * TILE + TILE * 0.5)

# 상호작용 가능한 칸 = 맵 안 + 밭 흙(SOIL). 길·집·카페·벽은 제외.
# T3.2/T5.6 미호 밭 자리는 사람 자리라 농사 대상에서 뺀다(말걸기와 밭 동작 충돌 방지).
# 미호가 오후에 카페로 출근해 비어 있어도 이 자리는 계속 비워 둔다(돌아올 자리 — 작물을
# 심어 미호와 겹치는 걸 막는다). 카페 자리(_miho_tile 카페값)는 SOIL이 아니라 자동 제외된다.
func _is_farmable(t: Vector2i) -> bool:
	if t.x < 0 or t.x >= _grid_w or t.y < 0 or t.y >= _grid_h:
		return false
	if t == MIHO_FIELD_TILE:
		return false
	if _grid[t.y][t.x] == SOIL:
		return true
	# ★ [S1-8 §10.4] 경작지 확장 — 안식 농원에서 개간(debris 치움)한 타일도 farmable(스타듀식 풀→틸드).
	# 지형(_grid)은 GROUND 그대로 두고 reclaim 델타만 얹는다(구역 재빌드 안전·세이브는 reclaim이 담당).
	return _region == RegionCatalog.HOME and reclaim != null and reclaim.is_cleared(t)

# ★ [S1-5b] 혼의 나무 3×3 심기 판정용 "이 칸이 막혔나"(greybox-spec §7.4 ①②③). orchard.can_plant에
# Callable로 주입한다 — orchard는 지형을 모르고 main이 여기서 합성한다(디커플링). 막힘 = 맵 밖 or
# is_solid(절벽·프롭·벽·나무·바위) or is_crop_solid(트렐리스 넝쿨) or 미호 밭 자리(예약). SOIL 요구는
# 없다(밭갈이 무관 — 풀 위에도 심을 수 있다, Q2/Q3). 타 나무 겹침은 orchard가 자체 판정한다(④).
func _is_tree_blocked(t: Vector2i) -> bool:
	if t.x < 0 or t.x >= _grid_w or t.y < 0 or t.y >= _grid_h:
		return true
	if t == MIHO_FIELD_TILE:
		return true
	if is_solid(_grid[t.y][t.x]):
		return true
	return farm.is_crop_solid(t)

# ★ [S1-8 §10.2] 조준 타일에 아직 안 치운 debris가 있으면 그 DebrisCatalog kind, 없으면 "". 배치는
# _prop_layouts["HOME"] 시드에서 텍스처→kind로 역인한다(이미 치운 것은 reclaim이 걸러 "" 반환). 안식
# 농원 전용(CAFE/VILLAGE는 debris 텍스처 無). 개간 디스패치 게이트·_use_tool 개간 분기가 쓴다.
func _debris_kind_at(t: Vector2i) -> String:
	if _region != RegionCatalog.HOME or reclaim == null or reclaim.is_cleared(t):
		return ""
	for entry in _prop_layouts.get("HOME", []):
		var kind: String = DEBRIS_KIND.get(entry[0], "")
		if kind != "" and t in entry[1]:
			return kind
	return ""

# ★ [ADR-0055] HOME 프롭이 점유한 타일 집합(다중 타일 footprint 포함). 프롭 크기(get_size)를 타일로
#   환산해 앵커에서 아래·오른쪽으로 펼친다(나무 2×4·바위 2×2 등). 재점령 후보에서 이 타일을 배제해
#   건물·나무·바위·debris·꽃·울타리·허수아비·가구 위에 잡초가 안 돋게 한다(성역·시각 겹침 방지).
func _home_occupied_tiles() -> Dictionary:
	var occ: Dictionary = {}
	for entry in _prop_layouts.get("HOME", []):
		var sz: Vector2 = entry[0].get_size()
		var tw: int = maxi(int(round(sz.x / TILE)), 1)
		var th: int = maxi(int(round(sz.y / TILE)), 1)
		for anchor in entry[1]:
			for dx in range(tw):
				for dy in range(th):
					occ[anchor + Vector2i(dx, dy)] = true
	return occ

# ★ [ADR-0055 §2] 재점령 자격 빈 맨땅 후보 — reclaim.advance_day 입력. ENCROACH_SCAN_RECT 안에서
#   순수 빈 GROUND(밭 SOIL·길·벽·물·절벽 아님)이고, 프롭 미점유(건물·나무·바위·debris·꽃·울타리 등)이며,
#   밭(경작·심음)도 아니고, 개간(치운 debris) 자리도 아닌 타일만 모은다 = 아직 안 다듬은 잔디 여백.
#   → 밭·작물·구조물·이미 연 땅은 절대 재점령 안 됨(진보·cozy 성역). HOME 전용.
func _encroach_candidates() -> Array:
	var out: Array = []
	if _region != RegionCatalog.HOME or reclaim == null:
		return out
	var occ := _home_occupied_tiles()
	var y0: int = maxi(ENCROACH_SCAN_RECT.position.y, 0)
	var y1: int = mini(ENCROACH_SCAN_RECT.end.y, _outdoor_h)
	var x0: int = maxi(ENCROACH_SCAN_RECT.position.x, 0)
	var x1: int = mini(ENCROACH_SCAN_RECT.end.x, _grid_w)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var t := Vector2i(x, y)
			if _grid[y][x] != GROUND:              # 밭 흙·길·벽·물·절벽 = 진보/성역 → 배제
				continue
			if occ.has(t):                          # 프롭 점유(구조물·장식·debris) → 배제
				continue
			if reclaim.is_cleared(t):               # 이미 연 땅(구조물 치운 성역) → 배제
				continue
			if farm.is_tilled(t) or farm.is_planted(t):  # 밭 성역(이중 방어) → 배제
				continue
			out.append(t)
	return out

# ★ [B1-a.1 → Phase E/S1-15] 신규 게임 스타터 짐승 배치. ranch가 비었을 때만(멱등) 종별 소속 건물 실내에
# 놓는다(진입 실내 — 안개소=넋우릿간·노을닭=넋둥우리). ★ Phase E: 각 건물에 *성체 1 + 새끼 1*(owner 결정
# 2026-07-03 — 데모에서 성체·새끼·성장 셋 다 보이게). 성체는 age=grow_days로 즉시 산물 가능, 새끼는 age=0.
# 좌표계는 HOME _grid 기준이라 부팅 직후(신규 게임, 구역=HOME)에만 부른다(세이브 복원은 load_save가 담당).
func _ensure_starter_animals() -> void:
	if ranch == null or ranch.count() > 0:
		return
	# 넋우릿간(안개소·대형·barn형) — 성체 + 새끼.
	_seed_starter_animal(AnimalCatalog.HONBAEK_SO, "넋우릿간", NEOKURITGAN_RECT, AnimalCatalog.grow_days_of(AnimalCatalog.HONBAEK_SO))
	_seed_starter_animal(AnimalCatalog.HONBAEK_SO, "넋우릿간", NEOKURITGAN_RECT, 0)
	# 넋둥우리(노을닭·소형·coop형) — 성체 + 새끼.
	_seed_starter_animal(AnimalCatalog.HONBAEK_DAK, "넋둥우리", NEOKDUNGURI_RECT, AnimalCatalog.grow_days_of(AnimalCatalog.HONBAEK_DAK))
	_seed_starter_animal(AnimalCatalog.HONBAEK_DAK, "넋둥우리", NEOKDUNGURI_RECT, 0)

# 건물 실내 바닥(벽 1칸 안쪽) 첫 빈 칸에 종을 소속 건물째 배치. 방 rect는 둘레가 벽이라 안쪽으로 파고든다.
# ★ Phase E: age 파라미터로 성체(grow_days)/새끼(0)를 구분 배치(같은 건물 두 번 호출 시 다음 빈 칸에 놓임).
func _seed_starter_animal(species: String, building: String, room: Rect2i, age: int = 0) -> void:
	for y in range(room.position.y + 2, room.end.y - 1):
		for x in range(room.position.x + 2, room.end.x - 2):
			var t := Vector2i(x, y)
			if ranch.has_animal(t):
				continue
			if ranch.add_animal(t, species, building, age):
				return

# ── ★ [B1-a.2] 방목 pathing 배선 ──────────────────────────────────────────────
# 방목 날씨 게이트. 혼우(비)·잿눈(눈)이면 짐승은 실내 잔류(Q5 스펙)지만, 날씨 시스템은 Phase 3라
# 아직 없다 → 지금은 항상 평온(true). 날씨가 붙으면 여기서 clock.weather 등을 물어 게이팅한다(hook).
func _weather_calm() -> bool:
	return true

# 방목지(PASTURE_SCAN_RECT) 안의 걸을 수 있는(비-SOLID) 타일 목록. 짐승 방목 목적지 슬롯이 된다.
# 지형만 본다(그레이박스 — 방목지는 절벽으로 둘린 평면이라 프롭 거의 없음). _grid 경계도 방어.
func _free_pasture_tiles() -> Array:
	var out: Array = []
	for y in range(PASTURE_SCAN_RECT.position.y, PASTURE_SCAN_RECT.end.y):
		if y < 0 or y >= _grid.size():
			continue
		for x in range(PASTURE_SCAN_RECT.position.x, PASTURE_SCAN_RECT.end.x):
			if x < 0 or x >= _grid[y].size():
				continue
			if not is_solid(_grid[y][x]):
				out.append(Vector2i(x, y))
	return out

# 문 열린 건물의 실내 짐승을 방목지로 방출한다(아침 경계·문 여는 즉시). 평온·낮일 때만. 방목 슬롯을
# 짐승마다 하나씩 배정(라운드로빈)한다. ranch가 releasable(문+실내)을 판정하고, main이 지형을 배정한다.
func _release_open_buildings() -> void:
	if ranch == null or not _weather_calm():
		return
	# 밤엔 방출하지 않는다(방목=낮). day_advanced는 06:00 리셋 직후라 낮이지만, 문 토글은 언제든 눌리므로 가드.
	if clock != null and clock.phase() == "밤":
		return
	var slots := _free_pasture_tiles()
	if slots.is_empty():
		return
	var i := 0
	for tile in ranch.releasable():
		ranch.send_to_pasture(tile, slots[i % slots.size()])
		i += 1

# ★ [B1-a.3] 사료풀 시드 — FORAGE_SCAN_RECT 안의 걸을 수 있는(비-SOLID) 고지 풀 타일을 Forage에 등록.
#   여물광 footprint(SILO_EXT_RECT=WALL)는 is_solid로 자동 제외된다. seed는 멱등(복원 상태 보존).
func _seed_forage_tiles() -> void:
	if forage == null:
		return
	for y in range(FORAGE_SCAN_RECT.position.y, FORAGE_SCAN_RECT.end.y):
		if y < 0 or y >= _grid.size():
			continue
		for x in range(FORAGE_SCAN_RECT.position.x, FORAGE_SCAN_RECT.end.x):
			if x < 0 or x >= _grid[y].size():
				continue
			if not is_solid(_grid[y][x]):
				forage.seed(Vector2i(x, y))

# ★ ADR-0052 꽃 패치 시드 — layout.json HOME 배치에서 FLOWER_PATCH 타일을 FlowerPatch에 등록(_debris_kind_at
#   결 — 배치는 _prop_layouts에 잠기고 노드는 상태만). 신규·복원 멱등(seed가 딴 상태 보존).
func _seed_flower_patches() -> void:
	if flower == null:
		return
	for entry in _prop_layouts.get("HOME", []):
		if entry[0] == PROP_FLOWER_PATCH:
			for t in entry[1]:
				flower.seed(t)

# 밭 칸 상태가 바뀌면 오버레이 타일을 갱신한다(FarmField.tile_changed로 호출).
func _on_tile_changed(t: Vector2i) -> void:
	var idx := _overlay_index(t)
	if idx < 0:
		field_layer.erase_cell(t)
	else:
		field_layer.set_cell(t, 0, Vector2i(idx, 0))
	_rebuild_trellis_collision()   # ★ [S1-5a] 트렐리스 심기/수확/제거 시 넝쿨 충돌 갱신(칸 적어 저렴)
	queue_redraw()  # 작물 스프라이트(_draw_crops)는 _draw에서 그리므로 상태 변화 시 다시 그린다

# 칸 상태 → 오버레이 아틀라스 인덱스(-1 = 미경작, 오버레이 없음).
# 인덱스 = 외형단계 × 2 + 젖음. 외형단계는 FarmField.growth_stage(씨앗/새싹/수확가능)
# 에 빈 고랑(작물 없음)을 더해 매핑한다.
func _overlay_index(t: Vector2i) -> int:
	if not farm.is_tilled(t):
		return -1
	var wet := 1 if farm.is_watered(t) else 0
	var appearance := AP_EMPTY
	if farm.is_planted(t):
		appearance = farm.growth_stage(t) + 1  # 0/1/2 → SEED/SPROUT/MATURE
	return appearance * 2 + wet

# 대상 칸 강조 커서(흰 1px 테두리) + T5.4 카페 손님·인내심 바. main은 원점 0,0이라
# 그리기 좌표 = 타일 픽셀(미호·멜은 자기 Node2D에서 그리지만, 손님은 일시적이라 main이
# 좌석 칸에 직접 그린다 — 노드 생성·해제 없이 그레이박스로 가볍게).
# ★ M1.4 — 구역별로 그린다. 안식 농원=집 외관·집 가구·밭 작물 / 나루 마을=카페 외관·카페 가구·
# 카페 손님·잡귀. 두 구역이 좌표 범위를 공유해(같은 그리드 크기) 다른 구역 그림이 떠다니지
# 않게 현재 구역(_region) 것만 그린다. 카페 손님/잡귀는 카페 실내 칸(y38~47)이라 마을 야외
# 카메라엔 어차피 안 들지만(실내 카메라에서만 보임), 명시적으로 갈라 그리기를 단순하게 한다.
func _draw() -> void:
	# ★ 지면 디테일 오버레이(타일 위·facade/프롭/플레이어 아래) — 구역 빌드 때 베이크한 한 장.
	if _ground_detail_tex != null:
		draw_texture(_ground_detail_tex, Vector2.ZERO)
	match _region:
		RegionCatalog.HOME:
			_draw_house_wall_band()  # ★ T3③ 집 실내 북벽 plank 밴드(가구 아래 — 가구가 위로 덮어 입체)
			_draw_home_deco()        # ★ [S1-9] 플레이어 집 꾸미기 3레이어(벽 밴드 위·시드 가구 아래, 집 실내에서만)
			_draw_facade_home()      # 집 외관(WALL 박스 위에 덮어 닫힌 건물로)
			_draw_facade_storehouse()  # ★ T3 창고 외관(NE)
			_draw_facade_barn()        # ★ [B1-a.1] 넋우릿간+넋둥우리 외관(동물 2건물 — barn 6×4·coop 4×2)
			_draw_silo()               # ★ [B1-a.3] 여물광 외관(WALL 박스 그레이박스 + 건초 게이지)
			_draw_well()               # ★ [B2] 혼우물 외관(WALL 박스 그레이박스 — 돌 우물, 리필 메카닉=별도 grill)
			_draw_forage()             # ★ [B1-a.3] 사료풀(다 자람=풀포기·벤 자리=밑동) — 낫 채집 대상
			_draw_flower_regrow()      # ★ ADR-0052 딴 꽃 패치 자리 새싹(재생 대기 — 폄은 _draw_props_for가 풀 스프라이트로)
			_draw_encroach_weeds()     # ★ ADR-0055 밤새 돋은 재점령 잡초(빈 맨땅 위 평면 데칼 — 낫 채집 대상)
			# ★[§6] Y-split: 뒤 프롭(플레이어 발치 위)만 여기서(플레이어 아래). 앞 프롭은 _front_props.
			var _psy: float = player.global_position.y if player != null else 1.0e20
			_draw_props_for(_prop_layouts.get("HOME", []), self, _PROP_PASS_BACK, _psy)  # ★ ADR-0025 데이터: 집 가구·길가 등불·화분 + T3 농장 장식
			_draw_crops()            # 밭의 작물 스프라이트(흙 오버레이 위·캐릭터 아래)
			_draw_orchard()          # ★ [S1-5b/S1-10] 혼의 나무 과수 — 종별 3단계 스프라이트(묘목·성목·결실)
			_draw_trackb_interiors() # ★ Phase E Track B 실내 가구(여물통·보관 크레이트 — 짐승 아래, 카메라로 방별 클립)
			_draw_ranch()            # ★ [S1-7/S1-15] 혼의 짐승 — 전용 스프라이트(assets/livestock) 방목/실내 렌더
			_draw_chest()            # ★ Phase D/E 저장 상자(집·창고 실내 — 각 카메라에서만 보임)
		RegionCatalog.NARU_VILLAGE:
			_draw_facade_cafe()      # 카페 외관
			_draw_facade_village_houses()   # ★ M2.5 메인 집 3채(미호·멜·바나) 외관
			_draw_props_for(_prop_layouts.get("CAFE", []), self)  # ★ ADR-0025 데이터: 카페 무대 가구·카페 등불
			_draw_ship_bin()         # ★ C2 무인 출하함 상자(카페 안 — 카페 카메라에서만 보임)
			# M2.4 — 이벤트 데이면 카페 무대를 축제 장식으로(가구 위에 가랜드·무대 카펫 덧그림).
			if Festival.is_event_day(clock.day):
				_draw_cafe_festival()
			# ★ M2.2 — 공유 집 실내에 들어와 있으면 집 가구를 재사용해 그린다(HOUSE_RECT 방).
			# 만물상 방·카페 방은 카메라 밖이라 같이 그려도 안 보이지만, 가구는 들어온 그 방만 둔다.
			if _is_in_house_interior():
				_draw_props_for(_prop_layouts.get("VILLAGE_HOUSE", []), self)  # ★ ADR-0025 데이터
			_draw_customers()
			_draw_night_customers()
			_draw_jobgui()
	if _edit_mode:          # ★ ADR-0025 ① 배치 모드 오버레이(선택·마우스 칸·팔레트 고스트)
		_draw_edit_overlay()
	if _deco_mode:          # ★ [S1-9] 집 꾸미기 모드 오버레이(마우스 칸·팔레트 고스트)
		_draw_deco_overlay()
	if not _target_valid:
		return
	var p := Vector2(_target.x * TILE, _target.y * TILE)
	draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(1, 1, 1, 0.7), false, 1.0)

# 실내 가구·장식을 바닥정렬(타일 좌상단 원점)로 그린다. 충돌 없는 순수 장식 —
# 손님·잡귀 그리기와 같은 결(노드 생성·해제 없이 main이 직접). 침대(32×64)는 1×2칸을 덮고,
# 나머지(32×32)는 한 칸을 채운다(ADR-0013 native). PROP_LAYOUT 순서대로
# 그려 선반(뒷벽)→카운터→스툴이 자연스레 겹친다.
func _draw_crops() -> void:
	for t in farm.planted_tiles():
		var crop_id := farm.crop_of(t)
		var frames: Variant = CROP_SPRITES.get(crop_id)
		if frames == null:
			continue
		# growth_stage: 0=씨앗 / 1=새싹 / 2=수확가능 → 같은 인덱스 프레임. 칸(32×32)을 채운다.
		var stage: int = clampi(farm.growth_stage(t), 0, frames.size() - 1)
		var tex: Texture2D = frames[stage]
		if CropCatalog.is_trellis(crop_id):
			# 트렐리스 작물(황천포도): 32×64 스프라이트 — 밑동을 타일 하단에 접지, 위로 1칸 솟음
			# (스타듀 홉/포도 결). 밑동 SOIL 칸은 그대로, 위 칸은 통과 가능하나 넝쿨이 시각적으로 덮는다.
			draw_texture_rect(tex, Rect2(Vector2(t.x * TILE, (t.y - 1) * TILE), Vector2(TILE, TILE * 2)), false)
		else:
			draw_texture_rect(tex, Rect2(Vector2(t.x * TILE, t.y * TILE), Vector2(TILE, TILE)), false)

# ★ [S1-5b] 혼의 나무 과수 그레이박스 표식(greybox-spec §7.4 — 대형 스프라이트·Y-sort=S1-10 이관).
# 묘목(미성숙)=밑동 작은 새싹 / 성숙=3×3 수관(반투명 초록) + 밑동(갈색) + 매달린 과일 점(fruit_count).
# 순수 시각 placeholder — 로직·충돌은 orchard/_orchard_body가 든다(육안 확인용).
func _draw_orchard() -> void:
	if orchard == null:
		return
	var day := clock.day
	for anchor in orchard.trunk_tiles():
		var trunk_px := Vector2(anchor.x * TILE, anchor.y * TILE)
		# ★ [S1-10] 종별 3단계 스프라이트: 0=묘목(미성숙) / 1=성목(성숙·과일0) / 2=결실(성숙·과일>0).
		var frames = ORCHARD_SPRITES.get(orchard.fruit_id_of(anchor))
		if frames != null:
			var stage := 0
			if orchard.is_mature(anchor, day):
				stage = 2 if orchard.fruit_count_of(anchor) > 0 else 1
			var tex: Texture2D = frames[stage]
			var sz := tex.get_size()
			# bottom-center 앵커 — 밑동을 앵커 칸 하단 중앙에, 3타일폭 수관이 위로 솟는다(facade와 같은 결).
			draw_texture(tex, Vector2(trunk_px.x + TILE * 0.5 - sz.x * 0.5, trunk_px.y + TILE - sz.y))
			continue
		# ── 폴백: 그레이박스(아트 없는 종 방어) ──
		if not orchard.is_mature(anchor, day):
			# 묘목: 밑동 칸에 작은 갈색 줄기 + 초록 새싹(자라는 중).
			draw_rect(Rect2(trunk_px + Vector2(TILE * 0.42, TILE * 0.45), Vector2(TILE * 0.16, TILE * 0.5)), Color(0.42, 0.30, 0.20))
			draw_rect(Rect2(trunk_px + Vector2(TILE * 0.30, TILE * 0.28), Vector2(TILE * 0.4, TILE * 0.22)), Color(0.35, 0.62, 0.35, 0.9))
			continue
		# 성숙: 3×3 수관(앵커 ±1) 반투명 초록 — 통과 가능함을 반투명으로 시사.
		var canopy_px := Vector2((anchor.x - 1) * TILE, (anchor.y - 1) * TILE)
		draw_rect(Rect2(canopy_px, Vector2(TILE * 3, TILE * 3)), Color(0.28, 0.52, 0.30, 0.5))
		# 밑동(앵커 1칸, 불투명 갈색 — 통과 불가 SOLID 칸).
		draw_rect(Rect2(trunk_px + Vector2(TILE * 0.34, TILE * 0.3), Vector2(TILE * 0.32, TILE * 0.7)), Color(0.40, 0.27, 0.17))
		# 매달린 익은 과일 점(fruit_count개, 수관 상단에 붉은 점).
		var n := orchard.fruit_count_of(anchor)
		for i in n:
			var fp := canopy_px + Vector2(TILE * (0.6 + i * 0.8), TILE * 0.6)
			draw_circle(fp, TILE * 0.22, Color(0.85, 0.28, 0.32))

# ★ [B1-a.3] 여물광(Silo) 그레이박스 — WALL 박스 footprint 위에 나무빛 사일로 몸통 + 지붕 + 건초 채움
#   게이지(오른쪽 세로 바, 노란 채움=silo_hay/240). ※짐승 스프라이트·과수는 이미 배선됨(_draw_ranch·
#   _draw_orchard). 남은 그레이박스=여물광·혼우물·사료풀·Track B 실내가구(아트 Gemini 후행). 실외 HOME 뷰.
func _draw_silo() -> void:
	if ranch == null:
		return
	var r := SILO_EXT_RECT
	var px := Vector2(r.position.x * TILE, r.position.y * TILE)
	var wpx := Vector2(r.size.x * TILE, r.size.y * TILE)
	# ★ 아트 훅: assets/props/silo.png 있으면 facade 앵커(풀 백드롭+접지그림자)로 렌더, 없으면 그레이박스.
	var tex := _prop_tex("silo")
	if tex != null:
		_blit_facade_anchored(tex, r)
	else:
		draw_rect(Rect2(px, wpx), Color(0.42, 0.34, 0.24))                              # 몸통(나무빛)
		draw_rect(Rect2(px, Vector2(wpx.x, TILE * 0.5)), Color(0.30, 0.24, 0.17))       # 지붕 밴드(위 어둡게)
		draw_rect(Rect2(px, wpx), Color(0.15, 0.12, 0.09), false, 2.0)                  # 외곽선
	# 건초 채움 게이지(동적 오버레이 — 아트 위에도 그린다) — 우측 세로 바(빈=회색 틀, 채움=노랑, 아래→위).
	var gw := TILE * 0.5
	var gh := wpx.y - TILE * 0.8
	var gpos := px + Vector2(wpx.x - gw - TILE * 0.25, TILE * 0.6)
	draw_rect(Rect2(gpos, Vector2(gw, gh)), Color(0.12, 0.12, 0.12, 0.8))
	var fill := gh * ranch.silo_fill_ratio()
	if fill > 0.0:
		draw_rect(Rect2(gpos + Vector2(0, gh - fill), Vector2(gw, fill)), Color(0.86, 0.74, 0.32))
	draw_rect(Rect2(gpos, Vector2(gw, gh)), Color(0.05, 0.05, 0.05), false, 1.0)

# ★ [B2] 혼우물(Well) 그레이박스 — WALL 박스 footprint 위에 돌 우물 몸통 + 어두운 수면 + 지붕/두레박 밴드.
#   아트(우물 도트)·리필 메카닉(유한 물뿌리개)은 후행(별도 grill). 실외 HOME 뷰. _draw_silo와 동형(디커플링).
func _draw_well() -> void:
	var r := WELL_RECT
	# ★ 아트 훅: assets/props/well.png 있으면 facade 앵커(풀 백드롭+접지그림자)로 렌더, 없으면 그레이박스.
	var tex := _prop_tex("well")
	if tex != null:
		_blit_facade_anchored(tex, r)
		return
	var px := Vector2(r.position.x * TILE, r.position.y * TILE)
	var wpx := Vector2(r.size.x * TILE, r.size.y * TILE)
	draw_rect(Rect2(px, wpx), Color(0.46, 0.47, 0.50))                                  # 몸통(돌빛 회색)
	draw_rect(Rect2(px, Vector2(wpx.x, TILE * 0.5)), Color(0.33, 0.28, 0.20))           # 지붕/두레박 밴드(위 나무빛 어둡게)
	draw_rect(Rect2(px, wpx), Color(0.14, 0.14, 0.16), false, 2.0)                      # 외곽선
	# 안쪽 수면(가운데 어두운 물웅덩이 — 우물임을 읽게).
	var pool_m := Vector2(TILE * 0.6, TILE * 0.8)
	draw_rect(Rect2(px + pool_m, wpx - pool_m * 2.0), Color(0.12, 0.20, 0.28))          # 수면(짙은 청록)
	draw_rect(Rect2(px + pool_m, wpx - pool_m * 2.0), Color(0.05, 0.08, 0.10), false, 1.0)

# ★ [B1-a.3] 사료풀 그레이박스 — 다 자란 풀은 초록 풀포기(낫 대상), 벤 자리는 낮은 밑동(재생 대기). 실외 HOME.
func _draw_forage() -> void:
	if forage == null:
		return
	# ★ 아트 훅: assets/props/forage_{grown,cut}.png 있으면 타일에 bottom-center 렌더, 없으면 그레이박스.
	var grown_tex := _prop_tex("forage_grown")
	var cut_tex := _prop_tex("forage_cut")
	for tile in forage.all_tiles():
		var px := Vector2(tile.x * TILE, tile.y * TILE)
		var grown: bool = forage.is_grown(tile)
		var tex: Texture2D = grown_tex if grown else cut_tex
		if tex != null:
			# ★ 사료풀 = 타일 꽉 채우는 fill 스프라이트(빽빽한 건초밭 — 이웃 타일과 이어짐). 오프셋 흔들기는
			#   fill 타일에 이음새(gap)를 만들므로 좌우반전만으로 변형(6×3 블록이 균일 반복으로 안 읽히게).
			#   타일 해시 결정적 → 매 프레임 동일(깜빡임 없음)·세이브 무관.
			var sz := tex.get_size()
			var hsh: int = absi((int(tile.x) * 73856093) ^ (int(tile.y) * 19349663))
			var bx := px.x + (TILE - sz.x) * 0.5
			var by := px.y + TILE - sz.y              # 발치(bottom-center)를 타일 바닥에
			if (hsh & 1) == 1:                        # 좌우 반전(이음새 없이 변형)
				draw_set_transform(Vector2(bx + sz.x, by), 0.0, Vector2(-1, 1))
				draw_texture(tex, Vector2.ZERO)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)   # 변환 원복(뒤 draw 영향 방지)
			else:
				draw_texture(tex, Vector2(bx, by))
			continue
		if grown:
			# 다 자람 = 세 갈래 풀포기(초록, 위로 뻗음).
			for dx in [0.28, 0.5, 0.72]:
				draw_line(px + Vector2(TILE * dx, TILE * 0.8), px + Vector2(TILE * dx, TILE * 0.35),
					Color(0.35, 0.62, 0.28), 2.0)
			draw_line(px + Vector2(TILE * 0.28, TILE * 0.55), px + Vector2(TILE * 0.16, TILE * 0.4), Color(0.35, 0.62, 0.28), 2.0)
			draw_line(px + Vector2(TILE * 0.72, TILE * 0.55), px + Vector2(TILE * 0.84, TILE * 0.4), Color(0.35, 0.62, 0.28), 2.0)
		else:
			# 벤 자리 = 낮은 마른 밑동(재생 대기 — 며칠 뒤 다시 자람).
			draw_line(px + Vector2(TILE * 0.35, TILE * 0.78), px + Vector2(TILE * 0.35, TILE * 0.66), Color(0.6, 0.56, 0.34), 2.0)
			draw_line(px + Vector2(TILE * 0.6, TILE * 0.78), px + Vector2(TILE * 0.6, TILE * 0.66), Color(0.6, 0.56, 0.34), 2.0)

# ★ ADR-0052 딴 꽃 패치 자리 = 낮은 새싹(재생 대기 — REGROW_DAYS 뒤 다시 핌). 폄 상태는 _draw_props_for가
#   PROP_FLOWER_PATCH 풀 스프라이트로 그리므로 여기선 딴 자리(비-폄)만 그린다. 순수 시각(상태는 노드 소유).
func _draw_flower_regrow() -> void:
	if flower == null or _region != RegionCatalog.HOME:
		return
	for tile in flower.all_tiles():
		if flower.is_bloomed(tile):
			continue   # 폄 = _draw_props_for가 풀 패치로(중복 방지)
		var px := Vector2(tile.x * TILE, tile.y * TILE)
		# 딴 자리 = 어린 초록 새싹 두 갈래(며칠 뒤 다시 핌). 사료풀 밑동과 색을 갈라(초록) 채집물임을 읽힘.
		draw_line(px + Vector2(TILE * 0.42, TILE * 0.72), px + Vector2(TILE * 0.36, TILE * 0.56), Color(0.40, 0.66, 0.34), 2.0)
		draw_line(px + Vector2(TILE * 0.58, TILE * 0.72), px + Vector2(TILE * 0.64, TILE * 0.56), Color(0.40, 0.66, 0.34), 2.0)

# ★ [ADR-0055] 밤새 돋은 재점령 잡초를 그린다 — 이승의 미련(잡초) 스프라이트를 빈 맨땅 위에 평면 데칼로.
#   debris 잡초와 같은 텍스처·변주(좌표 결정적 해시)를 써 개간 대상과 시각 동일(낫 대상임을 읽힘). 순수
#   시각(상태는 reclaim 노드 소유). 평면이라 그림자·Y-split 없음(back 레이어 = 플레이어 아래, debris 잡초 결).
func _draw_encroach_weeds() -> void:
	if reclaim == null or _region != RegionCatalog.HOME:
		return
	var tsz := PROP_DEBRIS_WEEDS.get_size()
	for t in reclaim.weed_tiles():
		var tex := _debris_variant_tex(PROP_DEBRIS_WEEDS, t)
		draw_texture_rect(tex, Rect2(Vector2(t.x * TILE, t.y * TILE), tsz), false)

# ★ [Phase E/S1-15] 가축 스프라이트 훅 — assets/livestock/<species>_<stage>.png(gemini-demo-sprites-spec §5,
#   bottom-center 앵커, dak 32²·so_baby 48²·so_adult 64×48). owner Gemini 결과가 이 경로에 들어오면 코드
#   무수정으로 렌더된다(placeholder=그레이박스 폴백). 종·단계별 1회 조회 후 캐시(없음=null도 캐시).
var _livestock_tex: Dictionary = {}
func _livestock_sprite(species: String, stage: String) -> Texture2D:
	var key := species + "_" + stage
	if _livestock_tex.has(key):
		return _livestock_tex[key]
	var path := "res://assets/livestock/%s.png" % key
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_livestock_tex[key] = tex
	return tex

# ★ [B1-a.3/B2] 야외 농장 인프라 프롭 스프라이트 훅 — assets/props/<name>.png(gemini-demo-sprites-spec §8).
#   여물광·혼우물·사료풀 아트가 이 경로에 들어오면 코드 무수정 렌더(없으면 그레이박스 폴백). 1회 조회 후
#   캐시(없음=null도 캐시). 로더만 범용, 앵커·오버레이는 각 _draw_*가 정한다(구조물=facade 앵커, 사료풀=타일).
var _prop_tex_cache: Dictionary = {}
func _prop_tex(name: String) -> Texture2D:
	if _prop_tex_cache.has(name):
		return _prop_tex_cache[name]
	var path := "res://assets/props/%s.png" % name
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_prop_tex_cache[name] = tex
	return tex

func _draw_ranch() -> void:
	if ranch == null:
		return
	# ★ [B1-a.2] 방목 문 상태 표식 — 각 동물 건물 외관 문 앞에 열림=초록·닫힘=적 사각(실외 HOME 뷰에서
	#   문 여닫힘을 읽는다). 실내 뷰(카메라 y66+)에선 이 y16 표식이 화면 밖이라 안 보인다.
	for pair in [["넋우릿간", NEOKURITGAN_EXT_DOOR], ["넋둥우리", NEOKDUNGURI_EXT_DOOR]]:
		var dt: Vector2i = pair[1]
		var dpx := Vector2(dt.x * TILE, dt.y * TILE)
		var col := Color(0.4, 0.85, 0.45) if ranch.door_open(str(pair[0])) else Color(0.72, 0.3, 0.3)
		draw_rect(Rect2(dpx + Vector2(TILE * 0.28, TILE * 0.28), Vector2(TILE * 0.44, TILE * 0.44)), col)
	for tile in ranch.animal_tiles():
		# ★ [B1-a.2] 방목 나간 짐승은 방목지 타일에, 실내 거주 짐승은 소속 건물 실내 앵커에 그린다.
		#   두 좌표가 서로 다른 카메라 밴드(방목=y18~·실내=y74+)라, 현재 뷰(실내/실외)에 맞는 것만 화면에 든다.
		var draw_tile: Vector2i = ranch.pasture_tile_of(tile) if ranch.is_outside(tile) else tile
		var px := Vector2(draw_tile.x * TILE, draw_tile.y * TILE)
		var sp := ranch.species_at(tile)
		var baby: bool = not ranch.is_adult(tile)   # ★ [Phase E/S1-15] 새끼(성장 중)면 작게·산물 없음.
		# ★ [Phase E/S1-15] 스프라이트 훅(Gemini 후행 계약): assets/livestock/<species>_<stage>.png가 있으면
		#   bottom-center 앵커로 그린다(gemini-demo-sprites-spec §5). 없으면(현재) 그레이박스 몸통으로 폴백.
		var tex := _livestock_sprite(sp, ranch.stage_of(tile))
		if tex != null:
			var sz := tex.get_size()
			draw_texture(tex, px + Vector2((TILE - sz.x) * 0.5, TILE - sz.y))   # 발치(bottom-center)를 타일 바닥에
		else:
			var scl := 0.62 if baby else 1.0   # 새끼 = 성체 대비 ~0.6배 몸집(spec §5.1 "새끼로 즉시 읽히게")
			var body := Color(0.92, 0.86, 0.6) if AnimalCatalog.kind_of(sp) == "coop" else Color(0.55, 0.38, 0.28)
			if baby:
				body = body.lightened(0.12)     # 새끼 = 살짝 밝게(솜털 결)
			var bw := TILE * 0.7 * scl
			var bh := TILE * 0.6 * scl
			var bx := px.x + (TILE - bw) * 0.5
			var by := px.y + TILE - bh - TILE * 0.2   # 발치를 타일 하단에 맞춤(그레이박스도 bottom-center 결)
			draw_rect(Rect2(Vector2(bx, by), Vector2(bw, bh)), body)
			draw_circle(Vector2(px.x + TILE * 0.5, by - TILE * 0.02), TILE * 0.14 * scl, body.darkened(0.3))
		if ranch.has_product(tile):   # 대기 산물 = 머리 위 밝은 점(수집 신호 — 성체만 has_product)
			draw_circle(px + Vector2(TILE * 0.5, TILE * 0.05), TILE * 0.12, Color(1.0, 0.95, 0.5))
		var hearts := ranch.hearts_of(tile)   # 우정 하트 바(하단 5칸 — 새끼도 우정을 쌓으므로 표시)
		for i in 5:
			var hp := px + Vector2(TILE * (0.1 + i * 0.16), TILE * 0.88)
			draw_rect(Rect2(hp, Vector2(TILE * 0.12, TILE * 0.08)),
				Color(0.85, 0.3, 0.4) if i < hearts else Color(0.3, 0.3, 0.3, 0.6))

# 외부 건물 외관을 외관 박스 좌상단에 1:1로 그린다(이미지 크기 = 박스 크기). 통과 불가 WALL
# 박스를 도트 외관이 덮어 "닫힌 건물"이 되고, 문 칸(외관 하단 중앙)에 닿으면 실내로 fade 전환한다.
# 실내 모드에선 외관 자리(외부)가 카메라 밖이라 그려져도 보이지 않는다.
# ★ M1.4 — 외관을 구역별로 갈라 그린다(집=안식 농원, 카페=나루 마을). 카페 이주로 카페 외관은
# 더는 안식 농원에 없고 나루 마을 야외에만 선다.
# ★ T3③ 집 실내 북벽 plank 밴드 — 방 북쪽 상단 행(y67, x 내부)에 plank 벽 텍스처를 가로로 깔아
#   1타일 wainscoting(y68 걸레받이) 위에 입체 벽을 세운다. 가구(_draw_props)보다 *먼저* 그려
#   침대·벽난로·책장이 그 위로 솟아 벽을 자연스럽게 덮는다(스타듀 2.5D). 집 실내(카메라 격리)에서만 보임.
func _draw_house_wall_band() -> void:
	var y0 := HOME_HOUSE_RECT.position.y                                 # y67 — 상단 벽 첫 행
	for x in range(HOME_HOUSE_RECT.position.x + 1, HOME_HOUSE_RECT.end.x - 1):  # 내부 x9..18
		for dy in 2:                                                     # 2행(y67·y68) = 입체 크림 벽 밴드
			draw_texture_rect(TEX_HOUSE_WALL_BAND, Rect2(Vector2(x * TILE, (y0 + dy) * TILE), Vector2(TILE, TILE)), false)

# ★[ADR-0043] facade 블렌드 — facade 아트는 footprint(WALL 박스)보다 작아 *투명 가장자리로 회색 WALL
# 그레이박스가 비친다*(새 lush 풀과 안 어울림). 충돌·grid·테스트(=WALL)는 그대로 두고, facade를 그리기
# *직전*에 그 footprint를 풀 베이스 타일로 덮어(시각 전용) 투명부가 풀로 비치게 한다 → 자연스러운 블렌드.
# ★[ADR-0054 건물 접지] 안식 농원(HOME)은 흙-지배 flip으로 세계가 tan이라, 이 풀 백드롭이 건물마다
#   *초록 사각형*을 낳는 회귀가 됐다(ADR-0053 flip). HOME은 ground16(_build_ground16)이 이미 WALL
#   footprint 칸을 월드-정렬 맨흙으로 칠하고(잔디억제 패드까지), 그 위 투명부에 seamless하게 비치므로
#   풀 백드롭을 건너뛴다(이중 그리기 제거 = 초록 사각 소멸·씸 프리). 그 외 구역은 초록 세계라 유지.
var _facade_grass_tex: Texture2D = null
func _facade_grass_backdrop(rect: Rect2i) -> void:
	if _region == RegionCatalog.HOME:
		return
	if _facade_grass_tex == null:
		var src := ground.tile_set.get_source(0) as TileSetAtlasSource
		var rs: int = src.texture_region_size.x
		var coord := _terrain_base_atlas(TR_GRASS)
		var img: Image = src.texture.get_image()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var g := Image.create(rs, rs, false, Image.FORMAT_RGBA8)
		g.blit_rect(img, Rect2i(coord.x * rs, coord.y * rs, rs, rs), Vector2i.ZERO)
		_facade_grass_tex = ImageTexture.create_from_image(g)
	draw_texture_rect(_facade_grass_tex, Rect2(Vector2(rect.position * TILE), Vector2(rect.size * TILE)), true)

# ★[ADR-0037 §3] 안식 건물 facade = bottom-center 앵커 + SE 접지 그림자(§11). facade 아트는 footprint
# (WALL 박스)보다 클 수 있어(지붕이 위로 솟음), art 바텀을 footprint 하단 경계에·가로 중앙에 맞춰
# "땅에 앉은" 정면 건물로 그린다. 문(art 하단 중앙)이 door 타일(rect 하단 중앙)과 1:1. 충돌·grid·
# 테스트(=WALL rect)는 불변 — 순수 시각. 접지 그림자는 반투명 타원(별도 즉시모드, 건물 아래).
func _blit_facade_anchored(tex: Texture2D, rect: Rect2i) -> void:
	_facade_grass_backdrop(rect)
	var cx := (rect.position.x + rect.size.x * 0.5) * TILE
	var base_y := float((rect.position.y + rect.size.y) * TILE)
	var sz := tex.get_size()
	# ★[§11 접지] art 바텀 = 건물 실제 밑단(bbox 트림). 밑단 폭에 *근접*한 납작 타원을 밑단에 밀착
	# (대부분 건물 뒤에 숨고 SE로 얇은 슬리버만 삐져나옴)시켜 넓은 건물도 좌우 코너까지 "땅에 앉게" 한다.
	# ★가로반경=밑단폭×0.48(코너 접지 — 예전 0.42는 좁아 넓은 본가 코너가 떴다). 세로반경은 폭과 거의
	# 무관하게 납작 고정(10+폭×0.02)이라 폭이 커도 '접시'로 뜨지 않는다. 소폭 SE(우+하)로 NW 광원(§1) 정합.
	# ★[§11 접지] 그림자 원리 = "데크 밑단선에 핀한 반원"(owner 교정 2026-07-02):
	#   앵커 y = *데크 밑단선*(base_y=계단 최하단이 아니라 넓은 지면접촉선 — _facade_base_span). 중심을 이
	#   선에 두어 타원 양끝(가로 극점)이 데크 좌·우 모서리에 닿고, 건물을 뒤에 그리므로 *아래 반원만* 풀
	#   위로 살짝 고인다. 중앙 계단은 이 선 아래로 내려가 진입로로 이어져 자연스럽다(계단 끝에 끌려
	#   그림자가 뜨던 문제 해소). 가로반경 = 실측 데크 반폭(양끝=진짜 모서리).
	# ★[§11/§1 접지] 캐스트 그림자 = 건물 실루엣을 SE(우하단)로 투사(owner 재설계 2026-07-02):
	#   NW(좌상단) 광원(§1)이라 그림자는 SE로 눕는다. 발(데크 밑단선)은 제자리에 고정(접지)하고, 높은
	#   부분(지붕)일수록 SE로 더 뻗어 "건물 형태를 닮은" 그림자가 된다. 소프트(블러) 검정 실루엣을 shear+
	#   squash 아핀변환으로 눕혀 반투명하게 깐다(둥근 블롭·공중 부양·코너 떨어짐 문제 일괄 해소).
	var span: Dictionary = _facade_base_span(tex)
	var sil := _facade_soft_silhouette(tex)                 # 소프트 검정 실루엣(여백 _SHADOW_MARGIN 포함)
	var ly := float(span["line_y"])                         # 데크 밑단선(텍스처 로컬 y) = 발 고정선
	var x0 := cx - sz.x * 0.5                               # 건물 텍스처 world 좌상단 x
	var y0 := base_y - sz.y                                 # 〃 y
	var shear := 0.34                                       # 높이당 우측 이동(E) — 광원 elevation 감
	var squash := 0.17                                      # 높이당 하강(S)·압축 — 그림자 길이
	# 아핀: 발선(y=ly) 고정 / 위(y<ly)는 (-shear,-squash)로 SE 투사. origin이 발선을 world에 앵커.
	var xf := Transform2D(Vector2(1, 0), Vector2(-shear, -squash),
		Vector2(x0 + shear * ly, y0 + (1.0 + squash) * ly))
	draw_set_transform_matrix(xf)
	draw_texture(sil, Vector2(-_SHADOW_MARGIN, -_SHADOW_MARGIN), Color(0, 0, 0, 0.30))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# bottom-center 앵커 블릿(트림된 art 바텀 = footprint 하단 = 실제 밑단, 위로 솟음 → 지붕 오버행).
	draw_texture_rect(tex, Rect2(Vector2(cx - sz.x * 0.5, base_y - sz.y), sz), false)

# 접지 그림자를 건물 *데크 밑단선*(계단·돌출부가 아닌 넓은 지면접촉선)에 핀하기 위해, 텍스처를 행별로
# 훑어 불투명 폭이 넓은(≥최대폭×0.7) *가장 낮은* 행 = 데크/주춧돌 밑단선을 찾는다. 중앙 계단은 그 아래로
# 돌출(더 좁음)해 이 선에 안 걸리므로, 그림자가 계단 끝에 끌려 내려가 뜨는 문제를 없앤다(owner 지적).
# 돌려주는 값: {line_y(텍스처 로컬 밑단선 y), center, half}. tex당 1회 측정 후 캐시.
func _facade_base_span(tex: Texture2D) -> Dictionary:
	if _facade_base_cache.has(tex):
		return _facade_base_cache[tex]
	var img := tex.get_image()
	var w := img.get_width()
	var h := img.get_height()
	var max_width := 0
	var rows: Array = []   # [y, lo, hi, width]
	for y in range(h):
		var lo := w
		var hi := -1
		for x in range(w):
			if img.get_pixel(x, y).a > 0.5:
				if x < lo:
					lo = x
				if x > hi:
					hi = x
		var width := (hi - lo) if hi >= 0 else 0
		rows.append([y, lo, hi, width])
		if width > max_width:
			max_width = width
	# 데크 밑단선 = 폭 ≥ 최대폭×0.7 인 *가장 낮은(큰 y)* 행(계단·좁은 돌출부 배제).
	var line_y := h - 1
	var lo := 0
	var hi := w - 1
	for r in rows:
		if r[3] >= int(max_width * 0.7):
			line_y = r[0]
			lo = r[1]
			hi = r[2]
	var span := {"line_y": line_y, "center": (lo + hi) * 0.5, "half": maxf(1.0, (hi - lo) * 0.5)}
	_facade_base_cache[tex] = span
	return span

# 캐스트 그림자용 소프트 실루엣 = 건물 알파를 검정으로, 가장자리를 박스블러(부드러움). 여백
# _SHADOW_MARGIN을 둘러 블러가 잘리지 않게 한다. tex당 1회 생성·캐시(_draw 매프레임 대비).
func _facade_soft_silhouette(tex: Texture2D) -> ImageTexture:
	if _facade_shadow_sil_cache.has(tex):
		return _facade_shadow_sil_cache[tex]
	var img := tex.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var m := _SHADOW_MARGIN
	var sw := w + m * 2
	var sh := h + m * 2
	var a := PackedFloat32Array()
	a.resize(sw * sh)   # 0.0 초기화
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.5:
				a[(y + m) * sw + (x + m)] = 1.0
	a = _box_blur_1d(a, sw, sh, 2, true)    # 수평 블러
	a = _box_blur_1d(a, sw, sh, 2, false)   # 수직 블러
	var out := Image.create(sw, sh, false, Image.FORMAT_RGBA8)
	for y in range(sh):
		for x in range(sw):
			out.set_pixel(x, y, Color(0, 0, 0, clampf(a[y * sw + x], 0.0, 1.0)))
	var t := ImageTexture.create_from_image(out)
	_facade_shadow_sil_cache[tex] = t
	return t

# 분리형 박스 블러 1D(수평/수직). 가장자리 clamp. 소프트 그림자 엣지용.
func _box_blur_1d(src: PackedFloat32Array, w: int, h: int, r: int, horizontal: bool) -> PackedFloat32Array:
	var dst := PackedFloat32Array()
	dst.resize(src.size())
	var norm := 1.0 / float(2 * r + 1)
	if horizontal:
		for y in range(h):
			var base := y * w
			for x in range(w):
				var s := 0.0
				for k in range(-r, r + 1):
					s += src[base + clampi(x + k, 0, w - 1)]
				dst[base + x] = s * norm
	else:
		for x in range(w):
			for y in range(h):
				var s := 0.0
				for k in range(-r, r + 1):
					s += src[clampi(y + k, 0, h - 1) * w + x]
				dst[y * w + x] = s * norm
	return dst

func _draw_facade_home() -> void:
	_blit_facade_anchored(FACADE_HOUSE, HOUSE_EXT_RECT)

# ★ T3 — 안식 농원 서비스 건물 외관(창고 NE·동물 건물 고지). 카페·집 외관과 같은 결 — 통과 불가 WALL
# 박스(_build_facade) 위에 1:1로 덮어 "닫힌 건물"로 읽히게 한다. 창고·동물 건물 모두 enterable(문 트리거).
# 그리기 전용, 충돌·동선 불변.
func _draw_facade_storehouse() -> void:
	_blit_facade_anchored(FACADE_STOREHOUSE, STOREHOUSE_EXT_RECT)

# ★ [B1-a.1 / 아트 배선] 동물 2건물 외관. 넋우릿간=barn_ext(6×4), 넋둥우리=coop_ext(4×2·문 우측) —
# 둘 다 Gemini facade 배치 완료(owner 2026-07-03), _blit_facade_anchored로 WALL 박스 위에 1:1 덮음.
func _draw_facade_barn() -> void:
	_blit_facade_anchored(FACADE_BARN, NEOKURITGAN_EXT_RECT)
	_blit_facade_anchored(FACADE_COOP, NEOKDUNGURI_EXT_RECT)

func _draw_facade_cafe() -> void:
	_facade_grass_backdrop(CAFE_EXT_RECT)
	draw_texture_rect(FACADE_CAFE, Rect2(Vector2(CAFE_EXT_RECT.position * TILE), FACADE_CAFE.get_size()), false)

# ★ C2 무인 출하함 상자(그레이박스 — 진짜 아트는 후속). SHIP_BIN_TILE 칸에 나무 궤짝 형태를
# 절차 도형으로 그린다(가구 프롭과 같은 결 — 충돌·세이브 없는 순수 장식, 상태는 ship_bin이 든다).
# 카페 카메라(CAFE_CAM_RECT)만 이 칸을 비추므로 카페 안에서만 보인다(손님·잡귀 그리기와 같은 결).
func _draw_ship_bin() -> void:
	var ox := SHIP_BIN_TILE.x * TILE
	var oy := SHIP_BIN_TILE.y * TILE
	var box := Rect2(ox + 3, oy + 8, TILE - 6, TILE - 12)
	draw_rect(box.grow(1.0), Color(0.20, 0.14, 0.09))           # 외곽선(어두운 나무)
	draw_rect(box, Color(0.46, 0.32, 0.18))                     # 궤짝 본체(나무빛)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 4)), Color(0.58, 0.42, 0.24))  # 뚜껑 밝은 띠
	# 정면 빗금 두 줄(널판 이음새)로 "상자"임을 읽히게 한다.
	draw_rect(Rect2(box.position.x, box.position.y + box.size.y * 0.5, box.size.x, 1), Color(0.28, 0.19, 0.11))
	# 대기 중이면 살짝 열린 표시(밝은 점) — "넣어 둔 게 있다"를 눈에 보이게.
	if ship_bin != null and not ship_bin.is_empty():
		draw_rect(Rect2(ox + TILE * 0.5 - 2, oy + 4, 4, 4), Color(0.90, 0.82, 0.45))

# ★ ADR-0048 Phase D 저장 상자(그레이박스 — 진짜 아트는 후속 스프라이트). CHEST_TILE 칸에 나무 궤짝을
# 절차 도형으로 그린다(출하함과 같은 결이되 자물쇠 걸쇠로 "보관함"임을 구분). 집 카메라(HOME_HOUSE_CAM_RECT)
# 안에서만 보인다. 좌표가 HOME 밴드라 region==HOME일 때 그리면 집 안에서만 눈에 든다(출하함과 같은 결).
# ★ [ADR-0048 Phase E/S1-15] Track B 건물 실내 가구 placeholder(그레이박스 — 아트 Gemini 후행). 동물
#   건물엔 여물통(여물광 건초 재고에 비례해 건초가 담긴 시각 — 급여 경제와 연결), 갈무리방(창고)엔 보관
#   크레이트를 그린다. 세 방이 서로 다른 카메라 밴드라 현재 뷰(들어간 방)만 화면에 든다(순수 시각·비충돌).
func _draw_trackb_interiors() -> void:
	if ranch == null:
		return
	var fill := ranch.silo_fill_ratio()   # 여물광 건초 비율(두 동물 건물 공유 — 여물통 담김 정도)
	_draw_feed_trough(NEOKURITGAN_RECT, fill)   # 넋우릿간(대형·안개소)
	_draw_feed_trough(NEOKDUNGURI_RECT, fill)   # 넋둥우리(소형·노을닭)
	_draw_storehouse_crates(STOREHOUSE_RECT)    # 갈무리방(창고) 보관 크레이트

# 동물 건물 실내 여물통(북측 내부 행에 가로 나무통 + 여물광 건초 비율만큼 채워진 건초). 비충돌 시각.
func _draw_feed_trough(room: Rect2i, fill: float) -> void:
	var x0 := float((room.position.x + 2) * TILE)
	var w := float((room.size.x - 4) * TILE)
	var y := float((room.position.y + 2) * TILE) + TILE * 0.4
	var h := TILE * 0.5
	# ★ 아트 훅: assets/props/feed_trough.png(32×16 세그먼트) 있으면 방 폭에 가로 타일링, 없으면 그레이박스.
	#   건초는 어느 쪽이든 동적 오버레이(여물광 재고 비율 → 아트 여물칸 안쪽에 담김).
	var tex := _prop_tex("feed_trough")
	if tex != null:
		draw_texture_rect(tex, Rect2(x0, y, w, h), true)                     # 가로 반복(tile=true)
	else:
		draw_rect(Rect2(x0 - 2, y - 2, w + 4, h + 4), Color(0.18, 0.13, 0.08))   # 외곽선(어두운 나무)
		draw_rect(Rect2(x0, y, w, h), Color(0.34, 0.24, 0.15))                   # 여물통 본체
		draw_rect(Rect2(x0, y, w, 3), Color(0.46, 0.33, 0.2))                    # 위 테두리 밝은 띠
	var hay_w := w * clampf(fill, 0.0, 1.0)                                  # 담긴 건초 = 여물광 재고 비율
	if hay_w > 1.0:
		draw_rect(Rect2(x0, y + 3, hay_w, h - 4), Color(0.82, 0.7, 0.3))     # 건초(따뜻한 노랑 — 아트 여물칸 위)

# 갈무리방(창고) 실내 보관 크레이트 — 동벽 flush로 나무 상자 몇 개(빈 창고를 "보관 공간"으로 읽히게). 비충돌 시각.
func _draw_storehouse_crates(room: Rect2i) -> void:
	var ex := float((room.end.x - 2) * TILE)   # 동벽 안쪽 한 칸
	# ★ 아트 훅: assets/props/storehouse_crate.png(32²) 있으면 3단 적층 크레이트로 렌더(칸당 1장·교대 반전
	#   으로 반복감 완화), 없으면 그레이박스. bottom-center는 칸 그리드 정렬(스택이 위로 쌓임).
	var tex := _prop_tex("storehouse_crate")
	for i in 3:                                # 3단 적층 크레이트
		if tex != null:
			var sz := tex.get_size()
			var cy := float((room.position.y + 2 + i) * TILE) + (TILE - sz.y)   # 칸 바닥 정렬
			if i % 2 == 1:                     # 교대 좌우반전(3장 반복감 완화)
				draw_set_transform(Vector2(ex + sz.x, cy), 0.0, Vector2(-1, 1))
				draw_texture(tex, Vector2.ZERO)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture(tex, Vector2(ex, cy))
			continue
		var y := float((room.position.y + 2 + i) * TILE) + TILE * 0.15
		var s := TILE * 0.7
		draw_rect(Rect2(ex, y, s, s).grow(1.0), Color(0.18, 0.13, 0.08))     # 외곽선
		draw_rect(Rect2(ex, y, s, s), Color(0.45, 0.32, 0.19))               # 나무 상자
		draw_line(Vector2(ex, y + s * 0.5), Vector2(ex + s, y + s * 0.5), Color(0.3, 0.21, 0.12), 2.0)  # 판자 이음
		draw_line(Vector2(ex + s * 0.5, y), Vector2(ex + s * 0.5, y + s), Color(0.3, 0.21, 0.12), 2.0)

func _draw_chest() -> void:
	# ★ Phase E — 집 상자·창고 상자 둘 다 그린다. 두 칸이 서로 다른 카메라 밴드(집 y68·창고 y81)라 현재
	#   뷰에 맞는 것만 화면에 든다(_draw_ranch와 같은 결 — 좌표로 자동 클립).
	_draw_chest_at(CHEST_TILE, chest)
	_draw_chest_at(STOREHOUSE_CHEST_TILE, storehouse_chest)

# 저장 상자 궤짝 하나를 타일에 그린다(그레이박스 — 잠금 걸쇠로 출하함과 시각 구분, 보관 중이면 뚜껑 점).
func _draw_chest_at(t: Vector2i, box_chest: StorageChest) -> void:
	var ox := t.x * TILE
	var oy := t.y * TILE
	var box := Rect2(ox + 3, oy + 8, TILE - 6, TILE - 12)
	draw_rect(box.grow(1.0), Color(0.18, 0.13, 0.08))           # 외곽선(어두운 나무)
	draw_rect(box, Color(0.50, 0.35, 0.20))                     # 궤짝 본체(따뜻한 나무빛 — 출하함보다 밝은 톤)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 4)), Color(0.64, 0.46, 0.26))  # 뚜껑 밝은 띠
	# 정면 금속 걸쇠(자물쇠) — "잠기는 보관함"으로 읽히게(출하함과 시각 구분).
	draw_rect(Rect2(ox + TILE * 0.5 - 3, oy + 10, 6, 5), Color(0.82, 0.74, 0.42))
	# 보관 중이면 뚜껑 위 밝은 점 — "넣어 둔 게 있다"(출하함과 같은 결).
	if box_chest != null and not box_chest.is_empty():
		draw_rect(Rect2(ox + TILE * 0.5 - 2, oy + 4, 4, 4), Color(0.92, 0.86, 0.52))

# ★ M2.5 — 나루 마을 메인 집 3채 외관(카페와 같은 결 — 통과 불가 WALL 박스 위 1:1 덮어 그리기).
# 본체 캐릭터별 재도색이라 라벨 없이 외관만으로 누구 집인지 읽힌다(카페 컨벤션). 그리기 전용 —
# WALL 충돌·문 트리거·동선은 그레이박스 시절 그대로(_build_naru_village), 보이는 것만 바뀐다.
func _draw_facade_village_houses() -> void:
	_facade_grass_backdrop(MEL_HOUSE_RECT)
	draw_texture_rect(FACADE_MEL_HOUSE, Rect2(Vector2(MEL_HOUSE_RECT.position * TILE), FACADE_MEL_HOUSE.get_size()), false)
	_facade_grass_backdrop(MIHO_HOUSE_RECT)
	draw_texture_rect(FACADE_MIHO_HOUSE, Rect2(Vector2(MIHO_HOUSE_RECT.position * TILE), FACADE_MIHO_HOUSE.get_size()), false)
	_facade_grass_backdrop(BANA_HOUSE_RECT)
	draw_texture_rect(FACADE_BANA_HOUSE, Rect2(Vector2(BANA_HOUSE_RECT.position * TILE), FACADE_BANA_HOUSE.get_size()), false)

# M2.4 — 카페 이벤트 데이 축제 장식(절차 도형, 새 에셋 0 — Phase 2 경계 준수). 카메라가 카페
# 방(CAFE_CAM_RECT)만 비추므로 CAFE_RECT 좌표에 그리면 카페 실내에서만 보인다(다른 구역·집/
# 만물상 방은 카메라 밖). 카페 프롭 다음에 그려 그 위에 얹히되, 무대 카펫은 반투명이라 스툴·
# 테이블이 비쳐 "바닥에 깔린" 결을 낸다(_draw_props_for 순서의 짝). festival.gd가 색의 단일 출처.
func _draw_cafe_festival() -> void:
	var r := CAFE_RECT
	# ① 무대 카펫: 손님석 중앙 바닥에 붉은 러그(반투명 — 스툴·테이블이 비친다).
	var rug := Rect2(Vector2((r.position.x + 2) * TILE, (r.position.y + 5) * TILE),
		Vector2((r.size.x - 4) * TILE, 3 * TILE))
	draw_rect(rug, Festival.RUG)
	# ② 천장 가랜드: 상단 벽 아래 가로로 홍·황 번갈아 삼각 깃발(잔치 줄 — 카운터·선반 위로 매달림).
	var y := float((r.position.y + 1) * TILE - 4)   # 상단 벽(첫 줄) 하단에 매달림
	for i in range(r.position.x + 1, r.end.x - 1):
		var x := float(i * TILE)
		var col: Color = Festival.BANNER_A if (i % 2 == 0) else Festival.BANNER_B
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, y), Vector2(x + TILE, y), Vector2(x + TILE * 0.5, y + 12.0)]), col)

# ★ M1.4 — 넘겨받은 가구 배열(현재 구역 것)만 그린다. PROP_LAYOUT_HOME/PROP_LAYOUT_CAFE를
# _draw가 구역에 맞춰 골라 넘긴다(다른 구역 가구가 떠다니지 않게).
# ★[asset-ruleset §6] Y-split 패스 모드 — 한 프롭 인스턴스의 발치(base) 스크린 Y를 split_y(플레이어
#   발치)와 비교해 앞/뒤를 가른다. ALL=전부(카페·실내·마을 등 Y-split 불필요), BACK=플레이어 뒤
#   (base ≤ split, main._draw = 플레이어 아래), FRONT=플레이어 앞(base > split, _front_props = 위).
const _PROP_PASS_ALL := 0
const _PROP_PASS_BACK := 1
const _PROP_PASS_FRONT := 2

# 프롭 인스턴스 발치(base) 스크린 Y — top-left blit(+yo) 기준 art 하단. Y-split·그림자·테스트 공용 출처.
func _prop_base_y(t: Vector2i, yo: int, tex: Texture2D) -> float:
	return float(t.y * TILE + yo) + tex.get_size().y

# ★[roster §5.2] debris 변주 선택 — 좌표 결정적 해시로 kind별 3변주 중 하나(같은 kind가 맵에서 3형태로
#   다양). 정체성 토큰이 DEBRIS_VARIANTS에 없으면(=debris 아님) 원본 그대로. 순수 시각(충돌·kind 무관).
func _debris_variant_tex(tex: Texture2D, t: Vector2i) -> Texture2D:
	var vs: Array = DEBRIS_VARIANTS.get(tex, [])
	if vs.is_empty():
		return tex
	return vs[(t.x * 7 + t.y * 13) % vs.size()]

# canvas = 실제로 그릴 CanvasItem — Godot draw_*는 *현재 _draw 중인 그 노드*에서만 허용되므로,
#   뒤 패스는 main(self)·앞 패스는 _front_props(플레이어 위 레이어)가 canvas로 넘어온다.
func _draw_props_for(layout: Array, canvas: CanvasItem, pass_mode: int = _PROP_PASS_ALL, split_y: float = 0.0) -> void:
	for entry in layout:
		var tex: Texture2D = entry[0]
		var yo: int = entry[2] if entry.size() > 2 else 0   # ★ T3③ 벽 가구 시각 보정(밀착, 좌표·충돌 무관)
		var casts_shadow: bool = tex in PROP_SHADOW_SET
		var is_debris: bool = DEBRIS_KIND.has(tex)          # ★ [S1-8] 치운 debris는 skip(안 그림)
		var is_flower: bool = tex == PROP_FLOWER_PATCH      # ★ ADR-0052 딴 꽃 패치는 skip(새싹은 _draw_flower_regrow가 그림)
		var tsz := tex.get_size()
		for t in entry[1]:
			# ★ [S1-8 §10.3] 개간한 debris 타일은 안 그린다(reclaim 델타 skip-filter — _prop_layouts 시드는 불변).
			if is_debris and reclaim != null and reclaim.is_cleared(t):
				continue
			# ★ ADR-0052 딴 꽃 패치는 풀 스프라이트를 숨긴다(reclaim 결 skip-filter). 재생 대기 새싹은 별도 패스.
			if is_flower and flower != null and not flower.is_bloomed(t):
				continue
			# Y-split: 부피 프롭(그림자 세트)만 앞/뒤로 갈린다 — 평면 데칼(러그·꽃·울타리·잡초 등)은
			#   발치 개념이 없어 늘 뒤(플레이어 아래). 경계 base==split은 BACK. ALL이면 전부 그린다.
			if pass_mode != _PROP_PASS_ALL:
				var is_front: bool = casts_shadow and _prop_base_y(t, yo, tex) > split_y
				if pass_mode == _PROP_PASS_BACK and is_front:
					continue
				if pass_mode == _PROP_PASS_FRONT and not is_front:
					continue
			# ★[§11] 부피 프롭이면 발치에 SE 접지 그림자 먼저(프롭 본체 아래). 순수 시각.
			if casts_shadow:
				_draw_prop_shadow(canvas, t, yo, tsz)
			# ★[roster §5.2] debris는 좌표 결정적 해시로 3변주 중 하나를 그린다(같은 kind가 맵에서 다양).
			#   변주 3장은 tex와 동일 크기(32×32)라 tsz·발치·그림자·Y-split 계산은 정체성 토큰 그대로 유효.
			#   덤불도 같은 해시로 2변주(dark↔bright)를 그린다 — 64×64 동일 크기라 발치·그림자 불변.
			var draw_tex: Texture2D = tex
			if is_debris:
				draw_tex = _debris_variant_tex(tex, t)
			elif BUSH_VARIANTS.has(tex):
				# 능선 한 줄 세로 스택 → (x + y/2)%2로 dark↔bright 교대(x 고정이라 y/2가 교대 축).
				var bvs: Array = BUSH_VARIANTS[tex]
				draw_tex = bvs[(t.x + t.y / 2) % bvs.size()]
			# ★ 초록 프롭(잔디뭉치·잡초·나무·덤불)은 필드 잔디 톤에 맞춰 muted(owner "초록 전부").
			#   목본(나무·덤불)은 완화 강도로 입체감 보존. tex=정체성으로 판별, draw_tex=변주별 캐시.
			if _MUTE_GREEN_PROPS.has(tex):
				draw_tex = _muted_prop_tex(draw_tex, _MUTE_WOODY.has(tex))
			# ★[roster] 앞 패스 나무는 occlusion fade 알파를 modulate로 얹는다(_update_tree_fade가 lerp).
			#   뒤 패스·다른 프롭·다른 구역은 늘 불투명(get 기본 1.0).
			var mod := Color(1, 1, 1, 1)
			if pass_mode == _PROP_PASS_FRONT and tex in FADE_PROPS:
				mod.a = _tree_fade.get(t, 1.0)
			# ADR-0013: 가구 아트도 32px native라 1:1로 그린다(스툴 32×32=1칸, 침대 32×64=1×2칸).
			canvas.draw_texture_rect(draw_tex, Rect2(Vector2(t.x * TILE, t.y * TILE + yo), tsz), false, mod)

# ★[asset-ruleset §11] 부피 프롭 발치 SE 접지 그림자 — 스프라이트에 굽지 않고 별도 반투명 타원을
#   밑단 바로 아래에 깐다(배치 100% 자유·"뜬 느낌" 방지). facade _blit_facade_anchored와 같은 결.
#   NW 광원(§1)이라 그림자는 SE(우·하) 방향으로 살짝 치우친다. 접지점(밑단 중앙) 기준.
func _draw_prop_shadow(canvas: CanvasItem, t: Vector2i, yo: int, tsz: Vector2) -> void:
	var cx := t.x * TILE + tsz.x * 0.5 + 2.0        # SE — 밑단 중앙에서 우측으로 살짝
	var base_y := float(t.y * TILE + yo) + tsz.y - 2.0   # art 밑단 바로 위(발치)
	canvas.draw_set_transform(Vector2(cx, base_y), 0.0, Vector2(1.0, 0.22))   # 납작한 타원
	canvas.draw_circle(Vector2.ZERO, tsz.x * 0.40, Color(0, 0, 0, 0.30))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ★[asset-ruleset §6] 플레이어보다 앞(발치 아래)의 HOME 야외 프롭을 플레이어 위 레이어(_front_props)에서
#   다시 그린다. main._draw는 뒤 프롭만(플레이어 아래) → 이 짝으로 캐릭터가 나무·바위 뒤로 가려진다.
#   canvas = _front_props(그리기 주체) — draw_*가 그 노드에서 나가야 Godot이 허용한다.
# ★[roster] 나무 occlusion fade 갱신 — HOME 야외에서 매 프레임, 각 나무가 (a) 앞 패스로 그려지고
#   (플레이어보다 앞 = 발치가 플레이어 아래) (b) 플레이어 발치를 스프라이트 rect로 덮으면 target=TREE_FADE_MIN,
#   아니면 1.0으로 move_toward. 알파가 바뀐 프레임에만 _front_props를 다시 그린다(정적이면 재드로우 0).
func _update_tree_fade(delta: float) -> void:
	var ppos := player.global_position
	var changed := false
	var live: Dictionary = {}   # 이번 프레임 나무 앵커 집합(사라진 나무의 잔여 엔트리 정리)
	for entry in _prop_layouts.get("HOME", []):
		var tex: Texture2D = entry[0]
		if not tex in FADE_PROPS:
			continue
		var yo: int = entry[2] if entry.size() > 2 else 0
		var tsz := tex.get_size()
		for t in entry[1]:
			live[t] = true
			var r := Rect2(Vector2(t.x * TILE, t.y * TILE + yo), tsz)
			var occl: bool = _prop_base_y(t, yo, tex) > ppos.y and r.has_point(ppos)
			var target: float = TREE_FADE_MIN if occl else 1.0
			var cur: float = _tree_fade.get(t, 1.0)
			if not is_equal_approx(cur, target):
				_tree_fade[t] = move_toward(cur, target, delta * TREE_FADE_SPEED)
				changed = true
	# 배치가 바뀌어(F10) 사라진 나무의 잔여 알파는 제거(다음 등장 시 1.0에서 다시 시작)
	for k in _tree_fade.keys():
		if not live.has(k):
			_tree_fade.erase(k)
	if changed and _front_props != null:
		_front_props.queue_redraw()

func _draw_front_props(canvas: CanvasItem) -> void:
	if _region != RegionCatalog.HOME or player == null:
		return
	_draw_props_for(_prop_layouts.get("HOME", []), canvas, _PROP_PASS_FRONT, player.global_position.y)

# 좌석에 앉은 손님과 머리 위 인내심 바를 그린다. 인내심이 줄수록 바가 짧아지고 붉어져
# "곧 떠난다"가 눈에 보인다(서빙 우선순위 판단의 근거). 몸체는 그레이박스지만 P2.7 톤 패스에서
# 도색 무대에 안 떠 보이게 _draw_graybox_figure로 최소 양식화한다(외곽선+음영, 진짜 아트는 Phase 3).
func _draw_customers() -> void:
	if not cafe.is_open():
		return
	for i in SEAT_TILES.size():
		if cafe.is_waiting(i):
			_draw_graybox_figure(SEAT_TILES[i], CUST, cafe.patience_ratio(i))

# T6.4 바를 연 밤(옵트인)의 바 손님과 머리 위 인내심 바를 그린다. 낮 카페 손님과 같은 좌석 줄을
# 시간대로 나눠 쓰므로(cafe 마감 후 밤 바) 그리기도 카페 손님과 똑같은 규격이고, 활성(밤 바 영업
# 중)일 때만 그린다 — 잡귀(아래 스폿 줄)와 한 화면에 떠 "막을지 받을지"가 눈에 보인다(★ 막기↔응대 경쟁).
func _draw_night_customers() -> void:
	if not night_bar.is_active():
		return
	for i in SEAT_TILES.size():
		if night_bar.is_waiting(i):
			_draw_graybox_figure(SEAT_TILES[i], CUST, night_bar.patience_ratio(i))

# T6.3 바를 연 밤(옵트인)에 깃든 잡귀(탁한 청록)와 머리 위 접근 바를 그린다. 카페 손님 그리기와
# 같은 결(노드 생성·해제 없이 main이 스폿 칸에 직접 — 그레이박스). 접근 바는 잔량이 줄수록
# 짧아지고 붉어져 "곧 닿는다"가 눈에 보인다(막기 우선순위 판단의 근거).
func _draw_jobgui() -> void:
	if not night_bar.is_active():
		return
	for i in NIGHT_SPOT_TILES.size():
		if night_bar.is_threat(i):
			_draw_graybox_figure(NIGHT_SPOT_TILES[i], JOBGUI, night_bar.approach_ratio(i))

# P2.7 ㉠ 톤 패스 — 손님·잡귀 그레이박스를 도색 무대에 안 떠 보이게 최소 양식화한 공통 그리기.
# 평면 사각형 대신 (1) 전경 캐릭터 컨벤션을 따르는 어두운 외곽선 한 겹 + (2) 상단 밝게·하단
# 어둡게 두 띠로 볼륨 + (3) 상단 양 모서리 노치로 어깨를 둥글려 "저승 그림자/혼령" 같은 형체로
# 읽히게 한다(진짜 캐릭터 아트는 Phase 3 — 여기선 그레이박스 유지가 원칙). 머리 위 상태 바
# (인내심·접근)는 잔량 비율만큼 채우고 초록→빨강으로 보간해 "곧 떠난다/닿는다"를 노출한다.
func _draw_graybox_figure(t: Vector2i, base: Color, ratio: float) -> void:
	var ox := t.x * TILE
	var oy := t.y * TILE
	var body := Rect2(ox + 4, oy + 3, TILE - 8, TILE - 6)
	draw_rect(body.grow(1.0), base.darkened(0.55))                                   # 외곽선
	var top_h := body.size.y * 0.42
	draw_rect(Rect2(body.position, Vector2(body.size.x, top_h)), base.lightened(0.14))  # 머리·어깨(밝게)
	draw_rect(Rect2(body.position + Vector2(0, top_h), Vector2(body.size.x, body.size.y - top_h)), base.darkened(0.20))  # 몸통(어둡게)
	var notch := base.darkened(0.55)                                                  # 어깨 둥글림(상단 모서리 노치)
	draw_rect(Rect2(body.position, Vector2(2, 2)), notch)
	draw_rect(Rect2(body.position + Vector2(body.size.x - 2, 0), Vector2(2, 2)), notch)
	var bar_bg := Rect2(ox + 2, oy - 3, TILE - 4, 2)                                  # 머리 위 상태 바
	draw_rect(bar_bg, Color(0, 0, 0, 0.6))
	var col := Color(0.85, 0.30, 0.25).lerp(Color(0.35, 0.80, 0.35), ratio)
	draw_rect(Rect2(bar_bg.position, Vector2(bar_bg.size.x * ratio, bar_bg.size.y)), col)

# ── 헬퍼 ──────────────────────────────────────────────────────────────────
func _set_tile(x: int, y: int, id: int) -> void:
	if x >= 0 and x < _grid_w and y >= 0 and y < _grid_h:
		_grid[y][x] = id

func _fill_rect(rect: Rect2i, id: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_set_tile(x, y, id)

# ★ M2.1 — 동선 헬퍼: 세로/가로 한 줄을 PATH로 깐다(양끝 칸 포함). L자 동선 조립용.
func _carve_v(x: int, y0: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		_set_tile(x, y, PATH)

func _carve_h(y: int, x0: int, x1: int) -> void:
	for x in range(x0, x1 + 1):
		_set_tile(x, y, PATH)

func _tile_center_px(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE * 0.5, t.y * TILE + TILE * 0.5)

func _rect_center_px(rect: Rect2i) -> Vector2:
	return Vector2((rect.position.x + rect.size.x * 0.5) * TILE,
		(rect.position.y + rect.size.y * 0.5) * TILE)

# ★ M1.4 — 구역 인지: 카페가 나루 마을로 이주해, 집·밭은 안식 농원에서만·카페는 나루 마을에서만
# 구역으로 읽힌다. 구역마다 그리드 크기가 달라도(★C3 마을 100×100·HOME 80×93) 좌표 범위가
# 겹칠 수 있으므로, 단순 Rect 판정이 아니라 현재 구역(_region)으로 먼저 가른다. 카페 실내 칸은
# 마을에서만 도달 가능하고, 집·밭은 농원에서만 도달 가능하다(실내 방·외관이 그 구역에만 지어짐).
func _zone_at(px: Vector2) -> String:
	var t := Vector2i(int(px.x) / TILE, int(px.y) / TILE)
	match _region:
		RegionCatalog.HOME:
			if HOME_HOUSE_RECT.has_point(t):   # ★C2 — HOME 집 실내(밴드 y67+)
				return "집"
			if STARTER_PATCH_RECT.has_point(t):
				return "밭"
		RegionCatalog.NARU_VILLAGE:
			if CAFE_RECT.has_point(t):
				return "카페"
	return "바깥"
