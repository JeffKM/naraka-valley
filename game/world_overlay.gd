extends Node2D
# ★[폴리시 R18 #16] 풀스크린 월드 오버레이 z 셔틀 — `front_props.gd`와 **같은 결·같은 이유**다.
#
# main._draw는 *부모* 그리기라 자식 노드가 언제나 그 위에 그려진다(main.gd 자신이 못 박은 규칙).
# 그런데 B5 내면 공간(`_draw_spine_puzzle`)과 B6/B7 S등급 일러스트(`_draw_illust`)는 화면을
# 통째로 덮어야 하는 그림인데 main의 `_draw`에서 나가, 세 자식이 그 먹 사각 **위에** 남았다:
#   ㉠ 플레이어(z0) — 별자리 허브 한가운데 그대로 서 있었다
#   ㉡ 앞프롭(z1) — 미혹의 숲 캐노피 + 안개 원반이 암전 위에 떠 있었다
#   ㉢ 월드 라벨(z10) — "옥자 집 …"이 암전 위에 그대로 뜬다
# ADR-0068 결정 8·9가 "내면 공간이 화면을 통째로 덮으므로 세계가 한 프레임도 안 보인다"로 세운
# 연출 계약이 그 셋 때문에 성립하지 않았다. 라벨(z10)보다 위에 서면 셋 다 한 번에 덮인다.
#
# 그리기 로직은 main이 단일 출처(`_draw_world_overlays`) — 이 노드는 z 레이어 셔틀일 뿐이다.
#
# ★재그리기는 **자기 프레임으로 판다**(무효화 배선을 안 늘린다). 오버레이 상태를 바꾸는 자리가
#   여럿이라(별 집기·컷신 알파·페이드) main의 산발적 `queue_redraw`에 하나씩 얹으면 언젠가
#   한 자리가 빠져 유령 그림이 남는다(`_redraw_world` 머리말이 앞프롭에서 겪은 그 사고).
#   대신 오버레이가 서 있는 동안만 매 프레임 다시 그린다 — 그 구간은 어차피 연출이 흐르는
#   중이고, 안 서 있을 땐 `_draw`가 첫 줄에서 되돌아가므로 비용이 0이다.
#   `_was_on`은 **걷히는 프레임 한 번**을 위한 것이다(안 그리면 마지막 그림이 화면에 남는다).
var host: Node2D = null

var _was_on := false

func _process(_dt: float) -> void:
	var on: bool = host != null and host._world_overlay_active()
	if on or _was_on:
		queue_redraw()
	_was_on = on

func _draw() -> void:
	if host != null:
		host._draw_world_overlays(self)   # self = 그리기 주체(draw_*가 이 노드에서 나가야 허용됨)
