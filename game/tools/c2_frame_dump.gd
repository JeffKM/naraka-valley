extends SceneTree
# Phase 2.7 C2 육안 확인용 글루(ADR-0001 허용) — 공통 인벤토리 프레임이 실제로 그려지는지
# 네 컨텍스트를 *실제 GPU 렌더*로 떨군다(tone_dump/hud_dump 결, --headless 없이):
#   c2_menu_inv.png  — 메뉴 인벤토리 탭(백팩 그리드 + 정리)
#   c2_menu_rel.png  — 메뉴 관계 탭(하트 4행, HeartBar 재사용)
#   c2_bin.png       — 무인 출하함(대기 슬롯 + 백팩, 정산 미리보기)
#   c2_store.png     — 네오 매대(구매 본문 + 백팩)
# 사용: godot --path game --resolution 960x540 -s res://tools/c2_frame_dump.gd

func _init() -> void:
	await _shot_menu_inv()
	await _shot_menu_rel()
	await _shot_bin()
	await _shot_store()
	print("✅ c2_frame_dump 4장 저장 완료")
	quit()

func _make_main() -> Node:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	main.onboarding.step = 7   # DONE — 인트로 컷신·배너 차단
	while main.dialogue.is_open():
		main.dialogue.advance()
	main.fade.modulate.a = 0.0
	main.set_process(false)    # 결정적 캡처(우리가 직접 프레임 컨텍스트를 연다)
	main.player.set_physics_process(false)
	# 백팩에 보이는 아이템 몇 개를 채운다(시작 키트 + 수확물).
	main.inventory.add_harvest(CropCatalog.HONRYEONGCHO, 9)
	main.inventory.add_harvest(CropCatalog.PIANHWA, 4)
	return main

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("res://tools/%s.png" % name)
	print("  · %s.png" % name)

func _shot_menu_inv() -> void:
	var main = await _make_main()
	main.frame.store_text = ""
	main.frame.open(InventoryFrame.CTX_MENU)
	main.frame.set_tab(InventoryFrame.TAB_INV)
	main.hotbar.visible = false
	await _capture("c2_menu_inv")
	main.free()

func _shot_menu_rel() -> void:
	var main = await _make_main()
	# 하트 약간 채워 읽기 전용 표시를 본다.
	main.affinity.points = 3 * main.affinity.POINTS_PER_HEART
	main.mel_affinity.points = 2 * main.mel_affinity.POINTS_PER_HEART
	main.frame.open(InventoryFrame.CTX_MENU)
	main.frame.set_tab(InventoryFrame.TAB_REL)
	main.frame.set_hearts(main._heart_rows())
	main.hotbar.visible = false
	await _capture("c2_menu_rel")
	main.free()

func _shot_bin() -> void:
	var main = await _make_main()
	main.ship_bin.add(CropCatalog.HONRYEONGCHO, 6)
	main.ship_bin.add(CropCatalog.PIANHWA, 3)
	main.frame.open(InventoryFrame.CTX_BIN)
	main.hotbar.visible = false
	await _capture("c2_bin")
	main.free()

func _shot_store() -> void:
	var main = await _make_main()
	main.wallet.gold = 480
	main.neo_affinity.points = 3 * main.neo_affinity.POINTS_PER_HEART
	main.frame.store_text = main._store_text()
	main.frame.open(InventoryFrame.CTX_STORE)
	main.hotbar.visible = false
	await _capture("c2_store")
	main.free()
