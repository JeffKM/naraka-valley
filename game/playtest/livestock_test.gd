extends SceneTree

# ★ [S1-7 / greybox-spec §4.1·§8] 혼의 짐승 목축 데일리 돌봄 루프 격리 검증.
#
# 무엇을 보나(S1-7 = 우정·기분 → 산물 · 급여/청결/야간보호 · 매일 돌봄 · 세이브 복원):
#   ① 배치 — add_animal 성공 / 중복 타일 거부 / 미지 종 거부.
#   ② 데일리 케어 플래그 — feed/pet/graze/pen/clean 세움·중복 거부 / tend_all 일괄.
#   ③ 우정·기분 정산(§4.1) — 완전 돌봄 델타(+33 우정·기분 255 saturate) / 완전 방치 델타(0·0).
#   ④ 우정 하트 파생(200/하트) / ⑤ 품질 state 파생 경계(NONE/BASIC/QUALITY/DELUXE) / ⑥ 대형 확률.
#   ⑦ 산물 생성 — 급여한 짐승만 산물 / 미급여 0 / 대기 중 중복 미생성(수집 전 프리즈).
#   ⑧ 산물 수집 — collect 반환·대기 0 리셋 / 미대기 collect {} / 산물 id = 종 산물.
#   ⑨ ★비살상 불변식 — 다일 완전 방치라도 짐승 제거 0·count 불변·우정/기분 바닥 clamp.
#   ⑩ 세이브 왕복 — 우정·기분·산물 상태 보존.
#   ⑪ ItemCatalog 통합 — 산물=CAT_HARVEST·대형가 ×2·건초=CAT_MATERIAL·이름.
#   ⑫ (main 통합) ranch 노드 스폰 + 스타터 짐승 존재.
#
# Part A(①~⑪)는 Ranch/카탈로그 단위(main 불필요), Part B(⑫)만 main 스폰(orchard_test 결).
# 품질/대형 roll은 난수라 값이 아니라 *state·확률 파생*(순수 함수)과 *생성 여부*(급여 게이트)만 단언한다.
# 좀비 방지: 끝에 quit(). run_tests 워치독.

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

func _initialize() -> void:
	print("▶ livestock_test (S1-7)")
	var DAK := AnimalCatalog.HONBAEK_DAK   # 노을닭(소형) — 산물 노을알·large_capable (내부 id 보존)
	var SO := AnimalCatalog.HONBAEK_SO     # 안개소(대형) — 산물 안개젖 (내부 id 보존)

	# ── ① 배치(§8.5) ──
	var r := Ranch.new()
	var t := Vector2i(4, 18)
	_check("① 짐승 배치 성공", r.add_animal(t, DAK) and r.has_animal(t))
	_check("① 배치 종 조회", r.species_at(t) == DAK)
	_check("① 중복 타일 배치 거부", not r.add_animal(t, SO))
	_check("① 미지 종 배치 거부", not r.add_animal(Vector2i(9, 9), "ghost_beast"))
	_check("① 초기 우정 0·기분 중립", r.friendship_of(t) == 0 and r.mood_of(t) == Ranch.MOOD_START)

	# ── ② 데일리 케어 플래그 ──
	_check("② feed 세움", r.feed(t) and r.is_fed(t))
	_check("② feed 중복 거부", not r.feed(t))
	_check("② pet 세움", r.pet(t) and r.is_petted(t))
	_check("② pet 중복 거부", not r.pet(t))
	_check("② graze/pen/clean 세움", r.graze(t) and r.pen(t) and r.clean(t))
	_check("② 없는 타일 케어 거부", not r.feed(Vector2i(99, 99)))

	# ── ③ 우정·기분 정산(§4.1) — t는 위에서 완전 돌봄(fed·pet·graze·pen·clean) 세워짐 ──
	# df = pet+15 + feed+5 + graze+8 + pen+5 = +33 / dm = feed40+pet30+pen40+graze30+clean20 = +160 → 128+160 clamp 255.
	r.advance_day()
	_check("③ 완전 돌봄 우정 델타 +33", r.friendship_of(t) == 33)
	_check("③ 완전 돌봄 기분 255 saturate", r.mood_of(t) == 255)
	_check("③ 정산 후 케어 플래그 리셋", not r.is_fed(t) and not r.is_petted(t))
	# 완전 방치 1일(fresh 짐승 t2, 플래그 전부 false) — df = -2(no pet) -20(no feed) = -22 → clamp0 /
	#   dm = -60(no feed) -40(no pen) -30(no clean) = -130 → 128-130 clamp 0.
	var t2 := Vector2i(6, 18)
	r.add_animal(t2, SO)
	r.advance_day()
	_check("③ 완전 방치 우정 0 clamp", r.friendship_of(t2) == 0)
	_check("③ 완전 방치 기분 0 clamp", r.mood_of(t2) == 0)

	# ── ④ 우정 하트 파생(200/하트) — 크래프트 세이브 로드로 임의 우정 주입 ──
	var rr := Ranch.new()
	rr.load_save({"animals": {
		Vector2i(0, 0): _mk(DAK, 1000, 255),   # 5하트
		Vector2i(1, 0): _mk(DAK, 850, 128),    # 4하트
		Vector2i(2, 0): _mk(DAK, 399, 128),    # 1하트
	}})
	_check("④ 우정 1000 → 5하트", rr.hearts_of(Vector2i(0, 0)) == 5)
	_check("④ 우정 850 → 4하트", rr.hearts_of(Vector2i(1, 0)) == 4)
	_check("④ 우정 399 → 1하트", rr.hearts_of(Vector2i(2, 0)) == 1)

	# ── ⑤ 품질 state 파생 경계(§4.1 재활용 §3.1) ──
	_check("⑤ (0하트,255) → NONE", Ranch.quality_state_for(0, 255) == FertilizerCatalog.STATE_NONE)
	_check("⑤ (1하트,255) → NONE", Ranch.quality_state_for(1, 255) == FertilizerCatalog.STATE_NONE)
	_check("⑤ (2하트,0) → BASIC", Ranch.quality_state_for(2, 0) == FertilizerCatalog.STATE_BASIC)
	_check("⑤ (3하트,255) → BASIC", Ranch.quality_state_for(3, 255) == FertilizerCatalog.STATE_BASIC)
	_check("⑤ (4하트,0) → QUALITY", Ranch.quality_state_for(4, 0) == FertilizerCatalog.STATE_QUALITY)
	_check("⑤ (5하트,199) → QUALITY(기분 게이트 미달)", Ranch.quality_state_for(5, 199) == FertilizerCatalog.STATE_QUALITY)
	_check("⑤ (5하트,200) → DELUXE", Ranch.quality_state_for(5, 200) == FertilizerCatalog.STATE_DELUXE)

	# ── ⑥ 대형 확률(§4.1 P_large=(하트/5)×0.5) ──
	_check("⑥ large_chance(0)=0", is_equal_approx(Ranch.large_chance(0), 0.0))
	_check("⑥ large_chance(2)=0.2", is_equal_approx(Ranch.large_chance(2), 0.2))
	_check("⑥ large_chance(5)=0.5(만렙)", is_equal_approx(Ranch.large_chance(5), 0.5))

	# ── ⑦ 산물 생성 — 급여 게이트(난수 무관 결정적) ──
	var rp := Ranch.new()
	var fed_tile := Vector2i(0, 5)
	var starve_tile := Vector2i(1, 5)
	rp.add_animal(fed_tile, DAK)
	rp.add_animal(starve_tile, DAK)
	rp.feed(fed_tile)                  # fed_tile만 급여
	rp.advance_day()
	_check("⑦ 급여한 짐승 산물 생성", rp.has_product(fed_tile))
	_check("⑦ 미급여 짐승 산물 0", not rp.has_product(starve_tile))
	# 대기 산물이 있으면 다음 advance가 새로 안 뱀(수집 전 프리즈) — 다시 급여해도 대기 1 유지.
	rp.feed(fed_tile)
	rp.advance_day()
	_check("⑦ 대기 중 중복 미생성(수집 전 프리즈)", rp.has_product(fed_tile))

	# ── ⑧ 산물 수집(§4.1) ──
	var picked := rp.collect(fed_tile)
	_check("⑧ 수집 반환 산물 id = 종 산물", picked.get("product_id", "") == AnimalCatalog.product_of(DAK))
	_check("⑧ 수집 후 대기 0 리셋", not rp.has_product(fed_tile))
	_check("⑧ 미대기 collect 빈 반환", rp.collect(starve_tile).is_empty())

	# ── ⑨ ★비살상 불변식(§4.1 하드 바운더리) — 완전 방치 다일 후에도 짐승 소멸 0 ──
	var rd := Ranch.new()
	var d0 := Vector2i(0, 9)
	var d1 := Vector2i(1, 9)
	rd.add_animal(d0, DAK)
	rd.add_animal(d1, SO)
	for _i in range(10):    # 10일 완전 방치(급여·격리·청소 전무)
		rd.advance_day()
	_check("⑨ 방치 10일 후 짐승 수 불변(비살상)", rd.count() == 2)
	_check("⑨ 방치 10일 후 짐승 여전히 존재", rd.has_animal(d0) and rd.has_animal(d1))
	_check("⑨ 방치 우정 0 바닥 clamp", rd.friendship_of(d0) == 0)
	_check("⑨ 방치 기분 0 바닥 clamp", rd.mood_of(d0) == 0)

	# ── ⑩ 세이브 왕복 ──
	# t(우정33·기분255) 짐승에 산물 하나 만들고(급여+advance) 세이브 → 로드 상태 보존.
	r.feed(t)
	r.advance_day()
	var blob := r.to_save()
	var r2 := Ranch.new()
	r2.load_save(blob)
	_check("⑩ 세이브 왕복 짐승 복원", r2.has_animal(t) and r2.count() == r.count())
	_check("⑩ 세이브 왕복 우정 보존", r2.friendship_of(t) == r.friendship_of(t))
	_check("⑩ 세이브 왕복 기분 보존", r2.mood_of(t) == r.mood_of(t))
	_check("⑩ 세이브 왕복 산물 대기 보존", r2.has_product(t) == r.has_product(t))
	# ★ [B1-a.1] 구버전 세이브(home_building 없음) 로드 → building_of "" 백필(방어).
	var rc := Ranch.new()
	rc.load_save({"animals": {Vector2i(0, 0): _mk(DAK, 0, 128)}})
	_check("⑩b 구버전 세이브 home_building 백필('')", rc.building_of(Vector2i(0, 0)) == "")

	# ── ⑬ [B1-a.1] 소속 건물·건물별 돌봄(진입 실내) ──
	var rb := Ranch.new()
	var bA := Vector2i(3, 3)   # 넋우릿간 소속
	var bB := Vector2i(4, 3)   # 넋우릿간 소속
	var bC := Vector2i(5, 3)   # 넋둥우리 소속
	rb.add_animal(bA, SO, "넋우릿간")
	rb.add_animal(bB, SO, "넋우릿간")
	rb.add_animal(bC, DAK, "넋둥우리")
	_check("⑬ building_of 반영", rb.building_of(bA) == "넋우릿간" and rb.building_of(bC) == "넋둥우리")
	_check("⑬ animals_in 필터(넋우릿간 2·넋둥우리 1)", rb.animals_in("넋우릿간").size() == 2 and rb.animals_in("넋둥우리").size() == 1)
	# 넋우릿간만 돌봄 → 그 소속만 방목·격리·청결 플래그 섬(넋둥우리는 불변).
	_check("⑬ tend_all_in 반환 true", rb.tend_all_in("넋우릿간"))
	rb.advance_day()   # 정산: 넋우릿간 소속은 방목·격리·청소 가산, 넋둥우리는 방치 감산 — 여기선 플래그 격리만 본다
	# advance_day가 플래그를 리셋하므로, 격리 검증은 정산 전에 별도로.
	var rb2 := Ranch.new()
	rb2.add_animal(bA, SO, "넋우릿간")
	rb2.add_animal(bC, DAK, "넋둥우리")
	rb2.tend_all_in("넋우릿간")
	_check("⑬ 건물별 돌봄 격리(넋우릿간 grazed·넋둥우리 미grazed)",
		rb2._animals[bA]["grazed"] and not rb2._animals[bC]["grazed"])
	_check("⑬ 빈 건물 tend_all_in = false(무동작)", not rb2.tend_all_in("없는건물"))

	# ── ⑪ ItemCatalog 통합(§8.6) ──
	var egg := AnimalCatalog.product_of(DAK)              # honbaek_ran
	var big_egg := ItemCatalog.large_product_id(egg)      # honbaek_ran_large
	_check("⑪ 산물 = CAT_HARVEST", ItemCatalog.category_of(egg) == ItemCatalog.CAT_HARVEST)
	_check("⑪ 대형 산물도 CAT_HARVEST", ItemCatalog.category_of(big_egg) == ItemCatalog.CAT_HARVEST)
	_check("⑪ 대형 판매가 = 기준 ×2", ItemCatalog.price_of(big_egg) == ItemCatalog.price_of(egg) * 2)
	_check("⑪ 대형 이름 '큰 …'", ItemCatalog.name_of(big_egg) == "큰 %s" % ItemCatalog.name_of(egg))
	_check("⑪ 건초 = CAT_MATERIAL", ItemCatalog.category_of(ItemCatalog.HAY) == ItemCatalog.CAT_MATERIAL)
	_check("⑪ 건초 has_item·이름", ItemCatalog.has_item(ItemCatalog.HAY) and ItemCatalog.name_of(ItemCatalog.HAY) == "건초")
	# 품질 배수 정합: 대형 이리듐(Q3) = 기준 ×2 ×2.0.
	_check("⑪ 대형 이리듐가 = 기준 ×4", ItemCatalog.price_of(big_egg, ItemCatalog.Q_IRIDIUM) == ItemCatalog.price_of(egg) * 4)

	# ── ⑭ [B1-a.2] pathing(실내↔방목 왕래)·방목 문 ──
	var rw := Ranch.new()
	var w1 := Vector2i(3, 3)   # 넋우릿간 소속
	var w2 := Vector2i(4, 3)   # 넋둥우리 소속
	rw.add_animal(w1, SO, "넋우릿간")
	rw.add_animal(w2, DAK, "넋둥우리")
	_check("⑭ 방목 문 기본 닫힘", not rw.door_open("넋우릿간") and not rw.door_open("넋둥우리"))
	_check("⑭ 새 짐승 실내 거주 시작", rw.location_of(w1) == Ranch.LOC_INDOOR and not rw.is_outside(w1))
	_check("⑭ 문 닫힘이면 releasable 0", rw.releasable().is_empty())
	_check("⑭ toggle_door 열림 반환", rw.toggle_door("넋우릿간"))
	_check("⑭ 문 연 건물만 releasable(넋우릿간 1)", rw.releasable().size() == 1 and rw.releasable()[0] == w1)
	var dest := Vector2i(5, 20)
	_check("⑭ send_to_pasture 성공", rw.send_to_pasture(w1, dest))
	_check("⑭ 방출 후 방목 상태·좌표", rw.is_outside(w1) and rw.pasture_tile_of(w1) == dest)
	_check("⑭ 방출이 grazed 자동 세움(F_GRAZE)", rw._animals[w1]["grazed"])
	# 밤 정산(문 열린 채) → 자동 귀가·penned·실내 복귀 / 실내 잔류 짐승도 penned(야간 격리).
	var n1 := rw.settle_night()
	_check("⑭ 문 열림 밤 귀가(실내 복귀·penned)", not rw.is_outside(w1) and rw._animals[w1]["penned"])
	_check("⑭ 실내 잔류 짐승도 penned(야간 격리, w2)", rw._animals[w2]["penned"])
	_check("⑭ settle_night 노출 0", int(n1["exposed"]) == 0)

	# 엣지① — 나간 뒤 문 닫아 실외 고립: penned 미설정·방목 위치 유지·비살상(짐승 소멸 0).
	var re := Ranch.new()
	var e1 := Vector2i(0, 0)
	re.add_animal(e1, SO, "넋우릿간")
	re.set_door("넋우릿간", true)
	re.send_to_pasture(e1, Vector2i(4, 20))
	re.set_door("넋우릿간", false)   # 귀가 전 문 닫음
	var n2 := re.settle_night()
	_check("⑭ 엣지① 실외 고립: penned 미설정", not re._animals[e1]["penned"])
	_check("⑭ 엣지① 실외 고립: 방목 위치 유지", re.is_outside(e1))
	_check("⑭ 엣지① settle_night 노출 1·격리 0", int(n2["exposed"]) == 1 and int(n2["penned"]) == 0)
	_check("⑭ 엣지① 비살상: 짐승 유지", re.count() == 1 and re.has_animal(e1))
	# 고립 짐승은 이후 문 다시 열면 다음 밤 귀가(회복).
	re.set_door("넋우릿간", true)
	var n3 := re.settle_night()
	_check("⑭ 문 다시 열면 고립 짐승 귀가", not re.is_outside(e1) and int(n3["penned"]) == 1)

	# 방목 문·위치 세이브 왕복.
	var rs := Ranch.new()
	var st := Vector2i(2, 2)
	rs.add_animal(st, DAK, "넋둥우리")
	rs.set_door("넋둥우리", true)
	rs.send_to_pasture(st, Vector2i(7, 21))
	var rs2 := Ranch.new()
	rs2.load_save(rs.to_save())
	_check("⑭ 세이브 왕복 방목 문 보존", rs2.door_open("넋둥우리"))
	_check("⑭ 세이브 왕복 방목 위치·좌표 보존", rs2.is_outside(st) and rs2.pasture_tile_of(st) == Vector2i(7, 21))
	# 구버전 세이브(location/doors 없음) 로드 → 실내·닫힘 default 백필.
	var rold := Ranch.new()
	rold.load_save({"animals": {Vector2i(9, 9): _mk(DAK, 0, 128)}})
	_check("⑭ 구버전 세이브 location 백필(실내)", rold.location_of(Vector2i(9, 9)) == Ranch.LOC_INDOOR)
	_check("⑭ 구버전 세이브 문 백필(닫힘)", not rold.door_open("넋둥우리"))
	# clean_all_in = 청소(청결)만 — 방목·격리는 pathing 몫이라 안 선다.
	var rcl := Ranch.new()
	var ct := Vector2i(1, 1)
	rcl.add_animal(ct, DAK, "넋둥우리")
	_check("⑭ clean_all_in 청소만(방목·격리 불변)",
		rcl.clean_all_in("넋둥우리") and rcl._animals[ct]["cleaned"] and not rcl._animals[ct]["grazed"] and not rcl._animals[ct]["penned"])

	# ── ⑮ [B1-a.3] 여물광(Silo) 건초 저장·여물통 급여 ──
	var rsi := Ranch.new()
	_check("⑮ 여물광 초기 0단", rsi.silo_hay() == 0 and not rsi.silo_full())
	_check("⑮ store_hay 저장수 반환", rsi.store_hay(5) == 5 and rsi.silo_hay() == 5)
	_check("⑮ 채움 비율", is_equal_approx(rsi.silo_fill_ratio(), 5.0 / float(Ranch.SILO_CAP)))
	rsi.store_hay(Ranch.SILO_CAP)   # 5 + 240 요청 → 235만 저장(합 240)·초과 소멸
	_check("⑮ 용량 상한 clamp(240)", rsi.silo_hay() == Ranch.SILO_CAP and rsi.silo_full())
	_check("⑮ 가득 찬 뒤 store_hay 0(소멸)", rsi.store_hay(3) == 0 and rsi.silo_hay() == Ranch.SILO_CAP)
	# 여물통 급여 — 여물광에서 짐승당 1단, 미급여만·재고만큼.
	var rf := Ranch.new()
	rf.add_animal(Vector2i(0, 0), DAK, "넋둥우리")
	rf.add_animal(Vector2i(1, 0), DAK, "넋둥우리")
	rf.store_hay(1)   # 1단만 → 한 마리만
	_check("⑮ 여물통 급여 = 재고만큼(1마리)", rf.feed_from_silo_in("넋둥우리") == 1 and rf.silo_hay() == 0)
	rf.store_hay(5)
	_check("⑮ 남은 미급여 급여(1마리)", rf.feed_from_silo_in("넋둥우리") == 1 and rf.silo_hay() == 4)
	_check("⑮ 이미 급여한 짐승 재급여 0", rf.feed_from_silo_in("넋둥우리") == 0 and rf.silo_hay() == 4)
	# 세이브 왕복 — 여물광 재고 보존 / 구버전(silo_hay 없음) 0 백필.
	var rf2 := Ranch.new()
	rf2.load_save(rf.to_save())
	_check("⑮ 세이브 왕복 여물광 재고 보존", rf2.silo_hay() == 4)
	var rf3 := Ranch.new()
	rf3.load_save({"animals": {}})
	_check("⑮ 구버전 세이브 여물광 0 백필", rf3.silo_hay() == 0)

	# ── Part B: main 통합(⑫) — 신규 게임 강제(세이브 백업·삭제)로 스타터 짐승 시드 검증 ──
	# save_region_test 결: 실제 개발 세이브를 백업했다가 끝에 복원(테스트 격리, 유저 세이브 불침범).
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)   # 세이브 제거 → _ready가 신규 게임 경로(스타터 시드)로 부팅
	var m := await _spawn_main()
	_check("⑫ ranch 노드 스폰", m.ranch != null)
	_check("⑫ 신규 게임 스타터 짐승 시드(2종 — 건물별 1마리)", m.ranch.count() == 2)
	# ★ [B1-a.1] 스타터 짐승은 소속 건물 실내 바닥(HOUSE)에 놓인다(진입 실내 — 방목 왕래는 B1-a.2).
	var all_indoor := true
	for at in m.ranch.animal_tiles():
		var bld: String = m.ranch.building_of(at)
		var room: Rect2i = m.NEOKURITGAN_RECT if bld == "넋우릿간" else (m.NEOKDUNGURI_RECT if bld == "넋둥우리" else Rect2i())
		if bld == "" or not room.has_point(at) or m._grid[at.y][at.x] != m.HOUSE:
			all_indoor = false
	_check("⑫ 스타터 짐승 전부 소속 건물 실내에 배치", all_indoor and m.ranch.count() > 0)
	# 종·건물 짝 정합(안개소=넋우릿간·노을닭=넋둥우리).
	var pair_ok := true
	for at in m.ranch.animal_tiles():
		var sp: String = m.ranch.species_at(at)
		var bld: String = m.ranch.building_of(at)
		if (sp == AnimalCatalog.HONBAEK_SO and bld != "넋우릿간") or (sp == AnimalCatalog.HONBAEK_DAK and bld != "넋둥우리"):
			pair_ok = false
	_check("⑫ 종·소속 건물 짝 정합(안개소=넋우릿간·노을닭=넋둥우리)", pair_ok)
	# 스타터 짐승에 급여 → advance → 산물 → 수집이 main 인벤토리로 이어지는지(루프 배선).
	var starter: Vector2i = m.ranch.animal_tiles()[0]
	m.ranch.feed(starter)
	m.ranch.advance_day()
	_check("⑫ 급여→advance 산물 생성", m.ranch.has_product(starter))
	var got: Dictionary = m.ranch.collect(starter)
	var pid: String = ItemCatalog.large_product_id(got["product_id"]) if bool(got["is_large"]) else str(got["product_id"])
	var before: int = m.inventory.count_of(pid)
	m.inventory.add_item(pid, 1, int(got["quality"]))
	_check("⑫ 수집 산물 인벤토리 적재", m.inventory.count_of(pid) == before + 1)
	m.queue_free()
	await process_frame
	# 백업 복원(있었으면).
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		if FileAccess.file_exists(BAK):
			DirAccess.remove_absolute(BAK)

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

const SAVE := "user://save.dat"
const BAK := "user://save.dat.livestock.bak"

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 크래프트 세이브용 짐승 상태 리터럴(우정·기분 임의 주입, 나머지 기본).
func _mk(species: String, friendship: int, mood: int) -> Dictionary:
	return {
		"species": species, "friendship": friendship, "mood": mood,
		"fed": false, "petted": false, "grazed": false, "penned": false, "cleaned": false,
		"product": 0, "product_quality": 0, "product_large": false,
	}
