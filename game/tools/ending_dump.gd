extends SceneTree
# 엔딩(마무리 화면) 육안 확인 글루(ADR-0001 허용). 슬라이스 종료를 강제해 EndingPanel을
# 띄우고 viewport를 PNG로 떤다 — 텍스트 짤림 진단용. GPU 필요(viewport 캡처).
# 사용: godot --path game --resolution 1920x1080 -s res://tools/ending_dump.gd

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	# 인트로 대화·페이드 정리
	if main.dialogue:
		while main.dialogue.is_open():
			main.dialogue.advance()
	main.fade.modulate.a = 0.0
	# 슬라이스 종료 강제 → 마무리 화면
	main.clock.day = RunSummary.RUN_DAYS + 1
	main._end_run()
	for i in 6:
		await process_frame
	var img := get_root().get_viewport().get_texture().get_image()
	img.save_png("res://tools/ending_dump.png")
	print("✅ tools/ending_dump.png 저장 (%dx%d)" % [img.get_width(), img.get_height()])
	quit()
