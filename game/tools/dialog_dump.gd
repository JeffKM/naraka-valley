extends SceneTree
# 대화창 룩 프로토타입을 PNG로 굽는 글루(ADR-0001 허용). 폰트·한지 텍스처 GPU 렌더가
# 필요하므로 --headless 없이(창 O) 실행: godot --path game -s res://tools/dialog_dump.gd --resolution 960x540

func _init() -> void:
	var s: Node = load("res://portrait_preview.tscn").instantiate()
	get_root().add_child(s)
	for _i in 10:
		await process_frame
	get_root().get_texture().get_image().save_png("res://tools/dialog_dump.png")
	print("✅ dialog_dump.png")
	# 캐릭터별 컷도 한 장씩(옥자·멜)
	if s.has_method("_show"):
		s._show(1)
		for _i in 4:
			await process_frame
		get_root().get_texture().get_image().save_png("res://tools/dialog_dump_okja.png")
		s._show(3)
		for _i in 4:
			await process_frame
		get_root().get_texture().get_image().save_png("res://tools/dialog_dump_mel.png")
		print("✅ okja/mel 컷")
	quit()
