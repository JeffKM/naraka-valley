extends SceneTree
# ★[S8-T7 / ADR-0066 결정 8·9] 결혼 — 혼례 부적·안방 확장·이주·도메인 잡일 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 부적 의뢰 — 연애 상태에서만 노출(훅·프롬프트) · 5,000냥 차감 · 유니크(보유 중 재노출 없음).
#   ② 안방 확장 — 목공 프로젝트(10,000냥+원목 300·2일) 완공 = HOME 방 rect 동쪽 확장 ·
#      그리드 바닥(HOUSE)·취침 zone("집")·home_deco bounds·집 카메라가 함께 넓어진다.
#   ③ 청혼 게이트 — 타인 불응·방 미완공·[메인] 속죄 아크(비트 1..4) 미완은 전부 거절 **무소모**.
#   ④ 수락 → 3일 후 아침 혼례 — spouse_id 상태 전이 · 배지 "부부" · 부적 소모.
#   ⑤ 이주 — 배우자 스케줄에 HOME 귀가 스테이션 1항목 append(19시 → 안방 칸).
#   ⑥ 주 2회 해제 — 주 상한 소진 상태에서도 배우자 선물은 통과(하루 1회는 유지·카운터 무소모).
#   ⑦ 도메인 잡일 — 미호=아침 미급수 8칸 물주기 · 멜=출하 정산 팁 +2% · 바나=자동 차단 +1.
#   ⑧ 세이브 왕복 — spouse_id·wedding_day 보존 · 확장 방 로드 복원 · 이주 스테이션 재적용 ·
#      구세이브(키 없음) = 미혼.
#   ⑨ ★[S9b-T6 / ADR-0068 결정 2] **뭍의 비약 = 세레나 결혼의 다리**([narrative-bible §5.3]) —
#      의뢰 창구의 순서(부적 먼저 · 부적을 쥐어야 비약) · 비약 없는 청혼의 **무소모 거절** ·
#      수락 시 **부적·비약 동반 소모** · 조연 혼례·이주가 메인과 같은 배관으로 도는가 ·
#      **옥자 트랙 무접촉**(비약은 마녀 *서비스*이지 옥자 호감도가 아니다 — 결정 10).
#
# ★[S9b-T6] ③d가 재작성됐다 — 옛 대조군(모찌)이 `ROMANCE_OPEN`에 들어오며 "명단 밖 = 자연
#   통과"의 표본이 아니게 됐다. 대조군은 점주(뱃사공)로 옮기고, 모찌는 같은 자리에서 **반대
#   방향**으로 다시 잰다(③d-2·③d-3 — 조연도 아크 게이트 대상이며, 비인간의 placeholder 관문도
#   비트가 진급에 찍히므로 자연 통과한다).
#
# 실행: ./run_tests.sh marriage   (헤드리스는 반드시 game/에서 · 순차)

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

func _dismiss_intro(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

func _pass_day(m: Node) -> void:
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)

# 지갑·원목을 정확히 맞춘다(carpenter_test 헬퍼 동형).
func _stock(m: Node, gold: int, wood: int) -> void:
	m.wallet.gold = gold
	var have: int = m.inventory.count_of(ItemCatalog.WOOD)
	if have > wood:
		m.inventory.remove_item(ItemCatalog.WOOD, have - wood)
	elif have < wood:
		m.inventory.add_item(ItemCatalog.WOOD, wood - have)

# 아이템을 손에 든다(선물/청혼 = 든 아이템 문법 — romance_test 동형).
func _hold(m: Node, id: String) -> void:
	if not m.inventory.has_item(id):
		m.inventory.add_item(id, 1, ItemCatalog.Q_NORMAL)
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

# 다음 "평온한 아침"(혼우 자동 급수 없음·절기 첫날 아님)을 골라 그 전날로 시계를 세운다 —
# 미호 물주기 잡일이 날씨 급수·절기 사멸과 섞이지 않게(판정은 전부 day 파생이라 결정적).
func _park_before_calm_day(m: Node) -> void:
	var d: int = m.clock.day + 1
	while Weather.waters_field(Weather.weather_for_day(d)) or GameClock.is_season_first_day(d):
		d += 1
	m.clock.day = d - 1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S8-T7 결혼 — 부적·안방 확장·이주·잡일 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_dismiss_intro(m)
	m.onboarding.step = Onboarding.DONE
	var r_miho: Resident = m._resident("miho")
	var r_mel: Resident = m._resident("mel")
	var r_okja: Resident = m._resident("okja")

	# ── ① 부적 의뢰(연애 상태에서만) ──
	print("── ① 부적 의뢰 ──")
	_check("①a 연애 전 = 의뢰 잠금(훅 false·프롬프트 꼬리 없음)",
		not m._charm_quest_open() and String(r_okja.prompt_extra.call()) == "")
	m.wallet.gold = 6000
	m._order_wedding_charm()
	_check("①b 잠금 중 호출은 무동작(골드·인벤 불변)",
		m.wallet.gold == 6000 and not m.inventory.has_item(ItemCatalog.WEDDING_CHARM))
	# 연애 개시(미호) — romance_test가 보증한 경로를 셋업으로 재사용.
	r_miho.affinity.points = Affinity.MAX_POINTS
	r_miho.affinity.stage = Affinity.MAX_HEARTS - 1
	m._resolve_confession("miho")
	_dismiss_intro(m)
	_check("①c 연애 중 = 의뢰 노출(프롬프트에 가격)",
		m._charm_quest_open() and String(r_okja.prompt_extra.call()).contains("5000"))
	m._order_wedding_charm()
	_check("①d 의뢰 = 5,000냥 차감 + 부적 입수",
		m.wallet.gold == 1000 and m.inventory.has_item(ItemCatalog.WEDDING_CHARM))
	_check("①e 보유 중 재노출 없음(부적은 세상에 하나)", not m._charm_quest_open())

	# ── ③ 청혼 게이트(방·아크·타인) — 확장 전이라 먼저 거절부터 본다 ──
	print("── ③ 청혼 게이트 ──")
	_hold(m, ItemCatalog.WEDDING_CHARM)
	m._try_resident_gift(r_mel)
	_check("③a 연인 아닌 이에겐 불응(무소모·무벌칙)",
		m._wedding_day == 0 and m.inventory.has_item(ItemCatalog.WEDDING_CHARM)
		and m._spouse_id == "")
	m._try_resident_gift(r_miho)
	_check("③b 안방 미완공 = 거절 · 부적 보존",
		m._wedding_day == 0 and m.inventory.has_item(ItemCatalog.WEDDING_CHARM))

	# ── ② 안방 확장(목공 프로젝트 → rect·zone·bounds·카메라) ──
	print("── ② 안방 확장 ──")
	_check("②a 확장 전 = 원본 rect·안방 칸은 방 밖",
		m.home_house_rect() == m.HOME_HOUSE_RECT
		and not m.home_house_rect().has_point(m.SPOUSE_HOME_TILE))
	_stock(m, 10000, 300)
	_check("②b 의뢰 성립(10,000냥+원목 300 차감)",
		m._try_order_build(Carpenter.PROJ_MASTER_ROOM)
		and m.inventory.count_of(ItemCatalog.WOOD) == 0)
	_pass_day(m)
	_check("②c 1일차 — 아직 공사 중", not m._home_expanded())
	_pass_day(m)
	_check("②d 2일차 아침 완공 = rect 동쪽 확장(원본은 부분집합 — 문·가구 좌표 보존)",
		m._home_expanded() and m.home_house_rect() == m.HOME_HOUSE_RECT_EXPANDED
		and m.home_house_rect().encloses(m.HOME_HOUSE_RECT))
	var st: Vector2i = m.SPOUSE_HOME_TILE
	_check("②e 안방 바닥이 실제 그리드에 선다(HOUSE) + 취침 zone '집' 포함",
		m._grid[st.y][st.x] == m.HOUSE
		and m._zone_at(Vector2(st.x * m.TILE + 8, st.y * m.TILE + 8)) == "집")
	_check("②f home_deco bounds 재주입 — 안방 칸이 배치 가능 · 원본 바닥도 유지",
		m.home_deco._floor_cells.has(st)
		and m.home_deco._floor_cells.has(Vector2i(10, 71)))
	_check("②g 집 카메라도 확장 rect로 교체(안방이 화면 밖에 잘리지 않게)",
		m._buildings["집"]["cam"] == m.HOME_HOUSE_CAM_RECT_EXPANDED)

	# ── ③(계속) 아크 게이트 → 수락 ──
	m._heart_bits = {}                    # 관문 비트를 비워 아크 미완을 만든다
	_hold(m, ItemCatalog.WEDDING_CHARM)
	m._try_resident_gift(r_miho)
	_check("③c [메인] 속죄 아크(비트 1..4) 미완 = 거절 · 부적 보존",
		m._wedding_day == 0 and m.inventory.has_item(ItemCatalog.WEDDING_CHARM))
	m._heart_bits = {"miho": (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)}
	# ★[S9b-T6 / ADR-0068 결정 2 재작성] 옛 ③d는 "명단 밖이라 자연 통과"의 대조군으로 모찌를
	#   썼는데, 모찌가 **명단 안으로 들어왔다**(T1 11인 전원 개통). 단언의 요지는 원문 그대로
	#   두고 — *판정은 비트 원장 참조이고 명단 밖은 무조건 통과* — 대조군을 영영 명단 밖인
	#   점주(뱃사공)로 옮긴다. ★그리고 모찌는 같은 자리에서 **반대 방향**으로 다시 잰다:
	#   비트가 비면 막히고, 비트가 서면 통과한다(③d-2) — 지시서 ⓐ가 확인을 요구한 그 지점이다.
	#   ㉠ 모찌는 ♡1·♡2·♡4 관문 **본문이 placeholder**인데, 비트는 *본문 유무*가 아니라 *진급*에
	#     찍히므로(`_mark_heart_bit`는 폴백 경로에서도 돈다) 비인간 3인의 "♡3 한 칸 집중" 구조가
	#     이 게이트에서 **자연 통과**한다. ㉡ 즉 판정식은 한 줄도 안 바뀌었고, 바뀐 것은 대상 집합뿐이다.
	_check("③d 아크 판정 = 비트 원장 참조(placeholder 자연 통과 — S9 주입에도 판정식 불변)",
		m._redemption_arc_complete("miho") and m._redemption_arc_complete("boatman"))
	_check("③d-2 ★조연도 이제 아크 게이트 대상이다(모찌 = 비트 0이면 막히고 · 1~4가 서면 통과)",
		m.ROMANCE_OPEN.has("mochi") and not m._redemption_arc_complete("mochi"))
	m._heart_bits["mochi"] = (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
	_check("③d-3 ★비인간의 ♡3 한 칸 집중 구조도 자연 통과한다(비트는 본문이 아니라 진급에 찍힌다)",
		m._redemption_arc_complete("mochi"))
	_hold(m, ItemCatalog.WEDDING_CHARM)
	var accept_day: int = m.clock.day
	m._try_resident_gift(r_miho)
	_check("③e 조건 충족 = 수락 — 혼례 예정(+3일) · 부적 소모",
		m._wedding_day == accept_day + 3
		and not m.inventory.has_item(ItemCatalog.WEDDING_CHARM))
	_check("③f 대기 중 배지 = '혼례 준비 중'", m._heart_badge(r_miho) == "혼례 준비 중")

	# ── ④ 혼례 아침 + ⑤ 이주 ──
	print("── ④ 혼례·⑤ 이주 ──")
	_pass_day(m)
	_pass_day(m)
	_check("④a 예정일 전엔 미혼(3일의 대기)", m._spouse_id == "")
	_pass_day(m)
	_check("④b 예정일 아침 = 혼례(상태 전이·예정 소거)",
		m._spouse_id == "miho" and m._wedding_day == 0)
	_check("④c 배지 = '부부'(연애 중보다 위)", m._heart_badge(r_miho) == "부부")
	var last: Dictionary = r_miho.schedule[r_miho.schedule.size() - 1]
	_check("⑤a 스케줄에 HOME 귀가 스테이션 1항목 append(19시 · 안방 칸 · HOME)",
		r_miho.schedule.size() == 3 and last["tile"] == m.SPOUSE_HOME_TILE
		and int(last["from_min"]) == Cafe.CLOSE_MIN
		and String(last["region"]) == RegionCatalog.HOME)
	_check("⑤b 저녁 스테이션 파생 = 안방(아침 밭·오후 카페는 그대로)",
		r_miho.station_tile(19 * 60 + 30) == m.SPOUSE_HOME_TILE
		and r_miho.station_tile(8 * 60) == m.MIHO_FIELD_TILE)
	m._apply_spouse_home_station()
	_check("⑤c 재적용은 멱등(중복 append 없음)", r_miho.schedule.size() == 3)

	# ── ⑥ 주 2회 해제(하루 1회 유지) ──
	print("── ⑥ 주 2회 해제 ──")
	r_miho.affinity.gift_week = GameClock.week_of(m.clock.day)
	r_miho.affinity.gifts_this_week = Affinity.GIFTS_PER_WEEK   # 주 상한 소진 상태를 만든다
	r_miho.affinity.last_gift_day = -1
	_check("⑥a 미혼 판정이면 이 주는 막혔다(대조군)",
		not r_miho.affinity.can_gift(m.clock.day, false, false))
	_hold(m, CropCatalog.HONRYEONGCHO)
	m._try_resident_gift(r_miho)
	_check("⑥b 배우자는 통과(하루 1회 소진 기록) · 주 카운터 무소모",
		r_miho.affinity.last_gift_day == m.clock.day
		and r_miho.affinity.gifts_this_week == Affinity.GIFTS_PER_WEEK)
	_hold(m, CropCatalog.HONRYEONGCHO)
	var day_used: int = r_miho.affinity.last_gift_day
	m._try_resident_gift(r_miho)
	_check("⑥c 같은 날 두 번째는 여전히 거절(하루 1회 유지)",
		r_miho.affinity.last_gift_day == day_used
		and m.inventory.has_item(CropCatalog.HONRYEONGCHO))

	# ── ⑦ 도메인 잡일 ──
	print("── ⑦ 도메인 잡일 ──")
	# ㉠ 미호 = 아침 미급수 8칸 물주기(평온한 아침을 골라 날씨 급수와 격리).
	_park_before_calm_day(m)
	var patch: Rect2i = m.STARTER_PATCH_RECT
	var planted := 0
	for dy in patch.size.y:
		for dx in patch.size.x:
			if planted >= 10:
				break
			var t := Vector2i(patch.position.x + dx, patch.position.y + dy)
			# ★[폴리시 R7] **경작 가능한 칸에만 심는다.** 종전엔 원장(hoe/plant)을 직접 불러
			#   `_is_farmable`을 우회했고, 패치 안의 예외 칸(미호 자리·삽사리 자리)까지 심어
			#   실제 플레이로는 만들 수 없는 상태를 세웠다. R7 이행 훅이 아침마다 삽사리 칸의
			#   밭 상태를 정리하므로(구세이브 구제), 그 칸을 세어 두면 잡일 계측이 흔들린다.
			if not m._is_farmable(t):
				continue
			if m.farm.hoe(t) and m.farm.plant(t, CropCatalog.HONRYEONGCHO):
				planted += 1
	_pass_day(m)
	var wet := 0
	var alive: Array = m.farm.planted_tiles()
	for t2 in alive:
		if m.farm.is_watered(t2):
			wet += 1
	_check("⑦a 미호 잡일 — 아침에 미급수 밭 %d칸을 적신다(심긴 10 중 8)" % m.SPOUSE_MIHO_WATER_TILES,
		wet == mini(m.SPOUSE_MIHO_WATER_TILES, alive.size()) and wet > 0)
	# ㉡ 멜 = 출하 정산 팁 +2%(잡일 판정은 spouse_id 파생이라 단위 스왑으로 검증).
	m._spouse_id = "mel"
	m.ship_bin.add(CropCatalog.HONRYEONGCHO, 10, ItemCatalog.Q_NORMAL)
	var base_gold: int = m.ship_bin.preview_gold()
	var wallet_before: int = m.wallet.gold
	_pass_day(m)
	var tip: int = maxi(1, base_gold * m.SPOUSE_MEL_TIP_PCT / 100)
	_check("⑦b 멜 잡일 — 출하 정산에 팁 +2%(최소 1골드)",
		base_gold > 0 and m.wallet.gold == wallet_before + base_gold + tip)
	# ㉢ 바나 = 밤 자동 차단 +1(매 프레임 파생 — 약탈 하한 1 불가침이라 차단 축으로 감쇄).
	m._spouse_id = "bana"
	await process_frame
	var bana_h: int = m.bana_affinity.hearts()
	_check("⑦c 바나 잡일 — 자동 차단 +1(약탈 하한 1은 무접촉)",
		m.night_bar.auto_block == BanaGuard.auto_block(bana_h) + m.SPOUSE_BANA_EXTRA_BLOCK
		and m.night_bar.raid_amount == BanaGuard.raid_amount(bana_h))
	m._spouse_id = "miho"                # 원상 복구(세이브 왕복은 미호 부부로)

	# ── ⑧ 세이브 왕복 ──
	print("── ⑧ 세이브 왕복 ──")
	m._save_game()
	m.free()
	var m2: Node = await _new_main()     # _ready가 자동 복원
	var r2_miho: Resident = m2._resident("miho")
	_check("⑧a 배우자 보존 + 배지 '부부'",
		m2._spouse_id == "miho" and m2._heart_badge(r2_miho) == "부부")
	_check("⑧b 확장 방 복원 — rect·그리드 바닥·deco bounds·카메라",
		m2._home_expanded() and m2.home_house_rect() == m2.HOME_HOUSE_RECT_EXPANDED
		and m2._grid[st.y][st.x] == m2.HOUSE
		and m2.home_deco._floor_cells.has(st)
		and m2._buildings["집"]["cam"] == m2.HOME_HOUSE_CAM_RECT_EXPANDED)
	_check("⑧c 이주 스테이션 재적용(스케줄은 부팅마다 재조립 — 로드가 다시 얹는다)",
		r2_miho.schedule.size() == 3
		and r2_miho.station_tile(20 * 60) == m2.SPOUSE_HOME_TILE)
	_check("⑧d 혼례 예정 없음(식은 이미 올렸다)", m2._wedding_day == 0)
	m2.free()
	# 구세이브(키 없음) = 미혼 — 세이브를 지우고 새로 시작해 기본값을 확인한다.
	cleaner.delete_save()
	var m3: Node = await _new_main()
	_dismiss_intro(m3)
	_check("⑧e 구세이브/신규 = 미혼·예정 없음·원본 방",
		m3._spouse_id == "" and m3._wedding_day == 0
		and m3.home_house_rect() == m3.HOME_HOUSE_RECT)

	# ── ⑨ ★[S9b-T6 / ADR-0068 결정 2 · narrative-bible §5.3] 뭍의 비약 = 세레나 결혼의 다리 ──
	# 물 밖에 못 나오는 인어라 청혼 수리에 **비약이 추가 전제**로 붙는다. 최소 기계화(아이템 1 +
	# 의뢰 훅 1 + 청혼 게이트 1)이므로 여기서 재는 것도 셋이다: 의뢰 창구의 **순서**, 비약 없는
	# 청혼의 **무소모 거절**, 그리고 수락 시 **부적·비약 동반 소모**.
	# ★ 판을 새로 깐다(m3 = 신규 세이브) — 세레나 경로는 미호와 상태가 겹치면 안 된다.
	print("── ⑨ 뭍의 비약(세레나 결혼) ──")
	m3.onboarding.step = Onboarding.DONE
	var r3_serena: Resident = m3._resident("serena")
	var r3_okja: Resident = m3._resident("okja")
	# 안방 확장 — ②가 태운 그 경로 그대로(공통 관문이라 세레나에게도 먼저 필요하다).
	_stock(m3, 10000, 300)
	m3._try_order_build(Carpenter.PROJ_MASTER_ROOM)
	_pass_day(m3)
	_pass_day(m3)
	# 연애 개시 + 속죄 아크 비트(조연도 이제 아크 게이트 대상 — ③d-2).
	r3_serena.affinity.points = Affinity.MAX_POINTS
	r3_serena.affinity.stage = Affinity.MAX_HEARTS - 1
	m3._resolve_confession("serena")
	_dismiss_intro(m3)
	m3._heart_bits = {"serena": (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)}
	m3.wallet.gold = 20000
	_check("⑨a 부적이 먼저다 — 부적 미보유면 비약 의뢰는 안 열린다(순서가 곧 안내)",
		m3._charm_quest_open() and not m3._elixir_quest_open()
		and String(r3_okja.prompt_extra.call()).contains("혼례 부적"))
	m3._order_wedding_charm()
	_check("⑨b 부적을 쥐면 그때 비약 의뢰가 열린다(같은 [F] 창구의 세 번째 얼굴)",
		m3._elixir_quest_open()
		and String(r3_okja.prompt_extra.call()).contains("뭍의 비약")
		and String(r3_okja.prompt_extra.call()).contains(str(m3.ELIXIR_COST)))
	# 비약 없이 청혼 — 인-픽션 거절 **무소모**(방·아크 게이트와 완전히 같은 결).
	_hold(m3, ItemCatalog.WEDDING_CHARM)
	m3._try_resident_gift(r3_serena)
	_check("⑨c ★비약 없는 청혼 = 거절 · **부적 보존**(무소모 — 받아 와서 다시 청하면 된다)",
		m3._wedding_day == 0 and m3._spouse_id == ""
		and m3.inventory.has_item(ItemCatalog.WEDDING_CHARM))
	var gold_before: int = m3.wallet.gold
	m3._order_okja_elixir()
	_check("⑨d 의뢰 = %d냥 차감 + 비약 입수 · 보유 중 재노출 없음(세상에 하나)" % m3.ELIXIR_COST,
		m3.wallet.gold == gold_before - m3.ELIXIR_COST
		and m3.inventory.has_item(ItemCatalog.OKJA_ELIXIR)
		and not m3._elixir_quest_open())
	_hold(m3, ItemCatalog.WEDDING_CHARM)
	var accept3: int = m3.clock.day
	m3._try_resident_gift(r3_serena)
	_check("⑨e ★조건 충족 = 수락 — 혼례 예정(+3일) · **부적·비약 둘 다 소모**",
		m3._wedding_day == accept3 + m3.WEDDING_WAIT_DAYS
		and not m3.inventory.has_item(ItemCatalog.WEDDING_CHARM)
		and not m3.inventory.has_item(ItemCatalog.OKJA_ELIXIR))
	# 혼례·이주까지 — 조연에게도 메인과 같은 배관이 그대로 돈다(이주 스케줄 일반화 확인).
	_pass_day(m3)
	_pass_day(m3)
	_pass_day(m3)
	var last3: Dictionary = r3_serena.schedule[r3_serena.schedule.size() - 1]
	_check("⑨f ★조연 혼례·이주가 메인과 같은 배관으로 돈다(귀가 스테이션 append · 기본 19시)",
		m3._spouse_id == "serena" and m3._heart_badge(r3_serena) == "부부"
		and last3["tile"] == m3.SPOUSE_HOME_TILE
		and int(last3["from_min"]) == Cafe.CLOSE_MIN
		and String(last3["region"]) == RegionCatalog.HOME)
	_check("⑨g ★배우자 대사가 캐릭터 본문으로 갈린다(spouse_lines 4축 — 일상 묶음이 아니다)",
		r3_serena.node.spouse_lines(m3.clock.day) != r3_serena.node.lines(5, true))
	# ★ 옥자 게이트 불가침([ADR-0068] 결정 10) — 비약은 *마녀 서비스*이지 옥자 트랙이 아니다.
	_check("⑨h ★옥자 트랙 무접촉 — 관계 트랙도 척추 원장도 한 칸 안 움직였다",
		r3_okja.affinity == null and m3._spine_bits == 0)
	m3.free()

	# 뒷정리 — 이 테스트가 만든 세이브를 지운다(다른 테스트의 자동 복원 오염 방지).
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ marriage_test 전체 통과 ══")
	else:
		print("══ marriage_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)
