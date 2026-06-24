extends SceneTree
# Phase 2.7 C2 — 무인 출하함(shipping_bin.gd + main 배선) 단위검증(ephemeral 헤드리스).
# 멜 F 게이트를 떼고(ADR-0021 출하대 무인화) "넣어 두면 다음 아침 정산"으로 판매를 바꾼 걸 검증한다.
#
# ★ 핵심 불변식:
#   ① ShippingBin 순수 — add/take_back/count/preview/settle/is_empty, 손상 load_save 방어.
#   ② 드롭(_on_frame_deposit) — 백팩 수확물 슬롯을 통째로 출하 대기로(인벤토리 차감·bin 증가).
#      수확물 외(씨앗·도구)는 출하 거절(무동작).
#   ③ 롤백(_on_frame_takeback) — 취침 전 회수(인벤토리 복귀·bin 차감).
#   ④ 익일 정산(_on_day_advanced) — settle 골드가 wallet에 들어가고 출하함이 비워진다(즉시판매 제거).
#   ⑤ 세이브 라운드트립 — 출하 대기가 새 인스턴스로 재개된다(롤백·정산 보존).
# 실행: godot --headless --path game --script res://playtest/shipping_bin_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _settle_frames(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 인벤토리에서 id를 든 첫 슬롯 인덱스(-1=없음).
func _slot_of(m: Node, id: String) -> int:
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == id:
			return i
	return -1

func _initialize() -> void:
	print("══ Phase 2.7 C2 — 무인 출하함(shipping_bin.gd) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.shipbin_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① ShippingBin 순수 단위(인스턴스 불필요한 노드) ──
	print("── ① ShippingBin 순수 ──")
	var bin := ShippingBin.new()
	var crop: String = CropCatalog.HONRYEONGCHO
	_check("①a 처음엔 비어 있음", bin.is_empty() and bin.total() == 0)
	bin.add(crop, 3)
	bin.add(crop, 2)
	_check("①b add 누적(같은 id 합산)", bin.count_of(crop) == 5)
	_check("①c preview = 개수×판매가", bin.preview_gold() == 5 * CropCatalog.sell_price(crop))
	var got := bin.take_back(crop, 2)
	_check("①d take_back = 실제 뺀 개수", got == 2 and bin.count_of(crop) == 3)
	var over := bin.take_back(crop, 99)
	_check("①e 보유 초과 take_back은 보유분만", over == 3 and bin.is_empty())
	bin.add(crop, 4)
	var gold := bin.settle()
	_check("①f settle = 정산 골드 반환 + 출하함 비움", gold == 4 * CropCatalog.sell_price(crop) and bin.is_empty())
	_check("①g settle(빈 상태) = 0", bin.settle() == 0)
	_check("①h 손상 id·n<=0 거절", not bin.add("garbage_xyz", 1) and not bin.add(crop, 0))
	# load_save 손상 방어
	bin.load_save({"pending": {"honryeongcho": 2, "garbage": 5, "pianhwa": -1}})
	_check("①i load_save 손상 정제(유효·양수만)", bin.count_of("honryeongcho") == 2 and bin.count_of("garbage") == 0 and bin.count_of("pianhwa") == 0)
	bin.free()

	var m: Node = await _spawn_main()

	# ── ② 드롭(_on_frame_deposit) ──
	print("── ② 드롭(백팩 → 출하함) ──")
	m.ship_bin.pending.clear()
	m.inventory.add_harvest(crop, 3)
	var hslot := _slot_of(m, crop)
	_check("②pre 수확물 슬롯 확보", hslot >= 0)
	var inv_before: int = m.inventory.harvest_count(crop)
	m._on_frame_deposit(hslot)
	_check("②a 드롭 = 인벤토리에서 빠짐", m.inventory.harvest_count(crop) == 0)
	_check("②b 드롭 = 출하함 대기로(통째 3개)", m.ship_bin.count_of(crop) == inv_before)
	# 씨앗·도구는 출하 거절(무동작)
	var seed_slot := _slot_of(m, ItemCatalog.seed_id(CropCatalog.HONRYEONGCHO))
	var hoe_slot := _slot_of(m, ItemCatalog.HOE)
	var bin_before: int = m.ship_bin.total()
	if seed_slot >= 0:
		m._on_frame_deposit(seed_slot)
	if hoe_slot >= 0:
		m._on_frame_deposit(hoe_slot)
	_check("②c 씨앗·도구 드롭은 거절(출하함 불변)", m.ship_bin.total() == bin_before)

	# ── ③ 롤백(_on_frame_takeback) ──
	print("── ③ 롤백(출하함 → 백팩) ──")
	var inv_b: int = m.inventory.harvest_count(crop)
	var bin_b: int = m.ship_bin.count_of(crop)
	m._on_frame_takeback(crop)
	_check("③a 롤백 = 인벤토리 복귀", m.inventory.harvest_count(crop) == inv_b + bin_b)
	_check("③b 롤백 = 출하함 비움", m.ship_bin.count_of(crop) == 0)

	# ── ④ 익일 정산(_on_day_advanced) ──
	print("── ④ 익일 정산 ──")
	m.ship_bin.pending.clear()
	m.ship_bin.add(crop, 5)
	var gold_before: int = m.wallet.gold
	var expect_gold: int = 5 * CropCatalog.sell_price(crop)
	m._on_day_advanced(m.clock.day)
	_check("④a 정산 = wallet에 판매가 합 입금", m.wallet.gold == gold_before + expect_gold)
	_check("④b 정산 후 출하함 비워짐", m.ship_bin.is_empty())

	# ── ⑤ 세이브 라운드트립 ──
	print("── ⑤ 세이브 라운드트립 ──")
	m.ship_bin.pending.clear()
	m.ship_bin.add(crop, 7)
	m._save_game()
	m.queue_free()
	await process_frame
	await process_frame
	var m2: Node = await _spawn_main()
	_check("⑤ 출하 대기 재개(7개)", m2.ship_bin.count_of(crop) == 7)
	m2.queue_free()
	await process_frame

	# ── 정리: 세이브 원복 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)
