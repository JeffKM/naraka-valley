extends SceneTree
# ★[S10-T5 / ADR-0069 결정 8] 카페 마일스톤 3단 「저승의 명소」 단위검증.
# milestone_test(1·2단)의 짝이고 같은 결이다: ① 순수 정적 규칙(문턱·단조성·문구)을 CafeMilestone로
# 직접 검증하고, ② 그 3단이 main.gd에 살아 — 단계 파생·달성 팝업 래치·늘봄방 해금 게이트·세이브
# 재개 — 있는지를 main 씬으로 결정화한다.
# ★ 이 스위트의 **핵심 단언은 "1·2단 문턱 상수 바이트 불변"**이다(구세이브 마일스톤 호환의 뿌리).
# 실행: godot --headless --path game --script res://playtest/cafe_stage3_test.gd

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

func _dismiss_intro(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

# 세 축을 한 번에 세팅하는 헬퍼(하트는 점수 + stage 동반 — heart_gate 규약).
func _set_axes(m: Node, harvested: int, revenue: int, hearts_each: int) -> void:
	m._run_harvested = harvested
	m._cafe_revenue_total = revenue
	m.affinity.points = hearts_each * Affinity.POINTS_PER_HEART
	m.affinity.stage = hearts_each
	m.mel_affinity.points = hearts_each * Affinity.POINTS_PER_HEART
	m.mel_affinity.stage = hearts_each

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S10-T5 카페 마일스톤 3단 「저승의 명소」 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var TH := CafeMilestone.TARGET_HARVEST
	var TR := CafeMilestone.TARGET_REVENUE
	var THE := CafeMilestone.TARGET_HEARTS
	var S2H := CafeMilestone.S2_TARGET_HARVEST
	var S2R := CafeMilestone.S2_TARGET_REVENUE
	var S2E := CafeMilestone.S2_TARGET_HEARTS
	var S3R := CafeMilestone.S3_TARGET_REVENUE

	# ═══ ① 기존 문턱 **바이트 불변**(구세이브 마일스톤 호환의 뿌리 — 3단이 이 셋을 못 건드린다) ═══
	_check("① 1단 문턱 불변(12/400/6)", TH == 12 and TR == 400 and THE == 6)
	# ★[폴리시 R3 · #15] 하트 문턱만 **9 → 8**로 의도적으로 내렸다(수확·매출은 바이트 불변).
	#   9는 "미호+멜 최대 10"을 전제한 값인데, S8-T5의 진급 관문(Affinity.GATE_MAX=4) 도입 뒤
	#   실제 상한은 연애 상대에 따라 9(미호·멜과 연애) 또는 8(바나·조연·옥자와 연애 / 무연애)이라,
	#   9면 **연애 상대 선택 하나가 2·3단을 영구 잠근다**(좌석·곳간·융합 슬롯·늘봄방 전부).
	#   그래서 문턱을 "연애 선택과 무관하게 닿는 상한"인 `2 × GATE_MAX`에서 **파생**시킨다 —
	#   이제 상한을 조정해도 이 값이 다시 어긋나지 않으므로, 여기서도 리터럴 대신 파생식을 잠근다.
	_check("①b 2단 문턱 — 수확·매출 불변(40/1800) · 하트는 관문 상한 파생(%d)" % S2E,
		S2H == 40 and S2R == 1800 and S2E == 2 * Affinity.GATE_MAX)
	_check("①c 3단 단계 상수 = 3", CafeMilestone.STAGE_3 == 3)

	# ═══ ② 3단 축 = 누적 서빙 매출 **단독**, 단 2단 완료를 AND로 문다(사다리 단조성) ═══
	_check("② 3단 문턱이 2단 매출보다 높다(사다리)", S3R > S2R)
	_check("②b 세 축 만족 + 매출 3단 문턱 → 3단 완료",
		CafeMilestone.is_stage3_complete(S2H, S3R, S2E))
	_check("②c 매출만 3단 문턱이고 수확이 2단 미달이면 3단 아님(단조성 방어)",
		not CafeMilestone.is_stage3_complete(S2H - 1, S3R, S2E))
	_check("②d 매출만 3단 문턱이고 하트가 2단 미달이면 3단 아님",
		not CafeMilestone.is_stage3_complete(S2H, S3R, S2E - 1))
	_check("②e 3단 완료는 2단 완료를 **함의**", CafeMilestone.is_stage2_complete(S2H, S3R, S2E))
	_check("②f 3단 완료는 1단 완료도 함의", CafeMilestone.is_complete(S2H, S3R, S2E))
	# 수확·하트를 더 올려도 매출이 모자라면 3단이 아니다(축이 매출 단독이라는 것의 반대 방향 확인).
	_check("②g 수확·하트를 만렙으로 올려도 매출 미달이면 2단에 머문다",
		CafeMilestone.stage(S2H * 10, S3R - 1, 2 * Affinity.MAX_HEARTS) == CafeMilestone.STAGE_2)

	# ═══ ③ stage() 4단계 판정(0/1/2/3) ═══
	_check("③ 0 산출물 → STAGE_NONE", CafeMilestone.stage(0, 0, 0) == CafeMilestone.STAGE_NONE)
	_check("③b 1단 문턱 → STAGE_1", CafeMilestone.stage(TH, TR, THE) == CafeMilestone.STAGE_1)
	_check("③c 2단 문턱 → STAGE_2", CafeMilestone.stage(S2H, S2R, S2E) == CafeMilestone.STAGE_2)
	_check("③d 3단 문턱 → STAGE_3", CafeMilestone.stage(S2H, S3R, S2E) == CafeMilestone.STAGE_3)
	_check("③e 3단 진행 비율은 매출 단독 파생(문턱 도달 = 1.0)",
		is_equal_approx(CafeMilestone.s3_overall_ratio(S3R), 1.0)
		and is_equal_approx(CafeMilestone.s3_overall_ratio(0), 0.0))
	_check("③f 3단 비율도 초과분은 1.0로 잘림", is_equal_approx(CafeMilestone.s3_overall_ratio(S3R * 3), 1.0))

	# ═══ ④ 표시 계층 — 2단에서 굳지 않고 **3단 문턱으로 갈아탄다**(사다리 규칙 승계) ═══
	var sum2 := CafeMilestone.summary(S2H, S2R, S2E)
	_check("④ 2단을 채우면 summary가 3단 문턱으로 갈아탄다(꼭대기 완료로 안 굳는다)",
		sum2.contains("카페 3단") and not sum2.contains("완료")
		and sum2.contains("%d" % S3R))
	var sum3 := CafeMilestone.summary(S2H, S3R, S2E)
	_check("④b 3단을 채우면 '카페 3단 완료 ★ — 저승의 명소'로 굳는다",
		sum3.contains("3단 완료") and sum3.contains("저승의 명소"))
	var cmp2 := CafeMilestone.compact(S2H, S2R, S2E)
	_check("④c compact도 2단에서 3단 진행으로 갈아탄다",
		cmp2.contains("카페 3단") and not cmp2.contains("완료"))
	_check("④d compact 3단 완료 문구", CafeMilestone.compact(S2H, S3R, S2E).contains("카페 3단 완료 ★"))
	var prev3 := CafeMilestone.stage3_preview()
	_check("④e 3단 미리보기는 매출 축과 늘봄방을 이름으로 말한다",
		prev3.contains("매출") and prev3.contains("늘봄방"))
	_check("④f 미리보기 수치는 상수 파생(문자열에 숫자를 안 박음)", prev3.contains("%d" % S3R))
	_check("④g 2단 달성 팝업이 이제 3단을 예고한다(빈 예고가 아니게 됐다)",
		CafeMilestone.reached2_text().contains("늘봄방"))
	var r3 := CafeMilestone.reached3_text()
	_check("④h 3단 팝업 = 「저승의 명소」 + 늘봄방 해금 안내",
		r3.contains("저승의 명소") and r3.contains("늘봄방"))
	_check("④i 3단 팝업은 **다음 칸을 약속하지 않는다**(사다리의 마지막 — 4단 예고 0)",
		not r3.contains("4단"))

	# ═══ ⑤ 해금 표 — 3단이 여는 것 = 늘봄방 하나 ═══
	_check("⑤ greenhouse_unlocked는 3단부터 참",
		not CafeMilestone.greenhouse_unlocked(CafeMilestone.STAGE_2)
		and CafeMilestone.greenhouse_unlocked(CafeMilestone.STAGE_3))
	_check("⑤b 3단이 좌석·곳간·메뉴판을 더 열지는 않는다(2단 값 유지 — 여는 건 늘봄방뿐)",
		CafeMilestone.seats_of(CafeMilestone.STAGE_3) == CafeMilestone.seats_of(CafeMilestone.STAGE_2)
		and CafeMilestone.larder_capacity_of(CafeMilestone.STAGE_3) == CafeMilestone.larder_capacity_of(CafeMilestone.STAGE_2)
		and CafeMilestone.fusion_slots_of(CafeMilestone.STAGE_3) == CafeMilestone.fusion_slots_of(CafeMilestone.STAGE_2))

	# ═══ ⑥ main 통합 — 단계 파생 · 3단 팝업 래치(1회) · HUD ═══
	var m1: Node = await _new_main()
	_dismiss_intro(m1)
	m1.clock.minutes = 10 * 60   # 영업창 밖(카페 틱이 화면을 안 흔들게)
	_set_axes(m1, S2H, S2R, 5)   # 하트 합 10 ≥ 9
	_check("⑥ 2단 세팅 → _cafe_stage()==2", m1._cafe_stage() == CafeMilestone.STAGE_2)
	_check("⑥b 2단에선 3단 미완료", not m1._milestone_stage3_complete())
	m1._cafe_revenue_total = S3R
	_check("⑥c 매출만 3단 문턱으로 올리면 3단 완료(축 = 매출 단독)", m1._milestone_stage3_complete())
	_check("⑥d _cafe_stage()==3", m1._cafe_stage() == CafeMilestone.STAGE_3)
	# 세 래치를 다 끄고 프레임을 흘리면 1→2→3단 팝업이 한 프레임에 하나씩 뜬다(팝업이 팝업을 안 삼킨다).
	m1._milestone_celebrated = false
	m1._milestone2_celebrated = false
	m1._milestone3_celebrated = false
	m1.milestone_panel.visible = false
	await process_frame
	_check("⑥e 1단 팝업이 먼저", m1.milestone_panel.visible and m1.milestone_text.text.contains("카페 2단계"))
	m1.milestone_panel.visible = false
	await process_frame
	_check("⑥f 다음 프레임 2단 팝업", m1.milestone_panel.visible and m1.milestone_text.text.contains("카페 2단 완성"))
	m1.milestone_panel.visible = false
	await process_frame
	_check("⑥g 그다음 프레임 3단 팝업(저승의 명소)",
		m1.milestone_panel.visible and m1.milestone_text.text.contains("저승의 명소"))
	_check("⑥h 3단 래치가 켜진다", m1._milestone3_celebrated)
	m1.milestone_panel.visible = false
	await process_frame
	_check("⑥i 래치 후 재팝업 0(1회성 — 1·2단과 같은 규칙)", not m1.milestone_panel.visible)
	_check("⑥j HUD가 '카페 3단 완료 ★'로 굳는다", m1.milestone_label.text.contains("3단 완료"))

	# ═══ ⑦ 늘봄방 해금 게이트 — 매대 행 잠금 + 결제 경로 재검증 ═══
	m1.wallet.gold = 999999
	m1.inventory.add_item(ItemCatalog.WOOD, 999)
	var rows3: Array = m1._build_rows()
	var gh_row3: Dictionary = {}
	for r in rows3:
		if String(r["buy_id"]) == Carpenter.PROJ_GREENHOUSE:
			gh_row3 = r
	_check("⑦ 3단에선 늘봄방 행이 잠기지 않는다", not gh_row3.is_empty() and not gh_row3.get("locked", false))
	_check("⑦b 3단에선 주문이 성립한다", m1._try_order_build(Carpenter.PROJ_GREENHOUSE))
	m1.free()

	# 2단(미달) 판에서는 행이 잠기고 결제도 막힌다.
	var m2: Node = await _new_main()
	_dismiss_intro(m2)
	m2.clock.minutes = 10 * 60
	_set_axes(m2, S2H, S2R, 5)   # 2단까지만
	m2.wallet.gold = 999999
	m2.inventory.add_item(ItemCatalog.WOOD, 999)
	var rows2: Array = m2._build_rows()
	var gh_row2: Dictionary = {}
	var other_locked_wrongly := false
	for r2 in rows2:
		if String(r2["buy_id"]) == Carpenter.PROJ_GREENHOUSE:
			gh_row2 = r2
		elif bool(r2.get("locked", false)):
			other_locked_wrongly = true
	_check("⑦c 2단에선 늘봄방 행이 '카페 3단 필요'로 잠긴다",
		not gh_row2.is_empty() and bool(gh_row2.get("locked", false))
		and String(gh_row2.get("locked_text", "")).contains("카페 3단"))
	_check("⑦d 다른 건축 4건은 게이트에 안 걸린다(기존 매대 표시 회귀 0)", not other_locked_wrongly)
	_check("⑦e 2단에선 결제 경로가 다시 막는다(프레임 신호 불신)",
		not m2._try_order_build(Carpenter.PROJ_GREENHOUSE))
	_check("⑦f 막힌 주문은 원장에 남지 않는다", not m2.carpenter.is_active())
	m2.free()

	# ═══ ⑧ 세이브 — 3단은 조각을 신설하지 않는다(누적 축 파생) + 2단 세이브 로드 무손상 ═══
	var m3: Node = await _new_main()
	_dismiss_intro(m3)
	m3.clock.minutes = 10 * 60
	_set_axes(m3, S2H, S2R, 5)   # ★2단 상태로 저장(3단 도입 전 세이브와 같은 모양)
	m3._save_game()
	var blob: Dictionary = cleaner.load_game()
	_check("⑧ 3단도 세이브 조각을 신설하지 않는다(무상태 — 단계 키 없음)",
		not blob.has("cafe_stage") and not blob.has("milestone_stage")
		and blob.has("cafe_revenue_total") and blob.has("run_harvested"))
	m3.free()
	var m4: Node = await _new_main()
	_check("⑧b 2단 세이브를 이어받으면 그대로 2단(3단 도입이 단계를 안 흔든다)",
		m4._cafe_stage() == CafeMilestone.STAGE_2)
	_check("⑧c 2단 세이브 재개 시 1·2단 래치는 켜지고 3단 래치는 꺼진다",
		m4._milestone_celebrated and m4._milestone2_celebrated and not m4._milestone3_celebrated)
	await process_frame
	_check("⑧d 재개 후 한 프레임에도 팝업 안 터짐", not m4.milestone_panel.visible)
	# 3단으로 올려 저장 → 재개 시 3단 래치가 미리 켜져 재팝업 0.
	m4._cafe_revenue_total = S3R
	m4._save_game()
	m4.free()
	var m5: Node = await _new_main()
	_check("⑧e 3단 세이브 재개 → 단계가 그대로 파생(3단)", m5._cafe_stage() == CafeMilestone.STAGE_3)
	_check("⑧f 재개 시 3단 래치도 미리 켜져 재팝업 0", m5._milestone3_celebrated)
	await process_frame
	_check("⑧g 3단 재개 후 한 프레임에도 팝업 안 터짐", not m5.milestone_panel.visible)
	m5.free()

	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
