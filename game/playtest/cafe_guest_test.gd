extends SceneTree
# ★[S6-T4 / ADR-0064 결정 8] 손님 풀 · 단골화 방문 가중치 · 익명 볼륨 단위검증.
# 실행: godot --headless --path game --script res://playtest/cafe_guest_test.gd
#
# 검증 축:
#   ① 명명 스폰 결정성 — day+serial 시드(전역 randf 0)·주입 없으면 전원 익명(안전판)
#      ★①f 기존 주문 롤 스트림 불침범(시드 네임스페이스 분리 — S6-T2 결정성 단언 보호)
#   ② 단골 가중치 단조성 — 서빙 이력↑ → 가중치↑ → 실제 재방문 픽 수↑. 익명은 사라지지 않는다.
#   ③ 익명 볼륨 = 마일스톤 사다리 파생 — 2단 spawn_scale이 실제로 더 많은 익명 손님을 앉힌다.
#      ★spawn_scale의 주인은 _refresh_cafe_ladder 하나(축제 × 단계 — 두 레버가 곱해진다).
#   ④ 하루 1인 1회 — 가중치가 아무리 커도 같은 얼굴이 하루에 두 번(또는 두 자리에 동시에) 안 앉는다.
#   ⑤ ★서빙 ≠ 호감도(ADR-0017) — 명명 손님에게 몇 잔을 내도 ♡는 한 톨도 안 오른다.
#   ⑥ 적격 필터 — 지금 카페 안에 서 있는 주민은 손님 후보에서 빠진다(한 사람이 둘로 안 보인다).
#   ⑦ 세이브 왕복(guest_pool) + **키 없는 구세이브** 하위호환(빈 원장·무막힘).
#
# ①②③④는 노드 단위(Cafe/GuestPool/CafeMilestone)로, ⑤⑥⑦은 main.tscn 라이브로 본다
# (원장 적립·적격 필터·세이브는 main이 조율하는 오케스트레이션 — cafe_order_test와 같은 이분법).

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_cafe() -> Cafe:
	var c := Cafe.new()
	c._ready()   # 트리에 안 붙이므로 좌석 초기화를 직접 부른다(cafe_test 하네스 동형)
	return c

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

# 좌석 0에 "이 손님이 이 메뉴를 시켰다"를 강제로 심는다(스폰 롤을 기다리지 않고 서빙 갈래만 본다).
func _seat_guest(m: Node, guest_id: String, menu_id: String) -> void:
	m.cafe._seats[0] = {"occupied": true, "patience": 5.0,
		"max_patience": Cafe.DEFAULT_PATIENCE, "want": menu_id, "guest": guest_id}

# 영업창 한나절을 굴리고(자리가 비면 즉시 서빙해 회전시킨다) 오늘의 손님 구성을 돌려준다.
# 서빙으로 자리를 비워야 다음 손님이 앉으므로, 이 회전이 곧 "하루 영업"의 최소 시뮬이다.
func _run_shift(c: Cafe, steps: int = 400) -> void:
	c.tick(0.6, 16 * 60)                     # 영업창 진입(첫 손님)
	for i in steps:
		for s in Cafe.N_SEATS:
			if c.is_waiting(s):
				c.serve(s, c.want_of(s))
		c.tick(0.5, 16 * 60)

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S6-T4 손님 풀·단골화·익명 볼륨 단위검증 ══")

	var NEO := "neo"
	var ONGI := "ongi"

	# ── ① 명명 스폰 결정성 ──────────────────────────────────────────────────
	var pool_a: Array = [{"id": NEO, "weight": 4}, {"id": ONGI, "weight": 4}]
	var a := _new_cafe()
	a.day = 5
	a.guest_pool = pool_a
	var b := _new_cafe()
	b.day = 5
	b.guest_pool = pool_a.duplicate(true)
	var same := true
	for s in 40:
		if a.roll_guest(s) != b.roll_guest(s):
			same = false
	_check("① 같은 day·serial·풀 → 같은 손님(결정 롤)", same)
	_check("①b 재호출해도 안 흔들린다(전역 randf 0)", a.roll_guest(7) == a.roll_guest(7))
	var seq5: Array = []
	var seq6: Array = []
	b.day = 6
	for s2 in 40:
		seq5.append(a.roll_guest(s2))
		seq6.append(b.roll_guest(s2))
	_check("①c 날이 다르면 손님열이 갈린다(day가 시드 축)", seq5 != seq6)
	var all_valid := true
	var any_named := false
	for g in seq5:
		if String(g) != "" and not GuestPool.GUEST_IDS.has(String(g)):
			all_valid = false
		if String(g) != "":
			any_named = true
	_check("①d 롤 결과는 익명(\"\") 아니면 로스터 id", all_valid)
	_check("①e 명명 손님이 실제로 뽑힌다(단언에 이빨이 있다)", any_named)
	var plain := _new_cafe()
	plain.day = 5
	var anon_only := true
	for s3 in 40:
		if plain.roll_guest(s3) != "":
			anon_only = false
	_check("①f 손님 풀 주입 없음 → 전원 익명(안전판·거동 불변)", anon_only)
	# ★ 시드 네임스페이스 분리 — 손님 롤을 얹어도 **주문 결과열이 한 톨도 안 흔들린다**.
	var w_with := _new_cafe()
	w_with.day = 5
	w_with.guest_pool = pool_a.duplicate(true)
	var w_none := _new_cafe()
	w_none.day = 5
	var want_same := true
	for s4 in 40:
		w_with.roll_guest(s4)                 # 손님 롤을 섞어 굴려도
		if w_with.roll_want(s4) != w_none.roll_want(s4):
			want_same = false                 # 주문열은 그대로여야 한다
	_check("①g ★주문 롤 스트림 불침범(S6-T2 결정성 단언 보호)", want_same)

	# ── ② 단골 가중치 단조성 ────────────────────────────────────────────────
	var led := GuestPool.new()
	_check("② 이력 0 = 기본 가중치", led.weight_of(NEO) == GuestPool.BASE_WEIGHT)
	var mono := true
	var prev := led.weight_of(NEO)
	for i in GuestPool.VISIT_CAP + 3:
		led.record_serve(NEO)
		var now := led.weight_of(NEO)
		if now < prev:
			mono = false
		prev = now
	_check("②b 서빙할수록 가중치가 오른다(단조 비감소)", mono)
	_check("②c 상한에서 멈춘다(한 단골이 좌석을 독식하지 않는다)",
		led.weight_of(NEO) == GuestPool.BASE_WEIGHT + GuestPool.FAMILIAR_STEP * GuestPool.VISIT_CAP)
	_check("②d 이력은 상한 위로도 계속 쌓인다(가중치만 멈춘다)",
		led.visits_of(NEO) == GuestPool.VISIT_CAP + 3)
	_check("②e 단골 판정(REGULAR_AT)", led.is_regular(NEO) and not led.is_regular(ONGI))
	led.record_serve("")
	led.record_serve("존재하지_않는_손님")
	_check("②f 익명·모르는 id는 원장이 안 센다", led.known_count() == 1)
	# 가중치가 실제 추첨에 실린다 — 같은 시드열에서 단골이 더 자주 뽑힌다.
	var cold := _new_cafe()
	cold.day = 21
	cold.guest_pool = [{"id": NEO, "weight": GuestPool.BASE_WEIGHT}]
	var warm := _new_cafe()
	warm.day = 21
	warm.guest_pool = [{"id": NEO, "weight": led.weight_of(NEO)}]
	var n_cold := 0
	var n_warm := 0
	var n_anon := 0
	for s5 in 300:
		if cold.roll_guest(s5) == NEO:
			n_cold += 1
		if warm.roll_guest(s5) == NEO:
			n_warm += 1
		if warm.roll_guest(s5) == "":
			n_anon += 1
	_check("②g 처음 오는 손님도 뽑힌다 (300롤 중 %d)" % n_cold, n_cold > 0)
	_check("②h ★단골이 더 자주 온다 — 재방문 확률↑ (%d → %d)" % [n_cold, n_warm], n_warm > n_cold)
	_check("②i ★익명은 후보에서 사라지지 않는다 (300롤 중 %d)" % n_anon, n_anon > 0)
	_check("②j 익명 가중치 상수(그레이박스 레버)", Cafe.W_ANON_GUEST > 0)

	# ── ③ 익명 볼륨 = 마일스톤 사다리 파생 ──────────────────────────────────
	_check("③ 2단 스폰 배수가 더 붐빈다(작을수록 잦다)",
		CafeMilestone.spawn_scale_of(CafeMilestone.STAGE_2)
		< CafeMilestone.spawn_scale_of(CafeMilestone.STAGE_NONE))
	var s1 := _new_cafe()
	s1.spawn_scale = CafeMilestone.spawn_scale_of(CafeMilestone.STAGE_NONE)
	s1.open_seats = CafeMilestone.seats_of(CafeMilestone.STAGE_NONE)
	_run_shift(s1)
	var s2 := _new_cafe()
	s2.spawn_scale = CafeMilestone.spawn_scale_of(CafeMilestone.STAGE_2)
	s2.open_seats = CafeMilestone.seats_of(CafeMilestone.STAGE_2)
	_run_shift(s2)
	_check("③b ★2단에서 익명 손님이 더 많이 앉는다 (%d → %d명)"
		% [s1.today_anonymous(), s2.today_anonymous()],
		s2.today_anonymous() > s1.today_anonymous())
	_check("③c 명명 주입이 없으면 전원 익명(볼륨 축과 정체성 축이 갈려 있다)",
		s2.today_named() == 0 and s2.today_anonymous() > 0)
	_check("③d 좌석도 2단이 더 열린다(사다리 콘텐츠)",
		CafeMilestone.seats_of(CafeMilestone.STAGE_2)
		> CafeMilestone.seats_of(CafeMilestone.STAGE_NONE))

	# ── ④ 하루 1인 1회(같은 얼굴 중복 착석 0) ───────────────────────────────
	var solo := _new_cafe()
	solo.day = 33
	solo.open_seats = Cafe.SEATS_STAGE2
	solo.guest_pool = [{"id": NEO, "weight": 999}]   # 극단 가중치로도 하루 한 번뿐이어야 한다
	_run_shift(solo)
	_check("④ 명명 손님은 하루 한 번만 앉는다 (오늘 아는 얼굴 %d명)" % solo.today_named(),
		solo.today_named() == 1)
	_check("④b 그래도 손님은 계속 온다(나머지는 익명 — 무막힘)", solo.today_anonymous() > 1)
	_check("④c 오늘 다녀갔음 조회", solo.came_today(NEO) and not solo.came_today(ONGI))
	solo.end_day()
	_run_shift(solo)
	_check("④d 다음 날이면 다시 온다(하루 단위 규칙 — 원장은 그대로)", solo.today_named() == 1)

	for n in [a, b, plain, w_with, w_none, cold, warm, s1, s2, solo]:
		n.free()

	# ── main 배선(main.tscn 라이브) ─────────────────────────────────────────
	print("── ⑤⑥⑦ main 배선(main.tscn 라이브) ──")
	var cleaner := SaveManager.new()
	cleaner.delete_save()   # 결정적 검증 — 디스크 세이브를 비우고 시작(cafe_order_test 하네스 동형)
	var mn: Node = await _spawn_main()

	# ── ⑥ 적격 필터(카페 상주 제외) ────────────────────────────────────────
	mn.clock.minutes = 16 * 60                  # 영업창 한복판 — 모찌의 저녁 스테이션이 카페 홀이다
	var pool_open: Array = mn._cafe_guest_pool()
	var ids_open: Array = []
	for e in pool_open:
		ids_open.append(String((e as Dictionary)["id"]))
	_check("⑥ 영업창엔 카페 상주 주민(모찌)이 후보에서 빠진다 — 한 사람이 둘로 안 보인다",
		not ids_open.has("mochi"))
	_check("⑥b 다른 구역 점주들은 후보다(네오·뱃사공·옹이·풀무·무골)",
		ids_open.has("neo") and ids_open.has("boatman") and ids_open.has("ongi")
		and ids_open.has("pulmu") and ids_open.has("mugol"))
	_check("⑥c 카페 직원·사장·밤 무대는 애초에 로스터 밖(미호·멜·옥자·바나)",
		not GuestPool.GUEST_IDS.has("miho") and not GuestPool.GUEST_IDS.has("mel")
		and not GuestPool.GUEST_IDS.has("okja") and not GuestPool.GUEST_IDS.has("bana"))
	mn.clock.minutes = 8 * 60                   # 아침엔 모찌가 제 집 앞이라 후보로 돌아온다
	var ids_morning: Array = []
	for e2 in mn._cafe_guest_pool():
		ids_morning.append(String((e2 as Dictionary)["id"]))
	_check("⑥d 필터는 *지금 자리* 파생이다(아침엔 모찌도 후보 — 로스터 영구 제외가 아니다)",
		ids_morning.has("mochi"))
	mn.clock.minutes = 16 * 60
	_check("⑥e 후보 가중치는 단골 원장이 매긴다",
		int((pool_open[0] as Dictionary)["weight"]) == GuestPool.BASE_WEIGHT)

	# ── ⑤ ★서빙 ≠ 호감도(ADR-0017) + 단골 원장 적립 ────────────────────────
	var neo_r = mn._resident("neo")
	neo_r.affinity.points = 0
	var hearts0: int = neo_r.affinity.hearts()
	var points0: int = neo_r.affinity.points
	var gold0: int = mn.wallet.gold
	for i2 in 3:
		_seat_guest(mn, "neo", MenuCatalog.AMERICANO)
		mn._try_serve(0)
	_check("⑤ 명명 손님 서빙이 단골 원장에 쌓인다", mn.guests.visits_of("neo") == 3)
	_check("⑤b ★서빙은 호감도를 한 톨도 안 올린다(ADR-0017 — 대화·선물만이 ♡ 채널)",
		neo_r.affinity.points == points0 and neo_r.affinity.hearts() == hearts0)
	_check("⑤c 매출은 정상(서빙 자체는 종전 그대로)", mn.wallet.gold - gold0 == Cafe.BASE_PRICE * 3)
	_check("⑤d 단골이 되면 가중치가 올라 후보 풀에 실린다",
		mn.guests.is_regular("neo")
		and mn.guests.weight_of("neo") > GuestPool.BASE_WEIGHT)
	_check("⑤e 알림 문구에 이름이 실린다(익명은 이름 없음)",
		mn._guest_prefix("neo").begins_with("단골 네오") and mn._guest_prefix("") == "")
	# 익명 손님 서빙은 원장을 안 건드린다(이름도 이력도 없는 손님 — 결정 8).
	var known0: int = mn.guests.known_count()
	_seat_guest(mn, "", MenuCatalog.AMERICANO)
	mn._try_serve(0)
	_check("⑤f 익명 손님 서빙은 원장에 안 쌓인다", mn.guests.known_count() == known0)
	# ♡가 올라도 단골 가중치는 안 오른다(역방향 독립 — 관계가 손님 유입을 게이팅하지 않는다).
	var w_before: int = mn.guests.weight_of("ongi")
	mn._resident("ongi").affinity.points = 9999
	_check("⑤g ♡가 올라도 방문 가중치는 안 오른다(역방향 독립)",
		mn.guests.weight_of("ongi") == w_before)

	# ── ③e spawn_scale 단일 주인 재확인(라이브) ─────────────────────────────
	mn._run_harvested = CafeMilestone.S2_TARGET_HARVEST
	mn._cafe_revenue_total = CafeMilestone.S2_TARGET_REVENUE
	mn.affinity.points = 99999
	mn.mel_affinity.points = 99999
	mn._refresh_cafe_ladder()
	_check("③e 2단 도달", mn._cafe_stage() == CafeMilestone.STAGE_2)
	_check("③f ★spawn_scale = 축제 배수 × 단계 배수 한 자리에서(두 레버가 곱해진다)",
		is_equal_approx(mn.cafe.spawn_scale,
			Festival.spawn_scale(mn.clock.day) * CafeMilestone.spawn_scale_of(CafeMilestone.STAGE_2)))
	_check("③g 좌석도 함께 열린다(같은 자리에서 주입)", mn.cafe.open_seats == Cafe.SEATS_STAGE2)

	# ── ⑦ 세이브 왕복 + 구세이브 하위호환 ──────────────────────────────────
	mn._save_game()
	var mn2: Node = await _spawn_main()
	_check("⑦ 이어하기에 단골 원장 복원", mn2.guests.visits_of("neo") == 3)
	_check("⑦b 복원된 이력이 가중치에도 산다",
		mn2.guests.weight_of("neo") == mn.guests.weight_of("neo"))
	_check("⑦c 호감도 조각과 키가 갈려 있다(세이브 층위에서도 서빙 ≠ ♡)",
		mn2.guests.visits_of("neo") == 3 and mn2._resident("neo").affinity.points == 0)
	var blob: Dictionary = cleaner.load_game()
	_check("⑦d pre 세이브에 guest_pool 키가 실려 있다", blob.has("guest_pool"))
	blob.erase("guest_pool")
	cleaner.save_game(blob)
	var mn3: Node = await _spawn_main()
	_check("⑦e 구세이브(키 부재) 로드 = 빈 원장", mn3.guests.known_count() == 0)
	_check("⑦f 그래도 안 막힌다 — 명명 손님은 그대로 오고 이력만 0부터",
		mn3.guests.weight_of("neo") == GuestPool.BASE_WEIGHT
		and not mn3._cafe_guest_pool().is_empty())
	cleaner.delete_save()

	for m in [mn, mn2, mn3]:
		m.queue_free()   # 띄운 main 세 벌을 거둔다(cafe_order_test와 같은 종료 결)

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
