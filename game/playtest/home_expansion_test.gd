extends SceneTree

# 안식 농원 확장 — 창고(enterable 빈 방) + 축사(건물 자리만) 통합 단위검증(ephemeral 헤드리스).
#
# 무엇을 보나(interior_test가 M2.2 + 창고 출입까지 보므로, 여기선 *확장 고유*를 전담한다):
#   ① 창고 카탈로그 정합(region=HOME·kind=storehouse) + 실내 방 빌드 + 집·만물상·카페 방과 안 겹침.
#   ② 창고 세이브 라운드트립 — HOME 구역 실내(창고)에서 저장 → 새 인스턴스가 그 구역·실내·위치·
#      카메라로 그대로 재개(M2.2 카탈로그 주도 복원이 HOME-구역 건물에도 적용됨을 못박는다).
#   ③ 축사 = 건물 자리만 — BARN_EXT_RECT 전 칸 WALL(문 칸만 PATH 리세스), _buildings에 "축사" 키
#      부재 → 축사 문에 닿아도 진입 안 됨(_indoor 불변, '자리만'의 자연 표현).
#   ④ flood-fill(소프트락 0) — 도착(spawn)에서 창고 문·집 문·동쪽 워프 칸이 축사를 비껴 전부 도달.
#   ⑤ 회귀 0 — 홈 집 취침 가능·밭 존재·창고 enterable 불변.
#
# 좀비 방지: 모든 단언 뒤 quit(). _settle/_spawn 상한 폴링(무한대 X). run_tests.sh 워치독과 함께.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000   # 안전 상한(좀비 방지)
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

# HOME 외부(y<OUTDOOR_H)에서 4방향 flood-fill로 걸을 수 있는 칸 — WALL/VOID 막힘.
func _walkable(m: Node, t: Vector2i) -> bool:
	# ★C2 — 구역별 외부 치수를 따른다(MAP_W/OUTDOOR_H 전역 상수 대신 _grid_w/_outdoor_h). HOME은
	#   80×65라 전역(40×24)으로 경계를 잡으면 좌상단 모서리만 탐색하게 된다(C1 치수 일반화 결).
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	# ★ADR-0035 절벽 단면(CLIFF_*)도 통과 불가(고지를 두름 — 계단 틈만 GROUND).
	return id != m.WALL and id != m.VOID and id != m.WATER \
		and id != m.CLIFF_FACE and id != m.CLIFF_CORNER_L \
		and id != m.CLIFF_CORNER_R and id != m.CLIFF_INNER

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
	print("══ 안식 농원 확장 — 창고·축사 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.home_exp_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	# 첫 인스턴스가 옛/오염 세이브로 부팅되지 않게 spawn 전에 지운다(테스트 격리).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()
	_check("⓪ 부팅 = 안식 농원 바깥", m._region == RegionCatalog.HOME and m._indoor == "")

	# ── ① 창고 카탈로그·방 빌드·안 겹침 ──
	_check("① 창고 카탈로그 등록", m._buildings.has("창고"))
	var sh: Dictionary = m._buildings["창고"]
	_check("① 창고 region=HOME·kind=storehouse", sh["region"] == RegionCatalog.HOME and sh["kind"] == "storehouse")
	var ci: Vector2i = m.STOREHOUSE_RECT.position + Vector2i(1, 1)
	_check("① 창고 실내 바닥 빌드(STOREHOUSE_RECT)", m._grid[ci.y][ci.x] == m.HOUSE)
	_check("① 창고 방 = HOME 집 방과 안 겹침(둘 다 HOME 밴드)",   # ★C2 HOME 집은 HOME_HOUSE_RECT
		not m.STOREHOUSE_RECT.intersects(m.HOME_HOUSE_RECT))

	# ── ③ 축사 = 건물 자리만(비-enterable) ──
	var barn: Rect2i = m.BARN_EXT_RECT
	var barn_door: Vector2i = m.BARN_EXT_DOOR
	var all_wall := true
	var door_is_path := false
	for y in range(barn.position.y, barn.end.y):
		for x in range(barn.position.x, barn.end.x):
			var id: int = m._grid[y][x]
			if Vector2i(x, y) == barn_door:
				door_is_path = (id == m.PATH)
			elif id != m.WALL:
				all_wall = false
	_check("③ 축사 박스 = 문 칸 외 전부 WALL", all_wall)
	_check("③ 축사 문 칸 = PATH 리세스(시각 일관)", door_is_path)
	_check("③ 축사 카탈로그 미등록(_buildings에 '축사' 없음)", not m._buildings.has("축사"))
	# 축사 문에 닿아도 진입 안 됨(자리만 — _maybe_toggle_building이 카탈로그 조회로만 진입).
	m.player.position = m._tile_center_px(barn_door)
	m._maybe_toggle_building()
	await _settle(m)
	_check("③ 축사 문 닿아도 진입 불가(_indoor 불변)", m._indoor == "")

	# ── ④ flood-fill: 도착에서 창고 문·집 문·동쪽 워프 칸 도달(축사 비껴, 소프트락 0) ──
	var spawn: Vector2i = m.SPAWN_TILE
	_check("④pre 도착 칸이 걸을 수 있는 길", _walkable(m, spawn))
	var reach := _reachable(m, spawn)
	_check("④ 창고 외관 문 도달", reach.has(m.STOREHOUSE_EXT_DOOR))
	_check("④ 홈 집 외관 문 도달", reach.has(m.HOUSE_EXT_DOOR))
	_check("④ 동쪽 길 워프 칸(78,32) 도달", reach.has(Vector2i(78, 32)))   # ★C2 80×65
	# 축사 박스 칸은 WALL이라 도달 집합에 없다(통과 불가 자리). 둘레는 도달 가능(비껴감).
	_check("④ 축사 박스 안쪽 칸은 막힘(WALL 자리)", not reach.has(barn.position + Vector2i(1, 1)))
	_check("④ 축사 비껴 아래 칸 도달(소프트락 0)", reach.has(Vector2i(barn_door.x, barn.end.y)))

	# ── ② 창고 세이브 라운드트립(HOME 구역 실내 복원) ──
	# m이 살아 있을 때 저장한다(despawn된 노드 참조 금지 — freed 접근 = SCRIPT ERROR→행).
	m.saver.save_game({"region": RegionCatalog.HOME, "indoor": "창고", "player_tile": m.STOREHOUSE_IN_TILE})
	await _despawn(m)
	var mr: Node = await _spawn_main()
	_check("② 창고 구역 복원(HOME)", mr._region == RegionCatalog.HOME)
	_check("② 창고 실내 모드 복원(창고)", mr._indoor == "창고")
	_check("② 창고 위치 복원(진입 칸)", mr._player_tile() == mr.STOREHOUSE_IN_TILE)
	_check("② 창고 카메라 격리(top=STOREHOUSE_CAM)", mr._cam.limit_top == mr.STOREHOUSE_CAM_RECT.position.y * mr.TILE)
	# 창고 안에선 취침 불가(저장고 — _zone_at 비-"집").
	mr.player.position = mr._tile_center_px(mr.STOREHOUSE_IN_TILE)
	_check("② 창고 안 취침 불가", not mr._can_sleep())
	await _despawn(mr)

	# ── ⑤ 회귀 0: 홈 집 취침·밭·창고 enterable 불변 ──
	# 깨끗한 새 게임으로(세이브 지우고) 부팅.
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m2: Node = await _spawn_main()
	# 홈 집 진입 → 취침 가능(회귀).
	m2.player.position = m2._tile_center_px(m2.HOUSE_EXT_DOOR)
	m2._maybe_toggle_building()
	await _settle(m2)
	_check("⑤ 홈 집 진입(_indoor=집)", m2._indoor == "집")
	_check("⑤ 홈 집 안 취침 가능(회귀 0)", m2._can_sleep())
	m2.player.position = m2._tile_center_px(m2.HOME_HOUSE_DOOR)   # ★C2 HOME 집 실내 문
	m2._maybe_toggle_building()
	await _settle(m2)
	_check("⑤ 홈 집 퇴장", m2._indoor == "")
	# 스타터 패치(SOIL) 존재(회귀).
	var fi: Vector2i = m2.STARTER_PATCH_RECT.position + Vector2i(1, 1)
	_check("⑤ 스타터 패치(SOIL) 존재(회귀)", m2._grid[fi.y][fi.x] == m2.SOIL)
	# 창고 enterable 불변(다시 한 번 진입).
	m2.player.position = m2._tile_center_px(m2.STOREHOUSE_EXT_DOOR)
	m2._maybe_toggle_building()
	await _settle(m2)
	_check("⑤ 창고 enterable 불변(재진입 _indoor=창고)", m2._indoor == "창고")
	await _despawn(m2)

	# ── 세이브 백업 복원 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
