extends SceneTree
# ★[S9b-T3 / ADR-0068 결정 3·5·6·12] 루카 풀 온보딩 — 헤드리스 검증.
#
# 규약은 kkaebi_arc_test·ken_arc_test·seolhwa_arc_test·scarlet_arc_test를 그대로 상속한다
# (금칙어 31어 가드·볼륨 측정·훅 존재·관문 드레인·절기 물음·생일·편지). 루카 고유분은 ⑨의
# 구조 단언들이고, 그중 ⑨e가 이 인물의 **핵심 경계**다.
#
# 무엇을 보증하나:
#   ① 인물 층 배선 — 레코드 1건이 실제로 등록되고(id·표시명·세이브 키·선물 채널·집/스케줄),
#      세 스테이션이 서로 다르며 다른 주민 자리와 겹치지 않는다(칸 충돌 = 마주보기 판정 파손).
#   ② 일상 대사 **4단** 분기(♡0/♡1+/♡3+/♡5+) — 단 경계가 관문 경계와 맞고, 단 안에서는 같은
#      묶음이며, 오늘 두 번째 대화는 하트에 따라 온도만 다른 한 줄이다.
#   ③ 관문 발화 **♡1~4 네 칸 전부** 캐릭터 본문이다(placeholder 폴백 0 — 조연 4단 아크).
#   ④ 컷신 — 4동사 안이고(거절 0) 칸마다 하나이며 **npc 동사 0**(세 구역-자리를 도는 인물이라
#      순간이동 위험을 구조적으로 없앤다 — 깨비·스칼렛 선례), 재생이 끝나면 관문 발화가 맨 앞에
#      선 대화가 열린다.
#   ⑤ 여진 편지 — ♡2·♡3·♡4가 각기 실존하는 편지를 지목하고(♡1은 없음) 발신인이 루카이며,
#      관문 성사가 큐에 넣고 다음 날 아침 도착한다.
#   ⑥ 절기 물음 4개 — 짝이 맞고, 주 첫날 첫 대화에 서며, **0점 계약**(선택 전후 점수·stage 불변).
#   ⑦ 생일 — 훅 본문 + Resident.BIRTHDAYS 배정(유화절 15일 = 보름) + main 경로가 물린다.
#   ⑧ 볼륨([ADR-0068] 결정 5 상한) — 대사 100~150줄 · 컷신 4 · 절기 4 · 편지 ≤3 · **spouse 4축**.
#   ⑨ 봉인 법칙([ADR-0068] 결정 6) — 금칙어 31어 스캔 0 + 조연 경계 구조 단언. 루카는 수렴 지도의
#      **맨 첫 칸(뿌리)**이라 중심 진실과 지척이므로 경계가 로스터 중 가장 촘촘하다:
#      ㉠ 자기가 문 사람을 **알아보지 못한다**("누구였는지는 나도 몰라" · "너였구나" 0줄)
#      ㉡ 약을 달이던 사람은 끝까지 **"그 집 사람"**(옥자·약방·약사 0)
#      ㉢ ★**담 안에서 벌어진 일을 대신 말하지 않는다** — [narrative-bible §2] 일관성 규칙
#         「루카 = 밖 위협 · 멜 = 안 습격」의 기계 가드이자 설화·켄 ♡3(약방 *안*)과의 경계선
#      ㉣ 불을 남에게 돌리지 않는다 ㉤ 부채감이 **설명되지 않은 채** 남는다(점을 안 잇는다)
#      ㉥ ♡4는 자기 생전 죄까지만 ㉦ Affinity를 모른다 ㉧ 야성을 메카닉으로 안 쓴다.
#   ⑩ ★**소프트 게이트 ㉠**(결정 6) — 메인 3인 중 1인 이상 stage≥3이면 조연 ♡3이 성사된다.
#      ⚠️ 로스터 상수(`CHORUS_GATE_ROSTER`)에 "luca"를 **등재하는 것은 병렬 짝 워커의 단독
#      소유**다(결합 충돌 방지 — 로스터의 주인은 그 상수 한 곳뿐. T2 스칼렛 선례 동형). 그래서
#      이 스위트는 게이트가 **걸린 상태·안 걸린 상태 양쪽에서 똑같이 참인 것만** 잰다: ㉠ 메인
#      접촉 상태에서 ♡3이 성사된다 ㉡ ♡1·♡2는 언제나 게이트 밖. 등재 후 "미접촉이면 대기"는
#      짝 워커(미르) 스위트가 잰다.
#   ⑪ 휴면 콘텐츠 계약 — confession/divorce/spouse 훅은 있는데 main `ROMANCE_OPEN`엔 아직
#      루카가 없다(개통은 S9b-T6 소관 — 훅이 먼저, 명단이 나중).
#
# 실행: ./run_tests.sh luca_arc   (헤드리스는 반드시 game/에서 · 순차)

const KID := "luca"
const NAME_KO := "루카"
const HOUSE_IDX := 2        # 주민 집 3(RESIDENT_HOUSE_RECTS[2] — 동편 하단 우 = 마을과 산의 경계)

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

# ★소프트 게이트 ㉠를 연다 — 메인 3인 전원을 그 칸에 얌전히 앉힌다.
# 이 스위트는 **셋업부터 열어 두고 시작한다**: 로스터 등재(짝 워커 소유)가 결합된 뒤에도
# 무수정으로 통과해야 하기 때문이다(선주입 = 결합 안전장치. T2 스칼렛 선례).
func _set_mains(m: Node, stage: int) -> void:
	for mid in m.CHORUS_GATE_MAINS:
		_set_idle(m._resident(String(mid)), stage)

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S9b-T3 루카 풀 온보딩 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_drain(m)                                   # 신규 시작의 옥자 통보 대화
	m.onboarding.step = Onboarding.DONE
	m.clock.day = 3                             # 주 첫날 아님(절기 물음은 ⑥에서 따로 켠다)
	_set_mains(m, m.CHORUS_GATE_MAIN_STAGE)     # ★소프트 게이트 ㉠ 선주입(결합 후에도 무수정 통과)

	var r: Resident = m._resident(KID)
	_check("①a 레코드가 등록돼 있다", r != null)
	if r == null:
		quit(1)
		return
	var who: Node2D = r.node

	# ── ① 인물 층 배선 ─────────────────────────────────────────────────────
	print("── ① 인물 층 배선 ──")
	_check("①b 표시명·세이브 키·관계 트랙·선물 채널",
		r.display_name == NAME_KO and who.display_name() == NAME_KO
		and r.save_key == "luca_affinity" and r.affinity != null and r.can_gift)
	_check("①c 곱셈기 없음(조연 = 쉼터 2채널 — ADR-0008 메인 4인 독점)",
		not r.effect_fn.is_valid())
	_check("①d 초상화는 아직 없다(시트·초상 = S9b-T9 아트 패스)", r.portrait_stem == "")
	# 집 배정 = 주민 집 3(index 2). 아침 자리가 그 집 문 바로 아래 칸이어야 동선이 성립한다.
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
	_check("①h 낮 자리가 광장 안이다(마을 밖으로 빠지는 남동 어귀 모서리)",
		m.NARU_PLAZA_RECT.has_point(r.schedule[1]["tile"]))
	_check("①i 집 3은 동편 주거다(강변 2채 = 세레나 예약분을 안 쓴다)", _house_is_east(m, HOUSE_IDX))
	_check("①j 설화·스칼렛·모찌·깨비·켄과 다른 집이다(1인 1채)",
		house_door != m.RESIDENT_HOUSE_DOORS[0]
		and house_door != m.RESIDENT_HOUSE_DOORS[1]
		and house_door != m.RESIDENT_HOUSE_DOORS[3]
		and house_door != m.RESIDENT_HOUSE_DOORS[5]
		and house_door != m.RESIDENT_HOUSE_DOORS[8])
	# 선호 선물 — 러브/헤이트가 실존 아이템이고 전부 건넬 수 있어야 한다.
	_check("①k 선호 선물 테이블(러브 5 · 헤이트 2 · 전부 실존·건넬 수 있음)",
		GiftPrefs.loves(KID).size() == 5 and GiftPrefs.hates(KID).size() == 2
		and _prefs_valid())
	_check("①l ★날것 헤이트(먹빛장어 — 스스로 금한 입질. 유니버설을 덮는다)",
		GiftPrefs.tier_of(KID, FishCatalog.MEOKBIT_JANGEO) == GiftPrefs.HATE
		and GiftPrefs.universal_tier(FishCatalog.MEOKBIT_JANGEO) != GiftPrefs.HATE)
	_check("①m ★미혹난초가 미호·켄에겐 러브인데 루카에겐 헤이트다(정신을 흐리는 것 = 그에겐 독)",
		GiftPrefs.tier_of(KID, ItemCatalog.MIHOK_NANCHO) == GiftPrefs.HATE
		and GiftPrefs.tier_of("miho", ItemCatalog.MIHOK_NANCHO) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("ken", ItemCatalog.MIHOK_NANCHO) == GiftPrefs.LOVE)
	_check("①n 염주석은 유니버설 보석(라이크)에서 러브로 올라간다(쥐고 세는 돌)",
		GiftPrefs.tier_of(KID, ItemCatalog.GEM_YEOMJUSEOK) == GiftPrefs.LOVE
		and GiftPrefs.universal_tier(ItemCatalog.GEM_YEOMJUSEOK) == GiftPrefs.LIKE)
	_check("①o ★넋 데운 우유가 설화의 헤이트이자 루카의 러브다(같은 잔이 정반대 의미)",
		GiftPrefs.tier_of(KID, MenuCatalog.HOT_MILK) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("seolhwa", MenuCatalog.HOT_MILK) == GiftPrefs.HATE)

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
	_check("④c ♡3이 가장 긴 완전 암전이다(세트피스 — 등급 2의 표현력은 암전 길이뿐)",
		_max_fade(who.heart_gate_cutscene(3)) >= 1.0
		and _max_fade(who.heart_gate_cutscene(1)) <= 0.0)
	# 실제 재생(소프트 게이트는 셋업에서 이미 열어 뒀다).
	for t in [1, 2, 3, 4]:
		var body: PackedStringArray = who.heart_gate_lines(t)
		m._heart_bits = {}
		_set_heart(r, t - 1)
		r.affinity.last_talk_day = 0
		m._start_resident_dialogue(r)
		_check("④d ♡%d 컷신이 대화보다 먼저 선다(진급은 이미 성사)" % t,
			m.cutscene != null and not m.dialogue.is_open() and r.affinity.hearts() == t)
		_settle(m)
		_check("④e ♡%d 재생이 끝나면 관문 발화가 맨 앞에 선 대화가 열린다" % t,
			m.cutscene == null and m.dialogue.is_open()
			and m.dialogue.line() == String(body[0]))
		_drain(m)
	_check("④f 네 번의 재생 뒤에도 화면·시계 원복(암전 잔류 0)",
		is_equal_approx(m.fade.modulate.a, 0.0) and m.clock.running
		and m._cam.offset.is_equal_approx(Vector2.ZERO) and m.cutscene == null)
	# 재구애(본 비트 잔존) = 조용한 진급(ADR-0022).
	_set_heart(r, 3)
	var regate: PackedStringArray = m._try_heart_promotion(r)
	_check("④g 본 비트는 재지급 없음(발화 0 · 진급은 됨)",
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
	_check("⑤b 세 통 다 발신인이 루카다", sender_ok)
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
	_check("⑦b 생일 배정이 살아 있다(유화절 15일 = 절기 한복판 = 보름)",
		b.size() == 2 and int(b[0]) == 1 and int(b[1]) == 15)
	var bday_day := _find_birthday_day(KID)
	_check("⑦c 그 날짜가 실제로 이 사람 생일로 판정된다",
		bday_day > 0 and r.is_birthday_on(bday_day))
	_check("⑦d 그 날에 생일인 사람이 루카 하나다(달력 무충돌)",
		Resident.birthday_on_day(bday_day) == KID)
	_set_idle(r, 3)                              # 관문이 안 서는 상태(생일이 대화의 사건이 되게)
	m.clock.day = bday_day
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_check("⑦e 생일 당일 대화는 생일 발화로 열린다(평소 묶음 앞)",
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
	# 기존 아크 스위트(미호·멜·바나·T1 2인·깨비·켄·설화·스칼렛)의 금칙어 **31어를 그대로
	# 상속**한다. 검열이 아니라 회귀 가드다 — 나중 손질이 평결 문장을 흘려 넣으면 여기서 걸린다.
	var offender := _scan_forbidden(who, FORBIDDEN)
	_check("⑨a 금칙어 %d어 스캔 0(본문 + 편지 전량)" % FORBIDDEN.size(), offender == "")
	if offender != "":
		print("      ↳ 걸린 줄: " + offender)
	var g3 := _joined(who.GATE_HEART_3)
	_check("⑨b ♡3은 **자기 파편**이다(자기 이빨이 옮긴 것 + 자기 발로 간 담 밖까지)",
		g3.contains("내가 물었어") and g3.contains("그 집 밖에 갔어"))
	_check("⑨c ★자기가 문 사람을 알아보지 못한다(\"너였구나\"는 영원히 0줄 — 봉인의 법칙)",
		g3.contains("누구였는지는 나도 몰라") and not g3.contains("너였"))
	_check("⑨d ★약을 달이던 사람은 끝까지 \"그 집 사람\"이다(중심 진실 4금지 근처에도 안 간다)",
		g3.contains("그 집 사람") and not g3.contains("옥자")
		and not g3.contains("약방") and not g3.contains("약사"))
	_check("⑨e ★담 안에서 벌어진 일을 대신 말하지 않는다(일관성 규칙 「루카=밖·멜=안」)",
		g3.contains("나는 밖에 있었어") and not g3.contains("멜")
		and not g3.contains("설화") and not g3.contains("켄"))
	_check("⑨f 불을 남에게 돌리지 않는다(자기 몫까지만 — 증폭자·불씨의 조각은 그들 것)",
		g3.contains("내가 낸 불이 아니야") and not g3.contains("미호")
		and not g3.contains("여우") and not g3.contains("도깨비"))
	_check("⑨g ★부채감이 설명되지 않은 채 남는다(점을 잇는 건 플레이어 몫)",
		g3.contains("이유는 나도 설명 못 해") and not g3.contains("그래서 네가"))
	var g4 := _joined(who.GATE_HEART_4)
	_check("⑨h ♡4는 **자기 생전 죄까지만**(못 다스린 충동이 곁을 부순 죄)",
		g4.contains("곁에 있던") and g4.contains("내 손으로 부쉈어"))
	_check("⑨i ♡4가 플레이어의 죄를 겨누지 않는다(메인 3인 조각의 독점 영역)",
		not g4.contains("네 죄") and not g4.contains("네가 지은"))
	_check("⑨j 본문은 Affinity를 모른다(0점 계약의 구조적 근거)",
		not _src().contains("Affinity") and not _src().contains("add_points"))
	_check("⑨k 야성·변신을 메카닉으로 쓰지 않는다(백스토리 한정 — effect_fn 0 · 곱셈기 어휘 0)",
		not r.effect_fn.is_valid() and not _src().contains("effect_fn"))

	# ── ⑩ ★소프트 게이트 ㉠(결합 양쪽에서 참인 것만) ───────────────────────
	print("── ⑩ 소프트 게이트 ㉠ ──")
	_check("⑩a ♡1·♡2는 언제나 게이트 밖(칸 자체가 대상이 아니다 — \"평평 ≠ 막힘\")",
		m._chorus_gate_ok(KID, 1) and m._chorus_gate_ok(KID, 2))
	_set_mains(m, m.CHORUS_GATE_MAIN_STAGE)
	_check("⑩b 메인 접촉(1인 이상 ♡3) 상태면 ♡3 판정이 통과다",
		m._chorus_gate_ok(KID, m.CHORUS_GATE_HEART))
	m._heart_bits = {}
	_set_heart(r, 2)
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_settle(m)
	_check("⑩c ★그 상태에서 ♡3 그날 밤 고백이 실제로 열린다(비트 기록 포함)",
		r.affinity.hearts() == 3 and m._heart_bit_seen(KID, 3)
		and m.dialogue.line() == String(who.heart_gate_lines(3)[0]))
	_drain(m)
	# 메인 1인만 ♡3이어도 열린다(AND 아님 — OR 1인).
	_set_mains(m, 0)
	_set_idle(m._resident("bana"), m.CHORUS_GATE_MAIN_STAGE)
	_check("⑩d 메인 1인만 ♡3이어도 판정이 통과다(OR — 조연이 메인 진행의 인질이 되지 않는다)",
		m._chorus_gate_ok(KID, m.CHORUS_GATE_HEART))

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
		print("══ luca_arc_test 전체 통과 ══")
	else:
		print("══ luca_arc_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)

# ── 금칙어(31어) ────────────────────────────────────────────────────────────
# kkaebi_arc_test·ken_arc_test·seolhwa_arc_test·scarlet_arc_test와 **같은 배열**이다
# (조연 파일마다 상속하는 그 목록).
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

# 그 컷신이 도달하는 최대 암전 농도(0 = 암전 없음).
func _max_fade(steps: Array) -> float:
	var top := 0.0
	for s in steps:
		if typeof(s) == TYPE_DICTIONARY and String((s as Dictionary).get("verb", "")) == "fade":
			top = maxf(top, float((s as Dictionary).get("to", 0.0)))
	return top

# 루카의 세 스테이션이 다른 주민 누구의 스케줄 칸과도 안 겹치는가.
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

# 루카 발신 편지의 모든 줄(금칙어 스캔에 합류 — 편지도 캐릭터의 말이다).
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
