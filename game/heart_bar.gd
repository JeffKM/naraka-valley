class_name HeartBar
extends HBoxContainer
# P2.5② 호감도 하트 막대 — 이름 라벨 + 채운/빈 하트 스프라이트 5개 + 단계 수.
# affinity.heart_bar()의 ♥♡ 폰트 글리프를 스프라이트로 대체한다. 미호·멜·바나가
# 같은 틀을 재사용(affinity.gd 결) — main이 캐릭터별로 render(이름, 채운수, 총수)만 호출.

const FULL := preload("res://assets/ui/heart_full.png")
const EMPTY := preload("res://assets/ui/heart_empty.png")
const MAX_HEARTS := 5

var _name_label: Label
var _hearts: Array[TextureRect] = []
var _count: Label

func _ready() -> void:
	_build()

# 이름·하트5·카운트 슬롯을 한 번만 만든다. _ready와 render 양쪽에서 부르되 멱등 —
# render가 _ready보다 먼저 와도(헤드리스 테스트·첫 프레임) 슬롯이 보장된다.
func _build() -> void:
	if _name_label != null:
		return
	add_theme_constant_override("separation", 2)
	_name_label = Label.new()
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_name_label)
	for _i in MAX_HEARTS:
		var t := TextureRect.new()
		t.texture = EMPTY
		t.custom_minimum_size = Vector2(16, 16)
		t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		_hearts.append(t)
		add_child(t)
	_count = Label.new()
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_count)

# 캐릭터 이름 + 채운 하트 수로 막대를 갱신한다.
func render(label: String, filled: int, total: int) -> void:
	_build()
	_name_label.text = label
	for i in MAX_HEARTS:
		_hearts[i].texture = FULL if i < filled else EMPTY
	_count.text = "%d/%d" % [filled, total]
