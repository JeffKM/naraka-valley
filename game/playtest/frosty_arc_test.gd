extends SceneTree
# ★[S9b-T4 / ADR-0068 결정 3·5·6·7·12] 프로스티 풀 온보딩 + 척추 B4 — 헤드리스 검증.
#
# 규약은 kkaebi/ken/seolhwa/scarlet/mir/luca_arc_test를 그대로 상속한다(금칙어 31어 가드·볼륨
# 측정·훅 존재·관문 드레인·절기 물음·생일·편지). 프로스티 고유분은 ⑨(말 못함 + 비인간 본질 비밀
# 경계)와 **⑫(척추 B4 · `_spine_bits`)**이고, ⑫가 이 스위트가 다른 여섯과 갈리는 자리다.
#
# 무엇을 보증하나:
#   ① 인물 층 배선 — 레코드 1건이 실제로 등록되고(id·표시명·세이브 키·선물 채널·집/스케줄),
#      세 스테이션이 서로 다르며 다른 주민 자리와 겹치지 않는다(칸 충돌 = 마주보기 판정 파손).
#      집은 **동편 주거 중 가장 남쪽**(index 7)이고 강변 2채(세레나 예약)를 안 쓴다.
#   ② 일상 대사 **4단** 분기(♡0/♡1+/♡3+/♡5+) — 단 경계가 관문 경계와 맞고, 단 안에서는 같은
#      묶음이며, 오늘 두 번째 대화는 하트에 따라 온도만 다른 한 줄이다.
#   ③ 관문 발화 **♡1~4 네 칸 전부** 캐릭터 본문이다(placeholder 폴백 0 — 조연 4단 아크).
#   ④ 컷신 — 4동사 안이고(거절 0) 칸마다 하나이며 **npc 동사 0**(세 구역-자리를 도는 인물이라
#      순간이동 위험을 구조적으로 없앤다 — 깨비·스칼렛·루카 선례), 재생이 끝나면 관문 발화가
#      맨 앞에 선 대화가 열린다.
#   ⑤ 여진 편지 — ♡2·♡3·♡4가 각기 실존하는 편지를 지목하고(♡1은 없음) 발신인이 프로스티이며,
#      관문 성사가 큐에 넣고 다음 날 아침 도착한다.
#   ⑥ 절기 물음 4개 — 짝이 맞고, 주 첫날 첫 대화에 서며, **0점 계약**(선택 전후 점수·stage 불변).
#   ⑦ 생일 — 훅 본문 + Resident.BIRTHDAYS 배정(성야절 28일 = 한 해의 마지막 날) + main 경로가 물림.
#   ⑧ 볼륨([ADR-0068] 결정 5) — **상한만 계약**이다(아래 ⑧a 주석). 컷신 4 · 절기 4 · 편지 ≤3 ·
#      **spouse 4축**.
#   ⑨ ★**말 못함** + 봉인 법칙([ADR-0068] 결정 6):
#      ㉠ 캐릭터 본문 **전 줄이 지문 아니면 의성어**다(따옴표 대사 0 — 이 인물의 정의)
#      ㉡ 편지 세 통에도 「」로 묶인 문장이 0이다(말도 글도 못 한다)
#      ㉢ ♡3은 **보여 주는 데서 끝난다**(자국 · 빈 가슴) — 명명 0
#      ㉣ 중심 진실 4금지 근처에도 안 간다(옥자·봉인·기억 0 · "그러니까" 0)
#      ㉤ 그날 밤을 말하지 않는다(현장에 없던 존재 — 화재·약방 0)
#      ㉥ ♡4는 **본성의 대가**까지만(비인간이라 생전 죄가 없다 — "죄" 0)
#      ㉦ Affinity를 모른다 ㉧ 추위·설산을 메카닉으로 안 쓴다
#   ⑩ 소프트 게이트 ㉠(결정 6) — 이번엔 **단독 태스크라 로스터 등재도 이 태스크가 했다**.
#      그래서 T1~T3과 달리 "미접촉이면 대기"까지 여기서 전부 잰다.
#   ⑪ 개통 계약 — confession/divorce/spouse 훅이 먼저 서 있었고, **S9b-T6이
#      main `ROMANCE_OPEN`에 프로스티를 넣어 열었다**(콘텐츠 재작업 0).
#   ⑫ ★**척추 B4 + `_spine_bits`**([ADR-0068] 결정 7) — 트리거가 결정적이고(프로스티 ♡3 완료
#      없이는 미발동 · 취침 1회 후 아침 정확히 1회), 중복 발화가 0이며, 세이브 왕복에 원장이
#      보존되고, **B4를 frosty.gd가 소유하지 않는다**(아크와 척추의 소유 분리).
#
# 실행: ./run_tests.sh frosty_arc   (헤드리스는 반드시 game/에서 · 순차)

const KID := "frosty"
const NAME_KO := "프로스티"
const HOUSE_IDX := 7        # 주민 집 8(RESIDENT_HOUSE_RECTS[7] — 동편 주거 중 가장 남쪽)

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
	print("══ S9b-T4 프로스티 풀 온보딩 + 척추 B4 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_drain(m)                                   # 신규 시작의 옥자 통보 대화
	m.onboarding.step = Onboarding.DONE
	m.clock.day = 3                             # 주 첫날 아님(절기 물음은 ⑥에서 따로 켠다)
	_set_mains(m, m.CHORUS_GATE_MAIN_STAGE)     # ★소프트 게이트 ㉠ 선주입(⑩에서 닫았다 다시 연다)

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
		and r.save_key == "frosty_affinity" and r.affinity != null and r.can_gift)
	_check("①c 곱셈기 없음(조연 = 쉼터 2채널 — ADR-0008 메인 4인 독점)",
		not r.effect_fn.is_valid())
	# ★[S9b-T9] **초상 미생성 확정** — 시트는 붙었지만 초상은 안 만든다(미이행이 아니라 결정이다).
	#   `character_to_portrait`가 비인간 재질을 사람 피부로 되돌리는 모델 한계(§15.6 옹이 2판 실패)
	#   때문이고, 한 장이 25 gen이다. owner-Gemini 2×3 표정 그리드 큐 1순위로 넘겼다.
	_check("①d 초상화 미생성 확정(비인간 재질 → Gemini 큐 · S9b-T9)", r.portrait_stem == "")
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
	_check("①h 낮 자리가 광장 안이다(통행 레인에서 비켜난 남서 어귀)",
		m.NARU_PLAZA_RECT.has_point(r.schedule[1]["tile"]))
	_check("①i 집 8은 동편 주거다(강변 2채 = 세레나 예약분을 안 쓴다)", _house_is_east(m, HOUSE_IDX))
	_check("①j ★동편 8채 중 가장 남쪽 집이다(마을 맨 끝자락 = 지나쳐 온 자리)",
		_is_southmost_east_house(m, HOUSE_IDX))
	_check("①k 앞 일곱 사람과 다른 집이다(1인 1채)",
		house_door != m.RESIDENT_HOUSE_DOORS[0] and house_door != m.RESIDENT_HOUSE_DOORS[1]
		and house_door != m.RESIDENT_HOUSE_DOORS[2] and house_door != m.RESIDENT_HOUSE_DOORS[3]
		and house_door != m.RESIDENT_HOUSE_DOORS[5] and house_door != m.RESIDENT_HOUSE_DOORS[6]
		and house_door != m.RESIDENT_HOUSE_DOORS[8])
	# ★[S9b-T6 갱신 — 이월 부채 소거] 이 단언은 T4가 쓸 때 "index 4는 **강림 몫으로 비워 둔다**"의
	#   기계 표현이었는데, **S9b-T5가 실제로 그 집을 채우면서 stale이 됐다**(T5의 선별 회귀 목록에
	#   frosty_arc가 없어 그때 안 걸렸다 — S9b-T3의 ⑧a 누락과 같은 종류의 이월이다).
	#   요지를 살려 방향을 뒤집는다: **예약이 실제로 이행됐는가**를 재고, 덤으로 T6이 로스터를
	#   닫았다는 사실(남은 빈집 한 채 = 강변 동, 네오 몫)까지 한 줄로 못 박는다.
	_check("①l ★T4가 예약한 index 4를 T5가 실제로 채웠다(강림) · 이제 빈집은 강변 동 한 채뿐",
		not _house_free(m, 4)
		and m._resident("gangrim") != null
		and m._resident("gangrim").schedule[0]["tile"] == m.RESIDENT_HOUSE_DOORS[4] + Vector2i(0, 1)
		and _house_free(m, 10) and not _house_free(m, 9))
	# 선호 선물 — 러브/헤이트가 실존 아이템이고 전부 건넬 수 있어야 한다.
	_check("①m 선호 선물 테이블(러브 5 · 헤이트 1 · 전부 실존·건넬 수 있음)",
		GiftPrefs.loves(KID).size() == 5 and GiftPrefs.hates(KID).size() == 1
		and _prefs_valid())
	_check("①n ★혼불씨 헤이트(털에 옮겨붙는 것 — 유니버설 원자재 계층을 덮는다)",
		GiftPrefs.tier_of(KID, ItemCatalog.HONBULSSI) == GiftPrefs.HATE
		and GiftPrefs.universal_tier(ItemCatalog.HONBULSSI) != GiftPrefs.HATE)
	_check("①o ★넋 데운 우유가 설화의 헤이트이자 프로스티의 러브다(같은 잔이 정반대 의미)",
		GiftPrefs.tier_of(KID, MenuCatalog.HOT_MILK) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("seolhwa", MenuCatalog.HOT_MILK) == GiftPrefs.HATE)
	_check("①p 영혼 호박은 유니버설 수확물(뉴트럴)에서 러브로 올라간다(안아 오기 좋은 것)",
		GiftPrefs.tier_of(KID, CropCatalog.YEONGHON_HOBAK) == GiftPrefs.LOVE
		and GiftPrefs.universal_tier(CropCatalog.YEONGHON_HOBAK) == GiftPrefs.NEUTRAL)
	_check("①q ★러브에 광물·보석이 하나도 없다(값나가는 것을 고를 줄 모르는 존재)",
		_no_mineral_loves())

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
	_check("③c ♡3이 가장 길다(본질 비밀 = 필수 세트피스)",
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
	_check("⑤b 세 통 다 발신인이 프로스티다", sender_ok)
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
	_check("⑦b 생일 배정이 살아 있다(성야절 28일 = 한 해의 마지막 날)",
		b.size() == 2 and int(b[0]) == 3 and int(b[1]) == GameClock.DAYS_PER_SEASON)
	var bday_day := _find_birthday_day(KID)
	_check("⑦c 그 날짜가 실제로 이 사람 생일로 판정된다",
		bday_day > 0 and r.is_birthday_on(bday_day))
	_check("⑦d 그 날에 생일인 사람이 프로스티 하나다(달력 무충돌)",
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
	# ★ 하한 100은 **이 인물에 한해 면제**다(frosty.gd 머리말): 말을 못 하는 인물이라 발화가 지문·
	#   의성어뿐이고, 지문을 늘려 하한을 채우면 말 못 하는 인물이 곧장 수다스러워진다. 계약은
	#   **상한**이고, 아래 60줄은 "본문이 통째로 비지 않았나"의 방어선이지 목표치가 아니다.
	_check("⑧a 대사 볼륨이 상한 안(≤150 — 결정 5. 하한 100은 말 못함으로 면제)",
		total <= 150 and total >= 60)
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

	# ── ⑨ 말 못함 + 봉인 법칙([ADR-0068] 결정 6) ──────────────────────────
	print("── ⑨ 말 못함 · 봉인 법칙 ──")
	# 기존 아크 스위트(미호·멜·바나·T1 2인·깨비·켄·설화·스칼렛·미르·루카)의 금칙어 **31어를
	# 그대로 상속**한다. 검열이 아니라 회귀 가드다 — 나중 손질이 평결 문장을 흘려 넣으면 걸린다.
	var offender := _scan_forbidden(who, FORBIDDEN)
	_check("⑨a 금칙어 %d어 스캔 0(본문 + 편지 전량)" % FORBIDDEN.size(), offender == "")
	if offender != "":
		print("      ↳ 걸린 줄: " + offender)
	# ★ 이 스위트의 고유 가드 — **캐릭터 본문 전 줄이 지문 아니면 의성어**다. 태그를 뗀 첫 글자가
	#   "(" (지문) 또는 "…" (숨소리)여야 한다. 이 한 줄이 "프로스티는 말을 못 한다"의 기계 정의다.
	var talker := _scan_speech(who)
	_check("⑨b ★말하는 줄 0(전 줄이 지문 아니면 의성어 — 이 인물의 정의)", talker == "")
	if talker != "":
		print("      ↳ 말한 줄: " + talker)
	_check("⑨c ★편지 세 통에도 「」로 묶인 문장이 0이다(말도 글도 못 한다)",
		_letters_have_no_quotes())
	var g3 := _joined(who.GATE_HEART_3)
	_check("⑨d ♡3은 **보여 주는 데서 끝난다**(눈 위의 자국 + 텅 빈 가슴)",
		g3.contains("자국") and g3.contains("비어 있다"))
	_check("⑨e ★중심 진실 4금지 근처에도 안 간다(옥자·봉인·기억 0 · 결론을 안 내린다)",
		not g3.contains("옥자") and not g3.contains("봉인") and not g3.contains("기억")
		and not g3.contains("그러니까"))
	_check("⑨f ★그날 밤을 말하지 않는다(현장에 없던 존재 — 다른 조연의 조각을 안 침범한다)",
		not g3.contains("화재") and not g3.contains("약방") and not g3.contains("그날 밤"))
	var g4 := _joined(who.GATE_HEART_4)
	_check("⑨g ♡4는 **본성의 대가**까지만이다(비인간이라 생전 죄가 없다 — \"죄\" 0)",
		g4.contains("옮겨 담") and not g4.contains("죄"))
	_check("⑨h ♡4가 플레이어의 죄를 겨누지 않는다(메인 3인 조각의 독점 영역)",
		not g4.contains("네 죄") and not g4.contains("네가 지은"))
	# ★[폴리시 R15] 비어 있음 가드 — 아래 `_src()` 단언은 전부 부정형이라 파일을 못 열면(`KID`와
	#   파일명이 어긋나면) `not "".contains(x)`가 모조리 참이 되어 검사가 죽은 채 초록이 된다
	#   (⑫b의 척추 소유 분리 단언까지 같은 배를 탄다 — luck_forecast_test ⑦a 관례).
	_check("⑨i-pre %s.gd를 실제로 읽었다(부정 단언이 공허하지 않다 — 주석 제외 %d자)"
			% [KID, _src().length()],
		FileAccess.file_exists("res://%s.gd" % KID) and _src().length() > 2000
		and _src().contains("func "))
	_check("⑨i 본문은 Affinity를 모른다(0점 계약의 구조적 근거)",
		not _src().contains("Affinity") and not _src().contains("add_points"))
	_check("⑨j 추위·설산을 메카닉으로 쓰지 않는다(백스토리 한정 — effect_fn 0 · 회복 어휘 0)",
		not r.effect_fn.is_valid() and not _src().contains("effect_fn")
		and not _src().contains("energy") and not _src().contains("health"))

	# ── ⑩ ★소프트 게이트 ㉠(결정 6 — 등재도 이 태스크가 했다) ──────────────
	print("── ⑩ 소프트 게이트 ㉠ ──")
	_check("⑩a 로스터에 프로스티가 등재돼 있다(비인간 ♡3 = 본질 비밀에도 게이트가 걸린다)",
		m.CHORUS_GATE_ROSTER.has(KID))
	_check("⑩b ♡1·♡2는 언제나 게이트 밖(칸 자체가 대상이 아니다 — \"평평 ≠ 막힘\")",
		m._chorus_gate_ok(KID, 1) and m._chorus_gate_ok(KID, 2))
	_set_mains(m, 0)
	_check("⑩c ★메인 미접촉이면 ♡3 판정이 대기다(스포일러 순서)",
		not m._chorus_gate_ok(KID, m.CHORUS_GATE_HEART))
	m._heart_bits = {}
	_set_heart(r, 2)
	r.affinity.last_talk_day = 0
	var held: PackedStringArray = m._try_heart_promotion(r)
	_check("⑩d ★대기 = 점수 만충 유지 · 발화 0 · 진급 0 · 비트 0(deed 미달과 같은 대기)",
		held.is_empty() and r.affinity.hearts() == 2
		and r.affinity.points == Affinity.MAX_POINTS and not m._heart_bit_seen(KID, 3))
	# 메인 1인만 ♡3이어도 열린다(AND 아님 — OR 1인).
	_set_idle(m._resident("bana"), m.CHORUS_GATE_MAIN_STAGE)
	_check("⑩e 메인 1인만 ♡3이어도 판정이 통과다(OR — 조연이 메인 진행의 인질이 되지 않는다)",
		m._chorus_gate_ok(KID, m.CHORUS_GATE_HEART))
	r.affinity.last_talk_day = 0
	m._start_resident_dialogue(r)
	_settle(m)
	_check("⑩f ★그 상태에서 ♡3 본질 비밀이 실제로 열린다(비트 기록 포함)",
		r.affinity.hearts() == 3 and m._heart_bit_seen(KID, 3)
		and m.dialogue.line() == String(who.heart_gate_lines(3)[0]))
	_drain(m)

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
	_check("⑪c ★[S9b-T6 개통 반영] main ROMANCE_OPEN에 **들어왔다** — 본문 재작업 0으로 열렸다(훅이 먼저·명단이 나중이라는 그 계약의 실물)",
		m.ROMANCE_OPEN.has(KID))

	# ── ⑫ ★척추 B4 + `_spine_bits`([ADR-0068] 결정 7) ─────────────────────
	print("── ⑫ 척추 B4 · _spine_bits ──")
	# 데이터 층 먼저(재생 없이 잴 수 있는 것).
	_check("⑫a B4 컷신이 4동사 안이고 **npc 동사 0**이다(플레이어 단독 — 결정 7)",
		CutsceneRunner.new(m.SPINE_B4_CUTSCENE).rejected_verbs().is_empty()
		and not _has_verb(m.SPINE_B4_CUTSCENE, "npc")
		and _max_fade(m.SPINE_B4_CUTSCENE) >= 1.0)
	_check("⑫b ★B4를 frosty.gd가 소유하지 않는다(아크와 척추의 소유 분리 — 결정 7)",
		not _src().contains("SPINE_B4") and not _src().contains("spine"))
	_check("⑫c ★B4 본문이 프로스티를 호명하지 않는다(호명하면 관문의 꼬리가 된다)",
		not _joined(m.SPINE_B4_LINES).contains(NAME_KO)
		and _scan_words(_joined(m.SPINE_B4_LINES), FORBIDDEN) == "")
	_check("⑫d 비트 번호 = 비트 이름(B4~B7 = 4~7) · 마스크가 그 넷뿐",
		m.SPINE_B4 == 4 and m.SPINE_B7 == 7
		and m.SPINE_BITS_MASK == (1 << 4 | 1 << 5 | 1 << 6 | 1 << 7))
	# 판을 비우고 트리거를 태운다.
	m._spine_bits = 0
	m._spine_b4_armed = false
	m._heart_bits = {}
	m.clock.day = 100                            # 성야절 — 이후 세 아침이 같은 절기라 지면 재빌드 1회
	_check("⑫e 시작은 아무 비트도 안 선 상태다", not m._spine_bit_seen(m.SPINE_B4))
	# ㉠ 프로스티 ♡3 없이 아침 → 미발동.
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)
	m._on_sleep_done()
	_check("⑫f ★♡3 완료 없이는 미발동(예약 0 · 비트 0 · 컷신 0)",
		not m._spine_b4_armed and not m._spine_bit_seen(m.SPINE_B4) and m.cutscene == null)
	# ㉡ ♡3 비트를 세우고 하루를 넘긴다 — 아침 훅은 **예약만** 한다(재생은 취침 연출이 끝나는 프레임).
	m._mark_heart_bit(KID, 3)
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)
	_check("⑫g ★아침 훅이 예약한다(아직 재생 0 · 비트 0 — 취침 연출 한가운데라 안 튼다)",
		m._spine_b4_armed and m.cutscene == null and not m._spine_bit_seen(m.SPINE_B4))
	m._on_sleep_done()
	_check("⑫h ★취침 1회 후 아침에 정확히 1회 발동(재생 중 · 비트 기록 · 예약 소진)",
		m.cutscene != null and m._spine_bit_seen(m.SPINE_B4) and not m._spine_b4_armed)
	_settle(m)
	_check("⑫i 재생이 끝나면 **화자 없는** 내면 대화가 열린다(이름판 공백 = 내면엔 이름이 없다)",
		m.cutscene == null and m.dialogue.is_open() and m.dialogue.speaker() == ""
		and m.dialogue.line() == String(m.SPINE_B4_LINES[0]))
	_drain(m)
	_check("⑫j 화면·시계 원복(암전 잔류 0)",
		is_equal_approx(m.fade.modulate.a, 0.0) and m.clock.running
		and m._cam.offset.is_equal_approx(Vector2.ZERO))
	# ㉢ 다음 아침 — 재발동 0.
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)
	m._on_sleep_done()
	_check("⑫k ★중복 발화 0(다음 아침엔 예약도 재생도 안 선다)",
		not m._spine_b4_armed and m.cutscene == null and not m.dialogue.is_open())
	_check("⑫l 다른 척추 비트(B5~B7)는 여전히 0이다(B4만 열렸다)",
		m._spine_bits == (1 << m.SPINE_B4))
	# ㉣ 세이브 왕복.
	var bits_before: int = m._spine_bits
	m._save_game()
	m.free()
	var m2: Node = await _new_main()             # _ready가 자동 복원
	_drain(m2)
	_check("⑫m ★세이브 왕복에 `_spine_bits`가 보존된다(가법 키 1개 — 결정 7)",
		m2._spine_bits == bits_before and m2._spine_bit_seen(m2.SPINE_B4))
	_check("⑫n 로드 직후 예약은 언제나 0이다(예약은 취침 사슬 한정 — 세이브 대상 아님)",
		not m2._spine_b4_armed)
	_check("⑫o 복원된 원장으로 아침을 맞아도 재발동 0(비트가 유일한 방어선)",
		_no_refire(m2))
	m2.free()

	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ frosty_arc_test 전체 통과 ══")
	else:
		print("══ frosty_arc_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)

# ── 금칙어(31어) ────────────────────────────────────────────────────────────
# 앞 여섯 조연 스위트와 **같은 배열**이다(조연 파일마다 상속하는 그 목록).
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

# 프로스티의 세 스테이션이 다른 주민 누구의 스케줄 칸과도 안 겹치는가.
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

# 그 집이 동편 주거 8채 중 **가장 남쪽**(y가 가장 큰 집)인가.
func _is_southmost_east_house(m: Node, idx: int) -> bool:
	var mine: int = (m.RESIDENT_HOUSE_RECTS[idx] as Rect2i).position.y
	for i in m.RESIDENT_HOUSE_RECTS.size():
		if not _house_is_east(m, i):
			continue
		if (m.RESIDENT_HOUSE_RECTS[i] as Rect2i).position.y > mine:
			return false
	return true

# 그 집에 아무도 안 산다(어느 주민의 아침 자리도 그 문 아래 칸이 아니다).
func _house_free(m: Node, idx: int) -> bool:
	var want: Vector2i = m.RESIDENT_HOUSE_DOORS[idx] + Vector2i(0, 1)
	for res in m._residents:
		for e in res.schedule:
			if e.get("tile", Resident.UNPLACED) == want:
				return false
	return true

# 러브·헤이트 전량이 실존 아이템이고 건넬 수 있는가(선물 채널이 실제로 성립하는가).
func _prefs_valid() -> bool:
	for list in [GiftPrefs.loves(KID), GiftPrefs.hates(KID)]:
		for id in list:
			if not ItemCatalog.has_item(String(id)) or not GiftPrefs.giftable(String(id)):
				return false
	return true

# 러브 중에 광물·보석이 하나도 없는가(값나가는 것을 고를 줄 모르는 존재).
func _no_mineral_loves() -> bool:
	for id in GiftPrefs.loves(KID):
		if ItemCatalog.MINERALS.has(String(id)):
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

# 캐릭터가 소유한 본문 묶음 전량(볼륨·금칙어·말 못함 스캔의 공통 입력).
func _body_packs(who: Node2D) -> Array:
	var out: Array = [who.LINES_INTRO, who.LINES_WARMING, who.LINES_CLOSE, who.LINES_LOVER,
		who.GATE_HEART_1, who.GATE_HEART_2, who.GATE_HEART_3, who.GATE_HEART_4,
		who.CONFESSION_ACCEPT, who.CONFESSION_REJECT, who.DIVORCE_FAREWELL, who.BIRTHDAY]
	for ax in who.SPOUSE_AXES:
		out.append(ax)
	return out

# 프로스티 발신 편지의 모든 줄(금칙어 스캔에 합류 — 편지도 캐릭터의 몫이다).
func _letter_lines() -> Array:
	var out: Array = []
	for id in Mailbox.LETTERS:
		if String(Mailbox.LETTERS[id].get("from", "")) == NAME_KO:
			out.append_array(Mailbox.LETTERS[id].get("lines", []) as Array)
	return out

# 프로스티 발신 편지에 「」로 묶인 문장이 하나도 없는가(말도 글도 못 한다 — ⑨c).
func _letters_have_no_quotes() -> bool:
	var lines := _letter_lines()
	if lines.is_empty():
		return false      # 편지가 아예 없으면 이 계약은 잰 것이 없다
	for ln in lines:
		if String(ln).contains("「") or String(ln).contains("\""):
			return false
	return true

# 표정 태그를 뗀 본문(줄 맨 앞 [smile]/[shy]/[sad]/[surprised]/[talk] — main._render_dialogue 규약).
func _strip_tag(line: String) -> String:
	if line.begins_with("["):
		var close := line.find("]")
		if close > 1:
			return line.substr(close + 1).strip_edges()
	return line.strip_edges()

# ★ 말 못함 가드 — 태그를 뗀 첫 글자가 "(" (지문)도 "…" (숨소리)도 아닌 줄을 찾는다.
# 걸린 줄을 돌려주고, 전 줄이 규약 안이면 ""를 돌려준다.
func _scan_speech(who: Node2D) -> String:
	var all: Array = []
	for pack in _body_packs(who):
		all.append_array(pack as Array)
	all.append(who.LINE_AGAIN)
	all.append(who.LINE_AGAIN_LOVER)
	all.append(who.LINE_AGAIN_SPOUSE)
	for q in who.SEASON_QUESTIONS:
		all.append(q["line"])
		all.append_array(q["replies"] as Array)   # ★선택지(options)는 플레이어의 말이라 대상 밖
	for ln in all:
		var body := _strip_tag(String(ln))
		if not (body.begins_with("(") or body.begins_with("…")):
			return String(ln)
	return ""

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

# 한 덩이 문자열에서 금칙어를 찾는다(B4 본문 검사용 — 걸린 낱말을 돌려준다).
func _scan_words(text: String, words: Array) -> String:
	for w in words:
		if text.contains(String(w)):
			return String(w)
	return ""

# 복원된 세이브로 아침을 한 번 더 맞아도 B4가 다시 안 서는가(⑫o).
func _no_refire(m: Node) -> bool:
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)
	m._on_sleep_done()
	return not m._spine_b4_armed and m.cutscene == null

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
