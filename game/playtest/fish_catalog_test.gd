extends SceneTree

# ★[S3-T3 / ADR-0061 결정 3] 어종 로스터 18종(FishCatalog) 검증.
#
# 무엇을 보나:
#   ⓐ 스키마 완결성 — 18종·전 필드 존재·값 도메인(서식지/체급/절기/시간)·서식지·체급 분포·가격 밴드.
#   ⓑ 절기·시간 필터 — 잠금이 실제로 가용 셋을 가른다(절기 상이·시간 상이) + **밀도 하한**
#      (절기별 서식지당 비-전설 ≥3종 · 모든 절기×시간×서식지 조합에 최소 1종 = 사막 0).
#   ⓒ roll_fish — 결정성(같은 시드 = 같은 열)·가용 밖 어종 미출현(32조합 표본)·체급 가중 체감(소 ~80%).
#   ⓓ 품질 매핑 — quality_for_roll 경계 계단(퍼펙트 0=일반 위주·회수↑=상위 확률↑·이리듐은 2회부터)
#      + 시드 고정 분포 단언 + 퀄리티 보버 훅(기본 0.0 = 정확히 중립).
#   ⓔ ItemCatalog 통용 — has/category/name/stackable/price(등급 배수) + 출하함 정산 왕복.
#   ⓕ 전설 격리 — 일반 롤 1000회에 전설 0 · roll_legendary만 극저확률로 물리고 절기 밖이면 절대 0.
#
# FishCatalog는 순수 static 데이터라 main.tscn 스폰이 불필요하다(crop_catalog_test·fertilizer_catalog_test
# 골격). 좀비 방지: 끝에 quit(). run_tests.sh 워치독과 함께.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# 시드 주입 rng 하나(결정성 — 카탈로그 API는 전역 randf를 쓰지 않는다).
func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _initialize() -> void:
	print("▶ fish_catalog_test (S3-T3 / ADR-0061 결정 3)")
	var FC := FishCatalog
	var IC := ItemCatalog
	# ★[S5-T8 / ADR-0063 결정 10] 갱도 호수가 세 번째 무대로 합류(ADR-0061 결정 9 부분 개정).
	#   HABITATS = 스키마·조합 커버리지의 축(3무대) / OPEN_HABITATS = **절기 밀도 규칙**의 축이다.
	#   갱도를 밀도 규칙에서 뺀 이유: 지하 호수는 절기·시간 잠금이 아예 없어(둘 다 상시 2종) 그
	#   규칙이 방어하려던 "절기 사막"이 구조적으로 발생하지 않는다(아래 ⓑ가 그걸 직접 단언한다).
	var HABITATS := [FC.HABITAT_RIVER, FC.HABITAT_SEA, FC.HABITAT_MINE]
	var OPEN_HABITATS := [FC.HABITAT_RIVER, FC.HABITAT_SEA]
	var PHASES := [FC.PHASE_MORNING, FC.PHASE_DAY, FC.PHASE_EVENING, FC.PHASE_NIGHT]
	# 체급별 가격 밴드(ADR-0061 결정 3 "체급·희소도 비례" — 스타듀 문법).
	var PRICE_BAND := [[30, 55], [60, 120], [150, 250], [600, 900]]

	# ══ ⓐ 스키마 완결성 ══════════════════════════════════════════════════════
	# ★[S5-T8] 18 → 20(갱도 호수 2종 합류 — 의도적 불변식 개정).
	_check("ⓐ 로스터 = 20종", FC.FISH.size() == 20 and FC.ids().size() == 20)

	var field_ok := true
	var domain_ok := true
	var price_ok := true
	var bad: Array = []
	for id in FC.ids():
		var f: Dictionary = FC.FISH[id]
		for key in ["name_ko", "habitat", "weight_class", "seasons", "phases", "weather", "price", "fight"]:
			if not f.has(key):
				field_ok = false
				bad.append("%s: %s 누락" % [id, key])
		if not f.has("name_ko"):
			continue
		if String(f["name_ko"]) == "" or not HABITATS.has(String(f["habitat"])) \
				or int(f["weight_class"]) < 0 or int(f["weight_class"]) > 3 \
				or typeof(f["seasons"]) != TYPE_ARRAY or typeof(f["phases"]) != TYPE_ARRAY \
				or typeof(f["weather"]) != TYPE_ARRAY or typeof(f["fight"]) != TYPE_DICTIONARY:
			domain_ok = false
			bad.append("%s: 값 도메인" % id)
		for s in f["seasons"]:
			if int(s) < 0 or int(s) > 3:
				domain_ok = false
				bad.append("%s: 절기 %s" % [id, str(s)])
		for p in f["phases"]:
			if not PHASES.has(String(p)):
				domain_ok = false
				bad.append("%s: 시간대 %s" % [id, str(p)])
		var band: Array = PRICE_BAND[int(f["weight_class"])]
		if int(f["price"]) < int(band[0]) or int(f["price"]) > int(band[1]):
			price_ok = false
			bad.append("%s: 가격 %d ∉ [%d,%d]" % [id, int(f["price"]), int(band[0]), int(band[1])])
	_check("ⓐ 전 어종 스키마 필드 완비%s" % ("" if field_ok else " — " + str(bad)), field_ok)
	_check("ⓐ 값 도메인(서식지·체급 0~3·절기 0~3·시간대 문자열)%s" % ("" if domain_ok else " — " + str(bad)), domain_ok)
	_check("ⓐ 가격 > 0 · 체급별 밴드(소 30~55·중 60~120·대 150~250·전설 600~900)%s"
		% ("" if price_ok else " — " + str(bad)), price_ok)

	# 서식지·체급 분포(결정 3: 강 8 + 바다 8 + 전설 2(강 1·바다 1) / 소~중 위주 + 대 2 + 전설 2).
	var by_hab := {FC.HABITAT_RIVER: 0, FC.HABITAT_SEA: 0, FC.HABITAT_MINE: 0}
	var by_hab_legend := {FC.HABITAT_RIVER: 0, FC.HABITAT_SEA: 0, FC.HABITAT_MINE: 0}
	var by_class := [0, 0, 0, 0]
	for id in FC.ids():
		var h := FC.habitat_of(id)
		by_class[FC.weight_class_of(id)] += 1
		if FC.is_legendary(id):
			by_hab_legend[h] += 1
		else:
			by_hab[h] += 1
	_check("ⓐ 서식지 분포 = 강 8 · 바다 8 · ★갱도 2(비-전설)",
		by_hab[FC.HABITAT_RIVER] == 8 and by_hab[FC.HABITAT_SEA] == 8
		and by_hab[FC.HABITAT_MINE] == 2)
	# ★[S5-T8] 갱도엔 전설이 없다 — 전설은 "그 물의 주인"이라 무대마다 하나씩 늘릴 물건이 아니고,
	#   ADR-0063 결정 10도 갱도엔 2종만 뒀다(4종의 1/2 큐레이션에 전설이 들어갈 자리가 없다).
	_check("ⓐ 전설 2종 = 강 1 · 바다 1 · 갱도 0",
		by_hab_legend[FC.HABITAT_RIVER] == 1 and by_hab_legend[FC.HABITAT_SEA] == 1
		and by_hab_legend[FC.HABITAT_MINE] == 0)
	_check("ⓐ 체급 분포 = 소 9 · 중 7 · 대 2 · 전설 2 (★갱도 소1·중1 합류)",
		by_class == [9, 7, 2, 2])
	# 표시명 유일(중복 이름 = 인벤에서 구분 불가).
	var names := {}
	var name_uniq := true
	for id in FC.ids():
		if names.has(FC.name_of(id)):
			name_uniq = false
		names[FC.name_of(id)] = true
	_check("ⓐ 표시명 20개 전부 유일", name_uniq and names.size() == 20)
	# session_params = FishingSession 접속 계약(id + 체급 + 종별 오버라이드).
	var sp := FC.session_params(FC.MEOKBIT_JANGEO)
	_check("ⓐ session_params = id·체급·fight 오버라이드 전달",
		String(sp["id"]) == FC.MEOKBIT_JANGEO and int(sp["weight_class"]) == FC.WC_LARGE
		and sp.has("slack_rate"))
	var sess := FishingSession.new(1, FC.session_params(FC.NEOK_BUNGEO))
	_check("ⓐ FishingSession 주입 왕복 — result().fish_id로 어종이 되돌아온다",
		String(sess.result()["fish_id"]) == FC.NEOK_BUNGEO
		and sess.weight_class() == FC.WC_SMALL)

	# ══ ⓑ 절기·시간 필터 ═════════════════════════════════════════════════════
	# 밀도 하한 ①: 절기별·서식지당 비-전설 ≥3종(절기 잠금이 사막을 만들지 않는다).
	var density_ok := true
	var density_note: Array = []
	for h in OPEN_HABITATS:
		for s in range(4):
			var n: int = FC.season_roster(h, s).size()
			density_note.append("%s/%s=%d" % [h, GameClock.season_name(s), n])
			if n < 3:
				density_ok = false
	_check("ⓑ 절기별 서식지당 비-전설 ≥3종(하늘 아래 두 무대) — %s" % str(density_note), density_ok)
	# ★[S5-T8] 갱도는 밀도 규칙 대신 **무잠금**을 단언한다 — 2종 다 상시라 절기가 갈려도 로스터가
	#   줄지 않는다(지하 호수는 하늘을 안 본다). 이게 위 ≥3 규칙을 면제받는 근거다.
	var mine_open := true
	for s in range(4):
		if FC.season_roster(FC.HABITAT_MINE, s).size() != 2:
			mine_open = false
	_check("ⓑ ★갱도 호수 = 전 절기 상시 2종(절기 잠금 0 — 밀도 규칙 면제 근거)", mine_open)
	# 밀도 하한 ②: 모든 (서식지 × 절기 × 시간대) 조합에 최소 1종(roll_fish가 ""를 뱉는 구멍 0).
	var combo_ok := true
	var empty_combos: Array = []
	for h in HABITATS:
		for s in range(4):
			for p in PHASES:
				if FC.available_ids(h, s, p).is_empty():
					combo_ok = false
					empty_combos.append("%s/%d/%s" % [h, s, p])
	_check("ⓑ 32개 (서식지×절기×시간) 조합 전부 가용종 ≥1%s"
		% ("" if combo_ok else " — 빈 조합 " + str(empty_combos)), combo_ok)

	# 잠금이 실제로 가른다: 절기가 다르면 가용 셋이 다르고, 시간대가 다르면 가용 셋이 다르다.
	var r_spring := FC.available_ids(FC.HABITAT_RIVER, 0, FC.PHASE_DAY)
	var r_winter := FC.available_ids(FC.HABITAT_RIVER, 3, FC.PHASE_DAY)
	_check("ⓑ 절기 잠금 실효 — 피안절 낮 ≠ 성야절 낮(강)", r_spring != r_winter)
	var r_day := FC.available_ids(FC.HABITAT_RIVER, 1, FC.PHASE_DAY)
	var r_night := FC.available_ids(FC.HABITAT_RIVER, 1, FC.PHASE_NIGHT)
	_check("ⓑ 시간 잠금 실효 — 유화절 낮 ≠ 유화절 밤(강)", r_day != r_night)
	_check("ⓑ 밤 전용종 — 초롱치는 밤에만(강)",
		r_night.has(FC.CHORONG_CHI) and not r_day.has(FC.CHORONG_CHI))
	_check("ⓑ 밤 전용종 — 혼불해파리는 밤에만(바다)",
		FC.available_ids(FC.HABITAT_SEA, 0, FC.PHASE_NIGHT).has(FC.HONBUL_HAEPARI)
		and not FC.available_ids(FC.HABITAT_SEA, 0, FC.PHASE_MORNING).has(FC.HONBUL_HAEPARI))
	_check("ⓑ 상시종(빈 절기·빈 시간) = 전 조합에 존재",
		r_spring.has(FC.NEOK_BUNGEO) and r_winter.has(FC.NEOK_BUNGEO) and r_night.has(FC.NEOK_BUNGEO))
	_check("ⓑ 서식지 격리 — 강 어종은 바다 셋에 없다",
		not FC.available_ids(FC.HABITAT_SEA, 0, FC.PHASE_DAY).has(FC.NEOK_BUNGEO)
		and not r_spring.has(FC.NEOK_MYEOLCHI))
	_check("ⓑ 절기 밖 어종 미가용 — 잿빛송사리(망연·성야)는 피안절에 없다",
		not r_spring.has(FC.JAETBIT_SONGSARI)
		and FC.available_ids(FC.HABITAT_RIVER, 2, FC.PHASE_DAY).has(FC.JAETBIT_SONGSARI))
	_check("ⓑ available_ids 기본값 = 전설 제외 · include_legendary로만 노출",
		not FC.available_ids(FC.HABITAT_RIVER, 2, FC.PHASE_DAY).has(FC.GEOMEUNYEOUL_DAEMEGI)
		and FC.available_ids(FC.HABITAT_RIVER, 2, FC.PHASE_DAY, true).has(FC.GEOMEUNYEOUL_DAEMEGI))

	# ══ ⓒ roll_fish — 결정성 · 가용 밖 미출현 · 체급 가중 ═════════════════════
	var seq_a: Array = []
	var seq_b: Array = []
	var ra := _rng(4242)
	var rb := _rng(4242)
	for _i in 200:
		seq_a.append(FC.roll_fish(FC.HABITAT_RIVER, 1, FC.PHASE_NIGHT, ra))
		seq_b.append(FC.roll_fish(FC.HABITAT_RIVER, 1, FC.PHASE_NIGHT, rb))
	_check("ⓒ 결정성 — 같은 시드 200회 롤 열 완전 일치", seq_a == seq_b)
	var rc := _rng(999)
	var seq_c: Array = []
	for _i in 200:
		seq_c.append(FC.roll_fish(FC.HABITAT_RIVER, 1, FC.PHASE_NIGHT, rc))
	_check("ⓒ 다른 시드 = 다른 열(고착 아님)", seq_c != seq_a)

	# 32조합 × 40회 = 1,280회 표본: 전부 그 조합의 가용 셋 안이고 전설이 아니다.
	var out_of_pool := 0
	var rolled_legend := 0
	var rp := _rng(20260727)
	for h in HABITATS:
		for s in range(4):
			for p in PHASES:
				var pool := FC.available_ids(h, s, p)
				for _i in 40:
					var id := FC.roll_fish(h, s, p, rp)
					if not pool.has(id):
						out_of_pool += 1
					if FC.is_legendary(id):
						rolled_legend += 1
	_check("ⓒ 1,280회 롤 전부 가용 셋 안(절기·시간·서식지 잠금 준수)", out_of_pool == 0)
	_check("ⓒ 1,280회 롤에 전설 0(일반 롤은 전설을 모른다)", rolled_legend == 0)

	# 체급 가중 체감 — S3-T2 임시 분포(소 80 / 중 15 / 대 5)의 결을 잇는다.
	var counts := [0, 0, 0, 0]
	var rw := _rng(77)
	for _i in 4000:
		counts[FC.weight_class_of(FC.roll_fish(FC.HABITAT_RIVER, 2, FC.PHASE_EVENING, rw))] += 1
	var small_share := float(counts[0]) / 4000.0
	var large_share := float(counts[2]) / 4000.0
	_check("ⓒ 체급 가중 — 소 비중 ≈0.80 (실측 %.3f)" % small_share,
		small_share > 0.74 and small_share < 0.86)
	_check("ⓒ 체급 가중 — 대 비중 ≈0.05 (실측 %.3f)" % large_share,
		large_share > 0.02 and large_share < 0.09)

	# 가용 0인 무대(존재하지 않는 서식지)는 ""를 준다 — main이 fallback_id로 방어한다.
	_check("ⓒ 가용 0 = 빈 문자열 + fallback_id 방어",
		FC.roll_fish("nowhere", 0, FC.PHASE_DAY, _rng(1)) == ""
		and FC.has(FC.fallback_id(FC.HABITAT_RIVER)) and FC.has(FC.fallback_id(FC.HABITAT_SEA)))

	# ══ ⓓ 품질 매핑(퍼펙트 릴 → 등급) ════════════════════════════════════════
	var row_ok := true
	for row in FC.QUALITY_TABLE:
		var sum := 0
		for x in row:
			if int(x) < 0:
				row_ok = false
			sum += int(x)
		if row.size() != 4 or sum != 100:
			row_ok = false
	_check("ⓓ 확률표 4행 × 4등급 · 각 행 합 = 100", row_ok and FC.QUALITY_TABLE.size() == 4)
	# 경계 계단(결정적 순수 함수) — 퍼펙트 0회 행 [88,10,2,0].
	_check("ⓓ 퍼펙트 0회 roll 87→일반 · 88→은(경계)",
		FC.quality_for_roll(0, 87) == IC.Q_NORMAL and FC.quality_for_roll(0, 88) == IC.Q_SILVER)
	_check("ⓓ 퍼펙트 0회 roll 97→은 · 98→금 · 이리듐 도달 0",
		FC.quality_for_roll(0, 97) == IC.Q_SILVER and FC.quality_for_roll(0, 98) == IC.Q_GOLD
		and FC.quality_for_roll(0, 99) == IC.Q_GOLD)
	# 퍼펙트 3회 이상 행 [8,32,45,15] — 이리듐이 열린다.
	_check("ⓓ 퍼펙트 3회 roll 7→일반 · 8→은 · 40→금 · 85→이리듐",
		FC.quality_for_roll(3, 7) == IC.Q_NORMAL and FC.quality_for_roll(3, 8) == IC.Q_SILVER
		and FC.quality_for_roll(3, 40) == IC.Q_GOLD and FC.quality_for_roll(3, 85) == IC.Q_IRIDIUM)
	_check("ⓓ 퍼펙트 4회 이상은 3회 행으로 포화(표 밖 방어)",
		FC.quality_row(9) == FC.quality_row(3) and FC.quality_for_roll(9, 85) == IC.Q_IRIDIUM)
	# 계단 단조성: 같은 roll에서 퍼펙트 회수가 늘면 등급이 내려가지 않는다.
	var monotone := true
	for roll in range(100):
		for pc in range(3):
			if FC.quality_for_roll(pc + 1, roll) < FC.quality_for_roll(pc, roll):
				monotone = false
	_check("ⓓ 계단 단조 — 같은 roll에서 퍼펙트↑ ⇒ 등급 하락 없음", monotone)
	# 시드 고정 분포(2,000표본): 0회 = 일반 위주 · 3회 = 상위 등급 급증.
	var q0 := [0, 0, 0, 0]
	var q3 := [0, 0, 0, 0]
	var rq0 := _rng(5150)
	var rq3 := _rng(5150)
	for _i in 2000:
		q0[FC.quality_for(0, rq0)] += 1
		q3[FC.quality_for(3, rq3)] += 1
	var q0_normal := float(q0[0]) / 2000.0
	var q3_upper := float(q3[2] + q3[3]) / 2000.0
	_check("ⓓ 시드 고정 분포 — 퍼펙트 0회는 일반 위주(%.3f > 0.80)" % q0_normal, q0_normal > 0.80)
	_check("ⓓ 시드 고정 분포 — 퍼펙트 3회는 금+이리듐 급증(%.3f > 0.50)" % q3_upper, q3_upper > 0.50)
	_check("ⓓ 시드 고정 분포 — 이리듐은 퍼펙트 0회에 0 · 3회에 >0", q0[3] == 0 and q3[3] > 0)
	_check("ⓓ quality_for 결정성 — 같은 시드 = 같은 등급열",
		FC.quality_for(2, _rng(31)) == FC.quality_for(2, _rng(31)))
	# 퀄리티 보버 훅(S3-T4) — 기본 0.0은 정확히 중립, 양수는 상위로 민다.
	_check("ⓓ 퀄리티 보버 기본 0.0 = 중립(보정 무인자와 동일)",
		FC.quality_for(1, _rng(88), 0.0) == FC.quality_for(1, _rng(88)))
	var boosted := 0
	var plain := 0
	var rbo := _rng(606)
	var rpl := _rng(606)
	for _i in 1000:
		boosted += FC.quality_for(0, rbo, 0.3)
		plain += FC.quality_for(0, rpl, 0.0)
	_check("ⓓ 퀄리티 보버 보정 > 중립(등급 합 %d > %d)" % [boosted, plain], boosted > plain)

	# ══ ⓖ [S3-T4] 롤 보정 파라미터(미끼) — 중립성·결정성·효과 ═══════════════════
	# 유인 미끼(class_shift)·보장 미끼(guarantee_cap)는 roll_fish의 **선택 인자**다. 기본값이 정확히
	# 중립이어야 S3-T3의 모든 기존 단언(위 ⓒ)이 계속 유효하다 — 그것부터 못 박는다.
	_check("ⓖ 가중 시프트 0.0 = CLASS_WEIGHT 그대로(정확히 중립)",
		FC.class_weights(0.0) == FC.CLASS_WEIGHT)
	_check("ⓖ 가중 시프트 1.0 = 한 계단 위(중 15→80 · 대 5→15) · 전설 몫은 항상 0",
		is_equal_approx(float(FC.class_weights(1.0)[FC.WC_MEDIUM]), 80.0)
		and is_equal_approx(float(FC.class_weights(1.0)[FC.WC_LARGE]), 15.0)
		and is_equal_approx(float(FC.class_weights(1.0)[FC.WC_LEGEND]), 0.0))
	var seq_plain: Array = []
	var seq_zero: Array = []
	var r_p := _rng(2026)
	var r_z := _rng(2026)
	for _i in 100:
		seq_plain.append(FC.roll_fish(FC.HABITAT_SEA, 1, FC.PHASE_DAY, r_p))
		seq_zero.append(FC.roll_fish(FC.HABITAT_SEA, 1, FC.PHASE_DAY, r_z, 0.0, -1))
	_check("ⓖ 무인자 호출 = 보정 0 호출과 100회 열 완전 일치(회귀 0)", seq_plain == seq_zero)
	var seq_shift_a: Array = []
	var seq_shift_b: Array = []
	var r_a := _rng(555)
	var r_b := _rng(555)
	for _i in 100:
		seq_shift_a.append(FC.roll_fish(FC.HABITAT_SEA, 1, FC.PHASE_DAY, r_a, 1.0))
		seq_shift_b.append(FC.roll_fish(FC.HABITAT_SEA, 1, FC.PHASE_DAY, r_b, 1.0))
	_check("ⓖ 유인 시프트 결정성 — 같은 시드 100회 열 완전 일치", seq_shift_a == seq_shift_b)
	_check("ⓖ 유인 시프트 = 열이 실제로 달라진다(상수 반환 아님)", seq_shift_a != seq_plain)
	# 보장(guarantee_cap): 캡 이하 최고 체급만 나온다 + 전설은 여전히 안 샌다 + 결정적.
	var g_top_ok := true
	var g_cap_ok := true
	var g_legend := 0
	var r_g := _rng(99)
	for _i in 200:
		# 피안절 바다 저녁 가용 = 넋멸치·은비늘청어(소) · 저녁놀도미(중) · 너울범치(대).
		var top_id := FC.roll_fish(FC.HABITAT_SEA, 0, FC.PHASE_EVENING, r_g, 0.0, FC.WC_LEGEND)
		if top_id != FC.NEOUL_BEOMCHI:   # 캡을 안 씌우면 최고 체급(대) = 너울범치 단일
			g_top_ok = false
		if FC.is_legendary(top_id):
			g_legend += 1
		if FC.weight_class_of(FC.roll_fish(FC.HABITAT_SEA, 0, FC.PHASE_EVENING, r_g,
				0.0, FC.WC_SMALL)) != FC.WC_SMALL:
			g_cap_ok = false
		if FC.roll_fish(FC.HABITAT_SEA, 0, FC.PHASE_EVENING, r_g,
				0.0, FC.WC_MEDIUM) != FC.JEONYEOKNOL_DOMI:
			g_cap_ok = false
	_check("ⓖ 보장 = 가용 최고 체급 확정(피안절 바다 저녁 = 너울범치·대)", g_top_ok)
	_check("ⓖ 보장 상한 = 캡 이하 최고만(소 캡 = 소 · 중 캡 = 저녁놀도미)", g_cap_ok)
	_check("ⓖ 보장이어도 전설은 새지 않는다(일반 롤 전설 격리 불변)", g_legend == 0)
	var g_seq_a: Array = []
	var g_seq_b: Array = []
	var rg1 := _rng(1234)
	var rg2 := _rng(1234)
	for _i in 50:
		g_seq_a.append(FC.roll_fish(FC.HABITAT_RIVER, 2, FC.PHASE_NIGHT, rg1, 0.0, FC.WC_LARGE))
		g_seq_b.append(FC.roll_fish(FC.HABITAT_RIVER, 2, FC.PHASE_NIGHT, rg2, 0.0, FC.WC_LARGE))
	_check("ⓖ 보장 롤 결정성 — 같은 시드 50회 열 완전 일치", g_seq_a == g_seq_b)

	# ══ ⓔ ItemCatalog 통용 · 출하함 정산 ═════════════════════════════════════
	var ic_ok := true
	var ic_bad: Array = []
	for id in FC.ids():
		if not (IC.has_item(id) and IC._is_fish(id)
				and IC.category_of(id) == IC.CAT_HARVEST and IC.stackable_of(id)
				and IC.name_of(id) == FC.name_of(id)
				and IC.price_of(id) == FC.price_of(id)):
			ic_ok = false
			ic_bad.append(id)
	_check("ⓔ 18종 전부 ItemCatalog 통용(has/CAT_HARVEST/스택/이름/기준가)%s"
		% ("" if ic_ok else " — " + str(ic_bad)), ic_ok)
	_check("ⓔ 품질 유차원 — 금 등급 판매가 = 기준가 ×1.5(floor)",
		IC.price_of(FC.NEOUL_BEOMCHI, IC.Q_GOLD) == int(FC.price_of(FC.NEOUL_BEOMCHI) * 1.5)
		and IC.price_of(FC.NEOUL_BEOMCHI, IC.Q_IRIDIUM) > IC.price_of(FC.NEOUL_BEOMCHI, IC.Q_GOLD))
	_check("ⓔ 스텁 4종 제거 — 옛 fish_stub_* id는 카탈로그에서 사라졌다",
		not IC.has_item("fish_stub_small") and not IC.has_item("fish_stub_legend")
		and IC.category_of("fish_stub_large") == "")
	# 출하함 왕복(수확물 결 — 품질별로 쌓이고 판매가에 배수가 실린다).
	var bin := ShippingBin.new()
	bin.add(FC.NEOK_BUNGEO, 2, IC.Q_NORMAL)
	bin.add(FC.NEOK_BUNGEO, 1, IC.Q_GOLD)
	bin.add(FC.SIMYEON_MANJANGEO, 1, IC.Q_NORMAL)
	var expect := 2 * IC.price_of(FC.NEOK_BUNGEO, IC.Q_NORMAL) \
		+ IC.price_of(FC.NEOK_BUNGEO, IC.Q_GOLD) + IC.price_of(FC.SIMYEON_MANJANGEO, IC.Q_NORMAL)
	_check("ⓔ 출하함 대기 총액 = 품질별 판매가 합(%d)" % expect,
		bin.preview_gold() == expect and bin.total() == 4)
	_check("ⓔ 출하함 정산 = 총액 반환 후 비움",
		bin.settle() == expect and bin.is_empty() and bin.total() == 0)
	bin.free()

	# ══ ⓕ 전설 격리 ══════════════════════════════════════════════════════════
	# 일반 롤 1,000회(전설이 *가용한* 절기·무대에서) — 그래도 0.
	var legend_seen := 0
	var rl := _rng(31337)
	for _i in 1000:
		if FC.is_legendary(FC.roll_fish(FC.HABITAT_RIVER, 2, FC.PHASE_NIGHT, rl)):
			legend_seen += 1
	_check("ⓕ 일반 롤 1,000회(망연절 강 밤 = 전설 가용 조건)에 전설 0", legend_seen == 0)
	# roll_legendary는 절기 밖이면 절대 안 나온다(검은여울 대메기 = 망연절 전용).
	var off_season := 0
	var ros := _rng(4)
	for _i in 5000:
		if FC.roll_legendary(FC.HABITAT_RIVER, 0, FC.PHASE_NIGHT, ros) != "":
			off_season += 1
	_check("ⓕ 절기 밖 전설 = 5,000회 전부 미출현(피안절 강)", off_season == 0)
	# 가용 절기에서는 LEGEND_CHANCE(0.8%) 근방으로 물린다.
	var hits := 0
	var wrong_id := 0
	var ron := _rng(20261111)
	for _i in 20000:
		var lid := FC.roll_legendary(FC.HABITAT_RIVER, 2, FC.PHASE_NIGHT, ron)
		if lid != "":
			hits += 1
			if lid != FC.GEOMEUNYEOUL_DAEMEGI:
				wrong_id += 1
	var rate := float(hits) / 20000.0
	_check("ⓕ 망연절 강 전설 입질률 ≈ LEGEND_CHANCE %.3f (실측 %.4f)" % [FC.LEGEND_CHANCE, rate],
		rate > 0.004 and rate < 0.014 and FC.LEGEND_CHANCE < 0.01)
	_check("ⓕ 강 전설 = 검은여울 대메기 단일(바다 전설 혼입 0)", hits > 0 and wrong_id == 0)
	_check("ⓕ 바다 전설 = 유화절 심연 만장어",
		FC.available_ids(FC.HABITAT_SEA, 1, FC.PHASE_DAY, true).has(FC.SIMYEON_MANJANGEO)
		and not FC.available_ids(FC.HABITAT_SEA, 3, FC.PHASE_DAY, true).has(FC.SIMYEON_MANJANGEO))
	_check("ⓕ 전설 체급 = LEGEND(체급 게이트가 T4 낚싯대를 자연 요구)",
		FC.weight_class_of(FC.GEOMEUNYEOUL_DAEMEGI) == FC.WC_LEGEND
		and FC.weight_class_of(FC.SIMYEON_MANJANGEO) == FC.WC_LEGEND)

	print("― fish_catalog_test %s (실패 %d)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(0 if _fail == 0 else 1)
