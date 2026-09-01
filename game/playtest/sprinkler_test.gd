extends SceneTree

# [S1R-T9 · 저승 스프링클러 티어1] 그레이박스 단위검증(ephemeral 헤드리스).
#
# 무엇을 보나(카탈로그 §1-B / ADR-0059 결정4 — 물만 자동·혼력0·물뿌리개 잔량 무관·티어1=십자 4칸):
#   Part A — 아이템 카탈로그 등록(main 불필요):
#     ⓪ SPRINKLER = CAT_PLACEABLE·이름 있음·스택 O·구매가 60·has_item.
#   Part B — main 통합:
#     ① 구매→배치→세이브 왕복(구매로 인벤 적재·설치로 소모·설치 좌표 세이브 보존·구세이브=설치 0).
#     ② 아침 자동 급수 4칸(십자) + 혼력 불변 + 물뿌리개 잔량 불변(T8 축과 독립) + 대각은 미급수.
#     ③ 급수된 칸이 그날 성장 반영(급수 → advance_day 성장 순서 = 하루 사이클 정합, 실 배선 _on_day_advanced).
#     ④ 철거 후 급수 중단(watered_targets에서 빠짐·재파종 dry 칸 미급수).
#     ⑤ POND_ACTIVITY_RECT·길(PATH)·건물 패드(WALL)엔 설치 불가·빈 지면엔 설치 가능·중복 설치 불가.
#
# 좀비 방지: 모든 단언 뒤 quit(). run_tests.sh 워치독과 함께. 세이브 잔재는 끝에서 격리 정리.

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

# 든 아이템 선택(없으면 인벤 넣고 그 슬롯 선택 — well_test 결).
func _select(m: Node, id: String) -> void:
	if not m.inventory.has_item(id):
		m.inventory.add_item(id, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

# 경작+파종된(물 줄 수 있는·성장 가능한) 마른 칸 하나 만들기.
func _plant(m: Node, t: Vector2i) -> void:
	m.farm.hoe(t)
	m.farm.plant(t, CropCatalog.HONRYEONGCHO)

# 스프링클러를 설치할 수 있는(배치 규칙 통과) 첫 칸을 그리드에서 찾는다. 없으면 (-1,-1).
func _find_placeable(m: Node) -> Vector2i:
	for y in range(m._outdoor_h):
		for x in range(m._grid_w):
			var t := Vector2i(x, y)
			if m._can_place_sprinkler(t):
				return t
	return Vector2i(-1, -1)

func _cross(a: Vector2i) -> Array:
	return [a + Vector2i(1, 0), a + Vector2i(-1, 0), a + Vector2i(0, 1), a + Vector2i(0, -1)]

# 스프링클러가 현재 덮는(자동 급수) 칸 집합에 t가 드는가.
func _covers(m: Node, t: Vector2i) -> bool:
	return t in m.sprinkler.watered_targets()

# 아침 자동 급수만 흉내(main._on_day_advanced가 성장 판정 전에 도는 그 루프) — 성장·정산 배제 순수 급수.
func _morning_sprinkle(m: Node) -> void:
	for t in m.sprinkler.watered_targets():
		m.farm.sprinkle(t)

func _initialize() -> void:
	print("══ 저승 스프링클러 티어1(S1R-T9) 그레이박스 검증 ══")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	_part_a()
	await _part_b()
	await _part_r2()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(1 if _fail > 0 else 0)

func _part_a() -> void:
	var sp := ItemCatalog.SPRINKLER
	_check("⓪ SPRINKLER = CAT_PLACEABLE", ItemCatalog.category_of(sp) == ItemCatalog.CAT_PLACEABLE)
	_check("⓪ 이름 있음", ItemCatalog.name_of(sp) != "")
	_check("⓪ 스택 가능", ItemCatalog.stackable_of(sp))
	_check("⓪ 구매가 60", ItemCatalog.price_of(sp) == 60)
	_check("⓪ has_item 유효", ItemCatalog.has_item(sp))
	# 티어1 = 십자 4방(급수 범위 상수).
	_check("⓪ 티어1 범위 = 십자 4칸", Sprinkler.CROSS_OFFSETS.size() == 4)

func _part_b() -> void:
	var m: Node = await _spawn_main()
	var sp := ItemCatalog.SPRINKLER
	_check("부팅 = 안식 농원", m._region == RegionCatalog.HOME and m.sprinkler != null)

	# ── ① 구매 → 배치 → 세이브 왕복 ──
	m.wallet.earn(500)
	var g0: int = m.wallet.gold
	var bought: int = m.buy_sprinkler(2)
	_check("① 구매 2개 성공", bought == 2)
	_check("① 인벤토리 적재(2)", m.inventory.count_of(sp) == 2)
	_check("① 골드 차감(−120)", m.wallet.gold == g0 - 120)
	# ★[S10 폴리시] 만재 구매 = **적재 먼저·결제 나중**(냥이 안 나간다 — 종전엔 spend가 먼저
	# 성공하고 add_item 실패를 버려 냥만 증발했다). 포화를 만들려면 기존 스프링클러 스택부터
	# 지워야 한다 — 스택이 남으면 빈 칸 없이도 합쳐져 들어간다.
	var held: int = m.inventory.count_of(sp)
	m.inventory.remove_item(sp, held)
	var filled: Array = []
	for i in range(m.inventory.slots.size()):
		if m.inventory.slots[i] == null:
			m.inventory.slots[i] = {"id": ItemCatalog.STONE, "count": 1, "quality": 0}
			filled.append(i)
	var g_full: int = m.wallet.gold
	var got_full: int = m.buy_sprinkler(2)
	_check("①만재 구매 = 0개 반환 · 골드 %d 그대로 · 미보유" % g_full,
		got_full == 0 and m.wallet.gold == g_full and m.inventory.count_of(sp) == 0)
	for i in filled:
		m.inventory.slots[i] = null       # 포화 원복(아래 절은 여유 있는 백팩을 전제)
	m.inventory.add_item(sp, held)        # 지웠던 스택 원복
	_check("①만재 원복 확인(스프링클러 %d개 · 골드 불변)" % held,
		m.inventory.count_of(sp) == held and m.wallet.gold == g_full)
	var a1 := _find_placeable(m)
	_check("①pre 설치 가능한 빈 지면 존재", a1.x >= 0)
	_select(m, sp)
	m._target = a1
	m._place_sprinkler(a1)
	_check("① 설치 성공(원장 등록)", m.sprinkler.has_at(a1))
	_check("① 설치로 아이템 1 소모(2→1)", m.inventory.count_of(sp) == 1)
	# 세이브 왕복: 인메모리 오염 후 로드 → 설치 좌표 복원.
	m._save_game()
	m.sprinkler.remove(a1)
	_check("①pre 인메모리 철거(오염)", not m.sprinkler.has_at(a1))
	m._load_game()
	_check("① 세이브 왕복 — 설치 좌표 보존", m.sprinkler.has_at(a1))
	# 구세이브 하위호환: main은 "sprinkler" 키가 없으면 load_save를 건너뛰므로(reclaim/orchard 동형),
	#   하위호환 보증은 노드 레벨에 있다 — load_save가 "tiles" 없는 dict를 빈 목록으로 방어한다.
	m.sprinkler.load_save({})
	_check("① 구세이브(키 없음) → 설치 0(load_save 하위호환)", m.sprinkler.count() == 0)
	# 그리고 키 없는 세이브를 로드해도 크래시 없이 통과한다(위 _load_game이 이미 무키 경로를 지남).
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	raw.erase("sprinkler")
	m.saver.save_game(raw, m._active_slot, {})
	m._load_game()
	_check("① 구세이브(sprinkler 키 없음) 로드 크래시 없음", true)

	# ── ⑤ 설치 배치 규칙(POND_ACTIVITY_RECT·길·건물 패드 불가 / 빈 지면 가능 / 중복 불가) ──
	_check("⑤ 물가 활동존(POND_ACTIVITY_RECT) 설치 불가",
		not m._can_place_sprinkler(m.POND_ACTIVITY_RECT.position))
	_check("⑤ 길(PATH 39,19) 설치 불가", not m._can_place_sprinkler(Vector2i(39, 19)))
	_check("⑤ 건물 패드(본가 외관 WALL) 설치 불가",
		not m._can_place_sprinkler(m.HOUSE_EXT_RECT.position))
	var a5 := _find_placeable(m)
	_check("⑤ 빈 지면 설치 가능", a5.x >= 0 and m._can_place_sprinkler(a5))
	m.sprinkler.place(a5)
	_check("⑤ 이미 설치된 칸 = 중복 설치 불가", not m._can_place_sprinkler(a5))
	m.sprinkler.remove(a5)

	# ── ② 아침 자동 급수 4칸(십자) + 혼력 불변 + 물뿌리개 잔량 불변 + 대각 미급수 ──
	var a2 := Vector2i(50, 45)
	m.sprinkler.place(a2)
	for c in _cross(a2):
		_plant(m, c)
	var diag2 := a2 + Vector2i(1, 1)
	_plant(m, diag2)
	m.energy.refill()
	var e0: int = m.energy.current
	var w0: int = m._can_water
	_morning_sprinkle(m)
	var all_cross_watered := true
	for c in _cross(a2):
		if not m.farm.is_watered(c):
			all_cross_watered = false
	_check("② 십자 4칸 전원 자동 급수", all_cross_watered)
	_check("② 대각 칸은 미급수(십자만)", not m.farm.is_watered(diag2))
	_check("② 혼력 불변(자동급수는 혼력 0)", m.energy.current == e0)
	_check("② 물뿌리개 잔량 불변(T8 축과 독립)", m._can_water == w0)

	# ── ③ 급수된 칸이 **다음 아침** 성장에 반영(실 배선 _on_day_advanced) ──
	# ★[폴리시 R9] 급수 지점이 `farm.advance_day` **뒤**로 옮겨졌다(혼우가 R8에서 옮겨 간 그 자리와
	#   나란히). 종전엔 성장 판정 앞이라 같은 아침에 +1이 붙었지만, 그 뒤 같은 루프의 마름 패스가
	#   곧바로 칸을 말려 **정산이 끝난 시점의 밭이 종일 dry**였다 — 오버레이가 마른 흙을 그려
	#   플레이어가 물뿌리개·혼력을 헛되이 쓰고, 배우자 아침 물주기 8칸이 그 칸을 잠식했다.
	#   그래서 이 단언도 "그날 +1"에서 **"오늘 젖고 내일 +1"**로 바뀐다. 정상상태 속도는 그대로
	#   하루 +1이고(아래 ③c), 설치 첫날 하루만 뒤로 밀린다.
	var a3 := Vector2i(58, 45)
	m.sprinkler.place(a3)
	for c in _cross(a3):
		_plant(m, c)                        # dry·grown_days 0
	var diag3 := a3 + Vector2i(1, 1)
	_plant(m, diag3)                        # 미덮임 대조군
	m._on_day_advanced(2)                   # 실 하루 사이클: advance_day 성장 → 스프링클러 급수
	var all_cross_wet := true
	var all_cross_zero := true
	for c in _cross(a3):
		if not m.farm.is_watered(c):
			all_cross_wet = false
		if m.farm.grown_days_of(c) != 0:
			all_cross_zero = false
	_check("③a 첫 아침 정산이 끝난 시점에 십자 4칸이 **젖어 있다**(종일 dry였던 그 자리)",
		all_cross_wet and all_cross_zero)
	m._on_day_advanced(3)                   # 그 물이 다음 아침의 성장 판정에 실린다
	var all_cross_grew := true
	var all_cross_rewet := true
	for c in _cross(a3):
		if m.farm.grown_days_of(c) != 1:
			all_cross_grew = false
		if not m.farm.is_watered(c):
			all_cross_rewet = false
	_check("③b 다음 아침에 그 4칸이 +1 자란다(급수 → 성장의 하루 사이클)", all_cross_grew)
	_check("③c 같은 아침에 다시 젖는다 — 정상상태 속도는 여전히 하루 +1이다", all_cross_rewet)
	_check("③ 미덮인 대각 칸은 성장 없음(급수원=스프링클러 입증)", m.farm.grown_days_of(diag3) == 0)

	# ── ④ 철거 후 급수 중단 ──
	var a4 := Vector2i(64, 50)
	m.sprinkler.place(a4)
	var cross4 := _cross(a4)
	var covered_before := true
	for c in cross4:
		if not _covers(m, c):
			covered_before = false
	_check("④pre 설치 시 십자 4칸 급수 범위 포함", covered_before)
	m._target = a4
	var held_before: int = m.inventory.count_of(sp)
	m._remove_sprinkler(a4)
	_check("④ 철거 성공(원장 제거)", not m.sprinkler.has_at(a4))
	_check("④ 철거로 아이템 1 회수(인벤 +1)", m.inventory.count_of(sp) == held_before + 1)
	var covered_after := false
	for c in cross4:
		if _covers(m, c):
			covered_after = true
	_check("④ 철거 후 급수 범위에서 빠짐", not covered_after)
	# 재파종 dry 칸이 다음 아침에 안 젖는다(급수 중단 실효).
	for c in cross4:
		m.farm.hoe(c)                       # 이미 tilled면 무동작
		# grown_days·watered 초기화 위해 새 마른 파종 상태로 — remove_plant 후 재파종.
		m.farm.remove_plant(c)
		m.farm.plant(c, CropCatalog.HONRYEONGCHO)
	_morning_sprinkle(m)
	var any_watered_after := false
	for c in cross4:
		if m.farm.is_watered(c):
			any_watered_after = true
	_check("④ 철거 후 재파종 칸 미급수(급수 중단)", not any_watered_after)

	await _despawn(m)

# ══ [폴리시 R2] 회수 손실 · 구역 가드 · 설치물 겹침 ═══════════════════════════
# 세 결함을 한 무대에서 재현하고 봉합을 확인한다:
#   ⑥ 백팩이 가득한 채 회수 → **원장에도 백팩에도 없는 상태**가 되면 안 된다(적재 먼저·원장 나중).
#   ⑦ 다른 구역에서 같은 좌표를 겨눠도 안식 농원 설치물이 원격 철거되면 안 된다(원장에 구역 축 없음).
#   ⑧ 업화로·결정기·게잡이통·채취기 칸엔 스프링클러를 못 놓는다(단방향이던 가드의 양방향화).
func _part_r2() -> void:
	print("── ⑥⑦⑧ [폴리시 R2] 회수 손실 · 구역 가드 · 설치물 겹침 ──")
	var m: Node = await _spawn_main()
	var t := _find_placeable(m)
	_check("⑥pre 설치 가능한 빈 지면 확보", t != Vector2i(-1, -1))
	m.sprinkler.place(t, Sprinkler.TIER_1)
	_check("⑥pre2 원장에 티어1이 섰다", m.sprinkler.has_at(t) and m.sprinkler.tier_at(t) == Sprinkler.TIER_1)

	# ── ⑥ 백팩 만원 회수 ──
	_fill_backpack_full(m.inventory)
	_check("⑥a 준비 — 빈 슬롯 0 · 스프링클러 스택 없음",
		not m.inventory.has_free_slot() and m.inventory.count_of(ItemCatalog.SPRINKLER) == 0)
	m._remove_sprinkler(t)
	_check("⑥b **회수가 성립하지 않는다** — 원장에 그대로 서 있고 백팩엔 안 들어갔다(소실 0)",
		m.sprinkler.has_at(t) and m.sprinkler.tier_at(t) == Sprinkler.TIER_1
		and m.inventory.count_of(ItemCatalog.SPRINKLER) == 0)
	# 자리를 하나 비우면 그대로 회수된다(막는 것이 아니라 미루는 것).
	_fill_backpack_full(m.inventory, [0])   # 자리를 하나 비운다
	m._remove_sprinkler(t)
	_check("⑥c 자리를 비우면 회수 성립 — 원장에서 사라지고 백팩에 1개",
		not m.sprinkler.has_at(t) and m.inventory.count_of(ItemCatalog.SPRINKLER) == 1)

	# ── ⑦ 구역 가드 ──
	m.sprinkler.place(t, Sprinkler.TIER_1)
	_check("⑦a 안식 농원에서는 그 칸이 \"설치된 칸\"으로 읽힌다",
		m._region == RegionCatalog.HOME and m._sprinkler_at(t))
	var home_region: String = m._region
	m._region = RegionCatalog.NARU_VILLAGE      # 원장은 그대로 두고 무대만 옮긴다(좌표 축 공유 재현)
	_check("⑦b **다른 구역에서는 같은 좌표가 비어 보인다** — 원격 철거 디스패치가 안 걸린다",
		not m._sprinkler_at(t) and m.sprinkler.has_at(t))
	m._region = home_region
	_check("⑦c 돌아오면 다시 읽힌다(가드는 무대 축이지 원장을 안 건드린다)", m._sprinkler_at(t))
	m.sprinkler.remove(t)

	# ── ⑧ 설치물 겹침(양방향) ──
	var t2 := _find_placeable(m)
	_check("⑧pre 빈 지면 확보", t2 != Vector2i(-1, -1))
	var probes := {
		"업화로": func(): m.furnace.place(m._region, t2),
		"결정기": func(): m.crystalarium.place(m._region, t2),
		"채취기": func(): m.tapper.place(m._region, t2, TreeLedger.SP_OAK, 0),
	}
	for label: String in probes:
		probes[label].call()
		_check("⑧%s 칸엔 스프링클러·레어크로우를 못 놓는다" % label,
			not m._can_place_sprinkler(t2) and not m._can_place_rarecrow(t2))
		m.furnace.remove(m._region, t2)
		m.crystalarium.remove(m._region, t2)
		m.tapper.remove(m._region, t2)
	_check("⑧z 전부 걷어내면 다시 놓을 수 있다(가드가 칸을 영구히 죽이지 않는다)",
		m._can_place_sprinkler(t2))
	await _despawn(m)

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
