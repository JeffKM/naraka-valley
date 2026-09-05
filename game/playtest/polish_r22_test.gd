extends SceneTree
# ★[폴리시 22회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#7).
#
# 렌즈: R21 diff 리뷰(#0·#1·#2) · SOLID 스포너 불변식 스윕(#3·#4) · 동행체 교차(#5·#6·#7).
#
# 이 배치의 태도 셋.
#   ㉠ **직전 회차가 심은 것이 이 회차의 첫 셋이다.** #0·#1·#2가 전부 R21 봉합의 뒷면이다 —
#      #0은 «바가 너무 일찍 붉다»를 고치다 «영영 안 붉다»로 뒤집힌 자리, #1은 «원장 차집합이 곧
#      pending»이라는 등식이 손저작 앵커에서만 안 성립하는 자리, #2는 R20 ㉢과 R21 base 자[尺]가
#      되감기 사이클에서 충돌하는 자리다. 그래서 셋 다 **옛 계약을 함께 잰다**(새 봉합이 옛
#      계약을 한 톨도 안 무너뜨렸음을 같은 무대에서 보인다).
#   ㉡ **계약과 결함을 가른다.** #2의 절반(미성숙 칸에서 품질군이 임계를 base로 되돌리는 것)은
#      R21이 명시 선언하고 `polish_r21` ①d가 잠근 **계약**이라 되돌리지 않는다 — 결함은 되감기
#      사이클에서 결과가 «무비료 명목보다도 나빠지는» 쪽 하나이고, 계약 쪽은 침묵을 걷어 갚는다.
#   ㉢ **좌표를 옮겨 적지 않는다.** ②의 앵커는 `_home_tree_anchors()`에서, ④의 모서리 칸은
#      판을 훑어서, ⑤의 막힌 실내 칸은 `_player_blocked_at`에게 물어서, ⑦의 창구 좌표는
#      `_f_window_tile` 표에서, ⑧의 상주 칸은 `_resident_tile`에서 판다.
#
# 무엇을 보증하나(번호 = 22회차 헌트 발견 인덱스):
#   ① #0 `_lowest_action_cost`가 네 후보를 **무조건** 접어, 팬닝 스폿도 낚싯대도 없는 판에서도
#      결과가 상수 4였다 — 농사 L0(비용 10) 판의 혼력 4~9 구간 내내 바는 보랏빛인데 `_use_tool`은
#      조용히 되돌아가고 프롬프트는 "혼력 부족 — 집에서 취침"을 띄웠다(HUD ↔ 집행 정면 충돌).
#   ② #1 `_tree_seed_pending_solid`의 «원장 점유 − 물리 등재» 차집합이 **손저작 마당 나무 앵커**를
#      pending SOLID로 오분류했다 — 앵커는 발치 바만 원장에 적히고 캐노피 칸은 의도적 통행
#      가능이라, 퇴로 루프가 멀쩡한 칸을 건너뛰어 성숙목 근처 파종이 이유 없이 상시 거절됐다.
#   ③ #2 `_reseal_need`가 base 자로 재는데 REGROW 되감기의 grown은 **임계의 자**로 적힌 값이라,
#      쿨다운 중 품질 비료를 덮으면 재결실이 명목 cd보다 길어졌다(불사과 7일 → 10일 = 무비료
#      보다 나쁘다). 첫 사이클의 계약(품질군 → base 복귀)은 그대로 두되 침묵만 걷는다.
#   ④ #3 `_would_entrap_player`가 «지금 선 칸의 4방 중 하나가 열렸는가»만 봐, 그 열린 이웃이
#      그 자체로 주머니일 때를 못 봤다 — 기준 칸을 한 칸 옮겨 심는 것만으로 늘봄방에 두 칸짜리
#      영구 소프트락이 성립했다(R19 #15가 «영구 소프트락»이라 적은 그 시나리오 그대로).
#   ⑤ #4 `_restore_location`의 매몰 구제가 **야외 한정**이라, 늘봄방 발밑 넝쿨 구세이브가 로드
#      마다 같은 SOLID 칸으로 복귀했다(판정은 이미 옳고 무대 조건 한 줄이 그것을 버렸다).
#   ⑥ #5 `_refresh_soul_child_body`가 `visible_rule`의 구역 항을 빠뜨린 복제라, 남의 집에서 24:00을
#      맞으면 탄생 컷신·대사 넷 내내 마을 공유 집 안에 동행 혼의 몸이 서 있었다(보정자는 컷신·
#      대화 가드에 막혀 그 구간을 못 돈다). `_fire_soul_birth`엔 형제(`_fire_pet_event`)의 무대
#      술어도 없었다.
#   ⑦ #6 `_is_tree_blocked`만 [F] 창구 표(`_f_window_tile`)를 안 봐, 삽사리·물그릇 칸에 밑동을
#      세울 수 있었다 — 개가 앉은 칸이 통행 불가가 되고 나무가 개를 덮는데 **orchard엔 제거
#      API가 0**이라 되돌릴 창구가 없다.
#   ⑧ #7 `_can_place_pot`만 `_resident_tile` 항이 없어, 동행 혼·배우자 상주 칸의 화분이 RMB
#      사다리에서 대화에 영영 먹혔다(프롬프트도 같은 순서라 원인 단서조차 0).
#
# 판정: #0·#1·#3·#4·#5·#6·#7 CONFIRMED(전부 봉합) · #2 = **부분 CONFIRMED**(되감기 사이클만 결함 ·
#   미성숙 칸 역행은 R21 계약이라 REFUTED, 대신 침묵을 알림으로 갚았다). REFUTED 전량·DUP·
#   OWNER-DECISION 0건.
#
# 봉합 축(근거 전문은 커밋 본문·각 함수 머리말):
#   · #0 = 후보마다 **소유자에게 자리·보유를 묻는다**(`_has_any_rod` · `panning.count(_region)` ·
#          `_stored_anywhere(PICKAXE)`). 농사만 무조건 — 잡초·목축·과수까지 쓰는 바닥값이다.
#   · #1 = 차집합에서 `_home_tree_anchor_set()`을 뺀다(충돌을 세울 때 쓰는 그 함수 그대로).
#   · #2 = `harvest`의 REGROW 갈래가 `regrown` 표식을 세우고, `_reseal_need`가 그 사이클에서는
#          임계를 안 건드린다(R20 ㉢의 대칭: 이득이 없으니 손해도 없다) + 잔여가 실제로 늘어난
#          도포만 화면이 말한다(집행 0이면 알리지 않는다).
#   · #3 = 4방 1스텝 → **상한(ENTRAP_FREE_MIN)에서 끊는 폭 우선 탐색**. 좁히기만 한다.
#   · #4 = 실내 갈래 추가 — 폴백은 야외 스폰이 아니라 그 방의 `in_tile`(카메라가 방에 묶인다).
#   · #5 = 헬퍼가 레코드의 `visible_rule`을 그대로 부른다 + `_fire_soul_birth`에 HOME 술어.
#   · #6 = `_is_tree_blocked`에 `_f_window_tile(t)` 한 줄(좌표 복제 0).
#   · #7 = `_can_place_pot`에 `_resident_tile(t)` 한 줄 + 이미 놓인 화분을 위한 **한 프레임 양보**
#          (`_pot_harvest_yield` — 입력·프롬프트 둘 다).
#
# 하중 검증(**실측** — 봉합을 되돌리면 뜨는 red를 그대로 옮겨 적는다):
#   #0 후보 게이트 셋 삭제(무조건 접기로 복귀)      → ①b·①d red(눈금이 상수 4로 굳는다)
#   #1 차집합의 anchors 필터 삭제                    → ②c red(앵커가 pending 1칸으로 실린다)
#   #2 `_reseal_need`의 `regrown` 가지 삭제          → ③d·③e·③f red(잔여 7 → 10 · cd일에 안 열린다)
#   #2 `harvest`의 표식 세우기 삭제                  → ③d·③e·③f red(같은 값·같은 이유)
#   #2 비료 갈래 알림 삭제                           → ③i red(③j는 그대로 초록 = 침묵 계약 불변)
#   #3 BFS를 4방 1스텝으로 되돌림                    → ④c red(주머니가 통과한다)
#   #4 실내 elif 삭제                                → ⑤c red((8,67) 막힌 칸으로 복귀)
#   #5 헬퍼를 `visible = _soul_born`으로 되돌림      → ⑥b red(마을에서 몸이 선다)
#   #5 `_fire_soul_birth` 무대 술어 삭제             → ⑥d red(남의 집에서 깃든다)
#   #6 `_f_window_tile` 줄 삭제                      → ⑦b·⑦c red(삽사리 칸에 3×3이 선다)
#   #7 `_resident_tile` 줄 삭제                      → ⑧b·⑧d red
#   #7 양보 두 자리 삭제                             → ⑧f red
#
# ★하중 검증에서 배운 것 둘.
#   · **①c는 이 파괴의 red-catcher가 아니다.** 게이트를 통째로 걷으면 눈금이 상수 4로 굳는데
#     ①c가 기대하는 값도 4(후킹 하한)라 초록으로 남는다 — 「보유하면 내려간다」를 재는 항이지
#     「보유가 없으면 안 내려간다」를 재는 항이 아니고, 후자가 ①b·①d다. 두 방향을 한 항으로
#     묶으면 하중이 반만 걸린다(R21이 «빈 문자열끼리의 일치는 공허 통과»로 배운 것의 값 판).
#   · **⑧f만 구조 단언이다.** #7의 양보는 «입력 사다리의 어느 자리에서 물었는가»가 곧 계약이라
#     거동(⑧e = 술어 자체)과 배선(⑧f = `_process`의 두 자리)이 서로를 못 대신한다 — 양보 호출을
#     걷으면 술어는 멀쩡히 답하므로 ⑧e가 초록으로 남는다. 그래서 둘을 나란히 둔다.
#
# 실행: ./run_tests.sh polish_r22   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _src: PackedStringArray = PackedStringArray()

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

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

# ── 소스 스캔 헬퍼(polish_r7~r21 관례 — 니들은 반드시 함수 안에서 센다) ──────
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _count_in_func(lines: PackedStringArray, fn_needle: String, needle: String) -> int:
	var head := -1
	for i in range(lines.size()):
		if lines[i].begins_with(fn_needle):
			head = i
			break
	if head < 0:
		return -1
	var n := 0
	for i in range(head + 1, lines.size()):
		if lines[i].begins_with("func ") or lines[i].begins_with("static func "):
			break
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			n += 1
	return n

func _feed_has(m: Node, needle: String) -> bool:
	if m.notice_feed == null:
		return false
	for e in m.notice_feed._items:
		if String(e.get("text", "")).contains(needle):
			return true
	return false

func _feed_clear(m: Node) -> void:
	if m.notice_feed != null:
		m.notice_feed._items.clear()

# 아이템 1개를 넣고 그 슬롯을 손에 든다(gift_test의 그 관례).
func _hold(m: Node, id: String) -> bool:
	if not m.inventory.add_item(id, 1) and not m.inventory.has_item(id):
		return false
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return m.inventory.selected_id() == id
	return false

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R22 회귀 — 배치 A(#0~#7) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_check("무대 전제: main(%d행)을 읽었다(부정 단언 공허 통과 방지)" % _src.size(), _src.size() > 1000)

	_check_regrow_reseal()          # ③ — 순수 FarmField(무대 불요)

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)

	_check_low_action_cost(m)       # ①
	_check_seed_pending_anchor(m)   # ②
	_check_fertilize_notice(m)      # ③ 뒷절(알림)
	_check_entrap_connectivity(m)   # ④
	_check_soul_child_body(m)       # ⑥
	_check_tree_window_tiles(m)     # ⑦
	_check_pot_resident_tile(m)     # ⑧
	_check_indoor_restore(m)        # ⑤ — `_indoor`를 갈아 두므로 맨 끝

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 혼력 바 눈금 = **지금 낼 수 있는** 가장 싼 동사 ─────────────────────
# 값은 한 톨도 안 적는다: 팬닝 상수는 PanningSpots에서, 후킹 하한은 FishingSession에서, 농사
# 비용은 main의 그 함수에서 판다. 무대는 «낚싯대 0 · 곡괭이 0 · 이 구역 스폿 0»으로 만든다.
func _check_low_action_cost(m: Node) -> void:
	print("① #0 혼력 바 취침 눈금 ↔ 보유·자리")
	var farm_cost: int = m._farming_energy_cost()
	var pan_cost: int = PanningSpots.PAN_ENERGY
	var hook_cost: int = FishingSession.min_hook_energy(m._fishing_mods())
	_check("①a 무대: 팬닝 %d · 후킹 하한 %d 둘 다 농사 %d보다 싸다 — 종전엔 결과가 늘 이 최솟값으로 접혔다"
			% [pan_cost, hook_cost, farm_cost],
		pan_cost < farm_cost and hook_cost < farm_cost)

	var had_pick: bool = m.inventory.has_item(ItemCatalog.PICKAXE)
	if had_pick:
		m.inventory.remove_item(ItemCatalog.PICKAXE, 1)
	var spots_backup: Dictionary = m.panning._spots.duplicate(true)
	m.panning._spots = {}
	var indoor0: String = m._indoor
	m._indoor = ""
	_check("①b' 무대 전제가 실제로 섰다 — 낚싯대 %s · 곡괭이 %s · 이 무대 스폿 %d개"
			% [str(m._has_any_rod()), str(m._stored_anywhere(ItemCatalog.PICKAXE)),
				m.panning.count(m._region)],
		not m._has_any_rod() and not m._stored_anywhere(ItemCatalog.PICKAXE)
			and m.panning.count(m._region) == 0)
	_check("①b 아무것도 없으면 눈금은 **농사 비용**(%d)이다 — 낼 수 없는 동사는 후보가 아니다"
			% m._lowest_action_cost(), m._lowest_action_cost() == farm_cost)

	# 낚싯대를 가지면(상자에 넣어 둔 것도 «가진 것» — `_has_any_rod`의 그 술어) 눈금이 내려간다.
	m.inventory.add_item(ItemCatalog.ROD_T1, 1)
	var with_rod: int = m._lowest_action_cost()
	_check("①c 낚싯대를 가지면 눈금이 후킹 하한(%d)으로 내려간다 — 보유가 판정에 실제로 든다(%d → %d)"
			% [hook_cost, farm_cost, with_rod], with_rod == hook_cost and with_rod < farm_cost)
	m.inventory.remove_item(ItemCatalog.ROD_T1, 1)

	# 이 무대에 오늘 스폿이 깔리면 팬닝이 후보가 되고, 실내로 들어가면 겨눌 수조차 없어 빠진다.
	m.panning._spots = {m._region: {Vector2i(1, 1): {}}}
	var outdoor_pan: int = m._lowest_action_cost()
	m._indoor = "집"
	var indoor_pan: int = m._lowest_action_cost()
	m._indoor = ""
	_check("①d 이 무대 스폿 1개 → 눈금 %d(팬닝 %d) · 실내로 들어가면 다시 %d(농사)로 돌아온다"
			% [outdoor_pan, pan_cost, indoor_pan],
		outdoor_pan == pan_cost and indoor_pan == farm_cost)

	# 화면이 읽는 그 필드에 실제로 흘러드는가(HUD 갱신 한 묶음 — R21 #19가 세운 배선).
	m.panning._spots = {}
	m._refresh_clock_hud()
	_check("①e 화면이 읽는 필드에 그 값이 흘러든다 — `vitals.low_cost` %d == `_lowest_action_cost()` %d"
			% [m.vitals.low_cost, m._lowest_action_cost()],
		m.vitals != null and m.vitals.low_cost == m._lowest_action_cost())

	m.panning._spots = spots_backup
	m._indoor = indoor0
	if had_pick:
		m.inventory.add_item(ItemCatalog.PICKAXE, 1)

# ── ② #1 pending 차집합에서 손저작 앵커를 뺀다 ──────────────────────────────
func _check_seed_pending_anchor(m: Node) -> void:
	print("② #1 자체 파종 pending ↔ 마당 나무 앵커")
	var anchor := Vector2i(-1, -1)
	var stand := Vector2i(-1, -1)
	for a in m._home_tree_anchors():
		var at: Vector2i = a
		if not m.tree_ledger.is_occupied(RegionCatalog.HOME, at):
			continue
		for d in DIRS:
			var n: Vector2i = at + d
			if not m._player_blocked_at(n):
				anchor = at
				stand = n
				break
		if anchor.x >= 0:
			break
	_check("②a 무대: 점유된 손저작 앵커 %s와 그 옆 걸을 수 있는 칸 %s를 판에서 찾았다(좌표 하드코딩 0)"
			% [anchor, stand], anchor.x >= 0 and stand.x >= 0)
	if anchor.x < 0:
		return
	_check("②b 앵커 칸 자체는 **통행 가능**이다 — 발치 바만 물리에 서므로 캐노피는 걸어 나갈 수 있다(`_player_blocked_at` %s)"
			% str(m._player_blocked_at(anchor)), not m._player_blocked_at(anchor))
	# 차집합의 두 항이 앵커에서 동시에 참이다 = 필터가 없으면 반드시 오분류된다(근거).
	_check("②b' 근거: 앵커는 원장 점유(%s)이면서 물리 원장 미등재(%s)라, 필터가 없으면 차집합이 반드시 담는다"
			% [str(m.tree_ledger.is_occupied(RegionCatalog.HOME, anchor)),
				str(not m._prop_blocked_tiles.has(anchor))],
		m.tree_ledger.is_occupied(RegionCatalog.HOME, anchor)
			and not m._prop_blocked_tiles.has(anchor))
	var pos0: Vector2 = m.player.position
	m.player.position = m._tile_center_px(stand)
	var pending: Dictionary = m._tree_seed_pending_solid()
	_check("②c 그런데 pending에는 안 실린다 — 「곧 설 SOLID」가 아니라 이미 선 나무의 앵커다(pending %d칸 · 앵커 포함 %s)"
			% [pending.size(), str(pending.has(anchor))], not pending.has(anchor))
	m.player.position = pos0

# ── ③ #2 되감기 사이클에는 base라는 자를 못 댄다 ────────────────────────────
# 작물·계수·쿨다운을 전부 카탈로그에서 판다(REGROW 중 base가 가장 긴 것 = 정수 임계에서 차이가 보인다).
func _check_regrow_reseal() -> void:
	print("③ #2 REGROW 쿨다운 ↔ 비료 교체")
	var crop := ""
	var base := -1
	for id in CropCatalog.ids():
		if CropCatalog.growth_mode(String(id)) != "REGROW":
			continue
		var g := CropCatalog.growth_days(String(id))
		if g > base:
			base = g
			crop = String(id)
	var cd: int = CropCatalog.regrow_cooldown(crop) if crop != "" else -1
	var fh := FertilizerCatalog.speed_factor(FertilizerCatalog.FERT_HYPER)
	_check("③a 무대: REGROW 중 가장 긴 %s(base %d · cd %d) · 하이퍼 ×%.2f"
			% [CropCatalog.name_of(crop), base, cd, fh],
		crop != "" and base > cd and cd > 0 and fh < 1.0)
	if crop == "":
		return

	var f := FarmField.new()
	var t := Vector2i(3, 3)
	f.hoe(t)
	f.fertilize(t, FertilizerCatalog.FERT_HYPER)
	f.plant(t, crop)
	var need: int = f.effective_growth_days(t)
	for i in range(need):
		f.water(t)
		f.advance_day()
	var got: String = f.harvest(t)
	_check("③b R20 #6 계약 보존: 되감기는 **그 칸의 임계** 기준 그대로다 — grown %d(= 임계 %d − cd %d) · 넝쿨 유지 %s"
			% [f.grown_days_of(t), need, cd, str(f.is_planted(t))],
		got == crop and f.is_planted(t) and f.grown_days_of(t) == need - cd)
	var left_before: int = f.effective_growth_days(t) - f.grown_days_of(t)
	_check("③c 쿨다운 잔여가 명목 cd(%d) 그대로다 — 비료의 이득은 첫 결실에서 이미 받았다" % cd,
		left_before == cd)
	# base 자를 그대로 대면 얼마가 되는지 테스트가 직접 계산한다 — ③d가 공허 초록이 아님을 보인다.
	var naive_left: int = base - f.grown_days_of(t)
	_check("③c' 근거: base 자로 재면 잔여가 %d일이 된다 — 무비료 명목 쿨다운 %d일보다 **길다**(어떤 순수 경로보다 나쁘다)"
			% [naive_left, cd], naive_left > cd)
	f.fertilize(t, FertilizerCatalog.FERT_DELUXE)
	var left_after: int = f.effective_growth_days(t) - f.grown_days_of(t)
	_check("③d 쿨다운 중 디럭스를 덮어도 잔여는 %d일 그대로다(%d → %d) — 이득이 없으니 손해도 없다"
			% [cd, left_before, left_after], left_after == cd)
	_check("③d' 품질표는 그래도 갈린다 — 비료 필드는 %s(교체 자체는 성립한다 · XOR 문법 불변)"
			% FertilizerCatalog.state_of(f.fertilizer_of(t)),
		FertilizerCatalog.state_of(f.fertilizer_of(t)) == FertilizerCatalog.STATE_DELUXE)
	# 실제로 그날 수만큼 다시 열리는가 — 잔여를 «믿는» 대신 날을 굴려 확인한다.
	for i in range(cd - 1):
		f.water(t)
		f.advance_day()
	var mature_early: bool = f.is_mature(t)
	f.water(t)
	f.advance_day()
	_check("③e cd−1일(%d)엔 미성숙(%s) · 정확히 cd일에 다시 성숙(%s) — 명목 쿨다운이 실제로 선다"
			% [cd - 1, str(mature_early), str(f.is_mature(t))],
		not mature_early and f.is_mature(t))

	# 세이브 왕복 — 표식이 실려야 로드한 판에서도 같은 계약이 선다.
	var u := Vector2i(5, 5)
	f.hoe(u)
	f.fertilize(u, FertilizerCatalog.FERT_HYPER)
	f.plant(u, crop)
	var need_u: int = f.effective_growth_days(u)
	for i in range(need_u):
		f.water(u)
		f.advance_day()
	f.harvest(u)
	var g2 := FarmField.new()
	g2.load_save(f.to_save())
	var left_g_before: int = g2.effective_growth_days(u) - g2.grown_days_of(u)
	g2.fertilize(u, FertilizerCatalog.FERT_DELUXE)
	var left_g_after: int = g2.effective_growth_days(u) - g2.grown_days_of(u)
	_check("③f 세이브 왕복 뒤에도 같다 — 로드한 판의 잔여 %d → %d(명목 %d)"
			% [left_g_before, left_g_after, cd],
		left_g_before == cd and left_g_after == cd)

	# 표식은 심는 순간 꺼진다 — 다시 심으면 그 칸은 언제나 첫 사이클이다.
	f.remove_plant(t)
	f.fertilize(t, FertilizerCatalog.FERT_HYPER)
	f.plant(t, crop)
	f._tiles[t]["grown_days"] = 1
	f.fertilize(t, FertilizerCatalog.FERT_DELUXE)
	_check("③g 표식은 심기에서 꺼진다 — 다시 심은 칸에 디럭스를 덮으면 임계가 base(%d)로 돌아온다(%d)"
			% [base, f.effective_growth_days(t)], f.effective_growth_days(t) == base)

	# R21 ①d 계약 보존 — 첫 사이클 미성숙 칸에서 품질군은 여전히 base로 되돌린다(2군 XOR).
	var v := Vector2i(7, 7)
	f.hoe(v)
	f.fertilize(v, FertilizerCatalog.FERT_HYPER)
	f.plant(v, crop)
	var nominal_hyper: int = f.effective_growth_days(v)
	f._tiles[v]["grown_days"] = 1
	f.fertilize(v, FertilizerCatalog.FERT_DELUXE)
	_check("③h R21 ①d 계약 보존: 첫 사이클 미성숙 칸은 하이퍼 %d → 디럭스 %d(= base) — «−성숙 + 디럭스» 동시 성립 불가"
			% [nominal_hyper, f.effective_growth_days(v)],
		nominal_hyper < base and f.effective_growth_days(v) == base)
	f.free()
	g2.free()

# ── ③ 뒷절 #2 그 대가를 화면이 말한다(집행 0이면 알리지 않는다) ──────────────
func _check_fertilize_notice(m: Node) -> void:
	print("③ #2 잔여가 늘어난 도포 = 알림")
	var crop := ""
	var base := -1
	for id in CropCatalog.ids():
		var g := CropCatalog.growth_days(String(id))
		if g > base:
			base = g
			crop = String(id)
	var t := Vector2i(-1, -1)
	for tile in m.farm.tilled_tiles():
		t = tile
		break
	if t.x < 0:
		for y in range(m._grid.size()):
			for x in range(m._grid[y].size()):
				var c := Vector2i(x, y)
				if m._is_farmable(c) and m.farm.hoe(c):
					t = c
					break
			if t.x >= 0:
				break
	_check("③i' 무대: 밭 칸 %s에 %s(base %d)를 성장촉진으로 심는다" % [t, CropCatalog.name_of(crop), base],
		t.x >= 0 and crop != "")
	if t.x < 0:
		return
	m.farm.remove_plant(t)
	m.farm.fertilize(t, ItemCatalog.FERT_SPEED)
	m.farm.plant(t, crop)
	m.farm._tiles[t]["grown_days"] = 1
	var before: int = m.farm.effective_growth_days(t)
	m._target = t
	_feed_clear(m)
	var held: bool = _hold(m, ItemCatalog.FERT_DELUXE)
	m._use_tool()
	var after: int = m.farm.effective_growth_days(t)
	_check("③i 잔여가 늘어난 도포는 화면이 말한다 — 임계 %d → %d(+%d) · 피드에 그 줄이 있다(손에 든 것 %s)"
			% [before, after, after - before, str(held)],
		held and after > before and _feed_has(m, "성숙일"))
	# 집행 0이면 알리지 않는다 — 무비료 칸에 품질 비료를 덮으면 임계가 안 움직인다.
	var t2 := Vector2i(-1, -1)
	for y in range(m._grid.size()):
		for x in range(m._grid[y].size()):
			var c := Vector2i(x, y)
			if c != t and m._is_farmable(c) and m.farm.hoe(c):
				t2 = c
				break
		if t2.x >= 0:
			break
	if t2.x < 0:
		return
	m.farm.plant(t2, crop)
	m.farm._tiles[t2]["grown_days"] = 1
	var b2: int = m.farm.effective_growth_days(t2)
	m._target = t2
	_feed_clear(m)
	_hold(m, ItemCatalog.FERT_QUALITY)
	m._use_tool()
	var a2: int = m.farm.effective_growth_days(t2)
	_check("③j 안 늘어난 도포는 조용하다 — 무비료 칸의 임계 %d → %d(불변) · 그 줄 없음 %s"
			% [b2, a2, str(not _feed_has(m, "성숙일"))],
		a2 == b2 and not _feed_has(m, "성숙일"))

# ── ④ #3 매몰 가드가 «주머니»를 본다(1스텝 → 연결성) ────────────────────────
# 좌표를 안 적는다: **열린 이웃이 정확히 둘인 칸**을 판에서 찾고, 그중 한쪽 이웃의 나머지 퇴로를
# pending으로 막아 «열려 있지만 주머니인» 자리를 만든다. 종전 규칙(4방 중 하나만 열리면 통과)에
# 정확히 걸리는 형태다.
func _check_entrap_connectivity(m: Node) -> void:
	print("④ #3 매몰 가드 = 연결성")
	var here := Vector2i(-1, -1)
	var side := Vector2i(-1, -1)
	var cand := Vector2i(-1, -1)
	for y in range(m._grid.size()):
		for x in range(m._grid[y].size()):
			var c := Vector2i(x, y)
			if m._player_blocked_at(c):
				continue
			var open: Array[Vector2i] = []
			for d in DIRS:
				if not m._player_blocked_at(c + d):
					open.append(c + d)
			if open.size() != 2:
				continue
			here = c
			side = open[0]
			cand = open[1]
			break
		if here.x >= 0:
			break
	_check("④a 무대: 열린 이웃이 정확히 둘인 칸 %s를 판에서 찾았다(옆 %s · 후보 %s)"
			% [here, side, cand], here.x >= 0)
	if here.x < 0:
		return
	var pos0: Vector2 = m.player.position
	m.player.position = m._tile_center_px(here)
	var pending: Dictionary = {}
	for d in DIRS:
		var n: Vector2i = side + d
		if n != here and not m._player_blocked_at(n):
			pending[n] = true
	_check("④b 1스텝 규칙이었다면 통과했을 자리다 — 옆 칸 %s가 열려 있고(%s) pending도 아니다(%s)"
			% [side, str(not m._player_blocked_at(side)), str(not pending.has(side))],
		not m._player_blocked_at(side) and not pending.has(side))
	_check("④c 그런데 그 옆 칸에서 더 나갈 곳이 없다 → 후보를 세우면 주머니다(거절 %s · 막힌 퇴로 %d칸)"
			% [str(m._would_entrap_player(cand, pending)), pending.size()],
		m._would_entrap_player(cand, pending))
	_check("④d 과잉 거절 0 — 같은 후보라도 옆 칸 퇴로가 살아 있으면 허용된다(%s)"
			% str(m._would_entrap_player(cand, {})), not m._would_entrap_player(cand, {}))
	_check("④e ㉠은 그대로다 — 발밑은 여전히 즉시 매몰(%s)" % str(m._would_entrap_player(here, {})),
		m._would_entrap_player(here, {}))
	# 마당 한복판(열린 칸이 상한을 넘게 이어지는 자리)에서는 넷 다 허용된다 — 코지 톤 보존.
	m.player.position = m._tile_center_px(RegionCatalog.spawn_of(RegionCatalog.HOME))
	var open_all := true
	for d in DIRS:
		var n: Vector2i = m._player_tile() + d
		if not m._player_blocked_at(n) and m._would_entrap_player(n, {}):
			open_all = false
	_check("④f 넓은 마당에서는 4방 어느 칸도 안 막힌다 — 상한(%d칸)까지 이어지면 주머니가 아니다"
			% m.ENTRAP_FREE_MIN, open_all)
	m.player.position = pos0

# ── ⑥ #5 동행 혼의 몸은 레코드의 가시성 규칙 하나에서 판다 ──────────────────
func _check_soul_child_body(m: Node) -> void:
	print("⑥ #5 동행 혼 몸 ↔ 무대")
	var r = m._resident(m.SOUL_CHILD_RID)
	_check("⑥a 무대: 동행 혼 레코드와 몸이 있고 가시성 훅이 유효하다(%s)"
			% str(r != null and r.node != null and r.visible_rule.is_valid()),
		r != null and r.node != null and r.visible_rule.is_valid())
	if r == null or r.node == null:
		return
	var born0: bool = m._soul_born
	var region0: String = m._region
	m._soul_born = true
	m._region = RegionCatalog.NARU_VILLAGE
	m._refresh_soul_child_body()
	var vis_village: bool = r.node.visible
	m._region = RegionCatalog.HOME
	m._refresh_soul_child_body()
	var vis_home: bool = r.node.visible
	_check("⑥b 깃든 뒤에도 **남의 구역에서는 몸이 안 선다** — 마을 %s · 안식 %s(훅의 두 항을 그대로 든다)"
			% [str(vis_village), str(vis_home)], not vis_village and vis_home)
	_check("⑥c 근거: 훅 자신도 같은 답을 낸다 — 헬퍼와 보정자가 두 값을 낼 길이 없다(%s)"
			% str(r.visible_rule.call()), r.visible_rule.call() == vis_home)

	# 탄생 자체도 무대를 가린다(형제 `_fire_pet_event`의 그 항).
	m._soul_born = false
	m._soul_due_day = 1
	m._soul_birth_armed = true
	m._region = RegionCatalog.NARU_VILLAGE
	m._fire_soul_birth()
	var born_village: bool = m._soul_born
	m._soul_birth_armed = true
	m._region = RegionCatalog.HOME
	m._fire_soul_birth()
	var born_home: bool = m._soul_born
	_check("⑥d 남의 집에서 24:00을 맞아도 그 밤엔 안 깃든다(%s) — 안식에서는 그대로 깃든다(%s · 접힘은 다음 아침 재예약)"
			% [str(born_village), str(born_home)], not born_village and born_home)
	# 원복 — 컷신·예약·래치를 전부 되돌린다(뒤 절이 깨끗한 판을 본다).
	if m.cutscene != null:
		m._end_cutscene()
	_dismiss_dialogue(m)
	m._soul_body_pending = false
	m._soul_birth_armed = false
	m._soul_born = born0
	m._soul_due_day = 0
	m._region = region0
	m._refresh_soul_child_body()

# ── ⑦ #6 [F] 창구 좌표는 나무에도 성역이다 ──────────────────────────────────
func _check_tree_window_tiles(m: Node) -> void:
	print("⑦ #6 과수 배치 ↔ [F] 창구 표")
	var indoor0: String = m._indoor
	m._indoor = ""
	var pet: Vector2i = m.PET_TILE
	var bowl: Vector2i = m.PET_BOWL_TILE
	_check("⑦a 무대: 삽사리 %s·물그릇 %s은 [F] 창구 표에 있고(%s/%s) 지형은 비-SOLID다(%s/%s) — 종전 술어를 한 줄도 안 건드렸다"
			% [pet, bowl, str(m._f_window_tile(pet)), str(m._f_window_tile(bowl)),
				str(not m.is_solid(m._grid[pet.y][pet.x])), str(not m.is_solid(m._grid[bowl.y][bowl.x]))],
		m._region == RegionCatalog.HOME and m._f_window_tile(pet) and m._f_window_tile(bowl)
			and not m.is_solid(m._grid[pet.y][pet.x]) and not m.is_solid(m._grid[bowl.y][bowl.x]))
	_check("⑦b 그 칸들은 나무에 막힌 칸이다 — 삽사리 %s · 물그릇 %s · 우편함 %s"
			% [str(m._is_tree_blocked(pet)), str(m._is_tree_blocked(bowl)),
				str(m._is_tree_blocked(m.MAILBOX_TILE))],
		m._is_tree_blocked(pet) and m._is_tree_blocked(bowl) and m._is_tree_blocked(m.MAILBOX_TILE))
	var blocked_cb := Callable(m, "_is_tree_blocked")
	_check("⑦c 그래서 3×3 심기가 거절된다 — `can_plant(%s)` %s(되돌릴 창구가 orchard에 0이라 배치가 유일한 관문)"
			% [pet, str(m.orchard.can_plant(pet, blocked_cb))],
		not m.orchard.can_plant(pet, blocked_cb))
	# 과잉 거절 0 — 표 밖의 마당 칸은 여전히 심긴다.
	var free_anchor := Vector2i(-1, -1)
	var zone: Rect2i = m.ORCHARD_ZONE_RECT
	for y in range(zone.position.y, zone.end.y):
		for x in range(zone.position.x, zone.end.x):
			var a := Vector2i(x, y)
			if m.orchard.can_plant(a, blocked_cb):
				free_anchor = a
				break
		if free_anchor.x >= 0:
			break
	_check("⑦d 과잉 거절 0 — 과수원 구역에 여전히 심을 수 있는 앵커가 있다(%s)" % free_anchor,
		free_anchor.x >= 0)
	m._indoor = indoor0

# ── ⑧ #7 화분은 주민 상주 칸을 피한다(+ 이미 놓인 것은 한 프레임 양보) ───────
func _check_pot_resident_tile(m: Node) -> void:
	print("⑧ #7 화분 배치 ↔ 주민 상주 칸")
	var soul: Vector2i = m.SOUL_CHILD_TILE
	_check("⑧a 무대: 동행 혼 상주 칸 %s는 **깃들기 전에도** 주민 칸이다(스케줄이 부팅부터 든다 · %s)"
			% [soul, str(m._resident_tile(soul))], m._resident_tile(soul))
	var indoor0: String = m._indoor
	m._indoor = "집"
	_check("⑧b 그 칸엔 화분을 못 놓는다(%s) — 그 칸의 [우클릭]은 남의 것이다"
			% str(m._can_place_pot(soul)), not m._can_place_pot(soul))
	# 과잉 거절 0 — 같은 방의 다른 바닥 칸은 그대로 놓인다.
	var free_tile := Vector2i(-1, -1)
	var room: Rect2i = m.home_house_rect()
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var c := Vector2i(x, y)
			if m._can_place_pot(c):
				free_tile = c
				break
		if free_tile.x >= 0:
			break
	_check("⑧c 과잉 거절 0 — 같은 방 다른 칸엔 그대로 놓인다(%s)" % free_tile, free_tile.x >= 0)
	# 형제 배치 가드 셋과 대칭인가(각 함수 **안**에서 센다 — 파일 전역 카운트 아님).
	var sibs := {"func _can_place_crab_pot": 0, "func _can_place_furnace": 0,
		"func _can_place_crystalarium": 0, "func _can_place_pot": 0}
	var missing: Array[String] = []
	for fn in sibs.keys():
		if _count_in_func(_src, String(fn), "_resident_tile(") <= 0:
			missing.append(String(fn))
	_check("⑧d 배치 가드 넷이 같은 술어를 든다 — 빠진 함수: %s" % [missing],
		missing.is_empty())

	# 이미 놓인 화분의 탈출구 — 다 자랐을 때만 한 프레임 양보한다.
	m.garden_pot.place(soul)
	var crop := ""
	for id in CropCatalog.ids():
		crop = String(id)
		break
	m.garden_pot.plant(soul, crop)
	var yield_young: bool = m._pot_harvest_yield(soul)
	m.garden_pot._pots[soul]["grown_days"] = CropCatalog.growth_days(crop)
	var yield_ripe: bool = m._pot_harvest_yield(soul)
	_check("⑧e 이미 놓인 화분은 **다 자랐을 때만** 대화보다 먼저 받는다 — 자라는 중 %s · 다 자란 뒤 %s"
			% [str(yield_young), str(yield_ripe)], not yield_young and yield_ripe)
	_check("⑧f 입력과 화면이 같은 순서다 — `_process`가 그 양보를 %d자리에서 든다(입력·프롬프트)"
			% _count_in_func(_src, "func _process", "_pot_harvest_yield("),
		_count_in_func(_src, "func _process", "_pot_harvest_yield(") >= 2)
	m.garden_pot.remove(soul)
	m._indoor = indoor0

# ── ⑤ #4 매몰 구제는 실내에서도 선다(폴백 = 그 방의 입장 칸) ─────────────────
func _check_indoor_restore(m: Node) -> void:
	print("⑤ #4 실내 복원 좌표 구제")
	var in_tile: Vector2i = m._buildings["집"]["in_tile"]
	var room: Rect2i = m.home_house_rect()
	var blocked := Vector2i(-1, -1)
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var c := Vector2i(x, y)
			if m._player_blocked_at(c):
				blocked = c
				break
		if blocked.x >= 0:
			break
	_check("⑤a 무대: 집 실내 둘레에서 막힌 칸 %s를 판에서 찾았다(입장 칸 %s)" % [blocked, in_tile],
		blocked.x >= 0)
	if blocked.x < 0:
		return
	# 야외 갈래는 불변 — 안 막힌 칸은 그대로 그 칸에 복원된다.
	m._restore_location({"region": RegionCatalog.HOME, "indoor": "집", "player_tile": in_tile})
	_check("⑤b 안 막힌 실내 좌표는 그대로 복원된다(%s) — 구제는 «막힌 칸»에만 든다" % m._player_tile(),
		m._player_tile() == in_tile)
	m._restore_location({"region": RegionCatalog.HOME, "indoor": "집", "player_tile": blocked})
	_check("⑤c 막힌 실내 좌표는 **그 방의 입장 칸**으로 구제된다 — 복원 결과 %s(구역 스폰 %s이 아니다)"
			% [m._player_tile(), RegionCatalog.spawn_of(RegionCatalog.HOME)],
		m._player_tile() == in_tile and m._indoor == "집")
	_check("⑤c' 근거: 그 좌표는 지금 판에서 실제로 막힌 칸이다(%s) — 구제가 헛돌지 않았다"
			% str(m._player_blocked_at(blocked)), m._player_blocked_at(blocked))
	m._indoor = ""
