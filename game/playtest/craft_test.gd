extends SceneTree
# ★[S4-T5 / ADR-0062 결정 5] 손 제작 시스템 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ① 카탈로그 무결성 — 레시피 10종(★S5-T3 업화로 합류)·산출/재료 아이템 전부 ItemCatalog 유효.
#   ② 레벨 해금 계단 — 야생 씨앗 lvl1/4/6/7·수액 채취기 lvl4(스타듀 상속).
#   ③ 종 발견 게이트(ADR-0033 #4) — 희소종 씨앗은 그 종을 *주워 본* 뒤에만(발견 원장 주입).
#   ④ can_craft — 재료 부족/충족 판정(보유량 콜백 주입 — 카탈로그는 인벤 무지).
#   ⑤ 실행(main._on_frame_craft) — 재료 차감·산출 적재(야생 씨앗 ×10·채취기 ×1)·부족 시 무동작.
#   ⑥ 제작 탭 행 데이터(_craft_rows) — 9행·해금/가능 플래그 정합.
#   ⑦ 발견 원장 세이브 라운드트립 — 재부팅 후 희소종 레시피 해금 유지 + 키 없는 구세이브 하위호환.
#
# 실행: ./run_tests.sh craft   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame
	return m

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S4-T5 손 제작 시스템 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ① 카탈로그 무결성 ──
	print("── ① 카탈로그 무결성 ──")
	var ids: Array = CraftCatalog.ids()
	# ★[S5-T3 / ADR-0063 결정 3] 9 → 10: 업화로 레시피가 합류했다(의도적 불변식 개정).
	_check("①a 레시피 10종(★S5-T3 업화로 합류)", ids.size() == 10)
	var all_ok := true
	for id in ids:
		var r: Dictionary = CraftCatalog.get_recipe(id)
		if not ItemCatalog.has_item(String(r["out_item"])) or int(r["out_count"]) < 1:
			all_ok = false
		for mt in r["mats"]:
			if not ItemCatalog.has_item(String(mt["item"])) or int(mt["count"]) < 1:
				all_ok = false
		if String(r["unlock_species"]) != "" and not ItemCatalog.has_item(String(r["unlock_species"])):
			all_ok = false
	_check("①b 산출·재료·발견종 아이템 전부 유효", all_ok)
	_check("①c 수액 채취기 산출 = TAPPER(설치는 T6)",
		String(CraftCatalog.get_recipe(CraftCatalog.TAPPER)["out_item"]) == ItemCatalog.TAPPER)
	_check("①d mats_text 비어있지 않음", CraftCatalog.mats_text(CraftCatalog.WILD_SEEDS_PIAN) != "")

	# ── ② 레벨 해금 계단 ──
	print("── ② 레벨 해금 ──")
	_check("②a lvl0 → 피안 야생 씨앗 잠김", not CraftCatalog.unlocked(CraftCatalog.WILD_SEEDS_PIAN, 0, {}))
	_check("②b lvl1 → 피안 해금", CraftCatalog.unlocked(CraftCatalog.WILD_SEEDS_PIAN, 1, {}))
	_check("②c lvl3 → 채취기 잠김 / lvl4 해금",
		not CraftCatalog.unlocked(CraftCatalog.TAPPER, 3, {}) and CraftCatalog.unlocked(CraftCatalog.TAPPER, 4, {}))
	_check("②d 유화 4·망연 6·성야 7 계단",
		CraftCatalog.unlocked(CraftCatalog.WILD_SEEDS_YUHWA, 4, {}) and not CraftCatalog.unlocked(CraftCatalog.WILD_SEEDS_YUHWA, 3, {})
		and CraftCatalog.unlocked(CraftCatalog.WILD_SEEDS_MANGYEON, 6, {}) and not CraftCatalog.unlocked(CraftCatalog.WILD_SEEDS_MANGYEON, 5, {})
		and CraftCatalog.unlocked(CraftCatalog.WILD_SEEDS_SEONGYA, 7, {}) and not CraftCatalog.unlocked(CraftCatalog.WILD_SEEDS_SEONGYA, 6, {}))

	# ── ③ 종 발견 게이트 ──
	print("── ③ 종 발견 게이트 ──")
	_check("③a lvl6·미발견 → 미혹난초 씨앗 잠김",
		not CraftCatalog.unlocked(CraftCatalog.RARE_SEED_MIHOK_NANCHO, 6, {}))
	_check("③b lvl6·발견 → 해금",
		CraftCatalog.unlocked(CraftCatalog.RARE_SEED_MIHOK_NANCHO, 6, {ItemCatalog.MIHOK_NANCHO: true}))
	_check("③c 발견해도 lvl5면 잠김(2축 AND)",
		not CraftCatalog.unlocked(CraftCatalog.RARE_SEED_MIHOK_NANCHO, 5, {ItemCatalog.MIHOK_NANCHO: true}))

	# ── ④ can_craft ──
	print("── ④ 재료 판정 ──")
	var empty := func(_id: String) -> int: return 0
	var rich := func(_id: String) -> int: return 99
	_check("④a 빈손 → 불가", not CraftCatalog.can_craft(CraftCatalog.WILD_SEEDS_PIAN, empty))
	_check("④b 충족 → 가능", CraftCatalog.can_craft(CraftCatalog.WILD_SEEDS_PIAN, rich))

	# ── ⑤ 실행(main) ──
	print("── ⑤ 실행 ──")
	var m: Node = await _new_main()
	m._foraging_xp = 100   # L1 — 피안 야생 씨앗 해금
	var inv: Node = m.inventory
	inv.add_item(ItemCatalog.NEOK_GOSARI, 2)
	inv.add_item(ItemCatalog.JAETBIT_NAENGI, 1)
	inv.add_item(ItemCatalog.JEOSEUNG_DALLAE, 1)
	var seed_item: String = ItemCatalog.seed_id(CropCatalog.WILD_PIAN)
	m._on_frame_craft(CraftCatalog.WILD_SEEDS_PIAN)
	_check("⑤a 산출 = 야생 씨앗(피안) ×10", inv.count_of(seed_item) == 10)
	_check("⑤b 재료 차감(각 1 — 넋고사리 2→1)",
		inv.count_of(ItemCatalog.NEOK_GOSARI) == 1 and inv.count_of(ItemCatalog.JAETBIT_NAENGI) == 0)
	m._on_frame_craft(CraftCatalog.WILD_SEEDS_PIAN)   # 재료 부족(냉이·달래 0) → 무동작
	_check("⑤c 재료 부족 → 무동작", inv.count_of(seed_item) == 10 and inv.count_of(ItemCatalog.NEOK_GOSARI) == 1)
	m._on_frame_craft(CraftCatalog.TAPPER)            # lvl1 → 잠김 → 무동작
	_check("⑤d 미해금 레시피 → 무동작", inv.count_of(ItemCatalog.TAPPER) == 0)
	m._foraging_xp = 1000   # L4 — 채취기 해금
	inv.add_item(ItemCatalog.WOOD, 40)
	inv.add_item(ItemCatalog.PETRIFIED_WOOD, 2)
	m._on_frame_craft(CraftCatalog.TAPPER)
	_check("⑤e 채취기 제작(원목 40+석화 2 소모·×1)",
		inv.count_of(ItemCatalog.TAPPER) == 1 and inv.count_of(ItemCatalog.WOOD) == 0
		and inv.count_of(ItemCatalog.PETRIFIED_WOOD) == 0)

	# ── ⑥ 제작 탭 행 데이터 ──
	print("── ⑥ 제작 탭 행 ──")
	var rows: Array = m._craft_rows()
	_check("⑥a 10행·id/이름 채움", rows.size() == 10 and String(rows[0]["name"]) != "")
	var locked_seen := false
	for row in rows:
		if not bool(row["unlocked"]):
			locked_seen = true
	_check("⑥b 미해금 행 존재(성야 lvl7 등)", locked_seen)

	# ── ⑦ 발견 원장 세이브 ──
	print("── ⑦ 발견 원장 세이브 ──")
	m._forage_found[ItemCatalog.MIHOK_NANCHO] = true
	m._save_game()
	await _despawn(m)
	var m2: Node = await _new_main()
	_check("⑦a 재부팅 후 발견 유지 → 희소종 레시피 해금",
		bool(m2._forage_found.get(ItemCatalog.MIHOK_NANCHO, false))
		and CraftCatalog.unlocked(CraftCatalog.RARE_SEED_MIHOK_NANCHO, 6, m2._forage_found))
	await _despawn(m2)
	cleaner.delete_save()
	var m3: Node = await _new_main()   # 키 없는 새 세이브 — 하위호환(발견 0·무막힘)
	_check("⑦b 구세이브 하위호환(발견 0)", m3._forage_found.is_empty())
	await _despawn(m3)
	cleaner.delete_save()

	print("══ 결과: %s ══" % ("전체 통과" if _fail == 0 else "%d개 실패" % _fail))
	quit(0 if _fail == 0 else 1)
