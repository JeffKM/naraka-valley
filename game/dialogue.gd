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

var _speaker: String = ""
var _lines: PackedStringArray = PackedStringArray()
var _index: int = -1   # -1 = 닫힘. 0..n-1 = 현재 보여주는 줄.

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
	changed.emit(_speaker, _lines[_index])

# 다음 줄로 넘긴다. 마지막 줄에서 넘기면 닫히고 finished를 발화한다.
# 닫혀 있으면 아무 일도 하지 않는다(잘못된 입력 방어).
func advance() -> void:
	if not is_open():
		return
	_index += 1
	if _index >= _lines.size():
		_close()
		return
	changed.emit(_speaker, _lines[_index])

func _close() -> void:
	_index = -1
	_speaker = ""
	_lines = PackedStringArray()
	finished.emit()

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
