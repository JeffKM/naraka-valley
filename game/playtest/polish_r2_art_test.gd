extends SceneTree
# ★[폴리시 2회차 · 시각/아트 배치] 헤드리스 배선 검증.
#
# s10_art_test와 **같은 결**이다: 그림의 예쁨이 아니라 **"폴백에 도달하지 않는다"**를 잰다.
# 육안은 덤프 하네스(s10_art_dump·mine_dump·woodshop_dump)가 맡고, 여기서는 이번 패스가 깐 훅이
# 실제로 그레이박스를 지웠는지, 그리고 **상태 드로우가 아트 뒤에 살아 있는지**를 기계로 못 박는다.
#
# 무엇을 보증하나:
#   ① 실내 창구 프롭 — 길드·목공방·혼백관·나락에 깐 훅 전부가 `_prop_tex`에서 텍스처를 돌려준다.
#   ② 카운터 폭 결합 — 응대 줄 폭(칸 수 × TILE)과 아트 폭이 **같다**. 어긋나면 드로우가 폴백으로
#      떨어지도록 짜 뒀으므로(늘어난 그림보다 옛 통짜 판이 낫다) 조용히 아트가 사라진다.
#      ★ 폭은 좌표 상수에서 **파생**한다(192 하드코딩 금지 — 응대 줄이 늘면 여기도 따라온다).
#   ③ 가구 세트 매대 아이콘 — 아트가 온 세트는 `_deco_icon`이 텍스처를 주고, **swatch 폴백은 전
#      행에 그대로 남아 있다**(아트가 온 세트만 갈아 끼워도 나머지가 안 깨진다는 것의 증명).
#   ④ 시련패 매대 이름 — 전 품목이 이름 칸 안에 **통째로** 든다(말줄임 미도달). 칸 폭·가격 블록
#      기하는 InventoryFrame 상수에서 파생한다(치수를 테스트에 옮겨 적지 않는다).
#   ⑤ ★상태를 아트에 굽지 않았다 — 아트 분기 뒤에 early return이 남으면 상태 드로우에 영영
#      도달하지 않는다(§24.10 ③ 물그릇 회귀의 형태). 이번에 훅을 새로 깐 세 자리를 소스로 잰다.
#   ⑥ 나락 봉인 고리 — 재사용 석재가 32² 심리스 규격이다(칸을 정확히 덮는다).
#
# 실행: ./run_tests.sh polish_r2_art   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

# 소스에서 함수 본문 한 덩이를 떼어 온다(s10_art_test ⑦과 같은 수법).
func _body(src: String, from_fn: String, to_fn: String) -> String:
	var i0 := src.find(from_fn)
	var i1 := src.find(to_fn)
	return src.substr(i0, i1 - i0) if i0 >= 0 and i1 > i0 else ""

func _initialize() -> void:
	print("══ 폴리시 2회차 아트 배선 검증(그레이박스 폴백 미도달 · 상태 드로우 생존) ══")
	var m := await _spawn_main()

	# ── ① 실내 창구 프롭 ────────────────────────────────────────────────────
	var prop_names: Array = [
		"guild_counter", "guild_weapon_rack",                      # 길드 실내
		"woodshop_counter", "woodshop_workbench", "woodshop_logs", "woodshop_workpiece",
		"museum_pedestal", "museum_donate_table",                  # 혼백관 진열
		"narak_shaft",                                             # 나락 하강 구멍
		"storage_chest",                                           # 집·갈무리방 저장 상자(한 장 공용)
	]
	var missing: Array = []
	for n in prop_names:
		if m._prop_tex(String(n)) == null:
			missing.append(String(n))
	_check("①a 전 프롭이 `_prop_tex`에서 텍스처를 돌려준다 %d종 (누락: %s)"
		% [prop_names.size(), str(missing)], missing.is_empty())
	for n in prop_names:
		_check("①b %s 프롭 아트 존재" % n, m._prop_tex(String(n)) != null)
	# 2×1칸 프롭은 폭 64 — 옆 칸을 침범하지도, 반 칸을 비우지도 않는다.
	for n in ["guild_weapon_rack", "woodshop_workbench", "woodshop_logs", "museum_donate_table"]:
		_check("①c %s 폭 = 2칸(%d)" % [n, int(m.TILE) * 2],
			m._prop_tex(String(n)).get_size().x == float(int(m.TILE) * 2))

	# ── ② 카운터 폭 = 응대 줄 폭(좌표 상수 파생) ────────────────────────────
	var gw: float = float(int(m.GUILD_COUNTER_X1) - int(m.GUILD_COUNTER_X0) + 1) * float(m.TILE)
	_check("②a 길드 카운터 아트 폭 == 응대 줄 %d칸(%dpx)"
		% [int(m.GUILD_COUNTER_X1) - int(m.GUILD_COUNTER_X0) + 1, int(gw)],
		m._prop_tex("guild_counter").get_size().x == gw)
	var ww: float = float(int(m.WOODSHOP_COUNTER_X1) - int(m.WOODSHOP_COUNTER_X0) + 1) * float(m.TILE)
	_check("②b 목공방 카운터 아트 폭 == 응대 줄 %d칸(%dpx)"
		% [int(m.WOODSHOP_COUNTER_X1) - int(m.WOODSHOP_COUNTER_X0) + 1, int(ww)],
		m._prop_tex("woodshop_counter").get_size().x == ww)
	for n in ["guild_counter", "woodshop_counter"]:
		_check("②c %s 높이 = 1칸(%d)" % [n, int(m.TILE)],
			m._prop_tex(String(n)).get_size().y == float(int(m.TILE)))

	# ── ③ 가구 세트 매대 아이콘 + swatch 폴백 생존 ──────────────────────────
	var sets: Array = HomeDecoCatalog.SETS.keys()
	_check("③a 가구 세트 로스터가 비어 있지 않다 (%d종)" % sets.size(), sets.size() > 0)
	var iconed: Array = []
	for sid in sets:
		if m._deco_icon(String(sid)) != null:
			iconed.append(String(sid))
	# 이번 패스가 아트를 놓은 두 세트는 반드시 아이콘이 선다(색박스 미도달).
	for sid in ["JAETNUN", "JEOSEUNGSOL"]:
		_check("③b %s 세트 아이콘 존재(흰 색박스 미도달)" % sid, m._deco_icon(sid) != null)
	_check("③c 아이콘이 선 세트 %s ⊆ 로스터" % str(iconed), iconed.size() <= sets.size())
	# ★ 폴백 생존 — 아트가 없는 세트도 매대에서 빈 네모가 아니라 대표색 한 칸을 받는다.
	m.trial.tokens = 30
	m._refresh_trial_shop()
	var deco_rows: Array = []
	for r in m.frame.store_items:
		if String(r.get("kind", "")) == TrialGround.SHOP_DECO:
			deco_rows.append(r)
	_check("③d 시련패 매대에 가구 세트 행이 선다 (%d행)" % deco_rows.size(), not deco_rows.is_empty())
	var no_swatch: Array = []
	for r in deco_rows:
		if not r.has("swatch"):
			no_swatch.append(String(r.get("buy_id", "?")))
	_check("③e 전 가구 행이 swatch 폴백을 그대로 들고 있다 (누락: %s)" % str(no_swatch),
		no_swatch.is_empty())
	var no_icon: Array = []
	for r in deco_rows:
		if r.get("icon_tex", null) == null:
			no_icon.append(String(r.get("buy_id", "?")))
	_check("③f 시련패 매대 가구 행에 아이콘이 붙었다 (아이콘 없음: %s)" % str(no_icon),
		no_icon.is_empty())

	# ── ④ 시련패 매대 이름이 통째로 든다(말줄임 미도달) ─────────────────────
	# `draw_text_fit`은 13px에서 시작해 하한(10px)까지 줄이고, 그래도 넘치면 자른다.
	# 그래서 "10px 폭 ≤ 이름 칸"이 곧 "잘리지 않는다"이다.
	var name_w: float = InventoryFrame.TRIAL_NAME_W
	var too_long: Array = []
	for r in m.frame.store_items:
		var nm := String(r.get("name", ""))
		if HanjiUi.text_width(nm, 10) > name_w:
			too_long.append(nm)
	_check("④a 전 품목명이 이름 칸(%dpx) 안에 든다 (넘침: %s)" % [int(name_w), str(too_long)],
		too_long.is_empty())
	# 구성 요소 명시 — 가장 긴 이름(레어크로우 ⑧)이 실제로 이 매대에 선다.
	var has_crow := false
	for r in m.frame.store_items:
		if String(r.get("kind", "")) == TrialGround.SHOP_RARECROW:
			has_crow = true
	_check("④b 레어크로우 행(가장 긴 이름)이 이 매대에 선다", has_crow)
	# ★ 가격 블록이 [구매] 버튼 밑으로 파고들지 않는다 — 칸을 넓힌 대가를 기하로 잰다.
	#   가용 폭 = 패널 폭 − 좌우 PAD − (아이콘+여백) − 버튼 자리.
	var panel_w: float = InventoryFrame.COLS * InventoryFrame.SLOT \
		+ (InventoryFrame.COLS - 1) * InventoryFrame.GAP \
		+ InventoryFrame.PAD * 2.0 + InventoryFrame.SCROLLBAR_W + 6.0
	var name_x: float = InventoryFrame.PAD + InventoryFrame.ROW_ICON + InventoryFrame.ROW_ICON_GAP
	var button_x: float = panel_w - InventoryFrame.PAD - InventoryFrame.ROW_BUY_INSET
	var max_price := 0
	for r in m.frame.store_items:
		max_price = maxi(max_price, int(r.get("price", 0)))
	var price_end: float = name_x + InventoryFrame.TRIAL_PRICE_DX \
		+ InventoryFrame.ROW_COIN_DX + HanjiUi.text_width(str(max_price), 13)
	_check("④c 가격 블록 끝(%.0f) < [구매] 버튼 시작(%.0f) — 최고가 %d패"
		% [price_end, button_x, max_price], price_end < button_x)
	# 엽전 매대(만물상)는 값이 네다섯 자리라 **좁은 칸**을 그대로 써야 한다(같은 기하로 재확인).
	var gold_end: float = name_x + InventoryFrame.STORE_PRICE_DX \
		+ InventoryFrame.ROW_COIN_DX + HanjiUi.text_width("12000", 13)
	_check("④d 엽전 매대 5자리 가격(%.0f)도 버튼(%.0f) 앞에서 끝난다" % [gold_end, button_x],
		gold_end < button_x)

	# ── ⑤ 상태 드로우가 아트 뒤에 살아 있다 ─────────────────────────────────
	var src := FileAccess.get_file_as_string("res://main.gd")
	# ㉠ 목공방 작업대 — 건축 중 작업물이 아트 뒤에서도 얹힌다.
	var ws := _body(src, "func _draw_woodshop_room", "func _draw_guild_room")
	_check("⑤a `_draw_woodshop_room` 본문을 읽었다", ws.length() > 0)
	_check("⑤b 작업물 상태 드로우(carpenter.is_active)가 본문에 살아 있다",
		ws.find("carpenter.is_active()") >= 0)
	var wb_at := ws.find("_prop_tex(\"woodshop_workbench\")")
	var act_at := ws.find("carpenter.is_active()")
	_check("⑤c 작업대 아트 분기와 상태 드로우 사이에 early return이 없다",
		wb_at >= 0 and act_at > wb_at and ws.substr(wb_at, act_at - wb_at).find("\t\treturn") < 0)
	# ㉡ 시련 게시판 — 걸린 쪽지·수락 도장이 판면 아트 뒤에서도 얹힌다.
	var tr := _body(src, "func _draw_trial_room", "func _draw_quest_board")
	_check("⑤d `_draw_trial_room` 본문을 읽었다", tr.length() > 0)
	_check("⑤e 쪽지 상태 드로우(_draw_pinned_note)가 본문에 살아 있다",
		tr.find("_draw_pinned_note") >= 0)
	var bd_at := tr.find("_prop_tex(\"trial_board\")")
	var note_at := tr.find("_draw_pinned_note")
	_check("⑤f 판면 아트 분기와 쪽지 드로우 사이에 early return이 없다",
		bd_at >= 0 and note_at > bd_at and tr.substr(bd_at, note_at - bd_at).find("\t\treturn") < 0)
	# ㉢ 혼백관 진열 — 좌대 아트 뒤에서도 "얹힌 것"(유품·레어크로우)이 원장 파생으로 그려진다.
	var mu := _body(src, "func _draw_museum_room", "func _on_frame_discard")
	_check("⑤g `_draw_museum_room` 본문을 읽었다", mu.length() > 0)
	var ped_at := mu.find("_prop_tex(\"museum_pedestal\")")
	var owned_at := mu.find("_rarecrow_owned(rid)")
	_check("⑤h 좌대 아트 분기와 진열 상태 드로우 사이에 early return이 없다",
		ped_at >= 0 and owned_at > ped_at and mu.substr(ped_at, owned_at - ped_at).find("\t\treturn") < 0)
	_check("⑤i 유품 전시가 원장(museum.is_donated) 파생으로 남아 있다",
		mu.find("museum.is_donated(sid)") >= 0)
	# 만물상 게시판도 같은 쪽지 함수를 쓴다(그림 하나를 두 게시판이 공유한다는 것의 증명).
	var qb := _body(src, "func _draw_quest_board", "func _draw_pinned_note")
	_check("⑤j 만물상 게시판도 `_draw_pinned_note`를 쓴다", qb.find("_draw_pinned_note") >= 0)

	# ㉣ 저장 상자 — 아트 뒤에서도 "보관 중" 표식이 뚜껑 위에 얹힌다.
	var ch := _body(src, "func _draw_chest_at", "func _draw_facade_village_houses")
	_check("⑤k `_draw_chest_at` 본문을 읽었다", ch.length() > 0)
	var ch_at := ch.find("_prop_tex(\"storage_chest\")")
	var box_at := ch.find("box_chest.is_empty()")
	_check("⑤l 상자 아트 분기와 보관 표식 사이에 early return이 없다",
		ch_at >= 0 and box_at > ch_at and ch.substr(ch_at, box_at - ch_at).find("\treturn") < 0)

	# ── ⑥ 나락 봉인 고리 석재 ───────────────────────────────────────────────
	_check("⑥a 고리 석재 = %d×%d (칸을 정확히 덮는 심리스 타일)" % [int(m.TILE), int(m.TILE)],
		m.NARAK_TEX_RING_STONE.get_size() == Vector2(float(int(m.TILE)), float(int(m.TILE))))
	_check("⑥b 고리 좌표(NARAK_ROCK_RECTS)가 8세그먼트 그대로다",
		m.NARAK_ROCK_RECTS.size() == 8)

	m.queue_free()
	await process_frame
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
