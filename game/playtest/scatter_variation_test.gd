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

	# ── Task 4(물↔흙 shore 후처리): 물 셀의 흙-인접 변에 어두운 단차 밴드(동/서·남), 북쪽 제외 ──
	# 3×3 셀: 중앙(1,1)=물, 좌·우·상·하=흙, 나머지 물. _water_shore_edges가 out 픽셀을 어둡게 한다.
	var TL: int = m.TILE
	var tsurf := []
	for yy in 3:
		var row := []
		for xx in 3:
			row.append(4)   # 물
		tsurf.append(row)
	tsurf[1][0] = 0; tsurf[1][2] = 0; tsurf[0][1] = 0; tsurf[2][1] = 0   # 서·동·북·남 흙
	var base_c := Color(0.2, 0.4, 0.45)
	var timg := Image.create(3 * TL, 3 * TL, false, Image.FORMAT_RGBA8)
	timg.fill(base_c)
	# _water_shore_edges가 _grid_w/_outdoor_h를 참조 → 임시 세팅 후 복원.
	var sv_w = m._grid_w; var sv_h = m._outdoor_h
	m._grid_w = 3; m._outdoor_h = 3
	m._water_shore_edges(timg, tsurf)
	var mid := TL + int(TL / 2)
	var west_px: Color = timg.get_pixel(TL, mid)            # 중앙셀 좌측 첫 열(서쪽 흙 인접)
	var east_px: Color = timg.get_pixel(2 * TL - 1, mid)    # 중앙셀 우측 끝 열(동쪽 흙 인접)
	var south_px: Color = timg.get_pixel(mid, 2 * TL - 1)   # 중앙셀 하단 끝 행(남쪽 흙 인접)
	var north_px: Color = timg.get_pixel(mid, TL)           # 중앙셀 상단 첫 행(북쪽 흙 인접)
	var center_px: Color = timg.get_pixel(mid, mid)         # 중앙셀 중앙(어느 밴드도 안 닿음 = pristine base)
	_check("④ 물 서쪽(흙인접) 단차 = 어두워짐", west_px.v < center_px.v)
	_check("④ 물 동쪽(흙인접) 단차 = 어두워짐", east_px.v < center_px.v)
	_check("④ 물 남쪽(흙인접) 단차 = 어두워짐", south_px.v < center_px.v)
	_check("④ 물 북쪽(흙인접) = 제외(강둑 담당·단차 없음)", north_px.is_equal_approx(center_px))
	# 동/서가 남보다 깊은 단차(_WS_SIDE_DARK > _WS_BOT_DARK) → 경계 픽셀이 더 어둡다.
	_check("④ 동/서 단차 > 남 단차(경계 더 어둠)", west_px.v < south_px.v)
	# 흙쪽(바깥): 서쪽 흙셀의 물-인접 가장자리(x=TL-1) 일부 픽셀이 불규칙하게 어두워짐(젖은 진흙 얼룩).
	var earth_dark := false
	for jj in TL:
		if timg.get_pixel(TL - 1, TL + jj).v < center_px.v - 0.001:
			earth_dark = true
	_check("④ 흙쪽(바깥) 불규칙 젖은 진흙 적용", earth_dark)
	# 결정성: 재실행 동일 픽셀(순수 함수).
	var timg2 := Image.create(3 * TL, 3 * TL, false, Image.FORMAT_RGBA8)
	timg2.fill(base_c)
	m._water_shore_edges(timg2, tsurf)
	m._grid_w = sv_w; m._outdoor_h = sv_h
	_check("④ shore 후처리 결정적", timg.get_data() == timg2.get_data())

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
