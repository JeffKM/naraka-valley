extends SceneTree
# ★[S4-T8] 곁들이 육안 덤프(비-headless) — 열매 달린 채집 덤불·이끼 낀 성숙목·해변 채집물을 PNG로.
# ADR-0028 §4-6 "구역 완료마다 인게임 화면으로 시각 확인" 이행용 하네스(woodshop_dump 결).
# ★ --headless 없이: godot --path game --script res://playtest/forage_extras_dump.gd

func _read(p: String) -> PackedByteArray:
	var f := FileAccess.open(p, FileAccess.READ); var b := f.get_buffer(f.get_length()); f.close(); return b
func _write(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(b); f.close()

func _grab(name: String) -> void:
	# 워프는 트윈(≈0.5s)이라 넉넉히 기다린 뒤 굽는다(woodshop_dump에서 얻은 교훈).
	for i in 60:
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
	# 신규 게임 인트로 대화를 걷어낸다(안 걷으면 한지 대화창이 화면을 덮는다).
	for i in 12:
		if not m.dialogue.is_open():
			break
		m.dialogue.advance()
		await process_frame

	# ① 저승 숲 — 열매 달린 덤불 2그루 + 이끼 낀 성숙목을 한 화면에.
	m._rebuild_region(RegionCatalog.JEOSEUNG_FOREST)
	for i in 4:
		await process_frame
	for t in m.bush_tiles_for(RegionCatalog.JEOSEUNG_FOREST):
		m.berry_bushes.set_berry(RegionCatalog.JEOSEUNG_FOREST, t, true)
	# 화면 안 성숙목 몇 그루에 이끼를 얹는다(결정 롤을 기다리지 않고 강제 — 렌더 확인용).
	var mossed := 0
	for t: Vector2i in m.tree_ledger.tiles(RegionCatalog.JEOSEUNG_FOREST):
		if mossed >= 6:
			break
		if m.tree_ledger.is_mature(RegionCatalog.JEOSEUNG_FOREST, t) and t.y < 24:
			m.tree_ledger.set_moss(RegionCatalog.JEOSEUNG_FOREST, t, true)
			mossed += 1
	m._warp(RegionCatalog.JEOSEUNG_FOREST, "", Vector2i(20, 13))
	m.queue_redraw()
	await _grab("forage_extras_forest")

	# ①-b 이끼 낀 성숙목 근접 — 덤불 화면엔 나무가 안 들어와 이끼 렌더가 안 보인다. 이끼 얹은
	#     첫 나무 옆으로 옮겨 그 얼룩만 따로 확인한다(그레이박스 판독성 판정).
	var moss_list: Array = m.tree_ledger.moss_tiles(RegionCatalog.JEOSEUNG_FOREST)
	if not moss_list.is_empty():
		var mt: Vector2i = moss_list[0]
		m._warp(RegionCatalog.JEOSEUNG_FOREST, "", mt + Vector2i(0, 2))
		m.queue_redraw()
		await _grab("forage_extras_moss")

	# ② 황천해 백사장 — 해변 채집물 스폰(존 배선 확인).
	m._rebuild_region(RegionCatalog.HWANGCHEONHAE)
	for i in 4:
		await process_frame
	for d in range(1, 8):
		m.forage_spawns.advance_day(d, 0)
	m._warp(RegionCatalog.HWANGCHEONHAE, "", Vector2i(43, 22))
	m.queue_redraw()
	await _grab("forage_extras_beach")

	if had:
		_write(sp, bak)
	else:
		DirAccess.remove_absolute(sp)
	quit(0)
