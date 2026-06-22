extends SceneTree
# 외부↔실내 건물 출입 전환 검증 — 외관 문 칸에 닿으면 실내로, 실내 문 칸에 닿으면 밖으로
# fade 전환되고, 그때 _indoor·플레이어 위치·카메라 경계가 올바르게 바뀌는지 본다(ephemeral).
# 실행: godot --headless --path game --script res://playtest/building_test.gd
#
# 메모: _transition_to는 tween(실시간) 기반이라, 트리거 후 실제 시간이 충분히 흐를 때까지
# 프레임을 돌려야 콜백(_indoor 설정·텔레포트·카메라 전환)이 끝난다(_settle).

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# 트리거 후 fade 연출(약 0.52초)이 끝나도록 실제 시간 기준으로 프레임을 돌린다.
func _settle() -> void:
	var until := Time.get_ticks_msec() + 900
	while Time.get_ticks_msec() < until:
		await process_frame

func _initialize() -> void:
	print("══ 외부↔실내 건물 출입 전환 검증 ══")
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var T: int = main.TILE
	var out_bottom: int = main.OUTDOOR_H * T

	_check("① 시작은 바깥", main._indoor == "")
	_check("①b 외부 카메라가 외부 영역까지만(bottom=OUTDOOR_H)", main._cam.limit_bottom == out_bottom)

	# ── 집: 외관 문 진입 → 실내 ──
	main.player.position = main._tile_center_px(main.HOUSE_EXT_DOOR)
	main._maybe_toggle_building()
	await _settle()
	_check("② 집 외관 문에 닿으면 실내(집)로 전환", main._indoor == "집")
	_check("②b 플레이어가 실내 집 방 안으로 텔레포트", main.HOUSE_RECT.has_point(main._player_tile()))
	_check("②c 카메라가 집 방으로 격리(top=HOUSE_CAM)", main._cam.limit_top == main.HOUSE_CAM_RECT.position.y * T)
	_check("②d 집 안에서 취침 가능(_zone_at=집)", main._can_sleep())

	# ── 집: 실내 문 퇴장 → 바깥 ──
	main.player.position = main._tile_center_px(main.HOUSE_DOOR)
	main._maybe_toggle_building()
	await _settle()
	_check("③ 실내 집 문에 닿으면 바깥으로 전환", main._indoor == "")
	_check("③b 플레이어가 외관 집 문 앞으로", main._player_tile() == main.HOUSE_OUT_TILE)
	_check("③c 카메라 외부 복귀", main._cam.limit_bottom == out_bottom)
	# 집(안식 농원)에 있는 동안 외관 집 자리가 통과 불가(WALL)인지 본다 — 카페는 마을로 이주했으니
	# 안식 농원에선 집 외관만 검사한다(★ M1.4).
	_check("③d 외관 집 자리는 통과 불가(문 외 WALL)", main._grid[main.HOUSE_EXT_RECT.position.y][main.HOUSE_EXT_RECT.position.x] == main.WALL)

	# ── ★ M1.4: 카페는 나루 마을에 있다 — 안식 농원 동쪽 가장자리(38,16)에서 마을로 길 워프 ──
	main.player.position = main._tile_center_px(Vector2i(38, 16))
	main._maybe_warp_edge()
	await _settle()
	_check("④pre 동쪽 가장자리에서 나루 마을로 워프", main._region == RegionCatalog.NARU_VILLAGE)

	# ── 카페(나루 마을): 외관 문 진입 → 실내 ──
	main.player.position = main._tile_center_px(main.CAFE_EXT_DOOR)
	main._maybe_toggle_building()
	await _settle()
	_check("④ 카페 외관 문에 닿으면 실내(카페)로 전환", main._indoor == "카페")
	_check("④b 플레이어가 실내 카페 방 안으로", main.CAFE_RECT.has_point(main._player_tile()))
	_check("④c 카메라가 카페 방으로 격리(top=CAFE_CAM)", main._cam.limit_top == main.CAFE_CAM_RECT.position.y * T)
	_check("④d 카페 안 판정(_zone_at=카페)", main._in_cafe())

	# ── 카페: 실내 문 퇴장 → 바깥 ──
	main.player.position = main._tile_center_px(main.CAFE_DOOR)
	main._maybe_toggle_building()
	await _settle()
	_check("⑤ 실내 카페 문에 닿으면 바깥으로 전환", main._indoor == "")
	_check("⑤b 플레이어가 외관 카페 문 앞으로", main._player_tile() == main.CAFE_OUT_TILE)

	# ── 마을 외관 카페 자리는 통과 불가(WALL), 실내 방 바깥은 VOID ──
	_check("⑥ 외관 카페 자리는 통과 불가(문 외 WALL)", main._grid[main.CAFE_EXT_RECT.position.y][main.CAFE_EXT_RECT.position.x] == main.WALL)
	_check("⑥b 실내 구역 방 바깥은 VOID(검은 여백)", main._grid[main.OUTDOOR_H + 1][1] == main.VOID)

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
