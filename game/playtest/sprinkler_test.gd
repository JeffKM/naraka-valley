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

	# ── ③ 급수된 칸이 그날 성장 반영(실 배선 _on_day_advanced — 급수 후 성장 순서) ──
	var a3 := Vector2i(58, 45)
	m.sprinkler.place(a3)
	for c in _cross(a3):
		_plant(m, c)                        # dry·grown_days 0
	var diag3 := a3 + Vector2i(1, 1)
	_plant(m, diag3)                        # 미덮임 대조군
	m._on_day_advanced(2)                   # 실 하루 사이클: 스프링클러 급수 → advance_day 성장
	var all_cross_grew := true
	for c in _cross(a3):
		if m.farm.grown_days_of(c) != 1:
			all_cross_grew = false
	_check("③ 급수된 십자 4칸 그날 성장(+1)", all_cross_grew)
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
