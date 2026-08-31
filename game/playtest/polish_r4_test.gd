extends SceneTree
# ★[폴리시 4회차 · 배치 A] 버그 헌트 확정분 회귀 — 입력 디스패치 경계 · R3 부작용 · 카탈로그 무결성 · 경제 배선.
#
# polish_r3_test가 "날이 바뀌는 순간 상태가 새지 않는다"를 잰다면, 여기는 **"한 번 누른 키가 한 번만
# 집행된다"**와 **"표가 실물 id를 가리킨다"**를 잰다.
#
# 무엇을 보증하나(발견 번호 = 4회차 헌트 배치 A):
#   ① #6/#9 입력 디스패치 누수 — 디스패치 단계(`_input`·`_gui_input`)에서 세계를 바꾼 창구가 그
#      프레임 폴링을 삼킨다. 타이틀 [이어하기] Enter → 집 안 취침 / 모달 [X] 클릭 → 괭이질·설치.
#   ② #7 갱도·나락 LMB 게이트 — 조준 칸을 안 보는 손 물건(명부환·곁들이·계단)이 SOIL 없는 무대에서도
#      `_use_tool`에 닿는다(계단이 쓸 수 있는 유일한 무대에서 100% 불발이던 자리).
#   ③ #8 집 안 화분 수확(RMB)이 같은 프레임에 취침까지 집행하지 않는다.
#   ④ #10 채집 창구 넷이 [F]를 집으면 사슬 맨 끝의 휘파람이 안 돈다(12712 규약의 실제 집행).
#   ⑤ #11 레어크로우 노지 필터가 **HOME의 세로**를 본다 — 집 밖에서 날이 바뀌어도 허수아비가 안 사라진다
#      (동시에 R3 #22 "실내 허수아비는 노지를 못 지킨다" 불변식은 그대로 산다).
#   ⑥ #5 표시명 유일성 — 의뢰 풀 안에서 두 아이템이 같은 이름을 쓰지 않는다(피안화 ↔ 야생 피안화).
#   ⑦ #1 야시장 혼합 씨앗 — 소매 정가의 출처가 잔가(seed_cost(MIXED))가 아니고, 표시가와 결제가가
#      같은 출처를 보며, 어느 절기에서도 정규 씨앗보다 싸지 않다.
#   ⑧ #12 `_load_game`이 밀린 절기 재스폰 표를 버린다(F9 뒤 엉뚱한 날의 대량 재스폰 차단).
#
# ── 배치 B(발견 #13~#23) — 게이트 우회 · 무대 경계 · 적재 먼저 · 표시 진실성 ────────────
#   ⑨ #13/#14 매대 재고 풀이 **깊이 게이트 너머의 산출**(불사과·저승삼)을 팔지 않는다. 만물상의
#      옛 하드코딩 분기와 보부상의 손 목록이 이제 한 술어(`ForageSpawns.is_deep_gated`)를 본다.
#   ⑩ #17 물뿌리개 리필의 혼우물 가지가 구역·실내를 본다(물타일 가지는 전 구역 그대로).
#   ⑪ #18/#19 "한 칸에 둘 금지"가 양방향이고(레어크로우 위 업화로 차단) 원장이 무대를 본다
#      (안식 스프링클러가 다른 구역의 같은 좌표를 조용히 막던 자리).
#   ⑫ #16/#20 늘봄방 예정지 8×7이 **예약 부지**다 — 설치물이 안 놓이고 프롭이 발치까지 안 침범한다
#      (완공이 그 rect를 WALL로 덮어 설치물·나무 슬롯을 영구 매장하던 자리).
#   ⑬ #15 나락 채굴도 채광 축의 반딧넋·책 드랍을 굴린다(갱도 전용 배선이던 훅 둘).
#   ⑭ #21/#22 야생 수확·숲 줍기·꽃 따기가 **적재 자리부터** 본다(R2가 노지·화분에 세운 규율의 미커버 3경로).
#   ⑮ #23 매대 보유 수량이 어느 가게에서나 렌더러가 읽는 `count` 키로 실린다.
#
# ★ 디스패치 순서(②③④)는 `_process` 안의 지역 변수라 함수 호출로 재현할 수 없다 — 그래서 "그
#   게이트 줄이 실제로 그 가드를 달고 있나"를 **main 소스에서 줄 단위로** 대조하고(peddler_test ⑫·
#   trial_ground_test 라우팅 대조와 같은 관례), 그 가드가 서는 근거(술어·좌표 사실)는 따로 실호출로 잰다.
#
# 실행: ./run_tests.sh polish_r4   (헤드리스는 반드시 game/에서 · 순차)

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

func _dismiss_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 60:
		m.dialogue.advance()
		guard += 1

# main.gd 소스에서 needle이 든 줄의 인덱스(-1 = 없음). needle은 위 니들 유일성을 전제한다.
func _line_of(needle: String) -> int:
	for i in _src.size():
		if _src[i].contains(needle):
			return i
	return -1

func _initialize() -> void:
	print("══ 폴리시 4회차 배치 A — 입력 경계 · R3 부작용 · 카탈로그 · 경제 배선 회귀 ══")
	_src = FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().split("\n")
	var save0 := SaveManager.slot_path(0)
	if FileAccess.file_exists(save0):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save0))
	var m := await _spawn_main()
	_dismiss_dialogue(m)

	# ── ① #6/#9 입력 디스패치 단계 → 같은 프레임 폴링 누수 ──────────────────────
	# Godot은 한 iteration에서 입력 디스패치를 `_process`보다 먼저 흘리는데, main은 모든 월드 동사를
	# `Input.is_action_just_pressed`(전역 폴링)로 받는다 — `accept_event()`가 통하지 않는 그 자리다.
	print("── ① #6/#9 디스패치 단계가 세운 표를 _process가 삼킨다 ──")
	m.readout.text = "SENTINEL"
	m._swallow_input_once = true
	m._process(0.0)
	_check("①a 표가 서면 `_process`가 입력 구간을 통째로 건너뛴다(월드 디스패치·취침 폴링 미도달)",
		m.readout.text == "SENTINEL" and not m._swallow_input_once)
	m._process(0.0)
	_check("①b 그 다음 프레임은 그대로 흐른다 — 한 프레임만 삼킨다(입력 영구 사망 0)",
		m.readout.text != "SENTINEL")
	# #9 모달 우상단 [X] — inv_frame `_gui_input`이 곧바로 부르는 그 핸들러.
	m._open_frame(InventoryFrame.CTX_MENU)
	_check("①c 모달이 실제로 열렸다(이동 잠금·핫바 숨김)",
		m.frame.is_open() and not m.hotbar.visible)
	m._on_frame_close_pressed()
	_check("①d [X]는 그 자리에서 닫되(프레임 닫힘·핫바 복귀) 그 프레임 폴링을 삼킬 표를 세운다",
		not m.frame.is_open() and m.hotbar.visible and m._swallow_input_once)
	m._swallow_input_once = false
	# Esc 닫기(`_close_frame` 직행)는 그 자리에서 return하므로 표를 안 세운다 — 삼키는 범위를 좁힌 증거.
	m._open_frame(InventoryFrame.CTX_MENU)
	m._close_frame()
	_check("①e Esc 경로(`_close_frame` 직행)는 표를 안 세운다(모달 가드가 이미 return한다)",
		not m.frame.is_open() and not m._swallow_input_once)

	# ── ② #7 갱도·나락 LMB 게이트 ────────────────────────────────────────────
	print("── ② #7 조준 칸을 안 보는 손 물건이 SOIL 없는 무대에서도 산다 ──")
	_check("②a 술어가 세 부류를 모두 문다 — 명부환·곁들이·계단",
		m._is_free_use_item(ItemCatalog.MYEONGBUHWAN)
		and m._is_free_use_item(String(MenuCatalog.side_dish_ids()[0]))
		and m._is_free_use_item(ItemCatalog.STAIRS))
	_check("②b 그리고 밭 도구·씨앗은 안 문다(게이트가 넓어진 게 아니라 셋만 얹혔다)",
		not m._is_free_use_item(ItemCatalog.HOE)
		and not m._is_free_use_item(ItemCatalog.WATERING_CAN)
		and not m._is_free_use_item(ItemCatalog.seed_id(CropCatalog.PIANHWA)))
	var gate_i := _line_of("or holding_weapon or pot_at_target or holding_free_use")
	_check("②c LMB 디스패치 게이트가 그 술어를 or-항으로 단다(main.gd:%d)" % (gate_i + 1), gate_i >= 0)
	# 게이트가 필요한 이유 = 층 안엔 밭 흙이 한 칸도 없다. 그 사실을 실호출로 못 박는다.
	var mine_like := Vector2i(1, 1)   # 안식 그리드에서도 밭이 아닌 칸(집·길·풀 어느 쪽이든 SOIL 아님)
	_check("②d 밭이 아닌 칸은 `_is_farmable`이 거짓이다(= 옛 게이트의 유일한 참 조건이 층 안엔 없다)",
		not m._is_farmable(mine_like))
	# ★ 층 판정(`_in_mine_floor`)만 흉내 낸다 — 그리드 재빌드 없이 술어만 잰다(뒤 절들을 위해 즉시 복원).
	var saved_floor: int = m._mine_floor
	var saved_region: String = m._region
	m._region = RegionCatalog.EOPHWA_MINE
	m._mine_floor = 3
	_check("②e 그런데 계단은 그 무대에서 실제로 쓸 수 있다(`_can_use_stairs` 참) — 종전엔 디스패치가 그 앞에서 죽었다",
		m._can_use_stairs())
	m._mine_floor = saved_floor
	m._region = saved_region

	# ── ③ #8 집 안 화분 수확이 취침까지 집행하지 않는다 ────────────────────────
	print("── ③ #8 화분 수확(RMB) ⊗ 취침(RMB) ──")
	# 근거 사실: 화분이 서는 곳(집 실내)과 취침 가능 구역이 **같은 칸에서 겹친다**.
	var saved_indoor: String = m._indoor
	m._indoor = "집"
	var house: Rect2i = m.home_house_rect()
	var pot_t := Vector2i(house.position.x + 2, house.position.y + 2)
	_check("③a 집 실내 칸은 화분을 놓을 수 있고(`_can_place_pot`) 동시에 취침 구역이다(`_zone_at` = 집)",
		m._can_place_pot(pot_t) and m._zone_at(m._tile_center_px(pot_t)) == "집")
	var sleep_i := _line_of("_can_sleep() and Input.is_action_just_pressed(\"action\")")
	_check("③b 그래서 RMB 취침 줄이 \"이 프레임의 RMB를 수확이 이미 썼나\"를 먼저 본다(main.gd:%d)"
			% (sleep_i + 1),
		sleep_i >= 0 and _src[sleep_i].contains("not harvest_took_rmb"))
	m._indoor = saved_indoor

	# ── ④ #10 [F] 사슬 — 채집 창구가 집으면 휘파람은 안 돈다 ────────────────────
	print("── ④ #10 휘파람([F])이 앞선 창구와 같은 프레임에 겹치지 않는다 ──")
	var f_windows := ["_pick_forage(_target)", "_shake_bush(_target)",
		"_pan_spot(_target)", "_gather_firefly(_target)"]
	var f_missing: Array = []
	for w in f_windows:
		var wi := _line_of(w)
		if wi < 0 or not _src[wi + 1].contains("f_taken"):
			f_missing.append(w)
	_check("④a 채집 창구 넷이 각자 [F] 소비를 표시한다 — 채집물·덤불·팬닝·반딧넋(누락: %s)"
			% str(f_missing), f_missing.is_empty())
	_check("④b 사슬 맨 끝 휘파람이 그 표를 본다(12712 \"아무도 안 집었을 때만\" 규약의 집행)",
		_line_of("not _sleeping and not f_taken and mount != null") >= 0)

	# ── ⑤ #11 레어크로우 노지 필터는 HOME의 세로를 본다 ────────────────────────
	print("── ⑤ #11 집 밖에서 날이 바뀌어도 허수아비가 사라지지 않는다 ──")
	var home_h: int = RegionCatalog.size_of(RegionCatalog.HOME).y
	var far_t := Vector2i(40, home_h - 15)     # HOME 남동 개간지 — 남의 구역 세로(40·44)보다 아래
	m.rarecrow.place(far_t, ItemCatalog.RARECROW_3)
	var saved_h: int = m._outdoor_h
	_check("⑤a 안식에 서 있으면 목록에 든다(기준선)", m._scarecrow_tiles().has(far_t))
	m._outdoor_h = RegionCatalog.size_of(RegionCatalog.SAMDOCHEON).y   # 삼도천에서 24:00을 맞은 상태
	_check("⑤b 삼도천 세로(%d)로 날이 바뀌어도 HOME 레어크로우 %s가 목록에 남는다"
			% [m._outdoor_h, far_t], m._scarecrow_tiles().has(far_t))
	m._outdoor_h = saved_h
	m.rarecrow.remove(far_t)
	# R3 #22 불변식은 그대로 살아 있어야 한다 — 실내 밴드(y ≥ HOME 외부 세로)는 여전히 걸린다.
	var indoor_t := Vector2i(far_t.x, home_h + 3)
	m.rarecrow.place(indoor_t, ItemCatalog.RARECROW_3)
	_check("⑤c 실내 밴드(y=%d ≥ %d) 레어크로우는 여전히 걸러진다(R3 #22 보호 누수 불변식 생존)"
			% [indoor_t.y, home_h], not m._scarecrow_tiles().has(indoor_t))
	m.rarecrow.remove(indoor_t)

	# ── ⑥ #5 의뢰 풀 표시명 유일성 ───────────────────────────────────────────
	print("── ⑥ #5 같은 이름을 쓰는 두 아이템이 없다 ──")
	var pool: Array = QuestBoard.item_pool()          # 분모 = 레지스트리 파생(작물 + 채집물)
	var seen: Dictionary = {}
	var name_dup: Array = []
	for pid in pool:
		var nm := ItemCatalog.name_of(String(pid))
		if seen.has(nm):
			name_dup.append("%s ↔ %s = \"%s\"" % [String(seen[nm]), String(pid), nm])
		else:
			seen[nm] = pid
	_check("⑥a 의뢰 풀 %d종의 표시명이 서로 유일하다(충돌: %s)" % [pool.size(), str(name_dup)],
		name_dup.is_empty())
	_check("⑥b 두 피안화가 화면에서 갈린다 — 밭 \"%s\" ↔ 채집 \"%s\""
			% [CropCatalog.name_of(CropCatalog.PIANHWA), ItemCatalog.name_of(ItemCatalog.SPIRIT_FLOWER)],
		ItemCatalog.name_of(ItemCatalog.SPIRIT_FLOWER) != ItemCatalog.name_of(CropCatalog.PIANHWA)
		and ItemCatalog.name_of(ItemCatalog.SPIRIT_FLOWER) != "")

	# ── ⑦ #1 야시장 혼합 씨앗 소매가 ──────────────────────────────────────────
	print("── ⑦ #1 혼합 씨앗이 정규 씨앗의 확정 대체품이 아니다 ──")
	var seed_row: Dictionary = {}
	for r in SeasonalEvent.market_rows():
		if String(r["kind"]) == "fest_seed":
			seed_row = r
	var seed_base := int(seed_row.get("base", 0))
	_check("⑦a 소매 정가의 출처가 잔가가 아니다 — base %d ≠ seed_cost(MIXED) %d"
			% [seed_base, CropCatalog.seed_cost(CropCatalog.MIXED)],
		not seed_row.is_empty() and seed_base != CropCatalog.seed_cost(CropCatalog.MIXED))
	_check("⑦b 정가 = 혼합이 될 수 있는 정규 작물의 최고 씨앗가(= 황천포도 %d냥)"
			% CropCatalog.seed_cost(CropCatalog.HWANGCHEON_PODO),
		CropCatalog.mixed_pool_max_seed_cost() == CropCatalog.seed_cost(CropCatalog.HWANGCHEON_PODO)
		and seed_base == CropCatalog.mixed_pool_max_seed_cost())
	# 어느 절기에서도 "혼합이 그 절기 정규 씨앗보다 싸다"가 성립하지 않는다(같은 매대·같은 할인 기준).
	var cheaper: Array = []
	for pool_i in CropCatalog.MIXED_POOLS.size():
		for cid in CropCatalog.MIXED_POOLS[pool_i]:
			var mixed_price := SeasonalEvent.market_price(seed_base)
			var real_price := SeasonalEvent.market_price(CropCatalog.seed_cost(String(cid)))
			if mixed_price < real_price:
				cheaper.append("%s(%d < %d)" % [String(cid), mixed_price, real_price])
	_check("⑦c 절기 %d칸 어디서도 혼합이 정규 씨앗보다 싸지 않다(역전: %s)"
			% [CropCatalog.MIXED_POOLS.size(), str(cheaper)], cheaper.is_empty())
	# 표시가와 결제가가 같은 출처를 본다(R3 #19가 보부상에서 닫은 그 클래스).
	var shown := 0
	for row in m._night_market_items():
		if String(row["kind"]) == "fest_seed":
			shown = int(row["price"])
	_check("⑦d 매대 표시가 %d냥 = 결제 단가 출처(`market_price(market_seed_price())`)"
			% shown, shown == SeasonalEvent.market_price(SeasonalEvent.market_seed_price()))
	# 치환 표를 CropCatalog로 옮긴 뒤에도 절기별 치환이 그대로다(리팩터 안전판).
	var wrong_pool: Array = []
	for si in CropCatalog.MIXED_POOLS.size():
		var day_in_season := si * GameClock.DAYS_PER_SEASON + 1
		var got: String = m._mixed_crop_for(day_in_season, Vector2i(3, 3))
		if not CropCatalog.MIXED_POOLS[si].has(got):
			wrong_pool.append("절기%d→%s" % [si, got])
	_check("⑦e 절기별 치환이 그대로다 — 피안→피안화·유화→혼령초·망연→황천포도·성야→영혼호박(어긋남: %s)"
			% str(wrong_pool), wrong_pool.is_empty())

	# ── ⑨ #13/#14 매대가 깊이 게이트 너머의 산출을 팔지 않는다 ──────────────────
	print("── ⑨ #13/#14 보부상·만물상 재고 풀의 심층 게이트 ──")
	var deep: Array = ForageSpawns.species_for(ForageSpawns.KIND_DEEP, 0)
	_check("⑨a 술어의 분모가 심층 로스터 파생이다 — %s(일반종 넋고사리는 안 문다)" % str(deep),
		deep.size() >= 2 and ForageSpawns.is_deep_gated(CropCatalog.BULSAGWA)
		and ForageSpawns.is_deep_gated(ItemCatalog.JEOSEUNG_SAM)
		and not ForageSpawns.is_deep_gated(ItemCatalog.NEOK_GOSARI))
	var pool_hits: Array = []
	var pool_seed_ids: Array = []
	for row in Peddler.stock_pool():
		var pr: Dictionary = row
		var pid := String(pr["buy_id"])
		if String(pr["kind"]) == Peddler.KIND_SEED:
			pool_seed_ids.append(pid)
		if deep.has(pid):
			pool_hits.append("%s(%s)" % [pid, String(pr["kind"])])
	_check("⑨b 보부상 일반 풀에 심층 산출이 한 행도 없다 — 씨앗 루프·아이템 루프 양쪽(적발: %s)"
			% str(pool_hits), pool_hits.is_empty())
	# 정상 경로 생존(ADR-0008 "평평 ≠ 막힘") — 가드가 넓어져 풀이 마른 게 아니라 두 종만 빠졌다.
	_check("⑨c 정규 씨앗은 그대로 선다 — 풀의 씨앗 %d종 = 작물 %d종 − 심층 전용 1종"
			% [pool_seed_ids.size(), CropCatalog.ids().size()],
		pool_seed_ids.size() == CropCatalog.ids().size() - 1
		and pool_seed_ids.has(CropCatalog.HONRYEONGCHO) and not pool_seed_ids.has(CropCatalog.BULSAGWA))
	# 12주치 실제 좌판(가구·희귀 슬롯 포함)에도 안 뜬다 — 풀 필터가 최종 재고까지 관통하는가.
	var week_hits: Array = []
	for w in 12:
		var d := (w + 1) * Peddler.APPEAR_MODULUS
		for row in Peddler.stock_rows(d, [], {}):
			var rid := String((row as Dictionary)["buy_id"])
			if deep.has(rid):
				week_hits.append("day%d:%s" % [d, rid])
	_check("⑨d 출현일 12주치 좌판(일반 10 + 가구 + 희귀) 어디에도 안 뜬다 — 폴백 슬롯 포함(적발: %s)"
			% str(week_hits), week_hits.is_empty())
	var store_seed_ids: Array = []
	for row in m._store_items():
		if String((row as Dictionary)["kind"]) == "seed":
			store_seed_ids.append(String((row as Dictionary)["buy_id"]))
	_check("⑨e 만물상 씨앗 행에도 불사과가 없다(하드코딩 분기 → 같은 술어로 이관, 제철 필터와 무관)",
		not store_seed_ids.has(CropCatalog.BULSAGWA))

	# ── ⑩ #17 물뿌리개 리필이 혼우물이 선 무대에서만 된다 ──────────────────────
	print("── ⑩ #17 리필 대상 판정의 구역·실내 가드 ──")
	var well_t := Vector2i(m.WELL_RECT.position.x + 1, m.WELL_RECT.position.y + 1)
	var saved_reg2: String = m._region
	var saved_in2: String = m._indoor
	_check("⑩a 안식 농원 야외에서 혼우물 %s은 리필 대상이다(기준선)" % well_t,
		m._is_refill_target(well_t))
	m._region = RegionCatalog.NARU_VILLAGE
	_check("⑩b 같은 좌표라도 나루 마을에서는 아니다 — 그 구역엔 우물이 없다",
		not m._is_refill_target(well_t))
	m._region = saved_reg2
	m._indoor = "집"
	_check("⑩c 실내에서도 아니다(`_facing_mailbox`류 규약과 같은 두 축)", not m._is_refill_target(well_t))
	m._indoor = saved_in2
	# 물타일 가지는 전 구역 그대로다 — 좁힌 것은 "다른 구역엔 없는 건물" 한 채뿐이다.
	var water_t := Vector2i(-1, -1)
	for y in range(0, m._outdoor_h):
		for x in range(0, m._grid_w):
			if m._grid[y][x] == m.WATER:
				water_t = Vector2i(x, y)
				break
		if water_t.x >= 0:
			break
	m._region = RegionCatalog.NARU_VILLAGE
	_check("⑩d 물타일 %s은 어느 구역에서나 리필 대상으로 남는다(가드가 물까지 좁히지 않았다)" % water_t,
		water_t.x >= 0 and m._is_refill_target(water_t))
	m._region = saved_reg2

	# ── ⑪ #18/#19 설치물 겹침 가드가 양방향이고 무대를 본다 ─────────────────────
	print("── ⑪ #18/#19 한 칸에 둘 금지 · 원장의 구역 축 ──")
	var free_t := Vector2i(72, 3)   # 안식 북동 빈 잔디(프롭·debris·성역 밖 — 실측)
	_check("⑪a 기준선: 빈 칸엔 스프링클러도 업화로도 결정기도 놓을 수 있다",
		m._can_place_sprinkler(free_t) and m._can_place_furnace(free_t)
		and m._can_place_crystalarium(free_t))
	m.rarecrow.place(free_t, ItemCatalog.RARECROW_3)
	_check("⑪b 레어크로우가 선 칸엔 업화로·결정기가 못 선다(옛 단방향 가드가 빠뜨린 반쪽)",
		not m._can_place_furnace(free_t) and not m._can_place_crystalarium(free_t))
	_check("⑪c 반대 방향도 그대로다 — 그 칸엔 스프링클러도 못 선다(`_installation_at` 양방향)",
		not m._can_place_sprinkler(free_t) and not m._can_place_rarecrow(free_t))
	m.rarecrow.remove(free_t)
	m.sprinkler.place(free_t)
	_check("⑪d 스프링클러가 선 칸에도 업화로가 못 선다(겹침 판정 유지)", not m._can_place_furnace(free_t))
	m._region = RegionCatalog.NARU_VILLAGE
	_check("⑪e 그런데 **다른 구역의 같은 좌표**는 막지 않는다 — 스프링클러 원장의 좌표가 무대를 넘어 새던 자리",
		m._installation_at(free_t) == false and m._can_place_furnace(free_t))
	m._region = saved_reg2
	m.sprinkler.remove(free_t)

	# ── ⑫ #16/#20 늘봄방 예정지가 예약 부지다 ──────────────────────────────────
	print("── ⑫ #16/#20 완공이 덮어 매장하는 8×7을 미리 비워 둔다 ──")
	var lot: Rect2i = m.GREENHOUSE_EXT_RECT
	var lot_t := Vector2i(lot.position.x + 2, lot.position.y + 3)   # rect 한복판(완공 후 8이웃 전부 WALL)
	var above_t := Vector2i(lot_t.x, lot.position.y - 1)            # rect 바로 북쪽 한 칸(예약 밖)
	_check("⑫a 예정지 %s엔 스프링클러·레어크로우·업화로·결정기 어느 것도 못 놓는다" % lot_t,
		not m._can_place_sprinkler(lot_t) and not m._can_place_rarecrow(lot_t)
		and not m._can_place_furnace(lot_t) and not m._can_place_crystalarium(lot_t))
	_check("⑫b 예약은 그 rect에서 끝난다 — 바로 북쪽 %s은 그대로 놓인다(과잉 차단 0)" % above_t,
		m._can_place_sprinkler(above_t))
	m._region = RegionCatalog.NARU_VILLAGE
	_check("⑫c 다른 구역의 같은 좌표는 예약이 아니다(HOME 좌표 상수의 구역 축)",
		not m._greenhouse_lot_reserved(lot_t))
	m._region = saved_reg2
	m.carpenter._done[Carpenter.PROJ_GREENHOUSE] = true
	_check("⑫d 완공하면 예약이 풀린다 — 그 뒤엔 WALL이라 지면 검사가 이미 막는다(가드 이중화 0)",
		not m._greenhouse_lot_reserved(lot_t))
	m.carpenter._done.erase(Carpenter.PROJ_GREENHOUSE)
	# #20 — 그 rect 주석의 "프롭 무점유"를 실측으로 못 박는다(손저작 + 절차 스캐터 + 재스폰 debris 병합).
	var prop_hits: Array = []
	for entry in m._home_prop_entries():
		var tex: Texture2D = entry[0]
		var sz: Vector2 = tex.get_size()
		var tw: int = maxi(int(round(sz.x / 32.0)), 1)
		var th: int = maxi(int(round(sz.y / 32.0)), 1)
		for anchor in entry[1]:
			for dx in range(tw):
				for dy in range(th):
					if lot.has_point(anchor + Vector2i(dx, dy)):
						prop_hits.append("%s@%s" % [tex.resource_path.get_file(), anchor])
	_check("⑫e 예정지를 발치까지 침범하는 HOME 프롭이 0이다 — 앵커가 아니라 tw×th 풋프린트로 잰다(적발: %s)"
			% str(prop_hits), prop_hits.is_empty())
	var anchors: Array = m._home_tree_anchors()
	var buried: Array = anchors.filter(func(t: Vector2i) -> bool: return lot.has_point(t))
	_check("⑫f 나무 원장 시드 %d그루 중 예정지에 갇히는 슬롯이 없다(옛 (68,4)는 (68,1)로 이설)"
			% anchors.size(),
		buried.is_empty() and anchors.has(Vector2i(68, 1)) and not anchors.has(Vector2i(68, 4)))

	# ── ⑬ #15 나락 채굴도 채광 축의 드랍을 굴린다 ──────────────────────────────
	print("── ⑬ #15 갱도 전용이던 반딧넋·책 훅이 나락에도 선다 ──")
	var saved_depth: int = m._narak_depth
	var run_id: int = m.narak_floors.begin_run()   # 런을 열어 run_id ≥ 1로 만든다(serial 자리 대조가 실질이 되게)
	# 훅이 쓰는 것과 **같은 식**으로 serial을 조립해, 실제로 걸리는 (깊이, 칸)을 먼저 찾는다.
	var ff_hit := Vector3i(-1, -1, -1)
	var bk_hit := Vector3i(-1, -1, -1)
	for depth in range(1, 25):
		for y in range(1, 24):
			for x in range(1, 24):
				var s: int = run_id * 1000000000 + depth * 1000000 + y * 1000 + x
				if ff_hit.x < 0 and FireflySouls.peek_drop(FireflySouls.SRC_MINE, m.clock.day, s,
						m.fireflies.collected) != "":
					ff_hit = Vector3i(depth, x, y)
				if bk_hit.x < 0 and m.books.pending_drop(Books.SRC_MINE, m.clock.day, s) != "":
					bk_hit = Vector3i(depth, x, y)
			if ff_hit.x >= 0 and bk_hit.x >= 0:
				break
		if ff_hit.x >= 0 and bk_hit.x >= 0:
			break
	var ff_before: int = m.fireflies.collected_count()
	m._narak_depth = ff_hit.x
	m._award_narak_drop(Vector2i(ff_hit.y, ff_hit.z), "")   # "" = 일반 돌(광석 표 무관 — 훅만 잰다)
	_check("⑬a 나락 깊이 %d의 돌 한 칸이 반딧넋을 떨군다 — 안치 %d → %d(종전엔 롤 자체가 0회)"
			% [ff_hit.x, ff_before, m.fireflies.collected_count()],
		ff_hit.x > 0 and m.fireflies.collected_count() == ff_before + 1)
	var bk_before: int = m.books.acquired_count()
	m._narak_depth = bk_hit.x
	m._award_narak_drop(Vector2i(bk_hit.y, bk_hit.z), "")
	_check("⑬b 같은 자리에서 책·노트 훅도 산다 — 수집 %d → %d" % [bk_before, m.books.acquired_count()],
		bk_hit.x > 0 and m.books.acquired_count() == bk_before + 1)
	_dismiss_dialogue(m)   # 책은 주운 자리에서 그대로 펼쳐진다(인라인 즉독) — 뒤 절을 위해 닫는다
	m._narak_depth = saved_depth
	# serial 네임스페이스가 갱도와 안 겹친다 — 같은 (층, 칸)이어도 run_id 자리가 다르다.
	var mine_serial: int = ff_hit.x * 1000000 + ff_hit.z * 1000 + ff_hit.y
	var narak_serial: int = run_id * 1000000000 + mine_serial
	_check("⑬c 나락 serial(run %d)이 갱도 serial과 다른 값이다 — 같은 층·칸의 롤 복제 0"
			% run_id, run_id >= 1 and narak_serial != mine_serial)

	# ── ⑭ #21/#22 백팩이 가득이면 채집물이 증발하지 않는다 ─────────────────────
	# ★ 인벤을 통째로 채우므로 **세이브를 건드리는 ⑧ 바로 앞**에 둔다(앞 절들의 적재를 안 흔든다).
	print("── ⑭ #21/#22 야생 수확·숲 줍기·꽃 따기의 '적재 먼저' ──")
	var forage_species := String(ForageSpawns.species_for(ForageSpawns.KIND_COMMON, 0)[0])
	var filler: Array = ItemCatalog.MINERALS.keys() + ItemCatalog.MATERIALS.keys()
	var fi := 0
	for si in m.inventory.slots.size():
		while fi < filler.size() and (String(filler[fi]) == forage_species
				or String(filler[fi]) == ItemCatalog.SPIRIT_FLOWER):
			fi += 1
		m.inventory.slots[si] = {"id": String(filler[fi]), "count": 1, "quality": 0}
		fi += 1
	_check("⑭a 백팩 %d칸이 서로 다른 스택으로 가득 찼다(빈 칸 0 · 합칠 스택 0)" % m.inventory.slots.size(),
		not m.inventory.has_free_slot() and not m.inventory.can_add(forage_species, 1, 0)
		and not m.inventory.can_add(ItemCatalog.SPIRIT_FLOWER, 1, 0))
	# ㉠ 숲 채집물 줍기 — 스폰 칸이 지워지지 않고 발견 원장도 안 열린다.
	var fg_tile := Vector2i(9, 9)
	m.forage_spawns._tiles[RegionCatalog.HOME] = {fg_tile: forage_species}
	var found_before: bool = m._forage_found.has(forage_species)
	m._pick_forage(fg_tile)
	_check("⑭b 줍기 실패 시 스폰 칸이 그대로 남는다 — 그날 그 포기가 증발하지 않는다",
		m.forage_spawns.has_at(RegionCatalog.HOME, fg_tile)
		and m.forage_spawns.species_at(RegionCatalog.HOME, fg_tile) == forage_species)
	_check("⑭c 손에 쥔 적 없는 종이 발견 처리되지 않는다(희소종 씨앗 레시피 게이트가 안 열린다)",
		m._forage_found.has(forage_species) == found_before)
	m.forage_spawns._tiles.erase(RegionCatalog.HOME)
	# ㉡ 꽃 패치 따기 — 재생 타이머가 안 걸린다(딴 적이 없으므로 계속 활짝).
	var fl_tiles: Array = m.flower.bloomed_tiles()
	_check("⑭d 기준선: 활짝 핀 패치가 있다(%d칸)" % fl_tiles.size(), not fl_tiles.is_empty())
	var fl_t: Vector2i = fl_tiles[0]
	m._pick_flower(fl_t)
	_check("⑭e 따기 실패 시 꽃이 그대로 피어 있다 — 소진 뒤 토스트만 뜨던 자리", m.flower.is_bloomed(fl_t))
	# ㉢ 야생 작물 수확 — 밭 칸이 안 비고 점수판도 안 오른다.
	var wild_t := Vector2i(41, 13)   # 스타터 패치 안(SOIL)
	m.farm.hoe(wild_t)
	m.farm.plant(wild_t, CropCatalog.WILD_PIAN)
	m.farm._tiles[wild_t]["grown_days"] = 99   # 물 준 날수를 직접 세워 성숙시킨다(날 진행 없이)
	m._target = wild_t
	var harvested_before: int = m._run_harvested
	_check("⑭f 기준선: 야생 작물이 다 자랐다(수확 분기에 닿는다)", m.farm.is_mature(wild_t))
	m._try_harvest()
	_check("⑭g 수확 실패 시 밭 칸이 그대로다 — 노지·화분 두 형제와 같은 거절",
		m.farm.is_planted(wild_t) and m.farm.is_mature(wild_t))
	_check("⑭h 점수판도 안 오른다(거두지 못한 것을 거뒀다고 세지 않는다)",
		m._run_harvested == harvested_before)
	# 자리를 비우면 같은 손짓이 정상 통과한다 — 가드가 막힘이 아니라 대기임을 못 박는다(ADR-0008).
	m.inventory.slots[0] = null
	m._try_harvest()
	_check("⑭i 한 칸을 비우면 그 자리에서 거둬진다(가드 = 막힘이 아니라 대기)",
		not m.farm.is_planted(wild_t) and m._run_harvested == harvested_before + 1)
	for si in m.inventory.slots.size():
		m.inventory.slots[si] = null
	m.inventory.changed.emit()

	# ── ⑮ #23 매대 행의 보유 수량이 어느 가게에서나 같은 키로 실린다 ──────────
	print("── ⑮ #23 공용 렌더러가 읽는 키 하나로 통일 ──")
	# 오늘 매대에 실제로 서는 씨앗(제철 필터 통과분)을 골라 40개 들고 두 매대를 나란히 연다.
	var shop_seed := ""
	for row in m._store_items():
		if String((row as Dictionary)["kind"]) == "seed":
			shop_seed = String((row as Dictionary)["buy_id"])
			break
	m.inventory.add_seed(shop_seed, 40)
	var shops: Dictionary = {
		"만물상": m._store_items(), "생선가게": m._fishshop_items(),
		"목공방": m._woodshop_items(), "보부상": m._peddler_items(),
	}
	var stale_key: Array = []
	var row_n := 0
	for shop in shops:
		for row in shops[shop]:
			row_n += 1
			if (row as Dictionary).has("owned"):
				stale_key.append("%s:%s" % [shop, String((row as Dictionary).get("buy_id", "?"))])
	_check("⑮a 네 매대 %d행 어디에도 죽은 키 `owned`가 없다 — 렌더러가 안 읽는 키였다(적발: %s)"
			% [row_n, str(stale_key)], row_n > 0 and stale_key.is_empty())
	var no_count: Array = []
	for row in shops["만물상"]:
		if not (row as Dictionary).has("count"):
			no_count.append(String((row as Dictionary).get("buy_id", "?")))
	_check("⑮b 만물상 %d행 전부가 렌더러가 읽는 `count`를 싣는다 — 씨앗·묘목·비료·건초·설치물·레어크로우(누락: %s)"
			% [shops["만물상"].size(), str(no_count)],
		not shops["만물상"].is_empty() and no_count.is_empty())
	var store_shown := -1
	for row in shops["만물상"]:
		if String((row as Dictionary)["buy_id"]) == shop_seed:
			store_shown = int((row as Dictionary)["count"])
	_check("⑮c 씨앗 %s 40개를 들면 만물상 행이 보유 40을 싣는다(종전엔 `owned`라 화면이 \"보유 0\"이었다)"
			% shop_seed, shop_seed != "" and store_shown == 40)
	m.inventory.remove_item(ItemCatalog.seed_id(shop_seed), 40)

	# ── ⑧ #12 로드가 밀린 절기 재스폰 표를 버린다 ─────────────────────────────
	# ★ 세이브를 건드리므로 **맨 끝**에 둔다(위 절들의 월드 상태를 안 흔든다).
	print("── ⑧ #12 F9 로드 뒤 엉뚱한 날의 대량 재스폰 차단 ──")
	m._active_slot = 1
	m._save_game()
	m._season_respawn_pending_day = 29        # 집 밖에서 절기 마지막 밤을 넘긴 상태
	m._load_game()
	_check("⑧a 로드가 표를 버린다(fishing·_mine_entry_pick과 같은 세션 로컬 하드 리셋)",
		m._season_respawn_pending_day == 0)
	# `_process`의 소비 조건은 "표 != 0"이므로, 표가 0이면 안식에 서 있어도 집행되지 않는다.
	m._process(0.0)
	_check("⑧b 그래서 안식 그리드가 선 다음 프레임에도 재스폰이 안 돈다", m._season_respawn_pending_day == 0)
	var save1 := SaveManager.slot_path(1)
	if FileAccess.file_exists(save1):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save1))

	if FileAccess.file_exists(save0):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save0))
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(0 if _fail == 0 else 1)
