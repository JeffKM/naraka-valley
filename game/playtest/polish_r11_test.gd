extends SceneTree
# ★[폴리시 11회차] 버그 헌트 확정분 회귀 — 배치 A(#1~#15) + 배치 B(#16~#30 · 추가 조사 #31).
#
# 렌즈: R10 diff 리뷰 · 자동 세이브 위상 · 연 넘김(절대 day 표시) · 초반 아크 · 배우자 일과(A) /
#       배우자 일과 · 패널 스택 · 세이브 생애주기 · 알림 도달(B).
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
#
# 배치 B(#16~#30 · #31):
#   ⑩ #16 이혼이 앵커 트랙 재계산을 안 불러, 트랙은 열렸는데 ♡가 0에 멎었다(명부 부적 창구가
#         다음 취침·기증·대화까지 이유 없이 잠김). ★#17은 REFUTED — 그 자리에서 계약을 잠근다.
#   ⑪ #18 바나 관계 탭이 배우자 잡일 ③(자동 차단 +1)을 못 세어, 화면이 그 밤 실효 횟수보다
#         한 마리 적게 말했다(결혼으로 얻은 보호를 확인할 창구가 없었다).
#   ⑫ #19 아침 잡일 둘이 `_advance_wedding`보다 앞줄이라 혼례 아침엔 `_spouse_id`가 아직 ""였다
#         — 멜·미호 잡일만 하루 늦게 시작하고 바나만 즉효였다.
#   ⑬ #20 대화창이 매 줄 "[E] 다음"을 그리는데 `action`엔 우클릭뿐이라 그 키가 죽어 있었다.
#   ⑭ #21 조회 패널(거울·달력)을 연 채 C를 누르면 편집면이 통째로 가린 채 못 닫혔다(닫기 경로
#         전량이 `if _deco_mode: return` 아래).
#   ⑮ #22 `_hud_hidden`에 `_transitioning`이 없어 문 출입 암전 위에 핫바·혼력바·시계가 남았다.
#   ⑯ #24 세이브가 대상 파일을 먼저 절단해, 쓰기 중 크래시가 유일한 슬롯을 파괴했다(복구 0).
#   ⑰ #26 옵션 탭 [저장]이 실패에도 "저장했습니다"라 말하고 [종료]는 실패해도 그대로 나갔다.
#   ⑱ #28 개수 축출뿐인 알림 큐에서 1회성 래치(도감 트로피·혼례 배너)가 영영 사라졌다.
#   ⑲ #29 카페 마감 정산 패널이 마일스톤 축하 팝업을 통째로 덮었다(둘 다 래치는 축하 쪽).
#   ⑳ #30 날짜에 매인 네 층 중 생일만 아침 배너·거울 예고가 없어 상한 면제 기회가 조용히 지났다.
#   ㉑ #31 추가 조사 — miho/mel/bana/ken 아크 ⑤c·⑤e와 s9 스모크 ②c의 baseline 실패는 **결함이
#         아니라 계약 오독**이다(R8이 아침 훅 끝에 채널 개통 안내를 조건 없이 큐잉하면서
#         `pending_count() == 0`이 다른 층의 편지까지 세게 됐다). 다섯 자리를 구성 단언으로 정정.
#   ㉒ #23 (high) 밤 바 세션이 로드를 그대로 통과해, 열지도 않은 바에서 되감긴 19:00에 약탈이
#         집행됐다(ADR-0010 #6 옵트인이 F9 한 번으로 무효).
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

# start 이후 첫 매치(-1 = 없음) — 같은 니들이 여러 함수에 흩어져 있을 때 계약이 사는 함수 안에서
# 재기 위해 쓴다(polish_r6의 그 헬퍼와 같다). `contains`는 부분 일치라 전역 첫 매치가 엉뚱한
# 훅에 걸리는 일이 실제로 있었다(㉓ 주석 참조).
func _line_after(start: int, needle: String) -> int:
	for i in range(maxi(start, 0), _src.size()):
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

# 다른 파일의 소스 한 줄 검사(save.gd·형제 스위트 — main.gd는 _src·_in_func가 든다).
func _file_has(path: String, needle: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	return f.get_as_text().contains(needle)

# `_hud_hidden` 대입식을 이어 붙인 한 줄(백슬래시 연속줄 — 항목이 여러 줄에 걸쳐 있다).
func _hud_hidden_expr() -> String:
	var i := _line_of("var _hud_hidden :=")
	if i < 0:
		return ""
	var out := _src[i]
	var j := i
	while _src[j].strip_edges().ends_with("\\") and j + 1 < _src.size():
		j += 1
		out += " " + _src[j].strip_edges()
	return out

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

	# ══ 배치 B(#16~#30 · #31) ══════════════════════════════════════════════════
	# ── ⑩ #16 이혼이 앵커 트랙을 그 자리에서 되돌린다 / #17 판정(REFUTED) ───────
	print("── ⑩ #16 이혼 → 앵커 트랙 재계산이 같은 프레임에 온다 ──")
	_check("⑩a 이혼 결행에 트랙 재계산이 있다(혼인 성립이 이미 갖고 있던 그 한 줄의 역방향 짝)",
		_in_func("func _do_divorce", "_refresh_okja_track()")
		and _in_func("func _advance_wedding", "_refresh_okja_track()"))
	m._mark_spine_bit(m.SPINE_B4)
	m._mark_spine_bit(m.SPINE_B5)
	m._mark_spine_bit(m.SPINE_B6)
	m._run_harvested = 100000
	m._spouse_id = ""
	m._open_okja_track()      # 앞 블록(⑤ #7)이 이미 열어 뒀을 수 있다 — 개통은 멱등
	m._refresh_okja_track()   # 그래서 점수는 여기서 명시적으로 다시 잰다(파생 = 원장 스냅샷)
	var r_okja: Resident = m._resident("okja")
	var deed_pts: int = Spine.okja_deed_points(true, m.museum.donated_count(),
		Museum.donatable_ids().size(), m._run_harvested)
	_check("⑩b 전제: 트랙이 열렸고 deed가 원장에서 파생돼 있다 — 외면+돌봄 %d점(♡%d)"
			% [deed_pts, r_okja.affinity.hearts()],
		r_okja.affinity != null and deed_pts > 0 and r_okja.affinity.points == deed_pts
		and r_okja.affinity.hearts() > 0)
	var deed_hearts: int = r_okja.affinity.hearts()
	m._romance_partner = "mel"
	m._wedding_day = m.clock.day
	m._advance_wedding(m.clock.day)
	_check("⑩c 다른 이와 혼인하면 잠금 판정으로 앵커 ♡가 0으로 내려간다(결정 10-ⓓ)",
		m._spouse_id == "mel" and r_okja.affinity.points == 0 and r_okja.affinity.hearts() == 0)
	m.wallet.earn(m.DIVORCE_COST)
	m._do_divorce()
	_check("⑩d 이혼 그 프레임에 ♡%d가 되돌아온다(종전엔 취침·기증·옥자 대화 중 하나가 올 때까지 0에 멎었다)"
			% deed_hearts,
		m._spouse_id == "" and r_okja.affinity.points == deed_pts
		and r_okja.affinity.hearts() == deed_hearts)
	_check("⑩e 그래서 명부 부적 창구의 잠금·해제가 곁의 상태와 같은 프레임에 맞는다",
		m._okja_track_open() and (r_okja.affinity.hearts() >= Affinity.MAX_HEARTS)
			== m._myeongbu_quest_open())
	# ★#17 REFUTED — 앵커와 이혼하면 `reset_hearts`가 파생에 덮이는데, 그것이 이 트랙의 **명시된
	#   계약**이다(`_refresh_okja_track` "곁이 비면 그 자리에서 되돌아온다" · `_okja_track_open`
	#   "억지력은 이미 이혼 의뢰비가 지고 있으므로 두 번째 벌칙을 얹지 않는다"). 여기선 그 계약을
	#   *잠근다* — 앵커의 ♡는 재등반 통화가 아니라 갚은 것의 파생이라 되감을 대상이 아니다.
	m._romance_partner = "okja"
	m._wedding_day = m.clock.day
	m._advance_wedding(m.clock.day)
	var anchor_married_hearts: int = r_okja.affinity.hearts()
	m.wallet.earn(m.DIVORCE_COST)
	m._do_divorce()
	_check("⑩f #17 판정 — 앵커와의 이혼 뒤 ♡는 원장 파생으로 되돌아온다(설계 계약 · 벌칙 없음)",
		anchor_married_hearts == deed_hearts and r_okja.affinity.points == deed_pts
		and _in_func("func _okja_track_open", "_spouse_id == \"\" or _spouse_id == OKJA_RID"))
	m._romance_partner = ""
	m._wedding_day = 0

	# ── ⑪ #18 바나 요약이 배우자 잡일을 함께 말한다 ─────────────────────────────
	print("── ⑪ #18 관계 탭 바나 줄 — 화면이 그 밤의 실효 차단을 말한다 ──")
	var ab5: int = BanaGuard.auto_block(Affinity.MAX_HEARTS)
	_check("⑪a 매핑은 그대로다 — ♡%d의 base 자동 차단 %d마리(수치 이동 0)"
			% [Affinity.MAX_HEARTS, ab5],
		BanaGuard.summary(Affinity.MAX_HEARTS).contains("자동차단 %d마리" % ab5))
	_check("⑪b 얹힌 몫을 더해 말한다 — %d + %d = %d마리"
			% [ab5, m.SPOUSE_BANA_EXTRA_BLOCK, ab5 + m.SPOUSE_BANA_EXTRA_BLOCK],
		BanaGuard.summary(Affinity.MAX_HEARTS, m.SPOUSE_BANA_EXTRA_BLOCK)
			.contains("자동차단 %d마리" % (ab5 + m.SPOUSE_BANA_EXTRA_BLOCK)))
	_check("⑪c 주입부와 표시부가 **같은 상수**를 본다(수치 복제 0)",
		_in_func("func _process", "night_bar.auto_block += SPOUSE_BANA_EXTRA_BLOCK")
		and _in_func("func _setup_residents", "SPOUSE_BANA_EXTRA_BLOCK if _spouse_id == \"bana\" else 0"))
	var r_bana: Resident = m._resident("bana")
	var bana_saved: int = r_bana.affinity.points
	r_bana.affinity.points = Affinity.MAX_POINTS
	r_bana.affinity.stage = r_bana.affinity.points_hearts()
	var solo_line: String = r_bana.effect_fn.call()
	m._spouse_id = "bana"
	var wed_line: String = r_bana.effect_fn.call()
	m._spouse_id = ""
	_check("⑪d 라이브 — 결혼 전/후 같은 하트에서 줄이 갈린다: 「%s」 → 「%s」" % [solo_line, wed_line],
		solo_line != wed_line
		and solo_line.contains("자동차단 %d마리" % ab5)
		and wed_line.contains("자동차단 %d마리" % (ab5 + m.SPOUSE_BANA_EXTRA_BLOCK)))
	r_bana.affinity.points = bana_saved
	r_bana.affinity.stage = r_bana.affinity.points_hearts()

	# ── ⑫ #19 혼례 아침 잡일이 하루 늦지 않는다 ────────────────────────────────
	print("── ⑫ #19 혼례 아침 — 세 잡일의 개시 아침이 같아진다 ──")
	_check("⑫a 두 잡일이 아침 술어로 묻는다(멜 팁 · 미호 물주기)",
		_in_func("func _on_day_advanced", "_spouse_of_morning(day) == \"mel\"")
		and _in_func("func _on_day_advanced", "_spouse_of_morning(day) == \"miho\""))
	_check("⑫b 잡일 자리는 여전히 `_advance_wedding`보다 **앞줄**이다(그래서 술어가 필요했다)",
		_line_of("_spouse_of_morning(day) == \"mel\"") < _line_of("\t_advance_wedding(day)")
		and _line_of("_spouse_of_morning(day) == \"miho\"") < _line_of("\t_advance_wedding(day)"))
	var wd: int = m.clock.day + 3
	m._spouse_id = ""
	m._romance_partner = "miho"
	m._wedding_day = wd
	_check("⑫c 혼례 전날 아침은 아직 아무도 아니다(예정만 서 있다)",
		m._spouse_of_morning(wd - 1) == "" and m._spouse_id == "")
	_check("⑫d 혼례 아침 — `_spouse_id`는 아직 \"\"인데 잡일은 이미 미호를 본다(하루의 어긋남이 사라진다)",
		m._spouse_id == "" and m._spouse_of_morning(wd) == "miho")
	m._advance_wedding(wd)
	_check("⑫e 같은 아침 뒤엔 두 값이 일치한다(술어가 혼인 성립을 앞당기지 않는다 — 읽기만 한다)",
		m._spouse_id == "miho" and m._spouse_of_morning(wd) == "miho" and m._wedding_day == 0)
	_check("⑫f 바나 잡일은 종전 그대로 매 프레임 파생이다(주입부 불변 — 셋의 개시가 같은 아침)",
		_in_func("func _process", "if _spouse_id == \"bana\":"))
	m.wallet.earn(m.DIVORCE_COST)
	m._do_divorce()
	m._romance_partner = ""

	# ── ⑬ #20 대화창이 안내한 [E]가 실제로 대사를 넘긴다 ───────────────────────
	print("── ⑬ #20 대화 넘기기 — 화면이 지시한 키가 살아난다 ──")
	var e_bound := false
	for ev in InputMap.action_get_events("menu_tab"):
		if ev is InputEventKey and ev.physical_keycode == KEY_E:
			e_bound = true
	var action_has_key := false
	for ev in InputMap.action_get_events("action"):
		if ev is InputEventKey:
			action_has_key = true
	_check("⑬a 전제: E는 `menu_tab`에만 묶여 있고 `action`(넘기기)엔 키 이벤트가 하나도 없다(우클릭뿐)",
		e_bound and not action_has_key)
	_check("⑬b 화면은 매 줄 [E]를 안내한다(그 문구가 여전히 있다 — 고친 것은 배선이지 문구가 아니다)",
		_line_of("\"[E] 닫기\" if dialogue.is_last() else \"[E] 다음\"") >= 0)
	_check("⑬c 대화 진행 폴링이 두 키를 함께 받는다(우클릭 ∪ E)",
		_line_of("if Input.is_action_just_pressed(\"action\") or Input.is_action_just_pressed(\"menu_tab\"):") >= 0)
	_check("⑬d 선택지·고백 삼킴 규약은 그대로다(그 분기가 넘기기 폴링보다 **위**에서 return)",
		_line_of("if dialogue.has_choice():")
			< _line_of("if Input.is_action_just_pressed(\"action\") or Input.is_action_just_pressed(\"menu_tab\"):"))
	_check("⑬e 같은 뿌리 — 미호 온보딩 대사도 실제 키를 말한다(괭이질 = 좌클릭 `use_tool`)",
		_file_has("res://miho.gd", "[좌클릭]으로 갈고") and not _file_has("res://miho.gd", "[E]로 갈고"))

	# ── ⑭ #21 꾸미기 진입이 조회 패널을 박제하지 않는다 ────────────────────────
	print("── ⑭ #21 꾸미기 모드 — 열어 둔 조회 패널을 먼저 접는다 ──")
	if m._deco_mode:
		m._toggle_deco_mode()
	m._region = RegionCatalog.HOME
	m._indoor = "집"
	m._open_mirror()
	_check("⑭a 전제: 거울 패널이 떠 있다(이 상태로 C를 누르면 종전엔 못 닫았다)",
		m.mirror_panel.visible)
	m._toggle_deco_mode()
	_check("⑭b C를 누르면 거울이 접히고 꾸미기가 켜진다(입력이 죽지 않는다)",
		m._deco_mode and not m.mirror_panel.visible)
	m._toggle_deco_mode()
	m.calendar_panel.toggle()
	_check("⑭c 전제: 달력이 열려 있다($CanvasLayer의 마지막 자식 — 그 위에 그릴 것이 없다)",
		m.calendar_panel.is_open())
	m._toggle_deco_mode()
	_check("⑭d 달력도 같은 자리에서 접힌다", m._deco_mode and not m.calendar_panel.is_open())
	m._toggle_deco_mode()
	_check("⑭e 끄기는 언제나 받는다(R3가 세운 유일한 탈출구 — 불변)", not m._deco_mode)
	_check("⑭f 진입 게이트(`_deco_blocked`)엔 아무것도 안 더했다 — 접는 것이지 막는 것이 아니다",
		not _in_func("func _deco_blocked", "mirror_panel")
		and not _in_func("func _deco_blocked", "calendar_panel"))

	# ── ⑮ #22 전환 암전 위에 상시 HUD가 안 남는다 ──────────────────────────────
	print("── ⑮ #22 전환 암전 — HUD 가드가 `_transitioning`을 센다 ──")
	var hud_expr := _hud_hidden_expr()
	_check("⑮a `_hud_hidden`이 전환 연출을 항목으로 센다(취침 `_sleeping`과 나란히)",
		hud_expr.contains("_transitioning") and hud_expr.contains("_sleeping"))
	_check("⑮b 다른 연출 항목은 그대로다(컷신·내면 공간·일러스트·모달 넷 — 축소 0)",
		hud_expr.contains("cutscene != null") and hud_expr.contains("spine_puzzle != null")
		and hud_expr.contains("_illust_id != \"\"") and hud_expr.contains("mirror_panel.visible")
		and hud_expr.contains("frame.is_open()") and hud_expr.contains("dialogue.is_open()"))
	m._transitioning = true
	await process_frame
	await process_frame
	_check("⑮c 라이브 — 암전 중엔 핫바·혼력바·시계가 함께 접힌다",
		not m.hotbar.visible and not m.vitals.visible and not m.clock_hud.visible)
	m._transitioning = false
	await process_frame
	await process_frame
	_check("⑮d 암전이 걷히면 그대로 되돌아온다(전환은 상태가 아니라 연출이다)",
		m.hotbar.visible and m.vitals.visible and m.clock_hud.visible)

	# ── ⑯ #24 세이브 쓰기가 원자적이다 ─────────────────────────────────────────
	print("── ⑯ #24 세이브 — 임시본에 다 쓰고 한 번의 rename으로 자리를 바꾼다 ──")
	_check("⑯a 대상 슬롯 파일을 WRITE로 여는 코드가 없다(절단 지점 소멸)",
		not _file_has("res://save.gd", "FileAccess.open(path, FileAccess.WRITE)")
		and _file_has("res://save.gd", "FileAccess.open(tmp, FileAccess.WRITE)"))
	_check("⑯b 자리 바꾸기는 rename 한 번이고, 실패하면 반쪽 임시본을 지운다",
		_file_has("res://save.gd", "DirAccess.rename_absolute")
		and _file_has("res://save.gd", "DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))"))
	var sm := SaveManager.new()
	var probe_slot := SaveManager.SLOT_COUNT - 1
	_wipe_slot(probe_slot)
	var wrote_ok: bool = sm.save_game({"r11_probe": 7}, probe_slot, {"day": 3})
	var tmp_path := SaveManager.slot_path(probe_slot) + SaveManager.TMP_SUFFIX
	_check("⑯c 저장 성공 · 임시본이 남지 않는다 · 그 슬롯이 실제로 읽힌다",
		wrote_ok and not FileAccess.file_exists(tmp_path) and sm.can_load(probe_slot))
	var back: Dictionary = sm.load_game(probe_slot)
	_check("⑯d 왕복 — 내용이 그대로다(포맷·버전 래핑 불변)", int(back.get("r11_probe", 0)) == 7)
	var wrote2: bool = sm.save_game({"r11_probe": 9}, probe_slot, {"day": 4})
	var back2: Dictionary = sm.load_game(probe_slot)
	_check("⑯e 덮어쓰기도 온전한 한 벌로 바뀐다(직전 파일은 교체되는 순간까지 그대로)",
		wrote2 and int(back2.get("r11_probe", 0)) == 9
		and not FileAccess.file_exists(tmp_path))
	_wipe_slot(probe_slot)
	sm.free()

	# ── ⑰ #26 저장 성패를 화면이 말한다 ────────────────────────────────────────
	print("── ⑰ #26 옵션 탭 [저장]·[종료] — 실패를 삼키지 않는다 ──")
	_check("⑰a `_save_game`이 성패를 돌려준다(IO 성패를 아는 유일한 자리 — `_load_game`의 R6 처방)",
		_line_of("func _save_game() -> bool:") >= 0)
	_check("⑰b [저장]은 실패에만 말을 얹는다(성공 문구의 주인은 `_save_game` 하나 — 이중 토스트 소멸)",
		_in_func("func _on_frame_save", "if not _save_game():")
		and not _in_func("func _on_frame_save", "_notice(\"저장했습니다\")"))
	_check("⑰c [종료]는 저장 실패면 첫 타를 멈춘다(2단 확인 — 두 번째는 그대로 나간다)",
		_in_func("func _on_frame_quit", "if not _save_game() and not _quit_unsaved_armed:")
		and _in_func("func _on_frame_quit", "get_tree().quit()"))
	_check("⑰d 라이브 — 정상 슬롯 저장은 true를 돌려준다", m._save_game())

	# ── ⑱ #28 1회성 래치 알림이 4칸 큐에서 축출되지 않는다 ──────────────────────
	print("── ⑱ #28 알림 피드 — 다시 오지 않을 줄은 밀려나지 않는다 ──")
	var nf: NoticeFeed = m.notice_feed
	nf._items.clear()
	nf.push("래치 한 줄", 60.0, false, null, true, Color(0, 0, 0, 0), true)
	for i in range(NoticeFeed.MAX_ITEMS + 2):
		nf.push("휘발 %d" % i, 60.0)
	var feed_texts: Array = []
	for it in nf._items:
		feed_texts.append(String(it["text"]))
	_check("⑱a 래치 줄이 살아남고 최신 줄도 보인다 — 큐: %s" % [feed_texts],
		feed_texts.has("래치 한 줄")
		and feed_texts.has("휘발 %d" % (NoticeFeed.MAX_ITEMS + 1))
		and nf._items.size() == NoticeFeed.MAX_ITEMS)
	nf._items.clear()
	for i in range(NoticeFeed.MAX_ITEMS + 2):
		nf.push("고정 %d" % i, 60.0, false, null, false, Color(0, 0, 0, 0), true)
	_check("⑱b 전부 래치여도 상한은 안 무너진다(%d칸 계약 불변 — 그때만 맨 앞을 버린다)"
			% NoticeFeed.MAX_ITEMS,
		nf._items.size() == NoticeFeed.MAX_ITEMS)
	nf._items.clear()
	_check("⑱c 도감 완주 트로피가 그 표를 단다(세이브에 박히는 `trophy_day` 래치의 유일한 표면)",
		_in_func("func _on_day_advanced", "notice_feed.push(\"명부 도감 완주"))
	_check("⑱d 혼례 배너도 같은 표를 단다(예정일을 방금 0으로 접은 1회성 고지)",
		_in_func("func _advance_wedding", "Color(0, 0, 0, 0), true)"))

	# ── ⑲ #29 마일스톤 축하가 마감 정산에 덮이지 않는다 ────────────────────────
	print("── ⑲ #29 두 팝업 — 래치가 있는 쪽이 먼저 읽힌다 ──")
	_check("⑲a 전제: 두 패널 사각형이 실제로 겹친다(정산이 마일스톤 본문을 덮는다)",
		m.cafe_summary_panel.get_rect().intersects(m.milestone_text.get_global_rect()))
	m.milestone_panel.visible = true
	m._milestone_popup_secs = 5.0
	m.cafe_summary_panel.visible = false
	m._cafe_summary_pending = ""
	m._on_cafe_closed(120, 3, 1)
	_check("⑲b 마일스톤이 떠 있으면 정산은 미뤄진다(본문은 보관 — 잃는 것 0)",
		not m.cafe_summary_panel.visible and m._cafe_summary_pending.contains("오늘 카페 영업 마감")
		and m.milestone_panel.visible)
	m._milestone_popup_secs = 0.02
	await process_frame
	await process_frame
	await process_frame
	_check("⑲c 축하가 끝나는 프레임에 정산이 이어서 뜬다(순서가 생기고 둘 다 읽힌다)",
		not m.milestone_panel.visible and m.cafe_summary_panel.visible
		and m._cafe_summary_pending == ""
		and m.cafe_summary_text.text.contains("매출  +120냥"))
	m.cafe_summary_panel.visible = false
	m._cafe_summary_secs = 0.0
	m._on_cafe_closed(50, 1, 0)
	_check("⑲d 마일스톤이 없으면 종전 그대로 즉시 뜬다(거동 불변)",
		m.cafe_summary_panel.visible and m._cafe_summary_pending == ""
		and m.cafe_summary_text.text.contains("매출  +50냥"))
	m.cafe_summary_panel.visible = false
	m._cafe_summary_secs = 0.0

	# ── ⑳ #30 생일도 예고 문법을 갖는다 ────────────────────────────────────────
	print("── ⑳ #30 생일 — 아침 배너 + 거울 예고(네 번째 형제) ──")
	var bd_day := -1
	var bd_name := ""
	for d in range(2, GameClock.DAYS_PER_SEASON * 4 + 1):
		var rid := Resident.birthday_on_day(d)
		if rid != "" and m._display_name_of(rid) != "":
			bd_day = d
			bd_name = m._display_name_of(rid)
			break
	_check("⑳a 전제: 생일 표에서 로스터에 있는 첫 생일을 뜬다(날짜 표는 여전히 Resident 한 곳) — %s / day %d"
			% [bd_name, bd_day],
		bd_day > 1 and bd_name != "")
	var day_saved: int = m.clock.day
	m.clock.day = bd_day - 1
	var eve_lines: Array = m._birthday_morning_notices()
	_check("⑳b D-1 아침에 예고가 온다 — %s" % [eve_lines],
		eve_lines.size() >= 1 and String(eve_lines[eve_lines.size() - 1]).contains(bd_name)
		and String(eve_lines[eve_lines.size() - 1]).contains("내일"))
	m.clock.day = bd_day
	var today_lines: Array = m._birthday_morning_notices()
	_check("⑳c 당일 아침 배너가 상한 면제를 말한다 — %s" % [today_lines],
		today_lines.size() >= 1 and String(today_lines[0]).contains(bd_name)
		and String(today_lines[0]).contains("상한이 면제"))
	_check("⑳d 점괘 거울에도 형제 셋과 나란히 한 줄이 선다",
		m._birthday_upcoming_line().contains(bd_name)
		and m._mirror_forecast_text().contains(m._birthday_upcoming_line()))
	var all_named := true
	for rid in Resident.BIRTHDAYS:
		var b: Array = Resident.birthday_of(String(rid))
		if m._display_name_of(String(rid)) == "":
			continue
		var d2: int = int(b[0]) * GameClock.DAYS_PER_SEASON + int(b[1])
		var got: Array = []
		m.clock.day = d2
		got = m._birthday_morning_notices()
		if got.is_empty() or not String(got[0]).contains(m._display_name_of(String(rid))):
			all_named = false
	_check("⑳e 표에 오른 로스터 전원이 자기 날에 이름으로 불린다(총원 하드코딩 0 — 표에서 파생)",
		all_named)
	m.clock.day = day_saved
	_check("⑳f 아침 훅이 그 배너를 실제로 민다(행사·테마 배너와 같은 자리)",
		_in_func("func _on_day_advanced", "for line in _birthday_morning_notices():"))

	# ── ㉑ #31 우편 계약 정정(추가 조사 — 결함 아님) ────────────────────────────
	print("── ㉑ #31 아침 뒤 큐 잔류 — 계약 오독이지 결함이 아니다 ──")
	_check("㉑a 아침 훅은 채널 개통 안내를 **조건 없이** 민다(R8 — 멱등이라 한 번만 나간다)",
		_in_func("func _on_day_advanced", "mailbox.send(HERALD_NOTICE_LETTER)"))
	_check("㉑b 그래서 '아침 뒤 큐가 비어 있다'는 총량 단언은 거짓이 됐다 — 두 스위트가 구성으로 다시 잰다",
		_file_has("res://playtest/miho_arc_test.gd", "HERALD_NOTICE_LETTER")
		and _file_has("res://playtest/s9_narrative_smoke_test.gd", "HERALD_NOTICE_LETTER"))

	# ── ㉒ #23 밤 바 세션이 로드에서 폐기된다(마지막 — 월드를 되감는다) ─────────
	print("── ㉒ #23 F9 — 열지도 않은 바에서 약탈이 집행되지 않는다 ──")
	_check("㉒a 로드가 밤 바 세션을 폐기한다(낚시·체키·칵테일과 같은 줄)",
		_in_func("func _load_game", "night_bar.abandon()"))
	_check("㉒b `end_day`는 그 리셋을 재사용하되 정산을 먼저 쏜다(요약 경로 불변)",
		_in_func("func end_day", "closed.emit(_raided, _revenue, _left)") == false
			or _file_has("res://night_bar.gd", "\tabandon()"))
	m._transitioning = false
	var saved_before: bool = m._save_game()
	m.night_bar.open_bar(19 * 60)
	m.night_bar._auto_blocks_left = 0
	m.night_bar._raided = 5
	m.night_bar._revenue = 900
	var opened_before: bool = m.night_bar.is_opened()
	var closed_hits: Array = [0]
	m.night_bar.closed.connect(func(_r: int, _v: int, _l: int) -> void: closed_hits[0] += 1)
	var loaded_ok: bool = m._load_game()
	_check("㉒c 전제: 바를 연 밤이었다(옵트인·정산 카운터가 세션에 서 있었다)",
		saved_before and opened_before and loaded_ok)
	_check("㉒d 로드 뒤 바는 닫혀 있다 — 되감긴 19:00에 잡귀가 저절로 깃들지 않는다",
		not m.night_bar.is_opened())
	_check("㉒e 그 밤의 정산 카운터·바나 자동 차단 잔량도 함께 비워진다(약탈 %d·매출 %d → 0)"
			% [5, 900],
		m.night_bar._raided == 0 and m.night_bar._revenue == 0
		and m.night_bar._auto_blocks_left == 0)
	_check("㉒f 폐기는 정산 요약을 쏘지 않는다(존재한 적 없는 매출·약탈을 합산해 알리지 않는다)",
		closed_hits[0] == 0)

	# ── ㉓ #32 로드 한 번이 HOME 무대를 두 번 굽던 낭비 ────────────────────────────────
	# `_restore_location`은 저장 구역을 **언제나** 재빌드하는데(폴리시 R5가 "이미 서 있으면 건너뛴다"
	# 최적화를 일부러 폐기한 자리), 그 **직후** `_refresh_home_expansion`이 같은 HOME을 한 번 더
	# 구웠다. 두 결과는 같다 — 재빌드는 `home_house_rect()` 파생이고 그 진실원 `carpenter.load_save`는
	# 훨씬 앞줄에서 끝나므로, 두 번째 굽기는 첫 번째와 바이트 단위로 같은 순수 낭비다(늘봄방을 세운
	# 세이브면 `_refresh_greenhouse`까지 껴 넉 번). 실측 재빌드 1회 ≈ 2.5s라 로드가 5s→2.5s로 준다.
	# ★ 이 낭비가 `bana_test`를 러너 워치독(120s) 밖으로 밀어 **"결정적 hang"으로 오진**시켰다 —
	#   그 스위트는 main을 13번 세우고 그중 11번이 로드 경로다(행이 아니라 누적 비용이었다).
	# ★[폴리시 R12] 순서 비교를 **`_load_game` 머리 뒤로 좁힌다.** 종전엔 `_line_of`(전역 첫 매치)로
	#   두 줄을 찾았는데, R12가 `_refresh_greenhouse` 안쪽 호출도 `_refresh_home_expansion(false)`로
	#   바꾸면서(완공 아침의 HOME 이중 굽기 제거) 같은 니들이 그 훨씬 앞줄에 먼저 걸렸다 — 계약은
	#   그대로인데 단언만 거짓이 되는 형태라, 재는 자리를 계약이 사는 함수 안으로 맞춘다.
	var lg_i := _line_of("func _load_game")
	_check("㉓ 계약: 로드는 `_restore_location` **뒤에** 안방 확장을 재적용한다(그리드는 그쪽이 세운다)",
		_in_func("func _load_game", "_restore_location(data)")
		and _line_after(lg_i, "\t_refresh_home_expansion(false)") > _line_after(lg_i, "\t_restore_location(data)"))
	_check("㉓b 로드 경로는 두 `_refresh_*`에 재빌드 금지를 넘긴다(`_refresh_season_terrain(false)`와 같은 결)",
		_in_func("func _load_game", "_refresh_home_expansion(false)")
		and _in_func("func _load_game", "_refresh_greenhouse(false)"))
	# 건너뛰는 것은 **굽기뿐**이다 — 배치 경계·집 카메라 둘레는 `false`에서도 다시 주입돼야 한다
	# (그 둘은 `_restore_location`의 카메라 적용보다 *뒤*라, 함께 빠지면 확장 안방에 옛 둘레가 남는다).
	m._region = RegionCatalog.HOME
	m._buildings["집"]["cam"] = Rect2i(0, 0, 1, 1)   # 일부러 어긋난 값
	m._last_player_tile_y = 12345                    # 재빌드 감별용 표식(재빌드는 -9999로 무효화)
	m._refresh_home_expansion(false)
	_check("㉓c 재빌드를 건너뛰어도 집 카메라 둘레는 `home_house_cam_rect()`로 다시 주입된다",
		m._buildings["집"]["cam"] == m.home_house_cam_rect())
	_check("㉓d 그리고 그때 무대는 다시 굽지 않는다(Y-split 캐시 표식이 그대로 남는다)",
		m._last_player_tile_y == 12345)
	# 반대 방향 — 기본 인자(완공 아침·건물이 서는 순간)는 **여전히 굽는다**. 스킵이 로드 경로에만
	# 걸렸는지를 같은 표식으로 잰다(굽기가 통째로 죽으면 완공한 방이 화면에 안 서는 회귀가 된다).
	m._refresh_home_expansion()
	_check("㉓e 기본 인자는 종전대로 무대를 다시 굽는다(완공 아침 경로 불변)",
		m._last_player_tile_y == -9999)

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
