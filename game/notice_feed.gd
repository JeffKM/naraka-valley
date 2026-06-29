extends Control
class_name NoticeFeed
# Phase 2.7 C3 — 좌하단 알림 피드(일시 이벤트 큐, 스타듀식 미니멀 HUD).
#
# 목적: 흩어져 있던 상시 상태 라벨(저장됨·서빙·밤 매출·약탈·사연 한 줄 등)을 한 곳으로 모아,
#       "방금 무슨 일이 일어났나"를 좌하단에 잠깐 떴다 사라지는 큐로 보여 준다(상시 정보는
#       시계 클러스터·혼력 바·관계 탭이 들고, 이 피드는 *일시 이벤트*만 — ADR-0018 미니멀 HUD).
#
# 설계 메모:
#   - hotbar_hud.gd·lighting.gd와 같은 결: 코드 생성 자식 Control(무상태 — 표시용 휘발 큐만
#     들고 세이브 대상이 아니다). main._notice(...)가 push로 한 줄을 밀어 넣고, 나머지는 스스로
#     시간 경과로 흐려지며 사라진다(폴링·외부 상태 없음).
#   - 큐는 MAX_ITEMS로 잘려 화면을 넘치지 않는다(가장 오래된 것부터 밀려난다). 각 항목은 남은
#     시간(secs)이 끝나면 제거되고, 마지막 FADE_SECS 동안 알파가 줄어 부드럽게 사라진다.
#   - 부모 CanvasLayer가 UI scale(ADR-0018 ×1.5)을 먹으므로 보이는 영역은 size/scale(=640×360).
#     좌하단 기준점을 이 보이는 영역으로 잡는다(핫바·프레임과 같은 스케일 함정 회피).
#   - "버프 타이머"도 같은 자리(좌하단)를 공유하기로 예약됐다(C3 그레이박스 범위는 일시 알림까지 —
#     지속 버프는 Phase 3 활동 루프에서 이 피드에 timer 항목으로 얹는다).

const MAX_ITEMS := 4          # 동시에 보이는 최대 알림 수(넘으면 가장 오래된 것부터 제거)
const ROW_H := 22.0           # 한 줄 높이(px, 논리 좌표)
const MARGIN := 10.0          # 화면 왼쪽 여백
# 핫바(하단 중앙)·하단 프롬프트와 안 겹치게 피드를 그 위로 올린다(좌하단이되 하단 UI 위).
# 하단에서 RESERVE_BOTTOM만큼 띄운 자리가 가장 최근(맨 아래) 알림의 바닥이다.
const RESERVE_BOTTOM := 100.0
const MAX_W := 320.0          # 알림 띠 최대 폭(좌측 컬럼 유지 — 중앙 프롬프트 침범 방지)
const FADE_SECS := 0.6        # 사라지기 직전 알파가 줄어드는 구간(초)

# 표시 큐. 각 항목 = {text, secs}(secs=남은 표시 시간). 가장 최근이 배열 끝(아래에 그린다).
var _items: Array = []

# 알림 한 줄을 큐에 민다(main._notice가 호출). secs 후 자동으로 사라진다. 큐가 가득 차면
# 가장 오래된(앞) 항목을 밀어낸다 — 최신 이벤트가 항상 보이게.
func push(text: String, secs: float, wide: bool = false) -> void:
	if text == "":
		return
	# wide = 긴 안내(온보딩)용 — 좌측 컬럼(MAX_W) 대신 화면 폭 가까이 허용해 한 줄이 안 잘리게 한다.
	_items.append({"text": text, "secs": maxf(secs, 0.1), "wide": wide})
	while _items.size() > MAX_ITEMS:
		_items.pop_front()
	queue_redraw()

func _process(delta: float) -> void:
	if _items.is_empty():
		return
	# 각 항목의 남은 시간을 줄이고, 끝난 것은 제거한다. 살아 있는 항목이 있으면 매 프레임
	# 다시 그려(알파 페이드가 연속으로 흐르게) 한다.
	var any_alive := false
	for item in _items:
		item["secs"] -= delta
		if item["secs"] > 0.0:
			any_alive = true
	_items = _items.filter(func(it): return it["secs"] > 0.0)
	if any_alive or not _items.is_empty():
		queue_redraw()

# 부모 CanvasLayer scale을 되돌려 보이는 논리 영역(=640×360)을 얻는다(핫바와 동일).
func _view() -> Vector2:
	var sc := 1.0
	var par := get_parent()
	if par is CanvasLayer and par.scale.x != 0.0:
		sc = par.scale.x
	return Vector2(size.x / sc, size.y / sc)

func _draw() -> void:
	if _items.is_empty():
		return
	var view := _view()
	var font := ThemeDB.fallback_font
	# 좌하단: 가장 최근(배열 끝)을 맨 아래에, 오래된 것일수록 위로 쌓는다.
	var n := _items.size()
	for idx in n:
		var item: Dictionary = _items[idx]
		# 배열 끝(idx=n-1)이 맨 아래 줄(row 0). 하단 UI(핫바·프롬프트) 위로 RESERVE_BOTTOM만큼 띄운다.
		var row := (n - 1) - idx
		var y := view.y - RESERVE_BOTTOM - ROW_H * float(row + 1)
		var pos := Vector2(MARGIN, y)
		# 마지막 FADE_SECS 동안 서서히 흐려진다(그 전엔 불투명).
		var a := clampf(float(item["secs"]) / FADE_SECS, 0.0, 1.0)
		var text: String = item["text"]
		# 가독성: 반투명 배경 띠 + 흰 글자(밤 라이팅 위에서도 읽히게). 좌측 컬럼을 넘지 않게 폭 제한.
		# wide 항목(온보딩 안내)은 화면 폭 가까이 허용해 긴 한 줄이 안 잘리게 한다.
		var limit := (view.x - MARGIN * 2.0) if item.get("wide", false) else MAX_W
		var w := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0, limit)
		draw_rect(Rect2(pos, Vector2(w, ROW_H - 2.0)), Color(0.06, 0.05, 0.08, 0.66 * a))
		draw_string(font, pos + Vector2(8.0, 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, w - 12.0, 14, Color(0.96, 0.95, 0.92, a))
