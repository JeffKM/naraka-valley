extends SceneTree
# ★[S8-T10] 관계 장기 스모크 — Slice 8 전 사슬(선물·대화·활동 → 관문 → 연애 → 결혼 → 이혼 →
# 재구애·재혼)을 **한 세이브에서 결정적으로** 한 번에 굴린다.
#
# 무엇을 보증하나(이음매 전용 — 개별 기능의 상세 단언은 각 스위트가 소유한다):
#   ① 세 채널이 같은 미터를 채운다 — 일일 대화(+8) · 선물(GiftPrefs 등급) · 활동(일일 캡 12).
#      셋을 합치면 ♡1치(60점)지만 **deed 미달이면 칸은 안 오른다**(점수와 진급의 분리).
#      선물 리듬(주 2회)이 사흘째를 막는 것까지 같은 세이브에서 본다.
#   ② deed 원장이 차면 관문이 열린다 — ♡1은 직접 호출로, ♡2는 **대화 진입**으로(관문 트리거가
#      대화라는 사실이 이 사슬의 이음매다), ♡3·♡4까지. ♡5는 관문이 아니다(의지 시험 대기).
#   ③ ♡4 만충 → 고백 = ♡5 진급 + 연애 슬롯 + 질투(안 뽑힌 메인 2인 −30).
#   ④ 부적 의뢰 → 안방 확장 → 청혼 → 3일 후 혼례 → 이주·주 2회 해제·아침 물주기 잡일.
#   ⑤⑦ 세이브 왕복 2회(혼인 중 · 이혼 후) — 상태가 부팅을 건너 살아남는다.
#   ⑥ 이혼 = 50,000냥 · ♡0(points·stage) · 슬롯 해제 · 스케줄 원복 · 면제 원장 기록.
#   ⑧ 재구애 — 본 비트 재지급 없는 조용한 진급 · 재고백 · **재혼 면제**(아크 비워도 수락).
#
# 실행: TIMEOUT=240 ./run_tests.sh s8_relationship_smoke   (헤드리스는 반드시 game/에서 · 순차)

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

# ★[S9-T4] 판을 비운다 — 관문 컷신이 서 있으면 끝까지 재생해 뒤따르는 대화를 열고(미호는 S9-T4부터
# 관문 컷신 데이터를 가진다), 절기 물음 선택지가 떠 있으면 첫 항을 고른다(넘기기로는 못 지나간다).
func _dismiss_intro(m: Node) -> void:
	var guard := 0
	while (m.cutscene != null or m.dialogue.is_open()) and guard < 200:
		if m.cutscene != null:
			m._tick_cutscene(0.1)
		elif m.dialogue.has_choice():
			m.dialogue.choose(0)
		else:
			m.dialogue.advance()
		guard += 1

func _pass_day(m: Node) -> void:
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)

# 지갑·원목을 정확히 맞춘다(marriage_test·divorce_test 헬퍼 동형).
func _stock(m: Node, gold: int, wood: int) -> void:
	m.wallet.gold = gold
	var have: int = m.inventory.count_of(ItemCatalog.WOOD)
	if have > wood:
		m.inventory.remove_item(ItemCatalog.WOOD, have - wood)
	elif have < wood:
		m.inventory.add_item(ItemCatalog.WOOD, wood - have)

# 아이템을 손에 든다(선물·청혼 = 든 아이템 문법 — marriage_test 동형).
func _hold(m: Node, id: String) -> void:
	if not m.inventory.has_item(id):
		m.inventory.add_item(id, 1, ItemCatalog.Q_NORMAL)
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

# 다음 "평온한 아침"(혼우 자동 급수 없음·절기 첫날 아님) 전날로 시계를 세운다(marriage_test 동형).
func _park_before_calm_day(m: Node) -> void:
	var d: int = m.clock.day + 1
	while Weather.waters_field(m._weather_on(d)) or GameClock.is_season_first_day(d):
		d += 1
	m.clock.day = d - 1

# 오늘부터 span일이 **같은 주 안**에 들고 그 사이에 생일이 없는 자리로 시계를 세운다 —
# 주 2회 상한을 보려면 세 번의 선물이 한 주에 담겨야 하고(주가 넘어가면 카운터가 되감긴다),
# 생일이 끼면 그 하루가 상한 면제라 판정이 흐려진다. 전부 day 파생이라 결정적이다.
func _park_in_one_week(m: Node, r: Resident, span: int) -> void:
	var d: int = m.clock.day
	while true:
		var ok := GameClock.week_of(d) == GameClock.week_of(d + span)
		for i in span + 1:
			if r.is_birthday_on(d + i):
				ok = false
		if ok:
			break
		d += 1
	m.clock.day = d

# 스타터 밭에 n칸까지 심는다(잡일 물주기 대상 만들기 — marriage_test 동형). 심은 칸 수 반환.
func _plant_some(m: Node, n: int) -> int:
	var patch: Rect2i = m.STARTER_PATCH_RECT
	var planted := 0
	for dy in patch.size.y:
		for dx in patch.size.x:
			if planted >= n:
				return planted
			var t := Vector2i(patch.position.x + dx, patch.position.y + dy)
			# ★[폴리시 R7] **경작 가능한 칸에만 심는다**(marriage_test의 같은 루프와 짝). 원장을
			#   직접 부르면 `_is_farmable`을 우회해 패치 안의 예외 칸(미호 자리·삽사리 자리)까지
			#   심겨, 실제 플레이로는 만들 수 없는 상태가 잡일 계측에 섞인다.
			if not m._is_farmable(t):
				continue
			if m.farm.hoe(t) and m.farm.plant(t, CropCatalog.HONRYEONGCHO):
				planted += 1
	return planted

func _watered_count(m: Node) -> int:
	var wet := 0
	for t in m.farm.planted_tiles():
		if m.farm.is_watered(t):
			wet += 1
	return wet

# 미호 ♡1..♡4 관문 비트가 전부 서 있는가(아크 판정의 재료 — ②가 실제로 관문을 통과했다는 증거).
func _arc_bits_set(m: Node, rid: String) -> bool:
	for h in range(1, m.HEART_GATE_MAX + 1):
		if not m._heart_bit_seen(rid, h):
			return false
	return true

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S8-T10 관계 장기 스모크 — 선물·관문·연애·결혼·이혼·재혼 전 사슬 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_dismiss_intro(m)
	m.onboarding.step = Onboarding.DONE
	var r_miho: Resident = m._resident("miho")
	var r_mel: Resident = m._resident("mel")
	var r_bana: Resident = m._resident("bana")

	# ── ① 세 채널 + 선물 리듬 ──────────────────────────────────────────────
	print("── ① 세 채널(대화·선물·활동) + 주 2회 ──")
	_park_in_one_week(m, r_miho, 2)
	r_miho.affinity.points = 0
	r_miho.affinity.stage = 0
	r_miho.affinity.last_talk_day = -1
	r_miho.affinity.last_gift_day = -1
	r_miho.affinity.gift_week = -1
	r_miho.affinity.gifts_this_week = 0
	m._run_harvested = 0                       # deed 미달 상태에서 시작(①e의 대조군)

	_check("①a 일일 대화 = +%d점" % Affinity.DAILY_TALK_POINTS,
		r_miho.affinity.daily_talk(m.clock.day)
		and r_miho.affinity.points == Affinity.DAILY_TALK_POINTS)
	_check("①b 같은 날 두 번째 대화는 점수 0(하루 1회)",
		not r_miho.affinity.daily_talk(m.clock.day)
		and r_miho.affinity.points == Affinity.DAILY_TALK_POINTS)

	var love_id: String = CropCatalog.YEONGHON_HOBAK      # 미호 러브(GiftPrefs OVERRIDES)
	var love_pts: int = GiftPrefs.points_for(GiftPrefs.LOVE, love_id, ItemCatalog.Q_NORMAL)
	var before_gift: int = r_miho.affinity.points
	_hold(m, love_id)
	m._try_resident_gift(r_miho)
	_check("①c 선물 = GiftPrefs 등급 반영(러브 %+d)" % love_pts,
		GiftPrefs.tier_of("miho", love_id) == GiftPrefs.LOVE
		and r_miho.affinity.points == before_gift + love_pts)

	var before_act: int = r_miho.affinity.points
	m._activity_credit("miho", 5)
	m._activity_credit("miho", 100)            # 캡을 넘겨 요청 — 남은 여력만 붙는다
	_check("①d 활동 적립은 일일 캡 %d에서 멈춘다" % Affinity.ACTIVITY_DAILY_CAP,
		r_miho.affinity.points == before_act + Affinity.ACTIVITY_DAILY_CAP
		and r_miho.affinity.activity_used_on(m.clock.day) == Affinity.ACTIVITY_DAILY_CAP)

	_check("①e 세 채널 합 = ♡1 만충 — 그러나 deed 미달이라 칸은 안 오른다(점수·진급 분리)",
		r_miho.affinity.points_hearts() >= 1 and r_miho.affinity.pending_promotion()
		and m._try_heart_promotion(r_miho).is_empty() and r_miho.affinity.stage == 0)

	_pass_day(m)
	_hold(m, love_id)
	m._try_resident_gift(r_miho)
	_check("①f 주 2회 — 이튿날 두 번째 선물은 통과(주 카운터 2/2)",
		r_miho.affinity.last_gift_day == m.clock.day
		and r_miho.affinity.gifts_used_in_week(m.clock.day) == Affinity.GIFTS_PER_WEEK)
	_pass_day(m)
	_hold(m, love_id)
	var held_before: int = m.inventory.count_of(love_id)
	m._try_resident_gift(r_miho)
	_check("①g 사흘째 세 번째 선물은 거절(같은 주 · 아이템 무소모)",
		r_miho.affinity.last_gift_day != m.clock.day
		and m.inventory.count_of(love_id) == held_before)

	# ── ② deed 원장 → 관문 진급 ♡1→♡4 ────────────────────────────────────
	print("── ② deed 원장 → 관문 진급 ──")
	m._run_harvested = Deed.MIHO_HARVEST[Deed.MIHO_HARVEST.size() - 1]   # ♡4 문턱까지 충족
	r_miho.affinity.points = Affinity.MAX_POINTS
	var gate: PackedStringArray = m._try_heart_promotion(r_miho)
	# ★[S9-T4 재작성] 관문 발화가 placeholder 1줄이던 시절엔 `size() == 1`이 곧 "발화가 있다"였다.
	#   S9-T4가 미호 본문을 넣어 줄 수가 늘었으므로, 재는 것을 **줄 수**에서 **발화의 존재와
	#   출처**로 바꾼다(계약은 그대로 — 관문이 통과되면 캐릭터의 말이 앞에 선다).
	_check("②a deed 충족 = 관문 통과(♡1) · 관문 발화가 캐릭터 본문으로 선다",
		not gate.is_empty() and String(gate[0]) != m.HEART_GATE_PLACEHOLDER_LINE
		and r_miho.affinity.stage == 1)
	_check("②b 비트 원장에 ♡1 기록", m._heart_bit_seen("miho", 1))

	m._start_resident_dialogue(r_miho)          # ★이음매 — 관문 트리거는 **대화 진입**이다
	_dismiss_intro(m)
	_check("②c 대화 진입이 관문을 연다(♡2 — 대화 한 번에 한 칸)",
		r_miho.affinity.stage == 2 and m._heart_bit_seen("miho", 2))

	m._try_heart_promotion(r_miho)
	m._try_heart_promotion(r_miho)
	_check("②d ♡4까지 도달 — 관문은 칸마다 하나씩",
		r_miho.affinity.stage == m.HEART_GATE_MAX and _arc_bits_set(m, "miho"))
	_check("②e ♡5는 관문이 아니다(의지 시험 대기) — 배지 '진급 대기'",
		m._try_heart_promotion(r_miho).is_empty()
		and r_miho.affinity.stage == m.HEART_GATE_MAX
		and m._heart_badge(r_miho) == "진급 대기")

	# ── ③ 고백(의지 시험) + 질투 ──────────────────────────────────────────
	print("── ③ 고백 + 질투 ──")
	r_mel.affinity.points = 100
	r_bana.affinity.points = 100
	m._resolve_confession("miho")
	_dismiss_intro(m)
	_check("③a 고백 = ♡5 진급 + 연애 슬롯",
		r_miho.affinity.stage == Affinity.MAX_HEARTS and m._romance_partner == "miho"
		and m._heart_bit_seen("miho", Affinity.MAX_HEARTS))
	_check("③b 질투 — 안 뽑힌 메인 2인 −%d점" % m.JEALOUSY_HIT,
		r_mel.affinity.points == 100 - m.JEALOUSY_HIT
		and r_bana.affinity.points == 100 - m.JEALOUSY_HIT)
	_check("③c 질투 원장 = 실제 깎인 양·복원 예정일 기록",
		int(m._jealousy.get("mel", {}).get("amount", 0)) == m.JEALOUSY_HIT
		and int(m._jealousy.get("mel", {}).get("restore_day", 0))
			== m.clock.day + m.JEALOUSY_RESTORE_DAYS)
	_check("③d 배지 = '연애 중'", m._heart_badge(r_miho) == "연애 중")

	# ── ④ 결혼 사슬(부적 → 안방 → 청혼 → 혼례 → 이주·해제·잡일) ─────────
	print("── ④ 결혼 사슬 ──")
	m.wallet.gold = m.WEDDING_CHARM_COST
	var charm_open: bool = m._charm_quest_open()      # 연애 상태에서만 열린다
	m._order_wedding_charm()
	_check("④a 부적 의뢰 = %d냥 차감 + 입수(연애 상태에서만 열린다)" % m.WEDDING_CHARM_COST,
		charm_open and m.wallet.gold == 0
		and m.inventory.has_item(ItemCatalog.WEDDING_CHARM))

	_stock(m, 10000, 300)
	m._try_order_build(Carpenter.PROJ_MASTER_ROOM)
	_pass_day(m)
	_pass_day(m)
	_check("④b 안방 확장 2일 완공 — 배우자 칸이 방 안에 든다",
		m._home_expanded() and m.home_house_rect().has_point(m.SPOUSE_HOME_TILE))
	_check("④c 속죄 아크 = ②가 세운 비트로 통과(판정식은 비트 원장 참조)",
		m._redemption_arc_complete("miho"))

	_hold(m, ItemCatalog.WEDDING_CHARM)
	var accept_day: int = m.clock.day
	m._try_resident_gift(r_miho)                # 부적을 건네는 것이 곧 청혼(선물 경로 인터셉트)
	_check("④d 청혼 수락 = %d일 후 혼례 예정 · 부적 소모 · 배지 '혼례 준비 중'" % m.WEDDING_WAIT_DAYS,
		m._wedding_day == accept_day + m.WEDDING_WAIT_DAYS
		and not m.inventory.has_item(ItemCatalog.WEDDING_CHARM)
		and m._heart_badge(r_miho) == "혼례 준비 중")
	_pass_day(m)
	_pass_day(m)
	_pass_day(m)
	_check("④e 예정일 아침 = 혼례(배우자 전이 · 배지 '부부')",
		m._spouse_id == "miho" and m._wedding_day == 0 and m._heart_badge(r_miho) == "부부")
	var last: Dictionary = r_miho.schedule[r_miho.schedule.size() - 1]
	_check("④f 이주 — HOME 귀가 스테이션 1항목(19시 · 안방 칸)",
		r_miho.schedule.size() == 3 and last["tile"] == m.SPOUSE_HOME_TILE
		and String(last["region"]) == RegionCatalog.HOME
		and r_miho.station_tile(20 * 60) == m.SPOUSE_HOME_TILE)

	r_miho.affinity.gift_week = GameClock.week_of(m.clock.day)
	r_miho.affinity.gifts_this_week = Affinity.GIFTS_PER_WEEK    # 주 상한 소진 상태
	r_miho.affinity.last_gift_day = -1
	_hold(m, CropCatalog.HONRYEONGCHO)
	m._try_resident_gift(r_miho)
	_check("④g 주 2회 해제 — 배우자는 상한 소진 상태에서도 통과(카운터 무소모)",
		r_miho.affinity.last_gift_day == m.clock.day
		and r_miho.affinity.gifts_this_week == Affinity.GIFTS_PER_WEEK)

	_park_before_calm_day(m)
	var planted: int = _plant_some(m, 10)
	_pass_day(m)
	_check("④h 미호 잡일 — 아침에 미급수 밭 %d칸을 적신다" % m.SPOUSE_MIHO_WATER_TILES,
		planted >= m.SPOUSE_MIHO_WATER_TILES
		and _watered_count(m) == m.SPOUSE_MIHO_WATER_TILES)

	# ── ⑤ 세이브 왕복 #1(혼인 중) ─────────────────────────────────────────
	print("── ⑤ 세이브 왕복 #1(혼인 중) ──")
	m._save_game()
	m.free()
	var m2: Node = await _new_main()            # _ready가 자동 복원
	_dismiss_intro(m2)
	var r2_miho: Resident = m2._resident("miho")
	_check("⑤a 혼인 상태가 부팅을 건넌다 — 배우자·확장 방·이주 스테이션",
		m2._spouse_id == "miho" and m2._home_expanded()
		and r2_miho.schedule.size() == 3
		and r2_miho.station_tile(20 * 60) == m2.SPOUSE_HOME_TILE)
	_check("⑤b 관계 상태도 보존 — ♡5 · 관문 비트 원장(♡1..♡5)",
		r2_miho.affinity.stage == Affinity.MAX_HEARTS
		and _arc_bits_set(m2, "miho")
		and m2._heart_bit_seen("miho", Affinity.MAX_HEARTS))

	# ── ⑥ 이혼 ────────────────────────────────────────────────────────────
	print("── ⑥ 이혼 ──")
	m2.wallet.gold = m2.DIVORCE_COST + 10000
	m2._request_divorce()
	_check("⑥a 1타 = 경고·래치 무장(상태 불변)",
		m2._divorce_armed and m2._spouse_id == "miho")
	m2._request_divorce()
	_check("⑥b 2타 = 결행 — %d냥 차감 · 혼인 해소" % m2.DIVORCE_COST,
		m2._spouse_id == "" and m2.wallet.gold == 10000 and not m2._divorce_armed)
	_check("⑥c ♡0 리셋(points·stage 동시) · 슬롯 해제 · 배지 소거",
		r2_miho.affinity.points == 0 and r2_miho.affinity.stage == 0
		and m2._romance_partner == "" and m2._heart_badge(r2_miho) == "")
	_check("⑥d 스케줄 원복 — HOME 귀가 스테이션 제거",
		r2_miho.schedule.size() == 2
		and r2_miho.station_tile(20 * 60) != m2.SPOUSE_HOME_TILE)
	_check("⑥e 면제 원장 기록 · 비트 원장은 잔존(재구애가 조용한 이유)",
		bool(m2._ever_married.get("miho", false)) and _arc_bits_set(m2, "miho"))

	# ── ⑦ 세이브 왕복 #2(이혼 후) ─────────────────────────────────────────
	print("── ⑦ 세이브 왕복 #2(이혼 후) ──")
	m2._save_game()
	m2.free()
	var m3: Node = await _new_main()
	_dismiss_intro(m3)
	var r3_miho: Resident = m3._resident("miho")
	_check("⑦a 이혼 상태가 부팅을 건넌다 — 미혼 · ♡0 · 면제 원장 보존",
		m3._spouse_id == "" and m3._romance_partner == ""
		and r3_miho.affinity.points == 0 and r3_miho.affinity.stage == 0
		and bool(m3._ever_married.get("miho", false)))
	_check("⑦b 스케줄도 원복된 채로 뜬다(부팅 재조립 = 결혼 전 2항목)",
		r3_miho.schedule.size() == 2)

	# ── ⑧ 재구애·재혼(면제) ───────────────────────────────────────────────
	print("── ⑧ 재구애·재혼 ──")
	m3._run_harvested = Deed.MIHO_HARVEST[Deed.MIHO_HARVEST.size() - 1]
	r3_miho.affinity.points = Affinity.MAX_POINTS
	var regate: PackedStringArray = m3._try_heart_promotion(r3_miho)
	_check("⑧a 관문 재진급은 조용하다(진급 O · 본 비트 재지급 없음)",
		regate.is_empty() and r3_miho.affinity.stage == 1)
	r3_miho.affinity.stage = Affinity.MAX_HEARTS - 1
	m3._resolve_confession("miho")
	_dismiss_intro(m3)
	_check("⑧b 재고백 = 조용한 수락(연애 재개 · ♡5)",
		m3._romance_partner == "miho"
		and r3_miho.affinity.stage == Affinity.MAX_HEARTS)
	m3.wallet.gold = m3.WEDDING_CHARM_COST
	_check("⑧c 부적 재의뢰가 열린다(정표 재수여 경로)", m3._charm_quest_open())
	m3._order_wedding_charm()
	m3._heart_bits["miho"] = 1 << Affinity.MAX_HEARTS   # 아크 비움 — 초혼이면 거절될 상태
	_hold(m3, ItemCatalog.WEDDING_CHARM)
	var re_accept: int = m3.clock.day
	m3._try_resident_gift(r3_miho)
	_check("⑧d 재혼 면제 — 아크 미완이어도 수락(♡5 재도달 + 정표만)",
		m3._wedding_day == re_accept + m3.WEDDING_WAIT_DAYS
		and not m3.inventory.has_item(ItemCatalog.WEDDING_CHARM))
	_pass_day(m3)
	_pass_day(m3)
	_pass_day(m3)
	_check("⑧e 재혼 성립 — 배우자 복귀 · 이주 재적용",
		m3._spouse_id == "miho" and r3_miho.schedule.size() == 3)
	m3.free()

	# 뒷정리 — 이 테스트가 만든 세이브를 지운다(다른 테스트의 자동 복원 오염 방지).
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ s8_relationship_smoke_test 전체 통과 ══")
	else:
		print("══ s8_relationship_smoke_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)
