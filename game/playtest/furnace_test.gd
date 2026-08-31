extends SceneTree
# ★[S5-T3 / ADR-0063 결정 3·6] 업화로(제련) + 주괴 4종 + 지오드 개봉 + 풀무 상주 검증(ephemeral).
#
# 무엇을 지키나(어기면 ADR-0063 결정 3 위반):
#   ① 업화로 제작 레시피(돌 25 + 명동 광석 20) · 상시 노출 · 아이템 등록
#   ② 투입 검증(광석 5 + 혼탄 1 · 부족하면 거부 = 부분 소모 0)
#   ③ 시간 진행·수거(**분 배선** — 원장 직접 + 취침 점프가 분 델타로 접히는지)
#   ④ 주괴 4종의 **품질 차원 존재**(자재 관례의 명시적 예외 — INGOTS 주석)
#   ⑤ 지오드 개봉 — 결정성 · 25냥 차감 · 2종 분포 상이 · 재롤 차단(카운터 시드)
#   ⑥ 세이브 왕복 · 하위호환(키 없는 구세이브 = 업화로 0)
#   ⑦ 풀무 상주(대장간 실내) · 대사 · 관계-중립(effect_fn 없음)
# 실행: godot --headless --path game --script res://playtest/furnace_test.gd

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

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 이 구역에서 업화로를 놓을 수 있는 첫 칸(없으면 (-1,-1)).
func _placeable_tile(m: Node) -> Vector2i:
	for y in range(2, m._outdoor_h - 2):
		for x in range(2, m._grid_w - 2):
			var t := Vector2i(x, y)
			if m._can_place_furnace(t):
				return t
	return Vector2i(-1, -1)

func _initialize() -> void:
	print("══ S5-T3 업화로 제련 + 주괴 + 지오드 개봉 + 풀무 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s5t3_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 아이템·레시피 등록 ──
	print("── ① 주괴 4종 · 업화로 아이템 · 제작 레시피 ──")
	var ingots := [ItemCatalog.INGOT_MYEONGDONG, ItemCatalog.INGOT_YUCHEOL,
		ItemCatalog.INGOT_HWANGCHEONGEUM, ItemCatalog.INGOT_NARAKCHEOL]
	var all_valid := true
	for id: String in ingots:
		if not ItemCatalog.has_item(id) or ItemCatalog.category_of(id) != ItemCatalog.CAT_MATERIAL \
				or not ItemCatalog.stackable_of(id) or ItemCatalog.name_of(id) == "":
			all_valid = false
	_check("①a 주괴 4종 = 유효 CAT_MATERIAL 스택 아이템(has_item·이름 있음)",
		all_valid and ItemCatalog.INGOTS.size() == 4)
	_check("①b 주괴 기준가 = 60/120/250/1000(스타듀 1:1)",
		ItemCatalog.price_of(ItemCatalog.INGOT_MYEONGDONG) == 60
		and ItemCatalog.price_of(ItemCatalog.INGOT_YUCHEOL) == 120
		and ItemCatalog.price_of(ItemCatalog.INGOT_HWANGCHEONGEUM) == 250
		and ItemCatalog.price_of(ItemCatalog.INGOT_NARAKCHEOL) == 1000)
	# id 교집합 0 — 광물·자재·채집물과 겹치지 않는다(has_item 판정이 조용히 다른 표로 새지 않게).
	var no_overlap := true
	for id: String in ingots:
		if ItemCatalog.MINERALS.has(id) or ItemCatalog.MATERIALS.has(id) or ItemCatalog.FORAGEABLES.has(id) \
				or ItemCatalog.PLACEABLES.has(id) or CropCatalog.has_crop(id):
			no_overlap = false
	_check("①c 주괴 id ↔ 광물·자재·채집물·설치물·작물 교집합 0", no_overlap)
	_check("①d 업화로 = 유효 CAT_PLACEABLE 아이템",
		ItemCatalog.has_item(ItemCatalog.FURNACE)
		and ItemCatalog.category_of(ItemCatalog.FURNACE) == ItemCatalog.CAT_PLACEABLE)
	var rec := CraftCatalog.get_recipe(CraftCatalog.FURNACE)
	_check("①e 제작 레시피 = 돌 25 + 명동 광석 20 → 업화로 1",
		not rec.is_empty() and String(rec["out_item"]) == ItemCatalog.FURNACE
		and int(rec["out_count"]) == 1 and rec["mats"].size() == 2
		and String(rec["mats"][0]["item"]) == ItemCatalog.STONE and int(rec["mats"][0]["count"]) == 25
		and String(rec["mats"][1]["item"]) == ItemCatalog.ORE_MYEONGDONG and int(rec["mats"][1]["count"]) == 20)
	_check("①f 레시피 상시 노출(채집 레벨 0에서도 해금 — 재료가 게이트)",
		CraftCatalog.unlocked(CraftCatalog.FURNACE, 0, {}))
	_check("①g 레시피 목록에 편입(제작 탭 첫 줄)", CraftCatalog.ids().has(CraftCatalog.FURNACE)
		and String(CraftCatalog.ids()[0]) == CraftCatalog.FURNACE)

	# ── ② 광석 → 주괴 매핑 · 제련 시간 · 투입 검증(순수 규칙) ──
	print("── ② 매핑 · 제련 시간 · 투입 게이트 ──")
	_check("②a 광석 4종 → 주괴 4종 1:1",
		FurnaceLedger.ingot_for(ItemCatalog.ORE_MYEONGDONG) == ItemCatalog.INGOT_MYEONGDONG
		and FurnaceLedger.ingot_for(ItemCatalog.ORE_YUCHEOL) == ItemCatalog.INGOT_YUCHEOL
		and FurnaceLedger.ingot_for(ItemCatalog.ORE_HWANGCHEONGEUM) == ItemCatalog.INGOT_HWANGCHEONGEUM
		and FurnaceLedger.ingot_for(ItemCatalog.ORE_NARAKCHEOL) == ItemCatalog.INGOT_NARAKCHEOL)
	_check("②b 광석이 아니면 제련 불가(돌·혼탄·보석·주괴)",
		not FurnaceLedger.is_smeltable(ItemCatalog.STONE)
		and not FurnaceLedger.is_smeltable(ItemCatalog.HONTAN)
		and not FurnaceLedger.is_smeltable(ItemCatalog.GEM_NEOKSUJEONG)
		and not FurnaceLedger.is_smeltable(ItemCatalog.INGOT_MYEONGDONG))
	_check("②c 제련 시간 = 30분 / 2시간 / 5시간 / 8시간(스타듀 1:1)",
		FurnaceLedger.smelt_minutes(ItemCatalog.ORE_MYEONGDONG) == 30
		and FurnaceLedger.smelt_minutes(ItemCatalog.ORE_YUCHEOL) == 120
		and FurnaceLedger.smelt_minutes(ItemCatalog.ORE_HWANGCHEONGEUM) == 300
		and FurnaceLedger.smelt_minutes(ItemCatalog.ORE_NARAKCHEOL) == 480)
	_check("②d 제련공 시간 −50% 훅(인자 자리 실동작)",
		FurnaceLedger.smelt_minutes(ItemCatalog.ORE_YUCHEOL, 0.5) == 60
		and FurnaceLedger.smelt_minutes(ItemCatalog.ORE_MYEONGDONG, 0.5) == 15)
	_check("②e 투입 규격 = 광석 5 + 혼탄 1",
		FurnaceLedger.ORE_PER_BATCH == 5 and FurnaceLedger.FUEL_PER_BATCH == 1
		and FurnaceLedger.FUEL_ITEM == ItemCatalog.HONTAN)
	# 원장 단독: 빈 화덕만 광석을 받고, 이미 든 화덕은 거부한다(재투입 차단).
	var led := FurnaceLedger.new()
	var t0 := Vector2i(3, 4)
	_check("②f 설치 = 멱등(같은 칸 중복 거부)",
		led.place("r", t0) and not led.place("r", t0) and led.count() == 1)
	_check("②g 빈 화덕 = idle(제련 중·완성 아님)",
		led.is_idle("r", t0) and not led.is_smelting("r", t0) and not led.is_ready("r", t0))
	_check("②h 제련 불가 아이템은 투입 거부", not led.load_ore("r", t0, ItemCatalog.STONE))
	_check("②i 명동 광석 투입 성공 → 30분 카운트다운",
		led.load_ore("r", t0, ItemCatalog.ORE_MYEONGDONG)
		and led.minutes_left("r", t0) == 30 and led.is_smelting("r", t0))
	_check("②j 이미 든 화덕은 재투입 거부(안 비운 업화로는 안 받는다)",
		not led.load_ore("r", t0, ItemCatalog.ORE_YUCHEOL) and led.minutes_left("r", t0) == 30)
	_check("②k 광석 든 화덕은 회수 거부(광석 증발 방지)", not led.remove("r", t0))

	# ── ③ 시간 진행 · 수거(분 배선) ──
	print("── ③ 분 진행 · 수거 ──")
	_check("③a 29분 경과 = 아직 안 익음(남은 1분)",
		led.advance_minutes(29.0).is_empty() and led.minutes_left("r", t0) == 1
		and led.is_smelting("r", t0))
	var ripe: Array = led.advance_minutes(1.0)
	_check("③b 30분째 완성 = 수거 대기(반환 목록 1건)",
		ripe.size() == 1 and String(ripe[0]["id"]) == ItemCatalog.INGOT_MYEONGDONG
		and led.is_ready("r", t0) and not led.is_smelting("r", t0))
	_check("③c 완성 뒤 더 흘려도 재발화 없음(카운트다운 정지)",
		led.advance_minutes(500.0).is_empty() and led.is_ready("r", t0))
	var got := led.collect("r", t0)
	_check("③d 수거 = 주괴 1 + 등급 · 화덕이 다시 빈다(수거가 곧 재가동)",
		String(got["id"]) == ItemCatalog.INGOT_MYEONGDONG and led.is_idle("r", t0)
		and led.collect("r", t0).is_empty())
	_check("③e 빈 화덕은 회수 가능", led.remove("r", t0) and led.count() == 0)
	# 큰 델타 하나(취침 점프 규모)로 긴 제련이 한 번에 끝난다 — 8시간 = 480분.
	var led2 := FurnaceLedger.new()
	led2.place("r", t0)
	led2.load_ore("r", t0, ItemCatalog.ORE_NARAKCHEOL)
	_check("③f 취침 점프 규모(480분) 한 번에 나락철 완성",
		led2.advance_minutes(480.0).size() == 1 and led2.is_ready("r", t0))
	# 정지·역행 방어.
	var led3 := FurnaceLedger.new()
	led3.place("r", t0)
	led3.load_ore("r", t0, ItemCatalog.ORE_YUCHEOL)
	_check("③g 0분·음수 진행은 무동작",
		led3.advance_minutes(0.0).is_empty() and led3.advance_minutes(-100.0).is_empty()
		and led3.minutes_left("r", t0) == 120)
	_check("③h 소수 분(0.4)은 진행 0(정수 분만 소비)",
		led3.advance_minutes(0.4).is_empty() and led3.minutes_left("r", t0) == 120)

	# ── ④ 주괴 품질 차원(자재 관례의 명시적 예외) ──
	print("── ④ 주괴 품질 차원 ──")
	_check("④a 광물은 품질 무차원(등급 배수 0)",
		ItemCatalog.price_of(ItemCatalog.ORE_MYEONGDONG, ItemCatalog.Q_GOLD)
			== ItemCatalog.price_of(ItemCatalog.ORE_MYEONGDONG, ItemCatalog.Q_NORMAL))
	_check("④b 주괴는 품질 유차원(금 = 기준가 ×1.5)",
		ItemCatalog.price_of(ItemCatalog.INGOT_MYEONGDONG, ItemCatalog.Q_GOLD) == 90
		and ItemCatalog.price_of(ItemCatalog.INGOT_YUCHEOL, ItemCatalog.Q_SILVER) == 150)
	_check("④c 제련공 품질 계단 훅 — 금에서 클램프(이리듐 미도달)",
		FurnaceLedger.quality_for(0) == ItemCatalog.Q_NORMAL
		and FurnaceLedger.quality_for(1) == ItemCatalog.Q_SILVER
		and FurnaceLedger.quality_for(9) == ItemCatalog.Q_GOLD)
	var led4 := FurnaceLedger.new()
	led4.place("r", t0)
	led4.load_ore("r", t0, ItemCatalog.ORE_MYEONGDONG, 0.0, 2)
	led4.advance_minutes(30.0)
	_check("④d 투입 시점 등급이 산출에 스냅샷된다",
		int(led4.collect("r", t0)["quality"]) == ItemCatalog.Q_GOLD)

	# ── ⑤ 지오드 개봉(결정성 · 분포 상이 · 재롤 차단) ──
	print("── ⑤ 지오드 개봉 ──")
	_check("⑤a 개봉 대상 = 알돌 2종만",
		MiningSkill.is_geode(ItemCatalog.GEODE_NEOKAL) and MiningSkill.is_geode(ItemCatalog.GEODE_EOPHWA)
		and not MiningSkill.is_geode(ItemCatalog.STONE)
		and not MiningSkill.is_geode(ItemCatalog.ORE_MYEONGDONG))
	_check("⑤b 개봉 수수료 = 25냥(클린트 1:1)", MiningSkill.GEODE_COST == 25)
	var a1 := MiningSkill.open_geode(ItemCatalog.GEODE_NEOKAL, 7)
	var a2 := MiningSkill.open_geode(ItemCatalog.GEODE_NEOKAL, 7)
	_check("⑤c 같은 카운터 = 같은 결과(결정성)",
		String(a1["id"]) == String(a2["id"]) and int(a1["count"]) == int(a2["count"]))
	# 같은 종을 카운터만 바꿔 100번 돌려 분포를 모은다(두 종의 품목 집합이 실제로 다른가).
	var set_neokal := {}
	var set_eophwa := {}
	var all_registered := true
	for i in 100:
		var rn := MiningSkill.open_geode(ItemCatalog.GEODE_NEOKAL, i)
		var re := MiningSkill.open_geode(ItemCatalog.GEODE_EOPHWA, i)
		set_neokal[String(rn["id"])] = true
		set_eophwa[String(re["id"])] = true
		if not ItemCatalog.has_item(String(rn["id"])) or not ItemCatalog.has_item(String(re["id"])):
			all_registered = false
	_check("⑤d 개봉 산출은 전부 유효 아이템(카탈로그 등록 — 유령 id 0)", all_registered)
	_check("⑤e 카운터가 다르면 결과 집합이 여러 종(재롤 아닌 새 롤)",
		set_neokal.size() >= 4 and set_eophwa.size() >= 4)
	_check("⑤f 두 종의 분포가 **실제로 다르다** — 넋알돌에만 돌, 업화알돌에만 황천금",
		set_neokal.has(ItemCatalog.STONE) and not set_eophwa.has(ItemCatalog.STONE)
		and set_eophwa.has(ItemCatalog.ORE_HWANGCHEONGEUM)
		and not set_neokal.has(ItemCatalog.ORE_HWANGCHEONGEUM))
	_check("⑤g 유품이 저확률로 섞인다(혼백관 기증 사슬)",
		set_neokal.has(ItemCatalog.RELIC_BINYEO) or set_neokal.has(ItemCatalog.RELIC_SPOON)
		or set_neokal.has(ItemCatalog.RELIC_KKOTSIN))

	# ── 라이브 배선(main) ──
	print("── ⑥ 라이브 배선(설치·투입·수거·개봉·세이브) ──")
	var m: Node = await _spawn_main()
	m._indoor = ""
	# 설치 — 안식 농원 빈 지면.
	var slot := _placeable_tile(m)
	_check("⑥a 설치 가능 칸이 존재(빈 지면·길)", slot != Vector2i(-1, -1))
	m.inventory.add_item(ItemCatalog.FURNACE, 1)
	m._place_furnace(slot)
	_check("⑥b 설치 = 원장 1기 + 아이템 1개 소모",
		m.furnace.has_at(m._region, slot) and m.inventory.count_of(ItemCatalog.FURNACE) == 0)
	_check("⑥c 같은 칸엔 두 번 못 놓는다(설치 판정 거부)", not m._can_place_furnace(slot))
	# 투입 — 재료 부족 거부(부분 소모 0).
	m.inventory.add_item(ItemCatalog.ORE_MYEONGDONG, 3)
	m._load_furnace(slot, ItemCatalog.ORE_MYEONGDONG)
	_check("⑥d 광석 부족(3/5) → 투입 거부 · 재료 소모 0",
		m.furnace.is_idle(m._region, slot) and m.inventory.count_of(ItemCatalog.ORE_MYEONGDONG) == 3)
	m.inventory.add_item(ItemCatalog.ORE_MYEONGDONG, 4)   # 총 7개
	m._load_furnace(slot, ItemCatalog.ORE_MYEONGDONG)
	_check("⑥e 혼탄 없음 → 투입 거부 · 광석 소모 0",
		m.furnace.is_idle(m._region, slot) and m.inventory.count_of(ItemCatalog.ORE_MYEONGDONG) == 7)
	m.inventory.add_item(ItemCatalog.HONTAN, 2)
	m._load_furnace(slot, ItemCatalog.ORE_MYEONGDONG)
	_check("⑥f 광석 5 + 혼탄 1 차감 → 제련 시작(30분)",
		m.furnace.is_smelting(m._region, slot) and m.furnace.minutes_left(m._region, slot) == 30
		and m.inventory.count_of(ItemCatalog.ORE_MYEONGDONG) == 2
		and m.inventory.count_of(ItemCatalog.HONTAN) == 1)
	# ★ 취침 점프 = 절대 분 델타로 접힌다. 실제 취침 연출을 타지 않고 clock을 직접 갈고 _tick을 부른다
	#   (연출 tween을 기다리지 않는 헤드리스 관례 — 배선하는 값은 완전히 같다).
	m.clock.minutes = 22.0 * 60.0
	m._furnace_abs_min = -1.0                       # 부팅 프레임이 잡아 둔 기준점을 버리고
	m._tick_furnaces()                              # 기준점을 22:00으로 다시 잡는다(진행 0)
	var before_left: int = m.furnace.minutes_left(m._region, slot)
	m.clock.day += 1
	m.clock.minutes = float(GameClock.START_MIN)    # 다음날 06:00 (= 밤 480분 경과)
	m._tick_furnaces()
	_check("⑥g 취침 점프(22:00 → 다음날 06:00 = 480분)로 제련 완료 — 밤에도 화덕이 돈다",
		before_left == 30 and m.furnace.is_ready(m._region, slot))
	var ing0: int = m.inventory.count_of(ItemCatalog.INGOT_MYEONGDONG)
	m._use_furnace(slot)
	_check("⑥h [F] 수거 = 명동 주괴 +1 · 화덕이 다시 빈다",
		m.inventory.count_of(ItemCatalog.INGOT_MYEONGDONG) == ing0 + 1
		and m.furnace.is_idle(m._region, slot))
	# 프롬프트가 상태를 밝힌다(빈 화덕 = 회수 안내).
	var pf: String = m._furnace_prompt(slot)
	_check("⑥i 빈 화덕 프롬프트 = 회수 안내", pf.contains("회수"))
	# 지오드 개봉 라이브 — 25냥 차감 · 알돌 1개 소모 · 카운터 +1.
	m.wallet.gold = 1000
	m.inventory.add_item(ItemCatalog.GEODE_NEOKAL, 2)
	var geo_slot: int = -1
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == ItemCatalog.GEODE_NEOKAL:
			geo_slot = i
	m.inventory.select(geo_slot)
	var gold0: int = m.wallet.gold
	var cnt0: int = m._geode_opened
	m._try_open_geode()
	_check("⑥j 개봉 = 25냥 차감 · 알돌 1개 소모 · 카운터 +1",
		m.wallet.gold == gold0 - MiningSkill.GEODE_COST
		and m.inventory.count_of(ItemCatalog.GEODE_NEOKAL) == 1
		and m._geode_opened == cnt0 + 1)
	m.wallet.gold = 10
	var cnt1: int = m._geode_opened
	m._try_open_geode()
	_check("⑥k 냥 부족이면 거부 — 알돌·카운터 불변",
		m.inventory.count_of(ItemCatalog.GEODE_NEOKAL) == 1 and m._geode_opened == cnt1)
	# 세이브 왕복 — 제련 중 상태가 그대로 복원된다.
	m.inventory.add_item(ItemCatalog.ORE_YUCHEOL, 5)
	m.inventory.add_item(ItemCatalog.HONTAN, 1)
	m._load_furnace(slot, ItemCatalog.ORE_YUCHEOL)
	var left_before: int = m.furnace.minutes_left(m._region, slot)
	var saved: Dictionary = m.furnace.to_save()
	var led5 := FurnaceLedger.new()
	led5.load_save(saved)
	_check("⑥l 세이브 왕복 — 좌표·광석·남은 분·주괴 보존",
		led5.has_at(m._region, slot) and led5.minutes_left(m._region, slot) == left_before
		and led5.ore_at(m._region, slot) == ItemCatalog.ORE_YUCHEOL
		and led5.product_at(m._region, slot) == ItemCatalog.INGOT_YUCHEOL)
	var led6 := FurnaceLedger.new()
	led6.place("r", t0)
	led6.load_save({})
	_check("⑥m 하위호환 — 키 없는 구세이브 = 업화로 0", led6.count() == 0)
	var led7 := FurnaceLedger.new()
	led7.load_save({"forges": {"r": [[2, 2, "잡동사니", "쓰레기", 999, 7]]}})
	_check("⑥n 손상 세이브 방어 — 화덕은 살고 내용만 비운다(설치물 손실 0)",
		led7.count() == 1 and led7.is_idle("r", Vector2i(2, 2)))

	# ── ⑦ 풀무 상주(대장간 실내) ──
	print("── ⑦ 풀무 점주 ──")
	var r: Resident = m._resident("pulmu")
	_check("⑦a 레코드 등록 · 노드 생성(main.tscn 무수정)", r != null and r.node != null)
	_check("⑦b 표시명 = 풀무 · 대장간 실내 게이트 · 갱도 구역",
		r != null and r.display_name == "풀무" and r.require_indoor == "대장간"
		and String(r.schedule[0]["region"]) == RegionCatalog.EOPHWA_MINE)
	_check("⑦c 자리가 대장간 실내 rect 안 · 모루 칸과 안 겹침",
		m.SMITHY_RECT.has_point(m.PULMU_TILE) and m.PULMU_TILE != m.SMITHY_UPGRADE_TILE)
	_check("⑦d 관계 트랙 있음(선물·하트) + **effect_fn 없음**(관계-중립 — 매대 할인 0)",
		r != null and r.affinity != null and r.can_gift and not r.effect_fn.is_valid())
	var lines0: PackedStringArray = r.node.lines(0, true)
	var lines5: PackedStringArray = r.node.lines(5, true)
	var again: PackedStringArray = r.node.lines(0, false)
	_check("⑦e 대사 = 하트 단계별 묶음 + 재대화 1줄",
		lines0.size() >= 3 and lines5.size() >= 3 and again.size() == 1
		and String(lines0[0]) != String(lines5[0]))
	var joined := " ".join(lines0) + " " + " ".join(lines5)
	_check("⑦f 속죄·심판 어휘 없음(T2 라이트 플레이버 — ADR-0004/0005 경계)",
		not joined.contains("속죄") and not joined.contains("죄") and not joined.contains("심판"))
	_check("⑦g '저승'을 날것으로 부르지 않는다(주민 톤 정합)", not joined.contains("저승"))
	await _despawn(m)

	await _part_r2()

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)

# ══ [폴리시 R2] 던전 층 가드 — 유령 설치물 · 보이지 않는 [F] ═════════════════
# 두 결함이 같은 뿌리다: 층(갱도 층·나락 런 층)은 지상과 **구역 id를 공유하고 좌표 공간도 겹치는데**
# 설치물 원장은 층·깊이를 키로 갖지 않는다. 그래서
#   ⑫ 나락 런 층에 설치가 성립했고(원장 주석이 "유령 화덕"이라 부른 그 사고가 나락에서 재현),
#   ⑬ 층 안에서 지상 좌표를 겨눈 [F]가 보이지도 않는 지상 설비를 조작했다.
# 배치·드로우가 이미 보던 축(`_mine_floor`)에 `_narak_depth`를 합류시키고, [F] 디스패치에 그 둘을
# 세운다 — 세 창구(놓기·그리기·만지기)가 같은 술어를 본다.
func _part_r2() -> void:
	print("── ⑫⑬ [폴리시 R2] 던전 층 배치·[F] 가드 ──")
	var m: Node = await _spawn_main()

	# ── ⑫ 나락 런 층 배치 금지 ──
	# 원장은 깊이를 키로 갖지 않으므로, 층에 세운 화덕은 다른 모든 깊이와 런 종료 뒤 아레나에까지
	# 같은 좌표로 떠 있었다(그 칸이 봉인 고리 암반이면 회수 불가 = 화덕 + 안의 광석 영구 유실).
	# 판정은 **같은 칸**을 깊이만 바꿔 가며 묻는다 — 갈리는 축이 깊이 하나임이 그대로 보인다.
	m._rebuild_region(RegionCatalog.NARAK)
	m._mine_floor = 0
	m._narak_depth = 0
	m._indoor = ""
	await _settle_frames()
	var arena := _placeable_tile(m)
	_check("⑫a 나락 **아레나**(깊이 0)에는 종전대로 놓을 수 있다(거동 불변)",
		arena != Vector2i(-1, -1))
	m._narak_depth = 1
	_check("⑫b **런 층 안에서는 같은 칸도 막힌다** — 업화로·결정기 둘 다",
		not m._can_place_furnace(arena) and not m._can_place_crystalarium(arena))
	m._narak_depth = 7
	_check("⑫c 깊이가 얼마든 같다(원장이 깊이를 안 들기 때문)",
		not m._can_place_furnace(arena) and not m._can_place_crystalarium(arena))
	m._narak_depth = 0
	_check("⑫d 런이 끝나 아레나로 나오면 다시 놓을 수 있다",
		m._can_place_furnace(arena) and m._can_place_crystalarium(arena))

	# ── ⑬ 층 안에서 지상 설비 [F] 금지 ──
	# 갱도로 옮겨 지상에 화덕·결정기를 세우고, 같은 좌표를 층 안에서 겨눈다. [F] 디스패치와
	# 프롬프트가 모두 이 술어 하나를 보므로(둘의 불일치 0), 술어를 직접 맞대어 본다.
	m._narak_depth = 0
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	m._mine_floor = 0
	await _settle_frames()
	var ground := _placeable_tile(m)
	_check("⑬pre 갱도 지상 설치 칸 확보", ground != Vector2i(-1, -1))
	var gem_tile := ground + Vector2i(1, 0)
	m.furnace.place(m._region, ground)
	m.crystalarium.place(m._region, gem_tile)
	_check("⑬a 지상에서는 [F]가 걸린다(종전 거동 그대로)",
		m._furnace_at(ground) and m._crystalarium_at(gem_tile))
	m._mine_floor = 1                       # ★ 층으로 내려간 상태만 재현(구역 id·좌표는 그대로)
	_check("⑬b **갱도 층 안에서는 안 걸린다** — 원장은 여전히 그 좌표를 아는데도",
		not m._furnace_at(ground) and not m._crystalarium_at(gem_tile)
		and m.furnace.has_at(m._region, ground))
	m._mine_floor = 0
	m._narak_depth = 3                      # ★ 나락 런 층도 같은 구조(구역 id 공유 + 깊이만 갈림)
	_check("⑬c **나락 런 층 안에서도 안 걸린다**(같은 축을 함께 본다)",
		not m._furnace_at(ground) and not m._crystalarium_at(gem_tile))
	m._narak_depth = 0
	m._indoor = "대장간"
	_check("⑬d 실내에서도 안 걸린다(종전 가드 보존)",
		not m._furnace_at(ground) and not m._crystalarium_at(gem_tile))
	m._indoor = ""
	_check("⑬e 지상으로 돌아오면 다시 걸린다 — 설비도 원장도 무손상",
		m._furnace_at(ground) and m._crystalarium_at(gem_tile))
	await _despawn(m)

func _settle_frames() -> void:
	await process_frame
	await process_frame
