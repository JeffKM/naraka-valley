extends SceneTree
# [S5-T5] 잡귀 그레이박스 육안 덤프(비-headless) — 갱도 층 몹 스폰·아키타입 색 구분 확인.
# ★ --headless 없이: godot --path game --script res://playtest/mob_dump.gd

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

	# 갱도 구역으로 이동 후 층 하강(_descend_mine은 EOPHWA_MINE 재적 전제 — mine_floor_test ⑨ 선례)
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	await create_timer(2.0).timeout

	# 잿길 밴드(3층) — 헛것 위주 스폰·입구 클리어 확인
	m._descend_mine(3)
	await create_timer(6.0).timeout   # 워프 페이드·층 리빌드 완주 대기(T2 settle 선례)
	await _grab("mob_floor03")

	# 넋골 밴드(25층) — 달걀귀신 위장(바위 색)·그슨대 배회
	m._descend_mine(25)
	await create_timer(6.0).timeout
	await _grab("mob_floor25")

	# 업화 밴드(45층) — 불가사리·화귀(원거리) 스폰 확인
	m._descend_mine(45)
	await create_timer(6.0).timeout
	await _grab("mob_floor45")

	m.queue_free()
	await process_frame
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	if had: _write(sp, bak)
	quit(0)
