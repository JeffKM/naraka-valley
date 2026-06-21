extends CharacterBody2D
# T1.3 — 그레이박스 플레이어 (16×32 회색 자리).
#
# 목적: 탑다운 4방향(대각선 포함) "부드러운" 이동 + 벽 충돌을 검증한다.
#       회색 도형만 사용한다(ADR-0001). 캐릭터 규격 16×32(ADR-0003).
# origin 규약: 노드 원점을 "발치 중앙"에 둔다. 탑다운 3/4뷰에서 깊이 정렬
#              (Y-sort)과 충돌 판정 기준을 발 위치로 잡는 게 자연스럽다.

const SPEED := 80.0                 # px/s. 그레이박스 기준값(약 5타일/초). 밸런싱은 후속.
const BODY_SIZE := Vector2(16, 32)  # 캐릭터 자리 규격(ADR-0003)

# 마지막으로 바라본 방향. 정지해도 유지되며, 방향 마커를 그리는 데 쓴다(이동 검증용).
var _facing := Vector2.DOWN
# P2.3② P2.1 도색 스프라이트. 있으면 그레이박스 대신 보여 주고 이동 시 워크 애니를 돌린다.
var _sprite: AnimatedSprite2D = null

func _ready() -> void:
	_sprite = CharSprite.make("res://assets/characters/player_walk.png")
	if _sprite != null:
		add_child(_sprite)
		_update_sprite(Vector2.ZERO)

func _physics_process(_delta: float) -> void:
	# get_vector는 대각선 입력을 자동으로 정규화한다 → 대각선이 더 빨라지는 버그 방지.
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED
	if dir != Vector2.ZERO and dir != _facing:
		_facing = dir
		queue_redraw()  # 방향이 바뀐 프레임에만 다시 그린다
	_update_sprite(dir)
	# move_and_slide: 벽에 닿으면 멈추고, 벽을 따라 미끄러진다(통과 불가).
	move_and_slide()

# 스프라이트를 현재 바라보는 방향에 맞춘다 — 이동 중이면 워크 애니 재생, 정지면 첫 프레임 정지.
func _update_sprite(dir: Vector2) -> void:
	if _sprite == null:
		return
	var anim := CharSprite.dir_anim(_facing)
	if dir != Vector2.ZERO:
		if _sprite.animation != anim or not _sprite.is_playing():
			_sprite.play(anim)
	else:
		_sprite.animation = anim
		_sprite.frame = 0
		_sprite.pause()

# 마지막으로 바라본 방향(정규화). 정지해도 유지된다.
# T2.1에서 main이 "바라보는 앞 칸"을 상호작용 대상으로 삼는 데 쓴다.
func get_facing() -> Vector2:
	return _facing

func _draw() -> void:
	if _sprite != null:
		return  # 도색 스프라이트가 있으면 그레이박스는 안 그린다(폴백 전용)
	# 몸체: 발치 원점 기준 위로 16×32 회색 사각형
	var body := Rect2(-BODY_SIZE.x * 0.5, -BODY_SIZE.y, BODY_SIZE.x, BODY_SIZE.y)
	draw_rect(body, Color(0.70, 0.70, 0.74))
	# 상단(머리) 약간 밝게 — 그레이박스 시인성
	draw_rect(Rect2(body.position, Vector2(BODY_SIZE.x, 10)), Color(0.82, 0.82, 0.86))
	# 바라보는 방향 마커(어두운 점) — 어느 쪽을 향하는지 눈으로 확인
	var head := Vector2(0, -BODY_SIZE.y + 5)
	draw_rect(Rect2(head + _facing * 4.0 - Vector2(1.5, 1.5), Vector2(3, 3)),
		Color(0.15, 0.15, 0.18))
