extends SceneTree
# Phase 2.7 C1 단위검증(ephemeral) — ItemCatalog(아이템 카탈로그) + Inventory(슬롯 배열).
#
# 검증 대상(ADR-0020 데이터 주도 아이템 / ADR-0024 핫바 / 새 세이브 포맷):
#   ① ItemCatalog — 도구·씨앗·수확물 분류·표시명·스택여부·가격·작물 역참조, 손상 id 방어.
#   ② 슬롯 코어 — _init 12칸, 도구 유니크(중복 거절)·씨앗/수확물 스택 합치기, 빈칸 보존, 가득 거절.
#   ③ 의미 API — add_seed/seed_count/has_seed/take_seed/add_harvest/harvest_count/take_harvest/
#      total_harvest/harvest_ids/clear_harvest가 슬롯 위에서 작물군 id로 그대로 동작(회귀 0).
#   ④ 핫바 선택 — select/select_next/select_prev/selected_id(빈칸 포함 순환).
#   ⑤ 세이브 라운드트립 — 슬롯 배열·선택 인덱스 직렬화/복원, 손상 세이브(배열 아님·이상 슬롯·유니크
#      중복·음수) 방어.
#   ⑥ 시작 키트 — grant_start_kit이 도구 2종 + 혼령초 씨앗을 지급(.new()는 _ready 미실행이라 명시).
# 실행: godot --headless --path game --script res://playtest/inventory_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _initialize() -> void:
	print("══ Phase 2.7 C1 — item_catalog.gd + inventory.gd(슬롯) 단위검증 ══")
	_test_catalog()
	_test_slot_core()
	_test_semantic_api()
	_test_selection()
	_test_save_roundtrip()
	_test_corruption_defense()
	_test_start_kit()
	print("══ %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① ItemCatalog ────────────────────────────────────────────────────────────
func _test_catalog() -> void:
	print("── ① ItemCatalog ──")
	var seed_id := ItemCatalog.seed_id(CropCatalog.HONRYEONGCHO)
	_check("①a seed_id = '<작물>_seed'", seed_id == "honryeongcho_seed")
	_check("①b harvest_id = 작물 id", ItemCatalog.harvest_id(CropCatalog.PIANHWA) == "pianhwa")
	# 분류
	_check("①c 도구 카테고리", ItemCatalog.category_of(ItemCatalog.HOE) == ItemCatalog.CAT_TOOL)
	_check("①d 씨앗 카테고리", ItemCatalog.category_of(seed_id) == ItemCatalog.CAT_SEED)
	_check("①e 수확물 카테고리", ItemCatalog.category_of("pianhwa") == ItemCatalog.CAT_HARVEST)
	_check("①f 손상 id = 빈 카테고리", ItemCatalog.category_of("garbage_xyz") == "")
	_check("①g 가짜 씨앗 id 거절", not ItemCatalog.has_item("garbage_seed"))
	# 표시명·스택·가격·역참조
	_check("①h 도구 표시명", ItemCatalog.name_of(ItemCatalog.HOE) == "괭이")
	_check("①i 씨앗 표시명 = '<작물명> 씨앗'", ItemCatalog.name_of(seed_id) == "혼령초 씨앗")
	_check("①j 도구 비스택(유니크)", ItemCatalog.stackable_of(ItemCatalog.HOE) == false)
	_check("①k 씨앗 스택", ItemCatalog.stackable_of(seed_id) == true)
	_check("①l 씨앗 가격 = seed_cost", ItemCatalog.price_of(seed_id) == CropCatalog.seed_cost(CropCatalog.HONRYEONGCHO))
	_check("①m 수확물 가격 = sell_price", ItemCatalog.price_of("pianhwa") == CropCatalog.sell_price(CropCatalog.PIANHWA))
	_check("①n 도구 비매(가격 0)", ItemCatalog.price_of(ItemCatalog.HOE) == 0)
	_check("①o 씨앗 → 작물군 역참조", ItemCatalog.crop_of(seed_id) == CropCatalog.HONRYEONGCHO)
	_check("①p 수확물은 씨앗 아님(crop_of='')", ItemCatalog.crop_of("pianhwa") == "")

# ── ② 슬롯 코어 ──────────────────────────────────────────────────────────────
func _test_slot_core() -> void:
	print("── ② 슬롯 코어 ──")
	var inv := Inventory.new()  # _init이 12칸으로 채운다(_ready/start kit 없음 — 빈 슬롯)
	_check("②a _init 12칸", inv.slots.size() == Inventory.SIZE)
	_check("②b 시작은 전부 빈칸", inv.id_at(0) == "" and inv.total_harvest() == 0)
	# 도구 유니크: 추가 OK, 중복 거절
	_check("②c 도구 추가 성공", inv.add_item(ItemCatalog.HOE))
	_check("②d 도구 중복 거절", not inv.add_item(ItemCatalog.HOE))
	_check("②e 도구 개수 1", inv.count_of(ItemCatalog.HOE) == 1)
	# 씨앗 스택: 3 + 2 = 5(한 슬롯에 합침)
	var sid := ItemCatalog.seed_id(CropCatalog.PIANHWA)
	inv.add_item(sid, 3)
	inv.add_item(sid, 2)
	_check("②f 씨앗 스택 합치기(3+2=5)", inv.count_of(sid) == 5)
	# 한 슬롯만 차지(도구1 + 씨앗1 = 2슬롯 사용)
	var used := 0
	for i in inv.slots.size():
		if inv.id_at(i) != "":
			used += 1
	_check("②g 스택은 한 슬롯만(사용 2칸)", used == 2)
	# 제거 → 0이면 빈칸으로(위치 보존)
	_check("②h 일부 제거", inv.remove_item(sid, 4) and inv.count_of(sid) == 1)
	_check("②i 모자란 제거 거절", not inv.remove_item(sid, 99))
	inv.remove_item(sid, 1)
	_check("②j 0이면 슬롯 비움", inv.count_of(sid) == 0)
	# 가득 차면 새 스택 거절(12칸을 서로 다른 유효 아이템으로 채울 순 없으니, 빈칸 0 상태를 직접 만든다)
	var full := Inventory.new()
	for i in Inventory.SIZE:
		full.slots[i] = {"id": "pianhwa", "count": 1}  # 모든 칸 점유(직접 셋업)
	_check("②k 가득 차면 새 아이템 거절", not full.add_item(ItemCatalog.HOE))

# ── ③ 의미 API(작물군 id 기반) ────────────────────────────────────────────────
func _test_semantic_api() -> void:
	print("── ③ 의미 API ──")
	var inv := Inventory.new()
	inv.add_seed(CropCatalog.HONRYEONGCHO, 3)
	_check("③a add_seed/seed_count", inv.seed_count(CropCatalog.HONRYEONGCHO) == 3)
	_check("③b has_seed", inv.has_seed(CropCatalog.HONRYEONGCHO))
	_check("③c take_seed 1개 소모", inv.take_seed(CropCatalog.HONRYEONGCHO) and inv.seed_count(CropCatalog.HONRYEONGCHO) == 2)
	_check("③d 손상 작물 add_seed 무시", _no_change_add_seed(inv, "garbage"))
	# 수확물
	inv.add_harvest(CropCatalog.HONRYEONGCHO, 2)
	inv.add_harvest(CropCatalog.PIANHWA, 1)
	_check("③e harvest_count", inv.harvest_count(CropCatalog.HONRYEONGCHO) == 2)
	_check("③f total_harvest 합", inv.total_harvest() == 3)
	_check("③g harvest_ids 2종", inv.harvest_ids().size() == 2)
	_check("③h 씨앗은 harvest_ids에 안 섞임", not inv.harvest_ids().has("honryeongcho_seed"))
	_check("③i take_harvest", inv.take_harvest(CropCatalog.PIANHWA) and inv.harvest_count(CropCatalog.PIANHWA) == 0)
	# clear_harvest는 수확물만 비우고 씨앗은 보존
	inv.clear_harvest()
	_check("③j clear_harvest = 수확물 0", inv.total_harvest() == 0)
	_check("③k clear_harvest가 씨앗 보존", inv.seed_count(CropCatalog.HONRYEONGCHO) == 2)

func _no_change_add_seed(inv: Inventory, bad: String) -> bool:
	var before := inv.total_harvest() + inv.seed_count(CropCatalog.HONRYEONGCHO)
	inv.add_seed(bad, 5)
	return inv.total_harvest() + inv.seed_count(CropCatalog.HONRYEONGCHO) == before

# ── ④ 핫바 선택 ──────────────────────────────────────────────────────────────
func _test_selection() -> void:
	print("── ④ 핫바 선택 ──")
	var inv := Inventory.new()
	inv.add_item(ItemCatalog.HOE)                       # slot 0
	inv.add_item(ItemCatalog.seed_id(CropCatalog.HONRYEONGCHO), 1)  # slot 1
	_check("④a 기본 선택 0 = 괭이", inv.selected_id() == ItemCatalog.HOE)
	inv.select(1)
	_check("④b select(1) = 씨앗", inv.selected_id() == "honryeongcho_seed")
	inv.select_next()
	_check("④c select_next → 빈칸 슬롯도 순환(2번, 빈 손)", inv.selected_index == 2 and inv.selected_id() == "")
	inv.select_prev()
	_check("④d select_prev 복귀", inv.selected_index == 1)
	inv.select(-5)
	_check("④e 범위 밖 select 무시", inv.selected_index == 1)
	inv.select_prev()
	inv.select_prev()  # 0 → -1 → SIZE-1 순환
	_check("④f prev 순환(0→끝칸)", inv.selected_index == Inventory.SIZE - 1)

# ── ⑤ 세이브 라운드트립 ──────────────────────────────────────────────────────
func _test_save_roundtrip() -> void:
	print("── ⑤ 세이브 라운드트립 ──")
	var a := Inventory.new()
	a.add_item(ItemCatalog.HOE)
	a.add_item(ItemCatalog.WATERING_CAN)
	a.add_seed(CropCatalog.PIANHWA, 7)
	a.add_harvest(CropCatalog.YEONGHON_HOBAK, 4)
	a.select(2)
	var data := a.to_save()
	# var_to_str/str_to_var 라운드트립까지 통과해야 진짜 세이브 안전(SaveManager 경로 모사)
	var serialized: String = var_to_str(data)
	var restored: Variant = str_to_var(serialized)
	var b := Inventory.new()
	b.load_save(restored)
	_check("⑤a 괭이 복원", b.count_of(ItemCatalog.HOE) == 1)
	_check("⑤b 물뿌리개 복원", b.count_of(ItemCatalog.WATERING_CAN) == 1)
	_check("⑤c 씨앗 스택 복원(7)", b.seed_count(CropCatalog.PIANHWA) == 7)
	_check("⑤d 수확물 복원(4)", b.harvest_count(CropCatalog.YEONGHON_HOBAK) == 4)
	_check("⑤e 선택 인덱스 복원", b.selected_index == 2)

# ── ⑥ 손상 세이브 방어 ───────────────────────────────────────────────────────
func _test_corruption_defense() -> void:
	print("── ⑥ 손상 세이브 방어 ──")
	var inv := Inventory.new()
	# 배열 아님 → 빈 12칸
	inv.load_save({"slots": "not_an_array", "selected_index": 99})
	_check("⑥a 배열 아님 → 빈 12칸", inv.slots.size() == Inventory.SIZE and inv.total_harvest() == 0)
	_check("⑥b 이상 선택 인덱스 클램프", inv.selected_index >= 0 and inv.selected_index < Inventory.SIZE)
	# 잡다한 손상 슬롯: 미지 id·음수·유니크 중복·null·비-Dictionary
	var dirty := {
		"slots": [
			{"id": "garbage_xyz", "count": 3},        # 미지 id → 버림
			{"id": "pianhwa", "count": -2},           # 음수 → 버림
			{"id": ItemCatalog.HOE, "count": 1},      # 유효 도구
			{"id": ItemCatalog.HOE, "count": 1},      # 유니크 중복 → 둘째 버림
			"not_a_dict",                              # 비-Dictionary → 버림
			{"id": "honryeongcho", "count": 5},       # 유효 수확물
		],
		"selected_index": 0,
	}
	inv.load_save(dirty)
	_check("⑥c 미지·음수·비dict 슬롯 제거", inv.count_of("garbage_xyz") == 0 and inv.harvest_count(CropCatalog.PIANHWA) == 0)
	_check("⑥d 유효 도구 1개만(유니크 중복 제거)", inv.count_of(ItemCatalog.HOE) == 1)
	_check("⑥e 유효 수확물 보존", inv.harvest_count(CropCatalog.HONRYEONGCHO) == 5)

# ── ⑦ 시작 키트 ──────────────────────────────────────────────────────────────
func _test_start_kit() -> void:
	print("── ⑦ 시작 키트 ──")
	var inv := Inventory.new()
	inv.grant_start_kit()  # .new()는 _ready 미실행이라 명시 지급(봇·테스트 관례)
	_check("⑦a 괭이 지급", inv.count_of(ItemCatalog.HOE) == 1)
	_check("⑦b 물뿌리개 지급", inv.count_of(ItemCatalog.WATERING_CAN) == 1)
	_check("⑦c 혼령초 씨앗 지급", inv.seed_count(CropCatalog.HONRYEONGCHO) == Inventory.START_SEEDS[CropCatalog.HONRYEONGCHO])
