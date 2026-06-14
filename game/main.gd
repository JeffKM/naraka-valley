extends Node2D
# T1.4 — 16×16 타일맵 더미 맵 1개 (그레이박스).
#
# 목적: 회색 캐릭터가 "진짜 타일맵"(TileMapLayer) 위를 돌아다니며
#       밭·집·카페 세 구역을 시각적으로 구분할 수 있는지 검증한다.
#       회색 도형만(ADR-0001). 타일 16×16 · 내부해상도 320×180(ADR-0003).
#
# 설계 메모:
#   - 에셋 없이(ADR-0001) 타일맵을 쓰기 위해, 단색 16×16 블록을 코드로 그려
#     아틀라스 텍스처를 만들고 TileSet을 런타임에 조립한다. "도트화 툴"이 아니라
#     그레이박스용 플레이스홀더 생성이다.
#   - 맵(40×24 = 640×384)은 화면(320×180)보다 커서, 카메라가 캐릭터를 따라가며
#     맵 경계에서 멈춘다 → "돌아다니며"가 의미를 가진다.
#   - 온보딩 동선(CONTEXT '온보딩': 도착→집→밭→카페)을 염두에 둔 배치다.
#     길(PATH)이 도착 지점에서 허브로 올라가 집·밭·카페로 갈라진다.
#
# 보는 법:
#   - 방향키로 이동. 집/카페는 벽으로 둘러싸여 문으로만 드나든다(통과 불가).
#   - 밭은 벽 없는 열린 구역. 각 구역 위에 떠 있는 라벨(집/밭/카페/도착)로 식별.
#   - 좌상단 readout에 현재 구역·위치·FPS가 뜬다.

# ── 규격 ────────────────────────────────────────────────────────────────
const TILE := 16                       # 타일 한 칸(ADR-0003)
const MAP_W := 40                      # 맵 가로(타일) = 640px
const MAP_H := 24                      # 맵 세로(타일) = 384px

# ── 타일 종류(아틀라스 인덱스 = 이 순서) ──────────────────────────────────
const GROUND := 0   # 바깥 바닥(걷기 O)
const PATH := 1     # 길 — 온보딩 동선(걷기 O)
const SOIL := 2     # 밭 흙(걷기 O)
const HOUSE := 3    # 집 바닥(걷기 O)
const CAFE := 4     # 카페 바닥(걷기 O)
const WALL := 5     # 벽/건물 외벽(통과 X)
const N_TILES := 6

# 각 타일의 그레이박스 색(밝기·미세 색조로만 구분, 회색 기조 유지). WALL이 가장 밝다.
const COLORS := [
	Color(0.16, 0.18, 0.16),  # GROUND — 어두운 풀밭 톤
	Color(0.46, 0.43, 0.38),  # PATH   — 밝은 흙길(동선이 눈에 띄게)
	Color(0.31, 0.25, 0.20),  # SOIL   — 갈색 밭흙
	Color(0.33, 0.32, 0.41),  # HOUSE  — 푸른 실내
	Color(0.42, 0.37, 0.30),  # CAFE   — 따뜻한 실내
	Color(0.56, 0.56, 0.62),  # WALL   — 가장 밝은 회색(외벽)
]

# ── 구역 사각형(타일 좌표, Rect2i(x, y, 폭, 높이)) ───────────────────────
# readout 구역 판정과 라벨 배치에 함께 쓴다.
const HOUSE_RECT := Rect2i(3, 4, 7, 6)    # x3..9,  y4..9
const FARM_RECT := Rect2i(14, 4, 14, 11)  # x14..27, y4..14
const CAFE_RECT := Rect2i(30, 4, 8, 7)    # x30..37, y4..10
const SPAWN_TILE := Vector2i(20, 21)      # 도착 지점

@onready var ground: TileMapLayer = $Ground
@onready var player: CharacterBody2D = $Player
@onready var readout: Label = $CanvasLayer/Readout

var _grid: Array = []  # _grid[y][x] = 타일 id

func _ready() -> void:
	ground.tile_set = _build_tileset()
	_build_grid()
	_paint_grid()
	_place_labels()
	_setup_player_and_camera()

# ── TileSet 조립: 단색 블록 아틀라스 + WALL 충돌 ──────────────────────────
func _build_tileset() -> TileSet:
	# 1) N_TILES개의 16×16 단색 블록을 가로로 이어 붙인 아틀라스 이미지를 만든다.
	#    각 블록의 위/왼쪽 1px을 어둡게 칠해 타일 격자가 눈에 보이게 한다.
	var img := Image.create_empty(TILE * N_TILES, TILE, false, Image.FORMAT_RGBA8)
	for i in N_TILES:
		var base: Color = COLORS[i]
		img.fill_rect(Rect2i(i * TILE, 0, TILE, TILE), base)
		var edge := base.darkened(0.35)
		img.fill_rect(Rect2i(i * TILE, 0, TILE, 1), edge)  # 윗줄
		img.fill_rect(Rect2i(i * TILE, 0, 1, TILE), edge)  # 왼줄
	var tex := ImageTexture.create_from_image(img)

	# 2) 아틀라스 소스에 타일 N개 등록
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in N_TILES:
		src.create_tile(Vector2i(i, 0))

	# 3) TileSet 생성 + 소스 등록 + 물리 레이어 추가
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)            # source_id = 0
	ts.add_physics_layer()           # 물리 레이어 0 (기본 collision_layer=1)

	# 4) WALL 타일에만 꽉 찬 사각 충돌 폴리곤을 붙인다(타일 중심 기준 −8..8).
	var td := src.get_tile_data(Vector2i(WALL, 0), 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	]))
	return ts

# ── 맵 데이터 구성 ────────────────────────────────────────────────────────
func _build_grid() -> void:
	# 전부 GROUND로 채운 뒤, 우선순위 순서로 덮어쓴다.
	_grid = []
	for y in MAP_H:
		var row: Array = []
		for x in MAP_W:
			row.append(GROUND)
		_grid.append(row)

	_fill_rect(FARM_RECT, SOIL)            # 밭(열린 흙 구역)
	_build_room(HOUSE_RECT, HOUSE, Vector2i(6, 9))   # 집(아래 가운데 문)
	_build_room(CAFE_RECT, CAFE, Vector2i(33, 10))   # 카페(아래 가운데 문)
	_carve_paths()                         # 온보딩 동선(맨 위에 덮어 길 강조)
	_build_border()                        # 맵 4변 경계벽(마지막에 보장)

func _build_border() -> void:
	for x in MAP_W:
		_set_tile(x, 0, WALL)
		_set_tile(x, MAP_H - 1, WALL)
	for y in MAP_H:
		_set_tile(0, y, WALL)
		_set_tile(MAP_W - 1, y, WALL)

func _build_room(rect: Rect2i, floor_id: int, door: Vector2i) -> void:
	# 바닥으로 채운 뒤 둘레를 벽으로, 문 한 칸만 길로 뚫는다 → 문으로만 출입.
	_fill_rect(rect, floor_id)
	for x in range(rect.position.x, rect.end.x):
		_set_tile(x, rect.position.y, WALL)
		_set_tile(x, rect.end.y - 1, WALL)
	for y in range(rect.position.y, rect.end.y):
		_set_tile(rect.position.x, y, WALL)
		_set_tile(rect.end.x - 1, y, WALL)
	_set_tile(door.x, door.y, PATH)

func _carve_paths() -> void:
	# 동선 허브: 가로 복도(y=16)가 집·밭·카페를 잇고, 도착 지점에서 올라온다.
	for x in range(4, 38):
		_set_tile(x, 16, PATH)                  # 가로 복도
	for y in range(17, 22):
		_set_tile(20, y, PATH)                  # 도착(20,21) → 복도
	for y in range(10, 16):
		_set_tile(6, y, PATH)                   # 집 문 → 복도
	for y in range(11, 16):
		_set_tile(33, y, PATH)                  # 카페 문 → 복도
	_set_tile(20, 15, PATH)                     # 밭 아래 → 복도

func _paint_grid() -> void:
	for y in MAP_H:
		for x in MAP_W:
			ground.set_cell(Vector2i(x, y), 0, Vector2i(_grid[y][x], 0))

# ── 구역 라벨(월드 좌표, 카메라 따라 스크롤) ──────────────────────────────
func _place_labels() -> void:
	_add_label("집", _rect_center_px(HOUSE_RECT))
	_add_label("밭", _rect_center_px(FARM_RECT))
	_add_label("카페", _rect_center_px(CAFE_RECT))
	_add_label("도착", Vector2(SPAWN_TILE.x * TILE + TILE * 0.5, (SPAWN_TILE.y - 1) * TILE))

func _add_label(text: String, center_px: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(48, 12)
	lbl.position = center_px - Vector2(24, 6)
	lbl.z_index = 10
	add_child(lbl)

# ── 플레이어 스폰 + 추적 카메라 ───────────────────────────────────────────
func _setup_player_and_camera() -> void:
	player.position = _tile_center_px(SPAWN_TILE)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAP_W * TILE
	cam.limit_bottom = MAP_H * TILE
	cam.position_smoothing_enabled = false  # 정수배 픽셀 크리스프 유지(ADR-0003)
	player.add_child(cam)
	cam.make_current()

func _process(_delta: float) -> void:
	var p := player.global_position
	readout.text = "방향키 이동   구역: %s   위치(%d, %d)   FPS %d" % [
		_zone_at(p), int(p.x), int(p.y), Engine.get_frames_per_second()
	]

# ── 헬퍼 ──────────────────────────────────────────────────────────────────
func _set_tile(x: int, y: int, id: int) -> void:
	if x >= 0 and x < MAP_W and y >= 0 and y < MAP_H:
		_grid[y][x] = id

func _fill_rect(rect: Rect2i, id: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_set_tile(x, y, id)

func _tile_center_px(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE * 0.5, t.y * TILE + TILE * 0.5)

func _rect_center_px(rect: Rect2i) -> Vector2:
	return Vector2((rect.position.x + rect.size.x * 0.5) * TILE,
		(rect.position.y + rect.size.y * 0.5) * TILE)

func _zone_at(px: Vector2) -> String:
	var t := Vector2i(int(px.x) / TILE, int(px.y) / TILE)
	if HOUSE_RECT.has_point(t):
		return "집"
	if FARM_RECT.has_point(t):
		return "밭"
	if CAFE_RECT.has_point(t):
		return "카페"
	return "바깥"
