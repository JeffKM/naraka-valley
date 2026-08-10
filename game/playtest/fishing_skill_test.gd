extends SceneTree

# ★[S3-T6 / ADR-0061 결정 6] 낚시 스킬(FishSkill) · FISHING 전문직 퍼크 · 인양물 롤 검증.
#
# 무엇을 보나:
#   ⓐ XP 곡선 — FarmSkill 공통 기반 위임(임계·MAX_LEVEL 일치)·체급 비례 지급(10/20/40/100)·퍼펙트 +2.
#   ⓑ 레벨 효과 — 텐션 안전창·혼력 절감·퍼펙트 창 3계수(L0 정확히 중립·L10 실효). **같은 시드 동일 입력열**로
#      L0 vs L10을 돌려 실제로 격투가 쉬워지는지(끊김 지연·혼력 감소)까지 본다(계수 산술만 보지 않는다).
#   ⓒ main 배선 — _skill_level(FISHING)·_gain_fishing_xp 레벨업·포획 XP 지급·세이브 왕복·구세이브 하위호환.
#   ⓓ 전문직 퍼크 — 낚시꾼/명조사 품질 분포 상향(시드 고정)·퍼펙트 게이트 보존·보물잡이 인양 2배·
#      덫꾼 갈래 3종 조회 헬퍼(S3-T7 소비 접점)·picker 경로(lvl5 선택 가능·lvl10 부모 게이트).
#   ⓔ 인양 롤 — 결정성·기본 3%/보물잡이 6% 실빈도·2배 = 초집합·유품 극저확률·테이블 id 전원 실존·
#      격투 결과 무간섭(인양 유무가 어획물·혼력·XP를 안 바꾼다).
#
# FishSkill·SalvageTable·FishCatalog는 순수 static이라 ⓐ·ⓑ·ⓓ 일부·ⓔ는 씬 없이 돈다. ⓒ와 배선 단언만
# main.tscn을 띄운다(세이브·인벤·혼력이 필요).
# 좀비 방지: 끝에 quit(). run_tests.sh 워치독. 세이브 백업/원복(profession_test 결).

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

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

# 계속 당기기만 하는 격투 드라이버 — 결착까지 굴리고 (결과, 경과초)를 준다. 텐션 안전창 효과를
# "언제 끊기나"로 재는 데 쓴다(같은 시드·같은 입력열이면 차이의 원인은 계수뿐).
func _run_holding(sess: FishingSession, cap := 40.0, step := 0.05) -> Dictionary:
	var t := 0.0
	while sess.is_active() and t < cap:
		var reeling: bool = sess.state == FishingSession.State.BITE \
			or sess.state == FishingSession.State.FIGHT
		sess.tick(step, reeling)
		t += step
	return {"res": sess.result(), "secs": t}

func _initialize() -> void:
	print("▶ fishing_skill_test (S3-T6 / ADR-0061 결정 6)")
	var FISH := ProfessionCatalog.FISHING

	# ══ ⓐ XP 곡선 ═══════════════════════════════════════════════════════════
	_check("ⓐ MAX_LEVEL = FarmSkill과 같은 눈금(10)",
		FishSkill.MAX_LEVEL == FarmSkill.MAX_LEVEL and FishSkill.MAX_LEVEL == 10)
	_check("ⓐ XP 임계 = 공통 곡선 위임(FarmSkill.XP_THRESHOLDS)",
		FishSkill.xp_thresholds() == FarmSkill.XP_THRESHOLDS)
	_check("ⓐ level_for_xp 경계 — 0/99=L0 · 100=L1 · 5500=L10",
		FishSkill.level_for_xp(0) == 0 and FishSkill.level_for_xp(99) == 0
		and FishSkill.level_for_xp(100) == 1 and FishSkill.level_for_xp(5500) == 10)
	_check("ⓐ 만렙 상한 — 임계 초과도 L10 고정", FishSkill.level_for_xp(999999) == 10)
	# 체급 비례(ADR-0061 결정 6 실값).
	_check("ⓐ 포획 XP 체급 비례 = 소10·중20·대40·전설100",
		FishSkill.xp_for_catch(0, 0) == 10 and FishSkill.xp_for_catch(1, 0) == 20
		and FishSkill.xp_for_catch(2, 0) == 40 and FishSkill.xp_for_catch(3, 0) == 100)
	_check("ⓐ 퍼펙트 릴 보너스 = 회당 +2",
		FishSkill.xp_for_catch(0, 1) == 12 and FishSkill.xp_for_catch(2, 3) == 46)
	_check("ⓐ 손상 방어 — 체급 범위 밖 클램프·음수 퍼펙트 무시",
		FishSkill.xp_for_catch(-5, -3) == 10 and FishSkill.xp_for_catch(99, 0) == 100)

	# ══ ⓑ 레벨 효과 3계수 ════════════════════════════════════════════════════
	_check("ⓑ L0 = 정확히 중립(0.0 / 1.0 / 0.0)",
		is_equal_approx(FishSkill.tension_safe_bonus(0), 0.0)
		and is_equal_approx(FishSkill.energy_factor(0), 1.0)
		and is_equal_approx(FishSkill.perfect_window_add(0), 0.0))
	_check("ⓑ L10 = 텐션 0.10 · 혼력 0.70 · 퍼펙트 창 +0.20s",
		is_equal_approx(FishSkill.tension_safe_bonus(10), 0.10)
		and is_equal_approx(FishSkill.energy_factor(10), 0.70)
		and is_equal_approx(FishSkill.perfect_window_add(10), 0.20))
	_check("ⓑ 혼력 계수 = FarmSkill.energy_factor와 동형(레벨당 −3%)",
		is_equal_approx(FishSkill.energy_factor(5), FarmSkill.energy_factor(5)))
	_check("ⓑ 텐션 보너스 ≤ 코르크 보버(0.15) — 스킬이 기어를 넘어서지 않음",
		FishSkill.tension_safe_bonus(FishSkill.MAX_LEVEL) < 0.15)
	var mono := true
	for lv in range(0, 11):
		if lv > 0 and (FishSkill.tension_safe_bonus(lv) <= FishSkill.tension_safe_bonus(lv - 1)
				or FishSkill.energy_factor(lv) >= FishSkill.energy_factor(lv - 1)
				or FishSkill.perfect_window_add(lv) <= FishSkill.perfect_window_add(lv - 1)):
			mono = false
	_check("ⓑ 레벨당 단조 개선(퇴보 구간 없음)", mono)
	_check("ⓑ 범위 밖 레벨 클램프", is_equal_approx(FishSkill.energy_factor(99), FishSkill.energy_factor(10))
		and is_equal_approx(FishSkill.energy_factor(-3), 1.0))

	# ⓑ-2 **같은 시드·같은 입력열** 격투 비교 — 계수가 실제 손맛을 바꾸는가.
	# 중 체급을 계속 당기면(풀기 없음) 스태미나가 마르기 전에 줄이 끊긴다(fishing.gd 밸런스 의도).
	# L10의 텐션 안전창(0.10)이 그 끊김을 **뒤로 민다** = 안전창이 실효한다는 직접 증거.
	var med := {"weight_class": FishingSession.WeightClass.MEDIUM}
	var s_l0 := FishingSession.new(4242, med, {"max_class": FishingSession.WeightClass.MEDIUM,
		"tension_safe_bonus": FishSkill.tension_safe_bonus(0)},
		{"energy_factor": FishSkill.energy_factor(0), "perfect_window_add": FishSkill.perfect_window_add(0)})
	var s_l10 := FishingSession.new(4242, med, {"max_class": FishingSession.WeightClass.MEDIUM,
		"tension_safe_bonus": FishSkill.tension_safe_bonus(10)},
		{"energy_factor": FishSkill.energy_factor(10), "perfect_window_add": FishSkill.perfect_window_add(10)})
	s_l0.cast(); s_l10.cast()
	var r0 := _run_holding(s_l0)
	var r10 := _run_holding(s_l10)
	_check("ⓑ2 L0·L10 둘 다 계속 당기면 줄이 끊긴다(중 체급 밸런스 불변)",
		bool(r0["res"]["line_broke"]) and bool(r10["res"]["line_broke"]))
	_check("ⓑ2 L10 텐션 안전창 → 끊김이 더 늦다(같은 시드·같은 입력열)",
		float(r10["secs"]) > float(r0["secs"]))
	_check("ⓑ2 L0 후킹 혼력 = 중 8 · L10 = 8×0.70 = 6(반올림)",
		int(r0["res"]["energy_cost"]) == 8 and int(r10["res"]["energy_cost"]) == 6)
	_check("ⓑ2 혼력 하한 1 — 계수가 아무리 낮아도 공짜는 없다",
		FishingSession.new(1, {"weight_class": 0}, {}, {"energy_factor": 0.0}).energy_cost() == 1)
	# 퍼펙트 창 가산은 세션 내부 상태라 창 길이를 직접 본다(발버둥 시작 직후 창이 열린 채로 남는 시간).
	var s_pw := FishingSession.new(77, {"weight_class": 0}, {}, {"perfect_window_add": FishSkill.perfect_window_add(10)})
	_check("ⓑ2 퍼펙트 창 가산 = 세션 mods로 전달(0.20)",
		is_equal_approx(float(s_pw.mods["perfect_window_add"]), 0.20))

	# ══ ⓓ-A 전문직 퍼크 데이터(순수 카탈로그) ════════════════════════════════
	_check("ⓓA 낚시꾼 = FISH_QUALITY 0.10",
		_perk_of(FISH, "fisher", ProfessionCatalog.DIM_FISH_QUALITY) == 0.10)
	_check("ⓓA 명조사 = FISH_TOP_QUALITY 20",
		_perk_of(FISH, "angler", ProfessionCatalog.DIM_FISH_TOP_QUALITY) == 20.0)
	_check("ⓓA 보물잡이 = SALVAGE_DOUBLE flag",
		_perk_of(FISH, "pirate", ProfessionCatalog.DIM_SALVAGE_DOUBLE) == 1.0)
	_check("ⓓA 덫꾼 갈래 3종 퍼크 채워짐(★S3-T7 소비)",
		_perk_of(FISH, "trapper", ProfessionCatalog.DIM_TRAP_SAVE) > 0.0
		and _perk_of(FISH, "mariner", ProfessionCatalog.DIM_TRAP_NO_JUNK) == 1.0
		and _perk_of(FISH, "luremaster", ProfessionCatalog.DIM_TRAP_NO_BAIT) == 1.0)
	var all_filled := true
	for p in ProfessionCatalog.professions_for(FISH):
		if p["perks"].is_empty():
			all_filled = false
	_check("ⓓA 낚시 6전문직 전원 perks 비어 있지 않음", all_filled)
	# ADR-0052 §1 불변 — +판매가/마진 차원 부재(관계 곱셈기 전용).
	var no_value_dim := true
	for p in ProfessionCatalog.professions_for(FISH):
		for perk in p["perks"]:
			var d := String(perk["dim"])
			if d.contains("price") or d.contains("margin") or d.contains("gold"):
				no_value_dim = false
	_check("ⓓA 낚시 퍼크에 +판매가/마진 차원 없음(ADR-0052 §1)", no_value_dim)

	# ══ ⓓ-B 품질 퍼크 실효(FishCatalog — 시드 고정 분포) ═════════════════════
	# ★ 퍼펙트 게이트 보존: 이리듐 몫이 0인 행(퍼펙트 0·1회)은 명조사도 못 연다.
	_check("ⓓB 명조사 게이트 보존 — 퍼펙트 0·1회 행은 불변",
		FishCatalog.quality_row_for(0, 20) == FishCatalog.quality_row(0)
		and FishCatalog.quality_row_for(1, 20) == FishCatalog.quality_row(1))
	_check("ⓓB 명조사 상위 계단 — 퍼펙트 2회 [25,40,30,5] → [5,40,30,25]",
		FishCatalog.quality_row_for(2, 20) == [5, 40, 30, 25])
	_check("ⓓB 명조사 — 퍼펙트 3회 [8,32,45,15] → [0,20,45,35](금 보존)",
		FishCatalog.quality_row_for(3, 20) == [0, 20, 45, 35])
	_check("ⓓB top_bonus=0은 정확히 중립(기존 호출 결과 불변)",
		FishCatalog.quality_row_for(2, 0) == FishCatalog.quality_row(2)
		and FishCatalog.quality_for_roll(2, 30) == FishCatalog.quality_for_roll(2, 30, 0))
	_check("ⓓB 행 합 보존 100(확률 총량 불변)", _row_sum(FishCatalog.quality_row_for(3, 20)) == 100
		and _row_sum(FishCatalog.quality_row_for(2, 99)) == 100)
	# 분포 비교 — 낚시꾼(품질 축 +0.10)·명조사(이리듐 몫)가 실제로 등급을 올리는가(같은 시드열).
	var base_sum := 0
	var fisher_sum := 0
	var irid_plain := 0
	var irid_angler := 0
	for i in 400:
		base_sum += FishCatalog.quality_for(2, _rng(9000 + i), 0.0, 0)
		fisher_sum += FishCatalog.quality_for(2, _rng(9000 + i), 0.10, 0)
		if FishCatalog.quality_for(2, _rng(9000 + i), 0.0, 0) == ItemCatalog.Q_IRIDIUM:
			irid_plain += 1
		if FishCatalog.quality_for(2, _rng(9000 + i), 0.0, 20) == ItemCatalog.Q_IRIDIUM:
			irid_angler += 1
	_check("ⓓB 낚시꾼 = 등급 합 상향(같은 시드열)", fisher_sum > base_sum)
	_check("ⓓB 명조사 = 이리듐 빈도 대폭↑ (%d → %d / 400)" % [irid_plain, irid_angler],
		irid_angler > irid_plain * 2)

	# ══ ⓔ 인양물 롤(SalvageTable — 순수·결정적) ══════════════════════════════
	var tbl := SalvageTable.table()
	var tbl_ok := true
	var tw := 0
	for e in tbl:
		tw += int(e["weight"])
		if not ItemCatalog.has_item(String(e["id"])):
			tbl_ok = false
	_check("ⓔ 인양 테이블 id 전원 실존 아이템(신규 남발 0 — 신설은 삭은 그물 1종)", tbl_ok)
	_check("ⓔ 가중 합 = 1000", tw == 1000)
	_check("ⓔ 삭은 그물 = CAT_MATERIAL·판매가 5",
		ItemCatalog.category_of(ItemCatalog.ROTTEN_NET) == ItemCatalog.CAT_MATERIAL
		and ItemCatalog.price_of(ItemCatalog.ROTTEN_NET) == 5
		and ItemCatalog.name_of(ItemCatalog.ROTTEN_NET) == "삭은 그물")
	_check("ⓔ 결정성 — 같은 시드 = 같은 결과",
		SalvageTable.roll(12345, 30) == SalvageTable.roll(12345, 30)
		and SalvageTable.roll(999, 60) == SalvageTable.roll(999, 60))
	_check("ⓔ permil 0 = 항상 없음", SalvageTable.roll(1, 0) == "" and SalvageTable.roll(2, -5) == "")
	# 실빈도(연속 시드 4000개) — 3% ± 여유. 캐스팅 시드가 연속값이므로 이 검사가 해시 편향을 잡는다.
	var hits_base := 0
	var hits_pirate := 0
	var superset := true
	var relics := 0
	for i in 4000:
		var s := 700000 + i * 7   # 캐스팅 시드 결(연속·선형)
		var a := SalvageTable.roll(s, SalvageTable.BASE_PERMIL)
		var b := SalvageTable.roll(s, SalvageTable.permil_for(true))
		if a != "":
			hits_base += 1
			if b != a:
				superset = false   # 2배는 초집합 — 원래 나오던 게 사라지면 안 된다
		if b != "":
			hits_pirate += 1
			if SalvageTable.is_relic(b):
				relics += 1
	var rate := float(hits_base) / 4000.0
	_check("ⓔ 기본 인양 확률 ≈ 3%% (실측 %.2f%%)" % (rate * 100.0), rate > 0.015 and rate < 0.05)
	# ★ "2배"의 *엄밀한* 보장은 초집합 성질이다(permil 상향 = 통과 집합 확대). 표본 빈도는 해시 분포
	#   때문에 정확히 2.00배가 아니라 그 언저리다 — 밴드로 본다(4000 표본 기준).
	var ratio := float(hits_pirate) / maxf(float(hits_base), 1.0)
	_check("ⓔ 보물잡이 ≈ 2배(%d → %d · %.2f배)" % [hits_base, hits_pirate, ratio],
		ratio > 1.7 and ratio < 2.3)
	_check("ⓔ 2배 = 초집합(기존 인양물 보존 — '2배'의 엄밀한 보장)", superset)
	# 유품 실확률 = 인양분의 2%(테이블 가중 20/1000). 인양 자체가 3%라 포획당 0.06%다.
	# 큰 표본에서 (a) 실제로 나오고 (b) 여전히 극소수임을 함께 본다(도달 불가·과다 둘 다 배제).
	var forced := 0
	var forced_relics := 0
	for i in 20000:
		var id := SalvageTable.roll(31337 + i * 13, 1000)   # permil 1000 = 항상 인양(분포만 본다)
		if id == "":
			continue
		forced += 1
		if SalvageTable.is_relic(id):
			forced_relics += 1
	var relic_rate := float(forced_relics) / maxf(float(forced), 1.0)
	_check("ⓔ 유품 = 인양분의 ~2%%(실측 %.2f%% · %d/%d) — 나오되 극소수"
		% [relic_rate * 100.0, forced_relics, forced],
		forced_relics > 0 and relic_rate > 0.005 and relic_rate < 0.05)
	_check("ⓔ 실제 인양 표본에서도 유품 비중 극소(%d/%d)" % [relics, hits_pirate],
		relics * 10 < maxi(hits_pirate, 1))
	_check("ⓔ permil_for — 기본 30 · 보물잡이 60",
		SalvageTable.permil_for(false) == 30 and SalvageTable.permil_for(true) == 60)

	# ══ Part B: main 스폰(ⓒ 배선 · ⓓ picker · ⓔ 무간섭) ══════════════════════
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.fishskill_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m := await _spawn_main()

	# ── ⓒ main 배선 ──
	m._fishing_xp = 0
	m._professions = {}
	_check("ⓒ 신규 세이브 = 낚시 L0(무막힘 — base 맨몸 가동)", m._skill_level(FISH) == 0)
	_check("ⓒ L0 mods = 정확히 중립(기어 0)",
		is_equal_approx(float(m._fishing_mods()["energy_factor"]), 1.0)
		and is_equal_approx(float(m._fishing_mods()["perfect_window_add"]), 0.0))
	_check("ⓒ L0 rod = 기어 보너스 그대로(T1 = 0.0)",
		is_equal_approx(float(m._fishing_rod_params(ItemCatalog.ROD_T1)["tension_safe_bonus"]), 0.0))
	m._gain_fishing_xp(100)
	_check("ⓒ _gain_fishing_xp(100) → L1", m._skill_level(FISH) == 1 and m._fishing_xp == 100)
	m._gain_fishing_xp(-10)
	_check("ⓒ 음수 XP 무시", m._fishing_xp == 100)
	m._fishing_xp = 5500   # L10
	_check("ⓒ L10 mods 실효(혼력 0.70·퍼펙트 +0.20)",
		is_equal_approx(float(m._fishing_mods()["energy_factor"]), 0.70)
		and is_equal_approx(float(m._fishing_mods()["perfect_window_add"]), 0.20))
	_check("ⓒ L10 rod 텐션 안전창 = 0.10(기어 위에 가산)",
		is_equal_approx(float(m._fishing_rod_params(ItemCatalog.ROD_T1)["tension_safe_bonus"]), 0.10))
	# 숙련 탭 3행(농사·채집·낚시) — picker 데이터 계약.
	var frow := _fish_row(m._skill_rows())
	_check("ⓒ 숙련 탭에 낚시 행 존재(표시명 '낚시')", String(frow.get("name", "")) == "낚시")
	_check("ⓒ 낚시 행 레벨 = 10 · xp 5500", int(frow.get("level", -1)) == 10 and int(frow.get("xp", 0)) == 5500)

	# ★[S3-T6] 낚시가 3행째로 합류해도 고정 높이 패널 안에 들어가는가(치수 회귀 — 옛 치수로는 넘쳤다).
	var fr := InventoryFrame.new()
	root.add_child(fr)
	fr.menu_tab = InventoryFrame.TAB_SKILL
	var pr: Rect2 = fr._panel_rect()
	var need := InventoryFrame.PAD + 48.0 \
		+ 3.0 * (InventoryFrame.SK_ROW_H + InventoryFrame.SK_ROW_GAP)
	_check("ⓒ 숙련 탭 3행(농사·채집·낚시)이 패널 높이 안에 들어감 (%.0f ≤ %.0f)"
		% [need, pr.size.y - InventoryFrame.FRAME_MARGIN],
		need <= pr.size.y - InventoryFrame.FRAME_MARGIN)
	fr.free()

	# ── ⓓ-C picker 경로(lvl5 선택 가능 · lvl10 부모 게이트) ──
	m._fishing_xp = 1500   # L5
	m._professions = {}
	_check("ⓓC L5 → pending 5", m._pending_profession_tier(FISH) == 5)
	frow = _fish_row(m._skill_rows())
	_check("ⓓC L5 옵션 2(낚시꾼·덫꾼)", frow.get("options", []).size() == 2)
	_check("ⓓC L5에서 lvl10 선택 거부(레벨 미달)", not m.choose_profession(FISH, "angler"))
	_check("ⓓC L5 낚시꾼 선택 성공", m.choose_profession(FISH, "fisher"))
	_check("ⓓC 같은 tier 재선택 거부", not m.choose_profession(FISH, "trapper"))
	m._fishing_xp = 5500   # L10
	_check("ⓓC lvl10 부모 불일치 거부(뱃사람 ← 덫꾼 필요)", not m.choose_profession(FISH, "mariner"))
	frow = _fish_row(m._skill_rows())
	var opt_ids := []
	for o in frow.get("options", []):
		opt_ids.append(String(o["id"]))
	_check("ⓓC L10 옵션 = 낚시꾼 자식 2(명조사·보물잡이)",
		opt_ids.size() == 2 and opt_ids.has("angler") and opt_ids.has("pirate"))
	_check("ⓓC 퍼크 API — 낚시꾼 실효(품질 0.10)", is_equal_approx(m.fishing_quality_bonus(), 0.10))
	_check("ⓓC 낚시꾼만으론 명조사·보물잡이 0",
		m.fishing_top_quality_bonus() == 0 and m.fishing_salvage_permil() == SalvageTable.BASE_PERMIL)
	_check("ⓓC 보물잡이 선택 성공(부모 정합)", m.choose_profession(FISH, "pirate"))
	_check("ⓓC 보물잡이 → 인양 확률 2배", m.fishing_salvage_permil() == SalvageTable.BASE_PERMIL * 2)
	# 덫꾼 갈래 조회 헬퍼(★S3-T7 소비 접점) — 이 세이브는 낚시꾼 갈래라 전부 꺼져 있어야 한다.
	_check("ⓓC 덫꾼 갈래 헬퍼 = 미선택 시 전부 중립",
		is_equal_approx(m.crab_pot_cost_save(), 0.0) and not m.crab_pot_no_junk()
		and not m.crab_pot_bait_free())
	_check("ⓓC has_profession 관례 조회(보물잡이 O · 덫꾼 X)",
		m.has_profession(FISH, "pirate") and not m.has_profession(FISH, "trapper"))

	# ── ⓒ-2 세이브 왕복 + 구세이브 하위호환 ──
	m._fishing_xp = 2345
	m._save_game()
	m.queue_free()
	await process_frame
	await process_frame
	var m2 := await _spawn_main()
	_check("ⓒ2 fishing_xp 라운드트립(2345)", m2._fishing_xp == 2345)
	_check("ⓒ2 전문직 라운드트립 — 낚시꾼+보물잡이",
		m2.has_profession(FISH, "fisher") and m2.has_profession(FISH, "pirate")
		and m2.fishing_salvage_permil() == SalvageTable.BASE_PERMIL * 2)
	# 구세이브(키 없음) 하위호환 — _load_game 경로를 키 뺀 dict로 직접 흉내 낼 수 없으니 로더 규약을 본다.
	m2._fishing_xp = maxi(int({}.get("fishing_xp", 0)), 0)
	_check("ⓒ2 구세이브(fishing_xp 키 없음) = 0 → L0 무막힘", m2._fishing_xp == 0 and m2._skill_level(FISH) == 0)
	m2._fishing_xp = maxi(int({"fishing_xp": -999}.get("fishing_xp", 0)), 0)
	_check("ⓒ2 손상 세이브(음수) = 0으로 클램프", m2._fishing_xp == 0)

	# ── ⓒ-3 포획 XP 라이브 지급 + ⓔ 인양 무간섭 ──
	# 실제 결착 경로(_finish_fishing)를 태워, XP·인양이 어획 결과를 안 건드리는지 본다.
	m2._fishing_xp = 0
	m2._professions = {}
	m2.energy.refill()
	m2._cast_bobber_bonus = 0.0
	m2._cast_tackles = []
	m2._cast_bait = ""
	var before_fish: int = m2.inventory.count_of(FishCatalog.NEOK_MYEOLCHI)
	# ★[S7-T4 / ADR-0065 결정 5 ⑤] 인양 확률에 **명부의 운**이 가산됐다(계수 ×0.5 = ±50‰). 그래서
	#   이 단계는 BASE_PERMIL이 아니라 **그날 실제로 굴릴 확률**(main.fishing_salvage_permil_today)로
	#   시드를 찾아야 한다 — 안 그러면 흉한 날엔 "걸리는 시드"를 찾아 놓고도 라이브 롤이 그 확률을
	#   안 써서 헛돈다. 검증 목적(인양이 격투 결과를 안 건드린다)은 운과 무관하므로, 운이 확률을
	#   0 아래로 끌어내리지 않는 날 하나를 골라 그 위에서 본다(날짜 하드코딩 0 — 탐색).
	var luck_day := 1
	for d in range(1, 449):
		if m2.fishing_salvage_permil() + int(roundf(DailyLuck.luck_for_day(d)
				* DailyLuck.W_SALVAGE * 1000.0)) > 0:
			luck_day = d
			break
	m2.clock.day = luck_day
	var live_permil: int = m2.fishing_salvage_permil_today()
	_check("ⓔ2pre 인양이 가능한 날 확보(day %d · 실효 %d‰ > 0)" % [luck_day, live_permil],
		live_permil > 0)
	# 인양이 **걸리는** 시드를 찾아 그 캐스팅으로 포획을 결착시킨다(무간섭의 최악 케이스).
	var hit_seed := -1
	for i in 5000:
		if SalvageTable.roll(i ^ 0x51ed270b, live_permil) != "":
			hit_seed = i
			break
	_check("ⓔ2 인양이 걸리는 캐스팅 시드 확보", hit_seed >= 0)
	m2._cast_seed = hit_seed
	m2.fishing = FishingSession.new(21, FishCatalog.session_params(FishCatalog.NEOK_MYEOLCHI))
	m2.fishing.cast()
	_run_holding(m2.fishing)
	_check("ⓒ3pre 소 체급 포획 성공", m2.fishing.state == FishingSession.State.LANDED)
	var perfects: int = m2.fishing.perfect_count
	m2._finish_fishing()
	_check("ⓒ3 포획 → 낚시 XP 지급(소 10 + 퍼펙트 %d×2)" % perfects,
		m2._fishing_xp == FishSkill.xp_for_catch(FishCatalog.WC_SMALL, perfects))
	_check("ⓔ2 인양이 걸려도 어획물은 정확히 1마리(격투 결과 무간섭)",
		m2.inventory.count_of(FishCatalog.NEOK_MYEOLCHI) == before_fish + 1)
	var salvaged := String(SalvageTable.roll(hit_seed ^ 0x51ed270b, live_permil))
	_check("ⓔ2 인양물이 인벤에 실제 지급(%s)" % ItemCatalog.name_of(salvaged),
		m2.inventory.has_item(salvaged))
	# 놓친 격투(ESCAPED)는 XP 0 — "배움은 성공에만".
	var xp_before: int = m2._fishing_xp
	m2.fishing = FishingSession.new(22, FishCatalog.session_params(FishCatalog.NEOUL_BEOMCHI),
		FishingSession.ROD_T1)   # 대어 + T1 = 체급 게이트 확정 끊김
	m2.fishing.cast()
	_run_holding(m2.fishing)
	m2._finish_fishing()
	_check("ⓒ3 놓친 격투 = XP 0(리스크는 혼력으로 이미 냈다)", m2._fishing_xp == xp_before)

	m2.queue_free()
	await process_frame

	# 세이브 원복.
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── 헬퍼 ────────────────────────────────────────────────────────────────────
func _perk_of(skill: String, id: String, dim: String) -> float:
	for perk in ProfessionCatalog.perks_of(skill, id):
		if perk["dim"] == dim:
			return float(perk["value"])
	return -1.0

func _row_sum(row: Array) -> int:
	var s := 0
	for v in row:
		s += int(v)
	return s

func _fish_row(rows: Array) -> Dictionary:
	for r in rows:
		if String(r.get("skill", "")) == ProfessionCatalog.FISHING:
			return r
	return {}
