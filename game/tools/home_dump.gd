extends SceneTree
# ★ Phase 2.8 T3 육안 확인 글루(ADR-0001 허용) — facade·prop은 main._draw(GPU) 오버레이라
# --headless로 안 잡힌다. tone_dump 결로 실제 GPU 렌더를 띄워 안식 농원을 네 구도로 PNG에 떨군다
# (★T3② 현관 앞 농장 재배치 기준 — 집 북중앙·밭 남쪽·창고 서북·축사 동북):
#   home_house.png       — 집(북중앙 9×8 코티지) + 문 바로 아래 밭 입구
#   home_farm.png        — 밭 중앙(중앙 스파인·미호·울타리)
#   home_storehouse.png  — 창고(서북) 외관
#   home_barn.png        — 축사(동북) 외관
# 실내 가구(③)는 interior_dump.gd 참조.
# 사용: godot --path game --resolution 1280x720 -s res://tools/home_dump.gd

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	main.onboarding.step = 7                       # DONE — 인트로 컷신·배너 차단
	while main.dialogue.is_open():
		main.dialogue.advance()
	main.fade.modulate.a = 0.0
	main.clock.minutes = 12 * 60                    # 한낮(밝은 톤으로 도색 확인)
	main.lighting.apply(main.clock.minutes)
	main.player.visible = false                     # 장식을 가리지 않게 숨김
	main.set_process(false)
	main.player.set_physics_process(false)

	await _shot(main, Vector2i(44, 6), "res://tools/home_house.png")     # ★ADR-0035 본가(북중앙 저지)
	await _shot(main, Vector2i(42, 14), "res://tools/home_farm.png")     # 스타터 패치(미호·울타리·등불)
	await _shot(main, Vector2i(30, 6), "res://tools/home_storehouse.png")  # 창고(본가 왼쪽)
	await _shot(main, Vector2i(14, 15), "res://tools/home_barn.png")     # ★[S1-3] 축사·동향 계단 노치·pseudo-Z 절벽(남단 고지 하늘 목장)
	print("✅ home_dump 3장 저장 완료")
	quit()

func _shot(main: Node, tile: Vector2i, path: String) -> void:
	main.player.position = main._tile_center_px(tile)
	main._apply_camera_limits()
	for _i in 4:
		await process_frame
	get_root().get_texture().get_image().save_png(path)
	print("  saved ", path)
