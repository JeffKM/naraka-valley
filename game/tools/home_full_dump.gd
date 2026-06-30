extends SceneTree

# 육안 글루(ADR-0001) — 안식 농원 *전체 맵*(80×65)을 한 장에, 지형+PROP(나무·바위 테두리)+facade까지
# CPU 합성한다. home_wide_dump는 GPU 카메라 캡처라 --headless에서 빈 화면 → village_dump처럼 CPU blit로
# 재현(_draw_props_for의 즉시모드 draw_texture_rect를 layout 데이터로 1:1 재현).
# 사용: godot --headless --path game -s res://tools/home_full_dump.gd

const TILE := 32

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	# HOME이 부팅 기본 구역(별도 rebuild 불필요)
	var size: Vector2i = RegionCatalog.size_of(RegionCatalog.HOME)
	var out := Image.create(size.x * TILE, size.y * TILE, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.05, 0.07, 1.0))
	for layer in [main.get_node("Ground") as TileMapLayer, main.get_node("Field") as TileMapLayer]:
		_blit_layer(layer, out)
	# ★ 지면 디테일 오버레이(베이크된 한 장 — _draw와 동일 레이어: 타일 위·프롭 아래)
	if main._ground_detail_tex != null:
		var gdi: Image = main._ground_detail_tex.get_image()
		if gdi.get_format() != Image.FORMAT_RGBA8:
			gdi.convert(Image.FORMAT_RGBA8)
		out.blend_rect(gdi, Rect2i(Vector2i.ZERO, gdi.get_size()), Vector2i.ZERO)
	# PROP — _draw_props_for(즉시모드)의 CPU 재현(가장자리 나무·바위·장식 포함)
	for entry in main._prop_layouts.get("HOME", []):
		var tex: Texture2D = entry[0]
		var yo: int = entry[2] if entry.size() > 2 else 0
		var timg := tex.get_image()
		if timg.get_format() != Image.FORMAT_RGBA8:
			timg.convert(Image.FORMAT_RGBA8)
		for t in entry[1]:
			out.blend_rect(timg, Rect2i(Vector2i.ZERO, timg.get_size()), Vector2i(t.x * TILE, t.y * TILE + yo))
	# 야외 건물 외관(집·창고·축사) — 통과불가 WALL 박스 위 1:1 blit
	var facades := [
		[main.FACADE_HOUSE, main.HOUSE_EXT_RECT],
		[main.FACADE_STOREHOUSE, main.STOREHOUSE_EXT_RECT],
		[main.FACADE_BARN, main.BARN_EXT_RECT],
	]
	# ★[ADR-0043] facade 블렌드 — facade 그리기 전 footprint를 풀 베이스로 덮어(시각) 회색 WALL 그레이박스가
	#   투명부로 안 비치게. main._facade_grass_backdrop과 동일 결(여기선 CPU blit로 재현).
	var gsrc := (main.get_node("Ground") as TileMapLayer).tile_set.get_source(0) as TileSetAtlasSource
	var grs: int = gsrc.texture_region_size.x
	var gcoord: Vector2i = main._terrain_base_atlas(main.TR_GRASS)
	var gatlas: Image = gsrc.texture.get_image()
	if gatlas.get_format() != Image.FORMAT_RGBA8:
		gatlas.convert(Image.FORMAT_RGBA8)
	var gtile := Image.create(grs, grs, false, Image.FORMAT_RGBA8)
	gtile.blit_rect(gatlas, Rect2i(gcoord.x * grs, gcoord.y * grs, grs, grs), Vector2i.ZERO)
	for f in facades:
		var rect := f[1] as Rect2i
		for ty in range(rect.size.y):
			for tx in range(rect.size.x):
				out.blit_rect(gtile, Rect2i(0, 0, grs, grs), Vector2i((rect.position.x + tx) * TILE, (rect.position.y + ty) * TILE))
		var fimg := (f[0] as Texture2D).get_image()
		if fimg.get_format() != Image.FORMAT_RGBA8:
			fimg.convert(Image.FORMAT_RGBA8)
		out.blend_rect(fimg, Rect2i(Vector2i.ZERO, fimg.get_size()), (f[1] as Rect2i).position * TILE)
	out.save_png("res://tools/home_full_dump.png")
	print("✅ home_full_dump.png 저장 (", size.x, "×", size.y, ")")
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
