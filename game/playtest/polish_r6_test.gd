extends SceneTree
# ★[폴리시 6회차] 버그 헌트 확정분 회귀 — 배치 A(늘봄방 매장 클러스터 · 로드 편도 · 첫날 구멍) +
# 배치 B(하루 전환 훅의 구역·절기 누수 · 게시판 출제의 이행 가능성 · 저장고 보유 판정 · 무대 누출).
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
# 배치 B(발견 #10~#18·#20·#21) — 셋은 "하루가 넘어가는 순간", 둘은 "게시판이 무엇을 내는가",
# 둘은 "물건을 어디에 뒀는가", 둘은 "무대가 어디까지인가"다:
#   ⑩ #10 아침 방목 방출에 구역 술어가 없어 남의 구역 그리드로 슬롯을 고르던 자리(형제 훅들은
#         전부 HOME을 확인한다). 가드 + 밀린 방출 표(절기 재스폰 표와 같은 문법)로 막는다.
#   ⑪ #11 F9 인플레이스 로드가 절기 지형 스왑을 안 돌려 다른 절기 세이브를 옛 팔레트로 그렸다.
#   ⑫ #12 밤 재점령·확산 후보가 런타임 나무 원장을 못 봐 갓 파종한 유목 칸에 잡초가 겹쳐 돋았다.
#   ⑬ #13 게시판 채집 의뢰에 절기·창 필터가 없어 **기한 안에 세계 어디에도 없는** 종을 냈다.
#   ⑭ #14 일일 어종 의뢰가 T1 낚싯대로는 확정 끊김인 중 체급을 냈다(이행 확률 0).
#   ⑮ #15 F9가 체키·칵테일 세션과 제안 창을 안 버려 되감긴 장부에 옛 매출이 떨어졌다.
#   ⑯ #16 농사 프롬프트가 숙련 감산 **전** 비용으로 판정해, 굴러가는 동작에 "혼력 부족"이라 썼다.
#   ⑰ #17 상자가 같은 유니크를 두 슬롯에 받는데 복원이 중복을 지워 세이브 왕복에서 소실됐다.
#   ⑱ #18 유니크 기어·무기 보유 판정이 상자를 못 봐, 넣어 두면 재구매가 열렸다.
#   ⑲ #20 동행 혼 visible_rule에 구역 층이 없어 나루 마을 공용 집 실내에 몸이 떴다.
#   ⑳ #21 삽사리 칸이 스타터 밭 SOIL 안이라 밭 프롬프트가 가려지고 작물이 개를 덮었다.
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

# 그 구역에 선 채로 이 주민이 보이는가(구역만 바꿔 묻고 되돌린다 — 그리드는 안 건드린다).
func _visible_in(m: Node, r: Resident, region: String) -> bool:
	var keep: String = m._region
	m._region = region
	var vis: bool = r.visible_rule.call()
	m._region = keep
	return vis

func _wipe_slot(slot: int) -> void:
	var p := SaveManager.slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _initialize() -> void:
	print("══ 폴리시 6회차 — 배치 A(늘봄방 매장·로드 편도·첫날 구멍) + 배치 B(전환 훅·게시판 출제·저장고·무대) ══")
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

	# ══════════════ 배치 B — 하루 전환 훅 · 게시판 출제 · 저장고 보유 · 무대 누출 ══════════════

	# ── ⑩ #10 아침 방목 방출의 구역 술어 ─────────────────────────────────────
	print("── ⑩ #10 남의 구역 그리드로 방목 슬롯을 고르지 않는다 ──")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	m._rebuild_region(RegionCatalog.HOME)
	var home_slots: Array = m._free_pasture_tiles()
	m._region = RegionCatalog.JEOSEUNG_FOREST
	m._rebuild_region(RegionCatalog.JEOSEUNG_FOREST)
	var forest_slots: Array = m._free_pasture_tiles()
	_check("⑩a-pre 무대: 같은 좌표 상수 %s를 다른 구역 그리드로 훑으면 슬롯 집합이 실제로 갈린다(안식 %d칸 ↔ 숲 %d칸) — 이 차이가 결함의 실체다"
			% [str(m.PASTURE_SCAN_RECT), home_slots.size(), forest_slots.size()],
		not home_slots.is_empty() and home_slots != forest_slots)
	# 문 열린 건물에 실내 짐승을 세우고, 그 짐승이 아직 안 나갔음을 확인한다.
	var barn: String = String(m.ANIMAL_BUILDINGS[0])
	var beast: Vector2i = Vector2i(-1, -1)
	for t in m.ranch.animals_in(barn):
		beast = t
		break
	if beast == Vector2i(-1, -1):
		for t2 in m.ranch.animal_tiles():
			beast = t2
			barn = m.ranch.building_of(t2)
			break
	if not m.ranch.door_open(barn):
		m.ranch.toggle_door(barn)
	m.ranch._animals[beast]["location"] = Ranch.LOC_INDOOR
	m.ranch._animals[beast]["grazed"] = false
	_check("⑩b 기준선: %s의 짐승 %s가 문 열린 실내에 있고 아직 안 나갔다"
			% [barn, str(beast)],
		m.ranch.door_open(barn) and m.ranch.releasable().has(beast)
		and not bool(m.ranch._animals[beast]["grazed"]))
	_check("⑩c 숲에 선 채로는 방출이 **아무 일도 안 한다**(옛 코드는 숲이 열어 준 부분집합에 배정했다)",
		not m._release_open_buildings() and not bool(m.ranch._animals[beast]["grazed"]))
	# 밀린 표를 세우고 안식 농원으로 돌아오면, `_process` 드레인이 그 자리에서 집행한다.
	m._pasture_release_pending = true
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)
	m._sleeping = false
	m._transitioning = false
	m.clock.minutes = 8 * 60
	await process_frame
	await process_frame
	_check("⑩d 안식 농원에 다시 서는 프레임이 밀린 방출을 집행한다 — 그날치 방목 가산(F_GRAZE %d·M_GRAZE %d)을 안 잃는다"
			% [Ranch.F_GRAZE, Ranch.M_GRAZE],
		bool(m.ranch._animals[beast]["grazed"])
		and m.ranch.location_of(beast) == Ranch.LOC_PASTURE
		and not m._pasture_release_pending)
	_check("⑩e 배정된 칸이 **안식 방목지 슬롯 안**이다(숲이 열어 준 좌표가 아니다) — %s"
			% str(m.ranch._animals[beast].get("pasture_tile", Vector2i(-1, -1))),
		home_slots.has(m.ranch._animals[beast].get("pasture_tile", Vector2i(-1, -1))))
	_check("⑩f 아침 훅이 집 밖이면 표를 세운다(형제 훅들과 같은 문법 — 소스 대조)",
		_line_of("_pasture_release_pending = _region != RegionCatalog.HOME") >= 0
		and _line_of("if _release_open_buildings():") >= 0)
	_check("⑩g 로드는 그 표를 버린다(절기 재스폰 표와 같은 이유 — 세션 로컬)",
		_line_after(_line_of("func _load_game()"), "_pasture_release_pending = false") > 0)

	# ── ⑪ #11 인플레이스 로드의 절기 지형 ────────────────────────────────────
	print("── ⑪ #11 다른 절기 세이브를 옛 절기 팔레트로 그리지 않는다 ──")
	m._active_slot = 1
	var far_day: int = GameClock.DAYS_PER_SEASON + 5     # 다음 절기의 어느 날(파생 — 하드코딩 0)
	m.clock.day = far_day
	m._save_game()
	m.clock.day = 3                                       # 첫 절기로 되돌아온 세션
	m._refresh_season_terrain(false)
	_check("⑪a 기준선: 지금 구운 지면의 절기와 세이브의 절기가 실제로 갈린다(%d ↔ %d)"
			% [GameClock.season_index_for_day(3), GameClock.season_index_for_day(far_day)],
		m._bf_season == GameClock.season_index_for_day(3)
		and GameClock.season_index_for_day(3) != GameClock.season_index_for_day(far_day))
	_check("⑪b 그 세이브를 F9로 불러오면 지면도 그 절기로 갈린다(로드가 아침 훅의 그 한 줄을 더는 안 빠뜨린다)",
		m._load_game() and m.clock.day == far_day
		and m._bf_season == GameClock.season_index_for_day(far_day)
		and m._bf_season == m._season_field_index())
	_check("⑪c 그 호출은 `_restore_location`보다 **앞**이다(재빌드가 새 절기로 굽도록) — 소스 대조",
		_line_after(_line_of("func _load_game()"), "_refresh_season_terrain(false)") > 0
		and _line_after(_line_of("func _load_game()"), "_refresh_season_terrain(false)")
			< _line_after(_line_of("func _load_game()"), "_restore_location(data)"))
	_wipe_slot(1)
	m._active_slot = 0

	# ── ⑫ #12 밤 재점령·확산이 런타임 나무 원장을 본다 ───────────────────────
	print("── ⑫ #12 자체 파종 유목 칸에 잡초가 겹쳐 돋지 않는다 ──")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	m._rebuild_region(RegionCatalog.HOME)
	var base_cand: Array = m._encroach_candidates()
	var seed_t := Vector2i(-1, -1)
	for c in base_cand:
		if not m.tree_ledger.has_slot(RegionCatalog.HOME, c):
			seed_t = c
			break
	_check("⑫a-pre 무대: 후보로 잡히는 빈 맨땅 %s를 골랐다(전체 후보 %d칸)"
			% [str(seed_t), base_cand.size()],
		seed_t != Vector2i(-1, -1))
	var occ_now: Dictionary = m._home_occupied_tiles()
	_check("⑫b 기준선: 나무가 없을 때 그 칸은 후보이고 확산 목적지로도 열려 있다",
		base_cand.has(seed_t)
		and m._weed_spread_class(seed_t, occ_now) != Reclaim.DEST_BLOCK)
	m.tree_ledger._put(RegionCatalog.HOME, seed_t,
		{"species": TreeLedger.SP_PINE, "stage": 1, "hp": TreeLedger.HP_SAPLING, "stump": false})
	_check("⑫c 아침 훅이 먼저 심은 유목이 원장에 섰다(같은 전환 안에서 파종이 잡초보다 앞이다)",
		m.tree_ledger.is_occupied(RegionCatalog.HOME, seed_t)
		and not occ_now.has(seed_t) and m._grid[seed_t.y][seed_t.x] == m.GROUND)
	_check("⑫d 이제 그 칸은 재점령 후보에서 빠진다 — 나무와 잡초가 한 칸에 겹치지 않는다",
		not m._encroach_candidates().has(seed_t))
	_check("⑫e 확산 목적지로도 막힌다(스폰·확산 두 입구를 함께 막는다)",
		m._weed_spread_class(seed_t, m._home_occupied_tiles()) == Reclaim.DEST_BLOCK)
	_check("⑫f 나머지 후보는 한 칸도 안 줄었다 — 가드가 넓어진 게 아니라 그 칸만 빠졌다",
		m._encroach_candidates().size() == base_cand.size() - 1)
	m.tree_ledger.clear_slot(RegionCatalog.HOME, seed_t)
	_check("⑫g 나무를 치우면 그 칸이 다시 후보로 돌아온다(영구 성역이 아니다)",
		m._encroach_candidates().has(seed_t))

	# ── ⑬ #13 게시판 작물·채집 의뢰의 기한 내 획득 경로 ──────────────────────
	print("── ⑬ #13 기한 안에 돋을 수 없는 채집물은 출제하지 않는다 ──")
	var forage_days := 0
	var unobtainable: Array = []
	var crop_seen := false
	for d in range(1, GameClock.DAYS_PER_SEASON * 4 + 1):
		var q3 := QuestBoard.daily_quest(d)
		if q3.is_empty():
			continue
		var qid3 := String(q3["item_id"])
		if ItemCatalog.FORAGEABLES.has(qid3):
			forage_days += 1
			if not QuestBoard._obtainable_between(qid3, d, int(q3["due_day"])):
				unobtainable.append("%d일:%s" % [d, ItemCatalog.name_of(qid3)])
		elif CropCatalog.has_crop(qid3):
			crop_seen = true
	_check("⑬a-pre 무대: 1년치에서 채집물 의뢰가 실제로 %d건 걸린다(0이면 단언에 이빨이 없다)" % forage_days,
		forage_days > 0)
	_check("⑬b 그 전건이 기한 안에 세계에 돋을 수 있다(어긋남: %s)" % str(unobtainable),
		unobtainable.is_empty())
	_check("⑬c 작물은 여전히 출제된다 — 좁힌 것은 획득 경로가 구조적으로 0인 채집물뿐이다",
		crop_seen)
	# 필터가 실제로 무언가를 걸러야 단언에 이빨이 선다(절기 전용 종이 실존한다는 사실의 계측).
	var season_locked := 0
	for fid in ItemCatalog.FORAGEABLES.keys():
		if ForageSpawns.season_of(String(fid)) >= 0 or QuestBoard._is_berry(String(fid)):
			season_locked += 1
	_check("⑬d 로스터에 절기·창 전용 채집물이 %d종 있고, 그래서 걸러진 풀이 전체 풀보다 작다(1일 기준 %d < %d)"
			% [season_locked, QuestBoard.item_pool_for(1, 2).size(), QuestBoard.item_pool().size()],
		season_locked > 0
		and QuestBoard.item_pool_for(1, 2).size() < QuestBoard.item_pool().size())
	_check("⑬e 사철 채집물(심층·해변)은 안 걸러진다 — 필터 축은 '절기'이지 '채집물'이 아니다",
		QuestBoard.item_pool_for(1, 2).has(ItemCatalog.HWANGCHEON_SANHO)
		and QuestBoard.item_pool_for(1, 2).has(ItemCatalog.JEOSEUNG_SAM))

	# ── ⑭ #14 물고기 의뢰 체급 상한과 낚싯대 ─────────────────────────────────
	print("── ⑭ #14 지금 든 줄로 못 잡는 체급은 안 걸린다 ──")
	var t1_class: int = GearCatalog.max_class_of(GearCatalog.ROD_T1)
	var over_class: Array = []
	var fish_days_seen := 0
	for d2 in range(1, GameClock.DAYS_PER_SEASON * 4 + 1):
		var q4 := QuestBoard.daily_quest(d2, t1_class)
		if q4.is_empty():
			continue
		var qid4 := String(q4["item_id"])
		if not FishCatalog.has(qid4):
			continue
		fish_days_seen += 1
		if FishCatalog.weight_class_of(qid4) > t1_class:
			over_class.append("%d일:%s" % [d2, ItemCatalog.name_of(qid4)])
	_check("⑭a-pre 무대: T1 낚싯대만 든 1년치에서도 어종 의뢰가 %d건 걸린다(막힌 게 아니라 좁혀졌다 — ADR-0008 평평≠막힘)"
			% fish_days_seen, fish_days_seen > 0)
	_check("⑭b 그 전건이 T1의 줄 강도(체급 %d) 안이다 — 확정 끊김 어종 0(어긋남: %s)"
			% [t1_class, str(over_class)], over_class.is_empty())
	var medium_days := 0
	for d3 in range(1, GameClock.DAYS_PER_SEASON * 4 + 1):
		var q5 := QuestBoard.daily_quest(d3)     # 상한 없음 = 종전 거동
		if not q5.is_empty() and FishCatalog.has(String(q5["item_id"])) \
				and FishCatalog.weight_class_of(String(q5["item_id"])) > t1_class:
			medium_days += 1
	_check("⑭c-pre 무대: 캡이 없으면 같은 1년치에 T1로 못 잡는 어종이 %d건 나온다 — 결함이 실재했다는 계측"
			% medium_days, medium_days > 0)
	_check("⑭d 낚싯대가 아예 없으면 어종 의뢰가 한 건도 안 걸린다(작물 의뢰로 폴백 — 뱃사공 만나기 전)",
		QuestBoard._make_fish(QuestBoard.KIND_DAILY, 1, 1, 2, -1).is_empty())
	_check("⑭e 일일 상한 눈금(중 체급)은 한 줄도 안 바뀌었다 — 캡은 낚싯대 축으로만 얹힌다",
		QuestBoard._make_fish(QuestBoard.KIND_DAILY, 1, 1, 2, FishCatalog.WC_LEGEND)
			== QuestBoard._make_fish(QuestBoard.KIND_DAILY, 1, 1, 2, FishCatalog.WC_MEDIUM))
	_clear_backpack(m)
	_clear_chest(m.chest)
	_clear_chest(m.storehouse_chest)
	_check("⑭f main의 파생: 아무 데도 낚싯대가 없으면 −1", m._best_rod_class() == -1)
	m.inventory.add_item(GearCatalog.ROD_T1, 1)
	_check("⑭g 백팩의 T1이 잡힌다(체급 %d)" % t1_class, m._best_rod_class() == t1_class)
	m.inventory.remove_item(GearCatalog.ROD_T1, 1)
	m.chest.store(GearCatalog.ROD_T2, 1)
	_check("⑭h **상자에 넣어 둔 낚싯대도 가진 것이다**(보유 판정의 단일 술어를 그대로 쓴다)",
		m._best_rod_class() == GearCatalog.max_class_of(GearCatalog.ROD_T2))
	_clear_chest(m.chest)

	# ── ⑮ #15 인플레이스 로드와 미니게임 세션 ────────────────────────────────
	print("── ⑮ #15 되감긴 세계에 옛 결착이 안 떨어진다 ──")
	m._active_slot = 1
	m._save_game()
	m.cheki = ChekiSession.new(1)
	m._cheki_seat = 0
	m._cheki_guest = "miho"
	m._cheki_menu = String(MenuCatalog.ids()[0])
	m._cheki_offer_secs = 3.0
	m.cocktail = CocktailSession.new(1)
	m._cocktail_seat = 0
	m._cocktail_offer_secs = 3.0
	_check("⑮a 기준선: 촬영·제조 세션과 제안 창이 모두 서 있다",
		m.cheki != null and m.cocktail != null
		and m._cheki_offer_secs > 0.0 and m._cocktail_offer_secs > 0.0)
	_check("⑮b F9 로드가 셋을 나란히 버린다(취침이 이미 하던 그 일 — 로드만 짝이 빠져 있었다)",
		m._load_game() and m.cheki == null and m.cocktail == null)
	_check("⑮c 제안 창도 함께 닫힌다 — 손님이 없는 좌석에서 촬영이 열려 매출이 나던 둘째 갈래",
		m._cheki_offer_secs == 0.0 and m._cheki_seat < 0 and m._cheki_guest == ""
		and m._cocktail_offer_secs == 0.0 and m._cocktail_seat < 0)
	# 취침 경로도 세션 유무와 무관하게 창을 버린다(같은 뿌리의 세 번째 자리).
	m._cheki_seat = 0
	m._cheki_offer_secs = 3.0
	m._cocktail_seat = 0
	m._cocktail_offer_secs = 3.0
	# 취침 경로의 창 정리는 세션 대입과 **같은 들여쓰기**여야 한다(= `if cheki != null` 블록 밖).
	var sleep_at: int = _line_of("func _do_sleep()")
	var sleep_clear: int = _line_after(sleep_at, "\tcheki = null")
	_check("⑮d 취침 경로의 창 정리가 `cheki != null` 안에 갇혀 있지 않다(소스 대조)",
		sleep_clear > 0 and _src[sleep_clear].begins_with("\tcheki")
		and _src[sleep_clear + 1] == "\t_clear_cheki_offer()")
	m._cheki_offer_secs = 0.0
	m._cocktail_offer_secs = 0.0
	m._cheki_seat = -1
	m._cocktail_seat = -1
	_wipe_slot(1)
	m._active_slot = 0

	# ── ⑯ #16 혼력 프롬프트가 실행 게이트와 같은 비용을 본다 ─────────────────
	print("── ⑯ #16 굴러가는 동작에 \"혼력 부족\"이라 안 쓴다 ──")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	m._rebuild_region(RegionCatalog.HOME)
	# 농사 숙련을 감산이 실제로 걸리는 레벨까지 올린다(레벨 파생 — 수치 하드코딩 0).
	var lv_target := 1
	while lv_target < FarmSkill.MAX_LEVEL:
		var probe_cost := int(round(SoulEnergy.COST_PER_ACTION * FarmSkill.energy_factor(lv_target)))
		if probe_cost < SoulEnergy.COST_PER_ACTION:
			break
		lv_target += 1
	m._farming_xp = int(FarmSkill.XP_THRESHOLDS[lv_target - 1])
	var cost16: int = m._farming_energy_cost()
	_check("⑯a-pre 무대: 농사 Lv%d에서 실제 비용 %d < 기본 %d(두 판정이 갈리는 구간이 실재한다)"
			% [lv_target, cost16, SoulEnergy.COST_PER_ACTION],
		lv_target <= FarmSkill.MAX_LEVEL and cost16 < SoulEnergy.COST_PER_ACTION)
	var hoe_t := Vector2i(-1, -1)
	for yy in range(m.STARTER_PATCH_RECT.position.y, m.STARTER_PATCH_RECT.end.y):
		for xx in range(m.STARTER_PATCH_RECT.position.x, m.STARTER_PATCH_RECT.end.x):
			var ct := Vector2i(xx, yy)
			if m._is_farmable(ct) and not m.farm.is_tilled(ct):
				hoe_t = ct
				break
		if hoe_t != Vector2i(-1, -1):
			break
	if m.inventory.count_of(ItemCatalog.HOE) <= 0:
		m.inventory.add_item(ItemCatalog.HOE, 1)   # ⑭f가 백팩을 비웠으므로 도구를 되돌린다
	for hi in Inventory.HOTBAR_SLOTS:
		if m.inventory.id_at(hi) == ItemCatalog.HOE:
			m.inventory.select(hi)
			break
	m._target = hoe_t
	m._target_valid = m._is_farmable(hoe_t)
	m.energy.current = cost16                      # 실행은 되고 옛 프롬프트는 막던 잔량
	_check("⑯b-pre 무대: 괭이를 들고 미경작 밭 %s를 겨눴고 잔량이 정확히 %d다"
			% [str(hoe_t), cost16],
		hoe_t != Vector2i(-1, -1) and m._target_valid
		and m.inventory.selected_id() == ItemCatalog.HOE
		and m.energy.can_act(cost16) and not m.energy.can_act(SoulEnergy.COST_PER_ACTION))
	_check("⑯c 프롬프트가 괭이질을 안내한다 — 실제로 굴러가는 동작에 \"집에서 취침\"이라 안 쓴다",
		m._farm_prompt().contains("괭이질"))
	m.energy.current = cost16 - 1
	_check("⑯d 진짜로 모자라면 여전히 막힌다(가드를 없앤 게 아니라 눈금을 맞춘 것)",
		m._farm_prompt().contains("혼력 부족"))
	_check("⑯e 무인자 `can_act()`로 묻던 농사 프롬프트가 한 자리도 안 남았다(소스 대조)",
		_line_of("\t\t\tif not energy.can_act():") < 0 and _line_of("\t\tif not energy.can_act():") < 0)
	m.energy.current = SoulEnergy.MAX

	# ── ⑰ #17 상자 유니크 왕복 보존 ──────────────────────────────────────────
	print("── ⑰ #17 적재가 허용한 상태를 복원이 삭제하지 않는다 ──")
	_clear_chest(m.chest)
	var uniq := String(GearCatalog.TACKLES.keys()[0])
	_check("⑰a-pre 무대: %s는 비스택 유니크다(같은 슬롯에 합쳐지지 않는다)"
			% ItemCatalog.name_of(uniq), not ItemCatalog.stackable_of(uniq))
	_check("⑰b 첫 적재는 들어간다", m.chest.store(uniq, 1) == 1 and m.chest.count_of(uniq) == 1)
	_check("⑰c 같은 유니크의 둘째 적재는 거절된다(백팩 `add_item`과 같은 규약)",
		m.chest.store(uniq, 1) == 0 and m.chest.count_of(uniq) == 1)
	_check("⑰d 묻는 쪽(`can_store`)도 같은 답을 한다 — 두 창구가 안 갈린다",
		not m.chest.can_store(uniq, 1))
	var snap: Dictionary = m.chest.to_save()
	m.chest.load_save(snap)
	_check("⑰e 세이브 왕복이 값을 치른 물건을 안 지운다 — 적재 가능 상태 전부가 복원 가능하다",
		m.chest.count_of(uniq) == 1)
	# 옛 세이브(같은 유니크 두 슬롯)는 여전히 하나로 정제된다 — 복원의 방어는 그대로 산다.
	m.chest.load_save({"slots": [{"id": uniq, "count": 1, "quality": 0},
		{"id": uniq, "count": 1, "quality": 0}]})
	_check("⑰f 이미 두 슬롯이 실린 구세이브는 종전대로 하나로 정제된다(하위호환·불변식 재보증)",
		m.chest.count_of(uniq) == 1)
	_clear_chest(m.chest)

	# ── ⑱ #18 유니크 보유 판정이 상자를 본다 ─────────────────────────────────
	print("── ⑱ #18 상자에 넣었다고 재구매가 열리지 않는다 ──")
	_clear_backpack(m)
	_clear_chest(m.chest)
	_clear_chest(m.storehouse_chest)
	m.chest.store(uniq, 1)
	var gold_before: int = m.wallet.gold
	var row18: Dictionary = m._gear_row(uniq, 0)
	_check("⑱a 매대 행이 잠긴다 — 백팩엔 없지만 집 상자에 있다",
		bool(row18.get("locked", false)) and int(row18.get("count", 0)) == 1
		and m.inventory.count_of(uniq) == 0)
	_clear_notices(m)
	m._buy_store_generic_n(uniq, "gear", 1)
	_check("⑱b 그래도 사면 거절된다 — 같은 태클을 정가로 또 결제하지 않는다",
		m.wallet.gold == gold_before and m.inventory.count_of(uniq) == 0
		and _notice_has(m, "이미 가지고 있다"))
	# 무기도 완전히 같은 규약(길드 매대).
	var wid := ""
	for wcand in WeaponCatalog.ids():
		if WeaponCatalog.price_of(String(wcand)) > 0:
			wid = String(wcand)
			break
	m.mine_floors._depth = maxi(m.mine_floors.depth(), WeaponCatalog.depth_of(wid))
	m.storehouse_chest.store(wid, 1)
	m.wallet.gold = WeaponCatalog.price_of(wid) * 3
	var wgold: int = m.wallet.gold
	_clear_notices(m)
	m._buy_store_generic_n(wid, "weapon", 1)
	_check("⑱c 갈무리방 상자에 넣어 둔 %s도 보유다 — \"두 자루가 순수 손해\"가 그대로 성립하던 자리"
			% WeaponCatalog.name_of(wid),
		m.wallet.gold == wgold and m.inventory.count_of(wid) == 0
		and _notice_has(m, "이미 가지고 있다"))
	_check("⑱d 미끼(스택 소모품)는 이 규약 밖이다 — 상자에 있어도 계속 살 수 있다",
		not bool(m._gear_row(String(GearCatalog.BAITS.keys()[0]), 0).get("locked", false)))
	_clear_chest(m.chest)
	_clear_chest(m.storehouse_chest)

	# ── ⑲ #20 동행 혼의 무대 층 ──────────────────────────────────────────────
	print("── ⑲ #20 동행 혼의 몸이 남의 집에 안 뜬다 ──")
	var r_soul_rec: Resident = m._resident(m.SOUL_CHILD_RID)
	m._soul_born = true
	_check("⑲a-pre 무대: 상주 칸 %s가 나루 마을 공용 집 카메라 %s 안에 든다 — 이 겹침이 결함의 실체다"
			% [str(m.SOUL_CHILD_TILE), str(m.HOUSE_CAM_RECT)],
		r_soul_rec != null and m.HOUSE_CAM_RECT.has_point(m.SOUL_CHILD_TILE))
	m._region = RegionCatalog.NARU_VILLAGE
	m._indoor = String(m.HOUSE_IDS[0])
	_check("⑲b 남의 집(%s) 실내에서는 안 보인다 — 몸만 남의 방 북벽 위에 서 있던 자리" % m._indoor,
		not r_soul_rec.visible_rule.call())
	m._indoor = ""
	_check("⑲c 다른 구역이면 어디서도 안 보인다(마을 야외·숲 — 무대 층 하나로 전부 닫힌다)",
		not r_soul_rec.visible_rule.call()
		and not _visible_in(m, r_soul_rec, RegionCatalog.JEOSEUNG_FOREST))
	m._region = RegionCatalog.HOME
	m._indoor = r_soul_rec.require_indoor
	_check("⑲d 제 집 안에서는 보인다 — 좁힌 게 아니라 무대를 맞춘 것이다",
		r_soul_rec.visible_rule.call())
	m._indoor = ""
	_check("⑲e 방까지 좁히지 않는 근거: 상주 칸 y%d가 안식 실내 밴드(≥ %d)라 마당에선 카메라 밖이다"
			% [m.SOUL_CHILD_TILE.y, m._outdoor_h],
		m.SOUL_CHILD_TILE.y >= m._outdoor_h and r_soul_rec.visible_rule.call())
	m._soul_born = false
	m._indoor = r_soul_rec.require_indoor
	_check("⑲f 깃들기 전에는 제 집 안에서도 안 보인다(옛 규칙 그대로 산다)",
		not r_soul_rec.visible_rule.call())
	m._indoor = ""

	# ── ⑳ #21 삽사리 칸과 스타터 밭 ──────────────────────────────────────────
	print("── ⑳ #21 삽사리 칸이 밭 동사·작물과 안 겹친다 ──")
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)
	_check("⑳a-pre 무대: PET_TILE %s는 STARTER_PATCH_RECT %s 안이고 지형이 SOIL이다(머리말의 \"밭과 안 겹친다\"가 거짓이었다)"
			% [str(m.PET_TILE), str(m.STARTER_PATCH_RECT)],
		m.STARTER_PATCH_RECT.has_point(m.PET_TILE)
		and m._grid[m.PET_TILE.y][m.PET_TILE.x] == m.SOIL)
	_check("⑳b 그 칸은 경작 대상이 아니다 — 미호 자리가 받은 예외를 삽사리 자리도 받는다",
		not m._is_farmable(m.PET_TILE))
	m._target = m.PET_TILE
	m._target_valid = m._is_farmable(m.PET_TILE)
	_check("⑳c 겨눠도 밭 프롬프트가 없다 — 화면이 숨긴 동사가 애초에 존재하지 않는다",
		m._farm_prompt() == "")
	var patch_ok := 0
	for yy2 in range(m.STARTER_PATCH_RECT.position.y, m.STARTER_PATCH_RECT.end.y):
		for xx2 in range(m.STARTER_PATCH_RECT.position.x, m.STARTER_PATCH_RECT.end.x):
			if m._is_farmable(Vector2i(xx2, yy2)):
				patch_ok += 1
	_check("⑳d 패치의 나머지 칸은 그대로 경작된다(%d칸 = 5×5 − 미호 자리 − 삽사리 자리)" % patch_ok,
		patch_ok == m.STARTER_PATCH_RECT.size.x * m.STARTER_PATCH_RECT.size.y - 2)
	_check("⑳e 물그릇 칸 %s는 패치 밖이라 손대지 않았다(가드가 넓어진 게 아니다)"
			% str(m.PET_BOWL_TILE),
		not m.STARTER_PATCH_RECT.has_point(m.PET_BOWL_TILE))
	_check("⑳f 그리는 순서(삽사리 → 작물)는 그대로다 — 겹칠 작물이 없어졌을 뿐이다(소스 대조)",
		_line_of("_draw_sapsari()") < _line_of("_draw_crops()            #"))

	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)
	print("── 결과: %s (실패 %d)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
