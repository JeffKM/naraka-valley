extends SceneTree
# ★[S6-T8 / ADR-0064 아트 스코프] 카페 아트 패스 1 육안 덤프(비-headless) — cafe_larder_dump 확장판.
#   ① 카페 실내 낮 — 곳간 찬장·출하함 궤짝 프롭 + 좌석 5석(명명 손님 시트 · 익명 손님 상) +
#      주문 말풍선 메뉴 아이콘 + 단골 등불 표식
#   ② 곳간 패널(CTX_LARDER) — 재고 행의 "재료 → 융합 메뉴 아이콘" 한 줄
#   ③ 인벤 백팩 — 곁들이 메뉴 5종이 색박스가 아니라 접시로 뜨는지
#   ④ 체키 HUD(카메라 배지) / ⑤ 칵테일 HUD(셰이커 배지)
#   ⑥ 밤 바 — 익명 손님 상 + 잡귀 도트(MOB_TEX 재사용)
#
# ★[S6-T9] 아트 패스 2도 **이 하네스를 무수정으로 쓴다**: 주방요괴 시트는 ①의 직원 줄(KITCHEN_TILE
#   = 곳간 옆)에, 늘어난 익명 손님 8상은 ①⑥의 좌석에 그대로 뜬다. 새 판정면을 만들 이유가 없다 —
#   같은 장면에서 함께 봐야 "새것만 톤이 튄다"가 보인다(계수 정합이 이 패스들의 핵심 판정이다).
#
# ⚠️ 화면 grab이라 **골든 비교에 못 쓴다**(육안 전용 — [S5-T10] 교훈). 바이트 골든이 필요하면
#    오프라인 합성 덤프(tools/*_dump.gd)를 쓸 것.
# ★ --headless 없이: godot --path game --script res://playtest/s6_art_dump.gd

func _read(p: String) -> PackedByteArray:
	var f := FileAccess.open(p, FileAccess.READ); var b := f.get_buffer(f.get_length()); f.close(); return b
func _write(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(b); f.close()

func _grab(name: String) -> void:
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/%s.png" % name)
	print("saved /tmp/%s.png" % name)

# 좌석 하나를 직접 앉힌다(스폰 롤을 기다리지 않고 원하는 손님·메뉴를 세우려고 — 하네스 전용).
func _seat(m: Node, i: int, guest_id: String, menu_id: String, patience: float) -> void:
	var s: Dictionary = m.cafe._seats[i]
	s["occupied"] = true
	s["patience"] = patience
	s["max_patience"] = m.cafe.patience_secs
	s["want"] = menu_id
	s["guest"] = guest_id

func _initialize() -> void:
	root.size = Vector2i(960, 540)
	var sp := SaveManager.slot_path(0)
	var bak := _read(sp) if FileAccess.file_exists(sp) else PackedByteArray()
	var had := FileAccess.file_exists(sp)

	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	for i in 8:
		await process_frame
	m.onboarding.notice_seen()
	m.dialogue._close()
	await process_frame

	# ── ① 카페 실내(낮) ─────────────────────────────────────────────────────
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	await create_timer(2.0).timeout
	m.larder.add(CropCatalog.PIANHWA, 6)
	m.larder.add(CropCatalog.HONRYEONGCHO, 4)
	m.larder.add(ItemCatalog.NEOK_SONGI, 3)
	m.larder.add(ItemCatalog.NARAK_HONJEONG, 1)
	m._indoor = "카페"
	m.player.position = m._tile_center_px(m.CAFE_IN_TILE)
	m._apply_camera_limits()
	# 좌석 5석: 명명 3(그중 하나는 단골 = 등불 표식) + 익명 2
	m.cafe.open_seats = Cafe.SEATS_STAGE2
	m.cafe._open = true
	for k in 4:
		m.guests.record_serve("mochi")     # 모찌를 단골로(REGULAR_AT=3 넘김)
	_seat(m, 0, "mochi", MenuCatalog.PIANHWA_ADE, 6.5)
	_seat(m, 1, "neo", MenuCatalog.HONRYEONGCHO_LATTE, 4.0)
	_seat(m, 2, "", MenuCatalog.AMERICANO, 5.5)
	_seat(m, 3, "boatman", MenuCatalog.HONJEONG_EINSPANNER, 2.0)
	_seat(m, 4, "", MenuCatalog.SONGI_SOUP, 6.0)
	m.queue_redraw()
	await create_timer(1.0).timeout
	await _grab("s6art_cafe_room")

	# ── ② 곳간 패널(CTX_LARDER) ─────────────────────────────────────────────
	m.inventory.add_harvest(CropCatalog.HWANGCHEON_PODO, 3, 0)
	m._open_frame(InventoryFrame.CTX_LARDER)
	await _grab("s6art_larder_panel")
	m._close_frame()

	# ── ③ 인벤 백팩 — 곁들이 5종 ────────────────────────────────────────────
	for menu_id in MenuCatalog.side_dish_ids():
		m.inventory.add_item(String(menu_id), 2)
	m._open_frame(InventoryFrame.CTX_MENU)
	await _grab("s6art_inv_menu")
	m._close_frame()

	# ── ④⑤ 미니게임 HUD 배지 ───────────────────────────────────────────────
	m.cheki = ChekiSession.new(4242)
	m.cheki.begin()
	m.cheki.tick(0.35, false)
	m.queue_redraw()
	await _grab("s6art_hud_cheki")
	m.cheki = null
	m.cocktail = CocktailSession.new(4242)
	m.cocktail.begin()
	m.cocktail.tick(0.35, false)
	m.queue_redraw()
	await _grab("s6art_hud_cocktail")
	m.cocktail = null

	# ── ⑥ 밤 바 — 익명 손님 상 + 잡귀 도트 ──────────────────────────────────
	m.cafe._open = false
	m.night_bar._opened = true
	m.night_bar._was_active = true   # is_active()가 보는 래치(틱 없이 세운다 — 하네스 전용)
	for i in NightBar.N_SEATS:
		var s: Dictionary = m.night_bar._seats[i]
		s["occupied"] = true
		s["patience"] = 5.0
		s["max_patience"] = m.night_bar.patience_secs
	for i in NightBar.N_SPOTS:
		var t: Dictionary = m.night_bar._spots[i]
		t["active"] = true
		t["approach"] = 6.0 - float(i)
		t["max_approach"] = m.night_bar.approach_secs
	m.clock.minutes = 21.0 * 60.0
	m.queue_redraw()
	await create_timer(0.6).timeout
	await _grab("s6art_night_bar")

	m.queue_free()
	await process_frame
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	if had: _write(sp, bak)
	quit(0)
