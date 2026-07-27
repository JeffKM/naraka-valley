extends SceneTree
# ★[S4-T1 / ADR-0062 결정 1·2] 숲 채집물 스폰·줍기 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ① 결정성 — 같은 day·같은 절기면 몇 번을 굴려도 같은 배치(전역 randf 금지의 실증).
#   ② 구역 상한 — 구역당 동시 6개를 절대 안 넘는다(스타듀 forage cap 상속).
#   ③ 7일 주기 리셋 — 미수집분을 버리고 판을 새로 깐다.
#   ④ 절기 필터 — 절기마다 종이 배타적이다(피안·유화·망연·성야 교집합 0 + 성야도 안 죽음).
#   ⑤ 절기 전환일 전량 삭제 — (day-1)%28==0에 판이 통째로 지워지고 새 절기 종으로 갈린다.
#   ⑥ 줍기 = 혼력 0(ADR-0033 #1) — 줍기 전후 혼력 불변.
#   ⑦ 품질 롤 범위 — 채집 레벨 → 등급(L0 일반 / L4 은 / L7 금) · 퍼크 하한과 max · 0..3 밖 없음.
#   ⑧ 줍기 후 인벤 +1 · 원장에서 그 칸 제거(자리는 재생 아니라 소멸).
#   ⑨ 세이브 라운드트립 — 원장 직렬화 + main 세이브·재부팅 복원 + 키 없는 구세이브 하위호환.
#   ⑩ 빈터 존 밖 스폰 0 — 스폰 칸 전부가 존 rect 안이고, 그 존 칸이 실그리드에서 걸을 수 있다.
#   ⑪ 로스터 22종 — ItemCatalog 등록·CAT_HARVEST·가격 밴드·불사과 명칭 보존.
#
# 실행: ./run_tests.sh forage_spawn   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame
	return m

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

# 하루씩 굴려 누적한 원장(순수 — main 무의존). from..to일까지 그 절기로 advance_day.
func _run_days(from_day: int, to_day: int, season: int) -> ForageSpawns:
	var led := ForageSpawns.new()
	for d in range(from_day, to_day + 1):
		led.advance_day(d, season)
	return led

# 원장 상태를 비교 가능한 정렬 문자열로(결정성·라운드트립 판정).
func _fingerprint(led: ForageSpawns) -> String:
	var rows: Array = []
	for region: String in ForageSpawns.spawn_regions():
		for t: Vector2i in led.tiles(region):
			rows.append("%s:%d,%d=%s" % [region, t.x, t.y, led.species_at(region, t)])
	rows.sort()
	return "|".join(rows)

# 외부에서 걸을 수 있는 칸인가(jeoseung_forest_test 동형).
func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	var id: int = m._grid[t.y][t.x]
	return id != m.WALL and id != m.WATER and id != m.TREE and id != m.VOID

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S4-T1 숲 채집물 스폰·줍기 단위검증 ══")
	const SAVE := "user://save.dat"
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var FOREST := RegionCatalog.JEOSEUNG_FOREST
	var MIHOK := RegionCatalog.MIHOK_FOREST

	# ── ① 결정성 ──
	print("── ① 결정 롤 ──")
	var a := _run_days(1, 14, 0)
	var b := _run_days(1, 14, 0)
	_check("①a 같은 day·절기 시퀀스 = 같은 배치", _fingerprint(a) == _fingerprint(b) and _fingerprint(a) != "")
	# 같은 하루만 두 번 굴려도 같은 칸·같은 종(시드 = day+구역+좌표).
	var c1 := ForageSpawns.new()
	var r1: Dictionary = c1.advance_day(3, 0)
	var c2 := ForageSpawns.new()
	var r2: Dictionary = c2.advance_day(3, 0)
	_check("①b 단일 day 롤 재현", _fingerprint(c1) == _fingerprint(c2))
	_check("①c day가 다르면 시드가 다르다(고정 배치 아님)",
		_fingerprint(_run_days(2, 2, 0)) != _fingerprint(_run_days(3, 3, 0)))
	_check("①d 롤 결과 dict 형식(spawned/cleared/reset/season_reset)",
		r1.has("spawned") and r1.has("cleared") and r1.has("reset") and r1.has("season_reset")
		and r2["spawned"].size() == r1["spawned"].size())

	# ── ② 구역 상한 6 ──
	print("── ② 구역 상한 ──")
	var cap_led := ForageSpawns.new()
	var over := false
	var peak := 0
	for d in range(1, 113):        # 1년(112일) 통째로 — 한 번도 안 주우면 상한에 눌려 있어야
		cap_led.advance_day(d, GameClock.season_index_for_day(d))
		for region: String in ForageSpawns.spawn_regions():
			peak = maxi(peak, cap_led.count(region))
			if cap_led.count(region) > ForageSpawns.REGION_CAP:
				over = true
	_check("②a 상한 상수 = 6(스타듀 1:1)", ForageSpawns.REGION_CAP == 6)
	_check("②b 1년 내내 구역당 6 초과 0회", not over)
	_check("②c 실제로 상한까지 찬다(스폰율이 죽어 있지 않음)", peak == ForageSpawns.REGION_CAP)

	# ── ③ 7일 주기 리셋 ──
	print("── ③ 7일 리셋 ──")
	_check("③a 리셋 간격 상수 = 7", ForageSpawns.RESET_DAYS == 7)
	var cyc := _run_days(1, 7, 0)          # day7까지 쌓기(day8이 다음 주기 시작)
	var before_cnt := cyc.total()
	var res8: Dictionary = cyc.advance_day(8, 0)
	_check("③b day8 = 주기 리셋일(reset=true)", bool(res8["reset"]))
	_check("③c 미수집분 전량 삭제(cleared = 직전 보유 수) — %d" % before_cnt,
		before_cnt > 0 and int(res8["cleared"]) == before_cnt)
	_check("③d 삭제 후 그날 재시드(판이 새로 깔린다)", cyc.total() == int(res8["spawned"].size()))
	var res9: Dictionary = cyc.advance_day(9, 0)
	_check("③e 주기 중간 날은 리셋 없음(누적)", not bool(res9["reset"]) and int(res9["cleared"]) == 0)

	# ── ④ 절기 필터(절기별 종 배타) ──
	print("── ④ 절기 필터 ──")
	var season_ok := true
	var season_nonempty := true
	for s in 4:
		var pool_common: Array = ForageSpawns.species_for(ForageSpawns.KIND_COMMON, s)
		var pool_rare: Array = ForageSpawns.species_for(ForageSpawns.KIND_RARE, s)
		if pool_common.size() != 3 or pool_rare.size() != 1:
			season_nonempty = false
		var led := _run_days(1, 28, s)
		for region: String in ForageSpawns.spawn_regions():
			for t: Vector2i in led.tiles(region):
				var kind := ForageSpawns.zone_kind_at(region, t)
				if not ForageSpawns.species_for(kind, s).has(led.species_at(region, t)):
					season_ok = false
	_check("④a 절기당 일반 3종·희소 1종(성야절 포함 — 겨울 정지 없음)", season_nonempty)
	_check("④b 스폰 종은 그 절기·그 존의 로스터 안에만", season_ok)
	# 절기 간 교집합 0(피안 종이 성야에 안 뜬다).
	var cross := false
	for s in 4:
		for s2 in 4:
			if s == s2:
				continue
			for id in ForageSpawns.species_for(ForageSpawns.KIND_COMMON, s):
				if ForageSpawns.species_for(ForageSpawns.KIND_COMMON, s2).has(id):
					cross = true
			for id2 in ForageSpawns.species_for(ForageSpawns.KIND_RARE, s):
				if ForageSpawns.species_for(ForageSpawns.KIND_RARE, s2).has(id2):
					cross = true
	_check("④c 절기 간 종 교집합 0(배타)", not cross)
	_check("④d 심층·해변은 절기 무관(4절기 동일 풀)",
		ForageSpawns.species_for(ForageSpawns.KIND_DEEP, 0) == ForageSpawns.species_for(ForageSpawns.KIND_DEEP, 3)
		and ForageSpawns.species_for(ForageSpawns.KIND_BEACH, 0).size() == 4)
	# 희소 빈터엔 희소종만·심층엔 심층종만(존 배타).
	var zone_exclusive := true
	var deep_led := _run_days(1, 56, 1)
	for t: Vector2i in deep_led.tiles(MIHOK):
		var k := ForageSpawns.zone_kind_at(MIHOK, t)
		var sid := deep_led.species_at(MIHOK, t)
		if k == ForageSpawns.KIND_DEEP and not ForageSpawns.species_for(ForageSpawns.KIND_DEEP, 1).has(sid):
			zone_exclusive = false
		if k == ForageSpawns.KIND_RARE and not ForageSpawns.species_for(ForageSpawns.KIND_RARE, 1).has(sid):
			zone_exclusive = false
	_check("④e 존 배타(희소 빈터=희소종 / 심층=심층 2종)", zone_exclusive)

	# ── ⑤ 절기 전환일 전량 삭제 ──
	print("── ⑤ 절기 전환일 ──")
	var sea := ForageSpawns.new()
	for d in range(1, 29):
		sea.advance_day(d, GameClock.season_index_for_day(d))   # 피안절 28일
	var before_season := sea.total()
	var res29: Dictionary = sea.advance_day(29, GameClock.season_index_for_day(29))
	_check("⑤a day29 = 절기 전환일(season_reset=true)", bool(res29["season_reset"]))
	_check("⑤b 전량 삭제(cleared = 직전 보유 수) — %d" % before_season,
		before_season > 0 and int(res29["cleared"]) == before_season)
	var new_season_only := true
	for region: String in ForageSpawns.spawn_regions():
		for t: Vector2i in sea.tiles(region):
			if not ForageSpawns.species_for(ForageSpawns.zone_kind_at(region, t), 1).has(sea.species_at(region, t)):
				new_season_only = false
	_check("⑤c 전환 뒤엔 새 절기(유화절) 종만 남는다", new_season_only)

	# ── ⑩ 빈터 존 밖 스폰 0(원장 순수 판정) ──
	print("── ⑩ 존 경계 ──")
	var outside := 0
	var year := ForageSpawns.new()
	for d in range(1, 113):
		year.advance_day(d, GameClock.season_index_for_day(d))
		for region: String in ForageSpawns.spawn_regions():
			for t: Vector2i in year.tiles(region):
				if ForageSpawns.zone_kind_at(region, t) == "":
					outside += 1
	_check("⑩a 1년 스폰 전량이 빈터 존 안(존 밖 0)", outside == 0)
	_check("⑩b 존 정의 = 저승 3(일반) · 미혹 3(희소2+심층1)",
		ForageSpawns.zones()[FOREST].size() == 3 and ForageSpawns.zones()[MIHOK].size() == 3)
	# 라벨 앵커가 존 안(ADR-0062 "앵커 전량 보존" — 좌표는 안 움직였다).

	# ── ⑪ 로스터 22종 ──
	print("── ⑪ 로스터 22종 ──")
	var roster: Array = ForageSpawns.all_species()
	var uniq := {}
	for id in roster:
		uniq[id] = true
	_check("⑪a 종 22개·중복 0", roster.size() == 22 and uniq.size() == 22)
	var reg_ok := true
	var band_ok := true
	for id in roster:
		if not ItemCatalog.has_item(id) or ItemCatalog.category_of(id) != ItemCatalog.CAT_HARVEST \
				or ItemCatalog.name_of(id) == "" or ItemCatalog.price_of(id) <= 0:
			reg_ok = false
	for id in ForageSpawns.species_for(ForageSpawns.KIND_COMMON, 0) + ForageSpawns.species_for(ForageSpawns.KIND_COMMON, 1) \
			+ ForageSpawns.species_for(ForageSpawns.KIND_COMMON, 2) + ForageSpawns.species_for(ForageSpawns.KIND_COMMON, 3):
		if ItemCatalog.price_of(id) < 30 or ItemCatalog.price_of(id) > 90:
			band_ok = false
	for id in ForageSpawns.species_for(ForageSpawns.KIND_RARE, 0) + ForageSpawns.species_for(ForageSpawns.KIND_RARE, 1) \
			+ ForageSpawns.species_for(ForageSpawns.KIND_RARE, 2) + ForageSpawns.species_for(ForageSpawns.KIND_RARE, 3):
		if ItemCatalog.price_of(id) < 120 or ItemCatalog.price_of(id) > 250:
			band_ok = false
	for id in ForageSpawns.species_for(ForageSpawns.KIND_BEACH, 0):
		if ItemCatalog.price_of(id) < 20 or ItemCatalog.price_of(id) > 60:
			band_ok = false
	_check("⑪b 전종 ItemCatalog 등록·CAT_HARVEST·이름·가격", reg_ok)
	_check("⑪c 가격 밴드(일반 30~90 / 희소 120~250 / 해변 20~60)", band_ok)
	_check("⑪d 불사과 = CropCatalog 기존 종 재사용(명칭 보존)·500+ 고가·신규 중복 등록 0",
		ItemCatalog.name_of(CropCatalog.BULSAGWA) == "불사과"
		and ItemCatalog.price_of(CropCatalog.BULSAGWA) >= 500
		and not ItemCatalog.FORAGEABLES.has(CropCatalog.BULSAGWA))
	# 신규 21종 id가 기존 로스터(작물·과일·어종·산물·재료)와 안 부딪힌다(조회가 엉뚱한 표에 걸리는 사고 방지).
	var collide := ""
	for id in ItemCatalog.FORAGEABLES.keys():
		if CropCatalog.has_crop(id) or FruitTreeCatalog.has(id) or FishCatalog.has(id) \
				or AnimalCatalog.has_product(id) or ItemCatalog.MATERIALS.has(id) or ItemCatalog.POT_GOODS.has(id):
			collide = String(id)
	_check("⑪g 신규 채집물 id ↔ 기존 로스터 충돌 0", collide == "")
	_check("⑪e 품질 유차원(등급 배수 실효 — 수확물 결)",
		ItemCatalog.price_of(ItemCatalog.NEOK_SONGI, ItemCatalog.Q_GOLD)
			== int(90 * ItemCatalog.quality_mult(ItemCatalog.Q_GOLD)))
	_check("⑪f 피안화(안식 파일럿) 회귀 0", ItemCatalog.price_of(ItemCatalog.SPIRIT_FLOWER) == 30)

	# ── ⑨-a 원장 세이브 라운드트립(순수) ──
	print("── ⑨ 세이브 ──")
	var src := _run_days(1, 20, 2)
	var dst := ForageSpawns.new()
	dst.load_save(src.to_save())
	_check("⑨a 원장 직렬화 왕복(구역·좌표·종 보존)", _fingerprint(dst) == _fingerprint(src) and src.total() > 0)
	var empty := ForageSpawns.new()
	empty.load_save({})
	_check("⑨b 키 없는 구세이브 = 채집물 0(하위호환)", empty.total() == 0)
	var junk := ForageSpawns.new()
	junk.load_save({"tiles": {FOREST: [[20, 8, "no_such_species"], [21, 8, ItemCatalog.NEOK_GOSARI]]}})
	_check("⑨c 손상·구버전 종 id는 조용히 버린다", junk.total() == 1
		and junk.species_at(FOREST, Vector2i(21, 8)) == ItemCatalog.NEOK_GOSARI)

	# ── main 배선(⑥⑦⑧⑨-b⑩-c) ──
	print("── main 배선 ──")
	var m: Node = await _new_main()
	_check("⓪ forage_spawns 노드 배선(RefCounted 원장)", m.forage_spawns != null)
	m._rebuild_region(FOREST)
	_check("⓪b 구역 = 저승 숲", m._region == FOREST)

	# ⑩-c 존 칸이 실그리드에서 전부 걸을 수 있다(나무·연못·건물에 안 묻힘).
	var blocked_forest := 0
	for t: Vector2i in ForageSpawns.candidates(FOREST):
		if not _walkable(m, t):
			blocked_forest += 1
	_check("⑩c 저승 숲 존 %d칸 전부 걸을 수 있음" % ForageSpawns.candidates(FOREST).size(), blocked_forest == 0)
	_check("⑩d 라벨 앵커 3곳이 존 안(좌표 불변 — ADR-0062 앵커 보존)",
		ForageSpawns.zone_kind_at(FOREST, m.FOREST_FORAGE_LABEL_TILE) == ForageSpawns.KIND_COMMON
		and ForageSpawns.zone_kind_at(FOREST, m.FOREST_FORAGE_LABEL_TILE_2) == ForageSpawns.KIND_COMMON
		and ForageSpawns.zone_kind_at(FOREST, m.FOREST_FORAGE_LABEL_TILE_3) == ForageSpawns.KIND_COMMON)
	m._rebuild_region(MIHOK)
	# ★[S4-T4 / ADR-0062 결정 1 ㉡] 재작성 — 심층 존은 이제 **의도적으로 막혀 있다**. 큰 그루터기 6개가
	#   존 안에 서고(일일 리스폰 · 명동 도끼 필요), 존 전체가 봉쇄 링 + 큰 통나무 뒤에 있다. 즉 "존 칸이
	#   전부 걸을 수 있다"는 옛 단언은 희소 빈터 2곳에만 해당하고, 심층은 **큰 그루터기 칸만** 막힌 게
	#   정답이다(그 외 30칸은 여전히 빈터라 채집물이 묻히지 않는다). 도달성 자체는 tool_tier_test ⑦이 본다.
	var blocked_mihok := 0
	var blocked_deep := 0
	for t: Vector2i in ForageSpawns.candidates(MIHOK):
		if _walkable(m, t):
			continue
		if ForageSpawns.zone_kind_at(MIHOK, t) == ForageSpawns.KIND_DEEP:
			blocked_deep += 1
		else:
			blocked_mihok += 1
	_check("⑩e 미혹 희소 빈터 2곳은 전부 걸을 수 있음(심층 제외)", blocked_mihok == 0)
	_check("⑩e2 심층 존에서 막힌 칸 = 큰 그루터기 6칸뿐(나머지 30칸은 빈터)",
		blocked_deep == m.MIHOK_DEEP_STUMP_TILES.size()
		and m.tree_ledger.large_tiles(MIHOK, TreeLedger.KIND_LARGE_STUMP).size() == 6)
	_check("⑩f 미혹 라벨 앵커 2곳 = 희소 존",
		ForageSpawns.zone_kind_at(MIHOK, m.MIHOK_FORAGE_LABEL_TILE) == ForageSpawns.KIND_RARE
		and ForageSpawns.zone_kind_at(MIHOK, m.MIHOK_FORAGE_LABEL_TILE_2) == ForageSpawns.KIND_RARE)

	# ⑥⑦⑧ 줍기 — 저승 숲 빈터에 한 개 심어 놓고 줍는다.
	m._rebuild_region(FOREST)
	var spot: Vector2i = m.FOREST_FORAGE_LABEL_TILE
	m.forage_spawns.load_save({"tiles": {FOREST: [[spot.x, spot.y, ItemCatalog.NEOK_SONGI]]}})
	m._target = spot
	m._foraging_xp = 0
	m._professions = {}
	var inv_before: int = m.inventory.count_of(ItemCatalog.NEOK_SONGI)
	var soul_before: int = m.energy.current
	m._pick_forage(spot)
	_check("⑥ 줍기 = 혼력 0(ADR-0033 #1 — 유일 무비용 산출)", m.energy.current == soul_before)
	_check("⑧a 인벤토리 증가(1 또는 더블드랍 2)",
		m.inventory.count_of(ItemCatalog.NEOK_SONGI) - inv_before >= 1)
	_check("⑧b 원장에서 그 칸 제거(자리는 재생 아니라 소멸)",
		not m.forage_spawns.has_at(FOREST, spot) and m.forage_spawns.total() == 0)
	# ★[S4-T2] 고정 XP 테이블 전환 — 종·가격 무관하게 줍기 7(꽃 패치와 정확히 같은 값).
	_check("⑧c 채집 XP 획득(줍기 고정 %d — 꽃 패치와 같은 사슬)" % ForageSkill.PICK_XP,
		m._foraging_xp == ForageSkill.PICK_XP)
	_check("⑧d 없는 칸 줍기 = 무동작(방어)", m.forage_spawns.pick(FOREST, spot) == "")

	# ⑦ 품질 롤 범위(레벨 → 등급 · 0..3 밖 없음).
	_check("⑦a L0~3 = 일반", m._forage_base_quality(0) == ItemCatalog.Q_NORMAL and m._forage_base_quality(3) == ItemCatalog.Q_NORMAL)
	_check("⑦b L4~6 = 은", m._forage_base_quality(4) == ItemCatalog.Q_SILVER and m._forage_base_quality(6) == ItemCatalog.Q_SILVER)
	_check("⑦c L7+ = 금", m._forage_base_quality(7) == ItemCatalog.Q_GOLD and m._forage_base_quality(10) == ItemCatalog.Q_GOLD)
	var q_ok := true
	for lv in range(0, 11):
		var q: int = maxi(m._forage_base_quality(lv), m.forage_quality_floor())
		if q < ItemCatalog.Q_NORMAL or q > ItemCatalog.Q_IRIDIUM:
			q_ok = false
	_check("⑦d 롤 결과가 0..3 밖으로 안 나감(퍼크 하한과 max 포함)", q_ok)
	# 줍은 슬롯의 실등급이 그 롤과 일치(L7 = 금).
	m._foraging_xp = int(FarmSkill.XP_THRESHOLDS[6])   # L7 진입
	var spot2 := spot + Vector2i(1, 0)
	m.forage_spawns.load_save({"tiles": {FOREST: [[spot2.x, spot2.y, ItemCatalog.JAETBIT_NAENGI]]}})
	m._pick_forage(spot2)
	var slot_q := -1
	for i in m.inventory.slots.size():
		var s: Variant = m.inventory.slots[i]
		if s != null and String(s.get("id", "")) == ItemCatalog.JAETBIT_NAENGI:
			slot_q = m.inventory.quality_at(i)
	_check("⑦e L7 줍기 = 금 등급 슬롯", slot_q == ItemCatalog.Q_GOLD)

	# ⑨-b main 세이브·재부팅 라운드트립.
	var keep := _run_days(1, 20, 0)
	m.forage_spawns.load_save(keep.to_save())
	var fp: String = _fingerprint(m.forage_spawns)
	m._save_game()
	await _despawn(m)
	var m2: Node = await _new_main()
	_check("⑨d main 세이브 왕복(재부팅 후 같은 배치)", _fingerprint(m2.forage_spawns) == fp and fp != "")
	await _despawn(m2)
	cleaner.delete_save()

	print("── 결과 ──")
	if _fail == 0:
		print("✔ 전부 통과")
	else:
		print("✘ 실패 %d건" % _fail)
	quit(0 if _fail == 0 else 1)
