extends SceneTree
# T6.3 임시 헤드리스 단위검증 — night_bar.gd 계약을 게임 노드로 직접 검증한다(ephemeral).
# cafe_test.gd와 같은 결의 단언 하네스. 핵심 검증: 잡귀는 *바를 연 밤(옵트인) 의 19–24시
# 창* 안에서만 등장하고(완료기준 "바를 열 때만"), 안 열거나 일찍 자면 손실 0·밤 매출 0이다.
# 실행: godot --headless --path game --script res://playtest/night_bar_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_bar() -> NightBar:
	var b := NightBar.new()
	b._ready()  # 트리에 안 붙이므로 스폿 초기화를 직접 부른다(테스트 하네스 — cafe_test와 동일)
	return b

const NIGHT := 20 * 60   # 20:00 — 밤 창(19–24시) 한복판
const DAY := 12 * 60     # 12:00 — 낮(밤 창 밖)

func _initialize() -> void:
	print("══ T6.3 night_bar.gd 단위검증 ══")

	# ── ① 옵트인 안 함: 밤 창(20:00) 안이어도 바를 안 열면 잡귀가 없다(빈 밤 — 매일 세금 X) ──
	var a := _new_bar()
	a.tick(5.0, NIGHT)
	_check("① 안 열면 밤 창 안에서도 잡귀 없음(빈 밤)", not a.is_opened() and a.threat_count() == 0)
	_check("①b 안 열면 활성 아님", not a.is_active())

	# ── ② 옵트인은 밤 창 안에서만 된다(낮엔 못 연다) ──
	var b := _new_bar()
	_check("② 낮(12:00)엔 바를 못 연다", not b.open_bar(DAY))
	_check("②b 낮에 연 시도는 옵트인 안 됨", not b.is_opened())
	_check("③ 밤 창(20:00)엔 바를 연다", b.open_bar(NIGHT))
	_check("③b 한 번 열면 옵트인 켜짐", b.is_opened())
	_check("③c 이미 열렸으면 재호출은 false(멱등)", not b.open_bar(NIGHT))

	# ── ④ 바를 연 뒤 밤 창에서 tick하면 잡귀가 깃든다(완료기준 "열 때만 등장") ──
	b.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)  # 첫 스폰 타이머 경과 → 첫 잡귀
	_check("④ 열고 밤 창에서 tick → 잡귀 등장", b.threat_count() >= 1 and b.is_threat(0))
	_check("④b 활성 상태", b.is_active())
	_check("④c 접근 바 잔량이 1 근처(막 등장)", b.approach_ratio(0) > 0.9)

	# ── ⑤ 잡귀 접근(approach) 소진 → 스폿을 비운다(despawn). ★seam: 지금은 약탈 없이 사라짐 ──
	#     (T6.4 막기가 여기에 "못 막으면 약탈"을 얹는다 — 지금은 _raided가 0으로 남는다)
	b.tick(NightBar.DEFAULT_APPROACH + 1.0, NIGHT)
	_check("⑤ 접근 소진 시 약탈 없이 사라짐(★seam) — 손실 0", b.tonight_raided() == 0)

	# ── ⑥ 열었어도 밤 창을 벗어나면(낮) 비활성 = 잡귀 안 깃듦 ──
	var c := _new_bar()
	c.open_bar(NIGHT)
	c.tick(0.1, DAY)  # 창 밖(낮)
	_check("⑥ 창 밖이면 열려 있어도 비활성", not c.is_active())

	# ── ⑦ end_day(취침): 바를 열었던 밤이면 정산 요약(closed, raided=0)을 쏘고 옵트인을 끈다 ──
	var d := _new_bar()
	d.open_bar(NIGHT)
	d.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)
	var summary := {"fired": false, "raided": -1}
	d.closed.connect(func(r): summary["fired"] = true; summary["raided"] = r)
	d.end_day()
	_check("⑦ 열었던 밤은 end_day가 정산 요약을 쏨", summary["fired"])
	_check("⑦b 자정 전 취침 시 약탈(손실) 0", summary["raided"] == 0)
	_check("⑦c end_day 후 옵트인 꺼짐(다음 밤은 새 선택)", not d.is_opened())
	_check("⑦d end_day 후 잡귀·활성 리셋", d.threat_count() == 0 and not d.is_active())

	# ── ⑧ 안 열고 자면 정산 요약조차 없다(빈 밤엔 정산할 것이 없음 — 옵트인 안 한 손실 0) ──
	var e := _new_bar()
	e.tick(5.0, NIGHT)  # 안 열고 밤을 보냄
	var fired := {"v": false}
	e.closed.connect(func(_r): fired["v"] = true)
	e.end_day()
	_check("⑧ 안 연 밤은 end_day가 요약을 안 쏨(빈 밤)", not fired["v"])

	# ── ⑨ end_day 후 다음 밤 정상 재개: 다시 열고 tick하면 잡귀가 또 깃든다(이월 없음) ──
	d.open_bar(NIGHT)
	d.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)
	_check("⑨ end_day 후 다음 밤 재개(다시 열면 잡귀 등장)", d.is_opened() and d.threat_count() >= 1)

	# ── ⑩ ★seam: approach_secs 파라미터를 키우면 잡귀가 더 천천히 닿는다(T6.5 바나 ㉠ 보호 자리) ──
	var f := _new_bar()
	f.approach_secs = NightBar.DEFAULT_APPROACH * 2.0
	f.open_bar(NIGHT)
	f.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)
	f.tick(NightBar.DEFAULT_APPROACH + 1.0, NIGHT)  # 기본값이라면 사라졌을 시간
	_check("⑩ 접근 파라미터↑ → 더 오래 버팀(보호 seam)", f.is_threat(0))

	# ── ⑪ is_window 게이트: 19시 경계 포함, 24시 경계 제외 ──
	var g := _new_bar()
	_check("⑪ 19:00은 밤 창(경계 포함)", g.is_window(NightBar.OPEN_MIN))
	_check("⑪b 24:00은 밤 창 아님(경계 제외 — 강제 취침)", not g.is_window(NightBar.CLOSE_MIN))
	_check("⑪c 낮(12:00)은 밤 창 아님", not g.is_window(DAY))

	for n in [a, b, c, d, e, f, g]:
		n.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
