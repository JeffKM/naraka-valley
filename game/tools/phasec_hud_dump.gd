extends SceneTree
# ADR-0048 Phase C(S1-13) 육안 확인용 글루(ADR-0001 허용) — hud_dump와 같은 결로 *실제 GPU 렌더*가
# 필요한 Phase C HUD(한지 시계 클러스터·핫바·혼력 바·알림 토스트·레벨업·컨텍스트 팝업·툴팁)를
# PNG로 떨군다. 헤드리스론 폰트/한지 텍스처가 안 보이므로 --headless 없이 띄운다.
# 사용: godot --path game -s res://tools/phasec_hud_dump.gd

func _init() -> void:
	var main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	for _i in 6:
		await process_frame
	# 부팅 온보딩 대화를 끝까지 넘겨 일상 HUD를 드러낸다.
	while main.dialogue.is_open():
		main.dialogue.advance()
		await process_frame
	# 관계(컨텍스트 팝업 줄) — 미호 하트 3.
	main.affinity.points = main.affinity.POINTS_PER_HEART * 3
	# 핫바가 차 보이게 수확물 몇 개 적재(선택 슬롯 강조·아이콘·개수 배지).
	main.inventory.add_harvest(CropCatalog.YEONGHON_HOBAK, 5, 2)   # 금 등급
	main.inventory.add_harvest(CropCatalog.PIANHWA, 3, 1)          # 은 등급
	for _i in 4:
		await process_frame
	# main._process가 매 프레임 컨텍스트 팝업을 "마주 본 NPC 없음 → clear"로 덮어쓰고 툴팁 마우스로
	# 덮으니, 주입 시연을 위해 잠시 끈다(게임 로직은 정상 — NPC 마주 볼 때만 팝업, 이 dump는 시연용).
	main.set_process(false)
	# ① 획득 토스트 + ② 레벨업 알림(금박) — 좌하단 알림 피드 리스킨 확인.
	main._toast_item(CropCatalog.YEONGHON_HOBAK, 5)
	main.notice_feed.push("숙련 ▲ 농사 Lv 3", 4.0, false, null, true)
	# ③ 좌하단 컨텍스트 팝업(미호 초상화 + 친밀도).
	main.context_popup.set_target(main._idle_portrait("미호"), "미호", "친밀도 3/5")
	# ④ 호버 툴팁(핫바 슬롯 아이템명) — _process가 매 프레임 마우스로 덮으니 잠시 끄고 주입.
	main.hud_tooltip.set_process(false)
	main.hud_tooltip._text = ItemCatalog.name_of(CropCatalog.YEONGHON_HOBAK) + " · 금"
	main.hud_tooltip._mouse = Vector2(320.0, 300.0)
	main.hud_tooltip.queue_redraw()
	for _i in 5:
		await process_frame
	get_root().get_texture().get_image().save_png("res://tools/phasec_hud.png")
	print("✅ phasec_hud.png — 시계 클러스터·핫바·혼력·토스트·레벨업·컨텍스트 팝업·툴팁")
	quit()
