extends SceneTree

# ★[지면 채도 A/B 실험] home_full_dump의 전체 맵 CPU 합성을, _retone_earth 계수 프리셋마다
# 다시 돌려 지면 베이스톤을 A/B/C로 렌더한다. 실제 코드 경로(_load_big_fields→_retone_earth→
# _build_ground16→합성)를 그대로 타므로 인게임 화면과 1:1. 지면 채도가 잘 드러나는 대표 영역만 크롭 저장.
# 사용: godot --headless --path game -s res://tools/ground_ab_dump.gd

const TILE := 32
# 밭·집·축사·좌측건물·세로덤불·중앙 잔디패치·연못이 다 들어가는 대표 크롭(빈 흙 면적 포함).
const CROP := Rect2i(560, 40, 1440, 1060)

# [name, hue_lerp, sat_mul, val_mul, val_add]
const PRESETS := [
	["A_baseline", 0.55, 0.80, 1.22, 0.14],   # 현행 — 채도↓·명도↑ (파스텔 살구톤)
	["B_satup",    0.55, 1.20, 1.08, 0.06],   # 채도↑·명도 완화 — 골든머스타드 방향(중간)
	["C_strong",   0.50, 1.45, 1.00, 0.02],   # 채도 강·명도 최소 상향 — 스타듀급 고채도·고대비
]

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var size: Vector2i = RegionCatalog.size_of(RegionCatalog.HOME)
	for p in PRESETS:
		main._earth_hue_lerp = p[1]
		main._earth_sat_mul = p[2]
		main._earth_val_mul = p[3]
		main._earth_val_add = p[4]
		# _load_big_fields는 _bf_grass!=null이면 early-return → 강제 재로드 위해 리셋 후 지면 재빌드.
		main._bf_grass = null
		main._load_big_fields()
		main._build_ground16()
		var full := _compose(main, size)
		var crop := full.get_region(CROP)
		crop.save_png("res://tools/ground_ab_%s.png" % p[0])
		print("✅ ground_ab_%s.png (crop %d×%d) sat×%.2f val×%.2f+%.2f" % [p[0], CROP.size.x, CROP.size.y, p[2], p[3], p[4]])
	quit()

# home_full_dump._init의 합성부를 함수로 추출(지형+오버레이+PROP+facade).
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
