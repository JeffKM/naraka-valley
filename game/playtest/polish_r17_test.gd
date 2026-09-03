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
		r.tile = Resident.UNPLACED
		var free_ok: bool = m._can_place_furnace(t)
		r.tile = t
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
		var keep: Vector2i = ghost.tile
		ghost.tile = Resident.UNPLACED
		free_there = m._can_place_furnace(gt)
		ghost.tile = keep
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
	var pr_f := _line_in(_src, "elif _furnace_at(_target) and not _facing_event_booth():")
	var pr_c := _line_in(_src, "elif _crystalarium_at(_target) and not _facing_event_booth():")
	var ex_ped := _line_in(_src, "if _facing_peddler() and Input.is_action_just_pressed(\"shop_toggle\"):")
	var ex_fur := _line_in(_src, "if not _sleeping and _furnace_at(_target) and Input.is_action_just_pressed(\"shop_toggle\"):")
	_check("②d 두 기계 프롬프트가 부스에 양보한다(업화로 %d행 · 결정기 %d행)" % [pr_f + 1, pr_c + 1],
		pr_f >= 0 and pr_c >= 0)
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
