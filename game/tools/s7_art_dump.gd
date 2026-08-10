extends SceneTree

# ★[S7-T9 / ADR-0065 결정 12] 육안 글루(ADR-0001) — 이번 패스의 신규 프롭 3종을 **제 자리에** 앉혀
# 한 장씩 떨군다. 화면 grab이 아니라 CPU blit이다(헤드리스 GPU 캡처 = 빈 화면 · 골든 불가).
#
# ★ 앵커 수식은 main의 `_draw_*`에서 **그대로 옮겨 적는다** — 여기서 자리가 맞으면 인게임에서도
#   맞는다는 뜻이 되도록. (수식이 갈리면 이 덤프는 아무것도 증명하지 못한다.)
#     세 프롭 모두: blit 좌표 = (tile.x*TILE, tile.y*TILE + TILE - art_h)  ← 타일 하단 발치정렬
#     ★거울은 `WALL_PROP_LIFT`를 **안 먹는다**(그레이박스 도형 전용 보정값 — main 주석 참조).
#
# 산출: tools/s7_{mirror,derby_booth,night_market}.png
# 사용: godot --headless --path game -s res://tools/s7_art_dump.gd

const TILE := 32

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	# ㉠ 점괘 거울 — 집 실내 북벽(HOME 그리드의 실내 밴드). 아트 높이 64 = 벽 띠 두 줄과 같아 flush.
	await _shot(main, RegionCatalog.HOME, main.MIRROR_TILE, "fortune_mirror", "s7_mirror")
	# ㉡ 더비 부스 — 삼도천 강변 산책로. ㉢ 야시장 매대 — 나루 마을 광장.
	await _shot(main, RegionCatalog.SAMDOCHEON, main.DERBY_BOOTH_TILE, "derby_booth", "s7_derby_booth")
	await _shot(main, RegionCatalog.NARU_VILLAGE, main.NIGHT_MARKET_TILE, "night_market", "s7_night_market")
	print("✅ s7_art_dump 3장 저장")
	quit()

func _shot(main, region: String, tile: Vector2i, prop: String, out_name: String) -> void:
	if main._region != region:
		main._rebuild_region(region)
		await process_frame
	# 프롭을 가운데 두고 7×7칸 창을 판다(주변 지형과의 접지·톤 정합까지 한 프레임에 든다).
	var crop := Rect2i(tile.x - 3, tile.y - 4, 7, 7)
	var out := Image.create(crop.size.x * TILE, crop.size.y * TILE, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.05, 0.07, 1.0))
	var off := Vector2i(-crop.position.x * TILE, -crop.position.y * TILE)
	for layer in [main.get_node("Ground") as TileMapLayer, main.get_node("Field") as TileMapLayer]:
		_blit_layer(layer, out, crop, off)
	if main._ground_detail_tex != null:
		var gdi: Image = main._ground_detail_tex.get_image()
		if gdi.get_format() != Image.FORMAT_RGBA8:
			gdi.convert(Image.FORMAT_RGBA8)
		var src := Rect2i(crop.position * TILE, crop.size * TILE)
		if src.position.y + src.size.y <= gdi.get_height() and src.position.x + src.size.x <= gdi.get_width():
			out.blend_rect(gdi, src, Vector2i.ZERO)
	var tex: Texture2D = main._prop_tex(prop)
	if tex == null:
		print("  ! 프롭 텍스처 없음: ", prop)
		return
	var timg := tex.get_image()
	if timg.get_format() != Image.FORMAT_RGBA8:
		timg.convert(Image.FORMAT_RGBA8)
	out.blend_rect(timg, Rect2i(Vector2i.ZERO, timg.get_size()),
		Vector2i(tile.x * TILE, tile.y * TILE + TILE - timg.get_size().y) + off)
	out.save_png("res://tools/%s.png" % out_name)
	print("  ", out_name, " (", region, " ", tile, ")")

func _blit_layer(layer: TileMapLayer, out: Image, crop: Rect2i, off: Vector2i) -> void:
	var ts := layer.tile_set
	for cell in layer.get_used_cells():
		if not crop.has_point(cell):
			continue
		var sid := layer.get_cell_source_id(cell)
		if sid < 0:
			continue
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		var region := src.get_tile_texture_region(layer.get_cell_atlas_coords(cell), 0)
		var tile_img := src.texture.get_image().get_region(region)
		out.blend_rect(tile_img, Rect2i(Vector2i.ZERO, tile_img.get_size()),
			Vector2i(cell.x * TILE, cell.y * TILE) + off)
