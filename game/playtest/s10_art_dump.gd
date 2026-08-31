extends SceneTree
# ★[S10-T9 / ADR-0069 아트 스코프] 엔드게임 롱테일 아트 패스 육안 덤프(비-headless).
#   s6_art_dump·s9b_chorus_dump와 **같은 결**이다: 새 판정면을 만들지 않고, 신규 에셋을 **기존
#   프롭과 한 화면에 함께** 세운다 — "새것만 톤이 튄다"가 이 패스들의 핵심 판정이기 때문이다.
#
#   ① HOME 야외  — 늘봄방 외관 · 스프링클러 3티어 · 레어크로우 8종 · 삽사리/물그릇 · 우편함
#   ② HOME 집 실내 — 화분 3(빈·젖은·자란 것) · 동행 혼
#   ③ 혼백관 실내 — 도감 열람대 · 반딧넋 안치대(기증대와 같은 줄)
#   ④ 나루 다리 남단 — 저승 보부상 좌판(7의 배수 날)
#   ⑤ 삼도천 물가 — 팬닝 스폿 · 결정기 · 반딧넋
#   ⑥ 갱도 지상 — 시련장 외관(대장간·길드와 나란히) / ⑦ 시련장 실내 — 게시판 · 매대
#   ⑧ 인벤 백팩 — S10 아이콘 15종이 색박스가 아닌지 / ⑨ 시련패 매대 — 화폐 아이콘이 엽전이 아닌지
#   ⑩ 승마 — 먹갈기 4방향(합성 시트 행 선택)
#
# ⚠️ 화면 grab이라 **골든 비교에 못 쓴다**(육안 전용 — [S5-T10] 교훈).
# ★ --headless 없이: godot --path game --script res://playtest/s10_art_dump.gd

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

	# ── ① HOME 야외 ─────────────────────────────────────────────────────────
	# 늘봄방을 **완공 상태로 세운다**(원장에 직접 — 하네스 전용). `_refresh_greenhouse`가 카탈로그·
	# 그리드를 다시 세우므로 외관·방·경작면이 한 번에 선다(완공 아침이 하는 그 일 그대로).
	m.carpenter._done[Carpenter.PROJ_GREENHOUSE] = true
	m._refresh_greenhouse()
	await create_timer(0.6).timeout
	# 스프링클러 3티어를 나란히(범위 하이라이트 크기 = 티어 신호가 색과 함께 읽히는지).
	m.sprinkler.place(Vector2i(20, 20), 1)
	m.sprinkler.place(Vector2i(24, 20), 2)
	m.sprinkler.place(Vector2i(29, 20), 3)
	# 레어크로우 8종을 한 줄로(실루엣 계열이 유지되는지 + 소품이 갈리는지가 이 줄 하나에 걸린다).
	for i in ItemCatalog.RARECROWS.size():
		m.rarecrow.place(Vector2i(18 + i * 2, 24), String(ItemCatalog.RARECROWS[i]))
	# ★ 삽사리 입양은 **7일차 이후**라야 선다(`Pet.ADOPT_MIN_DAY`) — 부팅 1일차로 부르면 조용히
	#   false를 물고 마당이 비어 나온다(1차 덤프 실측). 날짜를 먼저 밀고 입양한다.
	m.clock.day = 7
	m.pet.adopt(m.clock.day)          # 삽사리 + 물그릇(입양 후에만 그려진다)
	m._rebuild_region(RegionCatalog.HOME)
	await create_timer(0.8).timeout
	m.player.position = m._tile_center_px(Vector2i(24, 22))
	m._apply_camera_limits()
	m.queue_redraw()
	await _grab("s10art_home_farm")
	# 집 앞 마당(삽사리·물그릇·우편함) + 늘봄방 외관은 동편이라 따로 잡는다.
	m.player.position = m._tile_center_px(Vector2i(45, 13))
	m._apply_camera_limits()
	m.queue_redraw()
	await _grab("s10art_home_yard")
	m.player.position = m._tile_center_px(Vector2i(67, 13))
	m._apply_camera_limits()
	m.queue_redraw()
	await _grab("s10art_greenhouse_ext")

	# ── ② 집 실내 — 화분 · 동행 혼 ──────────────────────────────────────────
	m._soul_born = true
	m._refresh_soul_child_body()
	var pots := [Vector2i(12, 71), Vector2i(13, 71), Vector2i(14, 71)]
	for t: Vector2i in pots:
		m.garden_pot.place(t)
	m.garden_pot.plant(pots[1], CropCatalog.PIANHWA)
	m.garden_pot.water(pots[1])
	m.garden_pot.plant(pots[2], CropCatalog.PIANHWA)
	for d in 12:
		m.garden_pot.water(pots[2])
		m.garden_pot.advance_day()
	m._indoor = "집"
	m.player.position = m._tile_center_px(Vector2i(14, 73))
	m._apply_camera_limits()
	m.queue_redraw()
	await create_timer(0.5).timeout
	await _grab("s10art_home_indoor")

	# ── ⑤ 삼도천 물가 — 팬닝 · 결정기 · 반딧넋 ──────────────────────────────
	# ★[폴리시 2회차] **③ 혼백관보다 먼저** 잡는다. ③이 게이트 문턱(30)까지 반딧넋을 안치하는데
	#   `FireflySouls.all_ids()` 앞 30개에 삼도천 고정 4자리가 통째로 들어 있어, 뒤에서 잡으면
	#   `live_tiles(samdocheon)`이 빈 배열이 되어 물가에 반딧넋이 하나도 안 선다(1차 판정에서
	#   "미배선"으로 읽힌 것의 정체 — 배선이 아니라 하네스 순서였다).
	m._indoor = ""
	m._rebuild_region(RegionCatalog.SAMDOCHEON)
	await create_timer(1.0).timeout
	# ★ 스폿은 day-해시라 "그날은 0개"가 정상 상태다(COUNT_WEIGHTS의 25%) — 판정면이 날짜 운에
	#   흔들리면 안 되므로 원장에 직접 두 자리를 세운다(하네스 전용 직접 쓰기).
	#   좌표는 `PanningSpots.zones()`의 삼도천 남안 스트립(y37) 안이다.
	m.panning._spots[RegionCatalog.SAMDOCHEON] = {Vector2i(21, 37): true, Vector2i(24, 37): true}
	# ★ 결정기는 **물 위가 아니라 남안 뭍**에 세운다(1차 덤프에서 강 한복판에 떠 보였다 — 앵커에서
	#   맹목적으로 +2,+2 한 탓이다. 무대는 좌표를 고르는 곳이지 원장에 맡길 자리가 아니다).
	# ★[폴리시 2회차] y38 → y37. 삼도천 남단은 맵 끝이라 카메라가 아래로 물려 **y38 줄이 항상
	#   핫바 HUD 뒤**에 깔린다(플레이어를 북으로 물려도 클램프 때문에 안 바뀐다) — 1차 판정의
	#   "결정기 미식별"이 이것이다. 물가 스폿과 같은 y37 줄에 세우면 셋이 한 줄로 나란히 읽힌다.
	var cry := Vector2i(27, 37)
	m.crystalarium.place(RegionCatalog.SAMDOCHEON, cry)
	m.crystalarium.load_gem(RegionCatalog.SAMDOCHEON, cry, ItemCatalog.GEM_NEOKSUJEONG)
	# ★ 앵커 x22 — 플레이어 몸이 팬닝 스폿(21,37)을 가리지 않으면서(x21에 서면 바로 위 칸을 덮는다)
	#   서편 반딧넋 고정 자리(14,28)까지 한 화면에 든다.
	var anchor := Vector2i(22, 38)
	m.player.position = m._tile_center_px(anchor)
	m._apply_camera_limits()
	m.queue_redraw()
	await create_timer(0.5).timeout
	await _grab("s10art_riverside")

	# ── ③ 혼백관 실내 — 열람대 · 안치대 ─────────────────────────────────────
	# 진행을 채워 눈금·등롱 불빛이 아트 위에 제대로 얹히는지 본다(상태는 코드가 그린다).
	# ★ **게이트 문턱(30)까지 채운다** — 1차 덤프에서 20만 채웠더니 시련장이 건물 카탈로그에
	#   등재되지 않아(문이 안 열림) 실내 카메라가 갱도 암반을 비췄다. 무대를 보려면 문이 열려야 한다.
	for i in FireflySouls.GATE_COUNT:
		m.fireflies.collect(String(FireflySouls.all_ids()[i]), 3)
	m._refresh_trial_gate()
	m._indoor = "혼백관"
	m.player.position = m._tile_center_px(m.MUSEUM_IN_TILE)
	m._apply_camera_limits()
	m.queue_redraw()
	await create_timer(0.5).timeout
	await _grab("s10art_museum_room")

	# ── ④ 나루 다리 남단 — 보부상 좌판 ──────────────────────────────────────
	m.clock.day = 7                   # 7의 배수 날 = 보부상이 선다
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	await create_timer(1.0).timeout
	# ★ 좌판 바로 옆에 서면 카메라가 맵 남단에 물려 좌판이 핫바 HUD 뒤로 내려간다(1차 덤프 실측).
	#   북쪽으로 세 칸 물러서서 잡는다 — 판정면은 "무엇이 보이나"이지 "어디 서 있나"가 아니다.
	m.player.position = m._tile_center_px(m.PEDDLER_TILE + Vector2i(0, -4))
	m._apply_camera_limits()
	m.queue_redraw()
	await create_timer(0.5).timeout
	await _grab("s10art_peddler")

	# ── ⑥⑦ 갱도 — 시련장 외관 · 실내 ────────────────────────────────────────
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	await create_timer(1.0).timeout
	m.player.position = m._tile_center_px(Vector2i(46, 8))
	m._apply_camera_limits()
	m.queue_redraw()
	await create_timer(0.5).timeout
	await _grab("s10art_trial_ext")
	m.trial.tokens = 23               # 잔고 패가 매대 상판 위에 뜨는지
	m._indoor = "시련장"
	m.player.position = m._tile_center_px(m.TRIAL_IN_TILE)
	m._apply_camera_limits()
	m.queue_redraw()
	await create_timer(0.5).timeout
	await _grab("s10art_trial_room")

	# ── ⑨ 시련패 매대 — 화폐 아이콘이 엽전이 아닌지 ─────────────────────────
	m._refresh_trial_shop()
	m._open_frame(InventoryFrame.CTX_TRIAL)
	await _grab("s10art_trial_shop")
	m._close_frame()

	# ── ⑧ 인벤 백팩 — S10 아이콘 15종 ───────────────────────────────────────
	for id in [ItemCatalog.SPRINKLER, ItemCatalog.SPRINKLER_T2, ItemCatalog.SPRINKLER_T3,
			ItemCatalog.GARDEN_POT, ItemCatalog.CRYSTALARIUM, ItemCatalog.CRYSTALARIUM_PART,
			ItemCatalog.MOUNT_WHISTLE]:
		m.inventory.add_item(String(id), 2)
	for id in ItemCatalog.RARECROWS:
		m.inventory.add_item(String(id), 1)
	m._open_frame(InventoryFrame.CTX_MENU)
	await _grab("s10art_inv_icons")
	m._close_frame()

	# ── ⑩ 승마 — 먹갈기 4방향 ───────────────────────────────────────────────
	m._indoor = ""
	m._rebuild_region(RegionCatalog.HOME)
	await create_timer(1.0).timeout
	m.player.position = m._tile_center_px(Vector2i(24, 22))
	m._apply_camera_limits()
	m.mount.mount_up("", RegionCatalog.HOME, false, 0)
	# ★[폴리시 2회차] 방향을 세우려면 **main의 `_process`를 먼저 멈춰야 한다**. ADR-0024대로
	#   `_update_target`이 매 프레임 커서 쪽으로 `face_toward`를 부르므로, `_facing`에 직접 쓴 값은
	#   그 프레임에 곧바로 덮인다 — 1차 판정의 "먹갈기 4방향이 사실상 1방향"이 이것이다(넷 다 커서가
	#   놓인 좌향으로 덮여 같은 측면 프레임이 나왔다). 커서를 옮기는 길은 막혀 있다: 창이 비포커스라
	#   `Input.warp_mouse`도 `parse_input_event`도 `get_global_mouse_position()`을 안 움직인다(둘 다
	#   실측). 그래서 커서 축을 통째로 끄고 방향만 세운다 — 정지 화면 grab이라 잃는 것이 없다.
	#   ⚠️ 이 블록이 덤프의 **마지막**이라 `_process`를 되살리지 않는다(살릴 자리가 없다).
	m.set_process(false)
	for pair in [[Vector2.DOWN, "down"], [Vector2.UP, "up"],
			[Vector2.RIGHT, "right"], [Vector2.LEFT, "left"]]:
		m.player._facing = pair[0]
		m.queue_redraw()
		await _grab("s10art_mount_%s" % pair[1])
		print("   [%s] facing=%s" % [pair[1], m.player.get_facing()])

	m.queue_free()
	await process_frame
	if FileAccess.file_exists(sp): DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
	if had: _write(sp, bak)
	quit(0)
