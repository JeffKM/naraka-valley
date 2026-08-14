extends SceneTree
# ★[S10-T7 / ADR-0069 결정 10] 반딧넋 수집(firefly_soul.gd + main 배선) 검증(ephemeral 헤드리스).
# "길 잃은 넋 45를 찾아 안치하면 30에서 명부 시련장이 열린다"가 코드로 성립하는지 본다.
#
# ★ 핵심 불변식(수락 기준 5축 + 침범 금지 2축):
#   ① 표 무결성·총원 파생 — 45 = 고정 30 + 드랍 15가 **표에서 파생**된다(호출부 하드코딩 0).
#      ★ 카운트만 세지 않는다: 구역별 개수·id 유일성·드랍 몫 접두를 **구성 요소로** 짚는다.
#   ② 고정 배치 결정성·실그리드 — 전 구역 좌표가 걸을 수 있고 **스폰에서 걸어 닿으며**(flood-fill),
#      워프 트리거·건물 문·채집 존·팬닝 존·경작 칸과 한 칸도 안 겹친다. 표는 재부팅에도 불변.
#   ③ 드랍 결정성 — 같은 day·같은 serial = 같은 답 / 다른 day = 다른 답 / 몫 15가 동나면 영원히 ""
#      / 고정 배치 id는 드랍으로 절대 안 나온다.
#   ④ 안치 카운트 — 줍기 = 원장 즉시 기록(인벤 경유 0)·멱등·구역별 분자·고정/드랍 분자 합 = 총 분자.
#   ⑤ 게이트 플래그 — 문턱 **경계 ±1**(29 닫힘 / 30 열림 / 31 열림)·저장 플래그 부재(파생).
#   ⑥ 세이브 왕복 — 새 키 하나·하위호환(키 없는 구세이브 = 빈 원장)·미지 id 드롭·손상 방어.
#   ⑦ ⚠️ **혼백관 기증 분모 불변** — Museum.donatable_ids()·MILESTONES가 한 톨도 안 바뀌었다.
#      (반딧넋이 별개 원장으로 선 유일한 이유가 이것이다 — 오염되면 이미 받은 답례가 어긋난다.)
# 실행: godot --headless --path game --script res://playtest/firefly_soul_test.gd

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

# 원장 상태 지문(결정성·왕복 비교용).
func _fingerprint(led: FireflySouls) -> String:
	var rows: Array = []
	for id in led.collected:
		rows.append("%s=%d" % [String(id), int(led.collected[id])])
	rows.sort()
	return "|".join(rows)

# 백팩 전 슬롯 지문(줍기가 아이템을 한 톨도 안 건드렸음을 슬롯 단위로 단언한다).
func _inv_fingerprint(m: Node) -> String:
	var rows := PackedStringArray()
	for i in Inventory.SIZE:
		rows.append("%s×%d" % [m.inventory.id_at(i), m.inventory.count_at(i)])
	return "|".join(rows)

# 이 칸이 실그리드에서 걸을 수 있는가(막힌 지형·물 = false).
#   ★ `is_solid`만으로는 부족하다 — WATER는 terrain corner라 WORLD_SOLID_TILES에 없다(충돌은 따로
#     단다). 그래서 반딧넋이 설 수 있는 바닥을 **GROUND/PATH로 명시**해 물 위 배치를 원천 배제한다.
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return (id == m.GROUND or id == m.PATH) and not m.is_solid(id)

# 그 구역 스폰에서 걸어 닿는 칸 집합(4방 flood-fill — 프롭 충돌 포함).
func _reachable(m: Node, region: String) -> Dictionary:
	var occ: Dictionary = {}
	var layout: Array = []
	if region == RegionCatalog.HOME:
		layout = m._home_prop_entries()
	elif region == RegionCatalog.NARU_VILLAGE:
		layout = m._prop_layouts.get("VILLAGE_OUTDOOR", [])
	for entry in layout:
		if not entry[0] in m.SOLID_PROPS:
			continue
		var sz: Vector2 = entry[0].get_size()
		var tw: int = maxi(int(round(sz.x / m.TILE)), 1)
		var th: int = maxi(int(round(sz.y / m.TILE)), 1)
		for a: Vector2i in entry[1]:
			for dx in range(tw):
				for dy in range(th):
					occ[a + Vector2i(dx, dy)] = true
	var reach: Dictionary = {}
	var spawn: Vector2i = RegionCatalog.spawn_of(region)
	var q: Array = [spawn]
	reach[spawn] = true
	while not q.is_empty():
		var cur: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nt: Vector2i = cur + d
			if reach.has(nt) or occ.has(nt):
				continue
			if nt.x < 0 or nt.y < 0 or nt.x >= m._grid_w or nt.y >= m._outdoor_h:
				continue
			if m.is_solid(m._grid[nt.y][nt.x]) or m._grid[nt.y][nt.x] == m.WATER:
				continue
			reach[nt] = true
			q.append(nt)
	return reach

func _initialize() -> void:
	print("══ S10-T7 반딧넋 수집(firefly_soul.gd) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.firefly_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 표 무결성 · 총원 파생 ──
	print("── ① 표 무결성 · 총원·게이트 파생 ──")
	var fixed: Array = FireflySouls.FIXED
	_check("①a ADR-0069 결정 10 계약 — 총원 45 = 고정 %d + 드랍 %d (전부 표 파생)"
			% [FireflySouls.fixed_count(), FireflySouls.DROP_COUNT],
		FireflySouls.total_count() == 45
		and FireflySouls.fixed_count() + FireflySouls.DROP_COUNT == FireflySouls.total_count()
		and FireflySouls.fixed_count() == fixed.size()
		and FireflySouls.drop_ids().size() == FireflySouls.DROP_COUNT)
	_check("①b 게이트 = 30(결정 10 '30개 = 명부 시련장 개방') · 고정분 총수와 정확히 같다",
		FireflySouls.GATE_COUNT == 30 and FireflySouls.GATE_COUNT == FireflySouls.fixed_count())
	# id 유일성 + 접두 분리 — 고정과 드랍이 한 id 공간에서 절대 안 겹친다.
	var seen := {}
	var dup := 0
	for id in FireflySouls.all_ids():
		if seen.has(String(id)):
			dup += 1
		seen[String(id)] = true
	_check("①c 45 id 전량 유일 · 전량 is_valid_id 통과",
		dup == 0 and seen.size() == FireflySouls.total_count()
		and FireflySouls.is_valid_id("ff_home_1") and FireflySouls.is_valid_id("ff_drop_1")
		and not FireflySouls.is_valid_id("ff_nope") and not FireflySouls.is_valid_id(""))
	var drop_pref_ok := true
	for id in FireflySouls.drop_ids():
		if not String(id).begins_with("ff_drop_") or not FireflySouls.is_drop_id(String(id)):
			drop_pref_ok = false
	var fixed_not_drop := true
	for id in FireflySouls.fixed_ids():
		if FireflySouls.is_drop_id(String(id)):
			fixed_not_drop = false
	_check("①d 드랍 몫은 ff_drop_* 접두 전용 · 고정 배치 id는 하나도 드랍 몫이 아니다",
		drop_pref_ok and fixed_not_drop)
	# ★ 구성 요소 명시 — 8구역 전부에 배치가 있고, 구역별 개수가 표와 일치한다.
	var want := {
		RegionCatalog.HOME: 4, RegionCatalog.NARU_VILLAGE: 5, RegionCatalog.SAMDOCHEON: 4,
		RegionCatalog.HWANGCHEONHAE: 4, RegionCatalog.JEOSEUNG_FOREST: 4,
		RegionCatalog.MIHOK_FOREST: 4, RegionCatalog.EOPHWA_MINE: 3, RegionCatalog.NARAK: 2,
	}
	var region_ok := true
	var region_sum := 0
	for r: String in RegionCatalog.ids():
		var n := FireflySouls.region_total(r)
		region_sum += n
		if n != int(want[r]) or n <= 0:
			region_ok = false
	_check("①e 도달 가능 8구역 **전부**에 배치가 있다(안식4·나루5·삼도천4·황천해4·저승숲4·미혹4·갱도3·나락2)",
		region_ok and FireflySouls.regions().size() == RegionCatalog.ids().size())
	_check("①f 구역별 합 %d = 고정분 총수 %d(빠진 구역·유령 구역 0)"
			% [region_sum, FireflySouls.fixed_count()],
		region_sum == FireflySouls.fixed_count())
	# 같은 구역 안 좌표 중복 0 + 행 스키마 무결성.
	var row_ok := true
	var tile_seen := {}
	var tile_dup := 0
	for row in fixed:
		if not row.has("id") or not row.has("region") or not row.has("tile"):
			row_ok = false
			continue
		if not RegionCatalog.has_region(String(row["region"])):
			row_ok = false
		var key := "%s:%s" % [String(row["region"]), str(row["tile"])]
		if tile_seen.has(key):
			tile_dup += 1
		tile_seen[key] = true
	_check("①g 전 행이 {id,region,tile} 스키마 · region이 실존 구역 · 같은 구역 좌표 중복 0",
		row_ok and tile_dup == 0)
	# 마일스톤 — 전부 게이트 위 · 보상 id가 실존 아이템 · 오름차순.
	var ms_ok := true
	var prev := FireflySouls.GATE_COUNT
	for mrow in FireflySouls.MILESTONES:
		var c := int(mrow["count"])
		if c <= FireflySouls.GATE_COUNT or c <= prev or c > FireflySouls.total_count():
			ms_ok = false
		if not ItemCatalog.has_item(String(mrow["reward_id"])) or int(mrow["n"]) <= 0:
			ms_ok = false
		prev = c
	_check("①h 마일스톤 %d행 — 전부 게이트(30) **위** · 오름차순 · 보상이 실존 아이템"
			% FireflySouls.MILESTONES.size(),
		ms_ok and FireflySouls.MILESTONES.size() > 0)
	# ⚠️ 오색혼옥 미지급 — 초희귀는 들어오는 길이 좁아야 한다(ADR-0063 결정 2).
	var osaek := false
	for mrow2 in FireflySouls.MILESTONES:
		if String(mrow2["reward_id"]) == ItemCatalog.GEM_OSAEK_HONOK:
			osaek = true
	_check("①i ⚠️ 답례에 오색혼옥이 없다(ADR-0063 초희귀 지위 — 혼백관 완주 답례와 중복 금지)", not osaek)

	# ── ③ 드랍 결정성 ──
	print("── ③ 활동 드랍 결정성 · 몫 유한 ──")
	var srcs := [FireflySouls.SRC_HARVEST, FireflySouls.SRC_CHOP,
		FireflySouls.SRC_MINE, FireflySouls.SRC_FISH]
	var permil_ok := true
	for s: String in srcs:
		if FireflySouls.permil_of(s) <= 0 or FireflySouls.permil_of(s) >= 1000:
			permil_ok = false
	_check("③a 네 활동(수확·벌목·채광·낚시) 전부 유효 퍼밀 · 미지 원천은 0(절대 안 나옴)",
		permil_ok and FireflySouls.DROP_PERMIL.size() == 4
		and FireflySouls.permil_of("nope") == 0 and FireflySouls.permil_of("") == 0)
	_check("③b 같은 day·같은 serial·같은 원장 = 같은 답(되감기 재롤 차단)",
		FireflySouls.peek_drop(FireflySouls.SRC_FISH, 12, 777, {})
			== FireflySouls.peek_drop(FireflySouls.SRC_FISH, 12, 777, {}))
	# 다른 day면 결과열이 갈린다 — 1년을 훑어 히트 날짜 집합이 서로 다른지 본다.
	var hits_a: Array = []
	var hits_b: Array = []
	for day in range(1, 113):
		if FireflySouls.peek_drop(FireflySouls.SRC_FISH, day, 777, {}) != "":
			hits_a.append(day)
		if FireflySouls.peek_drop(FireflySouls.SRC_FISH, day, 778, {}) != "":
			hits_b.append(day)
	_check("③c 다른 day·다른 serial이면 결과가 갈린다(히트 날짜열 상이 — 상수 함수 아님)",
		hits_a != hits_b and (hits_a.size() > 0 or hits_b.size() > 0))
	# 히트율이 퍼밀 밴드 근처인가(가중이 통째로 죽거나 폭주하지 않는다).
	var fish_hits := 0
	for i in 20000:
		if FireflySouls.peek_drop(FireflySouls.SRC_FISH, 5, i, {}) != "":
			fish_hits += 1
	_check("③d 낚시 히트율 %.1f퍼밀 ≈ 표 %d퍼밀(±10 — 해시 편향 없음)"
			% [fish_hits / 20.0, FireflySouls.permil_of(FireflySouls.SRC_FISH)],
		absf(fish_hits / 20.0 - float(FireflySouls.permil_of(FireflySouls.SRC_FISH))) < 10.0)
	# 지목은 **드랍 몫에서만** 나온다 + 이미 주운 것은 다시 안 나온다.
	var picked_ids := {}
	for i in 20000:
		var pid := FireflySouls.peek_drop(FireflySouls.SRC_CHOP, 9, i, {})
		if pid != "":
			picked_ids[pid] = true
	var only_drop := true
	for pid2 in picked_ids:
		if not FireflySouls.is_drop_id(String(pid2)):
			only_drop = false
	_check("③e 드랍은 **드랍 몫 15에서만** 나온다(고정 배치 id 침범 0) · 몫 전량이 실제로 등장",
		only_drop and picked_ids.size() == FireflySouls.DROP_COUNT)
	# 몫이 동나면 영원히 "" — 총원이 45를 못 넘는 구조적 보증.
	var all_drop := {}
	for id3 in FireflySouls.drop_ids():
		all_drop[String(id3)] = 1
	var after_exhaust := 0
	for i in 3000:
		if FireflySouls.peek_drop(FireflySouls.SRC_MINE, 3, i, all_drop) != "":
			after_exhaust += 1
	_check("③f 드랍 몫 15가 동나면 그 뒤로 영원히 없음(총원 45 초과 불가)", after_exhaust == 0)
	# 이미 주운 것은 다시 안 나온다(중복 입수 0).
	var owned_one := {"ff_drop_1": 1}
	var redup := 0
	for i in 8000:
		if FireflySouls.peek_drop(FireflySouls.SRC_HARVEST, 4, i, owned_one) == "ff_drop_1":
			redup += 1
	_check("③g 이미 안치한 넋은 두 번 안 나온다(중복 입수 0)", redup == 0)

	# ── ④ 안치 카운트 ──
	print("── ④ 안치 · 멱등 · 분자 구성 ──")
	var led := FireflySouls.new()
	_check("④a 새 원장 = 0/45 · 문 닫힘 · 남은 수 = 게이트 문턱 그대로",
		led.collected_count() == 0 and not led.gate_open()
		and led.remaining_to_gate() == FireflySouls.GATE_COUNT and not led.is_complete())
	var first_row: Dictionary = fixed[0]
	var fid := String(first_row["id"])
	var freg := String(first_row["region"])
	var ftile: Vector2i = first_row["tile"]
	_check("④b 표 질의 — spot_id_at이 그 칸의 id를 준다 · 빈 칸은 \"\"",
		FireflySouls.spot_id_at(freg, ftile) == fid
		and FireflySouls.spot_id_at(freg, Vector2i(-9, -9)) == ""
		and FireflySouls.spot_id_at("nope", ftile) == "")
	_check("④c 미수집 스폿만 live_spot_at이 준다 · 안치 = 1회성(멱등)",
		led.live_spot_at(freg, ftile) == fid and led.collect(fid, 7)
		and not led.collect(fid, 9) and led.collected_count() == 1
		and led.day_of(fid) == 7 and led.live_spot_at(freg, ftile) == "")
	_check("④d 표에 없는 id는 안치 거절(미지 id가 분자에 못 낀다)",
		not led.collect("ff_nope", 7) and not led.collect("", 7) and led.collected_count() == 1)
	_check("④e 안치한 칸은 필드 목록에서 빠진다(live_tiles = 남은 자리만)",
		led.live_tiles(freg).size() == FireflySouls.region_total(freg) - 1
		and not led.live_tiles(freg).has(ftile))
	# 분자 구성 — 고정 분자 + 드랍 분자 = 총 분자(★ 카운트만 세지 않는 명시 단언).
	led.collect("ff_drop_1", 8)
	led.collect("ff_drop_2", 8)
	_check("④f 고정 분자 %d + 드랍 분자 %d = 총 분자 %d(구성 요소 합이 총계와 일치)"
			% [led.collected_fixed_count(), led.collected_drop_count(), led.collected_count()],
		led.collected_fixed_count() == 1 and led.collected_drop_count() == 2
		and led.collected_fixed_count() + led.collected_drop_count() == led.collected_count())
	_check("④g 구역 분자 — 안치한 그 구역만 1, 나머지 구역은 0",
		led.region_collected(freg) == 1
		and led.region_collected(RegionCatalog.NARAK) == (1 if freg == RegionCatalog.NARAK else 0))

	# ── ⑤ 게이트 경계 ±1 ──
	print("── ⑤ 게이트 술어(문턱 경계 ±1) ──")
	var ids: Array = FireflySouls.all_ids()
	var g29 := FireflySouls.new()
	for i in FireflySouls.GATE_COUNT - 1:
		g29.collect(String(ids[i]), 1)
	_check("⑤a %d개 = 문 **닫힘** · 남은 1" % (FireflySouls.GATE_COUNT - 1),
		g29.collected_count() == FireflySouls.GATE_COUNT - 1
		and not g29.gate_open() and g29.remaining_to_gate() == 1)
	g29.collect(String(ids[FireflySouls.GATE_COUNT - 1]), 1)
	_check("⑤b %d개 = 문 **열림** · 남은 0" % FireflySouls.GATE_COUNT,
		g29.gate_open() and g29.remaining_to_gate() == 0)
	g29.collect(String(ids[FireflySouls.GATE_COUNT]), 1)
	_check("⑤c %d개 = 여전히 열림(한 번 열린 문은 안 닫힌다)" % (FireflySouls.GATE_COUNT + 1),
		g29.gate_open() and g29.collected_count() == FireflySouls.GATE_COUNT + 1)
	# ★ 게이트는 **저장 플래그가 아니라 파생**이다 — to_save에 문 상태를 뜻하는 키가 없다.
	var gsave: Dictionary = g29.to_save()
	_check("⑤d 세이브에 게이트 플래그 키가 없다(열림은 언제나 카운트 파생 — 어긋날 자리 0)",
		gsave.size() == 2 and gsave.has("collected") and gsave.has("claimed")
		and not gsave.has("gate") and not gsave.has("gate_open") and not gsave.has("trial"))
	# 마일스톤 — 게이트 아래선 하나도 안 뜨고, 문턱을 넘으면 낮은 것부터 뜬다.
	_check("⑤e 안치 %d에선 마일스톤 답례 0건(전부 게이트 위에 걸려 있다)"
			% g29.collected_count(), g29.pending_milestones().is_empty())
	var gfull := FireflySouls.new()
	for id4 in ids:
		gfull.collect(String(id4), 2)
	_check("⑤f 완주(45) = is_complete · 마일스톤 %d건 전부 대기 · 지급 후 재대기 0"
			% FireflySouls.MILESTONES.size(),
		gfull.is_complete()
		and gfull.pending_milestones().size() == FireflySouls.MILESTONES.size())
	for mrow3 in FireflySouls.MILESTONES:
		gfull.claim(int(mrow3["count"]))
	gfull.claim(int(FireflySouls.MILESTONES[0]["count"]))     # 중복 claim = 무동작
	_check("⑤g 지급 잠금은 멱등(같은 문턱을 두 번 잠가도 목록이 안 늘어난다)",
		gfull.pending_milestones().is_empty()
		and gfull.claimed.size() == FireflySouls.MILESTONES.size())

	# ── ⑥ 세이브 왕복 · 하위호환 · 손상 방어 ──
	print("── ⑥ 세이브 왕복 ──")
	var s1 := FireflySouls.new()
	s1.collect("ff_home_1", 11)
	s1.collect("ff_drop_3", 12)
	s1.claim(35)
	var s2 := FireflySouls.new()
	s2.load_save(s1.to_save())
	_check("⑥a 왕복 — 안치 id·day·지급 기록 전량 보존",
		_fingerprint(s2) == _fingerprint(s1) and s2.claimed == s1.claimed
		and s2.day_of("ff_home_1") == 11)
	var s3 := FireflySouls.new()
	s3.collect("ff_home_1", 1)
	s3.load_save({})
	_check("⑥b 하위호환 — 키 없는 구세이브 = 빈 원장(안치 0 · 문 닫힘)",
		s3.collected_count() == 0 and not s3.gate_open() and s3.claimed.is_empty())
	var s4 := FireflySouls.new()
	s4.load_save({"collected": {"ff_home_1": 3, "ff_ghost_99": 3, "ff_drop_99": 3}, "claimed": [35]})
	_check("⑥c 미지 id 드롭 — 표 밖 id는 조용히 버린다(\"46/45\" 사고 차단)",
		s4.collected_count() == 1 and s4.is_collected("ff_home_1")
		and not s4.is_collected("ff_ghost_99") and not s4.is_collected("ff_drop_99")
		and s4.claimed == [35])
	var s5 := FireflySouls.new()
	s5.load_save({"collected": "손상", "claimed": 7})
	_check("⑥d 손상 방어 — 비-dict/비-array 값에도 빈 원장으로 살아남는다",
		s5.collected_count() == 0 and s5.claimed.is_empty())

	# ── ⑦ ⚠️ 혼백관 기증 분모 불변 ──
	print("── ⑦ ⚠️ Museum 기증 분모 불가침 ──")
	_check("⑦a 기증 분모 = 유품 %d + 책 %d(반딧넋은 한 톨도 안 얹혔다)"
			% [ItemCatalog.RELICS.size(), Books.book_ids().size()],
		Museum.donatable_ids().size() == ItemCatalog.RELICS.size() + Books.book_ids().size())
	var ff_in_museum := false
	for id5 in FireflySouls.all_ids():
		if Museum.is_donatable(String(id5)) or ItemCatalog.has_item(String(id5)):
			ff_in_museum = true
	_check("⑦b ⚠️ 반딧넋 45 id 중 **아이템으로 등재된 것이 0**(= 버리기·상자·출하 경로 원천 부재)",
		not ff_in_museum)
	_check("⑦c Museum 마일스톤 사다리 불변(꼭대기 = 기증 11)",
		Museum.MILESTONES.size() == 6
		and int(Museum.MILESTONES[Museum.MILESTONES.size() - 1]["count"])
			== Museum.donatable_ids().size())

	# ── ② 라이브 배선(main) — 실그리드 · 도달성 · 배제 · [F] 줍기 ──
	print("── ②⑧ 라이브 배선(실그리드 · 도달성 · 줍기 · 혼백관) ──")
	var m: Node = await _spawn_main()
	_check("⑧a 원장 배선(RefCounted) · 시련장 게이트 술어 공개(T8 소비 지점)",
		m.fireflies != null and m.has_method("trial_ground_open") and not m.trial_ground_open())
	m._indoor = ""
	for region: String in FireflySouls.regions():
		m._rebuild_region(region)
		var reach := _reachable(m, region)
		var blocked := 0
		var unreach := 0
		var banned := 0
		var farm := 0
		var rows: Array = FireflySouls.spots_in(region)
		for row in rows:
			var t: Vector2i = row["tile"]
			if not _walkable(m, t):
				blocked += 1
			if not reach.has(t):
				unreach += 1
			if region == RegionCatalog.HOME and m._is_farmable(t):
				farm += 1
			# 워프 트리거·건물 문·채집 존·팬닝 존과 겹치면 안 된다.
			for w in RegionCatalog.warps_of(region):
				if Vector2i(w["at"]) == t:
					banned += 1
			for bid in m._buildings:
				var b: Dictionary = m._buildings[bid]
				if String(b.get("region", "")) != region:
					continue
				for k in ["ext_door", "ext_door2", "out_tile"]:
					if b.has(k) and Vector2i(b[k]) == t:
						banned += 1
			for z in ForageSpawns.zones().get(region, []):
				if Rect2i(z["rect"]).has_point(t):
					banned += 1
			if PanningSpots.in_zone(region, t):
				banned += 1
		_check("②%s 고정 배치 %d칸 — 전부 GROUND/PATH 통행 가능 · 스폰에서 걸어 닿음 · 워프/문/채집존/팬닝존/경작칸 충돌 0"
			% [region, rows.size()],
			rows.size() > 0 and blocked == 0 and unreach == 0 and banned == 0 and farm == 0)

	# 라이브 줍기 — 삼도천 첫 스폿을 [F]로 거둔다(안치가 인벤을 안 거친다).
	m._rebuild_region(RegionCatalog.SAMDOCHEON)
	var live_rows: Array = FireflySouls.spots_in(RegionCatalog.SAMDOCHEON)
	var lt: Vector2i = live_rows[0]["tile"]
	var lid := String(live_rows[0]["id"])
	var inv_before := _inv_fingerprint(m)
	var e_before: int = m.energy.current
	m._gather_firefly(lt)
	_check("⑧b [F] 줍기 = 원장 즉시 안치 · **혼력 0**(무과금) · 백팩 전 슬롯 불변(아이템 경유 0)",
		m.fireflies.is_collected(lid) and m.energy.current == e_before
		and _inv_fingerprint(m) == inv_before)
	m._gather_firefly(lt)
	_check("⑧c 같은 칸을 다시 [F] = 무동작(멱등 — 카운트가 안 는다)",
		m.fireflies.collected_count() == 1)

	# 라이브 게이트 — 원장을 문턱까지 채우면 main 술어가 따라 열린다.
	var gate_save := {"collected": {}, "claimed": []}
	for i in FireflySouls.GATE_COUNT - 1:
		gate_save["collected"][String(ids[i])] = 1
	m.fireflies.load_save(gate_save)
	_check("⑧d main 게이트 술어 — %d에서 닫힘" % (FireflySouls.GATE_COUNT - 1),
		not m.trial_ground_open())
	gate_save["collected"][String(ids[FireflySouls.GATE_COUNT - 1])] = 1
	m.fireflies.load_save(gate_save)
	_check("⑧e main 게이트 술어 — %d에서 열림(T8이 이 한 줄을 소비한다)" % FireflySouls.GATE_COUNT,
		m.trial_ground_open())

	# 혼백관 안치대 — 좌표가 기증대·열람대와 안 겹치고, 밀린 답례가 여기서 지급된다.
	_check("⑧f 안치대 좌표가 기증대·열람대와 갈린다(한 방 세 창구 · 조준 칸 충돌 0)",
		m.MUSEUM_FIREFLY_TILE != m.MUSEUM_DONATE_TILE
		and m.MUSEUM_FIREFLY_TILE != m.MUSEUM_CODEX_TILE
		and Rect2i(m.MUSEUM_RECT).has_point(m.MUSEUM_FIREFLY_TILE))
	var museum_before: int = m.museum.donated_count()
	var full_save := {"collected": {}, "claimed": []}
	for id6 in ids:
		full_save["collected"][String(id6)] = 2
	m.fireflies.load_save(full_save)
	var reward_id := String(FireflySouls.MILESTONES[0]["reward_id"])
	var reward_before: int = m.inventory.count_of(reward_id)
	m._claim_firefly_milestones()
	_check("⑧g 안치대 답례 — 완주 시 %d행 전부 지급 · 재호출 0건(멱등)"
			% FireflySouls.MILESTONES.size(),
		m.fireflies.pending_milestones().is_empty()
		and m.inventory.count_of(reward_id) > reward_before)
	m._claim_firefly_milestones()
	_check("⑧h ⚠️ 답례가 혼백관 기증 원장을 한 톨도 안 건드렸다(분모 불가침)",
		m.museum.donated_count() == museum_before and m.museum.claimed.is_empty())
	_check("⑧i 안치대 본문이 원장 파생으로 선다(구역 줄 %d + 머리말 + 드랍 줄 + 게이트 줄)"
			% FireflySouls.regions().size(),
		m._firefly_lines().size() == FireflySouls.regions().size() + 3)

	# 재부팅 왕복(main 통째) — 슬라이스 키가 세이브를 타고 살아 돌아온다.
	var live_fp := _fingerprint(m.fireflies)
	var live_claimed: Array = m.fireflies.claimed.duplicate()
	m._save_game()
	await _despawn(m)
	var m2: Node = await _spawn_main()
	_check("⑧j 재부팅 후 복원 — 안치 45 전량 · 지급 기록 · 게이트 열림",
		_fingerprint(m2.fireflies) == live_fp
		and m2.fireflies.claimed.size() == live_claimed.size()
		and m2.trial_ground_open() and m2.fireflies.is_complete())
	await _despawn(m2)

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
