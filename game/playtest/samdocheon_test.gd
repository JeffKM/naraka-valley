extends SceneTree
# M3.1 / ★[ADR-0061 결정 1 · S3-T1 종형 남향 이행] — 삼도천(강 낚시 무대 + 혼백관) 그레이박스 검증
# (ephemeral). main을 인스턴스화해 삼도천 구역을 빌드한 뒤 강(WATER) 밴드·북안 강둑·잔교·혼백관
# 외관/실내·동선(무 soft-lock)·출입 라운드트립·취침 불가·세이브 복원·회귀 0을 단언한다.
# region.gd 데이터(워프 점등·dest)는 world_test가, 워프 *동작*은 warp_test가 본다 — 여기는 main이
# 그 데이터로 *삼도천을 어떻게 짓는지*(그리드 콘텐츠 + 건물)를 본다.
#
# ★ 핵심 불변식(S3-T1 종형 플립 — 북에서 들어와 남으로 빠진다):
#   ① 강(WATER) 밴드가 남부(SAMDO_RIVER_Y0~Y1)에 **전 폭**으로 흐르고(잔교 열만 예외), 그 북안 상단
#      1행이 CLIFF_BANK 단차(SOLID)다 — 나루 배후 강 북안 문법 동형(ADR-0044 §2).
#   ①b 잔교(SAMDO_JETTY_X)가 강을 세로 종단해 통행 가능하고, 남안 좁은 스트립(y>RIVER_Y1)이 land다.
#   ② 혼백관 외관 = 통과 불가 WALL 박스 + 문 1칸(PATH 리세스), 실내는 빈 방(kind=museum).
#      실내 rect·문·카메라는 **무변경**(ADR-0061 혼백관 보존 원칙) — 외관만 북부 도착 밴드로 이동.
#   ③ 북단 나룻터 spawn(28,2)에서 혼백관 문·북단 복귀 워프·남단 하구 워프 칸이 걸어서 닿는다(flood-fill).
#      강 남쪽에서 닿는 칸은 잔교를 거친 것뿐 = 우회 도하 0.
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

# 외부에서 걸을 수 있는 칸인가(SOLID·WATER·VOID·범위밖이면 X). 실내 스택(y>=outdoor_h)은 제외.
# ★C4 — 삼도천이 56×40이라 전역 MAP_W/OUTDOOR_H가 아니라 빌드된 구역 치수(_grid_w/_outdoor_h)를 쓴다(village_test 결).
# ★[S3-T1] 강둑(CLIFF_BANK)이 도입돼 WALL 하드코딩으로는 부족하다 — 단일 진실원 is_solid()를 쓴다(village_test 결).
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

	# ── ① 남부 강 밴드(전 폭) + 북안 CLIFF_BANK 단차 + 잔교 종단 ──
	var jx: int = m.SAMDO_JETTY_X
	var ry0: int = m.SAMDO_RIVER_Y0
	var ry1: int = m.SAMDO_RIVER_Y1
	var bank_y: int = m.SAMDO_RIVER_BANK_Y
	_check("① 강 밴드가 남부다(북부 도착 밴드 아래) — y%d~%d" % [ry0, ry1], ry0 > m._outdoor_h / 2)
	_check("①b 강둑 1행이 강 최상단 바로 위", bank_y == ry0 - 1)
	_check("①c 강 폭 ≥3행(강으로 읽힘) — %d행" % (ry1 - ry0 + 1), ry1 - ry0 + 1 >= 3)
	# 전 폭 전수 스캔 — 잔교 열을 뺀 모든 강 칸이 WATER인가(우회 도하 구멍 0). 맵 가장자리 x0·x끝 포함.
	var river_hole := 0
	for y in range(ry0, ry1 + 1):
		for x in m._grid_w:
			if x == jx:
				continue
			if m._grid[y][x] != m.WATER:
				river_hole += 1
	_check("①d 강 밴드 전 폭 WATER(잔교 열 제외) — 구멍 %d칸" % river_hole, river_hole == 0)
	# 북안 강둑도 전 폭(잔교 열만 PATH로 열림).
	var bank_hole := 0
	for x in m._grid_w:
		if x == jx:
			continue
		if m._grid[bank_y][x] != m.CLIFF_BANK:
			bank_hole += 1
	_check("①e 북안 강둑 전 폭 CLIFF_BANK(잔교 열 제외) — 구멍 %d칸" % bank_hole, bank_hole == 0)
	_check("①f 강둑은 통과 불가(SOLID — 시각 단차 + 우회 차단)", m.is_solid(m.CLIFF_BANK))
	# 잔교(목판) 열 = 강둑~강 남단까지 전부 통행 가능(강을 세로 종단).
	var jetty_ok := true
	for y in range(bank_y, ry1 + 1):
		if m._grid[y][jx] != m.PATH:
			jetty_ok = false
	_check("①g 잔교 열(x%d)이 강둑~강 남단 전부 PATH(종단 통행)" % jx, jetty_ok)
	# 북안 물가(강둑 바로 위) = 강 낚시터 밴드, 남안 스트립(강 바로 아래) = 좁은 land.
	_check("①h 북안 물가(y%d)는 걸을 수 있음(강 낚시터)" % (bank_y - 1), _walkable(m, Vector2i(20, bank_y - 1)))
	_check("①i 남안 스트립(y%d)은 걸을 수 있는 land" % (ry1 + 1), _walkable(m, Vector2i(20, ry1 + 1)))
	_check("①j 남안 스트립이 좁다(≤3행) — %d행" % (m._outdoor_h - 1 - ry1), m._outdoor_h - 1 - ry1 <= 3)

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
	# ★[ADR-0061 혼백관 보존 원칙] 외관만 북부 밴드로 옮겼고 **실내 앵커는 바이트 불변**이다 —
	#   세이브 키(기증 원장)·기증대·카메라가 실내 좌표에만 걸려 있어 여길 흔들면 S2-T5가 깨진다.
	_check("②e 실내 rect 무변경(8,44,12,9)", m.MUSEUM_RECT == Rect2i(8, 44, 12, 9))
	_check("②f 실내 문·진입 칸·기증대 무변경",
		m.MUSEUM_DOOR == Vector2i(13, 52) and m.MUSEUM_IN_TILE == Vector2i(13, 51)
		and m.MUSEUM_DONATE_TILE == Vector2i(13, 46))
	_check("②g 실내 카메라 rect 무변경(2,42,20,13)", m.MUSEUM_CAM_RECT == Rect2i(2, 42, 20, 13))
	# 외관은 북부 도착 밴드(강둑 위)에 있다 = 도착하자마자 보이고, 강 건너편이 아니다.
	_check("②h 혼백관 외관이 북부 도착 밴드(강둑 위)", m.MUSEUM_EXT_RECT.end.y - 1 < bank_y)

	# ── ③ flood-fill 무 soft-lock: spawn에서 문·두 워프 칸 도달 + 우회 도하 0 ──
	# ★[S3-T1] spawn이 남단(28,38) → **북단 나룻터(28,2)**로 뒤집혔다(종형 남향 축 = 북에서 들어온다).
	var spawn: Vector2i = RegionCatalog.spawn_of(RegionCatalog.SAMDOCHEON)
	_check("③ spawn = (28,2) ★[S3-T1] 북단 나룻터", spawn == Vector2i(28, 2))
	_check("③a spawn이 나룻터 부두 데크 안", m.SAMDO_DOCK_RECT.has_point(spawn))
	var reach := _reachable(m, spawn)
	_check("③b 혼백관 외관 문 도달", reach.has(m.MUSEUM_EXT_DOOR))
	var warps: Array = RegionCatalog.warps_of(RegionCatalog.SAMDOCHEON)
	for w in warps:
		_check("③c 워프 발동 칸 도달 (→%s)" % w["to"], reach.has(w["at"]))
		_check("③d 워프 발동 칸이 PATH (→%s)" % w["to"], m._grid[w["at"].y][w["at"].x] == m.PATH)
	_check("③e 강 낚시터(북안 물가) 도달", reach.has(m.SAMDO_FISHING_LABEL_TILE))
	# 강 남쪽(남안 스트립)에서 닿는 칸이 실재하고, 그 도하는 전부 잔교 열을 거쳤다(우회 0).
	var south_reached := 0
	var south_cross_hole := 0
	for t in reach:
		var tt: Vector2i = t
		if tt.y < bank_y:
			continue
		south_reached += 1
		if tt.y <= ry1 and tt.x != jx:
			south_cross_hole += 1   # 강/강둑 행인데 잔교 열이 아니다 = 우회 도하
	_check("③f 강 남쪽에 실제로 도달(잔교가 살아 있음) — %d칸" % south_reached, south_reached > 0)
	_check("③g 도하는 잔교 열뿐(우회 도하 0) — 이탈 %d칸" % south_cross_hole, south_cross_hole == 0)

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
