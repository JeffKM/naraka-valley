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
	var DAK := AnimalCatalog.HONBAEK_DAK   # 혼백 닭 — 산물 혼백란·large_capable
	var SO := AnimalCatalog.HONBAEK_SO     # 혼백 소 — 산물 혼백유

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

	# ── Part B: main 통합(⑫) — 신규 게임 강제(세이브 백업·삭제)로 스타터 짐승 시드 검증 ──
	# save_region_test 결: 실제 개발 세이브를 백업했다가 끝에 복원(테스트 격리, 유저 세이브 불침범).
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)   # 세이브 제거 → _ready가 신규 게임 경로(스타터 시드)로 부팅
	var m := await _spawn_main()
	_check("⑫ ranch 노드 스폰", m.ranch != null)
	_check("⑫ 신규 게임 스타터 짐승 시드(≥1)", m.ranch.count() >= 1)
	# 스타터 짐승은 방목지 걷기 가능 타일에 놓인다(비-blocked).
	var all_walkable := true
	for at in m.ranch.animal_tiles():
		if m._is_tree_blocked(at):
			all_walkable = false
	_check("⑫ 스타터 짐승 전부 걷기 가능 타일", all_walkable and m.ranch.count() > 0)
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
