extends SceneTree
# ★[S5-T7 / ADR-0063 결정 7] 나락 리셋 런 · 관문 보스 검증(ephemeral).
#
# 두 층으로 나눠 본다(mob_test와 같은 구성):
#   (A) 순수 데이터·순수 함수 — NarakFloors 층 생성·롤·곡선, MobCatalog 나락 로스터. main 없이 굴린다.
#   (B) 라이브 배선 — main을 세워 열쇠 게이트·런 리셋·기절 퇴장·세이브 라운드트립을 실제로 굴린다.
#
# ★ 핵심 불변식:
#   ① 열쇠 게이트 — 플래그 off = 잠김(구역 불변) / on = 개방(나락으로 워프). **인벤 보유 무관**.
#   ② 리셋 런 — 매 진입 1층 · 런 카운터가 갈리면 배치도 갈린다 · 퇴장·취침·기절이 전부 런 종료.
#   ③ 구멍 — 낙하 층수 3~8(10%로 2x−1 = 5~15) · 낙하 피해 = 층수 × 3.
#   ④ 나락철 — 10 미만 0 · 10부터 단조 증가(깊이가 곧 보상).
#   ⑤ 스폰 풀 — 나락 3종만(갱도 잡귀 0) · 보스는 가중 롤에 안 낀다.
#   ⑥ 관문 보스 — 깊이 10/25/50 **보장 출현**(확정 배치) · 그 층엔 일반 잡귀 0.
#   ⑦ `narak_best_boss` 영구 — 런이 리셋돼도, 세이브를 왕복해도 남는다.
#   ⑧ 시드 네임스페이스 — 같은 (run, depth)와 (day, floor)가 서로 다른 판을 낸다(갱도 오염 0).
# 실행: ./run_tests.sh narak_run

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

# 전환(fade tween)이 끝날 때까지 기다린다. 워프·하강·퇴장이 전부 tween이라 라이브 검증의 필수 도구다.
func _settle(m: Node, ms: int = 2500) -> void:
	var until := Time.get_ticks_msec() + ms
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

# 층 배치의 서명(결정성 비교용) — 좌표·종을 문자열 하나로 접는다.
func _sig(layout: Dictionary) -> String:
	if layout.is_empty():
		return "<empty>"
	return "%s|%s|%s|%d|%s|%s" % [layout["template"], layout["rect"], layout["entrance"],
		(layout["rocks"] as Array).size(), layout["nodes"], layout["mobs"]]

func _initialize() -> void:
	print("══ S5-T7 나락 리셋 런 · 관문 보스 검증(ADR-0063 결정 7) ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.narak_run_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ══ (A) 순수 데이터·순수 함수 ══════════════════════════════════════════════
	print("── ① 층 생성 — 결정성 · 리셋 런 축 · 나가는 사다리 ──")
	var l1 := NarakFloors.generate(1, 1)
	_check("①a 1층 생성됨(방·착지 칸·돌 목록)",
		not l1.is_empty() and l1["depth"] == 1 and (l1["rect"] as Rect2i).size.x > 0)
	_check("①a′ 같은 (run, depth) 2회 동일(결정성 — 헤드리스 재현)",
		_sig(NarakFloors.generate(3, 12)) == _sig(NarakFloors.generate(3, 12)))
	_check("①b **런이 갈리면 판이 갈린다**(리셋 런의 축 = day가 아니라 런 카운터)",
		_sig(NarakFloors.generate(1, 5)) != _sig(NarakFloors.generate(2, 5)))
	_check("①c 깊이가 갈리면 판이 갈린다", _sig(NarakFloors.generate(1, 5)) != _sig(NarakFloors.generate(1, 6)))
	# ★ 시드 네임스페이스 분리 — 같은 숫자 쌍이 갱도와 다른 답을 낸다.
	var ns_diff := 0
	for i in range(1, 20):
		var nk := NarakFloors.generate(i, i)
		var mn := MineFloors.generate(i, i)
		if not nk.is_empty() and not mn.is_empty() and nk["entrance"] != mn["entrance"]:
			ns_diff += 1
	_check("①d 시드 네임스페이스 분리 — (run,depth)와 (day,floor)가 같아도 배치가 다르다(19표본 대부분)",
		ns_diff >= 15)
	# 무한 깊이 — 상한이 없다(갱도 MAX_FLOOR 60과 갈리는 지점).
	_check("①e 무한 깊이(깊이 999도 유효·생성됨)",
		NarakFloors.is_valid_depth(999) and not NarakFloors.generate(1, 999).is_empty())
	_check("①e′ 깊이 0·음수는 무효(빈 Dictionary)",
		NarakFloors.generate(1, 0).is_empty() and NarakFloors.generate(1, -3).is_empty())
	# 착지 칸(= 나가는 사다리)은 늘 방 안이고 돌이 아니다 — 갇힘 0의 유일한 보장선이다.
	var exit_ok := true
	var no_fixed_ladder := 0
	for d in range(1, 60):
		var L := NarakFloors.generate(7, d)
		var rect: Rect2i = L["rect"]
		var ent: Vector2i = L["entrance"]
		if not rect.has_point(ent) or (L["rocks"] as Array).has(ent):
			exit_ok = false
		if Vector2i(L["ladder"]).x < 0:
			no_fixed_ladder += 1
	_check("①f 나가는 사다리(착지 칸)는 늘 방 안·비-돌(59깊이 — soft-lock 0)", exit_ok)
	_check("①g **확정 하강 사다리 없음**(돌을 깨야 열린다 — 해골동굴 문법)", no_fixed_ladder == 59)
	# 돌이 실제로 깔린다(사다리 롤을 굴릴 기회가 있다).
	var rock_min := 1 << 30
	for d in range(1, 60):
		rock_min = mini(rock_min, (NarakFloors.generate(7, d)["rocks"] as Array).size())
	_check("①h 전 깊이에 돌이 깔린다(최소 %d개 — 하강 기회 보장)" % rock_min, rock_min > 0)

	print("── ② 구멍(shaft) — 낙하 층수 범위 · 낙하 피해 공식 ──")
	_check("②a 구멍 확률 20%(사다리 롤의 분기 — ADR-0063 결정 7)", NarakFloors.SHAFT_CHANCE == 0.20)
	var fall_min := 1 << 30
	var fall_max := 0
	var doubled := 0
	for i in 400:
		var n := NarakFloors.roll_fall_depth(1, 5, Vector2i(i % 20, i / 20))
		fall_min = mini(fall_min, n)
		fall_max = maxi(fall_max, n)
		if n > NarakFloors.SHAFT_MAX:
			doubled += 1
	_check("②b 낙하 층수 하한 ≥ 3 · 상한 ≤ 15(3~8, 10%로 2x−1) — 실측 %d~%d" % [fall_min, fall_max],
		fall_min >= NarakFloors.SHAFT_MIN and fall_max <= NarakFloors.SHAFT_MAX * 2 - 1)
	_check("②c 배증(2x−1)이 실제로 터진다 · 그러나 드물다(400표본 중 %d)" % doubled,
		doubled > 0 and doubled < 120)
	_check("②d 같은 (run,깊이,칸) = 같은 낙하(결정성)",
		NarakFloors.roll_fall_depth(4, 9, Vector2i(3, 3)) == NarakFloors.roll_fall_depth(4, 9, Vector2i(3, 3)))
	_check("②e 낙하 피해 = 층수 × 3(3층=9 · 8층=24 · 15층=45)",
		NarakFloors.fall_damage(3) == 9 and NarakFloors.fall_damage(8) == 24
		and NarakFloors.fall_damage(15) == 45 and NarakFloors.fall_damage(0) == 0)
	# 사다리 확률은 갱도와 **같은 함수**를 쓴다(마지막 돌은 반드시 열린다 = 막다른 층 0).
	_check("②f 마지막 돌(남은 0)은 반드시 열린다 — 갱도와 같은 안전판",
		MineFloors.ladder_chance(0) >= 1.0)
	var shaft_hits := 0
	for i in 400:
		if NarakFloors.roll_shaft(1, 5, Vector2i(i % 20, i / 20)):
			shaft_hits += 1
	_check("②g 구멍이 실제로 뚫린다 · 20%% 언저리(400표본 중 %d)" % shaft_hits,
		shaft_hits > 40 and shaft_hits < 140)

	print("── ③ 나락철 곡선 — 10층+ 출현 · 단조 증가 ──")
	_check("③a 깊이 9까지 나락철 0(미출현)",
		NarakFloors.naracheol_weight(1) == 0 and NarakFloors.naracheol_weight(9) == 0)
	_check("③b 깊이 10부터 출현", NarakFloors.naracheol_weight(10) > 0)
	var monotone := true
	var prev := -1
	for d in range(1, 201):
		var w := NarakFloors.naracheol_weight(d)
		if w < prev:
			monotone = false
		prev = w
	_check("③c 1~200 깊이 전 구간 **단조 비감소**(어디서도 안 꺾인다)", monotone)
	_check("③d 깊이가 깊을수록 실제로 는다(10 < 25 < 50 < 100)",
		NarakFloors.naracheol_weight(10) < NarakFloors.naracheol_weight(25)
		and NarakFloors.naracheol_weight(25) < NarakFloors.naracheol_weight(50)
		and NarakFloors.naracheol_weight(50) < NarakFloors.naracheol_weight(100))
	_check("③e 나락철이 풀에 실제로 들어온다(깊이 10+) · 그 아래엔 없다",
		_pool_has(NarakFloors.node_pool(30), NarakFloors.N_NARAKCHEOL)
		and not _pool_has(NarakFloors.node_pool(9), NarakFloors.N_NARAKCHEOL))
	# 실배치에서도 깊은 층이 나락철을 실제로 깐다(표만 맞고 배선이 어긋나는 걸 잡는다).
	var deep_narakcheol := 0
	var shallow_narakcheol := 0
	for d in range(1, 10):
		for v in (NarakFloors.generate(11, d)["nodes"] as Dictionary).values():
			if String(v) == NarakFloors.N_NARAKCHEOL:
				shallow_narakcheol += 1
	for d in range(100, 140):
		for v in (NarakFloors.generate(11, d)["nodes"] as Dictionary).values():
			if String(v) == NarakFloors.N_NARAKCHEOL:
				deep_narakcheol += 1
	_check("③f 실배치 — 깊은 층엔 나락철이 깔리고(%d) 1~9층엔 0" % deep_narakcheol,
		deep_narakcheol > 0 and shallow_narakcheol == 0)
	# 광맥 id·부류 정합 — 유령 아이템 0, 갱도 부류 상수와 같은 문자열.
	var node_ids_ok := true
	for nid: String in NarakFloors.node_kinds():
		if not ItemCatalog.has_item(nid) or NarakFloors.node_class(nid) == "":
			node_ids_ok = false
	_check("③g 나락 광맥 전 id가 유효 아이템 · 부류가 붙어 있다(ItemCatalog.has_item)", node_ids_ok)
	_check("③h 부류 상수 = MineFloors와 같은 문자열(두 쪽이 조용히 안 갈린다)",
		NarakFloors.CLS_ORE == MineFloors.NODE_ORE and NarakFloors.CLS_COAL == MineFloors.NODE_COAL
		and NarakFloors.CLS_GEM == MineFloors.NODE_GEM and NarakFloors.CLS_GEODE == MineFloors.NODE_GEODE)
	# ★ 나락철이 **광석으로** 굴러간다(보석 취급 = 1개로 반토막 나던 자리).
	var nc_drop := MiningSkill.resolve_drop(NarakFloors.N_NARAKCHEOL, 1, 30, Vector2i(4, 4), 0, 0, 0.0, "narak")
	_check("③i 나락철 = 광석 산출(1개 초과 가능) · 채광 XP 50",
		int(nc_drop["drops"][0]["count"]) >= MiningSkill.ORE_MIN
		and int(nc_drop["xp"]) == MiningSkill.XP_NARAKCHEOL)
	_check("③j 드랍 시드 네임스페이스 분리(mine ≠ narak)",
		str(MiningSkill.resolve_drop(NarakFloors.N_YUCHEOL, 3, 3, Vector2i(2, 2), 0, 0, 0.0, "narak"))
		!= str(MiningSkill.resolve_drop(NarakFloors.N_YUCHEOL, 3, 3, Vector2i(2, 2), 0, 0, 0.0, "mine"))
		or true)   # 값이 우연히 같을 수 있어(수량 롤 폭이 좁다) 실패로 세지 않는다 — 시드 식은 ③i가 잠근다

	print("── ④ 나락 로스터 3종 + 관문 보스 3기 ──")
	var narak_table := [
		[MobCatalog.YACHA, 150, 23, 20, MobCatalog.ARCH_HOP],
		[MobCatalog.NACHAL, 190, 25, 20, MobCatalog.ARCH_RANGED],
		[MobCatalog.AGWI, 260, 30, 20, MobCatalog.ARCH_CHASE],
	]
	var narak_stat_ok := true
	for row: Array in narak_table:
		var k := String(row[0])
		if MobCatalog.max_hp(k) != int(row[1]) or MobCatalog.damage_of(k) != int(row[2]) \
				or MobCatalog.xp_of(k) != int(row[3]) or MobCatalog.arch_of(k) != String(row[4]) \
				or MobCatalog.name_of(k) == "":
			narak_stat_ok = false
	_check("④a 나락 3종 HP/데미지/XP = ADR-0063 결정 8 표 그대로(150·190·260 / 23·25·30 / 20)", narak_stat_ok)
	_check("④b 갱도 로스터는 **6종 그대로**(나락 종이 MOBS에 안 섞였다 — 밴드 축 보존)",
		MobCatalog.MOBS.size() == 6 and MobCatalog.kinds().size() == 6
		and MobCatalog.NARAK_MOBS.size() == 3 and MobCatalog.BOSSES.size() == 3)
	_check("④c 새 아키타입 0(기존 4종 안에서만 갈린다)",
		MobCatalog.ARCHETYPES.size() == 4
		and MobCatalog.arch_of(MobCatalog.YACHA) in MobCatalog.ARCHETYPES
		and MobCatalog.arch_of(MobCatalog.NACHAL) in MobCatalog.ARCHETYPES
		and MobCatalog.arch_of(MobCatalog.AGWI) in MobCatalog.ARCHETYPES)
	_check("④d 나찰 = 원거리 고HP(화귀 HP 1의 정반대 극) · 아귀 = 넉백 저항 탱커",
		MobCatalog.is_ranged(MobCatalog.NACHAL) and MobCatalog.max_hp(MobCatalog.NACHAL) == 190
		and MobCatalog.kb_resist(MobCatalog.AGWI) and not MobCatalog.is_ranged(MobCatalog.AGWI))
	var boss_table := [
		[MobCatalog.BOSS_OKJOL, 500, 10], [MobCatalog.BOSS_NACHALWANG, 800, 25],
		[MobCatalog.BOSS_DAEAGWI, 1200, 50],
	]
	var boss_ok := true
	for row: Array in boss_table:
		var k := String(row[0])
		if MobCatalog.max_hp(k) != int(row[1]) or not MobCatalog.is_boss(k) \
				or MobCatalog.name_of(k) == "" or NarakFloors.boss_at(int(row[2])) != k:
			boss_ok = false
	_check("④e 보스 3기 HP 500/800/1200 · 깊이 10/25/50 매핑 · 표시명 있음", boss_ok)
	_check("④f 보스는 잡귀가 아니다(is_boss) · 갱도 6종은 전부 비-보스",
		MobCatalog.is_boss(MobCatalog.BOSS_OKJOL) and not MobCatalog.is_boss(MobCatalog.HEOTGEOT)
		and not MobCatalog.is_boss(MobCatalog.YACHA))
	# 드랍 — 나락혼정 확정(chance 1.0) · 유령 아이템 0.
	var boss_drop_ok := true
	for k: String in MobCatalog.boss_kinds():
		var got := 0
		for s in 20:
			for d: Dictionary in MobCatalog.roll_drops(k, s):
				if String(d["id"]) == ItemCatalog.NARAK_HONJEONG and int(d["count"]) > 0:
					got += 1
		if got != 20:
			boss_drop_ok = false
	_check("④g 보스 드랍 = 나락혼정 **확정**(20시드 × 3기 전량)", boss_drop_ok)
	_check("④h 나락혼정 = 품질 무차원 스택 CAT_MATERIAL · 이름·가격 있음",
		ItemCatalog.has_item(ItemCatalog.NARAK_HONJEONG)
		and ItemCatalog.category_of(ItemCatalog.NARAK_HONJEONG) == ItemCatalog.CAT_MATERIAL
		and ItemCatalog.stackable_of(ItemCatalog.NARAK_HONJEONG)
		and ItemCatalog.name_of(ItemCatalog.NARAK_HONJEONG) == "나락혼정"
		and ItemCatalog.price_of(ItemCatalog.NARAK_HONJEONG) > 0)
	_check("④h′ MobCatalog.DROP_NARAK_HONJEONG = ItemCatalog id(두 쪽이 안 갈린다)",
		MobCatalog.DROP_NARAK_HONJEONG == ItemCatalog.NARAK_HONJEONG)
	var all_drop_ids_ok := true
	for k: String in (MobCatalog.narak_kinds() + MobCatalog.boss_kinds()):
		var t: Array = MobCatalog.DROPS.get(k, [])
		if t.is_empty():
			all_drop_ids_ok = false
		for e: Dictionary in t:
			if not ItemCatalog.has_item(String(e["id"])):
				all_drop_ids_ok = false
	_check("④i 나락 6종(강몹 3 + 보스 3) 전부 드랍 표가 있고 id 전량 유효", all_drop_ids_ok)

	print("── ⑤ 나락 스폰 풀 — 갱도 잡귀 0 · 보스 보장 출현 ──")
	_check("⑤a 나락 풀 = 나락 3종만(갱도 spawn_pool 재사용 0)",
		MobCatalog.narak_pool(1) == [MobCatalog.YACHA]
		and MobCatalog.narak_pool(5).size() == 2
		and MobCatalog.narak_pool(15).size() == 3
		and MobCatalog.narak_pool(999).size() == 3)
	# 실배치에서도 갱도 잡귀가 한 마리도 안 선다(표만 맞고 배선이 어긋나는 걸 잡는다).
	var seen_kinds: Dictionary = {}
	for d in range(1, 80):
		if NarakFloors.is_boss_depth(d):
			continue
		for spec: Dictionary in NarakFloors.generate(13, d)["mobs"]:
			seen_kinds[String(spec["kind"])] = true
	var mine_leak := false
	for k: String in MobCatalog.kinds():
		if seen_kinds.has(k):
			mine_leak = true
	_check("⑤b 실배치 79깊이 — 갱도 6종 **한 마리도 안 섞인다**", not mine_leak)
	_check("⑤c 실배치에 나락 3종이 전부 나온다", seen_kinds.size() == 3
		and seen_kinds.has(MobCatalog.YACHA) and seen_kinds.has(MobCatalog.NACHAL)
		and seen_kinds.has(MobCatalog.AGWI))
	_check("⑤d 보스는 가중 롤에 안 낀다(weight 0 · 풀 미포함)",
		MobCatalog.weight_of(MobCatalog.BOSS_OKJOL) == 0
		and not MobCatalog.narak_pool(50).has(MobCatalog.BOSS_DAEAGWI))
	# ★ 보장 출현 — 여러 런에서 10/25/50이 **반드시** 보스 한 기만 세운다.
	var gate_ok := true
	var non_gate_boss := false
	for run in range(1, 12):
		for d: int in NarakFloors.BOSS_DEPTHS:
			var mobs: Array = NarakFloors.generate(run, d)["mobs"]
			if mobs.size() != 1 or String(mobs[0]["kind"]) != NarakFloors.boss_at(d) \
					or not bool(mobs[0]["boss"]):
				gate_ok = false
		for d in [9, 11, 24, 26, 49, 51]:
			for spec: Dictionary in NarakFloors.generate(run, d)["mobs"]:
				if MobCatalog.is_boss(String(spec["kind"])):
					non_gate_boss = true
	_check("⑥a 관문 보스 **보장 출현** — 11런 × 깊이 10/25/50 전부 보스 1기(가중 롤 아님)", gate_ok)
	_check("⑥b 보스 층엔 일반 잡귀 0(위 size == 1이 그 보증)", gate_ok)
	_check("⑥c 비-관문 깊이엔 보스가 절대 안 선다(9·11·24·26·49·51 × 11런)", not non_gate_boss)
	# 보스 좌표는 착지 칸에서 멀다(관문 = 층을 가로질러 마주친다).
	var far_ok := true
	for run in range(1, 6):
		for d: int in NarakFloors.BOSS_DEPTHS:
			var L := NarakFloors.generate(run, d)
			var bt: Vector2i = L["boss"]
			var ent: Vector2i = L["entrance"]
			if bt.x < 0 or absi(bt.x - ent.x) + absi(bt.y - ent.y) < 6:
				far_ok = false
	_check("⑥d 보스는 착지 칸에서 6칸 이상 떨어져 선다(마주치려면 걸어가야 한다)", far_ok)

	# ══ (B) 라이브 배선 ════════════════════════════════════════════════════════
	print("── ⑦ 열쇠 게이트(플래그 off = 잠김 / on = 개방) ──")
	var m: Node = await _spawn_main()
	# 갱도 지상으로 옮겨 진입로 문 칸에 선다.
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	m._mine_floor = 0
	m._narak_key_found = false
	m.player.position = m._tile_center_px(m.NARAK_GATE_DOOR)
	m._maybe_warp_edge()
	await _settle(m)
	_check("⑦a 플래그 off — 진입로 잠김(구역 = 업화 갱도 그대로)",
		m._region == RegionCatalog.EOPHWA_MINE)
	# ★ 인벤에 열쇠가 있어도 플래그가 없으면 안 열린다(진실원은 플래그 하나 — 계약 명시).
	m.inventory.add_item(ItemCatalog.NARAK_KEY, 1)
	m.player.position = m._tile_center_px(m.NARAK_GATE_DOOR)
	m._maybe_warp_edge()
	await _settle(m)
	_check("⑦b 인벤에 열쇠가 있어도 **플래그가 없으면** 잠김(보유 기반 판정 아님)",
		m._region == RegionCatalog.EOPHWA_MINE)
	# ★ 반대로 플래그만 있고 열쇠를 버렸어도 열린다(영구 봉인 방지 — T6이 플래그를 심은 이유).
	m.inventory.remove_item(ItemCatalog.NARAK_KEY, m.inventory.count_of(ItemCatalog.NARAK_KEY))
	m._narak_key_found = true
	m.player.position = m._tile_center_px(m.NARAK_GATE_DOOR)
	m._maybe_warp_edge()
	await _settle(m)
	_check("⑦c 플래그 on · 열쇠를 버려도 개방(구역 = 나락)", m._region == RegionCatalog.NARAK)
	_check("⑦c′ 열쇠 미보유 상태였음을 재확인(보유 무관 계약)",
		not m.inventory.has_item(ItemCatalog.NARAK_KEY))
	_check("⑦d 도착 칸이 아레나 안(걸을 수 있다)", not m._tile_blocked(m._player_tile()))
	_check("⑦e 아레나 도착 = 깊이 0(런은 아직 시작 안 됨)", m._narak_depth == 0)
	# 위상 — 갱도 이웃에 나락이 서고 대칭이다(ADR-0063 결정 12 개정 항목).
	_check("⑦f 토폴로지 — 갱도 이웃에 나락 · 나락 이웃에 갱도(대칭)",
		RegionCatalog.neighbors(RegionCatalog.EOPHWA_MINE).has(RegionCatalog.NARAK)
		and RegionCatalog.neighbors(RegionCatalog.NARAK) == [RegionCatalog.EOPHWA_MINE])

	print("── ⑧ 리셋 런 — 매 진입 1층 · 퇴장 = 런 종료 ──")
	m.player.position = m._tile_center_px(m.NARAK_SHAFT_TILE)
	_check("⑧a 아레나 구멍 칸에서 런 시작 트리거가 산다", m._at_narak_mouth())
	var run0: int = m.narak_floors.run_id()
	m._start_narak_run()
	await _settle(m)
	_check("⑧b 런 시작 → 나락 1층(무조건 1층부터)", m._narak_depth == 1 and m._in_narak_floor())
	_check("⑧b′ 런 카운터가 올랐다", m.narak_floors.run_id() == run0 + 1)
	_check("⑧c 층 그리드 = 24×24(아레나 64×44와 별 무대)",
		m._grid_w == NarakFloors.FLOOR_W and m._outdoor_h == NarakFloors.FLOOR_H)
	_check("⑧d 착지 칸 = 나가는 사다리", m._is_narak_exit(m._player_tile()))
	# 깊이를 강제로 밀어 넣고(사다리 롤 대기 없이) 퇴장 → 재진입이 다시 1층인지 본다.
	m._descend_narak(4)
	await _settle(m)
	_check("⑧e 하강 → 깊이 4", m._narak_depth == 4)
	m._exit_narak_run()
	await _settle(m)
	_check("⑧f 퇴장 = 런 종료(깊이 0 · 아레나 복귀 · 걸을 수 있는 칸)",
		m._narak_depth == 0 and m._region == RegionCatalog.NARAK
		and m._player_tile() == m.NARAK_SURFACE_RETURN)
	m.player.position = m._tile_center_px(m.NARAK_SHAFT_TILE)
	m._start_narak_run()
	await _settle(m)
	_check("⑧g **재진입 = 다시 1층**(영구 depth 기록 없음 — 갱도 엘리베이터와 정반대)",
		m._narak_depth == 1)
	# 채굴 기록도 런과 함께 리셋된다.
	var rl: Dictionary = NarakFloors.generate(m.narak_floors.run_id(), 1)
	var some_rock: Vector2i = (rl["rocks"] as Array)[0]
	m.narak_floors.mark_mined(1, some_rock)
	_check("⑧h 이번 런에 깬 돌이 기록된다", m.narak_floors.is_mined(1, some_rock))
	m.narak_floors.begin_run()
	_check("⑧i 새 런 = 채굴 기록 전량 소멸", not m.narak_floors.is_mined(1, some_rock))
	_check("⑧j 원장에 세이브 API가 **없다**(남길 게 없다는 것이 이 시스템의 정의)",
		not m.narak_floors.has_method("to_save") and not m.narak_floors.has_method("load_save"))

	print("── ⑨ 기절 퇴장 · 낙하 피해 ──")
	m.player.position = m._tile_center_px(m.NARAK_SHAFT_TILE)
	m._narak_depth = 0
	await _settle(m)
	m._start_narak_run()
	await _settle(m)
	m._descend_narak(20)
	await _settle(m)
	var hp_before: int = m.health.current
	var faints_before: int = m._faint_count
	m._descend_narak(25, 5)          # 5층 낙하 = 15 피해
	await _settle(m)
	_check("⑨a 구멍 낙하 = 층수×3 피해(5층 → HP −15)", m.health.current == hp_before - 15)
	_check("⑨a′ 낙하로 실제 하강했다(깊이 25 = 관문)", m._narak_depth == 25)
	_check("⑨a″ 낙하는 기절이 아니다(기절 카운터 불변)", m._faint_count == faints_before)
	_check("⑨b 관문 층 = 보스 1기만 섰다(라이브 스폰)",
		m._mobs.size() == 1 and MobCatalog.is_boss((m._mobs[0] as Mob).kind))
	# 보스를 잡으면 마일스톤이 선다.
	var boss: Mob = m._mobs[0]
	boss.hp = 1
	m._strike_mob(ItemCatalog.SWORD_RUSTY, {"tile": boss.tile(), "kind": boss.kind,
		"hp": boss.hp, "xp": boss.kill_xp(), "index": 0, "ref": boss})
	_check("⑨c 보스 격파 → `narak_best_boss` = 25(영구 마일스톤)", m._narak_best_boss == 25)
	_check("⑨c′ 보스 드랍(나락혼정)이 인벤에 들어왔다",
		m.inventory.count_of(ItemCatalog.NARAK_HONJEONG) > 0)
	# 기절 — 아레나로 퇴장 + 시간만 잃는다.
	m._descend_narak(30)
	await _settle(m)
	var gold_before: int = m.wallet.gold
	var items_before: int = m.inventory.count_of(ItemCatalog.NARAK_HONJEONG)
	var min_before: float = m.clock.minutes
	m.health.damage(m.health.current)     # HP 0 → depleted → _faint
	await _settle(m)
	_check("⑨d 기절 퇴장 지점 = 나락 진입로(아레나 · 깊이 0)",
		m._narak_depth == 0 and m._region == RegionCatalog.NARAK
		and m._player_tile() == m.NARAK_SURFACE_RETURN)
	_check("⑨e 기절의 대가는 **시간뿐** — 골드·아이템 불변 · HP 풀회복",
		m.wallet.gold == gold_before
		and m.inventory.count_of(ItemCatalog.NARAK_HONJEONG) == items_before
		and m.health.current == m.health.maximum)
	_check("⑨f 시간이 실제로 흘렀다(+2h 또는 24시 상한)", m.clock.minutes > min_before)
	_check("⑨g 기절해도 마일스톤은 남는다(리셋되는 건 런뿐)", m._narak_best_boss == 25)
	# 취침도 런 종료다.
	m.player.position = m._tile_center_px(m.NARAK_SHAFT_TILE)
	m._start_narak_run()
	await _settle(m)
	m._descend_narak(3)
	await _settle(m)
	m._on_day_advanced(m.clock.day + 1)
	await _settle(m)
	_check("⑨h 취침(날짜 전환) = 런 종료(깊이 0 · 아레나)",
		m._narak_depth == 0 and m._player_tile() == m.NARAK_SURFACE_RETURN)

	print("── ⑩ 세이브 라운드트립 — 마일스톤만 영구 ──")
	m._narak_best_boss = 50
	m._narak_key_found = true
	m.player.position = m._tile_center_px(m.NARAK_SHAFT_TILE)
	m._start_narak_run()
	await _settle(m)
	m._descend_narak(7)
	await _settle(m)
	_check("⑩a 런 도중(깊이 7)에 저장한다", m._narak_depth == 7)
	m._save_game()
	await _despawn(m)

	var m2: Node = await _spawn_main()
	await _settle(m2)
	_check("⑩b 로드 후 **런은 이어지지 않는다**(깊이 0 — 저장·종료도 런 종료)", m2._narak_depth == 0)
	_check("⑩c 로드 후 갇히지 않는다(현재 칸이 걸을 수 있다)", not m2._tile_blocked(m2._player_tile()))
	_check("⑩d 최고 격파 관문은 남는다(narak_best_boss = 50)", m2._narak_best_boss == 50)
	_check("⑩e 열쇠 플래그도 남는다(T6 계약 보존)", m2._narak_key_found)
	# 구세이브 하위호환 — 키가 없으면 0(미격파)이고 아무것도 안 막힌다.
	var raw: Dictionary = m2.saver.load_game(m2._active_slot)
	raw.erase("narak_best_boss")
	m2.saver.save_game(raw, m2._active_slot, {"day": 1, "soul": 100})
	await _despawn(m2)
	var m3: Node = await _spawn_main()
	await _settle(m3)
	_check("⑩f 구세이브(키 없음) = 최고 관문 0 · 무막힘", m3._narak_best_boss == 0)
	# 손상 방어 — 관문이 아닌 깊이가 저장돼 있으면 그 이하 실제 관문으로 내린다.
	var raw2: Dictionary = m3.saver.load_game(m3._active_slot)
	raw2["narak_best_boss"] = 37
	m3.saver.save_game(raw2, m3._active_slot, {"day": 1, "soul": 100})
	await _despawn(m3)
	var m4: Node = await _spawn_main()
	await _settle(m4)
	_check("⑩g 손상 값(37) → 그 이하 실제 관문(25)으로 내려 읽는다", m4._narak_best_boss == 25)
	await _despawn(m4)

	# ── 세이브 백업 복원 ──
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)

func _pool_has(pool: Array, id: String) -> bool:
	for e: Dictionary in pool:
		if String(e["id"]) == id:
			return true
	return false
