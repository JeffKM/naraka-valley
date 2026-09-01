extends SceneTree
# ★[S7-T7 / ADR-0065 결정 9] 절기 행사 4종(오버레이) 검증 — ephemeral 헤드리스.
#
# CONTEXT [절기 행사]가 잠근 정체성이 코드에 그대로 서 있는지 본다: **오버레이 전용**(새 미니게임
# 엔진·새 장소 0) · **해금 = 처음부터**(테마 데이와 비대칭) · **옵트인 무손실**(안 해도 게이트 0).
#
# ★ 핵심 불변식:
#   ① 달력 — 피안 12(더비)·유화 20(해파리)·망연 16(장원제)·성야 15(야시장). 그 밖은 평일.
#      테마 데이(25일)와 **날짜가 겹치지 않는다**. 해금 입력이 없다(처음부터).
#   ② 더비 — 태그 롤이 (day, 어획 순번)에 결정적 · 교환 사다리 3단 · **당일 소멸**(날 바뀌면 0) ·
#      지급 실패 시 태그 미소비 · 삼도천 아닌 무대·행사일 아닌 날엔 롤 자체가 없다.
#   ③ 해파리 창 — 유화 20일 **저녁·밤 + 황천해**에서만 출현이 뛴다. 창 밖 저녁은 카탈로그 규칙대로
#      0(혼불해파리는 평소 밤 전용)이고, 기존 어종 롤 구조는 한 줄도 안 바뀐다.
#   ④ 장원제 — 다양성 2/종 + 판매가 밴드 + 제철 3/종 · 9종 상한 · 등급 3단 · **곳간 재고 불변**(전시) ·
#      하루 1회.
#   ⑤ 야시장 — 품목 4행(가구 2 + 한정 1 + 씨앗 1) · 전 품목 2할 할인 · 한정 물품 1회 한정 ·
#      가구 세트는 목공방과 같은 해금 원장을 민다(이중 진실원 0).
#   ⑥ 비참여 무손실 — 행사일에 아무것도 안 해도 지갑·인벤·곳간이 그대로다.
#   ⑦ 세이브 — "seasonal_event" 가법 키 왕복 · 키 없는 구세이브는 빈 원장(막힘 0).
# 실행: godot --headless --path game --script res://playtest/seasonal_event_test.gd

var _fail := 0

# 절기 s(0~3)의 행사일 = s*28 + DAY_OF_SEASON[s].
func _event_day(s: int) -> int:
	return s * GameClock.DAYS_PER_SEASON + int(SeasonalEvent.DAY_OF_SEASON[s])

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

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 황천해 저녁/밤 캐스팅을 n번 굴려 혼불해파리가 나온 비율(0..1). 무대는 _region 직접 주입
# (워프 없이 `_roll_fish_id`가 보는 축만 세운다 — 이 함수가 읽는 건 region·day·phase뿐이다).
func _jelly_ratio(m: Node, day: int, minute: int, n: int) -> float:
	m._region = RegionCatalog.HWANGCHEONHAE
	m.clock.day = day
	m.clock.minutes = float(minute)
	var hit := 0
	for i in n:
		if m._roll_fish_id(1000 + i * 7919) == SeasonalEvent.JELLY_FISH_ID:
			hit += 1
	return float(hit) / float(n)

func _initialize() -> void:
	print("══ S7-T7 절기 행사 4종(오버레이) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s7_t7_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var d_derby := _event_day(0)    # 피안 12일  = 12
	var d_jelly := _event_day(1)    # 유화 20일  = 48
	var d_grange := _event_day(2)   # 망연 16일  = 72
	var d_market := _event_day(3)   # 성야 15일  = 99

	# ── ① 달력(순수 단위 — 인스턴스 불필요) ──
	print("── ① 달력 ──")
	_check("①a 절기 내 일차 = 12·20·16·15", SeasonalEvent.DAY_OF_SEASON == [12, 20, 16, 15])
	_check("①b 각 절기 행사일이 그 절기의 행사", SeasonalEvent.event_for_day(d_derby) == SeasonalEvent.DERBY
		and SeasonalEvent.event_for_day(d_jelly) == SeasonalEvent.JELLYFISH
		and SeasonalEvent.event_for_day(d_grange) == SeasonalEvent.GRANGE
		and SeasonalEvent.event_for_day(d_market) == SeasonalEvent.NIGHT_MARKET)
	var plain_ok := true
	for d in [d_derby - 1, d_derby + 1, d_jelly - 1, d_jelly + 1, d_grange + 1, d_market - 1]:
		if SeasonalEvent.is_event_day(d):
			plain_ok = false
	_check("①c 전날·다음날은 평일", plain_ok)
	_check("①d 2년차도 같은 자리(+112)",
		SeasonalEvent.event_for_day(d_derby + 4 * GameClock.DAYS_PER_SEASON) == SeasonalEvent.DERBY)
	_check("①e day 0·음수 = 평일(손상 방어)", SeasonalEvent.event_for_day(0) == SeasonalEvent.NONE
		and SeasonalEvent.event_for_day(-12) == SeasonalEvent.NONE)
	# ★ 두 층(행사·테마 데이)의 날짜 비충돌 — 한 절기에 두 이벤트가 같은 날에 겹치지 않는다.
	var no_clash := true
	for s in 4:
		if int(SeasonalEvent.DAY_OF_SEASON[s]) == Festival.DAY_OF_SEASON:
			no_clash = false
		if Festival.is_theme_slot(_event_day(s)):
			no_clash = false
	_check("①f 테마 데이(25일)와 날짜 비충돌", no_clash)
	_check("①g 표시명 4종 + 범위 밖 \"\"", SeasonalEvent.name_of(SeasonalEvent.DERBY) == "삼도천 낚시 더비"
		and SeasonalEvent.name_of(SeasonalEvent.NIGHT_MARKET) == "저승 야시장"
		and SeasonalEvent.name_of(SeasonalEvent.NONE) == "")
	_check("①h 배너·예고 문구가 4행사 전부 비어 있지 않다",
		SeasonalEvent.banner_text(SeasonalEvent.DERBY) != ""
		and SeasonalEvent.banner_text(SeasonalEvent.JELLYFISH) != ""
		and SeasonalEvent.banner_text(SeasonalEvent.GRANGE) != ""
		and SeasonalEvent.banner_text(SeasonalEvent.NIGHT_MARKET) != ""
		and SeasonalEvent.preview_text(SeasonalEvent.GRANGE) != ""
		and SeasonalEvent.banner_text(SeasonalEvent.NONE) == "")
	_check("①i 점괘 거울 한 줄 문법(오늘·내일·N일 뒤)",
		SeasonalEvent.upcoming_text(SeasonalEvent.DERBY, 0) == "오늘: 삼도천 낚시 더비"
		and SeasonalEvent.upcoming_text(SeasonalEvent.DERBY, 1) == "내일: 삼도천 낚시 더비"
		and SeasonalEvent.upcoming_text(SeasonalEvent.DERBY, 3) == "3일 뒤: 삼도천 낚시 더비")

	# ── ② 더비 — 롤 결정성 · 교환 테이블(순수 단위) ──
	print("── ② 더비(롤·교환 테이블) ──")
	var det := true
	for i in range(1, 40):
		if SeasonalEvent.roll_tag(d_derby, i) != SeasonalEvent.roll_tag(d_derby, i):
			det = false
	_check("②a 태그 롤이 (day, 순번)에 결정적", det)
	var hits := 0
	for i in range(1, 401):
		if SeasonalEvent.roll_tag(d_derby, i):
			hits += 1
	# rand_from_seed 믹싱이 걸려 있으면 33% 근처로 수렴한다(hash 직접 롤이면 분위가 뭉쳐 크게 어긋난다).
	_check("②b 400회 태그율 ≈ 33%%(실측 %.1f%% — rand_from_seed 믹싱)" % (hits / 4.0),
		hits >= 100 and hits <= 165)
	_check("②c 다른 날은 다른 출목열(시드에 day가 섞인다)",
		SeasonalEvent.roll_tag(d_derby, 1) != SeasonalEvent.roll_tag(d_derby + 112, 1)
		or SeasonalEvent.roll_tag(d_derby, 2) != SeasonalEvent.roll_tag(d_derby + 112, 2)
		or SeasonalEvent.roll_tag(d_derby, 3) != SeasonalEvent.roll_tag(d_derby + 112, 3))
	_check("②d 교환 사다리 = 품질 비료 3 → 혼합 씨앗 5 → 엽전 120(이후 반복)",
		String(SeasonalEvent.derby_reward(1)["kind"]) == "fert"
		and int(SeasonalEvent.derby_reward(1)["n"]) == 3
		and String(SeasonalEvent.derby_reward(2)["kind"]) == "seed"
		and String(SeasonalEvent.derby_reward(3)["kind"]) == "gold"
		and int(SeasonalEvent.derby_reward(9)["n"]) == 120)
	_check("②e 0번째 교환 = 빈 dict(방어)", SeasonalEvent.derby_reward(0).is_empty())

	# ── ③ 장원제 채점(순수 단위) ──
	print("── ③ 장원제 채점 ──")
	_check("③a 밴드 경계(300=8 · 299=6 · 150=6 · 79=2 · 0=1)",
		SeasonalEvent.band_points(300) == 8 and SeasonalEvent.band_points(299) == 6
		and SeasonalEvent.band_points(150) == 6 and SeasonalEvent.band_points(79) == 2
		and SeasonalEvent.band_points(0) == 1)
	_check("③b 1종 최저가 = 다양성 2 + 밴드 1 = 3점",
		SeasonalEvent.score_entries([{"price": 0, "in_season": false}]) == 3)
	_check("③c 제철 가점 +3", SeasonalEvent.score_entries([{"price": 0, "in_season": true}]) == 6)
	_check("③d 다양성이 종수에 비례(3종 = 다양성 6 + 밴드 3)",
		SeasonalEvent.score_entries([{"price": 0, "in_season": false}, {"price": 0, "in_season": false},
			{"price": 0, "in_season": false}]) == 9)
	var many: Array = []
	for i in 20:
		many.append({"price": 999, "in_season": true})
	_check("③e 9종 상한(20종 넣어도 9종분 = 18+72+27 = 117점)",
		SeasonalEvent.score_entries(many) == 117)
	_check("③f 등급 3단 문턱(11 선외 · 12 입선 · 30 우수 · 55 장원)",
		SeasonalEvent.grange_rank(11) == -1 and SeasonalEvent.grange_rank(12) == 0
		and SeasonalEvent.grange_rank(30) == 1 and SeasonalEvent.grange_rank(55) == 2)
	_check("③g 등급 이름·보상(선외 0냥 · 입선 300 · 우수 800 · 장원 1500)",
		SeasonalEvent.grange_rank_name(-1) == "선외" and SeasonalEvent.grange_rank_name(2) == "장원"
		and SeasonalEvent.grange_gold(-1) == 0 and SeasonalEvent.grange_gold(0) == 300
		and SeasonalEvent.grange_gold(1) == 800 and SeasonalEvent.grange_gold(2) == 1500)

	# ── ④ 야시장 로스터·할인(순수 단위) ──
	print("── ④ 야시장 로스터·할인 ──")
	var rows: Array = SeasonalEvent.market_rows()
	_check("④a 로스터 4행(가구 2 + 한정 1 + 씨앗 1)", rows.size() == 4
		and String(rows[0]["kind"]) == "fest_deco" and String(rows[1]["kind"]) == "fest_deco"
		and String(rows[2]["kind"]) == "fest_item" and String(rows[3]["kind"]) == "fest_seed")
	_check("④b 가구 세트 정가는 HomeDecoCatalog가 진실원(중복 표 0)",
		int(rows[0]["base"]) == HomeDecoCatalog.price_of("JEOSEUNGSOL")
		and int(rows[1]["base"]) == HomeDecoCatalog.price_of("JAETNUN"))
	_check("④c 행사 할인 2할(3000→2400 · 6000→4800 · 2500→2000)",
		SeasonalEvent.market_price(3000) == 2400 and SeasonalEvent.market_price(6000) == 4800
		and SeasonalEvent.market_price(SeasonalEvent.MARKET_RARECROW_PRICE) == 2000)
	_check("④d 한정 물품 = 레어크로우 ②(비매 수집물 — ①과 같은 규칙)",
		ItemCatalog.has_item(ItemCatalog.RARECROW_2)
		and ItemCatalog.price_of(ItemCatalog.RARECROW_2) == 0
		and SeasonalEvent.MARKET_RARECROW == ItemCatalog.RARECROW_2)

	var m: Node = await _spawn_main()

	# ── ⑤ 아침 배너·점괘 거울 예고(main 통합) ──
	print("── ⑤ 배너·예고 ──")
	m.clock.day = d_derby
	var b_today: Array = m._seasonal_morning_notices()
	_check("⑤a 당일 아침 = 개막 배너 1줄", b_today.size() == 1
		and String(b_today[0]).begins_with("오늘은") and String(b_today[0]).contains("삼도천 낚시 더비"))
	m.clock.day = d_derby - 1
	var b_prev: Array = m._seasonal_morning_notices()
	_check("⑤b D-1 = 예고 배너 1줄", b_prev.size() == 1 and String(b_prev[0]).begins_with("내일은"))
	m.clock.day = d_derby - 2
	_check("⑤c D-2는 조용(배너 0줄)", m._seasonal_morning_notices().is_empty())
	m.clock.day = d_derby - 3
	_check("⑤d 점괘 거울에 행사 예고 한 줄", m._event_upcoming_line() == "3일 뒤: 삼도천 낚시 더비"
		and m._mirror_forecast_text().contains("삼도천 낚시 더비"))
	m.clock.day = 20   # 피안 20일 — 다음 행사는 유화 20일(48), 테마 데이는 피안 25일(25)
	_check("⑤e 테마 데이 줄과 행사 줄이 서로를 가리지 않는다(두 층 병렬)",
		m._event_upcoming_line() != "" and m._event_upcoming_line() != m._festival_upcoming_line())

	# ── ⑥ 더비 원장(main 통합 — 무대·행사일 게이트 · 당일 소멸 · 교환 지급) ──
	print("── ⑥ 더비 원장·교환 ──")
	m.clock.day = d_derby
	m._region = RegionCatalog.SAMDOCHEON
	m._indoor = ""
	m._sleeping = false
	m.seasonal_event.load_save({})   # 빈 원장에서 시작
	for i in 30:
		m._note_derby_catch()
	var tags_after: int = m.seasonal_event.tags_on(d_derby)
	_check("⑥a 삼도천 행사일 어획 30건 → 태그가 붙는다(%d개)" % tags_after,
		tags_after > 0 and m.seasonal_event.derby_catches == 30)
	m._region = RegionCatalog.HWANGCHEONHAE
	var before_sea: int = m.seasonal_event.derby_catches
	m._note_derby_catch()
	_check("⑥b 다른 무대(황천해) 어획은 더비에 안 잡힌다",
		m.seasonal_event.derby_catches == before_sea)
	m._region = RegionCatalog.SAMDOCHEON
	m.clock.day = d_derby + 1                      # 행사 다음 날
	var before_plain: int = m.seasonal_event.derby_catches
	m._note_derby_catch()
	_check("⑥c 행사일이 아니면 롤 자체가 없다", m.seasonal_event.derby_catches == before_plain)
	_check("⑥d 태그는 당일 소멸(날이 바뀌면 0)", m.seasonal_event.tags_on(d_derby + 1) == 0)
	# 교환 — 태그를 손으로 세우고(롤 확률 의존 제거) 사다리 3단을 그대로 받는다.
	m.clock.day = d_derby
	m.seasonal_event.load_save({"derby_day": d_derby, "derby_tags": 3, "derby_exchanges": 0})
	m.wallet.gold = 0
	var fert_before: int = m.inventory.count_of(FertilizerCatalog.FERT_QUALITY)
	m._try_derby_exchange()
	var seed_item := ItemCatalog.seed_id(SeasonalEvent.MARKET_SEED_CROP)
	var seed_before: int = m.inventory.count_of(seed_item)
	m._try_derby_exchange()
	m._try_derby_exchange()
	_check("⑥e 교환 3회 = 품질 비료 3 · 혼합 씨앗 5 · 엽전 120",
		m.inventory.count_of(FertilizerCatalog.FERT_QUALITY) == fert_before + 3
		and m.inventory.count_of(seed_item) == seed_before + 5
		and m.wallet.gold == 120)
	_check("⑥f 태그 3개를 다 썼다", m.seasonal_event.tags_on(d_derby) == 0
		and m.seasonal_event.derby_exchanges == 3)
	var gold_hold: int = m.wallet.gold
	m._try_derby_exchange()
	_check("⑥g 태그 0이면 교환이 안 일어난다(무손실)", m.wallet.gold == gold_hold
		and m.seasonal_event.derby_exchanges == 3)
	m._target = DERBY_BOOTH_TILE_OF(m)
	_check("⑥h 부스 facing = 행사일 · 삼도천 야외 · 그 칸", m._facing_derby_booth())
	m.clock.day = d_derby + 1
	_check("⑥i 행사일이 아니면 부스가 없다(facing false)", not m._facing_derby_booth())

	# ── ⑦ 해파리 창(창 안/밖 · 저녁/밤 · 무대) ──
	print("── ⑦ 해파리 창 ──")
	_check("⑦a 창 판정 = 그날 저녁·밤만",
		SeasonalEvent.is_jelly_window(d_jelly, "저녁") and SeasonalEvent.is_jelly_window(d_jelly, "밤")
		and not SeasonalEvent.is_jelly_window(d_jelly, "낮")
		and not SeasonalEvent.is_jelly_window(d_jelly, "아침")
		and not SeasonalEvent.is_jelly_window(d_jelly + 1, "밤"))
	var r_out_eve := _jelly_ratio(m, d_jelly + 1, 19 * 60, 200)   # 창 밖 저녁
	var r_in_eve := _jelly_ratio(m, d_jelly, 19 * 60, 200)        # 창 안 저녁
	_check("⑦b 창 밖 저녁 = 0(혼불해파리는 평소 밤 전용 — 카탈로그 규칙 불변)", is_zero_approx(r_out_eve))
	_check("⑦c 창 안 저녁 = 확률 대폭↑(실측 %.0f%%)" % (r_in_eve * 100.0), r_in_eve >= 0.40)
	var r_out_night := _jelly_ratio(m, d_jelly + 1, 22 * 60, 200)
	var r_in_night := _jelly_ratio(m, d_jelly, 22 * 60, 200)
	_check("⑦d 창 안 밤 > 평소 밤(실측 %.0f%% > %.0f%%)" % [r_in_night * 100.0, r_out_night * 100.0],
		r_in_night > r_out_night)
	m._region = RegionCatalog.SAMDOCHEON
	m.clock.day = d_jelly
	m.clock.minutes = 22.0 * 60.0
	var river_jelly := false
	for i in 60:
		if m._roll_fish_id(500 + i * 131) == SeasonalEvent.JELLY_FISH_ID:
			river_jelly = true
	_check("⑦e 삼도천(강)에는 안 뜬다(무대 축 보존)", not river_jelly)

	# ── ⑧ 장원제(main 통합 — 곳간 재고 불변 · 하루 1회) ──
	print("── ⑧ 장원제 통합 ──")
	m.clock.day = d_grange
	m.seasonal_event.load_save({})
	m.larder.stock = {}
	for cid in CropCatalog.ids():
		m.larder.add(cid, 2)
	var stock_before: Dictionary = m.larder.stock.duplicate(true)
	var total_before: int = m.larder.total()
	var entries: Array = m._grange_entries()
	_check("⑧a 출품 목록 = 곳간 재고에서 최대 9종",
		entries.size() == mini(m.larder.ids().size(), SeasonalEvent.GRANGE_MAX_ENTRIES)
		and entries.size() > 0)
	var sorted_desc := true
	for i in range(1, entries.size()):
		if int(entries[i]["price"]) > int(entries[i - 1]["price"]):
			sorted_desc = false
	_check("⑧b 판매가 높은 순 정렬(플레이어 최적 선별)", sorted_desc)
	var gold_pre: int = m.wallet.gold
	var expect_score: int = SeasonalEvent.score_entries(entries)
	var expect_rank: int = SeasonalEvent.grange_rank(expect_score)
	m._try_grange_entry()
	_check("⑧c 출품해도 곳간 재고가 한 톨도 안 줄어든다(전시)",
		m.larder.total() == total_before and m.larder.stock == stock_before)
	_check("⑧d 등급 보상 지급(+%d냥)" % SeasonalEvent.grange_gold(expect_rank),
		m.wallet.gold == gold_pre + SeasonalEvent.grange_gold(expect_rank))
	_check("⑧e 출품 이력 기록(최고 등급 갱신)", m.seasonal_event.grange_entered(d_grange)
		and m.seasonal_event.grange_best == expect_rank)
	var gold_after: int = m.wallet.gold
	m._try_grange_entry()
	_check("⑧f 하루 1회 — 재출품은 보상 0", m.wallet.gold == gold_after)
	m.clock.day = d_grange + 1
	_check("⑧g 다음 날은 출품 이력이 풀린다(내년 재개최를 위해)",
		not m.seasonal_event.grange_entered(d_grange + 1))
	# 빈 곳간이면 안내만 — 손실 0.
	m.clock.day = d_grange
	m.seasonal_event.load_save({})
	m.larder.stock = {}
	var gold_empty: int = m.wallet.gold
	m._try_grange_entry()
	_check("⑧h 곳간이 비면 출품이 안 열린다(무손실·이력 0)", m.wallet.gold == gold_empty
		and not m.seasonal_event.grange_entered(d_grange))

	# ── ⑨ 야시장(main 통합 — 매대 행 · 구매 · 1회 한정) ──
	print("── ⑨ 야시장 통합 ──")
	m.clock.day = d_market
	m._region = RegionCatalog.NARU_VILLAGE
	m._indoor = ""
	m.seasonal_event.load_save({})
	var items: Array = m._night_market_items()
	_check("⑨a 매대 4행 · 표시가 = 정가의 8할", items.size() == 4
		and int(items[0]["price"]) == SeasonalEvent.market_price(int(items[0]["base"]))
		and int(items[0]["price"]) < int(items[0]["base"]))
	_check("⑨b 헤더에 할인율이 뜬다", m._night_market_text().contains("2할") \
		or m._night_market_text().contains("20%"))
	# 가구 세트 — 목공방과 **같은 해금 원장**을 민다.
	m.wallet.gold = 99999
	var set_price := SeasonalEvent.market_price(HomeDecoCatalog.price_of("JEOSEUNGSOL"))
	var gold_b: int = m.wallet.gold
	_check("⑨c 가구 세트 구매 전엔 미해금", not m.home_deco.is_unlocked("JEOSEUNGSOL"))
	m._on_frame_buy_store_item("JEOSEUNGSOL", "fest_deco", false)
	_check("⑨d 가구 세트 해금 + 할인가만큼 지출", m.home_deco.is_unlocked("JEOSEUNGSOL")
		and m.wallet.gold == gold_b - set_price)
	var rows2: Array = m._night_market_items()
	_check("⑨e 해금된 세트 행은 잠긴다(재구매 불가)", bool(rows2[0].get("locked", false)))
	# 한정 물품 — 1회 한정.
	var rare_price := SeasonalEvent.market_price(SeasonalEvent.MARKET_RARECROW_PRICE)
	var gold_c: int = m.wallet.gold
	m._on_frame_buy_store_item(ItemCatalog.RARECROW_2, "fest_item", false)
	_check("⑨f 한정 물품 획득 + 할인가 지출",
		m.inventory.count_of(ItemCatalog.RARECROW_2) == 1 and m.wallet.gold == gold_c - rare_price)
	var gold_d: int = m.wallet.gold
	m._on_frame_buy_store_item(ItemCatalog.RARECROW_2, "fest_item", false)
	_check("⑨g 두 번째 구매는 거절(1회 한정 — 엽전 안 나감)",
		m.inventory.count_of(ItemCatalog.RARECROW_2) == 1 and m.wallet.gold == gold_d)
	# 씨앗 — 스택 소매.
	var seed_pre: int = m.inventory.count_of(seed_item)
	var gold_e: int = m.wallet.gold
	m._on_frame_buy_store_item(SeasonalEvent.MARKET_SEED_CROP, "fest_seed", false)
	# ★[폴리시 R4 #1] 단가 출처는 `market_seed_price()` 하나다 — 종전엔 이 줄이 `seed_cost(MIXED)`를
	#   따로 굴려, 그 값이 "상점가 아님(출하 잔가)"인 5냥이라는 사실을 테스트가 함께 못 보고 통과했다.
	var seed_unit := SeasonalEvent.market_price(SeasonalEvent.market_seed_price())
	_check("⑨h 씨앗 1개 소매(할인가 %d냥)" % seed_unit, m.inventory.count_of(seed_item) == seed_pre + 1
		and m.wallet.gold == gold_e - seed_unit)
	_check("⑨h2 그 단가가 잔가 파생(seed_cost(MIXED) %d냥)이 아니다 — 정규 씨앗 대체품 차단"
			% CropCatalog.seed_cost(SeasonalEvent.MARKET_SEED_CROP),
		seed_unit > SeasonalEvent.market_price(CropCatalog.seed_cost(SeasonalEvent.MARKET_SEED_CROP)))
	m._target = NIGHT_MARKET_TILE_OF(m)
	_check("⑨i 매대 facing = 행사일 · 마을 야외 · 그 칸", m._facing_night_market())
	m.clock.day = d_market + 1
	_check("⑨j 행사일이 아니면 매대가 없다(facing false)", not m._facing_night_market())
	# ★ 결제 층의 행사일 재검증 — facing(표시)만 재던 자리의 공백을 메운다. 매대 프레임은 자정을
	#   넘겨도 안 닫히므로(쓰러지면 그대로 하루가 간다) **결제 순간에 오늘을 다시 묻지 않으면**
	#   행사가 파한 날에도 2할 할인·한정 물품이 계속 나간다. 보부상 `_peddler_price`가 이미 막아 둔
	#   그 구멍이라, 여기서도 세 경로(가구·한정 물품·씨앗) 전부를 같은 문법으로 잰다.
	#   ★ 값을 세 축으로 대조한다: 지갑 불변 · 해금 원장 불변 · 인벤 수량 불변(카운트 하나만 세면
	#     "샀는데 알림만 없다"를 못 잡는다).
	var gold_k: int = m.wallet.gold
	var seed_k: int = m.inventory.count_of(seed_item)
	var rare_k: int = m.inventory.count_of(ItemCatalog.RARECROW_2)
	_check("⑨k pre 행사 다음 날 · 미해금 세트가 남아 있다",
		m._seasonal_event_today() != SeasonalEvent.NIGHT_MARKET
		and not m.home_deco.is_unlocked("JAETNUN"))
	m._on_frame_buy_store_item("JAETNUN", "fest_deco", false)
	_check("⑨l ★행사 다음 날 가구 세트 구매 불성립(해금 0 · 엽전 0)",
		not m.home_deco.is_unlocked("JAETNUN") and m.wallet.gold == gold_k)
	m.seasonal_event.market_bought.clear()   # 1회 한정 가드를 걷어 **날짜 가드만** 남긴다
	m._on_frame_buy_store_item(ItemCatalog.RARECROW_2, "fest_item", false)
	_check("⑨m ★행사 다음 날 한정 물품 구매 불성립(수량·엽전·구매 이력 전부 불변)",
		m.inventory.count_of(ItemCatalog.RARECROW_2) == rare_k and m.wallet.gold == gold_k
		and not m.seasonal_event.has_bought(ItemCatalog.RARECROW_2))
	m._on_frame_buy_store_item(SeasonalEvent.MARKET_SEED_CROP, "fest_seed", false)
	_check("⑨n ★행사 다음 날 씨앗 소매 불성립(씨앗 수·엽전 불변)",
		m.inventory.count_of(seed_item) == seed_k and m.wallet.gold == gold_k)
	# 근원 봉합 — 매대를 연 채 자정을 넘기면(쓰러짐 → `_do_sleep`) 프레임이 하루를 못 넘긴다.
	m.clock.day = d_market
	m.seasonal_event.load_save({})
	m._open_frame(InventoryFrame.CTX_NIGHTMARKET)
	_check("⑨o pre 야시장 프레임이 열렸다",
		m.frame.is_open() and m.frame.context == InventoryFrame.CTX_NIGHTMARKET)
	m._do_sleep()
	_check("⑨p ★취침(쓰러짐)이 열린 매대를 닫는다 — 어제 매대가 오늘 아침까지 남지 않는다",
		not m.frame.is_open())
	# 하네스 원복 — 취침 연출 트윈을 죽여 **하루가 실제로 넘어가지 않게** 한다(넘어가면 아래
	# ⑩·⑪ 블록이 재는 지갑·곳간 원장이 정산으로 흔들린다).
	for tw in get_processed_tweens():
		tw.kill()
	m._sleeping = false
	m.fade.modulate.a = 0.0
	m.player.set_physics_process(true)
	m.clock.running = true

	# ── ⑩ 비참여 무손실 ──
	print("── ⑩ 비참여 무손실 ──")
	m.clock.day = d_market
	m.seasonal_event.load_save({})
	var gold_x: int = m.wallet.gold
	var inv_x: int = m.inventory.total_harvest() if m.inventory.has_method("total_harvest") else 0
	var larder_x: int = m.larder.total()
	m._refresh_festival()
	await process_frame
	_check("⑩ 행사일에 아무것도 안 해도 지갑·곳간이 그대로다(옵트인)",
		m.wallet.gold == gold_x and m.larder.total() == larder_x
		and (m.inventory.total_harvest() if m.inventory.has_method("total_harvest") else 0) == inv_x)

	# ── ⑪ 세이브 왕복(가법 키) ──
	print("── ⑪ 세이브 왕복 ──")
	m.clock.day = d_derby
	m.seasonal_event.load_save({"derby_day": d_derby, "derby_catches": 7, "derby_tags": 2,
		"derby_exchanges": 1, "grange_day": d_grange, "grange_best": 2,
		"market_bought": [ItemCatalog.RARECROW_2]})
	m._save_game()
	var saved: Dictionary = m.saver.load_game()
	_check("⑪a 세이브에 \"seasonal_event\" 키가 있다", saved.has("seasonal_event"))
	m.queue_free()
	await process_frame
	await process_frame
	var m2: Node = await _spawn_main()
	_check("⑪b 더비 원장 복원(태그 2 · 교환 1 · 어획 7)",
		m2.seasonal_event.tags_on(d_derby) == 2 and m2.seasonal_event.derby_exchanges == 1
		and m2.seasonal_event.derby_catches == 7)
	_check("⑪c 장원제·야시장 이력 복원", m2.seasonal_event.grange_entered(d_grange)
		and m2.seasonal_event.grange_best == 2
		and m2.seasonal_event.has_bought(ItemCatalog.RARECROW_2))
	m2.seasonal_event.load_save({})
	_check("⑪d 키 없는 구세이브 = 빈 원장(막힘 0)", m2.seasonal_event.derby_tags == 0
		and m2.seasonal_event.grange_best == -1 and m2.seasonal_event.market_bought.is_empty())
	m2.seasonal_event.load_save({"derby_tags": -5, "grange_best": 99, "market_bought": "쓰레기"})
	_check("⑪e 손상 세이브 방어(음수·범위 초과·타입 불일치)", m2.seasonal_event.derby_tags == 0
		and m2.seasonal_event.grange_best <= 2 and m2.seasonal_event.market_bought.is_empty())

	# ── ⑫ 행사 표식 _draw — **그 무대에 실제로 서서** 크래시 없이 돈다 ──
	# 구역을 실제로 세우지 않으면 _draw의 match가 그 갈래를 안 타 표식 코드가 통째로 안 굴러간다
	# (덤프 없이 "통과"가 찍히는 헛 단언 방지 — 그래서 _rebuild_region으로 무대를 진짜 옮긴다).
	print("── ⑫ 표식 _draw ──")
	m2._rebuild_region(RegionCatalog.NARU_VILLAGE)
	m2.clock.day = d_market
	_check("⑫pre-a 나루 마을 · 야시장 당일", m2._region == RegionCatalog.NARU_VILLAGE
		and m2._seasonal_event_today() == SeasonalEvent.NIGHT_MARKET)
	m2.queue_redraw()
	await process_frame
	await process_frame
	m2._rebuild_region(RegionCatalog.SAMDOCHEON)
	m2.clock.day = d_derby
	m2.seasonal_event.load_save({"derby_day": d_derby, "derby_tags": 2})   # 태그 표식(금빛 점)까지 그린다
	_check("⑫pre-b 삼도천 · 더비 당일 · 태그 보유", m2._region == RegionCatalog.SAMDOCHEON
		and m2._seasonal_event_today() == SeasonalEvent.DERBY
		and m2.seasonal_event.tags_on(d_derby) == 2)
	m2.queue_redraw()
	await process_frame
	await process_frame
	# 여기까지 예외 없이 도달하면 두 표식의 좌표·draw 호출이 안전히 돌았다.
	_check("⑫ 더비 부스·야시장 매대 _draw 크래시 없음", true)
	m2.queue_free()
	await process_frame

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)

# main의 const 타일 좌표를 읽는 얇은 헬퍼(스크립트 상수는 인스턴스를 통해 읽는다).
func DERBY_BOOTH_TILE_OF(m: Node) -> Vector2i:
	return m.get_script().get_script_constant_map()["DERBY_BOOTH_TILE"]

func NIGHT_MARKET_TILE_OF(m: Node) -> Vector2i:
	return m.get_script().get_script_constant_map()["NIGHT_MARKET_TILE"]
