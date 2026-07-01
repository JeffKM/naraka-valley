extends SceneTree

# ★ [S1-6 / greybox-spec §8.4·§8.5·§8.9] 비료 카탈로그 + 품질/숙련 순수 데이터 격리 검증.
#
# 무엇을 보나(순수 데이터·불변식만 — main 스폰·시뮬은 quality_skill_test로 분리):
#   ① 품질 확률표 — 4행(NONE/BASIC/QUALITY/DELUXE) 각 합=100·성분 ≥0.
#   ② tier_for_roll 경계 — NONE(0..79→0·80..97→1·98..99→2·이리듐 도달 0) / DELUXE(0..9→0·…·80..99→3).
#   ③ 등급 배수 — QUALITY_MULT=[1.0,1.25,1.5,2.0]·quality_mult clamp.
#   ④ 비료 로스터 — 2군 5종·group/state/speed_factor 매핑(0.75/0.67·무비료 1.0).
#   ⑤ 숙련 — XP 임계·level_for_xp(99→0·100→1·5500→10·초과 cap)·energy_factor(L0=1.0·L10=0.70).
#   ⑥ 검증기 이빨 — 행합≠100/등급 역전 mock을 _row_violations가 잡는지(가드 작동 증명).
#
# 정적 데이터라 main.tscn 스폰 불필요(crop_catalog_test 골격). 좀비 방지: 끝에 quit(). run_tests 워치독.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# ── 재사용 검증기(테스트 스코프 — 카탈로그는 순수 데이터 유지) ──
# 확률행의 위반 목록(빈 배열 = 합법). 합=100·성분 정수 ≥0·길이 4. §8.12 ⑥.
func _row_violations(row: Array) -> Array:
	var v: Array = []
	if row.size() != 4:
		v.append("행 길이≠4: %d" % row.size())
		return v
	var sum := 0
	for x in row:
		if int(x) < 0:
			v.append("음수 성분: %d" % int(x))
		sum += int(x)
	if sum != 100:
		v.append("행 합≠100: %d" % sum)
	return v

func _initialize() -> void:
	print("▶ fertilizer_catalog_test (S1-6)")
	var FC := FertilizerCatalog

	# ── ① 품질 확률표 4행 각 합=100·성분 ≥0 ──
	for state in [FC.STATE_NONE, FC.STATE_BASIC, FC.STATE_QUALITY, FC.STATE_DELUXE]:
		var viol := _row_violations(FC.QUALITY_TABLE[state])
		_check("① %s 확률행 합=100·성분≥0%s" % [state, "" if viol.is_empty() else " — " + str(viol)], viol.is_empty())

	# ── ② tier_for_roll 경계(결정적) ──
	# NONE [80,18,2,0]: 0..79→0 · 80..97→1 · 98..99→2 · 이리듐(3) 도달 0.
	_check("② NONE roll 0→0", FC.tier_for_roll(FC.STATE_NONE, 0) == 0)
	_check("② NONE roll 79→0(경계)", FC.tier_for_roll(FC.STATE_NONE, 79) == 0)
	_check("② NONE roll 80→1(경계)", FC.tier_for_roll(FC.STATE_NONE, 80) == 1)
	_check("② NONE roll 97→1(경계)", FC.tier_for_roll(FC.STATE_NONE, 97) == 1)
	_check("② NONE roll 98→2(경계)", FC.tier_for_roll(FC.STATE_NONE, 98) == 2)
	_check("② NONE roll 99→2(이리듐 미도달)", FC.tier_for_roll(FC.STATE_NONE, 99) == 2)
	# DELUXE [10,30,40,20]: 0..9→0 · 10..39→1 · 40..79→2 · 80..99→3.
	_check("② DELUXE roll 9→0(경계)", FC.tier_for_roll(FC.STATE_DELUXE, 9) == 0)
	_check("② DELUXE roll 10→1(경계)", FC.tier_for_roll(FC.STATE_DELUXE, 10) == 1)
	_check("② DELUXE roll 39→1(경계)", FC.tier_for_roll(FC.STATE_DELUXE, 39) == 1)
	_check("② DELUXE roll 40→2(경계)", FC.tier_for_roll(FC.STATE_DELUXE, 40) == 2)
	_check("② DELUXE roll 79→2(경계)", FC.tier_for_roll(FC.STATE_DELUXE, 79) == 2)
	_check("② DELUXE roll 80→3(경계)", FC.tier_for_roll(FC.STATE_DELUXE, 80) == 3)
	_check("② DELUXE roll 99→3", FC.tier_for_roll(FC.STATE_DELUXE, 99) == 3)
	# roll clamp(음수·초과) 방어 — 최저/최고 등급으로 흡수.
	_check("② roll<0 clamp→0", FC.tier_for_roll(FC.STATE_DELUXE, -5) == 0)
	_check("② roll≥100 clamp→최고", FC.tier_for_roll(FC.STATE_DELUXE, 200) == 3)
	# roll_quality(난수)는 항상 유효 등급 0..3(300회 표본).
	var all_valid := true
	for _i in 300:
		var t := FC.roll_quality(FC.STATE_QUALITY)
		if t < 0 or t > 3:
			all_valid = false
	_check("② roll_quality 난수 항상 0..3", all_valid)

	# ── ③ 등급 배수(ItemCatalog §8.2) ──
	_check("③ QUALITY_MULT = [1.0,1.25,1.5,2.0]", ItemCatalog.QUALITY_MULT == [1.0, 1.25, 1.5, 2.0])
	_check("③ quality_mult(0)=1.0", is_equal_approx(ItemCatalog.quality_mult(0), 1.0))
	_check("③ quality_mult(3)=2.0", is_equal_approx(ItemCatalog.quality_mult(3), 2.0))
	_check("③ quality_mult clamp(하한)", is_equal_approx(ItemCatalog.quality_mult(-9), 1.0))
	_check("③ quality_mult clamp(상한)", is_equal_approx(ItemCatalog.quality_mult(99), 2.0))
	_check("③ quality_name 등급별", ItemCatalog.quality_name(0) == "일반" and ItemCatalog.quality_name(3) == "이리듐")

	# ── ④ 비료 로스터 2군 5종·매핑 ──
	_check("④ 로스터 5종", FC.ids().size() == 5)
	# 품질군 3 + 성장촉진군 2.
	var q_group := 0
	var s_group := 0
	for id in FC.ids():
		match FC.group_of(id):
			"quality": q_group += 1
			"speed": s_group += 1
	_check("④ 품질군 3 + 성장촉진군 2", q_group == 3 and s_group == 2)
	# 품질군 state 매핑.
	_check("④ fert_basic → BASIC", FC.state_of(ItemCatalog.FERT_BASIC) == FC.STATE_BASIC)
	_check("④ fert_quality → QUALITY", FC.state_of(ItemCatalog.FERT_QUALITY) == FC.STATE_QUALITY)
	_check("④ fert_deluxe → DELUXE", FC.state_of(ItemCatalog.FERT_DELUXE) == FC.STATE_DELUXE)
	# 성장촉진군은 품질 state NONE(품질과 별 축).
	_check("④ fert_speed 품질 state NONE", FC.state_of(ItemCatalog.FERT_SPEED) == FC.STATE_NONE)
	_check("④ fert_hyper 품질 state NONE", FC.state_of(ItemCatalog.FERT_HYPER) == FC.STATE_NONE)
	# 성장촉진 계수(0.75/0.67), 품질군·무비료·미지는 1.0(무단축).
	_check("④ speed_factor(fert_speed)=0.75", is_equal_approx(FC.speed_factor(ItemCatalog.FERT_SPEED), 0.75))
	_check("④ speed_factor(fert_hyper)=0.67", is_equal_approx(FC.speed_factor(ItemCatalog.FERT_HYPER), 0.67))
	_check("④ speed_factor(품질비료)=1.0(무단축)", is_equal_approx(FC.speed_factor(ItemCatalog.FERT_BASIC), 1.0))
	_check("④ speed_factor(무비료 \"\")=1.0", is_equal_approx(FC.speed_factor(""), 1.0))
	_check("④ state_of(무비료 \"\")=NONE", FC.state_of("") == FC.STATE_NONE)
	# ItemCatalog가 비료를 카테고리/스택/구매가로 인지.
	_check("④ ItemCatalog category=fertilizer", ItemCatalog.category_of(ItemCatalog.FERT_BASIC) == ItemCatalog.CAT_FERTILIZER)
	_check("④ 비료 스택 가능", ItemCatalog.stackable_of(ItemCatalog.FERT_BASIC))
	_check("④ 비료 price=buy_cost(20)", ItemCatalog.price_of(ItemCatalog.FERT_BASIC) == 20)
	# id 계약 진실원(ItemCatalog.FERT_* == FertilizerCatalog 리터럴 키) 정합 — 순환 끊은 리터럴 어긋남 가드.
	_check("④ id 계약 정합(ItemCatalog↔FertilizerCatalog)", \
		FC.has(ItemCatalog.FERT_BASIC) and FC.has(ItemCatalog.FERT_QUALITY) and FC.has(ItemCatalog.FERT_DELUXE) \
		and FC.has(ItemCatalog.FERT_SPEED) and FC.has(ItemCatalog.FERT_HYPER))

	# ── ⑤ 농사 숙련 곡선(FarmSkill §8.9) ──
	_check("⑤ XP_THRESHOLDS 10개", FarmSkill.XP_THRESHOLDS.size() == 10)
	_check("⑤ level_for_xp(0)=0", FarmSkill.level_for_xp(0) == 0)
	_check("⑤ level_for_xp(99)=0(경계)", FarmSkill.level_for_xp(99) == 0)
	_check("⑤ level_for_xp(100)=1(경계)", FarmSkill.level_for_xp(100) == 1)
	_check("⑤ level_for_xp(299)=1", FarmSkill.level_for_xp(299) == 1)
	_check("⑤ level_for_xp(300)=2(경계)", FarmSkill.level_for_xp(300) == 2)
	_check("⑤ level_for_xp(5500)=10", FarmSkill.level_for_xp(5500) == 10)
	_check("⑤ level_for_xp(99999)=10(cap)", FarmSkill.level_for_xp(99999) == 10)
	_check("⑤ energy_factor(L0)=1.0", is_equal_approx(FarmSkill.energy_factor(0), 1.0))
	_check("⑤ energy_factor(L10)=0.70", is_equal_approx(FarmSkill.energy_factor(10), 0.70))
	_check("⑤ energy_factor clamp(초과 레벨)=0.70", is_equal_approx(FarmSkill.energy_factor(99), 0.70))
	_check("⑤ speed_factor 대칭(L10)=0.70", is_equal_approx(FarmSkill.speed_factor(10), 0.70))

	# ── ⑥ 검증기 이빨(음성 mock — 가드가 위반을 실제로 잡는가) ──
	_check("⑥ mock[행합 90] 위반 검출", not _row_violations([80, 8, 2, 0]).is_empty())
	_check("⑥ mock[행합 110] 위반 검출", not _row_violations([80, 18, 12, 0]).is_empty())
	_check("⑥ mock[음수 성분] 위반 검출", not _row_violations([110, -10, 0, 0]).is_empty())
	_check("⑥ mock[길이≠4] 위반 검출", not _row_violations([100, 0, 0]).is_empty())
	_check("⑥ 합법 행엔 무위반(대칭)", _row_violations([10, 30, 40, 20]).is_empty())

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
