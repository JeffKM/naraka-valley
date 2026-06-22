extends SceneTree
# M4.1 — 저승 숲(채집 무대 + 목공방) 그레이박스 검증(ephemeral). main을 인스턴스화해 저승 숲 구역을
# 빌드한 뒤 나무(TREE) 무대·목공방 외관/실내·동선(무 soft-lock)·출입 라운드트립·취침 불가·세이브
# 복원·회귀 0을 단언한다. region.gd 데이터(워프 점등·dest·임시 우회)는 world_test가, 워프 *동작*은
# warp_test가 본다 — 여기는 main이 그 데이터로 *저승 숲을 어떻게 짓는지*(그리드 콘텐츠 + 건물)를 본다.
#
# ★ 핵심 불변식:
#   ① 나무(TREE) 군집(FOREST_TREE_RECTS)이 통과 불가로 서고, 그 사이 빈터(GROUND)는 걸을 수 있다.
#   ② 목공방 외관 = 통과 불가 WALL 박스 + 문 1칸(PATH 리세스), 실내는 빈 방(kind=woodshop).
#   ③ 남단 spawn(20,22)에서 목공방 문·두 워프 칸(동 미혹·남 갱도)이 걸어서 닿는다(flood-fill). ★M5.1: 임시 우회(서) 제거.
#   ④ 목공방 출입 라운드트립(진입→실내 격리→퇴장) + 취침 불가(남의 건물).
#   ⑤ 세이브 라운드트립 — 저승 숲 실내(목공방)에서 저장하면 새 인스턴스가 그 구역·실내·위치로 재개.
#   ⑥ 회귀 0 — 카탈로그에 목공방(JEOSEUNG_FOREST·woodshop) 등록, 홈 집 출입 불변.
# 실행: godot --headless --path game --script res://playtest/jeoseung_forest_test.gd

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

# 외부에서 걸을 수 있는 칸인가(WALL·WATER·TREE·VOID·범위밖이면 X). 실내 스택(y>=OUTDOOR_H)은 제외.
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m.MAP_W or t.y >= m.OUTDOOR_H:
		return false
	var id: int = m._grid[t.y][t.x]
	return id != m.WALL and id != m.WATER and id != m.TREE and id != m.VOID

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
	print("══ M4.1 저승 숲(채집 무대 + 목공방) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.m4_1_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	# 첫 인스턴스가 옛/오염 세이브로 부팅되지 않게 spawn 전에 지운다(테스트 격리).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()

	# 저승 숲 구역을 빌드(동기 — samdocheon/warp_test와 같은 결, 그리드 직접 검사).
	m._rebuild_region(RegionCatalog.JEOSEUNG_FOREST)
	_check("⓪ 구역 = 저승 숲", m._region == RegionCatalog.JEOSEUNG_FOREST)
	_check("⓪b 그리드 크기 유지(MAP_H×MAP_W)",
		m._grid.size() == m.MAP_H and m._grid[0].size() == m.MAP_W)

	# ── ① 나무(TREE) 군집 통과 불가 + 빈터(GROUND) 걸을 수 있음 ──
	for r in m.FOREST_TREE_RECTS:
		var c := Vector2i(r.position.x, r.position.y)   # 군집 좌상단 — 나무여야(동선이 안 덮은 칸)
		_check("① 나무 군집 칸 TREE (%d,%d)" % [c.x, c.y], m._grid[c.y][c.x] == m.TREE)
		_check("①b 나무 칸 통과 불가", not _walkable(m, c))
	# 빈터(채집지 라벨 자리)는 걸을 수 있는 GROUND.
	_check("①c 채집지 빈터 걸을 수 있음", _walkable(m, m.FOREST_FORAGE_LABEL_TILE))

	# ── ② 목공방 외관 = WALL 박스 + 문 PATH 리세스, 실내 빈 방 ──
	var ext: Rect2i = m.WOODSHOP_EXT_RECT
	for x in range(ext.position.x, ext.end.x):
		for y in range(ext.position.y, ext.end.y):
			var t := Vector2i(x, y)
			if t == m.WOODSHOP_EXT_DOOR:
				_check("② 목공방 문 = PATH 리세스", m._grid[y][x] == m.PATH)
			else:
				_check("②b 목공방 외관 칸 WALL (%d,%d)" % [x, y], m._grid[y][x] == m.WALL)
	_check("②c 목공방 실내 바닥 빌드(HOUSE 타일)",
		m._grid[m.WOODSHOP_RECT.position.y + 1][m.WOODSHOP_RECT.position.x + 1] == m.HOUSE)
	_check("②d 목공방 실내 문 = 바닥(퇴장 통로)", m._grid[m.WOODSHOP_DOOR.y][m.WOODSHOP_DOOR.x] == m.HOUSE)

	# ── ③ flood-fill 무 soft-lock: spawn에서 목공방 문·세 워프 칸 도달 ──
	var spawn: Vector2i = RegionCatalog.spawn_of(RegionCatalog.JEOSEUNG_FOREST)
	_check("③ spawn = (20,22)", spawn == Vector2i(20, 22))
	var reach := _reachable(m, spawn)
	_check("③b 목공방 외관 문 도달", reach.has(m.WOODSHOP_EXT_DOOR))
	var warps: Array = RegionCatalog.warps_of(RegionCatalog.JEOSEUNG_FOREST)
	_check("③c 워프 2개(갱도·미혹 — ★M5.1 나루 마을 임시 우회 제거)", warps.size() == 2)
	for w in warps:
		_check("③d 워프 발동 칸 도달 (→%s)" % w["to"], reach.has(w["at"]))
		_check("③e 워프 발동 칸이 PATH (→%s)" % w["to"], m._grid[w["at"].y][w["at"].x] == m.PATH)

	# ── ④ 목공방 출입 라운드트립 + 취침 불가 ──
	m.player.position = m._tile_center_px(m.WOODSHOP_EXT_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("④ 목공방 진입(_indoor=목공방)", m._indoor == "목공방")
	_check("④b 플레이어가 목공방 방 안", m.WOODSHOP_RECT.has_point(m._player_tile()))
	_check("④c 카메라 목공방 방 격리(top=WOODSHOP_CAM)",
		m._cam.limit_top == m.WOODSHOP_CAM_RECT.position.y * m.TILE)
	_check("④d 목공방 안 취침 불가(남의 건물)", not m._can_sleep())
	m.player.position = m._tile_center_px(m.WOODSHOP_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("④e 목공방 퇴장(_indoor='')", m._indoor == "")
	_check("④f 목공방 외관 문 앞으로(out_tile)", m._player_tile() == m.WOODSHOP_EXT_DOOR + Vector2i(0, 1))
	var shop_in: Vector2i = m.WOODSHOP_IN_TILE   # m이 free되기 전에 상수 캡처(세이브 라운드트립용)
	await _despawn(m)

	# ── ⑤ 세이브 라운드트립: 저승 숲 목공방 실내에서 저장 → 새 인스턴스가 그대로 재개 ──
	var sm := SaveManager.new()
	sm.save_game({"region": RegionCatalog.JEOSEUNG_FOREST, "indoor": "목공방", "player_tile": shop_in})
	sm.free()
	var m2: Node = await _spawn_main()
	_check("⑤ 구역 복원(저승 숲)", m2._region == RegionCatalog.JEOSEUNG_FOREST)
	_check("⑤b 목공방 실내 모드 복원", m2._indoor == "목공방")
	_check("⑤c 위치 복원(목공방 진입 칸)", m2._player_tile() == shop_in)
	_check("⑤d 카메라 목공방 방 격리(top=WOODSHOP_CAM)",
		m2._cam.limit_top == m2.WOODSHOP_CAM_RECT.position.y * m2.TILE)
	await _despawn(m2)

	# ── ⑥ 회귀 0: 카탈로그 목공방 등록 + 홈 집 출입 불변 ──
	# ⑤에서 저승 숲 세이브를 남겼으니, 깨끗한 새 게임(HOME)으로 부팅되게 spawn 전에 지운다(테스트 격리).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m3: Node = await _spawn_main()
	_check("⑥ 목공방 카탈로그 = JEOSEUNG_FOREST·woodshop",
		m3._buildings.has("목공방")
		and m3._buildings["목공방"]["region"] == RegionCatalog.JEOSEUNG_FOREST
		and m3._buildings["목공방"]["kind"] == "woodshop")
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
