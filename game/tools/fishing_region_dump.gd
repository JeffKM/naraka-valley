extends SceneTree

# ★[S3-T9] 육안 글루(ADR-0001) — 삼도천(56×40)·황천해(64×44) *전체 무대*를 각각 한 장에 CPU 합성한다.
# village_dump.gd와 같은 층위(레이어 순서 = main._draw):
#   ① Ground/Field 타일맵(절벽·강둑·경계벽 = 자체 SOLID_TEX가 여기서 보인다)
#   ② _ground_detail_tex(ground16 베이크 — 잔디/흙 Wang·모래 밴드·목판 데크·물가 shore·스캐터)
#   ③ 야외 프롭(SAMDO_OUTDOOR / HWANG_OUTDOOR — 나룻배·말뚝. 발치 SE 접지 그림자 포함)
#   ④ 건물 외관(혼백관·생선가게) — `_blit_facade_anchored`의 **bottom-center** 앵커
#      (art 바텀 = footprint 하단 경계, 가로 중앙 정렬 → 지붕이 위로 솟는다)
#   ★ 풀 백드롭은 그리지 않는다 — 두 구역 다 ground16 이식 구역이라 main._facade_grass_backdrop이
#     early-return한다(건물마다 초록 사각형이 되살아나는 [ADR-0054] 회귀 방지).
# 사용: godot --headless --path game -s res://tools/fishing_region_dump.gd
#   ⚠ 반드시 game/ 기준 --path로. 워크트리 루트에서 실행하면 무한 행(메모리 교훈).

const TILE := 32

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	for spec in [
		{"region": RegionCatalog.SAMDOCHEON, "out": "samdo_dump.png", "props": "SAMDO_OUTDOOR"},
		{"region": RegionCatalog.HWANGCHEONHAE, "out": "hwang_dump.png", "props": "HWANG_OUTDOOR"},
	]:
		await _dump(main, spec)
	quit()

func _dump(main: Node, spec: Dictionary) -> void:
	var region: String = spec["region"]
	var t0 := Time.get_ticks_msec()
	main._rebuild_region(region)
	var build_ms := Time.get_ticks_msec() - t0
	await process_frame
	var size: Vector2i = RegionCatalog.size_of(region)
	var out := Image.create(size.x * TILE, size.y * TILE, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.05, 0.07, 1.0))
	# ① 타일맵
	for layer in [main.get_node("Ground") as TileMapLayer, main.get_node("Field") as TileMapLayer]:
		_blit_layer(layer, out)
	# ② 지면 오버레이(ground16 베이크 한 장)
	if main._ground_detail_tex != null:
		var gdi: Image = main._ground_detail_tex.get_image()
		if gdi.get_format() != Image.FORMAT_RGBA8:
			gdi.convert(Image.FORMAT_RGBA8)
		out.blend_rect(gdi, Rect2i(Vector2i.ZERO, gdi.get_size()), Vector2i.ZERO)
	# ③ 야외 프롭
	for entry in main._prop_layouts.get(String(spec["props"]), []):
		var ptex: Texture2D = entry[0]
		if ptex == null:
			continue
		var yo: int = entry[2] if entry.size() > 2 else 0
		var timg := ptex.get_image()
		if timg.get_format() != Image.FORMAT_RGBA8:
			timg.convert(Image.FORMAT_RGBA8)
		var tsz := timg.get_size()
		for t in entry[1]:
			if t.y >= size.y:
				continue   # 실내 띠 = 야외 캔버스 밖
			out.blend_rect(timg, Rect2i(Vector2i.ZERO, tsz), Vector2i(t.x * TILE, t.y * TILE + yo))
	# ④ 건물 외관(bottom-center 앵커)
	var facades := []
	if region == RegionCatalog.SAMDOCHEON:
		facades.append([main.FACADE_MUSEUM, main.MUSEUM_EXT_RECT])
	else:
		facades.append([main.FACADE_FISHSHOP, main.FISHSHOP_EXT_RECT])
	for f in facades:
		var tex: Texture2D = f[0]
		var rect: Rect2i = f[1]
		var fimg := tex.get_image()
		if fimg.get_format() != Image.FORMAT_RGBA8:
			fimg.convert(Image.FORMAT_RGBA8)
		var sz := fimg.get_size()
		var at := Vector2i(
			int((rect.position.x + rect.size.x * 0.5) * TILE) - sz.x / 2,
			(rect.position.y + rect.size.y) * TILE - sz.y)
		out.blend_rect(fimg, Rect2i(Vector2i.ZERO, sz), at)
	out.save_png("res://tools/" + String(spec["out"]))
	print("✅ ", spec["out"], " 저장 (", size.x, "×", size.y, ") — 구역 리빌드 ", build_ms, "ms")

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
