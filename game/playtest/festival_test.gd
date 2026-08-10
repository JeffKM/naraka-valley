extends SceneTree
# ★[S7-T6 / ADR-0065 결정 8] 카페 이벤트 데이(테마 데이) 검증 — **절기 달력판**(ephemeral 헤드리스).
# 절기 25일마다 카페가 한 테마로 맞춰져 메인 4인 의상이 바뀌고 장식·붐빔·프리미엄이 얹히는지,
# 그리고 그 발동이 **카페 일구기 해금 사다리**에 정확히 걸려 있는지 본다.
#
# ★ 옛 판(2주 주기 CYCLE=14)에서 갈아탄 자리: 트리거 단언(①)과 발동 조건(②)만 교체됐고, 효과
#   3종(붐빔·의상·장식) 단언은 그대로 보존된다 — 축제가 *언제* 열리는가만 바뀌었지 열렸을 때
#   무엇이 일어나는가는 계승됐기 때문이다.
#
# ★ 핵심 불변식:
#   ① 달력(Festival) — 각 절기 **25일**이 테마 슬롯(피안=메이드·유화=바캉스·망연=힙합·성야=
#      크리스마스). 24·26일은 평일. 세이브 무상태 static 규칙(day에서 파생).
#   ② 해금 사다리 — 메이드=카페 1단·바캉스=2단·힙합=누적 매출 5,000·크리스마스=12,000.
#      **비해금 테마의 25일은 평일**(발동 자체가 안 됨). 해금 입력은 main이 주입(무상태 유지).
#   ③ 의상(set_festive) — 4인이 멱등 토글: festive on=TINT 틴트, off=WHITE 원복.
#   ④ main 통합 — _refresh_festival이 day+진척에서 4인 의상·cafe.spawn_scale을 한 번에 맞춘다.
#   ⑤ 프리미엄 — 그날 서빙 ×1.25 · 체키는 그 위에 ×1.5(=평일 대비 1.875) · 밤 바까지 물든다.
#      단, 프리미엄은 margin(멜 관계 축)을 *바꾸지 않는* 별도 인자다(두 축 분리).
#   ⑥ 강제 평온 — 테마 슬롯 당일은 날씨 분포를 무시하고 평온(Weather가 Festival에 위임).
#      ★ 해금과 무관하게 **슬롯 기준**이라 비해금 25일도 맑다(무해한 잉여 — 부작용 0 확인).
#   ⑦ 예고 — D-1(24일) "내일은 …" · 당일(25일) "오늘은 …". 비해금 테마는 예고도 안 한다.
#   ⑧ 세이브 무상태 — festival 키 없이 day+누적값만 복원되면 축제가 그대로 재개된다.
#   ⑨ 카페 테마 장식 _draw — 테마 데이 나루 마을에서 _draw가 크래시 없이 돈다.
# 실행: godot --headless --path game --script res://playtest/festival_test.gd

var _fail := 0

# 절기 s(0~3)의 테마 데이 = s*28 + 25. D-1은 그 전날.
func _theme_day(season: int) -> int:
	return season * GameClock.DAYS_PER_SEASON + Festival.DAY_OF_SEASON

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000   # 안전 상한(좀비 방지)
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 4인 모두 festive가 기대값인지(의상 동기화 단언 헬퍼).
func _all_festive(m: Node, want: bool) -> bool:
	return m.miho.festive == want and m.mel.festive == want and m.bana.festive == want and m.okja.festive == want

# 카페 진척을 원하는 자리에 꽂는다(해금 입력 주입 — 하트는 미호+멜 합이라 포인트를 밀어 올린다).
func _set_progress(m: Node, harvested: int, revenue: int) -> void:
	m._run_harvested = harvested
	m._cafe_revenue_total = revenue
	m.affinity.points = 99999
	m.mel_affinity.points = 99999

func _initialize() -> void:
	print("══ S7-T6 카페 이벤트 데이(테마 데이 · 절기 달력) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s7_t6_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	# 첫 인스턴스가 옛/오염 세이브로 부팅되지 않게 spawn 전에 지운다(interior_test 격리 교훈).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var d_maid := _theme_day(0)      # 피안절 25일 = 25
	var d_vac := _theme_day(1)       # 유화절 25일 = 53
	var d_hip := _theme_day(2)       # 망연절 25일 = 81
	var d_xmas := _theme_day(3)      # 성야절 25일 = 109

	# ── ① 달력(절기 25일 슬롯) — 순수 단위(인스턴스 불필요) ──
	print("── ① 달력(절기 25일) ──")
	_check("①a 테마 슬롯 = 절기 25일", Festival.DAY_OF_SEASON == 25)
	_check("①b 피안 25=메이드 · 유화 25=바캉스", Festival.theme_slot_for_day(d_maid) == Festival.MAID
		and Festival.theme_slot_for_day(d_vac) == Festival.VACANCE)
	_check("①c 망연 25=힙합 · 성야 25=크리스마스", Festival.theme_slot_for_day(d_hip) == Festival.HIPHOP
		and Festival.theme_slot_for_day(d_xmas) == Festival.XMAS)
	_check("①d 24·26일 = 평일(슬롯 아님)", Festival.theme_slot_for_day(d_maid - 1) == Festival.NONE
		and Festival.theme_slot_for_day(d_maid + 1) == Festival.NONE)
	_check("①e 2년차도 같은 자리(day+112)", Festival.theme_slot_for_day(d_maid + 4 * GameClock.DAYS_PER_SEASON) == Festival.MAID)
	_check("①f day 0·음수 = 평일(손상 방어)", Festival.theme_slot_for_day(0) == Festival.NONE
		and Festival.theme_slot_for_day(-25) == Festival.NONE)
	_check("①g 옛 2주 주기 폐기(day 14·28은 슬롯 아님)",
		Festival.theme_slot_for_day(14) == Festival.NONE and Festival.theme_slot_for_day(28) == Festival.NONE)
	_check("①h 표시명 4종", Festival.name_of(Festival.MAID) == "메이드 데이"
		and Festival.name_of(Festival.XMAS) == "크리스마스 데이" and Festival.name_of(Festival.NONE) == "")

	# ── ② 해금 사다리(진척 주입 — 세이브 무상태 유지) ──
	print("── ② 해금 사다리 ──")
	_check("②a 문턱 = 1단·2단·매출 5,000·12,000",
		int(Festival.UNLOCK_STAGE[Festival.MAID]) == CafeMilestone.STAGE_1
		and int(Festival.UNLOCK_STAGE[Festival.VACANCE]) == CafeMilestone.STAGE_2
		and int(Festival.UNLOCK_REVENUE[Festival.HIPHOP]) == 5000
		and int(Festival.UNLOCK_REVENUE[Festival.XMAS]) == 12000)
	_check("②b 1단 전(0단) = 메이드도 안 열린다 → 25일이 평일",
		not Festival.is_event_day(d_maid, CafeMilestone.STAGE_NONE, 0))
	_check("②c 1단 도달 = 메이드 개최", Festival.theme_for_day(d_maid, CafeMilestone.STAGE_1, 400) == Festival.MAID)
	_check("②d 1단으로는 바캉스 못 연다(2단 필요)",
		not Festival.is_event_day(d_vac, CafeMilestone.STAGE_1, 400))
	_check("②e 2단 도달 = 바캉스 개최", Festival.theme_for_day(d_vac, CafeMilestone.STAGE_2, 1800) == Festival.VACANCE)
	_check("②f 힙합 = 매출 눈금(4,999 잠김 / 5,000 열림)",
		not Festival.is_event_day(d_hip, CafeMilestone.STAGE_2, 4999)
		and Festival.theme_for_day(d_hip, CafeMilestone.STAGE_2, 5000) == Festival.HIPHOP)
	_check("②g 크리스마스 = 매출 12,000 눈금(11,999 잠김)",
		not Festival.is_event_day(d_xmas, CafeMilestone.STAGE_2, 11999)
		and Festival.theme_for_day(d_xmas, CafeMilestone.STAGE_2, 12000) == Festival.XMAS)
	_check("②h 해금돼도 25일이 아니면 평일(달력 ∧ 해금)",
		not Festival.is_event_day(d_maid + 1, CafeMilestone.STAGE_2, 99999))

	# ── ③ 효과 상수(옛 판에서 계승 + 신규 프리미엄) ──
	print("── ③ 효과 상수 ──")
	_check("③a 테마 데이 spawn_scale 0.5(2배 붐빔)", is_equal_approx(Festival.spawn_scale_of(Festival.MAID), 0.5))
	_check("③b 평일 spawn_scale 1.0(base rate, 평평≠막힘)", is_equal_approx(Festival.spawn_scale_of(Festival.NONE), 1.0))
	_check("③c 서빙 프리미엄 1.25 / 평일 1.0", is_equal_approx(Festival.serve_premium_of(Festival.MAID), 1.25)
		and is_equal_approx(Festival.serve_premium_of(Festival.NONE), 1.0))
	_check("③d 체키 프리미엄 1.5 / 평일 1.0", is_equal_approx(Festival.cheki_premium_of(Festival.XMAS), 1.5)
		and is_equal_approx(Festival.cheki_premium_of(Festival.NONE), 1.0))
	_check("③e TINT ≠ WHITE(의상 틴트 존재)", Festival.TINT != Color.WHITE)

	# ── ④ 의상(set_festive) — 4인 멱등 토글(옛 판 계승) ──
	print("── ④ 의상 토글 ──")
	for maker in [Miho, Mel, Bana, Okja]:
		var c = maker.new()
		var nm: String = c.display_name()
		c._ready()   # _sprite 폴백 셋업(도색 있으면 스프라이트, 없으면 그레이박스 — 토글은 무관)
		var ok_init: bool = (c.festive == false and c.modulate == Color.WHITE)
		c.set_festive(true)
		var ok_on: bool = (c.festive == true and c.modulate == Festival.TINT)
		c.set_festive(true)   # 멱등 — 같은 값 재호출 무해
		var ok_idem: bool = (c.festive == true and c.modulate == Festival.TINT)
		c.set_festive(false)
		var ok_off: bool = (c.festive == false and c.modulate == Color.WHITE)
		_check("④ %s: 초기WHITE→on TINT→멱등→off WHITE" % nm, ok_init and ok_on and ok_idem and ok_off)
		c.free()

	# ── ⑤ 강제 평온(Weather 위임) — 슬롯 기준이라 해금 무관 ──
	print("── ⑤ 당일 강제 평온 ──")
	_check("⑤a Weather._is_theme_day가 Festival 슬롯에 위임",
		Weather._is_theme_day(d_maid) and Weather._is_theme_day(d_vac) and not Weather._is_theme_day(d_maid + 1))
	var calm_all := true
	for d in [d_maid, d_vac, d_hip, d_xmas]:
		if Weather.weather_for_day(d) != Weather.CALM:
			calm_all = false
	_check("⑤b 테마 슬롯 4일 전부 평온(분포 오버라이드)", calm_all)
	_check("⑤c 비해금이어도 그날은 평온 — 무해한 잉여(부작용 0)",
		Weather.weather_for_day(d_xmas) == Weather.CALM
		and not Festival.is_event_day(d_xmas, CafeMilestone.STAGE_NONE, 0))

	var m: Node = await _spawn_main()

	# ── ⑥ main 통합 — day + 진척에서 의상·붐빔·프리미엄이 한 번에 선다 ──
	print("── ⑥ main 통합(달력 × 해금) ──")
	m.clock.day = d_maid
	_set_progress(m, 0, 0)                    # 아직 0단
	m._refresh_festival()
	_check("⑥a 0단 + 25일 → 평일(의상 평상복)", _all_festive(m, false)
		and m._festival_theme() == Festival.NONE)
	_check("⑥b 0단 25일 → spawn_scale에 축제 배수 없음", is_equal_approx(m.cafe.spawn_scale,
		CafeMilestone.spawn_scale_of(m._cafe_stage())))
	_set_progress(m, CafeMilestone.TARGET_HARVEST, CafeMilestone.TARGET_REVENUE)   # 1단
	m._refresh_festival()
	_check("⑥c 1단 도달", m._cafe_stage() == CafeMilestone.STAGE_1)
	_check("⑥d 1단 + 피안 25일 → 메이드 데이(4인 축제 의상)", _all_festive(m, true)
		and m._festival_theme() == Festival.MAID)
	_check("⑥e 메이드 데이 → cafe.spawn_scale에 0.5가 곱해진다", is_equal_approx(m.cafe.spawn_scale,
		0.5 * CafeMilestone.spawn_scale_of(m._cafe_stage())))
	m.clock.day = d_maid + 1
	m._refresh_festival()
	_check("⑥f 26일 → 평상복 · 축제 배수 없음", _all_festive(m, false)
		and is_equal_approx(m.cafe.spawn_scale,
			CafeMilestone.spawn_scale_of(m._cafe_stage()) * Weather.cafe_spawn_scale(m._weather_today())))
	m.clock.day = d_vac
	m._refresh_festival()
	_check("⑥g 1단으로 유화 25일 → 잠겨서 평일(비해금 = 발동 0)", _all_festive(m, false))
	_set_progress(m, CafeMilestone.S2_TARGET_HARVEST, CafeMilestone.S2_TARGET_REVENUE)   # 2단
	m._refresh_festival()
	_check("⑥h 2단 도달 → 바캉스 데이 개막", m._cafe_stage() == CafeMilestone.STAGE_2
		and m._festival_theme() == Festival.VACANCE and _all_festive(m, true))
	m.clock.day = d_hip
	_set_progress(m, CafeMilestone.S2_TARGET_HARVEST, 5000)
	m._refresh_festival()
	_check("⑥i 매출 5,000 → 힙합 데이", m._festival_theme() == Festival.HIPHOP and _all_festive(m, true))
	m.clock.day = d_xmas
	m._refresh_festival()
	_check("⑥j 매출 5,000으론 크리스마스 잠김(12,000 필요)", m._festival_theme() == Festival.NONE
		and _all_festive(m, false))
	_set_progress(m, CafeMilestone.S2_TARGET_HARVEST, 12000)
	m._refresh_festival()
	_check("⑥k 매출 12,000 → 크리스마스 데이", m._festival_theme() == Festival.XMAS and _all_festive(m, true))

	# ── ⑦ 프리미엄 배선(서빙 ×1.25 · 체키 ×1.5 · 밤 바) ──
	print("── ⑦ 테마 프리미엄 ──")
	m.clock.day = d_maid
	_set_progress(m, CafeMilestone.TARGET_HARVEST, CafeMilestone.TARGET_REVENUE)
	m._refresh_festival()
	m.cafe.margin = 1.0                        # 멜 마진 축을 중립으로 고정(프리미엄만 보게)
	var price_fest: int = m.cafe.serve_price()
	var cheki_fest: int = m.cafe.cheki_price("", ChekiSession.Grade.GOOD)
	var night_fest: int = m.night_bar.serve_price()
	_check("⑦a 테마 프리미엄 주입(cafe 1.25 · 체키 1.5 · 밤 바 1.25)",
		is_equal_approx(m.cafe.theme_premium, Festival.SERVE_PREMIUM)
		and is_equal_approx(m.cafe.cheki_premium, Festival.CHEKI_PREMIUM)
		and is_equal_approx(m.night_bar.theme_premium, Festival.SERVE_PREMIUM))
	_check("⑦b 서빙가 = 정액 × 1.25", price_fest == int(round(Cafe.BASE_PRICE * 1.25)))
	_check("⑦c 밤 응대가 = 정액 × 1.25", night_fest == int(round(NightBar.SERVE_PRICE * 1.25)))
	m.clock.day = d_maid + 1                   # 같은 조건에서 날짜만 평일로
	m._refresh_festival()
	m.cafe.margin = 1.0
	var price_plain: int = m.cafe.serve_price()
	var cheki_plain: int = m.cafe.cheki_price("", ChekiSession.Grade.GOOD)
	_check("⑦d 평일엔 프리미엄 0(배수 1.0 원복)", is_equal_approx(m.cafe.theme_premium, 1.0)
		and is_equal_approx(m.cafe.cheki_premium, 1.0)
		and is_equal_approx(m.night_bar.theme_premium, 1.0))
	_check("⑦e 서빙 프리미엄 = ×1.25(평일 대비)", price_fest == int(round(price_plain * 1.25)))
	# 기대값은 실제 산식과 같은 순서로 접는다(round 두 번을 임의로 재배열하면 1냥이 어긋난다).
	_check("⑦f 체키 = 서빙 프리미엄 위에 +50%(평일 대비 ×1.875)",
		cheki_fest == int(round(price_fest * float(Cafe.CHEKI_RATE[ChekiSession.Grade.GOOD]) * 1.5))
		and cheki_plain == int(round(price_plain * float(Cafe.CHEKI_RATE[ChekiSession.Grade.GOOD])))
		and cheki_fest > cheki_plain)
	# ★ 관계 축 분리 — 프리미엄은 margin을 *바꾸지 않는다*(달력 축 ↔ 관계 축).
	m.clock.day = d_maid
	m._refresh_festival()
	m.cafe.margin = 2.0
	_check("⑦g margin은 프리미엄과 별개로 곱해진다(두 축 분리)",
		m.cafe.serve_price() == int(round(Cafe.BASE_PRICE * 2.0 * 1.25)))
	m.cafe.margin = 1.0

	# ── ⑧ 예고·개막 배너(D-1 · 당일) ──
	print("── ⑧ 예고 배너 ──")
	m.clock.day = d_maid
	m._refresh_festival()
	var b_today: Array = m._festival_morning_notices()
	_check("⑧a 당일 아침 = 개막 배너 1줄", b_today.size() == 1 and String(b_today[0]).begins_with("오늘은")
		and String(b_today[0]).contains("메이드 데이"))
	m.clock.day = d_maid - 1
	m._refresh_festival()
	var b_prev: Array = m._festival_morning_notices()
	_check("⑧b D-1(24일) = 예고 배너 1줄", b_prev.size() == 1 and String(b_prev[0]).begins_with("내일은")
		and String(b_prev[0]).contains("메이드 데이"))
	m.clock.day = d_maid - 2
	m._refresh_festival()
	_check("⑧c D-2는 조용(배너 0줄)", m._festival_morning_notices().is_empty())
	m.clock.day = d_vac - 1
	m._refresh_festival()
	_check("⑧d 비해금 테마는 예고도 안 한다(못 여는 잔치 광고 0)",
		m._festival_morning_notices().is_empty())
	m.clock.day = d_maid - 3
	m._refresh_festival()
	_check("⑧e 점괘 거울 = 다가오는 테마 데이 한 줄", m._festival_upcoming_line() == "3일 뒤: 메이드 데이"
		and m._mirror_forecast_text().contains("메이드 데이"))

	# ── ⑨ 세이브 무상태 — day + 누적값만 복원되면 축제가 그대로 재개 ──
	print("── ⑨ 세이브 무상태(재개) ──")
	m.clock.day = d_maid
	_set_progress(m, CafeMilestone.TARGET_HARVEST, CafeMilestone.TARGET_REVENUE)
	m._refresh_festival()
	m._save_game()
	var saved: Dictionary = m.saver.load_game()
	_check("⑨a 세이브에 festive/festival 키 없음(무상태)", not saved.has("festive") and not saved.has("festival"))
	m.queue_free()
	await process_frame
	await process_frame
	var m2: Node = await _spawn_main()
	_check("⑨b 재개 day=%d(복원)" % d_maid, m2.clock.day == d_maid)
	_check("⑨c 재개하면 메이드 데이 그대로(달력 × 누적값 파생)", _all_festive(m2, true)
		and m2._festival_theme() == Festival.MAID)
	_check("⑨d 재개하면 프리미엄·붐빔도 그대로", is_equal_approx(m2.cafe.theme_premium, Festival.SERVE_PREMIUM)
		and is_equal_approx(m2.cafe.spawn_scale,
			0.5 * CafeMilestone.spawn_scale_of(m2._cafe_stage())))

	# ── ⑩ 카페 테마 장식 _draw — 테마 데이 나루 마을에서 크래시 없이 돈다 ──
	print("── ⑩ 카페 테마 장식 _draw ──")
	m2.player.position = m2._tile_center_px(Vector2i(78, 32))   # ★C2 동쪽 길 워프 → 마을
	m2._maybe_warp_edge()
	await _settle(m2)
	_check("⑩pre 나루 마을로 워프", m2._region == RegionCatalog.NARU_VILLAGE)
	m2.clock.day = d_maid
	m2._refresh_festival()
	m2.queue_redraw()
	await process_frame
	await process_frame
	# 여기까지 예외 없이 도달하면 _draw_cafe_festival(좌표·draw_colored_polygon)이 안전히 돌았다.
	_check("⑩ 테마 데이 카페 _draw 크래시 없음(가랜드·카펫 좌표 안전)", true)
	m2.queue_free()
	await process_frame

	# ── 정리: 세이브 원복 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)
