extends SceneTree
# ★ Phase 2.8 T3⑤ 육안 글루(ADR-0001) — 안식 농원 *전체 맵*을 한 장에(테두리 프레이밍 확인용).
# home_dump는 집·밭 중심 4구도라 맵 가장자리(나무·바위 테두리)가 화면 밖 → zoom out으로 80×65 전체를
# 한 프레임에 담는다(_cam=player 자식이라 player를 맵 중심에 두고 limit 해제·zoom 낮춤).
# 사용: godot --path game --resolution 1280x720 -s res://tools/home_wide_dump.gd

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
	main.player.visible = false
	main.set_process(false)
	main.player.set_physics_process(false)
	# 전체 맵 한 장: player(=카메라 부모)를 맵 중심에, limit 해제·zoom out.
	main.player.position = main._tile_center_px(Vector2i(40, 32))
	var cam = main._cam
	cam.limit_left = -3000
	cam.limit_top = -3000
	cam.limit_right = 6000
	cam.limit_bottom = 6000
	cam.zoom = Vector2(0.34, 0.34)
	cam.make_current()
	for _i in 12:
		await process_frame
	get_root().get_texture().get_image().save_png("res://tools/home_wide.png")
	print("✅ home_wide.png 저장")
	quit()
