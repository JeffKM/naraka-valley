# game/tools/pond_shore_dump.gd
# 라이브 연못(SPIRIT_POND_RECT) 물↔흙 측면 물가(4_0 shoreline) 시각 덤프.
# ★ 헤드리스: godot --headless --path game -s res://tools/pond_shore_dump.gd
extends SceneTree

func _initialize() -> void:
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	for i in 8:
		await process_frame
	var tex: ImageTexture = m._ground_detail_tex
	if tex == null:
		print("✗ _ground_detail_tex 없음")
		quit(); return
	var img := tex.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var W := img.get_width()
	var H := img.get_height()
	var T: int = m.TILE
	var pr: Rect2i = m.SPIRIT_POND_RECT   # (26,34,8,7)
	# 연못 + 주변 흙 4칸 여유 크롭.
	var rx := clampi((pr.position.x - 4) * T, 0, W - 1)
	var ry := clampi((pr.position.y - 4) * T, 0, H - 1)
	var rw := mini((pr.size.x + 8) * T, W - rx)
	var rh := mini((pr.size.y + 8) * T, H - ry)
	var crop := img.get_region(Rect2i(rx, ry, rw, rh))
	crop.save_png("/tmp/pond_shore.png")
	print("saved /tmp/pond_shore.png (%dx%d @ %d,%d)  full %dx%d" % [rw, rh, rx, ry, W, H])
	quit()
