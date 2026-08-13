extends SceneTree
# ★[S9b-T6 / ADR-0068 결정 2·3·4·5·6·12] 세레나 풀 온보딩 + **조연 연애·결혼 전원 개통** —
# 헤드리스 검증.
#
# 규약은 kkaebi/ken/seolhwa/scarlet/mir/luca/frosty/gangrim_arc_test를 그대로 상속한다(금칙어
# 31어 가드·볼륨 측정·훅 존재·관문 드레인·절기 물음·생일·편지·소프트 게이트). **이 스위트가
# 앞 여덟과 갈리는 자리는 둘**이다 — ⑩ **무호명 가드**(멜·바나 실명 평결 0)와 ⑫ **개통 계약**
# (앞 여덟이 "아직 명단 밖"을 단언했다면 여기는 "명단이 열렸다"를 단언한다).
#
# ★ 왜 무호명 가드가 따로 필요한가([narrative-bible §5.3] · [ADR-0068] 결정 6):
#   세레나는 **그 밤을 가장 많이 본 조연**이다(우물 안에서 실시간·처음부터 끝까지). 게다가
#   §5.3이 "원흉(멜·바나) 보면 목격자로서 하악질"이라 적어 두었다 — 즉 **이름을 부를 동기가
#   본문에 내장된 유일한 인물**이다. 이름을 붙이는 순간 그것은 코러스가 아니라 *다른 사람의
#   아크에 대한 평결*이 되어 멜·바나 속죄 서사의 소유를 침범하므로(도박장 3자를 무호명으로
#   세운 S9b-T3의 판단과 같은 자리), 하악질이 **결로만** 사는지를 기계로 잰다.
#   ★ 동시에 **🟢 허용 상한이 실제로 서 있는지**도 잰다 — 침묵만 재면 그것은 가드가 아니라
#     검열이고, 하악질이 아예 없는 본문도 통과해 버린다(S9b-T5가 남긴 교훈의 승계).
#
# 무엇을 보증하나:
#   ① 인물 층 배선 — 레코드 1건이 실제로 등록되고(id·표시명·세이브 키·선물 채널·집/스케줄),
#      세 스테이션이 서로 다르며 다른 주민 자리와 안 겹친다. 집은 **T1부터 여덟 블록이 비켜
#      둔 강변 2채 중 서쪽**이고, 이로써 **남는 집이 강변 동 한 채(네오 몫)뿐**이다.
#      ★ 세 자리가 **전부 물가**다(광장 0 · 카페 실내 0 — 이 인물만의 불변식).
#   ② 일상 대사 **4단** 분기(♡0/♡1+/♡3+/♡5+) — 단 경계가 관문 경계와 맞고, 단 안에서는 같은
#      묶음이며, 오늘 두 번째 대화는 하트에 따라 온도만 다른 한 줄이다.
#   ③ 관문 발화 **♡1~4 네 칸 전부** 캐릭터 본문이다(placeholder 폴백 0 — 조연 4단 아크).
#   ④ 컷신 — 4동사 안이고(거절 0) 칸마다 하나이며 **npc 동사 0**, 재생이 끝나면 관문 발화가
#      맨 앞에 선 대화가 열린다. ★**가로(x) 오프셋을 쓰는 유일한 인물**(물결) · ♡3 암전은
#      **한 계단**으로 떨어진다(강림의 두 계단과 정확한 대비).
#   ⑤ 여진 편지 — ♡2·♡3·♡4가 각기 실존하는 편지를 지목하고(♡1은 없음) 발신인이 세레나이며,
#      **세 통 다 끝에서 문장을 포기하고 노래로 넘어간다**. 관문 성사가 큐에 넣고 익일 도착.
#   ⑥ 절기 물음 4개 — 짝이 맞고, 주 첫날 첫 대화에 서며, **0점 계약**(선택 전후 점수·stage 불변).
#   ⑦ 생일 — 훅 본문 + Resident.BIRTHDAYS 배정(피안절 26일) + main 경로가 물린다.
#   ⑧ 볼륨([ADR-0068] 결정 5) — 대사 100~150줄 · 컷신 4 · 절기 4 · 편지 ≤3 · **spouse 4축**.
#   ⑨ 봉인 법칙 구조 단언 — 31어 스캔 0 + 세레나 고유 경계(판독 실패·자기 죄책감·1인칭·
#      Affinity 0·낚시 도메인 무침범).
#   ⑩ ★★**무호명 가드**(이 태스크의 핵심) — 「옥자」·「멜」·「바나」를 비롯한 전 로스터 실명이
#      본문·편지 전량에서 0회이면서, **하악질의 결과 목격의 사실은 실제로 서 있다**.
#   ⑪ 소프트 게이트 ㉠(결정 6) — 등재도 이 태스크가 했고, 이 한 줄로 **T1 11인 전원 등재**가
#      완성된다("미접촉이면 대기"까지 여기서 전부 잰다).
#   ⑫ ★★**개통 계약**([ADR-0068] 결정 2) — `ROMANCE_OPEN`이 **메인 3 + T1 11 = 14인**이고,
#      모찌·네오 소급 훅이 실제로 붙었으며, **질투 명단은 갈라져 메인 3인 상호로 남았다**
#      ([ADR-0066] 결정 7 자구 보존 — 조연 연애 개시 = 질투 0건).
#   ⑬ 비약 = 세레나 **한정** 구조(명단이 아니라 한 명 · 옥자 트랙 무접촉). 실동작 사슬
#      (의뢰 → 청혼 게이트 → 소모)은 marriage_test가 소유한다.
#
# 실행: ./run_tests.sh serena_arc   (헤드리스는 반드시 game/에서 · 순차)

const KID := "serena"
const NAME_KO := "세레나"
const HOUSE_IDX := 9        # 주민 집 10 = 강변 서(RESIDENT_HOUSE_RECTS[9] — T1부터 예약된 그 자리)
const FREE_HOUSE_IDX := 10  # 남는 강변 동(네오 몫으로 비워 둔다 — 레코드 주석)

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
	print("══ S9b-T6 세레나 풀 온보딩 + 조연 연애·결혼 전원 개통 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_drain(m)                                   # 신규 시작의 옥자 통보 대화
	m.onboarding.step = Onboarding.DONE
	m.clock.day = 3                             # 주 첫날 아님(절기 물음은 ⑥에서 따로 켠다)
	_set_mains(m, m.CHORUS_GATE_MAIN_STAGE)     # ★소프트 게이트 ㉠ 선주입(⑪에서 닫았다 다시 연다)

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
		and r.save_key == "serena_affinity" and r.affinity != null and r.can_gift)
	_check("①c 곱셈기 없음(조연 = 쉼터 2채널 — ADR-0008 메인 4인 독점)",
		not r.effect_fn.is_valid())
	_check("①d 초상화는 아직 없다(시트·초상 = S9b-T9 아트 패스)", r.portrait_stem == "")
	var house_door: Vector2i = m.RESIDENT_HOUSE_DOORS[HOUSE_IDX]
	_check("①e 스케줄 3단(집 앞 → 낮 물가 → 저녁 물가) · 전부 나루 마을",
		r.schedule.size() == 3
		and r.schedule[0]["tile"] == house_door + Vector2i(0, 1)
		and String(r.schedule[0]["region"]) == RegionCatalog.NARU_VILLAGE
		and String(r.schedule[2]["region"]) == RegionCatalog.NARU_VILLAGE)
	_check("①f 낮·저녁 자리가 아침 자리와 다르다(실제로 도는 동선)",
		r.schedule[0]["tile"] != r.schedule[1]["tile"]
		and r.schedule[1]["tile"] != r.schedule[2]["tile"])
	_check("①g 세 자리 어느 것도 다른 주민 자리와 안 겹친다(마주보기 판정 파손 방지)",
		_no_station_clash(m, r))
	# ★ 이 인물만의 불변식 — 물 밖에 서지 않는다(serena.gd ♡2 관문이 세우는 그 선).
	var day_tile: Vector2i = r.schedule[1]["tile"]
	var dusk_tile: Vector2i = r.schedule[2]["tile"]
	_check("①h ★낮·저녁 자리가 강변 레인 위다(물가 — 광장·카페 실내에 안 선다)",
		day_tile.y == m.RIVERSIDE_LANE_Y and dusk_tile.y == m.RIVERSIDE_LANE_Y)
	_check("①i ★세 자리 어느 것도 광장 안이 아니다(로스터에서 유일 — 물 밖 좌표 금지)",
		not m.NARU_PLAZA_RECT.has_point(Vector2i(r.schedule[0]["tile"]))
		and not m.NARU_PLAZA_RECT.has_point(day_tile)
		and not m.NARU_PLAZA_RECT.has_point(dusk_tile))
	_check("①j ★다리 스파인(x52·53)을 한 칸도 안 막는다",
		not m.BRIDGE_X.has(day_tile.x) and not m.BRIDGE_X.has(dusk_tile.x))
	_check("①k ★집이 강변 주거다(T1부터 여덟 블록이 세레나 몫으로 비켜 둔 그 2채)",
		_house_is_riverside(m, HOUSE_IDX))
	_check("①l ★둘 중 **서쪽**이다(다리에서 가장 먼 물가 — 레코드 근거 ㉠)",
		house_door.x < int(m.BRIDGE_X[0]))
	_check("①m 앞 아홉 사람과 다른 집이다(1인 1채)", _house_unique(m, HOUSE_IDX))
	_check("①n ★이제 남는 집은 강변 동 한 채뿐이다(네오 몫 — 레코드 주석 · owner 큐)",
		_free_house_count(m) == 1 and _house_free(m, FREE_HOUSE_IDX))
	# 선호 선물 — 러브/헤이트가 실존 아이템이고 전부 건넬 수 있어야 한다.
	_check("①o 선호 선물 테이블(러브 5 · 헤이트 1 · 전부 실존·건넬 수 있음)",
		GiftPrefs.loves(KID).size() == 5 and GiftPrefs.hates(KID).size() == 1
		and _prefs_valid())
	_check("①p ★혼불씨 헤이트가 유니버설(원자재=디스라이크)을 덮는다",
		GiftPrefs.tier_of(KID, ItemCatalog.HONBULSSI) == GiftPrefs.HATE
		and GiftPrefs.universal_tier(ItemCatalog.HONBULSSI) != GiftPrefs.HATE)
	_check("①q ★같은 혼불씨가 프로스티에게도 헤이트다(까닭은 정반대 — 판정은 캐릭터별 독립)",
		GiftPrefs.tier_of("frosty", ItemCatalog.HONBULSSI) == GiftPrefs.HATE)
	_check("①r ★러브에 어종이 0개다(낚시 도메인 무침범 — 물고기는 선물이 아니라 기억이다)",
		_loves_have_no_fish())

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
	_check("③c ♡3이 가장 길다(그날 밤 자기 파편 = 필수 세트피스)",
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
	_check("④b npc 동사 0(세 물가 자리를 도는 인물 — 순간이동·물 밖 좌표 위험을 구조적으로 없앤다)",
		npc_free)
	_check("④c ♡3이 완전 암전이고 ♡1은 암전 0이다(등급 2의 표현력은 암전 길이뿐)",
		_max_fade(who.heart_gate_cutscene(3)) >= 1.0
		and _max_fade(who.heart_gate_cutscene(1)) <= 0.0)
	_check("④d ★♡3 암전이 **한 계단**으로 떨어진다(물은 계단을 안 밟는다 — 강림 두 계단의 대비)",
		_rising_fade_steps(who.heart_gate_cutscene(3)) == 1)
	var x_all := true
	for t in [1, 2, 3, 4]:
		if _max_cam_x(who.heart_gate_cutscene(t)) <= 0.0:
			x_all = false
	_check("④e ★★네 컷신 전부 **가로(x) 오프셋**을 쓴다 — 물결(로스터에서 유일)", x_all)
	var gangrim_node: Node2D = m._resident("gangrim").node
	var gangrim_flat := true
	for t in [1, 2, 3, 4]:
		if _max_cam_x(gangrim_node.heart_gate_cutscene(t)) > 0.0:
			gangrim_flat = false
	_check("④f ★그 유일함의 대조군 — 강림 컷신은 x가 전부 0이다(세로로만 움직인다)",
		gangrim_flat)
	# 실제 재생(소프트 게이트는 셋업에서 이미 열어 뒀다).
	for t in [1, 2, 3, 4]:
		var body: PackedStringArray = who.heart_gate_lines(t)
		m._heart_bits = {}
		_set_heart(r, t - 1)
		r.affinity.last_talk_day = 0
		m._start_resident_dialogue(r)
		_check("④g ♡%d 컷신이 대화보다 먼저 선다(진급은 이미 성사)" % t,
			m.cutscene != null and not m.dialogue.is_open() and r.affinity.hearts() == t)
		_settle(m)
		_check("④h ♡%d 재생이 끝나면 관문 발화가 맨 앞에 선 대화가 열린다" % t,
			m.cutscene == null and m.dialogue.is_open()
			and m.dialogue.line() == String(body[0]))
		_drain(m)
	_check("④i 네 번의 재생 뒤에도 화면·시계 원복(암전 잔류 0)",
		is_equal_approx(m.fade.modulate.a, 0.0) and m.clock.running
		and m._cam.offset.is_equal_approx(Vector2.ZERO) and m.cutscene == null)
	# 재구애(본 비트 잔존) = 조용한 진급(ADR-0022).
	_set_heart(r, 3)
	var regate: PackedStringArray = m._try_heart_promotion(r)
	_check("④j 본 비트는 재지급 없음(발화 0 · 진급은 됨)",
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
	_check("⑤b 세 통 다 발신인이 세레나다", sender_ok)
	_check("⑤c ★세 통 다 **끝에서 문장을 포기하고 노래로 넘어간다**(글보다 소리가 먼저인 존재)",
		_letters_end_in_song())
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
	_check("⑤d 관문 성사 = 큐에 들어간다(같은 날 도착 0)",
		m.mailbox.pending_count() == 1 and not m.mailbox.has_unread())
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)
	_check("⑤e 다음 날 아침 도착(지목한 그 편지)",
		m.mailbox.inbox.has(lid2) and m.mailbox.unread_count() == 1)
	m._read_next_letter()
	_check("⑤f 열람 = 대화창(발신인이 화자 · 본문 첫 줄) · 여는 순간 기독",
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
	_check("⑥c 주 첫날 첫 대화 = 물음 줄에 선택지가 선다(문항 = 캐릭터 소유 본문)",
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
	_check("⑦b 생일 배정이 살아 있다(피안절 26일 — 물길이 다 풀린 뒤의 자리)",
		b.size() == 2 and int(b[0]) == 0 and int(b[1]) == 26)
	var bday_day := _find_birthday_day(KID)
	_check("⑦c 그 날짜가 실제로 이 사람 생일로 판정된다",
		bday_day > 0 and r.is_birthday_on(bday_day))
	_check("⑦d 그 날에 생일인 사람이 세레나 하나다(달력 무충돌)",
		Resident.birthday_on_day(bday_day) == KID)
	_set_idle(r, 3)                              # 관문이 안 서는 상태(생일이 대화의 사건이 되게)
	m.clock.day = bday_day
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_check("⑦e 생일 당일 대화는 생일 발화로 열린다(평소 묶음 앞)",
		m.dialogue.is_open() and m.dialogue.line() == String(bday[0]))
	_drain(m)

	# ── ⑧ 볼륨([ADR-0068] 결정 5) ──────────────────────────────────────────
	print("── ⑧ 볼륨 ──")
	var total := _total_lines(who)
	print("    본문 줄 수(선택지 제외) = %d" % total)
	_check("⑧a 대사 볼륨이 100~150줄 안(결정 5 — 상한이지 목표치가 아니다)",
		total >= 100 and total <= 150)
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

	# ── ⑨ 봉인 법칙 — 조연 공통 31어 + 세레나 고유 구조 ────────────────────
	print("── ⑨ 봉인 법칙(공통 31어 + 구조) ──")
	# 기존 아크 스위트(미호·멜·바나·T1 2인·깨비·켄·설화·스칼렛·미르·루카·프로스티·강림)의
	# 금칙어 **31어를 그대로 상속**한다. 검열이 아니라 회귀 가드다.
	var offender := _scan_forbidden(who, FORBIDDEN)
	_check("⑨a 금칙어 %d어 스캔 0(본문 + 편지 전량)" % FORBIDDEN.size(), offender == "")
	if offender != "":
		print("      ↳ 걸린 줄: " + offender)
	var g3 := _joined(who.GATE_HEART_3)
	_check("⑨b ★♡3은 **판독하지 않는다**(본 것은 모양·색까지 · 그게 무엇이었는지는 모른다)",
		g3.contains("뭐였는지는 아직도 몰라") and g3.contains("이름을 못 붙이겠어"))
	_check("⑨c ★죄책감은 자기 것뿐이다(방관 = 생전 죄와 같은 모양 — ♡4로 이어지는 실)",
		g3.contains("나는 물 밖으로 나가지 않았어"))
	_check("⑨d 목격이 후회로만 남는다(코러스는 증거를 내놓지 판결을 내놓지 않는다)",
		g3.contains("보기만 했어"))
	var g4 := _joined(who.GATE_HEART_4)
	_check("⑨e ♡4는 **자기 생전 죄까지만**(부르기만 하고 안 돌아본 방관)",
		g4.contains("돌아본 적이 없어") and g4.contains("그게 내 죄야"))
	_check("⑨f ★♡4가 끝까지 **1인칭**이다(\"너도\"·\"우리는\"으로 안 번진다 — 메인 조각의 독점 영역)",
		not g4.contains("너도") and not g4.contains("우리는")
		and not g4.contains("네 죄") and not g4.contains("네가 지은"))
	_check("⑨g 본문은 Affinity를 모른다(0점 계약의 구조적 근거)",
		not _src().contains("Affinity") and not _src().contains("add_points"))
	_check("⑨h 목소리·물을 메카닉으로 쓰지 않는다(백스토리 한정 — effect_fn 0)",
		not r.effect_fn.is_valid() and not _src().contains("effect_fn"))
	# ⚠️ 낱말은 **서사상 정당한 쓰임과 충돌하지 않는 것만** 고른다 — 예: "물"은 이 인물의 전부라
	#    당연히 못 쓰고, "찌"는 「모찌」·「어찌」에 부분 일치해 오탐이 난다(넣지 않는다).
	_check("⑨i ★낚시 도메인을 침범하지 않는다(물에서 아는 것은 언제나 *소리*다)",
		_scan_words(_corpus(who), ["낚시", "미끼", "물때", "어획", "손맛", "낚아"]) == "")

	# ── ⑩ ★★무호명 가드([narrative-bible §5.3] · [ADR-0068] 결정 6) ────────
	print("── ⑩ 무호명 가드 ──")
	# ★ 이 절이 이 스위트의 존재 이유다. §5.3이 "원흉(멜·바나) 보면 하악질"이라 적어 둔 탓에
	#   이 인물만 **이름을 부를 동기가 본문에 내장**돼 있다 — 그래서 실명을 축으로 따로 잰다.
	var corpus := _corpus(who)     # 대사 전량 + 절기 물음 + 세레나 발신 편지 전량
	for axis_name in NAME_AXES:
		var hit := _scan_words(corpus, NAME_AXES[axis_name] as Array)
		_check("⑩ %s 스캔 0" % axis_name, hit == "")
		if hit != "":
			print("      ↳ 걸린 이름: " + hit)
	# ★ 침묵만 재면 가드가 아니라 검열이다 — 하악질도 목격도 **실제로 서 있어야** 한다.
	_check("⑩d ★🟢 하악질이 **결로** 실재한다(이름 없이 몸이 먼저 반응한다)",
		corpus.contains("목이 저절로 닫혀") and corpus.contains("목이 잠깐 잠긴다"))
	_check("⑩e ★🟢 목격의 사실도 실재한다(무호명이 곧 무내용이 아니다)",
		corpus.contains("불이 났어") and corpus.contains("우물 테두리 위로"))
	_check("⑩f ★척추를 이 파일이 소유하지 않는다(B4~B7·spine은 main/S9b-T7의 것)",
		not _src().contains("SPINE") and not _src().contains("spine")
		and not _src().contains("_spine_bits"))

	# ── ⑪ ★소프트 게이트 ㉠(결정 6 — 이 한 줄로 T1 11인 전원 등재 완성) ────
	print("── ⑪ 소프트 게이트 ㉠ ──")
	_check("⑪a 로스터에 세레나가 등재돼 있다", m.CHORUS_GATE_ROSTER.has(KID))
	_check("⑪b ★T1 11인이 **전원** 등재됐다(§6.2 안전장치 ㉠ 완성) · 점주는 밖이다",
		_roster_has_all_t1(m) and m.CHORUS_GATE_ROSTER.size() == 11
		and not m.CHORUS_GATE_ROSTER.has("boatman")
		and not m.CHORUS_GATE_ROSTER.has("ongi")
		and not m.CHORUS_GATE_ROSTER.has("pulmu")
		and not m.CHORUS_GATE_ROSTER.has("mugol"))
	_check("⑪c ♡1·♡2는 언제나 게이트 밖(칸 자체가 대상이 아니다 — \"평평 ≠ 막힘\")",
		m._chorus_gate_ok(KID, 1) and m._chorus_gate_ok(KID, 2))
	_set_mains(m, 0)
	_check("⑪d ★메인 미접촉이면 ♡3 판정이 대기다(스포일러 순서)",
		not m._chorus_gate_ok(KID, m.CHORUS_GATE_HEART))
	m._heart_bits = {}
	_set_heart(r, 2)
	r.affinity.last_talk_day = 0
	var held: PackedStringArray = m._try_heart_promotion(r)
	_check("⑪e ★대기 = 점수 만충 유지 · 발화 0 · 진급 0 · 비트 0(deed 미달과 같은 대기)",
		held.is_empty() and r.affinity.hearts() == 2
		and r.affinity.points == Affinity.MAX_POINTS and not m._heart_bit_seen(KID, 3))
	# 메인 1인만 ♡3이어도 열린다(AND 아님 — OR 1인).
	_set_idle(m._resident("bana"), m.CHORUS_GATE_MAIN_STAGE)
	_check("⑪f 메인 1인만 ♡3이어도 판정이 통과다(OR — 조연이 메인 진행의 인질이 되지 않는다)",
		m._chorus_gate_ok(KID, m.CHORUS_GATE_HEART))
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_settle(m)
	_check("⑪g ★그 상태에서 ♡3 그날 밤 목격이 실제로 열린다(비트 기록 포함)",
		r.affinity.hearts() == 3 and m._heart_bit_seen(KID, 3)
		and m.dialogue.line() == String(who.heart_gate_lines(3)[0]))
	_drain(m)

	# ── ⑫ ★★개통 계약([ADR-0068] 결정 2) ──────────────────────────────────
	print("── ⑫ 조연 연애·결혼 전원 개통 ──")
	_check("⑫a 연애·배우자·이혼 훅이 전부 있다(본문 선행)",
		who.has_method("confession_lines") and who.has_method("divorce_lines")
		and who.has_method("spouse_lines")
		and who.confession_lines(true).size() >= 4
		and who.confession_lines(false).size() >= 4
		and who.divorce_lines().size() >= 3)
	_check("⑫b 수락·거절 본문이 서로 다르다",
		who.confession_lines(true) != who.confession_lines(false))
	# ★ 앞 여덟 스위트가 "아직 명단 밖"을 단언한 그 자리의 **반대편**이다.
	_check("⑫c ★★ROMANCE_OPEN = 메인 3 + T1 11 = 14인(앞 여덟 태스크가 약속한 그 명단 한 줄)",
		m.ROMANCE_OPEN.size() == 14 and _romance_open_has_all(m))
	_check("⑫d 점주 4인·옥자·주방요괴는 명단 밖이다(T1 티어가 아니다 · 옥자는 deed 단독 채널)",
		not m.ROMANCE_OPEN.has("boatman") and not m.ROMANCE_OPEN.has("ongi")
		and not m.ROMANCE_OPEN.has("pulmu") and not m.ROMANCE_OPEN.has("mugol")
		and not m.ROMANCE_OPEN.has("okja") and not m.ROMANCE_OPEN.has("kitchen_youkai"))
	# 모찌·네오 소급 — 훅이 실제로 붙었고, 결혼 후 대사가 일상 대사와 갈린다.
	var mochi_node: Node2D = m._resident("mochi").node
	var neo_node: Node2D = m._resident("neo").node
	_check("⑫e ★모찌·네오 소급 주입 — 4축 훅이 실제로 붙었다(비인간 결 유지)",
		mochi_node.has_method("confession_lines") and mochi_node.has_method("divorce_lines")
		and mochi_node.has_method("spouse_lines") and mochi_node.SPOUSE_AXES.size() == 4
		and neo_node.has_method("confession_lines") and neo_node.has_method("divorce_lines")
		and neo_node.has_method("spouse_lines") and neo_node.SPOUSE_AXES.size() == 4)
	_check("⑫f ★결혼 후 대사가 ♡5 일상 대사와 다르다(연인 tier와 배우자 tier의 공존 정리)",
		mochi_node.spouse_lines(1) != mochi_node.lines(5, true)
		and neo_node.spouse_lines(1) != neo_node.lines(5, true)
		and String(mochi_node.LINE_AGAIN_SPOUSE) != String(mochi_node.LINE_AGAIN_BOND)
		and String(neo_node.LINE_AGAIN_SPOUSE) != String(neo_node.LINE_AGAIN_BOND))
	# ★ 질투 — [ADR-0066] 결정 7 자구("안 뽑힌 **메인 2인**")를 개통이 안 넓혔는가.
	_check("⑫g ★★질투 명단이 갈라져 메인 3인으로 남았다(결정 7 자구 — 임의 확장 금지)",
		m.JEALOUSY_ROSTER.size() == 3 and m.JEALOUSY_ROSTER.has("miho")
		and m.JEALOUSY_ROSTER.has("mel") and m.JEALOUSY_ROSTER.has("bana")
		and m.ROMANCE_OPEN.size() != m.JEALOUSY_ROSTER.size())
	# 실동작 — 조연(세레나)과 연애를 개시해도 메인 3인이 한 점도 안 깎인다.
	_set_mains(m, 2)
	m._romance_partner = ""
	m._jealousy = {}
	var mains_before := []
	for mid in m.CHORUS_GATE_MAINS:
		mains_before.append(m._resident(String(mid)).affinity.points)
	_set_heart(r, Affinity.MAX_HEARTS - 1)
	_check("⑫h 조연도 ♡4 만충이면 고백 제안이 선다(개통의 실물)",
		m._romance_offer_available(r))
	# ★ 플레이어와 같은 경로로 간다 — 제안이 선 대화를 열고 그 자리에서 [F]를 결행한다
	#   (romance_test 선례. 대화가 안 열려 있으면 수락 발화를 잴 수 없다).
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_settle(m)
	_check("⑫h-2 대화 첫 줄이 고백 제안이다(제안 rid 세팅)",
		m.dialogue.is_open() and m.dialogue.line() == m.CONFESS_OFFER_LINE
		and m._confess_rid == KID)
	m._resolve_confession(KID)
	var mains_after := []
	for mid in m.CHORUS_GATE_MAINS:
		mains_after.append(m._resident(String(mid)).affinity.points)
	_check("⑫i ★조연 연애 개시 = 연인 성립 + **질투 0건**(뽑힌 자가 메인이 아니면 \"메인 2인\"이 없다)",
		m._romance_partner == KID and r.affinity.hearts() == Affinity.MAX_HEARTS
		and mains_after == mains_before and m._jealousy.is_empty())
	_check("⑫j 수락 발화가 캐릭터 본문이다(placeholder 아님)",
		m.dialogue.is_open()
		and m.dialogue.line() == String(who.confession_lines(true)[0])
		and m.dialogue.line() != m.CONFESS_ACCEPT_LINE)
	_drain(m)

	# ── ⑬ 비약 = 세레나 한정 구조([narrative-bible §5.3]) ───────────────────
	print("── ⑬ 뭍의 비약(구조) ──")
	# ★ 실동작 사슬(의뢰 → 청혼 게이트 → 소모)은 marriage_test가 소유한다. 여기서 재는 것은
	#   **범위**다 — 명단이 아니라 한 명이고, 옥자 트랙을 한 칸도 안 건드린다.
	_check("⑬a 비약이 필요한 사람은 **한 명**이다(명단이 아니라 rid 하나 — 과설계 금지)",
		String(m.ELIXIR_RID) == KID)
	_check("⑬b 아이템이 실존하고 이름이 쓰임을 따른다(KEYS = 비매·유니크·선물 불가)",
		ItemCatalog.has_item(ItemCatalog.OKJA_ELIXIR)
		and ItemCatalog.name_of(ItemCatalog.OKJA_ELIXIR) == "뭍의 비약"
		and not GiftPrefs.giftable(ItemCatalog.OKJA_ELIXIR))
	_check("⑬c 연애 전엔 의뢰가 안 열린다 · 세레나 연인 + 부적 보유 뒤에야 열린다(순서가 곧 안내)",
		_elixir_gate_order(m))
	_check("⑬d ★옥자 트랙 불가침 — 옥자는 여전히 관계 트랙이 없다(비약은 *서비스*다)",
		m._resident("okja").affinity == null)
	_check("⑬e ★척추 원장도 무접촉(비약이 B4~B7 비트를 한 칸도 안 건드린다)",
		m._spine_bits == 0)

	m.free()
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ serena_arc_test 전체 통과 ══")
	else:
		print("══ serena_arc_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)

# ── 금칙어(31어 — 조연 공통) ────────────────────────────────────────────────
# 앞 여덟 조연 스위트와 **같은 배열**이다(조연 파일마다 상속하는 그 목록).
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

# ── ★★무호명 축([narrative-bible §5.3] · [ADR-0068] 결정 6) ────────────────
# 공통 31어가 *특정 문장*을 막는다면 이쪽은 **이름 그 자체**를 막는다 — 세레나만 부를 동기가
# 본문에 내장돼 있기 때문이다(§5.3 "원흉을 보면 하악질" · 기다리던 사람 · 우물 위로 지나간 것).
# 축마다 이름이 붙어 있어 걸리면 어느 경계가 무너졌는지가 즉시 보인다.
# ⚠️ **세레나 자신의 이름은 넣지 않는다** — 지문("세레나가 …")이 정당한 쓰임이라서다
#    (gangrim_arc_test가 "강림"을 뺀 것과 같은 규약).
const NAME_AXES := {
	"⑩a 축① 옥자 무호명(중심 진실 4종이 전부 이 명명을 요구한다)": [
		"옥자", "마녀", "약사", "사장님",
	],
	"⑩b 축② 원흉 무호명(멜·바나 아크의 소유 — 하악질은 결로만 산다)": [
		"멜", "바나", "불을 낸", "문을 잠근", "습격한",
	],
	"⑩c 축③ 그 밤의 다른 조각 무호명(라쇼몽 구조 — 남의 조각을 대신 말하지 않는다)": [
		"미호", "깨비", "켄", "설화", "스칼렛", "미르", "루카", "프로스티", "모찌", "네오", "강림",
	],
}

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

# 암전이 **올라가는** 단계의 수(0 → 1.0 이면 1). 계단을 안 밟는 이 인물의 문법.
func _rising_fade_steps(steps: Array) -> int:
	var n := 0
	var cur := 0.0
	for s in steps:
		if typeof(s) != TYPE_DICTIONARY or String((s as Dictionary).get("verb", "")) != "fade":
			continue
		var to := float((s as Dictionary).get("to", 0.0))
		if to > cur:
			n += 1
		cur = to
	return n

# 그 컷신이 쓰는 카메라 **가로** 오프셋의 최대 절댓값(픽셀) — 물결의 기계 지표.
func _max_cam_x(steps: Array) -> float:
	var top := 0.0
	for s in steps:
		if typeof(s) != TYPE_DICTIONARY or String((s as Dictionary).get("verb", "")) != "cam":
			continue
		var off: Vector2 = (s as Dictionary).get("offset", Vector2.ZERO)
		top = maxf(top, absf(off.x))
	return top

# 세레나의 세 스테이션이 다른 주민 누구의 스케줄 칸과도 안 겹치는가.
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

# 그 집이 강변 주거인가 — 판정은 main의 RIVERSIDE_ZONE_Y가 소유한다(사본을 안 만든다).
func _house_is_riverside(m: Node, idx: int) -> bool:
	var rect: Rect2i = m.RESIDENT_HOUSE_RECTS[idx]
	return rect.position.y >= m.RIVERSIDE_ZONE_Y

# 그 집에 아무도 안 산다(어느 주민의 아침 자리도 그 문 아래 칸이 아니다).
func _house_free(m: Node, idx: int) -> bool:
	var want: Vector2i = m.RESIDENT_HOUSE_DOORS[idx] + Vector2i(0, 1)
	for res in m._residents:
		for e in res.schedule:
			if e.get("tile", Resident.UNPLACED) == want:
				return false
	return true

# 그 집을 쓰는 주민이 세레나 하나인가(1인 1채).
func _house_unique(m: Node, idx: int) -> bool:
	var want: Vector2i = m.RESIDENT_HOUSE_DOORS[idx] + Vector2i(0, 1)
	var n := 0
	for res in m._residents:
		for e in res.schedule:
			if e.get("tile", Resident.UNPLACED) == want:
				n += 1
				break
	return n == 1

# 아직 아무도 안 사는 집의 수(S9b-T6 뒤엔 강변 동 한 채만 남는다 — 네오 몫).
func _free_house_count(m: Node) -> int:
	var n := 0
	for i in m.RESIDENT_HOUSE_RECTS.size():
		if _house_free(m, i):
			n += 1
	return n

# 러브·헤이트 전량이 실존 아이템이고 건넬 수 있는가(선물 채널이 실제로 성립하는가).
func _prefs_valid() -> bool:
	for list in [GiftPrefs.loves(KID), GiftPrefs.hates(KID)]:
		for id in list:
			if not ItemCatalog.has_item(String(id)) or not GiftPrefs.giftable(String(id)):
				return false
	return true

# 러브에 어종이 하나도 없는가(낚시 도메인 무침범의 데이터 표현 — ①r).
func _loves_have_no_fish() -> bool:
	for id in GiftPrefs.loves(KID):
		if FishCatalog.ids().has(String(id)):
			return false
	return true

# 세레나 발신 편지 세 통이 전부 **끝줄에서 노래로 넘어가는가**(⑤c).
func _letters_end_in_song() -> bool:
	var n := 0
	for id in Mailbox.LETTERS:
		if String(Mailbox.LETTERS[id].get("from", "")) != NAME_KO:
			continue
		n += 1
		var body: Array = Mailbox.LETTERS[id].get("lines", []) as Array
		if body.is_empty():
			return false
		var last := String(body[body.size() - 1])
		if not (last.contains("소절") or last.contains("음 높이")):
			return false
	return n >= 2

# 소프트 게이트 로스터가 [narrative-bible] T1 11인을 전원 담고 있는가(⑪b).
func _roster_has_all_t1(m: Node) -> bool:
	for rid in ["mochi", "neo", "kkaebi", "ken", "seolhwa", "scarlet", "mir", "luca",
			"frosty", "gangrim", "serena"]:
		if not m.CHORUS_GATE_ROSTER.has(rid):
			return false
	return true

# 연애 개통 명단이 메인 3 + T1 11을 전원 담고 있는가(⑫c).
func _romance_open_has_all(m: Node) -> bool:
	for rid in ["miho", "mel", "bana",
			"mochi", "neo", "kkaebi", "ken", "seolhwa", "scarlet", "mir", "luca",
			"frosty", "gangrim", "serena"]:
		if not m.ROMANCE_OPEN.has(rid):
			return false
	return true

# 비약 의뢰의 **노출 순서**가 서는가(⑬c) — 연애 전 잠금 / 부적 미보유면 부적이 먼저 /
# 부적을 쥐고 나서야 비약. 상태를 직접 세우고 훅만 읽는다(구매는 marriage_test 소관).
func _elixir_gate_order(m: Node) -> bool:
	var saved_partner: String = m._romance_partner
	var ok := true
	m._romance_partner = ""
	if m._elixir_quest_open():
		ok = false                       # 연애 전엔 안 열린다
	m._romance_partner = "miho"
	if m._elixir_quest_open():
		ok = false                       # 상대가 세레나가 아니면 영영 안 열린다
	m._romance_partner = KID
	if m._elixir_quest_open():
		ok = false                       # 부적을 아직 안 받았으면 부적이 먼저다
	if not m._charm_quest_open():
		ok = false
	m.inventory.add_item(ItemCatalog.WEDDING_CHARM, 1)
	if not m._elixir_quest_open():
		ok = false                       # 부적을 쥐면 그때 열린다
	m.inventory.remove_item(ItemCatalog.WEDDING_CHARM, 1)
	m._romance_partner = saved_partner
	return ok

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
	for pack in _body_packs(who):
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

# 캐릭터가 소유한 본문 묶음 전량(볼륨·금칙어 스캔의 공통 입력).
func _body_packs(who: Node2D) -> Array:
	var out: Array = [who.LINES_INTRO, who.LINES_WARMING, who.LINES_CLOSE, who.LINES_LOVER,
		who.GATE_HEART_1, who.GATE_HEART_2, who.GATE_HEART_3, who.GATE_HEART_4,
		who.CONFESSION_ACCEPT, who.CONFESSION_REJECT, who.DIVORCE_FAREWELL, who.BIRTHDAY]
	for ax in who.SPOUSE_AXES:
		out.append(ax)
	return out

# 세레나 발신 편지의 모든 줄(금칙어·무호명 스캔에 합류 — 편지도 캐릭터의 몫이다).
func _letter_lines() -> Array:
	var out: Array = []
	for id in Mailbox.LETTERS:
		if String(Mailbox.LETTERS[id].get("from", "")) == NAME_KO:
			out.append_array(Mailbox.LETTERS[id].get("lines", []) as Array)
	return out

# ★ 스캔 대상 전량 = 대사 본문 + LINE_AGAIN 3종 + 절기 물음(문항·반응) + 세레나 발신 편지.
#   선택지(options)는 **플레이어의 말**이라 대상 밖이다(gangrim_arc_test와 같은 경계).
func _corpus(who: Node2D) -> String:
	var all: Array = []
	for pack in _body_packs(who):
		all.append_array(pack as Array)
	all.append(who.LINE_AGAIN)
	all.append(who.LINE_AGAIN_LOVER)
	all.append(who.LINE_AGAIN_SPOUSE)
	for q in who.SEASON_QUESTIONS:
		all.append(q["line"])
		all.append_array(q["replies"] as Array)
	all.append_array(_letter_lines())
	return "\n".join(PackedStringArray(all))

# 전 본문에서 금칙어를 찾는다(걸린 줄을 돌려준다 — 없으면 "").
func _scan_forbidden(who: Node2D, words: Array) -> String:
	var all: Array = []
	for pack in _body_packs(who):
		all.append_array(pack as Array)
	for q in who.SEASON_QUESTIONS:
		all.append(q["line"])
		all.append_array(q["replies"] as Array)
	all.append_array(_letter_lines())
	for ln in all:
		for w in words:
			if String(ln).contains(String(w)):
				return String(ln)
	return ""

# 한 덩이 문자열에서 금칙어를 찾는다(무호명 축 가드용 — 걸린 낱말을 돌려준다).
func _scan_words(text: String, words: Array) -> String:
	for w in words:
		if text.contains(String(w)):
			return String(w)
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
