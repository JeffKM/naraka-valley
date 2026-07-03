extends SceneTree

# 트렐리스 렌더 검증 dump (ADR-0001 허용 글루). 실제 밭 SOIL 타일 배경 위에 황천포도
# 3단계를 _draw_crops 트렐리스 훅과 *동일 좌표*(밑동 접지·위로 1칸 솟음, 32×64)로
# 합성해 ①밭흙 warm 톤 대조 ②밑동 접지/위로 솟음을 육안 확인한다.
# (실제 심기·성장강제 없이 훅 좌표를 그대로 재현 = GPU _draw_crops와 픽셀 동일.)
# 사용: godot --headless --path game -s res://tools/trellis_dump.gd

func _init():
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var ground: TileMapLayer = main.get_node("Ground")
	var field: TileMapLayer = main.get_node("Field")

	# 밭 SOIL 칸 수집(_grid[y][x] == SOIL)
	var byrow := {}
	for y in main._grid.size():
		var row: Array = main._grid[y]
		for x in row.size():
			if row[x] == main.SOIL:
				if not byrow.has(y):
					byrow[y] = []
				byrow[y].append(x)
	if byrow.is_empty():
		push_error("밭 SOIL 칸 없음"); quit(); return

	# 3칸 이상 있는 행을 위에서부터 골라 심을 3칸(가로로 벌림) 선택
	var rows: Array = byrow.keys(); rows.sort()
	var pick_y: int = rows[0]
	for ry in rows:
		if byrow[ry].size() >= 3:
			pick_y = ry; break
	var xs: Array = byrow[pick_y]; xs.sort()
	var cells := [
		Vector2i(xs[0], pick_y),
		Vector2i(xs[xs.size() / 2], pick_y),
		Vector2i(xs[xs.size() - 1], pick_y),
	]

	# 밭 bbox(+ 여유 2칸, 위로 솟음 공간)
	var minx := 9999; var miny := 9999; var maxx := -1; var maxy := -1
	for ry in rows:
		miny = min(miny, ry); maxy = max(maxy, ry)
		for x in byrow[ry]:
			minx = min(minx, x); maxx = max(maxx, x)
	var ox := minx - 1
	var oy := miny - 2
	var w := (maxx - ox + 2) * 32
	var h := (maxy - oy + 2) * 32
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.05, 0.07, 1.0))
	for layer in [ground, field]:
		_blit_layer(layer, out, ox, oy)

	# 황천포도 3단계 — 트렐리스 훅과 동일: (t.x, t.y-1)*32, 32×64
	var frames: Array = main.CROP_SPRITES[CropCatalog.HWANGCHEON_PODO]
	for st in 3:
		var img: Image = frames[st].get_image()
		var t: Vector2i = cells[st]
		var px := (t.x - ox) * 32
		var py := (t.y - 1 - oy) * 32
		out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(px, py))

	out.save_png("res://tools/trellis_dump.png")
	print("✅ trellis_dump.png 저장 — 심은 칸: ", cells)
	quit()

func _blit_layer(layer: TileMapLayer, out: Image, ox: int, oy: int) -> void:
	var ts := layer.tile_set
	for cell in layer.get_used_cells():
		var sid := layer.get_cell_source_id(cell)
		if sid < 0:
			continue
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		var ac := layer.get_cell_atlas_coords(cell)
		var region := src.get_tile_texture_region(ac, 0)
		var timg := src.texture.get_image().get_region(region)
		out.blend_rect(timg, Rect2i(Vector2i.ZERO, timg.get_size()), Vector2i((cell.x - ox) * 32, (cell.y - oy) * 32))
