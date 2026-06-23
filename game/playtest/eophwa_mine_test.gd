extends SceneTree
# M5.1 — 업화 갱도(채광/전투 무대 + 대장간·길드) 그레이박스 검증(ephemeral). main을 인스턴스화해 업화 갱도
# 구역을 빌드한 뒤 바위(ROCK)·호수(WATER) 무대·대장간/길드 외관·실내·잠긴 게이트 둘·동선(무 soft-lock)·
# 출입 라운드트립·취침 불가·세이브 복원·회귀 0을 단언한다. region.gd 데이터(토폴로지 복원·dest)는 world_test가,
# 워프 *동작*(산길·숲길 왕복)은 warp_test가 본다 — 여기는 main이 그 데이터로 *갱도를 어떻게 짓는지*
# (그리드 콘텐츠 + 두 enterable 건물 + 두 잠긴 외관)를 본다.
#
# ★ 핵심 불변식:
#   ① 바위(ROCK) 군집·호수(WATER)가 통과 불가로 서고, 그 사이 빈터(GROUND)는 걸을 수 있다.
#   ② 대장간·길드 외관 = 통과 불가 WALL 박스 + 문 1칸(PATH 리세스), 실내는 빈 방(kind=smithy/guild).
#   ③ 던전 입구·나락 진입로 = 잠긴 외관(WALL 박스 + 문 PATH 리세스), 카탈로그 미등록 → 진입 불가.
#   ④ 남단 spawn(14,42)에서 대장간/길드 문·두 워프 칸(산길·숲길)이 걸어서 닿는다(flood-fill 무 soft-lock, ★C8).
#   ⑤ 대장간·길드 출입 라운드트립(진입→실내 격리→퇴장) + 취침 불가(남의 건물) + 두 게이트 진입 안 됨(잠김).
#   ⑥ 세이브 라운드트립 — 갱도 실내(대장간)에서 저장하면 새 인스턴스가 그 구역·실내·위치로 재개.
#   ⑦ 회귀 0 — 카탈로그에 대장간·길드(EOPHWA_MINE·smithy/guild) 등록, 홈 집 출입 불변.
# 실행: godot --headless --path game --script res://playtest/eophwa_mine_test.gd

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

# 외부에서 걸을 수 있는 칸인가(WALL·WATER·TREE·ROCK·VOID·범위밖이면 X). 실내 스택(y>=_outdoor_h)은 제외.
# ★C8 — 업화 갱도가 64×44라 전역 MAP_W/OUTDOOR_H가 아니라 빌드된 구역 치수(_grid_w/_outdoor_h)를 쓴다(저승/미혹 결).
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return id != m.WALL and id != m.WATER and id != m.TREE and id != m.ROCK and id != m.VOID

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

# 외관 박스가 WALL이고 문만 PATH 리세스인지(잠긴 게이트·enterable 외관 공용 검사).
func _check_facade(m: Node, ext: Rect2i, door: Vector2i, name: String) -> void:
	for x in range(ext.position.x, ext.end.x):
		for y in range(ext.position.y, ext.end.y):
			var t := Vector2i(x, y)
			if t == door:
				_check("%s 문 = PATH 리세스" % name, m._grid[y][x] == m.PATH)
			else:
				_check("%s 외관 칸 WALL (%d,%d)" % [name, x, y], m._grid[y][x] == m.WALL)

func _initialize() -> void:
	print("══ M5.1 업화 갱도(채광/전투 무대 + 대장간·길드) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.m5_1_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	# 첫 인스턴스가 옛/오염 세이브로 부팅되지 않게 spawn 전에 지운다(테스트 격리).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()

	# 업화 갱도 구역을 빌드(동기 — samdocheon/warp_test와 같은 결, 그리드 직접 검사).
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	_check("⓪ 구역 = 업화 갱도", m._region == RegionCatalog.EOPHWA_MINE)
	_check("⓪b 그리드 크기 = _grid_h×_grid_w (★C8 64×44)",
		m._grid.size() == m._grid_h and m._grid[0].size() == m._grid_w
		and m._grid_w == 64 and m._outdoor_h == 44)

	# ── ① 바위(ROCK) 군집·호수(WATER) 통과 불가 + 빈터(GROUND) 걸을 수 있음 ──
	for r in m.MINE_ROCK_RECTS:
		var c := Vector2i(r.position.x, r.position.y)   # 군집 좌상단 — 바위여야(동선이 안 덮은 칸)
		_check("① 바위 군집 칸 ROCK (%d,%d)" % [c.x, c.y], m._grid[c.y][c.x] == m.ROCK)
		_check("①b 바위 칸 통과 불가", not _walkable(m, c))
	var lake := Vector2i(m.MINE_LAKE_RECT.position.x, m.MINE_LAKE_RECT.position.y)
	_check("①c 호수 칸 WATER 통과 불가", m._grid[lake.y][lake.x] == m.WATER and not _walkable(m, lake))
	# 빈터(채광지 라벨 자리 3곳)는 걸을 수 있는 GROUND. ★C8 — 채광 본진이라 라벨 3(숲 채집보다 촘촘).
	for ore in m.MINE_ORE_LABEL_TILES:
		_check("①d 채광지 빈터 걸을 수 있음 (%d,%d)" % [ore.x, ore.y], _walkable(m, ore))

	# ── ② 대장간·길드 외관 = WALL 박스 + 문 PATH 리세스, 실내 빈 방 ──
	_check_facade(m, m.SMITHY_EXT_RECT, m.SMITHY_EXT_DOOR, "② 대장간")
	_check_facade(m, m.GUILD_EXT_RECT, m.GUILD_EXT_DOOR, "② 길드")
	_check("②c 대장간 실내 바닥 빌드(HOUSE 타일)",
		m._grid[m.SMITHY_RECT.position.y + 1][m.SMITHY_RECT.position.x + 1] == m.HOUSE)
	_check("②d 대장간 실내 문 = 바닥(퇴장 통로)", m._grid[m.SMITHY_DOOR.y][m.SMITHY_DOOR.x] == m.HOUSE)
	_check("②e 길드 실내 바닥 빌드(CAFE 타일)",
		m._grid[m.GUILD_RECT.position.y + 1][m.GUILD_RECT.position.x + 1] == m.CAFE)
	_check("②f 길드 실내 문 = 바닥(퇴장 통로)", m._grid[m.GUILD_DOOR.y][m.GUILD_DOOR.x] == m.CAFE)

	# ── ③ 던전 입구·나락 진입로 = 잠긴 외관(WALL 박스 + 문 리세스), 카탈로그 미등록 ──
	_check_facade(m, m.DUNGEON_GATE_EXT_RECT, m.DUNGEON_GATE_DOOR, "③ 던전 입구")
	_check_facade(m, m.NARAK_GATE_EXT_RECT, m.NARAK_GATE_DOOR, "③ 나락 진입로")
	_check("③c 던전 입구·나락 진입로 카탈로그 미등록(잠김 — 진입 불가)",
		not m._buildings.has("던전 입구") and not m._buildings.has("나락 진입로") and not m._buildings.has("나락"))

	# ── ④ flood-fill 무 soft-lock: spawn에서 대장간/길드 문·두 워프 칸 도달 ──
	var spawn: Vector2i = RegionCatalog.spawn_of(RegionCatalog.EOPHWA_MINE)
	_check("④ spawn = (14,42) ★C8", spawn == Vector2i(14, 42))
	var reach := _reachable(m, spawn)
	_check("④b 대장간 외관 문 도달", reach.has(m.SMITHY_EXT_DOOR))
	_check("④c 길드 외관 문 도달", reach.has(m.GUILD_EXT_DOOR))
	var warps: Array = RegionCatalog.warps_of(RegionCatalog.EOPHWA_MINE)
	_check("④d 워프 2개(나루 마을·저승 숲)", warps.size() == 2)
	for w in warps:
		_check("④e 워프 발동 칸 도달 (→%s)" % w["to"], reach.has(w["at"]))
		_check("④f 워프 발동 칸이 PATH (→%s)" % w["to"], m._grid[w["at"].y][w["at"].x] == m.PATH)

	# ── ⑤ 대장간·길드 출입 라운드트립 + 취침 불가 + 두 게이트 진입 안 됨(잠김) ──
	m.player.position = m._tile_center_px(m.SMITHY_EXT_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("⑤ 대장간 진입(_indoor=대장간)", m._indoor == "대장간")
	_check("⑤b 플레이어가 대장간 방 안", m.SMITHY_RECT.has_point(m._player_tile()))
	_check("⑤c 카메라 대장간 방 격리(top=SMITHY_CAM)",
		m._cam.limit_top == m.SMITHY_CAM_RECT.position.y * m.TILE)
	_check("⑤d 대장간 안 취침 불가(남의 건물)", not m._can_sleep())
	m.player.position = m._tile_center_px(m.SMITHY_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("⑤e 대장간 퇴장(_indoor='')", m._indoor == "")
	_check("⑤f 대장간 외관 문 앞으로(out_tile)", m._player_tile() == m.SMITHY_EXT_DOOR + Vector2i(0, 1))
	# 길드 출입 라운드트립.
	m.player.position = m._tile_center_px(m.GUILD_EXT_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("⑤g 길드 진입(_indoor=길드)", m._indoor == "길드")
	_check("⑤h 카메라 길드 방 격리(top=GUILD_CAM)",
		m._cam.limit_top == m.GUILD_CAM_RECT.position.y * m.TILE)
	m.player.position = m._tile_center_px(m.GUILD_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("⑤i 길드 퇴장(_indoor='')", m._indoor == "")
	# 두 잠긴 게이트: 문에 닿아도 진입 안 됨(축사·옥자 집 결 — 카탈로그 미등록).
	m.player.position = m._tile_center_px(m.DUNGEON_GATE_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("⑤j 던전 입구 문에 닿아도 진입 안 됨(_indoor='')", m._indoor == "")
	m.player.position = m._tile_center_px(m.NARAK_GATE_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("⑤k 나락 진입로 문에 닿아도 진입 안 됨(_indoor='')", m._indoor == "")
	var smithy_in: Vector2i = m.SMITHY_IN_TILE   # m이 free되기 전에 상수 캡처(세이브 라운드트립용)
	await _despawn(m)

	# ── ⑥ 세이브 라운드트립: 갱도 대장간 실내에서 저장 → 새 인스턴스가 그대로 재개 ──
	var sm := SaveManager.new()
	sm.save_game({"region": RegionCatalog.EOPHWA_MINE, "indoor": "대장간", "player_tile": smithy_in})
	sm.free()
	var m2: Node = await _spawn_main()
	_check("⑥ 구역 복원(업화 갱도)", m2._region == RegionCatalog.EOPHWA_MINE)
	_check("⑥b 대장간 실내 모드 복원", m2._indoor == "대장간")
	_check("⑥c 위치 복원(대장간 진입 칸)", m2._player_tile() == smithy_in)
	_check("⑥d 카메라 대장간 방 격리(top=SMITHY_CAM)",
		m2._cam.limit_top == m2.SMITHY_CAM_RECT.position.y * m2.TILE)
	await _despawn(m2)

	# ── ⑦ 회귀 0: 카탈로그 대장간·길드 등록 + 홈 집 출입 불변 ──
	# ⑥에서 갱도 세이브를 남겼으니, 깨끗한 새 게임(HOME)으로 부팅되게 spawn 전에 지운다(테스트 격리).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m3: Node = await _spawn_main()
	_check("⑦ 대장간 카탈로그 = EOPHWA_MINE·smithy",
		m3._buildings.has("대장간")
		and m3._buildings["대장간"]["region"] == RegionCatalog.EOPHWA_MINE
		and m3._buildings["대장간"]["kind"] == "smithy")
	_check("⑦b 길드 카탈로그 = EOPHWA_MINE·guild",
		m3._buildings.has("길드")
		and m3._buildings["길드"]["region"] == RegionCatalog.EOPHWA_MINE
		and m3._buildings["길드"]["kind"] == "guild")
	_check("⑦c 시작 구역 = home(회귀)", m3._region == RegionCatalog.HOME)
	m3.player.position = m3._tile_center_px(m3.HOUSE_EXT_DOOR)
	m3._maybe_toggle_building()
	await _settle(m3)
	_check("⑦d 홈 집 진입(_indoor=집)", m3._indoor == "집")
	_check("⑦e 홈 집 안 취침 가능(회귀 0)", m3._can_sleep())
	await _despawn(m3)

	# ── 세이브 백업 복원 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
