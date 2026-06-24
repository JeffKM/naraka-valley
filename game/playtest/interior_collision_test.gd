extends SceneTree

# ★ T3③' 실내 가구 충돌 단위검증(젬나이 피드백 — 가구 통과 버그 수정 잠금).
#
# 무엇을 보나:
#   ① _prop_body 존재 + HOME 실내 가구 칸에 충돌 shape가 세워짐(SOLID_PROPS 수와 정합).
#   ② 통과 불가 — 침대·벽난로·책장·테이블·화분 중심에 물리 point query가 콜라이더를 맞춘다.
#   ③ 통과 가능(분리) — 러그(바닥 깔개)·빈 바닥 칸은 콜라이더 없음(걸어 지나갈 수 있음).
#   ④ 구역 전환 멱등 — 마을로 워프 후 HOME 복귀 시 충돌이 다시 정확히 선다(중복·누락 0).
#
# 좀비 방지: 모든 단언 뒤 quit(). 폴링 없음. run_tests.sh 워치독과 함께.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	await physics_frame   # StaticBody/CollisionShape가 물리 공간에 등록될 시간
	return m

# 월드 좌표에 콜라이더가 있나(가구 충돌체) — 직접 공간 point query.
func _hits(m: Node, world: Vector2) -> bool:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world
	params.collide_with_bodies = true
	params.collision_mask = 0xFFFFFFFF
	var space: PhysicsDirectSpaceState2D = m.get_world_2d().direct_space_state
	return space.intersect_point(params, 4).size() > 0

# SOLID_PROPS 엔트리의 첫 칸 충돌 중심(시각 lift 포함 — _rebuild_prop_collision과 동일 식).
func _prop_center(m: Node, tex) -> Vector2:
	for entry in m.PROP_LAYOUT_HOME:
		if entry[0] == tex:
			var sz: Vector2 = tex.get_size()
			var yo: int = entry[2] if entry.size() > 2 else 0
			var t = entry[1][0]
			return Vector2(t.x * m.TILE, t.y * m.TILE + yo) + sz * 0.5
	return Vector2.ZERO

func _initialize() -> void:
	print("══ 실내 가구 충돌 검증 ══")
	var m: Node = await _spawn()
	_check("⓪ 부팅 = HOME", m._region == RegionCatalog.HOME)

	# ── ① 충돌 shape 세워짐 ──
	_check("① _prop_body 존재", m._prop_body != null)
	_check("① 가구 충돌 shape > 0", m._prop_body.get_child_count() > 0)

	# ── ② 통과 불가(가구 중심에 콜라이더) ──
	_check("② 침대 통과 불가", _hits(m, _prop_center(m, m.PROP_BED)))
	_check("② 벽난로 통과 불가", _hits(m, _prop_center(m, m.PROP_FIREPLACE)))
	_check("② 책장 통과 불가", _hits(m, _prop_center(m, m.PROP_BOOKSHELF)))
	_check("② 테이블 통과 불가", _hits(m, _prop_center(m, m.PROP_TABLE)))
	_check("② 화분 통과 불가", _hits(m, _prop_center(m, m.PROP_POT)))

	# ── ③ 통과 가능(러그·빈 바닥은 콜라이더 없음) ──
	# 러그 좌상단(테이블·가구 비껴) — 바닥 깔개라 충돌 X.
	var rug_pt := Vector2(11 * m.TILE + 8, 71 * m.TILE + 8)
	_check("③ 러그(바닥) 통과 가능", not _hits(m, rug_pt))
	# 빈 실내 바닥 칸(10,71) 중심 — 가구·벽 비껴.
	var floor_pt := Vector2(10 * m.TILE + 16, 71 * m.TILE + 16)
	_check("③ 빈 바닥 통과 가능", not _hits(m, floor_pt))

	# ── ④ 구역 전환 멱등(마을 왕복 후 HOME 충돌 재구성) ──
	var n0: int = m._prop_body.get_child_count()
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	await process_frame
	await physics_frame
	m._rebuild_region(RegionCatalog.HOME)
	await process_frame
	await physics_frame
	_check("④ HOME 복귀 후 충돌 shape 수 동일(멱등)", m._prop_body.get_child_count() == n0)
	_check("④ 복귀 후 침대 여전히 통과 불가", _hits(m, _prop_center(m, m.PROP_BED)))

	m.queue_free()
	await process_frame
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
