extends SceneTree
# M1.3 — 가장자리/길 워프 시스템 동작 검증(ephemeral). main을 인스턴스화해 워프 실행기
# (_warp)·문 위임(_transition_to)·가장자리 워프 트리거(_maybe_warp_edge)·구역 재빌드
# (_rebuild_region)를 헤드리스로 단언한다. RegionCatalog *데이터*는 world_test가 본다 —
# 여기는 main이 그 데이터를 어떻게 *쓰는지*(동작)를 본다(building_test와 같은 결의 하네스).
#
# ★ M1.4 핵심 불변식: 나루 마을이 지어져(is_built) 안식 농원↔나루 마을 가장자리 워프가 *살았다* —
#   발동 칸(38,16)에 닿으면 구역이 나루 마을로 전환되고 도착 칸(3,16)에 놓인다. 마을→갱도·삼도천은
#   목적지가 아직 stub이라 휴면이다(M1.3에선 모든 워프가 휴면이었으나 M1.4가 첫 워프를 점등).
#
# 메모: _warp/_transition_to는 tween(실시간) 기반이라, 트리거 후 실제 시간이 흐를 때까지
# 프레임을 돌려야 콜백(_region·_indoor·텔레포트·카메라)이 끝난다(_settle). _rebuild_region은 동기.
# 실행: godot --headless --path game --script res://playtest/warp_test.gd

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
	print("══ M1.3 가장자리/길 워프 시스템 검증 ══")
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# ── ① 시작 상태: 홈베이스·바깥 ──
	_check("① 시작 구역 = home", main._region == RegionCatalog.HOME)
	_check("①b 시작은 바깥(_indoor='')", main._indoor == "")

	# ── ② 가장자리 워프 발동 칸이 걸어갈 수 있는 길(PATH) ──
	# 동쪽 복도 끝(38,16) = RegionCatalog.HOME warps.at. _carve_paths가 여기까지 길을 잇는다.
	var at: Vector2i = RegionCatalog.warps_of(RegionCatalog.HOME)[0]["at"]
	_check("② home 워프 발동 칸 = (38,16)", at == Vector2i(38, 16))
	_check("②b 그 칸이 길(PATH — 걸어 닿을 수 있음)", main._grid[at.y][at.x] == main.PATH)

	# ── ③ 가장자리 워프 점등(M1.4): 발동 칸에 닿으면 나루 마을로 전환되고 도착 칸에 놓인다 ──
	var dest: Vector2i = RegionCatalog.warps_of(RegionCatalog.HOME)[0]["dest"]
	main.player.position = main._tile_center_px(at)
	main._maybe_warp_edge()
	await _settle()
	_check("③ 발동 칸에 닿으면 나루 마을로 전환(워프 점등)", main._region == RegionCatalog.NARU_VILLAGE)
	_check("③b 도착 칸(마을 스폰)에 놓임", main._player_tile() == dest)
	_check("③c 전환 후 바깥(실내 아님)", main._indoor == "")
	_check("③d 마을 카페 외관 문이 길(PATH — 카페 진입 가능)",
		main._grid[main.CAFE_EXT_DOOR.y][main.CAFE_EXT_DOOR.x] == main.PATH)
	# ── ③' 되돌아가기: 마을 서쪽 가장자리(1,16)에 닿으면 안식 농원으로 복귀(왕복 검증) ──
	var back_at: Vector2i = RegionCatalog.warps_of(RegionCatalog.NARU_VILLAGE)[0]["at"]
	var back_dest: Vector2i = RegionCatalog.warps_of(RegionCatalog.NARU_VILLAGE)[0]["dest"]
	main.player.position = main._tile_center_px(back_at)
	main._maybe_warp_edge()
	await _settle()
	_check("③e 마을 서쪽 가장자리 → 안식 농원 복귀(왕복)", main._region == RegionCatalog.HOME)
	_check("③f 복귀 도착 칸에 놓임", main._player_tile() == back_dest)

	# ── ④ 워프 도착 칸 폴백 규칙(_warp_dest) ──
	# dest 미정(TBD)이면 목적 구역 기본 스폰으로 폴백, 명시했으면 그 칸 그대로.
	var w_tbd := {"to": RegionCatalog.HOME, "dest": RegionCatalog.TILE_TBD}
	_check("④ dest=TBD → 목적 구역 스폰 폴백", main._warp_dest(w_tbd) == RegionCatalog.spawn_of(RegionCatalog.HOME))
	var w_set := {"to": RegionCatalog.HOME, "dest": Vector2i(5, 5)}
	_check("④b dest 명시 → 그 칸 그대로", main._warp_dest(w_set) == Vector2i(5, 5))

	# ── ⑤ 구역 재빌드(_rebuild_region): 그리드·라벨을 새로 깔되 누적/크래시 없음 ──
	var labels_before: int = main._labels.size()
	main._rebuild_region(RegionCatalog.HOME)   # 홈베이스 자기 재빌드(이웃 미빌드라 테스트는 self로)
	_check("⑤ 재빌드 후 구역 = home", main._region == RegionCatalog.HOME)
	_check("⑤b 재빌드 후 그리드 크기 유지(MAP_H×MAP_W)",
		main._grid.size() == main.MAP_H and main._grid[0].size() == main.MAP_W)
	_check("⑤c 재빌드 후 가장자리 길 유지", main._grid[at.y][at.x] == main.PATH)
	_check("⑤d 라벨 개수 누적 안 됨(중복 방지)", main._labels.size() == labels_before)

	# ── ⑥ 문 = 특수 워프(구역 불변): _transition_to가 _warp에 위임돼도 행동 동일 ──
	# 집 외관 문에 닿으면 실내(집)로 가되 구역은 home 그대로(같은 구역 안 워프 = 재빌드 없음).
	main.player.position = main._tile_center_px(main.HOUSE_EXT_DOOR)
	main._maybe_toggle_building()
	await _settle()
	_check("⑥ 집 문 진입 → 실내(집)", main._indoor == "집")
	_check("⑥b 문 워프는 구역 불변(home 유지)", main._region == RegionCatalog.HOME)
	_check("⑥c 플레이어가 집 방 안으로 텔레포트", main.HOUSE_RECT.has_point(main._player_tile()))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
