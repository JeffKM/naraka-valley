extends SceneTree
# M1.5 — 세이브: 현재 구역·위치 추적·복원 검증(ephemeral 헤드리스 단위검증).
#
# 무엇을 보나:
#   ① 라운드트립 — 한 구역(나루 마을)으로 워프해 어느 칸에 선 채 저장하고, 새 인스턴스를
#      띄우면(_ready 자동 복원) 그 구역·실내 모드·위치·카메라가 '있던 그대로' 재개되는가.
#   ② 미지 구역 폴백 — 저장 구역 id가 안 지어졌거나 알 수 없으면(is_built=false) 홈베이스
#      외부 스폰으로 안전히 떨어지는가(깨진/구버전 세이브로 빈 맵·VOID에 갇히지 않게).
#   ③ SaveManager 불변 — save.gd는 IO만 책임지고(버전 래핑), '무엇을 어떻게 되돌리나'는
#      main(_save_game/_restore_location)이 조율한다 — 세 키(region·indoor·player_tile)가
#      늘어도 SaveManager는 손대지 않는다(이 테스트는 그 조율 동작을 검증).
#
# 실행: godot --headless --path game --script res://playtest/save_region_test.gd
#
# 메모: 세이브는 user://save.dat(SaveManager.SAVE_PATH) 단일 슬롯을 공유하므로, 실제 개발
# 세이브를 덮어쓰지 않게 시작 시 백업하고 끝에 복원한다(테스트 격리).

var _fail := 0
const SAVE := "user://save.dat"
const BAK := "user://save.dat.m1_5_bak"

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# 워프/페이드 tween(실시간 ~0.52s)이 끝나도록 실제 시간 기준으로 프레임을 돌린다(building_test 결).
func _settle() -> void:
	var until := Time.get_ticks_msec() + 900
	while Time.get_ticks_msec() < until:
		await process_frame

# 새 main 인스턴스를 띄우고 _ready(자동 복원 포함)가 안정될 때까지 프레임을 돌린다.
func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
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

func _initialize() -> void:
	print("══ M1.5 세이브 구역·위치 추적·복원 검증 ══")

	# ── 실제 개발 세이브 백업(테스트 격리) ──
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))

	# ── ① 라운드트립: 나루 마을 어느 칸에서 저장 → 새 인스턴스가 그대로 재개 ──
	var m1: Node = await _spawn_main()
	m1.saver.delete_save()   # 백업했으니 깨끗한 새 게임에서 시작
	# 안식 농원 동쪽 가장자리(38,16)에서 나루 마을로 길 워프(building_test와 같은 경로).
	m1.player.position = m1._tile_center_px(Vector2i(38, 16))
	m1._maybe_warp_edge()
	await _settle()
	_check("①pre 동쪽 가장자리에서 나루 마을로 워프", m1._region == RegionCatalog.NARU_VILLAGE)
	# 마을 서쪽 복도(y=16)의 한 칸에 선 채 저장한다(스폰과 다른 자리 — '있던 자리' 복원 검증).
	var saved_tile := Vector2i(5, 16)
	m1.player.position = m1._tile_center_px(saved_tile)
	m1._save_game()
	_check("① 저장은 성공(세이브 파일 존재)", m1.saver.has_save())
	await _despawn(m1)

	# 새 인스턴스 — _ready가 세이브를 자동 복원한다("껐다 켜도 그대로").
	var m2: Node = await _spawn_main()
	_check("②a 구역 복원(나루 마을)", m2._region == RegionCatalog.NARU_VILLAGE)
	_check("②b 실내 모드 복원(바깥)", m2._indoor == "")
	_check("②c 위치 복원(저장한 칸 그대로)", m2._player_tile() == saved_tile)
	# 외부 카메라 경계가 복원 구역(마을) 크기에서 파생되는가(_apply_camera_limits 재적용).
	var vw: int = RegionCatalog.size_of(RegionCatalog.NARU_VILLAGE).x * m2.TILE
	_check("②d 외부 카메라 경계 = 마을 폭", m2._cam.limit_right == vw)
	await _despawn(m2)

	# ── ② 실내 모드 복원: 카페 안에서 저장 → 재개 시 실내·카메라 격리 ──
	var m3: Node = await _spawn_main()
	# 저장 데이터를 직접 구성해 카페 실내 상태를 박는다(나루 마을·카페 실내 칸).
	m3.saver.save_game({
		"region": RegionCatalog.NARU_VILLAGE,
		"indoor": "카페",
		"player_tile": m3.CAFE_IN_TILE,
	})
	await _despawn(m3)
	var m4: Node = await _spawn_main()
	_check("③a 카페 실내 모드 복원", m4._indoor == "카페")
	_check("③b 구역 복원(나루 마을)", m4._region == RegionCatalog.NARU_VILLAGE)
	_check("③c 카메라가 카페 방으로 격리(top=CAFE_CAM)",
		m4._cam.limit_top == m4.CAFE_CAM_RECT.position.y * m4.TILE)
	await _despawn(m4)

	# ── ③ 미지 구역 폴백: 안 지어진/알 수 없는 구역 id → 홈베이스 외부 스폰 ──
	var sm := SaveManager.new()
	sm.save_game({
		"region": "atlantis_does_not_exist",
		"indoor": "카페",
		"player_tile": Vector2i(7, 7),
	})
	sm.free()
	var m5: Node = await _spawn_main()
	_check("④a 미지 구역 → 홈베이스 폴백", m5._region == RegionCatalog.HOME)
	_check("④b 폴백은 실내 모드를 비운다(바깥)", m5._indoor == "")
	_check("④c 폴백 위치 = 홈베이스 스폰", m5._player_tile() == m5.SPAWN_TILE)
	# 폴백 후 외부 카메라가 홈베이스 크기 경계인지(빈 맵·격리방에 갇히지 않음).
	var hw: int = RegionCatalog.size_of(RegionCatalog.HOME).x * m5.TILE
	_check("④d 외부 카메라 경계 = 홈베이스 폭", m5._cam.limit_right == hw)
	await _despawn(m5)

	# ── 미빌드 stub 구역(저승 숲)도 미지와 같게 폴백되는가 ──
	# ★ M3.2 — 삼도천·황천해가 빌드돼 더는 stub이 아니다(정상 복원 — samdocheon/hwangcheonhae_test).
	#   여전히 stub인 저승 숲으로 폴백 불변식을 검사한다(다음 구역이 빌드되면 다음 stub으로 교체).
	var sm2 := SaveManager.new()
	sm2.save_game({"region": RegionCatalog.JEOSEUNG_FOREST, "indoor": "", "player_tile": Vector2i(2, 2)})
	sm2.free()
	var m6: Node = await _spawn_main()
	_check("⑤ 미빌드 stub 구역(저승 숲) → 홈베이스 폴백", m6._region == RegionCatalog.HOME)
	_check("⑤b stub 폴백 위치 = 홈베이스 스폰", m6._player_tile() == m6.SPAWN_TILE)
	await _despawn(m6)

	# ── 세이브 백업 복원(실제 개발 세이브 보존) ──
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
