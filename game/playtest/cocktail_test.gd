extends SceneTree
# ★[S6-T6 / ADR-0064 결정 6] 밤 바 칵테일(CocktailSession) 코어 + main 배선 결정적 검증.
# 실행: godot --headless --path game --script res://playtest/cocktail_test.gd
#
# 검증 축:
#   ⓐ 계약 — 상태 사슬(IDLE→POUR×2→SHAKE→DONE)·결정성(같은 시드+같은 입력열=같은 결과)·
#      종착/미시작 상태의 입력 무시·홀드가 전 단계를 한꺼번에 삼키지 않음(edge 판정)·취소.
#   ⓑ 등급 — 점수→등급 매핑의 단조성·경계값·**무실패 불변식**(어떤 점수도 등급이 나온다)·
#      ★셰이킹은 박자지 연타가 아니다(난타는 0점으로 수렴 = 체키와 갈리는 액티브 결의 근거).
#   ⓒ 밸런스 불변식 — COCKTAIL_RATE 단조 증가·최저 등급 보상 > 0·PERFECT 보상 상한·
#      ★바나는 '보호'라 단가 배수가 없다(멜 마진과 분화, ADR-0008).
#   ⓓ 배선(main.tscn 라이브) — 응대→제안·제안 만료 무벌칙·칵테일 매출 귀속(밤 장부·지갑·마일스톤
#      축·누적 총수입 네 곳)·비영속·★호감도 불변(ADR-0017).
#   ⓔ ★바나 보호 불변 — 칵테일 도입 후에도 night_bar의 잡귀 축이 그대로다: 세션이 굴러가는
#      동안에도 잡귀는 접근하고 손님 인내심은 닳으며, auto_block·raid_amount 계약이 변하지 않는다
#      (ADR-0064 결정 6 "night_bar의 잡귀 방어·바나 보호 곱셈기는 불변" + 시간 정지 금지).
#
# CocktailSession은 RefCounted 순수 클래스라 ⓐⓑ는 씬 없이 new()로 돈다(ChekiSession이 이어받은
# FishingSession의 구조 배당금). ⓓ만 main.tscn을 띄운다.
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

# 밤 바 좌석 0에 손님을 앉힌다(night_bar_test 하네스 동형 — 스폰 롤을 기다리지 않고 응대→칵테일
# 사슬만 본다). ★밤 좌석엔 손님 id 축이 없다 = 익명뿐이라는 사실이 이 하네스에 그대로 드러난다.
func _seat_night(m: Node, seat: int) -> void:
	m.night_bar._seats[seat] = {"occupied": true, "patience": 5.0,
		"max_patience": NightBar.DEFAULT_PATIENCE}

func _new_bar() -> NightBar:
	var b := NightBar.new()
	b._ready()   # 트리에 안 붙으므로 스폿·좌석 초기화를 직접 부른다(night_bar_test와 동일)
	return b

# ── 조작 드라이버 ────────────────────────────────────────────────────────────
# ① 대본 조작기 — 지정한 틱 번호에서만 한 프레임 누른다(상태 무관·완전 결정적). 결정성 단언에 쓴다.
func _run_scripted(sess: CocktailSession, press_ticks: Array, cap_ticks := 900, step := 0.02) -> Array:
	var seen: Array = [sess.state]
	for i in cap_ticks:
		if not sess.is_active():
			break
		sess.tick(step, press_ticks.has(i))
		if seen.back() != sess.state:
			seen.append(sess.state)
	return seen

# ② 정밀 조작기 — 잘 만드는 플레이어의 재현. 붓기는 커서가 목표 중심 tol 안에 들어온 첫 프레임에,
# 셰이킹은 **아직 안 친 박자의 중심에 닿는 프레임**에 한 번씩 친다(연타가 아니라 박자).
# step을 잘게 쪼개는 건 "누르기로 정한 시점"과 "세션이 재는 시점"의 한 프레임 차를 줄이기 위함이다.
func _run_precise(sess: CocktailSession, tol := 0.01, cap_ticks := 2000, step := 0.01) -> void:
	var held := false
	for _i in cap_ticks:
		if not sess.is_active():
			break
		var want := false
		if sess.state == CocktailSession.State.POUR:
			want = absf(sess.cursor_pos() - sess.zone_center(0)) <= tol \
				and sess.elapsed >= CocktailSession.ARM_SECS
		else:
			# 다음 박자 중심에 도달했나(세션은 이 tick에서 _phase_t를 step만큼 더 밀고 입력을 본다).
			for b in CocktailSession.SHAKE_BEATS:
				if not sess.beat_hit(b) and absf(sess.phase_time() + step - sess.beat_center_secs(b)) <= step:
					want = true
					break
		var press: bool = want and not held
		sess.tick(step, press)
		held = press

# ③ 방치 조작기 — 한 번도 안 누른다(자동 확정 경로 = 무실패의 극단).
func _run_idle(sess: CocktailSession, cap_ticks := 900, step := 0.02) -> void:
	for _i in cap_ticks:
		if not sess.is_active():
			break
		sess.tick(step, false)

# ④ 난타 조작기 — 한 틱 걸러 계속 친다(연타 최적해 여부를 가르는 반례 생성기).
func _run_mash(sess: CocktailSession, cap_ticks := 2000, step := 0.01) -> void:
	var on := false
	for _i in cap_ticks:
		if not sess.is_active():
			break
		on = not on
		sess.tick(step, on)

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S6-T6 밤 바 칵테일(CocktailSession)·응대 사슬 2단 검증 ══")
	var ST := CocktailSession.State
	var GR := CocktailSession.Grade

	# ── ⓐ 계약 ──────────────────────────────────────────────────────────────
	var s0 := CocktailSession.new(1234)
	_check("ⓐ 새 세션은 IDLE(begin 전엔 아무것도 안 굴러간다)",
		s0.state == ST.IDLE and not s0.is_active() and not s0.is_finished())
	s0.tick(1.0, true)
	_check("ⓐb IDLE 상태의 입력·시간은 무시된다(멱등)",
		s0.state == ST.IDLE and is_equal_approx(s0.elapsed, 0.0))
	_check("ⓐc begin()은 첫 붓기를 연다", s0.begin() and s0.state == ST.POUR and s0.is_active()
		and s0.pour_round == 0)
	_check("ⓐd 두 번째 begin()은 거부된다(진행 중 재시작 금지)", not s0.begin())

	var chained := CocktailSession.new(7788)
	chained.begin()
	var chain := _run_scripted(chained, [50, 160])
	_check("ⓐe 상태 사슬 POUR→SHAKE→DONE (%s)" % str(chain), chain == [ST.POUR, ST.SHAKE, ST.DONE])
	_check("ⓐe2 ★붓기는 두 회차를 산다(같은 State를 pour_round가 가른다)",
		chained.pour_scores.size() == CocktailSession.POUR_ROUNDS and CocktailSession.POUR_ROUNDS == 2)

	var mid := CocktailSession.new(7788)
	mid.begin()
	var ticks := 0
	while mid.state == ST.POUR and mid.pour_round == 0 and ticks < 900:
		mid.tick(0.02, ticks == 50)
		ticks += 1
	_check("ⓐe3 1회차를 확정하면 2회차가 새 제한시간으로 열린다(단계 시계 리셋)",
		mid.pour_round == 1 and mid.state == ST.POUR and mid.phase_time() < 0.05)

	var done := CocktailSession.new(7788)
	done.begin()
	_run_scripted(done, [50, 160])
	_check("ⓐf DONE은 종착역(is_finished·is_active 배타)",
		done.is_finished() and not done.is_active() and done.state == ST.DONE)
	var frozen := done.result()
	done.tick(1.0, true)
	done.tick(1.0, true)
	_check("ⓐg 종착 상태의 tick은 무동작(결과가 안 흔들린다)", done.result() == frozen)

	# 홀드 = 한 번 누른 것. edge 판정이 없으면 한 번 누른 채로 전 단계가 통째로 지나간다.
	var held_sess := CocktailSession.new(4242)
	held_sess.begin()
	var held_ticks := 0
	while held_sess.is_active() and held_ticks < 900:
		held_sess.tick(0.02, true)      # 처음부터 끝까지 계속 누르고 있는다
		held_ticks += 1
	_check("ⓐh ★계속 홀드하면 여섯 입력이 한꺼번에 안 지나간다 — 아무것도 안 누른 것과 같다",
		held_sess.is_finished() and held_sess.pour_timeouts == [true, true]
		and held_sess.shake_hits == 0 and held_sess.shake_strays == 0)
	# 준비 구간(ARM_SECS) — 그 안의 *진짜 누름*(뗐다 다시)조차 안 먹는다. 응대 입력이 붓기로
	# 흘러드는 사고를 막는 자리다.
	var armed := CocktailSession.new(555)
	armed.begin()
	armed.tick(0.05, false)
	armed.tick(0.05, true)      # elapsed 0.10 < ARM_SECS 0.15 — 흘려보낸다
	_check("ⓐi 준비 구간 안의 누름은 무시된다(응대 손가락이 붓기가 되지 않는다)",
		CocktailSession.ARM_SECS > 0.0 and armed.pour_round == 0 and armed.pour_scores.is_empty())
	armed.tick(0.05, false)
	armed.tick(0.05, true)      # elapsed 0.20 ≥ ARM_SECS — 이제 먹는다
	_check("ⓐi2 준비 구간이 지나면 정상 동작한다",
		armed.pour_round == 1 and armed.pour_timeouts == [false])

	# 결정성 — 같은 시드 + 같은 입력열 = 같은 결과.
	var d1 := CocktailSession.new(31337)
	var d2 := CocktailSession.new(31337)
	d1.begin()
	d2.begin()
	_run_scripted(d1, [37, 155])
	_run_scripted(d2, [37, 155])
	_check("ⓐj 같은 시드 + 같은 입력열 = 같은 결과(헤드리스 재현의 전제)", d1.result() == d2.result())
	var v1 := CocktailSession.new(31337)
	var v2 := CocktailSession.new(31338)
	v1.begin()
	v2.begin()
	_check("ⓐk 시드가 다르면 변주가 갈린다(붓기 목표·박자 시작이 시드 파생)",
		not is_equal_approx(v1.zone_center(0), v2.zone_center(0))
		or not is_equal_approx(v1.shake_span(), v2.shake_span()))
	var d4 := CocktailSession.new(31337)
	d4.begin()
	_run_precise(d4)
	_check("ⓐl 입력이 다르면 결과가 갈린다(입력이 실제로 점수를 만든다)", d4.result() != d1.result())

	var cancelled := CocktailSession.new(99)
	cancelled.begin()
	cancelled.tick(0.5, false)
	cancelled.cancel()
	_check("ⓐm cancel()은 세션을 죽인다(결착 아님 — 매출도 등급도 없다)",
		not cancelled.is_active() and not cancelled.is_finished())
	cancelled.cancel()
	_check("ⓐn cancel()은 멱등", cancelled.state == ST.IDLE)

	# ── ⓑ 등급 매핑·액티브 결 ────────────────────────────────────────────────
	_check("ⓑ 문턱 순서 OK < GOOD < PERFECT",
		0.0 < CocktailSession.GRADE_GOOD and CocktailSession.GRADE_GOOD < CocktailSession.GRADE_PERFECT
		and CocktailSession.GRADE_PERFECT <= 1.0)
	var monotonic := true
	var prev := CocktailSession.grade_for(0.0)
	for i in 101:
		var g := CocktailSession.grade_for(i / 100.0)
		if g < prev:
			monotonic = false
		prev = g
	_check("ⓑb 점수↑ → 등급이 절대 안 내려간다(단조)", monotonic)
	_check("ⓑc 경계값 — 문턱 위는 그 등급, 문턱 바로 아래는 한 칸 아래",
		CocktailSession.grade_for(CocktailSession.GRADE_PERFECT) == GR.PERFECT
		and CocktailSession.grade_for(CocktailSession.GRADE_PERFECT - 0.001) == GR.GOOD
		and CocktailSession.grade_for(CocktailSession.GRADE_GOOD) == GR.GOOD
		and CocktailSession.grade_for(CocktailSession.GRADE_GOOD - 0.001) == GR.OK)
	_check("ⓑd ★무실패 불변식 — 0점·음수·1 초과 어디에도 실패 등급이 없다(코지, ADR-0008)",
		CocktailSession.grade_for(0.0) == GR.OK and CocktailSession.grade_for(-5.0) == GR.OK
		and CocktailSession.grade_for(2.0) == GR.PERFECT and GR.OK == 0)
	_check("ⓑe 등급은 셋뿐이다(실패 등급이 enum에 없다)",
		GR.OK == 0 and GR.GOOD == 1 and GR.PERFECT == 2)
	_check("ⓑf 등급 이름이 셋 다 있다(체키와 겹치지 않는 밤 결 문구)",
		CocktailSession.grade_name(GR.OK) != "" and CocktailSession.grade_name(GR.GOOD) != ""
		and CocktailSession.grade_name(GR.PERFECT) != ""
		and CocktailSession.grade_name(GR.OK) != CocktailSession.grade_name(GR.PERFECT)
		and CocktailSession.grade_name(GR.PERFECT) != ChekiSession.grade_name(GR.PERFECT))

	# 실제 세션이 실제로 각 등급을 낸다(문턱이 도달 불가능한 값이 아님 = 살아 있는 사다리).
	var best := CocktailSession.new(20260810)
	best.begin()
	_run_precise(best)
	_check("ⓑg 잘 만들면 PERFECT가 실제로 나온다 (점수 %.3f · 박자 %d/%d)"
		% [best.score(), best.shake_hits, CocktailSession.SHAKE_BEATS],
		best.is_finished() and CocktailSession.grade_for(best.score()) == GR.PERFECT)
	_check("ⓑh 두 결의 점수가 따로 잡힌다(붓기 정확도 · 셰이킹 박자 = 반반)",
		best.pour_score() > 0.0 and best.shake_score > 0.0
		and is_equal_approx(best.score(), best.pour_score() * 0.5 + best.shake_score * 0.5))
	_check("ⓑh2 ★붓기는 여섯 입력 중 둘, 셰이킹이 넷 — 체키(둘)보다 손이 바쁘다(액티브 결)",
		CocktailSession.POUR_ROUNDS + CocktailSession.SHAKE_BEATS == 6
		and best.shake_hits == CocktailSession.SHAKE_BEATS)
	_check("ⓑh3 ★붓기 커서는 체키 셔터보다 빠르고 창은 좁다(같은 골격·다른 손맛)",
		CocktailSession.POUR_SPEED_MIN > ChekiSession.SNAP_SPEED_MIN
		and CocktailSession.POUR_TOL < ChekiSession.SNAP_TOL)

	var lazy := CocktailSession.new(20260810)
	lazy.begin()
	_run_idle(lazy)
	_check("ⓑi ★한 번도 안 눌러도 세션은 끝난다(자동 확정 — 막힘 0)",
		lazy.is_finished() and lazy.pour_timeouts == [true, true] and lazy.shake_hits == 0)
	_check("ⓑj 방치해도 등급이 나온다(실패 아님 — 최저 등급일 뿐)",
		CocktailSession.grade_for(lazy.score()) >= GR.OK)
	_check("ⓑk 잘 만든 쪽이 항상 더 높다 (%.3f > %.3f)" % [best.score(), lazy.score()],
		best.score() > lazy.score())

	# ★★ 연타 억제 — 셰이킹은 *박자*지 손가락 시험이 아니다(체키와 갈리는 액티브 결의 근거).
	var masher := CocktailSession.new(20260810)
	masher.begin()
	_run_mash(masher)
	_check("ⓑl ★★난타는 창 밖 헛침을 쌓아 셰이킹 0점으로 수렴한다(연타가 최적해가 아니다) — 적중 %d · 헛침 %d"
		% [masher.shake_hits, masher.shake_strays],
		masher.is_finished() and masher.shake_strays > masher.shake_hits
		and is_equal_approx(masher.shake_score, 0.0))
	_check("ⓑm 난타해도 벌칙은 없다(점수가 0으로 멈출 뿐 — 음수·실패 없음)",
		masher.score() >= 0.0 and CocktailSession.grade_for(masher.score()) >= GR.OK)
	_check("ⓑn 박자를 맞춘 쪽이 난타보다 높다 (%.3f > %.3f)" % [best.shake_score, masher.shake_score],
		best.shake_score > masher.shake_score)
	# 세션 시간 상한 — 미니게임이 밤 창을 통째로 먹지 않는다(시간 게이팅의 상한).
	_check("ⓑo 최장 세션도 상한 안에 끝난다 (%.2fs ≤ %.2fs)"
		% [lazy.elapsed, CocktailSession.max_session_secs()],
		lazy.elapsed <= CocktailSession.max_session_secs() + 0.1)

	# ── ⓒ 밸런스 불변식 ─────────────────────────────────────────────────────
	var rate_up := true
	for i in NightBar.COCKTAIL_RATE.size() - 1:
		if float(NightBar.COCKTAIL_RATE[i]) >= float(NightBar.COCKTAIL_RATE[i + 1]):
			rate_up = false
	_check("ⓒ COCKTAIL_RATE는 등급에 단조 증가(잘 만들수록 더 받는다)", rate_up)
	_check("ⓒb 등급 수와 배수 표 길이가 맞는다", NightBar.COCKTAIL_RATE.size() == 3)
	_check("ⓒc ★최저 등급 배수도 0이 아니다(실패 등급 없음의 경제적 표현)",
		float(NightBar.COCKTAIL_RATE[0]) > 0.0)

	var bar := _new_bar()
	var c_ok := bar.cocktail_price(GR.OK)
	var c_good := bar.cocktail_price(GR.GOOD)
	var c_best := bar.cocktail_price(GR.PERFECT)
	_check("ⓒd 칵테일가는 등급에 단조 증가 (%d ≤ %d ≤ %d)" % [c_ok, c_good, c_best],
		c_ok <= c_good and c_good <= c_best and c_ok < c_best)
	_check("ⓒe ★최저 등급 보상 > 0(만들어서 손해 보는 갈래가 없다)", c_ok > 0)
	_check("ⓒf PERFECT 보상 상한 — 밤 응대가의 1.5배를 넘지 않는다 (%d ≤ %d)"
		% [c_best, int(round(NightBar.SERVE_PRICE * 1.5))],
		c_best <= int(round(NightBar.SERVE_PRICE * 1.5)))
	_check("ⓒg 등급 인덱스 범위 밖은 클램프된다(손상 방어)",
		bar.cocktail_price(-3) == c_ok and bar.cocktail_price(99) == c_best)
	# ★ 바나는 '보호' 곱셈기라 단가 배수가 없다(멜 마진과 분화, ADR-0008) — 보호 축을 아무리
	#   흔들어도 칵테일 값은 그대로다. 밤의 관계 보상은 매출이 아니라 *지켜 주는 것*으로 치러진다.
	bar.raid_amount = 1
	bar.auto_block = 5
	bar.patience_secs = 30.0
	_check("ⓒh ★바나 보호를 최대로 켜도 칵테일 단가는 그대로다(밤은 마진 축이 아니다)",
		bar.cocktail_price(GR.PERFECT) == c_best and bar.cocktail_price(GR.OK) == c_ok)
	bar.raid_amount = NightBar.DEFAULT_RAID
	bar.auto_block = NightBar.DEFAULT_AUTO_BLOCK
	bar.patience_secs = NightBar.DEFAULT_PATIENCE
	# 오늘 밤 장부 — 칵테일 매출은 밤 응대 매출과 **같은 눈금**에 쌓이고, 잔수만 따로 센다.
	bar.open_bar(20 * 60)
	var rev0 := bar.tonight_revenue()
	var got := bar.record_cocktail(GR.PERFECT)
	_check("ⓒi 칵테일 매출이 오늘 밤 장부(밤 매출)에 오른다 — 새 귀속처 발명 0",
		bar.tonight_revenue() - rev0 == got and got == c_best)
	_check("ⓒj 잔수가 따로 센다(깊이·회전이 다른 눈금)", bar.tonight_cocktails() == 1)
	_check("ⓒk 칵테일은 약탈·이탈 눈금을 오염시키지 않는다",
		bar.tonight_raided() == 0 and bar.tonight_left() == 0)
	bar.end_day()
	_check("ⓒl 잔수는 밤마다 리셋된다(세이브 무상태)", bar.tonight_cocktails() == 0)
	bar.free()

	# ── ⓔ ★바나 보호 불변(칵테일 도입 후에도 잡귀 축이 그대로다) ─────────────
	print("── ⓔ 바나 보호·잡귀 축 불변 ──")
	_check("ⓔ 보호 seam 기본값 4종 불변(♡0 = 바나 잠듦 = base rate)",
		NightBar.DEFAULT_APPROACH == 8.0 and NightBar.DEFAULT_PATIENCE == 7.0
		and NightBar.DEFAULT_RAID == 3 and NightBar.DEFAULT_AUTO_BLOCK == 0)

	# 세션이 굴러가는 동안에도 잡귀는 접근하고 손님은 닳는다(★시간 정지 금지 = 밤판 깊이 vs 방어).
	var guard := _new_bar()
	guard.open_bar(20 * 60)
	guard._spots[0] = {"active": true, "approach": 5.0, "max_approach": 5.0}
	guard._seats[1] = {"occupied": true, "patience": 5.0, "max_patience": 5.0}
	var live := CocktailSession.new(4321)
	live.begin()
	var app0 := guard.approach_ratio(0)
	var pat0 := guard.patience_ratio(1)
	for _i in 20:
		live.tick(0.05, false)          # 잔을 젓는 동안…
		guard.tick(0.05, 20 * 60)       # …main._process가 세션과 무관하게 굴리는 그 틱
	_check("ⓔb ★★제조 중에도 잡귀가 계속 접근한다(시간 정지 금지 = 깊이 vs 방어)",
		guard.approach_ratio(0) < app0 and live.is_active())
	_check("ⓔc ★★제조 중에도 다른 밤 손님의 인내심이 닳는다(깊이 vs 회전)",
		guard.patience_ratio(1) < pat0)

	# auto_block 계약이 세션 활성 중에도 그대로 — 못 막은 돌파를 바나가 대신 막고 약탈 0.
	var seen: Array = []
	guard.resolved.connect(func(r): seen.append(r))
	guard._auto_blocks_left = 1
	guard._spots[2] = {"active": true, "approach": 0.05, "max_approach": 5.0}
	var raided_before := guard.tonight_raided()
	live.tick(0.1, false)
	guard.tick(0.1, 20 * 60)
	_check("ⓔd ★세션 활성 중에도 바나 자동 차단이 그대로 작동한다({repelled:true, auto:true} · 약탈 0)",
		seen.size() == 1 and bool(seen[0]["repelled"]) and bool(seen[0].get("auto", false))
		and guard.tonight_raided() == raided_before and guard.tonight_auto_blocked() == 1)
	# 자동 차단이 소진되면 약탈 계약도 그대로(raid_amount만큼 미래 자산 손실).
	guard._spots[2] = {"active": true, "approach": 0.05, "max_approach": 5.0}
	live.tick(0.1, false)
	guard.tick(0.1, 20 * 60)
	_check("ⓔe ★자동 차단 소진 후 약탈 계약도 불변(raid_amount만큼 — 칵테일이 손실을 안 지운다)",
		seen.size() == 2 and not bool(seen[1]["repelled"])
		and int(seen[1]["raided"]) == guard.raid_amount
		and guard.tonight_raided() - raided_before == guard.raid_amount)
	_check("ⓔf 막기(block) 계약도 그대로다(즉시 격퇴 · 약탈 0)",
		guard.block(0) == {"repelled": true, "raided": 0})
	guard.free()

	# ── ⓓ main 배선(main.tscn 라이브) ───────────────────────────────────────
	print("── ⓓ main 배선(main.tscn 라이브) ──")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	var m: Node = await _spawn_main()
	var bana_r = m._resident("bana")
	var pts0: int = bana_r.affinity.points
	var hearts0: int = bana_r.affinity.hearts()

	# ★⑤ 밤 좌석의 손님 정체 확인 — 낮 카페 좌석엔 "guest" 축이 있고 밤 바 좌석엔 없다(익명뿐).
	_check("ⓓ ★밤 바 좌석엔 손님 id 축이 아예 없다(익명 볼륨뿐 — 낮 카페 좌석과 갈린다)",
		not m.night_bar._seats[0].has("guest") and m.cafe._seats[0].has("guest"))

	_seat_night(m, 0)
	m._try_night_serve(0)
	_check("ⓓb 밤 응대 직후 칵테일 제안이 열린다(명명 게이트 없음 — 걸러 낼 이름이 없다)",
		m._cocktail_offered_at(0))
	_check("ⓓc 제안은 그 좌석에만 열린다", not m._cocktail_offered_at(1) and not m._cocktail_offered_at(-1))

	# 제안 만료 = 무벌칙(지갑·밤 장부 전부 불변).
	var gold_before: int = m.wallet.gold
	var night_rev_before: int = m.night_bar.tonight_revenue()
	m._tick_cocktail_offer(0.0)                  # 0초 진행 = 변화 없음
	_check("ⓓd 창은 시간으로만 닫힌다(0초 진행엔 그대로)", m._cocktail_offered_at(0))
	m._tick_cocktail_offer(99.0)                 # 창 길이를 넉넉히 넘겨 만료시킨다
	_check("ⓓe ★제안을 무시하면 조용히 닫힌다 — 벌칙 0(지갑·밤 장부 불변)",
		not m._cocktail_offered_at(0) and m._cocktail_seat == -1
		and m.wallet.gold == gold_before and m.night_bar.tonight_revenue() == night_rev_before)

	# 제안 수락 → 제조 → 결착 반영.
	_seat_night(m, 0)
	m._try_night_serve(0)
	var gold_after_serve: int = m.wallet.gold
	var milestone_before: int = m._cafe_revenue_total
	var income_before: int = m._total_income
	var night_rev_after_serve: int = m.night_bar.tonight_revenue()
	var cocktails_before: int = m.night_bar.tonight_cocktails()
	m._start_cocktail()
	_check("ⓓf 제안 수락 = 세션 시작(창은 닫히고 제조는 들고 간다)",
		m.cocktail != null and m.cocktail.is_active() and m._cocktail_offer_secs <= 0.0)
	_run_precise(m.cocktail)
	var live_grade := CocktailSession.grade_for(m.cocktail.score())
	var expect_pay: int = m.night_bar.cocktail_price(live_grade)
	m._finish_cocktail()
	_check("ⓓg 결착하면 세션은 버려진다(비영속)", m.cocktail == null and m._cocktail_seat == -1)
	_check("ⓓh 칵테일 매출이 지갑에 들어온다 (+%d골드 · 등급 %s)"
		% [expect_pay, CocktailSession.grade_name(live_grade)],
		m.wallet.gold - gold_after_serve == expect_pay and expect_pay > 0)
	_check("ⓓi ★칵테일 매출이 밤 장부에 오른다(밤 응대 매출과 같은 눈금 — 마감 요약이 한 줄로 읽힌다)",
		m.night_bar.tonight_revenue() - night_rev_after_serve == expect_pay)
	_check("ⓓj ★칵테일 매출이 마일스톤 누적 매출 축에 합류한다(옥자 축 — ADR-0064 결정 7)",
		m._cafe_revenue_total - milestone_before == expect_pay
		and m._total_income - income_before == expect_pay)
	_check("ⓓk 오늘 밤 장부에 칵테일 한 잔이 오른다",
		m.night_bar.tonight_cocktails() - cocktails_before == 1)
	_check("ⓓl ★★칵테일은 호감도를 한 톨도 안 올린다(ADR-0017 — 대화·선물만이 ♡ 채널)",
		bana_r.affinity.points == pts0 and bana_r.affinity.hearts() == hearts0)

	# 세이브 무간섭 — 세션·제안은 비영속이고, 밤 장부도 하루짜리다.
	_seat_night(m, 0)
	m._try_night_serve(0)
	_check("ⓓm 제안이 열린 채로도 저장은 정상(세션·창은 직렬화 대상이 아니다)", m._cocktail_offered_at(0))
	m._save_game()
	var m2: Node = await _spawn_main()
	_check("ⓓn 로드한 판엔 제안·세션이 없다(비영속 — 저장되는 건 지갑뿐)",
		m2.cocktail == null and m2._cocktail_seat == -1 and m2._cocktail_offer_secs <= 0.0)
	_check("ⓓo 칵테일로 번 골드는 지갑에 남아 있다(영속되는 하류 산출물)", m2.wallet.gold > 0)
	cleaner.delete_save()
	m2.queue_free()
	m.queue_free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
