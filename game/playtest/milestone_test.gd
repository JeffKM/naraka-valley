extends SceneTree
# T7.2 임시 헤드리스 단위검증 — cafe_milestone.gd(카페 마일스톤 1단) 계약 + main 통합을 검증한다.
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
	var sum_done := CafeMilestone.summary(TH, TR, THE)
	_check("④d 완료 summary는 '완료' + 2단 미리보기", sum_done.contains("완료") and sum_done.contains("2단"))
	_check("④e 2단 미리보기는 낚시 떡밥을 건다(왜 낚시? = 카페 성장)",
		CafeMilestone.stage2_preview().contains("낚시"))
	_check("④f 달성 팝업 본문은 '카페 2단계!'", CafeMilestone.reached_text().contains("카페 2단계"))

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
	# 출하대 raw 판매는 누적에 안 든다(마일스톤은 카페를 *운영한* 매출만 — ADR-0009).
	var before_raw: int = m1._cafe_revenue_total
	m1.inventory.add_harvest(CropCatalog.HONRYEONGCHO)
	m1._sell_all()
	_check("⑤d raw 출하대 판매는 마일스톤 매출에 안 듦(운영 매출만)", m1._cafe_revenue_total == before_raw)
	m1.free()

	# ══════════════ ⑥ 세 루프 산출물 파생 + 1단 완료 → "카페 2단계!" 팝업(래치 1회) ══════════════
	var m2: Node = await _new_main()
	_dismiss_intro(m2)
	# 세 루프 산출물을 목표치로 채운다: 거둔 영혼·누적 서빙 매출·세 동료 하트 합(점수 직접 세팅).
	m2._run_harvested = TH
	m2._cafe_revenue_total = TR
	m2.affinity.points = 3 * Affinity.POINTS_PER_HEART        # ♡3
	m2.mel_affinity.points = 3 * Affinity.POINTS_PER_HEART    # ♡3
	m2.bana_affinity.points = 2 * Affinity.POINTS_PER_HEART   # ♡2 → 합 8 = THE
	_check("⑥ 관계 산출물 = 세 동료 하트 합", m2._milestone_hearts() == 8)
	_check("⑥b 세 산출물이 목표치 → _milestone_complete 참", m2._milestone_complete())
	# _process 한 프레임 — 채우는 순간 팝업이 한 번 뜨고 래치가 켜진다.
	m2._milestone_celebrated = false
	m2.milestone_panel.visible = false
	await process_frame
	_check("⑥c 채우면 '카페 2단계!' 팝업이 뜬다", m2.milestone_panel.visible)
	_check("⑥d 달성 래치가 켜진다", m2._milestone_celebrated)
	_check("⑥e 달성 팝업 본문에 '카페 2단계'", m2.milestone_text.text.contains("카페 2단계"))
	_check("⑥f 마일스톤 HUD가 완료를 노출", m2.milestone_label.text.contains("완료"))
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
	m3.mel_affinity.points = 3 * Affinity.POINTS_PER_HEART
	m3.bana_affinity.points = 2 * Affinity.POINTS_PER_HEART
	m3._save_game()  # 완료 상태를 디스크에 저장
	m3.free()
	var m4: Node = await _new_main()  # _ready가 자동 로드 + 래치 초기화
	_check("⑦ 누적 서빙 매출이 세이브를 넘어 복원", m4._cafe_revenue_total == TR)
	_check("⑦b 완료 세이브를 이어받으면 _milestone_complete 참", m4._milestone_complete())
	_check("⑦c 재개 시 래치가 미리 켜져 재팝업 0(완료는 HUD가 상시 보여 줌)", m4._milestone_celebrated)
	await process_frame
	_check("⑦d 재개 후 한 프레임에도 달성 팝업 안 터짐", not m4.milestone_panel.visible)
	m4.free()

	cleaner.delete_save()  # 테스트 잔여 세이브 정리(다른 실행·플레이에 새지 않게)
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
