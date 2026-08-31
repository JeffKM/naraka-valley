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
	# ★[S9-T7] 책 8권이 기증 대상에 합류해 분모가 3 → 11이 됐다(Museum.donatable_ids 주석).
	#   유품 3종이 **앞쪽 3좌**를 그대로 지키는지까지 본다(진열 인덱스 안정 = 좌대가 안 밀린다).
	_check("③f 트래커 분모 = 유품 3 + 책 8 = 11", Museum.donatable_ids().size() == 11)
	_check("③g 유품이 여전히 앞쪽 3좌", Museum.donatable_ids().slice(0, 3) == ItemCatalog.RELICS.keys())

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

	# ── ⑦ [폴리시 R2] 답례 지급 실패 시 claim 래치 금지 ──
	# 종전엔 `add_item` 반환값을 안 보고 곧바로 `museum.claim`이 문턱을 영구 래치해서, 백팩이 가득한
	# 채 3점을 채우면 답례(레어크로우 ① — 다른 획득처가 없다)가 지급 없이 증발하고 pending에서도
	# 빠졌다. 반딧넋 답례(`_claim_firefly_milestones`)가 지키는 "못 받으면 claim 안 한다" 1:1.
	print("── ⑦ [폴리시 R2] 답례 지급 실패 = claim 보류 ──")
	var m3: Node = await _spawn_main()
	await _settle(m3)
	m3.museum.donated = {}
	m3.museum.claimed = []
	var relics: Array = Museum.donatable_ids()
	# 전시 3점을 채운다(원장에 직접 — 기증 동작이 아니라 문턱 도달만 재현).
	var staged: Array = []
	for id in relics:
		if staged.size() >= 3:
			break
		if ItemCatalog.has_item(String(id)):
			m3.museum.donate(String(id), 1)
			staged.append(String(id))
	var reward_3 := ""
	for row in Museum.MILESTONES:
		if int(row["count"]) == 3:
			reward_3 = String(row["reward_id"])
	_check("⑦pre 전시 3점 도달 · count 3 답례가 레어크로우 ①(다른 획득처 없음)",
		staged.size() == 3 and reward_3 == ItemCatalog.RARECROW_1)
	_fill_backpack_full(m3.inventory)
	_check("⑦a 준비 — 빈 슬롯 0 · 레어크로우 ①은 아직 미지급",
		not m3.inventory.has_free_slot() and m3.inventory.count_of(ItemCatalog.RARECROW_1) == 0)
	var pend_before: int = m3.museum.pending_milestones().size()
	m3._claim_museum_milestones()
	_check("⑦b **claim이 서지 않는다** — 문턱이 pending에 그대로 남고 답례도 안 사라졌다",
		not m3.museum.claimed.has(1) and not m3.museum.claimed.has(3)
		and m3.museum.pending_milestones().size() == pend_before
		and m3.inventory.count_of(ItemCatalog.RARECROW_1) == 0)
	# 자리를 비우고 다시 오면 밀린 답례가 순서대로 들어온다(count 1·2·3).
	for i in range(m3.inventory.slots.size()):
		m3.inventory.slots[i] = null
	m3.inventory.changed.emit()
	var acted: bool = m3._claim_museum_milestones()
	_check("⑦c 자리를 비우면 밀린 답례가 전부 지급되고 claim이 선다",
		acted and m3.museum.claimed.has(1) and m3.museum.claimed.has(2) and m3.museum.claimed.has(3)
		and m3.inventory.count_of(ItemCatalog.RARECROW_1) == 1
		and m3.inventory.seed_count(CropCatalog.HONRYEONGCHO) == 5
		and m3.museum.pending_milestones().is_empty())
	_check("⑦d 더 줄 것이 없으면 이 창구는 소비되지 않는다(기증 안내가 그대로 뜬다)",
		not m3._claim_museum_milestones())
	m3.queue_free()
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

# ★[폴리시 R2 공용] 백팩을 **빈 슬롯 0**으로 채운다 — 되돌릴 수 없는 사건 앞의 무대 셋업.
#   슬롯에 직접 쓴다: `add_item`으로 채우면 같은 (id,품질)이 스택으로 합쳐져 칸이 안 준다.
#   종을 서로 다르게 섞는 것이 핵심이다(합류할 스택이 하나도 없어야 "가득"이 실효한다).
#   ★ `keep`에 든 슬롯 인덱스는 비워 둔다(자리를 하나만 남기는 함정 재현용).
#   ★ 풀은 유품·책(전부 스택 가능·서로 다른 종)이라 레어크로우·설치물 카운트를 오염시키지 않는다.
func _fill_backpack_full(inv: Inventory, keep: Array = []) -> void:
	var pool: Array = []
	for id in Museum.donatable_ids():
		pool.append(String(id))
	for i in range(inv.slots.size()):
		if keep.has(i):
			inv.slots[i] = null
			continue
		inv.slots[i] = {"id": String(pool[i]), "count": 1, "quality": 0} if i < pool.size() \
			else {"id": ItemCatalog.harvest_id(CropCatalog.PIANHWA), "count": 1,
				"quality": (i - pool.size()) % 4}
	inv.changed.emit()
