extends SceneTree
# ★[S5-T6 / ADR-0063 결정 5·6·10] 모험가 길드(무골) + 무기 매대 + 명부환 + 보상 층 상자 검증.
#
# 무엇을 보증하나(어기면 ADR-0063 결정 5/6/10 위반):
#   ⓐ 무골 = Resident T2 10인째 — 길드 실내 상주 · 점주 훅 · **관계-중립**(effect_fn 없음) · T2 톤.
#   ⓑ 첫 방문 증정(녹슨 혼검) 1회성 — 첫 대화 지급 · 재대화 무지급 · 이미 가졌으면 조용히 접힘.
#   ⓒ 무기 매대 깊이 게이팅 — **미달 품목은 행 자체가 없다**(잠금 행 아님) · 증정품은 비매라 미노출.
#   ⓓ 구매 → 장착 실효 — 산 검이 인벤에 들고, 들면 그 검의 밴드로 몹을 벤다 · 재구매 불가(유니크).
#   ⓔ 명부환 — 상시 품목 · 구매(대량) · HP 회복 · **최대치 클램프** · 풀피 거절(소모 0) · 혼력 0에서도 사용.
#   ⓕ 보상 층 상자 — 10의 배수만 · 몹 0 · 자리 결정적(빈 칸) · **1회성 영구**(재진입·날 바뀜에도 유지).
#   ⓖ 60층 상자 = 나락 열쇠 + 영구 마일스톤 플래그 + 바닥 안내 문구 전환.
#   ⓗ 세이브 왕복 — 증정 플래그 · 개봉 원장 · 열쇠 플래그 · ♡ · 구세이브 하위호환(키 없음 = 초기값).
#   ⓘ 로스터 대조 — 보상 테이블의 아이템 id가 전부 ItemCatalog에 실재한다(두 로스터 분기 방지).
#   ⓙ 회귀 0 — 골든 서명(층 배치)이 상자 도입으로 한 칸도 안 흔들린다(상자는 RNG를 안 쓴다).
#
# 실행: ./run_tests.sh guild   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

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

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 전환(층 전환) tween이 끝날 때까지 폴링(실시간 tween, 좀비 방지 상한).
func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

# 무골을 지금 마주 본 상태로 만든다(갱도 구역 + 길드 실내 + 그의 칸을 겨눔).
func _face_mugol(m: Node, r: Resident) -> void:
	m._region = RegionCatalog.EOPHWA_MINE
	m._sleeping = false
	m._indoor = "길드"
	m._update_resident_stations(0.0)
	m._target = r.tile

# 대화창을 끝까지 넘겨 닫는다(플레이어 조작과 같은 경로).
func _close_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 48:
		m.dialogue.advance()
		guard += 1
	m.player.set_physics_process(true)

# 아이템을 들려(핫바 선택) 준다 — 없으면 지급부터(mob_test._equip 1:1).
func _equip(m: Node, id: String) -> bool:
	if m.inventory.count_of(id) <= 0 and not m.inventory.add_item(id, 1):
		return false
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return m.inventory.selected_id() == id
	return false

func _buy_ids(rows: Array) -> Array:
	return rows.map(func(it): return String(it["buy_id"]))

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S5-T6 모험가 길드·무기 매대·명부환·보상 상자 검증(ADR-0063 결정 5·6·10) ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.guild_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()

	# ── ⓐ 무골 = Resident T2 등록 ────────────────────────────────────────────
	print("── ⓐ 무골 등록 ──")
	var r: Resident = m._resident("mugol")
	_check("ⓐa 레지스트리에 등록 · 10인째(뒤에만 붙는다 — 앞 순서 불변)",
		r != null and m._residents.size() == 10 and m._residents[9].id == "mugol")
	_check("ⓐb 표시명 = 무골(칭호)", r != null and r.display_name == "무골")
	_check("ⓐc 몸이 런타임 생성돼 트리에 붙는다(main.tscn 무수정)",
		r.node != null and r.node.is_inside_tree() and r.node is Mugol)
	_check("ⓐd 신규 세이브 키(구세이브엔 없음 = ♡0 시작)", r.save_key == "mugol_affinity")
	_check("ⓐe 관계 트랙 보유 · 선물 채널 있음(T2 사귐)", r.affinity != null and r.can_gift)
	_check("ⓐf 자리 = 길드 실내 rect 안 · 문 열 정렬(들어오면 정면)",
		m.GUILD_RECT.has_point(m.MUGOL_TILE) and m.MUGOL_TILE.x == m.GUILD_DOOR.x)
	_check("ⓐg 카운터 줄과 안 겹친다(무골은 카운터 뒤)", m.MUGOL_TILE.y != m.GUILD_COUNTER_Y)
	_check("ⓐh 상시 영업(스케줄 1항목) · 갱도 구역 · 길드 실내 게이트",
		r.schedule.size() == 1 and String(r.schedule[0]["region"]) == RegionCatalog.EOPHWA_MINE
		and r.require_indoor == "길드" and r.require_visible)
	_check("ⓐi 점주 훅([F] 매대) 보유", r.shop_key.is_valid())
	# ★관계-중립(풀무 동형) — 할인이 없으므로 관계 탭 효과 줄 자체가 없다.
	_check("ⓐj **effect_fn 없음**(관계-중립 — 무기 값은 깊이 곡선이라 ♡ 보정 0)",
		not r.effect_fn.is_valid())
	# 실내 게이트 — 같은 갱도 구역의 대장간 안에서는 안 잡힌다(방 이름이 다르다).
	m._region = RegionCatalog.EOPHWA_MINE
	m._sleeping = false
	m._indoor = "대장간"
	m._update_resident_stations(0.0)
	m._target = m.MUGOL_TILE
	_check("ⓐk 대장간 안에서는 안 잡힌다(require_indoor 게이트)",
		m._facing_resident() == null or m._facing_resident().id != "mugol")
	_face_mugol(m, r)
	var faced: Resident = m._facing_resident()
	_check("ⓐl 길드 안에서 마주 보면 잡힌다", faced != null and faced.id == "mugol")
	# T2 톤 — 속죄·심판 어휘 0, "저승" 날것 0(풀무·옹이와 같은 계약).
	var lines0: PackedStringArray = r.node.lines(0, true)
	var lines5: PackedStringArray = r.node.lines(5, true)
	var again: PackedStringArray = r.node.lines(0, false)
	_check("ⓐm 대사 = 하트 단계별 묶음 + 재대화 1줄",
		lines0.size() >= 3 and lines5.size() >= 3 and again.size() == 1
		and String(lines0[0]) != String(lines5[0]))
	var joined := " ".join(lines0) + " " + " ".join(lines5) + " " + " ".join(Mugol.LINES_SWORD_GIFT)
	_check("ⓐn 속죄·심판 어휘 없음(T2 라이트 플레이버 — ADR-0004/0005 경계)",
		not joined.contains("속죄") and not joined.contains("죄") and not joined.contains("심판"))
	_check("ⓐo '저승'을 날것으로 부르지 않는다(주민 톤 정합)", not joined.contains("저승"))
	_check("ⓐp 할인을 약속하지 않는다(관계-중립 — 대사도 메카닉 약속 0)",
		not joined.contains("깎아 주") and not joined.contains("싸게"))

	# ── ⓑ 첫 방문 증정(녹슨 혼검) ────────────────────────────────────────────
	print("── ⓑ 첫 방문 증정 ──")
	m.inventory.remove_item(WeaponCatalog.SWORD_RUSTY, m.inventory.count_of(WeaponCatalog.SWORD_RUSTY))
	m._mugol_sword_given = false
	r.affinity.last_talk_day = -1
	m.clock.day = 2
	_check("ⓑa 증정 전엔 검 0", not m.inventory.has_item(WeaponCatalog.SWORD_RUSTY))
	m._start_resident_dialogue(r)
	_check("ⓑb 첫 대화에서 녹슨 혼검 지급", m.inventory.count_of(WeaponCatalog.SWORD_RUSTY) == 1)
	_check("ⓑc 증정 플래그가 선다", m._mugol_sword_given)
	_check("ⓑd 증정 대사가 대화 앞에 붙는다(화자 = 무골)",
		m.dialogue.is_open() and m._talking_to == "무골")
	_close_dialogue(m)
	m.clock.day = 3
	m._start_resident_dialogue(r)
	_check("ⓑe 재대화에도 한 자루뿐(1회성)", m.inventory.count_of(WeaponCatalog.SWORD_RUSTY) == 1)
	_close_dialogue(m)
	# 이미 가지고 있는 상태에서 플래그만 꺼도 두 자루가 되지 않는다(구세이브·디버그 지급 방어).
	m._mugol_sword_given = false
	m.clock.day = 4
	m._start_resident_dialogue(r)
	_check("ⓑf 이미 가졌으면 조용히 플래그만 접는다(두 자루 금지)",
		m.inventory.count_of(WeaponCatalog.SWORD_RUSTY) == 1 and m._mugol_sword_given)
	_close_dialogue(m)

	# ── ⓒ 무기 매대 깊이 게이팅 ──────────────────────────────────────────────
	print("── ⓒ 깊이 게이팅 ──")
	m.mine_floors._depth = 0
	var rows0: Array = m._guild_items()
	var ids0: Array = _buy_ids(rows0)
	_check("ⓒa 깊이 0 = 검 0행 + 명부환 1행",
		rows0.size() == 1 and ids0 == [ItemCatalog.MYEONGBUHWAN])
	_check("ⓒb 증정품(녹슨 혼검)은 비매라 **어느 깊이에서도 미노출**",
		not ids0.has(WeaponCatalog.SWORD_RUSTY))
	m.mine_floors._depth = 10
	var ids10: Array = _buy_ids(m._guild_items())
	_check("ⓒc 깊이 10 = 명동검 노출 · 상위 3검 **행 자체가 없다**(잠금 행 아님)",
		ids10.has(WeaponCatalog.SWORD_MYEONGDONG)
		and not ids10.has(WeaponCatalog.SWORD_YUCHEOL)
		and not ids10.has(WeaponCatalog.SWORD_HWANGCHEONGEUM)
		and not ids10.has(WeaponCatalog.SWORD_EOPHWADO))
	m.mine_floors._depth = 40
	var ids40: Array = _buy_ids(m._guild_items())
	_check("ⓒd 깊이 40 = 명동·유철·황천금 3검(업화도는 60층)",
		ids40.has(WeaponCatalog.SWORD_HWANGCHEONGEUM) and not ids40.has(WeaponCatalog.SWORD_EOPHWADO))
	m.mine_floors._depth = 60
	var rows60: Array = m._guild_items()
	var ids60: Array = _buy_ids(rows60)
	_check("ⓒe 깊이 60 = 검 4 + 명부환 = 5행", rows60.size() == 5 and ids60.has(WeaponCatalog.SWORD_EOPHWADO))
	var fields_ok := true
	for it: Dictionary in rows60:
		var k := String(it.get("kind", ""))
		if not (k == "weapon" or k == "potion"):
			fields_ok = false
		if not (it.has("icon_id") and it.has("name") and it.has("price") and it.has("base")):
			fields_ok = false
		if int(it["price"]) != int(it["base"]):
			fields_ok = false   # ★할인 0 = 정가 = base(병기 표시가 안 뜬다)
	_check("ⓒf 전 행 kind = weapon|potion · 필수 필드 구비 · **price == base**(할인 0)", fields_ok)
	_check("ⓒg 값은 WeaponCatalog 단일 출처(정가 그대로)",
		int(rows60[0]["price"]) == WeaponCatalog.price_of(String(rows60[0]["buy_id"])))
	_check("ⓒh 헤더에 가게·도달 깊이·체력", m._guild_text().contains("모험가 길드")
		and m._guild_text().contains("도달 깊이") and m._guild_text().contains("체력"))
	# ★관계-중립 실증 — ♡5여도 값이 한 냥도 안 바뀐다(뱃사공·옹이 매대와 갈리는 지점).
	var price_h0: int = int(m._guild_items()[0]["price"])
	r.affinity.points = 5 * Affinity.POINTS_PER_HEART
	_check("ⓒi ♡5여도 값 불변(무골 할인 0 — ADR-0008 관계-중립)",
		int(m._guild_items()[0]["price"]) == price_h0)

	# ── ⓓ 구매 → 장착 실효 ──────────────────────────────────────────────────
	print("── ⓓ 구매·장착 ──")
	m.mine_floors._depth = 10
	m.inventory.remove_item(WeaponCatalog.SWORD_MYEONGDONG,
		m.inventory.count_of(WeaponCatalog.SWORD_MYEONGDONG))
	var gold0 := 20000
	m.wallet.gold = gold0
	m._on_frame_buy_store_item(WeaponCatalog.SWORD_MYEONGDONG, "weapon", false)
	_check("ⓓa 명동검 구매 — 인벤 적재 · 정가 차감",
		m.inventory.count_of(WeaponCatalog.SWORD_MYEONGDONG) == 1
		and m.wallet.gold == gold0 - WeaponCatalog.price_of(WeaponCatalog.SWORD_MYEONGDONG))
	var gold1: int = m.wallet.gold
	m._on_frame_buy_store_item(WeaponCatalog.SWORD_MYEONGDONG, "weapon", true)
	_check("ⓓb 유니크 — 재구매 불가(Shift 대량도 무시 · 골드 불변)",
		m.inventory.count_of(WeaponCatalog.SWORD_MYEONGDONG) == 1 and m.wallet.gold == gold1)
	m._on_frame_buy_store_item(WeaponCatalog.SWORD_EOPHWADO, "weapon", false)
	_check("ⓓc 깊이 미달 무기는 **구매도 막힌다**(진열과 같은 판정 — 안 보이는데 사는 구멍 0)",
		not m.inventory.has_item(WeaponCatalog.SWORD_EOPHWADO) and m.wallet.gold == gold1)
	_check("ⓓd 증정품은 매대로 못 산다(price 0 = 비매)",
		(func() -> bool:
			var before: int = m.inventory.count_of(WeaponCatalog.SWORD_RUSTY)
			m._on_frame_buy_store_item(WeaponCatalog.SWORD_RUSTY, "weapon", false)
			return m.inventory.count_of(WeaponCatalog.SWORD_RUSTY) == before).call())
	# 산 검을 들고 층에서 몹을 벤다 — 밴드가 실제 판정에 실린다(구매 → 장착 → 실효 사슬 완결).
	m.energy.current = SoulEnergy.MAX
	m._descend_mine(3)
	await _settle(m)
	_check("ⓓe pre 3층 · 잡귀가 서 있다", m._mine_floor == 3 and m._mobs.size() > 0)
	_check("ⓓf pre 명동검 장착", _equip(m, WeaponCatalog.SWORD_MYEONGDONG))
	var victim: Dictionary = m._mobs_in_region()[0]
	var victim_ref: Mob = victim["ref"]
	var hp_before: int = victim_ref.hp
	m._combat_swings += 1
	var res: Dictionary = m._strike_mob(WeaponCatalog.SWORD_MYEONGDONG, victim)
	var dmg := int(res["damage"])
	_check("ⓓg 산 검이 그 검의 밴드로 실제 피해를 준다(장착 실효)",
		dmg >= WeaponCatalog.damage_min(WeaponCatalog.SWORD_MYEONGDONG)
		and victim_ref.hp == maxi(hp_before - dmg, 0))

	# ── ⓔ 명부환 ────────────────────────────────────────────────────────────
	print("── ⓔ 명부환 ──")
	_check("ⓔa 아이템 등록 · 소모품 카테고리 · 스택 가능",
		ItemCatalog.has_item(ItemCatalog.MYEONGBUHWAN)
		and ItemCatalog.category_of(ItemCatalog.MYEONGBUHWAN) == ItemCatalog.CAT_CONSUMABLE
		and ItemCatalog.stackable_of(ItemCatalog.MYEONGBUHWAN))
	m.inventory.remove_item(ItemCatalog.MYEONGBUHWAN, m.inventory.count_of(ItemCatalog.MYEONGBUHWAN))
	m.wallet.gold = 20000
	var gp := ItemCatalog.price_of(ItemCatalog.MYEONGBUHWAN)
	m._on_frame_buy_store_item(ItemCatalog.MYEONGBUHWAN, "potion", false)
	_check("ⓔb 1개 구매 — 적재·차감", m.inventory.count_of(ItemCatalog.MYEONGBUHWAN) == 1
		and m.wallet.gold == 20000 - gp)
	var gold2: int = m.wallet.gold
	m._on_frame_buy_store_item(ItemCatalog.MYEONGBUHWAN, "potion", true)
	_check("ⓔc 스택 소모품이라 대량 구매(Shift) 성립",
		m.inventory.count_of(ItemCatalog.MYEONGBUHWAN) == 1 + m.STORE_BULK
		and m.wallet.gold == gold2 - gp * m.STORE_BULK)
	# 회복 — 반쯤 깎인 체력에서 정확히 HEAL만큼.
	m.health.current = m.health.maximum - ItemCatalog.MYEONGBUHWAN_HEAL - 5
	var hp0: int = m.health.current
	var pots0: int = m.inventory.count_of(ItemCatalog.MYEONGBUHWAN)
	_check("ⓔd pre 명부환 장착", _equip(m, ItemCatalog.MYEONGBUHWAN))
	m._use_tool()
	_check("ⓔe 마시면 체력 +%d · 1개 소모" % ItemCatalog.MYEONGBUHWAN_HEAL,
		m.health.current == hp0 + ItemCatalog.MYEONGBUHWAN_HEAL
		and m.inventory.count_of(ItemCatalog.MYEONGBUHWAN) == pots0 - 1)
	# 클램프 — 최대치를 넘겨 회복하지 않는다.
	m.health.current = m.health.maximum - 5
	m._use_tool()
	_check("ⓔf 최대치 클램프(넘쳐 흐르지 않는다)", m.health.current == m.health.maximum)
	# 풀피 거절 — 소모 0(낭비 방지 · 잠정 결정).
	var pots1: int = m.inventory.count_of(ItemCatalog.MYEONGBUHWAN)
	m._use_tool()
	_check("ⓔg 풀피면 거절 — 소모 0(1회성 회복원 낭비 방지)",
		m.inventory.count_of(ItemCatalog.MYEONGBUHWAN) == pots1
		and m.health.current == m.health.maximum)
	# 혼력 0에서도 마신다(체력·혼력 완전 별개 — ADR-0011).
	m.energy.current = 0
	m.health.current = 10
	var pots2: int = m.inventory.count_of(ItemCatalog.MYEONGBUHWAN)
	m._use_tool()
	_check("ⓔh 혼력 0에서도 회복은 성립(자원 분리 — 갱도에서 막히지 않는다)",
		m.health.current > 10 and m.inventory.count_of(ItemCatalog.MYEONGBUHWAN) == pots2 - 1
		and m.energy.current == 0)
	m.energy.current = SoulEnergy.MAX

	# ── ⓕ 보상 층 상자 ──────────────────────────────────────────────────────
	print("── ⓕ 보상 층 상자 ──")
	_check("ⓕa 10의 배수만 보상 층",
		MineFloors.is_reward_floor(10) and MineFloors.is_reward_floor(60)
		and not MineFloors.is_reward_floor(11) and not MineFloors.is_reward_floor(0)
		and not MineFloors.is_reward_floor(61))
	_check("ⓕb 보상 층 = 몹 0(T5 불변식과 같은 축)",
		not MineFloors.spawns_mobs(10) and MineFloors.spawns_mobs(11))
	var tile_ok := true
	var non_reward_ok := true
	for day in [1, 5, 12]:
		for f in [10, 20, 30, 40, 50, 60]:
			var lay := MineFloors.generate(int(day), int(f))
			var ct: Vector2i = lay["chest"]
			var rect: Rect2i = lay["rect"]
			if ct.x < 0 or not rect.has_point(ct) or lay["rocks"].has(ct) \
					or ct == lay["entrance"] or ct == lay["ladder"]:
				tile_ok = false
			if MineFloors.chest_tile(lay) != ct:
				tile_ok = false   # 순수 함수 재계산이 같은 자리(결정성)
		for f2 in [1, 7, 19, 41, 59]:
			if Vector2i(MineFloors.generate(int(day), int(f2))["chest"]).x >= 0:
				non_reward_ok = false
	_check("ⓕc 상자 자리 = 방 안 빈 칸(돌·입구·사다리 배제) · 재계산 동일(결정적)", tile_ok)
	_check("ⓕd 비-보상 층에는 상자가 없다((-1,-1))", non_reward_ok)
	# 실제 개봉 — 20층(명부환 + 골드).
	m.mine_floors._chests = {}
	m._narak_key_found = false
	m.mine_floors._depth = 60
	m._descend_mine(20)
	await _settle(m)
	var chest_t: Vector2i = m._mine_layout["chest"]
	m.player.global_position = m._tile_center_px(chest_t)
	await process_frame
	_check("ⓕe 20층 상자 칸에 서면 개봉 대상", m._is_mine_chest(m._player_tile()))
	var pots_before: int = m.inventory.count_of(ItemCatalog.MYEONGBUHWAN)
	var gold_before: int = m.wallet.gold
	m._open_mine_chest()
	_check("ⓕf 개봉 = 명부환 + 골드 지급 · 원장 기록",
		m.inventory.count_of(ItemCatalog.MYEONGBUHWAN) > pots_before
		and m.wallet.gold > gold_before and m.mine_floors.is_chest_opened(20))
	_check("ⓕg 연 상자는 대상에서 빠진다(자리에서 사라짐)", not m._is_mine_chest(m._player_tile()))
	var pots_after: int = m.inventory.count_of(ItemCatalog.MYEONGBUHWAN)
	var gold_after: int = m.wallet.gold
	m._open_mine_chest()
	_check("ⓕh 재개봉 무동작(1회성)",
		m.inventory.count_of(ItemCatalog.MYEONGBUHWAN) == pots_after and m.wallet.gold == gold_after)
	# 날이 바뀌어도 유지된다(day-한정 기록과 수명이 다르다 — 재파밍 차단).
	m.mine_floors.advance_day(m.mine_floors.current_day() + 1)
	_check("ⓕi 날이 바뀌어도 개봉 기록 유지(채굴 기록만 소멸)",
		m.mine_floors.is_chest_opened(20) and m.mine_floors.mined_count(20) == 0)
	# 층을 나갔다 다시 들어와도 유지.
	m._ascend_mine_to_surface()
	await _settle(m)
	m._descend_mine(20)
	await _settle(m)
	m.player.global_position = m._tile_center_px(Vector2i(m._mine_layout["chest"]))
	await process_frame
	_check("ⓕj 재진입해도 상자는 없다(영구 1회성)", not m._is_mine_chest(m._player_tile()))
	_check("ⓕk 10층 보상 = 명동검(대체 입수 — ADR-0063 결정 10)",
		String(MineFloors.chest_rewards(10)[0]["id"]) == WeaponCatalog.SWORD_MYEONGDONG)
	# 이미 가진 검이 나오면 골드로 대체된다(1회성 보상이 빈손이 되지 않는다).
	m.mine_floors._chests = {}
	m._descend_mine(10)
	await _settle(m)
	m.player.global_position = m._tile_center_px(Vector2i(m._mine_layout["chest"]))
	await process_frame
	var swords_before: int = m.inventory.count_of(WeaponCatalog.SWORD_MYEONGDONG)
	var gold_b2: int = m.wallet.gold
	m._open_mine_chest()
	_check("ⓕl 중복 무기는 판매가만큼 **골드로 대체**(두 자루 금지 · 빈손 금지)",
		m.inventory.count_of(WeaponCatalog.SWORD_MYEONGDONG) == swords_before
		and m.wallet.gold == gold_b2 + WeaponCatalog.price_of(WeaponCatalog.SWORD_MYEONGDONG))

	# ── ⓖ 60층 = 나락 열쇠 ──────────────────────────────────────────────────
	print("── ⓖ 60층 나락 열쇠 ──")
	_check("ⓖa 60층 보상 테이블 = 나락 열쇠 1",
		MineFloors.chest_rewards(60).size() == 1
		and String(MineFloors.chest_rewards(60)[0]["id"]) == ItemCatalog.NARAK_KEY)
	_check("ⓖb 열쇠는 비매(price 0) · 스택 불가 · 유품 아님(기증 대상 0)",
		ItemCatalog.price_of(ItemCatalog.NARAK_KEY) == 0
		and not ItemCatalog.stackable_of(ItemCatalog.NARAK_KEY)
		and not ItemCatalog._is_relic(ItemCatalog.NARAK_KEY))
	m.inventory.remove_item(ItemCatalog.NARAK_KEY, m.inventory.count_of(ItemCatalog.NARAK_KEY))
	m.mine_floors._chests = {}
	m._narak_key_found = false
	m._descend_mine(60)
	await _settle(m)
	_check("ⓖc pre 60층 · 바닥 안내가 상자를 가리킨다",
		m._mine_floor == 60 and m._mine_bottom_line().contains("상자"))
	m.player.global_position = m._tile_center_px(Vector2i(m._mine_layout["chest"]))
	await process_frame
	m._open_mine_chest()
	_check("ⓖd 60층 상자 = 나락 열쇠 지급", m.inventory.count_of(ItemCatalog.NARAK_KEY) == 1)
	_check("ⓖe 영구 마일스톤 플래그가 선다(T7 점등 게이트 — 버려도 안 잠긴다)", m._narak_key_found)
	_check("ⓖf 바닥 안내가 나락 진입로로 바뀐다",
		m._mine_bottom_line().contains("나락") and not m._mine_bottom_line().contains("상자"))
	m.inventory.remove_item(ItemCatalog.NARAK_KEY, 1)
	_check("ⓖg 열쇠를 버려도 플래그는 남는다(진행 봉쇄 방지)",
		m._narak_key_found and not m.inventory.has_item(ItemCatalog.NARAK_KEY))
	_check("ⓖh 나락 진입로는 여전히 잠김(점등 배선 = S5-T7 소관)",
		not m._buildings.has("나락 진입로"))

	# ── ⓘ 로스터 대조 ───────────────────────────────────────────────────────
	print("── ⓘ 로스터 대조 ──")
	var roster_ok := true
	for f in [10, 20, 30, 40, 50, 60]:
		for row: Dictionary in MineFloors.chest_rewards(int(f)):
			if String(row.get("kind", "")) != "item":
				continue
			if not ItemCatalog.has_item(String(row["id"])):
				roster_ok = false
	_check("ⓘa 보상 테이블의 아이템 id가 전부 ItemCatalog에 실재(두 로스터 분기 방지)", roster_ok)
	_check("ⓘb 전 보상 층에 내용물이 있다(빈 상자 0)",
		[10, 20, 30, 40, 50, 60].all(func(f): return not MineFloors.chest_rewards(int(f)).is_empty()))

	# ── ⓙ 회귀 0(골든 서명 불변 — 상자는 RNG를 안 쓴다) ──────────────────────
	print("── ⓙ 회귀(골든 서명) ──")
	# ★값은 mining_test ②·mob_test ④와 **같은 표(T1 시점 원본)** 를 그대로 복사해 왔다. 상자 자리가
	#   RNG를 한 번이라도 소비하면 이 여섯 줄이 즉시 깨진다 = 조기 경보(노드·몹 도입 때와 같은 계약).
	var golden := [
		#  day floor  template   rect                                entrance    ladder      rocks  str(rocks).hash()
		[5, 1, "wide", Rect2i(1, 1, 20, 14), Vector2i(13, 6), Vector2i(9, 11), 25, 630255240],
		[5, 21, "wide", Rect2i(2, 1, 20, 14), Vector2i(9, 2), Vector2i(15, 12), 43, 1221722436],
		[5, 41, "tall", Rect2i(10, 3, 13, 20), Vector2i(19, 20), Vector2i(13, 7), 47, 1516593986],
		[9, 7, "narrow", Rect2i(3, 1, 11, 11), Vector2i(5, 2), Vector2i(9, 11), 27, 2127131022],
		[1, 31, "wide", Rect2i(3, 5, 20, 14), Vector2i(9, 7), Vector2i(18, 18), 34, 1734108470],
		[3, 60, "narrow", Rect2i(3, 3, 11, 11), Vector2i(4, 11), Vector2i(11, 6), 33, 2430958882],
	]
	var golden_ok := true
	var golden_hash_ok := true
	for g: Array in golden:
		var lay := MineFloors.generate(int(g[0]), int(g[1]))
		var rocks: Array = lay["rocks"]
		if String(lay["template"]) != String(g[2]) or lay["rect"] != g[3] \
				or lay["entrance"] != g[4] or lay["ladder"] != g[5] or rocks.size() != int(g[6]):
			golden_ok = false
		if str(rocks).hash() != int(g[7]):
			golden_hash_ok = false
	_check("ⓙa 층 배치 골든 서명 불변 — 템플릿·방·입구·사다리·돌 수(상자 = RNG 소비 0)", golden_ok)
	_check("ⓙb 층 배치 골든 서명 불변 — 돌 좌표 전량 해시", golden_hash_ok)

	# ── ⓗ 세이브 왕복 / 하위호환 ────────────────────────────────────────────
	print("── ⓗ 세이브 ──")
	r.affinity.points = 2 * Affinity.POINTS_PER_HEART
	# 앞 절들이 원장을 여러 번 비웠으므로(각 시나리오가 자기 전제를 세운다) 지금 열려 있는 건 60층뿐이다.
	# 왕복이 **여러 층**을 보존하는지 보려고 10·20을 원장에 직접 연다(지급 경로는 ⓕ가 이미 검증했다).
	m.mine_floors.open_chest(10)
	m.mine_floors.open_chest(20)
	m._ascend_mine_to_surface()
	await _settle(m)
	m._save_game()
	var slot: int = m._active_slot
	await _despawn(m)
	var m2: Node = await _spawn_main()
	_check("ⓗa 무골 ♡이 mugol_affinity 키로 복원", m2._resident("mugol").affinity.hearts() == 2)
	_check("ⓗb 증정 플래그가 세이브를 넘어 유지", m2._mugol_sword_given)
	_check("ⓗc 나락 열쇠 마일스톤 플래그 유지", m2._narak_key_found)
	_check("ⓗd 상자 개봉 원장 복원(10·20·60 열림 · 30은 안 열림)",
		m2.mine_floors.is_chest_opened(10) and m2.mine_floors.is_chest_opened(20)
		and m2.mine_floors.is_chest_opened(60) and not m2.mine_floors.is_chest_opened(30))
	var want_chests: Array[int] = [10, 20, 60]
	_check("ⓗe 개봉 목록이 오름차순", m2.mine_floors.opened_chests() == want_chests)
	await _despawn(m2)
	# 구세이브 — 무골 키 3개(♡·증정 플래그·열쇠 플래그) + 상자 원장을 지운 세이브로 부팅.
	var sm := SaveManager.new()
	var raw := sm.load_game(slot)
	raw.erase("mugol_affinity")
	raw.erase("mugol_sword_given")
	raw.erase("narak_key_found")
	if raw.has("mine") and typeof(raw["mine"]) == TYPE_DICTIONARY:
		var mine_slice: Dictionary = raw["mine"]
		mine_slice.erase("chests")
		raw["mine"] = mine_slice
	sm.save_game(raw, slot)
	var m3: Node = await _spawn_main()
	_check("ⓗf 구세이브 하위호환 — ♡0 · 증정 대기 · 열쇠 없음 · 상자 전부 미개봉(크래시 0)",
		m3._resident("mugol").affinity.hearts() == 0 and not m3._mugol_sword_given
		and not m3._narak_key_found and m3.mine_floors.opened_chests().is_empty())
	var bad := MineFloors.new()
	bad.load_save({"chests": [7, "zz", 20, 999]})
	var want_bad: Array[int] = [20]
	_check("ⓗg 손상 세이브 방어 — 보상 층 아닌 값은 버린다(엉뚱한 봉인 0)",
		bad.opened_chests() == want_bad)
	await _despawn(m3)

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
