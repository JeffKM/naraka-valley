extends SceneTree
# ★[S5-T2 / ADR-0063 결정 2·9] 광물 노드·드랍·채광 숙련 검증(ephemeral).
#
# 두 층위를 본다:
#   (A) 순수 규칙 — MineFloors 노드 스캐터(결정성·밴드 게이팅·rocks 불변)·ItemCatalog 광물 로스터·
#       MiningSkill(XP 테이블·혼력 계수·크리·드랍 해석). main 없이 굴린다(빠르고 흔들림 0).
#   (B) main 배선 — 갱도 층에서 광맥을 실제로 캐 인벤·XP·혼력이 움직이는 라이브 사슬, 스킬 탭 4행,
#       mining_xp 세이브/로드 왕복.
#
# ★ 핵심 불변식:
#   ① 노드 스캐터가 결정적이다(같은 day·층이면 몇 번을 굴려도 같은 배치).
#   ② **S5-T1 배치 불변** — 노드 추가가 앞 롤(템플릿·방·입구·사다리·돌)을 한 칸도 안 흔든다.
#      T1 시점에 뜬 골든 서명을 그대로 박아 대조한다(RNG 스트림 앞에 무언가 끼면 즉시 터진다).
#   ③ 밴드 게이팅 — 1층에 유철·황천금 0 / 21층+ 유철 / 41층+ 황천금 / 명부금강 31층+ / 알돌 2종 분리.
#   ④ 다타수 진행 → 파괴 → 드랍 적재 → XP 적립(중간 타엔 산출 0).
#   ⑤ 크리 채굴이 결정적이고 Lv0 = 0% · Lv10 = 10%다.
#   ⑥ 혼력 감산 — Lv0 = 10 · Lv10 = 7(3%/lv).
#   ⑦ mining_xp 세이브/로드 왕복(구세이브 = 0, 무막힘).
#   ⑧ 광물 아이템 13종 등록·가격·카테고리 + **노드 id = 아이템 id** 대조(두 로스터 분기 방지).
#   ⑨ 숙련 탭 4행(농사·채집·낚시·채광).
# 실행: ./run_tests.sh mining

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

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

func _slot_of(inv: Object, id: String) -> int:
	for i in range(inv.slots.size()):
		if inv.id_at(i) == id:
			return i
	return -1

# 노드 dict의 정규 서명(키 정렬 — dict 키 순서에 안 기댄다).
func _nodes_sig(layout: Dictionary) -> String:
	var nodes: Dictionary = layout.get("nodes", {})
	var keys: Array = nodes.keys()
	keys.sort()
	var parts: Array[String] = []
	for k: Vector2i in keys:
		parts.append("%s=%s" % [k, nodes[k]])
	return " ".join(parts)

# 여러 날·층을 훑어 나온 노드 종 집합.
func _kinds_over(days: Array, floors: Array) -> Dictionary:
	var seen: Dictionary = {}
	for d in days:
		for f in floors:
			var l := MineFloors.generate(int(d), int(f))
			if l.is_empty():
				continue
			for k in (l["nodes"] as Dictionary).values():
				seen[String(k)] = true
	return seen

func _initialize() -> void:
	print("══ S5-T2 광물 노드·드랍·채광 숙련 검증(ADR-0063 결정 2·9) ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.mining_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 노드 스캐터 결정성 ─────────────────────────────────────────────────
	var det_ok := true
	var any_node := 0
	for pair in [[5, 1], [5, 21], [5, 41], [9, 7], [1, 31], [3, 60]]:
		var a := MineFloors.generate(int(pair[0]), int(pair[1]))
		var b := MineFloors.generate(int(pair[0]), int(pair[1]))
		if _nodes_sig(a) != _nodes_sig(b):
			det_ok = false
		any_node += (a["nodes"] as Dictionary).size()
	_check("① 같은 day·층 노드 배치 2회 동일(결정성)", det_ok)
	_check("①b 노드가 실제로 깔린다(6개 표본 합계 > 0)", any_node > 0)
	# 노드 키는 항상 돌 좌표의 부분집합이다(노드 = 특별한 돌 — 신규 좌표계 0).
	var subset_ok := true
	var count_ok := true
	for d in [1, 2, 3, 4]:
		for f in range(1, MineFloors.MAX_FLOOR + 1):
			var l := MineFloors.generate(d, f)
			var rocks: Dictionary = {}
			for r: Vector2i in l["rocks"]:
				rocks[r] = true
			var nodes: Dictionary = l["nodes"]
			for t: Vector2i in nodes:
				if not rocks.has(t):
					subset_ok = false
			if nodes.size() > MineFloors.NODE_MAX:
				count_ok = false
	_check("①c 노드 키 ⊆ 돌 좌표(4일 × 60층)", subset_ok)
	_check("①d 층당 노드 수 ≤ 상한(%d)" % MineFloors.NODE_MAX, count_ok)
	# 다른 날 = 다른 노드 배치(매일 리필).
	var node_diff := 0
	for f in range(1, 21):
		if _nodes_sig(MineFloors.generate(1, f)) != _nodes_sig(MineFloors.generate(2, f)):
			node_diff += 1
	_check("①e 다른 day = 다른 노드 배치(20층 중 20)", node_diff == 20)

	# ── ② S5-T1 배치 불변(골든 서명 — 노드가 RNG 스트림 앞을 안 흔든다) ──────
	# 값은 T2 착수 전(노드 스캐터 도입 직전) 생성기에서 그대로 떠 왔다. 노드 롤이 ⑦(맨 뒤)이
	# 아니라 어디든 앞에 끼면 이 여섯 줄이 전부 깨진다 = 전 층 배치 파손의 조기 경보다.
	var golden := [
		#  day floor  template   rect                                entrance    ladder      rocks  str(rocks).hash()
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
	_check("② T1 골든 서명 불변 — 템플릿·방·입구·사다리·돌 수(6표본)", golden_ok)
	_check("②b T1 골든 서명 불변 — 돌 좌표 전량 해시(6표본)", golden_hash_ok)

	# ── ③ 밴드 게이팅 ────────────────────────────────────────────────────────
	var band1 := _kinds_over(range(1, 31), range(1, 21))     # 잿길(1~20)
	_check("③ 잿길(1~20)에 유철 0", not band1.has(MineFloors.N_YUCHEOL))
	_check("③b 잿길에 황천금 0", not band1.has(MineFloors.N_HWANGCHEONGEUM))
	_check("③c 잿길에 명옥·염주석·명부금강 0",
		not band1.has(MineFloors.N_GEM_MYEONGOK) and not band1.has(MineFloors.N_GEM_YEOMJUSEOK) \
		and not band1.has(MineFloors.N_GEM_MYEONGBU))
	_check("③d 잿길에 명동·혼탄·넋수정·넋알돌은 나온다",
		band1.has(MineFloors.N_MYEONGDONG) and band1.has(MineFloors.N_HONTAN) \
		and band1.has(MineFloors.N_GEM_NEOKSUJEONG) and band1.has(MineFloors.N_GEODE_NEOKAL))
	var band2 := _kinds_over(range(1, 31), range(21, 41))    # 넋골(21~40)
	_check("③e 넋골(21~40)에 유철 출현", band2.has(MineFloors.N_YUCHEOL))
	_check("③f 넋골에 황천금 0(41층+ 전용)", not band2.has(MineFloors.N_HWANGCHEONGEUM))
	_check("③g 넋골에 명동 여전히 출현(상위가 하위를 대체 안 함)", band2.has(MineFloors.N_MYEONGDONG))
	var band3 := _kinds_over(range(1, 31), range(41, 61))    # 업화(41~60)
	_check("③h 업화(41~60)에 황천금 출현", band3.has(MineFloors.N_HWANGCHEONGEUM))
	_check("③i 업화에 염주석 출현", band3.has(MineFloors.N_GEM_YEOMJUSEOK))
	_check("③j 알돌 분리 — 넋알돌 1~40 / 업화알돌 41+",
		band1.has(MineFloors.N_GEODE_NEOKAL) and not band1.has(MineFloors.N_GEODE_EOPHWA) \
		and band3.has(MineFloors.N_GEODE_EOPHWA) and not band3.has(MineFloors.N_GEODE_NEOKAL))
	var shallow := _kinds_over(range(1, 61), range(1, 31))   # 1~30층
	_check("③k 명부금강 = 31층+ 전용(1~30층 0)", not shallow.has(MineFloors.N_GEM_MYEONGBU))
	_check("③l 명부금강이 31층+에서는 나온다(희귀)",
		_kinds_over(range(1, 61), range(31, 61)).has(MineFloors.N_GEM_MYEONGBU))
	# 나락철·오색혼옥은 갱도 노드가 아니다(등록만 — 출현은 S5-T7 나락 소관).
	var all_kinds := _kinds_over(range(1, 41), range(1, 61))
	_check("③m 나락철·오색혼옥은 갱도 노드 아님",
		not all_kinds.has(ItemCatalog.ORE_NARAKCHEOL) and not all_kinds.has(ItemCatalog.GEM_OSAEK_HONOK))
	_check("③n node_pool 게이트 — 1층 4종 / 21층 6종 / 31층 7종 / 41층 9종",
		MineFloors.node_pool(1).size() == 4 and MineFloors.node_pool(21).size() == 6 \
		and MineFloors.node_pool(31).size() == 7 and MineFloors.node_pool(41).size() == 9)

	# ── ⑧ 아이템 로스터 등록·가격·카테고리 + 노드 id 대조 ────────────────────
	var price_rows := [
		[ItemCatalog.ORE_MYEONGDONG, "명동 광석", 5], [ItemCatalog.ORE_YUCHEOL, "유철 광석", 10],
		[ItemCatalog.ORE_HWANGCHEONGEUM, "황천금 광석", 25], [ItemCatalog.ORE_NARAKCHEOL, "나락철 광석", 100],
		[ItemCatalog.HONTAN, "혼탄", 15], [ItemCatalog.STONE, "돌", 2],
		[ItemCatalog.GEM_NEOKSUJEONG, "넋수정", 100], [ItemCatalog.GEM_MYEONGOK, "명옥", 200],
		[ItemCatalog.GEM_YEOMJUSEOK, "염주석", 250], [ItemCatalog.GEM_MYEONGBU_GEUMGANG, "명부금강", 750],
		[ItemCatalog.GEM_OSAEK_HONOK, "오색혼옥", 2000],
		[ItemCatalog.GEODE_NEOKAL, "넋알돌", 50], [ItemCatalog.GEODE_EOPHWA, "업화알돌", 150],
	]
	var reg_ok := true
	var cat_ok := true
	var stack_ok := true
	for row: Array in price_rows:
		var id := String(row[0])
		if not ItemCatalog.has_item(id) or ItemCatalog.name_of(id) != String(row[1]) \
				or ItemCatalog.price_of(id) != int(row[2]):
			reg_ok = false
		if ItemCatalog.category_of(id) != ItemCatalog.CAT_MATERIAL:
			cat_ok = false
		if not ItemCatalog.stackable_of(id):
			stack_ok = false
	_check("⑧ 광물 13종 등록·표시명·가격", reg_ok)
	_check("⑧b 전부 CAT_MATERIAL", cat_ok)
	_check("⑧c 전부 스택 가능", stack_ok)
	_check("⑧d 품질 무차원 — 등급을 줘도 가격 불변",
		ItemCatalog.price_of(ItemCatalog.GEM_MYEONGOK, ItemCatalog.Q_IRIDIUM) == 200)
	_check("⑧e 로스터 크기 13", ItemCatalog.MINERALS.size() == 13)
	var node_item_ok := true
	for nid: String in MineFloors.node_kinds():
		if not ItemCatalog.has_item(nid) or ItemCatalog.category_of(nid) != ItemCatalog.CAT_MATERIAL:
			node_item_ok = false
	_check("⑧f 노드 id = 실존 광물 아이템 id(10종 전량 대조)", node_item_ok)
	_check("⑧g 노드 종 10 · 부류 판정",
		MineFloors.node_kinds().size() == 10 \
		and MineFloors.node_class(MineFloors.N_MYEONGDONG) == MineFloors.NODE_ORE \
		and MineFloors.node_class(MineFloors.N_HONTAN) == MineFloors.NODE_COAL \
		and MineFloors.node_class(MineFloors.N_GEM_MYEONGOK) == MineFloors.NODE_GEM \
		and MineFloors.node_class(MineFloors.N_GEODE_NEOKAL) == MineFloors.NODE_GEODE \
		and MineFloors.node_class("") == "")
	_check("⑧h 타수 — 일반 돌 1 · 광석/혼탄 3 · 보석/지오드 5",
		MineFloors.node_hits("") == 1 and MineFloors.node_hits(MineFloors.N_MYEONGDONG) == 3 \
		and MineFloors.node_hits(MineFloors.N_HONTAN) == 3 \
		and MineFloors.node_hits(MineFloors.N_GEM_MYEONGBU) == 5 \
		and MineFloors.node_hits(MineFloors.N_GEODE_EOPHWA) == 5)

	# ── 채광 숙련 순수 규칙(XP 테이블·곡선 위임·혼력·크리) ────────────────────
	_check("⑨x XP 곡선은 FarmSkill 위임(수치 복제 0)",
		MiningSkill.level_for_xp(0) == FarmSkill.level_for_xp(0) \
		and MiningSkill.level_for_xp(5000) == FarmSkill.level_for_xp(5000) \
		and MiningSkill.MAX_LEVEL == FarmSkill.MAX_LEVEL)
	_check("⑨y 고정 XP 테이블(명동 5 · 유철 12 · 황천금 18 · 혼탄 10)",
		MiningSkill.xp_for_node(MineFloors.N_MYEONGDONG) == 5 \
		and MiningSkill.xp_for_node(MineFloors.N_YUCHEOL) == 12 \
		and MiningSkill.xp_for_node(MineFloors.N_HWANGCHEONGEUM) == 18 \
		and MiningSkill.xp_for_node(MineFloors.N_HONTAN) == 10)
	_check("⑨z 고정 XP 테이블(보석 16/40/150 · 지오드 8/16 · 일반 돌 0)",
		MiningSkill.xp_for_node(MineFloors.N_GEM_NEOKSUJEONG) == 16 \
		and MiningSkill.xp_for_node(MineFloors.N_GEM_MYEONGOK) == 16 \
		and MiningSkill.xp_for_node(MineFloors.N_GEM_YEOMJUSEOK) == 40 \
		and MiningSkill.xp_for_node(MineFloors.N_GEM_MYEONGBU) == 150 \
		and MiningSkill.xp_for_node(MineFloors.N_GEODE_NEOKAL) == 8 \
		and MiningSkill.xp_for_node(MineFloors.N_GEODE_EOPHWA) == 16 \
		and MiningSkill.xp_for_node("") == 0)
	_check("⑨A 나락철 XP 50(표만 — 갱도 미출현)",
		MiningSkill.xp_for_node(ItemCatalog.ORE_NARAKCHEOL) == 50)

	# ── ⑥ 혼력 감산(3%/lv) ───────────────────────────────────────────────────
	_check("⑥ 계수 Lv0 = 1.0 · Lv10 = 0.7", is_equal_approx(MiningSkill.energy_factor(0), 1.0) \
		and is_equal_approx(MiningSkill.energy_factor(10), 0.7))
	var mono_e := true
	var prev_e := MiningSkill.energy_factor(0)
	for lv in range(1, 11):
		var c := MiningSkill.energy_factor(lv)
		if c >= prev_e:
			mono_e = false
		prev_e = c
	_check("⑥b 레벨이 오를수록 단조 감소(0→10)", mono_e)
	_check("⑥c 범위 밖 레벨 클램프", is_equal_approx(MiningSkill.energy_factor(-3), 1.0) \
		and is_equal_approx(MiningSkill.energy_factor(99), MiningSkill.energy_factor(10)))

	# ── ⑤ 크리 채굴(결정성·확률) ─────────────────────────────────────────────
	_check("⑤ Lv0 = 0% · Lv10 = 10%", is_equal_approx(MiningSkill.crit_chance(0), 0.0) \
		and is_equal_approx(MiningSkill.crit_chance(10), 0.10))
	var crit_a := MiningSkill.roll_crit(7, 3, Vector2i(5, 5), 10)
	var crit_b := MiningSkill.roll_crit(7, 3, Vector2i(5, 5), 10)
	_check("⑤b 같은 (day,층,칸,레벨) 롤 2회 동일(결정성)", crit_a == crit_b)
	var crit_l0 := 0
	var crit_l10 := 0
	for i in range(400):
		if MiningSkill.roll_crit(1, 1, Vector2i(i % 20, i / 20), 0):
			crit_l0 += 1
		if MiningSkill.roll_crit(1, 1, Vector2i(i % 20, i / 20), 10):
			crit_l10 += 1
	_check("⑤c Lv0은 절대 안 터진다(400표본 0)", crit_l0 == 0)
	_check("⑤d Lv10은 대략 10%% — 400표본 %d회(4~18%% 허용)" % crit_l10, crit_l10 >= 16 and crit_l10 <= 72)

	# ── 드랍 해석(resolve_drop — 순수·결정적) ────────────────────────────────
	var d_stone := MiningSkill.resolve_drop("", 5, 1, Vector2i(3, 4), 0)
	_check("④a 일반 돌 = 돌 1개 · XP 0(또는 5% 부산출)",
		(d_stone["drops"] as Array).size() >= 1 \
		and String((d_stone["drops"] as Array)[0]["id"]) == ItemCatalog.STONE \
		and int((d_stone["drops"] as Array)[0]["count"]) == 1)
	var stone_bonus := 0
	for i in range(600):
		var r := MiningSkill.resolve_drop("", 1, 1, Vector2i(i % 24, i / 24), 0)
		if (r["drops"] as Array).size() > 1:
			stone_bonus += 1
			if String((r["drops"] as Array)[1]["id"]) != ItemCatalog.ORE_MYEONGDONG or int(r["xp"]) != 5:
				stone_bonus = -9999
	_check("④b 일반 돌 5%% 명동 부산출 + 그때만 XP 5(600표본 %d회)" % stone_bonus,
		stone_bonus > 5 and stone_bonus < 90)
	var ore_ok := true
	var ore_min := 99
	var ore_max := 0
	for i in range(300):
		var r := MiningSkill.resolve_drop(MineFloors.N_MYEONGDONG, 2, 5, Vector2i(i % 24, i / 24), 0)
		var c := int((r["drops"] as Array)[0]["count"])
		if String((r["drops"] as Array)[0]["id"]) != MineFloors.N_MYEONGDONG or int(r["xp"]) != 5 \
				or bool(r["crit"]):
			ore_ok = false
		ore_min = mini(ore_min, c)
		ore_max = maxi(ore_max, c)
	_check("④c 광석 노드 = 1~3개 · XP 5 · Lv0 크리 없음", ore_ok and ore_min == 1 and ore_max == 3)
	_check("④d 같은 인자 2회 = 같은 결과(결정성)",
		str(MiningSkill.resolve_drop(MineFloors.N_YUCHEOL, 4, 25, Vector2i(9, 9), 3)) \
		== str(MiningSkill.resolve_drop(MineFloors.N_YUCHEOL, 4, 25, Vector2i(9, 9), 3)))
	_check("④e 보석 노드 = 1개 · 퍼크 0이면 쌍 없음",
		int((MiningSkill.resolve_drop(MineFloors.N_GEM_MYEONGOK, 4, 25, Vector2i(9, 9), 3)["drops"] \
			as Array)[0]["count"]) == 1)
	_check("④f 지질사 퍼크(쌍 100%) 훅 — 보석 2개",
		int((MiningSkill.resolve_drop(MineFloors.N_GEM_MYEONGOK, 4, 25, Vector2i(9, 9), 3, 0, 1.0)["drops"] \
			as Array)[0]["count"]) == 2)
	# 광부 퍼크(+1) 훅 — 같은 칸에서 정확히 +1(크리 없는 표본을 골라 비교).
	var miner_ok := true
	for i in range(60):
		var t := Vector2i(i % 12, i / 12)
		var base_r := MiningSkill.resolve_drop(MineFloors.N_MYEONGDONG, 6, 12, t, 0)
		var perk_r := MiningSkill.resolve_drop(MineFloors.N_MYEONGDONG, 6, 12, t, 0, 1)
		if int((perk_r["drops"] as Array)[0]["count"]) != int((base_r["drops"] as Array)[0]["count"]) + 1:
			miner_ok = false
	_check("④g 광부 퍼크(+1) 훅 — 광맥당 정확히 +1(60표본)", miner_ok)
	_check("④h 퍼크 해석기 — 미선택(0)은 중립",
		MiningSkill.ore_bonus(0.0) == 0 and is_equal_approx(MiningSkill.gem_pair_chance(0.0), 0.0) \
		and MiningSkill.ore_bonus(1.0) == 1 and is_equal_approx(MiningSkill.gem_pair_chance(0.5), 0.5))
	# 크리 = 광석 2배(레벨 10이면 일부 칸에서 터진다).
	var crit_hits := 0
	for i in range(400):
		var t2 := Vector2i(i % 20, i / 20)
		var r10 := MiningSkill.resolve_drop(MineFloors.N_MYEONGDONG, 8, 30, t2, 10)
		if bool(r10["crit"]):
			crit_hits += 1
			var r0 := MiningSkill.resolve_drop(MineFloors.N_MYEONGDONG, 8, 30, t2, 0)
			if int((r10["drops"] as Array)[0]["count"]) != int((r0["drops"] as Array)[0]["count"]) * 2:
				crit_hits = -9999
	_check("④i 크리 채굴 = 광석 정확히 2배(Lv10 400표본 %d회)" % crit_hits, crit_hits > 5)

	# ── ⑨ main 배선: 층에서 광맥 캐기 ────────────────────────────────────────
	var m: Node = await _spawn_main()
	_check("⑨ 숙련 탭 4행(농사·채집·낚시·채광)", (m._skill_rows() as Array).size() == 4 \
		and String((m._skill_rows() as Array)[3]["name"]) == "채광" \
		and String((m._skill_rows() as Array)[3]["skill"]) == ProfessionCatalog.MINING)
	_check("⑨b 채광 레벨이 XP 스칼라에서 파생(초기 0)",
		m._skill_level(ProfessionCatalog.MINING) == 0 and m._mining_xp == 0)
	_check("⑨c 혼력 비용 Lv0 = 10(기준값)", m._mining_energy_cost() == m.MINE_ROCK_COST)
	m._mining_xp = 100000        # Lv10 강제(곡선 만렙 — 혼력 감산 확인)
	_check("⑥d main 배선 혼력 Lv10 = 7", m._skill_level(ProfessionCatalog.MINING) == 10 \
		and m._mining_energy_cost() == 7)
	m._mining_xp = 0

	# 노드가 있는 층을 찾아 내려간다(오늘 날짜 기준 — 대부분의 층에 노드가 있다).
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	var target_floor := 0
	var node_tile := Vector2i(-1, -1)
	var node_id := ""
	for f in range(1, 21):
		var l := MineFloors.generate(m.clock.day, f)
		var nodes2: Dictionary = l["nodes"]
		var keys2: Array = nodes2.keys()
		keys2.sort()
		for k: Vector2i in keys2:
			if String(nodes2[k]) == MineFloors.N_MYEONGDONG:
				target_floor = f
				node_tile = k
				node_id = String(nodes2[k])
				break
		if target_floor > 0:
			break
	_check("④ 명동 광맥이 깔린 층을 찾았다(1~20층 표본)", target_floor > 0)
	if target_floor > 0:
		m._descend_mine(target_floor)
		await _settle(m)
		var pick_idx := _slot_of(m.inventory, ItemCatalog.PICKAXE)
		m.inventory.select(pick_idx)
		_check("④j 광맥 칸이 곡괭이 대상(ROCK)", m._is_mine_rock(node_tile) \
			and m._mine_node_at(node_tile) == node_id)
		var need := MineFloors.node_hits(node_id)
		_check("④k 광석 광맥 타수 3", need == 3)
		var e0: int = m.energy.current
		var have0: int = m.inventory.count_of(node_id)
		var xp0: int = m._mining_xp
		# 첫 타 — 진행만 오르고 산출 0.
		m._target = node_tile
		m._mine_rock(node_tile)
		_check("④l 1타 — 아직 안 깨짐(진행 1/3)",
			not m.mine_floors.is_mined(target_floor, node_tile) \
			and m.mine_floors.node_hits_done(target_floor, node_tile) == 1)
		_check("④m 1타 — 혼력만 나가고 산출·XP 0",
			m.energy.current == e0 - m._mining_energy_cost() \
			and m.inventory.count_of(node_id) == have0 and m._mining_xp == xp0)
		m._mine_rock(node_tile)
		_check("④n 2타 — 여전히 안 깨짐(2/3)",
			not m.mine_floors.is_mined(target_floor, node_tile) \
			and m.mine_floors.node_hits_done(target_floor, node_tile) == 2)
		m._mine_rock(node_tile)
		_check("④o 3타 — 부서짐(원장 기록·통행 개방)",
			m.mine_floors.is_mined(target_floor, node_tile) \
			and m._grid[node_tile.y][node_tile.x] == m.PATH)
		var gained: int = m.inventory.count_of(node_id) - have0
		_check("④p 명동 광석 1~3개 적재(실제 %d개)" % gained, gained >= 1 and gained <= 3)
		_check("④q 채광 XP 5 적립", m._mining_xp == xp0 + MiningSkill.XP_MYEONGDONG)
		_check("④r 혼력 3타분 소모", m.energy.current == e0 - m._mining_energy_cost() * 3)
		_check("④s 부순 뒤 타수 기록 정리", m.mine_floors.node_hits_done(target_floor, node_tile) == 0)
		# 일반 돌 — 1타로 깨지고 돌 1개가 들어온다.
		var plain := Vector2i(-1, -1)
		for r: Vector2i in m.mine_floors.rocks_left(m.clock.day, target_floor):
			if m._mine_node_at(r) == "":
				plain = r
				break
		if plain.x >= 0:
			var stone0: int = m.inventory.count_of(ItemCatalog.STONE)
			m._target = plain
			m._mine_rock(plain)
			_check("④t 일반 돌 1타로 깨짐 + 돌 1개 적재",
				m.mine_floors.is_mined(target_floor, plain) \
				and m.inventory.count_of(ItemCatalog.STONE) >= stone0 + 1)
		# day가 갈리면 타수 진행도 함께 소멸(층 리필).
		var probe := Vector2i(2, 2)
		m.mine_floors.add_node_hit(target_floor, probe)
		_check("④u 타수 진행 기록됨", m.mine_floors.node_hits_done(target_floor, probe) == 1)
		m.mine_floors.advance_day(m.clock.day + 1)
		_check("④v day 갈리면 타수 진행 소멸", m.mine_floors.node_hits_done(target_floor, probe) == 0)

	# ── ⑦ mining_xp 세이브/로드 왕복 ─────────────────────────────────────────
	m._mining_xp = 777
	m._save_game()
	await _despawn(m)
	var m2: Node = await _spawn_main()
	_check("⑦ mining_xp 세이브/로드 왕복(777)", m2._mining_xp == 777)
	_check("⑦b 레벨이 복원 XP에서 파생",
		m2._skill_level(ProfessionCatalog.MINING) == MiningSkill.level_for_xp(777))
	await _despawn(m2)
	# 타수 진행 원장 왕복(MineFloors 단독).
	var mf := MineFloors.new()
	mf.advance_day(4)
	mf.add_node_hit(6, Vector2i(3, 8))
	mf.add_node_hit(6, Vector2i(3, 8))
	var mf2 := MineFloors.new()
	mf2.load_save(mf.to_save())
	_check("⑦c 타수 진행 세이브/로드 왕복(2타)", mf2.node_hits_done(6, Vector2i(3, 8)) == 2)
	var mf3 := MineFloors.new()
	mf3.load_save({"node_hits": {"61": [[1, 1, 3]], "6": [[2, 2, 0]], "7": [[4, 4, 2]]}})
	_check("⑦d 손상 방어 — 범위 밖 층·0타 기록 폐기",
		mf3.node_hits_done(61, Vector2i(1, 1)) == 0 and mf3.node_hits_done(6, Vector2i(2, 2)) == 0 \
		and mf3.node_hits_done(7, Vector2i(4, 4)) == 2)

	# ── ⑦e 구세이브 하위호환: mining_xp·node_hits 키 없는 세이브 ─────────────
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var sm := SaveManager.new()
	sm.save_game({"region": RegionCatalog.HOME, "indoor": "",
		"player_tile": RegionCatalog.spawn_of(RegionCatalog.HOME)})
	sm.free()
	var m3: Node = await _spawn_main()
	_check("⑦e 구세이브 = 채광 XP 0·Lv0(무막힘)",
		m3._mining_xp == 0 and m3._skill_level(ProfessionCatalog.MINING) == 0)
	_check("⑦f 구세이브 = 숙련 탭 4행 그대로", (m3._skill_rows() as Array).size() == 4)
	await _despawn(m3)

	# ── 세이브 백업 복원 ──
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
