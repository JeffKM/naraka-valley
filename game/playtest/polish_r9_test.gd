extends SceneTree
# ★[폴리시 9회차] 버그 헌트 확정분 회귀 — 배치 A(#1~#12).
#
# 렌즈: 농사 사슬(화분·급수 시점·비료·손상 세이브) · 카페 사슬(F9 되감기) · 상점 창구 교차
#       (클릭 라우팅·게이트 우회·처분 창구) · 신규 API 스윕(산출 적재·술어 일관성).
#
# 무엇을 보증하나(발견 번호 = 9회차 헌트 배치 A):
#   ① #1  화분에 야생 씨앗을 심으면 수확이 **채집 치환을 안 타** 판매가 0·XP 0의 유령 아이템이
#         됐다(밭에 심으면 실제 채집종이 나온다 — 같은 씨앗의 결과가 그릇에 따라 갈렸다).
#   ② #2  스프링클러 급수가 `advance_day` **앞**이라 같은 아침의 마름 패스에 곧바로 말랐다:
#         밭 오버레이는 종일 마른 흙을 그리고, 배우자 아침 물주기 8칸이 그 칸을 잠식했다.
#   ③ #3  같은 비료 재도포에 멱등 가드가 없어, 칸 상태가 그대로인 채 값비싼 소모품만 계속 탔다.
#   ④ #4  `FarmField.load_save`가 crop id를 검증 안 해, 미지 작물이 실린 칸이 **영구 불능**으로
#         굳었다(성숙 불가·재파종 불가·절기 사멸도 못 지움).
#   ⑤ #5  `Cafe.load_save`가 좌석·`_was_open`을 안 되감아, 아침 8시에 마감 정산 팝업이 뜨고
#         되감긴 원장에 없는 손님이 좌석에 남아 **하루 1인 1회**가 깨졌다.
#   ⑥ #6  **DUP** — 선물 선호표의 음료 칸 도달 불가는 R7 #13(owner 결정 큐 ⓐ)과 같은 사실이다.
#         여기서는 그 경계를 술어로 못 박는다: 곁들이는 손에 들어오고 음료는 안 들어온다(수정 0).
#   ⑦ #7  카페 1~3단 달성 래치가 F9에서 재파생되지 않아, 지난 팝업이 재발화하거나 영영 억제됐다.
#   ⑧ #8  목공방 「짐승 새끼」 행의 kind("livestock")가 프레임 허용 목록에서 빠져 클릭이 죽었다
#         — R7이 연 유일한 짐승 구매 경로가 신호 층에서 불통(같은 클래스 3회차).
#   ⑨ #9  보부상 일반 재고가 갱도 깊이 밴드 너머의 광물을 팔아 채광 깊이 곡선을 우회시켰다.
#   ⑩ #10 카탈로그가 "출하했을 때의 값"이라 선언한 결정기 부품·결정기에 처분 창구가 0이었다.
#   ⑪ #11 벌목 산출만 `can_add` 선검사·실패 처리 없이 지급해, 백팩 만재 시 원목이 조용히 증발하고
#         토스트가 "원목 +2"라고 거짓말을 했다.
#   ⑫ #12 청혼 게이트의 뭍의 비약 판정만 `inventory.has_item` 직행이라, 비약을 상자에 넣으면
#         청혼도 막히고 안내가 가리킨 옥자의 재발급 창구도 안 열렸다(막다른 안내).

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

# main.gd 소스에서 needle이 든 줄의 인덱스(-1 = 없음) — polish_r7/r8의 그 헬퍼.
func _line_of(needle: String) -> int:
	for i in _src.size():
		if _src[i].contains(needle):
			return i
	return -1

func _in_func(fn_needle: String, needle: String) -> bool:
	return _line_in_func(fn_needle, needle) >= 0

# 그 함수 **안에서** needle이 처음 나오는 줄 인덱스(-1 = 그 함수 안엔 없다). 함수 밖의 동명
# 호출에 속지 않으려면 위치 비교는 반드시 이쪽을 쓴다(`_refresh_festival()`처럼 부팅 경로에도
# 같은 줄이 있는 자리 — 전역 `_line_of`로 재면 늘 참인 무의미한 단언이 된다).
func _line_in_func(fn_needle: String, needle: String) -> int:
	var head := _line_of(fn_needle)
	if head < 0:
		return -1
	for i in range(head + 1, _src.size()):
		if _src[i].begins_with("func "):
			return -1
		if _src[i].contains(needle):
			return i
	return -1

# 마지막 알림 줄(notice_feed는 최신이 배열 끝).
func _last_notice(m: Node) -> String:
	var items: Array = m.notice_feed._items
	return "" if items.is_empty() else String(items[items.size() - 1]["text"])

func _wipe_slot(slot: int) -> void:
	var p := SaveManager.slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _initialize() -> void:
	print("══ 폴리시 9회차 배치 A — 농사 사슬 · 카페 사슬 · 상점 교차 · 신규 API 스윕 ══")
	_src = FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().split("\n")
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)

	var m := await _spawn_main()
	_dismiss_dialogue(m)
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)

	# ── ① #1 화분의 야생 씨앗 수확이 채집으로 치환된다 ──────────────────────────
	print("── ① #1 화분 야생 씨앗 — 유령 아이템이 아니라 채집종이 나온다 ──")
	var wild: String = CropCatalog.WILD_PIAN
	var ghost_id := ItemCatalog.harvest_id(wild)
	var common_pool: Array = ForageSpawns.species_for(ForageSpawns.KIND_COMMON,
		CropCatalog.wild_season(wild))
	_check("①pre 야생 모둠(피안)은 화분 심기를 통과하는 카탈로그 작물이고 sell_price = 0이다",
		CropCatalog.has_crop(wild) and CropCatalog.is_wild(wild)
		and CropCatalog.sell_price(wild) == 0 and not common_pool.is_empty())
	var pot_tile := Vector2i(3, 3)
	_check("①pre 빈 화분을 놓고 야생 씨앗을 심는다(프롬프트가 권하는 그 동선)",
		m.garden_pot.place(pot_tile) and m.garden_pot.plant(pot_tile, wild))
	var pot_guard := 0
	while not m.garden_pot.is_mature(pot_tile) and pot_guard < 40:
		m.garden_pot.water(pot_tile)
		m.garden_pot.advance_day()
		pot_guard += 1
	_check("①pre %d일 손 물주기로 성숙" % pot_guard, m.garden_pot.is_mature(pot_tile))
	var ghost_before: int = m.inventory.count_of(ghost_id)
	var forage_xp_before: int = m._foraging_xp
	var species_before: Dictionary = {}
	for sp in common_pool:
		species_before[str(sp)] = m.inventory.count_of(str(sp))
	m._target = pot_tile
	m._harvest_pot()
	var gained_species := ""
	var gained_n := 0
	for sp2 in common_pool:
		var sid := str(sp2)
		var d: int = m.inventory.count_of(sid) - int(species_before[sid])
		if d > 0:
			gained_species = sid
			gained_n = d
	_check("①a 백팩에 들어온 것은 **채집종**이다(%s ×%d — 그 절기 일반종 3종 중 하나)"
			% [gained_species, gained_n],
		gained_species != "" and common_pool.has(gained_species) and gained_n >= 1)
	_check("①b 판매가 0의 유령 작물(%s)은 한 개도 안 들어왔다" % ghost_id,
		m.inventory.count_of(ghost_id) == ghost_before)
	_check("①c 채집 XP가 붙었다(종전엔 sell_price 0 → 농사 XP도 0이었다)",
		m._foraging_xp > forage_xp_before)
	_check("①d 그 종이 채집 발견 원장에 오른다(희소종 씨앗 사슬의 그 축)",
		bool(m._forage_found.get(gained_species, false)))
	_check("①e 화분은 빈 화분으로 되돌아갔다(원장은 화분 쪽이 비었다)",
		m.garden_pot.has_at(pot_tile) and not m.garden_pot.is_planted(pot_tile))
	_check("①f 규칙은 한 곳에 있다 — 화분 갈래가 `_harvest_wild`에 위임한다(분기 복제 0)",
		_in_func("func _harvest_pot", "_harvest_wild(crop, true)"))
	m.garden_pot.remove(pot_tile)

	# ── ② #2 스프링클러 급수가 advance_day 뒤로 옮겨졌다 ────────────────────────
	print("── ② #2 스프링클러 급수 시점 — 젖은 상태가 하루 종일 남는다 ──")
	var ln_grow := _line_in_func("func _on_day_advanced", "farm.advance_day(Foxfire.accel(h)")
	var ln_sprk := _line_in_func("func _on_day_advanced", "for st in sprinkler.watered_targets():")
	var ln_spouse := _line_in_func("func _on_day_advanced", "farm.water_dry(SPOUSE_MIHO_WATER_TILES)")
	var ln_rain := _line_in_func("func _on_day_advanced", "for wt in farm.tilled_tiles():")
	_check("②a 네 지점을 아침 정산 안에서 찾았다(성장 %d · 스프링클러 %d · 혼우 %d · 배우자 %d)"
			% [ln_grow, ln_sprk, ln_rain, ln_spouse],
		ln_grow > 0 and ln_sprk > 0 and ln_rain > 0 and ln_spouse > 0)
	_check("②b 순서 = 성장 판정 → 스프링클러 → 배우자(혼우가 R8에서 옮겨 간 그 자리와 나란히)",
		ln_grow < ln_sprk and ln_sprk < ln_spouse)
	_check("②c 혼우도 여전히 성장 판정 뒤다(R8 회귀 잠금 — 두 급수 창구의 시점이 같아졌다)",
		ln_grow < ln_rain and ln_rain < ln_spouse)
	# 살아 있는 밭 — 스프링클러가 덮은 칸만 젖고, 사거리 밖은 마른다.
	# 무대 좌표는 **손으로 안 적는다**: 경작 가능 칸을 전수로 긁어 그 안에서 고른다(맵이 바뀌면
	# 무대가 따라 움직인다 — 하드코딩 좌표가 stale로 죽는 그 함정 회피).
	var farmable: Array = []
	for y in range(0, 64):
		for x in range(0, 64):
			var t := Vector2i(x, y)
			if m._is_farmable(t):
				farmable.append(t)
	var till_base := Vector2i(-1, -1)
	for cand: Vector2i in farmable:
		if farmable.has(cand + Vector2i(1, 0)) and farmable.has(cand + Vector2i(-1, 0)) \
				and farmable.has(cand + Vector2i(0, 1)) and farmable.has(cand + Vector2i(0, -1)):
			till_base = cand
			break
	var covered: Array = []
	var control := Vector2i(-1, -1)
	var outside: Array = []
	if till_base.x >= 0:
		for off in Sprinkler.CROSS_OFFSETS:
			var ct: Vector2i = till_base + off
			m.farm.hoe(ct)
			covered.append(ct)
		m.sprinkler.place(till_base, Sprinkler.TIER_1)
		var targets: Array = m.sprinkler.watered_targets()
		for t2: Vector2i in farmable:
			if t2 == till_base or targets.has(t2) or covered.has(t2):
				continue
			outside.append(t2)
		if not outside.is_empty():
			control = outside[0]
			m.farm.hoe(control)
	_check("②pre 무대: 경작 가능 %d칸에서 십자 4칸 + 티어1 스프링클러 + 사거리 밖 %d칸 확보"
			% [farmable.size(), outside.size()],
		covered.size() == 4 and control.x >= 0 and m.sprinkler.has_at(till_base)
		and outside.size() > m.SPOUSE_MIHO_WATER_TILES)
	var calm_day := -1
	for d in range(m.clock.day, m.clock.day + 60):
		if Weather.weather_for_day(d) == Weather.CALM:
			calm_day = d
			break
	m.clock.day = calm_day
	m._on_day_advanced(calm_day)
	_check("②pre2 평온일 %d 아침을 지났고 스프링클러가 살아남았다(잡초 파괴 대조)" % calm_day,
		calm_day > 0 and m.sprinkler.has_at(till_base))
	var dry_covered: Array = []
	for ct2: Vector2i in covered:
		if m.farm.is_tilled(ct2) and not m.farm.is_watered(ct2):
			dry_covered.append(ct2)
	_check("②d 아침 정산이 끝난 시점에 스프링클러 칸 4개가 **전부 젖어 있다**(마른 칸 %s)"
			% str(dry_covered),
		dry_covered.is_empty())
	_check("②e 대조군(사거리 밖)은 여전히 마르다 — 젖음이 밭 전체로 새지 않았다",
		m.farm.is_tilled(control) and not m.farm.is_watered(control))
	# 배우자 8칸 예산이 스프링클러 칸을 잠식하지 않는다(아침 정산 뒷부분을 그대로 재현).
	var seed_crop: String = str(CropCatalog.ids()[0])
	var extra: Array = []
	for t3: Vector2i in outside:
		if extra.size() >= m.SPOUSE_MIHO_WATER_TILES + 2:
			break
		m.farm.hoe(t3)
		if m.farm.plant(t3, seed_crop):
			extra.append(t3)
	for ct3: Vector2i in covered:
		m.farm.plant(ct3, seed_crop)
	m.farm.advance_day()                       # 전 칸을 말린다(성장 판정 자리)
	for st: Vector2i in m.sprinkler.watered_targets():
		m._field_at(st).sprinkle(st)           # 그 다음이 스프링클러
	var spouse_n: int = m.farm.water_dry(m.SPOUSE_MIHO_WATER_TILES)
	_check("②pre3 배우자 예산 무대: 사거리 밖 심긴 칸 %d개(예산 %d칸 이상)"
			% [extra.size(), m.SPOUSE_MIHO_WATER_TILES],
		extra.size() >= m.SPOUSE_MIHO_WATER_TILES)
	_check("②f 배우자가 적신 칸 수 = 예산 그대로(%d) — 알림이 말하는 수와 실효가 같다" % spouse_n,
		spouse_n == m.SPOUSE_MIHO_WATER_TILES)
	var wet_outside := 0
	for et: Vector2i in extra:
		if m.farm.is_watered(et):
			wet_outside += 1
	_check("②g 그 예산이 **전부 사거리 밖 칸**에 갔다(젖은 사거리 밖 칸 %d개 = 예산 %d)"
			% [wet_outside, m.SPOUSE_MIHO_WATER_TILES],
		wet_outside == m.SPOUSE_MIHO_WATER_TILES)
	for ct5: Vector2i in covered:
		m.farm.remove_plant(ct5)
	for et2: Vector2i in extra:
		m.farm.remove_plant(et2)
	m.sprinkler.remove(till_base)

	# ── ③ #3 같은 비료 재도포는 무동작(멱등) ──────────────────────────────────
	print("── ③ #3 비료 멱등 가드 — 값비싼 소모품만 예외였던 자리 ──")
	var ferts: Array = FertilizerCatalog.ids()
	var f1 := str(ferts[0]) if ferts.size() > 0 else ""
	var f2 := str(ferts[1]) if ferts.size() > 1 else ""
	var ftile: Vector2i = covered[0]
	_check("③pre 비료 2종을 로스터에서 뽑았다(%s · %s) · 경작 칸 확보" % [f1, f2],
		f1 != "" and f2 != "" and f1 != f2 and m.farm.is_tilled(ftile))
	_check("③a 첫 도포는 성립한다(호출부가 이 true를 차감에 쓴다)", m.farm.fertilize(ftile, f1))
	_check("③b 같은 비료 재도포는 **false**다 — 칸 상태가 같으므로 차감도 없다",
		not m.farm.fertilize(ftile, f1))
	_check("③c 칸의 비료는 그대로 %s다(재도포가 값을 안 바꿨다)" % f1,
		m.farm.fertilizer_of(ftile) == f1)
	_check("③d 다른 비료로의 overwrite는 그대로 성립한다(단일 필드 XOR 문법 불변)",
		m.farm.fertilize(ftile, f2) and m.farm.fertilizer_of(ftile) == f2)
	_check("③e 형제 동사 넷도 같은 가드를 든다(hoe·plant·sprinkle — 관례 대조)",
		not m.farm.hoe(ftile) and not m.farm.plant(ftile, "없는작물")
		and m.farm.sprinkle(ftile) and not m.farm.sprinkle(ftile))
	# 화면이 무동작의 이유를 말한다 — 칸의 비료를 읽는 경로가 main에 한 곳도 없던 자리.
	m.inventory.add_item(f2, 1)
	var fslot := -1
	for i in 40:
		if m.inventory.id_at(i) == f2:
			fslot = i
			break
	m.inventory.selected_index = fslot
	m._target = ftile
	m._target_valid = true
	_check("③f 프롬프트가 재도포를 '이미 뿌려 둔 칸'으로 읽힌다 — '%s'" % m._farm_prompt(),
		fslot >= 0 and m._farm_prompt().contains("이미 뿌려 둔"))
	m.farm.fertilize(ftile, f1)
	_check("③g 다른 비료를 들면 다시 '뿌리기' 안내다 — '%s'" % m._farm_prompt(),
		m._farm_prompt().contains("뿌리기"))
	m.inventory.remove_item(f2, 1)

	# ── ④ #4 손상 세이브의 미지 작물 칸이 영구 불능으로 굳지 않는다 ─────────────
	print("── ④ #4 FarmField.load_save crop 검증 — 영구 불능 칸 방어 ──")
	var bogus := FarmField.new()
	var btile := Vector2i(9, 9)
	bogus.load_save({"tiles": {
		btile: {"planted": true, "watered": false, "crop": "은퇴한작물",
			"grown_days": 3, "fertilizer": f1},
	}})
	_check("④a 미지 작물 칸은 **빈 경작 칸**으로 되돌아온다(흙은 남는다)",
		bogus.is_tilled(btile) and not bogus.is_planted(btile) and bogus.crop_of(btile) == "")
	_check("④b 비료는 보존된다 — 되돌림 폭이 `remove_plant`(작물만 제거)와 같다",
		bogus.fertilizer_of(btile) == f1)
	_check("④c 그래서 그 자리에 바로 다시 심을 수 있다(종전엔 is_planted에 막혀 영영 불능)",
		bogus.plant(btile, seed_crop))
	var known := FarmField.new()
	known.load_save({"tiles": {
		btile: {"planted": true, "watered": true, "crop": seed_crop,
			"grown_days": 2, "fertilizer": ""},
	}})
	_check("④d 정상 세이브는 한 톨도 안 건드린다(심김·젖음·자란 날 2 그대로)",
		known.is_planted(btile) and known.is_watered(btile)
		and known.crop_of(btile) == seed_crop and known.grown_days_of(btile) == 2)
	_check("④e 형제 원장(GardenPot)이 이미 드는 그 가드다 — 문법이 같다",
		FileAccess.open("res://garden_pot.gd", FileAccess.READ).get_as_text()
			.contains("모르는 작물 id는 조용히 빈 화분으로"))
	bogus.free()
	known.free()

	# ── ⑤ #5 카페 F9 — 좌석·영업창 래치 되감기 ────────────────────────────────
	print("── ⑤ #5 Cafe.load_save가 좌석·`_was_open`을 함께 되감는다 ──")
	var cafe_snapshot: Dictionary = m.cafe.to_save()
	m.cafe._was_open = true
	m.cafe._open = true
	m.cafe._seats[0]["occupied"] = true
	m.cafe._seats[0]["guest"] = "유령손님"
	m.cafe._seats[0]["want"] = "americano"
	_check("⑤pre 오염: 영업 중(`_was_open`) + 좌석 0에 명명 손님이 앉아 있다",
		m.cafe._was_open and bool(m.cafe._seats[0]["occupied"])
		and String(m.cafe._seats[0]["guest"]) == "유령손님")
	m.cafe.load_save(cafe_snapshot)
	var occupied_after := 0
	var named_after: Array = []
	for s5 in m.cafe._seats:
		if bool(s5["occupied"]):
			occupied_after += 1
		if String(s5["guest"]) != "":
			named_after.append(String(s5["guest"]))
	_check("⑤a 로드가 좌석을 비운다(앉은 자리 %d · 남은 이름 %s)" % [occupied_after, str(named_after)],
		occupied_after == 0 and named_after.is_empty())
	_check("⑤b 영업창 래치가 false에서 다시 시작한다 — 아침 8시 마감 정산 팝업의 그 원인",
		not m.cafe._was_open and not m.cafe.is_open())
	_check("⑤c 하루치 원장은 그대로 복원된다(되감는 것은 세션뿐 — R5 가드 불변)",
		m.cafe._ledger_day == int(cafe_snapshot["ledger_day"])
		and m.cafe._spawned_today == int(cafe_snapshot["spawned_today"]))
	_check("⑤d 되감는 셋이 `end_day()`와 같다(취침도 로드도 '그 손님들은 이제 없다')",
		FileAccess.open("res://cafe.gd", FileAccess.READ).get_as_text()
			.contains("\t_clear_seats()"))

	# ── ⑥ #6 DUP 경계 고정 — 곁들이는 손에 들어오고 음료는 안 들어온다 ──────────
	print("── ⑥ #6 DUP(R7 #13) — 선물 선호표 음료의 도달 불가 경계를 술어로 고정 ──")
	var side_ids: Array = MenuCatalog.side_dish_ids()
	var drinks: Array = []
	var side_untracked: Array = []
	for mid in MenuCatalog.ids():
		var ms := str(mid)
		if side_ids.has(ms):
			if not Codex.is_tracked(ms):
				side_untracked.append(ms)
			continue
		drinks.append(ms)
	var drink_tracked: Array = []
	for dz in drinks:
		if Codex.is_tracked(str(dz)):
			drink_tracked.append(str(dz))
	_check("⑥a 곁들이 %d종은 도감·출하 축에 있다 — 주방요괴 창구가 실제로 굽는다(밖 %s)"
			% [side_ids.size(), str(side_untracked)],
		side_ids.size() >= 5 and side_untracked.is_empty())
	_check("⑥b 음료 %d종은 전부 그 축 밖 = 인벤 진입 경로 0(선호표가 사문인 그 칸들 — 안 %s)"
			% [drinks.size(), str(drink_tracked)],
		drinks.size() >= 4 and drink_tracked.is_empty())
	_check("⑥c 그중 선호표가 등급을 매긴 음료가 실제로 있다(사문 = 이 교집합)",
		_gift_rated_drinks(drinks) > 0)
	_check("⑥d 이 사실은 **owner 결정 큐 R7 #13**의 재보고다 — 코드로 선점하지 않는다(수정 0)",
		true)

	# ── ⑦ #7 F9가 카페 달성 래치를 다시 판다 ─────────────────────────────────
	print("── ⑦ #7 마일스톤 래치 재파생 ──")
	_check("⑦a `_load_game`이 래치 셋을 다시 판다(부팅 경로 `_ready`와 같은 세 줄)",
		_in_func("func _load_game", "_milestone_celebrated = _milestone_complete()")
		and _in_func("func _load_game", "_milestone2_celebrated = _milestone_stage2_complete()")
		and _in_func("func _load_game", "_milestone3_celebrated = _milestone_stage3_complete()"))
	_check("⑦b 위치가 사다리(`_refresh_festival`) 뒤다 — 단계 판정이 읽는 누적 축이 그때 복원된다",
		_line_in_func("func _load_game", "_milestone_celebrated = _milestone_complete()")
			> _line_in_func("func _load_game", "_refresh_festival()"))
	m._active_slot = 0
	m._save_game()
	m._milestone_celebrated = true
	m._milestone2_celebrated = true
	m._milestone3_celebrated = true
	var loaded: bool = m._load_game()
	_check("⑦pre 1단 미달 세이브를 저장·재로드했다", loaded and not m._milestone_complete())
	_check("⑦c 미달 세이브를 불러오면 래치 셋이 전부 false로 되감긴다(영구 억제 해소)",
		not m._milestone_celebrated and not m._milestone2_celebrated
		and not m._milestone3_celebrated)
	# 세 축을 전부 상한까지 밀어 실제 달성 상태를 만든다(하트 축은 최고 수위 원장이 진실원).
	m._run_harvested = 100000
	m._cafe_revenue_total = 100000000
	m._milestone_hearts_peak = 100
	m._save_game()
	m._milestone_celebrated = false
	m._milestone2_celebrated = false
	m._load_game()
	_check("⑦d 달성 세이브를 불러오면 래치가 켜져 온다 — 지난 팝업이 다시 안 터진다(1단 %s · 2단 %s)"
			% [str(m._milestone_celebrated), str(m._milestone2_celebrated)],
		m._milestone_complete() and m._milestone_celebrated
		and m._milestone2_celebrated == m._milestone_stage2_complete())
	for s6 in SaveManager.SLOT_COUNT:
		_wipe_slot(s6)

	# ── ⑧ #8 목공방 짐승 새끼 행이 클릭 라우팅을 탄다 ─────────────────────────
	print("── ⑧ #8 프레임 kind 허용 목록 — 목공방 「짐승 새끼」 ──")
	var frame_src: String = FileAccess.open("res://inv_frame.gd", FileAccess.READ).get_as_text()
	var allow_line := ""
	for ln in frame_src.split("\n"):
		var s7 := String(ln).strip_edges()
		if s7.begins_with("#"):
			continue
		if s7.contains("\"sapling\"") and s7.ends_with(":"):
			allow_line = s7
			break
	# 대조 목록을 **손으로 안 적는다** — 목공방이 실제로 내는 행에서 kind를 긁는다.
	var ws_kinds: Dictionary = {}
	for row in m._woodshop_items():
		ws_kinds[String((row as Dictionary).get("kind", ""))] = true
	var ws_unrouted: Array = []
	for k in ws_kinds.keys():
		if not allow_line.contains("\"%s\"" % str(k)):
			ws_unrouted.append(str(k))
	ws_unrouted.sort()
	_check("⑧a 허용 목록 행을 찾았다", allow_line != "")
	_check("⑧b 목공방이 실제로 「짐승 새끼」 행을 낸다(kind %s)" % str(ws_kinds.keys()),
		ws_kinds.has("livestock"))
	_check("⑧c 목공방이 내는 kind 중 라우팅 안 되는 것 0(미라우팅 %s)" % str(ws_unrouted),
		ws_unrouted.is_empty())
	_check("⑧d 핸들러 쪽 분기는 이미 있었다 — 죽어 있던 층은 **신호**뿐이었다",
		_in_func("func _on_frame_buy_store_item", "\"livestock\""))

	# ── ⑨ #9 보부상이 깊이 밴드 너머 광물을 팔지 않는다 ───────────────────────
	print("── ⑨ #9 보부상 일반 재고 — 갱도 깊이 게이트 우회 차단 ──")
	var gated: Array = []
	var shallow: Array = []
	for e: Dictionary in MineFloors.NODE_TABLE:
		if int(e["floor_min"]) > 1:
			gated.append(String(e["id"]))
		else:
			shallow.append(String(e["id"]))
	gated.sort()
	shallow.sort()
	var not_excluded: Array = []
	for gid in gated:
		if not Peddler.pool_excluded(str(gid)):
			not_excluded.append(str(gid))
	_check("⑨pre 깊이 밴드 너머 산출을 NODE_TABLE에서 파생했다(%s)" % str(gated),
		gated.size() >= 5 and gated.has(ItemCatalog.GEM_MYEONGBU_GEUMGANG)
		and gated.has(ItemCatalog.ORE_YUCHEOL) and gated.has(ItemCatalog.ORE_HWANGCHEONGEUM))
	_check("⑨a 그 전부가 배제 술어에 걸린다(안 걸린 것 %s)" % str(not_excluded),
		not_excluded.is_empty())
	var in_pool: Array = []
	var shallow_in_pool: Array = []
	for r in Peddler.stock_pool():
		var bid := String((r as Dictionary)["buy_id"])
		if gated.has(bid):
			in_pool.append(bid)
		if shallow.has(bid):
			shallow_in_pool.append(bid)
	shallow_in_pool.sort()
	_check("⑨b 일반 재고 풀에 한 종도 안 선다(선 것 %s)" % str(in_pool), in_pool.is_empty())
	_check("⑨c 1층에서 닿는 광물은 **그대로 판다**(평평≠막힘 — 좌판이 안 죽는다: %s)"
			% str(shallow_in_pool),
		shallow_in_pool.has(ItemCatalog.ORE_MYEONGDONG) and shallow_in_pool.has(ItemCatalog.HONTAN)
		and shallow_in_pool.has(ItemCatalog.GEM_NEOKSUJEONG))
	_check("⑨d 술어는 로스터 파생이다 — 밴드가 바뀌면 매대가 0줄로 따라온다",
		MineFloors.is_depth_gated(ItemCatalog.GEM_MYEONGOK)
		and not MineFloors.is_depth_gated(ItemCatalog.STONE))

	# ── ⑩ #10 결정기 부품·결정기의 처분 창구 ─────────────────────────────────
	print("── ⑩ #10 카탈로그가 값을 매긴 물건에 판매 창구가 선다 ──")
	var part: String = ItemCatalog.CRYSTALARIUM_PART
	_check("⑩pre 카탈로그는 부품 %d냥·결정기 %d냥을 '출하했을 때의 값'으로 선언한다(도감 밖)"
			% [ItemCatalog.price_of(part), ItemCatalog.price_of(ItemCatalog.CRYSTALARIUM)],
		ItemCatalog.price_of(part) > 0 and ItemCatalog.price_of(ItemCatalog.CRYSTALARIUM) > 0
		and not Codex.is_tracked(part))
	m.inventory.add_item(part, 2)
	var pslot := -1
	for i2 in 40:
		if m.inventory.id_at(i2) == part:
			pslot = i2
			break
	var bin_before: int = m.ship_bin.count_of(part)
	if pslot >= 0:
		m._on_frame_deposit(pslot)
	_check("⑩a 출하함이 부품을 받는다(대기 %d → %d)" % [bin_before, m.ship_bin.count_of(part)],
		pslot >= 0 and m.ship_bin.count_of(part) == bin_before + 2)
	_check("⑩b 백팩에서 실제로 빠졌다(창구가 표시만이 아니다)", m.inventory.count_of(part) == 0)
	m.ship_bin.take_back(part, 2)
	m.inventory.remove_item(part, m.inventory.count_of(part))
	m.inventory.add_item(ItemCatalog.SPRINKLER, 1)
	var sslot := -1
	for i3 in 40:
		if m.inventory.id_at(i3) == ItemCatalog.SPRINKLER:
			sslot = i3
			break
	if sslot >= 0:
		m._on_frame_deposit(sslot)
	_check("⑩c 다른 설치물(스프링클러)은 여전히 거절된다 — 술어가 그 둘에만 걸린다",
		sslot >= 0 and m.ship_bin.count_of(ItemCatalog.SPRINKLER) == 0
		and m.inventory.count_of(ItemCatalog.SPRINKLER) == 1)
	m.inventory.remove_item(ItemCatalog.SPRINKLER, 1)

	# ── ⑪ #11 벌목 산출이 조용히 증발하지 않는다 ──────────────────────────────
	print("── ⑪ #11 벌목 적재 실패 — 형제 창구(채굴·처치)와 같은 문법 ──")
	var filler_pool: Array = []
	filler_pool.append_array(ItemCatalog.MINERALS.keys())
	filler_pool.append_array(ItemCatalog.FORAGEABLES.keys())
	filler_pool.append_array(ItemCatalog.MATERIALS.keys())
	var filler: Array = []
	for fid2 in filler_pool:
		var fs := str(fid2)
		if fs == ItemCatalog.WOOD:
			continue
		if not m.inventory.can_add(ItemCatalog.WOOD, 1):
			break
		if m.inventory.count_of(fs) == 0 and m.inventory.add_item(fs, 1):
			filler.append(fs)
	_check("⑪pre 백팩을 원목 아닌 서로 다른 물건 %d종으로 가득 채웠다(원목 스택 0)" % filler.size(),
		not m.inventory.can_add(ItemCatalog.WOOD, 1)
		and m.inventory.count_of(ItemCatalog.WOOD) == 0)
	var granted: bool = m._grant_chop_drop(ItemCatalog.WOOD, 2)
	_check("⑪a 적재 실패를 **반환값으로 알린다**(종전엔 void라 호출부가 알 수도 없었다)",
		not granted and m.inventory.count_of(ItemCatalog.WOOD) == 0)
	_check("⑪b 줄 것이 없으면 실패가 아니다(id \"\" · n 0 = true — 알림 스팸 방지)",
		m._grant_chop_drop("", 0) and m._grant_chop_drop(ItemCatalog.WOOD, 0))
	_check("⑪c 호출부가 그 실패를 알림으로 흘린다(형제 `_award_mine_drop`과 같은 문법)",
		_in_func("func _chop_tree", "백팩이 가득 차 벤 것을 다 담지 못했다"))
	_check("⑪d 네 산출 갈래가 전부 그 반환을 모아 한 번만 알린다(알림 도배 0)",
		_in_func("func _chop_tree", "chop_full = not _grant_chop_drop(ItemCatalog.WOOD"))
	# 자리가 생기면 통째로 담기고 토스트 수도 실수와 맞는다(스택은 빈 슬롯 하나면 전량 들어간다).
	if not filler.is_empty():
		m.inventory.remove_item(str(filler[0]), 1)
	var refilled: bool = m._grant_chop_drop(ItemCatalog.WOOD, 3)
	_check("⑪e 자리가 있으면 전량 담고 토스트도 그 수다(원목 %d개 — '%s')"
			% [m.inventory.count_of(ItemCatalog.WOOD), _last_notice(m)],
		refilled and m.inventory.count_of(ItemCatalog.WOOD) == 3
		and _last_notice(m).contains("+3"))
	for f3 in filler:
		m.inventory.remove_item(str(f3), m.inventory.count_of(str(f3)))
	m.inventory.remove_item(ItemCatalog.WOOD, m.inventory.count_of(ItemCatalog.WOOD))

	# ── ⑫ #12 청혼 게이트의 비약 안내가 막다른 길이 아니다 ────────────────────
	print("── ⑫ #12 뭍의 비약 — 상자에 넣었을 때의 안내 ──")
	var serena: Resident = m._resident(m.ELIXIR_RID)
	m._romance_partner = m.ELIXIR_RID
	m._spouse_id = ""
	m._wedding_day = 0
	m._ever_married.erase(m.ELIXIR_RID)
	m.carpenter._done[Carpenter.PROJ_MASTER_ROOM] = 1
	m._heart_bits[m.ELIXIR_RID] = 0xFFFF
	m.inventory.remove_item(ItemCatalog.OKJA_ELIXIR, m.inventory.count_of(ItemCatalog.OKJA_ELIXIR))
	m.inventory.add_item(ItemCatalog.WEDDING_CHARM, 1)   # 정표 보유 = 비약 창구가 열리는 선행 조건
	_check("⑫pre 무대: 세레나 연애 중 · 안방 확장 · 아크 완주 · 정표 보유(비약 게이트만 남는다)",
		serena != null and m._home_expanded() and m._redemption_arc_complete(m.ELIXIR_RID)
		and not m._charm_quest_open())
	m._try_propose(serena)
	var notice_none := _last_notice(m)
	_check("⑫a 비약이 아예 없으면 옥자를 가리킨다(그 창구는 실제로 열려 있다) — '%s'" % notice_none,
		notice_none.contains("옥자") and m._elixir_quest_open())
	m.chest.store(ItemCatalog.OKJA_ELIXIR, 1)
	m._try_propose(serena)
	var notice_chest := _last_notice(m)
	_check("⑫b 상자에 넣어 두면 **상자를 가리킨다** — '%s'" % notice_chest,
		notice_chest.contains("상자"))
	_check("⑫c 그 상황에서 옥자 창구는 닫혀 있다(R7의 재발급 차단) — 안내가 그 사실과 맞는다",
		not m._elixir_quest_open())
	_check("⑫d 청혼은 여전히 무소모다 — 비약도 혼례 예정일도 안 움직였다",
		m._count_anywhere(ItemCatalog.OKJA_ELIXIR) == 1 and m._wedding_day == 0)
	_check("⑫e 판정은 손에 든 것을 묻되(소모 지점과 같은 원장) 안내만 갈린다",
		_in_func("func _try_propose(r: Resident)", "_stored_anywhere(ItemCatalog.OKJA_ELIXIR)"))

	for s8 in SaveManager.SLOT_COUNT:
		_wipe_slot(s8)
	print("── 결과: %s (실패 %d)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# 선물 선호표가 등급을 매긴 음료 수(⑥c — "사문"이 실재하는지의 증거. 0이면 그 발견 자체가 없다).
func _gift_rated_drinks(drinks: Array) -> int:
	var n := 0
	for d in drinks:
		var did := str(d)
		for rid in GiftPrefs.OVERRIDES.keys():
			var ov: Dictionary = GiftPrefs.OVERRIDES[rid]
			if Array(ov.get(GiftPrefs.LOVE, [])).has(did) \
					or Array(ov.get(GiftPrefs.HATE, [])).has(did):
				n += 1
				break
	return n
