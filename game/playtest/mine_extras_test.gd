extends SceneTree
# ★[S5-T8 / ADR-0063 결정 10] 갱도 곁들이 3건 검증(ephemeral) — 바닥 반짝이·갱도 호수 어종·계단.
#
# 세 곁들이는 서로 다른 시스템에 붙지만 한 결정(결정 10)의 몸이라 한 스위트에서 본다:
#   (A) 바닥 반짝이 — MineFloors 생성기(결정 롤·배타 좌표) + 원장(day-한정 줍기·세이브) + main 배선
#       (혼력 0·**채집** XP 7·재줍기 차단)
#   (B) 갱도 호수 어종 — FishCatalog 세 번째 서식지(ADR-0061 결정 9 부분 개정) + main 캐스팅 무대
#   (C) 계단 — CraftCatalog 채광 Lv2 게이트 + 든 채 LMB 사용(층 스킵·1개 소모)
#
# ★ 핵심 불변식:
#   ① 반짝이 = 층당 0~2개·결정적·돌/입구/사다리/상자 칸과 배타·종 전부 ItemCatalog 유효.
#   ② **T1/T2/T5 골든 서명 불변** — 반짝이 롤이 RNG 스트림 맨 뒤라 방·돌·노드가 한 칸도 안 흔들린다
#      (mining_test ②와 **같은 골든 표**를 여기서도 본다 = 두 스위트가 서로의 조기 경보다).
#   ③ 줍기 = 혼력 0 · 채집 XP +7(채광 XP 0) · 같은 칸 두 번 못 줍는다 · day가 갈리면 원장 소멸.
#   ④ 갱도 호수 캐스팅 성립 + 서식지 = mine + 풀 = 갱도 2종뿐 · 강/바다 로스터 불변 · 층 안 비캐스팅.
#   ⑤ 계단 = 채광 Lv2 해금(Lv1 잠김) · 돌 99 · 사용 시 층 +1 · 정확히 1개 소모.
#   ⑥ 채광 전문직 드랍 축 실효 — 탐광자(혼탄 2배)·보석사(보석 한 계급 위)가 resolve_drop에서 갈린다.
# 실행: ./run_tests.sh mine_extras

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _settle(m: Node) -> void:
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

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

# 반짝이 배치의 정규 서명(배열이라 순서 자체가 결정적 — dict 키 순서에 안 기댄다).
func _shimmer_sig(layout: Dictionary) -> String:
	if layout.is_empty():
		return "<empty>"
	var parts: Array[String] = []
	for e: Dictionary in layout.get("shimmers", []):
		parts.append("%s@%s" % [String(e["id"]), e["tile"]])
	return ";".join(parts)

func _initialize() -> void:
	print("▶ mine_extras_test (S5-T8 / ADR-0063 결정 10)")

	# ══ ① 반짝이 생성 — 개수·결정성·배타 좌표·로스터 ═════════════════════════
	print("── ① 바닥 반짝이 생성(결정 롤·배타 좌표) ──")
	var count_ok := true
	var det_ok := true
	var excl_ok := true
	var kind_ok := true
	var total := 0
	for day in [1, 5, 9]:
		for f in range(1, MineFloors.MAX_FLOOR + 1):
			var l := MineFloors.generate(day, f)
			var sh: Array = l.get("shimmers", [])
			if sh.size() < MineFloors.SHIMMER_MIN or sh.size() > MineFloors.SHIMMER_MAX:
				count_ok = false
			total += sh.size()
			if _shimmer_sig(l) != _shimmer_sig(MineFloors.generate(day, f)):
				det_ok = false
			var rocks: Array = l["rocks"]
			var used := {}
			for e: Dictionary in sh:
				var t: Vector2i = e["tile"]
				if rocks.has(t) or t == l["entrance"] or t == l["ladder"] or t == l["chest"] \
						or used.has(t) or not (l["rect"] as Rect2i).has_point(t):
					excl_ok = false
				used[t] = true
				if not MineFloors.is_shimmer_kind(String(e["id"])) \
						or not ItemCatalog.has_item(String(e["id"])):
					kind_ok = false
	_check("①a 층당 반짝이 0~2개(3일 × 60층)", count_ok)
	_check("①b 같은 (day,층)은 같은 배치(결정성)", det_ok)
	_check("①c 돌·입구·사다리·상자 칸과 배타 · 방 안 · 중복 0", excl_ok)
	_check("①d 종 전부 로스터 ∩ ItemCatalog 유효(신규 아이템 0)", kind_ok)
	_check("①e 실제로 깔린다(180층 표본 합 > 0) — 합 %d" % total, total > 0)
	# 다른 날 = 다른 배치(매일 리필). 0개인 층이 섞이므로 "전부 다르다"가 아니라 "대체로 다르다"를 본다.
	var day_diff := 0
	for f in range(1, 31):
		if _shimmer_sig(MineFloors.generate(1, f)) != _shimmer_sig(MineFloors.generate(2, f)):
			day_diff += 1
	_check("①f 다른 day = 다른 반짝이 배치(30층 중 %d)" % day_diff, day_diff >= 20)

	# ══ ② 골든 서명 불변(반짝이 롤이 스트림 맨 뒤) ═══════════════════════════
	print("── ② T1/T2 골든 서명 불변(반짝이 롤이 스트림 맨 뒤) ──")
	# 값은 mining_test ②·mob_test ④와 **같은 표**다(T1 시점 생성기 원본). 반짝이 롤이 몹 롤보다
	# 앞에 끼면 이 여섯 줄과 노드·몹 서명이 동시에 터진다 = 전 층 배치 파손의 조기 경보.
	var golden := [
		[5, 1, "wide", Rect2i(1, 1, 20, 14), Vector2i(13, 6), Vector2i(9, 11), 25, 630255240],
		[5, 21, "wide", Rect2i(2, 1, 20, 14), Vector2i(9, 2), Vector2i(15, 12), 43, 1221722436],
		[5, 41, "tall", Rect2i(10, 3, 13, 20), Vector2i(19, 20), Vector2i(13, 7), 47, 1516593986],
		[9, 7, "narrow", Rect2i(3, 1, 11, 11), Vector2i(5, 2), Vector2i(9, 11), 27, 2127131022],
		[1, 31, "wide", Rect2i(3, 5, 20, 14), Vector2i(9, 7), Vector2i(18, 18), 34, 1734108470],
		[3, 60, "narrow", Rect2i(3, 3, 11, 11), Vector2i(4, 11), Vector2i(11, 6), 33, 2430958882],
	]
	var golden_ok := true
	var golden_hash_ok := true
	for g: Array in golden:
		var l := MineFloors.generate(int(g[0]), int(g[1]))
		var rocks: Array = l["rocks"]
		if String(l["template"]) != String(g[2]) or l["rect"] != g[3] \
				or l["entrance"] != g[4] or l["ladder"] != g[5] or rocks.size() != int(g[6]):
			golden_ok = false
		if str(rocks).hash() != int(g[7]):
			golden_hash_ok = false
	_check("②a T1 골든 서명 불변 — 템플릿·방·입구·사다리·돌 수(6표본)", golden_ok)
	_check("②b T1 골든 서명 불변 — 돌 좌표 전량 해시(6표본)", golden_hash_ok)

	# ══ ③ 줍기 원장(day-한정·세이브 왕복) ════════════════════════════════════
	print("── ③ 줍기 원장(day-한정) ──")
	var mf := MineFloors.new()
	mf.advance_day(5)
	# 반짝이가 실제로 깔린 층을 찾는다(0개 층이 섞이므로 탐색).
	var probe_floor := -1
	for f in range(1, MineFloors.MAX_FLOOR + 1):
		if (MineFloors.generate(5, f).get("shimmers", []) as Array).size() > 0:
			probe_floor = f
			break
	_check("③pre 반짝이가 깔린 층 존재(day 5) — %d층" % probe_floor, probe_floor > 0)
	if probe_floor > 0:
		var sh0: Array = MineFloors.generate(5, probe_floor)["shimmers"]
		var t0: Vector2i = sh0[0]["tile"]
		_check("③a 줍기 전 = 원장 조회로 종이 보인다",
			mf.shimmer_at(5, probe_floor, t0) == String(sh0[0]["id"])
			and mf.shimmers_left(5, probe_floor).size() == sh0.size())
		mf.mark_picked(probe_floor, t0)
		_check("③b 주운 뒤 = 그 칸은 빈손 · 남은 목록에서 빠진다",
			mf.is_picked(probe_floor, t0) and mf.shimmer_at(5, probe_floor, t0) == ""
			and mf.shimmers_left(5, probe_floor).size() == sh0.size() - 1)
		# 세이브 왕복.
		var mf2 := MineFloors.new()
		mf2.load_save(mf.to_save())
		_check("③c 세이브 왕복 — 주운 기록 복원", mf2.is_picked(probe_floor, t0))
		_check("③d 세이브 스키마에 'picked' 키", mf.to_save().has("picked"))
		# day 리셋(day-한정 — 깬 돌과 같은 수명).
		mf.advance_day(6)
		_check("③e day가 갈리면 주운 기록 소멸(층 리필)", not mf.is_picked(probe_floor, t0))
		# 구세이브 하위호환 — 키가 없으면 전부 미획득.
		var mf3 := MineFloors.new()
		mf3.load_save({"depth": 3, "day": 5})
		_check("③f 구세이브('picked' 키 없음) = 전부 미획득·무막힘",
			not mf3.is_picked(probe_floor, t0) and mf3.depth() == 3)

	# ══ ⑥ 채광 전문직 드랍 축(순수 해석기) ═══════════════════════════════════
	print("── ⑥ 채광 전문직 드랍 축(탐광자·보석사) ──")
	var coal_base := MiningSkill.resolve_drop(MineFloors.N_HONTAN, 5, 3, Vector2i(4, 4), 0)
	var coal_perk := MiningSkill.resolve_drop(MineFloors.N_HONTAN, 5, 3, Vector2i(4, 4), 0,
		0, 0.0, "mine", 1.0, 0)
	_check("⑥a 탐광자 = 혼탄 산출 정확히 2배",
		int(coal_perk["drops"][0]["count"]) == int(coal_base["drops"][0]["count"]) * 2)
	var ore_perk := MiningSkill.resolve_drop(MineFloors.N_MYEONGDONG, 5, 3, Vector2i(4, 4), 0,
		0, 0.0, "mine", 1.0, 0)
	var ore_base := MiningSkill.resolve_drop(MineFloors.N_MYEONGDONG, 5, 3, Vector2i(4, 4), 0)
	_check("⑥b 탐광자는 **광석에 안 걸린다**(혼탄 전용 축)",
		int(ore_perk["drops"][0]["count"]) == int(ore_base["drops"][0]["count"]))
	var gem_base := MiningSkill.resolve_drop(MineFloors.N_GEM_NEOKSUJEONG, 5, 3, Vector2i(6, 6), 0)
	var gem_perk := MiningSkill.resolve_drop(MineFloors.N_GEM_NEOKSUJEONG, 5, 3, Vector2i(6, 6), 0,
		0, 0.0, "mine", 0.0, 1)
	_check("⑥c 보석사 = 넋수정 → 명옥(한 계급 위)",
		String(gem_base["drops"][0]["id"]) == MineFloors.N_GEM_NEOKSUJEONG
		and String(gem_perk["drops"][0]["id"]) == MineFloors.N_GEM_MYEONGOK)
	_check("⑥d 보석사 상한 = 명부금강에서 클램프",
		MiningSkill.gem_upgrade(MineFloors.N_GEM_MYEONGBU, 1) == MineFloors.N_GEM_MYEONGBU
		and MiningSkill.gem_upgrade(MineFloors.N_GEM_YEOMJUSEOK, 1) == MineFloors.N_GEM_MYEONGBU)
	_check("⑥e 사다리 밖(지오드·오색혼옥)은 승급 대상이 아니다",
		MiningSkill.gem_upgrade(MineFloors.N_GEODE_NEOKAL, 1) == MineFloors.N_GEODE_NEOKAL
		and MiningSkill.gem_upgrade(ItemCatalog.GEM_OSAEK_HONOK, 3) == ItemCatalog.GEM_OSAEK_HONOK)
	_check("⑥f XP는 **캔 광맥**의 값(승급해도 안 늘어난다 — 비-가치 축)",
		int(gem_perk["xp"]) == int(gem_base["xp"]))

	# ══ ⑤ 계단 레시피 게이트(순수 카탈로그) ══════════════════════════════════
	print("── ⑤ 계단 레시피(채광 Lv2 게이트) ──")
	_check("⑤a 채광 Lv1 = 잠김 / Lv2 = 해금",
		not CraftCatalog.unlocked(CraftCatalog.STAIRS, 10, {}, 1)
		and CraftCatalog.unlocked(CraftCatalog.STAIRS, 0, {}, 2))
	_check("⑤b 재료 = 돌 99(스타듀 1:1) · 산출 = 계단 ×1",
		String(CraftCatalog.get_recipe(CraftCatalog.STAIRS)["out_item"]) == ItemCatalog.STAIRS
		and int(CraftCatalog.get_recipe(CraftCatalog.STAIRS)["out_count"]) == 1
		and int(CraftCatalog.get_recipe(CraftCatalog.STAIRS)["mats"][0]["count"]) == 99)
	# ★[S10-T2] 2차 축을 쓰는 레시피가 셋이 됐다(계단=채광 · 스프링클러 2티어=농사). 그래서 단언을
	#   "계단만 갖는다"에서 **"계단의 축은 채광이고, 축 없는 레시피는 여전히 0"**으로 좁힌다.
	_check("⑤c 계단의 2차 축 = 채광 Lv2(축 없는 레시피는 0 = 무영향)",
		CraftCatalog.skill_gate_of(CraftCatalog.STAIRS) == 2
		and CraftCatalog.skill_gate_id_of(CraftCatalog.STAIRS) == ProfessionCatalog.MINING
		and CraftCatalog.skill_gate_of(CraftCatalog.TAPPER) == 0
		and CraftCatalog.skill_gate_id_of(CraftCatalog.TAPPER) == ""
		and CraftCatalog.unlocked(CraftCatalog.TAPPER, 4, {}))
	_check("⑤d 계단 아이템 = 스택 CAT_CONSUMABLE·비매",
		ItemCatalog.has_item(ItemCatalog.STAIRS)
		and ItemCatalog.category_of(ItemCatalog.STAIRS) == ItemCatalog.CAT_CONSUMABLE
		and ItemCatalog.stackable_of(ItemCatalog.STAIRS)
		and ItemCatalog.price_of(ItemCatalog.STAIRS) == 0
		and ItemCatalog.name_of(ItemCatalog.STAIRS) != "")

	# ══ ④ 갱도 호수 어종(카탈로그 층위) ══════════════════════════════════════
	print("── ④ 갱도 호수 어종(ADR-0061 결정 9 부분 개정) ──")
	var mine_pool := FishCatalog.available_ids(FishCatalog.HABITAT_MINE, 0, FishCatalog.PHASE_DAY)
	_check("④a 갱도 풀 = 정확히 2종(돌비늘치·업화붕장어)",
		mine_pool.size() == 2 and mine_pool.has(FishCatalog.DOLBINEUL_CHI)
		and mine_pool.has(FishCatalog.EOPHWA_BUNGJANGEO))
	var all_phase_ok := true
	for s in range(4):
		for p in [FishCatalog.PHASE_MORNING, FishCatalog.PHASE_DAY,
				FishCatalog.PHASE_EVENING, FishCatalog.PHASE_NIGHT]:
			if FishCatalog.available_ids(FishCatalog.HABITAT_MINE, s, p).size() != 2:
				all_phase_ok = false
	_check("④b 16개 (절기×시간) 조합 전부 2종(지하 = 무잠금)", all_phase_ok)
	# 강·바다는 갱도 종을 **한 번도** 안 본다(무대 격리).
	var leak := false
	for h in [FishCatalog.HABITAT_RIVER, FishCatalog.HABITAT_SEA]:
		for s in range(4):
			for p in [FishCatalog.PHASE_MORNING, FishCatalog.PHASE_DAY,
					FishCatalog.PHASE_EVENING, FishCatalog.PHASE_NIGHT]:
				var pool := FishCatalog.available_ids(h, s, p, true)
				if pool.has(FishCatalog.DOLBINEUL_CHI) or pool.has(FishCatalog.EOPHWA_BUNGJANGEO):
					leak = true
	_check("④c 강·바다 32조합에 갱도 종 유출 0(기존 산출 불변)", not leak)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var roll_ok := true
	for i in 200:
		var fid := FishCatalog.roll_fish(FishCatalog.HABITAT_MINE, i % 4, FishCatalog.PHASE_NIGHT, rng)
		if fid != FishCatalog.DOLBINEUL_CHI and fid != FishCatalog.EOPHWA_BUNGJANGEO:
			roll_ok = false
	_check("④d 갱도 입질 롤 200회 전부 갱도 2종", roll_ok)
	_check("④e 갱도 폴백 = 돌비늘치(상시종)",
		FishCatalog.fallback_id(FishCatalog.HABITAT_MINE) == FishCatalog.DOLBINEUL_CHI
		and FishCatalog.fallback_id(FishCatalog.HABITAT_SEA) == FishCatalog.NEOK_MYEOLCHI
		and FishCatalog.fallback_id(FishCatalog.HABITAT_RIVER) == FishCatalog.NEOK_BUNGEO)

	# ══ main 배선 ════════════════════════════════════════════════════════════
	var m: Node = await _spawn_main()

	# ── ④' 갱도 호수 캐스팅(지상 무대) ──────────────────────────────────────
	print("── ④' 갱도 호수 캐스팅(main 배선) ──")
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	await _settle(m)
	_check("④'pre 지상 갱도 · 층 0", m._region == RegionCatalog.EOPHWA_MINE and m._mine_floor == 0)
	_check("④'a 서식지 = 갱도(mine)", m._fishing_habitat() == FishCatalog.HABITAT_MINE)
	_check("④'b 캐스팅 무대 O · 게잡이통 무대 X(통 표는 삼도천·황천해 전용)",
		m._is_casting_region() and not m._is_fishing_region())
	# 호수 물가 land 칸을 찾아 그 칸에서 물을 겨눈다.
	var lake: Rect2i = m.MINE_LAKE_RECT
	var stand := Vector2i(-1, -1)
	var water := Vector2i(-1, -1)
	for y in range(lake.position.y, lake.end.y):
		for x in range(lake.position.x, lake.end.x):
			if m._grid[y][x] != m.WATER:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x < 0 or n.y < 0 or n.x >= m._grid_w or n.y >= m._outdoor_h:
					continue
				if m._grid[n.y][n.x] == m.GROUND or m._grid[n.y][n.x] == m.PATH:
					stand = n
					water = Vector2i(x, y)
	_check("④'pre 호수 물가에 설 칸 존재 — 서기 %s / 물 %s" % [stand, water], stand.x >= 0)
	m.inventory.add_item(ItemCatalog.ROD_T1, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == ItemCatalog.ROD_T1:
			m.inventory.select(i)
			break
	m.player.position = m._tile_center_px(stand)
	m._target = water
	_check("④'c 갱도 호수에 캐스팅 가능(무대 개방)", m._can_cast())
	# 층 안은 비캐스팅(층 그리드엔 물이 없고, 술어 자체가 막는다).
	m.player.position = m._tile_center_px(m.DUNGEON_GATE_DOOR)
	m._descend_mine(1)
	await _settle(m)
	_check("④'d 층 안 = 비캐스팅(지상 호수만)",
		m._mine_floor == 1 and not m._is_casting_region() and not m._can_cast())

	# ── ③' 줍기 배선(혼력 0 · 채집 XP 7) ────────────────────────────────────
	print("── ③' 줍기 배선(혼력 0 · 채집 XP 7) ──")
	# 반짝이가 깔린 층을 찾아 내려간다(오늘 날짜 기준).
	var live_floor := -1
	for f in range(1, MineFloors.MAX_FLOOR + 1):
		if (MineFloors.generate(m.clock.day, f).get("shimmers", []) as Array).size() > 0:
			live_floor = f
			break
	_check("③'pre 오늘 반짝이가 깔린 층 존재 — %d층" % live_floor, live_floor > 0)
	if live_floor > 0:
		m._descend_mine(live_floor)
		await _settle(m)
		var sh: Array = m._mine_layout["shimmers"]
		var st: Vector2i = sh[0]["tile"]
		var sid := String(sh[0]["id"])
		m.player.position = m._tile_center_px(st)
		_check("③'a 발밑 반짝이 인식", m._mine_shimmer_at(st) == sid)
		var e_before: int = m.energy.current
		var fx_before: int = m._foraging_xp
		var mx_before: int = m._mining_xp
		var have_before: int = m.inventory.count_of(sid)
		m._pick_mine_shimmer(st)
		_check("③'b 인벤 +1(%s)" % ItemCatalog.name_of(sid),
			m.inventory.count_of(sid) == have_before + 1)
		_check("③'c 혼력 0 소모", m.energy.current == e_before)
		_check("③'d 채집 XP +%d(줍기 고정)" % ForageSkill.PICK_XP,
			m._foraging_xp == fx_before + ForageSkill.PICK_XP)
		_check("③'e 채광 XP 0(줍기는 채광 축이 아니다)", m._mining_xp == mx_before)
		_check("③'f 그 칸은 비었다(원장 기록)",
			m._mine_shimmer_at(st) == "" and m.mine_floors.is_picked(live_floor, st))
		var have_after: int = m.inventory.count_of(sid)
		m._pick_mine_shimmer(st)
		_check("③'g 같은 칸 재줍기 불가(1회성)", m.inventory.count_of(sid) == have_after)

	# ── ⑤' 계단 사용(층 스킵·1개 소모) ──────────────────────────────────────
	print("── ⑤' 계단 사용(층 스킵) ──")
	m._descend_mine(3)
	await _settle(m)
	m.inventory.add_item(ItemCatalog.STAIRS, 2)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == ItemCatalog.STAIRS:
			m.inventory.select(i)
			break
	_check("⑤'pre 3층·계단 2개 소지", m._mine_floor == 3 and m.inventory.count_of(ItemCatalog.STAIRS) == 2)
	var e2: int = m.energy.current
	m._use_tool()                     # 든 것이 계단 = 놓는다(든 것이 곧 동사)
	await _settle(m)
	_check("⑤'a 층 +1(4층)", m._mine_floor == 4)
	_check("⑤'b 정확히 1개 소모", m.inventory.count_of(ItemCatalog.STAIRS) == 1)
	_check("⑤'c 혼력 0 소모(놓는 데 혼력이 안 든다)", m.energy.current == e2)
	# 바닥 층에선 못 쓴다(물건만 날리는 사고 방지).
	m._descend_mine(MineFloors.MAX_FLOOR)
	await _settle(m)
	_check("⑤'pre2 바닥 60층", m._mine_floor == MineFloors.MAX_FLOOR)
	_check("⑤'d 바닥에서는 계단 사용 불가(판정)", not m._can_use_stairs())
	m._use_tool()
	await _settle(m)
	_check("⑤'e 바닥에서 눌러도 소모 0 · 층 불변",
		m.inventory.count_of(ItemCatalog.STAIRS) == 1 and m._mine_floor == MineFloors.MAX_FLOOR)
	# ── ⑦ 채광 전문직 **실효** 배선(main 조회 6종) ──────────────────────────
	# 카탈로그 값이 인코딩됐다는 건 profession_test ⑫가 본다. 여기선 그 값이 **main의 소비 창구
	# 여섯 줄을 실제로 통과하는가**를 본다 — T2/T3이 "0 중립" 폴백으로 열어 둔 바로 그 자리다.
	print("── ⑦ 채광 전문직 실효(main 조회 6종) ──")
	var MIN := ProfessionCatalog.MINING
	m._professions[MIN] = {}
	_check("⑦a 미선택 = 전 축 중립(0/false/1.0배)",
		m.mining_ore_bonus() == 0 and is_equal_approx(m.mining_gem_pair_chance(), 0.0)
		and not m.mining_coal_double() and m.mining_gem_rank_step() == 0
		and is_equal_approx(m.smelt_time_cut(), 0.0) and m.smelt_quality_step() == 0
		and is_equal_approx(m.geode_double_chance(), 0.0))
	m._professions[MIN] = {5: "miner", 10: "blacksmith"}
	_check("⑦b 광부 → 광맥당 +1", m.mining_ore_bonus() == 1)
	_check("⑦c 제련공 → 제련 시간 −50% · 주괴 등급 계단 +1",
		is_equal_approx(m.smelt_time_cut(), 0.5) and m.smelt_quality_step() == 1)
	# 원장 계약까지 내려가는지 — 명동 30분이 15분으로, 등급이 은(Q_NORMAL+1)으로.
	_check("⑦d 원장 실효 — 명동 30분 → 15분 · 투입 등급 = 은",
		FurnaceLedger.smelt_minutes(ItemCatalog.ORE_MYEONGDONG, m.smelt_time_cut()) == 15
		and FurnaceLedger.quality_for(m.smelt_quality_step()) == ItemCatalog.Q_NORMAL + 1)
	m._professions[MIN] = {5: "miner", 10: "prospector"}
	_check("⑦e 탐광자 → 혼탄 2배 플래그", m.mining_coal_double())
	m._professions[MIN] = {5: "geologist", 10: "excavator"}
	_check("⑦f 지질사 → 보석 쌍 0.5 · 발굴자 → 알돌 2배 1.0",
		is_equal_approx(m.mining_gem_pair_chance(), 0.5)
		and is_equal_approx(m.geode_double_chance(), 1.0))
	m._professions[MIN] = {5: "geologist", 10: "gemologist"}
	_check("⑦g 보석사 → 계급 계단 +1", m.mining_gem_rank_step() == 1)
	m._professions[MIN] = {}
	await _despawn(m)

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
