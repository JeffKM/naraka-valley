extends SceneTree
# ★[S3-T10] 육안 글루(ADR-0001 허용) — 낚시 아트 패스 2의 **실제 GPU 렌더**를 PNG로 떨군다.
# hud_dump.gd와 같은 결이다: 아이콘 슬롯·한지 패널·릴 격투 HUD는 헤드리스 더미 렌더러로는
# 안 나오므로 `--headless` **없이** 띄운다([godot-draw-texture-compressed-flat-gl] 교훈 —
# 즉시모드 텍스처 드로우의 진단은 반드시 비-헤드리스 실캡처로).
#
# 떨구는 것:
#   ① s3_inv_fish.png    인벤 백팩 — 어획물 21종(물고기 18 + 통용물 3) 슬롯
#   ② s3_inv_gear.png    인벤 백팩 — 기어 11종(낚싯대4·미끼3·태클3·게잡이통)
#   ③ s3_hud_wait.png    릴 격투 HUD — 입질 대기(찌)
#   ④ s3_hud_bite.png    릴 격투 HUD — 입질(찌 잠김)
#   ⑤ s3_hud_fight.png   릴 격투 HUD — 격투(트랙 물고기 + 텐션/스태미나 바)
#   ⑥ s3_hud_burst.png   릴 격투 HUD — 발버둥(붉은 테 + 텔레그래프) + 퍼펙트 누적
#   ⑦ s3_boatman.png     황천해 생선가게 앞 뱃사공(인게임 자리 — 발치·크기 정합)
#   ⑧ s3_portrait.png    뱃사공 대화 초상화 슬롯
#
# 사용(★워치독 필수 — 좀비 방지):
#   ( godot --path game -s res://tools/fishing_art_dump.gd & pid=$!; \
#     ( sleep 180; kill -9 $pid 2>/dev/null ) & wd=$!; wait $pid; kill $wd 2>/dev/null )

const OUT := "res://tools/"


func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	for _i in 6:
		await process_frame
	# 부팅 온보딩 대화를 끝까지 넘겨 일상 화면을 드러낸다(hud_dump 선례).
	while main.dialogue.is_open():
		main.dialogue.advance()
		await process_frame

	# ── ①② 인벤 아이콘 ───────────────────────────────────────────────────
	# 백팩을 비우고 어획물만 채운다(21종이 한 화면에 들어오게 — 슬롯에 그레이박스 잔재가 남아
	# 있으면 흰 박스/색 박스로 즉시 드러난다).
	_fill(main, FishCatalog.ids() + [ItemCatalog.NEOK_GE, ItemCatalog.HON_JOGAE, ItemCatalog.JAETBIT_SORA])
	main._open_frame(InventoryFrame.CTX_MENU)
	main.frame.menu_tab = InventoryFrame.TAB_INV
	for _i in 4:
		await process_frame
	_shot("s3_inv_fish.png")

	_fill(main, [
		GearCatalog.ROD_T1, GearCatalog.ROD_T2, GearCatalog.ROD_T3, GearCatalog.ROD_T4,
		GearCatalog.BAIT_BASIC, GearCatalog.BAIT_LURE, GearCatalog.BAIT_PLEDGE,
		GearCatalog.TACKLE_CORK, GearCatalog.TACKLE_SINKER, GearCatalog.TACKLE_QUALITY,
		ItemCatalog.CRAB_POT,
	])
	for _i in 4:
		await process_frame
	_shot("s3_inv_gear.png")

	# 태클·게잡이통은 위 목록에선 둘째 줄 밖으로 밀린다 — 넷만 따로 담아 슬롯 렌더를 확인한다
	# (CAT_TOOL 태클 · **CAT_PLACEABLE 게잡이통** = 이번에 텍스처 분기를 새로 얹은 칸).
	_fill(main, [
		ItemCatalog.CRAB_POT, GearCatalog.TACKLE_CORK, GearCatalog.TACKLE_SINKER,
		GearCatalog.TACKLE_QUALITY, GearCatalog.BAIT_BASIC, GearCatalog.BAIT_LURE,
	])
	for _i in 4:
		await process_frame
	_shot("s3_inv_tackle.png")
	main._close_frame()
	for _i in 2:
		await process_frame

	# ── ③~⑥ 릴 격투 HUD ─────────────────────────────────────────────────
	# 세션을 **직접 만들어** 상태를 고정한다(캐스팅 입력을 흉내 내면 타이밍 의존이라 불안정하다).
	# 로직은 안 건드리고 상태 변수만 원하는 그림이 되게 세팅한다 — 순수 시각 확인이다.
	main.fishing = FishingSession.new(7, FishCatalog.session_params(FishCatalog.SANGYEOTGIL_INGEO))
	main.fishing.state = FishingSession.State.WAITING
	main.fishing._wait_secs = 999.0   # 캡처 동안 BITE로 안 넘어가게(세션은 _process가 계속 굴린다)
	main.queue_redraw()
	for _i in 3:
		await process_frame
	_shot("s3_hud_wait.png")

	main.fishing.state = FishingSession.State.BITE
	main.fishing._phase_t = 0.0
	main.queue_redraw()
	for _i in 3:
		await process_frame
	_shot("s3_hud_bite.png")

	main.fishing.state = FishingSession.State.FIGHT
	main.fishing.tension = 42.0
	main.fishing.fish_stamina = float(main.fishing.fish.get("stamina", 60.0)) * 0.65
	main.fishing.distance = float(main.fishing.fish.get("distance", 30.0)) * 0.55
	main.queue_redraw()
	for _i in 3:
		await process_frame
	_shot("s3_hud_fight.png")

	main.fishing.tension = 88.0
	main.fishing.distance = float(main.fishing.fish.get("distance", 30.0)) * 0.20
	main.fishing.perfect_count = 3
	main.fishing._burst_left = 0.6      # 발버둥 중(붉은 테)
	main.fishing._perfect_left = 0.2    # 퍼펙트 창(금박 테)
	main.queue_redraw()
	for _i in 3:
		await process_frame
	_shot("s3_hud_burst.png")
	main.fishing = null
	main.queue_redraw()

	# ── ⑦ 뱃사공(인게임 자리) ────────────────────────────────────────────
	main._rebuild_region(RegionCatalog.HWANGCHEONHAE)
	for _i in 6:
		await process_frame
	var r = main._resident_named("뱃사공")
	print("boatman._sprite = ", "OK(도색)" if (r != null and r.node != null and r.node._sprite != null) else "null(그레이박스 폴백)")
	if r != null and r.node != null:
		main.player.global_position = r.node.global_position + Vector2(-56.0, 8.0)
	for _i in 6:
		await process_frame
	_shot("s3_boatman.png")

	# ⑨ 게잡이통 월드 렌더 — 아이콘과 **같은 텍스처**를 물 위에 세 상태로 나란히 깐다
	#    (무미끼 / 장전 / 어획 대기 — 상태 표식이 텍스처 위에서 살아 있는지).
	if r != null and r.node != null:
		var wy: int = int(r.node.global_position.y / 32.0) + 3
		var wx: int = int(r.node.global_position.x / 32.0) - 2
		for i in 3:
			var pt := Vector2i(wx + i * 2, wy)
			main.crab_pot.place(RegionCatalog.HWANGCHEONHAE, pt)
			if i >= 1:
				main.crab_pot.load_bait(RegionCatalog.HWANGCHEONHAE, pt)
			if i == 2:
				main.crab_pot._pots[RegionCatalog.HWANGCHEONHAE][pt]["catch"] = ItemCatalog.NEOK_GE
		main.player.global_position = Vector2((wx + 2) * 32 + 16, (wy - 2) * 32)
		main.queue_redraw()
		for _i in 6:
			await process_frame
		_shot("s3_crabpot.png")

	# ── ⑧ 초상화 ─────────────────────────────────────────────────────────
	var lines := PackedStringArray(["[talk]…노 젓는 사람일세."])
	if r != null and r.node != null:
		lines = r.node.lines()
	main.dialogue.start("뱃사공", lines)
	main._set_portrait("뱃사공", "")
	for _i in 4:
		await process_frame
	_shot("s3_portrait.png")
	quit()


# 백팩을 비우고 목록만 1개씩 넣는다(핫바 앞 칸은 도구가 차지하므로 슬롯이 밀린다 — 그대로 둔다).
func _fill(main, ids: Array) -> void:
	for i in main.inventory.slots.size():
		var slot = main.inventory.slots[i]
		if slot != null and ItemCatalog.category_of(String(slot.get("id", ""))) != ItemCatalog.CAT_TOOL:
			main.inventory.slots[i] = null
	for id in ids:
		main.inventory.add_item(String(id), 1)


func _shot(name: String) -> void:
	get_root().get_texture().get_image().save_png(OUT + name)
	print("✅ ", name)
