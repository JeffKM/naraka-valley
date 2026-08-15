extends SceneTree
# ★[S4-T5 / ADR-0062 결정 5] 손 제작 시스템 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ① 카탈로그 무결성 — 레시피 목록 = 카탈로그 전량(★S5-T3 업화로 · ★S5-T8 계단 · ★S10-T1 결정기
#      합류)·산출/재료 아이템 전부 ItemCatalog 유효.
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
	# ★[S5-T8 / ADR-0063 결정 10] 10 → 11: 계단 레시피가 합류했다(같은 결의 의도적 개정).
	# ★[S10-T1 / ADR-0069 결정 2] 11 → 12: 결정기 레시피가 합류했다(같은 결의 의도적 개정).
	# ★[S10-T2 / ADR-0069 결정 3] +2: 스프링클러 상위 2티어 합류(결합 시 T1 파생 단언 채택 — 분모 하드코딩 금지).
	# ★ 분모를 손으로 안 적는다 — 카탈로그 dict 크기와 목록 크기가 서로를 검증한다(stale 단언 방지).
	_check("①a 레시피 목록 = 카탈로그 전량(★S10-T1 결정기·★S10-T2 스프링클러 2티어 합류)",
		ids.size() == CraftCatalog.catalog().size() and ids.has(CraftCatalog.CRYSTALARIUM)
		and ids.has(CraftCatalog.SPRINKLER_T2) and ids.has(CraftCatalog.SPRINKLER_T3))
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
	# ★[S10 폴리시] 만재 제작 원자성 — **담기 먼저, 비우기 나중**(업화로 회수 `_use_furnace`와 같은
	# 계약). 종전엔 재료를 먼저 뺐다가 산출 적재 실패를 버려, 재료 슬롯이 안 비는 조합(원목 50 중
	# 40 소모)에서 **재료만 증발하고 산출은 0**이었다(그런데 획득 토스트는 떴다).
	inv.remove_item(ItemCatalog.TAPPER, inv.count_of(ItemCatalog.TAPPER))   # 스택 합류 여지 제거
	inv.add_item(ItemCatalog.WOOD, 50)
	inv.add_item(ItemCatalog.PETRIFIED_WOOD, 3)
	for i in range(inv.slots.size()):
		if inv.slots[i] == null:
			inv.slots[i] = {"id": ItemCatalog.STONE, "count": 1, "quality": 0}
	_check("⑤f pre 백팩 포화(빈 칸 0 · 채취기 스택 0 — 적재는 반드시 실패한다)",
		not inv.has_free_slot() and inv.count_of(ItemCatalog.TAPPER) == 0)
	m._on_frame_craft(CraftCatalog.TAPPER)
	_check("⑤g ★만재 제작 = 재료가 한 톨도 안 빠진다(원목 50·석화 3 그대로 · 채취기 0)",
		inv.count_of(ItemCatalog.WOOD) == 50 and inv.count_of(ItemCatalog.PETRIFIED_WOOD) == 3
		and inv.count_of(ItemCatalog.TAPPER) == 0)
	# 대조군 — 막힌 게 아니라 자리가 없던 것이다. 돌 한 칸을 비우면 같은 제작이 성립하고
	# 재료는 레시피 표대로만 빠진다(원목 40·석화 2).
	for i in range(inv.slots.size()):
		if inv.slots[i] != null and String(inv.slots[i]["id"]) == ItemCatalog.STONE:
			inv.slots[i] = null
			break
	m._on_frame_craft(CraftCatalog.TAPPER)
	_check("⑤h 한 칸 비면 제작 성립 · 재료는 레시피대로만 차감(원목 50→10 · 석화 3→1)",
		inv.count_of(ItemCatalog.TAPPER) == 1 and inv.count_of(ItemCatalog.WOOD) == 10
		and inv.count_of(ItemCatalog.PETRIFIED_WOOD) == 1)

	# ── ⑥ 제작 탭 행 데이터 ──
	print("── ⑥ 제작 탭 행 ──")
	var rows: Array = m._craft_rows()
	# ★[S10-T1·T2 합치] 분모는 카탈로그 파생(레시피가 늘 때마다 여기를 고치지 않게 — stale 단언 방지).
	_check("⑥a 카탈로그 전량 행·id/이름 채움",
		rows.size() == CraftCatalog.ids().size() and String(rows[0]["name"]) != "")
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
