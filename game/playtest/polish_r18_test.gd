extends SceneTree
# ★[폴리시 18회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#9) + 배치 B(#10~#18).
#
# 렌즈: R17 diff 리뷰(#0) · 도달 계약(#1·#2·#11) · 프롬프트↔실행 불일치(#3) ·
#       표시 진실성(#4·#5·#8) · 시간 게이트(#6·#7) · 스케줄↔지도 정합(#9·#10) ·
#       배치 가드 시간 축(#12) · 죽은 갈래(#13) · 로드 리셋 누수(#14·#15) ·
#       그리기 순서(#16·#18) · 그림↔원장 어긋남(#17).
#
# 이 회차의 태도 셋.
#   ㉠ **"어느 칸을 겨눠야 하는가"는 눈에 보이는 것이 정한다.** #1·#2가 같은 병이다 — 원장 좌표와
#      보이는 그림이 어긋난 자리에서 프롬프트만 뜨고 버튼이 안 먹었다. 그래서 아래 단언은 전부
#      "프롬프트가 서는 칸 = 실행이 성립하는 칸"을 한 쌍으로 잰다(한쪽만 재면 반쪽이 다시 샌다).
#   ㉡ **표시 단언은 문구를 옮겨 적지 않는다.** 알림·툴팁 문구는 소스가 아니라 **그 문구를 만드는
#      함수를 실제로 호출해** 받는다(`_ranch_door_open_notice`·`HudTooltip.label_for`). 두 함수는
#      이번 회차에 문구 조립을 한 곳으로 모으며 생긴 이름이고, 화면 경로가 쓰는 바로 그것이다.
#   ㉢ **분모는 레지스트리에서 판다.** 아이콘 케이스 누락(#4)은 "10종 중 9종"이라 세면 카테고리가
#      느는 날 초록인 채로 다시 빠진다 — 카테고리 목록을 item_catalog.gd에서 긁어 분모로 쓴다.
#
# 무엇을 보증하나(번호 = 18회차 헌트 발견 인덱스):
#   ① #0 취침 트윈 중 시작된 컷신이 `clock.running=false`를 스냅해 컷신 종료 후 하루가 통째로 멎었다.
#   ② #1 혼의 나무 심기·수확이 `_target_valid`(밭 흙) 게이트에 막혀 프롬프트만 뜨고 무동작이었다.
#   ③ #2 안식 마당 나무 — 벌목·이끼는 캐노피 꼭대기, 수액 채취기는 밑동(같은 나무, 3칸 갈린 조준 칸).
#   ④ #3 갱도·나락 층 포괄 프롬프트가 휘파람 [F] 안내를 삼켜, 화면의 [F]와 실제 [F]가 갈렸다.
#   ⑤ #4 CAT_RELIC만 두 슬롯 드로어의 match에 케이스가 없어 손에 든 유품이 빈 칸으로 보였다.
#   ⑥ #5 작물 성장일수가 화면에 도달하는 경로가 0이었다(유일 호출부 = 영구 비가시 라벨).
#   ⑦ #6 바나와 결혼하면 22시 이후 '집'에서 나라카 바를 원격으로 열 수 있었다(방어 불가 약탈).
#   ⑧ #7 체키 제안창·촬영 세션이 카페 마감(19:00)을 넘어 살아남아 정산 뒤에 장부가 더 올랐다.
#   ⑨ #8 방목 문 알림이 밤·잿눈에도 «짐승이 방목지로 나간다»고 말했지만 실제 방출은 0이었다.
#   ⑩ #9 세레나 스케줄 3칸이 전부 강변 레인인데 걷기는 메인 복도로만 라우팅 — 집 WALL 관통 60칸.
#   ⑪ #10 걷기가 '문 x열 = 길'로 가정 — 지도가 옆 열로 우회시킨 집들의 아침 전환이 벽을 뚫었다.
#   ⑫ #11 네오는 ROMANCE_OPEN인데 require_indoor가 안 풀려, 안방 배우자에게 말을 걸 수 없었다.
#   ⑬ #12 배치 가드가 '지금 서 있는 칸'만 봐서, 주민의 **다음** 스테이션 칸에 기계를 세울 수 있었다.
#   ⑭ #13 `_run_over`가 죽은 갈래라 ENDING BGM이 정식 플레이에서 한 번도 안 들렸다.
#   ⑮ #14 seasonal_event 로드가 `data.has` 뒤라, 키 없는 구세이브가 더비 당일치 원장을 물려받았다.
#   ⑯ #15 peddler 로드도 같은 가드 뒤라, 하루 한 점 희귀 슬롯 잠금이 세이브를 건너 이월됐다.
#   ⑰ #16 화면을 덮는 월드 오버레이를 플레이어·앞프롭·월드 라벨이 위에서 덮었다.
#   ⑱ #17 안식 원장 나무의 그루터기·유목·이끼를 앵커 칸에 그려 실제 밑동보다 96px 위에 떴다.
#   ⑲ #18 트렐리스 작물의 앞뒤가 밭 원장 순서(=괭이질 이력)로 정해졌다(같은 상태·다른 그림).
#
# 판정: #0~#18 전부 CONFIRMED(봉합). REFUTED·DUP·OWNER 0건.
#
# ★#13은 **뿌리를 안 건드린다**: `_run_over`를 되살리는 것은 세이브·F8 재시작까지 얽힌 설계
#   결정이라(선언부가 "S9 엔딩 재사용 대기"로 남겨 둔 자산) 폴리시 회차의 몫이 아니다. 고친 것은
#   플레이어가 실제로 잃던 것 하나 — 실존 에셋 `bgm_ending.ogg`가 해방 회고 화면에서 울리지
#   않던 도달 경로다(`_open_epilogue`가 그 인자를 참으로 만든다). 같은 뿌리의 죽은 갈래 둘
#   (`_process`의 `if _run_over:` F8 · `_on_ending_button`의 else)은 그 결정에 함께 걸려 있어
#   손대지 않았고, ⑭a가 그 뿌리(호출부 0개)가 그대로임을 매 회차 재확인한다.
#
# 봉합 축(근거 전문은 커밋 본문·각 함수 머리말):
#   · #0 = `_begin_cutscene`의 스냅에 `or _sleeping`(형제 둘이 R12/R13에 받은 그 가드의 컷신 판).
#          R17 #10이 재개 주인을 `clock.sleep` → `_on_sleep_done`으로 옮겨 스냅 창이 0.4초에서
#          연출 전 구간(1.1초)으로 벌어진 것이 이 결함의 직접 원인이라, R17 계약은 안 건드린다.
#   · #1 = `_orchard_dispatch_at` or-항(S10-T5 화분이 두 게이트에 받은 그 처방의 과수 판).
#   · #2 = `_home_tree_ledger_tile` 다리(R14/R15가 채취기 두 축에 놓은 그 다리의 벌목·이끼 판).
#          **더하기만 한다** — 앵커 칸 조준은 한 프레임도 안 바뀐다(회수 가능한 것을 안 뺀다).
#   · #3 = `_mount_prompt()`로 세 갈래를 한 곳에 뽑고 갱도·나락 층 포괄 분기 **앞**에 세운다.
#   · #4 = 두 드로어에 CAT_RELIC 케이스 + 색은 `ItemCatalog.RELICS.color` 단일 출처(진열장도 파생).
#   · #5 = `HudTooltip.label_for`가 씨앗의 성장일수를 붙인다(main 주석이 선언한 인계의 이행).
#   · #6 = `_night_bar_optin_close_min()` — 결혼하면 `SPOUSE_HOME_MIN["bana"]` 파생으로 창이 좁아진다.
#          미혼의 창(19:00~24:00)은 불변이라 새 관계 게이트가 아니다(ADR-0008).
#   · #7 = `_cheki_offered_at`에 영업 창 술어 + `_on_cafe_closed`가 정산 **전에** 창구를 접는다.
#   · #8 = `_ranch_door_open_notice(building, released, to_release)` — 방출 결과와 이유를 갈라 말한다.
#   · #9·#10 = 지도와 걷기가 **한 표를 읽는다**(`_village_door_spokes` — rect·door·lane 삼항).
#          레인 배정도 우회 열도 그 표에서 나오므로 두 곳이 갈릴 자리가 없어진다. A*는 도입 안 함
#          (ADR-0060 "보류" 재론 금지 유지 — 경유점 표를 한 겹 늘렸을 뿐이다).
#   · #11 = `_facing_resident`의 require_indoor에 배우자 안방 예외 + 점주 창구(shop_key·
#          prompt_extra)는 가게 방에 묶는다(ADR-0060 결정 8의 이중 신분이 그 분리다 — 관계
#          레이어만 안방으로 따라오고 매대는 안 따라온다).
#   · #12 = `_resident_tile`에 시간 축(스케줄 전 항목). **새 배치만 막고** 이미 놓인 기계는
#          `_f_machine_at` 양보로 언제나 회수 가능하다(R17 #0/#1이 세운 규율 — 구세이브 매몰 0).
#   · #13 = `_ending_music_on()` = `_run_over or _epilogue_open`(#0의 `or _sleeping`과 같은 형태 —
#          새 상태·새 래치 0. 회고를 닫으면 `update_music`이 스스로 되잇는다).
#   · #14·#15 = `has` 가드를 걷고 `data.get(key, {})`로 무조건 되감는다(R6가 카페에 쓴 처방의
#          형제 전파). 판별식은 R13의 "부팅으로 시드되는가" — 둘 다 플레이가 채우는 원장이다.
#   · #16 = z 셔틀 노드(`world_overlay.gd`, z20) — `front_props.gd`가 이미 세운 그 패턴이다.
#          재그리기는 자기 `_process`로 판다(무효화 배선을 안 늘린다 — 한 자리 누락 = 유령 그림).
#   · #17 = `_tree_ledger_draw_px`가 채취기와 **같은 드롭·같은 앵커 집합**을 쓴다(값 복제 0).
#          덕분에 #2의 조준 다리와 자동으로 짝이 맞는다 — 겨누는 칸이 곧 그려지는 칸이 된다.
#   · #18 = `_crop_draw_order`가 발치 y로 정렬한다(숲 프롭의 `_forest_sort_entries` 1:1).
#
# 하중 검증(계약을 일부러 깨서 red 확인 후 원복 — 전부 실측):
#   #0 `or _sleeping` 삭제 → ①c·①d red ·
#   #1 두 게이트의 `orchard_dispatch` or-항 삭제 → ②e red ·
#   #2 `_home_tree_ledger_tile` 본문을 `return t`로 → ③c·③e·③f red ·
#   #3 갱도·나락 휘파람 갈래 삭제 → ④d red · hotbar CAT_RELIC 케이스 삭제 → ⑤b red ·
#   #4 `tool_color_of`의 유품 갈래 삭제 → ⑤d red · #5 `label_for` 씨앗 갈래 삭제 → ⑥b red ·
#   #6 옵트인 상한 고정 → ⑦c·⑦d red · #7 `cafe.is_open()` 삭제 → ⑧e red ·
#   #7 마감 접기 삭제 → ⑧b red · #8 알림을 옛 한 줄로 → ⑨d·⑨f·⑨g·⑨h red ·
#   #9 `_road_lane_of` 고정 → ⑩c·⑩d·⑩e red(⑩c가 세레나 집 WALL (39,58)~(39,60)을 이름) ·
#   #10 `_house_detour`를 빈 배열 고정으로 → ⑪b·⑪d·⑪e red(⑪e가 켄·스칼렛·미르·루카의 관통 칸을 이름) ·
#   #11 require_indoor 예외 삭제 → ⑫d red · #12 `_resident_tile`의 스케줄 루프 삭제 → ⑬c red ·
#   #13 `_ending_music_on`을 `_run_over` 고정으로 → ⑭c red ·
#   #14·#15 두 `has` 가드 복원 → ⑮c·⑯c·⑯d red ·
#   #16 셔틀 z를 0으로 → ⑰b red · #17 `_tree_ledger_draw_px`의 드롭 삭제 → ⑱b·⑱c red ·
#   #18 `_crop_draw_order`의 정렬 삭제 → ⑲c·⑲d·⑲e red.
#
# ★⑲의 무대에서 배운 것: 밭 원장의 순서를 정하는 것은 **파종이 아니라 괭이질**이다(`hoe`가
#   `_tiles`에 칸을 처음 넣는다). 심는 순서만 뒤집는 옛 무대는 정렬을 지워도 두 목록이 같아
#   ⑲c가 헛돌았다 — 하중 검증이 그 공허를 스스로 잡아냈다.
#
# 실행: ./run_tests.sh polish_r18   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _src: PackedStringArray = PackedStringArray()
var _hot_src: PackedStringArray = PackedStringArray()
var _inv_src: PackedStringArray = PackedStringArray()
var _cat_src: PackedStringArray = PackedStringArray()

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

# ── 소스 스캔 헬퍼(polish_r7~r17의 그 관례) ─────────────────────────────────
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _line_in(lines: PackedStringArray, needle: String) -> int:
	for i in range(lines.size()):
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			return i
	return -1

func _line_in_func(lines: PackedStringArray, fn_needle: String, needle: String) -> int:
	var head := -1
	for i in range(lines.size()):
		if lines[i].begins_with(fn_needle):
			head = i
			break
	if head < 0:
		return -1
	for i in range(head + 1, lines.size()):
		if lines[i].begins_with("func ") or lines[i].begins_with("static func "):
			return -1
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			return i
	return -1

func _count_in(lines: PackedStringArray, needle: String) -> int:
	var n := 0
	for line in lines:
		if String(line).strip_edges().begins_with("#"):
			continue
		if String(line).contains(needle):
			n += 1
	return n

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R18 회귀 — 배치 A(#0~#9) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_hot_src = _lines_of_file("res://hotbar_hud.gd")
	_inv_src = _lines_of_file("res://inv_frame.gd")
	_cat_src = _lines_of_file("res://item_catalog.gd")
	_check("무대 전제: main(%d행)·hotbar_hud(%d)·inv_frame(%d)·item_catalog(%d)를 읽었다(부정 단언 공허 통과 방지)"
			% [_src.size(), _hot_src.size(), _inv_src.size(), _cat_src.size()],
		_src.size() > 1000 and _hot_src.size() > 100 and _inv_src.size() > 500 and _cat_src.size() > 500)

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)

	_check_sleep_cutscene_clock(m)
	_check_orchard_dispatch(m)
	_check_home_tree_bridge(m)
	_check_mount_prompt(m)
	_check_relic_icon(m)
	_check_seed_growth_tooltip(m)
	_check_night_bar_optin_window(m)
	_check_cheki_close_boundary(m)
	_check_ranch_door_notice(m)
	_check_riverside_lane(m)

	# ── 배치 B(#10~#18) ────────────────────────────────────────────────────
	_check_house_door_detour(m)
	_check_spouse_require_indoor(m)
	_check_station_placement_guard(m)
	_check_ending_music(m)
	await _check_daily_ledger_reload(m)
	_check_overlay_z(m)
	_check_tree_ledger_draw(m)
	_check_crop_draw_order(m)

	print("── 결과: %s (실패 %d) ──" % ["통과" if _fail == 0 else "실패", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 취침 트윈 한가운데 선 컷신의 시계 스냅(라이브) ─────────────────────
# 공허 통과 방지: ㉠ 형제 둘이 이미 같은 가드를 갖고 있음을 소스로 확인해(관례가 실재한다)
# ㉡ 스냅 **전에** `clock.running == false`임을 확인한 뒤(그 창이 진짜다) 스냅 값을 잰다.
func _check_sleep_cutscene_clock(m: Node) -> void:
	print("① #0 취침 중 컷신의 시계 스냅")
	var b5 := _line_in(_src, "_spine_b5_clock_prev = clock.running or _sleeping")
	var epi := _line_in(_src, "_epilogue_clock_prev = clock.running or _sleeping")
	_check("①a 무대: 형제 둘이 이미 `or _sleeping` 가드를 쓴다(B5 %d행 · 에필로그 %d행) — 컷신만 빠져 있던 자리다"
			% [b5 + 1, epi + 1], b5 >= 0 and epi >= 0)

	# 취침 연출 한가운데를 재현한다 — `_do_sleep`이 세우는 두 값 그대로.
	var prev_sleeping: bool = m._sleeping
	var prev_running: bool = m.clock.running
	var prev_cut = m.cutscene
	m.cutscene = null
	m._sleeping = true
	m.clock.running = false
	_check("①b 무대: 취침 연출 중이라 `clock.running == false`이고 `_sleeping == true`다(스냅 창이 실재)",
		not m.clock.running and m._sleeping)
	var began: bool = m._begin_cutscene(Spine.B6_CUTSCENE.duplicate(true), "", PackedStringArray())
	_check("①c 취침 중 시작한 컷신의 스냅 = **true**(재생 개시 %s · `_cutscene_clock_prev` %s) — 꺼진 채로 뜨면 `_end_cutscene`이 그 false를 복원해 하루가 통째로 멎는다"
			% [str(began), str(m._cutscene_clock_prev)], began and m._cutscene_clock_prev)

	# 눈뜨는 프레임 이후(=`_on_sleep_done`이 지나간 뒤) 컷신이 끝나면 **시계가 다시 흐른다**.
	# ★재생 중의 정지는 러너 소유다(스텝의 clock_on) — 그래서 여기서 재는 것은 종료 시점의
	#   복원값이다. 스냅이 false로 떴다면 이 줄이 false로 복원해 그 하루가 통째로 멎었다.
	m._sleeping = false
	m.clock.running = true
	m._apply_cutscene_frame()
	var during: bool = m.clock.running          # 재생 중 = `_cutscene_clock_prev and 러너 clock_on`
	m._end_cutscene()
	_check("①d 컷신이 끝나면 시계가 다시 흐른다(재생 중 %s → 종료 후 %s) — 스냅이 곧 복원값이다"
			% [str(during), str(m.clock.running)], m.clock.running)

	m.cutscene = prev_cut
	m._sleeping = prev_sleeping
	m.clock.running = prev_running

# ── ② #1 혼의 나무 심기·수확이 디스패치 게이트를 통과한다(라이브) ───────────
# 공허 통과 방지: 고른 칸이 **`_target_valid`가 거짓인 칸**이어야 한다 — 밭 흙 위에서 재면
# 봉합을 지워도 초록이다(기존 or-항이 이미 통과시킨다).
func _check_orchard_dispatch(m: Node) -> void:
	print("② #1 과수 디스패치 or-항")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	# 과수원 존 안에서 3×3이 통째로 비어 있고 SOIL이 아닌 앵커를 찾는다.
	var zone: Rect2i = m.ORCHARD_ZONE_RECT
	var anchor := Vector2i(-1, -1)
	for y in range(zone.position.y + 1, zone.end.y - 1):
		for x in range(zone.position.x + 1, zone.end.x - 1):
			var t := Vector2i(x, y)
			if m._is_farmable(t):
				continue                     # 밭 흙이면 기존 게이트가 이미 통과시킨다(무대 부적격)
			if m.orchard.can_plant(t, m._is_tree_blocked):
				anchor = t
				break
		if anchor.x >= 0:
			break
	_check("②a 무대: 과수원 존 안에 «밭 흙이 아니고 3×3이 비어 있는» 앵커가 있다 %s" % str(anchor),
		anchor.x >= 0)
	if anchor.x < 0:
		return

	var orchard_snap: Dictionary = m.orchard.to_save()
	var fruit: String = FruitTreeCatalog.ids()[0]
	var sapling: String = ItemCatalog.sapling_id(fruit)
	m._target = anchor
	m._target_valid = m._is_farmable(anchor)
	m.inventory.slots[m.inventory.selected_index] = {"id": sapling, "count": 1, "quality": 0}
	_check("②b 무대: 그 칸은 `_target_valid`가 **거짓**이고(밭 흙 아님) 손에 든 것은 묘목(%s)이다" % sapling,
		not m._target_valid and ItemCatalog.category_of(sapling) == ItemCatalog.CAT_SAPLING)
	_check("②c 심기 축: `_orchard_dispatch_at`이 그 칸을 연다 — 프롬프트도 같은 답이다(「%s」)"
			% m._farm_prompt(), m._orchard_dispatch_at(anchor) and m._farm_prompt().contains("묘목 심기"))

	# 실제로 심고 → 캐노피 칸(앵커가 아닌 풋프린트 칸)에서 수확 축을 잰다.
	var planted: bool = m.orchard.plant(anchor, fruit, m.clock.day, m._is_tree_blocked)
	var canopy := anchor + Vector2i(-1, -1)
	_check("②d 수확 축: 앵커 아닌 풋프린트 칸 %s도 창구가 열린다(심기 %s · `_target_valid` %s · 디스패치 %s)"
			% [str(canopy), str(planted), str(m._is_farmable(canopy)), str(m._orchard_dispatch_at(canopy))],
		planted and not m._is_farmable(canopy) and m._orchard_dispatch_at(canopy))
	# 게이트 두 줄이 실제로 그 or-항을 물고 있는가(입력 사슬의 자리 — 라이브로는 못 누른다).
	var g_use := _line_in(_src, "or orchard_dispatch) \\")
	var g_harv := _line_in(_src, "(_target_valid or pot_dispatch or orchard_dispatch)")
	_check("②e 두 디스패치 게이트가 그 or-항을 물었다 — LMB `_use_tool`(main %d행) · RMB `_try_harvest`(%d행)"
			% [g_use + 1, g_harv + 1], g_use >= 0 and g_harv >= 0)
	m.orchard.load_save(orchard_snap)      # 무대 원복 — 심은 나무를 원장에서 되돌린다
	m.inventory.slots[m.inventory.selected_index] = null

# ── ③ #2 안식 마당 나무 — 밑동↔앵커 다리(라이브) ────────────────────────────
func _check_home_tree_bridge(m: Node) -> void:
	print("③ #2 마당 나무 밑동 다리")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	var drop_tiles: int = int(m._tapper_home_drop()) / int(m.TILE)
	_check("③a 무대: 손저작 나무 보정 = 스프라이트 높이 − 한 칸 = %d칸(0이면 이 결함 자체가 없다)"
			% drop_tiles, drop_tiles > 0)
	var anchors: Array = m._home_tree_anchors()
	var anchor := Vector2i(-1, -1)
	for t in anchors:
		var a: Vector2i = t
		if m.tree_ledger.is_occupied(RegionCatalog.HOME, a) \
				and not m.tree_ledger.is_occupied(RegionCatalog.HOME, a + Vector2i(0, drop_tiles)):
			anchor = a
			break
	_check("③b 무대: 원장이 아는 손저작 앵커(%d그루) 중 밑동 칸이 원장에 **없는** 나무를 골랐다 %s"
			% [anchors.size(), str(anchor)], anchor.x >= 0)
	if anchor.x < 0:
		return
	var trunk := anchor + Vector2i(0, drop_tiles)
	_check("③c 보이는 밑동 %s → 원장 칸 %s로 이어진다(다리 없으면 그 칸은 원장 밖이라 도끼·낫이 무동작)"
			% [str(trunk), str(m._home_tree_ledger_tile(trunk))], m._home_tree_ledger_tile(trunk) == anchor)
	_check("③d **더하기만 한다** — 앵커 칸 조준은 그대로 앵커다(%s) · 아무 나무도 없는 칸은 항등(%s)"
			% [str(m._home_tree_ledger_tile(anchor)), str(m._home_tree_ledger_tile(Vector2i(0, 0)))],
		m._home_tree_ledger_tile(anchor) == anchor and m._home_tree_ledger_tile(Vector2i(0, 0)) == Vector2i(0, 0))
	# 채취기 축은 이미 밑동에서 선다 — 벌목 축이 같은 칸에서 서야 한 나무의 동사가 안 갈린다.
	_check("③e 같은 밑동 칸에서 **채취기 설치 축**(%s)과 **벌목 축**(%s)이 같은 나무를 가리킨다"
			% [str(m._tapper_place_tile(trunk)), str(m._home_tree_ledger_tile(trunk))],
		m._tapper_place_tile(trunk) == anchor and m._home_tree_ledger_tile(trunk) == anchor)
	# 프롬프트 사슬이 **밑동에서 실제로 선다** — 그 elif가 묻는 술어를 그대로 다시 묻는다.
	var stands: bool = m.tree_ledger.is_occupied(m._region, m._home_tree_ledger_tile(trunk))
	var t_prompt: String = m._tree_prompt(m._home_tree_ledger_tile(trunk))
	_check("③f 밑동을 겨눈 프롬프트가 선다(사슬 술어 %s) — 「%s」 · 앵커를 겨눴을 때와 같은 문장이다"
			% [str(stands), t_prompt], stands and t_prompt == m._tree_prompt(anchor))

# ── ④ #3 휘파람 [F] 안내가 갱도·나락 층에서도 선다 ──────────────────────────
func _check_mount_prompt(m: Node) -> void:
	print("④ #3 갱도·나락 층의 휘파람 안내")
	var held: String = m.inventory.selected_id()
	m.inventory.slots[m.inventory.selected_index] = {"id": ItemCatalog.MOUNT_WHISTLE, "count": 1, "quality": 0}
	m._indoor = ""
	var prev_depth: int = m._narak_depth
	m._narak_depth = 0
	var mine_line: String = m._mount_prompt()
	m._narak_depth = 1
	var narak_line: String = m._mount_prompt()
	m._narak_depth = prev_depth
	_check("④a 갱도 무대(깊이 0)는 **탈 수 있다** — 「%s」" % mine_line, mine_line.contains("[F]"))
	_check("④b 나락 층(깊이 1)은 왜 못 타는지를 말한다 — 「%s」" % narak_line,
		narak_line != "" and not narak_line.contains("[F]") and narak_line.contains("탈 수 없다"))
	m.inventory.slots[m.inventory.selected_index] = null
	_check("④c 든 게 휘파람이 아니면 이 안내를 안 세운다(\"\" — 사슬을 안 가로챈다)", m._mount_prompt() == "")
	if held != "":
		m.inventory.slots[m.inventory.selected_index] = {"id": held, "count": 1, "quality": 0}
	# 두 포괄 분기가 **자기 바닥 줄보다 먼저** 그 안내를 잡는가(입력 사슬의 자리 = 라이브로는 못 누른다).
	# 자리를 이름이 아니라 **순서로** 잰다: 갱도 블록 안 → 나락 블록 안 → 사슬 맨 끝, 셋이 이 순서다.
	# ★두 술어는 파일 곳곳(구역 크기·카메라)에 같은 형태로 나오므로 **프롬프트 사슬의 그것**을
	#   집는다 — 그 사슬의 머리인 갱도 입구 분기 뒤로 처음 나오는 자리다.
	var chain_head := _line_in(_src, "elif _at_dungeon_gate():")
	var mine_head := -1
	var narak_head := -1
	for i in range(chain_head + 1, _src.size()):
		var ln := String(_src[i])
		if mine_head < 0 and ln.contains("elif _in_mine_floor():"):
			mine_head = i
		if mine_head >= 0 and narak_head < 0 and ln.contains("elif _in_narak_floor():"):
			narak_head = i
			break
	var hits: Array = []
	for i in range(_src.size()):
		if String(_src[i]).contains("elif _mount_prompt() != \"\":"):
			hits.append(i)
	_check("④d 휘파람 갈래가 셋이다 — 갱도 블록(%d행 > 머리 %d) · 나락 블록(%d > %d) · 사슬 맨 끝(%d행)"
			% [(hits[0] + 1) if hits.size() > 0 else -1, mine_head + 1,
				(hits[1] + 1) if hits.size() > 1 else -1, narak_head + 1,
				(hits[2] + 1) if hits.size() > 2 else -1],
		hits.size() == 3 and mine_head >= 0 and narak_head >= 0 \
			and mine_head < hits[0] and hits[0] < narak_head and narak_head < hits[1] \
			and hits[1] < hits[2])

# ── ⑤ #4 CAT_RELIC 아이콘 케이스(레지스트리 파생 분모) ──────────────────────
func _check_relic_icon(m: Node) -> void:
	print("⑤ #4 유품 아이콘 케이스")
	# 분모 = item_catalog.gd가 선언한 **전 카테고리**(옮겨 적기 0 — 카테고리가 늘면 분모가 는다).
	var cats: Array = []
	for line in _cat_src:
		var ln := String(line)
		if ln.begins_with("const CAT_"):
			cats.append(ln.split(" ")[1])
	_check("⑤a 무대: 카테고리 상수를 소스에서 %d종 긁었다 %s" % [cats.size(), str(cats)], cats.size() >= 10)
	var missing_hot: Array = []
	var missing_inv: Array = []
	for c in cats:
		var cname := String(c)
		if ItemCatalog.ids_in_category(_cat_value(cname)).is_empty():
			continue                       # 인벤에 들 id가 하나도 없는 카테고리는 그릴 것이 없다
		if _line_in(_hot_src, "ItemCatalog." + cname + ":") < 0:
			missing_hot.append(cname)
		if _line_in(_inv_src, "ItemCatalog." + cname + ":") < 0:
			missing_inv.append(cname)
	_check("⑤b 두 슬롯 드로어의 match에 빠진 카테고리가 0이다(핫바 %s · 백팩 %s)"
			% [str(missing_hot), str(missing_inv)], missing_hot.is_empty() and missing_inv.is_empty())
	# 유품 전 종이 실제로 CAT_RELIC이고 색박스 폴백을 갖는다(전량 — 한 종만 재면 표가 늘 때 샌다).
	var relics: Array = ItemCatalog.ids_in_category(ItemCatalog.CAT_RELIC)
	var colorless: Array = []
	for rid in relics:
		if ItemCatalog.tool_color_of(String(rid)) == Color.WHITE:
			colorless.append(rid)
	_check("⑤c 무대: 유품 %d종이 CAT_RELIC으로 분류된다 %s" % [relics.size(), str(relics)],
		relics.size() == ItemCatalog.RELICS.size() and relics.size() > 0)
	_check("⑤d 유품 전 종이 색박스 폴백을 갖는다(흰 박스로 떨어지는 종 %s) — 색 출처는 RELICS의 color 하나다"
			% str(colorless), colorless.is_empty())
	# 진열장이 그 표를 파생해 읽는가(색이 두 곳에서 갈리지 않는다).
	var derived := _line_in(_src, "relic_colors[rid] = ItemCatalog.tool_color_of(String(rid))")
	_check("⑤e 혼백관 진열도 같은 표를 파생한다(main %d행) — 지역 색 dict가 사라졌다" % (derived + 1),
		derived >= 0 and _line_in(_src, "ItemCatalog.RELIC_BINYEO: Color(") < 0)

func _cat_value(cname: String) -> String:
	# "CAT_TOOL" → ItemCatalog.CAT_TOOL 값. 소스에서 긁은 이름을 값으로 되돌린다(하드코딩 0).
	var idx := _line_in(_cat_src, "const " + cname + " :=")
	if idx < 0:
		return ""
	var s := String(_cat_src[idx])
	var a := s.find("\"")
	var b := s.find("\"", a + 1)
	return s.substr(a + 1, b - a - 1) if b > a else ""

# ── ⑥ #5 씨앗 성장일수가 화면 문구에 실제로 실린다 ──────────────────────────
func _check_seed_growth_tooltip(m: Node) -> void:
	print("⑥ #5 성장일수 도달 경로")
	var seeds: Array = ItemCatalog.ids_in_category(ItemCatalog.CAT_SEED)
	_check("⑥a 무대: 씨앗 %d종을 카탈로그에서 파생했다(하드코딩 0)" % seeds.size(), seeds.size() > 0)
	var missing: Array = []
	var shown := 0
	for sid in seeds:
		var days := CropCatalog.growth_days(ItemCatalog.crop_of(String(sid)))
		if days <= 0:
			continue                        # 성장일수가 없는 파생 id(혼합 봉지 등)는 붙일 값이 없다
		shown += 1
		if not HudTooltip.label_for(String(sid), 0).contains("%d일" % days):
			missing.append(sid)
	_check("⑥b 성장일수를 가진 씨앗 %d종이 전부 툴팁 문구에 그 값을 싣는다(빠진 종 %s)"
			% [shown, str(missing)], shown > 0 and missing.is_empty())
	# 이름·등급이라는 기존 계약은 안 깨졌다(덧붙이기이지 갈아 끼우기가 아니다).
	var one := String(seeds[0])
	var lbl := HudTooltip.label_for(one, 2)
	_check("⑥c 이름·등급 계약 불변 — 「%s」에 이름(%s)과 등급(%s)이 함께 있다"
			% [lbl, ItemCatalog.name_of(one), ItemCatalog.quality_name(2)],
		lbl.contains(ItemCatalog.name_of(one)) and lbl.contains(ItemCatalog.quality_name(2)))
	# 그리는 쪽이 그 함수를 쓰는가(문구 출처가 하나여야 화면과 단언이 안 갈린다).
	var used := _line_in(_lines_of_file("res://hud_tooltip.gd"), "text = label_for(id, _inv.quality_at(idx))")
	_check("⑥d 툴팁 `_process`가 그 함수를 문구 출처로 쓴다(hud_tooltip %d행)" % (used + 1), used >= 0)

# ── ⑦ #6 바 옵트인 창이 결혼으로 좁아진다(라이브) ───────────────────────────
func _check_night_bar_optin_window(m: Node) -> void:
	print("⑦ #6 나라카 바 옵트인 창")
	var r = m._resident("bana")
	_check("⑦a 무대: 바나 레코드에 창구 둘이 달려 있다(prompt_extra·shop_key)",
		r != null and r.prompt_extra is Callable and r.shop_key is Callable)
	if r == null:
		return
	var prev_spouse: String = m._spouse_id
	var prev_min: float = m.clock.minutes
	var home_min: int = m.SPOUSE_HOME_MIN["bana"]
	var late: float = float(home_min) + 30.0     # 귀가 뒤 30분 — 종전엔 여기서 열렸다

	m._spouse_id = ""
	m.clock.minutes = late
	m.night_bar.abandon()
	_check("⑦b 미혼: 같은 시각(%02d:%02d)에 창은 **그대로 열린다** — 기저 메카닉 불변(ADR-0008 · 상한 %d분)"
			% [int(late) / 60, int(late) % 60, m._night_bar_optin_close_min()],
		m._night_bar_optin_close_min() == NightBar.CLOSE_MIN and bool(r.shop_key.call()))
	m.night_bar.abandon()

	m._spouse_id = "bana"
	m.clock.minutes = late
	_check("⑦c 결혼 후: 상한이 귀가 시각(%d분)으로 당겨지고 [F]가 거절된다 — 안방에서 원격으로 못 연다"
			% m._night_bar_optin_close_min(),
		m._night_bar_optin_close_min() == home_min and not bool(r.shop_key.call()) \
			and not m.night_bar.is_opened())
	_check("⑦d 광고도 함께 걷힌다 — 창 밖 문구는 「%s」(빈 줄)" % String(r.prompt_extra.call()),
		String(r.prompt_extra.call()) == "")
	m.clock.minutes = float(home_min) - 30.0
	_check("⑦e 좁아진 창 **안**(%02d:%02d)에서는 여전히 열린다 — 막힘 0"
			% [int(m.clock.minutes) / 60, int(m.clock.minutes) % 60],
		String(r.prompt_extra.call()).contains("[F]") and bool(r.shop_key.call()))
	m.night_bar.abandon()
	m._spouse_id = prev_spouse
	m.clock.minutes = prev_min

# ── ⑧ #7 체키가 카페 마감 경계를 못 넘는다(라이브) ──────────────────────────
func _check_cheki_close_boundary(m: Node) -> void:
	print("⑧ #7 체키 ↔ 카페 마감 경계")
	var prev_min: float = m.clock.minutes
	m.clock.minutes = float(Cafe.CLOSE_MIN) - 10.0
	m.cafe.tick(0.0, m.clock.minutes)
	var seat := 0
	var guest: String = "guest_probe"
	var menu: String = MenuCatalog.ids()[0]
	m._offer_cheki(seat, guest, menu)
	m._start_cheki()
	_check("⑧a 무대: 마감 10분 전에 촬영 세션이 실제로 섰다(영업 중 %s · 세션 %s)"
			% [str(m.cafe.is_open()), str(m.cheki != null)], m.cafe.is_open() and m.cheki != null)

	var rev_before: int = m.cafe.today_revenue()
	var cheki_before: int = m.cafe.today_cheki()
	m._on_cafe_closed(rev_before, 0, 0)
	_check("⑧b 마감 핸들러가 세션(%s)과 제안 창(%.1f초)을 그 자리에서 접는다 — 정산 뒤에 장부가 더 오르지 않는다"
			% [str(m.cheki), m._cheki_offer_secs], m.cheki == null and m._cheki_offer_secs == 0.0)
	_check("⑧c 접기에 매출·체키 적립이 따라붙지 않았다(매출 %d→%d냥 · 체키 %d→%d장)"
			% [rev_before, m.cafe.today_revenue(), cheki_before, m.cafe.today_cheki()],
		m.cafe.today_cheki() == cheki_before and m.cafe.today_revenue() == rev_before)

	# 술어 축 — 카페가 실제로 닫힌 뒤에는 창 타이머가 남아 있어도 제안이 안 선다(빈 스툴 앞 RMB).
	m.clock.minutes = float(Cafe.CLOSE_MIN)
	m.cafe.tick(0.0, m.clock.minutes)
	m._offer_cheki(seat, guest, menu)          # 창 타이머만 다시 채운다(마감 뒤 잔여 창의 재현)
	_check("⑧d 무대: 카페가 닫혔는데(%s) 창 타이머는 %.1f초 남아 있다 — 종전엔 이 상태가 최대 %.0f 게임분 지속됐다"
			% [str(not m.cafe.is_open()), m._cheki_offer_secs,
				m._cheki_offer_secs * (GameClock.END_MIN - GameClock.START_MIN) / GameClock.REAL_SECONDS_PER_DAY],
		not m.cafe.is_open() and m._cheki_offer_secs > 0.0)
	_check("⑧e 그 잔여 창으로는 제안이 서지 않는다 — 이미 귀가한 손님의 체키가 시작되지 않는다",
		not m._cheki_offered_at(seat))
	m._clear_cheki_offer()
	m.clock.minutes = prev_min

# ── ⑨ #8 방목 문 알림이 방출 결과를 말한다(문구 함수 라이브 호출) ───────────
func _check_ranch_door_notice(m: Node) -> void:
	print("⑨ #8 방목 문 열기 알림")
	var prev_min: float = m.clock.minutes
	var prev_day: int = m.clock.day
	var building: String = m.ANIMAL_BUILDINGS[0]

	# ㉠ 낮·평온·실제 방출 — 종전 문구 그대로다(회귀 보존).
	var calm_day := -1
	var snow_day := -1
	for d in range(1, 400):
		if calm_day < 0 and Weather.allows_grazing(Weather.weather_for_day(d)):
			calm_day = d
		if snow_day < 0 and not Weather.allows_grazing(Weather.weather_for_day(d)):
			snow_day = d
		if calm_day > 0 and snow_day > 0:
			break
	_check("⑨a 무대: 방목 가능한 날(%d일)과 방목 금지 날(%d일)을 날씨 표에서 파생했다(하드코딩 0)"
			% [calm_day, snow_day], calm_day > 0 and snow_day > 0)
	m.clock.day = calm_day
	m.clock.minutes = 10.0 * 60.0
	var out_day: String = m._ranch_door_open_notice(building, true, 1)
	_check("⑨b 낮·평온·방출 1마리 → 「%s」" % out_day, out_day.contains("방목지로 나간다"))

	# ㉡ 밤 — 실제 동작은 *귀가 통로 열기*라 문구도 그렇게 말한다.
	m.clock.minutes = 22.0 * 60.0
	_check("⑨c 무대: 그 시각의 phase가 «밤»이다(%s)" % m.clock.phase(), m.clock.phase() == "밤")
	var out_night: String = m._ranch_door_open_notice(building, m._release_open_buildings(), 1)
	_check("⑨d 밤 → 「%s」 — 나갔다고 말하지 않는다" % out_night,
		not out_night.contains("방목지로 나간다") and out_night.contains("귀가"))

	# ㉢ 잿눈 — 실내 급여·청소가 필요하다는 다음 행동까지 말한다.
	m.clock.day = snow_day
	m.clock.minutes = 10.0 * 60.0
	_check("⑨e 무대: 그 날은 방목 금지 날씨다(%s)" % Weather.NAMES[Weather.weather_for_day(snow_day)],
		not m._weather_calm())
	var out_snow: String = m._ranch_door_open_notice(building, m._release_open_buildings(), 1)
	_check("⑨f 잿눈 → 「%s」 — 나갔다고 말하지 않는다" % out_snow,
		not out_snow.contains("방목지로 나간다") and out_snow.contains("잿눈"))

	# ㉣ 나갈 짐승이 0마리인 갈래도 갈린다(게이트는 통과했는데 후보가 없는 경우).
	m.clock.day = calm_day
	var out_none: String = m._ranch_door_open_notice(building, true, 0)
	_check("⑨g 방출 후보 0마리 → 「%s」" % out_none, out_none.contains("나갈 짐승은 없다"))
	# 네 문구가 서로 다르다(한 갈래라도 겹치면 이유가 안 갈린다).
	var uniq := {}
	for s in [out_day, out_night, out_snow, out_none]:
		uniq[s] = true
	_check("⑨h 네 갈래가 서로 다른 문장이다(%d/4)" % uniq.size(), uniq.size() == 4)
	m.clock.day = prev_day
	m.clock.minutes = prev_min

# ── ⑩ #9 강변 레인 라우팅 — 걷는 칸이 벽을 안 뚫는다(라이브) ────────────────
func _check_riverside_lane(m: Node) -> void:
	print("⑩ #9 강변 레인 걷기 경로")
	if m._region != RegionCatalog.NARU_VILLAGE:
		m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	var r = m._resident("serena")
	_check("⑩a 무대: 세레나 레코드에 스케줄 %d칸이 있고 마을 구역이 섰다"
			% (r.schedule.size() if r != null else -1),
		r != null and r.schedule.size() >= 2 and m._region == RegionCatalog.NARU_VILLAGE)
	if r == null:
		return
	# 스테이션이 전부 강변대인지부터 확인한다(이 결함의 전제 — 아니면 잴 것이 없다).
	var all_riverside := true
	for st in r.schedule:
		if int(st["tile"].y) < m.RIVERSIDE_ZONE_Y:
			all_riverside = false
	_check("⑩b 무대: 세레나의 스테이션 %d칸이 전부 강변대(y ≥ %d)에 있다"
			% [r.schedule.size(), m.RIVERSIDE_ZONE_Y], all_riverside)

	var bad: Array = []
	var used_corridor := false
	for i in range(r.schedule.size()):
		for j in range(r.schedule.size()):
			if i == j:
				continue
			var a: Vector2i = r.schedule[i]["tile"]
			var b: Vector2i = r.schedule[j]["tile"]
			var spokes: PackedVector2Array = m._road_spokes(a, b, RegionCatalog.NARU_VILLAGE)
			if spokes.is_empty():
				continue
			for t in _path_tiles(m, a, spokes):
				if t.y == m.MAIN_CORRIDOR_Y:
					used_corridor = true
				if m.is_solid(m._grid[t.y][t.x]):
					bad.append(t)
	_check("⑩c 강변끼리의 전 전환에서 걷는 칸이 **SOLID를 한 칸도 안 지난다**(위반 %s) — 종전엔 자기 집 WALL과 광장 돌담을 관통했다"
			% str(bad), bad.is_empty())
	_check("⑩d 그 경로들이 메인 복도(y%d)로 올라가지 않는다 — 강변 산책로(y%d)를 탄다"
			% [m.MAIN_CORRIDOR_Y, m.RIVERSIDE_LANE_Y], not used_corridor)
	# 레인이 갈리는 전환은 다리 스파인에서 환승한다(복도 주민 ↔ 강변 주민이 생기는 날의 계약).
	var north := Vector2i(int(r.schedule[0]["tile"].x), m.MAIN_CORRIDOR_Y - 2)
	var mixed: PackedVector2Array = m._road_spokes(north, r.schedule[0]["tile"], RegionCatalog.NARU_VILLAGE)
	var link_hit := false
	for p in mixed:
		if int(p.x) / m.TILE == int(m.BRIDGE_X[0]):
			link_hit = true
	_check("⑩e 레인이 갈리는 전환은 다리 스파인 열(x%d)에서 환승한다(경유점 %d개)"
			% [int(m.BRIDGE_X[0]), mixed.size()], link_hit and mixed.size() >= 4)

# 경유점 목록을 실제 걷는 칸으로 편다(축 정렬 구간의 타일 열거 — 걷기는 직선 보간이다).
func _path_tiles(m: Node, from_tile: Vector2i, spokes: PackedVector2Array) -> Array:
	var out: Array = []
	var cur := from_tile
	for p in spokes:
		var nxt := Vector2i(int(p.x) / m.TILE, int(p.y) / m.TILE)
		var step := Vector2i(signi(nxt.x - cur.x), signi(nxt.y - cur.y))
		var guard := 0
		while cur != nxt and guard < 200:
			cur += step
			guard += 1
			if cur.x >= 0 and cur.y >= 0 and cur.x < m._grid_w and cur.y < m._grid_h:
				out.append(cur)
		cur = nxt
	return out

# ── ⑪ #10 문 스포크 우회 열 — 걷기가 지도를 따른다(라이브) ──────────────────
# 무대 공허 통과 방지: 우회가 **필요한 집이 실제로 있는지**를 표에서 먼저 세고(0이면 잴 것이
# 없다), 그 집들의 문 앞 칸에서만 잰다.
func _check_house_door_detour(m: Node) -> void:
	print("⑪ #10 집 문 스포크 우회 열")
	if m._region != RegionCatalog.NARU_VILLAGE:
		m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	var table: Array = m._village_door_spokes()
	var detour_houses: Array = []
	var straight_houses: Array = []
	for e in table:
		var door: Vector2i = e[1]
		if door.y > int(e[2]):
			detour_houses.append(e)
		else:
			straight_houses.append(e)
	_check("⑪a 무대: 문 스포크 표 %d채 중 **문 열을 못 쓰는 집**이 %d채다(지도의 else 갈래 — 0이면 이 결함이 없다)"
			% [table.size(), detour_houses.size()], detour_houses.size() > 0)
	# 지도가 판 우회 열과 걷기가 끼우는 경유점이 같은 열인가 — 표 하나에서 둘 다 나온다.
	var lane_mismatch: Array = []
	for e in detour_houses:
		var rect: Rect2i = e[0]
		var door: Vector2i = e[1]
		var d: Array = m._house_detour(door + Vector2i(0, 1), int(e[2]), RegionCatalog.NARU_VILLAGE)
		if d.size() != 2 or int(d[0].x) != int(rect.end.x) or int(d[1].x) != int(rect.end.x):
			lane_mismatch.append(door)
	_check("⑪b 우회 집 %d채 전부가 지도와 **같은 옆 열**(rect.end.x)을 경유점으로 받는다(어긋난 집 %s)"
			% [detour_houses.size(), str(lane_mismatch)], lane_mismatch.is_empty())
	_check("⑪c 문이 레인 위인 집 %d채는 우회를 **안 받는다**(지도의 if 갈래 — 과잉 적용 0)"
			% straight_houses.size(),
		straight_houses.all(func(e): return m._house_detour(Vector2i(e[1]) + Vector2i(0, 1),
			int(e[2]), RegionCatalog.NARU_VILLAGE).is_empty()))

	# 실제 걷기 칸이 SOLID를 지나지 않는다 — 이 결함의 본체(자기 집 벽 관통).
	var bad: Array = []
	for e in detour_houses:
		var approach: Vector2i = Vector2i(e[1]) + Vector2i(0, 1)
		var dest := Vector2i(int(m.BRIDGE_X[0]), int(e[2]))   # 같은 레인 위 다리 열(도달 가능 칸)
		var spokes: PackedVector2Array = m._road_spokes(approach, dest, RegionCatalog.NARU_VILLAGE)
		for t in _path_tiles(m, approach, spokes):
			if m.is_solid(m._grid[t.y][t.x]):
				bad.append([e[1], t])
	_check("⑪d 우회 집 전 채의 외출 경로가 SOLID를 한 칸도 안 지난다(위반 %s)" % str(bad), bad.is_empty())

	# 실제 주민 전환으로도 잰다 — 스케줄이 그 문 앞 칸에서 출발하는 사람 전부.
	var walked := 0
	var walk_bad: Array = []
	for r in m._residents:
		if r.schedule.size() < 2:
			continue
		for i in range(r.schedule.size() - 1):
			var a: Vector2i = r.schedule[i]["tile"]
			var b: Vector2i = r.schedule[i + 1]["tile"]
			if String(r.schedule[i].get("region", "")) != RegionCatalog.NARU_VILLAGE \
					or String(r.schedule[i + 1].get("region", "")) != RegionCatalog.NARU_VILLAGE:
				continue
			var sp: PackedVector2Array = m._road_spokes(a, b, RegionCatalog.NARU_VILLAGE)
			if sp.is_empty():
				continue
			walked += 1
			for t in _path_tiles(m, a, sp):
				if m.is_solid(m._grid[t.y][t.x]):
					walk_bad.append([r.id, t])
	_check("⑪e 마을 안 주민 전환 %d건이 전부 벽을 안 뚫는다(위반 %s) — 종전엔 복도 남쪽 집들의 아침 전환이 전부 자기 집 몸통을 관통했다"
			% [walked, str(walk_bad)], walked > 0 and walk_bad.is_empty())

# ── ⑫ #11 네오 배우자 — 안방에서 말이 걸린다 / 매대는 안 열린다(라이브) ─────
func _check_spouse_require_indoor(m: Node) -> void:
	print("⑫ #11 배우자 안방 ↔ require_indoor")
	var r = m._resident("neo")
	_check("⑫a 무대: 네오는 require_indoor(%s)를 가진 **동시에** ROMANCE_OPEN 명단에 있다(둘을 함께 가진 유일한 사람)"
			% r.require_indoor,
		r != null and r.require_indoor != "" and m.ROMANCE_OPEN.has("neo"))
	if r == null:
		return
	var prev_spouse: String = m._spouse_id
	var prev_partner: String = m._romance_partner
	var prev_min: float = m.clock.minutes
	var prev_region: String = m._region
	var prev_indoor: String = m._indoor
	var prev_target: Vector2i = m._target
	var sched_n: int = r.schedule.size()

	m._romance_partner = "neo"
	m._spouse_id = "neo"
	m._apply_spouse_home_station()
	_check("⑫b 무대: 혼례로 귀가 스테이션 한 칸이 붙었다(%d→%d칸 · 안방 %s)"
			% [sched_n, r.schedule.size(), str(m.SPOUSE_HOME_TILE)], r.schedule.size() == sched_n + 1)
	m.clock.minutes = float(m.SPOUSE_HOME_MIN.get("neo", Cafe.CLOSE_MIN)) + 60.0
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	m._indoor = "집"
	m._update_resident_station(r)
	m._target = m.SPOUSE_HOME_TILE
	_check("⑫c 무대: 그 시각 네오가 안방 칸에 서 있고(%s) 무대도 그 구역이다" % str(r.tile),
		r.tile == m.SPOUSE_HOME_TILE and m._resident_on_stage(r))
	var faced = m._facing_resident()
	_check("⑫d 안방에서 **말이 걸린다**(마주 본 주민 %s) — 종전엔 require_indoor가 매일 19:00~24:00 내내 눈앞 배우자를 무반응으로 만들었다"
			% (faced.id if faced != null else "<없음>"), faced != null and faced.id == "neo")
	# 점주 레이어는 따라오지 않는다(안방에서 만물상을 원격으로 열지 않는다 — #6과 같은 규율).
	_check("⑫e 그 자리에서 매대는 **안 열린다**([F] %s · 광고 「%s」)"
			% [str(bool(r.shop_key.call())), String(r.prompt_extra.call())],
		not bool(r.shop_key.call()) and String(r.prompt_extra.call()) == "")
	# 가게에서는 종전 그대로다(좁히는 축을 한 톨도 안 잃었다).
	m._indoor = r.require_indoor
	_check("⑫f 만물상 안에서는 매대가 그대로 열린다(광고 「%s」) — 점주 레이어 거동 불변"
			% String(r.prompt_extra.call()),
		String(r.prompt_extra.call()).contains("[F]") and bool(r.shop_key.call()))
	if m.frame != null:
		m.frame.close()
	# 미혼 복귀 — 붙인 스테이션을 걷는다.
	r.schedule.resize(sched_n)
	m._spouse_id = prev_spouse
	m._romance_partner = prev_partner
	m.clock.minutes = prev_min
	m._indoor = prev_indoor
	m._target = prev_target
	if m._region != prev_region:
		m._rebuild_region(prev_region)

# ── ⑬ #12 배치 가드의 시간 축 — 다음 스테이션 칸도 예약된다(라이브) ─────────
func _check_station_placement_guard(m: Node) -> void:
	print("⑬ #12 배치 가드 시간 축")
	m._indoor = ""
	var here: String = m._region
	# 지금은 비어 있지만 **오늘 중 누군가 설** 칸을 찾는다(그런 칸이 없으면 잴 것이 없다).
	var future := Vector2i(-1, -1)
	var owner_id := ""
	for r in m._residents:
		for e in r.schedule:
			var t: Vector2i = e.get("tile", Resident.UNPLACED)
			if t == Resident.UNPLACED or t == r.tile:
				continue
			var reg := String(e.get("region", ""))
			if reg != "" and reg != here:
				continue
			if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
				continue
			future = t
			owner_id = r.id
			break
		if future.x >= 0:
			break
	_check("⑬a 무대: 「지금 비었지만 오늘 중 %s가 설」 칸 %s를 스케줄에서 찾았다" % [owner_id, str(future)],
		future.x >= 0)
	if future.x < 0:
		return
	var standing := false
	for r in m._residents:
		if r.tile == future:
			standing = true
	_check("⑬b 무대: 그 칸엔 **지금 아무도 안 서 있다**(현재 칸만 보던 옛 가드는 여길 열어 줬다)",
		not standing)
	_check("⑬c 예약된다 — `_resident_tile` %s · 업화로 %s · 결정기 %s"
			% [str(m._resident_tile(future)), str(m._can_place_furnace(future)),
				str(m._can_place_crystalarium(future))],
		m._resident_tile(future) and not m._can_place_furnace(future) \
			and not m._can_place_crystalarium(future))
	# **새 배치만 막는다** — 이미 놓인 기계의 회수 경로([F] 양보)는 그대로다.
	var yield_line := _line_in(_src, "and not _f_machine_at(_target)")
	_check("⑬d 구세이브 탈출구 불변: [F] 사다리의 기계 양보가 그대로 있다(main %d행) — 가드는 새 배치만 막는다"
			% (yield_line + 1), yield_line >= 0)

# ── ⑭ #13 엔딩 BGM이 실제로 도달한다(라이브) ────────────────────────────────
func _check_ending_music(m: Node) -> void:
	print("⑭ #13 엔딩 BGM 도달 경로")
	# 사실 ㉠ — `_run_over`를 세우는 곳이 게임 코드에 0개다(그래서 인자만으로는 영영 false였다).
	var setters := 0
	for line in _src:
		var ln := String(line)
		if ln.strip_edges().begins_with("#"):
			continue
		if ln.contains("_end_run()") and not ln.contains("func _end_run"):
			setters += 1
	_check("⑭a 무대: `_end_run()`의 게임 코드 호출부가 여전히 0개다(%d) — 이 결함의 뿌리이자 손대지 않은 자리"
			% setters, setters == 0)
	var prev_open: bool = m._epilogue_open
	var prev_running: bool = m.clock.running
	_check("⑭b 평시엔 엔딩 phase가 아니다 — `_ending_music_on()` %s · phase 「%s」"
			% [str(m._ending_music_on()),
				m.audio.phase_for(m.clock.minutes, m._ending_music_on(), m._in_cafe())],
		not m._ending_music_on() \
			and m.audio.phase_for(m.clock.minutes, m._ending_music_on(), m._in_cafe()) != GameAudio.PHASE_ENDING)
	m._open_epilogue()
	_check("⑭c 해방 회고 화면이 서면 엔딩 phase가 선다 — phase 「%s」 · BGM stem 「%s」"
			% [m.audio.phase_for(m.clock.minutes, m._ending_music_on(), m._in_cafe()),
				String(GameAudio.BGM_STEM[GameAudio.PHASE_ENDING])],
		m._epilogue_open \
			and m.audio.phase_for(m.clock.minutes, m._ending_music_on(), m._in_cafe()) == GameAudio.PHASE_ENDING)
	# 그 stem이 실존 에셋으로 해석된다(빈 phase를 세우면 소리가 없다 = 봉합이 반쪽이다).
	var stem := String(GameAudio.BGM_STEM[GameAudio.PHASE_ENDING])
	_check("⑭d 그 stem이 실존 파일로 해석된다(assets/audio/bgm/%s) — 세운 phase에 실제로 소리가 있다" % stem,
		m.audio.bgm_source(GameAudio.PHASE_ENDING) != "")
	m._close_epilogue()
	_check("⑭e 회고를 닫으면 **스스로 원래 phase로 돌아온다**(「%s」) — 새 래치가 0이라 되감을 것도 없다"
			% m.audio.phase_for(m.clock.minutes, m._ending_music_on(), m._in_cafe()),
		not m._ending_music_on() \
			and m.audio.phase_for(m.clock.minutes, m._ending_music_on(), m._in_cafe()) != GameAudio.PHASE_ENDING)
	m._epilogue_open = prev_open
	m.clock.running = prev_running

# ── ⑮⑯ #14·#15 구세이브 로드가 당일치 원장을 되감는다(F9 왕복 실측) ─────────
func _check_daily_ledger_reload(m: Node) -> void:
	print("⑮⑯ #14·#15 구세이브 로드 리셋(F9 왕복)")
	var d: int = m.clock.day
	_check("⑯a 무대: 두 원장이 부팅 1회 생성 노드다(세션 내 로드가 인스턴스를 안 갈아끼운다)",
		m.seasonal_event != null and m.peddler != null)
	# ① 지금 상태를 저장한 뒤 **그 키 둘을 지운다** = 구세이브(S7-T7·S10-T3 이전 파일)의 재현.
	var ok_save: bool = m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	_check("⑯b 무대: 세이브가 서고(%s) 두 조각이 그 안에 있다" % str(ok_save),
		ok_save and raw.has("seasonal_event") and raw.has("peddler"))
	raw.erase("seasonal_event")
	raw.erase("peddler")
	m.saver.save_game(raw, m._active_slot)
	# ② 직전 세션 값을 더럽힌다 — 같은 날짜의 당일치 원장(리셋이 `derby_day == d`에서 통째로 막힌다).
	m.seasonal_event.load_save({"derby_day": d, "derby_tags": 3, "derby_exchanges": 2,
		"grange_day": d, "market_bought": ["dirty_item"]})
	var rare_id: String = m.peddler.RARECROW_ID
	m.peddler.load_save({"rare_day": d, "rare_id": rare_id, "bought": [rare_id]})
	_check("⑮a 무대: 직전 세션 값이 섰다 — 태그 %d장 · 보상 %d칸 · 장원제 %s · 희귀 슬롯 잠금 %s"
			% [m.seasonal_event.tags_on(d), m.seasonal_event.derby_exchanges,
				str(m.seasonal_event.grange_day == d), str(m.peddler.rare_taken_on(d))],
		m.seasonal_event.tags_on(d) == 3 and m.seasonal_event.grange_day == d \
			and m.peddler.rare_taken_on(d))
	# ③ 그 구세이브를 로드한다(F9).
	var ok_load: bool = m._load_game()
	await process_frame
	_check("⑮b 로드가 섰다(%s)" % str(ok_load), ok_load)
	_check("⑮c 절기 원장이 되감겼다 — 태그 %d장 · 보상 %d칸 · 장원제 이력 %s · 한정품 차단 %s (어획 한 번 없는 세이브가 물려받지 않는다)"
			% [m.seasonal_event.tags_on(d), m.seasonal_event.derby_exchanges,
				str(m.seasonal_event.grange_day), str(m.seasonal_event.has_bought("dirty_item"))],
		m.seasonal_event.tags_on(d) == 0 and m.seasonal_event.derby_exchanges == 0 \
			and m.seasonal_event.grange_day == 0 and not m.seasonal_event.has_bought("dirty_item"))
	_check("⑯c 보부상 원장이 되감겼다 — 희귀 슬롯 잠금 %s · 1회성 구매 이력 %s (`load_save` 머리말이 계약으로 못 박은 그 왕복)"
			% [str(m.peddler.rare_taken_on(d)), str(m.peddler.has_bought(rare_id))],
		not m.peddler.rare_taken_on(d) and not m.peddler.has_bought(rare_id))
	# 판별식이 남는다: 두 조각은 **부팅으로 시드되지 않는다**(플레이가 채운다) → 로드는 무조건 되감는다.
	var guarded := _line_in(_src, "if data.has(\"seasonal_event\")") >= 0 \
		or _line_in(_src, "if data.has(\"peddler\")") >= 0
	_check("⑯d `has` 가드가 걷혔다(잔존 %s) — R6가 카페에 쓴 그 처방의 형제 전파" % str(guarded), not guarded)
	m.saver.delete_save(m._active_slot)

# ── ⑰ #16 풀스크린 오버레이가 월드 자식들 위에 선다(라이브 z) ────────────────
# 분모를 안 옮겨 적는다: main의 **전 CanvasItem 자식**을 훑어 최대 z를 데이터에서 뽑는다.
func _check_overlay_z(m: Node) -> void:
	print("⑰ #16 월드 오버레이 z")
	_check("⑰a 무대: z 셔틀 노드가 서 있다", m._world_overlay != null)
	if m._world_overlay == null:
		return
	var max_other := -9999
	var worst := ""
	for c in m.get_children():
		if c == m._world_overlay or not (c is CanvasItem):
			continue
		if int(c.z_index) > max_other:
			max_other = int(c.z_index)
			worst = c.name
	_check("⑰b 오버레이 z(%d)가 **다른 모든 월드 자식**보다 높다(최고 경쟁자 %s z%d) — 플레이어·앞프롭·월드 라벨이 암전 위에 남지 않는다"
			% [m._world_overlay.z_index, worst, max_other], m._world_overlay.z_index > max_other)
	# 라벨이 실제로 그 경쟁자 안에 들어 있는가(무대 공허 통과 방지 — 라벨이 0개면 잴 것이 없다).
	_check("⑰c 무대: 월드 라벨이 %d개 서 있고 그 z(%d)도 위 비교에 포함됐다"
			% [m._labels.size(), (int(m._labels[0].z_index) if m._labels.size() > 0 else -1)],
		m._labels.size() > 0 and int(m._labels[0].z_index) <= max_other)
	# main의 `_draw`는 더 이상 두 그림을 안 그린다(같은 그림이 두 겹으로 나가지 않는다).
	var in_main_draw := _line_in_func(_src, "func _draw()", "_draw_spine_puzzle(")
	var shuttle := _line_in(_src, "func _draw_world_overlays(canvas: CanvasItem)")
	_check("⑰d main `_draw`에서 걷혔고(%d) 셔틀 창구가 섰다(main %d행)"
			% [in_main_draw + 1, shuttle + 1], in_main_draw < 0 and shuttle >= 0)
	# 셔틀의 재그리기 게이트가 두 그림의 자기 가드와 같은 답을 낸다(헛돌지도, 빠뜨리지도 않는다).
	_check("⑰e 평시엔 오버레이가 없다고 답한다(`_world_overlay_active` %s)" % str(m._world_overlay_active()),
		not m._world_overlay_active())
	var prev_illust: String = m._illust_id
	var prev_a: float = m._illust_a
	m._illust_id = "b6"
	m._illust_a = 1.0
	_check("⑰f 일러스트가 서면 참이 된다(%s)" % str(m._world_overlay_active()), m._world_overlay_active())
	m._illust_id = prev_illust
	m._illust_a = prev_a

# ── ⑱ #17 원장 나무 그림이 밑동에 선다(그리기 원점 함수 라이브 호출) ────────
func _check_tree_ledger_draw(m: Node) -> void:
	print("⑱ #17 원장 나무 그리기 원점")
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	m._indoor = ""
	var drop_tiles: int = int(m._tapper_home_drop()) / int(m.TILE)
	var anchors: Array = m._home_tree_anchors()
	var anchor := Vector2i(-1, -1)
	for t in anchors:
		if m.tree_ledger.is_occupied(RegionCatalog.HOME, t):
			anchor = t
			break
	_check("⑱a 무대: 손저작 앵커(%d그루) 중 원장이 아는 나무 %s · 보정 %d칸"
			% [anchors.size(), str(anchor), drop_tiles], anchor.x >= 0 and drop_tiles > 0)
	if anchor.x < 0:
		return
	var px: Vector2 = m._tree_ledger_draw_px(anchor)
	var drawn_tile := Vector2i(int(px.x) / int(m.TILE), int(px.y) / int(m.TILE))
	_check("⑱b 그리기 원점이 앵커가 아니라 **밑동 행**이다 — 원장 칸 %s → 그리는 칸 %s"
			% [str(anchor), str(drawn_tile)], drawn_tile == anchor + Vector2i(0, drop_tiles))
	# 채취기 그림과 **같은 발치**에 선다(형제 그림이 3칸 갈려 서지 않는다).
	_check("⑱c 형제 그림(채취기)과 같은 발치다 — 나무 %.0fpx · 채취기 %.0fpx"
			% [px.y, float(anchor.y * m.TILE) + m._tapper_home_drop()],
		is_equal_approx(px.y, float(anchor.y * m.TILE) + m._tapper_home_drop()))
	# R18 #2의 조준 다리와 짝이 맞는다: **겨누는 칸 = 그려지는 칸**.
	_check("⑱d 조준 다리와 짝이 맞는다 — 그려진 칸 %s를 겨누면 원장 칸 %s로 이어진다"
			% [str(drawn_tile), str(m._home_tree_ledger_tile(drawn_tile))],
		m._home_tree_ledger_tile(drawn_tile) == anchor)
	# 보정이 0인 자리(자체 파종·숲)는 항등 — 없는 나무의 발치를 빌리지 않는다.
	var free := Vector2i(1, 1)
	_check("⑱e 손저작 앵커가 아닌 칸은 항등이다 %s" % str(m._tree_ledger_draw_px(free)),
		m._tree_ledger_draw_px(free) == Vector2(free.x * m.TILE, free.y * m.TILE))

# ── ⑲ #18 트렐리스 앞뒤가 파종 순서에 안 흔들린다(그리기 순서 함수 라이브) ──
func _check_crop_draw_order(m: Node) -> void:
	print("⑲ #18 작물 그리기 순서")
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	m._indoor = ""
	# 트렐리스 종을 카탈로그에서 파생한다(하드코딩 0 — 종이 늘면 함께 는다).
	var trellis := ""
	for cid in CropCatalog.ids():
		if CropCatalog.is_trellis(String(cid)):
			trellis = String(cid)
			break
	var plain := ""
	for cid in CropCatalog.ids():
		if not CropCatalog.is_trellis(String(cid)):
			plain = String(cid)
			break
	_check("⑲a 무대: 트렐리스 종(%s)과 일반 종(%s)을 카탈로그에서 파생했다" % [trellis, plain],
		trellis != "" and plain != "")
	if trellis == "" or plain == "":
		return
	# 스타터 밭에서 세로로 붙은 두 칸을 고른다(위 칸이 넝쿨에 덮이는 그 조합).
	var south := Vector2i(-1, -1)
	var rect: Rect2i = m.STARTER_PATCH_RECT
	for y in range(rect.position.y + 1, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var s := Vector2i(x, y)
			var n := Vector2i(x, y - 1)
			if m._is_farmable(s) and m._is_farmable(n) \
					and not m.farm.is_planted(s) and not m.farm.is_planted(n):
				south = s
				break
		if south.x >= 0:
			break
	_check("⑲b 무대: 세로로 붙은 빈 밭 두 칸 %s(남·넝쿨)·%s(북)을 골랐다"
			% [str(south), str(south - Vector2i(0, 1))], south.x >= 0)
	if south.x < 0:
		return
	var north := south - Vector2i(0, 1)
	var snap: Dictionary = m.farm.to_save()

	# ㉠ 남(넝쿨)을 먼저 일군다 → ㉡ 북을 먼저 일군다. 두 이력의 그리기 순서가 **같아야** 한다.
	# ★원장 순서를 정하는 것은 파종이 아니라 **괭이질**이다(`hoe`가 `_tiles`에 칸을 처음 넣는다) —
	#   심는 순서만 뒤집으면 정렬을 지워도 두 목록이 같아 이 단언이 헛돈다(실측으로 확인).
	m.farm.load_save(snap)
	m.farm.hoe(south); m.farm.hoe(north)
	m.farm.plant(south, trellis)
	m.farm.plant(north, plain)
	var order_a: Array = m._crop_draw_order()
	m.farm.load_save(snap)
	m.farm.hoe(north); m.farm.hoe(south)
	m.farm.plant(north, plain)
	m.farm.plant(south, trellis)
	var order_b: Array = m._crop_draw_order()
	_check("⑲c 두 파종 이력이 **같은 그리기 순서**를 낸다(%s == %s) — 같은 월드 상태가 다른 그림이 되지 않는다"
			% [str(order_a), str(order_b)], order_a == order_b)
	var ia := order_a.find(north)
	var ib := order_a.find(south)
	_check("⑲d 북(%s, i=%d)이 남(%s, i=%d)보다 **먼저** 그려진다 — 가까운 쪽 넝쿨이 위에 얹힌다"
			% [str(north), ia, str(south), ib], ia >= 0 and ib >= 0 and ia < ib)
	# 전 목록이 발치 y 오름차순이다(두 칸만 맞고 나머지가 어긋나면 반쪽이다).
	var monotonic := true
	for i in range(order_a.size() - 1):
		if int(order_a[i].y) > int(order_a[i + 1].y):
			monotonic = false
	_check("⑲e 목록 %d칸 전체가 발치 y 오름차순이다" % order_a.size(), monotonic)
	m.farm.load_save(snap)
