extends SceneTree
# [S5-T6] 모험가 길드 육안 덤프(비-headless) — ①길드 실내(무골·카운터·빈 토벌 게시판) ②무기 매대 프레임 ③10층 보상 상자.
# ★ --headless 없이: godot --path game --script res://playtest/guild_dump.gd

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

	# 갱도 구역 → 길드 실내(카운터 앞) — 무골·카운터·무기 걸이·빈 토벌 게시판 확인
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	await create_timer(2.0).timeout
	m._transition_to("길드", Vector2i(27, 51))
	await create_timer(4.0).timeout
	await _grab("guild_room")

	# 무기 매대 프레임(CTX_GUILD) — mine_depth 25 상태로 깊이 게이팅 노출 확인(명동검·유철검만)
	m.mine_floors.reach_floor(25)
	m.wallet.gold = 3000
	m._open_frame(InventoryFrame.CTX_GUILD)
	await _grab("guild_store")
	m._close_frame()

	# 10층 보상 층 — 몹 0·상자 1개(방 중심) 확인
	m._transition_to("", Vector2i(27, 55))
	await create_timer(3.0).timeout
	m._descend_mine(10)
	await create_timer(6.0).timeout
	await _grab("guild_chest_floor10")

	m.queue_free()
	await process_frame
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	if had: _write(sp, bak)
	quit(0)
