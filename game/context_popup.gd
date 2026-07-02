extends Control
class_name ContextPopup
# ADR-0048 Phase C(S1-13) — 좌하단 컨텍스트 팝업(근처 NPC 초상화 + 한 줄).
#
# 목적: 플레이어가 주민을 마주 보면 좌하단에 그 인물의 초상화 + 이름 + 관계 한 줄을 태운 한지
#       프레임으로 띄운다(스타듀의 "지금 이 인물과 상호작용" 문맥 큐). 대화창(모달)과 별개의 상시
#       HUD — 대화를 열기 전에도 "누가 여기 있고 얼마나 친한가"를 보여 준다. "화면에 raw 패널 0"의
#       컨텍스트 파트.
#
# 설계 메모:
#   - notice_feed·vitals와 같은 결: 코드 생성 자식 Control(무상태). main이 매 프레임 set_target으로
#     대상(초상화·이름·줄)을 흘려넣고, 마주 본 NPC가 없으면 clear로 숨긴다. 값이 바뀔 때만 다시 그린다.
#   - 좌하단 코너(알림 피드 예약 영역 아래)에 놓아 알림 큐와 겹치지 않는다(notice RESERVE_BOTTOM=100).
#   - 초상화는 대화창과 같은 PORTRAIT 매핑을 쓴다(main이 idle 텍스처를 캐시해 주입 — 여기선 표시만).

const MARGIN := 8.0
const PAD := 9.0
const PORT := 46.0        # 초상화 한 변(px)
const W := 214.0          # 프레임 폭
# 하단 핫바(전폭·상단 y≈view.y-48)를 피해 팝업을 그 *위*에 얹는다. 이 값만큼 화면 바닥에서 띄운다.
# 알림 피드는 이 팝업 위로 다시 쌓인다(notice_feed.RESERVE_BOTTOM — 3단: 팝업→알림→핫바).
const LIFT := 52.0

var _portrait: Texture2D = null
var _name := ""
var _line := ""

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

# main이 매 프레임 호출. 대상이 바뀔 때만 다시 그린다. 이름·줄이 모두 비면 숨김(clear와 동일).
func set_target(portrait: Texture2D, char_name: String, line: String) -> void:
	if portrait == _portrait and char_name == _name and line == _line:
		return
	_portrait = portrait
	_name = char_name
	_line = line
	queue_redraw()

func clear() -> void:
	set_target(null, "", "")

func _view() -> Vector2:
	var sc := 1.0
	var par := get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		sc = par.scale.x
	return Vector2(size.x / sc, size.y / sc)

func _draw() -> void:
	if _name == "" and _line == "":
		return
	var view := _view()
	var h := PAD * 2.0 + PORT
	var frame := Rect2(MARGIN, view.y - h - LIFT, W, h)
	HanjiUi.draw_frame(self, frame)
	var px := frame.position.x + PAD
	var py := frame.position.y + PAD
	# 초상화(어두운 인셋 판 위에 이미지). 없으면 인셋만(이름·줄은 그대로).
	draw_rect(Rect2(px, py, PORT, PORT), HanjiUi.INSET)
	if _portrait != null:
		draw_texture_rect(_portrait, Rect2(px, py, PORT, PORT), false)
	draw_rect(Rect2(px, py, PORT, PORT), HanjiUi.BORDER, false, 1.0)
	# 이름(먹빛 표제) + 관계 한 줄(보조 먹빛). 밝은 한지 프레임 위라 어두운 글자로 대비.
	var tx := px + PORT + 10.0
	var text_w := frame.end.x - PAD - tx
	HanjiUi.draw_text(self, Vector2(tx, py + 18.0), _name, 15, HanjiUi.INK, text_w)
	if _line != "":
		HanjiUi.draw_text(self, Vector2(tx, py + 40.0), _line, 12,
			Color(0.34, 0.26, 0.18), text_w)
