extends Node2D
# P2.1 캐스트 미리보기 하네스 (글루, ADR-0001 허용) — 도색된 캐스트를 한 무대에 세워 톤 통일을 눈으로 본다.
# 사용: godot --path <game> res://cast_preview.tscn  (또는 에디터 F6)
# 조작: 방향키=플레이어 4방향 워크 확인 · G=격자 · R=리로드
#
# 시트 규약(P2.0 §4에서 잠금): 캐릭터 프레임 48×48, 행=방향(down/up/right/left=south/north/east/west).
#   워크 캐릭터 = 행당 6프레임 / 대기 NPC = 행당 1프레임(rotation).

const CHARS := "res://assets/characters/"
const BG := "res://spike/assets/tile_ground.png"
const PATH_TEX := "res://spike/assets/tile_path.png"
const FRAME := Vector2i(80, 80)   # standard size56 통일본 native
const DIRS := ["down", "up", "right", "left"]   # 행 순서
const FPS := 8.0
const STEP := 86          # 캐스트 가로 간격(라벨 겹침 방지)
const START_X := 40.0
const TILE := 16
const COLS := 26
const ROWS := 11

# [표시이름, 파일, 워크여부]
const CAST := [
	["플레이어", "player_walk.png", true],
	["미호", "miho_walk.png", true],
	["옥자", "okja.png", false],
	["바나", "bana.png", false],
	["멜", "mel.png", false],
]

var _bg: Texture2D = null
var _path: Texture2D = null
var _player: AnimatedSprite2D = null
var _facing := "down"
var _grid := false
var _missing: Array[String] = []
var _label := Label.new()
var _names: Array[Label] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg = _try_load(BG)
	_path = _try_load(PATH_TEX)
	_build_cast()
	_setup_camera()
	_setup_hud()
	queue_redraw()

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	_missing.append(path.get_file())
	return null

func _frames_for(sheet: Texture2D, is_walk: bool) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var cols: int = int(sheet.get_width() / FRAME.x) if is_walk else 1
	for row in DIRS.size():
		var anim: String = "walk_" + DIRS[row]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, FPS)
		sf.set_animation_loop(anim, true)
		for col in cols:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(col * FRAME.x, row * FRAME.y, FRAME.x, FRAME.y)
			sf.add_frame(anim, at)
	return sf

func _build_cast() -> void:
	# 무대 가운데 줄에 캐스트를 일렬로 세운다
	var baseline_y := (ROWS - 4) * TILE
	for i in CAST.size():
		var nm: String = CAST[i][0]
		var file: String = CAST[i][1]
		var is_walk: bool = CAST[i][2]
		var sheet := _try_load(CHARS + file)
		var px := START_X + i * STEP
		if sheet == null:
			continue
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = _frames_for(sheet, is_walk)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.offset = Vector2(0, -36)   # 발치(콘텐츠 y≈76)를 노드 원점에 (char_sprite와 동일)
		spr.position = Vector2(px, baseline_y)
		spr.play("walk_down")
		if not is_walk:
			spr.pause()   # 대기 NPC는 정지 포즈(남쪽)
		add_child(spr)
		if CAST[i][1] == "player_walk.png":
			_player = spr
		# 이름 라벨
		var lb := Label.new()
		lb.text = nm
		lb.add_theme_color_override("font_color", Color.WHITE)
		lb.add_theme_color_override("font_outline_color", Color.BLACK)
		lb.add_theme_constant_override("outline_size", 4)
		lb.position = Vector2(px - nm.length() * 5.0, baseline_y + 8)
		add_child(lb)
		_names.append(lb)

func _setup_camera() -> void:
	# 캐스트가 선 가로 범위 중앙에 맞춰 5명이 내부해상도(320×180)에 다 들어오게 한다
	var first_x := START_X
	var last_x := START_X + (CAST.size() - 1) * STEP
	var cam := Camera2D.new()
	cam.position = Vector2((first_x + last_x) * 0.5, (ROWS - 4) * TILE - 20)
	cam.zoom = Vector2.ONE
	add_child(cam)
	cam.make_current()

func _setup_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	cl.add_child(_label)
	_label.position = Vector2(6, 4)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	var loaded := CAST.size() - _missing.size()
	var status := "P2.1 캐스트 미리보기 — %d/%d 로드" % [loaded, CAST.size()]
	if not _missing.is_empty():
		status += "  · 없음: " + ", ".join(_missing)
	_label.text = status + "\n방향키=플레이어 워크  G=격자  R=리로드"

func _process(delta: float) -> void:
	if _player == null:
		return
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if v != Vector2.ZERO:
		_player.position += v * 40.0 * delta
		var nf := _facing
		if absf(v.x) > absf(v.y):
			nf = "right" if v.x > 0.0 else "left"
		else:
			nf = "down" if v.y > 0.0 else "up"
		if nf != _facing:
			_facing = nf
		if not _player.is_playing():
			_player.play("walk_" + _facing)
		elif _player.animation != "walk_" + _facing:
			_player.play("walk_" + _facing)
	else:
		_player.pause()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_grid = not _grid
			queue_redraw()
		elif event.keycode == KEY_R:
			get_tree().reload_current_scene()

func _draw() -> void:
	# 바닥: 풀 타일 채우고 캐스트가 선 줄만 흙길로
	for y in ROWS:
		for x in COLS:
			var pos := Vector2(x * TILE, y * TILE)
			var on_path := (y == ROWS - 4 or y == ROWS - 5)
			var tex := _path if on_path else _bg
			if tex:
				draw_texture(tex, pos)
			else:
				draw_rect(Rect2(pos, Vector2(TILE, TILE)), Color(0.16, 0.18, 0.16) if not on_path else Color(0.46, 0.43, 0.38))
	if _grid:
		var col := Color(1, 1, 1, 0.12)
		for x in COLS + 1:
			draw_line(Vector2(x * TILE, 0), Vector2(x * TILE, ROWS * TILE), col)
		for y in ROWS + 1:
			draw_line(Vector2(0, y * TILE), Vector2(COLS * TILE, y * TILE), col)
