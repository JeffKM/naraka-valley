extends Control
class_name HudTooltip
# ADR-0048 Phase C(S1-13) — 마우스 호버 툴팁(핫바 슬롯 아이템명·품질).
#
# 목적: 핫바 슬롯에 마우스를 올리면 그 아이템의 이름(+품질 등급)을 커서 위에 작은 한지 톤 칩으로
#       띄운다(스타듀의 아이템 호버 툴팁). 코드 조작이 마우스라(ADR-0024) 슬롯 위 호버가 자연스럽다.
#
# 설계 메모:
#   - notice_feed·vitals와 같은 결: 코드 생성 자식 Control(무상태). 핫바(MOUSE_FILTER_IGNORE라 클릭을
#     안 잡음)의 슬롯 히트박스를 slot_index_at로 질의해 표시만 한다. 표시 텍스트/위치가 바뀔 때만 다시 그린다.
#   - 부모 CanvasLayer UI scale(×1.5)을 되돌려 논리 좌표(=640×360)에서 마우스·슬롯을 맞춘다
#     (viewport 마우스는 창 px라 scale로 나눠 논리 좌표로 변환 — 핫바 _view와 같은 함정 회피).
#   - 칩은 어두운 인셋 + 따뜻한 테두리 + 밝은 글자(다양한 배경 위 커서 옆이라 대비 우선).

var _hotbar: HotbarHud = null
var _inv: Inventory = null
var _text := ""
var _mouse := Vector2.ZERO   # 논리 좌표 마우스 위치

func setup(hotbar: HotbarHud, inventory: Inventory) -> void:
	_hotbar = hotbar
	_inv = inventory
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()

func _scale() -> float:
	var par := get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		return par.scale.x
	return 1.0

func _view() -> Vector2:
	var sc := _scale()
	return Vector2(size.x / sc, size.y / sc)

func _process(_dt: float) -> void:
	if _hotbar == null or _inv == null:
		return
	var logical := get_viewport().get_mouse_position() / _scale()
	var idx := _hotbar.slot_index_at(logical)
	var text := ""
	if idx >= 0:
		var id := _inv.id_at(idx)
		if id != "":
			text = ItemCatalog.name_of(id)
			var q := _inv.quality_at(idx)
			if q > 0:
				text = "%s · %s" % [text, ItemCatalog.quality_name(q)]
	# 텍스트가 바뀌거나(다른 슬롯) 표시 중 마우스가 움직이면 다시 그린다.
	if text != _text or (text != "" and logical.distance_squared_to(_mouse) > 1.0):
		_text = text
		_mouse = logical
		queue_redraw()

func _draw() -> void:
	if _text == "":
		return
	var view := _view()
	var font := HanjiUi.font()
	var fs := 13
	var tw := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pad := 8.0
	var w := tw + pad * 2.0
	var h := 22.0
	# 커서 위쪽에 띄우되 화면 밖으로 안 나가게 클램프.
	var x: float = clampf(_mouse.x - w * 0.5, 4.0, view.x - w - 4.0)
	var y: float = clampf(_mouse.y - h - 8.0, 4.0, view.y - h - 4.0)
	var rect := Rect2(x, y, w, h)
	draw_rect(rect, Color(HanjiUi.INSET.r, HanjiUi.INSET.g, HanjiUi.INSET.b, 0.92))
	draw_rect(rect, HanjiUi.BORDER, false, 1.0)
	HanjiUi.draw_text(self, Vector2(x + pad, y + 15.0), _text, fs, HanjiUi.INK_LIGHT)
