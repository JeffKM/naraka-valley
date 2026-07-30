extends SceneTree
# ★[S5-T10 / ADR-0063 아트 스코프] 갱도·나락 아이콘 육안 덤프(비-headless) — 이번 패스가 채운
# 아이콘 29종을 **실제 인벤 슬롯 렌더**로 굽는다(§15 t10_icon_dump.gd와 같은 결·같은 판정 기준).
# 목표는 하나: Slice 5의 **흰박스/색박스 폴백 0**을 눈으로 확정하는 것.
#
# ★ --headless 없이: godot --path game --script res://playtest/t10_mine_icon_dump.gd
#   ⚠ 반드시 game/ 기준 --path로. 워크트리 루트에서 실행하면 무한 행(메모리 교훈).
#
# 산출: /tmp/t10m_inv_<n>.png — 인벤 3면(광물·주괴 / 보석·지오드·드랍 / 무기·소모품·어종)
#      /tmp/t10m_portrait.png — 풀무 도트 초상화(대화창 슬롯 실렌더)
#
# 판정 기준(이 덤프를 보는 법 — §15 t10_icon_dump 주석 승계):
#   ㉠ 흰 사각형(`_draw_crop_tex` 폴백)이 한 칸이라도 있으면 배선 누락이다.
#   ㉡ 단색 사각형(색박스)이 있으면 카테고리 분기가 텍스처를 안 집은 것이다.
#   ㉢ 이웃 슬롯끼리 실루엣·색이 안 갈리면 아이콘 리젝 대상이다(16px 축소 가독성).
#      ★이 패스의 최대 위험처가 여기다 — 29종 중 18종이 **한 원본의 틴트 파생**이라, 같은 줄에
#        나란히 섰을 때 종색이 안 갈리면 파생 전략 자체가 실패다.

func _read(p: String) -> PackedByteArray:
	var f := FileAccess.open(p, FileAccess.READ); var b := f.get_buffer(f.get_length()); f.close(); return b
func _write(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(b); f.close()

func _grab(name: String) -> void:
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/%s.png" % name)
	print("saved /tmp/%s.png" % name)

func _initialize() -> void:
	root.size = Vector2i(960, 540)
	var sp := SaveManager.slot_path(0)
	var bak := _read(sp) if FileAccess.file_exists(sp) else PackedByteArray()
	var had := FileAccess.file_exists(sp)

	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	for i in 8:
		await process_frame
	for i in 12:
		if not m.dialogue.is_open():
			break
		m.dialogue.advance()
		await process_frame

	# 이 패스가 아이콘을 붙인 것 **전량**. 그룹 = 파생 계열 단위라 "한 원본에서 갈린 종들"이
	# 한 화면에 나란히 서고, 그래야 ㉢(종색이 갈리나)이 눈으로 판정된다.
	var groups: Array = [
		# ① 광물 5 + 주괴 4 — 광석(덩이) ↔ 주괴(바)의 **형태 계급 차**와 금속 4색이 한 줄에.
		[ItemCatalog.ORE_MYEONGDONG, ItemCatalog.ORE_YUCHEOL, ItemCatalog.ORE_HWANGCHEONGEUM,
		ItemCatalog.ORE_NARAKCHEOL, ItemCatalog.HONTAN,
		ItemCatalog.INGOT_MYEONGDONG, ItemCatalog.INGOT_YUCHEOL,
		ItemCatalog.INGOT_HWANGCHEONGEUM, ItemCatalog.INGOT_NARAKCHEOL,
		# 대조군 — 기존 슬라이스 자재(톤이 튀는지 나란히 본다)
		ItemCatalog.WOOD, ItemCatalog.HAY],
		# ② 보석 5 + 지오드 2 + 잡귀·보스 드랍 3
		#   ★넋수정(투명 백)과 명부금강(백청)이 **붙어 서는 줄**이다 — 형태를 안 갈랐으면
		#     여기서 같은 아이콘 두 개로 드러난다(원석 다발 ↔ 가공 브릴리언트).
		[ItemCatalog.GEM_NEOKSUJEONG, ItemCatalog.GEM_MYEONGOK, ItemCatalog.GEM_YEOMJUSEOK,
		ItemCatalog.GEM_MYEONGBU_GEUMGANG, ItemCatalog.GEM_OSAEK_HONOK,
		ItemCatalog.GEODE_NEOKAL, ItemCatalog.GEODE_EOPHWA,
		ItemCatalog.NEOKGARU, ItemCatalog.HONBULSSI, ItemCatalog.NARAK_HONJEONG],
		# ③ 무기 5(CAT_TOOL) + 소모품·열쇠 3 + 갱도 어종 2
		#   ★검 5티어가 색으로 갈리나 + 업화도만 실루엣(굽은 도)으로 서나를 본다.
		[ItemCatalog.SWORD_RUSTY, ItemCatalog.SWORD_MYEONGDONG, ItemCatalog.SWORD_YUCHEOL,
		ItemCatalog.SWORD_HWANGCHEONGEUM, ItemCatalog.SWORD_EOPHWADO,
		ItemCatalog.MYEONGBUHWAN, ItemCatalog.STAIRS, ItemCatalog.NARAK_KEY,
		FishCatalog.DOLBINEUL_CHI, FishCatalog.EOPHWA_BUNGJANGEO,
		# 대조군 — 기존 도구·어종(같은 카테고리 칸에서 톤이 튀는지)
		ItemCatalog.PICKAXE, FishCatalog.NEOK_BUNGEO],
	]

	for gi in range(groups.size()):
		# 슬롯을 통째로 비운다(도구 종잣돈까지 치워야 이 패스 아이콘만 한 화면에 든다).
		for i in m.inventory.slots.size():
			m.inventory.slots[i] = null
		var missing: Array = []
		for id: String in groups[gi]:
			if not ItemCatalog.has_item(id):
				missing.append(id)      # 카탈로그에 없는 id = 덤프 목록 오타(배선 문제와 구분)
				continue
			m.inventory.add_item(id, 1)
		if not missing.is_empty():
			print("  ! 카탈로그 미등록(덤프 목록 오타): %s" % str(missing))
		m._open_frame(InventoryFrame.CTX_MENU)
		m.frame.set_tab(InventoryFrame.TAB_INV)
		m.frame._hover_tab = -1
		m.frame._bp_first_row = 0
		m.frame.set_inv_info(m.wallet.gold, 0, m._inv_date_string(), "업화 갱도")
		m.frame.queue_redraw()
		await _grab("t10m_inv_%d" % (gi + 1))
		m._close_frame()
		await process_frame

	# 풀무 도트 초상화 — 대화창 슬롯에 실제로 얹혀 그려지는지(파일 존재가 아니라 *배선* 확인).
	m._set_portrait("풀무", "talk")
	m.dialogue_panel.visible = true
	m.dialogue_text.text = "…사람이 내려왔군. 여긴 화덕일세. 나는 풀무라 하네."
	await _grab("t10m_portrait")

	if had:
		_write(sp, bak)
	else:
		DirAccess.remove_absolute(sp)
	quit(0)
