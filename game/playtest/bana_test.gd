extends SceneTree
# T6.1/T6.2/T6.3/T6.4/T6.5/T6.6 임시 헤드리스 단위검증 — 바나 NPC 밤 무대 배치·대화(T6.1)·호감도
# (T6.2)·바 옵트인(T6.3)·막기/응대/이중 손실(T6.4)·이중 보호 축(T6.5)·Sprint 6 통합(T6.6)을
# 실제 main 씬으로 검증. npc_station_test.gd와 같은 결의 단언 하네스 — 배치/가시성·대화 라우팅이
# main.gd(씬 오케스트레이션)에 살아 단독 노드로 떼어 검증할 수 없어, main.tscn을 인스턴스화해
# 시각·단계·호감도를 직접 흘려 분기를 굴린다.
#
# T6.6(Sprint 6 통합)은 앞 작업들이 *점단위*로 검증한 조각들을 통합 관점으로 마무리한다:
#   ㉖ 배치 정합 — 밤 시각에 네 NPC(옥자·멜·미호·바나)가 시각·단계에서 파생되어 서로 다른
#      칸에 충돌 없이 서고, 바나 칸이 좌석 줄(응대)·스폿 줄(막기)과 겹치지 않는다(무대 일관).
#   ㉗ 밤 루프 end-to-end — 옵트인→막기→자동차단(이중 보호 ㉠)→실제 약탈(이중 손실 ㉮)→응대
#      매출(㉯)→취침 정산(손실 이월 0)이 *한 밤 한 흐름*으로 끝까지 굴러가고, 그 사이 바나
#      호감도가 일 경계·세이브를 넘어 보존된다("바나 세이브 + 배치 정합 + 통합" 한자리 검증).
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
	print("══ T6.1/T6.2 바나 NPC 밤 무대 + 호감도(대화·선물) 단위검증 ══")
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

	# ══════════════ T6.2 호감도(일일 대화 · 선물 · 하트별 대사 · 세이브) ══════════════
	var m4: Node = await _new_main()
	# ── ⑧ 선호 작물 분화: 바나=혼령초(미호=영혼 호박·멜=피안화와 분리, affinity.gd 인스턴스
	#     하나에 preferred_crop만 바꿔 재사용). 시작 호감도는 0 ──
	_check("⑧ 바나 선호 작물이 혼령초", m4.bana_affinity.preferred_crop == CropCatalog.HONRYEONGCHO)
	_check("⑧b 바나 호감도 시작 0", m4.bana_affinity.points == 0)

	# ── ⑨ 일일 대화: 오늘 첫 대화면 호감도 소폭↑, 같은 날 두 번째는 점수 불변(하루 1회 게이팅) ──
	m4.clock.day = 1
	var p0: int = m4.bana_affinity.points
	m4._start_bana_dialogue()
	_check("⑨ 첫 대화로 호감도가 오른다", m4.bana_affinity.points == p0 + Affinity.DAILY_TALK_POINTS)
	_check("⑨b 오늘은 더 못 받는다(일일 게이팅)", not m4.bana_affinity.can_daily_talk(1))
	var g1 := 0
	while m4.dialogue.is_open() and g1 < 50:
		m4.dialogue.advance()
		g1 += 1
	var p1: int = m4.bana_affinity.points
	m4._start_bana_dialogue()  # 같은 날 두 번째 대화
	_check("⑨c 같은 날 두 번째 대화는 호감도 불변", m4.bana_affinity.points == p1)
	var g2 := 0
	while m4.dialogue.is_open() and g2 < 50:
		m4.dialogue.advance()
		g2 += 1

	# ── ⑩ 선물: 선호(혼령초)는 큰 폭, 비선호는 작은 폭. 하루 1회 게이팅, 막힌 선물은 무소모 ──
	m4.clock.day = 2
	m4.inventory.add_harvest(CropCatalog.HONRYEONGCHO, 1)
	m4.inventory.add_harvest(CropCatalog.PIANHWA, 1)
	m4._selected_crop = CropCatalog.HONRYEONGCHO
	var pg0: int = m4.bana_affinity.points
	m4._try_bana_gift()
	var pref_gain: int = m4.bana_affinity.points - pg0
	_check("⑩ 선호(혼령초) 선물로 호감도가 크게 오른다", pref_gain == Affinity.GIFT_PREFERRED_POINTS)
	_check("⑩b 선물한 혼령초 1개가 소모됨", m4.inventory.harvest_count(CropCatalog.HONRYEONGCHO) == 0)
	m4._selected_crop = CropCatalog.PIANHWA
	var pg1: int = m4.bana_affinity.points
	m4._try_bana_gift()  # 같은 날 두 번째 선물
	_check("⑩c 같은 날 두 번째 선물은 막힌다", m4.bana_affinity.points == pg1)
	_check("⑩d 막힌 선물은 작물을 소모하지 않음", m4.inventory.harvest_count(CropCatalog.PIANHWA) == 1)
	m4.clock.day = 3  # 다음 날: 비선호(피안화) 선물
	var pg2: int = m4.bana_affinity.points
	m4._try_bana_gift()
	var normal_gain: int = m4.bana_affinity.points - pg2
	_check("⑩e 비선호 작물 선물은 작은 폭", normal_gain == Affinity.GIFT_POINTS)
	_check("⑩f 선호 선물이 일반 선물보다 큼", pref_gain > normal_gain)
	m4.free()

	# ── ⑪ 하트별 대사 분기: ♡0 인트로 / ♡2–3 밤 경비 속죄 / ♡4+ '목격' 조각이 서로 다르고,
	#     ♡4+엔 옥자 목격 떡밥이 깔린다(미호·멜과 같은 틀, 바나=목격 각도 ADR-0005) ──
	var b2 := Bana.new()
	var intro := b2.lines(0, true)
	var warming := b2.lines(2, true)
	var fact := b2.lines(4, true)
	_check("⑪ ♡0·♡2·♡4 대사 묶음이 서로 다르다", intro != warming and warming != fact and intro != fact)
	_check("⑪b ♡4+ '목격' 조각에 옥자가 등장한다(봉인 죄목 떡밥)", "\n".join(fact).contains("옥자"))
	# 같은 날 두 번째(first_today=false)는 하트와 무관하게 짧은 재대화 한 줄.
	_check("⑪c 재대화는 하트 무관 한 줄", b2.lines(4, false).size() == 1)
	b2.free()

	# ── ⑫ 세이브 라운드트립: 바나 호감도 점수가 저장·복원된다(SaveManager 불변, 한 조각 추가) ──
	# T7.3: 곡선이 슬라이스 길이에 비례 스케일되므로(POINTS_PER_HEART) ♡2를 점수 상수에서
	# 파생한다 — 21일(60점/칸)·14일(40점/칸) 어느 쪽으로 RUN_DAYS를 돌려도 ♡2로 떨어진다.
	var m5: Node = await _new_main()
	var pts_h2: int = 2 * Affinity.POINTS_PER_HEART + 15  # ♡2 칸 안(다음 칸 임계 미만)
	m5.bana_affinity.points = pts_h2
	m5._save_game()
	m5.free()
	var m6: Node = await _new_main()  # _ready가 자동 복원
	_check("⑫ 바나 호감도 점수가 세이브에 저장·복원됨", m6.bana_affinity.points == pts_h2)
	_check("⑫b 복원된 하트 단계도 일치(♡2)", m6.bana_affinity.hearts() == 2)
	m6.free()

	# ══════════════ T6.3 나라카 바 옵트인(밤 영업 창 + 잡귀 등장 게이팅) 통합 ══════════════
	# night_bar.gd 계약은 night_bar_test.gd가 단위로 검증한다. 여기선 main이 그 노드를
	# *제대로 배선*했는지(옵트인 키 경로·스폰 게이팅·취침 리셋·세이브 무상태)를 main 씬으로 본다.
	var m7: Node = await _new_main()
	m7.onboarding.step = Onboarding.MEET_MIHO  # 통보 지난 상태(밤 무대·바 게이트가 열리는 단계)
	# ⑬ 시작은 안 열림 — 밤이어도 잡귀 없음(완료기준 "열 때만 등장", 옵트인 X = 빈 밤).
	m7.clock.minutes = NightBar.OPEN_MIN + 60  # 20:00(밤 창)
	m7.night_bar.tick(5.0, m7.clock.minutes)
	_check("⑬ 안 열면 밤이어도 잡귀 없음(빈 밤)", not m7.night_bar.is_opened() and m7.night_bar.threat_count() == 0)
	# ⑭ 낮엔 옵트인이 막힌다(밤 창 밖) — main의 _open_night_bar가 open_bar 창 가드를 탄다.
	m7.clock.minutes = 12 * 60  # 낮
	m7._open_night_bar()
	_check("⑭ 낮엔 바를 못 연다", not m7.night_bar.is_opened())
	# ⑮ 밤에 _open_night_bar로 옵트인 → tick하면 잡귀가 깃든다(완료기준 "바를 열 때만 등장").
	m7.clock.minutes = NightBar.OPEN_MIN + 60
	m7._open_night_bar()
	_check("⑮ 밤에 _open_night_bar로 바 열림", m7.night_bar.is_opened())
	m7.night_bar.tick(NightBar.SPAWN_INTERVAL + 0.1, m7.clock.minutes)
	_check("⑮b 열고 tick → 잡귀 등장·활성", m7.night_bar.threat_count() >= 1 and m7.night_bar.is_active())
	# ⑯ 자정 전 취침(_on_day_advanced) → 밤 정산 약탈 0 + 옵트인 리셋(다음 밤 새 선택, 손실 이월 0).
	var raided: int = m7.night_bar.tonight_raided()
	m7._on_day_advanced(2)  # 슬라이스 안(끝 아님) — 작물 성장·혼력 회복 + night_bar.end_day
	_check("⑯ 자정 전 취침 시 손실 0(약탈 0)", raided == 0)
	_check("⑯b 취침 후 옵트인 리셋(빈 밤으로 복귀)", not m7.night_bar.is_opened() and m7.night_bar.threat_count() == 0)
	# ⑰ 세이브 무상태: 밤 바는 직렬화 항목이 없다(SaveManager 불변 — T6.2 바나 affinity 한
	#    조각만 추가됐고, 밤 바 상태는 옵트인·잡귀 모두 일시적). 밤에 바를 연 채 저장하고 새
	#    인스턴스로 복원해도, 밤 바는 무상태라 안 열린 채(빈 밤) 깨끗이 시작한다.
	m7.clock.minutes = NightBar.OPEN_MIN + 60
	m7.night_bar.open_bar(m7.clock.minutes)  # 밤에 바를 연 상태로
	m7._save_game()
	m7.free()
	var m8: Node = await _new_main()
	_check("⑰ 밤 바는 세이브 무상태(복원 후 안 열림·잡귀 0)", not m8.night_bar.is_opened() and m8.night_bar.threat_count() == 0)
	m8.free()

	# ══════════════ T6.4 막기 + 응대 + 이중 손실 (main 배선) ══════════════
	# night_bar.gd 계약은 night_bar_test.gd가 단위로 검증한다. 여기선 main이 막기(_try_block)·
	# 응대(_try_night_serve)·약탈 적용(resolved → _on_night_resolved → 재고 차감)을 *제대로
	# 배선*했는지 main 씬으로 본다(키 입력 대신 핸들러를 직접 불러 입력 경로를 검증).
	var m9: Node = await _new_main()
	m9.onboarding.step = Onboarding.MEET_MIHO
	m9.clock.minutes = NightBar.OPEN_MIN + 60  # 20:00(밤 창)
	# T6.4 배선은 *막기 실패→약탈* base 경로(♡0, 바나 잠듦)를 본다 — 직전 테스트가 남긴 세이브가
	# 바나 ♡2로 복원되면 T6.5 자동 차단이 돌파를 대신 막아(약탈 0) base 경로가 가려지므로, 밤 바를
	# 열기 전 호감도·seam을 ♡0 base로 고정한다(자동 차단 경로는 아래 T6.5 ㉕에서 별도 검증).
	m9.bana_affinity.points = 0
	m9.night_bar.raid_amount = NightBar.DEFAULT_RAID
	m9.night_bar.auto_block = NightBar.DEFAULT_AUTO_BLOCK
	m9._open_night_bar()
	# ⑱ 막기: 잡귀를 깃들이고 _try_block → 즉시 격퇴(스폿 비움). main이 block 계약을 배선했다.
	m9.night_bar.tick(NightBar.SPAWN_INTERVAL + 0.1, m9.clock.minutes)
	_check("⑱ 막기 전 잡귀 존재", m9.night_bar.is_threat(0))
	m9._try_block(0)
	_check("⑱b _try_block → 잡귀 즉시 격퇴(스폿 비움)", not m9.night_bar.is_threat(0))
	# ⑲ 막기 실패 → 재고 약탈(이중 손실 ㉮): 돌파 시 resolved가 main을 통해 수확물을 덜어낸다.
	m9.inventory.add_harvest(CropCatalog.HONRYEONGCHO, 3)
	var before: int = m9.inventory.total_harvest()
	m9.night_bar.tick(NightBar.SPAWN_INTERVAL + 0.1, m9.clock.minutes)  # 잡귀 재등장
	m9.night_bar.tick(NightBar.DEFAULT_APPROACH + 1.0, m9.clock.minutes)  # 안 막아 돌파 → 약탈
	_check("⑲ 막기 실패 시 재고가 약탈된다(미래 자산↓)", m9.inventory.total_harvest() == before - NightBar.DEFAULT_RAID)
	_check("⑲b 약탈량이 밤 정산에 쌓인다", m9.night_bar.tonight_raided() >= NightBar.DEFAULT_RAID)
	# ⑳ 응대(이중 손실 ㉯의 반대편 — 현재 자산): 바 손님을 _try_night_serve → 밤 매출 즉시 지갑 반영.
	m9.night_bar.tick(NightBar.CUST_INTERVAL + 0.1, m9.clock.minutes)  # 손님 착석
	_check("⑳ 응대 전 바 손님 존재", m9.night_bar.is_waiting(0))
	var gold_before: int = m9.wallet.gold
	m9._try_night_serve(0)
	_check("⑳b _try_night_serve → 밤 매출이 지갑에 들어온다", m9.wallet.gold == gold_before + NightBar.SERVE_PRICE)
	_check("⑳c 응대한 좌석은 비고 밤 매출이 누적된다", not m9.night_bar.is_waiting(0) and m9.night_bar.tonight_revenue() == NightBar.SERVE_PRICE)
	m9.free()

	# ══════════════ T6.5 바나 이중 보호 축 (BanaGuard 매핑 + main 주입) ══════════════
	# ㉠ 재고 방어(약탈량↓·자동 차단↑) · ㉡ 응대 보호(인내심↑). foxfire/cafe_margin 패턴(static
	# 매핑·세이브 무상태·base 위 얹기). ♡0 = night_bar 기본값 = 바나 잠듦(평평≠막힘, ADR-0008).
	# ── ㉑ BanaGuard 매핑 앵커: ♡0이면 세 축 모두 night_bar 기본값(바나 잠듦) ──
	_check("㉑ ♡0 약탈량 = night_bar 기본값", BanaGuard.raid_amount(0) == NightBar.DEFAULT_RAID)
	_check("㉑b ♡0 자동차단 = 0", BanaGuard.auto_block(0) == NightBar.DEFAULT_AUTO_BLOCK)
	_check("㉑c ♡0 인내심 = night_bar 기본값", is_equal_approx(BanaGuard.patience_secs(0), NightBar.DEFAULT_PATIENCE))
	_check("㉑d ♡0이면 바나 보호 잠듦", not BanaGuard.is_awake(0))
	# ── ㉒ ㉠ 재고 방어: ♡↑ → 약탈량 단조 감소(하한 1) · 자동차단 단조 증가 ──
	_check("㉒ ♡↑ 약탈량 단조 감소",
		BanaGuard.raid_amount(5) <= BanaGuard.raid_amount(2) and BanaGuard.raid_amount(2) <= BanaGuard.raid_amount(0))
	_check("㉒b 약탈량 하한 1(손실 방지지 무효화 아님 — 밤 긴장 유지)", BanaGuard.raid_amount(5) == BanaGuard.MIN_RAID)
	_check("㉒c ♡↑ 자동차단 단조 증가",
		BanaGuard.auto_block(5) >= BanaGuard.auto_block(2) and BanaGuard.auto_block(2) >= BanaGuard.auto_block(0) and BanaGuard.auto_block(5) > 0)
	# ── ㉓ ㉡ 응대 보호: ♡↑ → 인내심 단조 증가, ♡>0이면 보호 깨어남 ──
	_check("㉓ ♡↑ 인내심 단조 증가", BanaGuard.patience_secs(5) > BanaGuard.patience_secs(0))
	_check("㉓b ♡1부터 보호 깨어남(인내심 축)", BanaGuard.is_awake(1))
	_check("㉓c 범위 방어(음수·초과 clamp)",
		BanaGuard.raid_amount(-3) == BanaGuard.raid_amount(0) and BanaGuard.auto_block(99) == BanaGuard.auto_block(Affinity.MAX_HEARTS))

	# ── ㉔ main 주입: 바나 하트를 올리고 한 프레임 굴리면 night_bar seam에 BanaGuard 값이 얹힌다 ──
	#     (cafe.margin과 같은 다리 — night_bar는 바나 호감도를 모르고 파라미터만 받는다.)
	var m10: Node = await _new_main()
	m10.onboarding.step = Onboarding.MEET_MIHO
	m10.clock.minutes = NightBar.OPEN_MIN + 60        # 20:00(밤 창)
	m10.bana_affinity.points = Affinity.MAX_POINTS    # ♡5(만렙)
	await process_frame                                # main._process가 주입을 한 번 굴리게
	var h5: int = m10.bana_affinity.hearts()
	_check("㉔ 주입: night_bar.raid_amount = BanaGuard.raid_amount(하트)", m10.night_bar.raid_amount == BanaGuard.raid_amount(h5))
	_check("㉔b 주입: night_bar.auto_block = BanaGuard.auto_block(하트)", m10.night_bar.auto_block == BanaGuard.auto_block(h5))
	_check("㉔c 주입: night_bar.patience_secs = BanaGuard.patience_secs(하트)", is_equal_approx(m10.night_bar.patience_secs, BanaGuard.patience_secs(h5)))
	# ── ㉕ 체감(end-to-end): ♡5에서 못 막은 돌파를 바나가 자동 차단해 재고가 안 줄어든다 ──
	#     (open_bar가 현재 주입된 auto_block으로 이 밤 차단 횟수를 채운다.)
	m10._open_night_bar()
	m10.inventory.add_harvest(CropCatalog.HONRYEONGCHO, 5)
	var inv_before: int = m10.inventory.total_harvest()
	m10.night_bar.tick(NightBar.SPAWN_INTERVAL + 0.1, m10.clock.minutes)
	m10.night_bar.tick(NightBar.DEFAULT_APPROACH + 1.0, m10.clock.minutes)  # 안 막아 돌파 → 자동 차단
	_check("㉕ ♡5 자동 차단으로 첫 돌파는 재고가 안 줄어듦(체감)",
		m10.inventory.total_harvest() == inv_before and m10.night_bar.tonight_auto_blocked() >= 1)
	m10.free()

	# ══════════════ T6.6 Sprint 6 통합: 배치 정합 + 밤 루프 end-to-end + 바나 세이브 ══════════════
	# 앞 작업들이 점단위로 본 조각을 통합 관점으로 마무리한다(T5.6과 같은 결의 통합 검증).
	print("── T6.6 Sprint 6 통합(배치 정합 · 밤 루프 end-to-end · 바나 세이브) ──")

	# ── ㉖ 배치 정합: 밤 시각에 네 NPC가 시각·단계에서 파생되어 서로 다른 칸에 충돌 없이 서고,
	#     바나 칸이 좌석 줄(응대 대상)·스폿 줄(막기 대상)과 겹치지 않는다(밤 무대 일관) ──
	var m11: Node = await _new_main()
	m11.onboarding.step = Onboarding.MEET_MIHO          # 통보 지남(옥자 상주·바나 밤 무대가 열림)
	m11.clock.minutes = Cafe.CLOSE_MIN + 60             # 20:00(밤 — 미호 카페 출근·바나 등장)
	m11._refresh_okja_station()
	m11._update_miho_station()
	m11._update_bana_station()
	# 네 NPC의 밤 칸이 모두 서로 다르다(겹쳐 서면 한 칸에서 둘이 겹쳐 그려짐 — 무대 깨짐).
	var night_tiles := [m11.OKJA_CAFE_TILE, m11.MEL_TILE, m11._miho_tile, m11.BANA_NIGHT_TILE]
	var uniq := {}
	for t in night_tiles:
		uniq[t] = true
	_check("㉖ 밤 시각 네 NPC(옥자·멜·미호·바나) 칸이 모두 다름(충돌 0)", uniq.size() == 4)
	# 밤엔 미호가 카페 출근 자리에 있고(밭 아님) 바나가 밤 무대에 보인다(시각 파생 일관).
	_check("㉖b 밤엔 미호가 카페 자리·바나 보임", m11._miho_tile == m11.MIHO_CAFE_TILE and m11.bana.visible)
	# 위치도 칸에서 파생된다(세이브 무상태 — 시각·단계가 자리를 정한다).
	_check("㉖c 옥자·멜·미호·바나 위치가 각 칸 중앙에서 파생",
		m11.okja.position == m11._tile_center_px(m11.OKJA_CAFE_TILE)
		and m11.mel.position == m11._tile_center_px(m11.MEL_TILE)
		and m11.miho.position == m11._tile_center_px(m11.MIHO_CAFE_TILE)
		and m11.bana.position == m11._tile_center_px(m11.BANA_NIGHT_TILE))
	# 바나 칸이 좌석 줄·스폿 줄과 겹치지 않는다(NPC가 응대·막기 대상 칸을 깔고 앉지 않게).
	_check("㉖d 바나 칸은 좌석 줄·스폿 줄과 안 겹침",
		not m11.SEAT_TILES.has(m11.BANA_NIGHT_TILE) and not m11.NIGHT_SPOT_TILES.has(m11.BANA_NIGHT_TILE))
	# 좌석 줄(응대)과 스폿 줄(막기)이 분리된다 — 막기↔응대 경쟁의 공간적 뿌리(ADR-0010 #4).
	var rows_disjoint := true
	for s in m11.SEAT_TILES:
		if m11.NIGHT_SPOT_TILES.has(s):
			rows_disjoint = false
	_check("㉖e 좌석 줄(응대)과 스폿 줄(막기)이 분리(경쟁의 공간 뿌리)", rows_disjoint)
	m11.free()

	# ── ㉗ 밤 루프 end-to-end: 옵트인→막기→자동차단(㉠)→실제 약탈(㉮)→응대(㉯)→취침 정산(이월 0)이
	#     한 밤 한 흐름으로 끝까지 굴러가고, 바나 호감도가 일 경계·세이브를 넘어 보존된다 ──
	var m12: Node = await _new_main()
	m12.onboarding.step = Onboarding.MEET_MIHO
	m12.clock.day = 1
	m12.clock.minutes = NightBar.OPEN_MIN + 120         # 21:00(밤 창)
	# ♡3: 보호가 깨어 있되 base를 무효화하진 않는 중간값 — raid 2(<base 3)·자동차단 1·인내심 10.
	# 이 한 밤에 자동 차단(돌파 1회)과 실제 약탈(다음 돌파)이 모두 나와 이중 보호·이중 손실을
	# 한 흐름으로 보인다(♡5는 ㉕에서 자동 차단만, ♡0은 ⑱~⑳에서 약탈만 — ♡3이 둘을 잇는다).
	m12.bana_affinity.points = 3 * Affinity.POINTS_PER_HEART  # ♡3(=120)
	await process_frame                                  # main._process가 night_bar seam에 ♡3 보호 주입
	_check("㉗ ♡3 보호가 night_bar에 주입됨(raid 2·자동차단 1·인내심 10)",
		m12.night_bar.raid_amount == 2 and m12.night_bar.auto_block == 1
		and is_equal_approx(m12.night_bar.patience_secs, 10.0))
	# 옵트인 — 여는 순간 auto_block(1)이 이 밤 자동 차단 횟수로 채워진다.
	m12._open_night_bar()
	_check("㉗b 옵트인으로 바가 열린다", m12.night_bar.is_opened())
	m12.inventory.add_harvest(CropCatalog.HONRYEONGCHO, 10)
	var inv_full: int = m12.inventory.total_harvest()
	# (A) 막기 성공: 잡귀를 깃들이고 _try_block → 즉시 격퇴(재고 불변).
	m12.night_bar.tick(NightBar.SPAWN_INTERVAL + 0.1, m12.clock.minutes)
	_check("㉗c 막기 전 잡귀 존재", m12.night_bar.is_threat(0))
	m12._try_block(0)
	_check("㉗d _try_block → 격퇴(스폿 비움·재고 불변)",
		not m12.night_bar.is_threat(0) and m12.inventory.total_harvest() == inv_full)
	# (B) 자동 차단(이중 보호 ㉠): 새 잡귀를 돌파시키면 바나가 1마리를 대신 막아 재고 0 손실.
	m12.night_bar.tick(NightBar.SPAWN_INTERVAL + 0.1, m12.clock.minutes)   # 잡귀 재등장
	m12.night_bar.tick(NightBar.DEFAULT_APPROACH + 0.1, m12.clock.minutes)  # 안 막아 돌파 → 자동 차단
	_check("㉗e 첫 돌파는 바나 자동 차단(재고 보존·약탈 0)",
		m12.night_bar.tonight_auto_blocked() == 1 and m12.night_bar.tonight_raided() == 0
		and m12.inventory.total_harvest() == inv_full)
	# (C) 실제 약탈(이중 손실 ㉮): 자동 차단 소진 후 다음 돌파는 재고를 약탈한다(미래 자산↓).
	# 직전 tick의 돌파가 곧바로 새 잡귀를 재스폰했으므로(spawn_timer), 추가 스폰 없이 한 번
	# 더 접근시키면 그 잡귀가 돌파한다(자동 차단은 소진됐으니 이번엔 실제 약탈).
	m12.night_bar.tick(NightBar.DEFAULT_APPROACH + 0.1, m12.clock.minutes)  # 안 막아 돌파 → 약탈
	_check("㉗f 자동 차단 소진 후 돌파는 재고 약탈(raid 2)",
		m12.night_bar.tonight_raided() == 2 and m12.inventory.total_harvest() == inv_full - 2)
	# (D) 응대 매출(이중 손실 ㉯의 반대편 — 현재 자산): 바 손님을 응대해 밤 매출을 번다(재료 무소모).
	var serve_seat := -1
	for i in NightBar.N_SEATS:
		if m12.night_bar.is_waiting(i):
			serve_seat = i
			break
	_check("㉗g 응대할 바 손님이 있다", serve_seat >= 0)
	var gold0: int = m12.wallet.gold
	var inv_after_raid: int = m12.inventory.total_harvest()
	m12._try_night_serve(serve_seat)
	_check("㉗h 응대 → 밤 매출이 지갑에 들어옴(재료 무소모)",
		m12.wallet.gold == gold0 + NightBar.SERVE_PRICE
		and m12.night_bar.tonight_revenue() == NightBar.SERVE_PRICE
		and m12.inventory.total_harvest() == inv_after_raid)
	# (E) 취침 정산: 하루가 넘어가면 밤이 정산되고 옵트인이 꺼져 손실이 다음 밤으로 이월되지 않는다.
	m12._on_day_advanced(2)  # 슬라이스 안(끝 아님)
	_check("㉗i 취침 후 옵트인 리셋·잡귀 0(손실 이월 0)",
		not m12.night_bar.is_opened() and m12.night_bar.threat_count() == 0
		and m12.night_bar.tonight_raided() == 0)
	# (F) 바나 호감도는 밤 활동·일 경계를 넘어 보존된다(밤 루프는 호감도를 건드리지 않음).
	_check("㉗j 바나 호감도가 일 경계를 넘어 ♡3 보존", m12.bana_affinity.hearts() == 3)
	# (G) 바나 세이브 라운드트립 + 배치 재현: 저장·복원 후 ♡3이 살고, 밤이면 바나가 다시 선다.
	m12.clock.minutes = NightBar.OPEN_MIN + 120  # 밤 시각으로 저장(복원 시 밤 무대 재현 확인)
	m12._save_game()
	m12.free()
	var m13: Node = await _new_main()  # _ready가 자동 복원 후 _update_bana_station
	_check("㉗k 복원 후 바나 ♡3 유지", m13.bana_affinity.points == 3 * Affinity.POINTS_PER_HEART and m13.bana_affinity.hearts() == 3)
	_check("㉗l 밤 시각 복원 시 바나가 밤 무대에 재등장(세이브+배치 정합)", m13.bana.visible)
	m13.free()

	# 테스트 잔여 세이브 정리(다른 실행·플레이에 새지 않게).
	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
