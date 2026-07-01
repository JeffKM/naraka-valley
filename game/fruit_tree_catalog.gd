extends RefCounted
class_name FruitTreeCatalog
# S1-5b — 혼의 나무(저승 과수) 정적 카탈로그. CropCatalog(작물)와 역할이 갈린 별개 카탈로그.
#
# 목적: ROADMAP S1-5b — "혼의 나무" 과수가 데이터로 정의되고 헤드리스 검증을 통과하는지 한 곳에서
#       보장한다. 설계 근거·수치 = docs/design/homestead-farming-greybox-spec.md §7.8.
#
# 왜 CropCatalog와 별개인가(greybox-spec §7.1·CONTEXT [혼의 나무]):
#   - 작물은 밭 칸(FarmField)의 per-tile 상태(물주기·성장일수)로 살지만, 혼의 나무는 3×3 영속
#     엔티티다 — 물주기·비료 없는 패시브 생산자로 orchard.gd가 자체 좌표계로 소유한다.
#   - 그래서 작물 데이터와 섞지 않고 별도 static 카탈로그로 둔다(class_name으로 어디서든
#     FruitTreeCatalog.get_tree("...")). 세이브 상태(심긴 나무·나이)는 orchard가 든다(데이터/상태 분리).
#
# 설계 메모(§7.8):
#   - ★ 그레이박스 스코프 = 정준 1종(혼백도)만. 데이터 모델은 N종 수용 구조지만 로스터는 1종이다.
#     4절기 로스터 확장(절기별 저승 과일)은 naming(CONTEXT/flavor)·아트(S1-10)·콘텐츠 배치(Slice 7)
#     로 이관 — S1-5b는 콘텐츠 저작이 아니라 메카닉 스코프.
#   - mature_days=28(1절기)·fruit_cap=3은 종별 필드지만 그레이박스 상수. season(int 0..3)이 결실
#     절기(clock.season_index_for_day와 대조). sapling_cost/fruit_sell은 placeholder(밸런싱 리튠).

# ── 과일 종 식별자(영문 id) ───────────────────────────────────────────────────
const HONBAEKDO := "honbaekdo"   # 혼백도(魂魄桃) — 저승 복숭아, 피안절 결실. 그레이박스 정준 1종.

# ── 카탈로그. 키 = 영문 id, 값 = 과수 데이터 ──────────────────────────────────
# 필드(greybox-spec §7.8):
#   name_ko      : 과일 표시명(CONTEXT [혼백도])
#   season       : 결실 절기 인덱스(0=피안·1=유화·2=망연·3=성야, clock.season_index_for_day 대조)
#   mature_days  : 묘목→성숙 소요 일수(28 = 1절기, 순수 달력·물주기 무관)
#   fruit_cap    : 안 따면 매달리는 익은 과일 최대 수(제철 매일 +1 축적 상한)
#   sapling_cost : 묘목 구매가(골드, 영속 투자 → 비쌈, placeholder)
#   fruit_sell   : 과일 판매가(골드, tier0 기준 — S1-6이 나이 등급 곱을 얹음, placeholder)
const CATALOG := {
	HONBAEKDO: {
		"name_ko": "혼백도",
		"season": 0,          # 피안절(봄) — 복숭아=봄꽃 정합, 게임 시작 절기라 조기 검증
		"mature_days": 28,    # 1절기
		"fruit_cap": 3,
		"sapling_cost": 500,  # 영속 투자 placeholder
		"fruit_sell": 90,     # 프리미엄 placeholder(tier0)
	},
}

# ── 조회 ────────────────────────────────────────────────────────────────────
# 과일 종 id 목록.
static func ids() -> Array:
	return CATALOG.keys()

static func has(id: String) -> bool:
	return CATALOG.has(id)

# 과수 데이터(읽기 전용). 없는 id면 빈 Dictionary.
static func get_tree(id: String) -> Dictionary:
	return CATALOG.get(id, {})

# 표시명. 없는 id면 "".
static func name_of(id: String) -> String:
	return CATALOG[id]["name_ko"] if CATALOG.has(id) else ""

# 결실 절기 인덱스. 없는 id면 -1 sentinel(제철 판정에서 어떤 절기와도 불일치 → 결실 안 함, 안전).
static func season(id: String) -> int:
	return CATALOG[id]["season"] if CATALOG.has(id) else -1

# 성숙 소요 일수. 없는 id면 -1(is_mature가 need>=0 계약으로 미지 종을 성숙 안 시킴).
static func mature_days(id: String) -> int:
	return CATALOG[id]["mature_days"] if CATALOG.has(id) else -1

# 익은 과일 축적 상한. 없는 id면 0(결실 안 함).
static func fruit_cap(id: String) -> int:
	return CATALOG[id]["fruit_cap"] if CATALOG.has(id) else 0

# 묘목 구매가. 없는 id면 -1.
static func sapling_cost(id: String) -> int:
	return CATALOG[id]["sapling_cost"] if CATALOG.has(id) else -1

# 과일 판매가. 없는 id면 0(판매 합산에 안전).
static func fruit_sell(id: String) -> int:
	return CATALOG[id]["fruit_sell"] if CATALOG.has(id) else 0
