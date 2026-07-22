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

# ★ [S1R-T8] 든 도구 선택(없으면 인벤 넣고 그 슬롯 선택 — 유니크 도구는 idempotent).
func _select(m: Node, id: String) -> void:
	m.inventory.add_item(id, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

# ★ [S1R-T8] 경작+파종된(물 줄 수 있는) 칸 하나 만들기.
func _plant(m: Node, t: Vector2i) -> void:
	m.farm.hoe(t)
	m.farm.plant(t, CropCatalog.HONRYEONGCHO)

# ★ [S1R-T8] 맵에서 WATER 타일 하나 찾기(유기화된 연못 포함). 없으면 (-1,-1).
func _find_water(m: Node) -> Vector2i:
	for y in range(m._grid_h):
		for x in range(m._grid_w):
			if m._grid[y][x] == m.WATER:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

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

	# ── ⑥ [S1R-T8 / ADR-0059 결정4] 물뿌리개 용량·리필(소진→차단→우물 리필→재개) ──
	_check("⑥pre 부팅 잔량 = 용량 가득(20)", m._can_water == m._CAN_CAPACITY)
	var wa := Vector2i(48, 30)   # farm._tiles 순수 좌표(지형 무관 — hoe/plant/water는 grid 안 봄)
	var wb := Vector2i(48, 31)
	_plant(m, wa); _plant(m, wb)
	_select(m, ItemCatalog.WATERING_CAN)
	# 잔량 1로 낮춰 소진 경계를 관찰(20회 반복 없이 결정적).
	m._can_water = 1
	m.energy.refill()
	m._target = wa
	m._use_tool()
	_check("⑥ 물주기 성공 시 잔량 −1(1→0)", m.farm.is_watered(wa) and m._can_water == 0)
	# 잔량 0 — 물 줄 칸이어도 물주기 차단(에너지와 독립 축).
	m.energy.refill()
	m._target = wb
	m._use_tool()
	_check("⑥ 잔량 0 — 물주기 차단(칸 안 젖음)", not m.farm.is_watered(wb))
	_check("⑥ 잔량 0 — 물주기 시도해도 혼력 무소모(독립 축)", m.energy.current == SoulEnergy.MAX)
	# 혼우물 리필: WELL_RECT 셀 = 리필 대상 → 풀충전.
	_check("⑥ 혼우물 셀 = 리필 대상(_is_refill_target)", m._is_refill_target(m.WELL_RECT.position))
	_check("⑥ 밭칸(SOIL) = 리필 대상 아님", not m._is_refill_target(m.STARTER_PATCH_RECT.position + Vector2i(1, 1)))
	m._refill_watering_can()
	_check("⑥ 혼우물 리필 → 잔량 풀충전(20)", m._can_water == m._CAN_CAPACITY)
	# 재개: 리필 후 다시 물주기 가능.
	m.energy.refill()
	m._target = wb
	m._use_tool()
	_check("⑥ 리필 후 물주기 재개(젖음·잔량 19)", m.farm.is_watered(wb) and m._can_water == m._CAN_CAPACITY - 1)
	# 이미 가득이면 리필 무동작(잔량 불변).
	m._can_water = m._CAN_CAPACITY
	m._refill_watering_can()
	_check("⑥ 이미 가득 — 리필 무동작(20 유지)", m._can_water == m._CAN_CAPACITY)

	# ── ⑦ [S1R-T8] 물타일(연못) 리필 — WATER 셀도 리필 대상 ──
	var wt := _find_water(m)
	_check("⑦ 맵에 WATER 타일 존재", wt.x >= 0)
	if wt.x >= 0:
		_check("⑦ WATER 셀 = 리필 대상(유기화된 연못 포함)", m._is_refill_target(wt))
	m._can_water = 4   # 소진 상태 가정
	m._refill_watering_can()   # 물타일 인접에서 사용했을 때의 효과(디스패치는 _is_refill_target로 라우팅)
	_check("⑦ 물타일 리필 → 풀충전(20)", m._can_water == m._CAN_CAPACITY)

	# ── ⑧ [S1R-T8] 세이브 왕복 — 잔량 보존 + 구세이브 기본값 20(하위호환) ──
	m._can_water = 7
	m._save_game()
	m._can_water = 0   # 인메모리 오염
	m._load_game()
	_check("⑧ 세이브 왕복 — 잔량 보존(7)", m._can_water == 7)
	# 구세이브(키 없음) → 로드 시 기본값 20으로 폴백.
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	raw.erase("watering_can")
	m.saver.save_game(raw, m._active_slot, {})
	m._can_water = 3   # 오염
	m._load_game()
	_check("⑧ 구세이브(키 없음) → 기본값 20(하위호환)", m._can_water == m._CAN_CAPACITY)

	await _despawn(m)

	# 테스트가 만든 세이브 잔재 정리(격리).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
