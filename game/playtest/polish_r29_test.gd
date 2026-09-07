extends SceneTree
# ★[폴리시 29회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#11).
#
# 렌즈: R28 diff 리뷰(#0~#4) · 증인 rot 재훑기(#5~#8) · ADR 계약 감사(#9~#11).
#
# 이 배치의 태도 셋.
#   ㉠ **판을 잘라도 글은 안 잘린다.** #0은 R28 #27이 하단 예약 띠를 지키려고 판 높이만 물렸는데
#      Godot Label은 부모 Panel이 안 잘라 주므로 본문이 그대로 흘러내리던 자리다. 잘라서 지키는
#      대신 **위로 밀어 올려** 지킨다 — 접는 축을 배제한 그 함수 머리말의 근거를 그대로 따른다.
#   ㉡ **선측정 규율은 항이 하나만 빠져도 무너진다.** #1은 R28 #22가 새로 그리는 줄이 `block`에
#      한 항도 안 들어가 마지막 통과 행이 24px 밀리던 자리, #2는 R28 #7이 끼운 행 하나가 막줄을
#      9-slice 테두리 위로 밀던 자리다(둘 다 눈금을 한 표로 모으고 **그린 자리를 실측**해 잰다).
#   ㉢ **낡은 증인은 재는 계약이 아니라 보는 자리를 고친다.** #5~#8은 프로덕션이 옳고 니들만
#      이사·접힘·조립식 전환을 못 따라간 자리다(#5·#6은 같은 이사가 원인인 형제 — 근거 공유).
#
# 무엇을 보증하나(번호 = 29회차 헌트 발견 인덱스).
#   ① #0 마감 정산 팝업의 **본문**이 하단 예약 띠 위에 산다(줄이 붙는 날에도 한 줄도 안 잃는다).
#   ② #1 숙련 탭이 그린 바닥이 나무 테두리 안쪽이다(전문직 효과 줄이 선측정에 든다).
#   ③ #2 옵션 탭 막줄(언어)이 baseline+descent까지 테두리 안쪽이다(눈금 = 한 표 파생).
#   ④ #3 음소거 체크박스가 **눌린다** — 형제(전체화면)와 같은 라우팅·같은 진실원(버스 mute).
#   ⑤ #4 곳간 안내가 자기 폭 예산 안에 든다(덧붙인 절이 말줄임으로 사라지지 않는다).
#   ⑥ #5~#8 네 증인이 새 계약을 물고, 재던 것을 그대로 잰다.
#   ⑦ #9 개간 성역의 축이 **solid**다 — 낫으로 벤 자리는 재점령 후보로 돌아온다(ADR-0055 §1/§2).
#
# 판정: CONFIRMED 10 · **OWNER-DECISION 2**(#10 멜 마진↔deed 폐루프 · #11 조연 게이트↔곱셈기
#   — 둘 다 코드 무수정, 후보 안은 커밋 본문에) · REFUTED·DUP 0.

var _fail := 0
var _src: PackedStringArray
var _inv_src: PackedStringArray
var _r8_src: PackedStringArray
var _r12_src: PackedStringArray
var _r17_src: PackedStringArray
var _mute_emits := 0

func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text().split("\n") if f != null else PackedStringArray()

func _line_of(lines: PackedStringArray, needle: String) -> int:
	for i in lines.size():
		if lines[i].contains(needle):
			return i
	return -1

# 그 함수 본문(다음 `func ` 줄 전까지) 안에서 니들이 몇 번 나오는가.
func _count_in(lines: PackedStringArray, fn_needle: String, needle: String) -> int:
	var head := _line_of(lines, fn_needle)
	if head < 0:
		return 0
	var n := 0
	for i in range(head + 1, lines.size()):
		if lines[i].begins_with("func "):
			break
		if lines[i].contains(needle):
			n += 1
	return n

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _dismiss_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 200:
		m.dialogue.advance()
		guard += 1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R29 회귀 — 배치 A(#0~#11) ══")
	_src = _lines_of_file("res://main.gd")
	_inv_src = _lines_of_file("res://inv_frame.gd")
	_r8_src = _lines_of_file("res://playtest/polish_r8_test.gd")
	_r12_src = _lines_of_file("res://playtest/polish_r12_test.gd")
	_r17_src = _lines_of_file("res://playtest/polish_r17_test.gd")
	var m := await _spawn_main()
	_dismiss_dialogue(m)
	m.frame.close()
	m._sleeping = false
	m._transitioning = false
	await _check_summary_body(m)      # ① #0
	await _check_skill_tab_block(m)   # ② #1
	await _check_options_last_row(m)  # ③ #2
	await _check_mute_click(m)        # ④ #3
	_check_larder_caption(m)          # ⑤ #4
	_check_stale_witnesses()          # ⑥ #5~#8
	_check_weed_sanctuary(m)          # ⑦ #9
	print("── 결과: %s (실패 %d) ──" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(0 if _fail == 0 else 1)

# ── ① #0 마감 정산 팝업 본문 ↔ 하단 예약 띠 ─────────────────────────────────
# R28 #27의 증인 ㉖d는 **판**만 재서 라벨 오버플로를 못 봤다 — 여기서는 라벨의 실제 바닥을 잰다.
func _check_summary_body(m: Node) -> void:
	print("① #0 마감 정산 팝업 ↔ 예약 띠(판이 아니라 **글**을 잰다)")
	_check("①a 배선: 안 들어가면 판을 자르지 않고 **윗변을 올린다**(씬 윗변은 meta에 한 번 굳힌다)",
		_count_in(_src, "func _layout_popup_panel", "panel.set_meta(\"popup_top_home\"") == 1
			and _count_in(_src, "func _layout_popup_panel", "top = maxf(MIRROR_VIEW_MARGIN, limit - need)") == 1
			and _count_in(_src, "func _layout_popup_panel", "panel.position.y = top") == 1)
	var panel = m.cafe_summary_panel
	var label = m.cafe_summary_text
	var view: Vector2 = m._logical_view_size(panel)
	var limit: float = view.y - NoticeFeed.RESERVE_BOTTOM
	# 평소(4줄) — 종전 그림과 같은 입력. 이 판이 아래로 내려가는 일은 어떤 본문에서도 없다.
	m._show_cafe_summary("── 오늘 카페 영업 마감 ──\n매출  +120냥\n서빙한 손님  3명\n놓친 손님  0명")
	await process_frame
	await process_frame
	var home_y: float = float(panel.get_meta("popup_top_home"))
	var top4: float = panel.position.y
	var body4: float = panel.position.y + label.position.y + label.size.y
	_check("①b 4줄(평소)도 본문 바닥이 예약 띠 위다(글 %.0f ≤ %.0f · 윗변 %.0f ≤ 씬 %.0f)"
			% [body4, limit, top4, home_y], body4 <= limit and top4 <= home_y)
	# 「아는 얼굴」·「체키」가 붙는 날 = 6줄. 이 본문이 R23 #17이 이름 붙인 그 그림을 만들던 입력이다.
	m._show_cafe_summary("── 오늘 카페 영업 마감 ──\n매출  +1240냥\n서빙한 손님  12명"
		+ "\n놓친 손님  3명\n아는 얼굴  2명\n체키  1장")
	await process_frame
	await process_frame
	var body_bottom: float = panel.position.y + label.position.y + label.size.y
	var panel_bottom: float = panel.position.y + panel.size.y
	_check("①c 무대: 6줄 본문(%.0fpx)이 씬이 준 라벨 칸보다 크다 — 그래서 판이 자라야 하는 프레임이다"
			% label.size.y, label.size.y > 92.0)
	_check("①d **본문 바닥**이 하단 예약 띠 위에 선다(글 %.0f ≤ 한계 %.0f · 논리 뷰 %.0f)"
			% [body_bottom, limit, view.y], body_bottom <= limit)
	_check("①e 판도 같은 한계 안이고, 라벨이 판 밖으로 안 나간다(판 바닥 %.0f · 글 %.0f)"
			% [panel_bottom, body_bottom],
		panel_bottom <= limit and body_bottom <= panel_bottom + 0.5)
	_check("①f 자란 만큼 **위로** 갔다(6줄 윗변 %.0f < 4줄 %.0f ≤ 씬 %.0f) — 접지 않고 지킨 자리"
			% [panel.position.y, top4, home_y], panel.position.y < top4)
	m.cafe_summary_panel.visible = false
	m._cafe_summary_secs = 0.0
	# 마일스톤 판(예약 띠 0)은 거동이 한 글자도 안 바뀐다 — 이 봉합의 사정거리 대조군.
	var mp = m.milestone_panel
	var mhome: float = float(mp.get_meta("popup_top_home")) if mp.has_meta("popup_top_home") \
		else mp.position.y
	m._layout_popup_panel(mp, m.milestone_text)
	_check("①g 대조군: 예약 띠 0인 마일스톤 판은 윗변 %.0f 그대로다(사정거리 한정)" % mhome,
		is_equal_approx(mp.position.y, mhome))

# ── ② #1 숙련 탭 선측정 ↔ 실제로 그린 바닥 ───────────────────────────────────
func _check_skill_tab_block(m: Node) -> void:
	print("② #1 숙련 탭 `block` ↔ 전문직 효과 줄")
	_check("②a 배선: 선측정과 그리기가 **같은 상수**로 그 줄을 센다(리터럴 흩어짐 0)",
		_count_in(_inv_src, "func _draw_skill_tab", "float(prof_lines.size()) * SK_PROF_LINE_H") == 1
			and _count_in(_inv_src, "func _draw_skill_tab", "y += SK_PROF_LINE_H") == 1)
	# 무대 — 다섯 스킬을 만렙으로 올리고 고를 수 있는 전문직을 **프로덕션 창구로** 전부 고른다.
	var skills: Array = [ProfessionCatalog.FARMING, ProfessionCatalog.FORAGING,
		ProfessionCatalog.FISHING, ProfessionCatalog.MINING, ProfessionCatalog.COMBAT]
	var top_xp: int = int(FarmSkill.XP_THRESHOLDS[FarmSkill.MAX_LEVEL - 1])
	m._farming_xp = top_xp
	m._foraging_xp = top_xp
	m._fishing_xp = top_xp
	m._mining_xp = top_xp
	m._combat_xp = top_xp
	var chosen := 0
	for skill: String in skills:
		for tier in [5, 10]:
			for p in ProfessionCatalog.tier_profs(skill, tier):
				if m._can_choose_profession(skill, String(p["id"])) and m.choose_profession(skill, String(p["id"])):
					chosen += 1
					break
	var lines_total := 0
	for row in m._skill_rows():
		lines_total += (row.get("profession_lines", []) as Array).size()
	_check("②b 무대: 전문직 %d개를 골라 효과 줄 %d개가 섰다(행마다 붙는 그 줄)" % [chosen, lines_total],
		lines_total >= 8)
	m.frame.open(InventoryFrame.CTX_MENU)
	m.frame.set_tab(InventoryFrame.TAB_SKILL)
	var panel: Rect2 = m.frame._panel_rect()
	var max_y: float = panel.end.y - InventoryFrame.FRAME_MARGIN
	# ★ 스크롤 **전 위치**를 훑는다 — 규율("들어갈 때만 그린다")은 어느 첫 행에서 시작해도
	#   성립해야 하고, 선측정에서 빠진 항은 시작 행에 따라 다른 곳에서 삐져나온다(한 위치만
	#   재면 그 프레임에서만 우연히 안 넘칠 수 있다 — 이 단언이 실제로 그렇게 공허했다).
	var rows_n: int = m._skill_rows().size()
	var worst := 0.0
	var worst_at := -1
	var outside: Array = []
	for s in rows_n:
		m.frame._skill_scroll = s
		m.frame.queue_redraw()
		await process_frame
		await process_frame
		if m.frame._skill_draw_bottom > worst:
			worst = m.frame._skill_draw_bottom
			worst_at = s
		for e in m.frame._prof_choice_rects:
			if (e["rect"] as Rect2).end.y > max_y:
				outside.append("전문직:%s(첫행 %d)" % [String(e["skill"]), s])
		for e in m.frame._mastery_rects:
			if (e["rect"] as Rect2).end.y > max_y:
				outside.append("경지:%s(첫행 %d)" % [String(e["skill"]), s])
	_check("②c 스크롤 %d위치 전부에서 그린 바닥이 9-slice 테두리 안쪽이다(최악 %.0f@첫행 %d ≤ %.0f · 판 %.0f~%.0f)"
			% [rows_n, worst, worst_at, max_y, panel.position.y, panel.end.y],
		worst > 0.0 and worst <= max_y)
	_check("②d 등록된 클릭 영역도 전부 그 선 안이다(밖: %s)"
			% ("없음" if outside.is_empty() else ", ".join(outside)), outside.is_empty())
	m.frame._skill_scroll = 0
	m.frame.close()

# ── ③ #2 옵션 탭 막줄 ↔ 나무 테두리 ──────────────────────────────────────────
func _check_options_last_row(m: Node) -> void:
	print("③ #2 옵션 탭 막줄(언어) ↔ 9-slice 테두리")
	_check("③a 배선: 그리기가 눈금 **한 표**를 소비한다(리터럴 sy += 흩어짐 0)",
		_count_in(_inv_src, "func _draw_options_tab", "options_row_ys(panel)") == 1
			and _count_in(_inv_src, "func _draw_options_tab", "sy += ") == 0)
	m.frame.open(InventoryFrame.CTX_MENU)
	m.frame.set_tab(InventoryFrame.TAB_OPTIONS)
	m.frame.queue_redraw()
	await process_frame
	await process_frame
	var panel: Rect2 = m.frame._panel_rect()
	var max_y: float = panel.end.y - InventoryFrame.FRAME_MARGIN
	var desc: float = HanjiUi.text_descent(12)
	_check("③b 무대: 그리기가 막줄 baseline을 남겼다(%.0f)" % m.frame._opt_last_baseline,
		m.frame._opt_last_baseline > 0.0)
	_check("③c 막줄 아랫동(baseline %.0f + descent %.0f = %.0f)이 테두리 안쪽이다(≤ %.0f)"
			% [m.frame._opt_last_baseline, desc, m.frame._opt_last_baseline + desc, max_y],
		m.frame._opt_last_baseline + desc <= max_y)
	# 다섯 행이 서로 안 물린다 — 행 하나를 끼울 때 위로 압축하다 겹치면 그것도 같은 결함이다.
	var rows: Array = m.frame.options_row_ys(panel)
	var overlap: Array = []
	for i in range(1, rows.size()):
		if float(rows[i]) - float(rows[i - 1]) < 20.0:
			overlap.append("%d↔%d" % [i, i + 1])
	_check("③d 다섯 행이 서로 안 물린다(간격 최소 20px · 겹침: %s)"
			% ("없음" if overlap.is_empty() else ", ".join(overlap)), overlap.is_empty())
	m.frame.close()

# ── ④ #3 음소거 체크박스 ↔ 클릭 라우팅 ──────────────────────────────────────
func _on_mute_emit() -> void:
	_mute_emits += 1

func _check_mute_click(m: Node) -> void:
	print("④ #3 음소거 체크박스 ↔ 눌리는가")
	_check("④a 배선: 칸이 필드로 서고 라우팅 갈래가 있다(전체화면과 같은 결) · main이 받는다",
		_count_in(_inv_src, "func _draw_options_tab", "_mute_rect = Rect2(") == 1
			and _count_in(_inv_src, "func _click_menu", "_mute_rect.has_point(p)") == 1
			and _count_in(_src, "func _setup_settings", "frame.mute_toggled.connect(_on_frame_mute_toggled)") == 1)
	m.frame.open(InventoryFrame.CTX_MENU)
	m.frame.set_tab(InventoryFrame.TAB_OPTIONS)
	m.frame.queue_redraw()
	await process_frame
	await process_frame
	var mb: Rect2 = m.frame._mute_rect
	var fb: Rect2 = m.frame._fullscreen_rect
	_check("④b 무대: 그리기가 두 칸을 같은 x·같은 치수로 세웠다(음소거 %s · 전체화면 %s)"
			% [str(mb), str(fb)],
		mb.size == fb.size and is_equal_approx(mb.position.x, fb.position.x)
			and mb.position.y > fb.position.y)
	_mute_emits = 0
	if not m.frame.mute_toggled.is_connected(_on_mute_emit):
		m.frame.mute_toggled.connect(_on_mute_emit)
	m.frame._click_menu(mb.position + mb.size * 0.5)
	_check("④c 칸 한복판을 누르면 신호가 나간다(%d건 — 종전엔 어떤 rect에도 안 걸려 0건)" % _mute_emits,
		_mute_emits == 1)
	# 대조군 — 두 칸 사이의 빈 자리는 여전히 아무 일도 안 한다(라우팅이 넓어진 게 아니다).
	m.frame._click_menu(Vector2(mb.position.x + 4.0, (fb.end.y + mb.position.y) * 0.5))
	_check("④d 대조군: 두 칸 사이 빈 자리는 신호를 안 낸다(%d건 그대로)" % _mute_emits,
		_mute_emits == 1)
	# 진실원 왕복 — main 핸들러가 실제 버스 mute를 뒤집는다([M]과 같은 동사).
	var was: bool = m.audio.is_muted()
	m.audio.set_muted(false)
	m._on_frame_mute_toggled()
	var after_on: bool = m.audio.is_muted()
	m._on_frame_mute_toggled()
	var after_off: bool = m.audio.is_muted()
	_check("④e main 핸들러가 버스 mute를 실제로 뒤집는다(꺼짐→%s→%s)"
			% [str(after_on), str(after_off)], after_on and not after_off)
	m.audio.set_muted(was)
	m.frame.close()

# ── ⑤ #4 곳간 안내 ↔ 자기 폭 예산 ───────────────────────────────────────────
func _check_larder_caption(m: Node) -> void:
	print("⑤ #4 곳간 안내 한 줄 ↔ 폭 예산")
	_check("⑤a 배선: 그리기가 조립·예산을 **같은 두 함수**에서 받는다(회귀가 그것을 잰다)",
		_count_in(_inv_src, "func _draw_larder_top", "larder_caption()") == 1
			and _count_in(_inv_src, "func _draw_larder_top", "larder_caption_budget()") == 1)
	var f = m.frame
	var keep: PackedStringArray = f._menu_board
	# 최악 = 메뉴판 만석(슬롯 상한은 카탈로그에서 판다 — 수 옮겨 적기 0).
	var full := PackedStringArray()
	for i in MenuCatalog.FUSION_SLOTS_STAGE2:
		full.append("__slot%d" % i)
	f.set_menu_board(full)
	var cap: String = f.larder_caption()
	var budget: float = f.larder_caption_budget()
	var w: float = HanjiUi.text_width(cap, 12)
	f.set_menu_board(PackedStringArray())
	var bare: String = f.larder_caption()
	f.set_menu_board(full)
	_check("⑤b 무대: 꼬리가 실제로 붙은 최악 문자열이다 — 「%s」(메뉴판 없으면 「%s」)" % [cap, bare],
		cap.length() > bare.length() and cap.begins_with(bare)
			and cap.contains("흐린 줄") and bare.contains("적재") and bare.contains("회수"))
	_check("⑤c 그 줄이 예산 안에 든다(%.0fpx ≤ %.0fpx)" % [w, budget], w <= budget)
	_check("⑤d 그래서 말줄임이 한 글자도 안 먹는다(그리기가 넘기는 그 폭으로 실측)",
		HanjiUi.elide(cap, 12, budget) == cap)
	f.set_menu_board(keep)

# ── ⑥ #5~#8 낡은 증인 넷 ────────────────────────────────────────────────────
# 재는 계약은 보존하고 **보는 자리**만 새 프로덕션으로 옮겼는가.
func _check_stale_witnesses() -> void:
	print("⑥ #5~#8 증인 rot 정정(계약 보존 · 자리 이동)")
	_check("⑥a #5·#6 형제: 두 스위트가 이사한 함수(`_free_pasture_slots`)를 물고, "
			+ "방출이 그 표를 쓰는 것도 함께 잰다(옛 니들은 남아 있지 않다)",
		_line_of(_r8_src, "_in_func(\"func _release_open_buildings\", \"ranch.occupied_pasture_tiles()\")") < 0
			and _line_of(_r12_src, "_in_func(\"func _release_open_buildings\", \"ranch.occupied_pasture_tiles()\")") < 0
			and _line_of(_r8_src, "_in_func(\"func _free_pasture_slots\", \"ranch.occupied_pasture_tiles()\")") > 0
			and _line_of(_r12_src, "_in_func(\"func _free_pasture_slots\", \"ranch.occupied_pasture_tiles()\")") > 0
			and _line_of(_r8_src, "_in_func(\"func _release_open_buildings\", \"_free_pasture_slots()\")") > 0
			and _line_of(_r12_src, "_in_func(\"func _release_open_buildings\", \"_free_pasture_slots()\")") > 0)
	_check("⑥b 프로덕션 쪽 근거: 슬롯 계산이 그 한 함수에 있고 방출은 그것만 부른다",
		_count_in(_src, "func _free_pasture_slots", "ranch.occupied_pasture_tiles()") == 1
			and _count_in(_src, "func _release_open_buildings", "_free_pasture_slots()") == 1
			and _count_in(_src, "func _release_open_buildings", "ranch.occupied_pasture_tiles()") == 0)
	_check("⑥c #7: r17 ⑦b가 **접힌 호출문 한 문장**을 보는 자로 갈렸다(줄 전제 폐기)",
		_line_of(_r17_src, "func _call_stmt_at") > 0
			and _line_of(_r17_src, "_call_stmt_at(_inv_src, dsc).contains(\"opt_w\")") > 0)
	_check("⑥d #8: r17 ⑤b가 접두사 리터럴이 아니라 **조립 결과**를 잰다(최악 메뉴판까지 세운다)",
		_line_of(_r17_src, "frame.larder_caption()") > 0
			and _line_of(_r17_src, "_literal_at(_inv_src, _line_in_func(_inv_src, \"func _draw_larder_top\"") < 0)

# ── ⑦ #9 개간 성역 ↔ solid 축(ADR-0055 §1/§2) ────────────────────────────────
func _check_weed_sanctuary(m: Node) -> void:
	print("⑦ #9 «치운 자리 성역»의 축은 solid다")
	_check("⑦a 배선: 후보 필터가 종을 가르는 술어를 문다(두 배제 모두)",
		_count_in(_src, "func _encroach_candidates", "reclaim.is_weed_cleared(t)") == 1
			and _count_in(_src, "func _encroach_candidates", "occ.has(t) and not weed_opened") == 1
			and _count_in(_src, "func _encroach_candidates", "reclaim.is_cleared(t) and not weed_opened") == 1)
	# 순수 원장 — 종별 판정이 카탈로그의 solid를 그대로 따른다(수 옮겨 적기 0).
	var r := Reclaim.new()
	var tw := Vector2i(3, 3)
	var te := Vector2i(4, 4)
	var ts := Vector2i(5, 5)
	r.clear(tw, DebrisCatalog.WEEDS, DebrisCatalog.tool_for(DebrisCatalog.WEEDS))
	r.clear(te, DebrisCatalog.EMBER, DebrisCatalog.tool_for(DebrisCatalog.EMBER))
	r.clear(ts, DebrisCatalog.STUMP, DebrisCatalog.tool_for(DebrisCatalog.STUMP))
	_check("⑦b 잡초(non-solid)를 벤 자리만 «성역 아님»이다(잡초 %s · 업화석 %s · 석화 고목 %s)"
			% [str(r.is_weed_cleared(tw)), str(r.is_weed_cleared(te)), str(r.is_weed_cleared(ts))],
		r.is_weed_cleared(tw) and not r.is_weed_cleared(te) and not r.is_weed_cleared(ts)
			and r.is_cleared(tw) and r.is_cleared(te) and r.is_cleared(ts))
	# 세이브 왕복 — 종이 살아 넘어간다. 구세이브(2튜플)는 종 미상이라 **성역 유지**(보수적).
	var r2 := Reclaim.new()
	r2.load_save(r.to_save())
	_check("⑦c 세이브 왕복에서 종이 보존된다(잡초 %s · 업화석 %s)"
			% [str(r2.is_weed_cleared(tw)), str(r2.is_weed_cleared(te))],
		r2.is_weed_cleared(tw) and not r2.is_weed_cleared(te)
			and r2.is_cleared(tw) and r2.is_cleared(te))
	var r3 := Reclaim.new()
	r3.load_save({"cleared": [[tw.x, tw.y]]})
	_check("⑦d 구세이브 2튜플은 종 미상 → 성역 유지(더 단단한 계약을 안 깬다)",
		r3.is_cleared(tw) and not r3.is_weed_cleared(tw))
	# 라이브 — 시드 배치 잡초 한 포기를 낫으로 베면 그 칸이 재점령 후보로 **돌아온다**.
	m._indoor = ""
	m._region = RegionCatalog.HOME
	var weeds: Array = []
	var embers: Array = []
	for entry in m._home_prop_entries():
		var kind: String = m.DEBRIS_KIND.get(entry[0], "")
		if kind != DebrisCatalog.WEEDS and kind != DebrisCatalog.EMBER:
			continue
		for t: Vector2i in entry[1]:
			if not m.ENCROACH_SCAN_RECT.has_point(t) or m.reclaim.is_cleared(t):
				continue
			if kind == DebrisCatalog.WEEDS:
				weeds.append(t)
			else:
				embers.append(t)
	_check("⑦e 무대: 스캔 구역 안의 시드 잡초 %d포기 · 시드 업화석 %d개를 잡았다"
			% [weeds.size(), embers.size()], weeds.size() > 0 and embers.size() > 0)
	if weeds.is_empty() or embers.is_empty():
		return
	var before: Array = m._encroach_candidates()
	var pre_hit: Array = []
	for t: Vector2i in weeds:
		if before.has(t):
			pre_hit.append(t)
	_check("⑦f 무대: 아직 안 벤 잡초 칸은 프롭 점유라 한 칸도 후보가 아니다(대조군 시작점 — %d칸)"
			% pre_hit.size(), pre_hit.is_empty())
	for t: Vector2i in weeds:
		m.reclaim.clear(t, DebrisCatalog.WEEDS, DebrisCatalog.tool_for(DebrisCatalog.WEEDS))
	for t: Vector2i in embers:
		m.reclaim.clear(t, DebrisCatalog.EMBER, DebrisCatalog.tool_for(DebrisCatalog.EMBER))
	var after: Array = m._encroach_candidates()
	var back: Array = []
	for t: Vector2i in weeds:
		if after.has(t):
			back.append(t)
	var leaked: Array = []
	for t: Vector2i in embers:
		if after.has(t):
			leaked.append(t)
	_check("⑦g 벤 잡초 자리가 후보로 **돌아온다**(%d/%d칸 · ADR-0055 §1 «잡초 = 매일 재생»)"
			% [back.size(), weeds.size()], back.size() > 0)
	_check("⑦h 치운 업화석 자리는 영구 성역 그대로다(%d/%d칸 누출 · §2 «구조적 개간은 영구 진보»)"
			% [leaked.size(), embers.size()], leaked.is_empty())
