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
#   ⑨ 세이브 왕복이 옛 키로 돈다. ⑩ 레코드가 노드를 낳는 길(main.tscn 무수정)이 살아 있다.
#
# ★ [S2-T8] ⑪ 모찌 — 위 절차를 실제로 탄 **첫 T1 주민**의 종단 검증:
#   등록·런타임 노드 생성 → 스케줄 3자리(집 앞·광장·카페) 시각 판정 → **같은 구역 전환의 보간
#   걷기 첫 실동작**(복도 스포크 경유·결정적·오프셋 0 수렴) → 실내 자리는 안 걷는 가드 →
#   대화 4묶음 하트 게이팅 → 선물 선호 배수·하루 1회 → 세이브 왕복(신규 키 mochi_affinity)과
#   구세이브 하위호환 → **기존 5인 거동 불변**. 이 섹션이 통과하면 "1인 추가 = 파일 1 + 레코드 1"
#   주장이 실증된 것이다(ADR-0060 결정 7).
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

# ★[S8-T2] 그 아이템이 든 슬롯을 손에 든다(선물 입력 = 든 아이템 문법 — 없으면 1개 넣고 든다).
func _hold(m: Node, id: String) -> void:
	if not m.inventory.has_item(id):
		m.inventory.add_item(id, 1)
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

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
	# ★ [S2-T8] 모찌가 여섯째로 붙었다(레코드 1건 — main.tscn 무수정). 앞 5인의 **순서는 불변**이라
	#   facing 판정 순서·관계 탭 순서가 그대로다(신규는 뒤에만 붙는다).
	# ★[S5-T3 / ADR-0063 결정 6] 8 → 9: 풀무(대장간 점주)가 아홉째로 붙었다(의도적 불변식 개정).
	# ★[S6-T7 / ADR-0064 결정 8] 10 → 11: 주방요괴(카페 T3 배경 직원)가 열한째로 붙었다(의도적
	#   불변식 개정). **관계 트랙 0**인 첫 등록이라 이 한 건이 프레임워크의 "affinity 없이도 주민"
	#   경로(옥자)를 script_path 생성 경로와 함께 처음으로 태운다.
	# ★[S9b-T1 / ADR-0068 결정 3] 11 → 12: 깨비(조연 코러스 첫 온보딩)가 **주방요괴 바로 앞**에
	#   붙었다(의도적 불변식 개정). 그 자리인 이유는 두 좌표 불변식의 교집합이라서다 — 앞 10인의
	#   인덱스 불변(guild_test `_residents[9] == mugol`) + 주방요괴가 마지막(side_dish_test).
	_check("③a 주민 12인 등록(★T8 모찌 · ★S3-T5 뱃사공 · ★S4-T7 옹이 · ★S5-T3 풀무 · ★S5-T6 무골 · ★S6-T7 주방요괴 · ★S9b-T1 깨비 추가)",
		m._residents.size() == 12)
	_check("③b 12인 = 미호·멜·바나·네오·옥자·모찌·뱃사공·옹이·풀무·무골·깨비·주방요괴",
		ids == ["miho", "mel", "bana", "neo", "okja", "mochi", "boatman", "ongi", "pulmu",
			"mugol", "kkaebi", "kitchen_youkai"])
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
	# ★[S8-T2] 선호는 인스턴스 필드(preferred_crop)가 아니라 GiftPrefs 테이블이 든다 — 옛 3인
	#   배정은 러브 등급으로 그대로 승계됐다(선물 경제 분산 보존).
	_check("③i 선호 선물 분산(GiftPrefs 러브 승계)",
		GiftPrefs.tier_of("miho", CropCatalog.YEONGHON_HOBAK) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("mel", CropCatalog.PIANHWA) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("bana", CropCatalog.HONRYEONGCHO) == GiftPrefs.LOVE)

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
	_check("⑥c 네오도 선물 채널 보유(★S8-T2 개방 — 옛 단언 '채널 없음'을 뒤집는다)", faced.can_gift)
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
	# ★[S8-T2] 선물 채널은 열렸지만 **하트에서 파생되지 않는다** — 레코드가 든 결정이라 ♡0에서도
	#   ♡만렙에서도 같다(옛 단언 "만렙이어도 안 열린다"를 뒤집되 독립성 주장은 그대로 지킨다).
	_check("⑦b 선물 채널은 하트 파생이 아니다(♡만렙·♡0 모두 같은 값)", r_neo.can_gift)
	_check("⑦c 점주 훅과 관계 트랙이 별개 필드(상호 참조 없음)",
		r_neo.shop_key.is_valid() and r_neo.affinity != null)
	m.neo_affinity.points = 0

	# ── ⑧ 관계 탭 행이 레지스트리에서 파생 ──
	print("── ⑧ 관계 탭 ──")
	var rows: Array = m._heart_rows()
	var names := []
	for row in rows:
		names.append(String(row["name"]))
	# ★[S8-T1 / ADR-0066 결정 11] 표시 자격 = **관계 트랙 보유 하나**로 갈렸다(옛 조건은 트랙 AND
	#   효과 줄이라 곱셈기 없는 주민 셋을 탭에서 지웠다). 옥자·주방요괴는 설계상 트랙이 없어 계속 제외.
	# ★[S9b-T1] 9 → 10: 깨비가 관계 트랙 보유자로 합류(등록 순서 = 표시 순서라 무골 뒤·꼬리에 선다).
	_check("⑧a 관계 트랙 보유 10인 전원(옥자·주방요괴만 제외)",
		names == ["미호", "멜", "바나", "네오", "모찌", "뱃사공", "옹이", "풀무", "무골", "깨비"])
	# ★[S8-T9] 선물 리듬 꼬리("이번 주 선물 n/2")가 붙어 곱셈기 없는 주민도 줄이 선다 — 곱셈기
	#   유무는 꼬리 **앞**에 무엇이 있느냐로 읽는다(frame_test ③b′와 같은 기준).
	_check("⑧b 곱셈기 보유자에게만 효과 줄(미호·옹이=곱셈기+꼬리 · 모찌·무골=선물 꼬리만)",
		rows.size() == 10
		and String(rows[0]["effect"]).contains(" · 이번 주 선물")
		and String(rows[6]["effect"]).contains(" · 이번 주 선물")
		and String(rows[4]["effect"]).begins_with("이번 주 선물")
		and String(rows[8]["effect"]).begins_with("이번 주 선물"))

	# ── ⑨ 세이브 왕복: 4인 호감도가 옛 키로 저장·복원된다 ──
	print("── ⑨ 세이브 왕복 ──")
	# ★[S8-T5] 하트 = stage(진급 칸) — 점수와 함께 stage도 세팅해야 하트가 선다(관문은 heart_gate_test).
	m.affinity.points = 1 * Affinity.POINTS_PER_HEART
	m.affinity.stage = 1
	m.mel_affinity.points = 2 * Affinity.POINTS_PER_HEART
	m.mel_affinity.stage = 2
	m.bana_affinity.points = 3 * Affinity.POINTS_PER_HEART
	m.bana_affinity.stage = 3
	m.neo_affinity.points = 4 * Affinity.POINTS_PER_HEART
	m.neo_affinity.stage = 4
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
			res.affinity.stage = 0   # ★[S8-T5] 하트 = stage — 재로드 멱등 검증도 stage로 본다
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

	# ── ⑪ [S2-T8] 모찌 — 위 절차를 실제로 탄 첫 T1 주민 ──
	# ⑩이 "길이 있다"를 보였다면 여기서는 그 길로 **진짜 주민 한 명이 굴러가는지**를 본다.
	print("── ⑪ 모찌(첫 T1 주민) ──")
	var r_mochi: Resident = m2._resident("mochi")
	_check("⑪a 레코드 등록", r_mochi != null and r_mochi.display_name == "모찌")
	_check("⑪b 몸이 런타임 생성돼 트리에 붙는다(main.tscn 무수정)",
		r_mochi.node != null and r_mochi.node.is_inside_tree() and r_mochi.node is Mochi)
	_check("⑪c 관계 트랙(Affinity)도 함께 생긴다", r_mochi.affinity != null)
	_check("⑪d 신규 세이브 키", r_mochi.save_key == "mochi_affinity")
	_check("⑪e 선물 채널 있음 · 선호 = 황천포도(과일 = 모찌 정체성 — ★S8-T2 GiftPrefs 러브)",
		r_mochi.can_gift and GiftPrefs.tier_of("mochi", CropCatalog.HWANGCHEON_PODO) == GiftPrefs.LOVE)
	_check("⑪f 초상화 없음(도트 눈입은 T10 아트)", r_mochi.portrait_stem == "")
	_check("⑪g 관계 곱셈기 없음(ADR-0008 메인 4인 독점)", not r_mochi.effect_fn.is_valid())

	# 스케줄 3자리 — 시각별 판정(집 앞 → 광장 → 카페). 좌표는 레코드가 소유하므로 여기선
	# 스케줄에서 되읽어 비교한다(main에 상수를 새로 심지 않은 설계 그대로).
	var t_home: Vector2i = r_mochi.schedule[0]["tile"]
	var t_plaza: Vector2i = r_mochi.schedule[1]["tile"]
	var t_cafe: Vector2i = r_mochi.schedule[2]["tile"]
	_check("⑪h 세 자리가 전부 다른 칸", t_home != t_plaza and t_plaza != t_cafe)
	_check("⑪i 집 앞 = 주민 집 4 문 바로 아래(남향 진입 칸)",
		t_home == m2.RESIDENT_HOUSE_DOORS[3] + Vector2i(0, 1))
	_check("⑪j 광장은 통행 레인을 안 막는다(복도 y36·다리 스파인 x52·53 비껴감)",
		t_plaza.y != m2.MAIN_CORRIDOR_Y and not (t_plaza.x in m2.BRIDGE_X))
	_check("⑪k 카페 자리는 실내 카페 방 안 · 좌석/직원 줄과 안 겹침",
		m2.CAFE_RECT.has_point(t_cafe) and not (t_cafe in m2.SEAT_TILES)
		and t_cafe != m2.MEL_TILE and t_cafe != m2.MIHO_CAFE_TILE and t_cafe != m2.OKJA_CAFE_TILE)
	_check("⑪l 세 자리 모두 나루 마을 구역", r_mochi.station_region(6 * 60) == RegionCatalog.NARU_VILLAGE
		and r_mochi.station_region(12 * 60) == RegionCatalog.NARU_VILLAGE
		and r_mochi.station_region(20 * 60) == RegionCatalog.NARU_VILLAGE)
	_check("⑪m 아침(06:00) = 집 앞", r_mochi.station_tile(GameClock.START_MIN) == t_home)
	_check("⑪n 낮(12:00) = 광장", r_mochi.station_tile(12 * 60) == t_plaza)
	_check("⑪o 저녁(20:00) = 카페", r_mochi.station_tile(20 * 60) == t_cafe)

	# ★ 같은 구역 전환 = 보간 걷기의 첫 실동작. 논리 위치는 즉시 스냅하고 그림만 뒤따른다.
	m2.clock.minutes = GameClock.START_MIN
	m2._update_resident_stations(0.0)
	_check("⑪p 아침 배치 = 집 앞(논리·노드 동시)",
		r_mochi.tile == t_home and r_mochi.node.position == m2._tile_center_px(t_home))
	m2.clock.minutes = 10 * 60
	m2._update_resident_stations(0.0)
	_check("⑪q 낮 전환 = 논리 위치 즉시 광장(스냅)",
		r_mochi.tile == t_plaza and r_mochi.node.position == m2._tile_center_px(t_plaza))
	_check("⑪r 같은 구역이라 실제로 걷는다(첫 실동작)",
		r_mochi.walk != null and r_mochi.walk.is_walking())
	_check("⑪s 걷는 중엔 그림 오프셋 ≠ 0(그림만 뒤따름)", r_mochi.node.walk_offset != Vector2.ZERO)
	# 경로가 메인 복도(길 스포크)를 실제로 경유한다.
	var mochi_spokes: PackedVector2Array = m2._road_spokes(t_home, t_plaza, RegionCatalog.NARU_VILLAGE)
	_check("⑪t 경로가 메인 복도를 경유한다(ㄱ자 스포크)",
		mochi_spokes.size() == 3
		and mochi_spokes[0] == m2._tile_center_px(Vector2i(t_home.x, m2.MAIN_CORRIDOR_Y))
		and mochi_spokes[1] == m2._tile_center_px(Vector2i(t_plaza.x, m2.MAIN_CORRIDOR_Y)))
	# 결정적: 같은 전환을 두 레코드로 굴리면 같은 delta에 같은 오프셋.
	var twin := Resident.new()
	twin.id = "mochi_twin"
	m2._begin_resident_walk(twin, t_home, RegionCatalog.NARU_VILLAGE, t_plaza, RegionCatalog.NARU_VILLAGE)
	twin.walk.advance(0.3)
	var solo := ResidentWalk.new()
	solo.start(m2._tile_center_px(t_home), mochi_spokes)
	solo.advance(0.3)
	_check("⑪u 걷기가 결정적(같은 경로·같은 delta = 같은 오프셋)", twin.walk.offset() == solo.offset())
	# 충분히 진행하면 정확히 도착(오프셋 0 = 그림이 논리 위치에 앉는다).
	m2._advance_resident_walk(r_mochi, 100.0)
	_check("⑪v 도착하면 오프셋 0(그림 = 논리 위치)",
		not r_mochi.walk.is_walking() and r_mochi.node.walk_offset == Vector2.ZERO)
	# ★ 저녁 카페(실내 밴드)로는 걷지 않는다 — 실내는 길 그래프 밖(T8 가드).
	m2.clock.minutes = Cafe.OPEN_MIN
	m2._update_resident_stations(0.0)
	_check("⑪w 저녁 전환 = 카페 자리로 즉시 도착", r_mochi.tile == t_cafe)
	_check("⑪x 실내 자리로는 걷지 않는다(길 그래프 밖 가드)", not r_mochi.walk.is_walking())
	_check("⑪y 실내 밴드 스포크 = 빈 배열",
		m2._road_spokes(t_plaza, t_cafe, RegionCatalog.NARU_VILLAGE).is_empty())

	# 대화 4묶음 하트 게이팅(캐릭터가 고른다 — 프레임워크는 시그니처만 안다).
	var l0: PackedStringArray = r_mochi.node.lines(0, true)
	var l1: PackedStringArray = r_mochi.node.lines(2, true)
	var l3: PackedStringArray = r_mochi.node.lines(4, true)
	var l5: PackedStringArray = r_mochi.node.lines(5, true)
	_check("⑪z 대화 4묶음이 하트 단계로 갈린다(0 / 1~2 / 3~4 / 5)",
		l0 != l1 and l1 != l3 and l3 != l5 and l0 != l5)
	_check("⑪A 묶음마다 3줄 이상",
		l0.size() >= 3 and l1.size() >= 3 and l3.size() >= 3 and l5.size() >= 3)
	_check("⑪B 오늘 두 번째 대화는 한 줄", r_mochi.node.lines(0, false).size() == 1)
	# 프레임워크 대화 경로(레지스트리 → 캐릭터)가 실제로 물린다.
	m2._start_resident_dialogue(r_mochi)
	_check("⑪C 공통 대화 경로로 대화창이 열린다(화자 = 모찌)",
		m2.dialogue.is_open() and m2._talking_to == "모찌")
	var guard := 0
	while m2.dialogue.is_open() and guard < 32:   # 끝까지 넘겨 닫는다(플레이어 조작과 같은 경로)
		# ★[S9-T9] 절기 물음 대응 — 모찌에게 `season_question` 훅이 생기면서(ADR-0067 결정 6)
		#   주 첫날 첫 대화 마지막 줄에 선택지가 설 수 있다. 선택지는 넘기기로 못 지나가므로
		#   (dialogue.advance의 has_choice 가드) 여기서 첫 항을 고른다 — miho/mel/bana 아크
		#   테스트 드레인 헬퍼와 같은 처방이다. 0점 계약이라 어느 항을 골라도 관측값은 불변.
		if m2.dialogue.has_choice():
			m2.dialogue.choose(0)
		else:
			m2.dialogue.advance()
		guard += 1
	_check("⑪D 끝까지 넘기면 닫힌다", not m2.dialogue.is_open())
	m2.player.set_physics_process(true)

	# 선물 → 호감도. ★[S8-T2] 입력이 **든 아이템**으로 바뀌었다(옛 경로 = _selected_crop 수확물).
	#   등급별 점수·품질 배율의 전수 검증은 gift_test 소관이고, 여기서는 프레임워크가 그 경로로
	#   실제 굴러가는지(소모·게이팅·캐릭터별 등급)만 본다.
	r_mochi.affinity.points = 0
	r_mochi.affinity.last_gift_day = -1
	m2.clock.day = 3
	m2.inventory.add_item(CropCatalog.HONRYEONGCHO, 1)   # 모찌에겐 선호가 아닌 작물
	_hold(m2, CropCatalog.HONRYEONGCHO)
	m2._try_resident_gift(r_mochi)
	var plain_pts: int = r_mochi.affinity.points
	_check("⑪E 뉴트럴 선물 = 기본 점수", plain_pts == Affinity.GIFT_POINTS)
	_check("⑪F 선물한 아이템이 인벤에서 소모된다",
		m2.inventory.count_of(CropCatalog.HONRYEONGCHO) == 0)
	# 하루 1회 게이팅 — 재고를 다시 채우고 같은 날 또 건네도 점수도 재고도 안 움직인다
	# (재고 부족으로 반려되는 게 아니라 *게이트*에 막히는지를 본다).
	m2.inventory.add_item(CropCatalog.HONRYEONGCHO, 1)
	_hold(m2, CropCatalog.HONRYEONGCHO)
	m2._try_resident_gift(r_mochi)
	_check("⑪G 하루 1회 게이팅(같은 날 두 번째는 무점수·무소모)",
		r_mochi.affinity.points == plain_pts
		and m2.inventory.count_of(CropCatalog.HONRYEONGCHO) == 1)
	m2.clock.day = 4
	_hold(m2, CropCatalog.HWANGCHEON_PODO)   # 모찌의 러브(황천포도)
	m2._try_resident_gift(r_mochi)
	_check("⑪H 러브 선물 = 배수 점수(황천포도)",
		r_mochi.affinity.points - plain_pts == Affinity.GIFT_PREFERRED_POINTS)
	_check("⑪I 등급 판정이 캐릭터별로 갈린다(같은 황천포도가 멜에겐 뉴트럴)",
		GiftPrefs.tier_of("mochi", CropCatalog.HWANGCHEON_PODO) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("mel", CropCatalog.HWANGCHEON_PODO) == GiftPrefs.NEUTRAL)

	# ★ 기존 5인 거동 불변 — 신규 주민 등록이 앞사람 자리·하트·관계 탭을 건드리지 않는다.
	# ★[S8-T1] 모찌도 관계 트랙 보유자라 이제 관계 탭에 뜬다(효과 줄만 없음 — 표시 자격 분리).
	var m2_rows: Array = m2._heart_rows()
	var mochi_shown := false
	for row in m2_rows:
		if String(row["name"]) == "모찌":
			mochi_shown = String(row["effect"]).begins_with("이번 주 선물")   # ★[S8-T9] 곱셈기 없음 = 꼬리만
	# ★[S9b-T1] 9 → 10행(깨비 합류). 모찌의 표시 성질(효과 줄 없음)은 그대로여야 한다.
	_check("⑪J 관계 탭 = 관계 트랙 보유 10행이고 모찌는 효과 줄 없이 표시된다",
		m2_rows.size() == 10 and mochi_shown)
	_check("⑪K 기존 주민 자리 불변",
		m2._resident("mel").tile == m2.MEL_TILE and m2._resident("neo").tile == m2.NEO_TILE)
	_check("⑪L 기존 4인 호감도 불변(⑨ 복원값 그대로)",
		m2.affinity.hearts() == 1 and m2.mel_affinity.hearts() == 2
		and m2.bana_affinity.hearts() == 3 and m2.neo_affinity.hearts() == 4)

	# 세이브 왕복 — 신규 키로 저장·복원된다.
	r_mochi.affinity.points = 2 * Affinity.POINTS_PER_HEART
	r_mochi.affinity.stage = 2   # ★[S8-T5] 하트 = stage(진급 칸) — 점수와 함께 세팅
	m2._save_game()
	var slot: int = m2._active_slot
	m2.free()
	var m3: Node = await _new_main()
	_check("⑪M 모찌 호감도가 mochi_affinity 키로 복원", m3._resident("mochi").affinity.hearts() == 2)
	_check("⑪N 같은 세이브에서 기존 4인도 그대로",
		m3.affinity.hearts() == 1 and m3.neo_affinity.hearts() == 4)
	m3.free()
	# 구세이브 하위호환 — mochi_affinity 키만 없는 세이브를 만들어 새로 부팅한다.
	var sm := SaveManager.new()
	var raw := sm.load_game(slot)
	raw.erase("mochi_affinity")
	sm.save_game(raw, slot, {"day": 1, "soul": 0})
	sm.free()
	var m4: Node = await _new_main()
	_check("⑪O 구세이브(키 없음) = 모찌만 ♡0으로 시작(무막힘)",
		m4._resident("mochi") != null and m4._resident("mochi").affinity.hearts() == 0)
	_check("⑪P 구세이브에서도 기존 주민은 정상 복원",
		m4.mel_affinity.hearts() == 2 and m4.neo_affinity.hearts() == 4)
	m4.free()

	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
