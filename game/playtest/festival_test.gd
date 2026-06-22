extends SceneTree
# M2.4 — 카페 이벤트 데이(축제) 검증(ephemeral 헤드리스 단위검증).
# 특정 날(2주마다) 카페가 축제 무대가 되어 메인 4인(미호·멜·바나·옥자) 의상이 바뀌고
# 카페 내부가 축제 장식으로 바뀌며, 가벼운 보너스(손님 붐빔)가 얹히는지 본다.
#
# ★ 핵심 불변식:
#   ① 트리거(Festival) — day 14·28·42…만 이벤트 데이(2주 주기). 1·7·13·15는 평소(평평).
#      세이브 무상태 static 규칙(day에서 파생, store_discount 결).
#   ② 축제 보너스 = 손님 붐빔(spawn_scale 0.5) — *유입*만 키우고 *단가*(멜 마진)는 불침범
#      (ADR-0008 '활동 곱셈기' 아님). 평소 1.0(base rate, 평평≠막힘).
#   ③ 의상(set_festive) — 4인이 멱등 토글: festive on=TINT 틴트, off=WHITE 원복.
#   ④ main 통합 — _refresh_festival이 day에서 4인 의상·cafe.spawn_scale을 한 번에 맞춘다.
#   ⑤ 단가 불침범 — cafe.spawn_scale을 바꿔도 serve_price(멜 마진 축)는 불변.
#   ⑥ 세이브 무상태 — festive 키 없이 day만 복원되면 축제가 그대로 재개된다(껐다 켜도 그대로).
#   ⑦ 카페 축제 장식 _draw — 이벤트일 나루 마을에서 _draw가 크래시 없이 돈다(좌표·폴리곤 안전).
# 실행: godot --headless --path game --script res://playtest/festival_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000   # 안전 상한(좀비 방지)
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 4인 모두 festive가 기대값인지(의상 동기화 단언 헬퍼).
func _all_festive(m: Node, want: bool) -> bool:
	return m.miho.festive == want and m.mel.festive == want and m.bana.festive == want and m.okja.festive == want

func _initialize() -> void:
	print("══ M2.4 카페 이벤트 데이(축제) 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.m2_4_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	# 첫 인스턴스가 옛/오염 세이브로 부팅되지 않게 spawn 전에 지운다(interior_test 격리 교훈).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 트리거(Festival) — 순수 단위(인스턴스 불필요) ──
	print("── ① 트리거(2주 주기) ──")
	_check("①a CYCLE = 14(2주)", Festival.CYCLE == 14)
	_check("①b day 14·28·42 = 이벤트 데이", Festival.is_event_day(14) and Festival.is_event_day(28) and Festival.is_event_day(42))
	_check("①c day 1·7·13·15·27 = 평소", not Festival.is_event_day(1) and not Festival.is_event_day(7) and not Festival.is_event_day(13) and not Festival.is_event_day(15) and not Festival.is_event_day(27))
	_check("①d day 0·음수 = 평소(손상 방어)", not Festival.is_event_day(0) and not Festival.is_event_day(-14))

	# ── ② 축제 보너스 = 손님 붐빔(단가 불침범) ──
	print("── ② 보너스(spawn_scale) ──")
	_check("②a 이벤트일 spawn_scale 0.5(2배 붐빔)", is_equal_approx(Festival.spawn_scale(14), 0.5))
	_check("②b 평소 spawn_scale 1.0(base rate, 평평≠막힘)", is_equal_approx(Festival.spawn_scale(7), 1.0))
	_check("②c TINT ≠ WHITE(의상 틴트 존재)", Festival.TINT != Color.WHITE)

	# ── ③ 의상(set_festive) — 4인 멱등 토글 ──
	print("── ③ 의상 토글 ──")
	for maker in [Miho, Mel, Bana, Okja]:
		var c = maker.new()
		var nm: String = c.display_name()
		c._ready()   # _sprite 폴백 셋업(도색 있으면 스프라이트, 없으면 그레이박스 — 토글은 무관)
		var ok_init: bool = (c.festive == false and c.modulate == Color.WHITE)
		c.set_festive(true)
		var ok_on: bool = (c.festive == true and c.modulate == Festival.TINT)
		c.set_festive(true)   # 멱등 — 같은 값 재호출 무해
		var ok_idem: bool = (c.festive == true and c.modulate == Festival.TINT)
		c.set_festive(false)
		var ok_off: bool = (c.festive == false and c.modulate == Color.WHITE)
		_check("③ %s: 초기WHITE→on TINT→멱등→off WHITE" % nm, ok_init and ok_on and ok_idem and ok_off)
		c.free()

	var m: Node = await _spawn_main()

	# ── ④ main 통합 — _refresh_festival이 day에서 4인 의상·보너스를 맞춘다 ──
	print("── ④ main 통합 ──")
	m.clock.day = 14
	m._refresh_festival()
	_check("④a day14 → 4인 의상 축제(festive=true)", _all_festive(m, true))
	_check("④b day14 → cafe.spawn_scale 0.5", is_equal_approx(m.cafe.spawn_scale, 0.5))
	m.clock.day = 15
	m._refresh_festival()
	_check("④c day15 → 4인 평상복(festive=false)", _all_festive(m, false))
	_check("④d day15 → cafe.spawn_scale 1.0(base)", is_equal_approx(m.cafe.spawn_scale, 1.0))
	m.clock.day = 28
	m._refresh_festival()
	_check("④e day28(다음 주기) → 다시 축제", _all_festive(m, true) and is_equal_approx(m.cafe.spawn_scale, 0.5))

	# ── ⑤ 단가 불침범 — spawn_scale은 serve_price를 안 건드린다(멜 마진 축 격리) ──
	print("── ⑤ 단가 불침범(ADR-0008) ──")
	m.cafe.margin = 1.0
	var price_normal: int = m.cafe.serve_price()
	m.cafe.spawn_scale = 0.5   # 축제 붐빔이라도
	_check("⑤a spawn_scale 바꿔도 serve_price 불변(단가=멜 마진 축)", m.cafe.serve_price() == price_normal)
	m.cafe.margin = 2.0        # 단가는 오직 margin(멜 호감도)으로만 오른다
	_check("⑤b serve_price는 margin으로만 오른다", m.cafe.serve_price() > price_normal)

	# ── ⑥ 세이브 무상태 — day만 복원되면 축제가 그대로 재개(festive 키 없음) ──
	print("── ⑥ 세이브 무상태(재개) ──")
	m.clock.day = 14
	m._refresh_festival()
	m._save_game()
	var saved: Dictionary = m.saver.load_game()
	_check("⑥a 세이브에 festive/festival 키 없음(무상태)", not saved.has("festive") and not saved.has("festival"))
	m.queue_free()
	await process_frame
	await process_frame
	var m2: Node = await _spawn_main()
	_check("⑥b 재개 day=14(복원)", m2.clock.day == 14)
	_check("⑥c 재개하면 4인 축제 의상 그대로", _all_festive(m2, true))
	_check("⑥d 재개하면 cafe.spawn_scale 0.5 그대로", is_equal_approx(m2.cafe.spawn_scale, 0.5))

	# ── ⑦ 카페 축제 장식 _draw — 이벤트일 나루 마을에서 크래시 없이 돈다 ──
	print("── ⑦ 카페 축제 장식 _draw ──")
	m2.player.position = m2._tile_center_px(Vector2i(78, 32))   # ★C2 동쪽 길 워프 → 마을
	m2._maybe_warp_edge()
	await _settle(m2)
	_check("⑦pre 나루 마을로 워프", m2._region == RegionCatalog.NARU_VILLAGE)
	m2.clock.day = 14
	m2._refresh_festival()
	m2.queue_redraw()
	await process_frame
	await process_frame
	# 여기까지 예외 없이 도달하면 _draw_cafe_festival(좌표·draw_colored_polygon)이 안전히 돌았다.
	_check("⑦ 이벤트일 카페 _draw 크래시 없음(가랜드·카펫 좌표 안전)", true)
	m2.queue_free()
	await process_frame

	# ── 정리: 세이브 원복 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)
