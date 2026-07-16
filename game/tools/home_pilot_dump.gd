extends SceneTree

# ★[스타듀 타일 파일럿] home_full_dump 복제 + PixelLab 지형 텍스처 검증용.
#   terrain16/grass_field·dirt_field가 PixelLab 순수 타일로 스왑된 상태에서 전체 맵을 렌더한다.
#   _retone_earth는 identity(hue0·sat1·val×1+0)로 두어 PixelLab 흙 톤을 그대로 보존(사후보정 배제).
# 사용: godot --headless --path game -s res://tools/home_pilot_dump.gd

const TILE := 32

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	# ★ PixelLab 흙 톤 보존 — retone 계수 identity로 재빌드
	main._earth_hue_lerp = 0.0
	main._earth_sat_mul = 1.0
	main._earth_val_mul = 1.0
	main._earth_val_add = 0.0
	main._bf_grass_mute = false   # ★ 파일럿은 재생성 crisp 잔디의 순수 톤(muted 전)을 검증
	main._bf_grass = null
	main._load_big_fields()
	main._build_ground16()
	var size: Vector2i = RegionCatalog.size_of(RegionCatalog.HOME)
	var out := _compose(main, size)
	out.save_png("res://tools/home_pilot_dump.png")
	print("✅ home_pilot_dump.png 저장 (", size.x, "×", size.y, ")")
	quit()

func _compose(main, size: Vector2i) -> Image:
	var out := Image.create(size.x * TILE, size.y * TILE, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.05, 0.07, 1.0))
	for layer in [main.get_node("Ground") as TileMapLayer, main.get_node("Field") as TileMapLayer]:
		_blit_layer(layer, out)
	if main._ground_detail_tex != null:
		var gdi: Image = main._ground_detail_tex.get_image()
		if gdi.get_format() != Image.FORMAT_RGBA8:
			gdi.convert(Image.FORMAT_RGBA8)
		out.blend_rect(gdi, Rect2i(Vector2i.ZERO, gdi.get_size()), Vector2i.ZERO)
	for entry in main._prop_layouts.get("HOME", []):
		var tex: Texture2D = entry[0]
		var yo: int = entry[2] if entry.size() > 2 else 0
		var casts_shadow: bool = tex in main.PROP_SHADOW_SET
		var variants: Array = main.DEBRIS_VARIANTS.get(tex, [])
		if variants.is_empty():
			variants = main.BUSH_VARIANTS.get(tex, [])
		var timg := tex.get_image()
		if timg.get_format() != Image.FORMAT_RGBA8:
			timg.convert(Image.FORMAT_RGBA8)
		var tsz := timg.get_size()
		for t in entry[1]:
			if casts_shadow:
				_blit_shadow(out, t.x * TILE + tsz.x * 0.5 + 2.0, float(t.y * TILE + yo) + tsz.y - 2.0, tsz.x * 0.40)
			var dimg := timg
			if not variants.is_empty():
				var idx: int = (t.x + t.y / 2) if main.BUSH_VARIANTS.has(tex) else (t.x * 7 + t.y * 13)
				var vtex: Texture2D = variants[idx % variants.size()]
				dimg = vtex.get_image()
				if dimg.get_format() != Image.FORMAT_RGBA8:
					dimg.convert(Image.FORMAT_RGBA8)
			out.blend_rect(dimg, Rect2i(Vector2i.ZERO, tsz), Vector2i(t.x * TILE, t.y * TILE + yo))
	var facades := [
		[main.FACADE_HOUSE, main.HOUSE_EXT_RECT],
		[main.FACADE_STOREHOUSE, main.STOREHOUSE_EXT_RECT],
		[main.FACADE_BARN, main.NEOKURITGAN_EXT_RECT],
		[main.FACADE_COOP, main.NEOKDUNGURI_EXT_RECT],
	]
	for f in facades:
		var rect := f[1] as Rect2i
		var fimg := (f[0] as Texture2D).get_image()
		if fimg.get_format() != Image.FORMAT_RGBA8:
			fimg.convert(Image.FORMAT_RGBA8)
		var fsz := fimg.get_size()
		var cx := int((rect.position.x + rect.size.x * 0.5) * TILE)
		var base_y := (rect.position.y + rect.size.y) * TILE
		var srx := fsz.x * 0.42
		var sry := srx * 0.17
		var scx := cx + 2
		var scy := int(base_y - sry * 0.4)
		for sy in range(int(scy - sry), int(scy + sry) + 1):
			for sx in range(int(scx - srx), int(scx + srx) + 1):
				var nx := (sx - scx) / srx
				var ny := (sy - scy) / sry
				if nx * nx + ny * ny <= 1.0 and sx >= 0 and sy >= 0 and sx < out.get_width() and sy < out.get_height():
					var bg := out.get_pixel(sx, sy)
					out.set_pixel(sx, sy, bg.lerp(Color(0, 0, 0, 1), 0.34))
		out.blend_rect(fimg, Rect2i(Vector2i.ZERO, fsz), Vector2i(cx - fsz.x / 2, base_y - fsz.y))
	return out

func _blit_shadow(out: Image, cx: float, cy: float, rx: float) -> void:
	var ry := rx * 0.22
	for sy in range(int(cy - ry), int(cy + ry) + 1):
		for sx in range(int(cx - rx), int(cx + rx) + 1):
			if sx < 0 or sy < 0 or sx >= out.get_width() or sy >= out.get_height():
				continue
			var nx := (sx - cx) / rx
			var ny := (sy - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				var bg := out.get_pixel(sx, sy)
				out.set_pixel(sx, sy, bg.lerp(Color(0, 0, 0, 1), 0.30))

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
