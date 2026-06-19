extends SceneTree
# T5.5 임시 헤드리스 단위검증 — cafe_margin.gd(멜 하트 → 서빙 단가 배수) 계약을 검증한다.
# 실행: godot --headless --path game --script res://playtest/cafe_margin_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _initialize() -> void:
	print("══ T5.5 cafe_margin.gd 단위검증 ══")

	# ① ROADMAP 앵커 정확 일치: ♡0 ×1.0 / ♡2 ×1.4 / ♡5 ×2.0.
	_check("① ♡0 → ×1.0 (base rate)", is_equal_approx(CafeMargin.margin(0), 1.0))
	_check("①b ♡2 → ×1.4", is_equal_approx(CafeMargin.margin(2), 1.4))
	_check("①c ♡5 → ×2.0", is_equal_approx(CafeMargin.margin(5), 2.0))

	# ② 곱셈기는 게이트가 아니라 base 위에 얹는다(ADR-0008): ♡0에서도 1.0이라 카페는
	#    굴러가고, 하트가 오르면 *단조 증가*한다(평평≠막힘, 관계=항상 우월한 가속).
	_check("② ♡0에서도 굴러감(≥1.0, 막힘 아님)", CafeMargin.margin(0) >= 1.0)
	var monotonic := true
	for h in range(1, CafeMargin.MAX_HEARTS + 1):
		if CafeMargin.margin(h) <= CafeMargin.margin(h - 1):
			monotonic = false
	_check("②b 하트가 오르면 배수 단조 증가", monotonic)

	# ③ 중간 하트도 선형식(1.0 + 0.2×h)을 따른다(앵커 사이가 한 직선 위).
	_check("③ ♡1 → ×1.2", is_equal_approx(CafeMargin.margin(1), 1.2))
	_check("③b ♡3 → ×1.6", is_equal_approx(CafeMargin.margin(3), 1.6))
	_check("③c ♡4 → ×1.8", is_equal_approx(CafeMargin.margin(4), 1.8))

	# ④ 범위 방어: 음수·상한 초과 하트는 [0, MAX]로 잘려 안전한 배수를 준다.
	_check("④ 음수 하트 → ♡0과 동일(×1.0)", is_equal_approx(CafeMargin.margin(-3), 1.0))
	_check("④b 상한 초과 → ♡MAX와 동일(×2.0)", is_equal_approx(CafeMargin.margin(99), 2.0))

	# ⑤ cafe.serve_price와의 연동: 주입된 margin이 정액 P에 그대로 곱해진다(end-to-end seam).
	var c := Cafe.new()
	c._ready()
	c.margin = CafeMargin.margin(5)            # 멜 ♡5 주입
	c.tick(0.6, 16 * 60)                        # 16:00 영업 + 손님 착석
	_check("⑤ ♡5 주입 시 서빙가 = P×2.0", c.serve_price() == int(round(Cafe.BASE_PRICE * 2.0)))
	_check("⑤b 실제 서빙 매출도 배수 반영", c.serve(0) == int(round(Cafe.BASE_PRICE * 2.0)))
	c.free()

	# ⑥ summary 문구: ♡0은 안내, ♡>0은 배수·증가율을 노출(체감 HUD용).
	_check("⑥ ♡0 summary는 안내 문구", CafeMargin.summary(0).contains("친해지면"))
	_check("⑥b ♡5 summary에 ×2.0·+100% 노출",
		CafeMargin.summary(5).contains("×2.0") and CafeMargin.summary(5).contains("+100%"))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
