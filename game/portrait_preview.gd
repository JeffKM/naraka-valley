extends Node2D
# 대화용 초상화 미리보기 하네스 (글루, ADR-0001 허용) — ADR-0003 "표정은 별도 일러스트 초상화".
# 인게임 도트(작은 실루엣)와 달리 얼굴을 또렷하게 살리는 자리. 가짜 대화창에 초상화+이름+대사를 띄운다.
# 사용: godot --path <game> res://portrait_preview.tscn  (또는 에디터 F6)
# 조작: ←/→ 또는 Space=다음 캐릭터 · R=리로드

const PORTRAITS := "res://assets/portraits/"

# [표시이름, 파일stem, 샘플 대사]
const CAST := [
	["미호", "miho", "오늘 밭일 도와줄래? 여우불로 쑥쑥 키워줄게!"],
	["옥자", "okja", "왔구나. …앉아. 차는 내가 우려줄 테니."],
	["바나", "bana", "밤엔 내가 지켜. 넌 신경 쓰지 마."],
	["멜", "mel", "장부는 거짓말 안 해. 출하대 위에 올려."],
]

const VIEW := Vector2(320, 180)   # 내부해상도(ADR-0003)
const PORTRAIT_BOX := 132.0       # 초상화 표시 한 변(내부해상도 기준)

var _idx := 0
var _portrait := Sprite2D.new()
var _name := Label.new()
var _line := Label.new()
var _hud := Label.new()
var _missing: Array[String] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cam := Camera2D.new()
	cam.position = VIEW * 0.5
	add_child(cam)
	cam.make_current()

	add_child(_portrait)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # 일러스트는 보간 허용(도트 아님)
	_portrait.centered = true

	var cl := CanvasLayer.new()
	add_child(cl)
	cl.add_child(_name)
	cl.add_child(_line)
	cl.add_child(_hud)
	_style(_name, 18, Color(1, 0.92, 0.78))
	_style(_line, 14, Color.WHITE)
	_style(_hud, 12, Color(0.8, 0.85, 0.95))
	_name.position = Vector2(150, 96)
	_line.position = Vector2(150, 120)
	_line.size = Vector2(150, 50)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.position = Vector2(6, 4)
	_show(0)

func _style(lb: Label, sz: int, col: Color) -> void:
	lb.add_theme_font_size_override("font_size", sz)
	lb.add_theme_color_override("font_color", col)
	lb.add_theme_color_override("font_outline_color", Color.BLACK)
	lb.add_theme_constant_override("outline_size", 5)

func _show(i: int) -> void:
	_idx = (i + CAST.size()) % CAST.size()
	var nm: String = CAST[_idx][0]
	var stem: String = CAST[_idx][1]
	var path := PORTRAITS + stem + ".png"
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		_portrait.texture = tex
		# PORTRAIT_BOX 한 변에 맞춰 contain
		var s: float = PORTRAIT_BOX / float(maxi(tex.get_width(), tex.get_height()))
		_portrait.scale = Vector2(s, s)
		_portrait.position = Vector2(82, 96)
	else:
		_portrait.texture = null
		if not _missing.has(stem):
			_missing.append(stem)
	_name.text = nm
	_line.text = CAST[_idx][2]
	var note := "" if _missing.is_empty() else "  · 없음: " + ", ".join(_missing)
	_hud.text = "초상화 미리보기 %d/%d%s\n←/→ 또는 Space=다음  R=리로드" % [_idx + 1, CAST.size(), note]
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT, KEY_SPACE:
				_show(_idx + 1)
			KEY_LEFT:
				_show(_idx - 1)
			KEY_R:
				get_tree().reload_current_scene()

func _draw() -> void:
	# 저승 톤 배경
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.10, 0.09, 0.13))
	# 대화창 패널
	var box := Rect2(Vector2(8, 86), Vector2(304, 86))
	draw_rect(box, Color(0.06, 0.05, 0.09, 0.92))
	draw_rect(box, Color(0.45, 0.40, 0.30), false, 2.0)
	# 초상화 받침 프레임
	draw_rect(Rect2(Vector2(14, 18), Vector2(PORTRAIT_BOX + 4, PORTRAIT_BOX + 4)), Color(0.45, 0.40, 0.30), false, 2.0)
