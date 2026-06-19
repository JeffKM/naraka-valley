extends SceneTree
# T6.1 임시 헤드리스 단위검증 — 바나 NPC 밤 무대 배치 + 대화 텍스트박스를 실제 main 씬을
# 띄워 검증한다(ephemeral). npc_station_test.gd와 같은 결의 단언 하네스 — 배치/가시성·대화
# 라우팅이 main.gd(씬 오케스트레이션)에 살아 단독 노드로 떼어 검증할 수 없어, main.tscn을
# 인스턴스화해 시각·단계를 직접 흘려 분기를 굴린다.
# 실행: godot --headless --path game --script res://playtest/bana_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# main 씬을 새로 인스턴스화해 트리에 붙인다(npc_station_test와 동일 — _ready 한 프레임 대기).
func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	return m

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ T6.1 바나 NPC 밤 무대 배치 + 대화 단위검증 ══")
	# 결정적 검증을 위해 기존 세이브를 비우고 시작한다(신규 시작 = 통보 단계).
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ① 바나 인트로 대사가 비어 있지 않고, 이름이 "바나"다(대사는 캐릭터가 듦, ADR-0005) ──
	var bana := Bana.new()
	_check("① 바나 인트로 대사가 있다", bana.lines().size() > 0)
	_check("①b 이름이 바나다", bana.display_name() == "바나")
	# 같은 날 두 번째 대화(first_today=false) 줄도 있다(T6.2 일일 게이팅 자리 — 지금은 미사용).
	_check("①c 재대화 줄도 한 줄 있다", bana.lines(0, false).size() > 0)
	bana.free()

	var m: Node = await _new_main()
	# 신규 시작은 통보 단계(NOTICE).
	_check("②pre 신규 시작은 통보 단계", m.onboarding.step == Onboarding.NOTICE)

	# ── ② 바나는 밤(19시=Cafe.CLOSE_MIN)에만 밤 무대에 드러난다(낮엔 숨김) ──
	# 통보를 끝낸 상태로 강제(밤 가드는 onboarding.step > NOTICE도 본다 — 옥자 가드와 같은 결).
	m.onboarding.step = Onboarding.MEET_MIHO
	# 아침(06:00): 바나는 안 보인다(밤 아님).
	m.clock.minutes = 6 * 60
	m._update_bana_station()
	_check("② 아침엔 바나가 안 보임", not m.bana.visible)
	# 카페 영업(15:00): 아직 낮(빈 밤 슬롯 전)이라 안 보인다.
	m.clock.minutes = Cafe.OPEN_MIN
	m._update_bana_station()
	_check("②b 카페 영업(15시)에도 바나 안 보임", not m.bana.visible)
	# 밤(19:00, 빈 밤 슬롯 시작): 바나가 밤 무대에 선다.
	m.clock.minutes = Cafe.CLOSE_MIN
	m._update_bana_station()
	_check("③ 밤(19시)부터 바나가 밤 무대에 보임", m.bana.visible)
	# 자정 직전(23:59)도 밤이라 보인다(양방향 — 밤 창 내내 상주).
	m.clock.minutes = 23 * 60 + 59
	m._update_bana_station()
	_check("③b 자정 직전도 바나 보임", m.bana.visible)

	# ── ④ 통보(NOTICE) 도중엔 밤이어도 안 보인다(오프닝 컷신 가드 — 옥자와 같은 결) ──
	m.onboarding.step = Onboarding.NOTICE
	m.clock.minutes = Cafe.CLOSE_MIN
	m._update_bana_station()
	_check("④ 통보 단계면 밤이어도 바나 안 보임", not m.bana.visible)

	# ── ⑤ 위치·농사 제외: 밤 무대 칸 중앙에 서고, 그 칸은 농사 대상이 아니다 ──
	_check("⑤ 바나 위치가 밤 무대 칸 중앙", m.bana.position == m._tile_center_px(m.BANA_NIGHT_TILE))
	_check("⑤b 바나 칸은 농사 대상 아님(카페 바닥)", not m._is_farmable(m.BANA_NIGHT_TILE))

	# ── ⑥ 대화 라운드트립 + 온보딩 오전진 0: 통보 다음 단계(MEET_MIHO) 도중 바나와 대화해도
	#     온보딩이 전진하지 않는다(완료기준: 단계 도중 말 걸어도 오전진 없음) ──
	m.onboarding.step = Onboarding.MEET_MIHO
	var step_before: int = m.onboarding.step
	m._start_bana_dialogue()
	_check("⑥ 바나 대화가 열린다", m.dialogue.is_open())
	_check("⑥b 화자가 바나로 잡힌다", m._talking_to == m.bana.display_name())
	# E로 끝까지 넘기면 닫힌다(완료기준). 무한 루프 방어로 상한을 둔다.
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1
	_check("⑥c 끝까지 넘기면 대화가 닫힌다", not m.dialogue.is_open())
	_check("⑥d 대화 끝나도 온보딩 오전진 없음", m.onboarding.step == step_before)
	# 대화 종료 후 화자 래치가 비워진다(다음 대화에 새지 않게 — 멜·옥자와 같은 결).
	_check("⑥e 종료 후 화자 래치 비움", m._talking_to == "")
	m.free()

	# ── ⑦ 세이브 무상태 파생: 밤 시각 세이브를 복원하면 바나가 밤 무대에 이미 서 있다 ──
	# 바나 배치는 시각·단계에서 매 프레임 파생되는 무상태라(SaveManager 불변), 밤에 저장하고
	# 다시 켜면 _ready의 _update_bana_station이 바나를 다시 드러낸다("껐다 켜도 그대로").
	var m2: Node = await _new_main()
	m2.onboarding.step = Onboarding.MEET_MIHO
	m2.clock.minutes = Cafe.CLOSE_MIN + 60  # 20:00(밤)
	m2._save_game()
	m2.free()
	var m3: Node = await _new_main()  # _ready가 자동 복원 후 _update_bana_station 호출
	_check("⑦ 밤 시각 복원 시 바나가 밤 무대에 보임", m3.bana.visible)
	m3.free()

	# 테스트 잔여 세이브 정리(다른 실행·플레이에 새지 않게).
	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
