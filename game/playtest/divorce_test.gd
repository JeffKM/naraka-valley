extends SceneTree
# ★[S8-T8 / ADR-0066 결정 10] 이혼 — ADR-0022 이행(최소) 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 의뢰 노출 — 결혼 상태에서만(미혼 = 훅 무동작·프롬프트 꼬리 없음) · 옥자 [F] 창구 공유.
#   ② 2타 확인 — 1타 = 경고(상태 불변)·2타 = 결행 · 냥 부족은 무장 전에 끊는다.
#   ③ 이혼 효과 — 50,000냥 차감 · ♡0 리셋(points·stage 모두) · 슬롯 해제 · 스케줄 원복 ·
#      비트 원장 잔존 · 재혼 면제 원장 기록 · 질투 원장에서 전 배우자만 삭제.
#   ④ 잡일 정지 — spouse_id 파생이라 해제 즉시(아침 물주기 0칸).
#   ⑤ 재구애 — 본 비트 재지급 없음(관문 재진급은 조용하다) · 재고백도 조용한 수락.
#   ⑥ 재혼 면제 — 안방 확장·속죄 아크 게이트 건너뜀(♡5 재도달 + 정표 재수여만).
#   ⑦ 세이브 왕복 — ever_married 보존 · 재혼 상태 보존 · 구세이브(키 없음) = 빈 원장.
#
# 실행: ./run_tests.sh divorce   (헤드리스는 반드시 game/에서 · 순차)

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

# 지갑·원목을 정확히 맞춘다(marriage_test 헬퍼 동형).
func _stock(m: Node, gold: int, wood: int) -> void:
	m.wallet.gold = gold
	var have: int = m.inventory.count_of(ItemCatalog.WOOD)
	if have > wood:
		m.inventory.remove_item(ItemCatalog.WOOD, have - wood)
	elif have < wood:
		m.inventory.add_item(ItemCatalog.WOOD, wood - have)

# 아이템을 손에 든다(청혼 = 든 아이템 문법 — marriage_test 동형).
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
	while Weather.waters_field(Weather.weather_for_day(d)) or GameClock.is_season_first_day(d):
		d += 1
	m.clock.day = d - 1

# 결혼 상태까지 빠르게 세운다(marriage_test가 보증한 경로를 셋업으로 재사용):
# 연애(♡5) → 안방 확장(목공 2일) → 아크 비트 → 부적 의뢰 → 청혼 → 3일 후 혼례.
func _fast_marry(m: Node, r_miho: Resident) -> void:
	r_miho.affinity.points = Affinity.MAX_POINTS
	r_miho.affinity.stage = Affinity.MAX_HEARTS - 1
	m._resolve_confession("miho")
	_dismiss_intro(m)
	_stock(m, 10000, 300)
	m._try_order_build(Carpenter.PROJ_MASTER_ROOM)
	_pass_day(m)
	_pass_day(m)
	m._heart_bits["miho"] = int(m._heart_bits.get("miho", 0)) \
		| (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
	m.wallet.gold = 5000
	m._order_wedding_charm()
	_hold(m, ItemCatalog.WEDDING_CHARM)
	m._try_resident_gift(r_miho)
	_pass_day(m)
	_pass_day(m)
	_pass_day(m)

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S8-T8 이혼 — 해소 의뢰·♡0 리셋·재혼 면제 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_dismiss_intro(m)
	m.onboarding.step = Onboarding.DONE
	var r_miho: Resident = m._resident("miho")
	var r_okja: Resident = m._resident("okja")

	# ── ① 의뢰 노출(결혼 상태에서만) ──
	print("── ① 의뢰 노출 ──")
	m.wallet.gold = 60000
	m._request_divorce()
	_check("①a 미혼 = 해소 훅 무동작(골드 불변) · 프롬프트 꼬리 없음",
		m.wallet.gold == 60000 and String(r_okja.prompt_extra.call()) == "")
	_fast_marry(m, r_miho)
	_check("①b (셋업 확인) 결혼 성립 — 배우자·스케줄 이주",
		m._spouse_id == "miho" and r_miho.schedule.size() == 3)
	m.wallet.gold = 60000
	_check("①c 결혼 중 = 해소 의뢰 노출(프롬프트에 가격)",
		String(r_okja.prompt_extra.call()).contains("50000"))

	# ── ② 2타 확인 ──
	print("── ② 2타 확인 ──")
	m.wallet.gold = 100
	m._request_divorce()
	_check("②a 냥 부족 = 무장조차 안 된다(상태 불변)",
		not m._divorce_armed and m._spouse_id == "miho" and m.wallet.gold == 100)
	m.wallet.gold = 60000
	m._request_divorce()
	_check("②b 1타 = 경고·래치 무장(혼인·골드 불변)",
		m._divorce_armed and m._spouse_id == "miho" and m.wallet.gold == 60000)

	# 질투 원장 선별 삭제 검증용 씨앗 — 전 배우자(miho) 항목은 지워지고 멜 항목은 남아야 한다.
	m._jealousy["miho"] = {"restore_day": m.clock.day + 3, "amount": 10}
	var mel_entry: Dictionary = m._jealousy.get("mel", {"restore_day": m.clock.day + 3, "amount": 5})
	m._jealousy["mel"] = mel_entry

	# ── ③ 이혼 효과 ──
	print("── ③ 이혼 효과 ──")
	m._request_divorce()
	_check("③a 2타 = 결행 — 50,000냥 차감·혼인 해소",
		m._spouse_id == "" and m.wallet.gold == 10000 and not m._divorce_armed)
	_check("③b ♡0 리셋 — points·stage 모두(비트 원장은 잔존)",
		r_miho.affinity.points == 0 and r_miho.affinity.stage == 0
		and m._heart_bit_seen("miho", 1) and m._heart_bit_seen("miho", Affinity.MAX_HEARTS))
	_check("③c 연애 슬롯 해제 + 배지 소거",
		m._romance_partner == "" and m._heart_badge(r_miho) == "")
	_check("③d 스케줄 원복 — HOME 귀가 스테이션 제거(저녁 자리 = 결혼 전 파생)",
		r_miho.schedule.size() == 2
		and r_miho.station_tile(19 * 60 + 30) != m.SPOUSE_HOME_TILE)
	_check("③e 재혼 면제 원장 기록", bool(m._ever_married.get("miho", false)))
	_check("③f 질투 원장 — 전 배우자만 삭제(다른 이의 복원분은 그대로)",
		not m._jealousy.has("miho") and m._jealousy.has("mel"))
	m._jealousy.erase("mel")            # 씨앗 뒷정리(이후 날짜 진행에 안 섞이게)

	# ── ④ 잡일 정지(spouse_id 파생 — 해제 즉시) ──
	print("── ④ 잡일 정지 ──")
	_park_before_calm_day(m)
	var patch: Rect2i = m.STARTER_PATCH_RECT
	var planted := 0
	for dy in patch.size.y:
		for dx in patch.size.x:
			if planted >= 6:
				break
			var t := Vector2i(patch.position.x + dx, patch.position.y + dy)
			if m.farm.hoe(t) and m.farm.plant(t, CropCatalog.HONRYEONGCHO):
				planted += 1
	_pass_day(m)
	var wet := 0
	for t2 in m.farm.planted_tiles():
		if m.farm.is_watered(t2):
			wet += 1
	_check("④a 아침 물주기 잡일 정지(평온한 아침 · 젖은 칸 0)", planted > 0 and wet == 0)

	# ── ⑤ 재구애 — 본 비트 재지급 없음 ──
	print("── ⑤ 재구애 ──")
	m._run_harvested = 300              # 미호 deed 문턱(♡1..4) 전부 충족 — 관문은 비트만 가른다
	r_miho.affinity.points = Affinity.MAX_POINTS
	var gate: PackedStringArray = m._try_heart_promotion(r_miho)
	_check("⑤a 관문 재진급은 조용하다(진급 O · 이벤트 발화 없음)",
		gate.is_empty() and r_miho.affinity.stage == 1)
	r_miho.affinity.stage = Affinity.MAX_HEARTS - 1
	m._resolve_confession("miho")
	_check("⑤b 재고백 = 조용한 수락(연애 재개 · ♡5)",
		m._romance_partner == "miho" and r_miho.affinity.stage == Affinity.MAX_HEARTS)

	# ── ⑥ 재혼 면제(방·아크 게이트 건너뜀) ──
	print("── ⑥ 재혼 면제 ──")
	m.wallet.gold = 5000
	_check("⑥a 부적 재의뢰 열림(정표 재수여 경로)", m._charm_quest_open())
	m._order_wedding_charm()
	# 아크 비트를 비워 "미완" 상태를 만든다 — 초혼이라면 ③c(marriage_test)가 보증한 거절 경로.
	m._heart_bits["miho"] = 1 << Affinity.MAX_HEARTS
	_hold(m, ItemCatalog.WEDDING_CHARM)
	var accept_day: int = m.clock.day
	m._try_resident_gift(r_miho)
	_check("⑥b 아크 미완이어도 재혼 청혼은 수락(면제 플래그 — ♡5 + 정표만)",
		m._wedding_day == accept_day + 3
		and not m.inventory.has_item(ItemCatalog.WEDDING_CHARM))
	_pass_day(m)
	_pass_day(m)
	_pass_day(m)
	_check("⑥c 3일 후 재혼 성립 — 이주 재적용",
		m._spouse_id == "miho" and r_miho.schedule.size() == 3)

	# ── ⑦ 세이브 왕복 ──
	print("── ⑦ 세이브 왕복 ──")
	m._save_game()
	m.free()
	var m2: Node = await _new_main()     # _ready가 자동 복원
	var r2_miho: Resident = m2._resident("miho")
	_check("⑦a 재혼 상태 보존 — 배우자·이주 스테이션·면제 원장",
		m2._spouse_id == "miho" and r2_miho.schedule.size() == 3
		and bool(m2._ever_married.get("miho", false)))
	m2.free()
	cleaner.delete_save()
	var m3: Node = await _new_main()
	_dismiss_intro(m3)
	_check("⑦b 구세이브/신규 = 빈 면제 원장(초혼 게이트 정상 작동)",
		m3._ever_married.is_empty())
	m3.free()

	# 뒷정리 — 이 테스트가 만든 세이브를 지운다(다른 테스트의 자동 복원 오염 방지).
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ divorce_test 전체 통과 ══")
	else:
		print("══ divorce_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)
