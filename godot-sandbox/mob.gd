extends Area2D
# 적(Mob) 노드. Player와 똑같이 Area2D + Polygon2D(빨간 네모) + CollisionShape2D 트리.
# main.gd가 Timer 시그널을 받을 때마다 이 씬을 인스턴스로 찍어 화면 위에서 떨어뜨린다.

@export var fall_speed: float = 220.0  # 픽셀/초

func _process(delta: float) -> void:
	# 매 프레임 아래로 fall_speed * delta 만큼 낙하(프레임 독립적).
	position.y += fall_speed * delta

	# 화면 아래로 완전히 벗어나면 스스로 제거 → 메모리 누수 방지.
	if position.y > get_viewport_rect().size.y + 50:
		queue_free()
