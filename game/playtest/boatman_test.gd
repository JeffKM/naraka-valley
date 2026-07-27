extends SceneTree
# ★ [S3-T5 / ADR-0061 결정 5] 뱃사공·생선가게 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ⓐ Resident T2 등록 — 레지스트리·표시명·황천해 생선가게 앞 자리·점주/관계 두 레이어.
#   ⓑ T1 낚싯대 증정 1회성 — 첫 대화 지급 · 재대화 무지급 · 세이브 왕복 후에도 유지.
#   ⓒ 매대 구성 — 낚싯대 T2~T4 + 미끼 3 + 태클 3(T1 비매 · 게잡이통 자리 미노출).
#   ⓓ 할인 — ♡0 정가 · ♡n = StoreDiscount 공식 · **네오 ♡와 완전 독립**(서로의 가격 불변).
#   ⓔ 유니크 구매 — 낚싯대·태클은 각 1개(보유 시 재구매 불가·locked 표시), 미끼만 대량.
#   ⓕ 환전 — 개별/행 전량/전량 · 가격 = **출하함 정산과 같은 공식** · 만물상은 물고기 비취급.
#   ⓖ 세이브 하위호환 — 뱃사공 키가 없는 구세이브 로드가 무해(♡0·증정 대기·크래시 0).
#   ⓗ ★ADR-0008/ADR-0030 관계-중립 — 뱃사공 ♡은 *가게 할인*뿐(낚시 메카닉 보정 0).
#
# 실행: ./run_tests.sh boatman   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	return m

# 뱃사공을 지금 마주 본 상태로 만든다(황천해 구역 + 그의 칸을 겨눔).
func _face_boatman(m: Node, r: Resident) -> void:
	m._region = RegionCatalog.HWANGCHEONHAE
	m._sleeping = false
	m._indoor = ""
	m._update_resident_stations(0.0)
	m._target = r.tile

# 대화창을 끝까지 넘겨 닫는다(플레이어 조작과 같은 경로).
func _close_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 48:
		m.dialogue.advance()
		guard += 1
	m.player.set_physics_process(true)

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S3-T5 뱃사공·생선가게 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()

	# ── ⓐ Resident T2 등록 ──
	print("── ⓐ 주민 등록 ──")
	var r: Resident = m._resident("boatman")
	_check("ⓐa 레지스트리에 등록", r != null)
	_check("ⓐb 표시명 = 뱃사공(칭호)", r != null and r.display_name == "뱃사공")
	_check("ⓐc 몸이 런타임 생성돼 트리에 붙는다(main.tscn 무수정)",
		r.node != null and r.node.is_inside_tree() and r.node is Boatman)
	_check("ⓐd 신규 세이브 키(구세이브엔 없음 = ♡0 시작)", r.save_key == "boatman_affinity")
	_check("ⓐe 관계 트랙 보유 · 선물 채널 있음(T2 사귐)", r.affinity != null and r.can_gift)
	_check("ⓐf 선호 선물 = 불사과(기존 4인과 안 겹침)",
		r.affinity.preferred_crop == CropCatalog.BULSAGWA)
	_check("ⓐg 초상화 없음(아트는 S3-T10)", r.portrait_stem == "")
	# 자리 — 황천해 생선가게 앞 백사장(문 열·산책로 레인을 둘 다 비껴간 칸).
	var tile: Vector2i = r.schedule[0]["tile"]
	_check("ⓐh 상시 영업(스케줄 1항목)", r.schedule.size() == 1)
	_check("ⓐi 자리 구역 = 황천해", r.station_region(0) == RegionCatalog.HWANGCHEONHAE)
	_check("ⓐj 자리 = 생선가게 문 옆 백사장(12,27)",
		tile == Vector2i(m.FISHSHOP_EXT_DOOR.x + 1, m.BEACH_CORRIDOR_Y + 1))
	_check("ⓐk 문 진입 열·산책로 레인을 안 막는다",
		tile.x != m.FISHSHOP_EXT_DOOR.x and tile.y != m.BEACH_CORRIDOR_Y)
	_check("ⓐl 실내가 아니라 외부 자리(외관 박스 밖·바다 위 아님)",
		not m.FISHSHOP_EXT_RECT.has_point(tile) and tile.y < m.SEA_Y0)
	# 점주 레이어(shop_key·effect_fn)와 관계 트랙이 독립 필드(ADR-0060 결정 8 · 네오 동형).
	_check("ⓐm 점주 훅([F] 생선가게) 보유", r.shop_key.is_valid())
	_check("ⓐn 관계 탭 효과 줄(할인 요약) 보유", r.effect_fn.is_valid())
	m.neo_affinity.points = 0
	r.affinity.points = 0
	_check("ⓐo ♡0이어도 매대는 열린다(평평≠막힘)", String(r.effect_fn.call()).contains("정가"))
	# 구역 가시성 가드 — 다른 구역의 같은 좌표에 닿아도 무반응.
	m._region = RegionCatalog.HOME
	m._sleeping = false
	m._indoor = ""
	m._update_resident_stations(0.0)
	m._target = tile
	_check("ⓐp 다른 구역에선 안 잡힌다(가시성 가드)", m._facing_resident() == null)
	_face_boatman(m, r)
	var faced: Resident = m._facing_resident()
	_check("ⓐq 황천해에서 마주 보면 잡힌다", faced != null and faced.id == "boatman")

	# ── ⓑ T1 낚싯대 증정(첫 대화 1회) ──
	print("── ⓑ T1 증정 ──")
	m.inventory.remove_item(ItemCatalog.ROD_T1, m.inventory.count_of(ItemCatalog.ROD_T1))
	m._boatman_rod_given = false
	r.affinity.last_talk_day = -1
	m.clock.day = 2
	_check("ⓑa 증정 전엔 낚싯대 0(옛 자동 지급 폐기)", not m.inventory.has_item(ItemCatalog.ROD_T1))
	_check("ⓑb 낚싯대 없으면 캐스팅 불가", not m._can_cast())
	m._start_resident_dialogue(r)
	_check("ⓑc 첫 대화에서 T1 낚싯대 지급", m.inventory.has_item(ItemCatalog.ROD_T1))
	_check("ⓑd 증정 플래그가 선다", m._boatman_rod_given)
	_check("ⓑe 증정 대사가 대화 앞에 붙는다(화자 = 뱃사공)",
		m.dialogue.is_open() and m._talking_to == "뱃사공")
	_close_dialogue(m)
	# 재대화(다음 날 = 일일 대화가 다시 열리는 날)에도 두 번째 대는 안 준다.
	m.clock.day = 3
	m._start_resident_dialogue(r)
	_check("ⓑf 재대화에도 낚싯대는 한 자루뿐(1회성)",
		m.inventory.count_of(ItemCatalog.ROD_T1) == 1)
	_close_dialogue(m)
	# 옛 자동 지급 경로는 제거됐다(구역 진입해도 안 준다).
	_check("ⓑg 옛 자동 지급 함수 제거", not m.has_method("_grant_starter_rod"))

	# ── ⓒ 매대 구성 ──
	print("── ⓒ 매대 구성 ──")
	var items: Array = m._fishshop_items()
	_check("ⓒa 9행 = 낚싯대3 + 미끼3 + 태클3", items.size() == 9)
	var buy_ids: Array = items.map(func(it): return String(it["buy_id"]))
	_check("ⓒb 낚싯대 T2~T4 전부 진열",
		buy_ids.has(GearCatalog.ROD_T2) and buy_ids.has(GearCatalog.ROD_T3)
		and buy_ids.has(GearCatalog.ROD_T4))
	_check("ⓒc T1(증정품)은 비매 — 매대에 없음", not buy_ids.has(GearCatalog.ROD_T1))
	var all_bait := true
	for id in GearCatalog.BAITS:
		if not buy_ids.has(id):
			all_bait = false
	var all_tackle := true
	for id in GearCatalog.TACKLES:
		if not buy_ids.has(id):
			all_tackle = false
	_check("ⓒd 미끼 3종 전부 진열", all_bait)
	_check("ⓒe 태클 3종 전부 진열", all_tackle)
	var fields_ok := true
	for it in items:
		if String(it["kind"]) != "gear" or not (it.has("icon_id") and it.has("name")
				and it.has("price") and it.has("base")):
			fields_ok = false
	_check("ⓒf 전 행 kind = gear · 필수 필드 구비", fields_ok)
	# ★[S3-T7] 게잡이통은 아직 로스터에 없다 — 자리만 예약(해금 노출은 S3-T7 소관).
	_check("ⓒg 게잡이통 미노출(S3-T7 해금 전)",
		items.all(func(it): return not String(it["buy_id"]).contains("crab")))
	_check("ⓒh 매대 헤더에 가게·할인 요약", m._fishshop_text().contains("생선가게"))

	# ── ⓓ 할인(네오와 독립) ──
	print("── ⓓ 할인 ──")
	var rod2_base: int = GearCatalog.price_of(GearCatalog.ROD_T2)
	r.affinity.points = 0
	m.neo_affinity.points = m.neo_affinity.MAX_POINTS      # 네오 ♡5(만물상만 싸져야 한다)
	var row0: Dictionary = m._fishshop_items()[0]
	_check("ⓓa 뱃사공 ♡0 = 정가(네오 ♡5여도 생선가게는 안 싸짐)",
		int(row0["price"]) == rod2_base and int(row0["base"]) == rod2_base)
	r.affinity.points = 3 * Affinity.POINTS_PER_HEART      # 뱃사공 ♡3
	var row3: Dictionary = m._fishshop_items()[0]
	_check("ⓓb 뱃사공 ♡3 = StoreDiscount 공식가",
		int(row3["price"]) == StoreDiscount.price(rod2_base, 3) and int(row3["price"]) < rod2_base)
	# 반대 방향 — 뱃사공 ♡가 만물상 가격을 건드리지 않는다.
	m.neo_affinity.points = 0
	var seed_base: int = CropCatalog.seed_cost(CropCatalog.HONRYEONGCHO)
	var store_rows: Array = m._store_items()
	var seed_row: Dictionary = store_rows[0]
	_check("ⓓc 뱃사공 ♡3이어도 만물상은 정가(할인 독립)", int(seed_row["price"]) == seed_base)
	_check("ⓓd 할인 요약 문구가 점주별로 갈린다",
		String(r.effect_fn.call()).contains("뱃사공")
		and StoreDiscount.summary(0).contains("네오"))
	r.affinity.points = 0

	# ── ⓔ 유니크 구매 ──
	print("── ⓔ 유니크 구매 ──")
	m.wallet.gold = 20000
	m.inventory.remove_item(GearCatalog.ROD_T2, m.inventory.count_of(GearCatalog.ROD_T2))
	var gold0: int = m.wallet.gold
	m._on_frame_buy_store_item(GearCatalog.ROD_T2, "gear", false)
	_check("ⓔa 낚싯대 구매 = 인벤 +1", m.inventory.count_of(GearCatalog.ROD_T2) == 1)
	_check("ⓔb 정가만큼 골드 차감(♡0)", m.wallet.gold == gold0 - rod2_base)
	var gold1: int = m.wallet.gold
	m._on_frame_buy_store_item(GearCatalog.ROD_T2, "gear", false)
	_check("ⓔc 보유 티어는 재구매 불가(수량·골드 불변)",
		m.inventory.count_of(GearCatalog.ROD_T2) == 1 and m.wallet.gold == gold1)
	m._on_frame_buy_store_item(GearCatalog.ROD_T2, "gear", true)   # Shift 대량도 막힌다
	_check("ⓔd 대량 구매로도 못 늘린다", m.inventory.count_of(GearCatalog.ROD_T2) == 1)
	var locked_row: Array = m._fishshop_items().filter(
		func(it): return String(it["buy_id"]) == GearCatalog.ROD_T2)
	_check("ⓔe 보유 티어 행은 '보유 중'으로 잠긴다",
		locked_row.size() == 1 and bool(locked_row[0]["locked"]))
	# 미끼는 스택 소모품 — 대량 구매가 열려 있다.
	var bait_base: int = GearCatalog.price_of(GearCatalog.BAIT_BASIC)
	m.inventory.remove_item(GearCatalog.BAIT_BASIC, m.inventory.count_of(GearCatalog.BAIT_BASIC))
	m.wallet.gold = 20000
	m._on_frame_buy_store_item(GearCatalog.BAIT_BASIC, "gear", true)
	_check("ⓔf 미끼는 대량 구매(STORE_BULK개)",
		m.inventory.count_of(GearCatalog.BAIT_BASIC) == m.STORE_BULK)
	_check("ⓔg 미끼 대량 = 단가×묶음 차감", m.wallet.gold == 20000 - bait_base * m.STORE_BULK)
	var bait_row: Array = m._fishshop_items().filter(
		func(it): return String(it["buy_id"]) == GearCatalog.BAIT_BASIC)
	_check("ⓔh 미끼 행은 보유해도 안 잠긴다", not bool(bait_row[0]["locked"]))
	# 골드 부족이면 막힌다(음수 방지 — 만물상과 같은 규약).
	m.wallet.gold = 0
	m._on_frame_buy_store_item(GearCatalog.ROD_T4, "gear", false)
	_check("ⓔi 골드 부족이면 구매 막힘",
		not m.inventory.has_item(GearCatalog.ROD_T4) and m.wallet.gold == 0)

	# ── ⓕ 물고기 즉시 환전 ──
	print("── ⓕ 환전 ──")
	var fish_a: String = FishCatalog.NEOK_BUNGEO
	var fish_b: String = FishCatalog.NEOK_MYEOLCHI
	m.inventory.remove_item(fish_a, m.inventory.count_of(fish_a))
	m.inventory.remove_item(fish_b, m.inventory.count_of(fish_b))
	m.inventory.add_item(fish_a, 3, ItemCatalog.Q_NORMAL)
	m.inventory.add_item(fish_a, 2, 2)          # 금 등급 — 같은 어종이라도 등급이 다르면 다른 행
	m.inventory.add_item(fish_b, 1, ItemCatalog.Q_NORMAL)
	var rows: Array = m._trade_items()
	_check("ⓕa 환전 행 = (어종 × 등급)별 3행", rows.size() == 3)
	_check("ⓕb 행마다 보유 수량·등급이 실린다",
		rows.all(func(it): return it.has("count") and it.has("quality") and int(it["count"]) > 0))
	# ★가격 = 출하함 정산과 **동일 공식**(같은 물량을 출하함에 넣은 미리보기와 총액이 같다).
	var trade_total := 0
	for it in rows:
		trade_total += int(it["price"]) * int(it["count"])
	m.ship_bin.pending.clear()
	m.ship_bin.add(fish_a, 3, ItemCatalog.Q_NORMAL)
	m.ship_bin.add(fish_a, 2, 2)
	m.ship_bin.add(fish_b, 1, ItemCatalog.Q_NORMAL)
	_check("ⓕc 환전 총액 = 출하함 정산 총액(같은 공식)", trade_total == m.ship_bin.preview_gold())
	m.ship_bin.pending.clear()
	# 개별 환전(1마리).
	m.wallet.gold = 0
	var unit_a: int = ItemCatalog.price_of(fish_a, ItemCatalog.Q_NORMAL)
	m._on_frame_sell_fish(fish_a, ItemCatalog.Q_NORMAL, false)
	_check("ⓕd 개별 환전 = 1마리 소모 · 골드 +단가",
		m._fish_count(fish_a, ItemCatalog.Q_NORMAL) == 2 and m.wallet.gold == unit_a)
	# 행 전량(Shift) — 같은 등급만 빠지고 다른 등급은 남는다.
	m.wallet.gold = 0
	m._on_frame_sell_fish(fish_a, ItemCatalog.Q_NORMAL, true)
	_check("ⓕe 행 전량 환전 = 그 등급만 비운다",
		m._fish_count(fish_a, ItemCatalog.Q_NORMAL) == 0
		and m._fish_count(fish_a, 2) == 2 and m.wallet.gold == unit_a * 2)
	# 전량 환전 — 남은 물고기 전부.
	m.wallet.gold = 0
	var rest := 0
	for it in m._trade_items():
		rest += int(it["price"]) * int(it["count"])
	m._on_frame_sell_fish_all()
	_check("ⓕf 전량 환전 = 보유 물고기 0 · 골드 +총액",
		m._trade_items().is_empty() and m.wallet.gold == rest and rest > 0)
	_check("ⓕg 환전할 게 없으면 무해(빈 목록·골드 불변)",
		m.wallet.gold == rest and m._trade_items().is_empty())
	m._on_frame_sell_fish_all()
	_check("ⓕh 빈 상태 전량 환전도 골드 불변", m.wallet.gold == rest)
	# 물고기가 아닌 id는 환전되지 않는다(오용 방어).
	m.inventory.add_harvest(CropCatalog.HONRYEONGCHO, 1)
	var gold_before: int = m.wallet.gold
	m._on_frame_sell_fish(CropCatalog.HONRYEONGCHO, 0, true)
	_check("ⓕi 물고기 아닌 id는 환전 거절",
		m.wallet.gold == gold_before and m.inventory.harvest_count(CropCatalog.HONRYEONGCHO) == 1)
	# 만물상은 물고기 비취급(매대에도 환전에도 없다 — 서비스 분산 유지).
	_check("ⓕj 만물상 매대에 물고기 없음",
		m._store_items().all(func(it): return not ItemCatalog._is_fish(String(it["buy_id"]))))

	# ── ⓗ 관계-중립(ADR-0008 / ADR-0030) ──
	print("── ⓗ 관계-중립 ──")
	m.clock.minutes = 10 * 60
	r.affinity.points = 0
	var roll0: String = m._roll_fish_id(4242)
	var gear0: String = m._fishing_gear_line(GearCatalog.ROD_T2)
	r.affinity.points = r.affinity.MAX_POINTS   # ♡5
	_check("ⓗa ♡5여도 같은 시드 = 같은 어종(입질·추첨 보정 0)", m._roll_fish_id(4242) == roll0)
	_check("ⓗb ♡5여도 기어 파라미터 불변(격투 보정 0)",
		m._fishing_gear_line(GearCatalog.ROD_T2) == gear0
		and GearCatalog.rod_params(GearCatalog.ROD_T2) == GearCatalog.rod_params(GearCatalog.ROD_T2))
	_check("ⓗc ♡5가 바꾸는 건 매대 가격뿐",
		int(m._fishshop_items()[0]["price"]) == StoreDiscount.price(rod2_base, 5))
	r.affinity.points = 2 * Affinity.POINTS_PER_HEART   # 세이브 왕복용 값

	# ── ⓑ' + ⓖ 세이브 왕복 / 하위호환 ──
	print("── ⓖ 세이브 ──")
	m._save_game()
	var slot: int = m._active_slot
	m.free()
	var m2: Node = await _new_main()
	_check("ⓖa 뱃사공 호감도가 boatman_affinity 키로 복원",
		m2._resident("boatman").affinity.hearts() == 2)
	_check("ⓖb 증정 플래그가 세이브를 넘어 유지", m2._boatman_rod_given)
	# 플래그가 산 채로 재대화해도 두 번째 대는 없다.
	var r2: Resident = m2._resident("boatman")
	var rods_before: int = m2.inventory.count_of(ItemCatalog.ROD_T1)
	_face_boatman(m2, r2)
	m2.clock.day += 1
	m2._start_resident_dialogue(r2)
	_check("ⓖc 세이브 왕복 후 재대화도 무지급",
		m2.inventory.count_of(ItemCatalog.ROD_T1) == rods_before)
	_close_dialogue(m2)
	m2.free()
	# 구세이브 — 뱃사공 키 2개(호감도·증정 플래그)를 지운 세이브로 부팅한다.
	var sm := SaveManager.new()
	var raw := sm.load_game(slot)
	raw.erase("boatman_affinity")
	raw.erase("boatman_rod_given")
	sm.save_game(raw, slot, {"day": 1, "soul": 0})
	sm.free()
	var m3: Node = await _new_main()
	var r3: Resident = m3._resident("boatman")
	_check("ⓖd 구세이브 = 뱃사공만 ♡0으로 시작(무막힘)", r3 != null and r3.affinity.hearts() == 0)
	_check("ⓖe 구세이브 = 증정 플래그 false(하위호환 기본값)", not m3._boatman_rod_given)
	# ★구세이브가 옛 자동 지급으로 이미 T1을 들고 있으면 두 번째 대를 주지 않고 플래그만 접는다.
	if not m3.inventory.has_item(ItemCatalog.ROD_T1):
		m3.inventory.add_item(ItemCatalog.ROD_T1, 1)
	_face_boatman(m3, r3)
	m3.clock.day = 9
	m3._start_resident_dialogue(r3)
	_check("ⓖf 이미 T1 보유한 구세이브 = 중복 지급 없음",
		m3.inventory.count_of(ItemCatalog.ROD_T1) == 1 and m3._boatman_rod_given)
	_close_dialogue(m3)
	_check("ⓖg 구세이브 로드가 매대·환전을 안 깨뜨린다",
		m3._fishshop_items().size() == 9 and m3._trade_items() is Array)
	m3.free()

	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
