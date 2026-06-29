extends SceneTree
# 미호 인게임 스프라이트 검증 글루(ADR-0001) — main을 띄워 Miho 노드의 실제
# AnimatedSprite2D(char_sprite.make 거친 것)에서 4방향 idle 프레임을 뽑아 한 장으로.
# miho_walk.png 교체가 인게임에 반영됐는지 확인. 사용: godot --headless --path game -s res://tools/miho_check.gd

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var miho = main.get_node_or_null("Miho")
	if miho == null:
		print("❌ Miho 노드 없음"); quit(); return
	var spr: AnimatedSprite2D = null
	for c in miho.get_children():
		if c is AnimatedSprite2D:
			spr = c; break
	if spr == null:
		print("❌ Miho에 AnimatedSprite2D 없음(그레이박스 폴백?)"); quit(); return
	var anims := ["walk_down","walk_up","walk_right","walk_left"]
	var F := 80
	var out := Image.create(F*4, F, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.35,0.38,0.34,1))
	for i in anims.size():
		var a: String = anims[i]
		if not spr.sprite_frames.has_animation(a):
			continue
		var cnt := spr.sprite_frames.get_frame_count(a)
		var ftex := spr.sprite_frames.get_frame_texture(a, 0)
		if ftex == null:
			continue
		var fimg := ftex.get_image()
		fimg.convert(Image.FORMAT_RGBA8)
		out.blit_rect(fimg, Rect2i(Vector2i.ZERO, fimg.get_size()), Vector2i(i*F, 0))
		print("%s: %d프레임, 프레임크기 %s" % [a, cnt, str(fimg.get_size())])
	out.save_png("res://tools/miho_check.png")
	print("✅ tools/miho_check.png 저장")
	quit()
