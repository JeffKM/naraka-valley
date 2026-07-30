extends SceneTree
# [S6-T1] 카페 곳간 육안 덤프(비-headless) — ①카페 실내(곳간 찬장 vs 출하함 대칭 배치·재고 핍)
# ②곳간 패널(CTX_LARDER — 재고 행·백팩·안내문). guild_dump 선례 동형.
# ★ --headless 없이: godot --path game --script res://playtest/cafe_larder_dump.gd

func _read(p: String) -> PackedByteArray:
	var f := FileAccess.open(p, FileAccess.READ); var b := f.get_buffer(f.get_length()); f.close(); return b
func _write(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(b); f.close()

func _grab(name: String) -> void:
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/%s.png" % name)
	print("saved /tmp/%s.png" % name)

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

	# 나루 마을 → 카페 실내 — 곳간 찬장(9,88)·출하함(19,88) 대칭 배치와 재고 핍 확인.
	# ★ _transition_to는 fade tween·_transitioning 가드가 있어 하네스에선 경합한다(에지 워프와
	#   겹치면 무음 무시) — _warp이 fade 최암부에 하는 상태 변경을 직접 한다(mob_dump 교훈 동형).
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	await create_timer(2.0).timeout
	m.larder.add(CropCatalog.PIANHWA, 6)
	m.larder.add(CropCatalog.HONRYEONGCHO, 4)
	m._indoor = "카페"
	m.player.position = m._tile_center_px(m.CAFE_IN_TILE)
	m._apply_camera_limits()
	m.queue_redraw()
	await create_timer(2.0).timeout
	await _grab("cafe_larder_room")

	# 곳간 패널(CTX_LARDER) — 재고 행·백팩 그리드·품질 소멸 안내문 확인
	m.inventory.add_harvest(CropCatalog.HWANGCHEON_PODO, 3, 0)
	m._open_frame(InventoryFrame.CTX_LARDER)
	await _grab("cafe_larder_panel")
	m._close_frame()

	m.queue_free()
	await process_frame
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	if had: _write(sp, bak)
	quit(0)
