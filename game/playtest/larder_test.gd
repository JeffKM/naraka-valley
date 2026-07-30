extends SceneTree
# ★[S6-T1 / ADR-0064 결정 3] larder.gd 단위검증 — 카페 곳간(융합 메뉴 재료 재고).
# 실행: godot --headless --path game --script res://playtest/larder_test.gd
#
# 검증 축:
#   ① 적재/회수 기본 계약(add·take_back·count_of·ids·total)
#   ② 용량 30 상한 + 부분 적재(코지 — "다 안 들어가면 하나도 안 넣는다"가 아님)
#   ③ 품질 무차원(출하함의 등급 중첩과 갈리는 지점)
#   ④ 손상 방어(미등록 id·0·음수)
#   ⑤ 세이브 왕복 + 하위호환(키 없음 = 빈 곳간) + 손상 세이브 정제
#   ⑥ changed 시그널(패널 갱신의 유일한 계기)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_larder() -> Larder:
	return Larder.new()   # 트리에 안 붙인다(순수 상태 노드 — _ready 의존 없음)

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

func _initialize() -> void:
	print("══ S6-T1 larder.gd 단위검증 ══")

	var pian := CropCatalog.PIANHWA
	var hobak := CropCatalog.YEONGHON_HOBAK

	# ① 적재/회수 기본 계약.
	var l := _new_larder()
	_check("① 새 곳간은 비어 있음", l.is_empty() and l.total() == 0)
	_check("①b add는 실제 적재 수를 돌려줌", l.add(pian, 3) == 3)
	_check("①c count_of 반영", l.count_of(pian) == 3 and l.total() == 3)
	_check("①d 같은 id 합산", l.add(pian, 2) == 2 and l.count_of(pian) == 5)
	_check("①e 다른 id는 따로", l.add(hobak, 1) == 1 and l.ids().size() == 2 and l.total() == 6)
	_check("①f has_stock", l.has_stock(pian) and not l.has_stock(ItemCatalog.HAY))
	_check("①g take_back은 실제 회수 수를 돌려줌", l.take_back(pian, 2) == 2 and l.count_of(pian) == 3)
	_check("①h 보유보다 많이 회수 = 있는 만큼만", l.take_back(pian, 99) == 3)
	_check("①i 0이 된 id는 키에서 사라짐(빈 항목 X)",
		not l.stock.has(pian) and l.ids().size() == 1)
	_check("①j 없는 id 회수 = 0", l.take_back("nothing_here", 1) == 0)

	# ② 용량 상한 + 부분 적재. CAPACITY는 잠정 레버라 값 자체도 못 박는다(2단 확장 시 여기가 운다).
	_check("② 용량 상수 = 30(ADR-0064 잠정)", Larder.CAPACITY == 30)
	var c := _new_larder()
	_check("②b free_space 초기값 = 용량", c.free_space() == Larder.CAPACITY)
	c.add(pian, 28)
	_check("②c 28개 적재 → 남은 자리 2", c.free_space() == 2 and not c.is_full())
	_check("②d 초과 적재는 **들어갈 만큼만**(부분 적재)", c.add(hobak, 5) == 2)
	_check("②e 상한에서 멈춤", c.total() == Larder.CAPACITY and c.is_full())
	_check("②f 가득 찬 뒤 추가 적재 = 0", c.add(pian, 1) == 0)
	_check("②g 회수하면 자리가 다시 남", c.take_back(pian, 3) == 3 and c.free_space() == 3)

	# ③ 품질 무차원 — add가 등급 인자를 아예 안 받는다(계약이 곧 설계). 같은 id는 한 칸에 쌓인다.
	#    (출하함은 {id:{quality:count}} 중첩이라 은/금이 갈라 쌓인다 — 곳간은 그 축이 없다.)
	var q := _new_larder()
	q.add(pian, 1)
	q.add(pian, 1)
	_check("③ 등급 축 없이 한 칸에 합산", q.count_of(pian) == 2 and q.stock[pian] == 2)
	_check("③b 재고 dict가 평 dict(중첩 아님)", typeof(q.stock[pian]) == TYPE_INT)

	# ④ 손상 방어.
	var d := _new_larder()
	_check("④ 미등록 id 거절", d.add("존재하지_않는_아이템", 5) == 0 and d.is_empty())
	_check("④b n<=0 거절", d.add(pian, 0) == 0 and d.add(pian, -3) == 0 and d.is_empty())
	_check("④c take_back n<=0 = 0", d.take_back(pian, 0) == 0)

	# ⑤ 세이브 왕복.
	var s := _new_larder()
	s.add(pian, 4)
	s.add(hobak, 2)
	var blob := s.to_save()
	var r := _new_larder()
	r.load_save(blob)
	_check("⑤ 세이브 왕복(종·개수 보존)",
		r.count_of(pian) == 4 and r.count_of(hobak) == 2 and r.total() == 6)
	s.add(pian, 1)   # 세이브를 뜬 뒤 원본을 건드려도 스냅샷은 안 흔들려야 한다.
	_check("⑤b to_save는 깊은 복사(원본과 분리)", int(blob["stock"][pian]) == 4)
	# 하위호환: 키 자체가 없는 구버전 세이브 = main이 load_save를 안 부른다 → 빈 곳간.
	var old := _new_larder()
	old.load_save({})
	_check("⑤c 빈 데이터 로드 = 빈 곳간(하위호환)", old.is_empty())
	# 손상 세이브 정제(미등록 id·음수·타입 오류·용량 초과).
	var broken := _new_larder()
	broken.load_save({"stock": {pian: 3, "쓰레기_id": 9, hobak: -2}})
	_check("⑤d 손상 세이브 정제(유효 항목만 남김)",
		broken.count_of(pian) == 3 and broken.total() == 3)
	var over := _new_larder()
	over.load_save({"stock": {pian: 999}})
	_check("⑤e 용량 초과 세이브도 상한이 선다", over.total() == Larder.CAPACITY)
	var junk := _new_larder()
	junk.load_save({"stock": "이건 dict가 아님"})
	_check("⑤f dict 아닌 stock = 빈 곳간", junk.is_empty())

	# ⑥ changed 시그널 — 곳간 패널·프롬프트가 다시 그려지는 유일한 계기.
	var sig := _new_larder()
	var hits := {"n": 0}
	sig.changed.connect(func(): hits["n"] += 1)
	sig.add(pian, 1)
	_check("⑥ 적재 시 changed 발화", hits["n"] == 1)
	sig.take_back(pian, 1)
	_check("⑥b 회수 시 changed 발화", hits["n"] == 2)
	sig.add("존재하지_않는_아이템", 1)
	_check("⑥c 거절된 적재는 안 쏨(헛 리드로 0)", hits["n"] == 2)
	sig.load_save({"stock": {pian: 1}})
	_check("⑥d 로드 시 changed 발화(복원 직후 패널 정합)", hits["n"] == 3)

	# ⑦ 곳간 ↔ 메뉴 결속 — 쟁인 재료가 실제로 어떤 융합 메뉴로 이어지는지(T2 차감의 전제).
	var m := _new_larder()
	m.add(pian, 1)
	var menu_id := MenuCatalog.menu_for_signature(m.ids()[0])
	_check("⑦ 적재한 재료 → 융합 메뉴 역참조",
		menu_id == MenuCatalog.PIANHWA_ADE and MenuCatalog.price_of(menu_id) > Cafe.BASE_PRICE)

	for n in [l, c, q, d, s, r, old, broken, over, junk, sig, m]:
		n.free()

	# ⑧ main 배선 — 노드 생성·프레임 주입·적재/회수 핸들러·세이브 왕복(chest_test 하네스 동형).
	#    곳간은 main 안에서만 살아 단독 노드로는 검증 못 하는 층이 있다(프레임 컨텍스트·경제 0·세이브).
	print("── ⑧ main 배선(main.tscn 라이브) ──")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var mn: Node = await _spawn_main()
	_check("⑧ larder 노드 생성·프레임에 주입", mn.larder != null and mn.frame.larder == mn.larder)
	_check("⑧b 곳간 칸이 출하함 칸과 갈린다(같은 방 반대쪽 끝)",
		mn.LARDER_TILE != mn.SHIP_BIN_TILE)
	# 적재: 백팩 수확물 슬롯 → 곳간. **경제 0**(출하함과 달리 지금 골드가 안 들어온다).
	var hid := ItemCatalog.harvest_id(CropCatalog.PIANHWA)
	mn.inventory.add_harvest(CropCatalog.PIANHWA, 3, 0)
	var slot := -1
	for i in Inventory.SIZE:
		if mn.inventory.id_at(i) == hid:
			slot = i
			break
	_check("⑧pre 백팩에 수확물 슬롯 있음", slot >= 0)
	var gold_before: int = mn.wallet.gold
	mn._on_frame_larder_store(slot)
	_check("⑧c 적재 후 백팩에서 사라짐", mn.inventory.id_at(slot) == "")
	_check("⑧d 적재 후 곳간에 들어감", mn.larder.count_of(hid) == 3)
	_check("⑧e 지갑 불변(적재는 판매가 아니다)", mn.wallet.gold == gold_before)
	# 수확물이 아닌 슬롯(도구·씨앗)은 적재 대상이 아니다 — 출하함 드롭과 같은 제한.
	var tool_slot := -1
	for i in Inventory.SIZE:
		if mn.inventory.id_at(i) == ItemCatalog.HOE:
			tool_slot = i
			break
	if tool_slot >= 0:
		mn._on_frame_larder_store(tool_slot)
		_check("⑧f 도구는 적재 거절(수확물만 — 출하함 드롭과 같은 제한)",
			mn.inventory.id_at(tool_slot) == ItemCatalog.HOE and not mn.larder.has_stock(ItemCatalog.HOE))
	# 회수: 곳간 → 백팩.
	mn._on_frame_larder_take(hid)
	_check("⑧g 회수 후 곳간에서 사라짐", mn.larder.count_of(hid) == 0)
	_check("⑧h 회수 후 백팩 복귀", mn.inventory.count_of(hid) == 3)
	_check("⑧i 회수도 지갑 불변", mn.wallet.gold == gold_before)
	# 세이브 왕복 — main 세이브에 "larder" 조각으로 실린다.
	mn.larder.add(hid, 5)
	mn._save_game()
	var mn2: Node = await _spawn_main()
	_check("⑧j 이어하기에 곳간 재고 복원(5)", mn2.larder.count_of(hid) == 5)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
