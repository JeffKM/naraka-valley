extends SceneTree

# 육안 글루(ADR-0001) — 나루 마을(100×72) *전체 무대*를 한 장에 CPU 합성한다.
# ★[S2-T3 / ADR-0060 결정 3] 종전 버전은 Ground/Field 타일맵 + 외관 4장만 그려 stale였다(마을이
#   `_build_ground16` 단일출처 파이프라인으로 이식되면서 실제 화면의 지면은 거의 전부
#   `_ground_detail_tex` 오버레이 한 장이다 — 그걸 안 그리면 덤프가 라이브와 완전히 다른 그림이 된다).
#   home_full_dump.gd와 같은 층위로 맞춘다: 타일맵 → 지면 오버레이 → 프롭 → 외관.
#
# 레이어 순서 = main._draw와 동일:
#   ① Ground/Field 타일맵(그레이박스 WALL 박스 = 만물상·주민 집 11채가 여기서 보인다)
#   ② _ground_detail_tex(ground16 베이크 — 잔디/흙 Wang 합성·길·물가 shore·스캐터)
#   ③ 야외 프롭(마을은 현재 야외 프롭 0 — CAFE/VILLAGE_HOUSE 레이아웃은 실내 띠 y72+라 캔버스 밖)
#   ④ 건물 외관 4장(카페·미호/멜/바나 집) — main._draw_facade_*와 같은 **좌상단 1:1** blit
#      (HOME의 bottom-center 앵커와 다르다. 마을 외관은 rect.position에 그대로 얹힌다.)
#      ★ 풀 백드롭은 그리지 않는다 — ground16 구역은 main._facade_grass_backdrop이 early-return
#        (건물마다 초록 사각형이 되살아나는 [ADR-0054] 회귀 방지). 지면 오버레이의 흙 패드가 비친다.
# 사용: godot --headless --path game -s res://tools/village_dump.gd

const TILE := 32

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var t0 := Time.get_ticks_msec()
	main._rebuild_region(RegionCatalog.NARU_VILLAGE)   # 마을로 전환(그리드·지면·외관 자리)
	var build_ms := Time.get_ticks_msec() - t0
	await process_frame
	var size: Vector2i = RegionCatalog.size_of(RegionCatalog.NARU_VILLAGE)
	var out := Image.create(size.x * TILE, size.y * TILE, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.05, 0.07, 1.0))
	# ① 타일맵(Ground/Field)
	for layer in [main.get_node("Ground") as TileMapLayer, main.get_node("Field") as TileMapLayer]:
		_blit_layer(layer, out)
	# ② 지면 디테일 오버레이(ground16 베이크 한 장 — 타일 위·프롭 아래)
	if main._ground_detail_tex != null:
		var gdi: Image = main._ground_detail_tex.get_image()
		if gdi.get_format() != Image.FORMAT_RGBA8:
			gdi.convert(Image.FORMAT_RGBA8)
		out.blend_rect(gdi, Rect2i(Vector2i.ZERO, gdi.get_size()), Vector2i.ZERO)
	# ③ 야외 프롭(_draw_props_for의 CPU 재현 — 실내 띠 좌표는 캔버스 밖이라 건너뛴다)
	for key in main._REGION_PROP_KEYS.get(RegionCatalog.NARU_VILLAGE, []):
		for entry in main._prop_entries_for(key):
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
					continue   # 실내 띠(y72+) — 야외 캔버스 밖
				out.blend_rect(timg, Rect2i(Vector2i.ZERO, tsz), Vector2i(t.x * TILE, t.y * TILE + yo))
	# ④ 건물 외관 — 앵커가 두 갈래라 각 항목이 자기 앵커를 들고 온다(main._draw와 1:1):
	#    · 카페·메인 집 3 = `_draw_facade_*`의 **좌상단 1:1** blit(rect.position에 그대로)
	#    · ★[S2-T10] 만물상·주민 집 11 = `_blit_facade_anchored`의 **bottom-center** 앵커
	#      (art 바텀 = footprint 하단 경계, 가로 중앙 정렬 → 지붕이 위로 솟는다)
	var facades := [
		[main.FACADE_CAFE, main.CAFE_EXT_RECT, false],
		[main.FACADE_MEL_HOUSE, main.MEL_HOUSE_RECT, false],
		[main.FACADE_MIHO_HOUSE, main.MIHO_HOUSE_RECT, false],
		[main.FACADE_BANA_HOUSE, main.BANA_HOUSE_RECT, false],
		[main.FACADE_STORE, main.STORE_EXT_RECT, true],
	]
	for i in main.RESIDENT_HOUSE_RECTS.size():
		var hr: Rect2i = main.RESIDENT_HOUSE_RECTS[i]
		var htex: Texture2D = main.FACADE_VILLAGE_HOUSE_WIDE if hr.size.x >= 5 \
			else main.VILLAGE_HOUSE_CYCLE[i % main.VILLAGE_HOUSE_CYCLE.size()]
		facades.append([htex, hr, true])
	for f in facades:
		var tex: Texture2D = f[0]
		var rect: Rect2i = f[1]
		var fimg := tex.get_image()
		if fimg.get_format() != Image.FORMAT_RGBA8:
			fimg.convert(Image.FORMAT_RGBA8)
		var at := rect.position * TILE
		if bool(f[2]):
			var sz := fimg.get_size()
			at = Vector2i(
				int((rect.position.x + rect.size.x * 0.5) * TILE) - sz.x / 2,
				(rect.position.y + rect.size.y) * TILE - sz.y)
		out.blend_rect(fimg, Rect2i(Vector2i.ZERO, fimg.get_size()), at)
	out.save_png("res://tools/village_dump.png")
	print("✅ village_dump.png 저장 (", size.x, "×", size.y, ") — 구역 리빌드 ", build_ms, "ms")
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
		var tile_img := src.texture.get_image().get_region(region)
		out.blend_rect(tile_img, Rect2i(Vector2i.ZERO, tile_img.get_size()), Vector2i(cell.x * TILE, cell.y * TILE))
