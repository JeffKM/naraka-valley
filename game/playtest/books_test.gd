extends SceneTree
# ★[S9-T7 / ADR-0067 결정 8 · ADR-0034] 옥자 Books 채널 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 카탈로그 속성 — CAT_BOOK이 **선물 불가·비매·스택 불가**이고 has_item/name_of가 잡는다.
#   ② 텍스트 테이블 — 책 8 + 노트 15가 제목·본문·메모를 갖추고 id 교집합이 0이다.
#   ③ 입수 롤 — 네 원천 전부 **결정적**이고, 확률이 표대로이며, **이미 주운 것은 안 나온다**.
#   ④ 수집 원장 — 입수 멱등·책/노트 분리 카운트·기독 원장·미독 수.
#   ⑤ 인라인 즉독 — 주운 자리에서 대화창이 열리고 **대화 중이면 안 열리되 미독으로 남는다**.
#   ⑥ 집 책장 재읽기 — 미독 우선 → 순환. 좌표·실내 가드. 빈 책장은 대화창을 안 연다.
#   ⑦ 혼백관 — 책은 기증되고 **노트는 안 된다**. 트래커 분모 11 · 마일스톤 산입 · 기존 행 보존.
#   ⑧ 세이브 왕복 — 입수·기독 원장이 이어하기에 살아남고, 구세이브는 빈 원장, 손상은 정제된다.
#   ⑨ 봉인 법칙 가드([ADR-0067] 결정 8 체크리스트 기계 판정분) — placeholder 본문 어디에도
#      플레이어 죄목의 **중심 평결**·세 조각으로 읽힐 어휘가 없다.
#   ⑩ main 배선 — 네 입수 지점이 실제로 롤을 부른다(소스 구조 검증).
#
# 실행: TIMEOUT=180 ./run_tests.sh books   (헤드리스는 반드시 game/에서 · 순차)

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

# 신규 시작의 옥자 통보 대화를 끝까지 넘겨 닫는다(즉독 검증 전에 무대를 비운다).
func _dismiss_intro(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

# 그 원천에서 **드랍이 걸리는** 첫 serial을 찾는다(없으면 -1). 확률이 낮아 손으로 못 고르므로
# 테스트가 결정적 롤을 그대로 뒤져 쓴다(같은 입력 = 같은 결과라 이 탐색 자체가 재현 가능하다).
func _find_hit(source: String, day: int, owned: Dictionary) -> int:
	for s in 4000:
		if Books.peek_drop(source, day, s, owned) != "":
			return s
	return -1

# **주석을 걷어낸 코드 본문**(주석이 검사 문자열을 우연히 품는 오탐 방지 — miho_arc_test 선례).
func _strip_comments(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var out := PackedStringArray()
	for ln in f.get_as_text().split("\n"):
		if not String(ln).strip_edges().begins_with("#"):
			out.append(String(ln))
	return "\n".join(out)

func _main_source() -> String:
	return _strip_comments("res://main.gd")

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S9-T7 옥자 Books 채널(books.gd) 검증 ══")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var a_book := "book_okja_1"
	var a_note := "note_secret_1"

	# ── ② 텍스트 테이블(다른 검증의 전제라 맨 앞) ──
	print("── ② 텍스트 테이블 ──")
	_check("②a 책 8권(ADR-0067 결정 8 볼륨)",
		Books.book_ids().size() == 8 and Books.BOOK_COUNT == 8)
	_check("②b 비밀 노트 15장", Books.note_ids().size() == 15 and Books.NOTE_COUNT == 15)
	_check("②c 전 id 23종·중복 0", Books.all_ids().size() == 23)
	var table_ok := true
	var title_seen := {}
	for id in Books.all_ids():
		var sid := str(id)
		if Books.title_of(sid) == "" or Books.lines_of(sid).is_empty():
			table_ok = false
		if title_seen.has(Books.title_of(sid)):
			table_ok = false
		title_seen[Books.title_of(sid)] = true
		for ln in Books.lines_of(sid):
			if String(ln).strip_edges() == "":
				table_ok = false
	_check("②d 전 행이 제목·본문을 갖췄다(빈 줄 0·제목 중복 0)", table_ok)
	var note_ok := true
	for id in Books.all_ids():
		if not Books._row(str(id)).has("note"):
			note_ok = false
	_check("②e 전 행이 트리거/배치 메모를 갖췄다(T8 주입 자리 표식)", note_ok)
	_check("②f 책과 노트는 서로 다른 집합",
		Books.is_book(a_book) and not Books.is_note(a_book)
		and Books.is_note(a_note) and not Books.is_book(a_note))
	_check("②g 미지 id는 전부 빈값(조회 방어)",
		not Books.has_text("__nope__") and Books.title_of("__nope__") == ""
		and Books.lines_of("__nope__").is_empty())
	# placeholder 성질 — T8이 본문을 채우기 전까지는 "아직 읽히지 않는다"가 살아 있어야 한다.
	var placeholder_ok := true
	for id in Books.all_ids():
		if not "\n".join(Books.lines_of(str(id))).contains("아직 읽히지 않는다"):
			placeholder_ok = false
	_check("②h 전 본문이 placeholder다(T8 주입 전 상태 — 그릇만)", placeholder_ok)

	# ── ① 카탈로그 속성 ──
	print("── ① 카탈로그 속성 ──")
	var cat_ok := true
	var gift_ok := true
	var price_ok := true
	var stack_ok := true
	var name_ok := true
	for id in Books.all_ids():
		var sid := str(id)
		if not ItemCatalog.has_item(sid):
			cat_ok = false
		if ItemCatalog.category_of(sid) != ItemCatalog.CAT_BOOK:
			cat_ok = false
		if GiftPrefs.giftable(sid):
			gift_ok = false
		if ItemCatalog.price_of(sid) != 0:
			price_ok = false
		if ItemCatalog.stackable_of(sid):
			stack_ok = false
		if ItemCatalog.name_of(sid) != Books.title_of(sid):
			name_ok = false
	_check("①a 전 23종이 has_item·CAT_BOOK", cat_ok)
	_check("①b **선물 불가**(ADR-0034 #7 — 유품 키프세이크)", gift_ok)
	_check("①c **비매**(price 0 — 팔 수도 살 수도 없다)", price_ok)
	_check("①d 스택 불가(세상에 한 권씩 — 중복 입수 0의 짝)", stack_ok)
	_check("①e 표시명 = Books.title_of 위임(단일 출처)", name_ok)
	_check("①f ids_in_category(CAT_BOOK) = 23종 열거",
		ItemCatalog.ids_in_category(ItemCatalog.CAT_BOOK).size() == 23)
	_check("①g 유품은 여전히 선물 가능·유가(책과 갈리는 지점이 안 무너졌다)",
		GiftPrefs.giftable(ItemCatalog.RELIC_BINYEO)
		and ItemCatalog.price_of(ItemCatalog.RELIC_BINYEO) > 0)
	_check("①h 그레이박스 색이 책/노트를 가른다(아이콘 폴백)",
		ItemCatalog.tool_color_of(a_book) != ItemCatalog.tool_color_of(a_note))

	# ── ③ 입수 롤 ──
	print("── ③ 입수 롤 ──")
	var sources: Array = [Books.SRC_MINE, Books.SRC_FISH, Books.SRC_FORAGE, Books.SRC_DEBRIS]
	var permil_ok := true
	for s in sources:
		if Books.permil_of(str(s)) <= 0:
			permil_ok = false
	_check("③a 네 원천 전부 양의 확률(갱도·낚시·미혹 채집·개간)",
		sources.size() == 4 and permil_ok)
	_check("③b 미지 원천은 0퍼밀 = 절대 안 나온다(오타 방어)",
		Books.permil_of("__nope__") == 0 and Books.peek_drop("__nope__", 3, 7, {}) == "")
	# 결정성 — 같은 (원천, day, serial)은 언제 굴려도 같은 결과.
	var hit := _find_hit(Books.SRC_MINE, 5, {})
	_check("③c 갱도 롤에 실제로 걸리는 serial이 있다", hit >= 0)
	var r1 := Books.peek_drop(Books.SRC_MINE, 5, hit, {})
	var r2 := Books.peek_drop(Books.SRC_MINE, 5, hit, {})
	_check("③d 같은 입력 = 같은 결과(결정 롤)", r1 == r2 and r1 != "")
	_check("③e 날이 다르면 스트림이 다르다",
		Books.peek_drop(Books.SRC_MINE, 6, hit, {}) != r1
		or Books.peek_drop(Books.SRC_MINE, 7, hit, {}) != r1)
	_check("③f 원천이 다르면 스트림이 다르다(네 축이 안 얽힌다)",
		Books.peek_drop(Books.SRC_DEBRIS, 5, hit, {}) != r1
		or Books.peek_drop(Books.SRC_FORAGE, 5, hit, {}) != r1)
	# 확률 실측 — 원천별 퍼밀 ±12퍼밀 허용(2000표본).
	var band_ok := true
	for s in sources:
		var src := str(s)
		var hits := 0
		for i in 2000:
			if Books.peek_drop(src, 11, i, {}) != "":
				hits += 1
		var measured := hits * 1000.0 / 2000.0
		var ok := absf(measured - float(Books.permil_of(src))) <= 12.0
		if not ok:
			band_ok = false
		print("      · %s: 표기 %d퍼밀 / 실측 %.1f" % [src, Books.permil_of(src), measured])
	_check("③g 원천별 확률이 표대로다(±12퍼밀)", band_ok)
	# 산출물은 항상 유효 아이템이고, 노트가 책보다 흔하다(ADR-0034 #1 "노트=흔함/책=귀함").
	var member_ok := true
	var n_book := 0
	var n_note := 0
	for i in 4000:
		var id := Books.peek_drop(Books.SRC_FORAGE, 13, i, {})
		if id == "":
			continue
		if not Books.has_text(id):
			member_ok = false
		if Books.is_book(id):
			n_book += 1
		else:
			n_note += 1
	_check("③h 산출물은 전부 테이블 소속", member_ok)
	_check("③i 노트가 책보다 흔하다(떡밥=넓음 / 책=귀함)", n_note > n_book and n_book > 0)
	# 미입수 필터 — 이미 가진 것은 절대 안 나온다.
	var owned_all_books := {}
	for id in Books.book_ids():
		owned_all_books[str(id)] = 1
	var dup_ok := true
	var got_note := false
	for i in 3000:
		var id2 := Books.peek_drop(Books.SRC_FISH, 21, i, owned_all_books)
		if id2 == "":
			continue
		if owned_all_books.has(id2):
			dup_ok = false
		if Books.is_note(id2):
			got_note = true
	_check("③j 이미 주운 것은 다시 안 나온다(중복 입수 0)", dup_ok)
	_check("③k 한 종류가 동나도 다른 종류로 넘어간다(막힘 0)", got_note)
	var owned_all := {}
	for id in Books.all_ids():
		owned_all[str(id)] = 1
	var exhausted_ok := true
	for i in 500:
		if Books.peek_drop(Books.SRC_MINE, 31, i, owned_all) != "":
			exhausted_ok = false
	_check("③l 전부 모으면 더 나오지 않는다", exhausted_ok)

	# ── ④ 수집 원장 ──
	print("── ④ 수집 원장 ──")
	var bk := Books.new()
	_check("④a 처음엔 빈 원장",
		bk.acquired_count() == 0 and bk.unread_count() == 0 and bk.acquired_ids().is_empty())
	_check("④b 미지 id 입수 거절", not bk.acquire("__nope__", 1) and bk.acquired_count() == 0)
	_check("④c 입수 = 원장 적재", bk.acquire(a_book, 3) and bk.has_acquired(a_book))
	_check("④d 같은 것 재입수 거절(멱등)", not bk.acquire(a_book, 4) and bk.acquired_count() == 1)
	_check("④e 입수분은 미독이다", bk.unread_count() == 1 and not bk.is_read(a_book))
	bk.acquire(a_note, 5)
	_check("④f 책/노트를 따로 센다",
		bk.acquired_book_count() == 1 and bk.acquired_note_count() == 1 and bk.acquired_count() == 2)
	_check("④g 주운 적 없는 것은 기독 거절", not bk.mark_read("book_okja_5"))
	_check("④h 기독 = 원장 적재", bk.mark_read(a_book) and bk.is_read(a_book))
	_check("④i 기독 처리는 멱등", not bk.mark_read(a_book) and bk.unread_count() == 1)
	_check("④j 입수 순서(day 오름차순)로 나열",
		bk.acquired_ids().size() == 2 and str(bk.acquired_ids()[0]) == a_book)
	_check("④k pending_drop = 인스턴스 원장을 본다(주운 것은 안 뽑힌다)",
		bk.pending_drop(Books.SRC_MINE, 5, hit) != a_book)

	# ── ⑥ 책장 재읽기(원장 층위) ──
	print("── ⑥ 책장 재읽기 ──")
	_check("⑥a 미독을 먼저 집는다", bk.next_reread() == a_note)
	bk.mark_read(a_note)
	var first := bk.next_reread()
	var second := bk.next_reread()
	_check("⑥b 전부 읽었으면 순환한다(연타 = 다음 권)",
		first != "" and second != "" and first != second)
	_check("⑥c 한 바퀴 돌면 처음으로 돌아온다", bk.next_reread() == first)
	var bk_empty := Books.new()
	_check("⑥d 빈 책장은 빈 문자열(빈 대화창 차단의 근거)", bk_empty.next_reread() == "")
	bk_empty.free()

	# ── ⑧a load_save 정제(손상 방어) ──
	print("── ⑧a load_save 정제 ──")
	var bk2 := Books.new()
	bk2.load_save({"acquired": {a_book: 3, "__nope__": 9}, "read": {"__nope__": true, a_note: true}})
	_check("⑧a1 테이블에 없는 id는 버린다",
		bk2.acquired_count() == 1 and bk2.has_acquired(a_book))
	_check("⑧a2 입수 원장에 없는 기독 기록은 버린다", bk2.read_ledger.is_empty())
	bk2.load_save({"acquired": "쓰레기", "read": 7})
	_check("⑧a3 형식 손상 = 빈 원장(예외 없이)",
		bk2.acquired_count() == 0 and bk2.read_ledger.is_empty())
	bk2.free()
	bk.free()

	# ── ⑦ 혼백관 전시 ──
	print("── ⑦ 혼백관 전시 ──")
	_check("⑦a 책은 기증 대상", Museum.is_donatable(a_book))
	_check("⑦b **노트는 기증 대상이 아니다**(떡밥은 유품이 아니다)", not Museum.is_donatable(a_note))
	_check("⑦c 유품은 여전히 기증 대상", Museum.is_donatable(ItemCatalog.RELIC_BINYEO))
	_check("⑦d 트래커 분모 = 유품 3 + 책 8 = 11", Museum.donatable_ids().size() == 11)
	var order_ok: bool = str(Museum.donatable_ids()[0]) == ItemCatalog.RELIC_BINYEO \
		and str(Museum.donatable_ids()[3]) == "book_okja_1"
	_check("⑦e 좌대 순서 = 유품 먼저·책 나중(진열 인덱스 안정)", order_ok)
	var mus := Museum.new()
	_check("⑦f 노트는 기증 거부", not mus.donate(a_note, 1) and mus.donated_count() == 0)
	_check("⑦g 책 기증 성공", mus.donate(a_book, 2) and mus.is_donated(a_book))
	_check("⑦h 같은 책 중복 거부", not mus.donate(a_book, 3) and mus.donated_count() == 1)
	_check("⑦i **책 기증이 마일스톤에 산입된다**(유품과 한 통에 센다)",
		mus.pending_milestones().size() == 1 and int(mus.pending_milestones()[0]["count"]) == 1)
	# 마일스톤 사다리 — 기존 1·2·3 보존 + 5·8·11 연장, 보상은 전부 유효 아이템.
	var counts: Array = []
	var reward_ok := true
	for row in Museum.MILESTONES:
		counts.append(int(row["count"]))
		if not ItemCatalog.has_item(String(row["reward_id"])) or int(row["n"]) <= 0:
			reward_ok = false
	_check("⑦j 사다리 = 1·2·3(보존) + 5·8·11(연장)", counts == [1, 2, 3, 5, 8, 11])
	_check("⑦k 보상 전 행 = 유효 아이템·양수", reward_ok)
	_check("⑦l 꼭대기 = 분모와 같다(완주에 답례가 있다)",
		int(Museum.MILESTONES[Museum.MILESTONES.size() - 1]["count"]) == Museum.donatable_ids().size())
	# 책 3권을 더 넣어 5점 문턱이 실제로 뜨는가.
	mus.claim(1)
	mus.donate("book_okja_2", 4)
	mus.donate("book_okja_3", 5)
	mus.donate("book_okja_4", 6)
	mus.donate("book_okja_5", 7)
	var pend: Array = mus.pending_milestones()
	var pend_counts: Array = []
	for row in pend:
		pend_counts.append(int(row["count"]))
	_check("⑦m 책만으로 5점 도달 → 2·3·5 문턱이 함께 선다", pend_counts == [2, 3, 5])
	mus.free()

	# ── ⑤ main 배선 · 인라인 즉독 ──
	print("── ⑤ main 배선·인라인 즉독 ──")
	var m: Node = await _spawn_main()
	_dismiss_intro(m)
	_check("⑤a Books 노드가 붙어 있다", m.books != null and m.books.acquired_count() == 0)
	# 오늘 날짜에서 걸리는 serial을 찾아 즉독 경로를 태운다.
	var day: int = m.clock.day
	var hit2 := _find_hit(Books.SRC_DEBRIS, day, m.books.acquired)
	_check("⑤b 오늘 개간 롤에 걸리는 serial이 있다", hit2 >= 0)
	var expect := Books.peek_drop(Books.SRC_DEBRIS, day, hit2, m.books.acquired)
	m._roll_book_drop(Books.SRC_DEBRIS, hit2)
	_check("⑤c 인벤토리에 실물이 들어온다", m.inventory.count_of(expect) == 1)
	_check("⑤d 입수 원장에 오른다", m.books.has_acquired(expect) and m.books.acquired_count() == 1)
	_check("⑤e 주운 자리에서 바로 펼쳐진다(인라인 즉독 — 혼백관 방문 게이트 0)",
		m.dialogue.is_open() and m.dialogue.speaker() == Books.title_of(expect)
		and m.dialogue.line() == Books.lines_of(expect)[0])
	_check("⑤f 읽는 동안 이동 잠금", not m.player.is_physics_processing())
	_check("⑤g 여는 순간 기독", m.books.is_read(expect) and m.books.unread_count() == 0)
	# 같은 (day, serial)을 다시 굴려도 같은 것이 두 번 나오지 않는다(미입수 필터의 실전 확인 —
	# 원장이 갱신됐으니 그 조각은 이제 후보에서 빠진다).
	_check("⑤h 같은 사건을 다시 굴려도 그 조각은 다시 안 나온다",
		Books.peek_drop(Books.SRC_DEBRIS, day, hit2, m.books.acquired) != expect
		and m.inventory.count_of(expect) == 1)
	var guard := 0
	while m.dialogue.is_open() and guard < 20:
		m.dialogue.advance()
		guard += 1
	_check("⑤i 끝까지 넘기면 닫히고 이동 잠금 해제",
		not m.dialogue.is_open() and m.player.is_physics_processing())
	# ★ 대화 중 입수 = 대화창을 가로채지 않고 **미독으로 남는다**(T3 실증 함정의 선제 봉합).
	var hit3 := _find_hit(Books.SRC_MINE, day, m.books.acquired)
	var expect3 := Books.peek_drop(Books.SRC_MINE, day, hit3, m.books.acquired)
	m.dialogue.start("점주", PackedStringArray(["대화 중이다.", "두 번째 줄."]))
	m._roll_book_drop(Books.SRC_MINE, hit3)
	_check("⑤j 대화 중이면 그 대화를 밀어내지 않는다",
		m.dialogue.is_open() and m.dialogue.speaker() == "점주")
	_check("⑤k 그래도 실물·원장은 들어온다(주운 사실은 유실 0)",
		m.books.has_acquired(expect3) and m.inventory.count_of(expect3) == 1)
	_check("⑤l 대신 **미독으로 남는다**(책장이 회수한다)",
		not m.books.is_read(expect3) and m.books.unread_count() == 1)
	guard = 0
	while m.dialogue.is_open() and guard < 20:
		m.dialogue.advance()
		guard += 1

	# ── ⑥ 집 책장 [F] 배선 ──
	print("── ⑥ 집 책장 배선 ──")
	m._sleeping = false
	m._indoor = "집"
	m._target = m.BOOKSHELF_TILES[0]
	var faced: bool = m._facing_bookshelf()
	m._target = m.BOOKSHELF_TILES[1]
	var faced2: bool = m._facing_bookshelf()
	_check("⑥e 책장 두 칸 다 창구가 선다(옆칸 먹통 0)", faced and faced2)
	m._indoor = ""
	var faced_out: bool = m._facing_bookshelf()
	m._indoor = "집"
	_check("⑥f 실외에선 같은 좌표라도 무반응", not faced_out)
	m._target = m.BOOKSHELF_TILES[0] + Vector2i(0, 3)
	var faced_off: bool = m._facing_bookshelf()
	m._target = m.BOOKSHELF_TILES[0]
	_check("⑥g 다른 칸을 보면 무반응", not faced_off)
	m._read_from_bookshelf()
	_check("⑥h 책장 [F] = 미독을 먼저 펼친다(대화 중 놓친 것 회수)",
		m.dialogue.is_open() and m.dialogue.speaker() == Books.title_of(expect3)
		and m.books.is_read(expect3))
	guard = 0
	while m.dialogue.is_open() and guard < 20:
		m.dialogue.advance()
		guard += 1
	m._read_from_bookshelf()
	_check("⑥i 전부 읽었으면 소장분을 다시 펼친다", m.dialogue.is_open())
	guard = 0
	while m.dialogue.is_open() and guard < 20:
		m.dialogue.advance()
		guard += 1
	# 빈 책장(원장을 비운 새 인스턴스)은 대화창을 안 연다.
	var m_empty: Node = await _spawn_main()
	_dismiss_intro(m_empty)
	m_empty.books.acquired = {}
	m_empty.books.read_ledger = {}
	m_empty._read_from_bookshelf()
	_check("⑥j 빈 책장은 대화창을 안 연다(빈 대화창 차단)", not m_empty.dialogue.is_open())
	m_empty.free()

	# ── ⑦ 혼백관 main 통합(든 책 기증) ──
	print("── ⑦ 혼백관 main 통합 ──")
	# ★ 즉독 경로가 준 것(expect/expect3)은 **노트일 수 있다**(노트가 70%). 노트는 설계상 기증
	#   대상이 아니므로(⑦b), 기증 통합은 아직 안 주운 **책**을 명시적으로 손에 들려 검증한다.
	var bid := ""
	for id in Books.book_ids():
		if not m.books.has_acquired(str(id)):
			bid = str(id)
			break
	m.books.acquire(bid, day)
	m.inventory.add_item(bid, 1)
	var slot := -1
	for i in m.inventory.SIZE:
		if m.inventory.id_at(i) == bid:
			slot = i
			break
	_check("⑦n 되찾은 책이 인벤 슬롯에 있다",
		bid != "" and slot >= 0 and m.inventory.count_of(bid) == 1)
	m.inventory.selected_index = slot
	m.museum.donated = {}
	m.museum.claimed = []
	_check("⑦o 든 책이 기증 가능으로 판정된다", m.museum.can_donate(bid))
	m._try_donate_selected()
	_check("⑦p 기증 = 원장 기록·실물 1개 소모",
		m.museum.is_donated(bid) and m.inventory.count_of(bid) == 0)
	_check("⑦q 책 기증도 마일스톤 답례를 받는다", m.museum.claimed.has(1))
	# 든 것이 **노트**면 기증 창구가 조용히 거절한다(전시 대상 분리의 실전 확인).
	var nslot := -1
	for i in m.inventory.SIZE:
		if Books.is_note(m.inventory.id_at(i)):
			nslot = i
			break
	if nslot >= 0:
		var nid: String = str(m.inventory.id_at(nslot))
		m.inventory.selected_index = nslot
		m._try_donate_selected()
		_check("⑦q2 든 노트는 기증되지 않는다(실물도 안 사라진다)",
			not m.museum.is_donated(nid) and m.inventory.count_of(nid) == 1)
	# 버리기 금지 — 되찾은 것은 휴지통으로 못 보낸다(수집 완주 봉쇄 방어).
	var kslot := -1
	for i in m.inventory.SIZE:
		if m.inventory.id_at(i) == expect3:
			kslot = i
			break
	_check("⑦r0 버리기 검증 전제(슬롯 확보)", kslot >= 0 and m.inventory.count_of(expect3) == 1)
	m._on_frame_discard(kslot)
	_check("⑦r 책은 버릴 수 없다(영구 유실 봉쇄)", m.inventory.count_of(expect3) == 1)

	# ── ⑧ 세이브 왕복 ──
	print("── ⑧ 세이브 왕복 ──")
	var save_acq: int = m.books.acquired_count()
	var save_read: int = m.books.read_ledger.size()
	m._save_game()
	var m2: Node = await _spawn_main()
	_check("⑧b 입수 원장이 이어하기에 살아 있다",
		m2.books.acquired_count() == save_acq and m2.books.has_acquired(expect3))
	_check("⑧c 기독 원장도 복원", m2.books.read_ledger.size() == save_read)
	_check("⑧d 복원 후에도 이미 주운 것은 다시 안 뽑힌다",
		not owned_reroll(m2.books, expect3))
	# 구세이브 하위호환 — "books" 키가 없으면 빈 원장.
	var payload: Dictionary = m2.saver.load_game(m2._active_slot)
	_check("⑧e 세이브에 books 조각이 실제로 있다(다음 단언의 전제)", payload.has("books"))
	payload.erase("books")
	m2.saver.save_game(payload, m2._active_slot, {})
	var m3: Node = await _spawn_main()
	_check("⑧f 키 없는 구세이브 = 빈 원장으로 조용히 시작",
		m3.books != null and m3.books.acquired_count() == 0 and m3.books.unread_count() == 0)
	_check("⑧g 빈 원장이라도 입수는 정상 동작(막히는 것 0)",
		m3.books.pending_drop(Books.SRC_FISH, m3.clock.day, _find_hit(Books.SRC_FISH, m3.clock.day, {})) != "")

	# ── ⑨ 봉인 법칙 가드(기계 판정분) ──
	print("── ⑨ 봉인 법칙 ──")
	# 책은 **타인의 말**이라 중심 평결을 서술하면 키스톤 위반이다(ADR-0034 #3 · ADR-0067 결정 8).
	# placeholder도 그 규칙을 이미 지키지만, T8이 본문을 부을 때 이 가드가 회귀로 남는다.
	var verdicts := ["네 죄는", "너의 죄는", "네가 지은 죄", "네 죄목", "그러니까 네가",
		"너 때문에 옥자", "네가 옥자를 죽", "너는 외면했", "네가 외면한",
		"감정의 조각", "사실의 조각", "행동의 조각"]
	var offender := ""
	for id in Books.all_ids():
		var body := Books.title_of(str(id)) + "\n" + "\n".join(Books.lines_of(str(id)))
		for w in verdicts:
			if body.contains(String(w)):
				offender = body
				break
		if offender != "":
			break
	_check("⑨a 중심 평결·세 조각 어휘 0(책이 평결을 먼저 말하지 않는다)", offender == "")
	if offender != "":
		print("      ↳ 걸린 본문: " + offender)
	var src := _strip_comments("res://books.gd")
	_check("⑨b 책은 호감도 미터를 만들지 않는다(옥자 = 무미터 앵커)",
		not src.contains("Affinity") and not src.contains("add_points"))
	_check("⑨c 책은 성장 축이 아니다(영구 % 곱셈·XP·가격 상수 0 — ADR-0034 #4)",
		not src.contains("mult") and not src.contains("_xp") and not src.contains("price"))

	# ── ⑩ main 배선(네 입수 지점) ──
	print("── ⑩ 입수 지점 4곳 ──")
	var msrc := _main_source()
	_check("⑩a 갱도 채굴이 롤을 부른다", msrc.contains("_roll_book_drop(Books.SRC_MINE"))
	_check("⑩b 낚시 포획이 롤을 부른다", msrc.contains("_roll_book_drop(Books.SRC_FISH"))
	_check("⑩c 미혹 채집이 롤을 부른다", msrc.contains("_roll_book_drop(Books.SRC_FORAGE"))
	_check("⑩d 농장 개간이 롤을 부른다", msrc.contains("_roll_book_drop(Books.SRC_DEBRIS"))
	_check("⑩e 미혹 구역 가드가 붙어 있다(저승 숲·해변 줍기는 안 굴린다)",
		msrc.contains("RegionCatalog.MIHOK_FOREST") and msrc.contains("Books.SRC_FORAGE"))

	m.free()
	m2.free()
	m3.free()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# 복원된 원장으로 굴렸을 때 그 id가 다시 뽑히는가(뽑히면 중복 입수 = 실패).
func owned_reroll(bk: Node, id: String) -> bool:
	for i in 1500:
		if bk.pending_drop(Books.SRC_MINE, 5, i) == id:
			return true
	return false
