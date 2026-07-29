extends SceneTree
# ★[S4-T8 / ADR-0062 결정 9] 곁들이 3건(덤불 열매·저승 이끼·해변 채집) 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ① 덤불 열매 — 절기 창 게이트(피안 15~18 / 망연 8~11 밖에선 롤 자체가 없다) · 밤 20% 결정성
#      (같은 day 재현·day가 다르면 다른 결과) · 채집 레벨 수량 계단(1/2/3) · **흔들기 혼력 0**
#      (ADR-0033 #1) · 창을 벗어나면 남은 열매도 진다 · 덤불 자리가 걸을 수 있고 빈터 존 밖이다.
#   ② 저승 이끼 — 착생 결정 롤 재현 · **성숙목 한정**(유목·그루터기·큰 장애물·빈 슬롯 제외) ·
#      낫 1회 채취(산출 1 · XP 1 · 혼력 과금) · 채취 후 쿨다운(MOSS_COOLDOWN일) 안엔 재착생 0.
#   ③ 해변 채집 — 황천해 백사장 존 배선 · **절기 무관**(4절기 전부 같은 4종) · 상한 6·7일 리셋 등
#      기존 ForageSpawns 문법 그대로(신규 규칙 0) · 존 35칸이 실그리드에서 전부 걸을 수 있다.
#   ④ 세이브 — 덤불 원장 왕복 · 이끼 플래그·쿨다운 왕복 · **키 없는 구세이브 하위호환**(둘 다) ·
#      main 세이브·재부팅 왕복.
#   ⑤ 아이템 — 신규 3종(넋딸기·잿빛복분자·저승 이끼) 등록·카테고리·가격 · **기존 로스터와 id 충돌 0**.
#
# 실행: ./run_tests.sh forage_extras   (헤드리스는 반드시 game/에서 · 순차)

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

# 외부에서 걸을 수 있는 칸인가(forage_spawn_test 동형).
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return id != m.WALL and id != m.WATER and id != m.TREE and id != m.VOID

# 덤불 원장 상태를 비교 가능한 정렬 문자열로(결정성·라운드트립 판정).
func _fingerprint(led: BerryBushes, regions: Array) -> String:
	var rows: Array = []
	for region: String in regions:
		for t: Vector2i in led.tiles(region):
			rows.append("%s:%d,%d" % [region, t.x, t.y])
	rows.sort()
	return "|".join(rows)

func _select(m: Node, id: String) -> void:
	m.inventory.add_item(id, 1)   # 유니크 도구는 이미 있으면 무시(idempotent)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S4-T8 곁들이 3건(덤불 열매·저승 이끼·해변 채집) 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var FOREST := RegionCatalog.JEOSEUNG_FOREST
	var MIHOK := RegionCatalog.MIHOK_FOREST
	var BEACH := RegionCatalog.HWANGCHEONHAE

	# ── ⑤ 신규 아이템 3종 ──
	print("── ⑤ 신규 아이템 ──")
	var new_ids := [ItemCatalog.NEOK_DALGI, ItemCatalog.JAETBIT_BOKBUNJA, ItemCatalog.JEOSEUNG_IKKI]
	var reg_ok := true
	for id in new_ids:
		if not ItemCatalog.has_item(id) or ItemCatalog.name_of(id) == "" or ItemCatalog.price_of(id) <= 0:
			reg_ok = false
	_check("⑤a 3종 ItemCatalog 등록·이름·가격(has_item 유효 판정)", reg_ok)
	_check("⑤b 열매 2종 = 품질 유차원 CAT_HARVEST(채집물 결)",
		ItemCatalog.category_of(ItemCatalog.NEOK_DALGI) == ItemCatalog.CAT_HARVEST
		and ItemCatalog.category_of(ItemCatalog.JAETBIT_BOKBUNJA) == ItemCatalog.CAT_HARVEST)
	_check("⑤c 저승 이끼 = 품질 **무**차원 CAT_MATERIAL(원목·수액 결 — 품질은 줍기의 축)",
		ItemCatalog.category_of(ItemCatalog.JEOSEUNG_IKKI) == ItemCatalog.CAT_MATERIAL)
	_check("⑤d 가격 잠정값(넋딸기 20 · 잿빛복분자 30 · 저승 이끼 8)",
		ItemCatalog.price_of(ItemCatalog.NEOK_DALGI) == 20
		and ItemCatalog.price_of(ItemCatalog.JAETBIT_BOKBUNJA) == 30
		and ItemCatalog.price_of(ItemCatalog.JEOSEUNG_IKKI) == 8)
	# id 충돌 — 기존 로스터(스폰 채집물·작물·과일·어종·산물·재료·통용물) 어디와도 안 겹친다.
	var collide := ""
	for id in new_ids:
		var hits := 0
		if ItemCatalog.FORAGEABLES.has(id):
			hits += 1
		if ItemCatalog.MATERIALS.has(id):
			hits += 1
		if CropCatalog.has_crop(id) or FruitTreeCatalog.has(id) or FishCatalog.has(id) \
				or AnimalCatalog.has_product(id) or ItemCatalog.POT_GOODS.has(id):
			hits += 1
		if hits != 1:
			collide = String(id)
	_check("⑤e 신규 3종 id ↔ 기존 로스터 충돌 0(정확히 한 표에만 산다)", collide == "")
	_check("⑤f 저승산딸기(기존 유화절 일반종)와 별종 — id·이름 모두 다르다",
		ItemCatalog.NEOK_DALGI != ItemCatalog.JEOSEUNG_SANDALGI
		and ItemCatalog.name_of(ItemCatalog.NEOK_DALGI) != ItemCatalog.name_of(ItemCatalog.JEOSEUNG_SANDALGI))
	_check("⑤g 덤불 열매는 스폰 로스터 22종 밖(빈터에 안 돋는다 — 획득 경로 배타)",
		ForageSpawns.all_species().size() == 22
		and not ForageSpawns.all_species().has(ItemCatalog.NEOK_DALGI)
		and not ForageSpawns.all_species().has(ItemCatalog.JAETBIT_BOKBUNJA))

	# ── ① 덤불 열매(순수 원장) ──
	print("── ① 덤불 절기 창 ──")
	_check("①a 창 = 피안절 15~18일 · 망연절 8~11일(스타듀 1:1)",
		BerryBushes.berry_for_day(15) == ItemCatalog.NEOK_DALGI
		and BerryBushes.berry_for_day(18) == ItemCatalog.NEOK_DALGI
		and BerryBushes.berry_for_day(28 * 2 + 8) == ItemCatalog.JAETBIT_BOKBUNJA
		and BerryBushes.berry_for_day(28 * 2 + 11) == ItemCatalog.JAETBIT_BOKBUNJA)
	_check("①b 창 밖은 열매 없음(경계 하루 앞뒤 포함)",
		BerryBushes.berry_for_day(14) == "" and BerryBushes.berry_for_day(19) == ""
		and BerryBushes.berry_for_day(28 * 2 + 7) == "" and BerryBushes.berry_for_day(28 * 2 + 12) == "")
	# 1년(112일) 중 창은 정확히 8일이다(나흘 × 2).
	var window_days := 0
	for d in range(1, 113):
		if BerryBushes.in_window(d):
			window_days += 1
	_check("①c 1년 중 창 = 8일(나흘 × 2 — 희소성이 곧 이 시스템의 맛)", window_days == 8)

	print("── ① 밤 결실 롤 ──")
	var bushes := {FOREST: [Vector2i(16, 12), Vector2i(24, 12), Vector2i(41, 13), Vector2i(46, 35)],
		MIHOK: [Vector2i(46, 6), Vector2i(26, 33), Vector2i(34, 33)]}
	_check("①d 결실 확률 상수 = 20%(ADR-0062 결정 9 ㉠)", BerryBushes.BERRY_CHANCE == 0.20)
	# 창 밖 날엔 롤 자체가 없다.
	var out_led := BerryBushes.new()
	var out_res: Dictionary = out_led.advance_day(5, bushes)
	_check("①e 창 밖 날 = 결실 0 · item \"\"(롤 자체가 없다)",
		out_led.total() == 0 and out_res["berried"].is_empty() and String(out_res["item"]) == "")
	# 창 안 날 — 같은 day를 두 번 굴리면 같은 덤불에 달린다(전역 randf 금지의 실증).
	var a := BerryBushes.new()
	var b := BerryBushes.new()
	a.advance_day(16, bushes)
	b.advance_day(16, bushes)
	_check("①f 같은 day 재현(결정 롤 — day+구역+좌표 해시)",
		_fingerprint(a, [FOREST, MIHOK]) == _fingerprint(b, [FOREST, MIHOK]))
	var day_diff := false
	for d in [15, 16, 17, 18]:
		var one := BerryBushes.new()
		one.advance_day(d, bushes)
		if _fingerprint(one, [FOREST, MIHOK]) != _fingerprint(a, [FOREST, MIHOK]):
			day_diff = true
	_check("①g day가 다르면 판도 다르다(고정 배치 아님)", day_diff)
	# 창 나흘을 통째로 굴리면 7그루 중 적어도 몇은 달린다(스폰율이 죽어 있지 않음).
	var win := BerryBushes.new()
	for d in range(15, 19):
		win.advance_day(d, bushes)
	_check("①h 창 나흘(15~18)이면 실제로 열매가 달린다 — %d그루" % win.total(), win.total() > 0)
	_check("①i 한 덤불에 열매는 하나뿐(안 딴 열매 위에 겹쳐 안 달린다)", win.total() <= 7)
	# 창을 벗어나면 남은 열매도 진다.
	var fell: Dictionary = win.advance_day(19, bushes)
	_check("①j 창을 벗어나면 남은 열매 전량 소멸(절기 전환 결) — cleared %d" % int(fell["cleared"]),
		win.total() == 0 and int(fell["cleared"]) > 0)

	print("── ① 수량 계단 ──")
	_check("①k L0~3 = 1개(무게이트 — L0도 반드시 1개는 나온다, ADR-0008)",
		ForageSkill.bush_yield(0) == 1 and ForageSkill.bush_yield(3) == 1)
	_check("①l L4~7 = 2개", ForageSkill.bush_yield(4) == 2 and ForageSkill.bush_yield(7) == 2)
	_check("①m L8+ = 3개", ForageSkill.bush_yield(8) == 3 and ForageSkill.bush_yield(10) == 3)
	_check("①n 개당 1XP 상수(ForageSkill.BUSH_SHAKE_XP)", ForageSkill.BUSH_SHAKE_XP == 1)

	# ── ② 저승 이끼(순수 원장) ──
	print("── ② 저승 이끼 ──")
	_check("②a 상수 — 착생 15% · 쿨다운 3일(잠정)",
		TreeLedger.MOSS_CHANCE == 0.15 and TreeLedger.MOSS_COOLDOWN == 3)
	# 성숙목 6·유목 1·그루터기 1·큰 장애물 1을 깔고 여러 날 굴려 "성숙목에만 낀다"를 본다.
	var tl := TreeLedger.new()
	var mature_tiles: Array = []
	for i in 6:
		mature_tiles.append(Vector2i(10 + i, 20))
	tl.seed_region(FOREST, mature_tiles)                       # 전부 stage 5(성숙)
	tl.seed_region(MIHOK, [Vector2i(5, 5)], 2)                 # 유목(stage 2)
	tl.seed_large(MIHOK, [Vector2i(7, 7)], TreeLedger.KIND_LARGE_STUMP)
	# 그루터기 하나 만들기(성숙목 한 그루를 정타로 눕힌다).
	var stump_t := Vector2i(10, 20)
	for _i in 20:
		if tl.is_stump(FOREST, stump_t):
			break
		tl.chop(FOREST, stump_t, 1, 0)
	_check("②b 준비 — 그루터기 1 · 유목 1 · 큰 그루터기 1",
		tl.is_stump(FOREST, stump_t) and tl.stage_at(MIHOK, Vector2i(5, 5)) == 2
		and tl.is_large(MIHOK, Vector2i(7, 7)))
	var non_mature := false
	for d in range(2, 40):
		tl.advance_day(d)
		if tl.has_moss(FOREST, stump_t) or tl.has_moss(MIHOK, Vector2i(7, 7)):
			non_mature = true
		if tl.has_moss(MIHOK, Vector2i(5, 5)) and not tl.is_mature(MIHOK, Vector2i(5, 5)):
			non_mature = true
	_check("②c 이끼는 **성숙목에만** 낀다(그루터기·큰 장애물·유목 0)", not non_mature)
	var mossed := 0
	for t: Vector2i in tl.tiles(FOREST):
		if tl.has_moss(FOREST, t):
			mossed += 1
	_check("②d 성숙목엔 실제로 낀다(착생률이 죽어 있지 않음) — %d그루" % mossed, mossed > 0)
	# 결정성 — 같은 날짜 시퀀스면 같은 나무에 낀다.
	var tl2 := TreeLedger.new()
	tl2.seed_region(FOREST, mature_tiles)
	var tl3 := TreeLedger.new()
	tl3.seed_region(FOREST, mature_tiles)
	for d in range(2, 12):
		tl2.advance_day(d)
		tl3.advance_day(d)
	_check("②e 착생 결정 롤 재현(같은 시퀀스 = 같은 나무)",
		tl2.moss_tiles(FOREST) == tl3.moss_tiles(FOREST) and not tl2.moss_tiles(FOREST).is_empty())
	# 쿨다운 — 벗긴 뒤 MOSS_COOLDOWN일 안엔 자격이 없다.
	var mt: Vector2i = tl2.moss_tiles(FOREST)[0]
	_check("②f 벗기기 전엔 has_moss 참 · can_moss 거짓(이미 껴 있으니 롤 대상 아님)",
		tl2.has_moss(FOREST, mt) and not tl2.can_moss(FOREST, mt, 12))
	_check("②g scrape_moss = true · 플래그 내려감", tl2.scrape_moss(FOREST, mt, 12) and not tl2.has_moss(FOREST, mt))
	_check("②h 빈손 재채취 = false(멱등 — 없는 이끼를 또 벗기지 않는다)", not tl2.scrape_moss(FOREST, mt, 12))
	_check("②i 쿨다운 %d일 안엔 재착생 자격 없음" % TreeLedger.MOSS_COOLDOWN,
		not tl2.can_moss(FOREST, mt, 12) and not tl2.can_moss(FOREST, mt, 14)
		and tl2.can_moss(FOREST, mt, 15))
	var cooled := false
	for d in range(13, 15):
		tl2.advance_day(d)
		if tl2.has_moss(FOREST, mt):
			cooled = true
	_check("②j 쿨다운 중엔 밤 롤이 돌아도 안 낀다", not cooled)

	# ── ③ 해변 채집(존 배선) ──
	print("── ③ 해변 존 ──")
	var zones: Dictionary = ForageSpawns.zones()
	_check("③a 황천해가 스폰 구역에 편입(존 1곳 · KIND_BEACH)",
		zones.has(BEACH) and zones[BEACH].size() == 1
		and String(zones[BEACH][0]["kind"]) == ForageSpawns.KIND_BEACH
		and ForageSpawns.spawn_regions().has(BEACH))
	_check("③b 존 문법 = 기존 그대로(7×5 · 후보 35칸 · 상한 6 · 리셋 7일)",
		ForageSpawns.candidates(BEACH).size() == 35
		and ForageSpawns.REGION_CAP == 6 and ForageSpawns.RESET_DAYS == 7)
	# 절기 무관 — 4절기 전부 같은 해변 4종.
	var beach_same := true
	for s in 4:
		if ForageSpawns.species_for(ForageSpawns.KIND_BEACH, s) != ForageSpawns.species_for(ForageSpawns.KIND_BEACH, 0):
			beach_same = false
	_check("③c 해변 4종 = 절기 무관(조개·산호)", beach_same
		and ForageSpawns.species_for(ForageSpawns.KIND_BEACH, 0).size() == 4)
	# 1년 굴려 상한·존·종을 한꺼번에 본다(기존 문법 준수의 실증).
	var year := ForageSpawns.new()
	var over := false
	var peak := 0
	var wrong_species := 0
	var outside := 0
	var beach_seen := false
	for d in range(1, 113):
		year.advance_day(d, GameClock.season_index_for_day(d))
		peak = maxi(peak, year.count(BEACH))
		if year.count(BEACH) > ForageSpawns.REGION_CAP:
			over = true
		for t: Vector2i in year.tiles(BEACH):
			beach_seen = true
			if ForageSpawns.zone_kind_at(BEACH, t) != ForageSpawns.KIND_BEACH:
				outside += 1
			elif not ForageSpawns.species_for(ForageSpawns.KIND_BEACH, 0).has(year.species_at(BEACH, t)):
				wrong_species += 1
	_check("③d 1년 내내 해변에 채집물이 돋는다(절기 정지 없음)", beach_seen and peak > 0)
	_check("③e 상한 6 초과 0회 · 존 밖 0 · 해변 4종 밖 0", not over and outside == 0 and wrong_species == 0)
	# 7일 주기 리셋이 해변에도 그대로 걸린다.
	var cyc := ForageSpawns.new()
	for d in range(1, 8):
		cyc.advance_day(d, 0)
	var before_cnt := cyc.count(BEACH)
	var res8: Dictionary = cyc.advance_day(8, 0)
	_check("③f day8 주기 리셋이 해변에도 적용(미수집분 삭제 후 재시드)",
		bool(res8["reset"]) and int(res8["cleared"]) >= before_cnt)

	# ── main 배선 ──
	print("── main 배선 ──")
	var m: Node = await _new_main()
	_check("⓪a berry_bushes 원장 배선(RefCounted)", m.berry_bushes != null)
	_check("⓪b 덤불 지도 = 저승 4 · 미혹 3(숲 2구역 전용)",
		m.bush_tiles_for(FOREST).size() == 4 and m.bush_tiles_for(MIHOK).size() == 3
		and m.bush_tiles_for(RegionCatalog.HOME).is_empty())

	# ① 덤불 자리 — 걸을 수 있고, 빈터 존 밖이다(같은 칸에서 줍기와 안 겹친다).
	m._rebuild_region(FOREST)
	var bush_blocked := 0
	var bush_in_zone := 0
	for t: Vector2i in m.bush_tiles_for(FOREST):
		if not _walkable(m, t):
			bush_blocked += 1
		if ForageSpawns.zone_kind_at(FOREST, t) != "":
			bush_in_zone += 1
	_check("①o 저승 숲 덤불 4그루 전부 걸을 수 있음(통행 벽 아님 — flood-fill 불변)", bush_blocked == 0)
	_check("①p 저승 숲 덤불이 빈터 존 밖(줍기와 칸 충돌 0)", bush_in_zone == 0)

	# ①⑥ 흔들기 — 혼력 0 · 수량 계단 · XP.
	m.clock.day = 16                                   # 피안절 16일 = 넋딸기 창 안
	var bt: Vector2i = m.bush_tiles_for(FOREST)[0]
	m.berry_bushes.set_berry(FOREST, bt, true)
	m._target = bt
	m._foraging_xp = 0
	m._professions = {}
	var soul_before: int = m.energy.current
	var inv_before: int = m.inventory.count_of(ItemCatalog.NEOK_DALGI)
	m._shake_bush(bt)
	_check("①q 흔들기 = 혼력 0(ADR-0033 #1 — 줍기 결)", m.energy.current == soul_before)
	_check("①r L0 흔들기 = 넋딸기 1개",
		m.inventory.count_of(ItemCatalog.NEOK_DALGI) - inv_before == 1)
	_check("①s 흔든 덤불은 열매가 없어진다", not m.berry_bushes.has_berry(FOREST, bt))
	_check("①t 채집 XP = 개당 1 × 1개", m._foraging_xp == ForageSkill.BUSH_SHAKE_XP)
	_check("①u 빈 덤불 재흔들기 = 무동작", m.berry_bushes.shake(FOREST, bt, 16) == "")
	# L8 = 3개(수량 계단이 실동작에 실린다).
	m._foraging_xp = int(FarmSkill.XP_THRESHOLDS[7])   # L8 진입
	var xp_before: int = m._foraging_xp
	var bt2: Vector2i = m.bush_tiles_for(FOREST)[1]
	m.berry_bushes.set_berry(FOREST, bt2, true)
	m._target = bt2
	var inv2: int = m.inventory.count_of(ItemCatalog.NEOK_DALGI)
	m._shake_bush(bt2)
	_check("①v L8 흔들기 = 3개(수량 계단 실효)",
		m.inventory.count_of(ItemCatalog.NEOK_DALGI) - inv2 == 3
		and m._skill_level(ProfessionCatalog.FORAGING) >= 8)
	_check("①w XP도 개수만큼(3 × 1)", m._foraging_xp - xp_before == 3)
	# 창 밖에선 프롬프트가 "철이 아니다"를 밝힌다(빈손이 벌칙으로 안 읽히게).
	m.clock.day = 5
	_check("①x 창 밖 프롬프트 = 철 안내", m._bush_prompt(bt).find("철이 아니다") >= 0)
	m.clock.day = 16
	_check("①y 창 안·열매 없음 프롬프트 = 밤 안내", m._bush_prompt(bt).find("밤새") >= 0)

	# ② 이끼 — 성숙목에 낫 1회.
	var forest_mature := Vector2i(-1, -1)
	for t: Vector2i in m.tree_ledger.tiles(FOREST):
		if m.tree_ledger.is_mature(FOREST, t):
			forest_mature = t
			break
	_check("②k 저승 숲에 원장 성숙목이 있다(무대 시드)", forest_mature != Vector2i(-1, -1))
	m.tree_ledger.set_moss(FOREST, forest_mature, true)
	m._target = forest_mature
	_select(m, ItemCatalog.SCYTHE)
	m._foraging_xp = 0
	var ikki_before: int = m.inventory.count_of(ItemCatalog.JEOSEUNG_IKKI)
	var soul2: int = m.energy.current
	m._scrape_moss(forest_mature)
	_check("②l 낫 1회 = 저승 이끼 1개",
		m.inventory.count_of(ItemCatalog.JEOSEUNG_IKKI) - ikki_before == 1)
	_check("②m 채취 후 이끼가 없어진다", not m.tree_ledger.has_moss(FOREST, forest_mature))
	_check("②n 채집 XP = 곁들이 최소 1", m._foraging_xp == ForageSkill.MOSS_SCRAPE_XP)
	_check("②o 혼력 = 과금(나무 작업 — 벌목과 같은 고정 COST_PER_ACTION)",
		m.energy.current == soul2 - SoulEnergy.COST_PER_ACTION)
	# 낫이 아니면 무동작(자동 분기 없음 — ADR-0024 §2).
	m.tree_ledger.set_moss(FOREST, forest_mature, true)
	_select(m, ItemCatalog.AXE)
	var soul3: int = m.energy.current
	var ikki2: int = m.inventory.count_of(ItemCatalog.JEOSEUNG_IKKI)
	m._scrape_moss(forest_mature)
	_check("②p 도끼로는 이끼 채취 무동작(도구 배타 · 혼력 불변)",
		m.tree_ledger.has_moss(FOREST, forest_mature) and m.energy.current == soul3
		and m.inventory.count_of(ItemCatalog.JEOSEUNG_IKKI) == ikki2)

	# ③ 백사장 존이 실그리드에서 전부 걸을 수 있다.
	m._rebuild_region(BEACH)
	_check("③g 구역 = 황천해", m._region == BEACH)
	var beach_blocked := 0
	for t: Vector2i in ForageSpawns.candidates(BEACH):
		if not _walkable(m, t):
			beach_blocked += 1
	_check("③h 백사장 존 %d칸 전부 걸을 수 있음(모래 — 부두·나룻배·생선가게 비껴감)"
		% ForageSpawns.candidates(BEACH).size(), beach_blocked == 0)
	# 해변에서도 줍기 사슬이 그대로 돈다(혼력 0 · 인벤 · XP).
	var bspot: Vector2i = ForageSpawns.candidates(BEACH)[0]
	m.forage_spawns.load_save({"tiles": {BEACH: [[bspot.x, bspot.y, ItemCatalog.NEOK_SEONGGAE]]}})
	m._target = bspot
	m._foraging_xp = 0
	var soul4: int = m.energy.current
	var seong_before: int = m.inventory.count_of(ItemCatalog.NEOK_SEONGGAE)
	m._pick_forage(bspot)
	_check("③i 해변 줍기 = 기존 사슬 그대로(인벤 +1 이상 · XP 7 · 혼력 0)",
		m.inventory.count_of(ItemCatalog.NEOK_SEONGGAE) - seong_before >= 1
		and m._foraging_xp == ForageSkill.PICK_XP and m.energy.current == soul4)

	# ── ④ 세이브 ──
	print("── ④ 세이브 ──")
	var src := BerryBushes.new()
	for d in range(15, 19):
		src.advance_day(d, bushes)
	var dst := BerryBushes.new()
	dst.load_save(src.to_save())
	_check("④a 덤불 원장 직렬화 왕복(구역·좌표 보존)",
		_fingerprint(dst, [FOREST, MIHOK]) == _fingerprint(src, [FOREST, MIHOK]) and src.total() > 0)
	var empty := BerryBushes.new()
	empty.load_save({})
	_check("④b 키 없는 구세이브 = 열매 0(하위호환)", empty.total() == 0)
	var junk := BerryBushes.new()
	junk.load_save({"berries": {FOREST: [[16, 12], ["x"], [24]]}})
	_check("④c 손상 항목은 조용히 버린다", junk.total() == 1 and junk.has_berry(FOREST, Vector2i(16, 12)))
	# 이끼 플래그·쿨다운 왕복 + 이끼 키 없는 구세이브(7항 옛 포맷).
	var mt_src := TreeLedger.new()
	mt_src.seed_region(FOREST, [Vector2i(10, 20), Vector2i(11, 20)])
	mt_src.set_moss(FOREST, Vector2i(10, 20), true)
	mt_src.scrape_moss(FOREST, Vector2i(11, 20), 0)     # 플래그는 없고 쿨다운만 남는 경로 방어
	mt_src.set_moss(FOREST, Vector2i(11, 20), true)
	mt_src.scrape_moss(FOREST, Vector2i(11, 20), 9)
	var mt_dst := TreeLedger.new()
	mt_dst.load_save(mt_src.to_save())
	_check("④d 이끼 플래그 왕복", mt_dst.has_moss(FOREST, Vector2i(10, 20))
		and not mt_dst.has_moss(FOREST, Vector2i(11, 20)))
	_check("④e 이끼 쿨다운(mossday) 왕복 — day9 채취분은 day11엔 자격 없고 day12엔 있다",
		not mt_dst.can_moss(FOREST, Vector2i(11, 20), 11)
		and mt_dst.can_moss(FOREST, Vector2i(11, 20), 12))
	var old_fmt := TreeLedger.new()
	old_fmt.load_save({"trees": {FOREST: [[10, 20, TreeLedger.SP_PINE, 5, 10, 0, 1]]}})
	_check("④f 이끼 키 없는 옛 7항 세이브 = mossday 0으로 읽힘(하위호환 — 즉시 자격)",
		old_fmt.has_moss(FOREST, Vector2i(10, 20)) and old_fmt.slot_count(FOREST) == 1)

	# main 세이브·재부팅 왕복.
	m.clock.day = 16
	m.berry_bushes.load_save(src.to_save())
	var fp: String = _fingerprint(m.berry_bushes, [FOREST, MIHOK])
	m.tree_ledger.set_moss(FOREST, forest_mature, true)
	m._save_game()
	await _despawn(m)
	var m2: Node = await _new_main()
	_check("④g main 세이브 왕복 — 덤불 열매 배치 복원",
		_fingerprint(m2.berry_bushes, [FOREST, MIHOK]) == fp and fp != "")
	_check("④h main 세이브 왕복 — 이끼 플래그 복원", m2.tree_ledger.has_moss(FOREST, forest_mature))
	await _despawn(m2)
	cleaner.delete_save()

	print("── 결과 ──")
	if _fail == 0:
		print("✔ 전부 통과")
	else:
		print("✘ 실패 %d건" % _fail)
	quit(0 if _fail == 0 else 1)
