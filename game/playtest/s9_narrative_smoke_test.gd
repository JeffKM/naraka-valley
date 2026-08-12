extends SceneTree
# ★[S9-T10] 서사 장기 스모크 — Slice 9 전 사슬(관문 컷신 · 여진 편지 · 절기 물음 · Books ·
# 아크 성립 · 세이브 왕복)을 **한 세이브에서 결정적으로** 한 번에 굴린다.
#
# 무엇을 보증하나(이음매 전용 — 개별 기능의 상세 단언은 각 스위트가 소유한다):
#   ① 메인 3인(미호·멜·바나)의 ♡1~4 관문이 **컷신 → 대화** 순서로 재생된다 — 대화보다 컷신이
#      먼저 서고, 재생이 끝나면 그 캐릭터의 **본문**(placeholder 폴백 아님)이 맨 앞에 선 대화가
#      열린다. 세 사람 것이 한 판에서 연달아 굴러도 서로를 밀어내지 않는다.
#   ② 관문 여진 편지 — 열두 번의 관문이 열두 통을 큐에 넣고(같은 날 도착 0), **다음 날 아침**
#      한꺼번에 도착하며, 열람이 곧 기독이다(heart_gate_letter 매핑의 실동작).
#   ③ 절기 물음 — T9이 개통한 T1 2인(모찌·네오)까지 포함해, 주 첫날 첫 대화에 물음이 서고
#      선택 전후 **점수·stage가 불변**이며(0점 계약) 같은 주엔 다시 안 묻는다.
#   ④ Books — 결정적 롤 재현으로 실제 입수(즉독까지) + 책·노트 혼합 수집 → 혼백관 기증(책만) →
#      책장 재읽기(미독 우선) → 수집 트래커. 네 층이 한 원장 위에서 이어진다.
#   ⑤ 아크 성립 — 세 사람 모두 ♡1~4 비트가 서면 B1~B3 세 조각이 성립한다(비트 원장 판정).
#   ⑥ 세이브 왕복 — 비트·절기 물음·Books·우편함 원장이 전부 부팅을 건넌다.
#
# ★ 관례(기존 아크 스위트와 동형이므로 어기지 말 것):
#   · 하트 세팅은 points·stage **동반**이다(S8 이후 hearts()=stage). 만충 = `_set_heart`,
#     "아무 사건도 없는 칸" = `_set_idle`(points = stage × POINTS_PER_HEART).
#   · 드레인 헬퍼는 **컷신 재생 + 선택지 `has_choice → choose(0)`**를 동반한다 — 절기 물음
#     선택지는 넘기기로 못 지나가고, 관문 컷신이 서 있으면 대화가 아예 안 열린다.
#
# 실행: TIMEOUT=300 ./run_tests.sh s9_narrative_smoke   (헤드리스는 반드시 game/에서 · 순차)

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

# 컷신이 서 있으면 끝까지 재생한다(대화는 안 닫는다 — 뒤따르는 첫 줄을 재야 한다).
func _settle(m: Node) -> void:
	var guard := 0
	while m.cutscene != null and guard < 200:
		m._tick_cutscene(0.1)
		guard += 1

# 판을 비운다 — 컷신 재생 → 선택지는 첫 항 → 나머지는 넘기기(플레이어와 같은 경로).
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

# 그 칸에 **얌전히** 앉힌다 — 점수가 딱 그 칸까지라 진급 대기도 고백 제안도 서지 않는다.
func _set_idle(r: Resident, stage: int) -> void:
	r.affinity.stage = stage
	r.affinity.points = stage * Affinity.POINTS_PER_HEART

func _pass_day(m: Node) -> void:
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)

# 메인 3인의 deed 원장을 전 칸 충족으로 세운다(deed는 이 스위트의 관심사가 아니다 —
# 각 아크 스위트가 문턱을 따로 잰다. 여기서는 관문이 *열린다*는 사실만 필요하다).
func _stock_deeds(m: Node) -> void:
	m._run_harvested = 100000          # 미호 = 누적 수확(문턱 30/80/160/300)
	m._cafe_revenue_total = 100000     # 멜 = 누적 서빙 매출(500/1500/3500/7000)
	m.mine_floors._depth = 60          # 바나 ♡1 = 갱도 10층
	m._combat_xp = 999                 # 바나 ♡2 = 전투 XP 200
	m._narak_key_found = true          # 바나 ♡3 = 나락 개방
	m._narak_best_boss = 50            # 바나 ♡4 = 보스 격파 깊이 ≥10

# 그 사람의 ♡1..♡4 관문 비트가 전부 섰는가(아크 판정의 재료).
func _arc_bits_set(m: Node, rid: String) -> bool:
	for h in range(1, m.HEART_GATE_MAX + 1):
		if not m._heart_bit_seen(rid, h):
			return false
	return true

# from 이후로 **주 첫날**이면서 그 사람 생일이 아닌 첫 날(전부 day 파생이라 결정적이다).
func _next_week_first(r: Resident, from: int) -> int:
	var d: int = from
	while true:
		if (d - 1) % GameClock.DAYS_PER_WEEK == 0 and not r.is_birthday_on(d):
			return d
		d += 1
	return from

# 지금 열린 대화에 그 절기 물음이 실려 있는가(miho_arc_test 헬퍼 동형).
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

# 그 원천에서 드랍이 걸리는 첫 serial(없으면 -1 — books_test 헬퍼 동형).
func _find_hit(m: Node, source: String, day: int) -> int:
	for s in 4000:
		if m.books.pending_drop(source, day, s) != "":
			return s
	return -1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S9-T10 서사 장기 스모크 — 관문 컷신·편지·절기 물음·Books·아크 성립 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_drain(m)                                   # 신규 시작의 옥자 통보 대화
	m.onboarding.step = Onboarding.DONE
	m.clock.day = 3                             # 주 첫날 아님(절기 물음은 ③에서 따로 켠다)
	_stock_deeds(m)

	# ── ① 메인 3인 ♡1~4 관문 = 컷신 → 대화 ────────────────────────────────
	print("── ① 메인 3인 ♡1~4 관문 컷신 ──")
	var mains := {"miho": "미호", "mel": "멜", "bana": "바나"}
	for rid in mains:
		var r: Resident = m._resident(String(rid))
		var who: Node2D = r.node
		var who_ko := String(mains[rid])
		for target in [1, 2, 3, 4]:
			_set_heart(r, target - 1)
			var body: PackedStringArray = who.heart_gate_lines(target)
			m._start_resident_dialogue(r)
			_check("①a %s♡%d 컷신이 대화보다 먼저 선다(진급은 이미 성사)" % [who_ko, target],
				m.cutscene != null and not m.dialogue.is_open()
				and r.affinity.hearts() == target)
			_settle(m)
			_check("①b %s♡%d 재생이 끝나면 캐릭터 본문이 맨 앞에 선 대화가 열린다" % [who_ko, target],
				m.cutscene == null and m.dialogue.is_open()
				and body.size() >= 3 and String(body[0]) != m.HEART_GATE_PLACEHOLDER_LINE
				and m.dialogue.line() == String(body[0]))
			_drain(m)
		_check("①c %s 관문 비트 ♡1~♡4 전부 기록" % who_ko, _arc_bits_set(m, String(rid)))
	_check("①d 열두 번의 재생 뒤에도 화면·시계가 원복돼 있다(암전 잔류 0)",
		is_equal_approx(m.fade.modulate.a, 0.0) and m.clock.running
		and m._cam.offset.is_equal_approx(Vector2.ZERO) and m.cutscene == null)

	# ── ② 관문 여진 편지(큐 → 익일 도착 → 열람) ───────────────────────────
	print("── ② 관문 여진 편지 ──")
	var want_letters := PackedStringArray()
	for rid in mains:
		var who2: Node2D = m._resident(String(rid)).node
		for t in [1, 2, 3, 4]:
			want_letters.append(String(who2.heart_gate_letter(t)))
	var mapped_ok := true
	for id in want_letters:
		if String(id) == "" or not Mailbox.has_letter(String(id)):
			mapped_ok = false
	_check("②a 열두 관문이 각기 실존하는 편지를 지목한다(3인 × 4칸)",
		want_letters.size() == 12 and mapped_ok)
	_check("②b 열두 통이 전부 큐에 있고 같은 날 도착은 0",
		m.mailbox.pending_count() == 12 and not m.mailbox.has_unread())
	_pass_day(m)
	var arrived_ok := true
	for id in want_letters:
		if not m.mailbox.inbox.has(String(id)):
			arrived_ok = false
	_check("②c 다음 날 아침 = 열두 통이 한꺼번에 도착(미독 12 · 지목한 그 편지들)",
		m.mailbox.pending_count() == 0 and m.mailbox.unread_count() == 12 and arrived_ok)
	var first_letter: String = m.mailbox.next_unread()
	m._read_next_letter()
	_check("②d 열람 = 대화창(발신인이 화자 · 본문 첫 줄) · 여는 순간 기독",
		m.dialogue.is_open() and m.dialogue.speaker() == Mailbox.sender_of(first_letter)
		and m.dialogue.line() == Mailbox.lines_of(first_letter)[0]
		and m.mailbox.is_read(first_letter))
	_drain(m)
	var read_guard := 0
	while m.mailbox.has_unread() and read_guard < 20:
		m._read_next_letter()
		_drain(m)
		read_guard += 1
	_check("②e 열두 통을 순차로 다 읽으면 깃발이 접힌다(보관함은 그대로)",
		not m.mailbox.has_unread() and m.mailbox.inbox.size() == 12)

	# ── ③ 절기 물음 — T1 2인(모찌·네오) 개통분 ────────────────────────────
	print("── ③ 절기 물음(모찌·네오) ──")
	for rid in ["mochi", "neo"]:
		var r3: Resident = m._resident(String(rid))
		var who3: Node2D = r3.node
		_set_idle(r3, 2)                        # 관문·고백이 안 서는 칸(물음만 재는 상태)
		var d: int = _next_week_first(r3, m.clock.day + 1)
		m.clock.day = d
		r3.affinity.last_talk_day = -1
		var q: Dictionary = who3.season_question(GameClock.season_index_for_day(d))
		m._start_resident_dialogue(r3)
		# ★ 점수 스냅은 **대화가 열린 뒤**다 — 일일 대화 보상은 대화 진입의 몫이라, 그 전에 재면
		#   이 단언이 "선택이 아니라 대화 자체"를 재게 된다(miho_arc_test ④c 선례).
		var pts_before: int = r3.affinity.points
		var stage_before: int = r3.affinity.stage
		while m.dialogue.is_open() and not m.dialogue.has_choice():
			m.dialogue.advance()
		_check("③a %s 주 첫날 첫 대화 = 질문 줄에 선택지가 선다" % rid,
			m.dialogue.has_choice() and m.dialogue.line() == String(q["line"])
			and m.dialogue.choices() == PackedStringArray(q["options"]))
		m.dialogue.choose(1)
		_check("③b %s 고르면 반응 한 줄로 교체된다" % rid,
			m.dialogue.is_open()
			and m.dialogue.line() == String(PackedStringArray(q["replies"])[1]))
		_check("③c %s ★0점 계약 — 선택 전후 점수·stage 불변" % rid,
			r3.affinity.points == pts_before and r3.affinity.stage == stage_before)
		_drain(m)
		r3.affinity.last_talk_day = -1
		m._start_resident_dialogue(r3)
		_check("③d %s 같은 주엔 다시 안 묻는다(원장 1주 1회)" % rid, not _has_question(m, q))
		_drain(m)

	# ── ④ Books — 롤 → 즉독 → 기증 → 책장 → 트래커 ────────────────────────
	print("── ④ Books ──")
	var day: int = m.clock.day
	var hit := _find_hit(m, Books.SRC_DEBRIS, day)
	var rolled: String = m.books.pending_drop(Books.SRC_DEBRIS, day, hit)
	_check("④a 오늘 개간 롤에 걸리는 serial이 있다(결정적 재현)", hit >= 0 and rolled != "")
	m._roll_book_drop(Books.SRC_DEBRIS, hit)
	_check("④b 실물·원장이 함께 들어오고 주운 자리에서 바로 펼쳐진다(인라인 즉독)",
		m.inventory.count_of(rolled) == 1 and m.books.has_acquired(rolled)
		and m.dialogue.is_open() and m.dialogue.speaker() == Books.title_of(rolled)
		and m.books.is_read(rolled))
	_drain(m)
	# 책·노트 혼합 수집 — 롤이 준 것은 노트일 확률이 높으므로(70%), 기증·재읽기 검증에 필요한
	# **책**과 **노트**를 각각 명시적으로 되찾는다(직접 acquire = 롤과 같은 원장 창구).
	var bid := ""
	for id in Books.book_ids():
		if not m.books.has_acquired(String(id)):
			bid = String(id)
			break
	var nid := ""
	for id in Books.note_ids():
		if not m.books.has_acquired(String(id)):
			nid = String(id)
			break
	m.books.acquire(bid, day)
	m.books.acquire(nid, day)
	m.inventory.add_item(bid, 1)
	m.inventory.add_item(nid, 1)
	_check("④c 책·노트 혼합 수집 — 책/노트를 따로 센다",
		m.books.acquired_book_count() >= 1 and m.books.acquired_note_count() >= 1
		and m.books.acquired_count() == 3)
	_check("④d 갓 되찾은 둘은 미독이다(즉독분과 구분된다)",
		m.books.unread_count() == 2 and not m.books.is_read(bid))
	# 혼백관 — 책은 좌대에 오르고 노트는 안 오른다.
	for i in m.inventory.SIZE:
		if m.inventory.id_at(i) == bid:
			m.inventory.selected_index = i
			break
	m._try_donate_selected()
	_check("④e 책 기증 = 원장 기록 · 실물 1개 소모",
		m.museum.is_donated(bid) and m.inventory.count_of(bid) == 0)
	for i in m.inventory.SIZE:
		if m.inventory.id_at(i) == nid:
			m.inventory.selected_index = i
			break
	m._try_donate_selected()
	_check("④f 노트는 기증되지 않는다(떡밥은 유품이 아니다 · 실물도 안 사라진다)",
		not m.museum.is_donated(nid) and m.inventory.count_of(nid) == 1)
	_check("④g 트래커 분모 = 유품 3 + 책 8 = 11(책이 전시 원장에 합류)",
		Museum.donatable_ids().size() == 11 and m.museum.donated_count() == 1)
	# 집 책장 — 미독을 먼저 집는다(기증한 책은 실물이 없어도 원장에 남아 다시 읽힌다).
	m._sleeping = false
	m._indoor = "집"
	m._target = m.BOOKSHELF_TILES[0]
	_check("④h 책장 두 칸 다 창구가 선다", m._facing_bookshelf())
	var next_unread: String = m.books.next_reread()
	m._read_from_bookshelf()
	_check("④i 책장 [F] = 미독을 먼저 펼친다(즉독분은 이미 읽혔다)",
		next_unread != rolled and m.dialogue.is_open()
		and m.dialogue.speaker() == Books.title_of(next_unread)
		and m.books.is_read(next_unread))
	_drain(m)
	m._read_from_bookshelf()
	_drain(m)
	m._read_from_bookshelf()
	_check("④j 전부 읽었으면 소장분을 돌려 가며 다시 펼친다(연타 = 다음 권)",
		m.dialogue.is_open() and m.books.unread_count() == 0)
	_drain(m)
	m._indoor = ""

	# ── ⑤ 아크 성립 = B1~B3 세 조각 ───────────────────────────────────────
	print("── ⑤ 아크 성립(B1~B3) ──")
	_check("⑤a 미호 조각 성립(마음 — 외면)", m._redemption_arc_complete("miho"))
	_check("⑤b 멜 조각 성립(사실 — 망각)", m._redemption_arc_complete("mel"))
	_check("⑤c 바나 조각 성립(행동 — 부재)", m._redemption_arc_complete("bana"))
	_check("⑤d 세 조각은 각기 다른 사람 소유다(비트 원장 3인 · 서로 안 대신한다)",
		_arc_bits_set(m, "miho") and _arc_bits_set(m, "mel") and _arc_bits_set(m, "bana")
		and not m._heart_bit_seen("mochi", 1))

	# ── ⑥ 세이브 왕복(원장 복원) ──────────────────────────────────────────
	print("── ⑥ 세이브 왕복 ──")
	var save_acq: int = m.books.acquired_count()
	var save_read: int = m.books.read_ledger.size()
	var save_weeks: Dictionary = m._season_q_week.duplicate()
	m._save_game()
	m.free()
	var m2: Node = await _new_main()            # _ready가 자동 복원
	_drain(m2)
	_check("⑥a 관문 비트 원장이 부팅을 건넌다 = 세 조각이 그대로 성립",
		m2._redemption_arc_complete("miho") and m2._redemption_arc_complete("mel")
		and m2._redemption_arc_complete("bana"))
	_check("⑥b 하트 칸도 보존(♡4 = 관문 상한)",
		m2._resident("miho").affinity.stage == m2.HEART_GATE_MAX
		and m2._resident("bana").affinity.stage == m2.HEART_GATE_MAX)
	var weeks_ok := true
	for k in save_weeks:
		if int(m2._season_q_week.get(String(k), -1)) != int(save_weeks[k]):
			weeks_ok = false
	_check("⑥c 절기 물음 원장 보존(모찌·네오 포함 — 같은 주 재발동 없음)",
		weeks_ok and save_weeks.has("mochi") and save_weeks.has("neo"))
	_check("⑥d Books 입수·기독 원장 보존",
		m2.books.acquired_count() == save_acq and m2.books.read_ledger.size() == save_read
		and m2.books.has_acquired(rolled))
	_check("⑥e 우편함 보관함·기독 원장 보존(재발송도 여전히 거절)",
		m2.mailbox.inbox.size() == 12 and not m2.mailbox.has_unread()
		and not m2.mailbox.send(first_letter))
	_check("⑥f 혼백관 전시도 보존", m2.museum.is_donated(bid))
	m2.free()

	# 뒷정리 — 이 테스트가 만든 세이브를 지운다(다른 테스트의 자동 복원 오염 방지).
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ s9_narrative_smoke_test 전체 통과 ══")
	else:
		print("══ s9_narrative_smoke_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)
