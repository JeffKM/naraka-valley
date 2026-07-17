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

	# ── Task 4(Wang 물↔흙): base 합성 + 단차 ──
	var wkey: int = m._wang_pair_key(4, 0)   # = 40
	var wt: Dictionary = m._wang_tiles.get(wkey, {})
	_check("④ 물↔흙(40) 합성 타일 16 코너키 존재", wt.size() == 16)
	# all-upper(bits=15) 타일 중앙 = 흙 base(_bf_earth), all-lower(bits=0) = 물 base(_bf_water).
	var P: int = m._GF * 2
	var cc := int(m.TILE / 2)
	if wt.has(15) and wt.has(0):
		var earth_px: Color = (wt[15] as Image).get_pixel(cc, cc)
		var water_px: Color = (wt[0] as Image).get_pixel(cc, cc)
		_check("④ all-흙 코너 = _bf_earth 픽셀", earth_px.is_equal_approx(m._bf_earth.get_pixel(cc % P, cc % P)))
		_check("④ all-물 코너 = _bf_water 픽셀", water_px.is_equal_approx(m._bf_water.get_pixel(cc % P, cc % P)))
	else:
		_check("④ all-흙/all-물 코너키 존재", false)
	# 결정성: 재-bake 시 동일 픽셀(좌표해시 순수).
	m._bake_water_dirt_wang()
	var again: PackedByteArray = (m._wang_tiles[wkey][12] as Image).get_data()
	m._bake_water_dirt_wang()
	_check("④ 물↔흙 합성 결정적", again == (m._wang_tiles[wkey][12] as Image).get_data())

	# ── Task 4(림): 얕은물 밝은 림이 물 픽셀을 밝힌다(rim on > rim off) ──
	const _TMPK := 987654   # 실제 _wang_tiles[40] 불침범용 임시 키
	m._bake_field_wang(_TMPK, m._bf_earth, m._bf_water, m._W40_RAG, m._W40_MICRO, m._W40_EDGE_DARK, m._W40_SHADOW, m._W40_SHADOW_DARK, 0.0, 0)
	var lum_off := _tile_luma(m._wang_tiles[_TMPK][1] as Image)   # bits=1: NW만 흙, 나머지 물(경계 존재)
	m._bake_field_wang(_TMPK, m._bf_earth, m._bf_water, m._W40_RAG, m._W40_MICRO, m._W40_EDGE_DARK, m._W40_SHADOW, m._W40_SHADOW_DARK, 0.30, 2)
	var lum_on := _tile_luma(m._wang_tiles[_TMPK][1] as Image)
	_check("④ 얕은물 림 활성 시 물 픽셀 더 밝음(rim on > off)", lum_on > lum_off)
	m._wang_tiles.erase(_TMPK)
	# 하위호환: 잔디↔흙(0_1) 재-bake는 rim 기본 0이라 결정적·불변(회귀 0 방증).
	var g_before: PackedByteArray = (m._wang_tiles[m._wang_pair_key(0,1)][12] as Image).get_data()
	m._bake_grass_dirt_wang()
	_check("④ 잔디↔흙 rim 무영향(재-bake 동일)", g_before == (m._wang_tiles[m._wang_pair_key(0,1)][12] as Image).get_data())

	print("결과: %d 실패" % _fail)
	quit(1 if _fail > 0 else 0)

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

func _tile_luma(img: Image) -> float:
	var s := 0.0
	for j in img.get_height():
		for i in img.get_width():
			var c := img.get_pixel(i, j)
			s += (c.r + c.g + c.b) * c.a
	return s
