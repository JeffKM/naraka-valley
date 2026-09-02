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
const RESERVE_BOTTOM := 124.0   # ★ Phase C — 좌하단 컨텍스트 팝업(핫바 위, top≈view.y-116) 위로 알림을 쌓는다
const MAX_W := 320.0          # 알림 띠 최대 폭(좌측 컬럼 유지 — 중앙 프롬프트 침범 방지)
const FADE_SECS := 0.6        # 사라지기 직전 알파가 줄어드는 구간(초)

# 표시 큐. 각 항목 = {text, secs}(secs=남은 표시 시간). 가장 최근이 배열 끝(아래에 그린다).
var _items: Array = []

# 알림 한 줄을 큐에 민다(main._notice가 호출). secs 후 자동으로 사라진다. 큐가 가득 차면
# 가장 오래된(앞) 항목을 밀어낸다 — 최신 이벤트가 항상 보이게.
# ★[폴리시 R11] `keep` = **밀려나면 다시 오지 않는 줄**(1회성 래치가 거는 알림). 큐가 가득 차면
#   여전히 가장 오래된 것부터 버리되 이 표가 붙은 줄은 건너뛴다. 왜 필요했나: 축출 규칙이 나이
#   하나뿐이라, 아침 정산처럼 한 프레임에 열 줄 넘게 미는 자리에서는 **한 프레임도 안 그려진 채
#   사라지는 줄**이 생겼다. 도감 완주 트로피(`codex.claim_trophy`가 세이브에 박는 영구 래치)가
#   그 예다 — 게잡이통·채취기·의뢰 만료·편지가 뒤이어 밀면 다섯째·여섯째 push에서 pop_front로
#   제거되고, 래치 때문에 영영 다시 뜨지 않는다.
#   ★ 큐가 MAX_ITEMS를 넘지 않는다는 계약은 그대로다: 버릴 만한 줄이 하나도 없으면(전부 keep)
#     그때만 맨 앞을 버린다 — 상한이 keep 때문에 무너지지 않는다.
func push(text: String, secs: float, wide: bool = false, icon: Texture2D = null, gold: bool = false,
		tint: Color = Color(0, 0, 0, 0), keep: bool = false) -> void:
	if text == "":
		return
	# wide = 긴 안내(온보딩)용 — 좌측 컬럼(MAX_W) 대신 화면 폭 가까이 허용해 한 줄이 안 잘리게 한다.
	# ★ Phase C — icon(아이템 획득 토스트의 좌측 아이콘)·gold(레벨업/숙련 알림 금박 강조)를 옵션으로 얹는다.
	# ★[S8-T9 아트 패스] tint = 글자 색 지정(알파 0 = 무틴트 = 종전 색). 선물 토스트가 tier(선호·
	#   좋아함·시큰둥·질색)를 색으로 먼저 말하는 데 쓴다 — 태그 문자열을 읽기 전에 결과가 도착한다.
	#   가법 옵션이라 기존 호출부(전부 5인자 이하)는 한 줄도 안 바뀐다.
	_items.append({"text": text, "secs": maxf(secs, 0.1), "wide": wide, "icon": icon, "gold": gold,
		"tint": tint, "keep": keep})
	while _items.size() > MAX_ITEMS:
		# 가장 오래된 것부터 훑되 keep은 건너뛴다. 방금 민 줄(배열 끝)은 후보에서 뺀다 —
		# "최신 이벤트가 항상 보이게"가 이 큐의 원래 계약이다.
		var victim := -1
		for i in _items.size() - 1:
			if not bool(_items[i].get("keep", false)):
				victim = i
				break
		_items.remove_at(victim if victim >= 0 else 0)
	queue_redraw()

func _process(delta: float) -> void:
	if _items.is_empty():
		return
	# 각 항목의 남은 시간을 줄이고, 끝난 것은 제거한다. 항목이 하나라도 있던 프레임이면 **무조건**
	# 다시 그린다(알파 페이드가 연속으로 흐르게 + 마지막 항목이 사라진 프레임의 지우기).
	# ★ 옛 조건("살아 있는 게 남았을 때만 redraw")은 큐가 비는 바로 그 프레임의 redraw를 건너뛰어,
	#   CanvasItem에 마지막으로 그려진 **반투명 알림 띠가 화면에 영구히 남았다**(CanvasItem은 다시
	#   그리기 전까지 옛 그리기 명령을 유지한다). 다음 알림이 올 때까지 안 지워져, 갱도 층처럼
	#   화면에 검은 여백이 있는 무대에서 "갱도 N층 …" 잔재가 또렷이 떠 있었다.
	for item in _items:
		item["secs"] -= delta
	_items = _items.filter(func(it): return it["secs"] > 0.0)
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
	var font := HanjiUi.font()   # ★ Phase C — 한지 톤 통일(neodgm)
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
		var icon: Texture2D = item.get("icon", null)
		var gold: bool = item.get("gold", false)
		# 아이콘(아이템 획득 토스트) 여백 — 있으면 좌측에 16px 아이콘 자리를 둔다.
		var icon_w := (ROW_H - 6.0) if icon != null else 0.0
		# 가독성: 어두운 인셋 띠 + 밝은 글자(밤 라이팅 위에서도 읽히게) + 따뜻한 테두리. 좌측 컬럼을 넘지 않게 폭 제한.
		# wide 항목(온보딩 안내)은 화면 폭 가까이 허용해 긴 한 줄이 안 잘리게 한다.
		var limit := (view.x - MARGIN * 2.0) if item.get("wide", false) else MAX_W
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var w := minf(tw + 16.0 + icon_w, limit)
		var box := Rect2(pos, Vector2(w, ROW_H - 2.0))
		# 인셋 바탕 + 테두리(레벨업은 금박, 그 외 따뜻한 테두리). 한지 팔레트로 raw 톤 제거.
		draw_rect(box, Color(HanjiUi.INSET.r, HanjiUi.INSET.g, HanjiUi.INSET.b, 0.72 * a))
		var edge := HanjiUi.GOLD if gold else HanjiUi.BORDER
		draw_rect(box, Color(edge.r, edge.g, edge.b, a), false, 1.0)
		var tx := pos.x + 8.0
		if icon != null:
			draw_texture_rect(icon, Rect2(pos + Vector2(5.0, 3.0), Vector2(ROW_H - 8.0, ROW_H - 8.0)),
				false, Color(1, 1, 1, a))
			tx += icon_w
		# 글자 색 — tint(알파>0)가 있으면 그 색, 없으면 종전(금박 or 한지 흰). gold 테두리는 그대로.
		var tint: Color = item.get("tint", Color(0, 0, 0, 0))
		var col := HanjiUi.GOLD_SOFT if gold else Color(0.96, 0.95, 0.92)
		if tint.a > 0.0:
			col = tint
		draw_string(font, Vector2(tx, pos.y + 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, w - 12.0 - icon_w, 14,
			Color(col.r, col.g, col.b, a))
