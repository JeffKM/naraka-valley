extends SceneTree
# ★[S4-T10 / ADR-0062 결정 10 ㉤] 아이콘 육안 덤프(비-headless) — 이번 패스가 채운 아이콘을
# **실제 인벤 슬롯 렌더**로 굽는다. 목표는 하나: **흰박스/색박스 폴백 0**을 눈으로 확정하는 것.
#
# ★ --headless 없이: godot --path game --script res://playtest/t10_icon_dump.gd
#   ⚠ 반드시 game/ 기준 --path로. 워크트리 루트에서 실행하면 무한 행(메모리 교훈).
#
# 산출: /tmp/t10_inv_<n>.png — 인벤 3면(채집물 24 / 자재·수액·씨앗 19 / 씨앗 봉지 9 + 기존 대조군)
#      /tmp/t10_portrait.png — 옹이 도트 초상화(대화창 슬롯 실렌더)
#
# 판정 기준(이 덤프를 보는 법):
#   ㉠ 흰 사각형(`_draw_crop_tex` 폴백)이 한 칸이라도 있으면 배선 누락이다.
#   ㉡ 단색 사각형(색박스)이 있으면 카테고리 분기가 텍스처를 안 집은 것이다.
#   ㉢ 이웃 슬롯끼리 실루엣이 안 갈리면 아이콘 리젝 대상이다(16px 축소 가독성).

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

	# 이 패스가 아이콘을 붙인 것 **전량**. 그룹 순서 = 인벤 슬롯 순서라 화면에서 묶어 읽힌다.
	var groups: Array = [
		# ① 채집물 24종(로스터 22 중 21 + 불사과 + 덤불 열매 2 + 이끼)
		[ItemCatalog.NEOK_GOSARI, ItemCatalog.JAETBIT_NAENGI, ItemCatalog.JEOSEUNG_DALLAE,
		ItemCatalog.JEOSEUNG_SANDALGI, ItemCatalog.HONIP_BAKHA, ItemCatalog.JAETBIT_DEODEOK,
		ItemCatalog.JAETBIT_DOTORI, ItemCatalog.ANGAE_DORAJI, ItemCatalog.NEOK_SONGI,
		ItemCatalog.EONHON_PPURI, ItemCatalog.SEORI_DONGBAEK, ItemCatalog.SEONGYA_SOLBANGUL,
		ItemCatalog.MIHOK_NANCHO, ItemCatalog.YURYEONGCHO, ItemCatalog.MYEONGWOL_BEOSEOT,
		ItemCatalog.SEORI_HONBAEKCHO, ItemCatalog.JEOSEUNG_SAM, CropCatalog.BULSAGWA,
		ItemCatalog.HWANGCHEON_SANHO, ItemCatalog.NEOK_SEONGGAE, ItemCatalog.YURI_GODUNG,
		ItemCatalog.MULBINEUL_JOGAE, ItemCatalog.NEOK_DALGI, ItemCatalog.JAETBIT_BOKBUNJA],
		# ② 자재·수액·나무 씨앗·채취기 11종 + 이끼
		[ItemCatalog.WOOD, ItemCatalog.HARDWOOD, ItemCatalog.SAP, ItemCatalog.JEOSEUNG_IKKI,
		ItemCatalog.SOLNEOKJIN, ItemCatalog.NEOKSUJI, ItemCatalog.MYEONGDANPUNG_KKUL,
		ItemCatalog.SEED_JEOSEUNGSOL, ItemCatalog.SEED_MYEONGDANPUNG, ItemCatalog.SEED_NEOKCHAM,
		ItemCatalog.TAPPER,
		# ★곁들여 메운 기존 슬라이스 자재 5종(이 덤프가 색박스인 걸 잡아내 스코프에 들어왔다)
		ItemCatalog.PETRIFIED_WOOD, ItemCatalog.SOUL_FIBER, ItemCatalog.EMBER_SHARD,
		ItemCatalog.HAY, ItemCatalog.ROTTEN_NET,
		# 대조군 — 기존 슬라이스 아이콘(톤이 튀는지 나란히 본다)
		ItemCatalog.CRAB_POT, GearCatalog.ROD_T1],
		# ③ 야생·혼합·희귀 씨앗 봉지 9종(전부 CAT_SEED — 작물 id로 조회된다)
		[ItemCatalog.seed_id(CropCatalog.MIXED), ItemCatalog.seed_id(CropCatalog.WILD_PIAN),
		ItemCatalog.seed_id(CropCatalog.WILD_YUHWA), ItemCatalog.seed_id(CropCatalog.WILD_MANGYEON),
		ItemCatalog.seed_id(CropCatalog.WILD_SEONGYA),
		ItemCatalog.seed_id(CropCatalog.WILD_MIHOK_NANCHO),
		ItemCatalog.seed_id(CropCatalog.WILD_YURYEONGCHO),
		ItemCatalog.seed_id(CropCatalog.WILD_MYEONGWOL),
		ItemCatalog.seed_id(CropCatalog.WILD_SEORI_HONBAEK)],
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
		m.frame.set_inv_info(m.wallet.gold, 0, m._inv_date_string(), "안식 농원")
		m.frame.queue_redraw()
		await _grab("t10_inv_%d" % (gi + 1))
		m._close_frame()
		await process_frame

	# 옹이 도트 초상화 — 대화창 슬롯에 실제로 얹혀 그려지는지(파일 존재가 아니라 *배선* 확인).
	m._set_portrait("옹이", "talk")
	m.dialogue_panel.visible = true
	m.dialogue_text.text = "…손님이군. 여긴 목공방일세. 나는 옹이라 부르면 되네."
	await _grab("t10_portrait")

	if had:
		_write(sp, bak)
	else:
		DirAccess.remove_absolute(sp)
	quit(0)
