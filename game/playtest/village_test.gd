extends SceneTree
# M2.1 / ★[ADR-0060 결정 1 · S2-T1] — 나루 마을 허브 레이아웃 검증(ephemeral). 실제 main을 인스턴스화해
# 마을 구역을 빌드한 뒤 최남단 배후 강·북안 강둑·다리 1개소·8개 건물 외관·동선 연결(무 soft-lock)·
# 카페 실내 좌표 불변(회귀 0)·앵커 무이동을 단언한다.
# region.gd 데이터(워프 발동 칸)는 world_test가 보고, 여기는 main이 그 데이터로 *마을을 어떻게
# 짓는지*(그리드 콘텐츠)를 본다(building/warp_test와 같은 결의 하네스).
#
# ★ 옛 토폴로지(마을 내부 수직 강 RIVER_X 49·50 × y1~70 세로 절단 + 다리 BRIDGE_Y 36)는 [ADR-0044] §2
#   남향 물 토폴로지 이행으로 **폐지**됐다. 불변식 ①②를 새 배후 강 구조로 재작성한다.
#
# ★ 핵심 불변식:
#   ① 배후 강(WATER)이 최남단을 **동서로 횡단**한다 — x0..99 전 폭(동서 끝까지 = 우회 도하 없음),
#      y BACK_RIVER_Y0..BACK_RIVER_Y1(폭 ≥3행), 남단은 외부 무대 마지막 행까지(남쪽 우회 없음).
#      북안(강 최상단 바로 위) 1행은 CLIFF_BANK pseudo-Z 강둑 단차(SOLID).
#   ② 다리(BRIDGE_X, 폭 2칸)가 *유일한* 도하점 — 다리·남단 부두 외 모든 강 칸은 WATER,
#      강둑도 다리 폭만큼만 PATH로 열린다.
#   ③ ★[S2-T2] 16개 외관(카페·메인집3·만물상·**주민집11**)이 통과 불가 WALL 박스 + 문 1칸(남변 PATH
#      리세스)이고, 서로 2칸 이상 떨어지며, 메인 복도·다리 스파인·강·강둑을 안 막는다. 강변 주거는
#      강변 보조 레인(RIVERSIDE_LANE_Y)으로 다리 스파인에 붙는다.
#   ④ 도착(spawn)에서 모든 문·워프 발동 칸 + **다리 남단 부두**가 걸어서 닿고, 강 남쪽에서 닿는 칸은
#      다리·부두뿐이다(flood-fill — 무 soft-lock + 우회 불가의 실증).
#   ⑤ 카페 실내(CAFE_RECT) 좌표·바닥 불변 = 카페 시뮬 회귀 0 seam.
#   ⑥ 앵커 무이동 — 워프 3좌표·spawn·기존 건물 rect가 맵 리팩토링 전과 바이트 동일.
# 실행: godot --headless --path game --script res://playtest/village_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# 외부에서 걸을 수 있는 칸인가(SOLID·WATER·VOID·범위밖이면 X). 실내 스택(y>=외부세로)은 제외.
# ★C3 — 마을이 100×72라 전역 MAP_W/OUTDOOR_H가 아니라 빌드된 구역 치수(_grid_w/_outdoor_h)를 쓴다.
# ★[S2-T1] 강둑(CLIFF_BANK)이 도입돼 WALL 하드코딩으로는 부족하다 — 게임의 단일 진실원 is_solid()를 쓴다.
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return not m.is_solid(id) and id != m.WATER and id != m.VOID

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

# 그 칸이 다리(BRIDGE_X 열) 또는 남단 부두(BACK_RIVER_DOCK_RECT) 소속인가 = 의도된 도하 통로.
func _is_crossing(m: Node, t: Vector2i) -> bool:
	return t.x in m.BRIDGE_X or m.BACK_RIVER_DOCK_RECT.has_point(t)

func _initialize() -> void:
	print("══ M2.1 / S2-T1 나루 마을 허브 레이아웃 검증(배후 강) ══")
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame

	# 마을 구역을 빌드(동기 — warp_test ⑤와 같은 결, 그리드 직접 검사).
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	_check("⓪ 구역 = 나루 마을", m._region == RegionCatalog.NARU_VILLAGE)

	var y0: int = m.BACK_RIVER_Y0
	var y1: int = m.BACK_RIVER_Y1
	var bank_y: int = m.BACK_RIVER_BANK_Y
	var bridge: Array = m.BRIDGE_X
	var dock: Rect2i = m.BACK_RIVER_DOCK_RECT

	# ── ① 배후 강 = 최남단 동서 횡단(전 폭·폭≥3행·남단 경계까지) + 북안 강둑 단차 ──
	_check("① 강 폭 ≥3행(강으로 읽힘) — %d행" % (y1 - y0 + 1), y1 - y0 + 1 >= 3)
	_check("①b 강 남단이 외부 무대 마지막 행(남쪽 우회 없음)", y1 == m._outdoor_h - 1)
	_check("①c 강둑 1행이 강 최상단 바로 위", bank_y == y0 - 1)
	# 강이 맵 서단(x0)·동단(x99)까지 닿는다 = 동서 우회 도하 불가.
	for ex in [0, m._grid_w - 1]:
		for ey in [y0, y1]:
			_check("①d 강이 맵 가장자리까지(%d,%d) WATER" % [ex, ey], m._grid[ey][ex] == m.WATER)
	# 전 폭 전수 스캔 — 다리·부두를 제외한 모든 강 칸이 WATER인가(구멍 0).
	var river_hole := 0
	var river_water := 0
	for y in range(y0, y1 + 1):
		for x in m._grid_w:
			if _is_crossing(m, Vector2i(x, y)):
				continue
			if m._grid[y][x] == m.WATER:
				river_water += 1
			else:
				river_hole += 1
	_check("①e 강 전 폭 전수 WATER(다리·부두 제외) — 구멍 %d칸" % river_hole, river_hole == 0)
	_check("①f 강 수면 칸 수 = 전 폭×행수 − 통로", river_water > 0)
	# 북안 강둑(CLIFF_BANK, SOLID) — 다리 폭을 뺀 전 폭.
	var bank_hole := 0
	for x in m._grid_w:
		if x in bridge:
			continue
		if m._grid[bank_y][x] != m.CLIFF_BANK:
			bank_hole += 1
	_check("①g 북안 강둑 전 폭 CLIFF_BANK(다리 폭 제외) — 구멍 %d칸" % bank_hole, bank_hole == 0)
	_check("①h 강둑이 SOLID(pseudo-Z 단차 — [ADR-0044] §2)", m.is_solid(m.CLIFF_BANK))
	# 강둑 바로 위(y64)는 마을 땅 = 강가까지 걸어갈 수 있다.
	_check("①i 강둑 위 마을 땅(x10,y%d) 걷기 O" % (bank_y - 1), _walkable(m, Vector2i(10, bank_y - 1)))

	# ── ② 다리(BRIDGE_X, 폭 2칸)가 유일한 도하점 ──
	_check("② 다리 폭 2칸([ADR-0046] 문 2칸 규약과 결)", bridge.size() == 2)
	_check("②b 다리 두 열이 인접(끊긴 두 다리 아님)", int(bridge[1]) - int(bridge[0]) == 1)
	for bx in bridge:
		# 강둑 종단 + 강 종단 전 구간이 PATH.
		var span_ok := true
		for y in range(bank_y, y1 + 1):
			if m._grid[y][bx] != m.PATH:
				span_ok = false
		_check("②c 다리 열 x%d 강둑~강 종단 전부 PATH(y%d..%d)" % [bx, bank_y, y1], span_ok)
		# 복도에서 다리까지 내려오는 남향 스파인도 이어져 있다.
		var spine_ok := true
		for y in range(m.MAIN_CORRIDOR_Y, bank_y):
			if m._grid[y][bx] != m.PATH:
				spine_ok = false
		_check("②d 남향 스파인 x%d 복도(y%d)→강둑 연속 PATH" % [bx, m.MAIN_CORRIDOR_Y], spine_ok)
	# 다리 남단 부두(낚시터 스텁) 전 칸 PATH.
	var dock_ok := true
	for dy in range(dock.position.y, dock.end.y):
		for dx in range(dock.position.x, dock.end.x):
			if m._grid[dy][dx] != m.PATH:
				dock_ok = false
	_check("②e 다리 남단 부두 %s 전 칸 PATH(낚시터 스텁)" % dock, dock_ok)
	_check("②f 부두가 맵 남경계에서 막힘(마지막 행까지)", dock.end.y - 1 == y1)

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
	# ★[S2-T2 / ADR-0060 결정 2] 주민 집 3 → 11채(로스터 11인 1:1) → 야외 건물 8 → 16채.
	_check("③ 주민 집 11채(residents.md T1 로스터 1:1)", m.RESIDENT_HOUSE_RECTS.size() == 11)
	_check("③ 주민 집 문도 11개(rect과 짝)", m.RESIDENT_HOUSE_DOORS.size() == 11)
	_check("③ 야외 건물 16채(카페+메인집3+만물상+주민집11)", buildings.size() == 16)
	for b in buildings:
		var bname: String = b[0]
		var rect: Rect2i = b[1]
		var door: Vector2i = b[2]
		# 외관 좌상단 코너 = WALL(통과 불가 박스).
		_check("③ %s 외관 WALL 박스" % bname, m._grid[rect.position.y][rect.position.x] == m.WALL)
		# 문 1칸은 PATH 리세스(WALL 박스 안에서 유일하게 뚫림).
		_check("③ %s 문 = PATH(리세스)" % bname, m._grid[door.y][door.x] == m.PATH)
		# 문은 그 건물 외관 rect 안에 있다(외관에 붙은 문).
		_check("③ %s 문이 외관 rect 안" % bname, rect.has_point(door))
		# 문은 rect *남변*에 있다(남향 진입 — 기존 8채 패턴 계승).
		_check("③ %s 문이 rect 남변" % bname, door.y == rect.end.y - 1)
		# ★[S2-T1] 건물은 배후 강·강둑과 겹치지 않는다(강 y범위 침범 0).
		_check("③ %s rect가 강·강둑(y≥%d) 밖" % [bname, bank_y], rect.end.y - 1 < bank_y)
		# ★[S2-T2] 외관 몸통에 뚫린 칸은 **문 1칸뿐** — 문 스포크가 건물을 관통하면 그 칸이 PATH(걷기 O)라
		#   벽을 걸어 통과할 수 있다(옛 _carve_v 스포크의 실제 결함. _carve_door_spoke 우회로 해소).
		var holes: Array = []
		for hy in range(rect.position.y, rect.end.y):
			for hx in range(rect.position.x, rect.end.x):
				if m._grid[hy][hx] != m.WALL:
					holes.append(Vector2i(hx, hy))
		_check("③h %s 몸통 관통 0(뚫린 칸 = 문 1칸) — %s" % [bname, holes],
			holes.size() == 1 and holes[0] == door)
		# ★[S2-T2] 건물이 메인 가로 복도(y36)·다리 스파인 열(BRIDGE_X)을 막지 않는다.
		#   스파인 x52는 북단 나룻터(y1..36)+남향 다리(y36..71)라 사실상 전 높이 열이다.
		_check("③ %s rect가 메인 복도 y%d 밖" % [bname, m.MAIN_CORRIDOR_Y],
			m.MAIN_CORRIDOR_Y < rect.position.y or m.MAIN_CORRIDOR_Y > rect.end.y - 1)
		var on_spine := false
		for bx in bridge:
			if int(bx) >= rect.position.x and int(bx) <= rect.end.x - 1:
				on_spine = true
		_check("③ %s rect가 다리·나룻터 스파인 열 밖" % bname, not on_spine)
	# ★[S2-T2] 건물 간 최소 2칸 여백(통행·후속 프롭 여유) — 전 쌍 비교.
	var too_close := 0
	for i in buildings.size():
		for j in range(i + 1, buildings.size()):
			var ra: Rect2i = buildings[i][1]
			var rb: Rect2i = buildings[j][1]
			# 팽창 rect(각 변 +2)가 서로 안 닿아야 여백 ≥2.
			if ra.grow(2).intersects(rb):
				too_close += 1
				print("      · 근접: %s %s ↔ %s %s" % [buildings[i][0], ra, buildings[j][0], rb])
	_check("③b 건물 간 최소 2칸 여백 — 위반 %d쌍" % too_close, too_close == 0)
	# ★[S2-T2] 메인 가로 복도가 전 구간 살아 있다(신규 건물이 허리를 끊지 않았다).
	var corridor_break := 0
	for x in range(1, m._grid_w - 1):
		if m._grid[m.MAIN_CORRIDOR_Y][x] != m.PATH:
			corridor_break += 1
	_check("③c 메인 복도 y%d 전 구간 PATH — 끊김 %d칸" % [m.MAIN_CORRIDOR_Y, corridor_break], corridor_break == 0)
	# ★[S2-T2] 강변 보조 레인 — 강변 주거(RIVERSIDE_ZONE_Y 이상)가 있으면 레인이 깔리고 다리 스파인과 교차한다.
	var riverside: Array = []
	for i in m.RESIDENT_HOUSE_RECTS.size():
		if int(m.RESIDENT_HOUSE_RECTS[i].position.y) >= m.RIVERSIDE_ZONE_Y:
			riverside.append(i)
	_check("③d 강변 주거 존재(조닝 = 동편 + 강변 분산) — %d채" % riverside.size(), riverside.size() > 0)
	_check("③e 강변 레인 y%d가 강둑 y%d 위(물가 산책로)" % [m.RIVERSIDE_LANE_Y, bank_y], m.RIVERSIDE_LANE_Y < bank_y)
	for bx in bridge:
		_check("③f 강변 레인이 다리 스파인 x%d와 교차(PATH)" % bx, m._grid[m.RIVERSIDE_LANE_Y][bx] == m.PATH)
	for i in riverside:
		var rd: Vector2i = m.RESIDENT_HOUSE_DOORS[i]
		var lane_ok := true
		for y in range(rd.y, m.RIVERSIDE_LANE_Y + 1):
			if m._grid[y][rd.x] != m.PATH:
				lane_ok = false
		_check("③g 강변 주민집%d 문%s → 레인 연속 PATH" % [i + 1, rd], lane_ok)

	# ── ④ 동선 연결(무 soft-lock): 도착에서 모든 문·워프 발동 칸·남단 부두가 걸어서 닿는다 ──
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
	# ★[S2-T1] 마을이 통짜 = 동편 끝(만물상 문)이 다리 없이도 닿는다.
	_check("④b 동편 만물상 문 도달(마을 통짜 — 도하 불요)", reach.has(m.STORE_EXT_DOOR))
	# ★[S2-T1] 다리 남단 부두 도달(강을 실제로 건널 수 있다) — 부두 4모서리 전부.
	for corner in [dock.position, Vector2i(dock.end.x - 1, dock.position.y),
			Vector2i(dock.position.x, dock.end.y - 1), dock.end - Vector2i.ONE]:
		_check("④c 다리 남단 부두 모서리 도달 %s" % corner, reach.has(corner))
	# ★[S2-T1] 우회 불가의 실증 — 강 남쪽(y≥BACK_RIVER_Y0)에서 닿는 칸은 다리·부두뿐이다.
	var south_reached := 0
	var south_stray := 0
	for t in reach:
		var tt: Vector2i = t
		if tt.y < y0:
			continue
		south_reached += 1
		if not _is_crossing(m, tt):
			south_stray += 1
	_check("④d 강 남쪽 도달 칸이 전부 다리·부두(우회 도하 0) — 이탈 %d칸" % south_stray, south_stray == 0)
	_check("④e 강 남쪽에 실제로 도달함(막다른 부두 살아 있음) — %d칸" % south_reached, south_reached > 0)
	# 강둑(SOLID)은 다리 열 말고는 못 넘는다.
	_check("④f 강둑 비-다리 칸은 도달 불가(x10,y%d)" % bank_y, not reach.has(Vector2i(10, bank_y)))

	# ── ⑤ 카페 실내(CAFE_RECT) 좌표·바닥 불변 = 카페 시뮬 회귀 0 seam ──
	# 외관은 서편으로 옮겼어도 실내 방은 VOID 스택의 같은 칸에 그대로 선다(좌표 대이동 0).
	var ci: Vector2i = m.CAFE_RECT.position + Vector2i(1, 1)   # 방 안쪽 한 칸
	_check("⑤ 카페 실내 바닥(CAFE_RECT 불변)", m._grid[ci.y][ci.x] == m.CAFE)
	_check("⑤b 실내 카페 문 불변(CAFE_DOOR)", m.CAFE_RECT.has_point(m.CAFE_DOOR))

	# ── ⑥ 앵커 무이동(맵 리팩토링 전 좌표와 바이트 동일 — [ADR-0060] 결정 1 "앵커 보존") ──
	_check("⑥ spawn (3,36) 불변", spawn == Vector2i(3, 36))
	var warp_at := {}
	for w in RegionCatalog.warps_of(RegionCatalog.NARU_VILLAGE):
		warp_at[w["to"]] = w["at"]
	_check("⑥b 워프 HOME at (1,36) 불변", warp_at.get(RegionCatalog.HOME) == Vector2i(1, 36))
	_check("⑥c 워프 어푸광산 at (98,18) 불변", warp_at.get(RegionCatalog.EOPHWA_MINE) == Vector2i(98, 18))
	# ★[ADR-0061 결정 1 / S3-T1 종형 남향 이행] — 삼도천 워프는 북단 나룻터(52,1)에서 **다리 남단**
	#   (52·53,71 = 남단 부두 마지막 행, 다리 폭 2칸)으로 내려왔다. ADR-0060 결정 1의 "북단 앵커 보존"은
	#   Slice 2 스코프 한정이었고 ADR-0044 종형 축이 상위다. 나머지 앵커(서워프·산길·spawn)는 불변.
	var samdo_ats: Array = []
	for w in RegionCatalog.warps_of(RegionCatalog.NARU_VILLAGE):
		if w["to"] == RegionCatalog.SAMDOCHEON:
			samdo_ats.append(w["at"])
	_check("⑥d 워프 삼도천 at = 다리 남단 2칸 (52,71)·(53,71) ★[S3-T1]",
		samdo_ats == [Vector2i(52, 71), Vector2i(53, 71)])
	for sa in samdo_ats:
		_check("⑥d2 삼도천 워프 칸 %s이 남단 부두 안(다리로만 닿는 나룻터)" % sa, dock.has_point(sa))
	_check("⑥d3 북단 세로 스파인 길은 유지(마을 형태 불변)",
		m._grid[1][int(m.BRIDGE_X[0])] == m.PATH)
	_check("⑥e 카페 외관 rect 불변", m.CAFE_EXT_RECT == Rect2i(5, 25, 8, 7))
	_check("⑥f 멜 집 rect 불변", m.MEL_HOUSE_RECT == Rect2i(20, 14, 5, 5))
	_check("⑥g 미호 집 rect 불변", m.MIHO_HOUSE_RECT == Rect2i(5, 44, 4, 4))
	_check("⑥h 바나 집 rect 불변", m.BANA_HOUSE_RECT == Rect2i(30, 44, 4, 4))
	_check("⑥i 만물상 rect 불변", m.STORE_EXT_RECT == Rect2i(58, 14, 6, 5))
	# ★[S2-T2] 3→11채 확장에도 **기존 3채는 앵커**라 앞 3칸이 바이트 불변이어야 한다(신규는 뒤에 append).
	_check("⑥j 주민집 앵커 3채 rect 불변(선두 3칸)", m.RESIDENT_HOUSE_RECTS.slice(0, 3) == [
		Rect2i(80, 14, 5, 4), Rect2i(58, 44, 4, 4), Rect2i(82, 44, 4, 4)])
	_check("⑥j2 주민집 앵커 3채 문 불변(선두 3칸)", m.RESIDENT_HOUSE_DOORS.slice(0, 3) == [
		Vector2i(82, 17), Vector2i(59, 47), Vector2i(83, 47)])
	_check("⑥k 메인 가로 복도 y36 불변(옛 BRIDGE_Y 자리)", m.MAIN_CORRIDOR_Y == 36)

	m.queue_free()
	await process_frame
	print(("══ 통과 ══" if _fail == 0 else "══ 실패 %d건 ══" % _fail))
	quit(_fail)
