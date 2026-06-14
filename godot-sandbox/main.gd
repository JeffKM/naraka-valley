extends Node2D
# ── 노드(Node) 조립의 최상위 ────────────────────────────────
# main.tscn은 여러 씬/노드를 조립한 무대다:
#   - Player (player.tscn 인스턴스)  → 씬을 부품처럼 다시 사용
#   - MobTimer (Timer)               → 일정 간격 사건 발생기
#   - ScoreTimer (Timer)             → 점수 누적용
#   - CanvasLayer/ScoreLabel (Label) → 화면 위 고정 UI

# 적 Mob 씬을 통째로 들고 있다가 필요할 때 인스턴스로 찍어낸다.
@export var mob_scene: PackedScene

var score: int = 0
var alive: bool = true

func _ready() -> void:
	# ── 시그널(Signal) 연결 ─────────────────────────────────
	# Timer가 "시간 다 됐다(timeout)"를 방송하면 적을 스폰한다.
	$MobTimer.timeout.connect(_on_mob_timer_timeout)
	# 1초마다 점수 +1.
	$ScoreTimer.timeout.connect(_on_score_timer_timeout)
	# Player가 커스텀 "hit" 시그널을 방송하면 게임오버 처리.
	# → main은 충돌을 직접 검사하지 않는다. Player의 방송을 듣기만 한다(느슨한 결합).
	$Player.hit.connect(_on_player_hit)

	$MobTimer.start()
	$ScoreTimer.start()
	_update_label()

func _on_mob_timer_timeout() -> void:
	if not alive:
		return
	# PackedScene.instantiate() → 씬을 실제 노드로 찍어낸다.
	var mob := mob_scene.instantiate()
	var w := get_viewport_rect().size.x
	# 화면 위쪽(y=-30), 랜덤 x 위치에서 출발.
	mob.position = Vector2(randf_range(20, w - 20), -30)
	add_child(mob)  # 무대에 올려야 _process가 돌기 시작.

func _on_score_timer_timeout() -> void:
	if alive:
		score += 1
		_update_label()

func _on_player_hit() -> void:
	alive = false
	$MobTimer.stop()
	_update_label()

func _update_label() -> void:
	if alive:
		$CanvasLayer/ScoreLabel.text = "SCORE: %d" % score
	else:
		$CanvasLayer/ScoreLabel.text = "GAME OVER — SCORE: %d   (Enter/Space: 재시작)" % score

func _input(event: InputEvent) -> void:
	# 게임오버 상태에서 Enter/Space를 누르면 씬 전체를 다시 불러와 재시작.
	if not alive and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()
