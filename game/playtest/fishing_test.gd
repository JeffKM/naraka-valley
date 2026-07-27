extends SceneTree

# ★[S3-T2 / ADR-0061 결정 2·6·9] 릴 격투 코어(FishingSession) + main 배선 결정적 검증.
#
# 무엇을 보나:
#   ⓐ 상태 전이 사슬 — IDLE→CASTING→WAITING→BITE→FIGHT→LANDED(소 체급은 계속 당기면 이긴다).
#   ⓑ 줄 끊김 — 발버둥 중에도 계속 당기면 텐션이 100에 닿아 ESCAPED(중 체급은 풀기를 강제).
#   ⓒ 퍼펙트 릴 — 발버둥 시작 창(0.3s) 안에 '풀기'로 전환 성공/실패(크리 카운트).
#   ⓓ 체급 게이트 — T1 낚싯대(허용=소)로 대어를 걸면 후킹 직후 끊김 확정(line_broke_by_class).
#   ⓔ 혼력(결정 6) — 체급별 값(4/8/14/30)·후킹 순간 1회 소모·끊겨도 소모 유지·부족 시 후킹 불가.
#   ⓕ 결정성 — 같은 시드 + 같은 입력열 = 같은 결과(헤드리스 게이트의 전제).
#   ⓖ 세이브 무간섭 — 세션은 비영속(세이브 dict에 낚시 키 0·저장/로드 왕복해도 어획물만 남음).
#   ⓗ main 배선 — 캐스팅 무대 한정(결정 9)·물 판정(잔교/부두/강둑 너머)·T1 임시 지급·어획물 카탈로그.
#
# FishingSession은 RefCounted 순수 클래스라 ⓐ~ⓓ·ⓕ는 씬 없이 new()로 돈다(첫 미니게임의 구조 배당금).
# ⓔ·ⓖ·ⓗ만 main.tscn을 띄운다(혼력·인벤·세이브·지형이 필요).
# 좀비 방지: 모든 단언 뒤 quit(). run_tests.sh 워치독과 함께.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# ── 공용 드라이버 ────────────────────────────────────────────────────────────
# 기본 조작기: 입질 창·격투에서 계속 '당김'(홀드). 방문한 상태열을 반환한다.
func _run_holding(sess: FishingSession, secs_cap := 30.0, step := 0.05) -> Array:
	var seen: Array = [sess.state]
	var t := 0.0
	while sess.is_active() and t < secs_cap:
		var reeling: bool = sess.state == FishingSession.State.BITE \
			or sess.state == FishingSession.State.FIGHT
		sess.tick(step, reeling)
		t += step
		if seen.back() != sess.state:
			seen.append(sess.state)
	return seen

# ★[S3-T4] 안전 리듬 조작기 — 텐션이 안전선 아래이고 발버둥이 아닐 때만 당긴다(플레이어가 배우는
# "당기고 풀기"의 최소 지능형 재현). 체급 게이트를 넘긴 대어를 실제로 건져 올릴 수 있는지 볼 때 쓴다.
func _run_smart(sess: FishingSession, safe := 50.0, secs_cap := 45.0, step := 0.05) -> void:
	var t := 0.0
	while sess.is_active() and t < secs_cap:
		var reeling: bool = sess.state == FishingSession.State.BITE \
			or (sess.state == FishingSession.State.FIGHT and sess.tension < safe and not sess.is_bursting())
		sess.tick(step, reeling)
		t += step

# ★[S3-T4] 입질(BITE)까지 걸린 시간(초). 미끼의 대기 단축을 계측한다(같은 시드끼리만 비교할 것).
func _secs_to_bite(sess: FishingSession, secs_cap := 30.0, step := 0.05) -> float:
	sess.cast()
	var t := 0.0
	while sess.is_active() and sess.state != FishingSession.State.BITE and t < secs_cap:
		sess.tick(step, false)
		t += step
	return sess.elapsed

# ★[S3-T4] 격투에서 n틱 동안 계속 당겼을 때의 텐션(끊김 전 구간만 — 태클 감쇠의 직접 계측).
func _tension_after_holding(sess: FishingSession, ticks: int, step := 0.05) -> float:
	sess.cast()
	_advance_to_fight(sess, 30.0, step)
	for _i in ticks:
		sess.tick(step, true)
	return sess.tension

# ★[S3-T4] 인벤토리 전체 비우기(기어 배선 검증 전용 — 슬롯 16칸 경합을 없애고 보유 상태를 통제한다).
func _wipe_inventory(m: Node) -> void:
	for i in range(m.inventory.slots.size()):
		m.inventory.slots[i] = null
	m.inventory.select(0)
	m.inventory.changed.emit()

# FIGHT 진입까지만 굴린다(그 뒤 격투 입력을 테스트가 직접 조종하려고). 실패 시 false.
func _advance_to_fight(sess: FishingSession, secs_cap := 30.0, step := 0.05) -> bool:
	var t := 0.0
	while sess.is_active() and sess.state != FishingSession.State.FIGHT and t < secs_cap:
		sess.tick(step, sess.state == FishingSession.State.BITE)
		t += step
	return sess.state == FishingSession.State.FIGHT

# ── main 헬퍼(well_test 관례 그대로) ─────────────────────────────────────────
func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

# 든 도구 선택(없으면 인벤 넣고 그 슬롯 선택 — 유니크 도구는 idempotent).
func _select(m: Node, id: String) -> void:
	m.inventory.add_item(id, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

# 플레이어를 이 칸에 세우고 그 칸에서 겨눈 대상 칸을 지정한다(_update_target 우회 — 커서 없는 헤드리스).
func _stand_and_aim(m: Node, stand: Vector2i, aim: Vector2i) -> void:
	m.player.position = m._tile_center_px(stand)
	m._target = aim

func _find_tile(m: Node, id: int) -> Vector2i:
	for y in range(m._outdoor_h):
		for x in range(m._grid_w):
			if m._grid[y][x] == id:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _initialize() -> void:
	print("══ 릴 격투(FishingSession) 코어 검증 [S3-T2] ══")
	const S := FishingSession.State
	const WC := FishingSession.WeightClass

	# ── ⓞ 그레이박스 수치 계약(프리셋 4종 — 스펙카드 잠금값) ──
	_check("⓪ 체급 프리셋 4종(소·중·대·전설)", FishingSession.CLASS_PRESETS.size() == 4)
	_check("⓪ 혼력 = 소4·중8·대14·전설30 (ADR-0061 결정 6)",
		FishingSession.base_energy_for_class(WC.SMALL) == 4
		and FishingSession.base_energy_for_class(WC.MEDIUM) == 8
		and FishingSession.base_energy_for_class(WC.LARGE) == 14
		and FishingSession.base_energy_for_class(WC.LEGEND) == 30)
	_check("⓪ T1 낚싯대 허용 체급 = 소(줄 강도 게이트의 축)",
		int(FishingSession.ROD_T1["max_class"]) == WC.SMALL)
	# 밸런스 불변식: 소는 계속 당겨도 이기고(스태미나 소진 < 끊김), 중 이상은 끊김이 먼저 온다.
	var balance_ok := true
	for i in range(FishingSession.CLASS_PRESETS.size()):
		var p: Dictionary = FishingSession.CLASS_PRESETS[i]
		var t_land: float = float(p["stamina"]) / float(p["stamina_drain"])   # 계속 당길 때 포획까지(초)
		var t_break: float = FishingSession.TENSION_MAX / float(p["tension_rise"])  # 계속 당길 때 끊김까지(초)
		var expect_land := i == WC.SMALL
		if (t_land < t_break) != expect_land:
			balance_ok = false
	_check("⓪ 밸런스 불변식 — 소만 '계속 당기기'로 이긴다(중 이상은 끊김이 먼저)", balance_ok)

	# ── ⓐ 상태 전이 사슬(소 체급 · T1 낚싯대 · 계속 당김 → 포획) ──
	var a := FishingSession.new(20260727, {"weight_class": WC.SMALL})
	_check("ⓐ 생성 직후 = IDLE", a.state == S.IDLE)
	_check("ⓐ cast() = true(IDLE에서만)", a.cast() and a.state == S.CASTING)
	_check("ⓐ 이미 캐스팅 중이면 cast() = false(중복 방어)", not a.cast())
	var chain := _run_holding(a)
	_check("ⓐ 전이 사슬 = CASTING→WAITING→BITE→FIGHT→LANDED",
		chain == [S.CASTING, S.WAITING, S.BITE, S.FIGHT, S.LANDED])
	_check("ⓐ 결과 = 포획(landed) · 끊김 플래그 0",
		bool(a.result()["landed"]) and not a.line_broke and not a.line_broke_by_class
		and not a.missed_bite)
	_check("ⓐ 대기 구간은 혼력 0 — 결과 비용은 소 체급 4", int(a.result()["energy_cost"]) == 4)
	var a_elapsed_before: float = a.elapsed
	a.tick(1.0, true)
	_check("ⓐ 종착 상태에선 tick 무동작(멱등)", is_equal_approx(a.elapsed, a_elapsed_before))

	# 입질 창을 그냥 흘리면 놓침(당기지 않음 → ESCAPED · 혼력 소모 0).
	var a2 := FishingSession.new(20260727, {"weight_class": WC.SMALL})
	a2.cast()
	var t2 := 0.0
	while a2.is_active() and t2 < 30.0:
		a2.tick(0.05, false)      # 한 번도 안 당긴다
		t2 += 0.05
	_check("ⓐ 입질 창을 흘리면 ESCAPED(missed_bite) — 격투 미진입",
		a2.state == S.ESCAPED and a2.missed_bite and not a2.line_broke)

	# ── ⓑ 줄 끊김(중 체급 · 줄 강도 충분 · 계속 당김 → 텐션 100) ──
	var b := FishingSession.new(777, {"weight_class": WC.MEDIUM}, {"max_class": WC.MEDIUM})
	b.cast()
	var b_chain := _run_holding(b)
	_check("ⓑ 중 체급 계속 당김 = ESCAPED(줄 끊김)", b.state == S.ESCAPED and b.line_broke)
	_check("ⓑ 체급 게이트 끊김은 아님(줄 강도는 충분했다)", not b.line_broke_by_class)
	_check("ⓑ 끊김 시 텐션 = 상한 도달", b.tension >= FishingSession.TENSION_MAX)
	_check("ⓑ 끊김이어도 격투에는 들어갔다(FIGHT 경유)", b_chain.has(S.FIGHT))
	_check("ⓑ 결과 = 미포획", not bool(b.result()["landed"]))

	# ── ⓒ 퍼펙트 릴(발버둥 시작 창 안에 '풀기' 전환) ──
	# 텐션·스태미나를 길게 잡아(주입 파라미터) 창 판정만 격리 관찰한다.
	var soft := {"weight_class": WC.MEDIUM, "stamina": 999.0, "tension_rise": 4.0,
		"burst_period": 1.0, "burst_len": 1.0}
	var c := FishingSession.new(31337, soft, {"max_class": WC.MEDIUM})
	c.cast()
	_check("ⓒpre FIGHT 진입", _advance_to_fight(c))
	var guard := 0
	while not c.is_bursting() and c.is_active() and guard < 200:
		c.tick(0.05, true)        # 당기며 발버둥을 기다린다
		guard += 1
	_check("ⓒpre 발버둥 시작 감지 + 퍼펙트 창 열림", c.is_bursting() and c.is_perfect_window())
	var stam_before: float = c.fish_stamina
	c.tick(0.05, false)           # ★ 창 안에서 '풀기'로 전환 → 퍼펙트
	_check("ⓒ 창 안 풀기 전환 = 퍼펙트 릴 성공(카운트 +1)", c.perfect_count == 1)
	_check("ⓒ 퍼펙트 = 스태미나 추가 삭감(크리)",
		c.fish_stamina < stam_before - FishingSession.PERFECT_STAMINA_CUT * 0.5)
	_check("ⓒ 퍼펙트 플래시(HUD 연출 훅) 점등", c.perfect_flash())

	# 실패 케이스: 같은 조건에서 창 내내 계속 당기면 크리 0.
	var c2 := FishingSession.new(31337, soft, {"max_class": WC.MEDIUM})
	c2.cast()
	_advance_to_fight(c2)
	var guard2 := 0
	while not c2.is_bursting() and c2.is_active() and guard2 < 200:
		c2.tick(0.05, true)
		guard2 += 1
	for i in 12:                  # 0.6s > 퍼펙트 창(0.3s) 동안 계속 당김
		c2.tick(0.05, true)
	_check("ⓒ 창을 놓치면 퍼펙트 0(크리 미발생)", c2.perfect_count == 0)
	# 발버둥 시작 시점에 이미 풀고 있었다면 '풀 것'이 없다 = 퍼펙트 대상 아님(공짜 크리 방지).
	var c3 := FishingSession.new(31337, soft, {"max_class": WC.MEDIUM})
	c3.cast()
	_advance_to_fight(c3)
	var guard3 := 0
	while not c3.is_bursting() and c3.is_active() and guard3 < 200:
		c3.tick(0.05, false)      # 내내 풀고만 있음
		guard3 += 1
	for i in 12:
		c3.tick(0.05, false)
	_check("ⓒ 내내 풀고만 있으면 퍼펙트 0(공짜 크리 없음)", c3.perfect_count == 0)

	# ── ⓓ 체급 게이트(T1 낚싯대 = 소 허용 · 대어를 걸면 확정 끊김) ──
	var d := FishingSession.new(99, {"weight_class": WC.LARGE}, FishingSession.ROD_T1)
	d.cast()
	_check("ⓓpre 후킹은 된다(FIGHT 진입 — 끊김은 그 직후 확정)", _advance_to_fight(d))
	_check("ⓓ 후킹 즉시 체급 게이트 확정(line_broke_by_class)", d.line_broke_by_class)
	var d_chain := _run_holding(d)
	_check("ⓓ 짧은 격투 뒤 ESCAPED", d.state == S.ESCAPED and d.line_broke)
	_check("ⓓ 체급 끊김은 입력과 무관(연출 길이 ≈ CLASS_BREAK_SECS)",
		d.elapsed > 0.0 and d_chain.back() == S.ESCAPED)
	_check("ⓓ 대어 혼력 비용 = 14(끊겨도 계약은 그 값)", int(d.result()["energy_cost"]) == 14)
	# 대조: 같은 T1 낚싯대라도 소 체급이면 게이트 미발동.
	var d2 := FishingSession.new(99, {"weight_class": WC.SMALL}, FishingSession.ROD_T1)
	d2.cast()
	_advance_to_fight(d2)
	_check("ⓓ 대조 — 소 체급은 T1로 게이트 미발동", not d2.line_broke_by_class)
	# 풀린 낚싯대(T4 상당)면 전설도 게이트 통과.
	var d3 := FishingSession.new(99, {"weight_class": WC.LEGEND}, {"max_class": WC.LEGEND})
	d3.cast()
	_advance_to_fight(d3)
	_check("ⓓ 허용 체급을 키우면 전설도 게이트 통과", not d3.line_broke_by_class)

	# ── ⓔ-1 혼력 게이트(순수 클래스 층 — 주입 Callable 계약) ──
	var refused := FishingSession.new(555, {"weight_class": WC.SMALL})
	refused.hook_gate = func() -> bool: return false
	refused.cast()
	var re_t := 0.0
	while refused.is_active() and re_t < 30.0:
		refused.tick(0.05, refused.state == S.BITE or refused.state == S.FIGHT)
		re_t += 0.05
	_check("ⓔ1 후킹 게이트 거절 = 후킹 불가(ESCAPED·hook_refused)",
		refused.state == S.ESCAPED and refused.hook_refused and refused.missed_bite)
	_check("ⓔ1 거절이면 격투 미진입(텐션 0)", is_equal_approx(refused.tension, 0.0))
	# 스킬 절감 훅(S3-T6 자리) — energy_factor가 비용에 곱해진다(하한 1).
	var cheap := FishingSession.new(1, {"weight_class": WC.LARGE}, {}, {"energy_factor": 0.5})
	_check("ⓔ1 스킬 절감 훅 — energy_factor 0.5 → 대어 14→7", cheap.energy_cost() == 7)
	var neutral := FishingSession.new(1, {"weight_class": WC.LARGE})
	_check("ⓔ1 기본 훅은 정확히 중립(보정 0)", neutral.energy_cost() == 14)

	# ── ⓕ 결정성(같은 시드 + 같은 입력열 = 같은 결과) ──
	var script_fish := {"weight_class": WC.MEDIUM}
	var runs: Array = []
	for _i in 2:
		var f := FishingSession.new(424242, script_fish, {"max_class": WC.MEDIUM})
		f.cast()
		var step_i := 0
		while f.is_active() and step_i < 900:
			# 결정적 입력열: 5틱 당기고 3틱 푸는 리듬(입질 창은 항상 당김).
			var reel: bool = f.state == S.BITE or (step_i % 8) < 5
			f.tick(0.05, reel)
			step_i += 1
		var r: Dictionary = f.result()
		# result()의 스칼라만 뽑아 비교한다(Dictionary 비교 의존 회피 — 값 동등성을 명시적으로 본다).
		runs.append([f.state, f.perfect_count, snappedf(f.elapsed, 0.0001),
			snappedf(f.tension, 0.0001), snappedf(f.fish_stamina, 0.0001),
			snappedf(f.distance, 0.0001), bool(r["landed"]), bool(r["line_broke"]),
			bool(r["line_broke_by_class"]), bool(r["missed_bite"]), int(r["energy_cost"]),
			int(r["weight_class"]), int(r["perfect_count"])])
	_check("ⓕ 같은 시드·같은 입력열 = 같은 결과(상태·크리·시간·텐션·스태미나·거리·result 계약)",
		runs[0] == runs[1])
	# 다른 시드는 (거의) 다른 진행 — 결정성이 '상수 반환'이 아님을 보인다.
	var g1 := FishingSession.new(1, {"weight_class": WC.SMALL})
	var g2 := FishingSession.new(2, {"weight_class": WC.SMALL})
	g1.cast()
	g2.cast()
	_run_holding(g1)
	_run_holding(g2)
	_check("ⓕ 다른 시드 = 다른 대기시간(시드가 실제로 먹힌다)",
		not is_equal_approx(g1.elapsed, g2.elapsed))

	# ══ ⓘ [S3-T4 / ADR-0061 결정 4] 기어 — 낚싯대 4티어·미끼 3·태클 3(순수 층) ══════════
	var GC := GearCatalog
	# ── ⓘ-1 로스터 계약(슬롯 규칙의 축) ──
	_check("ⓘ1 로스터 = 낚싯대 4 · 미끼 3 · 태클 3",
		GC.RODS.size() == 4 and GC.BAITS.size() == 3 and GC.TACKLES.size() == 3)
	_check("ⓘ1 줄 강도 = 티어별 체급 상한(소·중·대·전설)",
		GC.max_class_of(GC.ROD_T1) == WC.SMALL and GC.max_class_of(GC.ROD_T2) == WC.MEDIUM
		and GC.max_class_of(GC.ROD_T3) == WC.LARGE and GC.max_class_of(GC.ROD_T4) == WC.LEGEND)
	_check("ⓘ1 미끼 슬롯 = T1만 0(T2+ 부터 미끼)",
		GC.bait_slots_of(GC.ROD_T1) == 0 and GC.bait_slots_of(GC.ROD_T2) == 1
		and GC.bait_slots_of(GC.ROD_T3) == 1 and GC.bait_slots_of(GC.ROD_T4) == 1)
	_check("ⓘ1 태클 슬롯 = 0·0·1·2(T3 하나 · T4 둘)",
		GC.tackle_slots_of(GC.ROD_T1) == 0 and GC.tackle_slots_of(GC.ROD_T2) == 0
		and GC.tackle_slots_of(GC.ROD_T3) == 1 and GC.tackle_slots_of(GC.ROD_T4) == 2)
	_check("ⓘ1 가격 밴드 = T1 증정(0) · 500 · 2,000 · 7,500 결",
		GC.price_of(GC.ROD_T1) == 0 and GC.price_of(GC.ROD_T2) == 500
		and GC.price_of(GC.ROD_T3) == 2000 and GC.price_of(GC.ROD_T4) == 7500)
	var gear_item_ok := true
	for gid in [GC.ROD_T2, GC.ROD_T3, GC.ROD_T4, GC.TACKLE_CORK, GC.TACKLE_SINKER, GC.TACKLE_QUALITY]:
		if not (ItemCatalog.has_item(gid) and ItemCatalog.category_of(gid) == ItemCatalog.CAT_TOOL
				and not ItemCatalog.stackable_of(gid) and ItemCatalog.name_of(gid) != ""
				and ItemCatalog.price_of(gid) == GC.price_of(gid)):
			gear_item_ok = false
	_check("ⓘ1 낚싯대·태클 = CAT_TOOL 유니크·매입가 위임(ItemCatalog 통용)", gear_item_ok)
	var bait_item_ok := true
	for bid in GC.BAITS:
		if not (ItemCatalog.has_item(bid)
				and ItemCatalog.category_of(bid) == ItemCatalog.CAT_CONSUMABLE
				and ItemCatalog.stackable_of(bid) and ItemCatalog.price_of(bid) > 0):
			bait_item_ok = false
	_check("ⓘ1 미끼 3종 = CAT_CONSUMABLE 스택·유가(소모품 카테고리 첫 실사용)", bait_item_ok)

	# ── ⓘ-2 슬롯 규칙(자동 적용·초과 무효·우선순위) ──
	var all_tackle := [GC.TACKLE_QUALITY, GC.TACKLE_SINKER, GC.TACKLE_CORK]   # 보유 순서는 무관해야 한다
	_check("ⓘ2 T1·T2 = 태클 슬롯 0(보유해도 적용 0)",
		GC.active_tackles(GC.ROD_T1, all_tackle).is_empty()
		and GC.active_tackles(GC.ROD_T2, all_tackle).is_empty())
	_check("ⓘ2 T3 = 우선순위 상위 1개만(코르크)",
		GC.active_tackles(GC.ROD_T3, all_tackle) == [GC.TACKLE_CORK])
	_check("ⓘ2 T4 = 상위 2개(코르크+납추) · 초과분(퀄리티) 무효",
		GC.active_tackles(GC.ROD_T4, all_tackle) == [GC.TACKLE_CORK, GC.TACKLE_SINKER])
	_check("ⓘ2 같은 종 중복 보유는 한 번만 센다(서로 다른 종만)",
		GC.active_tackles(GC.ROD_T4, [GC.TACKLE_CORK, GC.TACKLE_CORK]) == [GC.TACKLE_CORK])
	_check("ⓘ2 미끼 자동 소모 우선순위 = 보장 > 유인 > 일반",
		GC.active_bait(GC.ROD_T2, [GC.BAIT_BASIC, GC.BAIT_LURE, GC.BAIT_PLEDGE]) == GC.BAIT_PLEDGE
		and GC.active_bait(GC.ROD_T2, [GC.BAIT_BASIC, GC.BAIT_LURE]) == GC.BAIT_LURE
		and GC.active_bait(GC.ROD_T2, [GC.BAIT_BASIC]) == GC.BAIT_BASIC)
	_check("ⓘ2 T1은 미끼 슬롯 0 = 보유해도 무소모(맨몸)",
		GC.active_bait(GC.ROD_T1, [GC.BAIT_PLEDGE, GC.BAIT_BASIC]) == "")
	_check("ⓘ2 미끼 잔량 0 = 맨몸(빈 문자열)", GC.active_bait(GC.ROD_T4, []) == "")

	# ── ⓘ-3 주입 인터페이스가 정확히 중립인가(맨몸 = base, ADR-0008 "평평 ≠ 막힘") ──
	_check("ⓘ3 T1 맨몸 rod_params = FishingSession.ROD_T1과 동일",
		GC.rod_params(GC.ROD_T1) == FishingSession.ROD_T1)
	var neutral_mods := GC.mods_for()
	_check("ⓘ3 태클·미끼 0 = mods 정확히 중립(1.0/0.0)",
		is_equal_approx(float(neutral_mods["energy_factor"]), 1.0)
		and is_equal_approx(float(neutral_mods["burst_damp"]), 0.0)
		and is_equal_approx(float(neutral_mods["wait_factor"]), 1.0)
		and is_equal_approx(float(neutral_mods["perfect_window_add"]), 0.0))
	_check("ⓘ3 태클 0 = 퀄리티 보정 0.0(중립)", is_equal_approx(GC.bobber_bonus_for([]), 0.0))
	_check("ⓘ3 미끼 0 = 롤 보정 중립(시프트 0 · 보장 없음)",
		is_equal_approx(GC.class_shift_for(""), 0.0) and GC.guarantee_cap_for("", GC.ROD_T4) == -1)
	_check("ⓘ3 스킬 훅(extra)은 그대로 통과 — energy_factor 병합",
		is_equal_approx(float(GC.mods_for([], "", {"energy_factor": 0.5})["energy_factor"]), 0.5))

	# ── ⓘ-4 기어 효과의 방향성(같은 시드·같은 입력열에서 base와 비교) ──
	# ㉠ 코르크 보버 = 텐션 상승 감쇠 → 같은 조건에서 끊김이 늦게 온다.
	var cork_rod := GC.rod_params(GC.ROD_T3, [GC.TACKLE_CORK])
	_check("ⓘ4pre 코르크 = 안전 여유 비율 0.15(무적 태클 방지 클램프 아래)",
		is_equal_approx(float(cork_rod["tension_safe_bonus"]), 0.15))
	var med := {"weight_class": WC.MEDIUM}
	var base_break := FishingSession.new(4242, med, {"max_class": WC.MEDIUM})
	base_break.cast()
	_run_holding(base_break)
	var cork_break := FishingSession.new(4242, med, GC.rod_params(GC.ROD_T3, [GC.TACKLE_CORK]))
	cork_break.cast()
	_run_holding(cork_break)
	_check("ⓘ4 코르크 = 같은 시드에서 끊김 지연(%.2fs → %.2fs)" % [base_break.elapsed, cork_break.elapsed],
		base_break.line_broke and cork_break.line_broke and cork_break.elapsed > base_break.elapsed)
	# ㉡ 납추 = 발버둥 텐션 급등 완화 → 같은 틱 수에서 텐션이 낮다(발버둥 잦은 물고기로 격리 관찰).
	var bursty := {"weight_class": WC.MEDIUM, "stamina": 999.0, "tension_rise": 10.0,
		"burst_period": 0.4, "burst_len": 2.0, "burst_mult": 3.0}
	var t_base := _tension_after_holding(
		FishingSession.new(909, bursty, {"max_class": WC.MEDIUM}), 20)
	var t_damp := _tension_after_holding(FishingSession.new(909, bursty, {"max_class": WC.MEDIUM},
		GC.mods_for([GC.TACKLE_SINKER])), 20)
	_check("ⓘ4 납추 = 발버둥 텐션 완화(%.1f → %.1f)" % [t_base, t_damp], t_damp < t_base)
	_check("ⓘ4 납추 감쇠값 = 0.35(burst_mult에서 뺀다)",
		is_equal_approx(float(GC.mods_for([GC.TACKLE_SINKER])["burst_damp"]), 0.35))
	# ㉢ 퀄리티 보버 = 품질 분포 상향(등급 합 비교) — 다만 "품질 = 퍼펙트 릴" 축은 지켜야 한다.
	var qb := GC.bobber_bonus_for([GC.TACKLE_QUALITY])
	var q_plain := 0
	var q_boost := 0
	var gold_boost := 0
	var rq1 := RandomNumberGenerator.new()
	var rq2 := RandomNumberGenerator.new()
	rq1.seed = 777
	rq2.seed = 777
	for _i in 2000:
		q_plain += FishCatalog.quality_for(0, rq1, 0.0)
		var qg := FishCatalog.quality_for(0, rq2, qb)
		q_boost += qg
		if qg >= ItemCatalog.Q_GOLD:
			gold_boost += 1
	_check("ⓘ4 퀄리티 보버 = 품질 분포 상향(등급 합 %d > %d)" % [q_boost, q_plain], q_boost > q_plain)
	_check("ⓘ4 그래도 퍼펙트 0회 금+ 비율은 억제(%.2f < 0.35 — '품질 = 퍼펙트 릴' 축 보존)"
		% (float(gold_boost) / 2000.0), float(gold_boost) / 2000.0 < 0.35)
	# ㉣ 일반 미끼 = 입질 대기 −40%(같은 시드에서 BITE가 더 빨리 온다).
	var wait_plain := _secs_to_bite(FishingSession.new(5150, {"weight_class": WC.SMALL}))
	var wait_bait := _secs_to_bite(FishingSession.new(5150, {"weight_class": WC.SMALL}, {},
		GC.mods_for([], GC.BAIT_BASIC)))
	_check("ⓘ4 일반 미끼 = 입질 대기 단축(%.2fs → %.2fs)" % [wait_plain, wait_bait],
		wait_bait < wait_plain and wait_bait > 0.0)
	_check("ⓘ4 미끼 없는 캐스팅은 대기 배수 1.0(정확히 중립)",
		is_equal_approx(_secs_to_bite(FishingSession.new(5150, {"weight_class": WC.SMALL})), wait_plain))
	# ㉤ 유인 미끼 = 체급 가중이 상위로 한 계단(중·대 빈도↑). 망연절 강 저녁 = 소2·중2·대1 혼합 구간.
	var shift_lure := GC.class_shift_for(GC.BAIT_LURE)
	var big_plain := 0
	var big_lure := 0
	var rs1 := RandomNumberGenerator.new()
	var rs2 := RandomNumberGenerator.new()
	rs1.seed = 20260727
	rs2.seed = 20260727
	for _i in 3000:
		if FishCatalog.weight_class_of(FishCatalog.roll_fish(
				FishCatalog.HABITAT_RIVER, 2, FishCatalog.PHASE_EVENING, rs1)) >= WC.MEDIUM:
			big_plain += 1
		if FishCatalog.weight_class_of(FishCatalog.roll_fish(
				FishCatalog.HABITAT_RIVER, 2, FishCatalog.PHASE_EVENING, rs2, shift_lure)) >= WC.MEDIUM:
			big_lure += 1
	_check("ⓘ4 유인 미끼 = 중·대 빈도 상승(%d → %d / 3,000)" % [big_plain, big_lure],
		big_lure > big_plain * 2)
	# ㉥ 보장 미끼 = 가용 종 중 (낚싯대 허용 체급 이하) 최고 체급 확정.
	_check("ⓘ4pre 보장 상한 = 낚싯대 허용 체급(함정 방지 캡)",
		GC.guarantee_cap_for(GC.BAIT_PLEDGE, GC.ROD_T2) == WC.MEDIUM
		and GC.guarantee_cap_for(GC.BAIT_PLEDGE, GC.ROD_T3) == WC.LARGE)
	var pledge_ok := true
	var pledge_cap_ok := true
	var rp := RandomNumberGenerator.new()
	rp.seed = 4
	for _i in 200:
		var big_id := FishCatalog.roll_fish(FishCatalog.HABITAT_RIVER, 2,
			FishCatalog.PHASE_EVENING, rp, 0.0, WC.LARGE)
		if FishCatalog.weight_class_of(big_id) != WC.LARGE:
			pledge_ok = false
		var capped := FishCatalog.roll_fish(FishCatalog.HABITAT_RIVER, 2,
			FishCatalog.PHASE_EVENING, rp, 0.0, WC.MEDIUM)
		if FishCatalog.weight_class_of(capped) != WC.MEDIUM:
			pledge_cap_ok = false
	_check("ⓘ4 보장 미끼 = 200회 전부 최고 체급(대) 확정", pledge_ok)
	_check("ⓘ4 보장 상한이 낚싯대를 넘지 않는다 — T2 캡이면 중 체급 확정(끊김 함정 방지)", pledge_cap_ok)

	# ── ⓘ-5 체급 게이트 × 티어(줄 강도가 4티어의 존재 이유) ──
	var large := {"weight_class": WC.LARGE}
	var gate_t1 := FishingSession.new(2468, large, GC.rod_params(GC.ROD_T1))
	gate_t1.cast()
	_run_smart(gate_t1)
	_check("ⓘ5 T1으로 대어 = 확정 끊김(줄 강도 부족)",
		gate_t1.state == S.ESCAPED and gate_t1.line_broke_by_class)
	var gate_t3 := FishingSession.new(2468, large, GC.rod_params(GC.ROD_T3))
	gate_t3.cast()
	_run_smart(gate_t3)
	_check("ⓘ5 T3으로 같은 대어 = 게이트 통과 후 포획 성공(안전 리듬)",
		not gate_t3.line_broke_by_class and gate_t3.state == S.LANDED)
	var gate_t3_legend := FishingSession.new(2468, {"weight_class": WC.LEGEND},
		GC.rod_params(GC.ROD_T3))
	gate_t3_legend.cast()
	_run_smart(gate_t3_legend)
	_check("ⓘ5 T3으로 전설 = 여전히 끊김(T4 프레스티지의 자리)", gate_t3_legend.line_broke_by_class)

	# ══ 여기부터 main 배선(ⓔ2·ⓖ·ⓗ) ══
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m: Node = await _spawn_main()
	_check("⓿ 부팅 = 안식 농원 바깥", m._region == RegionCatalog.HOME and m._indoor == "")

	# ── ⓗ-1 아이템 카탈로그(낚싯대 T1 · 어획물 스텁 4종) ──
	_check("ⓗ1 낚싯대 T1 = 도구 카테고리·유니크·비매",
		ItemCatalog.category_of(ItemCatalog.ROD_T1) == ItemCatalog.CAT_TOOL
		and not ItemCatalog.stackable_of(ItemCatalog.ROD_T1)
		and ItemCatalog.price_of(ItemCatalog.ROD_T1) == 0
		and ItemCatalog.name_of(ItemCatalog.ROD_T1) != "")
	# ★[S3-T3] 스텁 4종(fish_stub_*)이 정식 로스터 18종으로 교체됐다 — 카탈로그 통용 단언의 축을
	#   "체급당 스텁"에서 "FishCatalog 전 어종"으로 옮긴다(로스터 세부는 fish_catalog_test 소관).
	var fish_ok := true
	for fid in FishCatalog.ids():
		if not (ItemCatalog.has_item(fid) and ItemCatalog._is_fish(fid)
				and ItemCatalog.category_of(fid) == ItemCatalog.CAT_HARVEST
				and ItemCatalog.stackable_of(fid) and ItemCatalog.price_of(fid) > 0):
			fish_ok = false
	_check("ⓗ1 어획물 18종 = 품질 유차원 CAT_HARVEST·스택·유가",
		fish_ok and FishCatalog.ids().size() == 18)
	_check("ⓗ1 어획물 판매가에 등급 배수(수확물 결)",
		ItemCatalog.price_of(FishCatalog.NEOK_BUNGEO, ItemCatalog.Q_GOLD)
			> ItemCatalog.price_of(FishCatalog.NEOK_BUNGEO, ItemCatalog.Q_NORMAL))

	# ── ⓗ-2 캐스팅 무대 한정(ADR-0061 결정 9) — 안식 연못은 비캐스팅 ──
	_select(m, ItemCatalog.ROD_T1)
	var home_water := _find_tile(m, m.WATER)
	_check("ⓗ2pre 안식 농원에 물 타일 존재", home_water.x >= 0)
	_stand_and_aim(m, home_water + Vector2i(0, -1), home_water)
	_check("ⓗ2 안식 연못 = 비캐스팅(결정 9 무대 한정)", not m._can_cast())

	# ── ⓗ-3 삼도천 — ★[S3-T5] 자동 지급 폐기 + 잔교/강둑 캐스팅 판정 ──
	# ★ ADR-0061 결정 4가 T1을 **뱃사공 첫 대화 증정**으로 옮기면서 옛 구역 진입 자동 지급
	#   (`_grant_starter_rod`)이 제거됐다. 삼도천은 뱃사공(황천해)보다 먼저 닿는 자리라, 낚싯대 없이
	#   물가에 서면 안내 프롬프트가 대신 뜬다(_needs_rod_hint).
	m.inventory.remove_item(ItemCatalog.ROD_T1, 1)
	_check("ⓗ3pre 낚싯대 회수(미보유 상태에서 진입)", not m.inventory.has_item(ItemCatalog.ROD_T1))
	m._rebuild_region(RegionCatalog.SAMDOCHEON)
	await _settle(m)
	_check("ⓗ3 ★[S3-T5] 삼도천 진입만으로는 낚싯대를 안 준다(자동 지급 폐기)",
		not m.inventory.has_item(ItemCatalog.ROD_T1))
	# 낚싯대 없이 강 낚시터 물가를 겨누면 뱃사공 안내 조건이 선다(막다른 동선 방어).
	var hint_lane: Vector2i = m.SAMDO_FISHING_LABEL_TILE
	var hint_bank: Vector2i = Vector2i(hint_lane.x, m.SAMDO_RIVER_BANK_Y)
	_stand_and_aim(m, hint_lane, hint_bank)
	_check("ⓗ3 낚싯대 미보유 + 낚시터 물가 = 뱃사공 안내 조건", m._needs_rod_hint())
	m.inventory.add_item(ItemCatalog.ROD_T1, 1)   # 이후 캐스팅 판정을 위해 손에 쥐어 준다(증정 대역)
	_check("ⓗ3 낚싯대를 얻으면 안내는 사라진다", not m._needs_rod_hint())
	_select(m, ItemCatalog.ROD_T1)
	# 잔교(x28) 위에서 옆 강물을 겨눔.
	var jetty: Vector2i = Vector2i(m.SAMDO_JETTY_X, m.SAMDO_RIVER_Y0 + 2)
	var jetty_water := jetty + Vector2i(-1, 0)
	_check("ⓗ3pre 잔교 옆 칸 = WATER", m._grid[jetty_water.y][jetty_water.x] == m.WATER)
	_stand_and_aim(m, jetty, jetty_water)
	_check("ⓗ3 잔교에서 강물 겨눔 = 캐스팅 가능", m._can_cast())
	_check("ⓗ3 물 칸 해석 = 겨눈 칸 그대로", m._cast_water_tile(jetty_water) == jetty_water)
	# 북안 물가 산책로(강 낚시터 라벨 자리) — 강둑(CLIFF_BANK) 너머로 던진다.
	var lane: Vector2i = m.SAMDO_FISHING_LABEL_TILE
	var bank: Vector2i = Vector2i(lane.x, m.SAMDO_RIVER_BANK_Y)
	_check("ⓗ3pre 강 낚시터 라벨 아래 = 강둑(CLIFF_BANK)", m._grid[bank.y][bank.x] == m.CLIFF_BANK)
	_stand_and_aim(m, lane, bank)
	_check("ⓗ3 강둑 너머 물로 캐스팅 가능(강 낚시터가 실제로 낚인다)", m._can_cast())
	_check("ⓗ3 물 칸 해석 = 강둑 한 칸 너머(WATER)",
		m._cast_water_tile(bank) == Vector2i(lane.x, m.SAMDO_RIVER_Y0))
	# 낚싯대를 안 들면 캐스팅 불가(든 도구 = 동사, ADR-0024).
	_select(m, ItemCatalog.HOE)
	_check("ⓗ3 괭이를 들면 캐스팅 불가(든 도구 = 동사)", not m._can_cast())
	_select(m, ItemCatalog.ROD_T1)
	# 물이 아닌 칸은 캐스팅 불가.
	_stand_and_aim(m, lane, lane + Vector2i(1, 0))
	_check("ⓗ3 마른 땅을 겨누면 캐스팅 불가", not m._can_cast())

	# ── ⓗ-4 황천해 — 부두 끝(바다 낚시터)에서 캐스팅 ──
	m._rebuild_region(RegionCatalog.HWANGCHEONHAE)
	await _settle(m)
	_select(m, ItemCatalog.ROD_T1)
	var pier: Vector2i = m.SEA_FISHING_LABEL_TILE
	var sea: Vector2i = pier + Vector2i(-1, 0)
	_check("ⓗ4pre 부두 끝 옆 = WATER(바다)", m._grid[sea.y][sea.x] == m.WATER)
	_stand_and_aim(m, pier, sea)
	_check("ⓗ4 바다 낚시터(부두 끝)에서 캐스팅 가능", m._can_cast())

	# ── ⓔ-2 혼력 배선(main) — 후킹 1회 소모·끊겨도 소모·부족 시 후킹 불가 ──
	m.energy.refill()
	var e0: int = m.energy.current
	# ★[S3-T3] 체급 스텁 대신 정식 어종 dict를 주입한다(main._start_fishing과 같은 경로).
	m.fishing = FishingSession.new(11, FishCatalog.session_params(FishCatalog.NEOK_MYEOLCHI),
		FishingSession.ROD_T1, {"energy_factor": m.FISHING_ENERGY_FACTOR})
	m.fishing.hook_gate = m._fishing_hook_gate
	m.fishing.cast()
	_advance_to_fight(m.fishing)
	_check("ⓔ2 후킹 순간 혼력 소모 = 소 4(캐스팅·대기는 0)", m.energy.current == e0 - 4)
	var e_hooked: int = m.energy.current
	for _i in 40:
		m.fishing.tick(0.05, true)
	_check("ⓔ2 격투 중 추가 소모 없음(후킹 1회뿐)", m.energy.current == e_hooked)
	_run_holding(m.fishing)
	m._finish_fishing()
	_check("ⓔ2 포획 → 어획물 인벤 지급(정식 어종 id)",
		m.inventory.has_item(FishCatalog.NEOK_MYEOLCHI))
	_check("ⓔ2 결착 후 세션 폐기(main.fishing = null)", m.fishing == null)

	# 끊겨도 혼력은 나간 채다(리스크 — 결정 6). 체급 게이트로 확정 끊김을 만든다.
	m.energy.refill()
	var e1: int = m.energy.current
	m.fishing = FishingSession.new(12, FishCatalog.session_params(FishCatalog.NEOUL_BEOMCHI),
		FishingSession.ROD_T1, {"energy_factor": m.FISHING_ENERGY_FACTOR})
	m.fishing.hook_gate = m._fishing_hook_gate
	m.fishing.cast()
	_advance_to_fight(m.fishing)
	_check("ⓔ2 대어 후킹 = 혼력 14 소모", m.energy.current == e1 - 14)
	_run_holding(m.fishing)
	_check("ⓔ2 체급 게이트 확정 끊김", m.fishing.state == FishingSession.State.ESCAPED
		and m.fishing.line_broke_by_class)
	var fish_before: int = m.inventory.count_of(FishCatalog.NEOUL_BEOMCHI)
	m._finish_fishing()
	_check("ⓔ2 끊김 = 어획물 0 · 혼력은 환불 없음",
		m.inventory.count_of(FishCatalog.NEOUL_BEOMCHI) == fish_before
		and m.energy.current == e1 - 14)

	# 혼력 부족 → 후킹 불가(입질 놓침) · 소모 0.
	m.energy.refill()
	m.energy.spend(SoulEnergy.MAX - 2)   # 잔량 2 < 소 체급 4
	var e2: int = m.energy.current
	m.fishing = FishingSession.new(13, FishCatalog.session_params(FishCatalog.NEOK_MYEOLCHI),
		FishingSession.ROD_T1, {"energy_factor": m.FISHING_ENERGY_FACTOR})
	m.fishing.hook_gate = m._fishing_hook_gate
	m.fishing.cast()
	_run_holding(m.fishing)
	_check("ⓔ2 혼력 부족 = 후킹 불가(ESCAPED·hook_refused)",
		m.fishing.state == FishingSession.State.ESCAPED and m.fishing.hook_refused)
	_check("ⓔ2 후킹 불가면 혼력 소모 0", m.energy.current == e2)
	m._finish_fishing()
	m.energy.refill()

	# ── ⓖ 세이브 무간섭(세션 = 비영속) ──
	m.fishing = FishingSession.new(14, {"weight_class": FishingSession.WeightClass.SMALL})
	m.fishing.cast()
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	var no_fishing_key := true
	for k in raw.keys():
		if String(k).findn("fishing") >= 0 or String(k).findn("reel") >= 0:
			no_fishing_key = false
	_check("ⓖ 세이브 dict에 낚시 세션 키 0(비영속)", no_fishing_key and not raw.has("fishing"))
	var fish_count: int = m.inventory.count_of(FishCatalog.NEOK_MYEOLCHI)
	m._load_game()
	await _settle(m)
	_check("ⓖ 저장/로드 왕복 후에도 어획물은 인벤에 남는다(하류 산출물만 영속)",
		m.inventory.count_of(FishCatalog.NEOK_MYEOLCHI) == fish_count)
	_check("ⓖ 로드 후 세션은 살아남지 않는다(구역 재구성이 버림)", m.fishing == null)

	# ── ⓗ-5 회귀 0 — 낚시 배선이 기존 밭 루프를 안 건드린다 ──
	m._rebuild_region(RegionCatalog.HOME)
	await _settle(m)
	m.energy.refill()
	var hoe_tile: Vector2i = m.STARTER_PATCH_RECT.position + Vector2i(1, 1)
	_select(m, ItemCatalog.HOE)
	m._target = hoe_tile
	m._target_valid = true
	m._use_tool()
	_check("ⓗ5 회귀 — 안식 농원 괭이질 정상(밭 루프 불변)", m.farm.is_tilled(hoe_tile))
	_check("ⓗ5 회귀 — 안식 농원은 여전히 비캐스팅", not m._can_cast())

	# ══ ⓙ [S3-T4] main 기어 배선 — 든 낚싯대 티어 인식 · 미끼 자동 소모 · 태클 자동 적용 ══
	# 인벤을 통째로 비우고(16칸 경합 제거) 보유 상태를 한 조합씩 만들어 캐스팅한다. 획득 경로는
	# 아직 없으므로(★S3-T5 매대) 여기선 디버그 지급 = inventory.add_item이 곧 "샀다"다.
	m._rebuild_region(RegionCatalog.SAMDOCHEON)
	await _settle(m)
	var cast_lane: Vector2i = m.SAMDO_FISHING_LABEL_TILE
	var cast_bank: Vector2i = Vector2i(cast_lane.x, m.SAMDO_RIVER_BANK_Y)
	var cast_water: Vector2i = Vector2i(cast_lane.x, m.SAMDO_RIVER_Y0)
	_stand_and_aim(m, cast_lane, cast_bank)
	m.energy.refill()

	# ㉠ T1 = 미끼 슬롯 0 — 미끼를 들고 있어도 소모 0·효과 0.
	_wipe_inventory(m)
	_select(m, ItemCatalog.ROD_T1)
	m.inventory.add_item(GearCatalog.BAIT_BASIC, 3)
	m.fishing = null
	m._start_fishing(cast_water)
	_check("ⓙ1 T1 캐스팅 = 미끼 무소모(슬롯 0)",
		m.inventory.count_of(GearCatalog.BAIT_BASIC) == 3 and m._cast_bait == "")
	_check("ⓙ1 T1 주입 = 줄 강도 소 · 안전 여유 0 · 대기 배수 1.0",
		int(m.fishing.rod["max_class"]) == WC.SMALL
		and is_equal_approx(float(m.fishing.rod["tension_safe_bonus"]), 0.0)
		and is_equal_approx(float(m.fishing.mods["wait_factor"]), 1.0))
	m.fishing = null

	# ㉡ T2 = 미끼 1개 자동 소모(강한 것부터) · 잔량 0이면 맨몸.
	_wipe_inventory(m)
	_select(m, ItemCatalog.ROD_T2)
	_check("ⓙ2pre 상위 티어를 들면 캐스팅 가능(티어 인식)", m._can_cast())
	m.inventory.add_item(GearCatalog.BAIT_BASIC, 2)
	m.inventory.add_item(GearCatalog.BAIT_LURE, 1)
	m.inventory.add_item(GearCatalog.BAIT_PLEDGE, 1)
	m.fishing = null
	m._start_fishing(cast_water)
	_check("ⓙ2 첫 캐스팅 = 보장 미끼 소모(우선순위 최상위)",
		m._cast_bait == GearCatalog.BAIT_PLEDGE
		and m.inventory.count_of(GearCatalog.BAIT_PLEDGE) == 0)
	_check("ⓙ2 T2 주입 = 줄 강도 중 · 미끼 대기 단축 반영(<1.0)",
		int(m.fishing.rod["max_class"]) == WC.MEDIUM
		and float(m.fishing.mods["wait_factor"]) < 1.0)
	_check("ⓙ2 보장 미끼 = 낚싯대 허용 체급 이하 최고 체급이 걸린다",
		FishCatalog.weight_class_of(String(m.fishing.result()["fish_id"])) == WC.MEDIUM)
	m.fishing = null
	m._start_fishing(cast_water)
	_check("ⓙ2 둘째 캐스팅 = 유인 미끼 소모(다음 우선순위)",
		m._cast_bait == GearCatalog.BAIT_LURE and m.inventory.count_of(GearCatalog.BAIT_LURE) == 0)
	m.fishing = null
	m._start_fishing(cast_water)
	m.fishing = null
	m._start_fishing(cast_water)
	_check("ⓙ2 일반 미끼 2개 소진(스택 소모품)",
		m._cast_bait == GearCatalog.BAIT_BASIC and m.inventory.count_of(GearCatalog.BAIT_BASIC) == 0)
	m.fishing = null
	m._start_fishing(cast_water)
	_check("ⓙ2 잔량 0 = 맨몸 캐스팅(막히지 않는다 — ADR-0008)",
		m._cast_bait == "" and is_equal_approx(float(m.fishing.mods["wait_factor"]), 1.0))
	m.fishing = null

	# ㉢ T3 = 태클 1슬롯(보유 3개 중 우선순위 1개만) · T4 = 2슬롯(초과분 무효).
	_wipe_inventory(m)
	_select(m, ItemCatalog.ROD_T3)
	m.inventory.add_item(GearCatalog.TACKLE_QUALITY, 1)
	m.inventory.add_item(GearCatalog.TACKLE_SINKER, 1)
	m.inventory.add_item(GearCatalog.TACKLE_CORK, 1)
	m.fishing = null
	m._start_fishing(cast_water)
	_check("ⓙ3 T3 = 태클 1개만 적용(코르크) · 나머지 무효",
		m._cast_tackles == [GearCatalog.TACKLE_CORK]
		and is_equal_approx(float(m.fishing.rod["tension_safe_bonus"]), 0.15)
		and is_equal_approx(float(m.fishing.mods["burst_damp"]), 0.0)
		and is_equal_approx(m._cast_bobber_bonus, 0.0))
	_check("ⓙ3 T3 줄 강도 = 대 체급", int(m.fishing.rod["max_class"]) == WC.LARGE)
	m.fishing = null
	_select(m, ItemCatalog.ROD_T4)
	m._start_fishing(cast_water)
	_check("ⓙ3 T4 = 태클 2개 적용(코르크+납추) · 퀄리티는 슬롯 초과로 무효",
		m._cast_tackles == [GearCatalog.TACKLE_CORK, GearCatalog.TACKLE_SINKER]
		and is_equal_approx(float(m.fishing.rod["tension_safe_bonus"]), 0.15)
		and is_equal_approx(float(m.fishing.mods["burst_damp"]), 0.35)
		and is_equal_approx(m._cast_bobber_bonus, 0.0))
	_check("ⓙ3 T4 줄 강도 = 전설 체급(프레스티지)",
		int(m.fishing.rod["max_class"]) == WC.LEGEND)
	m.fishing = null
	# 태클을 하나만 들면 그게 적용된다(퀄리티 보버 → 품질 보정이 결착 산정으로 흐른다).
	m.inventory.remove_item(GearCatalog.TACKLE_CORK, 1)
	m.inventory.remove_item(GearCatalog.TACKLE_SINKER, 1)
	m._start_fishing(cast_water)
	_check("ⓙ3 퀄리티 보버 단독 = 품질 보정이 캐스팅에 실린다",
		m._cast_tackles == [GearCatalog.TACKLE_QUALITY] and m._cast_bobber_bonus > 0.0)
	m.fishing = null
	# HUD 한 줄(장전 UI 부재의 임시 창구) — 미끼 잔량·적용 태클이 실제로 읽힌다.
	m.inventory.add_item(GearCatalog.BAIT_BASIC, 5)
	var gear_line: String = m._fishing_gear_line(ItemCatalog.ROD_T4)
	_check("ⓙ4 기어 HUD 한 줄 = 미끼 잔량 + 적용 태클(%s)" % gear_line,
		gear_line.find("일반 미끼 ×5") >= 0 and gear_line.find("퀄리티 보버") >= 0)
	_check("ⓙ4 T1은 슬롯이 없어 기어 줄도 없다(맨몸 티어)",
		m._fishing_gear_line(ItemCatalog.ROD_T1) == "")

	await _despawn(m)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
