extends RefCounted
class_name FertilizerCatalog
# S1-6 — 비료 정적 카탈로그(2군 5종 XOR). greybox-spec §3.1·§8.4·§8.5·§8.6.
#
# 목적: ROADMAP S1-6 — 비료가 데이터로 정의되고(품질군 3 + 성장촉진군 2), 품질 확률표·성장촉진
#       계수·순수 roll 코어가 헤드리스 검증을 통과하는지 한 곳에서 보장한다. CropCatalog/
#       FruitTreeCatalog와 같은 결의 정적 참조 데이터(class_name, 세이브 상태 아님).
#
# 설계 메모(§8.4):
#   - 2군(group) XOR: "quality"(품질 확률표 스왑) vs "speed"(성숙 임계 축소). 타일은 단일 fertilizer
#     필드라 다른 비료 투입 시 overwrite — XOR가 자연 성립(밭은 한 칸에 한 비료).
#   - 품질군은 state(NONE/BASIC/QUALITY/DELUXE)로 QUALITY_TABLE 행을 고른다. 성장촉진군은
#     speed_factor(잔여 성숙일 곱)만 쓰고 품질은 NONE(품질과 별 축, §3.1).
#   - 품질 roll = 순수 코어(tier_for_roll, 결정적·경계 테스트) + 얇은 난수 래퍼(roll_quality) 분리.
#   - buy_cost·name_ko는 그레이박스 placeholder(밸런싱=Phase 3, 저승 flavor 리네임·아이콘=하류).

# ── 비료 아이템 id ────────────────────────────────────────────────────────────
# id 문자열의 계약 진실원은 ItemCatalog.FERT_*(도구 id를 ItemCatalog가 들 듯). 여기 CATALOG 키는
# 그 값과 1:1로 같은 리터럴을 쓴다 — 데이터 카탈로그가 ItemCatalog를 const로 참조하면 두 class_name이
# const 초기화 수준에서 서로를 물어 순환 로드가 되므로(ItemCatalog는 함수에서 FertilizerCatalog를 씀),
# 리터럴로 의존을 끊는다(단방향: ItemCatalog → FertilizerCatalog만). 값 어긋남은 검증기가 잡는다(§8.12).
const FERT_BASIC := "fert_basic"
const FERT_QUALITY := "fert_quality"
const FERT_DELUXE := "fert_deluxe"
const FERT_SPEED := "fert_speed"
const FERT_HYPER := "fert_hyper"

# ── 품질 상태(QUALITY_TABLE 행 키) ────────────────────────────────────────────
# state = 품질 확률표를 고르는 키. NONE = 무비료·성장촉진군(품질 가중 없음).
const STATE_NONE := "NONE"
const STATE_BASIC := "BASIC"
const STATE_QUALITY := "QUALITY"
const STATE_DELUXE := "DELUXE"

# ── 품질 확률표(§3.1) — state → [일반,은,금,이리듐] 확률(행 합 100) ────────────
# tier_for_roll이 이 행을 누적경계로 바꿔 roll 0..99를 등급 0..3에 매핑한다.
const QUALITY_TABLE := {
	STATE_NONE:    [80, 18, 2, 0],
	STATE_BASIC:   [55, 30, 13, 2],
	STATE_QUALITY: [30, 35, 27, 8],
	STATE_DELUXE:  [10, 30, 40, 20],
}

# ── 카탈로그. 키 = 비료 아이템 id, 값 = 비료 데이터 ───────────────────────────
# 필드(§8.4):
#   name_ko      : 표시명(그레이박스 — 저승 flavor 리네임 하류)
#   group        : "quality"(품질 확률표군) | "speed"(성장촉진군) — 2군 XOR
#   state        : quality군의 QUALITY_TABLE 행 키(speed군은 없음 → NONE 취급)
#   speed_factor : speed군의 잔여 성숙일 곱(0.75=−25% · 0.67=−33% / quality군은 1.0 = 무단축)
#   buy_cost     : 구매가(골드, placeholder)
const CATALOG := {
	FERT_BASIC:   {"name_ko": "기초 비료",   "group": "quality", "state": STATE_BASIC,   "speed_factor": 1.0,  "buy_cost": 20},
	FERT_QUALITY: {"name_ko": "품질 비료",   "group": "quality", "state": STATE_QUALITY, "speed_factor": 1.0,  "buy_cost": 60},
	FERT_DELUXE:  {"name_ko": "디럭스 비료", "group": "quality", "state": STATE_DELUXE,  "speed_factor": 1.0,  "buy_cost": 120},
	FERT_SPEED:   {"name_ko": "성장촉진 비료", "group": "speed", "state": STATE_NONE,    "speed_factor": 0.75, "buy_cost": 40},
	FERT_HYPER:   {"name_ko": "하이퍼 비료", "group": "speed",   "state": STATE_NONE,    "speed_factor": 0.67, "buy_cost": 100},
}

# ── 조회 ────────────────────────────────────────────────────────────────────
static func ids() -> Array:
	return CATALOG.keys()

static func has(id: String) -> bool:
	return CATALOG.has(id)

static func get_fert(id: String) -> Dictionary:
	return CATALOG.get(id, {})

static func name_of(id: String) -> String:
	return CATALOG[id]["name_ko"] if CATALOG.has(id) else ""

static func group_of(id: String) -> String:
	return CATALOG[id]["group"] if CATALOG.has(id) else ""

static func buy_cost(id: String) -> int:
	return CATALOG[id]["buy_cost"] if CATALOG.has(id) else 0

# 비료 id → 품질 확률표 state. quality군이면 그 state, 그 외(성장촉진·무비료·미지)는 NONE.
static func state_of(id: String) -> String:
	return CATALOG[id]["state"] if (CATALOG.has(id) and CATALOG[id]["group"] == "quality") else STATE_NONE

# 비료 id → 성장촉진 잔여 성숙일 곱(§8.6). speed군이면 그 factor, 그 외(품질·무비료·미지)는 1.0(무단축).
static func speed_factor(id: String) -> float:
	return float(CATALOG[id]["speed_factor"]) if (CATALOG.has(id) and CATALOG[id]["group"] == "speed") else 1.0

# ── 품질 roll(§8.5) — 순수 코어 + 난수 래퍼 분리 ──────────────────────────────
# state의 확률행을 누적경계로 바꿔 roll(0..99)을 등급 0..3에 매핑한다(결정적·경계 테스트).
# 미지 state는 NONE으로 폴백(안전). 확률행 합이 <100이어도 마지막 등급으로 흡수(roll clamp).
static func tier_for_roll(state: String, roll: int) -> int:
	var row: Array = QUALITY_TABLE.get(state, QUALITY_TABLE[STATE_NONE])
	var r := clampi(roll, 0, 99)
	var acc := 0
	for tier in range(4):
		acc += int(row[tier])
		if r < acc:
			return tier
	return 3   # 행합<100 잔여는 최고 등급으로 흡수(경계 안전)

# state에 대한 품질 등급 난수(0..3). = tier_for_roll(state, 0..99 균등).
static func roll_quality(state: String) -> int:
	return tier_for_roll(state, randi() % 100)
