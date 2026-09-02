extends SceneTree
# ★[폴리시 11회차] 버그 헌트 확정분 회귀 — 배치 A(#1~#15).
#
# 렌즈: R10 diff 리뷰 · 자동 세이브 위상 · 연 넘김(절대 day 표시) · 초반 아크 · 배우자 일과.
#
# 무엇을 보증하나(발견 번호 = 11회차 헌트 배치 A):
#   ① #4(=#1·#8) 밀린 **절기 대량 재스폰 표**가 세이브에 안 실리고 로드가 지워, 집 밖 강제 취침
#         → F9 한 번이면 그 절기의 1회성 재스폰이 **영구 스킵**됐다(다음 기회 28일 뒤 = ADR-0055
#         개간 롱테일이 절기마다 무비용 면제). R10 #1이 형제 표 둘을 제외하며 근거로 든 "저쪽은
#         이미 집행된 원장이라 표만 버리면 그만"이 **거짓**이었음이 여기서 확정된다.
#   ② #6  밀린 **아침 방목 방출 표**도 같은 구멍이었다 — 파일의 `ranch`가 방출 전이라, 표를 버리면
#         그날치 F_GRAZE·M_GRAZE 가산이 전 마리 소실됐고 복구 경로는 화면에 없는 문 토글뿐이었다.
#   ③ #2  R10 #20의 캐스팅 선검사가 클램프 하한 `MIN_HOOK_ENERGY`(=1)를 봤는데 그 값은 **도달
#         불가**다(최저 체급 4 × 절감 하한 0.70 = 3). 혼력 1~3에서 미끼 소각 + 확정 실패가 그대로였다.
#   ④ #3  R10 #17의 폐기 금지 표가 `START_TOOLS` 5종만 파생 — 재구매 없는 1회 증정품 T1 낚싯대가
#         그대로 버려져 낚시 사슬 전체가 그 세이브에서 막혔다(소프트락).
#   ⑤ #7  B6 귀환이 비트·트랙 개통·세이브를 장면 **시작**에 찍는데 대사 열은 비영속이라, 재생 중
#         종료 시 §6.5 카타르시스 전환이 그 세이브에서 영영 못 떴다(R6가 B7에 준 처방의 형제 누락).
#   ⑥ #9·#10·#11 게시판 의뢰·시련·혼례 고지가 **절대 day**를 "%d일"로 찍어, day 29부터 게임 안에
#         존재하지 않는 눈금을 말했다("30일까지" / "119일까지" — 절기는 28일이 끝이고 달력 칸은 1..28).
#   ⑦ #12 온보딩 MEET_MIHO 안내가 시각을 안 봐, 카페 영업 시작 뒤엔 **빈 밭**을 가리켰다.
#   ⑧ #13·#14 미호·삽사리 예약 칸이 스타터 밭 안인데 주인이 화면에 없는 시간대엔 프롬프트가 통째로
#         사라져, day 1 튜토리얼 밭에서 괭이질이 **무알림 무동작**이었다.
#   ⑨ #15 배우자(미호) 아침 물주기가 노지 `farm`만 쳐, 재배를 늘봄방으로 옮기면 결혼 잡일 ①이
#         완전히 무효였다(늘봄방은 실내라 혼우 급수도 안 닿는다).
#
# 미봉합(판정만 남긴다): #5 = OWNER-DECISION. 밀린 밤 표의 단일 슬롯 덮어쓰기는 R9 머리말이
#   "밀린 밤 수만큼 곱해 물리는 건 페널티 설계 결정이라 여기서 새로 만들지 않는다(OWNER 큐)"로
#   이미 명시적으로 미룬 자리다 — 결함이 아니라 미결 눈금이라 이 파일은 *지금 계약*만 잠근다.

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

# main.gd 소스에서 needle이 든 줄의 인덱스(-1 = 없음) — polish_r7~r10의 그 헬퍼.
func _line_of(needle: String) -> int:
	for i in _src.size():
		if _src[i].contains(needle):
			return i
	return -1

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

func _wipe_slot(slot: int) -> void:
	var p := SaveManager.slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

# 그 슬롯 인덱스(id가 든 첫 칸 — 인벤에 find_item이 없어 테스트가 파생한다 — polish_r10의 그 헬퍼).
func _slot_of(m: Node, id: String) -> int:
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == id:
			return i
	return -1

func _initialize() -> void:
	print("══ 폴리시 11회차 — R10 diff · 자동 세이브 위상 · 연 넘김 · 초반 아크 · 배우자 일과(A) ══")
	_src = FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().split("\n")
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)

	var m := await _spawn_main()
	_dismiss_dialogue(m)
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)

	# ── ① #4(=#1·#8) 밀린 절기 재스폰 표가 세이브를 왕복한다 ─────────────────────
	print("── ① #4 절기 대량 재스폰 — 표가 원장과 같은 파일에 실린다 ──")
	_check("①a 표를 세우는 자리와 잡초 표의 자리가 **같은 함수**다(같은 위상 = 같은 계약)",
		_in_func("func _on_day_advanced", "_season_respawn_pending_day = day")
		and _in_func("func _on_day_advanced", "_weed_day_pending_day = day"))
	_check("①b 취침 자동 세이브는 날이 바뀐 **뒤**에 뜬다(그래서 표를 버리면 손실이 된다)",
		_in_func("func _on_sleep_done", "_save_game()"))
	m._season_respawn_pending_day = 29
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	_check("①c `_save_game`이 표를 실제로 적는다(키 season_respawn_pending_day = 29)",
		raw.has("season_respawn_pending_day") and int(raw["season_respawn_pending_day"]) == 29)
	_check("①d 같은 파일에 원장도 함께 실린다 — 표와 `reclaim`이 늘 같은 시점을 가리킨다",
		raw.has("reclaim") and raw.has("weed_pending_day") and raw.has("pasture_release_pending"))
	m._season_respawn_pending_day = 0
	var ok_load: bool = m._load_game()
	_check("①e 로드가 그 표를 되살린다(종전엔 무조건 0으로 버려 그 절기치가 영영 안 굴렀다) — 29",
		ok_load and m._season_respawn_pending_day == 29)
	_check("①f 하위호환 — 키 없는 구세이브는 0이다(파생 기본값이 종전과 같다)",
		int(({} as Dictionary).get("season_respawn_pending_day", 0)) == 0
		and _line_of("data.get(\"season_respawn_pending_day\", 0)") > 0)
	m._region = RegionCatalog.HOME
	m._sleeping = false
	m._transitioning = false
	await process_frame
	_check("①g 집에 있는 프레임이 그 표를 소비해 0으로 돌아간다(그 절기 재스폰이 실제로 굴렀다)",
		m._season_respawn_pending_day == 0)

	# ── ② #6 밀린 아침 방목 방출 표도 같은 계약 ─────────────────────────────────
	print("── ② #6 방목 방출 — 표가 세이브를 왕복한다 ──")
	m._pasture_release_pending = true
	m._save_game()
	var raw2: Dictionary = m.saver.load_game(m._active_slot)
	_check("②a `_save_game`이 표를 적는다(키 pasture_release_pending = true)",
		raw2.has("pasture_release_pending") and bool(raw2["pasture_release_pending"]))
	m._pasture_release_pending = false
	var ok_load2: bool = m._load_game()
	_check("②b 로드가 그 표를 되살린다(종전엔 무조건 false — 그날 방목 가산이 통째로 소실)",
		ok_load2 and m._pasture_release_pending)
	_check("②c 하위호환 — 키 없는 구세이브는 false다",
		not bool(({} as Dictionary).get("pasture_release_pending", false))
		and _line_of("data.get(\"pasture_release_pending\", false)") > 0)
	_check("②d 소비 계약은 안 바뀌었다 — **방출까지 간 프레임에만** 표를 지운다(R6 불변식)",
		_in_func("func _process", "if _release_open_buildings():"))
	m._pasture_release_pending = false

	# ── ③ #2 캐스팅 선검사가 도달 가능한 최저 비용을 본다 ───────────────────────
	print("── ③ #2 후킹 혼력 하한 — 클램프 값이 아니라 실제 도달 가능한 최저 비용 ──")
	var lowest_base := -1
	for p in FishingSession.CLASS_PRESETS:
		var e := int(p["energy"])
		if lowest_base < 0 or e < lowest_base:
			lowest_base = e
	var fish_override := 0
	for fid in FishCatalog.ids():
		if FishCatalog.session_params(String(fid)).has("energy"):
			fish_override += 1
	_check("③a 전제 확인: 어종 카탈로그에 체급 비용 오버라이드가 **한 종도 없다**(늘 프리셋 폴백) — %d종 중 0" % FishCatalog.ids().size(),
		FishCatalog.ids().size() > 0 and fish_override == 0)
	_check("③b 프리셋 최저 체급 비용(%d)이 곧 L0의 하한이다 — 클램프 값 1은 도달 불가" % lowest_base,
		FishingSession.min_hook_energy({}) == lowest_base
		and lowest_base > FishingSession.MIN_HOOK_ENERGY)
	var factor_max_skill := FishSkill.energy_factor(FishSkill.MAX_LEVEL)
	var floor_max_skill := FishingSession.min_hook_energy({"energy_factor": factor_max_skill})
	_check("③c 절감을 최대로 먹여도 하한은 %d — 여전히 클램프 값보다 크다(혼력 1~2는 어느 숙련에서도 확정 실패)" % floor_max_skill,
		floor_max_skill == maxi(int(round(float(lowest_base) * factor_max_skill)), FishingSession.MIN_HOOK_ENERGY)
		and floor_max_skill > FishingSession.MIN_HOOK_ENERGY)
	_check("③d 숙련이 오르면 하한이 **내려간다**(선검사가 스킬 축을 실제로 반영한다)",
		floor_max_skill < FishingSession.min_hook_energy({}))
	_check("③e 실집행 비용은 늘 이 하한 이상이다 — 소 체급 세션의 energy_cost로 대조",
		FishingSession.new(1, {"weight_class": FishingSession.WeightClass.SMALL}, {}, {}).energy_cost()
			>= FishingSession.min_hook_energy({}))
	_check("③f 화면(프롬프트)과 집행부(캐스팅)가 **같은 함수**를 부른다(갈림 0)",
		_in_func("func _start_fishing", "FishingSession.min_hook_energy(_fishing_mods())")
		and _line_of("energy.can_act(FishingSession.min_hook_energy(_fishing_mods()))") > 0
		and _line_of("energy.can_act(FishingSession.MIN_HOOK_ENERGY)") < 0)

	# ── ④ #3 T1 낚싯대는 버릴 수 없다 ───────────────────────────────────────────
	print("── ④ #3 휴지통 — 재구매 없는 증정 기어가 폐기 금지 표에 든다 ──")
	_check("④a 전제: T1은 증정품이라 매대 가격이 0이고, T2~T4는 값이 붙어 있다",
		GearCatalog.price_of(GearCatalog.ROD_T1) == 0
		and GearCatalog.price_of(GearCatalog.ROD_T2) > 0
		and GearCatalog.price_of(GearCatalog.ROD_T3) > 0
		and GearCatalog.price_of(GearCatalog.ROD_T4) > 0)
	var shop_rods: Array = []
	for row in m._fishshop_items():
		var bid := String(row.get("buy_id", ""))
		if GearCatalog.is_rod(bid):
			shop_rods.append(bid)
	_check("④b 전제: 생선가게 매대의 낚싯대 행은 T2·T3·T4뿐이다(T1 재구매 창구가 실재하지 않는다) — %s" % [shop_rods],
		not shop_rods.has(GearCatalog.ROD_T1) and shop_rods.has(GearCatalog.ROD_T2)
		and shop_rods.has(GearCatalog.ROD_T3) and shop_rods.has(GearCatalog.ROD_T4))
	m.inventory.add_item(GearCatalog.ROD_T1, 1)
	m.inventory.add_item(GearCatalog.ROD_T2, 1)
	var t1_slot := _slot_of(m, GearCatalog.ROD_T1)
	m._on_frame_discard(t1_slot)
	_check("④c T1은 휴지통이 거절한다 — 그 슬롯이 그대로 남는다(종전엔 영구 폐기 = 낚시 사슬 소프트락)",
		t1_slot >= 0 and _slot_of(m, GearCatalog.ROD_T1) >= 0)
	var t2_slot := _slot_of(m, GearCatalog.ROD_T2)
	m._on_frame_discard(t2_slot)
	_check("④d 값이 붙은 T2는 종전대로 버려진다(여분을 못 버리는 새 압박을 만들지 않는다)",
		t2_slot >= 0 and _slot_of(m, GearCatalog.ROD_T2) < 0)
	_check("④e 기본 도구 5종의 금지도 그대로다(R10 #17 계약 보존)",
		Inventory.START_TOOLS.size() == 5 and Inventory.START_TOOLS.has(ItemCatalog.HOE)
		and Inventory.START_TOOLS.has(ItemCatalog.WATERING_CAN)
		and Inventory.START_TOOLS.has(ItemCatalog.SCYTHE)
		and Inventory.START_TOOLS.has(ItemCatalog.PICKAXE)
		and Inventory.START_TOOLS.has(ItemCatalog.AXE))

	# ── ⑤ #7 B6 비트는 장면 **끝**에 선다 ───────────────────────────────────────
	print("── ⑤ #7 B6 귀환 — 비트·트랙 개통·세이브가 장면 끝으로 ──")
	_check("⑤a `_fire_spine_b6`은 더 이상 비트를 찍지 않는다(예약만 세운다)",
		_in_func("func _fire_spine_b6", "_spine_b6_pending = true")
		and not _in_func("func _fire_spine_b6", "_mark_spine_bit(SPINE_B6)")
		and not _in_func("func _fire_spine_b6", "_open_okja_track()"))
	_check("⑤b 장면을 거두는 자리가 셋을 함께 집행한다(비트·트랙 개통·세이브)",
		_in_func("func _close_spine_scene", "_mark_spine_bit(SPINE_B6)")
		and _in_func("func _close_spine_scene", "_open_okja_track()")
		and _in_func("func _close_spine_scene", "_save_game()"))
	_check("⑤c 형제 B7과 **같은 형태**다 — 저쪽 비트는 에필로그가 열리는 자리에 있다",
		_in_func("func _open_epilogue", "_mark_spine_bit(SPINE_B7)")
		and not _in_func("func _fire_spine_b7", "_mark_spine_bit(SPINE_B7)"))
	_check("⑤d 재개 훅이 재생 중에는 물러난다(예약 표가 가드 줄에 함께 섰다)",
		_in_func("func _maybe_resume_spine", "or _spine_b6_pending:"))
	# 라이브 — B5까지 지난 상태에서 B6를 튼다: 장면이 도는 동안 비트가 **안 서 있어야** 하고,
	# 장면이 닫히는 순간 비트·트랙이 함께 선다(중간 종료 = 재기동 시 처음부터 다시 재생).
	m._spine_bits = 0
	m._mark_spine_bit(m.SPINE_B5)
	m._spine_b6_pending = false
	m._fire_spine_b6()
	_check("⑤e 장면이 도는 동안 원장은 여전히 'B6가 안 왔다'이다(예약만 서 있다)",
		m._spine_b6_pending and not m._spine_bit_seen(m.SPINE_B6))
	_check("⑤f 그 사이에 재개 훅은 같은 장면을 겹쳐 세우지 않는다(가드가 실제로 먹는다)",
		not m._spine_say.is_empty() or m.cutscene != null)
	m._close_spine_scene()
	_check("⑤g 장면이 닫히는 프레임에 비트가 서고 앵커 트랙이 열린다",
		m._spine_bit_seen(m.SPINE_B6) and m._okja_track_open())
	_check("⑤h 예약은 소비돼 두 번 찍히지 않는다(멱등)",
		not m._spine_b6_pending)
	m._spine_bits = 0

	# ── ⑥ #9·#10·#11 기한·고지가 화면 눈금으로 접힌다 ──────────────────────────
	print("── ⑥ #9·#10·#11 절대 day 표기 — 절기 일차로 접는다 ──")
	_check("⑥a 전제: 게임의 표시 계층 어디에도 절대 day 눈금이 없다(달력은 1..%d칸)" % GameClock.DAYS_PER_SEASON,
		GameClock.day_of_season(GameClock.DAYS_PER_SEASON + 1) == 1
		and GameClock.date_label(GameClock.DAYS_PER_SEASON + 1)
			== "%s 1일" % GameClock.season_name(1))
	_check("⑥b 1년차 첫 절기에서는 종전 표기와 글자 그대로 같다(day == 일차 — 회귀 0)",
		GameClock.date_label(3) == "%s 3일" % GameClock.season_name(0))
	var q := QuestBoard.daily_quest(GameClock.DAYS_PER_SEASON + 1)
	var q_summary := QuestBoard.summary(q)
	_check("⑥c 의뢰 요약이 절기 일차로 말한다 — 종전 '%d일까지'는 달력에 없는 칸이었다(%s)"
			% [int(q["due_day"]), q_summary],
		q_summary.contains(GameClock.date_label(int(q["due_day"])))
		and not q_summary.contains("%d일까지" % int(q["due_day"])))
	var tr := TrialGround.weekly_trial(TrialGround.week_of(4 * GameClock.DAYS_PER_SEASON + 1))
	var tr_summary := TrialGround.summary(tr)
	_check("⑥d 시련 요약도 같은 눈금이다 — 주 기한이라 어긋남이 더 컸다(%s)" % tr_summary,
		tr_summary.contains(GameClock.date_label(int(tr["due_day"])))
		and not tr_summary.contains("%d일까지" % int(tr["due_day"])))
	_check("⑥e 혼례 고지 넷이 전부 접혔다(게임 유일의 혼례 날짜 고지 — 달력엔 마커가 없다)",
		_line_of("%d일 아침") < 0
		and _line_of("혼례를 올린다\" % GameClock.date_label(_wedding_day)") > 0)
	_check("⑥f 원장은 그대로 절대 day다 — 접는 것은 표시 계층뿐이다(due_day 산식 불변)",
		int(q["due_day"]) > GameClock.DAYS_PER_SEASON
		and int(tr["due_day"]) == QuestBoard.week_last_day(TrialGround.week_of(4 * GameClock.DAYS_PER_SEASON + 1)))

	# ── ⑦ #12 온보딩 MEET_MIHO 안내가 시각을 본다 ───────────────────────────────
	print("── ⑦ #12 온보딩 — 미호가 출근한 시간대엔 카페를 가리킨다 ──")
	var g_home: String = ""
	var g_away: String = ""
	m.onboarding.step = Onboarding.MEET_MIHO
	g_home = m.onboarding.guidance(false)
	g_away = m.onboarding.guidance(true)
	_check("⑦a 두 문구가 실제로 갈린다 — 밭 / 나루 마을 카페",
		g_home != g_away and g_home.contains("밭") and g_away.contains("카페")
		and g_away.contains("나루 마을"))
	_check("⑦b 다른 단계는 시각과 무관하다(안내가 하나뿐인 단계들은 거동 불변)",
		m.onboarding.guidance(true) != "" and _step_guides_stable(m))
	m.clock.minutes = float(Cafe.OPEN_MIN) - 60.0
	_check("⑦c 라이브 술어: 영업 시작 전에는 미호가 안식 농원 스테이션이다",
		not m._miho_stationed_away())
	m.clock.minutes = float(Cafe.OPEN_MIN) + 1.0
	_check("⑦d 라이브 술어: 영업 시작 뒤에는 구역이 갈린다(그 시각에 배너가 카페를 가리킨다)",
		m._miho_stationed_away())
	_check("⑦e main이 그 술어를 실제로 배너에 물린다(스케줄 파생 — 시각·좌표 복제 0)",
		_line_of("onboarding.guidance(_miho_stationed_away())") > 0)
	m.clock.minutes = float(GameClock.START_MIN)
	m.onboarding.step = Onboarding.DONE

	# ── ⑧ #13·#14 예약 칸의 침묵을 걷는다 ──────────────────────────────────────
	print("── ⑧ #13·#14 스타터 밭 안 예약 칸 — 사유가 화면에 뜬다 ──")
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)
	var patch: Rect2i = m.STARTER_PATCH_RECT
	_check("⑧a 전제: 두 예약 칸이 **스타터 밭 안**이고 흙으로 칠해져 있다(그래서 침묵이 치명적이었다)",
		patch.has_point(m.MIHO_FIELD_TILE) and patch.has_point(m.PET_TILE)
		and m._grid[m.MIHO_FIELD_TILE.y][m.MIHO_FIELD_TILE.x] == m.SOIL
		and m._grid[m.PET_TILE.y][m.PET_TILE.x] == m.SOIL)
	_check("⑧b 전제: 둘 다 농사 대상에서 빠진다(동사는 종전대로 막힌다 — 새 게이트 0)",
		not m._is_farmable(m.MIHO_FIELD_TILE) and not m._is_farmable(m.PET_TILE))
	m.inventory.select(_slot_of(m, ItemCatalog.HOE))
	m._target = m.MIHO_FIELD_TILE
	m._target_valid = m._is_farmable(m._target)
	var miho_prompt: String = m._farm_prompt()
	_check("⑧c 미호 칸에 커서를 두면 사유가 뜬다(종전엔 빈 문자열 = 프롬프트 자체가 사라졌다) — %s" % miho_prompt,
		miho_prompt != "" and miho_prompt.contains("미호"))
	m._target = m.PET_TILE
	m._target_valid = m._is_farmable(m._target)
	var pet_prompt: String = m._farm_prompt()
	_check("⑧d 삽사리 칸도 같다 — 입양 전(그림이 한 픽셀도 없을 때)에도 사유를 읽는다 — %s" % pet_prompt,
		pet_prompt != "" and pet_prompt.contains("삽사리"))
	_check("⑧e 두 문구가 갈린다(어느 자리인지 화면이 구분해 말한다)", miho_prompt != pet_prompt)
	# 평범한 밭 칸·예약 아닌 자리에는 아무 말도 새로 안 붙는다(회귀 0).
	var plain := Vector2i(-1, -1)
	for y in range(patch.position.y, patch.position.y + patch.size.y):
		for x in range(patch.position.x, patch.position.x + patch.size.x):
			var t := Vector2i(x, y)
			if t != m.MIHO_FIELD_TILE and t != m.PET_TILE and m._is_farmable(t):
				plain = t
				break
		if plain.x >= 0:
			break
	_check("⑧f 같은 밭의 평범한 칸 %s은 종전 그대로 **동사**를 안내한다(사유 문구가 안 샌다)" % [plain],
		plain.x >= 0 and m._reserved_tile_reason(plain) == "")
	_check("⑧g 흙이 아닌 칸에는 아무 말도 안 한다(길·벽 위에서 '누구의 자리'라고 하지 않는다)",
		m._reserved_tile_reason(Vector2i(-5, -5)) == "")
	_check("⑧h 다른 무대에서는 그 좌표가 예약 칸이 아니다(HOME 좌표 상수 — 구역 술어 보존)",
		_in_func("func _reserved_tile_reason", "_region != RegionCatalog.HOME"))

	# ── ⑨ #15 배우자 물주기가 늘봄방까지 본다 ──────────────────────────────────
	print("── ⑨ #15 배우자 아침 물주기 — 노지와 늘봄방을 한 예산으로 함께 돈다 ──")
	_check("⑨a 형제 창구는 이미 두 밭을 본다(스프링클러 = 칸의 주인 밭 라우팅 · 성장 = 독립 집행)",
		_in_func("func _on_day_advanced", "_field_at(st).sprinkle(st)")
		and _in_func("func _on_day_advanced", "greenhouse_farm.advance_day("))
	_check("⑨b 배우자 잡일이 늘봄방 창구를 실제로 부른다(남은 예산만큼 — 새 수치 0)",
		_in_func("func _on_day_advanced", "greenhouse_farm.water_dry(SPOUSE_MIHO_WATER_TILES - watered_by_spouse)"))
	# 라이브 — 노지를 비우고 늘봄방에만 심으면, 종전엔 0칸이라 알림조차 안 떴다.
	var gh_rect: Rect2i = m.GREENHOUSE_PLOT_RECT
	var gh_tiles: Array = []
	for i in range(m.SPOUSE_MIHO_WATER_TILES + 2):
		var gt := Vector2i(gh_rect.position.x + (i % gh_rect.size.x),
			gh_rect.position.y + (i / gh_rect.size.x))
		m.greenhouse_farm.hoe(gt)
		m.greenhouse_farm.plant(gt, CropCatalog.HONRYEONGCHO)
		gh_tiles.append(gt)
	var outdoor_first: int = m.farm.water_dry(m.SPOUSE_MIHO_WATER_TILES)
	var gh_watered: int = m.greenhouse_farm.water_dry(m.SPOUSE_MIHO_WATER_TILES - outdoor_first)
	_check("⑨c 노지가 비면 늘봄방이 그 예산을 그대로 받는다 — %d칸(예산 %d)"
			% [gh_watered, m.SPOUSE_MIHO_WATER_TILES],
		outdoor_first == 0 and gh_watered == m.SPOUSE_MIHO_WATER_TILES)
	var wet := 0
	for gt in gh_tiles:
		if m.greenhouse_farm.is_watered(gt):
			wet += 1
	_check("⑨d 적신 칸이 실제로 젖는다(늘봄방은 실내라 혼우 급수가 안 닿는 유일한 급수원) — %d칸이 젖고 %d칸이 남았다"
			% [wet, gh_tiles.size() - wet],
		wet == m.SPOUSE_MIHO_WATER_TILES and wet < gh_tiles.size())
	_check("⑨e 예산은 **한 몫**이다 — 밭이 늘었다고 곱절이 되지 않는다",
		outdoor_first + gh_watered == m.SPOUSE_MIHO_WATER_TILES)

	print("── 결과: %s (실패 %d)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# MEET_MIHO 밖의 단계들은 인자와 무관하게 같은 문구를 낸다(옛 호출부·구세이브 거동 불변).
func _step_guides_stable(m: Node) -> bool:
	var saved: int = m.onboarding.step
	var ok := true
	for st in [Onboarding.TILL, Onboarding.PLANT, Onboarding.WATER,
			Onboarding.GROW, Onboarding.HARVEST, Onboarding.NOTICE, Onboarding.DONE]:
		m.onboarding.step = st
		if m.onboarding.guidance(false) != m.onboarding.guidance(true):
			ok = false
	m.onboarding.step = saved
	return ok
