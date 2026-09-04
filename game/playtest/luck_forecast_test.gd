extends SceneTree
# ★[S7-T4 / ADR-0065 결정 5·6] 명부의 운 · 점괘 거울 예보 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 롤 — 같은 day는 언제나 같은 운(결정성)·±0.10 범위·균등 분포(해시 뭉침 회귀 가드)·
#      5등급 문턱 경계값(±0.02/±0.07)이 정확히 어느 쪽으로 떨어지는가.
#   ② 배선 6지점 — 가산이 확률을 *실제로* 움직인다(가산 후 확률값 화이트박스 + 히트 수 비교).
#   ③ 골든 불변 — 운 0/무인자 호출에서 여섯 지점의 결과열이 한 비트도 안 변한다.
#   ④ 점괘 거울 — facing 판정(구역 가드 포함)·팝업 열림/닫힘·기존 집 가구와 칸 무충돌.
#   ⑤ D-1 플래그 — 절기 마지막 날(28·56·84·112) true / 그 앞뒤 false.
#   ⑥ 예보 문자열 — 오늘 운 등급 + 내일 날씨 이름 포함 · **수치는 절대 안 들어간다**.
#   ⑦ 배선 존재 가드 — main.gd가 여섯 자리에 계수를 실제로 넘긴다(인자 자리만 열고 아무도 안
#      넘기는 사고를 소스 수준에서 못 박는다. S5 사다리 `0.0` 고정이 정확히 그 사고였다).
#
# ★ 특정 등급의 날짜는 **절대 하드코딩하지 않는다**(해시 롤이라 진폭·문턱을 만지면 곧장 어긋난다).
#   _first_day_grade 헬퍼가 구간을 훑어 첫 해당 날을 찾는다 — 수치를 조정해도 테스트는 산다.
#
# 실행: ./run_tests.sh luck_forecast   (헤드리스는 반드시 game/에서 · 순차)

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

# 구간 [from, to]에서 이 등급이 처음 나오는 날(-1 = 없음). 날짜 하드코딩 금지.
func _first_day_grade(g: int, from_day: int, to_day: int) -> int:
	for d in range(from_day, to_day + 1):
		if DailyLuck.grade_for_day(d) == g:
			return d
	return -1

func _initialize() -> void:
	print("══ S7-T4 명부의 운 · 점괘 거울 검증 ══")

	# ── ① 파생 롤(순수 static — 인스턴스 불필요) ─────────────────────────────
	print("── ① 운 롤(결정성·범위·등급 경계) ──")
	var YEAR := GameClock.DAYS_PER_SEASON * 4      # 112일 = 1년
	var det_ok := true
	var range_ok := true
	var lo := 1.0
	var hi := -1.0
	for d in range(1, YEAR + 1):
		var v := DailyLuck.luck_for_day(d)
		if not is_equal_approx(v, DailyLuck.luck_for_day(d)):
			det_ok = false
		if v < -DailyLuck.SPREAD - 0.0001 or v > DailyLuck.SPREAD + 0.0001:
			range_ok = false
		lo = minf(lo, v)
		hi = maxf(hi, v)
	_check("①a 결정성 — 같은 day는 언제나 같은 운(1..112 전수)", det_ok)
	_check("①b 전 day가 ±%.2f 범위 안(실측 %.4f ~ %.4f)" % [DailyLuck.SPREAD, lo, hi], range_ok)
	_check("①c day 0·음수 = 0.0(손상 방어 — Weather와 같은 결)",
		is_zero_approx(DailyLuck.luck_for_day(0)) and is_zero_approx(DailyLuck.luck_for_day(-7)))

	# 등급 경계 — 문턱 정확값이 어느 쪽으로 떨어지는지 못 박는다(위쪽이 가져간다).
	_check("①d 경계 +0.07 = 대길(문턱 포함)", DailyLuck.grade_of(DailyLuck.T_GREAT) == DailyLuck.GREAT)
	_check("①e 경계 +0.07 바로 아래 = 길", DailyLuck.grade_of(DailyLuck.T_GREAT - 0.0001) == DailyLuck.GOOD)
	_check("①f 경계 +0.02 = 길(문턱 포함)", DailyLuck.grade_of(DailyLuck.T_GOOD) == DailyLuck.GOOD)
	_check("①g 경계 +0.02 바로 아래 = 평", DailyLuck.grade_of(DailyLuck.T_GOOD - 0.0001) == DailyLuck.PLAIN)
	_check("①h 0.0 = 평", DailyLuck.grade_of(0.0) == DailyLuck.PLAIN)
	_check("①i 경계 −0.02 = 흉(문턱 포함 — 아래쪽 등급이 가져간다)",
		DailyLuck.grade_of(-DailyLuck.T_GOOD) == DailyLuck.BAD)
	_check("①j 경계 −0.02 바로 위 = 평", DailyLuck.grade_of(-DailyLuck.T_GOOD + 0.0001) == DailyLuck.PLAIN)
	_check("①k 경계 −0.07 = 대흉(문턱 포함)", DailyLuck.grade_of(-DailyLuck.T_GREAT) == DailyLuck.TERRIBLE)
	_check("①l 경계 −0.07 바로 위 = 흉", DailyLuck.grade_of(-DailyLuck.T_GREAT + 0.0001) == DailyLuck.BAD)
	_check("①m 극단값 클램프 없이 등급만 — ±1.0도 대길·대흉",
		DailyLuck.grade_of(1.0) == DailyLuck.GREAT and DailyLuck.grade_of(-1.0) == DailyLuck.TERRIBLE)
	_check("①n 등급명 5종 · '' = 범위 밖",
		DailyLuck.grade_name(DailyLuck.GREAT) == "대길" and DailyLuck.grade_name(DailyLuck.TERRIBLE) == "대흉"
		and DailyLuck.grade_name(DailyLuck.PLAIN) == "평" and DailyLuck.grade_name(9) == ""
		and DailyLuck.grade_name(-1) == "")
	_check("①o 점괘 문구 5종이 전부 비어 있지 않다 · '' = 범위 밖",
		DailyLuck.fortune_line(0) != "" and DailyLuck.fortune_line(4) != ""
		and DailyLuck.fortune_line(9) == "")

	# ★ 분포 균일성 가드 — weather.gd가 실측으로 걸러낸 djb2 함정의 회귀 방지다. `hash(...) % N`을
	#   직접 쓰면 순차 문자열의 하위 비트가 선형으로 남아 특정 분위가 통째로 빈다("대길이 1년에
	#   한 번도 안 뜬다"). 4년(448일)에서 다섯 등급이 **전부** 나와야 한다.
	var seen := {}
	for d2 in range(1, YEAR * 4 + 1):
		seen[DailyLuck.grade_for_day(d2)] = int(seen.get(DailyLuck.grade_for_day(d2), 0)) + 1
	var all_grades := true
	var report := ""
	for g in 5:
		if not seen.has(g):
			all_grades = false
		report += "%s %d · " % [DailyLuck.grade_name(g), int(seen.get(g, 0))]
	print("     4년 등급 분포 — " + report)
	_check("①p 4년 안에 다섯 등급이 전부 나온다(rand_from_seed 믹싱 회귀 가드)", all_grades)
	# 균등 롤이면 평(폭 0.04/0.20 = 20%)보다 대길·대흉(각 0.03/0.20 = 15%)이 크게 안 벗어난다.
	var n_all := YEAR * 4
	var plain_ratio := float(int(seen.get(DailyLuck.PLAIN, 0))) / float(n_all)
	_check("①q 평 비율이 균등 기대치 20퍼센트 언저리(실측 %.1f — 뭉침 없음)" % (plain_ratio * 100.0),
		plain_ratio > 0.12 and plain_ratio < 0.30)

	# 이후 단계가 쓸 대표 날짜(전부 탐색으로 구한다 — 하드코딩 0).
	var d_great := _first_day_grade(DailyLuck.GREAT, 1, YEAR * 4)
	var d_terrible := _first_day_grade(DailyLuck.TERRIBLE, 1, YEAR * 4)
	print("     대표일 — 대길 %d(운 %.4f) · 대흉 %d(운 %.4f)"
		% [d_great, DailyLuck.luck_for_day(d_great), d_terrible, DailyLuck.luck_for_day(d_terrible)])
	_check("①r 대길·대흉 날이 실제로 존재한다(아래 단계의 전제)", d_great > 0 and d_terrible > 0)
	var luck_up := DailyLuck.luck_for_day(d_great)
	var luck_dn := DailyLuck.luck_for_day(d_terrible)

	# ── ② 배선 6지점 — 가산이 확률을 실제로 움직인다 ─────────────────────────
	print("── ② 배선 6지점 보정 실효 ──")

	# ① 사다리 — 확률 함수가 가산을 그대로 반영한다(단조성 + 정확값).
	var base_ch := MineFloors.ladder_chance(20, false, 0.0)
	var up_ch := MineFloors.ladder_chance(20, false, luck_up * DailyLuck.W_LADDER)
	var dn_ch := MineFloors.ladder_chance(20, false, luck_dn * DailyLuck.W_LADDER)
	# ★ ladder_chance는 결과를 [0,1]로 클램프한다 — 대흉 날엔 base(0.068)보다 운(−0.099)이 커서
	#   0으로 바닥을 친다. 그게 정의된 거동이므로 기대값도 같은 클램프를 태워 비교한다.
	_check("②-① 사다리 확률 = clamp(base + 운×1.0) (기준 %.4f → 대길 %.4f · 대흉 %.4f)"
		% [base_ch, up_ch, dn_ch],
		is_equal_approx(up_ch, clampf(base_ch + luck_up, 0.0, 1.0))
		and is_equal_approx(dn_ch, clampf(base_ch + luck_dn, 0.0, 1.0))
		and up_ch > base_ch and dn_ch < base_ch)
	# 실제 롤에서도 히트가 는다(같은 시드 집합·확률만 갈린 비교).
	var lad_base := 0
	var lad_up := 0
	for i in 300:
		var t := Vector2i(i % 20, i / 20)
		if MineFloors.roll_ladder(9, 5, t, 20, false, 0.0):
			lad_base += 1
		if MineFloors.roll_ladder(9, 5, t, 20, false, luck_up * DailyLuck.W_LADDER):
			lad_up += 1
	_check("②-①b 대길 날 사다리 히트가 는다(300칸 %d → %d)" % [lad_base, lad_up], lad_up > lad_base)

	# ② 지오드 개봉 2배 — 운이 double_ch에 가산돼 count==2가 는다.
	var geo_base := 0
	var geo_up := 0
	for c in 600:
		if int((MiningSkill.open_geode(ItemCatalog.GEODE_NEOKAL, c, 0.0) as Dictionary)["count"]) == 2:
			geo_base += 1
		if int((MiningSkill.open_geode(ItemCatalog.GEODE_NEOKAL, c,
				0.0 + luck_up * DailyLuck.W_GEODE) as Dictionary)["count"]) == 2:
			geo_up += 1
	_check("②-② 지오드 개봉 2배 — 퍼크 0에서도 대길 날엔 나온다(600회 %d → %d)" % [geo_base, geo_up],
		geo_base == 0 and geo_up > 0)

	# ③ 잡귀 드랍 — (base + 운) × 배수. 순서 계약까지 값으로 못 박는다.
	var mob_base := 0
	var mob_up := 0
	var mob_dn := 0
	for sd in 400:
		mob_base += MobCatalog.roll_drops(MobCatalog.NACHAL, sd).size()
		mob_up += MobCatalog.roll_drops(MobCatalog.NACHAL, sd, 1.0, 1.0,
			luck_up * DailyLuck.W_MOB_DROP).size()
		mob_dn += MobCatalog.roll_drops(MobCatalog.NACHAL, sd, 1.0, 1.0,
			luck_dn * DailyLuck.W_MOB_DROP).size()
	_check("②-③ 잡귀 드랍 — 대길↑ 대흉↓ (400시드 %d → 대길 %d · 대흉 %d)" % [mob_base, mob_up, mob_dn],
		mob_up > mob_base and mob_dn < mob_base)
	# 확정 드랍(보스 관문 보상)은 운을 안 탄다 — 대흉 날에도 그대로 나온다.
	var boss_base := MobCatalog.roll_drops(MobCatalog.BOSS_OKJOL, 5)
	var boss_dn := MobCatalog.roll_drops(MobCatalog.BOSS_OKJOL, 5, 1.0, 1.0,
		luck_dn * DailyLuck.W_MOB_DROP)
	_check("②-③b 확정 드랍은 운 면제 — 대흉 날에도 관문 보상은 그대로",
		boss_base.size() == 1 and boss_dn == boss_base)

	# ④ 벌목 보너스 — 단단한 원목·씨앗. 퍼크 0·레벨 1(씨앗 자격)로 성숙목을 벤다.
	var hw_base := _chop_trials(0.0, 1)
	var hw_up := _chop_trials(luck_up * DailyLuck.W_CHOP, 1)
	_check("②-④ 벌목 — 대길 날엔 단단한 원목·씨앗이 는다(단단 %d→%d · 씨앗 %d→%d)"
		% [hw_base["hardwood"], hw_up["hardwood"], hw_base["seeds"], hw_up["seeds"]],
		int(hw_up["hardwood"]) > int(hw_base["hardwood"]) and int(hw_up["seeds"]) > int(hw_base["seeds"]))

	# ⑤ 낚시 인양 — 퍼밀 눈금 환산 가산 + ★[폴리시 2회차] 하한 클램프.
	# 옛 배선은 대흉 날 30 + (−50) = −20‰ → `roll`의 `permil <= 0` 가지에 걸려 **인양이 통째로
	# 정지**했다. 여기서 라이브와 같은 파생(SalvageTable.clamp_permil)을 태워, 대흉에도 얇게나마
	# 살아 있다는 계약을 경계값으로 못 박는다.
	var permil_base := SalvageTable.permil_for(false)
	var permil_up := SalvageTable.clamp_permil(
		permil_base + int(roundf(luck_up * DailyLuck.W_SALVAGE * 1000.0)))
	var permil_dn := SalvageTable.clamp_permil(
		permil_base + int(roundf(luck_dn * DailyLuck.W_SALVAGE * 1000.0)))
	var permil_dn_raw := permil_base + int(roundf(luck_dn * DailyLuck.W_SALVAGE * 1000.0))
	_check("②-⑤a ★대흉 날 원값은 음수(%d‰ — 옛 결함의 재현)이고 클램프가 하한 %d‰로 받는다"
		% [permil_dn_raw, SalvageTable.MIN_PERMIL],
		permil_dn_raw <= 0 and permil_dn == SalvageTable.MIN_PERMIL)
	_check("②-⑤b 하한은 기본보다 얇다(대흉은 손해로 남는다 — 하한이 보상이 되면 안 된다)",
		SalvageTable.MIN_PERMIL > 0 and SalvageTable.MIN_PERMIL < permil_base)
	# `roll` 자체의 "끄기" 의사는 그대로 살아 있다(하한이 roll 안으로 새지 않았다는 증거 —
	# 클램프는 운이 섞이는 파생 지점 한 곳에만 있다. 라이브 단언은 fishing_skill_test ⓔ3).
	_check("②-⑤c roll의 permil ≤ 0 = 명시적 끄기(하한이 roll 안으로 새지 않았다)",
		SalvageTable.roll(1, 0) == "" and SalvageTable.roll(2, -5) == "")
	var sal_base := 0
	var sal_up := 0
	var sal_dn := 0
	for sd2 in 2000:
		if SalvageTable.roll(sd2, permil_base) != "":
			sal_base += 1
		if SalvageTable.roll(sd2, permil_up) != "":
			sal_up += 1
		if SalvageTable.roll(sd2, permil_dn) != "":
			sal_dn += 1
	_check("②-⑤ 인양 — 대길↑ 대흉↓ (2000회 %d → 대길 %d · 대흉 %d · 퍼밀 %d/%d/%d)"
		% [sal_base, sal_up, sal_dn, permil_base, permil_up, permil_dn],
		sal_up > sal_base and sal_dn < sal_base)
	_check("②-⑤e ★대흉에도 인양이 죽지 않는다(2000회 중 %d회 — 얇아질 뿐 0이 아니다)" % sal_dn,
		sal_dn > 0)

	# ⑥ 작물 다수확 — 순수 바이어스 함수. 범위를 절대 안 넘는다.
	_check("②-⑥ 다수확 상단 바이어스 — 길한 날 r이 문턱 아래면 +1",
		DailyLuck.biased_yield(2, 2, 3, 0.05, 0.01) == 3)
	_check("②-⑥b 하단 바이어스 — 흉한 날 r이 문턱 아래면 −1",
		DailyLuck.biased_yield(3, 2, 3, -0.05, 0.01) == 2)
	_check("②-⑥c 범위를 넘지 않는다 — 상단에서 더 못 오르고 하단에서 더 못 내린다",
		DailyLuck.biased_yield(3, 2, 3, 0.05, 0.01) == 3
		and DailyLuck.biased_yield(2, 2, 3, -0.05, 0.01) == 2)
	_check("②-⑥d 단수확(1~1) 작물은 통째로 면제(운이 밭 전체를 흔들지 않는다)",
		DailyLuck.biased_yield(1, 1, 1, 0.05, 0.0) == 1
		and DailyLuck.biased_yield(1, 1, 1, -0.05, 0.0) == 1)
	_check("②-⑥e r이 문턱 위면 균등 롤 그대로(바이어스는 확률이지 확정이 아니다)",
		DailyLuck.biased_yield(2, 2, 3, 0.05, 0.9) == 2)

	# ── ③ 골든 불변 — 운 0에서 여섯 지점이 한 비트도 안 변한다 ──────────────
	print("── ③ 운 0 골든 불변(무인자 호출 = 정확히 중립) ──")
	_check("③a 사다리 — 무인자 == 운 0",
		is_equal_approx(MineFloors.ladder_chance(7), MineFloors.ladder_chance(7, false, 0.0))
		and MineFloors.roll_ladder(3, 2, Vector2i(4, 4), 7)
			== MineFloors.roll_ladder(3, 2, Vector2i(4, 4), 7, false, 0.0))
	_check("③b 잡귀 드랍 — 무인자 == 배수 1.0·운 0(기존 드랍 결과열 불변)",
		MobCatalog.roll_drops(MobCatalog.NACHAL, 3)
			== MobCatalog.roll_drops(MobCatalog.NACHAL, 3, 1.0, 1.0, 0.0))
	var drops_same := true
	for sd3 in 200:
		if MobCatalog.roll_drops(MobCatalog.NACHAL, sd3) \
				!= MobCatalog.roll_drops(MobCatalog.NACHAL, sd3, 1.0, 1.0, 0.0):
			drops_same = false
	_check("③c 잡귀 드랍 200시드 전수 동일(골든)", drops_same)
	# 날씨 배수만 걸었을 때도 종전과 같다 — T3 골든이 살아 있다는 확인.
	_check("③d 날씨 배수 단독 호출이 종전과 동일(T3 골든 보존)",
		MobCatalog.roll_drops(MobCatalog.NACHAL, 11, Weather.SOULWIND_DROP, Weather.SOULWIND_RARE)
			== MobCatalog.roll_drops(MobCatalog.NACHAL, 11, Weather.SOULWIND_DROP,
				Weather.SOULWIND_RARE, 0.0))
	var chop_zero := _chop_trials(0.0, 1)
	var chop_default := _chop_trials_default(1)
	_check("③e 벌목 — 무인자 == 운 0(원목·단단·씨앗 전부 동일)",
		chop_zero["wood"] == chop_default["wood"]
		and chop_zero["hardwood"] == chop_default["hardwood"]
		and chop_zero["seeds"] == chop_default["seeds"])
	_check("③f 지오드 — 운 0 가산 == 무가산", MiningSkill.open_geode(ItemCatalog.GEODE_NEOKAL, 42, 0.0)
		== MiningSkill.open_geode(ItemCatalog.GEODE_NEOKAL, 42, 0.0 + 0.0))
	_check("③g 다수확 — 운 0이면 균등 롤 결과 그대로(어떤 r에서도)",
		DailyLuck.biased_yield(2, 2, 3, 0.0, 0.0) == 2 and DailyLuck.biased_yield(2, 2, 3, 0.0, 0.99) == 2)

	# ── ④ 점괘 거울 ─────────────────────────────────────────────────────────
	print("── ④ 점괘 거울(facing·팝업·무충돌) ──")
	var m: Node = await _spawn_main()
	_check("④a 부팅 직후 패널은 접혀 있다", not m.mirror_panel.visible)
	m._indoor = "집"
	m._target = m.MIRROR_TILE
	_check("④b 집 실내에서 거울 칸을 바라보면 facing = true", m._facing_mirror())
	m._indoor = ""
	_check("④c 구역 가드 — 밖에선 같은 좌표라도 false", not m._facing_mirror())
	m._indoor = "창고"
	_check("④d 다른 실내에서도 false(_indoor 가드)", not m._facing_mirror())
	m._indoor = "집"
	m._target = m.CHEST_TILE
	_check("④e 상자 칸을 볼 땐 false(두 기물이 안 겹친다)", not m._facing_mirror())
	m._target = m.MIRROR_TILE
	m._open_mirror()
	_check("④f F로 펼치면 패널이 뜨고 본문이 채워진다",
		m.mirror_panel.visible and m.mirror_text.text.length() > 10)
	m._close_mirror()
	_check("④g 다시 F로 접으면 닫힌다", not m.mirror_panel.visible)
	# 자리가 접는다 — 집을 나가면 저절로 덮인다(_process 배선).
	m._open_mirror()
	m._indoor = ""
	await process_frame
	_check("④h 집을 나가면 패널이 저절로 접힌다(들고 다니는 패널이 아니다)", not m.mirror_panel.visible)

	# 무충돌 — 거울 칸이 집 실내 바닥 안이고, 기존 북벽 가구·상자와 겹치지 않는다.
	var floor_rect := Rect2i(m.HOME_HOUSE_RECT.position + Vector2i(1, 1),
		m.HOME_HOUSE_RECT.size - Vector2i(2, 2))
	_check("④i 거울 칸 %s이 집 실내 바닥 %s 안" % [m.MIRROR_TILE, floor_rect],
		floor_rect.has_point(m.MIRROR_TILE))
	_check("④j 상자 칸과 다르다", m.MIRROR_TILE != m.CHEST_TILE)
	_check("④k 문 앞(진입 착지)이 아니다",
		m.MIRROR_TILE != m.HOME_HOUSE_IN_TILE and m.MIRROR_TILE != m.HOME_HOUSE_DOOR
		and m.MIRROR_TILE != m.HOME_HOUSE_DOOR_E)
	var occupied := _home_prop_footprint(m, floor_rect)
	_check("④l 기존 집 가구 %d칸(침대·벽난로·책장·화분·러그·테이블) 중 어느 것과도 안 겹친다"
		% occupied.size(), not occupied.has(m.MIRROR_TILE))
	# ★ 통행성은 **상자 칸과의 동치**로 본다. 부팅 직후 그리드는 집을 아직 실내로 안 파냈으므로
	#   절대값(비-SOLID)을 단언하면 "집에 안 들어갔다"를 잡을 뿐이다. 두 칸이 같은 북벽 행에 있으니
	#   "상자와 통행성이 같다" = "거울이 새로 막는 것이 없다"가 정확한 질문이고, 프롭 겹침 자체는
	#   바로 위 ④l이 이미 못 박았다.
	_check("④m 거울 칸 통행성 = 상자 칸과 동일(거울이 새로 막는 것 0 — 막힘 %s/%s)"
		% [m._tile_blocked(m.MIRROR_TILE), m._tile_blocked(m.CHEST_TILE)],
		m._tile_blocked(m.MIRROR_TILE) == m._tile_blocked(m.CHEST_TILE))

	# ── ⑤ D-1 절기 마지막 날 플래그 ─────────────────────────────────────────
	print("── ⑤ D-1 사멸 경고 플래그(GameClock.is_season_last_day) ──")
	_check("⑤a 절기 마지막 날 28·56·84·112 = true",
		GameClock.is_season_last_day(28) and GameClock.is_season_last_day(56)
		and GameClock.is_season_last_day(84) and GameClock.is_season_last_day(112))
	_check("⑤b 그 하루 전(27·55) = false",
		not GameClock.is_season_last_day(27) and not GameClock.is_season_last_day(55))
	_check("⑤c 그 다음 날(29·57) = false — 전환일은 새 절기 1일차다",
		not GameClock.is_season_last_day(29) and not GameClock.is_season_last_day(57))
	_check("⑤d day 1·0·음수 = false(첫날 판정과 안 겹치고 손상도 방어)",
		not GameClock.is_season_last_day(1) and not GameClock.is_season_last_day(0)
		and not GameClock.is_season_last_day(-3))
	# 첫날 판정과 정확히 상보 — 마지막 날의 다음 날은 언제나 첫날이다.
	var pair_ok := true
	for d3 in range(1, 200):
		if GameClock.is_season_last_day(d3) != GameClock.is_season_first_day(d3 + 1):
			pair_ok = false
	_check("⑤e 마지막 날 ⇔ 다음 날이 첫날(두 판정이 하루도 안 어긋난다)", pair_ok)

	# ── ⑥ 예보 문자열 ───────────────────────────────────────────────────────
	print("── ⑥ 예보 본문 구성 ──")
	m.clock.day = d_great
	var txt_great: String = m._mirror_forecast_text()
	print("     [대길 예보]\n" + txt_great)
	_check("⑥a 오늘 운 등급명이 들어간다", txt_great.contains("대길"))
	_check("⑥b 점괘 한 줄이 들어간다", txt_great.contains(DailyLuck.fortune_line(DailyLuck.GREAT)))
	_check("⑥c 내일 날씨 이름이 들어간다(100% 확정 예보)",
		txt_great.contains(Weather.name_of(m._forecast_on(d_great))))
	# ★ 수치 노출 0 — 본문 어디에도 운의 숫자가 없다(CONTEXT [명부의 운] "내부 연산은 숨김").
	# ⚠️ **원본값에 `%d`를 쓰지 않는다**(S7-T7에서 오탐으로 드러난 자리): 운은 언제나 −0.1~+0.1이라
	#   `"%d" % v2`가 항상 "0"(또는 "-0")으로 퇴화해, 사실상 "본문에 숫자 0이 있으면 실패"라는 뜻이
	#   된다. 점괘 거울에 행사 예고("20일 뒤: …")가 붙자 그 0에 걸렸다 — 운 값은 어디에도 안 떴는데도.
	# ⚠️⚠️ **★[폴리시 R15] ×100 표기의 `%d`도 같은 함정이었다**(그 자리가 HEAD에서 상시 적색이었다):
	#   `"%d" % (v2*100.0)`는 그냥 한두 자리 정수 문자열이고, ◇예고 네 줄은 날짜 카운트다운을 **항상**
	#   싣는다(`Peddler.APPEAR_MODULUS == 7`이라 day 1이면 "6일 뒤"가 확정). trunc(luck×100)이 그
	#   날짜와 겹치기만 하면 운이 한 글자도 안 떴는데 실패했고, |luck|<0.01인 날(확률 10%)은 "0"으로
	#   퇴화해 "10일 뒤"·"20일 뒤"에 걸렸다. 그래서 **자릿수 목록을 못 박는 방식 자체를 버린다**:
	#   ◇예고 줄(날짜가 정상적으로 드는 유일한 층)을 걷어낸 나머지 — 머리·fortune_text·날씨 줄·
	#   D-1 경고 — 는 넷 다 수치를 안 담는 것이 계약이므로 **숫자가 한 글자도 없어야 한다**.
	#   어떤 자리수·어떤 표기(백분율·소수·괄호 병기)로 운이 새도 반드시 red가 되고, 예고 줄이 몇
	#   개 붙든 어떤 날짜를 싣든 영향을 안 받는다(퇴화 불가능).
	var numeric_leak := false
	var leak_where := ""
	var scanned_lines := 0
	for d4 in [d_great, d_terrible, 1, 28, 56]:
		m.clock.day = int(d4)
		var t2: String = m._mirror_forecast_text()
		for raw_line in t2.split("\n"):
			var line := String(raw_line)
			if line.begins_with("◇"):
				continue                                   # 예고 줄 = 날짜 층(숫자가 정상)
			if line.strip_edges() == "":
				continue
			scanned_lines += 1
			for ci in range(line.length()):
				var ch := line[ci]
				if ch >= "0" and ch <= "9":
					numeric_leak = true
					if leak_where == "":
						leak_where = "day %d — %s" % [int(d4), line]
	# 비어 있음 가드 — 예고 줄을 걷어낸 뒤에도 잴 본문이 남아야 검사가 하중을 받는다(표본 5일 ×
	# 최소 머리·운 2줄·날씨 1줄).
	_check("⑥d-pre 예고 줄을 걷어낸 본문이 남는다(검사가 공허하지 않다) — 실측 %d줄" % scanned_lines,
		scanned_lines >= 5 * 4)
	_check("⑥d 수치 노출 0 — 예고 줄 밖 본문에 숫자가 한 글자도 없다(등급·문구만)%s"
		% ("" if leak_where == "" else " ← 누출: " + leak_where), not numeric_leak)
	# D-1 경고 — 절기 마지막 날에만 뜬다.
	m.clock.day = 28
	var txt_last: String = m._mirror_forecast_text()
	m.clock.day = 27
	var txt_prev: String = m._mirror_forecast_text()
	_check("⑥e 절기 마지막 날엔 사멸 경고가 뜬다",
		txt_last.contains("절기가 바뀐다") and txt_last.contains("스러진다"))
	_check("⑥f 그 하루 전엔 경고가 없다(D-1 딱 하루)", not txt_prev.contains("절기가 바뀐다"))
	# 전 등급·전 절기에서 본문이 깨지지 않는다(빈 줄·범위 밖 이름 0).
	var text_ok := true
	for d5 in range(1, 113):
		m.clock.day = d5
		var t3: String = m._mirror_forecast_text()
		if t3.length() < 20 or t3.contains("— \n") or t3.contains("명부의 운 — \n"):
			text_ok = false
	_check("⑥g 1..112 전수에서 본문이 안 깨진다(빈 등급명·빈 날씨명 0)", text_ok)

	# ── ⑦ 배선 존재 가드(소스 수준) ─────────────────────────────────────────
	print("── ⑦ main.gd가 여섯 자리에 계수를 실제로 넘긴다 ──")
	# ★ 왜 소스를 읽나: "인자 자리만 열고 아무도 안 넘긴다"가 이 프로젝트에서 실제로 났던 사고다
	#   (S5 사다리 `luck_bonus` 자리가 `0.0` 고정으로 두 슬라이스를 잤다). 순수 함수 단언만으론
	#   그 사고가 안 잡혀서, 호출부가 계수를 넘기는지 자체를 못 박는다.
	var src := FileAccess.get_file_as_string("res://main.gd")
	_check("⑦a main.gd를 읽었다", src.length() > 1000)
	for w in [["W_LADDER", "①사다리"], ["W_GEODE", "②지오드"], ["W_MOB_DROP", "③잡귀 드랍"],
			["W_CHOP", "④벌목"], ["W_SALVAGE", "⑤인양"], ["W_CROP", "⑥다수확"]]:
		_check("⑦ %s — main.gd가 DailyLuck.%s를 넘긴다" % [w[1], w[0]],
			src.contains("DailyLuck." + String(w[0])))
	# 사다리는 두 무대(갱도·나락) 모두 배선돼야 한다.
	_check("⑦b 사다리 계수가 두 번 쓰인다(갱도 + 나락)", src.count("DailyLuck.W_LADDER") >= 2)
	# 옛 `0.0` 고정 인자가 남아 있지 않다.
	_check("⑦c 옛 `_mobs_cleared(), 0.0` 고정 인자가 사라졌다",
		not src.contains("_mobs_cleared(), 0.0"))
	# _luck_bonus 헬퍼가 계수를 그대로 태운다.
	m.clock.day = d_great
	_check("⑦d _luck_bonus(계수) == luck_for_day × 계수",
		is_equal_approx(m._luck_bonus(DailyLuck.W_LADDER), luck_up)
		and is_equal_approx(m._luck_bonus(DailyLuck.W_CROP), luck_up * 0.5))

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)

# ── 헬퍼 ──────────────────────────────────────────────────────────────────────
# 성숙목 N그루를 끝까지 베어 산출을 합산한다(운 인자만 갈린 비교용). 퍼크 0 · 레벨은 씨앗 자격.
func _chop_trials(luck: float, level: int) -> Dictionary:
	var led := TreeLedger.new()
	var tiles: Array = []
	for i in 60:
		tiles.append(Vector2i(i % 10, i / 10))
	led.seed_region("T", tiles, TreeLedger.MAX_STAGE)
	var out := {"wood": 0, "hardwood": 0, "seeds": 0}
	for t: Vector2i in tiles:
		for _h in TreeLedger.HP_MATURE:
			var r: Dictionary = led.chop("T", t, 7, level, 0, 0.0, 0, luck)
			out["wood"] = int(out["wood"]) + int(r.get("wood", 0))
			out["hardwood"] = int(out["hardwood"]) + int(r.get("hardwood", 0))
			out["seeds"] = int(out["seeds"]) + int(r.get("seeds", 0))
	return out

# 위와 같되 **운 인자를 아예 안 넘긴다**(무인자 호출 골든 비교용).
func _chop_trials_default(level: int) -> Dictionary:
	var led := TreeLedger.new()
	var tiles: Array = []
	for i in 60:
		tiles.append(Vector2i(i % 10, i / 10))
	led.seed_region("T", tiles, TreeLedger.MAX_STAGE)
	var out := {"wood": 0, "hardwood": 0, "seeds": 0}
	for t: Vector2i in tiles:
		for _h in TreeLedger.HP_MATURE:
			var r: Dictionary = led.chop("T", t, 7, level, 0, 0.0, 0)
			out["wood"] = int(out["wood"]) + int(r.get("wood", 0))
			out["hardwood"] = int(out["hardwood"]) + int(r.get("hardwood", 0))
			out["seeds"] = int(out["seeds"]) + int(r.get("seeds", 0))
	return out

# 집 실내 바닥 안의 기존 프롭이 물고 있는 칸 집합(앵커 + 텍스처 폭). 거울 자리 충돌 판정용.
func _home_prop_footprint(m: Node, floor_rect: Rect2i) -> Dictionary:
	var out := {}
	out[m.CHEST_TILE] = true                       # 상자는 레이아웃 밖(좌표 상수)이라 손으로 넣는다
	for entry: Array in m.PROP_LAYOUT_HOME:
		var tex: Texture2D = entry[0]
		var w: int = maxi(int(tex.get_width()) / m.TILE, 1)
		for a: Vector2i in entry[1]:
			if not floor_rect.has_point(a):
				continue                           # 실외·타 건물 프롭은 대상 밖
			for dx in w:
				out[a + Vector2i(dx, 0)] = true
	return out
