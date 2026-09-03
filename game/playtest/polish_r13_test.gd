extends SceneTree
# ★[폴리시 13회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#9) + 배치 B(#10~#18).
#
# 렌즈: R12 diff 리뷰 · 시그널/생애주기 · 문구·용어 · 원장 단조성 · 맵 가장자리 ·
#       상태변경↔무효화 짝 · 시계 정지/재개 · 경제 흐름.
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
#   ⑪ #10·#11 `if data.has(key):` 가드 때문에 키 없는 구세이브를 **실행 중에** F9로 읽으면
#        `load_save`가 아예 안 불려 버린 타임라인의 누적이 살아남았다 — 갱도 도달 최심층은
#        바나 ♡1 deed 관문을, 명부 도감 등재는 1회성 트로피 래치를 잘못 연다.
#   ⑫ #12 층 폭(24칸=768px)이 화면 폭(960px)보다 좁은데 카메라 한계를 층 크기 그대로 잡아,
#        층이 화면 오른쪽에 붙고 왼쪽 6칸이 아무것도 안 그려진 검은 띠로 남았다.
#   ⑬ #13 (high) 앞 패스는 마을·삼도천·황천해도 그리는데 재분할 게이트와 fade는 안식·숲만
#        알아서, 그 세 구역의 앞 패스가 진입 프레임의 split_y로 굳었다(나무가 사라지거나 덮었다).
#   ⑭ #14 더비 태그를 교환해도 좌판 위 금빛 점이 안 꺼졌다(`SeasonalEvent`엔 `changed`가 없다).
#   ⑮ #15 F10 배치 모드의 놓기·삭제가 main만 갱신해 앞 패스에 옛 그림이 남았다.
#   ⑯ #16 `_close_epilogue`가 취침 여부를 안 보고 시계·이동 잠금을 되살렸다 — 암전 뒤에서
#        플레이어가 걸어 다니는, R12가 형제 셋에서 막은 바로 그 증상의 마지막 자리.
#   ⑰ #17·#18 카탈로그가 값을 매긴 자재 셋(삭은 그물·넋가루·혼불씨)에 냥으로 바꾸는 창구가
#        0이었다 — R8(중복 유품)·R9(결정기 부품)과 같은 클래스.
#
# 판정: ①~⑰ 전부 CONFIRMED(REFUTED·DUP 없음). #19(곁들이 혼력 자기증식)는 OWNER-DECISION —
#       쿨다운·상한 신설은 새 게이트라 여기서 안 잰다.
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

# 같은 함수 몸통 안에서 니들이 몇 번 나오는가(무효화 자리 수를 세는 단언용 — 잔존 0건 확인).
func _count_in_func(fn_needle: String, needle: String) -> int:
	var head := _line_of(fn_needle)
	if head < 0:
		return -1
	var n := 0
	for i in range(head + 1, _src.size()):
		if _src[i].begins_with("func "):
			break
		if _src[i].contains(needle):
			n += 1
	return n

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
	print("══ 폴리시 R13 회귀 — 배치 A(#0~#9) + 배치 B(#10~#18) ══")
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
	_check_ledger_rollback(m)
	_check_floor_camera(m)
	_check_split_source(m)
	_check_derby_redraw(m)
	_check_edit_invalidate(m)
	_check_epilogue_sleep(m)
	_check_shippable_materials(m)

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


# ── ⑪ #10·#11 F9 인플레이스 로드가 누적 원장을 되감는다 ──────────────────────
# `if data.has(key):` 가드 때문에 키 없는 구세이브를 **실행 중에** F9로 읽으면 `load_save`가 아예
# 안 불려 버린 타임라인의 누적이 살아남았다. 소비처가 관계 관문(갱도 깊이 → 바나 ♡1 deed)과
# 1회성 트로피 래치(도감)라 결과가 무겁다. R3(아이템 원장 넷)·R12(삽사리·승마)와 같은 처방이되,
# 판별식은 "부팅으로 시드되는가"다 — 여기 여덟은 오직 플레이로만 쌓이므로 빈 dict = 부팅 결과다.
func _check_ledger_rollback(m: Node) -> void:
	print("── ⑪ #10·#11 키 없는 구세이브가 누적 원장을 되감는다 ──")
	var calls := [
		"museum.load_save(data.get(\"museum\", {}))",
		"codex.load_save(data.get(\"codex\", {}))",
		"fireflies.load_save(data.get(\"fireflies\", {}))",
		"quest_board.load_save(data.get(\"quest_board\", {}))",
		"mine_floors.load_save(data.get(\"mine\", {}))",
		"guests.load_save(data.get(\"guest_pool\", {}))",
		"trial.load_save(data.get(\"trial_ground\", {}))",
	]
	var missing: Array = []
	for c in calls:
		if not _in_func("func _load_game", String(c)):
			missing.append(c)
	_check("⑪a 로드 경로가 누적 원장 일곱을 **무조건** 부른다(`.get` 빈 dict 폴백 — 누락 %d건)"
			% missing.size(), missing.is_empty())
	for c in missing:
		print("      · 누락: " + String(c))
	var guards: Array = []
	for k in ["\"museum\"", "\"codex\"", "\"fireflies\"", "\"quest_board\"", "\"mine\"",
			"\"guest_pool\"", "\"trial_ground\"", "\"forage_found\""]:
		if _in_func("func _load_game", "data.has(%s)" % String(k)):
			guards.append(k)
	_check("⑪b 그 여덟(발견 원장 포함)에 `has` 가드가 안 남았다(부분 수정 방지 — 잔존 %d건)"
			% guards.size(), guards.is_empty())
	_check("⑪c-pre 무대: 부팅이 맵에서 다시 시드하는 원장(채집물·꽃·절기 스폰·열매)은 **그대로 가드를 둔다**"
			+ " — 그쪽은 빈 dict ≠ 부팅 결과다",
		_in_func("func _load_game", "data.has(\"forage\")")
		and _in_func("func _load_game", "data.has(\"flower_patch\")")
		and _in_func("func _load_game", "data.has(\"forage_spawn\")")
		and _in_func("func _load_game", "data.has(\"berry_bush\")"))

	# ── 거동으로 잰다: 키를 뺀 세이브를 만들고, 살아 있는 노드에 버린 타임라인을 새긴 뒤 F9.
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	var keys := ["mine", "codex", "quest_board", "guest_pool", "trial_ground", "forage_found"]
	var present := true
	for k in keys:
		if not raw.has(k):
			present = false
		raw.erase(k)
	_check("⑪d-pre 무대: 방금 쓴 세이브엔 여섯 키가 다 있었고, 그것을 지워 **키 없는 구세이브**를 만들었다",
		present)
	m.saver.save_game(raw, m._active_slot)

	var tracked: Array = Codex.tracked_ids()
	var sample_id := String(tracked[0]) if not tracked.is_empty() else ""
	m.mine_floors.load_save({"depth": Deed.BANA_MINE_DEPTH})
	m.codex.load_save({"shipped": {sample_id: m.clock.day}})
	m.quest_board.load_save({"completed_total": 7})
	var guest_id := String(GuestPool.GUEST_IDS[0])   # 로스터 파생(하드코딩 금지 — 표에 없는 id는 걸러진다)
	m.guests.load_save({"visits": {guest_id: 3}})
	m.trial.load_save({"tokens": 5})
	m._forage_found = {"soul_fiber": 1}
	_check("⑪e-pre 무대: 살아 있는 노드에 버린 타임라인이 새겨졌다(깊이 %d · 도감 '%s' 등재 · 의뢰 7 · 단골 · 시련패 5 · 발견 1)"
			% [m.mine_floors.depth(), sample_id],
		m.mine_floors.depth() >= Deed.BANA_MINE_DEPTH and m.codex.shipped_count() == 1
		and m.quest_board.completed_total == 7 and m.trial.tokens == 5
		and m.guests.visits_of(guest_id) == 3 and m._forage_found.size() == 1)
	_check("⑪f-pre 무대: 그 상태에선 바나 ♡1 deed 관문이 실제로 **열려 있다**(되감김의 하류가 관계 관문이다)",
		Deed.check("bana", 1, m._deed_ledgers()))

	var loaded: bool = m._load_game()
	_check("⑪g-pre 무대: F9 로드가 성립했다", loaded)
	_check("⑪h 여섯 원장이 전부 '키 없는 구세이브의 뜻'(0)으로 되감겼다",
		m.mine_floors.depth() == 0 and m.codex.shipped_count() == 0
		and m.quest_board.completed_total == 0 and m.trial.tokens == 0
		and m.guests.visits_of(guest_id) == 0 and m._forage_found.is_empty())
	_check("⑪i 하류가 함께 닫혔다 — 갱도에 한 번도 안 들어간 세이브에서 바나 ♡1 관문이 안 열린다",
		not Deed.check("bana", 1, m._deed_ledgers())
		and int(m._deed_ledgers()["mine_depth"]) == 0)


# ── ⑫ #12 좁은 층에서 카메라가 화면 정중앙에 선다 ────────────────────────────
# 층은 24칸(768px)인데 화면은 960px다. Godot Camera2D는 한계를 좌→우 순으로 클램프하고 뒤가
# 이기므로, 한계를 층 크기 그대로 두면 화면 rect가 `limit_right − 960`에 고정돼 층이 오른쪽에
# 붙고 왼쪽 6칸이 아무것도 안 그려진 검은 띠로 남았다(지면 굽기는 층 폭까지뿐이라 채울 그림도 없다).
func _check_floor_camera(m: Node) -> void:
	print("── ⑫ #12 갱도·나락 층 카메라 정렬 ──")
	var view_w: float = m.get_viewport_rect().size.x / m._cam.zoom.x
	var floor_w: int = MineFloors.FLOOR_W * m.TILE
	_check("⑫a-pre 무대: 층 폭(%dpx)이 화면 폭(%dpx)보다 **좁다** — 이 결함이 성립하는 조건 자체"
			% [floor_w, int(view_w)], float(floor_w) < view_w)

	var prev_region: String = m._region
	var prev_floor: int = m._mine_floor
	m._region = RegionCatalog.EOPHWA_MINE
	m._mine_floor = 1
	_check("⑫b-pre 무대: 지금이 갱도 층이다(카메라 분기가 실제로 이 갈래를 탄다)", m._in_mine_floor())
	m._apply_camera_limits()
	var lft: int = m._cam.limit_left
	var rgt: int = m._cam.limit_right
	_check("⑫c 한계 중심 = 층 중심(left %d + right %d == 층 폭 %d) — 층이 화면 정중앙에 선다"
			% [lft, rgt, floor_w], lft + rgt == floor_w)
	_check("⑫d 한계 폭(%dpx)이 화면 폭 이상이라 좌·우 클램프가 같은 값을 낸다(죽은 띠가 안 남는다)"
			% (rgt - lft), float(rgt - lft) >= view_w)
	_check("⑫e 세로는 손대지 않았다 — 층 높이(%dpx)가 화면보다 높아 남는 폭이 0이다"
			% (MineFloors.FLOOR_H * m.TILE),
		m._cam.limit_top == 0 and m._cam.limit_bottom == MineFloors.FLOOR_H * m.TILE)

	m._mine_floor = prev_floor
	m._region = prev_region
	m._apply_camera_limits()
	var out_w: int = RegionCatalog.size_of(m._region).x * m.TILE
	_check("⑫f 지상은 종전 그대로다(구역이 화면보다 넓어 패딩 0 — left 0 · right = 구역 폭 %d)" % out_w,
		m._cam.limit_left == 0 and m._cam.limit_right == out_w)


# ── ⑬ #13 Y-split의 구역 목록이 단일 출처다 ─────────────────────────────────
# 앞 패스(`_draw_front_props`)는 마을·삼도천·황천해도 그리는데 행 넘김 재분할 게이트와
# occlusion fade는 안식·숲만 알고 있었다 — 그 세 구역의 앞 패스가 진입 프레임의 split_y로 굳어,
# 뒤 패스만 매 걸음 다시 갈리는 동안 마을 벚꽃 나무가 통째로 사라지거나 플레이어를 덮었다.
func _check_split_source(m: Node) -> void:
	print("── ⑬ #13 앞 패스·재분할·fade가 같은 구역 목록을 쓴다 ──")
	_check("⑬a 재분할 게이트가 술어를 쓴다(`_process`의 행 넘김 블록)",
		_in_func("func _process", "if _has_split_pass() and player != null:"))
	_check("⑬b 앞 패스도 같은 술어로 열린다(한쪽만 늘면 '안 그려짐'으로 즉시 드러난다)",
		_in_func("func _draw_front_props", "not _has_split_pass()"))
	_check("⑬c fade가 앞 패스와 **같은 배열**을 본다(`_fade_prop_entries` = `_split_prop_entries`)",
		_in_func("func _fade_prop_entries", "return _split_prop_entries()"))

	var prev_region: String = m._region
	_check("⑬d-pre 무대: 부팅 구역(안식)은 종전부터 재분할·fade를 받았다(회귀 없음 확인)",
		m._has_split_pass() and not m._split_prop_entries().is_empty())
	var home_entries: Array = m._split_prop_entries()
	var joined: Array = []
	for rid in [RegionCatalog.NARU_VILLAGE, RegionCatalog.SAMDOCHEON, RegionCatalog.HWANGCHEONHAE]:
		m._region = rid
		if m._has_split_pass() and not m._split_prop_entries().is_empty():
			joined.append(rid)
	_check("⑬e 마을·삼도천·황천해 셋이 합류했다 — 술어가 참이고 그 구역의 split 원장도 비어 있지 않다(%s)"
			% str(joined), joined.size() == 3)

	m._region = RegionCatalog.NARU_VILLAGE
	var village: Array = m._split_prop_entries()
	_check("⑬f 마을에서 fade가 **마을 프롭**을 잰다 — 옛 코드는 구역 불문 안식 배열을 봤다",
		m._fade_prop_entries() == village
		and village == m._prop_layouts.get("VILLAGE_OUTDOOR", [])
		and village != home_entries)
	var has_fade_tree := false
	for e in village:
		if e[0] in m.FADE_PROPS and e[0] in m.SPLIT_PROPS:
			has_fade_tree = true
	_check("⑬g-pre 무대: 마을 원장에 **Y-split ∩ fade 대상**(벚꽃 나무)이 실재한다 — 게이트가 잴 것이 있다",
		has_fade_tree)

	m._region = RegionCatalog.EOPHWA_MINE
	_check("⑬h 앞 패스가 없는 구역은 술어도 거짓이고 원장도 빈 배열이다(갱도)",
		not m._has_split_pass() and m._split_prop_entries().is_empty())
	m._region = prev_region


# ── ⑭ #14 더비 태그 교환이 좌판 그림을 갱신한다 ──────────────────────────────
# 좌판 위 금빛 점은 `tags_on(day)` 파생인데 `SeasonalEvent`엔 `changed`가 없어 자동 훅에 안 실리고,
# [F]를 누르는 동안 `_target`이 고정이라 `_update_target`의 무효화도 안 걸렸다.
func _check_derby_redraw(m: Node) -> void:
	print("── ⑭ #14 더비 부스 금빛 점 무효화 ──")
	_check("⑭a-pre 무대: `SeasonalEvent`엔 `changed` 시그널이 없다(자동 훅에 못 실리는 근거)",
		not m.seasonal_event.has_signal("changed"))
	m.seasonal_event.derby_day = m.clock.day
	m.seasonal_event.derby_tags = 1
	m.seasonal_event.derby_exchanges = 0
	_check("⑭b-pre 무대: 오늘 금빛 태그를 1개 들고 있다(좌판 위 점이 켜져 있는 상태)",
		m.seasonal_event.tags_on(m.clock.day) == 1)
	m._try_derby_exchange()
	_check("⑭c 교환이 원장을 실제로 줄였다(그림이 가리키는 값이 갈렸다)",
		m.seasonal_event.tags_on(m.clock.day) == 0
		and _last_notice(m).contains("금빛 태그 교환"))
	_check("⑭d 그 자리가 직접 재드로우를 건다 — 시그널 없는 원장은 갱신이 이 자리 몫이다(R10 `_fill_pet_bowl`)",
		_in_func("func _try_derby_exchange", "queue_redraw()"))


# ── ⑮ #15 F10 배치 모드가 두 캔버스를 함께 무효화한다 ────────────────────────
# 프롭 배열은 앞 패스도 소비하는데 편집 경로가 main만 갱신해서, 플레이어 발치보다 남쪽에 놓은
# 프롭은 화면에 안 나타나고 지운 프롭은 플레이어 위에 남았다(배치 모드는 이동이 멎어 행 넘김
# 재분할도 안 탄다).
func _check_edit_invalidate(m: Node) -> void:
	print("── ⑮ #15 배치 모드 앞 패스 무효화 ──")
	_check("⑮a-pre 무대: `_redraw_world()`가 실제로 두 캔버스를 무효화한다(main + `_front_props`)",
		_in_func("func _redraw_world", "queue_redraw()")
		and _in_func("func _redraw_world", "_front_props.queue_redraw()"))
	_check("⑮b 배치 모드 입력 갈래(놓기·드래그·삭제·팔레트)가 전부 `_redraw_world()`다 — main 전용 갱신 0건",
		_count_in_func("func _unhandled_input", "_redraw_world()") == 3
		and _count_in_func("func _unhandled_input", "queue_redraw()") == 0)
	_check("⑮c 삭제도 같은 자리를 쓴다", _in_func("func _edit_delete", "_redraw_world()"))
	_check("⑮d-pre 무대: 편집이 고치는 배열은 앞 패스가 소비하는 그 원장이다(안식 = 'HOME' 키)",
		m._edit_key() == "HOME" and m._prop_layouts.has(m._edit_key()))


# ── ⑯ #16 에필로그를 닫아도 취침의 잠금은 취침이 쥔다 ────────────────────────
# 『정지 주인 ≠ 재개 주인』의 남은 닫는 자리. B7 마지막 묶음이 24:00 강제 취침 트윈 한가운데서
# 닫히면 다음 프레임의 [E]가 `_close_epilogue`를 띄우고, 그것이 취침의 시계 정지와 이동 잠금을
# 무조건 풀어 **암전 뒤에서 플레이어가 걸어 다녔다**.
func _check_epilogue_sleep(m: Node) -> void:
	print("── ⑯ #16 `_close_epilogue`의 취침 가드 ──")
	_check("⑯a-pre 무대: 형제 두 자리는 R12가 이미 `_sleeping`을 본다(같은 계열의 앞선 처방)",
		_in_func("func _on_dialogue_finished", "player.set_physics_process(not _sleeping)")
		and _in_func("func _close_spine_scene", "_sleeping"))

	# ㉠ 취침 트윈 한가운데서 닫는 갈래 — 두 잠금의 주인은 취침이다.
	m._sleeping = true
	m._epilogue_open = true
	m._epilogue_clock_prev = true
	m.clock.running = false
	m.player.set_physics_process(false)
	m._close_epilogue()
	_check("⑯b-pre 무대: 에필로그가 실제로 닫혔다(가드가 early return으로 도망친 게 아니다)",
		not m._epilogue_open)
	_check("⑯c 취침 중이면 시계도 이동도 안 건드린다 — 암전 뒤에서 걸어 다니지 않는다",
		not m.clock.running and not m.player.is_physics_processing())

	# ㉡ 평시 갈래 — 정정이 정상 경로를 안 깨뜨렸다.
	m._sleeping = false
	m._epilogue_open = true
	m._epilogue_clock_prev = true
	m.clock.running = false
	m.player.set_physics_process(false)
	m._close_epilogue()
	_check("⑯d 취침이 아니면 종전대로 스냅한 값으로 되돌린다(시계 재개 · 이동 해제)",
		m.clock.running and m.player.is_physics_processing())


# ── ⑰ #17·#18 값이 매겨진 자재에 판매 창구가 생겼다 ─────────────────────────
# 삭은 그물(게잡이통 밤 산출의 25% · 통 EV 계산이 그 5냥을 수입으로 산입)과 잡귀 부산물 2종
# (카탈로그가 "지금은 소지·판매까지가 실효 범위"라 선언)에 냥으로 바꾸는 창구가 한 곳도 없었다.
# R8(중복 유품)·R9(결정기 부품)과 같은 클래스라 답도 같다 — 출하함으로 판다.
func _check_shippable_materials(m: Node) -> void:
	print("── ⑰ #17·#18 값이 매겨진 자재의 판매 창구 ──")
	var ids: Array = ItemCatalog.SHIPPABLE_MATERIALS.keys()
	var priced := true
	var rejected_before := true
	for id in ids:
		var sid := String(id)
		if ItemCatalog.price_of(sid) <= 0:
			priced = false
		# 종전 네 갈래가 전부 거절했는가(다섯째 갈래가 필요했던 근거).
		if ItemCatalog.category_of(sid) == ItemCatalog.CAT_HARVEST or Codex.is_tracked(sid) \
				or ItemCatalog._is_relic(sid) or ItemCatalog._is_mine_device(sid):
			rejected_before = false
	_check("⑰a-pre 무대: 표에 실린 %d종이 전부 값이 매겨져 있다(카탈로그가 '팔린다'고 선언한 물건)"
			% ids.size(), not ids.is_empty() and priced)
	_check("⑰b-pre 무대: 종전 네 갈래(수확물·도감 추적·중복 유품·결정기)는 그 전부를 거절한다",
		rejected_before)
	_check("⑰c 자재군 전체를 연 것이 아니다 — 제작·건축이 삼키는 자재와 카페 소재는 여전히 거절",
		not ItemCatalog.is_shippable_material(ItemCatalog.WOOD)
		and not ItemCatalog.is_shippable_material(ItemCatalog.JEOSEUNG_IKKI)
		and not ItemCatalog.is_shippable_material(ItemCatalog.NARAK_HONJEONG))
	_check("⑰d-pre 무대: 삭은 그물은 게잡이통 밤 산출 표에 실려 있다(창구가 필요한 이유)",
		str(CrabPotLedger.catch_table()).contains(ItemCatalog.ROTTEN_NET))

	# 실제 창구 — 백팩에 넣고 출하함에 투입해 본다.
	m.ship_bin.load_save({})
	m.inventory.load_save({})
	var accepted: Array = []
	for id in ids:
		var sid := String(id)
		if not m.inventory.add_item(sid, 1, ItemCatalog.Q_NORMAL):
			continue
		m._on_frame_deposit(m.inventory._find_id(sid))
		if m.ship_bin.count_of(sid) == 1:
			accepted.append(sid)
	_check("⑰e 셋 다 출하함이 받는다(%s)" % str(accepted), accepted.size() == ids.size())
	var expect := 0
	for id in ids:
		expect += ItemCatalog.price_of(String(id))
	_check("⑰f 정산 예상액이 카탈로그 값의 합과 같다(%d냥 — 새 눈금 0)" % expect,
		m.ship_bin.preview_gold() == expect)
	m.ship_bin.load_save({})
	m.inventory.load_save({})
