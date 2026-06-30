extends SceneTree
# M1.1/M1.3 — Region 데이터 모델 단위검증(ephemeral). RegionCatalog의 8구역 정의·홈베이스
# 실데이터·stub 구분·토폴로지 정합·미지 id 방어를 헤드리스로 단언한다. crops/lighting_test와
# 같은 결의 하네스 — 정적 참조 데이터라 트리에 안 붙이고 static 함수를 직접 호출한다.
# M1.3에서 워프 발동 칸(at) 실좌표·도착 칸(dest) 폴백 규칙을 더했다(워프 *동작*은 warp_test.gd).
#
# ★ M1.6 — 데이터 모델 단위검증(①~⑤) 위에 *실제 main 한 세션 end-to-end 통합*(⑥)을 얹었다:
#   부팅(안식 농원)→동쪽 워프(나루 마을·재빌드)→카페 진입→그 안에서 저장→껐다 켜기(재개)→
#   카페 퇴장→서쪽 워프(안식 농원 복귀)를 한 흐름으로 굴려, 워프·건물·세이브·재빌드가
#   *구역 전환을 거쳐 상태 누수 0*으로 합쳐지는지 본다(seam별 단위는 warp/save_region/building_test).
# 실행: godot --headless --path game --script res://playtest/world_test.gd

var _fail := 0
const SAVE := "user://save.dat"
const BAK := "user://save.dat.m1_6_bak"

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _initialize() -> void:
	print("══ M1.1/M1.3 region.gd 단위검증 ══")

	# ── ① 8구역이 모두 등록됨 ──
	var ids := RegionCatalog.ids()
	_check("① 8구역 등록", ids.size() == 8)
	_check("①b ids에 중복 없음", ids.size() == _unique(ids).size())
	for id in ids:
		_check("①c '%s' 카탈로그에 존재" % id, RegionCatalog.has_region(id))

	# ── ② 홈베이스(안식 농원) 실데이터·필드 정합 ──
	_check("② home 존재", RegionCatalog.has_region(RegionCatalog.HOME))
	_check("②b home 표시명 = 안식 농원", RegionCatalog.name_of(RegionCatalog.HOME) == "안식 농원")
	# main.gd 외부 무대 크기(80×65, ★C2)·SPAWN_TILE(40,60)과 같은 seam.
	_check("②c home 크기 = (80, 65)", RegionCatalog.size_of(RegionCatalog.HOME) == Vector2i(80, 65))   # ★ADR-0018 C2 코지-와이드
	_check("②d home 스폰 = (40, 60)", RegionCatalog.spawn_of(RegionCatalog.HOME) == Vector2i(40, 60))
	_check("②e home은 지어진 구역(is_built)", RegionCatalog.is_built(RegionCatalog.HOME))

	# ── ②' 나루 마을(M1.4 빌드 — 카페 이주) 실데이터·필드 정합 ──
	# ★C3 — 100×72 코지-와이드 외부 무대·서쪽 복도 도착 칸(3,36)과 같은 seam.
	_check("②f 나루 마을 표시명 = 나루 마을", RegionCatalog.name_of(RegionCatalog.NARU_VILLAGE) == "나루 마을")
	_check("②g 나루 마을 크기 = (100, 72)", RegionCatalog.size_of(RegionCatalog.NARU_VILLAGE) == Vector2i(100, 72))   # ★ADR-0018 C3
	_check("②h 나루 마을 스폰 = (3, 36)", RegionCatalog.spawn_of(RegionCatalog.NARU_VILLAGE) == Vector2i(3, 36))
	_check("②i 나루 마을은 지어진 구역(is_built)", RegionCatalog.is_built(RegionCatalog.NARU_VILLAGE))

	# ── ③ 8구역 전부 실데이터(stub 0): size·spawn 채워짐 ──
	# ★ M5.2 — 업화 갱도·나락이 지어져 8구역 전부 빌드(stub 0, "빌드는 한 구역씩" 완주, ADR-0015).
	var built_ids := [RegionCatalog.HOME, RegionCatalog.NARU_VILLAGE, RegionCatalog.SAMDOCHEON, RegionCatalog.HWANGCHEONHAE, RegionCatalog.JEOSEUNG_FOREST, RegionCatalog.MIHOK_FOREST, RegionCatalog.EOPHWA_MINE, RegionCatalog.NARAK]
	var stub_count := 0
	for id in ids:
		if id in built_ids:
			continue
		stub_count += 1
		_check("③ '%s' stub size=ZERO" % id, RegionCatalog.size_of(id) == Vector2i.ZERO)
		_check("③b '%s' stub spawn=ZERO" % id, RegionCatalog.spawn_of(id) == Vector2i.ZERO)
		_check("③c '%s' stub 미빌드(is_built=false)" % id, not RegionCatalog.is_built(id))
		_check("③d '%s' 표시명은 채워짐" % id, RegionCatalog.name_of(id) != "")
	_check("③e stub은 0개(8구역 전부 빌드)", stub_count == 0)
	# ★ 핵심 불변식: 8구역 전부 빌드("빌드는 한 구역씩" 완주, ADR-0015 — M5.2로 여덟째 점등).
	var built := ids.filter(func(id): return RegionCatalog.is_built(id))
	_check("③f 지어진 구역 = 8구역 전부", built == built_ids)
	# ★ M3.1/M3.2/M4.1/M4.2/M5.1/M5.2 — 삼도천·황천해·저승 숲·미혹의 숲·업화 갱도·나락 실데이터 확인(size·spawn 채워짐).
	_check("③g 삼도천 크기 = (56,40) ★C4", RegionCatalog.size_of(RegionCatalog.SAMDOCHEON) == Vector2i(56, 40))
	_check("③h 삼도천 스폰 = (28,38) ★C4", RegionCatalog.spawn_of(RegionCatalog.SAMDOCHEON) == Vector2i(28, 38))
	_check("③i 황천해 크기 = (64,44) ★C5", RegionCatalog.size_of(RegionCatalog.HWANGCHEONHAE) == Vector2i(64, 44))
	_check("③j 황천해 스폰 = (2,15) ★C5", RegionCatalog.spawn_of(RegionCatalog.HWANGCHEONHAE) == Vector2i(2, 15))
	_check("③k 저승 숲 크기 = (60,44) ★C6", RegionCatalog.size_of(RegionCatalog.JEOSEUNG_FOREST) == Vector2i(60, 44))
	_check("③l 저승 숲 스폰 = (30,42) ★C6", RegionCatalog.spawn_of(RegionCatalog.JEOSEUNG_FOREST) == Vector2i(30, 42))
	_check("③m 미혹의 숲 크기 = (64,44) ★C7", RegionCatalog.size_of(RegionCatalog.MIHOK_FOREST) == Vector2i(64, 44))
	_check("③n 미혹의 숲 스폰 = (2,22) ★C7", RegionCatalog.spawn_of(RegionCatalog.MIHOK_FOREST) == Vector2i(2, 22))
	_check("③o 업화 갱도 크기 = (64,44) ★C8", RegionCatalog.size_of(RegionCatalog.EOPHWA_MINE) == Vector2i(64, 44))
	_check("③p 업화 갱도 스폰 = (14,42) ★C8", RegionCatalog.spawn_of(RegionCatalog.EOPHWA_MINE) == Vector2i(14, 42))
	_check("③q 나락 크기 = (64,44)", RegionCatalog.size_of(RegionCatalog.NARAK) == Vector2i(64, 44))   # ★C9 코지-와이드
	_check("③r 나락 스폰 = (32,22)", RegionCatalog.spawn_of(RegionCatalog.NARAK) == Vector2i(32, 22))   # ★C9 아레나 정중앙

	# ── ④ 토폴로지(warps) 정합: world-map.md §2 구역 그래프 ──
	# 워프의 to는 실재하는 구역이어야 하고, 토폴로지는 대칭(양방향)이어야 한다.
	for id in ids:
		for w in RegionCatalog.warps_of(id):
			_check("④ '%s'→'%s' 목적 구역 실재" % [id, w["to"]], RegionCatalog.has_region(w["to"]))
			# at(발동 칸)은 *이 구역*이 지어졌으면 실좌표(그 구역 size 범위 안), stub이면 TBD.
			# dest(도착 칸)는 *양 끝 구역이 다 지어져야* 정해진다 — 그래야 도착 칸이 목적 구역 안에
			# 실재한다(★ M1.4: 안식 농원↔나루 마을 워프는 양끝 빌드라 dest 실좌표, 그 외는 TBD).
			if RegionCatalog.is_built(id):
				var sz := RegionCatalog.size_of(id)
				var at: Vector2i = w["at"]
				_check("④b '%s'→'%s' 발동 칸이 실좌표" % [id, w["to"]], at != RegionCatalog.TILE_TBD)
				_check("④b' '%s'→'%s' 발동 칸이 구역 범위 안" % [id, w["to"]],
					at.x >= 0 and at.y >= 0 and at.x < sz.x and at.y < sz.y)
			else:
				_check("④b '%s'→'%s' stub 구역 발동 칸 TBD" % [id, w["to"]],
					w["at"] == RegionCatalog.TILE_TBD)
			if RegionCatalog.is_built(id) and RegionCatalog.is_built(w["to"]):
				var dsz := RegionCatalog.size_of(w["to"])
				var dest: Vector2i = w["dest"]
				_check("④b'' '%s'→'%s' 양끝 빌드 → 도착 칸 실좌표" % [id, w["to"]], dest != RegionCatalog.TILE_TBD)
				_check("④b''' '%s'→'%s' 도착 칸이 목적 구역 범위 안" % [id, w["to"]],
					dest.x >= 0 and dest.y >= 0 and dest.x < dsz.x and dest.y < dsz.y)
			else:
				_check("④b'' '%s'→'%s' 도착 칸 TBD(목적 구역 미빌드)" % [id, w["to"]],
					w["dest"] == RegionCatalog.TILE_TBD)
	# 대칭: A가 B를 이웃으로 두면 B도 A를 둔다(나락 제외 — 진입로 미정).
	for id in ids:
		for nb in RegionCatalog.neighbors(id):
			_check("④c 토폴로지 대칭 '%s'↔'%s'" % [id, nb], RegionCatalog.neighbors(nb).has(id))
	# 허브 = 나루 마을(이웃 3: home·갱도·삼도천).
	_check("④d 나루 마을 = 허브(이웃 3)", RegionCatalog.neighbors(RegionCatalog.NARU_VILLAGE).size() == 3)
	# 나락 = 독립(이웃 0, 진입로 빌드 시 확정).
	_check("④e 나락 = 독립(이웃 0)", RegionCatalog.neighbors(RegionCatalog.NARAK).is_empty())
	# home은 허브(나루 마을)와 이어진다.
	_check("④f home↔나루 마을 연결", RegionCatalog.neighbors(RegionCatalog.HOME) == [RegionCatalog.NARU_VILLAGE])
	# ★ M5.1 정규 토폴로지 복원: 나루 마을 ──(산길)── 업화 갱도 ──(숲길)── 저승 숲(M4.1 임시 우회 종료).
	_check("④g 나루 마을 이웃에 업화 갱도(산길 정규 복원)", RegionCatalog.neighbors(RegionCatalog.NARU_VILLAGE).has(RegionCatalog.EOPHWA_MINE))
	_check("④h 업화 갱도 이웃 = 나루 마을·저승 숲(2)",
		RegionCatalog.neighbors(RegionCatalog.EOPHWA_MINE).has(RegionCatalog.NARU_VILLAGE)
		and RegionCatalog.neighbors(RegionCatalog.EOPHWA_MINE).has(RegionCatalog.JEOSEUNG_FOREST)
		and RegionCatalog.neighbors(RegionCatalog.EOPHWA_MINE).size() == 2)
	_check("④i 저승 숲↔나루 마을 직결 없음(임시 우회 종료)", not RegionCatalog.neighbors(RegionCatalog.JEOSEUNG_FOREST).has(RegionCatalog.NARU_VILLAGE))

	# ── ⑤ 미지 id 방어: 조회가 안전한 빈값을 돌려준다(크래시 X) ──
	var unknown := "no_such_region"
	_check("⑤ 미지 id has_region=false", not RegionCatalog.has_region(unknown))
	_check("⑤b 미지 id get_region 빈 Dictionary", RegionCatalog.get_region(unknown).is_empty())
	_check("⑤c 미지 id name_of 빈 문자열", RegionCatalog.name_of(unknown) == "")
	_check("⑤d 미지 id size_of ZERO", RegionCatalog.size_of(unknown) == Vector2i.ZERO)
	_check("⑤e 미지 id spawn_of ZERO", RegionCatalog.spawn_of(unknown) == Vector2i.ZERO)
	_check("⑤f 미지 id warps_of 빈 Array", RegionCatalog.warps_of(unknown).is_empty())
	_check("⑤g 미지 id neighbors 빈 Array", RegionCatalog.neighbors(unknown).is_empty())
	_check("⑤h 미지 id is_built=false", not RegionCatalog.is_built(unknown))

	# ── ⑥ M1.6 통합: 실제 main을 한 세션 동안 끝까지 굴려 세계 루프 전체를 잇는다 ──
	# (데이터 모델(①~⑤) 위에서, 워프→건물→세이브→재개→복귀워프가 구역 재빌드를 거쳐
	#  *상태 누수 0*으로 합쳐지는지 — seam별 단위는 warp/save_region/building_test가 본다.)
	await _integration()

	print(("══ 통과 ══" if _fail == 0 else "══ 실패 %d건 ══" % _fail))
	quit(_fail)

# ── M1.6 통합: 실제 main 한 세션 end-to-end ──────────────────────────────────
# 부팅→동쪽 워프(나루 마을)→카페 진입→그 안에서 저장→껐다 켜기→카페 퇴장→서쪽 워프(안식
# 농원 복귀)를 한 흐름으로 굴린다. 단위 테스트들은 각 seam을 따로 증명하지만, 여기선 *한 세션*
# 안에서 구역이 두 번 재빌드되는 동안(농원→마을→농원) 상태가 새지 않는지(잔재 0)를 본다.
func _integration() -> void:
	print("\n══ M1.6 세계 루프 통합(실제 main 한 세션 end-to-end) ══")

	# 실제 개발 세이브 백업(테스트 격리 — save_region_test와 같은 결, user://save.dat 단일 슬롯).
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))

	# ── 부팅: 안식 농원 바깥에서 시작 ──
	var m: Node = await _spawn_main()
	m.saver.delete_save()   # 백업했으니 깨끗한 새 게임에서 시작
	_check("⑥ 부팅 구역 = 안식 농원", m._region == RegionCatalog.HOME)
	_check("⑥a 부팅은 바깥 모드", m._indoor == "")

	# ── 동쪽 가장자리(78,32) → 나루 마을로 길 워프 + 재빌드 ──
	m.player.position = m._tile_center_px(Vector2i(78, 32))   # ★C2 동쪽 길 워프(y중앙)
	m._maybe_warp_edge()
	await _settle()
	_check("⑥b 나루 마을로 워프", m._region == RegionCatalog.NARU_VILLAGE)
	_check("⑥c 도착 = 마을 dest(3,36)", m._player_tile() == Vector2i(3, 36))   # ★C3
	# 재빌드 증명(콘텐츠): 마을엔 카페 외관(WALL)이 선다(building_test ⑥와 같은 seam).
	# ★ADR-0035 — 프로브를 카페 외관 내부 칸(+0,3)으로. 안식 재설계로 축사가 카페 외관 좌상단 꼭짓점(5,25)과
	#   우연히 겹쳐(고지 남서끝) HOME에서 그 한 칸이 WALL이 됐다 — 잔재 누수가 아닌 좌표 우연 → 내부 칸으로 회피.
	var cafe_probe: Vector2i = m.CAFE_EXT_RECT.position + Vector2i(0, 3)
	_check("⑥d 마을 재빌드 — 카페 외관 자리 = WALL",
		m._grid[cafe_probe.y][cafe_probe.x] == m.WALL)

	# ── 카페 진입(건물 워프) → 그 안에서 저장 ──
	m.player.position = m._tile_center_px(m.CAFE_EXT_DOOR)
	m._maybe_toggle_building()
	await _settle()
	_check("⑥e 카페 실내 진입", m._indoor == "카페")
	var saved_tile: Vector2i = m._player_tile()
	_check("⑥f 카페 방 안에 위치", m.CAFE_RECT.has_point(saved_tile))
	m._save_game()
	_check("⑥g 카페 안에서 저장 성공", m.saver.has_save())
	await _despawn(m)

	# ── 껐다 켜기: 새 인스턴스가 '있던 구역·실내·자리'로 재개(_ready 자동 복원) ──
	var m2: Node = await _spawn_main()
	_check("⑥h 재개 구역 = 나루 마을", m2._region == RegionCatalog.NARU_VILLAGE)
	_check("⑥i 재개 실내 = 카페", m2._indoor == "카페")
	_check("⑥j 재개 위치 = 저장한 카페 칸", m2._player_tile() == saved_tile)
	_check("⑥k 재개 카메라가 카페 방 격리(top=CAFE_CAM)",
		m2._cam.limit_top == m2.CAFE_CAM_RECT.position.y * m2.TILE)

	# ── 카페 퇴장 → 마을 바깥 → 서쪽 가장자리(1,16)로 안식 농원 복귀 워프 ──
	m2.player.position = m2._tile_center_px(m2.CAFE_DOOR)
	m2._maybe_toggle_building()
	await _settle()
	_check("⑥l 카페 퇴장 → 마을 바깥(구역 불변)", m2._indoor == "" and m2._region == RegionCatalog.NARU_VILLAGE)
	m2.player.position = m2._tile_center_px(Vector2i(1, 36))   # ★C3 서워프 (1,36)
	m2._maybe_warp_edge()
	await _settle()
	_check("⑥m 서쪽 가장자리 → 안식 농원 복귀", m2._region == RegionCatalog.HOME)
	_check("⑥n 도착 = home dest(77,32)", m2._player_tile() == Vector2i(77, 32))   # ★C2 80×65 동쪽 워프 한 칸 안
	# 재빌드 증명(누수 0): 안식 농원엔 카페가 없다 — 같은 칸이 더는 WALL이 아니다(마을 잔재 0).
	var cafe_probe2: Vector2i = m2.CAFE_EXT_RECT.position + Vector2i(0, 3)   # ★ADR-0035 ⑥d와 같은 내부 칸(축사 우연 겹침 회피)
	_check("⑥o 안식 농원 재빌드 — 카페 외관 잔재 없음(자리 ≠ WALL)",
		m2._grid[cafe_probe2.y][cafe_probe2.x] != m2.WALL)
	await _despawn(m2)

	# ── 세이브 백업 복원(실제 개발 세이브 보존) ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

# ★C3 — 전환(워프 fade+재빌드)이 끝날 때까지 대기한 뒤 짧게 안정화한다(warp_test ★C2 결). 마을이
#   100×100 그리드라 HOME↔마을 워프 재빌드 hitch가 고정 sleep을 넘기면 _transitioning이 남아 다음
#   토글/워프가 가드에 막힌다 → 전환 해소까지 결정적으로 기다린다(_m = 현재 활성 인스턴스).
var _m: Node = null
func _settle() -> void:
	var cap := Time.get_ticks_msec() + 4000
	while _m != null and _m._transitioning and Time.get_ticks_msec() < cap:
		await process_frame
	var until := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < until:
		await process_frame

# 새 main 인스턴스를 띄우고 _ready(자동 복원 포함)가 안정될 때까지 프레임을 돌린다.
func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	_m = m   # ★C3 — _settle이 이 인스턴스의 전환 완료를 기다리게
	root.add_child(m)
	await process_frame
	await process_frame
	return m

# 인스턴스를 정리한다(quit 시 orphan 0 보장).
func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 중복 제거(순서 무관 — 개수 비교용).
func _unique(arr: Array) -> Array:
	var seen := {}
	for x in arr:
		seen[x] = true
	return seen.keys()
