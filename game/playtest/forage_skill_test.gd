extends SceneTree

# ★[S4-T2 / ADR-0062 결정 8] 채집 스킬(ForageSkill) · 혼 감지/추적 마커 · 퍼크 배선 검증.
#
# 무엇을 보나:
#   ① XP 테이블 — 행위별 고정 XP(줍기 7·벌목 14·큰 장애물 25·덤불 1)이고, **실제 줍기 두 경로**
#      (안식 꽃 패치·숲 빈터)가 종·가격과 무관하게 정확히 7을 준다(옛 기준가 방식 폐기의 실증).
#   ② 레벨 곡선 — FarmSkill 공통 기반 위임(임계·MAX_LEVEL·경계 일치. 수치 복제 0).
#   ③ 품질 계단 — L0~3 일반 / L4~6 은 / L7+ 금 **불변**(이관해도 계단이 안 움직인다) + main 위임 일치.
#   ④ 퍼크 헬퍼 — 더블드롭 0.20 · 품질 하한(이리듐) · 원목 +1 · 단단한 원목 확률 · 수액 등급 계단.
#      미선택이면 전부 정확히 중립(0/0.0/false)이라 "퍼크 없는 세이브 = base 그대로"가 보장된다.
#   ⑤ 감지 대상 선정 결정성 — 최근접 · 동률이면 좌표 정렬 · **입력 배열 순서에 무관**(셔플 불변).
#   ⑥ 감지 게이트 — lvl3 미만이면 대상 없음 / lvl3+면 있음 / 반경 밖은 안 잡힘 / 감지자 = 구역 전체.
#   ⑦ 세이브 — `foraging_xp` 키 하위호환(개명 금지)·라운드트립·구세이브 결측/손상 방어.
#
# ForageSkill은 순수 static이라 ①일부·②·③·④일부·⑤는 씬 없이 돈다. 배선(⑥·⑦·줍기 XP)만 main.tscn을 띄운다.
# 좀비 방지: 끝에 quit(). run_tests.sh 워치독. 세이브 백업/원복(fishing_skill_test 결).
#
# 실행: ./run_tests.sh forage_skill   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

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
	print("▶ forage_skill_test (S4-T2 / ADR-0062 결정 8)")
	var F := ProfessionCatalog.FORAGING

	# ══ ① XP 테이블(고정 — 스타듀 상속) ═════════════════════════════════════
	_check("① 고정 XP = 줍기 7 · 벌목 마지막 타 14 · 큰 장애물 25 · 덤불 흔들기 1",
		ForageSkill.PICK_XP == 7 and ForageSkill.CHOP_XP == 14
		and ForageSkill.LARGE_OBSTACLE_XP == 25 and ForageSkill.BUSH_SHAKE_XP == 1)
	_check("① 위계 보존 — 덤불 < 줍기 < 벌목 < 큰 장애물",
		ForageSkill.BUSH_SHAKE_XP < ForageSkill.PICK_XP
		and ForageSkill.PICK_XP < ForageSkill.CHOP_XP
		and ForageSkill.CHOP_XP < ForageSkill.LARGE_OBSTACLE_XP)

	# ══ ② 레벨 곡선 = FarmSkill 위임 ════════════════════════════════════════
	_check("② MAX_LEVEL = FarmSkill과 같은 눈금(10)",
		ForageSkill.MAX_LEVEL == FarmSkill.MAX_LEVEL and ForageSkill.MAX_LEVEL == 10)
	_check("② XP 임계 = 공통 곡선 위임(FarmSkill.XP_THRESHOLDS)",
		ForageSkill.xp_thresholds() == FarmSkill.XP_THRESHOLDS)
	var curve_same := true
	for xp in [0, 1, 99, 100, 299, 300, 1499, 1500, 5499, 5500, 99999]:
		if ForageSkill.level_for_xp(xp) != FarmSkill.level_for_xp(xp):
			curve_same = false
	_check("② level_for_xp가 FarmSkill과 전 구간 동일(수치 복제 0)", curve_same)
	_check("② 경계 — 0/99=L0 · 100=L1 · 5500=L10 · 만렙 상한",
		ForageSkill.level_for_xp(0) == 0 and ForageSkill.level_for_xp(99) == 0
		and ForageSkill.level_for_xp(100) == 1 and ForageSkill.level_for_xp(5500) == 10
		and ForageSkill.level_for_xp(999999) == 10)
	# 줍기 7 기준 첫 레벨까지 몇 번인가(체감 밴드 — 한 세션 안에 L1이 닿아야 "평평≠막힘"이 산다).
	var picks_to_l1 := int(ceil(100.0 / float(ForageSkill.PICK_XP)))
	_check("② 줍기 %d회면 L1(첫 레벨이 한 세션 안)" % picks_to_l1,
		ForageSkill.level_for_xp(picks_to_l1 * ForageSkill.PICK_XP) >= 1 and picks_to_l1 <= 20)

	# ══ ③ 품질 계단(이관 전후 불변) ═════════════════════════════════════════
	var steps_ok := true
	for lv in range(0, 4):
		if ForageSkill.base_quality(lv) != ItemCatalog.Q_NORMAL:
			steps_ok = false
	for lv in range(4, 7):
		if ForageSkill.base_quality(lv) != ItemCatalog.Q_SILVER:
			steps_ok = false
	for lv in range(7, 11):
		if ForageSkill.base_quality(lv) != ItemCatalog.Q_GOLD:
			steps_ok = false
	_check("③ 품질 계단 L0~3 일반 / L4~6 은 / L7+ 금(전 레벨 전수)", steps_ok)
	_check("③ 이리듐은 base로 안 나옴(약초학자 하한 전용 — 퍼크가 의미를 갖게)",
		ForageSkill.base_quality(10) != ItemCatalog.Q_IRIDIUM)

	# ══ ④ 퍼크 해석(순수) ═══════════════════════════════════════════════════
	_check("④ 미선택(0.0) = 정확히 중립",
		ForageSkill.quality_floor(0.0) == 0 and is_equal_approx(ForageSkill.double_drop_chance(0.0), 0.0)
		and ForageSkill.wood_bonus(0.0) == 0 and is_equal_approx(ForageSkill.hardwood_chance(0.0), 0.0)
		and ForageSkill.tap_quality(0.0) == 0)
	_check("④ 카탈로그 정의값 통과 — 채집꾼 0.20 · 약초학자 이리듐(3) · 감지자 원목 +1",
		is_equal_approx(ForageSkill.double_drop_chance(_perk_of(F, "gatherer", ProfessionCatalog.DIM_DOUBLE_DROP)), 0.20)
		and ForageSkill.quality_floor(_perk_of(F, "botanist", ProfessionCatalog.DIM_QUALITY_FLOOR)) == ItemCatalog.Q_IRIDIUM
		and ForageSkill.wood_bonus(_perk_of(F, "detector", ProfessionCatalog.DIM_WOOD_BONUS)) == 1)
	_check("④ 벌목꾼 = 단단한 원목 확률 %.2f · 수액꾼 = 등급 계단 +1"
		% ForageSkill.HARDWOOD_CHANCE,
		is_equal_approx(ForageSkill.hardwood_chance(_perk_of(F, "lumberjack", ProfessionCatalog.DIM_HARDWOOD)),
			ForageSkill.HARDWOOD_CHANCE)
		and ForageSkill.hardwood_chance(1.0) > 0.0 and ForageSkill.hardwood_chance(1.0) < 1.0
		and ForageSkill.tap_quality(_perk_of(F, "tapper", ProfessionCatalog.DIM_TAP_QUALITY)) == 1)
	_check("④ 손상 방어 — 음수/과대 퍼크 클램프",
		ForageSkill.quality_floor(-5.0) == 0 and ForageSkill.quality_floor(99.0) == ItemCatalog.Q_IRIDIUM
		and is_equal_approx(ForageSkill.double_drop_chance(9.0), 1.0)
		and ForageSkill.wood_bonus(-3.0) == 0)
	var all_filled := true
	for p in ProfessionCatalog.professions_for(F):
		if p["perks"].is_empty():
			all_filled = false
	_check("④ 채집 6전문직 전원 perks 채워짐(ADR-0052 로스터 이행)", all_filled)

	# ══ ⑤ 감지 대상 선정 결정성 ═════════════════════════════════════════════
	var origin := Vector2i(20, 20)
	var tiles := [Vector2i(24, 20), Vector2i(20, 22), Vector2i(30, 30)]
	_check("⑤ 최근접 선정((20,22)가 거리 2로 최소)",
		ForageSkill.nearest_forage(origin, tiles, ForageSkill.DETECT_RANGE_ALL) == Vector2i(20, 22))
	# 동률(정확히 같은 거리) — x 오름차순 → y 오름차순. 배열 순서를 뒤집어도 같은 답이 나와야 한다.
	var tie := [Vector2i(23, 20), Vector2i(20, 23), Vector2i(17, 20), Vector2i(20, 17)]
	var pick_a := ForageSkill.nearest_forage(origin, tie, ForageSkill.DETECT_RANGE_ALL)
	tie.reverse()
	var pick_b := ForageSkill.nearest_forage(origin, tie, ForageSkill.DETECT_RANGE_ALL)
	_check("⑤ 동률 = 좌표 정렬(x→y 최소 = (17,20)) · 배열 순서 무관",
		pick_a == Vector2i(17, 20) and pick_a == pick_b)
	# 셔플 불변(Dictionary 키 순서에 안 기댄다는 실증 — 20판 무작위 순열).
	var shuffle_stable := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for _i in 20:
		var arr := tiles.duplicate()
		for j in range(arr.size() - 1, 0, -1):
			var k := rng.randi_range(0, j)
			var tmp: Vector2i = arr[j]
			arr[j] = arr[k]
			arr[k] = tmp
		if ForageSkill.nearest_forage(origin, arr, ForageSkill.DETECT_RANGE_ALL) != Vector2i(20, 22):
			shuffle_stable = false
	_check("⑤ 셔플 20판 불변(입력 순서 독립)", shuffle_stable)
	_check("⑤ 반경 밖은 안 잡힌다(반경 3 → 거리 4짜리 제외)",
		ForageSkill.nearest_forage(origin, [Vector2i(24, 20)], 3) == ForageSkill.NO_TARGET
		and ForageSkill.nearest_forage(origin, [Vector2i(23, 20)], 3) == Vector2i(23, 20))
	_check("⑤ 빈 목록·감지 없음(반경 0) = NO_TARGET",
		ForageSkill.nearest_forage(origin, [], ForageSkill.DETECT_RANGE_ALL) == ForageSkill.NO_TARGET
		and ForageSkill.nearest_forage(origin, tiles, 0) == ForageSkill.NO_TARGET)
	_check("⑤ NO_TARGET 센티넬이 실좌표와 안 겹침(채집물 좌표는 전부 0 이상)",
		ForageSkill.NO_TARGET.x < 0 and ForageSkill.NO_TARGET.y < 0)

	# ══ ⑥ 감지 게이트(순수 계수부) ═══════════════════════════════════════════
	_check("⑥ lvl3 미만 = 감지 없음(반경 0)",
		ForageSkill.detect_radius(0, 0.0) == 0 and ForageSkill.detect_radius(2, 0.0) == 0
		and ForageSkill.detect_radius(2, 1.0) == 0)   # 퍼크가 있어도 레벨 게이트가 먼저
	_check("⑥ lvl3+ base = 반경 %d칸" % ForageSkill.DETECT_RADIUS,
		ForageSkill.detect_radius(3, 0.0) == ForageSkill.DETECT_RADIUS
		and ForageSkill.detect_radius(10, 0.0) == ForageSkill.DETECT_RADIUS)
	_check("⑥ 감지자 퍼크 = 구역 전체(DETECT_RANGE_ALL)",
		ForageSkill.detect_radius(3, 1.0) == ForageSkill.DETECT_RANGE_ALL
		and ForageSkill.detect_radius(10, 1.0) == ForageSkill.DETECT_RANGE_ALL)
	_check("⑥ 감지 해금 레벨 = 3(CONTEXT 혼 감지)", ForageSkill.DETECT_LEVEL == 3)

	# ══ Part B: main 배선 ════════════════════════════════════════════════════
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.forageskill_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m := await _spawn_main()
	m._professions = {}
	m._foraging_xp = 0
	_check("Ⓑ 신규 세이브 = 채집 L0(무막힘 — base 맨몸 가동)", m._skill_level(F) == 0)
	_check("Ⓑ _skill_level이 ForageSkill 곡선과 일치",
		m._skill_level(F) == ForageSkill.level_for_xp(m._foraging_xp))
	_check("Ⓑ main._forage_base_quality = ForageSkill.base_quality 위임(전 레벨)",
		_delegation_ok(m))

	# ── ①-B 실제 줍기 두 경로가 정확히 7 ──
	# ㉠ 안식 꽃 패치(피안화 — 기준가 45). 옛 방식이면 45가 들어왔다.
	var SF := ItemCatalog.SPIRIT_FLOWER
	var ftile: Vector2i = m.flower.bloomed_tiles()[0]
	m._foraging_xp = 0
	m._pick_flower(ftile)
	_check("①B 꽃 패치 줍기 = 고정 7(기준가 %d 아님 — 판매가 축 누수 차단)" % ItemCatalog.price_of(SF),
		m._foraging_xp == ForageSkill.PICK_XP)
	# ㉡ 숲 빈터 줍기 — **비싼 종과 싼 종이 같은 XP**여야 고정 테이블이 실효한 것이다.
	m._rebuild_region(RegionCatalog.JEOSEUNG_FOREST)
	var spot: Vector2i = m.FOREST_FORAGE_LABEL_TILE
	var cheap := ItemCatalog.NEOK_GOSARI
	var pricey := ItemCatalog.JEOSEUNG_SAM
	m.forage_spawns.load_save({"tiles": {RegionCatalog.JEOSEUNG_FOREST: [[spot.x, spot.y, cheap]]}})
	m._foraging_xp = 0
	m._pick_forage(spot)
	var xp_cheap: int = m._foraging_xp
	m.forage_spawns.load_save({"tiles": {RegionCatalog.JEOSEUNG_FOREST: [[spot.x, spot.y, pricey]]}})
	m._foraging_xp = 0
	m._pick_forage(spot)
	var xp_pricey: int = m._foraging_xp
	_check("①B 숲 줍기 = 고정 7(싼 종 %dg·비싼 종 %dg가 같은 XP)"
		% [ItemCatalog.price_of(cheap), ItemCatalog.price_of(pricey)],
		xp_cheap == ForageSkill.PICK_XP and xp_pricey == ForageSkill.PICK_XP)
	_check("①B 레벨업 감지 배선 — 줍기 %d회 누적이면 L1" % picks_to_l1,
		_pick_n_times(m, spot, picks_to_l1) and m._skill_level(F) >= 1)

	# ── ④-B main 퍼크 조회 헬퍼(미배선 3종 포함) ──
	m._professions = {}
	m._foraging_xp = 5500   # L10
	_check("④B 퍼크 미선택 = 전부 중립",
		m.forage_quality_floor() == 0 and is_equal_approx(m.forage_double_drop_chance(), 0.0)
		and m.forage_wood_bonus() == 0 and is_equal_approx(m.forage_hardwood_chance(), 0.0)
		and m.forage_tap_quality() == 0 and not m.forage_track_enabled())
	m.choose_profession(F, "gatherer")
	m.choose_profession(F, "tracker")
	_check("④B 채집꾼 → 더블드롭 0.20 · 추적자 → 마커 켜짐",
		is_equal_approx(m.forage_double_drop_chance(), 0.20) and m.forage_track_enabled())
	var m_det := await _spawn_main()
	m_det._professions = {}
	m_det._foraging_xp = 5500
	m_det.choose_profession(F, "detector")
	m_det.choose_profession(F, "lumberjack")
	_check("④B 감지자 → 원목 +1 · 벌목꾼 → 단단한 원목 확률(★S4-T3/T6 소비 접점)",
		m_det.forage_wood_bonus() == 1
		and is_equal_approx(m_det.forage_hardwood_chance(), ForageSkill.HARDWOOD_CHANCE))
	_check("④B 감지자 갈래는 약초학자/추적자 퍼크 0(갈래 격리)",
		m_det.forage_quality_floor() == 0 and not m_det.forage_track_enabled())

	# ── ⑥-B 혼 감지 라이브 배선(main.forage_detect_target) ──
	m_det._rebuild_region(RegionCatalog.JEOSEUNG_FOREST)
	var home_t: Vector2i = m.FOREST_FORAGE_LABEL_TILE          # (20,8) 빈터①
	var far_t: Vector2i = m.FOREST_FORAGE_LABEL_TILE_2         # (45,10) 빈터② — 반경 14 밖
	m_det.player.global_position = m_det._tile_center_px(home_t + Vector2i(2, 0))
	m_det.forage_spawns.load_save({"tiles": {RegionCatalog.JEOSEUNG_FOREST: [
		[home_t.x, home_t.y, cheap], [far_t.x, far_t.y, cheap]]}})
	_check("⑥B 감지자(구역 전체) → 최근접 (20,8) 선정",
		m_det.forage_detect_target() == home_t)
	# 멀리 있는 것만 남기면 — 감지자는 잡고, base(반경 14)는 못 잡는다.
	m_det.forage_spawns.load_save({"tiles": {RegionCatalog.JEOSEUNG_FOREST: [[far_t.x, far_t.y, cheap]]}})
	_check("⑥B 감지자 = 구역 전체라 먼 (45,10)도 잡힘", m_det.forage_detect_target() == far_t)
	var m_base := await _spawn_main()
	m_base._professions = {}
	m_base._rebuild_region(RegionCatalog.JEOSEUNG_FOREST)
	m_base.player.global_position = m_base._tile_center_px(home_t + Vector2i(2, 0))
	m_base.forage_spawns.load_save({"tiles": {RegionCatalog.JEOSEUNG_FOREST: [
		[home_t.x, home_t.y, cheap], [far_t.x, far_t.y, cheap]]}})
	m_base._foraging_xp = 0                       # L0
	_check("⑥B lvl3 미만 = 감지 없음(반경 0 → NO_TARGET)",
		m_base.forage_detect_radius() == 0 and m_base.forage_detect_target() == ForageSkill.NO_TARGET)
	m_base._foraging_xp = int(FarmSkill.XP_THRESHOLDS[2])   # L3 진입
	_check("⑥B lvl3 도달 = 감지 켜짐(반경 %d) · 가까운 (20,8)만" % ForageSkill.DETECT_RADIUS,
		m_base.forage_detect_radius() == ForageSkill.DETECT_RADIUS
		and m_base.forage_detect_target() == home_t)
	m_base.forage_spawns.load_save({"tiles": {RegionCatalog.JEOSEUNG_FOREST: [[far_t.x, far_t.y, cheap]]}})
	_check("⑥B base 반경 밖(45,10)은 안 잡힘 — 퍼크가 범위를 키운다는 대비",
		m_base.forage_detect_target() == ForageSkill.NO_TARGET)
	# 다른 구역·실내는 대상 0(원장이 구역별이라 자동 — 마커가 딴 데서 안 뜬다).
	m_base._rebuild_region(RegionCatalog.HOME)
	_check("⑥B 채집물 없는 구역 = NO_TARGET(마커 안 뜸)",
		m_base.forage_detect_target() == ForageSkill.NO_TARGET)

	# 숙련 탭에 채집 행이 있는가(이 테스트의 관심사는 *채집 행*이지 총 행 수가 아니다).
	# ★[S5-T2] 옛 "행 수 3 유지" 단언은 **의도적으로 개정**됐다 — ADR-0063 결정 9가 채광 행을
	#   4행째로 얹었고(전투 5행째는 S5-T4/T5), 행 수의 계약은 mining_test ⑨가 든다.
	var srows: Array = m_base._skill_rows()
	var frow := _forage_row(srows)
	_check("Ⓑ 숙련 탭 채집 행 존재(행 수는 스킬 슬라이스마다 는다 — 지금 %d행)" % srows.size(),
		srows.size() >= 3 and String(frow.get("name", "")) == "채집")
	var fr := InventoryFrame.new()
	root.add_child(fr)
	fr.menu_tab = InventoryFrame.TAB_SKILL
	var pr: Rect2 = fr._panel_rect()
	var need := InventoryFrame.PAD + 48.0 \
		+ float(srows.size()) * (InventoryFrame.SK_ROW_H + InventoryFrame.SK_ROW_GAP)
	_check("Ⓑ 숙련 %d행이 패널 높이 안에 들어감 (%.0f ≤ %.0f)"
		% [srows.size(), need, pr.size.y - InventoryFrame.FRAME_MARGIN],
		need <= pr.size.y - InventoryFrame.FRAME_MARGIN)
	fr.free()

	# ══ ⑦ 세이브 ════════════════════════════════════════════════════════════
	m_base._professions = {}
	m_base._foraging_xp = 1500        # L5 — 전문직 선택 자격(tier5)
	_check("⑦pre 채집꾼 선택 성공(L5 게이트)", m_base.choose_profession(F, "gatherer"))
	m_base._foraging_xp = 1234        # 라운드트립 표식값(레벨보다 낮아도 고른 전문직은 남는다)
	m_base._save_game()
	await _despawn(m_base)
	await _despawn(m_det)
	await _despawn(m)
	var m2 := await _spawn_main()
	_check("⑦ foraging_xp 라운드트립(1234) — 키 개명 없음", m2._foraging_xp == 1234)
	_check("⑦ 채집 전문직 라운드트립(채집꾼 → 더블드롭 0.20)",
		m2.has_profession(F, "gatherer") and is_equal_approx(m2.forage_double_drop_chance(), 0.20))
	_check("⑦ 세이브 키 이름이 'foraging_xp' 그대로(구세이브 하위호환)",
		_save_has_foraging_key())
	m2._foraging_xp = maxi(int({}.get("foraging_xp", 0)), 0)
	_check("⑦ 구세이브(foraging_xp 키 없음) = 0 → L0 무막힘",
		m2._foraging_xp == 0 and m2._skill_level(F) == 0)
	m2._foraging_xp = maxi(int({"foraging_xp": -999}.get("foraging_xp", 0)), 0)
	_check("⑦ 손상 세이브(음수) = 0으로 클램프", m2._foraging_xp == 0)

	await _despawn(m2)

	# 세이브 원복.
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── 헬퍼 ────────────────────────────────────────────────────────────────────
func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

func _perk_of(skill: String, id: String, dim: String) -> float:
	for perk in ProfessionCatalog.perks_of(skill, id):
		if perk["dim"] == dim:
			return float(perk["value"])
	return -1.0

func _forage_row(rows: Array) -> Dictionary:
	for r in rows:
		if String(r.get("skill", "")) == ProfessionCatalog.FORAGING:
			return r
	return {}

# main._forage_base_quality가 ForageSkill.base_quality로 정확히 위임되는가(전 레벨 + 범위 밖).
func _delegation_ok(m: Node) -> bool:
	for lv in range(-2, 13):
		if m._forage_base_quality(lv) != ForageSkill.base_quality(lv):
			return false
	return true

# 같은 칸에 채집물을 다시 심어 n회 줍는다(레벨업 배선 확인용). 성공하면 true.
func _pick_n_times(m: Node, spot: Vector2i, n: int) -> bool:
	m._foraging_xp = 0
	for _i in n:
		m.forage_spawns.load_save({"tiles": {RegionCatalog.JEOSEUNG_FOREST:
			[[spot.x, spot.y, ItemCatalog.NEOK_GOSARI]]}})
		m._pick_forage(spot)
	return m._foraging_xp == n * ForageSkill.PICK_XP

# 저장 파일 본문에 'foraging_xp' 키 문자열이 그대로 있는가(키 개명 금지의 직접 증거).
func _save_has_foraging_key() -> bool:
	var f := FileAccess.open("user://save.dat", FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	return txt.contains("foraging_xp")
