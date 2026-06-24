extends SceneTree
# ★ T3 ③ 잔여 패스 — 실내 가구 flush 확인용 임시 글루(ADR-0001). 집 실내로 진입해 한 장 떨군다.
# 사용: godot --path game --resolution 1280x720 -s res://tools/interior_dump.gd

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
	# 집 진입
	main.player.position = main._tile_center_px(main.HOUSE_EXT_DOOR)
	main._maybe_toggle_building()
	var until := Time.get_ticks_msec() + 3000
	while main._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame
	print("indoor=", main._indoor, " region=", main._region)
	# 방 중앙에 세우고(가구 안 가리게) 한 장
	main.player.visible = false
	main.set_process(false)
	main.player.set_physics_process(false)
	var rc: Rect2i = main.HOME_HOUSE_RECT
	var center := rc.position + Vector2i(rc.size.x / 2, rc.size.y / 2)
	main.player.position = main._tile_center_px(center)
	main._apply_camera_limits()
	for _i in 6:
		await process_frame
	get_root().get_texture().get_image().save_png("res://tools/interior_house.png")
	print("  saved interior_house.png")
	quit()
