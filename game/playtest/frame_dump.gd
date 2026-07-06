extends SceneTree
# 통합 메뉴 프레임 육안 덤프(비-headless) — 옵션 탭·인벤토리 탭 렌더를 PNG로 굽는다.
# owner 리포트(2026-07-06) 레이아웃 수정 확인용: 옵션 탭 "설정"/"음악 볼륨" 겹침·정리 버튼 위치.
# ★ --headless 없이: godot --path game --script res://playtest/frame_dump.gd

func _read(p: String) -> PackedByteArray:
	var f := FileAccess.open(p, FileAccess.READ); var b := f.get_buffer(f.get_length()); f.close(); return b
func _write(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(b); f.close()

func _grab(name: String) -> void:
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/%s.png" % name)
	print("saved /tmp/%s.png" % name)

func _initialize() -> void:
	root.size = Vector2i(960, 540)
	# 세이브 격리(부팅이 새 게임/로드하므로 개발 save.dat 백업).
	var sp := SaveManager.slot_path(0)
	var bak := _read(sp) if FileAccess.file_exists(sp) else PackedByteArray()
	var had := FileAccess.file_exists(sp)

	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	for i in 8:
		await process_frame

	# 옵션 탭 — 옵션(gear) 탭 호버 툴팁 표시(탭 바 우측에 뜨는지 확인)
	m._open_frame(InventoryFrame.CTX_MENU)
	m.frame.set_tab(InventoryFrame.TAB_OPTIONS)
	m.frame.set_settings(0.8, 0.9, false)
	m.frame._hover_tab = InventoryFrame.TAB_OPTIONS
	m.frame.queue_redraw()
	await _grab("frame_options")

	# 인벤토리 탭 — 관계(heart) 탭 호버 툴팁 표시
	m.frame.set_tab(InventoryFrame.TAB_INV)
	m.frame._hover_tab = InventoryFrame.TAB_REL
	m.frame.queue_redraw()
	await _grab("frame_inv")

	m._close_frame()
	m.queue_free()
	await process_frame

	# 세이브 복원
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	if had: _write(sp, bak)
	quit(0)
