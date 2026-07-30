extends SceneTree
# ★[S4-T4 / ADR-0062 결정 6 → S5-T3 / ADR-0063 결정 3] 도구 티어 코어 + 도구 4종 4티어 +
# 대장간 업그레이드(골드 + 주괴 5) + 미혹 심층 구획 검증(ephemeral).
#
# 무엇을 지키나(어기면 ADR-0027 / ADR-0063 결정 3 위반):
#   ① 기본 티어 0 · 세이브 라운드트립(하위호환 = 키 없는 구세이브도 0으로 뜬다)
#   ② 구매 = 골드 + 주괴 차감 + 순차 강제(0→2 직행 불가 — 명동을 거치지 않고 유철을 살 수 없다)
#   ③ 성숙목 타수 감소 10/8/6/5/4(티어별 — 스타듀 결). 규칙표와 **실제 타격 횟수**를 둘 다 본다.
#   ④ 0티어로 큰 그루터기·큰 통나무를 치면 거부 + **혼력 미소모**(무효타는 값을 안 매긴다)
#   ⑤ 명동 = 큰 그루터기 제거(경목 2 + 25XP) · 다음 날 **리스폰**(지속 공급)
#   ⑥ 유철 = 큰 통나무 제거(경목 8 + 25XP) · **영구**(하루가 지나도, 구역을 다시 지어도 안 돌아온다)
#   ⑦ 심층 도달성 flood-fill — **봉쇄 전 도달 불가 → 큰 통나무 제거 후 도달 가능**
#   ⑧ 심층 구획 ↔ 옥자 집 rect 비중첩(스토리 게이트 ↔ 메카닉 게이트 지리적 분리)
#   ★S5-T3 신설:
#   ⑩ MAX_TIER 4 · 전 도구 4계단 · 주괴 재료 게이트(골드만으론 거부) · **소급 없음**
#   ⑪ 곡괭이 티어 타수 감산(MineFloors.node_hits 단일 접점 · 일반 돌 불변)
#   ⑫ 괭이·물뿌리개 AoE 칸 집합 + 물뿌리개 용량 티어 배선
# 실행: godot --headless --path game --script res://playtest/tool_tier_test.gd

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

# 외부에서 걸을 수 있는 칸인가(mihok_forest_test와 같은 판정 — 실내 스택 제외).
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return id != m.WALL and id != m.WATER and id != m.TREE and id != m.VOID

func _reachable(m: Node, start: Vector2i) -> Dictionary:
	var seen := {}
	var stack: Array = [start]
	seen[start] = true
	while not stack.is_empty():
		var t: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + d
			if not seen.has(n) and _walkable(m, n):
				seen[n] = true
				stack.append(n)
	return seen

# 인벤토리에서 이 아이템이 든 슬롯 index(-1 = 없음). tree_test와 같은 헬퍼.
func _slot_of(m: Node, id: String) -> int:
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == id:
			return i
	return -1

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
	print("══ S4-T4 도구 티어 + 도끼 2티어 + 미혹 심층 구획 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s4t4_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 기본 티어 0 · 세이브 라운드트립 · 하위호환 ──
	print("── ① 티어 상태·세이브 ──")
	var tt := ToolTier.new()
	var all_zero := true
	for tool_id: String in ToolTier.TOOLS:
		if tt.tier_of(tool_id) != 0:
			all_zero = false
	_check("①a 기본 티어 = 전 도구 0(도끼·곡괭이·괭이·물뿌리개 키 예약)",
		all_zero and ToolTier.TOOLS.size() == 4)
	tt.set_tier(ToolTier.AXE, 2)
	var tt2 := ToolTier.new()
	tt2.load_save(tt.to_save())
	_check("①b 세이브 라운드트립(도끼 2티어 보존)", tt2.tier_of(ToolTier.AXE) == 2)
	_check("①c 나머지 도구는 0 그대로", tt2.tier_of(ToolTier.PICKAXE) == 0 and tt2.tier_of(ToolTier.HOE) == 0)
	var tt3 := ToolTier.new()
	tt3.set_tier(ToolTier.AXE, 1)
	tt3.load_save({})                      # 키 없는 구세이브(하위호환) — 전 도구 0으로 리셋
	_check("①d 하위호환: 키 없는 구세이브 = 전 도구 티어 0", tt3.tier_of(ToolTier.AXE) == 0)
	var tt4 := ToolTier.new()
	tt4.load_save({"tiers": {"axe": 9, "잡동사니": 3}})
	_check("①e 손상 세이브 방어(상한 클램프·미지 도구 폐기)",
		tt4.tier_of(ToolTier.AXE) == ToolTier.MAX_TIER and tt4.to_save()["tiers"].size() == 4)
	# ★[S5-T3] 도끼만이 아니라 **전 도구**에 계단이 열렸다(ADR-0063 결정 3 ㉡ — "준비 중" 소멸).
	_check("①f 전 도구 4종에 업그레이드 경로(미지 id만 false)",
		ToolTier.is_upgradable(ToolTier.AXE) and ToolTier.is_upgradable(ToolTier.PICKAXE)
		and ToolTier.is_upgradable(ToolTier.HOE) and ToolTier.is_upgradable(ToolTier.WATERING_CAN)
		and not ToolTier.is_upgradable("검"))

	# ── ② 구매 차감(골드 + 주괴) · 순차 강제 ──
	print("── ② 명동·유철 구매(골드 + 주괴 5 · 순차 강제) ──")
	var u1 := ToolTier.next_upgrade(ToolTier.AXE, 0)
	var u2 := ToolTier.next_upgrade(ToolTier.AXE, 1)
	_check("②a 명동 도끼 = 티어1 · 2000냥 · 명동 주괴 5",
		String(u1["name"]) == "명동 도끼" and int(u1["tier"]) == 1 and int(u1["price"]) == 2000
		and String(u1["ingot"]) == ItemCatalog.INGOT_MYEONGDONG and int(u1["ingot_count"]) == 5)
	_check("②b 유철 도끼 = 티어2 · 5000냥 · 유철 주괴 5",
		String(u2["name"]) == "유철 도끼" and int(u2["tier"]) == 2 and int(u2["price"]) == 5000
		and String(u2["ingot"]) == ItemCatalog.INGOT_YUCHEOL and int(u2["ingot_count"]) == 5)
	_check("②c 최고 티어(4)에선 다음 계단 없음 · 티어2의 다음은 황천금(3)",
		ToolTier.next_upgrade(ToolTier.AXE, ToolTier.MAX_TIER).is_empty()
		and int(ToolTier.next_upgrade(ToolTier.AXE, 2)["tier"]) == 3)

	var m: Node = await _spawn_main()
	m.wallet.gold = 100000
	m._indoor = ""
	_check("②d 시작 도끼 = 0티어", m.axe_tier() == 0)
	# 순차 강제: 0티어에서 다음 계단은 **명동뿐**이다(5000냥을 들고 있어도 유철로 직행 못 한다).
	_check("②e 0티어의 다음 계단 = 명동(유철 직행 불가)",
		int(m.tool_tier.pending_upgrade(ToolTier.AXE)["tier"]) == 1)
	# ★[S5-T3] **골드만으론 거부**된다(주괴 게이트). 차감 0 = 반쯤 지불 상태가 없다.
	var gold_only: int = m.wallet.gold
	_check("②f 골드만 있고 주괴가 없으면 거부 + 골드 차감 0",
		not m._try_upgrade_tool(ToolTier.AXE) and m.wallet.gold == gold_only and m.axe_tier() == 0)
	m.inventory.add_item(ItemCatalog.INGOT_MYEONGDONG, 5)
	m.inventory.add_item(ItemCatalog.INGOT_YUCHEOL, 5)
	var gold0: int = m.wallet.gold
	_check("②g 명동 구매 성공", m._try_upgrade_tool(ToolTier.AXE))
	_check("②h 골드 2000냥 + 명동 주괴 5 차감 · 티어 1",
		m.wallet.gold == gold0 - 2000 and m.axe_tier() == 1
		and m.inventory.count_of(ItemCatalog.INGOT_MYEONGDONG) == 0)
	_check("②i 유철 구매 성공", m._try_upgrade_tool(ToolTier.AXE))
	_check("②j 골드 5000냥 + 유철 주괴 5 차감 · 티어 2",
		m.wallet.gold == gold0 - 7000 and m.axe_tier() == 2
		and m.inventory.count_of(ItemCatalog.INGOT_YUCHEOL) == 0)
	_check("②k 다음 계단은 황천금(주괴 없어 거부 — 골드는 그대로)",
		not m._try_upgrade_tool(ToolTier.AXE) and m.wallet.gold == gold0 - 7000 and m.axe_tier() == 2)
	# 냥 부족 거부(차감 0) — 주괴는 있는데 골드가 없는 반대 방향.
	m.tool_tier.set_tier(ToolTier.AXE, 0)
	m.inventory.add_item(ItemCatalog.INGOT_MYEONGDONG, 5)
	m.wallet.gold = 100
	_check("②l 냥 부족이면 거부 + 주괴 소모 0",
		not m._try_upgrade_tool(ToolTier.AXE) and m.wallet.gold == 100 and m.axe_tier() == 0
		and m.inventory.count_of(ItemCatalog.INGOT_MYEONGDONG) == 5)
	m.inventory.remove_item(ItemCatalog.INGOT_MYEONGDONG, 5)
	# 대장간 업그레이드대 좌표 = 대장간 실내 방 안(혼백관 기증대와 같은 결).
	_check("②m 업그레이드대가 대장간 실내 rect 안",
		m.SMITHY_RECT.has_point(m.SMITHY_UPGRADE_TILE)
		and m.SMITHY_UPGRADE_TILE.x > m.SMITHY_RECT.position.x
		and m.SMITHY_UPGRADE_TILE.y > m.SMITHY_RECT.position.y)
	m.wallet.gold = 100000
	m._indoor = "대장간"
	var prompt0: String = m._tool_upgrade_prompt(ToolTier.AXE)
	_check("②n 프롬프트에 현재 티어·다음 티어·가격·주괴가 다 보인다",
		prompt0.contains("도끼") and prompt0.contains("명동 도끼") and prompt0.contains("2000")
		and prompt0.contains("명동 주괴"))
	# ★[S5-T3] 나머지 3종도 "준비 중"이 아니라 실제 계단을 보인다.
	var prompt_px: String = m._tool_upgrade_prompt(ToolTier.PICKAXE)
	var prompt_hoe: String = m._tool_upgrade_prompt(ToolTier.HOE)
	_check("②o 곡괭이·괭이도 실제 계단을 보인다('준비 중' 소멸)",
		prompt_px.contains("명동 곡괭이") and not prompt_px.contains("준비 중")
		and prompt_hoe.contains("명동 괭이") and not prompt_hoe.contains("준비 중"))
	_check("②p 든 게 도구가 아니면 '들고 서자' 안내(무엇도 준비 중이 아니다)",
		m._tool_upgrade_prompt("").contains("들고"))
	m._indoor = ""

	# ── ③ 성숙목 타수 감소 10/8/6/5/4 ──
	print("── ③ 도끼 티어 타수(10/8/6/5/4) ──")
	_check("③a 규칙표 = 10/8/6/5/4", ToolTier.axe_mature_hp(0) == 10
		and ToolTier.axe_mature_hp(1) == 8 and ToolTier.axe_mature_hp(2) == 6
		and ToolTier.axe_mature_hp(3) == 5 and ToolTier.axe_mature_hp(4) == 4)
	_check("③b TreeLedger 0티어 기준값과 동치(HP_MATURE)", TreeLedger.HP_MATURE == ToolTier.axe_mature_hp(0))
	for tier in ToolTier.MAX_TIER + 1:
		var led := TreeLedger.new()
		led.seed_region("t%d" % tier, [Vector2i(3, 3)])
		var hits := 0
		for i in 30:
			if not led.is_mature("t%d" % tier, Vector2i(3, 3)):
				break
			led.chop("t%d" % tier, Vector2i(3, 3), 1, 0, 0, 0.0, tier)
			hits += 1
		_check("③c 티어%d 성숙목 실타격 %d회 = %d타" % [tier, hits, ToolTier.axe_mature_hp(tier)],
			hits == ToolTier.axe_mature_hp(tier))
	# 중간에 도끼를 바꿔도 잔여 타수가 늘거나 줄지 않는다(손댄 나무는 시작 눈금을 이어 센다).
	var led_mix := TreeLedger.new()
	led_mix.seed_region("mix", [Vector2i(1, 1)])
	led_mix.chop("mix", Vector2i(1, 1), 1, 0, 0, 0.0, 0)      # 0티어로 1타(10 → 9)
	_check("③d 손댄 나무는 티어를 올려도 잔여 타수 유지(9타)", led_mix.hp_at("mix", Vector2i(1, 1), 2) == 9)

	# ── ④ 0티어 큰 장애물 거부(혼력 미소모) ──
	print("── ④ 0티어 큰 장애물 거부 ──")
	m._rebuild_region(RegionCatalog.MIHOK_FOREST)
	m.tool_tier.set_tier(ToolTier.AXE, 0)
	m.inventory.select(_slot_of(m, ItemCatalog.AXE))
	var log_t: Vector2i = m.MIHOK_DEEP_LOG_TILES[0]
	var stump_t: Vector2i = m.MIHOK_DEEP_STUMP_TILES[0]
	_check("④a 심층 큰 통나무 2개·큰 그루터기 6개가 원장에 섰다",
		m.tree_ledger.large_tiles(m._region, TreeLedger.KIND_LARGE_LOG).size() == 2
		and m.tree_ledger.large_tiles(m._region, TreeLedger.KIND_LARGE_STUMP).size() == 6)
	_check("④b 큰 장애물은 SOLID(통과 불가)", not _walkable(m, log_t) and not _walkable(m, stump_t))
	var e0: float = m.energy.current
	var hp_log0: int = m.tree_ledger.hp_at(m._region, log_t)
	m._chop_tree(log_t)
	_check("④c 0티어 큰 통나무 타격 거부 — 혼력 미소모·타수 불변",
		m.energy.current == e0 and m.tree_ledger.hp_at(m._region, log_t) == hp_log0
		and m.tree_ledger.is_occupied(m._region, log_t))
	m._chop_tree(stump_t)
	_check("④d 0티어 큰 그루터기 타격 거부 — 혼력 미소모",
		m.energy.current == e0 and m.tree_ledger.is_occupied(m._region, stump_t))
	var pr_log: String = m._tree_prompt(log_t)
	var pr_stump: String = m._tree_prompt(stump_t)
	_check("④e 프롬프트가 요구 도끼를 밝힌다", pr_log.contains("유철") and pr_stump.contains("명동"))
	# 명동(티어1)으로도 큰 통나무는 안 깨진다(게이트가 종별로 갈린다).
	m.tool_tier.set_tier(ToolTier.AXE, 1)
	m._chop_tree(log_t)
	_check("④f 명동으로도 큰 통나무는 거부(유철 전용)",
		m.energy.current == e0 and m.tree_ledger.is_occupied(m._region, log_t))

	# ── ⑤ 명동 = 큰 그루터기 제거(경목 2 + 25XP) · 일일 리스폰 ──
	print("── ⑤ 명동 → 큰 그루터기 ──")
	var hw0: int = m.inventory.count_of(ItemCatalog.HARDWOOD)
	var xp0: int = m._foraging_xp
	var swings := 0
	for i in 30:
		if not m.tree_ledger.is_occupied(m._region, stump_t):
			break
		m.energy.current = SoulEnergy.MAX    # 혼력은 이 단언의 관심사가 아니다(④가 이미 봤다)
		m._chop_tree(stump_t)
		swings += 1
	_check("⑤a 명동으로 큰 그루터기 제거(%d타)" % swings,
		not m.tree_ledger.is_occupied(m._region, stump_t) and swings == TreeLedger.HP_LARGE_STUMP)
	_check("⑤b 단단한 원목 +2", m.inventory.count_of(ItemCatalog.HARDWOOD) == hw0 + 2)
	_check("⑤c 큰 장애물 XP +25", m._foraging_xp == xp0 + ForageSkill.LARGE_OBSTACLE_XP)
	_check("⑤d 치운 자리가 걸을 수 있게 열림", _walkable(m, stump_t))
	m.tree_ledger.advance_day(2, Callable())
	m._sync_tree_tile(stump_t)
	_check("⑤e 다음 날 큰 그루터기 리스폰(지속 공급)",
		m.tree_ledger.is_occupied(m._region, stump_t) and not _walkable(m, stump_t)
		and m.tree_ledger.hp_at(m._region, stump_t) == TreeLedger.HP_LARGE_STUMP)

	# ── ⑥ 유철 = 큰 통나무 제거(경목 8 + 25XP) · 영구 ──
	print("── ⑥ 유철 → 큰 통나무 ──")
	m.tool_tier.set_tier(ToolTier.AXE, 2)
	var hw1: int = m.inventory.count_of(ItemCatalog.HARDWOOD)
	var xp1: int = m._foraging_xp
	for t: Vector2i in m.MIHOK_DEEP_LOG_TILES:
		for i in 30:
			if not m.tree_ledger.is_occupied(m._region, t):
				break
			m.energy.current = SoulEnergy.MAX
			m._chop_tree(t)
	_check("⑥a 유철로 큰 통나무 2개 제거",
		not m.tree_ledger.is_occupied(m._region, m.MIHOK_DEEP_LOG_TILES[0])
		and not m.tree_ledger.is_occupied(m._region, m.MIHOK_DEEP_LOG_TILES[1]))
	_check("⑥b 단단한 원목 +16(8×2)", m.inventory.count_of(ItemCatalog.HARDWOOD) == hw1 + 16)
	_check("⑥c 큰 장애물 XP +50(25×2)", m._foraging_xp == xp1 + ForageSkill.LARGE_OBSTACLE_XP * 2)
	m.tree_ledger.advance_day(3, Callable())
	_check("⑥d 하루가 지나도 큰 통나무는 안 돌아온다(재생성 없음)",
		not m.tree_ledger.is_occupied(m._region, m.MIHOK_DEEP_LOG_TILES[0])
		and not m.tree_ledger.is_occupied(m._region, m.MIHOK_DEEP_LOG_TILES[1]))
	m._rebuild_region(RegionCatalog.MIHOK_FOREST)
	_check("⑥e 구역을 다시 지어도 안 돌아온다(영구 개방)",
		not m.tree_ledger.is_occupied(m._region, m.MIHOK_DEEP_LOG_TILES[0])
		and _walkable(m, m.MIHOK_DEEP_LOG_TILES[0]))

	# ── ⑦ 심층 도달성 flood-fill(봉쇄 전 불가 → 제거 후 가능) ──
	print("── ⑦ 심층 도달성 ──")
	var spawn: Vector2i = RegionCatalog.spawn_of(RegionCatalog.MIHOK_FOREST)
	var reach_open := _reachable(m, spawn)
	var deep_center := Vector2i(m.MIHOK_DEEP_ZONE_RECT.position.x + 1, m.MIHOK_DEEP_ZONE_RECT.position.y + 2)
	_check("⑦a 큰 통나무 제거 **후** 심층 도달 가능", reach_open.has(deep_center))
	await _despawn(m)

	# 새 판(원장 초기 상태 = 봉쇄)에서 도달 불가를 본다 — 같은 인스턴스로는 되돌릴 수 없으므로 재부팅.
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m2: Node = await _spawn_main()
	m2._rebuild_region(RegionCatalog.MIHOK_FOREST)
	var reach_blocked := _reachable(m2, spawn)
	var deep_all_blocked := true
	for y in range(m2.MIHOK_DEEP_ZONE_RECT.position.y, m2.MIHOK_DEEP_ZONE_RECT.end.y):
		for x in range(m2.MIHOK_DEEP_ZONE_RECT.position.x, m2.MIHOK_DEEP_ZONE_RECT.end.x):
			if reach_blocked.has(Vector2i(x, y)):
				deep_all_blocked = false
	_check("⑦b 봉쇄 **전** 심층 존 36칸 전량 도달 불가(0티어로는 못 들어간다)", deep_all_blocked)
	# 회귀: 봉쇄가 기존 도달성을 하나도 깨지 않는다(특수 채집지 2곳·옥자 집 문·복귀 워프).
	_check("⑦c 회귀 — 특수 채집지 2곳·옥자 집 문·복귀 워프는 그대로 도달",
		reach_blocked.has(m2.MIHOK_FORAGE_LABEL_TILE) and reach_blocked.has(m2.MIHOK_FORAGE_LABEL_TILE_2)
		and reach_blocked.has(m2.OKJA_HUT_DOOR) and reach_blocked.has(Vector2i(1, 22)))
	# 봉쇄 링은 **원장 밖**이다 — 0티어 도끼로 벽을 우회해 들어갈 수 없다(게이트의 구조적 보증).
	var ring_in_ledger := 0
	for y in range(m2.MIHOK_DEEP_WALL_RECT.position.y, m2.MIHOK_DEEP_WALL_RECT.end.y):
		for x in range(m2.MIHOK_DEEP_WALL_RECT.position.x, m2.MIHOK_DEEP_WALL_RECT.end.x):
			var t := Vector2i(x, y)
			if m2._is_mihok_deep_wall(t) and m2.tree_ledger.has_slot(m2._region, t) \
					and not m2.tree_ledger.is_large(m2._region, t):
				ring_in_ledger += 1
	_check("⑦d 봉쇄 링 TREE가 원장에 하나도 없음(벌목 우회 0)", ring_in_ledger == 0)
	# 서측 진입목은 2칸이라, 하나만 치워도 그 한 칸이 곧 문이 된다(나머지 하나는 여전히 벽).
	m2.tool_tier.set_tier(ToolTier.AXE, 2)
	m2.inventory.select(_slot_of(m2, ItemCatalog.AXE))
	for i in 30:
		if not m2.tree_ledger.is_occupied(m2._region, m2.MIHOK_DEEP_LOG_TILES[0]):
			break
		m2.energy.current = SoulEnergy.MAX
		m2._chop_tree(m2.MIHOK_DEEP_LOG_TILES[0])
	var reach_half := _reachable(m2, spawn)
	_check("⑦e 큰 통나무 하나만 치워도 그 칸으로 심층에 들어간다(진입목 = 실제 문)",
		reach_half.has(Vector2i(m2.MIHOK_DEEP_ZONE_RECT.position.x, m2.MIHOK_DEEP_LOG_TILES[0].y)))

	# ── ⑧ 심층 구획 ↔ 옥자 집 비중첩 ──
	print("── ⑧ 공간 분리 ──")
	_check("⑧a 심층 봉쇄 링 ↔ 옥자 집 rect 비중첩",
		not m2.MIHOK_DEEP_WALL_RECT.intersects(m2.OKJA_HUT_EXT_RECT))
	_check("⑧b 심층 존 ↔ 옥자 집 rect 비중첩",
		not m2.MIHOK_DEEP_ZONE_RECT.intersects(m2.OKJA_HUT_EXT_RECT))
	_check("⑧c 심층 존 = ForageSpawns 심층 존 rect와 1:1(스폰 원장 정합)",
		ForageSpawns.zone_kind_at(RegionCatalog.MIHOK_FOREST,
			m2.MIHOK_DEEP_ZONE_RECT.position) == ForageSpawns.KIND_DEEP
		and ForageSpawns.zone_kind_at(RegionCatalog.MIHOK_FOREST,
			m2.MIHOK_DEEP_ZONE_RECT.end - Vector2i(1, 1)) == ForageSpawns.KIND_DEEP)
	var stumps_inside := true
	for t: Vector2i in m2.MIHOK_DEEP_STUMP_TILES:
		if not m2.MIHOK_DEEP_ZONE_RECT.has_point(t):
			stumps_inside = false
	_check("⑧d 큰 그루터기 6개 전부 심층 존 안", stumps_inside)
	var logs_on_ring := true
	for t: Vector2i in m2.MIHOK_DEEP_LOG_TILES:
		if not m2.MIHOK_DEEP_WALL_RECT.has_point(t) or m2.MIHOK_DEEP_ZONE_RECT.has_point(t):
			logs_on_ring = false
	_check("⑧e 큰 통나무 2개는 링 위(존 밖 — 진입목)", logs_on_ring)
	await _despawn(m2)

	# ── ⑨ 회귀 0: 홈 집 출입·취침 불변 ──
	print("── ⑨ 회귀 ──")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m3: Node = await _spawn_main()
	_check("⑨a 시작 구역 = home(회귀)", m3._region == RegionCatalog.HOME)
	_check("⑨b 새 판 도끼 티어 = 0", m3.axe_tier() == 0)

	# ── ★[S5-T3] ⑩ MAX_TIER 4 · 전 도구 4계단 · 소급 없음 ──
	print("── ⑩ 4티어 확장 · 소급 없음 ──")
	_check("⑩a MAX_TIER = 4(금속 4티어와 1:1)", ToolTier.MAX_TIER == 4)
	var stairs_ok := true
	for tool_id: String in ToolTier.TOOLS:
		var ups := ToolTier.upgrades_for(tool_id)
		if ups.size() != 4:
			stairs_ok = false
			continue
		for i in 4:
			var u: Dictionary = ups[i]
			if int(u["tier"]) != i + 1 or int(u["price"]) != int(ToolTier.TIER_PRICES[i + 1]) \
					or String(u["ingot"]) != String(ToolTier.TIER_INGOTS[i + 1]) \
					or int(u["ingot_count"]) != 5 or not ItemCatalog._is_ingot(String(u["ingot"])):
				stairs_ok = false
	_check("⑩b 전 도구 4계단 = 2000/5000/10000/25000 + 각 티어 주괴 5", stairs_ok)
	_check("⑩c 티어 명명 = 접두사 + 도구명(ItemCatalog 단일 출처)",
		ToolTier.tier_name(ToolTier.PICKAXE, 3) == "황천금 곡괭이"
		and ToolTier.tier_name(ToolTier.WATERING_CAN, 4) == "나락철 물뿌리개"
		and ToolTier.tier_name(ToolTier.HOE, 0) == "괭이")
	# ★소급 없음: 이미 산 티어(도끼 2)는 그대로 남고, 요구가 생기는 건 **다음 계단부터**다.
	#   원장이 "무엇으로 샀나"를 안 들기 때문에 티어를 직접 세팅한 세이브도 그대로 유효하다.
	m3.tool_tier.set_tier(ToolTier.AXE, 2)
	m3.wallet.gold = 100000
	_check("⑩d 소급 없음 — 기존 티어2는 유지 · 요구는 다음 계단(황천금 주괴)부터",
		m3.axe_tier() == 2
		and String(m3.tool_tier.pending_upgrade(ToolTier.AXE)["ingot"]) == ItemCatalog.INGOT_HWANGCHEONGEUM
		and not m3._try_upgrade_tool(ToolTier.AXE)   # 황천금 주괴가 없어 거부
		and m3.axe_tier() == 2)
	m3.inventory.add_item(ItemCatalog.INGOT_HWANGCHEONGEUM, 5)
	m3.inventory.add_item(ItemCatalog.INGOT_NARAKCHEOL, 5)
	_check("⑩e 황천금 → 나락철까지 올라 최고 티어에서 멈춘다",
		m3._try_upgrade_tool(ToolTier.AXE) and m3.axe_tier() == 3
		and m3._try_upgrade_tool(ToolTier.AXE) and m3.axe_tier() == 4
		and not m3._try_upgrade_tool(ToolTier.AXE) and m3.axe_tier() == ToolTier.MAX_TIER)
	m3.tool_tier.set_tier(ToolTier.AXE, 0)

	# ── ★[S5-T3] ⑪ 곡괭이 티어 광맥 타수 감산(MineFloors.node_hits 단일 접점) ──
	print("── ⑪ 곡괭이 타수 감산 ──")
	_check("⑪a 규칙표 [0]이 MineFloors 0티어 기준값과 동치(ORE_HITS·GEM_HITS)",
		MineFloors.ORE_HITS == ToolTier.pickaxe_ore_hits(0)
		and MineFloors.GEM_HITS == ToolTier.pickaxe_gem_hits(0))
	_check("⑪b 광석 3/2/2/1/1 · 보석 5/4/3/2/2(*잠정*)",
		ToolTier.PICK_ORE_HITS == [3, 2, 2, 1, 1] and ToolTier.PICK_GEM_HITS == [5, 4, 3, 2, 2])
	var hits_ok := true
	for tier in ToolTier.MAX_TIER + 1:
		if MineFloors.node_hits(MineFloors.N_MYEONGDONG, tier) != ToolTier.pickaxe_ore_hits(tier) \
				or MineFloors.node_hits(MineFloors.N_HONTAN, tier) != ToolTier.pickaxe_ore_hits(tier) \
				or MineFloors.node_hits(MineFloors.N_GEM_MYEONGOK, tier) != ToolTier.pickaxe_gem_hits(tier) \
				or MineFloors.node_hits(MineFloors.N_GEODE_NEOKAL, tier) != ToolTier.pickaxe_gem_hits(tier):
			hits_ok = false
	_check("⑪c node_hits(id, tier)가 부류별로 규칙표를 그대로 쓴다(수치 복제 0)", hits_ok)
	var rock_flat := true
	for tier in ToolTier.MAX_TIER + 1:
		if MineFloors.node_hits("", tier) != MineFloors.ROCK_HITS:
			rock_flat = false
	_check("⑪d 일반 돌은 티어 무관 1타(이미 즉발 — 깎을 게 없다)", rock_flat)
	_check("⑪e 인자 없는 기존 호출 = 0티어(회귀 0)",
		MineFloors.node_hits(MineFloors.N_MYEONGDONG) == MineFloors.ORE_HITS
		and MineFloors.node_hits(MineFloors.N_GEM_MYEONGBU) == MineFloors.GEM_HITS)
	_check("⑪f 큰 바위 게이트 = 유철 곡괭이(도끼 큰 통나무 문법 동형·배치는 후속)",
		ToolTier.TIER_LARGE_BOULDER == 2 and not ToolTier.pickaxe_breaks_boulder(1)
		and ToolTier.pickaxe_breaks_boulder(2))
	# 라이브: 곡괭이를 벼리면 그 프레임부터 타수가 줄어든다(main._mine_rock의 접점 하나).
	m3.tool_tier.set_tier(ToolTier.PICKAXE, 4)
	_check("⑪g 라이브 — 4티어 곡괭이에서 광석 1타 · 보석 2타",
		MineFloors.node_hits(MineFloors.N_MYEONGDONG, m3.pickaxe_tier()) == 1
		and MineFloors.node_hits(MineFloors.N_GEM_MYEONGOK, m3.pickaxe_tier()) == 2)
	m3.tool_tier.set_tier(ToolTier.PICKAXE, 0)

	# ── ★[S5-T3] ⑫ 괭이·물뿌리개 AoE + 물뿌리개 용량 ──
	print("── ⑫ AoE · 용량 ──")
	_check("⑫a AoE 표 = 1×1 / 1×1 / 1×3 / 1×3 / 3×3(*잠정* — 티어1은 범위 이득 0)",
		ToolTier.aoe_of(ToolTier.HOE, 0) == Vector2i(1, 1)
		and ToolTier.aoe_of(ToolTier.HOE, 1) == Vector2i(1, 1)
		and ToolTier.aoe_of(ToolTier.HOE, 2) == Vector2i(1, 3)
		and ToolTier.aoe_of(ToolTier.HOE, 3) == Vector2i(1, 3)
		and ToolTier.aoe_of(ToolTier.HOE, 4) == Vector2i(3, 3))
	_check("⑫b 물뿌리개 AoE = 괭이와 동형 · 도끼·곡괭이는 항상 1×1(차원 분리)",
		ToolTier.aoe_of(ToolTier.WATERING_CAN, 4) == Vector2i(3, 3)
		and ToolTier.aoe_of(ToolTier.AXE, 4) == Vector2i(1, 1)
		and ToolTier.aoe_of(ToolTier.PICKAXE, 4) == Vector2i(1, 1))
	# 칸 집합 — 조준 칸을 플레이어 기준 남쪽 한 칸으로 두고 1×3이 그 방향으로 뻗는지 본다.
	var pt: Vector2i = m3._player_tile()
	var aim := pt + Vector2i(0, 1)
	var line3: Array = m3._tool_aoe_tiles(aim, Vector2i(1, 3))
	_check("⑫c 1×3 = 바라보는 방향으로 일렬 3칸(가까운 칸부터·결정적 순서)",
		line3.size() == 3 and line3[0] == aim and line3[1] == aim + Vector2i(0, 1)
		and line3[2] == aim + Vector2i(0, 2))
	var sq: Array = m3._tool_aoe_tiles(aim, Vector2i(3, 3))
	_check("⑫d 3×3 = 조준 칸 중심 9칸(중심 포함)",
		sq.size() == 9 and sq.has(aim) and sq.has(aim + Vector2i(-1, -1))
		and sq.has(aim + Vector2i(1, 1)))
	var one: Array = m3._tool_aoe_tiles(aim, Vector2i(1, 1))
	_check("⑫e 1×1 = 조준 칸 하나(0·1티어 거동 = 기존과 완전 동일)",
		one.size() == 1 and one[0] == aim)
	_check("⑫f 방향이 없으면(자기 칸 조준) 1×3도 한 칸으로 폴백",
		m3._tool_aoe_tiles(pt, Vector2i(1, 3)).size() == 1)
	_check("⑫g 물뿌리개 용량 = 20/30/40/55/70 · [0]은 기존 구현값",
		ToolTier.can_capacity(0) == m3._CAN_CAPACITY and ToolTier.CAN_CAPACITY == [20, 30, 40, 55, 70])
	m3.tool_tier.set_tier(ToolTier.WATERING_CAN, 3)
	_check("⑫h 라이브 — 벼리면 상한이 그 프레임부터 넓어진다(잔량은 안 채운다)",
		m3._can_capacity() == 55)
	m3._refill_watering_can()
	_check("⑫i 리필하면 넓어진 통이 가득 찬다", m3._can_water == 55)
	m3.tool_tier.set_tier(ToolTier.WATERING_CAN, 0)
	_check("⑫j 티어를 되돌리면 상한도 되돌아온다(파생 — 세이브 상태 아님)", m3._can_capacity() == 20)
	# ★AoE는 형태만 만들고, **조준 칸 밖은 _is_farmable로 걸러진다** — FarmField.hoe가 좌표를 안 보므로
	#   이 필터가 없으면 3×3 괭이가 벽·물·맵 밖을 밭으로 갈아 버린다. 조준 칸 자체는 호출 측 게이트
	#   (_target_valid)의 책임이라 여기서 거르지 않는다(0티어 거동 불변의 근거).
	var filt: Array = m3._farm_aoe_tiles(aim, Vector2i(3, 3))
	var extras_ok := true
	for ft: Vector2i in filt:
		if ft != aim and not m3._is_farmable(ft):
			extras_ok = false
	var outside: Array = m3._farm_aoe_tiles(Vector2i(-5, -5), Vector2i(3, 3))
	_check("⑫k 밭 필터 — 조준 칸 밖 AoE는 farmable만 · 맵 밖 3×3은 조준 칸 하나로 접힌다",
		extras_ok and outside.size() == 1 and outside[0] == Vector2i(-5, -5))
	await _despawn(m3)

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
