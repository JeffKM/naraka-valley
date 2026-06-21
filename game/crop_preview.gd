extends Node2D
# P2.2 작물·소품 미리보기 하네스 (글루, ADR-0001 허용) — 저승 작물 3종을 한 무대에 모아
#   ① 한 작물의 seed→sprout→mature 성장 단계가 읽히나
#   ② 작물끼리 정체성(특히 수확 단계)이 확연히 구분되나(혼령초 파랑·피안화 빨강·호박 주황)
#   ③ 전경(작물, 외곽선 O)이 배경(밭흙, 외곽선 X) 위에 톤으로 붙나
#   를 320×180 정수배 화면에서 눈으로 판정한다.
#
# 사용: bash game/run_crops.sh  (또는 에디터에서 F6)
# 조작: G=픽셀 격자 토글 · R=리로드
#
# 규약: 작물 PNG는 res://assets/crops/<id>_<stage>.png. <id>=CropCatalog 영문 id,
#   <stage>=seed/sprout/mature(P2.0 §4에서 잠근 3프레임 규약). 32×32 네이티브를 바닥정렬로 얹는다.
#   (crops.gd의 stages 2/3/4는 T2.3 성장 틱 수 — 이 3프레임에 매핑된다. 아트 단계 수와는 별개.)

const CROP_DIR := "res://assets/crops/"
const SOIL_TEX := "res://spike/assets/tile_soil.png"
const PATH_TEX := "res://spike/assets/tile_path.png"
const TILE := 16

# 열 = 성장 단계(파일 접미사, 표시명)
const STAGES := [["seed", "씨앗"], ["sprout", "새싹"], ["mature", "수확가능"]]

# 셀 = 작물 한 칸이 차지하는 타일 수(32px 스프라이트 + 여백) · 그리드 배치
const CELL_W := 3   # 타일
const CELL_H := 3
const MARGIN := 1   # 가장자리 타일 여백

var _soil: Texture2D = null
var _path: Texture2D = null
var _crops: Array = []          # [{id, name, stages:[Texture2D|null]}]
var _grid := false
var _missing: Array[String] = []
var _label := Label.new()

# 데이터 기반: CropCatalog가 진실의 원천(작물 목록·표시명). 하드코딩하지 않는다.
func _crop_ids() -> Array:
	return CropCatalog.ids()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load()
	_setup_camera()
	_setup_labels()
	_setup_hud()
	queue_redraw()

# 월드 좌표 라벨: 열 머리(씨앗/새싹/수확가능) + 행 머리(작물 표시명)
func _world_label(text: String, pos: Vector2, cx: bool) -> void:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_color_override("font_color", Color.WHITE)
	lb.add_theme_color_override("font_outline_color", Color.BLACK)
	lb.add_theme_constant_override("outline_size", 4)
	lb.position = pos - (Vector2(text.length() * 3.0, 0) if cx else Vector2.ZERO)
	add_child(lb)

func _setup_labels() -> void:
	# 열 머리: 각 단계 칸 위 헤더 줄
	for c in STAGES.size():
		var ox := (MARGIN + c * CELL_W + CELL_W * 0.5) * TILE
		_world_label(STAGES[c][1], Vector2(ox, MARGIN * TILE - 2), true)
	# 행 머리: 각 작물 행 첫 칸 왼쪽 위
	for r in _crops.size():
		var origin := _cell_origin(r, 0)
		_world_label(_crops[r]["name"], Vector2(2, origin.y - 2), false)

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	_missing.append(path.get_file())
	return null

func _load() -> void:
	_missing.clear()
	_crops.clear()
	_soil = _try_load(SOIL_TEX)
	_path = _try_load(PATH_TEX)
	for id in _crop_ids():
		var stages: Array = []
		for s in STAGES:
			stages.append(_try_load(CROP_DIR + "%s_%s.png" % [id, s[0]]))
		_crops.append({"id": id, "name": CropCatalog.name_of(id), "stages": stages})

# 그리드 픽셀 폭/높이(타일 단위) — 헤더 1줄 + 작물 행들
func _cols() -> int:
	return MARGIN * 2 + STAGES.size() * CELL_W
func _rows() -> int:
	return MARGIN * 2 + 1 + _crops.size() * CELL_H   # +1 = 열 헤더 줄

# 셀의 좌상단 타일 좌표(픽셀). 헤더 줄(맨 위 1줄)을 비워 열 제목을 둔다.
func _cell_origin(row: int, col: int) -> Vector2:
	var tx := MARGIN + col * CELL_W
	var ty := MARGIN + 1 + row * CELL_H
	return Vector2(tx * TILE, ty * TILE)

func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(_cols() * TILE * 0.5, _rows() * TILE * 0.5)
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
	var total := _crops.size() * STAGES.size()
	var loaded := total - _missing.size()
	var status := "P2.2 작물 미리보기 — %d/%d 로드" % [loaded, total]
	if not _missing.is_empty():
		status += "  · 없음: " + ", ".join(_missing)
	_label.text = status + "\n행=작물(혼령초·피안화·영혼호박)  열=씨앗→새싹→수확가능  G=격자  R=리로드"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_grid = not _grid
			queue_redraw()
		elif event.keycode == KEY_R:
			get_tree().reload_current_scene()

func _draw() -> void:
	# 1) 바닥: 전부 밭흙(작물이 심긴 밭). 폴백색 = 그레이박스 밭흙 톤.
	for y in _rows():
		for x in _cols():
			var pos := Vector2(x * TILE, y * TILE)
			if _soil:
				draw_texture(_soil, pos)
			else:
				draw_rect(Rect2(pos, Vector2(TILE, TILE)), Color(0.31, 0.25, 0.20))
	# 2) 작물 그리드 — 각 셀 바닥에 스프라이트 발 맞춤(키 큰 작물도 바닥정렬)
	for r in _crops.size():
		var crop: Dictionary = _crops[r]
		var stages: Array = crop["stages"]
		for c in STAGES.size():
			var origin := _cell_origin(r, c)
			var foot := Vector2(origin.x + CELL_W * TILE * 0.5, origin.y + CELL_H * TILE - TILE * 0.5)
			var tex: Texture2D = stages[c] if c < stages.size() else null
			if tex:
				draw_texture(tex, Vector2(foot.x - tex.get_width() * 0.5, foot.y - tex.get_height()))
			else:
				# 폴백: 단계별 그레이박스(씨앗 갈색→새싹 초록→수확 채도색)
				var fc: Color = [Color(0.30, 0.26, 0.18), Color(0.40, 0.62, 0.34), Color(0.86, 0.74, 0.30)][c]
				draw_rect(Rect2(foot + Vector2(-TILE * 0.5, -TILE), Vector2(TILE, TILE)), fc)
	# 3) 픽셀 격자(정수배 정렬 확인)
	if _grid:
		var col := Color(1, 1, 1, 0.12)
		for x in _cols() + 1:
			draw_line(Vector2(x * TILE, 0), Vector2(x * TILE, _rows() * TILE), col)
		for y in _rows() + 1:
			draw_line(Vector2(0, y * TILE), Vector2(_cols() * TILE, y * TILE), col)
