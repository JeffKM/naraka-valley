extends SceneTree
# M3.2 — 황천해(바다 낚시 무대 + 생선가게) 그레이박스 검증(ephemeral). main을 인스턴스화해 황천해 구역을
# 빌드한 뒤 바다(WATER) 무대·부두(잔교)·생선가게 외관/실내·동선(무 soft-lock)·출입 라운드트립·취침 불가·
# 세이브 복원·막다른 구역(워프 1개)·회귀 0을 단언한다. region.gd 데이터·워프 동작은 world/warp_test가
# 본다 — 여기는 main이 그 데이터로 *황천해를 어떻게 짓는지*(그리드 콘텐츠 + 건물)를 본다.
#
# ★ 핵심 불변식(★[ADR-0061 결정 1 · S3-T1] 64×44 종형 남향 재배치 — 북에서 들어와 남쪽 바다로):
#   ① 남부(y≥SEA_Y0)가 **전 폭** 바다다(ㄴ자 만 폐지 — 옛 동측 띠 SEA_X0 소멸).
#   ①b 고지(북)↔백사장(남) 사이에 **수평 절벽 런**(Lip/Face/Base 3행)이 가로지르고, 계단 노치 1곳만 관통.
#   ② 부두(PIER_X) = 남부 바다 위에 PATH로 덮인 잔교(걸을 수 있음), 그 끝이 바다 낚시터.
#   ③ 생선가게 외관 = WALL 박스 + 문 PATH 리세스, 실내는 빈 방(kind=fishshop).
#      실내 rect·문·카메라는 **무변경**(혼백관 보존 원칙 동형) — 외관만 백사장 밴드로 이동.
#   ④ 북단 spawn(28,2)에서 생선가게 문·부두 끝·복귀 워프가 걸어서 닿는다(flood-fill·노치 통과).
#   ⑤ 생선가게 출입 라운드트립 + 취침 불가 + 세이브 라운드트립.
#   ⑥ 막다른 구역(워프 1개 — 삼도천 복귀) + 회귀 0(카탈로그 생선가게·홈 집 출입 불변).
# 실행: godot --headless --path game --script res://playtest/hwangcheonhae_test.gd

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

# 외부에서 걸을 수 있는 칸인가(SOLID·WATER·VOID·범위밖이면 X). 실내 스택(y>=outdoor_h)은 제외.
# ★C5 — 황천해가 64×44라 전역 MAP_W/OUTDOOR_H가 아니라 빌드된 구역 치수(_grid_w/_outdoor_h)를 쓴다(삼도천 결).
# ★[S3-T1] 절벽 런(CLIFF_FACE/BASE)·수풀(TREE)이 도입돼 WALL 하드코딩으로는 부족하다 — is_solid()를 쓴다.
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return not m.is_solid(id) and id != m.WATER and id != m.VOID

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
	print("══ M3.2 황천해(바다 낚시 무대 + 생선가게) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.m3_2_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()

	m._rebuild_region(RegionCatalog.HWANGCHEONHAE)
	_check("⓪ 구역 = 황천해", m._region == RegionCatalog.HWANGCHEONHAE)
	# ★C5 — 64×44 재배치: 그리드 = _grid_h(외부44+실내띠28=72) × _grid_w(64). 전역 MAP_*가 아니라 구역 치수.
	_check("⓪b 그리드 크기 = _grid_h×_grid_w (★C5 64×44)",
		m._grid.size() == m._grid_h and m._grid[0].size() == m._grid_w
		and m._grid_w == 64 and m._outdoor_h == 44)

	# ── ① 남부 바다 = 전 폭(ㄴ자 만 폐지) + 수평 절벽 런 + 걸을 수 있는 백사장 ──
	var px: int = m.PIER_X
	var sea_y0: int = m.SEA_Y0
	var cliff_y: int = m.HWANG_CLIFF_Y
	# 전 폭 전수 스캔 — 부두 열을 뺀 남부 모든 칸이 WATER인가(맵 가장자리 x0·x끝 포함 = 육로 우회 0).
	var sea_hole := 0
	for y in range(sea_y0, m._outdoor_h):
		for x in m._grid_w:
			if x == px:
				continue
			if m._grid[y][x] != m.WATER:
				sea_hole += 1
	_check("① 남부(y≥%d)가 전 폭 바다(부두 열 제외) — 구멍 %d칸" % [sea_y0, sea_hole], sea_hole == 0)
	_check("①b 바다가 남부 절반 이하에서 시작(북=육지 밴드)", sea_y0 > m._outdoor_h / 2)
	# 수평 절벽 런 = 고지↔백사장 전이(Lip 걷기 O / Face·Base SOLID). 계단 노치 열만 뚫려 있다.
	var gx: int = m.HWANG_CLIFF_GATE_X
	var gw: int = m.HWANG_CLIFF_GATE_W
	var face_hole := 0
	for x in m._grid_w:
		if x >= gx and x < gx + gw:
			continue
		if not m.is_solid(m._grid[cliff_y + 1][x]) or not m.is_solid(m._grid[cliff_y + 2][x]):
			face_hole += 1
	_check("①c 절벽 런 Face·Base 행이 전 폭 SOLID(노치 제외) — 구멍 %d칸" % face_hole, face_hole == 0)
	_check("①d 절벽 Lip 행은 걷기 O(고지 밑단 하이라이트)", not m.is_solid(m.CLIFF_LIP))
	for gy in range(cliff_y, cliff_y + 3):
		_check("①e 계단 노치(%d,%d) 통행 가능" % [gx, gy], _walkable(m, Vector2i(gx, gy)))
	# 고지 수풀(TREE)·백사장 land는 걸을 수 있다.
	_check("①f 백사장(생선가게 옆 y%d)은 걸을 수 있음" % (sea_y0 - 2), _walkable(m, Vector2i(20, sea_y0 - 2)))
	_check("①g 고지 도착 밴드(28,3)는 걸을 수 있음", _walkable(m, Vector2i(28, 3)))

	# ── ② 부두(잔교) = 바다 위 PATH, 끝이 바다 낚시터 ──
	for y in range(m.PIER_Y0, m.PIER_Y1 + 1):
		_check("② 부두 칸 PATH (%d,%d)" % [m.PIER_X, y], m._grid[y][m.PIER_X] == m.PATH)
	_check("②b 부두 끝(바다 낚시터) 걸을 수 있음", _walkable(m, Vector2i(m.PIER_X, m.PIER_Y1)))
	# 부두 끝은 바다 한가운데 — 좌우는 WATER(잔교다움).
	_check("②c 부두 끝 좌우는 바다(WATER)",
		m._grid[m.PIER_Y1][m.PIER_X - 1] == m.WATER and m._grid[m.PIER_Y1][m.PIER_X + 1] == m.WATER)

	# ── ③ 생선가게 외관 = WALL 박스 + 문 PATH 리세스, 실내 빈 방 ──
	var ext: Rect2i = m.FISHSHOP_EXT_RECT
	for x in range(ext.position.x, ext.end.x):
		for y in range(ext.position.y, ext.end.y):
			var t := Vector2i(x, y)
			if t == m.FISHSHOP_EXT_DOOR:
				_check("③ 생선가게 문 = PATH 리세스", m._grid[y][x] == m.PATH)
			else:
				_check("③b 생선가게 외관 칸 WALL (%d,%d)" % [x, y], m._grid[y][x] == m.WALL)
	_check("③c 생선가게 실내 바닥 빌드(HOUSE 타일)",
		m._grid[m.FISHSHOP_RECT.position.y + 1][m.FISHSHOP_RECT.position.x + 1] == m.HOUSE)
	# ★[S3-T1] 외관만 백사장 밴드로 내렸고 **실내 앵커는 바이트 불변**(혼백관 보존 원칙 동형).
	_check("③d 실내 rect 무변경(8,46,12,9)", m.FISHSHOP_RECT == Rect2i(8, 46, 12, 9))
	_check("③e 실내 문·진입 칸 무변경",
		m.FISHSHOP_DOOR == Vector2i(13, 54) and m.FISHSHOP_IN_TILE == Vector2i(13, 53))
	_check("③f 실내 카메라 rect 무변경(2,44,20,13)", m.FISHSHOP_CAM_RECT == Rect2i(2, 44, 20, 13))
	_check("③g 생선가게 외관이 백사장 밴드(절벽 아래·바다 위)",
		ext.position.y > cliff_y + 2 and ext.end.y - 1 < sea_y0)

	# ── ④ flood-fill 무 soft-lock: spawn에서 문·부두 끝·복귀 워프 도달 ──
	# ★[S3-T1] spawn이 서단(2,15) → **북단 중앙(28,2)**으로 이동했다(종형 남향 축 = 북에서 들어온다).
	var spawn: Vector2i = RegionCatalog.spawn_of(RegionCatalog.HWANGCHEONHAE)
	_check("④ spawn = (28,2) ★[S3-T1] 북단 고지 도착 밴드", spawn == Vector2i(28, 2))
	_check("④a spawn이 절벽 런 위(고지 쪽)", spawn.y < cliff_y)
	var reach := _reachable(m, spawn)
	_check("④a2 절벽 아래 백사장까지 도달(노치 관통)", reach.has(m.FISHSHOP_EXT_DOOR + Vector2i(0, 1)))
	_check("④b 생선가게 외관 문 도달", reach.has(m.FISHSHOP_EXT_DOOR))
	_check("④c 부두 끝(바다 낚시터) 도달", reach.has(Vector2i(m.PIER_X, m.PIER_Y1)))
	var warps: Array = RegionCatalog.warps_of(RegionCatalog.HWANGCHEONHAE)
	_check("④d 막다른 구역 — 워프 1개(삼도천 복귀)", warps.size() == 1)
	for w in warps:
		_check("④e 워프 발동 칸 도달 (→%s)" % w["to"], reach.has(w["at"]))
		_check("④f 워프 발동 칸이 PATH (→%s)" % w["to"], m._grid[w["at"].y][w["at"].x] == m.PATH)

	# ── ⑤ 생선가게 출입 라운드트립 + 취침 불가 + 세이브 라운드트립 ──
	m.player.position = m._tile_center_px(m.FISHSHOP_EXT_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("⑤ 생선가게 진입(_indoor=생선가게)", m._indoor == "생선가게")
	_check("⑤b 플레이어가 생선가게 방 안", m.FISHSHOP_RECT.has_point(m._player_tile()))
	_check("⑤c 카메라 생선가게 방 격리(top=FISHSHOP_CAM)",
		m._cam.limit_top == m.FISHSHOP_CAM_RECT.position.y * m.TILE)
	_check("⑤d 생선가게 안 취침 불가(남의 건물)", not m._can_sleep())
	m.player.position = m._tile_center_px(m.FISHSHOP_DOOR)
	m._maybe_toggle_building()
	await _settle(m)
	_check("⑤e 생선가게 퇴장(_indoor='')", m._indoor == "")
	var fishshop_in: Vector2i = m.FISHSHOP_IN_TILE   # m free 전 상수 캡처(세이브 라운드트립용)
	await _despawn(m)

	var sm := SaveManager.new()
	sm.save_game({"region": RegionCatalog.HWANGCHEONHAE, "indoor": "생선가게", "player_tile": fishshop_in})
	sm.free()
	var m2: Node = await _spawn_main()
	_check("⑤f 구역 복원(황천해)", m2._region == RegionCatalog.HWANGCHEONHAE)
	_check("⑤g 생선가게 실내 모드 복원", m2._indoor == "생선가게")
	_check("⑤h 위치 복원(생선가게 진입 칸)", m2._player_tile() == fishshop_in)
	await _despawn(m2)

	# ── ⑥ 회귀 0: 카탈로그 생선가게 등록 + 홈 집 출입 불변 ──
	# ⑤에서 황천해 세이브를 남겼으니, 깨끗한 새 게임(HOME)으로 부팅되게 spawn 전에 지운다(테스트 격리).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m3: Node = await _spawn_main()
	_check("⑥ 생선가게 카탈로그 = HWANGCHEONHAE·fishshop",
		m3._buildings.has("생선가게")
		and m3._buildings["생선가게"]["region"] == RegionCatalog.HWANGCHEONHAE
		and m3._buildings["생선가게"]["kind"] == "fishshop")
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
