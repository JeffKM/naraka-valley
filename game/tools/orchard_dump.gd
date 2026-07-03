extends SceneTree

# 육안 글루(ADR-0001) — 혼의 나무 과수(honbaekdo) 3단계 스프라이트를 실제 _draw_orchard 배치 수식
# (bottom-center 앵커·3타일폭·위로 솟음)으로 풀 타일 위에 CPU 합성한다. 부팅엔 심긴 나무가 없어
# home_full_dump엔 안 나오므로, 여기서 묘목·성목·결실 3단계를 나란히 놓아 아트/스케일을 확인한다.
# 사용: godot --headless --path game -s res://tools/orchard_dump.gd

const TILE := 32

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var cols := 13
	var rows := 8
	var out := Image.create(cols * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
	# 풀 타일 베이스(home_full_dump와 동일 — Ground 아틀라스에서 grass base 타일 추출).
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
	# 3단계 나무 = _draw_orchard 배치 수식 1:1 재현(anchor 하단 중앙, 위로 솟음).
	var frames = main.ORCHARD_SPRITES[FruitTreeCatalog.HONBAEKDO]
	var anchors := [Vector2i(2, 6), Vector2i(6, 6), Vector2i(10, 6)]  # 묘목·성목·결실
	for i in 3:
		var img: Image = (frames[i] as Texture2D).get_image()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var sz := img.get_size()
		var a: Vector2i = anchors[i]
		var x := int(a.x * TILE + TILE * 0.5 - sz.x * 0.5)
		var y := (a.y + 1) * TILE - sz.y
		out.blend_rect(img, Rect2i(Vector2i.ZERO, sz), Vector2i(x, y))
	out.save_png("res://tools/orchard_dump.png")
	print("✅ orchard_dump.png 저장 (묘목·성목·결실)")
	quit()
