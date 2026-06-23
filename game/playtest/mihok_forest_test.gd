extends SceneTree
# M4.2 — 미혹의 숲(특수 채집 무대 + 옥자 집) 그레이박스 검증(ephemeral). main을 인스턴스화해 미혹의 숲
# 구역을 빌드한 뒤 나무(TREE)·연못(WATER) 무대·옥자 집(잠긴 외관, 비-enterable)·동선(무 soft-lock)·
# 막다른 워프·세이브 복원·회귀 0을 단언한다. region.gd 데이터(워프 점등·dest)는 world_test가, 워프
# *동작*(저승 숲↔미혹의 숲 왕복)은 warp_test가 본다 — 여기는 main이 그 데이터로 *미혹의 숲을 어떻게
# 짓는지*(그리드 콘텐츠 + 잠긴 옥자 집)를 본다.
#
# ★ 핵심 불변식:
#   ① 나무(TREE) 군집·연못(WATER)이 통과 불가로 서고, 그 사이 빈터(GROUND)는 걸을 수 있다.
#   ② 옥자 집 = 잠긴 외관(WALL 박스 + 문 PATH 리세스), 실내 방 없음 + 카탈로그 미등록 → 진입 불가.
#   ③ 서단 spawn(2,22)에서 옥자 집 문·특수 채집지 2곳·복귀 워프 칸이 걸어서 닿는다(flood-fill 무 soft-lock). ★C7
#   ④ 옥자 집 문에 닿아도 진입 안 됨(잠김 — 축사 결, '숨겨진·게이트').
#   ⑤ 막다른 구역 — 워프는 저승 숲 복귀 하나.
#   ⑥ 세이브 라운드트립(미혹의 숲 외부) + 회귀 0(홈 집 출입 불변).
# 실행: godot --headless --path game --script res://playtest/mihok_forest_test.gd

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

# 외부에서 걸을 수 있는 칸인가(WALL·WATER·TREE·VOID·범위밖이면 X). 실내 스택(y>=outdoor_h)은 제외.
# ★C7 — 미혹의 숲이 64×44라 전역 MAP_W/OUTDOOR_H가 아니라 빌드된 구역 치수(_grid_w/_outdoor_h)를 쓴다(저승 숲 결).
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return id != m.WALL and id != m.WATER and id != m.TREE and id != m.VOID

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
	print("══ M4.2 미혹의 숲(특수 채집 무대 + 옥자 집) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.m4_2_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()

	m._rebuild_region(RegionCatalog.MIHOK_FOREST)
	_check("⓪ 구역 = 미혹의 숲", m._region == RegionCatalog.MIHOK_FOREST)
	# ★C7 — 64×44 재배치: 그리드 = _grid_h(외부44+실내띠) × _grid_w(64). 전역 MAP_*가 아니라 구역 치수.
	_check("⓪b 그리드 크기 = _grid_h×_grid_w (★C7 64×44)",
		m._grid.size() == m._grid_h and m._grid[0].size() == m._grid_w
		and m._grid_w == 64 and m._outdoor_h == 44)

	# ── ① 나무(TREE) 군집·연못(WATER) 통과 불가 + 빈터 걸을 수 있음 ──
	for r in m.MIHOK_TREE_RECTS:
		var c := Vector2i(r.position.x, r.position.y)
		_check("① 나무 군집 칸 TREE (%d,%d)" % [c.x, c.y], m._grid[c.y][c.x] == m.TREE)
		_check("①b 나무 칸 통과 불가", not _walkable(m, c))
	var pc := Vector2i(m.MIHOK_POND_RECT.position.x, m.MIHOK_POND_RECT.position.y)
	_check("①c 연못 칸 WATER (%d,%d)" % [pc.x, pc.y], m._grid[pc.y][pc.x] == m.WATER)
	_check("①d 연못 칸 통과 불가", not _walkable(m, pc))
	_check("①e 특수 채집지① 빈터 걸을 수 있음", _walkable(m, m.MIHOK_FORAGE_LABEL_TILE))
	_check("①f 특수 채집지② 빈터 걸을 수 있음", _walkable(m, m.MIHOK_FORAGE_LABEL_TILE_2))  # ★C7 채집지 2곳

	# ── ② 옥자 집 = 잠긴 외관(WALL 박스 + 문 PATH 리세스), 실내 방 없음 ──
	var ext: Rect2i = m.OKJA_HUT_EXT_RECT
	for x in range(ext.position.x, ext.end.x):
		for y in range(ext.position.y, ext.end.y):
			var t := Vector2i(x, y)
			if t == m.OKJA_HUT_DOOR:
				_check("② 옥자 집 문 = PATH 리세스", m._grid[y][x] == m.PATH)
			else:
				_check("②b 옥자 집 외관 칸 WALL (%d,%d)" % [x, y], m._grid[y][x] == m.WALL)
	_check("②c 옥자 집 카탈로그 미등록(잠김 — 진입 불가)", not m._buildings.has("옥자 집") and not m._buildings.has("옥자집"))

	# ── ③ flood-fill 무 soft-lock: spawn에서 옥자 집 문·복귀 워프 칸 도달 ──
	var spawn: Vector2i = RegionCatalog.spawn_of(RegionCatalog.MIHOK_FOREST)
	_check("③ spawn = (2,22) ★C7", spawn == Vector2i(2, 22))
	var reach := _reachable(m, spawn)
	_check("③b 옥자 집 문 도달", reach.has(m.OKJA_HUT_DOOR))
	# ★C7 — 특수 채집지 2곳도 spawn에서 도달(에워싸는 빽빽한 외곽·굽이 동선에 막히지 않음).
	_check("③b2 특수 채집지① 도달", reach.has(m.MIHOK_FORAGE_LABEL_TILE))
	_check("③b3 특수 채집지② 도달", reach.has(m.MIHOK_FORAGE_LABEL_TILE_2))
	var warps: Array = RegionCatalog.warps_of(RegionCatalog.MIHOK_FOREST)
	_check("③c 막다른 구역 — 워프 1개(저승 숲 복귀)", warps.size() == 1 and warps[0]["to"] == RegionCatalog.JEOSEUNG_FOREST)
	for w in warps:
		_check("③d 워프 발동 칸 도달 (→%s)" % w["to"], reach.has(w["at"]))
		_check("③e 워프 발동 칸이 PATH (→%s)" % w["to"], m._grid[w["at"].y][w["at"].x] == m.PATH)

	# ── ④ 옥자 집 잠김: 문에 닿아도 진입 안 됨(축사 결 — 카탈로그 미등록) ──
	m.player.position = m._tile_center_px(m.OKJA_HUT_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("④ 옥자 집 문에 닿아도 진입 안 됨(_indoor='')", m._indoor == "")
	await _despawn(m)

	# ── ⑤ 세이브 라운드트립(미혹의 숲 외부) ──
	var stand: Vector2i = Vector2i(10, 22)   # ★C7 서단 입구 가로 복도(y22) 위 걸을 수 있는 칸
	var sm := SaveManager.new()
	sm.save_game({"region": RegionCatalog.MIHOK_FOREST, "indoor": "", "player_tile": stand})
	sm.free()
	var m2: Node = await _spawn_main()
	_check("⑤ 구역 복원(미혹의 숲)", m2._region == RegionCatalog.MIHOK_FOREST)
	_check("⑤b 실내 모드 없음(바깥)", m2._indoor == "")
	_check("⑤c 위치 복원", m2._player_tile() == stand)
	_check("⑤d 카메라 외부 경계(미혹의 숲 크기)",
		m2._cam.limit_right == RegionCatalog.size_of(RegionCatalog.MIHOK_FOREST).x * m2.TILE)
	await _despawn(m2)

	# ── ⑥ 회귀 0: 홈 집 출입·취침 불변 ──
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m3: Node = await _spawn_main()
	_check("⑥ 시작 구역 = home(회귀)", m3._region == RegionCatalog.HOME)
	m3.player.position = m3._tile_center_px(m3.HOUSE_EXT_DOOR)
	m3._maybe_toggle_building()
	await _settle(m3)
	_check("⑥b 홈 집 진입(_indoor=집)", m3._indoor == "집")
	_check("⑥c 홈 집 안 취침 가능(회귀 0)", m3._can_sleep())
	await _despawn(m3)

	# ── 세이브 백업 복원 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
