extends SceneTree
# ★[S6-T1 / ADR-0064 결정 2·11] menu_catalog.gd + ItemCatalog 편입 단위검증.
# 실행: godot --headless --path game --script res://playtest/menu_catalog_test.gd
#
# 검증 축:
#   ①  로스터 수·구성(기본 4 / 융합 12 = 작물 5·물고기 3·채집 2·수액 1·나락혼정 1)
#   ②  시그니처 **실존**(ItemCatalog.has_item — ADR-0064가 명시한 유효 판정 함수)
#   ③  가격 계약(기본 = 정액 35 / 융합 = 시그니처 기본가 ×2.5 반올림)
#   ④  기본 = 무재료 · 시그니처 : 메뉴 = 1:1(중복 0) · id 충돌 0
#   ⑤  ItemCatalog 편입(CAT_CONSUMABLE·품질 무차원·스택·이름·색)
#   ⑥  ids_in_category() 계약
#   ⑦  ★실버그 회귀(결정 11 ①) — 비-작물 재료의 가격·이름이 CropCatalog에선 죽고 ItemCatalog에선 산다

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _initialize() -> void:
	print("══ S6-T1 menu_catalog.gd 단위검증 ══")

	# ① 로스터 수·구성.
	_check("① 기본 메뉴 4종", MenuCatalog.basic_ids().size() == 4)
	_check("①b 융합 메뉴 12종", MenuCatalog.fusion_ids().size() == 12)
	_check("①c 전체 = 기본 + 융합", MenuCatalog.ids().size() == 16)
	# 구성 = 작물 5 · 물고기 3 · 채집물(수액 포함 CAT_HARVEST) · 나락혼정 1(CAT_MATERIAL).
	var n_crop := 0
	var n_fish := 0
	var n_forage := 0
	var n_sap := 0
	var n_material := 0
	for mid in MenuCatalog.fusion_ids():
		var sig: String = MenuCatalog.signature_of(mid)
		if CropCatalog.has_crop(sig):
			n_crop += 1
		elif FishCatalog.has(sig):
			n_fish += 1
		elif ItemCatalog.SAP_GOODS.has(sig):
			n_sap += 1
		elif ItemCatalog.FORAGEABLES.has(sig):
			n_forage += 1
		elif ItemCatalog.MATERIALS.has(sig):
			n_material += 1
	_check("①d 작물 시그니처 5", n_crop == 5)
	_check("①e 물고기 시그니처 3", n_fish == 3)
	_check("①f 채집물 시그니처 2", n_forage == 2)
	_check("①g 수액 시그니처 1", n_sap == 1)
	_check("①h 나락혼정 시그니처 1(최상위)",
		n_material == 1 and MenuCatalog.signature_of(MenuCatalog.HONJEONG_EINSPANNER) == ItemCatalog.NARAK_HONJEONG)

	# ② 시그니처는 전부 **실존 아이템**이어야 한다(오타 id = 곳간에 영영 안 들어오는 죽은 메뉴).
	var all_sig_real := true
	var bad_sig := ""
	for mid in MenuCatalog.fusion_ids():
		var sig2: String = MenuCatalog.signature_of(mid)
		if not ItemCatalog.has_item(sig2):
			all_sig_real = false
			bad_sig = sig2
	_check("② 융합 시그니처 12종 전부 ItemCatalog.has_item 통과%s"
		% ("" if all_sig_real else " (미존재: %s)" % bad_sig), all_sig_real)

	# ③ 가격 계약. 기본 = 정액(cafe.gd BASE_PRICE 단일 출처) / 융합 = 시그니처 기본가 ×2.5 반올림.
	var basics_flat := true
	for bid in MenuCatalog.basic_ids():
		if MenuCatalog.price_of(bid) != Cafe.BASE_PRICE:
			basics_flat = false
	_check("③ 기본 메뉴가 = 정액 %d냥(현행 서빙가와 같은 값)" % Cafe.BASE_PRICE, basics_flat)
	var mult_ok := true
	var mult_bad := ""
	for mid2 in MenuCatalog.fusion_ids():
		var want := int(round(ItemCatalog.price_of(MenuCatalog.signature_of(mid2)) * MenuCatalog.PRICE_MULT))
		if MenuCatalog.price_of(mid2) != want:
			mult_ok = false
			mult_bad = String(mid2)
	_check("③b 융합 메뉴가 = 시그니처 기본가 ×%.1f 반올림%s"
		% [MenuCatalog.PRICE_MULT, "" if mult_ok else " (어긋남: %s)" % mult_bad], mult_ok)
	# 대표값 하나를 손계산으로 못 박는다(배수 상수가 바뀌면 여기가 먼저 운다).
	_check("③c 혼령초 라떼 = 혼령초 20 × 2.5 = 50",
		MenuCatalog.price_of(MenuCatalog.HONRYEONGCHO_LATTE) == 50)
	_check("③d 나락혼정 아인슈페너 = 480 × 2.5 = 1200(최상위)",
		MenuCatalog.price_of(MenuCatalog.HONJEONG_EINSPANNER) == 1200)

	# ④ 기본은 무재료(폴백이 재료를 먹으면 "곳간이 비어도 안 멈춤"이 깨진다) · 시그니처 1:1 · id 충돌 0.
	var basics_free := true
	for bid2 in MenuCatalog.basic_ids():
		if MenuCatalog.signature_of(bid2) != "":
			basics_free = false
	_check("④ 기본 메뉴는 무재료(시그니처 없음 — 폴백 보장)", basics_free)
	var seen: Dictionary = {}
	var dup := false
	for mid3 in MenuCatalog.fusion_ids():
		var s3: String = MenuCatalog.signature_of(mid3)
		if seen.has(s3):
			dup = true
		seen[s3] = true
	_check("④b 시그니처 : 메뉴 = 1:1(재고 경합 0)", not dup)
	var id_clash := false
	for mid4 in MenuCatalog.ids():
		# 메뉴 id가 기존 아이템군(작물·어종·자재…)과 겹치면 조회가 앞 분기에 먹힌다.
		if CropCatalog.has_crop(mid4) or FishCatalog.has(mid4) or ItemCatalog.MATERIALS.has(mid4) \
				or ItemCatalog.FORAGEABLES.has(mid4) or ItemCatalog.MINERALS.has(mid4):
			id_clash = true
	_check("④c 메뉴 id ↔ 기존 로스터 교집합 0", not id_clash)
	# 역참조(곳간 재고 → 무슨 메뉴가 되나).
	_check("④d menu_for_signature 역참조",
		MenuCatalog.menu_for_signature(CropCatalog.PIANHWA) == MenuCatalog.PIANHWA_ADE)
	_check("④e 메뉴가 없는 재료는 \"\"", MenuCatalog.menu_for_signature(ItemCatalog.HAY) == "")

	# ⑤ ItemCatalog 편입 — 메뉴는 CAT_CONSUMABLE·스택·품질 무차원이다.
	var probe: String = MenuCatalog.HOBAK_LATTE
	_check("⑤ has_item 통과", ItemCatalog.has_item(probe))
	_check("⑤b 카테고리 = CAT_CONSUMABLE",
		ItemCatalog.category_of(probe) == ItemCatalog.CAT_CONSUMABLE)
	_check("⑤c 스택 가능", ItemCatalog.stackable_of(probe))
	_check("⑤d 이름 위임(MenuCatalog 단일 출처)",
		ItemCatalog.name_of(probe) == MenuCatalog.name_of(probe) and ItemCatalog.name_of(probe) != "")
	_check("⑤e 가격 위임", ItemCatalog.price_of(probe) == MenuCatalog.price_of(probe))
	# ★ 품질 무차원 — 등급을 올려도 값이 안 오른다(catalog §1-B "메뉴는 품질 무영향").
	_check("⑤f 품질 무차원(금 등급도 같은 값)",
		ItemCatalog.price_of(probe, ItemCatalog.Q_GOLD) == ItemCatalog.price_of(probe))
	_check("⑤g 색박스 폴백 존재(아이콘 아트 전)",
		ItemCatalog.tool_color_of(probe) != Color.WHITE)
	# 전 메뉴가 같은 계약을 지키는지(하나만 빠져도 인벤·핫바에서 흰 박스·무명이 된다).
	var all_reg := true
	for mid5 in MenuCatalog.ids():
		if not ItemCatalog.has_item(mid5) \
				or ItemCatalog.category_of(mid5) != ItemCatalog.CAT_CONSUMABLE \
				or ItemCatalog.name_of(mid5) == "":
			all_reg = false
	_check("⑤h 16종 전부 등록·분류·명명 통과", all_reg)

	# ⑥ ids_in_category() — 곳간·메뉴 UI 열거 창구(결정 11 ②).
	var cons: Array = ItemCatalog.ids_in_category(ItemCatalog.CAT_CONSUMABLE)
	var has_all_menus := true
	for mid6 in MenuCatalog.ids():
		if not cons.has(mid6):
			has_all_menus = false
	_check("⑥ CAT_CONSUMABLE 열거에 메뉴 16종 전부 포함", has_all_menus)
	_check("⑥b 같은 열거에 명부환·계단도 포함(기존 소모품 회귀 0)",
		cons.has(ItemCatalog.MYEONGBUHWAN) and cons.has(ItemCatalog.STAIRS))
	var harv: Array = ItemCatalog.ids_in_category(ItemCatalog.CAT_HARVEST)
	_check("⑥c CAT_HARVEST 열거 = 작물·어종·채집물·수액 파생 포함",
		harv.has(CropCatalog.PIANHWA) and harv.has(FishCatalog.NEOK_BUNGEO) \
		and harv.has(ItemCatalog.NEOK_SONGI) and harv.has(ItemCatalog.MYEONGDANPUNG_KKUL))
	_check("⑥d 열거 결과에 카테고리가 다른 것이 안 섞임",
		not harv.has(ItemCatalog.HOE) and not harv.has(ItemCatalog.STONE))
	var seeds: Array = ItemCatalog.ids_in_category(ItemCatalog.CAT_SEED)
	_check("⑥e 파생 id 군(씨앗)도 열거된다",
		seeds.has(ItemCatalog.seed_id(CropCatalog.PIANHWA)))
	_check("⑥f 미지 카테고리 = 빈 배열", ItemCatalog.ids_in_category("nonexistent").is_empty())
	var dup_ids := false
	var seen_ids: Dictionary = {}
	for id7 in harv:
		if seen_ids.has(id7):
			dup_ids = true
		seen_ids[id7] = true
	_check("⑥g 열거 결과에 중복 0", not dup_ids)

	# ⑦ ★실버그 회귀(ADR-0064 결정 11 ①) — **ItemCatalog 가격·이름 계약**. 비-작물 산출물을
	#    CropCatalog로 조회하면 가격 0·이름 빈 문자열이 되던 잠복 버그의 회귀 방어다.
	#    ★[S6-T2] 소비자가 갈렸다: 서빙 알림은 이제 MenuCatalog.name_of(무엇을 냈나)를 쓰고,
	#    이 계약을 읽는 건 **밤 바 약탈**(main._cheapest_harvest — 최저가부터 가져간다)과 곳간·
	#    출하 알림이다. 함수가 바뀐 게 아니라 부르는 쪽이 넓어졌으므로 대조는 그대로 유효하다.
	for nonc in [FishCatalog.NEOK_BUNGEO, ItemCatalog.NEOK_SONGI, ItemCatalog.MYEONGDANPUNG_KKUL]:
		var cid := String(nonc)
		_check("⑦ 비-작물 재료 %s — CropCatalog는 가격 0(버그 재현)" % cid,
			CropCatalog.sell_price(cid) == 0)
		_check("⑦b %s — ItemCatalog.price_of는 양수(봉합)" % cid, ItemCatalog.price_of(cid) > 0)
		_check("⑦c %s — CropCatalog.name_of는 빈 문자열(알림 공백 재현)" % cid,
			CropCatalog.name_of(cid) == "")
		_check("⑦d %s — ItemCatalog.name_of는 이름을 준다(봉합)" % cid,
			ItemCatalog.name_of(cid) != "")
	# 최저가 선택이 실제로 뒤집혔음을 재현: 값싼 작물 vs 비싼 물고기를 옛 기준으로 고르면 물고기가 이긴다.
	var cheap_crop := CropCatalog.HONRYEONGCHO          # 20냥
	var pricey_fish := FishCatalog.JEONYEOKNOL_DOMI     # 88냥
	_check("⑦e 옛 기준(CropCatalog)에선 비싼 물고기가 '더 싸다'고 판정됨",
		CropCatalog.sell_price(pricey_fish) < CropCatalog.sell_price(cheap_crop))
	_check("⑦f 새 기준(ItemCatalog)에선 싼 작물이 먼저 소모된다",
		ItemCatalog.price_of(cheap_crop) < ItemCatalog.price_of(pricey_fish))

	# ⑧ ★[S6-T2 / 결정 2] 절기 창 = 시그니처 재료의 절기 창 파생 — **별도 달력 데이터 0**.
	#    (판정 세부는 cafe_order_test ⑥이 든다. 여기선 카탈로그 계약만: 전 메뉴가 어느 절기엔가
	#    반드시 팔린다 = "이 메뉴는 1년 내내 못 판다"는 죽은 항목이 없다.)
	var never_sellable := ""
	for mid8 in MenuCatalog.ids():
		var sellable := false
		for s in 4:
			if MenuCatalog.in_season(String(mid8), s):
				sellable = true
		if not sellable:
			never_sellable = String(mid8)
	_check("⑧ 16종 전부 적어도 한 절기엔 팔린다(사철 죽은 메뉴 0)%s"
		% ("" if never_sellable == "" else " (죽은 메뉴: %s)" % never_sellable), never_sellable == "")
	_check("⑧b 기본 메뉴는 전 절기(무재료라 하늘을 안 본다)",
		MenuCatalog.in_season(MenuCatalog.AMERICANO, 0) and MenuCatalog.in_season(MenuCatalog.AMERICANO, 3))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
