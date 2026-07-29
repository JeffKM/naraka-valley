extends SceneTree
# ★[S4-T9 / ADR-0062 결정 10] 숲 아트 패스 육안 덤프(비-headless) — 저승 숲·미혹의 숲을 실제 인게임
# 카메라 배율(960×540, asset-ruleset §12)로 여러 지점 캡처한다. 즉시모드 드로우(원장 나무·덤불·
# 이끼·채집물·안개)가 전부 들어오므로 헤드리스 CPU 합성(fishing_region_dump)보다 판독에 맞다.
#
# ★ --headless 없이: godot --path game --script res://playtest/forest_dump.gd
#   ⚠ 반드시 game/ 기준 --path로. 워크트리 루트에서 실행하면 무한 행(메모리 교훈).
#
# 산출: /tmp/forest_<이름>.png
#   jeoseung_clearing1 : 빈터① + 북서 경계 밴드(성숙목 캐노피 밀도·낙엽 지면)
#   jeoseung_woodshop  : 목공방 외관 + 서편 밴드(건물↔숲 접지)
#   jeoseung_growth    : 성장 3폼(묘목/중간/성숙) + 그루터기 + 이끼를 한 화면에 강제 배치
#   jeoseung_bush      : 채집 덤불(열매 유·무 2상태) — 능선 SOLID 덤불과 실루엣 대조
#   mihok_pond         : 미혹 연못 12×6 물가 정합 + 짙은 톤·안개
#   mihok_deep         : 심층 구획(큰 통나무 진입목 + 큰 그루터기 6)

func _read(p: String) -> PackedByteArray:
	var f := FileAccess.open(p, FileAccess.READ); var b := f.get_buffer(f.get_length()); f.close(); return b
func _write(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(b); f.close()

func _grab(name: String) -> void:
	# 워프는 트윈(≈0.5s)이라 넉넉히 기다린 뒤 굽는다(forage_extras_dump에서 얻은 교훈).
	for i in 60:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/forest_%s.png" % name)
	print("saved /tmp/forest_%s.png" % name)

func _initialize() -> void:
	root.size = Vector2i(960, 540)
	var sp := SaveManager.slot_path(0)
	var bak := _read(sp) if FileAccess.file_exists(sp) else PackedByteArray()
	var had := FileAccess.file_exists(sp)

	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	for i in 8:
		await process_frame
	for i in 12:
		if not m.dialogue.is_open():
			break
		m.dialogue.advance()
		await process_frame

	# ── ① 저승 숲 ──────────────────────────────────────────────────────────
	var JF: String = RegionCatalog.JEOSEUNG_FOREST
	m._rebuild_region(JF)
	for i in 4:
		await process_frame

	m._warp(JF, "", Vector2i(20, 12))
	m.queue_redraw()
	if m._front_props != null:
		m._front_props.queue_redraw()
	await _grab("jeoseung_clearing1")

	m._warp(JF, "", Vector2i(11, 21))
	m.queue_redraw()
	if m._front_props != null:
		m._front_props.queue_redraw()
	await _grab("jeoseung_woodshop")

	# 성장 3폼 + 그루터기 + 이끼를 한 화면에 강제로 세운다(결정 롤을 안 기다린다 — 렌더 확인용).
	# 내부 원장 나무 중 화면에 드는 것들을 골라 단계를 직접 박는다.
	var near: Array = []
	for t: Vector2i in m.tree_ledger.tiles(JF):
		if t.x >= 10 and t.x <= 16 and t.y >= 25 and t.y <= 31:
			near.append(t)
	var forms := [1, 3, 5, 5, 4, 5]
	for i in range(near.size()):
		var t: Vector2i = near[i]
		var st: int = forms[i % forms.size()]
		m.tree_ledger._trees[JF][t]["stage"] = st
		m.tree_ledger._trees[JF][t]["hp"] = TreeLedger.hp_for_stage(st)
		m.tree_ledger._trees[JF][t]["stump"] = (i % 5 == 2)
		m.tree_ledger._trees[JF][t]["moss"] = (st >= 5 and i % 3 == 0)
	m.tree_ledger.changed.emit()
	m._warp(JF, "", Vector2i(13, 32))
	m.queue_redraw()
	if m._front_props != null:
		m._front_props.queue_redraw()
	await _grab("jeoseung_growth")

	# ★폼 보드 — 원장 5단계·그루터기·이끼·큰 장애물을 **한 줄에 나란히** 세워 매핑을 직접 검증한다.
	#   빈터 한복판(y=20)에 슬롯을 직접 심는다(덤프 전용 — 세이브는 끝에서 되돌린다).
	var board_y := 20
	var board := [
		{"x": 15, "stage": 1}, {"x": 17, "stage": 2}, {"x": 19, "stage": 3},
		{"x": 21, "stage": 4}, {"x": 23, "stage": 5}, {"x": 25, "stage": 5, "moss": true},
		{"x": 27, "stump": true},
		{"x": 29, "large": TreeLedger.KIND_LARGE_STUMP}, {"x": 31, "large": TreeLedger.KIND_LARGE_LOG},
	]
	for b in board:
		var bt := Vector2i(int(b["x"]), board_y)
		m.tree_ledger._trees[JF][bt] = {
			"species": TreeLedger.SP_PINE,
			"stage": int(b.get("stage", 0)),
			"hp": 5,
			"stump": bool(b.get("stump", false)),
			"moss": bool(b.get("moss", false)),
			"large": String(b.get("large", "")),
			"gone": false, "mossday": 0,
		}
	m.tree_ledger.changed.emit()
	m._warp(JF, "", Vector2i(23, 24))
	m.queue_redraw()
	if m._front_props != null:
		m._front_props.queue_redraw()
	await _grab("jeoseung_forms")

	# 채집 덤불 — 4그루 중 둘만 열매를 달아 2상태를 한 화면에 둔다.
	var bl: Array = m.bush_tiles_for(JF)
	for i in range(bl.size()):
		m.berry_bushes.set_berry(JF, bl[i], i % 2 == 0)
	m._warp(JF, "", Vector2i(20, 13))
	m.queue_redraw()
	if m._front_props != null:
		m._front_props.queue_redraw()
	await _grab("jeoseung_bush")

	# ── ② 미혹의 숲 ────────────────────────────────────────────────────────
	var MF: String = RegionCatalog.MIHOK_FOREST
	m._rebuild_region(MF)
	for i in 4:
		await process_frame

	m._warp(MF, "", Vector2i(31, 22))
	m.queue_redraw()
	if m._front_props != null:
		m._front_props.queue_redraw()
	await _grab("mihok_pond")

	# 심층 구획 — 진입목(52,12)(52,13) 서쪽 빈 칸. 워프 목적지가 SOLID면 워프가 취소되므로
	# 반드시 걸을 수 있는 칸을 잡는다(1차 덤프에서 연못 화면이 그대로 나온 원인).
	m._warp(MF, "", Vector2i(48, 16))
	m.queue_redraw()
	if m._front_props != null:
		m._front_props.queue_redraw()
	await _grab("mihok_deep")

	m._warp(MF, "", Vector2i(30, 34))
	m.queue_redraw()
	if m._front_props != null:
		m._front_props.queue_redraw()
	await _grab("mihok_clearing")

	if had:
		_write(sp, bak)
	else:
		DirAccess.remove_absolute(sp)
	quit(0)
