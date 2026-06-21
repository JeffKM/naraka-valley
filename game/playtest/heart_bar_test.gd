extends SceneTree
# P2.5② HeartBar 단위검증(ephemeral) — render(이름, 채운수, 총수)가 슬롯별로 채운/빈
# 하트 텍스처를 올바르게 배정하는지 단언한다. TextureRect라 트리에 붙여야 _ready가 슬롯을
# 만든다(SceneTree.root 자식으로 추가). 실행:
#   godot --headless --path game --script res://playtest/heart_bar_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _filled_count(bar: HeartBar) -> int:
	var n := 0
	for t in bar._hearts:
		if t.texture == HeartBar.FULL:
			n += 1
	return n

func _initialize() -> void:
	print("══ P2.5② heart_bar.gd 단위검증 ══")
	var bar: HeartBar = load("res://heart_bar.tscn").instantiate()
	root.add_child(bar)
	bar._build()  # 헤드리스 _initialize에선 _ready 자동 호출 안 됨 → 명시 빌드(멱등)

	_check("① 슬롯 5개 생성", bar._hearts.size() == HeartBar.MAX_HEARTS)

	bar.render("미호", 3, 5)
	_check("②a 채운 하트 3개", _filled_count(bar) == 3)
	_check("②b 빈 하트 2개", _filled_count(bar) == 3 and bar._hearts[3].texture == HeartBar.EMPTY)
	_check("②c 이름 반영", bar._name_label.text == "미호")
	_check("②d 카운트 반영", bar._count.text == "3/5")

	bar.render("멜", 0, 5)
	_check("③ ♡0이면 채운 하트 0개(평평≠막힘 표기)", _filled_count(bar) == 0)

	bar.render("바나", 5, 5)
	_check("④ 만렙이면 채운 하트 5개", _filled_count(bar) == HeartBar.MAX_HEARTS)

	bar.render("미호", 9, 5)  # 손상 방어: 총수 초과 입력도 슬롯 수에서 멈춤
	_check("⑤ 슬롯 초과 입력은 5개에서 포화(인덱스 안전)", _filled_count(bar) == HeartBar.MAX_HEARTS)

	bar.queue_free()
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
