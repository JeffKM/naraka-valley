extends SceneTree

# ★[roster 2026-07-04] 나무 occlusion fade 격리 검증 — 캐릭터가 수관 뒤(스프라이트 rect 안 + 발치가
# 나무보다 위 = 나무가 앞)에 서면 _update_tree_fade가 그 나무 알파를 TREE_FADE_MIN으로 lerp하고,
# 벗어나면 1.0으로 돌아온다(스타듀식 반투명). 그리기 픽셀은 육안(실플레이)이 담당 — 여기선 상태 술어만.
# 좀비 방지: 모든 단언 뒤 quit(). run_tests.sh 워치독과 함께.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _init() -> void:
	print("══ [roster] 나무 occlusion fade 검증 ══")
	var m: Node = await _spawn_main()
	var TILE: int = m.TILE

	# layout.json HOME의 첫 나무 앵커를 집는다(시드=우상단 (54,3) 침엽).
	var anchor := Vector2i(-1, -1)
	var tex = null
	for entry in m._prop_layouts.get("HOME", []):
		if entry[0] in m.FADE_PROPS:
			anchor = entry[1][0]
			tex = entry[0]
			break
	_check("① 라이브 나무(FADE_PROPS) 인스턴스 존재", anchor.x >= 0)
	if anchor.x < 0:
		print("══ 결과: FAIL (실패 %d) ══" % _fail)
		quit(1)
		return

	var tsz: Vector2 = tex.get_size()
	_check("① 나무 크기 = 64×128(2×4칸)", is_equal_approx(tsz.x, 64.0) and is_equal_approx(tsz.y, 128.0))

	# 플레이어를 수관 뒤에 세운다: rect 중앙 x, 발치는 나무 발치(base)보다 위(=나무가 앞 패스).
	var rect := Rect2(Vector2(anchor.x * TILE, anchor.y * TILE), tsz)
	var base_y: float = m._prop_base_y(anchor, 0, tex)
	m.player.global_position = Vector2(rect.position.x + tsz.x * 0.5, base_y - TILE)  # 발치 한 칸 위(rect 안·base보다 위)
	_check("② 프로브 위치가 나무 rect 안(수관 뒤)", rect.has_point(m.player.global_position))
	_check("② 프로브 발치 < 나무 base(나무가 앞 패스)", m.player.global_position.y < base_y)

	# 여러 프레임 갱신 → 겹친 나무 알파가 TREE_FADE_MIN 쪽으로 내려간다.
	for i in range(30):
		m._update_tree_fade(0.1)
	var faded: float = m._tree_fade.get(anchor, 1.0)
	_check("③ 겹치면 알파가 내려감(< 1.0)", faded < 1.0)
	_check("③b 알파가 TREE_FADE_MIN에 수렴", is_equal_approx(faded, m.TREE_FADE_MIN))

	# 멀리 벗어나면(맵 밖 좌표) 알파가 1.0으로 복귀.
	m.player.global_position = Vector2(-9999, -9999)
	for i in range(30):
		m._update_tree_fade(0.1)
	var restored: float = m._tree_fade.get(anchor, 1.0)
	_check("④ 벗어나면 알파 1.0 복귀(불투명)", is_equal_approx(restored, 1.0))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
