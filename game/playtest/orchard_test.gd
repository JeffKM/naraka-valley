extends SceneTree

# ★ [S1-5b / greybox-spec §7] 혼의 나무 과수(혼백도 end-to-end) 격리 검증.
#
# 무엇을 보나(S1-5b = 3×3 심기 + 28일 성숙 + 제철 결실 + 절기 영속 + 품질=나이):
#   ① 심기 판정 — 유효 3×3 성공 / 막힌 칸(is_blocked) 거부 / 타 나무 풋프린트 교차 거부.
#   ② 성숙(순수 달력) — 나이<28 미성숙 / 나이≥28 성숙(물주기 무관).
#   ③ 제철 결실 순환 왕복 — 3a 제철 매일 +1·cap / 3b 비제철 정지(count 고정, ★음성 가드) /
#      3c 다음 해 제철 재진입(day 113·225 재개) / ⑥★ 제철 내부 수확 후 재결실(수확이 루프 미파괴).
#   ④ 영속 — 여러 절기 경계를 넘겨도 나무 생존·나이 계속 증가·사멸 0.
#   ⑤ 나이별 품질 — quality_tier_for_age 경계(28→0·56→1·84→2·112→3·clamp).
#   ⑥ 수확 — 성숙+결실 시 전량 회수·0 리셋·나이서 tier 산출.
#   ⑦ 세이브 왕복 + ★절기 경계 결착 — 로드 직후 첫 틱이 day에서 절기를 무상태 재계산(유령과일 차단).
#   ⑧ (main 통합) _orchard_body 밑동 1칸만 SOLID(수관 통과 = 3×3 벽 아님).
#   ⑨ (main 통합) GameClock.season_index_for_day CONTEXT 정합(0=피안·1=유화·2=망연·3=성야).
#
# Part A(①~⑦)는 Orchard 단위(main 불필요), Part B(⑧⑨)만 main 스폰(trellis_test 결).
# 절기 판정은 day를 넘겨 무상태 재계산(ADR-0045). 좀비 방지: 끝에 quit(). run_tests 워치독.

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

func _initialize() -> void:
	print("▶ orchard_test (S1-5b)")
	var HB := FruitTreeCatalog.HONBAEKDO   # 혼백도 — season0(피안)·mature28·cap3
	var open := func(_t: Vector2i) -> bool: return false   # 막힘 없는 열린 밭(is_blocked mock)

	# ── ① 심기 판정(§7.4) ──
	var orch := Orchard.new()
	var a := Vector2i(10, 10)
	_check("① 유효 3×3 심기 성공", orch.plant(a, HB, 1, open) and orch.has_tree(a))
	# 막힌 칸이 풋프린트에 있으면 거부.
	var blocked: Dictionary = {Vector2i(20, 21): true}
	var is_blocked := func(t: Vector2i) -> bool: return blocked.has(t)
	_check("① 막힌 칸 포함 풋프린트 심기 거부", not orch.plant(Vector2i(20, 20), HB, 1, is_blocked))
	# 타 나무 풋프린트 교차 거부(체비쇼프 ≤2). (11,10)·(12,10)=교차 / (13,10)=간격 확보.
	_check("① 인접(dx1) 나무 겹침 거부", not orch.plant(Vector2i(11, 10), HB, 1, open))
	_check("① 인접(dx2) 나무 겹침 거부", not orch.plant(Vector2i(12, 10), HB, 1, open))
	_check("① 간격(dx3) 나무 심기 성공", orch.plant(Vector2i(13, 10), HB, 1, open))
	# 미지 종 거부.
	_check("① 미지 종 심기 거부", not orch.plant(Vector2i(30, 30), "ghost_fruit", 1, open))

	# ── ② 성숙(순수 달력, 물주기 무관) — planted_day=1 나무(a) ──
	_check("② 나이27(day28) 미성숙", not orch.is_mature(a, 28))
	_check("② 나이28(day29) 성숙", orch.is_mature(a, 29))
	_check("② 성숙 판정에 물주기 개입 없음(달력만)", orch.age_of(a, 29) == 28)

	# ── ③ 제철 결실 순환 왕복(§7.5) — a는 day1 심음, 첫 제철 결실 = 다음 피안절(day113~140) ──
	# (day1 심어 day29 성숙 시점은 유화절 → 첫 피안절엔 못 열고 이듬해 피안절에 첫 결실 = 과수 정합.)
	_check("③ 비제철·미성숙 구간(day100) 결실 0", orch.fruit_count_of(a) == 0)
	orch.advance_day(113)   # 다음 해 피안절 1일 = mature(age112)+season0
	_check("③a 다음 해 제철 진입 결실 재개(count1)", orch.fruit_count_of(a) == 1)
	orch.advance_day(114)
	orch.advance_day(115)
	_check("③a 제철 매일 +1 축적(count3)", orch.fruit_count_of(a) == 3)
	orch.advance_day(116)
	_check("③a cap=3 정지", orch.fruit_count_of(a) == 3)

	# ── ⑥ 수확 + 제철 내부 수확 후 재결실(§7.6) ──
	var picked := orch.harvest(a, 116)   # 성숙+count3 → 전량, 나이=115
	_check("⑥ 수확 반환 count=3", int(picked.get("count", 0)) == 3)
	_check("⑥ 수확 반환 fruit_id=혼백도", picked.get("fruit_id", "") == HB)
	_check("⑥ 수확 후 count 0 리셋", orch.fruit_count_of(a) == 0)
	_check("⑥ 수확 quality_tier 산출(나이115→3)", int(picked.get("quality_tier", -1)) == 3)
	orch.advance_day(117)   # 여전히 피안절(≤140) → 재결실
	_check("⑥★ 제철 내부 수확 후 재결실(day117 count1)", orch.fruit_count_of(a) == 1)

	# ── ③b 비제철 결실 정지(★음성 가드) — count 고정(cap 아닌 값에서) ──
	orch.advance_day(141)   # 유화절(day141) — 성숙·미cap이지만 비제철 → 증가 0
	_check("③b 비제철 진입 결실 정지(count 고정1)", orch.fruit_count_of(a) == 1)
	orch.advance_day(142)   # 유화절 계속 → 여전히 정지
	_check("③b 비제철 지속 정지(count 고정1)", orch.fruit_count_of(a) == 1)

	# ── ③c 다음 해 제철 재진입(순환) ──
	orch.advance_day(225)   # year3 피안절 1일 = mature+season0 → 재개
	_check("③c 이듬해 제철 재진입 결실 재개(count2)", orch.fruit_count_of(a) == 2)

	# ── ④ 영속 — 여러 절기 경계(113/141/225) 넘겨도 생존·나이 증가·사멸 0 ──
	_check("④ 절기 경계 다수 넘겨도 나무 생존", orch.has_tree(a))
	_check("④ 나이 계속 증가(day225 → 224)", orch.age_of(a, 225) == 224)

	# ── ⑤ 나이별 품질(§7.7) — 순수 함수 경계 ──
	_check("⑤ qtier(28)=0", orch.quality_tier_for_age(28) == 0)
	_check("⑤ qtier(55)=0", orch.quality_tier_for_age(55) == 0)
	_check("⑤ qtier(56)=1", orch.quality_tier_for_age(56) == 1)
	_check("⑤ qtier(84)=2", orch.quality_tier_for_age(84) == 2)
	_check("⑤ qtier(112)=3", orch.quality_tier_for_age(112) == 3)
	_check("⑤ qtier(140)=3(clamp 상한)", orch.quality_tier_for_age(140) == 3)
	_check("⑤ qtier(10)=0(clamp 하한)", orch.quality_tier_for_age(10) == 0)

	# ── ⑦ 세이브 왕복 + ★절기 경계 결착 ──
	# planted_day=85(성야절) 나무 → day113 성숙(피안). day140(피안·성숙)에 결실 1 만든 뒤 세이브,
	# 로드한 나무를 day141(유화·비제철)로 틱 → 로드 직후 첫 틱이 유령과일을 안 만드는지(무상태 재계산).
	var orch2 := Orchard.new()
	var b := Vector2i(5, 5)
	orch2.plant(b, HB, 85, open)
	orch2.advance_day(140)   # 피안절·성숙(age55) → count1
	_check("⑦ 세이브 전 결실 1", orch2.fruit_count_of(b) == 1)
	var blob := orch2.to_save()
	var orch3 := Orchard.new()
	orch3.load_save(blob)
	_check("⑦ 세이브 왕복 나무 복원", orch3.has_tree(b))
	_check("⑦ 세이브 왕복 결실 상태 보존(1)", orch3.fruit_count_of(b) == 1)
	_check("⑦ 세이브 왕복 나이 파생 보존(day141→56)", orch3.age_of(b, 141) == 56)
	orch3.advance_day(141)   # ★ 로드 후 첫 틱 = 유화절(비제철) → 증가 0(유령과일 차단)
	_check("⑦★ 로드-틱 절기 경계 결착(비제철 즉시 반영·count 고정1)", orch3.fruit_count_of(b) == 1)

	# ── Part B: main 통합(⑧⑨) ──
	var m := await _spawn_main()
	# ⑨ 절기 유도 CONTEXT 정합(static — main 무관하지만 부팅 정합 확인 겸).
	_check("⑨ season(day1)=0 피안", GameClock.season_index_for_day(1) == 0)
	_check("⑨ season(day29)=1 유화", GameClock.season_index_for_day(29) == 1)
	_check("⑨ season(day57)=2 망연", GameClock.season_index_for_day(57) == 2)
	_check("⑨ season(day85)=3 성야", GameClock.season_index_for_day(85) == 3)
	_check("⑨ season(day113)=0 피안(순환)", GameClock.season_index_for_day(113) == 0)
	# ⑧ 안식 농원에서 유효 3×3 앵커를 찾아 심고 밑동 1칸 충돌만 서는지(수관 통과).
	var anchor := Vector2i(-1, -1)
	for y in range(1, m._grid_h - 1):
		for x in range(1, m._grid_w - 1):
			var ok := true
			for t in Orchard.footprint_of(Vector2i(x, y)):
				if m._is_tree_blocked(t):
					ok = false
					break
			if ok:
				anchor = Vector2i(x, y)
				break
		if anchor.x >= 0:
			break
	_check("⑧ 안식 농원에 유효 3×3 앵커 존재", anchor.x >= 0)
	var planted: bool = m.orchard.plant(anchor, HB, m.clock.day, m._is_tree_blocked)
	await process_frame
	_check("⑧ 나무 심기 성공", planted and m.orchard.has_tree(anchor))
	_check("⑧ _orchard_body 충돌 밑동 1칸만(3×3 벽 아님)", m._orchard_body.get_child_count() == 1)
	m.queue_free()
	await process_frame

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
