extends SceneTree
# ★[S9b-T1 / ADR-0068 결정 3·5·6·12] 켄 풀 온보딩(인물 층 + 서사 층) — 헤드리스 검증.
#
# t1_arc_test(S9-T9 · 조연 선례)와 bana_arc_test(S9-T6 · 훅 일습 선례)를 합친 판이다. 조연은
# 메인과 두 군데가 다르다: ㉠ **deed 문턱이 없다**(쉼터 2채널 — 관문이 점수만으로 열린다)
# ㉡ **볼륨 상한이 절반**(대사 100~150줄 · 편지 2~3통 · spouse 4축 — 결정 5).
#
# 무엇을 보증하나:
#   ① 온보딩(인물 층) — 레코드·집 배정(주민 집 9)·스케줄 3자리·선물·생일·곱셈기 0.
#   ② 관문 ♡1~4 — 캐릭터 본문이 나오고(placeholder 폴백 아님) 컷신이 4동사 안에서 재생된 뒤
#      대화가 합류한다(발화가 컷신에 삼켜지지 않는다) · npc 스텝은 **암전 뒤에서만**.
#   ③ 재구애(본 비트 잔존) = 조용한 진급 — 발화 0 · 컷신 0([ADR-0022]).
#   ④ 일상 대사 **4단** 분기(♡0/♡1+/♡3+/♡5+) + 오늘 두 번째 대화의 짧은 한 줄 + 배우자 **4축**.
#   ⑤ 절기 물음 — 주 첫날 첫 대화에 1회 · 같은 주 재발동 없음 · **0점 계약** · 관문보다 뒤.
#   ⑥ 편지 — 관문 성사로 큐에 들어가고 **다음 날 아침** 도착 · 중복 발송 없음 · 3통 · ♡2엔 없음 ·
#      메인 3인분과 id 충돌 없음.
#   ⑦ 휴면 콘텐츠 — confession/divorce/spouse 본문이 **이미 있고**(T6이 명단 한 줄만 고치면 개통),
#      지금은 main의 ROMANCE_OPEN 밖이라 고백 **제안**이 안 선다.
#   ⑧ 볼륨 상한(결정 5) — 대사 100~150줄 · 관문 컷신 4개 · 편지 3통 · 절기 물음 4개 · spouse 4축.
#   ⑨ 봉인 법칙 가드(결정 6) — 금칙어 31어 0 · ♡3이 **두 개의 공백을 스스로 선언** · 켄 본문에
#      "옥자" 0회(조연은 이승의 약방 주인과 지금의 카페 사장을 자기 입으로 잇지 않는다).
#
# ★ ♡3 드레인 셋업에 **메인 1인(미호) stage≥3**을 미리 세운다 — [ADR-0068] 결정 6의 소프트
#   게이트 ㉠("조연 ♡3 고백은 메인 3인 중 1인 이상 stage≥3")이 결합 후 켜지기 때문이다. 게이트가
#   없는 상태에서도 무해하고(단순 선세팅), 켜진 뒤에도 이 스위트가 그대로 통과한다.
#
# 실행: ./run_tests.sh ken_arc   (헤드리스는 반드시 game/에서 · 순차)

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
#  주 첫날 대화에서 루프가 갇힌다(miho/mel/bana/t1 아크 테스트와 같은 처방).
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

# 그 칸에 **얌전히** 앉힌다 — 점수가 딱 그 칸까지라 진급 대기가 안 선다(사건 없는 대화).
func _set_idle(r: Resident, stage: int) -> void:
	r.affinity.stage = stage
	r.affinity.points = stage * Affinity.POINTS_PER_HEART

# ★[ADR-0068 결정 6] 소프트 게이트 ㉠ 충족 — 메인 3인 중 1인이 ♡3 이상(대화재를 이미 접했다).
# 게이트 자체의 단언(미충족 시 대기)은 게이트를 소유한 태스크의 몫이고, 여기서는 **전제를 세우는
# 것**만 한다(게이트가 없는 상태에서도 무해하다 — 미호 하트를 올려 두는 것뿐이다).
func _satisfy_soft_gate(m: Node) -> void:
	var r_miho: Resident = m._resident("miho")
	if r_miho != null and r_miho.affinity != null:
		_set_idle(r_miho, 3)

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S9b-T1 켄 풀 온보딩(인물 + 서사) 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_drain(m)                                   # 신규 시작의 옥자 통보 대화
	m.onboarding.step = Onboarding.DONE
	_satisfy_soft_gate(m)
	var r: Resident = m._resident("ken")
	var ken: Node2D = r.node
	m.clock.day = 3                             # 주 첫날이 아닌 날(절기 물음 비발동 — ⑤에서 켠다)

	# ── ① 온보딩(인물 층) ──
	print("── ① 온보딩(레코드·집·스케줄·선물·생일) ──")
	_check("①a 레코드 등록 · 표시명", r != null and r.display_name == "켄")
	_check("①b 몸이 런타임 생성돼 트리에 붙는다(main.tscn 무수정 — 모찌가 깐 길)",
		ken != null and ken.is_inside_tree() and ken is Ken)
	_check("①c 관계 트랙(Affinity)도 함께 생긴다 · 신규 세이브 키",
		r.affinity != null and r.save_key == "ken_affinity")
	_check("①d 선물 채널 있음 · 초상화는 아직 없음(시트·초상 = S9b-T9 아트 패스)",
		r.can_gift and r.gift_target_ko == "켄" and r.portrait_stem == "")
	_check("①e ★곱셈기 없음(조연 = 쉼터 2채널 · ADR-0008 곱셈기는 메인 4인 독점)",
		not r.effect_fn.is_valid())
	# 집 배정 — 주민 집 9(index 8 · 동편 중하단 우 = 마을 동쪽 끝). 강변 2채(9·10 = 세레나 예약)와
	# 모찌(index 3)를 비껴간다.
	var t_home: Vector2i = r.schedule[0]["tile"]
	var t_plaza: Vector2i = r.schedule[1]["tile"]
	var t_cafe: Vector2i = r.schedule[2]["tile"]
	_check("①f 집 앞 = 주민 집 9 문 바로 아래(남향 진입 칸)",
		t_home == m.RESIDENT_HOUSE_DOORS[8] + Vector2i(0, 1))
	_check("①g 강변 2채(세레나 예약)·모찌 집과 겹치지 않는다",
		t_home != m.RESIDENT_HOUSE_DOORS[9] + Vector2i(0, 1)
		and t_home != m.RESIDENT_HOUSE_DOORS[10] + Vector2i(0, 1)
		and t_home != m.RESIDENT_HOUSE_DOORS[3] + Vector2i(0, 1))
	_check("①h 세 자리가 전부 다른 칸", t_home != t_plaza and t_plaza != t_cafe and t_home != t_cafe)
	_check("①i 낮 = 광장 안이되 통행 레인·야시장 매대·모찌 자리를 비껴간다",
		m.NARU_PLAZA_RECT.has_point(t_plaza) and t_plaza.y != m.MAIN_CORRIDOR_Y
		and not (t_plaza.x in m.BRIDGE_X) and t_plaza != m.NIGHT_MARKET_TILE
		and t_plaza != m._resident("mochi").schedule[1]["tile"])
	_check("①j 저녁 = 카페 방 안 · 좌석/직원/모찌 자리와 안 겹침",
		m.CAFE_RECT.has_point(t_cafe) and not (t_cafe in m.SEAT_TILES)
		and t_cafe != m.MEL_TILE and t_cafe != m.MIHO_CAFE_TILE and t_cafe != m.OKJA_CAFE_TILE
		and t_cafe != m.KITCHEN_TILE and t_cafe != m._resident("mochi").schedule[2]["tile"])
	_check("①k 세 자리 모두 나루 마을 구역(같은 구역 = 보간 걷기가 돈다)",
		r.station_region(GameClock.START_MIN) == RegionCatalog.NARU_VILLAGE
		and r.station_region(12 * 60) == RegionCatalog.NARU_VILLAGE
		and r.station_region(20 * 60) == RegionCatalog.NARU_VILLAGE)
	_check("①l 시각별 자리(아침 집 앞 · 낮 광장 · 저녁 카페)",
		r.station_tile(GameClock.START_MIN) == t_home and r.station_tile(12 * 60) == t_plaza
		and r.station_tile(20 * 60) == t_cafe)
	_check("①m 선호 선물 = 살아 있는 약초·화초 러브 / 다 타고 남은 것 헤이트",
		GiftPrefs.tier_of("ken", ItemCatalog.JEOSEUNG_SAM) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("ken", ItemCatalog.MIHOK_NANCHO) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("ken", ItemCatalog.HONTAN) == GiftPrefs.HATE)
	var b: Array = Resident.birthday_of("ken")
	var bday_day := _find_birthday_day("ken")
	_check("①n 생일 배정(달력 단일 출처) · 그 날짜가 실제로 켄 생일로 판정된다",
		b.size() == 2 and bday_day > 0 and r.is_birthday_on(bday_day))

	# ── ② 관문 ♡1~4 = 본문 + 컷신 → 대화 합류 ──
	print("── ② 관문 ♡1~4 ──")
	for target in [1, 2, 3, 4]:
		_set_heart(r, target - 1)
		var body: PackedStringArray = ken.heart_gate_lines(target)
		var steps: Array = ken.heart_gate_cutscene(target)
		var runner := CutsceneRunner.new(steps)
		_check("②a♡%d 관문 본문이 있다(placeholder 폴백 아님)" % target,
			body.size() >= 5 and String(body[0]) != m.HEART_GATE_PLACEHOLDER_LINE)
		_check("②b♡%d 컷신이 4동사 안이다(거절 0 · 유효 스텝 있음)" % target,
			runner.rejected_verbs().is_empty() and runner.step_count() == steps.size()
			and runner.step_count() > 0)
		m._start_resident_dialogue(r)
		_check("②c♡%d 대화보다 먼저 컷신이 선다(대화는 아직 안 열림)" % target,
			m.cutscene != null and not m.dialogue.is_open() and r.affinity.hearts() == target)
		_settle(m)
		_check("②d♡%d 재생이 끝나면 관문 발화가 맨 앞에 선 대화가 열린다" % target,
			m.cutscene == null and m.dialogue.is_open()
			and m.dialogue.line() == String(body[0]))
		_drain(m)
	_check("②e 재생 종료 후 화면·시계 원복(암전인 채로 안 끝난다)",
		is_equal_approx(m.fade.modulate.a, 0.0) and m.clock.running
		and m._cam.offset.is_equal_approx(Vector2.ZERO))
	_check("②f 자리 잡기는 완전 암전 뒤 · 밝은 화면엔 보간 이동만(순간이동 0)",
		_npc_steps_behind_fade(ken))
	_check("②g 무거운 두 비트(♡3·♡4)만 npc를 쓴다(가벼운 칸은 순간이동 위험 0)",
		not _has_verb(ken.heart_gate_cutscene(1), "npc")
		and not _has_verb(ken.heart_gate_cutscene(2), "npc")
		and _has_verb(ken.heart_gate_cutscene(3), "npc")
		and _has_verb(ken.heart_gate_cutscene(4), "npc"))

	# ── ③ 재구애 = 조용(비트 잔존 · 컷신 안 섬) ──
	print("── ③ 재구애 = 조용 ──")
	_set_heart(r, 1)                            # ♡2 비트는 ②에서 이미 봤다
	var regate: PackedStringArray = m._try_heart_promotion(r)
	_check("③a 본 비트는 재지급 없음(발화 0 · 진급은 됨)",
		regate.is_empty() and r.affinity.hearts() == 2)
	_set_heart(r, 2)
	m._start_resident_dialogue(r)
	_check("③b 조용한 진급엔 컷신도 안 선다(사건 없음 — 평소 대화로 열린다)",
		m.cutscene == null and m.dialogue.is_open() and r.affinity.hearts() == 3)
	_drain(m)

	# ── ④ 일상 대사 4단 + 배우자 4축 ──
	print("── ④ 일상 대사 4단 ──")
	var l0: PackedStringArray = ken.lines(0, true)
	var l1: PackedStringArray = ken.lines(1, true)
	var l2: PackedStringArray = ken.lines(2, true)
	var l3: PackedStringArray = ken.lines(3, true)
	var l4: PackedStringArray = ken.lines(4, true)
	var l5: PackedStringArray = ken.lines(5, true)
	_check("④a 네 단이 서로 다르다(♡0 ≠ ♡1+ ≠ ♡3+ ≠ ♡5)",
		l0 != l1 and l1 != l3 and l3 != l5 and not l5.is_empty())
	_check("④b 단 안에서는 같은 묶음(♡1=♡2 · ♡3=♡4 — 4단이지 6단이 아니다)",
		l1 == l2 and l3 == l4)
	_check("④c 네 단 모두 3줄 이상(빈 단 없음)",
		l0.size() >= 3 and l1.size() >= 3 and l3.size() >= 3 and l5.size() >= 3)
	_check("④d 오늘 두 번째 대화 = 짧은 한 줄(하트에 따라 온도만 다르다)",
		ken.lines(0, false).size() == 1 and ken.lines(5, false).size() == 1
		and ken.lines(0, false) != ken.lines(5, false))
	# 배우자 **4축**(메인 8축의 절반 — 결정 5). day 파생이라 상태가 0이고, 네 축이 서로 다르다.
	var axes := {}
	for d in 4:
		var ax: PackedStringArray = ken.spouse_lines(d, true)
		axes[String(ax[0])] = true
		_check("④e 배우자 축 %d는 비어 있지 않다" % d, ax.size() >= 2)
	_check("④f 네 축이 전부 다르다(4일 주기 — 조연 절반 폭)", axes.size() == 4)
	_check("④g 축은 day 파생 — 같은 날은 언제 물어도 같다(무상태)",
		ken.spouse_lines(3, true) == ken.spouse_lines(3, true)
		and ken.spouse_lines(7, true) == ken.spouse_lines(3, true))
	_check("④h 배우자도 오늘 두 번째 대화는 한 줄", ken.spouse_lines(3, false).size() == 1)
	# main 이음매 — 결혼 상태면 lines() 대신 배우자 묶음이 나온다(휴면 본문이 실제로 물린다).
	_set_heart(r, Affinity.MAX_HEARTS)
	m._spouse_id = "ken"
	m.clock.day = 10                            # 주 첫날 아님(물음 비발동)
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_check("④i main이 배우자 묶음으로 갈아탄다",
		m.dialogue.line() == String(ken.spouse_lines(10, true)[0])
		and m.dialogue.line() != String(ken.lines(5, true)[0]))
	_drain(m)
	m._spouse_id = ""
	_set_idle(r, 3)     # 진급 대기가 안 서는 상태(물음이 밀리지 않게)

	# ── ⑤ 절기 물음(주 첫날 · 1회 · 0점) ──
	print("── ⑤ 절기 물음 ──")
	var q0: Dictionary = ken.season_question(0)
	_check("⑤a 절기 4개 전부 물음이 있다(각 2~4지 · 반응 짝이 맞는다)", _all_seasons_ok(ken))
	_check("⑤b 범위 밖 절기는 빈 dict(방어)",
		ken.season_question(-1).is_empty() and ken.season_question(4).is_empty())
	m.clock.day = 15                            # (15-1)%7 == 0 → 주 첫날 · 절기 0(피안절)
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	# ★ 점수 스냅은 **대화가 열린 뒤**다 — 일일 대화 보상(daily_talk)은 대화 진입의 몫이라
	#   그 전에 재면 이 단언이 "선택이 아니라 대화 자체"를 재게 된다.
	var pts_before: int = r.affinity.points
	var stage_before: int = r.affinity.stage
	_check("⑤c 주 첫날 첫 대화 = 질문은 맨 뒤(첫 줄이 아니다)",
		m.dialogue.is_open() and String(m.dialogue.line()) != String(q0["line"]))
	while m.dialogue.is_open() and not m.dialogue.has_choice():
		m.dialogue.advance()
	_check("⑤d 질문 줄에 선택지가 선다(문항 = 캐릭터 소유 본문)",
		m.dialogue.has_choice() and m.dialogue.line() == String(q0["line"])
		and m.dialogue.choices() == PackedStringArray(q0["options"]))
	m.dialogue.choose(1)
	_check("⑤e 고르면 반응 한 줄로 교체된다",
		m.dialogue.is_open() and m.dialogue.line() == String(PackedStringArray(q0["replies"])[1]))
	_check("⑤f ★0점 계약 — 선택 전후 점수·stage 불변",
		r.affinity.points == pts_before and r.affinity.stage == stage_before)
	_drain(m)
	m.clock.day = 17                            # 같은 주의 다른 날(주 첫날도 아니다)
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_check("⑤g 주 중간엔 물음 없음", not _has_question(m, q0))
	_drain(m)
	m.clock.day = 22                            # (22-1)%7 == 0 → 다음 주 첫날 · 여전히 절기 0
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_check("⑤h 다음 주 첫날엔 다시 묻는다", _has_question(m, q0))
	_drain(m)
	m.clock.day = 36                            # (36-1)%7 == 0 → 주 첫날 · 절기 1(유화절)
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_check("⑤i 절기가 바뀌면 문항도 바뀐다",
		_has_question(m, ken.season_question(1)) and not _has_question(m, q0))
	_drain(m)
	# 관문보다 뒤 — 대화 한 번에 사건 하나.
	m.clock.day = 43                            # 주 첫날 · 절기 1
	m._heart_bits = {}
	_set_heart(r, 3)
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_settle(m)
	_check("⑤j 관문이 선 대화엔 물음이 안 붙는다(관문 > 물음)",
		r.affinity.hearts() == 4 and not _has_question(m, ken.season_question(1)))
	_drain(m)
	# 생일 — 훅 본문이 있고, 생일 당일 대화가 그 줄로 열린다.
	var bday: PackedStringArray = ken.birthday_lines()
	_check("⑤k 생일 훅 본문(placeholder 폴백 아님)",
		bday.size() >= 2 and String(bday[0]) != m.BIRTHDAY_PLACEHOLDER_LINE)
	_set_idle(r, 3)                             # 관문이 안 서는 상태(생일이 대화의 사건이 되게)
	m.clock.day = bday_day
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_check("⑤l 생일 당일 대화는 생일 발화로 열린다(평소 묶음 앞)",
		m.dialogue.is_open() and m.dialogue.line() == String(bday[0]))
	_drain(m)
	m.free()
	cleaner.delete_save()

	# ── ⑥ 편지(관문 여진 3통) ──
	print("── ⑥ 편지 ──")
	var m3: Node = await _new_main()
	_drain(m3)
	m3.onboarding.step = Onboarding.DONE
	_satisfy_soft_gate(m3)
	var r3: Resident = m3._resident("ken")
	var ken3: Node2D = r3.node
	m3.clock.day = 3
	_check("⑥a 시작 시 우편함은 비어 있다",
		m3.mailbox.pending_count() == 0 and not m3.mailbox.has_unread())
	_set_heart(r3, 0)
	m3._try_heart_promotion(r3)
	var lid: String = ken3.heart_gate_letter(1)
	_check("⑥b 관문 ♡1 성사 = 편지가 큐에 든다(같은 날 도착은 없다)",
		lid != "" and m3.mailbox.pending_count() == 1 and not m3.mailbox.has_unread())
	m3._on_day_advanced(m3.clock.day + 1)
	_check("⑥c 다음 날 아침 도착 = 미독 1통",
		m3.mailbox.pending_count() == 0 and m3.mailbox.unread_count() == 1
		and m3.mailbox.next_unread() == lid)
	_check("⑥d 본문·발신인이 실려 있다",
		Mailbox.sender_of(lid) == "켄" and Mailbox.lines_of(lid).size() >= 3)
	# 재구애(비트 잔존)로 같은 관문이 다시 성사돼도 편지는 두 번 안 온다.
	_set_heart(r3, 0)
	m3._try_heart_promotion(r3)
	_check("⑥e 중복 발송 없음(mailbox가 방어 — 사건 코드는 기억 불요)",
		m3.mailbox.pending_count() == 0 and m3.mailbox.unread_count() == 1)
	var ids := {}
	for t in [1, 3, 4]:
		var id: String = ken3.heart_gate_letter(t)
		ids[id] = true
		_check("⑥f♡%d 편지 id가 테이블에 실존" % t, id != "" and Mailbox.has_letter(id))
	_check("⑥g 세 칸이 각기 다른 편지(조연 상한 2~3통)", ids.size() == 3)
	_check("⑥h ♡2·관문 밖 칸은 편지 없음(말을 못 꺼낸 칸엔 여진도 없다)",
		ken3.heart_gate_letter(2) == "" and ken3.heart_gate_letter(5) == "")
	_check("⑥i 메인 3인 편지와 id가 겹치지 않는다",
		_no_letter_collision(ken3, m3._resident("miho").node)
		and _no_letter_collision(ken3, m3._resident("mel").node)
		and _no_letter_collision(ken3, m3._resident("bana").node))

	# ── ⑦ 휴면 콘텐츠(연애·이혼) ──
	print("── ⑦ 휴면 콘텐츠(고백·이혼) ──")
	var acc: PackedStringArray = ken3.confession_lines(true)
	var rej: PackedStringArray = ken3.confession_lines(false)
	_check("⑦a 수락·거절이 각기 본문을 가지고 서로 다르다",
		acc.size() >= 2 and rej.size() >= 2 and acc != rej
		and String(acc[0]) != m3.CONFESS_ACCEPT_LINE and String(rej[0]) != m3.CONFESS_REJECT_LINE)
	var far: PackedStringArray = ken3.divorce_lines()
	_check("⑦b 작별 훅 — 첫 줄이 혼자 서는 한 문장(토스트 경로)",
		not far.is_empty() and String(far[0]).length() >= 6
		and m3._divorce_farewell_line(r3) == String(far[0]))
	# ★ 지금은 **명단 밖**이라 고백 제안이 안 선다(S9b-T6이 ROMANCE_OPEN에 "ken"을 넣으면 열린다).
	_check("⑦c 아직 ROMANCE_OPEN 밖 = 제안 미노출(개통은 T6 소관 · 본문은 이미 대기)",
		not m3.ROMANCE_OPEN.has("ken"))
	_set_heart(r3, Affinity.MAX_HEARTS - 1)
	m3._romance_partner = ""
	m3._heart_bits = {}
	r3.affinity.last_talk_day = 0
	m3.clock.day = 10
	m3._start_resident_dialogue(r3)
	_check("⑦d 제안 줄이 안 선다(명단 밖 — 구조는 rid 무관이라 명단이 유일한 스위치)",
		m3.dialogue.is_open() and m3.dialogue.line() != m3.CONFESS_OFFER_LINE)
	_drain(m3)

	# ── ⑧ 볼륨 상한(ADR-0068 결정 5) ──
	print("── ⑧ 볼륨 ──")
	var total := _total_lines(ken3)
	print("    대사 줄 수(전 묶음 합) = %d" % total)
	_check("⑧a 조연 1인 대사 볼륨이 상한 안(100~150줄 — 상한이지 목표치가 아니다)",
		total >= 100 and total <= 150)
	_check("⑧b 관문 컷신 4개(관문당 1)", _cutscene_count(ken3) == 4)
	_check("⑧c 편지 3통(2~3통 범위)", ids.size() >= 2 and ids.size() <= 3)
	_check("⑧d 절기 물음 4개(절기당 1)", ken3.SEASON_QUESTIONS.size() == 4)
	_check("⑧e 배우자 4축(메인 8축의 절반)", ken3.SPOUSE_AXES.size() == 4)
	_check("⑧f 오늘 두 번째 한 줄이 세 종류(평소 · 연인 · 배우자)",
		String(ken3.LINE_AGAIN) != String(ken3.LINE_AGAIN_LOVER)
		and String(ken3.LINE_AGAIN_LOVER) != String(ken3.LINE_AGAIN_SPOUSE))

	# ── ⑨ 봉인 법칙 가드(ADR-0068 결정 6 · 금칙어 31어) ──
	print("── ⑨ 봉인 법칙 ──")
	# 조연 금칙어 = 중심 진실 4종(옥자의 희생 / 기억 봉인 / 마녀 = 연인 / 플레이어의 죄목)의
	# 어떤 문장도 켄 입에서 나오지 않는다. 메인 3인·T1 2인 스위트가 쓰던 어휘를 그대로 **상속**하고
	# (앞 22어), 조연 전용 중심 진실 어휘 9어를 더해 31어로 잠근다. 검열이 아니라 회귀 가드다 —
	# 나중 손질이 평결 문장을 흘려 넣으면 여기서 걸린다.
	var verdicts := [
		# ㉠ 플레이어 죄목의 중심 평결(miho·mel·bana·t1 스위트 상속분)
		"네 죄는", "너의 죄는", "네가 지은 죄", "네 죄목", "그러니까 네가", "그게 네 죄",
		"너 때문에 옥자", "네가 옥자를", "너는 외면했", "네가 외면한", "너는 잊었",
		"네가 잊은 죄", "네가 버린 죄", "네가 태워 없앤", "네가 방치했", "네가 버려둔",
		"네가 지키지 않아", "네가 없었기 때문",
		# ㉡ 그날 밤의 판독 결론(조연은 파편만 안다)
		"옥자의 눈물", "강림의 명부", "차사 명부", "그날 밤에 일어난",
		# ㉢ 중심 진실 4종의 사실 진술(ADR-0068 결정 6 조연 금칙어)
		"기억을 봉인", "봉인된 기억", "기억이 봉인", "너를 살리려고", "널 살리려고",
		"네 대신 죽", "마녀가 된 건", "옥자의 연인", "종신계약을 대신",
	]
	_check("⑨a 금칙어 목록이 31어(메인 상속 + 조연 전용)", verdicts.size() == 31)
	var offender := _scan_forbidden(ken3, verdicts)
	_check("⑨b 중심 평결·중심 진실 어휘 0", offender == "")
	if offender != "":
		print("      ↳ 걸린 줄: " + offender)
	var g3 := _joined(ken3.GATE_HEART_3)
	_check("⑨c ♡3은 **자기 손이 실패한 것**의 고백이다(그날 밤 파편 = 못 부순 문)",
		g3.contains("못 부쉈") and g3.contains("잠겨"))
	_check("⑨d ★공백 ①: 문 너머가 누구였는지 모른다(플레이어가 잇는 자리)",
		g3.contains("누구였는지는 끝까지 못 봤"))
	_check("⑨e ★공백 ②: 자기가 죽은 뒤는 모른다(옥자의 그 뒤를 켄이 대신 말하지 않는다)",
		g3.contains("나는 몰라") and g3.contains("내가 본 게 아니야"))
	_check("⑨f ★켄 본문에 \"옥자\" 0회(이승의 약방 주인 = 지금의 카페 사장을 자기 입으로 안 잇는다)",
		not _all_text(ken3).contains("옥자"))
	var g4 := _joined(ken3.GATE_HEART_4)
	_check("⑨g ♡4는 **자기 생전 죄까지만**(남의 죄도 플레이어의 죄도 겨누지 않는다)",
		g4.contains("사람을 하나 해쳤") and not g4.contains("네 죄")
		and not g4.contains("옥자") and not g4.contains("그날 밤"))
	_check("⑨h 본문은 Affinity를 모른다(0점 계약의 구조적 근거)",
		not _ken_code().contains("Affinity") and not _ken_code().contains("add_points"))

	m3.free()
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ ken_arc_test 전체 통과 ══")
	else:
		print("══ ken_arc_test 실패 %d건 ══" % _fail)
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

# 켄의 네 관문 컷신에서, **순간이동이 화면에 보이지 않는가**(bana_arc_test와 같은 규약).
# 그 컷신의 **첫 npc 스텝**은 임의의 자리에서 장면 자리로 뛰는 순간이동이라 반드시 완전 암전
# (fade 1.0) 뒤여야 한다. 그 다음부터는 출발점이 확정돼 있으므로 secs > 0의 보간 이동은 밝은
# 화면에서 해도 된다(그게 "걸어 들어온다" 연출이다). 밝은 화면의 즉시 이동(secs 0)만 금지된다.
func _npc_steps_behind_fade(who: Node2D) -> bool:
	for t in [1, 2, 3, 4]:
		var fade := 0.0
		var first_npc := true
		for s in (who.heart_gate_cutscene(t) as Array):
			var step := s as Dictionary
			var verb := String(step.get("verb", ""))
			if verb == "fade":
				fade = float(step.get("to", 0.0))
				continue
			if verb != "npc":
				continue
			if first_npc:
				first_npc = false
				if not is_equal_approx(fade, 1.0):
					return false      # 자리 잡기(순간이동)가 밝은 화면에서 일어났다
			elif fade < 1.0 and float(step.get("secs", 0.0)) <= 0.0:
				return false          # 밝은 화면에서의 즉시 이동 = 순간이동으로 보인다
	return true

# 켄과 그 사람이 같은 편지 테이블을 쓰면서 id를 겹치지 않는가.
func _no_letter_collision(who: Node2D, other: Node2D) -> bool:
	if other == null or not other.has_method("heart_gate_letter"):
		return true
	for t in [1, 2, 3, 4]:
		var a := String(who.heart_gate_letter(t))
		for u in [1, 2, 3, 4]:
			if a != "" and a == String(other.heart_gate_letter(u)):
				return false
	return true

# 켄이 가진 모든 대사 줄 묶음(볼륨 실측·금칙어 스캔이 공유하는 단일 출처).
func _packs(who: Node2D) -> Array:
	return [who.LINES_INTRO, who.LINES_WARMING, who.LINES_CLOSE, who.LINES_LOVER,
		who.GATE_HEART_1, who.GATE_HEART_2, who.GATE_HEART_3, who.GATE_HEART_4,
		who.CONFESSION_ACCEPT, who.CONFESSION_REJECT, who.DIVORCE_FAREWELL, who.BIRTHDAY]

# 볼륨 실측(bana_arc_test의 셈법 그대로 — 선택지 항목까지 센다).
func _total_lines(who: Node2D) -> int:
	var n := 0
	for pack in _packs(who):
		n += (pack as Array).size()
	for ax in who.SPOUSE_AXES:
		n += (ax as Array).size()
	for q in who.SEASON_QUESTIONS:
		n += 1 + PackedStringArray(q["options"]).size() + PackedStringArray(q["replies"]).size()
	return n + 3   # LINE_AGAIN 3종

func _cutscene_count(who: Node2D) -> int:
	var n := 0
	for t in [1, 2, 3, 4]:
		if not (who.heart_gate_cutscene(t) as Array).is_empty():
			n += 1
	return n

func _joined(pack: Array) -> String:
	return "\n".join(PackedStringArray(pack))

# 켄의 **전 본문**(대사 + 절기 물음 + 편지)을 한 줄 배열로.
func _all_lines(who: Node2D) -> Array:
	var all: Array = []
	for pack in _packs(who):
		all.append_array(pack as Array)
	for ax in who.SPOUSE_AXES:
		all.append_array(ax as Array)
	for q in who.SEASON_QUESTIONS:
		all.append(q["line"])
		all.append_array(q["options"] as Array)
		all.append_array(q["replies"] as Array)
	all.append_array(_ken_letter_lines())
	return all

func _all_text(who: Node2D) -> String:
	return "\n".join(PackedStringArray(_all_lines(who)))

# 켄의 전 본문에서 금칙어를 찾는다(걸린 줄을 돌려준다 — 없으면 "").
func _scan_forbidden(who: Node2D, words: Array) -> String:
	for ln in _all_lines(who):
		for w in words:
			if String(ln).contains(String(w)):
				return String(ln)
	return ""

# 켄 발신 편지의 모든 줄.
func _ken_letter_lines() -> Array:
	var out: Array = []
	for id in Mailbox.LETTERS:
		if String(Mailbox.LETTERS[id].get("from", "")) == "켄":
			out.append_array(Mailbox.LETTERS[id].get("lines", []) as Array)
	return out

# ken.gd의 **주석을 걷어낸 코드 본문**(주석이 검사 문자열을 우연히 품는 오탐 방지).
func _ken_code() -> String:
	var f := FileAccess.open("res://ken.gd", FileAccess.READ)
	if f == null:
		return ""
	var out := PackedStringArray()
	for ln in f.get_as_text().split("\n"):
		if not String(ln).strip_edges().begins_with("#"):
			out.append(String(ln))
	return "\n".join(out)
