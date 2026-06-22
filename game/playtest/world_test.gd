extends SceneTree
# M1.1/M1.3 — Region 데이터 모델 단위검증(ephemeral). RegionCatalog의 8구역 정의·홈베이스
# 실데이터·stub 구분·토폴로지 정합·미지 id 방어를 헤드리스로 단언한다. crops/lighting_test와
# 같은 결의 하네스 — 정적 참조 데이터라 트리에 안 붙이고 static 함수를 직접 호출한다.
# M1.3에서 워프 발동 칸(at) 실좌표·도착 칸(dest) 폴백 규칙을 더했다(워프 *동작*은 warp_test.gd).
#
# ★ M1.6에서 워프 동작·세이브까지 통합 검증으로 확장(같은 파일명 world_test).
# 실행: godot --headless --path game --script res://playtest/world_test.gd

var _fail := 0

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
	# main.gd 외부 무대 크기(MAP_W 40 × OUTDOOR_H 24)·SPAWN_TILE(20,21)과 같은 seam.
	_check("②c home 크기 = (40, 24)", RegionCatalog.size_of(RegionCatalog.HOME) == Vector2i(40, 24))
	_check("②d home 스폰 = (20, 21)", RegionCatalog.spawn_of(RegionCatalog.HOME) == Vector2i(20, 21))
	_check("②e home은 지어진 구역(is_built)", RegionCatalog.is_built(RegionCatalog.HOME))

	# ── ③ 나머지 7개 = stub(아직 안 지어짐): size·spawn = ZERO, 표시명만 있음 ──
	var stub_count := 0
	for id in ids:
		if id == RegionCatalog.HOME:
			continue
		stub_count += 1
		_check("③ '%s' stub size=ZERO" % id, RegionCatalog.size_of(id) == Vector2i.ZERO)
		_check("③b '%s' stub spawn=ZERO" % id, RegionCatalog.spawn_of(id) == Vector2i.ZERO)
		_check("③c '%s' stub 미빌드(is_built=false)" % id, not RegionCatalog.is_built(id))
		_check("③d '%s' 표시명은 채워짐" % id, RegionCatalog.name_of(id) != "")
	_check("③e stub은 정확히 7개", stub_count == 7)
	# ★ 핵심 불변식: 지어진 구역은 홈베이스 하나뿐("빌드는 한 구역씩", ADR-0015).
	var built := ids.filter(func(id): return RegionCatalog.is_built(id))
	_check("③f 지어진 구역 = home 하나뿐", built == [RegionCatalog.HOME])

	# ── ④ 토폴로지(warps) 정합: world-map.md §2 구역 그래프 ──
	# 워프의 to는 실재하는 구역이어야 하고, 토폴로지는 대칭(양방향)이어야 한다.
	for id in ids:
		for w in RegionCatalog.warps_of(id):
			_check("④ '%s'→'%s' 목적 구역 실재" % [id, w["to"]], RegionCatalog.has_region(w["to"]))
			# M1.3 — at(발동 칸)은 *이 구역*이 지어졌으면 실좌표(그 구역 size 범위 안), stub이면
			# 아직 TBD다. dest(도착 칸)는 *목적 구역*이 지어져야 정해지므로 지금은 다 TBD다.
			if RegionCatalog.is_built(id):
				var sz := RegionCatalog.size_of(id)
				var at: Vector2i = w["at"]
				_check("④b '%s'→'%s' 발동 칸이 실좌표" % [id, w["to"]], at != RegionCatalog.TILE_TBD)
				_check("④b' '%s'→'%s' 발동 칸이 구역 범위 안" % [id, w["to"]],
					at.x >= 0 and at.y >= 0 and at.x < sz.x and at.y < sz.y)
			else:
				_check("④b '%s'→'%s' stub 구역 발동 칸 TBD" % [id, w["to"]],
					w["at"] == RegionCatalog.TILE_TBD)
			_check("④b'' '%s'→'%s' 도착 칸 TBD(목적 구역 빌드 시 확정)" % [id, w["to"]],
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

	print(("══ 통과 ══" if _fail == 0 else "══ 실패 %d건 ══" % _fail))
	quit(_fail)

# 중복 제거(순서 무관 — 개수 비교용).
func _unique(arr: Array) -> Array:
	var seen := {}
	for x in arr:
		seen[x] = true
	return seen.keys()
