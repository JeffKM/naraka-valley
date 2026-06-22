extends SceneTree

# M2.5 외관 재도색 육안 확인용 글루(ADR-0001 허용 — map_dump 결, GPU 없이 CPU 합성).
# main을 헤드리스로 띄워 나루 마을(NARU_VILLAGE)로 재빌드한 뒤, Ground/Field 타일과
# 야외 건물 외관(카페 + 미호·멜·바나 집)을 박스 좌상단에 1:1로 합성해 한 장 PNG로 떨군다.
# _draw_facade_*는 텍스처를 rect.position*TILE에 1:1로 그리므로 CPU blit이 렌더와 동일.
# 사용: godot --headless --path game -s res://tools/village_dump.gd

const TILE := 32

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	main._rebuild_region(RegionCatalog.NARU_VILLAGE)   # 마을로 전환(그리드·외관 자리)
	await process_frame
	var size: Vector2i = RegionCatalog.size_of(RegionCatalog.NARU_VILLAGE)
	var out := Image.create(size.x * TILE, size.y * TILE, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.05, 0.07, 1.0))
	for layer in [main.get_node("Ground") as TileMapLayer, main.get_node("Field") as TileMapLayer]:
		_blit_layer(layer, out)
	# 야외 건물 외관(통과 불가 WALL 박스 위에 덮어 그리는 것과 동일 — _draw의 1:1 blit 재현).
	var facades := [
		[main.FACADE_CAFE, main.CAFE_EXT_RECT],
		[main.FACADE_MEL_HOUSE, main.MEL_HOUSE_RECT],
		[main.FACADE_MIHO_HOUSE, main.MIHO_HOUSE_RECT],
		[main.FACADE_BANA_HOUSE, main.BANA_HOUSE_RECT],
	]
	for f in facades:
		var tex: Texture2D = f[0]
		var rect: Rect2i = f[1]
		var fimg := tex.get_image()
		if fimg.get_format() != Image.FORMAT_RGBA8:
			fimg.convert(Image.FORMAT_RGBA8)
		out.blend_rect(fimg, Rect2i(Vector2i.ZERO, fimg.get_size()), rect.position * TILE)
	out.save_png("res://tools/village_dump.png")
	print("✅ village_dump.png 저장")
	quit()

func _blit_layer(layer: TileMapLayer, out: Image) -> void:
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
		var tile_img := src.texture.get_image().get_region(region)
		out.blend_rect(tile_img, Rect2i(Vector2i.ZERO, tile_img.get_size()), Vector2i(cell.x * TILE, cell.y * TILE))
