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
# [smile]/[shy]/[sad]/[talk]로 줄마다 지정한다(대사 속 [E] 등 조작키 안내는 화이트리스트
# 밖이라 표정으로 오인하지 않는다). 태그가 없거나 해당 표정 파일이 없으면 talk로, 그것도
# 없으면 표정 없는 기본 stem.png로 폴백한다.
const PORTRAIT_DIR := "res://assets/portraits/"
const PORTRAIT_STEM := {
	"미호": "miho",
	"옥자": "okja",
	"멜": "mel",
	"바나": "bana",
}
const PORTRAIT_EXPRS := ["smile", "shy", "sad", "talk"]  # 인라인 태그 화이트리스트
const PORTRAIT_FALLBACK_EXPR := "talk"

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
const WATER := 9    # 강물(통과 X — 나루 마을 동/서 분할, M2.1). 그레이박스 단색(도트 강물은 Phase 2)
const TREE := 10    # 나무(통과 X — 저승 숲·미혹의 숲 밀집 나무, M4.1). 그레이박스 단색(도트 나무는 Phase 2)
const ROCK := 11    # 바위(통과 X — 업화 갱도 바위 절벽·암반, M5.1). 그레이박스 단색(도트 바위는 Phase 2)
const N_TILES := 12

# ── P2.3 지형 도트: terrain TileSet + 실내/벽 도트 source ───────────────────
# combined_terrain.tres = PixelLab Wang 3세트(풀↔길·풀↔밭·길↔밭)를 합친 corner
# 오토타일. terrain_set_0의 terrain 순서는 컨버터 인자 순서로 고정(0=길,1=풀,2=밭).
# GROUND/PATH/SOIL은 이 terrain으로 자동 전환해 칠하고, HOUSE/CAFE/WALL(실내·벽)은
# 전환이 필요 없는 단일 면이라 별도 source(SOLID)에 16×16 도트 타일로 깐다.
const TERRAIN_TILESET_PATH := "res://assets/tiles/combined_terrain.tres"
const TERRAIN_SET := 0
const TR_PATH := 0    # dirt path
const TR_GRASS := 1   # muted grass
const TR_SOIL := 2    # tilled farm soil
# 타일 종류 → terrain id(GROUND/PATH/SOIL만 terrain으로 칠한다)
const TILE_TERRAIN := {GROUND: TR_GRASS, PATH: TR_PATH, SOIL: TR_SOIL}
# 실내/벽 source: 별도 source_id에 HOUSE/CAFE/WALL 3타일만 둔다.
const SOLID_SRC_ID := 1
const SOLID_TILES := [HOUSE, CAFE, WALL, HOUSE_WALL, CAFE_WALL, WATER, TREE, ROCK]   # 아틀라스 가로 배치 순서(= atlas x)
# ★ M2.1 — WATER는 SOLID_TEX에 도트 텍스처가 없다(강물 도트는 Phase 2). _build_tileset이
#   SOLID_TEX에 없는 타일은 COLORS 단색으로 절차 생성한다(그레이박스 강물). WALL과 같은 결의
#   통과 불가 충돌 타일이라 SOLID_TILES·충돌 루프에 함께 들어간다.
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
	Color(0.16, 0.28, 0.42),  # WATER  — 저승 강물(탁한 청록빛 — 통과 불가 강, 그레이박스)
	Color(0.11, 0.20, 0.13),  # TREE   — 저승 숲 나무(어두운 침엽 녹 — 풀 GROUND보다 짙어 빈터와 구분, 그레이박스)
	Color(0.34, 0.22, 0.20),  # ROCK   — 업화 갱도 바위(불그스름한 암반 — 풀 GROUND보다 따뜻해 빈터와 구분, 그레이박스)
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
# 외부 건물 외관(PixelLab 산출, 외관 박스 크기와 1:1). 통과 불가 WALL 박스 위에 덮어 그려
# "닫힌 건물"로 보이게 한다(_draw_facades). 집=224×192(7×6칸), 카페=256×224(8×7칸).
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
# P2.3③ 소울 등불 자리(단일 출처) — 가구 그리기(PROP_LAYOUT)와 밤 빛웅덩이(lighting)가
# 이 배열을 공유한다(좌표가 어긋나면 등불 그림과 빛이 따로 놀므로).
# ★ M1.4 — 카페가 나루 마을로 이주하며 등불도 구역이 갈렸다: 안식 농원 길가 둘 / 나루 마을 카페
#   구석 하나. 구역마다 자기 등불만 켜지게(다른 구역 등불이 떠다니지 않게) 둘로 나눈다.
const LANTERN_TILES_HOME := [Vector2i(12, 50), Vector2i(68, 50)]  # 안식 농원 길가(외부) ★C2: 80×65 메인 복도(y50) 양옆
const LANTERN_TILES_CAFE := [Vector2i(18, 91)]                    # 나루 마을 카페 구석(실내) ★C3: +48
# [텍스처, [놓을 타일들]]. 타일 좌표는 실내 레이아웃(직원 y40 / 카운터 y41 / 좌석 y42 /
# 스폿 y44) 위에 얹어 "장소"로 읽히게 배치한다. 좌석 스툴 위에는 손님 박스가 덮여 그려진다.
# ★ M1.4 — 카페 이주로 가구도 구역이 갈렸다: 안식 농원(집 가구·길가 등불·화분) / 나루 마을(카페
#   무대 가구·카페 등불). _draw_props가 현재 구역(_region)의 배열만 그린다(다른 구역 가구가
#   떠다니지 않게). 카페 내부 좌표는 안식 농원 시절과 동일하게 유지(좌표 대이동 최소화·회귀 0).
# ★ C2 — HOME 집 실내가 HOME 밴드(y67+, outdoor_h 65 아래)로 내려가 가구도 +41(=65-24) 이동.
# ★ C3 — 마을이 100×72로 커져 마을 실내(카페·공유 집)도 마을 밴드(y72+ 아래)로 +48(=72-24) 이동.
#   가구도 같은 +48 — 작동 검증된 카페/집 내부 레이아웃이 상대배치 그대로 내려간다(회귀 0).
const PROP_LAYOUT_HOME := [
	[PROP_RUG, [Vector2i(11, 71)]],                                                      # 집: 중앙 바닥 러그(맨 먼저 — 바닥)
	[PROP_BED, [Vector2i(9, 68)]],                                                       # 집: 좌상단 침대
	[PROP_FIREPLACE, [Vector2i(14, 68)]],                                                # 집: 상단 벽 벽난로
	[PROP_BOOKSHELF, [Vector2i(16, 68)]],                                                # 집: 상단 벽 책장
	[PROP_TABLE, [Vector2i(12, 71)]],                                                    # 집: 러그 위 작은 테이블
	[PROP_LANTERN, LANTERN_TILES_HOME],                                                  # 안식 농원 길가 등불 둘
	[PROP_POT, [Vector2i(18, 68), Vector2i(18, 74)]],                                    # 집 두 구석 혼령초 화분
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
	[PROP_RUG, [Vector2i(11, 78)]],
	[PROP_BED, [Vector2i(9, 75)]],
	[PROP_FIREPLACE, [Vector2i(14, 75)]],
	[PROP_BOOKSHELF, [Vector2i(16, 75)]],
	[PROP_TABLE, [Vector2i(12, 78)]],
	[PROP_POT, [Vector2i(18, 75), Vector2i(18, 81)]],
]

# ── 외부↔실내 분리(구역 사각형, 타일 좌표 Rect2i(x, y, 폭, 높이)) ─────────────
# 건물은 외부에선 통과 불가 "외관"으로 보이고, 문에 닿으면 fade로 맵 아래 별도 실내 구역으로
# 텔레포트한다(스타듀식 외부↔실내 — 문=같은 구역 안 특수 워프, _transition_to). 실내 NPC·가구·
# 좌석·_zone_at이 전부 이 상수들을 참조하므로, 좌표를 그대로 두면 참조 코드는 손대지 않아도 된다.
# ★ M1.4 — 카페가 나루 마을로 이주했다. 집(외관·실내)은 안식 농원에, 카페(외관·실내)는 나루
#   마을에 지어진다(_build_home / _build_naru_village). 카페 좌표는 안식 농원 시절과 *동일하게*
#   유지하되 마을 그리드의 같은 칸에 둔다 — 좌표 대이동 없이 카페 시뮬·NPC·좌석 상수가 그대로
#   따라온다(회귀 0). 어느 구역에서 어느 칸이 실제로 도달 가능한지는 _zone_at이 구역으로 가른다.

# 외부 외관. 통과 불가 박스 + 문 한 칸만 트리거. 집=안식 농원 / 카페=나루 마을(같은 칸 좌표 재사용).
const HOUSE_EXT_RECT := Rect2i(3, 4, 7, 6)    # x3..9, y4..9 (안식 농원)
# ★ M2.1 — 카페 외관을 나루 마을 *서편*으로 이전(world-map.md '서:카페·메인집'). 도착 칸 바로 위라
#   도착하자마자 카페가 보이는 출근 동선. 실내 좌표(CAFE_RECT·NPC·좌석)는 따로 +48 평행이동(아래
#   ★C3)이라 카페 운영·시뮬은 회귀 0 — 바뀌는 건 외관 위치·문·동선뿐. 8×7 = FACADE_CAFE 아트 1:1.
#   ★C3 — 100×72 코지-와이드: 외관을 서편 도착(3,36) 위쪽 x5..12 y25..31로 옮긴다(코지 여백).
const CAFE_EXT_RECT := Rect2i(5, 25, 8, 7)    # x5..12, y25..31 (나루 마을 서편, 도착 동선 위)
const HOUSE_EXT_DOOR := Vector2i(6, 9)    # 외관 집 문(닿으면 진입) — _carve_paths 동선과 연결(HOME)
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
const HOUSE_OUT_TILE := HOUSE_EXT_DOOR + Vector2i(0, 1)  # 외관 집 문 앞 (6,10) — HOME 집 외관(NW)
const CAFE_OUT_TILE := CAFE_EXT_DOOR + Vector2i(0, 1)    # 외관 카페 문 앞 (5,10) — 서편 카페 동선

# ── ★ C2 — 안식 농원 전용 집 실내(HOME 밴드 y67+) ─────────────────────────────
# HOME outdoor_h이 24→65로 커져, 공유 HOUSE_RECT(y26 띠)는 이제 HOME *외부*(밭/여백)와 충돌한다.
# → HOME 집 실내만 HOME 밴드(y65~92)로 분리: HOUSE_*(y26)에 +41(=65-24)을 더한 좌표. 내부 레이아웃
# (방 12×9·문·카메라 폭)은 똑같이 보존하고 y만 띠 아래로 내린다. 마을 6채는 HOUSE_*(y26) 그대로 공유
# → 마을·타 7구역 회귀 0. 외관(HOUSE_EXT_*·HOUSE_OUT_TILE)은 외부 NW라 +41 대상 아님(위 그대로).
const HOME_HOUSE_RECT := Rect2i(8, 67, 12, 9)     # x8..19, y67..75 (HOUSE_RECT + (0,41))
const HOME_HOUSE_DOOR := Vector2i(13, 75)         # 실내 집 문(아래벽 중앙) — HOUSE_DOOR + (0,41)
const HOME_HOUSE_IN_TILE := Vector2i(13, 74)      # 실내 집 문 안쪽(진입 착지) — HOUSE_IN_TILE + (0,41)
const HOME_HOUSE_CAM_RECT := Rect2i(2, 65, 20, 13)  # 집 방 둘레 — HOUSE_CAM_RECT + (0,41)

# ── ★ C2 — 80×65 안식 농원 외부 콘텐츠 재배치(중앙 대형 밭 + 코지 여백) ────────────
# 집(NW) / 창고(NE) / 축사(동) / 중앙 대형 밭 32×26 / 스폰(남단) / 동쪽 길 워프(y중앙).
# GROUND이 열려 도달성은 자동(길은 시각 레인) — _carve_paths가 안내 동선을 깐다.
const FARM_RECT := Rect2i(24, 19, 32, 26)  # x24..55, y19..44 (중앙 대형 밭 ~832타일, 현재 154의 5.4배)
const SPAWN_TILE := Vector2i(40, 60)       # 도착 지점(남단 중앙)

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
const STOREHOUSE_EXT_RECT := Rect2i(68, 4, 6, 6)   # x68..73, y4..9 (HOME 북동, FARM x≤55과 안 겹침)
const STOREHOUSE_EXT_DOOR := Vector2i(71, 9)       # 외관 창고 문(닿으면 진입) — _carve_paths 동선 연결
const STOREHOUSE_RECT := Rect2i(23, 79, 10, 9)     # x23..32, y79..87 (HOME 밴드 — 집 방 y67..75 아래, 안 겹침)
const STOREHOUSE_DOOR := Vector2i(27, 87)          # 실내 창고 문(닿으면 퇴장) — 아래벽 중앙(end.y-1)
const STOREHOUSE_IN_TILE := Vector2i(27, 86)       # 실내 창고 문 안쪽(진입 착지)
const STOREHOUSE_CAM_RECT := Rect2i(22, 78, 14, 13)  # 창고 방 둘레(집 방 CAM y65..77과 안 겹침)
# ── ★ 안식 농원 확장 — 축사(건물 자리만, 비-enterable) ───────────────────────
# 창고 바로 아래(복도 y16 남쪽) 빈 GROUND에 통과 불가 WALL 박스 + 문 리세스(시각 일관)만 둔다.
# 창고와 같은 x열(30..35)로 동편 농장 건물 군집을 이룬다. 목축(저승 가축) 메카닉은 Phase 3
# "채집·목축"으로 명시 연기 → 지금은 *건물 자리*만. ★ _build_building_catalog에 등록하지 않아
# _maybe_toggle_building이 _buildings 조회로만 진입하므로 축사 문에 닿아도 진입 안 됨('자리만'의
# 자연 표현, 특수 분기 0). 실내·카메라·세이브 무관. 창고 동선(x32 y10..15·복도 y16) 위가 아니라
# 아래(y18..21)라 어떤 기존 동선·밭(y≤14)·스폰(x20)과도 안 겹친다(소프트락 0 — flood-fill로 게이트).
const BARN_EXT_RECT := Rect2i(60, 40, 6, 4)    # ★C2: x60..65, y40..43 (동편, 밭 x≤55·창고 스포크 x71·복도 y50 비껴)
const BARN_EXT_DOOR := Vector2i(62, 40)        # 축사 문 리세스(시각 일관용 — 진입 트리거 아님, 카탈로그 미등록)
# ── ★ M3.1 삼도천(강 낚시 무대 + 혼백관) ───────────────────────────────────────
# 셋째 실데이터 구역(ADR-0015 "빌드는 한 구역씩"). 낚시 메카닉은 만들지 않는다(Phase 3) — 강(WATER)
# 무대 + 강 낚시터(라벨만) + 혼백관(enterable 빈 방)까지 그레이박스로 깐다. 나루 마을 나룻터(22,1)에서
# 배로 건너 남단 spawn(20,22)에 도착하고, 동단 하구(38,16)가 황천해로 가는 워프(M3.2 점등).
# 강은 상단 가로 띠(y1..3)로 흘러 그 아래 land(y4..23)는 한 덩어리(다리 불필요·flood-fill 단순).
const SAMDO_RIVER_Y0 := 1                       # 강(WATER) 상단 띠 시작 y(경계벽 y0 바로 아래)
const SAMDO_RIVER_Y1 := 3                       # 강 띠 끝 y — y4 이하가 강 낚시터 둑(land)
const SAMDO_FISHING_LABEL_TILE := Vector2i(28, 5)  # 강 낚시터 라벨 자리(둑, 낚시 메카닉 Phase 3)
# 혼백관(enterable 빈 방) — 외관(land)·실내 방(아래 실내 띠). 창고·만물상 결의 데이터 주도 출입.
# kind="museum"이라 _draw 가구 분기(house/cafe)에 안 걸려 빈 방으로 그려진다(분기 추가 0). 실내 방은
# y26..34 띠에 둬 MAP_H 불변(warp_test 그리드 불변식) — 구역별 빌드라 나루 마을 방과 좌표 겹쳐도 무해.
const MUSEUM_EXT_RECT := Rect2i(6, 6, 7, 6)     # x6..12, y6..11 (강 둑 아래 land)
const MUSEUM_EXT_DOOR := Vector2i(9, 11)        # 외관 혼백관 문(닿으면 진입) — _carve_samdocheon_paths 동선 연결
const MUSEUM_RECT := Rect2i(8, 26, 12, 9)       # x8..19, y26..34 (실내 방 — HOUSE_RECT 띠, 구역별 빌드)
const MUSEUM_DOOR := Vector2i(13, 34)           # 실내 혼백관 문(닿으면 퇴장) — 아래벽 중앙
const MUSEUM_IN_TILE := Vector2i(13, 33)        # 실내 문 안쪽(진입 착지)
const MUSEUM_CAM_RECT := Rect2i(2, 24, 20, 13)  # 혼백관 방 둘레(외부·다른 방 격리)
# ── ★ M3.2 황천해(바다 낚시 무대 + 생선가게) ──────────────────────────────────
# 넷째 실데이터 구역(막다른 바다). 낚시 메카닉은 만들지 않는다(Phase 3) — 바다(WATER) 무대 + 부두(잔교)
# + 바다 낚시터(라벨만) + 생선가게(enterable 빈 방)까지. 삼도천 하구(38,16)에서 서단 spawn(2,16)에 도착.
# 바다는 하단 가로 띠(y19~23)로, 그 위 land(y1~18)가 한 덩어리(flood-fill 단순). 부두가 바다로 뻗어 그
# 끝이 바다 낚시터(Phase 3 캐스팅 자리). 강(삼도천)과 같은 WATER 타일 재사용(물 색 차별화는 후속).
const SEA_Y0 := 19                              # 바다(WATER) 상단 띠 시작 y — 그 위 land(y1~18)
const SEA_Y1 := 23                              # 바다 끝 y(외부 하단)
const PIER_X := 20                              # 부두(잔교) 세로 칸 — 바다로 뻗음(WATER 위 PATH 덮어 걸을 수 있게)
const PIER_Y0 := 17                             # 부두 시작 y(land, 복도 y16 바로 아래)
const PIER_Y1 := 22                             # 부두 끝 y(바다 한가운데 = 바다 낚시터)
const SEA_FISHING_LABEL_TILE := Vector2i(20, 21)   # 바다 낚시터 라벨 자리(부두 끝, 낚시 메카닉 Phase 3)
# 생선가게(enterable 빈 방) — 외관(land)·실내 방(아래 실내 띠). 혼백관·창고 결의 데이터 주도 출입.
# kind="fishshop"이라 _draw 가구 분기에 안 걸려 빈 방(도구·미끼·물고기 거래 서비스는 후속). 실내 방은
# y26..34 띠(구역별 빌드라 좌표 겹쳐도 무해, MAP_H 불변).
const FISHSHOP_EXT_RECT := Rect2i(5, 5, 7, 6)   # x5..11, y5..10 (land, 바다 위쪽)
const FISHSHOP_EXT_DOOR := Vector2i(8, 10)      # 외관 생선가게 문(닿으면 진입) — _carve_hwangcheonhae_paths 동선 연결
const FISHSHOP_RECT := Rect2i(8, 26, 12, 9)     # x8..19, y26..34 (실내 방)
const FISHSHOP_DOOR := Vector2i(13, 34)         # 실내 생선가게 문(닿으면 퇴장) — 아래벽 중앙
const FISHSHOP_IN_TILE := Vector2i(13, 33)      # 실내 문 안쪽(진입 착지)
const FISHSHOP_CAM_RECT := Rect2i(2, 24, 20, 13)  # 생선가게 방 둘레(외부·다른 방 격리)
# ── ★ M4.1 저승 숲(채집 무대 + 목공방) ──────────────────────────────────────────
# 다섯째 실데이터 구역(ADR-0015 "빌드는 한 구역씩"). 채집 메카닉은 만들지 않는다(Phase 3) — 나무(TREE)
# 무대 + 채집지(라벨만) + 목공방(enterable 빈 방)까지. ★ M5.1: 업화 갱도가 지어져 남단 spawn(20,22)은
# 갱도 북단 숲길에서 도착(정규 토폴로지 복원 — M4.1 산길 임시 직결 종료). 동단(38,16)이 미혹의 숲 워프(M4.2 점등).
# 동선 = 가로 복도(y16, 서 목공방 11 ~ 동 미혹 38,16) + 남단 세로(spawn 20,22·갱도 숲길 워프 20,23) + 목공방 문.
# 나무는 동선·목공방·워프 칸을 비껴간 군집으로 둬 숲 정체성을 주되 flood-fill 무 soft-lock(빈터=GROUND).
const FOREST_TREE_RECTS := [   # 나무(TREE) 군집 — 동선(y16·x20·목공방)·워프 칸을 비껴감
	Rect2i(3, 3, 5, 4),     # 북서 군집
	Rect2i(24, 3, 7, 5),    # 북동 군집
	Rect2i(3, 19, 6, 3),    # 남서 군집
	Rect2i(28, 18, 8, 4),   # 남동 군집
]
const FOREST_FORAGE_LABEL_TILE := Vector2i(28, 12)  # 채집지 라벨 자리(빈터, 채집 메카닉 Phase 3)
# 목공방(enterable 빈 방) — 외관(land)·실내 방(아래 실내 띠). 혼백관·생선가게 결의 데이터 주도 출입.
# kind="woodshop"이라 _draw 가구 분기에 안 걸려 빈 방(집·농장 업그레이드 서비스, 로빈 대응은 후속).
const WOODSHOP_EXT_RECT := Rect2i(8, 8, 7, 6)   # x8..14, y8..13 (북서 land)
const WOODSHOP_EXT_DOOR := Vector2i(11, 13)     # 외관 목공방 문(닿으면 진입) — _carve_jeoseung_forest_paths 동선 연결
const WOODSHOP_RECT := Rect2i(8, 26, 12, 9)     # x8..19, y26..34 (실내 방 — 실내 띠, 구역별 빌드라 좌표 겹쳐도 무해)
const WOODSHOP_DOOR := Vector2i(13, 34)         # 실내 목공방 문(닿으면 퇴장) — 아래벽 중앙
const WOODSHOP_IN_TILE := Vector2i(13, 33)      # 실내 문 안쪽(진입 착지)
const WOODSHOP_CAM_RECT := Rect2i(2, 24, 20, 13)  # 목공방 방 둘레(외부·다른 방 격리)
# ── ★ M4.2 미혹의 숲(특수 채집 무대 + 옥자 집) ────────────────────────────────────
# 여섯째 실데이터 구역(막다른 깊은 숲). 채집 메카닉은 만들지 않는다(Phase 3) — 더 어둡고 깊은 숲(TREE
# 밀도↑ + 연못 WATER)·특수 채집지(라벨만)까지. 저승 숲 동단(38,16)에서 서단 spawn(2,16)에 도착(M4.2 점등).
# 동선 = 가로 복도(y16, 서단 복귀 1,16 ~ 동편) + 옥자 집 문 → 복도. 막다른 구역이라 워프는 저승 숲 복귀 하나.
# ★ 옥자 집(마녀의 오두막)은 '숨겨진·게이트' — 잠긴 외관(비-enterable). _build_facade만(실내 방 없음),
#   _build_building_catalog에 미등록 → 문에 닿아도 진입 안 됨(축사 결). 실내·게이트 해제는 Phase 3 시나리오.
const MIHOK_TREE_RECTS := [   # 나무(TREE) 군집 — 저승 숲보다 빽빽(깊은 숲). 동선·옥자 집·연못·spawn 비껴감
	Rect2i(5, 3, 6, 5),     # 북서
	Rect2i(26, 3, 8, 5),    # 북동(옥자 집 동쪽)
	Rect2i(4, 19, 7, 4),    # 남서
	Rect2i(13, 19, 4, 4),   # 남중
]
const MIHOK_POND_RECT := Rect2i(28, 17, 7, 4)   # 연못(WATER, 통과 X) — 깊은 숲 분위기(world-map "연못·이끼·고목")
const MIHOK_FORAGE_LABEL_TILE := Vector2i(33, 13)  # 특수 채집지 라벨 자리(빈터, 채집 메카닉 Phase 3)
# 옥자 집(마녀의 오두막) — 잠긴 외관(비-enterable). WALL 박스 + 문 리세스(시각 일관)만, 실내·카탈로그 없음.
const OKJA_HUT_EXT_RECT := Rect2i(16, 5, 8, 7)  # x16..23, y5..11 (숲 가운데, 잠긴 외관)
const OKJA_HUT_DOOR := Vector2i(19, 11)         # 문 리세스(시각 일관 — 진입 트리거 아님, 카탈로그 미등록)

# ── 업화 갱도(M5.1 빌드 — 채광/전투 무대·대장간·길드) ────────────────────────────
# 일곱째 실데이터 구역(ADR-0015 "빌드는 한 구역씩"). 채광·전투 메카닉은 만들지 않는다(Phase 3) — 바위(ROCK)·
# 호수(WATER) 무대 + 대장간·길드(enterable 빈 방) + 갱도 끝 전투 던전 입구·나락 진입로(둘 다 잠긴 외관,
# 비-enterable, 옥자 집 결)까지. 나루 마을 산길(38,8)에서 남단 spawn(20,22)에 도착, 북단(20,1)에서 숲길로
# 저승 숲. 세로 복도(x20)가 두 워프를, 가로 복도(y16)가 대장간·길드 문을 잇는다(flood-fill 무 soft-lock).
const MINE_ROCK_RECTS := [   # 바위(ROCK) 군집 — 빈터(GROUND) 사이에 흩어 갱도 밀도를 준다(동선 x20·y16·문·게이트 비껴감)
	Rect2i(2, 2, 4, 3),     # 북서 암반
	Rect2i(36, 2, 2, 6),    # 북동 절벽
	Rect2i(2, 11, 3, 4),    # 서 중단 암반(가로 복도 y16 위)
	Rect2i(35, 11, 3, 4),   # 동 중단 암반
	Rect2i(8, 19, 4, 3),    # 남서 암반(세로 복도 x20 서편)
	Rect2i(27, 19, 5, 3),   # 남동 암반(세로 복도 x20 동편)
]
const MINE_LAKE_RECT := Rect2i(3, 18, 5, 4)     # 호수(WATER, 통과 X) — world-map "호수"(남서 구석, 동선 비껴감)
const MINE_ORE_LABEL_TILE := Vector2i(13, 19)   # 채광지 라벨 자리(빈터, 채광 메카닉 Phase 3)
# 대장간(업화로 — 도구·무기, enterable 빈 방). 외관=서편, 실내=집 방 띠(x8..19 y26..34, woodshop 결).
const SMITHY_EXT_RECT := Rect2i(4, 5, 6, 6)     # x4..9, y5..10 (서편 land)
const SMITHY_EXT_DOOR := Vector2i(6, 10)        # 외관 대장간 문(닿으면 진입) — _carve_eophwa_mine_paths 동선 연결
const SMITHY_RECT := Rect2i(8, 26, 12, 9)       # x8..19, y26..34 (실내 방 — 집 방 띠, 구역별 빌드라 좌표 겹쳐도 무해)
const SMITHY_DOOR := Vector2i(13, 34)           # 실내 대장간 문(닿으면 퇴장) — 아래벽 중앙
const SMITHY_IN_TILE := Vector2i(13, 33)        # 실내 문 안쪽(진입 착지)
const SMITHY_CAM_RECT := Rect2i(2, 24, 20, 13)  # 대장간 방 둘레(외부·다른 방 격리)
# 모험가 길드(전투 장비, enterable 빈 방). 외관=동편, 실내=만물상 방 띠 옆 칸(x23..32 y26..34, store 결 — 대장간과 cam 비겹침).
const GUILD_EXT_RECT := Rect2i(30, 5, 6, 6)     # x30..35, y5..10 (동편 land)
const GUILD_EXT_DOOR := Vector2i(33, 10)        # 외관 길드 문(닿으면 진입) — _carve_eophwa_mine_paths 동선 연결
const GUILD_RECT := Rect2i(23, 26, 10, 9)       # x23..32, y26..34 (실내 방 — 만물상 방 띠, 대장간 방 옆)
const GUILD_DOOR := Vector2i(27, 34)            # 실내 길드 문(닿으면 퇴장) — 아래벽
const GUILD_IN_TILE := Vector2i(27, 33)         # 실내 문 안쪽(진입 착지)
const GUILD_CAM_RECT := Rect2i(21, 24, 14, 13)  # 길드 방 둘레(대장간 CAM x2..21과 안 겹침)
# 갱도 끝 전투 던전 입구 — 잠긴 외관(비-enterable). 채광으로 뚫고 내려가 전투(ADR-0015)는 Phase 3라 잠김.
# WALL 박스 + 문 리세스만(실내·카탈로그 없음 — 옥자 집 결). 나락(별개 공간)과 다른 잠긴 외관.
const DUNGEON_GATE_EXT_RECT := Rect2i(12, 2, 5, 5)  # x12..16, y2..6 (북서 중앙, 잠긴 던전 입구)
const DUNGEON_GATE_DOOR := Vector2i(14, 6)          # 문 리세스(시각 일관 — 진입 트리거 아님, 카탈로그 미등록)
# 나락 진입로 — 잠긴 외관(비-enterable). 독립 전투 던전(나락)으로 가는 '서랍' 진입로라 Phase 3 전투에서 점등.
# WALL 박스 + 문 리세스만(실내·카탈로그 없음, 라이브 워프 없음 — 옥자 집 결).
const NARAK_GATE_EXT_RECT := Rect2i(23, 2, 5, 5)    # x23..27, y2..6 (북동 중앙, 잠긴 나락 진입로)
const NARAK_GATE_DOOR := Vector2i(25, 6)            # 문 리세스(시각 일관 — 진입 트리거 아님, 카탈로그 미등록)

# ── 나락(M5.2 빌드 — 독립 전투 던전 스테이지) ───────────────────────────────────
# 여덟째 실데이터 구역(독립 전투 전용). 전투 메카닉은 만들지 않는다(Phase 3) — 심연·업화·봉인 모티프의 빈
# 전투장 무대까지. 진입로는 업화 갱도의 잠긴 외관(비-enterable)이라 인게임 진입 없음 — 헤드리스 테스트가
# _region 직접 세팅해 빌드·검증한다(잠긴 진입로, world-map §5 '서랍'). spawn=(20,12) 전투장 중앙.
const NARAK_ROCK_RECTS := [   # 봉인·암반(ROCK) — 빈 전투장 둘레를 따라 흩어 '심연 갱' 분위기(spawn·중앙 비껴감)
	Rect2i(4, 4, 5, 3),
	Rect2i(31, 4, 5, 3),
	Rect2i(4, 17, 5, 3),
	Rect2i(31, 17, 5, 3),
]
# ★ M2.2 — 공유 집 실내(HOUSE_RECT)를 쓰는 나루 마을 6채(메인 집 3 + 주민 집 3). 외관 문·퇴장
# 칸만 건물마다 다르고 실내 방·문·카메라는 한 방을 공유한다(_build_building_catalog·가구 재사용).
const HOUSE_IDS := ["미호집", "멜집", "바나집", "주민집1", "주민집2", "주민집3"]
# T3.2 미호 밭 자리 — 밭 남쪽 입구(도착→복도→밭 동선의 첫 밭 칸). 길에서 위를 바라보면
# 바로 미호를 향하게 되어, 멘토가 밭 문 앞에서 맞이하는 자연스러운 첫 만남. 이 칸은 미호가
# 카페로 출근한 오후에도 농사 대상에서 제외한다(_is_farmable — 돌아올 자리는 비워 둔다).
const MIHO_FIELD_TILE := Vector2i(40, 30)   # ★C2: 중앙 대형 밭(24,19,32,26) 안 — 농사 멘토 미호 자리
# T5.6 미호 카페 출근 자리 — 카페 뒷벽 줄(y=5)에서 멜(33,5) 오른쪽. 영업 시작(15시)부터
# 미호가 여기로 출근해 직원이 오후 카페에 모이는 무대를 만든다(ADR-0007). 카페 바닥이라
# 농사 대상이 아니고(밭과 안 겹침), 좌석(y=7)·문(33,10)·멜·옥자 칸과도 갈린다.
const MIHO_CAFE_TILE := Vector2i(15, 88)   # 카페 직원 줄(y88, ★C3 +48), 멜 오른쪽
# T4.1 옥자가 오프닝 통보 때 서는 칸 — 스폰(20,21) 바로 위. 도착하자마자 옥자를 마주본다.
# 통보가 끝나면 옥자는 이 자리에서 사라지고 카페(OKJA_CAFE_TILE)로 상주를 옮긴다(T5.6).
const OKJA_INTRO_TILE := Vector2i(20, 20)
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

@onready var ground: TileMapLayer = $Ground
@onready var field_layer: TileMapLayer = $Field           # T2.1 밭 상태 오버레이
@onready var player: CharacterBody2D = $Player
@onready var readout: Label = $CanvasLayer/Readout
@onready var clock: GameClock = $Clock                     # T1.5 시계
@onready var clock_label: Label = $CanvasLayer/ClockLabel
@onready var sleep_prompt: Label = $CanvasLayer/SleepPrompt
@onready var interact_prompt: Label = $CanvasLayer/InteractPrompt  # T2.1 [E] 안내
@onready var farm: FarmField = $FarmField                  # T2.1 밭 칸 상태
@onready var crop_label: Label = $CanvasLayer/CropLabel    # T2.3 선택 작물 HUD
@onready var crop_icon: TextureRect = $CanvasLayer/CropIcon  # P2.5④ 선택 작물 아이콘(작물 스프라이트 재사용)
@onready var shop_crop_icon: TextureRect = $CanvasLayer/ShopPanel/CropIcon  # P2.5④ 출하대 작물 아이콘
@onready var energy: SoulEnergy = $SoulEnergy              # T2.4 혼력
@onready var energy_label: Label = $CanvasLayer/EnergyLabel  # T2.4 혼력 HUD
@onready var saver: SaveManager = $SaveManager            # T2.5 세이브/로드
@onready var save_label: Label = $CanvasLayer/SaveLabel   # T2.5 저장 안내·확인 HUD
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
@onready var affinity_label: HeartBar = $CanvasLayer/AffinityLabel  # T3.3 하트 HUD(P2.5② 스프라이트)
@onready var foxfire_label: Label = $CanvasLayer/FoxfireLabel  # T3.4 여우불 도움 HUD
@onready var okja: Okja = $Okja                               # T4.1 옥자 NPC(오프닝 통보)
@onready var mel: Mel = $Mel                                 # T5.1 멜 NPC(카페 운영·그레이박스)
@onready var bana: Bana = $Bana                             # T6.1 바나 NPC(밤 무대·그레이박스)
@onready var mel_affinity: Affinity = $MelAffinity           # T5.2 멜 호감도(하트, affinity.gd 재사용)
@onready var mel_affinity_label: HeartBar = $CanvasLayer/MelAffinityLabel  # T5.2 멜 하트 HUD(P2.5② 스프라이트)
@onready var bana_affinity: Affinity = $BanaAffinity         # T6.2 바나 호감도(하트, affinity.gd 재사용)
@onready var bana_affinity_label: HeartBar = $CanvasLayer/BanaAffinityLabel  # T6.2 바나 하트 HUD(P2.5② 스프라이트)
@onready var neo: Neo = $Neo                                 # M2.3 네오 NPC(만물상 점주·그레이박스)
@onready var neo_affinity: Affinity = $NeoAffinity           # M2.3 네오 호감도(하트, affinity.gd 재사용 — 단골 할인 파생원)
@onready var neo_affinity_label: HeartBar = $CanvasLayer/NeoAffinityLabel  # M2.3 네오 하트 HUD(P2.5② 스프라이트)
@onready var cafe: Cafe = $Cafe                               # T5.4 카페 운영(손님 서빙·일일 정산)
@onready var night_bar: NightBar = $NightBar                 # T6.3 나라카 바(밤 옵트인·잡귀 등장 게이팅)
@onready var night_label: Label = $CanvasLayer/NightLabel    # T6.3 밤 바 상태·옵트인 HUD
@onready var bana_guard_label: Label = $CanvasLayer/BanaGuardLabel  # T6.5 바나 이중 보호 상태 HUD
@onready var cafe_label: Label = $CanvasLayer/CafeLabel       # T5.4 카페 영업 상태·매출 HUD
@onready var cafe_summary_panel: Panel = $CanvasLayer/CafeSummaryPanel  # T5.4 마감 정산 팝업 배경
@onready var cafe_summary_text: Label = $CanvasLayer/CafeSummaryPanel/Text  # T5.4 정산 본문
@onready var milestone_label: Label = $CanvasLayer/MilestoneLabel             # T7.2 카페 마일스톤 진행 바 HUD
@onready var milestone_panel: Panel = $CanvasLayer/MilestonePanel         # T7.2 "카페 2단계!" 달성 팝업 배경
@onready var milestone_text: Label = $CanvasLayer/MilestonePanel/Text         # T7.2 달성 팝업 본문
@onready var onboarding: Onboarding = $Onboarding             # T4.1 온보딩 단계 머신
@onready var onboarding_label: Label = $CanvasLayer/OnboardingLabel  # T4.1 안내 배너
@onready var ending_panel: ColorRect = $CanvasLayer/EndingPanel        # T4.2/T7.3 슬라이스 마무리 화면 배경
@onready var ending_text: Label = $CanvasLayer/EndingPanel/Text        # T4.2 점수판 본문
@onready var fade: ColorRect = $CanvasLayer/Fade

# P2.3③ 밤 라이팅(CanvasModulate + 등불). 월드 캔버스에 코드로 붙인다(타일셋·입력처럼
# 런타임 조립). 무상태(시각 파생)라 세이브 대상이 아니다 — _setup_lighting에서 생성.
var lighting: DayNightLighting

# P2.6 사운드(BGM 시간대 라우팅 + 이벤트 SFX + 음소거). lighting과 같은 결 — 코드 생성
# 자식 노드, 무상태(세이브 대상 아님). _setup_audio에서 생성, _process가 매 프레임 시각으로
# BGM을 잇고, 각 이벤트 자리에서 audio.sfx(...) 한 줄로 효과음을 쏜다.
var audio: GameAudio

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

# T2.5 저장/불러오기 확인 문구를 잠깐 띄우는 잔여 시간(초). 0이면 기본 안내로 복귀.
var _notice_secs := 0.0
const NOTICE_DEFAULT := "[F5] 저장 · [F9] 불러오기 · [F8] 새로 시작"
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

# T3.1/T5.3 카페 출하대 패널이 열려 있는가. 멜을 바라볼 때 F로 토글하고, 멜 앞을
# 벗어나면 자동으로 닫힌다(멜이 카운터 얼굴 — '멜 앞에서만' 패턴, 무인 카운터 제거).
var _shop_open := false

# M2.3 만물상 매대 패널이 열려 있는가. 네오를 바라볼 때 F로 토글하고, 네오 앞을 벗어나면
# 자동으로 닫힌다(멜 출하대와 같은 '점주 앞에서만' 패턴). 출하대(_shop_open)와 같은 ShopPanel
# 노드를 재사용하되, 둘은 서로 다른 건물(카페 vs 만물상)이라 동시에 열릴 수 없다 — 한 패널이
# 둘을 모두 띄운다(어느 쪽이 열렸는지로 본문 텍스트만 가른다).
var _store_open := false

# T4.2 슬라이스(RunSummary.RUN_DAYS일)가 끝났는가(마무리 화면 표시 중). true면 _process가 모든
# 게임 입력을 막고 마무리 화면만 유지한다. 끝남 자체는 GameClock.day에서 파생되므로
# (RunSummary.is_over) 세이브할 상태가 아니고, 이 플래그는 한 프레임 표시 래치일 뿐이다.
var _run_over := false
# T4.2 이번 슬라이스에서 거둔 영혼(수확) 총수 — 마무리 점수판용. 일시 표시용인
# _harvest_seen(사연 순환 index)과 달리 점수판이 재개에도 맞아야 하므로 저장한다.
var _run_harvested := 0

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
	_build_grid()
	_paint_grid()
	_place_labels()
	_setup_player_and_camera()
	_setup_lighting()
	_setup_audio()
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
	# T2.5 세이브가 있으면 시작 시 자동 복원 → "껐다 켜도 그대로"가 성립한다.
	if saver.has_save():
		_load_game()
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

# 'interact' 액션을 코드로 등록한다(키 E). project.godot 수동 편집 대신 런타임
# 조립 — 이 프로젝트의 TileSet·벽 생성과 같은 결이고, 직렬화 포맷 깨질 위험이 없다.
func _ensure_input_actions() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	InputMap.action_add_event("interact", ev)
	# T2.3 작물 선택 순환(키 Q). 같은 결로 런타임 등록한다.
	InputMap.add_action("cycle_crop")
	var ev_q := InputEventKey.new()
	ev_q.physical_keycode = KEY_Q
	InputMap.action_add_event("cycle_crop", ev_q)
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
	# T3.1 카페 출하대: 수확물 전량 판매(S)·선택 작물 씨앗 구매(B). 패널이 열렸을
	# 때만 처리하므로(_shop_open 가드), 밭 작업 키(E·Q)와 충돌하지 않는다.
	InputMap.add_action("shop_sell")
	var ev_s := InputEventKey.new()
	ev_s.physical_keycode = KEY_S
	InputMap.action_add_event("shop_sell", ev_s)
	InputMap.add_action("shop_buy")
	var ev_b := InputEventKey.new()
	ev_b.physical_keycode = KEY_B
	InputMap.action_add_event("shop_buy", ev_b)
	# T5.3 멜 카페 출하대 열기/닫기(F). 멜을 바라볼 때만 처리하므로(facing_mel 가드),
	# 멜 앞 대화(E)·선물(G) 및 밭 작업과 키가 갈려 충돌하지 않는다(무인 카운터 → 멜 카운터).
	InputMap.add_action("shop_toggle")
	var ev_f := InputEventKey.new()
	ev_f.physical_keycode = KEY_F
	InputMap.action_add_event("shop_toggle", ev_f)
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

	# 3) 물리 레이어 추가 + 벽 타일(외벽 WALL·실내 벽 HOUSE_WALL·CAFE_WALL)에 꽉 찬 사각
	#    충돌 폴리곤(타일 중심 −8..8) → 통과 불가. 바닥(HOUSE/CAFE)은 충돌 없이 걷는다.
	ts.add_physics_layer()
	for solid in [WALL, HOUSE_WALL, CAFE_WALL, WATER, TREE, ROCK]:
		var sx := SOLID_TILES.find(solid)
		var td := src.get_tile_data(Vector2i(sx, 0), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
		]))
	return ts

# 타일 종류 → 단색 source의 아틀라스 좌표(HOUSE/CAFE/WALL만)
func _solid_atlas(tile: int) -> Vector2i:
	return Vector2i(SOLID_TILES.find(tile), 0)

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

	_fill_rect(FARM_RECT, SOIL)                     # 밭(열린 흙 구역, 외부)
	_build_facade(HOUSE_EXT_RECT, HOUSE_EXT_DOOR)   # 외부 집 외관(통과 불가 박스 + 문 트리거)
	_build_facade(STOREHOUSE_EXT_RECT, STOREHOUSE_EXT_DOOR)  # ★ 창고 외관(동편, 카페 이주로 비워진 자리)
	_build_facade(BARN_EXT_RECT, BARN_EXT_DOOR)             # ★ 축사 건물 자리(비-enterable — 카탈로그 미등록)
	_build_room(HOME_HOUSE_RECT, HOUSE, HOUSE_WALL, HOME_HOUSE_DOOR)   # ★C2 실내 집 방(HOME 밴드 y67+, 마을 공유 방과 분리)
	_build_room(STOREHOUSE_RECT, HOUSE, HOUSE_WALL, STOREHOUSE_DOOR)  # ★ 실내 창고 방(빈 방 — kind=storehouse)
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

# ★ M3.1 — 삼도천 동선. 가로 복도(y16)가 혼백관 쪽과 동단 하구 워프(38,16)를 잇고, 남단 나룻터
# (spawn 20,22·복귀 워프 20,23)에서 복도로 올라온다. 혼백관 문(9,11)은 세로로 복도까지 잇는다.
# land가 한 덩어리라 길은 동선 안내용이고, 워프 발동 칸까지 닿아 무 soft-lock.
func _carve_samdocheon_paths() -> void:
	_carve_h(16, 1, 38)                    # 가로 복도(동단 하구 워프 38,16까지)
	_carve_v(20, 16, 23)                   # 나룻터 도착(20,22)·복귀 워프(20,23) → 복도
	_carve_v(MUSEUM_EXT_DOOR.x, MUSEUM_EXT_DOOR.y, 16)  # 혼백관 문(9,11) → 복도(y16)

# ★ M3.2 — 황천해(바다 낚시 무대 + 생선가게). 삼도천과 같은 패턴(외부 land + 아래 실내 생선가게 방,
# VOID 격리). 낚시 메카닉은 만들지 않는다(Phase 3) — 바다(WATER) 무대·부두·바다 낚시터(라벨만)·생선가게
# (enterable 빈 방)까지. 바다는 하단 가로 띠(y19~23)로 흘러 그 위 land(y1~18)가 한 덩어리(flood-fill
# 단순). 부두(PATH)가 바다로 뻗어 그 끝(PIER_Y1)이 바다 낚시터. 막다른 구역이라 워프는 삼도천 복귀 하나.
func _build_hwangcheonhae() -> void:
	_grid = []
	for y in _grid_h:
		var row: Array = []
		for x in _grid_w:
			row.append(GROUND if y < _outdoor_h else VOID)
		_grid.append(row)

	# 바다(WATER, 통과 X) — 하단 가로 띠. 부두 끝(바다 한가운데)이 바다 낚시터(Phase 3 캐스팅 자리).
	for y in range(SEA_Y0, SEA_Y1 + 1):
		for x in range(1, _grid_w - 1):
			_set_tile(x, y, WATER)

	_build_facade(FISHSHOP_EXT_RECT, FISHSHOP_EXT_DOOR)            # 생선가게 외관(통과 불가 박스 + 문)
	_build_room(FISHSHOP_RECT, HOUSE, HOUSE_WALL, FISHSHOP_DOOR)   # 실내 생선가게 빈 방(kind=fishshop)
	_carve_hwangcheonhae_paths()           # 동선(서단 도착 → 생선가게 문·부두)
	_build_border()                        # 맵 4변 경계벽(마지막에 보장)

# ★ M3.2 — 황천해 동선. 가로 복도(y16)가 서단 도착·복귀 워프(spawn 2,16·at 1,16)와 생선가게·부두를
# 잇고, 부두(PIER_X)가 복도에서 바다로 세로로 뻗는다(WATER 위에 PATH를 덮어 걸을 수 있는 잔교 — _build
# 순서상 바다 fill 뒤에 carve라 PATH가 이긴다). 부두 끝(바다 낚시터)까지 닿아 무 soft-lock.
func _carve_hwangcheonhae_paths() -> void:
	_carve_h(16, 1, PIER_X)                # 가로 복도(서워프 1,16 ~ 부두 x20)
	_carve_v(FISHSHOP_EXT_DOOR.x, FISHSHOP_EXT_DOOR.y, 16)  # 생선가게 문(8,10) → 복도(y16)
	_carve_v(PIER_X, PIER_Y0, PIER_Y1)     # 부두(잔교) — 복도(y16 아래)에서 바다로 뻗음(WATER 위 PATH)

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

# ★ M4.1 — 저승 숲 동선. 가로 복도(y16)가 서단 우회 워프(1,16)·동단 미혹 워프(38,16)를 잇고, 남단
# 세로(x20, spawn 20,22·갱도 워프 20,23)에서 복도로 올라온다. 목공방 문(11,13)은 세로로 복도까지 잇는다.
# carve는 나무 fill *뒤*라 PATH가 이겨 동선 칸엔 나무가 없다(무 soft-lock).
func _carve_jeoseung_forest_paths() -> void:
	# ★ M5.1 — 서단 임시 우회 워프(1,16) 제거에 맞춰 가로 복도 서단을 목공방 열(x11)까지 트림(서쪽 데드엔드 방지).
	_carve_h(16, 11, 38)                   # 가로 복도(서 목공방 11 ~ 동 미혹 워프 38,16)
	_carve_v(20, 16, 23)                   # 남단 spawn(20,22)·갱도 숲길 워프(20,23) → 복도
	_carve_v(WOODSHOP_EXT_DOOR.x, WOODSHOP_EXT_DOOR.y, 16)  # 목공방 문(11,13) → 복도(y16)

# ★ M4.2 — 미혹의 숲(특수 채집 무대 + 옥자 집). 저승 숲과 같은 스택이되 실내 방이 없다(옥자 집은 잠긴
# 외관 = 비-enterable). 더 깊은 숲: 나무(TREE) 밀도↑ + 연못(WATER). 채집 메카닉은 만들지 않는다(Phase 3).
# 옥자 집은 _build_facade만(WALL 박스 + 문 리세스) — 실내·카탈로그 없어 진입 불가(축사 결, '숨겨진·게이트').
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

# ★ M4.2 — 미혹의 숲 동선. 가로 복도(y16)가 서단 도착·복귀 워프(spawn 2,16·at 1,16)와 동편을 잇고,
# 옥자 집 문(19,11)은 세로로 복도까지 잇는다(잠긴 외관이라 닿아도 진입 안 됨 — 시각·동선 일관만). 막다른
# 구역이라 워프는 서단 하나. carve는 나무·연못 fill 뒤라 PATH가 이겨 동선 칸엔 나무·물이 없다(무 soft-lock).
func _carve_mihok_forest_paths() -> void:
	_carve_h(16, 1, 35)                    # 가로 복도(서단 복귀 1,16 ~ 동편)
	_carve_v(OKJA_HUT_DOOR.x, OKJA_HUT_DOOR.y, 16)  # 옥자 집 문(19,11) → 복도(y16)

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

# ★ M5.1 — 업화 갱도 동선. 세로 복도(x20)가 남단 spawn(20,22)·나루 마을 워프(20,23)와 북단 저승 숲
# 워프(20,1)를 잇고, 가로 복도(y16)가 대장간(서)·길드(동)를 잇는다. 각 건물·게이트 문은 세로로 복도까지
# 잇는다(게이트는 잠긴 외관이라 닿아도 진입 안 됨 — 시각·동선 일관만). carve는 바위·호수 fill *뒤*라 PATH가
# 이겨 동선 칸엔 바위·물이 없다(무 soft-lock).
func _carve_eophwa_mine_paths() -> void:
	_carve_v(20, 1, 23)                    # 세로 복도(북단 숲길 20,1 ~ 남단 산길 20,23·spawn 20,22)
	_carve_h(16, 4, 36)                    # 가로 복도(서 대장간 ~ 동 길드)
	_carve_v(SMITHY_EXT_DOOR.x, SMITHY_EXT_DOOR.y, 16)   # 대장간 문(6,10) → 복도(y16)
	_carve_v(GUILD_EXT_DOOR.x, GUILD_EXT_DOOR.y, 16)     # 길드 문(33,10) → 복도(y16)
	_carve_v(DUNGEON_GATE_DOOR.x, DUNGEON_GATE_DOOR.y, 16)  # 던전 입구(14,6) → 복도(잠김 — 시각·동선 일관)
	_carve_v(NARAK_GATE_DOOR.x, NARAK_GATE_DOOR.y, 16)      # 나락 진입로(25,6) → 복도(잠김 — 시각·동선 일관)

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

func _build_border() -> void:
	for x in _grid_w:
		_set_tile(x, 0, WALL)
		_set_tile(x, _grid_h - 1, WALL)
	for y in _grid_h:
		_set_tile(0, y, WALL)
		_set_tile(_grid_w - 1, y, WALL)

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
	# ★ C2 — 80×65 안식 농원 동선(시각 레인). GROUND/SOIL이 열려 도달성은 자동이라 길은 *안내*다.
	#   메인 가로 복도(y50, 밭 남단 y44 아래)가 좌우 가장자리를 잇고, 거기서 스폰·집·창고·동워프로
	#   스포크가 뻗는다. 동쪽 길 워프(78,32)는 창고 레인에서 y32로 갈라져 닿는다(스타듀식 가장자리 워프).
	_carve_h(50, 4, 78)                         # 가로 메인 복도(좌우 가장자리까지)
	_carve_v(40, 44, 60)                        # 스폰(40,60) → 복도(y50) → 중앙 밭 남단(y44)
	_carve_v(6, 10, 50)                         # 집 문(6,9) → 복도 — NW
	_carve_v(71, 10, 50)                        # 창고 문(71,9) → 복도 — NE
	_carve_h(32, 71, 78)                        # 창고 레인(x71) → 동쪽 길 워프(78,32)
	_carve_v(62, 44, 50)                        # 축사 앞(62,44) → 복도 — 동편 군집 안내(시각)

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
	# GROUND/PATH/SOIL은 terrain별 칸을 모아 corner 오토타일로 칠하고(경계·모서리
	# 자동 전환), HOUSE/CAFE/WALL은 단색 source로 직접 깐다.
	var all_terrain: Array[Vector2i] = []   # GROUND/PATH/SOIL 전부 — 풀 베이스로 단일 칠
	var path_cells: Array[Vector2i] = []
	var soil_cells: Array[Vector2i] = []
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
				all_terrain.append(cell)
				if t == PATH:
					path_cells.append(cell)
				elif t == SOIL:
					soil_cells.append(cell)
			else:
				solids.append([cell, t])
	# ★ 모든 지형 칸을 *풀 하나로* 먼저 칠한다. 단일 연속 영역이라 base가 빈틈없이
	#   매칭돼 검은 구멍이 안 생긴다. 그 위에 길·밭을 얹으면 경계가 grass↔path·grass↔soil
	#   전환 타일로 자동 교체된다. ignore_empty_terrains=false: 빈 캔버스 첫 칠은 모든 이웃이
	#   empty라 기본 true면 제약이 사라져 한 칸도 못 칠한다(Godot 4 동작).
	ground.set_cells_terrain_connect(all_terrain, TERRAIN_SET, TR_GRASS, false)
	# 밭은 넓어 corner 전환이 자연스럽다 → terrain으로 칠해 풀↔밭 경계를 부드럽게.
	ground.set_cells_terrain_connect(soil_cells, TERRAIN_SET, TR_SOIL, false)
	# 길은 1칸 폭 동선이라 전환에 묻힌다 → base 흙길 타일을 직접 깔아 또렷하게(동선 안내).
	var path_base := _terrain_base_atlas(TR_PATH)
	for c in path_cells:
		ground.set_cell(c, 0, path_base)
	# 단색(HOUSE/CAFE/WALL)은 terrain 위에 덮어 깐다(아직 도트 전, 단계 ②에서 교체).
	for s in solids:
		ground.set_cell(s[0], SOLID_SRC_ID, _solid_atlas(s[1]))

# ── 구역 라벨(월드 좌표, 카메라 따라 스크롤) ──────────────────────────────
func _place_labels() -> void:
	# 집·카페는 도트 외관(간판·건물 형태)으로 식별되므로 라벨을 빼고, 아직 그레이박스인
	# 밭·도착·구역 동선 안내만 라벨로 남긴다(외관 위 텍스트 중복 제거).
	# ★ M1.4 — 구역마다 자기 라벨만 깐다(_rebuild_region이 전환 시 _clear_labels로 걷어낸다).
	match _region:
		RegionCatalog.HOME:
			_add_label("밭", _rect_center_px(FARM_RECT))
			_add_label("도착", Vector2(SPAWN_TILE.x * TILE + TILE * 0.5, (SPAWN_TILE.y - 1) * TILE))
			# ★C2 — 동쪽 길 워프(78,32) 안내 — 마을로 가는 길임을 그레이박스로 일러둔다.
			_add_label("나루 마을 →", _tile_center_px(Vector2i(74, 31)))
			_add_label("창고", _tile_center_px(Vector2i(71, 3)))  # ★ 북동 창고 외관(그레이박스 — 도색 전)
			_add_label("축사(목축 예정)", _tile_center_px(Vector2i(62, 38)))  # ★ 건물 자리만(Phase 3 목축)
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
			# ★ M3.1 — 혼백관은 그레이박스 WALL 박스라 라벨로 식별(만물상·창고 컨벤션). 강 낚시터·워프 안내.
			_add_label("혼백관", _tile_center_px(Vector2i(9, 8)))
			_add_label("강 낚시터(Phase 3)", _tile_center_px(SAMDO_FISHING_LABEL_TILE))
			_add_label("나룻터 → 나루 마을", _tile_center_px(Vector2i(20, 21)))  # 남단 복귀 워프(20,23) 안내
			_add_label("하구 → 황천해", _tile_center_px(Vector2i(36, 15)))      # ★ M3.2 동단 하구 워프(38,16, 점등)
		RegionCatalog.HWANGCHEONHAE:
			# ★ M3.2 — 생선가게는 그레이박스 WALL 박스라 라벨로 식별. 부두·바다 낚시터·복귀 워프 안내.
			_add_label("생선가게", _tile_center_px(Vector2i(8, 7)))
			_add_label("부두", _tile_center_px(Vector2i(PIER_X, 18)))
			_add_label("바다 낚시터(Phase 3)", _tile_center_px(SEA_FISHING_LABEL_TILE))
			_add_label("하구 → 삼도천", _tile_center_px(Vector2i(4, 15)))       # 서단 복귀 워프(1,16) 안내
		RegionCatalog.JEOSEUNG_FOREST:
			# ★ M4.1 — 목공방은 그레이박스 WALL 박스라 라벨로 식별. 채집지·워프 안내.
			_add_label("목공방", _tile_center_px(Vector2i(11, 10)))
			_add_label("채집지(Phase 3)", _tile_center_px(FOREST_FORAGE_LABEL_TILE))
			_add_label("숲 안쪽 → 미혹의 숲", _tile_center_px(Vector2i(36, 15)))  # ★ M4.2 동단 워프(38,16, 점등)
			_add_label("숲길 → 업화 갱도", _tile_center_px(Vector2i(20, 21)))   # ★ M5.1 남단 숲길 워프(20,23, 점등 — 임시 우회 종료)
		RegionCatalog.EOPHWA_MINE:
			# ★ M5.1 — 대장간·길드는 그레이박스 WALL 박스라 라벨로 식별(목공방 컨벤션). 던전 입구·나락 진입로는
			# 잠긴 외관(비-enterable)이라 라벨로 위상 명시(옥자 집 컨벤션). 채광지·두 워프 안내.
			_add_label("대장간", _tile_center_px(Vector2i(6, 7)))
			_add_label("모험가 길드", _tile_center_px(Vector2i(33, 7)))
			_add_label("채광지(Phase 3)", _tile_center_px(MINE_ORE_LABEL_TILE))
			_add_label("호수", _tile_center_px(Vector2i(5, 22)))
			_add_label("던전 입구 (잠김 — 전투 Phase 3)", _tile_center_px(Vector2i(14, 8)))
			_add_label("나락 진입로 (잠김 — 전투 Phase 3)", _tile_center_px(Vector2i(25, 8)))
			_add_label("산길 → 나루 마을", _tile_center_px(Vector2i(20, 21)))   # 남단 산길 워프(20,23) 안내
			_add_label("숲길 → 저승 숲", _tile_center_px(Vector2i(20, 3)))       # 북단 숲길 워프(20,1) 안내
		RegionCatalog.NARAK:
			# ★ M5.2 — 독립 전투 던전 스테이지(헤드리스 빌드·검증). 인게임 진입은 잠긴 외관(업화 갱도)이라 없음.
			_add_label("나락 (전투 — Phase 3)", _tile_center_px(Vector2i(20, 10)))
		RegionCatalog.MIHOK_FOREST:
			# ★ M4.2 — 옥자 집은 잠긴 외관(비-enterable)이라 라벨로 위상 명시(축사 컨벤션). 특수 채집지·복귀 워프 안내.
			_add_label("옥자 집 (잠김 — 미결의 죄 해결 후)", _tile_center_px(Vector2i(19, 4)))
			_add_label("특수 채집지(Phase 3)", _tile_center_px(MIHOK_FORAGE_LABEL_TILE))
			_add_label("연못", _tile_center_px(Vector2i(31, 18)))
			_add_label("숲 안쪽 → 저승 숲", _tile_center_px(Vector2i(4, 15)))   # 서단 복귀 워프(1,16) 안내

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
	# T4.2 슬라이스의 끝. 취침으로 RUN_DAYS+1일째 아침이 오면 더 진행하지 않고(작물 성장·
	# 혼력 회복도 생략) 마무리 화면을 띄운다. 끝 판정은 RunSummary가 day로 내린다.
	if RunSummary.is_over(day):
		_end_run()
		return
	var h := affinity.hearts()
	farm.advance_day(Foxfire.accel(h), Foxfire.reach(h))
	energy.refill()
	# T4.1 물 준 작물이 다 자라면 온보딩을 '수확하라' 단계로 넘긴다(그 단계일 때만).
	if farm.any_mature():
		onboarding.crop_ready()
	# M2.4 새 날이 이벤트 데이(2주마다)면 메인 4인 의상·카페 보너스를 켠다(아니면 끈다).
	_refresh_festival()

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

# T2.3 선택 작물을 카탈로그 순서(빠른 성장 순)대로 다음 것으로 순환.
func _cycle_crop() -> void:
	var ids := CropCatalog.ids()
	var i := ids.find(_selected_crop)
	_selected_crop = ids[(i + 1) % ids.size()]
	audio.sfx("ui")                           # P2.6 작물 선택 순환 블립

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
		"ext_door": HOUSE_EXT_DOOR, "out_tile": HOUSE_OUT_TILE,
		# ★C2 — HOME 집 실내는 HOME 밴드 전용 좌표(마을 6채는 HOUSE_* 공유, 아래 루프).
		"in_tile": HOME_HOUSE_IN_TILE, "door": HOME_HOUSE_DOOR, "cam": HOME_HOUSE_CAM_RECT,
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
		"ext_door": STOREHOUSE_EXT_DOOR, "out_tile": STOREHOUSE_EXT_DOOR + Vector2i(0, 1),
		"in_tile": STOREHOUSE_IN_TILE, "door": STOREHOUSE_DOOR, "cam": STOREHOUSE_CAM_RECT,
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
			if b["region"] == _region and t == b["ext_door"]:
				_transition_to(id, b["in_tile"])
				return
	elif _buildings.has(_indoor) and t == _buildings[_indoor]["door"]:
		_transition_to("", _buildings[_indoor]["out_tile"])

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
		"wallet": wallet.to_save(),
		"inventory": inventory.to_save(),
		"affinity": affinity.to_save(),
		"mel_affinity": mel_affinity.to_save(),
		"bana_affinity": bana_affinity.to_save(),
		"neo_affinity": neo_affinity.to_save(),   # M2.3 네오(만물상 점주) 호감도 — 매대 할인 파생원
		"onboarding": onboarding.to_save(),
		"run_harvested": _run_harvested,
		"cafe_revenue_total": _cafe_revenue_total,
		"selected_crop": _selected_crop,
		# M1.5 — 현재 구역·실내 모드·플레이어 위치(껐다 켜도 '있던 자리'에서 재개). region은
		# 영문 id(RegionCatalog 키, 가볍고 안정적), indoor는 ""/건물 id(_buildings 키), 위치는 타일 좌표.
		# SaveManager는 IO만 책임지므로(불변) 세 키가 늘어도 손대지 않는다 — main이 조율한다.
		"region": _region,
		"indoor": _indoor,
		"player_tile": _player_tile(),
	}
	if saver.save_game(data):
		_notice("저장됨")

func _load_game() -> void:
	var data := saver.load_game()
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
	if data.has("wallet"):
		wallet.load_save(data["wallet"])
	if data.has("inventory"):
		inventory.load_save(data["inventory"])
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

# 확인·알림 문구를 잠깐 띄운다(지속시간 경과 후 기본 안내로 복귀). 저장됨 등은
# 짧게(NOTICE_SECS), T3.5 사연 한 줄은 읽을 수 있게 길게(FLAVOR_SECS) 띄운다.
func _notice(msg: String, secs: float = NOTICE_SECS) -> void:
	save_label.text = msg
	_notice_secs = secs

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
	saver.delete_save()
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
	# 음소거 토글(M) — 연출·대화·마무리 화면 어디서든 받는다(입력 가드보다 위, UX 토글이라
	# 게임 상태와 무관). audio가 Music·SFX 버스를 함께 음소거한다.
	if Input.is_action_just_pressed("mute_audio"):
		audio.toggle_mute()
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
	# T3.2 대화 중엔 다른 모든 입력을 막고 대사 넘기기(E)만 처리한다. 이동은 대화
	# 시작 시 player 물리를 꺼 잠가 두었고(_start_dialogue), 끝나면 다시 켠다.
	# 패널 본문은 dialogue.changed 시그널로 갱신되므로 여기선 입력만 본다.
	if dialogue.is_open():
		onboarding_label.visible = false  # T4.1 대화가 화면을 채우는 동안 배너 숨김
		if Input.is_action_just_pressed("interact"):
			dialogue.advance()
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

	# 저장/불러오기 확인 문구 표시 시간이 지나면 기본 안내로 되돌린다.
	if _notice_secs > 0.0:
		_notice_secs -= delta
		if _notice_secs <= 0.0:
			save_label.text = NOTICE_DEFAULT

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

	# T2.3 작물 선택 순환(Q). 심을 작물을 바꾼다(성장일수가 다른 3종).
	if not _sleeping and Input.is_action_just_pressed("cycle_crop"):
		_cycle_crop()

	# T2.1/T2.3 밭 상호작용: 바라보는 앞 칸을 대상으로, E 한 키가 다음 단계를
	# 수행한다(괭이질→심기→물주기→…자람…→수확). 심기엔 현재 선택 작물을 넘긴다.
	# T2.4 행동 한 번마다 혼력을 쓴다. 혼력이 바닥나면(can_act false) 행동이 막힌다.
	# T3.1 심기엔 씨앗이 필요하고, 수확물은 인벤토리에 쌓인다(경제 순환의 양끝).
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
	# T5.1 멜에게 말 걸기: 바라보는 칸이 멜 칸이면 E로 대화를 연다. 멜은 카페 안에 서
	# 있어, 카페 출하대(_process_shop)보다 먼저 처리하고 return해 대화가 우선한다
	# (멜을 바라보면 대화, 안 바라보고 카페 안이면 출하대 — T5.3에서 멜 운영으로 통합).
	var facing_mel := not _sleeping and _target == MEL_TILE
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
	if facing_miho and Input.is_action_just_pressed("interact"):
		_start_dialogue()
		return
	# T3.3 미호 선물: 바라볼 때 G로 선택 작물 수확물 1개를 건넨다(호감도↑, 하루 1회).
	if facing_miho and Input.is_action_just_pressed("gift_item"):
		_try_gift()
		return
	# T5.6 옥자 일상 대화: 카페 상주 옥자를 바라보며 E. 호감도·선물 없는 일상이라 G는 없다.
	if facing_okja and Input.is_action_just_pressed("interact"):
		_start_okja_dialogue()
		return
	# T6.1 바나 대화: 밤 무대의 바나를 바라보며 E면 대사를 연다. 좌석·밭 동작보다 먼저
	# 처리하고 return해 대화가 우선한다. T6.2 선물: 바라볼 때 G로 선택 작물 수확물 1개를
	# 건넨다(호감도↑, 하루 1회 — 미호·멜 선물과 같은 결).
	if facing_bana and Input.is_action_just_pressed("interact"):
		_start_bana_dialogue()
		return
	if facing_bana and Input.is_action_just_pressed("gift_item"):
		_try_bana_gift()
		return
	# T6.3 나라카 바 옵트인: 밤에 바나를 바라보며 F면 바를 연다(잡귀가 깃들기 시작). 멜
	# 출하대(F)와 키는 같지만 facing_bana/facing_mel은 칸이 갈려 동시에 참이 아니고(바나=밤
	# 무대 36,5 / 멜=카운터 33,5), 바나는 출하대가 없어 충돌하지 않는다. 안 열면 빈 밤 —
	# 옵트인은 그 밤의 선택이지 매일 세금이 아니다(ADR-0010 #6, ADR-0008 평평≠막힘).
	if facing_bana and not night_bar.is_opened() and Input.is_action_just_pressed("shop_toggle"):
		_open_night_bar()
		return
	if not _sleeping and _target_valid and Input.is_action_just_pressed("interact"):
		_try_farm_action()

	# T5.1 멜 대화: 멜을 바라보며 E면 대화를 연다. 출하대 패널이 열려 있을 땐 막아
	# (not _shop_open) 패널 조작(F·S·B)과 섞이지 않게 한다.
	if facing_mel and not _shop_open and Input.is_action_just_pressed("interact"):
		_start_mel_dialogue()
		return
	# T5.2 멜 선물: 바라볼 때 G로 선택 작물 수확물 1개를 건넨다(호감도↑, 하루 1회).
	if facing_mel and not _shop_open and Input.is_action_just_pressed("gift_item"):
		_try_mel_gift()
		return

	# M2.3 네오 대화: 만물상에서 네오를 바라보며 E면 대화를 연다(일일 대화로 호감도↑). 매대 패널이
	# 열려 있을 땐 막아(not _store_open) 패널 조작(F·B)과 섞이지 않게 한다(멜 대화와 같은 결).
	# ★ 이 슬라이스는 선물(G) 없이 *일일 대화 한 채널*로만 친해진다 — 네오는 T1 비인간이지만 풀 T1
	#   트랙(선물·하트 이벤트·결혼)은 후속이고(ADR-0014 한 명씩), 지금은 매대 단골 할인까지만.
	if facing_neo and not _store_open and Input.is_action_just_pressed("interact"):
		_start_neo_dialogue()
		return

	# T5.4 손님 서빙: 기다리는 손님이 앉은 좌석을 바라보며 E. 보유 재료 1개를 자동
	# 소모하고 정액 P 골드를 즉시 번다(서사·호감도 없는 가벼운 단골 — ADR-0005). 좌석은
	# 농사 대상이 아니라(_target_valid false) 밭 동작과 충돌하지 않는다.
	if facing_seat >= 0 and cafe.is_waiting(facing_seat) and Input.is_action_just_pressed("interact"):
		_try_serve(facing_seat)
		return

	# T6.4 막기: 밤에 잡귀가 깃든 스폿을 바라보며 E면 즉시 격퇴한다(접근→E→쫓아냄, 전투 엔진 0).
	# block이 막기 해소 계약 {repelled, raided}를 돌려주고, 격퇴 성공은 손실 0이다. 카운터를
	# 비우고 여기로 오는 동안 손님 인내심이 닳는 게 ★ 막기↔응대 경쟁이다(ADR-0010 #2·#4).
	if facing_spot >= 0 and night_bar.is_threat(facing_spot) and Input.is_action_just_pressed("interact"):
		_try_block(facing_spot)
		return

	# T6.4 밤 손님 응대: 밤에 바 손님이 앉은 좌석을 바라보며 E면 정액 밤 매출을 번다(현재 자산,
	# 재료 무소모 — 미래 자산인 재고는 잡귀 약탈 쪽이 건드린다, ADR-0010 #5). 낮 카페 서빙과
	# 같은 좌석 줄이지만 시간이 갈려(cafe 마감 후) 한 번에 한쪽만 is_waiting이다.
	if facing_seat >= 0 and night_bar.is_waiting(facing_seat) and Input.is_action_just_pressed("interact"):
		_try_night_serve(facing_seat)
		return

	# T5.3 멜 카페 출하대: 멜을 바라보며 F로 패널을 열고/닫고, 열린 동안 S로 수확물을
	# 팔고 B로 씨앗을 산다(작은 순환을 닫는 곳). 멜이 카운터 얼굴이라 멜 앞에서만 열리고,
	# 멜 앞을 벗어나면 자동으로 닫힌다(무인 카운터 제거 — 대화·선물과 한 접점으로 통합).
	_process_shop(facing_mel)
	# M2.3 만물상 매대: 네오를 바라보며 F로 패널을 열고/닫고, 열린 동안 B로 선택 작물 씨앗을
	# (네오 할인가로) 산다. 멜 출하대와 같은 '점주 앞에서만' 패턴 — 네오 앞을 벗어나면 자동으로 닫힌다.
	_process_store(facing_neo)

	var p := player.global_position
	readout.text = "방향키 이동   구역: %s   위치(%d, %d)   FPS %d" % [
		_zone_at(p), int(p.x), int(p.y), Engine.get_frames_per_second()
	]
	clock_label.text = "Day %d   %s   %s" % [clock.day, clock.clock_string(), clock.phase()]
	# T2.3 선택 작물 HUD + T3.1 보유 씨앗 수(심을 수 있는지 한눈에).
	crop_label.text = "심을 작물: %s(%d일) 씨앗%d  [Q] 변경" % [
		CropCatalog.name_of(_selected_crop), CropCatalog.growth_days(_selected_crop),
		inventory.seed_count(_selected_crop)
	]
	# P2.5④ 작물 아이콘 재사용: 선택 작물의 mature 스프라이트를 심기 선택 HUD·출하대에
	# 아이콘으로 건다(P2.2 작물 도트를 인벤/상점 아이콘으로 재사용 — 무엇을 심고/사는지 한눈에).
	var crop_icon_tex: Texture2D = CROP_SPRITES[_selected_crop][2]
	crop_icon.texture = crop_icon_tex
	shop_crop_icon.texture = crop_icon_tex
	# T2.4 혼력 HUD: 현재/최대. 바닥나면 취침 안내를 덧붙여 막힌 이유를 알린다.
	energy_label.text = "혼력: %d/%d%s" % [
		energy.current, SoulEnergy.MAX, "  지쳤다(취침 필요)" if not energy.can_act() else ""
	]
	# T3.1 골드 HUD + 카페 출하대 패널(열렸을 때만).
	gold_label.text = "골드: %d" % wallet.gold
	# T3.3 미호 호감도 HUD: P2.5② 채운/빈 하트 스프라이트 + 단계 수(♥♡ 글리프 대체).
	affinity_label.render("미호", affinity.hearts(), Affinity.MAX_HEARTS)
	# T5.2 멜 호감도 HUD: 미호와 같은 HeartBar 틀, 캐릭터만 다름.
	mel_affinity_label.render("멜", mel_affinity.hearts(), Affinity.MAX_HEARTS)
	# T6.2 바나 호감도 HUD: 미호·멜과 같은 HeartBar 틀, 캐릭터만 다름.
	bana_affinity_label.render("바나", bana_affinity.hearts(), Affinity.MAX_HEARTS)
	# M2.3 네오 호감도 HUD: 메인 3인과 같은 HeartBar 틀(만물상 점주와도 하트로 사귄다). 이 슬라이스는
	# 매대 단골 할인까지 — 네오의 풀 T1 트랙(서사·하트 이벤트·결혼)은 후속. 할인 체감은 매대 패널에서.
	neo_affinity_label.render("네오", neo_affinity.hearts(), Affinity.MAX_HEARTS)
	# T3.4 여우불 도움 HUD: 현재 하트로 파생한 여우불 세기(관계→농사 보상을 눈에 보이게).
	foxfire_label.text = Foxfire.summary(affinity.hearts())
	# T5.4 카페 영업 HUD: 영업창(15–19시) 동안만 떠 현재 매출·서빙 인원을 보여준다
	# (오후 슬롯에 "지금 카페 시간"이 눈에 보이게 — 시간 희소성 피드백).
	cafe_label.visible = cafe.is_open()
	if cafe.is_open():
		# T5.5 단가에 멜 마진 배수를 붙여 노출 — 멜과 친해질수록 같은 서빙이 비싸지는 걸
		# 영업 중에 눈으로 체감하게 한다(관계=곱셈기, ADR-0008). ♡0이면 ×1.0(base rate).
		cafe_label.text = "카페 영업 중 (~19:00) · 매출 %d골드 · 손님 %d명 (단가 %d ×%.1f)" % [
			cafe.today_revenue(), cafe.today_served(), cafe.serve_price(),
			CafeMargin.margin(mel_affinity.hearts())
		]
	# T6.3/T6.4 밤 바 HUD: 밤 창(19–24시) 동안만 떠 옵트인 여부를 알린다. 안 열었으면 "바나에게
	# 열 수 있다"(선택), 열었으면 영업 중 잡귀 수·손님 수·밤 매출(막기↔응대 경쟁과 이중 손익을
	# 눈에 보이게 — 잡귀를 막을지 손님을 받을지 한눈에 저울질하게 한다).
	night_label.visible = not _sleeping and night_bar.is_window(clock.minutes) \
		and onboarding.step > Onboarding.NOTICE
	if night_label.visible:
		if night_bar.is_opened():
			# T6.5 자동 차단 수를 약탈 옆에 노출 — 바나가 못 막은 돌파를 대신 막은 게 눈에 보이게.
			night_label.text = "나라카 바 영업 중 (~24:00) · 밤 매출 %d골드 · 잡귀 %d마리 · 손님 %d명 · 약탈 %d개 · 자동차단 %d마리" % [
				night_bar.tonight_revenue(), night_bar.threat_count(),
				night_bar.customer_count(), night_bar.tonight_raided(),
				night_bar.tonight_auto_blocked()
			]
		else:
			night_label.text = "빈 밤 — 바나에게 [F]로 나라카 바를 열 수 있다 (옵트인)"
	# T6.5 바나 이중 보호 HUD: 밤 창 동안 현재 바나 하트로 파생한 보호 세기를 보여준다(관계→밤
	# 보상을 눈에 보이게 — foxfire_label이 관계→농사에 하는 일의 밤판, ADR-0008 체감). ♡0이면 잠듦.
	bana_guard_label.visible = night_label.visible
	if bana_guard_label.visible:
		bana_guard_label.text = BanaGuard.summary(bana_affinity.hearts())
	# T7.2 카페 마일스톤 진행 바(상시 노출 — 매크로 목표). 세 루프 산출물(거둔 영혼·누적 서빙
	# 매출·세 동료 하트 합)에서 매번 파생해 "셋 다 채워야 1단이 닫힌다"를 바 하나 + 하위 분해로
	# 보여 준다(ADR-0009 — 왜 농사·카페·관계를 다 하지의 답). 완료되면 바 대신 2단 미리보기를 건다.
	milestone_label.text = CafeMilestone.summary(_run_harvested, _cafe_revenue_total, _milestone_hearts())
	# 채우는 순간 한 번 "카페 2단계!" 팝업을 띄운다(래치 — 매 프레임 재팝업 방지). 달성 여부는
	# 누적값에서 파생되므로(세이브 무상태), 재개 시엔 _ready가 래치를 미리 켜 둬 다시 안 터진다.
	if not _milestone_celebrated and _milestone_complete():
		_milestone_celebrated = true
		_show_milestone_reached()
	# T4.1 온보딩 안내 배너: 현재 목표 한 줄. 상점 패널이 떴으면 숨겨 겹침을 막는다
	# (대화 중엔 위 early-return에서 이미 숨겼다). 완료(DONE) 후엔 문구가 ""라 사라진다.
	var guide := onboarding.guidance()
	onboarding_label.visible = guide != "" and not _shop_open and not _store_open
	onboarding_label.text = guide
	# T3.1 출하대(멜)·M2.3 매대(네오)는 같은 ShopPanel을 재사용한다(서로 다른 건물이라 동시에 안 열림).
	# 어느 쪽이 열렸는지로 본문만 가른다.
	shop_panel.visible = _shop_open or _store_open
	if _shop_open:
		shop_text.text = _shop_text()
	elif _store_open:
		shop_text.text = _store_text()
	# 집 안에서만 취침 안내를 띄운다(연출 중엔 숨김).
	sleep_prompt.visible = _can_sleep()
	# 하단 프롬프트(집은 sleep_prompt, 카페·밭은 interact_prompt — 구역이 달라 겹치지 않음).
	# 우선순위: 패널 > 미호 말걸기 > 옥자 말걸기 > 바나 말걸기(밤) > 멜(대화·출하대·선물) > 손님 서빙 > 밭 동작.
	if _shop_open or _store_open:
		interact_prompt.visible = false
	elif facing_neo:
		# M2.3 네오(만물상 점주)를 바라볼 때: 대화·매대 한 줄 안내(네오가 매대 얼굴). 이 슬라이스는
		# 선물(G) 없이 일일 대화로만 친해진다(풀 T1 트랙은 후속, ADR-0014).
		interact_prompt.visible = true
		interact_prompt.text = "[E] 대화   [F] 매대"
	elif facing_miho:
		interact_prompt.visible = true
		interact_prompt.text = "[E] 대화   [G] %s 선물" % CropCatalog.name_of(_selected_crop)
	elif facing_okja:
		# T5.6 옥자를 바라볼 때: 일상 대화만(호감도·선물·출하대 없음 — 매일 보는 사장).
		interact_prompt.visible = true
		interact_prompt.text = "[E] 대화"
	elif facing_bana:
		# T6.1/T6.2 바나(밤 무대)를 바라볼 때: 대화·선물 안내. T6.3 바를 아직 안 열었으면
		# [F] 바 열기(옵트인)를 덧붙이고, 이미 열었으면 영업 중임을 알린다(막기는 T6.4+ 몫).
		interact_prompt.visible = true
		var bana_hint := "[E] 대화   [G] %s 선물" % CropCatalog.name_of(_selected_crop)
		if night_bar.is_opened():
			bana_hint += "   (나라카 바 영업 중)"
		else:
			bana_hint += "   [F] 나라카 바 열기"
		interact_prompt.text = bana_hint
	elif facing_mel:
		# T5.1/T5.2/T5.3 멜을 바라볼 때: 대화·출하대·선물 한 줄 안내(멜이 카운터 얼굴).
		interact_prompt.visible = true
		interact_prompt.text = "[E] 대화   [F] 출하대   [G] %s 선물" % CropCatalog.name_of(_selected_crop)
	elif facing_spot >= 0 and night_bar.is_threat(facing_spot):
		# T6.4 잡귀가 깃든 스폿을 바라볼 때: E로 막는다(즉시 격퇴). 막으러 오느라 카운터를
		# 비운 사이 손님이 닳는 게 ★ 막기↔응대 경쟁의 비용이다(ADR-0010 #4).
		interact_prompt.visible = true
		interact_prompt.text = "[E] 막기 (잡귀 격퇴 · 재고 지킴)"
	elif facing_seat >= 0 and cafe.is_waiting(facing_seat):
		# T5.4 기다리는 손님을 바라볼 때: 재료가 있으면 서빙, 없으면 막힌 이유를 안내.
		interact_prompt.visible = true
		interact_prompt.text = "[E] 서빙 (+%d골드)" % cafe.serve_price() if _has_any_harvest() \
			else "서빙할 재료 없음 — 수확물 필요"
	elif facing_seat >= 0 and night_bar.is_waiting(facing_seat):
		# T6.4 밤 바 손님을 바라볼 때: E로 응대(정액 밤 매출, 재료 무소모 — 현재 자산).
		interact_prompt.visible = true
		interact_prompt.text = "[E] 응대 (+%d골드)" % NightBar.SERVE_PRICE
	else:
		# 밭 칸을 바라볼 때만 [E] 안내(다음 동작 이름). 다 키운(물준) 칸이면 숨김.
		# T2.4 혼력 바닥, T3.1 씨앗 없음이면 동작 대신 막힌 이유를 안내한다.
		var action := farm.next_action(_target) if _target_valid else ""
		interact_prompt.visible = not _sleeping and _target_valid and action != ""
		if interact_prompt.visible:
			if not energy.can_act():
				interact_prompt.text = "혼력 부족 — 집에서 취침"
			elif action == "심기" and not inventory.has_seed(_selected_crop):
				interact_prompt.text = "%s 씨앗 없음 — 카페·만물상에서 구매" % CropCatalog.name_of(_selected_crop)
			else:
				interact_prompt.text = "[E] %s" % action

# ── T2.1/T3.1 밭 한 동작 ──────────────────────────────────────────────────
# 바라보는 칸의 다음 동작을 수행한다. 혼력이 없으면 막고, 심기는 씨앗이 있어야
# 하며(없으면 카페에서 사야 한다), 수확물은 인벤토리에 쌓아 경제의 양끝을 잇는다.
func _try_farm_action() -> void:
	var action := farm.next_action(_target)
	if action == "" or not energy.can_act():
		return
	# 심기는 씨앗 1개가 필요하다. 없으면 막는다(프롬프트가 "카페에서 구매"를 안내).
	if action == "심기" and not inventory.has_seed(_selected_crop):
		return
	# 수확이면 거둘 작물 id를 미리 확보한다(interact 뒤엔 칸이 비어 crop_of가 ""다).
	var harvested_crop := farm.crop_of(_target) if action == "수확" else ""
	farm.interact(_target, _selected_crop)  # action != "" 이므로 반드시 수행됨
	if action == "심기":
		inventory.take_seed(_selected_crop)   # 심은 씨앗 1개 소모
	elif action == "수확":
		inventory.add_harvest(harvested_crop) # 거둔 수확물 적재(나중에 카페에서 판매)
		_run_harvested += 1                   # T4.2 슬라이스 점수판: 거둔 영혼 총수
		_show_flavor(harvested_crop)          # T3.5 그 영혼의 생전 사연 한 줄을 띄운다
	# P2.6 밭 동작 SFX. 괭이질·심기는 흙 다지는 둔탁한 "턱"(hoe 재사용 — 둘 다 흙 누르는
	# 동작), 물주기는 물줄기, 수확은 밝은 팝. 동작 문자열(field.next_action)에서 파생한다.
	audio.sfx({"괭이질": "hoe", "심기": "hoe", "물주기": "water", "수확": "harvest"}.get(action, ""))
	_advance_onboarding(action)               # T4.1 이 동작이 온보딩 단계를 다음으로 넘긴다
	energy.spend()                            # 한 동작당 혼력 소모
	queue_redraw()                            # 새 상태가 바로 보이도록

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

# ── T3.1/T5.3 멜 카페 출하대 ───────────────────────────────────────────────
# 멜이 카운터 얼굴이라 멜을 바라볼 때만 동작한다(T5.3 — 무인 카운터 제거, '멜 앞에서만'
# 패턴). F로 패널을 토글하고, 열린 동안 S=수확물 전량 판매, B=선택 작물 씨앗 구매. 멜
# 앞을 벗어나거나 자는 중이면 자동으로 닫힌다(이동하면 닫혀 상태가 새지 않는다). 키가
# E(대화)·G(선물)과 갈려 멜 앞에서 세 동사가 충돌하지 않는다(기존 판매/구매는 그대로).
func _process_shop(facing_mel: bool) -> void:
	if _sleeping or not facing_mel:
		_shop_open = false
		return
	if Input.is_action_just_pressed("shop_toggle"):
		_shop_open = not _shop_open
		audio.sfx("ui")                       # P2.6 출하대 패널 열고/닫기 블립
	if not _shop_open:
		return
	if Input.is_action_just_pressed("shop_sell"):
		_sell_all()
	if Input.is_action_just_pressed("shop_buy"):
		_buy_seed(_selected_crop)

# 수확물 전량을 판매가(sell_price)로 환산해 골드로 바꾼다 — 순환의 '수확물 → 골드'.
func _sell_all() -> void:
	var total := 0
	for id in inventory.harvested:
		total += inventory.harvest_count(id) * CropCatalog.sell_price(id)
	if total <= 0:
		_notice("팔 수확물이 없다")
		return
	inventory.clear_harvest()
	wallet.earn(total)
	audio.sfx("gold")                         # P2.6 동전 "치링"(raw 판매 골드 획득)
	_notice("판매 +%d골드" % total)

# 선택 작물 씨앗 1개를 seed_cost로 산다 — 순환의 '골드 → 씨앗'. 골드가 모자라면 막는다.
func _buy_seed(crop_id: String) -> void:
	var cost := CropCatalog.seed_cost(crop_id)
	if cost <= 0:
		return
	if not wallet.spend(cost):
		_notice("골드 부족(%d 필요)" % cost)
		return
	inventory.add_seed(crop_id)
	audio.sfx("ui")                           # P2.6 상점 거래 블립(씨앗 구매)
	_notice("%s 씨앗 −%d골드" % [CropCatalog.name_of(crop_id), cost])

# 멜 카페 출하대 패널 본문(골드·수확물 판매 예상액·씨앗 구매가·조작 안내). 헤더에 멜이
# 운영하는 카운터임을 드러낸다(T5.3 — 무인 카운터가 아니라 멜이 골드로 쳐준다).
func _shop_text() -> String:
	var sell_total := 0
	for id in inventory.harvested:
		sell_total += inventory.harvest_count(id) * CropCatalog.sell_price(id)
	var sel := _selected_crop
	return "\n".join([
		"── 멜의 카페 출하대 ──",
		"골드 %d" % wallet.gold,
		"수확물 %d개 → %d골드" % [inventory.total_harvest(), sell_total],
		"[S] 전량 판매",
		"[B] %s 씨앗 (−%d골드 · 보유 %d)" % [
			CropCatalog.name_of(sel), CropCatalog.seed_cost(sel), inventory.seed_count(sel)
		],
		"[Q] 작물 변경    [F] 닫기",
	])

# ── M2.3 네오 만물상 매대 ───────────────────────────────────────────────────
# 네오가 매대 얼굴이라 네오를 바라볼 때만 동작한다(멜 출하대와 같은 '점주 앞에서만' 패턴). F로
# 패널을 토글하고, 열린 동안 B=선택 작물 씨앗 구매(네오 할인가). 네오 앞을 벗어나거나 자는 중이면
# 자동으로 닫힌다(이동하면 닫혀 상태가 새지 않는다). ★ 만물상은 *구매 전용* — 수확물 판매·환전은
# 멜 출하대의 몫이다(서비스 분산, world-map.md / ADR-0015: "카페 출하대(멜, 판매·씨앗)는 유지").
func _process_store(facing_neo: bool) -> void:
	if _sleeping or not facing_neo:
		_store_open = false
		return
	if Input.is_action_just_pressed("shop_toggle"):
		_store_open = not _store_open
		audio.sfx("ui")                       # 매대 패널 열고/닫기 블립(출하대와 같은 SFX)
	if not _store_open:
		return
	if Input.is_action_just_pressed("shop_buy"):
		_buy_seed_store(_selected_crop)

# 선택 작물 씨앗 1개를 *네오 할인가*로 산다 — 순환의 '골드 → 씨앗'(멜 출하대 _buy_seed의 만물상판).
# 가격은 정가(seed_cost)에 네오 호감도 할인을 먹인 값(StoreDiscount). 골드가 모자라면 막는다.
func _buy_seed_store(crop_id: String) -> void:
	var base := CropCatalog.seed_cost(crop_id)
	if base <= 0:
		return
	var cost := StoreDiscount.price(base, neo_affinity.hearts())
	if not wallet.spend(cost):
		_notice("골드 부족(%d 필요)" % cost)
		return
	inventory.add_seed(crop_id)
	audio.sfx("ui")                           # 매대 거래 블립(씨앗 구매)
	_notice("%s 씨앗 −%d골드 (만물상)" % [CropCatalog.name_of(crop_id), cost])

# 네오 만물상 매대 패널 본문(골드·씨앗 할인가·할인율·조작 안내). 헤더에 네오가 운영하는 매대임을
# 드러낸다. 정가 대비 할인가를 함께 보여 줘 "친해질수록 싸진다"는 퍼크를 거래 시점에 체감하게 한다.
func _store_text() -> String:
	var sel := _selected_crop
	var base := CropCatalog.seed_cost(sel)
	var hearts := neo_affinity.hearts()
	var cost := StoreDiscount.price(base, hearts)
	# 할인이 걸렸으면 "정가→할인가"를, 정가면 가격 하나만 보인다(♡0 평평≠막힘).
	var price_line := "[B] %s 씨앗 (−%d골드 · 보유 %d)" % [CropCatalog.name_of(sel), cost, inventory.seed_count(sel)]
	if cost < base:
		price_line = "[B] %s 씨앗 (정가 %d → −%d골드 · 보유 %d)" % [CropCatalog.name_of(sel), base, cost, inventory.seed_count(sel)]
	return "\n".join([
		"── 네오의 만물상 매대 ──",
		"골드 %d" % wallet.gold,
		StoreDiscount.summary(hearts),
		price_line,
		"[Q] 작물 변경    [F] 닫기",
	])

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
	# 다른 패널·프롬프트는 마무리 화면(전체 화면 불투명 패널)이 덮으므로 따로 숨기지 않는다.
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
	for id in inventory.harvested:
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
	var hint := "[E] 닫기" if dialogue.is_last() else "[E] 다음"
	dialogue_text.text = "%s\n\n%s\n\n%s   %s" % [speaker, body, dialogue.progress(), hint]

# P2.4 화자+표정 → 초상화 슬롯. 표정 → talk → 기본 stem.png 순으로 폴백하고, 매핑에 없는
# 화자(그레이박스 손님·잡귀 등)는 슬롯을 끈다(텍스트만 표시).
func _set_portrait(speaker: String, expr: String) -> void:
	var stem: String = PORTRAIT_STEM.get(speaker, "")
	if stem == "":
		dialogue_portrait.visible = false
		return
	for cand in [expr, PORTRAIT_FALLBACK_EXPR]:
		var p: String = PORTRAIT_DIR + stem + "_" + cand + ".png"
		if ResourceLoader.exists(p):
			dialogue_portrait.texture = load(p)
			dialogue_portrait.visible = true
			return
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

# ── T2.1 상호작용 대상 칸 / 시각화 ────────────────────────────────────────
# 플레이어 발 타일에서 바라보는 방향으로 한 칸 앞을 대상으로 삼는다.
# 대각선 facing은 더 큰 축으로 스냅(4방향화)한다.
func _update_target() -> void:
	var old_target := _target
	var old_valid := _target_valid
	var foot := player.global_position
	var ft := Vector2i(int(foot.x) / TILE, int(foot.y) / TILE)
	var f: Vector2 = player.get_facing()
	var step := Vector2i(0, 1)
	if abs(f.x) >= abs(f.y) and f.x != 0:
		step = Vector2i(int(sign(f.x)), 0)
	elif f.y != 0:
		step = Vector2i(0, int(sign(f.y)))
	_target = ft + step
	_target_valid = _is_farmable(_target)
	if _target != old_target or _target_valid != old_valid:
		queue_redraw()  # 커서 위치/표시 갱신

# 상호작용 가능한 칸 = 맵 안 + 밭 흙(SOIL). 길·집·카페·벽은 제외.
# T3.2/T5.6 미호 밭 자리는 사람 자리라 농사 대상에서 뺀다(말걸기와 밭 동작 충돌 방지).
# 미호가 오후에 카페로 출근해 비어 있어도 이 자리는 계속 비워 둔다(돌아올 자리 — 작물을
# 심어 미호와 겹치는 걸 막는다). 카페 자리(_miho_tile 카페값)는 SOIL이 아니라 자동 제외된다.
func _is_farmable(t: Vector2i) -> bool:
	if t.x < 0 or t.x >= _grid_w or t.y < 0 or t.y >= _grid_h:
		return false
	if t == MIHO_FIELD_TILE:
		return false
	return _grid[t.y][t.x] == SOIL

# 밭 칸 상태가 바뀌면 오버레이 타일을 갱신한다(FarmField.tile_changed로 호출).
func _on_tile_changed(t: Vector2i) -> void:
	var idx := _overlay_index(t)
	if idx < 0:
		field_layer.erase_cell(t)
	else:
		field_layer.set_cell(t, 0, Vector2i(idx, 0))
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
	match _region:
		RegionCatalog.HOME:
			_draw_facade_home()      # 집 외관(WALL 박스 위에 덮어 닫힌 건물로)
			_draw_props_for(PROP_LAYOUT_HOME)  # 집 가구·길가 등불·화분
			_draw_crops()            # 밭의 작물 스프라이트(흙 오버레이 위·캐릭터 아래)
		RegionCatalog.NARU_VILLAGE:
			_draw_facade_cafe()      # 카페 외관
			_draw_facade_village_houses()   # ★ M2.5 메인 집 3채(미호·멜·바나) 외관
			_draw_props_for(PROP_LAYOUT_CAFE)  # 카페 무대 가구·카페 등불
			# M2.4 — 이벤트 데이면 카페 무대를 축제 장식으로(가구 위에 가랜드·무대 카펫 덧그림).
			if Festival.is_event_day(clock.day):
				_draw_cafe_festival()
			# ★ M2.2 — 공유 집 실내에 들어와 있으면 집 가구를 재사용해 그린다(HOUSE_RECT 방).
			# 만물상 방·카페 방은 카메라 밖이라 같이 그려도 안 보이지만, 가구는 들어온 그 방만 둔다.
			if _is_in_house_interior():
				_draw_props_for(PROP_LAYOUT_VILLAGE_HOUSE)
			_draw_customers()
			_draw_night_customers()
			_draw_jobgui()
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
		draw_texture_rect(tex, Rect2(Vector2(t.x * TILE, t.y * TILE), Vector2(TILE, TILE)), false)

# 외부 건물 외관을 외관 박스 좌상단에 1:1로 그린다(이미지 크기 = 박스 크기). 통과 불가 WALL
# 박스를 도트 외관이 덮어 "닫힌 건물"이 되고, 문 칸(외관 하단 중앙)에 닿으면 실내로 fade 전환한다.
# 실내 모드에선 외관 자리(외부)가 카메라 밖이라 그려져도 보이지 않는다.
# ★ M1.4 — 외관을 구역별로 갈라 그린다(집=안식 농원, 카페=나루 마을). 카페 이주로 카페 외관은
# 더는 안식 농원에 없고 나루 마을 야외에만 선다.
func _draw_facade_home() -> void:
	draw_texture_rect(FACADE_HOUSE, Rect2(Vector2(HOUSE_EXT_RECT.position * TILE), FACADE_HOUSE.get_size()), false)

func _draw_facade_cafe() -> void:
	draw_texture_rect(FACADE_CAFE, Rect2(Vector2(CAFE_EXT_RECT.position * TILE), FACADE_CAFE.get_size()), false)

# ★ M2.5 — 나루 마을 메인 집 3채 외관(카페와 같은 결 — 통과 불가 WALL 박스 위 1:1 덮어 그리기).
# 본체 캐릭터별 재도색이라 라벨 없이 외관만으로 누구 집인지 읽힌다(카페 컨벤션). 그리기 전용 —
# WALL 충돌·문 트리거·동선은 그레이박스 시절 그대로(_build_naru_village), 보이는 것만 바뀐다.
func _draw_facade_village_houses() -> void:
	draw_texture_rect(FACADE_MEL_HOUSE, Rect2(Vector2(MEL_HOUSE_RECT.position * TILE), FACADE_MEL_HOUSE.get_size()), false)
	draw_texture_rect(FACADE_MIHO_HOUSE, Rect2(Vector2(MIHO_HOUSE_RECT.position * TILE), FACADE_MIHO_HOUSE.get_size()), false)
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
func _draw_props_for(layout: Array) -> void:
	for entry in layout:
		var tex: Texture2D = entry[0]
		for t in entry[1]:
			# ADR-0013: 가구 아트도 32px native라 1:1로 그린다(스툴 32×32=1칸, 침대 32×64=1×2칸).
			draw_texture_rect(tex, Rect2(Vector2(t.x * TILE, t.y * TILE), tex.get_size()), false)

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
			if FARM_RECT.has_point(t):
				return "밭"
		RegionCatalog.NARU_VILLAGE:
			if CAFE_RECT.has_point(t):
				return "카페"
	return "바깥"
