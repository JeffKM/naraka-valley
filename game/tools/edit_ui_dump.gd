extends SceneTree
# ★ 배치 모드 UI 점검 글루 — 배치 모드 ON 상태의 실제 화면(UI scale 1.5 반영)을 한 장에.
# 사용: godot --path game --resolution 1920x1080 -s res://tools/edit_ui_dump.gd

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	main.onboarding.step = 7
	while main.dialogue.is_open():
		main.dialogue.advance()
	main.fade.modulate.a = 0.0
	main.clock.minutes = 12 * 60
	main.lighting.apply(main.clock.minutes)
	main._toggle_edit_mode()   # 배치 모드 ON — 패널 풀로 펼침
	for _i in 8:
		await process_frame
	get_root().get_texture().get_image().save_png("res://tools/edit_ui.png")
	print("✅ edit_ui.png 저장")
	quit()
