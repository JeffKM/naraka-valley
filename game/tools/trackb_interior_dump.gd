extends SceneTree
# ★[ADR-0048 §2] 건물 실내 전용 바닥·벽 타일 육안 확인 — 갈무리방·넋우릿간·넋둥우리 3방을
#   차례로 진입해 각 한 장씩 떨군다(집 HOUSE 재사용 탈피 확인).
# 사용: godot --path game --resolution 1280x720 -s res://tools/trackb_interior_dump.gd

func _enter_and_shot(main, bid: String, rc: Rect2i, out: String) -> void:
	var b: Dictionary = main._buildings[bid]
	main.player.position = main._tile_center_px(b["ext_door"])
	main._maybe_toggle_building()
	var until := Time.get_ticks_msec() + 3000
	while main._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame
	print("  [", bid, "] indoor=", main._indoor)
	var center := rc.position + Vector2i(rc.size.x / 2, rc.size.y / 2)
	main.player.position = main._tile_center_px(center)
	main._apply_camera_limits()
	for _i in 6:
		await process_frame
	get_root().get_texture().get_image().save_png("res://tools/%s" % out)
	print("    saved ", out)
	# 퇴장 — 실내 문으로 이동 후 토글(문 위에서만 전환)
	main.player.position = main._tile_center_px(b["door"])
	main._maybe_toggle_building()
	until = Time.get_ticks_msec() + 3000
	while main._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame
	print("    exited → indoor=", main._indoor)

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
	await _enter_and_shot(main, "창고", main.STOREHOUSE_RECT, "interior_storehouse.png")
	await _enter_and_shot(main, "넋우릿간", main.NEOKURITGAN_RECT, "interior_barn.png")
	await _enter_and_shot(main, "넋둥우리", main.NEOKDUNGURI_RECT, "interior_coop.png")
	quit()
