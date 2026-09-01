extends SceneTree
# ★[폴리시 5회차 · 배치 A] 버그 헌트 확정분 회귀 — R4 부작용 · 한글 조사 · 1회성 멱등.
#
# polish_r4_test가 "한 번 누른 키가 한 번만 집행된다"를 잰다면, 여기는 그 표를 **누가 세울 자격이
# 있는가**(= 아무 일도 안 한 창구는 입력을 못 삼킨다)와, **화면에 뜨는 한 줄이 한국어로 맞는가**,
# 그리고 **1회성 사건이 상자·이혼을 거쳐도 한 번인가**를 잰다.
#
# 무엇을 보증하나(발견 번호 = 5회차 헌트 배치 A):
#   ① #1 늘봄방 예약 부지 — 배치 차단뿐이던 가드에 **묘목 차단·발주 차단·완공 회수**가 붙는다
#      (구세이브의 기존 설치물이 완공 아침에 벽 밑으로 매장되지 않는다).
#   ② #2 `_try_harvest`가 **소비 여부를 반환**한다 — 집 안 빈 화분·안 자란 화분은 RMB를 안 삼킨다
#      (그 방향을 본 채로 우클릭 취침이 영영 안 먹던 자리). 실패 알림은 소비로 친다.
#   ③ #3 채집 창구 넷도 같은 계약 — 완전 무동작이면 [F]를 안 삼켜 사슬 맨 끝 휘파람까지 흐른다
#      (R4가 세운 "호출 줄 다음 줄이 f_taken" 소스 관례는 그대로 산다).
#   ④ #4~#10 조사(助詞) — 받침 판정 헬퍼 한 곳(HanjiUi)이 을/를·이/가·은/는·과/와를 가른다.
#      **개별 문구 땜질이 아니라** 이름을 끼우는 줄에 고정 조사가 하나도 안 남았음을 스캔으로 못 박는다.
#   ⑤ #11 마구간 휘파람 — 상자에 넣어 둔 것도 "가진 것"이다(매일 아침 재지급 = 무한 복제 차단).
#   ⑥ #12 카페 마일스톤 하트 축이 **단조**다 — 이혼(reset_hearts)이 지나간 도달을 되돌리지 않는다
#      (1회성 축하 재발화 + 좌석·곳간·늘봄방 도면 퇴행이 한 소스에서 함께 낫는다).
#   ⑦ #13 명부 혼례 부적 — 무상 1회성 발급이 상자 보관으로 다시 열리지 않는다.
#
# ★ `_process` 안의 지역 변수(harvest_took_rmb·f_taken)는 함수 호출로 재현할 수 없다 — 그래서 그
#   줄이 실제로 그 가드를 달고 있나를 **main 소스에서 줄 단위로** 대조하고(polish_r4_test ④·
#   peddler_test ⑫와 같은 관례), 그 가드가 부르는 술어·반환값은 따로 실호출로 잰다.
#
# 실행: ./run_tests.sh polish_r5   (헤드리스는 반드시 game/에서 · 순차)

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
	for i in _src.size():
		if _src[i].contains(needle):
			return i
	return -1

# ★[폴리시 R2 공용] 백팩을 **빈 슬롯 0**으로 채운다 — sprinkler_test·panning_test 등이 쓰는 그
#   헬퍼를 그대로 가져온다(수법을 갈라 두면 여기서만 다르게 새는 자리가 생긴다).
#   슬롯에 직접 쓴다: `add_item`으로 채우면 같은 (id,품질)이 스택으로 합쳐져 칸이 안 준다.
#   ★ 풀 = 유품·책이다. 서로 다른 종이라 합류할 스택이 하나도 없고, **작물 수확물·채집물과 겹치지
#     않아** 이 파일이 재는 두 물건(화분 수확물·야생 피안화)의 `can_add`를 오염시키지 않는다.
#     레어크로우·작물 로스터로 채우면 13종뿐이라 16칸을 못 채우고(빈 칸이 남아 "가득"이 거짓이 된다),
#     작물 수확물이 풀에 들면 합칠 스택이 생겨 만재 분기 자체에 안 닿는다 — 둘 다 겪은 함정이다.
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

# 상자에서 그 물건이 든 슬롯을 찾아 1개 뺀다(인덱스 0을 가정하지 않는다 — 로드한 상자엔 다른 게 있다).
func _chest_take(c, id: String) -> bool:
	for i in c.slots.size():
		if c.id_at(i) == id:
			return c.remove_at(i, 1)
	return false

func _initialize() -> void:
	print("══ 폴리시 5회차 배치 A — R4 부작용 · 한글 조사 · 1회성 멱등 회귀 ══")
	_src = FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().split("\n")
	var save0 := SaveManager.slot_path(0)
	if FileAccess.file_exists(save0):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save0))
	var m := await _spawn_main()
	_dismiss_dialogue(m)

	# ── ④ #4~#10 조사 헬퍼 ────────────────────────────────────────────────────
	# 판정 자체를 먼저 잰다(월드 상태 무관 — 순수 함수). 받침 O / 받침 X / 비한글 세 갈래.
	print("── ④ #4~#10 받침 판정 조사 헬퍼(HanjiUi) ──")
	_check("④a 받침 있는 이름은 을·이·은·과 — 넋알돌/명동 광석/명부환/뱃사공",
		HanjiUi.josa_eul("넋알돌") == "을" and HanjiUi.josa_i("명동 광석") == "이"
		and HanjiUi.josa_eun("명부환") == "은" and HanjiUi.josa_gwa("뱃사공") == "과")
	_check("④b 받침 없는 이름은 를·가·는·와 — 넋붕어/넋수지/미호",
		HanjiUi.josa_eul("넋붕어") == "를" and HanjiUi.josa_i("넋수지") == "가"
		and HanjiUi.josa_eun("미호") == "는" and HanjiUi.josa_gwa("미호") == "와")
	_check("④c 한글이 아닌 끝글자·빈 문자열은 받침 없는 쪽으로 떨어진다(병기로 물러서지 않는다)",
		HanjiUi.josa_eul("Item7") == "를" and HanjiUi.josa_i("") == "가"
		and HanjiUi.josa_gwa("Mel") == "와")
	_check("④d 이름+조사 형태가 그 판정을 그대로 잇는다(호출부가 쓰는 형태)",
		HanjiUi.with_eul("넋알돌") == "넋알돌을" and HanjiUi.with_i("명동 광석") == "명동 광석이"
		and HanjiUi.with_eun("명부환") == "명부환은" and HanjiUi.with_gwa("뱃사공") == "뱃사공과")
	# 지적된 실제 문구들 — 카탈로그의 진짜 이름으로 합성해 본다(문자열이 아니라 *결과*를 잰다).
	var geode_name := ItemCatalog.name_of(ItemCatalog.GEODE_NEOKAL)
	var ore_name := ItemCatalog.name_of(ItemCatalog.ORE_MYEONGDONG)
	_check("④e #5 알돌 개봉이 「%s 깼다」로 뜬다(받침 ㄹ에 '를'이 붙던 100%% 오조사 자리)"
			% HanjiUi.with_eul(geode_name),
		HanjiUi.with_eul(geode_name) == geode_name + "을")
	_check("④f #6 업화로 광석 부족이 「%s 모자라다」로 뜬다(받침 ㄱ에 '가'가 붙던 자리)"
			% HanjiUi.with_i(ore_name),
		HanjiUi.with_i(ore_name) == ore_name + "이")
	# #7 수액 산출물 3종 · #8 수종 3종 — **로스터 전수**를 돈다(대표 하나만 맞고 지나가지 않게).
	var josa_bad: Array = []
	for sp in [TreeLedger.SP_PINE, TreeLedger.SP_MAPLE, TreeLedger.SP_OAK]:
		var pname := ItemCatalog.name_of(TapperLedger.product_for(String(sp)))
		if HanjiUi.with_i(pname) != pname + HanjiUi.josa_i(pname):
			josa_bad.append(pname)
		var sname := TreeLedger.species_name(String(sp))
		if HanjiUi.with_eul(sname) != sname + HanjiUi.josa_eul(sname):
			josa_bad.append(sname)
	_check("④g #7/#8 수종·수액 산출물 3종이 전부 제 조사를 받는다 — 저승솔·명단풍·넋참나무 / 솔넋진·넋수지·명단풍꿀(어긋남: %s)"
			% str(josa_bad), josa_bad.is_empty()
			and HanjiUi.with_eul(TreeLedger.species_name(TreeLedger.SP_PINE)) == "저승솔을")
	_check("④h #9 점주 할인 ♡0 헤더가 「뱃사공과」로 뜬다(옹이는 「옹이와」 — 둘 다 한 식에서)",
		StoreDiscount.summary_for("뱃사공", "생선가게 매대", 0).contains("뱃사공과 친해지면")
		and StoreDiscount.summary_for("옹이", "목공방 매대", 0).contains("옹이와 친해지면"))
	# ★ 전수 스캔 — **이름을 끼우는 줄에 고정 조사가 한 곳도 안 남았다**(부분 수정 방지).
	#   서식 문자열과 인자가 다른 줄에 있는 문구가 많아 3행 창으로 본다. "%s 가구 세트"처럼
	#   조사가 아닌 한글이 이어지는 자리는 뒤 문자 조건([^가-힣])으로 걸러진다.
	var name_srcs := ["name_of(", "title_of(", "species_name(", "display_name", "name_ko", "large_name("]
	var josa_re := RegEx.create_from_string("%s ?(를|을|는|은|가|이|와|과)([^가-힣]|$)")
	var leftovers: Array = []
	for i in _src.size():
		var w := ""
		for k in range(i, mini(i + 3, _src.size())):
			w += _src[k] + " "
		if josa_re.search(w) == null:
			continue
		for s in name_srcs:
			if w.contains(String(s)):
				leftovers.append(i + 1)
				break
	_check("④i main.gd에서 런타임 이름 옆 고정 조사가 0곳이다(잔존 줄: %s)" % str(leftovers),
		leftovers.is_empty())

	# ── ② #2 `_try_harvest`의 소비 반환 ───────────────────────────────────────
	print("── ② #2 빈 화분을 겨눈 RMB가 취침을 삼키지 않는다 ──")
	var saved_indoor: String = m._indoor
	var saved_target: Vector2i = m._target
	m._indoor = "집"
	var house: Rect2i = m.home_house_rect()
	var pot_t := Vector2i(house.position.x + 2, house.position.y + 2)
	_check("②a 기준선: 집 실내 칸은 화분 자리이자 취침 구역이다(R4 ③a와 같은 사실)",
		m._can_place_pot(pot_t) and m._zone_at(m._tile_center_px(pot_t)) == "집")
	m.garden_pot.place(pot_t)
	m._target = pot_t
	_check("②b 빈 화분을 겨눈 RMB는 **소비되지 않는다**(false) — 그 자리에서 취침이 살아난다",
		m._pot_at(pot_t) and not m._try_harvest())
	var pot_crop := String(CropCatalog.ids()[0])
	m.garden_pot.plant(pot_t, pot_crop)
	_check("②c 안 자란 화분도 마찬가지다(심었다고 소비되지 않는다)",
		m.garden_pot.is_planted(pot_t) and not m.garden_pot.is_mature(pot_t)
		and not m._try_harvest())
	m.garden_pot._pots[pot_t]["grown_days"] = 99   # 날 진행 없이 성숙시킨다
	_check("②d 다 자란 화분은 소비된다(true) — R4가 막으려던 「수확하며 잠드는」 사고는 그대로 막힌다",
		m.garden_pot.is_mature(pot_t) and m._try_harvest())
	# 실패 알림은 소비로 친다 — 흘려보내면 "거둘 수 없다" 한 줄과 함께 하루가 끝난다.
	m.garden_pot.plant(pot_t, pot_crop)
	m.garden_pot._pots[pot_t]["grown_days"] = 99
	_fill_backpack(m)
	# ★ 무대 셋업을 **따로** 단언한다 — 이 두 사실이 거짓이면 아래 ②e는 만재 분기에 닿지도 못한
	#   채 통과/실패하므로, 무엇이 깨졌는지 라벨 하나로 갈리게 둔다(합친 단언이 원인을 삼켰던 자리).
	_check("②e-pre 무대: 백팩에 빈 칸이 0이고 %s가 합류할 스택도 없다(만재 분기에 실제로 닿는다)"
			% ItemCatalog.name_of(ItemCatalog.harvest_id(pot_crop)),
		not m.inventory.has_free_slot()
		and not m.inventory.can_add(ItemCatalog.harvest_id(pot_crop), 1, ItemCatalog.Q_NORMAL))
	_check("②e 백팩 만재로 못 거둔 RMB는 **소비로 친다**(true) — 알림 뒤에 잠들어 버리지 않게",
		m._try_harvest() and m.garden_pot.is_mature(pot_t))
	_clear_backpack(m)
	m.garden_pot.remove(pot_t)
	m._indoor = saved_indoor
	m._target = saved_target
	var call_i := _line_of("harvest_took_rmb = _try_harvest()")
	var sleep_i := _line_of("if not harvest_took_rmb and _can_sleep()")
	_check("②f 디스패치가 표를 **반환값으로** 세우고 취침이 그 표를 본다(main.gd:%d → %d)"
			% [call_i + 1, sleep_i + 1], call_i >= 0 and sleep_i > call_i)

	# ── ③ #3 채집 창구 넷의 같은 계약 ─────────────────────────────────────────
	print("── ③ #3 아무 일도 안 한 창구는 [F]를 못 삼킨다 ──")
	var saved_region: String = m._region
	m._region = RegionCatalog.HOME
	var empty_t := Vector2i(2, 2)   # 채집물·덤불·팬닝·반딧넋 어느 원장에도 없는 칸
	_check("③a 스폰 없는 칸의 줍기·거두기는 false다(사슬 맨 끝 휘파람까지 [F]가 흐른다)",
		not m._pick_forage(empty_t) and not m._gather_firefly(empty_t))
	_check("③b 스폿 없는 칸의 팬닝·덤불도 false다(네 창구가 같은 계약을 쓴다)",
		not m._pan_spot(empty_t) and not m._shake_bush(empty_t))
	# 실제로 집으면 true — 계약이 "무조건 false"가 아니라 성공을 가린다는 것을 못 박는다.
	var fg_t := Vector2i(9, 9)
	var forage_id := ItemCatalog.SPIRIT_FLOWER
	m.forage_spawns._tiles[RegionCatalog.HOME] = {fg_t: forage_id}
	_check("③c 실제 스폰 칸을 주우면 true다(%s) — 그때는 휘파람이 안 돈다" % ItemCatalog.name_of(forage_id),
		m._pick_forage(fg_t) and not m.forage_spawns.has_at(RegionCatalog.HOME, fg_t))
	# 만재 실패는 ②e와 같은 이유로 소비다 — 알림을 띄운 [F]가 말에서 내리는 겹동작이 되지 않게.
	m.forage_spawns._tiles[RegionCatalog.HOME] = {fg_t: forage_id}
	_fill_backpack(m)
	_check("③d-pre 무대: 백팩에 빈 칸이 0이고 %s가 합류할 스택도 없다(만재 분기에 실제로 닿는다)"
			% ItemCatalog.name_of(forage_id),
		not m.inventory.has_free_slot() and not m.inventory.can_add(forage_id, 1))
	_check("③d 만재로 못 주운 [F]도 소비로 친다(true) — 스폰 칸은 그대로 남는다(R4 ⑭b 불변식 생존)",
		m._pick_forage(fg_t) and m.forage_spawns.has_at(RegionCatalog.HOME, fg_t))
	_clear_backpack(m)
	m.forage_spawns._tiles.erase(RegionCatalog.HOME)
	# R4가 세운 소스 관례(호출 줄 바로 다음 줄이 f_taken)가 그대로 서 있나 — 넷 전부.
	var f_windows := ["_pick_forage(_target)", "_shake_bush(_target)",
		"_pan_spot(_target)", "_gather_firefly(_target)"]
	var f_missing: Array = []
	for wname in f_windows:
		var wi := _line_of(String(wname))
		if wi < 0 or not _src[wi].contains("if ") or not _src[wi + 1].contains("f_taken"):
			f_missing.append(wname)
	_check("③e 네 창구가 **성공했을 때만** 표를 세운다 — `if <창구>(_target):` 다음 줄이 f_taken(누락: %s)"
			% str(f_missing), f_missing.is_empty())
	_check("③f 사슬 맨 끝 휘파람이 그 표를 그대로 본다(R4 규약 불변)",
		_line_of("not _sleeping and not f_taken and mount != null") >= 0)

	# ── ① #1 늘봄방 예약 부지의 세 방어 ───────────────────────────────────────
	print("── ① #1 예약 부지 — 묘목 차단 · 발주 차단 · 완공 회수 ──")
	var lot: Rect2i = m.GREENHOUSE_EXT_RECT          # 좌표 하드코딩 0(main 상수 파생)
	var lot_t := Vector2i(lot.position.x + 2, lot.position.y + 3)
	var crow_t := lot_t + Vector2i(1, 0)
	_check("①a 기준선: 늘봄방은 아직 안 지었고 그 칸 %s는 예약 부지다" % str(lot_t),
		not m._greenhouse_built() and m._greenhouse_lot_reserved(lot_t))
	_check("①b 예약 부지엔 **묘목도 못 심는다**(설치물 셋만 막고 비어 있던 반쪽 — 회수 수단조차 없다)",
		m._is_tree_blocked(lot_t))
	_check("①c 부지 밖 스타터 패치는 그대로 심을 수 있다(가드가 넓어진 게 아니다)",
		not m._is_tree_blocked(Vector2i(41, 13)))
	# 구세이브 재현 — 가드 이전에 세운 설치물을 원장에 직접 심는다.
	m.sprinkler.place(lot_t, Sprinkler.TIER_1)
	var crow_id := String(ItemCatalog.RARECROWS[0])
	m.rarecrow.place(crow_t, crow_id)
	var occ: Array = m._greenhouse_lot_occupants()
	_check("①d 점유 스캔이 스프링클러·레어크로우 두 칸을 **무대와 무관하게** 센다(발주는 나루 마을에서 일어난다) — %s"
			% str(occ), occ.has(lot_t) and occ.has(crow_t))
	# 발주 차단 — 3단 도면 해금까지 세운 뒤라야 이 게이트에 닿는다(앞 게이트에 안 걸리게).
	m._run_harvested = CafeMilestone.S2_TARGET_HARVEST
	m._cafe_revenue_total = CafeMilestone.S3_TARGET_REVENUE
	m.affinity.stage = Affinity.MAX_HEARTS
	m.mel_affinity.stage = Affinity.MAX_HEARTS
	m.wallet.earn(Carpenter.gold_cost(Carpenter.PROJ_GREENHOUSE) * 2)
	m.inventory.add_item(ItemCatalog.WOOD, Carpenter.wood_cost(Carpenter.PROJ_GREENHOUSE))
	_check("①e 기준선: 카페 3단이라 늘봄방 도면이 열려 있다(발주 게이트까지 실제로 닿는다)",
		m._cafe_stage() == CafeMilestone.STAGE_3 and m._build_row_unlocked(Carpenter.PROJ_GREENHOUSE))
	var gold_at_order: int = m.wallet.gold
	var wood_at_order: int = m.inventory.count_of(ItemCatalog.WOOD)
	_check("①f 부지가 점유된 채로는 **발주가 거절된다** — 냥·원목을 치르기 전에 막는다(부분 결제 0)",
		not m._try_order_build(Carpenter.PROJ_GREENHOUSE) and not m.carpenter.is_active()
		and m.wallet.gold == gold_at_order
		and m.inventory.count_of(ItemCatalog.WOOD) == wood_at_order)
	# 완공 회수 — 구세이브가 이미 발주를 걸어 둔 경우의 안전판(발주 게이트가 못 막는 유일한 창).
	m.carpenter._done[Carpenter.PROJ_GREENHOUSE] = true
	m._reclaim_greenhouse_lot()
	_check("①g 완공 회수가 원장을 비운다 — 스프링클러·레어크로우 두 칸이 남지 않는다",
		m._greenhouse_lot_occupants().is_empty()
		and not m.sprinkler.has_at(lot_t) and not m.rarecrow.has_at(crow_t))
	_check("①h 걷은 것은 사라지지 않고 손에 돌아온다 — %s·%s(레어크로우는 재획득 경로가 1회성이라 특히)"
			% [ItemCatalog.name_of(ItemCatalog.SPRINKLER), ItemCatalog.name_of(crow_id)],
		m._stored_anywhere(ItemCatalog.SPRINKLER) and m._stored_anywhere(crow_id))
	m._reclaim_greenhouse_lot()
	_check("①i 회수는 멱등이다(두 번째 호출은 걷을 것이 없고 아무것도 더 주지 않는다)",
		m._greenhouse_lot_occupants().is_empty()
		and m.inventory.count_of(ItemCatalog.SPRINKLER) + m.chest.count_of(ItemCatalog.SPRINKLER)
			+ m.storehouse_chest.count_of(ItemCatalog.SPRINKLER) == 1)
	var refresh_i := _line_of("func _refresh_greenhouse()")
	var reclaim_i := _line_of("\t_reclaim_greenhouse_lot()")
	var rebuild_i := _line_of("\t\t_rebuild_region(RegionCatalog.HOME)")
	_check("①j 회수가 **그리드 재빌드보다 앞**에 선다(벽이 덮은 뒤엔 겨눌 수도 걷을 수도 없다) — %d < %d < %d"
			% [refresh_i + 1, reclaim_i + 1, rebuild_i + 1],
		refresh_i >= 0 and reclaim_i > refresh_i and rebuild_i > reclaim_i)
	m.carpenter._done.erase(Carpenter.PROJ_GREENHOUSE)
	m._region = saved_region

	# ── ⑥ #12 마일스톤 하트 축의 단조성 ───────────────────────────────────────
	print("── ⑥ #12 이혼이 지나간 도달을 되돌리지 않는다 ──")
	var peak_before: int = m._milestone_hearts()
	_check("⑥a 기준선: 미호+멜이 각 ♡%d라 하트 축 %d, 카페 3단에 닿아 있다"
			% [Affinity.MAX_HEARTS, peak_before],
		peak_before == m.affinity.hearts() + m.mel_affinity.hearts()
		and m._cafe_stage() == CafeMilestone.STAGE_3)
	m.affinity.reset_hearts()          # `_do_divorce`가 배우자에게 하는 일 그대로
	_check("⑥b 이혼으로 미호 칸이 0이 되어도 마일스톤이 보는 값은 최고 수위 그대로다(%d)" % peak_before,
		m.affinity.hearts() == 0 and m._milestone_hearts() == peak_before)
	_check("⑥c 그래서 1회성 축하 조건도, 카페 단계도 내려앉지 않는다 — 좌석·곳간·늘봄방 도면 퇴행 0",
		m._milestone_complete() and m._cafe_stage() == CafeMilestone.STAGE_3
		and m._build_row_unlocked(Carpenter.PROJ_GREENHOUSE))
	# 세이브 왕복 — 래치가 아니라 **입력**을 저장하므로 재개해도 같은 값이 선다.
	m._active_slot = 1
	m._save_game()
	m._milestone_hearts_peak = 0
	m._load_game()
	_check("⑥d 최고 수위가 세이브를 건너 살아남는다(구세이브는 키가 없어 0 → 첫 파생이 채운다)",
		m._milestone_hearts_peak == peak_before and m._milestone_hearts() == peak_before)

	# ── ⑤⑦ #11/#13 상자를 낀 1회성 멱등 ──────────────────────────────────────
	print("── ⑤⑦ #11/#13 상자에 넣으면 다시 열리던 1회성 창구 ──")
	_clear_backpack(m)
	m.carpenter._done[Carpenter.PROJ_STABLE] = true
	_check("⑤a 기준선: 마구간을 지었고 휘파람은 어디에도 없다 → 오늘 아침 증정이 성립한다",
		not m._stored_anywhere(ItemCatalog.MOUNT_WHISTLE) and m._grant_mount_whistle()
		and m.inventory.count_of(ItemCatalog.MOUNT_WHISTLE) == 1)
	# 상자에 넣는다(플레이어가 실제로 하는 일 — 상자는 종류 제한이 없어 KEY도 받는다).
	m.inventory.remove_item(ItemCatalog.MOUNT_WHISTLE, 1)
	m.chest.store(ItemCatalog.MOUNT_WHISTLE, 1)
	_check("⑤b 집 상자에 넣어 둔 휘파람도 「가진 것」이다 → 다음 아침이 두 번째를 안 찍는다",
		m.chest.count_of(ItemCatalog.MOUNT_WHISTLE) == 1
		and not m._grant_mount_whistle()
		and m.inventory.count_of(ItemCatalog.MOUNT_WHISTLE) == 0)
	# 갈무리방 상자도 같은 합집합에 든다(두 상자는 서로 독립이라 둘 다 본다).
	_check("⑤c 갈무리방 상자도 마찬가지다(`_rarecrow_owned`가 이미 확립한 범위와 같다)",
		_chest_take(m.chest, ItemCatalog.MOUNT_WHISTLE)
		and m.storehouse_chest.store(ItemCatalog.MOUNT_WHISTLE, 1) > 0
		and not m._grant_mount_whistle()
		and m.inventory.count_of(ItemCatalog.MOUNT_WHISTLE) == 0)
	_check("⑤d 어디에도 없으면 다음 아침이 스스로 복구한다(멱등이 봉쇄가 되지 않는다 — ADR-0008)",
		_chest_take(m.storehouse_chest, ItemCatalog.MOUNT_WHISTLE) and m._grant_mount_whistle()
		and m.inventory.count_of(ItemCatalog.MOUNT_WHISTLE) == 1)
	m.carpenter._done.erase(Carpenter.PROJ_STABLE)
	# #13 — 무상 발급이라 복제 이득이 가장 큰 창구(부적 5,000냥·비약 3,000냥과 달리 값을 안 받는다).
	m.chest.store(ItemCatalog.MYEONGBU_CHARM, 1)
	_check("⑦a 상자에 든 명부 혼례 부적도 「가진 것」이다(백팩엔 없다)",
		m.inventory.count_of(ItemCatalog.MYEONGBU_CHARM) == 0
		and m._stored_anywhere(ItemCatalog.MYEONGBU_CHARM))
	_check("⑦b 발급 게이트가 그 술어를 본다 — 강림 [F] 연타로 두 번째 부적이 안 나온다",
		not m._myeongbu_quest_open()
		and _line_of("and not _stored_anywhere(ItemCatalog.MYEONGBU_CHARM)") >= 0)
	_check("⑦c 백팩만 보던 옛 판정은 두 창구 어디에도 안 남았다",
		_line_of("and not inventory.has_item(ItemCatalog.MYEONGBU_CHARM)") < 0
		and _line_of("if inventory.has_item(ItemCatalog.MOUNT_WHISTLE):") < 0)

	var save1 := SaveManager.slot_path(1)
	if FileAccess.file_exists(save1):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save1))
	if FileAccess.file_exists(save0):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save0))
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(0 if _fail == 0 else 1)
