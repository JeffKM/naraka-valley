extends SceneTree
# ★[S8-T5 / ADR-0066 결정 5] 단계 관문 프레임워크·deed 판정·비트 원장 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① Affinity stage/points 분리 — 점수 만충 ≠ 진급(진급 정지)·promote 한 칸씩·구세이브
#      하위호환(stage 키 없음 = 옛 파생식으로 복원 — 소급 강등 없음)·세이브 왕복.
#   ② Deed 순수 판정 — 미호 30/80/160/300 · 멜 500/1500/3500/7000 · 바나 4축 ·
#      서브 주민 무조건 통과 · ♡5 = deed 아님(의지 시험 소관).
#   ③ 관문 트리거(대화 진입) — 메인 deed 미달 = 잠금 · 충족 = 진급 + placeholder 발화 1줄 ·
#      서브 = 이벤트만 · ♡5 진급은 관문 이벤트로 안 오른다(의지 시험 대기 — S8-T6).
#   ④ 비트 원장 — 진급 시 seen 마킹·세이브 가법·재구애(비트 기존재) 시 조용한 진급.
#   ⑤ hearts() 파급 — 곱셈기(마진·경비·할인)·마일스톤 하트 축이 점수가 아니라 stage에서 파생.
#   ⑥ 관계 탭 배지 — 진급 대기 실값(T1 훅 배선).
#
# 실행: ./run_tests.sh heart_gate   (헤드리스는 반드시 game/에서 · 순차)

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

# 신규 시작은 _ready가 옥자 통보 대화를 띄운다 — 관문 대화 검증 전에 끝까지 넘겨 닫는다.
func _dismiss_intro(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

# 열린 대화를 끝까지 넘겨 닫는다(다음 대화 트리거를 위해).
func _close_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S8-T5 단계 관문·deed·비트 원장 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ① Affinity stage/points 분리(노드 단위) ──
	print("── ① stage/points 분리 ──")
	var a := Affinity.new()
	a.points = Affinity.MAX_POINTS
	_check("①a 점수 만충이어도 하트는 0(자동 진급 없음 — 진급 정지)",
		a.hearts() == 0 and a.points_hearts() == Affinity.MAX_HEARTS)
	_check("①b 진급 대기 판정", a.pending_promotion())
	_check("①c promote는 한 칸씩", a.promote() and a.hearts() == 1 and a.pending_promotion())
	a.stage = Affinity.MAX_HEARTS
	_check("①d 만렙에선 promote 불가(대기 없음)", not a.pending_promotion() and not a.promote())
	a.stage = 2
	a.points = 2 * Affinity.POINTS_PER_HEART
	_check("①e 점수가 안 받쳐 주는 진급은 없다(칸 경계 = 대기 아님)",
		not a.pending_promotion() and not a.promote() and a.hearts() == 2)
	# 세이브 왕복 — stage 키가 실려 그대로 돌아온다.
	var saved := a.to_save()
	var b := Affinity.new()
	b.load_save(saved)
	_check("①f 세이브 왕복 = stage 보존", b.stage == 2 and b.hearts() == 2)
	# 구세이브(stage 키 없음) = 옛 파생식으로 복원 — 관문 도입이 기존 하트를 소급 강등하지 않는다.
	var c := Affinity.new()
	c.load_save({"points": 3 * Affinity.POINTS_PER_HEART})
	_check("①g 구세이브 하위호환 — stage 없으면 points 파생(♡3 유지·강등 없음)",
		c.stage == 3 and c.hearts() == 3)
	a.free(); b.free(); c.free()

	# ── ② Deed 순수 판정(문턱표) ──
	print("── ② Deed 문턱 ──")
	_check("②a 미호 ♡1 = 수확 30(미달 false·충족 true)",
		not Deed.check("miho", 1, {"run_harvested": 29})
		and Deed.check("miho", 1, {"run_harvested": 30}))
	_check("②b 미호 ♡4 = 수확 300", not Deed.check("miho", 4, {"run_harvested": 299})
		and Deed.check("miho", 4, {"run_harvested": 300}))
	_check("②c 멜 ♡1 = 매출 500냥", not Deed.check("mel", 1, {"cafe_revenue_total": 499})
		and Deed.check("mel", 1, {"cafe_revenue_total": 500}))
	_check("②d 멜 ♡4 = 매출 7000냥", not Deed.check("mel", 4, {"cafe_revenue_total": 6999})
		and Deed.check("mel", 4, {"cafe_revenue_total": 7000}))
	_check("②e 바나 ♡1 = 갱도 10층", not Deed.check("bana", 1, {"mine_depth": 9})
		and Deed.check("bana", 1, {"mine_depth": 10}))
	_check("②f 바나 ♡2 = 전투 XP 200", not Deed.check("bana", 2, {"combat_xp": 199})
		and Deed.check("bana", 2, {"combat_xp": 200}))
	_check("②g 바나 ♡3 = 나락 개방", not Deed.check("bana", 3, {"narak_key_found": false})
		and Deed.check("bana", 3, {"narak_key_found": true}))
	_check("②h 바나 ♡4 = 최고 격파 ≥10", not Deed.check("bana", 4, {"narak_best_boss": 0})
		and Deed.check("bana", 4, {"narak_best_boss": 10}))
	_check("②i 서브 주민 = 무조건 통과(deed 0 — 쉼터)",
		Deed.check("mochi", 1, {}) and Deed.check("ongi", 4, {}) and Deed.check("neo", 3, {}))
	_check("②j ♡5 = deed 아님(의지 시험 소관 — 메인도 통과)",
		Deed.check("miho", 5, {}) and Deed.check("bana", 5, {}))
	_check("②k 0칸 진급은 존재하지 않는다(방어)", not Deed.check("miho", 0, {}))

	# ── ③ 관문 트리거(대화 진입) — main 통합 ──
	print("── ③ 관문 트리거 ──")
	var m: Node = await _new_main()
	_dismiss_intro(m)
	m.onboarding.step = Onboarding.MEET_MIHO
	var r_miho: Resident = m._resident("miho")
	# 점수 만충·deed 미달 — 대화해도 진급 정지.
	r_miho.affinity.points = Affinity.MAX_POINTS
	m._run_harvested = 0
	m._start_resident_dialogue(r_miho)
	_close_dialogue(m)
	_check("③a 메인 deed 미달 = 대화해도 진급 잠금(점수는 만충 대기)",
		r_miho.affinity.hearts() == 0 and r_miho.affinity.pending_promotion())
	# deed 충족 — 다음 대화가 관문 이벤트가 된다(placeholder 발화 1줄이 앞에 선다).
	m._run_harvested = 30
	var gate: PackedStringArray = m._try_heart_promotion(r_miho)
	_check("③b deed 충족 + 대화 = ♡1 진급", r_miho.affinity.hearts() == 1)
	_check("③c 관문 발화 = placeholder 1줄(컷신 내용은 S9)",
		gate.size() == 1 and String(gate[0]) == m.HEART_GATE_PLACEHOLDER_LINE)
	_check("③d 대화 한 번에 한 칸만(점수 만충이어도 연쇄 진급 없음)",
		r_miho.affinity.pending_promotion() and r_miho.affinity.hearts() == 1)
	# ♡2 문턱(80) 미달 → 잠금, 충족 → 진급 — 실제 대화 경로로도 굴러간다.
	m._run_harvested = 79
	m._start_resident_dialogue(r_miho)
	_close_dialogue(m)
	_check("③e ♡2 deed(수확 80) 미달 = 잠금", r_miho.affinity.hearts() == 1)
	m._run_harvested = 80
	m._start_resident_dialogue(r_miho)
	_close_dialogue(m)
	_check("③f ♡2 deed 충족 = 대화 경로로 진급", r_miho.affinity.hearts() == 2)
	# 서브 주민 = 이벤트만(deed 0) — 대화 한 번으로 진급.
	var r_mochi: Resident = m._resident("mochi")
	r_mochi.affinity.points = 2 * Affinity.POINTS_PER_HEART
	m._start_resident_dialogue(r_mochi)
	_close_dialogue(m)
	_check("③g 서브 주민 = 이벤트만으로 진급(♡1)", r_mochi.affinity.hearts() == 1)
	m._start_resident_dialogue(r_mochi)
	_close_dialogue(m)
	_check("③h 서브 두 번째 대화 = ♡2(대기 소진)",
		r_mochi.affinity.hearts() == 2 and not r_mochi.affinity.pending_promotion())
	# ♡5 진급은 관문 이벤트로 안 오른다 — 의지 시험(S8-T6) 대기.
	var r_bana: Resident = m._resident("bana")
	r_bana.affinity.points = Affinity.MAX_POINTS
	r_bana.affinity.stage = 4
	m.mine_floors._depth = 60
	m._combat_xp = 999
	m._narak_key_found = true
	m._narak_best_boss = 50
	var gate5: PackedStringArray = m._try_heart_promotion(r_bana)
	_check("③i ♡4→5는 관문 이벤트가 아니다(의지 시험 대기 — deed 전부 충족이어도)",
		gate5.is_empty() and r_bana.affinity.hearts() == 4 and r_bana.affinity.pending_promotion())
	# 관계 트랙 없는 주민(옥자)은 판정 자체가 무동작.
	var r_okja: Resident = m._resident("okja")
	_check("③j 관계 트랙 없으면 무동작", m._try_heart_promotion(r_okja).is_empty())

	# ── ④ 비트 원장(seen 플래그·세이브 가법·재구애 조용한 진급) ──
	print("── ④ 비트 원장 ──")
	_check("④a 진급한 관문은 seen 마킹(미호 ♡1·♡2 — ♡3은 아직)",
		m._heart_bit_seen("miho", 1) and m._heart_bit_seen("miho", 2)
		and not m._heart_bit_seen("miho", 3))
	_check("④b 서브도 같은 원장(모찌 ♡1·♡2)",
		m._heart_bit_seen("mochi", 1) and m._heart_bit_seen("mochi", 2))
	# 재구애(이혼 후 재도달) 시뮬 — 호감도를 리셋해도 비트는 잔존하고, 재진급은 조용하다(발화 0).
	r_mochi.affinity.points = Affinity.POINTS_PER_HEART
	r_mochi.affinity.stage = 0
	var regate: PackedStringArray = m._try_heart_promotion(r_mochi)
	_check("④c 재구애 = 본 비트 재지급 없음(조용한 진급 — 발화 0·진급은 됨)",
		regate.is_empty() and r_mochi.affinity.hearts() == 1)
	# 세이브 왕복 — 비트 원장·stage가 함께 돌아온다.
	m._save_game()
	m.free()
	var m2: Node = await _new_main()   # _ready가 자동 복원
	_check("④d 세이브 왕복 — 비트 원장 보존",
		m2._heart_bit_seen("miho", 1) and m2._heart_bit_seen("miho", 2)
		and not m2._heart_bit_seen("miho", 3) and m2._heart_bit_seen("mochi", 2))
	_check("④e 세이브 왕복 — stage 보존(미호 ♡2·점수 만충 대기 그대로)",
		m2.affinity.hearts() == 2 and m2.affinity.pending_promotion())

	# ── ⑤ hearts() 파급 — 곱셈기·마일스톤이 stage에서 파생 ──
	print("── ⑤ hearts() 파급 ──")
	m2.mel_affinity.points = Affinity.MAX_POINTS   # 점수만 만충(stage 0)
	m2.mel_affinity.stage = 0
	_check("⑤a 멜 마진 — 점수 만충이어도 stage 0이면 base(×1.0)",
		is_equal_approx(CafeMargin.margin(m2.mel_affinity.hearts()), 1.0))
	m2.mel_affinity.stage = 5
	_check("⑤b stage 5로 진급하면 마진 만렙(×2.0)",
		is_equal_approx(CafeMargin.margin(m2.mel_affinity.hearts()), 2.0))
	m2.bana_affinity.points = Affinity.MAX_POINTS
	m2.bana_affinity.stage = 0
	_check("⑤c 바나 경비 — stage 0 = base 보호", BanaGuard.auto_block(m2.bana_affinity.hearts()) == 0)
	m2.neo_affinity.points = Affinity.MAX_POINTS
	m2.neo_affinity.stage = 0
	var base_price := 100
	_check("⑤d 네오 할인 — 점수 만충·stage 0 = 정가",
		StoreDiscount.price(base_price, m2.neo_affinity.hearts()) == base_price)
	# 마일스톤 하트 축(미호+멜) — stage 합으로 파생.
	m2.affinity.points = Affinity.MAX_POINTS
	m2.affinity.stage = 3
	m2.mel_affinity.stage = 2
	_check("⑤e 마일스톤 하트 축 = stage 합(점수 아님)", m2._milestone_hearts() == 5)

	# ── ⑥ 관계 탭 배지(T1 훅 실값) ──
	print("── ⑥ 진급 대기 배지 ──")
	var r2_miho: Resident = m2._resident("miho")
	r2_miho.affinity.points = Affinity.MAX_POINTS
	r2_miho.affinity.stage = 3
	_check("⑥a 점수 만충·관문 미통과 = '진급 대기' 배지", m2._heart_badge(r2_miho) == "진급 대기")
	var rows: Array = m2._heart_rows()
	var miho_row: Dictionary = rows[0]
	_check("⑥b 관계 탭 행에 배지가 실린다", String(miho_row["badge"]) == "진급 대기")
	r2_miho.affinity.stage = 5
	r2_miho.affinity.points = Affinity.MAX_POINTS
	_check("⑥c 대기 없으면 빈 배지(프레임은 빈 배지를 안 그림)", m2._heart_badge(r2_miho) == "")
	m2.free()

	# 뒷정리 — 이 테스트가 만든 세이브를 지운다(다른 테스트의 자동 복원 오염 방지).
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ heart_gate_test 전체 통과 ══")
	else:
		print("══ heart_gate_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)
