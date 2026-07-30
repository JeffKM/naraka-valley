extends SceneTree
# [S5-T4] 전투 코어 UI 육안 덤프(비-headless) — ①vitals HUD 2바(체력+혼력) ②숙련 탭 5행(전투 행 포함).
# ★ --headless 없이: godot --path game --script res://playtest/combat_hud_dump.gd

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
	# 세이브 격리(부팅이 새 게임/로드하므로 개발 save.dat 백업).
	var sp := SaveManager.slot_path(0)
	var bak := _read(sp) if FileAccess.file_exists(sp) else PackedByteArray()
	var had := FileAccess.file_exists(sp)

	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	for i in 8:
		await process_frame

	# 인트로 통보 대화 스킵(HUD·프레임 로직이 대화에 가려지지 않게)
	m.onboarding.notice_seen()
	m.dialogue._close()
	await process_frame

	# ① vitals HUD 2바 — 체력·혼력 모두 부분 소모 상태로(두 바의 비율·수치 표기 확인)
	m.health.damage(37)
	m.energy.spend(30)
	await _grab("combat_vitals_partial")

	# ② 숙련 탭 5행 — 전투 행이 5행째로 들어간 상태(XP 꼬리 배치·행 높이 확인)
	m._gain_combat_xp(15)
	m._open_frame(InventoryFrame.CTX_MENU)
	m.frame.set_tab(InventoryFrame.TAB_SKILL)
	m.frame.set_skills(m._skill_rows())
	m.frame.queue_redraw()
	await _grab("combat_skill_tab")

	m._close_frame()
	m.queue_free()
	await process_frame

	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	if had: _write(sp, bak)
	quit(0)
