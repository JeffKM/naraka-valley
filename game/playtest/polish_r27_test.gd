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
#
# ══ 배치 B(#11~#21) ═══════════════════════════════════════════════════════════
# 렌즈: 확률 질량 보존(#11·#12) · 목축 생애주기 사슬(#13~#16) · 도구 업그레이드
#       생애주기(#17~#19) · 가격표 정합(#20·#21).
#
# 판정: CONFIRMED 9 · **OWNER-DECISION 2**(#15·#20 — 코드 무수정) · REFUTED·DUP 0.
#
# 무엇을 보증하나(번호 = 27회차 헌트 발견 인덱스).
#   ⑫ #11 낙엽 «칸당 3알갱이»가 실제로 세 번 독립으로 굴러간다(종전엔 칸 단위 all-or-nothing).
#   ⑬ #12 캐노피 변주가 8칸 주기 격자로 서지 않고 행끼리 무늬를 반복하지 않는다.
#   ⑭ #13 방목 문 [F]가 실내 프롬프트에서 **키와 상태로** 광고된다(사슬 전체의 유일한 입구).
#   ⑮ #14 «오늘 돌봄 완료»는 급여·청소까지 끝났을 때만 뜬다(아니면 무엇이 남았는지 말한다).
#   ⑯ #16 방목지에 그대로 선 짐승은 새 날에도 방목 중이다(원장이 자기 위치와 안 어긋난다).
#   ⑰ #17 티어 AoE 프롬프트가 집행부와 같은 범위를 본다(업그레이드가 화면을 침묵시키지 않는다).
#   ⑱ #18 모루 상호작용 칸이 **아트 폭 파생**이다(왼쪽 절반이 더는 죽은 칸이 아니다).
#   ⑲ #19 광맥 타수 눈금이 분자를 분모로 접는다(«4/3타» 0 — 그림 쪽 R15 clampf의 글자판).
#   ⑳ #21 시련 납품 풀이 판매가 밴드가 아니라 **깊이 단일 술어**에서 나온다.
#
# ★ OWNER-DECISION 2건(코드 무수정 — 후보안은 커밋 본문).
#   #15 짐승 기분(mood)이 DELUXE 산물을 게이팅하는데 UI 도달성이 0이다. 결함은 실재하나
#       «어떻게 노출하나»가 설계 선택이라(수치/2단 낱말/아이콘) 어휘를 발명하지 않는다.
#   #20 멜 배우자 출하 팁 +2%가 ADR-0061 결정 5의 «판매 채널 총액 동일»과 정면으로 어긋난다.
#       ADR-0008(관계 = 곱셈기)과 그 계약 중 **어느 쪽이 양보하는가**가 owner 몫이다.
#
# 하중 검증(파괴 9배치 — 봉합을 되돌리면 실제로 red가 남는가 · 전건 실측):
#   #11 원시 djb2 복귀        → ⑫a·⑫c red(낙엽 칸 비율 0.399 → 0.160 = 접힌 답 그대로)
#   #12 원시 djb2 복귀        → ⑬a·⑬c·⑬d red(간격 «정확히 8칸» 8% → 50% · 겹치는 행 0 → 2)
#   #13 문 광고 삭제          → ⑭c·⑭d red · #14 완료 판정 복귀 → ⑮b red
#   #16 이월 두 줄 삭제       → ⑯d red · #17 조준 칸 단독 판정 복귀 → ⑰a·⑰d red
#   #18 단일 칸 비교 복귀     → ⑱a red · #19 `mini` 제거 → ⑲a red
#   #21 판매가 하한 복귀      → ⑳b·⑳c·⑳d red(1층 산출 둘 + 나락철이 그대로 풀에 든다)
#   ★ ⑱b·⑱c(칸 표 자체)·⑲b~⑲d(무대)·⑯e(대조군)·⑭a(무대)는 그 파괴에 안 죽는다 — 각각
#     **헬퍼 회귀**와 **무대 성립**을 재는 자리이고, 소비처 쪽 하중은 ⑱a·⑲a가 든다(배치 A ①의
#     두 반쪽 구조와 같다 — 파괴를 갈래로 나눠 각각 실측했다).
#   ★ ⑬은 **초안 지표 두 개가 파괴에 안 죽어** 두 번 다시 설계했다: `mix.find`는 같은 텍스처
#     여섯 칸을 전부 0으로 접고, «4점 주기»는 djb2의 자릿수 올림 때문에 성립하다 만다. 파괴
#     상태의 실측 로그(x = 12·20·38·46 / 13·21·39·47)로 갈아탄 자리다.
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

	print("══ 폴리시 R27 회귀 — 배치 B(#11~#21) ══")
	_check_trial_deliver_pool()          # ⑳ #21(무대 불요 — 순수 카탈로그)
	_check_pasture_graze_carry()         # ⑯ #16(무대 불요 — 순수 Ranch)
	await _check_leaf_litter_grains(m)   # ⑫ #11(숲 무대 — 위 ⑪이 이미 숲에 서 있다)
	await _check_canopy_variation(m)     # ⑬ #12(같은 무대)
	await _check_animal_care_honesty(m)  # ⑮ #14
	await _check_pasture_door_ad(m)      # ⑭ #13
	await _check_aoe_prompt(m)           # ⑰ #17
	_check_anvil_tiles(m)                # ⑱ #18
	_check_node_hits_fold(m)             # ⑲ #19

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
	# ★[폴리시 R30 부록 — 선재 증인 rot] 술어 이름이 R29 #21에서 `_romance_slot_valid`로 갈렸다
	#   (자[尺]가 한 칸 좁아 앵커 청혼을 재기동마다 지웠기 때문 — 그 주석에 경위). 재는 계약은
	#   그대로다: **로스터 밖 유령 id는 로드가 버린다**(아래 ⑨b~가 그 거동을 그대로 잰다).
	_check("⑨a 배선: 로드가 슬롯 자격 술어로 실재를 본다(형제 원장 전부가 가진 그 방어)",
		_count_in(_src, "func _load_game",
			"if _romance_partner != \"\" and not _romance_slot_valid(_romance_partner):") == 1)
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


# ── ⑫ #11 낙엽 «칸당 3알갱이»가 실제로 세 번 독립으로 굴러간다 ────────────────
# ★ 프로덕션 함수(`_g16_bake_leaf_litter`)를 그대로 태운다 — 식을 테스트가 다시 구현하면
#   되돌려도 안 죽는 공허 초록이 된다(#10 초안에서 실측으로 겪은 함정).
func _check_leaf_litter_grains(m: Node) -> void:
	print("⑫ #11 낙엽 알갱이 ↔ 세 번 독립 롤")
	_check("⑫a 배선: 원시 djb2를 그대로 나누지 않는다(#10·#12와 같은 처방)",
		_count_in(_src, "func _g16_bake_leaf_litter",
			"absi(rand_from_seed(hash(\"leaf:%s:%d:%d:%d\"") == 1
		and _count_in(_src, "func _g16_bake_leaf_litter", "abs(hash(\"leaf:%s:%d:%d:%d\"") == 0)
	m._rebuild_region(RegionCatalog.JEOSEUNG_FOREST)
	await process_frame
	var d: float = m._g16_leaf_density
	_check("⑫b 무대: 이 구역의 낙엽 밀도가 0이 아니다(%.3f — 0이면 함수가 즉시 빠진다)" % d, d > 0.0)
	if d <= 0.0:
		return
	# 불투명 판을 하나 세워 프로덕션 베이크를 그대로 돌린다(투명 픽셀은 함수가 건너뛴다).
	var w: int = m._grid_w
	var h: int = m._outdoor_h
	var img := Image.create(w * m.TILE, h * m.TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	# ★ 기준색은 **판에서 되읽는다** — FORMAT_RGBA8은 0.5를 128/255로 양자화하므로 리터럴과
	#   비교하면 모든 픽셀이 «바뀐 픽셀»로 세어진다(초안이 실제로 그래서 비율이 1.000이었다).
	var basec: Color = img.get_pixel(0, 0)
	var surf: Array = []
	for _y in h:
		var row: Array = []
		for _x in w:
			row.append(0)
		surf.append(row)
	m._g16_bake_leaf_litter(img, surf)
	# 낙엽이 앉은 칸 수를 센다(색이 바뀐 픽셀이 하나라도 있는 칸).
	var leafed := 0
	for y in h:
		for x in w:
			var hit := false
			for j in m.TILE:
				for i in m.TILE:
					if img.get_pixel(x * m.TILE + i, y * m.TILE + j) != basec:
						hit = true
						break
				if hit:
					break
			if hit:
				leafed += 1
	var ratio: float = float(leafed) / float(w * h)
	# 세 롤이 **독립**이면 칸이 낙엽을 받을 확률은 1-(1-d)^3다. 종전(마지막 성분이 k)에는 세 롤의
	# 답이 늘 같아 그 확률이 정확히 d로 접혔다 — 즉 «칸당 3알갱이»가 실질 1알갱이였다.
	var want: float = 1.0 - pow(1.0 - d, 3.0)
	_check("⑫c 낙엽 칸 비율 %.3f가 «세 번 독립» 기대 %.3f에 든다(접힌 답은 d=%.3f 근처였다)"
			% [ratio, want, d],
		ratio >= want * 0.75 and ratio <= want * 1.25 and ratio > d * 1.5)

# ── ⑬ #12 캐노피 변주가 행마다 같은 무늬를 반복하지 않는다 ───────────────────
func _check_canopy_variation(m: Node) -> void:
	print("⑬ #12 캐노피 변주 인덱스 ↔ 격자 규칙성")
	_check("⑬a 배선: 캐노피·성숙목 두 창구가 같은 처방을 쓴다(형제 창구 정렬)",
		_count_in(_src, "func _collect_forest_canopy",
			"absi(rand_from_seed(hash(\"canopy:%s:%d:%d\"") == 1
		and _count_in(_src, "func _collect_forest_tree_art",
			"absi(rand_from_seed(hash(\"ledgertree:%s:%d:%d\"") == 1)
	var mix: Array = m._CANOPY_MIX_JEOSEUNG
	var items: Array = []
	m._collect_forest_canopy(items)
	_check("⑬b 무대: 캐노피 후보가 %d점 섰다(mix %d칸)" % [items.size(), mix.size()],
		items.size() > 20 and mix.size() > 1)
	if items.size() <= 20:
		return
	# `_forest_item`의 `key`가 곧 발치 행이라 그것으로 행을 묶는다(앵커 y는 텍스처 높이만큼 밀린다).
	var rows: Dictionary = {}
	for it in items:
		var k: int = int(it["key"])
		if not rows.has(k):
			rows[k] = []
		rows[k].append({"x": int(it["tile"].x), "tex": it["tex"]})
	# ★ 재는 것은 발견물이 실측으로 지목한 **그 증상 두 개**다(모델을 세우지 않는다 — djb2의
	#   자릿수 올림 때문에 «인덱스 = x의 아핀식»도 «4점 주기»도 성립하다 말다 해서, 그 둘로 만든
	#   초안 지표는 파괴에 안 죽었다. 실측 로그로 갈아탄 자리다):
	#   ㉠ 특별 나무가 한 행 안에서 **정확히 mix 한 바퀴(8칸) 간격**에 선다.
	#     파괴 실측 — 저승 숲 두 행이 x = 12·20·38·46 / 13·21·39·47이었다(간격열 8·18·8).
	#   ㉡ **서로 다른 행이 같은 간격열**을 반복한다(위 두 행이 글자 단위로 같다 = 반칸 엇갈림이
	#     무력해진 그 증거).
	var gaps_total := 0
	var gaps_lattice := 0
	var sigs: Dictionary = {}
	for k in rows:
		var arr: Array = rows[k]
		arr.sort_custom(func(a, b): return int(a["x"]) < int(b["x"]))
		var sx: Array = []
		for e in arr:
			if e["tex"] != mix[0]:
				sx.append(int(e["x"]))
		if sx.size() < 2:
			continue
		var sig := ""
		for q in range(1, sx.size()):
			var g: int = int(sx[q]) - int(sx[q - 1])
			gaps_total += 1
			if g == mix.size():
				gaps_lattice += 1
			sig += "%d," % g
		if sx.size() >= 3:
			sigs[sig] = int(sigs.get(sig, 0)) + 1
	var dup_rows := 0
	for sg in sigs:
		if int(sigs[sg]) > 1:
			dup_rows += int(sigs[sg])
	_check("⑬c 특별 나무 간격 %d개 중 «정확히 %d칸» %d개(%.0f%%) — 격자면 대다수가 그 값이다"
			% [gaps_total, mix.size(), gaps_lattice,
				100.0 * float(gaps_lattice) / maxf(1.0, float(gaps_total))],
		gaps_total >= 4 and float(gaps_lattice) < float(gaps_total) * 0.5)
	_check("⑬d 간격열이 겹치는 행 %d개 / 표본 %d개 — 종전엔 두 행이 글자 단위로 같았다"
			% [dup_rows, sigs.size()],
		dup_rows == 0)

# ── ⑭ #13 방목 문 [F]가 화면에서 광고된다 ────────────────────────────────────
func _check_pasture_door_ad(m: Node) -> void:
	print("⑭ #13 방목 문 [F] ↔ 키 광고")
	_check("⑭a 무대 전제: 저장소에 방목 문 **집행부**가 서 있다(광고만 없던 자리)",
		_count_in(_src, "func _process", "_indoor in ANIMAL_BUILDINGS and Input.is_action_just_pressed") == 1)
	var barn: String = m.ANIMAL_BUILDINGS[0]
	var beast := Vector2i(-1, -1)
	for tile in m.ranch._animals.keys():
		if String(m.ranch._animals[tile].get("home_building", "")) == barn:
			beast = tile
			break
	_check("⑭b 무대: %s에 짐승이 있다 %s" % [barn, str(beast)], beast.x >= 0)
	if beast.x < 0:
		return
	# 문 상태 두 갈래를 **프로덕션 문자열 그대로** 받는다(프롬프트는 `_process` 안이라 프레임을 태운다).
	m._region = RegionCatalog.HOME
	m._indoor = barn
	m._sleeping = false
	m._transitioning = false
	m._target = beast + Vector2i(0, 1) if not m.ranch.has_animal_at(beast + Vector2i(0, 1)) else beast + Vector2i(1, 0)
	m.ranch.set_door(barn, false)
	await process_frame
	await process_frame
	var closed_txt: String = m.interact_prompt.text
	m.ranch.set_door(barn, true)
	await process_frame
	await process_frame
	var open_txt: String = m.interact_prompt.text
	_check("⑭c 닫힘일 때 화면이 키와 상태를 말한다 — 「%s」" % closed_txt,
		closed_txt.contains("[F] 방목 문") and closed_txt.contains("지금 닫힘"))
	_check("⑭d 열림일 때 문구가 따라간다 — 「%s」" % open_txt,
		open_txt.contains("[F] 방목 문") and open_txt.contains("지금 열림"))
	m.ranch.set_door(barn, false)
	m._indoor = ""

# ── ⑮ #14 «오늘 돌봄 완료»가 실제 완료일 때만 뜬다 ───────────────────────────
func _check_animal_care_honesty(m: Node) -> void:
	print("⑮ #14 짐승 프롬프트 ↔ 급여·청소")
	var beast := Vector2i(-1, -1)
	for tile in m.ranch._animals.keys():
		beast = tile
		break
	_check("⑮a 무대: 짐승 한 마리를 잡았다 %s" % str(beast), beast.x >= 0)
	if beast.x < 0:
		return
	var a: Dictionary = m.ranch._animals[beast]
	a["product"] = 0
	a["petted"] = true
	a["fed"] = false
	a["cleaned"] = false
	# 손에 건초가 없으면 종전 `parts`는 비어 «완료»로 떨어졌다(급여는 건초를 들었을 때만 판정).
	m.inventory.add_item(ItemCatalog.HOE, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == ItemCatalog.HOE:
			m.inventory.select(i)
			break
	var txt: String = m._animal_prompt(beast)
	_check("⑮b 미급여·미청소인데 «완료»라 말하지 않는다 — 「%s」" % txt,
		not txt.contains("오늘 돌봄 완료") and txt.contains("급여") and txt.contains("청소"))
	a["fed"] = true
	a["cleaned"] = true
	var txt2: String = m._animal_prompt(beast)
	_check("⑮c 셋을 다 하면 그때 «완료»다 — 「%s」" % txt2, txt2.contains("오늘 돌봄 완료"))

# ── ⑯ #16 방목지에 선 짐승은 새 날에도 방목 중이다 ───────────────────────────
func _check_pasture_graze_carry() -> void:
	print("⑯ #16 실외 고립 ↔ 방목 가산")
	var r := Ranch.new()
	var t := Vector2i(2, 2)
	var barn := "넋둥우리"
	_check("⑯a 무대: 짐승을 %s에 들였다" % barn,
		r.add_animal(t, AnimalCatalog.ids()[0], barn))
	r.set_door(barn, true)
	_check("⑯b 무대: 문이 열려 방목지로 나갔다(grazed)",
		r.send_to_pasture(t, Vector2i(9, 9)) and r.is_outside(t))
	r.set_door(barn, false)                      # 오후에 문을 닫았다 = 밤에 실외 고립
	var night: Dictionary = r.settle_night()
	_check("⑯c 무대: 실외 고립으로 남았다(귀가 0 · 노출 %d)" % int(night.get("exposed", 0)),
		int(night.get("exposed", 0)) == 1 and r.is_outside(t))
	r.advance_day()
	_check("⑯d 새 아침에도 **방목 중이다** — 원장이 자기 위치와 어긋나지 않는다(그림·`_grazing_animal_at`은 «방목 중»이라 말한다)",
		r.is_outside(t) and r._animals[t]["grazed"])
	# 대조군 — 실내에 있는 짐승은 새 아침에 grazed가 꺼져 있어야 한다(과잉 적용 0).
	var t2 := Vector2i(3, 3)
	r.add_animal(t2, AnimalCatalog.ids()[0], barn)
	r.settle_night()
	r.advance_day()
	_check("⑯e 대조군: 실내 짐승은 새 아침에 grazed가 꺼져 있다(문을 열어야 그날 방목이 선다)",
		not r.is_outside(t2) and not r._animals[t2]["grazed"])
	r.free()

# ── ⑰ #17 AoE 프롬프트가 집행부와 같은 범위를 본다 ───────────────────────────
func _check_aoe_prompt(m: Node) -> void:
	print("⑰ #17 티어 AoE ↔ 프롬프트 침묵")
	_check("⑰a 배선: 두 갈래가 AoE 술어를 문다(조준 칸 단독 판정 0)",
		_count_in(_src, "func _farm_prompt", "_hoe_aoe_has_work()") == 1
		and _count_in(_src, "func _farm_prompt", "_water_aoe_has_work()") == 1)
	m._indoor = ""
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)
	await process_frame
	# 밭 흙 한 줄을 찾아 조준 칸만 갈아 둔다(그 너머는 미경작 — 종전엔 여기서 화면이 침묵했다).
	# ★ 일렬 AoE는 **바라보는 방향**으로 뻗는다(`_tool_aoe_tiles` — dir = 조준 칸 − 발 칸).
	#   그래서 무대는 «플레이어가 위, 조준 칸이 아래»로 세워야 티어 범위가 실제로 성립한다
	#   (초안은 발 위치를 안 세워 dir이 ZERO였고, 그러면 0티어와 같은 한 칸짜리 AoE가 된다).
	var t := Vector2i(-1, -1)
	for y in range(m.STARTER_PATCH_RECT.position.y + 1, m.STARTER_PATCH_RECT.end.y - 2):
		for x in range(m.STARTER_PATCH_RECT.position.x, m.STARTER_PATCH_RECT.end.x):
			var c := Vector2i(x, y)
			if m._is_farmable(c) and m._is_farmable(c + Vector2i(0, 1)) \
					and not m.farm.is_tilled(c) and not m.farm.is_tilled(c + Vector2i(0, 1)):
				t = c
				break
		if t.x >= 0:
			break
	_check("⑰b 무대: 조준 칸 %s와 그 아래 칸이 둘 다 경작 가능하다" % str(t), t.x >= 0)
	if t.x < 0:
		return
	m.player.position = m._tile_center_px(t - Vector2i(0, 1))
	m.farm.hoe(t)
	m.tool_tier.set_tier(ItemCatalog.HOE, 1)     # 명동 괭이 = 세로 3칸
	var aoe: Vector2i = m.tool_aoe(ItemCatalog.HOE)
	m._target = t
	var span: Array = m._farm_aoe_tiles(t, aoe)
	_check("⑰c 무대: 티어 AoE %s가 조준 칸 밖으로 %d칸 더 뻗는다(0티어면 이 어긋남이 존재하지 않는다)"
			% [str(aoe), span.size() - 1],
		aoe != Vector2i(1, 1) and span.size() > 1)
	m.energy.refill()
	m.inventory.add_item(ItemCatalog.HOE, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == ItemCatalog.HOE:
			m.inventory.select(i)
			break
	m._target = t
	m._target_valid = true
	var p: String = m._farm_prompt()
	_check("⑰d 조준 칸은 이미 갈렸지만 AoE 안에 갈 칸이 있어 **화면이 말한다** — 「%s」" % p,
		m.farm.is_tilled(t) and p.contains("괭이질"))
	# 대조군 — AoE 전체가 이미 갈렸으면 종전대로 침묵한다(과잉 광고 0).
	for at: Vector2i in m._farm_aoe_tiles(t, aoe):
		m._field_at(at).hoe(at)
	var p2: String = m._farm_prompt()
	_check("⑰e 대조군: AoE가 통째로 갈린 뒤엔 괭이질을 광고하지 않는다 — 「%s」" % p2,
		not p2.contains("괭이질"))
	m.tool_tier.set_tier(ItemCatalog.HOE, 0)

# ── ⑱ #18 모루 상호작용 칸이 아트 폭을 따른다 ────────────────────────────────
func _check_anvil_tiles(m: Node) -> void:
	print("⑱ #18 모루 아트 ↔ 상호작용 칸")
	_check("⑱a 배선: 겨눔 판정이 칸 **표**를 문다(단일 칸 비교 0 — 실행·프롬프트가 이 하나를 공유한다)",
		_count_in(_src, "func _process", "_smithy_anvil_tiles().has(_target)") == 1
		and _count_in(_src, "func _process", "_target == SMITHY_UPGRADE_TILE") == 0)
	var tiles: Array = m._smithy_anvil_tiles()
	var w: int = int(m.SMITHY_TEX_ANVIL.get_size().x) / m.TILE
	_check("⑱b 칸 수가 **아트 폭 파생**이다(%d칸 = 텍스처 %dpx / 타일 %dpx — 좌표 복제 0)"
			% [tiles.size(), int(m.SMITHY_TEX_ANVIL.get_size().x), m.TILE],
		tiles.size() == w and w == 2)
	_check("⑱c 그림이 덮는 두 칸이 다 들어 있다 — 왼쪽 %s·오른쪽 %s(종전엔 오른쪽만 열렸다)"
			% [str(m.SMITHY_UPGRADE_TILE - Vector2i(1, 0)), str(m.SMITHY_UPGRADE_TILE)],
		tiles.has(m.SMITHY_UPGRADE_TILE) and tiles.has(m.SMITHY_UPGRADE_TILE - Vector2i(1, 0)))

# ── ⑲ #19 광맥 타수 눈금이 «4/3타»를 안 낸다 ─────────────────────────────────
func _check_node_hits_fold(m: Node) -> void:
	print("⑲ #19 광맥 타수 눈금 ↔ 티어 교체")
	_check("⑲a 배선: 갱도·나락 두 문구가 분자를 분모로 접는다(그림 쪽 R15 clampf의 글자판)",
		_count_in(_src, "func _process",
			"mini(mine_floors.node_hits_done(_mine_floor, _target), m_need)") == 1
		and _count_in(_src, "func _process",
			"mini(narak_floors.node_hits_done(_narak_depth, _target), n_need)") == 1)
	# 무대가 실재하는가 — 티어를 올리면 need가 이미 친 타수 **아래로** 내려가는 종이 있는가.
	var gem := ""
	for nid in MineFloors.node_kinds():
		# done의 현실적 최댓값은 need0 − 1이다(need0째 타에 깨진다) — 그것이 need2를 넘어야
		#   «다 친 것보다 필요 타수가 적은데 광맥이 서 있는» 그 프레임이 성립한다.
		if MineFloors.node_hits(String(nid), 0) - 1 > MineFloors.node_hits(String(nid), 2):
			gem = String(nid)
			break
	_check("⑲b 무대: 티어로 타수가 줄어드는 광맥 「%s」(%d타 → %d타)"
			% [gem, MineFloors.node_hits(gem, 0), MineFloors.node_hits(gem, 2)],
		gem != "")
	if gem == "":
		return
	var t := Vector2i(5, 5)
	var need0: int = MineFloors.node_hits(gem, 0)
	var need2: int = MineFloors.node_hits(gem, 2)
	for _i in (need0 - 1):
		m.mine_floors.add_node_hit(1, t)
	var done: int = m.mine_floors.node_hits_done(1, t)
	_check("⑲c 무대: 0티어로 %d타 친 뒤 2티어 요구가 %d타 — 분자가 분모를 **넘는다**(눈금이 거짓말할 조건)"
			% [done, need2],
		done > need2)
	_check("⑲d 접은 값은 분모를 안 넘는다(%d/%d — 종전 표시는 %d/%d였다)"
			% [mini(done, need2), need2, done, need2],
		mini(done, need2) == need2)

# ── ⑳ #21 시련 납품 풀이 깊이 술어에서 나온다 ────────────────────────────────
func _check_trial_deliver_pool() -> void:
	print("⑳ #21 시련 납품 풀 ↔ 깊이 단일 술어")
	var pool: Array = TrialGround.deliver_pool()
	_check("⑳a 풀이 비어 있지 않다(%d종)" % pool.size(), not pool.is_empty())
	# ㉠ 전량이 깊이 게이트를 넘는다 — «1층 왕복으로 끝나는 시련» 0.
	var shallow: Array = []
	for id in pool:
		if not MineFloors.is_depth_gated(String(id)):
			shallow.append(String(id))
	_check("⑳b 풀 전량이 `is_depth_gated`를 통과한다(1층 산출 잔존: %s)" % str(shallow),
		shallow.is_empty())
	_check("⑳c 종전에 들어 있던 1층 산출 둘이 빠졌다(넋알돌·넋수정 — `mine_floors`가 「1층에서 손에 넣을 수 있는 물건」이라 적은 그 둘)",
		not pool.has(ItemCatalog.GEM_NEOKSUJEONG) and not pool.has(ItemCatalog.GEODE_NEOKAL))
	# ㉡ 나락철 — NODE_TABLE에 없는 종이라 술어가 false를 준다(보부상이 이름으로 뺀 그 물건).
	_check("⑳d 나락철 광석이 표적이 아니다(도구 4티어 최종 재료 — 시련은 5~9개를 **소각**한다)",
		not pool.has(ItemCatalog.ORE_NARAKCHEOL))
	# ㉢ 상한은 그대로다(깊이와 다른 것을 막는다 — 초희귀 유입 통제).
	_check("⑳e 상한도 그대로다 — 명부금강(깊이 게이트 통과·정가 상한 초과)은 여전히 밖이다",
		not pool.has(ItemCatalog.GEM_MYEONGBU_GEUMGANG))
	# ㉣ 깊이 게이트를 넘고 상한 안이면 값이 싸도 든다(옛 하한 50이 잘라내던 쪽).
	_check("⑳f 깊이를 넘으면 값이 싸도 든다 — 명옥·업화알돌과 함께 21·41층 저가종도 후보다(%d종)" % pool.size(),
		pool.has(ItemCatalog.GEM_MYEONGOK) and pool.has(ItemCatalog.GEODE_EOPHWA)
			and pool.size() > 2)
