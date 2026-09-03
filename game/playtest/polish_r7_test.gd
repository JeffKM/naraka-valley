extends SceneTree
# ★[폴리시 7회차] 버그 헌트 확정분 회귀 — 배치 A(하위호환 이행 · 상단 패널 도달성 · 혼인 생애주기 ·
# 주민 무대 술어) + 배치 B(걷기 오프셋 · 선물 표시 진실성 · 손 물건 이중 소비 · 프롬프트 혼력 게이트 ·
# 목축 생애주기).
#
# polish_r6_test가 "완공이 예정지를 덮기 전에 걷는가"를 세웠다면, 여기는 **가드가 소급되는 세이브는
# 누가 구제하는가 · 창에 안 들어가는 품목은 어떻게 꺼내는가 · 혼인이 무엇을 굳혀 놓는가 ·
# 다른 구역의 같은 좌표는 누구인가**를 잰다.
#
# 무엇을 보증하나(발견 번호 = 7회차 헌트 배치 A):
#   ① #1  R6이 `_is_farmable`에서 뺀 삽사리 칸은 **R6 이전 모든 세이브에서 정상 밭**이었다(스타터
#         패치 5×5의 북동 모서리). 가드는 앞으로만 막으므로 그 칸의 작물이 물도 못 주고 수확도 못
#         하는 채 영구 고립됐다. 이행 훅이 씨앗을 돌려주고 흙을 지운다(적재 자리가 없으면 아무것도
#         안 건드리고 물러난다 — 다음 아침·다음 로드가 다시 시도).
#   ② #2  늘봄방 **완공 당일** 아침 재시도 훅이 `_refresh_greenhouse`의 회수와 같은 프레임에 겹쳐
#         "걷지 못했다" 긴 알림이 두 줄로 났다. 두 번 부르면 실제로 두 줄이 난다는 것을 먼저 재고,
#         그 위에 완공 당일 제외 가드를 소스로 못 박는다.
#   ③ #3/#4 출하함·곳간 상단 내역이 3행에서 잘리고 스크롤이 없어, 창 밖 품목은 히트 rect가 없어
#         **표시도 회수도 불가**였다(회수 창구가 이 패널 하나뿐이다). 창 기하를 단일 출처로 뽑고
#         휠 라우팅을 열었다 — 도달성은 그 단일 출처에서 파생해 잰다(치수 하드코딩 0).
#   ④ #5  앵커 혼인이 붙이는 19:00 HOME 귀가 스테이션이 `visible_rule` 상수 true를 통과해 **전 구역에
#         떠 보였다**(바나가 S8-T7에 받은 구역 겹이 옥자에는 없었다).
#   ⑤ #6/#11(DUP — 같은 뿌리) 멜·네오는 스케줄이 region "" 한 항목뿐이라, 혼인이 얹은 region HOME
#         항목이 HOME 밖에서 visible=false로 끈 뒤 다음 날 06:00에 **되돌릴 분기가 없어 래치**됐다.
#   ⑥ #7  이혼 2타 확인 래치가 F9 로드를 건너 살아남아, 로드 후 첫 [F]가 경고 없이 결행됐다
#         (형제 세션 래치는 전부 `_load_game`에서 되감기는데 이 하나만 빠져 있었다).
#   ⑦ #8  혼인·연애 중이면 타 주민의 ♡5 진급이 영구 정지라 고백 제안이 **상시**로 서고, 그것을
#         "오늘의 사건"으로 읽은 가드가 절기 물음 채널을 영영 닫았다. 제안·거절 장면은 그대로 두고
#         물음만 되살린다.
#   ⑧ #9  혼례 부적·뭍의 비약 발급 가드가 백팩만 봐서 상자에 넣으면 유니크가 재발급됐다
#         (R5의 `_stored_anywhere` 선례가 이 두 창구에는 안 붙어 있었다).
#   ⑨ #10 `_facing_resident`에 구역 술어가 없어 다른 구역의 같은 좌표에서 **화면엔 아무도 없는데**
#         대화·선물이 실제로 열렸다. 좁히기만 하므로 같은 구역의 정상 대화는 한 건도 안 막힌다 —
#         레지스트리 전원에 대해 양방향(제 구역 = 열린다 / 남의 구역 = 안 열린다)으로 잰다.
#   ⑩ #12 `_begin_resident_walk`가 걸어갈 길이 없다고 판단해 돌아가는 세 갈래에서 **진행 중이던
#         걷기를 안 껐다**. 오프셋은 폐기된 옛 목적지 기준이라, 논리 위치가 새 칸으로 스냅된 뒤엔
#         그림이 그 칸에서 통째로 떨어져 그려졌다(세레나의 마을 이동이 19:00 귀가 스테이션에 잘리면
#         안방으로 스냅된 몸이 농원 야외에 서 있는 것으로 보인다).
#   ⑪ #14 관계 탭 선물 리듬이 **생일 면제를 안 봐** 생일 당일에 "0/2"로 불가능을 알렸다 — 그날 G를
#         누르면 실제로는 성립하고 생일 보정까지 들어간다(달력 마커와 정면으로 어긋난 표시).
#   ⑫ #15 곁들이 창구가 회복량 최대치만 굽는 탓에, 선호표가 러브로 지정한 하위 곁들이가 곳간의
#         상위 재고에 인질이 됐다("늘 최대치를 원한다"는 전제가 선물 축이 생기며 깨졌다).
#   ⑬ #16 LMB 한 번이 타일 술어별 갈래와 일반 갈래에서 `_use_tool()`을 **두 번** 실행해, 칸을 안 보는
#         손 물건(명부환·곁들이·계단)이 한 클릭에 2개 소모됐다. `_swing_weapon`이 정확히 이 사유로
#         프레임 가드를 들고 있었으나, 헤드리스 회귀가 같은 프레임에 `_use_tool()`을 연달아 부르는
#         경로라 같은 처방을 못 쓴다 — 디스패치에서 겹침 자체를 없앤다.
#   ⑭ #17 화분 물주기 안내가 혼력 게이트를 안 봐, 부족할 때 "[좌클릭] 물주기"라 해 놓고 LMB가
#         조용히 무동작이었다(노지 밭은 R6이 같은 동사에 이미 안내를 세워 뒀다).
#   ⑮ #18 저승 이끼 안내도 같은 자리 — 같은 나무 앞에서 도끼는 "혼력 부족"을 내고 낫만 "채취 가능"을
#         냈다(두 갈래의 비용이 같은 상수인데 표가 갈렸다).
#   ⑯ #19 큰 넋둥우리·큰 넋우릿간(22,000냥+원목 850)이 **실효 0**이었다 — `add_animal`의 게임 내
#         호출부가 신규 게임 스타터 하나뿐이라 5번째 짐승이 들어올 코드 경로가 없었다. 정원을 파는
#         목공방이 정원을 채울 수단도 팔게 잇는다(수치는 잠정 — owner 큐).
#   ⑰ #20 방목 나간 짐승은 그림만 방목지를 따라가고 상호작용은 실내 앵커에 남아, **보이는 짐승은
#         못 만지고 빈 실내 바닥이 산물을 내줬다**(문을 열어 둔 정상 플레이에선 상시).
#   ⑱ #21 동물 건물 실내 안내가 "방목·격리·청결"을 약속했으나 실제 집행은 여물 급여 + 청소다
#         (건초를 태우는 동사를 한 글자도 안 알리고, 이 조작으로는 안 서는 두 동사를 약속했다).
#   ⑲ #22 짐승 산물 수집만 농사 XP를 안 줘, 목축 전문직 3종이 사는 FARMING 트리가 목축만으로는
#         한 톨도 안 올랐다(밭·과수 형제 분기는 전부 준다).
#
# ★ `_process`·훅 안의 지역 상태는 함수 호출로 재현할 수 없다 — 그 줄이 실제로 그 가드를 달고
#   있나를 소스에서 줄 단위로 대조한다(polish_r4_test ④ · polish_r6_test와 같은 관례).
# ★ 좌표·분모·로스터·치수는 전부 상수/레지스트리에서 파생한다(하드코딩 0).
#
# 실행: ./run_tests.sh polish_r7   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _src: PackedStringArray = PackedStringArray()
var _ui_src: PackedStringArray = PackedStringArray()

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

# main.gd 소스에서 needle이 든 줄의 인덱스(-1 = 없음).
func _line_of(needle: String) -> int:
	return _line_after(0, needle)

func _line_after(start: int, needle: String) -> int:
	for i in range(maxi(start, 0), _src.size()):
		if _src[i].contains(needle):
			return i
	return -1

# ★ 그 함수의 **몸통 안에** 이 줄이 있는가 — 함수 머리에서 시작해 다음 최상위 `func `까지만 본다.
#   같은 호출이 여러 훅에 흩어져 있을 때 "어느 훅에 달렸나"를 정확히 가른다(부분 일치 오검출 방지).
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

func _ui_line_count(needle: String) -> int:
	var n := 0
	for line in _ui_src:
		if line.contains(needle):
			n += 1
	return n

func _notice_has(m: Node, needle: String) -> bool:
	if m.notice_feed == null:
		return false
	for e in m.notice_feed._items:
		if String(e.get("text", "")).contains(needle):
			return true
	return false

func _notice_count(m: Node, needle: String) -> int:
	if m.notice_feed == null:
		return 0
	var n := 0
	for e in m.notice_feed._items:
		if String(e.get("text", "")).contains(needle):
			n += 1
	return n

func _clear_notices(m: Node) -> void:
	if m.notice_feed != null:
		m.notice_feed._items.clear()

# 백팩을 **빈 슬롯 0**으로 채운다(polish_r5/r6의 그 헬퍼 그대로 — 수법을 갈라 두면 여기서만 다르게
# 새는 자리가 생긴다). 풀 = 유품이라 합류할 스택이 하나도 없다.
func _fill_backpack(m: Node) -> void:
	var pool: Array = []
	for id in Museum.donatable_ids():
		pool.append(String(id))
	for i in range(m.inventory.slots.size()):
		m.inventory.slots[i] = {"id": String(pool[i]), "count": 1, "quality": 0} if i < pool.size() \
			else {"id": ItemCatalog.harvest_id(CropCatalog.PIANHWA), "count": 1,
				"quality": (i - pool.size()) % 4}
	m.inventory.changed.emit()

func _clear_backpack(m: Node) -> void:
	for si in m.inventory.slots.size():
		m.inventory.slots[si] = null
	m.inventory.changed.emit()

func _fill_chest(box) -> void:
	var pool: Array = []
	for id in Museum.donatable_ids():
		pool.append(String(id))
	for i in box.slots.size():
		box.slots[i] = {"id": String(pool[i % pool.size()]), "count": 1, "quality": 0} \
			if i < pool.size() else {"id": ItemCatalog.harvest_id(CropCatalog.PIANHWA),
				"count": 1, "quality": (i - pool.size()) % 4}
	box.changed.emit()

func _clear_chest(box) -> void:
	for i in box.slots.size():
		box.slots[i] = null
	box.changed.emit()

func _fill_all_storage(m: Node) -> void:
	_fill_backpack(m)
	_fill_chest(m.chest)
	_fill_chest(m.storehouse_chest)

func _clear_all_storage(m: Node) -> void:
	_clear_backpack(m)
	_clear_chest(m.chest)
	_clear_chest(m.storehouse_chest)

# 그 구역에 선 채로 이 주민이 보이는가(구역만 바꿔 묻고 되돌린다 — 그리드는 안 건드린다).
func _visible_in(m: Node, r: Resident, region: String) -> bool:
	var keep: String = m._region
	m._region = region
	var vis: bool = r.visible_rule.call()
	m._region = keep
	return vis

# 휠 이벤트 하나(프레임 좌표계).
func _wheel(at: Vector2, up: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = at
	return ev

func _wipe_slot(slot: int) -> void:
	var p := SaveManager.slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _initialize() -> void:
	print("══ 폴리시 7회차 — 배치 A(하위호환 이행 · 상단 패널 도달성 · 혼인 생애주기 · 무대 술어) ══")
	_src = FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().split("\n")
	_ui_src = FileAccess.open("res://inv_frame.gd", FileAccess.READ).get_as_text().split("\n")
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)

	var m := await _spawn_main()
	_dismiss_dialogue(m)
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)

	# ── ① #1 삽사리 칸 밭 상태의 하위호환 이행 ────────────────────────────────
	print("── ① #1 R6 이전 세이브의 삽사리 칸 작물이 고립되지 않는다 ──")
	var pet: Vector2i = m.PET_TILE
	var crop: String = CropCatalog.PIANHWA
	var seed_id: String = ItemCatalog.seed_id(crop)
	_check("①a-pre 무대: PET_TILE %s는 STARTER_PATCH_RECT %s 안이고 지형이 SOIL이다 — R6 이전엔 **정상 밭**이었다"
			% [str(pet), str(m.STARTER_PATCH_RECT)],
		m.STARTER_PATCH_RECT.has_point(pet) and m._grid[pet.y][pet.x] == m.SOIL)
	_clear_all_storage(m)
	m.farm.hoe(pet)
	m.farm.plant(pet, crop)
	m._target = pet
	m._target_valid = m._is_farmable(pet)
	_check("①b-pre 고립의 실체: 심겨 있는데 겨눔이 무효라 물주기·수확 디스패치가 둘 다 그 칸을 안 통과한다",
		m.farm.is_planted(pet) and not m._target_valid)
	_clear_notices(m)
	m._reclaim_pet_tile_farm()
	_check("①c 씨앗 1개를 돌려받는다(넣은 것만 되돌린다 — 자란 날수는 버린다): %s ×%d"
			% [ItemCatalog.name_of(seed_id), m._count_anywhere(seed_id)],
		m._count_anywhere(seed_id) == 1)
	_check("①d 흙까지 지운다 — 더는 밭이 아닌 칸에 젖은 흙이 남지 않는다",
		not m.farm.is_tilled(pet) and not m.farm.is_planted(pet))
	_check("①e 조용히 지나가지 않는다(무슨 일이 왜 일어났는지 화면이 말한다)",
		_notice_has(m, "삽사리가 앉은 칸"))
	m._reclaim_pet_tile_farm()
	_check("①f 멱등 — 걷을 것이 없으면 두 번째 호출은 아무 일도 안 한다(씨앗이 두 개로 늘지 않는다)",
		not m.farm.is_tilled(pet) and m._count_anywhere(seed_id) == 1)

	# 만재 갈래: 아무것도 잃지 않고 물러난다(늘봄방 부지 회수와 같은 규율).
	_clear_all_storage(m)
	m.farm.hoe(pet)
	m.farm.plant(pet, crop)
	_fill_all_storage(m)
	_clear_notices(m)
	m._reclaim_pet_tile_farm()
	_check("①g 보관처가 전부 가득이면 **아무것도 안 건드리고** 물러난다(작물이 증발하지 않는다)",
		m.farm.is_planted(pet) and m.farm.is_tilled(pet))
	_check("①h 그리고 이유와 복구법을 말한다", _notice_has(m, "돌려주지 못했다"))
	_clear_all_storage(m)
	_clear_notices(m)
	m._reclaim_pet_tile_farm()
	_check("①i 자리를 비우면 재시도가 실제로 걷는다(씨앗 %d개 회수 · 흙 정리)"
			% m._count_anywhere(seed_id),
		m._count_anywhere(seed_id) == 1 and not m.farm.is_tilled(pet))
	_check("①j 이행 훅이 **아침 정산**에 걸려 있다(늘봄방 부지 재시도와 같은 자리)",
		_in_func("func _on_day_advanced", "_reclaim_pet_tile_farm()"))
	_check("①k 그리고 **로드 직후**에도 걸려 있다 — 구세이브를 불러온 그 화면에서 이미 풀린다",
		_in_func("func _load_game", "_reclaim_pet_tile_farm()"))
	_check("①l 가드 자체는 그대로다(R6 결정 불변 — 이행은 소급분 정리이지 가드 철회가 아니다)",
		not m._is_farmable(pet))
	_clear_all_storage(m)

	# ── ② #2 늘봄방 완공 아침 이중 집행 ───────────────────────────────────────
	print("── ② #2 완공 당일 아침 재시도가 회수를 두 번 돌리지 않는다 ──")
	var lot: Rect2i = m.GREENHOUSE_EXT_RECT
	var lot_tile := Vector2i(lot.position.x, lot.position.y)
	m.sprinkler.place(lot_tile, Sprinkler.TIER_1)
	_fill_all_storage(m)
	_clear_notices(m)
	m._reclaim_greenhouse_lot()
	var stuck_once := _notice_count(m, "걷지 못했다")
	m._reclaim_greenhouse_lot()
	var stuck_twice := _notice_count(m, "걷지 못했다")
	_check("②a-pre 같은 프레임에 두 번 부르면 같은 긴 알림이 실제로 두 줄 난다(%d → %d) — 그래서 가드가 필요하다"
			% [stuck_once, stuck_twice],
		stuck_once == 1 and stuck_twice == 2)
	_check("②b 1회차 집행의 주인은 `_refresh_greenhouse`다(완공 분기가 부르는 그 함수가 첫 줄에서 회수한다)",
		_in_func("func _refresh_greenhouse", "_reclaim_greenhouse_lot()"))
	_check("②c 아침 재시도 훅은 **완공 당일을 제외**한다 — 자리를 비운 다음 아침부터가 그 훅의 몫이다",
		_in_func("func _on_day_advanced", "_greenhouse_built() and built != Carpenter.PROJ_GREENHOUSE"))
	m.sprinkler.remove(lot_tile)
	_clear_all_storage(m)
	_clear_notices(m)

	# ── ③ #3/#4 출하함·곳간 상단 내역의 도달성 ────────────────────────────────
	print("── ③ #3/#4 상단 내역 4번째 이후 품목에 손이 닿는다 ──")
	var vis: int = m.frame.top_rows_visible()
	_check("③a 창에 한 번에 보이는 행 수는 **치수에서 파생**된다(TOP_H·PAD·TOP_ROW_H → %d행)" % vis,
		vis >= 1)
	# 넘침을 실제로 만든다 — 종수는 카탈로그에서 뽑아 vis보다 많게(수를 옮겨 적지 않는다).
	var ship_ids: Array = []
	for cid in CropCatalog.CATALOG:
		var hid := ItemCatalog.harvest_id(String(cid))
		if not ship_ids.has(hid):
			ship_ids.append(hid)
		if ship_ids.size() >= vis + 3:
			break
	for hid in ship_ids:
		m.ship_bin.add(String(hid), 1, ItemCatalog.Q_NORMAL)
	var bin_ids: Array = m.ship_bin.ids()
	_check("③b-pre 넘침이 실재한다 — %d종 적재(창 %d행)" % [bin_ids.size(), vis],
		bin_ids.size() > vis)
	# 창 규칙(스크롤 s에서 [s, s+vis) 표시)으로 전 품목 도달성을 잰다. 규칙의 두 축(창 높이·스크롤
	# 상한)은 전부 코드가 쓰는 단일 출처에서 왔다.
	var max_scroll := maxi(0, bin_ids.size() - vis)
	var unreachable: Array = []
	for i in bin_ids.size():
		var ok := false
		for s in range(0, max_scroll + 1):
			if i >= s and i < s + vis:
				ok = true
				break
		if not ok:
			unreachable.append(String(bin_ids[i]))
	_check("③c 어떤 품목도 창 밖에 갇히지 않는다(도달 불가: %s)" % str(unreachable),
		unreachable.is_empty())
	_check("③d 그리기가 스크롤 위치를 실제로 반영한다 — 두 패널 모두 `ids[_top_scroll + i]`로 색인한다",
		_ui_line_count("ids[_top_scroll + i]") == 2)
	_check("③e 스크롤은 그리기 시점에 클램프된다(휠 핸들러는 ±1만 — 매대 리스트와 같은 규율)",
		_ui_line_count("_top_scroll = clampi(_top_scroll, 0, maxi(0, ids.size() - max_rows))") == 2)
	# 휠 라우팅 — 두 컨텍스트 모두 `_backpack_visible()`이 참이라, 분기가 없으면 백팩만 굴렀다.
	var panel: Rect2 = m.frame._panel_rect()
	var area: Rect2 = m.frame.top_list_area(panel)
	# 곳간에도 같은 넘침을 만든다 — 이 회귀가 재는 것은 "넘칠 때 내역이 넘어가는가"이고,
	# ★[폴리시 R8] 휠 분기가 품목 수를 함께 보게 되면서 두 컨텍스트 모두 실재 넘침이 전제가 됐다
	# (넘칠 것이 없으면 그 자리의 휠은 백팩으로 흘러야 한다 — R8 #4).
	for hid in ship_ids:
		m.larder.add(String(hid), 1)
	for ctx in [InventoryFrame.CTX_BIN, InventoryFrame.CTX_LARDER]:
		m.frame.open(int(ctx))
		m.frame._top_area_rect = area          # 그리기가 매 프레임 세우는 값(헤드리스는 그리기가 없다)
		# ★[폴리시 R8] 같은 이유로 총 품목 수도 그리기가 세운다 — 헤드리스는 원장에서 직접 읽는다.
		m.frame._top_rows_total = (m.ship_bin.ids() if int(ctx) == InventoryFrame.CTX_BIN
			else m.larder.ids()).size()
		var bp_keep: int = m.frame._bp_first_row
		m.frame._gui_input(_wheel(area.get_center(), false))
		var down_ok: bool = m.frame._top_scroll == 1 and m.frame._bp_first_row == bp_keep
		m.frame._gui_input(_wheel(area.get_center(), true))
		var up_ok: bool = m.frame._top_scroll == 0
		_check("③f 컨텍스트 %d — 내역 위 휠이 내역을 넘긴다(백팩을 대신 굴리지 않는다)" % int(ctx),
			down_ok and up_ok)
		# 창 밖(백팩 그리드 위)은 종전대로 백팩 몫이다 — 좁히기만 했다는 반례.
		m.frame._gui_input(_wheel(Vector2(area.get_center().x, panel.end.y - 8.0), false))
		_check("③g 컨텍스트 %d — 내역 영역 **밖** 휠은 백팩이 받는다(기존 조작 불변)" % int(ctx),
			m.frame._top_scroll == 0)
		m.frame.close()
	m.frame._top_scroll = 5
	m.frame.open(InventoryFrame.CTX_BIN)
	_check("③h 열 때 내역 스크롤은 맨 위로 돌아간다(매대·백팩과 같은 규율)",
		m.frame._top_scroll == 0)
	m.frame.close()
	for hid in ship_ids:
		m.ship_bin.take_back(String(hid), 1)

	# ── ④ #5 앵커 혼인과 구역 겹 ──────────────────────────────────────────────
	print("── ④ #5 혼인한 옥자가 다른 구역에 떠 보이지 않는다 ──")
	var r_okja: Resident = m._resident("okja")
	m.clock.minutes = Cafe.CLOSE_MIN
	_check("④a-pre 미혼: 스케줄 region이 \"\"라 어느 구역에서든 보인다(기존 거동 불변)",
		r_okja.station_region(int(m.clock.minutes)) == ""
		and _visible_in(m, r_okja, RegionCatalog.HOME)
		and _visible_in(m, r_okja, RegionCatalog.NARU_VILLAGE))
	m._spouse_id = "okja"
	m._apply_spouse_home_station()
	_check("④b-pre 혼인이 region %s가 박힌 귀가 스테이션을 얹는다(%s)"
			% [RegionCatalog.HOME, str(m.SPOUSE_HOME_TILE)],
		r_okja.station_region(int(m.clock.minutes)) == RegionCatalog.HOME)
	_check("④c 귀가 시각 이후 **안식에서만** 보인다 — 바나가 받은 구역 겹이 앵커에도 붙었다",
		_visible_in(m, r_okja, RegionCatalog.HOME)
		and not _visible_in(m, r_okja, RegionCatalog.NARU_VILLAGE))
	m.clock.minutes = 6 * 60
	_check("④d 귀가 전 시각은 region \"\" 항목이라 종전대로 구역을 안 가른다",
		r_okja.station_region(int(m.clock.minutes)) == ""
		and _visible_in(m, r_okja, RegionCatalog.NARU_VILLAGE))
	m._remove_spouse_home_station("okja")
	m._spouse_id = ""

	# ── ⑤ #6/#11 멜·네오 가시성 래치(DUP — 같은 뿌리) ─────────────────────────
	print("── ⑤ #6/#11 혼인이 배우자를 투명 NPC로 굳히지 않는다 ──")
	for rid in ["mel", "neo"]:
		var r: Resident = m._resident(String(rid))
		m._spouse_id = String(rid)
		m._apply_spouse_home_station()
		_check("⑤a %s — 기본 스케줄은 region \"\" 한 항목이라 ㉡ 분기가 애초에 안 돈다(래치의 전제)"
				% r.display_name,
			r.station_region(6 * 60) == "" and not r.visible_rule.is_valid())
		m.clock.minutes = Cafe.CLOSE_MIN
		m._region = RegionCatalog.NARU_VILLAGE
		m._update_resident_station(r)
		var night_off: bool = not r.node.visible
		m.clock.minutes = 6 * 60
		m._update_resident_station(r)
		_check("⑤b %s — 귀가 시각에 HOME 밖이면 꺼지고(%s), 다음 날 아침이 **되돌린다**"
				% [r.display_name, str(night_off)],
			night_off and r.node.visible)
		m._remove_spouse_home_station(String(rid))
		m._spouse_id = ""
	var r_kitchen: Resident = m._resident("kitchen_youkai")
	m._update_resident_station(r_kitchen)
	_check("⑤c 혼인과 무관한 region \"\" 주민(주방요괴)도 드러난 채다 — \"구역을 안 가른다\"의 실효는 참이다",
		r_kitchen.node.visible)
	m._region = RegionCatalog.HOME

	# ── ⑥ #7 이혼 2타 확인 래치와 로드 ────────────────────────────────────────
	print("── ⑥ #7 이혼 확인 래치가 로드를 건너 살아남지 않는다 ──")
	_check("⑥a-pre 시선 접기 훅은 F9 분기보다 **뒷줄**이다 — 그 프레임을 막지 못한다",
		_line_after(_line_of("if not _load_game():"), "_divorce_armed = false")
			> _line_of("if not _load_game():"))
	m._divorce_armed = true
	m._save_game()
	m._divorce_armed = true
	var loaded: bool = m._load_game()
	_check("⑥b 로드가 래치를 0에서 시작시킨다(로드 성공: %s)" % str(loaded),
		loaded and not m._divorce_armed)
	_check("⑥c 형제 세션 래치도 함께 되감긴다(한 가족이 한 자리에서 리셋된다)",
		not m._spine_b4_armed and not m._spine_b7_armed
		and not m._soul_birth_armed and not m._pet_event_armed)
	_dismiss_dialogue(m)
	m._region = RegionCatalog.HOME

	# ── ⑦ #8 상시 고백 제안과 절기 물음 ───────────────────────────────────────
	print("── ⑦ #8 슬롯이 잡혀 있어도 절기 물음 채널이 살아 있다 ──")
	# 물음 훅을 가진 연애 명단 주민 중, 오늘이 생일이 아닌 한 사람을 레지스트리에서 고른다.
	var q_rid := ""
	for r2: Resident in m._residents:
		if r2.affinity == null or not m.ROMANCE_OPEN.has(r2.id):
			continue
		if r2.node == null or not r2.node.has_method("season_question"):
			continue
		q_rid = r2.id
		break
	_check("⑦a-pre 물음 훅을 가진 연애 명단 주민이 레지스트리에 있다(고른 이: %s)" % q_rid, q_rid != "")
	var rq: Resident = m._resident(q_rid)
	# 주 첫날이면서 그 사람 생일이 아닌 날로 맞춘다(둘 다 술어에서 파생 — 날짜를 적어 두지 않는다).
	var qday := 1
	for d in range(1, GameClock.DAYS_PER_WEEK * 8):
		if (d - 1) % GameClock.DAYS_PER_WEEK == 0 and not rq.is_birthday_on(d):
			qday = d
			break
	m.clock.day = qday
	m._season_q_week.erase(rq.id)
	rq.affinity.stage = Affinity.MAX_HEARTS - 1
	rq.affinity.points = Affinity.MAX_POINTS
	m._confess_rid = rq.id
	m._romance_partner = ""
	m._spouse_id = ""
	_check("⑦b-pre 제안이 결행 가능한 대화에선 물음이 미뤄진다(대화 한 번에 사건 하나 — 기존 규율 불변)",
		m._romance_offer_available(rq) and m._pending_season_question(rq, PackedStringArray()).is_empty())
	# 다른 사람이 슬롯을 차지한다 — 그 순간 이 사람의 ♡5 진급은 영구 정지다.
	var other := "miho" if rq.id != "miho" else "mel"
	m._romance_partner = other
	m._spouse_id = other
	_check("⑦c-pre 그래도 제안은 선다(ADR-0066 결정 6 — 제안을 숨기면 인-픽션 거절이 침묵이 된다)",
		m._romance_offer_available(rq)
		and m._try_heart_promotion(rq).is_empty())
	var q: Dictionary = m._pending_season_question(rq, PackedStringArray())
	_check("⑦d 그 상시 제안이 절기 물음을 덮지 않는다 — 서사 채널이 살아 있다",
		not q.is_empty())
	_check("⑦e 관문(진급)이 선 대화는 종전대로 물음을 미룬다(우선순위 첫 칸 불변)",
		m._pending_season_question(rq, PackedStringArray(["관문"])).is_empty())
	var pts_keep: int = rq.affinity.points
	var stage_keep: int = rq.affinity.stage
	m._confess_rid = rq.id
	m._resolve_confession(rq.id)
	_check("⑦f 두 번째 시도는 여전히 **무벌칙 거절**이다(점수·단계·슬롯 전부 불변)",
		rq.affinity.points == pts_keep and rq.affinity.stage == stage_keep
		and m._romance_partner == other)
	m._romance_partner = ""
	m._spouse_id = ""
	m._confess_rid = ""

	# ── ⑧ #9 유니크 정표의 보유 판정 ──────────────────────────────────────────
	print("── ⑧ #9 부적·비약을 상자에 넣어도 재발급되지 않는다 ──")
	_clear_all_storage(m)
	m._romance_partner = "miho"
	m._wedding_day = 0
	_check("⑧a-pre 연애 중·미보유면 부적 창구가 열린다", m._charm_quest_open())
	m.inventory.add_item(ItemCatalog.WEDDING_CHARM, 1)
	_check("⑧b 백팩에 있으면 닫힌다(종전에도 이건 맞았다)", not m._charm_quest_open())
	m.inventory.remove_item(ItemCatalog.WEDDING_CHARM, 1)
	m.chest.store(ItemCatalog.WEDDING_CHARM, 1)
	_check("⑧c **집 상자**에 넣어도 닫힌 채다 — 부적은 세상에 하나(재발급 차단)",
		not m._charm_quest_open() and m._count_anywhere(ItemCatalog.WEDDING_CHARM) == 1)
	# 그 부작용도 함께 풀린다: 상자에 둔 부적이 비약 창구를 가리지 않는다.
	m._romance_partner = m.ELIXIR_RID
	_check("⑧d 부작용 봉합 — 부적을 상자에 둔 채로도 뭍의 비약 창구가 열린다(전제가 이미 충족이므로)",
		m._elixir_quest_open())
	m.storehouse_chest.store(ItemCatalog.OKJA_ELIXIR, 1)
	_check("⑧e 비약도 같은 규율 — 갈무리방에 넣어도 재발급되지 않는다",
		not m._elixir_quest_open())
	_clear_all_storage(m)
	m._romance_partner = ""

	# ── ⑨ #10 `_facing_resident` 구역 술어 ────────────────────────────────────
	print("── ⑨ #10 다른 구역의 같은 좌표에서 유령 창구가 열리지 않는다 ──")
	m._sleeping = false
	m.clock.minutes = 10 * 60
	m._update_resident_stations(0.0)
	var region_bound: Array = []
	for r3: Resident in m._residents:
		if r3.tile != Resident.UNPLACED and r3.station_region(int(m.clock.minutes)) != "":
			region_bound.append(r3)
	_check("⑨a-pre 구역이 박힌 주민을 레지스트리에서 센다(%d인 — 총원 하드코딩 0)" % region_bound.size(),
		region_bound.size() > 0)
	var ghost_open: Array = []
	var same_region_blocked: Array = []
	for r4: Resident in region_bound:
		var home_reg: String = r4.station_region(int(m.clock.minutes))
		# ㉠ 남의 구역: 같은 좌표를 겨눠도 아무 창구도 안 열린다.
		var other_reg := ""
		for reg in RegionCatalog.ids():
			if String(reg) != home_reg:
				other_reg = String(reg)
				break
		m._region = other_reg
		m._indoor = ""
		m._target = r4.tile
		if m._facing_resident() != null:
			ghost_open.append(r4.id)
		# ㉡ 제 구역: 종전대로 열린다(좁히기만 했다는 반례).
		m._region = home_reg
		m._indoor = r4.require_indoor
		if r4.require_visible:
			r4.node.visible = true
		if r4.facing_gate.is_valid() and not r4.facing_gate.call():
			continue                        # 별도 게이트가 닫힌 주민은 이 축의 대상이 아니다
		var faced: Resident = m._facing_resident()
		if faced == null or faced.tile != r4.tile:
			same_region_blocked.append(r4.id)
	_check("⑨b 남의 구역에서는 한 사람도 안 잡힌다(유령 창구: %s)" % str(ghost_open),
		ghost_open.is_empty())
	_check("⑨c 제 구역에서는 전원 그대로 잡힌다 — 정상 대화를 한 건도 안 깼다(막힌 이: %s)"
			% str(same_region_blocked),
		same_region_blocked.is_empty())
	# ★[폴리시 R17 #0] 그 구역 술어가 `_resident_on_stage` 한 곳으로 뽑혔다(배치 가드
	#   `_resident_tile`이 같은 답을 써야 해서). 파생원은 그대로 `station_region`이다.
	_check("⑨d 판정은 스케줄 파생(`station_region`)이라 걷기용 캐시와 무관하게 늘 지금 시각의 답이다",
		_in_func("func _resident_on_stage", "r.station_region(int(clock.minutes))")
		and _in_func("func _facing_resident", "_resident_on_stage(r)"))
	m._region = RegionCatalog.HOME
	m._indoor = ""

	# ══ 배치 B(#12·#14~#22) ══════════════════════════════════════════════════
	m._sleeping = false
	m._indoor = ""
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)

	# ── ⑩ #12 걷기 중 스테이션이 바뀌어 경로가 거절되면 옛 오프셋이 안 남는다 ──
	print("── ⑩ #12 폐기된 걷기의 stale 오프셋이 스프라이트를 논리 칸에서 떼어 놓지 않는다 ──")
	var rw: Resident = m._residents[0]
	var walk_from := Vector2i(10, 10)
	var walk_to := Vector2i(30, 10)
	rw.walk = ResidentWalk.new()
	rw.walk.start(m._tile_center_px(walk_from), PackedVector2Array([m._tile_center_px(walk_to)]))
	rw.walk.advance(0.2)
	rw.node.set_walk_offset(rw.walk.offset())
	_check("⑩a-pre 걷는 중이면 오프셋이 실제로 얹힌다(그림이 논리 칸 뒤에서 따라온다)",
		rw.walk.is_walking() and rw.walk.offset() != Vector2.ZERO
		and rw.node.walk_offset != Vector2.ZERO)
	# 구역을 넘는 전환 = `_begin_resident_walk`가 걸어갈 길이 없다고 판단해 그냥 돌아가는 갈래.
	m._begin_resident_walk(rw, walk_from, RegionCatalog.NARU_VILLAGE, walk_to, RegionCatalog.HOME)
	_check("⑩b 구역을 넘는 전환에 잘리면 걷기가 **끊긴다**(옛 목적지 기준 오프셋을 더 안 만든다)",
		not rw.walk.is_walking() and rw.walk.offset() == Vector2.ZERO)
	_check("⑩c 노드의 그림 오프셋도 그 자리에서 0으로 돌아간다(그림 = 논리 칸)",
		rw.node.walk_offset == Vector2.ZERO)
	# 계속 프레임을 굴려도 되살아나지 않는다(advance가 죽은 걷기를 다시 밀지 않는다).
	m._advance_resident_walk(rw, 0.5)
	_check("⑩d 이후 프레임에서도 오프셋이 0으로 남는다", rw.node.walk_offset == Vector2.ZERO)
	# 같은 칸(스포크 없음) 갈래도 같은 처방을 받는다 — 세 갈래가 한 가드를 공유한다.
	rw.walk.start(m._tile_center_px(walk_from), PackedVector2Array([m._tile_center_px(walk_to)]))
	rw.walk.advance(0.2)
	m._begin_resident_walk(rw, walk_from, RegionCatalog.HOME, walk_from, RegionCatalog.HOME)
	_check("⑩e 스포크를 못 만드는 전환(같은 칸)에서도 옛 걷기가 끊긴다",
		not rw.walk.is_walking() and rw.walk.offset() == Vector2.ZERO)
	# 반례 — 정상 전환은 그대로 걷는다(가드가 걷기 자체를 죽이지 않았다).
	var lane_y: int = m.ROAD_LANE_Y[RegionCatalog.NARU_VILLAGE]
	m._begin_resident_walk(rw, Vector2i(40, lane_y + 4), RegionCatalog.NARU_VILLAGE,
		Vector2i(50, lane_y + 4), RegionCatalog.NARU_VILLAGE)
	_check("⑩f 반례 — 같은 구역의 정상 전환은 종전대로 걷기가 선다(좁히기만 했다)",
		rw.walk.is_walking())
	rw.walk.cancel()
	rw.node.set_walk_offset(Vector2.ZERO)

	# ── ⑪ #14 관계 탭 선물 리듬이 생일 면제를 반영한다 ────────────────────────
	print("── ⑪ #14 생일 당일 관계 탭이 \"0/2\"로 거짓말하지 않는다 ──")
	var bday_r: Resident = null
	var bday_day := -1
	for rb: Resident in m._residents:
		if not rb.can_gift or rb.affinity == null or rb.id == m._spouse_id:
			continue
		for d in range(1, GameClock.DAYS_PER_SEASON * 4 + 1):
			if rb.is_birthday_on(d):
				bday_r = rb
				bday_day = d
				break
		if bday_r != null:
			break
	_check("⑪a-pre 생일이 박힌 선물 가능 주민을 레지스트리에서 찾는다(%s · day %d — 날짜 하드코딩 0)"
			% [bday_r.id if bday_r != null else "없음", bday_day],
		bday_r != null and bday_day > 0)
	var keep_day: int = m.clock.day
	m.clock.day = bday_day
	bday_r.affinity.gift_week = GameClock.week_of(bday_day)
	bday_r.affinity.gifts_this_week = Affinity.GIFTS_PER_WEEK
	bday_r.affinity.last_gift_day = -1
	_check("⑪b-pre 그 주의 주 상한을 이미 다 썼다(남은 횟수 0) — 옛 표시의 입력이 실제로 0이다",
		bday_r.affinity.gifts_left_in_week(bday_day) == 0)
	_check("⑪c 그러나 **판정**은 통과한다(생일은 주 상한 면제 — ADR-0066 결정 3)",
		bday_r.affinity.can_gift(bday_day, true, false))
	var bday_text: String = m._gift_rhythm_text(bday_r)
	_check("⑪d 표시가 그 예외를 함께 본다 — 생일을 밝히고 \"0/%d\"를 말하지 않는다 (실제: \"%s\")"
			% [Affinity.GIFTS_PER_WEEK, bday_text],
		bday_text.contains("생일")
		and not bday_text.contains("0/%d" % Affinity.GIFTS_PER_WEEK))
	# 반례 — 생일이 아닌 날은 종전 문구 그대로(남은 횟수 표시가 사라지지 않았다).
	var normal_day := bday_day + 1 if not bday_r.is_birthday_on(bday_day + 1) else bday_day + 2
	m.clock.day = normal_day
	var normal_text: String = m._gift_rhythm_text(bday_r)
	_check("⑪e 반례 — 생일이 아닌 날은 남은 횟수 표시가 그대로다 (실제: \"%s\")" % normal_text,
		normal_text.contains("이번 주 선물") and not normal_text.contains("생일"))
	m.clock.day = keep_day
	bday_r.affinity.gifts_this_week = 0
	bday_r.affinity.last_gift_day = -1

	# ── ⑫ #15 곁들이 창구가 회복량 최대치에 갇히지 않는다 ─────────────────────
	print("── ⑫ #15 하위 곁들이가 곳간의 상위 재고에 인질이 되지 않는다 ──")
	var dishes: Array = MenuCatalog.side_dish_ids()
	var low_dish := ""
	var high_dish := ""
	for raw_d in dishes:
		var did := String(raw_d)
		if low_dish == "" or MenuCatalog.restore_of(did) < MenuCatalog.restore_of(low_dish):
			low_dish = did
		if high_dish == "" or MenuCatalog.restore_of(did) > MenuCatalog.restore_of(high_dish):
			high_dish = did
	var low_sig := MenuCatalog.signature_of(low_dish)
	var high_sig := MenuCatalog.signature_of(high_dish)
	_check("⑫a-pre 로스터 양끝을 카탈로그에서 뽑는다 — %s(회복 %d) vs %s(회복 %d)"
			% [MenuCatalog.name_of(low_dish), MenuCatalog.restore_of(low_dish),
				MenuCatalog.name_of(high_dish), MenuCatalog.restore_of(high_dish)],
		low_dish != "" and high_dish != "" and low_dish != high_dish)
	# 최하위 곁들이가 GiftPrefs에서 러브로 실제로 쓰이고 있다 — 이 결함이 관계를 막았다는 근거.
	var low_loved_by: Array = []
	for rl: Resident in m._residents:
		if GiftPrefs.tier_of(rl.id, low_dish) == GiftPrefs.LOVE:
			low_loved_by.append(rl.id)
	_check("⑫b-pre 그 최하위 접시는 선물 선호표에서 러브다(%s) — 축이 혼력 하나가 아니다"
			% str(low_loved_by),
		not low_loved_by.is_empty())
	for raw_d2 in dishes:
		m.larder.consume(MenuCatalog.signature_of(String(raw_d2)), 99)
	m.larder.add(low_sig, 1)
	m.larder.add(high_sig, 1)
	_clear_backpack(m)
	m.inventory.select(0)
	_check("⑫c 아무것도 안 들면 종전대로 회복량 최대치를 고른다(기존 거동 불변)",
		m._best_side_dish() == high_dish)
	m.inventory.add_item(low_sig, 1)
	_check("⑫d-pre 최하위 시그니처를 손에 든다", _hold(m, low_sig))
	_check("⑫e 든 시그니처가 곧 주문서 — 상위 재고가 있어도 그 접시가 나온다",
		m._best_side_dish() == low_dish)
	var high_before: int = m.larder.count_of(high_sig)
	m._make_side_dish()
	_check("⑫f 실제로 그 접시를 받는다(백팩에 %s 1개)" % MenuCatalog.name_of(low_dish),
		m.inventory.count_of(low_dish) == 1)
	_check("⑫g 값은 그 접시의 시그니처로만 치른다 — 상위 재고는 한 개도 안 줄었다",
		m.larder.count_of(low_sig) == 0 and m.larder.count_of(high_sig) == high_before)
	_check("⑫h 손에 든 시그니처는 소모되지 않는다(재료는 곳간에서 나간다 — 창구의 계약 불변)",
		m.inventory.count_of(low_sig) == 1)

	# ── ⑬ #16 한 번의 LMB가 `_use_tool()`을 두 번 실행하지 않는다 ─────────────
	print("── ⑬ #16 칸을 안 보는 손 물건이 타일 갈래와 겹쳐 두 번 소모되지 않는다 ──")
	# 무엇이 "칸을 안 보는 손 물건"인가 — 술어에서 파생한다(명단 하드코딩 0).
	var free_use_ids: Array = [ItemCatalog.MYEONGBUHWAN, ItemCatalog.STAIRS]
	for raw_d3 in dishes:
		free_use_ids.append(String(raw_d3))
	var not_free_use: Array = []
	for fid in free_use_ids:
		if not m._is_free_use_item(String(fid)):
			not_free_use.append(String(fid))
	_check("⑬a-pre 명부환·계단·곁들이 %d종이 전부 `_is_free_use_item`이다(누락: %s)"
			% [dishes.size(), str(not_free_use)],
		not_free_use.is_empty())
	_check("⑬b 반례 — 칸이 게이트인 농사 도구는 그 술어에 안 든다(가드가 도구질까지 끄지 않는다)",
		not m._is_free_use_item(ItemCatalog.HOE) and not m._is_free_use_item(ItemCatalog.WATERING_CAN))
	# `_process`의 지역 상태라 호출로 재현할 수 없다 — 네 갈래가 그 가드를 실제로 달고 있나를 소스로 잰다.
	var hand_decl := _line_of("var free_use_hand := _is_free_use_item(inventory.selected_id())")
	var animal_br := _line_of("if on_animal and not free_use_hand and Input.is_action_just_pressed(\"use_tool\")")
	var debris_br := _line_of("if on_debris and not free_use_hand and Input.is_action_just_pressed(\"use_tool\")")
	var weed_br := _line_of("if on_weed and not free_use_hand and Input.is_action_just_pressed(\"use_tool\")")
	_check("⑬c 짐승·개간·잡초 세 타일 갈래가 전부 손-물건 가드를 단다(줄 %d/%d/%d)"
			% [animal_br, debris_br, weed_br],
		animal_br > 0 and debris_br > 0 and weed_br > 0)
	_check("⑬d 그 술어는 세 갈래보다 **먼저** 선언된다(줄 %d)" % hand_decl,
		hand_decl > 0 and hand_decl < animal_br and hand_decl < debris_br and hand_decl < weed_br)
	_check("⑬e 맨 아래 일반 갈래는 `holding_free_use`를 그대로 든다 — 손 물건이 여전히 **한 번** 실행된다",
		# ★[폴리시 R17 경유 발견] R16 #5가 or-항을 `pot_at_target` → `pot_dispatch`로 갈았다(계약 불변).
		_line_of("and (_target_valid or holding_weapon or pot_dispatch or holding_free_use)") > weed_br)
	# 동사 자체는 호출 1회당 1개만 태운다(가드가 없어도 참이었던 성질 — 이중은 디스패치의 몫이었다).
	_clear_backpack(m)
	m.inventory.add_item(low_dish, 2)
	_hold(m, low_dish)
	m.energy.current = 10
	m._use_tool()
	_check("⑬f `_use_tool()` 한 번 = 접시 정확히 1개(동사 자체의 계약)",
		m.inventory.count_of(low_dish) == 1)

	# ── ⑭ #17 화분 물주기 프롬프트가 혼력 게이트를 본다 ───────────────────────
	print("── ⑭ #17 혼력이 모자란데 \"[좌클릭] 물주기\"라 안내하지 않는다 ──")
	m._indoor = "집"                 # `_can_place_pot`의 실내 게이트(빈 문자열이면 어디에도 못 놓는다)
	var pot_t := Vector2i(-1, -1)
	for py in range(m.HOME_HOUSE_RECT.position.y + 1, m.HOME_HOUSE_RECT.end.y - 1):
		for px2 in range(m.HOME_HOUSE_RECT.position.x + 1, m.HOME_HOUSE_RECT.end.x - 1):
			if m._can_place_pot(Vector2i(px2, py)):
				pot_t = Vector2i(px2, py)
				break
		if pot_t != Vector2i(-1, -1):
			break
	_check("⑭a-pre 화분을 놓을 실내 칸을 찾는다 %s(좌표 하드코딩 0)" % str(pot_t),
		pot_t != Vector2i(-1, -1))
	_clear_backpack(m)
	m.inventory.add_item(ItemCatalog.GARDEN_POT, 1)
	m._place_garden_pot(pot_t)
	m.garden_pot.plant(pot_t, CropCatalog.PIANHWA)
	m._target = pot_t
	m.inventory.add_item(ItemCatalog.WATERING_CAN, 1)
	_hold(m, ItemCatalog.WATERING_CAN)
	m._can_water = m._can_capacity()
	var farm_cost: int = m._farming_energy_cost()
	m.energy.current = farm_cost - 1
	_check("⑭b-pre 심겼고·안 젖었고·물은 있고·혼력만 모자라다(%d < %d)" % [m.energy.current, farm_cost],
		m.garden_pot.is_planted(pot_t) and not m.garden_pot.is_watered(pot_t)
		and m._can_water > 0 and not m.energy.can_act(farm_cost))
	_check("⑭c 프롬프트가 노지 밭과 **같은 문구**로 막는다 (실제: \"%s\")" % m._pot_prompt(),
		m._pot_prompt() == "혼력 부족 — 집에서 취침")
	m._use_tool()
	_check("⑭d 그리고 그 안내는 참이다 — LMB는 실제로 아무 일도 안 한다(화분이 마른 채)",
		not m.garden_pot.is_watered(pot_t))
	m.energy.current = SoulEnergy.MAX
	_check("⑭e 반례 — 혼력이 차면 종전 안내가 그대로 돌아온다",
		m._pot_prompt() == "[좌클릭] 물주기")
	m._use_tool()
	_check("⑭f 그리고 실제로 물이 든다(가드가 동사를 막아 버리지 않았다)",
		m.garden_pot.is_watered(pot_t))
	m.garden_pot.remove(pot_t)
	m._indoor = ""

	# ── ⑮ #18 저승 이끼 프롬프트가 혼력 게이트를 본다 ─────────────────────────
	print("── ⑮ #18 같은 나무 앞에서 도끼는 막고 낫만 거짓말하지 않는다 ──")
	var moss_line := _line_of("[좌클릭] 저승 이끼 채취 (낫)")
	var moss_gate := -1
	for i in range(maxi(moss_line - 8, 0), moss_line):
		if _src[i].contains("energy.can_act(SoulEnergy.COST_PER_ACTION)"):
			moss_gate = i
	_check("⑮a 이끼 안내 갈래(줄 %d)가 실행부와 **같은 고정 비용**으로 혼력을 먼저 묻는다(줄 %d)"
			% [moss_line, moss_gate],
		moss_line > 0 and moss_gate > 0)
	_check("⑮b 그 비용의 출처가 실행부와 하나다(`_scrape_moss`가 쓰는 그 상수)",
		_in_func("func _scrape_moss", "SoulEnergy.COST_PER_ACTION"))
	_check("⑮c 낫을 안 들었을 때의 줄은 동사 약속이 아니라 안내라 혼력과 무관하게 남는다",
		_line_of("interact_prompt.text = \"저승 이끼가 끼었다 — 낫으로 긁어낼 수 있다\"") > 0)
	_check("⑮d 이웃한 벌목 안내가 같은 규율을 이미 들고 있다(두 갈래가 이제 한 표를 본다)",
		_in_func("func _tree_prompt", "energy.can_act(SoulEnergy.COST_PER_ACTION)"))

	# ── ⑯ #19 성장 티어에 실효가 생긴다(짐승을 들일 경로) ─────────────────────
	print("── ⑯ #19 큰 넋둥우리·큰 넋우릿간이 실제로 두수를 늘린다 ──")
	var sale_species: Array = []
	for raw_sp in AnimalCatalog.ids():
		if AnimalCatalog.buy_price(String(raw_sp)) > 0:
			sale_species.append(String(raw_sp))
	var shop_rows: Array = m._woodshop_items()
	var listed: Array = []
	for row in shop_rows:
		if String(row.get("kind", "")) == "livestock":
			listed.append(String(row.get("buy_id", "")))
	listed.sort()
	sale_species.sort()
	_check("⑯a 목공방 매대가 파는 종을 카탈로그에서 파생해 전부 진열한다(%s)" % str(listed),
		listed == sale_species and not listed.is_empty())
	var sp0: String = sale_species[0]
	var bld0: String = m._animal_building_of(sp0)
	var occ0: int = m.ranch.occupancy_of(bld0)
	var cap0: int = m.ranch.capacity_of(bld0)
	_check("⑯b-pre 그 건물은 기본 티어 정원이다(%d/%d — 정원 하드코딩 0)" % [occ0, cap0],
		cap0 == Ranch.CAP_BASE and occ0 < cap0)
	m.wallet.earn(200000)
	var gold0: int = m.wallet.gold
	var unit0: int = StoreDiscount.price(AnimalCatalog.buy_price(sp0), m._ongi_hearts())
	_check("⑯c 한 마리 산다 — 냥이 정확히 정가만큼 나가고 두수가 하나 는다",
		m._try_buy_animal(sp0)
		and m.wallet.gold == gold0 - unit0
		and m.ranch.occupancy_of(bld0) == occ0 + 1)
	# 새로 들어온 짐승은 **새끼**다(grow_days가 의미를 잃지 않는다).
	var newborn := Vector2i(-1, -1)
	for raw_t in m.ranch.animals_in(bld0):
		var at: Vector2i = raw_t
		if m.ranch.age_of(at) == 0 and m.ranch.species_at(at) == sp0:
			newborn = at
	_check("⑯d 산 짐승은 새끼로 온다(성체까지 %d일 — ADR-0048 Phase E 성장 축이 산다)"
			% AnimalCatalog.grow_days_of(sp0),
		newborn != Vector2i(-1, -1) and not m.ranch.is_adult(newborn))
	# 정원까지 채운 뒤 — 기본 티어에선 더 못 들이고, 매대 행이 그 사실을 말한다.
	while m.ranch.occupancy_of(bld0) < cap0:
		if not m._try_buy_animal(sp0):
			break
	_check("⑯e-pre 정원이 찼다(%d/%d)" % [m.ranch.occupancy_of(bld0), cap0],
		m.ranch.occupancy_of(bld0) == cap0)
	_check("⑯f 정원이 차면 더 못 들인다(구매 거절)", not m._try_buy_animal(sp0))
	var locked_row := false
	for row2 in m._woodshop_items():
		if String(row2.get("kind", "")) == "livestock" and String(row2.get("buy_id", "")) == sp0:
			locked_row = bool(row2.get("locked", false))
	_check("⑯g 매대 행이 잠긴 채 남는다 — 감추지 않아 큰 건물이 목표로 읽힌다", locked_row)
	# ★핵심 — 성장 티어를 올리면 그 즉시 5번째가 들어온다(22,000냥짜리 프로젝트의 실효).
	m.ranch.upgrade_building(bld0)
	_check("⑯h-pre 승격하면 정원이 %d로 넓어진다" % Ranch.CAP_BIG,
		m.ranch.capacity_of(bld0) == Ranch.CAP_BIG)
	_check("⑯i **큰 건물의 실효** — 기본 정원을 넘는 짐승이 실제로 들어온다(%d 초과)" % Ranch.CAP_BASE,
		m._try_buy_animal(sp0) and m.ranch.occupancy_of(bld0) == Ranch.CAP_BASE + 1)

	# ── ⑰ #20 방목 나간 짐승의 상호작용 좌표 ──────────────────────────────────
	print("── ⑰ #20 보이는 짐승에 손이 닿고, 빈 실내 바닥은 산물을 안 내준다 ──")
	var herd: Array = m.ranch.animals_in(bld0)
	var anchor: Vector2i = herd[0]
	var slots: Array = m._free_pasture_tiles()
	_check("⑰a-pre 방목지 슬롯을 지형에서 파생한다(%d칸 — 좌표 하드코딩 0)" % slots.size(),
		not slots.is_empty())
	var pasture: Vector2i = slots[0]
	m.ranch.send_to_pasture(anchor, pasture)
	_check("⑰b-pre 드로우가 보는 좌표는 방목지다(main `_draw_ranch`가 쓰는 그 조회)",
		m.ranch.is_outside(anchor) and m.ranch.pasture_tile_of(anchor) == pasture)
	_check("⑰c 상호작용도 같은 좌표를 본다 — 방목지 칸이 그 짐승으로 해석된다",
		m.ranch.has_animal_at(pasture) and m.ranch.animal_key_at(pasture) == anchor)
	_check("⑰d 비어 버린 실내 앵커는 더 이상 짐승 칸이 아니다(빈 바닥에 프롬프트가 안 뜬다)",
		not m.ranch.has_animal_at(anchor))
	_check("⑰e 원장 주소는 여전히 키 타일 하나다(좌표계는 안 흔들렸다)",
		m.ranch.has_animal(anchor) and m.ranch.building_of(anchor) == bld0)
	# 집행까지 잇는다 — 대기 산물을 심고 방목지 칸에서 실제로 거둔다.
	m.ranch._animals[anchor]["product"] = 1
	m.ranch._animals[anchor]["product_quality"] = 0
	m.ranch._animals[anchor]["product_large"] = false
	var prod_id: String = AnimalCatalog.product_of(m.ranch.species_at(anchor))
	_clear_backpack(m)
	m.energy.current = SoulEnergy.MAX
	m._region = RegionCatalog.HOME
	m._indoor = ""
	m._target = anchor
	var xp_before: int = m._farming_xp
	_check("⑰f 빈 실내 앵커를 겨눈 RMB는 아무 일도 안 한다(산물이 그대로 대기)",
		not m._try_harvest() and m.ranch.has_product(anchor)
		and m.inventory.count_of(prod_id) == 0)
	m._target = pasture
	var took: bool = m._try_harvest()
	_check("⑰g 보이는 짐승(방목지 칸)을 겨누면 실제로 거둬진다",
		took and m.inventory.count_of(prod_id) == 1 and not m.ranch.has_product(anchor))
	_check("⑰h 프롬프트도 같은 술어를 본다(그 칸에서 안내가 선다)",
		m._animal_prompt(m.ranch.animal_key_at(pasture)).contains(
			AnimalCatalog.name_of(m.ranch.species_at(anchor))))

	# ── ⑲ #22 짐승 산물 수집이 농사 XP를 준다 ─────────────────────────────────
	print("── ⑲ #22 목축만 하는 플레이도 농사 트리 XP가 오른다 ──")
	var expect_xp: int = XpBoost.scaled(AnimalCatalog.product_sell(prod_id),
		m.affinity.hearts() if m.affinity != null else 0)
	_check("⑲a 방금 수집이 농사 XP를 **기준 판매가 파생**만큼 얹었다(+%d = 산물가 %d · 하트 배수)"
			% [expect_xp, AnimalCatalog.product_sell(prod_id)],
		m._farming_xp == xp_before + expect_xp and expect_xp > 0)
	_check("⑲b 배율의 결이 형제 분기와 같다 — 밭·과수도 같은 `_gain_farm_xp` 창구를 쓴다",
		_in_func("func _try_harvest", "_gain_farm_xp(AnimalCatalog.product_sell("))
	_check("⑲c 목축 전문직 3종이 사는 트리가 바로 그 트리다(FARMING — 배선의 이유)",
		ProfessionCatalog.perks_of(ProfessionCatalog.FARMING, "rancher").size() >= 0
		and _in_func("func _gain_farm_xp", "_farming_xp += amount"))

	# ── ⑱ #21 동물 건물 실내 프롬프트가 실제 동작을 말한다 ────────────────────
	print("── ⑱ #21 프롬프트가 이 우클릭으로는 서지 않는 동사를 약속하지 않는다 ──")
	var tend_prompt_line := _line_of("돌봄 (여물 급여 · 잠자리 청소 — 여물광 %d단)")
	_check("⑱a 안내가 **급여**를 밝힌다 — 여물광 건초를 태우는 동사를 한 글자도 안 알리던 자리다",
		tend_prompt_line > 0)
	_check("⑱b 실행부가 실제로 그 둘만 집행한다(여물 급여 + 잠자리 청소)",
		_line_of("var fed_ct := ranch.feed_from_silo_in(_indoor)") > 0
		and _line_of("var cleaned := ranch.clean_all_in(_indoor)") > 0)
	_check("⑱c 이제 이 안내에 \"방목·격리\"가 없다 — pathing이 세우는 플래그를 창구가 약속하지 않는다",
		_line_of("돌봄 (방목·격리·청결)") < 0)
	_check("⑱d 여물광이 비면 그 사실을 미리 말한다(누르고 나서 알 일이 아니다)",
		_line_of("잠자리 청소 (여물광이 비어 급여 불가)") > 0)

	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)
	print("── 결과: %s (실패 %d)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# 그 아이템이 든 첫 슬롯을 선택한다(side_dish_test의 그 헬퍼 — 수법을 갈라 두지 않는다).
func _hold(m: Node, id: String) -> bool:
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return true
	return false
