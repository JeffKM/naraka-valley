extends SceneTree

# ★[S7-T9 / ADR-0065 결정 11] 육안 글루(ADR-0001) — 안식 농원 지면을 **4절기 각각**으로 한 장씩
# 오프라인 합성한다. 화면 grab이 아니라 CPU blit이라 --headless에서도 실지면이 그대로 나온다
# (home_full_dump와 같은 방식·같은 이유 — 헤드리스 GPU 캡처는 빈 화면이다).
#
# 절기는 `main._season_field_override`(덤프 전용 레버)로 못 박고 `_refresh_season_terrain(true)`가
# 실제 게임과 **똑같은 경로**로 필드를 갈아 굽는다 — 덤프용 별도 합성 코드가 없으므로 여기 뜬 톤이
# 곧 인게임 톤이다(두 벌 그리기 = 어긋남의 씨앗, weather_dump가 청크 표를 공유하는 것과 같은 규율).
#
# 산출: tools/season_ground_<슬러그>.png 4장 + tools/season_ground_sheet.png(2×2 축소 대조 시트)
# 사용: godot --headless --path game -s res://tools/season_ground_dump.gd

const TILE := 32
const SLUGS := ["pianhwa", "yuhwa", "mangyeon", "seongya"]
# 마당 한복판 — 잔디·맨흙·흙길·밭·연못 물가가 한 프레임에 드는 구간(팔레트 변화가 전부 보이는 창).
const CROP := Rect2i(24, 8, 40, 34)   # 타일 단위 → 1280×1088 px

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var shots: Array[Image] = []
	for s in 4:
		main._season_field_override = s
		main._refresh_season_terrain(true)   # 필드 리로드 + 구역 리빌드(인게임 절기 전환과 동일 경로)
		await process_frame
		var img := _compose(main)
		img.save_png("res://tools/season_ground_%s.png" % SLUGS[s])
		shots.append(img)
		print("  ", SLUGS[s], " → ", img.get_width(), "×", img.get_height())
	_sheet(shots).save_png("res://tools/season_ground_sheet.png")
	print("✅ 4절기 지면 덤프 + 대조 시트 저장")
	quit()

# 타일 레이어(지형·밭) + 베이크된 지면 디테일 한 장을 CROP 창으로 합성한다.
# ★ 프롭·외관은 일부러 뺀다: 이 덤프의 질문은 "땅의 낯빛이 절기를 따라갔나" 하나뿐이고,
#   나무·건물이 덮으면 정작 비교할 지면이 가려진다(home_full_dump가 전체 장면을 맡는다).
func _compose(main) -> Image:
	var out := Image.create(CROP.size.x * TILE, CROP.size.y * TILE, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.05, 0.07, 1.0))
	var off := Vector2i(-CROP.position.x * TILE, -CROP.position.y * TILE)
	for layer in [main.get_node("Ground") as TileMapLayer, main.get_node("Field") as TileMapLayer]:
		_blit_layer(layer, out, off)
	if main._ground_detail_tex != null:
		var gdi: Image = main._ground_detail_tex.get_image()
		if gdi.get_format() != Image.FORMAT_RGBA8:
			gdi.convert(Image.FORMAT_RGBA8)
		var src := Rect2i(CROP.position * TILE, CROP.size * TILE)
		out.blend_rect(gdi, src, Vector2i.ZERO)
	return out

func _blit_layer(layer: TileMapLayer, out: Image, off: Vector2i) -> void:
	var ts := layer.tile_set
	for cell in layer.get_used_cells():
		if not CROP.has_point(cell):
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

# 네 장을 2×2로 붙인 축소 대조 시트(절기 차이는 나란히 놓아야 읽힌다).
func _sheet(shots: Array[Image]) -> Image:
	var cw := shots[0].get_width() / 2
	var ch := shots[0].get_height() / 2
	var sheet := Image.create(cw * 2, ch * 2, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var half := shots[i].duplicate() as Image
		half.resize(cw, ch, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(half, Rect2i(0, 0, cw, ch), Vector2i((i % 2) * cw, (i / 2) * ch))
	return sheet
