extends Node2D
# ★[asset-ruleset §6] Y-Sort 프론트 프롭 오버레이 — main._draw는 *부모* 그리기라, 자식 노드인
# 플레이어(z0)가 항상 그 위에 그려진다(프롭이 늘 캐릭터 뒤로 깔림). 이 노드를 플레이어보다 높은
# z_index로 두고 "플레이어 발치보다 아래(=화면상 앞)에 있는 HOME 야외 프롭"만 여기서 다시 그려,
# 플레이어가 나무·바위 뒤로 자연스럽게 가려지게 한다.
# → [뒤 프롭(main._draw) → 플레이어 → 앞 프롭(여기)] 순서 = owner 잠금 수동 Y-split.
# 그리기 로직은 main이 단일 출처(_draw_front_props) — 이 노드는 z 레이어 셔틀일 뿐.
var host: Node2D = null

func _draw() -> void:
	if host != null:
		host._draw_front_props(self)   # self = 그리기 주체(draw_*가 이 노드에서 나가야 허용됨)
