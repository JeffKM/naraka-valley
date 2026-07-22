extends SceneTree

# ★ [S1R-T7 / ADR-0059 결정3] 에너지(혼력) 동사별 과금 계약 — 스타듀 정합.
#
# 무엇을 고정하나(결정3 안전망 — "괭이·물만 과금, 파종·수확·시비 무과금"):
#   ① 괭이질 = 과금(−cost)
#   ② 물주기 = 과금(−cost)
#   ③ 낫 풀베기 = 과금(−cost)          — 스타듀는 낫 사용에 스태미나를 쓴다(정합 유지)
#   ④ 파종(씨앗 심기) = 무과금(혼력 불변)
#   ⑤ 밭 수확 = 무과금(혼력 불변)       — "보람 액션 과세" 제거
#   ⑥ 시비(비료) = 무과금(혼력 불변)
#   ⑦ 혼력 0 — 과금 동사 차단(can_act)·무과금 동사는 0에서도 가동
#   ⑧ 숙련 감산 차등 — 과금 동사(괭이) L0=10 · L10=7(FarmSkill.energy_factor 실효)
#
# 계층 경계(불변): 목축·과수·개간 에너지 행동은 이 리메이크에서 건드리지 않는다(각 계층 자체 게이트).
# 좀비 방지: 끝에 quit(). run_tests 워치독. 세이브는 백업/원복(quality_skill_test 결).

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

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 든 아이템을 선택한다(도구·비료 — 없으면 인벤에 넣고 그 슬롯 선택).
func _select(m: Node, id: String) -> void:
	m.inventory.add_item(id, 1)   # 유니크 도구는 이미 있으면 무시(idempotent)
	m.inventory.select(_slot_of(m.inventory, id))

func _select_seed(m: Node, crop_id: String) -> void:
	m.inventory.add_seed(crop_id, 1)
	m.inventory.select(_slot_of(m.inventory, ItemCatalog.seed_id(crop_id)))

func _slot_of(inv: Object, id: String) -> int:
	for i in range(inv.slots.size()):
		if inv.id_at(i) == id:
			return i
	return -1

# 안식 농원에서 심을 수 있는 빈 밭칸 n개(부족하면 있는 만큼).
func _free_soils(m: Node, n: int) -> Array:
	var out: Array = []
	for y in range(1, m._grid_h - 1):
		for x in range(1, m._grid_w - 1):
			var tile := Vector2i(x, y)
			if not m.farm.is_tilled(tile) and not m._is_tree_blocked(tile):
				out.append(tile)
				if out.size() >= n:
					return out
	return out

func _initialize() -> void:
	print("▶ energy_contract_test (S1R-T7 / ADR-0059 결정3)")
	var CROP := CropCatalog.HONRYEONGCHO
	var FERT := ItemCatalog.FERT_BASIC
	var HID := ItemCatalog.harvest_id(CROP)

	# 세이브 백업·격리(quality_skill_test 결).
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.ect_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m := await _spawn_main()
	m.inventory.add_seed(CROP, 30)
	m.inventory.add_item(FERT, 30)
	m._farming_xp = 0   # L0 기준(과금 동사 비용 = 10)

	var tiles := _free_soils(m, 12)
	_check("빈 밭칸 12개 확보", tiles.size() == 12)

	# ── ① 괭이 = 과금 ──
	m.energy.refill()
	_select(m, ItemCatalog.HOE)
	m._target = tiles[0]
	var e0: int = m.energy.current
	m._use_tool()
	_check("① 괭이질 성공(경작됨)", m.farm.is_tilled(tiles[0]))
	_check("① 괭이 = 과금(−10)", m.energy.current == e0 - 10)

	# ── ② 물주기 = 과금(셋업은 직접 호출로 테스트 혼력 보존) ──
	m.farm.hoe(tiles[1]); m.farm.plant(tiles[1], CROP)
	m.energy.refill()
	_select(m, ItemCatalog.WATERING_CAN)
	m._target = tiles[1]
	var e1: int = m.energy.current
	m._use_tool()
	_check("② 물주기 성공", m.farm.is_watered(tiles[1]))
	_check("② 물주기 = 과금(−10)", m.energy.current == e1 - 10)

	# ── ③ 낫 풀베기 = 과금 ──
	m.forage.seed(tiles[2])
	_check("③ 사료풀 다 자람 셋업", m.forage.is_grown(tiles[2]))
	m.energy.refill()
	_select(m, ItemCatalog.SCYTHE)
	m._target = tiles[2]
	var e2: int = m.energy.current
	m._use_tool()
	_check("③ 낫 풀베기 성공(벰)", not m.forage.is_grown(tiles[2]))
	_check("③ 낫 = 과금(−10)", m.energy.current == e2 - 10)

	# ── ④ 파종 = 무과금 ──
	m.farm.hoe(tiles[3])
	m.energy.refill()
	_select_seed(m, CROP)
	m._target = tiles[3]
	var e3: int = m.energy.current
	m._use_tool()
	_check("④ 파종 성공", m.farm.is_planted(tiles[3]))
	_check("④ 파종 = 무과금(혼력 불변)", m.energy.current == e3)

	# ── ⑤ 밭 수확 = 무과금 ──
	m.farm.hoe(tiles[4]); m.farm.plant(tiles[4], CROP)
	m.farm._tiles[tiles[4]]["grown_days"] = 99   # 강제 성숙(테스트 셋업)
	m.energy.refill()
	m._target = tiles[4]
	var e4: int = m.energy.current
	var inv4: int = m.inventory.count_of(HID)
	m._try_harvest()
	_check("⑤ 수확 성공(적재)", m.inventory.count_of(HID) > inv4)
	_check("⑤ 수확 = 무과금(혼력 불변)", m.energy.current == e4)

	# ── ⑥ 시비 = 무과금 ──
	m.farm.hoe(tiles[5])
	m.energy.refill()
	_select(m, FERT)
	m._target = tiles[5]
	var e5: int = m.energy.current
	m._use_tool()
	_check("⑥ 시비 성공", m.farm.fertilizer_of(tiles[5]) == FERT)
	_check("⑥ 시비 = 무과금(혼력 불변)", m.energy.current == e5)

	# ── ⑦ 혼력 0 — 과금 차단 / 무과금 가동 ──
	m.energy.current = 0
	_select(m, ItemCatalog.HOE)
	m._target = tiles[6]
	m._use_tool()
	_check("⑦ 혼력0 — 괭이(과금) 차단(경작 안 됨)", not m.farm.is_tilled(tiles[6]))

	m.farm.hoe(tiles[7])
	m.energy.current = 0
	_select_seed(m, CROP)
	m._target = tiles[7]
	m._use_tool()
	_check("⑦ 혼력0 — 파종(무과금) 가동", m.farm.is_planted(tiles[7]))

	m.farm.hoe(tiles[8])
	m.energy.current = 0
	_select(m, FERT)
	m._target = tiles[8]
	m._use_tool()
	_check("⑦ 혼력0 — 시비(무과금) 가동", m.farm.fertilizer_of(tiles[8]) == FERT)

	m.farm.hoe(tiles[9]); m.farm.plant(tiles[9], CROP)
	m.farm._tiles[tiles[9]]["grown_days"] = 99
	m.energy.current = 0
	m._target = tiles[9]
	var inv9: int = m.inventory.count_of(HID)
	m._try_harvest()
	_check("⑦ 혼력0 — 수확(무과금) 가동", m.inventory.count_of(HID) > inv9)

	# ── ⑧ 숙련 감산 차등(과금 동사=괭이) — L0=10 · L10=7 ──
	m._farming_xp = 0
	m.energy.refill()
	_select(m, ItemCatalog.HOE)
	m._target = tiles[10]
	var eL0: int = m.energy.current
	m._use_tool()
	_check("⑧ L0 괭이 과금 = 10(기본)", eL0 - m.energy.current == 10)

	m._farming_xp = 5500   # L10
	m.energy.refill()
	m._target = tiles[11]
	var eL10: int = m.energy.current
	m._use_tool()
	_check("⑧ L10 괭이 과금 = 7(숙련 30% 감산)", eL10 - m.energy.current == 7)

	m.queue_free()
	await process_frame

	# 세이브 원복.
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
