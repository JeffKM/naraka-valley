extends SceneTree
# ★[폴리시 31회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#8).
#
# 렌즈: R30 diff 리뷰(#0~#3) · 단일 출처 술어 채택(#4) · 알림 keep 포화(#5·#6) ·
#       탈것/동행 동사 행렬(#7) · 목록 넘침 내비게이션(#8).
#   ※ #6은 배치 B 소관이라 이 스위트에 없다.
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
# 판정: CONFIRMED 9 · REFUTED·DUP·OWNER-DECISION 0.

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

func _initialize() -> void:
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R31 회귀 — 배치 A(#0~#8) ══")
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
