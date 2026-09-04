extends SceneTree
# ★[폴리시 18회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#9).
#
# 렌즈: R17 diff 리뷰(#0) · 도달 계약(#1·#2) · 프롬프트↔실행 불일치(#3) · 표시 진실성(#4·#5·#8) ·
#       시간 게이트(#6·#7) · 스케줄↔지도 정합(#9).
#
# 이 회차의 태도 셋.
#   ㉠ **"어느 칸을 겨눠야 하는가"는 눈에 보이는 것이 정한다.** #1·#2가 같은 병이다 — 원장 좌표와
#      보이는 그림이 어긋난 자리에서 프롬프트만 뜨고 버튼이 안 먹었다. 그래서 아래 단언은 전부
#      "프롬프트가 서는 칸 = 실행이 성립하는 칸"을 한 쌍으로 잰다(한쪽만 재면 반쪽이 다시 샌다).
#   ㉡ **표시 단언은 문구를 옮겨 적지 않는다.** 알림·툴팁 문구는 소스가 아니라 **그 문구를 만드는
#      함수를 실제로 호출해** 받는다(`_ranch_door_open_notice`·`HudTooltip.label_for`). 두 함수는
#      이번 회차에 문구 조립을 한 곳으로 모으며 생긴 이름이고, 화면 경로가 쓰는 바로 그것이다.
#   ㉢ **분모는 레지스트리에서 판다.** 아이콘 케이스 누락(#4)은 "10종 중 9종"이라 세면 카테고리가
#      느는 날 초록인 채로 다시 빠진다 — 카테고리 목록을 item_catalog.gd에서 긁어 분모로 쓴다.
#
# 무엇을 보증하나(번호 = 18회차 헌트 발견 인덱스):
#   ① #0 취침 트윈 중 시작된 컷신이 `clock.running=false`를 스냅해 컷신 종료 후 하루가 통째로 멎었다.
#   ② #1 혼의 나무 심기·수확이 `_target_valid`(밭 흙) 게이트에 막혀 프롬프트만 뜨고 무동작이었다.
#   ③ #2 안식 마당 나무 — 벌목·이끼는 캐노피 꼭대기, 수액 채취기는 밑동(같은 나무, 3칸 갈린 조준 칸).
#   ④ #3 갱도·나락 층 포괄 프롬프트가 휘파람 [F] 안내를 삼켜, 화면의 [F]와 실제 [F]가 갈렸다.
#   ⑤ #4 CAT_RELIC만 두 슬롯 드로어의 match에 케이스가 없어 손에 든 유품이 빈 칸으로 보였다.
#   ⑥ #5 작물 성장일수가 화면에 도달하는 경로가 0이었다(유일 호출부 = 영구 비가시 라벨).
#   ⑦ #6 바나와 결혼하면 22시 이후 '집'에서 나라카 바를 원격으로 열 수 있었다(방어 불가 약탈).
#   ⑧ #7 체키 제안창·촬영 세션이 카페 마감(19:00)을 넘어 살아남아 정산 뒤에 장부가 더 올랐다.
#   ⑨ #8 방목 문 알림이 밤·잿눈에도 «짐승이 방목지로 나간다»고 말했지만 실제 방출은 0이었다.
#   ⑩ #9 세레나 스케줄 3칸이 전부 강변 레인인데 걷기는 메인 복도로만 라우팅 — 집 WALL 관통 60칸.
#
# 판정: #0~#9 전부 CONFIRMED(봉합). REFUTED·DUP·OWNER 0건.
#
# 봉합 축(근거 전문은 커밋 본문·각 함수 머리말):
#   · #0 = `_begin_cutscene`의 스냅에 `or _sleeping`(형제 둘이 R12/R13에 받은 그 가드의 컷신 판).
#          R17 #10이 재개 주인을 `clock.sleep` → `_on_sleep_done`으로 옮겨 스냅 창이 0.4초에서
#          연출 전 구간(1.1초)으로 벌어진 것이 이 결함의 직접 원인이라, R17 계약은 안 건드린다.
#   · #1 = `_orchard_dispatch_at` or-항(S10-T5 화분이 두 게이트에 받은 그 처방의 과수 판).
#   · #2 = `_home_tree_ledger_tile` 다리(R14/R15가 채취기 두 축에 놓은 그 다리의 벌목·이끼 판).
#          **더하기만 한다** — 앵커 칸 조준은 한 프레임도 안 바뀐다(회수 가능한 것을 안 뺀다).
#   · #3 = `_mount_prompt()`로 세 갈래를 한 곳에 뽑고 갱도·나락 층 포괄 분기 **앞**에 세운다.
#   · #4 = 두 드로어에 CAT_RELIC 케이스 + 색은 `ItemCatalog.RELICS.color` 단일 출처(진열장도 파생).
#   · #5 = `HudTooltip.label_for`가 씨앗의 성장일수를 붙인다(main 주석이 선언한 인계의 이행).
#   · #6 = `_night_bar_optin_close_min()` — 결혼하면 `SPOUSE_HOME_MIN["bana"]` 파생으로 창이 좁아진다.
#          미혼의 창(19:00~24:00)은 불변이라 새 관계 게이트가 아니다(ADR-0008).
#   · #7 = `_cheki_offered_at`에 영업 창 술어 + `_on_cafe_closed`가 정산 **전에** 창구를 접는다.
#   · #8 = `_ranch_door_open_notice(building, released, to_release)` — 방출 결과와 이유를 갈라 말한다.
#   · #9 = `_road_lane_of`가 지도와 **같은 술어**로 레인을 가르고, 갈리면 다리 스파인에서 환승한다.
#
# 하중 검증(계약을 일부러 깨서 red 확인 후 원복 — 전부 실측):
#   #0 `or _sleeping` 삭제 → ①b·①c red ·
#   #1 두 게이트의 `orchard_dispatch` or-항 삭제 → ②d·②e red ·
#   #2 `_home_tree_ledger_tile` 본문을 `return t`로 → ③c·③d·③e red ·
#   #3 갱도·나락 `_mount_prompt()` 분기 삭제 → ④d red ·
#   #4 hotbar_hud의 CAT_RELIC 케이스 삭제 → ⑤b red · RELICS의 color 키 삭제 → ⑤d red ·
#   #5 `label_for`의 씨앗 갈래 삭제 → ⑥b red ·
#   #6 `_night_bar_optin_close_min`을 `NightBar.CLOSE_MIN` 고정으로 → ⑦b·⑦c red ·
#   #7 `_cheki_offered_at`의 `cafe.is_open()` 삭제 → ⑧b red · `_on_cafe_closed`의 접기 삭제 → ⑧d red ·
#   #8 `_ranch_door_open_notice`를 옛 한 줄로 되돌림 → ⑨b·⑨c red ·
#   #9 `_road_lane_of`를 `ROAD_LANE_Y[region]` 고정으로 → ⑩b·⑩c red.
#
# 실행: ./run_tests.sh polish_r18   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _src: PackedStringArray = PackedStringArray()
var _hot_src: PackedStringArray = PackedStringArray()
var _inv_src: PackedStringArray = PackedStringArray()
var _cat_src: PackedStringArray = PackedStringArray()

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

# ── 소스 스캔 헬퍼(polish_r7~r17의 그 관례) ─────────────────────────────────
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
		if lines[i].begins_with("func ") or lines[i].begins_with("static func "):
			return -1
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			return i
	return -1

func _count_in(lines: PackedStringArray, needle: String) -> int:
	var n := 0
	for line in lines:
		if String(line).strip_edges().begins_with("#"):
			continue
		if String(line).contains(needle):
			n += 1
	return n

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R18 회귀 — 배치 A(#0~#9) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_hot_src = _lines_of_file("res://hotbar_hud.gd")
	_inv_src = _lines_of_file("res://inv_frame.gd")
	_cat_src = _lines_of_file("res://item_catalog.gd")
	_check("무대 전제: main(%d행)·hotbar_hud(%d)·inv_frame(%d)·item_catalog(%d)를 읽었다(부정 단언 공허 통과 방지)"
			% [_src.size(), _hot_src.size(), _inv_src.size(), _cat_src.size()],
		_src.size() > 1000 and _hot_src.size() > 100 and _inv_src.size() > 500 and _cat_src.size() > 500)

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)

	_check_sleep_cutscene_clock(m)
	_check_orchard_dispatch(m)
	_check_home_tree_bridge(m)
	_check_mount_prompt(m)
	_check_relic_icon(m)
	_check_seed_growth_tooltip(m)
	_check_night_bar_optin_window(m)
	_check_cheki_close_boundary(m)
	_check_ranch_door_notice(m)
	_check_riverside_lane(m)

	print("── 결과: %s (실패 %d) ──" % ["통과" if _fail == 0 else "실패", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 취침 트윈 한가운데 선 컷신의 시계 스냅(라이브) ─────────────────────
# 공허 통과 방지: ㉠ 형제 둘이 이미 같은 가드를 갖고 있음을 소스로 확인해(관례가 실재한다)
# ㉡ 스냅 **전에** `clock.running == false`임을 확인한 뒤(그 창이 진짜다) 스냅 값을 잰다.
func _check_sleep_cutscene_clock(m: Node) -> void:
	print("① #0 취침 중 컷신의 시계 스냅")
	var b5 := _line_in(_src, "_spine_b5_clock_prev = clock.running or _sleeping")
	var epi := _line_in(_src, "_epilogue_clock_prev = clock.running or _sleeping")
	_check("①a 무대: 형제 둘이 이미 `or _sleeping` 가드를 쓴다(B5 %d행 · 에필로그 %d행) — 컷신만 빠져 있던 자리다"
			% [b5 + 1, epi + 1], b5 >= 0 and epi >= 0)

	# 취침 연출 한가운데를 재현한다 — `_do_sleep`이 세우는 두 값 그대로.
	var prev_sleeping: bool = m._sleeping
	var prev_running: bool = m.clock.running
	var prev_cut = m.cutscene
	m.cutscene = null
	m._sleeping = true
	m.clock.running = false
	_check("①b 무대: 취침 연출 중이라 `clock.running == false`이고 `_sleeping == true`다(스냅 창이 실재)",
		not m.clock.running and m._sleeping)
	var began: bool = m._begin_cutscene(Spine.B6_CUTSCENE.duplicate(true), "", PackedStringArray())
	_check("①c 취침 중 시작한 컷신의 스냅 = **true**(재생 개시 %s · `_cutscene_clock_prev` %s) — 꺼진 채로 뜨면 `_end_cutscene`이 그 false를 복원해 하루가 통째로 멎는다"
			% [str(began), str(m._cutscene_clock_prev)], began and m._cutscene_clock_prev)

	# 눈뜨는 프레임 이후(=`_on_sleep_done`이 지나간 뒤) 컷신이 끝나면 **시계가 다시 흐른다**.
	# ★재생 중의 정지는 러너 소유다(스텝의 clock_on) — 그래서 여기서 재는 것은 종료 시점의
	#   복원값이다. 스냅이 false로 떴다면 이 줄이 false로 복원해 그 하루가 통째로 멎었다.
	m._sleeping = false
	m.clock.running = true
	m._apply_cutscene_frame()
	var during: bool = m.clock.running          # 재생 중 = `_cutscene_clock_prev and 러너 clock_on`
	m._end_cutscene()
	_check("①d 컷신이 끝나면 시계가 다시 흐른다(재생 중 %s → 종료 후 %s) — 스냅이 곧 복원값이다"
			% [str(during), str(m.clock.running)], m.clock.running)

	m.cutscene = prev_cut
	m._sleeping = prev_sleeping
	m.clock.running = prev_running

# ── ② #1 혼의 나무 심기·수확이 디스패치 게이트를 통과한다(라이브) ───────────
# 공허 통과 방지: 고른 칸이 **`_target_valid`가 거짓인 칸**이어야 한다 — 밭 흙 위에서 재면
# 봉합을 지워도 초록이다(기존 or-항이 이미 통과시킨다).
func _check_orchard_dispatch(m: Node) -> void:
	print("② #1 과수 디스패치 or-항")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	# 과수원 존 안에서 3×3이 통째로 비어 있고 SOIL이 아닌 앵커를 찾는다.
	var zone: Rect2i = m.ORCHARD_ZONE_RECT
	var anchor := Vector2i(-1, -1)
	for y in range(zone.position.y + 1, zone.end.y - 1):
		for x in range(zone.position.x + 1, zone.end.x - 1):
			var t := Vector2i(x, y)
			if m._is_farmable(t):
				continue                     # 밭 흙이면 기존 게이트가 이미 통과시킨다(무대 부적격)
			if m.orchard.can_plant(t, m._is_tree_blocked):
				anchor = t
				break
		if anchor.x >= 0:
			break
	_check("②a 무대: 과수원 존 안에 «밭 흙이 아니고 3×3이 비어 있는» 앵커가 있다 %s" % str(anchor),
		anchor.x >= 0)
	if anchor.x < 0:
		return

	var orchard_snap: Dictionary = m.orchard.to_save()
	var fruit: String = FruitTreeCatalog.ids()[0]
	var sapling: String = ItemCatalog.sapling_id(fruit)
	m._target = anchor
	m._target_valid = m._is_farmable(anchor)
	m.inventory.slots[m.inventory.selected_index] = {"id": sapling, "count": 1, "quality": 0}
	_check("②b 무대: 그 칸은 `_target_valid`가 **거짓**이고(밭 흙 아님) 손에 든 것은 묘목(%s)이다" % sapling,
		not m._target_valid and ItemCatalog.category_of(sapling) == ItemCatalog.CAT_SAPLING)
	_check("②c 심기 축: `_orchard_dispatch_at`이 그 칸을 연다 — 프롬프트도 같은 답이다(「%s」)"
			% m._farm_prompt(), m._orchard_dispatch_at(anchor) and m._farm_prompt().contains("묘목 심기"))

	# 실제로 심고 → 캐노피 칸(앵커가 아닌 풋프린트 칸)에서 수확 축을 잰다.
	var planted: bool = m.orchard.plant(anchor, fruit, m.clock.day, m._is_tree_blocked)
	var canopy := anchor + Vector2i(-1, -1)
	_check("②d 수확 축: 앵커 아닌 풋프린트 칸 %s도 창구가 열린다(심기 %s · `_target_valid` %s · 디스패치 %s)"
			% [str(canopy), str(planted), str(m._is_farmable(canopy)), str(m._orchard_dispatch_at(canopy))],
		planted and not m._is_farmable(canopy) and m._orchard_dispatch_at(canopy))
	# 게이트 두 줄이 실제로 그 or-항을 물고 있는가(입력 사슬의 자리 — 라이브로는 못 누른다).
	var g_use := _line_in(_src, "or orchard_dispatch) \\")
	var g_harv := _line_in(_src, "(_target_valid or pot_dispatch or orchard_dispatch)")
	_check("②e 두 디스패치 게이트가 그 or-항을 물었다 — LMB `_use_tool`(main %d행) · RMB `_try_harvest`(%d행)"
			% [g_use + 1, g_harv + 1], g_use >= 0 and g_harv >= 0)
	m.orchard.load_save(orchard_snap)      # 무대 원복 — 심은 나무를 원장에서 되돌린다
	m.inventory.slots[m.inventory.selected_index] = null

# ── ③ #2 안식 마당 나무 — 밑동↔앵커 다리(라이브) ────────────────────────────
func _check_home_tree_bridge(m: Node) -> void:
	print("③ #2 마당 나무 밑동 다리")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	var drop_tiles: int = int(m._tapper_home_drop()) / int(m.TILE)
	_check("③a 무대: 손저작 나무 보정 = 스프라이트 높이 − 한 칸 = %d칸(0이면 이 결함 자체가 없다)"
			% drop_tiles, drop_tiles > 0)
	var anchors: Array = m._home_tree_anchors()
	var anchor := Vector2i(-1, -1)
	for t in anchors:
		var a: Vector2i = t
		if m.tree_ledger.is_occupied(RegionCatalog.HOME, a) \
				and not m.tree_ledger.is_occupied(RegionCatalog.HOME, a + Vector2i(0, drop_tiles)):
			anchor = a
			break
	_check("③b 무대: 원장이 아는 손저작 앵커(%d그루) 중 밑동 칸이 원장에 **없는** 나무를 골랐다 %s"
			% [anchors.size(), str(anchor)], anchor.x >= 0)
	if anchor.x < 0:
		return
	var trunk := anchor + Vector2i(0, drop_tiles)
	_check("③c 보이는 밑동 %s → 원장 칸 %s로 이어진다(다리 없으면 그 칸은 원장 밖이라 도끼·낫이 무동작)"
			% [str(trunk), str(m._home_tree_ledger_tile(trunk))], m._home_tree_ledger_tile(trunk) == anchor)
	_check("③d **더하기만 한다** — 앵커 칸 조준은 그대로 앵커다(%s) · 아무 나무도 없는 칸은 항등(%s)"
			% [str(m._home_tree_ledger_tile(anchor)), str(m._home_tree_ledger_tile(Vector2i(0, 0)))],
		m._home_tree_ledger_tile(anchor) == anchor and m._home_tree_ledger_tile(Vector2i(0, 0)) == Vector2i(0, 0))
	# 채취기 축은 이미 밑동에서 선다 — 벌목 축이 같은 칸에서 서야 한 나무의 동사가 안 갈린다.
	_check("③e 같은 밑동 칸에서 **채취기 설치 축**(%s)과 **벌목 축**(%s)이 같은 나무를 가리킨다"
			% [str(m._tapper_place_tile(trunk)), str(m._home_tree_ledger_tile(trunk))],
		m._tapper_place_tile(trunk) == anchor and m._home_tree_ledger_tile(trunk) == anchor)
	# 프롬프트 사슬이 **밑동에서 실제로 선다** — 그 elif가 묻는 술어를 그대로 다시 묻는다.
	var stands: bool = m.tree_ledger.is_occupied(m._region, m._home_tree_ledger_tile(trunk))
	var t_prompt: String = m._tree_prompt(m._home_tree_ledger_tile(trunk))
	_check("③f 밑동을 겨눈 프롬프트가 선다(사슬 술어 %s) — 「%s」 · 앵커를 겨눴을 때와 같은 문장이다"
			% [str(stands), t_prompt], stands and t_prompt == m._tree_prompt(anchor))

# ── ④ #3 휘파람 [F] 안내가 갱도·나락 층에서도 선다 ──────────────────────────
func _check_mount_prompt(m: Node) -> void:
	print("④ #3 갱도·나락 층의 휘파람 안내")
	var held: String = m.inventory.selected_id()
	m.inventory.slots[m.inventory.selected_index] = {"id": ItemCatalog.MOUNT_WHISTLE, "count": 1, "quality": 0}
	m._indoor = ""
	var prev_depth: int = m._narak_depth
	m._narak_depth = 0
	var mine_line: String = m._mount_prompt()
	m._narak_depth = 1
	var narak_line: String = m._mount_prompt()
	m._narak_depth = prev_depth
	_check("④a 갱도 무대(깊이 0)는 **탈 수 있다** — 「%s」" % mine_line, mine_line.contains("[F]"))
	_check("④b 나락 층(깊이 1)은 왜 못 타는지를 말한다 — 「%s」" % narak_line,
		narak_line != "" and not narak_line.contains("[F]") and narak_line.contains("탈 수 없다"))
	m.inventory.slots[m.inventory.selected_index] = null
	_check("④c 든 게 휘파람이 아니면 이 안내를 안 세운다(\"\" — 사슬을 안 가로챈다)", m._mount_prompt() == "")
	if held != "":
		m.inventory.slots[m.inventory.selected_index] = {"id": held, "count": 1, "quality": 0}
	# 두 포괄 분기가 **자기 바닥 줄보다 먼저** 그 안내를 잡는가(입력 사슬의 자리 = 라이브로는 못 누른다).
	# 자리를 이름이 아니라 **순서로** 잰다: 갱도 블록 안 → 나락 블록 안 → 사슬 맨 끝, 셋이 이 순서다.
	# ★두 술어는 파일 곳곳(구역 크기·카메라)에 같은 형태로 나오므로 **프롬프트 사슬의 그것**을
	#   집는다 — 그 사슬의 머리인 갱도 입구 분기 뒤로 처음 나오는 자리다.
	var chain_head := _line_in(_src, "elif _at_dungeon_gate():")
	var mine_head := -1
	var narak_head := -1
	for i in range(chain_head + 1, _src.size()):
		var ln := String(_src[i])
		if mine_head < 0 and ln.contains("elif _in_mine_floor():"):
			mine_head = i
		if mine_head >= 0 and narak_head < 0 and ln.contains("elif _in_narak_floor():"):
			narak_head = i
			break
	var hits: Array = []
	for i in range(_src.size()):
		if String(_src[i]).contains("elif _mount_prompt() != \"\":"):
			hits.append(i)
	_check("④d 휘파람 갈래가 셋이다 — 갱도 블록(%d행 > 머리 %d) · 나락 블록(%d > %d) · 사슬 맨 끝(%d행)"
			% [(hits[0] + 1) if hits.size() > 0 else -1, mine_head + 1,
				(hits[1] + 1) if hits.size() > 1 else -1, narak_head + 1,
				(hits[2] + 1) if hits.size() > 2 else -1],
		hits.size() == 3 and mine_head >= 0 and narak_head >= 0 \
			and mine_head < hits[0] and hits[0] < narak_head and narak_head < hits[1] \
			and hits[1] < hits[2])

# ── ⑤ #4 CAT_RELIC 아이콘 케이스(레지스트리 파생 분모) ──────────────────────
func _check_relic_icon(m: Node) -> void:
	print("⑤ #4 유품 아이콘 케이스")
	# 분모 = item_catalog.gd가 선언한 **전 카테고리**(옮겨 적기 0 — 카테고리가 늘면 분모가 는다).
	var cats: Array = []
	for line in _cat_src:
		var ln := String(line)
		if ln.begins_with("const CAT_"):
			cats.append(ln.split(" ")[1])
	_check("⑤a 무대: 카테고리 상수를 소스에서 %d종 긁었다 %s" % [cats.size(), str(cats)], cats.size() >= 10)
	var missing_hot: Array = []
	var missing_inv: Array = []
	for c in cats:
		var cname := String(c)
		if ItemCatalog.ids_in_category(_cat_value(cname)).is_empty():
			continue                       # 인벤에 들 id가 하나도 없는 카테고리는 그릴 것이 없다
		if _line_in(_hot_src, "ItemCatalog." + cname + ":") < 0:
			missing_hot.append(cname)
		if _line_in(_inv_src, "ItemCatalog." + cname + ":") < 0:
			missing_inv.append(cname)
	_check("⑤b 두 슬롯 드로어의 match에 빠진 카테고리가 0이다(핫바 %s · 백팩 %s)"
			% [str(missing_hot), str(missing_inv)], missing_hot.is_empty() and missing_inv.is_empty())
	# 유품 전 종이 실제로 CAT_RELIC이고 색박스 폴백을 갖는다(전량 — 한 종만 재면 표가 늘 때 샌다).
	var relics: Array = ItemCatalog.ids_in_category(ItemCatalog.CAT_RELIC)
	var colorless: Array = []
	for rid in relics:
		if ItemCatalog.tool_color_of(String(rid)) == Color.WHITE:
			colorless.append(rid)
	_check("⑤c 무대: 유품 %d종이 CAT_RELIC으로 분류된다 %s" % [relics.size(), str(relics)],
		relics.size() == ItemCatalog.RELICS.size() and relics.size() > 0)
	_check("⑤d 유품 전 종이 색박스 폴백을 갖는다(흰 박스로 떨어지는 종 %s) — 색 출처는 RELICS의 color 하나다"
			% str(colorless), colorless.is_empty())
	# 진열장이 그 표를 파생해 읽는가(색이 두 곳에서 갈리지 않는다).
	var derived := _line_in(_src, "relic_colors[rid] = ItemCatalog.tool_color_of(String(rid))")
	_check("⑤e 혼백관 진열도 같은 표를 파생한다(main %d행) — 지역 색 dict가 사라졌다" % (derived + 1),
		derived >= 0 and _line_in(_src, "ItemCatalog.RELIC_BINYEO: Color(") < 0)

func _cat_value(cname: String) -> String:
	# "CAT_TOOL" → ItemCatalog.CAT_TOOL 값. 소스에서 긁은 이름을 값으로 되돌린다(하드코딩 0).
	var idx := _line_in(_cat_src, "const " + cname + " :=")
	if idx < 0:
		return ""
	var s := String(_cat_src[idx])
	var a := s.find("\"")
	var b := s.find("\"", a + 1)
	return s.substr(a + 1, b - a - 1) if b > a else ""

# ── ⑥ #5 씨앗 성장일수가 화면 문구에 실제로 실린다 ──────────────────────────
func _check_seed_growth_tooltip(m: Node) -> void:
	print("⑥ #5 성장일수 도달 경로")
	var seeds: Array = ItemCatalog.ids_in_category(ItemCatalog.CAT_SEED)
	_check("⑥a 무대: 씨앗 %d종을 카탈로그에서 파생했다(하드코딩 0)" % seeds.size(), seeds.size() > 0)
	var missing: Array = []
	var shown := 0
	for sid in seeds:
		var days := CropCatalog.growth_days(ItemCatalog.crop_of(String(sid)))
		if days <= 0:
			continue                        # 성장일수가 없는 파생 id(혼합 봉지 등)는 붙일 값이 없다
		shown += 1
		if not HudTooltip.label_for(String(sid), 0).contains("%d일" % days):
			missing.append(sid)
	_check("⑥b 성장일수를 가진 씨앗 %d종이 전부 툴팁 문구에 그 값을 싣는다(빠진 종 %s)"
			% [shown, str(missing)], shown > 0 and missing.is_empty())
	# 이름·등급이라는 기존 계약은 안 깨졌다(덧붙이기이지 갈아 끼우기가 아니다).
	var one := String(seeds[0])
	var lbl := HudTooltip.label_for(one, 2)
	_check("⑥c 이름·등급 계약 불변 — 「%s」에 이름(%s)과 등급(%s)이 함께 있다"
			% [lbl, ItemCatalog.name_of(one), ItemCatalog.quality_name(2)],
		lbl.contains(ItemCatalog.name_of(one)) and lbl.contains(ItemCatalog.quality_name(2)))
	# 그리는 쪽이 그 함수를 쓰는가(문구 출처가 하나여야 화면과 단언이 안 갈린다).
	var used := _line_in(_lines_of_file("res://hud_tooltip.gd"), "text = label_for(id, _inv.quality_at(idx))")
	_check("⑥d 툴팁 `_process`가 그 함수를 문구 출처로 쓴다(hud_tooltip %d행)" % (used + 1), used >= 0)

# ── ⑦ #6 바 옵트인 창이 결혼으로 좁아진다(라이브) ───────────────────────────
func _check_night_bar_optin_window(m: Node) -> void:
	print("⑦ #6 나라카 바 옵트인 창")
	var r = m._resident("bana")
	_check("⑦a 무대: 바나 레코드에 창구 둘이 달려 있다(prompt_extra·shop_key)",
		r != null and r.prompt_extra is Callable and r.shop_key is Callable)
	if r == null:
		return
	var prev_spouse: String = m._spouse_id
	var prev_min: float = m.clock.minutes
	var home_min: int = m.SPOUSE_HOME_MIN["bana"]
	var late: float = float(home_min) + 30.0     # 귀가 뒤 30분 — 종전엔 여기서 열렸다

	m._spouse_id = ""
	m.clock.minutes = late
	m.night_bar.abandon()
	_check("⑦b 미혼: 같은 시각(%02d:%02d)에 창은 **그대로 열린다** — 기저 메카닉 불변(ADR-0008 · 상한 %d분)"
			% [int(late) / 60, int(late) % 60, m._night_bar_optin_close_min()],
		m._night_bar_optin_close_min() == NightBar.CLOSE_MIN and bool(r.shop_key.call()))
	m.night_bar.abandon()

	m._spouse_id = "bana"
	m.clock.minutes = late
	_check("⑦c 결혼 후: 상한이 귀가 시각(%d분)으로 당겨지고 [F]가 거절된다 — 안방에서 원격으로 못 연다"
			% m._night_bar_optin_close_min(),
		m._night_bar_optin_close_min() == home_min and not bool(r.shop_key.call()) \
			and not m.night_bar.is_opened())
	_check("⑦d 광고도 함께 걷힌다 — 창 밖 문구는 「%s」(빈 줄)" % String(r.prompt_extra.call()),
		String(r.prompt_extra.call()) == "")
	m.clock.minutes = float(home_min) - 30.0
	_check("⑦e 좁아진 창 **안**(%02d:%02d)에서는 여전히 열린다 — 막힘 0"
			% [int(m.clock.minutes) / 60, int(m.clock.minutes) % 60],
		String(r.prompt_extra.call()).contains("[F]") and bool(r.shop_key.call()))
	m.night_bar.abandon()
	m._spouse_id = prev_spouse
	m.clock.minutes = prev_min

# ── ⑧ #7 체키가 카페 마감 경계를 못 넘는다(라이브) ──────────────────────────
func _check_cheki_close_boundary(m: Node) -> void:
	print("⑧ #7 체키 ↔ 카페 마감 경계")
	var prev_min: float = m.clock.minutes
	m.clock.minutes = float(Cafe.CLOSE_MIN) - 10.0
	m.cafe.tick(0.0, m.clock.minutes)
	var seat := 0
	var guest: String = "guest_probe"
	var menu: String = MenuCatalog.ids()[0]
	m._offer_cheki(seat, guest, menu)
	m._start_cheki()
	_check("⑧a 무대: 마감 10분 전에 촬영 세션이 실제로 섰다(영업 중 %s · 세션 %s)"
			% [str(m.cafe.is_open()), str(m.cheki != null)], m.cafe.is_open() and m.cheki != null)

	var rev_before: int = m.cafe.today_revenue()
	var cheki_before: int = m.cafe.today_cheki()
	m._on_cafe_closed(rev_before, 0, 0)
	_check("⑧b 마감 핸들러가 세션(%s)과 제안 창(%.1f초)을 그 자리에서 접는다 — 정산 뒤에 장부가 더 오르지 않는다"
			% [str(m.cheki), m._cheki_offer_secs], m.cheki == null and m._cheki_offer_secs == 0.0)
	_check("⑧c 접기에 매출·체키 적립이 따라붙지 않았다(매출 %d→%d냥 · 체키 %d→%d장)"
			% [rev_before, m.cafe.today_revenue(), cheki_before, m.cafe.today_cheki()],
		m.cafe.today_cheki() == cheki_before and m.cafe.today_revenue() == rev_before)

	# 술어 축 — 카페가 실제로 닫힌 뒤에는 창 타이머가 남아 있어도 제안이 안 선다(빈 스툴 앞 RMB).
	m.clock.minutes = float(Cafe.CLOSE_MIN)
	m.cafe.tick(0.0, m.clock.minutes)
	m._offer_cheki(seat, guest, menu)          # 창 타이머만 다시 채운다(마감 뒤 잔여 창의 재현)
	_check("⑧d 무대: 카페가 닫혔는데(%s) 창 타이머는 %.1f초 남아 있다 — 종전엔 이 상태가 최대 %.0f 게임분 지속됐다"
			% [str(not m.cafe.is_open()), m._cheki_offer_secs,
				m._cheki_offer_secs * (GameClock.END_MIN - GameClock.START_MIN) / GameClock.REAL_SECONDS_PER_DAY],
		not m.cafe.is_open() and m._cheki_offer_secs > 0.0)
	_check("⑧e 그 잔여 창으로는 제안이 서지 않는다 — 이미 귀가한 손님의 체키가 시작되지 않는다",
		not m._cheki_offered_at(seat))
	m._clear_cheki_offer()
	m.clock.minutes = prev_min

# ── ⑨ #8 방목 문 알림이 방출 결과를 말한다(문구 함수 라이브 호출) ───────────
func _check_ranch_door_notice(m: Node) -> void:
	print("⑨ #8 방목 문 열기 알림")
	var prev_min: float = m.clock.minutes
	var prev_day: int = m.clock.day
	var building: String = m.ANIMAL_BUILDINGS[0]

	# ㉠ 낮·평온·실제 방출 — 종전 문구 그대로다(회귀 보존).
	var calm_day := -1
	var snow_day := -1
	for d in range(1, 400):
		if calm_day < 0 and Weather.allows_grazing(Weather.weather_for_day(d)):
			calm_day = d
		if snow_day < 0 and not Weather.allows_grazing(Weather.weather_for_day(d)):
			snow_day = d
		if calm_day > 0 and snow_day > 0:
			break
	_check("⑨a 무대: 방목 가능한 날(%d일)과 방목 금지 날(%d일)을 날씨 표에서 파생했다(하드코딩 0)"
			% [calm_day, snow_day], calm_day > 0 and snow_day > 0)
	m.clock.day = calm_day
	m.clock.minutes = 10.0 * 60.0
	var out_day: String = m._ranch_door_open_notice(building, true, 1)
	_check("⑨b 낮·평온·방출 1마리 → 「%s」" % out_day, out_day.contains("방목지로 나간다"))

	# ㉡ 밤 — 실제 동작은 *귀가 통로 열기*라 문구도 그렇게 말한다.
	m.clock.minutes = 22.0 * 60.0
	_check("⑨c 무대: 그 시각의 phase가 «밤»이다(%s)" % m.clock.phase(), m.clock.phase() == "밤")
	var out_night: String = m._ranch_door_open_notice(building, m._release_open_buildings(), 1)
	_check("⑨d 밤 → 「%s」 — 나갔다고 말하지 않는다" % out_night,
		not out_night.contains("방목지로 나간다") and out_night.contains("귀가"))

	# ㉢ 잿눈 — 실내 급여·청소가 필요하다는 다음 행동까지 말한다.
	m.clock.day = snow_day
	m.clock.minutes = 10.0 * 60.0
	_check("⑨e 무대: 그 날은 방목 금지 날씨다(%s)" % Weather.NAMES[Weather.weather_for_day(snow_day)],
		not m._weather_calm())
	var out_snow: String = m._ranch_door_open_notice(building, m._release_open_buildings(), 1)
	_check("⑨f 잿눈 → 「%s」 — 나갔다고 말하지 않는다" % out_snow,
		not out_snow.contains("방목지로 나간다") and out_snow.contains("잿눈"))

	# ㉣ 나갈 짐승이 0마리인 갈래도 갈린다(게이트는 통과했는데 후보가 없는 경우).
	m.clock.day = calm_day
	var out_none: String = m._ranch_door_open_notice(building, true, 0)
	_check("⑨g 방출 후보 0마리 → 「%s」" % out_none, out_none.contains("나갈 짐승은 없다"))
	# 네 문구가 서로 다르다(한 갈래라도 겹치면 이유가 안 갈린다).
	var uniq := {}
	for s in [out_day, out_night, out_snow, out_none]:
		uniq[s] = true
	_check("⑨h 네 갈래가 서로 다른 문장이다(%d/4)" % uniq.size(), uniq.size() == 4)
	m.clock.day = prev_day
	m.clock.minutes = prev_min

# ── ⑩ #9 강변 레인 라우팅 — 걷는 칸이 벽을 안 뚫는다(라이브) ────────────────
func _check_riverside_lane(m: Node) -> void:
	print("⑩ #9 강변 레인 걷기 경로")
	if m._region != RegionCatalog.NARU_VILLAGE:
		m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	var r = m._resident("serena")
	_check("⑩a 무대: 세레나 레코드에 스케줄 %d칸이 있고 마을 구역이 섰다"
			% (r.schedule.size() if r != null else -1),
		r != null and r.schedule.size() >= 2 and m._region == RegionCatalog.NARU_VILLAGE)
	if r == null:
		return
	# 스테이션이 전부 강변대인지부터 확인한다(이 결함의 전제 — 아니면 잴 것이 없다).
	var all_riverside := true
	for st in r.schedule:
		if int(st["tile"].y) < m.RIVERSIDE_ZONE_Y:
			all_riverside = false
	_check("⑩b 무대: 세레나의 스테이션 %d칸이 전부 강변대(y ≥ %d)에 있다"
			% [r.schedule.size(), m.RIVERSIDE_ZONE_Y], all_riverside)

	var bad: Array = []
	var used_corridor := false
	for i in range(r.schedule.size()):
		for j in range(r.schedule.size()):
			if i == j:
				continue
			var a: Vector2i = r.schedule[i]["tile"]
			var b: Vector2i = r.schedule[j]["tile"]
			var spokes: PackedVector2Array = m._road_spokes(a, b, RegionCatalog.NARU_VILLAGE)
			if spokes.is_empty():
				continue
			for t in _path_tiles(m, a, spokes):
				if t.y == m.MAIN_CORRIDOR_Y:
					used_corridor = true
				if m.is_solid(m._grid[t.y][t.x]):
					bad.append(t)
	_check("⑩c 강변끼리의 전 전환에서 걷는 칸이 **SOLID를 한 칸도 안 지난다**(위반 %s) — 종전엔 자기 집 WALL과 광장 돌담을 관통했다"
			% str(bad), bad.is_empty())
	_check("⑩d 그 경로들이 메인 복도(y%d)로 올라가지 않는다 — 강변 산책로(y%d)를 탄다"
			% [m.MAIN_CORRIDOR_Y, m.RIVERSIDE_LANE_Y], not used_corridor)
	# 레인이 갈리는 전환은 다리 스파인에서 환승한다(복도 주민 ↔ 강변 주민이 생기는 날의 계약).
	var north := Vector2i(int(r.schedule[0]["tile"].x), m.MAIN_CORRIDOR_Y - 2)
	var mixed: PackedVector2Array = m._road_spokes(north, r.schedule[0]["tile"], RegionCatalog.NARU_VILLAGE)
	var link_hit := false
	for p in mixed:
		if int(p.x) / m.TILE == int(m.BRIDGE_X[0]):
			link_hit = true
	_check("⑩e 레인이 갈리는 전환은 다리 스파인 열(x%d)에서 환승한다(경유점 %d개)"
			% [int(m.BRIDGE_X[0]), mixed.size()], link_hit and mixed.size() >= 4)

# 경유점 목록을 실제 걷는 칸으로 편다(축 정렬 구간의 타일 열거 — 걷기는 직선 보간이다).
func _path_tiles(m: Node, from_tile: Vector2i, spokes: PackedVector2Array) -> Array:
	var out: Array = []
	var cur := from_tile
	for p in spokes:
		var nxt := Vector2i(int(p.x) / m.TILE, int(p.y) / m.TILE)
		var step := Vector2i(signi(nxt.x - cur.x), signi(nxt.y - cur.y))
		var guard := 0
		while cur != nxt and guard < 200:
			cur += step
			guard += 1
			if cur.x >= 0 and cur.y >= 0 and cur.x < m._grid_w and cur.y < m._grid_h:
				out.append(cur)
		cur = nxt
	return out
