extends Control
class_name OnboardingBanner
# ★ owner 2026-07-03 3차 HUD 가이드(A) — 온보딩/지역 안내를 상단-중앙 팝업 배너로.
#
# 목적: 옛 방식(온보딩 안내를 좌하단 notice_feed에 wide로 흘려 화면 폭 가까이 퍼진 날것 띠)을
#       걷어내고, 스타듀식 "잠깐 떴다 사라지는 미니 배너"로 바꾼다 — 태운 한지 플레이트에 외곽선
#       텍스트를 중앙정렬해 상단 중앙에 띄우고, 유지시간 뒤 부드럽게 페이드아웃.
#
# 설계 메모:
#   - clock_hud·notice_feed와 같은 결: 코드 생성 자식 Control(무상태 — 표시용 휘발값만). main이
#     show_guide(text)로 현재 안내를 밀어 넣고, 나머지(유지·페이드)는 스스로 시간으로 처리한다.
#   - 부모 CanvasLayer UI scale(×1.5)을 되돌린 보이는 영역(640×360) 상단 중앙에 배치(스케일 함정 회피).
#   - 페이드는 self.modulate.a로 통째 적용(플레이트+텍스트 함께) — _draw는 항상 불투명 기준으로 그린다.

const MARGIN_TOP := 12.0    # 화면 위 여백
const PAD_X := 12.0         # 플레이트 좌우 안쪽 여백
const PAD_Y := 7.0          # 플레이트 상하 안쪽 여백
const FONT_SIZE := 13       # 안내 글자 크기
const HOLD_SECS := 6.0      # 완전 불투명 유지 시간(초)
const FADE_SECS := 0.8      # 페이드아웃 구간(초)

var _text := ""             # 현재 안내 문구
var _secs := 0.0            # 남은 표시 시간(HOLD + FADE부터 카운트다운)

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	queue_redraw()

# main이 온보딩 단계가 바뀔 때 호출. 같은 문구면 타이머만 리셋(깜빡임 방지).
func show_guide(text: String) -> void:
	if text == "":
		return
	_text = text
	_secs = HOLD_SECS + FADE_SECS
	modulate.a = 1.0
	queue_redraw()

# 즉시 감춘다(대화가 화면을 채울 때 등).
func hide_now() -> void:
	_secs = 0.0
	modulate.a = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if _secs <= 0.0:
		return
	_secs -= delta
	# 마지막 FADE_SECS 동안 알파가 1→0으로 줄어든다(그 전엔 불투명).
	modulate.a = clampf(_secs / FADE_SECS, 0.0, 1.0)
	if _secs <= 0.0:
		_text = ""
	queue_redraw()

func _view() -> Vector2:
	var sc := 1.0
	var par := get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		sc = par.scale.x
	return Vector2(size.x / sc, size.y / sc)

func _draw() -> void:
	if _text == "" or modulate.a <= 0.0:
		return
	var view := _view()
	var tw := HanjiUi.text_width(_text, FONT_SIZE)
	var w := tw + PAD_X * 2.0
	var h := float(FONT_SIZE) + PAD_Y * 2.0
	var plate := Rect2((view.x - w) * 0.5, MARGIN_TOP, w, h)
	HanjiUi.draw_plate(self, plate)
	# 중앙정렬 안내 글자(금박 — 표제 톤, 외곽선으로 배경 무관 선명).
	var tx := plate.position.x + PAD_X
	var ty := plate.position.y + PAD_Y + float(FONT_SIZE) - 1.0
	HanjiUi.draw_text(self, Vector2(tx, ty), _text, FONT_SIZE, HanjiUi.GOLD_SOFT)
