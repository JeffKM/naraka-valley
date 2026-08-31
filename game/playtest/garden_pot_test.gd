extends SceneTree
# ★[S10-T5 / ADR-0069 결정 8] 화분(최소형) 단위검증.
#
# 이 스위트의 본론은 **온실과의 차별 자구 넷**이다(카탈로그 §2-6 · ADR-0069 결정 8):
#   ㉠ 절기 무시 — 절기 전환 아침에 비제철 작물도 안 스러진다
#   ㉡ 매일 손 물주기 — 아침마다 마르고, 젖은 화분만 자란다
#   ㉢ 스프링클러 불가 — 급수 사슬이 화분에 닿는 경로가 **코드에 없다**
#   ㉣ [혼의 나무] 불가 — plant가 작물만 받고, 묘목 동사는 실내에서 아예 안 뜬다
# 넷 다 "가드로 막았나"가 아니라 **구조로 성립하나**를 본다(garden_pot.gd 머리말).
# 실행: godot --headless --path game --script res://playtest/garden_pot_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	return m

# 든 아이템 선택(없으면 인벤 넣고 그 슬롯 선택 — sprinkler_test 결).
func _select(m: Node, id: String) -> void:
	if not m.inventory.has_item(id):
		m.inventory.add_item(id, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

func _dismiss_intro(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S10-T5 화분(최소형) 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ═══ ① 아이템·레시피 — 획득 경로(제작) ═══
	_check("① 화분이 설치물 아이템으로 등록", ItemCatalog.has_item(ItemCatalog.GARDEN_POT))
	_check("①b 카테고리 = 설치물(스프링클러·채취기와 같은 칸)",
		ItemCatalog.category_of(ItemCatalog.GARDEN_POT) == ItemCatalog.CAT_PLACEABLE)
	_check("①c 표시명 = 화분", ItemCatalog.name_of(ItemCatalog.GARDEN_POT) == "화분")
	_check("①d 제작 레시피가 있다(획득 경로 = 제작 — 잠정)", CraftCatalog.has(CraftCatalog.GARDEN_POT))
	_check("①e 레시피 산출 = 화분 1개",
		String(CraftCatalog.get_recipe(CraftCatalog.GARDEN_POT)["out_item"]) == ItemCatalog.GARDEN_POT)
	_check("①f 상시 노출(해금 계단 0 — 실내 소품에 채집 레벨을 안 문다)",
		CraftCatalog.unlocked(CraftCatalog.GARDEN_POT, 0, {}))
	_check("①g 제작 탭 목록에 있다", CraftCatalog.GARDEN_POT in CraftCatalog.ids())
	# 비-가치 원칙: 산출 잔가가 재료 원가를 넘지 않는다(ADR-0052).
	var mats_price := 0
	for mmat in CraftCatalog.get_recipe(CraftCatalog.GARDEN_POT)["mats"]:
		mats_price += ItemCatalog.price_of(String(mmat["item"]), 0) * int(mmat["count"])
	_check("①h 산출 잔가 < 재료 원가(만들어 팔기가 차익이 안 된다 — ADR-0052)",
		ItemCatalog.price_of(ItemCatalog.GARDEN_POT, 0) < mats_price)

	# ═══ ② 원장 계약 — 배치·심기·물주기·수확 ═══
	var pot := GardenPot.new()
	var t := Vector2i(11, 70)
	_check("② 빈 화분을 놓는다", pot.place(t) and pot.has_at(t))
	_check("②b 같은 칸에 두 번 못 놓는다(멱등)", not pot.place(t))
	_check("②c 놓은 직후엔 빈 화분", not pot.is_planted(t) and pot.crop_of(t) == "")
	_check("②d 화분 없는 칸엔 못 심는다", not pot.plant(Vector2i(99, 99), CropCatalog.HONRYEONGCHO))
	_check("②e 화분에 작물을 심는다", pot.plant(t, CropCatalog.HONRYEONGCHO))
	_check("②f 이미 심긴 화분엔 못 심는다", not pot.plant(t, CropCatalog.HONRYEONGCHO))
	_check("②g 심은 직후엔 안 젖었다", not pot.is_watered(t))
	_check("②h 손 물주기가 든다", pot.water(t) and pot.is_watered(t))
	_check("②i 하루 두 번은 못 준다(멱등)", not pot.water(t))
	pot.free()

	# ═══ ③ ㉣ [혼의 나무] 불가 — 원장이 작물만 받는다 ═══
	var pot2 := GardenPot.new()
	pot2.place(t)
	var sapling_fruit: String = String(FruitTreeCatalog.ids()[0])
	_check("③ ㉣ 과수 종 id는 화분에 안 심긴다(CropCatalog 검증만 통과 — 구조로 배제)",
		not pot2.plant(t, sapling_fruit))
	_check("③b 화분엔 비료 API 자체가 없다(최소형)", not pot2.has_method("fertilize"))
	_check("③c ㉢ 화분엔 sprinkle API 자체가 없다(급수 사슬이 닿을 경로 0)",
		not pot2.has_method("sprinkle"))
	pot2.free()

	# ═══ ④ ㉡ 매일 손 물주기 — 젖은 것만 자라고, 아침마다 전부 마른다 ═══
	var pot3 := GardenPot.new()
	var a := Vector2i(11, 70)
	var b := Vector2i(12, 70)
	pot3.place(a)
	pot3.place(b)
	pot3.plant(a, CropCatalog.HONRYEONGCHO)
	pot3.plant(b, CropCatalog.HONRYEONGCHO)
	pot3.water(a)   # a만 물을 준다
	pot3.advance_day()
	_check("④ 물 준 화분만 자란다", pot3.grown_days_of(a) == 1)
	_check("④b 물 안 준 화분은 안 자란다", pot3.grown_days_of(b) == 0)
	_check("④c ㉡ 아침이면 **전부 마른다**(매일 손이 가야 한다)",
		not pot3.is_watered(a) and not pot3.is_watered(b))
	# 성숙까지 굴려 수확 → 빈 화분으로 되돌아간다(되자람 없음 — 최소형).
	var need := CropCatalog.growth_days(CropCatalog.HONRYEONGCHO)
	for i in need:
		pot3.water(a)
		pot3.advance_day()
	_check("④d 물을 매일 주면 성숙한다", pot3.is_mature(a))
	_check("④e 성숙 전엔 수확 불가", pot3.harvest(b) == "")
	_check("④f 수확하면 작물 id를 돌려준다", pot3.harvest(a) == CropCatalog.HONRYEONGCHO)
	_check("④g 수확 후엔 **빈 화분**으로 남는다(화분은 안 사라진다)",
		pot3.has_at(a) and not pot3.is_planted(a))
	_check("④h 회수하면 자라던 것도 함께 사라진다",
		pot3.remove(b) and not pot3.has_at(b))
	pot3.free()

	# ═══ ⑤ 세이브 라운드트립 + 손상 세이브 방어 ═══
	var pot4 := GardenPot.new()
	pot4.place(a)
	pot4.plant(a, CropCatalog.HONRYEONGCHO)
	pot4.water(a)
	pot4.advance_day()
	var blob := pot4.to_save()
	var pot5 := GardenPot.new()
	pot5.load_save(blob)
	_check("⑤ 세이브 왕복 — 화분·작물·자란 날이 보존",
		pot5.has_at(a) and pot5.crop_of(a) == CropCatalog.HONRYEONGCHO
		and pot5.grown_days_of(a) == pot4.grown_days_of(a))
	var pot6 := GardenPot.new()
	pot6.load_save({})
	_check("⑤b 키 없는 구세이브 = 화분 0(하위호환)", pot6.count() == 0)
	var pot7 := GardenPot.new()
	pot7.load_save({"pots": [[3, 4, "no_such_crop", true, 5]]})
	_check("⑤c 모르는 작물 id는 조용히 빈 화분으로(손상 세이브 방어)",
		pot7.has_at(Vector2i(3, 4)) and not pot7.is_planted(Vector2i(3, 4)))
	pot4.free()
	pot5.free()
	pot6.free()
	pot7.free()

	# ═══ ⑥ main 통합 — 실내 배치 규칙 · 동사 · 수확 산출 ═══
	var m: Node = await _new_main()
	_dismiss_intro(m)
	m.clock.minutes = 10 * 60
	var house_tile := Vector2i(11, 72)   # 홈 집 실내 바닥(HOME_HOUSE_RECT 안)
	m._indoor = ""
	_check("⑥ 바깥에선 화분을 못 놓는다(실내 소품)", not m._can_place_pot(house_tile))
	m._indoor = "집"
	_check("⑥b 집 안 바닥엔 놓을 수 있다", m._can_place_pot(house_tile))
	_check("⑥c 벽엔 못 놓는다",
		not m._can_place_pot(Vector2i(m.HOME_HOUSE_RECT.position.x, m.HOME_HOUSE_RECT.position.y + 3)))
	m.inventory.add_item(ItemCatalog.GARDEN_POT, 2)
	m._target = house_tile
	m._place_garden_pot(house_tile)
	_check("⑥d 놓으면 원장에 서고 아이템이 1개 준다",
		m.garden_pot.has_at(house_tile) and m.inventory.count_of(ItemCatalog.GARDEN_POT) == 1)
	_check("⑥e 화분이 선 칸엔 또 못 놓는다", not m._can_place_pot(house_tile))
	# 프롬프트가 화분을 인지한다(_target_valid=false인 실내 마룻바닥에서도).
	_check("⑥f 화분 프롬프트가 밭 게이트(_target_valid) 없이도 뜬다",
		m._pot_prompt().contains("화분"))
	# 심기·물주기·수확을 main 동사로 굴린다.
	# ★_select가 없으면 1개를 넣고 그 슬롯을 고른다 — 여기서 따로 add_seed를 부르면 2개가 되어
	#   "심으면 1개 소모"를 못 본다(⑥h가 그 소모를 단언한다).
	_select(m, ItemCatalog.seed_id(CropCatalog.HONRYEONGCHO))
	# ★신규 시작 인벤엔 스타터 씨앗이 이미 들어 있다 — "0이 됐나"가 아니라 **1 줄었나**를 본다.
	var seeds_before: int = m.inventory.seed_count(CropCatalog.HONRYEONGCHO)
	m._use_tool()
	_check("⑥g 씨앗을 들고 좌클릭 → 화분에 심긴다",
		m.garden_pot.crop_of(house_tile) == CropCatalog.HONRYEONGCHO)
	_check("⑥h 씨앗이 정확히 1개 소모됐다",
		m.inventory.seed_count(CropCatalog.HONRYEONGCHO) == seeds_before - 1)
	_select(m, ItemCatalog.WATERING_CAN)
	m._can_water = 5
	m._use_tool()
	_check("⑥i 물뿌리개 좌클릭 → 화분이 젖는다", m.garden_pot.is_watered(house_tile))
	_check("⑥j 물이 한 칸치만 든다(칸당 −1)", m._can_water == 4)
	# 성숙까지 아침을 굴린다 — 매일 물을 줘야 자란다.
	var pneed := CropCatalog.growth_days(CropCatalog.HONRYEONGCHO)
	for d in pneed:
		m.garden_pot.water(house_tile)
		m._on_day_advanced(m.clock.day + d + 1)
	_check("⑥k 매일 물을 주면 화분 작물이 성숙한다", m.garden_pot.is_mature(house_tile))
	var inv_before: int = m.inventory.count_of(ItemCatalog.harvest_id(CropCatalog.HONRYEONGCHO))
	var harvested_before: int = m._run_harvested
	m._try_harvest()
	_check("⑥l 우클릭 수확 → 수확물이 들어온다(노지와 같은 문법)",
		m.inventory.count_of(ItemCatalog.harvest_id(CropCatalog.HONRYEONGCHO)) > inv_before)
	_check("⑥m 수확 점수판(_run_harvested)도 오른다", m._run_harvested == harvested_before + 1)
	_check("⑥n 수확 후 빈 화분으로 남는다",
		m.garden_pot.has_at(house_tile) and not m.garden_pot.is_planted(house_tile))

	# ═══ ⑦ ㉢ 스프링클러 불가 — 배치 배제 + 아침 급수 미도달 ═══
	m.garden_pot.plant(house_tile, CropCatalog.HONRYEONGCHO)
	_check("⑦ 화분이 선 칸엔 스프링클러를 못 세운다(겹침 방지)",
		not m._can_place_sprinkler(house_tile))
	# 화분 바로 옆에 스프링클러를 억지로 세워도(원장 직접 조작) 화분엔 물이 안 든다.
	m.sprinkler.place(house_tile + Vector2i(1, 0))
	m._on_day_advanced(m.clock.day + 50)
	_check("⑦b ㉢ 인접 스프링클러가 돌아도 화분은 안 젖는다(급수 사슬이 화분을 모른다)",
		not m.garden_pot.is_watered(house_tile))
	_check("⑦c 그래서 물 안 준 화분은 그날 안 자란다", m.garden_pot.grown_days_of(house_tile) == 0)

	# ═══ ⑧ ㉠ 절기 무시 — 절기 전환 아침에 비제철 작물도 안 스러진다 ═══
	var next_season: int = (GameClock.season_index_for_day(m.clock.day) + 1) % 4
	var off_crop := ""
	for cid in CropCatalog.ids():
		var c := String(cid)
		if CropCatalog.is_multi_seasonal(c) or CropCatalog.is_wild(c):
			continue
		if not CropCatalog.in_season(c, next_season):
			off_crop = c
			break
	m.garden_pot.harvest(house_tile)
	m.garden_pot.remove(house_tile)
	m.garden_pot.place(house_tile)
	_check("⑧ 대조군 작물을 찾았다", off_crop != "")
	_check("⑧b ㉠ 절기와 무관하게 심긴다(in_season 게이트 없음)",
		m.garden_pot.plant(house_tile, off_crop))
	var next_first: int = m.clock.day + (GameClock.DAYS_PER_SEASON - GameClock.day_of_season(m.clock.day) + 1)
	m.clock.day = next_first
	m._on_day_advanced(next_first)
	_check("⑧c ㉠ 절기 전환 아침에도 화분 작물은 **살아남는다**",
		m.garden_pot.is_planted(house_tile) and m.garden_pot.crop_of(house_tile) == off_crop)

	# ═══ ⑩ ★[폴리시] 배치 범위 = 안식 농원 실내(구역 네임스페이스) ═══
	# 화분 원장은 좌표만 키로 들고(구역 축 없음) 실내 밴드 좌표는 구역끼리 겹친다. 그래서 배치를
	# ADR-0069 결정 8이 든 자리("집·늘봄방" = 둘 다 HOME)로 좁히지 않으면, 다른 구역 실내에 놓은
	# 화분이 그 방에서는 안 보이고(그리기는 HOME에서만) 안식 농원 쪽에 유령으로 서서 원격으로
	# 심기·물주기·수확까지 먹힌다. 여기서 보는 건 그 두 방향 모두다.
	_select(m, ItemCatalog.GARDEN_POT)            # 화분을 든 채로 물어야 배치 안내가 뜬다
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	m._indoor = "만물상"
	var store_tile: Vector2i = m.STORE_IN_TILE   # 만물상 진입 착지 = 방 안 바닥(걷기 O)
	_check("⑩ 전제 — 만물상 실내 · 그 칸은 밟을 수 있는 바닥 · 화분을 들고 있다",
		m._region == RegionCatalog.NARU_VILLAGE
		and not m.is_solid(m._grid[store_tile.y][store_tile.x])
		and m.inventory.selected_id() == ItemCatalog.GARDEN_POT)
	_check("⑩b ★다른 구역 실내엔 못 놓는다(스프링클러의 HOME 가드와 같은 결)",
		not m._can_place_pot(store_tile))
	m._target = store_tile
	_check("⑩c 배치 안내도 안 뜬다(설치 동사가 그 방에선 아예 없다)",
		not m._pot_prompt().contains("화분 놓기"))
	# 실내이기만 하면 통과하던 옛 술어와의 대조 — 같은 칸이 '실내·비-SOLID·빈 칸' 조건은 다 만족한다.
	_check("⑩d 막은 축은 정확히 구역 하나다(실내 여부·바닥·빈 칸은 전부 만족)",
		m._indoor != "" and not m.garden_pot.has_at(store_tile)
		and not m._field_at(store_tile).is_tilled(store_tile))
	# 역방향 — 안식 농원 집에 선 화분을 **다른 구역에서 같은 좌표로** 만질 수 없다.
	m._target = house_tile
	_check("⑩e ★HOME 화분이 다른 구역에서는 원장 질의에 안 잡힌다(원격 조작 차단)",
		m.garden_pot.has_at(house_tile) and not m._pot_at(house_tile))
	_check("⑩f 그 칸 화분 프롬프트도 비어 있다", m._pot_prompt() == "")
	_select(m, ItemCatalog.WATERING_CAN)
	m._can_water = 5
	var wet_before: bool = m.garden_pot.is_watered(house_tile)
	m._use_tool()
	_check("⑩g 다른 구역에서 물뿌리개를 휘둘러도 HOME 화분은 안 젖는다",
		m.garden_pot.is_watered(house_tile) == wet_before)
	# 대조군 — 안식 농원으로 돌아오면 같은 칸이 그대로 다시 화분이다(가드가 기능을 안 죽였다).
	m._rebuild_region(RegionCatalog.HOME)
	m._indoor = "집"
	_check("⑩h 대조군 — 안식 농원 실내로 돌아오면 그 화분을 다시 만진다",
		m._pot_at(house_tile) and m._pot_prompt() != "")

	# ═══ ⑨ main 세이브 — 신규 슬라이스 키 + 구세이브 무손상 ═══
	m._save_game()
	var save_blob: Dictionary = cleaner.load_game()
	_check("⑨ 세이브에 garden_pot 슬라이스 키가 있다", save_blob.has("garden_pot"))
	m.free()
	var m2: Node = await _new_main()
	_check("⑨b 재개하면 화분과 그 안의 작물이 복원된다",
		m2.garden_pot.has_at(house_tile) and m2.garden_pot.crop_of(house_tile) == off_crop)
	m2._save_game()
	var old_blob: Dictionary = cleaner.load_game()
	old_blob.erase("garden_pot")
	cleaner.save_game(old_blob)
	m2.free()
	var m3: Node = await _new_main()
	_check("⑨c 구세이브(키 없음) 로드 — 화분 0·무손상", m3.garden_pot.count() == 0)
	m3.free()

	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
