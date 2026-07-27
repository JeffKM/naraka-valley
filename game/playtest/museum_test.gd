extends SceneTree
# ★ [S2-T5 / ADR-0060 결정 5] 혼백관 전시 인프라 검증(ephemeral 헤드리스 단위검증).
# enterable 빈 방뿐이던 혼백관에 기증 원장·수집 트래커·마일스톤 보상·유품 발굴이 붙었는지 본다.
#
# ★ 핵심 불변식:
#   ① 유품 카탈로그 — RELICS 3종이 CAT_RELIC·이름·판매가를 갖고 has_item에 잡힌다(인벤 적재 가능).
#   ② 발굴 롤(relic_roll) — 결정적(같은 입력=같은 결과)·확률 ≈ DIG_ROLL_PERMIL/1000(전수 스캔)·
#      반환 id는 항상 RELICS 소속.
#   ③ 기증 원장 — donate=종당 1회(중복 거부)·비유품 거부·donated_count 증가·is_donated.
#   ④ 마일스톤 — count 도달분만 pending·claim 후 재지급 없음·테이블 보상 id 전부 유효 아이템.
#   ⑤ main 통합 — _try_donate_selected가 든 유품을 소모·원장 기록·보상 지급(인벤 반영)까지 잇는다.
#   ⑥ 세이브 라운드트립 — donated·claimed가 새 인스턴스로 재개(키 없는 구버전=빈 원장 하위호환).
# 실행: godot --headless --path game --script res://playtest/museum_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

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

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

func _initialize() -> void:
	print("══ S2-T5 혼백관 전시 인프라 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s2t5_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
		DirAccess.remove_absolute(SAVE)

	var m: Node = await _spawn_main()
	await _settle(m)

	# ── ① 유품 카탈로그 ──
	print("── ① 유품 카탈로그 ──")
	var relic_ids: Array = ItemCatalog.RELICS.keys()
	_check("①a 유품 3종", relic_ids.size() == 3)
	var cat_ok := true
	var item_ok := true
	var name_ok := true
	var price_ok := true
	for rid in relic_ids:
		if ItemCatalog.category_of(rid) != ItemCatalog.CAT_RELIC:
			cat_ok = false
		if not ItemCatalog.has_item(rid):
			item_ok = false
		if ItemCatalog.name_of(rid) == "":
			name_ok = false
		if ItemCatalog.price_of(rid) <= 0:
			price_ok = false
	_check("①b 전부 CAT_RELIC", cat_ok)
	_check("①c 전부 has_item(인벤 적재 가능)", item_ok)
	_check("①d 전부 이름 있음", name_ok)
	_check("①e 전부 판매가 > 0(중복 발굴분)", price_ok)
	_check("①f 레어크로우 ① = 유효 아이템·비매(0골드)",
		ItemCatalog.has_item(ItemCatalog.RARECROW_1) and ItemCatalog.price_of(ItemCatalog.RARECROW_1) == 0)

	# ── ② 발굴 롤(결정적·확률·소속) ──
	print("── ② 발굴 롤 ──")
	var r1 := Museum.relic_roll(7, Vector2i(30, 20))
	var r2 := Museum.relic_roll(7, Vector2i(30, 20))
	_check("②a 결정적(같은 입력=같은 결과)", r1 == r2)
	var hits := 0
	var total := 0
	var member_ok := true
	for day in range(1, 21):
		for x in range(20, 45):
			for y in range(15, 35):
				var rr := Museum.relic_roll(day, Vector2i(x, y))
				total += 1
				if rr != "":
					hits += 1
					if not ItemCatalog.RELICS.has(rr):
						member_ok = false
	var permil := hits * 1000.0 / total
	_check("②b 반환 id 전부 RELICS 소속", member_ok)
	_check("②c 확률 ≈ %d퍼밀(실측 %.1f — ±15 허용)" % [Museum.DIG_ROLL_PERMIL, permil],
		absf(permil - Museum.DIG_ROLL_PERMIL) <= 15.0)

	# ── ③ 기증 원장 ──
	print("── ③ 기증 원장 ──")
	var mus: Node = m.museum
	_check("③a 초기 기증 0", mus.donated_count() == 0)
	_check("③b 비유품 기증 거부", not mus.donate(ItemCatalog.HAY, 1))
	_check("③c 유품 기증 성공", mus.donate(ItemCatalog.RELIC_BINYEO, 3))
	_check("③d 같은 종 중복 거부", not mus.donate(ItemCatalog.RELIC_BINYEO, 4))
	_check("③e 카운트 1·is_donated", mus.donated_count() == 1 and mus.is_donated(ItemCatalog.RELIC_BINYEO))
	_check("③f 트래커 분모 = 기증 대상 전체(3)", Museum.donatable_ids().size() == 3)

	# ── ④ 마일스톤 ──
	print("── ④ 마일스톤 ──")
	var pend: Array = mus.pending_milestones()
	_check("④a 1점 도달 → pending 1건(count=1)", pend.size() == 1 and int(pend[0]["count"]) == 1)
	var reward_ok := true
	for row in Museum.MILESTONES:
		if not ItemCatalog.has_item(String(row["reward_id"])) or int(row["n"]) <= 0:
			reward_ok = false
	_check("④b 보상 테이블 전 행 = 유효 아이템·양수", reward_ok)
	mus.claim(1)
	_check("④c claim 후 재지급 없음", mus.pending_milestones().is_empty())
	mus.donate(ItemCatalog.RELIC_SPOON, 5)
	mus.donate(ItemCatalog.RELIC_KKOTSIN, 6)
	var pend2: Array = mus.pending_milestones()
	_check("④d 3점 도달 → count 2·3 pending", pend2.size() == 2
		and int(pend2[0]["count"]) == 2 and int(pend2[1]["count"]) == 3)

	# ── ⑤ main 통합(_try_donate_selected) ──
	print("── ⑤ main 기증 통합 ──")
	mus.donated = {}
	mus.claimed = []
	m.inventory.add_item(ItemCatalog.RELIC_BINYEO, 2)
	# 든 슬롯을 유품으로 — 유품 슬롯 인덱스를 찾아 선택.
	var slot := -1
	for i in m.inventory.SIZE:
		if m.inventory.id_at(i) == ItemCatalog.RELIC_BINYEO:
			slot = i
			break
	_check("⑤a 유품 인벤 적재·슬롯 발견", slot >= 0)
	m.inventory.selected_index = slot
	var seeds0: int = m.inventory.seed_count(CropCatalog.HONRYEONGCHO)
	m._try_donate_selected()
	_check("⑤b 기증 = 원장 기록·아이템 1개 소모",
		mus.is_donated(ItemCatalog.RELIC_BINYEO) and m.inventory.count_of(ItemCatalog.RELIC_BINYEO) == 1)
	_check("⑤c 마일스톤 1 보상(혼령초 씨앗 5) 지급",
		m.inventory.seed_count(CropCatalog.HONRYEONGCHO) == seeds0 + 5 and mus.claimed.has(1))
	m._try_donate_selected()
	_check("⑤d 중복 기증 무동작(원장·인벤 불변)",
		mus.donated_count() == 1 and m.inventory.count_of(ItemCatalog.RELIC_BINYEO) == 1)

	# ── ⑥ 세이브 라운드트립 ──
	print("── ⑥ 세이브 라운드트립 ──")
	mus.donate(ItemCatalog.RELIC_SPOON, 9)
	var save_donated: int = mus.donated_count()
	var save_claimed: Array = mus.claimed.duplicate()
	m._save_game()
	m.queue_free()
	await process_frame
	await process_frame
	var m2: Node = await _spawn_main()
	await _settle(m2)
	_check("⑥a donated 복원", m2.museum.donated_count() == save_donated
		and m2.museum.is_donated(ItemCatalog.RELIC_BINYEO) and m2.museum.is_donated(ItemCatalog.RELIC_SPOON))
	_check("⑥b claimed 복원", m2.museum.claimed == save_claimed)
	m2.queue_free()
	await process_frame

	# 정리 — 세이브 원복(다른 테스트·플레이 세이브 보호).
	DirAccess.remove_absolute(SAVE)
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(BAK)

	if _fail == 0:
		print("══ 결과: PASS (실패 0) ══")
	else:
		print("══ 결과: FAIL (실패 %d) ══" % _fail)
	quit(0 if _fail == 0 else 1)
