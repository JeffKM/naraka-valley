extends SceneTree
# ★[폴리시 6회차 · 배치 A] 버그 헌트 확정분 회귀 — 늘봄방 매장 클러스터 · 로드 편도 · 첫날 구멍.
#
# polish_r5_test가 "완공이 예정지를 덮기 전에 걷는다"를 세웠다면, 여기는 **그 걷기가 물건을 잃지
# 않는가 · 그 자리에 서 있던 사람은 어떻게 되는가 · 못 걷었을 때 다시 걷을 기회가 있는가**를 잰다.
#
# 무엇을 보증하나(발견 번호 = 6회차 헌트 배치 A):
#   ① #7  손상·버전불일치 세이브 [이어하기] — 파일 존재(has_save)와 읽힘(can_load)이 갈리는 슬롯을
#         고르면, 종전엔 **조용히 반쪽 새 게임**(스타터 짐승 0·꾸미기 세트 0)으로 떨어졌다.
#         이제는 사실을 알리고 신규 셋업을 온전히 태운다(세이브 파일은 안 건드린다).
#   ② #8  신규 게임 첫날 — 숲 채집물·사금 스폿의 일일 롤이 `_on_day_advanced`에만 걸려 있어 day 1이
#         통째로 비어 있었다. 이제 신규 가지가 그날치를 굴린다(**결정적**이라 새 원장으로 재현해 대조).
#   ③ #9  온보딩 GROW 안내의 집 방향 — 좌표에서 파생해 본다(문구가 아니라 배치가 근거다).
#   ④ #2/#19 보관처 만재 회수 — 원장 삭제가 적재보다 먼저라 걷힌 레어크로우가 **어디에도 없이**
#         사라지던 자리. 이제 적재 먼저·차감 나중이고, 못 넣으면 그 자리에 남긴 뒤 알리고 다음
#         아침이 다시 걷는다(레어크로우 재획득 창구는 전부 1회성 = 잃으면 8종 완주가 영구히 깨진다).
#   ⑤ #3  예정지 나무 — R5 가드는 `orchard`만 봤고 마당 **자연목**(tree_ledger)은 자체 파종·발주
#         게이트 양쪽에서 통과했다. 파종 차단 · 발주 차단 · 완공 정리 세 자리를 함께 잰다.
#   ⑥ #5  완공 아침 매몰 — 예정지 위에서 눈뜨면 WALL 56칸 안이었다(탈출 경로 0 · 자동 저장이
#         그 좌표를 굳혀 F9도 같은 자리). 완공 퇴거 + 막힌 복원 좌표 구제 두 겹으로 막는다.
#   ⑦ #4  카페 하루치 원장 — `data.has` 가드라 키 없는 세이브 로드에서 **직전 세션 값이 잔류**했다
#         (리셋 책임이 `_open_shop`에서 `_ledger_day` 비교로 옮겨간 뒤 뜻이 뒤집힌 자리).
#   ⑧ #6  B7 해방 도중 종료 — 비트를 장면 *시작*에 찍어 자동 저장이 그것을 굳혔고, 대사·에필로그는
#         비영속이라 재기동 시 `_maybe_resume_spine`의 두 갈래가 모두 거짓이 됐다. 비트를 장면
#         *끝*(에필로그가 열리는 자리)으로 옮겨 끊긴 재생이 ㉡로 돌아온다.
#   ⑨ #1  **REFUTED 근거 잠금** — "로드마다 회수가 다시 돌아 무한 복제"는 성립하지 않는다:
#         적재처(백팩·두 상자)가 회수보다 **먼저** 파일에서 되감기므로 한 번의 로드가 만드는 상태는
#         파일에 대해 결정적이다. 그 순서가 곧 무해함의 근거라, 순서 자체를 소스에서 못 박는다.
#
# ★ `_process`·훅 안의 지역 상태는 함수 호출로 재현할 수 없다 — 그 줄이 실제로 그 가드를 달고
#   있나를 main 소스에서 줄 단위로 대조한다(polish_r4_test ④ · peddler_test ⑫와 같은 관례).
# ★ 좌표·분모·로스터는 전부 main 상수/레지스트리에서 파생한다(하드코딩 0).
#
# 실행: ./run_tests.sh polish_r6   (헤드리스는 반드시 game/에서 · 순차)

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

# main.gd 소스에서 needle이 든 줄의 인덱스(-1 = 없음).
func _line_of(needle: String) -> int:
	return _line_after(0, needle)

# start 이후 첫 매치 — 같은 호출이 여러 훅에 흩어져 있을 때(들여쓰기만 다른 같은 줄) 함수 머리부터
# 세기 위해 쓴다. `contains`는 부분 일치라 3탭 줄이 1탭 니들에도 걸리기 때문이다.
func _line_after(start: int, needle: String) -> int:
	for i in range(maxi(start, 0), _src.size()):
		if _src[i].contains(needle):
			return i
	return -1

# 알림 피드에 이 문구가 떠 있는가(플레이어가 실제로 들었는가 — 조용한 진행 금지의 계측).
func _notice_has(m: Node, needle: String) -> bool:
	if m.notice_feed == null:
		return false
	for e in m.notice_feed._items:
		if String(e.get("text", "")).contains(needle):
			return true
	return false

func _clear_notices(m: Node) -> void:
	if m.notice_feed != null:
		m.notice_feed._items.clear()

# ★[폴리시 R2 공용] 백팩을 **빈 슬롯 0**으로 채운다(polish_r5_test의 그 헬퍼 그대로 — 수법을
#   갈라 두면 여기서만 다르게 새는 자리가 생긴다). 풀 = 유품·책이라 합류할 스택이 하나도 없다.
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

# 상자를 빈 슬롯 0으로 채운다(회수 사다리의 2·3단을 막는다). 백팩과 같은 이유로 서로 다른 종만 쓴다.
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

func _wipe_slot(slot: int) -> void:
	var p := SaveManager.slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _initialize() -> void:
	print("══ 폴리시 6회차 배치 A — 늘봄방 매장 클러스터 · 로드 편도 · 첫날 구멍 ══")
	_src = FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().split("\n")
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)

	# ── ① #7 손상 세이브로 [이어하기] ─────────────────────────────────────────
	# main이 부팅에서 `_begin_game(false)`를 타므로, **띄우기 전에** 슬롯 0에 안 읽히는 파일을
	# 심어 두면 그 갈림길이 실제로 재현된다(잘린 save.dat = str_to_var 실패).
	print("── ① #7 파일은 있는데 안 읽히는 슬롯 = 반쪽 새 게임이 아니다 ──")
	var broken := FileAccess.open(SaveManager.slot_path(0), FileAccess.WRITE)
	broken.store_string("{ \"version\": 1, \"data\": { \"day\":")   # 저장 중 끊긴 파일
	broken.close()
	var saver0 := SaveManager.new()
	_check("①a 두 술어가 실제로 갈린다 — has_save는 참인데 can_load는 거짓(이 차이를 아무도 안 물었다)",
		saver0.has_save(0) and not saver0.can_load(0))
	_check("①b 버전 불일치도 같은 쪽으로 떨어진다(VERSION을 올린 뒤의 구세이브 전량)",
		not saver0.can_load(0) and SaveManager.VERSION == 1)
	var mb := await _spawn_main()
	_dismiss_dialogue(mb)
	_check("①c 손상 슬롯으로 부팅해도 **스타터 짐승이 깔린다** — 넋우릿간·넋둥우리가 비지 않는다(%d마리)"
			% mb.ranch.count(), mb.ranch.count() > 0)
	var deco_missing: Array = []
	for sid in HomeDecoCatalog.STARTER_SETS:
		if not mb.home_deco.is_unlocked(String(sid)):
			deco_missing.append(String(sid))
	_check("①d 스타터 꾸미기 세트도 전부 해금된다 — %s(미해금: %s)"
			% [str(HomeDecoCatalog.STARTER_SETS), str(deco_missing)], deco_missing.is_empty())
	_check("①e 그리고 **조용히 지나가지 않는다** — 못 읽었다는 사실이 화면에 뜬다",
		_notice_has(mb, "세이브를 읽지 못했다"))
	_check("①f 손상 파일을 지우거나 덮어쓰지 않는다(복구 시도의 여지를 남긴다)",
		FileAccess.file_exists(SaveManager.slot_path(0)))
	_check("①g F9 실패도 말한다 — `_load_game`이 성패를 돌려주고 호출부가 그것을 본다",
		_line_of("if not _load_game():") >= 0 and not mb._load_game())
	mb.free()
	saver0.free()
	_wipe_slot(0)

	# ── 본 세션: 깨끗한 신규 게임 ────────────────────────────────────────────
	var m := await _spawn_main()
	_dismiss_dialogue(m)

	# ── ② #8 신규 게임 첫날의 채집·팬닝 ──────────────────────────────────────
	print("── ② #8 첫날에도 숲 채집물·사금 스폿이 있다 ──")
	var d1: int = m.clock.day
	# 대조군을 **새 원장으로 다시 굴려** 만든다 — 기대값을 적어 두지 않는다(두 롤은 day 시드라 결정적).
	var ref_forage := ForageSpawns.new()
	ref_forage.advance_day(d1, GameClock.season_index_for_day(d1))
	var ref_pan := PanningSpots.new()
	ref_pan.advance_day(d1)
	var forage_diff: Array = []
	for region in ForageSpawns.spawn_regions():
		var live: Array = m.forage_spawns.tiles(String(region))
		var want: Array = ref_forage.tiles(String(region))
		live.sort(); want.sort()
		if live != want:
			forage_diff.append(String(region))
	_check("②a 첫날 숲 채집물이 **그날 롤 그대로** 서 있다 — 구역별 좌표가 대조 원장과 일치(어긋남: %s)"
			% str(forage_diff), forage_diff.is_empty() and ref_forage.total() > 0
			and m.forage_spawns.total() == ref_forage.total())
	var pan_diff: Array = []
	for region in PanningSpots.spawn_regions():
		var live_p: Array = m.panning.tiles(String(region))
		var want_p: Array = ref_pan.tiles(String(region))
		live_p.sort(); want_p.sort()
		if live_p != want_p:
			pan_diff.append(String(region))
	_check("②b 사금 스폿도 같다 — 삼도천·황천해 좌표가 대조 원장과 일치(어긋남: %s)" % str(pan_diff),
		pan_diff.is_empty())
	_check("②c 그 롤은 **신규 가지 안에서만** 돈다 — 로드 경로가 같은 날을 다시 굴리면 이미 줍거나 인 자리가 되살아난다",
		_line_of("\t\tif forage_spawns != null:") > _line_of("\t\tfor sid in HomeDecoCatalog.STARTER_SETS:")
		and _line_of("\t\t\tpanning.advance_day(clock.day)") > 0)

	# ── ③ #9 온보딩 GROW 안내의 방향 ─────────────────────────────────────────
	print("── ③ #9 집은 밭의 위쪽이다(왼쪽은 창고) ──")
	var patch: Rect2i = m.STARTER_PATCH_RECT
	var door: Vector2i = m.HOUSE_EXT_DOOR
	var store_rect: Rect2i = m.STOREHOUSE_EXT_RECT
	_check("③a 좌표가 근거다 — 본가 문 %s는 스타터 밭 %s의 **북쪽**이고 x는 밭 폭 안이다"
			% [str(door), str(patch)],
		door.y < patch.position.y and door.x >= patch.position.x and door.x <= patch.end.x)
	_check("③b 밭의 서쪽에 있는 건 창고다(%s) — 잠들 수 없는 건물" % str(store_rect),
		store_rect.end.x <= patch.position.x)
	m.onboarding.step = Onboarding.GROW
	var grow_text: String = m.onboarding.guidance()
	_check("③c 그래서 안내가 「집(위쪽)」이다 — 「왼쪽」이 남아 있지 않다: %s" % grow_text,
		grow_text.contains("집(위쪽)") and not grow_text.contains("왼쪽"))

	# ── ④ #2/#19 보관처 만재 회수 ────────────────────────────────────────────
	print("── ④ #2/#19 걷은 것이 사라지지 않는다(적재 먼저·차감 나중) ──")
	var lot: Rect2i = m.GREENHOUSE_EXT_RECT            # 좌표 하드코딩 0(main 상수 파생)
	var crow_t := Vector2i(lot.position.x + 2, lot.position.y + 3)
	var spr_t := crow_t + Vector2i(1, 0)
	var crow_id := String(ItemCatalog.RARECROWS[0])
	m.rarecrow.place(crow_t, crow_id)
	m.sprinkler.place(spr_t, Sprinkler.TIER_1)
	_fill_backpack(m)
	_fill_chest(m.chest)
	_fill_chest(m.storehouse_chest)
	_check("④a 기준선: 세 보관처가 전부 가득이고 그 물건의 스택도 없다(백팩 %d칸·집 상자 %d칸·갈무리방 %d칸)"
			% [m.inventory.slots.size(), m.chest.slots.size(), m.storehouse_chest.slots.size()],
		not m.inventory.can_add(crow_id, 1) and not m.chest.can_store(crow_id, 1)
		and not m.storehouse_chest.can_store(crow_id, 1) and not m._stored_anywhere(crow_id))
	m.carpenter._done[Carpenter.PROJ_GREENHOUSE] = true
	_clear_notices(m)
	m._reclaim_greenhouse_lot()
	_check("④b 못 넣었으면 **걷지 않는다** — 레어크로우가 원장에 그대로 남는다(밭에도 없고 인벤에도 없는 증발 0)",
		m.rarecrow.has_at(crow_t) and m.rarecrow.id_at(crow_t) == crow_id
		and m._rarecrow_owned(crow_id))
	_check("④c 스프링클러도 같다 — 두 칸 다 점유 스캔에 그대로 잡힌다",
		m.sprinkler.has_at(spr_t) and m._greenhouse_lot_occupants().has(crow_t)
		and m._greenhouse_lot_occupants().has(spr_t))
	_check("④d 그리고 조용히 넘어가지 않는다 — 못 걷은 이유와 복구법이 화면에 뜬다",
		_notice_has(m, "보관할 자리가 없어") and _notice_has(m, ItemCatalog.name_of(crow_id)))
	# 자리를 비우면 **다음 아침이 스스로** 나머지를 걷는다(벽 밑이라 손으로는 못 걷는다).
	_clear_backpack(m)
	_clear_notices(m)
	var whistle_i := _line_of("휘파람 재지급 훅")     # 아침 자기 복구 훅의 앵커(같은 호출이 완공 갈래에도 있다)
	var retry_i := _line_after(whistle_i, "if _greenhouse_built():")
	_check("④e 아침 재시도 훅이 휘파람 재지급과 **같은 자리**에 선다(자기 복구의 같은 문법) — %d < %d"
			% [whistle_i + 1, retry_i + 1], whistle_i >= 0 and retry_i > whistle_i)
	m._reclaim_greenhouse_lot()
	_check("④f 자리가 나자 둘 다 걷혀 손에 돌아온다 — %s·%s"
			% [ItemCatalog.name_of(crow_id), ItemCatalog.name_of(ItemCatalog.SPRINKLER)],
		not m.rarecrow.has_at(crow_t) and not m.sprinkler.has_at(spr_t)
		and m._stored_anywhere(crow_id) and m._stored_anywhere(ItemCatalog.SPRINKLER))
	_check("④g 걷은 목록이 이름으로 뜬다(무엇이 어디로 갔는지 말한다)",
		_notice_has(m, "걷어 두었다") and _notice_has(m, ItemCatalog.name_of(crow_id)))
	# 되돌릴 수 없는 걷기(업화로)는 **안에 든 것의 자리까지** 확인하고 들어간다.
	_clear_backpack(m)
	_clear_chest(m.chest)
	_clear_chest(m.storehouse_chest)
	var forge_t := crow_t
	m.furnace.place(RegionCatalog.HOME, forge_t)
	var ore_id := String(ItemCatalog.ORE_MYEONGDONG)
	m.furnace.load_ore(RegionCatalog.HOME, forge_t, ore_id)
	_fill_backpack(m)
	_fill_chest(m.chest)
	# 갈무리방에 딱 한 칸만 남긴다 — 업화로는 들어가지만 안에 든 광석은 못 들어가는 자리.
	_fill_chest(m.storehouse_chest)
	m.storehouse_chest.slots[0] = null
	m.storehouse_chest.changed.emit()
	_check("④h 기준선: 업화로 한 대가 광석을 물고 서 있고 빈 칸은 정확히 하나다",
		m.furnace.has_at(RegionCatalog.HOME, forge_t)
		and m.furnace.ore_at(RegionCatalog.HOME, forge_t) == ore_id
		and m._reclaim_can_store(ItemCatalog.FURNACE, 1)
		and not m.inventory.can_add(ore_id, FurnaceLedger.ORE_PER_BATCH))
	m._reclaim_greenhouse_lot()
	_check("④i 안에 든 광석 %d개를 둘 자리가 없으면 **업화로째 그 자리에 남긴다**(걷고 나서 흘리면 소실)"
			% FurnaceLedger.ORE_PER_BATCH,
		m.furnace.has_at(RegionCatalog.HOME, forge_t)
		and m.furnace.ore_at(RegionCatalog.HOME, forge_t) == ore_id)
	_check("④j 롤백이 실제로 돌았다 — 먼저 넣은 업화로가 보관처에 남아 있지 않다",
		not m._stored_anywhere(ItemCatalog.FURNACE))
	_clear_backpack(m)
	m._reclaim_greenhouse_lot()
	_check("④k 자리가 나자 업화로와 **넣어 둔 광석이 함께** 돌아온다",
		not m.furnace.has_at(RegionCatalog.HOME, forge_t)
		and m._stored_anywhere(ItemCatalog.FURNACE)
		and m.inventory.count_of(ore_id) + m.chest.count_of(ore_id)
			+ m.storehouse_chest.count_of(ore_id) >= FurnaceLedger.ORE_PER_BATCH)

	# ── ⑤ #3 예정지 나무 — 두 원장이 나눠 가진 마당 나무 ─────────────────────
	print("── ⑤ #3 자연목도 예정지에 못 들어온다(orchard만 보던 반쪽) ──")
	m.carpenter._done.erase(Carpenter.PROJ_GREENHOUSE)
	var tree_t := Vector2i(lot.position.x + 4, lot.position.y + 2)
	var outside_t := Vector2i(lot.end.x + 2, lot.position.y + 1)   # 부지 **밖** 대조군(같은 마당)
	_check("⑤a 기준선: 늘봄방은 다시 미완공이고 그 칸 %s는 예약 부지 · %s는 부지 밖이다"
			% [str(tree_t), str(outside_t)],
		not m._greenhouse_built() and m._greenhouse_lot_reserved(tree_t)
		and not m._greenhouse_lot_reserved(outside_t))
	_check("⑤b 자체 파종 판정이 예정지를 거절한다 — `_is_tree_seed_free`(자연목)까지 가드가 닿는다",
		not m._is_tree_seed_free(RegionCatalog.HOME, tree_t, {}))
	_check("⑤c 심는 쪽(혼의 나무) 가드는 R5 그대로 산다(두 술어가 함께 막는다)",
		m._is_tree_blocked(tree_t))
	# 가드 이전 세이브 재현 — 예정지에 자연목을 직접 심는다(HOME은 이미 시드됐으므로 플래그를 되돌린다).
	m.tree_ledger._seeded.erase(RegionCatalog.HOME)
	m.tree_ledger.seed_region(RegionCatalog.HOME, [tree_t, outside_t], TreeLedger.MAX_STAGE)
	_check("⑤d 예정지 안과 밖에 각각 자연목이 선 상태를 만들었다(구세이브 재현 + 대조군)",
		m.tree_ledger.is_occupied(RegionCatalog.HOME, tree_t)
		and m.tree_ledger.is_occupied(RegionCatalog.HOME, outside_t))
	_check("⑤e 발주 게이트가 그 나무를 본다 — orchard가 비어도 `_greenhouse_lot_has_tree`가 참",
		m._greenhouse_lot_has_tree() and m.orchard.tree_at(tree_t) == Orchard.TREE_NONE)
	m.carpenter._done[Carpenter.PROJ_GREENHOUSE] = true
	_clear_notices(m)
	m._reclaim_greenhouse_lot()
	_check("⑤f 완공 정리가 그 나무를 치운다 — 벽 밑에 남아 상한만 축내는 유령 나무 0",
		not m.tree_ledger.is_occupied(RegionCatalog.HOME, tree_t)
		and not m.tree_ledger.has_slot(RegionCatalog.HOME, tree_t)
		and not m._greenhouse_lot_has_tree())
	_check("⑤g 치웠다는 사실도 말한다", _notice_has(m, "나무"))
	_check("⑤h 부지 **밖** 나무 %s는 한 그루도 안 건드린다 — 슬롯도 성숙도도 그대로다(가드가 넓어진 게 아니다)"
			% str(outside_t),
		m.tree_ledger.is_occupied(RegionCatalog.HOME, outside_t)
		and m.tree_ledger.stage_at(RegionCatalog.HOME, outside_t) == TreeLedger.MAX_STAGE)

	# ── ⑥ #5 완공 아침 매몰 ──────────────────────────────────────────────────
	print("── ⑥ #5 예정지 위에서 눈떠도 벽 안에 갇히지 않는다 ──")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	m.carpenter._done.erase(Carpenter.PROJ_GREENHOUSE)
	m._rebuild_region(RegionCatalog.HOME)
	var inside_t := Vector2i(lot.position.x + 2, lot.position.y + 3)
	m.player.position = m._tile_center_px(inside_t)
	_check("⑥a 기준선: 예정지는 완공 전까지 걸어 들어갈 수 있는 맨 지면이다(%s에 서 있다)" % str(inside_t),
		m._player_tile() == inside_t and not m._tile_blocked(inside_t))
	m.carpenter._done[Carpenter.PROJ_GREENHOUSE] = true
	_clear_notices(m)
	m._refresh_greenhouse()
	_check("⑥b 완공이 그 8×7을 WALL로 덮는다(사고의 전제 자체는 그대로다)",
		m._tile_blocked(inside_t))
	_check("⑥c 그런데 플레이어는 이미 밖이다 — 문 앞 칸 %s으로 옮겨졌고 그 칸은 걸을 수 있다"
			% str(m.GREENHOUSE_EXT_DOOR + Vector2i(0, 1)),
		not lot.has_point(m._player_tile()) and not m._tile_blocked(m._player_tile())
		and m._player_tile() == m.GREENHOUSE_EXT_DOOR + Vector2i(0, 1))
	_check("⑥d 왜 밀려났는지도 말한다", _notice_has(m, "밀려났다"))
	# 두 번째 겹 — 이미 벽 안 좌표로 저장된 세이브(자동 저장이 굳힌 그 좌표)도 구제한다.
	var buried := {"region": RegionCatalog.HOME, "indoor": "", "player_tile": inside_t}
	m._restore_location(buried)
	_check("⑥e 막힌 좌표로 복원하면 그 구역 스폰으로 떨군다 — 나락 전용이던 구제를 바깥 전체로 넓혔다",
		not m._tile_blocked(m._player_tile())
		and m._player_tile() == RegionCatalog.spawn_of(RegionCatalog.HOME))
	var ok_tile := RegionCatalog.spawn_of(RegionCatalog.HOME) + Vector2i(1, 0)
	if not m._tile_blocked(ok_tile):
		m._restore_location({"region": RegionCatalog.HOME, "indoor": "", "player_tile": ok_tile})
		_check("⑥f 멀쩡한 좌표는 그대로 복원한다(구제가 정상 복원을 덮지 않는다) — %s" % str(ok_tile),
			m._player_tile() == ok_tile)
	m.carpenter._done.erase(Carpenter.PROJ_GREENHOUSE)

	# ── ⑦ #4 카페 하루치 원장의 되감기 ───────────────────────────────────────
	print("── ⑦ #4 키 없는 세이브 로드가 직전 세션 값을 남기지 않는다 ──")
	m._active_slot = 1
	m._save_game()
	var raw: Dictionary = m.saver.load_game(1)
	_check("⑦a 기준선: 지금 세이브엔 카페 당일 원장 키가 실린다(R5의 그 키)", raw.has("cafe_day"))
	raw.erase("cafe_day")                     # 키 없는 구세이브(R5 이전 저장) 재현
	m.saver.save_game(raw, 1, {})
	# 이 세션에서 오늘 영업을 한 것으로 만든다 — 로드가 되감아야 할 바로 그 값들.
	m.cafe._ledger_day = m.clock.day
	m.cafe._spawned_today = 4
	m.cafe._guests_today = ["miho"]
	m.cafe._today_revenue = 1234
	_check("⑦b 세션 값이 실제로 서 있다(원장 날짜 = 오늘 · serial 4 · 미호 다녀감 · 매출 1234)",
		m.cafe._ledger_day == m.clock.day and m.cafe.came_today("miho")
		and m.cafe._spawned_today == 4 and m.cafe._today_revenue == 1234)
	m._load_game()
	_check("⑦c 키 없는 세이브를 불러오면 원장이 **0으로 되감긴다** — 그날 영업이 serial 0에서 시작하고 미호는 다시 올 수 있다",
		m.cafe._ledger_day == 0 and m.cafe._spawned_today == 0
		and not m.cafe.came_today("miho") and m.cafe._today_revenue == 0)
	_check("⑦d 복원부에 `has` 가드가 남아 있지 않다 — 되감기는 무조건이다",
		_line_of("\t\tcafe.load_save(data.get(\"cafe_day\", {}))") >= 0
		and _line_of("if data.has(\"cafe_day\")") < 0)
	_wipe_slot(1)
	m._active_slot = 0

	# ── ⑨ #1 REFUTED 근거 — 로드 순서가 곧 무해함의 근거다 ───────────────────
	print("── ⑨ #1 로드 회수는 복제가 아니다(적재처가 회수보다 먼저 되감긴다) ──")
	var load_i := _line_of("func _load_game()")
	var inv_i := _line_after(load_i, "inventory.load_save(data[\"inventory\"])")
	var chest_i := _line_after(load_i, "chest.load_save(data.get(\"chest\", {}))")
	var store_i := _line_after(load_i, "storehouse_chest.load_save(data.get(\"storehouse_chest\", {}))")
	var refresh_i := _line_after(load_i, "_refresh_greenhouse()")
	_check("⑨a 백팩·집 상자·갈무리방이 로드 안에서 **회수보다 먼저** 파일에서 되감긴다 — %d·%d·%d < %d"
			% [inv_i + 1, chest_i + 1, store_i + 1, refresh_i + 1],
		load_i > 0 and inv_i > load_i and chest_i > inv_i and store_i > chest_i
		and refresh_i > store_i)
	# 그 순서가 뜻을 가지려면 세 복원이 **덮어쓰기**여야 한다 — 합치기라면 로드마다 쌓인다.
	_clear_backpack(m)
	m.inventory.add_item(ItemCatalog.WOOD, 3)
	m.chest.store(ItemCatalog.WOOD, 3)
	m.storehouse_chest.store(ItemCatalog.WOOD, 3)
	m.inventory.load_save({})
	m.chest.load_save({})
	m.storehouse_chest.load_save({})
	_check("⑨b 세 복원은 전부 덮어쓰기다 — 빈 세이브를 불러오면 넣어 둔 원목 3이 남지 않는다(합치기 0)",
		m.inventory.count_of(ItemCatalog.WOOD) == 0 and m.chest.count_of(ItemCatalog.WOOD) == 0
		and m.storehouse_chest.count_of(ItemCatalog.WOOD) == 0)

	# ── ⑧ #6 B7 해방 재개 ────────────────────────────────────────────────────
	# ★ 마지막에 둔다 — 에필로그가 시계를 멈추고 입력을 잠그므로 뒤에 다른 절을 두지 않는다.
	print("── ⑧ #6 해방 장면이 끊겨도 다시 이어진다 ──")
	m._spouse_id = m.OKJA_RID
	m._mark_spine_bit(m.SPINE_B5)
	m._mark_spine_bit(m.SPINE_B6)
	m.cutscene = null
	m.spine_puzzle = null
	m._spine_say.clear()
	m._epilogue_pending = false
	m._epilogue_open = false
	m._spine_b5_pending = false
	m._sleeping = false
	m._transitioning = false
	_dismiss_dialogue(m)
	_check("⑧a 기준선: 앵커와 부부이고 B6까지 왔는데 B7은 아직이다",
		m._spine_bit_seen(m.SPINE_B6) and not m._spine_bit_seen(m.SPINE_B7))
	m._maybe_resume_spine()
	_check("⑧b 재개 훅이 해방 장면을 튼다(컷신 + 대사 묶음 + 에필로그 예약)",
		m.cutscene != null and not m._spine_say.is_empty() and m._epilogue_pending)
	_check("⑧c 그리고 **비트는 아직 안 선다** — 이 순간의 자동 저장이 미완의 장면을 완료로 굳히지 않는다",
		not m._spine_bit_seen(m.SPINE_B7))
	# 여기서 앱이 꺼진 상태 = 로드가 비영속 3종을 0으로 되돌린 뒤의 모습(main.gd의 그 줄들 그대로).
	m.cutscene = null
	m._spine_say.clear()
	m._epilogue_pending = false
	m._maybe_resume_spine()
	_check("⑧d 재기동하면 같은 훅이 장면을 **처음부터 다시** 튼다(주례 지문·앵커 대사·해방 대사가 살아 있다)",
		m.cutscene != null and not m._spine_say.is_empty() and m._epilogue_pending)
	m.cutscene = null
	m._spine_say.clear()
	m._open_epilogue()
	_check("⑧e 에필로그가 열리는 자리에서 비로소 비트가 선다(해방 = 장면 끝)",
		m._spine_bit_seen(m.SPINE_B7) and m._epilogue_open)
	m._epilogue_open = false
	m._epilogue_pending = false
	m.cutscene = null
	m._spine_say.clear()
	m._maybe_resume_spine()
	_check("⑧f 그 뒤로는 다시 안 튼다 — 1회성이 그대로 산다",
		m.cutscene == null and m._spine_say.is_empty() and not m._epilogue_pending)
	_check("⑧g 비트를 찍는 자리가 장면 시작이 아니라 에필로그다(소스 대조)",
		_line_of("\t_mark_spine_bit(SPINE_B7)") >= 0
		and _line_of("\t_mark_spine_bit(SPINE_B7)") > _line_of("func _open_epilogue()"))

	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)
	print("── 결과: %s (실패 %d)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
