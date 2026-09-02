extends SceneTree
# ★[폴리시 12회차] 버그 헌트 확정분 회귀 — 배치 A(#1~#11).
#
# 렌즈: R11 diff 리뷰 · 다중 슬롯 교차 · 트윈/타이머 생애주기 · 프레임 순서.
#
# 무엇을 보증하나(번호 = 12회차 헌트 배치 A 발견 번호):
#   ① #1  (high) R11이 세운 원자적 세이브가 **쓰기의 성패를 한 번도 안 물었다** — `store_string`·
#         `close`는 값을 안 돌려주고 `get_error()`는 어디서도 안 읽혀, 디스크가 차면 잘린 tmp가
#         rename으로 멀쩡한 슬롯을 덮고 `return true`가 났다(계약의 정반대 + 거짓 성공 보고).
#   ② #2(=#4·#10) 미뤄 둔 카페 마감 정산·마일스톤 팝업 타이머가 **취침과 F9를 넘어 살아남아**,
#         어제 밤(또는 폐기된 타임라인)의 장부가 새 아침 화면 위에 떴다. R11은 화면을 갈아엎는 세
#         경로 중 `_open_epilogue`·`_end_run` 둘에만 버리는 줄을 넣었다.
#   ③ #3  저장 실패 [종료] 2단 확인 래치가 **세우기만 하고 해제되지 않아**, 한 세션에 실패
#         에피소드가 둘이면 두 번째 [종료]가 경고 없이 나갔다(그 사이 진행이 조용히 사라진다).
#   ④ #5  점괘 거울은 **열 때 한 번만** 그날 예보를 스냅샷하는데 F9 로드가 다시 파생하지 않아,
#         20일차 운·'내일 날씨'가 3일차를 복원한 화면에 남고 프롬프트는 '덮기'라 최신인 척했다.
#   ⑤ #6  음소거 중 phase가 바뀌면 새 곡의 **페이드인 트윈이 아예 안 생겨**, 음소거를 풀어도
#         다음 전환까지 완전 무음이었다(`set_muted`는 버스만 건드리고 플레이어 볼륨은 안 본다).
#   ⑥ #7  `_close_spine_scene`이 `_sleeping`을 안 봐, R10 #6이 `_on_dialogue_finished`에서 세운
#         "취침 트윈 중엔 잠금을 안 푼다"를 그 아래 줄이 무조건 되뚫었다(암전 뒤 자유 이동).
#   ⑦ #8  `_on_sleep_done`의 해제 목록에 `_epilogue_open`·`spine_puzzle`이 빠져, 엔딩 화면이 떠
#         있는 채로 캐릭터가 패널 뒤 월드를 돌아다녔다(main엔 다시 잠글 경로가 없다).
#   ⑧ #9  `_open_epilogue`가 **취침 트윈이 일시적으로 멈춰 둔** 시계를 스냅해, 엔딩을 닫은 뒤
#         시간이 영구 정지했다(분 틱·NPC 스케줄·영업창·날씨 phase 전부 — 복구는 취침뿐).
#   ⑨ #11(=#17) 늘봄방 완공 아침이 같은 프레임에 HOME 그리드를 **두 번** 구웠다 — R11이 로드
#         경로만 접어 기본 인자 호출부에 그대로 남은 이중 굽기(실측 재빌드 1회 ≈ 2.5s가 취침
#         페이드 한가운데서 순수 낭비).
#
# 판정: ①~⑨ 전부 CONFIRMED. #4·#10은 #2와 같은 가족(같은 다섯 조각·같은 두 갈래)이라 캐노니컬
#       한 자리(`_drop_cafe_popups`)에서 함께 봉합하고 ②가 두 갈래를 모두 잰다. #17은 #11과
#       같은 결함의 두 줄(5427·5430)을 각각 가리킨 것이라 ⑨ 한 수정이 둘을 덮는다.

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

# main.gd 소스에서 needle이 든 줄의 인덱스(-1 = 없음) — polish_r7~r11의 그 헬퍼.
func _line_of(needle: String) -> int:
	return _line_after(0, needle)

# start 이후 첫 매치 — 같은 니들이 여러 함수에 흩어져 있을 때 계약이 사는 함수 안에서 잰다.
func _line_after(start: int, needle: String) -> int:
	for i in range(maxi(start, 0), _src.size()):
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

# 다른 파일 소스의 줄 배열(save.gd·audio.gd — main.gd는 _src가 든다).
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _index_in(lines: PackedStringArray, needle: String) -> int:
	for i in lines.size():
		if lines[i].contains(needle):
			return i
	return -1

func _wipe_slot(slot: int) -> void:
	var p := SaveManager.slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var t := p + SaveManager.TMP_SUFFIX
	if FileAccess.file_exists(t):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(t))


func _initialize() -> void:
	print("══ 폴리시 12회차 — R11 diff · 다중 슬롯 교차 · 트윈/타이머 생애주기 · 프레임 순서(배치 A) ══")
	_src = FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().split("\n")
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)

	_check_save_atomicity()
	await _check_audio_mute_phase()

	var m := await _spawn_main()
	_dismiss_dialogue(m)
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)

	await _check_cafe_popups(m)
	_check_quit_latch(m)
	_check_sleep_locks(m)
	_check_epilogue_clock(m)
	_check_greenhouse_rebuild(m)

	print("── 결과: %s (실패 %d) ──" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)


# ── ① #1 원자적 세이브가 쓰기의 성패를 묻는다 ────────────────────────────────
# 잘린 쓰기 자체는 헤드리스에서 유도할 수 없다(디스크를 채워야 한다). 그래서 재는 것은 **계약의
# 형태**다: ㉠검사가 rename보다 앞에 있고 ㉡실패 갈래가 tmp를 지우고 false를 돌리며 ㉢그 false를
# 보고 층 둘이 실제로 읽는다. 정상 경로는 종전 그대로 왕복하고 tmp를 남기지 않는다.
func _check_save_atomicity() -> void:
	print("── ① #1 원자적 세이브 — 쓰기가 실패하면 슬롯도 보고도 그것을 안다 ──")
	var sv := _lines_of_file("res://save.gd")
	var store_i := _index_in(sv, "f.store_string(var_to_str(wrapped))")
	var err_i := _index_in(sv, "var werr := f.get_error()")
	var rename_i := _index_in(sv, "DirAccess.rename_absolute(")
	_check("①a 쓰기 뒤 `get_error()`를 실제로 읽는다(save.gd:%d — 종전엔 저장소 어디에도 없던 호출)"
			% (err_i + 1),
		err_i > 0 and store_i > 0 and err_i > store_i)
	_check("①b 그 검사가 **rename보다 앞**이다(save.gd:%d < %d) — 잘린 tmp가 슬롯을 덮기 전에 멈춘다"
			% [err_i + 1, rename_i + 1],
		rename_i > 0 and err_i < rename_i)
	_check("①c 실패 갈래는 버퍼를 먼저 내려보낸다(`flush` — 잘림이 close 시점에야 드러나는 경우)",
		_index_in(sv, "f.flush()") > store_i and _index_in(sv, "f.flush()") < err_i)
	# 실패 갈래의 구성: 경고 + tmp 삭제 + false. 셋이 다 있어야 "슬롯은 직전 세이브 그대로"가 참이다.
	var branch := ""
	for i in range(err_i, mini(err_i + 6, sv.size())):
		branch += sv[i]
	_check("①d 실패 갈래가 셋을 다 한다 — 경고·tmp 삭제·false 반환(하나라도 빠지면 계약이 깨진다)",
		branch.contains("if werr != OK:") and branch.contains("push_warning(")
		and branch.contains("DirAccess.remove_absolute(") and branch.contains("return false"))
	# 보고 층 — false가 위로 올라가는 두 자리(옵션 탭 [저장] 문구 · [종료] 2단 확인).
	_check("①e `_save_game`이 그 false를 그대로 올린다(성공 문구는 그 뒤에만 뜬다)",
		_in_func("func _save_game", "if not saver.save_game(data, _active_slot")
		and _in_func("func _save_game", "_notice(\"저장됨\")"))
	_check("①f [종료] 2단 확인이 그 false를 읽는다(`not _save_game()` — 그래야 래치가 무장한다)",
		_in_func("func _on_frame_quit", "if not _save_game() and not _quit_unsaved_armed:"))

	# 정상 경로 회귀 — 계약을 세우면서 평범한 저장을 깨지 않았는가.
	var saver := SaveManager.new()
	root.add_child(saver)
	var slot: int = SaveManager.SLOT_COUNT - 1
	_wipe_slot(slot)
	var payload := {"day": 41, "note": "R12"}
	var ok := saver.save_game(payload, slot, {"day": 41})
	_check("①g 정상 저장은 여전히 true이고 그대로 읽힌다(day=41 · meta.day=41)",
		ok and saver.load_game(slot).get("day", 0) == 41
		and int(saver.slot_meta(slot).get("day", 0)) == 41)
	_check("①h 성공 뒤 임시본이 안 남는다(`%s` 없음 — rename이 자리를 옮겼다)" % SaveManager.TMP_SUFFIX,
		not FileAccess.file_exists(SaveManager.slot_path(slot) + SaveManager.TMP_SUFFIX))
	saver.free()
	_wipe_slot(slot)


# ── ⑤ #6 음소거 중 phase 전환이 페이드인을 건너뛰지 않는다 ───────────────────
# 결함의 형태가 "트윈이 **아예 안 생긴다**"라 그 자리를 직접 잰다. 종전엔 `if not _muted:`가
# incoming 페이드를 통째로 건너뛰어 새 곡이 SILENT_DB에 박혔고, `set_muted(false)`는 버스만
# 열어 다음 phase 전환까지 무음이었다.
func _check_audio_mute_phase() -> void:
	print("── ⑤ #6 음소거 중 곡이 바뀌어도 볼륨은 서 있다(버스만 닫혀 있을 뿐) ──")
	var au := _lines_of_file("res://audio.gd")
	_check("⑤a `set_phase`에서 페이드인의 음소거 게이트가 사라졌다(소스 — 코드 줄 `if not _muted:` 0회)",
		_index_in(au, "\tif not _muted:") < 0)
	_check("⑤b 음소거의 주인은 여전히 버스 하나다(`set_muted`는 플레이어 볼륨을 안 건드린다)",
		_index_in(au, "AudioServer.set_bus_mute") > 0)

	var A := GameAudio.new()
	get_root().add_child(A)
	await process_frame
	A.update_music(12 * 60, false, false)          # 낮(farm)으로 한 곡 깔고
	await process_frame
	A.set_muted(true)                              # M으로 음소거 — 버스만 닫힌다
	A.set_phase(GameAudio.PHASE_NIGHT)             # 19:00 경계를 넘어 밤으로 전환
	var incoming: AudioStreamPlayer = A._music_a if A._music_on_a else A._music_b
	var tw: Tween = A._music_tweens.get(incoming.get_instance_id())
	_check("⑤c 음소거 중 전환에도 새 곡에 페이드인 트윈이 걸린다(종전엔 이 트윈이 아예 없었다)",
		tw != null and tw.is_valid())
	_check("⑤d 그 곡이 실제로 밤 테마다(엉뚱한 플레이어를 재고 있지 않다)",
		incoming.stream != null and incoming.stream.resource_path.get_file().begins_with("bgm_night"))
	if tw != null and tw.is_valid():
		tw.pause()
		tw.custom_step(GameAudio.CROSSFADE_SECS + 0.1)
	_check("⑤e 페이드가 끝나면 볼륨이 FULL_DB다(%.1f) — 해제하는 순간 소리가 돌아온다"
			% GameAudio.FULL_DB,
		is_equal_approx(incoming.volume_db, GameAudio.FULL_DB))
	A.set_muted(false)
	_check("⑤f 해제는 버스만 연다 — 볼륨은 이미 서 있어 다음 전환을 기다리지 않는다",
		not AudioServer.is_bus_mute(AudioServer.get_bus_index(GameAudio.MUSIC_BUS))
		and is_equal_approx(incoming.volume_db, GameAudio.FULL_DB))
	A.set_muted(false)
	A.free()


# ── ② #2(=#4·#10) 카페 팝업 셋이 취침·F9를 못 넘는다 ─────────────────────────
func _check_cafe_popups(m: Node) -> void:
	print("── ② #2(=#4·#10) 미뤄 둔 마감 정산이 새 아침·복원된 아침 위로 뜨지 않는다 ──")
	# 먼저 이 결함이 왜 성립했는지를 소스로 못 박는다 — 두 타이머 틱에 `_sleeping` 가드가 없어
	# 1.1초 암전 트윈 동안에도 계속 깎이고, F9 폴링은 팝업이 모달이 아니라 그대로 도달한다.
	var tick_i := _line_of("\tif _milestone_popup_secs > 0.0:")
	var tick_block := ""
	for i in range(tick_i, mini(tick_i + 9, _src.size())):
		tick_block += _src[i]
	_check("②a-pre 무대: 마일스톤 타이머 틱에는 `_sleeping` 가드가 없다(main.gd:%d — 취침 갈래의 뿌리)"
			% (tick_i + 1),
		tick_i > 0 and not tick_block.contains("_sleeping")
		and tick_block.contains("_show_cafe_summary(pending)"))
	_check("②a2-pre 무대: F9 폴링은 팝업 가시성을 안 본다(로드 갈래의 뿌리 — 두 팝업은 모달이 아니다)",
		_in_func("func _process", "Input.is_action_just_pressed(\"load_game\")"))

	# 다섯 조각을 전부 세운다(미룬 본문 + 두 타이머 + 두 패널).
	var pending_text := "매출  1234냥\n서빙한 손님  7명"
	m._cafe_summary_pending = pending_text
	m._cafe_summary_secs = m.CAFE_SUMMARY_SECS
	m._milestone_popup_secs = m.MILESTONE_POPUP_SECS
	m.cafe_summary_panel.visible = true
	m.milestone_panel.visible = true
	_check("②b-pre 무대: 다섯 조각이 실제로 서 있다(미룬 본문·정산 타이머·팝업 타이머·패널 둘)",
		m._cafe_summary_pending == pending_text and m._cafe_summary_secs > 0.0
		and m._milestone_popup_secs > 0.0
		and m.cafe_summary_panel.visible and m.milestone_panel.visible)

	# ㉠취침 갈래 — 한 자리(`_drop_cafe_popups`)가 다섯을 다 버린다.
	m._drop_cafe_popups()
	_check("②c 버리는 자리가 다섯을 **전부** 비운다 — 본문 \"\" · 타이머 둘 0 · 패널 둘 숨김",
		m._cafe_summary_pending == "" and m._cafe_summary_secs == 0.0
		and m._milestone_popup_secs == 0.0
		and not m.cafe_summary_panel.visible and not m.milestone_panel.visible)
	_check("②d 취침이 그 자리를 부른다(세션 셋 폐기와 같은 줄 — `_do_sleep`)",
		_in_func("func _do_sleep", "_drop_cafe_popups()"))
	_check("②e 로드도 같은 자리를 부른다(밤 바 폐기와 같은 줄 — `_load_game`)",
		_in_func("func _load_game", "_drop_cafe_popups()"))
	_check("②f 형제 두 경로는 종전대로 미룬 본문을 버린다(계약의 출처 — 화면을 갈아엎는 세 경로)",
		_in_func("func _open_epilogue", "_cafe_summary_pending = \"\"")
		and _in_func("func _end_run", "_cafe_summary_pending = \"\""))

	# ㉡F9 갈래 — 실제 로드 왕복으로 잰다(소스가 아니라 거동으로).
	m._save_game()
	m._cafe_summary_pending = pending_text
	m._cafe_summary_secs = m.CAFE_SUMMARY_SECS
	m._milestone_popup_secs = m.MILESTONE_POPUP_SECS
	m.cafe_summary_panel.visible = true
	m.milestone_panel.visible = true
	# ④ #5 — 같은 로드가 점괘 거울 스냅샷도 덮는지 함께 잰다(둘 다 "로드가 안 되감던 조회 패널").
	m._open_mirror()
	var mirror_before: String = m.mirror_text.text
	_check("④a-pre 무대: 거울이 열렸고 본문이 그날 예보로 채워졌다(빈 문자열이 아니다)",
		m.mirror_panel.visible and mirror_before != "")
	var loaded: bool = m._load_game()
	await process_frame
	_check("②g-pre 무대: 로드가 실제로 성공했다(공회전 단언 방지)", loaded)
	_check("②g F9 뒤 다섯 조각이 전부 비었다 — 폐기된 타임라인의 장부가 복원된 아침에 안 뜬다",
		m._cafe_summary_pending == "" and m._cafe_summary_secs == 0.0
		and m._milestone_popup_secs == 0.0
		and not m.cafe_summary_panel.visible and not m.milestone_panel.visible)
	_check("④b F9 뒤 점괘 거울이 덮인다 — 로드 전 날짜의 운·'내일 날씨'가 화면에 안 남는다",
		not m.mirror_panel.visible)
	_check("④c 자동 접기는 여전히 자리 조건뿐이다(집 안에서 찍은 세이브엔 안 걸린다 — 로드가 필요한 이유)",
		_in_func("func _process", "if mirror_panel.visible and (_indoor != \"집\" or _sleeping):"))
	_check("④d 대조: 같은 조회 패널인 달력은 매 프레임 값을 다시 흘려넣어 이 문제가 없다",
		_line_of("calendar_panel.set_state(clock.day, _cafe_stage(), _cafe_revenue_total)") > 0)


# ── ③ #3 [종료] 2단 확인 래치가 저장 성공에 풀린다 ───────────────────────────
func _check_quit_latch(m: Node) -> void:
	print("── ③ #3 저장이 성공하면 [종료] 경고 래치가 다시 선다 ──")
	m._quit_unsaved_armed = true
	var ok: bool = m._save_game()
	_check("③a-pre 무대: 이 환경에서 저장은 실제로 성공한다(공회전 단언 방지)", ok)
	_check("③b 성공한 저장이 래치를 푼다 — 선언부 머리말의 논증이 비로소 참이 된다",
		not m._quit_unsaved_armed)
	_check("③c 해제가 **성공 갈래 안**에 있다(실패하면 여전히 무장한 채다 — 실패 시 return false가 먼저)",
		_in_func("func _save_game", "_quit_unsaved_armed = false")
		and _line_after(_line_of("func _save_game"), "if not saver.save_game(data, _active_slot")
			< _line_after(_line_of("func _save_game"), "_quit_unsaved_armed = false"))
	_check("③d 형제 둘도 각자 해제 경로를 갖는다(F8 = 시간 만료 · 이혼 [F] 2타 = 시선을 떼면 접힘)",
		_in_func("func _process", "_delete_armed_secs -= delta")
		and _in_func("func _process", "_divorce_armed = false"))


# ── ⑥ #7 · ⑦ #8 취침 트윈 뒤에서 잠금이 안 풀린다 ────────────────────────────
func _check_sleep_locks(m: Node) -> void:
	print("── ⑥ #7 척추 장면 종료가 취침 암전 뒤에서 이동을 안 푼다 ──")
	m._run_over = false
	m._epilogue_open = false
	m._sleeping = true
	m.player.set_physics_process(false)
	m._close_spine_scene()
	_check("⑥a 취침 중이면 `_close_spine_scene`이 물리를 안 켠다(R10 #6 불변식을 안 되뚫는다)",
		not m.player.is_physics_processing())
	m._sleeping = false
	m._close_spine_scene()
	_check("⑥b 대조: 깨어 있으면 종전대로 켠다 — 가드가 잠금을 통째로 죽인 게 아니다",
		m.player.is_physics_processing())
	_check("⑥c 조건 네 항이 다 있다(`_run_over`·`_epilogue_open`·`spine_puzzle`·`_sleeping`)",
		_in_func("func _close_spine_scene",
			"if not _run_over and not _epilogue_open and spine_puzzle == null and not _sleeping:"))

	print("── ⑦ #8 눈뜨는 프레임이 엔딩 화면·내면 공간 뒤에서 이동을 안 푼다 ──")
	m._epilogue_open = true
	m.player.set_physics_process(false)
	m._on_sleep_done()
	_check("⑦a 엔딩 화면이 떠 있으면 `_on_sleep_done`이 물리를 안 켠다(회고 뒤 자유 이동 0)",
		not m.player.is_physics_processing())
	m._epilogue_open = false
	m.player.set_physics_process(false)
	m._on_sleep_done()
	_check("⑦b 대조: 화면이 없으면 종전대로 켠다(평범한 아침이 잠긴 채로 시작하지 않는다)",
		m.player.is_physics_processing())
	_check("⑦c 목록에 내면 공간(`spine_puzzle`)도 함께 들었다 — 걸어 다니는 곳이 아니다",
		_in_func("func _on_sleep_done", "and not _epilogue_open and spine_puzzle == null:"))
	_check("⑦d 다시 켜는 자리는 두 화면이 닫히는 그곳이다(`_close_epilogue`·`_close_spine_scene`)",
		_in_func("func _close_epilogue", "player.set_physics_process(true)")
		and _in_func("func _close_spine_scene", "player.set_physics_process(true)"))


# ── ⑧ #9 엔딩이 취침으로 멈춘 시계를 스냅하지 않는다 ─────────────────────────
func _check_epilogue_clock(m: Node) -> void:
	print("── ⑧ #9 엔딩을 닫은 뒤 시간이 다시 흐른다 ──")
	m._run_over = false
	m._epilogue_open = false
	# 취침 트윈의 첫 0.4초 구간 재현 — `_do_sleep`이 running=false를 세웠고 `clock.sleep`은 아직이다.
	m._sleeping = true
	m.clock.running = false
	m._open_epilogue()
	_check("⑧a 취침 중 스냅은 true다 — 기억할 값은 '연출이 끝나면 시계가 어떤 상태여야 하는가'다",
		m._epilogue_clock_prev == true)
	m._close_epilogue()
	m._sleeping = false
	_check("⑧b 그래서 엔딩을 닫으면 시간이 다시 흐른다(종전엔 여기서 영구 정지했다)",
		m.clock.running == true)
	# 대조 — 취침이 아닌 이유로 멈춰 있던 시계는 여전히 되살리지 않는다(컷신의 그 규율 보존).
	m._epilogue_open = false
	m.clock.running = false
	m._open_epilogue()
	_check("⑧c 대조: 취침이 아니면 종전대로 멈춘 상태를 그대로 뜬다(컷신 규율은 안 넓어졌다)",
		m._epilogue_clock_prev == false)
	m._close_epilogue()
	_check("⑧d 그때는 닫아도 멈춘 채다 — 이 수정이 시계를 무조건 켜는 것이 아니다",
		m.clock.running == false)
	m.clock.running = true


# ── ⑨ #11(=#17) 늘봄방 완공 아침의 HOME 이중 굽기 ────────────────────────────
# 재빌드는 `_rebuild_region` 끝의 Y-split 캐시 무효화(`_last_player_tile_y = -9999`)를 남기므로,
# 그 표식으로 "이 호출이 실제로 구웠는가"를 잰다(polish_r11 ㉓의 그 기법).
func _check_greenhouse_rebuild(m: Node) -> void:
	print("── ⑨ #11(=#17) 완공 아침이 같은 HOME 그리드를 두 번 굽지 않는다 ──")
	_check("⑨a `_refresh_greenhouse`가 안쪽 호출에 **언제나 false**를 넘긴다(굽기는 자기 세 줄이 한다)",
		_in_func("func _refresh_greenhouse", "_refresh_home_expansion(false)")
		and not _in_func("func _refresh_greenhouse", "_refresh_home_expansion(rebuild)"))
	_check("⑨b 두 함수 모두 굽기를 `rebuild` 게이트 뒤에 둔다(인자가 실제로 굽기를 가른다)",
		_in_func("func _refresh_greenhouse", "if rebuild:")
		and _in_func("func _refresh_home_expansion", "if rebuild:"))

	m._region = RegionCatalog.HOME
	m._indoor = ""
	# 안쪽 호출과 **같은 인자**로 불렀을 때 스스로는 안 굽는다(그래서 이중이 사라진다).
	m._last_player_tile_y = 12345
	m._refresh_home_expansion(false)
	_check("⑨c `false`로 부른 안방 확장은 무대를 안 굽는다(Y-split 표식 12345가 그대로)",
		m._last_player_tile_y == 12345)
	_check("⑨d 그래도 집 카메라 둘레는 다시 주입된다(`false`가 접는 것은 굽기뿐)",
		m._buildings["집"]["cam"] == m.home_house_cam_rect())

	# 완공 아침 경로 회귀 — 늘봄방을 원장에 박고 기본 인자로 부른다(그 아침이 하는 그 일 그대로).
	m.carpenter.load_save({"active": [], "done": [Carpenter.PROJ_GREENHOUSE]})
	_check("⑨e-pre 무대: 늘봄방이 완공으로 섰다(안 그러면 `_refresh_greenhouse`가 첫 줄에서 반환)",
		m._greenhouse_built())
	m._last_player_tile_y = 12345
	m._refresh_greenhouse()
	_check("⑨f 완공 아침은 여전히 HOME을 세운다 — 굽기를 통째로 죽인 게 아니다(표식 무효화됨)",
		m._last_player_tile_y == -9999)
	_check("⑨g 그리고 늘봄방이 실제로 카탈로그에 섰다(구운 결과가 화면 원장에 반영됐다)",
		m._buildings.has("늘봄방"))
