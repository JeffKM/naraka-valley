extends SceneTree
# ★[폴리시 27회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#10).
#
# 렌즈: R26 diff 리뷰(#0) · 낡은 증인 전수(#1~#4) · 건물 표 소비처(#5·#6) ·
#       백필 상호작용 행렬(#7~#9) · 확률 질량 보존(#10).
#
# 이 배치의 태도 넷.
#   ㉠ **항의 «폭»은 항의 내용만큼 계약이다.** #0은 R26 #5가 앵커 한 칸짜리 결함을 3×3 전수
#      평가 술어에 넣어, 캐노피 여덟 칸까지 조용히 거절하던 자리다. 같은 파일이 정확히 그
#      함정을 두 번 적어 뒀다 — `_orchard_trunk_at` 머리말(「캐노피는 겹침이 아니다」)과 R19 #17
#      (「3×3 전수 평가에 넣으면 … 막아야 하는 것도 밑동 하나다」). 봉합은 항을 지우는 것이
#      아니라 **맞는 폭의 자리로 옮기는 것**이다.
#   ㉡ **증인이 낡으면 계약이 아니라 증인을 고친다 — 단, 계약이 옳은지 먼저 감별한다.**
#      #1~#4는 전부 프로덕션이 옳고 니들만 뒤처진 자리였다(#1·#3 = R25 #14의 축 전환,
#      #2 = R24 #19의 두 갈래 분기). #4만 결이 달라 «공허 초록»이었다 — 라벨이 주장하는 계약
#      («로드가 표를 버린다»)이 R11 이후 **거짓**인데도 매치가 함수 경계를 넘어 늘 참이었다.
#   ㉢ **표에서 파생하는 소비처는 표가 자라면 함께 자라야 한다.** #5는 늘봄방이 완공 뒤에
#      생기는 다섯 번째 facade라 const 접지 목록에 못 실려 여섯 동 중 혼자 ADR-0054 패드를
#      못 받던 자리고, #6은 「채취기는 이 8×7에 놓일 수 없다」는 배제 근거를 **같은 파일이
#      33줄 아래에서 반증**하던 자리다(`_greenhouse_lot_trees`의 존재 자체가 반례).
#   ㉣ **백필은 «무엇을 못 되찾는가»를 말해야 한다.** #9는 임계(`need_days`)만 복구하고 그
#      임계를 읽는 자[尺](`regrown`)를 안 복구해, 어떤 순수 경로보다 나쁜 쿨다운이 나오던
#      자리다. 표식을 파일에서 되찾을 수는 없으므로 **증명 가능한 한쪽만**(되감긴 적 없음이
#      확정인 칸) 남기고, 나머지는 명목보다 나빠질 수 없는 쪽으로 접는다.
#
# 무엇을 보증하나(번호 = 27회차 헌트 발견 인덱스).
#   ① #0 원장 나무 성역의 폭이 **밑동 한 칸**이다 — 캐노피 여덟 칸은 다시 열렸고, 앵커는 여전히 막힌다.
#   ② #1 두 상단 패널이 각자 **자기 목록의 행 수**로 그리기 시점에 클램프한다(축이 갈려도).
#   ③ #2 방목 이월 표의 아침 계약이 두 갈래다(집 밖=세운다 / 집=성공했을 때만 내린다).
#   ④ #3 출하함 회수 알림이 되돌린 **등급을 말한다**(R25 #14 문구 — 증인 니들의 실재 확인).
#   ⑤ #4 그 표는 세이브를 왕복한다(«집행 전 표 = 왕복 필수» — 로드가 안 버린다).
#   ⑥ #5 늘봄방이 서면 그 8×7과 발치 링이 ADR-0054 접지 패드 안이다(완공 전엔 아니다).
#   ⑦ #6 늘봄방 부지 회수가 **수액 채취기도** 걷는다(고인 수액과 함께).
#   ⑧ #7 `home_deco`가 무조건 되감긴다 — 키 없는 구세이브 로드가 배치·해금을 버린다.
#   ⑨ #8 로스터 밖 연애 슬롯 id는 로드에서 버려진다(영구 소프트락·유령 배우자 둘 다 차단).
#   ⑩ #9 되감기 표식 백필 — pre-R22 되감기 칸이 명목보다 긴 쿨다운으로 재봉인되지 않는다.
#   ⑪ #10 숲 장식 밀도가 열 줄무늬로 뭉치지 않는다(원시 djb2 → `rand_from_seed`).
#
# 판정: #0~#10 **전건 CONFIRMED**(11건 봉합) · REFUTED·DUP·OWNER 0.
#   ★ #2와 #4는 **형제이되 별개 결함**이다(오케 위임 판정): 둘 다 polish_r6 ⑩의 방목 이월 증인
#     이지만 병이 다르다 — #2는 니들 0건의 **확정 red**(R24 #19가 갈아 치운 대입)고, #4는 늘
#     참인 **공허 초록**(함수 경계를 넘은 매치 + 라벨이 주장하는 계약 자체가 거짓)이다. 봉합도
#     갈린다: #2는 니들 교체, #4는 «무엇을 재는가»의 교체(로드 폐기 → 세이브 왕복).
#   ★ #10과 #12(배치 B 몫)는 **같은 계보이되 별개 자리**다: 둘 다 숲 그리기의 원시 djb2지만
#     #10은 `_collect_forest_decor`의 밀도 롤(4420행 계열)이고 #12는 4350행의 캐노피·원장 나무
#     변주 인덱스다. 이 배치는 #12를 건드리지 않는다.
#
# 하중 검증(파괴 11배치 — 봉합을 되돌리면 실제로 red가 남는가 · 전건 실측):
#   #0  `_is_tree_blocked`에 `_tree_occupied_at(t)` 복귀     → ①c red(캐노피 이웃 앵커가 다시 막힌다)
#       `_use_tool`의 `elif _tree_occupied_at(_target)` 삭제 → ①d·①e red(파종목 위에 밑동이 선다)
#   #1  `_draw_bin_top`의 클램프를 `ids.size()`로 복귀       → ②c red(행 축 스크롤 상한이 품목 수로 잘린다)
#   #2  `_on_day_advanced`의 두 갈래를 옛 무조건 대입으로 복귀 → ③a·③b red
#   #3  `_on_frame_takeback` 문구에서 `btag` 제거            → ④a·④b red(등급을 안 말한다)
#   #4  `_save_game`의 `"pasture_release_pending"` 줄 삭제   → ⑤b red(왕복이 끊긴다)
#   #5  `_g16_resolve_profile`의 늘봄방 append 삭제          → ⑥b·⑥c red(패드 밖 · 발치 링 밖)
#   #6  `_greenhouse_lot_occupants`의 tapper 항 삭제         → ⑦b·⑦c·⑦d red(원장에 그대로 남는다)
#   #7  `home_deco`를 `has` 가드로 복귀                      → ⑧b red(버린 타임라인의 가구가 산다)
#   #8  `ROMANCE_OPEN.has` 검증 삭제                         → ⑨b·⑨c red(유령 슬롯이 그대로 눕는다)
#   #9  `regrown` 백필 삭제                                  → ⑩c red(재봉인이 명목 쿨다운보다 길어진다)
#   #10 `rand_from_seed`를 원시 `abs(hash(...))`로 복귀      → ⑪b·⑪c red(통과 열 수가 한 자릿수로 뭉친다)
#   ★ ①a·②a·③…의 «무대» 줄들은 파괴에 안 죽는다(전제를 재는 자리다) — 하중은 위 목록이 든다.
#
# 실행: ./run_tests.sh polish_r27   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _src: PackedStringArray = PackedStringArray()
var _ui_src: PackedStringArray = PackedStringArray()

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

# ── 소스 스캔 헬퍼(polish_r7~r26 관례 — 니들은 반드시 함수 안에서 센다) ──────
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _count_in(lines: PackedStringArray, fn_needle: String, needle: String) -> int:
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

func _select(m: Node, id: String) -> void:
	m.inventory.add_item(id, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

func _notice_has(m: Node, needle: String) -> bool:
	if m.notice_feed == null:
		return false
	for e in m.notice_feed._items:
		if String(e.get("text", "")).contains(needle):
			return true
	return false

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R27 회귀 — 배치 A(#0~#10) ══")
	SaveManager.new().delete_save()
	_src = _lines_of_file("res://main.gd")
	_ui_src = _lines_of_file("res://inv_frame.gd")
	_check("무대 전제: main(%d행)·inv_frame(%d행)을 읽었다(부정 단언 공허 통과 방지)"
			% [_src.size(), _ui_src.size()],
		_src.size() > 1000 and _ui_src.size() > 500)

	_check_field_regrown_backfill()   # ⑩ #9(무대 불요 — 순수 FarmField)

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	m._indoor = ""
	m._sleeping = false
	m._transitioning = false

	_check_tree_anchor_width(m)       # ① #0
	await _check_bin_scroll_clamp(m)  # ② #1
	_check_pasture_pending_hooks()    # ③ #2
	_check_takeback_grade_notice(m)   # ④ #3
	await _check_pasture_roundtrip(m) # ⑤ #4
	await _check_greenhouse_pad(m)    # ⑥ #5
	await _check_lot_tapper_reclaim(m)   # ⑦ #6
	await _check_home_deco_rewind(m)     # ⑧ #7
	await _check_romance_roster(m)       # ⑨ #8
	await _check_forest_decor_spread(m)  # ⑪ #10(구역 재빌드가 무대라 맨 끝)

	# ★ ⑤·⑧·⑨는 세이브 파일을 **쓴다**(구세이브 되감기·왕복이 파일 경로를 타야 하는 검증이라
	#   무대가 곧 파일이다). 끝나면 지운다 — polish_r24 ⑮·r25 ⑩·r26 ⑤가 세운 그 관례.
	SaveManager.new().delete_save()
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 원장 나무 성역의 폭 = 밑동 한 칸 ────────────────────────────────────
func _check_tree_anchor_width(m: Node) -> void:
	print("① #0 자체 파종 원장 성역 ↔ 3×3 풋프린트")
	_check("①a 배선: 원장 항이 3×3 전수 술어를 떠나 앵커 갈래에 섰다(R19 #17이 같은 이유로 세운 자리)",
		_count_in(_src, "func _is_tree_blocked", "_tree_occupied_at(t)") == 0
			and _count_in(_src, "func _use_tool", "elif _tree_occupied_at(_target):") == 1)
	# 무대 — 지금 판에서 실제로 심을 수 있는 앵커를 찾는다(좌표 옮겨 적기 0).
	var anchor := Vector2i(-1, -1)
	for y in range(6, 40):
		for x in range(30, 70):
			var a := Vector2i(x, y)
			if m.orchard.can_plant(a, m._is_tree_blocked):
				anchor = a
				break
		if anchor.x >= 0:
			break
	_check("①b 무대: 심을 수 있는 앵커 (%d,%d)를 찾았다" % [anchor.x, anchor.y], anchor.x >= 0)
	if anchor.x < 0:
		return
	# ㉠ 캐노피 — 앵커에서 한 칸 비켜선 칸에 파종목이 돋아도 그 앵커는 **여전히 열려 있다**.
	var canopy: Vector2i = anchor + Vector2i(1, 0)
	m.tree_ledger._put(RegionCatalog.HOME, canopy,
		{"species": TreeLedger.species_at_tile(RegionCatalog.HOME, canopy), "stage": 1,
		"hp": TreeLedger.hp_for_stage(1), "stump": false, "moss": false})
	_check("①c **캐노피는 성역이 아니다** — 파종목이 %s에 서 있어도 앵커 %s는 열려 있다(3×3 안 · 밑동 아님)"
			% [str(canopy), str(anchor)],
		Orchard.footprint_of(anchor).has(canopy) and m._tree_occupied_at(canopy)
			and m.orchard.can_plant(anchor, m._is_tree_blocked))
	m.tree_ledger.clear_slot(RegionCatalog.HOME, canopy)
	# ㉡ 앵커 — 그 칸 자체에 파종목이 서면 LMB 묘목이 **말하며** 거절한다(무동작 아님).
	m.tree_ledger._put(RegionCatalog.HOME, anchor,
		{"species": TreeLedger.species_at_tile(RegionCatalog.HOME, anchor), "stage": 1,
		"hp": TreeLedger.hp_for_stage(1), "stump": false, "moss": false})
	var fruit: String = FruitTreeCatalog.ids()[0]
	var sap_id: String = ItemCatalog.sapling_id(fruit)
	_select(m, sap_id)
	m._target = anchor
	m.notice_feed._items.clear()
	var sap_before: int = m.inventory.count_of(sap_id)
	m._use_tool()
	_check("①d 앵커에 파종목이 서 있으면 밑동이 **안 선다**(두 원장이 한 칸을 쥐지 않는다)",
		not m.orchard.has_tree(anchor) and m.inventory.count_of(sap_id) == sap_before)
	_check("①e 그리고 **말한다** — 종전 이 실패는 알림 없는 no-op이었다",
		_notice_has(m, "이미 나무가 서 있다"))
	m.tree_ledger.clear_slot(RegionCatalog.HOME, anchor)

# ── ② #1 두 상단 패널의 그리기 시점 클램프는 각자 자기 목록을 잰다 ────────────
func _check_bin_scroll_clamp(m: Node) -> void:
	print("② #1 출하함/곳간 상단 패널 ↔ 스크롤 클램프의 자")
	_check("②a 배선: 두 패널이 각자 자기 목록으로 클램프한다(출하함 rows · 곳간 ids — 소스 대조)",
		_count_in(_ui_src, "func _draw_bin_top",
			"_top_scroll = clampi(_top_scroll, 0, maxi(0, rows.size() - max_rows))") == 1
		and _count_in(_ui_src, "func _draw_larder_top",
			"_top_scroll = clampi(_top_scroll, 0, maxi(0, ids.size() - max_rows))") == 1)
	# 무대 — **품목 수보다 행 수가 큰** 적재를 만든다(같은 id를 두 등급으로). 두 수가 갈리지
	#   않으면 «어느 자로 클램프하는가»를 잴 수 없다(R25 #14가 연 축이 바로 그 갈림이다).
	var vis: int = m.frame.top_rows_visible()
	var ship_ids: Array = []
	for cid in CropCatalog.CATALOG:
		var hid := ItemCatalog.harvest_id(String(cid))
		if not ship_ids.has(hid):
			ship_ids.append(hid)
		if ship_ids.size() >= vis + 2:
			break
	for hid in ship_ids:
		m.ship_bin.add(String(hid), 1, ItemCatalog.Q_NORMAL)
		m.ship_bin.add(String(hid), 1, ItemCatalog.Q_SILVER)
	var n_ids: int = m.ship_bin.ids().size()
	var n_rows: int = m.frame.bin_rows().size()
	_check("②b 무대: 행 수(%d)가 품목 수(%d)보다 크다 — 두 자가 실제로 갈린다(창 %d행)"
			% [n_rows, n_ids, vis],
		n_rows > n_ids and n_rows > vis)
	# 그리기 시점 클램프를 **그리기로** 잰다(표시 단언은 그리기 경로를 태운다 — R16 규약).
	m.frame.open(InventoryFrame.CTX_BIN)
	m.frame._top_scroll = 9999
	m.frame.queue_redraw()
	await process_frame
	await process_frame
	var want: int = maxi(0, n_rows - vis)
	_check("②c 스크롤이 **행 수**로 클램프된다(%d = rows %d − 창 %d · 품목 수 기준이면 %d였다)"
			% [m.frame._top_scroll, n_rows, vis, maxi(0, n_ids - vis)],
		m.frame._top_scroll == want and want != maxi(0, n_ids - vis))
	m.frame.close()

# ── ③ #2 방목 이월 표의 아침 계약(두 갈래) ───────────────────────────────────
func _check_pasture_pending_hooks() -> void:
	print("③ #2 아침 훅 ↔ 방목 이월 표")
	_check("③a 집 밖이면 표를 세우고, 집이면 방출이 **성공했을 때만** 내린다(R24 #19 — 소스 대조)",
		_count_in(_src, "func _on_day_advanced", "_pasture_release_pending = true") == 1
		and _count_in(_src, "func _on_day_advanced",
			"_pasture_release_pending = not _release_open_buildings(day)") == 1)
	_check("③b 옛 **무조건 대입**은 한 줄도 안 남았다(polish_r24 ⑯과 같은 자·모순 0)",
		_count_in(_src, "func _on_day_advanced",
			"_pasture_release_pending = _region != RegionCatalog.HOME") == 0)

# ── ④ #3 출하함 회수 알림은 되돌린 등급을 말한다 ─────────────────────────────
func _check_takeback_grade_notice(m: Node) -> void:
	print("④ #3 출하함 회수 알림 ↔ 등급 앞머리")
	var pick: String = ItemCatalog.harvest_id(String(CropCatalog.ids()[0]))
	m.ship_bin.add(pick, 1, ItemCatalog.Q_GOLD)
	m.notice_feed._items.clear()
	m._on_frame_takeback(pick, ItemCatalog.Q_GOLD)
	var qname: String = ItemCatalog.quality_name(ItemCatalog.Q_GOLD)
	_check("④a 회수 알림이 그 **등급**을 말한다(「%s %s」 — R25 #14 문구)"
			% [qname, ItemCatalog.name_of(pick)],
		_notice_has(m, "출하함에서 %s %s" % [qname, ItemCatalog.name_of(pick)]))
	_check("④b 그 문구가 소스에도 그 형태로 서 있다(증인 니들의 실재 — 낡은 니들 0)",
		_count_in(_src, "func _on_frame_takeback", "\"출하함에서 %s%s %d개 회수\"") == 1)

# ── ⑤ #4 방목 이월 표는 세이브를 왕복한다 ────────────────────────────────────
func _check_pasture_roundtrip(m: Node) -> void:
	print("⑤ #4 방목 이월 표 ↔ 세이브 왕복")
	_check("⑤a 배선: 저장·복원 두 줄이 서로 짝이다(«집행 전 표 = 왕복 필수» — R10 판별식)",
		_count_in(_src, "func _save_game", "\"pasture_release_pending\": _pasture_release_pending") == 1
		and _count_in(_src, "func _load_game",
			"_pasture_release_pending = bool(data.get(\"pasture_release_pending\", false))") == 1)
	m._active_slot = 0
	m._pasture_release_pending = true
	var saved: bool = m._save_game()
	m._pasture_release_pending = false
	var loaded: bool = m._load_game()
	# ★ 값은 **로드가 돌아온 그 자리**에서 읽는다 — 다음 프레임의 `_process` 소비처가 안식 농원에
	#   서 있는 판에서 그 빚을 정상적으로 갚아 버리기 때문이다(그게 R6가 세운 계약이다). 여기서
	#   재는 것은 «로드가 표를 버리는가»이지 «소비처가 도는가»가 아니다.
	var survived: bool = m._pasture_release_pending
	await process_frame
	_check("⑤b 집 밖에서 잔 밤의 빚이 F9를 건너 살아남는다(로드가 안 버린다 — 저장 %s·로드 %s·표 %s)"
			% [str(saved), str(loaded), str(survived)],
		saved and loaded and survived)
	m._pasture_release_pending = false

# ── ⑥ #5 늘봄방도 ADR-0054 건물 접지 패드를 받는다 ───────────────────────────
func _check_greenhouse_pad(m: Node) -> void:
	print("⑥ #5 늘봄방 ↔ 잔디억제 접지 패드")
	var r: Rect2i = m.GREENHOUSE_EXT_RECT
	var c: Vector2i = r.position + r.size / 2
	if m.carpenter._done.has(Carpenter.PROJ_GREENHOUSE):
		m.carpenter._done.erase(Carpenter.PROJ_GREENHOUSE)
	m._rebuild_region(RegionCatalog.HOME)
	await process_frame
	_check("⑥a 완공 전엔 패드가 **아니다** — 아직 없는 건물의 접지를 미리 그리지 않는다",
		not m._greenhouse_built() and not m._g16_near_building(c.x, c.y))
	# 완공시킨다(카탈로그 원장 그대로 — 새 좌표·새 플래그 0).
	m.carpenter._done[Carpenter.PROJ_GREENHOUSE] = true
	m._rebuild_region(RegionCatalog.HOME)
	await process_frame
	_check("⑥b 완공 뒤 footprint 중심 %s가 패드 안이다(다른 여섯 동과 같은 대접)" % str(c),
		m._greenhouse_built() and m._g16_near_building(c.x, c.y))
	var west := Vector2i(r.position.x - 1, c.y)
	var east := Vector2i(r.end.x, c.y)
	_check("⑥c 발치 1링(서 %s·동 %s)도 패드 안이다(facade 틈으로 잔디가 안 비친다)"
			% [str(west), str(east)],
		m._g16_near_building(west.x, west.y) and m._g16_near_building(east.x, east.y))
	_check("⑥d const 프로파일 표는 **오염되지 않았다**(duplicate — 구역을 옮겨도 안 따라다닌다)",
		m._HOME_BUILDING_RECTS.size() == 6 and not m._HOME_BUILDING_RECTS.has(r))

# ── ⑦ #6 늘봄방 부지 회수가 수액 채취기도 걷는다 ─────────────────────────────
func _check_lot_tapper_reclaim(m: Node) -> void:
	print("⑦ #6 늘봄방 부지 회수 ↔ 수액 채취기 원장")
	var r: Rect2i = m.GREENHOUSE_EXT_RECT
	var t := Vector2i(r.position.x + 1, r.position.y + 1)
	# 구세이브 무대 — 예정지 가드가 서기 전 파일에서 돋아 성숙한 자연목 + 그 위의 채취기.
	m.tree_ledger._put(RegionCatalog.HOME, t,
		{"species": TreeLedger.species_at_tile(RegionCatalog.HOME, t),
		"stage": TreeLedger.MAX_STAGE, "hp": TreeLedger.hp_for_stage(TreeLedger.MAX_STAGE),
		"stump": false, "moss": false})
	var species: String = m.tree_ledger.species_at(RegionCatalog.HOME, t)
	var placed: bool = m.tapper.place(RegionCatalog.HOME, t, species)
	_check("⑦a 무대: 예정지 %s의 성숙목에 채취기가 박혔다(구세이브 경로 — `_can_place_tapper`는 부지를 안 본다)"
			% str(t),
		placed and m.tapper.has_at(RegionCatalog.HOME, t))
	_check("⑦b 그 칸이 **회수 대상 목록**에 든다(종전엔 배제 근거가 `_greenhouse_lot_trees`로 반증됐다)",
		m._greenhouse_lot_occupants().has(t))
	var tap_before: int = m.inventory.count_of(ItemCatalog.TAPPER)
	m.notice_feed._items.clear()
	m._reclaim_greenhouse_lot()
	_check("⑦c 회수가 원장에서 **실제로 걷는다**(벽 밑 영구 유실 0)",
		not m.tapper.has_at(RegionCatalog.HOME, t))
	_check("⑦d 걷힌 채취기가 보관처로 들어갔다(적재 먼저·차감 나중 — %d → %d)"
			% [tap_before, m.inventory.count_of(ItemCatalog.TAPPER)],
		m.inventory.count_of(ItemCatalog.TAPPER) > tap_before)
	m.tree_ledger.clear_slot(RegionCatalog.HOME, t)

# ── ⑧ #7 home_deco는 무조건 되감긴다 ─────────────────────────────────────────
func _check_home_deco_rewind(m: Node) -> void:
	print("⑧ #7 집 꾸미기 원장 ↔ 구세이브 되감기")
	_check("⑧a 배선: `has` 가드가 없다(R24 #16 판별식 — 부팅 시드가 `if not loaded:` 안에만 있다)",
		_count_in(_src, "func _load_game", "home_deco.load_save(data.get(\"home_deco\", {}))") == 1
			and _count_in(_src, "func _load_game", "if data.has(\"home_deco\"):") == 0)
	m._active_slot = 1
	var ok_save: bool = m._save_game()
	# 그 슬롯 파일에서 키를 **떼어 낸다** = pre-S1-9 세이브(그 세대 갭이 실재한다).
	var path: String = SaveManager.slot_path(1)
	var f := FileAccess.open(path, FileAccess.READ)
	var wrapped: Dictionary = {}
	if f != null:
		var parsed: Variant = str_to_var(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			wrapped = parsed
		f.close()
	var raw: Dictionary = wrapped.get("data", {})
	_check("⑧a' 무대: 그 슬롯 파일을 읽었고 원래는 키가 있었다(세대 갭을 인위로 만든다)",
		raw.has("home_deco"))
	raw.erase("home_deco")
	wrapped["data"] = raw
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w != null:
		w.store_string(var_to_str(wrapped))
		w.close()
	# 이 세션에서 집을 꾸미고 테마를 해금한다(버린 타임라인).
	var sid: String = HomeDecoCatalog.STARTER_SETS[0]
	m.home_deco.unlock(sid)
	m.home_deco._unlocked["__r27_probe__"] = true
	_check("⑧b' 무대: 이 세션의 원장이 실제로 비어 있지 않다", not m.home_deco._unlocked.is_empty())
	var loaded: bool = m._load_game()
	await process_frame
	_check("⑧b 키 없는 구세이브 로드가 **배치·해금을 버린다**(가구가 꾸민 적 없는 세계에 안 남는다)",
		ok_save and loaded and not m.home_deco._unlocked.has("__r27_probe__")
			and m.home_deco._furniture.is_empty())

# ── ⑨ #8 로스터 밖 연애 슬롯 id는 로드에서 버려진다 ──────────────────────────
func _check_romance_roster(m: Node) -> void:
	print("⑨ #8 연애 슬롯 ↔ 로스터 실재 검증")
	_check("⑨a 배선: 로드가 `ROMANCE_OPEN` 실재를 본다(형제 원장 전부가 가진 그 방어)",
		_count_in(_src, "func _load_game",
			"if _romance_partner != \"\" and not ROMANCE_OPEN.has(_romance_partner):") == 1)
	var ghost := "__r27_ghost__"
	_check("⑨a' 무대: 그 id는 실제로 로스터 밖이다", not m.ROMANCE_OPEN.has(ghost))
	m._active_slot = 2
	var ok_save: bool = m._save_game()
	var path: String = SaveManager.slot_path(2)
	var f := FileAccess.open(path, FileAccess.READ)
	var wrapped: Dictionary = {}
	if f != null:
		var parsed: Variant = str_to_var(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			wrapped = parsed
		f.close()
	var raw: Dictionary = wrapped.get("data", {})
	# 재현 A — 슬롯에만 유령 id(영구 소프트락: 고백 전원 거절 · 이혼 도달 불가).
	raw["romance_partner"] = ghost
	raw["spouse_id"] = ""
	wrapped["data"] = raw
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w != null:
		w.store_string(var_to_str(wrapped))
		w.close()
	var l1: bool = m._load_game()
	await process_frame
	_check("⑨b 재현 A: 유령 슬롯이 로드에서 버려진다(고백 창구가 다시 열린다 — 영구 소프트락 0)",
		ok_save and l1 and m._romance_partner == "")
	# 재현 B — 두 값이 **같은** 유령 id(동일성 검사만으로는 통과한다).
	raw["romance_partner"] = ghost
	raw["spouse_id"] = ghost
	wrapped["data"] = raw
	var w2 := FileAccess.open(path, FileAccess.WRITE)
	if w2 != null:
		w2.store_string(var_to_str(wrapped))
		w2.close()
	var l2: bool = m._load_game()
	await process_frame
	_check("⑨c 재현 B: 유령과 기혼 상태가 안 선다(둘이 같아 동일성 검사는 통과하던 갈래)",
		l2 and m._romance_partner == "" and m._spouse_id == "")

# ── ⑩ #9 되감기 표식 백필 ────────────────────────────────────────────────────
func _check_field_regrown_backfill() -> void:
	print("⑩ #9 FarmField 로드 백필 ↔ 되감기 표식")
	# 무대 — 되감기 축이 실재하는 작물(REGROW·cd < base)을 카탈로그에서 판다(값 옮겨 적기 0).
	var crop := ""
	for cid in CropCatalog.ids():
		var b: int = CropCatalog.growth_days(String(cid))
		var cd: int = CropCatalog.regrow_cooldown(String(cid))
		if cd > 0 and b > cd:
			crop = String(cid)
			break
	_check("⑩a 무대: 되감기 작물 「%s」(base %d · cd %d)를 카탈로그에서 찾았다"
			% [crop, CropCatalog.growth_days(crop), CropCatalog.regrow_cooldown(crop)],
		crop != "")
	if crop == "":
		return
	var base: int = CropCatalog.growth_days(crop)
	var cd: int = CropCatalog.regrow_cooldown(crop)
	var t := Vector2i(3, 3)
	# pre-R22 세이브 모양 — 임계는 굳어 있고(`need_days`) `regrown` 키만 없다. grown은 되감기
	#   출발점 그대로라 «되감긴 적 없음»이 성립하지 않는 쪽이다.
	var need: int = base - 1
	var fld := FarmField.new()
	fld.load_save({"tiles": {t: {"tilled": true, "planted": true, "crop": crop,
		"grown_days": maxi(0, need - cd), "need_days": need, "watered": false,
		"fertilizer": ""}}})
	_check("⑩b 되감기 칸으로 백필됐다(grown %d ≥ need−cd %d — 첫 사이클이 아님이 배제되지 않는다)"
			% [maxi(0, need - cd), maxi(0, need - cd)],
		fld.is_planted(t) and bool(fld._tiles[t].get("regrown", false)))
	# 그 칸에 품질군 비료를 덮어도 임계가 **명목보다 길어지지 않는다**(R22 #2 계약).
	var before: int = int(fld._tiles[t]["need_days"])
	var qfert := ""
	for fid in FertilizerCatalog.ids():
		if FertilizerCatalog.speed_factor(String(fid)) >= 1.0:
			qfert = String(fid)
			break
	if qfert != "":
		fld.fertilize(t, qfert)
		_check("⑩c 재봉인이 임계를 안 건드린다 — %d 유지(백필 없으면 %d로 늘어 명목 cd %d를 넘긴다)"
				% [int(fld._tiles[t]["need_days"]), base, cd],
			int(fld._tiles[t]["need_days"]) == before)
	# 대조군 — **되감긴 적 없음이 확정**인 칸(grown < need − cd)은 표식을 안 받는다.
	if need - cd >= 2:
		var t2 := Vector2i(4, 4)
		var f2 := FarmField.new()
		f2.load_save({"tiles": {t2: {"tilled": true, "planted": true, "crop": crop,
			"grown_days": 0, "need_days": need, "watered": false, "fertilizer": ""}}})
		_check("⑩d 대조군: grown 0 < need−cd %d인 칸은 표식을 안 받는다(증명 가능한 한쪽만 남긴다)"
				% (need - cd),
			f2.is_planted(t2) and not bool(f2._tiles[t2].get("regrown", false)))

# ── ⑪ #10 숲 장식 밀도는 열 줄무늬가 아니다 ──────────────────────────────────
# ★ 재는 것은 **프로덕션이 실제로 뱉은 소품 목록**이다(`_collect_forest_decor`를 그대로 태운다).
#   식을 테스트가 다시 구현해 재면 프로덕션을 되돌려도 안 죽는 «공허 초록»이 된다 — 초안이
#   실제로 그랬고, 파괴 실측(원시 djb2 복귀 → 배선 단언만 red)이 그것을 잡아냈다.
func _check_forest_decor_spread(m: Node) -> void:
	print("⑪ #10 숲 장식 밀도 롤 ↔ 확률 질량")
	_check("⑪a 배선: 원시 djb2를 그대로 나누지 않는다(weather.gd·TreeLedger가 두 번 금지한 그 자리)",
		_count_in(_src, "func _collect_forest_decor",
			"absi(rand_from_seed(hash(\"decor:%s:%d:%d\"") == 1
		and _count_in(_src, "func _collect_forest_decor", "abs(hash(\"decor:%s:%d:%d\"") == 0)
	for region in [RegionCatalog.MIHOK_FOREST, RegionCatalog.JEOSEUNG_FOREST]:
		m._rebuild_region(region)
		await process_frame
		var items: Array = []
		m._collect_forest_decor(items)
		var cols := {}
		var per_col := {}
		for it in items:
			var cx: int = int(it["tile"].x)
			cols[cx] = true
			per_col[cx] = int(per_col.get(cx, 0)) + 1
		var worst := 0
		for k in per_col:
			worst = maxi(worst, int(per_col[k]))
		_check("⑪b %s: 소품 %d점이 %d개 열에 퍼진다(원시 djb2는 한 자릿수 열에 뭉쳤다 — 실측 4·7열)"
				% [region, items.size(), cols.size()],
			items.size() > 0 and cols.size() * 2 >= items.size())
		_check("⑪c %s: 한 열이 전체를 도배하지 않는다(최다 열 %d점 / %d점 = %.0f%%)"
				% [region, worst, items.size(), 100.0 * float(worst) / maxf(1.0, float(items.size()))],
			items.size() > 0 and float(worst) <= float(items.size()) * 0.15)
