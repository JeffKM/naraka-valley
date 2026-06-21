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
const MAP_H := 24                      # 맵 세로(타일) = 384px

# ── P2.4 대화 초상화: 화자 표시이름 → 버스트 초상화 경로 ──────────────────────
# ADR-0003 "표정=대화 시 별도 일러스트 초상화". 인게임 도트(작은 실루엣)와 달리 얼굴을
# 또렷이 살리는 자리. 키는 각 NPC display_name()(미호/옥자/멜/바나)과 일치시킨다.
# 표정 변형(미호 4~5 등)은 이 매핑에 stem을 늘려 붙이면 되는 자리(P2.4 후속).
const PORTRAIT_OF := {
	"미호": "res://assets/portraits/miho.png",
	"옥자": "res://assets/portraits/okja.png",
	"멜": "res://assets/portraits/mel.png",
	"바나": "res://assets/portraits/bana.png",
}

# ── 타일 종류(아틀라스 인덱스 = 이 순서) ──────────────────────────────────
const GROUND := 0   # 바깥 바닥(걷기 O)
const PATH := 1     # 길 — 온보딩 동선(걷기 O)
const SOIL := 2     # 밭 흙(걷기 O)
const HOUSE := 3    # 집 바닥(걷기 O)
const CAFE := 4     # 카페 바닥(걷기 O)
const WALL := 5     # 벽/건물 외벽(통과 X)
const N_TILES := 6

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
const SOLID_TILES := [HOUSE, CAFE, WALL]   # 아틀라스 가로 배치 순서(= atlas x)
# P2.3② 단색 교체: 실내 바닥·벽을 도트 타일(create_tiles_pro 산출 16×16 PNG)로 깐다.
# 아틀라스 결은 단색 시절과 동일(SOLID_SRC_ID 가로 배치) — _build_tileset이 fill 대신
# 이 텍스처를 blit한다. WALL 충돌·칠 순서는 불변(지형 위에 덮어 깔기 그대로).
const SOLID_TEX := {
	HOUSE: "res://assets/tiles/house_floor.png",  # 청회색 판석(아늑한 저승 집)
	CAFE: "res://assets/tiles/cafe_floor.png",    # 따뜻한 앰버 판자(멜의 카페)
	WALL: "res://assets/tiles/wall.png",          # 어두운 회청 벽돌(외벽·건물벽 공용)
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
# P2.3③ 소울 등불 자리(단일 출처) — 가구 그리기(PROP_LAYOUT)와 밤 빛웅덩이(lighting)가
# 이 한 배열을 공유한다(좌표가 어긋나면 등불 그림과 빛이 따로 놀므로). 길가 2 + 카페 구석 1.
const LANTERN_TILES := [Vector2i(12, 15), Vector2i(28, 15), Vector2i(36, 8)]
# [텍스처, [놓을 타일들]]. 타일 좌표는 실내 레이아웃(직원 y5 / 카운터 y6 / 좌석 y7 /
# 통로 y8) 위에 얹어 "장소"로 읽히게 배치한다. 좌석 스툴 위에는 손님 박스가 덮여 그려진다.
const PROP_LAYOUT := [
	[PROP_BED, [Vector2i(4, 5)]],                                                        # 집: 왼쪽 벽 침대
	[PROP_COUNTER, [Vector2i(31, 6), Vector2i(32, 6), Vector2i(33, 6), Vector2i(34, 6), Vector2i(35, 6)]],  # 카페 바 카운터
	[PROP_STOOL, [Vector2i(31, 7), Vector2i(33, 7), Vector2i(35, 7)]],                   # 카페 좌석 스툴(= SEAT_TILES)
	[PROP_SHELF, [Vector2i(32, 4), Vector2i(34, 4)]],                                    # 카페 뒷벽 선반
	[PROP_LANTERN, LANTERN_TILES],                                                       # 길가 2 + 카페 구석 1 등불
	[PROP_POT, [Vector2i(8, 5), Vector2i(8, 8)]],                                        # 집 두 구석 혼령초 화분
]

# ── 구역 사각형(타일 좌표, Rect2i(x, y, 폭, 높이)) ───────────────────────
# readout 구역 판정과 라벨 배치에 함께 쓴다.
const HOUSE_RECT := Rect2i(3, 4, 7, 6)    # x3..9,  y4..9
const FARM_RECT := Rect2i(14, 4, 14, 11)  # x14..27, y4..14
const CAFE_RECT := Rect2i(30, 4, 8, 7)    # x30..37, y4..10
const SPAWN_TILE := Vector2i(20, 21)      # 도착 지점
# T3.2 미호 밭 자리 — 밭 남쪽 입구(도착→복도→밭 동선의 첫 밭 칸). 길에서 위를 바라보면
# 바로 미호를 향하게 되어, 멘토가 밭 문 앞에서 맞이하는 자연스러운 첫 만남. 이 칸은 미호가
# 카페로 출근한 오후에도 농사 대상에서 제외한다(_is_farmable — 돌아올 자리는 비워 둔다).
const MIHO_FIELD_TILE := Vector2i(20, 14)
# T5.6 미호 카페 출근 자리 — 카페 뒷벽 줄(y=5)에서 멜(33,5) 오른쪽. 영업 시작(15시)부터
# 미호가 여기로 출근해 직원이 오후 카페에 모이는 무대를 만든다(ADR-0007). 카페 바닥이라
# 농사 대상이 아니고(밭과 안 겹침), 좌석(y=7)·문(33,10)·멜·옥자 칸과도 갈린다.
const MIHO_CAFE_TILE := Vector2i(35, 5)
# T4.1 옥자가 오프닝 통보 때 서는 칸 — 스폰(20,21) 바로 위. 도착하자마자 옥자를 마주본다.
# 통보가 끝나면 옥자는 이 자리에서 사라지고 카페(OKJA_CAFE_TILE)로 상주를 옮긴다(T5.6).
const OKJA_INTRO_TILE := Vector2i(20, 20)
# T5.6 옥자 카페 상주 자리 — 카페 뒷벽 줄(y=5)에서 멜(33,5) 왼쪽. 통보를 마친 뒤(NOTICE
# 단계 지남) 여기로 옮겨 매일 보는 사장이 된다(풀 관계 트랙 없음, ADR-0005). 멜(33,5)·
# 미호 출근 자리(35,5)와 한 줄에 나란히 서고, 좌석·문 동선과는 칸이 갈린다.
const OKJA_CAFE_TILE := Vector2i(31, 5)
# T5.1 멜이 서 있는 칸 — 카페 안 뒷벽 가운데(카운터 자리). 카페 문(33,10)으로 들어와
# 위로 올라오면 바로 멜을 마주본다. 카페 바닥이라 농사 대상이 아니고(밭과 안 겹침),
# 카페 출하대(T3.1)도 멜이 카운터 얼굴이라 멜을 바라볼 때만 연다(T5.3 — 무인 카운터
# 제거, 멜 앞에서 E=대화·F=출하대·G=선물 세 동사를 한 접점으로 통합).
const MEL_TILE := Vector2i(33, 5)
# T5.4 카페 손님 좌석 칸 — 카페 안 한 줄(멜 카운터 33,5 아래). 손님이 여기 앉고,
# 플레이어가 아래 칸(y=8)에 서서 위를 바라보며 E로 서빙한다. 카페 바닥이라 농사 대상이
# 아니고(밭과 안 겹침), 멜·문 동선과도 칸이 갈린다. 인덱스 = Cafe._seats 인덱스(좌석 0..2).
const SEAT_TILES := [Vector2i(31, 7), Vector2i(33, 7), Vector2i(35, 7)]
const CUST := Color(0.55, 0.42, 0.50)  # 손님 그레이박스(회색 기조 + 옅은 자줏빛, NPC들과 구분)
# T6.1 바나가 서는 밤 무대 칸 — 카페 뒷벽 직원 줄(옥자31·멜33·미호35,5) 맨 오른쪽 끝(미호
# 옆, x37은 벽). 바나는 밤(빈 밤 슬롯 19시=Cafe.CLOSE_MIN)에만 드러나는 밤 무대 호스트라
# (미호 출퇴근·옥자 상주 station 패턴) 낮엔 숨고 밤에만 보인다. 카페 바닥이라 농사 대상이
# 아니고(밭과 안 겹침), 좌석(y=7)·문(33,10)·다른 직원 칸과도 칸이 갈린다. 밤 영업창
# 옵트인(T6.3)·막기(T6.4)는 범위 밖 — T6.1은 배치 + 대사 텍스트박스만(ADR-0006 그레이박스 최소).
const BANA_NIGHT_TILE := Vector2i(36, 5)
# T6.3 잡귀가 깃드는 밤 스폿 칸 — 카페 안 앞줄(문 33,10 안쪽 y=9), 밤에 바를 열면 잡귀가
# 여기 기어든다. 카페 좌석(y=7)·직원 줄(y=5)과 칸이 갈리고(낮 카페와 시간도 갈림 — 카페
# 15–19시 마감 후 밤 19–24시), 카페 바닥이라 농사 대상이 아니다(밭과 안 겹침). 인덱스 =
# NightBar._spots 인덱스(스폿 0..2). 막기 E·이중 손실(T6.4)은 이 칸을 바라볼 때 얹힌다.
const NIGHT_SPOT_TILES := [Vector2i(31, 9), Vector2i(33, 9), Vector2i(35, 9)]
const JOBGUI := Color(0.26, 0.40, 0.30)  # 잡귀 그레이박스(탁한 청록 — 손님 CUST·NPC들과 구분)

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
@onready var energy: SoulEnergy = $SoulEnergy              # T2.4 혼력
@onready var energy_label: Label = $CanvasLayer/EnergyLabel  # T2.4 혼력 HUD
@onready var saver: SaveManager = $SaveManager            # T2.5 세이브/로드
@onready var save_label: Label = $CanvasLayer/SaveLabel   # T2.5 저장 안내·확인 HUD
@onready var wallet: Wallet = $Wallet                     # T3.1 골드
@onready var inventory: Inventory = $Inventory            # T3.1 수확물·씨앗 재고
@onready var gold_label: Label = $CanvasLayer/GoldLabel        # T3.1 골드 HUD
@onready var shop_panel: ColorRect = $CanvasLayer/ShopPanel    # T3.1 카페 출하대 패널 배경
@onready var shop_text: Label = $CanvasLayer/ShopPanel/Text    # T3.1 패널 본문
@onready var miho: Miho = $Miho                               # T3.2 미호 NPC(그레이박스)
@onready var dialogue: DialogueBox = $Dialogue                # T3.2 대사 진행기
@onready var dialogue_panel: ColorRect = $CanvasLayer/DialoguePanel  # T3.2 대화 텍스트박스 배경
@onready var dialogue_text: Label = $CanvasLayer/DialoguePanel/Text  # T3.2 대화 본문
@onready var dialogue_portrait: TextureRect = $CanvasLayer/DialoguePortrait  # P2.4 대화 초상화 슬롯
@onready var affinity: Affinity = $Affinity                   # T3.3 미호 호감도(하트)
@onready var affinity_label: Label = $CanvasLayer/AffinityLabel  # T3.3 하트 HUD
@onready var foxfire_label: Label = $CanvasLayer/FoxfireLabel  # T3.4 여우불 도움 HUD
@onready var okja: Okja = $Okja                               # T4.1 옥자 NPC(오프닝 통보)
@onready var mel: Mel = $Mel                                 # T5.1 멜 NPC(카페 운영·그레이박스)
@onready var bana: Bana = $Bana                             # T6.1 바나 NPC(밤 무대·그레이박스)
@onready var mel_affinity: Affinity = $MelAffinity           # T5.2 멜 호감도(하트, affinity.gd 재사용)
@onready var mel_affinity_label: Label = $CanvasLayer/MelAffinityLabel  # T5.2 멜 하트 HUD
@onready var bana_affinity: Affinity = $BanaAffinity         # T6.2 바나 호감도(하트, affinity.gd 재사용)
@onready var bana_affinity_label: Label = $CanvasLayer/BanaAffinityLabel  # T6.2 바나 하트 HUD
@onready var cafe: Cafe = $Cafe                               # T5.4 카페 운영(손님 서빙·일일 정산)
@onready var night_bar: NightBar = $NightBar                 # T6.3 나라카 바(밤 옵트인·잡귀 등장 게이팅)
@onready var night_label: Label = $CanvasLayer/NightLabel    # T6.3 밤 바 상태·옵트인 HUD
@onready var bana_guard_label: Label = $CanvasLayer/BanaGuardLabel  # T6.5 바나 이중 보호 상태 HUD
@onready var cafe_label: Label = $CanvasLayer/CafeLabel       # T5.4 카페 영업 상태·매출 HUD
@onready var cafe_summary_panel: ColorRect = $CanvasLayer/CafeSummaryPanel  # T5.4 마감 정산 팝업 배경
@onready var cafe_summary_text: Label = $CanvasLayer/CafeSummaryPanel/Text  # T5.4 정산 본문
@onready var milestone_label: Label = $CanvasLayer/MilestoneLabel             # T7.2 카페 마일스톤 진행 바 HUD
@onready var milestone_panel: ColorRect = $CanvasLayer/MilestonePanel         # T7.2 "카페 2단계!" 달성 팝업 배경
@onready var milestone_text: Label = $CanvasLayer/MilestonePanel/Text         # T7.2 달성 팝업 본문
@onready var onboarding: Onboarding = $Onboarding             # T4.1 온보딩 단계 머신
@onready var onboarding_label: Label = $CanvasLayer/OnboardingLabel  # T4.1 안내 배너
@onready var ending_panel: ColorRect = $CanvasLayer/EndingPanel        # T4.2/T7.3 슬라이스 마무리 화면 배경
@onready var ending_text: Label = $CanvasLayer/EndingPanel/Text        # T4.2 점수판 본문
@onready var fade: ColorRect = $CanvasLayer/Fade

# P2.3③ 밤 라이팅(CanvasModulate + 등불). 월드 캔버스에 코드로 붙인다(타일셋·입력처럼
# 런타임 조립). 무상태(시각 파생)라 세이브 대상이 아니다 — _setup_lighting에서 생성.
var lighting: DayNightLighting

var _grid: Array = []  # _grid[y][x] = 타일 id
var _sleeping := false  # T1.5 취침 연출 중이면 이동·입력 잠금

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
		var src_img := (load(SOLID_TEX[SOLID_TILES[i]]) as Texture2D).get_image()
		if src_img.get_format() != Image.FORMAT_RGBA8:
			src_img.convert(Image.FORMAT_RGBA8)
		img.blit_rect(src_img, Rect2i(0, 0, TILE_ART, TILE_ART), Vector2i(i * TILE_ART, 0))
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE_ART, TILE_ART)
	for i in n:
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, SOLID_SRC_ID)

	# 3) 물리 레이어 추가 + WALL 단색 타일에만 꽉 찬 사각 충돌 폴리곤(타일 중심 −8..8).
	ts.add_physics_layer()
	var wall_x := SOLID_TILES.find(WALL)
	var td := src.get_tile_data(Vector2i(wall_x, 0), 0)
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
func _build_grid() -> void:
	# 전부 GROUND로 채운 뒤, 우선순위 순서로 덮어쓴다.
	_grid = []
	for y in MAP_H:
		var row: Array = []
		for x in MAP_W:
			row.append(GROUND)
		_grid.append(row)

	_fill_rect(FARM_RECT, SOIL)            # 밭(열린 흙 구역)
	_build_room(HOUSE_RECT, HOUSE, Vector2i(6, 9))   # 집(아래 가운데 문)
	_build_room(CAFE_RECT, CAFE, Vector2i(33, 10))   # 카페(아래 가운데 문)
	_carve_paths()                         # 온보딩 동선(맨 위에 덮어 길 강조)
	_build_border()                        # 맵 4변 경계벽(마지막에 보장)

func _build_border() -> void:
	for x in MAP_W:
		_set_tile(x, 0, WALL)
		_set_tile(x, MAP_H - 1, WALL)
	for y in MAP_H:
		_set_tile(0, y, WALL)
		_set_tile(MAP_W - 1, y, WALL)

func _build_room(rect: Rect2i, floor_id: int, door: Vector2i) -> void:
	# 바닥으로 채운 뒤 둘레를 벽으로, 문 한 칸만 길로 뚫는다 → 문으로만 출입.
	_fill_rect(rect, floor_id)
	for x in range(rect.position.x, rect.end.x):
		_set_tile(x, rect.position.y, WALL)
		_set_tile(x, rect.end.y - 1, WALL)
	for y in range(rect.position.y, rect.end.y):
		_set_tile(rect.position.x, y, WALL)
		_set_tile(rect.end.x - 1, y, WALL)
	_set_tile(door.x, door.y, PATH)

func _carve_paths() -> void:
	# 동선 허브: 가로 복도(y=16)가 집·밭·카페를 잇고, 도착 지점에서 올라온다.
	for x in range(4, 38):
		_set_tile(x, 16, PATH)                  # 가로 복도
	for y in range(17, 22):
		_set_tile(20, y, PATH)                  # 도착(20,21) → 복도
	for y in range(10, 16):
		_set_tile(6, y, PATH)                   # 집 문 → 복도
	for y in range(11, 16):
		_set_tile(33, y, PATH)                  # 카페 문 → 복도
	_set_tile(20, 15, PATH)                     # 밭 아래 → 복도

func _paint_grid() -> void:
	# GROUND/PATH/SOIL은 terrain별 칸을 모아 corner 오토타일로 칠하고(경계·모서리
	# 자동 전환), HOUSE/CAFE/WALL은 단색 source로 직접 깐다.
	var all_terrain: Array[Vector2i] = []   # GROUND/PATH/SOIL 전부 — 풀 베이스로 단일 칠
	var path_cells: Array[Vector2i] = []
	var soil_cells: Array[Vector2i] = []
	var solids: Array = []   # [[cell, tile_id], ...] — terrain 칠 *뒤*에 덮는다
	for y in MAP_H:
		for x in MAP_W:
			var cell := Vector2i(x, y)
			var t: int = _grid[y][x]
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
	_add_label("집", _rect_center_px(HOUSE_RECT))
	_add_label("밭", _rect_center_px(FARM_RECT))
	_add_label("카페", _rect_center_px(CAFE_RECT))
	_add_label("도착", Vector2(SPAWN_TILE.x * TILE + TILE * 0.5, (SPAWN_TILE.y - 1) * TILE))

func _add_label(text: String, center_px: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(48, 12)
	lbl.position = center_px - Vector2(24, 6)
	lbl.z_index = 10
	add_child(lbl)

# ── 플레이어 스폰 + 추적 카메라 ───────────────────────────────────────────
func _setup_player_and_camera() -> void:
	player.position = _tile_center_px(SPAWN_TILE)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAP_W * TILE
	cam.limit_bottom = MAP_H * TILE
	cam.position_smoothing_enabled = false  # 정수배 픽셀 크리스프 유지(ADR-0003)
	player.add_child(cam)
	cam.make_current()

# ── P2.3③ 밤 라이팅 ────────────────────────────────────────────────────────
# CanvasModulate(화면 색조) + 소울 등불 자리 빛웅덩이를 월드 캔버스에 붙인다. 등불 위치는
# PROP_LAYOUT과 같은 LANTERN_TILES에서 픽셀 중심으로 환산해 그림과 빛을 한 자리에 둔다.
# 첫 색조는 즉시 적용해 부팅 첫 프레임부터 시각에 맞는 톤이 뜨게 한다(로드 후도 _process가 잇는다).
func _setup_lighting() -> void:
	lighting = DayNightLighting.new()
	add_child(lighting)
	var lamp_px := PackedVector2Array()
	for t in LANTERN_TILES:
		lamp_px.append(_tile_center_px(t))
	lighting.setup(lamp_px)
	lighting.apply(clock.minutes)

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

# T2.3 선택 작물을 카탈로그 순서(빠른 성장 순)대로 다음 것으로 순환.
func _cycle_crop() -> void:
	var ids := CropCatalog.ids()
	var i := ids.find(_selected_crop)
	_selected_crop = ids[(i + 1) % ids.size()]

func _on_collapsed() -> void:
	_do_sleep()  # 어디서든 쓰러져 다음 날 아침으로

# 취침 가능 조건: 집 구역 안 + 연출 중이 아님. 그레이박스라 침대 오브젝트 없이
# '집에 있으면 잘 수 있다'로 단순화한다(에셋·가구는 Phase 2).
func _can_sleep() -> bool:
	return not _sleeping and _zone_at(player.global_position) == "집"

func _do_sleep() -> void:
	if _sleeping:
		return
	_sleeping = true
	clock.running = false
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
		"onboarding": onboarding.to_save(),
		"run_harvested": _run_harvested,
		"cafe_revenue_total": _cafe_revenue_total,
		"selected_crop": _selected_crop,
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
	if data.has("onboarding"):
		onboarding.load_save(data["onboarding"])
	# T4.2 슬라이스 점수판 누적(거둔 영혼 총수). 손상 방어로 음수는 0으로 자른다.
	_run_harvested = maxi(int(data.get("run_harvested", 0)), 0)
	# T7.2 카페 마일스톤 누적 서빙 매출. 손상 방어로 음수는 0으로 자른다(키 없는 구버전 세이브는 0).
	_cafe_revenue_total = maxi(int(data.get("cafe_revenue_total", 0)), 0)
	var sel: String = data.get("selected_crop", CropCatalog.HONRYEONGCHO)
	_selected_crop = sel if CropCatalog.has_crop(sel) else CropCatalog.HONRYEONGCHO
	_notice("불러옴")

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
	# T4.2 슬라이스가 끝났으면 마무리 화면만 유지하고 모든 게임 입력을 막는다
	# (이동은 _do_sleep/_end_run에서 이미 잠갔다). 마무리 화면은 _end_run이 한 번
	# 세웠으므로 여기선 더 손대지 않는다.
	if _run_over:
		# 마무리 화면에서도 세이브 삭제+새 시작(F8)은 받는다 — 슬라이스가 끝나(보호할 진행이
		# 없음) "다시 처음부터"가 가장 자연스러운 자리다. 여긴 곧바로 실행한다(2단 확인 없음).
		if Input.is_action_just_pressed("delete_save"):
			_delete_save_and_restart()
		return
	# T3.2 대화 중엔 다른 모든 입력을 막고 대사 넘기기(E)만 처리한다. 이동은 대화
	# 시작 시 player 물리를 꺼 잠가 두었고(_start_dialogue), 끝나면 다시 켠다.
	# 패널 본문은 dialogue.changed 시그널로 갱신되므로 여기선 입력만 본다.
	if dialogue.is_open():
		onboarding_label.visible = false  # T4.1 대화가 화면을 채우는 동안 배너 숨김
		if Input.is_action_just_pressed("interact"):
			dialogue.advance()
		return

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
	# T2.4 혼력 HUD: 현재/최대. 바닥나면 취침 안내를 덧붙여 막힌 이유를 알린다.
	energy_label.text = "혼력: %d/%d%s" % [
		energy.current, SoulEnergy.MAX, "  지쳤다(취침 필요)" if not energy.can_act() else ""
	]
	# T3.1 골드 HUD + 카페 출하대 패널(열렸을 때만).
	gold_label.text = "골드: %d" % wallet.gold
	# T3.3 미호 호감도 HUD: 하트 막대 + 단계 수(하트 단계가 UI에 반영 — 완료기준).
	affinity_label.text = "미호 %s %d/%d" % [
		affinity.heart_bar(), affinity.hearts(), Affinity.MAX_HEARTS
	]
	# T5.2 멜 호감도 HUD: 하트 막대 + 단계 수(미호와 같은 표기, 캐릭터만 다름).
	mel_affinity_label.text = "멜 %s %d/%d" % [
		mel_affinity.heart_bar(), mel_affinity.hearts(), Affinity.MAX_HEARTS
	]
	# T6.2 바나 호감도 HUD: 하트 막대 + 단계 수(미호·멜과 같은 표기, 캐릭터만 다름).
	bana_affinity_label.text = "바나 %s %d/%d" % [
		bana_affinity.heart_bar(), bana_affinity.hearts(), Affinity.MAX_HEARTS
	]
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
	onboarding_label.visible = guide != "" and not _shop_open
	onboarding_label.text = guide
	shop_panel.visible = _shop_open
	if _shop_open:
		shop_text.text = _shop_text()
	# 집 안에서만 취침 안내를 띄운다(연출 중엔 숨김).
	sleep_prompt.visible = _can_sleep()
	# 하단 프롬프트(집은 sleep_prompt, 카페·밭은 interact_prompt — 구역이 달라 겹치지 않음).
	# 우선순위: 패널 > 미호 말걸기 > 옥자 말걸기 > 바나 말걸기(밤) > 멜(대화·출하대·선물) > 손님 서빙 > 밭 동작.
	if _shop_open:
		interact_prompt.visible = false
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
				interact_prompt.text = "%s 씨앗 없음 — 카페에서 구매" % CropCatalog.name_of(_selected_crop)
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
func _update_miho_station() -> void:
	var t := MIHO_CAFE_TILE if clock.minutes >= Cafe.OPEN_MIN else MIHO_FIELD_TILE
	if t != _miho_tile:
		_miho_tile = t
		miho.position = _tile_center_px(_miho_tile)

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
		_notice("잡귀를 쫓아냈다")

# T6.4 밤 손님 응대: 바 손님을 응대해 정액 밤 매출을 즉시 번다(현재 자산). 카페 서빙과 달리
# 재료를 소모하지 않는다(미래 자산인 재고는 잡귀 약탈 쪽 — ADR-0010 #5 현재/미래 분리).
func _try_night_serve(seat: int) -> void:
	var revenue := night_bar.serve(seat)
	if revenue > 0:
		wallet.earn(revenue)
		_cafe_revenue_total += revenue        # T7.2 카페 마일스톤 누적(밤 응대도 카페/바 운영 매출)
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
	_notice("%s 선물 %s+%d 호감도" % [CropCatalog.name_of(crop), tag, gained])

# 현재 줄이 바뀔 때마다(시작·넘기기) 패널을 갱신한다. 마지막 줄이면 "닫기"로 안내.
func _on_dialogue_changed(speaker: String, line: String) -> void:
	dialogue_panel.visible = true
	# P2.4 화자 초상화: 매핑에 있고 에셋이 실제로 존재할 때만 슬롯을 켠다(없으면 텍스트만 —
	# 그레이박스 손님·잡귀 등 일러스트 없는 화자는 자연스럽게 슬롯 없이 표시된다).
	var portrait_path: String = PORTRAIT_OF.get(speaker, "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		dialogue_portrait.texture = load(portrait_path)
		dialogue_portrait.visible = true
	else:
		dialogue_portrait.visible = false
	var hint := "[E] 닫기" if dialogue.is_last() else "[E] 다음"
	dialogue_text.text = "%s\n\n%s\n\n%s   %s" % [speaker, line, dialogue.progress(), hint]

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
	if t.x < 0 or t.x >= MAP_W or t.y < 0 or t.y >= MAP_H:
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
func _draw() -> void:
	_draw_props()            # 가구·장식을 맨 먼저 → 캐릭터·손님이 그 위에 올라온다
	_draw_crops()            # 밭의 작물 스프라이트(흙 오버레이 위·캐릭터 아래)
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

func _draw_props() -> void:
	for entry in PROP_LAYOUT:
		var tex: Texture2D = entry[0]
		for t in entry[1]:
			# ADR-0013: 가구 아트도 32px native라 1:1로 그린다(스툴 32×32=1칸, 침대 32×64=1×2칸).
			draw_texture_rect(tex, Rect2(Vector2(t.x * TILE, t.y * TILE), tex.get_size()), false)

# 좌석에 앉은 손님(회색 박스)과 머리 위 인내심 바(초록→빨강)를 그린다. 인내심이 줄수록
# 바가 짧아지고 붉어져 "곧 떠난다"가 눈에 보인다(서빙 우선순위 판단의 근거).
func _draw_customers() -> void:
	if not cafe.is_open():
		return
	for i in SEAT_TILES.size():
		if not cafe.is_waiting(i):
			continue
		var t: Vector2i = SEAT_TILES[i]
		# 손님 몸체: 타일 칸 안에 살짝 작은 박스(좌석 위에 앉은 느낌).
		var body := Rect2(t.x * TILE + 3, t.y * TILE + 2, TILE - 6, TILE - 4)
		draw_rect(body, CUST)
		# 인내심 바: 손님 머리 위 가로 막대. 비율만큼 채우고 잔량에 따라 색을 보간한다.
		var ratio := cafe.patience_ratio(i)
		var bar_bg := Rect2(t.x * TILE + 2, t.y * TILE - 3, TILE - 4, 2)
		draw_rect(bar_bg, Color(0, 0, 0, 0.6))
		var col := Color(0.85, 0.30, 0.25).lerp(Color(0.35, 0.80, 0.35), ratio)
		draw_rect(Rect2(bar_bg.position, Vector2(bar_bg.size.x * ratio, bar_bg.size.y)), col)

# T6.4 바를 연 밤(옵트인)의 바 손님(회색 박스)과 머리 위 인내심 바를 그린다. 낮 카페 손님과
# 같은 좌석 줄(y=7)을 시간대로 나눠 쓰므로(cafe 마감 후 밤 바) 그리기도 카페 손님과 똑같은
# 규격이고, 활성(밤 바 영업 중)일 때만 그린다 — 잡귀(아래 y=9)와 한 화면에 떠 "막을지 받을지"가
# 눈에 보인다(★ 막기↔응대 경쟁). 인내심이 줄수록 바가 짧아지고 붉어져 "곧 떠난다"가 보인다.
func _draw_night_customers() -> void:
	if not night_bar.is_active():
		return
	for i in SEAT_TILES.size():
		if not night_bar.is_waiting(i):
			continue
		var t: Vector2i = SEAT_TILES[i]
		var body := Rect2(t.x * TILE + 3, t.y * TILE + 2, TILE - 6, TILE - 4)
		draw_rect(body, CUST)
		var ratio := night_bar.patience_ratio(i)
		var bar_bg := Rect2(t.x * TILE + 2, t.y * TILE - 3, TILE - 4, 2)
		draw_rect(bar_bg, Color(0, 0, 0, 0.6))
		var col := Color(0.85, 0.30, 0.25).lerp(Color(0.35, 0.80, 0.35), ratio)
		draw_rect(Rect2(bar_bg.position, Vector2(bar_bg.size.x * ratio, bar_bg.size.y)), col)

# T6.3 바를 연 밤(옵트인)에 깃든 잡귀(탁한 청록 박스)와 머리 위 접근 바를 그린다. 카페 손님
# 그리기와 같은 결(노드 생성·해제 없이 main이 스폿 칸에 직접 — 그레이박스). 접근 바는 잔량이
# 줄수록 짧아지고 붉어져 "곧 닿는다"가 눈에 보인다(막기 우선순위 판단의 근거).
func _draw_jobgui() -> void:
	if not night_bar.is_active():
		return
	for i in NIGHT_SPOT_TILES.size():
		if not night_bar.is_threat(i):
			continue
		var t: Vector2i = NIGHT_SPOT_TILES[i]
		# 잡귀 몸체: 타일 칸 안에 살짝 작은 박스(좌석 손님과 같은 규격, 색만 다름).
		var body := Rect2(t.x * TILE + 3, t.y * TILE + 2, TILE - 6, TILE - 4)
		draw_rect(body, JOBGUI)
		# 접근 바: 잡귀 머리 위 가로 막대. 잔량만큼 채우고 색을 보간한다(초록→빨강).
		var ratio := night_bar.approach_ratio(i)
		var bar_bg := Rect2(t.x * TILE + 2, t.y * TILE - 3, TILE - 4, 2)
		draw_rect(bar_bg, Color(0, 0, 0, 0.6))
		var col := Color(0.85, 0.30, 0.25).lerp(Color(0.35, 0.80, 0.35), ratio)
		draw_rect(Rect2(bar_bg.position, Vector2(bar_bg.size.x * ratio, bar_bg.size.y)), col)

# ── 헬퍼 ──────────────────────────────────────────────────────────────────
func _set_tile(x: int, y: int, id: int) -> void:
	if x >= 0 and x < MAP_W and y >= 0 and y < MAP_H:
		_grid[y][x] = id

func _fill_rect(rect: Rect2i, id: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_set_tile(x, y, id)

func _tile_center_px(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE * 0.5, t.y * TILE + TILE * 0.5)

func _rect_center_px(rect: Rect2i) -> Vector2:
	return Vector2((rect.position.x + rect.size.x * 0.5) * TILE,
		(rect.position.y + rect.size.y * 0.5) * TILE)

func _zone_at(px: Vector2) -> String:
	var t := Vector2i(int(px.x) / TILE, int(px.y) / TILE)
	if HOUSE_RECT.has_point(t):
		return "집"
	if FARM_RECT.has_point(t):
		return "밭"
	if CAFE_RECT.has_point(t):
		return "카페"
	return "바깥"
