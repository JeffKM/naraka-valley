extends SceneTree
# ★[S4-T7 / ADR-0062 결정 7] 목공방 — 건축 의뢰 원장·매대·점주 옹이 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ⓐ 카탈로그 정합 — 성장 티어 2건뿐(집 업그레이드 3단계 = 서랍) · 스타듀 Big Coop/Big Barn
#      1:1 수치(10,000/400/2 · 12,000/450/2) · 프로젝트 ↔ Ranch 건물 매핑.
#   ⓑ 옹이 = Resident T2 — 레지스트리·목공방 실내 자리·점주/관계 두 레이어·대화·선물·
#      **main.tscn 무수정**(레코드가 노드를 낳는다).
#   ⓒ 지불 — 골드+원목 **둘 다** 즉시 차감 · 어느 한쪽이라도 모자라면 **아무것도 소모 안 함** ·
#      동시 진행 1건(다른 프로젝트도 잠김) · 완공분 재의뢰 거절.
#   ⓓ 완공 — 정확히 N일째 아침 · day 비교 결정적(RNG 0) · 완공 시 Ranch 티어 승격.
#   ⓔ 정원 실효 — 기본 4마리에서 막히고 승격 후 8마리까지(스타듀 4→8 비율) · 세이브 보존.
#   ⓕ 매대 — 가구 세트 골드 해금(재료 게이트 0·스타터는 비매) · 원목 소매(판매가 2배) ·
#      ♡ 할인이 **골드에만** 붙고 원목 요구량엔 안 붙는다 · 네오·뱃사공 ♡와 완전 독립.
#   ⓖ 세이브 왕복·하위호환 — 진행 의뢰·완공 이력·건물 티어 보존 · carpenter 키 없는 구세이브 무해.
#
# 실행: ./run_tests.sh carpenter   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame
	return m

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

# 옹이를 지금 마주 본 상태로 만든다(저승 숲 목공방 실내 + 그의 칸을 겨눔).
func _face_ongi(m: Node, r: Resident) -> void:
	m._region = RegionCatalog.JEOSEUNG_FOREST
	m._sleeping = false
	m._indoor = "목공방"
	m._update_resident_stations(0.0)
	m._target = r.tile

# 대화창을 끝까지 넘겨 닫는다(플레이어 조작과 같은 경로).
func _close_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 48:
		m.dialogue.advance()
		guard += 1
	m.player.set_physics_process(true)

# 하루를 넘긴다(취침 연출 없이 day advance 훅만 — 완공 판정의 실경로).
func _pass_day(m: Node) -> void:
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)

# 지갑·원목을 정확히 맞춘다(구매력 시나리오 셋업).
func _stock(m: Node, gold: int, wood: int) -> void:
	m.wallet.gold = gold
	var have: int = m.inventory.count_of(ItemCatalog.WOOD)
	if have > wood:
		m.inventory.remove_item(ItemCatalog.WOOD, have - wood)
	elif have < wood:
		m.inventory.add_item(ItemCatalog.WOOD, wood - have)

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S4-T7 목공방(건축 의뢰·매대·옹이) 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ⓐ 카탈로그 정합(원장 무의존 — static) ──
	print("── ⓐ 카탈로그 ──")
	# ★[S8-T7] 로스터 3건 — 성장 티어 2건 + 안방 확장(결혼 조건 "배우자 방" — 서랍의 이행).
	_check("ⓐa 로스터 = 성장 티어 2건 + 안방 확장(주방 업그레이드 = 서랍 유지)",
		Carpenter.ids().size() == 3
		and Carpenter.has_project(Carpenter.PROJ_BIG_COOP)
		and Carpenter.has_project(Carpenter.PROJ_BIG_BARN)
		and Carpenter.has_project(Carpenter.PROJ_MASTER_ROOM))
	_check("ⓐa′ 안방 확장 = 10,000냥 · 원목 300 · 2일 · Ranch 무관(building 없음)",
		Carpenter.gold_cost(Carpenter.PROJ_MASTER_ROOM) == 10000
		and Carpenter.wood_cost(Carpenter.PROJ_MASTER_ROOM) == 300
		and Carpenter.build_days(Carpenter.PROJ_MASTER_ROOM) == 2
		and Carpenter.building_of(Carpenter.PROJ_MASTER_ROOM) == "")
	_check("ⓐb 큰 넋둥우리 = 스타듀 Big Coop 1:1(10,000냥 · 원목 400 · 2일)",
		Carpenter.gold_cost(Carpenter.PROJ_BIG_COOP) == 10000
		and Carpenter.wood_cost(Carpenter.PROJ_BIG_COOP) == 400
		and Carpenter.build_days(Carpenter.PROJ_BIG_COOP) == 2)
	_check("ⓐc 큰 넋우릿간 = 스타듀 Big Barn 1:1(12,000냥 · 원목 450 · 2일)",
		Carpenter.gold_cost(Carpenter.PROJ_BIG_BARN) == 12000
		and Carpenter.wood_cost(Carpenter.PROJ_BIG_BARN) == 450
		and Carpenter.build_days(Carpenter.PROJ_BIG_BARN) == 2)
	_check("ⓐd 프로젝트 → Ranch 건물 매핑(넋둥우리·넋우릿간)",
		Carpenter.building_of(Carpenter.PROJ_BIG_COOP) == "넋둥우리"
		and Carpenter.building_of(Carpenter.PROJ_BIG_BARN) == "넋우릿간")
	_check("ⓐe 표시명 한국어 · 미지 프로젝트 방어",
		Carpenter.name_of(Carpenter.PROJ_BIG_COOP) == "큰 넋둥우리"
		and not Carpenter.has_project("big_house")
		and Carpenter.gold_cost("big_house") == 0 and Carpenter.name_of("big_house") == "")
	# 순수 원장(main 무의존) — 동시 1건·완공 판정이 day 하나로 닫힌다.
	var solo := Carpenter.new()
	_check("ⓐf 새 원장 = 진행 0·완공 0", not solo.is_active() and solo.done_ids().is_empty())
	_check("ⓐg 주문 → 예정일 = day + days", solo.order(Carpenter.PROJ_BIG_COOP, 5)
		and solo.due_day() == 7 and solo.days_left(5) == 2)
	_check("ⓐh 진행 중엔 어느 프로젝트도 못 건다",
		not solo.can_order(Carpenter.PROJ_BIG_BARN) and not solo.order(Carpenter.PROJ_BIG_BARN, 5))
	_check("ⓐi 예정일 전엔 완공 없음", solo.advance_day(6) == "" and solo.is_active())
	_check("ⓐj 예정일에 완공 · 이력 기록 · 진행 해제",
		solo.advance_day(7) == Carpenter.PROJ_BIG_COOP
		and solo.is_done(Carpenter.PROJ_BIG_COOP) and not solo.is_active())
	_check("ⓐk 완공분은 재의뢰 불가", not solo.can_order(Carpenter.PROJ_BIG_COOP))

	var m: Node = await _new_main()

	# ── ⓑ 옹이 = Resident T2 ──
	print("── ⓑ 옹이(T2 점주) ──")
	var r: Resident = m._resident("ongi")
	_check("ⓑa 레지스트리에 등록", r != null)
	_check("ⓑb 표시명 = 옹이", r != null and r.display_name == "옹이")
	_check("ⓑc 몸이 런타임 생성돼 트리에 붙는다(main.tscn 무수정)",
		r.node != null and r.node.is_inside_tree() and r.node is Ongi)
	_check("ⓑd 신규 세이브 키(구세이브엔 없음 = ♡0 시작)", r.save_key == "ongi_affinity")
	_check("ⓑe 관계 트랙 보유 · 선물 채널 있음(T2 사귐)", r.affinity != null and r.can_gift)
	# ★[S4-T10] 아트 패스 2가 도트 초상화를 붙여 단언을 **뒤집었다**(옛 단언 = "초상화 없음").
	#   표정 파일은 안 만든다 — `_set_portrait`가 없으면 idle로 떨어지므로 idle 한 장이 계약이다.
	_check("ⓑf 도트 초상화 배선(S4-T10 스톱갭 — idle 한 장)",
		r.portrait_stem == "ongi" and ResourceLoader.exists("res://assets/portraits/ongi.png"))
	_check("ⓑg 상시 영업(스케줄 1항목) · 자리 = 목공방 카운터 뒤",
		r.schedule.size() == 1 and r.tile == m.ONGI_TILE
		and m.WOODSHOP_RECT.has_point(m.ONGI_TILE))
	_check("ⓑh 실내·구역 이중 가드(목공방 · 저승 숲)",
		r.require_indoor == "목공방" and r.require_visible
		and String(r.schedule[0]["region"]) == RegionCatalog.JEOSEUNG_FOREST)
	_face_ongi(m, r)
	_check("ⓑi 목공방 안에서 마주 보면 잡힌다", m._facing_resident() == r)
	m._indoor = ""
	_check("ⓑj 밖(같은 구역 야외)에선 안 잡힌다", m._facing_resident() == null)
	m._region = RegionCatalog.EOPHWA_MINE
	m._indoor = "대장간"
	m._update_resident_stations(0.0)
	_check("ⓑk 다른 구역 같은 좌표(대장간)에서도 안 잡힌다", m._facing_resident() == null)
	_face_ongi(m, r)
	# 대사 — 하트 단계별 묶음이 갈리고, 오늘 두 번째 대화는 짧은 한 줄.
	_check("ⓑl 하트 단계별 대사 묶음이 갈린다",
		r.node.lines(0, true) != r.node.lines(3, true)
		and r.node.lines(3, true) != r.node.lines(5, true))
	_check("ⓑm 오늘 두 번째 대화 = 짧은 한 줄", r.node.lines(0, false).size() == 1)
	m.clock.day = 2
	m._start_resident_dialogue(r)
	_check("ⓑn 말 걸면 대화창이 열리고 일일 호감도가 오른다",
		m.dialogue.is_open() and r.affinity.points > 0)
	_close_dialogue(m)
	# 선물 — 수확물 1개를 소모하고 호감도가 오른다(선호 미지정이라 일반 선물 점수).
	# ★[S8-T2] 든 아이템 문법 + 옹이 선호 배정(명단풍꿀 = 러브. 옛 옹이는 선호가 비어 있었다).
	m.inventory.add_item(ItemCatalog.MYEONGDANPUNG_KKUL, 1)
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == ItemCatalog.MYEONGDANPUNG_KKUL:
			m.inventory.select(i)
			break
	var pts_before: int = r.affinity.points
	m._try_resident_gift(r)
	_check("ⓑo 선물이 든 아이템 1개를 소모하고 호감도를 올린다(명단풍꿀 = 옹이 러브)",
		m.inventory.count_of(ItemCatalog.MYEONGDANPUNG_KKUL) == 0
		and r.affinity.points - pts_before == Affinity.GIFT_PREFERRED_POINTS)

	# ── ⓒ 건축 의뢰 지불 ──
	print("── ⓒ 지불 ──")
	var coop := Carpenter.PROJ_BIG_COOP
	var coop_gold := Carpenter.gold_cost(coop)
	var coop_wood := Carpenter.wood_cost(coop)
	_stock(m, coop_gold - 1, coop_wood)
	_check("ⓒa 골드 부족 → 의뢰 거절 · 원목 무소모",
		not m._try_order_build(coop) and not m.carpenter.is_active()
		and m.inventory.count_of(ItemCatalog.WOOD) == coop_wood
		and m.wallet.gold == coop_gold - 1)
	_stock(m, coop_gold, coop_wood - 1)
	_check("ⓒb 원목 부족 → 의뢰 거절 · 골드 무소모",
		not m._try_order_build(coop) and not m.carpenter.is_active()
		and m.wallet.gold == coop_gold)
	_stock(m, coop_gold + 500, coop_wood + 7)
	_check("ⓒc 지불 성공 — 골드·원목 **둘 다** 차감 · 의뢰 점유",
		m._try_order_build(coop) and m.wallet.gold == 500
		and m.inventory.count_of(ItemCatalog.WOOD) == 7
		and m.carpenter.is_active() and m.carpenter.active_id() == coop)
	_check("ⓒd 예정일 = 오늘 + 2일", m.carpenter.due_day() == m.clock.day + 2)
	# 동시 1건 — 두 번째 의뢰는 돈이 넉넉해도 거절되고 아무것도 안 나간다.
	var barn := Carpenter.PROJ_BIG_BARN
	_stock(m, 99999, 999)
	var gold_before: int = m.wallet.gold
	var wood_before: int = m.inventory.count_of(ItemCatalog.WOOD)
	_check("ⓒe 동시 진행 1건 — 다른 프로젝트도 거절 · 무소모",
		not m._try_order_build(barn) and m.carpenter.active_id() == coop
		and m.wallet.gold == gold_before
		and m.inventory.count_of(ItemCatalog.WOOD) == wood_before)
	# 진열도 같은 사실을 말한다(진행 중이면 두 행 다 잠긴다 — 안 보이는데 살 수 있는 구멍 방지).
	var rows: Array = m._build_rows()
	var all_locked := true
	for row in rows:
		if not bool(row.get("locked", false)):
			all_locked = false
	_check("ⓒf 진행 중이면 건축 행 전부 잠김(진열 = 판정과 같은 사실)",
		rows.size() == 3 and all_locked)   # ★[S8-T7] 안방 확장이 붙어 3행

	# ── ⓓ 완공 ──
	print("── ⓓ 완공 ──")
	var cap_before: int = m.ranch.capacity_of("넋둥우리")
	_pass_day(m)
	_check("ⓓa 1일차 — 아직 안 선다", m.carpenter.is_active()
		and m.ranch.capacity_of("넋둥우리") == cap_before)
	_pass_day(m)
	_check("ⓓb 2일차 아침 — 완공 · 진행 해제 · 이력 기록",
		not m.carpenter.is_active() and m.carpenter.is_done(coop))
	_check("ⓓc 완공이 Ranch 티어를 승격(수용 두수 확장)",
		m.ranch.tier_of("넋둥우리") == Ranch.TIER_BIG
		and m.ranch.capacity_of("넋둥우리") == Ranch.CAP_BIG)
	_check("ⓓd 다른 건물 정원은 그대로(승격은 지은 건물만)",
		m.ranch.capacity_of("넋우릿간") == Ranch.CAP_BASE)
	_stock(m, 99999, 999)
	_check("ⓓe 완공분 재의뢰 거절 · 무소모", not m._try_order_build(coop)
		and m.wallet.gold == 99999)
	_check("ⓓf 완공 후 다른 프로젝트는 다시 열린다", m.carpenter.can_order(barn))

	# ── ⓔ 수용 두수 실효 ──
	print("── ⓔ 수용 두수 ──")
	var scratch := Ranch.new()
	var dak := AnimalCatalog.HONBAEK_DAK
	var placed := 0
	for i in 10:
		if scratch.add_animal(Vector2i(i, 0), dak, "넋둥우리"):
			placed += 1
	_check("ⓔa 기본 정원 4마리에서 막힌다(스타듀 Coop 1:1)",
		placed == Ranch.CAP_BASE and scratch.is_full("넋둥우리"))
	scratch.upgrade_building("넋둥우리")
	var placed2 := placed
	for i in range(10, 20):
		if scratch.add_animal(Vector2i(i, 0), dak, "넋둥우리"):
			placed2 += 1
	_check("ⓔb 승격 후 8마리까지(4→8 = 스타듀 Big Coop 비율)",
		placed2 == Ranch.CAP_BIG and scratch.is_full("넋둥우리"))
	_check("ⓔc 승격은 멱등(두 번째 호출 false)", not scratch.upgrade_building("넋둥우리"))
	_check("ⓔd 미소속(\"\") 짐승은 정원 밖(단위 테스트·구버전 방어)",
		scratch.add_animal(Vector2i(90, 90), dak))
	scratch.free()

	# ── ⓕ 매대(가구 세트·원목 소매·♡ 할인) ──
	print("── ⓕ 매대 ──")
	var deco_rows: Array = m._woodshop_items()
	_check("ⓕa 매대 = 판매 가구 세트 2 + 원목 소매 1", deco_rows.size() == 3)
	var starter_listed := false
	for row in deco_rows:
		if String(row.get("kind", "")) == "deco" and HomeDecoCatalog.STARTER_SETS.has(String(row["buy_id"])):
			starter_listed = true
	_check("ⓕb 스타터 세트(무상 해금분)는 진열되지 않는다", not starter_listed)
	var set_id := String(HomeDecoCatalog.purchasable_ids()[0])
	var set_price := HomeDecoCatalog.price_of(set_id)
	_stock(m, set_price - 1, 0)
	_check("ⓕc 골드 부족 → 세트 해금 거절 · 무소모",
		not m._try_buy_deco_set(set_id) and not m.home_deco.is_unlocked(set_id)
		and m.wallet.gold == set_price - 1)
	m.wallet.gold = set_price + 40
	_check("ⓕd 세트 구매 = 골드만 받고 해금(제작 재료 게이트 0)",
		m._try_buy_deco_set(set_id) and m.home_deco.is_unlocked(set_id)
		and m.wallet.gold == 40)
	_check("ⓕe 해금분 재구매 거절 · 무소모",
		not m._try_buy_deco_set(set_id) and m.wallet.gold == 40)
	# 원목 소매 — 기준 판매가의 2배(잠정)로 사고, 인벤에 스택 적재된다.
	var wood_unit: int = ItemCatalog.price_of(ItemCatalog.WOOD) * m.WOOD_RETAIL_MULT
	_check("ⓕf 원목 소매가 = 판매가 × 2(사는 게 늘 손해 = 벌목이 산다)",
		wood_unit == ItemCatalog.price_of(ItemCatalog.WOOD) * 2)
	_stock(m, wood_unit * 3, 0)
	m._buy_store_generic_n(ItemCatalog.WOOD, "wood", 3)
	_check("ⓕg 원목 3개 구매 — 골드 차감·인벤 적재",
		m.inventory.count_of(ItemCatalog.WOOD) == 3 and m.wallet.gold == 0)
	# ♡ 할인 — 골드에만 붙고 원목 요구량엔 안 붙는다(관계가 자재 경제 곱셈기가 되면 ADR-0008 위반).
	print("── ⓕ' ♡ 할인 ──")
	r.affinity.points = 0
	_check("ⓕh ♡0 = 정가(게이트가 아니라 base — 평평≠막힘)",
		int(m._build_rows()[0]["price"]) == Carpenter.gold_cost(String(m._build_rows()[0]["buy_id"]))
		and int(m._woodshop_items()[2]["price"]) == wood_unit)
	r.affinity.points = 5 * Affinity.POINTS_PER_HEART
	r.affinity.stage = 5   # ★[S8-T5] 하트 = stage(진급 칸) — 실제 ♡5로 세워 할인을 검증
	var barn_price: int = 0
	for row in m._build_rows():
		if String(row["buy_id"]) == barn:
			barn_price = int(row["price"])
	_check("ⓕi ♡5 = StoreDiscount 공식(−30%)",
		barn_price == StoreDiscount.price(Carpenter.gold_cost(barn), 5))
	_check("ⓕj ♡5여도 원목 요구량은 불변(자재는 할인 대상 아님)",
		Carpenter.wood_cost(barn) == 450)
	# 지불도 할인가로 실제 빠진다(진열가와 결제가가 같은 출처).
	_stock(m, barn_price, Carpenter.wood_cost(barn))
	_check("ⓕk 할인가로 실제 결제된다", m._try_order_build(barn) and m.wallet.gold == 0)
	# 점주 셋의 할인은 서로를 안 본다.
	var neo_price0: int = int(m._store_items()[0]["price"])
	var fish_price0: int = int(m._fishshop_items()[0]["price"])
	m._resident("boatman").affinity.points = 0
	m.neo_affinity.points = 0
	_check("ⓕl 옹이 ♡5여도 만물상·생선가게 값은 제 하트로만 정해진다",
		int(m._store_items()[0]["price"]) == neo_price0
		and int(m._fishshop_items()[0]["price"]) == fish_price0)

	# ── ⓖ 세이브 왕복·하위호환 ──
	print("── ⓖ 세이브 ──")
	var saved_due: int = m.carpenter.due_day()
	m._save_game()
	var slot: int = m._active_slot
	await _despawn(m)
	var m2: Node = await _new_main()
	_check("ⓖa 진행 의뢰(프로젝트·예정일) 복원",
		m2.carpenter.is_active() and m2.carpenter.active_id() == barn
		and m2.carpenter.due_day() == saved_due)
	_check("ⓖb 완공 이력 복원", m2.carpenter.is_done(coop))
	_check("ⓖc 건물 티어(수용 두수) 복원",
		m2.ranch.capacity_of("넋둥우리") == Ranch.CAP_BIG
		and m2.ranch.capacity_of("넋우릿간") == Ranch.CAP_BASE)
	_check("ⓖd 옹이 호감도가 ongi_affinity 키로 복원",
		m2._resident("ongi").affinity.hearts() == 5)
	_check("ⓖe 가구 세트 해금 복원", m2.home_deco.is_unlocked(set_id))
	await _despawn(m2)
	# 구세이브 — 이 슬라이스가 새로 심은 키 3개(원장·옹이 호감도·건물 티어)를 지운 세이브로 부팅한다.
	# ★ranch의 "tiers"는 ranch 딕셔너리 *안*이라 통째로 지우지 않고 그 키만 걷어낸다(다른 짐승
	#   상태는 살려 둔 채 "티어만 없는 구버전"을 정확히 재현).
	var sm := SaveManager.new()
	var raw := sm.load_game(slot)
	raw.erase("carpenter")
	raw.erase("ongi_affinity")
	if raw.has("ranch") and typeof(raw["ranch"]) == TYPE_DICTIONARY:
		var rd: Dictionary = raw["ranch"]
		rd.erase("tiers")
		raw["ranch"] = rd
	sm.save_game(raw, slot, {"day": 1, "soul": 0})
	sm.free()
	var m3: Node = await _new_main()
	_check("ⓖf 구세이브 = 진행 0·완공 0(빈 원장·크래시 0)",
		not m3.carpenter.is_active() and m3.carpenter.done_ids().is_empty())
	_check("ⓖg 옹이 키 없는 구세이브 = ♡0 시작(크래시 0)",
		m3._resident("ongi") != null and m3._resident("ongi").affinity.hearts() == 0)
	_check("ⓖh 티어 키 없는 구세이브 = 전 건물 기본 정원 4(하위호환)",
		m3.ranch.capacity_of("넋둥우리") == Ranch.CAP_BASE
		and m3.ranch.capacity_of("넋우릿간") == Ranch.CAP_BASE)
	await _despawn(m3)
	# 손상 방어 — 모르는 프로젝트 id / 이미 지은 걸 또 짓는 세이브.
	_check("ⓖi 모르는 프로젝트 id는 통째 버린다", not _load_carpenter(
		{"active": ["no_such_project", 9], "done": ["nope"]}).is_active())
	_check("ⓖj 완공 이력에도 있는 진행분은 버린다(이미 서 있는 건물이 답)",
		not _load_carpenter({"active": [Carpenter.PROJ_BIG_COOP, 9],
			"done": [Carpenter.PROJ_BIG_COOP]}).is_active())

	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)

# 세이브 딕셔너리를 원장 단독으로 로드해 본다(손상 방어 — main 무의존).
func _load_carpenter(data: Dictionary) -> Carpenter:
	var c := Carpenter.new()
	c.load_save(data)
	return c
