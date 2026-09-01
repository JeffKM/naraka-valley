extends SceneTree
# ★[S10-T5 / ADR-0069 결정 8] 늘봄방(온실) 단위검증 — **면제 불변식이 이 스위트의 본론**이다.
#
# ADR-0069 결정 8이 늘봄방에 건 약속 넷을 각각 못박는다:
#   ㉠ 절기 전환 아침에 **무사멸**(비제철 작물도 산다)
#   ㉡ 까마귀·잡초 재점령 **무해**
#   ㉢ 스프링클러 **호환**(지상과 같은 자동 급수)
#   ㉣ 절기 무관 **파종 가능**
# 넷 다 "필터로 걸렀나"가 아니라 **구조로 성립하나**를 본다: 늘봄방 밭이 별개 FarmField
# 인스턴스(main.greenhouse_farm)라 노지 순회(절기 사멸·까마귀·잡초)가 애초에 닿지 못한다.
# 여기에 해금 게이트·세이브 하위호환·구세이브 무손상을 더한다.
# 실행: godot --headless --path game --script res://playtest/greenhouse_test.gd

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	return m

func _dismiss_intro(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

# 늘봄방을 즉시 세운다 — 원장에 완공을 박고 실효 헬퍼를 부른다(완공 아침과 같은 경로).
func _build_greenhouse(m: Node) -> void:
	m.carpenter.load_save({"active": [], "done": [Carpenter.PROJ_GREENHOUSE]})
	m._refresh_greenhouse()

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S10-T5 늘봄방(온실) 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ═══ ① 카탈로그 — 목공방 원장의 다섯째 행(기존 넷은 바이트 불변) ═══
	_check("① 늘봄방이 건축 카탈로그에 있다", Carpenter.has_project(Carpenter.PROJ_GREENHOUSE))
	_check("①b 표시명 = 로스터 기정 명명 「늘봄방」",
		Carpenter.name_of(Carpenter.PROJ_GREENHOUSE) == "늘봄방")
	_check("①c 기존 4건이 그대로 살아 있다(데이터 1건 추가가 전부)",
		Carpenter.ids().size() == 5 and Carpenter.has_project(Carpenter.PROJ_BIG_COOP)
		and Carpenter.has_project(Carpenter.PROJ_BIG_BARN)
		and Carpenter.has_project(Carpenter.PROJ_MASTER_ROOM)
		and Carpenter.has_project(Carpenter.PROJ_STABLE))
	_check("①d 마구간 비용·공기 불변(10000냥·원목100·주괴5·2일 — 기존 행 회귀 0)",
		Carpenter.gold_cost(Carpenter.PROJ_STABLE) == 10000
		and Carpenter.wood_cost(Carpenter.PROJ_STABLE) == 100
		and Carpenter.ingot_cost(Carpenter.PROJ_STABLE) == 5
		and Carpenter.build_days(Carpenter.PROJ_STABLE) == 2)
	_check("①e 늘봄방은 Ranch 무관 프로젝트(building=\"\")",
		Carpenter.building_of(Carpenter.PROJ_GREENHOUSE) == "")
	_check("①f 늘봄방은 주괴를 안 쓴다(원목만)", Carpenter.ingot_cost(Carpenter.PROJ_GREENHOUSE) == 0)

	# ═══ ② 미건축 상태 — 세계가 종전과 같다(등록 0·방 0·라우터는 노지로) ═══
	var m0: Node = await _new_main()
	_dismiss_intro(m0)
	_check("② 짓기 전엔 늘봄방이 건물 카탈로그에 없다", not m0._buildings.has("늘봄방"))
	_check("②b 짓기 전엔 _greenhouse_built() 거짓", not m0._greenhouse_built())
	var plot_center := main_plot_center(m0)
	_check("②c 짓기 전 경작면 좌표는 밭이 아니다(VOID)", not m0._is_farmable(plot_center))
	_check("②d 짓기 전 라우터는 노지 밭을 돌려준다", m0._field_at(plot_center) == m0.farm)
	_check("②e 늘봄방 밭 인스턴스는 처음부터 살아 있다(빈 채 — 라우터가 null을 안 만난다)",
		m0.greenhouse_farm != null and m0.greenhouse_farm.tilled_tiles().is_empty())
	m0.free()

	# ═══ ③ 완공 — 실내 구역 신설(방·문·카메라·10×8 경작면) ═══
	var m: Node = await _new_main()
	_dismiss_intro(m)
	m.clock.minutes = 10 * 60
	_build_greenhouse(m)
	_check("③ 완공 후 건물 카탈로그에 늘봄방 등록", m._buildings.has("늘봄방"))
	_check("③b 실내 카메라가 방 둘레로 잡힌다", m._buildings["늘봄방"]["cam"] == m.GREENHOUSE_CAM_RECT)
	_check("③c 진입 착지 칸은 **경작면이 아니라 통로**다(들어서자마자 작물 위 X)",
		not m.GREENHOUSE_PLOT_RECT.has_point(m.GREENHOUSE_IN_TILE))
	_check("③d 경작면이 10×8", m.GREENHOUSE_PLOT_RECT.size == Vector2i(10, 8))
	# 경작면 전 칸이 farmable(SOIL)이고 라우터가 늘봄방 밭을 가리킨다.
	var all_farmable := true
	var all_routed := true
	for gx in range(m.GREENHOUSE_PLOT_RECT.position.x, m.GREENHOUSE_PLOT_RECT.end.x):
		for gy in range(m.GREENHOUSE_PLOT_RECT.position.y, m.GREENHOUSE_PLOT_RECT.end.y):
			var t := Vector2i(gx, gy)
			if not m._is_farmable(t):
				all_farmable = false
			if m._field_at(t) != m.greenhouse_farm:
				all_routed = false
	_check("③e 경작면 80칸이 전부 farmable(SOIL)", all_farmable)
	_check("③f 경작면 80칸이 전부 늘봄방 밭으로 라우팅", all_routed)
	_check("③g 노지 스타터 패치는 여전히 노지 밭으로 라우팅(라우터가 안 샌다)",
		m._field_at(Vector2i(41, 13)) == m.farm)
	_check("③h 통로 행(진입 칸)은 경작면이 아니다", m._field_at(m.GREENHOUSE_IN_TILE) == m.farm)
	# 방 둘레가 실제로 벽으로 서 있다(못 빠져나간다).
	_check("③i 방 둘레가 벽(SOLID)",
		m.is_solid(m._grid[m.GREENHOUSE_RECT.position.y][m.GREENHOUSE_RECT.position.x + 3])
		and m.is_solid(m._grid[m.GREENHOUSE_RECT.position.y + 3][m.GREENHOUSE_RECT.position.x]))
	_check("③j 실내 문 2칸은 열려 있다(퇴장 트리거)",
		not m.is_solid(m._grid[m.GREENHOUSE_DOOR.y][m.GREENHOUSE_DOOR.x])
		and not m.is_solid(m._grid[m.GREENHOUSE_DOOR_E.y][m.GREENHOUSE_DOOR_E.x]))

	# ═══ ④ 절기 무관 파종 + 절기 전환 아침 **무사멸**(㉠·㉣) ═══
	# 성야절(계절 3) 전용 작물이 아닌, 지금 절기와 어긋나는 작물을 고른다 — 노지에선 절기 전환에
	# 스러지는 그 작물이 늘봄방에선 살아남는 것을 대조로 본다.
	var season_now: int = GameClock.season_index_for_day(m.clock.day)
	var next_season := (season_now + 1) % 4
	var off_crop := ""
	for cid in CropCatalog.ids():
		var c := String(cid)
		if CropCatalog.is_multi_seasonal(c) or CropCatalog.is_wild(c):
			continue
		if not CropCatalog.in_season(c, next_season):
			off_crop = c
			break
	_check("④ 다음 절기에 스러질 작물을 하나 찾았다(대조군)", off_crop != "")
	var gt := Vector2i(m.GREENHOUSE_PLOT_RECT.position.x + 1, m.GREENHOUSE_PLOT_RECT.position.y + 1)
	var nt := Vector2i(41, 13)   # 노지 스타터 패치
	_check("④b 늘봄방 칸을 괭이질할 수 있다", m.greenhouse_farm.hoe(gt))
	_check("④c 절기와 무관하게 파종된다(in_season 게이트 우회)", m.greenhouse_farm.plant(gt, off_crop))
	m.farm.hoe(nt)
	m.farm.plant(nt, off_crop)
	# 절기 첫날 아침으로 넘긴다(day를 다음 절기 첫날로 세팅 후 아침 정산 훅 직접 호출).
	var next_first: int = m.clock.day + (GameClock.DAYS_PER_SEASON - GameClock.day_of_season(m.clock.day) + 1)
	m.clock.day = next_first
	_check("④d 검증일이 실제 절기 전환일", GameClock.is_season_first_day(next_first))
	m._on_day_advanced(next_first)
	_check("④e ㉠ 늘봄방 작물은 절기 전환 아침에 **살아남는다**",
		m.greenhouse_farm.is_planted(gt) and m.greenhouse_farm.crop_of(gt) == off_crop)
	_check("④f (대조) 같은 작물이 노지에선 스러진다 — 면제가 진짜임을 대조로 확인",
		not m.farm.is_planted(nt))

	# ═══ ⑤ 까마귀 무해(㉡) — 습격 후보 목록에 늘봄방 칸이 아예 안 든다 ═══
	# 문턱(15포기)을 넘기려면 노지에 충분히 심어야 한다. 늘봄방에도 여러 칸 심고 후보를 본다.
	for i in range(2, 8):
		var g2 := Vector2i(m.GREENHOUSE_PLOT_RECT.position.x + i, m.GREENHOUSE_PLOT_RECT.position.y + 1)
		m.greenhouse_farm.hoe(g2)
		m.greenhouse_farm.plant(g2, CropCatalog.HONRYEONGCHO)
	for j in range(0, 20):
		var n2 := Vector2i(40 + (j % 5), 12 + (j / 5))
		m.farm.hoe(n2)
		m.farm.plant(n2, CropCatalog.HONRYEONGCHO)
	var crow_targets: Array = m._crow_target_tiles()
	var gh_in_crow := false
	for ct in crow_targets:
		if m.GREENHOUSE_PLOT_RECT.has_point(ct):
			gh_in_crow = true
	_check("⑤ ㉡ 까마귀 습격 후보에 늘봄방 칸이 하나도 없다(순회가 노지 밭만 돈다)",
		not gh_in_crow and crow_targets.size() >= 15)
	# 잡초 확산 목적지 분류도 노지 밭만 본다 — 늘봄방 칸은 재점령 스캔 rect 밖이다.
	_check("⑤b ㉡ 잡초 재점령 스캔 구역이 늘봄방 경작면과 안 겹친다",
		not m.ENCROACH_SCAN_RECT.intersects(m.GREENHOUSE_PLOT_RECT))

	# ═══ ⑥ 스프링클러 호환(㉢) — 늘봄방 안에 세우고 아침 급수가 실제로 든다 ═══
	var spr_at := Vector2i(m.GREENHOUSE_PLOT_RECT.position.x + 1, m.GREENHOUSE_PLOT_RECT.position.y + 3)
	var spr_target := spr_at + Vector2i(1, 0)
	m.greenhouse_farm.hoe(spr_target)
	m.greenhouse_farm.plant(spr_target, CropCatalog.HONRYEONGCHO)
	_check("⑥ 늘봄방 경작면에 스프링클러를 세울 수 있다", m._can_place_sprinkler(spr_at))
	m.sprinkler.place(spr_at)
	var grown_before: int = m.greenhouse_farm.grown_days_of(spr_target)
	m._on_day_advanced(m.clock.day + 1)
	# ★[폴리시 R9] 급수 지점이 `advance_day` **뒤**로 옮겨졌다(#2 — 혼우가 R8에서 옮겨 간 그 자리와
	#   나란히). 그래서 설치 첫 아침은 "젖은 채 끝나고", +1은 다음 아침에 붙는다. 지상 밭의
	#   `sprinkler_test` ③a~③c가 잠근 그 계약을 늘봄방에서도 같은 모양으로 확인한다 —
	#   ㉢("스프링클러 호환")이 보증하는 건 *같은 날 성장*이 아니라 **지상과 같은 사이클**이다.
	_check("⑥b ㉢ 첫 아침 정산이 끝난 시점에 늘봄방 스프링클러 칸이 젖어 있다(지상과 같은 시점)",
		m.greenhouse_farm.is_watered(spr_target)
		and m.greenhouse_farm.grown_days_of(spr_target) == grown_before)
	m._on_day_advanced(m.clock.day + 2)
	_check("⑥b' ㉢ 그 물이 다음 아침 성장에 실리고 같은 아침에 다시 젖는다(정상상태 = 하루 +1)",
		m.greenhouse_farm.grown_days_of(spr_target) > grown_before
		and m.greenhouse_farm.is_watered(spr_target))
	# 손 물주기·성장 사슬도 그대로 산다(급수 없는 칸은 안 자란다 = 급수가 실효라는 반증).
	var dry_t := Vector2i(m.GREENHOUSE_PLOT_RECT.position.x + 8, m.GREENHOUSE_PLOT_RECT.position.y + 5)
	m.greenhouse_farm.hoe(dry_t)
	m.greenhouse_farm.plant(dry_t, CropCatalog.HONRYEONGCHO)
	var dry_before: int = m.greenhouse_farm.grown_days_of(dry_t)
	m._on_day_advanced(m.clock.day + 3)
	_check("⑥c 물 안 준 늘봄방 칸은 안 자란다(급수가 진짜 원인)",
		m.greenhouse_farm.grown_days_of(dry_t) == dry_before)
	_check("⑥d 늘봄방 칸에 손 물주기가 든다", m.greenhouse_farm.water(dry_t))

	# ═══ ⑦ 잿눈(성장 정지)은 **노지만** — 늘봄방엔 하늘이 없다 ═══
	# 잿눈 날을 찾아 그날 아침에 두 밭을 나란히 굴린다.
	var snow_day := -1
	for d in range(m.clock.day + 1, m.clock.day + 200):
		if not Weather.grows_crops(Weather.weather_for_day(d)):
			snow_day = d
			break
	if snow_day > 0:
		var gsnow := Vector2i(m.GREENHOUSE_PLOT_RECT.position.x + 3, m.GREENHOUSE_PLOT_RECT.position.y + 6)
		var nsnow := Vector2i(44, 16)
		m.greenhouse_farm.hoe(gsnow)
		m.greenhouse_farm.plant(gsnow, CropCatalog.HONRYEONGCHO)
		m.greenhouse_farm.water(gsnow)
		m.farm.hoe(nsnow)
		m.farm.plant(nsnow, CropCatalog.HONRYEONGCHO)
		m.farm.water(nsnow)
		var gb: int = m.greenhouse_farm.grown_days_of(gsnow)
		var nb: int = m.farm.grown_days_of(nsnow)
		m.clock.day = snow_day
		m._on_day_advanced(snow_day)
		_check("⑦ 잿눈 날 늘봄방 작물은 그대로 자란다", m.greenhouse_farm.grown_days_of(gsnow) > gb)
		_check("⑦b (대조) 같은 날 노지 작물은 성장이 멈춘다", m.farm.grown_days_of(nsnow) == nb)
	else:
		_check("⑦ 잿눈 날을 200일 안에서 찾았다", false)

	# ═══ ⑧ 세이브 — 신규 슬라이스 키 + 구세이브(키 없음) 무손상 ═══
	m._save_game()
	var blob: Dictionary = cleaner.load_game()
	_check("⑧ 세이브에 greenhouse 슬라이스 키가 있다", blob.has("greenhouse"))
	_check("⑧b 늘봄방 건축 여부는 carpenter 원장이 든다(플래그 신설 0)",
		blob.has("carpenter") and not blob.has("greenhouse_built"))
	var gh_tiles: int = m.greenhouse_farm.tilled_tiles().size()
	m.free()
	var m2: Node = await _new_main()
	_check("⑧c 재개하면 늘봄방이 그대로 서 있다", m2._greenhouse_built() and m2._buildings.has("늘봄방"))
	_check("⑧d 늘봄방 경작면이 통째로 복원된다", m2.greenhouse_farm.tilled_tiles().size() == gh_tiles)
	_check("⑧e 복원 후에도 라우터가 늘봄방 밭을 가리킨다",
		m2._field_at(main_plot_center(m2)) == m2.greenhouse_farm)
	m2.free()

	# 구세이브(greenhouse·carpenter 키 없음) 로드 = 미건축·빈 상태로 무손상.
	cleaner.delete_save()
	var m3: Node = await _new_main()
	_dismiss_intro(m3)
	m3._save_game()
	var old_blob: Dictionary = cleaner.load_game()
	old_blob.erase("greenhouse")
	old_blob.erase("garden_pot")
	old_blob.erase("carpenter")
	cleaner.save_game(old_blob)
	m3.free()
	var m4: Node = await _new_main()
	_check("⑨ 구세이브(키 없음) 로드 — 늘봄방 미건축", not m4._greenhouse_built())
	_check("⑨b 구세이브 로드 — 늘봄방 경작면 빈 상태(무손상)", m4.greenhouse_farm.tilled_tiles().is_empty())
	_check("⑨c 구세이브 로드 — 건물 카탈로그에 늘봄방 없음(없는 방으로 워프 0)",
		not m4._buildings.has("늘봄방"))
	_check("⑨d 구세이브 로드 — 노지 밭 사슬은 멀쩡", m4.farm != null and m4._field_at(Vector2i(41, 13)) == m4.farm)
	m4.free()

	# ═══ ⑩ [폴리시 R2] 로드가 원장을 **되감는** 방향 — 유령 늘봄방 행 ═══
	# 완공한 세션 안에서 F9로 완공 전 세이브를 되불러 오면 carpenter는 미완공으로 돌아가는데,
	# `_refresh_greenhouse`는 첫 줄에서 그냥 return이라 `_buildings`에 늘봄방 행이 그대로 남았다.
	# 그리드는 방을 안 세우므로(`_build_grid`의 조건부 블록) 문 칸을 밟으면 없는 방으로 워프해
	# 실내 밴드 VOID에 갇혔다(퇴장 문에도 못 닿는 소프트락). 카탈로그를 로드에서 **무조건 다시
	# 파는 것**으로 두 방향(생김·사라짐)이 모두 원장 파생이 됐다.
	var m5: Node = await _new_main()
	_dismiss_intro(m5)
	m5.carpenter.load_save({"active": [], "done": []})
	m5._save_game()                       # ← 완공 **전** 세이브를 만든다
	_build_greenhouse(m5)                 # 그 세션 안에서 완공
	_check("⑩pre 완공 직후 — 카탈로그에 늘봄방 행이 섰다",
		m5._greenhouse_built() and m5._buildings.has("늘봄방"))
	m5._load_game()                       # F9 — 완공 전 세이브를 되불러 온다
	_check("⑩a 로드로 원장이 되감겼다(미완공)", not m5._greenhouse_built())
	_check("⑩b **유령 늘봄방 행이 남지 않는다** — 없는 방으로 워프할 문이 사라졌다",
		not m5._buildings.has("늘봄방"))
	_check("⑩c 그리드와 카탈로그가 같은 답을 한다(둘 다 방을 안 세운다)",
		not m5._buildings.has("늘봄방") and not m5._greenhouse_built())
	_build_greenhouse(m5)
	_check("⑩d 다시 완공하면 행이 되돌아온다(가드가 한 방향으로만 굳지 않는다)",
		m5._buildings.has("늘봄방") and m5._greenhouse_built())
	m5.free()

	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)

# 경작면 한가운데 칸(라우터 검증용 대표 좌표).
func main_plot_center(m: Node) -> Vector2i:
	return m.GREENHOUSE_PLOT_RECT.position + m.GREENHOUSE_PLOT_RECT.size / 2
