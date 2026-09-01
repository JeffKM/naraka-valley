extends RefCounted
class_name HanjiUi
# ADR-0048 Phase C(S1-13) — 상시 HUD 공용 「태운 한지」 룩 헬퍼(즉시모드).
#
# 목적: Phase B(inv_frame.gd)의 9-slice·팔레트·neodgm 폰트를, 코드로 생성되는 HUD Control들
#       (시계·핫바·혼력·알림·툴팁·컨텍스트 팝업)이 한 곳에서 공유하게 뽑아낸다. 흩어진
#       raw draw_rect/ThemeDB.fallback_font를 한지 톤으로 통일해 "화면에 raw 패널 0"을 달성한다.
#
# 설계 메모:
#   - 상태 없는 정적 유틸(RefCounted, class_name). 어느 CanvasItem이든 첫 인자로 받아 그 _draw
#     안에서 즉시모드로 그린다(draw_* 는 대상 노드의 _draw 컨텍스트에서만 유효하므로 ci로 스레드).
#   - 9-slice·규격은 inv_frame._draw_nine과 동일 — hanji_frame 72² 테두리 22 / hanji_plate 40²
#     테두리 12(ADR-0025 박제). 같은 파일명·크기 Gemini 결과로 코드 무수정 덮어쓰기(ADR-0047).
#   - 팔레트는 Phase B inv_frame 톤 계승(따뜻한 먹빛·금박). 밝은 한지 위엔 INK(먹빛), 어두운
#     월드 위 떠 있는 HUD 글자엔 INK_LIGHT를 쓴다(대비).

const FRAME: Texture2D = preload("res://assets/ui/hanji_frame.png")
const PLATE: Texture2D = preload("res://assets/ui/hanji_plate.png")
const FRAME_MARGIN := 22.0
const PLATE_MARGIN := 12.0
const FONT: Font = preload("res://assets/fonts/neodgm.ttf")

# ── 팔레트(태운 한지) ─────────────────────────────────────────────────────────
const INK := Color(0.16, 0.12, 0.085)        # 먹빛 — 밝은 한지 배경 위 본문(대화 DLG_INK 톤)
const INK_LIGHT := Color(1.0, 0.97, 0.88)    # 밝은 글자 — 어두운 월드 위 떠 있는 HUD
const INK_DIM := Color(0.82, 0.76, 0.66)     # 보조 글자(설명·부제)
const GOLD := Color(0.90, 0.66, 0.28)        # 금박 강조 — 진행바 채움·핵심 수치
const GOLD_SOFT := Color(0.95, 0.88, 0.60)   # 밝은 금박 — 선택 테두리·강조 글자
const BORDER := Color(0.50, 0.42, 0.30)      # 따뜻한 테두리
const INSET := Color(0.14, 0.11, 0.08, 0.85) # 어두운 인셋 — 바 트랙·빈 슬롯 바탕

static func font() -> Font:
	return FONT

# 즉시모드 9-slice — 텍스처를 9칸(모서리 고정 · 변/중앙 신축)으로 rect에 그린다.
# inv_frame._draw_nine 이식(대상 노드를 ci로 받는 것만 다름).
# ★ owner 2026-07-03 HUD 가이드 — mod로 알파 낮춰(예: 0.82) 슬롯 배경 뒤 지형이 투과되게(시야 확보).
static func draw_nine(ci: CanvasItem, tex: Texture2D, rect: Rect2, m: float, mod: Color = Color.WHITE) -> void:
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var mx: float = minf(m, floorf(rect.size.x * 0.5))
	var my: float = minf(m, floorf(rect.size.y * 0.5))
	var sx := [0.0, m, tw - m]
	var sw := [m, tw - m * 2.0, m]
	var dx := [rect.position.x, rect.position.x + mx, rect.end.x - mx]
	var dw := [mx, rect.size.x - mx * 2.0, mx]
	var sy := [0.0, m, th - m]
	var sh := [m, th - m * 2.0, m]
	var dy := [rect.position.y, rect.position.y + my, rect.end.y - my]
	var dh := [my, rect.size.y - my * 2.0, my]
	for r in 3:
		for c in 3:
			ci.draw_texture_rect_region(tex,
				Rect2(dx[c], dy[r], dw[c], dh[r]),
				Rect2(sx[c], sy[r], sw[c], sh[r]), mod)

# 태운 한지 프레임(큰 패널·팝업 셸).
static func draw_frame(ci: CanvasItem, rect: Rect2) -> void:
	draw_nine(ci, FRAME, rect, FRAME_MARGIN)

# 태운 한지 판(슬롯·바·작은 위젯 바탕). alpha<1이면 뒤 지형이 투과(핫바 시야 확보).
static func draw_plate(ci: CanvasItem, rect: Rect2, alpha: float = 1.0) -> void:
	draw_nine(ci, PLATE, rect, PLATE_MARGIN, Color(1.0, 1.0, 1.0, alpha))

# 외곽선 두께(px) — 밝은 잔디·어두운 절벽 어디서든 글자가 칼같이 보이게(owner HUD 가이드 C).
const TEXT_OUTLINE := 4
const OUTLINE_COL := Color(0.05, 0.04, 0.03, 0.92)   # 단단한 먹빛 외곽선

# 한지 글자(neodgm). 좌상단이 아니라 baseline 기준이라, 호출부가 y에 폰트 높이를 더해 넘긴다.
# ★ owner 2026-07-03 — 검정 외곽선을 먼저 깔아 배경 무관 선명도 확보(픽셀 퍼펙트 가독).
static func draw_text(ci: CanvasItem, pos: Vector2, text: String, size: int, color: Color,
		max_w: float = -1.0, outline: bool = true) -> void:
	if outline:
		ci.draw_string_outline(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, max_w, size,
			TEXT_OUTLINE, OUTLINE_COL)
	ci.draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, max_w, size, color)

# 글자 폭(레이아웃 계산용).
static func text_width(text: String, size: int) -> float:
	return FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

# ── ★[폴리시] 글자 세로 치수·가변 길이 흡수 ──────────────────────────────────
# 왜 있나: `draw_text`가 **baseline** 기준이라 호출부가 "한 줄이 세로로 몇 px을 먹는가"를
# 폰트 크기(size)로 어림하고 있었다. 실제로는 baseline 아래로 descent가 더 내려가므로, 판 높이를
# size 합으로만 잡으면 막줄의 아랫배가 9-slice 테두리에 깔린다(시계 HUD 마일스톤 줄·달력 범례
# 막줄이 그렇게 잘려 있었다). 판 기하를 계산하는 쪽은 이 두 함수를 쓴다.
static func text_ascent(size: int) -> float:
	return FONT.get_ascent(size)

static func text_descent(size: int) -> float:
	return FONT.get_descent(size)

# 폭에 안 들어가는 꼬리를 잘라 말줄임(…)을 붙인다. 이미 들어가면 원문 그대로.
# ★ '…'(U+2026)은 neodgm.ttf **자체에 있는** 글리프다(♥처럼 폰트에 없어 두부가 되는 문자가
#   아니다 — calendar_panel의 ♥ 선례 참조). 곳간의 "…외 N종"이 이미 쓰고 있으므로 이건
#   "새 특수문자를 들이지 않는다"는 규약 안의 선택이다.
static func elide(text: String, size: int, max_w: float) -> String:
	if max_w <= 0.0 or text_width(text, size) <= max_w:
		return text
	var ell := "…"
	var ew := text_width(ell, size)
	if ew > max_w:
		return ""
	# 들어가는 최대 글자 수를 이분 탐색(한 글자씩 줄이면 긴 줄에서 폭 계산이 수십 번 돈다).
	var lo := 0
	var hi := text.length()
	while lo < hi:
		@warning_ignore("integer_division")
		var mid := (lo + hi + 1) / 2
		if text_width(text.substr(0, mid), size) + ew <= max_w:
			lo = mid
		else:
			hi = mid - 1
	return text.substr(0, lo).strip_edges(false, true) + ell

# 폭에 맞춰 **먼저 줄이고(글자 크기), 그래도 안 되면 자른다(말줄임)**. 가변 길이 한 줄
# (매대 헤더처럼 문구가 상태에 따라 길어지는 줄)의 기본 그리기.
static func draw_text_fit(ci: CanvasItem, pos: Vector2, text: String, size: int, color: Color,
		max_w: float, min_size: int = 10) -> void:
	var s := size
	while s > min_size and text_width(text, s) > max_w:
		s -= 1
	draw_text(ci, pos, elide(text, s, max_w), s, color, max_w)

# ── 한글 조사 — 앞말의 받침에 따라 갈리는 짝(을/를 · 이/가 · 은/는 · 과/와) ──
# 왜 한 곳에 모으나: 알림·프롬프트 문구는 대부분 `%s` 자리에 **런타임 이름**(아이템·수종·산출물·
# 사람)을 끼우는데, 그 이름의 받침은 문자열을 적는 쪽이 알 수 없다. 그래서 문구마다 조사를 고정해
# 두면 다른 이름이 들어오는 순간 틀리고("넋알돌를 깼다"·"명동 광석가 모자라다"), 병기로 피하면
# 문장이 딱딱해진다("%s 을(를)"). 판정은 여기 한 곳에만 둔다.
#
# 받침 판정 = 한글 음절의 (코드포인트 − 0xAC00) % 28 (0 = 받침 없음).
# ★ 한글이 아닌 끝글자(영문·숫자·기호)는 **받침 없는 쪽**으로 떨어진다 — 병기("을(를)")로 물러서지
#   않는 것이 이 헬퍼를 세운 이유고, 지금 카탈로그의 표시명은 전부 한글이라 실효 분기도 아니다.
static func _has_batchim(word: String) -> bool:
	if word.is_empty():
		return false
	var cp := word.unicode_at(word.length() - 1)
	if cp < 0xAC00 or cp > 0xD7A3:
		return false
	return (cp - 0xAC00) % 28 != 0

# 조사만 — 이름과 조사를 따로 그려야 하는 자리(inv_frame 확인 문구)가 쓴다.
static func josa_eul(word: String) -> String:
	return "을" if _has_batchim(word) else "를"

static func josa_i(word: String) -> String:
	return "이" if _has_batchim(word) else "가"

static func josa_eun(word: String) -> String:
	return "은" if _has_batchim(word) else "는"

static func josa_gwa(word: String) -> String:
	return "과" if _has_batchim(word) else "와"

# 이름 + 조사 — 문구 대부분이 쓰는 형태다. `"%s를 깼다" % name`을 `"%s 깼다" % with_eul(name)`으로
# 바꾸면 서식 인자 수가 그대로라(조사용 %s를 새로 끼우지 않는다) 호출부가 한 글자만 움직인다.
static func with_eul(word: String) -> String:
	return word + josa_eul(word)

static func with_i(word: String) -> String:
	return word + josa_i(word)

static func with_eun(word: String) -> String:
	return word + josa_eun(word)

static func with_gwa(word: String) -> String:
	return word + josa_gwa(word)
