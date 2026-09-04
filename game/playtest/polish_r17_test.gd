extends SceneTree
# ★[폴리시 17회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#7).
#
# 렌즈: R16 diff 리뷰(#0~#2) · 문자열 폭 스윕(#3~#7).
#
# 이 회차의 태도 둘.
#   ㉠ **폭·높이 단언은 그리기가 실제로 쓰는 식에서 판다.** 넘침을 잡는 회귀가 자기 상수로 판을
#      다시 그리면, 판이 움직인 날 초록인 채로 다시 샌다. 그래서 아래는 패널 기하를 `_panel_rect()`
#      ·`_inner_right()`에서, 글자 크기·Label 폭을 테마·노드에서 받아 온다(옮겨 적기 0).
#   ㉡ **최악 조합은 데이터에서 만든다.** "가장 긴 문구"를 손으로 고르면 표가 자라는 날 빗나가므로,
#      전 항목(전문직 30 · 절기 112일 · 도달 깊이 60층)을 훑어 최악을 뽑고 그것으로 잰다.
#
# 무엇을 보증하나(번호 = 17회차 헌트 발견 인덱스):
#   ① #0 `_resident_tile`이 좌표만 봐서, **다른 구역** 주민이 업화로·결정기 배치를 조용히 막았다.
#   ② #1 R16 #13이 기계 프롬프트를 올리면서 야시장·보부상·더비 부스와 새 역전을 만들었다.
#   ③ #2 제작 만재 알림이 가리킨 "아래 가방"이 제작 탭에는 그려지지 않는다(거짓 지시).
#   ④ #3 갱도 엘리베이터 프롬프트가 888px까지 자라 Label(624)·화면(640) 밖으로 양끝이 잘렸다.
#   ⑤ #4 저장 상자 안내(444px)가 가용 폭(324px)을 넘어 패널 밖 월드 위로 나갔다.
#   ⑥ #5 점괘 거울 본문이 접힌 뒤 16줄(304px)이라 Label(196px) 위아래로 한지 프레임을 넘었다.
#   ⑦ #6 전문직 선택 버튼 설명(곡예사 280px)이 버튼 판(260px)을 10px 넘어 그려졌다.
#   ⑧ #7 제작 탭 머리말(330px)이 나무 테두리 안쪽(312px) 밑으로 파고들었다.
#
# 판정: #0~#7 전부 CONFIRMED(봉합). 단 #2의 부수 주장 하나는 **REFUTED**다 — 헌트는
#   "`cycle_tab()`이 main에서 호출되지 않아 키로도 못 넘긴다"고 적었으나 실제로는 `menu_tab`
#   액션([E])이 `frame.cycle_tab()`을 부른다(main.gd `_process`). 그래서 봉합 문구는 탭이 없다고
#   말하는 대신 **있는 길을 정확히** 가리킨다("[E] 가방 탭에서"). ③c가 그 사실을 잠근다.
#
# 봉합 축(근거는 커밋 본문):
#   · #0 = 구역 술어를 `_resident_on_stage` 한 곳으로 뽑아 `_facing_resident`와 **같은 답**을 쓴다
#          (가드가 막는 칸 ⊇ 남이 [F]를 가져가는 칸이 성립해야 프롬프트↔동작이 안 갈린다).
#   · #1 = 배치 가드(`_f_booth_tile` — `_f_window_tile`의 형제) + 프롬프트 양보(구세이브 탈출구).
#          순서를 통째로 되돌리지 않고 두 갈래에만 양보 절을 달아, 바뀌는 우선순위를 기계↔부스
#          한 쌍으로 가둔다(주민 [F]가 `not _f_machine_at`으로 양보하는 그 문법의 반대 방향).
#   · #3 = 목록이 폭을 넘으면 **범위 표기로 접는다**(생략이 아니다 — 후보가 1 + STEP 배수라
#          목록 전체가 세 값에서 파생되므로 접힌 형태도 무손실이다).
#   · #5 = 판을 본문에 맞춰 세운다(고정 기하 → 내용 파생). 줄을 접거나 글자를 줄이는 반대 축은
#          둘 다 정보를 잃는다. 덤으로 예고가 없는 날은 판이 옛 고정 높이보다 작아진다.
#   · #4·#7 = `draw_text_fit`으로 갈고(가변 길이 한 줄의 기본 그리기) 문구를 형제 골격에 맞춘다.
#   · #6 = 버튼 안쪽 폭을 인자로 물린다(바로 위 "전문직:" 줄이 이미 쓰던 관례) + 유일한 초과 문구 축약.
#
# 하중 검증(계약을 일부러 깨고 빨개지는지 본 뒤 원복):
#   #0 `_resident_tile`의 `and _resident_on_stage(r)` 삭제 → ①a·①c red ·
#   #1 `_can_place_furnace`의 `_f_booth_tile` 배제 삭제 → ②a red · 프롬프트 양보 절 둘 삭제 → ②d red ·
#   #2 문구를 "아래 가방에서"로 되돌림 → ③a red ·
#   #3 `_mine_entry_prompt`의 접힘 갈래를 지우고 full만 반환 → ④a·④c·④d red ·
#   #4 옛 안내 문자열 복귀 → ⑤a·⑤b red ·
#   #5 `_open_mirror`의 `_layout_mirror_panel()` 호출 삭제 → ⑥a red(112일 중 112일 초과) ·
#   #6 desc의 `opt_w` 인자 삭제 → ⑦b red · 옛 곡예사 문구 복귀 → ⑦a red ·
#   #7 옛 머리말 문구 복귀 → ⑧a·⑧d red.
#   (전부 실측 — 배치 1: ①a·①c·②a·③a·④a·④c·④d · 배치 2: ②d·⑤·⑥a·⑦a·⑦b·⑧ · 문구 2건 재확인)
#
# 실행: ./run_tests.sh polish_r17   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _src: PackedStringArray = PackedStringArray()
var _inv_src: PackedStringArray = PackedStringArray()

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
	while m.dialogue.is_open() and guard < 60:
		m.dialogue.advance()
		guard += 1

# ── 소스 스캔 헬퍼(polish_r7~r16의 그 관례) ─────────────────────────────────
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _line_in(lines: PackedStringArray, needle: String) -> int:
	for i in range(lines.size()):
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			return i
	return -1

func _line_in_func(lines: PackedStringArray, fn_needle: String, needle: String) -> int:
	var head := -1
	for i in range(lines.size()):
		if lines[i].begins_with(fn_needle):
			head = i
			break
	if head < 0:
		return -1
	for i in range(head + 1, lines.size()):
		if lines[i].begins_with("func "):
			return -1
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			return i
	return -1

# 그 줄에 박힌 첫 문자열 리터럴(따옴표 안). 표시 문구를 **소스에서 그대로** 집어 재기 위한 것 —
# 테스트가 문구를 옮겨 적으면 문구가 바뀐 날 초록인 채로 넘침이 되살아난다.
func _feed_texts(m: Node) -> Array:
	var out: Array = []
	for it in m.notice_feed._items:
		out.append(String(it["text"]))
	return out

func _literal_at(lines: PackedStringArray, idx: int) -> String:
	if idx < 0 or idx >= lines.size():
		return ""
	var s := lines[idx]
	var a := s.find("\"")
	if a < 0:
		return ""
	var b := s.find("\"", a + 1)
	return s.substr(a + 1, b - a - 1) if b > a else ""

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R17 회귀 — 배치 A(#0~#7) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_inv_src = _lines_of_file("res://inv_frame.gd")
	_check("무대 전제: main.gd(%d행)·inv_frame.gd(%d행)를 읽었다(부정 단언 공허 통과 방지)"
			% [_src.size(), _inv_src.size()], _src.size() > 1000 and _inv_src.size() > 500)

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)

	_check_resident_region_axis(m)
	await _check_booth_guard(m)
	await _check_craft_notice(m)
	_check_mine_entry_prompt(m)
	_check_chest_guide_width(m)
	await _check_mirror_fit(m)
	_check_profession_desc_width(m)
	_check_craft_header_width(m)

	_check_save_failure_voice(m)
	_check_menu_found_rewind(m)
	_check_sleep_clock_leak(m)
	_check_night_bar_keep(m)
	_check_weed_tone(m)
	_check_notice_step_reload(m)
	await _check_crab_pot_bait(m)
	_record_flavor_index(m)

	print("── 결과: %s (실패 %d) ──" % ["통과" if _fail == 0 else "실패", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 `_resident_tile`이 무대를 가른다(라이브) ───────────────────────────
# 공허 통과 방지 둘을 함께 세운다: ㉠ **다른 구역** 주민이 실제로 현재 구역 좌표 범위 안에 서
# 있는 칸을 찾고(그런 칸이 없으면 유령 가드도 없다 = 무대 실패), ㉡ 그 주민을 잠시 내려놓았을 때
# 배치가 되는 칸만 고른다(다른 사유로 이미 막힌 칸을 고르면 봉합을 지워도 초록이다).
func _check_resident_region_axis(m: Node) -> void:
	print("① #0 주민 칸 가드의 구역 축")
	m._indoor = ""
	var here: String = m._region
	var ghost: Resident = null
	var gt := Vector2i(-1, -1)
	for r in m._residents:
		if r.tile == Resident.UNPLACED:
			continue
		var st: String = r.station_region(int(m.clock.minutes))
		if st == "" or st == here:
			continue                      # 이 무대의 주민 — 막는 것이 맞다
		var t: Vector2i = r.tile
		if t.x < 0 or t.x >= m._grid_w or t.y < 0 or t.y >= m._outdoor_h:
			continue                      # 좌표 공간이 안 겹치면 애초에 사고가 안 난다
		# ★[폴리시 R18 #12] **스케줄도 함께 내려놓는다** — R18이 이 가드에 시간 축을 달아
		#   "오늘 중 그가 설 칸"까지 예약하므로, `r.tile`만 비우면 그 칸이 스케줄 항목에
		#   그대로 걸려 후보를 못 찾는다(무대 기법이 낡은 것 — 재는 계약은 그대로다).
		var sched: Array = r.schedule
		r.tile = Resident.UNPLACED
		r.schedule = []
		var free_ok: bool = m._can_place_furnace(t)
		r.tile = t
		r.schedule = sched
		if free_ok:
			ghost = r
			gt = t
			break
	_check("① 무대: **다른 구역** 주민이 이 무대(%s) 좌표를 물고 있다(%s이 %s에서 %s — 내려놓으면 배치 가능)"
			% [here, ghost.id if ghost != null else "?", ghost.station_region(int(m.clock.minutes)) if ghost != null else "?",
				str(gt), ] if ghost != null else "① 무대: 유령 가드를 만들 주민을 못 찾았다",
		ghost != null)
	if ghost == null:
		return
	_check("①a 그 칸에 이제 업화로·결정기·게잡이통 가드가 안 걸린다(화면엔 아무도 없는 칸)",
		m._can_place_furnace(gt) and m._can_place_crystalarium(gt) and not m._resident_tile(gt))
	# ㉡ 대조군 — 같은 주민을 **제 무대에서** 만나면 그대로 막는다(좁히기만 했다는 증거).
	var there: String = ghost.station_region(int(m.clock.minutes))
	m._rebuild_region(there)
	var blocked_there: bool = m._resident_tile(gt)
	var free_there := false
	if blocked_there:
		# ★[폴리시 R18 #12] 위 탐색과 같은 이유로 스케줄도 함께 내려놓는다(시간 축 예약 해제).
		var keep: Vector2i = ghost.tile
		var keep_sched: Array = ghost.schedule
		ghost.tile = Resident.UNPLACED
		ghost.schedule = []
		free_there = m._can_place_furnace(gt)
		ghost.tile = keep
		ghost.schedule = keep_sched
	_check("①b 같은 주민을 제 무대(%s)에서 만나면 그 칸은 그대로 막힌다(주민만이 막는다: %s)"
			% [there, str(free_there)], blocked_there and free_there)
	m._rebuild_region(here)
	# ㉢ 두 술어가 **한 곳**에서 구역을 판다 — 답이 갈리면 프롬프트↔동작이 다시 갈린다.
	var helper := _line_in(_src, "func _resident_on_stage(r: Resident) -> bool:")
	var used_tile := _line_in_func(_src, "func _resident_tile", "_resident_on_stage(r)")
	var used_face := _line_in_func(_src, "func _facing_resident", "_resident_on_stage(r)")
	_check("①c 구역 축이 단일 출처다(%d행 정의 · `_resident_tile` %d행 · `_facing_resident` %d행)"
			% [helper + 1, used_tile + 1, used_face + 1],
		helper >= 0 and used_tile > helper and used_face > helper)

# ── ② #1 행사·좌판 부스 칸(라이브 + 소스) ───────────────────────────────────
func _check_booth_guard(m: Node) -> void:
	print("② #1 부스 칸 설치 가드·프롬프트 양보")
	var keep: String = m._region
	m._indoor = ""
	var booths := [
		["더비 부스", RegionCatalog.SAMDOCHEON, m.DERBY_BOOTH_TILE],
		["저승 야시장", RegionCatalog.NARU_VILLAGE, m.NIGHT_MARKET_TILE],
		["저승 보부상", RegionCatalog.NARU_VILLAGE, m.PEDDLER_TILE],
	]
	var blocked: Array[String] = []
	var control: Array[String] = []
	for b in booths:
		m._rebuild_region(String(b[1]))
		await process_frame
		var t: Vector2i = b[2]
		if not m._can_place_furnace(t) and not m._can_place_crystalarium(t) and m._f_booth_tile(t):
			blocked.append(String(b[0]))
		# 대조군 — **바로 옆 칸**은 그대로 놓인다(가드가 세 좌표만 자른다는 증거이자,
		# 이 칸이 "원래 놓이던 자리"였다는 재현이다).
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if m._can_place_furnace(t + d) and not m._f_booth_tile(t + d):
				control.append("%s%s" % [String(b[0]), str(t + d)])
				break
	_check("②a 세 부스 칸 전부에서 업화로·결정기가 막힌다(%s)" % ", ".join(blocked),
		blocked.size() == booths.size())
	_check("②b 대조군: 바로 옆 칸은 그대로 놓인다(%s) — 가드가 세 좌표만 자른다" % ", ".join(control),
		control.size() == booths.size())
	# 구세이브 탈출구 — 이미 놓인 기계는 **행사일에만** [F]를 양보하고, 그 밖의 날엔 되돌아온다.
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	await process_frame
	var pt: Vector2i = m.PEDDLER_TILE
	m._sleeping = false
	m._target = pt
	m.furnace.place(m._region, pt)
	var open_day := Peddler.next_open_day(m.clock.day)
	var keep_day: int = m.clock.day
	m.clock.day = open_day
	var yields_on: bool = m._facing_event_booth() and m._furnace_at(pt)
	m.clock.day = open_day + 1 if not Peddler.is_open_day(open_day + 1) else open_day + 2
	var back_off: bool = not m._facing_event_booth() and m._furnace_at(pt)
	_check("②c 좌판 날(%d일)엔 부스가 [F]를 가져가고(%s), 그 밖의 날(%d일)엔 화덕이 되돌아온다(%s)"
			% [open_day, str(yields_on), m.clock.day, str(back_off)], yields_on and back_off)
	m.furnace.remove(m._region, pt)
	m.clock.day = keep_day
	m._rebuild_region(keep)
	await process_frame
	# 프롬프트 사슬이 그 양보를 **화면에** 옮긴다(실행 사다리는 손대지 않았다 = 매몰 0).
	var pr_f := _line_in(_src, "elif _furnace_at(_target) and not _f_taken_before_machine(_target):")
	var pr_c := _line_in(_src, "elif _crystalarium_at(_target) and not _f_taken_before_machine(_target):")
	var ex_ped := _line_in(_src, "if _facing_peddler() and Input.is_action_just_pressed(\"shop_toggle\"):")
	var ex_fur := _line_in(_src, "if not _sleeping and _furnace_at(_target) and Input.is_action_just_pressed(\"shop_toggle\"):")
	_check("②d 두 기계 프롬프트가 양보 절을 든다(업화로 %d행 · 결정기 %d행)" % [pr_f + 1, pr_c + 1],
		pr_f >= 0 and pr_c >= 0)
	# 양보 대상은 **실행 사다리에서 기계보다 위에 선 것 전수**다(부스 셋 + 게잡이통 + 수액 채취기).
	# R16 #13이 기계 안내를 맨 앞으로 올리며 셋 다에서 같은 역전을 만들었고, polish_r8 ⑥c가 그
	# 사실을 R16 이후 줄곧 빨갛게 붙들고 있었다.
	var ex_pot := _line_in(_src, "crab_pot.has_at(_region, _target) \\")
	var ex_tap := _line_in(_src, "tapper.has_at(_region, _tapper_ledger_tile(_target)) \\")
	_check("②f 통(%d행)·채취기(%d행)도 실행 사다리에서 기계(%d행)보다 먼저 잡으므로 같은 양보를 받는다"
			% [ex_pot + 1, ex_tap + 1, ex_fur + 1],
		ex_pot > 0 and ex_tap > ex_pot and ex_fur > ex_tap
			and _src[pr_f].contains("_f_taken_before_machine"))
	_check("②e 실행 사다리는 그대로다 — 부스(%d행)가 기계(%d행)보다 먼저 잡는 그 순서에 프롬프트를 맞춘 것이다"
			% [ex_ped + 1, ex_fur + 1], ex_ped >= 0 and ex_fur > ex_ped)

# ── ③ #2 제작 만재 알림이 **실제로 있는 길**을 가리킨다(라이브 + 소스) ──────
func _check_craft_notice(m: Node) -> void:
	print("③ #2 제작 만재 알림의 지시")
	# 제작 가능한 행 하나를 세우고 백팩을 가득 채운다(산출을 못 담는 상태 = 그 알림의 조건).
	m._foraging_xp = 100
	m.inventory.add_item(ItemCatalog.NEOK_GOSARI, 2)
	m.inventory.add_item(ItemCatalog.JAETBIT_NAENGI, 1)
	m.inventory.add_item(ItemCatalog.JEOSEUNG_DALLAE, 1)
	for i in m.inventory.slots.size():
		if m.inventory.slots[i] == null:
			m.inventory.slots[i] = {"id": ItemCatalog.STONE, "count": 999, "quality": 0}
	m.notice_feed._items.clear()
	m._open_frame(InventoryFrame.CTX_MENU)
	m.frame.set_tab(InventoryFrame.TAB_CRAFT)
	await process_frame
	m._on_frame_craft(CraftCatalog.WILD_SEEDS_PIAN)
	var said := ""
	for it in m.notice_feed._items:
		if String(it["text"]).contains("만들지 못했다"):
			said = String(it["text"])
	_check("③a 알림이 「아래 가방」이 아니라 실제 절차를 말한다 — 「%s」" % said,
		said != "" and said.contains("[E]") and said.contains("가방 탭") and not said.contains("아래 가방"))
	# 근거 ㉠ — 그 화면엔 백팩이 없다(프레임 `_draw`가 인벤 탭에서만 그린다).
	var bp := _line_in_func(_inv_src, "func _draw", "if menu_tab == TAB_INV:")
	var bp_call := _inv_src[bp + 1] if bp >= 0 else ""
	_check("③b 근거: 백팩 그리드는 인벤 탭에서만 그려진다(inv_frame %d행 → %s)"
			% [bp + 1, bp_call.strip_edges()],
		bp >= 0 and bp_call.contains("_draw_backpack") and m.frame.menu_tab == InventoryFrame.TAB_CRAFT)
	# 근거 ㉡ — **REFUTED 기록.** 헌트는 `cycle_tab()`이 안 불린다고 적었으나 [E]가 부른다.
	var key := _line_in_func(_src, "func _process", "frame.cycle_tab()")
	var guard := 0
	while m.frame.menu_tab != InventoryFrame.TAB_INV and guard < InventoryFrame.TAB_COUNT:
		m.frame.cycle_tab()
		guard += 1
	_check("③c [E]가 실제로 탭을 돌린다(main %d행 — 헌트의 「미배선」 주장은 REFUTED · %d번 눌러 가방 탭 도달)"
			% [key + 1, guard], key >= 0 and m.frame.menu_tab == InventoryFrame.TAB_INV)
	m._close_frame()
	for i in m.inventory.slots.size():
		m.inventory.slots[i] = null

# ── ④ #3 갱도 엘리베이터 프롬프트가 Label 폭 안에 산다 ──────────────────────
# 분모를 안 적는다: 도달 깊이는 `MineFloors.MAX_FLOOR`, 한도는 `InteractPrompt`의 실제 폭,
# 글자 크기는 테마에서 받는다(전부 봉합 코드가 쓰는 그 출처).
func _check_mine_entry_prompt(m: Node) -> void:
	print("④ #3 갱도 입구 프롬프트 폭")
	var limit: float = m._prompt_max_width()
	var fs: int = m._prompt_font_size()
	_check("④ 무대: 한도·글자 크기를 노드·테마에서 받았다(Label %.0fpx · %dpx 글자)" % [limit, fs],
		limit > 100.0 and fs >= 10)
	var keep_depth: int = m.mine_floors._depth
	var keep_pick: int = m._mine_entry_pick
	var over_old: Array[String] = []
	var over_new: Array[String] = []
	var folded := 0
	var full_kept := 0
	for depth in range(1, MineFloors.MAX_FLOOR + 1):
		m.mine_floors._depth = depth
		var opts: Array[int] = m._mine_entry_options()
		for pick in opts:
			m._mine_entry_pick = pick
			# 옛 형태(전 층 나열) — 결함 재현용 기준선.
			var names: Array[String] = []
			for f in opts:
				names.append(("〔%d〕" % f) if f == pick else str(f))
			var old_line := "[F] 갱도 %d층으로 내려간다   [G] 엘리베이터: %s층" % [pick, " · ".join(names)]
			if opts.size() > 1 and HanjiUi.text_width(old_line, fs) > limit:
				over_old.append("%d층/%d개" % [depth, opts.size()])
			var now: String = m._mine_entry_prompt()
			if HanjiUi.text_width(now, fs) > limit:
				over_new.append("%d층(%.0fpx)" % [depth, HanjiUi.text_width(now, fs)])
			if now == old_line:
				full_kept += 1
			elif opts.size() > 1:
				folded += 1
	m.mine_floors._depth = keep_depth
	m._mine_entry_pick = keep_pick
	_check("④a 도달 가능한 전 깊이(1~%d층)의 모든 선택에서 프롬프트가 Label 폭 안이다(초과: %s)"
			% [MineFloors.MAX_FLOOR, "없음" if over_new.is_empty() else ", ".join(over_new)],
		over_new.is_empty())
	_check("④b 결함 재현: 옛 전 층 나열은 %d개 조합에서 넘쳤다(첫 초과 %s) — 공허 통과가 아니다"
			% [over_old.size(), over_old[0] if not over_old.is_empty() else "-"], over_old.size() > 0)
	_check("④c 짧을 땐 안 접는다(전 층 나열 유지 %d조합) · 넘칠 때만 접는다(%d조합)"
			% [full_kept, folded], full_kept > 0 and folded > 0)
	# 접힘이 무손실인가 — 1층·계단 폭·최대 개방층·지금 고른 층이 전부 그 줄에서 읽힌다.
	m.mine_floors._depth = MineFloors.MAX_FLOOR
	var deep: Array[int] = m._mine_entry_options()
	m._mine_entry_pick = deep[deep.size() - 1]
	var fold_line: String = m._mine_entry_prompt()
	_check("④d 접힌 줄이 목록을 재구성할 세 값 + 지금 고른 층을 전부 싣는다 — 「%s」" % fold_line,
		fold_line.contains("〔%d〕" % m._mine_entry_pick)
			and fold_line.contains("%d~%d" % [MineFloors.ELEVATOR_STEP, deep[deep.size() - 1]])
			and fold_line.contains("%d층 단위" % MineFloors.ELEVATOR_STEP)
			and fold_line.contains(str(deep[0])))
	m.mine_floors._depth = keep_depth
	m._mine_entry_pick = keep_pick

# ── ⑤ #4 저장 상자 안내가 나무 테두리 안쪽에 산다 ───────────────────────────
# 문구는 **소스에서 그대로 집어** 재고, 가용 폭은 그리기가 쓰는 `_panel_rect()`·`_inner_right()`
# ·`PAD`에서 판다(양쪽 다 옮겨 적기 0).
func _check_chest_guide_width(m: Node) -> void:
	print("⑤ #4 저장 상자 안내 폭")
	var frame = m.frame
	var panel: Rect2 = frame._panel_rect()
	var x: float = panel.position.x + frame.PAD
	var avail: float = frame._inner_right(panel) - x
	var idx := _line_in_func(_inv_src, "func _draw_chest_top", "클릭=회수")
	var lit := _literal_at(_inv_src, idx)
	var w := HanjiUi.text_width(lit, 12)
	_check("⑤ 무대: 그리기 문구를 소스에서 집었다(inv_frame %d행) — 「%s」" % [idx + 1, lit],
		idx >= 0 and lit != "")
	_check("⑤a 안내가 나무 테두리 안쪽에 든다(%.0fpx ≤ 가용 %.0fpx · 판 %.0f~%.0f)"
			% [w, avail, panel.position.x, panel.end.x], w <= avail)
	# 형제 두 줄(출하함·곳간)과 같은 골격·같은 여유인가 — 이 줄만 튀던 것이 결함이었다.
	var bin_lit := _literal_at(_inv_src, _line_in_func(_inv_src, "func _draw_bin_top", "백팩 클릭=드롭"))
	var lar_lit := _literal_at(_inv_src, _line_in_func(_inv_src, "func _draw_larder_top", "백팩 클릭=적재"))
	var bw := HanjiUi.text_width(bin_lit, 12)
	var lw := HanjiUi.text_width(lar_lit, 12)
	_check("⑤b 형제 두 줄도 같은 폭 안이다(출하함 %.0f · 곳간 %.0f · 상자 %.0f ≤ %.0f)"
			% [bw, lw, w, avail],
		bin_lit != "" and lar_lit != "" and bw <= avail and lw <= avail and w <= avail)
	# 넘칠 때 스스로 줄어드는 그리기로 갈았는가(문구가 다시 길어져도 판을 안 뚫는다).
	var call := _line_in_func(_inv_src, "func _draw_chest_top", "draw_text_fit")
	_check("⑤c 그리기가 `draw_text_fit`(폭 인자 있음)으로 갈렸다(inv_frame %d행)" % (call + 1),
		call >= 0 and _inv_src[call + 2].contains("_inner_right(panel)"))

# ── ⑥ #5 점괘 거울 본문이 판 안에 산다(라이브 · 한 해 전수 + 최악 조합) ─────
func _check_mirror_fit(m: Node) -> void:
	print("⑥ #5 점괘 거울 판 기하")
	var view: Vector2 = m._logical_view_size(m.mirror_panel)
	var keep_day: int = m.clock.day
	var year: int = GameClock.DAYS_PER_SEASON * 4
	var over: Array[String] = []
	var smallest := 99999.0
	var largest := 0.0
	for d in range(1, year + 1):
		m.clock.day = d
		m._open_mirror()
		var body: float = m._mirror_body_height(m.mirror_text.text, m.mirror_text.size.x)
		if body > m.mirror_text.size.y + 0.5:
			over.append("%d일(%.0f > %.0f)" % [d, body, m.mirror_text.size.y])
		if m.mirror_panel.size.y > largest:
			largest = m.mirror_panel.size.y
		if m.mirror_panel.size.y < smallest:
			smallest = m.mirror_panel.size.y
		if m.mirror_panel.position.y < 0.0 or (m.mirror_panel.position.y + m.mirror_panel.size.y) > view.y \
				or m.mirror_panel.position.x < 0.0 or (m.mirror_panel.position.x + m.mirror_panel.size.x) > view.x:
			over.append("%d일 판이 뷰 밖(%s)" % [d, str(m.mirror_panel.position)])
	m.clock.day = keep_day
	_check("⑥a 한 해 %d일 전부에서 본문이 판 안에 들고 판이 뷰(%.0f×%.0f) 안이다(초과: %s)"
			% [year, view.x, view.y, "없음" if over.is_empty() else ", ".join(over)], over.is_empty())
	# ㉡ **최악 조합**은 데이터에서 만든다 — 슬롯별로 한 해 전체(테마는 전 종류)를 훑어 가장 넓은
	#    변형을 뽑아 실제 골격으로 조립한다. 하루도 동시에 안 뜨는 조합까지 미리 잰다.
	var worst_fortune := ""
	var worst_ped := ""
	var worst_bday := ""
	var worst_event := ""
	for d in range(1, year + 1):
		m.clock.day = d
		worst_fortune = _wider(worst_fortune, DailyLuck.fortune_text(d, 0))
		worst_ped = _wider(worst_ped, m._peddler_upcoming_line())
		worst_bday = _wider(worst_bday, m._birthday_upcoming_line())
		worst_event = _wider(worst_event, m._event_upcoming_line())
	m.clock.day = keep_day
	var worst_fest := ""
	for th in range(0, Festival.NAMES.size()):
		for ahead in range(0, GameClock.DAYS_PER_SEASON + 1):
			worst_fest = _wider(worst_fest, Festival.upcoming_text(th, ahead))
	var worst_hint := ""
	for w in range(0, Weather.NAMES.size()):
		worst_hint = _wider(worst_hint, "내일: %s — %s" % [Weather.name_of(w), m._weather_hint(w)])
	var warn := _literal_at(_src, _line_in_func(_src, "func _mirror_forecast_text", "절기가 바뀐다"))
	var head := _literal_at(_src, _line_in_func(_src, "func _mirror_forecast_text", "◆ 점괘 거울 ◆"))
	var worst := "\n".join([head, "", worst_fortune, "", worst_hint, "", warn, "",
		"◇ " + worst_fest, "◇ " + worst_event, "◇ " + worst_ped, "◇ " + worst_bday])
	_check("⑥ 무대: 최악 조합을 슬롯별 실제 생성기에서 조립했다(운·예보·경고·테마·행사·보부상·생일 7슬롯)",
		worst_fortune != "" and worst_fest != "" and worst_event != "" and worst_ped != ""
			and worst_bday != "" and warn != "" and head != "")
	m.mirror_text.text = worst
	m._layout_mirror_panel()
	var wbody: float = m._mirror_body_height(worst, m.mirror_text.size.x)
	_check("⑥b 그 최악 조합도 판 안에 든다(본문 %.0f ≤ Label %.0f · 판 %.0f~%.0f · 뷰 %.0f)"
			% [wbody, m.mirror_text.size.y, m.mirror_panel.position.y, (m.mirror_panel.position.y + m.mirror_panel.size.y), view.y],
		wbody <= m.mirror_text.size.y + 0.5 and (m.mirror_panel.position.y + m.mirror_panel.size.y) <= view.y)
	# 결함 재현 — 옛 고정 기하(본문 폭 412 · 높이 196)로는 이 조합이 넘친다.
	var old_body: float = m._mirror_body_height(worst, 412.0)
	_check("⑥c 결함 재현: 옛 기하에선 같은 본문이 %.0fpx로 Label 196px을 넘었다" % old_body,
		old_body > 196.0)
	# 줄 수 측정이 Label과 같은 답을 내는가 — 봉합이 그 등식 위에 서 있다.
	await process_frame
	await process_frame
	var lines_label: int = m.mirror_text.get_line_count()
	var fh := HanjiUi.FONT.get_height(m.mirror_text.get_theme_font_size("font_size"))
	var spacing := float(m.mirror_text.get_theme_constant("line_spacing"))
	_check("⑥d 폰트 측정과 Label이 같은 줄 수를 낸다(%d줄 · %.0fpx)"
			% [lines_label, wbody], absf(float(lines_label) * (fh + spacing) - wbody) < 0.5)
	_check("⑥e 예고가 없는 날엔 판이 옛 고정 높이(232)보다 작다(최소 %.0f · 최대 %.0f)"
			% [smallest, largest], smallest < 232.0 and largest <= view.y)
	m._close_mirror()

func _wider(a: String, b: String) -> String:
	if b == "":
		return a
	return b if HanjiUi.text_width(b, 16) > HanjiUi.text_width(a, 16) else a

# ── ⑦ #6 전문직 선택 버튼 글자가 버튼 판 안에 산다(카탈로그 전수) ───────────
func _check_profession_desc_width(m: Node) -> void:
	print("⑦ #6 전문직 선택 버튼 글자 폭")
	var frame = m.frame
	var panel: Rect2 = frame._panel_rect()
	# 그리기가 쓰는 식 그대로: btn = Rect2(x + 8, y, bar_w − 16, …) · 글자는 좌우 OPT_TEXT_X 여백.
	var bar_w: float = panel.size.x - frame.PAD * 2.0 - 24.0
	var avail: float = (bar_w - 16.0) - frame.OPT_TEXT_X * 2.0
	var over: Array[String] = []
	var total := 0
	var widest := ""
	for sk in ProfessionCatalog.SKILLS:
		for p in ProfessionCatalog.professions_for(sk):
			total += 1
			var d := String(p["desc"])
			var n := String(p["name"])
			if HanjiUi.text_width(d, 10) > avail:
				over.append("%s(%.0f)" % [n, HanjiUi.text_width(d, 10)])
			if HanjiUi.text_width(n, 12) > avail:
				over.append("%s 이름(%.0f)" % [n, HanjiUi.text_width(n, 12)])
			if HanjiUi.text_width(d, 10) > HanjiUi.text_width(widest, 10):
				widest = d
	_check("⑦ 무대: 전문직 표 %d개를 전수로 쟀다(가용 %.0fpx · 최장 「%s」 %.0fpx)"
			% [total, avail, widest, HanjiUi.text_width(widest, 10)], total >= 20)
	_check("⑦a 전 항목의 이름·설명이 버튼 판 안에 든다(초과: %s)"
			% ("없음" if over.is_empty() else ", ".join(over)), over.is_empty())
	# 문구를 줄이는 것만으로는 다음 항목이 다시 샌다 — 그리기가 폭을 물어야 한다.
	var dsc := _line_in_func(_inv_src, "func _draw_skill_tab", "opt.get(\"desc\", \"\")")
	var nam := _line_in_func(_inv_src, "func _draw_skill_tab", "opt.get(\"name\", \"\")")
	_check("⑦b 두 줄 다 폭 인자를 넘긴다(설명 %d행 · 이름 %d행 — `opt_w`)" % [dsc + 1, nam + 1],
		dsc >= 0 and nam >= 0 and _inv_src[dsc].contains("opt_w") and _inv_src[nam].contains("opt_w"))
	_check("⑦c 결함 재현: 옛 곡예사 문구는 같은 판을 넘겼다(%.0f > %.0f)"
			% [HanjiUi.text_width("특수기 쿨다운 절반 (무기 특수동작 도입 전까지 효과 보류)", 10), avail],
		HanjiUi.text_width("특수기 쿨다운 절반 (무기 특수동작 도입 전까지 효과 보류)", 10) > avail)

# ── ⑧ #7 제작 탭 머리말이 나무 테두리 안쪽에 산다 ───────────────────────────
func _check_craft_header_width(m: Node) -> void:
	print("⑧ #7 제작 탭 머리말 폭")
	var frame = m.frame
	var panel: Rect2 = frame._panel_rect()
	var x: float = panel.position.x + frame.PAD + 12.0
	var avail: float = frame._inner_right(panel) - x
	# 축은 **행에서 파생**되고(R14) 서식도 **소스에서 집는다** — 둘 다 옮겨 적으면 한쪽이 바뀐 날
	# 초록인 채로 넘침이 되살아난다. 헌트가 "축은 항상 둘"이라 적은 것도 여기서 반증된다(실제 셋).
	var axes: Array = frame._craft_skill_axes(m._craft_rows())
	var tpl := _literal_at(_inv_src, _line_in_func(_inv_src, "func _draw_craft_tab", "손 제작 — %s"))
	var headline := tpl % " · ".join(axes)
	var raw := HanjiUi.text_width(headline, 12)
	_check("⑧ 무대: 축(%d개 %s)과 서식을 코드에서 집었다 — 「%s」" % [axes.size(), str(axes), headline],
		axes.size() >= 2 and tpl.contains("%s"))
	_check("⑧a 머리말이 축소 없이(12px) 테두리 안쪽에 든다(%.0f ≤ 가용 %.0f)" % [raw, avail],
		raw <= avail)
	# 축이 하나 더 늘어도 `draw_text_fit`이 흡수한다(그 여유가 남아 있는지까지 잰다).
	var plus: Array = axes.duplicate()
	plus.append("낚시")
	var grown := tpl % " · ".join(plus)
	var shrunk := 12
	while shrunk > 10 and HanjiUi.text_width(grown, shrunk) > avail:
		shrunk -= 1
	_check("⑧d 축이 넷이 돼도 말줄임 없이 든다(%.0f → %dpx에서 %.0f ≤ %.0f)"
			% [HanjiUi.text_width(grown, 12), shrunk, HanjiUi.text_width(grown, shrunk), avail],
		HanjiUi.text_width(grown, shrunk) <= avail)
	var call := _line_in_func(_inv_src, "func _draw_craft_tab", "draw_text_fit")
	var arg := _inv_src[call + 2] if call >= 0 else ""
	_check("⑧b 그리기가 `draw_text_fit`으로 갈리고 폭을 `_inner_right`에서 판다(inv_frame %d행)"
			% (call + 1), call >= 0 and arg.contains("_inner_right(panel) - x"))
	var old_tpl := "손 제작 — %s 숙련으로 배운다 (행 클릭 = 제작)"
	var old_w := HanjiUi.text_width(old_tpl % " · ".join(axes), 12)
	_check("⑧c 결함 재현: 옛 문구는 폭 인자도 없이 %.0f > %.0f로 그대로 넘쳤다" % [old_w, avail],
		old_w > avail)

# ── ⑨ #8 저장 실패가 화면에 말해진다(라이브 · 실제 IO 실패 주입) ─────────────
# 무대를 진짜로 만든다: `SaveManager`가 쓸 수 없는 슬롯을 주어 `_save_game()`이 실제로 false를
# 돌려주게 하고(문자열 스텁이 아니라 IO 경로 그대로), 그때 화면에 무엇이 뜨는지를 큐에서 읽는다.
func _check_save_failure_voice(m: Node) -> void:
	print("⑨ #8 저장 실패 알림")
	var keep_slot: int = m._active_slot
	m.notice_feed._items.clear()
	# 성공 기준선 — 성공은 종전대로 `_save_game`의 "저장됨" 한 줄뿐이다(이중 토스트 0 = R11 계약).
	var ok: bool = m._save_or_warn()
	var ok_lines := _feed_texts(m)
	_check("⑨ 무대: 정상 슬롯에서는 성공하고 성공 문구는 한 줄뿐이다(%s)" % str(ok_lines),
		ok and ok_lines.size() == 1 and String(ok_lines[0]).contains("저장됨"))
	# 실패 주입 — **진짜 IO 실패**다(스텁 0): 임시 파일 자리에 디렉터리를 세우면
	# `save.gd`의 `FileAccess.open(tmp, WRITE)`가 null을 돌려주고 그 경로가 그대로 false로 흐른다.
	m.notice_feed._items.clear()
	m._active_slot = 7
	var tmp := SaveManager.slot_path(7) + SaveManager.TMP_SUFFIX
	DirAccess.make_dir_absolute(tmp)
	var bad: bool = m._save_or_warn()
	var bad_lines := _feed_texts(m)
	DirAccess.remove_absolute(tmp)
	m._active_slot = keep_slot
	var said := ""
	for s in bad_lines:
		if String(s).contains("저장하지"):
			said = String(s)
	_check("⑨a 실제로 쓰기가 실패하고(%s) 화면이 그 사실을 말한다 — 「%s」" % [str(bad), said],
		not bad and said != "" and not said.contains("저장됨"))
	# ★ 취침 자동 저장은 아침 훅과 같은 프레임이라 keep이 없으면 축출된다(#11과 같은 판별식).
	var kept := false
	for it in m.notice_feed._items:
		if String(it["text"]).contains("저장하지"):
			kept = bool(it.get("keep", false))
	_check("⑨b 그 경고에 keep 표가 붙어 있다(아침 알림 더미에 밀려 사라지지 않게)", kept)
	# 반환값을 버리던 다섯 입구가 전부 새 창구로 갈렸다 — 소스 전수(명단 하드코딩 0).
	var raw := 0
	var warned := 0
	var cur := ""
	var raw_fns: Array = []
	for line in _src:
		var ln := String(line)
		if ln.begins_with("func "):
			cur = ln.substr(5, maxi(ln.find("("), 5) - 5)
		if ln.strip_edges().begins_with("#") or cur == "_save_or_warn":
			continue
		if ln.contains("_save_game()") and not ln.contains("func _save_game"):
			raw += 1
			raw_fns.append(cur)
		if ln.contains("_save_or_warn()") and not ln.contains("func _save_or_warn"):
			warned += 1
	_check("⑨c 날 `_save_game()` 호출부는 성패를 **보는** 둘만 남았다(%s) · 새 창구 경유 %d곳"
			% [str(raw_fns), warned],
		raw == 2 and raw_fns.has("_on_frame_save") and raw_fns.has("_on_frame_quit") and warned == 5)
	m.notice_feed._items.clear()

# ── ⑩ #9 `menu_found`가 형제와 같은 무가드로 되감긴다(라이브 왕복) ───────────
func _check_menu_found_rewind(m: Node) -> void:
	print("⑩ #9 융합 메뉴 발견 원장 되감기")
	# ㉠ 부팅으로 시드되지 않음 — 이 원장의 유일한 기록처가 `item_gained` 훅이고, 로드는 `changed`만 쏜다.
	var writer := _line_in(_src, "_menu_found[id] = true")
	var loader := _line_in_func(_lines_of_file("res://inventory.gd"), "func load_save", "changed.emit()")
	_check("⑩ 무대: 기록처가 `_on_item_gained` 한 곳(main %d행)이고 `inventory.load_save`는 changed만 쏜다(%d행)"
			% [writer + 1, loader + 1], writer >= 0 and loader >= 0)
	# ㉡ 라이브 왕복 — 원장을 채운 뒤 **키가 없는 구세이브 dict**를 로드에 먹인다.
	var keep: Dictionary = m._menu_found.duplicate()
	m._menu_found = {"__ghost__": true}
	m._apply_menu_found({})
	_check("⑩a 키 없는 구세이브를 읽으면 원장이 비워진다(버린 타임라인의 해금이 안 살아남는다)",
		m._menu_found.is_empty())
	m._apply_menu_found({"menu_found": {"x": true}})
	_check("⑩b 키가 있으면 그 값으로 되감는다(%s)" % str(m._menu_found),
		m._menu_found.has("x") and not m._menu_found.has("__ghost__"))
	m._menu_found = keep
	# ㉢ 형제와 같은 문법인가 — 두 줄이 같은 `.get(키, {})` 모양이어야 계약이 하나다.
	var ff := _line_in_func(_src, "func _load_game", "data.get(\"forage_found\", {})")
	var mf := _line_in_func(_src, "func _apply_menu_found", "data.get(\"menu_found\", {})")
	var seam := _line_in_func(_src, "func _load_game", "_apply_menu_found(data)")
	var guarded := _line_in(_src, "data.has(\"menu_found\")")
	_check("⑩c 두 형제가 같은 무가드 `.get(키, {})` 문법이다(forage_found %d행 · menu_found %d행 · 옛 has 가드 %d)"
			% [ff + 1, mf + 1, guarded + 1], ff >= 0 and mf >= 0 and guarded < 0)
	_check("⑩d 로드가 그 창구를 실제로 부른다(%d행 — 씬 밖 헬퍼가 아니라 로드 경로 위다)" % (seam + 1),
		seam > 0 and seam > ff)

# ── ⑪ #10 취침 트윈이 도는 동안 시계가 안 흐른다 ────────────────────────────
# 재는 것은 문자열이 아니라 **시계 상태와 실제 분**이다: 아침 훅이 도는 시점의 running과,
# 트윈 길이만큼 프레임을 흘렸을 때 minutes가 START_MIN에서 안 움직이는가.
func _check_sleep_clock_leak(m: Node) -> void:
	print("⑪ #10 취침 트윈 시계 누수")
	var per_sec: float = float(GameClock.END_MIN - GameClock.START_MIN) / GameClock.REAL_SECONDS_PER_DAY
	var tween_secs := 0.7   # 아래 ⑪c가 소스에서 다시 판다(여긴 표시용)
	var seen_running := [true]
	var probe := func(_d: int) -> void: seen_running[0] = m.clock.running
	m.clock.day_advanced.connect(probe)
	m.clock.running = true
	m.clock.sleep(false)
	m.clock.day_advanced.disconnect(probe)
	_check("⑪a 아침 훅(day_advanced)이 도는 동안 시계는 멈춰 있다 — `_arm_spine_b4` 머리말이 단언하는 그 상태",
		seen_running[0] == false and m.clock.running == false)
	# 트윈 구간을 실제로 흘려도 분이 안 움직인다(멈춘 시계는 `_process`가 안 민다).
	var before: float = m.clock.minutes
	m.clock._process(tween_secs)
	_check("⑪b 그 0.7초 동안 분이 한 눈금도 안 간다(%.1f → %.1f · 종전 손실 %.1f 게임분)"
			% [before, m.clock.minutes, tween_secs * per_sec],
		is_equal_approx(before, m.clock.minutes) and before == float(GameClock.START_MIN))
	# 대조군 — 기본값(resume)은 종전 그대로 즉시 흐른다(헤드리스 하네스가 쓰는 그 경로).
	m.clock.sleep()
	_check("⑪c 대조: 인자 없는 `sleep()`은 종전대로 곧바로 흐른다(다른 호출부 거동 불변)",
		m.clock.running == true)
	# 정지 주인 = 재개 주인 — `_do_sleep`이 멈추고 `_on_sleep_done`이 켠다.
	var stop := _line_in_func(_src, "func _do_sleep", "clock.running = false")
	var bind := _line_in_func(_src, "func _do_sleep", "clock.sleep.bind(false)")
	var resume := _line_in_func(_src, "func _on_sleep_done", "clock.running = true")
	var b4 := _line_in_func(_src, "func _on_sleep_done", "_fire_spine_b4()")
	_check("⑪d 멈춘 자리(%d행)와 켜는 자리(%d행)가 한 연출의 양끝이고, 콜백은 재개를 미룬다(%d행)"
			% [stop + 1, resume + 1, bind + 1], stop >= 0 and bind >= 0 and resume >= 0)
	_check("⑪e 재개가 컷신 스냅(`_fire_spine_b4` %d행)보다 **먼저**다 — 꺼진 채 스냅되면 연출 뒤 시간이 안 간다"
			% (b4 + 1), b4 > resume)
	# 트윈 길이는 소스에서 판다(0.7 = interval 0.3 + 페이드인 0.4).
	var iv := _line_in_func(_src, "func _do_sleep", "tween_interval(")
	var fi := _line_in_func(_src, "func _do_sleep", "tween_property(fade, \"modulate:a\", 0.0")
	_check("⑪f 재개를 미룬 구간이 실제로 트윈 꼬리 전체다(정지 %d행 · 페이드인 %d행 · 그 뒤가 `_on_sleep_done`)"
			% [iv + 1, fi + 1], iv > bind and fi > iv)

# ── ⑫ #11 밤 바 마감 정산이 아침 알림 더미에 안 밀린다(라이브) ──────────────
func _check_night_bar_keep(m: Node) -> void:
	print("⑫ #11 밤 바 마감 정산 축출")
	m.notice_feed._items.clear()
	m._on_night_closed(3, 120, 2)
	var line := ""
	var kept := false
	for it in m.notice_feed._items:
		if String(it["text"]).contains("나라카 바 마감"):
			line = String(it["text"])
			kept = bool(it.get("keep", false))
	_check("⑫ 무대: 정산 한 줄이 큐에 들어갔다 — 「%s」" % line, line != "")
	_check("⑫a 그 줄에 keep 표가 붙어 있다", kept)
	# 아침 훅이 미는 만큼(MAX_ITEMS 초과) 계속 밀어도 살아남는다 — 분모는 피드에서 판다.
	for i in m.notice_feed.MAX_ITEMS + 3:
		m._notice("아침 알림 %d" % i)
	var survived := false
	for it in m.notice_feed._items:
		if String(it["text"]).contains("나라카 바 마감"):
			survived = true
	_check("⑫b MAX_ITEMS(%d)를 %d줄 넘겨 밀어도 살아남는다(종전엔 다섯째 push에서 축출됐다)"
			% [m.notice_feed.MAX_ITEMS, m.notice_feed.MAX_ITEMS + 3], survived)
	_check("⑫c 큐 상한 계약은 그대로다(%d ≤ %d — keep이 상한을 무너뜨리지 않는다)"
			% [m.notice_feed._items.size(), m.notice_feed.MAX_ITEMS],
		m.notice_feed._items.size() <= m.notice_feed.MAX_ITEMS)
	# 다시 볼 경로가 없다는 근거 — `end_day`는 `closed`를 쏘고 곧바로 정산을 0으로 지운다.
	var nb := _lines_of_file("res://night_bar.gd")
	var emit_line := _line_in_func(nb, "func end_day", "closed.emit(")
	var wipe := _line_in_func(nb, "func end_day", "abandon()")
	_check("⑫d 근거: `end_day`가 정산을 쏜(%d행) 직후 `abandon()`(%d행)이 값을 0으로 지운다 — 재발행 경로 0"
			% [emit_line + 1, wipe + 1], emit_line >= 0 and wipe > emit_line)
	m.notice_feed._items.clear()

# ── ⑬ #12 재점령 잡초가 debris 잡초와 같은 톤으로 그려진다 ──────────────────
# 픽셀로 잰다: 두 경로가 같은 칸에서 집는 텍스처가 **같은 객체**인가(캐시 합류), 그리고 그것이
# 원본과 실제로 다른 톤인가(합류가 무의미하지 않다는 대조군).
func _check_weed_tone(m: Node) -> void:
	print("⑬ #12 재점령 잡초 톤")
	var t := Vector2i(11, 23)
	var variant: Texture2D = m._debris_variant_tex(m.PROP_DEBRIS_WEEDS, t)
	var muted: Texture2D = m._muted_prop_tex(variant, m._MUTE_WOODY.has(m.PROP_DEBRIS_WEEDS))
	_check("⑬ 무대: 잡초가 muted 대상 목록에 있고 목본이 아니다(잔디류 강도)",
		m._MUTE_GREEN_PROPS.has(m.PROP_DEBRIS_WEEDS) and not m._MUTE_WOODY.has(m.PROP_DEBRIS_WEEDS))
	# 그리기 경로가 실제로 그 캐시를 태우는가 — 두 줄이 같은 식을 쓴다.
	var enc := _line_in_func(_src, "func _draw_encroach_weeds", "_muted_prop_tex(")
	var props := _line_in(_src, "draw_tex = _muted_prop_tex(draw_tex, _MUTE_WOODY.has(tex))")
	_check("⑬a 두 그리기 경로가 같은 캐시를 태운다(재점령 %d행 · debris %d행)" % [enc + 1, props + 1],
		enc >= 0 and props >= 0)
	_check("⑬b 그 캐시는 같은 변주에 대해 **같은 객체**를 돌려준다(톤이 갈릴 수 없다)",
		muted == m._muted_prop_tex(variant, false))
	# 대조군 — mute가 실제로 픽셀을 바꾼다(합류가 공허하지 않다는 증거).
	var a := variant.get_image()
	var b := muted.get_image()
	var diff := 0
	var checked := 0
	for y in range(0, b.get_height(), 2):
		for x in range(0, b.get_width(), 2):
			var pa := a.get_pixel(x, y)
			if pa.a < 0.5:
				continue
			checked += 1
			if not pa.is_equal_approx(b.get_pixel(x, y)):
				diff += 1
	_check("⑬c 대조: mute 사본은 원본과 실제로 다르다(검사 %d px 중 %d px 변경 — 종전엔 이 차이가 그대로 화면에 갈렸다)"
			% [checked, diff], checked > 0 and diff > 0)

# ── ⑭ #13 NOTICE 단계 세이브를 F9로 불러오면 통보가 다시 열린다(라이브) ─────
func _check_notice_step_reload(m: Node) -> void:
	print("⑭ #13 NOTICE 단계 F9 왕복")
	var keep_step: int = m.onboarding.step
	var keep_slot: int = m._active_slot
	# ㉠ 무대 — NOTICE 단계를 파일에 굳힌다(통보를 못 넘긴 채 24:00 강제 취침이 만드는 그 파일).
	_dismiss_dialogue(m)
	m.onboarding.step = Onboarding.NOTICE
	var saved: bool = m._save_game()
	_check("⑭ 무대: NOTICE 단계가 파일에 실렸다(%s)" % str(saved), saved)
	# ㉡ 플레이가 진행돼 단계를 넘긴 뒤 F9 — 종전엔 여기서 통보가 다시 안 열렸다.
	m.onboarding.step = Onboarding.MEET_MIHO
	_dismiss_dialogue(m)
	var loaded: bool = m._load_game()
	_check("⑭a 로드가 단계를 NOTICE로 되감았다(%s · loaded=%s)"
			% [str(m.onboarding.step == Onboarding.NOTICE), str(loaded)],
		loaded and m.onboarding.step == Onboarding.NOTICE)
	_check("⑭b **그 프레임에 통보가 다시 열려 있다** — 종전엔 이 대화가 없어 단계가 영원히 갇혔다(대화 %s)"
			% str(m.dialogue.is_open()), m.dialogue.is_open())
	# ㉢ 그리고 그 대화를 끝내면 단계가 실제로 넘어간다(탈출구가 살아 있다).
	_dismiss_dialogue(m)
	m._on_dialogue_finished()
	_check("⑭c 통보를 끝내면 단계가 넘어간다(NOTICE → %d) — 갇힘이 풀렸다" % m.onboarding.step,
		m.onboarding.step > Onboarding.NOTICE)
	# ㉣ 갇혔을 때 무엇이 죽는지 — 이 술어들이 그 사고의 실체다(문서가 아니라 코드로 남긴다).
	m.onboarding.step = Onboarding.NOTICE
	var r_okja: Resident = m._resident("okja")
	var r_bana: Resident = m._resident("bana")
	_check("⑭d 근거: NOTICE에서는 옥자 게이트가 닫히고(facing %s) 안내도 비어 있다(「%s」)"
			% [str(r_okja.facing_gate.call()), m.onboarding.guidance()],
		r_okja != null and not r_okja.facing_gate.call() and m.onboarding.guidance() == "")
	_check("⑭e 근거: 바나 무대도 함께 닫힌다(%s) — 밤 바가 통째로 잠긴다"
			% str(r_bana.visible_rule.call()), r_bana != null and not r_bana.visible_rule.call())
	m.onboarding.step = keep_step
	m._active_slot = keep_slot
	_dismiss_dialogue(m)

# ── ⑮ #15 게잡이통 회수가 장전한 미끼를 돌려준다(라이브) ────────────────────
func _check_crab_pot_bait(m: Node) -> void:
	print("⑮ #15 게잡이통 미끼 반환")
	m._indoor = ""
	var t := Vector2i(-1, -1)
	for r in [RegionCatalog.SAMDOCHEON, RegionCatalog.HWANGCHEONHAE, RegionCatalog.NARU_VILLAGE]:
		m._rebuild_region(String(r))
		for y in range(1, m._outdoor_h):
			for x in range(1, m._grid_w):
				if m._can_place_crab_pot(Vector2i(x, y)):
					t = Vector2i(x, y)
					break
			if t.x >= 0:
				break
		if t.x >= 0:
			break
	_check("⑮ 무대: 통을 놓을 수 있는 물가 칸을 찾았다(%s · %s)" % [m._region, str(t)], t.x >= 0)
	if t.x < 0:
		return
	for i in m.inventory.slots.size():
		m.inventory.slots[i] = null
	m.inventory.add_item(ItemCatalog.CRAB_POT, 1)
	m.inventory.add_item(ItemCatalog.BAIT_BASIC, 1)
	m._target = t
	m._sleeping = false
	m._place_crab_pot(t)
	m._use_crab_pot(t)   # ② 장전 — 미끼 1개가 통으로 들어간다
	_check("⑮a 무대: 미끼가 통에 들어갔다(장전 %s · 손에 남은 미끼 %d)"
			% [str(m.crab_pot.is_baited(m._region, t)), m.inventory.count_of(ItemCatalog.BAIT_BASIC)],
		m.crab_pot.is_baited(m._region, t) and m.inventory.count_of(ItemCatalog.BAIT_BASIC) == 0)
	m.notice_feed._items.clear()
	m._use_crab_pot(t)   # ③ 회수 — [F] 연타 한 번이 밟는 그 갈래
	var said := ""
	for it in m.notice_feed._items:
		if String(it["text"]).contains("회수"):
			said = String(it["text"])
	_check("⑮b 회수가 통과 미끼를 **둘 다** 되돌린다(통 %d · 미끼 %d) — 종전엔 미끼가 증발했다"
			% [m.inventory.count_of(ItemCatalog.CRAB_POT), m.inventory.count_of(ItemCatalog.BAIT_BASIC)],
		m.inventory.count_of(ItemCatalog.CRAB_POT) == 1
			and m.inventory.count_of(ItemCatalog.BAIT_BASIC) == 1
			and not m.crab_pot.has_at(m._region, t))
	_check("⑮c 알림이 그 사실을 말한다 — 「%s」" % said, said.contains("미끼"))
	# 만재 거절 — 적재先 관례(부분 성공 0): 통은 들어가는데 미끼가 못 들어가는 **딱 그 상태**를
	# 만든다(빈 칸 하나만 남긴다). 원장이 한 줄도 안 움직여야 한다.
	m._place_crab_pot(t)
	m._use_crab_pot(t)   # 다시 장전(회수분 미끼 1개를 그대로 쓴다)
	var empties: Array = []
	for i in m.inventory.slots.size():
		if m.inventory.slots[i] == null:
			empties.append(i)
	for k in range(1, empties.size()):
		m.inventory.slots[int(empties[k])] = {"id": ItemCatalog.STONE, "count": 999, "quality": 0}
	_check("⑮ 무대: 빈 칸이 정확히 하나다(통은 들어가고 미끼는 못 들어간다)", empties.size() >= 1)
	m.notice_feed._items.clear()
	m._use_crab_pot(t)
	var refused := ""
	for it in m.notice_feed._items:
		if String(it["text"]).contains("가득"):
			refused = String(it["text"])
	_check("⑮d 만재면 회수를 거절하고 원장은 그대로다(통 %s · 장전 %s) — 「%s」"
			% [str(m.crab_pot.has_at(m._region, t)), str(m.crab_pot.is_baited(m._region, t)), refused],
		m.crab_pot.has_at(m._region, t) and m.crab_pot.is_baited(m._region, t) and refused != "")
	# 프롬프트가 그 동작을 말하고, Label 폭 안에 든다(R17 #3이 세운 한도).
	var pr: String = m._crab_pot_prompt(t)
	_check("⑮e 프롬프트가 미끼 반환을 말하고 폭이 %.0f ≤ %.0f다 — 「%s」"
			% [HanjiUi.text_width(pr, m._prompt_font_size()), m._prompt_max_width(), pr],
		pr.contains("미끼") and HanjiUi.text_width(pr, m._prompt_font_size()) <= m._prompt_max_width())
	m.crab_pot.remove(m._region, t)
	for i in m.inventory.slots.size():
		m.inventory.slots[i] = null

# ── ⑯ #14 OWNER-DECISION 기록 — 작물 사연 순환 index는 저장되지 않는다 ──────
# 코드를 **안 고쳤다.** 아래 판정의 근거를 수치로 남긴다.
func _record_flavor_index(m: Node) -> void:
	print("⑯ #14 사연 순환 index(OWNER-DECISION)")
	var decl := _line_in(_src, "var _harvest_seen: Dictionary = {}")
	var doc := ""
	for i in range(maxi(decl - 4, 0), decl):
		if _src[i].contains("세이브하지 않는다"):
			doc = _src[i].strip_edges()
	_check("⑯ 무대: 미저장이 **선언부에 명시된 결정**이다(main %d행) — 「%s」" % [decl + 1, doc],
		decl >= 0 and doc != "")
	# 사실 ㉠ — 저장 dict에 키가 없다(형제 `_run_harvested`는 같은 사건에서 저장된다).
	var in_save := _line_in_func(_src, "func _save_game", "harvest_seen")
	var run_saved := _line_in_func(_src, "func _save_game", "\"run_harvested\"")
	_check("⑯a 저장 dict에 키가 없다(%d) · 같은 수확 사건의 형제 `run_harvested`는 있다(%d행)"
			% [in_save + 1, run_saved + 1], in_save < 0 and run_saved >= 0)
	# 사실 ㉡ — 그래서 몇 줄이 세션 밖에서 도달 불가인가(카탈로그 파생 — 하드코딩 0).
	var crops := 0
	var lines := 0
	for cid in SoulMemory.MEMORIES.keys():
		crops += 1
		lines += SoulMemory.count(String(cid))
	var reachable := crops   # 세션마다 index 0부터 다시 — 실질 도달은 작물당 첫 줄
	_check("⑯b 사실: 사연 %d줄(작물 %d종 × %d줄) 중 세션 간 실질 도달은 %d줄뿐이다 — 나머지 %d줄은 한 세션에서 연속 수확해야만 보인다"
			% [lines, crops, lines / maxi(crops, 1), reachable, lines - reachable],
		lines > crops and crops > 0)
	# 사실 ㉢ — 형제 순환 index가 저장소에 없다(대조할 관례 자체가 없다 = 판단 근거 부재).
	var siblings: Array = []
	for line in _src:
		var ln := String(line)
		if ln.begins_with("var _") and (ln.contains("index") or ln.contains("_seen")) \
				and ln.contains("Dictionary"):
			siblings.append(ln.split(":")[0].strip_edges())
	_check("⑯c 판정 OWNER-DECISION: 대조할 형제 순환 원장이 저장소에 없다(%s) — 저장은 사연 도달성을 바꾸는 **설계 결정**이라 폴리시 회차가 단독으로 뒤집지 않는다"
			% str(siblings), siblings.size() == 1)
