extends SceneTree
# ★[S9b-T2 / ADR-0068 결정 3·5·6] 설화 풀 온보딩 — 헤드리스 검증.
#
# 규약은 kkaebi_arc_test를 그대로 상속한다(S9b-T1이 세운 조연 arc_test 규약 — 볼륨 측정·금칙어
# 31어 가드·훅 존재·관문 드레인·절기 물음·생일·편지). 캐릭터별로 다른 것은 ⑨의 **구조 단언**뿐이다.
#
# 무엇을 보증하나:
#   ① 인물 층 배선 — 레코드 1건이 실제로 등록되고(id·표시명·세이브 키·선물 채널·집/스케줄),
#      세 스테이션이 서로 다르며 다른 주민 자리와 겹치지 않는다(칸 충돌 = 마주보기 판정 파손).
#   ② 일상 대사 **4단** 분기(♡0/♡1+/♡3+/♡5+) — 단 경계가 관문 경계와 맞고, 단 안에서는 같은
#      묶음이며, 오늘 두 번째 대화는 하트에 따라 온도만 다른 한 줄이다.
#   ③ 관문 발화 **♡1~4 네 칸 전부** 캐릭터 본문이다(placeholder 폴백 0 — 조연 4단 아크).
#   ④ 컷신 — 4동사 안이고(거절 0) 칸마다 하나이며 **npc 동사 0**(세 구역-자리를 도는 인물이라
#      순간이동 위험을 구조적으로 없앤다), 재생이 끝나면 관문 발화가 맨 앞에 선 대화가 열린다.
#   ⑤ 여진 편지 — ♡2·♡3·♡4가 각기 실존하는 편지를 지목하고(♡1은 없음) 발신인이 설화이며,
#      관문 성사가 큐에 넣고 다음 날 아침 도착한다.
#   ⑥ 절기 물음 4개 — 짝이 맞고, 주 첫날 첫 대화에 서며, **0점 계약**(선택 전후 점수·stage 불변).
#   ⑦ 생일 — 훅 본문 + Resident.BIRTHDAYS 배정(성야절) + main 경로가 물린다.
#   ⑧ 볼륨([ADR-0068] 결정 5 상한) — 대사 100~150줄 · 컷신 4 · 절기 4 · 편지 ≤3 · **spouse 4축**.
#   ⑨ 봉인 법칙([ADR-0068] 결정 6) — 금칙어 31어 스캔 0 + **설화 전용 경계 구조 단언**(불의
#      주인을 지목하지 않는다 · 그 집 안의 사람을 호명하지 않는다 · 「약방」을 쓰지 않는다 ·
#      플레이어 죄목을 겨누지 않는다 · Affinity를 모른다 · 냉기를 메카닉으로 안 쓴다).
#   ⑩ ★**소프트 게이트 ㉠** — 설화의 ♡3 진급은 메인 3인 중 1인 이상 stage≥3일 때만 성사된다.
#      미충족 = 기존 `pending_promotion` 대기(점수 손실 0·비트 0·편지 0), 충족 후 다시 대화하면
#      그 자리에서 성사. ♡1·♡2·♡4는 게이트 밖이고, 로스터엔 스칼렛도 **선등재**돼 있다.
#   ⑪ 휴면 콘텐츠 계약 — confession/divorce/spouse 훅은 있는데 main `ROMANCE_OPEN`엔 아직
#      설화가 없다(개통은 S9b-T6 소관 — 훅이 먼저, 명단이 나중).
#
# 실행: ./run_tests.sh seolhwa_arc   (헤드리스는 반드시 game/에서 · 순차)

const KID := "seolhwa"
const NAME_KO := "설화"
const HOUSE_IDX := 0        # 주민 집 1(RESIDENT_HOUSE_RECTS[0] — 동편 최북단)

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
# ★절기 물음 선택지는 넘기기로 못 지나간다(dialogue.advance의 has_choice 가드).
func _drain(m: Node) -> void:
	_settle(m)
	var guard := 0
	while m.dialogue.is_open() and guard < 300:
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

# ★소프트 게이트 ㉠를 연다/닫는다 — 메인 3인 전원을 그 칸에 얌전히 앉힌다.
func _set_mains(m: Node, stage: int) -> void:
	for mid in m.CHORUS_GATE_MAINS:
		_set_idle(m._resident(String(mid)), stage)

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S9b-T2 설화 풀 온보딩 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_drain(m)                                   # 신규 시작의 옥자 통보 대화
	m.onboarding.step = Onboarding.DONE
	m.clock.day = 3                             # 주 첫날 아님(절기 물음은 ⑥에서 따로 켠다)

	var r: Resident = m._resident(KID)
	_check("①a 레코드가 등록돼 있다", r != null)
	if r == null:
		quit(1)
		return
	var who: Node2D = r.node
	# ★셋업 — 소프트 게이트 ㉠를 **미리 연다**(메인 3인 stage≥3). 게이트 자체는 ⑩이 따로 닫았다
	#   열며 재고, 그전 구간(③~⑦)은 "게이트가 열린 평상시"를 재는 게 맞다.
	_set_mains(m, m.CHORUS_GATE_MAIN_STAGE)

	# ── ① 인물 층 배선 ─────────────────────────────────────────────────────
	print("── ① 인물 층 배선 ──")
	_check("①b 표시명·세이브 키·관계 트랙·선물 채널",
		r.display_name == NAME_KO and who.display_name() == NAME_KO
		and r.save_key == "seolhwa_affinity" and r.affinity != null and r.can_gift)
	_check("①c 곱셈기 없음(조연 = 쉼터 2채널 — ADR-0008 메인 4인 독점)",
		not r.effect_fn.is_valid())
	_check("①d 초상화는 아직 없다(시트·초상 = S9b-T9 아트 패스)", r.portrait_stem == "")
	# 집 배정 = 주민 집 1(index 0). 아침 자리가 그 집 문 바로 아래 칸이어야 동선이 성립한다.
	var house_door: Vector2i = m.RESIDENT_HOUSE_DOORS[HOUSE_IDX]
	_check("①e 스케줄 3단(집 앞 → 광장 → 카페) · 전부 나루 마을",
		r.schedule.size() == 3
		and r.schedule[0]["tile"] == house_door + Vector2i(0, 1)
		and String(r.schedule[0]["region"]) == RegionCatalog.NARU_VILLAGE
		and String(r.schedule[2]["region"]) == RegionCatalog.NARU_VILLAGE)
	_check("①f 낮·저녁 자리가 아침 자리와 다르다(실제로 도는 동선)",
		r.schedule[0]["tile"] != r.schedule[1]["tile"]
		and r.schedule[1]["tile"] != r.schedule[2]["tile"])
	_check("①g 세 자리 어느 것도 다른 주민 자리와 안 겹친다(마주보기 판정 파손 방지)",
		_no_station_clash(m, r))
	_check("①h 집 1은 동편 주거다(강변 2채 = 세레나 예약분을 안 쓴다)", _house_is_east(m, HOUSE_IDX))
	_check("①i 모찌(4)·깨비(6)·켄(9) 집과 다른 집이다(1인 1채)",
		house_door != m.RESIDENT_HOUSE_DOORS[3]
		and house_door != m.RESIDENT_HOUSE_DOORS[5]
		and house_door != m.RESIDENT_HOUSE_DOORS[8])
	# 선호 선물 — 러브/헤이트가 실존 아이템이고 전부 건넬 수 있어야 한다.
	_check("①j 선호 선물 테이블(러브 5 · 헤이트 2 · 전부 실존·건넬 수 있음)",
		GiftPrefs.loves(KID).size() == 5 and GiftPrefs.hates(KID).size() == 2
		and _prefs_valid())
	_check("①k ★김이 오르는 것이 헤이트(온기 자체 — 반전 로맨스의 출발선)",
		GiftPrefs.tier_of(KID, MenuCatalog.HOT_MILK) == GiftPrefs.HATE
		and GiftPrefs.tier_of(KID, MenuCatalog.COLD_WATER) == GiftPrefs.LOVE)

	# ── ② 일상 대사 4단 ────────────────────────────────────────────────────
	print("── ② 일상 대사 4단 ──")
	var l0: PackedStringArray = who.lines(0, true)
	var l1: PackedStringArray = who.lines(1, true)
	var l2: PackedStringArray = who.lines(2, true)
	var l3: PackedStringArray = who.lines(3, true)
	var l4: PackedStringArray = who.lines(4, true)
	var l5: PackedStringArray = who.lines(5, true)
	_check("②a 네 단이 서로 다르다(♡0 ≠ ♡1+ ≠ ♡3+ ≠ ♡5)",
		l0 != l1 and l1 != l3 and l3 != l5 and not l5.is_empty())
	_check("②b 단 안에서는 같은 묶음(♡1=♡2 · ♡3=♡4 — 4단이지 6단이 아니다)",
		l1 == l2 and l3 == l4)
	_check("②c 네 단 모두 5줄 이상(빈 단 없음)",
		l0.size() >= 5 and l1.size() >= 5 and l3.size() >= 5 and l5.size() >= 5)
	_check("②d 오늘 두 번째 대화 = 짧은 한 줄(하트에 따라 온도만 다르다)",
		who.lines(0, false).size() == 1 and who.lines(5, false).size() == 1
		and who.lines(0, false) != who.lines(5, false))

	# ── ③ 관문 발화 ♡1~4 ───────────────────────────────────────────────────
	print("── ③ 관문 발화 ♡1~4 ──")
	var bodies_ok := true
	for t in [1, 2, 3, 4]:
		var b: PackedStringArray = who.heart_gate_lines(t)
		if b.size() < 5 or String(b[0]) == m.HEART_GATE_PLACEHOLDER_LINE:
			bodies_ok = false
	_check("③a 네 칸 전부 캐릭터 본문(placeholder 폴백 0 — 조연 4단 아크)", bodies_ok)
	_check("③b 범위 밖 칸은 빈 배열(방어)",
		who.heart_gate_lines(0).is_empty() and who.heart_gate_lines(5).is_empty())
	_check("③c ♡3이 가장 길다(그날 밤 고백 = 필수 세트피스)",
		who.heart_gate_lines(3).size() > who.heart_gate_lines(1).size()
		and who.heart_gate_lines(3).size() > who.heart_gate_lines(2).size()
		and who.heart_gate_lines(3).size() > who.heart_gate_lines(4).size())

	# ── ④ 컷신 → 대화 합류 ─────────────────────────────────────────────────
	print("── ④ 컷신 → 대화 합류 ──")
	var verbs_ok := true
	var npc_free := true
	for t in [1, 2, 3, 4]:
		var steps: Array = who.heart_gate_cutscene(t)
		var runner := CutsceneRunner.new(steps)
		if steps.is_empty() or not runner.rejected_verbs().is_empty() \
				or runner.step_count() != steps.size():
			verbs_ok = false
		if _has_verb(steps, "npc"):
			npc_free = false
	_check("④a 네 컷신 전부 4동사 안(거절 0 · 유효 스텝 있음)", verbs_ok)
	_check("④b npc 동사 0(세 구역-자리를 도는 인물 — 순간이동 위험을 구조적으로 없앤다)", npc_free)
	# 실제 재생.
	for t in [1, 2, 3, 4]:
		var body: PackedStringArray = who.heart_gate_lines(t)
		m._heart_bits = {}
		_set_heart(r, t - 1)
		r.affinity.last_talk_day = 0
		m._start_resident_dialogue(r)
		_check("④c ♡%d 컷신이 대화보다 먼저 선다(진급은 이미 성사)" % t,
			m.cutscene != null and not m.dialogue.is_open() and r.affinity.hearts() == t)
		_settle(m)
		_check("④d ♡%d 재생이 끝나면 관문 발화가 맨 앞에 선 대화가 열린다" % t,
			m.cutscene == null and m.dialogue.is_open()
			and m.dialogue.line() == String(body[0]))
		_drain(m)
	_check("④e 네 번의 재생 뒤에도 화면·시계 원복(암전 잔류 0)",
		is_equal_approx(m.fade.modulate.a, 0.0) and m.clock.running
		and m._cam.offset.is_equal_approx(Vector2.ZERO) and m.cutscene == null)
	# 재구애(본 비트 잔존) = 조용한 진급(ADR-0022).
	_set_heart(r, 3)
	var regate: PackedStringArray = m._try_heart_promotion(r)
	_check("④f 본 비트는 재지급 없음(발화 0 · 진급은 됨)",
		regate.is_empty() and r.affinity.hearts() == 4)

	# ── ⑤ 여진 편지 ────────────────────────────────────────────────────────
	print("── ⑤ 여진 편지 ──")
	_check("⑤a ♡1은 편지 없음 · ♡2~4는 실존하는 편지를 지목",
		String(who.heart_gate_letter(1)) == ""
		and Mailbox.has_letter(String(who.heart_gate_letter(2)))
		and Mailbox.has_letter(String(who.heart_gate_letter(3)))
		and Mailbox.has_letter(String(who.heart_gate_letter(4))))
	var sender_ok := true
	for t in [2, 3, 4]:
		if Mailbox.sender_of(String(who.heart_gate_letter(t))) != NAME_KO:
			sender_ok = false
	_check("⑤b 세 통 다 발신인이 설화다", sender_ok)
	# 실발송 — 판을 새로 깔고 ♡2 관문을 성사시켜 큐 → 익일 도착을 태운다.
	m.mailbox.outbox = PackedStringArray()
	m.mailbox.inbox = PackedStringArray()
	m.mailbox.read_ledger = {}
	m._heart_bits = {}
	_set_heart(r, 1)
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_drain(m)
	var lid2 := String(who.heart_gate_letter(2))
	_check("⑤c 관문 성사 = 큐에 들어간다(같은 날 도착 0)",
		m.mailbox.pending_count() == 1 and not m.mailbox.has_unread())
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)
	_check("⑤d 다음 날 아침 도착(지목한 그 편지)",
		m.mailbox.inbox.has(lid2) and m.mailbox.unread_count() == 1)
	m._read_next_letter()
	_check("⑤e 열람 = 대화창(발신인이 화자 · 본문 첫 줄) · 여는 순간 기독",
		m.dialogue.is_open() and m.dialogue.speaker() == NAME_KO
		and m.dialogue.line() == Mailbox.lines_of(lid2)[0] and m.mailbox.is_read(lid2))
	_drain(m)

	# ── ⑥ 절기 물음 ────────────────────────────────────────────────────────
	print("── ⑥ 절기 물음 ──")
	_check("⑥a 절기 4개 전부 물음이 있다(각 2~4지 · 반응 짝이 맞는다)", _all_seasons_ok(who))
	_check("⑥b 범위 밖 절기는 빈 dict(방어)",
		who.season_question(-1).is_empty() and who.season_question(4).is_empty())
	var q0: Dictionary = who.season_question(0)
	_set_idle(r, 3)                              # 관문이 안 서는 상태(물음이 밀리지 않게)
	m.clock.day = 15                             # (15-1)%7 == 0 → 주 첫날 · 절기 0(피안절)
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	# ★ 점수 스냅은 **대화가 열린 뒤**다 — 일일 대화 보상은 대화 진입의 몫이라 그 전에 재면
	#   이 단언이 "선택이 아니라 대화 자체"를 재게 된다(t1_arc_test ④c 선례).
	var pts_before: int = r.affinity.points
	var stage_before: int = r.affinity.stage
	while m.dialogue.is_open() and not m.dialogue.has_choice():
		m.dialogue.advance()
	_check("⑥c 주 첫날 첫 대화 = 질문 줄에 선택지가 선다(문항 = 캐릭터 소유 본문)",
		m.dialogue.has_choice() and m.dialogue.line() == String(q0["line"])
		and m.dialogue.choices() == PackedStringArray(q0["options"]))
	m.dialogue.choose(1)
	_check("⑥d 고르면 반응 한 줄로 교체된다",
		m.dialogue.is_open() and m.dialogue.line() == String(PackedStringArray(q0["replies"])[1]))
	_check("⑥e ★0점 계약 — 선택 전후 점수·stage 불변",
		r.affinity.points == pts_before and r.affinity.stage == stage_before)
	_drain(m)
	m.clock.day = 17                             # 같은 주의 다른 날
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_check("⑥f 같은 주엔 다시 안 묻는다(원장 1주 1회)", not _has_question(m, q0))
	_drain(m)

	# ── ⑦ 생일 ─────────────────────────────────────────────────────────────
	print("── ⑦ 생일 ──")
	var bday: PackedStringArray = who.birthday_lines()
	_check("⑦a 생일 훅 본문(placeholder 폴백 아님)",
		bday.size() >= 3 and String(bday[0]) != m.BIRTHDAY_PLACEHOLDER_LINE)
	var b: Array = Resident.birthday_of(KID)
	_check("⑦b 생일 배정이 살아 있다(달력 단일 출처 · 성야절)", b.size() == 2 and int(b[0]) == 3)
	var bday_day := _find_birthday_day(KID)
	_check("⑦c 그 날짜가 실제로 이 사람 생일로 판정된다",
		bday_day > 0 and r.is_birthday_on(bday_day))
	_set_idle(r, 3)                              # 관문이 안 서는 상태(생일이 대화의 사건이 되게)
	m.clock.day = bday_day
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_check("⑦d 생일 당일 대화는 생일 발화로 열린다(평소 묶음 앞)",
		m.dialogue.is_open() and m.dialogue.line() == String(bday[0]))
	_drain(m)

	# ── ⑧ 볼륨([ADR-0068] 결정 5 상한) ─────────────────────────────────────
	print("── ⑧ 볼륨 ──")
	var total := _total_lines(who)
	print("    본문 줄 수(선택지 제외) = %d" % total)
	_check("⑧a 대사 볼륨이 상한 안(100~150줄 — 결정 5)", total >= 100 and total <= 150)
	_check("⑧b 관문 컷신 4개(♡1~4 각 1)", _cutscene_count(who) == 4)
	_check("⑧c 절기 물음 4개(절기당 1)", who.SEASON_QUESTIONS.size() == 4)
	_check("⑧d 여진 편지 2~3통", who.GATE_LETTERS.size() >= 2 and who.GATE_LETTERS.size() <= 3)
	_check("⑧e ★spouse_lines 4축(메인 8축의 절반 — day%4)",
		who.SPOUSE_AXES.size() == 4
		and who.spouse_lines(0) == PackedStringArray(who.SPOUSE_AXES[0])
		and who.spouse_lines(5) == PackedStringArray(who.SPOUSE_AXES[1])
		and who.spouse_lines(3, false).size() == 1)
	_check("⑧f 오늘 두 번째 한 줄이 세 종류(평소 · 연인 · 배우자)",
		String(who.LINE_AGAIN) != String(who.LINE_AGAIN_LOVER)
		and String(who.LINE_AGAIN_LOVER) != String(who.LINE_AGAIN_SPOUSE))

	# ── ⑨ 봉인 법칙([ADR-0068] 결정 6) ─────────────────────────────────────
	print("── ⑨ 봉인 법칙 ──")
	# 기존 아크 스위트(미호·멜·바나·T1 2인·깨비·켄)의 금칙어를 **합집합으로 상속**하고, 결정 6의
	# 중심 진실 4금지(옥자 희생 / 기억 봉인 / 마녀=연인 / 플레이어 죄목)를 어휘로 못 박는다.
	# 검열이 아니라 회귀 가드다 — 나중 손질이 평결 문장을 흘려 넣으면 여기서 걸린다.
	var offender := _scan_forbidden(who, FORBIDDEN)
	_check("⑨a 금칙어 %d어 스캔 0(본문 + 편지 전량)" % FORBIDDEN.size(), offender == "")
	if offender != "":
		print("      ↳ 걸린 줄: " + offender)
	var g3 := _joined(who.GATE_HEART_3)
	_check("⑨b ♡3은 **자기 파편**이다(얼음 벽을 세운 것과 무너진 것까지)",
		g3.contains("언 벽을 세웠") and g3.contains("세 번 무너졌"))
	_check("⑨c ★불의 주인을 지목하지 않는다(코러스 = 자기 파편만 · 깨비 ♡3의 대칭)",
		g3.contains("누구 불인지는 나도 몰라")
		and not g3.contains("미호") and not g3.contains("여우"))
	_check("⑨d ★그 밤의 인물을 호명하지 않는다(옥자·약방 0 · 열을 다스리던 이는 끝내 익명)",
		not g3.contains("옥자") and not g3.contains("약방") and g3.contains("앓는 사람"))
	var g2 := _joined(who.GATE_HEART_2)
	_check("⑨e ♡2도 고유명사 「약방」을 안 쓴다(“약 짓는 집”까지)",
		not g2.contains("약방") and g2.contains("약 짓는 집") and not g2.contains("옥자"))
	var g4 := _joined(who.GATE_HEART_4)
	_check("⑨f ♡4는 **자기 생전 죄까지만**(체념 — 얼린 죄가 아니라 얼리는 걸 그냥 둔 죄)",
		g4.contains("체념") and g4.contains("포기"))
	_check("⑨g ♡4가 플레이어의 죄를 겨누지 않는다(메인 3인 조각의 독점 영역)",
		not g4.contains("네 죄") and not g4.contains("네가 지은"))
	_check("⑨h 본문은 Affinity를 모른다(0점 계약의 구조적 근거)",
		not _src().contains("Affinity") and not _src().contains("add_points"))
	_check("⑨i 냉기를 메카닉으로 쓰지 않는다(깨비의 불과 같은 가드레일 — effect_fn 0 · 곱셈기 어휘 0)",
		not r.effect_fn.is_valid() and not _src().contains("effect_fn"))

	# ── ⑩ ★소프트 게이트 ㉠ ────────────────────────────────────────────────
	print("── ⑩ 소프트 게이트 ㉠ ──")
	_check("⑩a 로스터 상수가 설화를 담고 점주(T2)는 안 담는다(★scarlet 선등재)",
		m.CHORUS_GATE_ROSTER.has(KID) and m.CHORUS_GATE_ROSTER.has("scarlet")
		and m.CHORUS_GATE_ROSTER.has("mochi") and m.CHORUS_GATE_ROSTER.has("neo")
		and m.CHORUS_GATE_ROSTER.has("kkaebi") and m.CHORUS_GATE_ROSTER.has("ken")
		and not m.CHORUS_GATE_ROSTER.has("boatman")
		and not m.CHORUS_GATE_ROSTER.has("ongi")
		and not m.CHORUS_GATE_ROSTER.has("pulmu")
		and not m.CHORUS_GATE_ROSTER.has("mugol"))
	_set_mains(m, 0)                             # 대화재 미접촉 상태로 되돌린다
	m._heart_bits = {}
	# ♡1·♡2는 게이트 밖 — 미접촉이어도 그냥 오른다("평평 ≠ 막힘").
	_set_heart(r, 0)
	m._try_heart_promotion(r)
	_check("⑩b ♡1은 게이트 밖(미접촉이어도 성사)", r.affinity.hearts() == 1)
	_set_heart(r, 1)
	m._try_heart_promotion(r)
	_check("⑩c ♡2도 게이트 밖", r.affinity.hearts() == 2)
	# ♡3 — 미충족이면 대기(점수 손실 0 · 비트 0 · 편지 0).
	m.mailbox.outbox = PackedStringArray()
	var gate_lines: PackedStringArray = m._try_heart_promotion(r)
	_check("⑩d ★미접촉이면 ♡3 관문은 **대기**(발화 0 · 진급 0 · 비트 0 · 편지 0)",
		gate_lines.is_empty() and r.affinity.hearts() == 2
		and not m._heart_bit_seen(KID, 3) and m.mailbox.pending_count() == 0)
	_check("⑩e 점수는 만충 그대로 남는다(손실 0 · 대기 배지의 근거)",
		r.affinity.pending_promotion() and r.affinity.points == Affinity.MAX_POINTS)
	# 대화 진입 경로로도 같은 결과여야 한다(판정부 한 곳 = 호출부 전부).
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_check("⑩f 대화로 들어와도 컷신·관문 발화가 안 선다(평소 대사만)",
		m.cutscene == null and m.dialogue.is_open() and r.affinity.hearts() == 2)
	_drain(m)
	# 메인 1인만 ♡3에 올려도 열린다(AND 아님 — OR 1인).
	_set_idle(m._resident("bana"), m.CHORUS_GATE_MAIN_STAGE)
	_set_heart(r, 2)
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_settle(m)
	_check("⑩g ★메인 1인만 ♡3이어도 열린다(OR — 조연이 메인 진행의 인질이 되지 않는다)",
		r.affinity.hearts() == 3 and m._heart_bit_seen(KID, 3)
		and m.dialogue.line() == String(who.heart_gate_lines(3)[0]))
	_drain(m)
	# ♡4는 게이트 밖 — 미접촉으로 되돌려도 오른다(그날 밤이 아니라 생전 죄라서).
	_set_mains(m, 0)
	_set_heart(r, 3)
	m._try_heart_promotion(r)
	_check("⑩h ♡4는 게이트 밖(생전 죄 고백 — 그날 밤 소프트 게이트의 대상이 아니다)",
		r.affinity.hearts() == 4)

	# ── ⑪ 휴면 콘텐츠 계약 ─────────────────────────────────────────────────
	print("── ⑪ 휴면 콘텐츠 ──")
	_check("⑪a 연애·배우자·이혼 훅이 전부 있다(본문 선행)",
		who.has_method("confession_lines") and who.has_method("divorce_lines")
		and who.has_method("spouse_lines")
		and who.confession_lines(true).size() >= 4
		and who.confession_lines(false).size() >= 4
		and who.divorce_lines().size() >= 3)
	_check("⑪b 수락·거절 본문이 서로 다르다",
		who.confession_lines(true) != who.confession_lines(false))
	_check("⑪c ★main ROMANCE_OPEN엔 아직 없다(개통은 S9b-T6 소관 — 이 태스크는 명단을 안 건드린다)",
		not m.ROMANCE_OPEN.has(KID))

	m.free()
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ seolhwa_arc_test 전체 통과 ══")
	else:
		print("══ seolhwa_arc_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)

# ── 금칙어(31어) ────────────────────────────────────────────────────────────
# S9b-T1이 확정한 조연 공통 배열을 **그대로 상속**한다(기존 아크 스위트 4종의 합집합 23어 +
# [ADR-0068] 결정 6이 명문화한 중심 진실 4금지의 어휘 8어). 조연 파일마다 이 배열을 복사한다 —
# 배열을 공유 모듈로 빼지 않는 이유는 캐릭터별 가드가 각자의 회귀 스위트 안에 자족해야 하기
# 때문이다(한 파일만 열어도 그 캐릭터가 무엇을 말하면 안 되는지 전부 읽힌다).
const FORBIDDEN := [
	# 플레이어 죄목의 평결(공통 18어)
	"네 죄는", "너의 죄는", "네가 지은 죄", "네 죄목", "그러니까 네가",
	"너 때문에 옥자", "네가 옥자를", "너는 외면했", "네가 외면한",
	"너는 잊었", "네가 잊은 죄", "네가 버린 죄", "그게 네 죄", "네가 태워 없앤",
	"네가 방치했", "네가 버려둔", "네가 지키지 않아", "네가 없었기 때문",
	# 그날 밤의 판독 결론(5어)
	"옥자의 눈물", "강림의 명부", "차사 명부", "그날 밤에 일어난", "화재의 원인은",
	# ★중심 진실 4금지([ADR-0068] 결정 6 — 옥자 희생 / 기억 봉인 / 마녀=연인 / 플레이어 죄목)
	"옥자가 널 살리", "옥자가 너를 살리", "자기를 바쳐", "종신계약을 대신",
	"기억을 봉인", "봉인된 기억", "옥자는 마녀가 됐", "옥자의 연인",
]

# ── 헬퍼 ────────────────────────────────────────────────────────────────────
func _has_verb(steps: Array, verb: String) -> bool:
	for s in steps:
		if typeof(s) == TYPE_DICTIONARY and String((s as Dictionary).get("verb", "")) == verb:
			return true
	return false

# 설화의 세 스테이션이 다른 주민 누구의 스케줄 칸과도 안 겹치는가.
func _no_station_clash(m: Node, mine: Resident) -> bool:
	var mine_tiles := []
	for e in mine.schedule:
		mine_tiles.append(e["tile"])
	for other in m._residents:
		if other.id == mine.id:
			continue
		for e in other.schedule:
			if mine_tiles.has(e["tile"]):
				return false
	return true

# 그 집이 동편 주거(강변 예약분이 아님)인가 — 강변 판정은 main의 RIVERSIDE_ZONE_Y가 소유한다.
func _house_is_east(m: Node, idx: int) -> bool:
	var rect: Rect2i = m.RESIDENT_HOUSE_RECTS[idx]
	return rect.position.y < m.RIVERSIDE_ZONE_Y

# 러브·헤이트 전량이 실존 아이템이고 건넬 수 있는가(선물 채널이 실제로 성립하는가).
func _prefs_valid() -> bool:
	for list in [GiftPrefs.loves(KID), GiftPrefs.hates(KID)]:
		for id in list:
			if not ItemCatalog.has_item(String(id)) or not GiftPrefs.giftable(String(id)):
				return false
	return true

# 지금 열린 대화에 그 절기 물음이 실려 있는가.
func _has_question(m: Node, q: Dictionary) -> bool:
	if q.is_empty() or not m.dialogue.is_open():
		return false
	var want := String(q.get("line", ""))
	var guard := 0
	while m.dialogue.is_open() and guard < 200:
		if m.dialogue.line() == want:
			return true
		if m.dialogue.has_choice():
			return false      # 다른 물음의 선택지 — 넘기기가 막혀 있으니 여기서 멈춘다
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

# 캐릭터 본문 줄의 총합(볼륨 실측 — [ADR-0068] 결정 5의 셈법).
# 절기 물음은 질문 줄 + 반응만 센다(선택지 항목은 *플레이어의 말*이라 캐릭터 볼륨이 아니다).
# LINE_AGAIN 3종은 프레임워크 슬롯 채움 한 줄짜리라 여기 안 넣는다(⑧f가 따로 존재를 잰다).
func _total_lines(who: Node2D) -> int:
	var n := 0
	for pack in [who.LINES_INTRO, who.LINES_WARMING, who.LINES_CLOSE, who.LINES_LOVER,
			who.GATE_HEART_1, who.GATE_HEART_2, who.GATE_HEART_3, who.GATE_HEART_4,
			who.CONFESSION_ACCEPT, who.CONFESSION_REJECT, who.DIVORCE_FAREWELL, who.BIRTHDAY]:
		n += (pack as Array).size()
	for ax in who.SPOUSE_AXES:
		n += (ax as Array).size()
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

# 설화 발신 편지의 모든 줄(금칙어 스캔에 합류 — 편지도 캐릭터의 말이다).
func _letter_lines() -> Array:
	var out: Array = []
	for id in Mailbox.LETTERS:
		if String(Mailbox.LETTERS[id].get("from", "")) == NAME_KO:
			out.append_array(Mailbox.LETTERS[id].get("lines", []) as Array)
	return out

# 전 본문에서 금칙어를 찾는다(걸린 줄을 돌려준다 — 없으면 "").
func _scan_forbidden(who: Node2D, words: Array) -> String:
	var all: Array = []
	for pack in [who.LINES_INTRO, who.LINES_WARMING, who.LINES_CLOSE, who.LINES_LOVER,
			who.GATE_HEART_1, who.GATE_HEART_2, who.GATE_HEART_3, who.GATE_HEART_4,
			who.CONFESSION_ACCEPT, who.CONFESSION_REJECT, who.DIVORCE_FAREWELL, who.BIRTHDAY]:
		all.append_array(pack as Array)
	for ax in who.SPOUSE_AXES:
		all.append_array(ax as Array)
	for q in who.SEASON_QUESTIONS:
		all.append(q["line"])
		all.append_array(q["replies"] as Array)
	all.append_array(_letter_lines())
	for ln in all:
		for w in words:
			if String(ln).contains(String(w)):
				return String(ln)
	return ""

# 캐릭터 파일의 **주석을 걷어낸 코드 본문**(주석이 검사 문자열을 우연히 품는 오탐 방지).
func _src() -> String:
	var f := FileAccess.open("res://%s.gd" % KID, FileAccess.READ)
	if f == null:
		return ""
	var out := PackedStringArray()
	for ln in f.get_as_text().split("\n"):
		if not String(ln).strip_edges().begins_with("#"):
			out.append(String(ln))
	return "\n".join(out)
