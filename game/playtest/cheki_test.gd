extends SceneTree
# ★[S6-T5 / ADR-0064 결정 5] 상업 체키(ChekiSession) 코어 + main 배선 결정적 검증.
# 실행: godot --headless --path game --script res://playtest/cheki_test.gd
#
# 검증 축:
#   ⓐ 계약 — 상태 사슬(IDLE→AIM→SNAP→DONE)·결정성(같은 시드+같은 입력열=같은 결과)·
#      종착/미시작 상태의 입력 무시·홀드가 두 단을 한꺼번에 삼키지 않음(edge 판정)·이동 취소.
#   ⓑ 등급 — 점수→등급 매핑의 단조성·경계값·**무실패 불변식**(어떤 점수도 등급이 나온다).
#   ⓒ 밸런스 불변식 — CHEKI_RATE 단조 증가·최저 등급 보상 > 0·PERFECT 보상이 원 서빙가 대비 상한 내.
#   ⓓ 배선(main.tscn 라이브) — **명명 단골만** 제안·익명 배제·체키 매출(지갑·마일스톤 축·마감 요약)·
#      단골 가중치 가속·제안 만료 무벌칙·★호감도 불변(ADR-0017)·촬영 중 카페 시간 계속 흐름.
#
# ChekiSession은 RefCounted 순수 클래스라 ⓐⓑ는 씬 없이 new()로 돈다(FishingSession이 깔아 둔
# 구조 배당금 — 미니게임 하나를 통째로 헤드리스에서 굴린다). ⓓ만 main.tscn을 띄운다.
# 좀비 방지: 모든 단언 뒤 quit(). run_tests.sh 워치독과 함께.

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

# 좌석 0에 "이 손님이 이 메뉴를 시켰다"를 심는다(cafe_guest_test 하네스 동형 — 스폰 롤을 기다리지
# 않고 서빙→체키 사슬만 본다).
func _seat_guest(m: Node, guest_id: String, menu_id: String) -> void:
	# ★[폴리시 R18 #7] **영업 창을 먼저 연다.** 종전엔 부팅 직후(06:00 = 카페 마감 상태)의 좌석에
	#   손님을 꽂았는데, 그건 플레이에서 성립하지 않는 무대다(손님은 영업 중에만 앉는다). 체키
	#   제안 창구가 `cafe.is_open()`을 묻게 된 뒤 이 무대가 드러났다 — 술어가 아니라 무대가 틀렸다.
	#   여는 것이 먼저다: `_open_shop`이 자리를 비우므로 그 뒤에 앉혀야 한다.
	m.clock.minutes = float(Cafe.OPEN_MIN) + 60.0
	m.cafe.tick(0.0, m.clock.minutes)
	m.cafe._seats[0] = {"occupied": true, "patience": 5.0,
		"max_patience": Cafe.DEFAULT_PATIENCE, "want": menu_id, "guest": guest_id}

# ── 조작 드라이버 ────────────────────────────────────────────────────────────
# ① 대본 조작기 — 지정한 틱 번호에서만 한 프레임 누른다(상태 무관·완전 결정적). 결정성 단언에 쓴다.
func _run_scripted(sess: ChekiSession, press_ticks: Array, cap_ticks := 800, step := 0.02) -> Array:
	var seen: Array = [sess.state]
	for i in cap_ticks:
		if not sess.is_active():
			break
		sess.tick(step, press_ticks.has(i))
		if seen.back() != sess.state:
			seen.append(sess.state)
	return seen

# ② 정밀 조작기 — 커서가 목표 중심 tol 안에 들어온 첫 프레임에 누른다(잘 찍는 플레이어의 재현).
# step을 잘게 쪼개는 건 "누르기로 정한 위치"와 "세션이 재는 위치"의 한 프레임 차를 줄이기 위함이다
# (세션은 커서를 먼저 옮기고 나서 입력을 본다 — 실제 플레이의 입력 지연과 같은 결).
func _run_precise(sess: ChekiSession, tol := 0.01, cap_ticks := 1500, step := 0.01) -> void:
	var held := false
	for _i in cap_ticks:
		if not sess.is_active():
			break
		var aiming := sess.state == ChekiSession.State.AIM
		var target := sess.aim_target() if aiming else sess.snap_target()
		var pos := sess.aim_pos() if aiming else sess.snap_pos()
		var want := absf(pos - target) <= tol and sess.elapsed >= ChekiSession.ARM_SECS
		var press := want and not held
		sess.tick(step, press)
		held = press

# ③ 방치 조작기 — 한 번도 안 누른다(자동 확정 경로 = 무실패의 극단).
func _run_idle(sess: ChekiSession, cap_ticks := 800, step := 0.02) -> void:
	for _i in cap_ticks:
		if not sess.is_active():
			break
		sess.tick(step, false)

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S6-T5 상업 체키(ChekiSession)·서빙 사슬 2단 검증 ══")
	var ST := ChekiSession.State
	var GR := ChekiSession.Grade

	# ── ⓐ 계약 ──────────────────────────────────────────────────────────────
	var s0 := ChekiSession.new(1234)
	_check("ⓐ 새 세션은 IDLE(begin 전엔 아무것도 안 굴러간다)",
		s0.state == ST.IDLE and not s0.is_active() and not s0.is_finished())
	s0.tick(1.0, true)
	_check("ⓐb IDLE 상태의 입력·시간은 무시된다(멱등)",
		s0.state == ST.IDLE and is_equal_approx(s0.elapsed, 0.0))
	_check("ⓐc begin()은 AIM을 연다", s0.begin() and s0.state == ST.AIM and s0.is_active())
	_check("ⓐd 두 번째 begin()은 거부된다(진행 중 재시작 금지)", not s0.begin())

	var chained := ChekiSession.new(7788)
	chained.begin()
	var chain := _run_scripted(chained, [50, 200])
	_check("ⓐe 상태 사슬 AIM→SNAP→DONE (%s)" % str(chain), chain == [ST.AIM, ST.SNAP, ST.DONE])

	var done := ChekiSession.new(7788)
	done.begin()
	_run_scripted(done, [50, 200])
	_check("ⓐf DONE은 종착역(is_finished·is_active 배타)",
		done.is_finished() and not done.is_active() and done.state == ST.DONE)
	var frozen := done.result()
	done.tick(1.0, true)
	done.tick(1.0, true)
	_check("ⓐg 종착 상태의 tick은 무동작(결과가 안 흔들린다)", done.result() == frozen)

	# 홀드 = 한 번 누른 것. edge 판정이 없으면 한 번 누른 채로 두 단이 통째로 지나간다.
	var held_sess := ChekiSession.new(4242)
	held_sess.begin()
	var held_ticks := 0
	while held_sess.is_active() and held_ticks < 800:
		held_sess.tick(0.02, true)      # 처음부터 끝까지 계속 누르고 있는다
		held_ticks += 1
	_check("ⓐh ★계속 홀드하면 두 단이 한꺼번에 안 지나간다 — 아무것도 안 누른 것과 같다",
		held_sess.is_finished() and held_sess.aim_timeout and held_sess.snap_timeout)
	# 준비 구간(ARM_SECS) — 그 안의 *진짜 누름*(뗐다 다시)조차 안 먹는다. 서빙 입력이 셔터로
	# 흘러드는 사고를 막는 자리다.
	var armed := ChekiSession.new(555)
	armed.begin()
	armed.tick(0.05, false)
	armed.tick(0.05, true)      # elapsed 0.10 < ARM_SECS 0.15 — 흘려보낸다
	_check("ⓐi 준비 구간 안의 누름은 무시된다(서빙 손가락이 셔터가 되지 않는다)",
		ChekiSession.ARM_SECS > 0.0 and armed.state == ST.AIM)
	armed.tick(0.05, false)
	armed.tick(0.05, true)      # elapsed 0.20 ≥ ARM_SECS — 이제 먹는다
	_check("ⓐi2 준비 구간이 지나면 정상 동작한다", armed.state == ST.SNAP and not armed.aim_timeout)

	# 결정성 — 같은 시드 + 같은 입력열 = 같은 결과.
	var d1 := ChekiSession.new(31337)
	var d2 := ChekiSession.new(31337)
	d1.begin()
	d2.begin()
	_run_scripted(d1, [37, 155])
	_run_scripted(d2, [37, 155])
	_check("ⓐj 같은 시드 + 같은 입력열 = 같은 결과(헤드리스 재현의 전제)", d1.result() == d2.result())
	var d3 := ChekiSession.new(31338)
	d3.begin()
	_run_scripted(d3, [37, 155])
	_check("ⓐk 시드가 다르면 변주가 갈린다", d3.result() != d1.result())
	var d4 := ChekiSession.new(31337)
	d4.begin()
	_run_scripted(d4, [37, 160])
	_check("ⓐl 입력이 다르면 결과가 갈린다(입력이 실제로 점수를 만든다)", d4.result() != d1.result())

	var cancelled := ChekiSession.new(99)
	cancelled.begin()
	cancelled.tick(0.5, false)
	cancelled.cancel()
	_check("ⓐm cancel()은 세션을 죽인다(결착 아님 — 매출도 등급도 없다)",
		not cancelled.is_active() and not cancelled.is_finished())
	cancelled.cancel()
	_check("ⓐn cancel()은 멱등", cancelled.state == ST.IDLE)

	# ── ⓑ 등급 매핑 ─────────────────────────────────────────────────────────
	_check("ⓑ 문턱 순서 OK < GOOD < PERFECT",
		0.0 < ChekiSession.GRADE_GOOD and ChekiSession.GRADE_GOOD < ChekiSession.GRADE_PERFECT
		and ChekiSession.GRADE_PERFECT <= 1.0)
	var monotonic := true
	var prev := ChekiSession.grade_for(0.0)
	for i in 101:
		var g := ChekiSession.grade_for(i / 100.0)
		if g < prev:
			monotonic = false
		prev = g
	_check("ⓑb 점수↑ → 등급이 절대 안 내려간다(단조)", monotonic)
	_check("ⓑc 경계값 — 문턱 위는 그 등급, 문턱 바로 아래는 한 칸 아래",
		ChekiSession.grade_for(ChekiSession.GRADE_PERFECT) == GR.PERFECT
		and ChekiSession.grade_for(ChekiSession.GRADE_PERFECT - 0.001) == GR.GOOD
		and ChekiSession.grade_for(ChekiSession.GRADE_GOOD) == GR.GOOD
		and ChekiSession.grade_for(ChekiSession.GRADE_GOOD - 0.001) == GR.OK)
	_check("ⓑd ★무실패 불변식 — 0점·음수·1 초과 어디에도 실패 등급이 없다(코지, ADR-0008)",
		ChekiSession.grade_for(0.0) == GR.OK and ChekiSession.grade_for(-5.0) == GR.OK
		and ChekiSession.grade_for(2.0) == GR.PERFECT and GR.OK == 0)
	_check("ⓑe 등급은 셋뿐이다(실패 등급이 enum에 없다)",
		GR.OK == 0 and GR.GOOD == 1 and GR.PERFECT == 2)
	_check("ⓑf 등급 이름이 셋 다 있다",
		ChekiSession.grade_name(GR.OK) != "" and ChekiSession.grade_name(GR.GOOD) != ""
		and ChekiSession.grade_name(GR.PERFECT) != ""
		and ChekiSession.grade_name(GR.OK) != ChekiSession.grade_name(GR.PERFECT))

	# 실제 세션이 실제로 각 등급을 낸다(문턱이 도달 불가능한 값이 아님 = 살아 있는 사다리).
	var best := ChekiSession.new(20260810)
	best.begin()
	_run_precise(best)
	var best_grade := ChekiSession.grade_for(best.score())
	_check("ⓑg 잘 겨누면 PERFECT가 실제로 나온다 (점수 %.3f)" % best.score(),
		best.is_finished() and best_grade == GR.PERFECT)
	_check("ⓑh 두 단의 점수가 따로 잡힌다(구도·타이밍 평균)",
		best.aim_score > 0.0 and best.timing_score > 0.0
		and is_equal_approx(best.score(), (best.aim_score + best.timing_score) * 0.5))
	var lazy := ChekiSession.new(20260810)
	lazy.begin()
	_run_idle(lazy)
	_check("ⓑi ★한 번도 안 눌러도 세션은 끝난다(자동 확정 — 막힘 0)",
		lazy.is_finished() and lazy.aim_timeout and lazy.snap_timeout)
	_check("ⓑj 방치해도 등급이 나온다(실패 아님 — 최저 등급일 뿐)",
		ChekiSession.grade_for(lazy.score()) >= GR.OK)
	_check("ⓑk 잘 찍은 쪽이 항상 더 높다 (%.3f > %.3f)" % [best.score(), lazy.score()],
		best.score() > lazy.score())
	# 세션 시간 상한 — 미니게임이 영업창을 통째로 먹지 않는다(시간 게이팅의 상한).
	_check("ⓑl 최장 세션도 두 단 제한시간 합 안에 끝난다 (%.2fs)" % lazy.elapsed,
		lazy.elapsed <= ChekiSession.AIM_SECS + ChekiSession.SNAP_SECS + 0.1)

	# ── ⓒ 밸런스 불변식 ─────────────────────────────────────────────────────
	var rate_up := true
	for i in Cafe.CHEKI_RATE.size() - 1:
		if float(Cafe.CHEKI_RATE[i]) >= float(Cafe.CHEKI_RATE[i + 1]):
			rate_up = false
	_check("ⓒ CHEKI_RATE는 등급에 단조 증가(잘 찍을수록 더 받는다)", rate_up)
	_check("ⓒb 등급 수와 배수 표 길이가 맞는다", Cafe.CHEKI_RATE.size() == 3)
	_check("ⓒc ★최저 등급 배수도 0이 아니다(실패 등급 없음의 경제적 표현)",
		float(Cafe.CHEKI_RATE[0]) > 0.0)

	var pricer := Cafe.new()
	pricer._ready()
	var base_price := pricer.serve_price(MenuCatalog.AMERICANO)
	var p_ok := pricer.cheki_price(MenuCatalog.AMERICANO, GR.OK)
	var p_good := pricer.cheki_price(MenuCatalog.AMERICANO, GR.GOOD)
	var p_best := pricer.cheki_price(MenuCatalog.AMERICANO, GR.PERFECT)
	_check("ⓒd 체키가는 등급에 단조 증가 (%d ≤ %d ≤ %d)" % [p_ok, p_good, p_best],
		p_ok <= p_good and p_good <= p_best and p_ok < p_best)
	_check("ⓒe ★최저 등급 보상 > 0(찍어서 손해 보는 갈래가 없다)", p_ok > 0)
	var pay_cap := int(round(base_price * 1.5))
	_check("ⓒf PERFECT 보상 상한 — 원 서빙가의 1.5배를 넘지 않는다 (%d ≤ %d)"
		% [p_best, pay_cap], p_best <= pay_cap)
	_check("ⓒg 등급 인덱스 범위 밖은 클램프된다(손상 방어)",
		pricer.cheki_price(MenuCatalog.AMERICANO, -3) == p_ok
		and pricer.cheki_price(MenuCatalog.AMERICANO, 99) == p_best)
	# 사슬이 값을 물려받는다 — 비싼 잔을 낸 자리는 체키도 비싸다(곳간 적재의 보상이 끝까지 간다).
	var fusion_id := String(MenuCatalog.fusion_ids()[0])
	_check("ⓒh ★체키가는 방금 낸 잔의 값을 물려받는다(융합 > 기본 — 사슬이 안 끊긴다)",
		pricer.cheki_price(fusion_id, GR.GOOD) > pricer.cheki_price(MenuCatalog.AMERICANO, GR.GOOD))
	# 멜 마진(관계 곱셈기)이 사슬 2단에도 자동으로 얹힌다(ADR-0008 — 게이트가 아니라 곱셈기).
	pricer.margin = 2.0
	_check("ⓒi ★멜 마진은 체키에도 곱해진다(♡0에서도 base는 온전 · 친할수록 사슬 전체가 두껍다)",
		pricer.cheki_price(MenuCatalog.AMERICANO, GR.GOOD) > p_good)
	pricer.margin = 1.0
	# 오늘 장부 — 체키는 매출에 오르되 서빙 수를 부풀리지 않는다(두 눈금이 갈려 있다).
	var served0 := pricer.today_served()
	var rev0 := pricer.today_revenue()
	var got := pricer.record_cheki(MenuCatalog.AMERICANO, GR.PERFECT)
	_check("ⓒj 체키 매출이 오늘 카페 장부에 오른다", pricer.today_revenue() - rev0 == got and got == p_best)
	_check("ⓒk 체키는 서빙 수를 안 부풀린다(깊이·회전이 다른 눈금)",
		pricer.today_served() == served0 and pricer.today_cheki() == 1)
	pricer.free()

	# 단골 원장 — 체키가 가중치를 가속하되 상한은 그대로(게이트가 아니라 가속).
	var led := GuestPool.new()
	var w0 := led.weight_of("neo")
	led.record_cheki("neo", GR.GOOD)
	var w1 := led.weight_of("neo")
	led.record_cheki("neo", GR.PERFECT)
	var w2 := led.weight_of("neo")
	_check("ⓒl 체키가 단골 가중치를 올린다 (%d → %d → %d)" % [w0, w1, w2], w1 > w0 and w2 > w1)
	_check("ⓒm 인생샷이 두 배로 남는다(등급이 원장에도 반영)",
		GuestPool.CHEKI_STEP_PERFECT > GuestPool.CHEKI_STEP
		and led.cheki_points_of("neo") == GuestPool.CHEKI_STEP + GuestPool.CHEKI_STEP_PERFECT)
	_check("ⓒn 체키는 '몇 잔 팔았나'를 오염시키지 않는다(서빙 이력과 별개 dict)",
		led.visits_of("neo") == 0)
	for _i in 30:
		led.record_cheki("neo", GR.PERFECT)
	_check("ⓒo ★VISIT_CAP 상한은 그대로다(체키를 아무리 찍어도 한 단골이 좌석을 독식 못 한다)",
		led.weight_of("neo") == GuestPool.BASE_WEIGHT + GuestPool.FAMILIAR_STEP * GuestPool.VISIT_CAP)
	led.record_cheki("", GR.GOOD)
	led.record_cheki("모르는놈", GR.GOOD)
	_check("ⓒp 익명·모르는 id는 조용히 흘려보낸다(record_serve와 같은 방어)",
		led.cheki_points_of("") == 0 and led.known_count() == 0)
	# 세이브 왕복 + 구세이브(키 부재) 하위호환.
	var led2 := GuestPool.new()
	led2.load_save(led.to_save())
	_check("ⓒq 체키 이력 세이브 왕복", led2.weight_of("neo") == led.weight_of("neo"))
	var led3 := GuestPool.new()
	led3.load_save({"visits": {"neo": 2}})
	_check("ⓒr 구세이브(chekis 키 부재) = 빈 체키 원장·무막힘",
		led3.cheki_points_of("neo") == 0 and led3.visits_of("neo") == 2)

	# ── ⓓ main 배선(main.tscn 라이브) ───────────────────────────────────────
	print("── ⓓ main 배선(main.tscn 라이브) ──")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	var m: Node = await _spawn_main()
	var neo_r = m._resident("neo")
	neo_r.affinity.points = 0
	var pts0: int = neo_r.affinity.points
	var hearts0: int = neo_r.affinity.hearts()

	# 명명 손님 서빙 → 제안이 열린다.
	_seat_guest(m, "neo", MenuCatalog.AMERICANO)
	m._try_serve(0)
	_check("ⓓ 명명 손님 서빙 직후 체키 제안이 열린다",
		m._cheki_offered_at(0) and m._cheki_guest == "neo" and m._cheki_menu == MenuCatalog.AMERICANO)
	_check("ⓓb 제안은 그 좌석에만 열린다", not m._cheki_offered_at(1) and not m._cheki_offered_at(-1))

	# 제안 만료 = 무벌칙(지갑·원장·호감도 전부 불변).
	var gold_before: int = m.wallet.gold
	var w_before: int = m.guests.weight_of("neo")
	m._tick_cheki_offer(0.0)                     # 0초 진행 = 변화 없음
	_check("ⓓc 창은 시간으로만 닫힌다(0초 진행엔 그대로)", m._cheki_offered_at(0))
	m._tick_cheki_offer(99.0)                    # 창 길이를 넉넉히 넘겨 만료시킨다
	_check("ⓓd ★제안을 무시하면 조용히 닫힌다 — 벌칙 0(지갑·단골 원장 불변)",
		not m._cheki_offered_at(0) and m._cheki_seat == -1 and m._cheki_guest == ""
		and m.wallet.gold == gold_before and m.guests.weight_of("neo") == w_before)

	# 익명 손님에겐 제안이 안 열린다(T3 볼륨 배제).
	_seat_guest(m, "", MenuCatalog.AMERICANO)
	m._try_serve(0)
	_check("ⓓe ★익명 손님(T3 볼륨)에겐 제안이 안 열린다 — 이름 없는 손님과 '같이 한 장'은 없다",
		not m._cheki_offered_at(0) and m._cheki_guest == "")

	# 제안 수락 → 촬영 → 결착 반영.
	_seat_guest(m, "neo", MenuCatalog.AMERICANO)
	m._try_serve(0)
	var gold_after_serve: int = m.wallet.gold
	var milestone_before: int = m._cafe_revenue_total
	var cheki_pts_before: int = m.guests.cheki_points_of("neo")
	var cafe_cheki_before: int = m.cafe.today_cheki()
	m._start_cheki()
	_check("ⓓf 제안 수락 = 세션 시작(창은 닫히고 대상은 들고 간다)",
		m.cheki != null and m.cheki.is_active() and m._cheki_guest == "neo"
		and m._cheki_offer_secs <= 0.0)
	_run_precise(m.cheki)
	var live_grade := ChekiSession.grade_for(m.cheki.score())
	var expect_pay: int = m.cafe.cheki_price(MenuCatalog.AMERICANO, live_grade)
	m._finish_cheki()
	_check("ⓓg 결착하면 세션은 버려진다(비영속)", m.cheki == null and m._cheki_guest == "")
	_check("ⓓh 체키 매출이 지갑에 들어온다 (+%d골드 · 등급 %s)"
		% [expect_pay, ChekiSession.grade_name(live_grade)],
		m.wallet.gold - gold_after_serve == expect_pay and expect_pay > 0)
	_check("ⓓi ★체키 매출이 마일스톤 누적 서빙 매출 축에 합류한다(옥자 축 — ADR-0064 결정 7)",
		m._cafe_revenue_total - milestone_before == expect_pay)
	_check("ⓓj 오늘 카페 장부에도 체키 한 장이 오른다",
		m.cafe.today_cheki() - cafe_cheki_before == 1)
	_check("ⓓk 단골 가중치가 체키로 가속된다",
		m.guests.cheki_points_of("neo") > cheki_pts_before)
	_check("ⓓl ★★체키는 호감도를 한 톨도 안 올린다(ADR-0017 — 대화·선물만이 ♡ 채널)",
		neo_r.affinity.points == pts0 and neo_r.affinity.hearts() == hearts0)

	# 촬영 중에도 카페 시간이 흐른다 — 깊이 vs 회전 트레이드오프의 본체.
	_seat_guest(m, "neo", MenuCatalog.AMERICANO)
	m._try_serve(0)
	m._start_cheki()
	m.cafe._open = true
	m.cafe._was_open = true      # 영업창 재진입(_open_shop)이 좌석을 쓸어 버리지 않게
	m.cafe._seats[1] = {"occupied": true, "patience": 5.0,
		"max_patience": Cafe.DEFAULT_PATIENCE, "want": MenuCatalog.AMERICANO, "guest": ""}
	var pat_before: float = m.cafe.patience_ratio(1)
	for _i in 20:
		m.cafe.tick(0.05, 16 * 60)      # main._process가 세션과 무관하게 굴리는 그 틱
	_check("ⓓm ★★촬영 중에도 다른 손님의 인내심이 닳는다(시간 정지 금지 = 깊이 vs 회전)",
		m.cafe.patience_ratio(1) < pat_before and m.cheki != null and m.cheki.is_active())
	m.cheki = null
	m._clear_cheki_offer()

	# 세이브 무간섭 — 세션·제안은 비영속이고, 영속되는 건 하류 산출물(단골 원장)뿐이다.
	# 제안이 열린 채 저장/로드해도 새 세션에는 제안이 안 딸려 온다(창은 그 자리 그 순간의 것).
	_seat_guest(m, "neo", MenuCatalog.AMERICANO)
	m._try_serve(0)
	_check("ⓓn 제안이 열린 채로도 저장은 정상(세션·창은 직렬화 대상이 아니다)", m._cheki_offered_at(0))
	m._save_game()
	var m2: Node = await _spawn_main()
	_check("ⓓo 로드한 판엔 제안·세션이 없다(비영속 — 저장되는 건 원장뿐)",
		m2.cheki == null and m2._cheki_seat == -1 and m2._cheki_guest == "")
	_check("ⓓp 단골 체키 원장은 살아남는다(영속되는 유일한 조각)",
		m2.guests.cheki_points_of("neo") > 0)
	cleaner.delete_save()
	m2.queue_free()
	m.queue_free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
