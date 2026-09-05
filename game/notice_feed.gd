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
# ★[폴리시 R24 #1] 스택이 **위로 넘지 못하는 선**. 종전엔 상한이 암묵적이었다 — 항목 높이가
#   ROW_H 고정이라 4줄 = 88px이 구조적 천장이었고, R23 #14가 «넘치면 접는다»로 바꾸면서 그 천장이
#   사라졌다(3줄짜리 띠 넷 = 264px > 예약 영역 236px). 넘친 띠는 화면 밖(y<0)으로 나가거나 상단
#   HUD 위에 겹쳐 섰다. 값의 출처는 main.tscn의 상단 라벨 스택 맨 아래(MilestoneLabel
#   offset_bottom = 72) — 그 아래부터가 이 피드가 써도 되는 공간이다(Readout 8..400 · ClockLabel
#   312..632 · GoldLabel 312..632 · MilestoneLabel 232..632이 전부 그 위에 산다).
const RESERVE_TOP := 72.0
const MAX_W := 320.0          # 알림 띠 최대 폭(좌측 컬럼 유지 — 중앙 프롬프트 침범 방지)

# ★[폴리시 R23 #14] 이 폭에서 접힌 뒤 몇 줄이 되나(그리기·높이 계산의 단일 출처).
#   ★ 줄 수를 폰트에서 재는 이유는 main `_mirror_body_height`가 적어 둔 그대로다 — 노드 내부
#     (`get_line_count`)는 shaping 시점에 의존하는데 폰트 측정은 같은 답을 즉시 준다.
func _wrapped_rows(font: Font, text: String, avail: float) -> int:
	if text == "" or avail <= 0.0:
		return 1
	var fh := font.get_height(14)
	if fh <= 0.0:
		return 1
	var wrapped := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, avail, 14)
	return maxi(1, int(round(wrapped.y / fh)))
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
		# ★[폴리시 R19 #6] 앞이 전부 keep이면 **방금 민 줄부터 본다** — 그 줄이 평범한 알림이면
		#   그것을 버린다. 종전 폴백은 곧장 `remove_at(0)`이라, 재발화 가능한 한 줄이 다시는 오지
		#   않을 줄을 축출했다(하루 전환 한 프레임에 밤 바 마감·도감 트로피·완공·혼례 아침이 keep
		#   4줄로 큐를 채우고, 뒤이은 출하 정산 한 줄이 밤 바 결산을 지웠다 — `abandon()`이 매출을
		#   이미 0으로 지운 뒤라 되뜰 경로가 없다). 유실 우선순위를 keep 계약대로 되돌린다.
		#   ★ 상한 계약은 그대로다: 새 줄까지 keep이면 여전히 맨 앞을 버린다(전부 keep인 불가피).
		if victim < 0 and not bool(_items[-1].get("keep", false)):
			victim = _items.size() - 1
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

# ★[폴리시 R24 #1] **스택 기하의 단일 출처.** `_draw`가 이 배열만 그리므로 "재는 값"과 "그리는
#   값"이 갈릴 자리가 없다(R23 #14가 폭에 대해 세운 그 규율을 높이·위치까지 넓힌 것).
#   반환 = 아래(최신)에서 위로 훑으며 **예약 영역 안에 들어간 항목만**, 각 원소 =
#   {idx, pos, w, h, rows, avail}(idx = `_items` 인덱스).
#   ★ 넘치는 항목은 **자르지도, 큐에서 버리지도 않는다** — 이 프레임에 그리지 않을 뿐이라
#     앞의 띠가 시간으로 사라지면 그대로 다시 선다(무손실). 큐 상한은 여전히 push의 MAX_ITEMS다.
#   ★ 최신 한 줄은 예약 영역보다 크더라도 반드시 선다 — "최신 이벤트가 항상 보이게"가 이 큐의
#     원래 계약이고, 그것까지 접으면 방금 벌어진 일을 말할 창구가 0이 된다.
func layout(font: Font, view: Vector2) -> Array:
	var out: Array = []
	var n := _items.size()
	var bottom := view.y - RESERVE_BOTTOM
	for idx in range(n - 1, -1, -1):
		var item: Dictionary = _items[idx]
		var icon: Texture2D = item.get("icon", null)
		var icon_w := (ROW_H - 6.0) if icon != null else 0.0
		var text: String = item["text"]
		var limit := (view.x - MARGIN * 2.0) if item.get("wide", false) else MAX_W
		var avail := limit - 16.0 - icon_w
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var w := minf(tw + 16.0 + icon_w, limit)
		var rows := _wrapped_rows(font, text, avail)
		var h := ROW_H * float(rows)
		if bottom - h < RESERVE_TOP and idx != n - 1:
			break                     # 예약 영역을 넘으면 여기서 멈춘다(더 오래된 것도 안 그린다)
		out.append({"idx": idx, "pos": Vector2(MARGIN, bottom - h), "w": w, "h": h,
			"rows": rows, "avail": avail})
		bottom -= h
	return out

func _draw() -> void:
	if _items.is_empty():
		return
	var view := _view()
	var font := HanjiUi.font()   # ★ Phase C — 한지 톤 통일(neodgm)
	# 좌하단: 가장 최근(배열 끝)을 맨 아래에, 오래된 것일수록 위로 쌓는다.
	# ★[폴리시 R23 #14] **바닥에서 위로 쌓되 줄 높이는 항목마다 다르다** — 접힌 줄 수만큼 띠가
	#   커지므로 `ROW_H × row`라는 고정 눈금을 못 쓴다. 최신(배열 끝)부터 역순으로 훑으며 바닥을
	#   깎아 올린다(가장 최근이 맨 아래라는 계약은 그대로다). ★[폴리시 R24 #1] 그 훑기 자체는
	#   `layout`이 든다 — 여기선 나온 자리에 색을 칠하기만 한다.
	for slot in layout(font, view):
		var idx: int = int(slot["idx"])
		var item: Dictionary = _items[idx]
		var pos: Vector2 = slot["pos"]
		# 마지막 FADE_SECS 동안 서서히 흐려진다(그 전엔 불투명).
		var a := clampf(float(item["secs"]) / FADE_SECS, 0.0, 1.0)
		var text: String = item["text"]
		var icon: Texture2D = item.get("icon", null)
		var gold: bool = item.get("gold", false)
		# 아이콘(아이템 획득 토스트) 여백 — 있으면 좌측에 16px 아이콘 자리를 둔다.
		var icon_w := (ROW_H - 6.0) if icon != null else 0.0
		# 가독성: 어두운 인셋 띠 + 밝은 글자(밤 라이팅 위에서도 읽히게) + 따뜻한 테두리. 좌측 컬럼을 넘지 않게 폭 제한.
		# wide 항목(온보딩 안내)은 화면 폭 가까이 허용해 긴 한 줄이 안 잘리게 한다.
		# ★[폴리시 R23 #14] **넘치면 접는다(잘라내지 않는다).** 종전엔 non-wide 항목의 실 그리기
		#   폭이 308px 고정이고 elide도 축소도 안 탔다 — main의 `_notice` 호출 393곳 중 wide는 셋
		#   뿐이라, 문자열 리터럴 330개 중 129개가 그 폭을 넘어 **꼬리가 통째로 사라졌다**. 하필
		#   잘리는 쪽이 «무엇을 하면 풀리는지»다: "백팩이 가득 차 <최장 아이템명> 거둘 수 없다 —
		#   [Tab] 가방에서 자리를 비우고 다시"(714px)는 「…레어크로우 ③ — 도롱이」에서 끊겨 문제도
		#   해법도 안 보였다. R14/R17의 폭 스윕은 `draw_text_fit`을 쓰는 판·헤더 계열만 훑었고 이
		#   피드는 대상 밖이었다(회귀 전체에 `MAX_W` 참조가 0이었다 = 아무도 안 재던 자리).
		#   ★ 접는 축을 줄바꿈으로 고른 근거: 이 띠의 문구는 전부 정보이고(무슨 일·왜·어떻게),
		#     말줄임은 하필 끝의 행동 지시를 먼저 먹는다. 폭은 그대로 두고 높이만 내용에서 판다.
		var avail: float = slot["avail"]
		var box := Rect2(pos, Vector2(float(slot["w"]), float(slot["h"]) - 2.0))
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
		# ★[폴리시 R23 #14] `draw_string`(한 줄·나머지 잘림) → `draw_multiline_string`(접힘).
		#   접는 폭은 **줄 수를 셀 때 쓴 그 폭**이라(avail) 재는 값과 그리는 값이 갈리지 않는다.
		draw_multiline_string(font, Vector2(tx, pos.y + 15.0), text, HORIZONTAL_ALIGNMENT_LEFT,
			avail, 14, -1, Color(col.r, col.g, col.b, a))
