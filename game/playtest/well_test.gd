extends SceneTree

# [B2 · 혼우물] 물뿌리개 리필 우물(Well) 그레이박스 단위검증(ephemeral 헤드리스).
#
# 무엇을 보나(혼우물 = 비진입 WALL 박스 자리만 — 여물광(SILO) "자리만" 결. 리필 메카닉은 별도 grill 후):
#   ① WELL_RECT = 전부 WALL(통과 불가 SOLID) + _buildings 카탈로그 미등록(non-enterable).
#   ② WELL_RECT = 밭·연못·본가·창고·동물 건물·여물광·방목지와 안 겹침(좌표 정합).
#   ③ flood-fill(소프트락 0) — 도착(spawn)에서 창고 문·집 문·동쪽 워프 칸이 우물을 비껴 전부 도달.
#      우물 박스 안쪽 칸은 막힘(WALL 자리)·우물 둘레는 도달(비껴감) + 접근 스퍼(39,19)=PATH.
#   ④ 우물에 닿아도 진입 안 함(_maybe_toggle_building → _indoor 불변="") — 카탈로그 미등록의 자연 표현.
#   ⑤ 회귀 0 — 스타터 밭(SOIL) 존재·홈 집 취침 가능 불변.
#
# 좀비 방지: 모든 단언 뒤 quit(). _settle 상한 폴링(무한대 X). run_tests.sh 워치독과 함께.

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

# HOME 외부(y<_outdoor_h)에서 4방향 flood-fill로 걸을 수 있는 칸 — WALL/VOID/WATER 막힘(home_expansion_test 결).
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return id != m.VOID and id != m.WATER and not m.is_solid(id)

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

func _initialize() -> void:
	print("══ 혼우물(Well) 그레이박스 검증 ══")
	const SAVE := "user://save.dat"
	# 첫 인스턴스가 옛/오염 세이브로 부팅되지 않게 spawn 전에 지운다(테스트 격리 — 세이브 무관 테스트).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()
	_check("⓪ 부팅 = 안식 농원 바깥", m._region == RegionCatalog.HOME and m._indoor == "")

	var r: Rect2i = m.WELL_RECT

	# ── ① 전부 WALL(통과 불가) + 카탈로그 미등록 ──
	var all_wall := true
	var all_solid := true
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var id: int = m._grid[y][x]
			if id != m.WALL:
				all_wall = false
			if not m.is_solid(id):
				all_solid = false
	_check("① 혼우물 footprint = 전부 WALL", all_wall)
	_check("① 혼우물 = 전부 통과 불가(is_solid)", all_solid)
	_check("① 혼우물 카탈로그 미등록(non-enterable)", not m._buildings.has("혼우물"))

	# ── ② 밭·연못·건물·목축 인프라와 안 겹침 ──
	_check("② 스타터 밭과 안 겹침", not r.intersects(m.STARTER_PATCH_RECT))
	_check("② 영혼빛 연못과 안 겹침", not r.intersects(m.SPIRIT_POND_RECT))
	_check("② 본가·창고 외관과 안 겹침",
		not r.intersects(m.HOUSE_EXT_RECT) and not r.intersects(m.STOREHOUSE_EXT_RECT))
	_check("② 동물 건물(넋우릿간·넋둥우리)과 안 겹침",
		not r.intersects(m.NEOKURITGAN_EXT_RECT) and not r.intersects(m.NEOKDUNGURI_EXT_RECT))
	_check("② 여물광·방목지·사료풀과 안 겹침",
		not r.intersects(m.SILO_EXT_RECT) and not r.intersects(m.PASTURE_SCAN_RECT) \
		and not r.intersects(m.FORAGE_SCAN_RECT))

	# ── ③ flood-fill: 도착에서 창고 문·집 문·동쪽 워프 도달(우물 비껴, 소프트락 0) ──
	var spawn: Vector2i = m.SPAWN_TILE
	_check("③pre 도착 칸이 걸을 수 있는 길", _walkable(m, spawn))
	var reach := _reachable(m, spawn)
	_check("③ 창고 외관 문 도달", reach.has(m.STOREHOUSE_EXT_DOOR))
	_check("③ 홈 집 외관 문 도달", reach.has(m.HOUSE_EXT_DOOR))
	_check("③ 동쪽 길 워프 칸(78,32) 도달", reach.has(Vector2i(78, 32)))
	# 우물 박스 안쪽 칸은 WALL이라 도달 집합에 없다(통과 불가). 둘레는 도달 가능(비껴감).
	_check("③ 우물 박스 안쪽 칸은 막힘(WALL 자리)", not reach.has(r.position + Vector2i(1, 1)))
	_check("③ 우물 둘레 도달(소프트락 0 — 서·동·남·북 인접)",
		reach.has(r.position + Vector2i(-1, 1)) and reach.has(Vector2i(r.end.x, r.position.y + 1)) \
		and reach.has(Vector2i(r.position.x + 1, r.end.y)) and reach.has(Vector2i(r.position.x + 1, r.position.y - 1)))
	# 접근 스퍼(중앙 스파인 → 우물 서면) = PATH.
	_check("③ 접근 스퍼(39,19) = PATH", m._grid[19][39] == m.PATH)

	# ── ④ 우물에 닿아도 진입 안 함(카탈로그 미등록) ──
	m.player.position = m._tile_center_px(r.position + Vector2i(-1, 1))   # 우물 서면 앞(걸을 수 있는 칸)
	m._maybe_toggle_building()
	await _settle(m)
	_check("④ 우물 닿아도 진입 안 함(_indoor 불변='')", m._indoor == "")

	# ── ⑤ 회귀 0: 스타터 밭 존재·홈 집 취침 가능 ──
	var fi: Vector2i = m.STARTER_PATCH_RECT.position + Vector2i(1, 1)
	_check("⑤ 스타터 패치(SOIL) 존재(회귀)", m._grid[fi.y][fi.x] == m.SOIL)
	m.player.position = m._tile_center_px(m.HOUSE_EXT_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("⑤ 홈 집 진입(_indoor=집)", m._indoor == "집")
	_check("⑤ 홈 집 안 취침 가능(회귀 0)", m._can_sleep())
	await _despawn(m)

	# 테스트가 만든 세이브 잔재 정리(격리).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
