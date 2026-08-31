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
