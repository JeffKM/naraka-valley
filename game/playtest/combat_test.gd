extends SceneTree
# ★[S5-T4 / ADR-0063 결정 4·5·9] HP 자원 + 무기 5종 + 피해 판정 + 기절 + 전투 전문직 검증(ephemeral).
#
# 무엇을 지키나(어기면 ADR-0063 결정 4·5 / ADR-0011 / ADR-0031 결정 7 위반):
#   ① HP 성장 곡선 — base 100 + 5/lv, **Lv5/10 제외**(그 몫은 전문직) · 전문직 합산 +40
#   ② 무기 5종 스탯 — 데미지 밴드·해금 깊이·가격·유니크(스택 0) · 도구 티어와 완전 분리
#   ③ 데미지 롤 결정성(같은 시드 = 같은 결과) · 밴드 안 · 크리 배율 · 퍼크 변조(척후·결사·투사·광전사)
#   ④ 전투 행동비용 0(공격에 혼력·HP 무과금) · 무기 미장착이면 기존 도구 거동 불변
#   ⑤ 스윙 부채꼴(방향 의미·벽 뒤 배제) · 몹 훅(빈 배열 폴백)
#   ⑥ 피격 무적 창(0.8s) · 넉백 · 층 하강 무적(1s)
#   ⑦ 기절 — 무대 퇴장 + 게임 시간 +2h · **골드·아이템·진행 손실 0** · HP 회복
#   ⑧ 세이브 왕복(hp·combat_xp) · 하위호환(키 없는 구세이브 = 풀HP/0XP) · 기존 키 개명 0
#   ⑨ 숙련 탭 5행 완성(5스킬 전면 가동) · 곡예사 = 예약 퍼크(선택 가능·효과 보류)
# 실행: godot --headless --path game --script res://playtest/combat_test.gd

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

# 전환(층 퇴장) tween이 끝날 때까지 _transitioning 폴링(mine_floor_test._settle 동형 — 좀비 방지 상한).
func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

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

# 인벤에 아이템 1개를 넣고(없을 때만) 그 슬롯을 든다 — 장착 전환 = 핫바에서 드는 것(ADR-0024).
func _equip(m: Node, id: String) -> bool:
	if m.inventory.count_of(id) <= 0 and not m.inventory.add_item(id, 1):
		return false
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return m.inventory.selected_id() == id
	return false

func _initialize() -> void:
	print("══ S5-T4 HP · 무기 5종 · 피해 판정 · 기절 · 전투 전문직 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s5t4_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① HP 성장 곡선(순수 규칙) ──
	print("── ① HP 성장 곡선(Lv5/10 제외 + 전문직 몫) ──")
	_check("①a base 최대 HP = 100 · Lv0 성장분 0",
		PlayerHealth.BASE_MAX == 100 and CombatSkill.hp_bonus(0) == 0
		and PlayerHealth.max_for(0) == 100)
	# Lv1~4 = +5씩 · Lv5 = **제외**(4와 같음) · Lv6~9 = 다시 +5씩 · Lv10 = 제외(9와 같음).
	var curve_ok := CombatSkill.hp_bonus(1) == 5 and CombatSkill.hp_bonus(4) == 20 \
		and CombatSkill.hp_bonus(5) == 20 and CombatSkill.hp_bonus(6) == 25 \
		and CombatSkill.hp_bonus(9) == 40 and CombatSkill.hp_bonus(10) == 40
	_check("①b Lv5·Lv10 계단은 +5가 **빠진다**(4→5·9→10에서 정체 — 그 몫은 전문직)", curve_ok)
	_check("①c Lv10 순수 성장 = 8계단 × 5 = +40 (최대 140)",
		PlayerHealth.max_for(10) == 140 and CombatSkill.HP_PER_LEVEL == 5
		and CombatSkill.HP_SKIP_LEVELS.size() == 2)
	_check("①d 전문직 합산(투사 15 + 수호자 25 = 40)이 그 두 계단을 메운다 → 최대 180",
		PlayerHealth.max_for(10, 40) == 180 and PlayerHealth.max_for(0, 40) == 140)
	_check("①e 레벨 상한 밖은 클램프(음수·11 이상)",
		CombatSkill.hp_bonus(-3) == 0 and CombatSkill.hp_bonus(99) == CombatSkill.hp_bonus(10))
	_check("①f XP 곡선 = FarmSkill 위임(수치 복제 0 — 5스킬 공통 기반)",
		CombatSkill.xp_thresholds() == FarmSkill.XP_THRESHOLDS
		and CombatSkill.level_for_xp(FarmSkill.XP_THRESHOLDS[4]) == 5
		and CombatSkill.MAX_LEVEL == FarmSkill.MAX_LEVEL)

	# ── ② HP 자원(PlayerHealth 단독) ──
	print("── ② HP 자원 — 소모·회복·최대 갱신·기절 시그널 ──")
	var hp := PlayerHealth.new()
	_check("②a 초기 = 풀 HP(100/100) · 기절 아님",
		hp.current == 100 and hp.maximum == 100 and not hp.is_down())
	_check("②b 피해 = 깎인 양 반환 · 0/음수는 무동작",
		hp.damage(30) == 30 and hp.current == 70 and hp.damage(0) == 0 and hp.damage(-5) == 0)
	_check("②c 회복은 최대에서 멈춘다(초과분 버림)", hp.heal(500) == 30 and hp.current == 100)
	var downed := [false]
	hp.depleted.connect(func() -> void: downed[0] = true)
	_check("②d 남은 HP보다 큰 피해 = 남은 만큼만 깎이고 0에서 멈춘다(음수 없음)",
		hp.damage(999) == 100 and hp.current == 0 and hp.is_down())
	_check("②e HP 0 = depleted 발화(기절 훅)", downed[0])
	_check("②f 0에서 더 때려도 재발화 없음(무동작)", hp.damage(50) == 0)
	hp.refill()
	_check("②g 취침 풀회복", hp.current == 100 and not hp.is_down())
	# 최대치 갱신 — 늘면 현재도 그만큼 채운다(레벨업 즉시 체감), 줄면 상한으로 자른다.
	hp.damage(40)                                  # 60/100
	hp.refresh_max(6, 0)                           # Lv6 → 최대 125(+25)
	_check("②h 최대가 늘면 현재도 그만큼 오른다(60 → 85 / 최대 125)",
		hp.maximum == 125 and hp.current == 85)
	hp.refresh_max(0, 0)                           # 최대 100으로 되돌림
	_check("②i 최대가 줄면 현재는 상한으로 잘린다", hp.maximum == 100 and hp.current == 85)
	_check("②j 비율 조회(HUD 바 채움)", absf(hp.ratio() - 0.85) < 0.001)

	# ── ③ 무기 5종 스탯 ──
	print("── ③ 무기 5종(검 단일 계열) ──")
	var swords := [WeaponCatalog.SWORD_RUSTY, WeaponCatalog.SWORD_MYEONGDONG,
		WeaponCatalog.SWORD_YUCHEOL, WeaponCatalog.SWORD_HWANGCHEONGEUM, WeaponCatalog.SWORD_EOPHWADO]
	var all_valid := true
	for id: String in swords:
		if not ItemCatalog.has_item(id) or ItemCatalog.category_of(id) != ItemCatalog.CAT_TOOL \
				or ItemCatalog.stackable_of(id) or ItemCatalog.name_of(id) == "":
			all_valid = false
	_check("③a 검 5종 = 유효 CAT_TOOL **유니크**(스택 0) 아이템 · 이름 있음",
		all_valid and WeaponCatalog.SWORDS.size() == 5 and WeaponCatalog.ids().size() == 5)
	_check("③b 데미지 밴드 = 2-5 / 8-15 / 12-25 / 28-46 / 55-64(스타듀 검 대응 1:1)",
		WeaponCatalog.damage_band(WeaponCatalog.SWORD_RUSTY) == "2-5"
		and WeaponCatalog.damage_band(WeaponCatalog.SWORD_MYEONGDONG) == "8-15"
		and WeaponCatalog.damage_band(WeaponCatalog.SWORD_YUCHEOL) == "12-25"
		and WeaponCatalog.damage_band(WeaponCatalog.SWORD_HWANGCHEONGEUM) == "28-46"
		and WeaponCatalog.damage_band(WeaponCatalog.SWORD_EOPHWADO) == "55-64")
	_check("③c 해금 깊이 = 0 / 10 / 25 / 40 / 60",
		WeaponCatalog.depth_of(WeaponCatalog.SWORD_RUSTY) == 0
		and WeaponCatalog.depth_of(WeaponCatalog.SWORD_MYEONGDONG) == 10
		and WeaponCatalog.depth_of(WeaponCatalog.SWORD_YUCHEOL) == 25
		and WeaponCatalog.depth_of(WeaponCatalog.SWORD_HWANGCHEONGEUM) == 40
		and WeaponCatalog.depth_of(WeaponCatalog.SWORD_EOPHWADO) == MineFloors.MAX_FLOOR)
	_check("③d 가격 = 증정 0 / 750 / 2,000 / 9,000 / 25,000(ItemCatalog 위임 일치)",
		ItemCatalog.price_of(WeaponCatalog.SWORD_RUSTY) == 0
		and ItemCatalog.price_of(WeaponCatalog.SWORD_MYEONGDONG) == 750
		and ItemCatalog.price_of(WeaponCatalog.SWORD_YUCHEOL) == 2000
		and ItemCatalog.price_of(WeaponCatalog.SWORD_HWANGCHEONGEUM) == 9000
		and ItemCatalog.price_of(WeaponCatalog.SWORD_EOPHWADO) == 25000)
	# 깊이 게이팅 — 도달 깊이가 유일한 해금 축(관계·스킬 게이트 0).
	_check("③e 깊이 게이팅 — 0층에선 증정품만, 25층이면 셋, 60층이면 전부",
		WeaponCatalog.unlocked_ids(0).size() == 1
		and WeaponCatalog.unlocked_ids(25).size() == 3
		and WeaponCatalog.unlocked_ids(60).size() == 5
		and not WeaponCatalog.unlocked(WeaponCatalog.SWORD_EOPHWADO, 59))
	# ★무기 티어 ↔ 도구 티어 완전 분리(ADR-0031 결정 7): 무기 id는 ToolTier 축에 없다.
	var tt_clean := true
	for id: String in swords:
		if ToolTier.is_upgradable(id) or id in ToolTier.TOOLS:
			tt_clean = false
	_check("③f 무기 티어 ↔ 도구 티어 **완전 분리**(무기 id는 ToolTier 축에 없다)", tt_clean)
	# id 교집합 0 — 무기가 광물·자재·기어·작물 표로 조용히 새지 않는다.
	var no_overlap := true
	for id: String in swords:
		if ItemCatalog.TOOLS.has(id) or GearCatalog.has(id) or ItemCatalog.MINERALS.has(id) \
				or ItemCatalog.MATERIALS.has(id) or CropCatalog.has_crop(id):
			no_overlap = false
	_check("③g 무기 id ↔ 도구·낚시기어·광물·자재·작물 교집합 0", no_overlap)
	_check("③h 미상 id는 전부 0/빈값 폴백(유령 무기 없음)",
		not WeaponCatalog.has("sword_ghost") and WeaponCatalog.damage_max("sword_ghost") == 0
		and WeaponCatalog.name_of("sword_ghost") == "" and WeaponCatalog.depth_of("") == 0)

	# ── ④ 피해 판정(순수·결정적) ──
	print("── ④ 피해 판정 — 결정성 · 밴드 · 크리 · 퍼크 ──")
	var h1 := CombatSkill.resolve_hit(WeaponCatalog.SWORD_YUCHEOL, 42)
	var h2 := CombatSkill.resolve_hit(WeaponCatalog.SWORD_YUCHEOL, 42)
	_check("④a 같은 시드 = 같은 결과(결정성 — 헤드리스 재현)",
		int(h1["damage"]) == int(h2["damage"]) and bool(h1["crit"]) == bool(h2["crit"])
		and int(h1["base"]) == int(h2["base"]))
	# 시드를 200번 굴려 밴드 안에 있는지 + 값이 실제로 갈리는지(고정값 아님).
	var in_band := true
	var seen := {}
	var crits := 0
	for i in 200:
		var r := CombatSkill.resolve_hit(WeaponCatalog.SWORD_YUCHEOL, i)
		var b := int(r["base"])
		if b < 12 or b > 25:
			in_band = false
		seen[b] = true
		if bool(r["crit"]):
			crits += 1
	_check("④b 밴드 롤은 항상 [12,25] 안 · 값이 실제로 갈린다(시드마다 새 롤)",
		in_band and seen.size() >= 8)
	_check("④c base 크리 = 2% · 배율 3(200회에 크리가 드물게만 — 0~15회)",
		absf(CombatSkill.CRIT_BASE - 0.02) < 0.0001 and absf(CombatSkill.CRIT_MULT - 3.0) < 0.0001
		and crits >= 0 and crits <= 15)
	_check("④d 미상 무기는 damage 0(맨손 기본 피해 없음 — 무기가 축이다)",
		int(CombatSkill.resolve_hit("", 1)["damage"]) == 0
		and int(CombatSkill.resolve_hit("sword_ghost", 1)["damage"]) == 0)
	# 퍼크 변조 — 척후(확률 ×1.5) · 결사(배율 ×2) · 투사+광전사(피해 합산 +25%).
	_check("④e 척후 = 크리 확률 ×1.5(2% → 3%)",
		absf(CombatSkill.crit_chance(1.0) - 0.02) < 0.0001
		and absf(CombatSkill.crit_chance(1.5) - 0.03) < 0.0001)
	_check("④f 결사 = 크리 배율 ×2(3 → 6)",
		absf(CombatSkill.crit_mult(1.0) - 3.0) < 0.0001
		and absf(CombatSkill.crit_mult(2.0) - 6.0) < 0.0001)
	_check("④g 투사+광전사 = 피해 배수 1.25(합산 +25%)",
		absf(CombatSkill.damage_factor(0.0) - 1.0) < 0.0001
		and absf(CombatSkill.damage_factor(0.25) - 1.25) < 0.0001)
	# 같은 시드에서 피해 퍼크만 얹으면 정확히 그 비율만큼 오른다(base 롤은 불변 = 순차 소비 규율).
	var plain := CombatSkill.resolve_hit(WeaponCatalog.SWORD_EOPHWADO, 7)
	var buffed := CombatSkill.resolve_hit(WeaponCatalog.SWORD_EOPHWADO, 7, 0.25)
	_check("④h 같은 시드 · 피해 퍼크만 다름 → base 롤 동일 · 최종만 ×1.25",
		int(plain["base"]) == int(buffed["base"])
		and int(buffed["damage"]) == int(float(plain["base"]) * 1.25))
	# 크리가 확정으로 터지는 시드를 찾아 배율이 실제로 얹히는지 본다(결사 = 3배 → 6배).
	var crit_seed := -1
	for i in 500:
		if bool(CombatSkill.resolve_hit(WeaponCatalog.SWORD_EOPHWADO, i)["crit"]):
			crit_seed = i
			break
	_check("④i pre 크리가 터지는 시드가 존재(500회 안에)", crit_seed >= 0)
	if crit_seed >= 0:
		var c3 := CombatSkill.resolve_hit(WeaponCatalog.SWORD_EOPHWADO, crit_seed)
		var c6 := CombatSkill.resolve_hit(WeaponCatalog.SWORD_EOPHWADO, crit_seed, 0.0, 1.0, 2.0)
		_check("④j 크리 배율이 실제로 얹힌다(×3) · 결사면 ×6",
			int(c3["damage"]) == int(float(c3["base"]) * 3.0)
			and int(c6["damage"]) == int(float(c3["base"]) * 6.0))
	_check("④k 몹 → 플레이어 = 고정 데미지(변동 롤 없음 · 음수 방어)",
		CombatSkill.incoming_damage(15) == 15 and CombatSkill.incoming_damage(-4) == 0)

	# ── ⑤ 스윙 부채꼴 · 몹 훅 ──
	print("── ⑤ 스윙 부채꼴 · 몹 훅 ──")
	var arc_r := CombatSkill.swing_arc(Vector2i(10, 10), Vector2i.RIGHT)
	_check("⑤a 부채꼴 = 정면 2칸 + 1칸 앞 좌우 대각 = 4칸",
		arc_r.size() == 4 and arc_r.has(Vector2i(11, 10)) and arc_r.has(Vector2i(12, 10))
		and arc_r.has(Vector2i(11, 9)) and arc_r.has(Vector2i(11, 11)))
	var arc_u := CombatSkill.swing_arc(Vector2i(10, 10), Vector2i.UP)
	_check("⑤b 방향이 의미를 갖는다 — 위를 보면 위쪽 4칸(뒤·옆은 안 맞는다)",
		arc_u.has(Vector2i(10, 9)) and arc_u.has(Vector2i(10, 8))
		and not arc_u.has(Vector2i(10, 11)) and not arc_u.has(Vector2i(11, 10)))
	_check("⑤c 대각 facing은 우세 축으로 스냅 · (0,0)은 빈 배열",
		CombatSkill.swing_arc(Vector2i(10, 10), Vector2i(3, 1)) == arc_r
		and CombatSkill.swing_arc(Vector2i(10, 10), Vector2i.ZERO).is_empty())
	_check("⑤d 몹 훅 = 빈 몹 목록이면 빈 결과(★S5-T5까지의 폴백)",
		CombatSkill.hits_in_arc(arc_r, []).is_empty()
		and CombatSkill.hits_in_arc([], [{"tile": Vector2i(11, 10)}]).is_empty())
	var picked: Array = CombatSkill.hits_in_arc(arc_r, [
		{"tile": Vector2i(11, 10), "id": "in"}, {"tile": Vector2i(5, 5), "id": "out"}])
	_check("⑤e arc 안 몹만 골라낸다(겹침 검사 — T5가 이 인자만 채우면 실효)",
		picked.size() == 1 and String(picked[0]["id"]) == "in")

	# ── ⑥ 전문직 퍼크 인코딩(ADR-0052 로스터 이행) ──
	print("── ⑥ 전투 전문직 퍼크 인코딩 ──")
	var combat_profs := ProfessionCatalog.professions_for(ProfessionCatalog.COMBAT)
	var all_encoded := true
	for p in combat_profs:
		if (p["perks"] as Array).is_empty():
			all_encoded = false
	_check("⑥a 전투 트리 6전문직 전부 퍼크 인코딩됨(구조-only 아님)",
		combat_profs.size() == 6 and all_encoded)
	_check("⑥b 투사 = 피해 +10% + HP +15(한 전문직이 두 차원)",
		ProfessionCatalog.perks_of(ProfessionCatalog.COMBAT, "fighter").size() == 2)
	_check("⑥c 척후 = 크리 확률 ×1.5 · 결사 = 크리 배율 ×2",
		float(ProfessionCatalog.perks_of(ProfessionCatalog.COMBAT, "scout")[0]["value"]) == 1.5
		and float(ProfessionCatalog.perks_of(ProfessionCatalog.COMBAT, "desperado")[0]["value"]) == 2.0)
	_check("⑥d 곡예사 = **예약 퍼크**(값은 있으나 해석기가 중립 1.0 반환 — 효과 보류)",
		float(ProfessionCatalog.perks_of(ProfessionCatalog.COMBAT, "acrobat")[0]["value"]) == 0.5
		and absf(CombatSkill.special_cooldown_factor(0.5) - 1.0) < 0.0001)
	_check("⑥e tier10은 전부 부모 lvl5를 요구한다(합산 퍼크의 정합 근거)",
		ProfessionCatalog.requires_of(ProfessionCatalog.COMBAT, "brute") == "fighter"
		and ProfessionCatalog.requires_of(ProfessionCatalog.COMBAT, "defender") == "fighter"
		and ProfessionCatalog.requires_of(ProfessionCatalog.COMBAT, "desperado") == "scout"
		and ProfessionCatalog.requires_of(ProfessionCatalog.COMBAT, "acrobat") == "scout")

	# ── 라이브 배선(main) ──
	print("── ⑦ 라이브 배선 — 자원·스윙·무과금·5행 ──")
	var m: Node = await _spawn_main()
	m._indoor = ""
	_check("⑦a 체력 자원이 부팅과 함께 선다(100/100) · 혼력과 별 객체",
		m.health != null and m.health.current == 100 and m.health.maximum == 100
		and m.health != m.energy)
	_check("⑦b HUD 2바 복원 — vitals가 체력·혼력 **둘 다** 물고 있다",
		m.vitals != null and m.vitals.health == m.health and m.vitals.energy == m.energy)
	# 숙련 탭 5행 완성(5스킬 전면 가동).
	var rows: Array = m._skill_rows()
	var names: Array = []
	for r in rows:
		names.append(String(r["name"]))
	_check("⑦c 숙련 탭 5행 = 농사·채집·낚시·채광·전투(5스킬 전면 가동)",
		rows.size() == 5 and names == ["농사", "채집", "낚시", "채광", "전투"])
	_check("⑦d 전투 행이 다른 넷과 같은 스키마(특별 취급 0)",
		rows[4].has("level") and rows[4].has("xp") and rows[4].has("floor_xp")
		and rows[4].has("next_xp") and String(rows[4]["skill"]) == ProfessionCatalog.COMBAT)
	# 5행 프레임 렌더 무크래시 + 스크롤 상태 존재(패널 높이 봉합).
	m._open_frame(InventoryFrame.CTX_MENU)
	m.frame.set_tab(InventoryFrame.TAB_SKILL)
	m.frame.set_skills(rows)
	await process_frame
	_check("⑦e 5행 숙련 탭 렌더 무크래시 · 행 스크롤 상태 존재(패널 높이 봉합)",
		m.frame._skill_scroll == 0 and m.frame._skill_area_rect.size.y > 0.0)
	m._close_frame()
	# ── 무기 스윙: 혼력·HP 무과금 ──
	_check("⑦f pre 검 장착(핫바에서 드는 것이 곧 장착 전환)", _equip(m, WeaponCatalog.SWORD_RUSTY))
	m.energy.current = 0                       # ★혼력 0에서도 휘둘러진다(전투 행동비용 0)
	var hp_before: int = m.health.current
	var swings_before: int = m._combat_swings
	m._use_tool()
	m._use_tool()                              # ★같은 프레임 재호출(LMB 디스패치 중복 시뮬)
	_check("⑦g 무기 스윙 = 혼력 0에서도 성립 · 혼력·HP 무과금(ADR-0011 행동비용 0)",
		m._combat_swings == swings_before + 1 and m.energy.current == 0
		and m.health.current == hp_before)
	_check("⑦g′ 한 프레임 = 한 스윙(타일별 LMB 디스패치가 겹쳐도 검은 한 번만 휘둘린다)",
		m._combat_swings == swings_before + 1)
	await process_frame
	m._use_tool()
	_check("⑦g″ 다음 프레임엔 다시 휘둘린다(프레임 가드가 스윙을 영구히 막지 않는다)",
		m._combat_swings == swings_before + 2)
	_check("⑦h 라이브 몹 목록은 빈 배열(★S5-T5 훅) — 허공 스윙도 동작이다",
		(m._mobs_in_region() as Array).is_empty())
	# arc가 벽 뒤 칸을 자른다(SOLID 배제).
	var arc_live: Array = m._weapon_arc()
	var arc_walkable := true
	for t: Vector2i in arc_live:
		if m.is_solid(m._grid[t.y][t.x]):
			arc_walkable = false
	# ★[폴리시 R10 #3] 상한이 4 → 5로 올랐다: 라이브 arc는 순수 부채꼴 4칸에 **선 자리(origin)**를
	#   더한다(겹친 추적 몹을 베기 위해 — `_weapon_arc` 머리말). 순수 기하(⑤a)는 그대로 4칸이다.
	_check("⑦i 라이브 arc는 벽·프롭 칸을 뺀다(벽 하나 사이로 못 벤다) · 선 자리 포함 최대 5칸",
		arc_walkable and arc_live.size() <= 5 and arc_live.has(m._player_tile()))
	# ── 무기 미장착이면 기존 도구 거동 완전 불변 ──
	m.energy.current = SoulEnergy.MAX
	_check("⑦j pre 괭이로 전환", _equip(m, ItemCatalog.HOE))
	var swings_hoe: int = m._combat_swings
	var farm_target := Vector2i(-1, -1)
	for y in range(2, m._outdoor_h - 2):
		for x in range(2, m._grid_w - 2):
			if m._is_farmable(Vector2i(x, y)) and not m.farm.is_tilled(Vector2i(x, y)):
				farm_target = Vector2i(x, y)
				break
		if farm_target != Vector2i(-1, -1):
			break
	_check("⑦k pre 경작 가능한 빈 칸 존재", farm_target != Vector2i(-1, -1))
	m._target = farm_target
	var e_before: int = m.energy.current
	m._use_tool()
	_check("⑦l 무기 미장착 = 기존 도구 거동 **불변**(괭이질 성립 · 혼력 과금 · 스윙 카운터 0)",
		m.farm.is_tilled(farm_target) and m.energy.current < e_before
		and m._combat_swings == swings_hoe)

	# ── ⑧ 피격 무적 창 · 넉백 ──
	print("── ⑧ 피격 무적 창 · 넉백 ──")
	m._hurt_at = m.INVULN_NONE
	m._mine_descended_at = m.INVULN_NONE
	m.health.refill()
	_check("⑧a 무적 창 없음(기준점 INVULN_NONE) = 지금 맞는다", not m._is_invulnerable())
	var dealt: int = m.take_damage(12)
	_check("⑧b 피해 12 적용 · 무적 창 시작", dealt == 12 and m.health.current == m.health.maximum - 12
		and m._is_invulnerable())
	_check("⑧c 무적 창 안 추가 피격은 **튕긴다**(0 반환 · HP 불변)",
		m.take_damage(30) == 0 and m.health.current == m.health.maximum - 12)
	_check("⑧d 무적 창 상수 = 0.8초(ADR-0063 결정 4 잠정)", absf(m.COMBAT_INVULN_SECS - 0.8) < 0.0001)
	# 층 하강 무적(1초)은 별개 창 — 피격 창을 닫아도 하강 창만으로 무적이 성립한다.
	m._hurt_at = m.INVULN_NONE
	m._mine_descended_at = float(Time.get_ticks_msec()) / 1000.0
	_check("⑧e 층 하강 무적 1초는 **별개 창**(피격 창을 닫아도 무적)",
		m._is_invulnerable() and m.take_damage(50) == 0
		and absf(m.MINE_DESCEND_INVULN_SECS - 1.0) < 0.0001)
	# 넉백 — 출처 반대 방향으로 고정 거리(막힌 방향이면 제자리).
	m._hurt_at = m.INVULN_NONE
	m._mine_descended_at = m.INVULN_NONE
	var pos_before: Vector2 = m.player.global_position
	m.take_damage(5, pos_before + Vector2(m.TILE * 2.0, 0.0))   # 오른쪽에서 맞음 → 왼쪽으로 밀림
	var moved: Vector2 = m.player.global_position - pos_before
	_check("⑧f 넉백 = 출처 반대 방향 고정 거리(왼쪽으로 밀림 · 거리 = 상수)",
		moved.x < 0.0 and absf(moved.length() - m.COMBAT_KNOCKBACK_PX) < 0.5)
	m._hurt_at = m.INVULN_NONE
	var pos2: Vector2 = m.player.global_position
	m.take_damage(5)                                            # source 미지정 = 넉백 없음
	_check("⑧g 출처 없는 피해(환경·낙하 자리)는 넉백 0", m.player.global_position == pos2)

	# ── ⑨ 기절 — 시간만 잃는다 ──
	print("── ⑨ 기절(무대 퇴장 + 시간 +2h · 손실 0) ──")
	m._hurt_at = m.INVULN_NONE
	m._mine_descended_at = m.INVULN_NONE
	m.health.refill()
	m.wallet.gold = 4321
	m.inventory.add_item(ItemCatalog.STONE, 7)
	var gold_before: int = m.wallet.gold
	var stone_before: int = m.inventory.count_of(ItemCatalog.STONE)
	var xp_before: int = m._combat_xp
	m.clock.minutes = 10.0 * 60.0               # 10:00
	var day_before: int = m.clock.day
	m.take_damage(9999)                          # → HP 0 → depleted → _faint
	_check("⑨a HP 0 → 기절 후 **풀회복**(반쯤 죽은 채 안 내보낸다)",
		m.health.current == m.health.maximum and not m.health.is_down())
	_check("⑨b 게임 시간 +2시간(10:00 → 12:00) · 날짜 불변",
		absf(m.clock.minutes - 12.0 * 60.0) < 0.001 and m.clock.day == day_before
		and m.FAINT_TIME_PENALTY_MIN == 120)
	_check("⑨c **골드·아이템·전투 XP 손실 0**(ADR-0011 — 스타듀 페널티 비채택)",
		m.wallet.gold == gold_before
		and m.inventory.count_of(ItemCatalog.STONE) == stone_before
		and m._combat_xp == xp_before)
	_check("⑨d 기절이 무적 창을 닫는다(복귀 직후 유령 무적 0)", m._hurt_at == m.INVULN_NONE)
	# 24:00 상한 — 늦은 밤 기절은 시계가 상한에서 잘린다(GameClock이 강제 취침을 잇는다).
	m.clock.minutes = 23.0 * 60.0
	m._advance_clock_minutes(m.FAINT_TIME_PENALTY_MIN)
	_check("⑨e 시간 페널티는 24:00에서 자른다(넘겨서 다음날로 새지 않는다)",
		absf(m.clock.minutes - float(GameClock.END_MIN)) < 0.001)
	m.clock.minutes = 10.0 * 60.0
	# 갱도 층에서 기절하면 지상으로 퇴장한다(무대 강제 퇴장 — 나락은 S5-T7).
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	m._descend_mine(3)
	await _settle(m)
	_check("⑨f pre 갱도 3층 상태 · 도달 최심층 3", m._in_mine_floor() and m.mine_floors.depth() == 3)
	# ★ 갱도 층 바닥은 PATH(비-SOIL)라 `_target_valid`가 false다 — 그래도 무기를 들면 스윙이 나가야
	#   한다(정작 전투가 벌어지는 무대에서 검이 안 휘둘리면 코어가 죽는다). LMB 게이트의 or 분기 검증.
	_check("⑨f′ pre 갱도 층에서 검 장착 · 조준 칸은 밭이 아니다",
		_equip(m, WeaponCatalog.SWORD_MYEONGDONG) and not m._target_valid)
	var mine_swings: int = m._combat_swings
	m._use_tool()
	_check("⑨f″ 갱도 층(비-SOIL 무대)에서도 스윙이 나간다", m._combat_swings == mine_swings + 1)
	m.health.refill()
	m._faint()
	await _settle(m)
	_check("⑨g 갱도 층 기절 = 지상 퇴장(층 0) · 도달 최심층은 **보존**(진행 손실 0)",
		m._mine_floor == 0 and m.mine_floors.depth() == 3)

	# ── ⑩ 세이브 왕복 · 하위호환 ──
	print("── ⑩ 세이브 왕복 · 하위호환 ──")
	m._rebuild_region(RegionCatalog.HOME)
	m._combat_xp = FarmSkill.XP_THRESHOLDS[5]    # Lv6 → 최대 125
	m._refresh_max_hp()
	_check("⑩a 전투 XP → 레벨 → 최대 HP 파생이 이어진다(Lv6 = 125)",
		m._skill_level(ProfessionCatalog.COMBAT) == 6 and m.health.maximum == 125)
	m.health.current = 77
	m._save_game()
	var saved: Dictionary = m.saver.load_game(m._active_slot)
	_check("⑩b 신규 키 2개만 늘었다(hp · combat_xp) · 기존 키 개명 0",
		saved.has("hp") and saved.has("combat_xp")
		and saved.has("furnace") and saved.has("geode_opened") and saved.has("mining_xp")
		and saved.has("mine") and saved.has("tool_tiers"))
	_check("⑩c 세이브 값 = 현재 HP + 전투 XP(최대는 저장 안 한다 — 파생 단일 출처)",
		int((saved["hp"] as Dictionary)["current"]) == 77
		and int(saved["combat_xp"]) == FarmSkill.XP_THRESHOLDS[5]
		and not (saved["hp"] as Dictionary).has("maximum"))
	m.health.current = 5
	m._combat_xp = 0
	m._load_game()
	await _settle(m)
	_check("⑩d 왕복 복원 — 전투 XP·최대·현재 HP가 모두 되돌아온다",
		m._combat_xp == FarmSkill.XP_THRESHOLDS[5] and m.health.maximum == 125
		and m.health.current == 77)
	_check("⑩e 로드가 무적 기준점을 리셋한다(실시간 ticks 불연속 방어)",
		m._hurt_at == m.INVULN_NONE and m._mine_descended_at == m.INVULN_NONE)
	# 하위호환 — 키가 없는 구세이브는 풀 HP · 0 XP.
	var hp2 := PlayerHealth.new()
	hp2.refresh_max(4, 0)                        # 최대 120
	hp2.load_save({})
	_check("⑩f 하위호환 — 키 없는 구세이브 = 풀 HP(반쯤 죽은 채 시작 안 함)",
		hp2.current == 120 and hp2.maximum == 120)
	var hp3 := PlayerHealth.new()
	hp3.load_save({"current": 0})
	_check("⑩g 손상 방어 — HP 0 세이브는 1로 되살린다(조작 불가 상태로 안 얼어붙게)",
		hp3.current == 1)
	var hp4 := PlayerHealth.new()
	hp4.load_save({"current": 9999})
	_check("⑩h 손상 방어 — 최대 초과분은 상한으로 자른다", hp4.current == hp4.maximum)

	# ── ⑪ 전문직 → HP·피해 실효(라이브) ──
	print("── ⑪ 전문직 실효(합산 리듀서) ──")
	m._combat_xp = FarmSkill.XP_THRESHOLDS[9]    # Lv10
	m._refresh_max_hp()
	_check("⑪a Lv10 · 전문직 0 = 최대 140", m.health.maximum == 140)
	var cur_before: int = m.health.current
	_check("⑪b pre 투사 선택(lvl5) → 수호자 선택(lvl10)",
		m.choose_profession(ProfessionCatalog.COMBAT, "fighter")
		and m.choose_profession(ProfessionCatalog.COMBAT, "defender"))
	_check("⑪c 투사 15 + 수호자 25 = **합산 40** → 최대 180(max로 접으면 165라 틀린다)",
		m.combat_max_hp_bonus() == 40 and m.health.maximum == 180)
	_check("⑪d 전문직 선택이 즉시 반영된다 — 늘어난 40만큼 현재 HP도 함께 오른다",
		m.health.current == cur_before + 40)
	_check("⑪e 투사 피해 +10% 실효(광전사 미선택이라 합산 = 0.10)",
		absf(m.combat_damage_bonus() - 0.10) < 0.0001)
	_check("⑪f 크리 퍼크는 배수라 중립 1.0(척후 갈래 미선택 — 투사 갈래를 골랐다)",
		absf(m.combat_crit_chance_mult() - 1.0) < 0.0001
		and absf(m.combat_crit_power_mult() - 1.0) < 0.0001)
	_check("⑪g 곡예사는 척후 갈래라 지금 못 고른다(부모 불일치 — 트리 정합)",
		not m.choose_profession(ProfessionCatalog.COMBAT, "acrobat"))
	# 합산 리듀서 자체 — 광전사까지 고른 세이브를 흉내 내 0.25가 되는지 본다(수치의 근거).
	m._professions[ProfessionCatalog.COMBAT] = {5: "fighter", 10: "brute"}
	_check("⑪h 투사 10% + 광전사 15% = **합산 25%**(스타듀 누적 곡선 1:1)",
		absf(m.combat_damage_bonus() - 0.25) < 0.0001)
	m._professions[ProfessionCatalog.COMBAT] = {5: "scout", 10: "desperado"}
	_check("⑪i 척후 ×1.5 · 결사 ×2 = 크리 3%·배율 6(배수는 max 리듀서)",
		absf(CombatSkill.crit_chance(m.combat_crit_chance_mult()) - 0.03) < 0.0001
		and absf(CombatSkill.crit_mult(m.combat_crit_power_mult()) - 6.0) < 0.0001)
	m._professions[ProfessionCatalog.COMBAT] = {5: "scout", 10: "acrobat"}
	_check("⑪j 곡예사 보유 = 예약 퍼크(선택은 살아 있고 효과만 중립 1.0)",
		absf(m.combat_special_cooldown() - 1.0) < 0.0001)

	# ── ⑫ 전투 XP 적립 경로 ──
	print("── ⑫ 전투 XP 적립 경로(소스는 S5-T5) ──")
	m._professions[ProfessionCatalog.COMBAT] = {}
	m._combat_xp = 0
	m._refresh_max_hp()
	var max0: int = m.health.maximum
	m._gain_combat_xp(FarmSkill.XP_THRESHOLDS[0])   # Lv1
	_check("⑫a add_xp 경로가 레벨·최대 HP를 함께 올린다(Lv1 = 105)",
		m._skill_level(ProfessionCatalog.COMBAT) == 1 and m.health.maximum == max0 + 5)
	m._gain_combat_xp(0)
	m._gain_combat_xp(-50)
	_check("⑫b 0·음수 XP는 무동작", m._combat_xp == FarmSkill.XP_THRESHOLDS[0])

	await _despawn(m)

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
