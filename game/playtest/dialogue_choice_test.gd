extends SceneTree
# ★[S9-T1 / ADR-0067 결정 3·4·9] 선택지 문법 + divorce_lines 훅 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 선택지 예약·표시 — 기본 = 마지막 줄 · 명시 인덱스 · 지선 수 위반(1지/5지)·닫힘·범위 밖 거부.
#   ② 입력 전이 — 콜백에 고른 인덱스가 그대로 간다 · 범위 밖 choose 무동작 · 선택 전 advance 차단.
#   ③ 콜백 없는 선택 = 다음 줄 진행(마지막 줄이면 닫힘) · 콜백이 대사를 교체하면 그 위에 진행이
#      얹히지 않는다(세대 판별) · 콜백이 닫으면 닫힌 채로 끝.
#   ④ 선택지 없는 대화의 기존 거동 불변 — start·advance·finished·progress·is_last 전부 그대로.
#   ⑤ choice_shown 시그널 — 예약한 줄이 이미 떠 있으면 즉시 · 넘겨 도달하면 그때(줄 불변 재렌더).
#   ⑥ main 배선 — 패널 본문에 [1]~[n] 표기·진행 안내 접힘·화살표 숨김, 선택지 없는 대화는
#      "[E] 다음/닫기" 표기 그대로(기존 렌더 불변).
#   ⑦ divorce_lines 훅 — 훅 없는 캐릭터 = 공용 폴백 · PackedStringArray 첫 줄 · String 관용 수용 ·
#      빈 반환 = 폴백. 표시 경로는 토스트 그대로(대화창 승격 없음 — S9b).
#   ⑧ 기존 [F]/[G] 2타 래치 불간섭 — 고백 제안 대화엔 선택지가 서지 않는다(이중 존치, 결정 3).
#   ⑨ 점수 0점 계약 — 선택 문법에 호감도 인자·시그널이 없고, 고르기 전후 점수가 불변(결정 4).
#
# 실행: ./run_tests.sh dialogue_choice   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _picked := -1          # 콜백이 받은 인덱스(전이 검증용)
var _cb_calls := 0
var _shown := 0            # choice_shown 발화 횟수

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

# 신규 시작의 옥자 통보 대화를 끝까지 넘겨 닫는다.
func _dismiss_intro(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

# 훅을 가진 가짜 캐릭터 노드(Resident.node 자리에 끼운다 — 실제 캐릭터 파일을 안 건드리고
# 이음매만 검증한다. S9 콘텐츠 태스크가 miho.gd 등에 진짜 본문을 붙이면 이 mock은 그 예시가 된다).
func _mock_node(body: String) -> Node2D:
	var src := GDScript.new()
	src.source_code = "extends Node2D\n" + body
	src.reload()
	var n := Node2D.new()
	n.set_script(src)
	return n

# 콜백들 — 무상태 함수로 두면 Callable 비교·호출 횟수 검증이 쉽다.
func _on_pick(idx: int) -> void:
	_picked = idx
	_cb_calls += 1

func _on_choice_shown() -> void:
	_shown += 1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S9-T1 선택지 문법·divorce_lines 훅 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ① 예약·표시(순수 노드 단위 — main 없이 DialogueBox만) ──
	print("── ① 예약·표시 ──")
	var d := DialogueBox.new()
	_check("①a 닫힌 대화엔 예약 불가",
		not d.queue_choice(PackedStringArray(["가", "나"])) and not d.has_choice())
	d.start("미호", PackedStringArray(["첫 줄", "둘째 줄", "질문 줄"]))
	_check("①b 예약 기본 자리 = 마지막 줄(지금은 안 뜬다)",
		d.queue_choice(PackedStringArray(["가", "나"])) and not d.has_choice())
	d.advance()
	_check("①c 도달 전엔 여전히 안 뜬다", not d.has_choice() and d.choices().is_empty())
	d.advance()
	_check("①d 마지막 줄에서 뜬다", d.has_choice() and d.choices().size() == 2)
	_check("①e 표시 목록이 예약 그대로", d.choices()[0] == "가" and d.choices()[1] == "나")
	d.free()

	d = DialogueBox.new()
	d.start("멜", PackedStringArray(["한 줄"]))
	_check("①f 1지 거부(선택이 아니다)", not d.queue_choice(PackedStringArray(["혼자"])))
	_check("①g 5지 거부(입력 상한 4)",
		not d.queue_choice(PackedStringArray(["1", "2", "3", "4", "5"])))
	_check("①h 범위 밖 인덱스 거부",
		not d.queue_choice(PackedStringArray(["가", "나"]), Callable(), 3))
	_check("①i 거부된 예약은 흔적이 없다", not d.has_choice())
	_check("①j 4지 상한은 통과",
		d.queue_choice(PackedStringArray(["1", "2", "3", "4"])) and d.choices().size() == 4)
	d.free()

	# ── ② 입력 전이(콜백 인자·advance 차단) ──
	print("── ② 입력 전이 ──")
	d = DialogueBox.new()
	d.start("바나", PackedStringArray(["질문 줄", "뒷줄"]))
	_check("②a 명시 인덱스 예약 = 그 줄에 즉시 선다",
		d.queue_choice(PackedStringArray(["가", "나", "다"]), _on_pick, 0) and d.has_choice())
	d.advance()
	_check("②b 선택 전 넘기기는 막힌다(고르는 것이 진행)",
		d.has_choice() and d.line() == "질문 줄")
	d.choose(9)
	_check("②c 범위 밖 choose는 무동작", d.has_choice() and _cb_calls == 0)
	_picked = -1
	d.choose(1)
	_check("②d 고른 인덱스가 콜백에 그대로 간다", _picked == 1 and _cb_calls == 1)
	_check("②e 콜백이 흐름을 안 바꿨으면 다음 줄로 진행",
		d.is_open() and d.line() == "뒷줄" and not d.has_choice())
	d.choose(0)
	_check("②f 선택지가 없으면 choose는 무동작", _cb_calls == 1)
	d.free()

	# ── ③ 콜백 없는 선택 / 대사 교체 / 닫기 ──
	print("── ③ 콜백 유무별 진행 ──")
	d = DialogueBox.new()
	var closed := [false]
	d.finished.connect(func(): closed[0] = true)
	d.start("미호", PackedStringArray(["톤을 고른다"]))
	d.queue_choice(PackedStringArray(["담담히", "웃으며"]))
	d.choose(0)
	_check("③a 콜백 없는 선택 = 다음 줄 진행(마지막 줄이라 닫힘)",
		not d.is_open() and closed[0])
	d.free()

	d = DialogueBox.new()
	d.start("미호", PackedStringArray(["질문", "안 보일 뒷줄"]))
	d.queue_choice(PackedStringArray(["가", "나"]), func(_i): d.replace_lines(PackedStringArray(["교체된 반응"])), 0)
	d.choose(0)
	_check("③b 콜백이 대사를 교체하면 그 위에 진행이 안 얹힌다",
		d.is_open() and d.line() == "교체된 반응" and d.progress() == "1/1")
	_check("③c 교체된 대사엔 옛 선택지 예약이 따라오지 않는다", not d.has_choice())
	d.free()

	d = DialogueBox.new()
	d.start("미호", PackedStringArray(["질문", "뒷줄"]))
	d.queue_choice(PackedStringArray(["가", "나"]), func(_i): d.replace_lines(PackedStringArray()), 0)
	d.choose(1)
	_check("③d 콜백이 닫으면 닫힌 채로 끝(조용한 종료)", not d.is_open())
	d.free()

	# ── ④ 선택지 없는 대화 = 기존 거동 불변 ──
	print("── ④ 기존 거동 불변 ──")
	d = DialogueBox.new()
	var fin := [0]
	d.finished.connect(func(): fin[0] += 1)
	d.start("옥자", PackedStringArray(["가", "나"]))
	_check("④a 시작 = 첫 줄·진행표시·마지막 아님",
		d.is_open() and d.line() == "가" and d.progress() == "1/2" and not d.is_last()
		and not d.has_choice())
	d.advance()
	_check("④b 넘기기 = 둘째 줄·마지막", d.line() == "나" and d.is_last())
	d.advance()
	_check("④c 마지막에서 넘기면 닫히고 finished 1회", not d.is_open() and fin[0] == 1)
	d.advance()
	_check("④d 닫힌 뒤 넘기기는 무동작", not d.is_open() and fin[0] == 1)
	d.free()

	# ── ⑤ choice_shown 시그널 ──
	print("── ⑤ choice_shown ──")
	d = DialogueBox.new()
	d.choice_shown.connect(_on_choice_shown)
	d.start("미호", PackedStringArray(["가", "나"]))
	d.queue_choice(PackedStringArray(["1", "2"]), Callable(), 0)
	_check("⑤a 예약한 줄이 이미 떠 있으면 즉시 1회", _shown == 1)
	d.choose(0)
	_check("⑤b 고른 뒤 진행에는 추가 발화 없음", _shown == 1)
	d.free()

	d = DialogueBox.new()
	d.choice_shown.connect(_on_choice_shown)
	d.start("미호", PackedStringArray(["가", "나"]))
	d.queue_choice(PackedStringArray(["1", "2"]))
	_check("⑤c 도달 전엔 발화 없음", _shown == 1)
	d.advance()
	_check("⑤d 넘겨 도달한 순간 발화", _shown == 2)
	d.free()

	# ── ⑥ main 배선(패널 렌더) ──
	print("── ⑥ 패널 렌더 ──")
	var m: Node = await _new_main()
	_dismiss_intro(m)
	m.dialogue.start("미호", PackedStringArray(["오늘은 어땠어?"]))
	_check("⑥a 선택지 없는 대화는 기존 표기 그대로([E] 안내 + 진행)",
		m.dialogue_text.text.contains("[E] 닫기") and m.dialogue_text.text.contains("1/1"))
	m.dialogue.queue_choice(PackedStringArray(["좋았어", "그냥 그랬어", "말하기 싫어"]))
	await process_frame
	_check("⑥b 선택지 표기 = [1]~[3] 대괄호 키 관례",
		m.dialogue_text.text.contains("[1] 좋았어")
		and m.dialogue_text.text.contains("[2] 그냥 그랬어")
		and m.dialogue_text.text.contains("[3] 말하기 싫어"))
	_check("⑥c 고르기 전엔 진행 안내가 접힌다(넘기기가 막혀 있어 거짓말이 된다)",
		not m.dialogue_text.text.contains("[E] "))
	_check("⑥d 본문(질문)은 그대로 남는다", m.dialogue_text.text.contains("오늘은 어땠어?"))
	m.dialogue.choose(0)
	_check("⑥e 고르면 대화가 진행된다(마지막 줄 = 닫힘)", not m.dialogue.is_open())

	# ── ⑦ divorce_lines 훅 ──
	print("── ⑦ divorce_lines 훅 ──")
	var r_miho = m._resident("miho")
	var orig: Node2D = r_miho.node
	# ★[S9-T4 / ADR-0067 결정 11 재작성] 미호가 divorce_lines 훅을 갖게 되어 "훅 없는 캐릭터"의
	#   실례로 쓸 수 없다. 폴백 계약은 그대로 유효하므로 전제를 **훅 없는 mock**으로 옮기고,
	#   실파일 쪽은 반대 방향(훅 존재·본문이 폴백과 다름)으로 단언한다.
	_check("⑦a-1 미호(실파일)는 작별 훅을 가진다(placeholder 폴백 아님)",
		orig.has_method("divorce_lines")
		and m._divorce_farewell_line(r_miho) == String(orig.divorce_lines()[0])
		and m._divorce_farewell_line(r_miho) != m.DIVORCE_FAREWELL_LINE)
	var mk_none := _mock_node("func lines(_h: int, _f: bool) -> PackedStringArray:\n\treturn PackedStringArray([\"x\"])\n")
	r_miho.node = mk_none
	_check("⑦a-2 훅 없는 캐릭터 = 공용 폴백",
		not mk_none.has_method("divorce_lines")
		and m._divorce_farewell_line(r_miho) == m.DIVORCE_FAREWELL_LINE)
	mk_none.free()
	var mk_arr := _mock_node("func divorce_lines() -> PackedStringArray:\n\treturn PackedStringArray([\"…원망은 없어. 정말로.\", \"둘째 줄\"])\n")
	r_miho.node = mk_arr
	_check("⑦b PackedStringArray 훅 = 첫 줄을 쓴다",
		m._divorce_farewell_line(r_miho) == "…원망은 없어. 정말로.")
	var mk_str := _mock_node("func divorce_lines() -> String:\n\treturn \"…잘 지내.\"\n")
	r_miho.node = mk_str
	_check("⑦c String 반환도 관용 수용", m._divorce_farewell_line(r_miho) == "…잘 지내.")
	var mk_empty := _mock_node("func divorce_lines() -> PackedStringArray:\n\treturn PackedStringArray()\n")
	r_miho.node = mk_empty
	_check("⑦d 빈 반환 = 폴백(관문·고백 훅과 같은 이음매)",
		m._divorce_farewell_line(r_miho) == m.DIVORCE_FAREWELL_LINE)
	_check("⑦e null 방어 = 폴백", m._divorce_farewell_line(null) == m.DIVORCE_FAREWELL_LINE)
	r_miho.node = orig
	mk_arr.free()
	mk_str.free()
	mk_empty.free()

	# 실경로(_do_divorce) — 훅 문구가 토스트로 나가고 **대화창으로 승격되지 않는다**(결정 9).
	m._spouse_id = "miho"
	m.wallet.gold = m.DIVORCE_COST
	var mk_live := _mock_node("func divorce_lines() -> PackedStringArray:\n\treturn PackedStringArray([\"…고맙다는 말만 두고 갈게.\"])\n")
	r_miho.node = mk_live
	m._do_divorce()
	_check("⑦f 이혼 결행 = 상태 전이 그대로(슬롯 해제·♡0)",
		m._spouse_id == "" and r_miho.affinity.hearts() == 0)
	_check("⑦g 작별 문구는 토스트 경로 유지(대화창 승격 없음)", not m.dialogue.is_open())
	r_miho.node = orig
	mk_live.free()

	# ── ⑧ 기존 [F]/[G] 래치 불간섭 + ⑨ 0점 계약 ──
	print("── ⑧ 기존 래치 불간섭·⑨ 0점 ──")
	var r_mel = m._resident("mel")
	r_mel.affinity.points = Affinity.MAX_POINTS
	r_mel.affinity.stage = Affinity.MAX_HEARTS - 1
	m._start_resident_dialogue(r_mel)
	_check("⑧a 고백 제안 대화엔 선택지가 서지 않는다(이중 존치 — [F]/[G] 래치 그대로)",
		m._confess_rid == "mel" and not m.dialogue.has_choice())
	_check("⑧b 제안 줄은 기존 표기([F]/[G] 본문 문자열) 그대로",
		m.dialogue.line() == m.CONFESS_OFFER_LINE)
	var before: int = r_mel.affinity.points
	m.dialogue.queue_choice(PackedStringArray(["가", "나"]), Callable(), 0)
	m.dialogue.choose(1)
	_check("⑨a 선택은 점수를 움직이지 않는다(0점 계약)", r_mel.affinity.points == before)
	_check("⑨b 선택지 API에 호감도 인자·시그널이 없다",
		not m.dialogue.has_signal("choice_scored")
		and m.dialogue.has_signal("choice_shown"))
	m.free()

	# 뒷정리 — 이 테스트가 만든 세이브를 지운다(다른 테스트의 자동 복원 오염 방지).
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ dialogue_choice_test 전체 통과 ══")
	else:
		print("══ dialogue_choice_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)
