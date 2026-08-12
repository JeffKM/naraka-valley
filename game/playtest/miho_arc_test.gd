extends SceneTree
# ★[S9-T4 / ADR-0067 결정 1·4·5·6·7·11·12] 미호 아크 본문 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 관문 ♡1~4 — 캐릭터 본문이 나오고(placeholder 폴백 아님) 컷신이 4동사 안에서 재생된 뒤
#      대화가 합류한다(발화가 컷신에 삼켜지지 않는다).
#   ② 재구애(본 비트 잔존) = 조용한 진급 — 발화 0 · 컷신 0(ADR-0022).
#   ③ 일상 대사 **4단** 분기(♡0/♡1+/♡3+/♡5+) + 오늘 두 번째 대화의 짧은 한 줄 + 배우자 8축.
#   ④ 절기 물음 — 주 첫날 첫 대화에 1회 · 같은 주 재발동 없음 · **0점 계약**(선택 전후 점수·
#      stage 불변) · 관문/생일보다 뒤(대화 한 번에 사건 하나) · 세이브 왕복.
#   ⑤ 편지 — 관문 성사로 큐에 들어가고 **다음 날 아침** 도착 · 중복 발송 없음 · 본문 존재.
#   ⑥ confession/divorce/birthday 훅 유효(수락·거절이 서로 다르고, 작별 첫 줄이 토스트감).
#   ⑦ 볼륨 상한(ADR-0067 결정 12) — 대사 줄 수 ≈250~300 이내 · 관문 컷신 4개 · 편지 4통 ·
#      절기 물음 4개.
#   ⑧ 봉인 법칙 가드(ADR-0067 결정 8 체크리스트 기계 판정분) — 미호 본문 어디에도 플레이어
#      죄목의 **중심 평결**로 읽힐 어휘가 없다(금칙어 스캔).
#
# 실행: ./run_tests.sh miho_arc   (헤드리스는 반드시 game/에서 · 순차)

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

# 관문 컷신이 서 있으면 끝까지 재생해 뒤따르는 대화를 연다(대화는 안 닫는다 — 첫 줄을 재야 한다).
func _settle(m: Node) -> void:
	var guard := 0
	while m.cutscene != null and guard < 200:
		m._tick_cutscene(0.1)
		guard += 1

# 판을 비운다 — 컷신 재생 → 선택지는 첫 항 → 나머지는 넘기기(플레이어와 같은 경로).
func _drain(m: Node) -> void:
	_settle(m)
	var guard := 0
	while m.dialogue.is_open() and guard < 200:
		if m.dialogue.has_choice():
			m.dialogue.choose(0)
		else:
			m.dialogue.advance()
		guard += 1

# 그 사람을 "점수 만충 + 지정 stage"로 세운다(★관례: points와 stage는 **동반** 세팅).
func _set_heart(r: Resident, stage: int) -> void:
	r.affinity.stage = stage
	r.affinity.points = Affinity.MAX_POINTS

# 그 칸에 **얌전히** 앉힌다 — 점수가 딱 그 칸까지라 진급 대기도, 고백 제안도 서지 않는다.
# 절기 물음처럼 "아무 사건도 없는 대화"를 재려면 이 상태여야 한다(사건 하나 규율 때문에
# 관문·의지 시험이 서 있으면 물음이 밀린다 — 그게 ④k가 재는 계약이다).
func _set_idle(r: Resident, stage: int) -> void:
	r.affinity.stage = stage
	r.affinity.points = stage * Affinity.POINTS_PER_HEART

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S9-T4 미호 아크 본문 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_drain(m)                                   # 신규 시작의 옥자 통보 대화
	m.onboarding.step = Onboarding.DONE
	var r_miho: Resident = m._resident("miho")
	var miho: Node2D = r_miho.node
	m._run_harvested = 100000                   # deed는 이 스위트의 관심사가 아니다(전 칸 충족)
	m.clock.day = 3                             # 주 첫날이 아닌 날(절기 물음 비발동 — ④에서 따로 켠다)

	# ── ① 관문 ♡1~4 = 본문 + 컷신 → 대화 합류 ──
	print("── ① 관문 ♡1~4 ──")
	for target in [1, 2, 3, 4]:
		_set_heart(r_miho, target - 1)
		var body: PackedStringArray = miho.heart_gate_lines(target)
		var steps: Array = miho.heart_gate_cutscene(target)
		var runner := CutsceneRunner.new(steps)
		_check("①a♡%d 관문 본문이 있다(placeholder 폴백 아님)" % target,
			body.size() >= 3 and String(body[0]) != m.HEART_GATE_PLACEHOLDER_LINE)
		_check("①b♡%d 컷신이 4동사 안이다(거절 0 · 유효 스텝 있음)" % target,
			runner.rejected_verbs().is_empty() and runner.step_count() == steps.size()
			and runner.step_count() > 0)
		m._start_resident_dialogue(r_miho)
		_check("①c♡%d 대화보다 먼저 컷신이 선다(대화는 아직 안 열림)" % target,
			m.cutscene != null and not m.dialogue.is_open()
			and r_miho.affinity.hearts() == target)
		_settle(m)
		_check("①d♡%d 재생이 끝나면 관문 발화가 맨 앞에 선 대화가 열린다" % target,
			m.cutscene == null and m.dialogue.is_open()
			and m.dialogue.line() == String(body[0]))
		_drain(m)
	# 컷신이 끝나면 화면·시계가 원복된다(암전인 채로 안 끝난다 — 러너 계약의 라이브 확인).
	_check("①e 재생 종료 후 화면·시계 원복",
		is_equal_approx(m.fade.modulate.a, 0.0) and m.clock.running
		and m._cam.offset.is_equal_approx(Vector2.ZERO))

	# ── ② 재구애 = 조용(비트 잔존 · 컷신 안 섬) ──
	print("── ② 재구애 = 조용 ──")
	_set_heart(r_miho, 1)                       # ♡2 비트는 ①에서 이미 봤다
	var regate: PackedStringArray = m._try_heart_promotion(r_miho)
	_check("②a 본 비트는 재지급 없음(발화 0 · 진급은 됨)",
		regate.is_empty() and r_miho.affinity.hearts() == 2)
	_set_heart(r_miho, 2)
	m._start_resident_dialogue(r_miho)
	_check("②b 조용한 진급엔 컷신도 안 선다(사건 없음 — 평소 대화로 열린다)",
		m.cutscene == null and m.dialogue.is_open() and r_miho.affinity.hearts() == 3)
	_drain(m)

	# ── ③ 일상 대사 4단 + 배우자 8축 ──
	print("── ③ 일상 대사 4단 ──")
	var l0: PackedStringArray = miho.lines(0, true)
	var l1: PackedStringArray = miho.lines(1, true)
	var l2: PackedStringArray = miho.lines(2, true)
	var l3: PackedStringArray = miho.lines(3, true)
	var l4: PackedStringArray = miho.lines(4, true)
	var l5: PackedStringArray = miho.lines(5, true)
	_check("③a 네 단이 서로 다르다(♡0 ≠ ♡1+ ≠ ♡3+ ≠ ♡5)",
		l0 != l1 and l1 != l3 and l3 != l5 and not l5.is_empty())
	_check("③b 단 안에서는 같은 묶음(♡1=♡2 · ♡3=♡4 — 4단이지 6단이 아니다)",
		l1 == l2 and l3 == l4)
	_check("③c 오늘 두 번째 대화 = 짧은 한 줄(하트에 따라 온도만 다르다)",
		miho.lines(0, false).size() == 1 and miho.lines(5, false).size() == 1
		and miho.lines(0, false) != miho.lines(5, false))
	# 배우자 8축 — day 파생이라 상태가 0이고, 여덟 축이 서로 다르다.
	var axes := {}
	for d in 8:
		var ax: PackedStringArray = miho.spouse_lines(d, true)
		axes[String(ax[0])] = true
		_check("③d 배우자 축 %d는 비어 있지 않다" % d, ax.size() >= 2)
	_check("③e 여덟 축이 전부 다르다(8일 주기)", axes.size() == 8)
	_check("③f 축은 day 파생 — 같은 날은 언제 물어도 같다(무상태)",
		miho.spouse_lines(3, true) == miho.spouse_lines(3, true)
		and miho.spouse_lines(11, true) == miho.spouse_lines(3, true))
	_check("③g 배우자도 오늘 두 번째 대화는 한 줄", miho.spouse_lines(3, false).size() == 1)
	# main 이음매 — 결혼 상태면 lines() 대신 배우자 묶음이 나온다.
	_set_heart(r_miho, Affinity.MAX_HEARTS)
	m._romance_partner = "miho"
	m._spouse_id = "miho"
	m.clock.day = 10                            # 주 첫날 아님(물음 비발동)
	r_miho.affinity.last_talk_day = 0
	m._start_resident_dialogue(r_miho)
	_check("③h main이 배우자 묶음으로 갈아탄다",
		m.dialogue.line() == String(miho.spouse_lines(10, true)[0])
		and m.dialogue.line() != String(miho.lines(5, true)[0]))
	_drain(m)
	m._spouse_id = ""
	m._romance_partner = ""
	_set_idle(r_miho, 3)     # ★ 진급 대기·고백 제안이 안 서는 상태(물음이 밀리지 않게)

	# ── ④ 절기 물음(주 첫날 · 1회 · 0점) ──
	print("── ④ 절기 물음 ──")
	var q0: Dictionary = miho.season_question(0)
	_check("④a 절기 4개 전부 물음이 있다(각 2~4지 · 반응 짝이 맞는다)", _all_seasons_ok(miho))
	_check("④b 범위 밖 절기는 빈 dict(방어)",
		miho.season_question(-1).is_empty() and miho.season_question(4).is_empty())
	m.clock.day = 15                            # (15-1)%7 == 0 → 주 첫날 · 절기 0(피안절)
	r_miho.affinity.last_talk_day = 0
	m._start_resident_dialogue(r_miho)
	# ★ 점수 스냅은 **대화가 열린 뒤**다 — 일일 대화 보상(daily_talk)은 대화 진입의 몫이라
	#   그 전에 재면 이 단언이 "선택이 아니라 대화 자체"를 재게 된다.
	var pts_before: int = r_miho.affinity.points
	var stage_before: int = r_miho.affinity.stage
	_check("④c 주 첫날 첫 대화 = 질문은 맨 뒤(첫 줄이 아니다)",
		m.dialogue.is_open() and String(m.dialogue.line()) != String(q0["line"]))
	while m.dialogue.is_open() and not m.dialogue.has_choice():
		m.dialogue.advance()
	_check("④d 질문 줄에 선택지가 선다(문항 = 캐릭터 소유 본문)",
		m.dialogue.has_choice() and m.dialogue.line() == String(q0["line"])
		and m.dialogue.choices() == PackedStringArray(q0["options"]))
	m.dialogue.choose(1)
	_check("④e 고르면 반응 한 줄로 교체된다",
		m.dialogue.is_open() and m.dialogue.line() == String(PackedStringArray(q0["replies"])[1]))
	_check("④f ★0점 계약 — 선택 전후 점수·stage 불변",
		r_miho.affinity.points == pts_before and r_miho.affinity.stage == stage_before)
	_drain(m)
	# 같은 주엔 다시 안 묻는다(그날 두 번째 대화도, 그 주의 다른 날도).
	r_miho.affinity.last_talk_day = 0
	m._start_resident_dialogue(r_miho)
	_check("④g 같은 날 두 번째 대화엔 물음 없음", not _has_question(m, q0))
	_drain(m)
	m.clock.day = 17                            # 같은 주의 다른 날(주 첫날도 아니다)
	r_miho.affinity.last_talk_day = 0
	m._start_resident_dialogue(r_miho)
	_check("④h 주 중간엔 물음 없음", not _has_question(m, q0))
	_drain(m)
	# 다음 주 첫날 = 다시 묻는다. 절기가 바뀌면 문항도 바뀐다.
	m.clock.day = 22                            # (22-1)%7 == 0 → 주 첫날 · 여전히 절기 0
	r_miho.affinity.last_talk_day = 0
	m._start_resident_dialogue(r_miho)
	_check("④i 다음 주 첫날엔 다시 묻는다", _has_question(m, q0))
	_drain(m)
	m.clock.day = 36                            # (36-1)%7 == 0 → 주 첫날 · 절기 1(유화절)
	r_miho.affinity.last_talk_day = 0
	m._start_resident_dialogue(r_miho)
	_check("④j 절기가 바뀌면 문항도 바뀐다",
		_has_question(m, miho.season_question(1)) and not _has_question(m, q0))
	_drain(m)
	# 관문·생일보다 뒤 — 대화 한 번에 사건 하나.
	m.clock.day = 43                            # 주 첫날 · 절기 1
	_set_heart(r_miho, 3)
	m._heart_bits = {}
	r_miho.affinity.last_talk_day = 0
	m._start_resident_dialogue(r_miho)
	_settle(m)
	_check("④k 관문이 선 대화엔 물음이 안 붙는다(관문 > 물음)",
		r_miho.affinity.hearts() == 4 and not _has_question(m, miho.season_question(1)))
	_drain(m)
	_set_idle(r_miho, 4)     # 관문·고백이 안 서는 상태로 되돌린다(다음 단언은 물음만 잰다)
	# 세이브 왕복 — 이번 주에 이미 물었다는 원장이 살아 돌아온다.
	m.clock.day = 50                            # (50-1)%7 == 0 → 주 첫날 · 절기 1
	r_miho.affinity.last_talk_day = 0
	m._start_resident_dialogue(r_miho)
	_check("④m 왕복 전 — 이 주엔 물었다", _has_question(m, miho.season_question(1)))
	_drain(m)
	m._save_game()
	var saved_week: int = int(m._season_q_week.get("miho", -1))
	m.free()
	var m2: Node = await _new_main()
	_drain(m2)
	_check("④n 세이브 왕복 — 절기 물음 원장 보존(같은 주 재발동 없음)",
		int(m2._season_q_week.get("miho", -1)) == saved_week and saved_week >= 0)
	m2.free()
	cleaner.delete_save()

	# ── ⑤ 편지(관문 여진) ──
	print("── ⑤ 편지 ──")
	var m3: Node = await _new_main()
	_drain(m3)
	m3.onboarding.step = Onboarding.DONE
	var r3: Resident = m3._resident("miho")
	var miho3: Node2D = r3.node
	m3._run_harvested = 100000
	m3.clock.day = 3
	_check("⑤a 시작 시 우편함은 비어 있다", m3.mailbox.pending_count() == 0
		and not m3.mailbox.has_unread())
	_set_heart(r3, 0)
	m3._try_heart_promotion(r3)
	var lid: String = miho3.heart_gate_letter(1)
	_check("⑤b 관문 ♡1 성사 = 편지가 큐에 든다(같은 날 도착은 없다)",
		lid != "" and m3.mailbox.pending_count() == 1 and not m3.mailbox.has_unread())
	m3._on_day_advanced(m3.clock.day + 1)
	_check("⑤c 다음 날 아침 도착 = 미독 1통",
		m3.mailbox.pending_count() == 0 and m3.mailbox.unread_count() == 1
		and m3.mailbox.next_unread() == lid)
	_check("⑤d 본문·발신인이 실려 있다",
		Mailbox.sender_of(lid) == "미호" and Mailbox.lines_of(lid).size() >= 3)
	# 재구애(비트 잔존)로 같은 관문이 다시 성사돼도 편지는 두 번 안 온다.
	_set_heart(r3, 0)
	m3._try_heart_promotion(r3)
	_check("⑤e 중복 발송 없음(mailbox가 방어 — 사건 코드는 기억 불요)",
		m3.mailbox.pending_count() == 0 and m3.mailbox.unread_count() == 1)
	# 네 칸이 각기 다른 편지를 부르고, 전부 테이블에 있다.
	var ids := {}
	for t in [1, 2, 3, 4]:
		var id: String = miho3.heart_gate_letter(t)
		ids[id] = true
		_check("⑤f♡%d 편지 id가 테이블에 실존" % t, id != "" and Mailbox.has_letter(id))
	_check("⑤g 네 칸이 각기 다른 편지", ids.size() == 4)
	_check("⑤h 관문 밖 칸은 편지 없음", miho3.heart_gate_letter(5) == "")

	# ── ⑥ confession · divorce · birthday 훅 ──
	print("── ⑥ 고백·이혼·생일 훅 ──")
	var acc: PackedStringArray = miho3.confession_lines(true)
	var rej: PackedStringArray = miho3.confession_lines(false)
	_check("⑥a 수락·거절이 각기 본문을 가지고 서로 다르다",
		acc.size() >= 2 and rej.size() >= 2 and acc != rej
		and String(acc[0]) != m3.CONFESS_ACCEPT_LINE and String(rej[0]) != m3.CONFESS_REJECT_LINE)
	var far: PackedStringArray = miho3.divorce_lines()
	_check("⑥b 작별 훅 — 첫 줄이 혼자 서는 한 문장(토스트 경로)",
		not far.is_empty() and String(far[0]).length() >= 6
		and m3._divorce_farewell_line(r3) == String(far[0]))
	_check("⑥c 생일 훅", miho3.birthday_lines().size() >= 2
		and String(miho3.birthday_lines()[0]) != m3.BIRTHDAY_PLACEHOLDER_LINE)

	# ── ⑦ 볼륨 상한(ADR-0067 결정 12) ──
	print("── ⑦ 볼륨 ──")
	var total := _total_lines(miho3)
	print("    대사 줄 수(전 묶음 합) = %d" % total)
	_check("⑦a 메인 1인 대사 볼륨이 상한 안(≈250~300줄)", total > 120 and total <= 300)
	_check("⑦b 관문 컷신 4개(관문당 1)", _cutscene_count(miho3) == 4)
	_check("⑦c 편지 4통(3~5통 범위)", ids.size() >= 3 and ids.size() <= 5)
	_check("⑦d 절기 물음 4개(절기당 1)", miho3.SEASON_QUESTIONS.size() == 4)

	# ── ⑧ 봉인 법칙 가드(기계 판정분) ──
	print("── ⑧ 봉인 법칙 ──")
	# 미호는 자기가 본 것만 말한다 — **플레이어 죄목의 중심 평결**로 읽힐 어휘를 본문에 두지 않는다.
	# (검열이 아니라 회귀 가드다: 나중 손질이 평결 문장을 흘려 넣으면 여기서 걸린다.)
	var verdicts := ["네 죄는", "너의 죄는", "네가 지은 죄", "네 죄목", "그러니까 네가",
		"너 때문에 옥자", "네가 옥자를 죽", "너는 외면했", "네가 외면한"]
	var offender := _scan_forbidden(miho3, verdicts)
	_check("⑧a 중심 평결 어휘 0(플레이어 죄목을 미호가 판결하지 않는다)", offender == "")
	if offender != "":
		print("      ↳ 걸린 줄: " + offender)
	_check("⑧b ♡4 조각은 **증언**이다(미호가 본 것을 말하고 뜻은 안 정한다)",
		_joined(miho3.GATE_HEART_4).contains("나도 몰라"))
	_check("⑧c 미호 본문은 Affinity를 모른다(0점 계약의 구조적 근거)",
		not _miho_source().contains("Affinity") and not _miho_source().contains("add_points"))

	m3.free()
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ miho_arc_test 전체 통과 ══")
	else:
		print("══ miho_arc_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)

# ── 헬퍼 ────────────────────────────────────────────────────────────────────
# 지금 열린 대화에 그 절기 물음이 실려 있는가(질문 줄이 대사 어딘가에 있는가).
func _has_question(m: Node, q: Dictionary) -> bool:
	if q.is_empty() or not m.dialogue.is_open():
		return false
	var want := String(q.get("line", ""))
	var guard := 0
	while m.dialogue.is_open() and guard < 200:
		if m.dialogue.line() == want:
			return true
		if m.dialogue.has_choice():
			return false      # 다른 물음의 선택지 — 여기서 멈춘다(넘기기가 막혀 있다)
		m.dialogue.advance()
		guard += 1
	return false

func _all_seasons_ok(miho: Node2D) -> bool:
	for s in 4:
		var q: Dictionary = miho.season_question(s)
		if q.is_empty() or String(q.get("line", "")) == "":
			return false
		var opts := PackedStringArray(q.get("options", PackedStringArray()))
		var reps := PackedStringArray(q.get("replies", PackedStringArray()))
		if opts.size() != reps.size() or opts.size() < DialogueBox.CHOICE_MIN \
				or opts.size() > DialogueBox.CHOICE_MAX:
			return false
	return true

# 미호가 가진 모든 대사 줄의 총합(볼륨 실측 — 선택지 항목·반응까지 센다).
func _total_lines(miho: Node2D) -> int:
	var n := 0
	for pack in [miho.LINES_INTRO, miho.LINES_WARMING, miho.LINES_CLOSE, miho.LINES_LOVER,
			miho.GATE_HEART_1, miho.GATE_HEART_2, miho.GATE_HEART_3, miho.GATE_HEART_4,
			miho.CONFESSION_ACCEPT, miho.CONFESSION_REJECT, miho.DIVORCE_FAREWELL, miho.BIRTHDAY]:
		n += (pack as Array).size()
	for ax in miho.SPOUSE_AXES:
		n += (ax as Array).size()
	for q in miho.SEASON_QUESTIONS:
		n += 1 + PackedStringArray(q["options"]).size() + PackedStringArray(q["replies"]).size()
	return n + 3   # LINE_AGAIN 3종

func _cutscene_count(miho: Node2D) -> int:
	var n := 0
	for t in [1, 2, 3, 4]:
		if not (miho.heart_gate_cutscene(t) as Array).is_empty():
			n += 1
	return n

func _joined(pack: Array) -> String:
	return "\n".join(PackedStringArray(pack))

# 미호의 전 본문에서 금칙어를 찾는다(걸린 줄을 돌려준다 — 없으면 "").
func _scan_forbidden(miho: Node2D, words: Array) -> String:
	var all: Array = []
	for pack in [miho.LINES_INTRO, miho.LINES_WARMING, miho.LINES_CLOSE, miho.LINES_LOVER,
			miho.GATE_HEART_1, miho.GATE_HEART_2, miho.GATE_HEART_3, miho.GATE_HEART_4,
			miho.CONFESSION_ACCEPT, miho.CONFESSION_REJECT, miho.DIVORCE_FAREWELL, miho.BIRTHDAY]:
		all.append_array(pack as Array)
	for ax in miho.SPOUSE_AXES:
		all.append_array(ax as Array)
	for q in miho.SEASON_QUESTIONS:
		all.append(q["line"])
		all.append_array(q["replies"] as Array)
	for id in Mailbox.LETTERS:
		if String(Mailbox.LETTERS[id].get("from", "")) == "미호":
			all.append_array(Mailbox.LETTERS[id].get("lines", []) as Array)
	for ln in all:
		for w in words:
			if String(ln).contains(String(w)):
				return String(ln)
	return ""

# miho.gd의 **주석을 걷어낸 코드 본문**(주석이 검사 문자열을 우연히 품는 오탐 방지).
func _miho_source() -> String:
	var f := FileAccess.open("res://miho.gd", FileAccess.READ)
	if f == null:
		return ""
	var out := PackedStringArray()
	for ln in f.get_as_text().split("\n"):
		if not String(ln).strip_edges().begins_with("#"):
			out.append(String(ln))
	return "\n".join(out)
