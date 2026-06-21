extends SceneTree
# P2.3③ 밤 라이팅 단위검증(ephemeral) — lighting.gd의 색조·등불 곡선 계약을 헤드리스로
# 단언한다. cafe_test/night_bar_test와 같은 결의 하네스. 순수 함수(tint_for/lamp_energy_for)
# 라 트리에 안 붙이고 직접 호출한다.
# 실행: godot --headless --path game --script res://playtest/lighting_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _bright(c: Color) -> float:
	return (c.r + c.g + c.b) / 3.0

const NOON := 12 * 60     # 12:00 한낮
const DUSK := 18 * 60     # 18:00 황혼
const NIGHT := 22 * 60    # 22:00 밤
const MIDNIGHT := 24 * 60 # 24:00 쓰러짐
const OPEN := 19 * 60     # 19:00 밤 바 영업 시작
const PEAK := 21 * 60     # 21:00 등불 최대

func _initialize() -> void:
	print("══ P2.3③ lighting.gd 단위검증 ══")
	var L := DayNightLighting.new()

	# ── ① 색조: 한낮은 원색(백색), 밤은 어둡고 푸른 인디고 ──
	var noon := L.tint_for(NOON)
	_check("① 한낮(12:00)은 백색(원색 도트 그대로)", noon.is_equal_approx(Color(1, 1, 1)))
	var night := L.tint_for(MIDNIGHT)
	_check("② 자정은 한낮보다 확연히 어둡다", _bright(night) < 0.5)
	_check("②b 자정은 푸른 기운(파랑 > 빨강 — 저승 인디고)", night.b > night.r)

	# ── ③ 황혼은 따뜻한 앰버(빨강 > 파랑), 한낮↔밤 사이 밝기 ──
	var dusk := L.tint_for(DUSK)
	_check("③ 황혼(18:00)은 따뜻하다(빨강 > 파랑)", dusk.r > dusk.b)
	_check("③b 황혼은 한낮보다 어둡고 자정보다 밝다",
		_bright(dusk) < _bright(noon) and _bright(dusk) > _bright(night))

	# ── ④ 범위 밖은 끝값으로 고정(clamp) ──
	_check("④ 06:00 이전은 새벽값으로 고정", L.tint_for(0).is_equal_approx(L.tint_for(6 * 60)))
	_check("④b 24:00 이후는 자정값으로 고정", L.tint_for(30 * 60).is_equal_approx(night))

	# ── ⑤ 등불 세기: 한낮 꺼짐, 영업 시작에 켜짐, 21시 최대 ──
	_check("⑤ 한낮(12:00) 등불 꺼짐", is_equal_approx(L.lamp_energy_for(NOON), 0.0))
	_check("⑤b 밤 바 영업(19:00) 등불 켜짐", L.lamp_energy_for(OPEN) > 0.0)
	_check("⑤c 21:00 등불 최대(1.0)", is_equal_approx(L.lamp_energy_for(PEAK), 1.0))
	_check("⑤d 밤(22:00)은 등불 최대 유지", is_equal_approx(L.lamp_energy_for(NIGHT), 1.0))

	# ── ⑥ setup으로 등불 자리에 빛웅덩이가 생기고 apply가 세기를 흘려넣는다 ──
	var pts := PackedVector2Array([Vector2(100, 100), Vector2(200, 200)])
	L.setup(pts)
	L.apply(NOON)
	var lamps := L.get_children().filter(func(n): return n is PointLight2D)
	_check("⑥ 등불 2개 생성", lamps.size() == 2)
	_check("⑥b 한낮 apply 후 등불 세기 0", lamps.size() == 2 and is_equal_approx(lamps[0].energy, 0.0))
	L.apply(PEAK)
	_check("⑥c 21:00 apply 후 등불 세기 1.0", lamps.size() == 2 and is_equal_approx(lamps[0].energy, 1.0))

	L.free()
	print(("══ 통과 ══" if _fail == 0 else "══ 실패 %d건 ══" % _fail))
	quit(_fail)
