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
