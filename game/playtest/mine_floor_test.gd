extends SceneTree
# ★[S5-T1 / ADR-0063 결정 1] 갱도 층 시스템 코어 검증(ephemeral).
#
# 두 층위를 본다:
#   (A) MineFloors 단독 — 층 생성의 **결정성·범위·밴드·사다리 도달성·확률 단조성·엘리베이터·
#       day 리셋·세이브 왕복**. main 없이 순수 함수/원장만 굴린다(빠르고 흔들림 0).
#   (B) main 배선 — 갱도 입구에서 층 1로 내려가고 입구 사다리로 지상에 복귀하는 라운드트립,
#       층 그리드 치수·카메라, 곡괭이 채굴(혼력 과금 + day-한정 원장 기록), 구세이브 하위호환.
#
# ★ 핵심 불변식:
#   ① 같은 (day, floor)는 몇 번을 굴려도 같은 배치(결정성 — 헤드리스 재현의 유일한 방어선).
#   ② 다른 day는 다른 배치(매일 리필 — 스타듀 정합).
#   ③ 1~60층 전부 무예외 생성 · 61층은 거부(빈 Dictionary).
#   ④ 밴드 경계 = 20/21 · 40/41(잿길·넋골·업화).
#   ⑤ 내려가는 사다리가 항상 있고, 입구에서 **걸어서 닿는다**(flood-fill — 갇힘 0).
#   ⑥ 돌 파괴 사다리 롤이 결정적이고, 남은 돌이 적을수록 확률이 단조 증가한다.
#   ⑦ 엘리베이터 = 도달 깊이 이하 5의 배수(depth 17 → [5,10,15]).
#   ⑧ mine_depth·day-한정 기록 세이브/로드 왕복.
#   ⑨ 갱도 입구 [F] → 층 1(24×24 그리드·입구 착지) → 입구 사다리 → 지상 복귀.
#   ⑩ day가 갈리면 그날 깬 돌 기록이 소멸한다(층 리필).
#   ⑪ 구세이브 하위호환 — "mine"·"mine_floor" 키 없는 세이브 = 지상 0층·깊이 0.
#   ⑫ 회귀 0 — 홈 집 출입·취침 불변, 지상 갱도 무대(64×44)·잠긴 나락 진입로 불변.
# 실행: ./run_tests.sh mine_floor

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# 전환(워프/층 전환) tween이 끝날 때까지 _transitioning 폴링(실시간 tween, 좀비 방지 상한).
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

# 층 배치의 정규 서명(Dictionary 동치 비교에 안 기대고 필드를 문자열로 편다).
func _sig(layout: Dictionary) -> String:
	if layout.is_empty():
		return "<empty>"
	return "%s|%s|%s|%s|%s" % [layout["template"], layout["rect"],
		layout["entrance"], layout["ladder"], layout["rocks"]]

# 방 안에서 입구 → 사다리가 4방향으로 이어지는가(돌 = 벽). 생성기와 **독립 구현**이라
# 생성기의 도달성 보정이 실제로 먹었는지를 바깥에서 검증한다.
func _reaches(layout: Dictionary) -> bool:
	var rect: Rect2i = layout["rect"]
	var blocked := {}
	for r: Vector2i in layout["rocks"]:
		blocked[r] = true
	var goal: Vector2i = layout["ladder"]
	var start: Vector2i = layout["entrance"]
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var t: Vector2i = stack.pop_back()
		if t == goal:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + d
			if seen.has(n) or blocked.has(n) or not rect.has_point(n):
				continue
			seen[n] = true
			stack.append(n)
	return seen.has(goal)

func _initialize() -> void:
	print("══ S5-T1 갱도 층 시스템 코어 검증(ADR-0063 결정 1) ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.mine_floor_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 결정성: 같은 (day, floor) 2회 생성 = 동일 ──────────────────────────
	var same_ok := true
	for f in [1, 7, 23, 41, 60]:
		var a := MineFloors.generate(9, int(f))
		var b := MineFloors.generate(9, int(f))
		if _sig(a) != _sig(b):
			same_ok = false
	_check("① 같은 day·floor 2회 생성 동일(결정성)", same_ok)
	_check("①b 같은 층이라도 시드가 day를 물어 원장 없이 재파생 가능",
		_sig(MineFloors.generate(3, 12)) == _sig(MineFloors.generate(3, 12)))

	# ── ② 다른 day는 다른 배치 ───────────────────────────────────────────────
	var diff := 0
	for f in range(1, 21):
		if _sig(MineFloors.generate(1, f)) != _sig(MineFloors.generate(2, f)):
			diff += 1
	_check("② 다른 day = 다른 배치(20개 층 중 20개 상이)", diff == 20)

	# ── ③ 1~60층 무예외 생성 · 61층 거부 ─────────────────────────────────────
	var all_ok := true
	var rock_total := 0
	for f in range(1, MineFloors.MAX_FLOOR + 1):
		var l := MineFloors.generate(5, f)
		if l.is_empty() or int(l["floor"]) != f:
			all_ok = false
			break
		var rect: Rect2i = l["rect"]
		# 방은 그리드 안(사방 최소 1칸 벽)이고 두 사다리는 방 안이다.
		if rect.position.x < 1 or rect.position.y < 1 \
				or rect.end.x > MineFloors.FLOOR_W - 1 or rect.end.y > MineFloors.FLOOR_H - 1:
			all_ok = false
			break
		if not rect.has_point(l["entrance"]) or not rect.has_point(l["ladder"]):
			all_ok = false
			break
		rock_total += (l["rocks"] as Array).size()
	_check("③ 1~60층 전부 생성(방·사다리 그리드 안)", all_ok)
	_check("③b 돌이 실제로 깔린다(60층 합계 > 0)", rock_total > 0)
	_check("③c 61층 거부(빈 Dictionary)", MineFloors.generate(5, 61).is_empty())
	_check("③d 0층·음수층 거부", MineFloors.generate(5, 0).is_empty() and MineFloors.generate(5, -3).is_empty())
	_check("③e is_valid_floor 경계", MineFloors.is_valid_floor(1) and MineFloors.is_valid_floor(60) \
		and not MineFloors.is_valid_floor(0) and not MineFloors.is_valid_floor(61))

	# ── ④ 밴드 경계(20/21 · 40/41) ───────────────────────────────────────────
	_check("④ 1~20 = 잿길", MineFloors.band_of(1) == MineFloors.BAND_JAETGIL \
		and MineFloors.band_of(20) == MineFloors.BAND_JAETGIL)
	_check("④b 21~40 = 넋골", MineFloors.band_of(21) == MineFloors.BAND_NEOKGOL \
		and MineFloors.band_of(40) == MineFloors.BAND_NEOKGOL)
	_check("④c 41~60 = 업화", MineFloors.band_of(41) == MineFloors.BAND_EOPHWA \
		and MineFloors.band_of(60) == MineFloors.BAND_EOPHWA)
	_check("④d 범위 밖 밴드 \"\"", MineFloors.band_of(0) == "" and MineFloors.band_of(61) == "")
	_check("④e 밴드 이름(잿길·넋골·업화)",
		MineFloors.band_name(MineFloors.BAND_JAETGIL) == "잿길" \
		and MineFloors.band_name(MineFloors.BAND_NEOKGOL) == "넋골" \
		and MineFloors.band_name(MineFloors.BAND_EOPHWA) == "업화")

	# ── ⑤ 사다리 항상 존재 · 입구에서 도달 가능(독립 flood-fill) ─────────────
	var reach_ok := true
	var sep_ok := true
	for day in [1, 2, 3]:
		for f in range(1, MineFloors.MAX_FLOOR + 1):
			var l := MineFloors.generate(day, f)
			if l["ladder"] == l["entrance"]:
				sep_ok = false
			if not _reaches(l):
				reach_ok = false
	_check("⑤ 내려가는 사다리 ≠ 입구(3일 × 60층)", sep_ok)
	_check("⑤b 입구 → 사다리 걸어서 도달(3일 × 60층 flood-fill)", reach_ok)
	var rocks_clear := true
	for f in range(1, 31):
		var l := MineFloors.generate(4, f)
		for r: Vector2i in l["rocks"]:
			if r == l["entrance"] or r == l["ladder"]:
				rocks_clear = false
	_check("⑤c 돌이 두 사다리 칸을 덮지 않는다", rocks_clear)

	# ── ⑥ 사다리 롤 결정성 + 남은 돌↓ ⇒ 확률↑ 단조 ─────────────────────────
	var roll_a := MineFloors.roll_ladder(7, 3, Vector2i(5, 5), 20)
	var roll_b := MineFloors.roll_ladder(7, 3, Vector2i(5, 5), 20)
	_check("⑥ 같은 (day,층,칸,남은돌) 롤 2회 동일(결정성)", roll_a == roll_b)
	var mono := true
	var prev := MineFloors.ladder_chance(60)
	for left in range(59, -1, -1):
		var c := MineFloors.ladder_chance(left)
		if c <= prev:
			mono = false
		prev = c
	_check("⑥b 남은 돌이 줄수록 확률 단조 증가(60→0)", mono)
	_check("⑥c base 2% + 1/(남은+1) — 남은 0이면 100%",
		is_equal_approx(MineFloors.ladder_chance(0), 1.0))
	_check("⑥d 몹 전멸 가산 +4%(S5-T5 훅 인자)",
		is_equal_approx(MineFloors.ladder_chance(99, true) - MineFloors.ladder_chance(99, false),
			MineFloors.LADDER_MOBS_CLEARED))
	_check("⑥e 명부의 운 가산 인자 자리",
		MineFloors.ladder_chance(99, false, 0.10) > MineFloors.ladder_chance(99, false, 0.0))

	# ── ⑦ 엘리베이터 목록(도달 깊이 파생) ────────────────────────────────────
	_check("⑦ depth 17 → [5,10,15]", str(MineFloors.elevator_floors(17)) == "[5, 10, 15]")
	_check("⑦b depth 4 → 빈 목록", MineFloors.elevator_floors(4).is_empty())
	_check("⑦c depth 5 → [5]", str(MineFloors.elevator_floors(5)) == "[5]")
	_check("⑦d depth 60 → 12개(5~60)", MineFloors.elevator_floors(60).size() == 12)

	# ── ⑧ 세이브/로드 왕복(mine_depth 영구 + day-한정 기록) ──────────────────
	var mf := MineFloors.new()
	mf.advance_day(11)
	mf.reach_floor(17)
	mf.reach_floor(9)                       # 더 얕은 층은 최심층을 못 내린다
	mf.mark_mined(3, Vector2i(6, 7))
	mf.add_ladder(3, Vector2i(6, 7))
	var blob := mf.to_save()
	var mf2 := MineFloors.new()
	mf2.load_save(blob)
	_check("⑧ 도달 최심층 왕복(17 — 얕은 재도달은 무시)", mf2.depth() == 17)
	_check("⑧b 엘리베이터 해금 = [5,10,15]", str(mf2.unlocked_elevators()) == "[5, 10, 15]")
	_check("⑧c day-한정 채굴 기록 왕복", mf2.is_mined(3, Vector2i(6, 7)) and mf2.current_day() == 11)
	_check("⑧d 열린 사다리 기록 왕복", mf2.has_ladder(3, Vector2i(6, 7)))
	var mf3 := MineFloors.new()
	mf3.load_save({})
	_check("⑧e 빈 세이브 로드 = 깊이 0·기록 0(방어)",
		mf3.depth() == 0 and not mf3.is_mined(3, Vector2i(6, 7)))
	var mf4 := MineFloors.new()
	mf4.load_save({"depth": 999, "mined": {"61": [[1, 1]], "3": [[4, 4]]}})
	_check("⑧f 손상 방어 — 깊이 클램프·범위 밖 층 폐기",
		mf4.depth() == MineFloors.MAX_FLOOR and not mf4.is_mined(61, Vector2i(1, 1)) \
		and mf4.is_mined(3, Vector2i(4, 4)))

	# ── ⑩ day 리셋(깬 돌 기록 소멸) ─────────────────────────────────────────
	_check("⑩ day 갈리기 전 기록 유지", mf.is_mined(3, Vector2i(6, 7)))
	mf.advance_day(12)
	_check("⑩b day 갈리면 채굴 기록 소멸(층 리필)", not mf.is_mined(3, Vector2i(6, 7)))
	_check("⑩c 열린 사다리도 함께 소멸", not mf.has_ladder(3, Vector2i(6, 7)))
	_check("⑩d 도달 최심층은 영구(리셋 안 됨)", mf.depth() == 17)
	# 같은 날 재진입 = 동일 배치 + 깬 돌 제외(재파밍 차단).
	mf.advance_day(20)
	var base_rocks: Array = MineFloors.generate(20, 5)["rocks"]
	_check("⑩e 배치 돌 존재(테스트 전제)", base_rocks.size() > 0)
	mf.mark_mined(5, base_rocks[0])
	_check("⑩f 같은 날 재진입 = 배치 동일 + 깬 돌 1개 제외",
		mf.rocks_left_count(20, 5) == base_rocks.size() - 1 \
		and not mf.rocks_left(20, 5).has(base_rocks[0]))

	# ── ⑨ main 배선: 갱도 입구 → 층 1 → 지상 복귀 ────────────────────────────
	var m: Node = await _spawn_main()
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	_check("⑨ 지상 갱도 = 64×44·층 0(회귀)",
		m._region == RegionCatalog.EOPHWA_MINE and m._mine_floor == 0 \
		and m._grid_w == 64 and m._outdoor_h == 44)
	m.player.position = m._tile_center_px(m.DUNGEON_GATE_DOOR)
	_check("⑨b 갱도 입구 문 칸 = 진입 트리거(점등)", m._at_dungeon_gate())
	_check("⑨c 진입 층 후보 = [1](엘리베이터 미해금)", str(m._mine_entry_options()) == "[1]")
	m._descend_mine(1)
	await _settle(m)
	_check("⑨d 층 1 진입(_mine_floor=1)", m._mine_floor == 1)
	_check("⑨e 층 그리드 = 24×24(별도 무대)",
		m._grid_w == MineFloors.FLOOR_W and m._outdoor_h == MineFloors.FLOOR_H)
	_check("⑨f 구역 id는 그대로 업화 갱도", m._region == RegionCatalog.EOPHWA_MINE)
	var layout: Dictionary = m._mine_layout
	_check("⑨g 입구 사다리 칸에 착지", m._player_tile() == layout["entrance"])
	_check("⑨h 카메라 층 크기로 격리",
		m._cam.limit_right == MineFloors.FLOOR_W * m.TILE and m._cam.limit_bottom == MineFloors.FLOOR_H * m.TILE)
	_check("⑨i 도달 최심층 갱신(1)", m.mine_floors.depth() == 1)
	_check("⑨j 층 안 취침 불가(집 구역 아님)", not m._can_sleep())
	m._maybe_toggle_building()
	_check("⑨k 층 안 건물 출입 없음(지상 대장간·길드 미도달)", m._indoor == "")
	# 방 바닥은 PATH(걷기 O), 방 밖은 WALL(암반), 남은 돌은 ROCK.
	var rect2: Rect2i = layout["rect"]
	_check("⑨l 방 바닥 = PATH(걷기 O)", m._grid[layout["entrance"].y][layout["entrance"].x] == m.PATH)
	_check("⑨m 방 밖 = WALL(암반)", m._grid[0][0] == m.WALL and rect2.position.x >= 1)
	var live_rocks: Array = m.mine_floors.rocks_left(m.clock.day, 1)
	var rock_tiles_ok := true
	for r: Vector2i in live_rocks:
		if m._grid[r.y][r.x] != m.ROCK:
			rock_tiles_ok = false
	_check("⑨n 남은 돌이 전부 ROCK 타일(통과 X)", rock_tiles_ok and live_rocks.size() > 0)

	# ── 곡괭이 채굴: 타수 1 · 혼력 10 · day-한정 원장 기록 · 통행 개방 ────────
	if live_rocks.size() > 0:
		var pick_idx := _slot_of(m.inventory, ItemCatalog.PICKAXE)
		m.inventory.select(pick_idx)
		_check("⑨o 곡괭이 선택", m.inventory.selected_id() == ItemCatalog.PICKAXE)
		var target: Vector2i = live_rocks[0]
		var e_before: int = m.energy.current
		var left_before: int = m.mine_floors.rocks_left_count(m.clock.day, 1)
		m._target = target
		_check("⑨p 겨눈 칸이 깰 수 있는 돌", m._is_mine_rock(target))
		m._mine_rock(target)
		_check("⑨q 1타로 깨짐(원장 기록)", m.mine_floors.is_mined(1, target))
		_check("⑨r 혼력 10 소모", m.energy.current == e_before - m.MINE_ROCK_COST)
		_check("⑨s 깬 자리 통행 개방(PATH)", m._grid[target.y][target.x] == m.PATH)
		_check("⑨t 남은 돌 −1", m.mine_floors.rocks_left_count(m.clock.day, 1) == left_before - 1)
		_check("⑨u 깬 돌은 더 이상 대상 아님", not m._is_mine_rock(target))
		# 곡괭이가 아니면 무동작(자동 분기 없음 — ADR-0024 §2).
		if live_rocks.size() > 1:
			var t2: Vector2i = live_rocks[1]
			m.inventory.select(_slot_of(m.inventory, ItemCatalog.HOE))
			var e2: int = m.energy.current
			m._mine_rock(t2)
			_check("⑨v 곡괭이 아니면 무동작(혼력·원장 불변)",
				not m.mine_floors.is_mined(1, t2) and m.energy.current == e2)
			m.inventory.select(pick_idx)

	# ── 하강(다음 층) → 복귀 ─────────────────────────────────────────────────
	m._descend_mine(2)
	await _settle(m)
	_check("⑨w 사다리로 다음 층(2층)", m._mine_floor == 2 and m.mine_floors.depth() == 2)
	_check("⑨x 2층 배치는 1층과 다르다", _sig(m._mine_layout) != _sig(layout))
	m._ascend_mine_to_surface()
	await _settle(m)
	_check("⑨y 지상 복귀(_mine_floor=0·64×44)",
		m._mine_floor == 0 and m._grid_w == 64 and m._outdoor_h == 44)
	_check("⑨z 갱도 입구 문 앞에 착지", m._player_tile() == m.MINE_SURFACE_RETURN)
	_check("⑨A 나락 진입로는 여전히 잠김(S5-T7 소관)",
		not m._buildings.has("나락 진입로") and not m._buildings.has("나락"))
	# day 리셋 훅(취침 경로) — 층 안이면 지상으로 되돌리고 기록을 비운다.
	m._descend_mine(3)
	await _settle(m)
	m.mine_floors.mark_mined(3, Vector2i(2, 2))
	m._on_day_advanced(m.clock.day + 1)
	_check("⑩g 취침 훅이 층을 리셋(지상 복귀)", m._mine_floor == 0 and m._grid_w == 64)
	_check("⑩h 취침 훅이 채굴 기록을 비움", not m.mine_floors.is_mined(3, Vector2i(2, 2)))
	await _despawn(m)

	# ── ⑪ 구세이브 하위호환: "mine"·"mine_floor" 키 없는 세이브 ──────────────
	var sm := SaveManager.new()
	sm.save_game({"region": RegionCatalog.EOPHWA_MINE, "indoor": "",
		"player_tile": RegionCatalog.spawn_of(RegionCatalog.EOPHWA_MINE)})
	sm.free()
	var m2: Node = await _spawn_main()
	_check("⑪ 구세이브 = 지상 0층", m2._mine_floor == 0)
	_check("⑪b 구세이브 = 지상 무대 64×44", m2._grid_w == 64 and m2._outdoor_h == 44)
	_check("⑪c 구세이브 = 도달 깊이 0", m2.mine_floors.depth() == 0)
	_check("⑪d 구역 복원은 종전대로", m2._region == RegionCatalog.EOPHWA_MINE)
	await _despawn(m2)

	# ── 층 세이브 왕복: 층 안에서 저장하면 그 층으로 재개 ────────────────────
	var mf_blob := MineFloors.new()
	mf_blob.advance_day(1)
	mf_blob.reach_floor(12)
	var sm2 := SaveManager.new()
	sm2.save_game({"region": RegionCatalog.EOPHWA_MINE, "indoor": "", "mine_floor": 3,
		"mine": mf_blob.to_save(),
		"player_tile": MineFloors.generate(1, 3)["entrance"]})
	sm2.free()
	var m3: Node = await _spawn_main()
	_check("⑧g 층 세이브 복원(_mine_floor=3)", m3._mine_floor == 3)
	_check("⑧h 층 그리드 복원(24×24)",
		m3._grid_w == MineFloors.FLOOR_W and m3._outdoor_h == MineFloors.FLOOR_H)
	_check("⑧i 도달 최심층 복원(12) + 엘리베이터 [5,10]",
		m3.mine_floors.depth() == 12 and str(m3.mine_floors.unlocked_elevators()) == "[5, 10]")
	m3._mine_floor = 0
	_check("⑧j 해금된 엘리베이터가 입구 선택지로", str(m3._mine_entry_options()) == "[1, 5, 10]")
	await _despawn(m3)

	# ── ⑫ 회귀 0: 깨끗한 새 게임(HOME) — 집 출입·취침 불변 ───────────────────
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m4: Node = await _spawn_main()
	_check("⑫ 시작 구역 = home(회귀)", m4._region == RegionCatalog.HOME and m4._mine_floor == 0)
	m4.player.position = m4._tile_center_px(m4.HOUSE_EXT_DOOR)
	m4._maybe_toggle_building()
	await _settle(m4)
	_check("⑫b 홈 집 진입(_indoor=집)", m4._indoor == "집")
	_check("⑫c 홈 집 안 취침 가능(회귀 0)", m4._can_sleep())
	await _despawn(m4)

	# ── 세이브 백업 복원 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
