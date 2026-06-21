extends SceneTree
# P2.7 톤 일관성 패스 육안 확인용 글루(ADR-0001 허용) — light_dump처럼 *실제 GPU 렌더*가
# 필요하므로(손님·잡귀 _draw 박스·라이팅·도색 무대) --headless 없이 띄워 네 장을 PNG로 떨군다:
#   ㉠ tone_cafe_day.png    — 낮 카페(손님 박스가 도색 무대에서 안 깨지나)
#   ㉠ tone_night_bar.png   — 밤 바(잡귀 박스 + 밤 손님 박스, 라이팅 위)
#   ㉡ tone_cast.png        — 5캐릭터 한 줄(한 캐스트로 보이나)
#   ㉢ tone_miho_compare.png — 도트-미호 ↔ 초상화-미호(동일인으로 읽히나)
# 사용: godot --path game --resolution 1280x720 -s res://tools/tone_dump.gd

const TILE := 32

func _init() -> void:
	await _shot_cafe_day()
	await _shot_night_bar()
	await _shot_cast()
	await _shot_miho_compare()
	print("✅ tone_dump 4장 저장 완료")
	quit()

# main을 인스턴스화하고 인트로 컷신·페이드를 걷어 깨끗한 무대로 만든다(_process는 끈다 —
# 손님/잡귀를 직접 스폰해 결정적으로 캡처).
func _make_main() -> Node:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	main.onboarding.step = 7                     # DONE — 인트로 컷신·배너 차단
	while main.dialogue.is_open():
		main.dialogue.advance()
	main.okja.visible = true
	main.fade.modulate.a = 0.0
	main.set_process(false)
	main.player.set_physics_process(false)
	return main

func _enter_cafe(main: Node, player_tile: Vector2i) -> void:
	main._indoor = "카페"
	main.player.position = main._tile_center_px(player_tile)   # 카메라 프레이밍용
	main.player.visible = false                                # 좌석/스폿을 가리지 않게 숨김
	main._apply_camera_limits()

func _capture(path: String) -> void:
	for _i in 3:
		await process_frame
	get_root().get_texture().get_image().save_png("res://tools/%s" % path)
	print("✅ %s 저장" % path)

# ㉠ 낮 카페 — 영업 중 + 세 좌석에 손님 착석.
func _shot_cafe_day() -> void:
	var main = await _make_main()
	main.clock.minutes = 16.0 * 60.0             # 카페 영업창(15–19시) 안
	main.clock.running = false
	main.lighting.apply(main.clock.minutes)      # 한낮 톤
	main.cafe.tick(0.1, main.clock.minutes)      # 영업 개시(_open_shop 전이)
	for _i in main.SEAT_TILES.size():
		main.cafe._seat_customer()                # 세 좌석 채움(결정적)
	_enter_cafe(main, Vector2i(14, 43))          # 좌석 줄(y42) 아래에서 위를 본다
	main.queue_redraw()
	await _capture("tone_cafe_day.png")
	main.free()

# ㉠ 밤 바 — 옵트인(open_bar) + 잡귀 스폿·밤 손님 좌석 채움.
func _shot_night_bar() -> void:
	var main = await _make_main()
	main.clock.minutes = 21.0 * 60.0             # 밤 창(19–24시) 안
	main.clock.running = false
	main.lighting.apply(main.clock.minutes)      # 저승 인디고 밤 톤
	main.night_bar.open_bar(main.clock.minutes)  # 옵트인(잡귀 깃들기 시작)
	main.night_bar.tick(0.1, main.clock.minutes) # _was_active=true(is_active 게이트)
	for i in main.NIGHT_SPOT_TILES.size():
		main.night_bar._spawn_jobgui()            # 잡귀 스폿 채움
	for i in main.SEAT_TILES.size():
		main.night_bar._seat_customer()           # 밤 손님 좌석 채움
	_enter_cafe(main, Vector2i(14, 43))          # 좌석(y42)·스폿(y44)이 한 화면에
	main.queue_redraw()
	await _capture("tone_night_bar.png")
	main.free()

# ㉡ 5캐릭터 한 캐스트 — 기존 cast_preview 씬을 그대로 띄워 캡처.
func _shot_cast() -> void:
	var cast = load("res://cast_preview.tscn").instantiate()
	get_root().add_child(cast)
	await _capture("tone_cast.png")
	cast.free()

# ㉢ 도트-미호 ↔ 초상화-미호 — map_dump처럼 CPU Image 합성(blend_rect)으로 한 장에 담는다
# (GPU draw 노드 대신 결정적). 위 줄=도트 4방향 워크 프레임(80×80), 아래=초상화 2표정(240×240).
func _shot_miho_compare() -> void:
	var out := Image.create_empty(560, 360, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.12, 0.12, 0.15, 1.0))
	# 도트-미호: 4방향 정지 프레임(시트 80×320, 행=방향, 행당 1프레임)을 위 줄에 native로.
	var simg := (load("res://assets/characters/miho_walk.png") as Texture2D).get_image()
	if simg.get_format() != Image.FORMAT_RGBA8:
		simg.convert(Image.FORMAT_RGBA8)
	for d in 4:
		var fimg := simg.get_region(Rect2i(0, d * 80, 80, 80))
		out.blend_rect(fimg, Rect2i(0, 0, 80, 80), Vector2i(12 + d * 90, 10))
	# 초상화-미호: 두 표정을 240×240으로 줄여 아래에.
	var px := 12
	for pp in ["res://assets/portraits/miho.png", "res://assets/portraits/miho_smile.png"]:
		var pimg := (load(pp) as Texture2D).get_image()
		if pimg.get_format() != Image.FORMAT_RGBA8:
			pimg.convert(Image.FORMAT_RGBA8)
		pimg.resize(240, 240, Image.INTERPOLATE_LANCZOS)
		out.blend_rect(pimg, Rect2i(0, 0, 240, 240), Vector2i(px, 105))
		px += 264
	out.save_png("res://tools/tone_miho_compare.png")
	print("✅ tone_miho_compare.png 저장(CPU 합성)")
