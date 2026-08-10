extends SceneTree
# ★[S7-T8 / ADR-0065 결정 10] 달력 패널·HUD 날씨·시각 연출 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① HUD 날씨 인자 — clock_hud.set_state가 **가법 확장**됐다(6인자 옛 호출 그대로 살아 있고,
#      7번째를 주면 날씨 심볼이 선다). 심볼 자리만큼 판이 넓어지는 것도 함께 본다.
#   ② 달력 패널 토글 — 닫힘 시작·toggle 왕복·close 멱등·시계 판 히트박스(판 안 true / 밖 false).
#   ③ 달력 마킹 데이터 — 28칸·오늘·지난 날·절기 행사일·테마 데이(25일)·해금 여부("?" 결).
#   ④ lighting 날씨 틴트 — 무인자 호출 하위호환(=평온과 픽셀 동일)·혼우 한색·잿눈 밝음·혼불 보라.
#   ⑤ 파티클 억제 — 실내·지하(갱도/나락)에서 꺼짐 + 혼불 바람은 애초에 낙하물 0.
#
# ★ 픽셀을 세지 않는다(결정 10의 "상태·데이터 위주"): 그린 결과가 아니라 *무엇을 그리기로
#   했는가*(마킹 데이터·활성 플래그·틴트 색)를 단언한다 — 절차 도형 좌표를 굳히면 T9 아트 교체가
#   테스트 재작성을 강요한다.
#
# 실행: ./run_tests.sh weather_hud   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame
	return m

func _initialize() -> void:
	print("══ S7-T8 달력·HUD 날씨·시각 연출 검증 ══")

	# ── ① HUD 날씨 인자(가법 확장) ────────────────────────────────────────────
	print("── ① 시계 HUD 날씨 심볼 ──")
	var hud := ClockHud.new()
	get_root().add_child(hud)
	hud.setup()
	# 옛 6인자 호출 — 한 글자도 안 고친 호출부가 그대로 산다(하위호환의 본체).
	hud.set_state("피안절", 3, "09:20", "아침", 120, "")
	_check("6인자 옛 호출이 그대로 통한다(날씨 미지정 = -1)", hud._weather == -1)
	var lead_narrow := hud._time_lead()
	var w_narrow := hud._plate_rect().size.x
	# 7번째 인자 = 오늘 날씨. 심볼 한 칸이 시각 줄 왼쪽에 붙는다.
	hud.set_state("피안절", 3, "09:20", "아침", 120, "", Weather.RAIN)
	_check("7번째 가법 인자로 날씨가 들어온다", hud._weather == Weather.RAIN)
	_check("시각 줄이 날씨 심볼 자리를 낸다",
		is_equal_approx(hud._time_lead(), lead_narrow + ClockHud.ICON_PX + ClockHud.ICON_GAP))
	_check("판이 좁아지지는 않는다(글자 잘림 0)", hud._plate_rect().size.x >= w_narrow)
	# 날씨만 바뀌어도 다시 그린다(문자열 게이트에 날씨가 합류했는가 — 안 그러면 하늘이 얼어붙는다).
	hud.set_state("피안절", 3, "09:20", "아침", 120, "", Weather.SNOW)
	_check("같은 문자열·다른 날씨면 상태가 갱신된다", hud._weather == Weather.SNOW)
	for w in [Weather.CALM, Weather.RAIN, Weather.SNOW, Weather.SOULWIND]:
		hud.set_state("성야절", 9, "13:00", "낮", 5, "", w)
	_check("날씨 4종 전부 심볼 경로를 탄다(그리기 예외 0)", hud._weather == Weather.SOULWIND)
	hud.queue_free()

	# ── ② 달력 패널 토글 ─────────────────────────────────────────────────────
	print("── ② 달력 패널 토글 ──")
	var cal := CalendarPanel.new()
	get_root().add_child(cal)
	cal.setup()
	_check("시작은 닫힘", not cal.is_open() and not cal.visible)
	cal.set_state(10, 1, 0)
	_check("toggle → 열림", cal.toggle() and cal.is_open() and cal.visible)
	_check("toggle → 닫힘", not cal.toggle() and not cal.is_open())
	cal.close()
	_check("닫힌 상태의 close는 무해(멱등)", not cal.is_open())

	# ── ③ 달력 마킹 데이터 ───────────────────────────────────────────────────
	print("── ③ 28칸 마킹(오늘·지난 날·행사·테마) ──")
	# 피안절 10일 · 카페 1단 · 매출 0 → 메이드 데이(25일)는 해금, 힙합/크리스마스는 무관.
	cal.set_state(10, 1, 0)
	var cells: Array = cal.cells()
	_check("28칸", cells.size() == GameClock.DAYS_PER_SEASON)
	_check("표제 = 절기 + 연차", cal.header() == "피안절 · 1년차")
	var today_n := 0
	var past_n := 0
	for c in cells:
		if bool(c["today"]):
			today_n += 1
			_check("오늘 칸의 일차가 맞다", int(c["dos"]) == 10 and int(c["day"]) == 10)
		if bool(c["past"]):
			past_n += 1
	_check("오늘은 정확히 한 칸", today_n == 1)
	_check("지난 날 = 9칸(1~9일)", past_n == 9)
	# 절기 행사(피안 = 삼도천 낚시 더비 12일) — 날짜를 하드코딩하지 않고 표에서 읽는다.
	var ev_dos := int(SeasonalEvent.DAY_OF_SEASON[0])
	var ev_cells: Array = []
	var th_cells: Array = []
	for c in cells:
		if int(c["event"]) != SeasonalEvent.NONE:
			ev_cells.append(c)
		if int(c["theme"]) != Festival.NONE:
			th_cells.append(c)
	_check("절기 행사는 한 칸", ev_cells.size() == 1)
	_check("행사 칸 = 표의 일차 · 그 절기 행사",
		int(ev_cells[0]["dos"]) == ev_dos and int(ev_cells[0]["event"]) == SeasonalEvent.DERBY)
	_check("테마 데이는 한 칸(25일)",
		th_cells.size() == 1 and int(th_cells[0]["dos"]) == Festival.DAY_OF_SEASON)
	_check("테마 슬롯 = 그 절기 테마", int(th_cells[0]["theme"]) == Festival.MAID)
	_check("카페 1단이면 메이드 데이 해금", bool(th_cells[0]["theme_unlocked"]))
	_check("해금 범례는 테마명을 밝힌다",
		"메이드 데이" in str(cal.legend()) and "삼도천 낚시 더비" in str(cal.legend()))
	# 진척 0 → 같은 25일이 "?"(슬롯은 보이되 정체는 가림).
	cal.set_state(10, 0, 0)
	var locked: Array = cal.cells()
	_check("진척 0이면 같은 칸이 비해금", not bool(locked[Festival.DAY_OF_SEASON - 1]["theme_unlocked"]))
	_check("비해금 범례는 '?'로 가린다",
		"?" in str(cal.legend()) and not ("메이드 데이" in str(cal.legend())))
	# 절기·연차가 넘어가도 달력은 *이번 절기만* 보여 준다(다음 절기 미리보기 없음).
	cal.set_state(113, 2, 0)   # 113 = 2년차 피안절 1일
	_check("연차 표기가 112일마다 오른다", cal.header() == "피안절 · 2년차")
	var y2: Array = cal.cells()
	_check("절기 첫날 = 지난 날 0칸·오늘 첫 칸",
		bool(y2[0]["today"]) and int(y2[0]["day"]) == 113)
	_check("칸의 절대 day가 이번 절기 28일치뿐", int(y2[27]["day"]) == 140)
	cal.queue_free()

	# ── ④ lighting 날씨 틴트 ─────────────────────────────────────────────────
	print("── ④ 날씨 틴트(시각 × 하늘) ──")
	var lit := DayNightLighting.new()
	get_root().add_child(lit)
	var noon := 720.0
	_check("무인자 tint_for = 평온(옛 호출 픽셀 동일)",
		lit.tint_for(noon) == lit.tint_for(noon, Weather.CALM))
	_check("평온 틴트 = 무보정(흰색)", lit.weather_tint(Weather.CALM) == Color.WHITE)
	var rain := lit.tint_for(noon, Weather.RAIN)
	var base := lit.tint_for(noon)
	_check("혼우 = 한색(파랑이 빨강보다 덜 깎인다)", rain.b > rain.r and rain.r < base.r)
	var snow := lit.tint_for(noon, Weather.SNOW)
	_check("잿눈 = 밝은 회백(한낮보다 밝아진다)", snow.r > base.r and snow.b > base.b)
	var wind := lit.tint_for(noon, Weather.SOULWIND)
	_check("혼불 바람 = 보랏빛 기운(초록만 깎이고 파랑은 산다)",
		wind.b > wind.g and wind.g < base.g)
	# "아주 약하게" — 지상 전조라 넷 중 가장 얕은 보정이어야 한다(혼우·잿눈보다 흰색에 가깝다).
	var d_wind: float = absf(wind.r - base.r) + absf(wind.g - base.g) + absf(wind.b - base.b)
	var d_rain: float = absf(rain.r - base.r) + absf(rain.g - base.g) + absf(rain.b - base.b)
	_check("혼불 지상 틴트가 혼우보다 얕다(전조 강도)", d_wind < d_rain)
	# apply도 가법 인자 — 무인자 호출이 살아 있다(하네스·기존 테스트 보호).
	lit.apply(noon)
	_check("apply 무인자 = 평온 색조", lit.color == lit.tint_for(noon))
	lit.apply(noon, Weather.RAIN)
	_check("apply(분, 날씨)가 색조에 하늘을 곱한다", lit.color == rain)
	lit.queue_free()

	# ── ⑤ 파티클 억제(실내·지하) ─────────────────────────────────────────────
	print("── ⑤ 날씨 파티클 ──")
	var fx := WeatherFx.new()
	get_root().add_child(fx)
	fx.setup()
	var view := Vector2(640, 360)
	_check("혼우·잿눈만 낙하물이 있다",
		WeatherFx.has_particles(Weather.RAIN) and WeatherFx.has_particles(Weather.SNOW)
		and not WeatherFx.has_particles(Weather.CALM)
		and not WeatherFx.has_particles(Weather.SOULWIND))
	fx.set_weather(Weather.RAIN, false)
	_check("실외 혼우 = 활성", fx.is_active() and fx.visible)
	fx.set_weather(Weather.RAIN, true)
	_check("실내·지하면 같은 혼우도 꺼진다", not fx.is_active() and not fx.visible)
	fx.set_weather(Weather.SOULWIND, false)
	_check("혼불 바람은 실외에서도 파티클 0(전조 틴트만)", not fx.is_active())
	fx.set_weather(Weather.CALM, false)
	_check("평온 = 꺼짐", not fx.is_active())
	_check("혼우 기하 = 빗줄기 다발",
		WeatherFx.particles(Weather.RAIN, 1.0, view).size() == WeatherFx.RAIN_COUNT)
	_check("잿눈 기하 = 눈송이 다발",
		WeatherFx.particles(Weather.SNOW, 1.0, view).size() == WeatherFx.SNOW_COUNT)
	_check("평온·혼불 기하 = 0",
		WeatherFx.particles(Weather.CALM, 1.0, view).is_empty()
		and WeatherFx.particles(Weather.SOULWIND, 1.0, view).is_empty())
	# 입자는 화면 안에 머문다(fposmod 랩) — 시간이 흘러도 밖으로 새지 않는다.
	var inside := true
	for t in [0.0, 3.7, 41.3, 600.0]:
		for p in WeatherFx.particles(Weather.RAIN, t, view):
			var a: Vector2 = p["a"]
			if a.x < -WeatherFx.RAIN_SLANT or a.x > view.x or a.y < -WeatherFx.RAIN_LEN or a.y > view.y:
				inside = false
		for p in WeatherFx.particles(Weather.SNOW, t, view):
			var q: Vector2 = p["pos"]
			if q.x < 0.0 or q.x > view.x or q.y < -WeatherFx.SNOW_SIZE or q.y > view.y:
				inside = false
	_check("입자가 화면 밖으로 새지 않는다(랩 어라운드)", inside)
	fx.queue_free()

	# ── ⑥ main 배선(무대별 억제 판정·HUD 주입) ───────────────────────────────
	print("── ⑥ main 배선 ──")
	var m: Node = await _spawn_main()
	_check("HUD 3조각이 다 붙었다",
		m.clock_hud != null and m.calendar_panel != null and m.weather_fx != null)
	_check("실외(안식 농원)는 억제 안 함", not m._weather_fx_suppressed())
	m._indoor = "집"
	_check("실내 억제", m._weather_fx_suppressed())
	m._indoor = ""
	m._region = RegionCatalog.EOPHWA_MINE
	_check("업화 갱도(지하) 억제", m._weather_fx_suppressed())
	m._region = RegionCatalog.NARAK
	_check("나락(지하) 억제", m._weather_fx_suppressed())
	m._region = RegionCatalog.HOME
	# 시계 판 히트박스 — 판 한가운데는 맞고, 화면 좌상단은 빗나간다(도구질을 안 먹는다).
	# ★ 부팅 온보딩 대화가 열려 있으면 상시 HUD가 숨겨져(_hud_hidden) 히트박스도 닫힌다 — 대화를
	#   닫고 가시성을 세운 뒤 본다(이 단언의 주제는 기하지 모달 규칙이 아니다).
	m.onboarding.notice_seen()
	m.dialogue._close()
	m.clock_hud.visible = true
	m.clock_hud.set_state("피안절", 1, "06:00", "아침", 0, "", Weather.CALM)
	var sc: float = m.get_node("CanvasLayer").scale.x
	var plate: Rect2 = m.clock_hud._plate_rect()
	_check("시계 판 한가운데 클릭 = 히트", m.clock_hud.hit_test(plate.get_center() * sc))
	_check("화면 좌상단 클릭 = 미스(도구질로 흐른다)", not m.clock_hud.hit_test(Vector2(4, 4)))
	# 달력은 오늘의 day·진척을 주입받아 산다(_process가 매 프레임 흘려넣는 그 값).
	m.calendar_panel.set_state(m.clock.day, m._cafe_stage(), m._cafe_revenue_total)
	_check("달력이 현재 절기를 잡는다",
		m.calendar_panel.header().begins_with(GameClock.season_name(m.clock.season_index())))
	m.queue_free()
	await process_frame

	print("══ %s (%d 실패) ══" % ["전체 통과" if _fail == 0 else "실패 있음", _fail])
	quit(1 if _fail > 0 else 0)
