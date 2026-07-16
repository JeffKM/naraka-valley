# game/tools/wang_live_dump.gd
# Wang 경계 라이브 톤 덤프 — main 정상 부팅(mute on·retone 정상)의 _ground_detail_tex를 저장.
# 전환 타일 잔디 톤이 라이브 base 잔디(muted)와 일치하는지 판정용(Task 5 mute 검증).
# ★ 헤드리스 가능: godot --headless --path game -s res://tools/wang_live_dump.gd
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
		quit()
		return
	var img := tex.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.save_png("/tmp/wang_live_full.png")
	var W := img.get_width()
	var H := img.get_height()
	var T: int = m.TILE
	# 잔디↔흙 경계 밀집 크롭(마당 우중앙 ~24×20칸). 이미지 경계 clamp.
	var rx := clampi(38 * T, 0, maxi(0, W - 1))
	var ry := clampi(14 * T, 0, maxi(0, H - 1))
	var rw := mini(24 * T, W - rx)
	var rh := mini(20 * T, H - ry)
	var crop := img.get_region(Rect2i(rx, ry, rw, rh))
	crop.save_png("/tmp/wang_live_crop.png")
	print("saved /tmp/wang_live_full.png (%dx%d) · /tmp/wang_live_crop.png (%dx%d @ %d,%d)" % [W, H, rw, rh, rx, ry])
	quit()
