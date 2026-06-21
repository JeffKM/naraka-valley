extends Node2D
# P2.0 에셋 파이프라인 스파이크 — 임포트·미리보기 하네스 (ADR-0001 허용 "글루")
#
# 목적: PixelLab/Aseprite가 만든 *완성 픽셀*을 받아 Godot 빌드에 끼워, 320×180 정수배에서
#       PASS 4기준을 눈으로 판정한다 — ① 가독성 ② 전경↔배경 톤 결합 ③ 미호 정체성 ④ (제작시간은 별도 기록).
#       이건 변환 엔진이 아니다(생성은 PixelLab MCP/API가 함). 임포트·적용·미리보기만 한다(ADR-0001 글루 허용).
#
# 사용법: PNG를 res://spike/assets/ 에 아래 상수 이름대로 넣고 이 씬을 F6(현재 씬 실행)으로 띄운다.
#         파일이 없으면 그레이박스 폴백으로 떨어져 *지금도* 실행된다(에셋 0개여도 하네스 자체 검증 가능).
#
# 조작: 방향키 = 미호 이동(지형 위 4방향 워크 확인) · G = 픽셀 격자 토글 · R = 에셋 리로드

const ASSET_DIR := "res://spike/assets/"
const TILE := 16

# ── PixelLab 출력 포맷을 보고 조정할 그리드 사양 (스파이크가 *발견*해 잠근다) ──────────
const CHAR_SHEET := "miho_walk.png"          # 4방향 워크 시트(행=방향, 열=프레임)
# ── P2.0 스파이크가 발견해 잠근 그리드 ──────────────────────────────
# PixelLab create_character(size=32)는 캔버스를 ~1.4배 키워 48×48 프레임으로 출력하고,
# walk 템플릿은 방향당 6프레임. 또 시트가 아니라 방향별 개별 PNG로 주므로
# 글루로 4행(down/up/right/left=south/north/east/west)×6열 시트로 합성해 둠.
const CHAR_FRAME := Vector2i(48, 48)         # PixelLab 실제 출력 프레임(16×32 아님 — 발견)
const CHAR_DIRS := ["down", "up", "right", "left"]  # 합성 시 south/north/east/west 순
const CHAR_FRAMES_PER_DIR := 6               # walk 템플릿 = 방향당 6프레임(발견)
const CHAR_FPS := 8.0

const TILE_FILES := {"ground": "tile_ground.png", "path": "tile_path.png", "soil": "tile_soil.png"}

const CROP_STAGES := ["honryeong_seed.png", "honryeong_sprout.png", "honryeong_mature.png"]

# 그레이박스 폴백 색(main.gd와 동일 톤 — 에셋 없을 때도 화면이 성립한다)
const C_GROUND := Color(0.16, 0.18, 0.16)
const C_PATH := Color(0.46, 0.43, 0.38)
const C_SOIL := Color(0.31, 0.25, 0.20)
const C_CROP := [Color(0.30, 0.26, 0.18), Color(0.40, 0.62, 0.34), Color(0.86, 0.74, 0.30)]  # 씨앗/새싹/수확가능

# 스테이지 크기(타일): 위=풀, 가운데 한 줄=길, 아래=밭흙 → 세 타일이 한 화면에서 같이 보인다
const COLS := 12
const ROWS := 7
const PATH_ROW := 3
const CROP_ROW := 5

var _tiles := {}                 # name -> Texture2D
var _crop_tex: Array = []        # 3 stage Texture2D 또는 null
var _char: AnimatedSprite2D = null   # 시트가 있을 때만 지연 생성(없으면 orphan 누수 방지)
var _char_ok := false
var _facing := "down"
var _grid := false
var _missing: Array[String] = []
var _label := Label.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_assets()
	_setup_camera()
	_setup_char()
	_setup_hud()
	queue_redraw()

func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(COLS * TILE * 0.5, ROWS * TILE * 0.5)
	add_child(cam)
	cam.make_current()

func _load_assets() -> void:
	_missing.clear()
	_tiles.clear()
	for k in TILE_FILES:
		var t := _try_load(TILE_FILES[k])
		if t:
			_tiles[k] = t
	_crop_tex.clear()
	for f in CROP_STAGES:
		_crop_tex.append(_try_load(f))

func _try_load(file: String) -> Texture2D:
	var path := ASSET_DIR + file
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	_missing.append(file)
	return null

func _setup_char() -> void:
	var sheet := _try_load(CHAR_SHEET)
	if sheet == null:
		# 시트 없음 → 만들어둔 게 있으면 정리(누수 방지), 그레이박스 폴백으로 떨어진다
		if _char:
			_char.queue_free()
			_char = null
		_char_ok = false
		return
	if _char == null:
		_char = AnimatedSprite2D.new()
		add_child(_char)
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for row in CHAR_DIRS.size():
		var anim: String = "walk_" + CHAR_DIRS[row]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, CHAR_FPS)
		for col in CHAR_FRAMES_PER_DIR:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(col * CHAR_FRAME.x, row * CHAR_FRAME.y, CHAR_FRAME.x, CHAR_FRAME.y)
			frames.add_frame(anim, at)
	_char.sprite_frames = frames
	_char.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 발치 중앙 원점(player.gd 규약): centered 스프라이트를 위로 절반 올려 바닥을 position에 맞춘다
	_char.offset = Vector2(0, -CHAR_FRAME.y * 0.5)
	_char.position = Vector2(COLS * TILE * 0.5, (CROP_ROW + 1) * TILE)
	_char_ok = true
	_play_facing()

func _play_facing() -> void:
	if _char == null:
		return
	var anim := "walk_" + _facing
	if _char.sprite_frames and _char.sprite_frames.has_animation(anim):
		_char.play(anim)

func _setup_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	cl.add_child(_label)
	_label.position = Vector2(6, 4)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_update_label()

func _update_label() -> void:
	var status := "에셋 %d/%d 로드" % [_loaded_count(), _total_count()]
	if _missing.is_empty():
		status += "  (전부 적용됨)"
	else:
		status += "  · 없음: " + ", ".join(_missing)
	_label.text = "P2.0 스파이크 미리보기 — %s\n방향키=미호 이동  G=격자  R=리로드" % status

func _loaded_count() -> int:
	var n := _tiles.size()
	for t in _crop_tex:
		if t:
			n += 1
	if _char_ok:
		n += 1
	return n

func _total_count() -> int:
	return TILE_FILES.size() + CROP_STAGES.size() + 1  # +1 = 캐릭터 시트

func _process(delta: float) -> void:
	if not _char_ok:
		return
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if v != Vector2.ZERO:
		_char.position += v * 40.0 * delta
		var nf := _facing
		if absf(v.x) > absf(v.y):
			nf = "right" if v.x > 0.0 else "left"
		else:
			nf = "down" if v.y > 0.0 else "up"
		if nf != _facing:
			_facing = nf
			_play_facing()
		elif not _char.is_playing():
			_play_facing()
	else:
		_char.stop()
		_char.frame = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_grid = not _grid
			queue_redraw()
		elif event.keycode == KEY_R:
			_load_assets()
			_setup_char()
			_update_label()
			queue_redraw()

func _draw() -> void:
	# 1) 지형 패치 — 위=풀 / 가운데 한 줄=길 / 아래=밭흙 (전경↔배경 톤 결합 검증용)
	for y in ROWS:
		for x in COLS:
			var kind := _cell_kind(y)
			var pos := Vector2(x * TILE, y * TILE)
			if _tiles.has(kind):
				draw_texture(_tiles[kind], pos)
			else:
				draw_rect(Rect2(pos, Vector2(TILE, TILE)), _fallback_tile_color(kind))
	# 2) 작물 3단계 — 밭흙 줄 위에 일렬(씨앗→새싹→수확가능)
	for i in 3:
		var cell := Vector2((2 + i * 3) * TILE, CROP_ROW * TILE)
		var tex: Texture2D = _crop_tex[i] if i < _crop_tex.size() else null
		if tex:
			# 키 큰 작물(16×32)도 바닥 정렬: 타일 바닥에 발 맞춤
			draw_texture(tex, Vector2(cell.x, cell.y + TILE - tex.get_height()))
		else:
			draw_rect(Rect2(cell, Vector2(TILE, TILE)), C_CROP[i])
	# 3) 캐릭터 시트가 없으면 그레이박스 미호 폴백(발치 중앙, player.gd 규약)
	if not _char_ok:
		var fc := Vector2(COLS * TILE * 0.5, (CROP_ROW + 1) * TILE)
		draw_rect(Rect2(fc + Vector2(-8, -32), Vector2(16, 32)), Color(0.85, 0.72, 0.45))
	# 4) 픽셀 격자(정수배 정렬 확인)
	if _grid:
		var col := Color(1, 1, 1, 0.12)
		for x in COLS + 1:
			draw_line(Vector2(x * TILE, 0), Vector2(x * TILE, ROWS * TILE), col)
		for y in ROWS + 1:
			draw_line(Vector2(0, y * TILE), Vector2(COLS * TILE, y * TILE), col)

func _cell_kind(y: int) -> String:
	if y == PATH_ROW:
		return "path"
	elif y > PATH_ROW:
		return "soil"
	return "ground"

func _fallback_tile_color(kind: String) -> Color:
	match kind:
		"path":
			return C_PATH
		"soil":
			return C_SOIL
		_:
			return C_GROUND
