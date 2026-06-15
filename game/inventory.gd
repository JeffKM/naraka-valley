extends Node
class_name Inventory
# T3.1 — 인벤토리(수확물·씨앗 보관).
#
# 목적: 경제 순환의 두 재고를 담는다 — 밭에서 거둔 수확물(팔아서 골드로)과,
#       카페에서 산 씨앗(심어서 다시 작물로). 이 둘이 있어야 "심기→수확→판매
#       →재구매→심기"의 작은 순환이 닫힌다(ROADMAP T3.1).
#
# 설계 메모:
#   - field.gd(FarmField)와 같은 결: 상태를 순수 Dictionary(작물 id → 개수)로만
#     들고 있어 그대로 직렬화된다. 화면 표시·판매가 계산·구매 조율은 main이 맡고,
#     여기서는 재고와 changed 시그널만 제공한다(단일 책임, 시그널 디커플링).
#   - 수확물과 씨앗을 분리한다: 수확물은 팔리는 것(sell_price), 씨앗은 심히는 것
#     (plant 시 1개 소모). 같은 작물이라도 역할이 달라 별도 재고로 둔다.
#   - 작물 id는 CropCatalog의 영문 id를 그대로 쓴다(코드·세이브용). 카탈로그에
#     없는 id는 받지 않아(add 시 검증) 손상·오타가 재고로 새지 않게 한다.
#   - START_SEEDS: 새 게임의 종잣돈 역할. 가장 싸고 빠른 혼령초 씨앗 몇 개를 줘
#     플레이어가 골드 0에서도 바로 첫 사이클을 돌릴 수 있게 한다(온보딩: 밭→첫 수확).
#     세이브를 불러오면 load_save가 통째로 덮어쓰므로 새 게임에만 적용된다.

signal changed()  # 재고가 바뀐 프레임(main이 HUD 갱신)

# 새 게임 시작 씨앗. _ready에서 재고가 비어 있을 때만(=새 게임) 지급한다.
const START_SEEDS := {CropCatalog.HONRYEONGCHO: 3}

# crop_id → 보유 개수. 0이 된 항목은 지워, 재고에 남은 키 = 실제 보유 종류가 된다.
var harvested: Dictionary = {}  # 거둔 수확물(판매 대상)
var seeds: Dictionary = {}      # 보유 씨앗(심기 대상)

func _ready() -> void:
	# 새 게임(둘 다 빈 재고)이면 시작 씨앗을 지급한다. main이 세이브를 불러오면
	# 그 뒤 load_save가 이 값을 덮어쓰므로, 이어하기에는 영향이 없다.
	if seeds.is_empty() and harvested.is_empty():
		for id in START_SEEDS:
			seeds[id] = START_SEEDS[id]
		changed.emit()

# ── 수확물 ────────────────────────────────────────────────────────────────
# 거둔 작물을 재고에 더한다. 카탈로그에 없는 id는 무시(손상 방어).
func add_harvest(crop_id: String, n: int = 1) -> void:
	if n <= 0 or not CropCatalog.has_crop(crop_id):
		return
	harvested[crop_id] = harvested.get(crop_id, 0) + n
	changed.emit()

func harvest_count(crop_id: String) -> int:
	return harvested.get(crop_id, 0)

# 보유한 모든 수확물 개수의 합(판매할 게 있는지 판단·HUD용).
func total_harvest() -> int:
	var sum := 0
	for id in harvested:
		sum += harvested[id]
	return sum

# 거둔 수확물 n개를 꺼내 쓴다(T3.3 미호 선물 등). 모자라면 아무것도 안 하고 false.
# 0이 되면 키를 지운다(seeds.take_seed와 같은 결).
func take_harvest(crop_id: String, n: int = 1) -> bool:
	if n <= 0 or harvest_count(crop_id) < n:
		return false
	harvested[crop_id] -= n
	if harvested[crop_id] <= 0:
		harvested.erase(crop_id)
	changed.emit()
	return true

# 수확물 재고를 통째로 비운다(전량 판매 후 호출). 변화가 있을 때만 알린다.
func clear_harvest() -> void:
	if harvested.is_empty():
		return
	harvested.clear()
	changed.emit()

# ── 씨앗 ──────────────────────────────────────────────────────────────────
func add_seed(crop_id: String, n: int = 1) -> void:
	if n <= 0 or not CropCatalog.has_crop(crop_id):
		return
	seeds[crop_id] = seeds.get(crop_id, 0) + n
	changed.emit()

func seed_count(crop_id: String) -> int:
	return seeds.get(crop_id, 0)

func has_seed(crop_id: String) -> bool:
	return seed_count(crop_id) > 0

# 씨앗 1개를 꺼내 쓴다(심기). 없으면 아무것도 안 하고 false. 0이 되면 키를 지운다.
func take_seed(crop_id: String) -> bool:
	if not has_seed(crop_id):
		return false
	seeds[crop_id] -= 1
	if seeds[crop_id] <= 0:
		seeds.erase(crop_id)
	changed.emit()
	return true

# ── T2.5 세이브/로드 ──────────────────────────────────────────────────────
# 두 재고 모두 String 키 + int 값의 순수 Dictionary라 그대로 직렬화된다.
# 깊은 복사로 넘겨, 호출 측이 들고 있어도 재고가 새지 않게 한다(field.gd와 동일).
func to_save() -> Dictionary:
	return {
		"harvested": harvested.duplicate(true),
		"seeds": seeds.duplicate(true),
	}

# 복원: 두 재고를 통째로 갈아끼운다. 손상된 세이브(Dictionary 아님)는 빈 재고로
# 방어한다. _sanitize로 카탈로그에 없는 id·음수 개수를 걸러 안전하게 만든다.
func load_save(data: Dictionary) -> void:
	harvested = _sanitize(data.get("harvested", {}))
	seeds = _sanitize(data.get("seeds", {}))
	changed.emit()

# 재고 Dictionary 정제: 카탈로그에 있는 id + 양수 개수만 남긴다(손상·버전 방어).
func _sanitize(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var clean: Dictionary = {}
	for id in raw:
		if CropCatalog.has_crop(id):
			var n := int(raw[id])
			if n > 0:
				clean[id] = n
	return clean
