extends SceneTree

# ★[단계3-⑤] Front 립/오버행 라이브 HOME 검증(ephemeral 헤드리스).
#
# 무엇을 보나(owner 결정: 벽면 전체 front, 스타듀 표준 — 캐릭터가 절벽 밑에 서면 Face/Base가 상체를 가림):
#   ① 벽면 캐시(_cliff_face_cells)가 남향 절벽 벽면만 담고(Face/Base/곡선코너, Lip 제외), 게이트 노치 제외.
#   ② 근접 판정(_front_cliff_cells_for): 같은 열·벽 밑 1~2칸이면 front 대상, 멀거나(dy>2)·다른 열·위면 아님.
#
# 그리드·충돌은 불변(순수 시각 오버행 — z=1 재렌더일 뿐). 좀비 방지: quit(). run_tests.sh 워치독과 함께.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _initialize() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame

	# HOME이 부팅 기본 구역 — _build_cliffs가 _cliff_face_cells를 채운다.
	var cells: Array = m._cliff_face_cells
	_check("① 벽면 캐시 비어있지 않음", cells.size() > 0)
	var all_wall := true
	for c in cells:
		if not (m._grid[c.y][c.x] in m.CLIFF_WALL_TILES):
			all_wall = false
	_check("① 캐시 전부 CLIFF_WALL_TILES(Face/Base/곡선코너)", all_wall)
	var gate_free := true
	for c in cells:
		if c.x == m.RANCH_GATE_X or c.x == m.RANCH_GATE_X + 1:
			gate_free = false
	_check("① 게이트 노치 열 제외(노치가 GROUND로 덮음)", gate_free)
	var no_lip := true
	for c in cells:
		if m._grid[c.y][c.x] == m.CLIFF_LIP:
			no_lip = false
	_check("① Lip 제외(걷기 O·안 가림 — 벽면만)", no_lip)

	# ② 근접 판정 — 벽 셀 하나 기준 밑 1칸/3칸·다른 열·위 검증
	var wall: Vector2i = cells[0]
	var below1: Array = m._front_cliff_cells_for(Vector2i(wall.x, wall.y + 1))
	_check("② 벽 밑 1칸 → 그 벽 셀 front 대상", wall in below1)
	var below2: Array = m._front_cliff_cells_for(Vector2i(wall.x, wall.y + 2))
	_check("② 벽 밑 2칸 → 여전히 front 대상", wall in below2)
	var below3: Array = m._front_cliff_cells_for(Vector2i(wall.x, wall.y + 3))
	_check("② 벽 밑 3칸 → front 아님(dy>2 감쇠)", not (wall in below3))
	var other_col: Array = m._front_cliff_cells_for(Vector2i(wall.x + 5, wall.y + 1))
	_check("② 다른 열 → front 아님", not (wall in other_col))
	var above: Array = m._front_cliff_cells_for(Vector2i(wall.x, wall.y - 1))
	_check("② 벽 위(고지쪽) → front 아님(dy<=0)", not (wall in above))

	m.queue_free()
	await process_frame
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
