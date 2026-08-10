extends SceneTree
# ★[S7-T8 / ADR-0065 결정 10] 날씨 시각 연출 육안 덤프 — **오프라인 합성**(화면 grab 아님).
#
# 목적: 같은 씬·같은 시각을 평온/혼우/잿눈 세 장으로 떨궈 "하늘이 바뀐 것이 보이는가"를 눈으로
#       고른다(틴트가 너무 센가·빗줄기가 화면을 가리는가·눈이 성긴가).
#
# ★ **화면 grab을 쓰지 않는다**(이 프로젝트의 박제된 교훈): `root.get_texture().get_image()`는
#   헤드리스에서 더미 렌더러라 빈 화면이 나오고, 비-헤드리스에서도 창 크기·DPI·컴포지터에 따라
#   결과가 흔들려 골든으로 못 쓴다. 그래서 home_full_dump 선례대로 월드를 CPU로 합성하고, 그 위에
#   런타임과 **같은 함수**(DayNightLighting.tint_for · WeatherFx.particles)로 하늘을 얹는다 —
#   덤프와 라이브가 한 출처라 "덤프에선 예쁜데 게임에선 다르다"가 구조적으로 불가능하다.
#
# 사용: godot --headless --path game -s res://tools/weather_dump.gd
# 출력: /tmp/weather_dump_calm.png · _rain.png · _snow.png (960×540 = 실제 뷰포트 한 화면)

const TILE := 32
const VIEW := Vector2i(960, 540)      # project.godot 뷰포트(월드가 그려지는 실제 픽셀 크기)
const UI_SCALE := 1.5                 # CanvasLayer scale — 파티클은 640×360 논리 공간에 산다
const LOGICAL := Vector2(640, 360)
const AT_MIN := 780.0                 # 13:00 — 한낮(시각 색조가 중립이라 날씨 차이만 남는다)
const AT_T := 3.0                     # 파티클 애니메이션 시각(초) — 정지 한 컷

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	# ── 배경: 안식 농원 월드를 CPU 합성(home_full_dump와 같은 결) ──────────────
	var size: Vector2i = RegionCatalog.size_of(RegionCatalog.HOME)
	var world := Image.create(size.x * TILE, size.y * TILE, false, Image.FORMAT_RGBA8)
	world.fill(Color(0.05, 0.05, 0.07, 1.0))
	for layer in [main.get_node("Ground") as TileMapLayer, main.get_node("Field") as TileMapLayer]:
		_blit_layer(layer, world)
	if main._ground_detail_tex != null:
		var gdi: Image = main._ground_detail_tex.get_image()
		if gdi.get_format() != Image.FORMAT_RGBA8:
			gdi.convert(Image.FORMAT_RGBA8)
		world.blend_rect(gdi, Rect2i(Vector2i.ZERO, gdi.get_size()), Vector2i.ZERO)
	_blit_props(main, world)
	# 플레이어 자리를 한 화면 잘라 낸다(카메라가 보는 그 창 — 밭·집이 함께 들어온다).
	var p: Vector2 = main.player.global_position
	var ox := clampi(int(p.x) - VIEW.x / 2, 0, world.get_width() - VIEW.x)
	var oy := clampi(int(p.y) - VIEW.y / 2, 0, world.get_height() - VIEW.y)
	var base := world.get_region(Rect2i(Vector2i(ox, oy), VIEW))

	# ── 하늘 3종: 시각 틴트 × 날씨 틴트 + 파티클 ──────────────────────────────
	var lit := DayNightLighting.new()
	get_root().add_child(lit)
	# 결정 10이 요구한 3장(평온·혼우·잿눈) + 혼불 바람 한 장. 혼불은 낙하물이 없어 *틴트만*으로
	# 승부하는 유일한 하늘이라, 그 미세한 보라 기운이 실제로 보이는지는 눈으로만 고를 수 있다.
	for row in [["calm", Weather.CALM], ["rain", Weather.RAIN], ["snow", Weather.SNOW],
			["soulwind", Weather.SOULWIND]]:
		var w: int = row[1]
		var img := base.duplicate() as Image
		_tint(img, lit.tint_for(AT_MIN, w))
		_particles(img, w)
		_glyph(img, w)
		var path := "/tmp/weather_dump_%s.png" % row[0]
		img.save_png(path)
		print("✅ %s — %s (%d×%d)" % [path, Weather.name_of(w), VIEW.x, VIEW.y])
	quit()

# ── 틴트: 화면 전체에 곱셈(CanvasModulate가 GPU에서 하는 그 연산의 CPU판) ──────
func _tint(img: Image, col: Color) -> void:
	var data := img.get_data()
	var mul := [col.r, col.g, col.b]
	for i in range(0, data.size(), 4):
		for c in 3:
			data[i + c] = clampi(int(round(float(data[i + c]) * float(mul[c]))), 0, 255)
	var out := Image.create_from_data(img.get_width(), img.get_height(), false,
		Image.FORMAT_RGBA8, data)
	img.blit_rect(out, Rect2i(Vector2i.ZERO, out.get_size()), Vector2i.ZERO)

# ── 파티클: 런타임과 같은 기하 함수를 불러 CPU로 찍는다 ───────────────────────
# 논리 640×360에서 나온 좌표를 UI_SCALE로 올려 실제 뷰포트 픽셀에 맞춘다(게임에서 CanvasLayer
# scale이 하는 그 일 — 이 한 줄이 덤프와 라이브의 배율을 잇는다).
func _particles(img: Image, w: int) -> void:
	for p in WeatherFx.particles(w, AT_T, LOGICAL):
		if p["kind"] == "streak":
			_line(img, Vector2(p["a"]) * UI_SCALE, Vector2(p["b"]) * UI_SCALE, p["col"],
				maxi(1, int(round(float(p["width"]) * UI_SCALE))))
		else:
			var s := maxi(1, int(round(float(p["size"]) * UI_SCALE)))
			var q: Vector2 = Vector2(p["pos"]) * UI_SCALE
			for dy in s:
				for dx in s:
					_px(img, int(q.x) + dx, int(q.y) + dy, p["col"])

# ── HUD 날씨 심볼(우상단) — clock_hud와 **같은 청크 표**를 읽어 크게 찍는다 ────────
# 세 장이 무슨 하늘인지 한눈에 갈리게 하는 라벨 겸, 심볼 도형 자체의 육안 검수(해·빗방울·눈송이·
# 도깨비불이 16px에서 서로 안 헷갈리는가)를 여기서 같이 한다. 게임 HUD는 16px, 여기선 ×4로 확대.
const GLYPH_PX := 64.0
const GLYPH_MARGIN := 16.0

func _glyph(img: Image, w: int) -> void:
	var u := GLYPH_PX / 8.0
	var ox := float(img.get_width()) - GLYPH_PX - GLYPH_MARGIN
	var oy := GLYPH_MARGIN
	# 어두운 판을 깔아 밝은 지면 위에서도 심볼이 읽히게(HUD의 한지 플레이트 자리).
	for py in range(int(oy) - 6, int(oy + GLYPH_PX) + 6):
		for px in range(int(ox) - 6, int(ox + GLYPH_PX) + 6):
			_px(img, px, py, Color(0.10, 0.08, 0.06, 0.80))
	for c in ClockHud.weather_chunks(w):
		var r := Rect2(ox + float(c[0]) * u, oy + float(c[1]) * u, float(c[2]) * u, float(c[3]) * u)
		for py in range(int(r.position.y), int(r.end.y)):
			for px in range(int(r.position.x), int(r.end.x)):
				_px(img, px, py, c[4])

func _line(img: Image, a: Vector2, b: Vector2, col: Color, width: int) -> void:
	var d := b - a
	var steps := int(maxf(absf(d.x), absf(d.y)))
	if steps <= 0:
		return
	for i in steps + 1:
		var q := a + d * (float(i) / float(steps))
		for k in width:
			_px(img, int(q.x) + k, int(q.y), col)

func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(col.r, col.g, col.b, 1.0), col.a))

# ── home_full_dump 이식(월드 CPU 합성) ───────────────────────────────────────
func _blit_layer(layer: TileMapLayer, out: Image) -> void:
	var ts := layer.tile_set
	for cell in layer.get_used_cells():
		var sid := layer.get_cell_source_id(cell)
		if sid < 0:
			continue
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		var region := src.get_tile_texture_region(layer.get_cell_atlas_coords(cell), 0)
		var tile_img := src.texture.get_image().get_region(region)
		out.blend_rect(tile_img, Rect2i(Vector2i.ZERO, tile_img.get_size()),
			Vector2i(cell.x * TILE, cell.y * TILE))

# 프롭(나무·바위·debris·덤불) — _draw_props_for의 CPU 재현. 변주·톤 완화까지 같은 함수를 탄다.
func _blit_props(main: Node, out: Image) -> void:
	for entry in main._home_prop_entries():
		var tex: Texture2D = entry[0]
		var yo: int = entry[2] if entry.size() > 2 else 0
		var variants: Array = main.DEBRIS_VARIANTS.get(tex, [])
		if variants.is_empty():
			variants = main.BUSH_VARIANTS.get(tex, [])
		var timg := tex.get_image()
		if timg.get_format() != Image.FORMAT_RGBA8:
			timg.convert(Image.FORMAT_RGBA8)
		if tex == main.PROP_GRASS:
			main._mute_grass_pixels(timg)
		var tsz := timg.get_size()
		for t in entry[1]:
			var dimg := timg
			if not variants.is_empty():
				var idx: int = (t.x + t.y / 2) if main.BUSH_VARIANTS.has(tex) else (t.x * 7 + t.y * 13)
				dimg = (variants[idx % variants.size()] as Texture2D).get_image()
				if dimg.get_format() != Image.FORMAT_RGBA8:
					dimg.convert(Image.FORMAT_RGBA8)
			if main._MUTE_GREEN_PROPS.has(tex):
				if dimg == timg:
					dimg = dimg.duplicate()
				if main._MUTE_WOODY.has(tex):
					main._mute_grass_pixels(dimg, main._WOODY_SAT_MUL, main._WOODY_SAT_CAP)
				else:
					main._mute_grass_pixels(dimg)
			out.blend_rect(dimg, Rect2i(Vector2i.ZERO, tsz),
				Vector2i(t.x * TILE, t.y * TILE + yo))
