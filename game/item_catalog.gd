extends RefCounted
class_name ItemCatalog
# Phase 2.7 C1 — 아이템·도구 정적 카탈로그(ADR-0020 데이터 주도 아이템 / ADR-0024 마우스 조작).
#
# 목적: 인벤토리 슬롯에 담기는 "무엇"(도구·씨앗·수확물)을 한 곳에서 정의한다. CropCatalog가
#       "작물이 어떻게 자라나"(성장일수·단계)를 들듯, ItemCatalog는 "아이템이 무엇인가"
#       (표시명·카테고리·스택여부·가격)를 든다. 둘은 역할이 갈린다 — 씨앗·수확물 아이템은
#       CropCatalog의 작물군을 *참조*하고(이름·가격 파생), CropCatalog는 성장 데이터 전용으로
#       잔존한다(데이터 중복 0, 단일 출처).
#
# 설계 메모:
#   - crops.gd(CropCatalog)와 같은 결: 정적 참조 데이터다. 세이브 상태가 아니라 카탈로그라
#     씬 노드로 두지 않고 static 헬퍼 + class_name으로 어디서든 ItemCatalog.name_of("...")로 읽는다.
#   - 아이템 id 체계(코드·세이브용 영문 id, 안정적):
#       도구    : "hoe" / "watering_can" (유니크 — 슬롯에 1개, 스택 불가)
#       씨앗    : "<작물군>_seed" (예: "honryeongcho_seed") — 스택. crop_of로 작물군 역참조.
#       수확물  : "<작물군>"      (예: "honryeongcho")      — 스택. 작물 id = 수확물 아이템 id.
#     씨앗·수확물 엔트리는 CropCatalog에서 *파생*하므로(상수에 박지 않음) 작물이 늘면 자동 따라온다.
#   - 카테고리(ADR-0020): 도구/씨앗/수확물·산물/재료/소모품. 이 슬라이스(C1)는 앞 셋만 실제로
#     쓰고, 재료(MATERIAL)·소모품(CONSUMABLE)은 자리만 예약한다(Phase 3 가공·조리).
#   - quality(품질): S1-6(§8.3)에서 슬롯 {id,count}에 quality가 더해졌다(예약 실현, ADR-0020).
#     수확물·과일만 등급을 실고(Q_NORMAL..Q_IRIDIUM), 판매가는 price_of(id, quality)로 배수를 받는다.
#     도구·씨앗·묘목·비료는 품질 무차원(항상 Q_NORMAL).
#   - 아이콘은 뷰(main) 책임이다 — 씨앗·수확물은 CROP_SPRITES(작물 도트) 재사용, 도구는 임시
#     색박스(tool_color_of). 카탈로그는 텍스처를 들지 않아(데이터/표시 분리) 헤드리스에서도 가볍다.

# ── 카테고리(ADR-0020) ──────────────────────────────────────────────────────
const CAT_TOOL := "tool"           # 도구(괭이·물뿌리개) — 유니크, 비매(price 0)
const CAT_SEED := "seed"           # 씨앗 — 심으면 작물, 스택
const CAT_SAPLING := "sapling"     # 묘목 — 심으면 혼의 나무(과수), 스택(S1-5b)
const CAT_HARVEST := "harvest"     # 수확물·산물(작물 + 과일) — 팔거나 서빙·선물, 스택
const CAT_FERTILIZER := "fertilizer"  # 비료(품질·성장촉진) — 밭 칸에 뿌림, 스택(S1-6)
const CAT_MATERIAL := "material"   # 재료 — 자리 예약(Phase 3 가공)
const CAT_CONSUMABLE := "consumable"  # 소모품 — 자리 예약(Phase 3 조리)

# ── 품질 등급(S1-6, §8.2) — 단일 진실원(orchard 나이·field 비료가 같은 enum·배수로 수렴) ──
# 수확물·과일 슬롯에 실리는 등급. 도구·씨앗·묘목·비료는 항상 Q_NORMAL(품질 무차원).
const Q_NORMAL := 0    # 일반
const Q_SILVER := 1    # 은
const Q_GOLD := 2      # 금
const Q_IRIDIUM := 3   # 이리듐
const QUALITY_MULT := [1.0, 1.25, 1.5, 2.0]     # §3.1 판매가 배수(등급 인덱스)
const QUALITY_NAMES := ["일반", "은", "금", "이리듐"]

# 등급 → 판매가 배수(clamp 0..3 방어). shipping_bin·price_of가 raw 판매가에 곱한다.
static func quality_mult(q: int) -> float:
	return QUALITY_MULT[clampi(q, 0, 3)]

# 등급 → 표시명("일반/은/금/이리듐"). HUD 품질 배지·툴팁이 쓴다.
static func quality_name(q: int) -> String:
	return QUALITY_NAMES[clampi(q, 0, 3)]

# ── 비료 아이템 id(S1-6, §8.4) — 데이터는 FertilizerCatalog, 여기는 id 진실원(도구 결) ──
const FERT_BASIC := "fert_basic"       # 기초 비료(품질군 → BASIC)
const FERT_QUALITY := "fert_quality"   # 품질 비료(품질군 → QUALITY)
const FERT_DELUXE := "fert_deluxe"     # 디럭스 비료(품질군 → DELUXE)
const FERT_SPEED := "fert_speed"       # 성장촉진 비료(성장촉진군 −25%)
const FERT_HYPER := "fert_hyper"       # 하이퍼 비료(성장촉진군 −33%)

# ── 도구 id ─────────────────────────────────────────────────────────────────
const HOE := "hoe"                 # 괭이 — 미경작 칸을 경작(LMB)
const WATERING_CAN := "watering_can"  # 물뿌리개 — 심은 칸에 물주기(LMB)
# ★ S1-8 개간 도구 3종(§10.2) — overgrown debris를 맞는 도구로 치운다(든 도구=동사, ADR-0024).
const SCYTHE := "scythe"           # 낫 — 이승의 미련(잡초) 제거
const PICKAXE := "pickaxe"         # 곡괭이 — 업화석(돌) 제거
const AXE := "axe"                 # 도끼 — 석화 고목(그루터기) 제거

# ── 목축(S1-7) — 건초·대형 산물(§8.6) ────────────────────────────────────────
# 건초(feed): 짐승 급여 재료(1마리/일 1개, §4.1). 품질 무차원 스택 아이템(CAT_MATERIAL 실사용 개시).
const HAY := "hay"
const HAY_COST := 10               # 건초 기준가(placeholder — 만물상 판매·수풀 베기는 하류)

# ── 개간(S1-8) — debris 드랍 재료(§10.2) ──────────────────────────────────────
# 개간으로 나오는 재료 3종. 품질 무차원 스택·CAT_MATERIAL(HAY 결 — Phase 3 가공 예약). name/가격은 아래 표에서.
const SOUL_FIBER := "soul_fiber"        # 혼백 섬유 — 이승의 미련(잡초·낫) 드랍
const EMBER_SHARD := "ember_shard"      # 업화석 조각 — 업화석(돌·곡괭이) 드랍
const PETRIFIED_WOOD := "petrified_wood"  # 석화 목재 — 석화 고목(그루터기·도끼) 드랍
const MATERIALS := {                    # 재료 id → {name_ko, price}(HAY는 별 상수라 여기 제외)
	SOUL_FIBER: {"name_ko": "혼백 섬유", "price": 4},
	EMBER_SHARD: {"name_ko": "업화석 조각", "price": 12},
	PETRIFIED_WOOD: {"name_ko": "석화 목재", "price": 15},
}
# 대형 산물 접미("<산물>_large"). 산물 아이템 id + 이 접미 = 대형 변이(판매가 ×2, §4.1). 씨앗:수확물 결.
const LARGE_SUFFIX := "_large"

# 씨앗 아이템 id 접미사("<작물군>_seed"). 작물군 id와 1:1 매핑.
const SEED_SUFFIX := "_seed"
# 묘목 아이템 id 접미사("<과일종>_sapling"). FruitTreeCatalog 종 id와 1:1(S1-5b).
# 수확된 과일 아이템 id = 과일 종 id 그대로(harvest_id와 같은 결 — 씨앗:수확물 = 묘목:과일).
const SAPLING_SUFFIX := "_sapling"

# 도구 카탈로그(유니크·비매). 씨앗·수확물은 CropCatalog 파생이라 상수에 없다(아래 헬퍼).
#   name_ko  : 표시명
#   color    : 그레이박스 임시 아이콘 색(도구만 — 씨앗·수확물은 작물 스프라이트 재사용)
const TOOLS := {
	HOE: {"name_ko": "괭이", "color": Color(0.62, 0.45, 0.30)},          # 흙빛 손잡이
	WATERING_CAN: {"name_ko": "물뿌리개", "color": Color(0.35, 0.55, 0.70)},  # 물빛 통
	SCYTHE: {"name_ko": "낫", "color": Color(0.72, 0.70, 0.42)},          # ★S1-8 마른 풀빛 날
	PICKAXE: {"name_ko": "곡괭이", "color": Color(0.55, 0.52, 0.56)},     # ★S1-8 회청 강철
	AXE: {"name_ko": "도끼", "color": Color(0.68, 0.40, 0.34)},           # ★S1-8 붉은 자루
}

# ── id 변환(작물군 ↔ 아이템 id) ─────────────────────────────────────────────
# 작물군 id → 씨앗 아이템 id("honryeongcho" → "honryeongcho_seed").
static func seed_id(crop_id: String) -> String:
	return crop_id + SEED_SUFFIX

# 작물군 id → 수확물 아이템 id(수확물 id = 작물 id 그대로).
static func harvest_id(crop_id: String) -> String:
	return crop_id

# 과일 종 id → 묘목 아이템 id("honbaekdo" → "honbaekdo_sapling"). S1-5b 심기 재료.
static func sapling_id(fruit_id: String) -> String:
	return fruit_id + SAPLING_SUFFIX

# ── 분류 판정(내부) ─────────────────────────────────────────────────────────
# id가 씨앗 아이템인가 = "_seed"로 끝나고 그 앞부분이 실제 작물군인가(오타·손상 방어).
static func _is_seed(id: String) -> bool:
	return id.ends_with(SEED_SUFFIX) and CropCatalog.has_crop(_seed_crop(id))

# 씨앗 아이템 id → 작물군 id("honryeongcho_seed" → "honryeongcho"). 씨앗 아님이면 "".
static func _seed_crop(id: String) -> String:
	return id.trim_suffix(SEED_SUFFIX) if id.ends_with(SEED_SUFFIX) else ""

# id가 묘목 아이템인가 = "_sapling"로 끝나고 그 앞부분이 실제 과일 종인가(오타·손상 방어).
static func _is_sapling(id: String) -> bool:
	return id.ends_with(SAPLING_SUFFIX) and FruitTreeCatalog.has(_sapling_fruit(id))

# 묘목 아이템 id → 과일 종 id("honbaekdo_sapling" → "honbaekdo"). 묘목 아님이면 "".
static func _sapling_fruit(id: String) -> String:
	return id.trim_suffix(SAPLING_SUFFIX) if id.ends_with(SAPLING_SUFFIX) else ""

# id가 수확된 과일 아이템인가(과일 종 id 그대로). 판매·스택은 작물 수확물과 동급(CAT_HARVEST).
static func _is_fruit(id: String) -> bool:
	return FruitTreeCatalog.has(id)

# id가 비료 아이템인가(S1-6). 데이터·판정은 FertilizerCatalog에 위임(_is_fruit 결).
static func _is_fertilizer(id: String) -> bool:
	return FertilizerCatalog.has(id)

# ── 목축 산물 판정(S1-7, §8.6 — _is_fruit 결) ────────────────────────────────
# id가 짐승 산물(기준 변이)인가. 데이터·판정은 AnimalCatalog에 위임.
static func _is_animal_base(id: String) -> bool:
	return AnimalCatalog.has_product(id)

# 대형 산물 아이템 id → 기준 산물 id("honbaek_ran_large" → "honbaek_ran"). 대형 아님이면 "".
static func _large_base(id: String) -> String:
	return id.trim_suffix(LARGE_SUFFIX) if id.ends_with(LARGE_SUFFIX) else ""

# id가 대형 산물 변이인가 = "_large"로 끝나고 그 앞부분이 실제 산물인가(오타·손상 방어).
static func _is_large_product(id: String) -> bool:
	return id.ends_with(LARGE_SUFFIX) and AnimalCatalog.has_product(_large_base(id))

# id가 짐승 산물(기준 or 대형)인가. 판매·스택은 작물 수확물과 동급(CAT_HARVEST).
static func _is_animal_product(id: String) -> bool:
	return _is_animal_base(id) or _is_large_product(id)

# id가 건초(급여 재료)인가.
static func _is_hay(id: String) -> bool:
	return id == HAY

# id가 개간 드랍 재료인가(S1-8, §10.2). 건초와 함께 CAT_MATERIAL(Phase 3 가공 예약).
static func _is_material(id: String) -> bool:
	return MATERIALS.has(id)

# 기준 산물 id → 대형 변이 아이템 id("honbaek_ran" → "honbaek_ran_large"). livestock 대형 수집이 쓴다.
static func large_product_id(product_id: String) -> String:
	return product_id + LARGE_SUFFIX

# ── 조회 ────────────────────────────────────────────────────────────────────
# 카탈로그에 있는 유효 아이템인가(도구·씨앗·묘목·수확물·과일·비료·건초·산물 어느 하나). 슬롯 add/load 검증에 쓴다.
static func has_item(id: String) -> bool:
	return TOOLS.has(id) or _is_seed(id) or _is_sapling(id) or CropCatalog.has_crop(id) or _is_fruit(id) \
		or _is_fertilizer(id) or _is_hay(id) or _is_material(id) or _is_animal_product(id)

# 카테고리("" = 알 수 없는 id). 인벤토리가 수확물/씨앗을 가르거나 main이 동사를 정할 때 쓴다.
# 과일(수확된 혼백도 등)은 작물 수확물과 동급 CAT_HARVEST(판매·서빙·정렬 동일 취급).
static func category_of(id: String) -> String:
	if TOOLS.has(id):
		return CAT_TOOL
	if _is_seed(id):
		return CAT_SEED
	if _is_sapling(id):
		return CAT_SAPLING
	if CropCatalog.has_crop(id) or _is_fruit(id) or _is_animal_product(id):
		return CAT_HARVEST
	if _is_fertilizer(id):
		return CAT_FERTILIZER
	if _is_hay(id) or _is_material(id):
		return CAT_MATERIAL   # 건초(S1-7)·개간 드랍(S1-8) = 재료 카테고리(Phase 3 가공 예약)
	return ""

# 표시명(HUD·상점·툴팁). 씨앗="<작물명> 씨앗"·묘목="<과일명> 묘목"·수확물=작물명·과일=과일명·도구=도구명. 없으면 "".
static func name_of(id: String) -> String:
	if TOOLS.has(id):
		return TOOLS[id]["name_ko"]
	if _is_seed(id):
		return "%s 씨앗" % CropCatalog.name_of(_seed_crop(id))
	if _is_sapling(id):
		return "%s 묘목" % FruitTreeCatalog.name_of(_sapling_fruit(id))
	if CropCatalog.has_crop(id):
		return CropCatalog.name_of(id)
	if _is_fruit(id):
		return FruitTreeCatalog.name_of(id)
	if _is_fertilizer(id):
		return FertilizerCatalog.name_of(id)
	if _is_hay(id):
		return "건초"
	if _is_material(id):
		return MATERIALS[id]["name_ko"]
	if _is_large_product(id):
		return "큰 %s" % AnimalCatalog.product_name(_large_base(id))
	if _is_animal_base(id):
		return AnimalCatalog.product_name(id)
	return ""

# 스택 가능한가. 도구=유니크(false), 씨앗·묘목·수확물·과일·비료·건초·산물=스택(true). 인벤토리 add가 합칠지 가른다.
static func stackable_of(id: String) -> bool:
	if TOOLS.has(id):
		return false
	return _is_seed(id) or _is_sapling(id) or CropCatalog.has_crop(id) or _is_fruit(id) \
		or _is_fertilizer(id) or _is_hay(id) or _is_material(id) or _is_animal_product(id)

# 기준 가격(골드). 도구=비매(0), 씨앗=구매가(seed_cost), 묘목=구매가(sapling_cost), 비료=구매가(buy_cost),
# 수확물/과일=판매가. 없으면 0. 상점은 이 값으로 사고팔되, 할인 등 변형은 호출 측(store_discount 등)이 얹는다.
# ★ S1-6(§8.7): quality 인자로 수확물·과일 판매가에 등급 배수를 얹는다(floor, 스타듀 정합). 기본 Q0라
#   무인자 기존 호출은 회귀 0. 품질 무차원 아이템(도구·씨앗·묘목·비료)은 등급을 무시(항상 기준가).
static func price_of(id: String, quality: int = Q_NORMAL) -> int:
	if TOOLS.has(id):
		return 0
	if _is_seed(id):
		return CropCatalog.seed_cost(_seed_crop(id))
	if _is_sapling(id):
		return FruitTreeCatalog.sapling_cost(_sapling_fruit(id))
	if _is_fertilizer(id):
		return FertilizerCatalog.buy_cost(id)
	if CropCatalog.has_crop(id):
		return int(CropCatalog.sell_price(id) * quality_mult(quality))
	if _is_fruit(id):
		return int(FruitTreeCatalog.fruit_sell(id) * quality_mult(quality))
	if _is_hay(id):
		return HAY_COST   # 건초 = 품질 무차원 고정가(급여 재료)
	if _is_material(id):
		return int(MATERIALS[id]["price"])   # ★S1-8 개간 드랍 = 품질 무차원 고정가(Phase 3 가공 예약)
	# ★ S1-7(§8.6): 대형 산물은 기준 판매가 ×2에 품질 배수를 얹는다(대형 = 품질과 별 축). 기준 산물은 품질 배수만.
	if _is_large_product(id):
		return int(AnimalCatalog.product_sell(_large_base(id)) * 2.0 * quality_mult(quality))
	if _is_animal_base(id):
		return int(AnimalCatalog.product_sell(id) * quality_mult(quality))
	return 0

# 씨앗 아이템 → 작물군 id("" = 씨앗 아님). main이 "이 씨앗을 심으면 무슨 작물"을 알 때 쓴다.
static func crop_of(id: String) -> String:
	return _seed_crop(id) if _is_seed(id) else ""

# 묘목 아이템 → 과일 종 id("" = 묘목 아님). main이 "이 묘목을 심으면 무슨 혼의 나무"를 알 때 쓴다.
static func fruit_of(id: String) -> String:
	return _sapling_fruit(id) if _is_sapling(id) else ""

# 그레이박스 도구 아이콘 색(도구 외엔 흰색 폴백 — 씨앗·수확물은 작물 스프라이트를 쓰므로 미사용).
static func tool_color_of(id: String) -> Color:
	return TOOLS[id]["color"] if TOOLS.has(id) else Color.WHITE
