extends SceneTree
# ★[S9b-T9 / ADR-0068 아트 스코프] 조연 코러스 9인 도색 시트 육안 글루(ADR-0001) —
# naru_npc_dump.gd(S2-T10 네오·모찌)의 9인판이다. 같은 CPU 합성 방식을 쓴다(헤드리스 렌더러는
# 더미라 실제 화면 캡처가 안 나온다 — 타일·스프라이트 이미지를 직접 blend_rect로 겹친다).
#
# 두 장면을 위아래로 잇는다:
#   ① 마을 광장 — 8인을 **각자의 낮 스케줄 칸**에 세운다(세레나는 강변이라 아래 ②에만 든다).
#      한 화면에 나란히 서야 "새것만 톤이 튄다"가 보인다(muted 계수 정합이 이 패스의 핵심 판정).
#   ② 9인 × 4방향 — 특히 **north(뒷모습)**에 얼굴이 안 그려졌는지가 판정면이다
#      ([§15.6] 옹이가 남긴 PixelLab standard의 알려진 결함. 조연 9인은 자리를 옮겨 다니는
#      스케줄이라 정지 NPC와 달리 뒷모습이 실제로 화면에 든다).
#
# 배선 확인(색박스 잔존 0의 **기계 판정**)도 같이 찍는다: 각 노드의 `_sprite`가 null이면
# 그레이박스 `_draw()` 폴백이 그려지는 중이라는 뜻이다.
#
# 사용: godot --headless --path game -s res://tools/s9b_chorus_dump.gd

const TILE := 32
const FRAME := 80
const ROW := {"down": 0, "up": 1, "right": 2, "left": 3}

# id → 낮 스케줄 칸(main `_setup_residents()`의 `*_plaza_tile` 값과 같은 칸).
const PLAZA := {
	"seolhwa": Vector2i(47, 32), "gangrim": Vector2i(55, 31), "scarlet": Vector2i(58, 32),
	"kkaebi": Vector2i(56, 34), "mir": Vector2i(54, 38), "ken": Vector2i(48, 39),
	"frosty": Vector2i(50, 40), "luca": Vector2i(58, 40),
}
const ROSTER := ["kkaebi", "ken", "seolhwa", "scarlet", "mir", "luca", "frosty", "gangrim", "serena"]
const PLAZA_RECT := Rect2i(44, 28, 20, 15)


func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	main._rebuild_region(RegionCatalog.NARU_VILLAGE)
	await process_frame

	var missing := 0
	for rid in ROSTER:
		var r = main._resident(rid)
		var ok: bool = r != null and r.node != null and r.node._sprite != null
		if not ok:
			missing += 1
		print("  %-8s _sprite = %s" % [rid, "OK(도색)" if ok else "null(그레이박스 색박스 폴백)"])
	print("색박스 잔존: %d / 9" % missing)

	var sheets := {}
	for rid in ROSTER:
		sheets[rid] = _img("res://assets/characters/%s.png" % rid)

	# ① 마을 광장 — 실제 지면 위, 실제 낮 자리
	var scene1 := Image.create(PLAZA_RECT.size.x * TILE, PLAZA_RECT.size.y * TILE,
		false, Image.FORMAT_RGBA8)
	scene1.fill(Color(0.05, 0.05, 0.07, 1.0))
	for layer in [main.get_node("Ground") as TileMapLayer, main.get_node("Field") as TileMapLayer]:
		_blit_layer(layer, scene1, PLAZA_RECT)
	# 발치가 아래인 순서로 그려야 앞사람이 뒷사람을 덮는다(인게임 Y-정렬과 같은 순서).
	var order: Array = PLAZA.keys()
	order.sort_custom(func(a, b): return PLAZA[a].y < PLAZA[b].y)
	for rid in order:
		var t: Vector2i = PLAZA[rid] - PLAZA_RECT.position
		scene1.blend_rect(sheets[rid], Rect2i(0, ROW["down"] * FRAME, FRAME, FRAME),
			Vector2i(t.x * TILE + TILE / 2 - FRAME / 2, t.y * TILE + TILE - 76))

	# ② 9인 × 4방향
	var dirs := ["down", "up", "right", "left"]
	var scene2 := Image.create(ROSTER.size() * FRAME, dirs.size() * FRAME, false, Image.FORMAT_RGBA8)
	scene2.fill(Color(0.10, 0.10, 0.13, 1.0))
	for i in ROSTER.size():
		for j in dirs.size():
			scene2.blend_rect(sheets[ROSTER[i]], Rect2i(0, ROW[dirs[j]] * FRAME, FRAME, FRAME),
				Vector2i(i * FRAME, j * FRAME))

	var w: int = maxi(scene1.get_width(), scene2.get_width())
	var out := Image.create(w, scene1.get_height() + scene2.get_height() + 16,
		false, Image.FORMAT_RGBA8)
	out.fill(Color(0.08, 0.08, 0.10, 1.0))
	out.blend_rect(scene1, Rect2i(Vector2i.ZERO, scene1.get_size()), Vector2i.ZERO)
	out.blend_rect(scene2, Rect2i(Vector2i.ZERO, scene2.get_size()),
		Vector2i(0, scene1.get_height() + 16))
	out.save_png("res://tools/s9b_chorus_dump.png")
	print("✅ s9b_chorus_dump.png 저장")
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
		if src == null or src.texture == null:
			continue
		var region := src.get_tile_texture_region(layer.get_cell_atlas_coords(cell), 0)
		var tile_img := src.texture.get_image().get_region(region)
		out.blend_rect(tile_img, Rect2i(Vector2i.ZERO, tile_img.get_size()),
			(cell - room.position) * TILE)
