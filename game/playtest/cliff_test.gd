extends SceneTree

# ★ [S1-2 / ADR-0044 §1 → 단계3 남향-only] pseudo-Z 절벽 격리 검증(ephemeral 헤드리스).
#
# 무엇을 보나(단계3 남향-only 피벗 후 — 옛 동향밴드·90°코너스텝 케이스는 ⑥ 정리로 폐기):
#   ① 남향 밴드 = Lip행 / Face행 / Face_Base행 타일종 패턴.
#   ② 타일종별 통과성(정준 is_solid) — CLIFF_LIP 걷기 O / CLIFF_FACE·CLIFF_FACE_BASE SOLID.
#   ③ 계단 노치 = 밴드 단면 종단이 walkable로 열림(옆 밴드는 여전히 SOLID).
#   ④ 8이웃(대각 포함) BFS leak = 2행 밴드가 고지↔저지를 차단(대각 squeeze 0), 노치로만 연결.
#   ⑤ [단계3] 남향-only 오토타일러 = 사각 마스크 → 남쪽만 Lip/Face/Base, 동/서/북=잔디 능선.
#   ⑥ [단계3-④] 곡선 코너 = 벽 서/동 바깥 끝 = CORNER_SW/SE × Face/Base(전부 SOLID), 중간 벽 직선.
#   ⑦ [ADR-0056 ④] 연못 북단 뱅크 = _autotile_pond_siblings가 SPIRIT_POND_RECT에서 유도(하드코딩 제거·멱등).
#   ⑧ [ADR-0056 ①] 절벽 상단 fringe = _build_ground16이 CLIFF_LIP 위에 풀 늘어뜨림(순수 시각·_grid 불변).
#   ⑨ [ADR-0056 ③] 노치 좌우 벽 끝 = _round_south_notch가 곡선 코너(SE/SW)로 라운딩(SOLID·폭 불변).
#   ⑩ [ADR-0056 ④] BASE 발치 그림자 밴드 = 아래 tan 그리드 불변(순수 시각 오버레이).
#
# 라이브 home맵은 건드리지 않는다(스크래치 rect만 덮어쓴다 — 회귀 0). 라이브는 _autotile_south_cliffs가 남향
# 벽을 굽고, _lay_south_band는 이 격리 검증 전용 원시어휘다. 좀비 방지: quit(). run_tests.sh 워치독과 함께.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

# 8이웃(대각 포함) 도달성 — scratch rect 안으로 한정, is_solid 칸은 막힘.
func _reach8(m: Node, start: Vector2i, r: Rect2i) -> Dictionary:
	var seen := {start: true}
	var stack: Array = [start]
	while not stack.is_empty():
		var t: Vector2i = stack.pop_back()
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var n: Vector2i = t + Vector2i(dx, dy)
				if n.x < r.position.x or n.y < r.position.y or n.x >= r.end.x or n.y >= r.end.y:
					continue
				if seen.has(n):
					continue
				if m.is_solid(m._grid[n.y][n.x]):
					continue
				seen[n] = true
				stack.append(n)
	return seen

func _initialize() -> void:
	var m := await _spawn_main()
	# 스크래치 영역 — 라이브 홈 콘텐츠와 격리(전 칸 GROUND로 통제). 외부 그리드(80×65) 안·실내밴드(y65+) 밖.
	var scratch := Rect2i(48, 40, 20, 20)   # x48..67, y40..59
	m._fill_rect(scratch, m.GROUND)

	# ── ① 남향 밴드: Lip행 / Face행 / Face_Base행 ──
	var sy := 43
	m._lay_south_band(50, 62, sy)
	_check("① 남향 Lip행 = CLIFF_LIP", m._grid[sy][55] == m.CLIFF_LIP)
	_check("① 남향 Face행 = CLIFF_FACE", m._grid[sy + 1][55] == m.CLIFF_FACE)
	_check("① 남향 Base행 = CLIFF_FACE_BASE", m._grid[sy + 2][55] == m.CLIFF_FACE_BASE)

	# ── ①' 지면 오버레이 절벽 스킵(ADR-0053/0054 흙-지배 flip 리그레션 가드) ──
	# _build_ground16/_ground_detail_tex가 절벽 셀을 tan/잔디로 베이크·덮으면 절벽이 화면에서 사라진다
	# (owner "절벽 아예 안 보여" 버그). _g16_surface가 절벽 계열을 -1(투명 통과)로 분류해 밑 타일맵 절벽이 비쳐야 한다.
	_check("①' 오버레이 Lip 스킵(-1)", m._g16_surface(55, sy) == -1)
	_check("①' 오버레이 Face 스킵(-1)", m._g16_surface(55, sy + 1) == -1)
	_check("①' 오버레이 Base 스킵(-1)", m._g16_surface(55, sy + 2) == -1)
	_check("①' 오버레이 GROUND는 안 스킵(≥0)", m._g16_surface(55, sy - 2) >= 0)

	# ── ② 타일종별 통과성(정준 is_solid) ──
	_check("② CLIFF_LIP 걷기 O (is_solid=false)", not m.is_solid(m.CLIFF_LIP))
	_check("② CLIFF_FACE SOLID", m.is_solid(m.CLIFF_FACE))
	_check("② CLIFF_FACE_BASE SOLID", m.is_solid(m.CLIFF_FACE_BASE))

	# ── ③ 계단 노치: 밴드 단면 종단 → walkable(옆 밴드는 SOLID 유지) ──
	m._fill_rect(scratch, m.GROUND)
	var ny := 45
	m._lay_south_band(50, 62, ny)
	m._carve_stair_notch(Rect2i(55, ny, 2, 3))   # 2열 종단(Lip/Face/Base 3행 깊이)
	_check("③ 노치 Lip행 walkable", not m.is_solid(m._grid[ny][55]))
	_check("③ 노치 Face행 walkable", not m.is_solid(m._grid[ny + 1][55]))
	_check("③ 노치 Base행 walkable", not m.is_solid(m._grid[ny + 2][55]))
	_check("③ 노치 옆 Face 여전히 SOLID", m.is_solid(m._grid[ny + 1][60]))

	# ── ④ 8이웃 BFS leak: 2행 밴드가 고지↔저지 차단(대각 squeeze 0), 노치로만 연결 ──
	m._fill_rect(scratch, m.GROUND)
	var br := 48
	m._lay_south_band(48, 67, br)   # 스크래치 전폭(x48..67) 종단 → 고지(y40..47)↔저지(y51..59) 분리
	var plateau := Vector2i(58, 44)
	var lowland := Vector2i(58, 55)
	var blocked := _reach8(m, lowland, scratch)
	_check("④ 무노치: 2행 밴드가 고지↔저지 차단(대각 leak 0)", not blocked.has(plateau))
	m._carve_stair_notch(Rect2i(57, br, 2, 3))
	var opened := _reach8(m, lowland, scratch)
	_check("④ 노치 뚫음: 고지↔저지 연결(노치 경유)", opened.has(plateau))

	# ── ⑤ [단계3 남향-only] 오토타일러: 사각 고지 마스크 → 남쪽만 Lip/Face/Base 바위벽, 동/서/북=잔디 유지 ──
	m._fill_rect(scratch, m.GROUND)
	var hi := Rect2i(52, 43, 8, 6)   # 고지 x52..59, y43..48 (scratch 안)
	m._autotile_south_cliffs(func(c: Vector2i) -> bool: return hi.has_point(c))
	_check("⑤ 남단 Lip(걷기 O)", m._grid[48][55] == m.CLIFF_LIP and not m.is_solid(m.CLIFF_LIP))
	_check("⑤ 남단+1 Face(SOLID)", m._grid[49][55] == m.CLIFF_FACE and m.is_solid(m.CLIFF_FACE))
	_check("⑤ 남단+2 Base(SOLID)", m._grid[50][55] == m.CLIFF_FACE_BASE and m.is_solid(m.CLIFF_FACE_BASE))
	_check("⑤ 고지 내부 = 풀(바위벽 아님)", m._grid[45][55] == m.GROUND)
	_check("⑤ 동경계 = 풀 능선(바위벽 없음)", m._grid[45][59] == m.GROUND and m._grid[45][60] == m.GROUND)
	_check("⑤ 북경계 = 풀 능선(바위벽 없음)", m._grid[42][55] == m.GROUND)
	_check("⑤ 서경계 = 풀 능선(바위벽 없음)", m._grid[45][52] == m.GROUND and m._grid[45][51] == m.GROUND)

	# ── ⑥ [단계3-④] 곡선 코너: 벽 서/동 바깥 끝 = 곡선 코너 타일(SW/SE × Face/Base), 전부 SOLID ──
	# ⑤ 오토타일 결과(hi=x52..59) 재사용 — 서끝 x52·동끝 x59의 Face(y49)/Base(y50) 행.
	_check("⑥ 서끝 Face = CORNER_SW", m._grid[49][52] == m.CLIFF_CORNER_SW)
	_check("⑥ 서끝 Base = CORNER_SW_B", m._grid[50][52] == m.CLIFF_CORNER_SW_B)
	_check("⑥ 동끝 Face = CORNER_SE", m._grid[49][59] == m.CLIFF_CORNER_SE)
	_check("⑥ 동끝 Base = CORNER_SE_B", m._grid[50][59] == m.CLIFF_CORNER_SE_B)
	_check("⑥ 곡선 코너 4종 전부 SOLID", m.is_solid(m.CLIFF_CORNER_SW) and m.is_solid(m.CLIFF_CORNER_SW_B) \
		and m.is_solid(m.CLIFF_CORNER_SE) and m.is_solid(m.CLIFF_CORNER_SE_B))
	_check("⑥ 중간 벽은 직선 유지(코너 아님)", m._grid[49][55] == m.CLIFF_FACE and m._grid[50][55] == m.CLIFF_FACE_BASE)

	# ── ⑦ [ADR-0056 ④] 연못 북단 뱅크 = SPIRIT_POND_RECT 로컬 유도(하드코딩 제거·좌표 바이트 동일) ──
	# _build_home이 _autotile_pond_siblings로 깐 라이브 뱅크를 검증(함수가 rect 폭 전체에서 정확히 유도했는지).
	# scratch(x48..)와 연못(x26..33)은 안 겹쳐 앞 케이스 영향 없음.
	# ★[ADR-0058·북벽 세로 절벽] 옛 CLIFF_FACE/BANK 강둑 폐지 — 물(_fill_rect)이 연못 전체를 채우고 북벽은
	# _draw_north_pond_cliff 오버레이(순수 렌더)가 담당. _autotile_pond_siblings는 no-op(멱등). WATER=통과불가.
	var pr: Rect2i = m.SPIRIT_POND_RECT
	var water_ok := true
	for px in range(pr.position.x, pr.end.x):
		if m._grid[pr.position.y][px] != m.WATER:
			water_ok = false
	_check("⑦ 연못 북단 y0 = WATER(북벽=오버레이·옛 CLIFF_BANK 강둑 폐지)", water_ok)
	m._autotile_pond_siblings()   # 멱등: no-op이라 재호출해도 물 불변
	_check("⑦ _autotile_pond_siblings 멱등(no-op)", m._grid[pr.position.y][pr.position.x] == m.WATER)

	# ── ⑧ [ADR-0056 ①] 절벽 상단 fringe = 순수 시각(_grid·타일종 불변) ──
	# _build_ground16(HOME 지면 오버레이)이 CLIFF_LIP 상단에 풀을 늘어뜨리되 _grid·충돌은 안 건드리고
	# _ground_detail_tex(오버레이 텍스처)만 다시 굽는다. fringe 루프가 라이브 HOME lip 위를 실제로 돈다.
	var lip_cells: Array = []
	for yy in range(m._outdoor_h):
		for xx in range(m._grid_w):
			if m._grid[yy][xx] == m.CLIFF_LIP:
				lip_cells.append(Vector2i(xx, yy))
	m._build_ground16()
	var lip_intact := true
	for c in lip_cells:
		if m._grid[c.y][c.x] != m.CLIFF_LIP:
			lip_intact = false
	_check("⑧ fringe 후 CLIFF_LIP 격자 불변(순수 시각)", lip_intact and lip_cells.size() > 0)
	_check("⑧ _ground_detail_tex 생성됨(오버레이 베이크)", m._ground_detail_tex != null)

	# ── ⑨ [ADR-0056 ③ FINAL] 노치 좌우 벽 끝 = 곡선 코너 라운딩(라이브 HOME 노치) ──
	# _round_south_notch가 통로 마주 벽 끝을 CORNER로 스위칭(좌벽 동측=SE / 우벽 서측=SW). 코너는 SOLID라 폭 불변.
	var gx: int = m.RANCH_GATE_X
	var gw: int = m.RANCH_GATE_W
	var hs: int = m.HIGHLAND_S
	var nleft: int = gx - 1
	var nright: int = gx + gw
	_check("⑨ 노치 좌벽 Face 끝 = CORNER_SE", m._grid[hs + 1][nleft] == m.CLIFF_CORNER_SE)
	_check("⑨ 노치 좌벽 Base 끝 = CORNER_SE_B", m._grid[hs + 2][nleft] == m.CLIFF_CORNER_SE_B)
	_check("⑨ 노치 우벽 Face 끝 = CORNER_SW", m._grid[hs + 1][nright] == m.CLIFF_CORNER_SW)
	_check("⑨ 노치 우벽 Base 끝 = CORNER_SW_B", m._grid[hs + 2][nright] == m.CLIFF_CORNER_SW_B)
	_check("⑨ 코너 라운딩 후에도 SOLID(통로 폭 불변)", m.is_solid(m.CLIFF_CORNER_SE) and m.is_solid(m.CLIFF_CORNER_SW))

	# ── ⑩ [ADR-0056 ④ FINAL] BASE 발치 그림자 밴드 = 순수 시각(아래 tan 그리드 불변) ──
	# 접지 밴드는 _ground_detail_tex 오버레이만 어둡게 — _grid의 발치 아래(Y+1) 셀은 순수 GROUND(tan) 유지.
	var base_x: int = 5   # 노치(x9) 서쪽 내부 남향 벽
	_check("⑩ 남향 벽 Base 존재(x5)", m._grid[hs + 2][base_x] == m.CLIFF_FACE_BASE)
	_check("⑩ Base 아래(Y+1) 그리드 = GROUND(tan 불변·순수 시각)", m._grid[hs + 3][base_x] == m.GROUND)

	m.queue_free()
	await process_frame
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
