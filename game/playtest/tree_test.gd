extends SceneTree
# ★[S4-T3 / ADR-0062 결정 3] 벌목 — 나무 원장·도끼 디스패치·원목·재성장 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ① 초기 배치 결정성 — 같은 맵이면 늘 같은 배치·같은 종(세이브 키 부재 시 재생성 정합).
#   ② 성장 20%/일 결정 롤 — 같은 day 시퀀스면 같은 결과 · 미성숙목이 실제로 자란다.
#   ③ 타수 — 성숙 10 · 4단계 3 · 유목 1 · 그루터기 3(도끼 티어 감소는 S4-T4).
#   ④ 산출 범위 — 원목 12~16 · 수액 5 · 씨앗 0~2(lvl1+).
#   ⑤ 그루터기 잔존·제거 — 성숙목을 베면 그루터기가 남아 여전히 통행 불가, 치우면 원목 4~9 + XP 2.
#   ⑥ 재성장 이원 — 숲 = 빈 슬롯 20% stage3 재출현 / 안식 = 성숙목 15% 반경 3칸 자체 파종.
#   ⑦ 경계 밴드 불벌목 — 테두리 TREE는 원장 밖이고 여전히 통과 불가(flood-fill 불변식 보존).
#   ⑧ 벌목 혼력 소모 > 0(줍기 0과 대비 — ADR-0033 "나무 작업은 과금").
#   ⑨ XP = 마지막 타에만 14(중간 타 0) · 그루터기 제거 2.
#   ⑩ 세이브 라운드트립 — 원장 직렬화 + main 세이브·재부팅 복원 + 키 없는 구세이브 하위호환.
#   ⑪ 퍼크 주입 — 감지자(원목 +1) · 벌목꾼(단단한 원목 확률) 실효.
#
# 실행: ./run_tests.sh tree   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame
	return m

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

# 외부에서 걸을 수 있는 칸인가(jeoseung_forest_test 동형).
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return id != m.WALL and id != m.WATER and id != m.TREE and id != m.VOID

# 원장 상태를 비교 가능한 정렬 문자열로(결정성·라운드트립 판정).
func _fingerprint(led: TreeLedger) -> String:
	var rows: Array = []
	for region: String in led.regions():
		for t: Vector2i in led.tiles(region):
			rows.append("%s:%d,%d=%s/%d/%d/%s" % [region, t.x, t.y, led.species_at(region, t),
				led.stage_at(region, t), led.hp_at(region, t),
				"S" if led.is_stump(region, t) else "-"])
	rows.sort()
	return "|".join(rows)

# 대상이 사라질 때까지 도끼질(무한루프 방어 상한). 누적 산출을 합쳐 반환.
func _chop_until(led: TreeLedger, region: String, t: Vector2i, day: int, level: int = 5,
		wood_bonus: int = 0, hardwood: float = 0.0) -> Dictionary:
	var acc := {"hits": 0, "wood": 0, "hardwood": 0, "sap": 0, "seeds": 0, "xp": 0, "mid_xp": 0}
	for i in 40:
		var r := led.chop(region, t, day, level, wood_bonus, hardwood)
		if r.is_empty():
			break
		acc["hits"] += 1
		acc["wood"] += int(r["wood"])
		acc["hardwood"] += int(r["hardwood"])
		acc["sap"] += int(r["sap"])
		acc["seeds"] += int(r["seeds"])
		acc["xp"] += int(r["xp"])
		if int(r["hp"]) > 0:
			acc["mid_xp"] += int(r["xp"]) + int(r["wood"]) + int(r["sap"])   # 중간 타는 전부 0이어야
		if int(r["hp"]) <= 0:
			break
	return acc

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S4-T3 벌목(나무 원장·도끼·원목·재성장) 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var FOREST := RegionCatalog.JEOSEUNG_FOREST
	var MIHOK := RegionCatalog.MIHOK_FOREST
	var HOME := RegionCatalog.HOME
	var T := Vector2i(20, 20)   # 순수 원장 테스트용 임의 칸(지형 무관 — 원장은 지형을 모른다)

	# ── ③ 타수(순수 규칙) ──
	print("── ③ 타수 ──")
	_check("③a 상수 = 성숙10 · 4단계3 · 유목1 · 그루터기3",
		TreeLedger.HP_MATURE == 10 and TreeLedger.HP_STAGE4 == 3
		and TreeLedger.HP_SAPLING == 1 and TreeLedger.HP_STUMP == 3)
	_check("③b hp_for_stage 매핑(5→10 · 4→3 · 1~3→1)",
		TreeLedger.hp_for_stage(5) == 10 and TreeLedger.hp_for_stage(4) == 3
		and TreeLedger.hp_for_stage(3) == 1 and TreeLedger.hp_for_stage(1) == 1)
	var l3 := TreeLedger.new()
	l3.seed_region(FOREST, [T])                              # 성숙목 1그루
	var mature_hits := _chop_until(l3, FOREST, T, 5)
	_check("③c 성숙목 = 10타에 쓰러짐", int(mature_hits["hits"]) == TreeLedger.HP_MATURE)
	_check("③d 쓰러진 자리에 그루터기 잔존(통행 불가 유지)",
		l3.is_stump(FOREST, T) and l3.is_occupied(FOREST, T))
	var stump_hits := _chop_until(l3, FOREST, T, 5)
	_check("③e 그루터기 = 3타에 제거", int(stump_hits["hits"]) == TreeLedger.HP_STUMP)
	_check("③f 제거 후 슬롯은 남되 비었다(재성장 후보 · 통행 가능)",
		l3.has_slot(FOREST, T) and not l3.is_occupied(FOREST, T) and l3.stage_at(FOREST, T) == 0)
	_check("③g 빈 슬롯 도끼질 = 무동작(방어)", l3.chop(FOREST, T, 5).is_empty())
	# 4단계·유목
	var l4 := TreeLedger.new()
	l4.seed_region(FOREST, [T], 4)
	_check("③h 4단계 = 3타", int(_chop_until(l4, FOREST, T, 7)["hits"]) == TreeLedger.HP_STAGE4)
	_check("③i 4단계 벌목은 그루터기를 안 남긴다", not l4.is_occupied(FOREST, T))
	var l1 := TreeLedger.new()
	l1.seed_region(FOREST, [T], 2)
	var young := _chop_until(l1, FOREST, T, 7)
	_check("③j 유목(2단계) = 1타", int(young["hits"]) == TreeLedger.HP_SAPLING)
	_check("③k 유목은 씨앗만(원목·수액·XP 0 — 남벌 유인 0)",
		int(young["wood"]) == 0 and int(young["sap"]) == 0 and int(young["xp"]) == 0
		and int(young["seeds"]) == 1)

	# ── ④ 산출 범위 + ⑨ XP ──
	print("── ④ 산출 · ⑨ XP ──")
	var wood_ok := true
	var sap_ok := true
	var seed_ok := true
	var xp_ok := true
	var mid_ok := true
	var wood_lo := 999
	var wood_hi := 0
	for d in range(1, 61):
		var led := TreeLedger.new()
		var tile := Vector2i(10 + d % 7, 10 + d / 7)
		led.seed_region(FOREST, [tile])
		var got := _chop_until(led, FOREST, tile, d)
		var w := int(got["wood"])
		wood_lo = mini(wood_lo, w)
		wood_hi = maxi(wood_hi, w)
		if w < TreeLedger.WOOD_MIN or w > TreeLedger.WOOD_MAX:
			wood_ok = false
		if int(got["sap"]) != TreeLedger.SAP_YIELD:
			sap_ok = false
		if int(got["seeds"]) < TreeLedger.SEED_MIN or int(got["seeds"]) > TreeLedger.SEED_MAX:
			seed_ok = false
		if int(got["xp"]) != ForageSkill.CHOP_XP:
			xp_ok = false
		if int(got["mid_xp"]) != 0:
			mid_ok = false
	_check("④a 성숙목 원목 12~16 (실측 %d~%d)" % [wood_lo, wood_hi], wood_ok)
	_check("④b 원목 밴드가 실제로 넓다(고정값 아님)", wood_lo < wood_hi)
	_check("④c 수액 = 5 고정", sap_ok)
	_check("④d 씨앗 0~2(lvl1+)", seed_ok)
	_check("⑨a 벌목 XP = 마지막 타에만 %d" % ForageSkill.CHOP_XP, xp_ok)
	_check("⑨b 중간 타는 XP·원목·수액 전부 0", mid_ok)
	# 채집 lvl0이면 씨앗이 안 나온다(SEED_LEVEL 게이트).
	var l0 := TreeLedger.new()
	l0.seed_region(FOREST, [T])
	_check("④e 채집 lvl0 = 씨앗 0(lvl1+ 게이트)",
		int(_chop_until(l0, FOREST, T, 11, 0)["seeds"]) == 0)
	# ⑤ 그루터기 제거 산출.
	var stump_wood_ok := true
	var stump_xp_ok := true
	for d in range(1, 41):
		var led2 := TreeLedger.new()
		var tile2 := Vector2i(5 + d % 5, 30 + d / 5)
		led2.seed_region(FOREST, [tile2])
		_chop_until(led2, FOREST, tile2, d)               # 성숙목 벌목 → 그루터기
		var sres := _chop_until(led2, FOREST, tile2, d)   # 그루터기 제거
		if int(sres["wood"]) < TreeLedger.STUMP_WOOD_MIN or int(sres["wood"]) > TreeLedger.STUMP_WOOD_MAX:
			stump_wood_ok = false
		if int(sres["xp"]) != TreeLedger.STUMP_XP:
			stump_xp_ok = false
	_check("⑤a 그루터기 제거 원목 4~9", stump_wood_ok)
	_check("⑤b 그루터기 제거 XP = 2", stump_xp_ok and TreeLedger.STUMP_XP == 2)

	# ── ⑪ 퍼크 주입(순수) ──
	print("── ⑪ 퍼크 ──")
	var bonus_ok := true
	for d in range(1, 21):
		var la := TreeLedger.new()
		var lb := TreeLedger.new()
		var tt := Vector2i(12, 12)
		la.seed_region(FOREST, [tt])
		lb.seed_region(FOREST, [tt])
		var base_w := int(_chop_until(la, FOREST, tt, d, 5, 0)["wood"])
		var bonus_w := int(_chop_until(lb, FOREST, tt, d, 5, 1)["wood"])
		if bonus_w != base_w + 1:
			bonus_ok = false
	_check("⑪a 감지자(wood_bonus +1) = 같은 롤에 원목 정확히 +1", bonus_ok)
	var hw := 0
	var hw_none := 0
	for d in range(1, 101):
		var lc := TreeLedger.new()
		var ld := TreeLedger.new()
		var tc := Vector2i(8 + d % 9, 8 + d / 9)
		lc.seed_region(FOREST, [tc])
		ld.seed_region(FOREST, [tc])
		hw += int(_chop_until(lc, FOREST, tc, d, 5, 0, ForageSkill.HARDWOOD_CHANCE)["hardwood"])
		hw_none += int(_chop_until(ld, FOREST, tc, d, 5, 0, 0.0)["hardwood"])
	_check("⑪b 벌목꾼(hardwood 0.25) — 100회 중 %d회 단단한 원목(0<n<100)" % hw, hw > 0 and hw < 100)
	_check("⑪c 퍼크 없으면 단단한 원목 0", hw_none == 0)
	_check("⑪d ForageSkill 해석기 배선(wood_bonus 1 · hardwood 0.25)",
		ForageSkill.wood_bonus(1.0) == 1 and is_equal_approx(ForageSkill.hardwood_chance(1.0), 0.25)
		and is_equal_approx(ForageSkill.hardwood_chance(0.0), 0.0))

	# ── ② 성장 20%/일 결정 롤 ──
	print("── ② 성장 ──")
	var grow_tiles: Array = []
	for i in 40:
		grow_tiles.append(Vector2i(i % 8, i / 8))
	var ga := TreeLedger.new()
	ga.seed_region(FOREST, grow_tiles, 1)
	var gb := TreeLedger.new()
	gb.seed_region(FOREST, grow_tiles, 1)
	for d in range(1, 31):
		ga.advance_day(d)
		gb.advance_day(d)
	_check("②a 같은 day 시퀀스 = 같은 결과(전역 randf 금지의 실증)",
		_fingerprint(ga) == _fingerprint(gb) and _fingerprint(ga) != "")
	var matured := 0
	var still_young := 0
	for t: Vector2i in ga.tiles(FOREST):
		if ga.stage_at(FOREST, t) >= TreeLedger.MAX_STAGE:
			matured += 1
		elif ga.stage_at(FOREST, t) < TreeLedger.MAX_STAGE:
			still_young += 1
	_check("②b 30일 뒤 일부는 성숙(1→5, 20%%/일 = 중앙값 ~24일) — 성숙 %d / 미성숙 %d"
		% [matured, still_young], matured > 0)
	_check("②c 성장 확률 상수 = 0.20", is_equal_approx(TreeLedger.GROWTH_CHANCE, 0.20))
	# 성장 롤이 실제로 20% 근방인가(1단계 40그루 × 1일).
	var one_day := TreeLedger.new()
	one_day.seed_region(FOREST, grow_tiles, 1)
	var res_day: Dictionary = one_day.advance_day(9)
	_check("②d 하루 성장 수가 20%% 근방(40그루 중 %d)" % res_day["grown"].size(),
		res_day["grown"].size() >= 2 and res_day["grown"].size() <= 18)
	_check("②e 그루터기는 안 자란다(치워야 자리가 난다)", true if _stump_frozen() else false)

	# ── ⑥ 재성장 이원 ──
	print("── ⑥ 재성장 ──")
	_check("⑥a 모드 분기(숲=빈 슬롯 재출현 / 안식=자체 파종)",
		TreeLedger.mode_for(FOREST) == TreeLedger.MODE_FOREST
		and TreeLedger.mode_for(MIHOK) == TreeLedger.MODE_FOREST
		and TreeLedger.mode_for(HOME) == TreeLedger.MODE_SEED)
	# 숲 — 빈 슬롯 20%/일 stage3 재출현.
	var rg := TreeLedger.new()
	rg.seed_region(FOREST, grow_tiles)
	for t: Vector2i in grow_tiles:            # 전부 완전 제거(그루터기까지)
		_chop_until(rg, FOREST, t, 3)
		_chop_until(rg, FOREST, t, 3)
	var all_empty := true
	for t: Vector2i in grow_tiles:
		if rg.is_occupied(FOREST, t):
			all_empty = false
	_check("⑥b 전량 벌목·그루터기 제거 후 빈 슬롯 40", all_empty and rg.slot_count(FOREST) == 40)
	var regrown_total := 0
	var stage3_only := true
	for d in range(4, 9):
		var rr: Dictionary = rg.advance_day(d)
		regrown_total += rr["regrown"].size()
		for e in rr["regrown"]:
			if rg.stage_at(FOREST, e["tile"]) < TreeLedger.REGROW_STAGE:
				stage3_only = false
	_check("⑥c 숲 빈 슬롯 재출현(5일 %d칸 — 20%%/일)" % regrown_total, regrown_total > 0)
	_check("⑥d 재출현 단계 = stage3(묘목이 아니라 중간 나무 — 코지)",
		stage3_only and TreeLedger.REGROW_STAGE == 3 and is_equal_approx(TreeLedger.REGROW_CHANCE, 0.20))
	# 숲은 자체 파종을 안 한다(슬롯 밖에 안 돋는다).
	var slots_before := rg.slot_count(FOREST)
	for d in range(9, 20):
		rg.advance_day(d, func(_r: String, _t: Vector2i) -> bool: return true)
	_check("⑥e 숲은 자체 파종 없음(슬롯 수 불변 — 길·빈터가 안 메워진다)",
		rg.slot_count(FOREST) == slots_before)
	# 안식 — 성숙목 15% 반경 3칸 파종.
	var hs := TreeLedger.new()
	hs.seed_region(HOME, [Vector2i(50, 50), Vector2i(60, 40)])
	var seeded_total := 0
	var radius_ok := true
	var stage1_ok := true
	for d in range(1, 21):
		var sr: Dictionary = hs.advance_day(d, func(_r: String, _t: Vector2i) -> bool: return true)
		seeded_total += sr["seeded"].size()
		for e in sr["seeded"]:
			var st: Vector2i = e["tile"]
			if hs.stage_at(HOME, st) != 1:
				stage1_ok = false
			# 파종은 *그 시점의 성숙목* 반경 안에서만 일어난다(자란 2세대가 다시 뿌리므로
			# 최초 앵커가 아니라 "지금 서 있는 성숙목" 전체를 모수로 본다).
			var near := false
			for anchor: Vector2i in hs.tiles(HOME):
				if not hs.is_mature(HOME, anchor):
					continue
				if absi(st.x - anchor.x) <= TreeLedger.SEED_RADIUS and absi(st.y - anchor.y) <= TreeLedger.SEED_RADIUS:
					near = true
			if not near:
				radius_ok = false
	_check("⑥f 안식 자체 파종(20일 %d그루 — 15%%/밤)" % seeded_total, seeded_total > 0)
	_check("⑥g 파종 = stage1(묘목)", stage1_ok and is_equal_approx(TreeLedger.SEED_CHANCE, 0.15))
	_check("⑥h 파종 자리 = 성숙목 반경 %d칸 안" % TreeLedger.SEED_RADIUS, radius_ok)
	_check("⑥i free_cb 무효면 파종 없음(main이 다른 구역에 있을 때)",
		_no_seed_without_cb(HOME))
	# 상한(HOME_CAP) — 무한정 안 늘어난다.
	var cap_led := TreeLedger.new()
	cap_led.seed_region(HOME, [Vector2i(40, 40), Vector2i(41, 44), Vector2i(46, 40)])
	for d in range(1, 400):
		cap_led.advance_day(d, func(_r: String, _t: Vector2i) -> bool: return true)
	_check("⑥j 안식 총상한 %d(마당이 숲이 되지 않는다 — 실측 %d)"
		% [TreeLedger.HOME_CAP, cap_led.occupied_count(HOME)],
		cap_led.occupied_count(HOME) <= TreeLedger.HOME_CAP)

	# ── ① 초기 배치 결정성(순수) + ⑩-a 세이브 라운드트립 ──
	print("── ① 결정성 · ⑩ 세이브 ──")
	var s1 := TreeLedger.new()
	s1.seed_region(FOREST, grow_tiles)
	var s2 := TreeLedger.new()
	s2.seed_region(FOREST, grow_tiles)
	_check("①a 같은 칸 목록 = 같은 종·같은 단계(좌표 해시 파생)", _fingerprint(s1) == _fingerprint(s2))
	_check("①b 종은 3종에 고루 갈린다(한 종으로 쏠리지 않음)", _species_spread(s1, FOREST) >= 2)
	_check("①c seed_region 멱등(이미 깐 구역은 무동작 — 벤 나무 부활 0)",
		s1.seed_region(FOREST, grow_tiles) == 0 and s1.is_seeded(FOREST))
	var dst := TreeLedger.new()
	dst.load_save(s1.to_save())
	_check("⑩a 원장 직렬화 왕복(구역·좌표·종·단계·타수·그루터기)", _fingerprint(dst) == _fingerprint(s1))
	_check("⑩b 시드 완료 플래그도 왕복(재빌드에 다시 안 심는다)", dst.is_seeded(FOREST))
	var mixed := TreeLedger.new()
	mixed.seed_region(FOREST, [T, T + Vector2i(1, 0), T + Vector2i(2, 0)])
	_chop_until(mixed, FOREST, T, 3)                        # 그루터기
	_chop_until(mixed, FOREST, T + Vector2i(1, 0), 3)
	_chop_until(mixed, FOREST, T + Vector2i(1, 0), 3)       # 빈 슬롯
	var mixed_dst := TreeLedger.new()
	mixed_dst.load_save(mixed.to_save())
	_check("⑩c 그루터기·빈 슬롯·성숙목 혼재 상태 왕복",
		mixed_dst.is_stump(FOREST, T) and not mixed_dst.is_occupied(FOREST, T + Vector2i(1, 0))
		and mixed_dst.is_mature(FOREST, T + Vector2i(2, 0)))
	var empty := TreeLedger.new()
	empty.load_save({})
	_check("⑩d 키 없는 구세이브 = 원장 0(첫 빌드가 결정적으로 재생성)",
		empty.total() == 0 and not empty.is_seeded(FOREST))
	var junk := TreeLedger.new()
	junk.load_save({"trees": {FOREST: [[3, 3, "no_such_species", 5, 10, 0, 0]]}, "seeded": [FOREST]})
	_check("⑩e 미지 종 id는 조용히 버린다(슬롯은 보존)",
		junk.has_slot(FOREST, Vector2i(3, 3)) and junk.species_at(FOREST, Vector2i(3, 3)) == "")

	# ── main 배선(⑦⑧ + ①-d + ⑩-f) ──
	print("── main 배선 ──")
	var m: Node = await _new_main()
	_check("⓪ tree_ledger 배선(RefCounted 원장)", m.tree_ledger != null)
	_check("⓪b 안식 나무 원장 시드 = 손저작 나무 앵커 수(%d)" % m._home_tree_anchors().size(),
		m.tree_ledger.slot_count(HOME) == m._home_tree_anchors().size()
		and m.tree_ledger.slot_count(HOME) > 0)
	print("  · 안식 원장 나무 %d그루" % m.tree_ledger.slot_count(HOME))

	m._rebuild_region(FOREST)
	var forest_slots: int = m.tree_ledger.slot_count(FOREST)
	print("  · 저승 숲 원장 나무 %d그루" % forest_slots)
	_check("①d 저승 숲 내부 나무 시드 > 0", forest_slots > 0)

	# ⑦ 경계 밴드 불벌목.
	var band_in_ledger := 0
	for t: Vector2i in m.tree_ledger.tiles(FOREST):
		if m._is_tree_border_band(t):
			band_in_ledger += 1
	_check("⑦a 경계 밴드 칸은 원장에 하나도 없음(불벌목 벽)", band_in_ledger == 0)
	# 밴드 TREE 칸이 실제로 존재하고 통과 불가.
	var band_tree := Vector2i(-1, -1)
	for y in m._outdoor_h:
		for x in m._grid_w:
			if m._grid[y][x] == m.TREE and m._is_tree_border_band(Vector2i(x, y)):
				band_tree = Vector2i(x, y)
				break
		if band_tree.x >= 0:
			break
	_check("⑦b 경계 밴드 TREE가 실재하고 통과 불가", band_tree.x >= 0 and not _walkable(m, band_tree))
	_check("⑦c 원장 밖이라 도끼가 안 먹는다(무동작)",
		m.tree_ledger.chop(FOREST, band_tree, m.clock.day).is_empty())

	# 내부 원장 나무 = 벌목 전 통과 불가.
	var inner: Vector2i = m.tree_ledger.tiles(FOREST)[0]
	_check("⑦d 내부 원장 나무는 벌목 전 TREE·통과 불가",
		m._grid[inner.y][inner.x] == m.TREE and not _walkable(m, inner))

	# ⑧ 벌목 혼력 소모 > 0 + 산출 인벤 적재 + 그리드 동기화.
	var axe_slot: int = _slot_of(m, ItemCatalog.AXE)
	var hoe_slot: int = _slot_of(m, ItemCatalog.HOE)
	_check("⑧0 스타터 도끼 보유(무상 그레이박스 도구 — 소프트락 0)", axe_slot >= 0 and hoe_slot >= 0)
	m.inventory.select(axe_slot)
	m._foraging_xp = int(FarmSkill.XP_THRESHOLDS[0])   # lvl1(씨앗 게이트 통과)
	var soul_before: int = m.energy.current
	m._target = inner
	m._chop_tree(inner)
	_check("⑧a 벌목 1타 = 혼력 소모 > 0(줍기 0과 대비 — ADR-0033)",
		m.energy.current == soul_before - SoulEnergy.COST_PER_ACTION)
	_check("⑧b 1타 후에도 서 있다(성숙 10타)", m.tree_ledger.hp_at(FOREST, inner) == TreeLedger.HP_MATURE - 1)
	# 도끼가 아니면 무동작(혼력 불변).
	m.inventory.select(hoe_slot)
	var soul_hoe: int = m.energy.current
	m._chop_tree(inner)
	_check("⑧c 도끼가 아니면 무동작(혼력·타수 불변)",
		m.energy.current == soul_hoe and m.tree_ledger.hp_at(FOREST, inner) == TreeLedger.HP_MATURE - 1)
	m.inventory.select(axe_slot)
	var wood_before: int = m.inventory.count_of(ItemCatalog.WOOD)
	for i in 20:
		m.energy.current = SoulEnergy.MAX
		if not m.tree_ledger.is_occupied(FOREST, inner):
			break
		if m.tree_ledger.is_stump(FOREST, inner):
			break
		m._chop_tree(inner)
	_check("⑤c 성숙목을 다 베면 그루터기 잔존 + 여전히 통과 불가",
		m.tree_ledger.is_stump(FOREST, inner) and m._grid[inner.y][inner.x] == m.TREE
		and not _walkable(m, inner))
	_check("④f 원목이 인벤에 실린다(%d개)" % (m.inventory.count_of(ItemCatalog.WOOD) - wood_before),
		m.inventory.count_of(ItemCatalog.WOOD) - wood_before >= TreeLedger.WOOD_MIN)
	_check("④g 수액도 실린다(5)", m.inventory.count_of(ItemCatalog.SAP) >= TreeLedger.SAP_YIELD)
	_check("⑨c 벌목 XP 적립(마지막 타 %d)" % ForageSkill.CHOP_XP,
		m._foraging_xp >= int(FarmSkill.XP_THRESHOLDS[0]) + ForageSkill.CHOP_XP)
	# 그루터기 제거 → 그 칸이 걸을 수 있게 된다(즉시 동기화).
	for i in 6:
		m.energy.current = SoulEnergy.MAX
		if not m.tree_ledger.is_occupied(FOREST, inner):
			break
		m._chop_tree(inner)
	_check("⑤d 그루터기 제거 → 그리드 GROUND·통과 가능(즉시 동기화)",
		not m.tree_ledger.is_occupied(FOREST, inner)
		and m._grid[inner.y][inner.x] == m.GROUND and _walkable(m, inner))
	# 구역 재빌드 후에도 열린 채로 남는다(원장이 유일 진실원).
	m._rebuild_region(MIHOK)
	m._rebuild_region(FOREST)
	_check("⑤e 재빌드·워프 재진입 후에도 벤 자리는 열린 채(부활 0)",
		m._grid[inner.y][inner.x] == m.GROUND and _walkable(m, inner))
	_check("①e 미혹의 숲도 내부 나무 시드(구역별 독립 원장)", m.tree_ledger.slot_count(MIHOK) > 0)
	print("  · 미혹의 숲 원장 나무 %d그루" % m.tree_ledger.slot_count(MIHOK))

	# ── 안식 농원 배선(프롭 나무 — 그리드가 아니라 충돌·드로우 skip-filter로 통행이 갈린다) ──
	m._rebuild_region(HOME)
	var anchor: Vector2i = m._home_tree_anchors()[0]
	_check("⓪c 안식 손저작 나무 앵커가 원장 성숙목", m.tree_ledger.is_mature(HOME, anchor))
	var solids_before: int = _live_shapes(m)
	for i in 20:
		m.energy.current = SoulEnergy.MAX
		if m.tree_ledger.is_stump(HOME, anchor):
			break
		m._chop_tree(anchor)
	_check("⑤f 안식 나무도 벌목 → 그루터기 잔존(충돌 유지)",
		m.tree_ledger.is_stump(HOME, anchor)
		and _live_shapes(m) == solids_before)
	for i in 6:
		m.energy.current = SoulEnergy.MAX
		if not m.tree_ledger.is_occupied(HOME, anchor):
			break
		m._chop_tree(anchor)
	_check("⑤g 그루터기 제거 → 프롭 충돌 1개 해제(통과 O — reclaim 결 skip-filter)",
		not m.tree_ledger.is_occupied(HOME, anchor)
		and _live_shapes(m) == solids_before - 1)
	m._rebuild_region(FOREST)

	# ⑩-f main 세이브·재부팅 라운드트립.
	var fp: String = _fingerprint(m.tree_ledger)
	m._save_game()
	await _despawn(m)
	var m2: Node = await _new_main()
	_check("⑩f main 세이브 왕복(재부팅 후 같은 원장 — 벤 나무가 안 돌아온다)",
		_fingerprint(m2.tree_ledger) == fp and fp != "")
	m2._rebuild_region(FOREST)
	_check("⑩g 복원 후 재빌드에도 벤 자리 유지",
		m2._grid[inner.y][inner.x] == m2.GROUND and _walkable(m2, inner))
	await _despawn(m2)
	cleaner.delete_save()

	# ── 아이템 로스터 ──
	print("── 신규 아이템 6종 ──")
	var items := [ItemCatalog.WOOD, ItemCatalog.HARDWOOD, ItemCatalog.SAP,
		ItemCatalog.SEED_JEOSEUNGSOL, ItemCatalog.SEED_MYEONGDANPUNG, ItemCatalog.SEED_NEOKCHAM]
	var item_ok := true
	for id in items:
		if not ItemCatalog.has_item(id) or ItemCatalog.category_of(id) != ItemCatalog.CAT_MATERIAL \
				or ItemCatalog.name_of(id) == "" or ItemCatalog.price_of(id) <= 0:
			item_ok = false
	_check("아이템 6종 등록·CAT_MATERIAL·이름·가격", item_ok)
	_check("원목 < 단단한 원목(경목이 더 비싸다)",
		ItemCatalog.price_of(ItemCatalog.WOOD) < ItemCatalog.price_of(ItemCatalog.HARDWOOD))
	_check("석화 목재와 별개 유지(개간 1회성 ↔ 재성장 자원 역할 분리)",
		ItemCatalog.PETRIFIED_WOOD != ItemCatalog.WOOD
		and ItemCatalog.name_of(ItemCatalog.PETRIFIED_WOOD) == "석화 목재")
	var seed_map_ok := true
	for sp in TreeLedger.SPECIES:
		var sid := TreeLedger.seed_item_for(sp)
		if sid == "" or not ItemCatalog.has_item(sid) or TreeLedger.species_name(sp) == "":
			seed_map_ok = false
	_check("종 3 ↔ 씨앗 3 매핑(저승솔·명단풍·넋참나무)",
		seed_map_ok and TreeLedger.SPECIES.size() == 3)

	print("── 결과 ──")
	if _fail == 0:
		print("✔ 전부 통과")
	else:
		print("✘ 실패 %d건" % _fail)
	quit(0 if _fail == 0 else 1)

# 그루터기는 advance_day에서 단계가 안 오른다(치워야 자리가 난다).
func _stump_frozen() -> bool:
	var led := TreeLedger.new()
	var t := Vector2i(2, 2)
	led.seed_region(RegionCatalog.JEOSEUNG_FOREST, [t])
	for i in TreeLedger.HP_MATURE:
		led.chop(RegionCatalog.JEOSEUNG_FOREST, t, 1)
	for d in range(1, 60):
		led.advance_day(d)
	return led.is_stump(RegionCatalog.JEOSEUNG_FOREST, t)

# free_cb 없이 굴리면 안식 자체 파종이 안 일어난다(슬롯 수 불변).
func _no_seed_without_cb(home: String) -> bool:
	var led := TreeLedger.new()
	led.seed_region(home, [Vector2i(30, 30)])
	for d in range(1, 60):
		led.advance_day(d)
	return led.slot_count(home) == 1

# 프롭 충돌체 중 *살아 있는* 것만 센다 — _rebuild_prop_collision이 queue_free로 옛 것을 치우므로
# 같은 프레임에 get_child_count를 그냥 읽으면 삭제 대기분까지 잡혀 값이 부푼다.
func _live_shapes(m: Node) -> int:
	var n := 0
	for c in m._prop_body.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n

# 인벤토리에서 이 아이템이 든 슬롯 index(-1 = 없음).
func _slot_of(m: Node, id: String) -> int:
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == id:
			return i
	return -1

# 이 구역 원장의 종 가짓수(한 종으로 쏠리지 않는지).
func _species_spread(led: TreeLedger, region: String) -> int:
	var seen: Dictionary = {}
	for t: Vector2i in led.tiles(region):
		seen[led.species_at(region, t)] = true
	return seen.size()
