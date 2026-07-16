extends SceneTree

# ★ [ADR-0051 / greybox] 밤 까마귀(미련까마귀) 작물 습격 + 허수아비 방어 격리 검증.
#
# 무엇을 보나(A = 무방비 작물 영구 소실 · 3중 안전장치 · 결정적 · 허수아비 반경 보호):
#   Part A — CrowRaid 순수 로직(main 불필요):
#     ① 문턱 — 작물 CROP_THRESHOLD 미만이면 습격 0(코지 온보딩 "평평≠막힘").
#     ② 문턱 경계 — 딱 THRESHOLD개 무방비면 습격 발생(size = nightly_count).
#     ③ 반경 보호 — 전부 허수아비 반경 안이면 습격 0.
#     ④ 상한 비례 — 심은 수 비례(문턱당 1)·최대 NIGHTLY_CAP(15→1·30→2·45→3·60→4·1000→4캡).
#     ⑤ 소실 칸 = 무방비 부분집합(보호된 칸은 절대 안 먹힘).
#     ⑥ 결정적 — 같은 (day·밭·허수아비) → 두 번 호출 동일 결과(헤드리스 재현).
#     ⑦ is_protected 경계 — 유클리드 거리 = 반경 정확히는 보호(≤), 반경+1은 무방비.
#   Part B — main 통합 계약(스폰):
#     ⑧ _scarecrow_tiles() = 배치 허수아비 밑동((37,15)·(46,15)) — 보이는 아트가 곧 방어.
#     ⑨ end-to-end — 무방비 15칸 + 보호 3칸 심고 CrowRaid+remove_plant 적용 → 보호칸 전원 생존·
#        무방비칸 일부 영구 소실(흙·비료 보존=다시 심을 수 있음).
#
# 좀비 방지: 끝에 quit(). run_tests 워치독.

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _grid(n: int, x0: int, y0: int) -> Array:
	# 서로 멀리 떨어진 결정적 칸 n개(한 열 세로 스택).
	var out: Array = []
	for i in range(n):
		out.append(Vector2i(x0, y0 + i))
	return out

func _init() -> void:
	print("══ CrowRaid 밤 까마귀 습격(ADR-0051) ══")
	_part_a()
	_part_b()
	if _fail == 0:
		print("══ 결과: PASS (실패 0) ══")
	else:
		print("══ 결과: FAIL (실패 %d) ══" % _fail)
	quit(1 if _fail > 0 else 0)

func _part_a() -> void:
	var T := CrowRaid.CROP_THRESHOLD
	var far_scare := [Vector2i(-100, -100)]   # 아무 것도 안 지키는 먼 허수아비

	# ① 문턱 미만 — 습격 0
	var below := _grid(T - 1, 10, 10)
	_check("① 문턱 미만(%d<%d)=습격 0" % [T - 1, T], CrowRaid.resolve(below, [], CrowRaid.BASE_RADIUS, 1).is_empty())

	# ② 문턱 경계 — 딱 T개 무방비면 발생
	var at := _grid(T, 10, 10)
	var r2 := CrowRaid.resolve(at, [], CrowRaid.BASE_RADIUS, 1)
	_check("② 문턱 경계(%d)=습격 발생" % T, r2.size() == CrowRaid.nightly_count(T) and r2.size() >= 1)

	# ③ 반경 보호 — 전부 반경 안이면 0
	var near := _grid(T, 50, 50)                     # (50,50)~(50,50+T-1)
	var scare := [Vector2i(50, 50 + T / 2)]          # 스택 중앙에 허수아비(전부 반경 8 안)
	_check("③ 전부 반경 안=습격 0", CrowRaid.resolve(near, scare, CrowRaid.BASE_RADIUS, 1).is_empty())

	# ④ 상한 비례 — nightly_count 단위
	_check("④ nightly_count 15→1", CrowRaid.nightly_count(15) == 1)
	_check("④ nightly_count 30→2", CrowRaid.nightly_count(30) == 2)
	_check("④ nightly_count 45→3", CrowRaid.nightly_count(45) == 3)
	_check("④ nightly_count 60→4", CrowRaid.nightly_count(60) == 4)
	_check("④ nightly_count 1000→4(캡)", CrowRaid.nightly_count(1000) == CrowRaid.NIGHTLY_CAP)
	var big := _grid(60, 70, 0)
	_check("④ 60무방비=소실 4(캡)", CrowRaid.resolve(big, far_scare, CrowRaid.BASE_RADIUS, 7).size() == 4)

	# ⑤ 소실 칸 ⊂ 무방비 집합
	var mixed_planted := _grid(T, 50, 50) + _grid(20, 70, 0)   # 앞 T개는 보호, 뒤 20개는 무방비
	var eaten := CrowRaid.resolve(mixed_planted, scare, CrowRaid.BASE_RADIUS, 3)
	var all_exposed := true
	for e in eaten:
		if CrowRaid.is_protected(e, scare, CrowRaid.BASE_RADIUS):
			all_exposed = false
	_check("⑤ 소실 칸은 전부 무방비(보호칸 불가침)", eaten.size() > 0 and all_exposed)

	# ⑥ 결정적 — 같은 인자 두 번 = 동일
	var d1 := CrowRaid.resolve(big, far_scare, CrowRaid.BASE_RADIUS, 42)
	var d2 := CrowRaid.resolve(big, far_scare, CrowRaid.BASE_RADIUS, 42)
	_check("⑥ 결정적(같은 day 재현)", d1 == d2)

	# ⑦ is_protected 경계 — 거리 8=보호, 9=무방비(허수아비 원점)
	var origin := [Vector2i(0, 0)]
	_check("⑦ 거리 8(=반경)=보호", CrowRaid.is_protected(Vector2i(8, 0), origin, 8))
	_check("⑦ 거리 9(>반경)=무방비", not CrowRaid.is_protected(Vector2i(9, 0), origin, 8))

func _part_b() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	var farm: FarmField = m.get_node("FarmField")
	# 스폰 직후엔 리전 빌드가 아직이라 _prop_layouts가 빈다(실플레이는 하루 경과 시 이미 채워짐).
	#   테스트는 부팅과 같은 순서로 명시 로드해 배치 허수아비 좌표를 확보한다.
	m._ensure_prop_layouts()

	# ⑧ 배치 허수아비 밑동 = (37,15)·(46,15)
	var st: Array = m._scarecrow_tiles()
	_check("⑧ 허수아비 밑동 2개 = (37,15)·(46,15)",
		st.size() == 2 and Vector2i(37, 15) in st and Vector2i(46, 15) in st)

	# ⑨ end-to-end — 보호 3칸(허수아비 곁) + 무방비 15칸(먼 곳) 심고 습격 적용
	var protected: Array = [Vector2i(37, 14), Vector2i(38, 15), Vector2i(46, 16)]  # 밑동 반경 8 안
	var exposed: Array = _grid(15, 70, 0)                                          # (70,0)~(70,14) 먼 곳
	for t in protected + exposed:
		farm.hoe(t)
		farm.plant(t, CropCatalog.PIANHWA)
	var eaten := CrowRaid.resolve(farm.planted_tiles(), m._scarecrow_tiles(), CrowRaid.BASE_RADIUS, 5)
	for et in eaten:
		farm.remove_plant(et)
	# 보호칸 전원 생존
	var prot_alive := true
	for t in protected:
		if not farm.is_planted(t):
			prot_alive = false
	_check("⑨a 보호칸 3개 전원 생존", prot_alive)
	# 무방비칸 일부 소실(습격 발생)
	var exp_lost := 0
	for t in exposed:
		if not farm.is_planted(t):
			exp_lost += 1
	_check("⑨b 무방비칸 일부 영구 소실(>0)", exp_lost > 0 and exp_lost == eaten.size())
	# 소실 칸도 흙(경작)은 남아 다시 심을 수 있다
	var re_tillable := true
	for et in eaten:
		if not farm.is_tilled(et) or farm.is_planted(et):
			re_tillable = false
	_check("⑨c 소실 칸=흙 보존(다시 심기 가능)", re_tillable)

	m.queue_free()
