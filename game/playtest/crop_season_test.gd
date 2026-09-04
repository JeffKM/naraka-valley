extends SceneTree
# ★[S7-T2 / ADR-0065 결정 2] 작물 절기 — 스키마·사멸 패스·제철 매대·메뉴 로테이션 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 스키마 — 전 작물(14종)이 유효 절기 인덱스를 들고, 절기당 재배 가능 작물이 최소 1종이며,
#      불사과만 사철(빈 배열)+multi_seasonal이다. 야생·혼합은 WILD_INFO 절기와 어긋나지 않는다.
#   ② 사멸 패스 — 절기 첫날 아침, 밭의 비제철 작물만 스러진다. 제철·다절기 작물은 살고,
#      흙(경작)·비료는 남으며(remove_plant 재사용의 증거), 과수는 통째로 불참한다(ADR-0045).
#      비전환일엔 아무것도 안 스러진다.
#   ③ 만물상 매대 — 씨앗 진열이 그 절기 것만으로 갈리고, 표시명에 절기가 병기된다.
#      다절기 씨앗(불사과)은 원래 미판매라 필터와 무관하다.
#   ④ 카페 메뉴 로테이션 — 작물 시그니처 메뉴가 그 작물의 절기에만 팔리고, 비제철이면
#      주문 풀(_cafe_order_pool)에서 실제로 빠진다("작물 사멸이 곧 메뉴 로테이션").
#
# ★ field.gd는 한 줄도 안 바뀌었다 — 사멸은 까마귀가 쓰던 remove_plant를 되쓰는 main 별도 패스다.
#   그래서 이 테스트도 밭 API를 새로 배우지 않고 기존 표면(hoe/plant/fertilize/is_planted)만 쓴다.
#
# 실행: ./run_tests.sh crop_season   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame
	return m

# 밭 한 칸을 경작하고 심는다(기존 표면만 사용 — 헬퍼는 테스트 스코프).
func _plant(m: Node, t: Vector2i, crop_id: String) -> void:
	m.farm.hoe(t)
	m.farm.plant(t, crop_id)

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S7-T2 작물 절기(사멸·제철 매대·메뉴 로테이션) 검증 ══")

	# ── ① 스키마 ────────────────────────────────────────────────────────────
	print("── ① seasons 스키마 ──")
	var bad_schema := ""
	for cid in CropCatalog.CATALOG.keys():
		var d: Dictionary = CropCatalog.CATALOG[cid]
		if not d.has("seasons") or typeof(d["seasons"]) != TYPE_ARRAY:
			bad_schema = "%s: seasons 필드 없음/배열 아님" % cid
			continue
		var seen: Array = []
		for s in d["seasons"]:
			if typeof(s) != TYPE_INT or int(s) < 0 or int(s) > 3:
				bad_schema = "%s: 절기 인덱스 이탈(%s)" % [cid, str(s)]
			if seen.has(s):
				bad_schema = "%s: 절기 중복(%s)" % [cid, str(s)]
			seen.append(s)
	_check("①a 전 작물이 유효 절기 배열을 든다(0..3·중복 0)%s"
		% ("" if bad_schema == "" else " — " + bad_schema), bad_schema == "")
	_check("①b 카탈로그 14종(로스터 5 + 야생·혼합 9)", CropCatalog.CATALOG.size() == 14)

	# 절기당 최소 1종(다절기 제외) — 매대·재배가 어느 절기에도 안 비는지가 이 단언의 본체다.
	var per_season := [0, 0, 0, 0]
	for cid2 in CropCatalog.ids():
		if CropCatalog.is_multi_seasonal(String(cid2)):
			continue
		for s2 in CropCatalog.seasons_of(String(cid2)):
			per_season[int(s2)] += 1
	_check("①c 절기당 재배 가능 작물 ≥1종 (피안%d·유화%d·망연%d·성야%d)" % per_season,
		per_season.min() >= 1)
	# 앵커 배정(ADR-0065 결정 2 확정분) — 여기가 갈리면 사멸·매대·메뉴가 통째로 어긋난다.
	_check("①d 앵커 배정 — 혼령초=유화 · 황천포도=망연 · 영혼호박=성야 · 피안화=피안",
		CropCatalog.seasons_of(CropCatalog.HONRYEONGCHO) == [1]
		and CropCatalog.seasons_of(CropCatalog.HWANGCHEON_PODO) == [2]
		and CropCatalog.seasons_of(CropCatalog.YEONGHON_HOBAK) == [3]
		and CropCatalog.seasons_of(CropCatalog.PIANHWA) == [0])
	_check("①e 불사과 = 사철(빈 배열) ∧ multi_seasonal(사멸을 두 번 비껴간다)",
		CropCatalog.seasons_of(CropCatalog.BULSAGWA).is_empty()
		and CropCatalog.is_multi_seasonal(CropCatalog.BULSAGWA))
	var only_bulsagwa := true
	for cid3 in CropCatalog.ids():
		var always: bool = CropCatalog.seasons_of(String(cid3)).is_empty()
		if always != (String(cid3) == CropCatalog.BULSAGWA):
			only_bulsagwa = false
	_check("①f 로스터에서 사철은 불사과 하나뿐(나머지는 전부 절기를 탄다)", only_bulsagwa)
	# 야생·혼합 = WILD_INFO 절기와 정합(모둠은 그 절기 숲 일반종을, 모종은 그 절기 희소종을 낸다).
	var wild_ok := true
	for wid in CropCatalog.WILD_INFO.keys():
		var want: int = int(CropCatalog.WILD_INFO[wid]["season"])
		if CropCatalog.seasons_of(String(wid)) != [want]:
			wild_ok = false
	_check("①g 야생 8종 절기 = WILD_INFO 절기와 일치(채집 풀과 모순 0)", wild_ok)
	_check("①h 혼합 씨앗 = 사철(심는 순간 치환되는 유령 엔트리라 판정에 안 걸린다)",
		CropCatalog.seasons_of(CropCatalog.MIXED).is_empty())
	# 판정 함수 계약.
	_check("①i in_season — 빈 배열은 전 절기 true",
		CropCatalog.in_season(CropCatalog.BULSAGWA, 0) and CropCatalog.in_season(CropCatalog.BULSAGWA, 3))
	_check("①j in_season — 절기종은 그 절기에만 true",
		CropCatalog.in_season(CropCatalog.HONRYEONGCHO, 1)
		and not CropCatalog.in_season(CropCatalog.HONRYEONGCHO, 0)
		and not CropCatalog.in_season(CropCatalog.HONRYEONGCHO, 3))
	_check("①k 미지 id는 사철로 떨어진다(사멸 안전 방향 — 모르는 작물을 지우지 않는다)",
		CropCatalog.seasons_of("없는_작물").is_empty() and CropCatalog.in_season("없는_작물", 2))
	_check("①l season_label = GameClock 절기명 파생('' = 사철)",
		CropCatalog.season_label(CropCatalog.HONRYEONGCHO) == "유화절"
		and CropCatalog.season_label(CropCatalog.BULSAGWA) == "")

	# ── ② 사멸 패스(절기 첫날 아침) ─────────────────────────────────────────
	print("── ② 절기 사멸 패스 ──")
	var m: Node = await _spawn_main()
	# 세이브 재개분 격리 — 사멸 집계를 이 테스트가 심은 칸으로만 좁힌다.
	for t0 in m.farm.planted_tiles():
		m.farm.remove_plant(t0)
	# ★[폴리시 R20] **축 격리 — 잡초 확산을 끈다.** 이 섹션은 «절기 사멸»만 재는데, 절기 첫날 아침엔
	#   같은 훅에서 잡초 확산(ADR-0065 결정 7)도 돌고 그쪽은 작물을 **파괴 대상으로 통과시킨다**
	#   (`DEST_CROP`). 게다가 절기 1일은 SPREAD_WET_MULT ×2로 확산이 가장 사나운 날이라, 심어 둔
	#   칸이 사멸이 아니라 잡초에 먹혀 사라질 수 있다 — 실제로 R20에서 후보 풀이 한 그루만큼
	#   달라지자(과수 성역 추가) 굴림이 옮겨 붙어 불사과 칸이 잡초에 먹혔다. 사멸 축을 재는 단언이
	#   확산 굴림에 흔들리면 회귀가 늙는다.
	#   확산의 씨앗은 **레이아웃 시드 잡초**(`_seed_weed_sources`)뿐이므로 그것을 치운 자리로
	#   표시하면 그 축이 통째로 꺼진다(사멸·재스폰 축은 그대로 돈다).
	for wt in m._seed_weed_sources():
		m.reclaim._cleared[wt] = true
	m._on_reclaim_changed()
	# day 28(피안절 마지막) → day 29(유화절 1일). 새 절기 = 유화(1)이므로 혼령초만 제철이다.
	m.clock.day = 28
	var t_keep := Vector2i(58, 45)    # 혼령초(유화) — 새 절기 제철이라 살아야 한다
	var t_pian := Vector2i(59, 45)    # 피안화(피안) — 지난 절기라 스러진다
	var t_podo := Vector2i(60, 45)    # 황천포도(망연·트렐리스) — 비제철
	var t_hobak := Vector2i(61, 45)   # 영혼 호박(성야) — 비제철
	var t_multi := Vector2i(62, 45)   # 불사과 — 다절기라 사멸 제외
	var t_wild := Vector2i(63, 45)    # 야생 모둠(피안) — 제작 씨앗도 같은 규칙을 탄다
	_plant(m, t_keep, CropCatalog.HONRYEONGCHO)
	_plant(m, t_pian, CropCatalog.PIANHWA)
	_plant(m, t_podo, CropCatalog.HWANGCHEON_PODO)
	_plant(m, t_hobak, CropCatalog.YEONGHON_HOBAK)
	_plant(m, t_multi, CropCatalog.BULSAGWA)
	_plant(m, t_wild, CropCatalog.WILD_PIAN)
	m.farm.fertilize(t_pian, ItemCatalog.FERT_BASIC)   # 사멸 후에도 남아야 하는 것
	# 과수 대조군 — 혼의 나무는 절기가 결실을 멈출 뿐 죽지 않는다(ADR-0045 불가침).
	var tree_anchor := Vector2i(58, 50)
	var tree_id: String = FruitTreeCatalog.ids()[0]
	var planted_tree: bool = m.orchard.plant(tree_anchor, tree_id, 28, func(_t): return false)
	_check("②pre 6칸 심김 + 과수 1그루(대조군)",
		m.farm.planted_tiles().size() == 6 and planted_tree and m.orchard.has_tree(tree_anchor))
	_check("②pre2 새 절기는 유화절(1) — 혼령초만 제철",
		GameClock.is_season_first_day(29) and GameClock.season_index_for_day(29) == 1)

	m.clock.day = 29
	m._on_day_advanced(29)
	await process_frame

	_check("②a 비제철 3종이 스러졌다(피안화·황천포도·영혼 호박)",
		not m.farm.is_planted(t_pian) and not m.farm.is_planted(t_podo)
		and not m.farm.is_planted(t_hobak))
	_check("②b 제철 작물(혼령초)은 살아남는다 — 사멸은 전멸이 아니다",
		m.farm.is_planted(t_keep) and m.farm.crop_of(t_keep) == CropCatalog.HONRYEONGCHO)
	_check("②c 다절기 작물(불사과)은 생존 — multi_seasonal 첫 프로덕션 소비",
		m.farm.is_planted(t_multi))
	_check("②d 야생 모둠(피안)도 같은 규칙으로 스러진다", not m.farm.is_planted(t_wild))
	_check("②e 흙(경작)은 남는다 — 다음 날 바로 다시 심을 수 있다",
		m.farm.is_tilled(t_pian) and m.farm.is_tilled(t_podo))
	_check("②f 비료도 남는다(remove_plant 재사용의 증거 — field.gd 무수정)",
		m.farm.fertilizer_of(t_pian) == ItemCatalog.FERT_BASIC)
	_check("②g 밭에 남은 작물은 정확히 2칸(제철 + 다절기)", m.farm.planted_tiles().size() == 2)
	_check("②h ★과수 불참 — 혼의 나무는 절기가 갈려도 그대로 서 있다(ADR-0045)",
		m.orchard.has_tree(tree_anchor) and m.orchard.fruit_id_of(tree_anchor) == tree_id)

	# 비전환일엔 아무 일도 없다 — 사멸은 절기 첫날 아침 단 하루의 의식이다.
	_plant(m, t_pian, CropCatalog.PIANHWA)      # 유화절 한복판에 비제철을 심어 본다(심기 자체는 자유)
	m.clock.day = 30
	m._on_day_advanced(30)
	await process_frame
	_check("②i 비전환일(day 30)엔 비제철도 안 스러진다(심기 자유 유지)", m.farm.is_planted(t_pian))
	_check("②j day 30은 전환일이 아니다(단언에 이빨)", not GameClock.is_season_first_day(30))
	# 다음 전환(day 57 = 망연절 1일)엔 이번엔 혼령초가 스러지고 황천포도가 제철이 된다(방향 대칭).
	_plant(m, t_podo, CropCatalog.HWANGCHEON_PODO)
	m.clock.day = 57
	m._on_day_advanced(57)
	await process_frame
	_check("②k 다음 전환(망연절 1일) — 혼령초가 스러지고 황천포도가 남는다(대칭 확인)",
		not m.farm.is_planted(t_keep) and m.farm.is_planted(t_podo)
		and m.farm.is_planted(t_multi))

	# ── ③ 만물상 제철 매대 ──────────────────────────────────────────────────
	print("── ③ 만물상 제철 씨앗 매대 ──")
	var season_first_day := [1, 29, 57, 85]
	var store_ok := true
	var tag_ok := true
	var bulsagwa_absent := true
	for si in 4:
		m.clock.day = int(season_first_day[si])
		var rows: Array = m._store_items()
		var seed_ids: Array = []
		for r in rows:
			if String((r as Dictionary)["kind"]) == "seed":
				seed_ids.append(String((r as Dictionary)["buy_id"]))
				if not String((r as Dictionary)["name"]).ends_with(" (%s)" % GameClock.season_name(si)):
					tag_ok = false
			if String((r as Dictionary)["buy_id"]) == CropCatalog.BULSAGWA:
				bulsagwa_absent = false
		var want_ids: Array = []
		for cid4 in CropCatalog.ids():
			if String(cid4) != CropCatalog.BULSAGWA and CropCatalog.in_season(String(cid4), si):
				want_ids.append(String(cid4))
		if seed_ids != want_ids or seed_ids.is_empty():
			store_ok = false
			print("     (절기 %d — 진열 %s / 기대 %s)" % [si, str(seed_ids), str(want_ids)])
	_check("③a 절기 4곳 전부 — 씨앗 진열 = 그 절기 작물뿐(그리고 절대 비지 않는다)", store_ok)
	_check("③b 씨앗 표시명에 절기 병기(\"혼령초 씨앗 (유화절)\")", tag_ok)
	_check("③c 불사과 씨앗은 어느 절기에도 안 선다(채집 전용 — 기존 노출 규칙 보존)", bulsagwa_absent)
	m.clock.day = 29
	var rows29: Array = m._store_items()
	_check("③d 유화절 매대엔 혼령초만·피안화는 없다",
		rows29.any(func(r): return r["buy_id"] == CropCatalog.HONRYEONGCHO)
		and rows29.all(func(r): return r["buy_id"] != CropCatalog.PIANHWA))
	# ★[S10-T5 발견] 8 → 9. 이 단언은 S7-T2 시점의 매대(묘목1·비료5·건초1·스프링클러1 = 8행)를
	#   센 것인데, **[S10-T2]가 만물상에 레어크로우 상시 재고 1행을 얹으면서** 9행이 됐고 이 숫자가
	#   같이 갱신되지 않아 잠복 실패로 남아 있었다(S10-T5 선별 회귀가 검출 — 늘봄방·화분과 무관).
	#   ★ 재발 방지로 **행 종류를 명시**한다: 숫자만 세면 다음 슬라이스가 또 조용히 깨뜨린다.
	var nonseed29: Array = rows29.filter(func(r): return r["kind"] != "seed")
	var nonseed_kinds: Dictionary = {}
	for r5 in nonseed29:
		nonseed_kinds[String(r5["kind"])] = int(nonseed_kinds.get(String(r5["kind"]), 0)) + 1
	_check("③e 씨앗 밖 품목(묘목·비료·건초·설치물·레어크로우)은 절기와 무관하게 그대로",
		nonseed29.size() == 9 and nonseed_kinds.get("sapling", 0) == 1
		and nonseed_kinds.get("fert", 0) == 5 and nonseed_kinds.get("hay", 0) == 1
		and nonseed_kinds.get("placeable", 0) == 1 and nonseed_kinds.get("rarecrow", 0) == 1)

	# ── ④ 카페 메뉴 로테이션(작물 사멸 = 메뉴 로테이션) ──────────────────────
	print("── ④ 메뉴 절기 로테이션 ──")
	var crop_menu_season := {
		MenuCatalog.PIANHWA_ADE: 0, MenuCatalog.HONRYEONGCHO_LATTE: 1,
		MenuCatalog.PODO_SMOOTHIE: 2, MenuCatalog.HOBAK_LATTE: 3,
	}
	var menu_ok := true
	for mid in crop_menu_season.keys():
		for s3 in 4:
			if MenuCatalog.in_season(String(mid), s3) != (int(crop_menu_season[mid]) == s3):
				menu_ok = false
	_check("④a 작물 메뉴 4종 = 시그니처 작물의 절기에만 팔린다", menu_ok)
	var tart_ok := true
	for s4 in 4:
		if not MenuCatalog.in_season(MenuCatalog.BULSAGWA_TART, s4):
			tart_ok = false
	_check("④b 다절기 작물 메뉴(불사과 타르트)는 사철 — 작물 축의 예외가 산다", tart_ok)
	# 주문 풀 실효 — 해금된 메뉴라도 비제철이면 후보에서 빠진다(cafe_order_test ⑤ 문법).
	m.inventory.add_item(CropCatalog.PIANHWA, 1, 0)    # 발견 게이트 통과(획득 관문 하나)
	_check("④pre 피안화 에이드 해금", m._menu_unlocked(MenuCatalog.PIANHWA_ADE))
	m.clock.day = 1                                     # 피안절
	var pool_in: Array = m._cafe_order_pool()
	m.clock.day = 29                                    # 유화절
	var pool_out: Array = m._cafe_order_pool()
	var has_in := pool_in.any(func(e): return String((e as Dictionary)["id"]) == MenuCatalog.PIANHWA_ADE)
	var has_out := pool_out.any(func(e): return String((e as Dictionary)["id"]) == MenuCatalog.PIANHWA_ADE)
	_check("④c 제철(피안절) 주문 풀에 피안화 에이드가 있다", has_in)
	_check("④d 비제철(유화절) 주문 풀에서 빠진다 — 사멸이 메뉴판까지 간다", not has_out)
	# 풀 전체가 절기를 지키는지(개별 메뉴가 아니라 규칙 자체).
	var pool_clean := true
	for si2 in 4:
		m.clock.day = int(season_first_day[si2])
		for e3 in m._cafe_order_pool():
			if not MenuCatalog.in_season(String((e3 as Dictionary)["id"]), si2):
				pool_clean = false
	_check("④e 어느 절기에도 주문 풀에 비제철 메뉴가 섞이지 않는다", pool_clean)

	m.queue_free()
	await process_frame

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)
