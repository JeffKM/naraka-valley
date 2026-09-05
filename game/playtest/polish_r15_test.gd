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
#   ⑬ #12 BGM·SFX 존재 판정이 `FileAccess.file_exists`라 **익스포트 빌드에서 전 오디오가 무음**이었다
#        (오디오는 임포트 자산이라 PCK엔 remap만 담긴다 — 원본 경로는 릴리스에 존재하지 않는다).
#   ⑭ #13 야생·희소 작물이 `CROP_SPRITES`에 키가 없어, 심은 뒤 수확까지 **빈 경작칸과 완전히 동일**했다.
#   ⑮ #14 인벤을 안 건드리는 구매(가구 세트 해금 등)는 프레임 무효화 트리거가 하나도 없어 헤더 냥·
#        행 잠금이 결제 전 값에 머물렀다.
#   ⑯ #15 집 꾸미기 모드 중 시계 판이 얼어붙었다 — 시간은 계속 흘러 24:00에 하루가 끝난다.
#   ⑰ #16 카페 마감 프레임에 무효화가 없어 좌석 손님 그림·인내심 바가 화면에 눌어붙었다(원장은 빈 좌석).
#   ⑱ #17 타수 게이지 분모가 현재 티어 파생이라, 같은 날 벼리면 비율이 음수가 되어 트랙 밖에 그려졌다.
#   ⑲ #18 가구 세트 안내가 [F10]을 광고했다 — 릴리스에선 죽은 디버그 키이고 실제 꾸미기 모드는 C다.
#   ⑳ #19 메뉴(백팩) 진입 키가 어디에도 없어, "자리를 비우고 다시"가 방법 없이 지시만 했다.
#   ㉑ #20 Shift 대량 구매가 전 매대에 배선돼 있는데 표기가 0곳이었다.
#   ㉒ #21 키 표기가 대괄호/괄호/무기호 세 갈래로 갈렸다(`[/]`는 판별 불가였다).
#   ㉓ #23 스택 개수 배지가 3~4자리에서 슬롯 밖으로 넘쳐 다음 칸 판에 먹혔다(원목 400~500이 정상 플레이).
#   ㉔ #22 **정보 정직성 축만** — 배너가 "어딘가로 가라"고 지시하면서 이동 키는 한 번도 말하지
#        않았다(유일한 이동 안내 문자열 readout은 대입 다음 줄에서 `visible = false`가 되어 영원히
#        안 뜬다). 첫 단계에 실제로 먹는 키를 붙이고, 그 표기가 InputMap과 어긋나지 않는지 잰다.
#
# 판정: #0~#21·#23 CONFIRMED. **#22는 축을 갈라 처리**했다 — 발견이 두 결함을 한 항목에 담고 있다:
#   ㉠ 정보 정직성("이동 키가 어디에도 광고되지 않는다") = CONFIRMED, 여기 ㉔가 봉합을 잰다.
#   ㉡ 조작 체계("타이틀은 WASD를 받는데 월드는 안 받는다") = **OWNER-DECISION**이라 코드 무수정.
#      해소는 "WASD를 이동에 묶는가"라는 결정이고, `ui_*`에 키를 얹으면 Godot의 Control 포커스
#      이동까지 함께 타므로 폴리시 회차가 단독으로 정할 자리가 아니다. 반대 방향(타이틀에서 WASD
#      제거)은 조작을 더 나쁘게 만든다. ㉔c가 그 비대칭을 **사실로 기록**해 owner 큐에 남긴다.
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
	# ── 배치 B(#12~#23) ──
	_check_audio_exists(m)
	_check_unarted_crops(m)
	await _check_frame_click_redraw(m)
	_check_deco_clock(m)
	_check_cafe_close_redraw(m)
	_check_hit_gauge_clamp(m)
	_check_deco_key_ad(m)
	_check_backpack_key_ad(m)
	_check_store_bulk_ad(m)
	_check_key_notation()
	_check_count_badges()
	_check_move_key_ad(m)

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
			# ★[폴리시 R23] **※ 줄도 뺀다** — 이 항이 막는 것은 머리말이 적은 대로 «명부의 운 *수치*»
			#   노출이고, ※ 줄에 실리는 숫자는 운이 아니라 **해금 문턱의 이름**이다
			#   (`Festival.unlock_hint` — "카페 1단"·"누적 서빙 매출 5000"). 그 줄은 R19·R22가
			#   나중에 얹은 것이라 이 전수 스캔이 상시 red를 물고 있었다(선재 결함 — R23 배치 B
			#   회귀에서 기준선 측정으로 드러났다). ◇ 예고 줄을 빼는 것과 정확히 같은 사유다.
			if line.begins_with("※"):
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


# ══ 배치 B(#12~#23) ══════════════════════════════════════════════════════════

# ── ⑬ #12 오디오 존재 판정이 remap을 따라간다 ────────────────────────────────
func _check_audio_exists(m: Node) -> void:
	print("── ⑬ #12 BGM·SFX 존재 판정(익스포트 안전) ──")
	var a = m.audio
	# 무대·분모는 **레지스트리 파생**이다(곡 목록·이벤트 목록을 여기 옮겨 적지 않는다).
	var phases: Array = a.BGM_STEM.keys()
	var events: Array = a.SFX_STEM.keys()
	var bgm_dead := ""
	var imported_proof := ""
	for ph in phases:
		var p: String = a.bgm_source(String(ph))
		if p == "":
			bgm_dead = String(ph)
		elif not FileAccess.file_exists(p + ".import"):
			imported_proof = p
	var sfx_dead := ""
	for e in events:
		var p2: String = a.sfx_source(String(e))
		if p2 == "":
			sfx_dead = String(e)
		elif not FileAccess.file_exists(p2 + ".import"):
			imported_proof = p2
	_check("⑬a-pre 무대: 곡 %d개·효과음 %d개가 등록돼 있다(표 파생)" % [phases.size(), events.size()],
		phases.size() > 0 and events.size() > 0)
	_check("⑬b 모든 phase가 실제 곡으로 해석된다(빈 경로 = 그 곡은 영원히 안 걸린다)%s"
			% ("" if bgm_dead == "" else " ← 죽은 phase: " + bgm_dead), bgm_dead == "")
	_check("⑬c 모든 SFX 이벤트가 실제 파일로 해석된다%s"
			% ("" if sfx_dead == "" else " ← 죽은 이벤트: " + sfx_dead), sfx_dead == "")
	# ★ 결함의 근거를 여기서 못 박는다 — 이 자산들은 **전부 임포트 자산**이다(`.import` 동반).
	#   그래서 PCK에 담기는 것은 `.godot/imported/*` + `.remap`이고 원본은 익스포트에 존재하지 않는다:
	#   `FileAccess.file_exists(원본)`은 에디터에서만 참이라 판정에 쓰면 릴리스에서 전 오디오가 무음이 된다.
	_check("⑬d 그 파일들은 전부 임포트 자산이다(`.import` 동반 — 원본은 PCK에 안 담긴다)%s"
			% ("" if imported_proof == "" else " ← .import 없음: " + imported_proof),
		imported_proof == "")
	# 판정식 회귀 — 죽은 형태가 코드 줄에 0곳(주석은 결함 해설이라 세지 않는다).
	var dead_calls := 0
	var live_calls := 0
	for raw in _lines_of_file("res://audio.gd"):
		var ln := String(raw)
		if ln.strip_edges().begins_with("#"):
			continue
		if ln.contains("FileAccess.file_exists"):
			dead_calls += 1
		if ln.contains("ResourceLoader.exists"):
			live_calls += 1
	_check("⑬e audio.gd가 `FileAccess.file_exists`로 존재를 묻지 않는다(죽은 형태 %d곳 · 산 형태 %d곳)"
			% [dead_calls, live_calls], dead_calls == 0 and live_calls >= 2)


# ── ⑭ #13 아트 없는 작물도 밭에 그려진다 ────────────────────────────────────
func _check_unarted_crops(m: Node) -> void:
	print("── ⑭ #13 야생·희소 작물의 폴백 그림 ──")
	# 분모는 **카탈로그 파생**이다 — "8종"을 여기 적지 않는다. CROP_SPRITES에 키가 생기면 이 목록이
	# 저절로 줄고, 마지막 한 종까지 아트가 들어오면 목록이 비어 ⑭a-pre가 그 사실을 알린다.
	var unarted: Array = []
	for cid in CropCatalog.CATALOG.keys():
		if not m.CROP_SPRITES.has(cid):
			unarted.append(String(cid))
	_check("⑭a-pre 무대: 3프레임 아트가 없는 심을 수 있는 작물이 %d종 있다(카탈로그 − CROP_SPRITES)"
			% unarted.size(), unarted.size() > 0)
	var blind := ""
	var wrong_species := ""
	var wrong_packet := ""
	for cid in unarted:
		var tex: Texture2D = m._unarted_crop_tex(cid)
		if tex == null:
			blind = cid
			continue
		var species: String = CropCatalog.wild_species(cid)
		if species != "":
			# 희소종 = 수확물이 한 종으로 확정 → 그 채집물 그림과 **같은 텍스처**여야 정직하다.
			if not m.FORAGE_ICONS.has(species) or tex != m.FORAGE_ICONS[species]:
				wrong_species = "%s→%s" % [cid, species]
		elif not m.SEED_PACKET_ICONS.has(cid) or tex != m.SEED_PACKET_ICONS[cid]:
			# 절기 모둠 = 수확 종이 롤 전까지 미정 → 그 씨앗 자신의 아이콘(약속하지 않는다).
			wrong_packet = cid
	_check("⑭b 그 전부가 그릴 그림을 갖는다 — 심으면 반드시 보인다%s"
			% ("" if blind == "" else " ← 여전히 안 보임: " + blind), blind == "")
	_check("⑭c 희소종은 **수확물 그 자체**를 보여 준다(채집물 스프라이트와 같은 텍스처)%s"
			% ("" if wrong_species == "" else " ← 어긋남: " + wrong_species), wrong_species == "")
	_check("⑭d 절기 모둠은 씨앗 아이콘이다 — 무엇이 나올지 약속하지 않는다%s"
			% ("" if wrong_packet == "" else " ← 어긋남: " + wrong_packet), wrong_packet == "")
	# 단계가 실제로 갈린다(작고 옅은 것 → 온전한 것). 성숙만 100%라 "다 자랐는가"가 한눈에 갈린다.
	var ramp_ok := true
	for i in range(1, m.UNARTED_STAGE_SCALE.size()):
		if float(m.UNARTED_STAGE_SCALE[i]) <= float(m.UNARTED_STAGE_SCALE[i - 1]) \
				or float(m.UNARTED_STAGE_ALPHA[i]) <= float(m.UNARTED_STAGE_ALPHA[i - 1]):
			ramp_ok = false
	_check("⑭e 단계 램프가 단조 증가하고 성숙만 온전하다(크기 %s · 농도 %s)"
			% [str(m.UNARTED_STAGE_SCALE), str(m.UNARTED_STAGE_ALPHA)],
		ramp_ok and float(m.UNARTED_STAGE_SCALE[-1]) == 1.0 and float(m.UNARTED_STAGE_ALPHA[-1]) == 1.0)
	# 라이브 — 이 경로가 **실제로 도달된다**: 야생 씨앗은 심을 때 치환되지 않고 그 id로 원장에 든다
	# (치환 분기는 혼합 씨앗만 잡는다). 그래서 옛 `continue`가 곧 "빈 칸과 동일"이었다.
	# 라이브 프로브는 **야생 작물**로 고른다 — 미등록 목록에는 혼합 씨앗도 들어 있는데 그쪽은 심는
	# 순간 정규 작물로 치환돼(`is_mixed` 분기) 이 폴백 경로에 애초에 안 닿는다.
	var wild_id := ""
	for cid in unarted:
		if CropCatalog.is_wild(String(cid)):
			wild_id = String(cid)
			break
	if wild_id != "":
		var t: Vector2i = m.STARTER_PATCH_RECT.position + Vector2i(3, 3)
		var fld = m._field_at(t)
		var sowed: bool = fld.hoe(t) and fld.plant(t, wild_id)
		_check("⑭f 라이브: 야생 씨앗은 치환 없이 그 id로 밭 원장에 든다(폴백 경로가 실제로 도달된다) — %s"
				% fld.crop_of(t),
			sowed and fld.crop_of(t) == wild_id and not CropCatalog.is_mixed(wild_id)
			and m._unarted_crop_tex(fld.crop_of(t)) != null)
		fld.remove_plant(t)


# ── ⑮ #14 프레임 클릭이 언제나 다시 그리기를 부른다 ─────────────────────────
var _drew_frame := false

func _check_frame_click_redraw(m: Node) -> void:
	print("── ⑮ #14 매대 클릭 → 프레임 무효화 ──")
	# ★ 무대는 **매대**다. 메뉴 탭은 main이 매 프레임 `set_hearts`/`set_skills`/`set_inv_info`로
	#   값을 밀어 넣고 그 세터들이 스스로 `queue_redraw`를 부르므로 늘 다시 그려진다 — 거기선 무엇을
	#   해도 초록이라 아무것도 못 잰다. 매대는 정반대로 `store_text`·`store_items`가 세터 없는 평범한
	#   var라 값만 갱신되고 무효화가 안 걸렸다. 결함이 실제로 살던 자리가 여기다.
	var f = m.frame
	f.open(f.CTX_STORE)
	await process_frame
	await process_frame                      # 열림에 딸린 첫 그림을 먼저 흘려보낸다
	f.draw.connect(_on_frame_drew)
	# ★ **무대 가드가 이 검사의 절반이다.** 가만히 둔 프레임이 매 프레임 다시 그려지고 있다면
	#   아래 단언은 클릭과 무관하게 늘 참이 되어 아무것도 안 재게 된다(이 회차가 잡는 공허한 단언).
	#   그래서 먼저 "아무 일 없는 프레임엔 안 그린다"를 확인하고, 그 다음에 클릭 한 번을 넣는다.
	_drew_frame = false
	await process_frame
	await process_frame
	var idle_drew := _drew_frame
	_drew_frame = false
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(4.0, 4.0)          # 어느 행에도 안 걸리는 자리 — 꼬리의 무효화만 잰다
	f._gui_input(ev)
	await process_frame
	await process_frame
	var click_drew := _drew_frame
	f.draw.disconnect(_on_frame_drew)
	f.close()
	_check("⑮a-pre 무대: 가만히 둔 프레임은 다시 안 그려진다(아래 단언이 공허하지 않다)", not idle_drew)
	_check("⑮a 그런데 클릭 한 번은 다시 그리기 한 번을 부른다(인벤을 안 건드리는 구매도 낡지 않는다)",
		click_drew)
	# 그 낡음의 실제 피해자 — 인벤토리를 한 톨도 안 건드리는 구매 경로가 실재한다.
	_check("⑮b 무대: 가구 세트 해금은 인벤을 안 건드린다(그래서 `inv.changed`가 덮어 주지 않았다)",
		_line_in_func(_src, "func _try_buy_deco_set", "home_deco.unlock(set_id)", true) >= 0
		and _line_in_func(_src, "func _try_buy_deco_set", "inventory.add_item", true) < 0)

func _on_frame_drew() -> void:
	_drew_frame = true


# ── ⑯ #15 꾸미기 모드 중에도 시계 판이 참이다 ───────────────────────────────
func _check_deco_clock(m: Node) -> void:
	print("── ⑯ #15 꾸미기 모드 시계 갱신 ──")
	var hud = m.clock_hud
	_check("⑯a-pre 무대: 시계 판이 서 있고 꾸미기 모드는 시계를 멈추지 않는다(`clock.running` 무접촉)",
		hud != null and _line_in_func(_src, "func _toggle_deco_mode", "clock.running", true) < 0)
	if hud == null:
		return
	var deco_prev: bool = m._deco_mode
	var min_prev: float = m.clock.minutes
	m._deco_mode = true
	m.clock.minutes = 8.0 * 60.0
	m._refresh_clock_hud()
	var t_before: String = hud._time
	m.clock.minutes = 14.0 * 60.0 + 20.0
	m._process(0.0)                            # 꾸미기 모드의 이른 return을 그대로 탄다
	var t_after: String = hud._time
	m._deco_mode = deco_prev
	m.clock.minutes = min_prev
	m._process(0.0)
	_check("⑯b 꾸미기 중에 시간이 흐르면 판도 따라 움직인다(「%s」 → 「%s」)" % [t_before, t_after],
		t_before != t_after and t_after.contains("14:20"))


# ── ⑰ #16 카페·밤 바가 닫히는 프레임까지 그려진다 ──────────────────────────
func _check_cafe_close_redraw(m: Node) -> void:
	print("── ⑰ #16 마감 프레임 잔상 ──")
	# 래치는 "직전 프레임에 그렸는가"다 — 마감 전이가 tick **안에서** 일어나 그 프레임엔 이미
	# 닫힌 것으로 읽히므로, 이 래치가 없으면 손님 그림을 지울 마지막 한 프레임이 사라진다.
	_check("⑰a-pre 무대: 마감 전이가 tick 안에서 일어난다(그 프레임엔 `is_open()`이 이미 거짓)",
		_line_in_func(_lines_of_file("res://cafe.gd"), "func tick", "_close_shop()", true) >= 0)
	# ★ **무효화 가드 자체**를 겨눈다(래치 변수의 존재가 아니라). 종전 판정은 `_cafe_drawn_open`이
	#   어딘가에 나오기만 하면 참이라, 대입은 남기고 `if` 조건에서만 그 항을 빼도 초록이었다 —
	#   그런데 잔상을 지우는 것은 대입이 아니라 **조건**이다(하중 검증에서 실제로 드러난 자리).
	var lit := _line_in_func(_src, "func _process",
		"if cafe_open_now or _cafe_drawn_open or _cheki_offer_secs > 0.0:", true)
	var lit2 := _line_in_func(_src, "func _process",
		"if bar_active_now or _bar_drawn_active or _cocktail_offer_secs > 0.0:", true)
	_check("⑰b 무효화 가드가 두 래치를 **조건에서** 든다(카페 %d행 · 밤 바 %d행)" % [lit + 1, lit2 + 1],
		lit >= 0 and lit2 >= 0)
	# 라이브 — 열었다 닫는 두 프레임에서 래치가 참 → 거짓으로 내려간다(그 사이 프레임이 redraw 대상).
	var open_prev: bool = m.cafe._open
	m.cafe._open = true
	m._process(0.0)
	var latched: bool = m._cafe_drawn_open
	m.cafe._open = false
	m._process(0.0)                            # 이 프레임이 잔상을 지우는 마지막 한 장이다
	var cleared: bool = not m._cafe_drawn_open
	m.cafe._open = open_prev
	m._process(0.0)
	_check("⑰c 열린 프레임에 래치가 서고(%s) 닫힌 다음 프레임에 내려간다(%s) — 그 사이 한 장이 잔상을 지운다"
			% [str(latched), str(cleared)], latched and cleared)


# ── ⑱ #17 타수 게이지가 트랙을 안 벗어난다 ──────────────────────────────────
func _check_hit_gauge_clamp(m: Node) -> void:
	print("── ⑱ #17 광맥 타수 게이지 경계 ──")
	# 무대: 티어가 오르면 필요 타수가 **준다** → 같은 날 벼리면 need < done이 실제로 성립한다
	#   (done은 때린 시점 티어로 원장에 쌓이고 리셋은 날이 갈릴 때뿐이다). 값은 표에서 파생한다.
	var lo := ToolTier.pickaxe_gem_hits(0)
	var hi := ToolTier.pickaxe_gem_hits(ToolTier.MAX_TIER)
	_check("⑱a-pre 무대: 곡괭이를 벼리면 보석 광맥 필요 타수가 준다(%d타 → %d타 — need<done 도달 가능)"
			% [lo, hi], hi < lo)
	# 클램프의 자리는 **그림 쪽**이다 — 이 게이지를 쓰는 자리가 갱도·나락 둘이고 앞으로 늘 수 있는데,
	# 트랙을 안 벗어나는 것은 호출부의 사정이 아니라 이 그림의 불변식이라서다.
	_check("⑱b `_draw_hit_gauge`가 받은 비율을 트랙 안으로 접는다(음수 폭 rect 불가)",
		_line_in_func(_src, "func _draw_hit_gauge", "clampf(ratio, 0.0, 1.0)", true) >= 0)
	# 옛 결함의 산술을 그대로 재현해 클램프 전 값이 실제로 음수였음을 못 박는다(0티어 4타 → 2티어).
	var done := lo - 1
	var need := ToolTier.pickaxe_gem_hits(2)
	var raw := float(need - done) / float(need)
	_check("⑱c 벼린 뒤의 원시 비율은 음수다(%d타 친 광맥 · 새 분모 %d → %.3f) — 클램프가 없으면 트랙 밖"
			% [done, need, raw], raw < 0.0 and clampf(raw, 0.0, 1.0) == 0.0)


# ── ⑲ #18 가구 세트 안내가 살아 있는 키를 가리킨다 ──────────────────────────
func _check_deco_key_ad(m: Node) -> void:
	print("── ⑲ #18 가구 세트 배치 안내 키 ──")
	# 광고 문구 ↔ InputMap 실키 대조 — 키 이름을 여기 옮겨 적지 않고 **InputMap에서 파생**한다.
	var deco_key := _key_label_of("deco_mode")
	var place_key := _key_label_of("place_mode")
	_check("⑲a-pre 무대: 꾸미기 모드는 %s · 저작 도구는 %s(둘은 다른 키다)" % [deco_key, place_key],
		deco_key != "" and place_key != "" and deco_key != place_key)
	# 저작 도구는 릴리스에서 죽은 키다 — 그래서 그걸 광고하면 안 되는 것이지, 표기가 예뻐서가 아니다.
	_check("⑲b 저작 도구 폴링이 디버그 빌드 가드 뒤에 있다(릴리스에선 그 키가 무반응)",
		_line_in_func(_src, "func _process", "OS.is_debug_build() and Input.is_action_just_pressed(\"place_mode\")", true) >= 0)
	# 라이브 — 실제로 세트를 사서 그 알림을 받아 본다.
	var set_id := ""
	for sid in HomeDecoCatalog.SETS.keys():
		if HomeDecoCatalog.price_of(String(sid)) > 0 and not m.home_deco.is_unlocked(String(sid)):
			set_id = String(sid)
			break
	m.wallet.gold = 999999
	var bought: bool = set_id != "" and m._try_buy_deco_set(set_id)
	var msg := _last_notice(m)
	_check("⑲c 라이브: 가구 세트를 사면 안내가 뜬다(%s) — 「%s」" % [set_id, msg], bought and msg != "")
	_check("⑲d 그 안내가 가리키는 키가 **꾸미기 모드에 실제로 묶인 키**다([%s] 표기 · 죽은 [%s] 소멸)"
			% [deco_key, place_key],
		msg.contains("[%s]" % deco_key) and not msg.contains("[%s]" % place_key))

# 액션에 묶인 첫 키보드 이벤트의 표기(InputMap 파생 — 키 이름 하드코딩 0). 없으면 "".
func _key_label_of(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k != null:
			return OS.get_keycode_string(k.physical_keycode)
	return ""


# ── ⑳ #19 "자리를 비우고" 지시가 가방 여는 법을 함께 말한다 ────────────────
func _check_backpack_key_ad(m: Node) -> void:
	print("── ⑳ #19 백팩 만재 안내의 진입 키 ──")
	var menu_key := _key_label_of("menu_toggle")
	var tab_key := _key_label_of("menu_tab")   # ★[폴리시 R17 #2] 프레임 안에서 가방 탭으로 가는 키
	_check("⑳a-pre 무대: 메뉴를 여는 키는 %s 하나뿐이고, 그 안 탭 순환은 %s다" % [menu_key, tab_key],
		menu_key != "" and tab_key != ""
			and _line_in_func(_src, "func _process", "Input.is_action_just_pressed(\"menu_toggle\")", true) >= 0
			and _line_in_func(_src, "func _process", "frame.cycle_tab()", true) >= 0)
	# 분모는 소스 파생 — "자리를 비우고"라고 **지시하는** 알림을 전수로 모아 그 전부를 본다.
	# ★[폴리시 R16 #3] 판정을 **키**가 아니라 계약("가는 법을 함께 말한다")으로 되돌렸다. 종전엔
	#   `[Tab]` 한 문자열만 봤는데, 그 알림 하나(`_on_frame_craft`)는 **메뉴 프레임이 열려 있는
	#   동안에만** 발화한다 — 그 상태의 Tab은 `_close_frame()`이라 안내대로 누르면 가방이 *닫히고*,
	#   백팩 그리드는 이미 같은 프레임 아래쪽에 그려져 있다. 거기서 참인 방법은 키가 아니라 자리다.
	#   그래서 프레임 안에서 발화하는 줄은 **어디를 보라고 말하는가**로 잰다(polish_r16 ④가 짝).
	var told := 0
	var silent: Array = []
	var cur_fn := ""
	for raw in _src:
		var ln := String(raw)
		if ln.begins_with("func "):
			cur_fn = ln.substr(5, maxi(ln.find("("), 5) - 5)
		if ln.strip_edges().begins_with("#") or not ln.contains("_notice(") \
				or not ln.contains("자리를 비우고"):
			continue
		told += 1
		var in_frame := cur_fn.begins_with("_on_frame_")
		# ★[폴리시 R17 #2] 프레임 안 줄의 판정을 "아래 가방" 한 문자열에서 **계약**으로 넓혔다.
		#   R16 #3이 그 문구를 고를 때 든 근거("백팩 그리드가 같은 프레임 아래쪽에 이미 있다")가
		#   제작 탭에서는 거짓이었다 — `_draw`는 인벤 탭에서만 백팩을 그린다. 그래서 참인 방법이
		#   자리가 아니라 **탭 순환 키**로 갈렸다. 둘 다 "가방으로 가는 법"이므로 계약은 그대로다:
		#   가방을 이름으로 부르고, 거기 닿는 길(자리 「아래」 또는 실제로 묶인 키)을 함께 댈 것.
		var told_how := (ln.contains("가방")
			and (ln.contains("아래") or ln.contains("[%s]" % tab_key))) if in_frame \
			else ln.contains("[%s]" % menu_key)
		if not told_how:
			silent.append(ln.strip_edges().substr(0, 40))
	_check("⑳b-pre 무대: 자리를 비우라고 지시하는 알림이 %d줄 있다(소스 전수 — 명단 하드코딩 0)" % told,
		told > 0)
	_check("⑳c 그 전부가 가는 법을 함께 말한다 — 월드 동작은 여는 키[%s], 프레임 안에서 뜨는 줄은"
			% menu_key + " 백팩의 자리(아래) 또는 탭 키[%s]" % tab_key
			+ "(지시만 하고 방법은 안 알려 주지 않는다)%s"
			% ("" if silent.is_empty() else " ← 침묵: " + str(silent)), silent.is_empty())


# ── ㉑ #20 Shift 대량 구매가 화면에 표기된다(그리고 그 표기가 참이다) ───────
func _check_store_bulk_ad(m: Node) -> void:
	print("── ㉑ #20 대량 구매 표기 ──")
	var f = m.frame
	f.open(f.CTX_STORE)
	m._process(0.0)
	_check("㉑a 만물상을 열면 프레임이 묶음 크기를 받는다(main `STORE_BULK` 단일 출처 — %d)"
			% f.store_bulk, f.store_bulk == m.STORE_BULK and m.STORE_BULK > 1)
	# 표기가 참인가 = 그만큼 실제로 사지는가(라이브).
	# 살 씨앗은 **지금 진열된 행**에서 고른다(절기 게이팅을 스스로 통과한 것만 매대에 뜬다).
	var crop := ""
	for r in f.store_items:
		if String((r as Dictionary).get("kind", "")) == "seed":
			crop = String((r as Dictionary).get("buy_id", ""))
			break
	m.wallet.gold = 999999
	var before: int = m.inventory.seed_count(crop) if crop != "" else -1
	if crop != "":
		m._on_frame_buy_seed(crop, true)
	var after: int = m.inventory.seed_count(crop) if crop != "" else -1
	f.close()
	_check("㉑b 표기가 참이다 — Shift 구매가 실제로 그 수만큼 들어온다(%s: %d → %d)"
			% [crop, before, after],
		crop != "" and after - before == m.STORE_BULK)
	# 1회성 행에는 그 약속을 안 건다 — 안내와 실동작이 갈리면 그것이 곧 #18과 같은 거짓 광고다.
	var exempt_wrong: Array = []
	for k in m.BULK_EXEMPT_KINDS:
		if m.kind_takes_bulk(String(k)):
			exempt_wrong.append(String(k))
		if _line_in_func(_src, "func _on_frame_buy_store_item", "\"%s\"" % String(k), true) < 0:
			exempt_wrong.append("%s(디스패치에 없음)" % String(k))
	_check("㉑c 1회성 kind %d종이 전부 대량 예외이고 디스패치에도 실재한다%s"
			% [m.BULK_EXEMPT_KINDS.size(), "" if exempt_wrong.is_empty() else " ← " + str(exempt_wrong)],
		not m.BULK_EXEMPT_KINDS.is_empty() and exempt_wrong.is_empty())
	# 반대 축 — 수량을 실제로 태우는 세 kind는 예외 목록에 **없어야** 한다(목록이 과잉 확장되면 표기가 사라진다).
	var bulk_kinds := ["fest_seed", "ped_seed", "ped_item"]
	var mis: Array = []
	for k in bulk_kinds:
		if not m.kind_takes_bulk(k):
			mis.append(k)
	_check("㉑d 수량을 태우는 kind는 예외가 아니다(%s)%s" % [str(bulk_kinds),
			"" if mis.is_empty() else " ← 잘못 제외: " + str(mis)], mis.is_empty())
	_check("㉑e 표기는 매대가 낱개 품목을 가질 때만 뜬다(1회성만 있는 매대엔 0 — 거짓 약속 0)",
		not m._store_rows_take_bulk([{"kind": "deco"}, {"kind": "build"}])
		and m._store_rows_take_bulk([{"kind": "deco"}, {"kind": "seed"}]))


# ── ㉒ #21 키 표기가 한 관례로 선다 ─────────────────────────────────────────
func _check_key_notation() -> void:
	print("── ㉒ #21 키 표기 관례 ──")
	# 지배 관례는 대괄호다. 괄호형 "(F11)"이 표시 문자열에 남아 있지 않은지 **전 .gd 전수**로 본다.
	var files: Array = []
	_all_gd_files("res://", files)
	var paren: Array = []
	for path in files:
		if String(path).begins_with("res://playtest/"):
			continue
		var plines := _lines_of_file(String(path))
		for i in plines.size():
			var ln := String(plines[i])
			if ln.strip_edges().begins_with("#"):
				continue
			if ln.contains("\"(F11)\""):
				paren.append("%s:%d" % [String(path).get_file(), i + 1])
	_check("㉒a-pre 무대: 스캔 대상 .gd %d개(res:// 재귀 — 분모 하드코딩 0)" % files.size(),
		files.size() > 100)
	_check("㉒b 괄호형 키 표기가 0곳이다(대괄호 관례로 통일)%s"
			% ("" if paren.is_empty() else " ← 잔존: " + str(paren)), paren.is_empty())
	# 꾸미기 안내 한 줄 — 옛 문구는 한 문장 안에서 무기호와 기호를 섞어 `[/]`가 "[ 와 ] 키"인지
	# "/ 키"인지 판별 불가였다. 대괄호는 키 표기 전용으로 두고, 기호가 곧 키인 둘은 「」로 감싼다.
	# ★[폴리시 R16 #1] 안내가 **두 줄로 나뉘었다**(한 줄 819px이 620px 한계를 넘어 뒤가 화면 밖으로
	#   나갔다). 재는 계약은 그대로 "표기가 대괄호 관례를 따른다"이므로, 한 줄이 아니라 진입 안내
	#   **전체**를 모아 본다(어느 줄에 실렸는가는 이 단언이 물을 것이 아니다).
	var deco_lines: Array = []
	var deco_fn := ""
	for raw in _src:
		var ln := String(raw)
		if ln.begins_with("func "):
			deco_fn = ln.substr(5, maxi(ln.find("("), 5) - 5)
		if deco_fn == "_toggle_deco_mode" and not ln.strip_edges().begins_with("#") \
				and ln.contains("_notice("):
			deco_lines.append(ln.strip_edges())
	var deco_line := " ".join(deco_lines)
	_check("㉒c 꾸미기 진입 안내(%d줄)가 대괄호 관례를 따르고 모호한 `[/]`가 없다 — %s"
			% [deco_lines.size(), deco_line.substr(0, 60)],
		deco_lines.size() >= 1 and deco_line.contains("[C]") and deco_line.contains("[R]")
		and not deco_line.contains("[/]") and not deco_line.contains("C=끄기"))

func _all_gd_files(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var nm := d.get_next()
	while nm != "":
		if nm.begins_with("."):
			nm = d.get_next()
			continue
		var full := dir_path.path_join(nm)
		if d.current_is_dir():
			_all_gd_files(full, out)
		elif nm.ends_with(".gd"):
			out.append(full)
		nm = d.get_next()
	d.list_dir_end()


# ── ㉓ #23 스택 배지가 슬롯 안에 머문다 ─────────────────────────────────────
func _check_count_badges() -> void:
	print("── ㉓ #23 스택 개수 배지 경계 ──")
	# 무대: 게임이 스스로 3자리 스택을 요구한다(건축 자재) — 인벤엔 스택 상한이 없다.
	var need_wood := 0
	for pid in Carpenter.PROJECTS.keys():
		need_wood = maxi(need_wood, int((Carpenter.PROJECTS[pid] as Dictionary).get("wood", 0)))
	_check("㉓a-pre 무대: 건축 의뢰가 요구하는 최대 원목이 %d개다(3자리 스택은 정상 플레이)" % need_wood,
		need_wood >= 100)
	# 배지 오른쪽 끝이 슬롯 안에 머무는가 — **실제 글자 폭을 재서** 본다(관례: text_width 우측 정렬).
	var worst := str(need_wood * 10)          # 한 자리 더 여유를 두고 최악을 잡는다
	var hot_x: float = float(HotbarHud.SLOT_PX) - 2.0 - HanjiUi.text_width(worst, 10)
	var inv_x: float = float(InventoryFrame.SLOT) - 4.0 - HanjiUi.text_width(worst, 13)
	_check("㉓b 핫바 배지가 슬롯 안에 들어간다(%s · 시작 %.1f ≥ 0 · 끝 %.1f ≤ %d)"
			% [worst, hot_x, hot_x + HanjiUi.text_width(worst, 10), HotbarHud.SLOT_PX],
		hot_x >= 0.0 and hot_x + HanjiUi.text_width(worst, 10) <= float(HotbarHud.SLOT_PX))
	_check("㉓c 백팩·상자 배지도 칸 안에 들어간다(시작 %.1f ≥ 0 · 끝 %.1f ≤ %d)"
			% [inv_x, inv_x + HanjiUi.text_width(worst, 13), InventoryFrame.SLOT],
		inv_x >= 0.0 and inv_x + HanjiUi.text_width(worst, 13) <= float(InventoryFrame.SLOT))
	# 옛 좌측정렬 고정 오프셋이 실제로 넘쳤다는 것 — 그래서 다음 칸 plate가 자릿수를 덮었다.
	var old_left: float = float(HotbarHud.SLOT_PX) - 11.0
	_check("㉓d 옛 고정 오프셋은 넘쳤다(시작 %.1f + 글자 %.1f > 칸 %d — 다음 칸 판에 먹혔다)"
			% [old_left, HanjiUi.text_width(worst, 10), HotbarHud.SLOT_PX],
		old_left + HanjiUi.text_width(worst, 10) > float(HotbarHud.SLOT_PX))
	# ★ 위 셋은 **치수 산술**이라 그리는 코드가 옛 형태로 돌아가도 그대로 참이다(하중 검증에서
	#   드러난 자리). 그래서 배지를 그리는 세 자리가 실제로 폭을 재는지 여기서 함께 못 박는다 —
	#   자리는 파일에서 파생한다(고정 offset은 이 관례를 못 지킨다).
	# 자리는 `var cnt := str(...)`로 파생한다(파일·행 번호 하드코딩 0). 그 바로 뒤 두 줄이 배지를
	# 그리는 호출이고, 거기서 폭을 재지 않으면 고정 offset이 남아 있다는 뜻이다.
	var sites := 0
	var fixed_offset: Array = []
	for path in ["res://hotbar_hud.gd", "res://inv_frame.gd"]:
		var plines := _lines_of_file(path)
		for i in plines.size():
			if not String(plines[i]).contains("var cnt := str("):
				continue
			sites += 1
			var call_txt := ""
			for j in range(i + 1, mini(i + 3, plines.size())):
				call_txt += String(plines[j])
			if not call_txt.contains("HanjiUi.text_width(cnt,"):
				fixed_offset.append("%s:%d" % [path.get_file(), i + 1])
	_check("㉓e-pre 무대: 개수 배지를 그리는 자리를 %d곳 찾았다(핫바·백팩·상자 — 소스 파생)" % sites,
		sites >= 3)
	_check("㉓e 그 전부가 글자 폭을 재서 맞춘다(고정 offset 0곳)%s"
			% ("" if fixed_offset.is_empty() else " ← 고정 offset 잔존: " + str(fixed_offset)),
		fixed_offset.is_empty())

# 마지막 알림 줄(notice_feed는 최신이 배열 끝).
func _last_notice(m: Node) -> String:
	var items: Array = m.notice_feed._items
	return "" if items.is_empty() else String(items[items.size() - 1]["text"])


# ── ㉔ #22 배너가 이동 키를 말하고, 그 표기가 참이다 ────────────────────────
func _check_move_key_ad(m: Node) -> void:
	print("── ㉔ #22 이동 키 광고(정보 정직성 축) ──")
	var ob = m.onboarding
	var prev: int = ob.step
	ob.step = ob.MEET_MIHO
	var g_home: String = ob.guidance(false)
	var g_away: String = ob.guidance(true)
	ob.step = prev
	# 무대 — 이동 키를 알려 주던 유일한 문자열은 **영원히 안 뜬다**(대입 다음 줄이 숨김이다).
	var lit := _line_in_func(_src, "func _process", "readout.text = \"방향키 이동", true)
	var hid := _line_in_func(_src, "func _process", "readout.visible = false", true)
	_check("㉔a-pre 무대: 옛 이동 안내는 대입(%d행) 직후 숨겨져(%d행) 한 번도 화면에 안 뜬다"
			% [lit + 1, hid + 1], lit >= 0 and hid > lit)
	# 그래서 "어딘가로 가라"고 지시하는 유일한 단계가 가는 법을 함께 말해야 한다.
	_check("㉔b 두 갈래 배너가 모두 이동 키를 말한다 — 「%s」 / 「%s」"
			% [g_home.substr(0, 26), g_away.substr(0, 26)],
		g_home.contains("[방향키]") and g_away.contains("[방향키]"))
	# ★ **광고는 언제나 참이어야 한다** — 표기한 것이 실제로 월드 이동에 묶여 있는가를 InputMap에서
	#   판정한다. 동시에 이 검사가 #22 ㉡(조작 체계)의 사실을 기록한다: `ui_*`에는 방향키만 있고
	#   WASD는 없는데 타이틀 화면은 WASD를 함께 받는다 — 그 비대칭 해소는 owner 결정이라 안 고쳤다.
	var arrow_bound := true
	var wasd_bound := false
	for pair in [["ui_up", KEY_UP, KEY_W], ["ui_down", KEY_DOWN, KEY_S],
			["ui_left", KEY_LEFT, KEY_A], ["ui_right", KEY_RIGHT, KEY_D]]:
		var act := String(pair[0])
		var has_arrow := false
		for ev in InputMap.action_get_events(act):
			var k := ev as InputEventKey
			if k == null:
				continue
			var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
			if code == int(pair[1]):
				has_arrow = true
			if code == int(pair[2]):
				wasd_bound = true
		if not has_arrow:
			arrow_bound = false
	_check("㉔c 표기가 참이다 — 월드 이동 `ui_*` 넷에 방향키가 실제로 묶여 있다", arrow_bound)
	_check("㉔d 기록: WASD는 월드 이동에 안 묶여 있다(묶임 %s) — 타이틀만 WASD를 함께 받는 비대칭은"
			% str(wasd_bound) + " 조작 체계 결정이라 owner 큐(그래서 배너가 WASD를 광고하지 않는다)",
		not wasd_bound and not g_home.contains("WASD") and not g_away.contains("WASD"))
	# 타이틀 쪽 사실도 소스에서 확인해 둔다(비대칭의 반대 절반 — 그래야 owner가 판단할 재료가 선다).
	var t := _text_of("res://title_screen.gd")
	_check("㉔e 기록: 타이틀 커서는 방향키와 WASD를 함께 받는다(비대칭의 반대 절반)",
		t.contains("KEY_UP, KEY_W") and t.contains("KEY_LEFT, KEY_A"))
