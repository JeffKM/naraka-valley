extends SceneTree
# ★[S2-T10] 육안 글루(ADR-0001) — 신규 NPC 도색 스프라이트(네오·모찌)를 **인게임 자리에** 세워
# 한 장 떨군다. village_dump.gd와 같은 CPU 합성 방식이다(헤드리스 렌더러는 더미라 실제 화면
# 캡처가 안 나온다 — 타일·스프라이트 이미지를 직접 blend_rect로 겹친다).
#
# 두 장면을 좌우로 잇는다:
#   ① 만물상 실내(STORE_RECT) — 매대 자리 NEO_TILE에 선 네오(상주 NPC라 남향 정지)
#   ② 마을 야외 모찌 아침 자리(집 문 앞) — 4방향을 나란히(방향 변형이 읽히는지)
# 스프라이트 배치는 char_sprite.gd 규약 그대로: 프레임 80×80, 발치가 노드 원점(offset -36)
# → 타일 좌상단 기준 blit 위치 = (tile*TILE + TILE/2 - 40, tile*TILE + TILE - 76).
#
# 사용: godot --headless --path game -s res://tools/naru_npc_dump.gd

const TILE := 32
const FRAME := 80
const ROW := {"down": 0, "up": 1, "right": 2, "left": 3}

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	main._rebuild_region(RegionCatalog.NARU_VILLAGE)
	await process_frame
	# 배선 확인 — 도색 시트가 실제로 로드됐나(null이면 그레이박스 폴백이 그려지는 중이다)
	print("neo._sprite   = ", "OK(도색)" if main.neo._sprite != null else "null(그레이박스 폴백)")
	var mochi_node = main._resident_named("모찌").node
	print("mochi._sprite = ", "OK(도색)" if mochi_node._sprite != null else "null(그레이박스 폴백)")

	var neo_sheet: Image = _img("res://assets/characters/neo.png")
	var mochi_sheet: Image = _img("res://assets/characters/mochi.png")

	# ① 만물상 실내 — 방 전체를 타일부터 그려 매대 자리의 네오를 방 안에서 본다
	var room: Rect2i = main.STORE_RECT
	var scene1 := Image.create(room.size.x * TILE, room.size.y * TILE, false, Image.FORMAT_RGBA8)
	scene1.fill(Color(0.05, 0.05, 0.07, 1.0))
	for layer in [main.get_node("Ground") as TileMapLayer, main.get_node("Field") as TileMapLayer]:
		_blit_layer(layer, scene1, room)
	var nt: Vector2i = main.NEO_TILE - room.position
	scene1.blend_rect(neo_sheet, Rect2i(0, ROW["down"] * FRAME, FRAME, FRAME),
		Vector2i(nt.x * TILE + TILE / 2 - FRAME / 2, nt.y * TILE + TILE - 76))

	# ② 모찌 4방향 — 야외 지면 위에 나란히(집 문 앞 칸의 지면을 배경으로 깐다)
	var scene2 := Image.create(4 * 2 * TILE, room.size.y * TILE, false, Image.FORMAT_RGBA8)
	scene2.fill(Color(0.05, 0.05, 0.07, 1.0))
	var mt: Vector2i = main.RESIDENT_HOUSE_DOORS[3] + Vector2i(0, 1)
	if main._ground_detail_tex != null:
		var gd: Image = main._ground_detail_tex.get_image()
		if gd.get_format() != Image.FORMAT_RGBA8:
			gd.convert(Image.FORMAT_RGBA8)
		for i in 4:                              # 같은 지면 조각을 4번 깔아 배경 통일
			scene2.blend_rect(gd, Rect2i((mt.x - 1) * TILE, (mt.y - 3) * TILE, 2 * TILE, room.size.y * TILE),
				Vector2i(i * 2 * TILE, 0))
	var dirs := ["down", "up", "right", "left"]
	for i in dirs.size():
		scene2.blend_rect(mochi_sheet, Rect2i(0, ROW[dirs[i]] * FRAME, FRAME, FRAME),
			Vector2i(i * 2 * TILE + TILE - FRAME / 2, 3 * TILE + TILE - 76))

	var out := Image.create(scene1.get_width() + scene2.get_width() + 16,
		maxi(scene1.get_height(), scene2.get_height()), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.08, 0.08, 0.10, 1.0))
	out.blend_rect(scene1, Rect2i(Vector2i.ZERO, scene1.get_size()), Vector2i.ZERO)
	out.blend_rect(scene2, Rect2i(Vector2i.ZERO, scene2.get_size()), Vector2i(scene1.get_width() + 16, 0))
	out.save_png("res://tools/naru_npc_dump.png")
	print("✅ naru_npc_dump.png 저장")
	quit()

func _img(path: String) -> Image:
	var t: Texture2D = load(path)
	var i := t.get_image()
	if i.get_format() != Image.FORMAT_RGBA8:
		i.convert(Image.FORMAT_RGBA8)
	return i

func _blit_layer(layer: TileMapLayer, out: Image, room: Rect2i) -> void:
	var ts := layer.tile_set
	for cell in layer.get_used_cells():
		if not room.has_point(cell):
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
			Vector2i((cell.x - room.position.x) * TILE, (cell.y - room.position.y) * TILE))
