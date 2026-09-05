extends SceneTree
# ★[폴리시 10회차] 버그 헌트 확정분 회귀 — 배치 A(#1~#10) + 배치 B(#11~#20).
#
# 렌즈: R9 diff 리뷰 · 전투 사슬 · 미니게임 세션 경계 · 대화 상태기계 · XP/전문직 축(A)
#       그리기↔원장 정합 · 구역 전환 알림 · 도구/혼력 축(B).
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
#   ⑪ #11 채취기 원장 훅이 main만 갱신해, Y-split 앞 패스(`_front_props`)에 이미 거둔 "수거 대기"
#         방울과 회수한 채취기가 **유령**으로 남았다(제자리에 서 있는 한 갱신 트리거 0).
#   ⑫ #12 승마 스프라이트는 플레이어 **픽셀** 좌표에서 파생되는데 main 캔버스는 타일 눈금으로만
#         갱신돼, 48px 말이 32px씩 순간이동하며 사람과 분리됐다.
#   ⑬ #13 Mount는 시그널이 없는 원장(bool 하나)인데 `_toggle_mount`가 재드로우를 안 걸어, 제자리
#         휘파람에서 속도만 ×1.5가 되고 말은 첫 타일을 건널 때까지 화면에 없었다.
#   ⑭ #14 Pet도 같은 결 — 물그릇을 채워도 "채웠다" 알림과 "빈 그릇" 그림이 동시에 남았다.
#   ⑮ #15 혼 감지 가장자리 마커가 **스테일 카메라 rect**로 클램프돼(여백 14px < 스테일 32px),
#         이동 중에 뷰포트 밖으로 떨어졌다 — "안 보이는 것을 가리킨다"는 유일한 목적이 무너진다.
#   ⑯ #16 잠긴 나락 진입로 안내가 래치 없이 매 프레임 push돼, 알림 피드(4칸·중복 제거 없음)가
#         포화되며 직전 수확·XP·정산 알림을 네 프레임 만에 밀어냈다.
#   ⑰ #17 휴지통이 기본 도구 5종을 영구 폐기 — 지급처가 새 게임 1회뿐이라 밭갈이·채굴·벌목 사슬이
#         그 세이브에서 통째로 막혔다(소프트락). 책·레어크로우만 있던 금지 표에 도구를 세운다.
#   ⑱ #18 곡괭이 4티어(25,000냥 + 나락철 주괴 5)의 실효 이득이 정확히 0이었다 — 광석 1==1 ·
#         보석 2==2 · 바위 게이트는 티어 2에서 이미 열림. 폴리시 2회차의 HOE_AOE 교정 동형.
#   ⑲ #19 짐승 프롬프트가 혼력을 안 봐, 저혼력에서 급여·수집·쓰다듬이 **무알림 무동작**이었다
#         (형제 창구 다섯이 전부 세워 둔 안내가 목축에만 없었다).
#   ⑳ #20 혼력 0에서도 캐스팅이 성립해 미끼만 태우고 100% 실패했다 — 후킹 비용 하한이 1이라
#         어떤 어종이 걸려도 게이트가 반드시 실패하는 확정 손실이었다.

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
		# ★[폴리시 R17 #8] 호출이 실패를 말하는 창구(`_save_or_warn`) 경유로 갈렸다 — 위상 계약 불변.
		_line_of("func _on_sleep_done") > 0 and _in_func("func _on_sleep_done", "_save_or_warn()"))
	# ★[폴리시 R24 #18] 표가 **스칼라 1칸 → 누적 배열**이 됐다(연속 강제 취침이 앞 밤을 덮던 자리).
	#   이 무대가 재는 계약("표가 원장과 같은 파일에 실리고 되살아난다")은 그대로고, 담는 그릇만
	#   갈렸다 — 그래서 값도 한 밤에서 두 밤으로 늘려 «전부» 왕복하는지까지 함께 잰다.
	m._weed_pending_days = [12, 13]
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	_check("①b `_save_game`이 표를 실제로 적는다(키 weed_pending_days = [12, 13])",
		raw.has("weed_pending_days") and str(raw["weed_pending_days"]) == str([12, 13]))
	m._weed_pending_days = []
	var ok_load: bool = m._load_game()
	_check("①c 로드가 그 표를 **전부** 되살린다(종전엔 무조건 0으로 버려 그 밤이 영영 안 굴렀다) — %s"
			% str(m._weed_pending_days),
		ok_load and str(m._weed_pending_days) == str([12, 13]))
	_check("①d 하위호환 — 키 없는 구세이브는 빈 표이고, **구 키(스칼라)는 한 칸짜리 표로 읽힌다**",
		m._pending_nights_from({}, "weed_pending_days", "weed_pending_day").is_empty()
		and str(m._pending_nights_from({"weed_pending_day": 12}, "weed_pending_days",
			"weed_pending_day")) == str([12]))
	# 되살아난 표는 **집에서 실제로 소비된다** — 라운드트립만으로는 반쪽이라 소비까지 본다.
	m._region = RegionCatalog.HOME
	m._sleeping = false
	m._transitioning = false
	await process_frame
	_check("①e 집에 있는 프레임이 그 표를 **비운다**(확산·재점령이 밀린 두 밤 값으로 굴렀다) — 잔여 %s"
			% str(m._weed_pending_days), m._weed_pending_days.is_empty())
	# ★[폴리시 R11 정정] 여기 있던 "형제 표 둘은 로드가 버린다"는 **R10의 잘못된 논증을 잠근**
	#   단언이었다(R11 #1·#4·#6·#8이 반증 — 그 둘도 세이브 시점엔 *집행 전*이라 버리면 손실이다).
	#   같은 자리에서 이제 셋이 **모두** 왕복하는 것을 잠근다(계약이 하나로 합쳐졌다).
	_check("①f 형제 표 둘도 R11에서 같은 계약으로 합류했다(셋 다 파일에서 되살아난다)",
		_line_of("data.get(\"season_respawn_pending_day\", 0)") > 0
		and _line_of("data.get(\"pasture_release_pending\", false)") > 0)

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
	# ★[폴리시 R19 #10·#11] 세 항이 **이름 있는 술어**(`session_lmb`)로 접혔다 — 형제인 설치 갈래
	#   넷이 같은 규칙을 읽어야 해서다(그 술어 머리말). 계약은 그대로: 셋을 모두 본다.
	var sess := _line_of("var session_lmb := cheki != null or cocktail != null or fishing != null")
	var gate := _line_of("if not _sleeping and not session_lmb \\")
	_check("⑤a `_use_tool` 디스패치 게이트가 세션 셋을 **모두** 본다(체키·칵테일·낚시 — 술어 %d행·게이트 %d행)"
			% [sess + 1, gate + 1], sess > 0 and gate > sess)
	_check("⑤b 그 게이트는 여전히 자유 사용 물건·무기를 or-항으로 들고 있다(거동 축소 0)",
		# ★[폴리시 R17 경유 발견] R16 #5가 이 or-항을 `pot_at_target` → `pot_dispatch`로 갈면서
		#   니들이 상해 있었다(계약 자체는 그대로 — 항 넷이 전부 산다). 이름만 따라 옮긴다.
		# ★[폴리시 R19 경유 발견] R18 #1이 다섯째 항(과수)을 더하며 그 줄이 **두 줄로 접혔고**,
		#   닫는 괄호가 다음 줄로 넘어가 이 니들이 R18 시점부터 이미 red였다(HEAD의 main.gd에
		#   이 문자열이 한 번도 없다 — R18의 선별 회귀가 이 스위트를 안 태운 자리다). 계약은
		#   여전히 "항 넷이 전부 산다"이므로 **닫는 괄호를 뺀 접두**로 고친다.
		_line_of("and (_target_valid or holding_weapon or pot_dispatch or holding_free_use") > 0)
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
	# ★[폴리시 R23] 점수판 니들을 **창구 이름**으로 바꾼다 — 그 누적은 이후 `_count_run_harvest()`
	#   한 함수로 모였고(R8·R11이 옥자 트랙 갱신을 함께 태우려고 추출했다), 그 뒤로 이 항은
	#   `_run_harvested += 1`을 찾다 상시 red였다(선재 결함 — R23 배치 B 회귀에서 기준선 측정으로
	#   드러났다). 재는 계약은 그대로다: 야생 수확은 점수판에 들되 미호 크레딧은 안 받는다.
	_check("⑩ 야생 수확은 채집 XP만 받고 미호 활동 크레딧은 안 받는데 `_run_harvested`엔 든다",
		_line_of("func _harvest_wild") > 0 and _in_harvest_wild("_count_run_harvest()")
		and not _in_harvest_wild("_activity_credit(\"miho\""))
	_check("⑩′ 그 원장을 읽는 곳이 셋이다 — 미호 deed 문턱·카페 3단·마무리 요약(어느 쪽을 고쳐도 셋이 함께 움직인다)",
		Deed.MIHO_HARVEST.size() == 4 and int(Deed.MIHO_HARVEST[3]) == 300
		and _line_of("CafeMilestone.is_complete(_run_harvested") > 0
		and _line_of("RunSummary.epilogue_text(clock.day, wallet.gold, _run_harvested") > 0)

	# ══ 배치 B(#11~#20) — 그리기↔원장 정합 5건 + 알림 포화 + 도구 소프트락 + 죽은 티어 + 혼력 안내 2건 ══
	print("══ 배치 B — 두 캔버스 · 매 프레임 파생 그림 · 소프트락 · 죽은 티어 · 혼력 게이트 ══")
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)
	m._indoor = ""
	m._sleeping = false
	m._transitioning = false

	# ── ⑪ #11 숲 채취기 앞 패스 — 원장 변화가 두 캔버스에 함께 닿는다 ────────────
	print("── ⑪ #11 채취기 원장 — main만이 아니라 _front_props도 무효화된다 ──")
	_check("⑪a 전제: 채취기는 Y-split을 타서 플레이어 앞이면 `_front_props`가 그린다(앞 패스가 실재)",
		_line_of("func _draw_tappers_front") > 0
		and _in_func("func _draw_front_props", "_draw_tappers_front(canvas)"))
	var tap_conn: Array = m.tapper.changed.get_connections()
	var tap_methods: Array = []
	for c in tap_conn:
		tap_methods.append((c["callable"] as Callable).get_method())
	_check("⑪b 원장 훅이 `_redraw_world`로 간다(종전 `queue_redraw` 직결 = main 한 쪽만 갱신)",
		tap_methods.has("_redraw_world") and not tap_methods.has("queue_redraw"))
	_check("⑪c 그 함수는 두 캔버스를 **둘 다** 무효화한다(main.queue_redraw + _front_props.queue_redraw)",
		_in_func("func _redraw_world", "queue_redraw()")
		and _in_func("func _redraw_world", "_front_props.queue_redraw()"))
	_check("⑪d 훅이 걸린 원장 사건은 넷이다 — 설치·수거·회수·일일 진행(어느 쪽으로 바뀌어도 앞 패스가 산다)",
		_src_has("res://tapper_ledger.gd", "func place") and _src_has("res://tapper_ledger.gd", "func collect")
		and _src_has("res://tapper_ledger.gd", "func remove")
		and _src_has("res://tapper_ledger.gd", "func advance_day"))

	# ── ⑫⑬ #12·#13 승마 — 매 프레임 파생 그림과 시그널 없는 원장 ────────────────
	print("── ⑫⑬ #12·#13 먹갈기 — 32px 순간이동 · 제자리 승차의 빈 화면 ──")
	_check("⑫pre 전제 ①: `_draw_mount`는 타일이 아니라 **플레이어 픽셀 좌표**에 시트를 얹는다",
		_in_func("func _draw_mount", "var p := player.global_position"))
	_check("⑫pre′ 전제 ②: Mount·Pet은 시그널이 0개다 — 그래서 갱신 책임이 전부 호출부에 있다",
		not _src_has("res://mount.gd", "signal ") and not _src_has("res://pet.gd", "signal "))
	m.mount.dismount()
	m._foraging_xp = 0
	m._live_canvas_src = Vector2.INF
	_check("⑬a 안 탔고 퍼크도 없으면 소스가 INF다 — 매 프레임 재드로우 요청 0(종전 비용 불변)",
		m._live_canvas_source() == Vector2.INF)
	var mounted_ok: bool = m.mount.mount_up(m._indoor, m._region, false, 0)
	_check("⑬b 제자리 승차가 소스를 INF → 플레이어 좌표로 갈라, 그 프레임에 재드로우가 선다",
		mounted_ok and m.mount.is_mounted()
		and m._live_canvas_source() == m.player.global_position)
	m._tick_live_canvas()
	_check("⑬c 틱이 그 좌표를 삼킨다(같은 자리에 서 있는 다음 프레임엔 요청이 다시 0)",
		m._live_canvas_src == m.player.global_position
		and m._live_canvas_source() == m._live_canvas_src)
	m.player.global_position += Vector2(7.0, 0.0)   # 타일 경계 **안쪽**의 7px — 종전엔 아무 트리거도 없던 폭
	_check("⑫a 타일을 안 넘는 7px 이동에도 소스가 갈린다(종전엔 32px마다 한 번 = 말이 뚝뚝 끊겼다)",
		m._live_canvas_source() != m._live_canvas_src
		and m._live_canvas_source() == m.player.global_position)
	_check("⑫b 그 폭이 실제로 문제인 크기다 — 말 시트 48px에 최대 지연 %dpx(자기 폭의 2/3)"
			% m.TILE,
		m.MOUNT_SHEET_FRAME == 48 and m.TILE == 32)
	_check("⑬d 승·하차 두 갈래와 강제 하차가 전부 상태 변이 자리에서 재드로우를 건다",
		_in_func("func _toggle_mount", "queue_redraw()")
		and _in_func("func _sync_mount", "queue_redraw()"))
	m.mount.dismount()
	m._tick_live_canvas()
	_check("⑬e 하차하면 소스가 INF로 돌아간다(말 그림을 지울 그 한 프레임이 보장된다)",
		m._live_canvas_src == Vector2.INF)

	# ── ⑭ #14 물그릇 — 채운 물이 그 프레임에 화면에 찬다 ────────────────────────
	print("── ⑭ #14 삽사리 물그릇 — 알림과 그림이 같은 프레임에 맞는다 ──")
	var day_kept: int = m.clock.day
	m.clock.day = maxi(m.clock.day, Pet.ADOPT_MIN_DAY)   # 입양 문턱 이후여야 삽사리가 세상에 선다
	var adopted: bool = m.pet.adopt(m.clock.day)
	_check("⑭pre′ 무대: 삽사리가 입양된 상태다(그 전엔 물그릇도 안 그린다 — 없는 존재의 자리)",
		adopted and m.pet.is_adopted())
	_check("⑭pre 물 띠는 원장 파생이다 — `_draw_sapsari`가 `pet.can_fill_bowl`을 매 드로우 질의한다",
		_in_func("func _draw_sapsari", "not pet.can_fill_bowl(clock.day)"))
	_check("⑭a 아트 훅 뒤에도 그 띠가 산다 — 함수의 return은 입양 가드 하나뿐(early return 잔류 0)",
		_returns_in_func("func _draw_sapsari") == 1)
	var could_fill: bool = m.pet.can_fill_bowl(m.clock.day)
	m._fill_pet_bowl()
	_check("⑭b 채우면 원장이 실제로 오늘 몫으로 넘어간다(그림의 소스가 바뀌었다)",
		could_fill and not m.pet.can_fill_bowl(m.clock.day))
	_check("⑭c 그 자리에서 재드로우를 건다(제자리 [F]엔 다른 트리거가 0이라 여기가 유일한 갱신 경로)",
		_in_func("func _fill_pet_bowl", "queue_redraw()"))
	m.clock.day = day_kept

	# ── ⑮ #15 혼 감지 마커 — 카메라가 흐른 만큼 마커가 밀려나지 않는다 ──────────
	print("── ⑮ #15 가장자리 마커 — 스테일 카메라 rect로 화면 밖에 나가지 않는다 ──")
	_check("⑮pre 산술 근거: 들인 여백 %dpx < 한 타일 %dpx — 타일 눈금 갱신만으로는 마커가 화면 밖으로 나간다"
			% [int(m._FDET_MARGIN), m.TILE],
		m._FDET_MARGIN < float(m.TILE))
	_check("⑮pre′ 그 rect는 매 프레임 값이다 — `_forage_view_rect`가 카메라 중심에서 만든다",
		_in_func("func _forage_view_rect", "_cam.get_screen_center_position()"))
	m._foraging_xp = 0
	_check("⑮a 퍼크가 없으면 소스가 INF다(감지 반경 0 · 추적 없음 = 그릴 것이 없다 → 요청 0)",
		m.forage_detect_radius() == 0 and not m.forage_track_enabled()
		and m._live_canvas_source() == Vector2.INF)
	m._foraging_xp = 1000000                      # 혼 감지(base lvl3+) 개통
	_check("⑮b 감지가 켜지면 소스가 **카메라 중심**으로 갈린다(마커의 진짜 소스와 같은 값)",
		m.forage_detect_radius() != 0
		and m._live_canvas_source() == m._cam.get_screen_center_position())
	# 카메라는 플레이어의 자식이고 경계 클램프를 먹으므로, 맵 한복판(클램프 밖)에서 흘려 본다.
	m.player.global_position = Vector2(RegionCatalog.size_of(RegionCatalog.HOME)) * float(m.TILE) * 0.5
	await process_frame            # 카메라 스크롤 반영(get_screen_center_position은 프레임 단위로 갱신된다)
	m._tick_live_canvas()
	var cam_before: Vector2 = m._live_canvas_src
	m.player.global_position += Vector2(9.0, 0.0)   # 타일 경계 **안쪽**에서 카메라가 흐른 폭
	await process_frame            # 그 프레임의 `_process`가 틱을 돌린다(라이브 경로 그대로)
	_check("⑮c 카메라가 9px만 흘러도 그 프레임의 틱이 새 rect를 잡는다(종전엔 32px 스테일 = 마커 실종)",
		cam_before != m._cam.get_screen_center_position()
		and m._live_canvas_src == m._cam.get_screen_center_position()
		and m._live_canvas_src != cam_before)
	await process_frame
	_check("⑮d 카메라가 멈춘 프레임엔 요청이 다시 0이다(정지 중 상시 재드로우가 아니다)",
		m._live_canvas_source() == m._live_canvas_src)
	m._foraging_xp = 0

	# ── ⑰ #17 휴지통 — 재획득 경로 0인 도구는 안 버려진다 ──────────────────────
	print("── ⑰ #17 휴지통 소프트락 — 기본 도구 5종은 폐기 불가 ──")
	var tools_kept := true
	var tool_names: Array = []
	for tid: String in Inventory.START_TOOLS:
		if m.inventory.count_of(tid) <= 0:
			m.inventory.add_item(tid, 1)
		m._on_frame_discard(_slot_of(m, tid))
		tool_names.append(ItemCatalog.name_of(tid))
		if m.inventory.count_of(tid) <= 0:
			tools_kept = false
	_check("⑰a 다섯 도구가 전부 휴지통을 통과 못 한다 — %s" % [", ".join(tool_names)], tools_kept)
	_check("⑰a′ 그 다섯이 곧 새 게임 지급 목록이다(판정이 유일한 지급처 파생 — id 복제 0)",
		Inventory.START_TOOLS.size() == 5
		and Inventory.START_TOOLS.has(ItemCatalog.HOE) and Inventory.START_TOOLS.has(ItemCatalog.WATERING_CAN)
		and Inventory.START_TOOLS.has(ItemCatalog.SCYTHE) and Inventory.START_TOOLS.has(ItemCatalog.PICKAXE)
		and Inventory.START_TOOLS.has(ItemCatalog.AXE))
	_check("⑰b 소프트락의 실체 — 도구는 CAT_TOOL(유니크·비매)이라 어느 매대에도 재구매 행이 없다",
		ItemCatalog.category_of(ItemCatalog.HOE) == ItemCatalog.CAT_TOOL
		and ItemCatalog.price_of(ItemCatalog.HOE) == 0)
	m.inventory.add_item(ItemCatalog.STONE, 3)
	m._on_frame_discard(_slot_of(m, ItemCatalog.STONE))
	_check("⑰c 그 외 물건은 종전대로 버려진다 — 돌 3개 폐기 성공(휴지통이 죽지 않았다)",
		m.inventory.count_of(ItemCatalog.STONE) == 0)
	_check("⑰d 낚싯대는 같은 CAT_TOOL이지만 안 막는다(상점 재구매가 있다 — 16칸 백팩 압박 회피)",
		ItemCatalog.category_of(GearCatalog.ROD_T2) == ItemCatalog.CAT_TOOL
		and not Inventory.START_TOOLS.has(GearCatalog.ROD_T2))
	_check("⑰e 형제 창구는 이미 도구를 거절하고 있었다(선물 `giftable`) — 휴지통만 그 표에서 빠졌다",
		not GiftPrefs.giftable(ItemCatalog.HOE) and GiftPrefs.giftable(ItemCatalog.STONE))

	# ── ⑱ #18 곡괭이 최고 티어 — 25,000냥이 무언가를 바꾼다 ─────────────────────
	print("── ⑱ #18 나락철 곡괭이 — 실효 이득 0의 봉합 ──")
	_check("⑱a 보석/지오드가 최고 티어에서 즉발이 된다 — 3티어 2타 → 4티어 1타(종전 2==2)",
		ToolTier.pickaxe_gem_hits(3) == 2 and ToolTier.pickaxe_gem_hits(4) == 1)
	_check("⑱b 광석 축은 구조적으로 못 바꾼다 — 3티어에서 이미 바닥(1타)이라 깎을 자리가 없다",
		ToolTier.pickaxe_ore_hits(3) == 1 and ToolTier.pickaxe_ore_hits(4) == 1)
	var pick_mono := true
	for tier in ToolTier.MAX_TIER:
		if ToolTier.pickaxe_ore_hits(tier + 1) > ToolTier.pickaxe_ore_hits(tier) \
				or ToolTier.pickaxe_gem_hits(tier + 1) > ToolTier.pickaxe_gem_hits(tier):
			pick_mono = false
	_check("⑱c 두 사다리가 전 구간 단조 비증가다(어느 티어도 손해가 아니다)", pick_mono)
	_check("⑱d 그리고 **모든** 티어가 바로 아래보다 최소 한 축에서 낫다(죽은 계단 0 — HOE_AOE 교정 동형)",
		_tier_strictly_better(1) and _tier_strictly_better(2)
		and _tier_strictly_better(3) and _tier_strictly_better(4))
	_check("⑱e 그 티어가 게임 최고가라는 사실은 그대로다(4티어 값 > 3티어 값 — 이득 0이면 함정이었다)",
		int(ToolTier.TIER_PRICES[4]) > int(ToolTier.TIER_PRICES[3])
		and int(ToolTier.TIER_PRICES[4]) == 25000)
	_check("⑱f 큰 바위 게이트는 4티어의 근거가 못 된다 — 티어 2에서 이미 열렸고 main에 호출부도 없다",
		ToolTier.TIER_LARGE_BOULDER == 2 and ToolTier.pickaxe_breaks_boulder(2)
		and _line_of("pickaxe_breaks_boulder") < 0)
	_check("⑱g 라이브 접점 둘이 함께 움직인다(갱도·나락 두 층 원장이 같은 표를 읽는다)",
		MineFloors.node_hits(MineFloors.N_GEM_MYEONGOK, 4) == 1
		and NarakFloors.node_hits(MineFloors.N_GEM_MYEONGOK, 4) == 1
		and MineFloors.node_hits(MineFloors.N_GEM_MYEONGOK, 3) == 2)

	# ── ⑲ #19 짐승 프롬프트 — 저혼력에서 화면과 동작이 갈리지 않는다 ────────────
	print("── ⑲ #19 목축 창구 — 침묵으로 실패하던 두 동사에 안내가 선다 ──")
	# 시험용 성체 한 마리를 빈 칸에 세운다(기존 목장 상태에 안 얹는다 — 무대가 결정적이어야 한다).
	var cow_tile := Vector2i(90, 90)
	var cow_added: bool = m.ranch.add_animal(cow_tile, AnimalCatalog.HONBAEK_SO, "", 99)
	m._region = RegionCatalog.HOME
	m._target = cow_tile
	m.energy.refill()
	var prompt_full: String = m._animal_prompt(cow_tile)
	m.energy.spend(m.energy.current - 1)           # 혼력 1 — 농사 비용(10) 미만
	var prompt_low: String = m._animal_prompt(cow_tile)
	_check("⑲pre 무대: 성체 한 마리를 겨눈 프롬프트가 동사를 실제로 권한다 — %s" % prompt_full,
		cow_added and m.ranch.animal_key_at(cow_tile) == cow_tile
		and prompt_full.contains("[우클릭]") and not prompt_full.contains("혼력 부족"))
	_check("⑲a 혼력이 비용 미만이면 안내가 '혼력 부족'으로 갈린다 — 화면이 못 하는 일을 권하지 않는다",
		m.energy.current < m._farming_energy_cost() and prompt_low.contains("혼력 부족")
		and not prompt_low.contains("[우클릭]"))
	_check("⑲b 집행부는 종전 그대로 조용히 돌아간다(막은 게 아니라 *예고*를 세웠다 — 거동 불변)",
		not m._try_harvest() and m.energy.current == 1)
	m.energy.refill()
	_check("⑲c 혼력이 차면 동사 안내가 되돌아온다(게이트가 아니라 안내다 — ADR-0008 평평≠막힘)",
		not m._animal_prompt(cow_tile).contains("혼력 부족")
		and m._animal_prompt(cow_tile) == prompt_full)
	_check("⑲d 형제 창구의 문구와 같은 축이다(나무·밭·화분·개간이 이미 세워 둔 그 안내)",
		_line_of("return \"혼력 부족 — 집에서 취침\"") > 0)

	# ── ⑳ #20 혼력 0 캐스팅 — 미끼만 태우는 확정 실패를 걷어낸다 ────────────────
	print("── ⑳ #20 낚시 — 확정 실패 캐스팅 앞의 선검사 ──")
	# T2 이상이어야 미끼 슬롯이 있다(T1 bait_slots = 0 → 태울 미끼 자체가 없어 무대가 안 선다).
	var rod: String = GearCatalog.ROD_T2
	var bait: String = GearCatalog.BAIT_BASIC
	m.fishing = null
	if m.inventory.count_of(rod) <= 0:
		m.inventory.add_item(rod, 1)
	m.inventory.add_item(bait, 5)
	m.inventory.selected_index = _slot_of(m, rod)
	var bait_before: int = m.inventory.count_of(bait)
	m.energy.spend(m.energy.current)               # 혼력 0
	m._start_fishing(Vector2i(5, 5))
	_check("⑳pre 하한이 실재한다 — 후킹 비용은 어떤 절감에도 %d 아래로 안 내려간다"
			% FishingSession.MIN_HOOK_ENERGY,
		FishingSession.MIN_HOOK_ENERGY >= 1 and m.energy.current == 0)
	_check("⑳a 혼력 0에서는 캐스팅이 서지 않는다 — 세션 없음 + 미끼 %d개 그대로(종전엔 1개씩 탔다)"
			% bait_before,
		m.fishing == null and m.inventory.count_of(bait) == bait_before)
	# ★[폴리시 R11 정정] 술어가 클램프 하한(MIN_HOOK_ENERGY = 1)에서 **도달 가능한 최저 비용**으로
	#   바뀌었다(#2 — 옛 값은 어떤 어종·어떤 숙련에서도 나올 수 없어 혼력 1~3의 확정 실패가 남았다).
	#   여기서 잠그는 계약은 그대로다: 화면과 집행부가 *같은* 술어를 읽는다.
	# ★[폴리시 R23] 술어 니들을 **지금의 단일 창구**로 바꾼다 — R21 #2가 그 판정을
	#   `_cast_energy_need` 한 함수로 모으면서(보장 미끼는 체급이 확정돼 하한이 아니라 그 비용이
	#   기준이다) 옛 이름이 소스에서 사라졌고, 그 뒤로 이 항의 뒷절이 0을 물고 상시 red였다
	#   (선재 결함 — R23 배치 B 회귀에서 기준선 측정으로 드러났다). 재는 계약은 그대로다:
	#   **화면과 집행부가 같은 술어를 읽는다**(그래서 집행부 쪽도 함께 문다).
	_check("⑳b 프롬프트도 같은 술어를 읽어 화면이 먼저 말한다(집행부와 안내가 안 갈린다)",
		_line_of("interact_prompt.text = \"혼력 부족 — 챌 힘이 없다 (집에서 취침)\"") > 0
		and _in_func("func _process", "_cast_energy_need(inventory.selected_id(), _fishing_mods())")
		and _in_func("func _start_fishing", "_cast_energy_need("))
	m.energy.restore(SoulEnergy.MAX)
	m._start_fishing(Vector2i(5, 5))
	_check("⑳c 혼력이 있으면 종전 그대로 던진다 — 세션이 서고 미끼 1개가 나간다(거동 축소 0)",
		m.fishing != null and m.inventory.count_of(bait) == bait_before - 1)
	m.fishing = null
	_check("⑳d 이건 게이트가 아니다 — 캐스팅·대기는 여전히 무과금이고 소모는 후킹 순간뿐이다",
		not _in_func("func _can_cast", "energy")
		and _in_func("func _fishing_hook_gate", "energy.spend(cost)"))
	_check("⑳e 형제 동사 둘은 이미 소모 전에 막고 알렸다(곡괭이·팬닝) — 낚시만 그 표에서 빠졌다",
		_in_func("func _mine_rock", "energy.can_act") and _in_func("func _pan_spot", "energy.can_act"))

	# ── ⑯ #16 나락 진입로 — 잠금 안내가 피드를 포화시키지 않는다 ────────────────
	# (구역을 갈아야 해서 배치 B의 맨 끝에 둔다 — 앞 단언들의 무대는 안식 농원이다.)
	print("── ⑯ #16 잠긴 나락 문 — 매 프레임 push가 1회 안내로 접힌다 ──")
	var gate_at := Vector2i(-1, -1)
	for w2 in RegionCatalog.warps_of(RegionCatalog.EOPHWA_MINE):
		if w2["to"] == RegionCatalog.NARAK:
			gate_at = w2["at"]
	m._region = RegionCatalog.EOPHWA_MINE
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	m._narak_key_found = false
	m._gate_notice_tile = Vector2i(-9999, -9999)
	m.player.global_position = Vector2(gate_at.x * m.TILE + 16, gate_at.y * m.TILE + 16)
	m.notice_feed._items.clear()
	for i in 30:
		m._maybe_warp_edge()
	_check("⑯pre 무대: 그 문 칸은 워프 표에서 파생했고(%s) 플레이어가 실제로 그 칸에 섰다" % [gate_at],
		gate_at != Vector2i(-1, -1) and m._player_tile() == gate_at)
	_check("⑯a 30프레임을 서 있어도 안내는 **한 줄**이다(종전엔 60회/초 push로 피드 4칸이 포화)",
		m.notice_feed._items.size() == 1
		and String(m.notice_feed._items[0]["text"]).contains("나락 열쇠"))
	m.notice_feed.push("직전 수확 토스트", 5.0)
	for i in 30:
		m._maybe_warp_edge()
	_check("⑯b 그래서 직전 알림이 안 밀려난다 — 같은 칸에서 30프레임 더 서 있어도 그 줄이 살아 있다",
		m.notice_feed._items.size() == 2
		and String(m.notice_feed._items[1]["text"]) == "직전 수확 토스트")
	m.player.global_position += Vector2(m.TILE * 2, 0.0)   # 두 칸 옆으로 — 래치 재무장
	m._maybe_warp_edge()
	m.player.global_position = Vector2(gate_at.x * m.TILE + 16, gate_at.y * m.TILE + 16)
	m._maybe_warp_edge()
	_check("⑯c 칸을 벗어났다 돌아오면 다시 알린다(억제가 소실로 넘어가지 않는다 — 유일한 피드백이라)",
		m.notice_feed._items.size() == 3
		and String(m.notice_feed._items[2]["text"]).contains("나락 열쇠"))
	m._narak_key_found = true
	_check("⑯d 열쇠 게이트 자체는 불변이다 — 플래그가 서면 그 분기를 아예 안 지난다(워프 성립)",
		m._narak_key_found and _line_of("if w[\"to\"] == RegionCatalog.NARAK and not _narak_key_found:") > 0)
	m._narak_key_found = false

	for s2 in SaveManager.SLOT_COUNT:
		_wipe_slot(s2)
	print("── 결과: %s (실패 %d)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# `_pan_spot` 본문 안에 그 문자열이 있나(함수 밖 동명 호출에 안 속게 — polish_r9 `_line_in_func` 결).
func _in_pan_spot(needle: String) -> bool:
	return _in_func("func _pan_spot", needle)

func _in_harvest_wild(needle: String) -> bool:
	return _in_func("func _harvest_wild", needle)

# main.gd 밖의 파일 한 줄 스캔(원장·자매 파일의 사실 확인용 — needle이 든 줄이 있나).
func _src_has(res_path: String, needle: String) -> bool:
	var f := FileAccess.open(res_path, FileAccess.READ)
	if f == null:
		return false
	return f.get_as_text().contains(needle)

# 그 함수 본문의 `return` 줄 수(early return 잔류 감별 — 아트 훅 뒤 상태 드로우가 살아 있나).
func _returns_in_func(fn_needle: String) -> int:
	var head := _line_of(fn_needle)
	if head < 0:
		return -1
	var n := 0
	for i in range(head + 1, _src.size()):
		if _src[i].begins_with("func "):
			break
		if _src[i].strip_edges().begins_with("return"):
			n += 1
	return n

# 그 슬롯 인덱스(id가 든 첫 칸 — 인벤에 find_item이 없어 테스트가 파생한다).
func _slot_of(m: Node, id: String) -> int:
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == id:
			return i
	return -1

# 곡괭이 티어 사다리 — 이 티어가 바로 아래보다 **최소 한 축**에서 엄격히 낫나(죽은 계단 감별).
func _tier_strictly_better(tier: int) -> bool:
	return ToolTier.pickaxe_ore_hits(tier) < ToolTier.pickaxe_ore_hits(tier - 1) \
		or ToolTier.pickaxe_gem_hits(tier) < ToolTier.pickaxe_gem_hits(tier - 1)

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
