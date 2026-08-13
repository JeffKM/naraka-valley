extends SceneTree
# ★[S9-T9 / ADR-0067 결정 1㉣·2·4·5·6·12] T1 2인(모찌·네오) 서사 묶음 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 일상 대사 **4단** 분기(♡0/♡1+/♡3+/♡5+) — 단 경계가 관문 경계(♡1·♡3·♡5)와 정확히 맞고,
#      단 안에서는 같은 묶음이며, 오늘 두 번째 대화는 하트에 따라 온도만 다른 한 줄이다.
#   ② ♡3 **비밀 비트** — 캐릭터 본문이 나오고(placeholder 폴백 아님) ♡1·♡2·♡4는 폴백이다
#      (한 칸 집중 = 볼륨 상한 안의 선택. 나머지 칸은 owner 큐).
#      ★[S9b-T6] 여기에 **연애 4축 소급분**이 합류했다(②c·②c-2) — [ADR-0068] 결정 2가 S9의
#      "T1 2인은 연애 축 없음"을 뒤집어 모찌·네오에게 confession/divorce/spouse를 주입했다.
#   ③ 컷신 — 4동사 안이고(거절 0) **캐릭터당 1개**이며, 재생이 끝난 뒤 관문 발화가 맨 앞에 선
#      대화가 열린다(발화가 컷신에 삼켜지지 않는다). ★npc 동사 0 = 구역 순간이동 위험 0.
#   ④ 절기 물음 — 4개·짝 맞음·주 첫날 1회·같은 주 재발동 없음·**0점 계약**(선택 전후 점수·
#      stage 불변)·관문보다 뒤(대화 한 번에 사건 하나).
#   ⑤ 생일 — 훅 본문이 있고 placeholder가 아니며, Resident.BIRTHDAYS 배정과 main 경로가 물린다.
#   ⑥ 볼륨 상한(ADR-0067 결정 12) — **각 50~60줄** · 컷신 ≤2 · 절기 물음 4개.
#   ⑦ 봉인 법칙 가드(결정 8 체크리스트 기계 판정분) — 두 사람 본문 어디에도 플레이어 죄목의
#      **중심 평결**·그날 밤 **판독 결론**으로 읽힐 어휘가 없다(금칙어 스캔).
#   ⑧ 아트 배선(T9 아트 스코프) — 책·노트 아이콘이 인벤/토스트 경로에 잡히고, 우편함·혼백관
#      좌대 프롭 텍스처가 실존하며, 편지·책 열람이 **편지지 스킨**으로 갈렸다가 닫히면 되돌아온다.
#
# ★[S9b-T1 / ADR-0068 결정 6] **소프트 게이트 ㉠ 소급분 반영**: 조연(모찌·네오 포함)의 ♡3 진급이
#   이제 "메인 3인 중 1인 이상 stage≥3"을 요구한다. 이 스위트의 관심사는 ♡3 *본문·컷신*이라
#   셋업에서 게이트를 한 번 열고 시작한다(`_open_chorus_gate`). 게이트 자체의 거동(대기·소급·
#   점주 제외)은 kkaebi_arc_test ⑩이 소유한다 — 여기서 두 번 재지 않는다.
#
# 실행: ./run_tests.sh t1_arc   (헤드리스는 반드시 game/에서 · 순차)

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
# ★절기 물음 선택지는 넘기기로 못 지나간다(dialogue.advance의 has_choice 가드) — 이 분기가 없으면
#  주 첫날 대화에서 루프가 갇힌다(miho/mel/bana 아크 테스트와 같은 처방).
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

# 그 칸에 **얌전히** 앉힌다 — 점수가 딱 그 칸까지라 진급 대기가 서지 않는다(사건 없는 대화).
func _set_idle(r: Resident, stage: int) -> void:
	r.affinity.stage = stage
	r.affinity.points = stage * Affinity.POINTS_PER_HEART

# ★[S9b-T1 / ADR-0068 결정 6] 소프트 게이트 ㉠를 연다 — 조연(모찌·네오 포함)의 **♡3 진급**은
# 메인 3인 중 1인 이상이 stage≥3일 때만 성사된다(대화재 접촉 후에만 그날 밤/본질 비밀이 열린다).
# 이 스위트는 ♡3 비트를 재는 것이 본론이라, 게이트를 셋업에서 한 번 열고 시작한다.
# ★ `_set_idle`로 여는 이유: 만충(`_set_heart`)으로 두면 미호 쪽에 진급 대기가 서서, 뒤 검증이
#   모찌·네오만 보고 있는 동안 엉뚱한 관문이 끼어들 여지가 생긴다(대화 한 번에 사건 하나 규약).
func _open_chorus_gate(m: Node) -> void:
	_set_idle(m._resident("miho"), m.CHORUS_GATE_MAIN_STAGE)

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S9-T9 T1 2인(모찌·네오) 서사 묶음 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_drain(m)                                   # 신규 시작의 옥자 통보 대화
	m.onboarding.step = Onboarding.DONE
	_open_chorus_gate(m)                        # ★[S9b-T1] 소프트 게이트 ㉠(♡3 진급의 전제)

	for rid in ["mochi", "neo"]:
		var r: Resident = m._resident(rid)
		var who: Node2D = r.node
		var name_ko: String = r.display_name
		print("── [%s] ① 일상 대사 4단 ──" % name_ko)
		m.clock.day = 3                         # 주 첫날이 아닌 날(절기 물음 비발동 — ④에서 켠다)
		var l0: PackedStringArray = who.lines(0, true)
		var l1: PackedStringArray = who.lines(1, true)
		var l2: PackedStringArray = who.lines(2, true)
		var l3: PackedStringArray = who.lines(3, true)
		var l4: PackedStringArray = who.lines(4, true)
		var l5: PackedStringArray = who.lines(5, true)
		_check("①a 네 단이 서로 다르다(♡0 ≠ ♡1+ ≠ ♡3+ ≠ ♡5)",
			l0 != l1 and l1 != l3 and l3 != l5 and not l5.is_empty())
		_check("①b 단 안에서는 같은 묶음(♡1=♡2 · ♡3=♡4 — 4단이지 6단이 아니다)",
			l1 == l2 and l3 == l4)
		_check("①c 네 단 모두 3줄 이상(빈 단 없음)",
			l0.size() >= 3 and l1.size() >= 3 and l3.size() >= 3 and l5.size() >= 3)
		_check("①d 오늘 두 번째 대화 = 짧은 한 줄(하트에 따라 온도만 다르다)",
			who.lines(0, false).size() == 1 and who.lines(5, false).size() == 1
			and who.lines(0, false) != who.lines(5, false))

		print("── [%s] ② ♡3 비밀 비트 ──" % name_ko)
		var body: PackedStringArray = who.heart_gate_lines(3)
		_check("②a ♡3 관문 본문이 있다(placeholder 폴백 아님)",
			body.size() >= 5 and String(body[0]) != m.HEART_GATE_PLACEHOLDER_LINE)
		_check("②b ♡1·♡2·♡4는 본문 없음 = 프레임워크 폴백(한 칸 집중 — 결정 12 볼륨)",
			who.heart_gate_lines(1).is_empty() and who.heart_gate_lines(2).is_empty()
			and who.heart_gate_lines(4).is_empty())
		# ★[S9b-T6 / ADR-0068 결정 2 재작성] 옛 ②c는 "연애 훅이 **없다**"(S9 결정 1㉣ 범위)였는데,
		#   [ADR-0068] 결정 2가 그 범위를 **소급으로 뒤집었다**("S9에서 '깊은 단골'로 닫은 모찌·
		#   네오도 소급 개통"). 그래서 단언의 방향을 뒤집고 **4축까지 함께 잰다** — 이 스위트가
		#   T1 2인의 훅 인벤토리를 소유하므로, 소급이 반쪽으로 들어오면 여기서 걸려야 한다.
		_check("②c ★연애·이혼·배우자 훅이 전부 있다(S9b-T6 소급 개통 — 옛 \"훅 없음\"의 반대편)",
			who.has_method("spouse_lines") and who.has_method("confession_lines")
			and who.has_method("divorce_lines")
			and who.confession_lines(true).size() >= 4
			and who.confession_lines(false).size() >= 4
			and who.confession_lines(true) != who.confession_lines(false)
			and who.divorce_lines().size() >= 3)
		_check("②c-2 ★spouse_lines 4축(메인 8축의 절반 — day%4) · 결혼 후 대사가 ♡5 일상과 갈린다",
			who.SPOUSE_AXES.size() == 4
			and who.spouse_lines(0) == PackedStringArray(who.SPOUSE_AXES[0])
			and who.spouse_lines(5) == PackedStringArray(who.SPOUSE_AXES[1])
			and who.spouse_lines(3, false).size() == 1
			and who.spouse_lines(1) != who.lines(5, true))

		print("── [%s] ③ 컷신 → 대화 합류 ──" % name_ko)
		var steps: Array = who.heart_gate_cutscene(3)
		var runner := CutsceneRunner.new(steps)
		_check("③a 컷신이 4동사 안이다(거절 0 · 유효 스텝 있음)",
			runner.rejected_verbs().is_empty() and runner.step_count() == steps.size()
			and runner.step_count() > 0)
		_check("③b npc 동사 0(구역을 도는 T1이라 순간이동 위험을 구조적으로 없앤다)",
			not _has_verb(steps, "npc"))
		m._heart_bits = {}
		_set_heart(r, 2)
		r.affinity.last_talk_day = 0
		m._start_resident_dialogue(r)
		_check("③c 대화보다 먼저 컷신이 선다(대화는 아직 안 열림 · 진급은 됐다)",
			m.cutscene != null and not m.dialogue.is_open() and r.affinity.hearts() == 3)
		_settle(m)
		_check("③d 재생이 끝나면 관문 발화가 맨 앞에 선 대화가 열린다",
			m.cutscene == null and m.dialogue.is_open()
			and m.dialogue.line() == String(body[0]))
		_drain(m)
		_check("③e 재생 종료 후 화면·시계 원복",
			is_equal_approx(m.fade.modulate.a, 0.0) and m.clock.running
			and m._cam.offset.is_equal_approx(Vector2.ZERO))
		# 재구애(본 비트 잔존) = 조용한 진급(ADR-0022).
		_set_heart(r, 2)
		var regate: PackedStringArray = m._try_heart_promotion(r)
		_check("③f 본 비트는 재지급 없음(발화 0 · 진급은 됨)",
			regate.is_empty() and r.affinity.hearts() == 3)

		print("── [%s] ④ 절기 물음 ──" % name_ko)
		_check("④a 절기 4개 전부 물음이 있다(각 2~4지 · 반응 짝이 맞는다)", _all_seasons_ok(who))
		_check("④b 범위 밖 절기는 빈 dict(방어)",
			who.season_question(-1).is_empty() and who.season_question(4).is_empty())
		var q0: Dictionary = who.season_question(0)
		_set_idle(r, 3)                          # 관문이 안 서는 상태(물음이 밀리지 않게)
		m.clock.day = 15                         # (15-1)%7 == 0 → 주 첫날 · 절기 0(피안절)
		r.affinity.last_talk_day = 0
		m._start_resident_dialogue(r)
		# ★ 점수 스냅은 **대화가 열린 뒤**다 — 일일 대화 보상(daily_talk)은 대화 진입의 몫이라
		#   그 전에 재면 이 단언이 "선택이 아니라 대화 자체"를 재게 된다.
		var pts_before: int = r.affinity.points
		var stage_before: int = r.affinity.stage
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
			r.affinity.points == pts_before and r.affinity.stage == stage_before)
		_drain(m)
		m.clock.day = 17                         # 같은 주의 다른 날(주 첫날도 아니다)
		r.affinity.last_talk_day = 0
		m._start_resident_dialogue(r)
		_check("④g 주 중간엔 물음 없음", not _has_question(m, q0))
		_drain(m)
		m.clock.day = 22                         # (22-1)%7 == 0 → 다음 주 첫날 · 여전히 절기 0
		r.affinity.last_talk_day = 0
		m._start_resident_dialogue(r)
		_check("④h 다음 주 첫날엔 다시 묻는다", _has_question(m, q0))
		_drain(m)
		# 관문보다 뒤 — 대화 한 번에 사건 하나.
		m.clock.day = 29                         # 주 첫날 · 절기 1(유화절)
		m._heart_bits = {}
		_set_heart(r, 2)
		r.affinity.last_talk_day = 0
		m._start_resident_dialogue(r)
		_settle(m)
		_check("④i 관문이 선 대화엔 물음이 안 붙는다(관문 > 물음)",
			r.affinity.hearts() == 3 and not _has_question(m, who.season_question(1)))
		_drain(m)

		print("── [%s] ⑤ 생일 ──" % name_ko)
		var bday: PackedStringArray = who.birthday_lines()
		_check("⑤a 생일 훅 본문(placeholder 폴백 아님)",
			bday.size() >= 2 and String(bday[0]) != m.BIRTHDAY_PLACEHOLDER_LINE)
		var b: Array = Resident.birthday_of(rid)
		_check("⑤b 생일 배정이 살아 있다(달력 단일 출처)", b.size() == 2)
		var bday_day := _find_birthday_day(rid)
		_check("⑤c 그 날짜가 실제로 이 사람 생일로 판정된다",
			bday_day > 0 and r.is_birthday_on(bday_day))
		_set_idle(r, 3)                          # 관문이 안 서는 상태(생일이 대화의 사건이 되게)
		m.clock.day = bday_day
		r.affinity.last_talk_day = 0
		m._start_resident_dialogue(r)
		_check("⑤d 생일 당일 대화는 생일 발화로 열린다(평소 묶음 앞)",
			m.dialogue.is_open() and m.dialogue.line() == String(bday[0]))
		_drain(m)

		print("── [%s] ⑥ 볼륨 ──" % name_ko)
		var total := _total_lines(who)
		print("    본문 줄 수(선택지 제외) = %d" % total)
		_check("⑥a 대사 볼륨이 상한 안(50~60줄 — 결정 12)", total >= 50 and total <= 60)
		_check("⑥b 컷신 ≤2(♡3 한 칸)", _cutscene_count(who) == 1)
		_check("⑥c 절기 물음 4개(절기당 1)", who.SEASON_QUESTIONS.size() == 4)
		# ★[S9b-T6] 소급 개통으로 **세 번째 온도**(배우자)가 붙었다 — ♡5는 이제 연인 단이고
		#   (♡5 진급의 유일한 경로가 고백 수락이다) 결혼 후엔 spouse_lines가 lines()를 대신한다.
		_check("⑥d 오늘 두 번째 한 줄이 세 종류(평소 · 연인 · 배우자)",
			String(who.LINE_AGAIN) != String(who.LINE_AGAIN_BOND)
			and String(who.LINE_AGAIN_BOND) != String(who.LINE_AGAIN_SPOUSE))

		print("── [%s] ⑦ 봉인 법칙 ──" % name_ko)
		# 두 사람은 **자기 몸·자기 코어에 대한 관측**만 말한다 — 플레이어 죄목의 중심 평결도,
		# 그날 밤의 판독 결론도 본문에 두지 않는다(검열이 아니라 회귀 가드다: 나중 손질이
		# 평결 문장을 흘려 넣으면 여기서 걸린다).
		var verdicts := ["네 죄는", "너의 죄는", "네가 지은 죄", "네 죄목", "그러니까 네가",
			"너 때문에 옥자", "네가 옥자를", "너는 외면했", "네가 외면한",
			"옥자의 눈물", "강림의 명부", "차사 명부", "그날 밤에 일어난"]
		var offender := _scan_forbidden(who, verdicts)
		_check("⑦a 중심 평결·판독 결론 어휘 0", offender == "")
		if offender != "":
			print("      ↳ 걸린 줄: " + offender)
		_check("⑦b ♡3 비트는 **관측**이다(뜻을 스스로 정하지 않는다)",
			_joined(who.GATE_HEART_3).contains("모른") or _joined(who.GATE_HEART_3).contains("못 "))
		_check("⑦c 본문은 Affinity를 모른다(0점 계약의 구조적 근거)",
			not _src(rid).contains("Affinity") and not _src(rid).contains("add_points"))
		_set_idle(r, 0)

	# ── ⑧ 아트 배선 ──
	print("── ⑧ 아트 배선 ──")
	var bid: String = String(Books.book_ids()[0])
	var nid: String = String(Books.note_ids()[0])
	_check("⑧a 책·노트 아이콘이 토스트 경로에 잡힌다(23 id가 2장을 공유)",
		m._item_icon(bid) == m.BOOK_ICON and m._item_icon(nid) == m.NOTE_ICON
		and m.BOOK_ICON != m.NOTE_ICON)
	var icons := {}
	m._merge_book_icons(icons)
	_check("⑧b 인벤·핫바 아이콘 dict에 전량(책 8 + 노트 15)이 얹힌다",
		icons.size() == Books.all_ids().size() and icons.get(bid) == m.BOOK_ICON)
	_check("⑧c 우편함 프롭 텍스처 실존(그레이박스 폴백 탈출 — 코드 0줄 배선)",
		m._prop_tex("mailbox") != null)
	_check("⑧d 혼백관 서가 좌대 텍스처 실존 + 폭이 좌대 간격(40) 안",
		m._prop_tex("museum_shelf") != null
		and m._prop_tex("museum_shelf").get_size().x <= 40.0)
	# 편지지 스킨 — 책을 펼치면 갈리고, 닫으면 되돌아온다.
	_check("⑧e 기본 스킨은 한지", String(m._dlg_skin) == "")
	m._read_book_now(bid)
	_check("⑧f 책·편지를 펼치면 편지지 스킨으로 갈린다",
		m.dialogue.is_open() and String(m._dlg_skin) == "letter")
	_drain(m)
	_check("⑧g 닫히면 기본 한지로 되돌아온다(되돌리기는 종료 한 곳)",
		String(m._dlg_skin) == "")

	m.free()
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ t1_arc_test 전체 통과 ══")
	else:
		print("══ t1_arc_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)

# ── 헬퍼 ────────────────────────────────────────────────────────────────────
func _has_verb(steps: Array, verb: String) -> bool:
	for s in steps:
		if typeof(s) == TYPE_DICTIONARY and String((s as Dictionary).get("verb", "")) == verb:
			return true
	return false

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

func _all_seasons_ok(who: Node2D) -> bool:
	for s in 4:
		var q: Dictionary = who.season_question(s)
		if q.is_empty() or String(q.get("line", "")) == "":
			return false
		var opts := PackedStringArray(q.get("options", PackedStringArray()))
		var reps := PackedStringArray(q.get("replies", PackedStringArray()))
		if opts.size() != reps.size() or opts.size() < DialogueBox.CHOICE_MIN \
				or opts.size() > DialogueBox.CHOICE_MAX:
			return false
	return true

# 그 사람 생일에 해당하는 절대 날짜(1..112 안에서 찾는다 — 한 해면 반드시 한 번 온다).
func _find_birthday_day(rid: String) -> int:
	for d in range(1, 113):
		if Resident.is_birthday(rid, d):
			return d
	return -1

# 그 사람이 가진 **캐릭터 본문** 줄의 총합(볼륨 실측). 절기 물음은 질문 줄 + 반응만 센다 —
# 선택지 항목은 *플레이어의 말*이라 캐릭터 대사 볼륨이 아니다(결정 12의 셈법).
# LINE_AGAIN 2종은 프레임워크 슬롯 채움 한 줄짜리라 여기 안 넣는다(⑥d가 따로 존재를 잰다).
func _total_lines(who: Node2D) -> int:
	var n := 0
	for pack in [who.LINES_INTRO, who.LINES_WARMING, who.LINES_CLOSE, who.LINES_BOND,
			who.GATE_HEART_3, who.BIRTHDAY]:
		n += (pack as Array).size()
	for q in who.SEASON_QUESTIONS:
		n += 1 + PackedStringArray(q["replies"]).size()
	return n

func _cutscene_count(who: Node2D) -> int:
	var n := 0
	for t in [1, 2, 3, 4]:
		if not (who.heart_gate_cutscene(t) as Array).is_empty():
			n += 1
	return n

func _joined(pack: Array) -> String:
	return "\n".join(PackedStringArray(pack))

# 그 사람의 전 본문에서 금칙어를 찾는다(걸린 줄을 돌려준다 — 없으면 "").
func _scan_forbidden(who: Node2D, words: Array) -> String:
	var all: Array = []
	for pack in [who.LINES_INTRO, who.LINES_WARMING, who.LINES_CLOSE, who.LINES_BOND,
			who.GATE_HEART_3, who.BIRTHDAY]:
		all.append_array(pack as Array)
	for q in who.SEASON_QUESTIONS:
		all.append(q["line"])
		all.append_array(q["replies"] as Array)
	for ln in all:
		for w in words:
			if String(ln).contains(String(w)):
				return String(ln)
	return ""

# 캐릭터 파일의 **주석을 걷어낸 코드 본문**(주석이 검사 문자열을 우연히 품는 오탐 방지).
func _src(rid: String) -> String:
	var f := FileAccess.open("res://%s.gd" % rid, FileAccess.READ)
	if f == null:
		return ""
	var out := PackedStringArray()
	for ln in f.get_as_text().split("\n"):
		if not String(ln).strip_edges().begins_with("#"):
			out.append(String(ln))
	return "\n".join(out)
