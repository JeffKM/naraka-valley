extends SceneTree
# ★[폴리시 14회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#13) + 배치 B(#14~#26).
#
# 렌즈: R13 diff 리뷰 · 서식 인자 · 약속↔이행 · 입력 맵 충돌 · 오디오-상태 짝 ·
#       노드 수명 · 설정 왕복 · 표시 진실성.
#
# 무엇을 보증하나(번호 = 14회차 헌트 발견 인덱스):
#   ① #0 R13이 안식 채취기의 **그림만** 밑동으로 내리고 상호작용·프롬프트는 앵커 칸에 둬,
#        통이 그려진 자리를 마주 보고 [F]를 눌러도 아무 일이 없었다(수거하려면 통이 한 조각도
#        없는 3칸 북쪽 캐노피 꼭대기를 겨눠야 했다). 원장·세이브 키는 그대로 두고 **겨눈 칸을
#        앵커로 되돌리는 다리**(`_tapper_ledger_tile`)를 입력·프롬프트 두 사슬에 함께 세웠다.
#   ② #1 `_close_spine_puzzle`이 『정지 주인 ≠ 재개 주인』 계약의 마지막 미봉합 자리였다 —
#        24:00 강제 취침 트윈 안에서 닫히면 시계 정지가 풀리고 완전 암전 뒤에서 이동이 켜졌다.
#   ③ #2·#3 이스케이프 안 된 `%`가 두 스위트의 단언 라벨을 통째로 "unsupported format
#        character"로 갈아치워, 회귀가 깨지는 날 어느 단언인지도 실측이 얼마인지도 못 말했다.
#   ④ #4 「큰 %s」 뒤 고정 조사 "을" — 넋둥우리(받침 없음) 분기에서 문법이 깨졌다. R5/R12 전수
#        가드의 정규식이 `」`가 낀 형태를 못 잡던 사각도 함께 좁혔다.
#   ⑤ #5 목공방 헤더가 한 프로젝트(큰 넋둥우리 2일)의 공기를 전 매대의 규칙인 양 광고했다 —
#        늘봄방은 실제 3일이고, 발주 직후 알림만 그 사실을 다르게 말했다.
#   ⑥ #6 미호 ♡1 편지가 본문으로 씨앗을 건네는데 첨부가 비어 있었다(R8 스윕이 놓친 네 번째 통).
#   ⑦ #7 관계 탭 "이번 주 선물 N/2"만 **잔여**를 분자에 넣어, 저장소의 다른 모든 X/Y(달성/총량)와
#        같은 화면에서 뜻이 정반대로 읽혔다.
#   ⑧ #8 도끼 3·4티어 벼리기 문구가 "더 굵은 것을 벨 수 있다"고 열리지 않는 접근을 약속했다.
#   ⑨ #9 제작 탭 헤더가 해금 축을 "채집 숙련" 하나로 단정했다 — 계단(채광)·상위 스프링클러(농사)는
#        채집 문턱이 0이라 만렙을 찍어도 안 열린다(바로 아래 잠금 행은 이미 사실을 말하고 있었다).
#   ⑩ #10 장원제 프롬프트가 곳간 전 종수를 보여 주는데 출품은 상위 9종에서 잘렸다 — 되돌릴 수
#        없는 하루 1회 래치 직전의 안내가 상한을 안 말했다.
#   ⑪⑫ #11(high)·#12 화면을 덮은 조회 오버레이(점괘 거울 예보 · 절기 달력) 위의 클릭이 월드로
#        새어, 집 안 우클릭 한 번에 하루가 통째로 소비되고(자동 저장이 굳힌다) 달력 격자 클릭이
#        도끼질로 나갔다.
#   ⑬ #13 집 꾸미기 모드(C)가 이동을 안 잠가, 문·워프 트리거가 얼어 있는 채 플레이어가 걸어
#        다니고 모드를 끄는 그 프레임에 얼어 있던 트리거가 한꺼번에 걸렸다.
#
# 배치 B(#14~#26)의 항목별 머리말은 아래 "배치 B" 구획에 있다(⑭~㉖).
#
# 판정: ①~⑬ + ⑭~㉕ = CONFIRMED, ㉖(#26) = #5 DUP(코드 무수정 — 배치 A 수리가 그 시나리오까지
#       덮는지 실측으로 확인한다). REFUTED·OWNER 없음. 배치 A 14건이 ⑬개 항목으로 묶이는 것은
#       #2·#3이 같은 결함 클래스라 ③ 한 항목이기 때문이고, 배치 B의 #18~#22는 같은 결함 클래스
#       (하네스 노드 수명)라 한 스캐너가 다섯 파일을 함께 잰다.
#
# 실행: ./run_tests.sh polish_r14   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _src: PackedStringArray = PackedStringArray()

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

# ── 소스 스캔 헬퍼(polish_r7~r13의 그 관례) ─────────────────────────────────
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _line_of(needle: String) -> int:
	for i in _src.size():
		if _src[i].contains(needle):
			return i
	return -1

func _in_func(fn_needle: String, needle: String) -> bool:
	var head := _line_of(fn_needle)
	if head < 0:
		return false
	for i in range(head + 1, _src.size()):
		if _src[i].begins_with("func "):
			return false
		if _src[i].contains(needle):
			return true
	return false

# ── ★③ 서식 스캐너 — 문자열 리터럴 하나에서 유효/무효 지시자를 센다 ────────────
# Godot `String.sprintf`는 `%`를 만나면 서식 모드로 들어가 플래그를 소비한 뒤 지시자를 읽는데,
# 그 자리에 지시자가 아닌 문자(한글 "로", 공백 뒤 "근" …)가 오면 **결과 전체**를 "unsupported
# format character"로 갈아 돌려준다 — 라벨도 실측값도 통째로 사라진다.
const _FMT_FLAGS := " -+0123456789.*"
const _FMT_SPECS := "diouxXfFeEgGscv"

func _scan_format(s: String) -> Vector2i:
	var good := 0
	var bad := 0
	var i := 0
	while i < s.length():
		if s[i] != "%":
			i += 1
			continue
		if i + 1 < s.length() and s[i + 1] == "%":
			i += 2                                # `%%` = 이스케이프된 리터럴 퍼센트
			continue
		var j := i + 1
		while j < s.length() and _FMT_FLAGS.contains(s[j]):
			j += 1
		if j < s.length() and _FMT_SPECS.contains(s[j]):
			good += 1
			i = j + 1
			continue
		bad += 1
		i += 1
	return Vector2i(good, bad)

# 한 줄에서 **주석 밖 문자열 리터럴**만 뽑는다(polish_r13 `_display_strings` 1:1).
func _display_strings(line: String) -> Array:
	var out: Array = []
	var in_str := false
	var cur := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "\\" and in_str:
			i += 2
			continue
		if c == "\"":
			if in_str:
				out.append(cur)
				cur = ""
			in_str = not in_str
		elif c == "#" and not in_str:
			break
		elif in_str:
			cur += c
		i += 1
	return out

# res:// 아래 모든 .gd 경로(재귀 — 분모 하드코딩 0).
func _all_gd_files(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			_all_gd_files(full, out)
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()


func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R14 회귀 — 배치 A(#0~#13) + 배치 B(#14~#26) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return

	_check_tapper_tile(m)
	_check_spine_close(m)
	_check_format_specs()
	_check_josa(m)
	_check_build_days(m)
	_check_letter_seed(m)
	_check_gift_rhythm(m)
	_check_axe_text(m)
	_check_craft_header(m)
	_check_grange_cap(m)
	_check_overlay_clicks(m)
	_check_deco_lock(m)
	# ── 배치 B(#14~#26) ──
	_check_edit_button_swallow(m)
	_check_authoring_modes_exclusive(m)
	_check_mute_reload(m)
	_check_b5_mute_intent(m)
	_check_harness_node_lifetime()
	_check_title_f11()
	_check_fullscreen_sync(m)
	_check_volume_floor(m)
	_check_greenhouse_days_dup(m)

	print("══ %s ══" % ("polish_r14_test 전체 통과" if _fail == 0 else "결과: FAIL (실패 %d)" % _fail))
	cleaner.delete_save()
	# ★[폴리시 R14] 이 파일이 ⑱~㉒로 강제하는 그 규약을 스스로도 지킨다(트리 밖 new() 직접 해제 ·
	#   무대로 세운 main도 함께 — 종료 시 ObjectDB 누수 경고 0).
	cleaner.free()
	m.queue_free()
	await process_frame
	quit(1 if _fail > 0 else 0)


# ── ① #0 안식 채취기 — 그려진 칸에서 [F]가 먹는다 ────────────────────────────
func _check_tapper_tile(m: Node) -> void:
	print("── ① #0 채취기: 그리는 칸 = 겨누는 칸 ──")
	_check("①a-pre 무대: 안식 농원이고 채취기·나무 원장이 서 있다",
		m._region == RegionCatalog.HOME and m.tapper != null and m.tree_ledger != null)
	var anchors: Dictionary = m._home_tree_anchor_set()
	_check("①b-pre 무대: 손저작 나무 앵커가 %d칸(layout.json HOME 파생 — 하드코딩 0)" % anchors.size(),
		not anchors.is_empty())
	if anchors.is_empty():
		return
	# 보정폭은 나무 스프라이트에서 파생된다(수치 하드코딩 0) — 칸 단위로 딱 떨어져야 다리가 성립한다.
	var drop_px: float = m._tapper_home_drop()
	var drop_tiles := int(drop_px) / int(m.TILE)
	_check("①c-pre 무대: 보정폭이 칸의 정수배다(%.0fpx = %d칸 · 스프라이트 높이 − 한 칸)"
			% [drop_px, drop_tiles],
		drop_tiles > 0 and is_equal_approx(float(drop_tiles * int(m.TILE)), drop_px))

	var t: Vector2i = anchors.keys()[0]
	var foot := t + Vector2i(0, drop_tiles)
	_check("①d-pre 무대: 그 앵커가 성숙목이라 채취기를 박을 수 있다", m._can_place_tapper(t))
	var species: String = m.tree_ledger.species_at(m._region, t)
	_check("①e-pre 무대: 앵커 칸에 채취기가 박혔다(원장 키는 앵커 그대로 — 세이브 무변)",
		m.tapper.place(m._region, t, species, 0) and m.tapper.has_at(m._region, t)
		and not m.tapper.has_at(m._region, foot))

	_check("①f **통이 그려진 밑동 칸이 원장 칸으로 되돌아온다**(어긋남 %d칸을 다리가 흡수)" % drop_tiles,
		m._tapper_ledger_tile(foot) == t)
	_check("①g 앵커 칸을 겨누는 옛 경로도 그대로 산다(항등 — 회귀 보존)",
		m._tapper_ledger_tile(t) == t)
	_check("①h 그 다리가 프롬프트를 실제로 세운다([F] 한 동사 — 종전엔 안내조차 안 떴다)",
		m.tapper.has_at(m._region, m._tapper_ledger_tile(foot))
		and m._tapper_prompt(m._tapper_ledger_tile(foot)).begins_with("[F]"))
	# 사각 — 나무와 무관한 칸·다른 구역은 손대지 않는다(앵커 집합·구역 술어가 범위를 좁힌다).
	var far := foot + Vector2i(5, 0)
	_check("①i 앵커와 무관한 칸은 항등이다(아무 칸에서나 3칸 위를 훔쳐보지 않는다)",
		m._tapper_ledger_tile(far) == far)
	var keep: String = m._region
	m._region = RegionCatalog.JEOSEUNG_FOREST
	_check("①j 숲은 보정 자체가 없다 — 구역 술어로 항등(원장 칸 = 발치인 무대)",
		m._tapper_ledger_tile(foot) == foot)
	m._region = keep
	# 입력 사슬과 프롬프트 사슬이 **같은 술어**를 본다(한쪽만 고치면 "안내는 뜨는데 안 먹는다").
	_check("①k 입력 사슬이 그 다리를 통과한 칸으로 동사를 부른다",
		_line_of("_use_tapper(_tapper_ledger_tile(_target))") >= 0)
	_check("①l 프롬프트 사슬도 같은 다리를 통과한 칸을 읽는다",
		_line_of("_tapper_prompt(_tapper_ledger_tile(_target))") >= 0)
	m.tapper.load_save({})


# ── ② #1 내면 공간 닫기 — 취침 중이면 잠금의 주인이 취침이다 ──────────────────
func _check_spine_close(m: Node) -> void:
	print("── ② #1 `_close_spine_puzzle` 취침 가드 ──")
	_check("②a-pre 계약의 형제들이 이미 그 형태다(`_close_epilogue`가 세운 두 줄)",
		_in_func("func _close_epilogue", "if not _sleeping:")
		and _in_func("func _close_epilogue", "player.set_physics_process(not _sleeping)"))
	_check("②b 닫는 자리가 시계를 취침 중엔 안 되돌린다(`_do_sleep`의 정지를 안 뺏는다)",
		_in_func("func _close_spine_puzzle", "if not _sleeping:"))
	_check("②c 닫는 자리가 이동도 취침 여부를 보고 켠다(`_on_sleep_done`이 눈뜨는 프레임에 켠다)",
		_in_func("func _close_spine_puzzle", "player.set_physics_process(not _sleeping)"))

	# 라이브 — 취침 트윈 한가운데서 닫히는 그 창을 그대로 세운다.
	var slept_prev: bool = m._sleeping
	m._sleeping = true
	m.clock.running = false
	m._spine_b5_clock_prev = true          # R13이 바꾼 스냅(취침 중 열림 = true)
	m.player.set_physics_process(false)
	m._close_spine_puzzle()
	_check("②d 취침 트윈 안에서 닫아도 시계가 다시 흐르지 않는다(분 틱·NPC·영업창 보존)",
		not m.clock.running)
	_check("②e 그 프레임에 이동도 안 켜진다(완전 암전 뒤에서 걷지 않는다)",
		not m.player.is_physics_processing())
	# 반대 갈래 — 평시엔 종전대로 스냅을 되돌리고 이동을 켠다(가드가 기능을 죽이지 않았다).
	m._sleeping = false
	m._spine_b5_clock_prev = true
	m.player.set_physics_process(false)
	m._close_spine_puzzle()
	_check("②f 평시엔 스냅대로 시계·이동이 되살아난다(거동 보존)",
		m.clock.running and m.player.is_physics_processing())
	m._sleeping = slept_prev


# ── ③ #2·#3 서식 지시자 — 라벨이 실측값을 싣는다 ─────────────────────────────
func _check_format_specs() -> void:
	print("── ③ #2·#3 이스케이프 안 된 `%` 전수 ──")
	# 판별식: **유효 지시자가 있는 문자열**(= 실제로 `%` 연산의 좌변인 서식 템플릿)에 무효 지시자가
	#   섞였는가. 유효 지시자가 하나도 없는 문자열("15% 할인" 같은 평문)은 서식이 아니라 그냥 글자다.
	var files: Array = []
	_all_gd_files("res://", files)
	var hits: Array = []
	for path in files:
		var lines := _lines_of_file(String(path))
		for i in lines.size():
			if not lines[i].contains("%"):
				continue
			for s in _display_strings(lines[i]):
				var sc := _scan_format(String(s))
				if sc.x > 0 and sc.y > 0:
					hits.append("%s:%d" % [String(path).get_file(), i + 1])
	_check("③a-pre 무대: 스캔 대상 .gd %d개(res:// 재귀 — 분모 하드코딩 0)" % files.size(),
		files.size() > 100)
	_check("③b 서식 템플릿 안에 이스케이프 안 된 퍼센트가 0곳(잔존: %s)" % str(hits), hits.is_empty())
	# 스캐너 자체가 두 결함을 실제로 잡는가(가드가 헛도는 것을 막는 자기검증).
	# ★ 프로브 문자열은 **조각내 잇는다** — 한 리터럴에 유효·무효가 함께 들면 위 전수 스캔이
	#   자기 자신을 잡는다(가드가 가드를 무는 자리).
	_check("③c 스캐너가 옛 두 형태를 잡는다(한글이 바로 이어진 지시자 · 공백 뒤 한글)",
		_scan_format("10%" + "로 %d") == Vector2i(1, 1)
		and _scan_format("15% 근처(" + "%d)") == Vector2i(1, 1))
	_check("③d 그리고 고친 형태는 통과시킨다(이스케이프된 퍼센트는 리터럴)",
		_scan_format("10%%로 %d~%d") == Vector2i(2, 0))
	# 두 라벨이 이제 실측값을 싣는다 — 문구가 엔진 오류 문자열로 안 바뀐다.
	_check("③e 나락 ②b 라벨이 실측을 싣는다(엔진 오류 문자열로 안 바뀐다)",
		("②b 낙하 층수(3~8, 10%%로 2x−1) — 실측 %d~%d" % [3, 15]).contains("10%로")
		and ("②b … 실측 %d~%d" % [3, 15]).contains("실측 3~15"))
	_check("③f 잡귀 ⑨d 라벨도 관측값을 싣는다",
		("⑨d 처치 롤이 15%% 근처(관측 %d/2000)" % 316).contains("15% 근처(관측 316/2000)"))


# ── ④ #4 「큰 %s」 뒤 조사가 받침을 가른다 ────────────────────────────────────
func _check_josa(m: Node) -> void:
	print("── ④ #4 넋둥우리 분기 고정 조사 ──")
	# 두 건물 이름은 **종에서 파생**한다(이름 하드코딩 0 — 표가 바뀌면 이 단언이 따라간다).
	var coop_bld := ""
	var barn_bld := ""
	for id in AnimalCatalog.ids():
		var bld: String = m._animal_building_of(String(id))
		if AnimalCatalog.kind_of(String(id)) == "coop":
			coop_bld = bld
		else:
			barn_bld = bld
	_check("④a-pre 무대: 두 갈래 건물 이름이 실제로 받침이 갈린다(%s / %s)" % [coop_bld, barn_bld],
		coop_bld != "" and barn_bld != ""
		and HanjiUi.josa_eul(coop_bld) != HanjiUi.josa_eul(barn_bld))
	_check("④b coop 갈래가 「큰 %s」+ 받침 없는 조사로 선다" % coop_bld,
		("목공방에서 「큰 %s」%s 지어야 한다" % [coop_bld, HanjiUi.josa_eul(coop_bld)])
			.contains("「큰 %s」를" % coop_bld))
	_check("④c barn 갈래는 종전대로 「…」을(우연히 맞던 쪽도 같은 한 식에서 나온다)",
		("목공방에서 「큰 %s」%s 지어야 한다" % [barn_bld, HanjiUi.josa_eul(barn_bld)])
			.contains("「큰 %s」을" % barn_bld))
	_check("④d 그 자리가 조사를 식으로 뽑는다(고정 문자열이 아니다)",
		_line_of("「큰 %s」%s 지어야 한다") >= 0
		and _line_of("HanjiUi.josa_eul(bld)") >= 0)
	# R5/R12 전수 가드의 사각(`」` 개재)이 메워졌다 — 정규식 자체를 세워 거동으로 잰다.
	var re := RegEx.create_from_string("%s[」』]? ?(를|을|는|은|가|이|와|과)([^가-힣]|$)")
	_check("④e 좁힌 가드 정규식이 `%s」을` 형태를 잡는다(종전 사각)",
		re.search("「큰 %s」을 지어야") != null)
	_check("④f 그러면서 옛 형태도 계속 잡는다(범위를 넓혔지 좁히지 않았다)",
		re.search("%s를 깼다") != null and re.search("%s 을 ") != null)
	for path in ["res://playtest/polish_r5_test.gd", "res://playtest/polish_r12_test.gd"]:
		var joined := "\n".join(_lines_of_file(String(path)))
		_check("④g 전수 가드 두 자리가 그 정규식을 쓴다(%s)" % String(path).get_file(),
			joined.contains("%s[」』]? ?(를|을|는|은|가|이|와|과)"))


# ── ⑤ #5 목공방 공기 헤더가 카탈로그에서 파생된다 ────────────────────────────
func _check_build_days(m: Node) -> void:
	print("── ⑤ #5 목공방 헤더 공기 ──")
	var lo := 0
	var hi := 0
	var days: Array = []
	for id in Carpenter.ids():
		var d := Carpenter.build_days(String(id))
		days.append(d)
		lo = d if lo == 0 else mini(lo, d)
		hi = maxi(hi, d)
	_check("⑤a-pre 무대: 표의 공기가 실제로 갈린다(%s — 한 값이면 헤더의 단정이 참이었다)" % str(days),
		lo != hi)
	var text: String = m._build_days_text()
	_check("⑤b 헤더 문구가 표의 최소·최대를 함께 말한다(%s)" % text,
		text.contains(str(lo)) and text.contains(str(hi)))
	_check("⑤c 한 프로젝트의 값을 전 매대의 규칙으로 일반화하지 않는다(옛 문구와 다르다)",
		text != "공기 %d일" % Carpenter.build_days(Carpenter.PROJ_BIG_COOP))
	# 실제 헤더에 그 문구가 실린다(놀고 있을 때 = 발주 전 = 사기 전에 보는 그 화면).
	m.carpenter.load_save({})
	_check("⑤d-pre 무대: 진행 중 의뢰가 없다(헤더가 가게 규칙을 먼저 말하는 상태)",
		m.carpenter.summary(m.clock.day) == "")
	_check("⑤e 목공방 헤더가 그 파생 문구를 그대로 싣는다",
		m._woodshop_text().contains(text))
	# 늘봄방이 그 상한을 실제로 만드는 프로젝트다(발주 알림과 헤더가 같은 값을 본다).
	_check("⑤f 상한을 만드는 프로젝트가 표에 실재한다(늘봄방 %d일 — 발주 알림이 쓰는 그 값)"
			% Carpenter.build_days(Carpenter.PROJ_GREENHOUSE),
		Carpenter.build_days(Carpenter.PROJ_GREENHOUSE) == hi)


# ── ⑥ #6 미호 ♡1 편지 첨부 ───────────────────────────────────────────────────
func _check_letter_seed(m: Node) -> void:
	print("── ⑥ #6 미호 ♡1 씨앗 첨부 ──")
	var lid := "miho_gate1_seed"
	_check("⑥a-pre 무대: 그 편지가 미호 ♡1 관문의 여진 통이다(GATE_LETTERS 파생)",
		String(Miho.GATE_LETTERS.get(1, "")) == lid)
	_check("⑥b-pre 무대: 본문이 실재 인벤 아이템군을 명시적으로 건넨다(첨부 규율의 기준)",
		str(Mailbox.LETTERS[lid]["lines"]).contains("씨앗"))
	var items: Array = Mailbox.attachment_items_of(lid)
	_check("⑥c 첨부가 씨앗 한 종을 싣는다(빈 첨부가 아니다)", items.size() == 1)
	if items.is_empty():
		return
	var iid := String(items[0]["id"])
	var n := int(items[0]["n"])
	_check("⑥d 그 id가 실재 등록 아이템이다(유령 id 0) — %s ×%d" % [iid, n],
		ItemCatalog.has_item(iid) and n > 0)
	_check("⑥e 씨앗군의 파생 id 그대로다(`seed_id` — 손으로 지은 문자열이 아니다)",
		iid == ItemCatalog.seed_id(CropCatalog.PIANHWA))
	_check("⑥f 그 씨앗은 ♡1이 닿는 첫 절기에 실제로 심을 수 있다(피안절 = 절기 0)",
		CropCatalog.in_season(CropCatalog.PIANHWA, 0))
	# 라이브 — 편지를 읽는 그 경로가 백팩을 실제로 움직인다.
	m.inventory.load_save({})
	var before: int = m.inventory.count_of(iid)
	m._grant_letter_attachment(lid)
	_check("⑥g 편지를 읽으면 백팩이 실제로 %d칸 는다(종전엔 한 톨도 안 변했다)" % n,
		m.inventory.count_of(iid) == before + n)
	m.inventory.load_save({})


# ── ⑦ #7 관계 탭 선물 X/Y가 코드베이스 관례를 따른다 ─────────────────────────
func _check_gift_rhythm(m: Node) -> void:
	print("── ⑦ #7 이번 주 선물 표기 ──")
	var r: Resident = m._resident("miho")
	_check("⑦a-pre 무대: 미호 레코드와 호감도 원장이 있다", r != null and r.affinity != null)
	if r == null or r.affinity == null:
		return
	var day: int = m.clock.day
	_check("⑦b-pre 무대: 오늘은 생일도 부부도 아니다(면제 갈래가 아닌 평상 갈래)",
		not r.is_birthday_on(day) and m._spouse_id != r.id)
	r.affinity.gift_week = GameClock.week_of(day)
	r.affinity.gifts_this_week = 0
	_check("⑦c 아무것도 안 쓴 주는 분자가 0이다(달성/총량 관례 — 종전엔 잔여라 %d였다)"
			% Affinity.GIFTS_PER_WEEK,
		m._gift_rhythm_text(r) == "이번 주 선물 0/%d" % Affinity.GIFTS_PER_WEEK)
	r.affinity.gifts_this_week = 1
	_check("⑦d 한 번 쓰면 1로 오른다(늘어나는 방향 = 다른 X/Y와 같은 방향)",
		m._gift_rhythm_text(r) == "이번 주 선물 1/%d" % Affinity.GIFTS_PER_WEEK)
	r.affinity.gifts_this_week = Affinity.GIFTS_PER_WEEK
	_check("⑦e 다 쓰면 분자 = 분모다(종전엔 0/2라 '아직 안 썼다'로 읽혔다)",
		m._gift_rhythm_text(r) == "이번 주 선물 %d/%d"
			% [Affinity.GIFTS_PER_WEEK, Affinity.GIFTS_PER_WEEK])
	_check("⑦f 표기만 고쳤다 — 판정(can_gift)은 그대로 소진을 안다",
		not r.affinity.can_gift(day) and r.affinity.gifts_left_in_week(day) == 0)
	r.affinity.gifts_this_week = 0


# ── ⑧ #8 도끼 벼리기 문구가 열리는 접근만 약속한다 ───────────────────────────
func _check_axe_text(m: Node) -> void:
	print("── ⑧ #8 도끼 티어 효과 문구 ──")
	# 도끼가 여는 접근 게이트의 상한 = 상수 파생(수치 하드코딩 0).
	var gate_top: int = maxi(ToolTier.TIER_LARGE_STUMP, ToolTier.TIER_LARGE_LOG)
	var top_tier: int = ToolTier.AXE_MATURE_HP.size() - 1
	_check("⑧a-pre 무대: 도끼 게이트 상한 %d < 최고 티어 %d(그 사이가 과잉 약속 구간)"
			% [gate_top, top_tier],
		gate_top < top_tier)
	var kinds_ok := true
	for kind in [TreeLedger.KIND_LARGE_STUMP, TreeLedger.KIND_LARGE_LOG]:
		if TreeLedger.tier_for_large(String(kind)) > gate_top:
			kinds_ok = false
	_check("⑧b-pre 무대: 원장이 요구하는 티어가 그 상한을 안 넘는다(게이트 전량이 둘)", kinds_ok)
	var opens: Array = []
	var silent: Array = []
	for tier in range(1, top_tier + 1):
		var txt: String = m._tier_effect_text(ToolTier.AXE, tier)
		if txt.contains("더 굵은 것을 벨 수 있다"):
			opens.append(tier)
		else:
			silent.append(tier)
	_check("⑧c '더 굵은 것' 약속이 게이트가 열리는 티어에만 붙는다(%s)" % str(opens),
		opens == range(1, gate_top + 1))
	_check("⑧d 그 위 티어는 그 절을 안 말한다(%s — 새로 벨 수 있게 된 대상 0종)" % str(silent),
		not silent.is_empty())
	var hp_ok := true
	for tier in range(0, top_tier + 1):
		if not m._tier_effect_text(ToolTier.AXE, tier) \
				.contains("성숙목 %d타" % ToolTier.axe_mature_hp(tier)):
			hp_ok = false
	_check("⑧e 실제 이득(타수)은 전 티어에서 그대로 말한다(정보를 지운 게 아니다)", hp_ok)


# ── ⑨ #9 제작 탭 헤더가 해금 축 전량을 말한다 ────────────────────────────────
func _check_craft_header(m: Node) -> void:
	print("── ⑨ #9 제작 탭 헤더 해금 축 ──")
	var rows: Array = m._craft_rows()
	var axes: Array = m.frame._craft_skill_axes(rows)
	_check("⑨a-pre 무대: 카탈로그에 채집 외 2차 축이 실재한다(계단=채광 · 상위 스프링클러=농사)",
		CraftCatalog.skill_gate_id_of(CraftCatalog.STAIRS) == ProfessionCatalog.MINING
		and CraftCatalog.skill_gate_id_of(CraftCatalog.SPRINKLER_T2) == ProfessionCatalog.FARMING)
	_check("⑨b-pre 무대: 그 셋은 채집 문턱이 0이다(만렙을 찍어도 안 열린다 = 옛 헤더가 거짓인 근거)",
		int(CraftCatalog.get_recipe(CraftCatalog.STAIRS)["unlock_level"]) == 0
		and int(CraftCatalog.get_recipe(CraftCatalog.SPRINKLER_T2)["unlock_level"]) == 0)
	_check("⑨c 헤더 축 목록이 채집을 든다(채집 계단 레시피가 여전히 다수)", axes.has("채집"))
	_check("⑨d 채광 축도 든다(계단 행의 잠금 사유와 같은 라벨)",
		axes.has(m._skill_label(ProfessionCatalog.MINING)))
	_check("⑨e 농사 축도 든다(상위 스프링클러 2종)",
		axes.has(m._skill_label(ProfessionCatalog.FARMING)))
	_check("⑨f 목록이 중복 없이 등장 순서대로다(%s)" % str(axes),
		axes.size() == 3)
	# 라벨은 행이 실어 온다 — 프레임에 스킬 이름 하드코딩이 없다.
	var inv_src := "\n".join(_lines_of_file("res://inv_frame.gd"))
	_check("⑨g 프레임에 옛 단정이 안 남았다(\"채집 숙련으로 배운다\" 고정 문구 0곳)",
		not inv_src.contains("손 제작 — 채집 숙련으로 배운다"))
	_check("⑨h 축 이름은 행이 싣고 온 라벨을 쓴다(프레임의 스킬 하드코딩 0)",
		inv_src.contains("row.get(\"skill_gate_label\""))


# ── ⑩ #10 장원제 프롬프트가 출품 상한을 말한다 ───────────────────────────────
func _check_grange_cap(m: Node) -> void:
	print("── ⑩ #10 장원제 출품 상한 안내 ──")
	m.larder.load_save({})
	# 상한을 실제로 넘기는 재고를 만든다(종수는 카탈로그 파생 — 값 하드코딩 0).
	var cap: int = SeasonalEvent.GRANGE_MAX_ENTRIES
	var stocked := 0
	for id in ItemCatalog.ids_in_category(ItemCatalog.CAT_HARVEST):
		if stocked >= cap + 2:
			break
		if m.larder.add(String(id), 1) > 0:
			stocked += 1
	_check("⑩a-pre 무대: 곳간 재고 %d종 > 출품 상한 %d종(잘림이 실제로 일어나는 판)"
			% [m.larder.ids().size(), cap],
		m.larder.ids().size() > cap)
	_check("⑩b 실제 출품은 상한에서 잘린다(계약 재확인 — 프롬프트가 말해야 할 그 수)",
		m._grange_entries().size() == mini(m.larder.ids().size(), cap))
	_check("⑩c 안내가 상한과 재고를 함께 말한다(되돌릴 수 없는 하루 1회 래치 직전)",
		_line_of("[F] 곳간 장원제 출품 (상위 %d종 · 재고 %d종 — 차감 없음)") >= 0
		and _line_of("mini(larder.ids().size(), SeasonalEvent.GRANGE_MAX_ENTRIES)") >= 0)
	var shown := "[F] 곳간 장원제 출품 (상위 %d종 · 재고 %d종 — 차감 없음)" % [
		mini(m.larder.ids().size(), cap), m.larder.ids().size()]
	_check("⑩d 그 문구의 앞 수가 결과 알림의 출품 종수와 같다(두 화면이 한 값을 본다)",
		shown.contains("상위 %d종" % m._grange_entries().size()))
	m.larder.load_save({})


# ── ⑪⑫ #11·#12 조회 오버레이 위의 클릭이 월드로 안 샌다 ─────────────────────
func _check_overlay_clicks(m: Node) -> void:
	print("── ⑪⑫ #11·#12 거울·달력 클릭 누수 ──")
	_check("⑪a-pre 무대: 거울 패널이 뜨면 시계 HUD가 숨는다(위 시계 가드가 죽는 이유)",
		_in_func("func _process", "or mirror_panel.visible"))
	_check("⑪b 월드 디스패치 앞에 오버레이 가드가 섰다",
		_in_func("func _process", "_pointer_over_overlay(get_viewport().get_mouse_position())"))
	# 거울 — 패널 안은 막고 밖은 그대로 논다.
	m.mirror_panel.visible = true
	var inside: Vector2 = m.mirror_panel.position + m.mirror_panel.size * 0.5
	var outside: Vector2 = m.mirror_panel.position - Vector2(20.0, 20.0)
	_check("⑪c 거울 판 한가운데의 클릭은 월드로 안 내려간다(집 안 우클릭 = `_do_sleep` 봉합)",
		m._pointer_over_overlay(inside))
	_check("⑪d 판 밖은 막지 않는다(패널 밖에서는 평소처럼 일한다)",
		not m._pointer_over_overlay(outside))
	m.mirror_panel.visible = false
	_check("⑪e 패널을 덮으면 가드도 함께 내려간다(상시 봉쇄가 아니다)",
		not m._pointer_over_overlay(inside))
	# 달력 — 그린 판과 판정이 한 식(frame_rect)에서 나온다.
	m.calendar_panel.set_state(m.clock.day, 0, 0)
	if m.calendar_panel.is_open():
		m.calendar_panel.close()
	m.calendar_panel.toggle()
	_check("⑫a-pre 무대: 달력이 펼쳐졌고 칸 데이터가 섰다",
		m.calendar_panel.is_open() and not m.calendar_panel.cells().is_empty())
	var frect: Rect2 = m.calendar_panel.frame_rect()
	_check("⑫b 달력 격자 위의 클릭이 막힌다(종전엔 그대로 도끼질로 나갔다)",
		m._pointer_over_overlay(frect.position + frect.size * 0.5))
	_check("⑫c 판 밖은 계속 논다 — 비-모달의 정체성 보존(열어 둔 채 걷는 자유)",
		not m._pointer_over_overlay(frect.position - Vector2(8.0, 8.0)))
	m.calendar_panel.close()
	_check("⑫d 접으면 판정도 꺼진다(닫힌 달력이 화면을 계속 먹지 않는다)",
		not m._pointer_over_overlay(frect.position + frect.size * 0.5))
	var cal_src := "\n".join(_lines_of_file("res://calendar_panel.gd"))
	_check("⑫e 그린 판과 막는 판이 한 식이다(`frame_rect` 단일 출처 — 어긋남 0)",
		cal_src.contains("func frame_rect()") and cal_src.contains("return frame_rect().has_point")
		and cal_src.contains("var frame := frame_rect()"))


# ── ⑬ #13 집 꾸미기 모드가 이동을 잠근다 ─────────────────────────────────────
func _check_deco_lock(m: Node) -> void:
	print("── ⑬ #13 꾸미기 모드 이동 잠금 ──")
	# 부팅 온보딩 대화가 열린 채면 `_deco_blocked`가 참이라 무대 자체가 안 선다(모달 목록 소속).
	var guard := 0
	while m.dialogue.is_open() and guard < 60:
		m.dialogue.advance()
		guard += 1
	var indoor_prev: String = m._indoor
	m._indoor = "집"
	m.player.set_physics_process(true)
	_check("⑬a-pre 무대: 지금 자리에서 꾸미기에 들어갈 수 있다(집 실내 · 막는 상태 없음)",
		m._can_deco() and not m._deco_blocked() and not m._deco_mode)
	m._toggle_deco_mode()
	_check("⑬b 켜면 이동이 잠긴다(문·워프 트리거가 얼어 있는 채 걷지 않는다)",
		m._deco_mode and not m.player.is_physics_processing())
	_check("⑬c 속도도 즉시 0이다(누르고 있던 방향키의 관성이 안 남는다)",
		m.player.velocity == Vector2.ZERO)
	m._toggle_deco_mode()
	_check("⑬d 끄면 되돌아온다(모드가 이동을 영구히 뺏지 않는다)",
		not m._deco_mode and m.player.is_physics_processing())
	# 잠금의 주인 — 취침·연출이 들어와 자동으로 접히는 경로에서는 여기가 안 켠다.
	m._toggle_deco_mode()
	m._sleeping = true
	_check("⑬e-pre 무대: 취침이 들어오면 꾸미기는 막힌 상태가 된다(`_deco_blocked` 자동 접기)",
		m._deco_mode and m._deco_blocked())
	m._toggle_deco_mode()
	_check("⑬f 그 자동 접기가 이동을 켜지 않는다(『정지 주인 ≠ 재개 주인』 — 암전 뒤 걷기 0)",
		not m._deco_mode and not m.player.is_physics_processing())
	m._sleeping = false
	m.player.set_physics_process(true)
	m._indoor = indoor_prev
	_check("⑬g 모드 토글이 다른 모드들과 같은 잠금 형태를 쓴다(`_open_frame`·`_start_dialogue` 결)",
		_in_func("func _toggle_deco_mode", "player.set_physics_process(false)")
		and _in_func("func _toggle_deco_mode", "elif not _deco_blocked():"))


# ══════════════════════════════════════════════════════════════════════════════
# 배치 B(#14~#26) — 입력 컨텍스트 · 오디오 상태 짝 · 테스트 노드 수명 · 설정 왕복.
#
#   ⑭ #14 좌상단 [배치 모드 끄기] 버튼 클릭이 같은 프레임 월드 LMB로 새어 도구·설치가 발동했다.
#   ⑮ #15 꾸미기 중 F10 → 두 저작 모드가 겹쳐 선 채 C도 배치 입력도 안 먹었다.
#   ⑯ #16 음소거가 전역 버스에만 남아 F8 재시작이 통째로 무음인 새 게임을 만들었다.
#   ⑰ #17 척추 B5 강제 음소거 구간의 [M]을 닫는 자리의 스냅 원복이 조용히 덮어썼다.
#   ⑱~㉒ #18~#22 playtest 하네스의 트리 밖 `new()` 노드 미해제(ObjectDB 누수 경고).
#   ㉓ #23 타이틀 설정 패널의 "(F11)" 안내가 거짓 — 그 화면에서만 키가 죽어 있었다.
#   ㉔ #24 OS 제스처로 창 모드가 바뀌면 `settings.fullscreen`이 영구 stale.
#   ㉕ #25 볼륨 0%가 무음이 아니었다(바닥이 크로스페이드용 −40 dB).
#   ㉖ #26 = #5 DUP — 배치 A의 카탈로그 파생이 이 시나리오까지 덮는지 실측으로 확인한다.


# ── ⑭ #14 배치 모드 버튼: 끄는 클릭이 월드로 안 샌다 ─────────────────────────
func _check_edit_button_swallow(m: Node) -> void:
	print("── ⑭ #14 배치 모드 버튼 클릭 누수 ──")
	_check("⑭a 버튼이 삼킴 표를 세우는 전용 경로에 배선됐다(맨 `_toggle_edit_mode` 직결 아님)",
		_in_func("func _make_edit_ui", "_edit_btn_toggle.pressed.connect(_on_edit_toggle_pressed)"))
	var edit_prev: bool = m._edit_mode
	var deco_prev: bool = m._deco_mode
	m._edit_mode = false
	m._swallow_input_once = false
	m._on_edit_toggle_pressed()
	_check("⑭b **켜는** 클릭은 표를 안 세운다(`if _edit_mode: return`이 이미 프레임을 끊는다)",
		m._edit_mode and not m._swallow_input_once)
	m._on_edit_toggle_pressed()
	_check("⑭c **끄는** 클릭이 그 프레임의 LMB를 삼킨다(커서 밑 도구·설치 발동 0)",
		not m._edit_mode and m._swallow_input_once)
	_check("⑭d 표를 소비하는 자리가 월드 디스패치보다 위다(R4가 세운 그 소비점 하나 — 복제 0)",
		_in_func("func _process", "if _swallow_input_once:")
		and _in_func("func _process", "_swallow_input_once = false"))
	m._swallow_input_once = false
	m._edit_mode = edit_prev
	m._deco_mode = deco_prev


# ── ⑮ #15 두 저작 모드는 동시에 설 수 없다 ───────────────────────────────────
func _check_authoring_modes_exclusive(m: Node) -> void:
	print("── ⑮ #15 배치 ↔ 꾸미기 상호배타 ──")
	var guard := 0
	while m.dialogue.is_open() and guard < 60:
		m.dialogue.advance()
		guard += 1
	var indoor_prev: String = m._indoor
	m._indoor = "집"
	m.player.set_physics_process(true)
	_check("⑮a-pre 무대: 꾸미기에 들어갈 수 있는 자리·때다(집 실내 · 막는 상태 없음)",
		m._can_deco() and not m._deco_blocked() and not m._deco_mode and not m._edit_mode)
	m._toggle_deco_mode()
	_check("⑮b-pre 무대: 꾸미기가 켜졌다", m._deco_mode)
	m._toggle_edit_mode()
	_check("⑮c 배치 모드를 켜면 꾸미기가 먼저 접힌다(두 모드가 겹쳐 서지 않는다)",
		m._edit_mode and not m._deco_mode)
	_check("⑮d 그 상태에서 이동도 잠긴다(문·워프 트리거가 얼어 있는 채 걷지 않는다 — #13과 같은 계약)",
		not m.player.is_physics_processing() and m.player.velocity == Vector2.ZERO)
	m._toggle_edit_mode()
	_check("⑮e 끄면 이동이 돌아온다(모드가 이동을 영구히 뺏지 않는다)",
		not m._edit_mode and not m._deco_mode and m.player.is_physics_processing())
	# 잠금의 주인 — 취침·연출이 들어와 막힌 상태면 끄는 자리가 이동을 켜지 않는다.
	m._toggle_edit_mode()
	m._sleeping = true
	_check("⑯-pre 무대: 취침이 들어오면 `_deco_blocked`가 참이다", m._edit_mode and m._deco_blocked())
	m._toggle_edit_mode()
	_check("⑮f 막힌 상태의 끄기는 이동을 안 켠다(『정지 주인 ≠ 재개 주인』 — 암전 뒤 걷기 0)",
		not m._edit_mode and not m.player.is_physics_processing())
	m._sleeping = false
	m.player.set_physics_process(true)
	m._indoor = indoor_prev
	_check("⑮g `_process` 순서가 그대로다(배치 early return이 꾸미기 토글보다 위 — 처방은 토글 쪽에 있다)",
		_in_func("func _process", "if _edit_mode:")
		and _in_func("func _toggle_edit_mode", "if _edit_mode and _deco_mode:"))


# ── ⑯ #16 음소거는 씬 재로드를 넘어 살아남지 않는다 ──────────────────────────
func _check_mute_reload(m: Node) -> void:
	print("── ⑯ #16 음소거 되감기 ──")
	var mi := AudioServer.get_bus_index(GameAudio.MUSIC_BUS)
	var si := AudioServer.get_bus_index(GameAudio.SFX_BUS)
	_check("⑯a-pre 무대: Music·SFX 버스가 서 있다(음소거의 실제 주인 = 씬 트리 밖 전역 서버)",
		mi != -1 and si != -1)
	if mi == -1 or si == -1:
		return
	m.audio.set_muted(true)
	_check("⑯b-pre 무대: 음소거가 두 버스의 플래그로 남는다(F8 재시작이 이걸 안 지운다)",
		AudioServer.is_bus_mute(mi) and AudioServer.is_bus_mute(si) and m.audio.is_muted())
	# 재시작 모사 — 버스는 남긴 채 **새 GameAudio**만 세운다(reload_current_scene이 하는 일 그대로).
	var fresh := GameAudio.new()
	root.add_child(fresh)
	_check("⑯c 새 GameAudio가 서면 버스가 노드 상태로 되감긴다(통째로 무음인 새 게임 0)",
		not AudioServer.is_bus_mute(mi) and not AudioServer.is_bus_mute(si) and not fresh.is_muted())
	_check("⑯d 첫 [M]이 실효한다(종전엔 `set_muted(true)`라 아무것도 안 바뀌어 두 번 눌러야 했다)",
		fresh.toggle_mute() and AudioServer.is_bus_mute(mi) and AudioServer.is_bus_mute(si))
	fresh.set_muted(false)
	fresh.free()
	_check("⑯e 형제 축(버스 볼륨)에는 그 짝이 이미 있었다 — mute만 비었던 비대칭",
		_in_func("func _setup_settings", "_apply_audio_volumes()"))
	m.audio.set_muted(false)
	_check("⑯f 정리 — 무대를 원상복구했다(버스·노드 상태가 같다)",
		not m.audio.is_muted() and not AudioServer.is_bus_mute(mi))


# ── ⑰ #17 B5 강제 음소거 구간의 [M]이 원복 근거를 갱신한다 ───────────────────
func _check_b5_mute_intent(m: Node) -> void:
	print("── ⑰ #17 B5 강제 음소거 구간의 사용자 의사 ──")
	_check("⑰a-pre 무대: 부팅 직후는 강제 음소거 구간이 아니다(구간 밖 [M] 거동은 종전 그대로)",
		not m._spine_b5_mute_forced)
	_check("⑰b 폴링이 **구간 중에만** 스냅을 갱신한다(그 표가 조건이다)",
		_in_func("func _process", "if _spine_b5_mute_forced:")
		and _in_func("func _process", "_spine_b5_mute_prev = muted_now"))
	_check("⑰c 구간의 시작 = 강제 음소거를 거는 바로 그 자리",
		_in_func("func _begin_spine_b5", "_spine_b5_mute_forced = true")
		and _in_func("func _begin_spine_b5", "audio.set_muted(true)"))
	_check("⑰d 소리를 되돌리는 자리마다 표를 내린다(닫기 + 중단 2경로 — 되돌린 뒤엔 갱신 대상이 아니다)",
		_in_func("func _close_spine_puzzle", "_spine_b5_mute_forced = false")
		and _in_func("func _begin_spine_b5", "_spine_b5_mute_forced = false")
		and _in_func("func _open_spine_puzzle", "_spine_b5_mute_forced = false"))
	_check("⑰e 닫는 자리는 여전히 **스냅 하나로만** 되돌린다(무조건 켜기 0 — 형제 `_spine_b5_clock_prev`의 규율)",
		_in_func("func _close_spine_puzzle", "audio.set_muted(_spine_b5_mute_prev)")
		and not _in_func("func _close_spine_puzzle", "audio.set_muted(false)"))


# ── ⑱~㉒ #18~#22 하네스의 트리 밖 노드 수명 ──────────────────────────────────
# `extends Node`는 RefCounted가 아니라 지역 변수가 스코프를 벗어나도 안 죽는다 —
# `add_child` 없이 `new()`한 원장은 직접 `free()` 하지 않으면 종료 시 ObjectDB에 남는다
# (`playtest_bot.gd:287-288`이 그 규약을 명시한다).
# 판정은 **파일에서 파생**한다: `extends Node` + `class_name`인 클래스 전량을 res:// 재귀 스캔으로
# 모으고, 대상 파일이 그중 무엇을 `new()`했는지 변수명까지 뽑아 그 이름 하나하나가 해제 문맥에
# 등장하는지 본다(수·분모 하드코딩 0 — 파일에 인스턴스를 추가하면 이 단언이 저절로 따라 조인다).
const _LEAK_TARGETS := [
	"res://playtest/livestock_test.gd",       # #18 Ranch
	"res://playtest/forage_test.gd",          # #18 잔여분 Forage
	"res://playtest/orchard_test.gd",         # #18 잔여분 Orchard
	"res://playtest/rarecrow_test.gd",        # #18 잔여분 RarecrowLedger
	"res://playtest/weather_test.gd",         # #18 잔여분 FarmField
	"res://playtest/inventory_test.gd",       # #19 Inventory
	"res://playtest/sprinkler_tier_test.gd",  # #20 Sprinkler
	"res://playtest/chest_test.gd",           # #21 StorageChest
	"res://playtest/quality_skill_test.gd",   # #22 FarmField·Inventory
]

# `extends Node`(정확히 — Node2D·Control 등 파생은 제외)이면서 `class_name`을 가진 클래스 이름 집합.
func _node_ledger_classes() -> Dictionary:
	var out := {}
	var files: Array = []
	_all_gd_files("res://", files)
	for path in files:
		var lines := _lines_of_file(String(path))
		var is_node := false
		var cname := ""
		for i in mini(lines.size(), 6):
			var ln := lines[i].strip_edges()
			if ln == "extends Node":
				is_node = true
			elif ln.begins_with("class_name "):
				cname = ln.substr(11).strip_edges()
		if is_node and cname != "":
			out[cname] = true
	return out

# 그 파일이 트리 밖에서 만든 (변수명 → 클래스) 표.
func _new_locals_of(lines: PackedStringArray, classes: Dictionary) -> Dictionary:
	var out := {}
	var re := RegEx.new()
	re.compile("^\\t+var ([A-Za-z_][A-Za-z0-9_]*) := ([A-Za-z_][A-Za-z0-9_]*)\\.new\\(\\)")
	for ln in lines:
		var mt := re.search(ln)
		if mt == null:
			continue
		var cls := mt.get_string(2)
		if classes.has(cls):
			out[mt.get_string(1)] = cls
	return out

# 해제 문맥으로 읽히는 줄 전량(직접 `x.free()` + `for n in [ … ]` 배열 리터럴 줄).
func _free_context_text(lines: PackedStringArray) -> String:
	var parts: Array = []
	var in_list := false
	for ln in lines:
		if ln.contains(".free()") or ln.contains(".queue_free()"):
			parts.append(ln)
		var stripped := ln.strip_edges()
		if in_list:
			parts.append(ln)
			if stripped.ends_with("]:"):
				in_list = false
		elif stripped.begins_with("for ") and stripped.contains(" in [") and not stripped.ends_with("]:"):
			parts.append(ln)
			in_list = true
		elif stripped.begins_with("for ") and stripped.contains(" in ["):
			parts.append(ln)
	return "\n".join(PackedStringArray(parts))

func _check_harness_node_lifetime() -> void:
	print("── ⑱~㉒ #18~#22 하네스 노드 수명 ──")
	var classes := _node_ledger_classes()
	_check("⑱a-pre 무대: `extends Node` + `class_name` 클래스를 res:// 재귀 스캔으로 모았다(%d종 — Ranch·Inventory 포함)"
			% classes.size(),
		classes.has("Ranch") and classes.has("Inventory") and classes.has("Sprinkler")
		and classes.has("StorageChest") and classes.has("FarmField") and classes.has("Forage")
		and classes.has("Orchard") and classes.has("RarecrowLedger"))
	for path in _LEAK_TARGETS:
		var lines := _lines_of_file(String(path))
		var locals := _new_locals_of(lines, classes)
		var ctx := _free_context_text(lines)
		var missing: Array = []
		for v in locals:
			var re := RegEx.new()
			re.compile("\\b" + String(v) + "\\b")
			if re.search(ctx) == null:
				missing.append("%s(%s)" % [v, locals[v]])
		var base := String(path).get_file()
		_check("⑱b %s — 트리 밖 %s를 만들고 전량 해제한다%s"
				% [base, str(locals.values()).replace("\"", ""),
					"" if missing.is_empty() else " · 미해제 " + str(missing)],
			not locals.is_empty() and missing.is_empty())
	# 반례(올바른 형태의 선재 근거) — 이 규약은 하네스가 이미 알고 있던 것이다.
	var bot := "\n".join(_lines_of_file("res://playtest/playtest_bot.gd"))
	_check("⑱c 규약의 출처가 하네스 안에 있다(`playtest_bot.gd`의 그 주석·그 해제 줄)",
		bot.contains("SceneTree 밖에서 new()한 노드라 직접 정리한다") and bot.contains("n.free()"))


# ── ㉓ #23 타이틀의 "(F11)" 안내가 참이 된다 ─────────────────────────────────
var _fs_signal_seen := 0

func _on_title_fullscreen() -> void:
	_fs_signal_seen += 1

func _check_title_f11() -> void:
	print("── ㉓ #23 타이틀 F11 ──")
	var tlines := _lines_of_file("res://title_screen.gd")
	var tsrc := "\n".join(tlines)
	_check("㉓a-pre 무대: 설정 패널이 그 단축키를 광고한다(안내의 실물)", tsrc.contains("\"(F11)\""))
	var ts := TitleScreen.new()
	ts.fullscreen_nudged.connect(_on_title_fullscreen)
	_fs_signal_seen = 0
	var ev := InputEventKey.new()
	ev.keycode = KEY_F11
	ev.pressed = true
	ts._input(ev)
	_check("㉓b 타이틀에서 F11이 실제로 전체화면 신호를 올린다(광고한 그 키가 먹는다)",
		_fs_signal_seen == 1)
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_F11
	ev2.pressed = false
	ts._input(ev2)
	_check("㉓c 떼는 이벤트는 안 센다(한 번 누름 = 한 번 토글)", _fs_signal_seen == 1)
	ts.fullscreen_nudged.disconnect(_on_title_fullscreen)
	ts.free()
	_check("㉓d 적용·영속의 주인은 여전히 main 한 곳이다(이 화면은 신호만 올린다 — 체크박스와 같은 창구)",
		tsrc.contains("fullscreen_nudged.emit()") and not tsrc.contains("DisplayServer.window_set_mode"))


# ── ㉔ #24 창 모드가 앱 밖에서 바뀌어도 설정 값이 따라온다 ───────────────────
func _check_fullscreen_sync(m: Node) -> void:
	print("── ㉔ #24 창 모드 → 설정 값 동기화 ──")
	var cfg_prev := PackedByteArray()
	var had_cfg := FileAccess.file_exists(GameSettings.PATH)
	if had_cfg:
		var fr := FileAccess.open(GameSettings.PATH, FileAccess.READ)
		if fr != null:
			cfg_prev = fr.get_buffer(fr.get_length())
	var actual: bool = m._window_is_fullscreen()
	_check("㉔a-pre 무대: 실제 창 모드를 두 값(FULLSCREEN·EXCLUSIVE)으로만 센다(R13이 세운 술어)",
		_in_func("func _window_is_fullscreen", "Window.MODE_EXCLUSIVE_FULLSCREEN"))
	# OS 제스처 모사 — 창 쪽만 바뀌고 값이 안 따라온 상태를 직접 만든다.
	m.settings.fullscreen = not actual
	_check("㉔b-pre 무대: 값이 실제와 어긋났다(체크박스·settings.cfg가 거짓을 말하는 그 상태)",
		m.settings.fullscreen != m._window_is_fullscreen())
	m._sync_fullscreen_setting()
	_check("㉔c 동기화가 값을 실제로 끌어온다(표시·저장·재기동이 다시 같은 것을 말한다)",
		m.settings.fullscreen == m._window_is_fullscreen())
	_check("㉔d 멱등이다 — 이미 맞으면 아무것도 안 쓴다(저장 IO 0)",
		not m.settings.set_fullscreen(m._window_is_fullscreen()))
	_check("㉔e 창의 변화 신호가 그 동기화에 배선됐다(듣는 곳이 없던 것이 결함의 뿌리)",
		m.get_window().size_changed.is_connected(Callable(m, "_sync_fullscreen_setting")))
	_check("㉔f 방향이 `_apply_fullscreen`과 반대다(저건 값→창 · 이건 창→값 — 두 방향이 다 있어야 왕복이 닫힌다)",
		_in_func("func _sync_fullscreen_setting", "settings.set_fullscreen(_window_is_fullscreen())")
		and _in_func("func _apply_fullscreen", "win.mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED"))
	# 무대 원복(설정 파일 포함 — 이 스위트가 기기 환경설정을 바꾸지 않는다).
	if had_cfg:
		var fw := FileAccess.open(GameSettings.PATH, FileAccess.WRITE)
		if fw != null:
			fw.store_buffer(cfg_prev)
			fw.close()
		m.settings.load_settings()
	elif FileAccess.file_exists(GameSettings.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.PATH))


# ── ㉕ #25 볼륨 0% = 실제 무음 ───────────────────────────────────────────────
func _check_volume_floor(m: Node) -> void:
	print("── ㉕ #25 볼륨 바닥(0%) ──")
	var mi := AudioServer.get_bus_index(GameAudio.MUSIC_BUS)
	if mi == -1:
		_check("㉕a-pre 무대: Music 버스가 서 있다", false)
		return
	var vol_prev: float = m.settings.music_volume
	m.audio.set_music_volume(0.0)
	var db0 := AudioServer.get_bus_volume_db(mi)
	_check("㉕a 0%%면 실질 무음 바닥으로 내려간다(%.1f dB — settings.gd가 못 박은 \"0=무음\" 계약)" % db0,
		is_equal_approx(db0, GameAudio.MUTE_DB) and db0 <= -80.0)
	_check("㉕b 그 바닥은 크로스페이드용 값이 아니다(과도 값과 정상 값의 뜻이 다르다)",
		GameAudio.MUTE_DB < GameAudio.SILENT_DB and is_equal_approx(GameAudio.SILENT_DB, -40.0))
	m.audio.set_music_volume(0.002)
	var db_tiny := AudioServer.get_bus_volume_db(mi)
	_check("㉕c 단조롭다 — 0.002(%.1f dB)가 0.0보다 **크다**(종전엔 −54 dB로 더 조용한 역전이었다)" % db_tiny,
		db_tiny > db0)
	m.audio.set_music_volume(0.5)
	_check("㉕d 0이 아닌 값은 종전 그대로 `linear_to_db`다(바닥만 고쳤다)",
		is_equal_approx(AudioServer.get_bus_volume_db(mi), linear_to_db(0.5)))
	m.audio.set_music_volume(vol_prev)
	_check("㉕e 정리 — 설정 볼륨으로 되돌렸다",
		is_equal_approx(AudioServer.get_bus_volume_db(mi), linear_to_db(vol_prev)) or vol_prev <= 0.001)


# ── ㉖ #26 = #5 DUP: 배치 A의 카탈로그 파생이 이 시나리오를 덮는다 ───────────
func _check_greenhouse_days_dup(m: Node) -> void:
	print("── ㉖ #26 (DUP of #5) 늘봄방 공기 사전 고지 ──")
	var gh := Carpenter.build_days(Carpenter.PROJ_GREENHOUSE)
	var coop := Carpenter.build_days(Carpenter.PROJ_BIG_COOP)
	_check("㉖a-pre 무대: #26이 지목한 어긋남이 표에 실재한다(늘봄방 %d일 ≠ 큰 넋둥우리 %d일)"
			% [gh, coop],
		gh != coop)
	var header: String = m._woodshop_text()
	_check("㉖b 발주 **전** 고지가 늘봄방의 실제 공기를 포함한다(사기 전에 보는 그 화면)",
		header.contains(str(gh)))
	_check("㉖c 옛 하드코딩이 사라졌다 — 헤더가 한 프로젝트 값을 전 매대 규칙으로 말하지 않는다",
		not header.contains("공기 %d일" % coop))
	_check("㉖d 사전 고지와 사후 알림이 같은 원장을 본다(`Carpenter.build_days` 하나 — 1일 어긋남 0)",
		_in_func("func _build_days_text", "Carpenter.build_days(String(id))")
		and _in_func("func _try_order_build", "Carpenter.build_days(project_id)"))
