extends Node2D
# T1.2 — 320×180 정수배 스케일 뷰포트 "검증" 씬.
#
# 목적: 창 크기를 바꿔도 픽셀이 정수배(×2/×3/×4)로만 확대되고
#       가장자리 뭉개짐이 없는지를 "눈으로" 확인한다(ADR-0003 픽셀규격).
# 원칙: 회색 도형만 사용한다(ADR-0001 그레이박스).
#
# 보는 법:
#   - 창을 자유롭게 늘려보라. 체커보드 칸이 항상 "정확한 정사각형"으로,
#     대각선이 "또렷한 계단"으로 보이면 정수배 + Nearest 보간이 정상이다.
#   - 좌상단 readout의 "배율 x__"가 정수로만 바뀌고, 남는 공간은
#     레터박스(검은 띠)로 처리되면 stretch/scale_mode=integer가 작동 중이다.

const BASE_SIZE := Vector2i(320, 180)  # 내부 해상도(ADR-0003)
const TILE := 16                       # 타일 한 칸 = 16×16 px(ADR-0003)

@onready var readout: Label = $CanvasLayer/Readout

func _ready() -> void:
	# 창 크기가 바뀔 때마다 현재 적용 배율을 다시 계산해 표시
	get_window().size_changed.connect(_update_readout)
	_update_readout()

func _update_readout() -> void:
	var win := DisplayServer.window_get_size()
	# 정수배 스케일에서 실제 적용 배율 = (창 / 내부해상도)를 내림한 값
	var scale_factor := int(min(
		win.x / float(BASE_SIZE.x),
		win.y / float(BASE_SIZE.y)
	))
	readout.text = "내부 %dx%d   창 %dx%d   배율 x%d" % [
		BASE_SIZE.x, BASE_SIZE.y, win.x, win.y, scale_factor
	]

func _draw() -> void:
	# 1) 16×16 체커보드 — 정수배 + Nearest면 모든 칸이 정확한 정사각형으로 보인다
	var cols := int(ceil(BASE_SIZE.x / float(TILE)))
	var rows := int(ceil(BASE_SIZE.y / float(TILE)))
	for y in rows:
		for x in cols:
			var is_dark := (x + y) % 2 == 0
			var c := Color(0.18, 0.18, 0.20) if is_dark else Color(0.28, 0.28, 0.31)
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), c)

	# 2) 1px 외곽선 — 비정수 배율이면 변마다 두께가 달라져 바로 티가 난다
	draw_rect(Rect2(0.5, 0.5, BASE_SIZE.x - 1, BASE_SIZE.y - 1),
		Color(0.85, 0.85, 0.90), false, 1.0)

	# 3) 대각선 — 계단(에일리어싱) 패턴이 또렷하면 Nearest 보간이 정상.
	#    분수배 + 선형보간이면 여기가 가장 먼저 흐려진다.
	draw_line(Vector2.ZERO, Vector2(BASE_SIZE), Color(0.55, 0.85, 0.55), 1.0)
	draw_line(Vector2(BASE_SIZE.x, 0), Vector2(0, BASE_SIZE.y),
		Color(0.85, 0.55, 0.55), 1.0)
