extends SceneTree
# ★타이틀 화면 로직 검증(gemini-ui-identity-spec §3.4) — 상태기계·라우팅·슬롯 포맷.
#
# 무엇을 보나(그리기 무관·순수 로직):
#   ① 메뉴 내비 — move_selection 래핑(위/아래·경계 순환).
#   ② 라우팅 — [새 게임](세이브 有→확인·無→즉시)·[이어하기]→슬롯·[종료]→확인, 예/아니오 분기.
#   ③ 슬롯 선택 — 점유 슬롯=이어하기(is_new=false)·빈 슬롯=신규(is_new=true)·뒤로=메뉴.
#   ④ slot_label — slot_meta({day,soul}) → 코지 다이어리 "N년차 절기 D일 · 혼력".
#   ⑤ start_game/quit_game 시그널이 정확한 인자로 나오는가.
#
# 실행: godot --headless --path game --script res://playtest/title_test.gd
# 메모: SaveManager 3 슬롯 경로를 백업/복원한다(개발 세이브 격리). GPU 없이 로직만(그리기는 title_dump).

var _fail := 0
var _got_start: Array = []   # [slot, is_new]
var _got_quit := 0
# ★ B2 설정 패널 조작 신호 캡처.
var _music_delta := 0.0
var _sfx_delta := 0.0
var _fs_toggles := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _on_start(slot: int, is_new: bool) -> void:
	_got_start = [slot, is_new]

func _on_quit() -> void:
	_got_quit += 1

func _on_music(d: float) -> void:
	_music_delta = d

func _on_sfx(d: float) -> void:
	_sfx_delta = d

func _on_fs() -> void:
	_fs_toggles += 1

func _rm(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _read(p: String) -> PackedByteArray:
	var f := FileAccess.open(p, FileAccess.READ); var b := f.get_buffer(f.get_length()); f.close(); return b

func _write(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(b); f.close()

func _initialize() -> void:
	print("══ 타이틀 화면 로직 검증 ══")
	# ── 슬롯 백업 ──
	var paths := [SaveManager.slot_path(0), SaveManager.slot_path(1), SaveManager.slot_path(2)]
	var baks := {}
	for p in paths:
		if FileAccess.file_exists(p): baks[p] = _read(p)
		_rm(p)

	var sm := SaveManager.new()
	# 슬롯0 = 점유(day 34 = 1년차 유화절 6일 / 혼력 85), 슬롯1 = 빈, 슬롯2 = 점유(day 200 = 성야절)
	sm.save_game({"x": 1}, 0, {"day": 34, "soul": 85})
	sm.save_game({"x": 1}, 2, {"day": 200, "soul": 40})

	var ts := TitleScreen.new()
	ts.setup(sm)
	ts.start_game.connect(_on_start)
	ts.quit_game.connect(_on_quit)
	ts.music_nudged.connect(_on_music)
	ts.sfx_nudged.connect(_on_sfx)
	ts.fullscreen_nudged.connect(_on_fs)

	# ── ④ slot_label ──
	var l0 := ts.slot_label(0)
	_check("④a 슬롯0 라벨 '1년차 유화절 6일' 포함: " + l0, l0.contains("1년차") and l0.contains("유화절") and l0.contains("6일") and l0.contains("85"))
	_check("④b 슬롯1(빈) 라벨 = 빈 슬롯", ts.slot_label(1) == "빈 슬롯")
	_check("④c 슬롯2 라벨 '성야절' 포함: " + ts.slot_label(2), ts.slot_label(2).contains("성야절"))

	# ── ① 메뉴 내비(5항목 래핑) ──
	_check("①a 초기 상태=MENU·sel=0", ts._state == TitleScreen.State.MENU and ts._sel == 0)
	ts.move_selection(-1)
	_check("①b 위로 래핑 → sel=4(종료)", ts._sel == 4)
	ts.move_selection(1)
	_check("①c 아래로 래핑 → sel=0", ts._sel == 0)

	# ── ② [새 게임] 세이브 있음 → 확인 다이얼로그(즉시 emit 안 함) ──
	_got_start = []
	ts._sel = 0
	ts.activate()
	_check("②a 새게임+세이브 → CONFIRM_NEW", ts._state == TitleScreen.State.CONFIRM_NEW)
	_check("②b 확인 전엔 start 미발화", _got_start.is_empty())
	ts._sel = 0   # 예
	ts.activate()
	_check("②c 예 → start_game(0, true) 발화", _got_start == [0, true])
	# 아니오 경로
	ts._go(TitleScreen.State.CONFIRM_NEW)
	ts._sel = 1   # 아니오
	ts.activate()
	_check("②d 아니오 → 메뉴 복귀", ts._state == TitleScreen.State.MENU)

	# ── ③ [이어하기] → 슬롯 선택 ──
	ts._go(TitleScreen.State.MENU); ts._sel = 1
	ts.activate()
	_check("③a 이어하기 → SLOTS", ts._state == TitleScreen.State.SLOTS)
	# 점유 슬롯0 선택 → 이어하기(is_new=false)
	_got_start = []; ts._sel = 0; ts.activate()
	_check("③b 점유 슬롯0 → start_game(0, false)", _got_start == [0, false])
	# 빈 슬롯1 선택 → 신규(is_new=true)
	ts._go(TitleScreen.State.SLOTS); _got_start = []; ts._sel = 1; ts.activate()
	_check("③c 빈 슬롯1 → start_game(1, true)", _got_start == [1, true])
	# 뒤로(sel = SLOT_COUNT)
	ts._go(TitleScreen.State.SLOTS); ts._sel = SaveManager.SLOT_COUNT; ts.activate()
	_check("③d 뒤로 → 메뉴", ts._state == TitleScreen.State.MENU)

	# ── ② [종료] → 확인 → 예 → quit ──
	ts._go(TitleScreen.State.MENU); ts._sel = 4; ts.activate()
	_check("②e 종료 → CONFIRM_QUIT", ts._state == TitleScreen.State.CONFIRM_QUIT)
	_got_quit = 0; ts._sel = 0; ts.activate()
	_check("②f 예 → quit_game 발화", _got_quit == 1)

	# ── ⑤ ESC(_cancel): 하위 상태→메뉴, 메뉴→종료확인 ──
	ts._go(TitleScreen.State.SLOTS); ts._cancel()
	_check("⑤a ESC(슬롯) → 메뉴", ts._state == TitleScreen.State.MENU)
	ts._cancel()
	_check("⑤b ESC(메뉴) → 종료확인", ts._state == TitleScreen.State.CONFIRM_QUIT)

	# ── ⑥ 설정(★ B2 실동작) → SETTINGS 패널 → 볼륨·전체화면 조작 신호 → 뒤로/ESC ──
	ts._go(TitleScreen.State.MENU); ts._sel = 2; ts.activate()
	_check("⑥a 설정 → SETTINGS", ts._state == TitleScreen.State.SETTINGS)
	_check("⑥b 초기 행=음악(sel 0)", ts._sel == 0)
	# 음악 행 좌/우 = 음악 볼륨 −/+ 신호
	_music_delta = 0.0; ts.adjust(1)
	_check("⑥c 음악행 우 → music_nudged(+STEP)", is_equal_approx(_music_delta, TitleScreen.VOL_STEP))
	ts.adjust(-1)
	_check("⑥d 음악행 좌 → music_nudged(−STEP)", is_equal_approx(_music_delta, -TitleScreen.VOL_STEP))
	# 효과음 행
	ts.move_selection(1)
	_check("⑥e 아래 → 효과음 행(sel 1)", ts._sel == 1)
	_sfx_delta = 99.0; ts.adjust(1)
	_check("⑥f 효과음행 우 → sfx_nudged(+STEP)", is_equal_approx(_sfx_delta, TitleScreen.VOL_STEP))
	# 음악 행 조작이 효과음으로 새지 않는가(행별 라우팅)
	_music_delta = 0.0; ts._sel = 1; ts.adjust(-1)
	_check("⑥g 효과음행에선 music 무변", is_equal_approx(_music_delta, 0.0))
	# 전체화면 행 → 엔터/조정 = 토글 신호
	ts.move_selection(1)
	_check("⑥h 아래 → 전체화면 행(sel 2)", ts._sel == 2)
	_fs_toggles = 0; ts.activate()
	_check("⑥i 전체화면 엔터 → fullscreen_nudged", _fs_toggles == 1)
	ts.adjust(1)
	_check("⑥j 전체화면 조정도 토글", _fs_toggles == 2)
	# 뒤로 행 → 메뉴 복귀
	ts.move_selection(1)
	_check("⑥k 아래 → 뒤로 행(sel 3)", ts._sel == 3)
	ts.activate()
	_check("⑥l 뒤로 → 메뉴", ts._state == TitleScreen.State.MENU)
	# ESC로도 설정→메뉴
	ts._go(TitleScreen.State.SETTINGS); ts._cancel()
	_check("⑥m ESC(설정) → 메뉴", ts._state == TitleScreen.State.MENU)
	# adjust는 SETTINGS 외 상태(MENU)에선 무동작(가드)
	_music_delta = 0.0; ts._sel = 0; ts.adjust(1)
	_check("⑥n MENU에서 adjust 무동작", is_equal_approx(_music_delta, 0.0))

	# ── 정리 ──
	ts.free()
	sm.free()
	for p in paths:
		_rm(p)
		if baks.has(p): _write(p, baks[p])

	if _fail == 0:
		print("══ 통과 ══"); quit(0)
	else:
		print("══ 실패 %d ══" % _fail); quit(1)
