extends SceneTree
# ★[S4-T7] 목공방 육안 덤프(비-headless) — 실내 방(옹이·카운터·작업대)과 매대 프레임을 PNG로 굽는다.
# ADR-0028 §4-6 "구역/캐릭터 완료마다 인게임 화면으로 시각 확인" 이행용 하네스.
# ★ --headless 없이: godot --path game --script res://playtest/woodshop_dump.gd

func _read(p: String) -> PackedByteArray:
	var f := FileAccess.open(p, FileAccess.READ); var b := f.get_buffer(f.get_length()); f.close(); return b
func _write(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(b); f.close()

func _grab(name: String) -> void:
	# ★ 워프는 트윈(0.22+0.08+0.22 ≈ 0.5s)이라 프레임 몇 장으로는 페이드 한복판을 찍는다.
	#   60fps 기준 넉넉히 60프레임(1s) 기다린 뒤 굽는다.
	for i in 60:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/%s.png" % name)
	print("saved /tmp/%s.png" % name)

func _initialize() -> void:
	root.size = Vector2i(960, 540)
	# 세이브 격리(부팅이 새 게임/로드하므로 개발 save.dat 백업 — frame_dump 규약 그대로).
	var sp := SaveManager.slot_path(0)
	var bak := _read(sp) if FileAccess.file_exists(sp) else PackedByteArray()
	var had := FileAccess.file_exists(sp)

	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	for i in 8:
		await process_frame

	# 신규 게임 인트로 대화(옥자 5줄)를 걷어낸다 — 안 걷으면 한지 대화창이 화면을 통째로 덮는다.
	for i in 12:
		if not m.dialogue.is_open():
			break
		m.dialogue.advance()
		await process_frame

	# ① 목공방 실내 — 저승 숲으로 이동한 뒤 실내 문 안쪽에 선다(카운터·옹이·작업대가 보이는 자리).
	m._rebuild_region(RegionCatalog.JEOSEUNG_FOREST)
	for i in 4:
		await process_frame
	m._warp(RegionCatalog.JEOSEUNG_FOREST, "목공방", m.WOODSHOP_IN_TILE)
	await _grab("woodshop_room")

	# ② 진행 중 의뢰가 있는 방(작업대에 목재가 얹힌 상태) — 원장 상태의 방 안 가시화 확인.
	m.carpenter.order(Carpenter.PROJ_BIG_COOP, m.clock.day)
	m.queue_redraw()
	await _grab("woodshop_room_building")

	# ③ 매대 프레임 — 건축 서브탭(프로젝트 2건 + 진행 표시).
	m._open_frame(InventoryFrame.CTX_WOODSHOP)
	await _grab("woodshop_store_build")

	# ④ 매대 프레임 — 물품 서브탭(가구 세트 + 원목 소매).
	m.frame.woodshop_tab = InventoryFrame.WS_TAB_GOODS
	m._refresh_woodshop()
	m.frame.queue_redraw()
	await _grab("woodshop_store_goods")

	# 세이브 원복(개발 슬롯을 덤프가 오염시키지 않게).
	if had:
		_write(sp, bak)
	else:
		DirAccess.remove_absolute(sp)
	quit(0)
