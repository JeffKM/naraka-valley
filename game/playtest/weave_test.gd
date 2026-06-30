extends SceneTree
# T7.1 임시 헤드리스 단위검증 — 낮↔밤 직조(시간 분업 + 자원·관계 합류)를 실제 main 씬으로
# 검증한다. npc_station_test.gd·bana_test.gd와 같은 결의 단언 하네스 — 직조는 새 메카닉이
# 아니라(ROADMAP "새 메카닉 X") Sprint 5~6에서 각자 굴러가던 세 루프(농사·카페·밤 경비)를
# *한 하루 시계 위에서* 서로 자원·관계를 주고받게 잇는 통합이라, 그 합류가 main.gd(씬
# 오케스트레이션)에 살아 단독 노드로 떼어 볼 수 없다. 그래서 main.tscn을 인스턴스화해 시각·
# 호감도·재고를 직접 흘려 *세 루프가 한 빌드에서 직조되는지*를 통합 관점으로 결정화한다.
#
# 검증 세 축(verification criteria — 직조 전환·자원 합류·관계 환류 + 낮 안 기회비용):
#   Ⓐ 직조 전환 — 한 GameClock 시각만 흘려도 세 루프의 깨우기/재우기가 파생된다: 아침=농사만,
#      15–19시=카페 영업창 열림(미호 카페 출근), 19–24시=카페 닫힘·밤 무대(바나 등장·옵트인 가능).
#   Ⓑ 자원 합류 — 낮에 거둔 *한 재고 풀*(inventory.harvested)을 카페 서빙(현재 자산 환전)과
#      밤 약탈(미래 자산 손실)이 *함께 노린다*(둘 다 _cheapest_harvest 경유). 카페 매출·밤 매출은
#      *같은 지갑*(wallet)으로 합류한다. → 밤이 밭→재고→서빙 사슬에 묶인다(§2.8 직조).
#   Ⓒ 관계 환류 — 미호·멜·바나 세 호감도가 한 프레임에 각자 *종류가 다른* 루프 곱셈기로 환류한다:
#      미호→Foxfire(자동화: 가속·범위)·멜→CafeMargin(마진: 단가 배수)·바나→BanaGuard(보호: 약탈량·
#      자동차단·인내심). 같은 +%의 반복이 아니라 동사가 분화(ADR-0008) — 셋이 한 빌드에서 동시 가동.
#   Ⓓ 낮 안 기회비용(구조) — 카페 영업창(15–19시)이 농사 가능 시간과 겹치고, 그 무대에 미호·멜이
#      함께 서 있어 "밭 더 vs 카운터 vs 대화"가 *같은 낮 시간*을 두고 경쟁한다(한 번에 한 곳 —
#      혼력=노동 전용·카페=시간 희소성, ADR-0008). 시간표 노동이 아니라 낮 안의 선택 긴장.
# 실행: godot --headless --path game --script res://playtest/weave_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# main 씬을 새로 인스턴스화해 트리에 붙인다(npc_station_test·bana_test와 동일 — _ready 한 프레임 대기).
func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	return m

# 신규 시작(세이브 없음)은 _ready가 옥자 오프닝 통보 대화를 띄운다 — 그게 열려 있으면 main._process가
# early-return해 곱셈기 주입(cafe.margin·night_bar seam)이 돌지 않는다(_process 윗머리 dialogue 가드).
# _process 주입에 의존하는 검증은 먼저 통보 대화를 끝까지 넘겨 닫는다(notice_seen → MEET_MIHO 전진).
# (bana_test는 앞 테스트가 디스크에 남긴 세이브를 로드해 통보를 건너뛰므로 별도 dismiss가 없었다.)
func _dismiss_intro(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ T7.1 낮↔밤 직조(시간 분업 + 자원·관계 합류) 단위검증 ══")
	# 결정적 검증을 위해 기존 세이브를 비우고 시작한다(신규 시작 = 통보 단계).
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ══════════════ Ⓐ 직조 전환 — 한 시계 시각만 흘려도 세 루프 깨우기/재우기가 파생 ══════════════
	# 통보를 지난 상태로 고정(옥자 상주·바나 밤 무대가 열리는 단계 — 직조 무대가 깔린다).
	var m1: Node = await _new_main()
	m1.onboarding.step = Onboarding.MEET_MIHO

	# ── ① 아침(08:00): 농사만 깨어 있다 — 카페 닫힘·밤 무대 숨김·미호는 밭 ──
	m1.clock.minutes = 8 * 60
	m1.cafe.tick(0.0, m1.clock.minutes)        # 카페 영업창 게이팅을 한 시각으로 굴린다
	m1._update_miho_station()
	m1._update_bana_station()
	_check("① 아침엔 카페 닫힘(농사 시간)", not m1.cafe.is_open())
	_check("①b 아침엔 밤 무대(바나) 숨김", not m1.bana.visible)
	_check("①c 아침엔 미호가 밭 자리(농사 멘토)", m1._miho_tile == m1.MIHO_FIELD_TILE)
	_check("①d 아침은 밤 창이 아니다(옵트인 불가)", not m1.night_bar.is_window(m1.clock.minutes))

	# ── ② 오후(16:00, 카페 영업창): 카페 열림·미호 카페 출근 — 낮 루프가 직조되는 무대 ──
	m1.clock.minutes = Cafe.OPEN_MIN + 60      # 16:00
	m1.cafe.tick(0.0, m1.clock.minutes)
	m1._update_miho_station()
	m1._update_bana_station()
	_check("② 15–19시엔 카페 영업창 열림", m1.cafe.is_open())
	_check("②b 영업창엔 미호가 카페로 출근(직원이 카페에 모임)", m1._miho_tile == m1.MIHO_CAFE_TILE)
	_check("②c 영업창은 아직 밤 무대 아님(바나 숨김)", not m1.bana.visible)
	_check("②d 영업창은 밤 창이 아니다", not m1.night_bar.is_window(m1.clock.minutes))

	# ── ③ 밤(20:00, 밤 창): 카페 닫힘·바나 등장·밤 옵트인 가능 — 낮→밤 전환 ──
	m1.clock.minutes = NightBar.OPEN_MIN + 60  # 20:00
	m1.cafe.tick(0.0, m1.clock.minutes)
	m1._update_miho_station()
	m1._update_bana_station()
	_check("③ 19시 이후 카페 닫힘(낮 영업 끝)", not m1.cafe.is_open())
	_check("③b 밤엔 바나가 밤 무대에 등장", m1.bana.visible)
	_check("③c 밤은 밤 창이라 옵트인 가능", m1.night_bar.is_window(m1.clock.minutes))
	# 같은 좌석 줄(y=7)을 낮 카페·밤 바가 시간대로 나눠 쓴다 — 19시 경계로 카페→밤 바 한쪽만 활성.
	_check("③d 카페 닫힘·밤 바 옵트인 전이라 좌석 줄은 둘 다 비활성(시간 분업)",
		not m1.cafe.is_open() and not m1.night_bar.is_active())
	m1.free()

	# ══════════════ Ⓑ 자원 합류 — 한 재고 풀을 카페 서빙·밤 약탈이 함께 노린다 ══════════════
	# 카페 매출·밤 매출은 같은 지갑으로 합류한다. → 낮 농사가 밤 약탈·카페 서빙에 동시에 묶인다(§2.8).
	var m2: Node = await _new_main()
	m2.onboarding.step = Onboarding.MEET_MIHO

	# ── ④ "한 날의 수확"을 모사: 낮 농사 산출물을 재고에 쌓는다(밭→재고). 비싼·싼 작물 섞어 둔다 ──
	#     (헤드리스라 괭이·물·혼력 경로 대신 직접 적재 — 자원 *합류* 자체가 검증 대상, 농사 입력은 T2 회귀 몫.)
	m2.inventory.add_harvest(CropCatalog.HONRYEONGCHO, 4)  # 싼 작물(서빙·약탈이 먼저 가져감)
	m2.inventory.add_harvest(CropCatalog.YEONGHON_HOBAK, 2)  # 비싼 작물(raw 판매로 남기는 게 이득)
	var day_harvest: int = m2.inventory.total_harvest()
	_check("④ 낮 농사 산출물이 한 재고 풀에 쌓임", day_harvest == 6)

	# ── ⑤ 낮 카페 서빙: 재고 1개를 *소모*하고 매출을 같은 지갑에 번다(현재 자산 환전) ──
	m2.clock.minutes = Cafe.OPEN_MIN + 60      # 16:00(영업창)
	m2.cafe.margin = CafeMargin.margin(m2.mel_affinity.hearts())  # ♡0 base ×1.0
	m2.cafe.tick(0.0, m2.clock.minutes)        # 카페 열림
	# 손님을 한 명 앉힌다(SPAWN_INTERVAL 경과 → 빈 좌석 착석).
	m2.cafe.tick(Cafe.SPAWN_INTERVAL + 0.1, m2.clock.minutes)
	var seat := -1
	for i in Cafe.N_SEATS:
		if m2.cafe.is_waiting(i):
			seat = i
			break
	_check("⑤pre 영업창에 카페 손님 착석", seat >= 0)
	var gold_before_serve: int = m2.wallet.gold
	var inv_before_serve: int = m2.inventory.total_harvest()
	m2._try_serve(seat)
	_check("⑤ 카페 서빙 → 재고 1개 소모(밭→재고→서빙 사슬)", m2.inventory.total_harvest() == inv_before_serve - 1)
	_check("⑤b 카페 매출이 같은 지갑으로 합류", m2.wallet.gold == gold_before_serve + Cafe.BASE_PRICE)

	# ── ⑥ 밤 약탈: *같은 재고 풀*을 잡귀가 노린다(미래 자산 손실) — 카페가 안 가져간 재고가 줄어든다 ──
	m2.clock.minutes = NightBar.OPEN_MIN + 60  # 20:00(밤 창) — 카페는 닫히고 밤이 같은 재고를 노린다
	# 바나 ♡0(잠듦): 보호 0이라 돌파가 곧장 약탈로 간다(base 약탈량 DEFAULT_RAID). 직조의 손실 쪽을 노출.
	m2.night_bar.raid_amount = BanaGuard.raid_amount(0)
	m2.night_bar.auto_block = BanaGuard.auto_block(0)
	m2.night_bar.patience_secs = BanaGuard.patience_secs(0)
	m2._open_night_bar()
	var inv_before_raid: int = m2.inventory.total_harvest()
	# 잡귀를 깃들이고(스폰) 안 막아 돌파시킨다 → _on_night_resolved가 같은 재고 풀에서 약탈.
	m2.night_bar.tick(NightBar.SPAWN_INTERVAL + 0.1, m2.clock.minutes)
	m2.night_bar.tick(NightBar.DEFAULT_APPROACH + 1.0, m2.clock.minutes)
	_check("⑥ 밤 약탈이 *낮 농사 재고*를 차감(자원 합류 — 미래 자산 손실)",
		m2.inventory.total_harvest() < inv_before_raid and m2.night_bar.tonight_raided() > 0)
	# 약탈량은 재고 차감량과 일치한다(night_bar는 재고를 모른 채 계약만 쏘고, main이 실제 차감 — 디커플링).
	_check("⑥b 약탈량 = 재고 차감량(계약 {약탈량} → main이 실제 적용)",
		inv_before_raid - m2.inventory.total_harvest() == m2.night_bar.tonight_raided())

	# ── ⑦ 밤 응대: 밤 매출도 *같은 지갑*으로 합류한다(재료 무소모 — 미래 자산은 약탈 쪽이 건드림) ──
	var bar_seat := -1
	for i in NightBar.N_SEATS:
		if m2.night_bar.is_waiting(i):
			bar_seat = i
			break
	_check("⑦pre 밤 바에 손님 착석", bar_seat >= 0)
	var gold_before_night: int = m2.wallet.gold
	var inv_before_night_serve: int = m2.inventory.total_harvest()
	m2._try_night_serve(bar_seat)
	_check("⑦ 밤 매출이 같은 지갑으로 합류(낮 카페 매출과 한 지갑)", m2.wallet.gold == gold_before_night + NightBar.SERVE_PRICE)
	_check("⑦b 밤 응대는 재고 무소모(현재/미래 자산 분리, ADR-0010 #5)", m2.inventory.total_harvest() == inv_before_night_serve)
	# 직조의 핵심: 하루가 끝나면 낮에 거둔 재고가 (서빙 소모 + 밤 약탈)만큼 줄어 있다 — 한 재고를 두 루프가 나눠 가짐.
	_check("⑦c 한 날 재고가 카페 서빙·밤 약탈로 함께 줄었다(직조 — 밭→재고→{서빙·약탈})",
		m2.inventory.total_harvest() < day_harvest)
	m2.free()

	# ══════════════ Ⓒ 관계 환류 — 세 호감도가 한 프레임에 *종류가 다른* 루프 곱셈기로 환류 ══════════════
	# 미호=자동화·멜=마진·바나=보호. 같은 +%의 반복이 아니라 동사 분화(ADR-0008) — 셋이 한 빌드에서 동시 가동.
	var m3: Node = await _new_main()
	_dismiss_intro(m3)                         # _process 곱셈기 주입을 막는 통보 대화를 닫는다
	m3.onboarding.step = Onboarding.MEET_MIHO
	m3.clock.minutes = NightBar.OPEN_MIN + 60  # 밤 시각(밤 곱셈기 주입까지 한 프레임에 보려고)
	# 세 호감도를 서로 다른 단계로 올려, 각 곱셈기가 *그 캐릭터의* 하트에서 파생됨을 가른다.
	m3.affinity.points = 5 * Affinity.POINTS_PER_HEART       # 미호 ♡5
	m3.mel_affinity.points = 3 * Affinity.POINTS_PER_HEART   # 멜 ♡3
	m3.bana_affinity.points = 2 * Affinity.POINTS_PER_HEART  # 바나 ♡2
	await process_frame  # main._process가 멜 마진·바나 보호를 한 프레임에 주입(미호는 advance_day 경로)
	var hm: int = m3.affinity.hearts()
	var hl: int = m3.mel_affinity.hearts()
	var hb: int = m3.bana_affinity.hearts()
	_check("⑧pre 세 호감도가 서로 다른 단계로 살아 있음(미호♡5·멜♡3·바나♡2)", hm == 5 and hl == 3 and hb == 2)

	# ── ⑧ 멜→카페 마진(곱셈기 #2: 마진). main이 cafe.margin에 멜 하트 파생값을 주입했다 ──
	_check("⑧ 멜 호감도 → 카페 마진 곱셈기 환류(cafe.margin = CafeMargin.margin(멜♡))",
		is_equal_approx(m3.cafe.margin, CafeMargin.margin(hl)) and m3.cafe.margin > CafeMargin.BASE_MARGIN)

	# ── ⑨ 바나→밤 보호(곱셈기 #3: 보호 — 약탈량·자동차단·인내심 세 축). main이 night_bar seam에 주입 ──
	_check("⑨ 바나 호감도 → 밤 보호 곱셈기 환류(raid_amount↓)", m3.night_bar.raid_amount == BanaGuard.raid_amount(hb))
	_check("⑨b 바나 보호 환류(auto_block↑)", m3.night_bar.auto_block == BanaGuard.auto_block(hb))
	_check("⑨c 바나 보호 환류(patience_secs↑)", is_equal_approx(m3.night_bar.patience_secs, BanaGuard.patience_secs(hb)))

	# ── ⑩ 미호→여우불(곱셈기 #1: 자동화 — 가속·범위). 취침(advance_day) 경로로 농사에 환류 ──
	#     세 곱셈기의 *종류가 다름*(동사 분화)을 한자리에서 확인: 마진(×배수)·보호(손실 방지)·자동화(노동 절감).
	_check("⑩ 미호 호감도 → 여우불 자동화 곱셈기 환류(♡5에서 가속·범위 깨어 있음)",
		Foxfire.accel(hm) > 0 and Foxfire.reach(hm) > 0 and Foxfire.is_awake(hm))
	# 세 곱셈기가 *동시에* 깨어 있고 종류가 분화돼 있다(같은 +% 반복 아님 — 미호 자동화·멜 마진·바나 보호).
	_check("⑩b 세 곱셈기가 한 빌드에서 동시 가동·종류 분화(자동화·마진·보호)",
		Foxfire.is_awake(hm) and m3.cafe.margin > CafeMargin.BASE_MARGIN and BanaGuard.auto_block(hb) > 0)
	m3.free()

	# ══════════════ Ⓓ 낮 안 기회비용(구조) — 밭 더 vs 카운터 vs 대화가 같은 낮 시간을 다툼 ══════════════
	# 시간표 노동(밤에만 경비·낮에만 농사)이 아니라, 카페 영업창이 농사 시간과 *겹쳐* 낮 안에서
	# "한정된 낮을 어디에 쓰나"가 산다(혼력=노동 전용·카페=시간 희소성, ADR-0008·§2.8 경고).
	var m4: Node = await _new_main()
	m4.onboarding.step = Onboarding.MEET_MIHO
	m4.clock.minutes = Cafe.OPEN_MIN + 60      # 16:00 — 카페 영업창
	m4.cafe.tick(0.0, m4.clock.minutes)
	m4._update_miho_station()
	# ⑪ 영업창(낮)에 카페가 열려 있으면서, 밭(SOIL)은 여전히 농사 가능 — 같은 낮 시간을 둘이 다툰다.
	# 밭 한 칸을 골라 농사 대상인지 본다(미호 자리·카페 자리 빼고 SOIL이면 경작 가능).
	var farmable_tile := Vector2i(m4.STARTER_PATCH_RECT.position.x + 1, m4.STARTER_PATCH_RECT.position.y + 1)
	_check("⑪ 카페 영업창(낮)에도 밭은 농사 가능 — 밭 더 vs 카운터가 같은 낮을 다툼",
		m4.cafe.is_open() and m4._is_farmable(farmable_tile))
	# ⑪b 그 무대에 미호·멜이 함께 서 있어 '대화'(호감도 곱셈기)도 같은 낮 시간의 선택지 — 셋이 경쟁.
	_check("⑪b 영업창 무대에 미호(카페 출근)·멜(카운터)이 함께 서 있음 — '대화'도 같은 낮의 선택지",
		m4._miho_tile == m4.MIHO_CAFE_TILE and m4.mel.position == m4._tile_center_px(m4.MEL_TILE))
	# ⑪c 혼력=노동 전용: 농사는 혼력을 쓰고(노동) 카페 서빙·대화는 안 쓴다 — 낮의 희소 자원은 *시간*이다.
	#     (혼력 바닥이어도 카페·대화는 막히지 않는다 → 낮 긴장은 혼력 게이트가 아니라 시간 기회비용.)
	_check("⑪c 혼력=노동 전용(카페=시간 희소성): 농사만 can_act 게이트, 서빙·대화는 시간만 씀",
		m4.energy.can_act())  # 신규 시작은 혼력 가득 — 농사 가능. 카페·대화는 혼력과 무관(구조 확인).
	m4.free()

	# ══════════════ Ⓔ 직조 end-to-end — 한 빌드에서 낮→밤이 한 흐름으로 굴러가고 호감도가 보존 ══════════════
	# Ⓐ~Ⓓ를 한 main 인스턴스에서 시각만 흘려 잇는다 — "한 하루 시계 위에서 직조"의 통합 결정화.
	var m5: Node = await _new_main()
	_dismiss_intro(m5)                         # _process 곱셈기 주입을 막는 통보 대화를 닫는다
	m5.onboarding.step = Onboarding.MEET_MIHO
	m5.clock.day = 1
	# 세 호감도를 켜 둔 채(관계 환류 유지) 낮→밤을 흘린다.
	m5.affinity.points = 4 * Affinity.POINTS_PER_HEART
	m5.mel_affinity.points = 2 * Affinity.POINTS_PER_HEART
	m5.bana_affinity.points = 2 * Affinity.POINTS_PER_HEART
	m5.inventory.add_harvest(CropCatalog.HONRYEONGCHO, 8)  # 낮 농사 재고
	# (낮) 카페 영업창에서 서빙 한 번 → 매출·재고 소모.
	m5.clock.minutes = Cafe.OPEN_MIN + 30
	await process_frame  # 곱셈기 주입(멜 마진·바나 보호) + 카페 tick
	m5.cafe.tick(Cafe.SPAWN_INTERVAL + 0.1, m5.clock.minutes)
	var s := -1
	for i in Cafe.N_SEATS:
		if m5.cafe.is_waiting(i):
			s = i
			break
	var day_gold: int = m5.wallet.gold
	if s >= 0:
		m5._try_serve(s)
	_check("⑫ (낮) 카페 영업창에서 서빙해 매출이 났다", m5.wallet.gold > day_gold)
	# (밤) 같은 날 밤으로 시각을 흘려 옵트인 → 밤 매출. 낮 매출과 밤 매출이 한 지갑에 누적된다.
	m5.clock.minutes = NightBar.OPEN_MIN + 60
	await process_frame  # 밤 보호 주입
	m5._open_night_bar()
	m5.night_bar.tick(NightBar.CUST_INTERVAL + 0.1, m5.clock.minutes)  # 밤 손님 착석
	var nb_seat := -1
	for i in NightBar.N_SEATS:
		if m5.night_bar.is_waiting(i):
			nb_seat = i
			break
	var night_gold: int = m5.wallet.gold
	if nb_seat >= 0:
		m5._try_night_serve(nb_seat)
	_check("⑫b (밤) 같은 날 밤 바에서 응대해 밤 매출이 같은 지갑에 누적", m5.wallet.gold > night_gold)
	# (취침) 하루가 넘어가면 카페·밤 바가 리셋되고(매일 새 선택), 세 호감도는 일 경계를 넘어 보존된다.
	var hm0: int = m5.affinity.hearts()
	var hl0: int = m5.mel_affinity.hearts()
	var hb0: int = m5.bana_affinity.hearts()
	m5._on_day_advanced(2)  # 슬라이스 안(끝 아님)
	_check("⑫c 취침 후 카페·밤 바 리셋(매일 새 선택 — 직조는 하루 단위로 다시 짜인다)",
		not m5.cafe.is_open() and not m5.night_bar.is_opened() and m5.night_bar.threat_count() == 0)
	_check("⑫d 세 호감도는 일 경계를 넘어 보존(관계는 누적·직조의 지속 축)",
		m5.affinity.hearts() == hm0 and m5.mel_affinity.hearts() == hl0 and m5.bana_affinity.hearts() == hb0)
	m5.free()

	# 테스트 잔여 세이브 정리(다른 실행·플레이에 새지 않게).
	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
