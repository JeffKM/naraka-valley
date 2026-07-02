extends SceneTree
# ADR-0048 Phase D(S1-14) — 저장 상자(chest.gd + inv_frame CTX_CHEST + main 배선) 단위검증(헤드리스).
#
# ★ 핵심 불변식:
#   ① StorageChest 컨테이너 — store/peek/remove_at/is_empty·(id,quality) 스택 병합·가득 거절·세이브 왕복·손상 방어.
#   ② 프레임 CTX_CHEST — 열기/닫기(모달: 핫바 숨김·이동 잠금), 백팩/상자 슬롯 클릭 신호 라우팅.
#   ③ main 배선 — _on_frame_chest_store(백팩→상자)·_on_frame_chest_take(상자→백팩) 정확 이동 + 경제 0(지갑 불변).
#   ④ 세이브 — main 세이브에 상자 보관 내용 왕복(키 없는 구버전은 빈 상자로 시작).
# 실행: godot --headless --path game --script res://playtest/chest_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _initialize() -> void:
	print("══ ADR-0048 Phase D — 저장 상자(chest.gd) 검증 ══")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var hid := ItemCatalog.harvest_id(CropCatalog.HONRYEONGCHO)   # 수확물 아이템 id(스택 가능)

	# ── ① StorageChest 컨테이너 직접 ──
	print("── ① 컨테이너 로직 ──")
	var c := StorageChest.new()
	_check("①a 처음엔 빔", c.is_empty())
	_check("①b store 3개 = 3 반환", c.store(hid, 3, 0) == 3)
	_check("①c is_empty 해제", not c.is_empty())
	_check("①d 슬롯0 id·개수", c.id_at(0) == hid and c.count_at(0) == 3)
	_check("①e 같은 (id,q) 스택 병합", c.store(hid, 3, 0) == 3 and c.count_at(0) == 6)
	_check("①f 다른 품질은 별 슬롯", c.store(hid, 2, 1) == 2 and c.count_at(1) == 2 and c.quality_at(1) == 1)
	_check("①g 도구(유니크)는 새 슬롯 1개", c.store(ItemCatalog.HOE, 5, 0) == 1 and c.id_at(2) == ItemCatalog.HOE and c.count_at(2) == 1)
	var pk := c.peek(0)
	_check("①h peek = {id,count,quality}", pk.get("id") == hid and int(pk.get("count")) == 6 and int(pk.get("quality")) == 0)
	_check("①i remove_at 2개 → 4 남음", c.remove_at(0, 2) and c.count_at(0) == 4)
	_check("①j 미지 id 거절", c.store("__nope__", 1) == 0)

	# 가득 거절: 서로 다른 스택(같은 (id,q)는 병합되므로 품질 4종 + 유니크 id들)으로 SIZE칸을 채운 뒤 store=0.
	var full := StorageChest.new()
	for q in 4:
		full.store(hid, 1, q)   # 수확물 품질 4종 = 4칸
	for id in [ItemCatalog.HOE, ItemCatalog.WATERING_CAN, ItemCatalog.SCYTHE, ItemCatalog.PICKAXE,
			ItemCatalog.AXE, ItemCatalog.seed_id(CropCatalog.HONRYEONGCHO),
			ItemCatalog.sapling_id(FruitTreeCatalog.HONBAEKDO), ItemCatalog.FERT_BASIC, ItemCatalog.FERT_SPEED]:
		if full._first_empty() == -1:
			break
		full.store(id, 1)
	_check("①k SIZE칸 채우면 가득", full._first_empty() == -1)
	_check("①l 가득이면 store=0(미포함 id)", full.store(ItemCatalog.HAY, 1) == 0)

	# 세이브 왕복.
	var saved := c.to_save()
	var c2 := StorageChest.new()
	c2.load_save(saved)
	_check("①m 세이브 왕복 슬롯0", c2.id_at(0) == hid and c2.count_at(0) == 4)
	_check("①n 세이브 왕복 품질 슬롯", c2.id_at(1) == hid and c2.quality_at(1) == 1)
	_check("①o 세이브 왕복 도구", c2.id_at(2) == ItemCatalog.HOE)
	# 손상 방어.
	var bad := StorageChest.new()
	bad.load_save({"slots": "쓰레기"})
	_check("①p 배열 아님 → 빈 상자", bad.is_empty())
	bad.load_save({"slots": [{"id": "__nope__", "count": 3}, {"id": hid, "count": -2}, {"id": hid, "count": 5}]})
	_check("①q 미지·음수 제거·유효 보존", bad.count_at(2) == 5 and bad.id_at(0) == "" and bad.id_at(1) == "")

	# ── ② 프레임 CTX_CHEST(모달) ──
	print("── ② 프레임 CTX_CHEST ──")
	var m: Node = await _spawn_main()
	_check("②pre 처음엔 닫힘", not m.frame.is_open())
	m._open_frame(InventoryFrame.CTX_CHEST)
	_check("②a 상자 열림 = context CHEST", m.frame.context == InventoryFrame.CTX_CHEST and m.frame.is_open())
	_check("②b 열리면 핫바 숨김", not m.hotbar.visible)
	_check("②c 열리면 이동 잠금(physics off)", not m.player.is_physics_processing())
	_check("②d 프레임에 상자 주입됨", m.frame.chest == m.chest)
	m._close_frame()
	_check("②e 닫으면 context NONE", not m.frame.is_open())
	_check("②f 닫으면 핫바 복귀·이동 해제", m.hotbar.visible and m.player.is_physics_processing())

	# ── ③ main 배선: 백팩 ↔ 상자 이동(경제 0) ──
	print("── ③ 보관/회수 이동(경제 0) ──")
	m.inventory.add_harvest(CropCatalog.HONRYEONGCHO, 5, 0)
	var slot := -1
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == hid:
			slot = i
			break
	_check("③pre 백팩에 수확물 슬롯 있음", slot >= 0)
	var gold_before: int = m.wallet.gold
	var chest_before: bool = m.chest.is_empty()
	m._on_frame_chest_store(slot)
	_check("③a 보관 후 백팩에서 사라짐", m.inventory.id_at(slot) == "")
	_check("③b 보관 후 상자에 들어감", not m.chest.is_empty())
	_check("③c 지갑 불변(판매 아님)", m.wallet.gold == gold_before)
	# 상자에서 회수.
	var ci := -1
	for i in StorageChest.SIZE:
		if m.chest.id_at(i) == hid:
			ci = i
			break
	_check("③pre2 상자에 수확물 슬롯 있음", ci >= 0)
	var cnt: int = m.chest.count_at(ci)
	m._on_frame_chest_take(ci)
	_check("③d 회수 후 상자에서 사라짐", m.chest.id_at(ci) == "")
	_check("③e 회수 후 백팩 복귀", m.inventory.count_of(hid) == cnt)
	_check("③f 회수도 지갑 불변", m.wallet.gold == gold_before)
	_check("③g 시작보다 상자 비었던 상태 복귀", m.chest.is_empty() == chest_before)

	# ── ④ 세이브 왕복(main) ──
	print("── ④ main 세이브 왕복 ──")
	m.chest.store(hid, 7, 0)
	m._save_game()
	var m2: Node = await _spawn_main()   # _ready가 자동 로드
	var found := 0
	for i in StorageChest.SIZE:
		if m2.chest.id_at(i) == hid:
			found = m2.chest.count_at(i)
			break
	_check("④a 이어하기에 상자 보관 복원(7)", found == 7)

	# ── ⑤ [ADR-0048 Phase E] 갈무리방(창고) 저장 상자 — 집 상자와 독립·활성 라우팅·세이브 왕복 ──
	print("── ⑤ 창고 저장 상자(Phase E) ──")
	_check("⑤a 창고 상자 노드 존재·집 상자와 독립", m.storehouse_chest != null and m.storehouse_chest != m.chest)
	# _open_chest로 활성 상자를 집→창고로 전환(같은 CTX_CHEST 패널 공유).
	m._open_chest(m.storehouse_chest)
	_check("⑤b _open_chest = 프레임에 창고 상자 주입·활성 전환",
		m.frame.chest == m.storehouse_chest and m._active_chest == m.storehouse_chest and m.frame.is_open())
	m._close_frame()
	# 창고 상자 보관이 창고 상자에만 반영(집 상자 불변 — 독립 컨테이너).
	m.inventory.add_harvest(CropCatalog.HONRYEONGCHO, 4, 0)
	var sslot := -1
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == hid:
			sslot = i
			break
	var house_empty_before: bool = m.chest.is_empty()
	m._active_chest = m.storehouse_chest   # 활성 = 창고(보관 핸들러가 이걸 조작)
	m._on_frame_chest_store(sslot)
	_check("⑤c 창고 상자에 보관됨", not m.storehouse_chest.is_empty())
	_check("⑤d 집 상자는 불변(독립 컨테이너)", m.chest.is_empty() == house_empty_before)
	# 세이브 왕복(main) — 창고 상자 보관이 별도 조각으로 복원된다.
	m._save_game()
	var m3: Node = await _spawn_main()
	var sfound := 0
	for i in StorageChest.SIZE:
		if m3.storehouse_chest.id_at(i) == hid:
			sfound = m3.storehouse_chest.count_at(i)
			break
	_check("⑤e 이어하기에 창고 상자 복원", sfound > 0)

	print("══ %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(_fail)
