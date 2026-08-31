extends SceneTree
# ★[S8-T4 / ADR-0066 결정 1·4·12] 곡선 절단 · 활동→하트 채널 · 도메인 XP 당근 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 곡선 상수 절단 — POINTS_PER_HEART가 명시 60(사장 RUN_DAYS 파생 아님)이고 값·만렙이 불변.
#      affinity.gd 소스에 "RunSummary" 참조가 **한 글자도 없다**(절단의 직접 증거).
#   ② 활동 채널(Affinity 단위) — 적립·일일 캡 12·초과분 절삭·날이 바뀌면 리셋·음수 무시.
#   ③ 라이브 배선 3곳 — 미호(밭 수확 1회 = +1) · 멜(서빙 매출 100냥당 +1, 잔돈 이월) ·
#      바나(**나락** 잡귀 처치 = +1, 갱도 처치는 0) · 서브 주민은 채널 자체가 없다.
#   ④ 도메인 XP 당근 — ♡0 = ×1.0(평평 ≠ 막힘)·♡5 = ×1.25, 그리고 **실효**(같은 수확·같은 처치가
#      하트에 따라 다른 XP를 남긴다). 바나 가속은 나락 한정(갱도 XP 불변).
#   ⑤ 세이브 — 활동 캡 2키·멜 잔돈 1키의 왕복 보존과 구세이브(키 없음) 무결.
#
# 실행: ./run_tests.sh activity   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame
	return m

# 안식 농원에서 아직 안 갈린 빈 밭칸 1개(quality_skill_test의 그 헬퍼 동형).
# ★ 과수 풋프린트도 피한다 — _try_harvest는 나무 3×3을 밭보다 **먼저** 보므로, 그 안의 칸을
#   골라 심으면 밭 수확을 검증하려던 호출이 조용히 과수 분기로 새 버린다(③c2가 나무를 심은 뒤에도
#   ④의 밭 수확이 밭 경로로 가야 한다).
func _free_home_soil(m: Node) -> Vector2i:
	for y in range(1, m._grid_h - 1):
		for x in range(1, m._grid_w - 1):
			var tile := Vector2i(x, y)
			if not m.farm.is_tilled(tile) and not m._is_tree_blocked(tile) \
					and m.orchard.tree_at(tile) == Orchard.TREE_NONE:
				return tile
	return Vector2i(-1, -1)

# 그 칸에 작물을 심고 강제 성숙시킨 뒤 수확한다(테스트 셋업 — quality_skill_test 동형).
func _harvest_once(m: Node, crop: String) -> bool:
	var t := _free_home_soil(m)
	if t.x < 0:
		return false
	m.farm.hoe(t)
	m.farm.plant(t, crop)
	m.farm._tiles[t]["grown_days"] = 99
	m._target = t
	m.energy.current = m.energy.MAX
	m._try_harvest()
	return not m.farm.is_planted(t)   # 수확되면 칸이 빈다

# 좌석 0에 "이 메뉴를 시킨 손님"을 강제로 앉힌다(cafe_order_test의 그 헬퍼 동형).
func _seat_want(m: Node, menu_id: String) -> void:
	m.cafe._seats[0] = {"occupied": true, "patience": 5.0,
		"max_patience": Cafe.DEFAULT_PATIENCE, "want": menu_id}

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S8-T4 곡선 절단·활동 채널·XP 당근 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ① 곡선 상수 절단(값 불변) ──
	print("── ① 곡선 상수 절단 ──")
	_check("①a 하트당 60점(옛 40 × 21/14와 같은 값 — 동작 불변)", Affinity.POINTS_PER_HEART == 60)
	_check("①b 만렙 300점(5칸 × 60)", Affinity.MAX_POINTS == 300
		and Affinity.MAX_POINTS == Affinity.MAX_HEARTS * Affinity.POINTS_PER_HEART)
	# 절단의 직접 증거 — **코드 줄**에 사장 상수 참조가 남아 있지 않다(주석의 유래 기록은 남긴다:
	# 무엇을 왜 끊었는지가 사라지면 다음 사람이 같은 파생을 다시 만든다).
	var src := FileAccess.open("res://affinity.gd", FileAccess.READ)
	var text := src.get_as_text()
	src.close()
	var code_ref := false
	for line in text.split("\n"):
		var s := String(line).strip_edges()
		if not s.begins_with("#") and "RunSummary" in s:
			code_ref = true
	_check("①c affinity.gd 코드 줄에 RunSummary 참조 0(사장 상수 절단)", not code_ref)
	# 사장 상수 자체는 **지우지 않았다**(S9 엔딩 자산 — season_calendar_test와 같은 입장).
	_check("①d RunSummary.RUN_DAYS 상수는 그대로 보존", RunSummary.RUN_DAYS == 21)
	# ★[폴리시 2회차] "죽은 앵커면 함께 절단"의 판정 결과를 박제한다 — **죽은 건 곡선 파생뿐이고
	#   상수 자체는 살아 있다**: playtest_bot이 이 값을 시뮬레이션 길이로 실사용한다(①c와 같은
	#   소스 스캔 방식). 이 단언이 서 있는 한 "RUN_DAYS는 아무도 안 쓴다"는 오판으로 지울 수 없다.
	var bot_src := FileAccess.open("res://playtest/playtest_bot.gd", FileAccess.READ)
	var bot_uses := "RunSummary.RUN_DAYS" in bot_src.get_as_text()
	bot_src.close()
	_check("①e RUN_DAYS는 죽은 앵커가 아니다 — playtest_bot이 시뮬 길이로 실사용(삭제 금지 근거)",
		bot_uses)

	# ── ② 활동 채널(Affinity 단위 — 노드만) ──
	print("── ② 활동 채널·일일 캡 ──")
	var a := Affinity.new()
	_check("②a 첫 적립은 그대로 붙는다(+1)", a.activity_gain(1, 10) == 1 and a.points == 1)
	_check("②b 오늘 쓴 양·남은 여력 파생",
		a.activity_used_on(10) == 1 and a.activity_left_on(10) == Affinity.ACTIVITY_DAILY_CAP - 1)
	_check("②c 다른 날에서 보면 오늘 쓴 양은 0(파생 리셋 — 루프 없음)",
		a.activity_used_on(11) == 0 and a.activity_left_on(11) == Affinity.ACTIVITY_DAILY_CAP)
	# 캡까지 채운다(1 + 11 = 12).
	_check("②d 남은 여력만큼만 붙는다(11 요청 → 11)", a.activity_gain(11, 10) == 11)
	_check("②e 캡 12 도달", a.activity_used_on(10) == Affinity.ACTIVITY_DAILY_CAP
		and a.activity_left_on(10) == 0 and a.points == Affinity.ACTIVITY_DAILY_CAP)
	_check("②f 캡 소진 후 적립은 0(점수 불변)",
		a.activity_gain(5, 10) == 0 and a.points == Affinity.ACTIVITY_DAILY_CAP)
	_check("②g 초과 요청은 남은 만큼만 잘라 붙는다(다음 날 20 요청 → 12)",
		a.activity_gain(20, 11) == Affinity.ACTIVITY_DAILY_CAP)
	_check("②h 날이 바뀌면 카운터가 되감긴다", a.activity_used_on(11) == Affinity.ACTIVITY_DAILY_CAP
		and a.points == Affinity.ACTIVITY_DAILY_CAP * 2)
	_check("②i 0·음수는 무시(방어)", a.activity_gain(0, 12) == 0 and a.activity_gain(-5, 12) == 0)
	# 활동 채널은 대화·선물 리듬을 건드리지 않는다(제3 채널 — add_points 결).
	_check("②j 대화·선물 리듬과 독립(last_*_day 무터치)",
		a.last_talk_day == -1 and a.last_gift_day == -1 and a.gifts_left_in_week(12) == 2)
	# 캡은 만렙 clamp와 별개로 동작한다(만렙에서도 카운터는 정상).
	a.points = Affinity.MAX_POINTS
	_check("②k 만렙에서도 적립 호출은 안전(점수는 상한)",
		a.activity_gain(3, 13) == 3 and a.points == Affinity.MAX_POINTS)
	a.free()

	# ── ③④ 라이브 배선(main.tscn) ──
	print("── ③ 라이브 배선 3채널 ──")
	var m: Node = await _new_main()
	var r_miho: Resident = m._resident("miho")
	var r_mel: Resident = m._resident("mel")
	var r_bana: Resident = m._resident("bana")
	m.clock.day = 3
	for r in [r_miho, r_mel, r_bana]:
		r.affinity.points = 0
		r.affinity.activity_day = -1
		r.affinity.activity_today = 0
	m._mel_revenue_carry = 0

	# ㉠ 미호 = 수확 액션당 +1.
	var p0: int = r_miho.affinity.points
	_check("③a 밭 수확 1회 성립", _harvest_once(m, CropCatalog.HONRYEONGCHO))
	_check("③b 수확 1회 = 미호 +1", r_miho.affinity.points == p0 + 1
		and r_miho.affinity.activity_used_on(3) == 1)
	_check("③c 수확은 멜·바나 채널을 건드리지 않는다(도메인 분리)",
		r_mel.affinity.points == 0 and r_bana.affinity.points == 0)
	# 과수 수확도 같은 "수확 액션당 1"이다 — 밭만 붙이면 과수 위주 판에서 채널이 죽는다.
	# 셋업: 나무를 직접 심고(성숙 나이까지 심은 날을 과거로) 매달린 과일을 채워 둔다.
	var tree_anchor := Vector2i(-1, -1)
	for cand in [Vector2i(6, 6), Vector2i(10, 10), Vector2i(14, 6), Vector2i(10, 14)]:
		if m.orchard.plant(cand, FruitTreeCatalog.HONBAEKDO, 3, func(_t): return false):
			tree_anchor = cand
			break
	m.orchard._trees[tree_anchor]["planted_day"] = 3 - 200   # 나이 200일 = 성숙
	m.orchard._trees[tree_anchor]["fruit_count"] = 3         # 매달린 과일 3개(액션은 1회)
	m._region = RegionCatalog.HOME
	m._target = tree_anchor
	m.energy.current = m.energy.MAX
	var p_before: int = r_miho.affinity.points
	m._try_harvest()
	_check("③c2 과수 수확 성립(과일 3개 전량)", m.orchard.fruit_count_of(tree_anchor) == 0)
	_check("③c3 과수 수확 = 미호 +1(과일 개수가 아니라 액션당 1)",
		r_miho.affinity.points == p_before + 1)
	# 반대 방향 경계 — **야생 작물 수확은 안 붙는다**: ADR-0033 #4가 그 수확을 채집 축으로 통째
	# 가로채 농사 XP조차 안 준다(밭에서 길러도 채집). 미호 도메인 실적이 아니다.
	var wild_p: int = r_miho.affinity.points
	_check("③c4 야생 작물 수확 성립", _harvest_once(m, CropCatalog.WILD_PIAN))
	_check("③c5 야생 작물 수확은 미호 적립 0(채집 축 — ADR-0033 #4)",
		r_miho.affinity.points == wild_p)

	# ㉡ 멜 = 서빙 매출 100냥당 +1(잔돈 이월).
	var base_price: int = m.cafe.serve_price(m._fallback_menu())   # 기본 메뉴가 × 멜 마진
	_seat_want(m, m._fallback_menu())
	m._try_serve(0)
	var after1: int = r_mel.affinity.points
	_check("③d 서빙 1회(%d냥) — 100냥 미만이면 아직 0점, 잔돈만 쌓인다" % base_price,
		(after1 == 0 and m._mel_revenue_carry == base_price) if base_price < 100
		else after1 == base_price / 100)
	# 누적이 100냥을 넘을 때까지 서빙을 반복한다(잔돈 이월이 살아 있어야 점수가 난다).
	var served := 1
	while r_mel.affinity.points == 0 and served < 12:
		_seat_want(m, m._fallback_menu())
		m._try_serve(0)
		served += 1
	_check("③e 누적 매출이 100냥을 넘으면 멜 +1(잔돈 이월이 살아 있다)",
		r_mel.affinity.points >= 1)
	_check("③f 점수 = 누적 매출 / 100(정수 나눗셈)과 일치",
		r_mel.affinity.points == (base_price * served) / m.MEL_REVENUE_PER_POINT)
	_check("③g 잔돈은 100냥 미만으로만 남는다",
		m._mel_revenue_carry == (base_price * served) % m.MEL_REVENUE_PER_POINT
		and m._mel_revenue_carry < m.MEL_REVENUE_PER_POINT)
	_check("③h 서빙은 미호·바나 채널을 건드리지 않는다(밭 1 + 과수 1 = 2에서 정지)",
		r_miho.affinity.points == p0 + 2 and r_bana.affinity.points == 0)

	# ㉢ 바나 = **나락** 잡귀 처치당 +1(갱도는 0).
	var mob_a := Mob.spawn(MobCatalog.HEOTGEOT, Vector2i(5, 5), 1)
	m._region = RegionCatalog.EOPHWA_MINE
	m._narak_depth = 0
	m._on_mob_killed(mob_a, 0)
	_check("③i 갱도 처치는 바나 채널 0(나락 한정 — 결정 4 문구)", r_bana.affinity.points == 0)
	var mob_b := Mob.spawn(MobCatalog.HEOTGEOT, Vector2i(5, 5), 2)
	m._region = RegionCatalog.NARAK
	m._narak_depth = 3
	m._on_mob_killed(mob_b, 1)
	_check("③j 나락 처치 = 바나 +1", r_bana.affinity.points == 1
		and r_bana.affinity.activity_used_on(3) == 1)
	# 캡 12는 라이브에서도 같은 값(13번째 처치는 안 붙는다).
	for i in range(2, 14):
		m._on_mob_killed(Mob.spawn(MobCatalog.HEOTGEOT, Vector2i(5, 5), i), i)
	_check("③k 라이브에서도 하루 캡 12에서 멈춘다",
		r_bana.affinity.points == Affinity.ACTIVITY_DAILY_CAP)
	# 서브 주민은 채널 자체가 없다("쉼터" 결 — 성과 요구 0).
	# ★[S9b-T1 / ADR-0068 결정 3] 켄 추가 — 조연 코러스도 **쉼터 2채널**(대화·선물)뿐이라는
	#   설계가 신규 온보딩에서도 지켜지는지 여기서 잰다([narrative-bible §6.1]).
	var subs := ["neo", "mochi", "boatman", "ongi", "pulmu", "mugol", "ken"]
	var subs_zero := true
	for rid in subs:
		var r: Resident = m._resident(rid)
		if r == null or r.affinity == null or r.affinity.points != 0 \
				or r.affinity.activity_used_on(3) != 0:
			subs_zero = false
	_check("③l 서브 주민 전원은 활동 적립 0(§6.1 쉼터 — 성과 요구 없음)", subs_zero)

	# ── ④ 도메인 XP 당근 ──
	print("── ④ 도메인 XP 당근(1 + 0.05/♡) ──")
	_check("④a ♡0 = ×1.0(평평 ≠ 막힘 — 관계 0에서도 base 그대로)",
		is_equal_approx(XpBoost.mult(0), 1.0))
	_check("④b ♡5 = ×1.25", is_equal_approx(XpBoost.mult(5), 1.25))
	_check("④c 선형 한 식(♡1 1.05 · ♡3 1.15)",
		is_equal_approx(XpBoost.mult(1), 1.05) and is_equal_approx(XpBoost.mult(3), 1.15))
	_check("④d 범위 밖 하트는 잘린다(손상 방어)",
		is_equal_approx(XpBoost.mult(-3), 1.0) and is_equal_approx(XpBoost.mult(99), 1.25))
	_check("④e 정수화 = 반올림(100 → ♡5에서 125 · 10 → 13)",
		XpBoost.scaled(100, 5) == 125 and XpBoost.scaled(10, 5) == 13)
	_check("④f 0 이하는 그대로 흘린다", XpBoost.scaled(0, 5) == 0 and XpBoost.scaled(-4, 5) == -4)
	# 바나 훅(예약석)이 실제 하트를 읽는다.
	# ★[S8-T5] 하트 = stage(진급 칸) — 점수와 함께 stage도 세팅한다(관문은 heart_gate_test 소관).
	r_bana.affinity.points = 0
	r_bana.affinity.stage = 0
	_check("④g narak_bana_xp_mult ♡0 = 1.0", is_equal_approx(m.narak_bana_xp_mult(), 1.0))
	r_bana.affinity.points = Affinity.MAX_POINTS
	r_bana.affinity.stage = Affinity.MAX_HEARTS
	_check("④h narak_bana_xp_mult ♡5 = 1.25", is_equal_approx(m.narak_bana_xp_mult(), 1.25))
	# **실효** — 같은 몹을 같은 무대에서 잡아도 하트에 따라 XP가 다르다.
	var kill_xp: int = Mob.spawn(MobCatalog.HEOTGEOT, Vector2i(5, 5), 99).kill_xp()
	m._region = RegionCatalog.NARAK
	m._narak_depth = 3
	r_bana.affinity.points = 0
	r_bana.affinity.stage = 0
	var xp0: int = m._combat_xp
	m._on_mob_killed(Mob.spawn(MobCatalog.HEOTGEOT, Vector2i(5, 5), 20), 20)
	var gained_flat: int = m._combat_xp - xp0
	r_bana.affinity.points = Affinity.MAX_POINTS
	r_bana.affinity.stage = Affinity.MAX_HEARTS
	xp0 = m._combat_xp
	m._on_mob_killed(Mob.spawn(MobCatalog.HEOTGEOT, Vector2i(5, 5), 21), 21)
	var gained_boost: int = m._combat_xp - xp0
	_check("④i 전투 XP 실효 — ♡0 = base · ♡5 = ×1.25",
		gained_flat == kill_xp and gained_boost == XpBoost.scaled(kill_xp, 5)
		and gained_boost > gained_flat)
	# 갱도에서는 바나 하트가 붙어 있어도 XP가 안 오른다(무대 한정).
	m._region = RegionCatalog.EOPHWA_MINE
	m._narak_depth = 0
	xp0 = m._combat_xp
	m._on_mob_killed(Mob.spawn(MobCatalog.HEOTGEOT, Vector2i(5, 5), 22), 22)
	_check("④j 갱도 전투 XP는 ♡5여도 base 그대로(나락 한정 가속)",
		m._combat_xp - xp0 == kill_xp)
	# 미호 농사 XP — 같은 작물 수확이 하트만큼 더 준다.
	var crop := CropCatalog.HONRYEONGCHO
	var farm_base: int = CropCatalog.sell_price(crop)
	r_miho.affinity.points = 0
	r_miho.affinity.stage = 0
	var fx0: int = m._farming_xp
	_check("④k 밭 수확 재현(♡0)", _harvest_once(m, crop))
	var farm_flat: int = m._farming_xp - fx0
	r_miho.affinity.points = Affinity.MAX_POINTS
	r_miho.affinity.stage = Affinity.MAX_HEARTS
	fx0 = m._farming_xp
	_check("④l 밭 수확 재현(♡5)", _harvest_once(m, crop))
	var farm_boost: int = m._farming_xp - fx0
	_check("④m 농사 XP 실효 — ♡0 = base(%d) · ♡5 = ×1.25" % farm_base,
		farm_flat == farm_base and farm_boost == XpBoost.scaled(farm_base, 5)
		and farm_boost > farm_flat)

	# ── ⑤ 세이브(가법 키 3개) ──
	print("── ⑤ 세이브 하위호환 ──")
	var old := Affinity.new()
	old.load_save({"points": 50})                # 활동 키 없는 구세이브
	_check("⑤a 활동 키 없는 구세이브도 크래시 없이 로드", old.points == 50
		and old.activity_day == -1 and old.activity_today == 0)
	_check("⑤b 기본값 = '오늘 아직 안 벌었다'(아무것도 안 막힌다)",
		old.activity_left_on(7) == Affinity.ACTIVITY_DAILY_CAP)
	old.activity_gain(4, 7)
	var rt := Affinity.new()
	rt.load_save(old.to_save())
	_check("⑤c 왕복 저장이 활동 카운터를 보존",
		rt.activity_day == 7 and rt.activity_today == 4 and rt.activity_left_on(7) == 8)
	var bad := Affinity.new()
	bad.load_save({"activity_today": 999, "activity_day": 7})
	_check("⑤d 손상값은 캡으로 잘린다", bad.activity_today == Affinity.ACTIVITY_DAILY_CAP)
	old.free()
	rt.free()
	bad.free()
	# 멜 잔돈 키 — main 세이브 왕복(저장·재개가 잔돈 세탁 수단이 되지 않는지).
	m._mel_revenue_carry = 77
	r_mel.affinity.points = 120
	m._save_game()
	m.free()
	await process_frame
	var m2: Node = await _new_main()
	_check("⑤e 멜 잔돈이 세이브 왕복에 보존", m2._mel_revenue_carry == 77)
	_check("⑤f 활동으로 쌓은 호감도도 함께 복원(멜 세이브 키 경로)",
		m2._resident("mel").affinity.points == 120)
	m2.free()
	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
