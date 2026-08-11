extends Control
class_name CalendarPanel
# ★[S7-T8 / ADR-0065 결정 10] 절기 달력 패널 — 28칸 한 장(그레이박스).
#
# 목적: "이번 절기 어디쯤이고, 남은 날에 무엇이 있는가"를 한 화면에서 읽게 한다. Slice 7이 하루에
#       거는 층이 넷(절기 전환·날씨·테마 데이·절기 행사)인데, 그때까지 플레이어가 미래를 보는
#       창구는 점괘 거울의 *한 줄*뿐이었다 — 날짜의 지도가 없으면 "곳간을 채워 두자" 같은 예고가
#       며칠 뒤인지 감이 안 온다.
#
# 설계 메모:
#   - context_popup·clock_hud와 같은 결: 코드 생성 자식 Control(무상태). main이 매 프레임
#     set_state(day, stage, revenue)로 흘려넣고, 값이 바뀔 때만 마킹을 다시 파생·다시 그린다.
#   - **표시 데이터는 전부 파생이다.** 이 패널은 달력을 *들지 않는다* — GameClock(절기·일차)·
#     Festival(테마 슬롯·해금)·SeasonalEvent(행사일)가 이미 순수 파생 규칙이라, 여기서 다시
#     계산해도 진실원이 갈리지 않는다(그 셋이 단일 출처, 이 파일은 조회자).
#   - **해금 입력(stage·revenue)은 주입받는다** — Festival이 세이브를 모르는 무상태 규칙이라
#     main이 진척을 넘겨 주는 그 다리를 그대로 탄다(_festival_theme과 같은 인자).
#   - **다음 절기 미리보기는 없다**(스타듀 동형 — 게임 내 달력은 이번 달만 보여 준다). 미래 절기를
#     펼치면 "며칠 뒤 무슨 씨앗을 사 두자"가 계산 가능해져 절기의 리듬이 스프레드시트가 된다.
#   - **비-모달**(mouse_filter IGNORE·이동 잠금 없음). 메뉴 프레임(모달)과 달리 이건 시계 곁의
#     조회 오버레이라, 열어 둔 채 걸어 다녀도 되고 다시 클릭하면 닫힌다.
#   - 아이콘·장식 아트는 T9 몫이다. 지금은 전부 절차 도형(한지 프레임 + 사각 칸 + 점 마커).

# ── 격자 규격(640×360 논리 화면 기준) ────────────────────────────────────────
const COLS := 7                # 28 = 7 × 4(주 개념은 없지만 7열이 눈에 가장 잘 갈린다)
const CELL_W := 30.0
const CELL_H := 26.0
const CELL_GAP := 4.0
const PAD := 14.0              # 프레임 안쪽 여백
const HEAD_SIZE := 15          # 표제("성야절 · 1년차")
const DAY_SIZE := 10           # 칸 안 일차 숫자
const LEG_SIZE := 10           # 하단 범례 줄

# ── 칸 팔레트(밝은 한지 위) ──────────────────────────────────────────────────
const CELL_FILL := Color(0.86, 0.79, 0.63, 0.55)     # 앞으로 올 날
const CELL_PAST := Color(0.52, 0.47, 0.39, 0.42)     # 지난 날(dim)
const CELL_TODAY := Color(0.96, 0.86, 0.52, 0.85)    # 오늘(금박 바탕)
const CELL_EDGE := Color(0.50, 0.42, 0.30, 0.75)     # 칸 테두리
const MARK_EVENT := Color(0.28, 0.58, 0.62)          # 절기 행사 마커(청록)
const MARK_THEME := Color(0.86, 0.20, 0.24)          # 테마 데이 마커(홍 — Festival.BANNER_A 결)
const MARK_LOCKED := Color(0.46, 0.42, 0.36)         # 비해금 테마 데이("?" 결의 회색)
const MARK_BIRTHDAY := Color(0.78, 0.42, 0.62)       # ★[S8-T3] 생일 마커(연분홍 — 청록◆·홍●과 구별)

var _open := false
var _day := 0
var _stage := -1
var _revenue := -1
var _cells: Array = []         # 28행 마킹 데이터(아래 _rebuild 참조 — 테스트가 이걸 단언한다)
# ★[S8-T3] 주민 id → 표시명. **주입받는다** — 이 패널은 레지스트리를 모르고(무상태 조회자),
#   표시명의 진실원은 main `_setup_residents`의 레코드다. stage·revenue를 main이 넘겨 주는
#   그 다리를 그대로 탄다(파일 머리말 "해금 입력은 주입받는다"). 안 넣으면 id로 폴백해
#   헤드리스에서도 범례가 성립한다(마커·칸 데이터는 이름과 무관하게 이미 완성이다).
var _res_names: Dictionary = {}

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

# ── 토글(시계 판 클릭이 부른다 — 판정은 main이 clock_hud.hit_test로) ──────────
func is_open() -> bool:
	return _open

func toggle() -> bool:
	_open = not _open
	visible = _open
	queue_redraw()
	return _open

func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	queue_redraw()

# main이 매 프레임 호출. 날·진척이 바뀔 때만 마킹을 다시 파생한다(폴링 비용 최소 — clock_hud 결).
func set_state(day: int, stage: int, revenue: int) -> void:
	if day == _day and stage == _stage and revenue == _revenue:
		return
	_day = day
	_stage = stage
	_revenue = revenue
	_rebuild()
	queue_redraw()

# ── 마킹 파생(달력 3규칙 조회 — 이 파일은 규칙을 안 든다) ─────────────────────
# 각 행: {"dos": 절기 내 일차 1..28, "day": 절대 day, "past": 지난 날, "today": 오늘,
#         "event": SeasonalEvent 인덱스(-1 없음), "theme": Festival 테마 슬롯(-1 없음),
#         "theme_unlocked": 그 테마가 지금 해금됐는가}
# ★ theme은 **슬롯**(해금 무관 달력 자리)이고 해금은 따로 든다 — 비해금 25일도 "무언가 있는 날"로
#   보이되 정체는 "?"로 가려야 하기 때문이다(있는 줄도 모르면 목표가 안 생기고, 다 보이면 결실이
#   아니다). Festival.theme_slot_for_day ↔ is_unlocked를 갈라 둔 그 설계를 그대로 쓴다.
func _rebuild() -> void:
	_cells = []
	if _day <= 0:
		return
	var first := _day - GameClock.day_of_season(_day) + 1   # 이 절기 1일의 절대 day
	for i in GameClock.DAYS_PER_SEASON:
		var d := first + i
		var slot := Festival.theme_slot_for_day(d)
		_cells.append({
			"dos": i + 1,
			"day": d,
			"past": d < _day,
			"today": d == _day,
			"event": SeasonalEvent.event_for_day(d),
			"theme": slot,
			"theme_unlocked": slot != Festival.NONE and Festival.is_unlocked(slot, _stage, _revenue),
			# ★[S8-T3] 그날 생일인 주민 id("" = 없음). 생일 배치가 25일·행사일을 피해 잡혔으므로
			#   한 칸에 마커 둘이 겹치는 경우는 없다(무충돌은 gift_test가 전수로 지킨다).
			"birthday": Resident.birthday_on_day(d),
		})

# 테스트·디버그용 읽기 표면(복제 — 외부에서 못 흔든다).
func cells() -> Array:
	return _cells.duplicate(true)

# ★[S8-T3] 주민 표시명 주입(main이 레지스트리 등록 직후 1회 — 이후 안 바뀐다).
func set_resident_names(names: Dictionary) -> void:
	_res_names = names.duplicate()
	queue_redraw()

# 생일 범례에 쓸 이름(주입 안 됐으면 id 폴백).
func _res_name(rid: String) -> String:
	return String(_res_names.get(rid, rid))

# 표제 — "성야절 · 1년차". 연차는 112일(4절기)마다 오른다.
func header() -> String:
	if _day <= 0:
		return ""
	var year := (_day - 1) / (GameClock.DAYS_PER_SEASON * 4) + 1
	return "%s · %d년차" % [GameClock.season_name(GameClock.season_index_for_day(_day)), year]

# 하단 범례(절기 행사 / 테마 데이 / ★생일). 비해금 테마는 이름을 가리고 "?"로 남긴다.
# ★생일은 가리지 않는다 — 테마 데이처럼 진척으로 여는 결실이 아니라 **달력에 원래 있는 날**이고,
#   미리 알아야 선물을 챙길 수 있어 가리면 마커의 쓸모가 사라진다(스타듀 달력도 생일은 다 보인다).
func legend() -> Array:
	var out: Array = []
	for c in _cells:
		if int(c["event"]) != SeasonalEvent.NONE:
			out.append("◆ %d일 — %s" % [int(c["dos"]), SeasonalEvent.name_of(int(c["event"]))])
	for c in _cells:
		if int(c["theme"]) != Festival.NONE:
			var nm := Festival.name_of(int(c["theme"])) if bool(c["theme_unlocked"]) else "? (카페를 더 키우면)"
			out.append("● %d일 — %s" % [int(c["dos"]), nm])
	for c in _cells:
		var rid := String(c.get("birthday", ""))
		if rid != "":
			out.append("♥ %d일 — %s 생일" % [int(c["dos"]), _res_name(rid)])
	return out

func _view() -> Vector2:
	var sc := 1.0
	var par := get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		sc = par.scale.x
	return Vector2(size.x / sc, size.y / sc)

func _draw() -> void:
	if not _open or _cells.is_empty():
		return
	var view := _view()
	var rows := int(ceil(float(_cells.size()) / float(COLS)))
	var grid_w := COLS * CELL_W + (COLS - 1) * CELL_GAP
	var grid_h := rows * CELL_H + (rows - 1) * CELL_GAP
	var legs := legend()
	var frame_w := grid_w + PAD * 2.0
	var frame_h := PAD * 2.0 + float(HEAD_SIZE) + 8.0 + grid_h + 8.0 \
		+ legs.size() * (LEG_SIZE + 3.0)
	# 화면 중앙(시계 클러스터와 안 겹치게 살짝 아래로).
	var frame := Rect2(floorf((view.x - frame_w) * 0.5), floorf((view.y - frame_h) * 0.5) + 8.0,
		frame_w, frame_h)
	HanjiUi.draw_frame(self, frame)
	var x0 := frame.position.x + PAD
	var y := frame.position.y + PAD + float(HEAD_SIZE)
	HanjiUi.draw_text(self, Vector2(x0, y), header(), HEAD_SIZE, HanjiUi.INK, -1.0, false)
	y += 8.0
	# 28칸 — 오늘 금박·지난 날 dim·행사/테마 마커.
	for i in _cells.size():
		var c: Dictionary = _cells[i]
		var cx := x0 + (i % COLS) * (CELL_W + CELL_GAP)
		var cy := y + (i / COLS) * (CELL_H + CELL_GAP)
		var cell := Rect2(cx, cy, CELL_W, CELL_H)
		var fill := CELL_FILL
		if bool(c["today"]):
			fill = CELL_TODAY
		elif bool(c["past"]):
			fill = CELL_PAST
		draw_rect(cell, fill)
		draw_rect(cell, HanjiUi.GOLD_SOFT if bool(c["today"]) else CELL_EDGE, false,
			2.0 if bool(c["today"]) else 1.0)
		# 일차 숫자(좌상단).
		HanjiUi.draw_text(self, Vector2(cx + 3.0, cy + DAY_SIZE + 2.0), str(int(c["dos"])),
			DAY_SIZE, HanjiUi.INK, -1.0, false)
		# 마커 — 절기 행사(청록 ◆) · 테마 데이(홍 ● / 비해금은 회색 "?").
		# ★[S8-T3] 생일 — 색뿐 아니라 **형태도** 다르다(사각 마커 둘과 한눈에 갈리게).
		#   행사·테마일을 피해 배치했으므로 같은 자리(칸 하단 중앙)를 써도 겹치지 않는다.
		# ★[S8-T9 아트 패스] 작은 원 → **하트**. 범례가 "♥ %d일 — %s 생일"이라 마커가 원이면
		#   범례와 칸이 서로 다른 물건처럼 보였다(형태가 곧 색인 마커에선 그 어긋남이 크다).
		if String(c.get("birthday", "")) != "":
			_draw_heart_mark(Vector2(cx + CELL_W * 0.5, cy + CELL_H - 6.0), MARK_BIRTHDAY)
		if int(c["event"]) != SeasonalEvent.NONE:
			draw_rect(Rect2(cx + CELL_W * 0.5 - 3.0, cy + CELL_H - 8.0, 6.0, 5.0), MARK_EVENT)
		if int(c["theme"]) != Festival.NONE:
			if bool(c["theme_unlocked"]):
				draw_rect(Rect2(cx + CELL_W * 0.5 - 3.0, cy + CELL_H - 8.0, 6.0, 5.0), MARK_THEME)
			else:
				HanjiUi.draw_text(self, Vector2(cx + CELL_W * 0.5 - 3.0, cy + CELL_H - 3.0),
					"?", DAY_SIZE, MARK_LOCKED, -1.0, false)
	y += grid_h + 8.0
	for line in legs:
		y += LEG_SIZE + 3.0
		HanjiUi.draw_text(self, Vector2(x0, y), line, LEG_SIZE, Color(0.34, 0.26, 0.18), -1.0, false)

# ★[S8-T9 아트 패스] 생일 마커 ♥ — 절차 드로잉(에셋 0). 위 두 볼(원)과 아래 삼각을 겹쳐 폭 ~7px의
#   작은 하트를 만든다. 이 치수보다 크면 칸(CELL_W)을 물고 작으면 뭉개져 원과 구분이 안 된다.
#   center = 하트가 앉는 자리의 대략 한가운데(칸 하단 중앙 — 옛 원 마커와 같은 자리).
const HEART_LOBE_R := 2.0     # 위 두 볼 반지름
const HEART_LOBE_DX := 1.7    # 볼 중심의 좌우 벌어짐
const HEART_TIP_DY := 3.4     # 볼 중심선에서 아래 꼭짓점까지
func _draw_heart_mark(center: Vector2, col: Color) -> void:
	var ly := center.y - 1.2                      # 볼 중심선(하트는 위가 넓어 살짝 올려 앉힌다)
	draw_circle(Vector2(center.x - HEART_LOBE_DX, ly), HEART_LOBE_R, col)
	draw_circle(Vector2(center.x + HEART_LOBE_DX, ly), HEART_LOBE_R, col)
	var half := HEART_LOBE_DX + HEART_LOBE_R      # 볼 바깥 끝 = 삼각 윗변 반폭(실루엣이 이어진다)
	draw_colored_polygon(PackedVector2Array([
		Vector2(center.x - half, ly), Vector2(center.x + half, ly),
		Vector2(center.x, ly + HEART_TIP_DY)]), col)
