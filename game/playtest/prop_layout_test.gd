extends SceneTree

# ★ ADR-0025 ② PROP 좌표 데이터 외부화 멱등성 검증(회귀 0 잠금).
#
# 무엇을 보나:
#   ① 부팅 후 _prop_layouts가 세 묶음(HOME/CAFE/VILLAGE_HOUSE)으로 채워진다.
#   ② 멱등 이주 — 각 묶음의 런타임 데이터(_prop_layouts[k])가 시드 const(_SEED_LAYOUTS[k])와
#      텍스처·타일 좌표·yo까지 *완전 동등*하다(좌표만 데이터로 나갔을 뿐 값 변화 0 = 회귀 0 근거).
#   ③ 직렬화 라운드트립 안정 — _serialize_layouts(_prop_layouts) == _serialize_layouts(_SEED_LAYOUTS).
#   ④ layout.json 파일이 존재하고 다시 파싱된다(진실의 원천 왕복).
#   ⑤ 등불 빛 좌표 불변 — LANTERN_TILES_HOME은 코드 상수 그대로(데이터는 *위치 사본*만, 빛은 코드).
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

# 두 묶음 배열([[tex,[Vector2i...],yo?],...])이 텍스처·타일·yo까지 동등한가.
func _layouts_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var ea: Array = a[i]
		var eb: Array = b[i]
		if ea[0] != eb[0]:
			return false
		var ta: Array = ea[1]
		var tb: Array = eb[1]
		if ta.size() != tb.size():
			return false
		for j in ta.size():
			if ta[j] != tb[j]:
				return false
		var ya: int = ea[2] if ea.size() > 2 else 0
		var yb: int = eb[2] if eb.size() > 2 else 0
		if ya != yb:
			return false
	return true

func _initialize() -> void:
	print("══ PROP 좌표 외부화 멱등성 검증 ══")
	var m: Node = await _spawn()

	# ── ① 세 묶음 로드됨 ──
	_check("① HOME 묶음 존재", m._prop_layouts.has("HOME"))
	_check("① CAFE 묶음 존재", m._prop_layouts.has("CAFE"))
	_check("① VILLAGE_HOUSE 묶음 존재", m._prop_layouts.has("VILLAGE_HOUSE"))

	# ── ② 멱등 이주(런타임 == 시드) ──
	_check("② HOME 런타임 ≡ 시드", _layouts_equal(m._prop_layouts["HOME"], m._SEED_LAYOUTS["HOME"]))
	_check("② CAFE 런타임 ≡ 시드", _layouts_equal(m._prop_layouts["CAFE"], m._SEED_LAYOUTS["CAFE"]))
	_check("② VILLAGE 런타임 ≡ 시드", _layouts_equal(m._prop_layouts["VILLAGE_HOUSE"], m._SEED_LAYOUTS["VILLAGE_HOUSE"]))

	# ── ③ 직렬화 라운드트립 안정 ──
	var s_run: Dictionary = m._serialize_layouts(m._prop_layouts)
	var s_seed: Dictionary = m._serialize_layouts(m._SEED_LAYOUTS)
	_check("③ 직렬화 동등(JSON 문자열)", JSON.stringify(s_run) == JSON.stringify(s_seed))

	# ── ④ layout.json 왕복 ──
	_check("④ layout.json 존재", FileAccess.file_exists(m.LAYOUT_PATH))
	if FileAccess.file_exists(m.LAYOUT_PATH):
		var f := FileAccess.open(m.LAYOUT_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		_check("④ layout.json 재파싱 = Dictionary", parsed is Dictionary)
		# 파일 → 역직렬화 → 시드 동등(파일이 진실의 원천으로서 시드 재현)
		if parsed is Dictionary:
			var from_file: Dictionary = m._deserialize_layouts(parsed)
			_check("④ 파일 로드 ≡ 시드(HOME)", _layouts_equal(from_file["HOME"], m._SEED_LAYOUTS["HOME"]))

	# ── ⑤ 등불 빛 좌표는 코드 상수 그대로(데이터는 위치 사본만) ──
	_check("⑤ LANTERN_TILES_HOME 불변", m.LANTERN_TILES_HOME == [Vector2i(39, 17), Vector2i(45, 17)])

	m.queue_free()
	await process_frame
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
