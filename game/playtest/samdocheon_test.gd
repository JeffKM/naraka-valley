extends SceneTree
# M3.1 — 삼도천(강 낚시 무대 + 혼백관) 그레이박스 검증(ephemeral). main을 인스턴스화해 삼도천 구역을
# 빌드한 뒤 강(WATER) 무대·혼백관 외관/실내·동선(무 soft-lock)·출입 라운드트립·취침 불가·세이브
# 복원·회귀 0을 단언한다. region.gd 데이터(워프 점등·dest)는 world_test가, 워프 *동작*은 warp_test가
# 본다 — 여기는 main이 그 데이터로 *삼도천을 어떻게 짓는지*(그리드 콘텐츠 + 건물)를 본다.
#
# ★ 핵심 불변식:
#   ① 강(WATER)이 상단 가로 띠(y1~3)로 흐르고, 그 아래 둑(y4~)은 걸을 수 있는 land.
#   ② 혼백관 외관 = 통과 불가 WALL 박스 + 문 1칸(PATH 리세스), 실내는 빈 방(kind=museum).
#   ③ 남단 나룻터 spawn(20,22)에서 혼백관 문·복귀 워프·하구 워프 칸이 걸어서 닿는다(flood-fill).
#   ④ 혼백관 출입 라운드트립(진입→실내 격리→퇴장) + 취침 불가(남의 건물).
#   ⑤ 세이브 라운드트립 — 삼도천 실내(혼백관)에서 저장하면 새 인스턴스가 그 구역·실내·위치로 재개.
#   ⑥ 회귀 0 — 카탈로그에 혼백관(SAMDOCHEON·museum) 등록, 홈 집 출입 불변.
# 실행: godot --headless --path game --script res://playtest/samdocheon_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# 전환(워프/문) tween이 끝날 때까지 _transitioning 폴링(실시간 tween, 좀비 방지 상한).
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

# 외부에서 걸을 수 있는 칸인가(WALL·WATER·VOID·범위밖이면 X). 실내 스택(y>=outdoor_h)은 제외.
# ★C4 — 삼도천이 56×40이라 전역 MAP_W/OUTDOOR_H가 아니라 빌드된 구역 치수(_grid_w/_outdoor_h)를 쓴다(village_test 결).
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return id != m.WALL and id != m.WATER and id != m.VOID

# spawn에서 4방향 flood-fill로 도달 가능한 외부 칸 집합.
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
	print("══ M3.1 삼도천(강 낚시 무대 + 혼백관) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.m3_1_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	# 첫 인스턴스가 옛/오염 세이브로 부팅되지 않게 spawn 전에 지운다(테스트 격리).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()

	# 삼도천 구역을 빌드(동기 — village/warp_test와 같은 결, 그리드 직접 검사).
	m._rebuild_region(RegionCatalog.SAMDOCHEON)
	_check("⓪ 구역 = 삼도천", m._region == RegionCatalog.SAMDOCHEON)
	# ★C4 — 56×40 재배치: 그리드 = _grid_h(외부40+실내띠28=68) × _grid_w(56). 전역 MAP_*가 아니라 구역 치수.
	_check("⓪b 그리드 크기 = _grid_h×_grid_w (★C4 56×40)",
		m._grid.size() == m._grid_h and m._grid[0].size() == m._grid_w
		and m._grid_w == 56 and m._outdoor_h == 40)

	# ── ① 강(WATER) 상단 띠 + 걸을 수 있는 둑 ──
	for y in range(m.SAMDO_RIVER_Y0, m.SAMDO_RIVER_Y1 + 1):
		for x in [1, 12, 20, 38]:
			_check("① 강 칸 WATER (%d,%d)" % [x, y], m._grid[y][x] == m.WATER)
	_check("①b 강 위 경계까지 닿음(SAMDO_RIVER_Y0=1)", m.SAMDO_RIVER_Y0 == 1)
	# 둑(강 바로 아래 y4)은 걸을 수 있는 land(낚시터 — Phase 3 캐스팅 자리).
	_check("①c 둑(y4)은 걸을 수 있음(강 낚시터)", _walkable(m, Vector2i(20, m.SAMDO_RIVER_Y1 + 1)))

	# ── ② 혼백관 외관 = WALL 박스 + 문 PATH 리세스, 실내 빈 방 ──
	var ext: Rect2i = m.MUSEUM_EXT_RECT
	for x in range(ext.position.x, ext.end.x):
		for y in range(ext.position.y, ext.end.y):
			var t := Vector2i(x, y)
			if t == m.MUSEUM_EXT_DOOR:
				_check("② 혼백관 문 = PATH 리세스", m._grid[y][x] == m.PATH)
			else:
				_check("②b 혼백관 외관 칸 WALL (%d,%d)" % [x, y], m._grid[y][x] == m.WALL)
	# 실내 방 바닥(HOUSE 톤)·둘레 벽이 빌드됐다(빈 방 — 가구는 _draw museum 분기 없음).
	_check("②c 혼백관 실내 바닥 빌드(HOUSE 타일)",
		m._grid[m.MUSEUM_RECT.position.y + 1][m.MUSEUM_RECT.position.x + 1] == m.HOUSE)
	_check("②d 혼백관 실내 문 = 바닥(퇴장 통로)", m._grid[m.MUSEUM_DOOR.y][m.MUSEUM_DOOR.x] == m.HOUSE)

	# ── ③ flood-fill 무 soft-lock: spawn에서 문·두 워프 칸 도달 ──
	var spawn: Vector2i = RegionCatalog.spawn_of(RegionCatalog.SAMDOCHEON)
	_check("③ spawn = (28,38) ★C4", spawn == Vector2i(28, 38))
	var reach := _reachable(m, spawn)
	_check("③b 혼백관 외관 문 도달", reach.has(m.MUSEUM_EXT_DOOR))
	var warps: Array = RegionCatalog.warps_of(RegionCatalog.SAMDOCHEON)
	for w in warps:
		_check("③c 워프 발동 칸 도달 (→%s)" % w["to"], reach.has(w["at"]))
		_check("③d 워프 발동 칸이 PATH (→%s)" % w["to"], m._grid[w["at"].y][w["at"].x] == m.PATH)

	# ── ④ 혼백관 출입 라운드트립 + 취침 불가 ──
	m.player.position = m._tile_center_px(m.MUSEUM_EXT_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("④ 혼백관 진입(_indoor=혼백관)", m._indoor == "혼백관")
	_check("④b 플레이어가 혼백관 방 안", m.MUSEUM_RECT.has_point(m._player_tile()))
	_check("④c 카메라 혼백관 방 격리(top=MUSEUM_CAM)",
		m._cam.limit_top == m.MUSEUM_CAM_RECT.position.y * m.TILE)
	_check("④d 혼백관 안 취침 불가(남의 건물)", not m._can_sleep())
	m.player.position = m._tile_center_px(m.MUSEUM_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("④e 혼백관 퇴장(_indoor='')", m._indoor == "")
	_check("④f 혼백관 외관 문 앞으로(out_tile)", m._player_tile() == m.MUSEUM_EXT_DOOR + Vector2i(0, 1))
	var museum_in: Vector2i = m.MUSEUM_IN_TILE   # m이 free되기 전에 상수 캡처(아래 세이브 라운드트립용)
	await _despawn(m)

	# ── ⑤ 세이브 라운드트립: 삼도천 혼백관 실내에서 저장 → 새 인스턴스가 그대로 재개 ──
	var sm := SaveManager.new()
	sm.save_game({"region": RegionCatalog.SAMDOCHEON, "indoor": "혼백관", "player_tile": museum_in})
	sm.free()
	var m2: Node = await _spawn_main()
	_check("⑤ 구역 복원(삼도천)", m2._region == RegionCatalog.SAMDOCHEON)
	_check("⑤b 혼백관 실내 모드 복원", m2._indoor == "혼백관")
	_check("⑤c 위치 복원(혼백관 진입 칸)", m2._player_tile() == museum_in)
	_check("⑤d 카메라 혼백관 방 격리(top=MUSEUM_CAM)",
		m2._cam.limit_top == m2.MUSEUM_CAM_RECT.position.y * m2.TILE)
	await _despawn(m2)

	# ── ⑤e 미빌드 구역 방어는 save_region_test가 전담 — 여기선 삼도천 복원만. ──

	# ── ⑥ 회귀 0: 카탈로그 혼백관 등록 + 홈 집 출입 불변 ──
	# ⑤에서 삼도천 세이브를 남겼으니, 깨끗한 새 게임(HOME)으로 부팅되게 spawn 전에 지운다(테스트 격리).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m3: Node = await _spawn_main()
	_check("⑥ 혼백관 카탈로그 = SAMDOCHEON·museum",
		m3._buildings.has("혼백관")
		and m3._buildings["혼백관"]["region"] == RegionCatalog.SAMDOCHEON
		and m3._buildings["혼백관"]["kind"] == "museum")
	_check("⑥b 시작 구역 = home(회귀)", m3._region == RegionCatalog.HOME)
	m3.player.position = m3._tile_center_px(m3.HOUSE_EXT_DOOR)
	m3._maybe_toggle_building()
	await _settle(m3)
	_check("⑥c 홈 집 진입(_indoor=집)", m3._indoor == "집")
	_check("⑥d 홈 집 안 취침 가능(회귀 0)", m3._can_sleep())
	await _despawn(m3)

	# ── 세이브 백업 복원 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
