extends SceneTree
# P2.5 UI 패스 육안 확인용 글루(ADR-0001 허용) — light_dump와 같은 결로 *실제 GPU 렌더*가
# 필요한 HUD(한글 폰트·하트·패널 스킨)를 PNG로 떨군다. 헤드리스론 폰트 렌더가 안 보이므로
# --headless 없이 띄운다.
# 사용: godot --path game -s res://tools/hud_dump.gd

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	for _i in 6:
		await process_frame
	# 부팅 시 자동 시작되는 옥자 온보딩 대화를 끝까지 넘겨 일상 HUD를 드러낸다.
	while main.dialogue.is_open():
		main.dialogue.advance()
		await process_frame
	# 하트가 보이게 미호·멜·바나 호감도를 채워둔다(스프라이트 교체 전후 비교용).
	main.affinity.points = main.affinity.POINTS_PER_HEART * 3
	main.mel_affinity.points = main.mel_affinity.POINTS_PER_HEART * 2
	main.bana_affinity.points = main.bana_affinity.POINTS_PER_HEART * 1
	for _i in 6:
		await process_frame
	# ① 일상 HUD(시계·혼력·골드·하트 3종·여우불·마일스톤 라벨)
	get_root().get_texture().get_image().save_png("res://tools/hud_default.png")
	print("✅ hud_default.png")
	# ② 대화 패널 + 초상화(미호) — 프레임 패널·초상화 슬롯 확인
	main.dialogue.start(main.miho.display_name(), main.miho.lines())
	for _i in 4:
		await process_frame
	get_root().get_texture().get_image().save_png("res://tools/hud_dialogue.png")
	print("✅ hud_dialogue.png")
	quit()
