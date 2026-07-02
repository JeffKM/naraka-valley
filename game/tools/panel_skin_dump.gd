extends SceneTree
# ★ Phase B(ADR-0048) 육안 확인 글루 — 전역 Panel 테마를 검정 → 태운 한지(hanji_frame)로 바꾼 뒤
# 마일스톤·상점·카페정산 팝업이 한지 톤 + 먹빛 라벨로 읽히는지 *실제 GPU 렌더*로 떨군다.
# 이 세 패널은 게임 흐름 특정 상태에서만 뜨므로 여기선 강제로 visible + 샘플 텍스트로 캡처한다.
# 사용: godot --path . --resolution 960x540 -s res://tools/panel_skin_dump.gd

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	main.onboarding.step = 7
	while main.dialogue.is_open():
		main.dialogue.advance()
	main.fade.modulate.a = 0.0
	main.set_process(false)
	main.player.set_physics_process(false)
	# 세 팝업을 동시에 띄워 한 장에(겹치지 않게 원래 앵커 유지 — 서로 다른 위치).
	main.milestone_panel.visible = true
	main.milestone_text.text = "카페 2단계 달성!\n혼백 손님이 늘었습니다"
	main.shop_panel.visible = true
	main.shop_text.text = "만물상 매대\n혼령초 씨앗  15골드\n네오 호감도 -10% 할인"
	main.cafe_summary_panel.visible = true
	main.cafe_summary_text.text = "오늘 카페 정산\n서빙 12잔 · +240골드"
	for _i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://tools/panel_skin.png")
	print("✅ panel_skin.png 저장")
	quit()
