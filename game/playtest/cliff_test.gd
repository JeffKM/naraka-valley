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

	m.queue_free()
	await process_frame
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
