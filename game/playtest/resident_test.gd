extends SceneTree
# ★ [S2-T7 / ADR-0060 결정 7] 주민 프레임워크 + 보간 걷기 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ① Resident 레코드의 스케줄 조회가 결정적이다(시각 → 자리).
#   ② ResidentWalk 보간이 경로를 실제로 훑고 0으로 수렴하며, 같은 delta 시퀀스면 같은 값이다.
#   ③ 레지스트리에 5인이 등록되고, **세이브 키가 옛 이름 그대로**다(하위호환 — 개명 금지).
#   ④ 미호 출퇴근 전환에서 **논리 위치가 즉시 스냅**한다 — 보간은 시각 레이어라 게임플레이
#      판정(말 걸기·농사 제외·기존 npc_station_test 단언)을 건드리지 않는다.
#   ⑤ 길 스포크: 같은 구역이면 메인 복도 경유 ㄱ자, 구역이 다르면 스포크 없음(즉시 도착).
#   ⑥ 마주 본 주민 판정의 가드(네오=실내 · 바나=가시성 · 옥자=통보 단계).
#   ⑦ [ADR-0060 결정 8] 네오 이중 신분 — 점주 레이어와 관계 트랙이 서로를 게이팅하지 않는다.
#   ⑧ 관계 탭 행이 레지스트리에서 파생된다(관계 트랙 보유 주민만·등록 순서).
#
# 실행: ./run_tests.sh resident   (헤드리스는 반드시 game/에서 · 순차)

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

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S2-T7 주민 프레임워크 + 보간 걷기 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ① Resident 레코드: 스케줄 조회(순수 단위 — 노드·씬 없이) ──
	print("── ① 스케줄 조회 ──")
	var r := Resident.new()
	r.id = "probe"
	r.schedule = [
		{"from_min": 0, "tile": Vector2i(1, 1), "region": "a"},
		{"from_min": 600, "tile": Vector2i(9, 9), "region": "b"},
	]
	_check("①a 이른 시각 = 첫 항목", r.station_tile(0) == Vector2i(1, 1))
	_check("①b 경계 직전 = 첫 항목", r.station_tile(599) == Vector2i(1, 1))
	_check("①c 경계 = 둘째 항목", r.station_tile(600) == Vector2i(9, 9))
	_check("①d 구역도 함께 갈린다", r.station_region(0) == "a" and r.station_region(700) == "b")
	_check("①e 미배치 초기값", r.tile == Resident.UNPLACED)
	_check("①f 관계 트랙 없으면 하트 0", r.hearts() == 0)

	# ── ② ResidentWalk: 경로를 훑고 0으로 수렴 · 결정적 ──
	print("── ② 보간 걷기 ──")
	var from_px := Vector2(0, 0)
	var path := PackedVector2Array([Vector2(100, 0), Vector2(100, 60)])
	var total := ResidentWalk.path_length(from_px, path)
	_check("②a 경로 총 길이 = 100+60", is_equal_approx(total, 160.0))
	var w := ResidentWalk.new()
	w.start(from_px, path)
	_check("②b 시작하면 걷는 중", w.is_walking())
	_check("②c 시작 오프셋 = 출발점 − 목적지", w.offset() == from_px - Vector2(100, 60))
	# 한 스텝 진행하면 남은 거리가 정확히 속도×delta만큼 준다(등속·결정적).
	w.advance(0.5)
	var moved := total - w.remaining_px()
	_check("②d 등속 진행(속도×delta)", is_equal_approx(moved, ResidentWalk.SPEED_PX * 0.5))
	_check("②e 걷는 중엔 오프셋 ≠ 0", w.offset() != Vector2.ZERO)
	# 같은 delta 시퀀스를 두 번 굴리면 같은 자리 — 난수·프레임 의존 없음.
	var seq := [0.1, 0.25, 0.033, 0.4]
	var a := ResidentWalk.new()
	var b := ResidentWalk.new()
	a.start(from_px, path)
	b.start(from_px, path)
	for d in seq:
		a.advance(d)
		b.advance(d)
	_check("②f 같은 delta 시퀀스 = 같은 오프셋(결정적)", a.offset() == b.offset())
	# 충분히 진행하면 정확히 목적지에 앉고 오프셋이 0으로 수렴한다(잔차 없음).
	a.advance(100.0)
	_check("②g 완주하면 걷기 종료", not a.is_walking())
	_check("②h 완주 오프셋 = 0(잔차 없음)", a.offset() == Vector2.ZERO)
	# 빈 경로 = 즉시 도착(종전 순간이동과 동일 — 스포크가 없는 전환의 폴백).
	var z := ResidentWalk.new()
	z.start(from_px, PackedVector2Array())
	_check("②i 빈 경로 = 안 걷는다(즉시 도착)", not z.is_walking() and z.offset() == Vector2.ZERO)

	# ── ③ 레지스트리 등록 + 세이브 키 하위호환 ──
	print("── ③ 레지스트리 ──")
	var m: Node = await _new_main()
	var ids := []
	for res in m._residents:
		ids.append(res.id)
	_check("③a 주민 5인 등록", m._residents.size() == 5)
	_check("③b 5인 = 미호·멜·바나·네오·옥자", ids == ["miho", "mel", "bana", "neo", "okja"])
	_check("③c id 조회", m._resident("mel") != null and m._resident("mel").display_name == "멜")
	_check("③d 이름 조회", m._resident_named("바나") != null and m._resident_named("바나").id == "bana")
	_check("③e 없는 id/이름 = null", m._resident("없음") == null and m._resident_named("없음") == null)
	# ★하위호환 — 옛 세이브 키가 그대로여야 기존 save.dat이 읽힌다.
	_check("③f 세이브 키 = 옛 이름 그대로",
		m._resident("miho").save_key == "affinity"
		and m._resident("mel").save_key == "mel_affinity"
		and m._resident("bana").save_key == "bana_affinity"
		and m._resident("neo").save_key == "neo_affinity")
	_check("③g 옥자는 관계 트랙 없음(세이브 키도 없음)",
		m._resident("okja").affinity == null and m._resident("okja").save_key == "")
	_check("③h 캐릭터 노드가 레코드에 물려 있다",
		m._resident("miho").node == m.miho and m._resident("neo").node == m.neo)
	# 선호 선물이 인스턴스별로 갈린다(미호=영혼 호박 · 멜=피안화 · 바나=혼령초).
	_check("③i 선호 선물 분산",
		m.affinity.preferred_crop == CropCatalog.YEONGHON_HOBAK
		and m.mel_affinity.preferred_crop == CropCatalog.PIANHWA
		and m.bana_affinity.preferred_crop == CropCatalog.HONRYEONGCHO)

	# ── ④ 스테이션 전환 = 논리 위치 즉시 스냅(보간은 시각 레이어 한정) ──
	print("── ④ 논리 위치 스냅 ──")
	m.clock.minutes = 6 * 60
	m._update_resident_stations(0.0)
	var r_miho: Resident = m._resident("miho")
	_check("④a 아침 = 밭 자리", r_miho.tile == m.MIHO_FIELD_TILE)
	_check("④b 노드 위치도 즉시 밭 중앙", m.miho.position == m._tile_center_px(m.MIHO_FIELD_TILE))
	m.clock.minutes = Cafe.OPEN_MIN
	m._update_resident_stations(0.0)
	_check("④c 15시 = 카페 자리", r_miho.tile == m.MIHO_CAFE_TILE)
	# ★ 전환 직후(보간이 있었다면 아직 걷는 중일 시점)에도 논리 위치는 이미 목적지다.
	_check("④d 전환 직후에도 노드 위치 = 목적지(순간 스냅)",
		m.miho.position == m._tile_center_px(m.MIHO_CAFE_TILE))
	_check("④e _miho_tile 별칭이 레지스트리를 따라간다", m._miho_tile == r_miho.tile)

	# ── ⑤ 길 스포크 ──
	print("── ⑤ 길 스포크 ──")
	var v_from := Vector2i(10, 20)
	var v_to := Vector2i(30, 25)
	var spokes: PackedVector2Array = m._road_spokes(v_from, v_to, RegionCatalog.NARU_VILLAGE)
	_check("⑤a 같은 구역 = 복도 경유 ㄱ자(경유점 3)", spokes.size() == 3)
	_check("⑤b 첫 경유점 = 출발 열 × 메인 복도",
		spokes.size() == 3 and spokes[0] == m._tile_center_px(Vector2i(v_from.x, m.MAIN_CORRIDOR_Y)))
	_check("⑤c 둘째 경유점 = 도착 열 × 메인 복도",
		spokes.size() == 3 and spokes[1] == m._tile_center_px(Vector2i(v_to.x, m.MAIN_CORRIDOR_Y)))
	_check("⑤d 마지막 = 목적지", spokes.size() == 3 and spokes[2] == m._tile_center_px(v_to))
	var same_col: PackedVector2Array = m._road_spokes(Vector2i(10, 20), Vector2i(10, 25), RegionCatalog.NARU_VILLAGE)
	_check("⑤e 같은 열이면 곧장 세로(경유점 1)", same_col.size() == 1)
	_check("⑤f 같은 칸 = 스포크 없음", m._road_spokes(v_from, v_from, RegionCatalog.NARU_VILLAGE).is_empty())
	_check("⑤g 도로 없는 구역 = 스포크 없음(즉시 도착)",
		m._road_spokes(v_from, v_to, RegionCatalog.HOME).is_empty())
	# 미호 출퇴근은 두 자리가 서로 다른 구역이라(농원 밭 ↔ 마을 카페) 스포크가 안 생긴다 =
	# 종전 순간이동 그대로 — 보간 도입이 기존 거동을 하나도 바꾸지 않았음을 못 박는다.
	_check("⑤h 미호 출퇴근(구역 넘김)은 걷기 없음",
		r_miho.walk == null or not r_miho.walk.is_walking())
	# 같은 구역 전환은 실제로 걷는다(레코드 하나를 손으로 굴려 프레임워크 경로를 탄다).
	var probe := Resident.new()
	probe.id = "probe2"
	probe.schedule = [{"from_min": 0, "tile": v_from, "region": RegionCatalog.NARU_VILLAGE}]
	probe.tile = v_from
	m._begin_resident_walk(probe, v_from, RegionCatalog.NARU_VILLAGE, v_to, RegionCatalog.NARU_VILLAGE)
	_check("⑤i 같은 구역 전환 = 걷기 시작", probe.walk != null and probe.walk.is_walking())
	m._advance_resident_walk(probe, 0.2)
	_check("⑤j 진행 중 오프셋 ≠ 0", probe.walk.offset() != Vector2.ZERO)
	m._advance_resident_walk(probe, 100.0)
	_check("⑤k 완주하면 오프셋 0", not probe.walk.is_walking() and probe.walk.offset() == Vector2.ZERO)
	# 구역이 다르면 도착지가 도로 있는 구역이어도 걷지 않는다(미호 출퇴근이 여기 걸린다).
	var probe2 := Resident.new()
	probe2.id = "probe3"
	m._begin_resident_walk(probe2, v_from, RegionCatalog.HOME, v_to, RegionCatalog.NARU_VILLAGE)
	_check("⑤l 구역 넘김은 걷기 없음(가드)", probe2.walk == null)

	# ── ⑥ 마주 본 주민 판정의 가드 ──
	print("── ⑥ facing 가드 ──")
	m._sleeping = false
	m._indoor = ""
	m._target = m.NEO_TILE
	_check("⑥a 네오는 만물상 밖에선 안 잡힌다", m._facing_resident() == null)
	m._indoor = "만물상"
	var faced: Resident = m._facing_resident()
	_check("⑥b 만물상 안에선 네오가 잡힌다", faced != null and faced.id == "neo")
	_check("⑥c 네오는 선물 채널 없음(풀 T1 트랙은 후속)", not faced.can_gift)
	_check("⑥d 네오는 [F] 훅 보유(매대)", faced.shop_key.is_valid())
	m._indoor = ""
	m._target = m.BANA_NIGHT_TILE
	m.bana.visible = false
	_check("⑥e 바나는 숨어 있으면 안 잡힌다(밤 전)", m._facing_resident() == null)
	m.bana.visible = true
	var faced_b: Resident = m._facing_resident()
	_check("⑥f 밤에 드러나면 바나가 잡힌다", faced_b != null and faced_b.id == "bana")
	_check("⑥g 바나는 선물 채널 있음", faced_b.can_gift)
	# 옥자: 통보 단계면 facing_gate가 막는다(신규 시작 = NOTICE).
	m._target = m.OKJA_CAFE_TILE
	m.okja.visible = true
	m.onboarding.step = Onboarding.NOTICE
	_check("⑥h 통보 단계 옥자는 안 잡힌다", m._facing_resident() == null)
	m.onboarding.step = Onboarding.MEET_MIHO
	m._update_resident_stations(0.0)   # 실제 프레임 순서: 스테이션 갱신 → facing 판정
	var faced_o: Resident = m._facing_resident()
	_check("⑥i 통보를 지나면 옥자가 잡힌다", faced_o != null and faced_o.id == "okja")
	_check("⑥j 옥자 관계 한 줄 = 고정 문구(호감도 없음)",
		m._resident_rel_line(faced_o) == "저승 카페 사장")
	_check("⑥k 미호 관계 한 줄 = 친밀도", m._resident_rel_line(r_miho).begins_with("친밀도"))
	# 자는 중엔 아무도 안 잡힌다(옛 not _sleeping 가드).
	m._sleeping = true
	_check("⑥l 자는 중엔 판정 없음", m._facing_resident() == null)
	m._sleeping = false
	m._target = Vector2i(-1, -1)

	# ── ⑦ [ADR-0060 결정 8] 네오 이중 신분 — 두 레이어가 서로를 게이팅하지 않는다 ──
	print("── ⑦ 네오 이중 신분 ──")
	var r_neo: Resident = m._resident("neo")
	m.neo_affinity.points = 0
	_check("⑦a ♡0이어도 점주 레이어(매대 훅)는 살아 있다",
		r_neo.shop_key.is_valid() and r_neo.affinity.hearts() == 0)
	m.neo_affinity.points = r_neo.affinity.MAX_POINTS
	_check("⑦b ♡만렙이어도 선물·하트 이벤트 채널이 자동으로 안 열린다", not r_neo.can_gift)
	_check("⑦c 점주 훅과 관계 트랙이 별개 필드(상호 참조 없음)",
		r_neo.shop_key.is_valid() and r_neo.affinity != null)
	m.neo_affinity.points = 0

	# ── ⑧ 관계 탭 행이 레지스트리에서 파생 ──
	print("── ⑧ 관계 탭 ──")
	var rows: Array = m._heart_rows()
	var names := []
	for row in rows:
		names.append(String(row["name"]))
	_check("⑧a 관계 트랙 보유 4인만(옥자 제외)", names == ["미호", "멜", "바나", "네오"])
	_check("⑧b 곱셈기 효과 줄이 채워진다",
		rows.size() == 4 and String(rows[0]["effect"]) != "" and String(rows[3]["effect"]) != "")

	# ── ⑨ 세이브 왕복: 4인 호감도가 옛 키로 저장·복원된다 ──
	print("── ⑨ 세이브 왕복 ──")
	m.affinity.points = 1 * Affinity.POINTS_PER_HEART
	m.mel_affinity.points = 2 * Affinity.POINTS_PER_HEART
	m.bana_affinity.points = 3 * Affinity.POINTS_PER_HEART
	m.neo_affinity.points = 4 * Affinity.POINTS_PER_HEART
	m._save_game()
	m.free()

	var m2: Node = await _new_main()   # _ready가 has_save()를 보고 자동 복원
	_check("⑨a 미호(키 affinity) 복원", m2.affinity.hearts() == 1)
	_check("⑨b 멜(키 mel_affinity) 복원", m2.mel_affinity.hearts() == 2)
	_check("⑨c 바나(키 bana_affinity) 복원", m2.bana_affinity.hearts() == 3)
	_check("⑨d 네오(키 neo_affinity) 복원", m2.neo_affinity.hearts() == 4)
	# 키가 없는 구세이브 = 그 주민만 ♡0(무막힘). 로드 경로를 직접 태워 본다.
	for res in m2._residents:
		if res.affinity != null:
			res.affinity.points = 0
	m2._load_game()
	_check("⑨e 재로드도 같은 값(멱등)",
		m2.affinity.hearts() == 1 and m2.neo_affinity.hearts() == 4)

	# ── ⑩ main.tscn 무수정 등록 — 신규 주민(T8 모찌)이 실제로 탈 길 ──
	print("── ⑩ 노드 자동 생성 ──")
	var spawn := Resident.new()
	spawn.id = "probe_spawn"
	spawn.display_name = "테스트주민"
	spawn.script_path = "res://miho.gd"   # 몸은 아무 주민 스크립트나 — 여기선 *생성 경로*만 본다
	spawn.needs_affinity = true
	spawn.schedule = [{"from_min": 0, "tile": Vector2i(5, 5), "region": ""}]
	m2._register_resident(spawn)
	_check("⑩a 캐릭터 노드가 생겨 트리에 붙는다", spawn.node != null and spawn.node.is_inside_tree())
	_check("⑩b 관계 트랙(Affinity)도 함께 생긴다", spawn.affinity != null)
	_check("⑩c 첫 자리에 세워진다",
		spawn.tile == Vector2i(5, 5) and spawn.node.position == m2._tile_center_px(Vector2i(5, 5)))
	_check("⑩d 레지스트리에서 이름으로 찾힌다", m2._resident_named("테스트주민") == spawn)
	# 이후 프레임에 영향 없게 걷어낸다(테스트 전용 정리).
	m2._residents.erase(spawn)
	m2._residents_by_id.erase(spawn.id)
	spawn.node.queue_free()
	spawn.affinity.queue_free()
	m2.free()

	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
