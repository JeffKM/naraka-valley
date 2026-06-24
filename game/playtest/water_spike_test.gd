extends SceneTree
# Phase 2.8 T2 — ★물(WATER) 터레인 스파이크 게이트 검증(ephemeral).
# P2.3에서 미검증이던 물 Wang→corner TileSet 파이프라인을 얇은 단면으로 게이트한다(Sprint-1식
# 리스크-우선). 통과해야 나루(T4)·삼도천·황천해 본 도색 착수. main을 인스턴스화해 *실제* 빌드 경로
# (_build_tileset + _paint_grid)로 물 구역을 짓고, 다음 4개 통과 기준을 단언한다:
#
# ★ 통과 기준(verification criteria):
#   ① 물 Wang→corner TileSet 변환 성공 — combined_terrain.tres가 terrain 4종(길·풀·흙·물),
#      terrain 3 = 물, 물 코너 비트를 가진 타일이 존재.
#   ② WATER 통과 불가 충돌 유지(회귀 0) — 물 코너를 가진 source 0 타일 전부에 충돌 폴리곤이 달려,
#      옛 SOLID WATER와 동일한 통과 불가 집합. 순수 풀 타일은 충돌 없음(걷기).
#   ③ land↔water 경계 테스트맵에서 검은 구멍 0 — 물 구역(삼도천 가로 강·나루 세로 강·미혹 연못)의
#      모든 WATER 칸이 유효 타일로 칠해짐(source_id != -1) + 그 타일이 통과 불가.
#   ④ corner 전환 자연스러움 — 물 칸에 base(4코너 물)뿐 아니라 전환 타일(풀 코너 섞임)도 깔려,
#      경계가 단색 절벽이 아니라 풀↔물 corner 전환으로 읽힘.
#
# 실행: godot --headless --path game --script res://playtest/water_spike_test.gd

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

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

# 타일이 물(TR_WATER) 코너를 하나라도 가지나.
func _has_water_corner(td: TileData, tr_water: int) -> bool:
	for c in [TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]:
		if td.get_terrain_peering_bit(c) == tr_water:
			return true
	return false

# 칠해진 칸의 타일이 충돌 폴리곤(물리 레이어 0)을 가지나(= 통과 불가).
func _cell_blocks(m: Node, cell: Vector2i) -> bool:
	var sid: int = m.ground.get_cell_source_id(cell)
	if sid == -1:
		return false   # 빈칸(검은 구멍) — 충돌도 없음
	var src := m.ground.tile_set.get_source(sid) as TileSetAtlasSource
	var coord: Vector2i = m.ground.get_cell_atlas_coords(cell)
	var td := src.get_tile_data(coord, 0)
	return td.get_collision_polygons_count(0) > 0

func _initialize() -> void:
	print("══ Phase 2.8 T2 — 물 터레인 스파이크 게이트 검증 ══")

	# ── ① 변환 성공: combined_terrain.tres가 4 terrain, 물 = terrain 3 ──
	var ts: TileSet = load("res://assets/tiles/combined_terrain.tres")
	_check("① terrain set 1개", ts.get_terrain_sets_count() == 1)
	_check("①b terrain 4종(길·풀·흙·물)", ts.get_terrains_count(0) == 4)
	_check("①c terrain 3 = 물(이름에 'water')", ts.get_terrain_name(0, 3).to_lower().contains("water"))

	var m: Node = await _spawn_main()
	var tr_water: int = m.TR_WATER
	_check("①d main.TR_WATER == 3", tr_water == 3)
	_check("①e TILE_TERRAIN[WATER] == TR_WATER", m.TILE_TERRAIN.get(m.WATER, -1) == tr_water)
	_check("①f WATER가 SOLID_TILES에서 빠짐(승격)", not m.SOLID_TILES.has(m.WATER))

	# ── ② 충돌 유지(회귀 0): 물 코너 타일 전부 충돌, 순수 풀 타일은 충돌 없음 ──
	var src := m.ground.tile_set.get_source(0) as TileSetAtlasSource
	var water_tiles := 0
	var water_no_coll := 0
	var grass_base_has_coll := false
	for i in src.get_tiles_count():
		var coord := src.get_tile_id(i)
		var td := src.get_tile_data(coord, 0)
		if td.terrain_set != m.TERRAIN_SET:
			continue
		if _has_water_corner(td, tr_water):
			water_tiles += 1
			if td.get_collision_polygons_count(0) == 0:
				water_no_coll += 1
		else:
			# 물 코너 0인 타일(순수 풀/길/흙·전환)은 충돌 없어야 걷는다.
			if td.get_collision_polygons_count(0) > 0:
				grass_base_has_coll = true
	_check("② 물 코너 타일 존재(>0)", water_tiles > 0)
	_check("②b 물 코너 타일 전부 충돌 폴리곤(통과 불가)", water_no_coll == 0)
	_check("②c 비-물 terrain 타일은 충돌 없음(풀·길·흙 걷기)", not grass_base_has_coll)

	# ── ③④ land↔water 경계 검은 구멍 0 + 전환 타일 + 통과 불가 (물 3구역으로 게이트) ──
	for region in [RegionCatalog.SAMDOCHEON, RegionCatalog.NARU_VILLAGE, RegionCatalog.MIHOK_FOREST]:
		m._rebuild_region(region)
		var rname: String = RegionCatalog.name_of(region)
		var holes := 0          # WATER 칸인데 빈칸(검은 구멍)
		var unblocked := 0      # WATER 칸인데 통과 가능(충돌 누락)
		var water_count := 0
		var transition_tiles := 0   # 물 칸인데 풀 코너가 섞인 전환 타일
		var base_water_tiles := 0   # 물 칸인데 4코너 모두 물(base)
		for y in m._grid.size():
			for x in m._grid[y].size():
				if m._grid[y][x] != m.WATER:
					continue
				water_count += 1
				var cell := Vector2i(x, y)
				var sid: int = m.ground.get_cell_source_id(cell)
				if sid == -1:
					holes += 1
					continue
				if not _cell_blocks(m, cell):
					unblocked += 1
				# 전환 vs base 분류(④ corner 전환 증거)
				var tsrc := m.ground.tile_set.get_source(sid) as TileSetAtlasSource
				var coord2: Vector2i = m.ground.get_cell_atlas_coords(cell)
				var td := tsrc.get_tile_data(coord2, 0)
				var ncorners := 0
				for c in [TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
						TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]:
					if td.get_terrain_peering_bit(c) == tr_water:
						ncorners += 1
				if ncorners == 4:
					base_water_tiles += 1
				else:
					transition_tiles += 1
		_check("③ [%s] 물 칸 존재(>0)" % rname, water_count > 0)
		_check("③b [%s] 물 칸 검은 구멍 0 (%d칸)" % [rname, water_count], holes == 0)
		_check("③c [%s] 물 칸 전부 통과 불가(충돌)" % rname, unblocked == 0)
		_check("④ [%s] 경계 전환 타일 존재(corner 전환 — base만 아님)" % rname, transition_tiles > 0)
		print("    · %s: 물 %d칸 = base %d + 전환 %d" % [rname, water_count, base_water_tiles, transition_tiles])

	# ── ⑤ 회귀: 물 인접 land(풀)는 걷을 수 있다(충돌 없음) — 삼도천 둑 ──
	m._rebuild_region(RegionCatalog.SAMDOCHEON)
	var bank := Vector2i(20, m.SAMDO_RIVER_Y1 + 1)   # 강 바로 아래 둑(land)
	_check("⑤ 강 둑(land) 칸은 칠해짐(검은 구멍 아님)", m.ground.get_cell_source_id(bank) != -1)
	_check("⑤b 강 둑(land) 칸은 통과 가능(충돌 없음)", not _cell_blocks(m, bank))

	await _despawn(m)

	print("══ 결과: %s ══" % ("PASS (실패 0) — GO" if _fail == 0 else "FAIL (실패 %d) — 폴백 검토" % _fail))
	quit(1 if _fail > 0 else 0)
