extends Node2D
# T1.3 — 캐릭터 이동/충돌 검증 씬(그레이박스).
#
# 목적: 회색 격자 위에서 회색 캐릭터가 4방향(대각선 포함)으로 부드럽게 움직이고
#       벽을 통과하지 못하는지를 "눈으로" 확인한다. 회색 도형만(ADR-0001).
# 규격: 내부해상도 320×180 · 타일 16px(ADR-0003).
#
# 보는 법:
#   - 방향키로 이동. 대각선으로 가도 속도가 빨라지지 않는다(정규화).
#   - 화면 4변 경계벽과 내부 장애물에 부딪치면 멈추거나 벽을 따라 미끄러진다.
#   - 좌상단 readout에 현재 위치/FPS가 표시된다.
#
# 메모: 여기 벽은 충돌 검증용 임시 도형이다. 본격 타일맵 더미 맵은 T1.4에서 만든다.

const BASE_SIZE := Vector2i(320, 180)  # 내부 해상도(ADR-0003)
const TILE := 16                       # 타일 한 칸 = 16×16 px(ADR-0003)
const WALL_THICK := 8

# 충돌 테스트용 벽 배치(Rect2: x, y, w, h). 화면 경계 4변 + 내부 장애물 몇 개.
var _walls: Array[Rect2] = [
	# 화면 4변 경계 — 캐릭터가 화면 밖으로 나가지 못하게
	Rect2(0, 0, BASE_SIZE.x, WALL_THICK),
	Rect2(0, BASE_SIZE.y - WALL_THICK, BASE_SIZE.x, WALL_THICK),
	Rect2(0, 0, WALL_THICK, BASE_SIZE.y),
	Rect2(BASE_SIZE.x - WALL_THICK, 0, WALL_THICK, BASE_SIZE.y),
	# 내부 장애물 — 통과 불가 + 벽 미끄러짐 확인용
	Rect2(96, 48, 48, 16),
	Rect2(176, 80, 16, 64),
	Rect2(64, 120, 80, 16),
]

@onready var player: CharacterBody2D = $Player
@onready var readout: Label = $CanvasLayer/Readout

func _ready() -> void:
	_build_walls()

func _build_walls() -> void:
	# 벽 데이터를 실제 정적 충돌체로 생성한다(시각 표현은 _draw가 담당).
	for r in _walls:
		var body := StaticBody2D.new()
		body.position = r.position + r.size * 0.5  # 사각형 충돌은 중심 기준
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		col.shape = shape
		body.add_child(col)
		add_child(body)

func _process(_delta: float) -> void:
	var p := player.global_position
	readout.text = "이동: 방향키   위치 (%d, %d)   FPS %d" % [
		int(p.x), int(p.y), Engine.get_frames_per_second()
	]

func _draw() -> void:
	# 바닥 — 격자선이 보이도록 어두운 배경을 깐다
	draw_rect(Rect2(Vector2.ZERO, BASE_SIZE), Color(0.10, 0.10, 0.12))
	# 16×16 격자 — 이동량을 눈으로 가늠하는 배경
	for x in range(0, BASE_SIZE.x + 1, TILE):
		draw_line(Vector2(x, 0), Vector2(x, BASE_SIZE.y), Color(0.20, 0.20, 0.23))
	for y in range(0, BASE_SIZE.y + 1, TILE):
		draw_line(Vector2(0, y), Vector2(BASE_SIZE.x, y), Color(0.20, 0.20, 0.23))
	# 벽 — 밝은 회색 채움
	for r in _walls:
		draw_rect(r, Color(0.40, 0.40, 0.45))
