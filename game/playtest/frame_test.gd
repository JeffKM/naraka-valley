extends SceneTree
# Phase 2.7 C2 — 공통 인벤토리 프레임(inv_frame.gd + main 메뉴 배선) 단위검증(ephemeral 헤드리스).
# §3.4 컨텍스트 스위칭 셸(메뉴/출하함/매대)이 열리고/닫히고/탭 전환되며, 이동이 잠기는지 본다.
#
# ★ 핵심 불변식:
#   ① _open_frame/_close_frame — 컨텍스트 설정·핫바 숨김·이동 잠금(모달, 대화와 같은 결).
#   ② 메뉴 탭 — 인벤토리 ↔ 관계 순환, set_tab/cycle_tab.
#   ③ 관계 탭 하트 — _heart_rows가 미호·멜·바나·네오 4행, set_hearts 무크래시(읽기 전용).
#   ④ 한 번에 한 컨텍스트 — 메뉴/출하함/매대가 동시에 안 열린다(frame.context 단일 출처).
# 실행: godot --headless --path game --script res://playtest/frame_test.gd

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

func _initialize() -> void:
	print("══ Phase 2.7 C2 — 공통 인벤토리 프레임(inv_frame.gd) 검증 ══")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()

	# ── ① 열기/닫기(모달) ──
	print("── ① 열기/닫기(모달) ──")
	_check("①pre 처음엔 닫힘", not m.frame.is_open())
	m._open_frame(InventoryFrame.CTX_MENU)
	_check("①a 메뉴 열림 = context MENU", m.frame.context == InventoryFrame.CTX_MENU and m.frame.is_open())
	_check("①b 열리면 핫바 숨김(이중 백팩 방지)", not m.hotbar.visible)
	_check("①c 열리면 이동 잠금(physics off)", not m.player.is_physics_processing())
	_check("①d 프레임 visible", m.frame.visible)
	m._close_frame()
	_check("①e 닫으면 context NONE", m.frame.context == InventoryFrame.CTX_NONE and not m.frame.is_open())
	_check("①f 닫으면 핫바 복귀·이동 해제", m.hotbar.visible and m.player.is_physics_processing())
	_check("①g 닫으면 프레임 숨김", not m.frame.visible)

	# ── ② 메뉴 탭 전환 ──
	print("── ② 메뉴 탭 ──")
	m._open_frame(InventoryFrame.CTX_MENU)
	m.frame.set_tab(InventoryFrame.TAB_INV)
	_check("②a 기본 인벤토리 탭", m.frame.menu_tab == InventoryFrame.TAB_INV)
	m.frame.cycle_tab()
	_check("②b cycle → 관계 탭", m.frame.menu_tab == InventoryFrame.TAB_REL)
	m.frame.cycle_tab()
	_check("②c cycle → 인벤토리 탭 복귀", m.frame.menu_tab == InventoryFrame.TAB_INV)

	# ── ③ 관계 탭 하트(읽기 전용) ──
	print("── ③ 관계 탭 하트 ──")
	var rows: Array = m._heart_rows()
	_check("③a _heart_rows = 4인(미호·멜·바나·네오)", rows.size() == 4)
	_check("③b 각 행에 이름·하트", rows[0].has("name") and rows[0].has("filled") and rows[0].has("total"))
	m.frame.set_tab(InventoryFrame.TAB_REL)
	m.frame.set_hearts(rows)   # 무크래시(읽기 전용 렌더)
	await process_frame
	_check("③c set_hearts 무크래시", true)
	m._close_frame()

	# ── ④ 한 번에 한 컨텍스트(매대/출하함도 같은 프레임) ──
	print("── ④ 단일 컨텍스트 ──")
	m._open_frame(InventoryFrame.CTX_STORE)
	_check("④a 매대 열림 = context STORE", m.frame.context == InventoryFrame.CTX_STORE)
	m._open_frame(InventoryFrame.CTX_BIN)   # 다른 컨텍스트로 교체
	_check("④b 출하함으로 교체 = context BIN(동시 X)", m.frame.context == InventoryFrame.CTX_BIN)
	m._close_frame()
	_check("④c 닫힘", not m.frame.is_open())

	m.queue_free()
	await process_frame

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)
