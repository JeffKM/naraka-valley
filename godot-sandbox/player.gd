extends Area2D
# ── 노드(Node) ──────────────────────────────────────────────
# 이 스크립트가 붙은 노드는 Area2D = "충돌 영역을 가진 부품".
# player.tscn에서 이 Area2D 아래에 자식으로:
#   - Box (Polygon2D)         → 겉모습(회색 네모)
#   - CollisionShape2D        → 실제 충돌 판정 모양
# 이렇게 [부품을 트리로 조립한 덩어리]가 곧 Player 씬이다.

# ── 시그널(Signal) ──────────────────────────────────────────
# "플레이어가 적과 부딪혔다"는 사건을 방송하는 커스텀 시그널.
# Player는 누가 이 방송을 듣는지 모른다(느슨한 결합).
# 실제로는 main.gd가 connect해서 듣고, 게임오버를 처리한다.
signal hit

@export var speed: float = 300.0  # 픽셀/초. 에디터 인스펙터에서 바꿔볼 수 있음(@export).
var screen_size: Vector2

func _ready() -> void:
	# _ready: 노드가 씬에 들어와 준비됐을 때 1번 호출.
	screen_size = get_viewport_rect().size
	# 내 충돌 영역에 "다른 Area2D"가 들어오면 _on_area_entered가 호출되도록 시그널 연결.
	# (적 Mob도 Area2D라서 겹치면 area_entered 시그널이 방출된다)
	area_entered.connect(_on_area_entered)

# ── _process(delta) ─────────────────────────────────────────
# 매 프레임 자동 호출되는 루프(심장박동). delta = 직전 프레임 이후 흐른 초.
func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1

	# 대각선이 더 빨라지지 않도록 방향 길이를 1로 정규화.
	if direction.length() > 0:
		direction = direction.normalized()

	# 핵심: speed * delta 를 곱한다.
	# → 프레임률이 흔들려도(60fps든 30fps든) 1초에 이동하는 거리는 항상 speed.
	#   delta를 안 곱하면 빠른 PC에서 순간이동하듯 빨라진다(프레임 종속).
	position += direction * speed * delta

	# 화면 밖으로 못 나가게 가둔다.
	position = position.clamp(Vector2.ZERO, screen_size)

func _on_area_entered(_area: Area2D) -> void:
	# 적과 부딪힘 → "hit" 시그널을 방출(emit)만 한다.
	# 실제 처리(게임오버)는 이 방송을 듣는 쪽(main.gd)의 몫.
	hit.emit()
