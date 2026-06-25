extends SceneTree

# ★ ADR-0025 ① 인게임 배치 모드 로직 검증(헤드리스 — 마우스 이벤트 없이 함수 직접 호출).
#
# 무엇을 보나(메모리 상 _prop_layouts 조작만 — 파일은 안 건드림, prop_layout_test의 파일≡시드 보존):
#   ① _edit_key() = 현재 구역의 편집 묶음(부팅 HOME → "HOME").
#   ② 놓기 — _edit_place_new가 팔레트 텍스처로 새 엔트리를 추가(엔트리 +1·tex·좌표 일치).
#   ③ 선택 — _edit_pick이 그 칸을 덮는 (entry, tile)을 찾는다.
#   ④ 드래그 — 좌표를 갱신하면 _edit_pick이 새 칸에서 잡힌다.
#   ⑤ 삭제 — _edit_delete가 엔트리를 제거해 원복(누수 0)하고 그 칸은 더는 안 잡힌다.
#
# 좀비 방지: 모든 단언 뒤 quit(). 폴링 없음. run_tests.sh 워치독과 함께.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _initialize() -> void:
	print("══ 배치 모드 로직 검증 ══")
	var m: Node = await _spawn()
	m._edit_mode = true

	# ── ① 편집 묶음 키 ──
	_check("① _edit_key = HOME", m._edit_key() == "HOME")

	var home: Array = m._prop_layouts["HOME"]
	var n0: int = home.size()
	var fence_tex = m.PROP_TEX_REGISTRY["FENCE"]

	# ── ② 놓기(FENCE 팔레트를 (5,5)에 — 인덱스는 순서 무관하게 find) ──
	m._edit_palette = m._EDIT_PALETTE.find("FENCE")
	var spot := Vector2i(5, 5)
	m._edit_place_new(spot)
	home = m._prop_layouts["HOME"]
	_check("② 엔트리 +1", home.size() == n0 + 1)
	_check("② 새 엔트리 tex = FENCE", home[n0][0] == fence_tex)
	_check("② 새 엔트리 좌표 = (5,5)", home[n0][1][0] == spot)

	# ── ③ 선택(_edit_pick) ──
	var pick: Vector2i = m._edit_pick(spot)
	_check("③ _edit_pick이 새 엔트리 잡음", pick == Vector2i(n0, 0))

	# ── ④ 드래그(좌표 갱신 → 새 칸에서 잡힘) ──
	var moved := Vector2i(7, 9)
	m._prop_layouts["HOME"][n0][1][0] = moved
	_check("④ 옮긴 칸에서 잡힘", m._edit_pick(moved) == Vector2i(n0, 0))
	_check("④ 옛 칸은 안 잡힘", m._edit_pick(spot) == Vector2i(-1, -1))

	# ── ⑤ 삭제(원복) ──
	m._edit_sel_entry = n0
	m._edit_sel_tile = 0
	m._edit_delete()
	_check("⑤ 엔트리 원복(누수 0)", m._prop_layouts["HOME"].size() == n0)
	_check("⑤ 삭제한 칸 더는 안 잡힘", m._edit_pick(moved) == Vector2i(-1, -1))

	m.queue_free()
	await process_frame
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
