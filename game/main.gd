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

# ── T2.1/T2.3 밭 오버레이 타일(Field 레이어 아틀라스 인덱스) ───────────────
# Ground의 SOIL 위에 겹쳐 그리는 칸 상태 표시. 미경작 칸은 오버레이 없음(맨 흙).
# 인덱스 = 외형단계(APPEAR) × 2 + 젖음(0 마름 / 1 젖음). 코드로 한 번에 생성한다.
#   외형단계: 0=빈 고랑(작물 없음) / 1=씨앗 / 2=새싹 / 3=수확가능(황금)
# 젖음은 베이스 흙색만 어둡게 바꾸고, 외형은 가운데 도형으로 표현한다.
const AP_EMPTY := 0    # 경작만(고랑)
const AP_SEED := 1     # 갓 심음(작은 점)
const AP_SPROUT := 2   # 자라는 중(중간 새싹)
const AP_MATURE := 3   # 다 자람(큰 황금 새싹 = 수확 가능 표시)
const N_APPEAR := 4
const N_OV := N_APPEAR * 2  # 외형 4 × 젖음 2 = 8타일

# 고랑 베이스색. SOIL(0.31,0.25,0.20)보다 어둡게, 젖으면 더 어둡고 축축하게.
const OV_DRY := Color(0.24, 0.17, 0.12)   # 파낸 마른 고랑
const OV_WET := Color(0.15, 0.12, 0.11)   # 젖은 고랑
# 외형단계별 가운데 도형(반지름 px, 색). 수확가능은 황금색으로 눈에 띄게(완료기준 표시).
const SPROUT := Color(0.40, 0.62, 0.34)   # 회녹색 새싹(그레이박스 작물)
const MATURE := Color(0.86, 0.74, 0.30)   # 황금 — 다 자람 = 수확 가능
const AP_DOT := [0, 2, 4, 5]              # 외형단계별 새싹 반지름(EMPTY는 0=안 그림)

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
@onready var field_layer: TileMapLayer = $Field           # T2.1 밭 상태 오버레이
@onready var player: CharacterBody2D = $Player
@onready var readout: Label = $CanvasLayer/Readout
@onready var clock: GameClock = $Clock                     # T1.5 시계
@onready var clock_label: Label = $CanvasLayer/ClockLabel
@onready var sleep_prompt: Label = $CanvasLayer/SleepPrompt
@onready var interact_prompt: Label = $CanvasLayer/InteractPrompt  # T2.1 [E] 안내
@onready var farm: FarmField = $FarmField                  # T2.1 밭 칸 상태
@onready var crop_label: Label = $CanvasLayer/CropLabel    # T2.3 선택 작물 HUD
@onready var fade: ColorRect = $CanvasLayer/Fade

var _grid: Array = []  # _grid[y][x] = 타일 id
var _sleeping := false  # T1.5 취침 연출 중이면 이동·입력 잠금

var _target := Vector2i(-1, -1)  # T2.1 바라보는 앞 칸(상호작용 대상)
var _target_valid := false       # 그 칸이 밭(SOIL)이라 상호작용 가능한가

# T2.3 현재 심을 작물. Q로 카탈로그(빠른 성장 순)를 순환 선택한다.
# 그레이박스에선 도구·씨앗 인벤토리 UI 없이 이 한 변수로 작물 종류를 고른다.
var _selected_crop: String = CropCatalog.HONRYEONGCHO

func _ready() -> void:
	_ensure_input_actions()
	ground.tile_set = _build_tileset()
	field_layer.tile_set = _build_field_tileset()
	farm.tile_changed.connect(_on_tile_changed)
	_build_grid()
	_paint_grid()
	_place_labels()
	_setup_player_and_camera()
	_setup_clock()

# 'interact' 액션을 코드로 등록한다(키 E). project.godot 수동 편집 대신 런타임
# 조립 — 이 프로젝트의 TileSet·벽 생성과 같은 결이고, 직렬화 포맷 깨질 위험이 없다.
func _ensure_input_actions() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	InputMap.action_add_event("interact", ev)
	# T2.3 작물 선택 순환(키 Q). 같은 결로 런타임 등록한다.
	InputMap.add_action("cycle_crop")
	var ev_q := InputEventKey.new()
	ev_q.physical_keycode = KEY_Q
	InputMap.action_add_event("cycle_crop", ev_q)

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

# ── T2.1/T2.3 밭 오버레이 TileSet: 칸 상태 8종(충돌 없음) ──────────────────
# Ground와 같은 방식(단색 블록 아틀라스를 코드 생성)이지만, 상태 표시용이라
# 물리 레이어는 없다. 인덱스 = 외형단계 × 2 + 젖음. 외형단계가 오를수록 가운데
# 새싹이 커지고, 수확가능 단계는 황금색으로 칠해 "수확 가능 표시"를 만든다.
func _build_field_tileset() -> TileSet:
	var img := Image.create_empty(TILE * N_OV, TILE, false, Image.FORMAT_RGBA8)
	for ap in N_APPEAR:
		for wet in 2:
			var i := ap * 2 + wet
			var base := OV_WET if wet == 1 else OV_DRY
			img.fill_rect(Rect2i(i * TILE, 0, TILE, TILE), base)
			var edge := base.darkened(0.3)
			img.fill_rect(Rect2i(i * TILE, 0, TILE, 1), edge)  # 윗줄(고랑 격자감)
			img.fill_rect(Rect2i(i * TILE, 0, 1, TILE), edge)  # 왼줄
			var r: int = AP_DOT[ap]                             # 새싹 반지름(0이면 안 그림)
			if r > 0:
				var c := MATURE if ap == AP_MATURE else SPROUT
				var c0 := TILE / 2 - r                          # 가운데 정렬
				img.fill_rect(Rect2i(i * TILE + c0, c0, r * 2, r * 2), c)
	var tex := ImageTexture.create_from_image(img)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in N_OV:
		src.create_tile(Vector2i(i, 0))

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
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

# ── T1.5 하루 사이클 ──────────────────────────────────────────────────────
func _setup_clock() -> void:
	# 24:00에 도달하면(쓰러짐) 위치에 상관없이 강제 취침시킨다.
	clock.collapsed.connect(_on_collapsed)
	# T2.3 취침으로 새 날이 시작되면 작물이 하루치 자란다(물 준 칸만). 시그널 디커플링.
	clock.day_advanced.connect(_on_day_advanced)

# 새 날 시작 → 밭 전체 하루 경과 처리(물 준 칸 성장 +1, 흙 마름).
func _on_day_advanced(_day: int) -> void:
	farm.advance_day()

# T2.3 선택 작물을 카탈로그 순서(빠른 성장 순)대로 다음 것으로 순환.
func _cycle_crop() -> void:
	var ids := CropCatalog.ids()
	var i := ids.find(_selected_crop)
	_selected_crop = ids[(i + 1) % ids.size()]

func _on_collapsed() -> void:
	_do_sleep()  # 어디서든 쓰러져 다음 날 아침으로

# 취침 가능 조건: 집 구역 안 + 연출 중이 아님. 그레이박스라 침대 오브젝트 없이
# '집에 있으면 잘 수 있다'로 단순화한다(에셋·가구는 Phase 2).
func _can_sleep() -> bool:
	return not _sleeping and _zone_at(player.global_position) == "집"

func _do_sleep() -> void:
	if _sleeping:
		return
	_sleeping = true
	clock.running = false
	player.set_physics_process(false)  # 연출 중 이동 잠금
	player.velocity = Vector2.ZERO
	sleep_prompt.visible = false
	# 검은 화면으로 페이드 → 날짜 넘기기 → 다시 밝아짐. CanvasLayer라 카메라와 무관.
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.4)
	tw.tween_callback(clock.sleep)       # day +1, 06:00 리셋
	tw.tween_interval(0.3)
	tw.tween_property(fade, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_on_sleep_done)

func _on_sleep_done() -> void:
	player.set_physics_process(true)
	_sleeping = false

func _process(_delta: float) -> void:
	# 취침 입력: 집 안에서 Enter/Space(ui_accept)
	if _can_sleep() and Input.is_action_just_pressed("ui_accept"):
		_do_sleep()

	# T2.3 작물 선택 순환(Q). 심을 작물을 바꾼다(성장일수가 다른 3종).
	if not _sleeping and Input.is_action_just_pressed("cycle_crop"):
		_cycle_crop()

	# T2.1/T2.3 밭 상호작용: 바라보는 앞 칸을 대상으로, E 한 키가 다음 단계를
	# 수행한다(괭이질→심기→물주기→…자람…→수확). 심기엔 현재 선택 작물을 넘긴다.
	_update_target()
	if not _sleeping and _target_valid and Input.is_action_just_pressed("interact"):
		var did := farm.interact(_target, _selected_crop)
		# (did != "" 이면 한 동작이 일어남. T2.4에서 여기에 혼력 소모가 붙는다.)
		if did != "":
			queue_redraw()  # 새 상태가 바로 보이도록

	var p := player.global_position
	readout.text = "방향키 이동   구역: %s   위치(%d, %d)   FPS %d" % [
		_zone_at(p), int(p.x), int(p.y), Engine.get_frames_per_second()
	]
	clock_label.text = "Day %d   %s   %s" % [clock.day, clock.clock_string(), clock.phase()]
	# T2.3 선택 작물 HUD: 이름·성장일수 + 전환 안내.
	crop_label.text = "심을 작물: %s(%d일)  [Q] 변경" % [
		CropCatalog.name_of(_selected_crop), CropCatalog.growth_days(_selected_crop)
	]
	# 집 안에서만 취침 안내를 띄운다(연출 중엔 숨김).
	sleep_prompt.visible = _can_sleep()
	# 밭 칸을 바라볼 때만 [E] 안내(다음 동작 이름). 다 키운(물준) 칸이면 숨김.
	var action := farm.next_action(_target) if _target_valid else ""
	interact_prompt.visible = not _sleeping and _target_valid and action != ""
	if interact_prompt.visible:
		interact_prompt.text = "[E] %s" % action

# ── T2.1 상호작용 대상 칸 / 시각화 ────────────────────────────────────────
# 플레이어 발 타일에서 바라보는 방향으로 한 칸 앞을 대상으로 삼는다.
# 대각선 facing은 더 큰 축으로 스냅(4방향화)한다.
func _update_target() -> void:
	var old_target := _target
	var old_valid := _target_valid
	var foot := player.global_position
	var ft := Vector2i(int(foot.x) / TILE, int(foot.y) / TILE)
	var f: Vector2 = player.get_facing()
	var step := Vector2i(0, 1)
	if abs(f.x) >= abs(f.y) and f.x != 0:
		step = Vector2i(int(sign(f.x)), 0)
	elif f.y != 0:
		step = Vector2i(0, int(sign(f.y)))
	_target = ft + step
	_target_valid = _is_farmable(_target)
	if _target != old_target or _target_valid != old_valid:
		queue_redraw()  # 커서 위치/표시 갱신

# 상호작용 가능한 칸 = 맵 안 + 밭 흙(SOIL). 길·집·카페·벽은 제외.
func _is_farmable(t: Vector2i) -> bool:
	if t.x < 0 or t.x >= MAP_W or t.y < 0 or t.y >= MAP_H:
		return false
	return _grid[t.y][t.x] == SOIL

# 밭 칸 상태가 바뀌면 오버레이 타일을 갱신한다(FarmField.tile_changed로 호출).
func _on_tile_changed(t: Vector2i) -> void:
	var idx := _overlay_index(t)
	if idx < 0:
		field_layer.erase_cell(t)
	else:
		field_layer.set_cell(t, 0, Vector2i(idx, 0))

# 칸 상태 → 오버레이 아틀라스 인덱스(-1 = 미경작, 오버레이 없음).
# 인덱스 = 외형단계 × 2 + 젖음. 외형단계는 FarmField.growth_stage(씨앗/새싹/수확가능)
# 에 빈 고랑(작물 없음)을 더해 매핑한다.
func _overlay_index(t: Vector2i) -> int:
	if not farm.is_tilled(t):
		return -1
	var wet := 1 if farm.is_watered(t) else 0
	var appearance := AP_EMPTY
	if farm.is_planted(t):
		appearance = farm.growth_stage(t) + 1  # 0/1/2 → SEED/SPROUT/MATURE
	return appearance * 2 + wet

# 대상 칸 강조 커서(흰 1px 테두리). main은 원점 0,0이라 그리기 좌표=타일 픽셀.
func _draw() -> void:
	if not _target_valid:
		return
	var p := Vector2(_target.x * TILE, _target.y * TILE)
	draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(1, 1, 1, 0.7), false, 1.0)

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
