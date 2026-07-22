extends SceneTree
# [ADR-0058] 지상 스캐터 변주 — 구역-키드 테이블 + 풀무리 이웃-확산 단위검증.
# 순수 시각(_ground_detail_tex bake)·결정적·저작맵 불가침. 좀비 방지: 끝에서 quit().

var _fail := 0
func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok: _fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _initialize() -> void:
	print("══ 지상 스캐터 변주(ADR-0058) 검증 ══")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m: Node = await _spawn_main()
	_check("⓪ 부팅 = 안식 농원(HOME)", m._region == RegionCatalog.HOME)

	# ── Task 1: 구역-키드 조회 + 전역 폴백 ──
	_check("① 미지 구역은 전역 GROUND 테이블로 폴백", _same_table(
		_call_table_for(m, "nonexistent_region", m.GROUND), m._GD_TABLES[m.GROUND]))
	_check("① 미지 구역 sparse도 전역 폴백", _same_table(
		_call_sparse_for(m, "nonexistent_region"), m._GD_SPARSE))

	# ── Task 2: 안식 테이블 = 풀무리 ↑ ──
	var home_ground: Array = m._REGION_GD_TABLES.get(RegionCatalog.HOME, {}).get(m.GROUND, [])
	_check("② 안식 GROUND 오버라이드 존재", not home_ground.is_empty())
	# 풀 tuft(GD_GRASS1) 가중이 전역(30)보다 높다.
	var home_grass_w := _weight_of(home_ground, m.GD_GRASS1)
	var glob_grass_w := _weight_of(m._GD_TABLES[m.GROUND], m.GD_GRASS1)
	_check("② 안식 풀 tuft 가중 > 전역", home_grass_w > glob_grass_w)
	# 맨 잔디 여백(null)이 전역(44)보다 낮다 → 풀무리 체감↑.
	_check("② 안식 맨 여백(null) 가중 < 전역", _weight_of(home_ground, null) < _weight_of(m._GD_TABLES[m.GROUND], null))

	# ── Task 3: 풀무리 CA 이웃-확산 마스크 ──
	m._compute_scatter_clump()
	var first: Array = m._scatter_clump.duplicate(true)
	m._compute_scatter_clump()
	_check("③ 마스크 결정적(재계산 동일)", str(first) == str(m._scatter_clump))
	# 비-GROUND 셀은 clump=0(저작 셀 불침범).
	var bad := false
	for yy in m._outdoor_h:
		for xx in m._grid_w:
			if m._grid[yy][xx] != m.GROUND and m._scatter_clump[yy][xx] == 1:
				bad = true
	_check("③ 비-GROUND 셀은 clump 아님", not bad)
	# 이웃-상관: clump 셀의 직교이웃이 clump일 확률 > 전역 clump 비율(유기적 응집).
	_check("③ clump 이웃-상관 > 전역비율", _neighbor_corr(m) > _global_rate(m))

	# ── Task 4(손그림 형태 마스크): 물↔흙 4_0 → 0=물·1=흙·2=테두리 마스크(② 루프서 셀별 합성) ──
	# 부팅 시 _build_ground16이 이미 _build_shore_masks 호출 → _shore_mask 채워짐.
	var sm: Dictionary = m._shore_mask
	_check("④ 물↔흙 형태 마스크 16 코너키 생성됨", sm.size() == 16)
	if sm.size() == 16:
		var full: int = int(m.TILE) * int(m.TILE)
		var m0: PackedByteArray = sm[0]     # bits=0 all-물
		var m15: PackedByteArray = sm[15]   # bits=15 all-흙
		var m3: PackedByteArray = sm[3]     # bits=3 경계(북흙/남물)
		_check("④ all-물(bits0) = 대부분 물(0)", _cls_count(m0, 0) > full / 2)
		_check("④ all-흙(bits15) = 대부분 흙(1)", _cls_count(m15, 1) > full / 2)
		# 경계 타일은 흙(1)·물(0) 둘 다 존재(전환) + 테두리(2) 존재(오토타일 실효).
		_check("④ 경계(bits3) 흙·물 둘 다 존재(전환 나뉨)", _cls_count(m3, 0) > 0 and _cls_count(m3, 1) > 0)
		_check("④ 경계(bits3) 테두리(2) 존재", _cls_count(m3, 2) > 0)
		# idempotent: 재호출해도 이미 있으면 불변.
		var before := _cls_count(m3, 2)
		m._build_shore_masks()
		_check("④ 마스크 idempotent(재호출 불변)", _cls_count(m._shore_mask[3], 2) == before)

	# ── Task 5(ADR-0059 결정 2): 마이크로 알고리즘 티어1·2 결정성 ──
	# 같은 시드 2회 빌드 산출 동일(FastNoiseLite seed 고정 + hash 결정 랜덤 → randi/Time 미사용 확증).
	m._build_ground16()
	var data_a: PackedByteArray = m._ground_detail_tex.get_image().get_data()
	m._build_ground16()
	var data_b: PackedByteArray = m._ground_detail_tex.get_image().get_data()
	_check("⑤ _build_ground16 결정적(2회 빌드 픽셀 동일)", data_a == data_b)
	_check("⑤ _mask_noise 결정적(단일 진입점)", m._mask_noise(12.0, 34.0) == m._mask_noise(12.0, 34.0))
	_check("⑤ _macro/_micro fBm 결정적", m._macro_noise01(5.0, 7.0) == m._macro_noise01(5.0, 7.0) \
		and m._micro_noise01(5.0, 7.0) == m._micro_noise01(5.0, 7.0))
	# 외톨이 정리 실효 — clump 마스크에 min-size(3) 미만 4-연결 조각이 없다.
	m._compute_scatter_clump()
	_check("⑤ clump 외톨이(<%d) 조각 없음" % m._SCATTER_CLUMP_MIN, _min_clump_comp(m) >= m._SCATTER_CLUMP_MIN)

	print("결과: %d 실패" % _fail)
	quit(1 if _fail > 0 else 0)

# clump 마스크의 4-연결 컴포넌트 중 최소 크기(외톨이 정리 검증). 조각 없으면 큰 값.
func _min_clump_comp(m: Node) -> int:
	var seen := {}
	var smallest := 1 << 30
	for y in m._outdoor_h:
		for x in m._grid_w:
			if int(m._scatter_clump[y][x]) != 1 or seen.has(Vector2i(x, y)):
				continue
			var n := 0
			var stack: Array = [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				n += 1
				for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var nb: Vector2i = c + d
					if nb.x >= 0 and nb.y >= 0 and nb.x < m._grid_w and nb.y < m._outdoor_h \
							and int(m._scatter_clump[nb.y][nb.x]) == 1 and not seen.has(nb):
						seen[nb] = true
						stack.append(nb)
			smallest = min(smallest, n)
	return smallest

func _cls_count(m: PackedByteArray, cls: int) -> int:
	var n := 0
	for v in m:
		if v == cls:
			n += 1
	return n

func _same_table(a: Array, b: Array) -> bool:
	return a.size() == b.size() and (a.is_empty() or a[0][1] == b[0][1])

# 테스트가 구역을 강제로 바꿔 조회를 검증하기 위한 래퍼(구현이 _region을 읽으므로 임시 세팅).
func _call_table_for(m: Node, region: String, terrain: int) -> Array:
	var saved = m._region
	m._region = region
	var r: Array = m._gd_table_for(terrain)
	m._region = saved
	return r

func _call_sparse_for(m: Node, region: String) -> Array:
	var saved = m._region
	m._region = region
	var r: Array = m._gd_sparse_for()
	m._region = saved
	return r

func _weight_of(table: Array, tex: Variant) -> int:
	for e in table:
		if e[0] == tex:
			return int(e[1])
	return 0

func _global_rate(m: Node) -> float:
	var g := 0; var tot := 0
	for yy in m._outdoor_h:
		for xx in m._grid_w:
			if m._grid[yy][xx] == m.GROUND:
				tot += 1
				if m._scatter_clump[yy][xx] == 1: g += 1
	return float(g) / max(1, tot)

func _neighbor_corr(m: Node) -> float:
	var hit := 0; var tot := 0
	for yy in m._outdoor_h:
		for xx in m._grid_w:
			if m._grid[yy][xx] == m.GROUND and m._scatter_clump[yy][xx] == 1:
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx = xx + d.x; var ny = yy + d.y
					if nx >= 0 and nx < m._grid_w and ny >= 0 and ny < m._outdoor_h and m._grid[ny][nx] == m.GROUND:
						tot += 1
						if m._scatter_clump[ny][nx] == 1: hit += 1
	return float(hit) / max(1, tot)
