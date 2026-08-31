extends SceneTree
# ★[S10-T1 / ADR-0069 결정 2] 팬닝(사금) + 결정기 검증(ephemeral).
#
# 무엇을 지키나(어기면 ADR-0069 결정 2 위반):
#   ① 아이템·레시피 등재 — 결정기 부품(재료)·결정기(설치물)·제작 레시피(부품 3) · id 교집합 0
#   ② 스폰 결정성 — 같은 day 재현 · 다른 day 변화 · 구역당 0~2 · 존 밖 0 · 삼도천/황천해 한정
#   ③ 산출 — 표 무결성 · **오색혼옥 부재**(ADR-0063 초희귀 지위) · 롤 결정성 · 스폿 소진
#   ④ 혼력 과금 — 잉 때 PAN_ENERGY 차감 · 혼력 부족이면 스폿을 소모하지 않는다
#   ⑤ 결정기 — 설치 · 투입 · 일수 경과 · 수거 후 **재가동** · 안 비우면 정지 · 회수 시 보석 반환
#   ⑥ 오색혼옥 거부 — days_for 0 · can_duplicate false · 목록 미포함 · load_gem 거절
#   ⑦ 세이브 왕복 — 두 원장 · 하위호환(키 없는 구세이브) · 손상 방어
#   ⑧ 존 실그리드 — 삼도천·황천해 후보 칸 전량이 걸을 수 있고 **물가**(main._is_waterside 일치)
# 실행: godot --headless --path game --script res://playtest/panning_test.gd

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

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 원장 상태를 문자열 지문으로(결정성 비교용 — forage_spawn_test의 같은 헬퍼 결).
func _fingerprint(led: PanningSpots) -> String:
	var rows: Array = []
	for region: String in PanningSpots.spawn_regions():
		for t: Vector2i in led.tiles(region):
			rows.append("%s:%d,%d" % [region, t.x, t.y])
	rows.sort()
	return "|".join(rows)

# 이 칸이 실그리드에서 걸을 수 있는가(막힌 지형 = false).
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return not m.is_solid(id)

# 결정기를 놓을 수 있는 첫 칸(없으면 (-1,-1)) — furnace_test._placeable_tile 결.
func _placeable_tile(m: Node) -> Vector2i:
	for y in range(2, m._outdoor_h - 2):
		for x in range(2, m._grid_w - 2):
			var t := Vector2i(x, y)
			if m._can_place_crystalarium(t):
				return t
	return Vector2i(-1, -1)

func _initialize() -> void:
	print("══ S10-T1 팬닝(사금) + 결정기 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s10t1_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 아이템·레시피 등재 ──
	print("── ① 아이템 등재 · 제작 레시피 ──")
	var part := ItemCatalog.CRYSTALARIUM_PART
	var unit := ItemCatalog.CRYSTALARIUM
	_check("①a 결정기 부품 = 유효 CAT_MATERIAL 스택 아이템(이름 있음·값 > 0)",
		ItemCatalog.has_item(part) and ItemCatalog.category_of(part) == ItemCatalog.CAT_MATERIAL
		and ItemCatalog.stackable_of(part) and ItemCatalog.name_of(part) != ""
		and ItemCatalog.price_of(part) > 0)
	_check("①b 결정기 = 유효 CAT_PLACEABLE 스택 설치물(이름 있음)",
		ItemCatalog.has_item(unit) and ItemCatalog.category_of(unit) == ItemCatalog.CAT_PLACEABLE
		and ItemCatalog.stackable_of(unit) and ItemCatalog.name_of(unit) != "")
	# id 교집합 0 — 광물·주괴·설치물 표와 겹치지 않는다(has_item 판정이 다른 표로 새지 않게).
	var overlap := false
	for id: String in ItemCatalog.MINE_DEVICES:
		if ItemCatalog.MINERALS.has(id) or ItemCatalog.INGOTS.has(id) \
				or ItemCatalog.PLACEABLES.has(id) or ItemCatalog.MATERIALS.has(id):
			overlap = true
	_check("①c 신규 id가 기존 표(광물·주괴·설치물·자재)와 교집합 0", not overlap)
	# 카테고리 열거에 잡힌다(곳간·UI 창구가 이 파생을 읽는다).
	_check("①d ids_in_category 파생에 둘 다 잡힘",
		ItemCatalog.ids_in_category(ItemCatalog.CAT_MATERIAL).has(part)
		and ItemCatalog.ids_in_category(ItemCatalog.CAT_PLACEABLE).has(unit))
	var recipe: Dictionary = CraftCatalog.get_recipe(CraftCatalog.CRYSTALARIUM)
	var mats: Array = recipe.get("mats", [])
	_check("①e 제작 레시피 = 부품 %d개 → 결정기 1대(수치는 원장 상수 파생)"
			% CrystalariumLedger.PARTS_PER_UNIT,
		String(recipe.get("out_item", "")) == unit and int(recipe.get("out_count", 0)) == 1
		and mats.size() == 1 and String(mats[0]["item"]) == part
		and int(mats[0]["count"]) == CrystalariumLedger.PARTS_PER_UNIT)
	_check("①f 레시피가 제작 탭 목록에 노출(상시 — unlock_level 0)",
		CraftCatalog.ids().has(CraftCatalog.CRYSTALARIUM)
		and CraftCatalog.unlocked(CraftCatalog.CRYSTALARIUM, 0, {}, 0))

	# ── ② 스폰 결정성 ──
	print("── ② 스폰 결정성 · 구역 한정 · 상한 ──")
	_check("②a 스폿 구역 = 삼도천·황천해 **둘뿐**(ADR 결정 2 '한정')",
		PanningSpots.spawn_regions().size() == 2
		and PanningSpots.spawn_regions().has(RegionCatalog.SAMDOCHEON)
		and PanningSpots.spawn_regions().has(RegionCatalog.HWANGCHEONHAE))
	var a := PanningSpots.new()
	var b := PanningSpots.new()
	a.advance_day(7)
	b.advance_day(7)
	_check("②b 같은 day = 같은 판(결정적 — 전역 randf 0)", _fingerprint(a) == _fingerprint(b))
	a.advance_day(7)
	_check("②c 같은 day를 두 번 굴려도 판이 안 흔들린다(멱등)", _fingerprint(a) == _fingerprint(b))
	# 다른 날엔 판이 바뀐다 — 1년(28×4일)을 훑어 서로 다른 지문이 여럿 나오는지 본다.
	var seen := {}
	var over_cap := 0
	var outside := 0
	var zero_days := 0
	for day in range(1, 113):
		var led := PanningSpots.new()
		led.advance_day(day)
		seen[_fingerprint(led)] = true
		if led.total() == 0:
			zero_days += 1
		for region: String in PanningSpots.spawn_regions():
			if led.count(region) > PanningSpots.SPOT_MAX:
				over_cap += 1
			for t: Vector2i in led.tiles(region):
				if not PanningSpots.in_zone(region, t):
					outside += 1
	_check("②d 1년 112일에 서로 다른 판이 여럿(날마다 자리가 옮겨간다)", seen.size() > 50)
	_check("②e 구역당 상한 %d 초과 0" % PanningSpots.SPOT_MAX, over_cap == 0)
	_check("②f 존 밖 스폰 0(1년 전량)", outside == 0)
	_check("②g '0개인 날'이 실존한다(구역당 0~2의 0 — 매일 보장이 아니다)", zero_days > 0)
	# 자리 중복 0 — 한 구역의 스폿 좌표가 서로 다르다(뽑은 칸을 후보에서 뺀다).
	var dup := 0
	for day in range(1, 113):
		var led2 := PanningSpots.new()
		led2.advance_day(day)
		for region: String in PanningSpots.spawn_regions():
			var uniq := {}
			for t: Vector2i in led2.tiles(region):
				uniq[t] = true
			if uniq.size() != led2.count(region):
				dup += 1
	_check("②h 같은 날 같은 칸에 두 스폿 0", dup == 0)

	# ── ③ 산출표 ──
	print("── ③ 산출표 · 롤 결정성 ──")
	var table: Array = PanningSpots.yield_table()
	var w_sum := 0
	var rows_ok := true
	var has_gem := false
	for row in table:
		w_sum += int(row["weight"])
		var rid := String(row["id"])
		if rid == "":
			if int(row["gold"]) <= 0:
				rows_ok = false          # 빈 id 행은 반드시 냥 행이다
		elif not ItemCatalog.has_item(rid) or int(row["count"]) <= 0:
			rows_ok = false
		if rid != "" and rid.begins_with("gem_"):
			has_gem = true
	_check("③a 표 무결성 — 전 행이 유효 아이템(또는 냥 행) · 가중 합 > 0", rows_ok and w_sum > 0)
	_check("③b 보석 행 실존 · 결정기 부품 행 실존(ADR 결정 2 산출 구성)", has_gem
		and table.any(func(r: Dictionary) -> bool: return String(r["id"]) == part))
	# ⚠️ 오색혼옥 부재 — 초희귀는 *들어오는 길*도 좁아야 한다(ADR-0063 결정 2).
	var osaek_in_table := false
	for row in table:
		if String(row["id"]) == ItemCatalog.GEM_OSAEK_HONOK:
			osaek_in_table = true
	_check("③c ⚠️ 오색혼옥이 산출표에 없다(ADR-0063 초희귀 지위 보존)", not osaek_in_table)
	# 롤 결정성 — 같은 day·같은 칸이면 같은 답(세이브 되감기 재롤 차단).
	# 프로브 = "스폿이 하나라도 있는 첫 날"의 첫 자리(어느 날이 그런 날인지는 해시가 정한다).
	var seed_led := PanningSpots.new()
	var probe_region := ""
	var probe_tile := Vector2i(-1, -1)
	var probe_day := 0
	for day in range(1, 200):
		var led3 := PanningSpots.new()
		led3.advance_day(day)
		for region: String in PanningSpots.spawn_regions():
			if led3.count(region) > 0:
				probe_region = region
				probe_tile = led3.tiles(region)[0]
				probe_day = day
				seed_led = led3
				break
		if probe_day > 0:
			break
	_check("③d 스폿이 있는 날을 찾았다(프로브 준비)", probe_day > 0)
	var r1: Dictionary = seed_led.pan(probe_day, probe_region, probe_tile)
	var led5 := PanningSpots.new()
	led5.advance_day(probe_day)
	var r2: Dictionary = led5.pan(probe_day, probe_region, probe_tile)
	_check("③e 같은 day·같은 칸 = 같은 산출(재롤 exploit 차단)",
		not r1.is_empty() and r1 == r2)
	_check("③f 인 자리는 소진된다(같은 날 두 번 못 인다)",
		not seed_led.has_at(probe_region, probe_tile)
		and seed_led.pan(probe_day, probe_region, probe_tile).is_empty())
	# 표 전량이 실제로 뽑힌다(가중 추첨이 특정 행에 갇히지 않는다).
	var drawn := {}
	for i in 4000:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		drawn[String(PanningSpots._pick(table, rng)["id"])] = true
	_check("③g 4000회 추첨에 표 %d행 전부 등장(가중 추첨 건전성)" % table.size(),
		drawn.size() == table.size())

	# ── ⑥ 결정기 규칙(오색혼옥 거부 포함) ──
	print("── ⑥ 결정기 규칙 · 오색혼옥 거부 ──")
	var gems: Array[String] = CrystalariumLedger.duplicable_gems()
	var days_ok := true
	for g: String in gems:
		if CrystalariumLedger.days_for(g) <= 0 or not CrystalariumLedger.can_duplicate(g) \
				or not ItemCatalog.has_item(g):
			days_ok = false
	_check("⑥a 복제 가능 보석 전량이 유효 아이템 + 일수 > 0", days_ok and gems.size() > 0)
	_check("⑥b ⚠️ 오색혼옥 복제 불가 — days_for 0 · can_duplicate false · 목록 미포함",
		CrystalariumLedger.days_for(ItemCatalog.GEM_OSAEK_HONOK) == 0
		and not CrystalariumLedger.can_duplicate(ItemCatalog.GEM_OSAEK_HONOK)
		and not gems.has(ItemCatalog.GEM_OSAEK_HONOK))
	_check("⑥c 보석 아닌 것(광석·주괴)도 복제 불가",
		not CrystalariumLedger.can_duplicate(ItemCatalog.ORE_MYEONGDONG)
		and not CrystalariumLedger.can_duplicate(ItemCatalog.INGOT_NARAKCHEOL)
		and not CrystalariumLedger.can_duplicate(""))
	# 일수 사다리 = 값이 비쌀수록 오래(경제 가드 — 값싼 보석이 시간까지 짧아 지배하지 않게).
	var ladder_ok := true
	for i in range(1, gems.size()):
		if CrystalariumLedger.days_for(gems[i]) < CrystalariumLedger.days_for(gems[i - 1]) \
				or ItemCatalog.price_of(gems[i]) <= ItemCatalog.price_of(gems[i - 1]):
			ladder_ok = false
	_check("⑥d 일수 사다리가 가격 사다리와 같은 방향(경제 가드)", ladder_ok)

	# ── ⑤ 결정기 사이클(원장 순수) ──
	print("── ⑤ 결정기 사이클(투입 · 일수 · 수거 · 재가동 · 회수) ──")
	var cl := CrystalariumLedger.new()
	var ct := Vector2i(4, 4)
	_check("⑤a 설치 = 빈 기계 1대(같은 칸 중복 설치 거부)",
		cl.place("r", ct) and not cl.place("r", ct) and cl.count() == 1 and cl.is_idle("r", ct))
	var gem := ItemCatalog.GEM_MYEONGOK
	_check("⑤b ⚠️ 오색혼옥 투입 거절 — 기계는 빈 채 그대로",
		not cl.load_gem("r", ct, ItemCatalog.GEM_OSAEK_HONOK) and cl.is_idle("r", ct))
	_check("⑤c 명옥 투입 = %d일 카운트다운 시작" % CrystalariumLedger.days_for(gem),
		cl.load_gem("r", ct, gem)
		and cl.days_left("r", ct) == CrystalariumLedger.days_for(gem)
		and cl.is_growing("r", ct))
	_check("⑤d 이미 든 기계엔 다른 보석을 못 넣는다",
		not cl.load_gem("r", ct, ItemCatalog.GEM_NEOKSUJEONG)
		and cl.gem_at("r", ct) == gem)
	var days := CrystalariumLedger.days_for(gem)
	var done: Array = []
	for i in days:
		done = cl.advance_day()
	_check("⑤e %d일 뒤 수거 대기(다 여물었다)" % days,
		cl.is_ready("r", ct) and done.size() == 1 and String(done[0]["id"]) == gem)
	var idle_run: Array = cl.advance_day()
	_check("⑤f 안 비우면 카운트다운 정지(방치 = 손실 아니라 정지)",
		idle_run.is_empty() and cl.is_ready("r", ct))
	_check("⑤g 수거 = 복제본 1개 반환 + **같은 보석으로 즉시 재가동**",
		cl.collect("r", ct) == gem and cl.is_growing("r", ct)
		and cl.days_left("r", ct) == days and cl.gem_at("r", ct) == gem)
	_check("⑤h 수거 대기가 아닐 때만 다시 수거 가능(빈 수거 = \"\")", cl.collect("r", ct) == "")
	# 회수 — 수거 대기면 거절, 복제 중이면 보석을 돌려준다.
	for i in days:
		cl.advance_day()
	_check("⑤i 수거 대기 상태에선 회수 거절(복제본 증발 방지)", cl.remove("r", ct).is_empty())
	cl.collect("r", ct)
	var taken: Dictionary = cl.remove("r", ct)
	_check("⑤j 복제 중 회수 = 안의 보석 반환 · 원장에서 사라짐(재산 손실 0)",
		String(taken.get("gem", "")) == gem and cl.count() == 0)
	var cl2 := CrystalariumLedger.new()
	cl2.place("r", ct)
	_check("⑤k 빈 기계 회수 = 보석 없음(\"\")로 성공",
		String(cl2.remove("r", ct).get("gem", "x")) == "" and cl2.count() == 0)

	# ── ⑦ 세이브 왕복 · 하위호환 · 손상 방어 ──
	print("── ⑦ 세이브 왕복 ──")
	var ps := PanningSpots.new()
	ps.advance_day(probe_day)
	var ps_fp := _fingerprint(ps)
	var ps2 := PanningSpots.new()
	ps2.load_save(ps.to_save())
	_check("⑦a 팬닝 왕복 — 좌표 전량 보존", _fingerprint(ps2) == ps_fp)
	var ps3 := PanningSpots.new()
	ps3.load_save({})
	_check("⑦b 팬닝 하위호환 — 키 없는 구세이브 = 스폿 0", ps3.total() == 0)
	var ps4 := PanningSpots.new()
	ps4.load_save({"spots": {RegionCatalog.SAMDOCHEON: [[0, 0], [99, 99]]}})
	_check("⑦c 팬닝 손상 방어 — 존 밖 좌표는 버린다", ps4.total() == 0)
	var cl3 := CrystalariumLedger.new()
	cl3.place("r", ct)
	cl3.load_gem("r", ct, ItemCatalog.GEM_YEOMJUSEOK)
	cl3.advance_day()
	var left_before: int = cl3.days_left("r", ct)
	var cl4 := CrystalariumLedger.new()
	cl4.load_save(cl3.to_save())
	_check("⑦d 결정기 왕복 — 좌표·보석·남은 일수 보존",
		cl4.has_at("r", ct) and cl4.gem_at("r", ct) == ItemCatalog.GEM_YEOMJUSEOK
		and cl4.days_left("r", ct) == left_before)
	var cl5 := CrystalariumLedger.new()
	cl5.place("r", ct)
	cl5.load_save({})
	_check("⑦e 결정기 하위호환 — 키 없는 구세이브 = 결정기 0", cl5.count() == 0)
	var cl6 := CrystalariumLedger.new()
	cl6.load_save({"units": {"r": [[2, 2, ItemCatalog.GEM_OSAEK_HONOK, 999]]}})
	_check("⑦f 결정기 손상 방어 — 기계는 살고 복제 불가 보석만 비운다(설치물 손실 0)",
		cl6.count() == 1 and cl6.is_idle("r", Vector2i(2, 2)))

	# ── 라이브 배선(main) ──
	print("── ④⑧ 라이브 배선(존 실그리드 · 혼력 과금 · 설치) ──")
	var m: Node = await _spawn_main()
	_check("⓪ 두 원장 배선(RefCounted)", m.panning != null and m.crystalarium != null)
	m._indoor = ""

	# ⑧ 존 실그리드 — 삼도천·황천해 후보 칸이 전부 걷을 수 있고 **물가**다.
	for region: String in PanningSpots.spawn_regions():
		m._rebuild_region(region)
		var blocked := 0
		var dry := 0
		var cands: Array = PanningSpots.candidates(region)
		for t: Vector2i in cands:
			if not _walkable(m, t):
				blocked += 1
			elif not m._is_waterside(t):
				dry += 1
		_check("⑧ %s 존 %d칸 전부 걸을 수 있음 · 전부 물가(_is_waterside 일치)"
			% [region, cands.size()], cands.size() > 0 and blocked == 0 and dry == 0)

	# ④ 혼력 과금 — 삼도천 스폿 하나를 심어 놓고 [F] 배선을 태운다.
	m._rebuild_region(RegionCatalog.SAMDOCHEON)
	var spot: Vector2i = PanningSpots.candidates(RegionCatalog.SAMDOCHEON)[0]
	m.panning.load_save({"spots": {RegionCatalog.SAMDOCHEON: [[spot.x, spot.y]]}})
	m.energy.current = 1                       # PAN_ENERGY 미만
	m._pan_spot(spot)
	_check("④a 혼력 부족이면 **스폿을 소모하지 않는다**(조용한 손실 0)",
		m.panning.has_at(RegionCatalog.SAMDOCHEON, spot) and m.energy.current == 1)
	m.energy.current = SoulEnergy.MAX
	var gold0: int = m.wallet.gold
	m._pan_spot(spot)
	_check("④b [F] 채취 = 혼력 %d 차감 · 스폿 소진" % PanningSpots.PAN_ENERGY,
		m.energy.current == SoulEnergy.MAX - PanningSpots.PAN_ENERGY
		and not m.panning.has_at(RegionCatalog.SAMDOCHEON, spot))
	# 산출이 실제로 손에 들어왔다(냥이 늘었거나 아이템이 늘었거나 — 표가 둘 중 하나를 준다).
	var expect: Dictionary = PanningSpots._pick(PanningSpots.yield_table(),
		_seeded_rng(m.clock.day, RegionCatalog.SAMDOCHEON, spot))
	var got_gold: int = int(m.wallet.gold) - gold0
	var got_item: bool = true
	if String(expect["id"]) != "":
		got_item = int(m.inventory.count_of(String(expect["id"]))) > 0
	_check("④c 산출이 지갑·가방에 얹혔다(원장이 정한 그 한 건)",
		(int(expect["gold"]) == 0 or got_gold == int(expect["gold"])) and got_item)
	_check("④d 이미 인 자리에 다시 [F] = 무동작(혼력 소모 0)", _no_op_pan(m, spot))
	m.panning.load_save({"spots": {}})

	# 결정기 라이브 — 설치·투입·수거·회수.
	m._rebuild_region(RegionCatalog.HOME)
	var slot := _placeable_tile(m)
	_check("⑤l 설치 가능 칸이 존재(빈 지면·길)", slot != Vector2i(-1, -1))
	m.inventory.add_item(ItemCatalog.CRYSTALARIUM, 1)
	m._place_crystalarium(slot)
	_check("⑤m 설치 = 원장 1대 + 아이템 1개 소모",
		m.crystalarium.has_at(m._region, slot)
		and m.inventory.count_of(ItemCatalog.CRYSTALARIUM) == 0)
	_check("⑤n 같은 칸엔 두 번 못 놓는다 · 업화로도 못 놓는다(설치물 상호 배제)",
		not m._can_place_crystalarium(slot) and not m._can_place_furnace(slot))
	# 투입 — 오색혼옥은 거절, 명옥은 통과.
	m.inventory.add_item(ItemCatalog.GEM_OSAEK_HONOK, 1)
	var osaek_slot := -1
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == ItemCatalog.GEM_OSAEK_HONOK:
			osaek_slot = i
	m.inventory.select(osaek_slot)
	m._use_crystalarium(slot)
	_check("⑤o ⚠️ 오색혼옥을 들고 [F] = 투입 안 됨(보석 소모 0 · 프롬프트가 사유를 밝힌다)",
		m.crystalarium.is_idle(m._region, slot)
		and m.inventory.count_of(ItemCatalog.GEM_OSAEK_HONOK) == 1
		and m._crystalarium_prompt(slot).contains("오색혼옥"))
	m.inventory.add_item(ItemCatalog.GEM_NEOKSUJEONG, 2)
	var gem_slot := -1
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == ItemCatalog.GEM_NEOKSUJEONG:
			gem_slot = i
	m.inventory.select(gem_slot)
	m._use_crystalarium(slot)
	_check("⑤p 넋수정 투입 = 보석 1개 차감 · %d일 카운트다운"
			% CrystalariumLedger.days_for(ItemCatalog.GEM_NEOKSUJEONG),
		m.crystalarium.is_growing(m._region, slot)
		and m.inventory.count_of(ItemCatalog.GEM_NEOKSUJEONG) == 1
		and m.crystalarium.days_left(m._region, slot)
			== CrystalariumLedger.days_for(ItemCatalog.GEM_NEOKSUJEONG))
	for i in CrystalariumLedger.days_for(ItemCatalog.GEM_NEOKSUJEONG):
		m.crystalarium.advance_day()
	var gem_before: int = m.inventory.count_of(ItemCatalog.GEM_NEOKSUJEONG)
	m._use_crystalarium(slot)
	_check("⑤q [F] 수거 = 넋수정 +1(복제본) · 기계는 같은 보석으로 재가동",
		m.inventory.count_of(ItemCatalog.GEM_NEOKSUJEONG) == gem_before + 1
		and m.crystalarium.is_growing(m._region, slot))
	# 회수 — 맨손(보석 아닌 것)으로 [F].
	m.inventory.select(0)
	if ItemCatalog._is_mine_device(m.inventory.selected_id()) \
			or CrystalariumLedger.can_duplicate(m.inventory.selected_id()):
		m.inventory.select(1)
	var unit_before: int = m.inventory.count_of(ItemCatalog.CRYSTALARIUM)
	var gem_before2: int = m.inventory.count_of(ItemCatalog.GEM_NEOKSUJEONG)
	m._use_crystalarium(slot)
	_check("⑤r [F] 회수 = 결정기 +1 **그리고 안의 넋수정도 +1**(재산 손실 0)",
		m.inventory.count_of(ItemCatalog.CRYSTALARIUM) == unit_before + 1
		and m.inventory.count_of(ItemCatalog.GEM_NEOKSUJEONG) == gem_before2 + 1
		and not m.crystalarium.has_at(m._region, slot))

	# 취침 훅 배선 — 하루가 가면 두 원장이 함께 굴러간다.
	print("── ⑨ 취침 훅 배선 ──")
	m.inventory.add_item(ItemCatalog.CRYSTALARIUM, 1)
	m._place_crystalarium(slot)
	m.crystalarium.load_gem(m._region, slot, ItemCatalog.GEM_NEOKSUJEONG)
	var left0: int = m.crystalarium.days_left(m._region, slot)
	var day0: int = m.clock.day
	m._on_day_advanced(day0 + 1)
	_check("⑨a 하루 훅 = 결정기 남은 일수 −1",
		m.crystalarium.days_left(m._region, slot) == left0 - 1)
	var pan_day := PanningSpots.new()
	pan_day.advance_day(day0 + 1)
	_check("⑨b 하루 훅 = 팬닝 판이 그날 것으로 갈린다(원장 파생과 일치)",
		_fingerprint(m.panning) == _fingerprint(pan_day))
	# 재부팅 왕복(main 통째) — 두 슬라이스 키가 세이브를 타고 살아 돌아온다.
	var live_left: int = m.crystalarium.days_left(m._region, slot)
	var live_gem: String = m.crystalarium.gem_at(m._region, slot)
	var live_pan := _fingerprint(m.panning)
	m._save_game()
	await _despawn(m)
	var m2: Node = await _spawn_main()
	_check("⑨c 재부팅 후 결정기 복원 — 좌표·보석·남은 일수",
		m2.crystalarium.has_at(RegionCatalog.HOME, slot)
		and m2.crystalarium.gem_at(RegionCatalog.HOME, slot) == live_gem
		and m2.crystalarium.days_left(RegionCatalog.HOME, slot) == live_left)
	_check("⑨d 재부팅 후 팬닝 스폿 복원(그날 판 그대로)",
		_fingerprint(m2.panning) == live_pan)
	await _despawn(m2)

	await _part_r2()

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)

# 산출 롤 시드 재현(원장 pan()과 같은 문자열 — 단언이 "무엇이 나와야 하나"를 직접 계산한다).
func _seeded_rng(day: int, region: String, t: Vector2i) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("panning:yield:%d:%s:%d:%d" % [day, region, t.x, t.y])
	return rng

# 이미 인 자리에 [F]를 한 번 더 — 혼력이 안 닳아야 한다(무동작).
func _no_op_pan(m: Node, t: Vector2i) -> bool:
	var e0: int = m.energy.current
	m._pan_spot(t)
	return m.energy.current == e0

# ══ [폴리시 R2] 팬닝 산출 소실 · 결정기 회수 롤백 ═════════════════════════════
#   ⑩ 백팩이 가득하면 **스폿을 소진하지 않는다**(스폿은 하루 한 자리씩만 깔려 되찾을 길이 없다).
#   ⑪ 결정기 회수는 안에 든 보석까지 담을 자리가 있어야 성립한다(빈 칸 1개짜리 함정).
func _part_r2() -> void:
	print("── ⑩⑪ [폴리시 R2] 팬닝 산출 · 결정기 안의 보석 ──")
	var m: Node = await _spawn_main()

	# ── ⑩ 팬닝 ──
	# 산출이 **아이템**인 스폿을 찾는다(금화만 나오는 자리는 이 결함의 무대가 아니다).
	var region := ""
	var spot := Vector2i(-1, -1)
	for r: String in PanningSpots.spawn_regions():
		for t: Vector2i in m.panning.tiles(r):
			var row: Dictionary = m.panning.peek(m.clock.day, r, t)
			if String(row.get("id", "")) != "" and int(row.get("count", 0)) > 0:
				region = r
				spot = t
				break
		if spot != Vector2i(-1, -1):
			break
	_check("⑩pre 아이템 산출 스폿 확보", spot != Vector2i(-1, -1))
	var row0: Dictionary = m.panning.peek(m.clock.day, region, spot)
	var yid := String(row0["id"])
	_check("⑩a peek는 원장을 안 건드린다(같은 답을 두 번 준다)",
		m.panning.has_at(region, spot)
		and String(m.panning.peek(m.clock.day, region, spot)["id"]) == yid)
	m._region = region
	m._indoor = ""
	_fill_backpack_full(m.inventory)
	var e0: int = m.energy.current
	m._pan_spot(spot)
	_check("⑩b **스폿이 그대로 남는다** — 혼력도 안 닳고 산출도 안 사라진다",
		m.panning.has_at(region, spot) and m.energy.current == e0
		and m.inventory.count_of(yid) == 0)
	_fill_backpack_full(m.inventory, [0])   # 자리를 하나 비운다
	m._pan_spot(spot)
	_check("⑩c 자리를 비우면 그때 성립 — 같은 산출이 그대로 들어온다(롤 결정적)",
		not m.panning.has_at(region, spot) and m.inventory.count_of(yid) == int(row0["count"])
		and m.energy.current == e0 - PanningSpots.PAN_ENERGY)

	# ── ⑪ 결정기 회수 — 빈 칸이 정확히 1개일 때 ──
	await _despawn(m)
	var m3: Node = await _spawn_main()
	var slot := _placeable_tile(m3)
	_check("⑪pre 결정기 설치 칸 확보", slot != Vector2i(-1, -1))
	var gem := ItemCatalog.GEM_MYEONGBU_GEUMGANG
	m3.crystalarium.place(m3._region, slot)
	m3.crystalarium.load_gem(m3._region, slot, gem)
	_check("⑪pre2 보석이 들어가 복제 진행 중", m3.crystalarium.gem_at(m3._region, slot) == gem)
	_fill_backpack_full(m3.inventory, [0])   # ★ 빈 칸이 정확히 하나 — 기계가 그 칸을 먹으면 보석이 갈 곳이 없다
	m3._target = slot
	m3.inventory.select(1)            # 든 것은 보석이 아니다 → 회수 갈래
	m3._use_crystalarium(slot)
	_check("⑪a **회수가 통째로 되돌려진다** — 기계도 보석도 제자리(보석 소실 0)",
		m3.crystalarium.has_at(m3._region, slot)
		and m3.crystalarium.gem_at(m3._region, slot) == gem
		and m3.inventory.count_of(ItemCatalog.CRYSTALARIUM) == 0
		and m3.inventory.count_of(gem) == 0)
	_fill_backpack_full(m3.inventory, [0, 1])   # 자리가 둘이면 기계와 보석이 함께 들어온다
	m3._use_crystalarium(slot)
	_check("⑪b 자리가 둘이면 회수 성립 — 기계 1 + 안의 보석 1이 함께 온다",
		not m3.crystalarium.has_at(m3._region, slot)
		and m3.inventory.count_of(ItemCatalog.CRYSTALARIUM) == 1
		and m3.inventory.count_of(gem) == 1)
	await _despawn(m3)

# ★[폴리시 R2 공용] 백팩을 **빈 슬롯 0**으로 채운다 — 되돌릴 수 없는 사건 앞의 무대 셋업.
#   슬롯에 직접 쓴다: `add_item`으로 채우면 같은 (id,품질)이 스택으로 합쳐져 칸이 안 준다.
#   종을 서로 다르게 섞는 것이 핵심이다(합류할 스택이 하나도 없어야 "가득"이 실효한다).
#   ★ `keep`에 든 슬롯 인덱스는 비워 둔다(자리를 하나만 남기는 함정 재현용).
#   ★ 풀은 유품·책(전부 스택 가능·서로 다른 종)이라 레어크로우·설치물 카운트를 오염시키지 않는다.
func _fill_backpack_full(inv: Inventory, keep: Array = []) -> void:
	var pool: Array = []
	for id in Museum.donatable_ids():
		pool.append(String(id))
	for i in range(inv.slots.size()):
		if keep.has(i):
			inv.slots[i] = null
			continue
		inv.slots[i] = {"id": String(pool[i]), "count": 1, "quality": 0} if i < pool.size() \
			else {"id": ItemCatalog.harvest_id(CropCatalog.PIANHWA), "count": 1,
				"quality": (i - pool.size()) % 4}
	inv.changed.emit()
