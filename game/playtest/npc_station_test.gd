extends SceneTree
# T5.6 임시 헤드리스 단위검증 — 옥자 카페 상주 + 미호 카페 출근 + 세이브 통합을
# 실제 main 씬을 띄워 검증한다(ephemeral). cafe_test.gd와 같은 결의 단언 하네스지만,
# 배치/출퇴근 로직이 main.gd(씬 오케스트레이션)에 살아 cafe.gd처럼 단독 노드로 떼어
# 검증할 수 없어 — main.tscn을 인스턴스화해 시각·단계를 직접 흘려 분기를 굴린다.
# 실행: godot --headless --path game --script res://playtest/npc_station_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# main 씬을 새로 인스턴스화해 트리에 붙인다. SceneTree 시작 전(_initialize)엔 add_child
# 직후 _ready가 바로 안 돌아 한 프레임 기다린다(@onready·자동 로드 완료 보장).
func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	return m

# _initialize는 SceneTree 시작 직전 호출된다. main 씬의 _ready를 한 프레임 돌리려고
# 코루틴으로 둔다(await). 단언 하네스 자체는 cafe_test.gd와 동일.
func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ T5.6 NPC 상주/출근 + 세이브 통합 단위검증 ══")
	# 결정적 검증을 위해 기존 세이브를 비우고 시작한다(신규 시작 = 통보 단계).
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ① 옥자 일상 대사: 비어 있지 않고 통보 대사(LINES_INTRO)와 다르다 ──
	var okja := Okja.new()
	var resident := okja.lines_resident()
	_check("① 옥자 상주 일상 대사가 있다", resident.size() > 0)
	_check("①b 상주 대사 ≠ 통보 대사(별도 묶음)", resident != okja.lines())
	okja.free()

	# ── ② 미호 출퇴근: 영업 시작(15시) 경계로 밭↔카페 자리가 갈린다 ──
	var m: Node = await _new_main()
	# 신규 시작은 통보 단계(NOTICE) — 옥자는 통보 자리에 보이고 카페엔 아직 없다.
	_check("②pre 신규 시작은 통보 단계", m.onboarding.step == Onboarding.NOTICE)

	# 아침(06:00): 미호는 밭 자리.
	m.clock.minutes = 6 * 60
	m._update_miho_station()
	_check("② 아침엔 미호가 밭 자리", m._miho_tile == m.MIHO_FIELD_TILE)
	_check("②b 미호 위치도 밭 자리 중앙", m.miho.position == m._tile_center_px(m.MIHO_FIELD_TILE))

	# 오후(15:00 영업 시작): 미호가 카페로 출근.
	m.clock.minutes = Cafe.OPEN_MIN
	m._update_miho_station()
	_check("③ 15시부터 미호가 카페 출근", m._miho_tile == m.MIHO_CAFE_TILE)
	_check("③b 미호 위치도 카페 자리 중앙", m.miho.position == m._tile_center_px(m.MIHO_CAFE_TILE))

	# 다시 아침이면(다음 날) 밭으로 복귀 — 출퇴근이 양방향이다.
	m.clock.minutes = 6 * 60
	m._update_miho_station()
	_check("③c 아침 복귀 시 다시 밭 자리", m._miho_tile == m.MIHO_FIELD_TILE)

	# ── ④ 미호 밭 자리는 출근 중에도 농사 대상에서 제외(돌아올 자리) ──
	m.clock.minutes = Cafe.OPEN_MIN
	m._update_miho_station()  # 미호는 카페에 있지만…
	_check("④ 미호 밭 자리는 출근 중에도 농사 불가", not m._is_farmable(m.MIHO_FIELD_TILE))

	# ── ⑤ 옥자 상주: 통보를 마치면(NOTICE 지남) 카페 자리에 보인다 ──
	m.okja.visible = false
	m.onboarding.step = Onboarding.MEET_MIHO  # 통보를 끝낸 상태로 강제
	m._refresh_okja_station()
	_check("⑤ 통보 후 옥자가 카페에 보임", m.okja.visible)
	_check("⑤b 옥자 위치가 카페 상주 자리", m.okja.position == m._tile_center_px(m.OKJA_CAFE_TILE))
	# 통보 단계로 되돌리면 상주 배치는 손대지 않는다(통보 흐름이 관리 — 멱등·단계 가드).
	m.okja.visible = false
	m.onboarding.step = Onboarding.NOTICE
	m._refresh_okja_station()
	_check("⑤c 통보 단계면 상주 배치 안 함(통보 흐름 소관)", not m.okja.visible)

	# ── ⑥ 세이브 통합: 멜 호감도가 저장·복원된다(완료기준 — SaveManager 불변) ──
	# 멜 호감도를 올리고 main이 모은 조각으로 저장한 뒤, 새 main이 자동 복원하는지 본다.
	m.mel_affinity.points = 80  # 임의 점수(하트 단계가 0이 아니게 — 80/40 = ♡2)
	var mel_hearts: int = m.mel_affinity.hearts()
	m._save_game()
	m.free()

	var m2: Node = await _new_main()  # _ready가 has_save()를 보고 자동 복원
	_check("⑥ 멜 호감도가 세이브에서 복원됨", m2.mel_affinity.hearts() == mel_hearts and mel_hearts > 0)
	# 복원 직후 옥자/미호 배치도 진행/시각에 맞춰 동기화돼 있다(껐다 켜도 그대로).
	_check("⑥b 복원 후 미호 자리가 시각과 일치",
		m2._miho_tile == (m2.MIHO_CAFE_TILE if m2.clock.minutes >= Cafe.OPEN_MIN else m2.MIHO_FIELD_TILE))
	m2.free()

	# ── ⑦ 세이브 삭제+새 시작(F8) 2단 확인 가드: 첫 누름은 무장만, 삭제하지 않는다 ──
	# (실제 reload_current_scene은 윈도우가 필요해 제외 — F5/F9 키처럼 부팅 클린으로 커버.
	#  여기선 "한 번 눌러도 진행이 안 날아간다"는 안전 가드만 검증한다.) ⑥에서 쓴 save.dat가
	# 디스크에 남아 있는 상태에서 시작한다.
	var m3: Node = await _new_main()
	_check("⑦pre 세이브 파일이 디스크에 있음", m3.saver.has_save())
	m3._arm_or_confirm_delete()  # 첫 F8 — 무장만
	_check("⑦ 첫 F8은 무장만(아직 삭제 안 함)", m3._delete_armed_secs > 0.0 and m3.saver.has_save())
	m3.free()

	# 테스트 잔여 세이브 정리(다른 실행·플레이에 새지 않게).
	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
