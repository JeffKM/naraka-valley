extends SceneTree

# ★ [ADR-0052 그레이박스] 활동 스킬 전문직 프레임워크 — 채집 파일럿 격리 검증.
#
# 무엇을 보나:
#   Part A(노드 불필요·ProfessionCatalog 순수):
#     ① 5스킬 구조 — 각 스킬 lvl5 2갈래 + lvl10 4분기(총 6), tier10 requires=실존 lvl5.
#     ② 채집 퍼크 시맨틱 — 약초학자=QUALITY_FLOOR 3(이리듐)·채집꾼=DOUBLE_DROP 0.20 등.
#     ③ 조회 방어 — is_valid/미지 스킬/미지 id.
#   Part B(main 스폰):
#     ④ 레벨 게이트 — L<5면 lvl5 선택 거부, L<10이면 lvl10 거부("평평≠막힘"과 별개=곱셈 편의 게이트).
#     ⑤ 선택 규칙 — 슬롯 1회(재선택 거부)·tier10 부모 정합(lumberjack은 detector 필요).
#     ⑥ 퍼크 API — 고른 전문직이 forage_quality_floor/double_drop에 실효.
#     ⑦ pending tier — 지금 고를 수 있는 tier(5→10→0) 파생.
#     ⑧ 세이브 왕복 — foraging_xp·professions 라운드트립 + 구세이브 결측/손상 방어.
#     ⑨ 채집 XP 레벨업 — _gain_forage_xp 누적·경계 레벨.
#
# 좀비 방지: 끝에 quit(). run_tests 워치독. 세이브 백업/원복(quality_skill_test 결).

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
	print("▶ profession_test (ADR-0052)")

	# ── Part A: ProfessionCatalog 순수 ──────────────────────────────────────
	# ① 5스킬 구조.
	_check("① SKILLS = 5종", ProfessionCatalog.SKILLS.size() == 5)
	var struct_ok := true
	var req_ok := true
	for skill in ProfessionCatalog.SKILLS:
		if ProfessionCatalog.tier_profs(skill, 5).size() != 2 or ProfessionCatalog.tier_profs(skill, 10).size() != 4:
			struct_ok = false
		# 각 tier10의 requires가 같은 스킬의 실존 lvl5 id인지.
		for p in ProfessionCatalog.tier_profs(skill, 10):
			var parent := String(p["requires"])
			if ProfessionCatalog.tier_of(skill, parent) != 5:
				req_ok = false
	_check("① 각 스킬 lvl5 2 + lvl10 4", struct_ok)
	_check("① 각 tier10 requires = 실존 lvl5", req_ok)
	# tier10은 부모 lvl5 2개로 2:2 갈림(채집: detector→{lumberjack,tapper}, gatherer→{botanist,tracker}).
	var det_children := 0
	var gat_children := 0
	for p in ProfessionCatalog.tier_profs(ProfessionCatalog.FORAGING, 10):
		if p["requires"] == "detector": det_children += 1
		elif p["requires"] == "gatherer": gat_children += 1
	_check("① 채집 lvl10 = 부모별 2:2 분기", det_children == 2 and gat_children == 2)

	# ② 채집 퍼크 시맨틱.
	_check("② 약초학자 = QUALITY_FLOOR 3(이리듐)", _perk_of(ProfessionCatalog.FORAGING, "botanist", ProfessionCatalog.DIM_QUALITY_FLOOR) == 3.0)
	_check("② 채집꾼 = DOUBLE_DROP 0.20", _perk_of(ProfessionCatalog.FORAGING, "gatherer", ProfessionCatalog.DIM_DOUBLE_DROP) == 0.20)
	_check("② 감지자 = WOOD_BONUS 1 + DETECT", _perk_of(ProfessionCatalog.FORAGING, "detector", ProfessionCatalog.DIM_WOOD_BONUS) == 1.0 and _perk_of(ProfessionCatalog.FORAGING, "detector", ProfessionCatalog.DIM_DETECT) == 1.0)
	_check("② 벌목꾼 = HARDWOOD flag", _perk_of(ProfessionCatalog.FORAGING, "lumberjack", ProfessionCatalog.DIM_HARDWOOD) == 1.0)
	# ADR-0052 §1 — 전문직 퍼크에 +판매가/마진 차원 부재(관계 곱셈기 전용). 채집 전 전문직 퍼크에 그런 dim 0.
	var no_value_dim := true
	for p in ProfessionCatalog.professions_for(ProfessionCatalog.FORAGING):
		for perk in p["perks"]:
			if String(perk["dim"]).contains("price") or String(perk["dim"]).contains("margin") or String(perk["dim"]).contains("value"):
				no_value_dim = false
	_check("② 채집 퍼크에 +판매가/마진 차원 없음(관계 곱셈기 전용)", no_value_dim)

	# ③ 조회 방어.
	_check("③ is_valid 유효/무효", ProfessionCatalog.is_valid(ProfessionCatalog.FORAGING, "botanist") and not ProfessionCatalog.is_valid(ProfessionCatalog.FORAGING, "garbage"))
	_check("③ 미지 스킬 = 빈 목록", ProfessionCatalog.professions_for("nope").is_empty())
	_check("③ 미지 id tier=0·requires=\"\"", ProfessionCatalog.tier_of(ProfessionCatalog.FORAGING, "garbage") == 0 and ProfessionCatalog.requires_of(ProfessionCatalog.FORAGING, "garbage") == "")

	# ── Part B: main 스폰 ───────────────────────────────────────────────────
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.prof_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var m := await _spawn_main()
	var F := ProfessionCatalog.FORAGING

	# ④ 레벨 게이트.
	m._foraging_xp = 0
	m._professions = {}
	_check("④ L0 채집 레벨 = 0", m._skill_level(F) == 0)
	_check("④ L0 lvl5 선택 거부", not m.choose_profession(F, "gatherer"))
	m._foraging_xp = 1500   # L5
	_check("④ 채집 XP1500 → L5", m._skill_level(F) == 5)
	_check("④ L5에서 lvl10 선택 거부(레벨 미달)", not m.choose_profession(F, "botanist"))

	# ⑤ 선택 규칙.
	_check("⑤ L5 lvl5 채집꾼 선택 성공", m.choose_profession(F, "gatherer"))
	_check("⑤ has_profession(채집꾼)", m.has_profession(F, "gatherer"))
	_check("⑤ 같은 tier 재선택 거부(슬롯 점유)", not m.choose_profession(F, "detector"))
	m._foraging_xp = 5500   # L10
	_check("⑤ L10 lvl10 부모 불일치 거부(벌목꾼=detector 필요, 우린 채집꾼)", not m.choose_profession(F, "lumberjack"))
	_check("⑤ L10 lvl10 부모 정합 선택 성공(약초학자←채집꾼)", m.choose_profession(F, "botanist"))

	# ⑥ 퍼크 API 실효.
	_check("⑥ forage_double_drop = 0.20(채집꾼)", is_equal_approx(m.forage_double_drop_chance(), 0.20))
	_check("⑥ forage_quality_floor = 3(약초학자 이리듐)", m.forage_quality_floor() == ItemCatalog.Q_IRIDIUM)

	# ⑦ pending tier.
	var m2 := await _spawn_main_fresh()
	m2._foraging_xp = 1500; m2._professions = {}
	_check("⑦ L5 미선택 → pending 5", m2._pending_profession_tier(F) == 5)
	m2.choose_profession(F, "gatherer")
	_check("⑦ L5 선택 후 → pending 0(lvl10 레벨 미달)", m2._pending_profession_tier(F) == 0)
	m2._foraging_xp = 5500
	_check("⑦ L10 lvl5만 고름 → pending 10", m2._pending_profession_tier(F) == 10)
	m2.choose_profession(F, "botanist")
	_check("⑦ 둘 다 고름 → pending 0", m2._pending_profession_tier(F) == 0)

	# ⑧ 세이브 왕복 + 구세이브 방어.
	m._foraging_xp = 1234
	m._professions = {F: {5: "gatherer", 10: "botanist"}}
	m._save_game()
	m.queue_free(); m2.queue_free()
	await process_frame
	await process_frame
	var m3 := await _spawn_main()
	_check("⑧ foraging_xp 라운드트립(1234)", m3._foraging_xp == 1234)
	_check("⑧ professions 라운드트립(약초학자)", m3.has_profession(F, "botanist") and m3.forage_quality_floor() == ItemCatalog.Q_IRIDIUM)
	# 구세이브 결측/손상 방어(_load_professions 직접).
	m3._load_professions({})
	_check("⑧ professions 키 없음 → 빈 선택", m3._professions.is_empty())
	m3._load_professions({F: {5: "nonexistent"}})
	_check("⑧ 실존 안 하는 id → 폐기", m3._professions.get(F, {}).is_empty())
	m3._load_professions({F: {10: "botanist"}})   # lvl5 부모 없음
	_check("⑧ tier10 부모 결측 → tier10 폐기", not m3.has_profession(F, "botanist"))
	m3._load_professions({F: {5: "gatherer", 10: "lumberjack"}})   # 부모 불일치(lumberjack←detector)
	_check("⑧ tier10 부모 불일치 → tier10만 폐기(tier5 유지)", m3.has_profession(F, "gatherer") and not m3.has_profession(F, "lumberjack"))

	# ⑨ 채집 XP 레벨업 누적.
	m3._foraging_xp = 0
	m3._gain_forage_xp(100)
	_check("⑨ _gain_forage_xp(100) → L1", m3._skill_level(F) == 1)
	m3._gain_forage_xp(50)   # 150 총 — 아직 L1(다음 임계 300)
	_check("⑨ 누적 150 → 여전히 L1", m3._skill_level(F) == 1 and m3._foraging_xp == 150)
	m3._gain_forage_xp(-10)   # 음수 무시
	_check("⑨ 음수 XP 무시", m3._foraging_xp == 150)

	# ⑩ UI 데이터 계약 — _skill_rows가 프레임에 넘길 options/profession/pending_tier.
	m3._foraging_xp = 1500   # L5
	m3._professions = {}
	var frow := _forage_row(m3._skill_rows())
	_check("⑩ L5 미선택 행 = pending 5·옵션 2(감지자·채집꾼)", int(frow.get("pending_tier", 0)) == 5 and frow.get("options", []).size() == 2)
	_check("⑩ L5 행 profession 빈 문자열", String(frow.get("profession", "")) == "")
	m3.choose_profession(F, "gatherer")
	frow = _forage_row(m3._skill_rows())
	_check("⑩ 선택 후 옵션 0(L5 소진)·profession=채집꾼", frow.get("options", []).size() == 0 and String(frow.get("profession", "")) == "채집꾼")
	m3._foraging_xp = 5500   # L10 → 채집꾼 자식 2개(약초학자·추적자)만
	frow = _forage_row(m3._skill_rows())
	var opt_ids := []
	for o in frow.get("options", []): opt_ids.append(String(o["id"]))
	_check("⑩ L10 옵션 = 채집꾼 자식 2(약초학자·추적자)", opt_ids.size() == 2 and opt_ids.has("botanist") and opt_ids.has("tracker"))

	# ⑪ 프레임 클릭 라우팅 — 숙련 탭 버튼 클릭 → profession_chosen 신호(옵션 탭 패턴). _draw 없이
	# _prof_choice_rects를 직접 채워 _click_menu 라우팅만 검증(레이아웃과 무관한 라우팅 단위).
	var fr := InventoryFrame.new()
	root.add_child(fr)
	fr.menu_tab = InventoryFrame.TAB_SKILL
	fr._prof_choice_rects = [{"rect": Rect2(10, 10, 120, 30), "skill": F, "prof_id": "gatherer"}]
	var captured := {"skill": "", "id": "", "hit": false}
	fr.profession_chosen.connect(func(s, pid): captured.skill = s; captured.id = pid; captured.hit = true)
	fr._click_menu(Vector2(20, 20))   # 버튼 안 클릭
	_check("⑪ 버튼 클릭 → profession_chosen(채집꾼)", captured.hit and captured.skill == F and captured.id == "gatherer")
	captured.hit = false
	fr._click_menu(Vector2(300, 300))   # 버튼 밖 클릭 = 무신호
	_check("⑪ 버튼 밖 클릭 = 무신호", not captured.hit)
	fr.free()

	m3.queue_free()
	await process_frame

	# 세이브 원복.
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── 헬퍼 ────────────────────────────────────────────────────────────────────
# (skill,id)의 dim 퍼크 값(없으면 -1). 순수 카탈로그 검사용.
func _perk_of(skill: String, id: String, dim: String) -> float:
	for perk in ProfessionCatalog.perks_of(skill, id):
		if perk["dim"] == dim:
			return float(perk["value"])
	return -1.0

# _skill_rows에서 채집 행(skill==FORAGING) 하나 — UI 데이터 계약 검사용.
func _forage_row(rows: Array) -> Dictionary:
	for r in rows:
		if String(r.get("skill", "")) == ProfessionCatalog.FORAGING:
			return r
	return {}

# save.dat를 지운 새 main(각 스폰이 깨끗한 기본 상태에서 시작하도록).
func _spawn_main_fresh() -> Node:
	if FileAccess.file_exists("user://save.dat"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.dat"))
	return await _spawn_main()
