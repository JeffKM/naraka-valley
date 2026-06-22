extends SceneTree
# M2.1 — 나루 마을 허브 레이아웃 검증(ephemeral). 실제 main을 인스턴스화해 마을 구역을 빌드한 뒤
# 강+다리 동/서 분할·8개 건물 외관·동선 연결(무 soft-lock)·카페 실내 좌표 불변(회귀 0)을 단언한다.
# region.gd 데이터(워프 발동 칸)는 world_test가 보고, 여기는 main이 그 데이터로 *마을을 어떻게
# 짓는지*(그리드 콘텐츠)를 본다(building/warp_test와 같은 결의 하네스).
#
# ★ 핵심 불변식:
#   ① 강(WATER)이 x19·20 세로로 흘러 마을을 서/동으로 가른다(위 경계까지 닿아 북쪽 우회 도하 없음).
#   ② 다리(y16)가 *유일한* 도하점 — 그 외 모든 y에서 x19·20은 WATER(PATH 아님).
#   ③ 8개 외관(카페·메인집3·만물상·주민집3)이 통과 불가 WALL 박스 + 문 1칸(PATH 리세스).
#   ④ 도착(spawn)에서 모든 문·워프 발동 칸이 걸어서 닿는다(flood-fill — 그레이박스 무 soft-lock).
#   ⑤ 카페 실내(CAFE_RECT) 좌표·바닥 불변 = 카페 시뮬 회귀 0 seam.
# 실행: godot --headless --path game --script res://playtest/village_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# 외부에서 걸을 수 있는 칸인가(WALL·WATER·VOID·범위밖이면 X). 실내 스택(y>=OUTDOOR_H)은 제외.
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m.MAP_W or t.y >= m.OUTDOOR_H:
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

func _initialize() -> void:
	print("══ M2.1 나루 마을 허브 레이아웃 검증 ══")
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame

	# 마을 구역을 빌드(동기 — warp_test ⑤와 같은 결, 그리드 직접 검사).
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	_check("⓪ 구역 = 나루 마을", m._region == RegionCatalog.NARU_VILLAGE)

	# ── ① 강(WATER)이 동/서를 가른다 ──
	var rx: Array = m.RIVER_X
	_check("① 강 두 칸 폭(x19·20)", rx == [19, 20])
	for ry in [m.RIVER_Y0, 8, 12, m.RIVER_Y1]:
		for x in rx:
			_check("①b 강 칸 WATER (%d,%d)" % [x, ry], m._grid[ry][x] == m.WATER)
	# 강이 맨 위 경계 바로 아래(RIVER_Y0=1)까지 닿아 북쪽 우회 도하가 없다.
	_check("①c 강이 위 경계까지 닿음(북쪽 우회 차단)", m.RIVER_Y0 == 1)

	# ── ② 다리(y16)가 유일한 도하점 ──
	for x in rx:
		_check("② 다리 칸 PATH (%d,16)" % x, m._grid[m.BRIDGE_Y][x] == m.PATH)
	# 다리 외 모든 y에서 강 칸은 WATER(다른 도하점 없음).
	var other_crossing := false
	for y in range(m.RIVER_Y0, m.RIVER_Y1 + 1):
		if y == m.BRIDGE_Y:
			continue
		for x in rx:
			if m._grid[y][x] != m.WATER:
				other_crossing = true
	_check("②b 다리 외 강 칸은 전부 WATER(유일 도하점)", not other_crossing)

	# ── ③ 8개 건물 외관: 통과 불가 WALL 박스 + 문 1칸(PATH) ──
	var buildings: Array = [
		["카페", m.CAFE_EXT_RECT, m.CAFE_EXT_DOOR],
		["멜 집", m.MEL_HOUSE_RECT, m.MEL_HOUSE_DOOR],
		["미호 집", m.MIHO_HOUSE_RECT, m.MIHO_HOUSE_DOOR],
		["바나 집", m.BANA_HOUSE_RECT, m.BANA_HOUSE_DOOR],
		["만물상", m.STORE_EXT_RECT, m.STORE_EXT_DOOR],
	]
	for i in m.RESIDENT_HOUSE_RECTS.size():
		buildings.append(["주민집%d" % (i + 1), m.RESIDENT_HOUSE_RECTS[i], m.RESIDENT_HOUSE_DOORS[i]])
	_check("③ 야외 건물 8채(카페+메인집3+만물상+주민집3)", buildings.size() == 8)
	for b in buildings:
		var name: String = b[0]
		var rect: Rect2i = b[1]
		var door: Vector2i = b[2]
		# 외관 좌상단 코너 = WALL(통과 불가 박스).
		_check("③ %s 외관 WALL 박스" % name, m._grid[rect.position.y][rect.position.x] == m.WALL)
		# 문 1칸은 PATH 리세스(WALL 박스 안에서 유일하게 뚫림).
		_check("③ %s 문 = PATH(리세스)" % name, m._grid[door.y][door.x] == m.PATH)
		# 문은 그 건물 외관 rect 안에 있다(외관에 붙은 문).
		_check("③ %s 문이 외관 rect 안" % name, rect.has_point(door))

	# ── ④ 동선 연결(무 soft-lock): 도착에서 모든 문·워프 발동 칸이 걸어서 닿는다 ──
	var spawn: Vector2i = RegionCatalog.spawn_of(RegionCatalog.NARU_VILLAGE)
	_check("④pre 도착 칸이 걸을 수 있는 길", _walkable(m, spawn))
	var reach := _reachable(m, spawn)
	for b in buildings:
		var door: Vector2i = b[2]
		_check("④ %s 문에 도착에서 닿음" % b[0], reach.has(door))
	# 워프 발동 칸(서워프·산길·나룻터)도 도착에서 닿는다(휴면이어도 길은 닿아야 점등 시 동작).
	for w in RegionCatalog.warps_of(RegionCatalog.NARU_VILLAGE):
		var at: Vector2i = w["at"]
		_check("④ 워프 발동 칸 도달 가능 →%s %s" % [w["to"], at], reach.has(at))
	# 동편(다리 건너)도 닿는다 = 다리가 실제로 서/동을 잇는다(예: 동편 만물상 문).
	_check("④b 동편(다리 건너) 도달 — 만물상 문", reach.has(m.STORE_EXT_DOOR))

	# ── ⑤ 카페 실내(CAFE_RECT) 좌표·바닥 불변 = 카페 시뮬 회귀 0 seam ──
	# 외관은 서편으로 옮겼어도 실내 방은 VOID 스택의 같은 칸에 그대로 선다(좌표 대이동 0).
	var ci: Vector2i = m.CAFE_RECT.position + Vector2i(1, 1)   # 방 안쪽 한 칸
	_check("⑤ 카페 실내 바닥(CAFE_RECT 불변)", m._grid[ci.y][ci.x] == m.CAFE)
	_check("⑤b 실내 카페 문 불변(CAFE_DOOR)", m.CAFE_RECT.has_point(m.CAFE_DOOR))

	m.queue_free()
	await process_frame
	print(("══ 통과 ══" if _fail == 0 else "══ 실패 %d건 ══" % _fail))
	quit(_fail)
