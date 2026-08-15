extends Control
class_name IndoorMask
# 실내 카메라 격리 마스크 — 방(cam rect) 바깥을 검정으로 덮어 "집 안인데 집 밖이 보임"을 막는다.
#
# 왜 있나(코지-와이드 회귀): ADR-0018이 뷰포트를 640×360→960×540(30×17타일)로 키웠는데 실내
# 방·cam rect(예: 20×13타일)는 그대로라, 카메라 한계 범위가 뷰포트보다 작아진다. Godot Camera2D는
# 한계 범위가 화면보다 작으면 그 범위를 화면 *가운데 정렬*하고 남는 가장자리에 한계 밖(위쪽 외부
# 풀밭·옆 VOID·인접 방)을 노출한다. 실내 방들은 VOID 띠에 빽빽이 인접해서(집↔만물상·집↔카페)
# cam 한계를 넓히면 이웃 방이 샌다 → 한계 확장 대신 *바깥을 가린다*.
#
# 방식(순수 가산 — 카메라 한계·방 좌표·회귀 불변): 방의 월드 rect를 카메라 캔버스 변환으로 화면
# 좌표에 투영하고, 그 바깥 네 변을 검정으로 칠한다. 화면공간 CanvasLayer 자식이라 카메라가 방을
# 따라 움직이든(따라감) 가운데 고정이든(정렬) 항상 방 둘레만 남기고 검게 가린다. Stardew식 검은 여백.
#
# main이 매 프레임 실내일 때 world_rect_px(=방 cam rect 픽셀)와 active를 주입하고 redraw한다.

var world_rect_px := Rect2()   # 가릴 기준 = 방 cam rect의 월드 픽셀 rect
var active := false             # 실내일 때만 true(외부면 아무것도 안 그림)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 입력 가로채지 않음(HUD·월드 클릭 그대로)

# main이 실내 전환·매 프레임 호출. 방 rect가 바뀌거나 카메라가 움직이면 다시 그린다.
func set_room(active_now: bool, room_px: Rect2) -> void:
	active = active_now
	world_rect_px = room_px
	queue_redraw()

# 방 월드 rect를 **이 노드의 로컬 좌표**로 투영한다(가림막 네 변이 두르는 "구멍").
# 월드 → 화면(뷰포트 canvas_transform = 카메라) → 로컬(get_global_transform_with_canvas의 역).
# ★ 로컬로 되돌리는 게 필수인 이유(길드↔시련장 누출 버그): main.tscn의 CanvasLayer는 scale 1.5다
#   (640×360 논리 → 960×540 화면). 화면 픽셀을 로컬에 그대로 그리면 가림막이 1.5배로 부풀어
#   방의 오른쪽·아래 가림막이 화면 밖으로 밀려나고, 그 자리로 이웃 방이 통째로 드러난다.
# _draw와 회귀 테스트가 같은 식을 쓰도록 분리했다 — 보정이 빠지면 여기서 바로 드러난다.
func hole_rect_local() -> Rect2:
	var ct := get_viewport().get_canvas_transform()
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var tl := to_local * (ct * world_rect_px.position)
	var br := to_local * (ct * world_rect_px.end)
	return Rect2(tl, br - tl)

# 화면 끝을 같은 로컬 단위로(basis_xform = 원점 평행이동 제외한 순수 스케일·회전).
func screen_size_local() -> Vector2:
	return get_global_transform_with_canvas().affine_inverse().basis_xform(get_viewport_rect().size)

func _draw() -> void:
	if not active:
		return
	var hole := hole_rect_local()
	var tl := hole.position
	var br := hole.end
	var screen := screen_size_local()
	var black := Color(0.0, 0.0, 0.0, 1.0)
	# 방 바깥 네 변(겹치지 않게 위·아래는 전체 폭, 좌·우는 방 높이 구간만). 음수 폭/높이는 0으로.
	var top_h := clampf(tl.y, 0.0, screen.y)
	var bot_y := clampf(br.y, 0.0, screen.y)
	draw_rect(Rect2(0, 0, screen.x, top_h), black)                          # 위
	draw_rect(Rect2(0, bot_y, screen.x, screen.y - bot_y), black)           # 아래
	var lft_x := clampf(tl.x, 0.0, screen.x)
	var rgt_x := clampf(br.x, 0.0, screen.x)
	draw_rect(Rect2(0, top_h, lft_x, bot_y - top_h), black)                 # 좌
	draw_rect(Rect2(rgt_x, top_h, screen.x - rgt_x, bot_y - top_h), black)  # 우
