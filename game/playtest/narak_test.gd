extends SceneTree
# M5.2 — 나락(독립 전투 던전 스테이지) 그레이박스 검증(ephemeral). main을 인스턴스화해 나락 구역을 빌드한 뒤
# 빈 전투장 스테이지(바위 둘레·걸을 수 있는 spawn)·건물 0·라이브 워프 0(잠긴 진입로)·회귀 0을 단언한다.
# region.gd 데이터(is_built·이웃 0)는 world_test가 본다 — 여기는 main이 그 데이터로 *나락을 어떻게 짓는지*
# (그리드 콘텐츠)와 *진입로가 잠겨 있는지*(라이브 워프 없음·헤드리스로만 빌드)를 본다.
#
# ★ 핵심 불변식:
#   ① 나락 = 실데이터 구역(is_built), size·spawn 채워짐. 그리드 크기 유지(MAP_H×MAP_W).
#   ② 깨진 봉인 고리(ROCK)가 통과 불가로 서고, spawn(32,22) 중앙은 걸을 수 있다 — flood-fill로 중앙 아레나·
#      라벨·고리 틈 너머 바깥 여백까지 한 덩어리(soft-lock 0, ★C9).
#   ③ 진입로 잠김 — 나락은 라이브 워프 없음(이웃 0), 어느 구역도 나락으로 워프하지 않는다(독립).
#   ④ 회귀 0 — 나락은 enterable 건물 0(카탈로그에 나락 구역 건물 없음), 홈 집 출입 불변.
# 실행: godot --headless --path game --script res://playtest/narak_test.gd

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

# ★C9 — 나락이 64×44라 전역 MAP_W/OUTDOOR_H가 아니라 빌드된 구역 치수(_grid_w/_outdoor_h)를 쓴다(갱도 C8 결).
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return id != m.WALL and id != m.WATER and id != m.TREE and id != m.ROCK and id != m.VOID

# spawn에서 4방향 flood-fill로 도달 가능한 외부 칸 집합(갱도 C8 결).
func _reachable(m: Node, start: Vector2i) -> Dictionary:
	var seen := {}
	var stack: Array = [start]
	seen[start] = true
	while not stack.is_empty():
		var t: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + d
			if not seen.has(n) and _walkable(m, n):
				seen[n] = true
				stack.append(n)
	return seen

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
	print("══ M5.2 나락(독립 전투 던전 스테이지) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.m5_2_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()

	# ── ① 나락 = 실데이터 구역, 그리드 빌드 ──
	_check("① 나락 실데이터(is_built)", RegionCatalog.is_built(RegionCatalog.NARAK))
	_check("①b 나락 크기 = (64,44)", RegionCatalog.size_of(RegionCatalog.NARAK) == Vector2i(64, 44))   # ★C9 코지-와이드
	_check("①c 나락 스폰 = (32,22)", RegionCatalog.spawn_of(RegionCatalog.NARAK) == Vector2i(32, 22))   # ★C9 아레나 정중앙
	# 나락 구역을 빌드(헤드리스 — 인게임 진입은 잠긴 외관이라 _region 직접 세팅으로 검증).
	m._rebuild_region(RegionCatalog.NARAK)
	_check("①d 구역 = 나락", m._region == RegionCatalog.NARAK)
	_check("①e 그리드 크기 = _grid_h×_grid_w (★C9 64×44)",
		m._grid.size() == m._grid_h and m._grid[0].size() == m._grid_w
		and m._grid_w == 64 and m._outdoor_h == 44)

	# ── ② 바위(ROCK) 군집 통과 불가 + spawn 중앙 걸을 수 있음 ──
	for r in m.NARAK_ROCK_RECTS:
		var c := Vector2i(r.position.x, r.position.y)
		_check("② 바위 군집 칸 ROCK (%d,%d)" % [c.x, c.y], m._grid[c.y][c.x] == m.ROCK)
		_check("②b 바위 칸 통과 불가", not _walkable(m, c))
	var spawn: Vector2i = RegionCatalog.spawn_of(RegionCatalog.NARAK)
	_check("②c spawn 중앙 걸을 수 있음", _walkable(m, spawn))

	# ── ②d 깨진 봉인 고리 도달성(★C9): spawn flood-fill로 중앙 아레나·라벨·고리 틈 너머 바깥 여백까지 한 덩어리 ──
	# 봉인 고리가 군데군데 끊겨(누출구) 중앙 공동과 바깥 여백이 통해야 한다(soft-lock 0). ROCK 칸은 도달 불가.
	var reach := _reachable(m, spawn)
	_check("②d 라벨 칸(32,18) 도달(중앙 아레나 개방)", reach.has(Vector2i(32, 18)))
	_check("②e 바깥 여백(3,3) 도달(고리 틈으로 통함 — 봉인 갈라짐)", reach.has(Vector2i(3, 3)))
	_check("②f 봉인 고리 ROCK 칸(10,6) 도달 불가(통과 X)", not reach.has(Vector2i(10, 6)))

	# ── ③ 진입로 잠김: 나락은 라이브 워프 0(이웃 0) + 아무도 나락으로 워프 안 함(독립) ──
	_check("③ 나락 워프 0(잠긴 진입로)", RegionCatalog.warps_of(RegionCatalog.NARAK).is_empty())
	_check("③b 나락 이웃 0(독립)", RegionCatalog.neighbors(RegionCatalog.NARAK).is_empty())
	var points_to_narak := false
	for id in RegionCatalog.ids():
		if RegionCatalog.neighbors(id).has(RegionCatalog.NARAK):
			points_to_narak = true
	_check("③c 어느 구역도 나락으로 워프 안 함(잠긴 진입로)", not points_to_narak)

	# ── ④ 회귀 0: 나락 구역 enterable 건물 0 + 홈 집 출입 불변 ──
	var narak_buildings := 0
	for id in m._buildings:
		if m._buildings[id]["region"] == RegionCatalog.NARAK:
			narak_buildings += 1
	_check("④ 나락 구역 enterable 건물 0", narak_buildings == 0)
	await _despawn(m)

	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m2: Node = await _spawn_main()
	_check("④b 시작 구역 = home(회귀)", m2._region == RegionCatalog.HOME)
	m2.player.position = m2._tile_center_px(m2.HOUSE_EXT_DOOR)
	m2._maybe_toggle_building()
	var until := Time.get_ticks_msec() + 2000
	while m2._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	_check("④c 홈 집 진입(_indoor=집)", m2._indoor == "집")
	await _despawn(m2)

	# ── 세이브 백업 복원 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
