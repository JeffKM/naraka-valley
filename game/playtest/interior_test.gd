extends SceneTree
# M2.2 — 건물 실내(메인 집·주민 집·만물상) 출입 검증(ephemeral 헤드리스 단위검증).
# M2.1까지 그레이박스 외관(WALL 박스 + 문)뿐이던 마을 8채 중 카페 외 7채(메인 집 3·주민 집 3·
# 만물상)가 *실제 들어갈 수 있는 방*이 됐는지 본다 — 외관 문에 닿으면 실내로, 실내 문에 닿으면
# 들어온 그 건물 외관 앞으로 fade 전환되고, _indoor·위치·카메라가 올바르게 바뀌는가.
#
# ★ 핵심 불변식:
#   ① 카탈로그(_buildings) — 10채 전부 등록(홈 집 1 + 마을 8 + 안식 농원 창고 1), 구역·종류 정합(카페·만물상·집6 = 마을, 창고 = HOME·storehouse).
#   ② 공유 집 실내 — 메인/주민 집 6채는 한 방(HOUSE_RECT)·실내 문(HOUSE_DOOR)을 공유하되
#      외관 문·퇴장 칸은 건물마다 다르다(들어온 그 집으로 정확히 퇴장).
#   ③ 만물상 전용 방(STORE_RECT) — 집 방 옆 칸에 서고, 들어가고 나올 수 있다.
#   ④ 그리드 크기 불변(MAP_H) — 세로 스택이 아니라 가로 배치라 warp_test의 크기 불변식 유지.
#   ⑤ 마을 집에선 취침 불가(_zone_at 비-"집") — 남의 집에서 자지 않는다(홈 집만 취침).
#   ⑥ 세이브 라운드트립 — 마을 집 실내에서 저장하면 새 인스턴스가 그 구역·실내·위치로 재개.
#   ⑦ 회귀 0 — 홈 집·카페 출입이 그대로 동작(id·카메라·취침 불변).
# 실행: godot --headless --path game --script res://playtest/interior_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# 전환(워프/문) tween이 끝날 때까지 — _transitioning이 내려갈 때까지 폴링한다(실시간 tween).
# 다중 연속 전환(워프 + 건물 14회)이라 고정 대기는 빠듯해 캐스케이드 실패가 나므로, 상태로 본다.
func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000   # 안전 상한(좀비 방지 — 무한대 X)
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame   # 최종 콜백 직후 위치·카메라 반영 한 프레임
	await process_frame

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

# 건물 종류(kind)별 실내 방 rect — 진입 후 플레이어가 이 방 안에 있는지 검증한다.
func _interior_rect(m: Node, kind: String) -> Rect2i:
	match kind:
		"house": return m.HOUSE_RECT
		"cafe": return m.CAFE_RECT
		"store": return m.STORE_RECT
		"storehouse": return m.STOREHOUSE_RECT
	return Rect2i()

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

func _initialize() -> void:
	print("══ M2.2 건물 실내 출입 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.m2_2_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	# ★ 첫 인스턴스가 옛/오염 세이브로 부팅되지 않게 spawn *전에* 지운다(테스트 격리 — 부팅 시
	# _ready가 has_save면 _load_game을 타므로, 파일을 미리 비워야 m이 깨끗한 새 게임으로 시작한다).
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m: Node = await _spawn_main()

	# ── ① 카탈로그: 15채 등록(홈 집 + 마을 8채 + 창고 + 혼백관 + 생선가게 + 목공방 + 대장간 + 길드) + 구역·종류 정합 ──
	# ★ 창고(HOME·storehouse) 9→10. ★ M3.1 혼백관(SAMDOCHEON·museum) 10→11. ★ M3.2 생선가게(HWANGCHEONHAE·fishshop) 11→12.
	# ★ M4.1 목공방(JEOSEUNG_FOREST·woodshop) 12→13. ★ M5.1 대장간(EOPHWA_MINE·smithy)·길드(EOPHWA_MINE·guild) 13→15.
	var ids: Array = m._buildings.keys()
	_check("① 건물 15채 등록(_buildings — 홈 집 + 마을 8채 + 창고 + 혼백관 + 생선가게 + 목공방 + 대장간 + 길드)", ids.size() == 15)
	_check("① 홈 집 = HOME·house", m._buildings["집"]["region"] == RegionCatalog.HOME and m._buildings["집"]["kind"] == "house")
	_check("① 창고 = HOME·storehouse", m._buildings["창고"]["region"] == RegionCatalog.HOME and m._buildings["창고"]["kind"] == "storehouse")
	# 혼백관·생선가게·목공방·대장간·길드 출입 라운드트립은 각 구역 test 전담 — 여기선 카탈로그 정합(구역·종류)만.
	_check("① 혼백관 = 삼도천·museum", m._buildings["혼백관"]["region"] == RegionCatalog.SAMDOCHEON and m._buildings["혼백관"]["kind"] == "museum")
	_check("① 생선가게 = 황천해·fishshop", m._buildings["생선가게"]["region"] == RegionCatalog.HWANGCHEONHAE and m._buildings["생선가게"]["kind"] == "fishshop")
	_check("① 목공방 = 저승 숲·woodshop", m._buildings["목공방"]["region"] == RegionCatalog.JEOSEUNG_FOREST and m._buildings["목공방"]["kind"] == "woodshop")
	_check("① 대장간 = 업화 갱도·smithy", m._buildings["대장간"]["region"] == RegionCatalog.EOPHWA_MINE and m._buildings["대장간"]["kind"] == "smithy")
	_check("① 길드 = 업화 갱도·guild", m._buildings["길드"]["region"] == RegionCatalog.EOPHWA_MINE and m._buildings["길드"]["kind"] == "guild")
	# ★ M4.2 옥자 집(미혹의 숲)·M5.1 던전 입구·나락 진입로는 잠긴 외관(비-enterable, 축사 결)이라 카탈로그에 *없다*.
	_check("① 옥자 집 카탈로그 미등록(잠김 — 비-enterable)", not m._buildings.has("옥자 집") and not m._buildings.has("옥자집"))
	_check("① 던전 입구·나락 진입로 카탈로그 미등록(잠김 — 비-enterable)", not m._buildings.has("던전 입구") and not m._buildings.has("나락 진입로"))
	_check("① 카페 = 마을·cafe", m._buildings["카페"]["region"] == RegionCatalog.NARU_VILLAGE and m._buildings["카페"]["kind"] == "cafe")
	_check("① 만물상 = 마을·store", m._buildings["만물상"]["region"] == RegionCatalog.NARU_VILLAGE and m._buildings["만물상"]["kind"] == "store")
	for hid in m.HOUSE_IDS:
		_check("① %s = 마을·house" % hid, m._buildings[hid]["region"] == RegionCatalog.NARU_VILLAGE and m._buildings[hid]["kind"] == "house")

	# ── ② 공유 집 실내: 6채가 한 방·한 실내 문 공유, 외관 문·퇴장 칸은 다름 ──
	var ext_doors := {}
	var out_tiles := {}
	for hid in m.HOUSE_IDS:
		var b: Dictionary = m._buildings[hid]
		_check("② %s 실내 방 공유(HOUSE_RECT in_tile)" % hid, b["in_tile"] == m.HOUSE_IN_TILE)
		_check("② %s 실내 문 공유(HOUSE_DOOR)" % hid, b["door"] == m.HOUSE_DOOR)
		_check("② %s 카메라 공유(HOUSE_CAM)" % hid, b["cam"] == m.HOUSE_CAM_RECT)
		ext_doors[b["ext_door"]] = true
		out_tiles[b["out_tile"]] = true
	_check("②b 외관 문 6채 서로 다름", ext_doors.size() == 6)
	_check("②b 퇴장 칸 6채 서로 다름", out_tiles.size() == 6)

	# ── ★ 안식 농원 창고(HOME·storehouse) — 빌드·진입·실내·격리·취침불가·퇴장(워프 전, HOME에서) ──
	# 창고 실내 방은 HOME 그리드에만 빌드되므로(_build_home) 마을로 워프하기 전 HOME에서 검증한다.
	var ci: Vector2i = m.STOREHOUSE_RECT.position + Vector2i(1, 1)
	_check("⒮ 창고 실내 바닥 빌드(STOREHOUSE_RECT)", m._grid[ci.y][ci.x] == m.HOUSE)
	_check("⒮ 창고 방 = HOME 집 방과 안 겹침(둘 다 HOME 밴드)",   # ★C2 HOME 집은 HOME_HOUSE_RECT
		not m.STOREHOUSE_RECT.intersects(m.HOME_HOUSE_RECT))
	var sh: Dictionary = m._buildings["창고"]
	# 진입: 외관 문에 닿는다.
	m.player.position = m._tile_center_px(sh["ext_door"])
	m._maybe_toggle_building()
	await _settle(m)
	_check("▶ 창고 외관 문 → 실내 전환", m._indoor == "창고")
	_check("▶ 창고 플레이어가 실내 방 안", m.STOREHOUSE_RECT.has_point(m._player_tile()))
	_check("▶ 창고 카메라가 그 방으로 격리(top)", m._cam.limit_top == sh["cam"].position.y * m.TILE)
	_check("▶ 창고 안에서 취침 불가(저장고)", not m._can_sleep())
	# 퇴장: 실내 문 → 들어온 외관 앞.
	m.player.position = m._tile_center_px(sh["door"])
	m._maybe_toggle_building()
	await _settle(m)
	_check("◀ 창고 실내 문 → 바깥 전환", m._indoor == "")
	_check("◀ 창고 외관 문 앞으로 퇴장(out_tile)", m._player_tile() == sh["out_tile"])

	# ── 마을로 워프(building_test와 같은 경로: 안식 농원 동쪽 가장자리) ──
	m.player.position = m._tile_center_px(Vector2i(78, 32))   # ★C2 동쪽 길 워프 → 마을
	m._maybe_warp_edge()
	await _settle(m)
	_check("⓪ 나루 마을로 워프", m._region == RegionCatalog.NARU_VILLAGE)

	# ── ④ 그리드 크기 = 빌드된 구역 치수 파생(★C3 마을 100×100 = _grid_w × _grid_h) ──
	_check("④ 그리드 크기 = 마을 치수(_grid_h×_grid_w)", m._grid.size() == m._grid_h and m._grid[0].size() == m._grid_w)
	# ③ 만물상 방·공유 집 방이 실제로 빌드됐는가(방 안쪽 바닥 칸).
	var si: Vector2i = m.STORE_RECT.position + Vector2i(1, 1)
	_check("③ 만물상 실내 바닥 빌드(STORE_RECT)", m._grid[si.y][si.x] == m.CAFE)
	var hi: Vector2i = m.HOUSE_RECT.position + Vector2i(1, 1)
	_check("③ 공유 집 실내 바닥 빌드(HOUSE_RECT)", m._grid[hi.y][hi.x] == m.HOUSE)
	# 두 방이 안 겹친다(가로 배치).
	_check("③b 집 방·만물상 방 안 겹침", not m.HOUSE_RECT.intersects(m.STORE_RECT))

	# ── 마을 7채(만물상 + 집 6) 각각: 진입 → 실내 → 퇴장(들어온 그 외관 앞) ──
	var village_ids: Array = ["만물상"] + Array(m.HOUSE_IDS)
	for id in village_ids:
		var b: Dictionary = m._buildings[id]
		# 진입: 외관 문에 닿는다.
		m.player.position = m._tile_center_px(b["ext_door"])
		m._maybe_toggle_building()
		await _settle(m)
		_check("▶ %s 외관 문 → 실내 전환" % id, m._indoor == id)
		var rect := _interior_rect(m, b["kind"])
		_check("▶ %s 플레이어가 실내 방 안" % id, rect.has_point(m._player_tile()))
		_check("▶ %s 카메라가 그 방으로 격리(top)" % id, m._cam.limit_top == b["cam"].position.y * m.TILE)
		# 마을 집에선 취침 불가(_zone_at 비-"집").
		if b["kind"] == "house":
			_check("▶ %s 안에서 취침 불가(남의 집)" % id, not m._can_sleep())
		# 퇴장: 실내 문에 닿으면 들어온 그 건물 외관 앞으로.
		m.player.position = m._tile_center_px(b["door"])
		m._maybe_toggle_building()
		await _settle(m)
		_check("◀ %s 실내 문 → 바깥 전환" % id, m._indoor == "")
		_check("◀ %s 들어온 그 외관 앞으로 퇴장(out_tile)" % id, m._player_tile() == b["out_tile"])

	# ── ⑥ 세이브 라운드트립: 마을 집 실내에서 저장 → 새 인스턴스가 그대로 재개 ──
	m.saver.save_game({
		"region": RegionCatalog.NARU_VILLAGE,
		"indoor": "바나집",
		"player_tile": m.HOUSE_IN_TILE,
	})
	await _despawn(m)
	var m2: Node = await _spawn_main()
	_check("⑥ 구역 복원(나루 마을)", m2._region == RegionCatalog.NARU_VILLAGE)
	_check("⑥b 마을 집 실내 모드 복원(바나집)", m2._indoor == "바나집")
	_check("⑥c 위치 복원(실내 진입 칸)", m2._player_tile() == m2.HOUSE_IN_TILE)
	_check("⑥d 카메라가 집 방으로 격리(top=HOUSE_CAM)", m2._cam.limit_top == m2.HOUSE_CAM_RECT.position.y * m2.TILE)
	await _despawn(m2)

	# ── ⑥e 구역 불일치 방어: region=홈인데 indoor=마을 건물 → 바깥으로 안전 복귀 ──
	var sm := SaveManager.new()
	sm.save_game({"region": RegionCatalog.HOME, "indoor": "만물상", "player_tile": Vector2i(20, 21)})
	sm.free()
	var m3: Node = await _spawn_main()
	_check("⑥e 구역 불일치 indoor → 바깥 복귀", m3._region == RegionCatalog.HOME and m3._indoor == "")
	await _despawn(m3)
	# (창고 HOME-구역 세이브 라운드트립은 home_expansion_test에서 전담 — interior_test는 M2.2 + 창고 출입까지.)

	# ── ⑦ 회귀 0: 홈 집 출입이 그대로 동작(id·취침 불변) ──
	var m4: Node = await _spawn_main()
	m4.player.position = m4._tile_center_px(m4.HOUSE_EXT_DOOR)
	m4._maybe_toggle_building()
	await _settle(m4)
	_check("⑦ 홈 집 진입(_indoor=집)", m4._indoor == "집")
	_check("⑦b 홈 집 안 취침 가능(회귀 0)", m4._can_sleep())
	m4.player.position = m4._tile_center_px(m4.HOME_HOUSE_DOOR)   # ★C2 HOME 집 실내 문
	m4._maybe_toggle_building()
	await _settle(m4)
	_check("⑦c 홈 집 퇴장(_indoor='')", m4._indoor == "")
	_check("⑦d 홈 집 외관 문 앞으로(HOUSE_OUT_TILE)", m4._player_tile() == m4.HOUSE_OUT_TILE)
	await _despawn(m4)

	# ── 세이브 백업 복원 ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
