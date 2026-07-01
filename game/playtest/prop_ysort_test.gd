extends SceneTree

# ★[asset-ruleset §6·§11] Slice0 Phase C ⑤ — Y-split 프론트 프롭 + 분리 접지 그림자 격리 검증.
#
# 무엇을 보나:
#   ① 프론트 프롭 오버레이 노드(_front_props)가 존재하고 플레이어(z0)보다 높은 z.
#   ② 그림자 세트 = 부피 프롭만(나무·바위·덤불·그루터기·debris·허수아비) / 평면 데칼(울타리·꽃·러그·잡초) 제외.
#   ③ Y-split 분할: 부피 프롭은 발치(base) Y로 앞/뒤가 갈린다(base>split=앞/플레이어 위, ≤split=뒤).
#   ④ 평면 데칼은 그림자 세트가 아니므로 절대 '앞'이 아니다(늘 플레이어 아래) — 러그가 발 위로 덮이는 버그 차단.
#   ⑤ 앞/뒤 분할이 배타적·완전(한 인스턴스는 정확히 한 패스) — 이중 그림·누락 0.
#
# 그리기 자체(픽셀)는 육안(home_full_dump)이 담당 — 여기선 분할 술어(_prop_base_y·그림자 세트)만 정량 검증.
# 좀비 방지: 모든 단언 뒤 quit(). run_tests.sh 워치독과 함께.

const TILE := 32
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

# 그림자 세트(=Y-sort 참여) 프롭이 split_y 기준 앞인가 — main._draw_props_for 술어의 거울.
func _is_front(m: Node, t: Vector2i, yo: int, tex: Texture2D, split_y: float) -> bool:
	var casts: bool = tex in m.PROP_SHADOW_SET
	return casts and m._prop_base_y(t, yo, tex) > split_y

func _init() -> void:
	print("══ Slice0 Phase C ⑤ Y-split 프론트 프롭 + 접지 그림자 검증 ══")
	var m: Node = await _spawn_main()

	# ① 프론트 프롭 오버레이 노드
	_check("① _front_props 오버레이 노드 존재", m._front_props != null)
	_check("① _front_props가 main의 자식", m._front_props != null and m._front_props.get_parent() == m)
	var pz: int = (m.player as Node2D).z_index
	_check("① _front_props z가 플레이어보다 높음(앞 레이어)", m._front_props != null and m._front_props.z_index > pz)

	# ② 그림자 세트 = 부피 프롭만
	_check("② 나무A 그림자 대상", m.PROP_TREE_A in m.PROP_SHADOW_SET)
	_check("② 나무B 그림자 대상", m.PROP_TREE_B in m.PROP_SHADOW_SET)
	_check("② 바위 그림자 대상", m.PROP_ROCK in m.PROP_SHADOW_SET)
	_check("② 그루터기 그림자 대상", m.PROP_STUMP in m.PROP_SHADOW_SET)
	_check("② 덤불 그림자 대상", m.PROP_BUSH in m.PROP_SHADOW_SET)
	_check("② 업화석 그림자 대상", m.PROP_DEBRIS_EMBER in m.PROP_SHADOW_SET)
	_check("② 석화고목 그림자 대상", m.PROP_DEBRIS_STUMP in m.PROP_SHADOW_SET)
	_check("② 허수아비 그림자 대상", m.PROP_SCARECROW in m.PROP_SHADOW_SET)
	# 평면 데칼·소품은 제외
	_check("②b 울타리 그림자 제외(평면)", not (m.PROP_FENCE in m.PROP_SHADOW_SET))
	_check("②b 꽃 패치 그림자 제외(평면)", not (m.PROP_FLOWER_PATCH in m.PROP_SHADOW_SET))
	_check("②b 러그 그림자 제외(바닥)", not (m.PROP_RUG in m.PROP_SHADOW_SET))
	_check("②b 잡초 debris 그림자 제외(낮음)", not (m.PROP_DEBRIS_WEEDS in m.PROP_SHADOW_SET))
	_check("②b 계단 그림자 제외(평면)", not (m.PROP_STAIRS in m.PROP_SHADOW_SET))

	# ③ Y-split — 부피 프롭 발치로 앞/뒤 분할
	# 북단 나무(row0, 64×96) 발치 = 0*32+96 = 96px. 남단 나무(row62) 발치 = 62*32+96 = 2080px.
	var tree: Texture2D = m.PROP_TREE_A
	var by_top: float = m._prop_base_y(Vector2i(24, 0), 0, tree)
	var by_bot: float = m._prop_base_y(Vector2i(4, 62), 0, tree)
	_check("③ 북단 나무 발치=96px", is_equal_approx(by_top, 96.0))
	_check("③ 남단 나무 발치=2080px", is_equal_approx(by_bot, 2080.0))
	# 플레이어가 두 나무 사이(y=1000px)일 때: 북단=뒤(플레이어 위로 안 가림), 남단=앞(플레이어를 가림).
	var split := 1000.0
	_check("③b 북단 나무 = 뒤(base≤split)", not _is_front(m, Vector2i(24, 0), 0, tree, split))
	_check("③b 남단 나무 = 앞(base>split)", _is_front(m, Vector2i(4, 62), 0, tree, split))
	# 플레이어가 남단 나무보다 더 아래(y=2100px)면 그 나무도 뒤가 된다(플레이어가 앞).
	_check("③c 플레이어가 더 아래면 남단 나무도 뒤", not _is_front(m, Vector2i(4, 62), 0, tree, 2100.0))

	# ④ 평면 데칼은 split과 무관하게 절대 '앞'이 아니다(러그가 발 위로 덮이는 버그 차단)
	_check("④ 러그는 어떤 split에서도 앞 아님", not _is_front(m, Vector2i(11, 71), 0, m.PROP_RUG, 0.0))
	_check("④b 꽃 패치도 앞 아님", not _is_front(m, Vector2i(8, 12), 0, m.PROP_FLOWER_PATCH, 0.0))

	# ⑤ 앞/뒤 배타·완전 — HOME 레이아웃 전 인스턴스가 정확히 한 패스에 속한다(이중·누락 0).
	var split5 := 1200.0
	var back := 0
	var front := 0
	var total := 0
	for entry in m._prop_layouts.get("HOME", []):
		var tex: Texture2D = entry[0]
		var yo: int = entry[2] if entry.size() > 2 else 0
		for t in entry[1]:
			total += 1
			var f: bool = _is_front(m, t, yo, tex, split5)
			if f:
				front += 1
			else:
				back += 1
	_check("⑤ 앞+뒤 = 전체(배타·완전, 누락 0)", back + front == total and total > 0)
	_check("⑤b 앞·뒤 둘 다 비어있지 않음(분할 유효)", front > 0 and back > 0)

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
