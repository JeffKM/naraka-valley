extends SceneTree
# T7.2 임시 헤드리스 단위검증 — cafe_milestone.gd(카페 일구기 사다리) 계약 + main 통합을 검증한다.
# ★[S6-T3 / ADR-0064 결정 7] 축 둘 추가: ⑧ 바나 ♡가 게이트에 무영향(하트 축 = 미호+멜) ·
#   ⑨ 2단 사다리(단계 판정 + 해금 콘텐츠 넷[좌석·곳간 용량·메뉴판 슬롯·손님 볼륨]이 실제로 달라짐
#   + 2단 팝업 래치 + 2단 세이브 재개).
# weave_test·cafe_margin_test와 같은 결: ① 순수 정적 규칙(목표치·진행도·AND 게이트·문구)을
# CafeMilestone로 직접 검증하고, ② 매크로 목표가 main.gd(오케스트레이션)에 살아 — 누적 서빙
# 매출 적립·세 루프 산출물 파생·달성 팝업 래치·세이브 라운드트립 — 있는지를 main 씬으로 결정화한다.
# 실행: godot --headless --path game --script res://playtest/milestone_test.gd

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

# 신규 시작은 _ready가 옥자 통보 대화를 띄운다 — 열려 있으면 _process가 early-return해 마일스톤
# HUD·완료 판정이 돌지 않는다. _process 의존 검증 전에 통보를 끝까지 넘겨 닫는다(weave_test와 동일).
func _dismiss_intro(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ T7.2 카페 마일스톤 1단 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()  # 결정적 검증 — 디스크 세이브를 비우고 시작

	var TH := CafeMilestone.TARGET_HARVEST
	var TR := CafeMilestone.TARGET_REVENUE
	var THE := CafeMilestone.TARGET_HEARTS

	# ══════════════ ① 진행 비율 — 각 하위 목표 채움 [0,1], 초과는 1.0로 잘림 ══════════════
	_check("① 0 산출물 → 비율 0", is_equal_approx(CafeMilestone.harvest_ratio(0), 0.0))
	_check("①b 목표 도달 → 비율 1.0", is_equal_approx(CafeMilestone.harvest_ratio(TH), 1.0))
	_check("①c 목표 초과 → 1.0로 잘림(과달성이 바를 넘지 않음)", is_equal_approx(CafeMilestone.harvest_ratio(TH * 3), 1.0))
	_check("①d 매출 비율도 같은 결", is_equal_approx(CafeMilestone.revenue_ratio(TR), 1.0))
	_check("①e 하트 비율도 같은 결", is_equal_approx(CafeMilestone.hearts_ratio(THE), 1.0))
	_check("①f 음수 산출물 방어 → 0", is_equal_approx(CafeMilestone.harvest_ratio(-5), 0.0))

	# ══════════════ ② 진행 바 하나 = 세 비율 평균(셋 다 채워야 100%) ══════════════
	_check("② 셋 다 0 → overall 0", is_equal_approx(CafeMilestone.overall_ratio(0, 0, 0), 0.0))
	_check("②b 셋 다 목표 → overall 1.0", is_equal_approx(CafeMilestone.overall_ratio(TH, TR, THE), 1.0))
	# 한 축만 초과 달성해도 나머지가 0이면 바는 1/3 이하 — '한 루프만 갈아선 안 찬다'(멀티루프 요구).
	_check("②c 한 축만 만렙(초과)·나머지 0 → overall < 0.4(한 루프로 못 채움)",
		CafeMilestone.overall_ratio(TH * 5, 0, 0) < 0.4)
	# 두 축 채우고 한 축만 비어도 100% 미만(AND 요구를 바가 반영).
	_check("②d 두 축 채우고 한 축 0 → overall < 1.0", CafeMilestone.overall_ratio(TH, TR, 0) < 1.0)

	# ══════════════ ③ 1단 완료 = AND 게이트(세 산출물 *각각* 달성) ══════════════
	_check("③ 셋 다 도달 → 완료", CafeMilestone.is_complete(TH, TR, THE))
	_check("③b 셋 다 초과 → 완료", CafeMilestone.is_complete(TH + 9, TR + 99, THE + 7))
	_check("③c 작물만 모자라면 미완료", not CafeMilestone.is_complete(TH - 1, TR, THE))
	_check("③d 매출만 모자라면 미완료", not CafeMilestone.is_complete(TH, TR - 1, THE))
	_check("③e 친밀만 모자라면 미완료", not CafeMilestone.is_complete(TH, TR, THE - 1))
	_check("③f 셋 다 0이면 미완료", not CafeMilestone.is_complete(0, 0, 0))

	# ══════════════ ④ 표시 문구(HUD 바 + 하위 분해 / 완료 + 미리보기) ══════════════
	var bar0 := CafeMilestone.bar(0.0)
	var barfull := CafeMilestone.bar(1.0)
	_check("④ 바 0% = 빈 칸만", not bar0.contains("▰") and bar0.contains("▱"))
	_check("④b 바 100% = 채운 칸만", barfull.contains("▰") and not barfull.contains("▱"))
	var sum_partial := CafeMilestone.summary(2, 50, 3)
	_check("④c 미완료 summary에 '카페 1단'·하위 분해(영혼/매출/친밀) 노출",
		sum_partial.contains("카페 1단") and sum_partial.contains("영혼")
		and sum_partial.contains("매출") and sum_partial.contains("친밀"))
	# ★[S6-T3] 1단을 채우면 줄이 "완료 ★"로 멈추지 않고 **2단 문턱으로 갈아탄다**(사다리 — 다음 칸이
	# 늘 보인다). 완료 문구는 꼭대기(2단)에서만 굳는다.
	var sum_done := CafeMilestone.summary(TH, TR, THE)
	_check("④d 1단을 채우면 summary가 2단 문턱으로 갈아탄다(사다리)",
		sum_done.contains("카페 2단") and not sum_done.contains("완료")
		and sum_done.contains("%d" % CafeMilestone.S2_TARGET_HARVEST))
	var sum_top := CafeMilestone.summary(CafeMilestone.S2_TARGET_HARVEST,
		CafeMilestone.S2_TARGET_REVENUE, CafeMilestone.S2_TARGET_HEARTS)
	_check("④d' 2단을 채우면 '카페 2단 완료 ★'로 굳는다", sum_top.contains("2단 완료"))
	# ★[S6-T3] 미리보기가 2단의 *실물*을 말한다(종전 "삼도천 낚시" 떡밥은 Slice 3 개통으로 소임 끝).
	var prev := CafeMilestone.stage2_preview()
	_check("④e 2단 미리보기는 열리는 콘텐츠를 이름으로 말한다(좌석·곳간·메뉴판)",
		prev.contains("좌석") and prev.contains("곳간") and prev.contains("메뉴판"))
	_check("④e' 미리보기 수치는 사다리 표에서 파생(문자열에 숫자를 안 박음)",
		prev.contains("%d→%d" % [Cafe.SEATS_STAGE1, Cafe.SEATS_STAGE2])
		and prev.contains("%d→%d" % [Larder.CAPACITY, Larder.CAPACITY_STAGE2]))
	_check("④f 달성 팝업 본문은 '카페 2단계!'", CafeMilestone.reached_text().contains("카페 2단계"))
	_check("④g 2단 달성 팝업은 열린 것을 센다(없는 3단을 약속하지 않는다)",
		CafeMilestone.reached2_text().contains("카페 2단 완성")
		and not CafeMilestone.reached2_text().contains("3단계"))

	# ══════════════ ⑤ main 통합 — 누적 서빙 매출 적립(낮 카페 + 밤 바) ══════════════
	var m1: Node = await _new_main()
	_dismiss_intro(m1)
	_check("⑤ 신규 시작 — 누적 서빙 매출 0·마일스톤 미완료", m1._cafe_revenue_total == 0 and not m1._milestone_complete())
	# (낮) 16:00 영업창에 손님을 앉히고 재료를 쥐여 서빙 → 누적 매출이 적립된다.
	m1.clock.minutes = Cafe.OPEN_MIN + 60
	m1.inventory.add_harvest(CropCatalog.HONRYEONGCHO)
	m1.cafe.tick(Cafe.SPAWN_INTERVAL + 0.1, m1.clock.minutes)
	var day_seat := -1
	for i in Cafe.N_SEATS:
		if m1.cafe.is_waiting(i):
			day_seat = i
			break
	var before_day: int = m1._cafe_revenue_total
	if day_seat >= 0:
		m1._try_serve(day_seat)
	_check("⑤b 낮 카페 서빙이 누적 서빙 매출을 올린다", m1._cafe_revenue_total > before_day)
	# (밤) 같은 빌드에서 밤으로 흘려 밤 바 응대 → 같은 누적에 합류(카페+밤 = 카페 운영 매출).
	m1.clock.minutes = NightBar.OPEN_MIN + 60
	await process_frame  # 밤 보호 주입(_process가 night_bar seam 채움)
	m1._open_night_bar()
	m1.night_bar.tick(NightBar.CUST_INTERVAL + 0.1, m1.clock.minutes)
	var night_seat := -1
	for i in NightBar.N_SEATS:
		if m1.night_bar.is_waiting(i):
			night_seat = i
			break
	var before_night: int = m1._cafe_revenue_total
	if night_seat >= 0:
		m1._try_night_serve(night_seat)
	_check("⑤c 밤 바 응대도 같은 누적에 합류(카페/밤 = 카페 운영 매출)", m1._cafe_revenue_total > before_night)
	# ★ C2 — 무인 출하함 raw 판매(익일 정산)는 누적에 안 든다(마일스톤은 카페를 *운영한* 매출만 — ADR-0009).
	var before_raw: int = m1._cafe_revenue_total
	var gold_before: int = m1.wallet.gold
	m1.ship_bin.add(CropCatalog.HONRYEONGCHO, 1)
	m1._on_day_advanced(m1.clock.day)   # 익일 settle → wallet엔 들어가되 마일스톤 매출엔 안 듦
	_check("⑤d raw 출하함 정산은 마일스톤 매출에 안 듦(운영 매출만)", m1._cafe_revenue_total == before_raw)
	_check("⑤e raw 출하함 정산은 골드엔 들어감(판매 자체는 유효)", m1.wallet.gold > gold_before)
	m1.free()

	# ══════════════ ⑥ 세 루프 산출물 파생 + 1단 완료 → "카페 2단계!" 팝업(래치 1회) ══════════════
	var m2: Node = await _new_main()
	_dismiss_intro(m2)
	# 세 루프 산출물을 목표치로 채운다: 거둔 영혼·누적 서빙 매출·세 동료 하트 합(점수 직접 세팅).
	m2._run_harvested = TH
	m2._cafe_revenue_total = TR
	# ★[S8-T5] 하트는 이제 stage(진급 칸)다 — 점수와 함께 stage도 세팅한다(관문은 heart_gate_test 소관).
	m2.affinity.points = 3 * Affinity.POINTS_PER_HEART        # 미호 ♡3
	m2.affinity.stage = 3
	m2.mel_affinity.points = 3 * Affinity.POINTS_PER_HEART    # 멜 ♡3 → 합 6 = THE
	m2.mel_affinity.stage = 3
	m2.bana_affinity.points = 2 * Affinity.POINTS_PER_HEART   # 바나 ♡2 — ★게이트 밖(⑧이 단언)
	m2.bana_affinity.stage = 2
	_check("⑥ 관계 산출물 = 미호+멜 하트 합(★S6-T3 — 바나 제외)", m2._milestone_hearts() == 6)
	_check("⑥b 세 산출물이 목표치 → _milestone_complete 참", m2._milestone_complete())
	# _process 한 프레임 — 채우는 순간 팝업이 한 번 뜨고 래치가 켜진다.
	m2._milestone_celebrated = false
	m2.milestone_panel.visible = false
	await process_frame
	_check("⑥c 채우면 '카페 2단계!' 팝업이 뜬다", m2.milestone_panel.visible)
	_check("⑥d 달성 래치가 켜진다", m2._milestone_celebrated)
	_check("⑥e 달성 팝업 본문에 '카페 2단계'", m2.milestone_text.text.contains("카페 2단계"))
	_check("⑥f 마일스톤 HUD가 곧바로 2단 진행으로 갈아탄다(★S6-T3 사다리)",
		m2.milestone_label.text.contains("카페 2단") and not m2.milestone_label.text.contains("완료"))
	# 래치 1회: 팝업을 수동으로 닫고 한 프레임 더 — 재팝업되지 않는다(매 프레임 다시 안 뜸).
	m2.milestone_panel.visible = false
	await process_frame
	_check("⑥g 래치 후엔 재팝업 안 됨(1회성)", not m2.milestone_panel.visible)
	m2.free()

	# ══════════════ ⑦ 세이브 라운드트립 — 누적 서빙 매출 보존 + 완료 세이브 재개 시 재팝업 0 ══════════════
	var m3: Node = await _new_main()
	_dismiss_intro(m3)
	m3._run_harvested = TH
	m3._cafe_revenue_total = TR
	m3.affinity.points = 3 * Affinity.POINTS_PER_HEART
	m3.affinity.stage = 3
	m3.mel_affinity.points = 3 * Affinity.POINTS_PER_HEART
	m3.mel_affinity.stage = 3
	m3.bana_affinity.points = 2 * Affinity.POINTS_PER_HEART
	m3.bana_affinity.stage = 2
	m3._save_game()  # 완료 상태를 디스크에 저장
	m3.free()
	var m4: Node = await _new_main()  # _ready가 자동 로드 + 래치 초기화
	_check("⑦ 누적 서빙 매출이 세이브를 넘어 복원", m4._cafe_revenue_total == TR)
	_check("⑦b 완료 세이브를 이어받으면 _milestone_complete 참", m4._milestone_complete())
	_check("⑦c 재개 시 래치가 미리 켜져 재팝업 0(완료는 HUD가 상시 보여 줌)", m4._milestone_celebrated)
	await process_frame
	_check("⑦d 재개 후 한 프레임에도 달성 팝업 안 터짐", not m4.milestone_panel.visible)
	m4.free()

	# ══════════ ⑧ ★[S6-T3] 바나 ♡가 게이트에 무영향(ADR-0029 §4 — 카페-도메인 3인) ══════════
	# 종전 게이트는 미호+멜+바나 합이었다. 바나는 밤 경비·던전 공급 축이라(카페-도메인 밖) 카페
	# 매크로 목표를 밀면 안 된다 — "카페를 일구려면 밤 경비도 갈아야 한다"가 되어 도메인이 섞인다.
	var m5: Node = await _new_main()
	_dismiss_intro(m5)
	m5.affinity.points = 3 * Affinity.POINTS_PER_HEART       # 미호 ♡3
	m5.affinity.stage = 3
	m5.mel_affinity.points = 3 * Affinity.POINTS_PER_HEART   # 멜 ♡3 → 합 6
	m5.mel_affinity.stage = 3
	var hearts_b0: int = m5._milestone_hearts()
	m5.bana_affinity.points = Affinity.MAX_POINTS            # 바나 만렙
	m5.bana_affinity.stage = Affinity.MAX_HEARTS
	_check("⑧ 바나 ♡를 0→만렙으로 올려도 하트 축이 안 움직인다", m5._milestone_hearts() == hearts_b0)
	_check("⑧b 하트 축 = 정확히 미호+멜 합",
		hearts_b0 == m5.affinity.hearts() + m5.mel_affinity.hearts() and hearts_b0 == 6)
	# 게이트 실효까지 본다: 미호+멜만으로 1단이 닫히고, 바나를 0으로 떨궈도 그대로 닫혀 있다.
	m5._run_harvested = TH
	m5._cafe_revenue_total = TR
	_check("⑧c 미호+멜만으로 1단 완료(바나 없이 닫힌다)", m5._milestone_complete())
	m5.bana_affinity.points = 0
	m5.bana_affinity.stage = 0
	_check("⑧d 바나 ♡0으로 떨궈도 1단은 그대로 완료(게이트 무영향)", m5._milestone_complete())
	# 문턱 하향(8→6)은 하트 축을 2인으로 좁힌 데 따른 잠정 레버다(owner 결재 대상).
	_check("⑧e 1단 하트 문턱 = 6(잠정 — 2인 합 최대 10)",
		CafeMilestone.TARGET_HEARTS == 6 and CafeMilestone.TARGET_HEARTS <= 2 * Affinity.MAX_HEARTS)

	# ══════════ ⑨ ★[S6-T3] 2단 사다리 — 단계 판정 + 해금 콘텐츠 넷이 실제로 달라진다 ══════════
	# 사다리 단조성: 2단 문턱은 모든 축에서 1단 이상이라 "2단 완료 ⇒ 1단 완료"가 성립한다.
	_check("⑨ 2단 문턱이 세 축 모두 1단 이상(사다리 단조성)",
		CafeMilestone.S2_TARGET_HARVEST >= TH and CafeMilestone.S2_TARGET_REVENUE >= TR
		and CafeMilestone.S2_TARGET_HEARTS >= THE
		and CafeMilestone.S2_TARGET_HEARTS <= 2 * Affinity.MAX_HEARTS)
	_check("⑨b stage() 3단계 판정(0/1/2)",
		CafeMilestone.stage(0, 0, 0) == CafeMilestone.STAGE_NONE
		and CafeMilestone.stage(TH, TR, THE) == CafeMilestone.STAGE_1
		and CafeMilestone.stage(CafeMilestone.S2_TARGET_HARVEST, CafeMilestone.S2_TARGET_REVENUE,
			CafeMilestone.S2_TARGET_HEARTS) == CafeMilestone.STAGE_2)
	_check("⑨c 2단 완료는 1단 완료를 함의",
		CafeMilestone.is_complete(CafeMilestone.S2_TARGET_HARVEST,
			CafeMilestone.S2_TARGET_REVENUE, CafeMilestone.S2_TARGET_HEARTS))
	# ── 콘텐츠 실효(라이브 main — 주입 다리가 실제로 값을 옮기나) ──
	# 발견 원장을 다 채워 융합 로스터를 전부 해금한다(메뉴판 슬롯 상한을 보려면 후보가 넘쳐야 한다).
	for mid in MenuCatalog.fusion_ids():
		m5._menu_found[MenuCatalog.signature_of(String(mid))] = true
	m5._refresh_cafe_ladder()
	_check("⑨d 1단 — 좌석 3칸", m5.cafe.open_seats == Cafe.SEATS_STAGE1 and Cafe.SEATS_STAGE1 == 3)
	_check("⑨e 1단 — 곳간 용량 30", m5.larder.capacity == Larder.CAPACITY and Larder.CAPACITY == 30)
	var pool1: Array = m5._cafe_order_pool()
	_check("⑨f 1단 — 메뉴판 슬롯 %d칸에서 잘린다" % MenuCatalog.FUSION_SLOTS_STAGE1,
		pool1.size() == MenuCatalog.FUSION_SLOTS_STAGE1)
	var scale1: float = m5.cafe.spawn_scale
	# 좌석 실효: 1단에선 4·5번 자리에 손님이 앉지 않는다(영업창을 열고 충분히 굴려도).
	# ★ 인내심을 크게 잡아 손님이 안 떠나게 한다(seam 1) — 그래야 좌석이 *채워진 채로* 쌓여
	#   "열린 칸까지만 앉는다"가 관측된다(기본 7초면 앞자리가 계속 비어 뒷칸까지 갈 일이 없다).
	m5.cafe.patience_secs = 9999.0
	m5.clock.minutes = Cafe.OPEN_MIN + 60
	for i in 40:
		m5.cafe.tick(Cafe.SPAWN_INTERVAL + 0.1, m5.clock.minutes)
	var locked_used := false
	for i in range(Cafe.SEATS_STAGE1, Cafe.N_SEATS):
		if m5.cafe.is_waiting(i):
			locked_used = true
	_check("⑨g 1단 — 잠긴 좌석 3·4에는 손님이 안 앉는다", not locked_used)
	_check("⑨h 좌석 칸(SEAT_TILES)은 사다리 최대치만큼 깔려 있다(잠긴 칸도 무대엔 있다)",
		m5.SEAT_TILES.size() == Cafe.N_SEATS and Cafe.N_SEATS == Cafe.SEATS_STAGE2)
	# ── 2단으로 올린다(같은 세 축을 더 높은 문턱까지) ──
	m5._run_harvested = CafeMilestone.S2_TARGET_HARVEST
	m5._cafe_revenue_total = CafeMilestone.S2_TARGET_REVENUE
	m5.affinity.points = Affinity.MAX_POINTS
	m5.affinity.stage = Affinity.MAX_HEARTS
	m5.mel_affinity.points = Affinity.MAX_POINTS
	m5.mel_affinity.stage = Affinity.MAX_HEARTS
	_check("⑨i 2단 완료 판정", m5._milestone_stage2_complete() and m5._cafe_stage() == CafeMilestone.STAGE_2)
	m5._refresh_cafe_ladder()
	_check("⑨j 2단 — 좌석 3→5", m5.cafe.open_seats == Cafe.SEATS_STAGE2 and Cafe.SEATS_STAGE2 == 5)
	_check("⑨k 2단 — 곳간 용량 30→50",
		m5.larder.capacity == Larder.CAPACITY_STAGE2 and Larder.CAPACITY_STAGE2 == 50)
	_check("⑨l 2단 — 곳간이 실제로 50개까지 받는다(용량 주입이 add까지 산다)",
		m5.larder.free_space() == Larder.CAPACITY_STAGE2 - m5.larder.total())
	# 메뉴판 슬롯 확대 — 후보(해금 ∧ 절기)가 남아 있는 만큼 더 걸린다.
	var avail := 0
	for mid2 in MenuCatalog.fusion_ids():
		if m5._menu_unlocked(String(mid2)) and MenuCatalog.in_season(String(mid2), m5.clock.season_index()):
			avail += 1
	var pool2: Array = m5._cafe_order_pool()
	_check("⑨m 2단 — 메뉴판 슬롯 %d→%d칸으로 넓어진다 (후보 %d종 → %d칸)" % [
		MenuCatalog.FUSION_SLOTS_STAGE1, MenuCatalog.FUSION_SLOTS_STAGE2, avail, pool2.size()],
		pool2.size() == mini(avail, MenuCatalog.FUSION_SLOTS_STAGE2) and pool2.size() > pool1.size())
	_check("⑨n 2단 — 손님 볼륨 증가(스폰 간격 배수↓ = 더 자주 앉는다)",
		m5.cafe.spawn_scale < scale1
		and is_equal_approx(m5.cafe.spawn_scale, scale1 * CafeMilestone.SPAWN_SCALE_STAGE2))
	# 좌석 실효(2단) — 이제 잠겼던 칸에도 손님이 앉는다(같은 하네스·같은 틱 수).
	m5.cafe.end_day()
	m5.cafe.patience_secs = 9999.0
	m5.clock.minutes = Cafe.OPEN_MIN + 60
	for i2 in 40:
		m5.cafe.tick(Cafe.SPAWN_INTERVAL + 0.1, m5.clock.minutes)
	var opened_used := false
	for i3 in range(Cafe.SEATS_STAGE1, Cafe.N_SEATS):
		if m5.cafe.is_waiting(i3):
			opened_used = true
	_check("⑨o 2단 — 열린 좌석 3·4에 손님이 앉는다", opened_used)
	# 2단 달성 팝업 — 1단 래치 선례를 그대로(1회성). 두 단계가 한 프레임에 함께 닫힌 상태라
	# 팝업 순서(1단 먼저 → 다음 프레임 2단)도 여기서 결정화한다(한 팝업이 다른 팝업을 안 삼킨다).
	m5._milestone_celebrated = false
	m5._milestone2_celebrated = false
	m5.milestone_panel.visible = false
	m5.clock.minutes = 10 * 60   # 영업창 밖으로 물려 카페 틱이 화면을 안 흔들게
	await process_frame
	_check("⑨p 둘 다 닫혀 있어도 1단 팝업이 먼저 뜬다",
		m5.milestone_panel.visible and m5.milestone_text.text.contains("카페 2단계"))
	m5.milestone_panel.visible = false
	await process_frame
	_check("⑨q 다음 프레임에 2단 팝업이 이어 뜬다(reached2_text)",
		m5.milestone_panel.visible and m5.milestone_text.text.contains("카페 2단 완성"))
	_check("⑨r 2단 래치가 켜진다", m5._milestone2_celebrated)
	m5.milestone_panel.visible = false
	await process_frame
	_check("⑨s 래치 후엔 재팝업 안 됨(1회성 — 1단과 같은 규칙)", not m5.milestone_panel.visible)
	_check("⑨t 2단 HUD는 '카페 2단 완료 ★'로 굳는다", m5.milestone_label.text.contains("2단 완료"))
	# 2단 세이브 왕복 — 세이브 무상태(누적 축 파생)라 새 키가 없고, 곳간은 2단 용량으로 온전히 산다.
	m5.larder.add(CropCatalog.HONRYEONGCHO, 45)   # 1단 상한(30) 초과 = 2단에서만 가능한 재고
	_check("⑨u 2단 곳간에 45개 적재(1단 상한 30 초과)", m5.larder.count_of(CropCatalog.HONRYEONGCHO) == 45)
	m5._save_game()
	var blob: Dictionary = cleaner.load_game()
	_check("⑨v 2단은 세이브 조각을 신설하지 않는다(누적 축 파생 — 무상태)",
		not blob.has("cafe_stage") and not blob.has("milestone_stage")
		and blob.has("cafe_revenue_total") and blob.has("run_harvested"))
	m5.free()
	var m6: Node = await _new_main()   # _ready 자동 로드
	_check("⑨w 재개하면 단계가 그대로 파생된다(2단)", m6._cafe_stage() == CafeMilestone.STAGE_2)
	_check("⑨x 재개 시 2단 래치도 미리 켜져 재팝업 0", m6._milestone2_celebrated)
	_check("⑨y ★2단 곳간 재고 45개가 온전히 복원(1단 상한에 잘리지 않는다)",
		m6.larder.count_of(CropCatalog.HONRYEONGCHO) == 45 and m6.larder.capacity == Larder.CAPACITY_STAGE2)
	await process_frame
	_check("⑨z 재개 후 한 프레임에도 팝업 안 터짐", not m6.milestone_panel.visible)
	m6.free()

	cleaner.delete_save()  # 테스트 잔여 세이브 정리(다른 실행·플레이에 새지 않게)
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
