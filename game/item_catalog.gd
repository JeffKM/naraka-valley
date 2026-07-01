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
#   - quality(품질) 필드는 *예약만* 한다 — Phase 3 §2.1(2축 성장 ADR-0019)에서 수확물에 품질이
#     붙을 때 슬롯 {id,count}에 quality를 더한다. 지금은 그레이박스라 품질 무차원(전부 동급).
#   - 아이콘은 뷰(main) 책임이다 — 씨앗·수확물은 CROP_SPRITES(작물 도트) 재사용, 도구는 임시
#     색박스(tool_color_of). 카탈로그는 텍스처를 들지 않아(데이터/표시 분리) 헤드리스에서도 가볍다.

# ── 카테고리(ADR-0020) ──────────────────────────────────────────────────────
const CAT_TOOL := "tool"           # 도구(괭이·물뿌리개) — 유니크, 비매(price 0)
const CAT_SEED := "seed"           # 씨앗 — 심으면 작물, 스택
const CAT_SAPLING := "sapling"     # 묘목 — 심으면 혼의 나무(과수), 스택(S1-5b)
const CAT_HARVEST := "harvest"     # 수확물·산물(작물 + 과일) — 팔거나 서빙·선물, 스택
const CAT_MATERIAL := "material"   # 재료 — 자리 예약(Phase 3 가공)
const CAT_CONSUMABLE := "consumable"  # 소모품 — 자리 예약(Phase 3 조리)

# ── 도구 id ─────────────────────────────────────────────────────────────────
const HOE := "hoe"                 # 괭이 — 미경작 칸을 경작(LMB)
const WATERING_CAN := "watering_can"  # 물뿌리개 — 심은 칸에 물주기(LMB)

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

# ── 조회 ────────────────────────────────────────────────────────────────────
# 카탈로그에 있는 유효 아이템인가(도구·씨앗·묘목·수확물·과일 어느 하나). 슬롯 add/load 검증에 쓴다.
static func has_item(id: String) -> bool:
	return TOOLS.has(id) or _is_seed(id) or _is_sapling(id) or CropCatalog.has_crop(id) or _is_fruit(id)

# 카테고리("" = 알 수 없는 id). 인벤토리가 수확물/씨앗을 가르거나 main이 동사를 정할 때 쓴다.
# 과일(수확된 혼백도 등)은 작물 수확물과 동급 CAT_HARVEST(판매·서빙·정렬 동일 취급).
static func category_of(id: String) -> String:
	if TOOLS.has(id):
		return CAT_TOOL
	if _is_seed(id):
		return CAT_SEED
	if _is_sapling(id):
		return CAT_SAPLING
	if CropCatalog.has_crop(id) or _is_fruit(id):
		return CAT_HARVEST
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
	return ""

# 스택 가능한가. 도구=유니크(false), 씨앗·묘목·수확물·과일=스택(true). 인벤토리 add가 합칠지 가른다.
static func stackable_of(id: String) -> bool:
	if TOOLS.has(id):
		return false
	return _is_seed(id) or _is_sapling(id) or CropCatalog.has_crop(id) or _is_fruit(id)

# 기준 가격(골드). 도구=비매(0), 씨앗=구매가(seed_cost), 묘목=구매가(sapling_cost), 수확물/과일=판매가. 없으면 0.
# 상점은 이 값으로 사고팔되, 할인 등 변형은 호출 측(store_discount 등)이 얹는다(데이터/정책 분리).
static func price_of(id: String) -> int:
	if TOOLS.has(id):
		return 0
	if _is_seed(id):
		return CropCatalog.seed_cost(_seed_crop(id))
	if _is_sapling(id):
		return FruitTreeCatalog.sapling_cost(_sapling_fruit(id))
	if CropCatalog.has_crop(id):
		return CropCatalog.sell_price(id)
	if _is_fruit(id):
		return FruitTreeCatalog.fruit_sell(id)
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
