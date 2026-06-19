extends SceneTree
# T5.4 임시 헤드리스 단위검증 — cafe.gd 계약을 게임 노드로 직접 검증한다(ephemeral).
# 실행: godot --headless --path game --script res://playtest/cafe_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_cafe() -> Cafe:
	var c := Cafe.new()
	c._ready()  # 트리에 안 붙이므로 좌석 초기화를 직접 부른다(테스트 하네스)
	return c

func _initialize() -> void:
	print("══ T5.4 cafe.gd 단위검증 ══")

	# ① 영업창 밖(아침)에서는 손님이 없다.
	var c := _new_cafe()
	c.tick(0.1, 6 * 60)
	_check("① 영업창 밖(06:00)엔 영업 안 함", not c.is_open() and not c.is_waiting(0))

	# ② 영업창(15–19시) 진입 → 영업 시작 + 손님 스폰(스폰 타이머 경과 후).
	c.tick(0.6, 16 * 60)        # 16:00, _spawn_timer 0.5 경과 → 첫 손님
	_check("② 15–19시 진입 시 영업 시작", c.is_open())
	_check("②b 곧 손님이 좌석에 앉음", c.is_waiting(0))

	# ③ 서빙 → 정액 P × margin(=1.0) 매출 + 좌석 비움 + 정산 누적.
	var rev := c.serve(0)
	_check("③ 서빙가 = BASE_PRICE × 1.0", rev == Cafe.BASE_PRICE)
	_check("③b 서빙 후 좌석 비움", not c.is_waiting(0))
	_check("③c 정산 누적(매출·인원)", c.today_revenue() == rev and c.today_served() == 1)

	# ④ 인내심 초과 → 손님 이탈(매출 +0, 벌칙 없음 → 무막힘). 이탈 직후 빈 자리는 다음
	#    스폰이 다시 채울 수 있으므로(실제 게임 동작), '좌석 빔'이 아니라 이탈 카운터로 본다.
	var d := _new_cafe()
	d.tick(0.6, 16 * 60)        # 손님 1명 착석
	_check("④pre 손님 착석", d.is_waiting(0))
	d.tick(Cafe.DEFAULT_PATIENCE + 1.0, 16 * 60)  # 인내심 초과만큼 시간 경과
	_check("④ 인내심 초과 시 이탈(이탈 카운트↑)", d.today_left() >= 1)
	_check("④b 이탈은 매출 0(무막힘)", d.today_revenue() == 0 and d.today_served() == 0)

	# ⑤ 영업 마감(19시 전이) → closed 시그널로 정산 요약을 쏜다. (람다는 지역변수를 값으로
	#    캡처하므로 재할당이 아니라 미리 만든 Dictionary를 '변경'해 결과를 밖으로 전달한다.)
	var e := _new_cafe()
	e.tick(0.6, 16 * 60)
	e.serve(0)
	var summary := {"fired": false}
	e.closed.connect(func(r, s, l):
		summary["fired"] = true; summary["r"] = r; summary["s"] = s; summary["l"] = l)
	e.tick(0.1, 19 * 60)        # 19:00 마감 전이
	_check("⑤ 마감 시 closed 정산 시그널 발화", summary["fired"])
	_check("⑤b 정산 매출/서빙 수 일치", summary.get("r", -1) == Cafe.BASE_PRICE and summary.get("s", -1) == 1)
	_check("⑤c 마감 후 영업 종료", not e.is_open())

	# ⑥ ★seam 2 — margin 분화: margin을 키우면 서빙가도 비례(T5.5 마진 얹힘 지점).
	var f := _new_cafe()
	f.margin = 2.0
	f.tick(0.6, 16 * 60)
	_check("⑥ margin=2.0 → 서빙가 2배(마진 seam)", f.serve(0) == Cafe.BASE_PRICE * 2)

	# ⑦ ★seam 1 — 인내심 파라미터: patience_secs를 키우면 손님이 더 오래 기다린다
	#    (Sprint 6 바나 응대 보호가 얹힐 지점). 기본 인내심으론 이탈할 시간에도 버틴다.
	var g := _new_cafe()
	g.patience_secs = Cafe.DEFAULT_PATIENCE * 2.0
	g.tick(0.6, 16 * 60)
	g.tick(Cafe.DEFAULT_PATIENCE + 1.0, 16 * 60)  # 기본값이라면 이탈했을 시간
	_check("⑦ 인내심 파라미터↑ → 더 오래 버팀(보호 seam)", g.is_waiting(0))

	# ⑧ end_day(취침) → 영업 중 상태를 조용히 리셋(요약 없이), 다음 영업창 정상 재개.
	var h := _new_cafe()
	h.tick(0.6, 16 * 60)
	h.end_day()
	_check("⑧ end_day 후 영업 종료·좌석 빔", not h.is_open() and not h.is_waiting(0))
	h.tick(0.6, 16 * 60)        # 다음 날 다시 15–19시
	_check("⑧b end_day 후 영업창 정상 재개", h.is_open() and h.is_waiting(0))

	for n in [c, d, e, f, g, h]:
		n.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
