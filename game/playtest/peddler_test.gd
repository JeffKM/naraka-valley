extends SceneTree
# ★[S10-T3 / ADR-0069 결정 5] 저승 보부상(여행 상인) 검증 — ephemeral 헤드리스.
#
# 결정 5가 잠근 정체성이 코드에 그대로 서 있는지 본다: **상시 리듬**(7의 배수 날) · **랜덤 재고**
# (day-해시 결정 롤 10 + 가구 1 + 희귀 1) · **야시장과의 역할 분리**(할인 아닌 웃돈·한정판 아닌 변주) ·
# **Books 미보유분 저확률 입수처** · **레어크로우 ⑤ 1회성**.
#
# ★ 핵심 불변식:
#   ① 달력 — 7의 배수 날에만 선다. 그 밖은 재고 자체가 없다(빈 배열). day 0·음수는 손상 방어.
#   ② 재고 롤 — 같은 day는 몇 번을 굴려도 같고, 다른 day는 달라진다. 일반 10슬롯에 중복 0.
#      **전역 randf 0**(소스 스캔) — 롤이 전부 rand_from_seed 믹싱이라 세이브 없이 재현된다.
#   ③ 풀 — **로스터 파생**이다(하드코딩 목록 0). 게이트 너머 3종(오색혼옥·나락철·나락혼정)과
#      비매 수집물(레어크로우 price 0)은 구조적으로 안 실린다.
#   ④ 가격 — 정가 ×2.2 ±25% 웃돈. (day, slot)에 결정적이라 재열람으로 값이 안 흔들린다.
#      ★ 야시장이 *깎는* 자리에서 보부상은 *얹는다* — 두 무대의 가격 축이 반대다.
#   ⑤ 가구 슬롯 — 매 출현일 1행. HomeDecoCatalog가 정가 진실원이고 해금 판정은 HomeDeco가 진다.
#   ⑥ 희귀 슬롯 — 레어크로우 ⑤ / Books 미보유분 / 고가 폴백의 3지 결정 분기. **비는 날이 없다**.
#   ⑦ 레어크로우 ⑤ — 1회성(사고 나면 영영 안 뜬다). ★ 아이템 등재는 T2 소유라 **조건부 단언**이다
#      (미등재면 "후보 스킵"을, 등재되면 "1회성 소진·구매 배선"을 잰다 — 결합 후 강한 경로가 돈다).
#   ⑧ 구매·지불 배선 — 표시가 = 결제가. 오늘 봇짐에 없는 id는 값 0이라 결제가 성립하지 않는다.
#   ⑨ Books·레어크로우 배선 — 그 물건이 뜨는 날로 시계를 옮겨 **실제로 산다**.
#   ⑩ 무손실 · 세이브 — 열어만 보면 잃는 것 0 · "peddler" 가법 키 왕복 · 구세이브는 빈 원장.
#   ⑪ 표식 _draw — 다리 남단 무대에 실제로 서서 크래시 없이 돈다(떠난 다음 날엔 흔적 0).
# 실행: godot --headless --path game --script res://playtest/peddler_test.gd

var _fail := 0

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

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 행 배열 → buy_id 배열(순서 보존). 재고 비교의 공용 축.
func _ids_of(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		var row: Dictionary = r
		out.append(str(row["buy_id"]))
	return out

# 행 배열에서 kind가 일치하는 첫 행({} = 없음).
func _first_of_kind(rows: Array, kind: String) -> Dictionary:
	for r in rows:
		var row: Dictionary = r
		if str(row["kind"]) == kind:
			return row
	return {}

# 그 kind가 실린 첫 출현일(0 = 표본 안에 없음). 재고가 롤이라 "그 종류가 뜬 날"로 옮겨 재야 한다.
func _day_with_kind(days: Array, kind: String) -> int:
	for d in days:
		if not _first_of_kind(Peddler.stock_rows(int(d), [], {}), kind).is_empty():
			return int(d)
	return 0

# 앞으로 n번의 출현일(day 오름차순).
func _open_days(n: int) -> Array:
	var out: Array = []
	var d := Peddler.APPEAR_MODULUS
	while out.size() < n:
		out.append(d)
		d += Peddler.APPEAR_MODULUS
	return out

func _initialize() -> void:
	print("══ S10-T3 저승 보부상 검증 ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.s10_t3_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# 40주치 출현일(day 7~280). ★ 24주가 아니라 40주인 이유: 희귀 슬롯의 두 저확률 가지(레어크로우
	#   20% · 책 15%)가 표본 안에서 **반드시 한 번은 뜨도록** 잡은 것이다(0.85^40 ≈ 0.15%). 롤이
	#   결정적이라 확률이 아니라 고정 결과지만, 표본이 얇으면 상수를 조금만 만져도 단언이 깨진다.
	var days := _open_days(40)
	var d0: int = days[0]

	# ── ① 달력(순수 단위 — 인스턴스 불필요) ──
	print("── ① 출현 달력(7의 배수 날) ──")
	_check("①a 주기 상수 = 7(주 1회)", Peddler.APPEAR_MODULUS == 7)
	var mod_ok := true
	for d in range(1, 200):
		if Peddler.is_open_day(d) != (d % Peddler.APPEAR_MODULUS == 0):
			mod_ok = false
	_check("①b 1~199일 전 구간에서 '7의 배수 = 출현일'이 정확히 일치", mod_ok)
	_check("①c 절기당 4회(7·14·21·28) · 절기 경계를 넘어도 리듬 유지(28→35)",
		Peddler.is_open_day(7) and Peddler.is_open_day(14) and Peddler.is_open_day(21)
		and Peddler.is_open_day(28) and Peddler.is_open_day(35))
	_check("①d day 0·음수 = 비출현(손상 방어)",
		not Peddler.is_open_day(0) and not Peddler.is_open_day(-7))
	_check("①e next_open_day — 오늘이 출현일이면 오늘 · 아니면 다음 배수",
		Peddler.next_open_day(7) == 7 and Peddler.next_open_day(8) == 14
		and Peddler.next_open_day(1) == 7 and Peddler.next_open_day(13) == 14)
	_check("①f days_until — 오늘 0 · 하루 뒤 1 · 엿새 뒤 6",
		Peddler.days_until(14) == 0 and Peddler.days_until(13) == 1 and Peddler.days_until(8) == 6)
	# ★ 테마 데이(25일)와는 **절기 내 일차가 절대 안 겹친다**(7의 배수 = 7/14/21/28 ≠ 25).
	var clash_theme := false
	var clash_event := false
	for d in range(1, 4 * GameClock.DAYS_PER_SEASON + 1):
		if not Peddler.is_open_day(d):
			continue
		if Festival.is_theme_slot(d):
			clash_theme = true
		if SeasonalEvent.is_event_day(d):
			clash_event = true
	_check("①g 테마 데이(25일)와 날짜 비충돌 — 한 아침에 매대가 둘 서지 않는다", not clash_theme)
	# 절기 행사(12/20/16/15)와도 1년 안에서 안 겹친다(둘 다 절기 내 일차 고정이라 산술로 확인된다).
	_check("①h 절기 행사(12·20·16·15)와도 1년 내 날짜 비충돌", not clash_event)

	# ── ② 재고 롤 결정성 ──
	print("── ② 재고 롤 결정성 ──")
	var empty_books: Dictionary = {}
	var rows_a := Peddler.stock_rows(d0, [], empty_books)
	var rows_b := Peddler.stock_rows(d0, [], empty_books)
	_check("②a 같은 day를 두 번 굴려도 재고가 동일(재열람 어뷰징 0)", _ids_of(rows_a) == _ids_of(rows_b))
	_check("②b 매대 행 수 = 10 + 가구 1 + 희귀 1 = %d" % Peddler.TOTAL_ROWS,
		rows_a.size() == Peddler.TOTAL_ROWS and Peddler.TOTAL_ROWS == Peddler.STOCK_SLOTS + 2)
	var changed_days := 0
	for i in range(1, days.size()):
		if _ids_of(Peddler.general_rows(int(days[i]))) != _ids_of(Peddler.general_rows(int(days[i - 1]))):
			changed_days += 1
	_check("②c 다른 day는 재고가 바뀐다(%d/%d회 변화 — '매번 다름'이 정체성)" % [changed_days, days.size() - 1],
		changed_days == days.size() - 1)
	var dup_free := true
	for d in days:
		var seen: Dictionary = {}
		for id in _ids_of(Peddler.general_rows(int(d))):
			if seen.has(id):
				dup_free = false
			seen[id] = true
	_check("②d 일반 10슬롯에 같은 물건이 두 번 안 실린다(해시 키 부분 선택 = 순열 앞 10개)", dup_free)
	_check("②e 비출현일엔 재고 자체가 없다(빈 배열)",
		Peddler.stock_rows(d0 + 1, [], empty_books).is_empty()
		and Peddler.stock_rows(1, [], empty_books).is_empty())
	# ★ 전역 randf 금지 — 소스 스캔(주석 제거 후. S9b-T7이 데인 그 함정: 예약 주석이 위반으로 잡힌다).
	var src := FileAccess.open("res://peddler.gd", FileAccess.READ).get_as_text()
	var code_only := ""
	for ln in src.split("\n"):
		var s := String(ln).strip_edges()
		if s.begins_with("#"):
			continue
		code_only += s + "\n"
	_check("②f 소스에 전역 randf/randi/randomize 0 — 롤은 전부 rand_from_seed 믹싱",
		not code_only.contains("randf(") and not code_only.contains("randi(")
		and not code_only.contains("randomize(") and code_only.contains("rand_from_seed"))

	# ── ③ 재고 풀 = 로스터 파생(하드코딩 분모 0) ──
	print("── ③ 재고 풀 로스터 파생 ──")
	var pool := Peddler.stock_pool()
	# 분모를 **카탈로그에서 독립 계산**해 대조한다(표를 손으로 옮겨 적으면 stale이 된다).
	var want := 0
	for cid in CropCatalog.ids():
		if int(CropCatalog.seed_cost(str(cid))) > 0:
			want += 1
	var tables: Array = [ItemCatalog.FORAGEABLES, ItemCatalog.MATERIALS, ItemCatalog.MINERALS,
		ItemCatalog.POT_GOODS, ItemCatalog.SAP_GOODS]
	for t in tables:
		var tbl: Dictionary = t
		for id in tbl:
			var row: Dictionary = tbl[id]
			if Peddler.POOL_EXCLUDE.has(str(id)):
				continue
			if int(row.get("price", 0)) > 0:
				want += 1
	_check("③a 풀 크기(%d)가 카탈로그 파생 계산과 일치(하드코딩 목록 0)" % pool.size(), pool.size() == want)
	var pool_ids := _ids_of(pool)
	_check("③b 게이트 너머 3종 부재(오색혼옥·나락철 광석·나락혼정 — 돈으로 깊이를 사지 못한다)",
		not pool_ids.has(ItemCatalog.GEM_OSAEK_HONOK)
		and not pool_ids.has(ItemCatalog.ORE_NARAKCHEOL)
		and not pool_ids.has(ItemCatalog.NARAK_HONJEONG))
	_check("③c 비매 수집물(레어크로우 ①②) 부재 — price 0 필터가 곧 규칙",
		not pool_ids.has(ItemCatalog.RARECROW_1) and not pool_ids.has(ItemCatalog.RARECROW_2))
	var kinds_ok := true
	var base_ok := true
	for r in pool:
		var row: Dictionary = r
		var k := str(row["kind"])
		if k != Peddler.KIND_SEED and k != Peddler.KIND_ITEM:
			kinds_ok = false
		if int(row["base"]) <= 0:
			base_ok = false
	_check("③d 풀은 씨앗·스택 아이템 두 종류뿐 · 정가 전부 > 0", kinds_ok and base_ok)
	_check("③e 풀 크기가 슬롯 수보다 넉넉하다(뽑기가 성립)", pool.size() > Peddler.STOCK_SLOTS)

	# ── ④ 가격(웃돈 ±변동 · 결정적) ──
	print("── ④ 가격(보부상 웃돈) ──")
	_check("④a 마크업 상수 = ×2.2 ±25%(야시장 2할 *할인*의 정확한 반대 축)",
		Peddler.MARKUP_PERMIL == 2200 and Peddler.JITTER_PERMIL == 250)
	var band_ok := true
	var jitter_seen: Dictionary = {}
	for d in days:
		for s in Peddler.STOCK_SLOTS:
			var p := Peddler.priced(int(d), s, 100)
			if p < 195 or p > 245:      # 100 × (2.2 ± 0.25) = 195 ~ 245
				band_ok = false
			jitter_seen[p] = true
	_check("④b 표시가가 정가의 1.95~2.45배 밴드 안(전 출현일 × 전 슬롯)", band_ok)
	_check("④c 변동이 실제로 흔들린다(%d가지 출목 — 상수 아님)" % jitter_seen.size(), jitter_seen.size() > 5)
	# ★ "다른 날은 값이 다르다"를 **한 쌍**으로 재면 안 된다: 밴드가 51칸뿐이라 우연히 같은 값이
	#   나오는 쌍이 반드시 존재하고, 그 쌍을 고르면 상수를 안 건드렸는데도 회귀가 깨진다(플래키).
	#   그래서 재현성은 같은 인자로, 변화는 **전 출현일에 걸친 출목 다양성**으로 나눠 잰다.
	var same_day_stable := true
	for d in days:
		if Peddler.priced(int(d), 3, 100) != Peddler.priced(int(d), 3, 100):
			same_day_stable = false
	var slot3_values: Dictionary = {}
	for d in days:
		slot3_values[Peddler.priced(int(d), 3, 100)] = true
	_check("④d 같은 (day, slot)은 몇 번을 물어도 같은 값(재열람 안정)", same_day_stable)
	_check("④e 같은 슬롯이라도 날이 바뀌면 값이 움직인다(%d가지 — 날짜가 시드에 섞인다)"
		% slot3_values.size(), slot3_values.size() > 3)
	_check("④f 정가 0·음수는 0(공짜 물건이 좌판에 서지 않는다)",
		Peddler.priced(d0, 0, 0) == 0 and Peddler.priced(d0, 0, -5) == 0)
	var row_price_ok := true
	for r in rows_a:
		var row: Dictionary = r
		if int(row["price"]) != Peddler.priced(d0, int(row["slot"]), int(row["base"])):
			row_price_ok = false
	_check("④g 매대 행의 표시가 = priced(day, slot, base)와 정확히 일치", row_price_ok)

	# ── ⑤ 가구 슬롯 ──
	print("── ⑤ 가구 슬롯(테마 세트 두 번째 입구) ──")
	var deco_always := true
	var deco_from_roster := true
	var purchasable: Array = HomeDecoCatalog.purchasable_ids()
	for d in days:
		var dr := Peddler.deco_row(int(d))
		if dr.is_empty():
			deco_always = false
			continue
		if not purchasable.has(str(dr["buy_id"])):
			deco_from_roster = false
		if int(dr["base"]) != HomeDecoCatalog.price_of(str(dr["buy_id"])):
			deco_from_roster = false
	_check("⑤a 매 출현일에 가구 행이 정확히 1개 선다", deco_always)
	_check("⑤b 세트는 HomeDecoCatalog.purchasable_ids()에서만 나오고 정가도 그쪽이 진실원(중복 표 0)",
		deco_from_roster)
	# 가구·희귀는 각각 정확히 1행이다(일반 10 + 1 + 1의 구조가 행 배열에도 그대로 서 있다).
	var n_deco := 0
	var n_rare_slot := 0
	for r in rows_a:
		var row: Dictionary = r
		if str(row["kind"]) == Peddler.KIND_DECO:
			n_deco += 1
		if int(row["slot"]) == Peddler.SLOT_RARE:
			n_rare_slot += 1
	_check("⑤c 매대 행에 가구 1행 · 희귀 슬롯 1행이 정확히 하나씩", n_deco == 1 and n_rare_slot == 1)
	# main 라우팅 리터럴과 kind 상수를 대조한다(오타 = 조용한 무동작이라 회귀로 잠근다).
	_check("⑤d kind 상수 5종이 main 구매 라우팅 리터럴과 일치",
		Peddler.KIND_ITEM == "ped_item" and Peddler.KIND_SEED == "ped_seed"
		and Peddler.KIND_DECO == "ped_deco" and Peddler.KIND_RARE == "ped_rare"
		and Peddler.KIND_BOOK == "ped_book")

	# ── ⑥ 희귀 슬롯 · Books 미보유분 ──
	print("── ⑥ 희귀 슬롯 · Books 입수처 ──")
	var rare_never_empty := true
	var book_days := 0
	var crow_days := 0
	var book_ids_seen: Dictionary = {}
	for d in days:
		var rr := Peddler.rare_row(int(d), [], empty_books)
		if rr.is_empty():
			rare_never_empty = false
			continue
		var rk := str(rr["kind"])
		if rk == Peddler.KIND_BOOK:
			book_days += 1
			book_ids_seen[str(rr["buy_id"])] = true
		elif rk == Peddler.KIND_RARE:
			crow_days += 1
	_check("⑥a 희귀 슬롯이 비는 날이 0(레어크로우/책/고가 폴백의 3지 분기가 늘 답을 낸다)",
		rare_never_empty)
	_check("⑥b 출현 %d회 중 책·노트가 뜬 날 %d회 — '저확률 입수처'로 성립" % [days.size(), book_days],
		book_days > 0 and book_days < days.size())
	var books_are_real := true
	for id in book_ids_seen:
		if not Books.has_text(str(id)):
			books_are_real = false
	_check("⑥c 책 슬롯 id가 전부 Books 테이블에 실재(오타·유령 id 0)", books_are_real)
	# 전부 보유하면 책 가지가 닫힌다 — 중복 입수 0.
	var all_owned: Dictionary = {}
	for id in Books.all_ids():
		all_owned[str(id)] = 1
	var no_dup := true
	for d in days:
		var rr2 := Peddler.rare_row(int(d), [], all_owned)
		if not rr2.is_empty() and str(rr2["kind"]) == Peddler.KIND_BOOK:
			no_dup = false
	_check("⑥d 이미 다 주웠으면 책 가지가 닫힌다(중복 입수 0 — 폴백으로 흘러간다)", no_dup)
	_check("⑥e remaining_books가 미보유분만 낸다(분모 = Books.all_ids 파생)",
		Peddler.remaining_books({}).size() == Books.all_ids().size()
		and Peddler.remaining_books(all_owned).is_empty())
	_check("⑥f 책·노트 값이 위계로 갈린다(책 > 노트 — 무거운 한 챕터 : 짧은 속삭임)",
		Peddler.BOOK_PRICE > Peddler.NOTE_PRICE and Peddler.NOTE_PRICE > 0)

	# ── ⑦ 레어크로우 ⑤(★ 조건부 — 아이템 등재는 T2 소유) ──
	print("── ⑦ 레어크로우 ⑤(획득처 ⑤) ──")
	var crow_registered := ItemCatalog.has_item(Peddler.RARECROW_ID)
	_check("⑦a id 참조가 로스터 규약과 일치(\"rarecrow_5\" — 등재는 T2 소유)",
		Peddler.RARECROW_ID == "rarecrow_5")
	if not crow_registered:
		# 미등재 경로 — has_item 게이트가 후보를 조용히 건너뛴다(빈 슬롯 0).
		var skipped := true
		for d in days:
			var rr3 := Peddler.rare_row(int(d), [], empty_books)
			if rr3.is_empty() or str(rr3["buy_id"]) == Peddler.RARECROW_ID:
				skipped = false
		_check("⑦b [미등재 경로] has_item 게이트가 후보를 건너뛰고 슬롯은 그대로 찬다", skipped)
		_check("⑦c [미등재 경로] 레어크로우 날 0회 — 등재되면 ⑦d~⑦f 강한 경로가 대신 돈다",
			crow_days == 0)
	else:
		_check("⑦b [등재 경로] 표본 40주에 레어크로우 ⑤가 뜨는 날이 있다(%d회)" % crow_days, crow_days > 0)
		# 구매 이력이 있으면 영영 안 뜬다(1회성).
		var gone := true
		for d in days:
			var rr4 := Peddler.rare_row(int(d), [Peddler.RARECROW_ID], empty_books)
			if rr4.is_empty() or str(rr4["buy_id"]) == Peddler.RARECROW_ID:
				gone = false
		_check("⑦c [등재 경로] 산 뒤엔 전 출현일에서 사라진다(1회성)", gone)
		_check("⑦d [등재 경로] 정가가 야시장 ②(2,500)보다 비싸다(할인 아닌 웃돈 축)",
			Peddler.RARECROW_PRICE > SeasonalEvent.MARKET_RARECROW_PRICE)

	var m: Node = await _spawn_main()

	# ── ⑧ main 통합 — 무대 · 프레임 · 구매/지불 ──
	print("── ⑧ main 통합(무대·매대·구매) ──")
	m._region = RegionCatalog.NARU_VILLAGE
	m._indoor = ""
	m._sleeping = false
	m.clock.day = d0
	m.peddler.load_save({})
	m.books.load_save({})
	m._target = PEDDLER_TILE_OF(m)
	_check("⑧a facing = 출현일 · 나루 마을 야외 · 그 칸", m._facing_peddler())
	m.clock.day = d0 + 1
	_check("⑧b 출현일이 아니면 좌판이 없다(facing false)", not m._facing_peddler())
	m.clock.day = d0
	_check("⑧c 무대 칸이 워프·착지·다리 데크를 안 먹는다",
		PEDDLER_TILE_OF(m) != Vector2i(52, 71) and PEDDLER_TILE_OF(m) != Vector2i(53, 71)
		and PEDDLER_TILE_OF(m) != Vector2i(52, 70) and PEDDLER_TILE_OF(m).x > 53)
	var notice_open: String = m._peddler_morning_notice()
	m.clock.day = d0 + 1
	var notice_closed: String = m._peddler_morning_notice()
	m.clock.day = d0
	_check("⑧d 아침 알림 — 출현일만 한 줄(비출현일은 조용)",
		notice_open != "" and notice_closed == "")
	var items: Array = m._peddler_items()
	_check("⑧e 매대 행 %d개(표시명·아이콘이 붙은 뒤에도 행 수 보존)" % items.size(),
		items.size() == Peddler.TOTAL_ROWS)
	var named := true
	for r in items:
		var row: Dictionary = r
		if str(row.get("name", "")) == "" or int(row.get("price", 0)) <= 0:
			named = false
	_check("⑧f 모든 행에 표시명과 표시가가 붙어 있다(빈 행 0)", named)
	_check("⑧g 헤더에 출현 주기가 뜬다(야시장이 할인율을 박는 그 자리)",
		m._peddler_text().contains("%d일마다" % Peddler.APPEAR_MODULUS))
	m._open_frame(InventoryFrame.CTX_PEDDLER)
	_check("⑧h [F] 매대 = 만물상 셸 재사용(CTX_PEDDLER · 첫 그림부터 품목이 차 있다)",
		m.frame.context == InventoryFrame.CTX_PEDDLER and m.frame.store_items.size() == Peddler.TOTAL_ROWS
		and m.frame.store_text != "")
	m._close_frame()

	# 일반 스택 아이템 — 표시가 = 결제가. ★ 재고가 롤이라 **그 종류가 실린 날로 시계를 옮겨** 잰다
	#   (오늘 우연히 안 실렸다고 배선 검증을 건너뛰면 회귀가 조용히 헐거워진다).
	m.wallet.gold = 999999
	var bulk_n: int = m.get_script().get_script_constant_map()["STORE_BULK"]
	var item_day := _day_with_kind(days, Peddler.KIND_ITEM)
	_check("⑧h-pre 일반 아이템이 실린 출현일을 찾았다(풀이 비면 아래가 통째로 무의미)", item_day > 0)
	m.clock.day = maxi(item_day, Peddler.APPEAR_MODULUS)
	var item_row := _first_of_kind(m._peddler_items(), Peddler.KIND_ITEM)
	if item_row.is_empty():
		item_row = {"buy_id": "", "price": 0}   # 아래 단언이 크래시 대신 **실패**로 떨어지게(진단 보존)
	var item_id := str(item_row["buy_id"])
	var item_price := int(item_row["price"])
	var have0: int = m.inventory.count_of(item_id)
	var gold0: int = m.wallet.gold
	m._on_frame_buy_store_item(item_id, Peddler.KIND_ITEM, false)
	_check("⑧i 일반 품목 1개 구매 = 표시가만큼 지출(%s −%d냥)" % [item_id, item_price],
		m.inventory.count_of(item_id) == have0 + 1 and m.wallet.gold == gold0 - item_price)
	var gold1: int = m.wallet.gold
	m._on_frame_buy_store_item(item_id, Peddler.KIND_ITEM, true)
	_check("⑧j Shift 대량 = %d개 묶음(부분 구매 규율 보존)" % bulk_n,
		m.inventory.count_of(item_id) == have0 + 1 + bulk_n
		and m.wallet.gold == gold1 - item_price * bulk_n)
	# 씨앗 — 스택 소매.
	var seed_day := _day_with_kind(days, Peddler.KIND_SEED)
	if seed_day == 0:
		_check("⑧k 씨앗 행이 표본 40주 어느 날에도 안 실린다면 풀이 잘못된 것", false)
	else:
		m.clock.day = seed_day
		var seed_row := _first_of_kind(m._peddler_items(), Peddler.KIND_SEED)
		var crop := str(seed_row["buy_id"])
		var seed_item := ItemCatalog.seed_id(crop)
		var s0: int = m.inventory.count_of(seed_item)
		var g0: int = m.wallet.gold
		m._on_frame_buy_store_item(crop, Peddler.KIND_SEED, false)
		_check("⑧k 씨앗 1개 소매(%s −%d냥)" % [crop, int(seed_row["price"])],
			m.inventory.count_of(seed_item) == s0 + 1
			and m.wallet.gold == g0 - int(seed_row["price"]))
	# 오늘 재고에 없는 **실재 아이템**은 값이 0 = 결제 불성립(프레임 밖 구매 구멍 차단).
	m.clock.day = item_day
	var absent := ""
	var today_ids := _ids_of(m._peddler_items())
	for r in Peddler.stock_pool():
		var prow: Dictionary = r
		if str(prow["kind"]) == Peddler.KIND_ITEM and not today_ids.has(str(prow["buy_id"])):
			absent = str(prow["buy_id"])
			break
	var gold_x: int = m.wallet.gold
	var have_x: int = m.inventory.count_of(absent)
	m._on_frame_buy_store_item(absent, Peddler.KIND_ITEM, false)
	_check("⑧l 오늘 봇짐에 없는 실재 아이템(%s)은 값 0 = 결제 불성립(구멍 차단)" % absent,
		absent != "" and m.wallet.gold == gold_x and m.inventory.count_of(absent) == have_x)
	# 가구 세트 — HomeDeco가 해금 진실원.
	var deco_row := _first_of_kind(m._peddler_items(), Peddler.KIND_DECO)
	if deco_row.is_empty():
		deco_row = {"buy_id": "", "price": 0}
	var set_id := str(deco_row["buy_id"])
	var set_price := int(deco_row["price"])
	if m.home_deco.is_unlocked(set_id):
		_check("⑧m 가구 세트(이미 해금 상태라 잠김 표시만 확인)", bool(deco_row.get("locked", false)))
	else:
		var g1: int = m.wallet.gold
		m._on_frame_buy_store_item(set_id, Peddler.KIND_DECO, false)
		_check("⑧m 가구 세트 해금 + 표시가만큼 지출(진실원 = home_deco)",
			m.home_deco.is_unlocked(set_id) and m.wallet.gold == g1 - set_price)
		var g2: int = m.wallet.gold
		m._on_frame_buy_store_item(set_id, Peddler.KIND_DECO, false)
		_check("⑧n 해금된 세트 재구매는 거절(엽전 안 나감)", m.wallet.gold == g2)
		_check("⑧o 해금 뒤 행이 잠긴다",
			bool(_first_of_kind(m._peddler_items(), Peddler.KIND_DECO).get("locked", false)))

	# ── ⑨ Books · 레어크로우 구매 배선(그 물건이 뜨는 날로 시계를 옮겨 실제로 산다) ──
	print("── ⑨ Books · 레어크로우 구매 배선 ──")
	var book_day := 0
	for d in days:
		var rr5 := Peddler.rare_row(int(d), [], {})
		if not rr5.is_empty() and str(rr5["kind"]) == Peddler.KIND_BOOK:
			book_day = int(d)
			break
	if book_day == 0:
		_check("⑨a 책이 뜨는 출현일이 표본 40주 안에 있다", false)
	else:
		m.clock.day = book_day
		m.books.load_save({})
		m.wallet.gold = 999999
		var brow := _first_of_kind(m._peddler_items(), Peddler.KIND_BOOK)
		if brow.is_empty():
			brow = {"buy_id": "", "price": 0, "name": ""}
		var bid := str(brow["buy_id"])
		var bprice := int(brow["price"])
		var gb: int = m.wallet.gold
		_check("⑨a 책 행 이름판은 Books가 낸다(카탈로그 아님)", str(brow["name"]) == Books.title_of(bid))
		m._on_frame_buy_store_item(bid, Peddler.KIND_BOOK, false)
		_check("⑨b 책 입수 = 인벤 적재 + Books 원장 등재 + 표시가 지출",
			m.inventory.count_of(bid) == 1 and m.books.has_acquired(bid)
			and m.wallet.gold == gb - bprice)
		_check("⑨c 즉독을 안 연다 — **미독으로 남아** 집 책장이 회수한다(모달 겹침 유실 방지)",
			not m.books.is_read(bid) and m.books.next_reread() == bid)
		var gb2: int = m.wallet.gold
		m._on_frame_buy_store_item(bid, Peddler.KIND_BOOK, false)
		_check("⑨d 되찾은 책은 재구매 거절(엽전 안 나감)", m.wallet.gold == gb2
			and m.inventory.count_of(bid) == 1)
		# ★★ 하루 한 점 잠금 — 이 슬라이스에서 **실제로 뚫려 있던 구멍**이다(초판 회귀가 잡아냈다):
		#    산 책이 미보유 풀에서 빠지면 같은 날 같은 슬롯이 *다른 책*으로 즉시 다시 차서, 연타로
		#    하루에 23권을 통째로 살 수 있었다. 그래서 세 층을 다 잰다 — 행이 안 바뀌는가 / 잠기는가 /
		#    **다른 책이 실제로 안 팔리는가**(표시만 잠그고 결제가 열려 있으면 고친 게 아니다).
		var brow2 := _first_of_kind(m._peddler_items(), Peddler.KIND_BOOK)
		_check("⑨e 되찾은 뒤에도 **산 그 책이** 그 자리에 서 있고 잠긴다(즉시 재충전 0)",
			not brow2.is_empty() and str(brow2["buy_id"]) == bid
			and bool(brow2.get("locked", false)))
		var other := ""
		for oid in Books.all_ids():
			if str(oid) != bid:
				other = str(oid)
				break
		var gb3: int = m.wallet.gold
		var acq3: int = m.books.acquired_count()
		m._on_frame_buy_store_item(other, Peddler.KIND_BOOK, false)
		_check("⑨e2 같은 날 다른 책은 **결제 자체가 성립 안 한다**(하루 한 점 — 연타 쓸이 차단)",
			m.wallet.gold == gb3 and m.books.acquired_count() == acq3
			and not m.books.has_acquired(other))
		_check("⑨e3 잠금 진실원이 원장에 남는다(day + 그때 산 id)",
			m.peddler.rare_taken_on(book_day) and m.peddler.rare_id == bid
			and not m.peddler.rare_taken_on(book_day + Peddler.APPEAR_MODULUS))
		# 다음 출현일엔 슬롯이 정상으로 돌아온다(하루 잠금이지 영구 잠금이 아니다).
		m.clock.day = book_day + Peddler.APPEAR_MODULUS
		_check("⑨e4 다음 출현일엔 희귀 슬롯이 다시 열린다(하루 잠금 ≠ 영구 잠금)",
			m._peddler_items().size() == Peddler.TOTAL_ROWS
			and not m.peddler.rare_taken_on(m.clock.day))
		m.clock.day = book_day
	if not crow_registered:
		_check("⑨f [미등재 경로] 레어크로우 ⑤ 구매 배선은 T2 결합 후 강한 경로로 검증된다", true)
	else:
		var crow_day := 0
		for d in days:
			var rr6 := Peddler.rare_row(int(d), [], {})
			if not rr6.is_empty() and str(rr6["kind"]) == Peddler.KIND_RARE:
				crow_day = int(d)
				break
		m.clock.day = maxi(crow_day, Peddler.APPEAR_MODULUS)
		m.peddler.load_save({})
		m.wallet.gold = 999999
		var crow := _first_of_kind(m._peddler_items(), Peddler.KIND_RARE)
		if crow.is_empty():
			_check("⑨f-pre [등재 경로] 레어크로우 ⑤가 뜨는 출현일을 찾았다", false)
			crow = {"price": 0}
		var cprice := int(crow["price"])
		var gc: int = m.wallet.gold
		m._on_frame_buy_store_item(Peddler.RARECROW_ID, Peddler.KIND_RARE, false)
		_check("⑨f [등재 경로] 레어크로우 ⑤ 획득 + 표시가 지출",
			m.inventory.count_of(Peddler.RARECROW_ID) == 1 and m.wallet.gold == gc - cprice)
		var gc2: int = m.wallet.gold
		m._on_frame_buy_store_item(Peddler.RARECROW_ID, Peddler.KIND_RARE, false)
		_check("⑨g [등재 경로] 두 번째 구매는 거절(1회 한정 — 엽전 안 나감)",
			m.inventory.count_of(Peddler.RARECROW_ID) == 1 and m.wallet.gold == gc2)
		_check("⑨h [등재 경로] 원장에 이력이 남아 이후 출현일에서 사라진다",
			m.peddler.has_bought(Peddler.RARECROW_ID)
			and _first_of_kind(Peddler.stock_rows(crow_day + Peddler.APPEAR_MODULUS * 3,
				m.peddler.bought, {}), Peddler.KIND_RARE).is_empty())

	# ── ⑩ 무손실 · 세이브 왕복 ──
	print("── ⑩ 무손실 · 세이브 왕복 ──")
	m.clock.day = d0
	m.peddler.load_save({})
	var gold_idle: int = m.wallet.gold
	var _rows_idle: Array = m._peddler_items()   # 열어만 보고 아무것도 안 산다
	_check("⑩a 열어만 보면 지갑이 그대로다(옵트인 — 안 사도 잃는 것 0)", m.wallet.gold == gold_idle)
	var lock_book := str(Books.all_ids()[0])
	m.peddler.load_save({"bought": [Peddler.RARECROW_ID],
		"rare_day": d0, "rare_id": lock_book})
	m._save_game()
	var saved: Dictionary = m.saver.load_game()
	_check("⑩b 세이브에 \"peddler\" 키가 있다", saved.has("peddler"))
	m.queue_free()
	await process_frame
	await process_frame
	var m2: Node = await _spawn_main()
	_check("⑩c 구매 이력 복원", m2.peddler.has_bought(Peddler.RARECROW_ID))
	# ★ 하루 한 점 잠금도 반드시 왕복해야 한다 — 안 그러면 사고 저장하고 **정상 이어하기**만 해도
	#   그날 희귀 슬롯이 되살아나 구멍이 그대로 다시 열린다(세이브-스컴이 아니라 평범한 이어하기다).
	_check("⑩d 희귀 슬롯 잠금(day + id) 복원",
		m2.peddler.rare_taken_on(d0) and m2.peddler.rare_id == lock_book)
	m2.peddler.load_save({})
	_check("⑩e 키 없는 구세이브 = 빈 원장·잠금 없음(막힘 0 — 다음 7의 배수 날에 그냥 온다)",
		m2.peddler.bought.is_empty() and not m2.peddler.rare_taken_on(d0)
		and Peddler.is_open_day(d0))
	m2.peddler.load_save({"bought": "쓰레기", "rare_day": -5, "rare_id": 99})
	_check("⑩f 손상 세이브 방어(타입 불일치·음수 day)", m2.peddler.bought.is_empty()
		and not m2.peddler.rare_taken_on(d0) and m2.peddler.rare_id == "")
	m2.peddler.load_save({"rare_day": d0, "rare_id": "사라진_유령_id"})
	_check("⑩g 테이블에서 사라진 id의 잠금은 **여는 쪽으로** 푼다(막힘 0)",
		not m2.peddler.rare_taken_on(d0))
	m2.peddler.load_save({"bought": ["x", "x", ""]})
	_check("⑩h 중복·빈 id는 걸러 넣는다", m2.peddler.bought.size() == 1)

	# ── ⑪ 좌판 표식 _draw — **그 무대에 실제로 서서** 크래시 없이 돈다 ──
	print("── ⑪ 좌판 표식 _draw ──")
	m2._rebuild_region(RegionCatalog.NARU_VILLAGE)
	m2.clock.day = d0
	_check("⑪a 나루 마을 · 보부상 출현일", m2._region == RegionCatalog.NARU_VILLAGE
		and Peddler.is_open_day(m2.clock.day))
	m2.queue_redraw()
	await process_frame
	await process_frame
	m2.clock.day = d0 + 1     # 떠난 다음 날 — 아무것도 안 그린다(흔적 0)
	m2.queue_redraw()
	await process_frame
	await process_frame
	_check("⑪b 출현일·비출현일 양쪽에서 좌판 _draw 크래시 없음(떠난 뒤 흔적 0)", true)
	m2.queue_free()
	await process_frame

	# ── ⑫ 클릭이 실제로 구매로 이어지는가(프레임 kind 허용 목록 소스 스캔) ──
	# ★ 이 단언이 생긴 이유: `InventoryFrame._buy_store_row`가 **kind 허용 목록**으로 신호를 거르는데,
	#   야시장 3종("fest_*")이 그 목록에서 빠져 있어 **매대 행을 클릭해도 아무 일이 안 일어나는** 잠복
	#   결함이 있었다(S7-T7). 회귀가 못 잡은 이유는 테스트가 프레임을 건너뛰고 `_on_frame_buy_store_item`을
	#   직접 불렀기 때문이다 — 즉 "핸들러는 맞는데 신호가 안 온다"는 층이 통째로 무검증이었다.
	#   여기서 **매대가 내는 kind 전부가 허용 목록에 있는지**를 소스로 대조해 그 클래스를 닫는다.
	print("── ⑫ 프레임 kind 허용 목록(클릭 → 구매 신호) ──")
	var frame_src := FileAccess.open("res://inv_frame.gd", FileAccess.READ).get_as_text()
	var allow_line := ""
	for ln in frame_src.split("\n"):
		var s2 := String(ln).strip_edges()
		if s2.begins_with("#"):
			continue
		if s2.contains("\"sapling\"") and s2.ends_with(":"):
			allow_line = s2
			break
	var missing: Array = []
	for k in [Peddler.KIND_ITEM, Peddler.KIND_SEED, Peddler.KIND_DECO, Peddler.KIND_RARE,
			Peddler.KIND_BOOK, "fest_deco", "fest_item", "fest_seed"]:
		if not allow_line.contains("\"%s\"" % str(k)):
			missing.append(str(k))
	_check("⑫a 허용 목록 행을 찾았다", allow_line != "")
	_check("⑫b 보부상 5종 + 야시장 3종이 전부 허용 목록에 있다(누락 %s)" % str(missing), missing.is_empty())

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ %s ══" % ("전체 통과" if _fail == 0 else "실패 %d건" % _fail))
	quit(1 if _fail > 0 else 0)

# main의 const 타일 좌표를 읽는 얇은 헬퍼(스크립트 상수는 인스턴스를 통해 읽는다).
func PEDDLER_TILE_OF(m: Node) -> Vector2i:
	return m.get_script().get_script_constant_map()["PEDDLER_TILE"]
