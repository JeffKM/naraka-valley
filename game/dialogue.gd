extends Node
class_name DialogueBox
# T3.2 — 대화 텍스트박스: 줄 단위 대사를 순서대로 넘긴다.
#
# 목적: "미호에게 말 걸면 텍스트박스가 뜨고 끝까지 넘기면 닫힌다"를 회색 박스+
#       텍스트만으로 검증한다(ADR-0001 그레이박스). 초상화 일러스트는 Phase 2.
#
# 설계 메모:
#   - energy.gd·wallet.gd와 같은 결: 이 노드는 "대사 진행"이라는 단일 책임만
#     가진다. 화면 표시(패널 Label)·입력 라우팅(말걸기·넘기기)·이동 잠금은
#     main.gd가 맡고, 여기서는 상태(현재 줄·열림 여부)와 시그널만 제공한다.
#   - 대화는 일시적 상태라 세이브하지 않는다(호감도는 T3.3에서 별도 노드가 진다).
#   - 대사 내용은 화자(miho.gd)가 들고 온다(ADR-0005: 서사 텍스트는 캐릭터에만).
#     DialogueBox는 누가 무슨 말을 하든 모르는 순수 진행기다 — 멜·바나도 같은 박스를 쓴다.

signal changed(speaker: String, line: String)  # 현재 줄이 바뀐 프레임(main이 패널 갱신)
signal finished()                                # 마지막 줄까지 넘겨 닫힘(이동 잠금 해제 훅)
# ★[S9-T1] 선택지가 화면에 서야 하는 순간(줄은 그대로 — main이 패널만 다시 그린다).
# changed와 나누는 이유: 같은 줄에 선택지가 붙는 경우까지 changed로 알리면 main의 대사 효과음이
# 한 줄에 두 번 난다. "줄이 바뀜"과 "선택지가 섬"은 다른 사건이라 시그널도 둘이다.
signal choice_shown()

var _speaker: String = ""
var _lines: PackedStringArray = PackedStringArray()
var _index: int = -1   # -1 = 닫힘. 0..n-1 = 현재 보여주는 줄.

# ── ★[S9-T1 / ADR-0067 결정 3·4] 선택지 문법 ───────────────────────────────
# 다지선다(2~4지) + 결과 콜백. 진행 중 대사의 특정 줄에 선택지가 서고, 고르면 콜백이 불린다.
#
# ★ **점수 배선이 없다**(결정 4 — 관문·이벤트 선택지는 전부 0점): 이 문법에는 호감도 인자도,
#   점수 시그널도 존재하지 않는다. 콜백은 *대사 교체·플래그* 전용이다. "선택 한 번으로 관계를
#   크게 잃는" 스타듀식 비대칭(−1500)은 비이식이며, 마이너스 채널은 기존 둘(혐오 선물·질투)뿐이다.
# ★ **기존 [F]/[G] 2타 래치(고백·이혼)는 이 문법을 쓰지 않는다**(결정 3 — 의도적 이중 존치).
#   신규 콘텐츠(S9-T4~ 절기 물음·관문 이벤트)만 여기로 온다. 두 문법의 공존은 S9b에서 재평가.
const CHOICE_MIN := 2   # 2지 미만은 선택이 아니다(그냥 다음 줄)
const CHOICE_MAX := 4   # 표시·입력(숫자키 1~4) 상한

var _choice_at: int = -1                                  # 선택지가 서는 줄 인덱스(-1 = 예약 없음)
var _choice_options: PackedStringArray = PackedStringArray()
var _choice_cb: Callable = Callable()                     # 결과 콜백(무효 = 그냥 진행)
# 대사 세대 — start·replace_lines·_close에서 증가한다. choose()가 "콜백이 흐름을 바꿨는가"를
# 이 값의 변화로만 판별한다(콜백이 대사를 갈아끼웠는데 그 위에 advance를 또 얹는 사고 방지).
var _seq: int = 0

# 대화 중인가(패널이 떠 있는가). main이 입력 라우팅·이동 잠금에 쓴다.
func is_open() -> bool:
	return _index >= 0

# 현재 줄이 마지막인가(다음에 넘기면 닫힘). UI에서 "다음/닫기" 안내를 가른다.
func is_last() -> bool:
	return is_open() and _index == _lines.size() - 1

# 대화를 시작한다. 이미 열렸거나 줄이 없으면 아무 일도 하지 않는다(잘못된 호출 방어).
# 성공 시 첫 줄로 changed를 발화한다.
func start(speaker: String, lines: PackedStringArray) -> void:
	if is_open() or lines.is_empty():
		return
	_speaker = speaker
	_lines = lines
	_index = 0
	_clear_choice()
	_seq += 1
	changed.emit(_speaker, _lines[_index])

# ★[S8-T6] 진행 중 대사를 통째로 교체한다(고백 [F] 분기 — 선택의 결과가 이 대화의 나머지가 된다).
# 화자는 유지한다. 빈 배열이면 그냥 닫는다(재구애의 조용한 진급 — 본 비트 재지급 없음, ADR-0022).
# 닫혀 있으면 아무 일도 하지 않는다(start와 같은 방어 — 선택 UI가 늦게 눌려도 안전).
func replace_lines(lines: PackedStringArray) -> void:
	if not is_open():
		return
	if lines.is_empty():
		_close()
		return
	_lines = lines
	_index = 0
	_clear_choice()   # 교체된 대사는 새 대사다 — 옛 줄에 걸어 둔 선택지 예약은 따라오지 않는다
	_seq += 1
	changed.emit(_speaker, _lines[_index])

# 다음 줄로 넘긴다. 마지막 줄에서 넘기면 닫히고 finished를 발화한다.
# 닫혀 있으면 아무 일도 하지 않는다(잘못된 입력 방어).
# ★[S9-T1] 선택지가 떠 있으면 넘기기로는 못 지나간다 — 고르는 것이 곧 진행이다(우클릭 연타로
#   선택을 건너뛰면 콜백이 통째로 유실된다). 선택 뒤엔 choose()가 대신 이 함수를 부른다.
func advance() -> void:
	if not is_open() or has_choice():
		return
	_index += 1
	if _index >= _lines.size():
		_close()
		return
	changed.emit(_speaker, _lines[_index])
	if _index == _choice_at:
		choice_shown.emit()   # 예약해 둔 줄에 도달 — 패널에 선택지가 선다

func _close() -> void:
	_index = -1
	_speaker = ""
	_lines = PackedStringArray()
	_clear_choice()
	_seq += 1
	finished.emit()

# ── 선택지 API(S9-T4~ 콘텐츠 워커가 쓰는 창구) ─────────────────────────────
# 지금 대화의 한 줄에 선택지를 예약한다. `at` 생략 = **마지막 줄**(질문 한 줄 + 선택지가 기본형).
# 반환 = 예약 성공 여부(닫힘·지선 수 위반·범위 밖 인덱스는 조용히 거부 — 대화가 못 닫히는
# 상태를 만들지 않기 위한 방어). 예약한 줄이 이미 떠 있으면 그 자리에서 choice_shown이 난다.
func queue_choice(options: PackedStringArray, on_choose: Callable = Callable(), at: int = -1) -> bool:
	if not is_open():
		return false
	if options.size() < CHOICE_MIN or options.size() > CHOICE_MAX:
		return false
	var idx: int = at if at >= 0 else _lines.size() - 1
	if idx < 0 or idx >= _lines.size():
		return false
	_choice_at = idx
	_choice_options = options
	_choice_cb = on_choose
	if _index == _choice_at:
		choice_shown.emit()
	return true

# 지금 선택지가 화면에 떠 있는가(= 예약한 줄에 도달했다). main이 입력 라우팅·패널 표기에 쓴다.
func has_choice() -> bool:
	return is_open() and _choice_at >= 0 and _index == _choice_at

# 표시할 선택지 목록(안 떠 있으면 빈 배열).
func choices() -> PackedStringArray:
	return _choice_options if has_choice() else PackedStringArray()

# idx번을 고른다(0-based). 콜백이 있으면 인덱스를 넘겨 부른다.
#   · 콜백이 대사를 갈아끼우거나(replace_lines) 대화를 닫았으면 거기서 끝이다.
#   · 콜백이 없거나 흐름을 안 바꿨으면 **다음 줄로 진행**한다(단순 톤 고르기 — 마지막 줄이면 닫힘).
# 선택지가 안 떠 있거나 범위 밖이면 무동작(늦게 눌린 입력 방어 — start·replace_lines와 같은 결).
func choose(idx: int) -> void:
	if not has_choice():
		return
	if idx < 0 or idx >= _choice_options.size():
		return
	var cb := _choice_cb
	_clear_choice()   # 콜백이 새 선택지를 예약할 수 있게 **먼저** 비운다
	var gen := _seq
	if cb.is_valid():
		cb.call(idx)
	if _seq == gen and is_open():
		advance()

func _clear_choice() -> void:
	_choice_at = -1
	_choice_options = PackedStringArray()
	_choice_cb = Callable()

# 현재 화자/줄(패널 렌더용). 닫혀 있으면 빈 문자열.
func speaker() -> String:
	return _speaker if is_open() else ""

func line() -> String:
	return _lines[_index] if is_open() else ""

# 진행 표시(예: "1/5"). UI에서 "더 있음/끝"을 한눈에 알린다. 닫혀 있으면 빈 문자열.
func progress() -> String:
	if not is_open():
		return ""
	return "%d/%d" % [_index + 1, _lines.size()]
