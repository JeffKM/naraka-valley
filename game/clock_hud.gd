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
#   - 날씨(☀)는 백엔드 부재로 보류(ADR-0048) — 자리만 비운다.

const MARGIN := 8.0        # 화면 오른쪽·위 여백
const PAD := 11.0          # 플레이트 안쪽 여백
const W := 182.0           # 플레이트 폭(우상단 고정 정렬)
const ROW_DATE := 16       # 절기·일차 글자 크기
const ROW_TIME := 14       # 시각·때
const ROW_GOLD := 15       # 골드
const ROW_MILE := 11       # 마일스톤(작게)

var _date := ""            # "성야절 12일"
var _time := ""            # "18:24 · 저녁"
var _gold := ""            # "◈ 1234"
var _mile := ""            # "카페 1단 ▓▓▒▒ 45%"

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

# main이 매 프레임 호출. 표시 문자열이 바뀔 때만 다시 그린다.
func set_state(season: String, day_of_season: int, time_str: String, phase: String,
		gold: int, milestone: String) -> void:
	var date := "%s %d일" % [season, day_of_season]
	var timv := "%s · %s" % [time_str, phase]
	var goldv := "◈ %d" % gold
	if date == _date and timv == _time and goldv == _gold and milestone == _mile:
		return
	_date = date
	_time = timv
	_gold = goldv
	_mile = milestone
	queue_redraw()

func _view() -> Vector2:
	var sc := 1.0
	var par := get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		sc = par.scale.x
	return Vector2(size.x / sc, size.y / sc)

func _draw() -> void:
	if _date == "":
		return
	var view := _view()
	# 플레이트 높이 = 세 줄(날짜·시각·골드) + 마일스톤 한 줄 + 여백. 줄 간격은 각 글자 크기+여유.
	var h := PAD * 2.0 + float(ROW_DATE + 6) + float(ROW_TIME + 6) + float(ROW_GOLD + 6)
	if _mile != "":
		h += float(ROW_MILE + 6)
	var plate := Rect2(view.x - W - MARGIN, MARGIN, W, h)
	HanjiUi.draw_plate(self, plate)
	var x := plate.position.x + PAD
	var right := plate.end.x - PAD
	var y := plate.position.y + PAD + float(ROW_DATE)
	# 절기·일차(우측 정렬, 밝은 금박 — 클러스터의 표제).
	_draw_right(x, right, y, _date, ROW_DATE, HanjiUi.GOLD_SOFT)
	y += float(ROW_TIME + 8)
	# 시각·때(우측 정렬, 밝은 글자).
	_draw_right(x, right, y, _time, ROW_TIME, HanjiUi.INK_LIGHT)
	y += float(ROW_GOLD + 8)
	# 골드(우측 정렬, 금박).
	_draw_right(x, right, y, _gold, ROW_GOLD, HanjiUi.GOLD)
	# 마일스톤(우측 정렬, 보조 톤 — 매크로 목표 한 줄).
	if _mile != "":
		y += float(ROW_MILE + 8)
		_draw_right(x, right, y, _mile, ROW_MILE, HanjiUi.INK_DIM)

# 우측 정렬 한 줄(플레이트 우변 - PAD에 오른끝을 맞춘다).
func _draw_right(left: float, right: float, baseline: float, text: String, size: int, color: Color) -> void:
	var w := HanjiUi.text_width(text, size)
	var px: float = maxf(left, right - w)
	HanjiUi.draw_text(self, Vector2(px, baseline), text, size, color)
