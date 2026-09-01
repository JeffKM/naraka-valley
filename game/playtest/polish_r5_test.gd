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
# ══ 배치 B(발견 #14~#26) — 세이브 스컴 · 왕복 완전성 · 달력 중첩 ══════════════
#   ⑧ #14 수확 품질 롤 · ⑨ #15 다수확 개수·운 바이어스 · ⑩ #16 채집 더블드랍 3창구
#      → 셋 다 **전역 RNG**였다. 전역 스트림은 세이브에 안 실리고 `_load_game`이 되감지도 않아
#        F9 한 번마다 같은 사건이 다시 굴렀다(저장→집행→로드를 반복하면 확률이 무의미해진다).
#        이제 셋 다 **사건 이름(day·구역·칸)으로 시드**를 잡는다 — 로드해도 답이 하나다.
#   ⑪ #17 일련번호 시드 4종(캐스팅·체키·칵테일·타격)이 세이브에 실린다(geode_opened의 그 계약).
#   ⑫ #18 배우자 이주 스테이션 · ⑬ #19 앵커 트랙 · ⑭ #20 카페 당일 원장 · ⑮ #21 안방 확장
#      → 넷 다 **편도 복원**이었다(여는 경로만 있고 닫는 경로가 없다). 로드는 양방향이어야 한다.
#   ⑯ #22 곳간 장원제가 그날 곳간 창구를 통째로 봉쇄하던 자리(출품은 재고를 안 줄이는데도).
#   ⑰ #23 생일이 주 첫날과 겹친 주민은 그 주 절기 물음을 통째로 잃었다(미룰 다음 날이 없었다).
#   ⑱ #24 절기 마지막 날 게시된 일일 어종 의뢰가 기한 이틀째에 이행 불가가 되던 자리.
#   ⑲ #25 보부상 예고 — 계약이 적힌 두 파생 함수가 런타임 무호출이었다.
#   ⑳ #26 사료풀 밭이 `_scatter_forbidden` 목록에 빠져 능선 나무가 네 칸을 영구 은폐하던 자리.
#
# ★ 달력 중첩(⑯~⑱)은 **사건 술어의 교집합에서 day를 센다** — 분모도 날짜도 하드코딩하지 않는다
#   (술어가 바뀌면 테스트가 따라 움직이고, 교집합이 비면 그 사실 자체를 실패로 낸다).
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

# 안식 농원에서 아직 안 갈린 빈 밭칸 1개(activity_test의 그 헬퍼 동형 — 과수 풋프린트도 피한다).
func _free_home_soil(m: Node) -> Vector2i:
	for y in range(1, m._grid_h - 1):
		for x in range(1, m._grid_w - 1):
			var t := Vector2i(x, y)
			if not m.farm.is_tilled(t) and not m._is_tree_blocked(t) \
					and m.orchard.tree_at(t) == Orchard.TREE_NONE and not m._pot_at(t) \
					and not m.ranch.has_animal(t):
				return t
	return Vector2i(-1, -1)

# 백팩에 든 그 작물 수확물의 [총 개수, 정렬된 등급열] — 수확 한 번의 **결과 지문**이다.
func _harvest_tally(m: Node, crop: String) -> Array:
	var hid := ItemCatalog.harvest_id(crop)
	var n := 0
	var quals: Array = []
	for i in m.inventory.slots.size():
		var sl: Variant = m.inventory.slots[i]
		if sl != null and String(sl["id"]) == hid:
			n += int(sl["count"])
			quals.append(int(sl.get("quality", 0)))
	quals.sort()
	return [n, quals]

# 지금 안방 귀가 스테이션이 스케줄에 박힌 주민 id들(명단이 아니라 **술어**로 훑는다).
func _station_holders(m: Node) -> Array:
	var out: Array = []
	for r in m._residents:
		for e in r.schedule:
			if e.get("tile", Resident.UNPLACED) == m.SPOUSE_HOME_TILE:
				out.append(r.id)
				break
	out.sort()
	return out

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

	# ══════════ 배치 B(발견 #14~#26) ══════════════════════════════════════════

	# ── ⑧ #14 수확 품질 롤이 사건에 묶인다(F9 재롤 차단) ─────────────────────
	print("── ⑧ #14 품질 롤 — 로드해도 답이 하나 ──")
	var st := FertilizerCatalog.STATE_DELUXE
	_check("⑧a 같은 tag는 같은 등급이다 — 이것이 계약의 전부다",
		FertilizerCatalog.roll_quality_seeded(st, "d1:home:3:4")
			== FertilizerCatalog.roll_quality_seeded(st, "d1:home:3:4"))
	# 결정적이되 **상수가 아니다** — 롤이 죽으면 위 단언은 통과하면서 게임만 망가진다.
	var q_seen: Dictionary = {}
	for i in 200:
		q_seen[FertilizerCatalog.roll_quality_seeded(st, "d:%d" % i)] = true
	_check("⑧b tag가 갈리면 등급도 갈린다 — DELUXE 200표본이 %d종(0..3 중)을 낸다" % q_seen.size(),
		q_seen.size() >= 3)
	# 라이브 왕복 — 저장·수확·로드·재수확이 같은 지문을 낸다(재현 시나리오 그대로).
	var multi := ""
	for cid in CropCatalog.ids():
		var yrr: Vector2i = CropCatalog.yield_range(String(cid))
		if yrr.y > yrr.x and not CropCatalog.is_wild(String(cid)):
			multi = String(cid)
			break
	_check("⑧c-pre 무대: 다수확 작물이 로스터에 있다(%s — 품질·개수 두 축을 한 번에 잰다)" % multi,
		multi != "")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	var soil := _free_home_soil(m)
	m.farm.hoe(soil)
	m.farm.fertilize(soil, FertilizerCatalog.FERT_DELUXE)
	m.farm.plant(soil, multi)
	m.farm._tiles[soil]["grown_days"] = 99
	m._target = soil
	m.energy.current = m.energy.MAX
	_clear_backpack(m)
	m._active_slot = 1
	m._save_game()
	_check("⑧c-pre2 무대: 그 칸이 고급 비료를 먹은 채 다 자랐다(품질 roll에 실제로 닿는다) — %s"
			% str(soil),
		soil.x >= 0 and m.farm.is_mature(soil)
		and m.farm.fertilizer_of(soil) == FertilizerCatalog.FERT_DELUXE)
	_check("⑧c 수확이 성립한다", m._try_harvest())
	var take1 := _harvest_tally(m, multi)
	m._load_game()
	m._target = soil
	m.energy.current = m.energy.MAX
	_check("⑧d-pre F9가 그 칸을 다시 「다 자람」으로 되돌린다(재롤 시나리오의 전제)",
		m.farm.is_mature(soil) and _harvest_tally(m, multi) == [0, []])
	_check("⑧d 다시 수확하면 **같은 개수·같은 등급**이다 %s(전엔 로드마다 재롤됐다)" % str(take1),
		m._try_harvest() and _harvest_tally(m, multi) == take1)
	_check("⑧e 개수가 그 작물의 yield_range 안이다 %s(결정화가 범위를 안 깨뜨린다)"
			% str(CropCatalog.yield_range(multi)),
		int(take1[0]) >= CropCatalog.yield_range(multi).x
		and int(take1[0]) <= CropCatalog.yield_range(multi).y)
	_check("⑧f 전역 RNG 래퍼는 수확 경로에서 사라졌다(카탈로그 분포 표본용으로만 남는다)",
		_line_of("var quality := field.roll_quality(_target, harvest_tag)") >= 0
		and _line_of("field.roll_quality(_target)") < 0)   # 인자 하나짜리 옛 호출 형태가 안 남았다

	# ── ⑨ #15 다수확 개수·명부의 운 바이어스 ────────────────────────────────
	print("── ⑨ #15 개수 롤·운 바이어스도 같은 시드 스트림 ──")
	_check("⑨a 개수 롤이 사건 시드에서 나온다(bare randi_range 소멸)",
		_line_of("var count := yrng.randi_range(yr.x, yr.y)") >= 0
		and _line_of("var count := randi_range(yr.x, yr.y)") < 0)
	_check("⑨b 운 바이어스도 같은 스트림에서 뽑는다(전역 randf 소멸)",
		_line_of("DailyLuck.biased_yield(count, yr.x, yr.y, crop_luck, yrng.randf())") >= 0
		and _line_of("crop_luck, randf())") < 0)

	# ── ⑩ #16 채집 더블드랍 3창구 ───────────────────────────────────────────
	print("── ⑩ #16 더블드랍 — 세 창구가 한 시드 규율을 쓴다 ──")
	var dd_prof := ""
	for pr in ProfessionCatalog.professions_for(ProfessionCatalog.FORAGING):
		for perk in ProfessionCatalog.perks_of(ProfessionCatalog.FORAGING, String(pr["id"])):
			if String(perk["dim"]) == ProfessionCatalog.DIM_DOUBLE_DROP:
				dd_prof = String(pr["id"])
	_check("⑩a-pre 무대: 더블드랍 퍼크를 든 전문직이 로스터에 있다(%s) — 확률 0이면 롤 자체가 없다"
			% ProfessionCatalog.name_of(ProfessionCatalog.FORAGING, dd_prof), dd_prof != "")
	m._professions[ProfessionCatalog.FORAGING] = {
		ProfessionCatalog.tier_of(ProfessionCatalog.FORAGING, dd_prof): dd_prof}
	_check("⑩a 그 퍼크를 들면 확률이 0보다 크다(%.2f — 롤에 실제로 닿는다)"
			% m.forage_double_drop_chance(), m.forage_double_drop_chance() > 0.0)
	var dd_t := Vector2i(9, 9)
	_check("⑩b 같은 창구·같은 칸은 몇 번을 물어도 같은 답이다(F9 재롤 차단)",
		m._forage_double_drop("pick", dd_t) == m._forage_double_drop("pick", dd_t)
		and m._forage_double_drop("pick", dd_t) == m._forage_double_drop("pick", dd_t))
	# 결정적이되 상수가 아님 + 창구가 서로 독립임을 **둘 다** 못 박는다.
	var dd_true := 0
	var dd_split := false
	for i in 120:
		var tt := Vector2i(i % 40 + 1, i / 40 + 1)
		if m._forage_double_drop("pick", tt):
			dd_true += 1
		if m._forage_double_drop("pick", tt) != m._forage_double_drop("wild", tt):
			dd_split = true
	_check("⑩c 칸이 갈리면 답도 갈린다 — 120칸 중 %d칸이 참(상수 아님)" % dd_true,
		dd_true > 0 and dd_true < 120)
	_check("⑩d 창구 셋은 서로 독립 시드다(꽃 패치의 결과가 야생 수확을 미리 알려 주지 않는다)",
		dd_split)
	m._professions.erase(ProfessionCatalog.FORAGING)
	_check("⑩e 퍼크가 없으면 롤 자체가 없다(확률 0 = 종전 거동 보존)",
		not m._forage_double_drop("pick", dd_t))
	var dd_missing: Array = []
	for src in ["flower", "wild", "pick"]:
		if _line_of("_forage_double_drop(\"%s\"" % src) < 0:
			dd_missing.append(src)
	_check("⑩f 세 창구 전부 그 헬퍼를 쓴다 — 전역 randf 호출이 한 곳도 안 남았다(누락: %s)"
			% str(dd_missing),
		dd_missing.is_empty() and _line_of("randf() < forage_double_drop_chance()") < 0)

	# ── ⑪ #17 일련번호 시드 4종의 세이브 왕복 ───────────────────────────────
	print("── ⑪ #17 캐스팅·체키·칵테일·타격 시드가 세이브를 건넌다 ──")
	m._cast_serial = 37
	m._cheki_serial = 11
	m._cocktail_serial = 5
	m._combat_swings = 91
	m._save_game()
	m._cast_serial = 0
	m._cheki_serial = 0
	m._cocktail_serial = 0
	m._combat_swings = 0
	m._load_game()
	_check("⑪a 네 시드가 전부 되감긴다 — 로드 뒤 같은 칸·같은 분의 캐스팅이 같은 답을 낸다",
		m._cast_serial == 37 and m._cheki_serial == 11
		and m._cocktail_serial == 5 and m._combat_swings == 91)
	_check("⑪b 구세이브(키 부재)는 0에서 다시 센다 — 진행과 모순 없는 폴백",
		_line_of("_cast_serial = maxi(int(data.get(\"cast_serial\", 0)), 0)") >= 0
		and _line_of("\"cast_serial\": _cast_serial,") >= 0)

	# ── ⑫ #18 배우자 이주 스테이션의 로드 역연산 ────────────────────────────
	print("── ⑫ #18 로드가 안방 스테이션을 걷는다 ──")
	m._spouse_id = ""
	m._romance_partner = ""
	m._clear_all_spouse_home_stations()
	m._save_game()                       # ← 미혼 슬롯
	_check("⑫a-pre 무대: 미혼 세이브를 떠 두었고 지금 안방에 선 사람이 없다",
		_station_holders(m).is_empty())
	m._romance_partner = "miho"
	m._spouse_id = "miho"
	m._apply_spouse_home_station()
	_check("⑫a 혼인하면 그 사람만 안방 스테이션을 갖는다 — %s" % str(_station_holders(m)),
		_station_holders(m) == ["miho"])
	m._load_game()
	_check("⑫b 미혼 슬롯을 로드하면 **스케줄에서도 걷힌다**(전엔 몸만 안방에 남았다) — %s"
			% str(_station_holders(m)),
		m._spouse_id == "" and _station_holders(m).is_empty())
	# 재현 ② — 다른 이와 혼인한 슬롯을 로드해도 둘이 겹쳐 서지 않는다.
	m._romance_partner = "mel"
	m._spouse_id = "mel"
	m._apply_spouse_home_station()
	m._save_game()                       # ← 멜과 혼인한 슬롯
	m._romance_partner = "miho"
	m._spouse_id = "miho"
	m._apply_spouse_home_station()
	_check("⑫c-pre 무대: 지금 세션엔 미호 항목이 (멜 것과 함께) 서 있다 — %s"
			% str(_station_holders(m)), _station_holders(m).has("miho"))
	m._load_game()
	_check("⑫d 멜 슬롯을 로드하면 멜 하나만 남는다(중복 가드가 못 보던 남의 항목까지 걷힌다) — %s"
			% str(_station_holders(m)),
		m._spouse_id == "mel" and _station_holders(m) == ["mel"])
	m._spouse_id = ""
	m._romance_partner = ""
	m._clear_all_spouse_home_stations()

	# ── ⑬ #19 앵커 트랙의 폐쇄 역연산 ───────────────────────────────────────
	print("── ⑬ #19 B6 이전 세이브를 로드하면 앵커 트랙이 닫힌다 ──")
	var okja: Resident = m._resident(m.OKJA_RID)
	m._spine_bits = 0
	m._save_game()                       # ← 척추를 시작도 안 한 슬롯
	m._open_okja_track()
	_check("⑬a-pre 무대: 트랙이 열려 Affinity 노드·세이브 키·효과 줄이 붙었다",
		okja.affinity != null and okja.save_key == "okja_affinity" and okja.effect_fn.is_valid())
	m._load_game()
	_check("⑬b B6 이전 슬롯을 로드하면 트랙이 통째로 걷힌다 — 관계 탭 표시 자격(affinity != null)이 사라진다",
		okja.affinity == null and okja.save_key == "" and not okja.effect_fn.is_valid())
	# 반대 방향도 산다 — 폐쇄가 개통을 잡아먹으면 그게 더 큰 사고다.
	m._spine_bits = (1 << m.SPINE_B6)
	m._save_game()
	m._close_okja_track()
	m._load_game()
	_check("⑬c B6를 지난 슬롯은 그대로 개통된다(폐쇄가 개통을 잡아먹지 않는다)",
		okja.affinity != null and okja.save_key == "okja_affinity")
	m._spine_bits = 0
	m._close_okja_track()

	# ── ⑭ #20 카페 당일 접객 원장의 왕복 ────────────────────────────────────
	print("── ⑭ #20 영업 중 저장→재시작이 단골 원장을 두 번 적립하지 않는다 ──")
	var g_id := ""
	for rid in m._residents_by_id:
		g_id = String(rid)
		break
	m.cafe.day = m.clock.day
	m.cafe._ledger_day = m.clock.day
	m.cafe._spawned_today = 5
	m.cafe._guests_today = [g_id]
	m.cafe._today_revenue = 1234
	m.cafe._today_served = 3
	m._save_game()
	m.cafe._ledger_day = 0
	m.cafe._spawned_today = 0
	m.cafe._guests_today = []
	m.cafe._today_revenue = 0
	m.cafe._today_served = 0
	m._load_game()
	m.cafe.day = m.clock.day
	_check("⑭a 하루치 원장이 세이브를 건넌다 — serial %d · 다녀간 손님 %s · 매출 %d"
			% [m.cafe._spawned_today, str(m.cafe._guests_today), m.cafe._today_revenue],
		m.cafe._spawned_today == 5 and m.cafe._guests_today == [g_id]
		and m.cafe._today_revenue == 1234 and m.cafe._today_served == 3)
	m.cafe._open_shop()
	_check("⑭b 같은 날 영업이 다시 열려도 원장을 안 민다 — 손님 열이 serial 0부터 재생되지 않는다",
		m.cafe._spawned_today == 5 and m.cafe._guests_today == [g_id]
		and m.cafe._today_revenue == 1234)
	m.cafe.day = m.clock.day + 1
	m.cafe._open_shop()
	_check("⑭c 날이 갈리면 그때 민다(하루 1인 1회 규칙이 하루에 갇힌다)",
		m.cafe._spawned_today == 0 and m.cafe._guests_today.is_empty()
		and m.cafe._today_revenue == 0 and m.cafe._ledger_day == m.clock.day + 1)
	m.cafe.day = m.clock.day
	m.cafe.end_day()

	# ── ⑮ #21 안방 확장 경계가 양방향이다 ───────────────────────────────────
	print("── ⑮ #21 좁아지는 방향도 배치 경계를 다시 잡는다 ──")
	var base_rect: Rect2i = m.home_house_rect()
	var base_cells: int = m.home_deco._floor_cells.size()
	m.carpenter._done[Carpenter.PROJ_MASTER_ROOM] = true
	m._refresh_home_expansion()
	var wide_rect: Rect2i = m.home_house_rect()
	var wide_cells: int = m.home_deco._floor_cells.size()
	_check("⑮a-pre 무대: 확장 rect가 실제로 더 넓다 %s → %s(칸 %d → %d)"
			% [str(base_rect), str(wide_rect), base_cells, wide_cells],
		wide_rect != base_rect and wide_cells > base_cells)
	# 확장 rect에만 있는 칸 하나를 술어로 고른다(좌표 하드코딩 0).
	var only_wide := Vector2i(-1, -1)
	for cell in m.home_deco._floor_cells:
		if not base_rect.has_point(cell):
			only_wide = cell
			break
	_check("⑮b-pre 무대: 확장 rect에만 있는 바닥 칸이 있다 %s" % str(only_wide), only_wide.x >= 0)
	m.carpenter._done.erase(Carpenter.PROJ_MASTER_ROOM)
	m._refresh_home_expansion()
	_check("⑮c 확장 전 세이브를 로드하면 경계도 함께 줄어든다(칸 %d → %d)"
			% [wide_cells, m.home_deco._floor_cells.size()],
		m.home_deco._floor_cells.size() == base_cells and m.home_house_rect() == base_rect)
	# 배치 검증의 유일한 게이트가 이 칸 집합이다(home_deco.gd: `if not _cells_for(layer).has(cell)`).
	_check("⑮d 그래서 줄어든 방의 **벽 너머 칸엔 이제 못 놓는다** %s(전엔 놓였고 세이브에 굳었다)"
			% str(only_wide),
		not m.home_deco._cells_for(HomeDecoCatalog.L_FLOOR).has(only_wide))
	# 소스 관례(peddler_test ⑫) — 함수 첫 줄이 곧바로 bounds 재주입이다(편도 가드가 없다).
	var hx_i := _line_of("func _refresh_home_expansion() -> void:")
	_check("⑮e 편도 가드가 소스에서 사라졌다 — 함수(main.gd:%d) 다음 줄이 곧 bounds 재주입" % (hx_i + 1),
		hx_i >= 0 and _src[hx_i + 1].contains("_configure_home_deco_bounds()"))

	# ── ⑯ #22 곳간 장원제 ↔ 적재 창구 ───────────────────────────────────────
	print("── ⑯ #22 장원제 당일에도 곳간을 열 수 있다 ──")
	var grange_days: Array = []
	for d in range(1, GameClock.DAYS_PER_SEASON * 4 + 1):
		if SeasonalEvent.event_for_day(d) == SeasonalEvent.GRANGE:
			grange_days.append(d)
	_check("⑯a-pre 무대: 1년차에 장원제 day가 실제로 있다 %s(술어에서 셌다 — 날짜 하드코딩 0)"
			% str(grange_days), not grange_days.is_empty())
	var gday: int = int(grange_days[0])
	var saved_day: int = m.clock.day
	m.clock.day = gday
	_check("⑯b 그날 창구 판정이 장원제로 선다", m._seasonal_event_today() == SeasonalEvent.GRANGE)
	m.seasonal_event.grange_day = 0        # 출품 이력 리셋(같은 날 재출품 차단만 되돌린다)
	while m.larder.total() > 0:
		var lid := String(m.larder.ids()[0])
		m.larder.take_back(lid, m.larder.count_of(lid))
	_check("⑯c 곳간이 비면 출품이 **성립하지 않는다**(false) — 그 [F]는 적재 패널로 흐른다",
		not m._try_grange_entry())
	m.larder.add(ItemCatalog.harvest_id(multi), 3)
	_check("⑯d-pre 무대: 곳간에 출품거리가 생겼다(%d종)" % m.larder.ids().size(),
		m.larder.ids().size() > 0)
	_check("⑯e 재고가 있으면 출품이 성립한다(true) — 그때만 창구를 가로챈다",
		m._try_grange_entry() and m.seasonal_event.grange_entered(gday))
	_check("⑯f 출품을 마친 뒤엔 다시 false다 — 그날 남은 시간 내내 곳간을 열 수 있다",
		not m._try_grange_entry())
	_check("⑯g 출품이 재고를 한 톨도 안 줄인다(설계 의도 — 경연이 카페 공급망을 안 비운다)",
		m.larder.count_of(ItemCatalog.harvest_id(multi)) == 3)
	_check("⑯h 디스패치가 그 반환값을 본다 — 실패하면 CTX_LARDER로 흐른다",
		_line_of("if _seasonal_event_today() != SeasonalEvent.GRANGE or not _try_grange_entry():") >= 0)
	m.clock.day = saved_day

	# ── ⑰ #23 생일 ∩ 주 첫날의 절기 물음 ────────────────────────────────────
	print("── ⑰ #23 생일이 주 첫날을 먹어도 그 주 물음이 사라지지 않는다 ──")
	var collide: Array = []
	for rid in Resident.BIRTHDAYS:
		var bd: Array = Array(Resident.BIRTHDAYS[rid])
		var bday: int = int(bd[0]) * GameClock.DAYS_PER_SEASON + int(bd[1])
		if (bday - 1) % GameClock.DAYS_PER_WEEK == 0:
			collide.append([String(rid), bday])
	_check("⑰a-pre 무대: 생일이 주 첫날에 앉은 주민이 실제로 있다 %s(술어 교집합에서 셌다)"
			% str(collide), not collide.is_empty())
	var q_lost: Array = []
	var q_saved: Array = []
	var q_tested: Array = []
	for pair in collide:
		var rid2 := String(pair[0])
		var bday2: int = int(pair[1])
		var rr: Resident = m._resident(rid2)
		if rr == null or rr.node == null or not rr.node.has_method("season_question"):
			continue
		if typeof(rr.node.season_question(
				GameClock.season_index_for_day(bday2))) != TYPE_DICTIONARY:
			continue
		if String((rr.node.season_question(
				GameClock.season_index_for_day(bday2)) as Dictionary).get("line", "")) == "":
			continue                     # 그 절기 물음이 아직 안 쓰인 캐릭터 — 잴 것이 없다
		q_tested.append(rid2)
		m._confess_rid = ""
		m._season_q_week.erase(rid2)
		m.clock.day = bday2
		if not m._pending_season_question(rr, PackedStringArray()).is_empty():
			q_lost.append(rid2)          # 생일 당일엔 물음이 안 서야 한다(우선순위 불변)
		m.clock.day = bday2 + 1
		if m._pending_season_question(rr, PackedStringArray()).is_empty():
			q_saved.append(rid2)         # 다음 날 회수되어야 한다(이 수정의 본체)
	_check("⑰a2-pre 무대: 그중 실제로 절기 물음을 든 주민이 있다 %s(공회전 단언 방지)"
			% str(q_tested), not q_tested.is_empty())
	_check("⑰b 생일 당일엔 여전히 물음이 안 선다(우선순위 관문>생일>물음 불변 — 어긋남: %s)"
			% str(q_lost), q_lost.is_empty())
	_check("⑰c 그 주 다음 날에 물음이 회수된다(전엔 그 주가 통째로 사라졌다 — 어긋남: %s)"
			% str(q_saved), q_saved.is_empty())
	# 생일과 무관한 주에는 주 첫날 고정이 그대로다(가드가 넓어진 게 아니다).
	# ★ 대조군은 **물음을 실제로 든 비-충돌 주민**이어야 한다 — 훅이 없는 사람을 고르면 첫 가드에서
	#   걸려 무엇을 재도 통과하는 공회전 단언이 된다(그 함정을 한 번 밟은 자리).
	var plain_id := ""
	for rid3 in m._residents_by_id:
		var cand: Resident = m._resident(String(rid3))
		var bd3: Array = Array(Resident.BIRTHDAYS.get(String(rid3), []))
		if cand == null or cand.node == null or not cand.node.has_method("season_question") \
				or bd3.size() < 2:
			continue
		var cday: int = int(bd3[0]) * GameClock.DAYS_PER_SEASON + int(bd3[1])
		if (cday - 1) % GameClock.DAYS_PER_WEEK == 0:
			continue                     # 충돌 주민은 대조군이 못 된다
		plain_id = String(rid3)
		break
	_check("⑰d-pre 무대: 대조군 = 물음을 들었고 생일이 주 첫날이 아닌 주민(%s)" % plain_id,
		plain_id != "")
	var plain: Resident = m._resident(plain_id)
	m._confess_rid = ""
	m._season_q_week.erase(plain_id)
	m.clock.day = 2                      # 주 첫날이 아니고 그 사람 생일도 아니다
	_check("⑰d 그 사람도 평범한 주의 이틀째엔 안 묻는다(주 첫날 고정이 살아 있다)",
		m._pending_season_question(plain, PackedStringArray()).is_empty())
	m._season_q_week.erase(plain_id)
	m.clock.day = 1                      # 주 첫날 — 같은 사람이 여기선 실제로 묻는다
	_check("⑰e 같은 사람이 주 첫날엔 실제로 묻는다(가드가 물음을 통째로 막은 게 아니다)",
		not m._pending_season_question(plain, PackedStringArray()).is_empty())
	m.clock.day = saved_day

	# ── ⑱ #24 절기 마지막 날의 일일 어종 의뢰 ───────────────────────────────
	print("── ⑱ #24 기한 이틀째에 절기 밖으로 나가는 어종을 안 낸다 ──")
	var edge_days: Array = []
	var edge_bad: Array = []
	for d in range(1, GameClock.DAYS_PER_SEASON * 8 + 1):
		if not GameClock.is_season_last_day(d):
			continue
		if not QuestBoard._is_fish_day(QuestBoard.KIND_DAILY, d):
			continue
		var q2 := QuestBoard.daily_quest(d)
		if q2.is_empty() or not FishCatalog.has(String(q2["item_id"])):
			continue
		edge_days.append(d)
		var fseasons: Array = FishCatalog.FISH[String(q2["item_id"])]["seasons"]
		var due_season := GameClock.season_index_for_day(int(q2["due_day"]))
		if not fseasons.is_empty() and not fseasons.has(due_season):
			edge_bad.append([d, String(q2["item_id"])])
	_check("⑱a-pre 무대: 절기 마지막 날에 실제로 어종 의뢰가 걸리는 day가 있다 %s(2년치 술어 스캔)"
			% str(edge_days), not edge_days.is_empty())
	_check("⑱b 그 어종들은 전부 기한 마지막 날의 절기에서도 낚인다(이행 불가 의뢰 0 — 어긋남: %s)"
			% str(edge_bad), edge_bad.is_empty())
	_check("⑱c 절기 안에 온전히 든 기한은 풀이 한 톨도 안 바뀐다(중기 의뢰·평일 무영향)",
		FishCatalog.quest_pool(0, FishCatalog.WC_MEDIUM)
			== FishCatalog.quest_pool(0, FishCatalog.WC_MEDIUM, 0))

	# ── ⑲ #25 보부상 예고 ───────────────────────────────────────────────────
	print("── ⑲ #25 좌판이 서기 전에 알 수 있다 ──")
	var ped_day: int = Peddler.APPEAR_MODULUS
	m.clock.day = ped_day - 1
	_check("⑲a 하루 전 아침에 D-1 예고가 뜬다(형제 두 층이 이미 쓰는 문법) — 「%s」"
			% m._peddler_morning_notice(),
		m._peddler_morning_notice().contains("내일") and Peddler.days_until(m.clock.day) == 1)
	_check("⑲b 점괘 거울이 그 줄을 함께 싣는다 — 「%s」" % m._peddler_upcoming_line(),
		m._peddler_upcoming_line() != ""
		and m._mirror_forecast_text().contains(m._peddler_upcoming_line()))
	m.clock.day = ped_day
	_check("⑲c 당일엔 「오늘」로 갈린다(예고와 개막이 한 문법에서 갈린다)",
		Peddler.days_until(m.clock.day) == 0 and m._peddler_upcoming_line().contains("오늘")
		and m._peddler_morning_notice().contains("오늘"))
	_check("⑲d 계약이 적혀 있던 두 파생 함수에 런타임 호출부가 생겼다(playtest 밖에서)",
		_line_of("Peddler.days_until(clock.day)") >= 0
		and _line_of("Peddler.is_open_day(clock.day + 1)") >= 0)
	m.clock.day = saved_day

	# ── ⑳ #26 사료풀 밭이 절차 스캐터에 안 깔린다 ──────────────────────────
	print("── ⑳ #26 능선 나무가 사료풀 밭을 덮지 않는다 ──")
	var frect: Rect2i = m.FORAGE_SCAN_RECT
	var not_forbidden: Array = []
	for y in range(frect.position.y, frect.end.y):
		for x in range(frect.position.x, frect.end.x):
			if not m._scatter_forbidden(Vector2i(x, y)):
				not_forbidden.append(Vector2i(x, y))
	_check("⑳a 사료풀 밭 %d칸 전부가 금지 rect 안이다(빠진 칸: %s)"
			% [frect.size.x * frect.size.y, str(not_forbidden)], not_forbidden.is_empty())
	# 진짜 불변식 — **실제로 생성된 프롭 풋프린트**가 그 밭에 한 칸도 안 겹친다.
	_check("⑳b-pre 무대: 안식 절차 스캐터가 실제로 깔려 있다(%d묶음 — 공회전 단언 방지)"
			% m._home_scatter.size(), not m._home_scatter.is_empty())
	var overlap: Array = []
	for entry in m._home_scatter:
		var tex: Texture2D = entry[0]
		for anch in entry[1]:
			for ft in m._scatter_footprint(tex, anch):
				if frect.has_point(ft):
					overlap.append([str(anch), str(ft), tex.resource_path.get_file()])
	_check("⑳c 프롭 풋프린트가 사료풀 밭과 한 칸도 안 겹친다(전엔 (18,22) 혼의 나무가 네 칸을 영구 은폐 — 겹침: %s)"
			% str(overlap), overlap.is_empty())
	# 밭 자체는 그대로 산다(금지 rect가 시드까지 죽이면 그게 더 큰 사고다).
	var seeded := 0
	for y in range(frect.position.y, frect.end.y):
		for x in range(frect.position.x, frect.end.x):
			if m.forage.has_forage(Vector2i(x, y)):
				seeded += 1
	_check("⑳d 사료풀은 그대로 시드된다(%d칸) — 금지는 프롭에만 걸린다" % seeded, seeded > 0)

	var save1 := SaveManager.slot_path(1)
	if FileAccess.file_exists(save1):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save1))
	if FileAccess.file_exists(save0):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save0))
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(0 if _fail == 0 else 1)
