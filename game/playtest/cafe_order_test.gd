extends SceneTree
# ★[S6-T2 / ADR-0064 결정 4·10] 주문 위상 · 융합/기본 폴백 · 해금 · 절기 창 단위검증.
# 실행: godot --headless --path game --script res://playtest/cafe_order_test.gd
#
# 검증 축:
#   ① 주문 롤 결정성 — day+serial 시드(전역 randf 0). 같은 날 같은 순번은 언제나 같은 주문.
#   ② 가중 반영 — 곳간 재고가 있는 융합이 더 자주 불린다. **재고 0도 뽑힌다**(폴백 경로의 전제).
#   ③ ★폴백 무이탈 — 융합을 시켰는데 재고 0 → 기본 잔으로 **서빙 성공**·이탈 0(하드 실패 없음).
#   ④ 융합 프리미엄 + 곳간 1개 차감 — 쟁여 둔 것이 그대로 매출 차이가 된다.
#   ⑤ 해금 = 발견 게이트(시그니처 첫 획득) + 최상위 한 잔만 마일스톤 1단 추가 게이트. 관계 게이트 0.
#   ⑥ 절기 창 = 시그니처 재료의 절기 창 파생(별도 달력 데이터 0).
#   ⑦ ♡0 중립 — 융합 매출은 base로 온전하고, 멜 마진은 그 *위에* 곱한다(ADR-0008).
#   ⑧ 세이브 왕복(menu_found) + 곳간 적재 필터 확장(물고기·나락혼정 시그니처 적재 가능).
#
# ①②⑥⑦은 노드 단위(Cafe/MenuCatalog)로, ③④⑤⑧은 main.tscn 라이브로 본다 — 폴백·차감·해금은
# 곳간·원장·지갑을 가로지르는 오케스트레이션이라 main 안에서만 살아 있다(larder_test ⑧ 선례).

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_cafe() -> Cafe:
	var c := Cafe.new()
	c._ready()   # 트리에 안 붙이므로 좌석 초기화를 직접 부른다(cafe_test 하네스 동형)
	return c

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

# 좌석 0에 "이 메뉴를 시킨 손님"을 강제로 앉힌다(스폰 롤을 기다리지 않고 서빙 갈래만 본다).
# 영업창 밖이라 tick이 좌석을 건드리지 않는다(06:00 시작 — cafe.tick은 _open이 false면 즉시 반환).
func _seat_want(m: Node, menu_id: String) -> void:
	m.cafe._seats[0] = {"occupied": true, "patience": 5.0,
		"max_patience": Cafe.DEFAULT_PATIENCE, "want": menu_id}

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S6-T2 주문 위상·폴백·해금 단위검증 ══")

	var ADE := MenuCatalog.PIANHWA_ADE          # 시그니처 = 피안화(작물 — ★S7-T2부터 피안절 전용)
	var PIAN := CropCatalog.PIANHWA

	# ── ① 주문 롤 결정성 ────────────────────────────────────────────────────
	var a := _new_cafe()
	a.day = 5
	a.order_pool = [{"id": ADE, "in_stock": true}]
	var b := _new_cafe()
	b.day = 5
	b.order_pool = [{"id": ADE, "in_stock": true}]
	var same := true
	for s in 30:
		if a.roll_want(s) != b.roll_want(s):
			same = false
	_check("① 같은 day·serial·풀 → 같은 주문(결정 롤)", same)
	_check("①b 재호출해도 안 흔들린다(전역 randf 0)", a.roll_want(7) == a.roll_want(7))
	var seq5: Array = []
	var seq6: Array = []
	b.day = 6
	for s2 in 30:
		seq5.append(a.roll_want(s2))
		seq6.append(b.roll_want(s2))
	_check("①c 날이 다르면 주문열이 갈린다(day가 시드 축)", seq5 != seq6)
	var all_valid := true
	for w in seq5:
		if not MenuCatalog.has(String(w)):
			all_valid = false
	_check("①d 롤 결과는 전부 실존 메뉴", all_valid)
	# 주입이 없으면 기본 메뉴만 나온다 = 하네스·구경로의 base rate 안전판(평평≠막힘).
	var plain := _new_cafe()
	plain.day = 5
	var basics_only := true
	for s3 in 30:
		if not MenuCatalog.is_basic(plain.roll_want(s3)):
			basics_only = false
	_check("①e 주문 풀 주입 없음 → 기본 메뉴만(안전판)", basics_only)

	# ── ② 가중 반영 ────────────────────────────────────────────────────────
	# 기본 4종(W=1) + 융합 1종. 재고 있으면 W=3(기대 3/7), 없으면 W=1(기대 1/5).
	var stocked := _new_cafe()
	stocked.day = 11
	stocked.order_pool = [{"id": ADE, "in_stock": true}]
	var barren := _new_cafe()
	barren.day = 11
	barren.order_pool = [{"id": ADE, "in_stock": false}]
	var n_stocked := 0
	var n_barren := 0
	for s4 in 200:
		if stocked.roll_want(s4) == ADE:
			n_stocked += 1
		if barren.roll_want(s4) == ADE:
			n_barren += 1
	_check("② 재고 있는 융합이 실제로 뽑힌다 (200롤 중 %d)" % n_stocked, n_stocked > 0)
	_check("②b ★재고 0인 융합도 뽑힌다 — 폴백 경로가 산다 (200롤 중 %d)" % n_barren, n_barren > 0)
	_check("②c 재고 가중치가 실효(재고 있음 > 재고 0)", n_stocked > n_barren)
	# 기대 비율 근방인가(W 상수가 뒤집히면 여기가 먼저 운다 — 시드 고정이라 flaky 0).
	_check("②d 재고 있는 융합 비율이 기대(3/7 ≈ 43%%) 근방 — 실측 %d%%" % (n_stocked / 2),
		n_stocked >= 60 and n_stocked <= 112)
	_check("②e 기본 메뉴도 여전히 다수 뽑힌다(융합 독식 0)", n_stocked < 200)
	_check("②f 가중 상수 = 기본1 / 재고3 / 무재고1(그레이박스 레버)",
		Cafe.W_BASIC == 1 and Cafe.W_FUSION_STOCKED == 3 and Cafe.W_FUSION_EMPTY == 1)

	# ── ⑥ 절기 창(시그니처 파생 — 별도 달력 데이터 0) ─────────────────────────
	# 채집물: 넋송이=망연절(2) · 서리동백=성야절(3). ForageSpawns 절기 풀의 역조회에 위임한다.
	_check("⑥ 넋송이 크림수프 = 망연절에만(채집 절기 풀 파생)",
		MenuCatalog.in_season(MenuCatalog.SONGI_SOUP, 2)
		and not MenuCatalog.in_season(MenuCatalog.SONGI_SOUP, 0)
		and not MenuCatalog.in_season(MenuCatalog.SONGI_SOUP, 3))
	_check("⑥b 서리동백 밀크티 = 성야절에만",
		MenuCatalog.in_season(MenuCatalog.DONGBAEK_MILKTEA, 3)
		and not MenuCatalog.in_season(MenuCatalog.DONGBAEK_MILKTEA, 1))
	_check("⑥c 역조회 단일 출처 = ForageSpawns.season_of",
		ForageSpawns.season_of(ItemCatalog.NEOK_SONGI) == 2
		and ForageSpawns.season_of(ItemCatalog.SEORI_DONGBAEK) == 3)
	# 어종: FishCatalog.seasons를 그대로 따른다(메뉴가 절기를 따로 안 든다).
	var domi_sig: String = MenuCatalog.signature_of(MenuCatalog.DOMI_PANINI)
	var domi_matches := true
	var domi_restricted := false
	for s5 in 4:
		if MenuCatalog.in_season(MenuCatalog.DOMI_PANINI, s5) != FishCatalog.in_season(domi_sig, s5):
			domi_matches = false
		if not FishCatalog.in_season(domi_sig, s5):
			domi_restricted = true
	_check("⑥d 어종 메뉴 절기 = FishCatalog.seasons 그대로", domi_matches)
	_check("⑥e 그 어종이 실제로 절기 제한종이다(단언에 이빨이 있다)", domi_restricted)
	# 상시종·수액·나락혼정·기본 = 사철.
	var always := true
	for s6 in 4:
		for mid in [MenuCatalog.BUNGEO_PPANG, MenuCatalog.DANPUNG_PANCAKE,
				MenuCatalog.HONJEONG_EINSPANNER, MenuCatalog.AMERICANO]:
			if not MenuCatalog.in_season(String(mid), s6):
				always = false
	_check("⑥f 상시 어종·수액·나락혼정·기본 메뉴 = 사철", always)
	# ★[S7-T2 / ADR-0065 결정 2] 작물 메뉴 = 그 작물의 절기 그대로(예약돼 있던 훅이 채워졌다 —
	#   "작물 사멸이 곧 메뉴 로테이션"). 옛 단언(작물=전 절기)이 여기 있었다.
	var crops_match := true
	var crop_menus := {
		MenuCatalog.PIANHWA_ADE: 0, MenuCatalog.HONRYEONGCHO_LATTE: 1,
		MenuCatalog.PODO_SMOOTHIE: 2, MenuCatalog.HOBAK_LATTE: 3,
	}
	for cm in crop_menus.keys():
		for s7 in 4:
			var want: bool = (int(crop_menus[cm]) == s7)
			if MenuCatalog.in_season(String(cm), s7) != want:
				crops_match = false
	_check("⑥g 작물 메뉴 = 시그니처 작물의 절기 하나뿐(에이드 피안·라떼 유화·스무디 망연·호박 성야)",
		crops_match)
	_check("⑥g2 판정의 단일 출처 = CropCatalog.in_season(메뉴가 달력을 따로 안 든다)",
		CropCatalog.in_season(CropCatalog.PIANHWA, 0)
		and not CropCatalog.in_season(CropCatalog.PIANHWA, 1))
	# 다절기 작물(불사과) 시그니처 메뉴는 사멸을 안 타 사철이다 — 작물이라고 다 잠기는 게 아니다.
	var tart_always := true
	for s8 in 4:
		if not MenuCatalog.in_season(MenuCatalog.BULSAGWA_TART, s8):
			tart_always = false
	_check("⑥g3 다절기 작물(불사과) 메뉴는 사철 — 작물 축의 예외가 산다", tart_always)
	_check("⑥h 메뉴 아닌 id는 false", not MenuCatalog.in_season("아무것도_아님", 0))

	# ── ⑦ ♡0 중립 + 마진 곱 ────────────────────────────────────────────────
	var fee := _new_cafe()
	var ade_price := MenuCatalog.price_of(ADE)
	_check("⑦ margin=1.0(♡0)에서 융합 매출 = price_of 그대로(base 불변)",
		fee.serve_price(ADE) == ade_price and ade_price > Cafe.BASE_PRICE)
	fee.margin = 2.0
	_check("⑦b margin=2.0(멜♡5)에서 정확히 ×2 — 마진은 메뉴가 *위에* 곱한다",
		fee.serve_price(ADE) == int(round(ade_price * 2.0)))
	_check("⑦c 기본 메뉴는 정액가 × margin", fee.serve_price(MenuCatalog.AMERICANO) == Cafe.BASE_PRICE * 2)
	_check("⑦d 미지 메뉴 id는 정액으로 떨어진다(구경로 안전판)", fee.serve_price("") == Cafe.BASE_PRICE * 2)

	for n in [a, b, plain, stocked, barren, fee]:
		n.free()

	# ── main 배선(main.tscn 라이브) ─────────────────────────────────────────
	print("── ③④⑤⑧ main 배선(main.tscn 라이브) ──")
	var cleaner := SaveManager.new()
	cleaner.delete_save()   # 결정적 검증 — 디스크 세이브를 비우고 시작(milestone_test 하네스 동형)
	var mn: Node = await _spawn_main()

	# ── ③ 폴백 무이탈 — 융합을 시켰는데 곳간이 텅 비었다 ─────────────────────
	_check("③pre 곳간이 비어 있다", not mn.larder.has_stock(PIAN))
	_seat_want(mn, ADE)
	var gold0: int = mn.wallet.gold
	var left0: int = mn.cafe.today_left()
	var served0: int = mn.cafe.today_served()
	var harvest0: int = mn.inventory.total_harvest()
	mn._try_serve(0)
	_check("③ 재고 0이어도 서빙 성공(손님 퇴장)", not mn.cafe.is_waiting(0))
	_check("③b 매출 = 기본 메뉴 정액 %d냥(폴백)" % Cafe.BASE_PRICE,
		mn.wallet.gold - gold0 == Cafe.BASE_PRICE)
	_check("③c ★이탈 0 — 하드 실패 경로가 없다", mn.cafe.today_left() == left0)
	_check("③d 정산에 서빙으로 잡힌다", mn.cafe.today_served() == served0 + 1)
	_check("③e 백팩 수확물은 한 개도 안 먹는다(무재료 기본 메뉴 — 옛 소모 배선 폐지)",
		mn.inventory.total_harvest() == harvest0)
	_check("③f 나갈 메뉴 예고(_planned_menu)도 폴백으로 일치",
		mn._planned_menu(0) == mn._fallback_menu())

	# ── ④ 융합 프리미엄 + 곳간 차감 ─────────────────────────────────────────
	mn.larder.add(PIAN, 1)
	_seat_want(mn, ADE)
	_check("④pre 재고 1 · 예고가 융합으로 바뀐다", mn._planned_menu(0) == ADE)
	var gold1: int = mn.wallet.gold
	var revenue_before: int = mn._cafe_revenue_total
	mn._try_serve(0)
	_check("④ 매출 = 융합 메뉴가(%d냥 — 프리미엄)" % ade_price, mn.wallet.gold - gold1 == ade_price)
	_check("④b 곳간에서 1개 차감", mn.larder.count_of(PIAN) == 0)
	_check("④c 프리미엄 매출도 마일스톤에 계상",
		mn._cafe_revenue_total - revenue_before == ade_price)
	# 재고가 2개면 한 잔에 하나만 먹는다(과다 차감 0).
	mn.larder.add(PIAN, 2)
	_seat_want(mn, ADE)
	mn._try_serve(0)
	_check("④d 한 잔에 딱 1개만 차감", mn.larder.count_of(PIAN) == 1)
	mn.larder.take_back(PIAN, 9)

	# ── ⑤ 해금 = 발견 게이트 ───────────────────────────────────────────────
	# ★[S7-T2] 주문 풀이 절기를 보게 됐다 — 세이브 재개 날짜에 따라 피안화 에이드가 비제철로 빠질 수
	#   있으므로, *해금* 게이트만 보는 이 블록은 절기를 피안절로 고정한다(절기 축은 ⑥이 따로 본다).
	mn.clock.day = 1
	mn._menu_found.clear()
	var pool_locked: Array = mn._cafe_order_pool()
	var locked_has_ade := false
	for e in pool_locked:
		if String((e as Dictionary)["id"]) == ADE:
			locked_has_ade = true
	_check("⑤ 발견 기록 없는 융합은 주문 풀에서 빠진다", not locked_has_ade)
	_check("⑤b 발견 전엔 해금 판정도 false", not mn._menu_unlocked(ADE))
	# 획득 관문 하나(inventory.add_item)가 원장을 채운다 — 획득처를 손대지 않는다.
	mn.inventory.add_item(PIAN, 1, 0)
	_check("⑤c 시그니처를 손에 넣는 순간 발견 기록", mn._menu_found.has(PIAN))
	_check("⑤d 발견 후 해금", mn._menu_unlocked(ADE))
	var pool_open: Array = mn._cafe_order_pool()
	var open_has_ade := false
	for e2 in pool_open:
		if String((e2 as Dictionary)["id"]) == ADE:
			open_has_ade = true
	_check("⑤e 발견 후 주문 풀에 합류", open_has_ade)
	# ★ 최상위 한 잔(나락혼정 아인슈페너)만 카페 일구기 1단을 추가로 요구한다.
	mn._menu_found[ItemCatalog.NARAK_HONJEONG] = true
	_check("⑤f pre 마일스톤 1단 미완", not mn._milestone_complete())
	_check("⑤g ★최상위는 발견만으론 안 열린다(일구기 1단 게이트)",
		not mn._menu_unlocked(MenuCatalog.HONJEONG_EINSPANNER))
	# 1단 세 축(거둔 영혼·누적 서빙 매출·미호+멜+바나 하트)을 채우면 열린다.
	mn._run_harvested = CafeMilestone.TARGET_HARVEST
	mn._cafe_revenue_total = CafeMilestone.TARGET_REVENUE
	# ★[S10-T5 발견] `points`만 세우면 하트가 안 오른다 — [S8-T5 / ADR-0066]이 하트를 **stage(진급
	#   칸)** 파생으로 바꾼 뒤(`Affinity.hearts() == stage`) 이 세팅이 갱신되지 않아 ⑤h가 잠복
	#   실패해 있었다(S10-T5 선별 회귀가 검출 — 카페 3단·늘봄방과 무관). milestone_test가 쓰는
	#   "점수와 stage를 함께 세운다" 관례를 그대로 따른다.
	mn.affinity.points = 9999
	mn.affinity.stage = Affinity.MAX_HEARTS
	mn.mel_affinity.points = 9999
	mn.mel_affinity.stage = Affinity.MAX_HEARTS
	mn.bana_affinity.points = 9999
	mn.bana_affinity.stage = Affinity.MAX_HEARTS
	_check("⑤h 1단 완료 후 최상위 해금",
		mn._milestone_complete() and mn._menu_unlocked(MenuCatalog.HONJEONG_EINSPANNER))
	_check("⑤i 하트가 최상위 *한 잔*에만 걸린다 — 다른 융합은 ♡와 무관(ADR-0008)",
		mn._menu_unlocked(ADE))
	# 관계를 도로 0으로 떨어뜨려도 나머지 융합은 그대로 열려 있다(관계=곱셈기, 게이트 0).
	mn.affinity.points = 0
	mn.mel_affinity.points = 0
	mn.bana_affinity.points = 0
	_check("⑤j ♡0으로 되돌려도 일반 융합은 계속 열려 있다", mn._menu_unlocked(ADE))

	# ── ⑧ 곳간 적재 필터 확장 + 세이브 왕복 ────────────────────────────────
	# T1의 CAT_HARVEST 제한은 **나락혼정(CAT_MATERIAL)을 통째로 막고 있었다** — 최상위 메뉴의
	# 재료가 곳간에 못 들어가는 잠복 격차. 판정을 "융합 시그니처인가"로 옮겨 봉합했다.
	var fish := FishCatalog.NEOK_BUNGEO
	mn.inventory.add_item(fish, 2, 0)
	var fslot := -1
	for i in Inventory.SIZE:
		if mn.inventory.id_at(i) == fish:
			fslot = i
	_check("⑧pre 백팩에 물고기 슬롯", fslot >= 0)
	mn._on_frame_larder_store(fslot)
	_check("⑧ 물고기 시그니처 적재 가능(CAT_HARVEST 밖 아님 — 회귀 방어)",
		mn.larder.count_of(fish) == 2)
	mn.inventory.add_item(ItemCatalog.NARAK_HONJEONG, 1, 0)
	var hslot := -1
	for i2 in Inventory.SIZE:
		if mn.inventory.id_at(i2) == ItemCatalog.NARAK_HONJEONG:
			hslot = i2
	mn._on_frame_larder_store(hslot)
	_check("⑧b ★나락혼정(CAT_MATERIAL) 적재 가능 — T1 잠복 격차 봉합",
		mn.larder.count_of(ItemCatalog.NARAK_HONJEONG) == 1)
	# 메뉴가 없는 산출물은 여전히 거절된다(죽은 재고 방지 — 곳간은 메뉴 재료 창고다).
	mn.inventory.add_item(ItemCatalog.NEOK_GOSARI, 1, 0)
	var gslot := -1
	for i3 in Inventory.SIZE:
		if mn.inventory.id_at(i3) == ItemCatalog.NEOK_GOSARI:
			gslot = i3
	if gslot >= 0:
		mn._on_frame_larder_store(gslot)
		_check("⑧c 어느 메뉴의 재료도 아닌 산출물은 거절(죽은 재고 0)",
			not mn.larder.has_stock(ItemCatalog.NEOK_GOSARI)
			and mn.inventory.id_at(gslot) == ItemCatalog.NEOK_GOSARI)
	# 세이브 왕복 — 발견 원장이 "menu_found" 한 조각으로 실린다.
	mn._save_game()
	var mn2: Node = await _spawn_main()
	_check("⑧d 이어하기에 발견 원장 복원",
		mn2._menu_found.has(PIAN) and mn2._menu_found.has(ItemCatalog.NARAK_HONJEONG))
	_check("⑧e 복원된 원장으로 해금도 살아난다", mn2._menu_unlocked(ADE))
	# 하위호환: **키 자체가 없는 구세이브**(S6-T2 이전 저장)를 열어도 막히지 않아야 한다. 디스크
	# 세이브에서 그 키만 도려내고 다시 열어 실제 로드 경로를 두드린다(빈 원장 → 융합은 잠겨 있지만
	# 기본 메뉴로 영업은 계속된다 = 무막힘, ADR-0008 평평≠막힘).
	var blob: Dictionary = cleaner.load_game()
	_check("⑧f pre 세이브에 menu_found 키가 실려 있다", blob.has("menu_found"))
	blob.erase("menu_found")
	cleaner.save_game(blob)
	var mn3: Node = await _spawn_main()
	_check("⑧g 구세이브(키 부재) 로드 = 빈 발견 원장", mn3._menu_found.is_empty())
	_check("⑧h 그래도 안 막힌다 — 주문 풀은 비고 기본 메뉴로 영업",
		mn3._cafe_order_pool().is_empty() and MenuCatalog.is_basic(mn3.cafe.roll_want(0)))
	cleaner.delete_save()

	for m in [mn, mn2, mn3]:
		m.queue_free()   # 띄운 main 세 벌을 거둔다(chest_test·larder_test와 같은 종료 결)

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
