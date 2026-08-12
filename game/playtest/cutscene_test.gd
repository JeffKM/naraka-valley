extends SceneTree
# ★[S9-T2 / ADR-0067 결정 2] 최소 컷신 러너(연출 등급 2) — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 결정성 — 같은 스텝 배열 + 같은 delta 열 = 같은 전이열(trace 문자열 동일)·즉시 스텝 연쇄·
#      한 프레임에 여러 스텝 소비.
#   ② 4동사 — NPC 스폰/이동(보간·퇴장 타이밍)·카메라 팬·페이드·시계 정지가 각자 제 값으로 움직인다.
#   ③ 미지 동사 = **거절 기록 후 스킵**(무시도 예외도 아님)·전량 미지면 재생 자체가 안 열린다.
#   ④ main 배선 — 시계 정지/원복(세이브 키 0)·페이드/카메라 원복·이동 잠금과 해제.
#   ⑤ 관문 이음매 하위호환 — 훅 없는 캐릭터 = 현행 대화 그대로(컷신 0).
#   ⑥ 훅 있는 캐릭터 = 컷신 재생 → **끝난 뒤 대화 개시**(관문 발화가 그대로 앞에 선다).
#   ⑦ 진급 스냅샷(_gate_target)이 훅에 정확한 칸을 넘긴다 · 재구애(조용한 진급)엔 컷신이 없다.
#
# 실행: ./run_tests.sh cutscene   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _hook_targets: Array = []   # mock 훅이 받은 target 값들(스냅샷 검증)

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

func _close_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

# 훅을 가진 가짜 캐릭터 노드(Resident.node 자리에 끼운다 — 실제 캐릭터 파일을 안 건드리고
# 이음매만 검증한다. S9-T4~ 콘텐츠 태스크가 miho.gd 등에 진짜 데이터를 붙이면 이 mock이 그 예시다).
func _mock_node(body: String) -> Node2D:
	var src := GDScript.new()
	src.source_code = "extends Node2D\n" + body
	src.reload()
	var n := Node2D.new()
	n.set_script(src)
	return n

# 컷신이 끝날 때까지 고정 delta로 굴린다(엔진 프레임을 안 기다린다 = 결정적).
func _play_out(m: Node, dt: float = 0.1, cap: int = 200) -> int:
	var n := 0
	while m.cutscene != null and n < cap:
		m._tick_cutscene(dt)
		n += 1
	return n

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S9-T2 컷신 러너(연출 등급 2) 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# 공용 스텝 데이터 — 4동사가 한 번씩 나오는 최소 장면(암전 → 시계 정지 → NPC 등장·이동 →
	# 카메라 팬 → 밝아짐 → 시계 재개).
	var scene := [
		{"verb": "fade", "to": 1.0, "secs": 0.4},
		{"verb": "clock", "running": false},
		{"verb": "npc", "id": "miho", "tile": Vector2i(10, 10)},
		{"verb": "npc", "id": "miho", "tile": Vector2i(10, 6), "secs": 1.0},
		{"verb": "cam", "offset": Vector2(0, -48), "secs": 0.5},
		{"verb": "fade", "to": 0.0, "secs": 0.4},
		{"verb": "clock", "running": true},
	]

	# ── ① 결정성(순수 러너 단위 — main 없이) ──
	print("── ① 결정성 ──")
	var deltas := [0.13, 0.07, 0.31, 0.02, 0.5, 0.25, 0.4, 0.19, 0.6, 0.33, 0.5]
	var t1 := _trace_of(scene, deltas)
	var t2 := _trace_of(scene, deltas)
	_check("①a 같은 데이터 2회 = 같은 전이열", t1 == t2 and not t1.is_empty())
	_check("①b 전이열이 스텝 전량을 지난다(begin 7 · end 7 · 종료 표식)",
		_count_prefix(t1, "begin:") == 7 and _count_prefix(t1, "end:") == 7
		and String(t1[t1.size() - 1]) == "end")
	# 프레임 분해가 달라도 결과 상태는 같다(같은 총 시간 · 다른 쪼개기).
	var a := CutsceneRunner.new(scene)
	a.start()
	for i in 100:
		a.advance(0.05)
	var b := CutsceneRunner.new(scene)
	b.start()
	b.advance(5.0)                     # 한 프레임이 전 스텝을 통째로 삼킨다
	_check("①c 프레임 쪼개기가 달라도 종착 상태는 같다(한 프레임 대량 소비 안전)",
		a.is_done() and b.is_done() and is_equal_approx(a.fade_alpha(), b.fade_alpha())
		and a.camera_offset().is_equal_approx(b.camera_offset())
		and a.clock_running() == b.clock_running()
		and a.npc_tile("miho").is_equal_approx(b.npc_tile("miho")))
	# 즉시 스텝만으로 이뤄진 컷신 — 한 번의 advance(0)에 전부 소비되고 끝난다(무한 루프 방어).
	var inst := CutsceneRunner.new([
		{"verb": "clock", "running": false},
		{"verb": "npc", "id": "mel", "tile": Vector2i(3, 3)},
		{"verb": "clock", "running": true},
	])
	inst.start()
	inst.advance(0.0)
	_check("①d 즉시 스텝 연쇄는 한 프레임에 전부 소비", inst.is_done() and inst.clock_running())

	# ── ② 4동사 ──
	print("── ② 4동사 ──")
	var r := CutsceneRunner.new(scene)
	_check("②a 시작 전 = 대기(무동작 advance 안전)",
		not r.is_playing() and not r.is_done() and r.step_count() == 7)
	r.advance(1.0)
	_check("②b 시작 전 advance는 무동작", r.fade_alpha() == 0.0)
	_check("②c start = 재생 개시", r.start() and r.is_playing())
	_check("②d 재차 start 거부(중복 재생 없음)", not r.start())
	r.advance(0.2)
	_check("②e ③페이드 — 절반 진행 = 중간값(0.4초 중 0.2초 = 0.5)",
		is_equal_approx(r.fade_alpha(), 0.5))
	r.advance(0.2)
	_check("②f ④시계 — 페이드가 끝나면 즉시 정지 동사가 붙는다", not r.clock_running())
	r.advance(0.0)
	_check("②g ①NPC 스폰 — 즉시 그 칸에 선다(보간 없음)",
		r.npc_tile("miho").is_equal_approx(Vector2(10, 10)) and r.npc_visible("miho"))
	r.advance(0.5)
	_check("②h ①NPC 이동 — 절반이면 중간 칸(10,10)→(10,6)의 반",
		r.npc_tile("miho").is_equal_approx(Vector2(10, 8)))
	r.advance(0.5)
	_check("②i ①NPC 이동 종료 = 목적지 정확히", r.npc_tile("miho").is_equal_approx(Vector2(10, 6)))
	r.advance(0.25)
	_check("②j ②카메라 팬 — 절반이면 오프셋 절반",
		r.camera_offset().is_equal_approx(Vector2(0, -24)))
	r.advance(0.25 + 0.4)
	_check("②k 페이드 인 복귀 + 카메라 도착",
		is_equal_approx(r.fade_alpha(), 0.0) and r.camera_offset().is_equal_approx(Vector2(0, -48)))
	r.advance(0.0)
	_check("②l 마지막 즉시 스텝(시계 재개) 소비 후 종료", r.is_done() and r.clock_running())
	_check("②m 종착에서 advance는 무동작(멱등)", _idempotent_done(r))
	# 퇴장 타이밍 — 이동을 마친 **뒤** 사라진다(등장은 시작 즉시).
	var ex := CutsceneRunner.new([
		{"verb": "npc", "id": "bana", "tile": Vector2i(4, 4)},
		{"verb": "npc", "id": "bana", "tile": Vector2i(8, 4), "secs": 1.0, "visible": false},
	])
	ex.start()
	ex.advance(0.5)
	_check("②n 퇴장 스텝 도중엔 아직 보인다(걸어 나가는 중)",
		ex.npc_visible("bana") and ex.npc_tile("bana").is_equal_approx(Vector2(6, 4)))
	ex.advance(0.6)
	_check("②o 이동을 마친 뒤 사라진다",
		not ex.npc_visible("bana") and ex.npc_tile("bana").is_equal_approx(Vector2(8, 4)))
	_check("②p npc_ids = 지금까지 등장한 NPC", ex.npc_ids().size() == 1 and String(ex.npc_ids()[0]) == "bana")
	# ★ cast_ids = 스텝 데이터 파생 전량 — **등장 전에도** 안다(main의 원상태 스냅 목록).
	var cast := CutsceneRunner.new(scene)
	_check("②q cast_ids는 재생 전에 이미 전량을 안다(npc_ids는 아직 빈다)",
		cast.cast_ids().size() == 1 and String(cast.cast_ids()[0]) == "miho"
		and cast.npc_ids().is_empty())
	cast.start()
	_check("②r 첫 스텝이 페이드여도 cast_ids는 그대로(스냅이 안 비는 근거)",
		cast.cast_ids().size() == 1 and cast.npc_ids().is_empty())

	# ── ③ 미지 동사 ──
	print("── ③ 미지 동사 ──")
	var mix := CutsceneRunner.new([
		{"verb": "particles", "kind": "여우불"},          # ADR-0067이 잠근 밖 — 거절
		{"verb": "fade", "to": 1.0, "secs": 0.2},
		"딕셔너리가 아님",                                  # 손상 입력 — 거절
		{"verb": "sound", "id": "bgm"},                    # 밖 — 거절
	])
	_check("③a 미지 동사는 재생 목록에 안 들어온다(유효 1건만)", mix.step_count() == 1)
	var rej := mix.rejected_verbs()
	_check("③b 거절은 조용히 무시되지 않고 기록된다(입력 순서대로)",
		rej.size() == 3 and String(rej[0]) == "particles" and String(rej[2]) == "sound"
		and String(rej[1]).begins_with("<"))
	mix.start()
	mix.advance(1.0)
	_check("③c 나머지 유효 스텝은 정상 재생", mix.is_done() and is_equal_approx(mix.fade_alpha(), 1.0))
	_check("③d 거절도 전이열에 남는다(결정적 — 재생 타이밍과 무관)",
		_count_prefix(mix.trace(), "reject:") == 3)
	var all_bad := CutsceneRunner.new([{"verb": "timeline"}, {"verb": "shake"}])
	_check("③e 전량 미지 = 재생 자체가 안 열린다(main이 평소 대화로 되돌아가는 근거)",
		not all_bad.start() and not all_bad.is_playing() and all_bad.step_count() == 0)
	_check("③f 빈 배열도 안 열린다", not CutsceneRunner.new([]).start())

	# ── ④ main 배선(시계·페이드·카메라·이동 잠금) ──
	print("── ④ main 배선 ──")
	var m: Node = await _new_main()
	_dismiss_intro(m)
	var clock_before: bool = m.clock.running
	var miho_pos_before: Vector2 = m._resident("miho").node.position
	var miho_vis_before: bool = m._resident("miho").node.visible
	var ok: bool = m._begin_cutscene(scene, "", PackedStringArray())
	_check("④a 재생 개시 = 러너가 선다", ok and m.cutscene != null)
	_check("④b 이동 잠금(재생 중)", not m.player.is_physics_processing())
	m._tick_cutscene(0.4)
	_check("④c ③페이드가 화면에 발린다(암전)", is_equal_approx(m.fade.modulate.a, 1.0))
	m._tick_cutscene(0.0)
	_check("④d ④시계 정지 동사가 게임 시계를 멈춘다", not m.clock.running)
	m._tick_cutscene(1.0)
	_check("④e ①NPC 그림이 컷신 자리로 옮겨진다",
		m._resident("miho").node.position.is_equal_approx(
			Vector2(10 * m.TILE + m.TILE * 0.5, 6 * m.TILE + m.TILE * 0.5)))
	m._tick_cutscene(0.25)
	_check("④f ②카메라 팬이 Camera2D.offset에 발린다",
		m._cam.offset.is_equal_approx(Vector2(0, -24)))
	_play_out(m)
	_check("④g 재생 종료 = 러너 해제", m.cutscene == null)
	_check("④h 페이드·카메라 원복(암전인 채로 안 끝난다)",
		is_equal_approx(m.fade.modulate.a, 0.0) and m._cam.offset.is_equal_approx(Vector2.ZERO))
	_check("④i 시계는 **재생 직전 상태로** 원복(무조건 재개 아님)", m.clock.running == clock_before)
	_check("④j NPC 그림 원복 = 재생 직전 그대로(스테이션 파생이 안 되돌리는 몫을 옮긴 쪽이 진다)",
		m._resident("miho").node.position.is_equal_approx(miho_pos_before)
		and m._resident("miho").node.visible == miho_vis_before)
	_check("④k 예약 대화가 없으면 이동 잠금 해제", m.player.is_physics_processing())
	m._save_game()
	var payload: Dictionary = m.saver.load_game(m._active_slot)
	_check("④l 세이브 키 0 — 컷신 상태는 저장 대상이 아니다(정지한 시계가 세이브를 오염 못 함)",
		not payload.has("cutscene") and not payload.has("cutscene_clock")
		and not payload.get("clock", {}).has("running"))
	# 시계가 **다른 이유로** 멈춰 있었으면 컷신이 되살리지 않는다(취침 연출·마무리 화면 보호).
	m.clock.running = false
	m._begin_cutscene([{"verb": "clock", "running": true}, {"verb": "fade", "to": 0.0, "secs": 0.1}],
		"", PackedStringArray())
	m._tick_cutscene(0.0)
	_check("④m 멈춰 있던 시계는 컷신의 '재개' 동사로도 안 돈다(스냅 우선)", not m.clock.running)
	_play_out(m)
	_check("④n 종료 후에도 원래대로 멈춘 채", not m.clock.running)
	m.clock.running = true

	# ── ⑤ 관문 이음매 하위호환(훅 없는 캐릭터) ──
	print("── ⑤ 하위호환 ──")
	# ★[S9-T4 재작성] 원래 이 블록은 **실제 miho.gd가 훅을 안 가졌다**는 사실을 하위호환의 전제로
	#   썼는데, S9-T4가 미호에 컷신 데이터를 넣으면서 그 전제가 미호에서 사라졌다. 계약 자체
	#   ("훅 없는 캐릭터 = 현행 대화 그대로")는 그대로 유효하므로, 전제를 **훅 없는 mock 노드**로
	#   옮긴다 — 어느 캐릭터가 아직 훅을 안 가졌는지에 의존하지 않게 되어(멜·바나도 T5·T6에서
	#   훅을 받는다) 이 단언이 다시는 콘텐츠 태스크에 깨지지 않는다.
	m.onboarding.step = Onboarding.MEET_MIHO
	var r_miho: Resident = m._resident("miho")
	var miho_orig: Node2D = r_miho.node
	var mock_bare := _mock_node(
		"func lines(_h: int, _f: bool) -> PackedStringArray:\n"
		+ "\treturn PackedStringArray([\"mock 일상 대사\"])\n")
	r_miho.node = mock_bare
	_check("⑤a 훅 없는 캐릭터 파일(무수정 하위호환의 전제)",
		not mock_bare.has_method("heart_gate_cutscene"))
	r_miho.affinity.points = Affinity.MAX_POINTS
	r_miho.affinity.stage = 0
	m._run_harvested = 30                       # 미호 ♡1 deed 충족
	m._start_resident_dialogue(r_miho)
	_check("⑤b 훅 없음 = 컷신 0 · 관문 대화가 곧바로 열린다(현행 거동 그대로)",
		m.cutscene == null and m.dialogue.is_open() and r_miho.affinity.hearts() == 1)
	_check("⑤c 관문 발화가 맨 앞에 선다(placeholder — 본문은 S9-T4~)",
		m.dialogue.line() == m.HEART_GATE_PLACEHOLDER_LINE)
	_check("⑤d 훅 조회 자체도 빈 배열(방어)", m._gate_cutscene_steps(r_miho, 1).is_empty())
	_close_dialogue(m)
	# ★[S9-T4 / ADR-0067 결정 11] 반대편 — **실제 캐릭터 파일은 이제 훅을 가진다**. placeholder
	#   동일성 대신 "훅이 있고 4동사 안의 유효 스텝을 낸다"를 단언한다(본문 검증은 miho_arc_test).
	r_miho.node = miho_orig
	_check("⑤e 미호(실파일)는 관문 컷신 훅을 가진다", miho_orig.has_method("heart_gate_cutscene"))
	var live1 := CutsceneRunner.new(m._gate_cutscene_steps(r_miho, 1))
	_check("⑤f 그 데이터가 4동사 안이고 재생 가능하다(거절 0 · 유효 스텝 있음)",
		live1.rejected_verbs().is_empty() and live1.step_count() > 0)
	r_miho.node = mock_bare

	# ── ⑥ 훅 있는 캐릭터 = 컷신 후 대화 개시 ──
	print("── ⑥ 컷신 → 대화 ──")
	var mock := _mock_node(
		"var seen := []\n"
		+ "func lines(_h: int, _f: bool) -> PackedStringArray:\n"
		+ "\treturn PackedStringArray([\"mock 일상 대사\"])\n"
		+ "func heart_gate_cutscene(target: int) -> Array:\n"
		+ "\tseen.append(target)\n"
		+ "\treturn [{\"verb\": \"fade\", \"to\": 1.0, \"secs\": 0.3},\n"
		+ "\t\t{\"verb\": \"clock\", \"running\": false},\n"
		+ "\t\t{\"verb\": \"fade\", \"to\": 0.0, \"secs\": 0.3}]\n")
	r_miho.node = mock
	m._run_harvested = 80                       # 미호 ♡2 deed 충족
	m._start_resident_dialogue(r_miho)
	_check("⑥a 훅 있음 = 대사보다 **먼저** 컷신이 선다(대화는 아직 안 열림)",
		m.cutscene != null and not m.dialogue.is_open())
	_check("⑥b 진급은 이미 성사됐다(판정부는 컷신과 무관 — 부작용 분리)",
		r_miho.affinity.hearts() == 2)
	_check("⑥c 재생 중 이동 잠금", not m.player.is_physics_processing())
	_check("⑥d 재생 중 시계 정지 동사가 먹는다(페이드 뒤)", _tick_until_clock_stop(m))
	_play_out(m)
	_check("⑥e 재생이 끝나면 그 자리에서 대화가 열린다",
		m.cutscene == null and m.dialogue.is_open())
	_check("⑥f 관문 발화가 그대로 앞에 선다(컷신이 대사를 삼키지 않는다)",
		m.dialogue.line() == m.HEART_GATE_PLACEHOLDER_LINE)
	_check("⑥g 화자·이동 잠금이 대화로 이어진다",
		m.dialogue.speaker() == r_miho.display_name and not m.player.is_physics_processing())
	_check("⑥h 시계는 재생 종료와 함께 원복", m.clock.running)
	# ⑦ 진급 스냅샷 — 훅이 받은 target이 실제 진급 칸이다.
	_check("⑦a 훅에 정확한 칸이 간다(♡2 진급 = target 2)",
		mock.seen.size() == 1 and int(mock.seen[0]) == 2)
	_close_dialogue(m)
	_check("⑥i 대화를 닫으면 이동 잠금 해제(현행 대화 플로우 그대로)",
		m.player.is_physics_processing())

	# ⑦ 재구애(본 비트 잔존) = 조용한 진급 → 관문 발화 0 → 컷신도 0.
	r_miho.affinity.stage = 1
	r_miho.affinity.points = Affinity.MAX_POINTS
	mock.seen.clear()
	m._start_resident_dialogue(r_miho)
	_check("⑦b 재구애의 조용한 진급엔 컷신이 없다(발화 0 = 사건 없음, ADR-0022)",
		m.cutscene == null and r_miho.affinity.hearts() == 2 and mock.seen.is_empty())
	_close_dialogue(m)
	# 훅이 빈 배열을 주면 = 훅 없음과 동일(현행 대화).
	var mock_empty := _mock_node(
		"func lines(_h: int, _f: bool) -> PackedStringArray:\n"
		+ "\treturn PackedStringArray([\"mock 일상 대사\"])\n"
		+ "func heart_gate_cutscene(_t: int) -> Array:\n\treturn []\n")
	r_miho.node = mock_empty
	r_miho.affinity.stage = 2
	r_miho.affinity.points = Affinity.MAX_POINTS
	m._run_harvested = 160                      # 미호 ♡3 deed 충족
	m._start_resident_dialogue(r_miho)
	_check("⑦c 훅이 빈 데이터면 훅 없음과 동일(현행 대화)",
		m.cutscene == null and m.dialogue.is_open() and r_miho.affinity.hearts() == 3)
	_close_dialogue(m)
	r_miho.node = miho_orig
	mock.free()
	mock_empty.free()
	mock_bare.free()
	m.free()

	# 뒷정리 — 이 테스트가 만든 세이브를 지운다(다른 테스트의 자동 복원 오염 방지).
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ cutscene_test 전체 통과 ══")
	else:
		print("══ cutscene_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)

# ── 헬퍼 ────────────────────────────────────────────────────────────────────
# 스텝 배열을 delta 열로 끝까지 굴린 전이열.
func _trace_of(steps: Array, deltas: Array) -> PackedStringArray:
	var r := CutsceneRunner.new(steps)
	r.start()
	for d in deltas:
		r.advance(float(d))
	return r.trace()

func _count_prefix(lines: PackedStringArray, pre: String) -> int:
	var n := 0
	for l in lines:
		if String(l).begins_with(pre):
			n += 1
	return n

# 종착 상태에서 advance를 더 먹여도 아무것도 안 변하는가.
func _idempotent_done(r: CutsceneRunner) -> bool:
	var f := r.fade_alpha()
	var c := r.camera_offset()
	var n := r.trace().size()
	r.advance(1.0)
	return r.is_done() and is_equal_approx(r.fade_alpha(), f) \
		and r.camera_offset().is_equal_approx(c) and r.trace().size() == n

# 컷신을 굴리다 시계가 멈추는 순간을 잡는다(멈추면 true).
func _tick_until_clock_stop(m: Node) -> bool:
	var n := 0
	while m.cutscene != null and n < 100:
		m._tick_cutscene(0.1)
		n += 1
		if not m.clock.running:
			return true
	return false
