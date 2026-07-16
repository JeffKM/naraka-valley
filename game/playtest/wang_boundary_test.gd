extends SceneTree
# Wang 경계 전환 헬퍼 단위검증(순수 함수 + 로더). run_tests.sh 워치독과 함께.
var _fail := 0
func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok: _fail += 1

func _spawn() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _initialize() -> void:
	print("══ Wang 경계 전환 헬퍼 검증 ══")
	var m: Node = await _spawn()
	# ① 위계: 잔디>흙>길>밭>물
	_check("① 위계 잔디(1)>흙(0)>길(2)>밭(3)>물(4)",
		m._surf_rank(1) > m._surf_rank(0) and m._surf_rank(0) > m._surf_rank(2)
		and m._surf_rank(2) > m._surf_rank(3) and m._surf_rank(3) > m._surf_rank(4))
	# ② 코너 비트: NW=1비트, SE=8비트
	_check("② _corner_bits(1,0,0,0)=1", m._corner_bits(1,0,0,0) == 1)
	_check("② _corner_bits(0,0,0,1)=8", m._corner_bits(0,0,0,1) == 8)
	_check("② _corner_bits(1,1,1,1)=15", m._corner_bits(1,1,1,1) == 15)
	# ③ 꼭짓점 표면 = 인접 4셀 위계 최대(-1 제외)
	var surf := [[0, 1], [3, -1]]   # 흙·잔디 / 밭·건물
	_check("③ 꼭짓점(1,1)=인접{흙,잔디,밭} 중 잔디(위계최대)",
		m._wang_vertex_surf(surf, 1, 1) == 1)
	_check("③ 꼭짓점(0,0)=코너 흙 하나만",
		m._wang_vertex_surf(surf, 0, 0) == 0)
	# ④ pair_key 유일
	_check("④ pair_key(0,1)≠pair_key(1,0)",
		m._wang_pair_key(0,1) != m._wang_pair_key(1,0))
	# ⑤ 로더: 흙↔잔디(0_1) 16 코너조합 로드
	m._load_wang_pairs()
	var pk: int = m._wang_pair_key(0, 1)
	_check("⑤ 흙↔잔디 tileset 로드됨", m._wang_tiles.has(pk))
	_check("⑤ 16 코너조합 커버", m._wang_tiles.has(pk) and (m._wang_tiles[pk] as Dictionary).size() == 16)
	print("결과: %d 실패" % _fail)
	quit()
