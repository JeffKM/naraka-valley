extends SceneTree
# ★[S10-T2 / ADR-0069 결정 4 · ADR-0051 결정 5] 레어크로우 8종 완성 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 로스터 — 8종이 등재되고 전부 **비매 스택 CAT_MATERIAL**(기능·반경 동일한 순수 스킨).
#   ② 배치 원장 — 밑동 좌표 → 종 매핑·같은 종 중복 배치 불가·회수 시 그 종 그대로 반환.
#   ③ main 배치 배선 — 스프링클러 규칙 상속(양방향 겹침 금지)·설치/회수 시 인벤 소모/반환.
#   ④ 까마귀 보호 — 세운 레어크로우가 `_scarecrow_tiles()`에 합류하고, 그 반경 안 작물이 산다.
#   ⑤ **8종 완성 → 디럭스 반경**(BASE 8 → DELUXE 16 — crows.gd:18 예약의 이행).
#   ⑥ 수집 판정 = 소지 ∪ 배치(원장 없는 파생) · 버리기 금지가 그 파생의 근거.
#   ⑦ 획득처 배선 — ①혼백관 마일스톤 ②야시장 ③만물상 ④전령 ⑥더비 ⑦장원제(⑤⑧은 예약).
#   ⑧ 세이브 왕복 — 배치가 살아남고, 키 없는 구세이브는 배치 0(하위호환).
#
# ⚠️ 분모(8)는 ItemCatalog.RARECROWS 크기에서 파생한다(하드코딩 stale 금지 — 로스터가 늘면 따라온다).
#
# 실행: TIMEOUT=180 ./run_tests.sh rarecrow   (헤드리스는 반드시 game/에서 · 순차)

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

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

func _dismiss_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 80:
		m.dialogue.advance()
		guard += 1

func _clear_backpack(m: Node) -> void:
	for i in range(m.inventory.slots.size()):
		m.inventory.slots[i] = null
	m.inventory.changed.emit()

func _select(m: Node, id: String) -> void:
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

# 레어크로우를 세울 수 있는 빈 칸 n개를 찾는다(그리드 스캔 — sprinkler_test 결).
func _find_spots(m: Node, n: int) -> Array:
	var out: Array = []
	for y in range(m._outdoor_h):
		for x in range(m._grid_w):
			var t := Vector2i(x, y)
			if m._can_place_rarecrow(t):
				out.append(t)
				if out.size() >= n:
					return out
	return out

func _initialize() -> void:
	await _run()

func _run() -> void:
	print("══ S10-T2 레어크로우 8종 완성 검증 ══")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	_part_pure()
	await _part_main()
	await _part_r2()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(1 if _fail > 0 else 0)

# ══ 순수 층 ══════════════════════════════════════════════════════════════════
func _part_pure() -> void:
	# ── ① 로스터 ──
	print("── ① 8종 로스터 ──")
	var roster: Array = ItemCatalog.RARECROWS
	_check("①a 8종 등재", roster.size() == 8)
	var uniq: Dictionary = {}
	var reg_ok := true
	for id in roster:
		var sid := String(id)
		uniq[sid] = true
		if not ItemCatalog.has_item(sid) or ItemCatalog.name_of(sid) == "":
			reg_ok = false
		if ItemCatalog.category_of(sid) != ItemCatalog.CAT_MATERIAL or not ItemCatalog.stackable_of(sid):
			reg_ok = false
		if ItemCatalog.price_of(sid) != 0:      # 비매 — 팔 물건이 아니다
			reg_ok = false
		if not ItemCatalog.is_rarecrow(sid):
			reg_ok = false
	_check("①b 전부 등록된 비매 스택 CAT_MATERIAL(순수 스킨)", reg_ok)
	_check("①c 중복 id 없음", uniq.size() == roster.size())
	_check("①d 기존 2종이 로스터 앞머리(①②의 획득처가 그대로 유효)",
		String(roster[0]) == ItemCatalog.RARECROW_1 and String(roster[1]) == ItemCatalog.RARECROW_2)
	_check("①e 레어크로우가 아닌 id는 술어가 거짓", not ItemCatalog.is_rarecrow(ItemCatalog.HAY)
		and not ItemCatalog.is_rarecrow(""))
	_check("①f 원장 로스터 = 카탈로그 로스터(진실원 하나)",
		RarecrowLedger.roster_size() == roster.size() and RarecrowLedger.roster() == roster)

	# ── ② 배치 원장 ──
	print("── ② 배치 원장 ──")
	var led := RarecrowLedger.new()
	var a := Vector2i(3, 3)
	var b := Vector2i(9, 9)
	_check("②a 처음엔 배치 0", led.count() == 0 and led.tiles().is_empty()
		and led.id_at(a) == "" and not led.has_at(a))
	_check("②b 배치 = 밑동 좌표 → 종",
		led.place(a, ItemCatalog.RARECROW_1) and led.id_at(a) == ItemCatalog.RARECROW_1
		and led.has_at(a) and led.is_placed(ItemCatalog.RARECROW_1))
	_check("②c 같은 칸 재배치 불가(멱등)", not led.place(a, ItemCatalog.RARECROW_2))
	_check("②d **같은 종을 두 곳에 못 세운다**(세상에 한 마리뿐)",
		not led.place(b, ItemCatalog.RARECROW_1) and led.count() == 1)
	_check("②e 로스터 밖 id는 거절", not led.place(b, ItemCatalog.HAY) and led.count() == 1)
	_check("②f 다른 종은 다른 칸에 선다",
		led.place(b, ItemCatalog.RARECROW_2) and led.count() == 2
		and led.placed_ids().size() == 2)
	_check("②g 회수 = 그 종을 돌려준다",
		led.remove(a) == ItemCatalog.RARECROW_1 and not led.has_at(a)
		and not led.is_placed(ItemCatalog.RARECROW_1))
	_check("②h 빈 칸 회수 = 빈 문자열(무동작)", led.remove(a) == "" and led.count() == 1)

	# ── ⑧ 세이브 왕복(원장 층) ──
	print("── ⑧ 세이브 왕복(원장) ──")
	var led2 := RarecrowLedger.new()
	led2.load_save(led.to_save())
	_check("⑧a 왕복 — 좌표·종 보존",
		led2.count() == 1 and led2.id_at(b) == ItemCatalog.RARECROW_2)
	var led3 := RarecrowLedger.new()
	led3.load_save({})
	_check("⑧b 키 없는 구세이브 = 배치 0(하위호환)", led3.count() == 0)
	var led4 := RarecrowLedger.new()
	led4.load_save({"tiles": [[1, 1, "__nope__"], [2, 2, ItemCatalog.RARECROW_3],
		[3, 3, ItemCatalog.RARECROW_3], "쓰레기", [4]]})
	_check("⑧c 손상 행·사라진 종·중복 종은 조용히 버린다",
		led4.count() == 1 and led4.id_at(Vector2i(2, 2)) == ItemCatalog.RARECROW_3)

# ══ main 통합 층 ═════════════════════════════════════════════════════════════
func _part_main() -> void:
	var m: Node = await _spawn_main()
	_dismiss_dialogue(m)
	_check("③pre 부팅 = 안식 농원 · 원장 준비됨", m._region == RegionCatalog.HOME and m.rarecrow != null)
	_clear_backpack(m)

	# ── ③ main 배치 배선 ──
	print("── ③ main 배치(스프링클러 규칙 상속·인벤 소모/반환) ──")
	var spots := _find_spots(m, 3)
	_check("③pre 배치 가능한 빈 지면 3칸 확보", spots.size() >= 3)
	var p0: Vector2i = spots[0]
	m.inventory.add_item(ItemCatalog.RARECROW_1, 1)
	_select(m, ItemCatalog.RARECROW_1)
	m._target = p0
	m._place_rarecrow(p0, ItemCatalog.RARECROW_1)
	_check("③a 배치 = 인벤 1 소모 · 원장 등록",
		m.rarecrow.id_at(p0) == ItemCatalog.RARECROW_1 and m.inventory.count_of(ItemCatalog.RARECROW_1) == 0)
	_check("③b 그 칸엔 스프링클러도 못 놓는다(양방향 겹침 금지)",
		not m._can_place_sprinkler(p0) and not m._can_place_rarecrow(p0))
	# 스프링클러가 선 칸엔 레어크로우도 못 놓는다(반대 방향).
	var p1: Vector2i = spots[1]
	m.sprinkler.place(p1)
	_check("③c 스프링클러 칸엔 레어크로우 불가", not m._can_place_rarecrow(p1))
	m.sprinkler.remove(p1)
	m._place_rarecrow(p1, ItemCatalog.RARECROW_5)   # 안 가진 종
	_check("③d 안 가진 종은 배치 무동작", not m.rarecrow.has_at(p1))
	m._remove_rarecrow(p0)
	_check("③e 회수 = 인벤 반환(그 종 그대로)",
		not m.rarecrow.has_at(p0) and m.inventory.count_of(ItemCatalog.RARECROW_1) == 1)

	# ── ⑥ 수집 판정 = 소지 ∪ 배치 ──
	print("── ⑥ 수집 판정(소지 ∪ 배치) · 버리기 금지 ──")
	_check("⑥a 소지 = 수집됨", m._rarecrow_owned(ItemCatalog.RARECROW_1) and m._rarecrow_collected() == 1)
	m._place_rarecrow(p0, ItemCatalog.RARECROW_1)
	_check("⑥b 세워도 수집 유지(백팩을 떠나도 안 잃는다)",
		m.inventory.count_of(ItemCatalog.RARECROW_1) == 0
		and m._rarecrow_owned(ItemCatalog.RARECROW_1) and m._rarecrow_collected() == 1)
	# 버리기 금지 — 파생 판정이 단조 증가하는 근거.
	m.inventory.add_item(ItemCatalog.RARECROW_2, 1)
	var slot2 := -1
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == ItemCatalog.RARECROW_2:
			slot2 = i
	m._on_frame_discard(slot2)
	_check("⑥c 레어크로우는 버릴 수 없다(수집 완주 보호)",
		m.inventory.count_of(ItemCatalog.RARECROW_2) == 1)
	# ★[S10 폴리시] 선물 채널도 같은 금지다 — 여기가 뚫려 있어 파생 판정의 단조 증가가 깨졌다
	#   (건네면 DISLIKE로 소모 → `_rarecrow_owned`가 영영 false → 디럭스 반경 영구 미달성).
	var r_gift: Resident = m._resident("miho")
	r_gift.affinity.last_gift_day = -1
	r_gift.affinity.gift_week = -1
	r_gift.affinity.gifts_this_week = 0
	var pts_pre: int = r_gift.affinity.points
	var collected_pre: int = m._rarecrow_collected()
	m.inventory.select(slot2)
	m._try_resident_gift(r_gift)
	_check("⑥d 레어크로우는 선물로도 못 잃는다(소지·수집 수·호감도 전부 불변)",
		m.inventory.id_at(slot2) == ItemCatalog.RARECROW_2
		and m.inventory.count_of(ItemCatalog.RARECROW_2) == 1
		and m._rarecrow_collected() == collected_pre
		and r_gift.affinity.points == pts_pre)

	# ★[폴리시] 저장 상자도 같은 단조 증가에 속한다 — 상자는 카테고리 필터가 없어 레어크로우를
	#   그대로 받는데(집·갈무리방 둘 다), 소유 판정이 상자를 못 봐 넣는 순간 "안 가진 것"이 됐다.
	#   ⓐ 집 상자 · ⓑ 갈무리방 상자를 각각 태워 두 저장소 모두가 합집합에 드는지 본다.
	var owned_pre: int = m._rarecrow_collected()
	m._active_chest = m.chest
	m._on_frame_chest_store(slot2)
	_check("⑥e 전제 — 레어크로우 ②가 백팩을 떠나 집 상자에 들어갔다",
		m.inventory.count_of(ItemCatalog.RARECROW_2) == 0
		and m.chest.count_of(ItemCatalog.RARECROW_2) == 1)
	_check("⑥f ★집 상자에 넣어도 소유는 유지(수집 수 불변)",
		m._rarecrow_owned(ItemCatalog.RARECROW_2) and m._rarecrow_collected() == owned_pre)
	# ⓑ 집 상자에서 빼 갈무리방 상자로 옮긴다 — 두 상자는 서로 독립된 저장소다.
	m._on_frame_chest_take(0)
	var slot2b := -1
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == ItemCatalog.RARECROW_2:
			slot2b = i
	m._active_chest = m.storehouse_chest
	m._on_frame_chest_store(slot2b)
	_check("⑥g 전제 — 같은 레어크로우가 갈무리방 상자로 옮겨 갔다(집 상자는 비었다)",
		m.storehouse_chest.count_of(ItemCatalog.RARECROW_2) == 1
		and m.chest.count_of(ItemCatalog.RARECROW_2) == 0
		and m.inventory.count_of(ItemCatalog.RARECROW_2) == 0)
	_check("⑥h ★갈무리방 상자도 소유로 친다(두 저장소 모두 합집합)",
		m._rarecrow_owned(ItemCatalog.RARECROW_2) and m._rarecrow_collected() == owned_pre)
	# 만물상 1회 한정이 상자 보관분을 본다 — 여기가 뚫려 있어 같은 종을 또 결제할 수 있었다.
	m.wallet.earn(ItemCatalog.RARECROW_STORE_PRICE * 2)
	var gold_pre: int = m.wallet.gold
	_check("⑥i ★상자에 넣어 둔 종은 만물상에서 재구매되지 않는다(냥·개수 불변)",
		not m._try_buy_rarecrow(ItemCatalog.RARECROW_2)
		and m.wallet.gold == gold_pre
		and m.storehouse_chest.count_of(ItemCatalog.RARECROW_2) == 1
		and m.inventory.count_of(ItemCatalog.RARECROW_2) == 0)
	# 되돌려 놓는다(아래 ④⑤ 반경 단언은 '백팩 ∪ 밭' 상태를 전제로 센다).
	m._on_frame_chest_take(0)
	_check("⑥j 회수하면 다시 백팩으로(왕복 무손실)",
		m.inventory.count_of(ItemCatalog.RARECROW_2) == 1
		and m.storehouse_chest.count_of(ItemCatalog.RARECROW_2) == 0)

	# ── ④⑤ 까마귀 보호 반경 · 디럭스 ──
	print("── ④⑤ 까마귀 보호 · 8종 완성 디럭스 ──")
	_check("④a 세운 레어크로우가 허수아비 목록에 합류", m._scarecrow_tiles().has(p0))
	_check("④b 그 반경 안 칸은 보호됨(프롭 허수아비와 같은 판정)",
		CrowRaid.is_protected(p0 + Vector2i(1, 1), m._scarecrow_tiles(), m._scarecrow_radius()))
	_check("⑤a 미완성(2/8) = 기본 반경 8",
		m._rarecrow_collected() == 2 and not m._rarecrow_complete()
		and m._scarecrow_radius() == CrowRaid.BASE_RADIUS)
	# 나머지 6종을 손에 넣어 완성.
	for id in ItemCatalog.RARECROWS:
		if not m._rarecrow_owned(String(id)):
			m.inventory.add_item(String(id), 1)
	_check("⑤b 8종 완성 판정(분모 = 로스터 크기 파생)",
		m._rarecrow_collected() == ItemCatalog.RARECROWS.size() and m._rarecrow_complete())
	_check("⑤c 완성 → 디럭스 반경 16(crows.gd DELUXE_RADIUS 배선)",
		m._scarecrow_radius() == CrowRaid.DELUXE_RADIUS and CrowRaid.DELUXE_RADIUS == 16)
	# 반경이 실제 판정에 먹는다 — 기본 반경 밖·디럭스 반경 안인 칸이 보호로 바뀐다.
	# ★ 방향을 고정하지 않고 **네 방향 중 조건을 만족하는 칸**을 고른다: 안식에는 프롭 허수아비가
	#   둘 서 있어(37,15)·(46,15) 고정 방향 한 칸이 그 반경에 우연히 들면 단언이 무의미해진다.
	var far := Vector2i.ZERO
	var far_found := false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var cand: Vector2i = p0 + d * (CrowRaid.BASE_RADIUS + 2)
		if not CrowRaid.is_protected(cand, m._scarecrow_tiles(), CrowRaid.BASE_RADIUS):
			far = cand
			far_found = true
			break
	_check("⑤d pre 기본 반경 밖 칸을 찾았다", far_found)
	_check("⑤d 기본 반경 밖·디럭스 안 칸이 보호로 바뀐다(반경 확장에 이빨)",
		not CrowRaid.is_protected(far, m._scarecrow_tiles(), CrowRaid.BASE_RADIUS)
		and CrowRaid.is_protected(far, m._scarecrow_tiles(), m._scarecrow_radius()))

	# ── ⑦ 획득처 배선 ──
	print("── ⑦ 획득처 8슬롯 ──")
	# ① 혼백관 마일스톤(기존) — 레어크로우 ①이 마일스톤 보상 테이블에 그대로 있다.
	var milestone_has := false
	for row in Museum.MILESTONES:
		if String(row["reward_id"]) == ItemCatalog.RARECROW_1:
			milestone_has = true
	_check("⑦① 혼백관 마일스톤 보상에 레어크로우 ①(기존 창구 유지)", milestone_has)
	# ② 야시장(기존) — 매대 로스터의 한정 물품.
	_check("⑦② 야시장 한정 물품 = 레어크로우 ②(기존 창구 유지)",
		SeasonalEvent.MARKET_RARECROW == ItemCatalog.RARECROW_2)
	# ③ 만물상 재고 — 행 존재 + 실제 구매.
	var store_row := {}
	for r in m._store_items():
		if String(r.get("buy_id", "")) == ItemCatalog.RARECROW_3:
			store_row = r
	_check("⑦③a 만물상 매대에 레어크로우 ③ 행", not store_row.is_empty()
		and String(store_row["kind"]) == "rarecrow")
	# 소지 중이면 잠긴다(위 ⑤b에서 8종을 다 손에 넣었다).
	_check("⑦③b 이미 가지고 있으면 잠김", bool(store_row.get("locked", false)))
	# ④ 전령 우편 첨부 — 편지 존재 + 첨부 id.
	_check("⑦④ 전령 편지의 첨부 = 레어크로우 ④",
		Mailbox.has_letter(m.RARECROW_HERALD_LETTER)
		and String(Mailbox.attachment_items_of(m.RARECROW_HERALD_LETTER)[0]["id"]) == ItemCatalog.RARECROW_4)
	# ⑥ 더비 · ⑦ 장원제 상수.
	_check("⑦⑥⑦ 더비·장원제 부상 id",
		SeasonalEvent.DERBY_RARECROW == ItemCatalog.RARECROW_6
		and SeasonalEvent.GRANGE_RARECROW == ItemCatalog.RARECROW_7
		and SeasonalEvent.DERBY_RARECROW_EXCHANGES > 0)
	# ⑤·⑧은 예약 — 지금은 어느 창구도 이 둘을 내주지 않는다(로스터엔 있다).
	_check("⑦⑤⑧ ⑤(보부상)·⑧(시련장)은 로스터 등재만 — 창구 예약",
		ItemCatalog.is_rarecrow(ItemCatalog.RARECROW_5) and ItemCatalog.is_rarecrow(ItemCatalog.RARECROW_8)
		and SeasonalEvent.MARKET_RARECROW != ItemCatalog.RARECROW_5
		and SeasonalEvent.DERBY_RARECROW != ItemCatalog.RARECROW_8)

	# 획득처 지급 창구가 실제로 문다(1회 한정 · 보유 중이면 무동작).
	m.rarecrow.remove(p0)
	_clear_backpack(m)
	_check("⑦x0 백팩·밭을 비워 수집 0으로 되돌림", m._rarecrow_collected() == 0)
	_check("⑦⑥x 더비 부상 지급(1회 한정)",
		m._award_event_rarecrow(SeasonalEvent.DERBY_RARECROW, "낚시 더비")
		and m.inventory.count_of(ItemCatalog.RARECROW_6) == 1)
	_check("⑦⑥x2 두 번째 지급은 거절(이력 원장)",
		not m._award_event_rarecrow(SeasonalEvent.DERBY_RARECROW, "낚시 더비")
		and m.inventory.count_of(ItemCatalog.RARECROW_6) == 1)
	# ③ 만물상 구매 — 냥 차감·1회 한정.
	m.wallet.earn(ItemCatalog.RARECROW_STORE_PRICE * 2)
	var gold_before: int = m.wallet.gold
	_check("⑦③c 만물상 구매 성공 · 냥 차감",
		m._try_buy_rarecrow(ItemCatalog.RARECROW_3)
		and m.inventory.count_of(ItemCatalog.RARECROW_3) == 1 and m.wallet.gold < gold_before)
	_check("⑦③d 재구매 거절(보유 중)", not m._try_buy_rarecrow(ItemCatalog.RARECROW_3))
	_check("⑦③e 레어크로우가 아닌 id는 무동작", not m._try_buy_rarecrow(ItemCatalog.HAY))
	# ④ 전령 발송 조건 — 2종을 모은 다음 아침에 큐잉된다(send는 멱등).
	_check("⑦④pre 지금 2종 보유(문턱 충족)",
		m._rarecrow_collected() >= m.RARECROW_HERALD_THRESHOLD)
	m._on_day_advanced(2)
	_check("⑦④a 문턱 충족 아침에 전령 편지가 큐에 든다(당일 도착 없음)",
		m.mailbox.ever_sent(m.RARECROW_HERALD_LETTER) and not m.mailbox.inbox.has(m.RARECROW_HERALD_LETTER))
	m._on_day_advanced(3)
	_check("⑦④b 그 다음 아침에 도착(중복 발송 0)",
		m.mailbox.inbox.has(m.RARECROW_HERALD_LETTER) and m.mailbox.pending_count() == 0)

	# ── ⑧ main 세이브 왕복(배치가 이어하기를 건넌다) ──
	print("── ⑧ main 세이브 왕복 ──")
	var spots2 := _find_spots(m, 1)
	_check("⑧d pre 배치 가능한 칸이 남아 있다", not spots2.is_empty())
	var p2: Vector2i = spots2[0] if not spots2.is_empty() else Vector2i(-1, -1)
	m._place_rarecrow(p2, ItemCatalog.RARECROW_3)
	_check("⑧d pre 배치됨", m.rarecrow.id_at(p2) == ItemCatalog.RARECROW_3)
	m._save_game()
	m.rarecrow.remove(p2)
	m._load_game()
	_dismiss_dialogue(m)
	_check("⑧e main 왕복 — 배치 좌표·종 보존", m.rarecrow.id_at(p2) == ItemCatalog.RARECROW_3)
	# 구세이브(rarecrow 키 없음) 로드에서 크래시 없음.
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	raw.erase("rarecrow")
	m.saver.save_game(raw, m._active_slot, {})
	m._load_game()
	_dismiss_dialogue(m)
	# ★ 키가 없으면 main은 `load_save`를 **아예 안 부른다**(reclaim·sprinkler와 같은 관례) — 그래서
	#   인메모리 원장이 그대로 남는 것이 정상 거동이고, 노드 레벨 하위호환은 위 ⑧b가 이미 잠갔다.
	#   여기서 보는 것은 "구세이브를 읽어도 터지지 않는다"이다.
	_check("⑧f 구세이브(rarecrow 키 없음) 로드 = 크래시 없음 · 인메모리 원장 유지",
		m.rarecrow.id_at(p2) == ItemCatalog.RARECROW_3)

	await _despawn(m)

# ══ [폴리시 R2] 회수 손실 · 구역 가드 ════════════════════════════════════════
# 레어크로우는 재획득 경로가 전부 1회성으로 잠기므로(마일스톤·행사·보부상·시련패 매대), 한 마리를
# 잃으면 8종 완주 = 디럭스 반경이 영구히 막힌다. 그 두 유실 경로를 재현하고 봉합을 확인한다.
func _part_r2() -> void:
	print("── ⑨⑩ [폴리시 R2] 백팩 만원 회수 · 타 구역 원격 철거 ──")
	var m: Node = await _spawn_main()
	_dismiss_dialogue(m)
	_clear_backpack(m)
	var spots := _find_spots(m, 1)
	_check("⑨pre 세울 칸 확보", spots.size() >= 1)
	var t: Vector2i = spots[0]
	m.rarecrow.place(t, ItemCatalog.RARECROW_1)
	_check("⑨pre2 ①이 밭에 섰다 · 수집 판정 1종",
		m.rarecrow.id_at(t) == ItemCatalog.RARECROW_1 and m._rarecrow_collected() == 1)

	# ── ⑨ 백팩이 가득한 채 회수 ──
	# 남은 종을 백팩에 담고(수집 판정이 소지 ∪ 배치임을 함께 잠근다) 나머지 칸을 유품·책으로 메운다.
	var others := 0
	for id in ItemCatalog.RARECROWS:
		if String(id) != ItemCatalog.RARECROW_1 and m.inventory.add_item(String(id), 1):
			others += 1
	var pool: Array = Museum.donatable_ids()
	var pi := 0
	for i in range(m.inventory.slots.size()):
		if m.inventory.slots[i] == null and pi < pool.size():
			m.inventory.slots[i] = {"id": String(pool[pi]), "count": 1, "quality": 0}
			pi += 1
	m.inventory.changed.emit()
	_check("⑨a 준비 — 빈 슬롯 0 · 다른 %d종 소지 · ①은 밭에" % others,
		not m.inventory.has_free_slot() and m.inventory.count_of(ItemCatalog.RARECROW_1) == 0)
	m._remove_rarecrow(t)
	_check("⑨b **①이 세상에서 사라지지 않는다** — 밭에 그대로 서 있고 수집 판정도 유지",
		m.rarecrow.id_at(t) == ItemCatalog.RARECROW_1
		and m._rarecrow_owned(ItemCatalog.RARECROW_1)
		and m._rarecrow_collected() == ItemCatalog.RARECROWS.size())
	m.inventory.slots[m.inventory.slots.size() - 1] = null   # 자리를 하나 비운다
	m.inventory.changed.emit()
	m._remove_rarecrow(t)
	_check("⑨c 자리를 비우면 회수 성립 — 원장에서 내려오고 백팩에 그 종 그대로",
		not m.rarecrow.has_at(t) and m.inventory.count_of(ItemCatalog.RARECROW_1) == 1
		and m._rarecrow_collected() == ItemCatalog.RARECROWS.size())

	# ── ⑩ 타 구역 원격 철거 금지 ──
	m.rarecrow.place(t, ItemCatalog.RARECROW_1)
	var home_region: String = m._region
	_check("⑩a 안식 농원에서는 선 칸으로 읽힌다", m._rarecrow_at(t))
	m._region = RegionCatalog.MIHOK_FOREST
	_check("⑩b **다른 구역에서는 비어 보인다** — 보이지도 않는 곳에서 수집물이 옮겨지지 않는다",
		not m._rarecrow_at(t) and m.rarecrow.id_at(t) == ItemCatalog.RARECROW_1)
	m._region = home_region
	_check("⑩c 돌아오면 다시 읽힌다", m._rarecrow_at(t))
	await _despawn(m)
