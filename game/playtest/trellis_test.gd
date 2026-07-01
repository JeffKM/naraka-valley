extends SceneTree

# ★ [S1-5a / greybox-spec §6] 트렐리스(황천포도 end-to-end) 격리 검증.
#
# 무엇을 보나(S1-5a = 트렐리스 충돌 + REGROW 수확 + 다수확·인접수확 근거):
#   ① is_crop_solid 술어 — 트렐리스 심김=solid / 비트렐리스 심김·빈칸·미경작=non-solid.
#   ② REGROW 수확 사이클 — 황천포도 성숙→수확→넝쿨 보존(planted)·grown_days=base−cd·is_mature=false
#      →물주고 cd일→재성숙→재수확(사이클). 수확 후에도 solid 유지.
#   ③ SINGLE 대조 — 혼령초 성숙→수확→비워짐(planted=false)·여전히 tilled·non-solid.
#   ④ solid_crop_tiles() 목록 정확성.
#   ⑤ (main 통합) 트렐리스 칸이 그리드상 여전히 farmable 타겟(인접수확 근거)이면서 동시에 solid,
#      _trellis_body 충돌이 세워짐 — "조준 O(수확) + 이동 X(통과불가)" 공존.
#
# Part A(①②③④)는 FarmField 단위(main 불필요), Part B(⑤)만 main 스폰(cliff_test 결).
# 성장은 물-구동 advance_day 재사용분만(신규 성장 로직 0). 좀비 방지: 끝에 quit(). run_tests 워치독.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# 물주고 하루 넘기기를 반복해 성숙시킨다(물-구동 advance_day 기본 0,0 = 순수 스타듀 성장).
func _grow_to_mature(farm: FarmField, t: Vector2i) -> void:
	var guard := 0
	while not farm.is_mature(t) and guard < 60:
		farm.water(t)
		farm.advance_day()
		guard += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _initialize() -> void:
	print("▶ trellis_test (S1-5a)")
	var farm := FarmField.new()

	# ── ① is_crop_solid 술어 ──
	var tt := Vector2i(0, 0)   # 트렐리스(황천포도)
	farm.hoe(tt)
	farm.plant(tt, CropCatalog.HWANGCHEON_PODO)
	_check("① 트렐리스 심긴 칸 solid", farm.is_crop_solid(tt))
	var st := Vector2i(1, 0)   # 비트렐리스(혼령초)
	farm.hoe(st)
	farm.plant(st, CropCatalog.HONRYEONGCHO)
	_check("① 비트렐리스 심긴 칸 non-solid", not farm.is_crop_solid(st))
	var et := Vector2i(2, 0)   # 빈 경작칸
	farm.hoe(et)
	_check("① 빈 경작칸 non-solid", not farm.is_crop_solid(et))
	_check("① 미경작칸 non-solid", not farm.is_crop_solid(Vector2i(9, 9)))

	# ── ④ solid_crop_tiles 정확성(트렐리스칸만) ──
	var solids := farm.solid_crop_tiles()
	_check("④ solid_crop_tiles = 트렐리스칸 1개만", solids.size() == 1 and solids[0] == tt)

	# ── ② REGROW 수확 사이클 ──
	_grow_to_mature(farm, tt)
	_check("② 황천포도 성숙", farm.is_mature(tt))
	var base := CropCatalog.growth_days(CropCatalog.HWANGCHEON_PODO)   # 7
	var cd := CropCatalog.regrow_cooldown(CropCatalog.HWANGCHEON_PODO) # 3
	var got := farm.harvest(tt)
	_check("② REGROW 수확 반환 = 작물 id", got == CropCatalog.HWANGCHEON_PODO)
	_check("② 수확 후 넝쿨 보존(planted)", farm.is_planted(tt))
	_check("② 수확 후 grown_days = base−cd (%d)" % (base - cd), farm.grown_days_of(tt) == base - cd)
	_check("② 수확 직후 is_mature=false(되감김)", not farm.is_mature(tt))
	_check("② 수확 후에도 solid 유지(넝쿨)", farm.is_crop_solid(tt))
	for _i in cd:   # 물주고 cd일 → 재성숙
		farm.water(tt)
		farm.advance_day()
	_check("② 물주고 cd일 → 재성숙", farm.is_mature(tt))
	var got2 := farm.harvest(tt)
	_check("② 재수확 사이클 성립(넝쿨 유지)", got2 == CropCatalog.HWANGCHEON_PODO and farm.is_planted(tt))

	# ── ③ SINGLE 대조(혼령초) ──
	_grow_to_mature(farm, st)
	_check("③ 혼령초 성숙", farm.is_mature(st))
	var sgot := farm.harvest(st)
	_check("③ SINGLE 수확 반환 = 작물 id", sgot == CropCatalog.HONRYEONGCHO)
	_check("③ SINGLE 수확 후 비워짐(planted=false)", not farm.is_planted(st))
	_check("③ SINGLE 수확 후 여전히 tilled", farm.is_tilled(st))
	_check("③ 비워진 SINGLE 칸 non-solid", not farm.is_crop_solid(st))

	# ── ⑤ main 통합: 그리드-SOIL 공존(인접수확 근거) + is_crop_solid + 충돌바디 ──
	var m := await _spawn_main()
	# 안식 농원(부팅 구역)에서 첫 farmable(SOIL) 칸을 찾는다.
	var soil := Vector2i(-1, -1)
	for y in range(m._grid_h):
		for x in range(m._grid_w):
			if m._is_farmable(Vector2i(x, y)):
				soil = Vector2i(x, y)
				break
		if soil.x >= 0:
			break
	_check("⑤ 안식 농원에 farmable SOIL 칸 존재", soil.x >= 0)
	m.farm.hoe(soil)
	m.farm.plant(soil, CropCatalog.HWANGCHEON_PODO)
	await process_frame
	_check("⑤ 트렐리스 칸 여전히 farmable 타겟(인접수확 근거)", m._is_farmable(soil))
	_check("⑤ 동시에 is_crop_solid(통과불가)", m.farm.is_crop_solid(soil))
	_check("⑤ _trellis_body 충돌 1개 생성(물리 배선)", m._trellis_body.get_child_count() == 1)
	m.queue_free()
	await process_frame

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
