extends SceneTree
# ★[S9b-T10] 척추 장기 스모크 — **한 세이브가 B0 이후 전 구간을 결정적으로 관통**한다.
# S9층 T10(`s9_narrative_smoke_test.gd`)이 Slice 9의 전 사슬을 한 판에서 굴린 그 규범을 승계하되,
# 이번에 관통하는 축이 다르다: 저쪽이 *가로*(관문·편지·물음·Books가 한 날 위에서 겹치는가)였다면
# 이쪽은 **세로**(B4 → B5 → B6 → B7 → 에필로그가 한 세이브 위에서 이어지는가)다.
#
# 무엇을 보증하나(이음매 전용 — 개별 계약의 상세 단언은 각 스위트가 소유한다):
#   ① 소프트 게이트 ㉠의 **순서** — 메인이 아직 ♡3에 못 닿았으면 조연 ♡3은 *대기*이고, 메인
#      한 사람이 씨앗을 본 뒤에야 같은 대화가 성사된다(점수 손실 0 — 대기지 잠금이 아니다).
#   ② 게이트 세 항이 **라이브 경로로** 찬다 — 메인 3인 ♡1~♡4 열두 관문과 조연 11인 ♡3 열한
#      관문을 전부 실제 대화로 굴려 `_heart_bits`를 채운다(다른 척추 스위트가 `_mark_heart_bit`
#      지름길로 세우는 그 원장을, 여기서는 플레이어와 같은 길로 세운다는 것이 이 스모크의 값이다).
#   ③ B5는 **공허 비트 없이는 안 열린다** — 두 항이 다 찬 상태로 문 칸을 밟아도 거동이 불변이다.
#   ④ B4 = 취침 2단(아침 훅이 판정·예약 → 눈뜨는 프레임에 재생)이 라이브 사슬로 성립한다.
#   ⑤ B5 = 문 칸 발동 → 별자리 퍼즐 **결정적 완주**(시드 = 날짜 파생이라 같은 날 재현이 같다) ·
#      🟡 확증선을 한 번 스치고 · 완료 즉시 저장이 **디스크에 실린다**.
#   ⑥ B6 = 이음매 0프레임 · 다화자 3막 · 앵커 트랙이 **원장 파생**임을 세 축 값 변경으로 실증.
#   ⑦ B7 = 강림 [F] 무상 부적 → 청혼 → 혼례 아침 **예약/재생 2단**(B4와 같은 문법) · 해방 비트.
#   ⑧ 에필로그 = 1회성 · 하트 스프라이트 · 닫으면 코지 샌드박스 복귀(게임 계속).
#   ⑨ 세이브 왕복 — 척추 네 비트 · 하트 비트 원장 · 앵커 트랙 · 혼인이 전부 부팅을 건넌다.
#
# ★ 관례(기존 스위트 상속 — 어기지 말 것):
#   · 하트 세팅은 points·stage **동반**이다(S8 이후 hearts() = stage).
#   · 드레인은 **컷신 재생 + 선택지 `has_choice → choose(0)`** 동반(절기 물음은 넘기기로 못 지난다).
#   · 화자가 갈리는 척추 장면은 `_drain_one`(한 묶음만)으로 끊어 읽는다 — `while is_open()`으로
#     돌면 다음 묶음이 같은 프레임에 열려 장면 전체가 한 번에 비워진다.
#   · 헤드리스는 반드시 game/에서 · 순차 실행(save.dat 전역 공유).
#
# 실행: TIMEOUT=400 ./run_tests.sh s9b_spine_smoke

const T1 := Spine.T1_ROSTER
const MAINS := Spine.MAIN_ROSTER

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

# 컷신만 끝까지 굴린다(대화는 안 닫는다 — 뒤따르는 첫 줄을 재야 한다).
func _settle(m: Node) -> void:
	var guard := 0
	while m.cutscene != null and guard < 400:
		m._tick_cutscene(0.2)
		guard += 1

# 판을 비운다 — 컷신 재생 → 선택지는 첫 항 → 나머지는 넘기기(플레이어와 같은 경로).
func _drain(m: Node) -> void:
	var guard := 0
	while (m.cutscene != null or m.dialogue.is_open()) and guard < 3000:
		if m.cutscene != null:
			m._tick_cutscene(0.2)
		elif m.dialogue.has_choice():
			m.dialogue.choose(0)
		else:
			m.dialogue.advance()
		guard += 1

# 지금 열린 **한 묶음만** 넘긴다(화자가 바뀌는 순간 멈춘다 — 다화자 척추 장면 전용).
func _drain_one(m: Node) -> void:
	var who: String = m.dialogue.speaker()
	var guard := 0
	while m.dialogue.is_open() and m.dialogue.speaker() == who and guard < 300:
		if m.dialogue.has_choice():
			m.dialogue.choose(0)
		else:
			m.dialogue.advance()
		guard += 1

func _set_heart(r: Resident, stage: int) -> void:
	r.affinity.stage = stage
	r.affinity.points = Affinity.MAX_POINTS

func _pass_day(m: Node) -> void:
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)

# 메인 3인의 deed 원장을 전 칸 충족으로 세운다(문턱의 주인은 각 아크 스위트다 — 여기서는
# 관문이 *열린다*는 사실만 필요하다. s9_narrative_smoke `_stock_deeds` 동형).
func _stock_deeds(m: Node) -> void:
	m._run_harvested = 100000          # 미호 = 누적 수확
	m._cafe_revenue_total = 100000     # 멜 = 누적 서빙 매출
	m.mine_floors._depth = 60          # 바나 ♡1 = 갱도 10층
	m._combat_xp = 999                 # 바나 ♡2 = 전투 XP
	m._narak_key_found = true          # 바나 ♡3 = 나락 개방
	m._narak_best_boss = 50            # 바나 ♡4 = 보스 격파 깊이

# 그 사람의 ♡1..♡4 관문 비트가 전부 섰는가.
func _arc_bits_set(m: Node, rid: String) -> bool:
	for h in range(1, m.HEART_GATE_MAX + 1):
		if not m._heart_bit_seen(rid, h):
			return false
	return true

func _stand_at_door(m: Node) -> void:
	m._rebuild_region(RegionCatalog.MIHOK_FOREST)
	m.player.global_position = m._tile_center_px(m.OKJA_HUT_DOOR)

func _label_with(m: Node, needle: String) -> String:
	for lbl in m._labels:
		if lbl is Label and String((lbl as Label).text).contains(needle):
			return String((lbl as Label).text)
	return ""

# 아이템을 손에 든다(청혼 = 든 아이템 문법 — marriage_test `_hold` 동형).
func _hold(m: Node, id: String) -> void:
	if not m.inventory.has_item(id):
		m.inventory.add_item(id, 1, ItemCatalog.Q_NORMAL)
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

# 안방 확장 완공(marriage_test ②가 태운 그 경로 그대로 — 배우자 방은 공통 관문이다).
func _expand_home(m: Node) -> void:
	m.wallet.gold = 10000
	var have: int = m.inventory.count_of(ItemCatalog.WOOD)
	if have < 300:
		m.inventory.add_item(ItemCatalog.WOOD, 300 - have)
	m._try_order_build(Carpenter.PROJ_MASTER_ROOM)
	_pass_day(m)
	_pass_day(m)

# 디스크에 실린 세이브의 척추 원장(즉시 저장 검증용 — main과 같은 슬롯 0).
func _saved_spine_bits() -> int:
	var probe := SaveManager.new()
	var data: Dictionary = probe.load_game(0)
	probe.free()
	return int(data.get("spine_bits", 0))


func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S9b-T10 척추 장기 스모크 — 소프트 게이트 → B4 → B5 → B6 → B7 → 에필로그 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_drain(m)                                   # 신규 시작의 앵커 통보 대화(B0)
	m.onboarding.step = Onboarding.DONE
	m.clock.day = 3                             # 주 첫날 아님(절기 물음이 관문에 겹치지 않게)
	_stock_deeds(m)

	# ── ① 소프트 게이트 ㉠ = **순서**([ADR-0068] 결정 6) ──────────────────────
	print("── ① 소프트 게이트 ㉠(조연 ♡3은 대화재 접촉 후) ──")
	var probe_rid := String(T1[0])
	var probe: Resident = m._resident(probe_rid)
	_set_heart(probe, Spine.CHORUS_HEART - 1)   # ♡2 만충 = 진급 대기 상태
	_check("①a 전제 — 메인 3인은 아직 씨앗(♡3)을 한 명도 안 봤다",
		not m._chorus_gate_ok(probe_rid, Spine.CHORUS_HEART))
	m._start_resident_dialogue(probe)
	_drain(m)
	_check("①b ★메인 씨앗 전에는 조연 ♡3이 **대기**다(칸도 비트도 안 오른다)",
		probe.affinity.stage == Spine.CHORUS_HEART - 1
		and not m._heart_bit_seen(probe_rid, Spine.CHORUS_HEART))
	_check("①c 대기는 잠금이 아니다 — 점수가 만충인 채 그대로 남는다(손실 0)",
		probe.affinity.points == Affinity.MAX_POINTS
		and probe.affinity.pending_promotion())

	# ── ② 게이트 세 항 중 둘을 **라이브 경로**로 채운다 ───────────────────────
	print("── ② 메인 3인 ♡1~♡4(라이브 관문) ──")
	for rid in MAINS:
		var r: Resident = m._resident(String(rid))
		for target in [1, 2, 3, 4]:
			_set_heart(r, target - 1)
			m._start_resident_dialogue(r)
			_drain(m)
		_check("②a %s 관문 ♡1~♡4가 전부 대화로 성사된다(비트 원장 4칸)" % r.display_name,
			_arc_bits_set(m, String(rid)) and r.affinity.stage == m.HEART_GATE_MAX)
	_check("②b ★열두 관문 뒤 화면·시계가 원복돼 있다(암전 잔류 0)",
		is_equal_approx(m.fade.modulate.a, 0.0) and m.clock.running
		and m._cam.offset.is_equal_approx(Vector2.ZERO) and m.cutscene == null)
	_check("②c 이제 소프트 게이트가 열렸다(메인 씨앗을 봤다)",
		m._chorus_gate_ok(probe_rid, Spine.CHORUS_HEART))

	print("── ③ 조연 11인 ♡3(라이브 관문) ──")
	m._start_resident_dialogue(probe)
	_drain(m)
	_check("③a ★같은 대화가 이제 성사된다(대기가 풀리면 그 자리에서 오른다 — %s)"
		% probe.display_name,
		probe.affinity.stage == Spine.CHORUS_HEART
		and m._heart_bit_seen(probe_rid, Spine.CHORUS_HEART))
	for rid in T1:
		var r3: Resident = m._resident(String(rid))
		if r3 == null or r3.affinity == null:
			continue
		if m._heart_bit_seen(String(rid), Spine.CHORUS_HEART):
			continue
		_set_heart(r3, Spine.CHORUS_HEART - 1)
		m._start_resident_dialogue(r3)
		_drain(m)
	var chorus_miss := ""
	for rid in T1:
		if not m._heart_bit_seen(String(rid), Spine.CHORUS_HEART):
			chorus_miss = String(rid)
	_check("③b ★조연 %d인 전원의 ♡3이 라이브로 섰다%s" % [T1.size(),
		"" if chorus_miss == "" else " · 빈 사람: " + chorus_miss], chorus_miss == "")
	var gt := Spine.gate_terms(m._spine_main_stages(), m._spine_bit_seen(m.SPINE_B4), m._heart_bits)
	_check("③c ★게이트 세 항 중 둘이 찼고 **공허(B4)만 비었다**(항이 이름으로 갈려 보인다)",
		bool(gt["keys"]) and bool(gt["chorus"]) and not bool(gt["void"]))

	# ── ④ 공허 비트 없이는 안 열린다(거동 불변) ──────────────────────────────
	print("── ④ B4 전 = 옥자 집 잠금 불변 ──")
	_stand_at_door(m)
	var label_before := _label_with(m, "옥자 집")
	_check("④a 문 칸에 서 있고 구역도 맞다(전제)",
		m._region == RegionCatalog.MIHOK_FOREST and m._player_tile() == m.OKJA_HUT_DOOR)
	for _i in 3:
		m._maybe_spine_b5()
	_check("④b ★두 항만으로는 아무 일도 안 일어난다(컷신 0 · 예약 0 · 내면 공간 0 · 비트 0)",
		m.cutscene == null and not m._spine_b5_pending and m.spine_puzzle == null
		and not m._spine_bit_seen(m.SPINE_B5) and not m.dialogue.is_open())
	_check("④c 라벨도 실내도 한 글자 안 바뀐다(거동 바이트 불변)",
		_label_with(m, "옥자 집") == label_before and label_before.contains("잠김")
		and m._indoor == "" and not m._buildings.has("옥자 집"))

	# ── ⑤ B4 = 취침 2단([ADR-0068] 결정 7) ───────────────────────────────────
	print("── ⑤ B4 공허 직면(취침 2단) ──")
	_check("⑤a 전제 — 방아쇠 인물의 ♡3이 위 라이브 루프에서 이미 섰다",
		m._heart_bit_seen(m.SPINE_B4_TRIGGER_RID, m.SPINE_B4_TRIGGER_HEART))
	_pass_day(m)
	_check("⑤b ★아침 훅은 **예약만** 한다(취침 연출 한가운데라 안 튼다 — 재생 0 · 비트 0)",
		m._spine_b4_armed and m.cutscene == null and not m._spine_bit_seen(m.SPINE_B4))
	# ★[폴리시 R2] **대화가 열려 있으면 접는다.** 24:00 강제 취침(`_on_collapsed`)은 긴 편지·책·주민
	#   대화를 연 채로도 아침을 넘기는데, 그 상태로 컷신을 틀면 `_end_cutscene`의 `dialogue.start`가
	#   이미 열린 대화 때문에 조용히 no-op이 되고(dialogue.gd `if is_open(): return`), 비트는 장면
	#   시작에 찍히므로 `_arm_spine_b4`가 그 뒤로 영영 early return = B4 10줄이 재생 경로 없이
	#   유실됐다. 접으면 비트를 안 찍고 물러나므로 **다음 아침에 그대로 다시 예약된다**.
	m.dialogue.start("", PackedStringArray(["가로막는 편지 한 줄"]))
	m.player.set_physics_process(false)   # 취침 연출이 잠근 상태를 재현(_do_sleep이 하는 일)
	m._on_sleep_done()
	_check("⑤b-R2 대화가 열려 있으면 재생을 접는다 — 비트 0 · 컷신 0(유실 0)",
		m.cutscene == null and not m._spine_bit_seen(m.SPINE_B4) and not m._spine_b4_armed)
	_check("⑤b-R2′ 대화창이 뜬 채로 이동 잠금이 풀리지 않는다",
		not m.player.is_physics_processing())
	_drain(m)
	_check("⑤b-R2″ 대화가 닫히면 이동 잠금이 풀린다(닫히는 프레임의 훅이 켠다)",
		not m.dialogue.is_open() and m.player.is_physics_processing())
	m._arm_spine_b4()
	_check("⑤b-R2‴ 다음 아침 훅이 **그대로 다시 예약한다**(비트를 안 찍었으므로)",
		m._spine_b4_armed and not m._spine_bit_seen(m.SPINE_B4))

	m._on_sleep_done()
	_check("⑤c ★눈을 뜨는 프레임에 정확히 1회 재생된다(비트 기록 · 예약 소진)",
		m.cutscene != null and m._spine_bit_seen(m.SPINE_B4) and not m._spine_b4_armed)
	_settle(m)
	_check("⑤d 재생이 끝나면 **화자 없는** 내면 대화가 열린다",
		m.dialogue.is_open() and m.dialogue.speaker() == ""
		and m.dialogue.line() == String(m.SPINE_B4_LINES[0]))
	_drain(m)
	_check("⑤e ★이제 세 항이 다 찼다 = 척추 해결 게이트가 열린다", m._spine_gate_ok())

	# ── ⑥ B5 = 문 칸 발동 · 결정적 완주 · 확증선 · 즉시 저장 ──────────────────
	print("── ⑥ B5 재구성 ──")
	_stand_at_door(m)
	_check("⑥a ★라벨이 게이트 실태를 되쏜다(잠김 문구가 걷힌다)",
		not _label_with(m, "옥자 집").contains("잠김") and _label_with(m, "옥자 집") != "")
	# 같은 날·같은 시드의 **참조 세션**을 미리 굴려 정답 열을 뽑는다(결정성의 눈금).
	var ref := SpineReconstruction.new(m._spine_b5_seed(), Spine.fragment_count(), Spine.HUB_INDEX)
	ref.start()
	var want_order: Array[int] = []
	while not ref.is_done():
		var nx: int = ref.next_index()
		want_order.append(nx)
		ref.link(nx)
	m._maybe_spine_b5()
	_check("⑥b ★문 칸을 밟는 순간 발동한다(컷신 + 내면 공간 예약 + 적막)",
		m.cutscene != null and m._spine_b5_pending and m.audio.is_muted())
	_settle(m)
	_check("⑥c ★컷신이 끝나는 그 프레임에 내면 공간이 열린다(세계 복귀 0프레임)",
		m.spine_puzzle != null and m.cutscene == null and not m._spine_b5_pending
		and not m.clock.running and not m.player.is_physics_processing())
	_check("⑥d 오프닝 지문이 화자 없이 선다 · 파편이 로스터 파생 수만큼 떠 있다",
		m.dialogue.is_open() and m.dialogue.speaker() == ""
		and m.dialogue.line() == String(Spine.B5_OPEN_LINES[0])
		and m.spine_puzzle.count() == Spine.fragment_count())
	_drain_one(m)
	# 🟡 확증선 — 무입력이 이어지면 다음 파편을 지시한다(한 번 스치고 지나간다).
	for _i in SpineReconstruction.HINT_IDLE_TICKS + 1:
		m._tick_spine_puzzle()
	_check("⑥e ★🟡 확증선을 한 번 스친다(무입력 tick이 차면 다음 올바른 파편을 지시)",
		m.spine_puzzle.hint_count() >= 1
		and m.spine_puzzle.hint_index() == m.spine_puzzle.next_index())
	var hint0 := Spine.hint_line(0).strip_edges()
	_check("⑥f 그 지문은 **전부 지문**이고 강림을 호명하지 않는다(§5.2)",
		hint0.begins_with("(") and hint0.ends_with(")")
		and not hint0.contains("「") and not hint0.contains("강림"))
	# 결정적 완주 — 참조 세션이 뽑은 그 순서 그대로 이어진다.
	var got_order: Array[int] = []
	var guard := 0
	while not m.spine_puzzle.is_done() and guard < 100:
		var nx2: int = m.spine_puzzle.next_index()
		got_order.append(nx2)
		m.spine_puzzle.link(nx2)
		guard += 1
	_check("⑥g ★같은 날 = 같은 별자리다(시드가 날짜 파생 — 참조 세션과 순서가 글자 그대로 같다 · %d칸)"
		% got_order.size(), got_order == want_order and got_order.size() == Spine.fragment_count() - 1)
	m._tick_spine_puzzle()
	_check("⑥h ★마지막 선이 이어지면 B5 비트가 서고 완료 지문이 돈다",
		m._spine_bit_seen(m.SPINE_B5) and m.dialogue.is_open()
		and m.dialogue.line() == String(Spine.B5_DONE_LINES[0]))
	_check("⑥i ★완료가 **디스크에 즉시 실린다**(여기서 껐다 켜도 같은 장면이 두 번 안 온다)",
		(_saved_spine_bits() & (1 << m.SPINE_B5)) != 0)

	# ── ⑦ B6 = 이음매 0프레임 · 다화자 3막 · 앵커 트랙 파생 ───────────────────
	print("── ⑦ B6 귀환 · 앵커 트랙 ──")
	var r_okja: Resident = m._resident("okja")
	_drain_one(m)                               # 완료 지문 → _close_spine_puzzle → B6
	_check("⑦a ★완료 지문이 닫히는 **그 자리**에서 B6가 이어 붙는다(내면 공간 해제 · 비트 · 재생)",
		m._spine_bit_seen(m.SPINE_B6) and m.spine_puzzle == null and m.cutscene != null)
	_settle(m)
	_check("⑦b 그림이 화면을 덮고(S등급) 첫 묶음은 화자 없는 내면이다",
		m._illust_id == Spine.ILLUST_B6 and m._illust_a > 0.0
		and m.dialogue.speaker() == "" and m.dialogue.line() == String(Spine.B6_RETURN_LINES[0]))
	_drain_one(m)
	_check("⑦c ★둘째 묶음에서 앵커가 처음 입을 연다(소유가 화자로 갈린다)",
		m.dialogue.is_open() and m.dialogue.speaker() == r_okja.display_name)
	var okja_said: String = m.dialogue.line()
	_check("⑦d 곁이 빈 경로의 본문이다(씁쓸한 축복 갈래가 아니다 — §6.4 두 갈래 중 이쪽)",
		m._spouse_id == "" and okja_said == String(r_okja.node.spine_lines("b6", false)[0])
		and String(r_okja.node.spine_lines("b6", true)[0]) != ""
		and r_okja.node.spine_lines("b6", true) != r_okja.node.spine_lines("b6", false))
	_drain_one(m)
	_check("⑦e 셋째 묶음이 다시 내면으로 돌아온다(내면 → 앵커 → 내면 3막)",
		m.dialogue.speaker() == "" and m.dialogue.line() == String(Spine.B6_CLOSE_LINES[0]))
	_drain(m)
	_check("⑦f ★장면이 끝나면 그림을 거두고 세계로 돌아온다(잔류 0 · 소리 복귀)",
		m._illust_id == "" and is_zero_approx(m._illust_a) and m._spine_say.is_empty()
		and m.player.is_physics_processing() and m.clock.running and not m.audio.is_muted())
	_stand_at_door(m)
	_check("⑦g ★앵커 집이 상시 개방으로 바뀐다(조건 문구 자체가 걷힌다)",
		_label_with(m, "옥자 집") == "옥자 집")
	# 앵커 트랙 — B6가 개통하고, 점수는 **원장에서 매번 다시 계산**된다.
	_check("⑦h ★B6가 트랙을 개통한다(Affinity·세이브 키가 이 순간에야 생긴다)",
		r_okja.affinity != null and r_okja.save_key == "okja_affinity" and m._okja_track_open())
	var donatable: int = Museum.donatable_ids().size()
	_check("⑦i 지금 점수가 원장 파생식과 정확히 일치한다(외면 ○ · 망각 0 · 부재 만점)",
		r_okja.affinity.points == Spine.okja_deed_points(true, m.museum.donated_count(),
			donatable, m._run_harvested))
	m._run_harvested = 0                        # ㉢ 부재 반전을 0으로 되돌린다
	m._refresh_okja_track()
	_check("⑦j ★부재 축이 값 파생이다 — 돌봄을 0으로 되돌리면 점수가 외면 한 축으로 내려온다",
		r_okja.affinity.points == Spine.OKJA_FACE_POINTS)
	for id in Museum.donatable_ids():           # ㉠ 망각 반전을 만점으로
		m.museum.donate(String(id), m.clock.day)
	m._refresh_okja_track()
	_check("⑦k ★망각 축도 값 파생이다 — 전부 되찾으니 두 축치가 된다(적립이 아니라 재계산)",
		r_okja.affinity.points == Spine.OKJA_FACE_POINTS + Spine.OKJA_MEMORY_POINTS
		and m.museum.donated_count() == donatable)
	m._run_harvested = Spine.OKJA_TEND_HARVEST  # ㉢ 다시 만점으로
	m._refresh_okja_track()
	_check("⑦l ★세 축이 다 차면 그 자리에서 ♡max다(칸도 파생 — 진급 대기라는 상태가 없다)",
		r_okja.affinity.points == Affinity.MAX_POINTS
		and r_okja.affinity.hearts() == Affinity.MAX_HEARTS
		and not r_okja.affinity.pending_promotion())

	# ── ⑧ B7 = 강림 [F] → 청혼 → 혼례 아침 2단 ───────────────────────────────
	print("── ⑧ B7 해방 ──")
	var r_gangrim: Resident = m._resident("gangrim")
	var gold_before: int = m.wallet.gold
	_check("⑧a ★정표 특별판의 창구가 **명부의 주인**이다([F] 프롬프트가 그에게 선다 — §6.3)",
		m._myeongbu_quest_open() and r_gangrim.prompt_extra.is_valid()
		and String(r_gangrim.prompt_extra.call()).contains("[F]"))
	var granted: bool = r_gangrim.shop_key.call()
	_check("⑧b ★값이 없다 — 명부에 이름을 올리는 일은 사고팔 수 없다(냥 변화 0)",
		granted and m.inventory.has_item(ItemCatalog.MYEONGBU_CHARM)
		and m.wallet.gold == gold_before)
	_check("⑧c 정표를 쥐면 의뢰가 닫힌다(세상에 하나뿐 — [F] 프롬프트도 걷힌다)",
		not m._myeongbu_quest_open() and String(r_gangrim.prompt_extra.call()) == "")
	_hold(m, ItemCatalog.MYEONGBU_CHARM)
	m._try_propose_okja()
	_check("⑧d 방이 없으면 **무소모 거절**이다(부적 보존 — 다른 로스터의 거절과 같은 계약)",
		m._wedding_day == 0 and m.inventory.has_item(ItemCatalog.MYEONGBU_CHARM))
	_expand_home(m)
	_hold(m, ItemCatalog.MYEONGBU_CHARM)
	m._try_propose_okja()
	_check("⑧e ★네 항이 다 차면 혼례가 정해진다(B6 · deed ♡max · 정표 · 배우자 방)",
		m._wedding_day == m.clock.day + m.WEDDING_WAIT_DAYS and m._romance_partner == "okja"
		and not m.inventory.has_item(ItemCatalog.MYEONGBU_CHARM))
	var wed_day: int = m._wedding_day
	while m.clock.day < wed_day:
		_pass_day(m)
		_drain(m)
	_check("⑧f ★혼례 아침이 예약만 한다(B4와 완전히 같은 두 단계 — 재생 0 · 비트 0)",
		m._spouse_id == "okja" and m._spine_b7_armed and not m._spine_bit_seen(m.SPINE_B7))
	m._on_sleep_done()
	_check("⑧g ★눈을 뜨는 프레임에 해방이 재생된다(비트 · S등급)",
		m._spine_bit_seen(m.SPINE_B7) and m.cutscene != null and not m._spine_b7_armed)
	_settle(m)
	_check("⑧h 그림이 바뀌고(귀환 → 해방) 주례는 **지문뿐**이다(화자 없이 선다)",
		m._illust_id == Spine.ILLUST_B7 and m.dialogue.speaker() == ""
		and m.dialogue.line() == String(Spine.B7_OFFICIANT_LINES[0]))
	_drain_one(m)
	_check("⑧i 둘째 묶음이 앵커의 말이다", m.dialogue.speaker() == r_okja.display_name)
	_drain_one(m)
	_check("⑧j 셋째 묶음이 해방의 내면이고 에필로그가 예약된다",
		m.dialogue.speaker() == "" and m.dialogue.line() == String(Spine.B7_RELEASE_LINES[0])
		and m._epilogue_pending and not m._epilogue_open)
	_check("⑧k ★척추 원장이 B4~B7 네 비트로 닫힌다(게임에 결말이 섰다)",
		m._spine_bits == ((1 << m.SPINE_B4) | (1 << m.SPINE_B5) | (1 << m.SPINE_B6)
			| (1 << m.SPINE_B7)))

	# ── ⑨ 에필로그([ADR-0068] 결정 11) ───────────────────────────────────────
	print("── ⑨ 에필로그 ──")
	_drain(m)
	_check("⑨a ★마지막 묶음이 닫히면 에필로그가 뜬다(회고 화면 · 시계·이동 잠금)",
		m._epilogue_open and m.ending_panel.visible and not m._epilogue_pending
		and not m.clock.running and not m.player.is_physics_processing())
	_check("⑨b ★`_run_over`가 아니다 — 이건 게임의 끝이 아니다", not m._run_over)
	_check("⑨c 하트가 **스프라이트**다(문자열 ♥ 막대가 아니다) · 배우자가 맨 윗줄이다",
		m._epilogue_hearts != null and m._epilogue_hearts.get_child_count() > 0
		and m._epilogue_hearts.get_child(0) is HeartBar
		and (m._epilogue_hearts.get_child(0) as HeartBar)._name_label.text == r_okja.display_name
		and not m.ending_text.text.contains("♥"))
	m._on_ending_button()
	_check("⑨d ★닫으면 코지 샌드박스로 돌아간다(시계·이동 재개 · 게임 계속)",
		not m._epilogue_open and not m.ending_panel.visible and m.clock.running
		and m.player.is_physics_processing() and not m._run_over
		and m.ending_restart.text == "처음부터 다시 시작")
	m._fire_spine_b7()
	for _i in 3:
		m._maybe_spine_b5()
		m._fire_spine_b6()
	_check("⑨e ★1회성 — 척추도 에필로그도 스스로 다시 안 뜬다(비트가 유일한 방어선)",
		m.cutscene == null and not m._epilogue_open and m.spine_puzzle == null
		and not m.dialogue.is_open()
		and m._spine_bits == ((1 << m.SPINE_B4) | (1 << m.SPINE_B5) | (1 << m.SPINE_B6)
			| (1 << m.SPINE_B7)))

	# ── ⑩ 세이브 왕복(한 세이브가 관통을 통째로 기억한다) ─────────────────────
	print("── ⑩ 세이브 왕복 ──")
	var bits_final: int = m._spine_bits
	var okja_pts: int = r_okja.affinity.points
	var heart_bits_final: Dictionary = m._heart_bits.duplicate()
	m._save_game()
	m.free()
	var m2: Node = await _new_main()             # _ready가 자동 복원
	_drain(m2)
	_check("⑩a ★척추 네 비트가 부팅을 건넌다", m2._spine_bits == bits_final
		and m2._spine_bit_seen(m2.SPINE_B7))
	var bits_ok := true
	for rid in heart_bits_final:
		if int(m2._heart_bits.get(String(rid), 0)) != int(heart_bits_final[rid]):
			bits_ok = false
	_check("⑩b 하트 비트 원장도 그대로다(메인 12관문 + 조연 11관문 · %d인)"
		% heart_bits_final.size(), bits_ok and m2._spine_gate_ok())
	var r2_okja: Resident = m2._resident("okja")
	_check("⑩c ★앵커 트랙이 복원된다 — 로드가 Affinity를 **먼저** 만들어 저장된 칸을 받는다",
		r2_okja.affinity != null and r2_okja.save_key == "okja_affinity"
		and r2_okja.affinity.points == okja_pts
		and r2_okja.affinity.hearts() == Affinity.MAX_HEARTS)
	_check("⑩d 혼인도 복원된다(배우자 = 앵커)", m2._spouse_id == "okja" and m2._okja_track_open())
	_check("⑩e 로드 직후 연출 상태는 언제나 0이다(그림·묶음 열·예약·회고 — 세이브 대상 아님)",
		m2._illust_id == "" and m2._spine_say.is_empty() and not m2._spine_b7_armed
		and not m2._spine_b4_armed and not m2._spine_b5_pending
		and not m2._epilogue_open and not m2._epilogue_pending)
	_stand_at_door(m2)
	for _i in 5:
		m2._maybe_spine_b5()
	_check("⑩f ★복원된 세이브에서도 재발동 0(문 칸을 몇 번을 밟아도 조용하다)",
		m2.cutscene == null and m2.spine_puzzle == null and not m2._spine_b5_pending
		and not m2.dialogue.is_open() and m2._spine_bits == bits_final)
	_pass_day(m2)
	m2._on_sleep_done()
	_drain(m2)
	_check("⑩g ★관통이 끝난 뒤에도 하루가 그냥 흘러간다(코지 샌드박스 — 엔딩이 게임을 안 닫는다)",
		m2.clock.running and m2.player.is_physics_processing() and not m2._run_over
		and m2._spine_bits == bits_final)
	m2.free()

	# 뒷정리 — 이 테스트가 만든 세이브를 지운다(다른 테스트의 자동 복원 오염 방지).
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ s9b_spine_smoke_test 전체 통과 ══")
	else:
		print("══ s9b_spine_smoke_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)
