extends SceneTree
# 실내 카메라 격리 마스크 육안 검증(GPU 필요 — tone_dump 결, --headless 없이). HOME 집 안으로
# 들어가 방 위쪽(풀밭 누출 최악 케이스)에 플레이어를 두고, 마스크가 방 바깥(외부 풀밭)을 검게
# 가리는지 PNG로 떨군다. 사용: godot --path game --resolution 1280x720 -s res://tools/indoor_mask_check.gd

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	main.onboarding.step = 7
	while main.dialogue.is_open():
		main.dialogue.advance()
	main.fade.modulate.a = 0.0
	# HOME 집 실내로 — _indoor 설정 + 방 위쪽 모서리에 플레이어(풀밭이 새던 자리)
	var cr: Rect2i = main._buildings["집"]["cam"]
	main._indoor = "집"
	main.player.position = main._tile_center_px(Vector2i(cr.position.x + cr.size.x / 2, cr.position.y + 2))
	main._apply_camera_limits()
	# _process를 끄지 않고(마스크 갱신 위해) 한 번 직접 주입 + 여러 프레임 대기
	main.indoor_mask.set_room(true, Rect2(cr.position.x * 32, cr.position.y * 32, cr.size.x * 32, cr.size.y * 32))
	for _i in 6:
		await process_frame
	get_root().get_texture().get_image().save_png("res://tools/indoor_mask_check.png")
	print("✅ indoor_mask_check.png 저장")
	quit()
