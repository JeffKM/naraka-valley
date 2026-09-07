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

# 세이브 슬롯 청소 — 이 스위트는 `_save_game`/`_load_game` 왕복을 태우므로(⑧·⑩·⑬) 앞선 실행이
# 남긴 파일이 부팅 자동 복원으로 되살아나면 **다른 절의 무대가 통째로 갈린다**(개간·백팩·원장).
func _wipe_slot(slot: int) -> void:
	var p := SaveManager.slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _initialize() -> void:
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)
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
	print("══ 폴리시 R29 회귀 — 배치 B(#12~#23 + 인계 #24) ══")
	_check_anchor_romance_slot(m)     # ⑧ #21
	_check_overlay_table(m)           # ⑨ #15·#16
	_check_load_confirm(m)            # ⑩ #17
	_check_carry_order()              # ⑪ #18
	_check_seed_ranch_guard(m)        # ⑫ #19
	_check_seed_mature_snapshot(m)    # ⑬ #20
	_check_material_sinks(m)          # ⑭ #13·#14
	_check_rarecrow_progress(m)       # ⑮ #23
	await _check_spine_b4_bit(m)      # ⑯ #22
	_check_soul_body_witness()        # ⑰ #24
	_check_base_menu_reach()          # ⑱ #12(OWNER — 근거 고정)
	print("── 결과: %s (실패 %d) ──" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(0 if _fail == 0 else 1)

# ── ⑧ #21 앵커 연애 슬롯 ↔ 세이브 왕복 ──────────────────────────────────────
func _check_anchor_romance_slot(m: Node) -> void:
	print("⑧ #21 앵커 청혼이 재기동을 넘는다")
	_check("⑧a 배선: 로드 검증이 **슬롯 자격 술어**를 묻는다(로스터 직행 0)",
		_count_in(_src, "func _load_game", "not _romance_slot_valid(_romance_partner)") == 1
			and _count_in(_src, "func _romance_slot_valid", "rid == OKJA_RID") == 1)
	_check("⑧b 계약: 앵커는 고백 명단(ROMANCE_OPEN) **밖**인데 슬롯 자격은 있다 · 유령은 여전히 거절",
		not m.ROMANCE_OPEN.has(m.OKJA_RID) and m._romance_slot_valid(m.OKJA_RID)
			and m._romance_slot_valid("miho") and not m._romance_slot_valid("__ghost__"))
	# 라이브 왕복 — 청혼이 세운 그 두 값이 저장·복원을 넘어 살아남는가.
	var keep_partner: String = m._romance_partner
	var keep_spouse: String = m._spouse_id
	m._romance_partner = m.OKJA_RID
	m._spouse_id = m.OKJA_RID
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	_check("⑧c 세이브가 앵커를 적는다(romance_partner=%s · spouse=%s)"
			% [str(raw.get("romance_partner", "")), str(raw.get("spouse_id", ""))],
		String(raw.get("romance_partner", "")) == m.OKJA_RID)
	m._romance_partner = ""
	m._spouse_id = ""
	var ok: bool = m._load_game()
	_check("⑧d 로드가 앵커 슬롯·혼인을 **지우지 않는다**(슬롯 「%s」 · 배우자 「%s」)"
			% [m._romance_partner, m._spouse_id],
		ok and m._romance_partner == m.OKJA_RID and m._spouse_id == m.OKJA_RID)
	# 대조군 — R27 #8이 세운 방어는 그대로 산다(로스터·앵커 어느 쪽도 아닌 id는 버려진다).
	m._romance_partner = "__ghost__"
	m._spouse_id = "__ghost__"
	m._save_game()
	m._load_game()
	_check("⑧e 대조군: 로스터 밖 유령 id는 여전히 버려진다(슬롯 「%s」 · 배우자 「%s」)"
			% [m._romance_partner, m._spouse_id],
		m._romance_partner == "" and m._spouse_id == "")
	m._romance_partner = keep_partner
	m._spouse_id = keep_spouse
	m._save_game()

# ── ⑨ #15·#16 화면을 덮은 판 위의 클릭 ──────────────────────────────────────
func _check_overlay_table(m: Node) -> void:
	print("⑨ #15·#16 오버레이 표 ↔ 판 위 클릭")
	_check("⑨a 배선: 표가 형제 판 둘과 시계 판을 함께 든다(거울 하나만 보던 자리)",
		_count_in(_src, "func _pointer_over_overlay", "cafe_summary_panel, milestone_panel") == 1
			and _count_in(_src, "func _pointer_over_overlay", "clock_hud.hit_test(screen_pos)") == 1)
	m.mirror_panel.visible = false
	m.cafe_summary_panel.visible = false
	m.milestone_panel.visible = false
	var sc: float = 1.0
	var par = m.cafe_summary_panel.get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		sc = par.scale.x
	var mid: Vector2 = (m.cafe_summary_panel.position
		+ m.cafe_summary_panel.size * 0.5) * sc
	_check("⑨b 대조군: 판이 안 떠 있으면 그 좌표는 오버레이가 아니다(월드가 그대로 논다)",
		not m._pointer_over_overlay(mid))
	m.cafe_summary_panel.visible = true
	_check("⑨c 마감 정산 판이 뜨면 그 판 위 클릭이 월드로 안 샌다 %s" % str(mid),
		m._pointer_over_overlay(mid))
	var outside: Vector2 = Vector2(m.cafe_summary_panel.position.x - 24.0,
		m.cafe_summary_panel.position.y - 24.0) * sc
	_check("⑨d 판 **바깥**은 그대로 논다(막는 범위가 그려진 판 한정) %s" % str(outside),
		not m._pointer_over_overlay(outside))
	m.cafe_summary_panel.visible = false
	m.milestone_panel.visible = true
	var mid2: Vector2 = (m.milestone_panel.position + m.milestone_panel.size * 0.5) * sc
	_check("⑨e 마일스톤 판도 같다(그 판은 `_hud_hidden`이라 시계 가드까지 함께 죽던 자리)",
		m._pointer_over_overlay(mid2))
	m.milestone_panel.visible = false
	# #16 — 시계 판 위. LMB는 위 가드가 달력으로 잡고, RMB는 여기서 막힌다.
	if m.clock_hud != null:
		m.clock_hud.visible = true
		var probe: Vector2 = _clock_probe(m)
		_check("⑨f 무대: 시계 판 위 좌표를 잡았다 %s(hit_test 참)" % str(probe),
			probe.x >= 0.0 and m.clock_hud.hit_test(probe))
		_check("⑨g 시계 판 위 **RMB**도 월드로 안 샌다(LMB만 보던 가드의 그 반쪽)",
			probe.x >= 0.0 and m._pointer_over_overlay(probe))

# 시계 판 안쪽 한 점을 찾는다(판 기하를 옮겨 적지 않고 hit_test로 판다).
func _clock_probe(m: Node) -> Vector2:
	var view: Vector2 = Vector2(m.get_viewport().get_visible_rect().size)
	var y := 4.0
	while y < view.y:
		var x := view.x - 4.0
		while x > view.x - 260.0 and x > 0.0:
			var p := Vector2(x, y)
			if m.clock_hud.hit_test(p):
				return p
			x -= 4.0
		y += 4.0
	return Vector2(-1.0, -1.0)

# ── ⑩ #17 F9 불러오기 ↔ 2단 확인(F8 형제 관례) ──────────────────────────────
func _check_load_confirm(m: Node) -> void:
	print("⑩ #17 [F9] 불러오기 ↔ 되돌릴 수 없는 키의 확인 절차")
	_check("⑩a 배선: 폴링이 래치 창구를 부르고, 래치가 F8과 **같은 상수·같은 자리**에서 준다",
		_count_in(_src, "func _process", "_arm_or_confirm_load()") == 1
			and _count_in(_src, "func _arm_or_confirm_load", "_load_armed_secs = DELETE_CONFIRM_SECS") == 1
			and _count_in(_src, "func _process", "_load_armed_secs -= delta") == 1)
	m._load_armed_secs = 0.0
	_clear_notices(m)
	var gold_before: int = m.wallet.gold
	m.wallet.earn(777)
	m._arm_or_confirm_load()
	_check("⑩b 첫 [F9]는 **무장만** 한다 — 세계가 안 되감긴다(지갑 %d 그대로 · 래치 %.1fs)"
			% [m.wallet.gold, m._load_armed_secs],
		m.wallet.gold == gold_before + 777 and m._load_armed_secs > 0.0)
	var told := ""
	for t in _feed_texts(m):
		if String(t).contains("[F9]"):
			told = String(t)
	_check("⑩c 그 프레임이 **키와 잃는 것을 말한다** — 「%s」" % told,
		told.contains("[F9]") and told.contains("사라진다"))
	m._arm_or_confirm_load()
	_check("⑩d 무장 중 두 번째 [F9]가 실제로 되감는다(지갑 %d · 래치 %.1fs)"
			% [m.wallet.gold, m._load_armed_secs],
		m.wallet.gold == gold_before and m._load_armed_secs == 0.0)

func _feed_texts(m: Node) -> Array:
	var out: Array = []
	if m.notice_feed != null:
		for it in m.notice_feed._items:
			out.append(String(it["text"]))
	return out

func _clear_notices(m: Node) -> void:
	if m.notice_feed != null:
		m.notice_feed._items.clear()

# ── ⑪ #18 이월 소비 순서 ↔ 아침 정산의 상대 순서 ────────────────────────────
func _check_carry_order() -> void:
	print("⑪ #18 밀린 방출은 절기 재스폰 **뒤**에 선다")
	var morning_respawn := _line_of(_src, "_run_season_boundary(day)")
	var morning_release := _line_of(_src, "_pasture_release_pending = not _release_open_buildings(day)")
	_check("⑪a 계약: 아침 정산은 «재스폰(%d행) → 방출(%d행)» 순이다"
			% [morning_respawn + 1, morning_release + 1],
		morning_respawn > 0 and morning_release > morning_respawn)
	# ★[폴리시 R30 #1] **방출이 밤 목록 안으로 들어갔다** — 목록 뒤에 두면 파종·재점령보다도 뒤라
	#   이번엔 파종↔방출이 아침 정산과 정반대가 됐기 때문이다(그 자리 주석에 경위). 그래서
	#   `_process`의 호출부가 둘이 됐고, **집행 자체는** `_try_pending_pasture_release` 한 창구로
	#   접혔으며 두 호출부는 `pasture_tried` 하나로 «한 프레임 한 번»을 지킨다. 여기서 재는 계약은
	#   한 글자도 안 바뀐다: ㉠ 이월 방출은 절기 재스폰보다 **뒤**다 ㉡ 창구가 늘지 않았다.
	var carry_loop := _line_of(_src, "_run_season_boundary(night)")
	var carry_release := _line_of(_src, "pasture_tried = _try_pending_pasture_release()")
	_check("⑪b 이월 경로도 **같은 상대 순서**다(밤 목록 %d행 → 방출 %d행) — 종전엔 정반대였다"
			% [carry_loop + 1, carry_release + 1],
		carry_loop > 0 and carry_release > carry_loop)
	_check("⑪c 방출 **집행**은 여전히 한 자리뿐이다(자리를 옮겼지 창구가 늘지 않았다)",
		_count_in(_src, "func _try_pending_pasture_release",
			"if _release_open_buildings(clock.day if clock != null else 0):") == 1
		and _count_in(_src, "func _process", "_release_open_buildings(clock.day") == 0
		and _count_in(_src, "func _process", "_try_pending_pasture_release()") == 2
		and _count_in(_src, "func _process", "if not pasture_tried:") == 1)

# ── ⑫ #19 자체 파종 성역 ↔ 짐승 ─────────────────────────────────────────────
func _check_seed_ranch_guard(m: Node) -> void:
	print("⑫ #19 짐승이 선 칸에는 유목이 안 돋는다")
	_check("⑫a 배선: 파종 성역이 짐승 술어를 문다(반대 방향 R25 #6과 짝)",
		_count_in(_src, "func _is_tree_seed_free", "ranch.has_animal_at(t)") == 1)
	m._indoor = ""
	m._region = RegionCatalog.HOME
	var occ: Dictionary = m._home_occupied_tiles()
	# 파종 자격이 있는 빈 칸을 하나 찾는다(그 칸이 짐승 하나로 성역이 되는지가 요점).
	var free_t := Vector2i(-1, -1)
	for y in range(m.PASTURE_SCAN_RECT.position.y, m.PASTURE_SCAN_RECT.end.y):
		for x in range(m.PASTURE_SCAN_RECT.position.x, m.PASTURE_SCAN_RECT.end.x):
			var t := Vector2i(x, y)
			if m._is_tree_seed_free(RegionCatalog.HOME, t, occ):
				free_t = t
				break
		if free_t.x >= 0:
			break
	_check("⑫b 무대: 지금 파종 가능한 방목 평면 칸 %s를 잡았다" % str(free_t), free_t.x >= 0)
	if free_t.x < 0:
		return
	var anchor := Vector2i(-1, -1)
	for tile in m.ranch._animals.keys():
		anchor = tile
		break
	if anchor.x < 0:
		_check("⑫c 무대: 짐승이 없다", false)
		return
	var keep: Dictionary = (m.ranch._animals[anchor] as Dictionary).duplicate(true)
	m.ranch.send_to_pasture(anchor, free_t)
	_check("⑫c 짐승을 그 칸에 세우면 **성역이 된다**(종전엔 발밑에 stage1이 돋았다)",
		m.ranch.has_animal_at(free_t)
			and not m._is_tree_seed_free(RegionCatalog.HOME, free_t, occ))
	m.ranch._animals[anchor] = keep
	_check("⑫d 원복하면 다시 파종 가능하다(가드가 짐승 한 항만 더한 것이 맞다)",
		m._is_tree_seed_free(RegionCatalog.HOME, free_t, occ))

# ── ⑬ #20 이월 파종 자격 ↔ 그 밤에 굳은 스냅샷 ──────────────────────────────
func _check_seed_mature_snapshot(m: Node) -> void:
	print("⑬ #20 밀린 밤의 파종 자격은 그 밤에 굳는다")
	_check("⑬a 배선: 큐 자리에서 굳히고, 소비가 그 목록을 그대로 넘긴다",
		_count_in(_src, "func _on_day_advanced", "_tree_seed_pending_mature[day] = tree_ledger.mature_tiles(") == 1
			and _count_in(_src, "func _process", "tree_ledger.catch_up_seeding(night, _tree_seed_free_cb(), mature)") == 1)
	# 순수 원장 — 그 밤에 미성숙이던 나무는 나중에 자라도 그 밤 몫을 안 굴린다.
	var led := TreeLedger.new()
	var home := RegionCatalog.HOME
	var young := Vector2i(3, 24)
	led._put(home, young, {"species": "pine", "stage": 1, "hp": 1, "stump": false, "moss": false})
	var free_cb := func(_r: String, _t: Vector2i) -> bool: return true
	var seeded_live := 0
	var seeded_snap := 0
	# 밤 N의 스냅샷 = 성숙목 0(그때는 아직 어렸다).
	var snap: Array = led.mature_tiles(home)
	_check("⑬b 무대: 밤 N의 자격 목록이 비어 있다(그 밤엔 아직 미성숙 — %d칸)" % snap.size(),
		snap.is_empty())
	# 그 뒤 자라 성숙목이 됐다.
	led._put(home, young, {"species": "pine", "stage": TreeLedger.MAX_STAGE,
		"hp": 9, "stump": false, "moss": false})
	_check("⑬c 무대: 지금은 성숙목이다(라이브 자격 %d칸)" % led.mature_tiles(home).size(),
		led.is_mature(home, young))
	for d in range(1, 60):
		seeded_live += led.catch_up_seeding(d, free_cb).size()
		if seeded_live > 0:
			break
	_check("⑬d 대조군: 스냅샷 없이 부르면(=종전) 지금 성숙한 나무가 지난 밤 몫을 굴린다(%d회)"
			% seeded_live, seeded_live > 0)
	var led2 := TreeLedger.new()
	led2._put(home, young, {"species": "pine", "stage": TreeLedger.MAX_STAGE,
		"hp": 9, "stump": false, "moss": false})
	for d in range(1, 60):
		seeded_snap += led2.catch_up_seeding(d, free_cb, []).size()
	_check("⑬e 그 밤의 자격 목록(빈 배열)을 주면 **한 번도 안 굴린다**(%d회) — 집에서 잔 세계와 같다"
			% seeded_snap, seeded_snap == 0)
	# 세이브 왕복 — 스냅샷이 표와 함께 돌아오고, 표 밖 밤은 유령으로 안 남는다.
	var keep_days: Array = m._tree_seed_pending_days.duplicate()
	var keep_snap: Dictionary = m._tree_seed_pending_mature.duplicate(true)
	m._tree_seed_pending_days = [41, 42]
	m._tree_seed_pending_mature = {41: [Vector2i(3, 24)], 42: []}
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	var raw_snap: Dictionary = raw.get("tree_seed_pending_mature", {})
	_check("⑬f 세이브가 밤별 자격 목록을 적는다(%d칸 · 41=%s)"
			% [raw_snap.size(), str(raw_snap.get(41, []))], raw_snap.size() == 2)
	m._tree_seed_pending_mature = {}
	m._load_game()
	_check("⑬g 로드가 되살린다(41=%s · 42=%s)"
			% [str(m._tree_seed_pending_mature.get(41, "없음")),
				str(m._tree_seed_pending_mature.get(42, "없음"))],
		m._tree_seed_pending_mature.size() == 2
			and (m._tree_seed_pending_mature[41] as Array).has(Vector2i(3, 24)))
	_check("⑬h 하위호환: 키 없는 구세이브는 빈 표(라이브 판정으로 떨어진다) · 표 밖 밤은 안 싣는다",
		m._tree_seed_mature_from({}).is_empty()
			and m._tree_seed_mature_from({"tree_seed_pending_mature": {99: [[1, 1]]}}).is_empty())
	m._tree_seed_pending_days = keep_days
	m._tree_seed_pending_mature = keep_snap
	m._save_game()

# ── ⑭ #13·#14 값은 매겨졌는데 받는 창구가 0인 자재 ───────────────────────────
func _check_material_sinks(m: Node) -> void:
	print("⑭ #13·#14 자재 sink 전수(레지스트리 파생 — 목록 옮겨 적기 0)")
	var craft: Dictionary = {}
	var cat: Dictionary = CraftCatalog.catalog()
	for rid in cat:
		for mm in cat[rid].get("mats", []):
			craft[String(mm["item"])] = true
	var quest: Dictionary = {}
	for q in QuestBoard.item_pool():
		quest[String(q)] = true
	var trial: Dictionary = {}
	for t in TrialGround.deliver_pool():
		trial[String(t)] = true
	var sig: Dictionary = {}
	for mid in MenuCatalog.fusion_ids():
		sig[String(MenuCatalog.signature_of(String(mid)))] = true
	var orphans: Array = []
	var opened: Array = []
	for id in ItemCatalog.MATERIALS:
		var sid := String(id)
		if int(ItemCatalog.MATERIALS[id].get("price", 0)) <= 0:
			continue
		if craft.has(sid) or quest.has(sid) or trial.has(sid) or sig.has(sid) \
				or Codex.is_tracked(sid) or ItemCatalog.category_of(sid) == ItemCatalog.CAT_HARVEST:
			continue
		if ItemCatalog.is_shippable_material(sid):
			opened.append(sid)
			continue
		orphans.append(sid)
	_check("⑭a 무대: 다른 sink가 하나도 없어 출하 표가 유일 창구인 자재 %d종을 파생했다(%s)"
			% [opened.size(), ", ".join(opened)], opened.size() >= 8)
	_check("⑭b 값이 매겨졌는데 **받는 창구가 0**인 자재가 하나도 없다(고아: %s)"
			% ("없음" if orphans.is_empty() else ", ".join(orphans)), orphans.is_empty())
	# #14 — 벌목꾼(비가역 2단 선택)의 유일한 산출물이 그 표에 들었는가.
	var payload := ""
	for p in ProfessionCatalog.tier_profs(ProfessionCatalog.FORAGING, 10):
		for perk in ProfessionCatalog.perks_of(ProfessionCatalog.FORAGING, String(p["id"])):
			if String(perk.get("dim", "")) == ProfessionCatalog.DIM_HARDWOOD:
				payload = ItemCatalog.HARDWOOD
	_check("⑭c #14: 벌목꾼 퍼크의 산출물 «%s»이 처분 창구를 얻었다(형제 후보와의 비대칭 해소)"
			% ItemCatalog.name_of(payload),
		payload != "" and ItemCatalog.is_shippable_material(payload))
	# 라이브 — 출하 술어가 실제로 그 여덟을 받는다(값이 붙는다). 대조군은 여전히 거절되는 자재다.
	var took: Array = []
	for sid in opened:
		m.inventory.add_item(String(sid), 1)
		var slot: int = m.inventory._find_id(String(sid))
		if slot < 0:
			continue
		m._on_frame_deposit(slot)
		if m.inventory.count_of(String(sid)) == 0:
			took.append(String(sid))
	_check("⑭d 라이브: 출하함이 그 %d종을 **전부** 받는다(휴지통이 유일 처분이던 자리 — %s)"
			% [took.size(), ", ".join(took)], took.size() == opened.size())
	m.inventory.add_item(ItemCatalog.WOOD, 1)
	var wslot: int = m.inventory._find_id(ItemCatalog.WOOD)
	m._on_frame_deposit(wslot)
	_check("⑭e 대조군: 표 밖 자재(원목 — 제작이 삼킨다)는 **여전히 거절**된다(자재군 전체가 안 열렸다)",
		m.inventory.count_of(ItemCatalog.WOOD) > 0)
	m.inventory.remove_item(ItemCatalog.WOOD, 99)

# ── ⑮ #23 레어크로우 진행·완주 ──────────────────────────────────────────────
func _check_rarecrow_progress(m: Node) -> void:
	print("⑮ #23 레어크로우 8종 ↔ 진행 꼬리·완주 발화")
	_check("⑮a 배선: 남은 세 창구가 **한 꼬리 함수**를 쓰고, 완주가 발화 창구를 얻었다",
		_count_in(_src, "func _try_buy_peddler_rare", "_rarecrow_tail(id)") == 1
			and _count_in(_src, "func _try_buy_trial_item", "_rarecrow_tail(buy_id)") == 1
			and _count_in(_src, "func _grant_letter_attachment", "_rarecrow_tail(iid)") == 1
			and _count_in(_src, "func _on_item_gained", "_maybe_notice_rarecrow_complete()") == 1)
	var some := String(ItemCatalog.RARECROWS[0])
	_check("⑮b 꼬리는 레어크로우에만 붙는다(«%s» → 「%s」 · 원목 → 「%s」)"
			% [some, m._rarecrow_tail(some), m._rarecrow_tail(ItemCatalog.WOOD)],
		m._rarecrow_tail(some).contains("/%d" % ItemCatalog.RARECROWS.size())
			and m._rarecrow_tail(ItemCatalog.WOOD) == "")
	# 라이브 — 여덟째가 들어오는 프레임에만 완주가 발화한다.
	m._rarecrow_complete_told = false
	# 백팩을 비운다 — 16칸이라 채워진 채로는 여덟 종이 다 안 들어가 «완주» 자체가 무대에 안 선다.
	var stash: Array = []
	for i in Inventory.SIZE:
		var iid: String = m.inventory.id_at(i)
		if iid != "":
			stash.append([iid, m.inventory.count_at(i), m.inventory.quality_at(i)])
			m.inventory.remove_at(i, m.inventory.count_at(i))
	_clear_notices(m)
	var last := String(ItemCatalog.RARECROWS[ItemCatalog.RARECROWS.size() - 1])
	for id in ItemCatalog.RARECROWS:
		if String(id) != last:
			m.inventory.add_item(String(id), 1)
	var mid_told := false
	for t in _feed_texts(m):
		if String(t).contains("모두 모았다"):
			mid_told = true
	_check("⑮c 일곱 종까지는 완주를 말하지 않는다(수집 %d/%d · 발화 %s)"
			% [m._rarecrow_collected(), ItemCatalog.RARECROWS.size(), str(mid_told)],
		not m._rarecrow_complete() and not mid_told)
	_clear_notices(m)
	m.inventory.add_item(last, 1)
	var done_line := ""
	for t in _feed_texts(m):
		if String(t).contains("모두 모았다"):
			done_line = String(t)
	_check("⑮d 여덟째가 들어오는 프레임이 **완주와 그 효과**를 말한다 — 「%s」" % done_line,
		m._rarecrow_complete() and done_line.contains("%d칸" % m._scarecrow_radius()))
	for id in ItemCatalog.RARECROWS:
		m.inventory.remove_item(String(id), 99)
	for e2 in stash:
		m.inventory.add_item(String(e2[0]), int(e2[1]), int(e2[2]))

# ── ⑯ #22 B4 비트 ↔ 장면이 닫히는 자리 ──────────────────────────────────────
func _check_spine_b4_bit(m: Node) -> void:
	print("⑯ #22 B4 비트는 재생이 아니라 **종료**에 찍힌다")
	_check("⑯a 배선: 발동은 예약만 하고, 두 종료 경로가 한 창구를 부른다",
		_count_in(_src, "func _fire_spine_b4", "_spine_b4_pending = true") == 1
			and _count_in(_src, "func _fire_spine_b4", "_mark_spine_bit(SPINE_B4)") == 0
			and _count_in(_src, "func _on_dialogue_finished", "_settle_spine_b4()") == 1
			and _count_in(_src, "func _end_cutscene", "_settle_spine_b4()") == 1)
	var keep_bits: int = m._spine_bits
	m._spine_bits = 0
	m._spine_b4_pending = false
	m._spine_b4_armed = true
	m._run_over = false
	m.cutscene = null
	_dismiss_dialogue(m)
	m._fire_spine_b4()
	await process_frame
	_check("⑯b 재생이 시작된 프레임엔 비트가 **아직 없다**(예약 %s · 비트 %s)"
			% [str(m._spine_b4_pending), str(m._spine_bit_seen(m.SPINE_B4))],
		m._spine_b4_pending and not m._spine_bit_seen(m.SPINE_B4))
	# 여기서 앱이 닫히면 비트가 안 남는다 = 다음 아침이 그대로 다시 예약한다.
	m._spine_b4_armed = false
	m._arm_spine_b4()
	_check("⑯c 끊긴 재생은 **다음 아침에 다시 예약된다**(예약 %s)" % str(m._spine_b4_armed),
		m._spine_b4_armed == m._heart_bit_seen(m.SPINE_B4_TRIGGER_RID, m.SPINE_B4_TRIGGER_HEART))
	# 장면을 끝까지 닫으면 그때 찍힌다.
	m._settle_spine_b4()
	_check("⑯d 장면이 닫히는 자리에서 비트가 선다(예약 %s · 비트 %s)"
			% [str(m._spine_b4_pending), str(m._spine_bit_seen(m.SPINE_B4))],
		not m._spine_b4_pending and m._spine_bit_seen(m.SPINE_B4))
	m.cutscene = null
	_dismiss_dialogue(m)
	# 형제 증인 둘도 새 계약을 문다(재는 것은 그대로 «정확히 1회 발동» — 기록 시점만 내려갔다).
	var frosty_src := _lines_of_file("res://playtest/frosty_arc_test.gd")
	var smoke_src := _lines_of_file("res://playtest/s9b_spine_smoke_test.gd")
	_check("⑯e 형제 증인(frosty_arc ⑫h2 · s9b_spine_smoke ⑤c2)이 **종료 프레임**을 잰다",
		_line_of(frosty_src, "⑫h2 ★장면이 끝난 프레임에 비트가 선다") > 0
			and _line_of(smoke_src, "⑤c2 ★지문이 다 닫힌 프레임에 비트가 선다") > 0)
	m._spine_bits = keep_bits
	m._spine_b4_pending = false
	m._spine_b4_armed = false

# ── ⑰ #24 동행 혼 증인 무대(배치 A 인계) ────────────────────────────────────
func _check_soul_body_witness() -> void:
	print("⑰ #24 polish_r8 ⑬ 무대 정정(구역 술어 도입 이후)")
	_check("⑰a 증인이 무대를 세운다(가시성 훅이 요구하는 구역을 그 절이 직접 세운다)",
		_line_of(_r8_src, "m._region = RegionCatalog.HOME") > 0
			and _line_of(_r8_src, "soul.visible_rule.is_valid()") > 0)
	_check("⑰b 프로덕션 계약은 그대로다 — 몸은 훅 파생이고, 소비는 암전 완료 프레임이다",
		_count_in(_src, "func _refresh_soul_child_body", "r.visible_rule.call()") == 1
			and _count_in(_src, "func _apply_cutscene_frame", "cutscene.fade_alpha() >= 1.0") == 1)

# ── ⑱ #12 OWNER-DECISION 근거 고정(코드 무수정) ─────────────────────────────
# 기본 4잔이 **정말로** 손에 안 들어온다는 사실을 술어로 못 박는다. owner가 어느 안을 고르든
# (획득 경로 신설 / 선물표 교체) 그 결정이 들어오는 순간 이 단언이 먼저 빨개져 알려 준다.
func _check_base_menu_reach() -> void:
	print("⑱ #12 기본 4잔 ↔ 선물표(OWNER — 사실 고정)")
	var unreachable: Array = []
	for mid in MenuCatalog.ids():
		var id := String(mid)
		if MenuCatalog.is_side_dish(id):
			continue
		if MenuCatalog.signature_of(id) == "":
			unreachable.append(id)
	_check("⑱a 사실: 시그니처도 곁들이도 아닌 메뉴 %d종은 인벤토리 획득 경로가 0이다(%s)"
			% [unreachable.size(), ", ".join(unreachable)], unreachable.size() == 4)
	var dead: Array = []
	for rid in GiftPrefs.OVERRIDES:
		var tbl: Dictionary = GiftPrefs.OVERRIDES[rid]
		for key in [GiftPrefs.LOVE, GiftPrefs.HATE]:
			for it in tbl.get(key, []):
				if unreachable.has(String(it)):
					dead.append("%s:%s" % [String(rid), String(it)])
	_check("⑱b 그 넷이 선호표에서 차지한 죽은 칸 %d개(%s) — owner 결재 대상"
			% [dead.size(), ", ".join(dead)], dead.size() == 6)

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
