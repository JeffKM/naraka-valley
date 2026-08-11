extends SceneTree
# ★[S8-T6 / ADR-0066 결정 6·7] 연애 — ♡5 의지 시험·단일 슬롯·질투 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 제안 자격 — ♡4 만충 + ROMANCE_OPEN(메인 3인)만 고백 제안이 선다 · 관문 진급 대화엔 안 선다
#      (대화 한 번에 사건 하나) · T1(네오)은 구조상 잠금(S9 점진).
#   ② 보류 무벌칙 — 제안을 넘겨 닫아도 상태 무변화·다음 대화에 제안 재등장(재시도 자유).
#   ③ 수락 — ♡5 진급 = 연애 개시 동일 시점 · 슬롯 점유 · 비트 5 마킹 · 수락 발화 교체.
#   ④ 질투 — 개시 순간 1회, 안 뽑힌 메인 2인 −30(실제 깎인 양만 원장 기록 — 바닥 방어).
#   ⑤ 슬롯 1 강제 — 연애 중 두 번째 고백 = 인-픽션 거절(무벌칙·점수/stage/대기 불변·재시도 가능).
#   ⑥ 질투 복원 — 7일 전엔 불변·7일에 깎인 만큼 정확히 복원·원장 소거(흔적 0).
#   ⑦ 일상 선물 무질투 — 연애 중 다른 주민 선물이 질투 원장을 건드리지 않는다.
#   ⑧ 세이브 왕복 — 슬롯·질투 원장 보존 · 구세이브(키 없음) = 연애 없음.
#   ⑨ 관계 탭 배지 — 연인 = "연애 중"(진급 대기보다 우선) · 타인은 기존 배지 그대로.
#   ⑩ 재구애 — 슬롯 해제(이혼 스텁) 후 재고백 = 조용한 수락(본 비트 재지급 없음 — 대화 닫힘).
#
# 실행: ./run_tests.sh romance   (헤드리스는 반드시 game/에서 · 순차)

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

# 신규 시작의 옥자 통보 대화를 끝까지 넘겨 닫는다.
func _dismiss_intro(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

func _close_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

# 그 사람을 ♡4 만충(점수 = ♡5 칸까지 채움 = 의지 시험 대기)으로 세팅한다.
func _stage4_full(r: Resident) -> void:
	r.affinity.points = Affinity.MAX_POINTS
	r.affinity.stage = Affinity.MAX_HEARTS - 1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S8-T6 연애 — 의지 시험·단일 슬롯·질투 검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_dismiss_intro(m)
	m.onboarding.step = Onboarding.DONE
	var r_miho: Resident = m._resident("miho")
	var r_mel: Resident = m._resident("mel")
	var r_bana: Resident = m._resident("bana")
	var r_neo: Resident = m._resident("neo")

	# ── ① 제안 자격 ──
	print("── ① 제안 자격 ──")
	_stage4_full(r_miho)
	_check("①a ♡4 만충 메인 = 제안 자격", m._romance_offer_available(r_miho))
	r_miho.affinity.stage = 3
	_check("①b ♡3 만충은 제안 아님(♡4 진급은 관문 소관)", not m._romance_offer_available(r_miho))
	r_miho.affinity.stage = 4
	r_miho.affinity.points = 5 * Affinity.POINTS_PER_HEART - 1
	_check("①c ♡4라도 점수 미만충이면 제안 없음", not m._romance_offer_available(r_miho))
	_stage4_full(r_neo)
	_check("①d T1(네오)은 ♡4 만충이어도 제안 없음(S8 개통 = 메인 3인 — S9 점진)",
		not m._romance_offer_available(r_neo))
	r_neo.affinity.points = 0
	r_neo.affinity.stage = 0
	# 대화 경로 — 제안 한 줄이 맨 앞에 선다.
	_stage4_full(r_miho)
	m._start_resident_dialogue(r_miho)
	_check("①e 대화 첫 줄 = 고백 제안·제안 rid 세팅",
		m.dialogue.is_open() and m.dialogue.line() == m.CONFESS_OFFER_LINE
		and m._confess_rid == "miho")
	_close_dialogue(m)
	# 관문 진급이 성사된 대화엔 제안이 안 선다(사건 하나 규율) — ♡3→4 진급 대화로 확인.
	r_miho.affinity.stage = 3
	r_miho.affinity.points = Affinity.MAX_POINTS
	m._run_harvested = 300              # 미호 ♡4 deed(수확 300) 충족
	m._heart_bits = {}                  # 관문 발화가 다시 틀리게 비트 리셋
	m._start_resident_dialogue(r_miho)
	_check("①f 관문 진급 대화엔 제안이 안 선다(다음 대화로 미룸)",
		r_miho.affinity.hearts() == 4 and m._confess_rid == ""
		and m.dialogue.line() == m.HEART_GATE_PLACEHOLDER_LINE)
	_close_dialogue(m)

	# ── ② 보류 무벌칙 ──
	print("── ② 보류 무벌칙 ──")
	m._start_resident_dialogue(r_miho)   # ♡4 만충 상태 그대로 — 이번엔 제안이 선다
	_check("②a 다음 대화엔 제안이 선다", m._confess_rid == "miho")
	_close_dialogue(m)                   # [F] 없이 끝까지 넘김 = 아직
	_check("②b 넘겨 닫으면 상태 무변화(무벌칙 — stage·대기·슬롯 그대로)",
		r_miho.affinity.hearts() == 4 and r_miho.affinity.pending_promotion()
		and m._romance_partner == "" and m._confess_rid == "")
	m._start_resident_dialogue(r_miho)
	_check("②c 재시도 자유 — 제안 재등장", m._confess_rid == "miho")

	# ── ③ 수락 + ④ 질투 ──
	print("── ③ 수락·④ 질투 ──")
	r_mel.affinity.points = 100          # 질투 전 점수(30 이상 — 온전히 깎인다)
	r_bana.affinity.points = 10          # 바닥 방어 확인용(10만 깎인다)
	m.clock.day = 20
	m._resolve_confession("miho")
	_check("③a 수락 = ♡5 진급 + 연애 개시 동일 시점",
		m._romance_partner == "miho" and r_miho.affinity.hearts() == Affinity.MAX_HEARTS
		and not r_miho.affinity.pending_promotion())
	_check("③b 비트 5 마킹(의지 시험도 비트 원장에 든다)",
		m._heart_bit_seen("miho", Affinity.MAX_HEARTS))
	_check("③c 수락 발화가 대화를 교체한다",
		m.dialogue.is_open() and m.dialogue.line() == m.CONFESS_ACCEPT_LINE)
	_close_dialogue(m)
	_check("④a 안 뽑힌 메인 2인 −30(멜 100→70)", r_mel.affinity.points == 70)
	_check("④b 바닥 방어 — 10점이던 바나는 10만 깎인다(0 하한)", r_bana.affinity.points == 0)
	_check("④c 원장 = 실제 깎인 양·복원 예정일(+7일)",
		int(m._jealousy["mel"]["amount"]) == 30 and int(m._jealousy["mel"]["restore_day"]) == 27
		and int(m._jealousy["bana"]["amount"]) == 10 and int(m._jealousy["bana"]["restore_day"]) == 27)

	# ── ⑤ 슬롯 1 강제(두 번째 시도 = 인-픽션 거절) ──
	print("── ⑤ 슬롯 1 강제 ──")
	_stage4_full(r_mel)
	_check("⑤a 슬롯 점유 중에도 제안은 선다(거절 장면의 전제)", m._romance_offer_available(r_mel))
	m._start_resident_dialogue(r_mel)
	var mel_pts: int = r_mel.affinity.points
	m._resolve_confession("mel")
	_check("⑤b 두 번째 고백 = 인-픽션 거절 발화",
		m.dialogue.is_open() and m.dialogue.line() == m.CONFESS_REJECT_LINE)
	_check("⑤c 무벌칙 — 슬롯·stage·점수·대기 전부 불변",
		m._romance_partner == "miho" and r_mel.affinity.hearts() == 4
		and r_mel.affinity.points == mel_pts and r_mel.affinity.pending_promotion())
	_close_dialogue(m)
	m._start_resident_dialogue(r_mel)
	_check("⑤d 거절 후 재시도 가능(이혼으로 슬롯이 비면 그때 수락된다)", m._confess_rid == "mel")
	_close_dialogue(m)
	r_mel.affinity.points = 70           # ⑤a가 만충으로 올렸던 점수를 질투 검증 값으로 되돌린다
	r_mel.affinity.stage = 2

	# ── ⑥ 질투 복원(7일 타이머) ──
	print("── ⑥ 질투 복원 ──")
	m._advance_jealousy(26)              # 예정일(27) 전
	_check("⑥a 7일 전엔 불변", r_mel.affinity.points == 70 and r_bana.affinity.points == 0
		and m._jealousy.size() == 2)
	m._advance_jealousy(27)              # 예정일 도달
	_check("⑥b 깎인 만큼 정확히 복원(멜 +30·바나 +10 — 공짜 점수 없음)",
		r_mel.affinity.points == 100 and r_bana.affinity.points == 10)
	_check("⑥c 원장 소거 = 흔적 0", m._jealousy.is_empty())

	# ── ⑦ 일상 선물 무질투 ──
	print("── ⑦ 일상 선물 무질투 ──")
	m.clock.day = 30
	var held: bool = m.inventory.add_item(CropCatalog.HONRYEONGCHO, 1, ItemCatalog.Q_NORMAL)
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == CropCatalog.HONRYEONGCHO:
			m.inventory.select(i)
			break
	var bana_before: int = r_bana.affinity.points
	m._try_resident_gift(r_bana)
	_check("⑦a 연애 중 타인 선물 = 점수만 오르고 질투 0",
		held and r_bana.affinity.points > bana_before and m._jealousy.is_empty())

	# ── ⑧ 세이브 왕복 ──
	print("── ⑧ 세이브 왕복 ──")
	m._jealousy = {"mel": {"restore_day": 40, "amount": 15}}   # 진행 중 타이머를 실어 본다
	m._save_game()
	m.free()
	var m2: Node = await _new_main()     # _ready가 자동 복원
	_check("⑧a 연애 슬롯 보존", m2._romance_partner == "miho")
	_check("⑧b 질투 원장 보존(예정일·깎인 양)",
		int(m2._jealousy.get("mel", {}).get("restore_day", 0)) == 40
		and int(m2._jealousy.get("mel", {}).get("amount", 0)) == 15)
	_check("⑧c 연인 하트도 세이브 축(♡5 유지)", m2.affinity.hearts() == Affinity.MAX_HEARTS)

	# ── ⑨ 관계 탭 배지 ──
	print("── ⑨ 관계 탭 배지 ──")
	var r2_miho: Resident = m2._resident("miho")
	var r2_mel: Resident = m2._resident("mel")
	_check("⑨a 연인 = '연애 중' 배지", m2._heart_badge(r2_miho) == "연애 중")
	_stage4_full(r2_mel)
	_check("⑨b 타인 진급 대기 배지는 그대로", m2._heart_badge(r2_mel) == "진급 대기")
	r2_mel.affinity.points = 0
	r2_mel.affinity.stage = 0

	# ── ⑩ 재구애 = 조용한 수락(본 비트 재지급 없음) ──
	print("── ⑩ 재구애 ──")
	m2._romance_partner = ""             # 이혼 스텁(슬롯 해제 — T7이 정식 경로를 연다)
	m2._jealousy = {}
	r2_miho.affinity.stage = Affinity.MAX_HEARTS - 1   # ♡4로 리셋(점수는 만충 그대로)
	m2._start_resident_dialogue(r2_miho)
	_check("⑩a 재도달 = 제안 재등장", m2._confess_rid == "miho")
	m2._resolve_confession("miho")
	_check("⑩b 조용한 수락 — 진급·연애는 되지만 발화 재지급 없음(대화 닫힘)",
		m2._romance_partner == "miho" and r2_miho.affinity.hearts() == Affinity.MAX_HEARTS
		and not m2.dialogue.is_open())
	m2.free()

	# 뒷정리 — 이 테스트가 만든 세이브를 지운다(다른 테스트의 자동 복원 오염 방지).
	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ romance_test 전체 통과 ══")
	else:
		print("══ romance_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)
