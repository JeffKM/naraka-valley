extends SceneTree
# ★[S10-T2 / ADR-0069 결정 3] 스프링클러 상위 2티어 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 티어 눈금·범위 오프셋 — 4(십자) / 8(3×3) / 24(5×5)이고, 범위 밖 티어는 티어1로 접힌다.
#   ② 아이템 ↔ 티어 매핑 — 카탈로그가 id→티어, Sprinkler가 티어→범위를 든다(삼각 디커플링).
#   ③ 제작 게이트 — **농사 스킬 + 주괴**(결정 3). 채집 축은 무영향이고, 2차 축 id가 레시피에 실린다.
#   ④ 원장 — 티어를 싣고 급수 범위가 티어를 따른다(watered_targets 합집합·targets_of).
#   ⑤ 세이브 왕복 — 티어가 살아남고, **구세이브([x,y] 2원소)는 티어1로 읽힌다**(하위호환).
#   ⑥ main 배선 — 든 아이템이 티어를 정하고(설치), 회수는 **선 티어 그대로** 돌려준다.
#   ⑦ 급수 실효 — 티어3을 놓으면 5×5 안 작물이 아침에 젖고 그 바깥은 안 젖는다(급수 로직 불변).
#
# ⚠️ 분모·개수 단언은 전부 카탈로그/오프셋 파생이다(하드코딩 stale 금지 — 티어가 늘면 여기도 따라온다).
#
# 실행: TIMEOUT=180 ./run_tests.sh sprinkler_tier   (헤드리스는 반드시 game/에서 · 순차)

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

# 든 아이템 선택(없으면 인벤 넣고 그 슬롯 선택 — sprinkler_test 결).
func _select(m: Node, id: String) -> void:
	if not m.inventory.has_item(id):
		m.inventory.add_item(id, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

# 스프링클러를 설치할 수 있는 첫 칸(그리드 스캔 — sprinkler_test와 같은 헬퍼).
func _find_placeable(m: Node) -> Vector2i:
	for y in range(m._outdoor_h):
		for x in range(m._grid_w):
			var t := Vector2i(x, y)
			if m._can_place_sprinkler(t):
				return t
	return Vector2i(-1, -1)

func _initialize() -> void:
	print("══ S10-T2 스프링클러 상위 2티어 검증 ══")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	_part_pure()
	await _part_main()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(1 if _fail > 0 else 0)

# ══ 순수 층(main 불필요) ══════════════════════════════════════════════════════
func _part_pure() -> void:
	# ── ① 티어 눈금·범위 오프셋 ──
	print("── ① 티어 눈금·급수 범위 ──")
	_check("①a 티어 3단(1·2·3)", Sprinkler.TIERS.size() == 3
		and Sprinkler.TIERS[0] == Sprinkler.TIER_1 and Sprinkler.TIERS[2] == Sprinkler.TIER_3)
	_check("①b 범위 = 4(십자) / 8(3×3) / 24(5×5)",
		Sprinkler.range_size(Sprinkler.TIER_1) == 4
		and Sprinkler.range_size(Sprinkler.TIER_2) == 8
		and Sprinkler.range_size(Sprinkler.TIER_3) == 24)
	_check("①c 티어1 오프셋 = 옛 CROSS_OFFSETS 그대로(회귀 표면 보존)",
		Sprinkler.offsets_for(Sprinkler.TIER_1) == Sprinkler.CROSS_OFFSETS)
	# 오프셋 자체의 형태 검증 — 앵커(0,0)를 안 담고, 3×3/5×5 상자를 정확히 채운다.
	var box_ok := true
	for tier in [Sprinkler.TIER_2, Sprinkler.TIER_3]:
		var r := 1 if tier == Sprinkler.TIER_2 else 2
		var seen: Dictionary = {}
		for d: Vector2i in Sprinkler.offsets_for(tier):
			if absi(d.x) > r or absi(d.y) > r or d == Vector2i.ZERO or seen.has(d):
				box_ok = false
			seen[d] = true
		if seen.size() != (2 * r + 1) * (2 * r + 1) - 1:
			box_ok = false
	_check("①d 3×3·5×5 = 앵커 제외 정사각 채움(중복 0·범위 초과 0)", box_ok)
	_check("①e 범위 밖 티어는 티어1로 접힌다(손상 방어)",
		Sprinkler.offsets_for(0) == Sprinkler.CROSS_OFFSETS
		and Sprinkler.offsets_for(9) == Sprinkler.CROSS_OFFSETS
		and not Sprinkler.is_tier(0) and not Sprinkler.is_tier(4))

	# ── ② 아이템 ↔ 티어 매핑 ──
	print("── ② 아이템 ↔ 티어 매핑 ──")
	var items := [ItemCatalog.SPRINKLER, ItemCatalog.SPRINKLER_T2, ItemCatalog.SPRINKLER_T3]
	var map_ok := true
	for i in items.size():
		var id: String = String(items[i])
		if ItemCatalog.sprinkler_tier_of(id) != i + 1 or not ItemCatalog.is_sprinkler(id):
			map_ok = false
		if ItemCatalog.sprinkler_item_for_tier(i + 1) != id:
			map_ok = false
		# 카탈로그·원장이 같은 표시명을 말한다(두 진실원 대조).
		if ItemCatalog.name_of(id) != Sprinkler.tier_name(i + 1):
			map_ok = false
	_check("②a 3종 아이템 ↔ 티어 1:1(양방향)·표시명 일치", map_ok)
	_check("②b 로스터 크기 = 티어 수(하드코딩 없음)",
		ItemCatalog.SPRINKLER_TIERS.size() == Sprinkler.TIERS.size())
	_check("②c 스프링클러가 아닌 id는 티어 0", ItemCatalog.sprinkler_tier_of(ItemCatalog.HAY) == 0
		and not ItemCatalog.is_sprinkler(ItemCatalog.HAY)
		and ItemCatalog.sprinkler_item_for_tier(99) == "")
	var reg_ok := true
	for id in [ItemCatalog.SPRINKLER_T2, ItemCatalog.SPRINKLER_T3]:
		if not ItemCatalog.has_item(id) or ItemCatalog.category_of(id) != ItemCatalog.CAT_PLACEABLE \
				or not ItemCatalog.stackable_of(id) or ItemCatalog.name_of(id) == "":
			reg_ok = false
	_check("②d 상위 2티어 = 등록된 스택 CAT_PLACEABLE(티어1과 같은 칸)", reg_ok)

	# ── ③ 제작 게이트(농사 스킬 + 주괴) ──
	print("── ③ 제작 게이트 = 농사 스킬 + 주괴 ──")
	var recipes := {CraftCatalog.SPRINKLER_T2: 4, CraftCatalog.SPRINKLER_T3: 8}
	var gate_ok := true
	for rid in recipes:
		var want: int = int(recipes[rid])
		if CraftCatalog.skill_gate_of(String(rid)) != want:
			gate_ok = false
		if CraftCatalog.skill_gate_id_of(String(rid)) != ProfessionCatalog.FARMING:
			gate_ok = false
		# 농사 레벨이 문턱 미만이면 잠기고, 닿으면 열린다(채집 레벨은 무영향 — 0으로 고정).
		if CraftCatalog.unlocked(String(rid), 0, {}, want - 1):
			gate_ok = false
		if not CraftCatalog.unlocked(String(rid), 0, {}, want):
			gate_ok = false
	_check("③a 농사 Lv4/Lv8 게이트 · 2차 축 id = farming", gate_ok)
	_check("③b 채집 축은 무영향(unlock_level 0 — 채집 Lv0에서도 농사만 차면 열린다)",
		int(CraftCatalog.get_recipe(CraftCatalog.SPRINKLER_T2)["unlock_level"]) == 0
		and CraftCatalog.unlocked(CraftCatalog.SPRINKLER_T2, 0, {}, 4))
	# 재료 = 하위 티어 1 + 주괴 1(업그레이드 사슬).
	var m2: Array = CraftCatalog.get_recipe(CraftCatalog.SPRINKLER_T2)["mats"]
	var m3: Array = CraftCatalog.get_recipe(CraftCatalog.SPRINKLER_T3)["mats"]
	_check("③c 재료 = 하위 티어 1 + 주괴 1(유철 / 황천금)",
		String(m2[0]["item"]) == ItemCatalog.SPRINKLER and String(m2[1]["item"]) == ItemCatalog.INGOT_YUCHEOL
		and String(m3[0]["item"]) == ItemCatalog.SPRINKLER_T2 and String(m3[1]["item"]) == ItemCatalog.INGOT_HWANGCHEONGEUM)
	_check("③d 산출 = 그 티어 아이템 ×1",
		String(CraftCatalog.get_recipe(CraftCatalog.SPRINKLER_T2)["out_item"]) == ItemCatalog.SPRINKLER_T2
		and String(CraftCatalog.get_recipe(CraftCatalog.SPRINKLER_T3)["out_item"]) == ItemCatalog.SPRINKLER_T3)
	_check("③e 제작 탭 목록에 편입(두 티어 다)",
		CraftCatalog.ids().has(CraftCatalog.SPRINKLER_T2) and CraftCatalog.ids().has(CraftCatalog.SPRINKLER_T3))

	# ── ④ 원장(티어를 싣는다) ── + ⑤ 세이브 왕복·구세이브 하위호환 ──
	print("── ④⑤ 원장 티어·세이브 왕복 ──")
	var s := Sprinkler.new()
	_check("④a 인자 없는 place = 티어1(기존 호출 거동 불변)",
		s.place(Vector2i(2, 2)) and s.tier_at(Vector2i(2, 2)) == Sprinkler.TIER_1)
	_check("④b 티어 지정 설치", s.place(Vector2i(9, 9), Sprinkler.TIER_3)
		and s.tier_at(Vector2i(9, 9)) == Sprinkler.TIER_3)
	_check("④c 손상 티어는 티어1로 접힌다", s.place(Vector2i(20, 20), 77)
		and s.tier_at(Vector2i(20, 20)) == Sprinkler.TIER_1)
	_check("④d 미설치 칸의 티어 = 0", s.tier_at(Vector2i(1, 1)) == 0)
	_check("④e 급수 대상 = 티어별 범위 합집합",
		s.targets_of(Vector2i(9, 9)).size() == Sprinkler.range_size(Sprinkler.TIER_3)
		and s.targets_of(Vector2i(2, 2)).size() == Sprinkler.range_size(Sprinkler.TIER_1)
		and s.watered_targets().size() > Sprinkler.range_size(Sprinkler.TIER_3))
	_check("④f 티어별 설치 수 집계", s.count_of_tier(Sprinkler.TIER_1) == 2
		and s.count_of_tier(Sprinkler.TIER_3) == 1 and s.count() == 3)
	var blob := s.to_save()
	var s2 := Sprinkler.new()
	s2.load_save(blob)
	_check("⑤a 세이브 왕복 — 좌표·티어 보존",
		s2.count() == 3 and s2.tier_at(Vector2i(9, 9)) == Sprinkler.TIER_3
		and s2.tier_at(Vector2i(2, 2)) == Sprinkler.TIER_1)
	# 구세이브 = [x,y] 2원소(티어 없음) → 티어1로 읽힌다.
	var s3 := Sprinkler.new()
	s3.load_save({"tiles": [[5, 5], [6, 6]]})
	_check("⑤b 구세이브([x,y] 2원소) → 티어1(하위호환 · 급수 4칸)",
		s3.count() == 2 and s3.tier_at(Vector2i(5, 5)) == Sprinkler.TIER_1
		and s3.targets_of(Vector2i(5, 5)).size() == 4)
	var s4 := Sprinkler.new()
	s4.load_save({})
	_check("⑤c 키 없는 구세이브 → 설치 0(기존 하위호환 불변)", s4.count() == 0)
	var s5 := Sprinkler.new()
	s5.load_save({"tiles": [[7, 7, 99], "쓰레기", [8]]})
	_check("⑤d 손상 행은 버리고 손상 티어는 접는다",
		s5.count() == 1 and s5.tier_at(Vector2i(7, 7)) == Sprinkler.TIER_1)

# ══ main 통합 층 ═════════════════════════════════════════════════════════════
func _part_main() -> void:
	print("── ⑥⑦ main 배선(설치·회수·급수·제작) ──")
	var m: Node = await _spawn_main()
	_check("⑥pre 부팅 = 안식 농원", m._region == RegionCatalog.HOME and m.sprinkler != null)

	# ── ⑥ 든 아이템이 티어를 정한다(설치) / 회수는 선 티어 그대로 ──
	var a2 := _find_placeable(m)
	_check("⑥pre 설치 가능한 빈 지면 존재", a2.x >= 0)
	m.inventory.add_item(ItemCatalog.SPRINKLER_T2, 1)
	_select(m, ItemCatalog.SPRINKLER_T2)
	m._target = a2
	m._place_sprinkler(a2, ItemCatalog.SPRINKLER_T2)
	_check("⑥a 티어2 아이템으로 설치 → 원장 티어2",
		m.sprinkler.tier_at(a2) == Sprinkler.TIER_2 and m.inventory.count_of(ItemCatalog.SPRINKLER_T2) == 0)
	_check("⑥b 그 자리의 급수 범위 = 8칸(3×3)",
		m.sprinkler.targets_of(a2).size() == 8)
	m._remove_sprinkler(a2)
	_check("⑥c 회수 = 선 티어 아이템이 돌아온다(티어1이 아니라 티어2)",
		not m.sprinkler.has_at(a2) and m.inventory.count_of(ItemCatalog.SPRINKLER_T2) == 1
		and m.inventory.count_of(ItemCatalog.SPRINKLER) == 0)
	# 안 가진 티어는 설치되지 않는다(아이템 소모 계약).
	m._place_sprinkler(a2, ItemCatalog.SPRINKLER_T3)
	_check("⑥d 안 가진 티어는 설치 무동작", not m.sprinkler.has_at(a2))
	# 스프링클러가 아닌 id로 부르면 무동작(방어).
	m._place_sprinkler(a2, ItemCatalog.HAY)
	_check("⑥e 스프링클러 아닌 id = 무동작", not m.sprinkler.has_at(a2))

	# ── 세이브 왕복(main 경로) — 티어가 세이브를 건넌다 ──
	m.inventory.add_item(ItemCatalog.SPRINKLER_T3, 1)
	m._place_sprinkler(a2, ItemCatalog.SPRINKLER_T3)
	_check("⑤e main 설치 = 티어3", m.sprinkler.tier_at(a2) == Sprinkler.TIER_3)
	m._save_game()
	m.sprinkler.remove(a2)
	m._load_game()
	_check("⑤f main 세이브 왕복 — 티어3 보존", m.sprinkler.tier_at(a2) == Sprinkler.TIER_3)

	# ── ⑦ 급수 실효(5×5 안은 젖고 밖은 안 젖는다) ──
	# 설치물이 이미 선 자리를 피해 넉넉한 밭 칸을 고른다(sprinkler_test가 쓰는 그 좌표대).
	var a3 := Vector2i(58, 45)
	if m.sprinkler.has_at(a3):
		m.sprinkler.remove(a3)
	m.sprinkler.place(a3, Sprinkler.TIER_3)
	var inner := a3 + Vector2i(2, 0)      # 5×5 안(티어1·티어2 범위 밖 — 티어3만 닿는다)
	var outer := a3 + Vector2i(3, 0)      # 5×5 밖
	# 범위 집합 층(순수) — 무대와 무관하게 티어3의 사거리를 못 박는다.
	var targets: Array = m.sprinkler.watered_targets()
	_check("⑦a 급수 대상에 5×5 안 칸이 든다", targets.has(inner))
	_check("⑦b 5×5 밖 칸은 급수 대상이 아니다(범위가 무한이 아니다)", not targets.has(outer))
	# 밭 층(실효) — 실제로 젖는지까지 본다.
	for t in [inner, outer]:
		m.farm.hoe(t)
		m.farm.plant(t, CropCatalog.HONRYEONGCHO)
	_check("⑦pre 두 칸 다 파종됨(단언의 전제)",
		m.farm.is_planted(inner) and m.farm.is_planted(outer))
	for wt in targets:
		m.farm.sprinkle(wt)
	_check("⑦c 5×5 안 칸이 젖는다(티어3 범위 실효)", m.farm.is_watered(inner))
	_check("⑦d 5×5 밖 칸은 안 젖는다", not m.farm.is_watered(outer))

	# ── ⑥f 제작 배선(농사 레벨 주입 → 해금 → 재료 차감·산출) ──
	m._farming_xp = 5500                 # 농사 만렙(문턱 8을 확실히 넘긴다)
	_check("⑥f 2차 축 레벨 주입 = 농사 레벨(하드코딩 분기 제거 확인)",
		m._craft_skill_level(CraftCatalog.SPRINKLER_T2) == m._skill_level(ProfessionCatalog.FARMING)
		and m._craft_skill_level(CraftCatalog.STAIRS) == m._skill_level(ProfessionCatalog.MINING)
		and m._craft_skill_level(CraftCatalog.TAPPER) == 0)
	var rows: Array = m._craft_rows()
	var row_t2: Dictionary = {}
	var row_stairs: Dictionary = {}
	for r in rows:
		if String(r["id"]) == CraftCatalog.SPRINKLER_T2:
			row_t2 = r
		elif String(r["id"]) == CraftCatalog.STAIRS:
			row_stairs = r
	_check("⑥g 제작 탭 잠금 라벨이 레시피 파생(스프링클러=농사 / 계단=채광)",
		String(row_t2.get("skill_gate_label", "")) == "농사"
		and String(row_stairs.get("skill_gate_label", "")) == "채광")
	# 재료를 쥐여 주고 실제 제작(차감·산출).
	m.inventory.add_item(ItemCatalog.SPRINKLER, 1)
	m.inventory.add_item(ItemCatalog.INGOT_YUCHEOL, 1)
	var t2_before: int = m.inventory.count_of(ItemCatalog.SPRINKLER_T2)
	m._on_frame_craft(CraftCatalog.SPRINKLER_T2)
	_check("⑥h 제작 = 하위 티어·주괴 차감 후 티어2 산출",
		m.inventory.count_of(ItemCatalog.SPRINKLER_T2) == t2_before + 1
		and m.inventory.count_of(ItemCatalog.INGOT_YUCHEOL) == 0)
	# 농사 레벨을 0으로 되돌리면 잠긴다(게이트가 진짜로 문다).
	m._farming_xp = 0
	var t3_before: int = m.inventory.count_of(ItemCatalog.SPRINKLER_T3)
	m.inventory.add_item(ItemCatalog.INGOT_HWANGCHEONGEUM, 1)
	m._on_frame_craft(CraftCatalog.SPRINKLER_T3)
	_check("⑥i 농사 Lv0 = 잠김(재료가 있어도 무동작 — 게이트에 이빨)",
		m.inventory.count_of(ItemCatalog.SPRINKLER_T3) == t3_before
		and m.inventory.count_of(ItemCatalog.INGOT_HWANGCHEONGEUM) == 1)

	await _despawn(m)
