extends Node2D
# 나라카 대화창 룩 프로토타입 하네스 (글루, ADR-0001 허용) — 「태운 한지」.
# owner 제미나이 윈도우 아트(dialog_window.png) 1장을 배경으로 깔고, 측정한 내부 칸에
# 초상화·본문·이름을 오버레이한다. main.gd/테스트는 안 건드림.
# 사용: bash run_portraits.sh  ·  헤드리스: godot --path game -s res://tools/dialog_dump.gd --resolution 960x540
# 조작: ←/→ 또는 Space=다음 · R=리로드

const PORTRAITS := "res://assets/portraits/"
const FONT := "res://assets/fonts/neodgm.ttf"
const WINDOW_TEX := "res://assets/ui/dialog_window.png"

const CAST := [
	["미호", "miho", "오늘 밭일 도와줄래? 여우불로 쑥쑥 키워줄게!"],
	["옥자", "okja", "왔구나. …앉아. 차는 내가 우려줄 테니."],
	["바나", "bana", "밤엔 내가 지켜. 넌 신경 쓰지 마."],
	["멜", "mel", "장부는 거짓말 안 해. 출하대 위에 올려."],
]

const BG_DARK := Color(0.09, 0.075, 0.11)
const INK := Color(0.16, 0.12, 0.085)      # 먹빛 본문
const NAME_INK := Color(0.20, 0.14, 0.09)  # 이름(먹빛, 이름판 위)

# ── 윈도우 배치(640×360 논리, CanvasLayer scale 1.5) ──
const WINDOW := Rect2(16, 172, 608, 176)
# 내부 칸 = 윈도우 대비 비율(측정값, dialog_window.png 3423×991 기준)
const F_TEXT := Rect2(0.0523, 0.1372, 0.6675, 0.7306)
const F_PORT := Rect2(0.7844, 0.1423, 0.1545, 0.5519)
const F_NAME := Rect2(0.7645, 0.7830, 0.1952, 0.1151)

var _idx := 0
var _font: FontFile = null
var _ui := CanvasLayer.new()
var _portrait := TextureRect.new()
var _line := Label.new()
var _name := Label.new()
var _hud := Label.new()

func _frac(f: Rect2) -> Rect2:
	return Rect2(WINDOW.position + f.position * WINDOW.size, f.size * WINDOW.size)

func _win_rect(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = WINDOW.position
	t.size = WINDOW.size
	return t

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(FONT):
		_font = load(FONT)

	var bg := CanvasLayer.new()
	add_child(bg)
	var rect := ColorRect.new()
	rect.color = BG_DARK
	rect.size = Vector2(960, 540)
	bg.add_child(rect)

	add_child(_ui)
	_ui.scale = Vector2(1.5, 1.5)

	var wtex := load(WINDOW_TEX) as Texture2D

	# 창 그림자(입체감) — 같은 실루엣을 검게, 살짝 오프셋해 뒤에 깐다
	var shadow := _win_rect(wtex)
	shadow.position += Vector2(4, 6)
	shadow.modulate = Color(0, 0, 0, 0.32)
	_ui.add_child(shadow)

	# 윈도우 아트(일러스트 → 보간)
	_ui.add_child(_win_rect(wtex))

	# 초상화(우 정사각 칸) — 여백(매팅) 넣어 프레임에 안 붙게
	var pr := _frac(F_PORT).grow(-5)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.position = pr.position
	_portrait.size = pr.size
	_ui.add_child(_portrait)

	# 본문(좌 텍스트칸, 안쪽 여백)
	var tr := _frac(F_TEXT)
	_line.position = tr.position + Vector2(10, 6)
	_line.size = tr.size - Vector2(20, 12)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style(_line, 15, INK)
	_ui.add_child(_line)

	# 이름(이름판, 가운데)
	var nr := _frac(F_NAME)
	_name.position = nr.position
	_name.size = nr.size
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style(_name, 13, NAME_INK)
	_ui.add_child(_name)

	# 다음 화살표 — 수묵 먹 톤(붓 느낌, 한지에 스민 듯). 실게임선 위아래 살짝 tween.
	var arrow := TextureRect.new()
	arrow.texture = load("res://assets/ui/ink_arrow.png")
	arrow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	arrow.position = tr.position + tr.size - Vector2(22, 20)
	_ui.add_child(arrow)

	var cl := CanvasLayer.new()
	add_child(cl)
	_hud.position = Vector2(8, 6)
	_style(_hud, 9, Color(0.7, 0.72, 0.8))
	cl.add_child(_hud)

	_show(0)

func _style(lb: Label, sz: int, col: Color) -> void:
	if _font:
		lb.add_theme_font_override("font", _font)
	lb.add_theme_font_size_override("font_size", sz)
	lb.add_theme_color_override("font_color", col)

func _show(i: int) -> void:
	_idx = (i + CAST.size()) % CAST.size()
	var stem: String = CAST[_idx][1]
	var path := PORTRAITS + stem + ".png"
	_portrait.texture = (load(path) as Texture2D) if ResourceLoader.exists(path) else null
	_name.text = CAST[_idx][0]
	_line.text = CAST[_idx][2]
	_hud.text = "대화창 룩 프로토타입 %d/%d  ←/→=다음  R=리로드" % [_idx + 1, CAST.size()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT, KEY_SPACE:
				_show(_idx + 1)
			KEY_LEFT:
				_show(_idx - 1)
			KEY_R:
				get_tree().reload_current_scene()
