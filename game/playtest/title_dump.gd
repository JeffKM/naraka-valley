extends SceneTree
# 타이틀 화면 육안 덤프(비-headless) — 실제 렌더를 PNG로 굽는다(레이아웃·로고 셰이더·파티클 확인).
# ★ --headless 없이 실행: godot --path game --script res://playtest/title_dump.gd
# hud_dump 결(GPU 폰트·셰이더 필요). run_tests.sh(헤드리스)엔 넣지 않는다.

func _grab(name: String) -> void:
	# 렌더 완료까지 몇 프레임 돌린 뒤 루트 뷰포트 이미지를 저장.
	for i in 6:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("/tmp/%s.png" % name)
	print("saved /tmp/%s.png  %dx%d" % [name, img.get_width(), img.get_height()])

func _read(p: String) -> PackedByteArray:
	var f := FileAccess.open(p, FileAccess.READ); var b := f.get_buffer(f.get_length()); f.close(); return b

func _write(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(b); f.close()

func _initialize() -> void:
	root.size = Vector2i(960, 540)
	var sm := SaveManager.new()
	# ★개발 세이브 격리 — 3 슬롯 파일을 백업하고 끝에 복원한다(save_slot_test 결).
	var paths := [SaveManager.slot_path(0), SaveManager.slot_path(1), SaveManager.slot_path(2)]
	var baks := {}
	for p in paths:
		if FileAccess.file_exists(p): baks[p] = _read(p)
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	sm.save_game({"x": 1}, 0, {"day": 34, "soul": 85})
	sm.save_game({"x": 1}, 2, {"day": 200, "soul": 40})
	var ts := TitleScreen.new()
	root.add_child(ts)
	ts.setup(sm)
	# MENU
	ts._canvas.queue_redraw()
	await _grab("title_menu")
	# 이어하기 → SLOTS
	ts._go(TitleScreen.State.SLOTS)
	ts._canvas.queue_redraw()
	await _grab("title_slots")
	# CONFIRM_QUIT
	ts._go(TitleScreen.State.CONFIRM_QUIT)
	ts._canvas.queue_redraw()
	await _grab("title_quit")
	# 정리 — 더미 슬롯 제거 후 개발 세이브 복원
	sm.delete_save(0); sm.delete_save(2)
	for p in paths:
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		if baks.has(p): _write(p, baks[p])
	quit(0)
