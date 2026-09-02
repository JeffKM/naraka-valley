extends SceneTree
# ★[폴리시 10회차] 버그 헌트 확정분 회귀 — 배치 A(#1~#10).
#
# 렌즈: R9 diff 리뷰 · 전투 사슬 · 미니게임 세션 경계 · 대화 상태기계 · XP/전문직 축.
#
# 무엇을 보증하나(발견 번호 = 10회차 헌트 배치 A):
#   ① #1  밀린 잡초 밤 표가 세이브에 안 실리고 로드가 버려, 마을에 서서 강제 취침 → F9 한 번이면
#         그 밤의 확산·재점령이 **영구 스킵**됐다(R9가 막은 무비용 악용의 재개통). 취침 자동
#         세이브가 `_on_day_advanced` 뒤에 뜨므로 파일의 `reclaim`은 확산 전이고, 표까지 버리면
#         되감기가 아니라 손실이 된다 — 형제 표 둘(절기 재스폰·방목 방출)과 갈리는 유일한 자리.
#   ② #2  R9 커밋이 "선물 배율 거동 불변"의 근거로 댄 "주괴는 어느 러브·라이크 목록에도 없다"가
#         **거짓**이었다(풀무 LOVE = 주괴 4종 전량 · 네오 LOVE = 황천금 주괴). 거동은 유지하되
#         (품질을 싣는 물건에 배율이라는 이 파일의 규칙과 정합) 그 사실을 단언으로 못 박는다.
#   ③ #3  추적 아키타입에 접촉 정지가 없어 몹이 플레이어와 **같은 칸**에 서는데, 스윙 부채꼴은
#         origin을 절대 안 담아 붙잡히면 검이 한 대도 안 들어갔다(한 칸 물러서야만 판정이 살았다).
#   ④ #4  arc가 SOLID 칸을 '제거'만 해서 정면 1칸이 막혀도 정면 2칸이 살아남았다 — 머리말이
#         선언한 "벽 하나 사이로 못 벤다"와 정반대(돌 뒤 제자리형을 일방적으로 처리).
#   ⑤ #5  LMB를 세션 입력으로 쓰는 셋째 세션인 릴 격투에만 `_use_tool` 디스패치 가드가 없어,
#         격투 중 곁들이·명부환을 들면 릴을 당길 때마다 접시·환약이 탔다(체키·칵테일은 방어됨).
#   ⑥ #6  `_on_dialogue_finished`가 취침 연출 중에도 무조건 이동 잠금을 풀어, 24:00 강제 취침
#         암전 뒤에서 플레이어가 걸어 다녔다(`_on_sleep_done`의 R2 불변식을 닫힘 경로가 되뚫음).
#   ⑦ #7  선택지가 떠 있을 때 [G]는 고백 제안만 조용히 파기하고 `advance()`는 확정 no-op —
#         화면은 한 글자도 안 바뀌는데 [F] 창구만 죽었다.
#   ⑧⑨⑩  #8(농사 XP 판매가 파생)·#9(팬닝 XP 0)·#10(야생 수확 deed 산입) = **owner 결정 큐**.
#         수정이 아니라 *지금 값*을 눈금으로 고정해, owner가 뒤집을 때 무엇이 바뀌는지 보이게 한다.

var _fail := 0
var _src: PackedStringArray = PackedStringArray()

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

func _dismiss_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 60:
		m.dialogue.advance()
		guard += 1

# main.gd 소스에서 needle이 든 줄의 인덱스(-1 = 없음) — polish_r7~r9의 그 헬퍼.
func _line_of(needle: String) -> int:
	for i in _src.size():
		if _src[i].contains(needle):
			return i
	return -1

func _wipe_slot(slot: int) -> void:
	var p := SaveManager.slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _initialize() -> void:
	print("══ 폴리시 10회차 — R9 diff · 전투 사슬 · 세션 경계 · 대화 상태기계 · XP 축(A) ══")
	_src = FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().split("\n")
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)

	var m := await _spawn_main()
	_dismiss_dialogue(m)
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)

	# ── ① #1 밀린 잡초 밤 표가 세이브를 왕복한다 ────────────────────────────────
	print("── ① #1 밀린 잡초 밤 — 표가 원장과 같은 파일에 실린다 ──")
	_check("①a 취침 자동 세이브는 날이 바뀐 **뒤**에 뜬다(그래서 표를 버리면 손실이 된다)",
		_line_of("func _on_sleep_done") > 0 and _in_func("func _on_sleep_done", "_save_game()"))
	m._weed_day_pending_day = 12
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	_check("①b `_save_game`이 표를 실제로 적는다(키 weed_pending_day = 12)",
		raw.has("weed_pending_day") and int(raw["weed_pending_day"]) == 12)
	m._weed_day_pending_day = 0
	var ok_load: bool = m._load_game()
	_check("①c 로드가 그 표를 되살린다(종전엔 무조건 0으로 버려 그 밤이 영영 안 굴렀다) — 12",
		ok_load and m._weed_day_pending_day == 12)
	_check("①d 하위호환 — 키 없는 구세이브는 0이다(파생 기본값이 종전과 같다)",
		int(({} as Dictionary).get("weed_pending_day", 0)) == 0
		and _line_of("data.get(\"weed_pending_day\", 0)") > 0)
	# 되살아난 표는 **집에서 실제로 소비된다** — 라운드트립만으로는 반쪽이라 소비까지 본다.
	m._region = RegionCatalog.HOME
	m._sleeping = false
	m._transitioning = false
	await process_frame
	_check("①e 집에 있는 프레임이 그 표를 소비해 0으로 돌아간다(확산·재점령이 그 밤 값으로 굴렀다)",
		m._weed_day_pending_day == 0)
	_check("①f 형제 표 둘은 계약이 그대로다(로드가 버린다 — 저쪽은 버려도 잃는 것이 없다)",
		_line_of("_season_respawn_pending_day = 0") > 0
		and _line_of("_pasture_release_pending = false") > 0)

	# ── ② #2 주괴 선물 배율 — R9의 "거동 불변" 전제가 거짓이었다 ────────────────
	print("── ② #2 주괴 선물 — 러브 목록에 실재하고 등급 배율이 얹힌다 ──")
	var ingot: String = ItemCatalog.INGOT_MYEONGDONG
	_check("②a 반증: 주괴는 풀무 LOVE 목록에 **전량** 들어 있다(4종) — R9 전제가 거짓",
		GiftPrefs.tier_of("pulmu", ItemCatalog.INGOT_MYEONGDONG) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("pulmu", ItemCatalog.INGOT_YUCHEOL) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("pulmu", ItemCatalog.INGOT_HWANGCHEONGEUM) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("pulmu", ItemCatalog.INGOT_NARAKCHEOL) == GiftPrefs.LOVE)
	_check("②b 네오 LOVE에도 황천금 주괴가 있다(둘째 창구)",
		GiftPrefs.tier_of("neo", ItemCatalog.INGOT_HWANGCHEONGEUM) == GiftPrefs.LOVE)
	_check("②c 주괴는 등급을 싣는 집합에 정식으로 들었다(R9 술어 — 값과 보관이 같은 집합)",
		ItemCatalog.carries_quality(ingot))
	_check("②d 그래서 배율이 실제로 얹힌다 — 일반 40 · 은 44(= int(40 × 1.1))",
		GiftPrefs.gift_points("pulmu", ingot, ItemCatalog.Q_NORMAL) == 40
		and GiftPrefs.gift_points("pulmu", ingot, 1) == 44)
	_check("②e 도달 상한 = 은 한 칸이다(제련공 퍼크가 등급 계단 +1 — 이리듐 주괴 선물은 없다)",
		MiningSkill.ingot_quality_step(
			float(ProfessionCatalog.perks_of(ProfessionCatalog.MINING, "blacksmith")[1]["value"])) == 1)
	_check("②f 파일 불변식은 그대로다 — 일반 품질 러브(40) > 이리듐 라이크(37)",
		GiftPrefs.points_for(GiftPrefs.LOVE, ingot, ItemCatalog.Q_NORMAL)
			> GiftPrefs.points_for(GiftPrefs.LIKE, ingot, 3))
	_check("②g 무품질 물건은 여전히 배율 0차원이다(돌 = 등급을 안 싣는다)",
		not ItemCatalog.carries_quality(ItemCatalog.STONE)
		and GiftPrefs.points_for(GiftPrefs.LOVE, ItemCatalog.STONE, 3)
			== GiftPrefs.points_for(GiftPrefs.LOVE, ItemCatalog.STONE, 0))

	# ── ③ #3 겹친 몹 — 스윙이 선 자리를 벤다 ────────────────────────────────────
	print("── ③ #3 접촉 중인 추적 몹 — 같은 칸에 선 적이 판정에 든다 ──")
	var origin: Vector2i = m._player_tile()
	# 무대 좌표를 손으로 안 적는다 — 정면 두 칸이 실제로 뚫린 방향을 넷 중에서 고른다(맵이
	# 바뀌면 무대가 따라 움직인다 — 하드코딩이 stale로 죽는 그 함정 회피).
	var facing := Vector2i.ZERO
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var pp := Vector2i(-d.y, d.x)
		if not m._blocks_swing(origin + d) and not m._blocks_swing(origin + d * 2) \
				and not m._blocks_swing(origin + d + pp) and not m._blocks_swing(origin + d - pp) \
				and not m._blocks_swing(origin - d) and not m._blocks_swing(origin - d * 2):
			facing = d
			break
	m.player.face_toward(m.player.global_position + Vector2(facing) * 64.0)
	_check("③pre 정면·배후 두 칸이 모두 뚫린 방향을 실그리드에서 골랐다 — %s" % [facing],
		facing != Vector2i.ZERO and Vector2i(m.player.get_facing().round()) == facing)
	_check("③pre′ 순수 기하는 종전 그대로 4칸이고 origin을 안 담는다(계약 불변 — 모양은 안 건드렸다)",
		CombatSkill.swing_arc(origin, facing).size() == 4
		and not CombatSkill.swing_arc(origin, facing).has(origin))
	var arc0: Array = m._weapon_arc()
	_check("③a 라이브 arc = 선 자리 %s + 정면 2칸 + 날개 2칸 = 5칸(origin이 새로 든 자리)" % [origin],
		arc0.size() == 5 and arc0.has(origin)
		and arc0.has(origin + facing) and arc0.has(origin + facing * 2)
		and arc0.has(origin + facing + Vector2i(-facing.y, facing.x))
		and arc0.has(origin + facing - Vector2i(-facing.y, facing.x)))
	var overlap := {"tile": origin, "id": "겹친놈"}
	var far := {"tile": origin + facing * 9, "id": "먼놈"}
	var picked: Array = CombatSkill.hits_in_arc(arc0, [overlap, far])
	_check("③b 몸을 겹친 몹이 실제로 골라진다(종전엔 빈 배열 — 접촉 피해만 받고 못 때렸다)",
		picked.size() == 1 and String(picked[0]["id"]) == "겹친놈")
	_check("③c 방향은 여전히 의미를 갖는다 — 등 뒤 칸은 안 든다",
		not arc0.has(origin - facing) and not arc0.has(origin - facing * 2))

	# ── ④ #4 벽 뒤 2칸이 잘린다 ─────────────────────────────────────────────────
	print("── ④ #4 가림 — 돌 하나 사이로는 못 벤다 ──")
	var front1 := origin + facing
	var front2 := origin + facing * 2
	var perp := Vector2i(-facing.y, facing.x)
	_check("④pre 무대 준비: 정면 두 칸이 맵 안이고 지금은 둘 다 닿는다",
		not m._blocks_swing(front1) and not m._blocks_swing(front2)
		and arc0.has(front1) and arc0.has(front2))
	var saved_cell: int = m._grid[front1.y][front1.x]
	m._grid[front1.y][front1.x] = m.ROCK
	var arc1: Array = m._weapon_arc()
	_check("④a 막힌 칸 자신은 종전처럼 빠진다(SOLID 제거 — 회귀 잠금)",
		m._blocks_swing(front1) and not arc1.has(front1))
	_check("④b **그 뒤 칸도 함께 잘린다** — 돌 뒤의 제자리형(화귀·나찰)이 더는 공짜가 아니다",
		m._swing_shadowed(origin, front2) and not arc1.has(front2))
	_check("④c 날개(대각)는 가림 대상이 아니다 — 사이에 낀 칸이 없다(정면 직선만 가려진다)",
		not m._swing_shadowed(origin, front1 + perp)
		and not m._swing_shadowed(origin, front1 - perp))
	_check("④d 선 자리는 어떤 벽에도 안 가려진다(origin은 사이 칸이 0개)",
		not m._swing_shadowed(origin, origin) and arc1.has(origin))
	m._grid[front1.y][front1.x] = saved_cell
	_check("④e 돌을 치우면 정면 2칸이 되돌아온다(가림은 상태이지 영구 축소가 아니다)",
		(m._weapon_arc() as Array).has(front2))

	# ── ⑤ #5 릴 격투 중 LMB가 도구 디스패치로 안 샌다 ───────────────────────────
	print("── ⑤ #5 릴 격투 — 세 세션이 같은 줄에 선다 ──")
	var gate := _line_of("if not _sleeping and cheki == null and cocktail == null and fishing == null")
	_check("⑤a `_use_tool` 디스패치 게이트가 세션 셋을 **모두** 본다(체키·칵테일·낚시)",
		gate > 0)
	_check("⑤b 그 게이트는 여전히 자유 사용 물건·무기를 or-항으로 들고 있다(거동 축소 0)",
		_line_of("and (_target_valid or holding_weapon or pot_at_target or holding_free_use)") > 0)
	_check("⑤c 세션 틱 분기는 종전대로 return이 없다(그래서 게이트가 유일한 방어다)",
		_line_of("if fishing != null and not _sleeping:") > 0
		and _line_of("if fishing != null and not _sleeping:") < gate)
	_check("⑤d 태우던 두 동사는 그대로 존재한다 — 막은 것은 *중복 실행*이지 동사가 아니다",
		_line_of("func _eat_side_dish") > 0 and _line_of("func _drink_potion") > 0)

	# ── ⑥ #6 취침 연출 중엔 대화가 닫혀도 이동이 안 풀린다 ──────────────────────
	print("── ⑥ #6 암전 뒤 이동 잠금 — 대화 닫힘 경로가 취침을 존중한다 ──")
	m._sleeping = true
	m.player.set_physics_process(false)
	m.dialogue.start("시험", PackedStringArray(["암전 뒤에 넘겨지는 줄"]))
	m.dialogue.advance()          # 마지막 줄 넘김 → 닫힘 → _on_dialogue_finished
	_check("⑥a 취침 중(_sleeping)에 대화가 닫혀도 물리는 꺼진 채다 — 검은 화면 뒤 산책 차단",
		not m.dialogue.is_open() and not m.player.is_physics_processing())
	m._sleeping = false
	m.dialogue.start("시험", PackedStringArray(["깨어 있을 때의 줄"]))
	m.dialogue.advance()
	_check("⑥b 평상시엔 종전 그대로 즉시 풀린다(대화가 이동을 영구히 잠그지 않는다)",
		not m.dialogue.is_open() and m.player.is_physics_processing())
	_check("⑥c 형태는 `_end_cutscene`이 이미 쓰던 그것이다(두 닫힘 경로가 같은 술어를 본다)",
		_line_of("player.set_physics_process(not _sleeping)") > 0)
	m.player.set_physics_process(true)

	# ── ⑦ #7 선택지 위의 [G]가 제안을 파기하지 않는다 ───────────────────────────
	print("── ⑦ #7 선택지 + 고백 제안 — [G]는 삼키지 않는다 ──")
	m.dialogue.start("시험", PackedStringArray(["첫 줄", "물음 줄"]))
	m.dialogue.advance()
	var queued: bool = m.dialogue.queue_choice(PackedStringArray(["가", "나"]))
	_check("⑦pre 마지막 줄에 선택지가 서 있다(고백 제안과 물음의 공존 — R7 #8이 되살린 그 경로)",
		queued and m.dialogue.has_choice())
	m.dialogue.advance()
	_check("⑦a 전제 실증: 선택지 위의 `advance()`는 **확정 no-op**이다(줄·선택지 불변)",
		m.dialogue.is_open() and m.dialogue.has_choice()
		and m.dialogue.choices().size() == 2)
	_check("⑦b 그래서 [G] 분기가 선택지를 먼저 본다 — 제안을 파기하지 않고 아래로 흘린다",
		_line_of("if Input.is_action_just_pressed(\"gift_item\") and not dialogue.has_choice():") > 0)
	_check("⑦c [F]는 그대로다(replace_lines가 화면을 갈고 물음 원장까지 되감는 R8 경로 보존)",
		_line_of("if Input.is_action_just_pressed(\"shop_toggle\"):") > 0
		and _line_of("_resolve_confession(_confess_rid)") > 0)
	_check("⑦d 고르면 대화가 닫히고 `_on_dialogue_finished`가 제안을 접는다([G]와 같은 결과)",
		_line_of("_confess_rid = \"\"   # ★[S8-T6] 고백 제안은 그 대화 한정") > 0)
	m.dialogue.choose(0)
	_dismiss_dialogue(m)

	# ── ⑧⑨⑩ owner 결정 큐 — 지금 눈금을 고정한다(수정 아님) ────────────────────
	print("── ⑧⑨⑩ owner 결정 큐 — 현행 눈금 고정(뒤집을 때 무엇이 바뀌는지 보이게) ──")
	_check("⑧ 농사 XP만 판매가 파생이다 — 혼령초 20 vs 영혼 호박 160 vs 불사과 600(형제 4스킬은 고정표)",
		CropCatalog.sell_price(CropCatalog.HONRYEONGCHO) == 20
		and CropCatalog.sell_price(CropCatalog.YEONGHON_HOBAK) == 160
		and CropCatalog.sell_price(CropCatalog.BULSAGWA) == 600
		and ForageSkill.PICK_XP == 7 and MiningSkill.XP_MYEONGDONG == 5)
	_check("⑧′ 그래서 불사과 한 번 = L1 임계(100)의 6배다(owner 눈금 — 곡선 재조준은 owner 몫)",
		CropCatalog.sell_price(CropCatalog.BULSAGWA) >= FarmSkill.XP_THRESHOLDS[0] * 6)
	_check("⑨ 팬닝은 혼력 %d을 물지만 어떤 스킬 XP도 안 준다(ADR-0069 결정 2가 XP 축을 안 정했다)"
			% PanningSpots.PAN_ENERGY,
		PanningSpots.PAN_ENERGY > 0
		and not _in_pan_spot("_gain_mining_xp") and not _in_pan_spot("_gain_forage_xp")
		and not _in_pan_spot("_gain_farm_xp"))
	_check("⑨′ 형제 창구는 XP를 준다 — 갱도 바닥 줍기는 도구·혼력 0인데도 채집 XP(대비 축)",
		_line_of("_gain_forage_xp(ForageSkill.PICK_XP)") > 0)
	_check("⑩ 야생 수확은 채집 XP만 받고 미호 활동 크레딧은 안 받는데 `_run_harvested`엔 든다",
		_line_of("func _harvest_wild") > 0 and _in_harvest_wild("_run_harvested += 1")
		and not _in_harvest_wild("_activity_credit(\"miho\""))
	_check("⑩′ 그 원장을 읽는 곳이 셋이다 — 미호 deed 문턱·카페 3단·마무리 요약(어느 쪽을 고쳐도 셋이 함께 움직인다)",
		Deed.MIHO_HARVEST.size() == 4 and int(Deed.MIHO_HARVEST[3]) == 300
		and _line_of("CafeMilestone.is_complete(_run_harvested") > 0
		and _line_of("RunSummary.epilogue_text(clock.day, wallet.gold, _run_harvested") > 0)

	for s2 in SaveManager.SLOT_COUNT:
		_wipe_slot(s2)
	print("── 결과: %s (실패 %d)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# `_pan_spot` 본문 안에 그 문자열이 있나(함수 밖 동명 호출에 안 속게 — polish_r9 `_line_in_func` 결).
func _in_pan_spot(needle: String) -> bool:
	return _in_func("func _pan_spot", needle)

func _in_harvest_wild(needle: String) -> bool:
	return _in_func("func _harvest_wild", needle)

func _in_func(fn_needle: String, needle: String) -> bool:
	var head := _line_of(fn_needle)
	if head < 0:
		return false
	for i in range(head + 1, _src.size()):
		if _src[i].begins_with("func "):
			return false
		if _src[i].contains(needle):
			return true
	return false
