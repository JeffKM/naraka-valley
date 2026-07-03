extends SceneTree

# 육안 글루(ADR-0001) — 야외 농장 인프라(여물광·혼우물·사료풀) 아트를 풀밭 위에 CPU 합성.
# 사료풀은 실제 _draw_forage 변형(타일 해시 좌우반전+오프셋)을 1:1 재현해 6×3 블록이 격자로
# 읽히는지/자연스러운 밭으로 읽히는지 눈으로 판단한다. 사용: godot --headless --path game -s res://tools/farm_infra_dump.gd

const TILE := 32

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var cols := 22
	var rows := 14
	var out := Image.create(cols * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
	# 풀 타일 베이스
	var gsrc := (main.get_node("Ground") as TileMapLayer).tile_set.get_source(0) as TileSetAtlasSource
	var grs: int = gsrc.texture_region_size.x
	var gcoord: Vector2i = main._terrain_base_atlas(main.TR_GRASS)
	var gatlas: Image = gsrc.texture.get_image()
	if gatlas.get_format() != Image.FORMAT_RGBA8:
		gatlas.convert(Image.FORMAT_RGBA8)
	var gtile := Image.create(grs, grs, false, Image.FORMAT_RGBA8)
	gtile.blit_rect(gatlas, Rect2i(gcoord.x * grs, gcoord.y * grs, grs, grs), Vector2i.ZERO)
	for ty in range(rows):
		for tx in range(cols):
			out.blit_rect(gtile, Rect2i(0, 0, grs, grs), Vector2i(tx * TILE, ty * TILE))
	# 여물광·혼우물 = bottom-center + 소프트 접지 그림자(footprint 3×3)
	_blit_struct(out, main._prop_tex("silo"), Vector2i(2, 1), Vector2i(3, 3))
	_blit_struct(out, main._prop_tex("well"), Vector2i(8, 1), Vector2i(3, 3))
	# 사료풀 6×3 블록(다 자람) — _draw_forage 변형 재현
	var grown: Texture2D = main._prop_tex("forage_grown")
	var cut: Texture2D = main._prop_tex("forage_cut")
	for ty in range(6, 9):
		for tx in range(2, 8):
			_blit_forage(out, grown, Vector2i(tx, ty))
	# 비교용: 아랫줄 = 벤 자리(cut)
	for tx in range(2, 8):
		_blit_forage(out, cut, Vector2i(tx, 10))
	out.save_png("res://tools/farm_infra_dump.png")
	print("✅ farm_infra_dump.png 저장 (여물광·혼우물·사료풀6×3+cut)")
	quit()

# 구조물 = footprint 하단중앙 앵커 + 납작 SE 접지 그림자(main._blit_facade_anchored 재현 간이판)
func _blit_struct(out: Image, tex: Texture2D, anchor: Vector2i, fp: Vector2i) -> void:
	if tex == null:
		return
	var img := tex.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var sz := img.get_size()
	var cx := int((anchor.x + fp.x * 0.5) * TILE)
	var base_y := (anchor.y + fp.y) * TILE
	# 접지 그림자(납작 타원)
	var srx := sz.x * 0.42
	var sry := srx * 0.17
	var scx := cx + 2
	var scy := int(base_y - sry * 0.4)
	for sy in range(int(scy - sry), int(scy + sry) + 1):
		for sx in range(int(scx - srx), int(scx + srx) + 1):
			var nx := (sx - scx) / srx
			var ny := (sy - scy) / sry
			if nx * nx + ny * ny <= 1.0 and sx >= 0 and sy >= 0 and sx < out.get_width() and sy < out.get_height():
				out.set_pixel(sx, sy, out.get_pixel(sx, sy).lerp(Color(0, 0, 0, 1), 0.34))
	out.blend_rect(img, Rect2i(Vector2i.ZERO, sz), Vector2i(cx - sz.x / 2, base_y - sz.y))

# 사료풀 타일 = _draw_forage 변형(해시 좌우반전+오프셋) 1:1 재현
func _blit_forage(out: Image, tex: Texture2D, tile: Vector2i) -> void:
	if tex == null:
		return
	var img := tex.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var sz := img.get_size()
	var px := Vector2i(tile.x * TILE, tile.y * TILE)
	var hsh: int = absi((tile.x * 73856093) ^ (tile.y * 19349663))
	var bx := px.x + int((TILE - sz.x) * 0.5)
	var by := px.y + TILE - sz.y
	var src := img
	if (hsh & 1) == 1:   # 좌우 반전
		src = Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
		for yy in range(sz.y):
			for xx in range(sz.x):
				src.set_pixel(sz.x - 1 - xx, yy, img.get_pixel(xx, yy))
	out.blend_rect(src, Rect2i(Vector2i.ZERO, sz), Vector2i(bx, by))
