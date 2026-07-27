extends SceneTree
# ★ [S2-T6 / ADR-0060 결정 6] 게시판 의뢰(일일 + 중기 납품형) 검증(ephemeral 헤드리스 단위검증).
# 코드에 게시판이 아예 없던 상태에서 의뢰 생성·수락·납품·만료·세이브가 붙었는지 본다.
#
# ★ 핵심 불변식:
#   ① 결정성 — 같은 day면 항상 같은 의뢰(비결정 랜덤 금지)·다른 day면 상이할 수 있다. 대상 아이템은
#      실존 소스 풀(작물 + 채집물 + ★[S3-T8] 물고기) 소속이고 처치 유형이 없다. 수량·기한이 스펙 범위 안.
#      ★[S3-T8] 물고기 갈래는 *별도 시드*라 비-물고기 날의 의뢰는 S2-T6 수열과 바이트 동일(①k).
#   ② 수락→납품→보상 — 골드 = 일반품질 판매가 × 3 × 수량 정확·의뢰인 호감도 가산·아이템 차감.
#   ③ 동시 1건 — 수락 중이면 새 수락 거부(일일·중기 통틀어).
#   ④ 기한 경과 만료·무페널티 — 골드·호감도 불변으로 조용히 소멸한다.
#   ⑤ 세이브 라운드트립 — 수락 계약·완료 이력이 새 인스턴스로 재개(키 없는 구버전 = 빈 원장 하위호환).
#   ⑥ 중기 의뢰 — 주 시드 결정적·주당 1건·수량 큼·기한 그 주 끝·호감도 일일의 2배.
#   ⑦ main 배선 — 게시판 칸이 만물상 문·문 앞·스포크를 안 막는 SOLID 그레이박스이고,
#      _try_accept_quest/_try_deliver_quest가 골드·인벤·호감도까지 실제로 잇는다.
# 실행: godot --headless --path game --script res://playtest/quest_board_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# ★ 나루 마을 리빌드가 ~4s 걸린다(단일출처 지형 파이프라인) — museum_test 계열보다 넉넉히 8s 상한.
func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 8000   # 안전 상한(좀비 방지)
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

func _initialize() -> void:
	print("══ S2-T6 게시판 의뢰(일일·중기 납품형) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s2t6_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	# 첫 인스턴스가 옛/오염 세이브로 부팅되지 않게 spawn 전에 지운다(store_test 격리 교훈).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 결정성·풀·범위(순수 단위 — 인스턴스 불필요) ──
	print("── ① 의뢰 생성 결정성·풀 ──")
	var q7a := QuestBoard.daily_quest(7)
	var q7b := QuestBoard.daily_quest(7)
	_check("①a 같은 day = 같은 의뢰(결정적)", q7a == q7b)
	var pool := QuestBoard.item_pool()
	_check("①b 대상 풀 = 작물 5 + 채집물 1(실존 소스만)",
		pool.size() == CropCatalog.ids().size() + ItemCatalog.FORAGEABLES.size())
	var pool_ok := true
	for pid in pool:
		if not ItemCatalog.has_item(String(pid)) or ItemCatalog.category_of(String(pid)) != ItemCatalog.CAT_HARVEST:
			pool_ok = false
	_check("①c 풀 전원 = 유효 수확물 아이템(처치·낚시 유형 없음)", pool_ok)
	# 하루씩 112일(1년)치를 훑어 범위·소속·기한·의뢰인을 전수 확인하고, 변주가 실제로 생기는지도 본다.
	# ★[S3-T8] 물고기 날은 물고기 규칙(절기 가용·체급 상한·FISH_CLIENTS)을, 아닌 날은 기존 규칙을 본다.
	var range_ok := true
	var member_ok := true
	var due_ok := true
	var client_ok := true
	var gold_ok := true
	var fish_season_ok := true
	var fish_class_ok := true
	var legacy_intact := true
	var fish_days := 0
	var crop_days := 0
	var seen := {}
	for d in range(1, 113):
		var q := QuestBoard.daily_quest(d)
		var qid := String(q["item_id"])
		var cnt := int(q["count"])
		if cnt < QuestBoard.DAILY_COUNT_MIN or cnt > QuestBoard.DAILY_COUNT_MAX:
			range_ok = false
		if int(q["due_day"]) != d + QuestBoard.DAILY_SPAN_DAYS - 1:
			due_ok = false
		if int(q["gold"]) != ItemCatalog.price_of(qid, ItemCatalog.Q_NORMAL) * QuestBoard.REWARD_MULT * cnt:
			gold_ok = false
		if FishCatalog.has(qid):
			fish_days += 1
			if not QuestBoard.FISH_CLIENTS.has(String(q["client"])):
				client_ok = false
			# 그날 절기에 실제로 낚이는 어종만 출제(전설·대어 배제 = quest_pool 상한 중 체급).
			if not FishCatalog.quest_pool(GameClock.season_index_for_day(d), FishCatalog.WC_MEDIUM).has(qid):
				fish_season_ok = false
			if FishCatalog.weight_class_of(qid) > FishCatalog.WC_MEDIUM:
				fish_class_ok = false
		else:
			crop_days += 1
			if not pool.has(qid):
				member_ok = false
			if not QuestBoard.CLIENTS.has(String(q["client"])):
				client_ok = false
			# ★[S3-T8] 비-물고기 날 = 기존 _make 경로와 바이트 동일(작물/채집 의뢰 시드 수열 보존).
			if q != QuestBoard._make(QuestBoard.KIND_DAILY, d, d, d + QuestBoard.DAILY_SPAN_DAYS - 1,
					QuestBoard.DAILY_COUNT_MIN, QuestBoard.DAILY_COUNT_MAX, QuestBoard.DAILY_AFFINITY):
				legacy_intact = false
		seen["%s×%d" % [qid, cnt]] = true
	_check("①d 수량 1~3(전 112일)", range_ok)
	_check("①e 비-물고기 날 대상 id 전부 기존 풀 소속", member_ok)
	_check("①f 기한 = 게시일 포함 2일", due_ok)
	_check("①g 의뢰인 = 유형별 풀 소속(물고기 날만 뱃사공 허용)", client_ok)
	_check("①h 보상 골드 = 일반품질가 ×3 ×수량(유형 무관 동일 공식)", gold_ok)
	_check("①i 다른 day면 의뢰가 갈린다(112일에 조합 3종 이상 — 실측 %d)" % seen.size(), seen.size() >= 3)
	_check("①j 일일 호감도 = 선물 1회급", int(q7a["affinity"]) == Affinity.GIFT_POINTS)
	_check("①k 비-물고기 날 = S2-T6 경로와 바이트 동일(결정성 회귀 0)", legacy_intact)
	_check("①l 물고기 날·작물 날이 공존한다(112일 실측 물고기 %d·작물 %d)" % [fish_days, crop_days],
		fish_days > 0 and crop_days > 0)
	_check("①m 물고기 의뢰 = 현 절기 가용종·중 체급 이하만(전설·대어 0)", fish_season_ok and fish_class_ok)

	# ── ⑥ 중기 의뢰(주 시드) ──
	print("── ⑥ 중기 의뢰 ──")
	_check("⑥a 주 인덱스 — 1~7일=0주 · 8일=1주",
		QuestBoard.week_of(1) == 0 and QuestBoard.week_of(7) == 0 and QuestBoard.week_of(8) == 1)
	var w0a := QuestBoard.weekly_quest(0)
	var w0b := QuestBoard.weekly_quest(0)
	_check("⑥b 같은 주 = 같은 의뢰(결정적)", w0a == w0b)
	_check("⑥c 기한 = 그 주 마지막 날(0주 → 7일 · 1주 → 14일)",
		int(w0a["due_day"]) == 7 and int(QuestBoard.weekly_quest(1)["due_day"]) == 14)
	# ★[S3-T8] 중기도 물고기 갈래 분기 — 물고기 주는 소 체급 한정·수량 4~6, 작물 주는 기존 5~8.
	var wrange_ok := true
	var wgold_ok := true
	var wfish_ok := true
	var fish_weeks := 0
	for w in range(0, 16):
		var wq := QuestBoard.weekly_quest(w)
		var wid := String(wq["item_id"])
		var wc := int(wq["count"])
		if FishCatalog.has(wid):
			fish_weeks += 1
			if wc < QuestBoard.WEEKLY_FISH_COUNT_MIN or wc > QuestBoard.WEEKLY_FISH_COUNT_MAX \
					or FishCatalog.weight_class_of(wid) != FishCatalog.WC_SMALL:
				wfish_ok = false
		elif wc < QuestBoard.WEEKLY_COUNT_MIN or wc > QuestBoard.WEEKLY_COUNT_MAX:
			wrange_ok = false
		if int(wq["gold"]) != ItemCatalog.price_of(wid, ItemCatalog.Q_NORMAL) * QuestBoard.REWARD_MULT * wc:
			wgold_ok = false
	_check("⑥d 중기 수량 — 작물 5~8·물고기 4~6(소 체급 한정, 물고기 주 실측 %d)" % fish_weeks,
		wrange_ok and wfish_ok)
	_check("⑥e 중기 보상 공식 = 일일과 같은 배수", wgold_ok)
	_check("⑥f 중기 호감도 = 일일의 2배",
		int(w0a["affinity"]) == 2 * int(q7a["affinity"]) and QuestBoard.WEEKLY_AFFINITY == 2 * QuestBoard.DAILY_AFFINITY)

	var m: Node = await _spawn_main()
	await _settle(m)

	# ── ⑦pre 게시판 배치(만물상 문·동선 비침범) ──
	print("── ⑦ 게시판 배치 ──")
	m.player.position = m._tile_center_px(Vector2i(78, 32))   # ★C2 동쪽 길 워프 → 마을
	m._maybe_warp_edge()
	await _settle(m)
	_check("⑦pre 나루 마을로 워프", m._region == RegionCatalog.NARU_VILLAGE)
	var bt: Vector2i = m.QUEST_BOARD_TILE
	_check("⑦a 게시판 칸 = SOLID 그레이박스(WALL)", m._grid[bt.y][bt.x] == m.WALL)
	_check("⑦b 만물상 문·문 앞 칸을 안 막는다",
		bt != m.STORE_EXT_DOOR and bt != m.STORE_EXT_DOOR + Vector2i(0, 1))
	_check("⑦c 만물상 외관 rect 밖(외관 아트 비침범)", not m.STORE_EXT_RECT.has_point(bt))
	# 문 스포크(만물상 문 x열 세로 PATH)와 안 겹치고, 플레이어가 설 칸(바로 아래)은 걸을 수 있어야 한다.
	var spoke_ok := true
	for y in range(m.STORE_EXT_DOOR.y, m.MAIN_CORRIDOR_Y + 1):
		if Vector2i(m.STORE_EXT_DOOR.x, y) == bt:
			spoke_ok = false
	_check("⑦d 만물상 문 스포크(x=%d 세로 길)와 비겹침" % m.STORE_EXT_DOOR.x, spoke_ok)
	var stand: Vector2i = bt + Vector2i(0, 1)
	_check("⑦e 바로 아래(플레이어 자리)는 걷기 O", not m.is_solid(m._grid[stand.y][stand.x]))
	# 주민 집 rect와도 안 겹친다(동편 조닝 침범 방지).
	var house_ok := true
	for r in m.RESIDENT_HOUSE_RECTS:
		if (r as Rect2i).has_point(bt):
			house_ok = false
	_check("⑦f 주민 집 11채 rect 밖", house_ok)

	# ── ③ 동시 1건 수락 ──
	print("── ③ 동시 1건 수락 ──")
	var qb: Node = m.quest_board
	qb.active = {}
	qb.completed = []
	var day: int = m.clock.day
	m._try_accept_quest(QuestBoard.KIND_DAILY)
	_check("③a 일일 수락 성공(active 세팅)", qb.is_active()
		and String(qb.active["kind"]) == QuestBoard.KIND_DAILY)
	var first_key: String = String(qb.active["key"])
	m._try_accept_quest(QuestBoard.KIND_WEEKLY)
	_check("③b 수락 중엔 중기 수락 거부(active 불변)", String(qb.active["key"]) == first_key)
	m._try_accept_quest(QuestBoard.KIND_DAILY)
	_check("③c 수락 중엔 일일 재수락도 거부", String(qb.active["key"]) == first_key)
	_check("③d can_accept = false", not qb.can_accept())

	# ── ② 납품→보상(골드·호감도·차감) ──
	print("── ② 납품 보상 ──")
	var item_id: String = String(qb.active["item_id"])
	var need: int = int(qb.active["count"])
	var client: String = String(qb.active["client"])
	var expect_gold: int = ItemCatalog.price_of(item_id, ItemCatalog.Q_NORMAL) * QuestBoard.REWARD_MULT * need
	var af: Node = m._quest_client_affinity(client)
	_check("②pre 의뢰인 affinity 다리 연결(%s)" % client, af != null)
	# ★[S3-T8] 새 의뢰인 뱃사공도 다리가 성립한다(Resident 등록·affinity 보유 — 어느 유형이 걸리든).
	_check("②pre2 뱃사공 affinity 다리 연결", m._quest_client_affinity("뱃사공") != null)
	af.points = 0
	m.wallet.gold = 0
	# 수량 부족 상태 = 아무것도 안 일어난다(부분 납품 없음).
	while m.inventory.count_of(item_id) > 0:
		m.inventory.remove_item(item_id, m.inventory.count_of(item_id))
	if need > 1:
		m.inventory.add_item(item_id, need - 1)
	m._try_deliver_quest()
	_check("②a 수량 부족 = 무동작(수락 유지·골드 0·아이템 불변)",
		qb.is_active() and m.wallet.gold == 0 and m.inventory.count_of(item_id) == maxi(need - 1, 0))
	# 충족 상태 = 차감·골드·호감도.
	m.inventory.add_item(item_id, need + 1 - m.inventory.count_of(item_id))
	var have0: int = m.inventory.count_of(item_id)
	m._try_deliver_quest()
	_check("②b 골드 = 일반품질가 ×3 ×수량(%d)" % expect_gold, m.wallet.gold == expect_gold)
	_check("②c 인벤 차감 = 요구 수량", m.inventory.count_of(item_id) == have0 - need)
	_check("②d 의뢰인 호감도 가산 = %d" % QuestBoard.DAILY_AFFINITY, af.points == QuestBoard.DAILY_AFFINITY)
	_check("②e 완료 후 active 비고 이력 기록", not qb.is_active() and qb.is_completed(first_key))
	# 같은 의뢰 중복 완료 방지 — 완료한 의뢰는 게시판에서 빠진다.
	m._try_accept_quest(QuestBoard.KIND_DAILY)
	_check("②f 완료한 일일 의뢰는 재수락 불가(중복 완료 방지)", not qb.is_active())

	# ── ④ 기한 경과 만료(무페널티) ──
	print("── ④ 기한 만료 ──")
	qb.active = {}
	qb.completed = []
	var mq := QuestBoard.daily_quest(day)
	_check("④a 기한 안이면 수락 성립", qb.accept(mq, day))
	m.wallet.gold = 500
	af.points = 42
	_check("④b 기한 당일(due_day)엔 안 만료", qb.advance_day(int(mq["due_day"])).is_empty() and qb.is_active())
	var expired: Dictionary = qb.advance_day(int(mq["due_day"]) + 1)
	_check("④c 기한 다음 날 만료(active 비움)", not expired.is_empty() and not qb.is_active())
	_check("④d 무페널티 — 골드·호감도 불변", m.wallet.gold == 500 and af.points == 42)
	_check("④e 만료분은 완료 이력에 안 들어간다(재게시 가능)", not qb.is_completed(String(mq["key"])))
	# 만료된 계약은 다시 수락할 수 없다(기한이 이미 지났으므로).
	_check("④f 기한 지난 의뢰는 수락 거부", not qb.accept(mq, int(mq["due_day"]) + 1))

	# ── ⑤ 세이브 라운드트립 ──
	print("── ⑤ 세이브 라운드트립 ──")
	qb.active = {}
	qb.completed = []
	var sq := QuestBoard.daily_quest(day)
	qb.accept(sq, day)
	qb.completed.append("daily:99")   # 과거 완료 이력 1건
	var save_key: String = String(qb.active["key"])
	var save_count: int = int(qb.active["count"])
	var save_hist: Array = qb.completed.duplicate()
	m._save_game()
	m.queue_free()
	await process_frame
	await process_frame
	var m2: Node = await _spawn_main()
	await _settle(m2)
	_check("⑤a 수락 계약 재개(key·수량 보존)", m2.quest_board.is_active()
		and String(m2.quest_board.active["key"]) == save_key
		and int(m2.quest_board.active["count"]) == save_count)
	_check("⑤b 완료 이력 재개", m2.quest_board.completed == save_hist)
	# 구버전 세이브 하위호환 — "quest_board" 키가 아예 없는 dict를 먹여도 안 깨지고 빈 원장이 된다.
	m2.quest_board.load_save({})
	_check("⑤c 키 없는 구버전 = 빈 원장(하위호환)",
		not m2.quest_board.is_active() and m2.quest_board.completed.is_empty())
	m2.queue_free()
	await process_frame

	# ── 정리: 세이브 원복 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)
