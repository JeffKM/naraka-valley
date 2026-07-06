extends SceneTree

# ★ [ADR-0052 §118 · ADR-0033] 채집 라이브 루프 — 안식 꽃 패치(피안화) 손수확 검증.
#
# 무엇을 보나:
#   Part A(FlowerPatch 노드 순수·main 불필요):
#     ① 시드·폄 — seed 등록 / 멱등 / is_bloomed.
#     ② 따기 — 핀 것만 pick / 딴 뒤 재따기 거부 / 미시드 거부.
#     ③ 재생 — REGROW_DAYS 미달=정지, 도달=다시 핌(절기 무관 — 저승 꽃).
#     ④ 세이브 왕복 — 딴 상태(picked_day) 보존 + 재생 타이머 연속 + 빈 세이브 방어.
#   Part B(main 스폰 — 전체 사슬):
#     ⑤ 부팅 시드 — layout.json FLOWER_PATCH 좌표가 노드에 등록(bloomed_count>0).
#     ⑥ 손수확 실효 — 따면 채집물(피안화) 인벤 적재 + 채집 XP 적립 + ★혼력 0(ADR-0033 #1).
#     ⑦ 품질=채집 레벨 — L0 일반 / L5 은 / L7 금(_forage_base_quality).
#     ⑧ 약초학자 하한 — 전문직 선택 시 채집물 이리듐 고정(base 위 max, 퍼크 실효점).
#     ⑨ 채집꾼 2배 확률 배선 — 미선택=항상 1송이 / 선택 시 double_drop 확률>0.
#     ⑩ 세이브 왕복 — main 저장/복원 후 딴 패치 상태 영속.
#
# 좀비 방지: 끝에 quit(). run_tests 워치독. 세이브 백업/원복(profession_test 결).

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

func _initialize() -> void:
	print("▶ flower_patch_test (ADR-0052 §118)")

	# ── Part A: FlowerPatch 노드 순수 ────────────────────────────────────────
	var fp := FlowerPatch.new()
	var t := Vector2i(8, 12)

	# ① 시드·폄.
	_check("① 시드 전 패치 아님", not fp.has_patch(t) and not fp.is_bloomed(t))
	fp.seed(t)
	_check("① 시드 후 활짝 폄", fp.has_patch(t) and fp.is_bloomed(t))
	fp.seed(t)   # 재시드
	_check("① 재시드 멱등(중복 없음)", fp.bloomed_count() == 1)

	# ② 따기.
	_check("② 핀 패치 따기 성공", fp.pick(t, 5) and not fp.is_bloomed(t))
	_check("② 딴 뒤 재따기 거부", not fp.pick(t, 5))
	_check("② 미시드 타일 따기 거부", not fp.pick(Vector2i(99, 99), 5))

	# ③ 재생(절기 무관 — advance_day 절기 인자 없음).
	fp.advance_day(5 + FlowerPatch.REGROW_DAYS - 1)   # 미달
	_check("③ REGROW 미달 재생 안 함", not fp.is_bloomed(t))
	fp.advance_day(5 + FlowerPatch.REGROW_DAYS)         # 도달
	_check("③ REGROW 도달 다시 핌", fp.is_bloomed(t))

	# ④ 세이브 왕복.
	fp.pick(t, 20)
	var fp2 := FlowerPatch.new()
	fp2.load_save(fp.to_save())
	_check("④ 세이브 왕복 패치 존재·딴 상태 보존", fp2.has_patch(t) and not fp2.is_bloomed(t))
	fp2.advance_day(20 + FlowerPatch.REGROW_DAYS)
	_check("④ 세이브 후 재생 타이머 연속", fp2.is_bloomed(t))
	var fp3 := FlowerPatch.new()
	fp3.load_save({})
	_check("④ 빈 세이브 로드 방어(패치 0)", fp3.all_tiles().is_empty())
	fp.free(); fp2.free(); fp3.free()

	# ── Part B: main 스폰 ────────────────────────────────────────────────────
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.flower_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m := await _spawn_main()
	var F := ProfessionCatalog.FORAGING
	var SF := ItemCatalog.SPIRIT_FLOWER

	# ⑤ 부팅 시드 — layout.json 꽃 패치가 노드에 등록.
	_check("⑤ 부팅 시 꽃 패치 시드(bloomed_count>0)", m.flower.bloomed_count() > 0)

	# ⑥ 손수확 실효 — 채집물 적재 + 채집 XP + 혼력 0.
	m._foraging_xp = 0
	m._professions = {}
	var tile: Vector2i = m.flower.bloomed_tiles()[0]
	var xp0: int = m._foraging_xp
	var e0: int = m.energy.current
	var n0: int = m.inventory.count_of(SF)
	m._pick_flower(tile)
	_check("⑥ 따기 후 채집물(피안화) +1", m.inventory.count_of(SF) == n0 + 1)
	_check("⑥ 채집 XP 적립(기준가만큼)", m._foraging_xp == xp0 + ItemCatalog.price_of(SF))
	_check("⑥ 혼력 소모 없음(줍기=혼력0)", m.energy.current == e0)
	_check("⑥ 딴 자리 비-폄(노드 상태 반영)", not m.flower.is_bloomed(tile))

	# ⑦ 품질 = 채집 레벨(약초학자 없이). L0=일반 / L5=은 / L7=금.
	_check("⑦ _forage_base_quality L0 = 일반", m._forage_base_quality(0) == ItemCatalog.Q_NORMAL)
	_check("⑦ _forage_base_quality L5 = 은", m._forage_base_quality(5) == ItemCatalog.Q_SILVER)
	_check("⑦ _forage_base_quality L7 = 금", m._forage_base_quality(7) == ItemCatalog.Q_GOLD)
	# 실 수확 등급도 레벨 따라감(L5 → 은 슬롯 존재).
	m._foraging_xp = 1500   # L5
	m.flower.advance_day(m.clock.day + FlowerPatch.REGROW_DAYS)   # 딴 자리 재생
	var tile5: Vector2i = m.flower.bloomed_tiles()[0]
	m._pick_flower(tile5)
	_check("⑦ L5 채집물 은 등급 슬롯 존재", m.inventory._find_stack(SF, ItemCatalog.Q_SILVER) >= 0)

	# ⑧ 약초학자 하한 — 이리듐 고정(base 위 max, 퍼크 실효점).
	m._foraging_xp = 5500   # L10
	m._professions = {}
	m.choose_profession(F, "gatherer")
	m.choose_profession(F, "botanist")
	_check("⑧ 약초학자 forage_quality_floor = 이리듐", m.forage_quality_floor() == ItemCatalog.Q_IRIDIUM)
	m.flower.advance_day(m.clock.day + FlowerPatch.REGROW_DAYS)
	var tileB: Vector2i = m.flower.bloomed_tiles()[0]
	m._pick_flower(tileB)
	_check("⑧ 약초학자 채집물 이리듐 슬롯 존재(base 위 하한)", m.inventory._find_stack(SF, ItemCatalog.Q_IRIDIUM) >= 0)

	# ⑨ 채집꾼 2배 확률 배선 — 미선택=항상 1 / 채집꾼=확률>0.
	var m2 := await _spawn_main_fresh()
	m2._foraging_xp = 0
	m2._professions = {}
	_check("⑨ 채집꾼 미선택 → double_drop 0", is_equal_approx(m2.forage_double_drop_chance(), 0.0))
	# 미선택으로 여러 번 따도 항상 1송이(2배 확률 0 → 결정적 1).
	var always_one := true
	for _i in 8:
		if m2.flower.bloomed_count() == 0:
			break
		var tt: Vector2i = m2.flower.bloomed_tiles()[0]
		var b: int = m2.inventory.count_of(SF)
		m2._pick_flower(tt)
		if m2.inventory.count_of(SF) - b != 1:
			always_one = false
		m2.flower.advance_day(m2.clock.day + FlowerPatch.REGROW_DAYS)
	_check("⑨ 채집꾼 없이 항상 1송이", always_one)
	m2._foraging_xp = 1500   # L5
	m2.choose_profession(F, "gatherer")
	_check("⑨ 채집꾼 선택 → double_drop 0.20", is_equal_approx(m2.forage_double_drop_chance(), 0.20))

	# ⑩ main 세이브 왕복 — 딴 패치 상태 영속.
	var tileS: Vector2i = m.flower.bloomed_tiles()[0]
	m._pick_flower(tileS)
	_check("⑩ 저장 전 딴 자리 비-폄", not m.flower.is_bloomed(tileS))
	m._save_game()
	m.queue_free(); m2.queue_free()
	await process_frame
	await process_frame
	var m3 := await _spawn_main()
	_check("⑩ 복원 후 딴 자리 비-폄 영속(세이브 왕복)", not m3.flower.is_bloomed(tileS))
	m3.queue_free()
	await process_frame

	# 세이브 원복.
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# save.dat를 지운 새 main(깨끗한 기본 상태에서 시작).
func _spawn_main_fresh() -> Node:
	if FileAccess.file_exists("user://save.dat"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.dat"))
	return await _spawn_main()
