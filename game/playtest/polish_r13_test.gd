extends SceneTree
# ★[폴리시 13회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#9).
#
# 렌즈: R12 diff 리뷰 · 시그널/생애주기 · 문구·용어.
#
# 무엇을 보증하나(번호 = 13회차 헌트 배치 A 발견 인덱스):
#   ① #0 (high) R12가 세운 `is_maxed()` 술어는 "만점 상대의 선물은 실효가 정확히 0"을 전제했는데
#        **선물 점수에는 음수 채널이 열려 있다**(GiftPrefs DISLIKE·HATE). 만점 미호에게 업화석
#        조각을 건네면 points가 실제로 깎이는데도 화면은 "호감도는 이미 가득하다"만 말했고 주간
#        예산도 안 썼다 — 하류로는 `points_hearts()`가 내려가 떠 있던 ♡5 고백 제안이 이유 없이
#        사라졌다. 술어에 **부호**를 더해 실효가 있는 선물만 정직해진다(ADR-0008 게이트 추가 0).
#   ② #1 `_do_sleep`이 부르는 `_drop_cafe_popups()`가 **1회성 래치인 마일스톤 축하 팝업까지**
#        버렸다. 래치가 팝업보다 먼저 서므로 그 6초 안에 자면 축하 문구가 세이브에서 영영 사라진다
#        — R11이 바로 앞 회차에 세운 "정산은 미뤄도 되고 마일스톤은 잃으면 안 된다"의 뒤집힘.
#   ③ #2 R12 #9가 `_open_epilogue`에서 고친 "취침 트윈이 일시적으로 멈춰 둔 시계를 스냅한다"가
#        구조가 같은 형제 자리(`_open_spine_puzzle`)에 그대로 남아, 내면 공간을 닫으면 시계가
#        영구 정지했다(분 틱·NPC 스케줄·영업창·날씨 — 복구는 다시 취침뿐).
#   ④ #3 안식 농원 나무의 채취기·"수거 대기" 방울이 앞 패스 나무에 통째로 가려졌다 — Y-split이
#        숲에만 걸렸고(HOME은 앞 패스 호출부 자체가 없다), 원장 칸이 손저작 프롭의 **앵커**라
#        나무 발치와 채취기 발치가 96px 어긋나 있었다.
#   ⑤ #4 `mode != MODE_WINDOWED`가 창 **최대화**(MODE_MAXIMIZED)를 전체화면으로 오독해, F11 첫
#        입력이 전체화면 대신 최대화만 풀었다(설정 값도 안 바뀌어 저장조차 안 됐다).
#   ⑥ #5 씨앗 구매 안내가 **존재하지 않는 판매처 "카페"**를 가리켰다(옛 멜 카페 매대의 잔존 문구).
#   ⑦ #6 같은 거래 한 흐름 안에서 화폐 이름이 골드↔냥으로 갈렸다(실패 "골드 부족" / 성공 "−120냥").
#   ⑧ #7 멜 온보딩 대사가 폐기된 "멜=출하대 담당·즉시 지급" 설정을 그대로 말했다(ADR-0021 무인화).
#   ⑨ #8 같은 설비를 출하함/무인 출하함/출하대 세 이름으로 불렀다(도감 조건문만 다른 이름).
#   ⑩ #9 관계 탭 바나 효과줄에 영문 단위 "s"와, 아크 본문이 회귀로 금지한 옛 프레이밍이 남아 있었다.
#
# 판정: ①~⑩ 전부 CONFIRMED(REFUTED·DUP 없음).
#
# 실행: ./run_tests.sh polish_r13   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _src: PackedStringArray = PackedStringArray()

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

# ── 소스 스캔 헬퍼(polish_r7~r12의 그 관례) ─────────────────────────────────
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _line_of(needle: String) -> int:
	for i in _src.size():
		if _src[i].contains(needle):
			return i
	return -1

func _in_func(fn_needle: String, needle: String) -> bool:
	var head := _line_of(fn_needle)
	if head < 0:
		return false
	for i in range(head + 1, _src.size()):
		if _src[i].begins_with("func "):
			return false
		if _src[i].contains(needle):
			return true
	return false

# ★ 한 줄에서 **주석 밖 문자열 리터럴**만 뽑는다(따옴표 밖의 첫 `#`부터가 주석). 용어·화폐 스캔이
#   내부 식별자·설계 주석에 걸리지 않게 하는 것이 이 헬퍼의 전부다 — 표시 층만 잰다.
func _display_strings(line: String) -> Array:
	var out: Array = []
	var in_str := false
	var cur := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "\\" and in_str:
			i += 2                      # 이스케이프 한 쌍은 통째로 건너뛴다(\" 오판 방지)
			continue
		if c == "\"":
			if in_str:
				out.append(cur)
				cur = ""
			in_str = not in_str
		elif c == "#" and not in_str:
			break
		elif in_str:
			cur += c
		i += 1
	return out

# 그 파일의 표시 문자열 중 needle이 든 것들(파일:줄 꼬리표를 달아 돌려준다 — 실패 시 자리가 읽힌다).
func _display_hits(path: String, needle: String) -> Array:
	var out: Array = []
	var lines := _lines_of_file(path)
	for i in lines.size():
		for s in _display_strings(lines[i]):
			if String(s).contains(needle):
				out.append("%s:%d %s" % [path.get_file(), i + 1, s])
	return out

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R13 배치 A 회귀(#0~#9) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_check("무대 0: main.gd 소스를 읽었다(소스 단언의 전제)", _src.size() > 1000)

	var m := await _spawn_main()
	_check_gift_sign(m)
	_check_milestone_kept(m)
	_check_spine_clock(m)
	_check_home_tapper(m)
	_check_fullscreen(m)
	_check_seed_shop()
	_check_currency()
	_check_mel_intro(m)
	_check_ship_bin_name()
	_check_bana_summary()

	print("── 결과 ──")
	print("  실패 %d건" % _fail)
	quit(1 if _fail > 0 else 0)


# ── ① #0 만점 상대의 **음수** 선물이 정직하게 보고되고 예산도 쓴다 ────────────
# R12는 "만점 = 실효 0"이라는 절반만 참인 전제로 알림 문구와 주간 카운터를 함께 갈랐다. 천장에
# 눌리는 것은 양수뿐이고, 질색 선물은 만점에서도 points를 실제로 깎는다.
func _check_gift_sign(m: Node) -> void:
	print("── ① #0 만점 상대의 질색 선물이 사실을 말한다 ──")
	var hate_pts: int = GiftPrefs.POINTS[GiftPrefs.HATE]
	var love_pts: int = GiftPrefs.POINTS[GiftPrefs.LOVE]
	_check("①a-pre 무대: 선물 점수표에 **음수 채널**이 실재한다(HATE %d · LOVE +%d — 카탈로그 파생)"
			% [hate_pts, love_pts],
		hate_pts < 0 and love_pts > 0)

	# 술어 자체 — 부호가 판정을 가르는가(만점 하나로는 못 가르던 그 갈림).
	var maxed := Affinity.new()
	maxed.points = Affinity.MAX_POINTS
	var normal := Affinity.new()
	normal.points = 0
	_check("①b-pre 무대: 하나는 천장에 닿았고 하나는 아니다",
		maxed.is_maxed() and not normal.is_maxed())
	_check("①c 술어가 부호로 갈린다 — 만점+양수만 실효 0(만점+음수·비만점+양수는 아니다)",
		maxed.is_gift_no_op(love_pts)
		and not maxed.is_gift_no_op(hate_pts)
		and not normal.is_gift_no_op(love_pts)
		and not normal.is_gift_no_op(hate_pts))

	# 점수·예산 — 만점에서 건넨 질색 선물이 실제로 깎고 그 주 예산도 쓴다.
	var day := 12
	var got_hate := maxed.gift(hate_pts, day)
	_check("①d 만점 쪽 점수가 실제로 깎였다(%d → %d) · 반환도 명목 그대로"
			% [Affinity.MAX_POINTS, maxed.points],
		maxed.points == Affinity.MAX_POINTS + hate_pts and got_hate == hate_pts)
	_check("①e 그 선물은 **주간 예산을 쓴다** — 실효가 있으면 R12 이전 계약 그대로다",
		maxed.gifts_used_in_week(day) == 1
		and maxed.gifts_left_in_week(day) == Affinity.GIFTS_PER_WEEK - 1)

	# 대조 — 만점 + 양수는 R12 계약이 한 글자도 안 바뀐다(수정이 안 넓어졌다).
	var maxed2 := Affinity.new()
	maxed2.points = Affinity.MAX_POINTS
	var got_love := maxed2.gift(love_pts, day)
	_check("①f 대조: 만점+선호는 종전대로 실효 0이고 예산도 안 쓴다(R12 계약 보존)",
		maxed2.points == Affinity.MAX_POINTS and got_love == love_pts
		and maxed2.gifts_used_in_week(day) == 0)
	_check("①g 하루 1회 리듬은 부호와 무관하게 셋 다 소모된다(그건 예산이 아니라 날짜다)",
		not maxed.can_gift(day) and not maxed2.can_gift(day))
	maxed.free()
	maxed2.free()
	normal.free()

	# 화면 — 라이브 선물 한 번으로 알림 문구가 갈리는지 본다(소스가 아니라 거동으로).
	var r: Resident = m._resident("miho")
	var hate_id: String = GiftPrefs.OVERRIDES["miho"][GiftPrefs.HATE][0]
	_check("①h-pre 무대: 그 아이템이 미호에게 실제로 질색이다(%s — 선호표 파생)"
			% ItemCatalog.name_of(hate_id),
		r != null and r.affinity != null
		and GiftPrefs.tier_of("miho", hate_id) == GiftPrefs.HATE)
	if r == null or r.affinity == null:
		return
	r.affinity.points = Affinity.MAX_POINTS
	r.affinity.stage = Affinity.MAX_HEARTS
	r.affinity.last_gift_day = -1
	r.affinity.gift_week = -1
	r.affinity.gifts_this_week = 0
	m.clock.day = day
	m.inventory.add_item(hate_id, 1)
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == hate_id:
			m.inventory.select(i)
			break
	_check("①i-pre 무대: 만점·♡MAX 미호에게 질색 아이템을 손에 들었다",
		m.inventory.selected_id() == hate_id and r.affinity.is_maxed())
	m._try_resident_gift(r)
	var note: String = _last_notice(m)
	_check("①j 알림이 손실을 숫자로 말한다 — \"%+d 호감도\"가 뜨고 \"이미 가득하다\"는 안 뜬다"
			% hate_pts,
		note.contains("%+d 호감도" % hate_pts) and not note.contains("이미 가득하다"))
	_check("①k 그리고 실제로 깎였다(화면과 원장이 같은 말을 한다): %d" % r.affinity.points,
		r.affinity.points == Affinity.MAX_POINTS + hate_pts)
	_check("①l 하류 — 그 손실이 `points_hearts()`를 내려 진급 대기가 사라진다(고백 제안이 걸린 축)",
		r.affinity.points_hearts() < Affinity.MAX_HEARTS)


# ── ② #1 취침이 마일스톤 축하 팝업을 죽이지 않는다 ────────────────────────────
# 마일스톤은 1회성 래치고 그 래치가 팝업보다 **먼저** 선다 — 6초 안에 자면 다시 뜰 경로가 없다.
func _check_milestone_kept(m: Node) -> void:
	print("── ② #1 취침이 1회성 마일스톤 축하를 보존한다 ──")
	var latch := _line_of("\t\t_milestone_celebrated = true")
	var popup := _line_of("\t\t_show_milestone_reached()")
	_check("②a-pre 무대: 래치가 팝업보다 **먼저** 선다(main.gd:%d < %d — 가려지면 끝인 근거)"
			% [latch + 1, popup + 1],
		latch > 0 and popup > latch)
	_check("②b-pre 무대: 재기동·로드도 래치를 완성 여부에서 되세운다(다시 뜰 경로가 없는 근거)",
		_line_of("_milestone_celebrated = _milestone_complete()") > 0)

	var pending := "매출  +1234냥\n서빙한 손님  7명"
	m._cafe_summary_pending = pending
	m._cafe_summary_secs = m.CAFE_SUMMARY_SECS
	m._milestone_popup_secs = m.MILESTONE_POPUP_SECS
	m.cafe_summary_panel.visible = true
	m.milestone_panel.visible = true
	_check("②c-pre 무대: 다섯 조각이 실제로 서 있다(미룬 본문·정산 타이머·팝업 타이머·패널 둘)",
		m._cafe_summary_pending == pending and m._cafe_summary_secs > 0.0
		and m._milestone_popup_secs > 0.0
		and m.cafe_summary_panel.visible and m.milestone_panel.visible)

	m._drop_cafe_popups(true)
	_check("②d 취침 형태 — 정산 세 조각만 비고 **마일스톤 두 조각은 그대로 산다**",
		m._cafe_summary_pending == "" and m._cafe_summary_secs == 0.0
		and not m.cafe_summary_panel.visible
		and m._milestone_popup_secs == m.MILESTONE_POPUP_SECS
		and m.milestone_panel.visible)

	m._cafe_summary_pending = pending
	m._cafe_summary_secs = m.CAFE_SUMMARY_SECS
	m.cafe_summary_panel.visible = true
	m._drop_cafe_popups()
	_check("②e 기본 인자는 종전대로 다섯을 전부 버린다(로드 갈래의 R12 계약 보존)",
		m._cafe_summary_pending == "" and m._cafe_summary_secs == 0.0
		and m._milestone_popup_secs == 0.0
		and not m.cafe_summary_panel.visible and not m.milestone_panel.visible)
	_check("②f 두 호출부가 그 갈림을 실제로 쓴다 — 취침=보존 · 로드=전량 폐기",
		_in_func("func _do_sleep", "_drop_cafe_popups(true)")
		and _in_func("func _load_game", "_drop_cafe_popups()")
		and not _in_func("func _load_game", "_drop_cafe_popups(true)"))


# ── ③ #2 내면 공간이 취침 중 시계를 영구 정지시키지 않는다 ────────────────────
# `_do_sleep`이 세운 `clock.running = false`는 0.4초 트윈 동안의 일시적 값이다. 그 창에 컷신이
# 끝나면 `_end_cutscene`이 `_sleeping` 가드로 복원을 건너뛴 채 곧바로 내면 공간을 연다.
func _check_spine_clock(m: Node) -> void:
	print("── ③ #2 내면 공간이 취침 중 false를 스냅하지 않는다 ──")
	_check("③a-pre 무대: 취침이 시계를 끄고, 아침에 `clock.sleep`이 되돌린다(false가 일시적인 근거)",
		_in_func("func _do_sleep", "clock.running = false")
		and _in_func("func _do_sleep", "tw.tween_callback(clock.sleep)"))
	_check("③b-pre 무대: 컷신 종료가 `_sleeping`이면 시계 복원을 건너뛴다(그 false가 남는 경로)",
		_in_func("func _end_cutscene", "if not _sleeping:")
		and _in_func("func _end_cutscene", "_open_spine_puzzle()"))
	_check("③c 형제 두 자리가 **같은 처방**을 쓴다(에필로그 R12 #9 · 내면 공간 R13)",
		_line_of("_epilogue_clock_prev = clock.running or _sleeping") > 0
		and _line_of("_spine_b5_clock_prev = clock.running or _sleeping") > 0)
	_check("③d 닫는 자리가 그 스냅으로 복원한다(스냅이 진실이어야 하는 이유)",
		_in_func("func _close_spine_puzzle", "clock.running = _spine_b5_clock_prev"))

	# 거동 — 취침 트윈 한가운데를 만들어 실제로 열어 본다.
	var running_prev: bool = m.clock.running
	var sleeping_prev: bool = m._sleeping
	m._sleeping = true
	m.clock.running = false
	_check("③e-pre 무대: 지금이 그 0.4초다(`_sleeping` 참 · `clock.running` 거짓)",
		m._sleeping and not m.clock.running)
	m._open_spine_puzzle()
	_check("③f-pre 무대: 내면 공간이 실제로 열렸다(파편 %d개 — 로스터 파생)"
			% Spine.fragments().size(),
		m.spine_puzzle != null)
	_check("③g 스냅이 **true**다 — 닫으면 시계가 다시 흐른다(옛 코드는 여기서 false를 기억했다)",
		m._spine_b5_clock_prev)
	# 무대 원복(퍼즐 세션·대화·물리 잠금 — B6 이음매를 안 태우고 손으로 되돌린다).
	m.spine_puzzle = null
	m._spine_b5_frags = []
	while m.dialogue.is_open():
		m.dialogue.advance()
	m._sleeping = sleeping_prev
	m.clock.running = running_prev
	m.player.set_physics_process(true)


# ── ④ #3 안식 채취기가 자기 나무와 같은 패스를 탄다 ──────────────────────────
# 숲은 원장 칸이 곧 나무 **발치**라 `t.y*TILE+TILE`이 그 나무의 `_prop_base_y`와 같지만, 안식은
# 원장 칸이 손저작 프롭의 **앵커(스프라이트 상단)**라 둘이 어긋난다.
func _check_home_tapper(m: Node) -> void:
	print("── ④ #3 안식 채취기·수거 대기 방울이 나무에 안 묻힌다 ──")
	_check("④a-pre 무대: 지금 안식 농원이고 채취기 원장이 서 있다",
		m._region == RegionCatalog.HOME and m.tapper != null and m.tree_ledger != null)
	_check("④b-pre 무대: 안식 나무는 앞 패스를 타는 그림이다(SPLIT_PROPS ∧ FADE_PROPS 소속)",
		m.PROP_TREE_A in m.SPLIT_PROPS and m.PROP_TREE_A in m.FADE_PROPS)

	var anchors: Dictionary = m._home_tree_anchor_set()
	_check("④c-pre 무대: 손저작 나무 앵커가 %d칸 있다(layout.json HOME 파생)" % anchors.size(),
		anchors.size() > 0)
	if anchors.is_empty():
		return
	var t: Vector2i = anchors.keys()[0]
	_check("④d-pre 무대: 그 칸이 성숙목이라 채취기를 박을 수 있다(구역 제한 없음)",
		m._can_place_tapper(t))

	var tile_base := float(t.y * m.TILE + m.TILE)
	var tree_base: float = m._prop_base_y(t, 0, m.PROP_TREE_A)
	_check("④e-pre 무대: 보정이 없으면 두 발치가 어긋난다(나무 %.0f vs 타일 %.0f = 결함의 뿌리)"
			% [tree_base, tile_base],
		not is_equal_approx(tree_base, tile_base))
	_check("④f 보정을 더하면 채취기 발치가 **나무 발치와 정확히 같다**(Y-split이 둘을 못 가른다)",
		is_equal_approx(tile_base + m._tapper_home_drop(), tree_base))

	# 숲은 보정이 0인 근거 — `_forest_item`이 앵커를 rows−1만큼 역산해 항등식이 이미 성립한다.
	var foot := Vector2i(t.x, t.y + 4)
	var item: Dictionary = m._forest_item(m.PROP_TREE_A, foot)
	_check("④g 숲은 그 어긋남이 0이다 — 보정이 안식 전용인 근거(`_forest_item` 역산)",
		is_equal_approx(m._prop_base_y(item["tile"], 0, m.PROP_TREE_A),
			float(foot.y * m.TILE + m.TILE)))

	_check("④h 그리고 안식 갈래에 앞 패스 호출부가 생겼다(숲과 같은 줄)",
		_in_func("func _draw_front_props", "_draw_tappers_front(canvas)"))
	_check("④i 뒤 패스의 split 게이트도 안식을 포함한다(둘 중 하나만 고치면 그림이 사라진다)",
		_in_func("func _draw_tappers", "_in_forest() or _region == RegionCatalog.HOME"))


# ── ⑤ #4 창 최대화를 전체화면으로 오독하지 않는다 ────────────────────────────
func _check_fullscreen(m: Node) -> void:
	print("── ⑤ #4 F11·옵션 전체화면 토글의 현재 상태 판정 ──")
	# 옛 식(`mode != MODE_WINDOWED`)과 새 술어가 MAXIMIZED에서 실제로 갈린다 — 열거값 그 자체로.
	_check("⑤a-pre 무대: Window.Mode는 다섯이고 MAXIMIZED는 창모드도 전체화면도 아니다",
		Window.MODE_MAXIMIZED != Window.MODE_WINDOWED
		and Window.MODE_MAXIMIZED != Window.MODE_FULLSCREEN
		and Window.MODE_MAXIMIZED != Window.MODE_EXCLUSIVE_FULLSCREEN)
	_check("⑤b 두 토글 자리가 새 술어를 쓰고, 옛 식은 main.gd 전문에 0건이다",
		_in_func("func _toggle_fullscreen", "_window_is_fullscreen()")
		and _in_func("func _on_fullscreen_toggled", "_window_is_fullscreen()")
		and _line_of("mode != Window.MODE_WINDOWED") < 0)
	_check("⑤c 술어가 전체화면 **두 값만** 참으로 센다(EXCLUSIVE 포함 — 소스 형태)",
		_in_func("func _window_is_fullscreen", "m == Window.MODE_FULLSCREEN")
		and _in_func("func _window_is_fullscreen", "m == Window.MODE_EXCLUSIVE_FULLSCREEN"))

	# 라이브 — 창모드를 실제로 바꿔 판정을 재 본다(헤드리스가 모드를 안 받으면 -pre가 걸러 낸다).
	var win := m.get_window()
	var prev := win.mode
	win.mode = Window.MODE_MAXIMIZED
	if win.mode == Window.MODE_MAXIMIZED:
		_check("⑤d 최대화된 창은 전체화면이 **아니다**(F11 첫 입력이 전체화면으로 간다)",
			not m._window_is_fullscreen())
		win.mode = Window.MODE_FULLSCREEN
		if win.mode == Window.MODE_FULLSCREEN:
			_check("⑤e 대조: 전체화면은 참이다(판정이 통째로 뒤집히지 않았다)",
				m._window_is_fullscreen())
	else:
		# ★ 헤드리스(dummy 디스플레이)는 창모드 대입을 흘린다 — 무대가 안 서면 **단언을 안 한다**
		#   (참이 될 수밖에 없는 줄을 세우면 그게 공회전이다). 계약은 ⑤a~⑤c가 잰다.
		print("  · (헤드리스가 창모드를 안 받아 라이브 두 단언은 생략 — ⑤a~⑤c가 계약을 잰다)")
	win.mode = prev


# ── ⑥ #5 씨앗 구매 안내가 실재하는 창구만 가리킨다 ──────────────────────────
func _check_seed_shop() -> void:
	print("── ⑥ #5 씨앗 안내의 판매처 ──")
	_check("⑥a-pre 무대: 씨앗 창구 셋이 실재한다(만물상·야시장·보부상 — 결제 함수 파생)",
		_line_of("func _try_buy_market_seed") > 0
		and _line_of("func _try_buy_peddler_seed") > 0
		and _line_of("_notice(\"%s 씨앗 ×%d −%d냥 (만물상)\"") > 0)
	var stale := _display_hits("res://main.gd", "카페·만물상")
	_check("⑥b 밭·화분 두 프롬프트가 더는 카페를 가리키지 않는다(잔존 %d건)" % stale.size(),
		stale.is_empty())
	var hits := _display_hits("res://main.gd", "씨앗 없음 — 만물상에서 구매")
	_check("⑥c 두 프롬프트 다 실재하는 창구를 가리킨다(밭·화분 = %d건)" % hits.size(),
		hits.size() == 2)
	# 카페 실내에 씨앗 매대가 없다는 무대 — 표시 층에서 "카페"와 "씨앗"이 한 줄에 걸리는 곳이 0.
	var both: Array = []
	for h in _display_hits("res://main.gd", "카페"):
		if String(h).contains("씨앗"):
			both.append(h)
	_check("⑥d 표시 층에 '카페'와 '씨앗'이 함께 걸리는 문자열이 0건이다(카페엔 매대가 없다)",
		both.is_empty())


# ── ⑦ #6 화폐 이름이 표시 층에서 한 이름으로 모인다 ─────────────────────────
func _check_currency() -> void:
	print("── ⑦ #6 화폐 표기(골드↔냥) ──")
	var files := ["res://main.gd", "res://quest_board.gd", "res://summary.gd",
		"res://mel.gd", "res://miho.gd"]
	var leftovers: Array = []
	for f in files:
		leftovers.append_array(_display_hits(f, "골드"))
	_check("⑦a 표시 문자열에 '골드'가 0건이다(주석·내부 식별자는 이 스캔 밖 — 잔존 %d건)"
			% leftovers.size(),
		leftovers.is_empty())
	if not leftovers.is_empty():
		for h in leftovers:
			print("      · " + String(h))
	_check("⑦b-pre 무대: 그 자리를 냥이 실제로 채웠다(빈칸으로 지운 게 아니다)",
		_display_hits("res://main.gd", "냥").size() > 20)
	# 발견의 원문 — 같은 함수 안에서 실패와 성공이 같은 단위를 부른다(보부상·야시장·만물상 셋).
	_check("⑦c 보부상 씨앗 한 함수 안에서 실패·성공이 같은 단위다",
		_in_func("func _try_buy_peddler_seed", "\"냥 부족(%d 필요)\"")
		and _in_func("func _try_buy_peddler_seed", "−%d냥"))
	_check("⑦d 야시장·만물상 형제도 같다(한 창구만 고치면 갈림이 남는다)",
		_in_func("func _try_buy_market_seed", "\"냥 부족(%d 필요)\"")
		and _in_func("func _try_buy_market_seed", "−%d냥")
		and _in_func("func _buy_seed_store_n", "\"냥 부족(%d 필요)\"")
		and _in_func("func _buy_seed_store_n", "−%d냥"))
	_check("⑦e 잠정 결정이 지갑 머리말에 기록됐다(공식 명칭은 owner 몫이라는 단서)",
		_lines_of_file("res://wallet.gd").size() > 0
		and String("\n".join(_lines_of_file("res://wallet.gd"))).contains("표시 단위는 \"냥\"으로 통일"))


# ── ⑧ #7 멜 온보딩이 무인 출하함을 말한다 ───────────────────────────────────
func _check_mel_intro(m: Node) -> void:
	print("── ⑧ #7 멜 소개 대사와 출하함의 소유권 ──")
	var r_mel: Resident = m._resident("mel")
	var mel: Node2D = r_mel.node if r_mel != null else null
	var lines: PackedStringArray = mel.lines(0, true) if mel != null else PackedStringArray()
	var joined := "\n".join(lines)
	_check("⑧a-pre 무대: ♡0 소개 풀이 실제로 재생되는 묶음이다(%d줄)" % lines.size(),
		lines.size() > 0)
	_check("⑧b 폐기된 담당자 설정이 사라졌다('출하대가 내 담당')",
		not joined.contains("내 담당"))
	_check("⑧c 그 자리가 **무인 창구**를 말한다(ADR-0021 · CONTEXT [출하대])",
		joined.contains("주인 없는 창구"))
	_check("⑧d-pre 무대: 프롬프트도 무인·익일 정산이라 두 화면이 같은 말을 한다",
		_line_of("interact_prompt.text = \"[우클릭] 무인 출하함 (수확물 드롭 → 다음 아침 정산)\"") > 0)
	_check("⑧e 멜의 축(돈·장부·정확한 계산)은 그대로다(문구 교정이 캐릭터를 안 지웠다)",
		joined.contains("돈줄") and joined.contains("장부"))


# ── ⑨ #8 같은 설비를 한 이름으로 부른다 ─────────────────────────────────────
func _check_ship_bin_name() -> void:
	print("── ⑨ #8 출하 설비 명칭 통일 ──")
	var stale: Array = []
	for f in ["res://main.gd", "res://mel.gd", "res://miho.gd"]:
		stale.append_array(_display_hits(f, "출하대"))
	_check("⑨a 표시 층(프롬프트·알림·도감·대사)에 '출하대'가 0건이다(잔존 %d건)" % stale.size(),
		stale.is_empty())
	if not stale.is_empty():
		for h in stale:
			print("      · " + String(h))
	_check("⑨b 도감 머리글이 실제 투입 창구를 가리킨다(등재 조건과 같은 이름)",
		_line_of("◆ 명부 도감 ◆   출하함에 올린 것이 스스로 이름을 얻는다") > 0)
	_check("⑨c-pre 무대: 투입·회수·정산 알림 셋은 종전부터 '출하함'이었다(다수결의 근거)",
		_line_of("\"출하함에 %s%s %d개 (다음 아침 정산)\"") > 0
		and _line_of("\"출하함에서 %s %d개 회수\"") > 0
		and _line_of("\"출하함 정산 +%d냥\"") > 0)


# ── ⑩ #9 바나 효과줄의 단위·프레이밍 ────────────────────────────────────────
func _check_bana_summary() -> void:
	print("── ⑩ #9 관계 탭 바나 효과줄 ──")
	var asleep := BanaGuard.summary(0)
	var awake := BanaGuard.summary(2)
	_check("⑩a-pre 무대: ♡0은 잠듦 · ♡2는 깨어 있다(두 갈래가 다 살아 있다)",
		asleep.contains("잠듦") and not awake.contains("잠듦"))
	_check("⑩b 폐기된 프레이밍('경비')이 두 갈래 어디에도 없다 — 바나는 근원의 수호자다",
		not asleep.contains("경비") and not awake.contains("경비"))
	_check("⑩c 두 갈래 다 새 이름을 쓴다('바나 수호')",
		asleep.begins_with("바나 수호:") and awake.begins_with("바나 수호:"))
	var secs := int(round(BanaGuard.patience_secs(2)))
	_check("⑩d 시간 단위가 한글이다 — \"인내심 %d초\"(값은 매핑 파생, 계산 불변)" % secs,
		awake.contains("인내심 %d초" % secs) and not awake.contains("%ds" % secs))
	_check("⑩e bana_guard.gd 표시 문자열에 영문 단위 's'가 남아 있지 않다",
		_display_hits("res://bana_guard.gd", "%ds").is_empty())


func _last_notice(m: Node) -> String:
	var items: Array = m.notice_feed._items
	return "" if items.is_empty() else String(items[items.size() - 1]["text"])
