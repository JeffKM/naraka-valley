extends SceneTree
# M2.3 — 만물상 서비스(점주 네오 — 바이블 오토마타, T1 비인간) 검증(ephemeral 헤드리스 단위검증).
# M2.2까지 enterable graybox 방뿐이던 만물상에, 점주 네오 + 매대(씨앗 구매)가 붙었는지 본다.
#
# ★ 핵심 불변식:
#   ① 할인 곡선(StoreDiscount) — ♡0 정가(1.0, 평평≠막힘) → 하트당 선형 할인 → ♡5 30% 할인,
#      가격은 정수·최소 1·정가 0이면 0(손상 방어). 이것은 '소매 할인 퍼크'지 '활동 곱셈기'가 아니다.
#   ② 네오 대사 — 하트 단계별 다른 묶음(낯섦/단골/친근) + 오늘 두 번째는 짧은 인사. 서사 조각 없는 플레이버.
#   ③ 네오 배치 — NEO_TILE이 만물상 방(STORE_RECT) 안 바닥, 바로 아래(플레이어 자리)도 방 안 바닥(마주봄 가능).
#   ④ 매대 구매 — _buy_seed_store가 네오 할인가로 골드를 쓰고 씨앗을 +1. ♡0 정가 / ♡5 할인.
#   ⑤ 구매 전용 — 만물상엔 판매가 없다(_store_text=매대·판매 없음 / _shop_text=출하대·전량 판매). 서비스 분산.
#   ⑥ 호감도 = 대화 한 채널 — 이 슬라이스는 일일 대화로만 오른다(하루 1회, 선물 채널은 풀 T1 트랙=후속). _start_neo_dialogue가 올린다.
#   ⑦ 세이브 라운드트립 — 네오 호감도가 새 인스턴스로 재개된다.
#   ⑧ 회귀 0 — 멜 출하대 씨앗 구매는 네오 할인을 받지 않는다(정가 그대로). 만물상 카탈로그·종류 불변.
# 실행: godot --headless --path game --script res://playtest/store_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000   # 안전 상한(좀비 방지)
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

func _initialize() -> void:
	print("══ M2.3 만물상 서비스(점주 네오 — 오토마타 T1) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.m2_3_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	# 첫 인스턴스가 옛/오염 세이브로 부팅되지 않게 spawn 전에 지운다(interior_test 격리 교훈).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 할인 곡선(StoreDiscount) — 순수 단위(인스턴스 불필요) ──
	print("── ① 할인 곡선(StoreDiscount) ──")
	_check("①a ♡0 = 정가(factor 1.0 — 평평≠막힘)", is_equal_approx(StoreDiscount.factor(0), 1.0))
	_check("①b ♡5 = 30% 할인(factor 0.70)", is_equal_approx(StoreDiscount.factor(5), 0.70))
	_check("①c 하트가 오를수록 할인율↓(단조 감소)", StoreDiscount.factor(0) > StoreDiscount.factor(3) and StoreDiscount.factor(3) > StoreDiscount.factor(5))
	_check("①d 음수/초과 하트는 [0,5]로 잘림", is_equal_approx(StoreDiscount.factor(-3), StoreDiscount.factor(0)) and is_equal_approx(StoreDiscount.factor(99), StoreDiscount.factor(5)))
	_check("①e ♡0 가격 = 정가", StoreDiscount.price(100, 0) == 100)
	_check("①f ♡5 가격 = 정가의 70%", StoreDiscount.price(100, 5) == 70)
	_check("①g 정가 0 → 0(손상 방어)", StoreDiscount.price(0, 5) == 0)
	_check("①h 가격 최소 1(0원 방지)", StoreDiscount.price(1, 5) == 1)
	_check("①i percent: ♡0 0% / ♡5 30%", StoreDiscount.percent(0) == 0 and StoreDiscount.percent(5) == 30)
	_check("①j summary ♡0=정가 안내 / ♡>0=−n%", StoreDiscount.summary(0).contains("정가") and StoreDiscount.summary(5).contains("30%"))

	# ── ② 네오 대사 — 하트 단계별 + 일일 ──
	print("── ② 네오 대사 ──")
	var neo := Neo.new()
	var intro := neo.lines(0, true)
	var warming := neo.lines(2, true)
	var close := neo.lines(4, true)
	var again := neo.lines(0, false)
	_check("②a 모든 단계 대사 비어 있지 않음", not intro.is_empty() and not warming.is_empty() and not close.is_empty())
	_check("②b 하트 단계별 다른 묶음", intro != warming and warming != close and intro != close)
	_check("②c 오늘 두 번째는 짧은 인사 한 줄", again.size() == 1 and again[0] == neo.LINE_AGAIN)
	_check("②d 이름 = 네오", neo.display_name() == "네오")
	neo.free()

	var m: Node = await _spawn_main()

	# ── ③ 네오 배치 — 만물상 방으로 워프해 방·바닥 확인 ──
	print("── ③ 네오 배치 ──")
	m.player.position = m._tile_center_px(Vector2i(78, 32))   # ★C2 동쪽 길 워프 → 마을
	m._maybe_warp_edge()
	await _settle(m)
	_check("③pre 나루 마을로 워프", m._region == RegionCatalog.NARU_VILLAGE)
	_check("③a NEO_TILE이 만물상 방(STORE_RECT) 안", m.STORE_RECT.has_point(m.NEO_TILE))
	_check("③b NEO_TILE 바닥(만물상 = 카페 타일)", m._grid[m.NEO_TILE.y][m.NEO_TILE.x] == m.CAFE)
	var stand: Vector2i = m.NEO_TILE + Vector2i(0, 1)   # 플레이어가 서서 위를 보는 칸
	_check("③c 네오 바로 아래(플레이어 자리)도 방 안 바닥", m.STORE_RECT.has_point(stand) and m._grid[stand.y][stand.x] == m.CAFE)
	_check("③d 네오 위치 = NEO_TILE 중앙", m.neo.position == m._tile_center_px(m.NEO_TILE))

	# ── ④ 매대 구매 — _buy_seed_store(할인 적용) ──
	print("── ④ 매대 구매 ──")
	var crop: String = m._selected_crop
	var base: int = CropCatalog.seed_cost(crop)
	_check("④pre 씨앗 정가 > 0", base > 0)
	# ♡0(정가) 구매
	m.neo_affinity.points = 0
	m.wallet.gold = 1000
	var seeds0: int = m.inventory.seed_count(crop)
	m._buy_seed_store(crop)
	_check("④a ♡0 구매 = 정가만큼 골드 차감", m.wallet.gold == 1000 - base)
	_check("④b 씨앗 +1", m.inventory.seed_count(crop) == seeds0 + 1)
	# ♡5(할인) 구매 — 같은 씨앗이 더 싸다
	m.neo_affinity.points = m.neo_affinity.MAX_POINTS   # ♡5
	m.neo_affinity.stage = Affinity.MAX_HEARTS          # ★[S8-T5] 하트 = stage(진급 칸) — 함께 세팅
	_check("④pre2 ♡5 도달", m.neo_affinity.hearts() == 5)
	var discounted: int = StoreDiscount.price(base, 5)
	m.wallet.gold = 1000
	m._buy_seed_store(crop)
	_check("④c ♡5 구매 = 할인가만큼 차감(< 정가)", m.wallet.gold == 1000 - discounted and discounted < base)
	# 골드 부족이면 막힌다(음수 방지)
	m.wallet.gold = 0
	var seeds_before: int = m.inventory.seed_count(crop)
	m._buy_seed_store(crop)
	_check("④d 골드 부족이면 구매 막힘(씨앗 불변)", m.inventory.seed_count(crop) == seeds_before and m.wallet.gold == 0)

	# ── ⑤ 구매 전용(서비스 분산) — ★ C2: 멜 출하대 폐지, 판매=무인 출하함 ──
	print("── ⑤ 구매 전용 ──")
	var st: String = m._store_text()
	_check("⑤a 만물상 매대 = '매대' 헤더 + 판매/출하 없음", st.contains("매대") and not st.contains("전량 판매") and not st.contains("판매"))
	# ★ C2 — 멜 출하대(_shop_text)는 폐지됐다. 판매 채널 = 무인 출하함(ship_bin, 익일 정산).
	m.ship_bin.pending.clear()
	m.ship_bin.add(crop, 2)
	var sell_expect: int = 2 * CropCatalog.sell_price(crop)
	_check("⑤b 판매 = 무인 출하함 익일 정산(판매가 합)", m.ship_bin.preview_gold() == sell_expect and m.ship_bin.settle() == sell_expect)
	m.ship_bin.pending.clear()

	# ── ⑥ 호감도 = 대화 한 채널(이 슬라이스 범위 — 풀 T1 트랙은 후속) ──
	print("── ⑥ 호감도(대화 채널) ──")
	m.neo_affinity.points = 0
	m.neo_affinity.last_talk_day = -1
	var day: int = m.clock.day
	var before_pts: int = m.neo_affinity.points
	m._start_neo_dialogue()
	_check("⑥a 일일 대화로 호감도↑", m.neo_affinity.points > before_pts)
	_check("⑥b 대화 중 이동 잠금", not m.player.is_physics_processing())
	# 같은 날 두 번째 대화는 점수 안 오름(하루 1회 게이팅)
	var after_first: int = m.neo_affinity.points
	if m.dialogue.has_method("close"):
		m.dialogue.close()
	m._start_neo_dialogue()
	_check("⑥c 같은 날 두 번째는 점수 불변", m.neo_affinity.points == after_first)

	# ── ⑧ 구매 일원화(★ C2) + Shift 대량 ──
	print("── ⑧ 구매 일원화 + 대량 ──")
	# ★ C2 — 씨앗 구매는 네오 매대로 일원화됐다(멜 출하대 _buy_seed 폐지). Shift 대량 구매 검증.
	m.neo_affinity.points = 0   # ♡0 정가(환산 단순)
	m.neo_affinity.stage = 0    # ★[S8-T5] 하트 = stage — ④의 ♡5를 되돌린다
	m.wallet.gold = 1000
	var seeds_b: int = m.inventory.seed_count(crop)
	m._on_frame_buy(true)   # Shift 대량(STORE_BULK개)
	_check("⑧a Shift 대량 구매 = STORE_BULK개", m.inventory.seed_count(crop) == seeds_b + m.STORE_BULK)
	_check("⑧a2 대량 구매 골드 차감 = 정가×묶음", m.wallet.gold == 1000 - base * m.STORE_BULK)
	_check("⑧b 만물상 카탈로그 = store 종류 불변", m._buildings["만물상"]["kind"] == "store")

	# ── ⑨ 매대 그리드 승격(★ S1R-T12) + 누적 총수입 ──
	print("── ⑨ 매대 그리드 + 총수입 ──")
	var items: Array = m._store_items()
	# ★[S2-T4] 묘목 1(혼백도) + 비료 5 + 건초 1 + 스프링클러 1 = 씨앗 밖 8행(불변).
	# ★[S7-T2 / ADR-0065 결정 2] 씨앗은 이제 **제철만** 진열된다 — 옛 단언(4종 전량·12행)이 여기 있었다.
	#   기대 목록을 카탈로그에서 뽑아 대조하므로 절기 배정이 바뀌어도 이 단언은 계속 이빨을 갖는다.
	var season0: int = m.clock.season_index()
	var seed_rows: Array = items.filter(func(it): return it["kind"] == "seed")
	var want_seeds: Array = []
	for cid in CropCatalog.ids():
		if cid != CropCatalog.BULSAGWA and CropCatalog.in_season(String(cid), season0):
			want_seeds.append(cid)
	_check("⑨a _store_items = 제철 씨앗%d+묘목1+비료5+건초1+설치물1(%d행)"
		% [want_seeds.size(), want_seeds.size() + 8], items.size() == want_seeds.size() + 8)
	_check("⑨a1 ★제철 필터 — 진열 씨앗이 정확히 이번 절기 작물(그리고 최소 1종은 선다)",
		seed_rows.map(func(it): return it["buy_id"]) == want_seeds and want_seeds.size() >= 1)
	var off_season_row := false
	for sr in seed_rows:
		if not CropCatalog.in_season(String((sr as Dictionary)["buy_id"]), season0):
			off_season_row = true
	_check("⑨a1b 비제철 씨앗은 매대에 없다(단언에 이빨 — 4종 중 %d종이 빠졌다)"
		% (CropCatalog.ids().size() - 1 - want_seeds.size()),
		not off_season_row and want_seeds.size() < CropCatalog.ids().size() - 1)
	_check("⑨a1c 씨앗 표시명에 절기 병기(\"… 씨앗 (피안절)\")",
		String(seed_rows[0]["name"]).ends_with(" (%s)" % GameClock.season_name(season0)))
	# 카테고리 순서 고정(씨앗 → 묘목 → 비료 → 건초 → 설치물) — 진열 묶음 규약.
	var kinds_seq: Array = items.map(func(it): return it["kind"])
	var want_kinds: Array = []
	for _i9 in want_seeds.size():
		want_kinds.append("seed")
	want_kinds.append_array(["sapling", "fert", "fert", "fert", "fert", "fert", "hay", "placeable"])
	_check("⑨a2 카테고리 진열 순서", kinds_seq == want_kinds)
	var has_fields := true
	for it in items:
		if not (it.has("icon_id") and it.has("name") and it.has("price") and it.has("kind") and it.has("buy_id")):
			has_fields = false
	_check("⑨b 각 행에 아이콘·이름·가격·종류·구매id", has_fields)
	_check("⑨c 불사과(채집 전용)는 매대에 없음",
		items.all(func(it): return it["buy_id"] != CropCatalog.BULSAGWA))
	var last9: Dictionary = items[items.size() - 1]
	_check("⑨d 마지막 행 = 스프링클러(설치물)", last9["kind"] == "placeable" and last9["buy_id"] == ItemCatalog.SPRINKLER)
	# 행별 구매 = 선택 작물이 아니라 그 행의 작물을 산다(_on_frame_buy_seed).
	m.neo_affinity.points = 0
	m.neo_affinity.stage = 0
	m.wallet.gold = 1000
	var target: String = CropCatalog.PIANHWA   # _selected_crop(혼령초)과 다른 작물로 검증
	var tbase: int = CropCatalog.seed_cost(target)
	var seeds_t: int = m.inventory.seed_count(target)
	m._on_frame_buy_seed(target, false)
	_check("⑨e 행별 구매 = 그 행 작물 씨앗 +1", m.inventory.seed_count(target) == seeds_t + 1)
	_check("⑨f 행별 구매 골드 차감 = 정가", m.wallet.gold == 1000 - tbase)

	# ── ⑩ ★[S2-T4] 신규 입고 3종 구매(묘목·비료·건초) ──
	print("── ⑩ 신규 입고 구매(S2-T4) ──")
	m.neo_affinity.points = 0
	m.neo_affinity.stage = 0
	m.wallet.gold = 1000
	var fert_id: String = ItemCatalog.FERT_DELUXE
	var fert_base: int = FertilizerCatalog.buy_cost(fert_id)
	var fert0: int = m.inventory.count_of(fert_id)
	m._on_frame_buy_store_item(fert_id, "fert", false)
	_check("⑩a 비료 구매 = 인벤 +1", m.inventory.count_of(fert_id) == fert0 + 1)
	_check("⑩b 비료 구매 골드 차감 = 정가(♡0)", m.wallet.gold == 1000 - fert_base)
	var hay0: int = m.inventory.count_of(ItemCatalog.HAY)
	m._on_frame_buy_store_item(ItemCatalog.HAY, "hay", false)
	_check("⑩c 건초 구매 = 인벤 +1", m.inventory.count_of(ItemCatalog.HAY) == hay0 + 1)
	var sap0: int = m.inventory.sapling_count(FruitTreeCatalog.HONBAEKDO)
	var sap_base: int = FruitTreeCatalog.sapling_cost(FruitTreeCatalog.HONBAEKDO)
	m.wallet.gold = 1000
	m._on_frame_buy_store_item(FruitTreeCatalog.HONBAEKDO, "sapling", false)
	_check("⑩d 묘목 구매 = 묘목 +1", m.inventory.sapling_count(FruitTreeCatalog.HONBAEKDO) == sap0 + 1)
	_check("⑩e 묘목 구매 골드 차감 = 정가", m.wallet.gold == 1000 - sap_base)
	# 네오 ♡5 할인 = StoreDiscount 일관 적용(씨앗과 같은 규약).
	m.neo_affinity.points = 5 * m.neo_affinity.POINTS_PER_HEART
	m.neo_affinity.stage = Affinity.MAX_HEARTS
	m.wallet.gold = 1000
	var disc_unit: int = StoreDiscount.price(fert_base, 5)
	m._on_frame_buy_store_item(fert_id, "fert", false)
	_check("⑩f ♡5 할인 적용(비료)", m.wallet.gold == 1000 - disc_unit and disc_unit < fert_base)
	# 골드 부족 = 부분 구매 후 중단(대량 구매 규약 — 씨앗과 동일).
	m.neo_affinity.points = 0
	m.neo_affinity.stage = 0
	m.wallet.gold = fert_base * 2 + 1   # 5개 요청 중 2개만 살 수 있는 골드
	var fert1: int = m.inventory.count_of(fert_id)
	m._on_frame_buy_store_item(fert_id, "fert", true)   # bulk=STORE_BULK(5)
	_check("⑩g 골드 부족 = 부분 구매(2개)", m.inventory.count_of(fert_id) == fert1 + 2 and m.wallet.gold == 1)
	# 미지 kind·미지 id는 무동작(방어).
	var g0: int = m.wallet.gold
	m._on_frame_buy_store_item("no_such_id", "fert", false)
	m._on_frame_buy_store_item(fert_id, "no_such_kind", false)
	_check("⑩h 미지 id/kind = 무동작", m.wallet.gold == g0)
	# 누적 총수입 — 출하 정산분이 _total_income에 쌓인다(_on_day_advanced 실경로).
	m.ship_bin.pending.clear()
	m.ship_bin.add(crop, 2)
	var expect_inc: int = 2 * CropCatalog.sell_price(crop)
	var inc0: int = m._total_income
	m._on_day_advanced(2)
	_check("⑨g 총수입 누적(출하 정산분)", m._total_income == inc0 + expect_inc)
	m.ship_bin.pending.clear()

	# ── ⑦ 세이브 라운드트립(네오 호감도) ──
	print("── ⑦ 세이브 라운드트립 ──")
	m.neo_affinity.points = 2 * m.neo_affinity.POINTS_PER_HEART   # ♡2
	var saved_pts: int = m.neo_affinity.points
	m._save_game()
	m.queue_free()
	await process_frame
	await process_frame
	var m2: Node = await _spawn_main()
	_check("⑦ 네오 호감도 재개", m2.neo_affinity.points == saved_pts)
	m2.queue_free()
	await process_frame

	# ── 정리: 세이브 원복 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)
