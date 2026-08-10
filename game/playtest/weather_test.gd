extends SceneTree
# ★[S7-T3 / ADR-0065 결정 3·4] 저승 날씨 코어 — 파생 롤·효과 배선 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 롤 — 같은 day는 언제나 같은 하늘(결정성)·타입 범위·절기별 분포 규칙(절기 첫날 강제 평온·
#      성야절 혼우 0·잿눈은 성야절에만)·예보 = 내일 롤.
#   ② 혼우(비) — 아침 자동 급수. 물을 한 방울도 안 준 밭이 비 오는 날엔 자란다(스프링클러와
#      같은 `field.sprinkle` 경로 재사용의 증거). 평온한 날엔 안 자란다(대조군).
#   ③ 잿눈 — 그날 성장 정지 + **물은 마른다**(비살상·물 남기지 않음). 작물은 안 죽는다.
#   ④ 방목 게이트 — `_weather_calm()`이 잿눈에만 false(혼우·혼불 바람은 방목 허용).
#   ⑤ 카페 볼륨 — 잿눈 손님 +50%가 **단일 곱 자리**(축제 × 단계 × 날씨)에 합류했다.
#   ⑥ 어종 날씨 — 예약 필드 첫 평가. 혼우 한정 2종 · 무인자 호출 하위호환 · 의뢰 풀 제외.
#   ⑦ 던전 — 혼불 바람 잡귀 스폰 ×1.5 · 드랍 ×1.5 · 희귀 ×2 · 보스는 배수 무관.
#
# ★ 특정 날씨의 날짜는 **절대 하드코딩하지 않는다**(해시 롤이라 분포표를 만지면 곧장 어긋난다).
#   아래 _first_day_with 헬퍼가 구간을 훑어 첫 해당 날을 찾는다 — 표를 조정해도 테스트는 산다.
#
# 실행: ./run_tests.sh weather   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame
	return m

# 구간 [from, to] 안에서 이 날씨가 처음 나오는 날(-1 = 없음). 해시 롤이라 날짜 하드코딩 금지.
func _first_day_with(w: int, from_day: int, to_day: int) -> int:
	for d in range(from_day, to_day + 1):
		if Weather.weather_for_day(d) == w:
			return d
	return -1

# 밭을 이 테스트 것만 남기고 비운다(세이브 재개분 격리 — crop_season_test 관례).
func _clear_farm(m: Node) -> void:
	for t in m.farm.planted_tiles():
		m.farm.remove_plant(t)

func _initialize() -> void:
	print("══ S7-T3 저승 날씨 코어 검증 ══")

	# ── ① 파생 롤(순수 static — 인스턴스 불필요) ─────────────────────────────
	print("── ① 날씨 롤(결정성·분포) ──")
	var YEAR := GameClock.DAYS_PER_SEASON * 4      # 112일 = 1년 전수
	var det_ok := true
	var range_ok := true
	var counts := {}                                # 절기 → [평온, 혼우, 잿눈, 혼불]
	for si in 4:
		counts[si] = [0, 0, 0, 0]
	for d in range(1, YEAR + 1):
		var w := Weather.weather_for_day(d)
		if w != Weather.weather_for_day(d):
			det_ok = false
		if w < 0 or w >= Weather.NAMES.size():
			range_ok = false
			continue
		counts[GameClock.season_index_for_day(d)][w] += 1
	_check("①a 결정성 — 같은 day는 언제나 같은 하늘(1..112 전수)", det_ok)
	_check("①b 전 day가 유효 타입(평온·혼우·잿눈·혼불 바람)", range_ok)
	for si2 in 4:
		var c: Array = counts[si2]
		print("     %s: 평온 %d · 혼우 %d · 잿눈 %d · 혼불 바람 %d"
			% [GameClock.season_name(si2), c[0], c[1], c[2], c[3]])

	var first_ok := true
	for d2 in [1, 29, 57, 85]:
		if Weather.weather_for_day(int(d2)) != Weather.CALM:
			first_ok = false
	_check("①c 절기 첫날(1·29·57·85) = 강제 평온 — 사멸·재스폰 날에 하늘까지 겹치지 않는다", first_ok)
	_check("①d 성야절 혼우 0(스타듀 '겨울엔 비가 안 온다' 동형)", int(counts[3][Weather.RAIN]) == 0)
	var snow_only_winter := int(counts[0][Weather.SNOW]) == 0 and int(counts[1][Weather.SNOW]) == 0 \
		and int(counts[2][Weather.SNOW]) == 0
	_check("①e 잿눈은 성야절에만 내린다(다른 세 절기 0)", snow_only_winter)
	_check("①f 성야절에 잿눈이 실제로 내린다(분포가 죽지 않았다)", int(counts[3][Weather.SNOW]) > 0)
	var alive_ok := true
	for si3 in 4:
		if int(counts[si3][Weather.CALM]) >= GameClock.DAYS_PER_SEASON:
			alive_ok = false                        # 전부 평온인 절기 = 분포가 죽은 것
	_check("①g 절기마다 평온이 아닌 날이 있다(네 절기 다 하늘이 산다)", alive_ok)
	var dist_ok := true
	for row: Array in Weather.DISTRIBUTION:
		var sum := 0
		for v in row:
			sum += int(v)
		if sum != 100 or row.size() != Weather.NAMES.size():
			dist_ok = false
	_check("①h 분포표 = 절기 4행 · 각 행 합 100 · 타입 수 일치", dist_ok
		and Weather.DISTRIBUTION.size() == 4)
	var fc_ok := true
	for d3 in range(1, YEAR):
		if Weather.forecast(d3) != Weather.weather_for_day(d3 + 1):
			fc_ok = false
	_check("①i 예보 = 내일 롤 그 자체(점괘 거울이 읽을 100% 확정 예보)", fc_ok)
	_check("①j day 0·음수 = 평온(손상 방어)",
		Weather.weather_for_day(0) == Weather.CALM and Weather.weather_for_day(-7) == Weather.CALM)
	_check("①k 표시명 — 평온·혼우·잿눈·혼불 바람 ('' = 범위 밖)",
		Weather.name_of(Weather.CALM) == "평온" and Weather.name_of(Weather.RAIN) == "혼우"
		and Weather.name_of(Weather.SNOW) == "잿눈" and Weather.name_of(Weather.SOULWIND) == "혼불 바람"
		and Weather.name_of(9) == "")
	# ★[S7-T6] T3의 스텁(항상 false)이 Festival 위임으로 실효화됐다 — 테마 데이 **슬롯**(절기 25일)이면
	#   분포를 무시하고 평온이다. 해금은 안 본다(세이브 상태를 모르는 순수 파생 유지 — festival.gd 근거 주석).
	_check("①l 테마 데이 = Festival 슬롯 위임(절기 25일만 true)",
		not Weather._is_theme_day(5) and Weather._is_theme_day(25)
		and Weather._is_theme_day(25 + GameClock.DAYS_PER_SEASON) and not Weather._is_theme_day(26))
	_check("①m 테마 데이 당일 강제 평온", Weather.weather_for_day(25) == Weather.CALM)

	# ★ 분포 균일성 가드 — 빌드 중 실제로 터진 함정의 회귀 방지다: `hash(...) % 100`을 직접 쓰면
	#   순차 문자열의 하위 비트가 선형으로 남아 특정 10분위가 통째로 비고, 확률 5~20%로 배정한
	#   혼불 바람이 **1년 내내 한 번도 안 나왔다**(weather.gd 설계 메모 참조). 4년(448일)을 훑어
	#   "표에 0이 아니게 적힌 날씨는 반드시 나온다"를 못 박는다 — 믹싱이 빠지면 여기서 즉사한다.
	var uncovered := ""
	for si4 in 4:
		var row2: Array = Weather.DISTRIBUTION[si4]
		for wt in row2.size():
			if int(row2[wt]) <= 0:
				continue
			var found := false
			for yr in 4:
				var lo: int = yr * YEAR + si4 * GameClock.DAYS_PER_SEASON + 1
				if _first_day_with(wt, lo, lo + GameClock.DAYS_PER_SEASON - 1) > 0:
					found = true
					break
			if not found:
				uncovered += "%s/%s " % [GameClock.season_name(si4), Weather.name_of(wt)]
	_check("①n 표에 0이 아닌 날씨는 4년 안에 반드시 나온다(해시 뭉침 회귀 가드)%s"
		% ("" if uncovered == "" else " — 미출현: " + uncovered), uncovered == "")

	# 이후 단계가 쓸 대표 날짜(전부 탐색으로 구한다 — 하드코딩 0).
	var d_rain := _first_day_with(Weather.RAIN, 2, 28)          # 피안절 안의 혼우
	var d_snow := _first_day_with(Weather.SNOW, 86, 112)        # 성야절 안의 잿눈
	var d_wind := _first_day_with(Weather.SOULWIND, 30, 56)     # 유화절 안의 혼불 바람
	var d_calm := _first_day_with(Weather.CALM, 2, 28)          # 피안절 안의 평온
	print("     대표일 — 혼우 %d · 잿눈 %d · 혼불 바람 %d · 평온 %d" % [d_rain, d_snow, d_wind, d_calm])
	_check("①m 네 날씨 모두 1년 안에서 실제로 발생한다(아래 단계의 전제)",
		d_rain > 0 and d_snow > 0 and d_wind > 0 and d_calm > 0)

	# ── ② 혼우 = 아침 자동 급수 ─────────────────────────────────────────────
	print("── ② 혼우(비) 아침 자동 급수 ──")
	var m: Node = await _spawn_main()
	_clear_farm(m)
	# 여우불이 잠들어 있어야 "물 안 준 칸은 안 자란다"는 대조군이 성립한다(하트 0 = accel/reach 0).
	_check("②pre 여우불 잠듦(하트 0 — 대조군 성립 전제)",
		Foxfire.accel(m.affinity.hearts()) == 0 and Foxfire.reach(m.affinity.hearts()) == 0)
	var t_a := Vector2i(58, 45)
	var t_b := Vector2i(59, 45)
	var t_bare := Vector2i(60, 45)      # 심지 않은 경작 칸 — 비는 이 칸도 적신다(sprinkle 결)
	m.farm.hoe(t_a)
	m.farm.hoe(t_b)
	m.farm.hoe(t_bare)
	m.farm.plant(t_a, CropCatalog.BULSAGWA)   # 다절기 12일 — 절기·사멸과 무관하게 오래 자란다
	m.farm.plant(t_b, CropCatalog.BULSAGWA)
	_check("②pre2 두 칸 심김 · 물은 한 방울도 안 줬다",
		m.farm.is_planted(t_a) and m.farm.is_planted(t_b)
		and not m.farm.is_watered(t_a) and not m.farm.is_watered(t_b))

	# 대조군 먼저 — 평온한 날엔 물 안 준 칸이 안 자란다.
	m.clock.day = d_calm
	m._on_day_advanced(d_calm)
	await process_frame
	_check("②a 평온한 날 — 물 안 준 칸은 안 자란다(대조군)",
		m.farm.grown_days_of(t_a) == 0 and m.farm.grown_days_of(t_b) == 0)

	m.clock.day = d_rain
	m._on_day_advanced(d_rain)
	await process_frame
	_check("②b 혼우 — 물 안 준 밭이 자랐다(비가 `field.sprinkle`로 적셨다는 증거)",
		m.farm.grown_days_of(t_a) == 1 and m.farm.grown_days_of(t_b) == 1)
	_check("②c 아침 마름은 그대로 — 비 온 날에도 흙은 다음 날까지 젖어 있지 않다",
		not m.farm.is_watered(t_a) and not m.farm.is_watered(t_b))
	_check("②d 심지 않은 경작 칸도 무해하게 적셨다(급수 경로가 심김을 안 가린다)",
		m.farm.is_tilled(t_bare) and not m.farm.is_planted(t_bare))
	# 멱등 — 스프링클러가 이미 적신 칸에 비가 또 와도 이중 성장은 없다.
	m.farm.sprinkle(t_a)
	var before_idem: int = m.farm.grown_days_of(t_a)
	var rain2 := _first_day_with(Weather.RAIN, d_rain + 1, 28)
	if rain2 > 0:
		m.clock.day = rain2
		m._on_day_advanced(rain2)
		await process_frame
		_check("②e 스프링클러 급수 + 비 = 멱등(하루에 +1만 — 이중 성장 0)",
			m.farm.grown_days_of(t_a) == before_idem + 1)
	else:
		_check("②e 피안절에 혼우가 두 번 이상 있다(멱등 검증 전제)", false)

	# ── ③ 잿눈 = 성장 정지 + 물 마름 ────────────────────────────────────────
	print("── ③ 잿눈 성장 정지·물 마름 ──")
	var grown_before: int = m.farm.grown_days_of(t_a)
	m.farm.water(t_a)                                   # 손수 물까지 줬는데도
	m.farm.water(t_b)
	_check("③pre 두 칸 다 젖은 채로 잠든다", m.farm.is_watered(t_a) and m.farm.is_watered(t_b))
	m.clock.day = d_snow
	m._on_day_advanced(d_snow)
	await process_frame
	_check("③a 잿눈 날엔 물을 줬어도 안 자란다(성장 정지)",
		m.farm.grown_days_of(t_a) == grown_before and m.farm.grown_days_of(t_b) == grown_before)
	_check("③b 그래도 흙은 마른다 — 눈 온 날이 '물 준 상태 저장'이 되지 않는다",
		not m.farm.is_watered(t_a) and not m.farm.is_watered(t_b))
	_check("③c 비살상 — 작물은 죽지 않는다(사멸은 절기 전환의 몫이지 날씨가 아니다)",
		m.farm.is_planted(t_a) and m.farm.crop_of(t_a) == CropCatalog.BULSAGWA)
	# 눈이 그치면 곧장 다시 자란다(정지는 그날 하루뿐).
	var after_snow := _first_day_with(Weather.CALM, d_snow + 1, 112)
	if after_snow > 0:
		m.farm.water(t_a)
		m.clock.day = after_snow
		m._on_day_advanced(after_snow)
		await process_frame
		_check("③d 눈이 그친 다음 평온한 날엔 다시 자란다(정지는 그날 하루뿐)",
			m.farm.grown_days_of(t_a) == grown_before + 1)
	# field.gd 계약 직접 확인 — grow=false는 성장만 끄고 마름은 그대로(가법 인자의 정의).
	var f := FarmField.new()
	f.hoe(t_a)
	f.plant(t_a, CropCatalog.BULSAGWA)
	f.water(t_a)
	f.advance_day(0, 0, false)
	_check("③e field.advance_day(grow=false) — 성장 0 · 마름 O(시그니처 가법 확장의 계약)",
		f.grown_days_of(t_a) == 0 and not f.is_watered(t_a))
	f.water(t_a)
	f.advance_day()
	_check("③f 무인자 호출은 종전 그대로 자란다(기본값 = 정확히 중립)", f.grown_days_of(t_a) == 1)

	# ── ④ 방목 게이트 ───────────────────────────────────────────────────────
	print("── ④ 방목 날씨 게이트(_weather_calm) ──")
	m.clock.day = d_snow
	_check("④a 잿눈 — 방목 금지(스텁이 실효화됐다)", not m._weather_calm())
	m.clock.day = d_calm
	_check("④b 평온 — 방목 허용", m._weather_calm())
	m.clock.day = d_rain
	_check("④c 혼우 — 방목 허용(우리 비는 밭을 적시는 이득의 비 — ADR-0065 결정 4가 잿눈만 지목)",
		m._weather_calm())
	m.clock.day = d_wind
	_check("④d 혼불 바람 — 방목 허용(지상 효과 0 · 던전 한정)", m._weather_calm())
	_check("④e Weather.allows_grazing과 값이 같다(판정 복제 0)",
		Weather.allows_grazing(Weather.SNOW) == false
		and Weather.allows_grazing(Weather.RAIN) and Weather.allows_grazing(Weather.SOULWIND))

	# ── ⑤ 카페 손님 볼륨(단일 곱 자리) ──────────────────────────────────────
	print("── ⑤ 카페 볼륨 단일 곱(축제 × 단계 × 날씨) ──")
	var st: int = m._cafe_stage()
	m.clock.day = d_calm
	m._refresh_cafe_ladder()
	var scale_calm: float = m.cafe.spawn_scale
	m.clock.day = d_snow
	m._refresh_cafe_ladder()
	var scale_snow: float = m.cafe.spawn_scale
	# ★[S7-T6] 축제 배수는 이제 day가 아니라 *열리는 테마*에서 나온다(달력 슬롯 ∧ 해금).
	var fest_calm: float = Festival.spawn_scale_of(
		Festival.theme_for_day(d_calm, st, m._cafe_revenue_total))
	var fest_snow: float = Festival.spawn_scale_of(
		Festival.theme_for_day(d_snow, st, m._cafe_revenue_total))
	_check("⑤a 잿눈 = 축제 × 단계 × 날씨 곱 그대로(별도 대입 0)",
		is_equal_approx(scale_snow, fest_snow
			* CafeMilestone.spawn_scale_of(st) * Weather.cafe_spawn_scale(Weather.SNOW)))
	_check("⑤b 평온 = 날씨 배수 1.0(종전 값 불변 — 회귀 0)",
		is_equal_approx(scale_calm, fest_calm * CafeMilestone.spawn_scale_of(st)))
	# 축제 상태가 같은 두 날끼리만 비율을 본다(축제일이 끼면 0.5가 섞여 비교가 무의미해진다).
	if is_equal_approx(fest_calm, fest_snow):
		_check("⑤c 잿눈 손님 +50% = 스폰 간격 ×(1/1.5)",
			is_equal_approx(scale_snow * Weather.SNOW_CAFE_GUESTS, scale_calm))
	else:
		_check("⑤c 대표 두 날의 축제 상태가 같다(비율 비교 전제)", false)
	_check("⑤d 혼우·혼불 바람은 카페 무효(잿눈만 붐빈다)",
		is_equal_approx(Weather.cafe_spawn_scale(Weather.RAIN), 1.0)
		and is_equal_approx(Weather.cafe_spawn_scale(Weather.SOULWIND), 1.0))

	# ── ⑥ 어종 날씨(예약 필드 첫 평가) ──────────────────────────────────────
	print("── ⑥ 어종 날씨 태그 ──")
	var FC := FishCatalog
	var schema_ok := true
	var tagged: Array = []
	for fid in FC.ids():
		var wx: Array = FC.FISH[fid]["weather"]
		for v in wx:
			if typeof(v) != TYPE_INT or int(v) < 0 or int(v) >= Weather.NAMES.size():
				schema_ok = false
		if not wx.is_empty():
			tagged.append(fid)
	tagged.sort()
	_check("⑥a 전 어종 weather 필드가 유효 눈금(0..3)", schema_ok)
	_check("⑥b 날씨 한정 어종 = 도깨비메기·먹빛장어 딱 2종",
		tagged == [FC.DOKKAEBI_MEGI, FC.MEOKBIT_JANGEO])
	# 도깨비메기 = 강 · 유화(1)·성야(3) · 저녁/밤 · 혼우 한정.
	_check("⑥c 혼우면 가용",
		FC.is_available(FC.DOKKAEBI_MEGI, FC.HABITAT_RIVER, 1, FC.PHASE_NIGHT, Weather.RAIN))
	_check("⑥d 평온·잿눈·혼불 바람이면 비가용",
		not FC.is_available(FC.DOKKAEBI_MEGI, FC.HABITAT_RIVER, 1, FC.PHASE_NIGHT, Weather.CALM)
		and not FC.is_available(FC.DOKKAEBI_MEGI, FC.HABITAT_RIVER, 1, FC.PHASE_NIGHT, Weather.SNOW)
		and not FC.is_available(FC.DOKKAEBI_MEGI, FC.HABITAT_RIVER, 1, FC.PHASE_NIGHT, Weather.SOULWIND))
	_check("⑥e 무인자(날씨 축 무시) = 종전 그대로 가용 — 하위호환",
		FC.is_available(FC.DOKKAEBI_MEGI, FC.HABITAT_RIVER, 1, FC.PHASE_NIGHT)
		and FC.available_ids(FC.HABITAT_RIVER, 1, FC.PHASE_NIGHT).has(FC.DOKKAEBI_MEGI))
	_check("⑥f 날씨 태그 없는 어종은 어느 하늘에서도 가용(빈 배열 = 전 날씨)",
		FC.is_available(FC.NEOK_BUNGEO, FC.HABITAT_RIVER, 0, FC.PHASE_DAY, Weather.CALM)
		and FC.is_available(FC.NEOK_BUNGEO, FC.HABITAT_RIVER, 0, FC.PHASE_DAY, Weather.SNOW))
	var pool_rain := FC.available_ids(FC.HABITAT_RIVER, 1, FC.PHASE_NIGHT, false, Weather.RAIN)
	var pool_calm := FC.available_ids(FC.HABITAT_RIVER, 1, FC.PHASE_NIGHT, false, Weather.CALM)
	_check("⑥g 비 오는 밤 강 풀이 평온한 밤보다 넓다(날씨는 어종을 *더한다*)",
		pool_rain.size() > pool_calm.size()
		and pool_rain.has(FC.MEOKBIT_JANGEO) and not pool_calm.has(FC.MEOKBIT_JANGEO))
	var quest_clean := true
	for s4 in 4:
		for mc in [FC.WC_SMALL, FC.WC_MEDIUM, FC.WC_LARGE]:
			var qp := FC.quest_pool(s4, int(mc))
			if qp.has(FC.DOKKAEBI_MEGI) or qp.has(FC.MEOKBIT_JANGEO):
				quest_clean = false
			if qp.is_empty():
				quest_clean = false          # 제외가 풀을 통째로 비우면 의뢰가 안 나온다
	_check("⑥h 의뢰 풀에서 날씨 한정 어종 제외 · 그래도 전 절기·체급 풀이 안 빈다", quest_clean)
	# 실배선 — 비 오는 날의 입질 롤이 실제로 혼우 한정 어종을 낼 수 있나.
	# ★ 두 어종은 절기 창도 탄다(도깨비메기 유화·성야 / 먹빛장어 유화·망연) — 그래서 **유화절 안의**
	#   혼우 날과 평온 날을 짝지어 비교한다(피안절 비 오는 밤엔 절기 축에서 이미 걸러져 무의미).
	var d_rain_s1 := _first_day_with(Weather.RAIN, 30, 56)
	var d_calm_s1 := _first_day_with(Weather.CALM, 30, 56)
	var saw_rain_fish := false
	m.clock.minutes = 22 * 60                      # 밤(도깨비메기·먹빛장어의 시간대)
	m.clock.day = d_rain_s1
	for k in 400:
		var got: String = m._roll_fish_id(k)
		if got == FC.DOKKAEBI_MEGI or got == FC.MEOKBIT_JANGEO:
			saw_rain_fish = true
			break
	var saw_on_calm := false
	m.clock.day = d_calm_s1
	for k2 in 400:
		var got2: String = m._roll_fish_id(k2)
		if got2 == FC.DOKKAEBI_MEGI or got2 == FC.MEOKBIT_JANGEO:
			saw_on_calm = true
			break
	_check("⑥i 실배선(유화절 밤) — 비 오는 밤엔 걸리고, 평온한 밤엔 400회를 굴려도 안 걸린다",
		d_rain_s1 > 0 and d_calm_s1 > 0 and saw_rain_fish and not saw_on_calm)
	_check("⑥j 입질 대기 배수 — 혼우 0.8배(빨리 문다) · 잿눈 1/0.85배(늦게 문다) · 그 외 중립",
		is_equal_approx(Weather.bite_wait_factor(Weather.RAIN), 1.0 / 1.25)
		and Weather.bite_wait_factor(Weather.SNOW) > 1.0
		and is_equal_approx(Weather.bite_wait_factor(Weather.CALM), 1.0)
		and is_equal_approx(Weather.bite_wait_factor(Weather.SOULWIND), 1.0))
	# FishingSession 쪽 계약 — 날씨는 기어 클램프(상한 1.0)를 안 탄다(잿눈 둔화가 살아 있다).
	var s_calm := FishingSession.new(7, {}, {}, {"weather_factor": 1.0})
	var s_snow := FishingSession.new(7, {}, {}, {"weather_factor": Weather.bite_wait_factor(Weather.SNOW)})
	var s_rain := FishingSession.new(7, {}, {}, {"weather_factor": Weather.bite_wait_factor(Weather.RAIN)})
	s_calm.cast(); s_snow.cast(); s_rain.cast()
	_check("⑥k 잿눈 대기 > 평온 대기 > 혼우 대기(같은 시드 — 날씨만 갈린 비교)",
		s_snow._wait_secs > s_calm._wait_secs and s_calm._wait_secs > s_rain._wait_secs)

	# ── ⑦ 던전(혼불 바람) ───────────────────────────────────────────────────
	print("── ⑦ 혼불 바람 던전 배수 ──")
	var sum_base := 0
	var sum_wind := 0
	for fl in range(1, 31):
		if not MineFloors.spawns_mobs(fl):
			continue
		sum_base += (MineFloors.generate(11, fl) as Dictionary)["mobs"].size()
		sum_wind += (MineFloors.generate(11, fl, Weather.SOULWIND_MOB) as Dictionary)["mobs"].size()
	_check("⑦a 갱도 잡귀 ×1.5 — 30층 합계가 늘었다(기준 %d → 혼불 %d)" % [sum_base, sum_wind],
		sum_wind > sum_base)
	_check("⑦b 무인자 = 종전 배치 그대로(기본값 1.0 = 정확히 중립)",
		(MineFloors.generate(11, 3) as Dictionary)["mobs"]
			== (MineFloors.generate(11, 3, 1.0) as Dictionary)["mobs"])
	var nsum_base := 0
	var nsum_wind := 0
	for dp in range(1, 21):
		if NarakFloors.is_boss_depth(dp):
			continue
		nsum_base += (NarakFloors.generate(1, dp) as Dictionary)["mobs"].size()
		nsum_wind += (NarakFloors.generate(1, dp, Weather.SOULWIND_MOB) as Dictionary)["mobs"].size()
	_check("⑦c 나락 잡귀 ×1.5 — 20층 합계가 늘었다(기준 %d → 혼불 %d)" % [nsum_base, nsum_wind],
		nsum_wind > nsum_base)
	var boss_depth := 0
	for dp2 in range(1, 60):
		if NarakFloors.is_boss_depth(dp2):
			boss_depth = dp2
			break
	var boss_base: Array = (NarakFloors.generate(1, boss_depth) as Dictionary)["mobs"]
	var boss_wind: Array = (NarakFloors.generate(1, boss_depth, Weather.SOULWIND_MOB) as Dictionary)["mobs"]
	_check("⑦d 보스 층은 배수 무관 — 관문은 날씨로 늘어나지 않는다(%d층 보스 1기)" % boss_depth,
		boss_base.size() == 1 and boss_wind == boss_base)
	# 드랍 — 나락철(0.10·0.15)이 희귀 문턱 아래라 rare_scale을 탄다.
	var rare_base := 0
	var rare_wind := 0
	var common_base := 0
	var common_wind := 0
	for sd in 400:
		for d4: Dictionary in MobCatalog.roll_drops(MobCatalog.NACHAL, sd):
			if String(d4["id"]) == "ore_narakcheol":
				rare_base += 1
			else:
				common_base += 1
		for d5: Dictionary in MobCatalog.roll_drops(MobCatalog.NACHAL, sd,
				Weather.SOULWIND_DROP, Weather.SOULWIND_RARE):
			if String(d5["id"]) == "ore_narakcheol":
				rare_wind += 1
			else:
				common_wind += 1
	_check("⑦e 희귀(나락철) ×2 — 400시드 히트 %d → %d" % [rare_base, rare_wind],
		rare_wind > rare_base and float(rare_wind) >= float(rare_base) * 1.5)
	_check("⑦f 일반 드랍 ×1.5 — 줄지 않는다(%d → %d · 1.0 클램프라 상한 포화 허용)"
		% [common_base, common_wind], common_wind >= common_base)
	_check("⑦g 무인자 roll_drops = 배수 1.0 호출과 완전 동일(기존 드랍 결과열 불변)",
		MobCatalog.roll_drops(MobCatalog.NACHAL, 3) == MobCatalog.roll_drops(MobCatalog.NACHAL, 3, 1.0, 1.0))
	var boss_drop_base := MobCatalog.roll_drops(MobCatalog.BOSS_OKJOL, 5)
	var boss_drop_wind := MobCatalog.roll_drops(MobCatalog.BOSS_OKJOL, 5,
		Weather.SOULWIND_DROP, Weather.SOULWIND_RARE)
	_check("⑦h 보스 확정 드랍(chance 1.0)은 배수를 먹어도 그대로(1.0 클램프)",
		boss_drop_base.size() == 1 and boss_drop_wind == boss_drop_base)
	_check("⑦i 지상은 혼불 바람 무효 — 급수·성장·방목·카페 전부 중립",
		not Weather.waters_field(Weather.SOULWIND) and Weather.grows_crops(Weather.SOULWIND)
		and Weather.allows_grazing(Weather.SOULWIND)
		and is_equal_approx(Weather.cafe_spawn_scale(Weather.SOULWIND), 1.0))
	_check("⑦j 던전 배수는 혼불 바람 전용 — 다른 하늘은 전부 1.0",
		is_equal_approx(Weather.mob_spawn_scale(Weather.RAIN), 1.0)
		and is_equal_approx(Weather.drop_scale(Weather.SNOW), 1.0)
		and is_equal_approx(Weather.rare_drop_scale(Weather.CALM), 1.0))

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)
