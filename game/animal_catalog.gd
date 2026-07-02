extends RefCounted
class_name AnimalCatalog
# S1-7 — 혼의 짐승(저승 목축) 정적 카탈로그. CropCatalog/FruitTreeCatalog와 역할이 갈린 별개 카탈로그.
#
# 목적: ROADMAP S1-7 — "혼의 짐승" 목축이 데이터로 정의되고 헤드리스 검증을 통과하는지 한 곳에서
#       보장한다. 설계 근거·수치 = docs/design/homestead-farming-greybox-spec.md §4.1·§8(S1-7 착수).
#
# 왜 CropCatalog/FruitTreeCatalog와 별개인가(§8.1 · CONTEXT [혼의 짐승]):
#   - 작물은 밭 칸(FarmField)으로, 나무는 3×3 영속 엔티티(Orchard)로 산다. 짐승은 그 어느 것도 아닌
#     "매일 돌봄(급여·쓰다듬·방목·격리·청결)으로 우정·기분이 오르고 산물을 내는" 데일리 루프 엔티티다
#     (작물=며칠·나무=절기 vs 짐승=매일, §8.1 중복 회피 훅). 상태(우정·기분·산물)는 livestock.gd(Ranch)가
#     자체 좌표계로 소유하고, 이 파일은 종·산물의 불변 참조 데이터만 든다(데이터/상태 분리).
#
# 설계 메모(§8.4):
#   - ★ 그레이박스 스코프 = 아키타입 2종(coop·barn 각 1) — 노을닭(소형·닭장 결)·안개소(대형·외양간 결).
#     ※ 작명 확정(farm-buildings-roster.md, 2026-07-02): 표시명 = 노을닭/안개소·산물 노을알/안개젖(하늘 목장
#       하늘 심상). 내부 id(HONBAEK_*·"honbaek_*")는 세이브·회귀 안전 위해 보존(표시명≠식별자).
#     스타듀 Coop(6)/Barn(5) 동물·산물(19)을 *참고*하되 나라카는 자체 2종 큐레이션(§8.4). 4절기·다종
#     확장(naming=CONTEXT/flavor·아트=S1-11·콘텐츠 배치=하류)은 이관 — S1-7은 메카닉 스코프.
#   - 산물 = CAT_HARVEST 아이템(작물 수확물·과일과 동급으로 판매·출하). 대형 산물(is_large)은 ItemCatalog가
#     "<산물>_large" 접미 변이로 인식하고 판매가 ×2를 얹는다(씨앗:수확물 = 산물:대형산물 결).
#   - product_sell은 tier0(품질 NONE·비대형) 기준 placeholder. 품질 등급 배수(§3.1)·대형 ×2는 상류(ItemCatalog)가
#     얹는다. feed_per_day=1 고정(§4.1 "1마리/일 1 건초"). kind(coop/barn)은 그레이박스 flavor 태그.

# ── 짐승 종 식별자(영문 id) ───────────────────────────────────────────────────
const HONBAEK_DAK := "honbaek_dak"   # 노을닭(소형·닭장 결) — 산물 = 노을알. (내부 id 보존)
const HONBAEK_SO := "honbaek_so"     # 안개소(대형·외양간 결) — 산물 = 안개젖. (내부 id 보존)

# ── 산물 아이템 id(영문 id) — 산물 = CAT_HARVEST 아이템 ────────────────────────
const HONBAEK_RAN := "honbaek_ran"   # 노을알 — 노을닭의 알. (내부 id 보존)
const HONBAEK_YU := "honbaek_yu"     # 안개젖 — 안개소의 젖. (내부 id 보존)

# ── 카탈로그. 키 = 종 영문 id, 값 = 짐승 데이터 ──────────────────────────────
# 필드(§8.4):
#   name_ko       : 표시명(CONTEXT 용어)
#   kind          : "coop"(닭장 계열) | "barn"(축사 계열) — 그레이박스 flavor 태그(메카닉 동일)
#   product_id    : 산물 아이템 id(CAT_HARVEST — 판매·출하·서빙)
#   product_name  : 산물 표시명
#   product_sell  : 산물 기준 판매가(골드, tier0·비대형 — 품질/대형 배수는 상류가 얹음, placeholder)
#   large_capable : 대형 산물(is_large) 가능 종인가(§4.1 P_large)
const CATALOG := {
	HONBAEK_DAK: {
		"name_ko": "노을닭",
		"kind": "coop",
		"product_id": HONBAEK_RAN,
		"product_name": "노을알",
		"product_sell": 50,       # 알 = 저단가 데일리(placeholder)
		"large_capable": true,
	},
	HONBAEK_SO: {
		"name_ko": "안개소",
		"kind": "barn",
		"product_id": HONBAEK_YU,
		"product_name": "안개젖",
		"product_sell": 125,      # 젖 = 고단가 데일리(placeholder)
		"large_capable": true,
	},
}

# ── 조회(종) ─────────────────────────────────────────────────────────────────
static func ids() -> Array:
	return CATALOG.keys()

static func has(id: String) -> bool:
	return CATALOG.has(id)

static func get_animal(id: String) -> Dictionary:
	return CATALOG.get(id, {})

static func name_of(id: String) -> String:
	return CATALOG[id]["name_ko"] if CATALOG.has(id) else ""

static func kind_of(id: String) -> String:
	return CATALOG[id]["kind"] if CATALOG.has(id) else ""

# 종 id → 산물 아이템 id("" = 없는 종). livestock가 산물 적재 시 쓴다.
static func product_of(id: String) -> String:
	return CATALOG[id]["product_id"] if CATALOG.has(id) else ""

# 종 id → 대형 산물 가능 여부. livestock의 P_large 게이트가 쓴다.
static func large_capable(id: String) -> bool:
	return CATALOG[id]["large_capable"] if CATALOG.has(id) else false

# ── 조회(산물 — 산물 아이템 id 기준. ItemCatalog가 CAT_HARVEST 인식에 위임) ─────
# 산물 아이템 id 목록(전 종의 product_id).
static func product_ids() -> Array:
	var out: Array = []
	for id in CATALOG.keys():
		out.append(CATALOG[id]["product_id"])
	return out

# id가 유효 산물 아이템인가. ItemCatalog._is_animal_product가 위임(_is_fruit 결).
static func has_product(pid: String) -> bool:
	return pid in product_ids()

# 산물 아이템 id → 표시명("" = 없는 산물).
static func product_name(pid: String) -> String:
	for id in CATALOG.keys():
		if CATALOG[id]["product_id"] == pid:
			return CATALOG[id]["product_name"]
	return ""

# 산물 아이템 id → 기준 판매가(0 = 없는 산물, 판매 합산에 안전). ItemCatalog.price_of가 품질/대형 배수를 얹음.
static func product_sell(pid: String) -> int:
	for id in CATALOG.keys():
		if CATALOG[id]["product_id"] == pid:
			return CATALOG[id]["product_sell"]
	return 0
