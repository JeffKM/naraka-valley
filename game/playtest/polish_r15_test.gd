extends SceneTree
# ★[폴리시 15회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#11).
#
# 렌즈: 단언 자멸(항진·퇴화 니들·공허 통과) · R14 diff 리뷰 · 온보딩 진실성.
#
# 이번 회차 배치 A는 **절반이 게임 코드가 아니라 판정식의 결함**이다(#0~#7). 그래서 이 스위트의
# 태도가 앞 회차와 갈린다: "고친 판정식이 실제로 하중을 받는가"를 재려면 그 판정식을 다시 흉내
# 내는 것으로는 부족하고, **판정식이 지키기로 한 계약 자체**를 여기서 독립적으로 재야 한다. 그래서
# ①·③·④·⑨·⑫는 소스 스캔이 아니라 라이브 상태를 굴려서 잰다.
#
# 무엇을 보증하나(번호 = 15회차 헌트 발견 인덱스):
#   ① #0 점괘 거울 "수치 노출 0" 판정이 `"%d" % (luck*100)`이라는 **평범한 정수 문자열**을 본문
#        전체에서 찾아, ◇예고 줄의 날짜 카운트다운("6일 뒤")과 겹치기만 하면 실패했다(HEAD 상시
#        적색 — 실제 누출이 들어와도 구분 불가). 여기선 계약을 직접 잰다: 예고 줄을 걷어낸 본문에
#        숫자가 한 글자도 없다(표본 5일이 아니라 **1..112 전수**).
#   ② #1 R14가 채취기의 수거·회수만 밑동으로 옮겨, 같은 나무의 **설치**는 통도 밑동도 한 조각 안
#        그려진 3칸 북쪽 캐노피 꼭대기에서만 성립했다(한 채취기의 동사들이 3칸 갈려 섰다).
#   ③ #2 폴리시 R11 ㉒b가 main.gd만 훑는 `_in_func`로 night_bar.gd의 `end_day`를 물어 항상 false를
#        받았고, `== false`가 항진이 되어 `abandon()`을 통째로 지워도 초록이었다.
#   ④ #3 건물 접지 ③의 3항 or 마지막 항이 같은 파일 45줄 위에서 이미 참으로 단언된 것이라, 잔디
#        술어가 전멸해도 통과했다.
#   ⑤ #4 동행 혼 ⑧c가 로드 정규화를 테스트 안에서 베껴 실행한 뒤 자기가 넣은 값을 되읽었다
#        (세이브 파일도 `_load_game`도 안 탄다 — 실제 정규화를 지워도 초록).
#   ⑥ #5 `_in_func` 니들이 함수 안 **주석 줄**에 먼저 걸려, 계약을 적어 둔 주석만 남기고 가드 항을
#        지워도 통과했다(polish_r13 ⑯a-pre · polish_r9 ⑲d 두 자리).
#   ⑦ #6 polish_r14 ③e·③f가 그 줄에서 만든 리터럴이 자기 부분문자열을 포함하는지 물었다(항진 —
#        대상 파일을 한 글자도 안 읽는다).
#   ⑧ #7 캐릭터 아크 다섯 스위트의 `_src()` 부정 단언이 파일 열기 실패 시 전부 공허하게 통과했다.
#   ⑨ #8 새 게임 키트의 **묘목**이 온보딩 PLANT 단계를 소비해, 다음 WATER 배너가 물을 줄 수 없는
#        칸(밭 원장이 아니라 orchard 원장)을 가리켰다 — 배너대로 해도 무알림 무동작.
#   ⑩ #9 HARVEST 안내의 시각 단서 "(황금)"이 실재하지 않는다(그레이박스 점 제거 후 남은 잔존 문구).
#   ⑪ #10 미호 온보딩 대사가 안식 농원에 없는 카페를 손가락질했다("저기 카페 보이지?" — M1.4에서
#        나루 마을로 이주).
#   ⑫ #11 튜토리얼 밭 안에서 **아직 존재하지 않는** 삽사리를 이유로 든 프롬프트가 1일차부터 떴다.
#
# 판정: #0~#11 전건 CONFIRMED(REFUTED·OWNER·DUP 없음).
#
# 하중 검증(계약을 일부러 깨고 빨개지는지 본 뒤 원복):
#   #0 `_weather_hint`에 숫자 한 글자 → ⑥d·①b red · #1 `_tapper_place_tile` 항등 퇴화 → ②b·②c·②f·②g
#   red · #2 `end_day`의 `abandon()` 삭제 → r11 ㉒b red · #3 `_g16_is_grass_patch` 상시 false →
#   접지 ③·④a red · #4 로드 정규화 두 줄 삭제 → soul_child ⑧c·⑤c red · #5 `not _sleeping` 항 삭제
#   (주석은 남김) → r13 ⑯a-pre·⑥ red · #6 나락 라벨의 `%%` 되돌림 → r14 ③e red.
#   ★ #0은 코드를 안 깨도 HEAD에서 이미 red였다(옛 판정식을 되돌려 재현 — 상시 적색 확인).
#
# 파생: #11이 삽사리 이름을 입양 뒤로 옮기면서 polish_r11 ⑧d가 깨졌다(그 줄이 재던 R11 계약은
#   "사유가 읽힌다"이지 "삽사리라고 적혀 있다"가 아니었다). ⑧d를 계약 쪽으로 되돌리고, 이름이
#   돌아오는 입양 뒤 갈래는 여기 ⑫e가 잇는다.
#
# 실행: ./run_tests.sh polish_r15   (헤드리스는 반드시 game/에서 · 순차)

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

func _dismiss_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 60:
		m.dialogue.advance()
		guard += 1

# ── 소스 스캔 헬퍼(polish_r7~r14의 그 관례) ─────────────────────────────────
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _text_of(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()

# 그 함수 몸통에서 니들이 처음 나오는 **코드** 줄(주석 줄은 건너뛴다 · 없으면 −1).
# ★ 이 헬퍼 자체가 ⑥의 관찰 도구다 — R15가 polish_r13·polish_r9에 세운 그 규약과 같은 형태로
#   구현해 두고, 니들이 주석이 아니라 실제 가드에 내려앉는지를 여기서 독립적으로 확인한다.
func _line_in_func(lines: PackedStringArray, fn_needle: String, needle: String,
		skip_comments: bool) -> int:
	var head := -1
	for i in range(lines.size()):
		if lines[i].contains(fn_needle):
			head = i
			break
	if head < 0:
		return -1
	for i in range(head + 1, lines.size()):
		if lines[i].begins_with("func "):
			return -1
		if skip_comments and lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			return i
	return -1

func _has_digit(s: String) -> bool:
	for i in range(s.length()):
		var ch := s[i]
		if ch >= "0" and ch <= "9":
			return true
	return false

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R15 회귀 — 배치 A(#0~#11) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)

	_check_forecast_numbers(m)
	_check_tapper_place_axis(m)
	_check_night_bar_end_day(m)
	_check_grass_predicate(m)
	_check_soul_load_roundtrip()
	_check_in_func_comment_skip()
	_check_r14_label_probe()
	_check_arc_src_guard()
	_check_sapling_onboarding(m)
	_check_harvest_guidance(m)
	_check_miho_cafe_line(m)
	_check_pet_tile_reason(m)

	m.queue_free()
	await process_frame
	cleaner.delete_save()
	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)


# ── ① #0 점괘 거울 — 예고 줄 밖 본문에 숫자 0 ────────────────────────────────
func _check_forecast_numbers(m: Node) -> void:
	print("── ① #0 명부의 운 수치 노출 0(예고 줄 제외 · 1..112 전수) ──")
	var day_before: int = m.clock.day
	var scanned := 0
	var forecast_lines := 0
	var leak := ""
	for d in range(1, 113):
		m.clock.day = d
		for raw in String(m._mirror_forecast_text()).split("\n"):
			var line := String(raw)
			if line.begins_with("◇"):
				forecast_lines += 1
				continue
			if line.strip_edges() == "":
				continue
			scanned += 1
			if _has_digit(line) and leak == "":
				leak = "day %d — %s" % [d, line]
	m.clock.day = day_before
	# 무대 가드 — 예고 줄이 **실제로 붙는** 무대여야 이 검사가 옛 결함을 재현할 수 있고(그래야
	# "예고 줄을 걷어낸다"가 의미를 갖는다), 걷어낸 뒤에도 잴 본문이 남아야 공허하지 않다.
	_check("①a 무대: 예고(◇) 줄이 실제로 붙는 달력이다(%d줄) · 걷어낸 뒤에도 본문이 남는다(%d줄)"
			% [forecast_lines, scanned],
		forecast_lines > 0 and scanned >= 112 * 4)
	_check("①b 예고 줄 밖 본문에 숫자가 한 글자도 없다%s"
			% ("" if leak == "" else " ← 누출: " + leak), leak == "")
	# 옛 퇴화 니들이 되돌아오지 않는다 — 운 값 ×100의 십진 문자열을 본문 전체에서 찾는 형태.
	# ★ 니들을 **조각내 잇는다**: 한 리터럴에 유효 지시자(`%d`)와 무효 지시자(` % (`)가 함께 들면
	#   polish_r14 ③b의 res:// 전수 서식 스캔이 이 줄을 잡는다(가드가 가드를 무는 자리 — R14 ③c의
	#   프로브가 같은 이유로 조각나 있다).
	var old_needle := "\"%d\" " + "% (v2 * 100.0)"
	_check("①c luck_forecast_test가 옛 퇴화 니들(운 값 ×100의 십진 문자열을 본문 전체에서 찾는 형태)을 안 쓴다",
		not _text_of("res://playtest/luck_forecast_test.gd").contains(old_needle))


# ── ② #1 채취기 — 설치·수거가 같은 칸에서 성립 ───────────────────────────────
func _check_tapper_place_axis(m: Node) -> void:
	print("── ② #1 안식 채취기 설치 축(발치 칸 → 앵커) ──")
	var drop_tiles := int(m._tapper_home_drop()) / int(m.TILE)
	var anchors: Array = m._home_tree_anchors()
	# 무대: 성숙 나무 앵커 하나를 원장에서 **파생**해 고른다(좌표 하드코딩 0).
	var anchor := Vector2i(-1, -1)
	for raw in anchors:
		var a: Vector2i = raw
		if m.tree_ledger.is_mature(RegionCatalog.HOME, a):
			anchor = a
			break
	_check("②a 무대: 안식 마당의 성숙 나무 앵커를 원장에서 찾았다(앵커 %d개 · 보정 %d칸)"
			% [anchors.size(), drop_tiles],
		anchor != Vector2i(-1, -1) and drop_tiles > 0 and m._region == RegionCatalog.HOME)
	if anchor == Vector2i(-1, -1):
		return
	var trunk := anchor + Vector2i(0, drop_tiles)
	# ㉠ 설치 축 — 발치(통이 그려지는 칸)를 겨눠도 설치가 성립한다.
	_check("②b 발치 칸을 겨누면 설치 원장 칸이 앵커로 되돌아온다(%s → %s)" % [str(trunk), str(anchor)],
		m._tapper_place_tile(trunk) == anchor)
	_check("②c 그래서 발치 칸에서 설치가 성립한다(옛 축은 여기서 거짓이었다)",
		m._can_place_tapper(m._tapper_place_tile(trunk)))
	# ㉡ 항등 보존 — 앵커 자신·나무 없는 칸·다른 구역은 손대지 않는다(숲 거동 불변의 근거).
	_check("②d 앵커 자신은 항등이다(설치 축이 앵커 칸을 빼앗지 않는다)",
		m._tapper_place_tile(anchor) == anchor)
	var barren := anchor + Vector2i(0, drop_tiles + 3)
	_check("②e 성숙 나무가 안 걸리는 칸은 항등이다(%s 그대로)" % str(barren),
		m._tapper_place_tile(barren) == barren)
	# ㉢ 한 채취기의 **전 동사가 같은 칸**에 선다 — 설치 → [F] 축까지 이어 확인.
	m.inventory.add_item(ItemCatalog.TAPPER, 1)
	m._place_tapper(m._tapper_place_tile(trunk))
	_check("②f 설치는 원장 앵커 키로 들어간다(세이브 키 불변)",
		m.tapper.has_at(m._region, anchor) and not m.tapper.has_at(m._region, trunk))
	_check("②g 같은 발치 칸이 [F] 축(`_tapper_ledger_tile`)에서도 앵커로 돌아온다 — 설치·수거 한 칸",
		m._tapper_ledger_tile(trunk) == anchor
		and m._tapper_prompt(m._tapper_ledger_tile(trunk)) != "")
	m.tapper.remove(m._region, anchor)


# ── ③ #2 night_bar.end_day — 정산 먼저, 그 다음 리셋 ─────────────────────────
func _check_night_bar_end_day(m: Node) -> void:
	print("── ③ #2 밤 바 `end_day` = 정산 → 리셋 ──")
	var bar = m.night_bar
	_check("③a-pre 무대: 밤 바가 서 있고 `abandon`·`end_day`를 갖는다",
		bar != null and bar.has_method("end_day") and bar.has_method("abandon"))
	if bar == null:
		return
	# 라이브 계약 — 연 밤을 마감하면 그 밤의 정산이 **먼저** 나가고 세션은 비워진다.
	# ★ 관측 그릇은 **제자리 변형**으로 채운다(`append`). GDScript 람다는 캡처를 **값으로** 뜨므로
	#   본문에서 `got = [...]`처럼 재대입하면 바깥 변수는 영원히 빈 배열로 남는다 — 그 형태로 쓰면
	#   "정산이 안 왔다"와 "관측을 못 했다"가 구분되지 않아, 이 회차가 잡는 바로 그 공허한 단언이
	#   된다(배열은 참조형이라 참조 복사본에 `append`하면 같은 그릇이 채워진다).
	bar.abandon()
	var opened: bool = bar.open_bar(19 * 60)
	bar._raided = 3
	bar._revenue = 700
	bar._left = 2
	var got: Array = []
	var cb := func(raided: int, revenue: int, left: int) -> void:
		got.append([raided, revenue, left])
	bar.closed.connect(cb)
	bar.end_day()
	bar.closed.disconnect(cb)
	_check("③b-pre 무대: 19:00에 바가 실제로 열렸다(영업창 안 — 안 열리면 아래가 공허해진다)", opened)
	_check("③b 연 밤의 마감은 그 밤의 값을 그대로 정산으로 쏜다(약탈·매출·이탈 = %s)" % str(got),
		got == [[3, 700, 2]])
	_check("③c 정산 뒤 세션이 비워진다(_opened·약탈·매출·이탈 전부 초기값)",
		not bar._opened and bar._raided == 0 and bar._revenue == 0 and bar._left == 0)
	# 안 연 밤은 정산이 없다(빈 밤엔 합산할 것이 없다 — ADR-0010 #6 옵트인).
	var got2: Array = []
	var cb2 := func(_r: int, _v: int, _l: int) -> void:
		got2.append(1)
	bar.closed.connect(cb2)
	bar.end_day()
	bar.closed.disconnect(cb2)
	_check("③d 안 연 밤의 마감은 정산을 안 쏜다(리셋만) — 같은 그릇이 ③b에선 찼으므로 관측은 살아 있다",
		got2.is_empty() and got.size() == 1)
	# 판정식 회귀 — ㉒b가 다시 항진으로 돌아가지 않는다(main.gd에 없는 함수를 `_in_func`로 묻는 형태).
	# ★ **코드 줄만** 본다. R15가 그 자리에 남긴 해설 주석이 옛 형태를 그대로 인용하므로, 파일 전체를
	#   훑으면 주석에 걸려 영원히 빨갛다 — 이 회차의 ⑥(주석 선걸림)과 같은 함정이 판정 축만 바꿔
	#   되돌아오는 자리다.
	var r11_dead := 0
	var r11_live := 0
	for raw in _lines_of_file("res://playtest/polish_r11_test.gd"):
		var ln := String(raw)
		if ln.strip_edges().begins_with("#"):
			continue
		if ln.contains("_in_func(\"func end_day\""):
			r11_dead += 1
		if ln.contains("_func_body_of(\"res://night_bar.gd\""):
			r11_live += 1
	_check("③e polish_r11 ㉒b가 night_bar.gd를 실제로 읽는다(죽은 형태 %d곳 · 산 형태 %d곳)"
			% [r11_dead, r11_live],
		r11_dead == 0 and r11_live > 0)


# ── ④ #3 잔디 술어가 패드 밖에서 갈린다 ──────────────────────────────────────
func _check_grass_predicate(m: Node) -> void:
	print("── ④ #3 잔디 술어 분별(패드 밖 마당) ──")
	var grass := 0
	var dirt := 0
	for y in range(m._outdoor_h):
		for x in range(m._grid_w):
			if m._g16_near_building(x, y):
				continue
			if m._g16_is_grass_patch(x, y):
				grass += 1
			else:
				dirt += 1
	_check("④a 패드 밖 마당에서 술어가 두 답을 다 낸다(잔디 %d칸 · 흙 %d칸)" % [grass, dirt],
		grass > 0 and dirt > 0)
	# 판정식 회귀 — ③의 마지막 항이 ①의 재진술로 돌아가지 않는다.
	_check("④b building_grounding ③이 `not _g16_near_building(60, 50)` 항으로 안 빠져나간다",
		not _text_of("res://playtest/building_grounding_test.gd").contains(
			"or not m._g16_near_building(60, 50)"))


# ── ⑤ #4 손상 세이브가 로드 경로를 지난다 ────────────────────────────────────
func _check_soul_load_roundtrip() -> void:
	print("── ⑤ #4 동행 혼 손상 방어가 왕복을 탄다 ──")
	var txt := _text_of("res://playtest/soul_child_test.gd")
	_check("⑤a-pre 무대: 스위트를 읽었다", txt.length() > 1000)
	_check("⑤a ⑧c가 슬롯 파일을 직접 손상시킨다(`_doctor_save` — 파일 위에서 키를 갈아 끼운다)",
		txt.contains("func _doctor_save") and txt.contains("_doctor_save(SAVE, \"soul_due_day\", 999)"))
	_check("⑤b 손상 뒤 **재부팅**으로 되읽는다(테스트 안에서 정규화를 베끼지 않는다)",
		not txt.contains("m3._soul_due_day = maxi(int(raw[\"soul_due_day\"]), 0)")
		and not txt.contains("var raw: Dictionary = {\"soul_born\": true"))
	# 그 정규화가 실제 로드 경로에 살아 있는가(스위트가 겨누는 그 세 줄).
	_check("⑤c main.gd `_load_game`이 탄생 뒤 예정을 0으로 접는다(스위트가 겨누는 계약의 실재)",
		_line_in_func(_src, "func _load_game", "_soul_due_day = maxi(int(data.get(\"soul_due_day\", 0)), 0)", true) >= 0
		and _line_in_func(_src, "func _load_game", "if _soul_born:", true) >= 0)


# ── ⑥ #5 `_in_func` 니들이 주석이 아니라 가드에 내려앉는다 ───────────────────
func _check_in_func_comment_skip() -> void:
	print("── ⑥ #5 `_in_func` 주석 선걸림 ──")
	# 관찰 대상은 두 스위트가 실제로 겨누는 그 자리다 — 주석을 건너뛰지 않으면 니들이 주석 줄에,
	# 건너뛰면 실제 가드 줄에 내려앉는다. 두 줄 번호가 **다르다**는 것이 옛 결함의 실재 증명이고,
	# 건너뛴 쪽이 가드 줄이라는 것이 수리의 실효 증명이다.
	for probe in [["func _close_spine_scene", "_sleeping", "polish_r13 ⑯a-pre"],
			["func _fire_pet_event", "_sleeping", "polish_r9 ⑲d"]]:
		var raw_hit := _line_in_func(_src, String(probe[0]), String(probe[1]), false)
		var code_hit := _line_in_func(_src, String(probe[0]), String(probe[1]), true)
		var raw_line := "" if raw_hit < 0 else String(_src[raw_hit]).strip_edges()
		var code_line := "" if code_hit < 0 else String(_src[code_hit]).strip_edges()
		_check("⑥ %s: 주석 스킵 없이는 주석 줄에 먼저 걸린다(%d행: %s…)"
				% [String(probe[2]), raw_hit + 1, raw_line.substr(0, 28)],
			raw_hit >= 0 and raw_line.begins_with("#"))
		_check("⑥ %s: 스킵하면 실제 가드 줄이다(%d행: %s…)"
				% [String(probe[2]), code_hit + 1, code_line.substr(0, 40)],
			code_hit >= 0 and not code_line.begins_with("#") and code_line.contains("_sleeping"))
	# 두 스위트의 헬퍼가 그 규약을 갖고 있다.
	for suite in ["res://playtest/polish_r13_test.gd", "res://playtest/polish_r9_test.gd"]:
		_check("⑥ %s 헬퍼가 주석 줄을 건너뛴다" % String(suite).get_file(),
			_text_of(suite).contains("strip_edges().begins_with(\"#\")"))


# ── ⑦ #6 polish_r14 ③e·③f가 대상 파일을 읽는다 ─────────────────────────────
func _check_r14_label_probe() -> void:
	print("── ⑦ #6 R14 라벨 검사의 항진 제거 ──")
	var txt := _text_of("res://playtest/polish_r14_test.gd")
	# ★ ①c와 같은 이유로 니들을 조각내 잇는다(한 리터럴에 유효·무효 지시자가 함께 들면 R14 ③b가
	#   이 줄을 잡는다).
	var old_inline := "(\"②b 낙하 층수(3~8, 10%%로 2x−1) — 실측 %d~%d\" " + "% [3, 15])"
	_check("⑦a 옛 인라인 리터럴 자기검사가 사라졌다(좌변이 그 줄에서 만들어진 상수)",
		not txt.contains(old_inline))
	_check("⑦b 이제 대상 두 파일을 실제로 연다",
		txt.contains("res://playtest/narak_run_test.gd") and txt.contains("res://playtest/mob_test.gd"))
	# 그 두 라벨이 실재하고 이스케이프가 온전하다(R14가 고친 자리 — 여기서도 독립으로 못 박는다).
	for probe in [["res://playtest/narak_run_test.gd", "②b 낙하 층수"],
			["res://playtest/mob_test.gd", "처치 롤이"]]:
		var found := ""
		for ln in _lines_of_file(String(probe[0])):
			if String(ln).contains(String(probe[1])):
				found = String(ln)
				break
		_check("⑦c %s의 「%s」 라벨이 살아 있고 퍼센트가 이스케이프돼 있다"
				% [String(probe[0]).get_file(), String(probe[1])],
			found != "" and found.contains("%%"))


# ── ⑧ #7 아크 다섯 스위트의 비어 있음 가드 ───────────────────────────────────
func _check_arc_src_guard() -> void:
	print("── ⑧ #7 캐릭터 아크 `_src()` 공허 통과 ──")
	# 분모를 세지 않는다 — 다섯 스위트를 이름으로 열고, 각자가 **자기 KID의 파일**을 실제로 읽을 수
	# 있는지와 그 사실을 단언으로 못 박았는지를 건별로 본다.
	for kid in ["mir", "kkaebi", "luca", "frosty", "gangrim"]:
		var suite := "res://playtest/%s_arc_test.gd" % kid
		var body := _text_of(suite)
		_check("⑧ %s: 스위트가 `KID`로 자기 캐릭터 파일을 지목한다(const KID := \"%s\")" % [kid, kid],
			body.contains("const KID := \"%s\"" % kid))
		_check("⑧ %s: 그 파일이 실재하고 본문이 있다(%d바이트)" % [kid, _text_of("res://%s.gd" % kid).length()],
			FileAccess.file_exists("res://%s.gd" % kid) and _text_of("res://%s.gd" % kid).length() > 2000)
		_check("⑧ %s: 부정 단언 앞에 비어 있음 가드가 선다(-pre 「실제로 읽었다」)" % kid,
			body.contains("를 실제로 읽었다(부정 단언이 공허하지 않다"))


# ── ⑨ #8 묘목이 온보딩 PLANT를 소비하지 않는다 ──────────────────────────────
func _check_sapling_onboarding(m: Node) -> void:
	print("── ⑨ #8 묘목 심기와 온보딩 PLANT ──")
	var ob = m.onboarding
	_check("⑨a-pre 무대: 온보딩이 서 있다", ob != null)
	if ob == null:
		return
	# 밭 파종만 그 단계를 넘긴다 — 과수 파종은 다른 원장이라 다른 동사다.
	ob.step = ob.PLANT
	m._advance_onboarding("묘목심기")
	_check("⑨b 묘목 심기는 PLANT 단계를 소비하지 않는다(다음 배너가 물 못 주는 칸을 안 가리킨다)",
		ob.step == ob.PLANT)
	m._advance_onboarding("심기")
	_check("⑨c 밭 파종은 그대로 WATER로 넘어간다(온보딩 사슬 불변)", ob.step == ob.WATER)
	# 시작 키트가 실제로 묘목을 함께 준다 — 이 시나리오가 신규 플레이어에게 닿는 근거.
	_check("⑨d 무대: 새 게임 키트에 묘목이 들어 있다(그래서 PLANT 단계에서 손에 잡힌다)",
		not Inventory.START_SAPLINGS.is_empty())
	_check("⑨e 과수 갈래가 밭 파종과 **다른 동사 이름**을 세운다(소스 — 자동 분기 0의 근거)",
		_line_in_func(_src, "func _use_tool", "verb = \"묘목심기\"", true) >= 0)
	ob.step = ob.PLANT


# ── ⑩ #9 HARVEST 안내가 실재하는 단서를 가리킨다 ────────────────────────────
func _check_harvest_guidance(m: Node) -> void:
	print("── ⑩ #9 HARVEST 안내의 시각 단서 ──")
	var ob = m.onboarding
	var prev: int = ob.step
	ob.step = ob.HARVEST
	var line: String = ob.guidance()
	ob.step = prev
	_check("⑩a-pre 무대: HARVEST 안내가 한 줄 나온다(%s)" % line, line.length() > 10)
	_check("⑩b 실재하지 않는 색 단서(「황금」)를 말하지 않는다", not line.contains("황금"))
	# 실제로 화면에 뜨는 단서를 가리킨다 — `_farm_prompt`가 성숙 칸에서 내는 그 문구와 같은 글자.
	_check("⑩c 대신 화면에 실제로 뜨는 프롬프트를 가리킨다(main.gd `_farm_prompt`의 그 문자열)",
		line.contains("[우클릭] 수확")
		and _line_in_func(_src, "func _farm_prompt", "return \"[우클릭] 수확\"", true) >= 0)
	# ★ 그리고 그 단서가 **실제로 화면에 뜬다.** 소스에 그 줄이 있다는 것과 플레이어가 그것을 본다는
	#   것은 다른 말이라, 스타터 밭 한 칸을 실제로 갈고 심고 다 키운 뒤 그 칸을 겨눠 프롬프트를 받아
	#   본다 — 배너가 약속한 글자와 화면에 뜨는 글자가 **같은 글자**여야 안내가 진실이다.
	#   (옛 "(황금)"은 여기서 절대 못 세운다: 성숙 칸을 황금으로 칠하는 코드가 저장소에 없으므로
	#    안내가 가리킬 수 있는 단서는 이 프롬프트뿐이다.)
	var t: Vector2i = m.STARTER_PATCH_RECT.position + Vector2i(1, 1)
	var fld = m._field_at(t)
	var crop: String = String(Inventory.START_SEEDS.keys()[0])
	var sowed: bool = fld.hoe(t) and fld.plant(t, crop)
	var guard := 0
	while not fld.is_mature(t) and guard < 40:
		fld.water(t)
		fld.advance_day()
		guard += 1
	for i in range(m.inventory.slots.size()):        # 맨손 기준으로 본다(묘목이 들려 있으면 과수 갈래가 먼저다)
		if m.inventory.id_at(i) == "":
			m.inventory.select(i)
			break
	var tgt_prev: Vector2i = m._target
	var valid_prev: bool = m._target_valid
	m._target = t
	m._target_valid = true
	var prompt: String = m._farm_prompt()
	m._target = tgt_prev
	m._target_valid = valid_prev
	_check("⑩d 라이브: 다 자란 스타터 밭 칸(%s)을 겨누면 안내가 약속한 그 글자가 실제로 뜬다(「%s」)"
			% [str(t), prompt],
		sowed and fld.is_mature(t) and prompt == "[우클릭] 수확" and line.contains(prompt))


# ── ⑪ #10 미호 대사가 실제 지리를 가리킨다 ──────────────────────────────────
func _check_miho_cafe_line(m: Node) -> void:
	print("── ⑪ #10 미호 온보딩 대사의 카페 지목 ──")
	var corpus := ""
	for ln in Miho.LINES_INTRO:
		corpus += String(ln) + "\n"
	_check("⑪a-pre 무대: 미호 ♡0 묶음을 읽었다(%d줄)" % Miho.LINES_INTRO.size(),
		Miho.LINES_INTRO.size() > 5 and corpus.contains("카페"))
	_check("⑪b 안식 농원에 없는 것을 손가락질하지 않는다(\"저기 카페 보이지\" 소멸)",
		not corpus.contains("저기 카페 보이지"))
	# 카페의 실제 구역을 **건물 등록에서 파생**해 확인하고, 대사가 그 구역 이름을 말하는지 본다.
	var cafe: Dictionary = m._buildings.get("카페", {})
	var cafe_region := String(cafe.get("region", ""))
	_check("⑪c 무대: 카페는 미호가 선 구역이 아니다(카페 %s ≠ 대화 자리 %s)"
			% [cafe_region, RegionCatalog.HOME],
		cafe_region != "" and cafe_region != RegionCatalog.HOME)
	_check("⑪d 대사가 그 구역을 이름으로 가리킨다(%s)" % cafe_region,
		corpus.contains(RegionCatalog.name_of(cafe_region)))


# ── ⑫ #11 삽사리 자리 문구는 삽사리가 있을 때만 ─────────────────────────────
func _check_pet_tile_reason(m: Node) -> void:
	print("── ⑫ #11 예약 칸 사유가 아직 없는 캐릭터를 안 부른다 ──")
	_check("⑫a-pre 무대: 삽사리 자리가 스타터 밭 안이고, 지금은 미입양이다",
		m.STARTER_PATCH_RECT.has_point(m.PET_TILE) and not m.pet.is_adopted())
	var before: String = m._reserved_tile_reason(m.PET_TILE)
	_check("⑫b 입양 전 사유가 삽사리를 호명하지 않는다(「%s」)" % before,
		not before.contains("삽사리"))
	_check("⑫c 그래도 침묵하지 않는다 — 동사는 막되 이유는 읽힌다(R11 계약 보존)",
		before != "" and before.contains("밭일은 못 한다"))
	# 형제 분기(미호 자리)는 주인이 실제로 서 있으므로 그대로 이름을 댄다.
	_check("⑫d 미호 자리 문구는 불변(그 주인은 실재한다)",
		String(m._reserved_tile_reason(m.MIHO_FIELD_TILE)).contains("미호"))
	# 입양 뒤에는 이름이 돌아온다.
	m.pet.adopt(m.pet.ADOPT_MIN_DAY)
	var after: String = m._reserved_tile_reason(m.PET_TILE)
	_check("⑫e 입양 뒤에는 삽사리를 호명한다(「%s」)" % after,
		m.pet.is_adopted() and after.contains("삽사리"))
