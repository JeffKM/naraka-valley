extends SceneTree
# ★[S4-T6 / ADR-0062 결정 4] 수액 채취기 — 원장·설치·주기·수거·퍼크 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ⓐ 데이터 정합 — 주기 5/7/9일이 종 3과 1:1 · 종→수액 매핑 · 수액 3종이 품질 유차원 CAT_HARVEST로
#      정상 편입(판매·출하·의뢰 자동 통용) · 벌목 부산물 SAP와 **별 아이템**(역할 분리).
#   ⓑ 설치 유효성 — 성숙목만 · 그루터기/유목/큰 장애물/빈 칸 거부 · 중복 거부 · 안식·숲 양쪽 가능 ·
#      실내 거부 · 아이템 1개 소모 · **혼력 0**.
#   ⓒ 주기·생산 — 정확히 N일째 고인다 · 완전 결정적(RNG 0) · **미수거 시 생산 정지 + 카운트다운 정지** ·
#      수거가 곧 재가동.
#   ⓓ 퍼크 실효 — 수액꾼(TAP_QUALITY) 등급 +1(금 클램프) + 주기 −1일 · main 주입 배선 2줄.
#   ⓔ 수거·회수 — 등급 실린 채 인벤 지급 · 빈 채취기 회수 · **고인 상태 회수 거절**(증발 방지) ·
#      채취기 박힌 나무 **벌목 차단**(혼력 미소모).
#   ⓕ 세이브 왕복·하위호환 — 구역/좌표/종/남은 날/고인 수액/등급 보존 · tapper 키 없는 구세이브 무해.
#
# 실행: ./run_tests.sh tapper   (헤드리스는 반드시 game/에서 · 순차)

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

# 핫바에서 아이템 id의 슬롯 번호(-1 = 없음).
func _slot_of(m: Node, id: String) -> int:
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == id:
			return i
	return -1

# 안식 원장에서 성숙목 칸 하나(없으면 (-1,-1)).
func _mature_home_tile(m: Node) -> Vector2i:
	for t: Vector2i in m.tree_ledger.tiles(RegionCatalog.HOME):
		if m.tree_ledger.is_mature(RegionCatalog.HOME, t):
			return t
	return Vector2i(-1, -1)

# 채취기 하나만 박은 순수 원장(main 무의존 — 주기·퍼크 검증용).
func _ledger_with(species: String, cut: int = 0) -> TapperLedger:
	var led := TapperLedger.new()
	led.place("forest", Vector2i(0, 0), species, cut)
	return led

# n일을 흘려 고인 날(1-based)을 반환한다(끝까지 안 고이면 -1).
func _days_until_sap(led: TapperLedger, limit: int = 30, base_q: int = 0,
		step: int = 0, cut: int = 0) -> int:
	for d in range(1, limit + 1):
		if not led.advance_day(base_q, step, cut).is_empty():
			return d
	return -1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S4-T6 수액 채취기 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ⓐ 데이터 정합 ──
	print("── ⓐ 데이터 정합 ──")
	_check("ⓐa 주기 = 저승솔 5 / 넋참나무 7 / 명단풍 9(스타듀 1:1)",
		TapperLedger.cycle_for(TreeLedger.SP_PINE) == 5
		and TapperLedger.cycle_for(TreeLedger.SP_OAK) == 7
		and TapperLedger.cycle_for(TreeLedger.SP_MAPLE) == 9)
	_check("ⓐb 종 → 수액 매핑(솔넋진·넋수지·명단풍꿀)",
		TapperLedger.product_for(TreeLedger.SP_PINE) == ItemCatalog.SOLNEOKJIN
		and TapperLedger.product_for(TreeLedger.SP_OAK) == ItemCatalog.NEOKSUJI
		and TapperLedger.product_for(TreeLedger.SP_MAPLE) == ItemCatalog.MYEONGDANPUNG_KKUL)
	_check("ⓐc 모르는 종 = 산출 없음(설치 자체가 거절되는 근거)",
		TapperLedger.product_for("no_such_tree") == "")
	var saps := [ItemCatalog.SOLNEOKJIN, ItemCatalog.NEOKSUJI, ItemCatalog.MYEONGDANPUNG_KKUL]
	var all_ok := true
	for id: String in saps:
		if not (ItemCatalog.has_item(id) and ItemCatalog.category_of(id) == ItemCatalog.CAT_HARVEST
				and ItemCatalog.stackable_of(id) and ItemCatalog.name_of(id) != ""
				and ItemCatalog.price_of(id) > 0):
			all_ok = false
	_check("ⓐd 수액 3종 = 유효·CAT_HARVEST·스택·이름·가격(통용물 결)", all_ok)
	_check("ⓐe 등급 배수 통용(금 = 기준가 ×1.5)",
		ItemCatalog.price_of(ItemCatalog.NEOKSUJI, ItemCatalog.Q_GOLD)
		== int(ItemCatalog.price_of(ItemCatalog.NEOKSUJI) * ItemCatalog.quality_mult(ItemCatalog.Q_GOLD)))
	_check("ⓐf 벌목 부산물 SAP와 별 아이템(역할 분리 — id·가격이 다르다)",
		not saps.has(ItemCatalog.SAP)
		and ItemCatalog.price_of(ItemCatalog.SOLNEOKJIN) != ItemCatalog.price_of(ItemCatalog.SAP))
	_check("ⓐg 의뢰 보상 공식 자동 통용",
		QuestBoard.reward_gold(ItemCatalog.SOLNEOKJIN, 2)
		== ItemCatalog.price_of(ItemCatalog.SOLNEOKJIN, ItemCatalog.Q_NORMAL) * QuestBoard.REWARD_MULT * 2)
	_check("ⓐh 제작 레시피 산출 = 설치 아이템(T5 ↔ T6 접합)",
		String(CraftCatalog.get_recipe(CraftCatalog.TAPPER)["out_item"]) == ItemCatalog.TAPPER)

	# ── ⓒ 주기·생산(순수 원장 — RNG 0) ──
	print("── ⓒ 주기·생산 ──")
	_check("ⓒa 저승솔 = 정확히 5일째 고인다", _days_until_sap(_ledger_with(TreeLedger.SP_PINE)) == 5)
	_check("ⓒb 넋참나무 = 7일째", _days_until_sap(_ledger_with(TreeLedger.SP_OAK)) == 7)
	_check("ⓒc 명단풍 = 9일째", _days_until_sap(_ledger_with(TreeLedger.SP_MAPLE)) == 9)
	var led := _ledger_with(TreeLedger.SP_PINE)
	for _i in 4:
		led.advance_day()
	_check("ⓒd 고이기 전 = 대기 없음·남은 날 1", led.pending_product("forest", Vector2i(0, 0)) == ""
		and led.days_left("forest", Vector2i(0, 0)) == 1)
	var made: Array = led.advance_day()
	_check("ⓒe 생산 반환 = {region,tile,id,quality}", made.size() == 1
		and String(made[0]["id"]) == ItemCatalog.SOLNEOKJIN and made[0]["tile"] == Vector2i(0, 0))
	_check("ⓒf 생산 즉시 다음 주기 리셋(5일)", led.days_left("forest", Vector2i(0, 0)) == 5)
	# 미수거 정지 — 3일을 더 흘려도 새 산출 0이고 카운트다운도 안 준다.
	var idle_ok := true
	for _i in 3:
		if not led.advance_day().is_empty():
			idle_ok = false
	_check("ⓒg 안 비운 채취기 = 생산 정지(게잡이통 1:1)", idle_ok)
	_check("ⓒh 미수거 중엔 카운트다운도 멈춘다(5일 그대로)",
		led.days_left("forest", Vector2i(0, 0)) == 5)
	var got: Dictionary = led.collect("forest", Vector2i(0, 0))
	_check("ⓒi 수거 = {id,quality} 반환·대기 비움",
		String(got.get("id", "")) == ItemCatalog.SOLNEOKJIN
		and led.pending_product("forest", Vector2i(0, 0)) == "")
	_check("ⓒj 수거가 곧 재가동 = 다시 5일 뒤 고인다", _days_until_sap(led) == 5)
	# 결정성 — 같은 입력이면 같은 결과(뽑기가 없으므로 시드조차 불요).
	var a := _ledger_with(TreeLedger.SP_OAK)
	var b := _ledger_with(TreeLedger.SP_OAK)
	_check("ⓒk 완전 결정적(RNG 0 — 같은 입력 = 같은 날·같은 산출)",
		_days_until_sap(a) == _days_until_sap(b)
		and a.pending_product("forest", Vector2i(0, 0)) == b.pending_product("forest", Vector2i(0, 0)))
	_check("ⓒl 두 구역 좌표 충돌 없음(구역 키 축)",
		led.place("home", Vector2i(0, 0), TreeLedger.SP_MAPLE) and led.count() == 2)

	# ── ⓓ 퍼크(수액꾼) — 원장 주입 ──
	print("── ⓓ 퍼크 ──")
	_check("ⓓa 등급 계단 +1(일반 → 은)",
		TapperLedger.quality_for(ItemCatalog.Q_NORMAL, ForageSkill.TAP_QUALITY_STEP) == ItemCatalog.Q_SILVER)
	_check("ⓓb 등급 상한 = 금(이리듐은 줍기 약초학자 전용)",
		TapperLedger.quality_for(ItemCatalog.Q_GOLD, ForageSkill.TAP_QUALITY_STEP) == ItemCatalog.Q_GOLD)
	_check("ⓓc 주기 단축 −1일(저승솔 5 → 4)",
		TapperLedger.cycle_for(TreeLedger.SP_PINE, ForageSkill.TAP_CYCLE_CUT) == 4)
	_check("ⓓd 단축이 주기를 0 이하로 못 끈다(바닥 1)",
		TapperLedger.cycle_for(TreeLedger.SP_PINE, 99) == TapperLedger.MIN_CYCLE)
	var perked := _ledger_with(TreeLedger.SP_PINE, ForageSkill.TAP_CYCLE_CUT)
	_check("ⓓe 퍼크 원장 = 4일째 고이고 등급 은",
		_days_until_sap(perked, 30, ItemCatalog.Q_NORMAL, ForageSkill.TAP_QUALITY_STEP,
			ForageSkill.TAP_CYCLE_CUT) == 4
		and perked.pending_quality("forest", Vector2i(0, 0)) == ItemCatalog.Q_SILVER)
	_check("ⓓf 퍼크 없으면 중립(등급 그대로·주기 그대로)",
		ForageSkill.tap_quality(0.0) == 0 and ForageSkill.tap_cycle_cut(0.0) == 0)

	# ── main 배선 ──
	var m: Node = await _new_main()
	print("── ⓑ 설치 유효성(main) ──")
	m._professions = {}
	m._foraging_xp = 0
	_check("ⓑ0 원장 노드 생성·빈 원장", m.tapper != null and m.tapper.count() == 0)
	var tree_t := _mature_home_tile(m)
	_check("ⓑ1 안식 성숙목 확보(원장 시드)", tree_t != Vector2i(-1, -1))
	_check("ⓑ2 성숙목 = 설치 가능", m._can_place_tapper(tree_t))
	_check("ⓑ3 빈 지면 = 거부", not m._can_place_tapper(Vector2i(1, 1)))
	# 설치 — 아이템 1개 소모·혼력 0.
	m.inventory.add_item(ItemCatalog.TAPPER, 2)
	var soul_before: int = m.energy.current
	m._place_tapper(tree_t)
	_check("ⓑ4 설치 성공(원장 1개)", m.tapper.has_at(RegionCatalog.HOME, tree_t)
		and m.tapper.count() == 1)
	_check("ⓑ5 아이템 1개 소모(2 → 1)", m.inventory.count_of(ItemCatalog.TAPPER) == 1)
	_check("ⓑ6 혼력 0(패시브는 무과금)", m.energy.current == soul_before)
	_check("ⓑ7 종 스냅샷 = 그 나무의 종",
		m.tapper.species_at(RegionCatalog.HOME, tree_t)
		== m.tree_ledger.species_at(RegionCatalog.HOME, tree_t))
	_check("ⓑ8 중복 설치 거부", not m._can_place_tapper(tree_t))
	m._place_tapper(tree_t)
	_check("ⓑ9 중복 설치가 아이템을 안 먹는다", m.inventory.count_of(ItemCatalog.TAPPER) == 1)
	_check("ⓑ10 프롬프트 = [F] 회수 안내(고인 것 없음)",
		m._tapper_prompt(tree_t).contains("회수") and m._tapper_prompt(tree_t).contains("일 남음"))
	# 실내 거부.
	var keep_indoor: String = m._indoor
	m._indoor = "HOUSE"
	_check("ⓑ11 실내에선 설치 불가", not m._can_place_tapper(tree_t))
	m._indoor = keep_indoor

	# ── ⓔ 벌목 차단·수거·회수 ──
	print("── ⓔ 벌목 차단·수거·회수 ──")
	var axe_slot := _slot_of(m, ItemCatalog.AXE)
	if axe_slot >= 0:
		m.inventory.select(axe_slot)
	m.energy.current = SoulEnergy.MAX
	var hp_before: int = m.tree_ledger.hp_at(RegionCatalog.HOME, tree_t)
	m._chop_tree(tree_t)
	_check("ⓔa 채취기 박힌 나무 = 벌목 차단(타수 불변)",
		m.tree_ledger.hp_at(RegionCatalog.HOME, tree_t) == hp_before
		and m.tree_ledger.is_mature(RegionCatalog.HOME, tree_t))
	_check("ⓔb 차단 타는 혼력 미소모(무효타는 값을 안 매긴다)", m.energy.current == SoulEnergy.MAX)
	# 하루를 통째로 흘려 수액을 고이게 한다(주기만큼).
	var cycle: int = TapperLedger.cycle_for(m.tapper.species_at(RegionCatalog.HOME, tree_t))
	for _i in cycle:
		m.tapper.advance_day(m._forage_base_quality(m._skill_level(ProfessionCatalog.FORAGING)),
			m.forage_tap_quality(), m.forage_tap_cycle_cut())
	var pending: String = m.tapper.pending_product(RegionCatalog.HOME, tree_t)
	_check("ⓔc 주기 경과 = 그 종의 수액이 고임",
		pending == TapperLedger.product_for(m.tapper.species_at(RegionCatalog.HOME, tree_t)))
	_check("ⓔd 고인 상태 = 회수 거절(산출물 증발 방지)",
		not m.tapper.remove(RegionCatalog.HOME, tree_t))
	_check("ⓔe 고인 상태 프롬프트 = 수거 안내", m._tapper_prompt(tree_t).contains("수거"))
	var had: int = m.inventory.count_of(pending)
	var soul_collect: int = m.energy.current
	m._use_tapper(tree_t)
	_check("ⓔf [F] 수거 = 인벤 +1", m.inventory.count_of(pending) == had + 1)
	_check("ⓔg 수거도 혼력 0", m.energy.current == soul_collect)
	_check("ⓔh 수거 후 재가동(남은 날 = 주기 전량)",
		m.tapper.pending_product(RegionCatalog.HOME, tree_t) == ""
		and m.tapper.days_left(RegionCatalog.HOME, tree_t) == cycle)
	var pot_before: int = m.inventory.count_of(ItemCatalog.TAPPER)
	m._use_tapper(tree_t)
	_check("ⓔi 빈 채취기 [F] = 회수(아이템 복귀·원장 0)",
		m.inventory.count_of(ItemCatalog.TAPPER) == pot_before + 1
		and not m.tapper.has_at(RegionCatalog.HOME, tree_t))
	m.energy.current = SoulEnergy.MAX
	m._chop_tree(tree_t)
	_check("ⓔj 회수 뒤엔 다시 벌목 가능(차단 해제)",
		m.tree_ledger.hp_at(RegionCatalog.HOME, tree_t) == hp_before - 1)

	# ── ⓓ(계속) main 퍼크 주입 배선 ──
	print("── ⓓ 퍼크 배선(main) ──")
	m._professions = {}
	_check("ⓓg 퍼크 미보유 = 등급 계단 0·주기 단축 0",
		m.forage_tap_quality() == 0 and m.forage_tap_cycle_cut() == 0)
	m._foraging_xp = 5500   # L10
	m._professions = {ProfessionCatalog.FORAGING: {5: "detector", 10: "tapper"}}
	_check("ⓓh 수액꾼 보유 = 등급 +1 · 주기 −1(같은 퍼크의 두 절반)",
		m.forage_tap_quality() == ForageSkill.TAP_QUALITY_STEP
		and m.forage_tap_cycle_cut() == ForageSkill.TAP_CYCLE_CUT)
	# 라이브 루프 — L10 + 수액꾼이면 고인 수액이 금등급이어야 한다(base 금 + 계단 → 금 클램프).
	var t2 := _mature_home_tile(m)
	m.inventory.add_item(ItemCatalog.TAPPER, 1)
	m._place_tapper(t2)
	var cycle2: int = TapperLedger.cycle_for(m.tapper.species_at(RegionCatalog.HOME, t2),
		m.forage_tap_cycle_cut())
	_check("ⓓi 퍼크 설치 = 단축된 주기로 박힌다", m.tapper.days_left(RegionCatalog.HOME, t2) == cycle2)
	for _i in cycle2:
		m.tapper.advance_day(m._forage_base_quality(m._skill_level(ProfessionCatalog.FORAGING)),
			m.forage_tap_quality(), m.forage_tap_cycle_cut())
	_check("ⓓj L10+수액꾼 산출 = 금등급(상한 클램프)",
		m.tapper.pending_quality(RegionCatalog.HOME, t2) == ItemCatalog.Q_GOLD)

	# ── ⓕ 세이브 왕복·하위호환 ──
	print("── ⓕ 세이브 ──")
	var saved_species: String = m.tapper.species_at(RegionCatalog.HOME, t2)
	var saved_days: int = m.tapper.days_left(RegionCatalog.HOME, t2)
	var saved_prod: String = m.tapper.pending_product(RegionCatalog.HOME, t2)
	var saved_count: int = m.tapper.count()
	m._save_game()
	var slot: int = m._active_slot
	await _despawn(m)
	var m2: Node = await _new_main()
	_check("ⓕa 설치 수 복원", m2.tapper.count() == saved_count)
	_check("ⓕb 구역·좌표·종 복원", m2.tapper.has_at(RegionCatalog.HOME, t2)
		and m2.tapper.species_at(RegionCatalog.HOME, t2) == saved_species)
	_check("ⓕc 남은 날 복원", m2.tapper.days_left(RegionCatalog.HOME, t2) == saved_days)
	_check("ⓕd 고인 수액·등급 복원",
		m2.tapper.pending_product(RegionCatalog.HOME, t2) == saved_prod
		and m2.tapper.pending_quality(RegionCatalog.HOME, t2) == ItemCatalog.Q_GOLD)
	_check("ⓕe 다른 구역엔 안 샌다",
		m2.tapper.tiles(RegionCatalog.JEOSEUNG_FOREST).is_empty())
	await _despawn(m2)
	# 구세이브 — tapper 키를 지운 세이브로 부팅한다(하위호환).
	var sm := SaveManager.new()
	var raw := sm.load_game(slot)
	raw.erase("tapper")
	sm.save_game(raw, slot, {"day": 1, "soul": 0})
	sm.free()
	var m3: Node = await _new_main()
	_check("ⓕf 구세이브 = 채취기 0(빈 원장·크래시 0)", m3.tapper.count() == 0)
	_check("ⓕg 손상 종은 통째 버린다(산출 미정 채취기 방지)",
		_load_broken_species().count() == 0)
	await _despawn(m3)

	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)

# 모르는 종이 박힌 세이브 데이터를 로드해 본다(손상 방어 — 원장 단독).
func _load_broken_species() -> TapperLedger:
	var led := TapperLedger.new()
	led.load_save({"taps": {"forest": [[3, 4, "no_such_tree", 2, "", 0]]}})
	return led
