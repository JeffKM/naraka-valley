extends SceneTree
# ★[S6-T7 / ADR-0064 결정 8·9·11 ③] 곁들이 검증 — `SoulEnergy.restore` 계약 · 곁들이 로스터 ·
# 주방요괴 창구 · 든 채 LMB 소비 배선.
#
# 검증 축:
#   ⓐ **restore(n) 계약**(순수 — 씬 없이 SoulEnergy.new()) — 실회복량 반환·상한 클램프·풀혼력 0·
#      비양수 0·changed 발화 조건·depleted 무발화·기존 동사(spend/refill/세이브) 무회귀.
#      ★ `PlayerHealth.heal`(명부환 HP+40)의 혼력 대칭이므로 **같은 모양의 단언**을 건다.
#   ⓑ 곁들이 로스터 불변식 — "융합 메뉴 *일부*"(진부분집합)·기본 메뉴 0·회복량 밴드(양수·명부환
#      회복량 미만)·선언 순 단조·시그니처 실존·판매 전용 메뉴는 restore 0.
#   ⓒ 주방요괴(T3 배경 NPC) — 등록·**관계 트랙 0**(affinity null·선물 없음·관계 탭 미노출)·자리·
#      몸 생성·일상 대사·실내 가드.
#   ⓓ 곁들이 창구(main 배선) — 곳간 재고에서 접시가 나온다·회복량 최대 우선·판매 전용 재료는 안
#      나온다·빈 곳간 무동작·백팩 가득 시 곳간 원복(원자성).
#   ⓔ 소비 배선(든 채 LMB) — 혼력 회복·정확히 1개 소모·**풀혼력 거절(아이템 불태움 0)**·
#      **혼력 0에서도 먹힌다**(회복 수단이 자기 자신에 잠기지 않는다)·HP 불변(ADR-0011)·
#      음식 버프 축 부재(결정 9 서랍).
# 실행: ./run_tests.sh side_dish
# 좀비 방지: 모든 단언 뒤 quit(). run_tests.sh 워치독과 함께.

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

# 백팩에서 그 id를 든다(핫바 선택 — 든 것이 곧 동사인 LMB 경로를 태우기 위해).
func _hold(m: Node, id: String) -> bool:
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return true
	return false

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S6-T7 곁들이(융합 메뉴 소비 = 혼력 회복)·주방요괴 검증 ══")

	# ── ⓐ restore(n) 계약 ───────────────────────────────────────────────────
	print("── ⓐ SoulEnergy.restore 계약(명부환 heal의 혼력 대칭) ──")
	var e := SoulEnergy.new()
	e.current = SoulEnergy.MAX
	_check("ⓐa 시작은 가득(MAX %d)" % SoulEnergy.MAX, e.current == SoulEnergy.MAX)
	_check("ⓐb ★풀혼력에서는 0을 돌려주고 아무것도 안 한다(아이템 낭비 방지의 마지막 방어선)",
		e.restore(30) == 0 and e.current == SoulEnergy.MAX)

	e.current = 40
	_check("ⓐc 실제로 채워진 양을 돌려준다", e.restore(25) == 25 and e.current == 65)
	_check("ⓐd ★상한 클램프 — 초과분은 버린다(반환값도 잘린 값)",
		e.restore(999) == SoulEnergy.MAX - 65 and e.current == SoulEnergy.MAX)

	e.current = 50
	_check("ⓐe 0·음수는 무동작(손상 방어)",
		e.restore(0) == 0 and e.restore(-7) == 0 and e.current == 50)

	# changed 시그널 — 실제로 값이 변한 호출에서만 울린다(HUD가 헛돌지 않게).
	var beats := [0]
	e.changed.connect(func(_c: int, _m: int) -> void: beats[0] += 1)
	e.restore(10)
	_check("ⓐf 값이 변하면 changed가 한 번 운다", beats[0] == 1 and e.current == 60)
	e.restore(0)
	e.current = SoulEnergy.MAX
	beats[0] = 0
	e.restore(50)
	_check("ⓐg 변화가 없으면 changed는 안 운다(풀혼력·비양수)", beats[0] == 0)

	# depleted는 채우는 동사의 대칭항이 아니다 — 절대 안 운다.
	var dropped := [0]
	e.depleted.connect(func() -> void: dropped[0] += 1)
	e.current = 5
	e.restore(1)
	_check("ⓐh ★restore는 depleted를 발화하지 않는다(채우는 동사는 바닥낼 수 없다)", dropped[0] == 0)

	# 기존 동사 무회귀 — restore가 spend·refill·세이브의 결을 흔들지 않는다.
	e.current = SoulEnergy.MAX
	_check("ⓐi spend 무회귀(회복 뒤에도 소모가 그대로 는다)",
		e.spend(SoulEnergy.COST_PER_ACTION) and e.current == SoulEnergy.MAX - SoulEnergy.COST_PER_ACTION)
	e.current = 12
	e.restore(3)
	e.refill()
	_check("ⓐj refill은 여전히 무조건 풀회복(restore와 갈린 동사)", e.current == SoulEnergy.MAX)
	e.current = 37
	var e2 := SoulEnergy.new()
	e2.load_save(e.to_save())
	_check("ⓐk 세이브 왕복 불변(restore가 직렬화 표면을 안 늘렸다)", e2.current == 37)
	e2.free()
	e.free()

	# ── ⓑ 곁들이 로스터 불변식 ─────────────────────────────────────────────
	print("── ⓑ 곁들이 로스터(ADR-0064 결정 9 '융합 메뉴 일부') ──")
	var sides: Array = MenuCatalog.side_dish_ids()
	_check("ⓑa 곁들이가 존재한다 (%d종)" % sides.size(), sides.size() > 0)
	_check("ⓑb ★'일부'다 — 융합 로스터의 **진부분집합**(전량이면 '일부'가 아니다) (%d < %d)"
		% [sides.size(), MenuCatalog.fusion_ids().size()],
		sides.size() < MenuCatalog.fusion_ids().size())
	var all_fusion := true
	var all_valid_sig := true
	for raw in sides:
		var sid := String(raw)
		if not MenuCatalog.is_fusion(sid):
			all_fusion = false
		if not ItemCatalog.has_item(MenuCatalog.signature_of(sid)):
			all_valid_sig = false
	_check("ⓑc 곁들이는 전부 융합 메뉴다(기본 메뉴 = 카페 판매 전용)", all_fusion)
	_check("ⓑd 곁들이 시그니처는 전부 실존 아이템", all_valid_sig)
	var basics_zero := true
	for raw in MenuCatalog.basic_ids():
		if MenuCatalog.is_side_dish(String(raw)) or MenuCatalog.restore_of(String(raw)) != 0:
			basics_zero = false
	_check("ⓑe ★기본 메뉴는 한 잔도 곁들이가 아니다(판매 전용 — 결정 9)", basics_zero)
	_check("ⓑf 최상위 나락혼정 아인슈페너는 판매 전용(로스터 꼭대기 = 매출의 정점)",
		not MenuCatalog.is_side_dish(MenuCatalog.HONJEONG_EINSPANNER))
	_check("ⓑg 비-메뉴 id는 회복 0(손상 방어)",
		MenuCatalog.restore_of(ItemCatalog.MYEONGBUHWAN) == 0
		and MenuCatalog.restore_of("없는놈") == 0)

	# 밴드 — 전부 양수이고, 취침으로 공짜 풀회복되는 혼력이 150냥짜리 명부환보다 후해지지 않는다.
	var band_ok := true
	var max_restore := 0
	for raw in sides:
		var n := MenuCatalog.restore_of(String(raw))
		if n <= 0 or n >= ItemCatalog.MYEONGBUHWAN_HEAL:
			band_ok = false
		max_restore = maxi(max_restore, n)
	_check("ⓑh 회복량 밴드 — 전부 양수 · 명부환 HP+%d 미만 (최대 %d)"
		% [ItemCatalog.MYEONGBUHWAN_HEAL, max_restore], band_ok)
	_check("ⓑi 하루치를 한 접시가 못 채운다(MAX %d의 절반 미만)" % SoulEnergy.MAX,
		max_restore < SoulEnergy.MAX / 2)

	# 선언 순 = 회복량 비-감소 = 메뉴가 비-감소. 셋이 나란히 가야 "비싼 재료일수록 든든하다"가
	# 데이터로 성립한다(_best_side_dish의 '회복량 최대' 규칙이 곧 '가장 비싼 접시'가 된다).
	var mono_restore := true
	var mono_price := true
	for i in range(sides.size() - 1):
		var a := String(sides[i])
		var b := String(sides[i + 1])
		if MenuCatalog.restore_of(a) > MenuCatalog.restore_of(b):
			mono_restore = false
		if MenuCatalog.price_of(a) > MenuCatalog.price_of(b):
			mono_price = false
	_check("ⓑj 선언 순 = 회복량 비-감소(결정적 순회의 뼈대)", mono_restore)
	_check("ⓑk ★회복량 순서가 메뉴가 순서와 어긋나지 않는다(비싼 재료일수록 든든하다)", mono_price)

	# ── ⓒ 주방요괴(T3 배경 NPC) ────────────────────────────────────────────
	print("── ⓒ 주방요괴 등록(T3 배경 직원 · 관계 트랙 0) ──")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	var m: Node = await _spawn_main()
	var r: Resident = m._resident("kitchen_youkai")
	_check("ⓒa 레지스트리에 등록 · **맨 뒤**(앞 순서 불변 — 신규는 뒤에만 붙는다)",
		r != null and m._residents[m._residents.size() - 1].id == "kitchen_youkai")
	_check("ⓒb 표시명 = 주방요괴(호칭 그대로 — 정체는 서랍)",
		r != null and r.display_name == "주방요괴")
	_check("ⓒc 몸이 런타임 생성돼 트리에 붙는다(main.tscn 무수정)",
		r.node != null and r.node.is_inside_tree() and r.node is KitchenYoukai)
	_check("ⓒd ★★관계 트랙 0 — 호감도 미터도 세이브 키도 없다(ADR-0005 깊이는 메인 독점)",
		r.affinity == null and r.save_key == "" and not r.needs_affinity)
	_check("ⓒe ★선물 채널 없음(대화·선물로 자라는 트랙 자체가 없다)", not r.can_gift)
	_check("ⓒf 관계 탭에 안 뜬다(effect_fn 무효 = 곱셈기 0 · ADR-0008)",
		not r.effect_fn.is_valid())
	_check("ⓒg 팝업 관계 한 줄이 하트 자리를 대신한다", r.rel_text != "")
	_check("ⓒh 일상 대사 묶음(plain_talk = lines_resident 경로)",
		r.plain_talk and r.node.lines_resident().size() > 0)
	_check("ⓒi 자리 = 카페 주방 칸(곳간 옆 · 직원 줄)",
		r.station_tile(12 * 60) == m.KITCHEN_TILE and r.tile == m.KITCHEN_TILE)
	_check("ⓒj 자리가 곳간·기존 직원 칸과 안 겹친다",
		m.KITCHEN_TILE != m.LARDER_TILE and m.KITCHEN_TILE != m.MEL_TILE
		and m.KITCHEN_TILE != m.OKJA_CAFE_TILE and m.KITCHEN_TILE != m.SHIP_BIN_TILE
		and m.KITCHEN_TILE != m.BANA_NIGHT_TILE and not m.SEAT_TILES.has(m.KITCHEN_TILE))
	_check("ⓒk 실내 가드 — 카페 안에서만 말 건다", r.require_indoor == "카페")
	_check("ⓒl [F] 훅·프롬프트 꼬리가 물려 있다",
		r.shop_key.is_valid() and r.prompt_extra.is_valid())

	# ── ⓓ 곁들이 창구(곳간 → 접시) ────────────────────────────────────────
	print("── ⓓ 곁들이 창구(주방요괴 [F]) ──")
	m.larder.stock.clear()
	_check("ⓓa 빈 곳간 = 낼 접시가 없다", m._best_side_dish() == "")
	_check("ⓓb 빈 곳간 프롬프트가 그 사실을 말한다", m._side_dish_prompt().find("없다") >= 0)
	m._make_side_dish()
	var made_any := false
	for raw in MenuCatalog.ids():
		if m.inventory.count_of(String(raw)) > 0:
			made_any = true
	_check("ⓓc 빈 곳간에서 [F] = 무동작(백팩에 메뉴가 하나도 안 생긴다)", not made_any)

	# 판매 전용 재료만 있는 곳간 — 접시가 안 나온다(곁들이 로스터가 실제로 필터로 산다).
	m.larder.add(CropCatalog.HONRYEONGCHO, 3)      # 혼령초 라떼 = 음료 = 판매 전용
	_check("ⓓd ★판매 전용 메뉴 재료만 쌓여 있으면 접시가 안 나온다", m._best_side_dish() == "")

	# 곁들이 재료 투입 — 그 접시가 나온다.
	m.larder.add(FishCatalog.NEOK_BUNGEO, 2)
	_check("ⓓe 곁들이 재료가 들어오면 그 접시가 잡힌다",
		m._best_side_dish() == MenuCatalog.BUNGEO_PPANG)
	var stock_before: int = m.larder.count_of(FishCatalog.NEOK_BUNGEO)
	var have_before: int = m.inventory.count_of(MenuCatalog.BUNGEO_PPANG)
	m._make_side_dish()
	_check("ⓓf 백팩에 접시 +1", m.inventory.count_of(MenuCatalog.BUNGEO_PPANG) == have_before + 1)
	_check("ⓓg 곳간에서 시그니처 정확히 1개 차감",
		m.larder.count_of(FishCatalog.NEOK_BUNGEO) == stock_before - 1)
	_check("ⓓh 판매 전용 재료는 한 톨도 안 건드린다(곁들이가 곳간을 훑지 않는다)",
		m.larder.count_of(CropCatalog.HONRYEONGCHO) == 3)

	# 회복량 최대 우선 — 결정적이라 같은 재고면 늘 같은 접시다(무작위 금지).
	m.larder.add(ItemCatalog.NEOK_SONGI, 1)        # 넋송이 수프(20) > 넋붕어빵(15)
	_check("ⓓi ★회복량이 큰 접시를 고른다(효과 축이 하나뿐이라 피커를 안 세운다)",
		m._best_side_dish() == MenuCatalog.SONGI_SOUP)
	_check("ⓓj 프롬프트가 나올 접시를 미리 말한다",
		m._side_dish_prompt().find(MenuCatalog.name_of(MenuCatalog.SONGI_SOUP)) >= 0)
	_check("ⓓk 같은 재고면 같은 답(결정적 — 무작위 폴백 없음)",
		m._best_side_dish() == m._best_side_dish())
	m._make_side_dish()
	_check("ⓓl 고른 접시의 재료만 줄어든다",
		m.inventory.count_of(MenuCatalog.SONGI_SOUP) == 1
		and m.larder.count_of(ItemCatalog.NEOK_SONGI) == 0
		and m.larder.count_of(FishCatalog.NEOK_BUNGEO) == stock_before - 1)

	# [F] 훅 경로(프레임워크가 부르는 그 창구)로도 같은 일이 일어난다.
	var have_bp: int = m.inventory.count_of(MenuCatalog.BUNGEO_PPANG)
	r.shop_key.call()
	_check("ⓓm 프레임워크 [F] 훅 경로도 같은 접시를 낸다",
		m.inventory.count_of(MenuCatalog.BUNGEO_PPANG) == have_bp + 1)

	# 원자성 — 백팩이 가득이면 곳간이 원복된다(재료가 허공에 사라지지 않는다).
	# ★ 포화 만들기 = 기존 붕어빵 스택을 먼저 지우고(스택이 남으면 합쳐져 들어간다) 빈 칸을 전부
	#   돌로 메운다. `add_item`은 스택 합치기가 되므로 루프로는 절대 포화가 안 온다.
	m.larder.add(FishCatalog.NEOK_BUNGEO, 1)
	var stock_full: int = m.larder.count_of(FishCatalog.NEOK_BUNGEO)
	m.inventory.remove_item(MenuCatalog.BUNGEO_PPANG, m.inventory.count_of(MenuCatalog.BUNGEO_PPANG))
	m.inventory.remove_item(MenuCatalog.SONGI_SOUP, m.inventory.count_of(MenuCatalog.SONGI_SOUP))
	for i in range(m.inventory.slots.size()):
		if m.inventory.slots[i] == null:
			m.inventory.slots[i] = {"id": ItemCatalog.STONE, "count": 1, "quality": 0}
	_check("ⓓn pre 백팩 포화", not m.inventory.add_item(MenuCatalog.BUNGEO_PPANG, 1))
	m._make_side_dish()
	_check("ⓓo ★★백팩이 가득이면 곳간이 원복된다(재료가 허공에 안 사라진다 — 원자성)",
		m.larder.count_of(FishCatalog.NEOK_BUNGEO) == stock_full
		and m.inventory.count_of(MenuCatalog.BUNGEO_PPANG) == 0)

	# ── ⓔ 소비 배선(든 채 LMB) ────────────────────────────────────────────
	print("── ⓔ 곁들이 소비(든 채 LMB = 혼력 회복) ──")
	for i in range(m.inventory.slots.size()):
		m.inventory.slots[i] = null       # 칸 수(SIZE)는 보존하고 내용만 비운다
	m.inventory.add_item(MenuCatalog.SONGI_SOUP, 3)
	_check("ⓔpre 접시 3개 소지 · 들었다",
		m.inventory.count_of(MenuCatalog.SONGI_SOUP) == 3 and _hold(m, MenuCatalog.SONGI_SOUP))

	# 풀혼력 거절 — 접시가 안 없어진다(오조작 한 번이 곳간 재료를 태우지 않는다).
	m.energy.current = SoulEnergy.MAX
	m._use_tool()
	_check("ⓔa ★★풀혼력이면 거절 — 접시가 그대로다(낭비 방지 · 명부환 ㉠ 대칭)",
		m.inventory.count_of(MenuCatalog.SONGI_SOUP) == 3 and m.energy.current == SoulEnergy.MAX)

	# 정상 소비 — 혼력이 표대로 차고 정확히 1개 준다.
	var amount := MenuCatalog.restore_of(MenuCatalog.SONGI_SOUP)
	m.energy.current = 30
	var hp_before: int = m.health.current
	m._use_tool()
	_check("ⓔb 혼력 +%d(카탈로그 표 그대로)" % amount, m.energy.current == 30 + amount)
	_check("ⓔc 정확히 1개 소모", m.inventory.count_of(MenuCatalog.SONGI_SOUP) == 2)
	_check("ⓔd ★HP는 한 톨도 안 변한다(혼력·체력은 완전 별개 자원 — ADR-0011)",
		m.health.current == hp_before)

	# 상한 클램프가 배선 끝까지 산다.
	m.energy.current = SoulEnergy.MAX - 1
	m._use_tool()
	_check("ⓔe 상한을 넘겨 채우지 않는다(초과분 버림)", m.energy.current == SoulEnergy.MAX)
	_check("ⓔf 그래도 접시는 소모된다(회복이 실제로 일어났으므로)",
		m.inventory.count_of(MenuCatalog.SONGI_SOUP) == 1)

	# 혼력 0 — **먹힌다**. 회복 수단이 자기 자신에 잠기면 막힘이 된다(ADR-0008).
	m.energy.current = 0
	m._use_tool()
	_check("ⓔg ★★혼력 0에서도 먹힌다(회복 동사가 혼력 게이트 위 — 막힘 0)",
		m.energy.current == amount and m.inventory.count_of(MenuCatalog.SONGI_SOUP) == 0)
	_check("ⓔh 다 먹으면 더는 아무 일도 없다(빈 손 LMB 무동작)", not _hold(m, MenuCatalog.SONGI_SOUP))

	# 판매 전용 메뉴는 들고 눌러도 안 먹힌다(로스터가 소비 경로에서도 실제로 산다).
	m.inventory.add_item(MenuCatalog.HONJEONG_EINSPANNER, 1)
	_hold(m, MenuCatalog.HONJEONG_EINSPANNER)
	m.energy.current = 20
	m._use_tool()
	_check("ⓔi ★판매 전용 융합 메뉴는 들고 눌러도 안 먹힌다(혼력·개수 불변)",
		m.energy.current == 20 and m.inventory.count_of(MenuCatalog.HONJEONG_EINSPANNER) == 1)

	# 음식 버프 축 부재(결정 9 서랍) — 곁들이가 손대는 상태는 혼력 하나뿐이다.
	m.inventory.add_item(MenuCatalog.SONGI_SOUP, 1)
	_hold(m, MenuCatalog.SONGI_SOUP)
	m.energy.current = 10
	var gold_b: int = m.wallet.gold
	var margin_b: float = m.cafe.margin
	m._use_tool()
	_check("ⓔj ★음식 버프 축 0(결정 9 서랍) — 지갑·마진 같은 다른 축은 미터치",
		m.wallet.gold == gold_b and is_equal_approx(m.cafe.margin, margin_b))

	cleaner.delete_save()
	m.queue_free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
