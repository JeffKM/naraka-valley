extends SceneTree

# ═══════════════════════════════════════════════════════════════════════════
# 안식 농원 16px 프리뷰 덤프 (ADR-0049 슬라이스 A — 라이브 render 무변경·안전).
#
# home_full_dump를 베이스로 *지면만* 교체: 실제 농원 grid(main._grid)를 새 소프트 잔디/흙
# **필드 타일링**(월드좌표 ×2 샘플 = 16 유효·실험 GO 룩)으로 칠하고, 프롭·건물 facade는
# chunkify(÷2×2)해서 얹는다. 라이브 게임 render 코드는 안 건드림 — owner 전체 농원 16px 판정용.
#
# 입력: assets/_staging_tile16/{grass_a,dirt}_field.png(128, 글루 산출).
# 사용: godot --headless --path game -s res://tools/home16_dump.gd
# 산출: tools/home16_dump.png
# ═══════════════════════════════════════════════════════════════════════════

const TILE := 32
const FIELD := 128
const JIT := 5
const GROUND := 0
const PATH := 1
const SOIL := 2
const WATER := 9

var _grass: Image
var _dirt: Image

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	_grass = _load_field("grass_a_field")
	_dirt = _load_field("dirt_field")
	var gw: int = main._grid_w
	var gh: int = main._outdoor_h
	var out := Image.create(gw * TILE, gh * TILE, false, Image.FORMAT_RGBA8)

	# 기존 아틀라스에서 soil·water 베이스 타일(청키화) — 새로 안 만든 지형은 유지.
	var soil_t := _base_tile(main, main.TR_SOIL)
	var water_t := _base_tile(main, main.TR_WATER)

	# ── 지면: grid → 새 소프트 필드(GROUND/PATH) + 지터 디더 경계 / soil·water는 기존 청키 ──
	for py in gh * TILE:
		for px in gw * TILE:
			var tx := px / TILE
			var ty := py / TILE
			var cell: int = main._grid[ty][tx]
			if cell == SOIL:
				out.set_pixel(px, py, soil_t.get_pixel(px % TILE, py % TILE))
				continue
			if cell == WATER:
				out.set_pixel(px, py, water_t.get_pixel(px % TILE, py % TILE))
				continue
			# GROUND/PATH/그 외(나무·바위·건물 밑 = 잔디) : 지터로 셀 판정 → 필드 ×2 샘플(16 유효)
			var jx := px + int((_h01(px, py, 610) - 0.5) * JIT * 2.0)
			var jy := py + int((_h01(px, py, 620) - 0.5) * JIT * 2.0)
			var jcx := clampi(jx / TILE, 0, gw - 1)
			var jcy := clampi(jy / TILE, 0, gh - 1)
			var use_dirt: bool = (int(main._grid[jcy][jcx]) == PATH) if (cell == GROUND or cell == PATH) else (cell == PATH)
			var src: Image = _dirt if use_dirt else _grass
			out.set_pixel(px, py, src.get_pixel((px / 2) % FIELD, (py / 2) % FIELD))

	# ── 클럼프 스캐터(Q5) — 필드 타일링 주기 반복감을 깨는 tuft. GROUND 셀에 결정적 해시 ──
	var tufts: Array[Image] = [
		_chunkify(_img(load("res://assets/props/ground_grass2.png"))),
		_chunkify(_img(load("res://assets/props/ground_grass3.png"))),
		_chunkify(_img(load("res://assets/props/ground_grass1.png"))),
	]
	for ty in gh:
		for tx in gw:
			if int(main._grid[ty][tx]) != GROUND:
				continue
			if _h01(tx, ty, 301) > 0.16:      # ~16% 밀도
				continue
			var timg: Image = tufts[int(_h01(tx, ty, 302) * tufts.size()) % tufts.size()]
			var tsz := timg.get_size()
			var ox := tx * TILE + int(_h01(tx, ty, 303) * maxi(1, TILE - tsz.x))
			var oy := ty * TILE + int(_h01(tx, ty, 304) * maxi(1, TILE - tsz.y))
			out.blend_rect(timg, Rect2i(Vector2i.ZERO, tsz), Vector2i(ox, oy))

	# ── 프롭(청키화) + 발치 그림자 ──
	for entry in main._prop_layouts.get("HOME", []):
		var tex: Texture2D = entry[0]
		var yo: int = entry[2] if entry.size() > 2 else 0
		var casts: bool = tex in main.PROP_SHADOW_SET
		var timg := _chunkify(_img(tex))
		var tsz := timg.get_size()
		for t in entry[1]:
			if casts:
				_shadow(out, t.x * TILE + tsz.x * 0.5 + 2.0, float(t.y * TILE + yo) + tsz.y - 2.0, tsz.x * 0.40, 0.30)
			out.blend_rect(timg, Rect2i(Vector2i.ZERO, tsz), Vector2i(t.x * TILE, t.y * TILE + yo))

	# ── 건물 facade(청키화) + 잔디 백드롭 + 접지 그림자 ──
	var facades := [
		[main.FACADE_HOUSE, main.HOUSE_EXT_RECT],
		[main.FACADE_STOREHOUSE, main.STOREHOUSE_EXT_RECT],
		[main.FACADE_BARN, main.NEOKURITGAN_EXT_RECT],
		[main.FACADE_COOP, main.NEOKDUNGURI_EXT_RECT],
	]
	for f in facades:
		var rect := f[1] as Rect2i
		# 잔디 백드롭(새 필드) — 회색 WALL 그레이박스가 안 비치게
		for ty2 in range(rect.size.y):
			for tx2 in range(rect.size.x):
				for iy in TILE:
					for ix in TILE:
						var wx := (rect.position.x + tx2) * TILE + ix
						var wy := (rect.position.y + ty2) * TILE + iy
						out.set_pixel(wx, wy, _grass.get_pixel((wx / 2) % FIELD, (wy / 2) % FIELD))
		var fimg := _chunkify(_img(f[0] as Texture2D))
		var fsz := fimg.get_size()
		var cx := int((rect.position.x + rect.size.x * 0.5) * TILE)
		var base_y := (rect.position.y + rect.size.y) * TILE
		var srx := fsz.x * 0.42
		var sry := srx * 0.17
		_shadow(out, cx + 2, base_y - sry * 0.4, srx, 0.34)
		out.blend_rect(fimg, Rect2i(Vector2i.ZERO, fsz), Vector2i(cx - fsz.x / 2, base_y - fsz.y))

	out.save_png("res://tools/home16_dump.png")
	print("✅ home16_dump.png  (%d×%d, 16px 유효 잔디/흙 + 청키 프롭/건물)" % [gw * TILE, gh * TILE])
	quit()

func _load_field(name: String) -> Image:
	var tex = load("res://assets/_staging_tile16/%s.png" % name)
	if tex == null:
		push_error("필드 없음: %s (글루 먼저 실행)" % name)
		return _flat(Color(0.29, 0.42, 0.24) if name.begins_with("grass") else Color(0.52, 0.40, 0.29))
	var img: Image = tex.get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != FIELD:
		img.resize(FIELD, FIELD, Image.INTERPOLATE_LANCZOS)
	return img

func _flat(c: Color) -> Image:
	var im := Image.create(FIELD, FIELD, false, Image.FORMAT_RGBA8)
	im.fill(c)
	return im

# terrain 베이스 타일(4코너 동일) 아틀라스 픽셀 → 32px 청키화
func _base_tile(main, terrain: int) -> Image:
	var src := (main.get_node("Ground") as TileMapLayer).tile_set.get_source(0) as TileSetAtlasSource
	var coord: Vector2i = main._terrain_base_atlas(terrain)
	var atlas := src.texture.get_image()
	if atlas.get_format() != Image.FORMAT_RGBA8:
		atlas.convert(Image.FORMAT_RGBA8)
	var rs: int = src.texture_region_size.x
	var t := Image.create(rs, rs, false, Image.FORMAT_RGBA8)
	t.blit_rect(atlas, Rect2i(coord.x * rs, coord.y * rs, rs, rs), Vector2i.ZERO)
	if rs != TILE:
		t.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)
	return _chunkify(t)

func _img(tex: Texture2D) -> Image:
	var im := tex.get_image()
	if im.get_format() != Image.FORMAT_RGBA8:
		im.convert(Image.FORMAT_RGBA8)
	return im

# ÷2(평균)→×2(nearest) 청키 + alpha 하드에지 (chunkify_asset.py의 GDScript판)
func _chunkify(im: Image) -> Image:
	var w := im.get_width()
	var h := im.get_height()
	var half := Image.create(maxi(1, w / 2), maxi(1, h / 2), false, Image.FORMAT_RGBA8)
	# 평균 다운스케일: 2×2 블록 평균
	for y in half.get_height():
		for x in half.get_width():
			var acc := Color(0, 0, 0, 0)
			var n := 0
			for dy in 2:
				for dx in 2:
					var sx := x * 2 + dx
					var sy := y * 2 + dy
					if sx < w and sy < h:
						acc += im.get_pixel(sx, sy)
						n += 1
			half.set_pixel(x, y, acc / float(n))
	var big := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := half.get_pixel(mini(x / 2, half.get_width() - 1), mini(y / 2, half.get_height() - 1))
			c.a = 1.0 if c.a >= 0.5 else 0.0
			big.set_pixel(x, y, c)
	return big

func _shadow(out: Image, cx: float, cy: float, rx: float, strength: float) -> void:
	var ry := rx * 0.22
	for sy in range(int(cy - ry), int(cy + ry) + 1):
		for sx in range(int(cx - rx), int(cx + rx) + 1):
			if sx < 0 or sy < 0 or sx >= out.get_width() or sy >= out.get_height():
				continue
			var nx := (sx - cx) / rx
			var ny := (sy - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				out.set_pixel(sx, sy, out.get_pixel(sx, sy).lerp(Color(0, 0, 0, 1), strength))

func _h01(x: int, y: int, salt: int) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	n = n & 0x7fffffff
	return float(n % 100000) / 100000.0
