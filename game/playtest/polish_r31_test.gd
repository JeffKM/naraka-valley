extends SceneTree
# ★[폴리시 31회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#5·#7·#8) + 배치 B(#6 · #9~#16).
#
# 렌즈: R30 diff 리뷰(#0~#3) · 단일 출처 술어 채택(#4) · 알림 keep 포화(#5·#6) ·
#       탈것/동행 동사 행렬(#7) · 목록 넘침 내비게이션(#8) · 혼력 대차 감사(#9~#11) ·
#       밭 타일 상태기계(#12~#14) · 상인 영업시간 진실성(#15·#16).
#
# 이 배치의 태도 셋.
#   ㉠ **동치를 선언했으면 모든 갈래가 그 동치를 읽어야 한다.** #0은 R30 #2가 「떨어뜨리는 값
#      `{}`는 «키 없는 구세이브»와 같은 뜻」이라 선언해 놓고, 스물두 줄 아래에서 `data.has()`로
#      다시 물어 그 동치를 스스로 깨뜨린 자리다 — 손상 세이브 하나가 조용한 영구 진행 잠금이 됐다.
#   ㉡ **시간은 그려진 것에게만 흐른다.** #1·#2는 R30 #15가 팝업 수명을 조기 반환 위로 올리면서
#      «visible 플래그»와 «실제로 보이는가»를 같은 것으로 본 자리다. 세이브당 1회 래치인 축하가
#      어두운 메뉴 판·펼친 달력 아래에서 6초를 다 태우고 영영 사라졌다.
#   ㉢ **화면 밖은 «있는 것»이 아니다.** #8은 판 높이가 상수 파생 고정값인데 목록은 카탈로그
#      길이만큼 자라, 15행 중 8행이 한 픽셀도 안 그려지고 마우스도 못 닿았다 — 그런데도 클릭
#      히트는 계속 등록됐다(R29 #1이 숙련 탭에서 봉합한 그 구조가 여기 그대로 남아 있었다).
#
# 무엇을 보증하나(번호 = 31회차 헌트 발견 인덱스).
#   ① #0 손상된 `heart_bits` 그릇이 «키 없는 구세이브»와 **같은 갈래로** 소급 백필을 받는다.
#      잘 형성된 원장은 그대로 진실원이고(합성 0), 키 부재 경로도 종전대로 돈다.
#   ② #1·#2 1회성 마일스톤 축하의 6초는 **가려진 동안 안 흐른다**(메뉴 프레임·펼친 달력).
#      정지 판정이 수명 함수 안에 있어 『정지 주인 = 재개 주인』이 지켜지고, 매일 뜨는 마감
#      정산은 종전대로 어떤 모드 아래에서도 늙는다(R30 #15 계약 보존).
#   ③ #3 마일스톤 판이 하단 예약 띠(`NoticeFeed.RESERVE_BOTTOM`)를 안 넘는다 — 세 호출부 전부.
#   ④ #4 레어크로우 **머리 칸**이 잡초 확산에도 성역이다(재점령 입구와 같은 술어·같은 폭).
#   ⑤ #5 늘봄방 발주 거절이 타일 좌표가 아니라 **설치물 이름**을 말한다.
#   ⑥ #7 [F] 창구 성역이 «잠든 플레이어의 실내 무대»에서도 산다(정상 취침 경로 = 유일한 경로).
#   ⑦ #8 제작 탭 15행이 **전부 도달 가능**하고, 그린 것이 테두리 안이며, 클릭 히트가 판 밖에 0이다.
#
# 판정: 배치 A CONFIRMED 8 / 배치 B CONFIRMED 7 · DUP 1(#12=#9) · OWNER-DECISION 1(#11) ·
#       REFUTED 0(단, #11의 «표와 화면이 서로를 반박한다» 절반은 오독으로 반증 — 커밋 본문 참조).

var _fail := 0
var _src: PackedStringArray

func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text().split("\n") if f != null else PackedStringArray()

func _line_of(lines: PackedStringArray, needle: String) -> int:
	for i in lines.size():
		if lines[i].contains(needle):
			return i
	return -1

# 그 함수 본문(다음 `func ` 줄 전까지) 안에서 니들이 처음 나오는 줄(없으면 -1).
func _in_func(fn_needle: String, needle: String) -> int:
	var head := _line_of(_src, fn_needle)
	if head < 0:
		return -1
	for i in range(head + 1, _src.size()):
		if _src[i].begins_with("func "):
			return -1
		if _src[i].contains(needle):
			return i
	return -1

# 파일 전체에서 니들을 담은 줄 수(주석 줄은 뺀다 — 근거 문장이 호출부로 세어지면 눈금이 거짓이 된다).
func _code_hits(needle: String) -> int:
	var n := 0
	for l in _src:
		if l.contains(needle) and not l.strip_edges().begins_with("#"):
			n += 1
	return n

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

# 세이브 슬롯 청소 — ①이 `_save_game`/`_load_game` 왕복을 태우므로 스위트 시작과 끝에서
# 반드시 비운다(R29 #29가 세운 규약 · polish_r8 관례).
func _wipe_slot(slot: int) -> void:
	var p := SaveManager.slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _notice_hits(m: Node, needle: String) -> int:
	var n := 0
	for it in m.notice_feed._items:
		if String(it["text"]).contains(needle):
			n += 1
	return n

# 열려 있는 대화를 끝까지 넘긴다(모달 잔재 청소 — polish_r29·r30 관례).
func _dismiss_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 200:
		m.dialogue.advance()
		guard += 1

# 모든 오버레이·연출 잔재를 걷어 «평소 무대»를 세운다(팝업 절의 전제).
func _clear_overlays(m: Node) -> void:
	_dismiss_dialogue(m)
	if m.frame.is_open():
		m.frame.close()
	m.calendar_panel.close()
	m.milestone_panel.visible = false
	m.cafe_summary_panel.visible = false
	m.mirror_panel.visible = false
	m.ending_panel.visible = false
	m._illust_id = ""
	m._sleeping = false
	m._transitioning = false
	m._milestone_popup_secs = 0.0
	m._cafe_summary_secs = 0.0
	m._cafe_summary_pending = ""

# 든 아이템 선택(없으면 인벤에 넣고 그 슬롯 선택 — polish_r30 관례 그대로).
func _select(m: Node, id: String) -> void:
	if not m.inventory.has_item(id):
		m.inventory.add_item(id, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

func _initialize() -> void:
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R31 회귀 — 배치 A(#0~#5·#7·#8) + 배치 B(#6·#9~#16) ══")
	_src = _lines_of_file("res://main.gd")
	var m := await _spawn_main()

	await _sec1_heart_bits_vessel(m)
	# ①이 세이브를 되불러 무대를 갈아엎으므로 안식 야외로 되돌린다(이후 절은 전부 HOME 좌표계다).
	m._indoor = ""
	m._rebuild_region(RegionCatalog.HOME)
	await _settle(m)
	await _sec2_milestone_occlusion(m)
	await _sec3_milestone_reserve(m)
	await _sec4_rarecrow_head_spread(m)
	await _sec5_greenhouse_notice(m)
	await _sec6_f_window_stage(m)
	await _sec7_craft_scroll(m)

	# ── 배치 B(#6 · #9~#16) ──
	await _sec8_notice_over_milestone(m)
	await _sec9_hoe_aoe_pot(m)
	await _sec10_restore_overflow(m)
	await _sec11_weed_farm_coowned(m)
	await _sec12_fert_sealed_prompt(m)
	_sec13_trial_shop_reason(m)
	_sec14_peddler_open_day(m)

	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)
	print("══ 결과: %s ══" % ("전부 통과" if _fail == 0 else "%d건 실패" % _fail))
	quit(1 if _fail > 0 else 0)

# ── ① #0 손상된 그릇 = «키 없는 구세이브» ────────────────────────────────────
func _sec1_heart_bits_vessel(m: Node) -> void:
	print("── ① #0 heart_bits 그릇 타입 ↔ R25 소급 백필 ──")
	var rid := String(m.ROMANCE_OPEN[0])
	var rr = m._resident(rid)
	if rr == null or rr.affinity == null:
		_check("①pre 무대: 연애 로스터 첫 사람(%s)의 호감도 노드가 있다" % rid, false)
		return
	var st: int = mini(3, m.HEART_GATE_MAX)
	var want := 0
	for h in range(1, st + 1):
		want |= (1 << h)
	rr.affinity.stage = st
	rr.affinity.points = st * Affinity.POINTS_PER_HEART
	m._heart_bits = {}
	_check("①a 무대: %s는 stage %d인데 관문 비트 원장이 비었다(백필이 겨누는 그 상태)" % [rid, st],
		rr.affinity.stage == st and m._heart_bits.is_empty())
	_check("①b 저장 성공", m._save_game())
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	_check("①c 무대: 페이로드에 `heart_bits` 키가 Dictionary로 실렸다(비었지만 존재한다)",
		raw.has("heart_bits") and raw.get("heart_bits") is Dictionary)
	# ㉠ 손상 그릇 — 키는 있는데 값이 Dictionary가 아니다(손으로 고친 평문 세이브의 이물).
	raw["heart_bits"] = 0
	_check("①d 손상 페이로드 기록 성공(래퍼는 그대로 — [이어하기]가 그대로 뜬다)",
		m.saver.save_game(raw, m._active_slot) and m.saver.can_load(m._active_slot))
	_check("①e `_load_game`이 끝까지 돈다", m._load_game())
	var got := int(m._heart_bits.get(rid, 0))
	_check("①f 손상 그릇도 «키 없음»과 **같은 갈래**로 소급된다 — 비트 1..%d가 선다(0b%s, 기대 0b%s)"
			% [st, String.num_int64(got, 2), String.num_int64(want, 2)],
		got == want)
	# ㉡ 잘 형성된 원장은 진실원 — 한 톨도 안 보탠다(R25 #12 계약 보존).
	m._heart_bits = {rid: (1 << 1)}
	rr.affinity.stage = st
	rr.affinity.points = st * Affinity.POINTS_PER_HEART
	_check("①g 무대: 관문 1만 선 원장을 저장한다(stage는 여전히 %d)" % st, m._save_game())
	_check("①h `_load_game` 성공", m._load_game())
	_check("①i 잘 형성된 원장엔 합성 0 — 비트 1만 그대로다(0b%s)"
			% String.num_int64(int(m._heart_bits.get(rid, 0)), 2),
		int(m._heart_bits.get(rid, 0)) == (1 << 1))
	# ㉢ 키 부재(관문 도입 전 세이브) — 종전 계약 그대로 소급된다.
	var raw2: Dictionary = m.saver.load_game(m._active_slot)
	raw2.erase("heart_bits")
	_check("①j 키를 통째로 지운 구세이브 기록 성공", m.saver.save_game(raw2, m._active_slot))
	_check("①k `_load_game` 성공", m._load_game())
	_check("①l 키 부재 경로는 종전대로 소급된다(0b%s — 회귀 없음)"
			% String.num_int64(int(m._heart_bits.get(rid, 0)), 2),
		int(m._heart_bits.get(rid, 0)) == want)

# ── ② #1·#2 1회성 축하의 6초는 «그려진 때에만» 흐른다 ────────────────────────
func _sec2_milestone_occlusion(m: Node) -> void:
	print("── ② #1·#2 마일스톤 팝업 수명 ↔ 가림 ──")
	_clear_overlays(m)
	await process_frame
	# ②a 규율 — 멈추는 판정이 **수명 함수 안**에 있다(『정지 주인 = 재개 주인』). 남이 얼려 두고
	#     안 녹이는 구조가 애초에 불가능해야 R19 #14·R29 #17이 이 자리를 고른 이유가 산다.
	var l_occ := _in_func("func _tick_popup_lifetimes", "_milestone_occluded()")
	var l_tick := _in_func("func _process", "_tick_popup_lifetimes(delta)")
	var l_frame := _in_func("func _process", "if frame.is_open():")
	_check("②a 정지 판정이 수명 함수 안(%d행)에 있고, 수명 훅(%d행)은 프레임 게이트(%d행)보다 위다"
			% [l_occ, l_tick, l_frame],
		l_occ > 0 and l_tick > 0 and l_frame > l_tick)
	_check("②b 평소 무대에선 아무도 안 가린다", not m._milestone_occluded())
	# ②c 평소엔 종전대로 늙고 거둬진다(과잉 정지 0).
	m.milestone_panel.visible = true
	m._milestone_popup_secs = 0.08
	var g := 0
	while m._milestone_popup_secs > 0.0 and g < 60:
		await process_frame
		g += 1
	_check("②c 안 가려진 축하는 %d프레임 만에 스스로 거둬진다(R30 #15가 세운 그 거동)" % g,
		m._milestone_popup_secs <= 0.0 and not m.milestone_panel.visible and g < 60)
	# ②d 메뉴 프레임(전화면 dim + 한지 판, 런타임 add_child) 아래에서는 초가 안 깎인다.
	m.milestone_panel.visible = true
	m._milestone_popup_secs = 3.0
	m.frame.open(InventoryFrame.CTX_MENU)
	await process_frame
	await process_frame
	await process_frame
	_check("②d 메뉴 프레임이 덮은 동안 초가 3.00에 멈춘다(실측 %.2f) — 판도 그대로 서 있다"
			% m._milestone_popup_secs,
		m._milestone_occluded() and is_equal_approx(m._milestone_popup_secs, 3.0)
		and m.milestone_panel.visible)
	# ②e 닫으면 같은 손이 다시 흘려보낸다(재개 주인 = 정지 주인).
	m._milestone_popup_secs = 0.08
	m.frame.close()
	await process_frame
	var g2 := 0
	while m._milestone_popup_secs > 0.0 and g2 < 60:
		await process_frame
		g2 += 1
	_check("②e 메뉴를 닫으면 %d프레임 만에 다시 흐르고 거둬진다(영구 정지 0)" % g2,
		m._milestone_popup_secs <= 0.0 and not m.milestone_panel.visible and g2 < 60)
	# ②f 펼친 절기 달력도 같다 — R30 #14가 «자동 접기»를 끄면서 생긴 구멍.
	m.milestone_panel.visible = true
	m._milestone_popup_secs = 3.0
	if not m.calendar_panel.is_open():
		m.calendar_panel.toggle()
	await process_frame
	await process_frame
	await process_frame
	_check("②f 펼친 달력 아래에서도 초가 3.00에 멈춘다(실측 %.2f) — 달력은 여전히 안 접힌다(R30 #14 보존)"
			% m._milestone_popup_secs,
		m.calendar_panel.is_open() and m._milestone_occluded()
		and is_equal_approx(m._milestone_popup_secs, 3.0))
	m.calendar_panel.close()
	await process_frame
	_check("②g 달력을 접으면 판정이 풀린다", not m._milestone_occluded())
	m._milestone_popup_secs = 0.0
	m.milestone_panel.visible = false
	# ②h 대조군 — 매일 뜨는 마감 정산은 **가려져도** 종전대로 늙는다(R30 #15가 봉합한 그 사고
	#     [불투명 판이 대화 본문을 덮은 채 안 사라짐]가 되살아나면 안 된다).
	m.cafe_summary_panel.visible = true
	m._cafe_summary_secs = 0.08
	m.frame.open(InventoryFrame.CTX_MENU)
	var g3 := 0
	while m._cafe_summary_secs > 0.0 and g3 < 60:
		await process_frame
		g3 += 1
	m.frame.close()
	await process_frame
	_check("②h 대조군: 마감 정산은 메뉴 프레임 아래에서도 %d프레임 만에 거둬진다(R30 #15 계약 보존)" % g3,
		m._cafe_summary_secs <= 0.0 and not m.cafe_summary_panel.visible and g3 < 60)
	_clear_overlays(m)
	await process_frame

# ── ③ #3 마일스톤 판 ↔ 하단 예약 띠 ─────────────────────────────────────────
func _sec3_milestone_reserve(m: Node) -> void:
	print("── ③ #3 마일스톤 판이 예약 띠를 안 넘는다 ──")
	var bare := _code_hits("_layout_popup_panel(milestone_panel, milestone_text)")
	var with_reserve := _code_hits(
		"_layout_popup_panel(milestone_panel, milestone_text, NoticeFeed.RESERVE_BOTTOM)")
	_check("③a 세 호출부(1·2·3단)가 전부 예약 띠를 넘긴다 — 인자 없는 호출 %d건 · 넘기는 호출 %d건"
			% [bare, with_reserve],
		bare == 0 and with_reserve == 3)
	# 하중 — 실제 그리기 경로를 태운다. 2단 축하가 이 판에서 가장 긴 본문이다(R23 #18 실측: 7줄).
	_clear_overlays(m)
	m._show_milestone2_reached()
	await process_frame
	var view: Vector2 = m._logical_view_size(m.milestone_panel)
	var limit: float = view.y - NoticeFeed.RESERVE_BOTTOM
	var pan: Panel = m.milestone_panel
	_check("③b 2단 축하 판의 아랫변 %.0f이 예약선 %.0f 안이다(뷰 %.0f − 띠 %.0f · 판 %.0f~%.0f)"
			% [pan.position.y + pan.size.y, limit, view.y, NoticeFeed.RESERVE_BOTTOM,
				pan.position.y, pan.position.y + pan.size.y],
		pan.position.y + pan.size.y <= limit + 0.5)
	var lab: Label = m.milestone_text
	_check("③c 본문 라벨(%.0f~%.0f)도 판 안에 들어간다 — 띠를 지키는 것은 판이 아니라 글이다(R29 #0)"
			% [pan.position.y + lab.position.y, pan.position.y + lab.position.y + lab.size.y],
		lab.position.y + lab.size.y <= pan.size.y + 0.5)
	_check("③d 머리가 화면 밖으로 안 나간다(윗변 %.0f ≥ 여백 %.0f)"
			% [pan.position.y, float(m.MIRROR_VIEW_MARGIN)],
		pan.position.y >= float(m.MIRROR_VIEW_MARGIN) - 0.5)
	_clear_overlays(m)
	await process_frame

# ── ④ #4 레어크로우 머리 칸 ↔ 잡초 확산 ─────────────────────────────────────
func _sec4_rarecrow_head_spread(m: Node) -> void:
	print("── ④ #4 두 입구가 한 규칙을 읽는다 ──")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	var crow_id := String(ItemCatalog.RARECROWS[0])
	var occ: Dictionary = m._home_occupied_tiles()
	# 밑동·머리·대조군 셋이 전부 «지금은 확산 목적지로 열려 있는» 자리를 찾는다(좌표 복제 0).
	var base := Vector2i(-1, -1)
	for yy in range(m.ENCROACH_SCAN_RECT.position.y + 2, m.ENCROACH_SCAN_RECT.end.y):
		for xx in range(m.ENCROACH_SCAN_RECT.position.x, m.ENCROACH_SCAN_RECT.end.x):
			var c := Vector2i(xx, yy)
			if m._can_place_rarecrow(c) \
					and m._weed_spread_class(c, occ) == Reclaim.DEST_OPEN \
					and m._weed_spread_class(c + Vector2i(0, -1), occ) == Reclaim.DEST_OPEN \
					and m._weed_spread_class(c + Vector2i(0, -2), occ) == Reclaim.DEST_OPEN:
				base = c
				break
		if base.x >= 0:
			break
	_check("④a 무대: 밑동 %s와 그 위 두 칸이 지금은 전부 확산 목적지로 열려 있다" % str(base),
		base.x >= 0)
	if base.x < 0:
		return
	var head: Vector2i = base + Vector2i(0, -1)
	var above: Vector2i = base + Vector2i(0, -2)
	m.rarecrow.place(base, crow_id)
	var occ2: Dictionary = m._home_occupied_tiles()
	_check("④b 무대: 원장은 밑동 한 칸만 싣고(머리 %s는 원장 밖) 프롭 점유 표에도 두 칸 다 없다"
			% str(head),
		m.rarecrow.has_at(base) and not m.rarecrow.has_at(head)
		and not occ2.has(base) and not occ2.has(head))
	_check("④c 확산 분류가 밑동과 **머리 칸**을 둘 다 막는다(밑동 %d · 머리 %d = DEST_BLOCK %d)"
			% [m._weed_spread_class(base, occ2), m._weed_spread_class(head, occ2),
				Reclaim.DEST_BLOCK],
		m._weed_spread_class(base, occ2) == Reclaim.DEST_BLOCK
		and m._weed_spread_class(head, occ2) == Reclaim.DEST_BLOCK)
	_check("④d 형제 입구(재점령 후보가 드는 `_installation_at`)와 **같은 답**이다 — 두 표가 안 갈린다",
		m._installation_at(base) and m._installation_at(head))
	_check("④e 과잉 0: 머리 위 한 칸 %s은 그대로 확산 목적지다(폭이 두 칸을 안 넘는다)" % str(above),
		m._weed_spread_class(above, occ2) == Reclaim.DEST_OPEN)
	m.rarecrow.remove(base)
	var occ3: Dictionary = m._home_occupied_tiles()
	_check("④f 걷어 내면 두 칸이 함께 풀린다(가드가 래치가 아니라 그 프레임의 원장이다)",
		m._weed_spread_class(base, occ3) == Reclaim.DEST_OPEN
		and m._weed_spread_class(head, occ3) == Reclaim.DEST_OPEN)

# ── ⑤ #5 늘봄방 발주 거절이 이름을 말한다 ────────────────────────────────────
func _sec5_greenhouse_notice(m: Node) -> void:
	print("── ⑤ #5 «무엇을 치워야 하는가» ──")
	# ★ 무대는 **구세이브**다 — R4가 `_can_place_furnace`에 `_greenhouse_lot_reserved` 가드를 넣은
	#   뒤로 새 세이브는 이 rect 안에 설치물을 세울 수 없다(그래서 여기서도 배치 가드를 안 쓰고
	#   원장에 직접 세운다). 이 거절 줄이 존재하는 이유가 정확히 그 구세이브 방어면이고,
	#   `_reclaim_greenhouse_lot`의 머리말도 같은 경로를 근거로 든다.
	var spot: Vector2i = m.GREENHOUSE_EXT_RECT.position \
		+ Vector2i(m.GREENHOUSE_EXT_RECT.size.x / 2, m.GREENHOUSE_EXT_RECT.size.y / 2)
	_check("⑤a 무대: 배치 가드는 예정지를 이미 막는다(%s — 이 갈래가 겨누는 것은 그 가드 이전 세이브다)"
			% str(spot),
		not m._can_place_furnace(spot) and m._greenhouse_lot_reserved(spot))
	_check("⑤a2 그 칸의 원장에 업화로를 직접 세운다(구세이브 재현)",
		m.furnace.place(RegionCatalog.HOME, spot))
	var lot: Array = m._greenhouse_lot_occupants()
	_check("⑤b 무대: 부지 점유 목록이 그 칸을 든다(%d개)" % lot.size(),
		lot.size() == 1 and Vector2i(lot[0]) == spot)
	_check("⑤c 이름 다리가 원장을 되짚어 아이템 id를 되찾는다(업화로 = %s)"
			% ItemCatalog.name_of(ItemCatalog.FURNACE),
		m._installation_item_at(spot) == ItemCatalog.FURNACE)
	# 카페 3단에 닿아야 도면이 열린다(그 앞 게이트를 지나야 이 거절 줄에 도달한다).
	m._run_harvested = maxi(m._run_harvested, CafeMilestone.S2_TARGET_HARVEST)
	m._cafe_revenue_total = maxi(m._cafe_revenue_total, CafeMilestone.S3_TARGET_REVENUE)
	var each: int = int(ceil(float(CafeMilestone.S2_TARGET_HEARTS) / 2.0))
	m.affinity.stage = maxi(m.affinity.stage, each)
	m.affinity.points = maxi(m.affinity.points, each * Affinity.POINTS_PER_HEART)
	m.mel_affinity.stage = maxi(m.mel_affinity.stage, each)
	m.mel_affinity.points = maxi(m.mel_affinity.points, each * Affinity.POINTS_PER_HEART)
	_check("⑤d 무대: 카페 %d단 — 늘봄방 도면이 열렸고 아직 안 지었다" % m._cafe_stage(),
		m._build_row_unlocked(Carpenter.PROJ_GREENHOUSE)
		and not m.carpenter.is_done(Carpenter.PROJ_GREENHOUSE) and not m.carpenter.is_active())
	m.notice_feed._items.clear()
	var ok: bool = m._try_order_build(Carpenter.PROJ_GREENHOUSE)
	var want_name := ItemCatalog.name_of(ItemCatalog.FURNACE)
	_check("⑤e 발주가 거절되고, 알림이 설치물 **이름**(%s)을 예시로 든다" % want_name,
		not ok and _notice_hits(m, "(%s 등)" % want_name) == 1)
	_check("⑤f 타일 좌표 문자열 %s은 화면에 한 번도 안 나온다(해독 불가 문자열 0)" % str(spot),
		_notice_hits(m, str(spot)) == 0)
	m.furnace.remove(RegionCatalog.HOME, spot)
	_check("⑤g 치우면 이 갈래를 안 탄다(부지 목록이 빈다)", m._greenhouse_lot_occupants().is_empty())

# ── ⑥ #7 [F] 창구 성역 ↔ 잠든 플레이어의 무대 ────────────────────────────────
func _sec6_f_window_stage(m: Node) -> void:
	print("── ⑥ #7 성역의 자[尺]는 칸의 무대다 ──")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	var mail: Vector2i = m.MAILBOX_TILE
	var bowl: Vector2i = m.PET_BOWL_TILE
	var occ: Dictionary = m._home_occupied_tiles()
	_check("⑥a 무대: 야외 표는 우편함 %s·물그릇 %s를 [F] 창구로 든다" % [str(mail), str(bowl)],
		m._f_window_tile_in("", mail) and m._f_window_tile_in("", bowl))
	_check("⑥b 무대: 실내 표엔 그 두 칸이 없다(무대별 표가 갈리는 것 자체는 설계다)",
		not m._f_window_tile_in("집", mail) and not m._f_window_tile_in("집", bowl))
	_check("⑥c 무대: 우편함 칸은 순수 GROUND이고 프롭 점유·밭·개간·잡초 어디에도 안 걸린다"
			+ "(= 이 가드가 유일한 거절 근거다)",
		m._grid[mail.y][mail.x] == m.GROUND and not occ.has(mail)
		and not m.farm.is_tilled(mail) and not m.farm.is_planted(mail)
		and not m.reclaim.is_cleared(mail) and not m.reclaim.has_weed(mail))
	# 하중 — 자체 파종이 실제로 도는 **그 프레임의 무대**(집 안에서 자는 밤)를 세운다.
	m._indoor = "집"
	_check("⑥d 잠든 무대(`_indoor`=\"집\")에서도 자체 파종이 우편함 칸을 거절한다",
		not m._is_tree_seed_free(RegionCatalog.HOME, mail, occ))
	_check("⑥e 물그릇 칸도 같다(형제 좌표 — 물 띠 표식·[F]가 나무에 묻히던 자리)",
		not m._is_tree_seed_free(RegionCatalog.HOME, bowl, occ))
	_check("⑥f 무인자 술어는 여전히 «지금 서 있는 무대»를 읽는다 — 실내 표가 살아 있다(배치 가드 불변)",
		m._f_window_tile(m.CHEST_TILE) and not m._f_window_tile(mail))
	# 과잉 거절 0 — 평범한 마당 여백은 잠든 무대에서도 그대로 통과한다.
	var free_t := Vector2i(-1, -1)
	for yy in range(m.ENCROACH_SCAN_RECT.position.y, m.ENCROACH_SCAN_RECT.end.y):
		for xx in range(m.ENCROACH_SCAN_RECT.position.x, m.ENCROACH_SCAN_RECT.end.x):
			var c := Vector2i(xx, yy)
			if m._is_tree_seed_free(RegionCatalog.HOME, c, occ):
				free_t = c
				break
		if free_t.x >= 0:
			break
	_check("⑥g 과잉 거절 0: 잠든 무대에서도 평범한 여백 %s은 파종 자격이다" % str(free_t),
		free_t.x >= 0)
	m._indoor = ""

# ── ⑦ #8 제작 탭 — 15행 전부 도달 가능 ───────────────────────────────────────
func _sec7_craft_scroll(m: Node) -> void:
	print("── ⑦ #8 화면 밖은 «있는 것»이 아니다 ──")
	_clear_overlays(m)
	# ★ 하중을 먼저 싣는다 — 클릭 히트(`_craft_row_rects`)는 **제작 가능한 행에만** 붙으므로,
	#   그 상태를 안 만들면 ⑦d는 잴 것이 0인 공허 단언이 된다(파괴 실측으로 확인했다).
	#   카탈로그 **막행**을 고르는 것이 요점이다: 그 행이 창 밖에 그려지던 것이 이 결함의 본체다.
	var last_id := String(CraftCatalog.ids()[CraftCatalog.ids().size() - 1])
	for mat in CraftCatalog.get_recipe(last_id)["mats"]:
		m.inventory.add_item(String(mat["item"]), int(mat["count"]))
	var rows: Array = m._craft_rows()
	var ids: Array = CraftCatalog.ids()
	_check("⑦pre 하중: 막행 %s가 «제작 가능»이라 클릭 히트가 실제로 등록된다" % last_id,
		bool((rows[rows.size() - 1] as Dictionary).get("can", false)))
	_check("⑦a 무대: 카탈로그 전량이 행으로 온다(%d행 = `CraftCatalog.ids()` %d개 — 분모 파생)"
			% [rows.size(), ids.size()],
		rows.size() == ids.size() and rows.size() > 0)
	m.frame.open(InventoryFrame.CTX_MENU)
	m.frame.set_tab(InventoryFrame.TAB_CRAFT)
	_check("⑦b 열 때 목록이 맨 위로 선다", m.frame._craft_scroll == 0)
	var panel: Rect2 = m.frame._panel_rect()
	var max_y: float = panel.end.y - InventoryFrame.FRAME_MARGIN
	var worst := 0.0
	var worst_at := -1
	var outside: Array = []
	var seen: Dictionary = {}
	var first_shown := 0
	# ★ 스크롤 전 위치를 훑는다(R29 ②c 관례) — 규율은 어느 첫 행에서 시작해도 성립해야 한다.
	for s in rows.size():
		m.frame._craft_scroll = s
		m.frame.queue_redraw()
		await process_frame
		await process_frame
		if s == 0:
			first_shown = m.frame._craft_shown
		if m.frame._craft_draw_bottom > worst:
			worst = m.frame._craft_draw_bottom
			worst_at = s
		for i in range(m.frame._craft_scroll, m.frame._craft_scroll + m.frame._craft_shown):
			seen[i] = true
		for e in m.frame._craft_row_rects:
			if (e["rect"] as Rect2).end.y > max_y or (e["rect"] as Rect2).position.y < panel.position.y:
				outside.append("%s(첫행 %d)" % [String(e["id"]), s])
	_check("⑦c 스크롤 %d위치 전부에서 그린 바닥이 9-slice 테두리 안쪽이다(최악 %.0f@첫행 %d ≤ %.0f)"
			% [rows.size(), worst, worst_at, max_y],
		worst_at >= 0 and worst <= max_y + 0.5)
	_check("⑦d 클릭 히트가 판 밖에 하나도 없다(%d건) — 보이지 않는 rect가 제작 버튼이 되던 자리"
			% outside.size(),
		outside.is_empty())
	var missed: Array = []
	for i in rows.size():
		if not seen.has(i):
			missed.append("%d:%s" % [i, String(ids[i])])
	_check("⑦e 15행 **전부**가 어느 스크롤 위치에선가 그려진다 — 도달 못 한 행 %d건 %s"
			% [missed.size(), str(missed)],
		missed.is_empty())
	_check("⑦f 넘친다는 사실 자체: 첫 화면은 %d행뿐이고 전량은 %d행이다(스크롤이 실효한다)"
			% [first_shown, rows.size()],
		first_shown > 0 and first_shown < rows.size())
	# ⑦g 휠이 실제로 듣는다 — 영역 안에서만(밖은 종전대로 아무 일도 안 일어난다).
	m.frame._craft_scroll = 0
	m.frame.queue_redraw()
	await process_frame
	await process_frame
	var area: Rect2 = m.frame._craft_area_rect
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = area.get_center()
	m.frame._gui_input(ev)
	var after_in: int = m.frame._craft_scroll
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev2.pressed = true
	ev2.position = Vector2(area.position.x, area.position.y - 40.0)
	m.frame._gui_input(ev2)
	_check("⑦g 행 영역(%.0f,%.0f %.0f×%.0f) 안의 휠만 목록을 넘긴다(안 %d · 밖 뒤 %d)"
			% [area.position.x, area.position.y, area.size.x, area.size.y,
				after_in, m.frame._craft_scroll],
		area.size.y > 0.0 and after_in == 1 and m.frame._craft_scroll == 1)
	# ⑦h 마지막 행에 실제로 닿는다 — 클램프가 끝까지 내려간다.
	m.frame._craft_scroll = rows.size() * 2
	m.frame.queue_redraw()
	await process_frame
	await process_frame
	var last_rect := Rect2()
	for e in m.frame._craft_row_rects:
		if String(e["id"]) == last_id:
			last_rect = e["rect"]
	_check("⑦h 끝까지 내리면 마지막 행(%s)이 창에 든다(첫행 %d + %d행 = %d)"
			% [last_id, m.frame._craft_scroll, m.frame._craft_shown,
				m.frame._craft_scroll + m.frame._craft_shown],
		m.frame._craft_scroll + m.frame._craft_shown == rows.size())
	_check("⑦i 그리고 그 행이 **클릭할 수 있는 자리**에 선다(%.0f~%.0f ⊂ 판 %.0f~%.0f) — 상위 스프링클러·화분이 영구 제작 불가이던 자리"
			% [last_rect.position.y, last_rect.end.y, panel.position.y, max_y],
		last_rect.size.y > 0.0 and last_rect.position.y >= panel.position.y
		and last_rect.end.y <= max_y + 0.5)
	m.frame.close()
	await process_frame

# ═══ 배치 B(#6 · #9~#16) ═══════════════════════════════════════════════════
#
# ㉠ **가려지면 안 되는 판이 있다.** #6은 배치 A의 #1·#2와 한 뿌리다 — 이번엔 알림 띠가 덮는다.
#    미룸(형제 정산 팝업의 처방)을 못 쓰는 창구라 «초를 멈춘다»로 간다.
# ㉡ **광고자와 집행자는 같은 표를 읽어야 한다.** #9/#12·#14는 화면이 «할 수 있다»고 말한 동사가
#    집행부에서 거절·건너뜀으로 끝나던 자리고, #10은 표값을 광고하고 절단값을 집행하던 자리다.
# ㉢ **거절에는 진짜 사유가 있다.** #15·#16은 여러 사유를 한 술어로 뭉쳐 «모자라다»·침묵으로
#    옮기던 자리다(둘 다 형제 창구가 이미 사유를 가르고 있었다).
#
#   ⑧ #6 알림 띠가 1회성 축하 본문을 덮는 동안 초가 안 흐른다(띠가 비면 마저 흐른다).
#   ⑨ #9(#12=DUP) 괭이 AoE 광고 술어가 집행 루프의 화분 항을 함께 든다.
#   ⑩ #10 회복 동사가 **실제로 들어갈 양**을 누르기 전에 말한다(넘치는 몫 포함).
#   ⑪ #13 한 칸을 두 원장이 나눠 가지면 화면이 **둘 다** 말한다.
#   ⑫ #14 되감기 봉인 칸의 비료 프롬프트가 집행부의 거절 술어를 본다.
#   ⑬ #15 시련패 매대가 «취급 없음 / 1회성 기구매 / 잔고 부족»을 갈라 말한다.
#   ⑭ #16 보부상 결제 5경로가 결제 순간에 오늘 날짜를 다시 묻는다.
#   ※ #11(급여 대차 비대칭)은 OWNER-DECISION — 코드를 안 건드린다(커밋 본문에 3안).

# 조준 — 헤드리스에서는 커서가 늘 플레이어의 우하단으로 떨어져 `_update_target`의 클램프가
# 항상 (+1,+1)이 된다(실측). 그래서 발을 대상 칸의 좌상단에 놓는다. 무대 단언이 실제 조준을 확인한다.
func _aim(m: Node, t: Vector2i) -> void:
	m.player.global_position = m._tile_center_px(t - Vector2i(1, 1))
	await process_frame
	await process_frame

# ── ⑧ #6 알림 띠 ↔ 1회성 축하 ────────────────────────────────────────────────
func _sec8_notice_over_milestone(m: Node) -> void:
	print("── ⑧ #6 띠가 덮은 동안은 초가 안 흐른다 ──")
	_clear_overlays(m)
	m.notice_feed._items.clear()
	m._show_milestone2_reached()
	await process_frame
	var pan: Panel = m.milestone_panel
	var lab: Label = m.milestone_text
	var body := Rect2(pan.position + lab.position, lab.size)
	_check("⑧a 무대: 축하가 떠 있고 본문 사각형이 판보다 좁다(판이 아니라 **글**과 댄다) — 본문 %s"
			% str(body),
		pan.visible and body.size.x > 0.0 and body.size.y > 0.0
		and body.size.y < pan.size.y)
	_check("⑧b 띠가 비면 아무도 안 덮는다", not m._notice_over_milestone() and not m._milestone_occluded())
	# 서빙 프레임 재현 — 문턱을 넘긴 그 프레임이 곧 알림을 미는 프레임이다.
	for i in 4:
		m._notice("서빙 +%d냥 (%d번째 손님)" % [120 + i, i + 1])
	await process_frame
	# 하중 — 실제로 겹치는 띠 조각을 그리기 경로(`layout`)에서 받아 좌표로 보인다.
	var hit := Rect2()
	for slot in m.notice_feed.layout(HanjiUi.font(), m._logical_view_size(m.notice_feed)):
		var r := Rect2(slot["pos"], Vector2(float(slot["w"]), float(slot["h"])))
		if r.intersects(body):
			hit = r
			break
	_check("⑧c 알림 %d줄 중 %s가 본문 %s를 실제로 문다(자리는 `_draw`가 쓰는 `layout` 그대로)"
			% [m.notice_feed._items.size(), str(hit), str(body)],
		hit.size.y > 0.0 and hit.intersects(body))
	_check("⑧d 그래서 가림 판정이 선다", m._notice_over_milestone() and m._milestone_occluded())
	m._milestone_popup_secs = 3.0
	await process_frame
	await process_frame
	await process_frame
	_check("⑧e 덮인 동안 초가 3.00에 멈춘다(실측 %.2f)" % m._milestone_popup_secs,
		is_equal_approx(m._milestone_popup_secs, 3.0) and m.milestone_panel.visible)
	# 띠가 비면 남은 초를 마저 쓴다 — 알림은 저마다 수명이 있어 반드시 빈다.
	m.notice_feed._items.clear()
	m._milestone_popup_secs = 0.08
	var g := 0
	while m._milestone_popup_secs > 0.0 and g < 60:
		await process_frame
		g += 1
	_check("⑧f 띠가 비면 %d프레임 만에 다시 흐르고 거둬진다(영구 정지 0)" % g,
		not m._notice_over_milestone() and m._milestone_popup_secs <= 0.0
		and not m.milestone_panel.visible and g < 60)
	# 대조 — 판이 안 떠 있으면 띠가 아무리 쌓여도 판정은 거짓이다(공회전 0).
	for i in 3:
		m._notice("대조 알림 %d" % i)
	await process_frame
	_check("⑧g 대조군: 축하가 없으면 띠가 %d줄이어도 판정이 거짓이다"
			% m.notice_feed._items.size(),
		not m.milestone_panel.visible and m.notice_feed._items.size() > 0
		and not m._notice_over_milestone())
	m.notice_feed._items.clear()
	_clear_overlays(m)
	await process_frame

# ── ⑨ #9(#12 DUP) 괭이 AoE — 광고자와 집행자가 같은 표 ────────────────────────
func _sec9_hoe_aoe_pot(m: Node) -> void:
	print("── ⑨ #9 화분 칸은 «할 일»이 아니다 ──")
	# 늘봄방을 세운다(화분이 설 수 있는 유일한 경작면 — `_can_place_pot`은 실내에서만 참).
	m.carpenter.load_save({"active": [], "done": [Carpenter.PROJ_GREENHOUSE]})
	m._refresh_greenhouse()
	m._region = RegionCatalog.HOME
	m._sleeping = false
	m._transitioning = false
	m._transition_to("늘봄방", m.GREENHOUSE_IN_TILE)   # 그리드가 실제로 서야 AoE 표가 열린다
	await _settle(m)
	_check("⑨pre 무대: 늘봄방 실내에 서 있다(경작면 그리드가 섰다)", m._indoor == "늘봄방")
	m.tool_tier.set_tier(ItemCatalog.HOE, 2)     # 3×3 — 0티어는 AoE가 (1,1)이라 이 결함이 안 생긴다
	_check("⑨a 무대: 티어 괭이의 AoE가 한 칸을 넘는다(%s)" % str(m.tool_aoe(ItemCatalog.HOE)),
		m.tool_aoe(ItemCatalog.HOE) != Vector2i(1, 1))
	var plot: Rect2i = m.GREENHOUSE_PLOT_RECT
	var center := Vector2i(plot.position.x + 4, plot.position.y + 4)
	var gh: FarmField = m._field_at(center)
	_check("⑨b 무대: 경작면 칸이 늘봄방 밭으로 라우팅된다(노지 밭과 다른 원장)",
		gh != null and gh != m.farm and m._in_greenhouse_plot(center))
	# ★ AoE의 **모양은 실측에서 파생한다** — 티어 표가 세로 일렬(1×N)이라 3×3을 가정하면
	#   화분 칸이 범위 밖으로 떨어져 단언이 공허해진다. 플레이어를 축에 세워 방향을 고정하고
	#   집행부·광고부가 함께 쓰는 그 함수에서 칸 목록을 그대로 받는다.
	m.player.global_position = m._tile_center_px(center + Vector2i(0, 2))
	m._target = center
	var aoe: Array = m._farm_aoe_tiles(center, m.tool_aoe(ItemCatalog.HOE))
	_check("⑨c 무대: AoE가 조준 칸을 넘어 %d칸이다 — %s" % [aoe.size(), str(aoe)],
		aoe.size() > 1)
	if aoe.size() <= 1:
		return
	var pot_t: Vector2i = aoe[aoe.size() - 1]
	for at in aoe:
		if Vector2i(at) != pot_t:
			gh.hoe(Vector2i(at))
	_check("⑨c2 무대: AoE 안에서 미경작인 칸은 %s 하나뿐이다" % str(pot_t),
		not gh.is_tilled(pot_t) and gh.is_tilled(center))
	_check("⑨d 화분이 없으면 종전대로 «할 일»이다(과잉 거절 0)", m._hoe_aoe_has_work())
	_check("⑨e 무대: 그 칸에 화분을 놓는다", m.garden_pot.place(pot_t) and m._pot_at(pot_t))
	m._target = center
	_check("⑨f 이제 광고 술어가 거짓이다 — 집행 루프가 건너뛰는 칸은 «할 일»이 아니다",
		not m._hoe_aoe_has_work())
	# 하중 — 화면이 실제로 무엇을 말하는가(프롬프트 경로를 태운다).
	_select(m, ItemCatalog.HOE)
	m.energy.current = SoulEnergy.MAX
	m._target = center
	m._target_valid = m._is_farmable(center)
	var p_with: String = m._farm_prompt()
	m.garden_pot.remove(pot_t)
	m._target = center
	var p_without: String = m._farm_prompt()
	_check("⑨g 화분이 있으면 «괭이질»을 한 글자도 약속하지 않고(「%s」), 걷으면 다시 약속한다(「%s」)"
			% [p_with, p_without],
		not p_with.contains("괭이질") and p_without.contains("괭이질"))
	# 무대 원복 — 다음 절은 안식 야외 좌표계다.
	for at in aoe:
		gh.untill(Vector2i(at))
	m.tool_tier.set_tier(ItemCatalog.HOE, 0)
	m._indoor = ""
	m._rebuild_region(RegionCatalog.HOME)
	await _settle(m)

# ── ⑩ #10 회복 초과분 사전 고지 ───────────────────────────────────────────────
func _sec10_restore_overflow(m: Node) -> void:
	print("── ⑩ #10 표값이 아니라 들어갈 양 ──")
	var dish := String(MenuCatalog.side_dish_ids()[0])
	var table := MenuCatalog.restore_of(dish)
	_check("⑩a 무대: 곁들이 %s의 표값은 +%d다(0보다 크다)" % [MenuCatalog.name_of(dish), table],
		table > 1)
	_select(m, dish)
	m.energy.current = 0
	var full_txt: String = m._free_use_prompt()
	_check("⑩b 가득 차지 않은 평소 구간은 문자열이 한 글자도 안 바뀐다 — 「%s」" % full_txt,
		full_txt == "[좌클릭] %s 먹기 (혼력 +%d)" % [MenuCatalog.name_of(dish), table])
	m.energy.current = SoulEnergy.MAX - 1
	var clipped: String = m._free_use_prompt()
	_check("⑩c 99/100에서는 **들어갈 +1**과 **버려질 %d**을 누르기 전에 말한다 — 「%s」"
			% [table - 1, clipped],
		clipped.contains("혼력 +1") and clipped.contains("넘치는 %d" % (table - 1))
		and not clipped.contains("혼력 +%d)" % table))
	# 집행부와 같은 값인가 — 실제로 회복해 보고 광고값과 댄다(표시↔집행 정합).
	m.inventory.add_item(dish, 1)
	var before: int = m.energy.current
	m._eat_side_dish(dish)
	_check("⑩d 집행부가 실제로 준 양(%d)이 광고한 +1과 같다" % (m.energy.current - before),
		m.energy.current - before == 1)
	_check("⑩e 만점에서는 종전대로 거절 문구다(계단의 맨 윗칸은 그대로)",
		m._free_use_prompt().contains("혼력이 가득하다"))
	# 형제 축(명부환/체력)도 같은 술어를 탄다.
	var potion := ItemCatalog.MYEONGBUHWAN
	var heal := ItemCatalog.potion_heal(potion)
	_select(m, potion)
	m.health.current = m.health.maximum - 1
	var ptxt: String = m._free_use_prompt()
	_check("⑩f 형제 축(명부환 체력 +%d)도 같은 술어를 탄다 — 「%s」" % [heal, ptxt],
		heal > 1 and ptxt.contains("체력 +1") and ptxt.contains("넘치는 %d" % (heal - 1)))
	m.health.current = m.health.maximum
	m.energy.current = SoulEnergy.MAX

# ── ⑪ #13 두 원장이 나눠 가진 칸 ─────────────────────────────────────────────
func _sec11_weed_farm_coowned(m: Node) -> void:
	print("── ⑪ #13 한 칸·두 원장·두 동사 ──")
	m._indoor = ""
	m._region = RegionCatalog.HOME
	m._sleeping = false
	# 스타터 밭에서 «갈아만 둔 칸»을 하나 골라 잡초를 얹는다(확산이 실제로 내는 그 상태).
	var t := Vector2i(-1, -1)
	for yy in range(m.STARTER_PATCH_RECT.position.y, m.STARTER_PATCH_RECT.end.y):
		for xx in range(m.STARTER_PATCH_RECT.position.x, m.STARTER_PATCH_RECT.end.x):
			var c := Vector2i(xx, yy)
			if m._is_farmable(c) and not m.farm.is_planted(c) and m._debris_kind_at(c) == "" \
					and not m.reclaim.has_weed(c) and not m._resident_tile(c) \
					and not m._resident_tile(c - Vector2i(1, 1)):
				t = c
				break
		if t.x >= 0:
			break
	_check("⑪a 무대: 밭 칸 %s를 찾았다" % str(t), t.x >= 0)
	if t.x < 0:
		return
	# 발견물의 순서 그대로다 — 잡초가 «갈아만 둔 칸»에 먼저 번지고, 그 뒤 플레이어가 심는다
	# (입력은 그대로 먹히므로 실제로 심긴다). 며칠 뒤 그 칸엔 다 자란 작물이 선다.
	m.farm.hoe(t)
	m.reclaim._weeds[t] = true
	m.reclaim.changed.emit()
	var crop := String(CropCatalog.ids()[0])
	m.farm.plant(t, crop)
	m.farm._tiles[t]["grown_days"] = 99
	_check("⑪b 무대: 한 칸이 «경작 ∧ 성숙 작물 ∧ 잡초»를 동시에 만족한다(확산이 SOIL을 목적지로 받는다)",
		m.farm.is_tilled(t) and m.farm.is_mature(t) and m.reclaim.has_weed(t)
		and m._is_farmable(t) and m._debris_kind_at(t) == "")
	_select(m, ItemCatalog.HOE)
	m.energy.current = SoulEnergy.MAX
	await _aim(m, t)
	_check("⑪c 무대: 실제로 그 칸을 겨눴고 입력 게이트가 열려 있다(조준 %s · 기대 %s · valid %s)"
			% [str(m._target), str(t), str(m._target_valid)],
		m._target == t and m._target_valid)
	var txt: String = m.interact_prompt.text
	_check("⑪d 화면이 **둘 다** 말한다 — 잡초(낫)와 다 자란 작물의 [우클릭] 수확이 한 줄에 선다: 「%s」" % txt,
		txt.contains("낫") and txt.contains("수확"))
	# 대조 — 밭이 아닌 평범한 잡초 칸은 문자열이 한 글자도 안 바뀐다.
	m.reclaim._weeds.erase(t)
	m.farm.remove_plant(t)
	m.farm.untill(t)
	var plain := Vector2i(-1, -1)
	for yy in range(m.ENCROACH_SCAN_RECT.position.y, m.ENCROACH_SCAN_RECT.end.y):
		for xx in range(m.ENCROACH_SCAN_RECT.position.x, m.ENCROACH_SCAN_RECT.end.x):
			var c := Vector2i(xx, yy)
			if not m._is_farmable(c) and m._grid[c.y][c.x] == m.GROUND \
					and m._debris_kind_at(c) == "" and not m._home_occupied_tiles().has(c) \
					and not m._resident_tile(c) and not m._resident_tile(c - Vector2i(1, 1)) \
					and m._grid[c.y - 1][c.x - 1] == m.GROUND:
				plain = c
				break
		if plain.x >= 0:
			break
	if plain.x >= 0:
		m.reclaim._weeds[plain] = true
		m.reclaim.changed.emit()
		await _aim(m, plain)
		var ptxt: String = m.interact_prompt.text
		_check("⑪e 대조군: 밭이 아닌 잡초 칸 %s은 종전 한 줄 그대로다(조준 %s) — 「%s」"
				% [str(plain), str(m._target), ptxt],
			m._target == plain and not m._target_valid and ptxt.contains("낫")
			and not ptxt.contains("·  ["))
		m.reclaim._weeds.erase(plain)
		m.reclaim.changed.emit()
	else:
		_check("⑪e 대조군 무대를 못 찾았다", false)

# ── ⑫ #14 되감기 봉인 칸의 비료 프롬프트 ──────────────────────────────────────
func _sec12_fert_sealed_prompt(m: Node) -> void:
	print("── ⑫ #14 거절될 동사는 약속하지 않는다 ──")
	# REGROW 작물을 카탈로그에서 파생해 고른다(id 하드코딩 0).
	var regrow := ""
	for c in CropCatalog.ids():
		if CropCatalog.growth_mode(String(c)) == "REGROW":
			regrow = String(c)
			break
	_check("⑫a 무대: REGROW 작물을 카탈로그에서 찾았다(%s)" % regrow, regrow != "")
	if regrow == "":
		return
	var t := Vector2i(-1, -1)
	for yy in range(m.STARTER_PATCH_RECT.position.y, m.STARTER_PATCH_RECT.end.y):
		for xx in range(m.STARTER_PATCH_RECT.position.x, m.STARTER_PATCH_RECT.end.x):
			var c := Vector2i(xx, yy)
			if m._is_farmable(c) and not m.farm.is_planted(c) and not m.reclaim.has_weed(c):
				t = c
				break
		if t.x >= 0:
			break
	if t.x < 0:
		_check("⑫pre 무대 칸을 못 찾았다", false)
		return
	m.farm.hoe(t)
	m.farm.plant(t, regrow)
	m.farm._tiles[t]["grown_days"] = 99          # 성숙시켜 한 번 수확한다(되감기 표식은 harvest가 새긴다)
	var got: String = m.farm.harvest(t)
	_check("⑫b 무대: 한 번 수확해 칸이 «미성숙 + 되감기 봉인»이 됐다(수확물 %s)" % got,
		got != "" and m.farm.is_planted(t) and not m.farm.is_mature(t)
		and m.farm.fertilize_sealed_no_op(t, FertilizerCatalog.FERT_SPEED))
	_select(m, FertilizerCatalog.FERT_SPEED)
	m.energy.current = SoulEnergy.MAX
	m._target = t
	m._target_valid = m._is_farmable(t)
	_check("⑫pre2 무대: 조준 칸이 밭 게이트를 통과한다(프롬프트가 그 표를 먼저 본다)", m._target_valid)
	var txt: String = m._farm_prompt()
	_check("⑫c 화면이 거절 사유를 미리 말한다(«뿌리기» 약속 0) — 「%s」" % txt,
		txt.contains("듣지 않는다") and not txt.contains("뿌리기"))
	# 하중 — 집행부가 실제로 거절하고 아이템이 안 줄어드는지 같은 프레임에서 확인한다.
	var before: int = m.inventory.count_of(FertilizerCatalog.FERT_SPEED)
	m._use_tool()
	_check("⑫d 집행부도 같은 술어로 거절한다 — 비료가 %d개 그대로다" % before,
		m.inventory.count_of(FertilizerCatalog.FERT_SPEED) == before)
	# 대조 — 봉인이 아닌 평범한 경작 칸은 종전대로 동사를 약속한다.
	m.farm.remove_plant(t)
	m.farm.untill(t)
	m.farm.hoe(t)
	m._target = t
	m._target_valid = m._is_farmable(t)
	var ok_txt: String = m._farm_prompt()
	_check("⑫e 대조군: 봉인 아닌 경작 칸은 종전대로 «뿌리기»다 — 「%s」" % ok_txt,
		ok_txt.contains("뿌리기") and not ok_txt.contains("듣지 않는다"))
	m.farm.untill(t)

# ── ⑬ #15 시련패 매대 거절 사유 ───────────────────────────────────────────────
func _sec13_trial_shop_reason(m: Node) -> void:
	print("── ⑬ #15 «모자라다»가 아닌 진짜 사유 ──")
	# 1회성 품목을 매대 표에서 파생한다(id 하드코딩 0).
	var once_id := ""
	for r in TrialGround.SHOP:
		if bool(r.get("once", false)) and ItemCatalog.has_item(String(r["buy_id"])):
			once_id = String(r["buy_id"])
			break
	var price := TrialGround.price_of(once_id)
	_check("⑬a 무대: 1회성 품목을 매대 표에서 찾았다(%s · %d패)" % [once_id, price],
		once_id != "" and price > 0)
	if once_id == "":
		return
	m.trial.tokens = price * 3               # 잔고는 넉넉하다 — «모자라다»가 거짓이 되는 무대
	m.trial.bought.append(once_id)
	_check("⑬b 무대: 이미 샀고 잔고는 %d패로 가격 %d패보다 많다(그런데 `can_buy`는 거짓)"
			% [m.trial.tokens, price],
		m.trial.has_bought(once_id) and m.trial.tokens > price and not m.trial.can_buy(once_id))
	m.notice_feed._items.clear()
	m._try_buy_trial_item(once_id)
	var txt := ""
	for it in m.notice_feed._items:
		txt = String(it["text"])
	_check("⑬c 화면이 «1회성 기구매»를 말하고 «모자라다»는 한 글자도 안 나온다 — 「%s」" % txt,
		txt.contains("이미 바꿨다") and not txt.contains("모자라다"))
	# 대조 ㉠ — 잔고가 실제로 모자라면 종전 문구 그대로다.
	var rep_id := ""
	for r in TrialGround.SHOP:
		if not bool(r.get("once", false)) and ItemCatalog.has_item(String(r["buy_id"])):
			rep_id = String(r["buy_id"])
			break
	m.trial.tokens = 0
	m.notice_feed._items.clear()
	m._try_buy_trial_item(rep_id)
	var txt2 := ""
	for it in m.notice_feed._items:
		txt2 = String(it["text"])
	_check("⑬d 대조군: 진짜 잔고 부족(%s)은 종전 문구 그대로다 — 「%s」" % [rep_id, txt2],
		rep_id != "" and txt2.contains("시련패가 모자라다"))
	# 대조 ㉡ — 매대가 취급하지 않는 품목은 «없다»고 말한다(0패 거짓 표기 0).
	var off_id := ItemCatalog.WOOD
	m.trial.tokens = 99
	m.notice_feed._items.clear()
	m._try_buy_trial_item(off_id)
	var txt3 := ""
	for it in m.notice_feed._items:
		txt3 = String(it["text"])
	_check("⑬e 취급 없는 품목(%s)은 «0패»가 아니라 «없다»라고 말한다 — 「%s」"
			% [ItemCatalog.name_of(off_id), txt3],
		TrialGround.price_of(off_id) <= 0 and txt3.contains("없다")
		and not txt3.contains("0패"))
	m.trial.bought.erase(once_id)
	m.trial.tokens = 0

# ── ⑭ #16 보부상 결제층의 영업일 ─────────────────────────────────────────────
func _sec14_peddler_open_day(m: Node) -> void:
	print("── ⑭ #16 결제 순간에 오늘 날짜를 다시 묻는다 ──")
	var closed_day := 0
	for d in range(1, 40):
		if not Peddler.is_open_day(d):
			closed_day = d
			break
	var open_day := Peddler.next_open_day(1)
	_check("⑭a 무대: 비출현일 %d일과 출현일 %d일을 카탈로그에서 파생했다" % [closed_day, open_day],
		closed_day > 0 and open_day > 0 and not Peddler.is_open_day(closed_day)
		and Peddler.is_open_day(open_day))
	m.clock.day = closed_day
	m.wallet.gold = 99999                    # 지갑은 넉넉하다 — «냥 부족»이 거짓이 되는 무대
	_check("⑭b 무대: 그날 진열은 통째로 비고 값이 0으로 떨어진다(그 0이 «냥 부족»으로 새던 자리)",
		not m._peddler_open_today()
		and Peddler.stock_rows(closed_day, [], {}).is_empty())
	# 다섯 경로를 전부 태운다 — 넷은 «0냥 부족», 하나(씨앗)·하나(품목)는 침묵이던 자리다.
	var set_id := String(HomeDecoCatalog.set_ids()[0])
	var crop_id := String(CropCatalog.ids()[0])
	var probes: Array = [
		["가구", func() -> void: m._try_buy_peddler_deco(set_id)],
		["희귀", func() -> void: m._try_buy_peddler_rare(ItemCatalog.WOOD)],
		["책", func() -> void: m._try_buy_peddler_book(String(Books.all_ids()[0]))],
		["씨앗", func() -> void: m._try_buy_peddler_seed(crop_id, 1)],
		["품목", func() -> void: m._try_buy_peddler_item(ItemCatalog.WOOD, 1)],
	]
	var silent: Array = []
	var lied: Array = []
	for p in probes:
		m.notice_feed._items.clear()
		(p[1] as Callable).call()
		var said := ""
		for it in m.notice_feed._items:
			said = String(it["text"])
		if said == "":
			silent.append(String(p[0]))
		elif not said.contains("오늘 안 온다"):
			lied.append("%s:%s" % [String(p[0]), said])
	_check("⑭c 다섯 경로가 전부 «오늘 안 온다»를 말한다 — 침묵 %s · 다른 사유 %s"
			% [str(silent), str(lied)],
		silent.is_empty() and lied.is_empty())
	_check("⑭d 지갑이 %d냥인데도 «냥이 모자라다»는 한 줄도 안 나왔다(0냥 자기모순 0)" % m.wallet.gold,
		m.wallet.gold > 0 and lied.is_empty())
	# 대조 — 출현일에는 이 갈래를 안 타고 종전 사슬로 흐른다.
	m.clock.day = open_day
	m.notice_feed._items.clear()
	m._try_buy_peddler_item(ItemCatalog.WOOD, 1)
	var open_txt := ""
	for it in m.notice_feed._items:
		open_txt = String(it["text"])
	_check("⑭e 대조군: 출현일에는 이 갈래를 안 탄다(«오늘 안 온다» 0) — 「%s」" % open_txt,
		m._peddler_open_today() and not open_txt.contains("오늘 안 온다")
		and m._peddler_price(ItemCatalog.WOOD) >= 0)
