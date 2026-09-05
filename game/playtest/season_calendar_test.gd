extends SceneTree
# ★[S7-T1 / ADR-0065 결정 1] 절기 달력 개통 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ① 절기 전환 판정(GameClock.is_season_first_day) — day 1·29·57·85·113만 true.
#      day 1(게임 시작)도 전환일이다 — 시작 절기의 첫날이라 같은 규칙에 들어간다.
#   ② 절기 내 일차(GameClock.day_of_season) — 1-기반 1..28 순환(28 다음이 다시 1).
#   ③ ★런 종료 게이트 소멸 — 옛 RUN_DAYS=21 게이트가 day 22 아침에 게임을 끝내
#      절기 전환(day 29)에 영원히 도달 못 했다. 이제 _on_day_advanced로 22를 넘고
#      29(유화절 1일)까지 간다. 게이트의 **다른 입구**(세이브 재개)도 함께 막혔는지 본다.
#   ④ 파생 수렴 — 흩어져 있던 일차 계산(덤불·HUD 날짜)이 clock static과 값이 같다.
#   ⑤ forage_spawn 이중 발화 차단 — 로컬 판정이 clock static으로 교체돼도 동작 동일
#      (절기 전환일 전량 삭제 유지 · 비전환일은 삭제 없음).
#
# ★ RunSummary.RUN_DAYS 상수·정산 화면(_end_run)·호감도 곡선은 **보존 대상**이다
#   (S9 엔딩 재사용 자산 — 게이트만 걷어냈지 자산을 지운 게 아니다). 그것도 함께 단언한다.
#
# ★[폴리시 R25 부록] ③의 무대가 **오프닝 통보를 닫고** 시작한다. R23 #25가 그 모달에 시계 정지를
#   세운 뒤로 «부팅 직후엔 시계가 흐른다»가 더는 참이 아니기 때문이다(③pre3·③pre4에 경위).
#
# 실행: ./run_tests.sh season_calendar   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame
	return m

# ★[폴리시 R25 부록] 열려 있는 대화를 끝까지 넘긴다(부팅 직후의 오프닝 통보 — 아래 ③ 참조).
func _dismiss_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 60:
		m.dialogue.advance()
		guard += 1

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

func _initialize() -> void:
	print("══ S7-T1 절기 달력 개통 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s7_t1_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	# 첫 인스턴스가 옛/오염 세이브로 부팅되지 않게 spawn 전에 지운다(festival_test 격리 관례).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 절기 전환 판정(순수 static — 인스턴스 불필요) ──
	print("── ① 절기 전환일(is_season_first_day) ──")
	_check("①a 절기 길이 28일(단일 진실원)", GameClock.DAYS_PER_SEASON == 28)
	var firsts_ok := true
	for d in [1, 29, 57, 85, 113]:
		if not GameClock.is_season_first_day(int(d)):
			firsts_ok = false
	_check("①b day 1·29·57·85·113 = 절기 첫날", firsts_ok)
	var plains_ok := true
	for d in [2, 28, 30, 56, 112]:
		if GameClock.is_season_first_day(int(d)):
			plains_ok = false
	_check("①c day 2·28·30·56·112 = 절기 중간(전환 아님)", plains_ok)
	# 전환일이 곧 절기 인덱스가 갈리는 날인지(기존 파생과 정합 — 판정이 따로 놀면 안 된다).
	var aligned := true
	for d in range(1, 120):
		var boundary: bool = GameClock.season_index_for_day(d) != GameClock.season_index_for_day(d - 1)
		# d=1은 이전 날이 없으니 예외 없이 전환일로 본다(시작 절기의 첫날).
		if d > 1 and boundary != GameClock.is_season_first_day(d):
			aligned = false
	_check("①d 전환일 = season_index가 갈리는 날(기존 파생과 정합)", aligned)

	# ── ② 절기 내 일차(day_of_season) ──
	print("── ② 절기 내 일차(day_of_season) ──")
	_check("②a day 1 → 1일(1-기반)", GameClock.day_of_season(1) == 1)
	_check("②b day 28 → 28일(절기 마지막)", GameClock.day_of_season(28) == 28)
	_check("②c day 29 → 1일(다음 절기로 되감김)", GameClock.day_of_season(29) == 1)
	_check("②d day 112 → 28일(한 해 마지막)", GameClock.day_of_season(112) == 28)
	_check("②e day 113 → 1일(해가 돌아 다시 피안절)", GameClock.day_of_season(113) == 1
		and GameClock.season_index_for_day(113) == 0)
	var range_ok := true
	for d in range(1, 260):
		var dos := GameClock.day_of_season(d)
		if dos < 1 or dos > GameClock.DAYS_PER_SEASON:
			range_ok = false
	_check("②f 1..28 밖으로 새지 않음(day 1..259 전수)", range_ok)

	# ── ③ ★런 종료 게이트 소멸 — day 22를 넘어 절기 전환(29)까지 간다 ──
	print("── ③ 런 종료 게이트 소멸(RUN_DAYS 21 돌파) ──")
	var m: Node = await _new_main()
	_check("③pre RUN_DAYS 상수는 보존(S9 엔딩 자산 — 지운 게 아니라 게이트만 걷음)",
		RunSummary.RUN_DAYS == 21 and RunSummary.is_over(22))
	_check("③pre2 _end_run 함수 보존(엔딩 재사용 대기)", m.has_method("_end_run"))
	# ★[폴리시 R25 부록] **부팅 직후는 오프닝 통보 중이다.** R23 #25(3ac1538)가 그 모달에 형제 셋
	#   (컷신·내면 공간·에필로그)과 같은 문법을 세우면서(`clock.running`을 스냅해 false로 두고 통보가
	#   끝나는 자리에서 되돌린다) 이 무대의 암묵 전제가 조용히 깨졌다 — ③c는 «런 게이트가 없어져
	#   시계가 흐른다»를 재는 항인데, 통보를 안 닫은 채 물으면 «통보가 멈춰 놨다»는 **다른 이유**로
	#   빨개진다(그 커밋 이래 선재 red · 프로덕션은 정확했다). 실플레이는 그 다섯 줄을 읽고 닫으면서
	#   시작하므로 무대도 거기까지 온다. 무대를 옮기기 전에 그 계약을 여기서 먼저 못 박아,
	#   ③c가 «어떤 이유로든 흐른다»가 아니라 «통보를 닫았는데도 게이트가 안 끈다»를 물게 한다.
	_check("③pre3 무대: 부팅 직후엔 오프닝 통보가 열려 있고 시계는 그 계약대로 멈춰 있다(R23 #25)",
		m.dialogue.is_open() and not m.clock.running)
	_dismiss_dialogue(m)
	await process_frame
	_check("③pre4 통보를 닫으면 시계가 되살아난다(정지 주인 = 재개 주인) — running %s · 대화 %s"
			% [str(m.clock.running), str(m.dialogue.is_open())],
		m.clock.running and not m.dialogue.is_open())
	# 옛 게이트가 정확히 터지던 지점: 21일째 취침 → day 22 아침.
	m.clock.day = 22
	m._on_day_advanced(22)
	await process_frame
	_check("③a day 22 아침에 런이 끝나지 않는다(_run_over false)", m._run_over == false)
	_check("③b 마무리 화면이 뜨지 않는다(ending_panel 숨김)", not m.ending_panel.visible)
	_check("③c 시계가 계속 흐른다(clock.running)", m.clock.running)
	# 계속 굴려 절기 전환일(29 = 유화절 1일)에 실제로 도달한다 — Slice 7의 전제.
	for d in range(23, 30):
		m.clock.day = d
		m._on_day_advanced(d)
		await process_frame
	_check("③d day 29(유화절 1일)까지 실주행 도달", m.clock.day == 29 and not m._run_over)
	_check("③e 그날이 절기 전환일로 판정된다", GameClock.is_season_first_day(m.clock.day))
	_check("③f 절기가 실제로 갈렸다(피안 → 유화)", m.clock.season_index() == 1
		and GameClock.season_name(m.clock.season_index()) == "유화절")

	# ── ④ 파생 수렴 — 흩어져 있던 일차 계산이 clock static과 같은 값 ──
	print("── ④ 일차 파생 수렴(덤불·HUD) ──")
	var berry_ok := true
	var hud_ok := true
	for d in [1, 14, 28, 29, 43, 112, 113]:
		if BerryBushes.day_of_season(int(d)) != GameClock.day_of_season(int(d)):
			berry_ok = false
		m.clock.day = int(d)
		var want: String = "%s %d일" % [GameClock.season_name(m.clock.season_index()),
			GameClock.day_of_season(int(d))]
		if m._inv_date_string() != want:
			hud_ok = false
	_check("④a berry_bush.day_of_season = clock 파생(값 동일)", berry_ok)
	_check("④b HUD 날짜 문자열이 clock 파생과 일치", hud_ok)
	# 덤불 절기 창(피안 15~18)이 수렴 후에도 그대로 열리는지 — 파생 교체가 규칙을 안 흔들었나.
	_check("④c 덤불 창 규칙 불변(피안 15~18 열림 · 14·19 닫힘)",
		BerryBushes.berry_for_day(15) != "" and BerryBushes.berry_for_day(18) != ""
		and BerryBushes.berry_for_day(14) == "" and BerryBushes.berry_for_day(19) == "")

	# ── ⑤ forage_spawn 이중 발화 차단(동작 동일) ──
	print("── ⑤ forage_spawn 절기 판정 승격 ──")
	var led := ForageSpawns.new()
	for d in range(1, 29):
		led.advance_day(d, 0)      # 피안절 한 절기를 굴려 판을 채운다
	var before := led.total()
	var res29: Dictionary = led.advance_day(29, 1)   # 절기 전환일 — 전량 삭제 후 새 절기 종
	_check("⑤a day 29에 season_reset=true(전환 감지 유지)", bool(res29["season_reset"]))
	_check("⑤b 전환일에 옛 절기 판이 비워졌다", before > 0 and int(res29["cleared"]) == before)
	var res30: Dictionary = led.advance_day(30, 1)
	_check("⑤c day 30은 전환 아님(season_reset=false)", not bool(res30["season_reset"]))
	var res1 := ForageSpawns.new().advance_day(1, 0)
	_check("⑤d day 1도 전환일(시작 절기 첫날 — 옛 동작 보존)", bool(res1["season_reset"]))

	# ── ⑥ 게이트의 다른 입구(세이브 재개)도 막혔나 ──
	print("── ⑥ 재개 입구(로드 시 종료 게이트) ──")
	m.clock.day = 33          # 옛 게이트라면 재개 즉시 마무리 화면이 떴을 날(> RUN_DAYS)
	m._save_game()
	await _despawn(m)
	var m2: Node = await _new_main()
	_check("⑥a day 33 세이브가 그대로 복원", m2.clock.day == 33)
	_check("⑥b 재개해도 런이 끝나지 않는다(_run_over false)", m2._run_over == false)
	_check("⑥c 재개 화면에 마무리 패널 없음", not m2.ending_panel.visible)
	_check("⑥d 재개한 날의 절기가 유화절 5일", m2.clock.season_index() == 1
		and GameClock.day_of_season(m2.clock.day) == 5)
	await _despawn(m2)

	# ── 정리: 세이브 원복 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)
