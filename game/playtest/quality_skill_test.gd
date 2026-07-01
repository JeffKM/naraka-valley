extends SceneTree

# ★ [S1-6 / greybox-spec §8] 품질 4등급 + 비료 + 농사 숙련 end-to-end 격리 검증.
#
# 무엇을 보나(§8.12 B):
#   ⑦ 비료 동사 — 경작칸 적용·overwrite(품질→성장촉진 단일필드 교체 = XOR)·미경작 거부.
#   ⑧ 밭 수확 품질 — roll_quality 유효 범위·주 수확분만 등급·다수확 추가분 Q0 강제(격리).
#   ⑨ 성장촉진 성숙 임계 축소 — effective_growth_days = ceili(base×factor)·foxfire accel 합성.
#   ⑩ 인벤토리 품질 스택 — 같은 작물 다른 품질=별 슬롯·count_of 합산·take_harvest worst-first.
#   ⑪ 출하 판매가 배수 — 이리듐 슬롯 → preview_gold = 판매가×2.0.
#   ⑫ (main) orchard 품질 실적재 — 나이 84 나무 수확 → 슬롯 quality=2(§8.8 소비).
#   ⑬ (main) 숙련 — 수확 XP 누적·energy.spend 감산(L0=10·L10=7) 실효.
#   ⑭ (main) 세이브 왕복 — farming_xp·타일 fertilizer·슬롯 quality·ship pending 품질 라운드트립 +
#      구세이브 결측 필드 Q0/"" 방어.
#
# Part A(⑦~⑪)는 노드 단위(main 불필요), Part B(⑫~⑭)만 main 스폰(orchard_test 골격).
# 좀비 방지: 끝에 quit(). run_tests 워치독. 세이브 파일은 백업/원복(shipping_bin_test 결).

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
	print("▶ quality_skill_test (S1-6)")
	var CROP := CropCatalog.HONRYEONGCHO      # base4·SINGLE·yield1
	var PODO := CropCatalog.HWANGCHEON_PODO    # base7·REGROW·yield2~3(다수확 격리 검증)
	var FB := ItemCatalog.FERT_BASIC
	var FQ := ItemCatalog.FERT_QUALITY
	var FSPEED := ItemCatalog.FERT_SPEED
	var FHYPER := ItemCatalog.FERT_HYPER

	# ── ⑦ 비료 동사(§8.4) ──
	var farm := FarmField.new()
	var t := Vector2i(3, 3)
	_check("⑦ 미경작 칸 비료 거부", not farm.fertilize(t, FQ))
	farm.hoe(t)
	_check("⑦ 경작 칸 비료 적용", farm.fertilize(t, FQ) and farm.fertilizer_of(t) == FQ)
	_check("⑦ 다른 비료 overwrite(품질→성장촉진, 단일필드 XOR)", farm.fertilize(t, FSPEED) and farm.fertilizer_of(t) == FSPEED)
	_check("⑦ 무효 비료 id 거부", not farm.fertilize(t, "garbage_fert"))
	# 심긴 칸에도 뿌릴 수 있다(심김/빈칸 무관).
	var t2 := Vector2i(4, 3)
	farm.hoe(t2)
	farm.plant(t2, CROP)
	_check("⑦ 심긴 칸에도 비료 적용", farm.fertilize(t2, FB) and farm.fertilizer_of(t2) == FB)

	# ── ⑧ 밭 수확 품질 roll(§8.5) ──
	# roll_quality 유효 범위(DELUXE·무비료 300표본).
	farm.fertilize(t, ItemCatalog.FERT_DELUXE)
	var q_ok := true
	for _i in 300:
		var q := farm.roll_quality(t)
		if q < 0 or q > 3:
			q_ok = false
	_check("⑧ roll_quality(DELUXE) 항상 0..3", q_ok)
	# 성장촉진 비료 칸은 품질 NONE 상태(품질과 별 축) — roll이 NONE 확률행을 먹는다.
	var tsp := Vector2i(5, 3)
	farm.hoe(tsp)
	farm.fertilize(tsp, FSPEED)
	_check("⑧ 성장촉진 비료 칸 = 품질 NONE 상태", FertilizerCatalog.state_of(farm.fertilizer_of(tsp)) == FertilizerCatalog.STATE_NONE)
	# 다수확 격리(§8.5) — 인벤토리 레벨 셋업(main과 동일 패턴: 첫 1개 roll 등급, 나머지 Q0).
	var inv := Inventory.new()
	inv.add_harvest(CROP, 1, 2)   # 주 수확분(금)
	inv.add_harvest(CROP, 1, 0)   # 다수확 추가분(Q0)
	inv.add_harvest(CROP, 1, 0)
	_check("⑧ 다수확 격리 — 등급 실린 개수 ≤1", _quality_bearing_count(inv, ItemCatalog.harvest_id(CROP)) == 1)
	_check("⑧ 다수확 격리 — 전량 count_of 합산(3)", inv.count_of(ItemCatalog.harvest_id(CROP)) == 3)

	# ── ⑨ 성장촉진 성숙 임계 축소(§8.6) ──
	var f2 := FarmField.new()
	var g := Vector2i(1, 1)
	f2.hoe(g)
	f2.plant(g, CROP)
	_check("⑨ 무비료 effective = base(4)", f2.effective_growth_days(g) == 4)
	f2.fertilize(g, FHYPER)   # base4 × 0.67 → ceili(2.68)=3
	_check("⑨ 하이퍼 effective = ceili(4×0.67)=3", f2.effective_growth_days(g) == 3)
	# 성장 시뮬(무 foxfire): 3일 물+취침에 성숙(2일엔 미성숙).
	f2.water(g); f2.advance_day()
	f2.water(g); f2.advance_day()
	_check("⑨ 하이퍼 2일차 미성숙", not f2.is_mature(g))
	f2.water(g); f2.advance_day()
	_check("⑨ 하이퍼 3일차 성숙(임계 축소)", f2.is_mature(g))
	# foxfire accel 합성(별 인스턴스) — accel1이면 하루 +2라 2일차에 성숙(더 빠름).
	var f3 := FarmField.new()
	var h := Vector2i(1, 1)
	f3.hoe(h); f3.plant(h, CROP); f3.fertilize(h, FHYPER)
	f3.water(h); f3.advance_day(1)   # +2 → grown 2
	_check("⑨ 하이퍼+foxfire 1일차 미성숙(grown2<3)", not f3.is_mature(h))
	f3.water(h); f3.advance_day(1)   # +2 → grown 4(cap) ≥ eff3
	_check("⑨ 하이퍼+foxfire accel 2일차 성숙(합성 가속)", f3.is_mature(h))

	# ── ⑩ 인벤토리 품질 스택(§8.3) ──
	var inv2 := Inventory.new()
	inv2.add_harvest(CROP, 2, 1)   # 은 ×2
	inv2.add_harvest(CROP, 3, 2)   # 금 ×3
	inv2.add_harvest(CROP, 1, 1)   # 은 +1 → 은 슬롯에 합쳐짐(같은 (id,quality))
	_check("⑩ 다른 품질 = 별 슬롯(은·금 2슬롯)", _slots_for(inv2, ItemCatalog.harvest_id(CROP)) == 2)
	_check("⑩ count_of 전 품질 합산(6)", inv2.count_of(ItemCatalog.harvest_id(CROP)) == 6)
	# take_harvest worst-first — 은(낮은 품질)부터 소진.
	inv2.take_harvest(CROP, 3)   # 은3 요청 → 은3 소진(은 슬롯 비고 금 유지)
	_check("⑩ take_harvest worst-first — 은부터 소진", _quality_count(inv2, ItemCatalog.harvest_id(CROP), 1) == 0 and _quality_count(inv2, ItemCatalog.harvest_id(CROP), 2) == 3)

	# ── ⑪ 출하 판매가 품질 배수(§8.7) ──
	var bin := ShippingBin.new()
	bin.add(CROP, 1, ItemCatalog.Q_IRIDIUM)   # 이리듐 ×2.0
	var base_price := CropCatalog.sell_price(CROP)
	_check("⑪ 이리듐 슬롯 preview_gold = 판매가×2.0", bin.preview_gold() == int(base_price * 2.0))
	bin.add(CROP, 1, ItemCatalog.Q_NORMAL)    # 일반 ×1.0 추가
	_check("⑪ 혼합 품질 합산 정산", bin.preview_gold() == int(base_price * 2.0) + base_price)
	_check("⑪ count_of 전 품질 합(2)", bin.count_of(CROP) == 2)
	bin.free()

	# ── Part B: main 스폰(⑫~⑭) ──
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.qs_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m := await _spawn_main()
	var HB := FruitTreeCatalog.HONBAEKDO

	# ── ⑬ 숙련: energy 감산 계수(결정적) ──
	m._farming_xp = 0
	_check("⑬ L0 농사 비용 = 10(기본)", m._farming_energy_cost() == 10)
	m._farming_xp = 5500   # L10
	_check("⑬ L10 농사 비용 = 7(30% 감산)", m._farming_energy_cost() == 7)
	# 밭 수확으로 XP 누적 + energy.spend 감산 실효(강제 성숙 셋업).
	var ht := _free_home_soil(m)
	_check("⑬ 안식 농원 빈 밭칸 확보", ht.x >= 0)
	m.farm.hoe(ht)
	m.farm.plant(ht, CROP)
	m.farm._tiles[ht]["grown_days"] = 99   # 강제 성숙(테스트 셋업)
	m._farming_xp = 5500                    # L10 유지(비용7)
	m._target = ht
	var e_before: int = m.energy.current
	var xp_before: int = m._farming_xp
	m._try_harvest()
	_check("⑬ 수확 XP 누적(+base 판매가)", m._farming_xp == xp_before + CropCatalog.sell_price(CROP))
	_check("⑬ energy.spend L10 감산 소모(−7)", m.energy.current == e_before - 7)
	_check("⑬ 수확물 인벤토리 적재", m.inventory.count_of(ItemCatalog.harvest_id(CROP)) >= 1)

	# ── ⑫ orchard 품질 실적재(§8.8) — 나이 84 나무 → 슬롯 quality=2 ──
	var anchor := _free_home_anchor(m)
	_check("⑫ 안식 농원 유효 3×3 앵커 확보", anchor.x >= 0)
	# 나이 84로 백데이트(planted_day = day−84) + 제철(피안·day1 season0) → 성숙+결실.
	m.orchard.plant(anchor, HB, m.clock.day - 84, m._is_tree_blocked)
	m.orchard.advance_day(m.clock.day)   # 제철 → fruit_count 1
	_check("⑫ 나무 성숙+결실(count≥1)", m.orchard.is_mature(anchor, m.clock.day) and m.orchard.fruit_count_of(anchor) >= 1)
	var fruit_before: int = m.inventory.count_of(HB)
	m._target = anchor
	m.energy.current = m.energy.MAX   # 앞 수확으로 준 혼력 보충(수확 게이트 방어)
	m._try_harvest()
	_check("⑫ 과일 인벤토리 적재", m.inventory.count_of(HB) > fruit_before)
	_check("⑫ 슬롯 quality = 나이84 등급(2=금)", _quality_count(m.inventory, HB, 2) >= 1)

	# ── ⑭ 세이브 왕복(§8.11) — farming_xp·타일 fertilizer·슬롯 quality·ship pending 품질 ──
	var st := _free_home_soil(m)
	m.farm.hoe(st)
	m.farm.fertilize(st, FQ)                        # 타일 fertilizer
	m.inventory.add_harvest(PODO, 2, ItemCatalog.Q_GOLD)   # 슬롯 quality(금 포도)
	m.ship_bin.pending.clear()
	m.ship_bin.add(PODO, 1, ItemCatalog.Q_IRIDIUM)  # ship pending 품질
	m._farming_xp = 1234
	m._save_game()
	m.queue_free()
	await process_frame
	await process_frame
	var m2 := await _spawn_main()
	_check("⑭ farming_xp 라운드트립(1234)", m2._farming_xp == 1234)
	_check("⑭ 타일 fertilizer 라운드트립", m2.farm.fertilizer_of(st) == FQ)
	_check("⑭ 슬롯 quality 라운드트립(금 포도)", _quality_count(m2.inventory, ItemCatalog.harvest_id(PODO), ItemCatalog.Q_GOLD) == 2)
	_check("⑭ ship pending 품질 라운드트립(이리듐)", m2.ship_bin.count_of_quality(PODO, ItemCatalog.Q_IRIDIUM) == 1)

	# 구세이브 결측 필드 방어 — farming_xp 없는 세이브·flat pending·fertilizer 없는 타일.
	var legacy_bin := ShippingBin.new()
	legacy_bin.load_save({"pending": {PODO: 4}})   # 구형 flat {id:int}
	_check("⑭ 구세이브 flat pending → 품질0 방어", legacy_bin.count_of_quality(PODO, 0) == 4 and legacy_bin.count_of(PODO) == 4)
	legacy_bin.free()
	var legacy_field := FarmField.new()
	legacy_field.load_save({"tiles": {Vector2i(2, 2): {"planted": false, "watered": false, "crop": "", "grown_days": 0}}})
	_check("⑭ 구세이브 타일(fertilizer 결측) → \"\" 방어", legacy_field.fertilizer_of(Vector2i(2, 2)) == "")
	legacy_field.free()
	var legacy_inv := Inventory.new()
	legacy_inv.load_save({"slots": [{"id": ItemCatalog.harvest_id(CROP), "count": 3}]})   # quality 결측
	_check("⑭ 구세이브 슬롯(quality 결측) → Q0 방어", legacy_inv.quality_at(0) == 0 and legacy_inv.count_of(ItemCatalog.harvest_id(CROP)) == 3)
	legacy_inv.free()

	m2.queue_free()
	await process_frame

	# 세이브 원복.
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── 헬퍼 ────────────────────────────────────────────────────────────────────
# 인벤토리에서 id의 슬롯 중 품질>0인 슬롯의 개수 총합(다수확 격리 = ≤1).
func _quality_bearing_count(inv: Inventory, id: String) -> int:
	var sum := 0
	for i in Inventory.SIZE:
		if inv.id_at(i) == id and inv.quality_at(i) > 0:
			sum += inv.count_at(i)
	return sum

# 인벤토리에서 id를 든 슬롯 수(품질별 분리 슬롯 카운트).
func _slots_for(inv: Inventory, id: String) -> int:
	var n := 0
	for i in Inventory.SIZE:
		if inv.id_at(i) == id:
			n += 1
	return n

# 인벤토리에서 (id, quality) 정확 일치 개수 합.
func _quality_count(inv: Inventory, id: String, quality: int) -> int:
	var sum := 0
	for i in Inventory.SIZE:
		if inv.id_at(i) == id and inv.quality_at(i) == quality:
			sum += inv.count_at(i)
	return sum

# 안식 농원에서 심을 수 있는 빈 밭칸 1개(-1,-1 = 없음). 강제 성숙 셋업용.
func _free_home_soil(m: Node) -> Vector2i:
	for y in range(1, m._grid_h - 1):
		for x in range(1, m._grid_w - 1):
			var tile := Vector2i(x, y)
			if not m.farm.is_tilled(tile) and not m._is_tree_blocked(tile):
				return tile
	return Vector2i(-1, -1)

# 안식 농원에서 유효 3×3 나무 앵커 1개(-1,-1 = 없음).
func _free_home_anchor(m: Node) -> Vector2i:
	for y in range(2, m._grid_h - 2):
		for x in range(2, m._grid_w - 2):
			var ok := true
			for tile in Orchard.footprint_of(Vector2i(x, y)):
				if m._is_tree_blocked(tile) or m.farm.is_tilled(tile):
					ok = false
					break
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)
