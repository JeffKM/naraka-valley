extends SceneTree
# ★[S5-T9 / ADR-0063 아트 스코프] 업화 갱도·나락 아트 패스 육안 덤프(비-headless) — 실제 인게임
# 카메라 배율(960×540, asset-ruleset §12)로 무대마다 캡처한다. 층 렌더는 전부 즉시모드 드로우
# (지면 오버레이·돌·광맥·사다리·상자·잡귀)라 헤드리스 CPU 합성으로는 판독이 안 된다.
#
# ★ --headless 없이: godot --path game --script res://playtest/mine_dump.gd
#   ⚠ 반드시 game/ 기준 --path로. 워크트리 루트에서 실행하면 무한 행(메모리 교훈).
#
# 산출: /tmp/mine_<이름>.png
#   surface_smithy : 갱도 지상 남단 입구 — 대장간·길드 외관 2채(tan 삼킴 0 판정)
#   band_jaetgil   : 잿길 밴드(5층) — 바닥·암반 톤 기준선 + 돌·광맥
#   band_neokgol   : 넋골 밴드(25층) — 청록 그림자 톤
#   band_eophwa    : 업화 밴드(45층) — 달군 주홍 톤
#   nodes          : 광맥 4광석 + 보석 + 지오드를 한 화면에 강제 배치(종 식별 판정 전용)
#   narak_arena    : 나락 지상 아레나 — 깨진 봉인 고리 + 봉인석 + 하강 구멍
#   narak_floor    : 나락 런 층 — 심연 자보라 톤 + 구멍 + 나락철
#   smithy_room    : 대장간 실내(모루) / guild_room : 길드 실내(무기 걸이)

func _read(p: String) -> PackedByteArray:
	var f := FileAccess.open(p, FileAccess.READ); var b := f.get_buffer(f.get_length()); f.close(); return b
func _write(p: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE); f.store_buffer(b); f.close()

func _grab(name: String) -> void:
	# 워프는 트윈(≈0.5s)이라 넉넉히 기다린 뒤 굽는다(forest_dump에서 얻은 교훈).
	for i in 60:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/mine_%s.png" % name)
	print("saved /tmp/mine_%s.png" % name)

# 층 한 판을 세우고(원장·구역 재빌드) 방 한가운데로 옮겨 굽는다.
func _floor_shot(m: Node, floor_no: int, name: String) -> void:
	m._descend_mine(floor_no)
	await create_timer(1.5).timeout
	var r: Rect2i = m._mine_layout["rect"]
	m.player.global_position = Vector2(r.position + r.size / 2) * m.TILE
	m.queue_redraw()
	await _grab(name)

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
	for i in 12:
		if not m.dialogue.is_open():
			break
		m.dialogue.advance()
		await process_frame

	# ── ① 갱도 지상 — 남단 입구(대장간 x4..9 · 길드 x22..27, 둘 다 y37..41) ─────
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	await create_timer(2.0).timeout
	m.player.global_position = Vector2(15, 43) * m.TILE   # 두 채가 한 화면에 들어오는 spawn 근처
	m.queue_redraw()
	await _grab("surface_smithy")

	# ── ② 밴드 3종(각 1층씩) ──────────────────────────────────────────────────
	await _floor_shot(m, 5, "band_jaetgil")
	await _floor_shot(m, 25, "band_neokgol")
	await _floor_shot(m, 45, "band_eophwa")

	# ── ③ 광맥 종 식별 전용 — 한 줄에 전 종을 강제로 심는다(육안 판정 하네스) ──
	#   층 생성 롤을 건드리지 않고 **레이아웃 사본의 nodes만** 덮어쓴다(RNG 무접촉).
	var r: Rect2i = m._mine_layout["rect"]
	var kinds := ["ore_myeongdong", "ore_yucheol", "ore_hwangcheongeum", "hontan",
		"gem_neoksujeong", "gem_myeongok", "gem_yeomjuseok", "gem_myeongbu_geumgang",
		"geode_neokal", "geode_eophwa"]
	var forced := {}
	var y0: int = r.position.y + r.size.y / 2
	for i in kinds.size():
		forced[Vector2i(r.position.x + 1 + i * 2, y0)] = kinds[i]
	m._mine_layout["nodes"] = forced
	m.player.global_position = Vector2(r.position.x + 10, y0 + 3) * m.TILE
	m.queue_redraw()
	await _grab("nodes")

	# ── ④ 실내 2방 ────────────────────────────────────────────────────────────
	m._ascend_mine_to_surface()                 # 층 → 지상(입구 사다리)
	await create_timer(3.0).timeout
	# ★ 착지 칸은 **방 안**(SMITHY_RECT x8..19)이어야 한다. 옛 (6,51)은 방 서쪽 벽 밖·cam rect
	#   여백(VOID)이라, 실내 격리 마스크가 제 크기로 고쳐진 뒤 플레이어만 검은 여백에 서 있는
	#   그림이 됐다(옛 마스크가 1.5배로 부푼 덕에 우연히 가려져 있었을 뿐이다).
	m._transition_to("대장간", Vector2i(11, 51))
	await create_timer(3.0).timeout
	await _grab("smithy_room")
	m._transition_to("길드", Vector2i(27, 51))
	await create_timer(3.0).timeout
	await _grab("guild_room")
	m._transition_to("", Vector2i(24, 43))
	await create_timer(2.0).timeout

	# ── ⑤ 나락 — 지상 아레나 + 런 층 ──────────────────────────────────────────
	m._rebuild_region(RegionCatalog.NARAK)
	await create_timer(2.0).timeout
	# 고리 상변의 **끊긴 자리**(x27↔x37 사이 누출구)가 화면에 들어오게 — 봉인석이 거기 선다.
	m.player.global_position = Vector2(32, 12) * m.TILE
	m.queue_redraw()
	await _grab("narak_arena")
	m._descend_narak(12)                                      # 나락철이 도는 깊이
	await create_timer(2.0).timeout
	var nr: Rect2i = m._narak_layout["rect"]
	m.player.global_position = Vector2(nr.position + nr.size / 2) * m.TILE
	m.queue_redraw()
	await _grab("narak_floor")

	m.queue_free()
	await process_frame
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	if had: _write(sp, bak)
	quit(0)
