extends SceneTree
# ★ [S3-T7 / ADR-0061 결정 7] 게잡이통 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ⓐ 해금 게이트 — 낚시 숙련 lvl3 미만이면 매대 미노출·구매 불가 / lvl3에서 한 행 노출·구매 가능.
#   ⓑ 설치 유효성 — 캐스팅 무대(삼도천·황천해) 한정 · 물가 인접 land 칸만 · 중복 설치 불가 ·
#      주민 자리 배제(뱃사공 칸 [F] 충돌 방지) · 안식 농원 전 칸 거부.
#   ⓒ 일일 롤 결정성 — 같은 day·같은 좌표 = 같은 결과 · 미끼 없으면 어획 0 · 안 비운 통은 재롤 0.
#   ⓓ 퍼크 실효 — 덫꾼(미끼 소모↓) · 뱃사람(잡동사니 0) · 미끼장인(무미끼 어획) + main 주입 배선.
#   ⓔ 수거·회수 — 어획물 인벤 지급 · 빈 통 회수 · **어획 대기 중 회수 거절**(어획물 증발 방지).
#   ⓕ 세이브 왕복·하위호환 — 구역/좌표/미끼/어획 보존 · crab_pot 키 없는 구세이브 무해.
#   ⓖ 혼력 무과금(ADR-0061 결정 7 "패시브·혼력 0") + 통용물 3종의 환전·출하·의뢰 자동 통용.
#
# 실행: ./run_tests.sh crab_pot   (헤드리스는 반드시 game/에서 · 순차)

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

# 낚시 숙련을 원하는 레벨의 진입 XP로 세운다(FarmSkill 공통 곡선 — FishSkill이 위임하는 그 곡선).
func _set_fishing_level(m: Node, level: int) -> void:
	m._fishing_xp = 0 if level <= 0 else int(FarmSkill.XP_THRESHOLDS[level - 1])

# 미끼 든 통 n개를 한 줄로 깐 순수 원장(main 무의존 — 롤·퍼크 검증용).
func _ledger_with(n: int, baited: bool) -> CrabPotLedger:
	var led := CrabPotLedger.new()
	for i in n:
		led.place("river", Vector2i(i, 0))
		if baited:
			led.load_bait("river", Vector2i(i, 0))
	return led

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S3-T7 게잡이통 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()

	# ── ⓐ 해금 게이트(낚시 숙련 lvl3) ──
	print("── ⓐ 해금 게이트 ──")
	_check("ⓐa 해금 레벨 상수 = 3(스타듀 Crab Pot 1:1)", FishSkill.CRAB_POT_LEVEL == 3)
	_set_fishing_level(m, 0)
	m._professions = {}
	_check("ⓐb L0 = 미해금", not m._crab_pot_unlocked())
	var rows0: Array = m._fishshop_items()
	_check("ⓐc L0 매대 = 기존 9행 그대로(게잡이통 미노출)",
		rows0.size() == 9 and rows0.all(func(it): return String(it["buy_id"]) != ItemCatalog.CRAB_POT))
	_set_fishing_level(m, 2)
	_check("ⓐd L2(문턱 직전)도 미해금", not m._crab_pot_unlocked() and m._fishshop_items().size() == 9)
	# 미해금 상태에서 구매 경로를 직접 때려도 거절(진열 숨김만이 아니라 실동작도 막힌다).
	m.wallet.gold = 5000
	var gold_before: int = m.wallet.gold
	m._on_frame_buy_store_item(ItemCatalog.CRAB_POT, "pot", false)
	_check("ⓐe 미해금 구매 거절(골드·인벤 불변)",
		m.wallet.gold == gold_before and m.inventory.count_of(ItemCatalog.CRAB_POT) == 0)
	# lvl3 도달 — 목록 끝에 한 행이 붙는다.
	_set_fishing_level(m, 3)
	_check("ⓐf L3 = 해금", m._crab_pot_unlocked())
	var rows3: Array = m._fishshop_items()
	var pot_row: Dictionary = rows3[rows3.size() - 1]
	_check("ⓐg L3 매대 = 10행 · 마지막이 게잡이통",
		rows3.size() == 10 and String(pot_row["buy_id"]) == ItemCatalog.CRAB_POT)
	_check("ⓐh 행 kind = pot(스프링클러 'placeable' 라우팅과 안 겹친다)",
		String(pot_row["kind"]) == "pot")
	var pot_base: int = ItemCatalog.price_of(ItemCatalog.CRAB_POT)
	_check("ⓐi 기준가 600 · 뱃사공 ♡ 할인가 적용",
		pot_base == 600 and int(pot_row["base"]) == pot_base
		and int(pot_row["price"]) == StoreDiscount.price(pot_base, m._boatman_hearts()))
	# 구매 — 설치물이라 유니크가 아니다(여러 개 산다).
	var unit: int = int(pot_row["price"])
	m._on_frame_buy_store_item(ItemCatalog.CRAB_POT, "pot", false)
	_check("ⓐj 구매 1개 = 인벤 +1 · 골드 −단가",
		m.inventory.count_of(ItemCatalog.CRAB_POT) == 1 and m.wallet.gold == gold_before - unit)
	m._on_frame_buy_store_item(ItemCatalog.CRAB_POT, "pot", false)
	_check("ⓐk 재구매 가능(설치물 = 유니크 아님)", m.inventory.count_of(ItemCatalog.CRAB_POT) == 2)
	_check("ⓐl 만물상 매대엔 게잡이통 없음(서비스 분산)",
		m._store_items().all(func(it): return String(it["buy_id"]) != ItemCatalog.CRAB_POT))

	# ── ⓑ 설치 유효성 ──
	print("── ⓑ 설치 유효성 ──")
	m._rebuild_region(RegionCatalog.HWANGCHEONHAE)
	m._indoor = ""
	m._sleeping = false
	m._update_resident_stations(0.0)
	m.inventory.add_item(ItemCatalog.CRAB_POT, 4)
	var beach := Vector2i(27, 27)          # 백사장 남단(GROUND) — 바로 아래 y28이 바다
	var inland := Vector2i(27, 21)         # 백사장 안쪽(GROUND) — 4방에 물 없음
	var sea := Vector2i(27, 28)            # 바다(WATER) 자체
	var pier := Vector2i(m.PIER_X, 30)     # 부두 목판(PATH) — 좌우가 바다
	_check("ⓑa 물가 인접 백사장 = 설치 가능", m._can_place_crab_pot(beach))
	_check("ⓑb 부두 목판(PATH)도 설치 가능", m._can_place_crab_pot(pier))
	_check("ⓑc 물에서 떨어진 내륙 칸 = 거부", not m._can_place_crab_pot(inland))
	_check("ⓑd 물 타일 자체 = 거부(통은 물가에 놓는다)", not m._can_place_crab_pot(sea))
	var boatman_tile: Vector2i = m._resident("boatman").tile
	_check("ⓑe 뱃사공 자리는 물가여도 거부([F] 충돌 방지)",
		m._is_waterside(boatman_tile) and not m._can_place_crab_pot(boatman_tile))
	var pots_before: int = m.inventory.count_of(ItemCatalog.CRAB_POT)
	m._place_crab_pot(beach)
	_check("ⓑf 설치 = 원장 등재 · 인벤 −1",
		m.crab_pot.has_at(RegionCatalog.HWANGCHEONHAE, beach)
		and m.inventory.count_of(ItemCatalog.CRAB_POT) == pots_before - 1)
	_check("ⓑg 같은 칸 중복 설치 불가", not m._can_place_crab_pot(beach))
	m._place_crab_pot(beach)
	_check("ⓑh 중복 호출도 무해(인벤 안 닳음)",
		m.inventory.count_of(ItemCatalog.CRAB_POT) == pots_before - 1 and m.crab_pot.count() == 1)
	# 안식 농원 = 캐스팅 무대가 아니다(ADR-0061 결정 9 정합) — 물가가 있어도 전 칸 거부.
	m._rebuild_region(RegionCatalog.HOME)
	var home_any := false
	for y in m._outdoor_h:
		for x in m._grid_w:
			if m._can_place_crab_pot(Vector2i(x, y)):
				home_any = true
	_check("ⓑi 안식 농원(연못 있음)은 전 칸 거부 — 무대 한정", not home_any)
	m._rebuild_region(RegionCatalog.HWANGCHEONHAE)
	_check("ⓑj 구역을 오가도 원장은 그 구역 것만 돌려준다",
		m.crab_pot.tiles(RegionCatalog.HWANGCHEONHAE).size() == 1
		and m.crab_pot.tiles(RegionCatalog.HOME).is_empty())

	# ── ⓒ 일일 롤 결정성 ──
	print("── ⓒ 일일 롤 결정성 ──")
	var led_a := _ledger_with(1, true)
	var led_b := _ledger_with(1, true)
	var got_a: Array = led_a.advance_day(7)
	var got_b: Array = led_b.advance_day(7)
	_check("ⓒa 같은 day·좌표 = 같은 어획(결정적)",
		got_a.size() == 1 and got_b.size() == 1 and String(got_a[0]["id"]) == String(got_b[0]["id"]))
	var led_c := _ledger_with(1, true)
	var got_c: Array = led_c.advance_day(8)
	_check("ⓒb day가 다르면 시드가 갈린다(같은 통·다른 날)",
		got_c.size() == 1 and String(got_c[0]["region"]) == "river")
	_check("ⓒc 어획물은 전부 유효 아이템",
		ItemCatalog.has_item(String(got_a[0]["id"])))
	var led_dry := _ledger_with(3, false)
	_check("ⓒd 미끼 없으면 어획 0", led_dry.advance_day(7).is_empty()
		and led_dry.pending_catch("river", Vector2i(0, 0)) == "")
	# 안 비운 통은 다음 밤을 쉰다(수거가 곧 재가동 — 스타듀 1:1).
	_check("ⓒe 어획 대기 중이면 다음 날 재롤 0", led_a.advance_day(8).is_empty())
	var kept: String = led_a.pending_catch("river", Vector2i(0, 0))
	_check("ⓒf 대기 어획물이 덮어써지지 않는다", kept == String(got_a[0]["id"]))
	# 미끼는 어획과 함께 닳는다(퍼크 없음 = cost_save 0.0).
	_check("ⓒg 어획하면 미끼 소모(퍼크 0)", not led_a.is_baited("river", Vector2i(0, 0)))

	# ── ⓓ 퍼크 실효 ──
	print("── ⓓ 퍼크 실효 ──")
	const N := 40
	# ① 뱃사람 — 잡동사니 0(테이블에서 삭은 그물 제거 → 통용물로 재정규화).
	var led_junk := _ledger_with(N, true)
	var led_clean := _ledger_with(N, true)
	var rolls_junk: Array = led_junk.advance_day(11)
	var rolls_clean: Array = led_clean.advance_day(11, true)
	var junk_n := 0
	for e in rolls_junk:
		if String(e["id"]) == ItemCatalog.ROTTEN_NET:
			junk_n += 1
	var clean_junk := 0
	var clean_goods := 0
	for e in rolls_clean:
		if String(e["id"]) == ItemCatalog.ROTTEN_NET:
			clean_junk += 1
		if ItemCatalog._is_pot_good(String(e["id"])):
			clean_goods += 1
	_check("ⓓa 기본 테이블엔 잡동사니(삭은 그물)가 섞인다", junk_n > 0)
	_check("ⓓb 뱃사람 = 잡동사니 0 · 전량 통용물로 대체",
		clean_junk == 0 and clean_goods == N and rolls_clean.size() == N)
	_check("ⓓc 잡동사니는 신규 아이템이 아니라 인양물 재사용(삭은 그물)",
		ItemCatalog._is_material(ItemCatalog.ROTTEN_NET))
	# ② 미끼장인 — 미끼 없이도 어획, 그리고 미끼를 쓰지도 않는다.
	var led_free := _ledger_with(3, false)
	var rolls_free: Array = led_free.advance_day(12, false, true)
	_check("ⓓd 미끼장인 = 미끼 없는 통도 어획", rolls_free.size() == 3)
	_check("ⓓe 미끼장인 = 미끼 소모 자체가 없다(장전 상태 불변)",
		not led_free.is_baited("river", Vector2i(0, 0)))
	# ③ 덫꾼 — 미끼 소모 절감(0.0 전량 소모 < 0.5 일부 잔존 < 1.0 전량 잔존).
	var led_s0 := _ledger_with(N, true)
	var led_s5 := _ledger_with(N, true)
	var led_s1 := _ledger_with(N, true)
	led_s0.advance_day(13, false, false, 0.0)
	led_s5.advance_day(13, false, false, 0.5)
	led_s1.advance_day(13, false, false, 1.0)
	var kept0 := 0
	var kept5 := 0
	var kept1 := 0
	for i in N:
		if led_s0.is_baited("river", Vector2i(i, 0)):
			kept0 += 1
		if led_s5.is_baited("river", Vector2i(i, 0)):
			kept5 += 1
		if led_s1.is_baited("river", Vector2i(i, 0)):
			kept1 += 1
	_check("ⓓf 퍼크 0 = 미끼 전량 소모", kept0 == 0)
	_check("ⓓg 덫꾼(0.5) = 일부 미끼 잔존(0 < n < %d)" % N, kept5 > 0 and kept5 < N)
	_check("ⓓh 절감 1.0 = 미끼 전량 잔존(상한 정합)", kept1 == N)
	# ④ main 주입 배선 — 전문직을 고르면 조회 헬퍼가 켜지고 _on_day_advanced가 그걸 넘긴다.
	m._professions = {ProfessionCatalog.FISHING: {5: "trapper", 10: "luremaster"}}
	_check("ⓓi 덫꾼·미끼장인 선택 → 조회 헬퍼 켜짐",
		is_equal_approx(m.crab_pot_cost_save(), 0.5) and m.crab_pot_bait_free())
	m.crab_pot.load_bait(RegionCatalog.HWANGCHEONHAE, beach)   # 장전해 두고
	m.crab_pot.collect(RegionCatalog.HWANGCHEONHAE, beach)     # (혹시 남은 어획 비우기 — 멱등)
	var energy_before: int = m.energy.current
	m.clock.day = 3
	m._on_day_advanced(3)
	_check("ⓓj _on_day_advanced가 통을 굴린다(미끼장인 배선 살아 있음)",
		m.crab_pot.pending_catch(RegionCatalog.HWANGCHEONHAE, beach) != "")

	# ── ⓖ 혼력 무과금(설치·장전·수거·회수 전부) ──
	print("── ⓖ 혼력 무과금 ──")
	m._professions = {}                          # 퍼크 없는 맨몸 상태(사다리 전 단계를 그대로 본다)
	m.energy.current = SoulEnergy.MAX
	var e0: int = m.energy.current
	var pot2 := Vector2i(26, 27)
	m.inventory.add_item(ItemCatalog.CRAB_POT, 1)
	m.inventory.add_item(ItemCatalog.BAIT_BASIC, 3)
	m._place_crab_pot(pot2)
	_check("ⓖa 설치 = 혼력 0", m.energy.current == e0)
	m._use_crab_pot(pot2)                       # 미끼 장전([F] 사다리 ②)
	_check("ⓖb 상호작용 1회 = 혼력 0",
		m.energy.current == e0 and m.crab_pot.is_baited(RegionCatalog.HWANGCHEONHAE, pot2))

	# ── ⓔ 수거·회수 ──
	print("── ⓔ 수거·회수 ──")
	# 통을 새로 깔고(위 흐름과 독립) 미끼 → 롤 → 수거 → 회수를 한 줄로 태운다.
	var pot3 := Vector2i(25, 27)
	m.inventory.add_item(ItemCatalog.CRAB_POT, 1)
	m._place_crab_pot(pot3)
	var bait_before: int = m.inventory.count_of(ItemCatalog.BAIT_BASIC)
	m._use_crab_pot(pot3)
	_check("ⓔa [F] ① 미끼 장전 = 일반 미끼 1개 소모",
		m.crab_pot.is_baited(RegionCatalog.HWANGCHEONHAE, pot3)
		and m.inventory.count_of(ItemCatalog.BAIT_BASIC) == bait_before - 1)
	m.crab_pot.advance_day(21)
	var pending: String = m.crab_pot.pending_catch(RegionCatalog.HWANGCHEONHAE, pot3)
	_check("ⓔb 하룻밤 뒤 수거 대기 생성", pending != "")
	_check("ⓔc 어획 대기 중엔 회수 거절(어획물 증발 방지)",
		not m.crab_pot.remove(RegionCatalog.HWANGCHEONHAE, pot3))
	var have_before: int = m.inventory.count_of(pending)
	m._use_crab_pot(pot3)
	_check("ⓔd [F] ② 수거 = 어획물 인벤 지급 · 통은 그 자리에 남는다",
		m.inventory.count_of(pending) == have_before + 1
		and m.crab_pot.has_at(RegionCatalog.HWANGCHEONHAE, pot3)
		and m.crab_pot.pending_catch(RegionCatalog.HWANGCHEONHAE, pot3) == "")
	m.inventory.remove_item(ItemCatalog.BAIT_BASIC, m.inventory.count_of(ItemCatalog.BAIT_BASIC))
	var pots_now: int = m.inventory.count_of(ItemCatalog.CRAB_POT)
	m._use_crab_pot(pot3)
	_check("ⓔe [F] ③ 미끼도 어획도 없으면 회수 = 빈 통 인벤 복귀",
		not m.crab_pot.has_at(RegionCatalog.HWANGCHEONHAE, pot3)
		and m.inventory.count_of(ItemCatalog.CRAB_POT) == pots_now + 1)
	_check("ⓔf 프롬프트가 상태별로 갈린다",
		m._crab_pot_prompt(pot2).contains("[F]"))

	# ── ⓖ' 통용물 3종의 자동 통용(환전·출하·의뢰) ──
	print("── ⓖ' 통용물 통용 ──")
	_check("ⓖc 통용물 3종 등록(넋게·혼조개·잿빛소라)",
		ItemCatalog.POT_GOODS.size() == 3 and ItemCatalog._is_pot_good(ItemCatalog.NEOK_GE)
		and ItemCatalog._is_pot_good(ItemCatalog.HON_JOGAE)
		and ItemCatalog._is_pot_good(ItemCatalog.JAETBIT_SORA))
	var band_ok := true
	var schema_ok := true
	for pid in ItemCatalog.POT_GOODS:
		var price: int = ItemCatalog.price_of(String(pid))
		if price < 30 or price > 60:
			band_ok = false
		if ItemCatalog.category_of(String(pid)) != ItemCatalog.CAT_HARVEST \
				or not ItemCatalog.stackable_of(String(pid)) \
				or ItemCatalog.name_of(String(pid)) == "" \
				or not ItemCatalog.has_item(String(pid)):
			schema_ok = false
	_check("ⓖd 가격 밴드 30~60(소 체급 물고기 결)", band_ok)
	_check("ⓖe 스키마 = CAT_HARVEST·스택·이름·유효 아이템", schema_ok)
	_check("ⓖf 품질 배수도 어획물과 같은 공식",
		ItemCatalog.price_of(ItemCatalog.NEOK_GE, ItemCatalog.Q_GOLD)
		== int(ItemCatalog.POT_GOODS[ItemCatalog.NEOK_GE]["price"] * ItemCatalog.quality_mult(ItemCatalog.Q_GOLD)))
	# ★[S5-T8] 18 → 20(갱도 호수 2종 합류 — ADR-0063 결정 10). 이 단언의 요지는 **통용물이 어종
	#   로스터에 안 섞인다**는 것이지 로스터 크기가 아니다. 갱도 어종은 낚싯대 산출이라 정상 합류다.
	_check("ⓖg 어종 로스터는 안 오염된다(20종 · 통용물은 _is_fish 아님)",
		FishCatalog.ids().size() == 20 and not ItemCatalog._is_fish(ItemCatalog.NEOK_GE)
		and ItemCatalog._is_seafood(ItemCatalog.NEOK_GE))
	# 환전(생선가게) — 어획물과 같은 창구·같은 공식.
	m.inventory.remove_item(ItemCatalog.NEOK_GE, m.inventory.count_of(ItemCatalog.NEOK_GE))
	m.inventory.add_item(ItemCatalog.NEOK_GE, 2)
	var trade_ids: Array = m._trade_items().map(func(it): return String(it["buy_id"]))
	_check("ⓖh 환전 목록에 통용물이 뜬다", trade_ids.has(ItemCatalog.NEOK_GE))
	var gold_pre: int = m.wallet.gold
	m._on_frame_sell_fish(ItemCatalog.NEOK_GE, ItemCatalog.Q_NORMAL, true)
	_check("ⓖi 환전 = 기준가 × 수량(출하 정산과 같은 공식)",
		m.wallet.gold == gold_pre + ItemCatalog.price_of(ItemCatalog.NEOK_GE) * 2
		and m.inventory.count_of(ItemCatalog.NEOK_GE) == 0)
	# 출하함 — CAT_HARVEST라 별도 분기 없이 받아진다.
	_check("ⓖj 출하함 자동 통용", m.ship_bin.add(ItemCatalog.HON_JOGAE, 1, ItemCatalog.Q_NORMAL))
	# 의뢰 보상 공식 — 일반품질 판매가 ×3 ×수량(게시판이 아이템 종류를 안 가린다).
	_check("ⓖk 의뢰 보상 공식 자동 통용",
		QuestBoard.reward_gold(ItemCatalog.JAETBIT_SORA, 2)
		== ItemCatalog.price_of(ItemCatalog.JAETBIT_SORA, ItemCatalog.Q_NORMAL) * QuestBoard.REWARD_MULT * 2)

	# ── ⓕ 세이브 왕복 · 하위호환 ──
	print("── ⓕ 세이브 ──")
	# 상태를 또렷하게 세운다: 미끼 든 통(pot2) + 어획 대기 통(beach).
	m.crab_pot.load_bait(RegionCatalog.HWANGCHEONHAE, pot2)
	var saved_catch: String = m.crab_pot.pending_catch(RegionCatalog.HWANGCHEONHAE, beach)
	var saved_count: int = m.crab_pot.count()
	m._save_game()
	var slot: int = m._active_slot
	m.free()
	var m2: Node = await _new_main()
	_check("ⓕa 설치 수 복원", m2.crab_pot.count() == saved_count)
	_check("ⓕb 구역·좌표 복원", m2.crab_pot.has_at(RegionCatalog.HWANGCHEONHAE, pot2)
		and m2.crab_pot.has_at(RegionCatalog.HWANGCHEONHAE, beach))
	_check("ⓕc 미끼 장전 상태 복원", m2.crab_pot.is_baited(RegionCatalog.HWANGCHEONHAE, pot2))
	_check("ⓕd 수거 대기 어획물 복원",
		m2.crab_pot.pending_catch(RegionCatalog.HWANGCHEONHAE, beach) == saved_catch)
	_check("ⓕe 다른 구역엔 안 샌다", m2.crab_pot.tiles(RegionCatalog.SAMDOCHEON).is_empty())
	m2.free()
	# 구세이브 — crab_pot 키를 지운 세이브로 부팅한다(하위호환).
	var sm := SaveManager.new()
	var raw := sm.load_game(slot)
	raw.erase("crab_pot")
	sm.save_game(raw, slot, {"day": 1, "soul": 0})
	sm.free()
	var m3: Node = await _new_main()
	_check("ⓕf 구세이브 = 게잡이통 0(빈 원장·크래시 0)", m3.crab_pot.count() == 0)
	_check("ⓕg 구세이브 로드가 매대를 안 깨뜨린다", m3._fishshop_items() is Array)
	m3.free()

	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
