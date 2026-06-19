extends SceneTree
# T6.3/T6.4/T6.5 임시 헤드리스 단위검증 — night_bar.gd 계약을 게임 노드로 직접 검증한다(ephemeral).
# cafe_test.gd와 같은 결의 단언 하네스. 핵심 검증:
#  · T6.3: 잡귀는 *바를 연 밤(옵트인) 의 19–24시 창* 안에서만 등장하고, 안 열거나 일찍 자면
#    손실 0·밤 매출 0이다.
#  · T6.4: 막기(접근→block→격퇴 즉시 판정, 막기 해소 계약 {repelled, raided}) · 막기 실패→
#    재고 약탈(돌파 시 _raided += raid_amount + resolved 발화) · 밤 손님 응대(serve→밤 매출) ·
#    응대 실패→이탈(인내심 0→_left) · 이중 손실 분리 · 보호 seam(approach/patience/raid_amount).
#  · T6.5: 바나 ㉠ 자동 차단(auto_block) — 못 막은 돌파를 바나가 N마리까지 대신 막아 약탈 0,
#    소진 후 재약탈, ♡0(기본 0)이면 잠듦, end_day 리셋. (raid_amount↓·patience↑ seam은 위
#    ⑮·⑱에서, 하트→보호 매핑은 bana_test.gd가 검증.)
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
	print("══ T6.3/T6.4/T6.5 night_bar.gd 단위검증 ══")

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

	# ── ⑤ 잡귀 접근(approach) 소진 → 막지 못하면 재고 약탈(T6.4가 ★seam을 채움) ──
	#     (T6.3에선 약탈 없이 사라졌으나, T6.4 막기 실패→약탈이 여기에 얹혔다 — 자세한 돌파/
	#      막기 분기는 아래 ⑬·⑭에서 검증. 여기선 "안 막으면 손실이 난다"만 확인.)
	b.tick(NightBar.DEFAULT_APPROACH + 1.0, NIGHT)
	_check("⑤ 접근 소진까지 안 막으면 재고 약탈(★seam 채움)", b.tonight_raided() == NightBar.DEFAULT_RAID)

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
	d.closed.connect(func(r, _rev, _lft): summary["fired"] = true; summary["raided"] = r)
	d.end_day()
	_check("⑦ 열었던 밤은 end_day가 정산 요약을 쏨", summary["fired"])
	_check("⑦b 자정 전 취침 시 약탈(손실) 0", summary["raided"] == 0)
	_check("⑦c end_day 후 옵트인 꺼짐(다음 밤은 새 선택)", not d.is_opened())
	_check("⑦d end_day 후 잡귀·활성 리셋", d.threat_count() == 0 and not d.is_active())

	# ── ⑧ 안 열고 자면 정산 요약조차 없다(빈 밤엔 정산할 것이 없음 — 옵트인 안 한 손실 0) ──
	var e := _new_bar()
	e.tick(5.0, NIGHT)  # 안 열고 밤을 보냄
	var fired := {"v": false}
	e.closed.connect(func(_r, _rev, _lft): fired["v"] = true)
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

	# ══════════════ T6.4 — 막기 + 막기↔응대 경쟁 + 이중 손실 ══════════════

	# ── ⑫ 막기(block): 잡귀를 깃들이고 block → 막기 해소 계약 {repelled:true, raided:0}, 즉시 격퇴 ──
	var h := _new_bar()
	h.open_bar(NIGHT)
	h.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)  # 잡귀 0 등장(접근 잔량 가득)
	var events: Array = []
	h.resolved.connect(func(r): events.append(r))
	var res: Dictionary = h.block(0)
	_check("⑫ block은 격퇴 성공 계약을 돌려준다", res["repelled"] == true and res["raided"] == 0)
	_check("⑫b 막은 스폿의 잡귀는 사라진다", not h.is_threat(0))
	_check("⑫c 격퇴도 resolved를 쏜다(다운스트림 계약 일관)", events.size() == 1 and events[0]["repelled"])
	# ⑫d 막을 잡귀 없는 스폿 block은 헛 호출 방어({repelled:false, raided:0})
	var empty: Dictionary = h.block(0)
	_check("⑫d 빈 스폿 block은 헛 호출({repelled:false,raided:0})", not empty["repelled"] and empty["raided"] == 0)

	# ── ⑬ 막기 실패 → 재고 약탈(돌파): 접근 소진까지 안 막으면 _raided += raid_amount + resolved 발화 ──
	var k := _new_bar()
	k.open_bar(NIGHT)
	k.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)  # 잡귀 등장
	var raids: Array = []
	k.resolved.connect(func(r): raids.append(r))
	k.tick(NightBar.DEFAULT_APPROACH + 1.0, NIGHT)  # 안 막고 접근 소진 → 돌파(약탈)
	_check("⑬ 돌파 시 약탈량이 _raided에 쌓인다", k.tonight_raided() == NightBar.DEFAULT_RAID)
	var had_breakthrough := raids.any(func(r): return not r["repelled"] and r["raided"] == NightBar.DEFAULT_RAID)
	_check("⑬b 돌파는 막기 실패 계약 {repelled:false, raided>0}을 쏜다", had_breakthrough)

	# ── ⑭ 막으면 약탈이 안 일어난다(접근 소진 전에 block → 손실 0) ──
	var l := _new_bar()
	l.open_bar(NIGHT)
	l.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)
	l.block(0)                                    # 접근 소진 전에 격퇴
	l.tick(NightBar.DEFAULT_APPROACH + 1.0, NIGHT)  # 막았으니 이 스폿은 돌파 안 함
	_check("⑭ 제때 막으면 그 잡귀 약탈은 0", l.tonight_raided() == 0)

	# ── ⑮ raid_amount seam(★㉠): 약탈량을 키우면 돌파당 그만큼 약탈(T6.5 바나 보호가 줄임) ──
	var n_bar := _new_bar()
	n_bar.raid_amount = 3
	n_bar.open_bar(NIGHT)
	n_bar.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)
	n_bar.tick(NightBar.DEFAULT_APPROACH + 1.0, NIGHT)
	_check("⑮ raid_amount↑ → 돌파당 약탈량↑(★㉠ seam)", n_bar.tonight_raided() == 3)

	# ── ⑯ 응대(serve): 바 손님이 앉고 serve → 정액 밤 매출, 좌석 비움(재료 무소모) ──
	var o := _new_bar()
	o.open_bar(NIGHT)
	o.tick(NightBar.CUST_INTERVAL + 0.1, NIGHT)   # 손님 0 착석
	_check("⑯ 열고 tick → 바 손님 등장", o.customer_count() >= 1 and o.is_waiting(0))
	var earned := o.serve(0)
	_check("⑯b serve는 정액 밤 매출을 돌려준다", earned == NightBar.SERVE_PRICE)
	_check("⑯c 응대한 좌석은 비고 매출이 누적된다", not o.is_waiting(0) and o.tonight_revenue() == NightBar.SERVE_PRICE)
	_check("⑯d 빈 좌석 serve는 0(헛 호출 방어)", o.serve(0) == 0)

	# ── ⑰ 응대 실패 → 이탈(인내심 0): 안 받으면 손님이 떠난다(_left, 벌칙 없음 → 무막힘) ──
	var q := _new_bar()
	q.open_bar(NIGHT)
	q.tick(NightBar.CUST_INTERVAL + 0.1, NIGHT)   # 손님 착석
	q.tick(NightBar.DEFAULT_PATIENCE + 1.0, NIGHT)  # 안 받고 인내심 소진 → 이탈
	_check("⑰ 인내심 소진 손님은 이탈한다(_left↑)", q.tonight_left() >= 1)
	_check("⑰b 이탈해도 밤 매출은 0(벌칙 없음 — 무막힘)", q.tonight_revenue() == 0)

	# ── ⑱ patience_secs seam(★㉡): 인내심을 키우면 더 오래 버틴다(T6.5 바나 응대 보호 자리) ──
	var r2 := _new_bar()
	r2.patience_secs = NightBar.DEFAULT_PATIENCE * 2.0
	r2.open_bar(NIGHT)
	r2.tick(NightBar.CUST_INTERVAL + 0.1, NIGHT)
	r2.tick(NightBar.DEFAULT_PATIENCE + 1.0, NIGHT)  # 기본값이라면 떠났을 시간
	_check("⑱ 인내심 파라미터↑ → 손님이 더 오래 버팀(★㉡ seam)", r2.is_waiting(0))

	# ── ⑲ 이중 손실 분리: 약탈(재고/미래)과 이탈(매출/현재)은 서로 독립 누적 + end_day가 셋 다 정산 ──
	var s2 := _new_bar()
	s2.open_bar(NIGHT)
	s2.tick(NightBar.CUST_INTERVAL + 0.1, NIGHT)   # 손님 착석
	var served := s2.serve(0)                       # 한 명 응대(매출)
	s2.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)  # 잡귀 등장
	s2.tick(NightBar.DEFAULT_APPROACH + 1.0, NIGHT)  # 안 막아 약탈 + (남은 손님 이탈)
	var night := {"raided": -1, "revenue": -1, "left": -1}
	s2.closed.connect(func(rd, rv, lf): night["raided"] = rd; night["revenue"] = rv; night["left"] = lf)
	s2.end_day()
	_check("⑲ end_day 정산이 약탈·밤 매출·이탈을 함께 싣는다",
		night["raided"] == NightBar.DEFAULT_RAID and night["revenue"] == served and night["left"] >= 1)

	# ══════════════ T6.5 — 바나 ㉠ 자동 차단(auto_block seam) ══════════════

	# ── ⑳ auto_block seam: 못 막은 돌파를 바나가 대신 막아 약탈 0(여우불 '범위'의 밤판) ──
	var t := _new_bar()
	t.auto_block = 1
	t.open_bar(NIGHT)
	var ev: Array = []
	t.resolved.connect(func(r): ev.append(r))
	t.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)       # 잡귀 등장
	t.tick(NightBar.DEFAULT_APPROACH + 1.0, NIGHT)     # 안 막아 돌파 → 바나 자동 차단
	_check("⑳ 자동 차단 시 약탈 0(바나가 대신 막음)", t.tonight_raided() == 0)
	_check("⑳b 자동 차단 수가 누적된다", t.tonight_auto_blocked() == 1)
	var auto_ev := ev.any(func(r): return r.get("auto", false) and r["repelled"] and r["raided"] == 0)
	_check("⑳c 자동 차단도 막기 해소 계약을 쏜다({repelled:true,auto:true})", auto_ev)

	# ── ㉑ 자동 차단 소진 후엔 다시 약탈된다(밤당 N마리까지만 받쳐줌) ──
	var u := _new_bar()
	u.auto_block = 1
	u.raid_amount = 2
	u.open_bar(NIGHT)
	u.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)       # 잡귀 등장
	u.tick(NightBar.DEFAULT_APPROACH + 1.0, NIGHT)     # 1차 돌파 → 자동 차단(약탈 0) + 새 잡귀 스폰
	_check("㉑ 1차 돌파는 자동 차단(약탈 0)", u.tonight_raided() == 0 and u.tonight_auto_blocked() == 1)
	u.tick(NightBar.DEFAULT_APPROACH + 1.0, NIGHT)     # 2차 돌파 → 차단 소진 → 약탈
	_check("㉑b 차단 소진 후 2차 돌파는 약탈된다", u.tonight_raided() == 2)

	# ── ㉒ auto_block 기본 0(♡0 base = 바나 잠듦)이면 첫 돌파부터 약탈(평평≠막힘) ──
	var v2 := _new_bar()
	v2.open_bar(NIGHT)
	v2.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)
	v2.tick(NightBar.DEFAULT_APPROACH + 1.0, NIGHT)
	_check("㉒ auto_block 기본 0이면 첫 돌파부터 약탈(바나 잠듦)",
		v2.tonight_raided() == NightBar.DEFAULT_RAID and v2.tonight_auto_blocked() == 0)

	# ── ㉓ end_day가 자동 차단 카운터·잔량도 리셋한다(다음 밤 깨끗이 재개) ──
	var w := _new_bar()
	w.auto_block = 2
	w.open_bar(NIGHT)
	w.tick(NightBar.SPAWN_INTERVAL + 0.1, NIGHT)
	w.tick(NightBar.DEFAULT_APPROACH + 1.0, NIGHT)
	w.end_day()
	_check("㉓ end_day가 자동 차단 카운터·잔량 리셋", w.tonight_auto_blocked() == 0 and w.auto_blocks_left() == 0)

	for n in [a, b, c, d, e, f, g, h, k, l, n_bar, o, q, r2, s2, t, u, v2, w]:
		n.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
