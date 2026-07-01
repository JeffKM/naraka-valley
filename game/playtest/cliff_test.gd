extends SceneTree

# ★ [S1-2 / ADR-0044 §1] pseudo-Z 다단 절벽 원시어휘 격리 검증(ephemeral 헤드리스).
#
# 무엇을 보나(S1-2 = 어휘·문법·격리 검증만 — 실배치 §5는 S1-3):
#   ① 남향 밴드 = Lip행 / Face행 / Face_Base행 타일종 패턴.
#   ② 타일종별 통과성(정준 is_solid) — CLIFF_LIP 걷기 O / CLIFF_FACE·CLIFF_FACE_BASE SOLID.
#   ③ 동향 밴드 = Lip열 / Face 2열(base 없음 — "높이의 가로 치환").
#   ④ 계단 노치 = 밴드 단면 종단이 walkable로 열림(옆 밴드는 여전히 SOLID).
#   ⑤ 코너 스텝 = 청키 블록 edge-to-edge(내부 FACE·상단 LIP 캡).
#   ⑥ 8이웃(대각 포함) BFS leak = 2행 밴드가 고지↔저지를 차단(대각 squeeze 0), 노치로만 연결.
#
# 라이브 home맵은 건드리지 않는다(스크래치 rect만 덮어쓴다 — 회귀 0). 옛 _build_cliffs(1타일) 유지.
# 물리 corner-squeeze(CharacterBody2D 대각 틈) 최종확인은 S1-3 bot/map_dump 육안(격자 BFS는 물리 틈 못 잡음).
# 좀비 방지: 모든 단언 뒤 quit(). run_tests.sh 워치독과 함께.

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

	# ── ② 타일종별 통과성(정준 is_solid) ──
	_check("② CLIFF_LIP 걷기 O (is_solid=false)", not m.is_solid(m.CLIFF_LIP))
	_check("② CLIFF_FACE SOLID", m.is_solid(m.CLIFF_FACE))
	_check("② CLIFF_FACE_BASE SOLID", m.is_solid(m.CLIFF_FACE_BASE))

	# ── ③ 동향 밴드: Lip열 / Face 2열(base 없음) ──
	m._fill_rect(scratch, m.GROUND)
	var ex := 52
	m._lay_east_band(ex, 44, 52)
	_check("③ 동향 Lip열 = CLIFF_LIP", m._grid[48][ex] == m.CLIFF_LIP)
	_check("③ 동향 Face 1열 = CLIFF_FACE", m._grid[48][ex + 1] == m.CLIFF_FACE)
	_check("③ 동향 Face 2열 = CLIFF_FACE (base 없음)", m._grid[48][ex + 2] == m.CLIFF_FACE)
	_check("③ 동향 Lip 걷기 O·Face 2열 SOLID", (not m.is_solid(m._grid[48][ex])) \
		and m.is_solid(m._grid[48][ex + 1]) and m.is_solid(m._grid[48][ex + 2]))

	# ── ④ 계단 노치: 밴드 단면 종단 → walkable(옆 밴드는 SOLID 유지) ──
	m._fill_rect(scratch, m.GROUND)
	var ny := 45
	m._lay_south_band(50, 62, ny)
	m._carve_stair_notch(Rect2i(55, ny, 2, 3))   # 2열 종단(Lip/Face/Base 3행 깊이)
	_check("④ 노치 Lip행 walkable", not m.is_solid(m._grid[ny][55]))
	_check("④ 노치 Face행 walkable", not m.is_solid(m._grid[ny + 1][55]))
	_check("④ 노치 Base행 walkable", not m.is_solid(m._grid[ny + 2][55]))
	_check("④ 노치 옆 Face 여전히 SOLID", m.is_solid(m._grid[ny + 1][60]))

	# ── ⑤ 코너 스텝: 청키 블록 edge-to-edge(내부 FACE·상단 LIP 캡) ──
	m._fill_rect(scratch, m.GROUND)
	m._lay_corner_step(Rect2i(50, 42, 3, 3))   # x50..52, y42..44
	_check("⑤ 코너 상단행 = LIP 캡", m._grid[42][51] == m.CLIFF_LIP)
	_check("⑤ 코너 내부 = FACE(edge-to-edge)", m._grid[43][51] == m.CLIFF_FACE and m._grid[44][52] == m.CLIFF_FACE)

	# ── ⑥ 8이웃 BFS leak: 2행 밴드가 고지↔저지 차단(대각 squeeze 0), 노치로만 연결 ──
	m._fill_rect(scratch, m.GROUND)
	var br := 48
	m._lay_south_band(48, 67, br)   # 스크래치 전폭(x48..67) 종단 → 고지(y40..47)↔저지(y51..59) 분리
	var plateau := Vector2i(58, 44)
	var lowland := Vector2i(58, 55)
	var blocked := _reach8(m, lowland, scratch)
	_check("⑥ 무노치: 2행 밴드가 고지↔저지 차단(대각 leak 0)", not blocked.has(plateau))
	m._carve_stair_notch(Rect2i(57, br, 2, 3))
	var opened := _reach8(m, lowland, scratch)
	_check("⑥ 노치 뚫음: 고지↔저지 연결(노치 경유)", opened.has(plateau))

	m.queue_free()
	await process_frame
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
