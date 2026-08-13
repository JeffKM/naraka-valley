extends SceneTree
# ★[S9b-T7 / ADR-0068 결정 8] 척추 해결 게이트 + B5 재구성 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 게이트 AND 전수 — [narrative-bible §6.1] `AND(세 조각 ♡4) + B4 + 조연 11인 ♡3`의 세 항을
#      **하나씩 빼며** 전부 false, 전부 채우면 true. OR/threshold가 몰래 섞여 있지 않다는 증명이다.
#   ② 로스터 박제 정합(안전장치 ㉑) — 11인 · 박제 ⊆ 실제 레지스트리 · 점주 5인·옥자 부재.
#   ③ 게이트 미충족 시 **옥자 집 잠금 불변** — 문 칸에 서 있어도 아무 일이 안 일어난다(알림도 0).
#   ④ 충족 시 진입 개방 + 척추 발동 — 컷신(4동사·npc 0) → 내면 공간(암전·적막·시계 정지).
#   ⑤ 퍼즐 결정성 — 같은 시드 + 같은 입력 열 = 같은 `trace()`(FishingSession 규범의 눈금).
#   ⑥ **무실패** — 오답을 아무리 반복해도 상태가 안 상하고, 종료가 불가침이다.
#   ⑦ 🟡 확증선 — 무입력 카운터(**tick 수**·벽시계 아님)가 차면 다음 파편을 지시하고,
#      그 본문은 **전부 지문**(대사 0)이며 **gangrim.gd는 한 글자도 안 걸린다**.
#   ⑧ 완료 = B5 비트 + 자동 저장 반영(세이브 왕복 보존) + 화면·시계·소리 원복.
#   ⑨ 금칙어 스캔 — 조연 31어 + 강림 🔴 4종을 척추 본문에 상속. 「옥자」 0회·중심 진실 0회.
#   ⑩ 재진입 가드 — B5 기성립이면 같은 문 칸에서 재발동 0.
#
# ★ 관례(기존 스위트 상속): 하트는 points·stage **동반** 세팅 · 드레인은 컷신 재생 +
#   선택지 `has_choice → choose(0)` 동반 · 헤드리스는 반드시 game/에서 · 순차 실행.
#
# 실행: ./run_tests.sh spine

const T1 := Spine.T1_ROSTER
const MAINS := Spine.MAIN_ROSTER
# 점주 5인(T2) — 척추 요구 **밖**이다(그들에겐 그날 밤 고백 자체가 없다).
const SHOPKEEPERS := ["boatman", "ongi", "pulmu", "mugol", "kitchen_youkai"]

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

func _settle(m: Node) -> void:
	var guard := 0
	while m.cutscene != null and guard < 200:
		m._tick_cutscene(0.1)
		guard += 1

func _drain(m: Node) -> void:
	_settle(m)
	var guard := 0
	while m.dialogue.is_open() and guard < 300:
		if m.dialogue.has_choice():
			m.dialogue.choose(0)
		else:
			m.dialogue.advance()
		guard += 1

func _set_heart(r, stage: int) -> void:
	r.affinity.stage = stage
	r.affinity.points = Affinity.MAX_POINTS

# 게이트 세 항을 전부 채운다(메인 ♡4 · B4 비트 · 조연 11인 ♡3 비트).
func _fill_gate(m: Node) -> void:
	for rid in MAINS:
		var r = m._resident(String(rid))
		if r != null and r.affinity != null:
			_set_heart(r, Spine.MAIN_STAGE)
	m._mark_spine_bit(m.SPINE_B4)
	for rid in T1:
		m._mark_heart_bit(String(rid), Spine.CHORUS_HEART)

# 플레이어를 미혹의 숲 옥자 집 문 칸에 세운다.
func _stand_at_door(m: Node) -> void:
	m._rebuild_region(RegionCatalog.MIHOK_FOREST)
	m.player.global_position = m._tile_center_px(m.OKJA_HUT_DOOR)

# 순수 판정용 스냅 조립(main 없이 게이트만 재는 ①에서 쓴다).
func _stages(v: int) -> Dictionary:
	var d := {}
	for rid in MAINS:
		d[String(rid)] = v
	return d

func _bits(heart: int) -> Dictionary:
	var d := {}
	for rid in T1:
		d[String(rid)] = 1 << heart
	return d

func _file_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()

# 주석을 걷어낸 소스(설계 주석에 든 낱말이 금칙어 스캔에 걸리지 않게 — 조연 스위트 `_src` 결).
func _code_only(path: String) -> String:
	var out := PackedStringArray()
	for ln in _file_text(path).split("\n"):
		if not String(ln).strip_edges().begins_with("#"):
			out.append(String(ln))
	return "\n".join(out)

func _scan_words(text: String, words: Array) -> String:
	for w in words:
		if text.contains(String(w)):
			return String(w)
	return ""

func _joined(pack) -> String:
	return "\n".join(PackedStringArray(pack))

# 지금 정답이 **아닌** 파편 하나(허브·이미 이은 것 제외). 오답 경로를 결정적으로 고른다.
func _wrong_index(s: SpineReconstruction, n: int) -> int:
	var want := s.next_index()
	for i in n:
		if i != want and i != Spine.HUB_INDEX and not s.is_linked(i):
			return i
	return Spine.HUB_INDEX

# 구역 라벨 중 이 낱말을 문 텍스트("" = 없음).
func _label_with(m: Node, needle: String) -> String:
	for lbl in m._labels:
		if lbl is Label and String((lbl as Label).text).contains(needle):
			return String((lbl as Label).text)
	return ""

func _has_verb(steps: Array, verb: String) -> bool:
	for s in steps:
		if typeof(s) == TYPE_DICTIONARY and String((s as Dictionary).get("verb", "")) == verb:
			return true
	return false

func _max_fade(steps: Array) -> float:
	var top := 0.0
	for s in steps:
		if typeof(s) == TYPE_DICTIONARY and String((s as Dictionary).get("verb", "")) == "fade":
			top = maxf(top, float((s as Dictionary).get("to", 0.0)))
	return top

# 세션을 입력 대본대로 굴린다 — 결정성 비교의 공통 입력(⑤).
# 대본 항목: {"tick": n} · {"cur": ±1} · {"pick": index} · {"next": true}(정답 잇기)
func _run_script(session: SpineReconstruction, script: Array) -> String:
	for step in script:
		var s: Dictionary = step
		if s.has("tick"):
			for _i in int(s["tick"]):
				session.tick()
		elif s.has("cur"):
			session.move_cursor(int(s["cur"]))
		elif s.has("pick"):
			session.link(int(s["pick"]))
		elif s.has("next"):
			session.link(session.next_index())
	return session.trace_text()


func _init() -> void:
	print("── spine_test ──")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ① 게이트 AND 전수([narrative-bible §6.1]) ────────────────────────────
	print("── ① 해결 게이트 AND 전수 ──")
	var full_stage := _stages(Spine.MAIN_STAGE)
	var full_bits := _bits(Spine.CHORUS_HEART)
	_check("①a 세 항이 다 차면 열린다", Spine.gate_ok(full_stage, true, full_bits))
	var terms := Spine.gate_terms(full_stage, true, full_bits)
	_check("①b 항이 **이름 붙어** 따로 보인다(keys·void·chorus)",
		bool(terms["keys"]) and bool(terms["void"]) and bool(terms["chorus"]))
	_check("①c 공허 비트(B4)가 없으면 닫힌다", not Spine.gate_ok(full_stage, false, full_bits))
	var keys_fail := 0
	for rid in MAINS:
		var s := full_stage.duplicate()
		s[String(rid)] = Spine.MAIN_STAGE - 1        # 그 한 사람만 ♡3(씨앗까지)
		if Spine.gate_ok(s, true, full_bits) or bool(Spine.gate_terms(s, true, full_bits)["keys"]):
			keys_fail += 1
	_check("①d 세 조각은 **AND**다 — 메인 한 사람만 ♡3이어도 전부 닫힌다(OR 아님 · %d인 전수)"
		% MAINS.size(), keys_fail == 0)
	var chorus_fail := 0
	for rid in T1:
		var b := full_bits.duplicate()
		b.erase(String(rid))                          # 그 한 사람의 ♡3 고백만 비었다
		if Spine.gate_ok(full_stage, true, b) or bool(Spine.gate_terms(full_stage, true, b)["chorus"]):
			chorus_fail += 1
	_check("①e 조연도 **전원**이다 — 한 사람만 빠져도 닫힌다(%d인 전수 · threshold 아님)"
		% T1.size(), chorus_fail == 0)
	_check("①f 빈 원장으로는 어느 항도 안 선다", not Spine.gate_ok({}, false, {}))
	_check("①g 조연의 ♡3 판정은 **비트**다 — ♡4 비트만 있고 ♡3이 없으면 안 쳐 준다",
		not Spine.gate_ok(full_stage, true, _bits(Spine.CHORUS_HEART + 1)))
	_check("①h 메인 ♡5(초과)도 통과다(진급은 단조 — 상한으로 막지 않는다)",
		Spine.gate_ok(_stages(Spine.MAIN_STAGE + 1), true, full_bits))

	# ── ② 로스터 박제 정합(안전장치 ㉑ — §6.2) ───────────────────────────────
	print("── ② 로스터 박제(안전장치 ㉑) ──")
	var m: Node = await _new_main()
	_drain(m)   # 부팅 온보딩 대화를 비운다
	_check("②a T1 로스터가 11인이다([narrative-bible] T1 정원)", T1.size() == 11)
	_check("②b 중복이 없다", T1.size() == _uniq(T1).size())
	var missing := ""
	for rid in T1:
		if m._resident(String(rid)) == null:
			missing = String(rid)
	_check("②c ★박제 ⊆ 실제 레지스트리 — 11인이 전부 실존 주민이다(오타 = 영영 안 닫히는 게이트)%s"
		% ("" if missing == "" else " · 없는 id: " + missing), missing == "")
	var not_in_soft := ""
	for rid in T1:
		if not m.CHORUS_GATE_ROSTER.has(String(rid)):
			not_in_soft = String(rid)
	_check("②d 박제 ⊆ 소프트 게이트 ㉠ 명단(지금은 같은 11인 — **부분집합**으로만 재어 갈라짐을 허용한다)",
		not_in_soft == "")
	var shop_hit := ""
	for rid in SHOPKEEPERS:
		if T1.has(String(rid)):
			shop_hit = String(rid)
	_check("②e ★점주 5인(T2)이 요구 밖이다 — 그들에겐 그날 밤 고백 자체가 없다", shop_hit == "")
	_check("②f ★옥자가 요구 밖이다(옥자 트랙은 B6 **후** — [ADR-0068] 결정 10)",
		not T1.has("okja") and not MAINS.has("okja"))
	_check("②g 메인 3인 = 세 조각의 주인(소프트 게이트의 증인 명단과 같은 셋)",
		MAINS.size() == 3 and Array(m.CHORUS_GATE_MAINS) == Array(MAINS))
	_check("②h 파편 수가 **로스터에서 파생**된다(하드코딩 산술 0) — 3 + 11 + 공허 1 = %d"
		% Spine.fragment_count(),
		Spine.fragment_count() == MAINS.size() + T1.size() + 1
		and Spine.fragments().size() == Spine.fragment_count())
	var frags := Spine.fragments()
	_check("②i 파편 0번이 **자기 공허**(허브)이고 rid가 없다(사람이 아니라 나 자신)",
		Spine.HUB_INDEX == 0 and String(frags[0]["kind"]) == Spine.KIND_VOID
		and String(frags[0]["rid"]) == "")
	var kinds := {Spine.KIND_KEY: 0, Spine.KIND_ECHO: 0, Spine.KIND_VOID: 0}
	for f in frags:
		kinds[String(f["kind"])] = int(kinds[String(f["kind"])]) + 1
	_check("②j 세 열쇠(메인 ♡4) + 열한 증거(조연 ♡3) + 공허 하나로 갈린다",
		kinds[Spine.KIND_KEY] == MAINS.size() and kinds[Spine.KIND_ECHO] == T1.size()
		and kinds[Spine.KIND_VOID] == 1)
	var pos_ok := Spine.star_pos(0, frags.size()) == Vector2.ZERO
	var far_ok := true
	for i in range(1, frags.size()):
		var p := Spine.star_pos(i, frags.size())
		if p.length() < 0.3 or p.length() > 1.0:
			far_ok = false
	_check("②k 별자리 배치 = 순수 결정 함수(허브는 정중앙 · 나머지는 −1..1 고리 안)", pos_ok and far_ok)

	# ── ③ 게이트 미충족 = 옥자 집 잠금 **불변** ─────────────────────────────
	print("── ③ 미충족 시 잠금 불변 ──")
	m._spine_bits = 0
	m._heart_bits = {}
	_stand_at_door(m)
	_check("③a 문 칸에 서 있고 구역도 맞다(전제)",
		m._region == RegionCatalog.MIHOK_FOREST and m._player_tile() == m.OKJA_HUT_DOOR)
	_check("③b 게이트가 안 찼다", not m._spine_gate_ok())
	m._maybe_spine_b5()
	_check("③c ★아무 일도 일어나지 않는다(컷신 0 · 예약 0 · 내면 공간 0 · 비트 0)",
		m.cutscene == null and not m._spine_b5_pending and m.spine_puzzle == null
		and not m._spine_bit_seen(m.SPINE_B5))
	_check("③d 실내로도 안 들어간다 — 옥자 집엔 **방이 없다**(카탈로그 미등록 유지)",
		m._indoor == "" and not m._buildings.has("옥자 집"))
	_check("③e 라벨이 여전히 잠김 문구다(게이트 전 문구는 한 글자도 안 바뀐다 — 거동 불변)",
		_label_with(m, "옥자 집").contains("잠김"))
	# 항을 둘만 채워도 여전히 잠김(AND의 실동작 확인 — 라이브 경로에서 한 번 더).
	for rid in MAINS:
		_set_heart(m._resident(String(rid)), Spine.MAIN_STAGE)
	m._mark_spine_bit(m.SPINE_B4)
	m._maybe_spine_b5()
	_check("③f ★두 항(세 조각 + 공허)만으로는 안 열린다 — 조연 코러스가 세 번째 열쇠다",
		m.cutscene == null and m.spine_puzzle == null and not m._spine_bit_seen(m.SPINE_B5))

	# ── ④ 충족 = 진입 개방 + 척추 발동(§6.5 1~2단) ──────────────────────────
	print("── ④ 게이트 충족 → 발동 ──")
	_check("④a B5 컷신이 **4동사 안**이고 npc 동사 0이며 완전 암전까지 간다",
		CutsceneRunner.new(Spine.B5_CUTSCENE).rejected_verbs().is_empty()
		and not _has_verb(Spine.B5_CUTSCENE, "npc")
		and _max_fade(Spine.B5_CUTSCENE) >= 1.0
		and _has_verb(Spine.B5_CUTSCENE, "clock"))
	_fill_gate(m)
	_check("④b 게이트가 찼다", m._spine_gate_ok())
	var mute_before: bool = m.audio.is_muted()
	m._maybe_spine_b5()
	_check("④c ★문 칸을 밟는 순간 발동한다(컷신 재생 + 내면 공간 예약)",
		m.cutscene != null and m._spine_b5_pending)
	_check("④d ★적막 — 인게임 소음이 소거된다(§6.5 2단)", m.audio.is_muted())
	_settle(m)
	_check("④e ★컷신이 끝나는 그 프레임에 내면 공간이 열린다(세계 복귀가 한 프레임도 안 보인다)",
		m.spine_puzzle != null and m.cutscene == null and not m._spine_b5_pending)
	_check("④f 내면엔 시간이 없다(시계 정지) · 걸어 다닐 수 없다(이동 잠금)",
		not m.clock.running and not m.player.is_physics_processing())
	_check("④g ★**화자 없는** 오프닝 지문이 선다(이름판 공백 = 내면엔 이름이 없다)",
		m.dialogue.is_open() and m.dialogue.speaker() == ""
		and m.dialogue.line() == String(Spine.B5_OPEN_LINES[0]))
	_check("④h 실내 방은 여전히 없다(진입 = 암전이지 건물 출입이 아니다)", m._indoor == "")
	_check("④i 파편이 로스터만큼 떠 있다(허브 포함 %d)" % Spine.fragment_count(),
		m.spine_puzzle.count() == Spine.fragment_count()
		and m.spine_puzzle.need_count() == Spine.fragment_count() - 1)
	_drain(m)   # 오프닝 지문을 넘긴다 — 이제 플레이어가 잇기 시작한다
	_check("④j 지문이 닫혀도 화면은 아직 내 안이다(세션 유지 · 이동 잠금 유지)",
		m.spine_puzzle != null and not m.player.is_physics_processing())

	# ── ⑤ 결정성(FishingSession 규범) ───────────────────────────────────────
	print("── ⑤ 퍼즐 결정성 ──")
	var script := [{"tick": 5}, {"cur": 1}, {"cur": 1}, {"pick": 2}, {"next": true},
		{"tick": SpineReconstruction.HINT_IDLE_TICKS}, {"cur": -1}, {"next": true}, {"pick": 0}]
	var n_frag := Spine.fragment_count()
	var a := SpineReconstruction.new(7788, n_frag, Spine.HUB_INDEX); a.start()
	var b := SpineReconstruction.new(7788, n_frag, Spine.HUB_INDEX); b.start()
	var ta := _run_script(a, script)
	var tb := _run_script(b, script)
	_check("⑤a 같은 시드 + 같은 입력 열 = 같은 전이열", ta == tb and ta != "")
	var c := SpineReconstruction.new(20260813, n_frag, Spine.HUB_INDEX); c.start()
	_check("⑤b 시드가 다르면 이을 순서가 다르다(별자리가 매번 같으면 시드가 무의미하다)",
		_run_script(c, script) != ta)
	var d := SpineReconstruction.new(7788, n_frag, Spine.HUB_INDEX); d.start()
	var seen := {}
	var dup := false
	for _i in d.need_count():
		var nx := d.next_index()
		if nx == Spine.HUB_INDEX or seen.has(nx):
			dup = true
		seen[nx] = true
		d.link(nx)
	_check("⑤c 순서가 **허브를 뺀 전 파편의 순열**이다(빠짐·중복 0)",
		not dup and seen.size() == n_frag - 1 and d.is_done())
	_check("⑤d 벽시계를 안 탄다 — 무입력 판정이 tick 수다(`tick()`이 delta를 안 받는다)",
		not _code_only("res://spine_puzzle.gd").contains("Time.")
		and not _code_only("res://spine_puzzle.gd").contains("delta"))

	# ── ⑥ 무실패([narrative-bible §6.5] 4) ─────────────────────────────────
	print("── ⑥ 무실패 ──")
	var e := SpineReconstruction.new(4242, n_frag, Spine.HUB_INDEX); e.start()
	var right := e.next_index()
	var wrong_hits := 0
	for i in n_frag:
		if i != right and e.link(i):
			wrong_hits += 1
	_check("⑥a 틀린 연결은 **조용히 안 이어진다**(성사 0 · 진행 0)",
		wrong_hits == 0 and e.linked_count() == 0 and e.is_active())
	_check("⑥b 오답을 %d번 반복해도 상태가 안 상한다(감점·되돌림·종료 전부 없다)" % e.wrong_count(),
		e.wrong_count() > 0 and e.is_active() and not e.is_done() and e.next_index() == right)
	_check("⑥c 허브(자기 자신)를 찍어도 무해하다", not e.link(Spine.HUB_INDEX) and e.is_active())
	for _i in 5000:
		e.tick()
	_check("⑥d ★타임아웃이 없다 — 5000 tick을 흘려도 종료되지 않는다(무실패의 시간 축)",
		e.is_active() and not e.is_done())
	while not e.is_done():
		e.link(e.next_index())
	_check("⑥e 오답 뒤에도 정답 열만 채우면 반드시 끝난다(막다른 길 0)",
		e.is_done() and e.linked_count() == e.need_count())
	_check("⑥f 상태 열거에 **실패 상태가 없다**(FAILED가 없는 것이 무실패의 구현)",
		not SpineReconstruction.State.has("FAILED")
		and SpineReconstruction.State.size() == 3)

	# ── ⑦ 🟡 확증선 = 강림 안전장치(§6.5 4 · [ADR-0068] 결정 8) ─────────────
	print("── ⑦ 🟡 확증선(강림 안전장치) ──")
	var h := SpineReconstruction.new(31337, n_frag, Spine.HUB_INDEX); h.start()
	_check("⑦a 시작하자마자는 지시가 없다(먼저 스스로 해 보게 둔다)", h.hint_index() < 0)
	for _i in SpineReconstruction.HINT_IDLE_TICKS - 1:
		h.tick()
	_check("⑦b 문턱 직전까지는 아직 없다", h.hint_index() < 0 and h.hint_count() == 0)
	h.tick()
	_check("⑦c ★무입력이 이어지면 **다음 올바른 파편**을 지시한다",
		h.hint_index() == h.next_index() and h.hint_count() == 1)
	for _i in SpineReconstruction.HINT_REPEAT_TICKS:
		h.tick()
	_check("⑦d 계속 무입력이면 지문이 다음 것으로 넘어간다(같은 말 반복 안 함)", h.hint_count() == 2)
	h.move_cursor(1)
	_check("⑦e ★스스로 움직이면 지시가 물러난다(곁을 지킬 뿐 대신 풀지 않는다)",
		h.hint_index() < 0 and h.idle_ticks() == 0)
	for _i in SpineReconstruction.HINT_IDLE_TICKS:
		h.tick()
	var armed_before := h.hint_index()
	h.link(_wrong_index(h, n_frag))
	_check("⑦f ★빗나간 시도는 지시를 **뺏지 않는다**(헤매는 사람에게서 안전장치를 거두지 않는다)",
		armed_before >= 0 and h.hint_index() == armed_before)
	# 본문 — 지문이어야 하고, 강림을 호명해서도 말을 시켜서도 안 된다.
	var hint_text := _joined(Spine.B5_HINT_LINES)
	var all_stage := true
	for ln in Spine.B5_HINT_LINES:
		var s := String(ln).strip_edges()
		if not (s.begins_with("(") and s.ends_with(")")):
			all_stage = false
	_check("⑦g ★전 줄이 **지문**이다(괄호로 열고 닫는다 — 대사가 아니다)", all_stage)
	_check("⑦h ★「」로 묶인 말이 0줄이다(말하는 순간 봉인의 법칙이 깨진다 — §2.2)",
		not hint_text.contains("「") and not hint_text.contains("」")
		and not hint_text.contains("\""))
	_check("⑦i ★강림을 **호명하지 않는다**(\"그림자\"까지 — 이름을 부르면 그의 발화로 읽힌다)",
		not hint_text.contains("강림") and not hint_text.contains("차사"))
	_check("⑦j 지문 순환이 결정적이다(같은 n = 같은 줄 · 범위 밖도 안전)",
		Spine.hint_line(0) == Spine.hint_line(Spine.B5_HINT_LINES.size())
		and Spine.hint_line(-1) != "")
	# ★ gangrim.gd 무접촉 — gangrim_arc_test ⑩g·⑩h가 잠근 그 계약을 여기서도 되짚는다.
	# ★ 스캔 대상은 **주석을 걷어낸 코드**다(그쪽 스위트의 `_src`와 같은 눈금): 강림 파일의 머리말
	#   ㉣이 "여기 쓰지 않는다"는 것을 설명하느라 그 문구를 인용하고 있어, 원문을 재면 *예약 주석의
	#   존재 자체*가 위반으로 잡힌다.
	_check("⑦k ★gangrim.gd가 척추를 여전히 소유하지 않는다(SPINE·spine 0회 — ⑩h 불변)",
		not _code_only("res://gangrim.gd").contains("SPINE")
		and not _code_only("res://gangrim.gd").contains("spine"))
	_check("⑦l ★강림 **본문**에 확증선 문구가 여전히 0줄이다(주인은 척추 쪽 — ⑩g 불변)",
		not _code_only("res://gangrim.gd").contains("마침내")
		and not _code_only("res://gangrim.gd").contains("닿았구나")
		and not _code_only("res://gangrim.gd").contains("이제 알겠구나"))
	# 라이브 경로 — main이 지시를 알림 채널로 흘리는가.
	var live_hints: int = m.spine_puzzle.hint_count()
	for _i in SpineReconstruction.HINT_IDLE_TICKS + 1:
		m._tick_spine_puzzle()
	_check("⑦m 라이브에서도 지시가 선다(main이 tick을 굴리고 지문을 알림으로 흘린다)",
		m.spine_puzzle.hint_count() > live_hints and m.spine_puzzle.hint_index() >= 0)

	# ── ⑧ 완료 = B5 비트 + 자동 저장 + 원복 ─────────────────────────────────
	print("── ⑧ 완료 · 비트 · 세이브 왕복 ──")
	_check("⑧a 완료 전엔 B5 비트가 0이다", not m._spine_bit_seen(m.SPINE_B5))
	var guard := 0
	while not m.spine_puzzle.is_done() and guard < 100:
		m.spine_puzzle.link(m.spine_puzzle.next_index())
		guard += 1
	m._tick_spine_puzzle()
	_check("⑧b ★마지막 선이 이어지면 B5 비트가 선다", m._spine_bit_seen(m.SPINE_B5))
	_check("⑧c 완료 지문이 열린다(화자 없음 — 오프닝과 같은 문법)",
		m.dialogue.is_open() and m.dialogue.speaker() == ""
		and m.dialogue.line() == String(Spine.B5_DONE_LINES[0]))
	_check("⑧d 지문이 도는 동안에도 화면은 내 안이다(세션 유지 = 암전 유지)", m.spine_puzzle != null)
	_drain(m)
	_check("⑧e ★지문이 닫히면 세계로 돌아온다(세션 해제 · 이동 · 시계 · 소리 원복)",
		m.spine_puzzle == null and m.player.is_physics_processing()
		and m.clock.running and m.audio.is_muted() == mute_before)
	_check("⑧f 화면 잔류 0(암전·카메라 오프셋이 안 남는다)",
		is_equal_approx(m.fade.modulate.a, 0.0) and m._cam.offset.is_equal_approx(Vector2.ZERO))
	_check("⑧g 다른 척추 비트는 안 건드린다 — B4·B5만 서 있다(B6~B7은 S9b-T8 소관)",
		m._spine_bits == ((1 << m.SPINE_B4) | (1 << m.SPINE_B5)))
	_stand_at_door(m)   # 구역 재빌드 = 라벨 재배치
	_check("⑧h ★라벨이 게이트 실태를 되쏜다(나락 진입로 점등과 같은 문법 — 잠김 문구가 걷힌다)",
		m._spine_gate_ok() and not _label_with(m, "옥자 집").contains("잠김")
		and _label_with(m, "옥자 집") != "")
	var bits_before: int = m._spine_bits
	m._save_game()
	m.free()
	var m2: Node = await _new_main()
	_drain(m2)
	_check("⑧i ★세이브 왕복에 B5 비트가 보존된다(가법 키는 여전히 \"spine_bits\" 하나)",
		m2._spine_bits == bits_before and m2._spine_bit_seen(m2.SPINE_B5))
	_check("⑧j 로드 직후 내면 공간·예약은 언제나 0이다(세션은 세이브 대상이 아니다)",
		m2.spine_puzzle == null and not m2._spine_b5_pending and not m2._spine_b5_closing)

	# ── ⑨ 금칙어 스캔(31어 + 강림 🔴 4종 · 중심 진실) ───────────────────────
	print("── ⑨ 봉인 법칙 금칙어 ──")
	var corpus := _joined(Spine.B5_OPEN_LINES) + "\n" + _joined(Spine.B5_HINT_LINES) \
		+ "\n" + _joined(Spine.B5_DONE_LINES)
	var hit := _scan_words(corpus, FORBIDDEN)
	_check("⑨a 조연 31어 스캔 0%s" % ("" if hit == "" else " · 걸린 낱말: " + hit), hit == "")
	_check("⑨b ★「옥자」가 본문에 0회다(중심 진실 4종이 전부 그 명명을 요구한다 — 가장 강한 프록시)",
		not corpus.contains("옥자"))
	_check("⑨c ★척추 코드에도 「옥자」가 0회다(설계 주석은 제외 — 조연 스위트 `_src` 결)",
		not _code_only("res://spine.gd").contains("옥자")
		and not _code_only("res://spine_puzzle.gd").contains("옥자"))
	_check("⑨d ★B6의 중심 진실을 선점하지 않는다(\"당신이었군요\"·귀환의 문장 0)",
		not corpus.contains("당신이었군요") and not corpus.contains("연인")
		and not corpus.contains("마녀") and not corpus.contains("봉인"))
	_check("⑨e ★평결을 대신 내리지 않는다(플레이어의 죄목을 명명하는 문장 0 — §2.2)",
		not corpus.contains("네 죄") and not corpus.contains("내 죄는")
		and not corpus.contains("그러니까"))
	_check("⑨f 본문 전량이 **화자 없는 내면**이다(이름판 공백)", Spine.INNER_SPEAKER == "")
	_check("⑨g 세 묶음이 다 서 있다(오프닝 %d줄 · 지시 %d줄 · 완료 %d줄)"
		% [Spine.B5_OPEN_LINES.size(), Spine.B5_HINT_LINES.size(), Spine.B5_DONE_LINES.size()],
		Spine.B5_OPEN_LINES.size() >= 4 and Spine.B5_HINT_LINES.size() >= 2
		and Spine.B5_DONE_LINES.size() >= 4)

	# ── ⑩ 재진입 가드 ───────────────────────────────────────────────────────
	print("── ⑩ 재진입 가드 ──")
	_stand_at_door(m2)
	_check("⑩a 복원된 세이브에서도 게이트는 여전히 열려 있다(원장이 전부 살아 있다)",
		m2._spine_gate_ok() and m2._player_tile() == m2.OKJA_HUT_DOOR)
	for _i in 5:
		m2._maybe_spine_b5()
	_check("⑩b ★B5 기성립이면 같은 문 칸을 몇 번을 밟아도 재발동 0(비트가 유일한 방어선)",
		m2.cutscene == null and m2.spine_puzzle == null and not m2._spine_b5_pending
		and not m2.dialogue.is_open())
	_check("⑩c 원장도 안 늘어난다(B4·B5 그대로)", m2._spine_bits == bits_before)
	m2.free()

	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ spine_test 전체 통과 ══")
	else:
		print("══ spine_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)


# ── 금칙어(31어) — 조연 스위트와 **같은 배열**을 척추 본문에 상속한다([ADR-0068] 결정 6) ──
const FORBIDDEN := [
	# 플레이어 죄목의 평결(공통 18어)
	"네 죄는", "너의 죄는", "네가 지은 죄", "네 죄목", "그러니까 네가",
	"너 때문에 옥자", "네가 옥자를", "너는 외면했", "네가 외면한",
	"너는 잊었", "네가 잊은 죄", "네가 버린 죄", "그게 네 죄", "네가 태워 없앤",
	"네가 방치했", "네가 버려둔", "네가 지키지 않아", "네가 없었기 때문",
	# 그날 밤의 판독 결론(5어)
	"옥자의 눈물", "강림의 명부", "차사 명부", "그날 밤에 일어난", "화재의 원인은",
	# ★중심 진실 4금지(옥자 희생 / 기억 봉인 / 마녀=연인 / 플레이어 죄목)
	"옥자가 널 살리", "옥자가 너를 살리", "자기를 바쳐", "종신계약을 대신",
	"기억을 봉인", "봉인된 기억", "옥자는 마녀가 됐", "옥자의 연인",
]

func _uniq(arr) -> Array:
	var seen := {}
	for v in arr:
		seen[String(v)] = true
	return seen.keys()
