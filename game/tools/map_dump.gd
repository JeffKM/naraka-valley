extends SceneTree

# 맵 시각 확인용 글루(ADR-0001 허용): main 씬을 헤드리스로 띄워 Ground/Field
# TileMapLayer의 *최종 배치된* 타일을 atlas에서 잘라 한 장 PNG(tools/map_dump.png)로
# 합성한다. 렌더링(GPU) 없이 타일 배치만 덤프하므로 --headless에서 동작.
# 사용: godot --headless --path game -s res://tools/map_dump.gd
# (밭 흙 상태 도트를 보려면 DEBUG_SOIL=true로 밭에 상태 칸을 강제 칠한다)
const DEBUG_SOIL := false

func _init():
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var ground: TileMapLayer = main.get_node("Ground")
	var field: TileMapLayer = main.get_node("Field")
	if DEBUG_SOIL:
		for i in 8:
			field.set_cell(Vector2i(16 + i, 6), 0, Vector2i(i, 0))
		await process_frame
	var out := Image.create(40 * 32, 24 * 32, false, Image.FORMAT_RGBA8)   # 환경 2배(TILE 32px)
	out.fill(Color(0.05, 0.05, 0.07, 1.0))
	for layer in [ground, field]:
		_blit_layer(layer, out)
	# P2.3② 가구·장식: main의 _draw 오버레이는 GPU 없이 안 잡히므로, 같은 배치
	# 데이터(PROP_LAYOUT)를 읽어 텍스처를 바닥정렬로 직접 합성한다(시각 확인용).
	for entry in main.PROP_LAYOUT:
		var tex: Texture2D = entry[0]
		var pimg := tex.get_image()  # ADR-0013: 가구 32px native → 1:1
		for t in entry[1]:
			out.blend_rect(pimg, Rect2i(Vector2i.ZERO, pimg.get_size()), Vector2i(t.x * 32, t.y * 32))
	# P2.3② 캐릭터 스프라이트: 노드의 AnimatedSprite2D 현재 프레임을 발치정렬로 합성한다.
	# (숨겨진 옥자·바나도 미리보기용으로 그린다 — 위치는 main이 _ready에서 잡아 둠.)
	for nm in ["Player", "Miho", "Okja", "Mel", "Bana"]:
		var node := main.get_node_or_null(nm) as Node2D
		if node == null:
			continue
		var spr: AnimatedSprite2D = null
		for child in node.get_children():
			if child is AnimatedSprite2D:
				spr = child
				break
		if spr == null:
			continue
		var ftex := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
		if ftex == null:
			continue
		var fimg := ftex.get_image()
		# 스프라이트는 노드 position에 중심정렬 + offset → 좌상단 = pos + offset − frame/2.
		var topleft := node.position + spr.offset - Vector2(fimg.get_width(), fimg.get_height()) * 0.5
		out.blend_rect(fimg, Rect2i(Vector2i.ZERO, fimg.get_size()), Vector2i(topleft))
	# 작물 스프라이트 미리보기(밭이 비어 있어 샘플로 합성): 3작물 × 3단계를 밭 칸에 직접 그린다.
	# 실게임에선 _draw_crops가 farm.planted_tiles()를 그린다 — 여기선 native 32px 렌더 확인용.
	var crop_row := 0
	for cid in main.CROP_SPRITES:
		var frames: Array = main.CROP_SPRITES[cid]
		for st in frames.size():
			var cimg: Image = frames[st].get_image()
			var cx := (15 + st) * 32   # 밭 안(x15~17), 단계별 가로
			var cy := (5 + crop_row * 2) * 32
			out.blend_rect(cimg, Rect2i(Vector2i.ZERO, cimg.get_size()), Vector2i(cx, cy))
		crop_row += 1
	out.save_png("res://tools/map_dump.png")
	print("✅ map_dump.png 저장")
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
		var tile_img := src.texture.get_image().get_region(region)  # ADR-0013: 타일 32px native → 1:1
		out.blend_rect(tile_img, Rect2i(Vector2i.ZERO, tile_img.get_size()), Vector2i(cell.x * 32, cell.y * 32))
