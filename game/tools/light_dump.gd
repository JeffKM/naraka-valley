extends SceneTree
# P2.3③ 라이팅 육안 확인용 글루(ADR-0001 허용) — map_dump와 달리 *실제 GPU 렌더*가
# 필요하므로(CanvasModulate·PointLight2D는 합성 효과) --headless 없이 띄워 한낮·황혼·밤
# 세 시각의 뷰포트를 PNG로 떨군다.
# 사용: godot --path game -s res://tools/light_dump.gd

const SHOTS := [[12 * 60, "noon"], [18 * 60, "dusk"], [22 * 60, "night"]]

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	for _i in 4:
		await process_frame
	for shot in SHOTS:
		main.clock.running = false
		main.clock.minutes = float(shot[0])
		main.lighting.apply(main.clock.minutes)
		for _i in 3:
			await process_frame
		var img := get_root().get_texture().get_image()
		img.save_png("res://tools/light_%s.png" % shot[1])
		print("✅ light_%s.png 저장 (밝기 %.2f)" % [shot[1], main.lighting.tint_for(float(shot[0])).v])
	# 밤 등불 빛웅덩이 확인 — 플레이어(카메라)를 길가 등불(28,15) 옆으로 옮긴 밤 샷.
	main.clock.minutes = float(22 * 60)
	main.lighting.apply(main.clock.minutes)
	main.player.position = Vector2(28 * 16 + 8, 19 * 16 + 8)
	for _i in 4:
		await process_frame
	get_root().get_texture().get_image().save_png("res://tools/light_night_lamp.png")
	print("✅ light_night_lamp.png 저장")
	quit()
