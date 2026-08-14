extends SceneTree
# ★ [S10-T6 / ADR-0069 결정 9] 명부 도감(codex.gd + main 배선) 검증(ephemeral 헤드리스).
# "출하대에 한 번이라도 올린 것이 스스로 이름을 얻는다"가 코드로 성립하는지 본다.
#
# ★ 핵심 불변식:
#   ① 분모 파생 — 다섯 칸(작물·어종·채집물·광물·요리)이 **원천 카탈로그에서만** 나온다.
#      ★ 카운트만 세지 않는다(S10-T5 교훈): 각 칸의 **구성 요소**를 명시로 짚는다 —
#        작물 칸은 수확물 id로 서고, 요리 칸은 융합만이며 기본 메뉴 4종은 **없다**.
#   ② 출하 → 등재 — 정산이 확정된 아침에 이름이 서고, 첫 출하 day가 남는다.
#   ③ 미출하 미등재 — 넣었다 뺀 것(롤백)·인벤에 든 것·해금만 된 요리는 안 적힌다.
#   ④ 비추적 id — 유품·자재는 출하해도 원장에 한 톨도 안 남는다(추적 풀 밖).
#   ⑤ 세이브 왕복 — 등재·트로피 래치가 새 인스턴스로 재개(키 없는 구세이브 = 빈 원장).
#   ⑥ 완주 트로피 — 전 분모 등재 시 완주 판정, 래치는 **1회성**(재정산 중복 발화 0).
#   ⑦ main 통합 — codex 인스턴스·정산 훅·열람대 좌표·프롬프트 배선.
# 실행: godot --headless --path game --script res://playtest/codex_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _settle_frames(m: Node) -> void:
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

# 인벤토리에서 id를 든 첫 슬롯 인덱스(-1=없음).
func _slot_of(m: Node, id: String) -> int:
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == id:
			return i
	return -1

func _initialize() -> void:
	print("══ S10-T6 명부 도감(codex.gd) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.codex_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 분모 파생(순수 static — main 인스턴스 불필요) ──
	print("── ① 분모 파생(원천 카탈로그) ──")
	var crop_ids: Array = Codex.category_ids(Codex.CAT_CROP)
	var fish_ids: Array = Codex.category_ids(Codex.CAT_FISH)
	var forage_ids: Array = Codex.category_ids(Codex.CAT_FORAGE)
	var mineral_ids: Array = Codex.category_ids(Codex.CAT_MINERAL)
	var cook_ids: Array = Codex.category_ids(Codex.CAT_COOK)

	# ①a 작물 — 크기 + **구성**(전부 수확물 id로 서 있고, 대표 종이 실제로 들어 있다).
	var crop_is_harvest := true
	for cid in crop_ids:
		if not CropCatalog.has_crop(String(cid)):
			crop_is_harvest = false
	_check("①a 작물 분모 = CropCatalog.ids() 크기(%d)" % CropCatalog.ids().size(),
		crop_ids.size() == CropCatalog.ids().size())
	_check("①b 작물 칸 = 수확물 id 구성(혼령초·불사과 실존)", crop_is_harvest
		and crop_ids.has(ItemCatalog.harvest_id(CropCatalog.HONRYEONGCHO))
		and crop_ids.has(ItemCatalog.harvest_id(CropCatalog.BULSAGWA)))

	# ①c 어종 — 크기 + 구성(대표 3종 실존 · 전부 FishCatalog 소속).
	var fish_member := true
	for fid in fish_ids:
		if not FishCatalog.has(String(fid)):
			fish_member = false
	_check("①c 어종 분모 = FishCatalog.ids() 크기(%d)" % FishCatalog.ids().size(),
		fish_ids.size() == FishCatalog.ids().size())
	_check("①d 어종 칸 구성(넋붕어·저녁놀도미·혼불해파리 실존 · 전부 어류)", fish_member
		and fish_ids.has(FishCatalog.NEOK_BUNGEO) and fish_ids.has(FishCatalog.JEONYEOKNOL_DOMI)
		and fish_ids.has(FishCatalog.HONBUL_HAEPARI))

	# ①e 채집물 — 크기 + 구성(피안화·넋송이버섯 실존).
	_check("①e 채집물 분모 = FORAGEABLES 크기(%d)" % ItemCatalog.FORAGEABLES.size(),
		forage_ids.size() == ItemCatalog.FORAGEABLES.size())
	_check("①f 채집물 칸 구성(피안화·넋송이버섯 실존)",
		forage_ids.has(ItemCatalog.SPIRIT_FLOWER) and forage_ids.has(ItemCatalog.NEOK_SONGI))

	# ①g 광물 — 크기 + 구성(돌·넋수정 실존 · 주괴는 **불포함** = 다른 dict).
	_check("①g 광물 분모 = MINERALS 크기(%d)" % ItemCatalog.MINERALS.size(),
		mineral_ids.size() == ItemCatalog.MINERALS.size())
	_check("①h 광물 칸 구성(돌·넋수정 실존 · 주괴 명동 불포함)",
		mineral_ids.has(ItemCatalog.STONE) and mineral_ids.has(ItemCatalog.GEM_NEOKSUJEONG)
		and not mineral_ids.has(ItemCatalog.INGOT_MYEONGDONG))

	# ①i 요리 — 크기 + 구성(융합 실존 · **기본 메뉴 4종 전부 불포함**).
	var no_basics := true
	for bid in MenuCatalog.basic_ids():
		if cook_ids.has(String(bid)):
			no_basics = false
	_check("①i 요리 분모 = fusion_ids() 크기(%d)" % MenuCatalog.fusion_ids().size(),
		cook_ids.size() == MenuCatalog.fusion_ids().size())
	_check("①j 요리 칸 구성(혼령초 라떼·넋붕어빵 실존 · 기본 메뉴 4종 0개)", no_basics
		and cook_ids.has(MenuCatalog.HONRYEONGCHO_LATTE) and cook_ids.has(MenuCatalog.BUNGEO_PPANG))

	# ①k 총 분모 = 다섯 칸 합(중복 0) · 전 id가 유효 아이템(이름 있음).
	var sum_cat := crop_ids.size() + fish_ids.size() + forage_ids.size() + mineral_ids.size() + cook_ids.size()
	var all_ids: Array = Codex.tracked_ids()
	var valid_all := true
	for tid in all_ids:
		if not ItemCatalog.has_item(String(tid)) or ItemCatalog.name_of(String(tid)) == "":
			valid_all = false
	_check("①k 총 분모 = 다섯 칸 합 %d(중복 0)" % sum_cat, all_ids.size() == sum_cat
		and Codex.total_count() == sum_cat)
	_check("①l 추적 전 id = 유효 아이템·이름 있음", valid_all)

	# ①m 소속 판정 — 대표 id의 칸이 맞고, 풀 밖(유품·책·도구·씨앗·자재)은 "" 이다.
	_check("①m category_of 소속(작물·어종·요리)",
		Codex.category_of(CropCatalog.HONRYEONGCHO) == Codex.CAT_CROP
		and Codex.category_of(FishCatalog.NEOK_BUNGEO) == Codex.CAT_FISH
		and Codex.category_of(MenuCatalog.HONRYEONGCHO_LATTE) == Codex.CAT_COOK)
	_check("①n 풀 밖 미추적(유품·도구·씨앗·건초)",
		not Codex.is_tracked(ItemCatalog.RELIC_BINYEO) and not Codex.is_tracked(ItemCatalog.HOE)
		and not Codex.is_tracked(ItemCatalog.seed_id(CropCatalog.HONRYEONGCHO))
		and not Codex.is_tracked(ItemCatalog.HAY))
	_check("①o 칸별 분모 합계 = category_total 합",
		Codex.category_total(Codex.CAT_CROP) + Codex.category_total(Codex.CAT_FISH)
		+ Codex.category_total(Codex.CAT_FORAGE) + Codex.category_total(Codex.CAT_MINERAL)
		+ Codex.category_total(Codex.CAT_COOK) == sum_cat)

	var m: Node = await _spawn_main()
	await _settle_frames(m)

	# ── ⑦ main 통합(먼저 확인 — 아래 시나리오가 전부 이 배선 위에 선다) ──
	print("── ⑦ main 통합 ──")
	_check("⑦a codex 인스턴스 존재(자식 노드)", m.codex != null and m.get_node_or_null("Codex") != null)
	_check("⑦b 초기 원장 = 빈 상태(신규 세이브)", m.codex.shipped_count() == 0 and not m.codex.has_trophy())
	_check("⑦c 열람대 좌표 = 기증대와 다른 칸·혼백관 방 안",
		m.MUSEUM_CODEX_TILE != m.MUSEUM_DONATE_TILE and m.MUSEUM_RECT.has_point(m.MUSEUM_CODEX_TILE))
	_check("⑦d 도감 본문 = 머리말 + 카테고리 5줄(원장 파생)",
		m._codex_lines().size() == 1 + Codex.CATEGORIES.size())

	# ── ② 출하 → 등재 ──
	print("── ② 출하 → 등재 ──")
	m.ship_bin.pending.clear()
	m.codex.shipped.clear()
	var crop: String = CropCatalog.HONRYEONGCHO
	m.inventory.add_harvest(crop, 3)
	var hslot := _slot_of(m, crop)
	_check("②pre 수확물 슬롯 확보", hslot >= 0)
	m._on_frame_deposit(hslot)
	_check("②a 정산 전에는 미등재(출하함 대기일 뿐)",
		m.ship_bin.count_of(crop) == 3 and not m.codex.is_shipped(crop))
	var day1: int = m.clock.day
	m._on_day_advanced(day1)
	_check("②b 정산 아침에 등재", m.codex.is_shipped(crop) and m.codex.shipped_count() == 1)
	_check("②c 첫 출하 day 기록", m.codex.first_day_of(crop) == day1)
	_check("②d 작물 칸 분자 1 · 이름 등재", m.codex.category_shipped(Codex.CAT_CROP) == 1
		and m.codex.category_names_shipped(Codex.CAT_CROP).has(CropCatalog.name_of(crop)))
	# 재출하해도 첫 day는 안 덮인다(첫 출하 기록의 의미).
	m.ship_bin.add(crop, 1)
	m._on_day_advanced(day1 + 5)
	_check("②e 재출하는 첫 day를 덮지 않는다", m.codex.first_day_of(crop) == day1)
	# ★[S10-T6] 넓어진 출하 판정 — 광물·요리가 출하대에 들어간다(도감 다섯 칸이 전부 살아 있다).
	m.ship_bin.pending.clear()
	m.inventory.add_item(ItemCatalog.GEM_NEOKSUJEONG, 1)
	var mslot := _slot_of(m, ItemCatalog.GEM_NEOKSUJEONG)
	m.inventory.add_item(MenuCatalog.HONRYEONGCHO_LATTE, 1)
	var kslot := _slot_of(m, MenuCatalog.HONRYEONGCHO_LATTE)
	_check("②pre2 광물·요리 슬롯 확보", mslot >= 0 and kslot >= 0)
	m._on_frame_deposit(mslot)
	m._on_frame_deposit(kslot)
	_check("②f 광물·요리도 출하 가능(도감 추적 대상)",
		m.ship_bin.count_of(ItemCatalog.GEM_NEOKSUJEONG) == 1
		and m.ship_bin.count_of(MenuCatalog.HONRYEONGCHO_LATTE) == 1)
	m._on_day_advanced(day1 + 6)
	_check("②g 광물·요리 등재 + 칸 분자 1씩",
		m.codex.is_shipped(ItemCatalog.GEM_NEOKSUJEONG)
		and m.codex.is_shipped(MenuCatalog.HONRYEONGCHO_LATTE)
		and m.codex.category_shipped(Codex.CAT_MINERAL) == 1
		and m.codex.category_shipped(Codex.CAT_COOK) == 1)

	# ── ③ 미출하 미등재 ──
	print("── ③ 미출하 미등재 ──")
	m.ship_bin.pending.clear()
	var crop2: String = CropCatalog.PIANHWA
	m.inventory.add_harvest(crop2, 2)
	var hslot2 := _slot_of(m, crop2)
	m._on_frame_deposit(hslot2)
	m._on_frame_takeback(crop2)          # 취침 전 롤백 — 아직 "출하한" 것이 아니다
	_check("③pre 롤백으로 출하함 비움", m.ship_bin.count_of(crop2) == 0)
	m._on_day_advanced(day1 + 7)
	_check("③a 넣었다 뺀 것은 미등재", not m.codex.is_shipped(crop2))
	# 인벤에 들고만 있는 것 · 해금만 된 요리도 미등재(출하대 단일 창구).
	var crop3: String = CropCatalog.YEONGHON_HOBAK
	m.inventory.add_harvest(crop3, 1)
	m.inventory.add_item(MenuCatalog.BUNGEO_PPANG, 1)
	m._on_day_advanced(day1 + 8)
	_check("③b 인벤 보유·요리 소지만으로는 미등재",
		not m.codex.is_shipped(crop3) and not m.codex.is_shipped(MenuCatalog.BUNGEO_PPANG))

	# ── ④ 비추적 id ──
	print("── ④ 비추적 id ──")
	var before4: int = m.codex.shipped_count()
	m.ship_bin.pending.clear()
	m.ship_bin.add(ItemCatalog.RELIC_BINYEO, 1)   # 유품 = 추적 풀 밖
	m.ship_bin.add(ItemCatalog.HAY, 2)            # 건초(자재) = 추적 풀 밖
	m._on_day_advanced(day1 + 9)
	_check("④a 유품·자재는 출하해도 원장 불변",
		m.codex.shipped_count() == before4 and not m.codex.is_shipped(ItemCatalog.RELIC_BINYEO)
		and not m.codex.is_shipped(ItemCatalog.HAY))
	# 출하 판정 자체도 여전히 유품·씨앗·도구를 거절한다(넓힘이 새지 않았다).
	m.ship_bin.pending.clear()
	m.inventory.add_item(ItemCatalog.RELIC_BINYEO, 1)
	var rslot := _slot_of(m, ItemCatalog.RELIC_BINYEO)
	var sslot := _slot_of(m, ItemCatalog.seed_id(CropCatalog.HONRYEONGCHO))
	var tslot := _slot_of(m, ItemCatalog.HOE)
	if rslot >= 0:
		m._on_frame_deposit(rslot)
	if sslot >= 0:
		m._on_frame_deposit(sslot)
	if tslot >= 0:
		m._on_frame_deposit(tslot)
	_check("④b 유품·씨앗·도구 드롭 거절(출하함 여전히 빔)", m.ship_bin.is_empty())

	# ── ⑥ 완주 트로피(1회성 연출) ──
	print("── ⑥ 완주 트로피 ──")
	m.codex.shipped.clear()
	m.codex.trophy_day = -1
	_check("⑥a 빈 원장은 미완주", not m.codex.is_complete() and not m.codex.trophy_pending())
	var all_tracked: Array = Codex.tracked_ids()
	for i in all_tracked.size() - 1:
		m.codex.record(String(all_tracked[i]), 3)
	_check("⑥b 한 칸 남으면 아직 미완주",
		not m.codex.is_complete() and m.codex.shipped_count() == all_tracked.size() - 1)
	m.codex.record(String(all_tracked[all_tracked.size() - 1]), 3)
	_check("⑥c 전 분모 등재 = 완주 판정 · 트로피 대기",
		m.codex.is_complete() and m.codex.trophy_pending() and not m.codex.has_trophy())
	m.ship_bin.pending.clear()
	var trophy_day: int = day1 + 10
	m._on_day_advanced(trophy_day)
	_check("⑥d 정산 직후 트로피 1회 발화(래치 기록)",
		m.codex.has_trophy() and m.codex.trophy_day == trophy_day and not m.codex.trophy_pending())
	m._on_day_advanced(trophy_day + 1)
	_check("⑥e 재정산에도 중복 발화 0(래치 불변)", m.codex.trophy_day == trophy_day)
	_check("⑥f claim_trophy 재호출 거부", not m.codex.claim_trophy(trophy_day + 99)
		and m.codex.trophy_day == trophy_day)
	_check("⑥g 완주 뒤 본문에 맺음말 1줄 추가",
		m._codex_lines().size() == 2 + Codex.CATEGORIES.size())

	# ── ⑤ 세이브 왕복 ──
	print("── ⑤ 세이브 왕복 ──")
	m.codex.shipped.clear()
	m.codex.trophy_day = -1
	m.codex.record(crop, 4)
	m.codex.record(FishCatalog.NEOK_BUNGEO, 6)
	m.codex.claim_trophy(11)
	var save_count: int = m.codex.shipped_count()
	m._save_game()
	m.queue_free()
	await process_frame
	await process_frame
	var m2: Node = await _spawn_main()
	await _settle_frames(m2)
	_check("⑤a 등재 복원(개수·id·첫 day)", m2.codex.shipped_count() == save_count
		and m2.codex.is_shipped(crop) and m2.codex.first_day_of(crop) == 4
		and m2.codex.is_shipped(FishCatalog.NEOK_BUNGEO))
	_check("⑤b 트로피 래치 복원", m2.codex.has_trophy() and m2.codex.trophy_day == 11)
	# 키 없는 구세이브 = 빈 원장(하위호환) · 미지 id 드롭(분모 밖 항목이 분자에 안 남는다).
	var fresh := Codex.new()
	fresh.load_save({})
	_check("⑤c 키 없는 구세이브 = 빈 원장·트로피 없음",
		fresh.shipped_count() == 0 and not fresh.has_trophy())
	var dirty := {}
	dirty["garbage_xyz"] = 3                 # 카탈로그에 없는 id
	dirty[ItemCatalog.RELIC_BINYEO] = 4      # 유효 아이템이지만 추적 풀 밖
	dirty[crop] = 9                          # 유효 추적 대상
	fresh.load_save({"shipped": dirty, "trophy_day": 2})
	_check("⑤d 미지·비추적 id 드롭(유효분만 남음)", fresh.shipped_count() == 1
		and fresh.is_shipped(crop) and fresh.first_day_of(crop) == 9 and fresh.trophy_day == 2)
	fresh.free()
	m2.queue_free()
	await process_frame

	# ── 정리: 세이브 원복 ──
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)
