extends Control
class_name ClockHud
# ADR-0048 Phase C(S1-13) — 우상단 시계 클러스터(스타듀식 온스크린 HUD).
#
# 목적: 흩어진 raw Label 셋(ClockLabel·GoldLabel·MilestoneLabel)을 한 장의 태운 한지 플레이트로
#       묶는다. 절기·일차·시각·때(아침/낮/저녁/밤)·골드·카페 마일스톤을 우상단 한 클러스터로 읽힌다
#       (스타듀 우상단 날짜/시계/골드 대응). "화면에 raw 패널 0"의 시계 파트.
#
# 설계 메모:
#   - hotbar_hud·vitals_hud·notice_feed와 같은 결: 코드 생성 자식 Control(무상태). main이 매 프레임
#     set_state로 표시값을 흘려넣되, 문자열이 실제로 바뀔 때만 다시 그린다(폴링 비용 최소).
#   - 부모 CanvasLayer UI scale(×1.5)을 되돌려 보이는 영역(=640×360) 우상단에 배치(핫바와 같은
#     스케일 함정 회피).
#   - 요일은 도메인에 없다(28일 절기, 주 개념 미정 — festival.gd). 스타듀의 "요일"을 흉내 내는 대신
#     절기 내 *일차*를 보여 준다("성야절 12일") — 더 도메인 충실하고 정보량도 크다.
#   - ★[S7-T8 / ADR-0065 결정 10] 날씨(☀) 자리가 채워졌다. ADR-0048이 "백엔드 부재로 보류"라
#     비워 뒀던 그 슬롯을, Weather(T3)가 순수 파생 롤로 서고 나서야 연다. 심볼은 **절차 드로잉**
#     이고(아트 아이콘은 T9 몫 — 에셋 파일 신규 0), 자리는 *시각 줄 왼쪽*이다: 시간대 심볼과 나란히
#     "지금 언제·어떤 하늘"이 한 줄에 읽힌다(절기 줄은 절기 심볼이 이미 쓰고 있다).
#   - ★ **내일 예보는 여기 안 띄운다**(결정 10). 예보의 자리는 점괘 거울(T4)이다 — 상시 HUD에
#     오늘+내일 두 심볼을 겹치면 우상단이 과밀해지고, "지금 이 하늘"이라는 상시 정보와 "내일을
#     미리 본다"는 조회 행위가 한 위젯에 섞인다.

# ★ owner 2026-07-03 3차 HUD 가이드(C) — 플레이트 빈 여백 제거·전체 축소. PAD·폰트 압축 +
#   플레이트 폭은 고정 W 폐기하고 *내용 최대폭*에 맞춰 동적 산출(_draw). 우상단 구석 밀착.
const MARGIN := 8.0        # 화면 오른쪽·위 여백
const PAD := 7.0           # 플레이트 안쪽 여백(11→7 압축)
const ROW_GAP := 4.0       # 줄 사이 여유(8→4 압축)
const ROW_DATE := 13       # 절기·일차 글자 크기(16→13)
const ROW_TIME := 11       # 시각·때(14→11)
const ROW_GOLD := 12       # 골드(15→12)
const ROW_MILE := 9        # 마일스톤(11→9)

# ★ [아트정리패스] 골드 아이콘 = 엽전(옛 "◈" 글리프 대체). 골드 숫자 왼쪽에 그린다.
const COIN: Texture2D = preload("res://assets/ui/gold_coin.png")
const COIN_PX := 12.0      # 엽전 렌더 변(골드 줄 높이에 맞춤)
const COIN_GAP := 2.0      # 엽전↔숫자 사이 여백

# ★ [정체성 UI 큐 §2] 절기·시간대 심볼 아이콘(gemini-ui-identity-spec §2.1). 절기 줄·시각 줄
#   좌측에 16px 심볼을 얹어 "저승 절기 클러스터"의 정체성을 준다(위젯 재설계 아님·아이콘 액센트).
#   폴백: 파일이 없으면 preload가 실패하므로 8장 모두 있어야 한다(드롭인 원칙 — 없으면 이 파트만 제거).
const SEASON_ICONS: Array[Texture2D] = [   # GameClock.SEASON_NAMES index 0..3(피안·유화·망연·성야)
	preload("res://assets/ui/season_icon_pianhwa.png"),
	preload("res://assets/ui/season_icon_yuhwa.png"),
	preload("res://assets/ui/season_icon_mangyeon.png"),
	preload("res://assets/ui/season_icon_seongya.png"),
]
const TIME_ICONS := {                       # GameClock.phase() 문자열 4
	"아침": preload("res://assets/ui/time_icon_morning.png"),
	"낮": preload("res://assets/ui/time_icon_day.png"),
	"저녁": preload("res://assets/ui/time_icon_evening.png"),
	"밤": preload("res://assets/ui/time_icon_night.png"),
}
const ICON_PX := 16.0      # 절기/시간대 심볼 렌더 변
const ICON_GAP := 3.0      # 심볼↔글자 사이 여백

# ★[S7-T8] 날씨 심볼 팔레트(절차 드로잉 — 에셋 0). 절기·시간대 심볼과 같은 16px 자리에 들어가되
# 저것들은 PNG, 이것은 draw_rect 청크다(T9에서 아트로 교체되면 이 함수만 텍스처 blit으로 바뀐다).
const WX_SUN := Color(0.98, 0.80, 0.34)      # 평온 — 낮은 해(금빛)
const WX_RAIN := Color(0.62, 0.80, 0.98)     # 혼우 — 서늘한 물빛
const WX_SNOW := Color(0.93, 0.95, 1.00)     # 잿눈 — 회백
const WX_FIRE := Color(0.74, 0.52, 0.96)     # 혼불 바람 — 보랏빛 도깨비불
const WX_GRID := 8.0       # 심볼 내부 격자(8×8 청크 — ICON_PX 16이면 청크 한 변 2px)

var _date := ""            # "성야절 12일"
var _time := ""            # "18:24 · 저녁"
var _gold := ""            # 골드 숫자만(예 "1234") — 엽전은 아이콘으로 앞에 그림
var _mile := ""            # "카페 1단 ▓▓▒▒ 45%"
var _season_idx := -1      # 절기 심볼 인덱스(SEASON_ICONS·-1=미매칭 시 심볼 생략)
var _phase_key := ""       # 시간대 심볼 키(TIME_ICONS·미매칭 시 생략)
var _weather := -1         # ★[S7-T8] 오늘 날씨(Weather 눈금·-1 = 미지정 → 심볼 생략)

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

# main이 매 프레임 호출. 표시 문자열이 바뀔 때만 다시 그린다.
# ★[S7-T8] `weather`는 **가법 인자**다(기본값 -1 = 심볼 없음). 기존 6인자 호출은 한 글자도 안 고쳐도
#   그대로 컴파일·동작하고(하위호환), 날씨를 아는 호출부만 일곱 번째를 얹는다.
func set_state(season: String, day_of_season: int, time_str: String, phase: String,
		gold: int, milestone: String, weather: int = -1) -> void:
	var date := "%s %d일" % [season, day_of_season]
	var timv := "%s · %s" % [time_str, phase]
	var goldv := "%d" % gold
	if date == _date and timv == _time and goldv == _gold and milestone == _mile \
			and weather == _weather:
		return
	_date = date
	_time = timv
	_gold = goldv
	_mile = milestone
	_weather = weather
	# 심볼 인덱싱(문자열 → 아이콘) — main이 넘긴 절기명·때를 그대로 매핑(무매칭이면 심볼 생략).
	_season_idx = GameClock.SEASON_NAMES.find(season)
	_phase_key = phase if TIME_ICONS.has(phase) else ""
	queue_redraw()

func _view() -> Vector2:
	var sc := 1.0
	var par := get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		sc = par.scale.x
	return Vector2(size.x / sc, size.y / sc)

# 절기 줄 좌측 심볼이 먹는 폭(없으면 0).
func _date_lead() -> float:
	return (ICON_PX + ICON_GAP) if _season_idx >= 0 else 0.0

# 시각 줄 좌측 심볼들이 먹는 폭 — ★[S7-T8] 시간대 심볼 + 날씨 심볼 **둘**이 설 수 있다(둘 다 선택적).
func _time_lead() -> float:
	var lead := 0.0
	if _phase_key != "":
		lead += ICON_PX + ICON_GAP
	if _weather >= 0:
		lead += ICON_PX + ICON_GAP
	return lead

# ★ 플레이트 폭 = 내용 최대폭 + 여백(고정 W 폐기 — 빈 마진 0, guide C). 높이 = 줄 높이 합 + 여백.
# ★[S7-T8] _draw에서 떼어냈다 — 달력 패널 토글이 "시계 판을 클릭했는가"를 물어야 해서(hit_test),
#   판의 기하가 그리기와 판정 양쪽에서 같은 한 곳에서 나와야 한다.
func _plate_rect() -> Rect2:
	var view := _view()
	# 골드 줄 폭 = 엽전 + 여백 + 숫자(플레이트 폭 산출이 아이콘을 포함해야 잘림 없음).
	var gold_w := COIN_PX + COIN_GAP + HanjiUi.text_width(_gold, ROW_GOLD)
	# 절기·시각 줄은 좌측 심볼 폭(있을 때)을 폭 산출에 포함(글자가 심볼과 겹치지 않게).
	var date_w := _date_lead() + HanjiUi.text_width(_date, ROW_DATE)
	var time_w := _time_lead() + HanjiUi.text_width(_time, ROW_TIME)
	var wmax := maxf(maxf(date_w, time_w), gold_w)
	if _mile != "":
		wmax = maxf(wmax, HanjiUi.text_width(_mile, ROW_MILE))
	var w := wmax + PAD * 2.0
	var h := PAD * 2.0 + float(ROW_DATE) + ROW_GAP + float(ROW_TIME) + ROW_GAP + float(ROW_GOLD)
	if _mile != "":
		h += ROW_GAP + float(ROW_MILE)
	return Rect2(view.x - w - MARGIN, MARGIN, w, h)

# ★[S7-T8] 화면 좌표(get_viewport().get_mouse_position() 눈금)가 시계 판 안인가 — 달력 토글의 판정.
# 부모 CanvasLayer 스케일(×1.5)을 되돌려 논리 좌표로 비교한다(_view와 같은 되돌림).
func hit_test(screen_pos: Vector2) -> bool:
	if not visible or _date == "":
		return false
	var sc := 1.0
	var par := get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		sc = par.scale.x
	return _plate_rect().has_point(screen_pos / sc)

func _draw() -> void:
	if _date == "":
		return
	var date_lead := _date_lead()
	var time_lead := _time_lead()
	var plate := _plate_rect()
	HanjiUi.draw_plate(self, plate)
	var x := plate.position.x + PAD
	var right := plate.end.x - PAD
	var y := plate.position.y + PAD + float(ROW_DATE)
	# 절기·일차(우측 정렬, 밝은 금박 — 클러스터의 표제) + 절기 심볼(글자 왼쪽).
	var date_tx := _draw_right(x + date_lead, right, y, _date, ROW_DATE, HanjiUi.GOLD_SOFT)
	if _season_idx >= 0 and _season_idx < SEASON_ICONS.size():
		draw_texture_rect(SEASON_ICONS[_season_idx],
			Rect2(date_tx - ICON_GAP - ICON_PX, y - ICON_PX + 2.0, ICON_PX, ICON_PX), false)
	y += ROW_GAP + float(ROW_TIME)
	# 시각·때(우측 정렬, 밝은 글자) + 시간대 심볼 + ★[S7-T8] 날씨 심볼(글자 왼쪽으로 차례로).
	var time_tx := _draw_right(x + time_lead, right, y, _time, ROW_TIME, HanjiUi.INK_LIGHT)
	var icon_x := time_tx
	if _phase_key != "":
		icon_x -= ICON_GAP + ICON_PX
		draw_texture_rect(TIME_ICONS[_phase_key],
			Rect2(icon_x, y - ICON_PX + 2.0, ICON_PX, ICON_PX), false)
	if _weather >= 0:
		icon_x -= ICON_GAP + ICON_PX
		_draw_weather_glyph(Rect2(icon_x, y - ICON_PX + 2.0, ICON_PX, ICON_PX), _weather)
	y += ROW_GAP + float(ROW_GOLD)
	# 골드(우측 정렬, 금박) — 엽전 아이콘 + 숫자. 숫자를 우변에 맞추고 엽전을 그 왼쪽에.
	var num_w := HanjiUi.text_width(_gold, ROW_GOLD)
	var num_x: float = maxf(x + COIN_PX + COIN_GAP, right - num_w)
	HanjiUi.draw_text(self, Vector2(num_x, y), _gold, ROW_GOLD, HanjiUi.GOLD)
	var coin_rect := Rect2(num_x - COIN_GAP - COIN_PX, y - COIN_PX + 1.0, COIN_PX, COIN_PX)
	draw_texture_rect(COIN, coin_rect, false)
	# 마일스톤(우측 정렬, 보조 톤 — 매크로 목표 한 줄).
	if _mile != "":
		y += ROW_GAP + float(ROW_MILE)
		_draw_right(x, right, y, _mile, ROW_MILE, HanjiUi.INK_DIM)

# 우측 정렬 한 줄(플레이트 우변 - PAD에 오른끝을 맞춘다). 그린 글자의 좌측 x를 반환(심볼 배치용).
func _draw_right(left: float, right: float, baseline: float, text: String, size: int, color: Color) -> float:
	var w := HanjiUi.text_width(text, size)
	var px: float = maxf(left, right - w)
	HanjiUi.draw_text(self, Vector2(px, baseline), text, size, color)
	return px

# ── ★[S7-T8] 날씨 심볼(절차 드로잉) ──────────────────────────────────────────
# 16px 자리 안을 8×8 격자로 보고 청크 사각을 찍는다(도트 결 — 안티에일리어싱 곡선 금지).
# 아트 아이콘이 오는 T9에는 이 함수 본문만 draw_texture_rect 한 줄로 바뀐다(호출부·레이아웃 불변).
#
# ★ 청크 표는 **데이터**(weather_chunks)로 두고 _draw는 그걸 찍기만 한다 — weather_fx.particles와
#   같은 이유다: 오프라인 합성 덤프(tools/weather_dump.gd)가 같은 표를 읽어 이미지에 찍으므로,
#   덤프에 뜬 심볼이 곧 게임에 뜨는 심볼이다(두 벌 그리기 = 어긋남의 씨앗).
# 반환: [[gx, gy, gw, gh, Color], …] — 8×8 격자 단위.
static func weather_chunks(w: int) -> Array:
	match w:
		Weather.CALM:
			# 해 — 팔각 원반 + 네 귀 빛살(평온한 하늘의 기준선).
			var ray := Color(WX_SUN, 0.65)
			return [
				[2, 2, 4, 4, WX_SUN], [3, 1, 2, 1, WX_SUN], [3, 6, 2, 1, WX_SUN],
				[1, 3, 1, 2, WX_SUN], [6, 3, 1, 2, WX_SUN],
				[1, 1, 1, 1, ray], [6, 1, 1, 1, ray], [1, 6, 1, 1, ray], [6, 6, 1, 1, ray],
			]
		Weather.RAIN:
			# 혼우 — 잿빛 구름 아래 빗줄기 두 단(엇갈리게 놓아 "내리는 중"으로 읽힌다).
			var cloud := Color(0.72, 0.72, 0.78)
			return [
				[2, 1, 4, 1, cloud], [1, 2, 6, 2, cloud],
				[2, 5, 1, 2, WX_RAIN], [4, 5, 1, 2, WX_RAIN],
				[6, 5, 1, 1, WX_RAIN], [1, 6, 1, 1, WX_RAIN],
			]
		Weather.SNOW:
			# 잿눈 — 6방 눈송이(십자 + 대각 네 갈래). 중심 (3,3) 기준 대칭.
			var out: Array = [[3, 1, 1, 6, WX_SNOW], [1, 3, 6, 1, WX_SNOW]]
			for d in [[1, 1], [2, 2], [4, 4], [5, 5], [5, 1], [4, 2], [2, 4], [1, 5]]:
				out.append([d[0], d[1], 1, 1, WX_SNOW])
			return out
		Weather.SOULWIND:
			# 혼불 바람 — 보랏빛 도깨비불 한 점(어두운 겉불 + 밝은 심지).
			return [
				[3, 1, 2, 2, WX_FIRE], [2, 3, 4, 3, WX_FIRE], [3, 6, 2, 1, WX_FIRE],
				[3, 3, 2, 2, Color(1.0, 0.90, 0.98)],
			]
	return []

func _draw_weather_glyph(rect: Rect2, w: int) -> void:
	var u := rect.size.x / WX_GRID
	var v := rect.size.y / WX_GRID
	for c in weather_chunks(w):
		draw_rect(Rect2(rect.position.x + float(c[0]) * u, rect.position.y + float(c[1]) * v,
			float(c[2]) * u, float(c[3]) * v), c[4])
