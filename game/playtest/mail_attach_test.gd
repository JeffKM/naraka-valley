extends SceneTree
# ★[S10-T2 / ADR-0069 결정 3] 우편 첨부(items/gold) — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 첨부 스키마 — 첨부 있는 편지만 items/gold를 내놓고, 나머지 전 행은 빈 첨부다(가법 확장 증명).
#   ② 테이블 무결성 — 모든 첨부 아이템 id가 유효 아이템이고 개수는 양수다(오타가 침묵하지 않는다).
#   ③ 진실원 대조 — 리터럴 "rarecrow_4" == ItemCatalog.RARECROW_4(const 초기화식 관례의 안전망).
#   ④ 지급 — 읽는 순간 백팩에 들어온다(획득처 ④의 실효).
#   ⑤ **기독 원장이 곧 지급 원장** — 재열람·세이브 왕복에서 두 번 나오지 않는다(중복 지급 0).
#   ⑥ 무첨부 편지 불변 — 33통은 읽어도 백팩·지갑이 한 톨도 안 변한다(기존 경로 무손상).
#   ⑦ 자리 없음 방어 — 백팩이 가득이면 **열리지 않고 미독으로 남는다**(첨부가 허공에 사라지지 않는다).
#   ⑧ 해금 경로 비사용 규약 — 첨부 스키마에 물건·냥뿐이다(mailbox.gd:7 · ADR-0064 발견 게이트).
#
# ⚠️ 분모는 Mailbox.LETTERS 전수 순회에서 파생한다(통수 하드코딩 금지 — 편지가 늘면 따라온다).
#
# 실행: TIMEOUT=180 ./run_tests.sh mail_attach   (헤드리스는 반드시 game/에서 · 순차)

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

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

# 신규 시작의 통보 대화를 끝까지 넘겨 닫는다(편지 열람 검증 전에 무대를 비운다 — mailbox_test 결).
func _dismiss_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 80:
		m.dialogue.advance()
		guard += 1

# 백팩을 통째로 비운다(자리 계산이 걸린 단언의 전제를 확정한다).
func _clear_backpack(m: Node) -> void:
	for i in range(m.inventory.slots.size()):
		m.inventory.slots[i] = null
	m.inventory.changed.emit()

# 백팩을 가득 채운다(빈 슬롯 0 — 서로 다른 스택 불가 아이템이 없으므로 각기 다른 재료로 채운다).
func _fill_backpack(m: Node) -> void:
	_clear_backpack(m)
	var fillers := [ItemCatalog.WOOD, ItemCatalog.STONE, ItemCatalog.SAP, ItemCatalog.HAY,
		ItemCatalog.HARDWOOD, ItemCatalog.HONTAN, ItemCatalog.NEOKGARU, ItemCatalog.HONBULSSI,
		ItemCatalog.SOUL_FIBER, ItemCatalog.EMBER_SHARD, ItemCatalog.PETRIFIED_WOOD,
		ItemCatalog.ROTTEN_NET, ItemCatalog.JEOSEUNG_IKKI, ItemCatalog.ORE_MYEONGDONG,
		ItemCatalog.ORE_YUCHEOL, ItemCatalog.ORE_HWANGCHEONGEUM]
	var i := 0
	while i < fillers.size() and m.inventory.add_item(String(fillers[i]), 1):
		i += 1

func _initialize() -> void:
	await _run()

func _run() -> void:
	print("══ S10-T2 우편 첨부(items/gold) 검증 ══")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var attached := "herald_rarecrow"   # 첨부를 가진 유일한 편지(획득처 ④)
	var plain := "herald_notice"        # 첨부 없는 샘플(중립 프레임워크 문구)

	# ── ① 첨부 스키마 ──
	print("── ① 첨부 스키마 ──")
	_check("①a 첨부 편지가 테이블에 있다", Mailbox.has_letter(attached))
	_check("①b has_attachment가 첨부 있는 편지만 참",
		Mailbox.has_attachment(attached) and not Mailbox.has_attachment(plain))
	var att := Mailbox.attachment_items_of(attached)
	_check("①c 첨부 물건 1종 ×1", att.size() == 1 and int(att[0]["n"]) == 1)
	_check("①d 첨부 냥은 0(이 편지는 물건만 — 전령이 값을 안 받는다)",
		Mailbox.attachment_gold_of(attached) == 0)
	_check("①e 없는 id는 빈 첨부(손상 방어)",
		Mailbox.attachment_items_of("__nope__").is_empty()
		and Mailbox.attachment_gold_of("__nope__") == 0
		and not Mailbox.has_attachment("__nope__"))

	# ── ② 테이블 무결성 + ⑥ 무첨부 편지 분모(전수 순회 파생) + ⑧ 규약 ──
	print("── ②⑥⑧ 테이블 전수(무결성·분모·규약) ──")
	var attached_ids: Array = []
	var items_ok := true
	var schema_ok := true
	for id in Mailbox.LETTERS:
		var sid := str(id)
		if Mailbox.has_attachment(sid):
			attached_ids.append(sid)
		for e in Mailbox.attachment_items_of(sid):
			if not ItemCatalog.has_item(String(e["id"])) or int(e["n"]) <= 0:
				items_ok = false
		# ⑧ 첨부 스키마에 물건·냥 말고는 아무것도 없다 — 해금 키가 생기면 여기서 걸린다.
		var row: Dictionary = Mailbox.LETTERS[id]
		for key in row.keys():
			if not (String(key) in ["from", "lines", "note", "items", "gold"]):
				schema_ok = false
	_check("②a 전 첨부 아이템 id가 유효하고 개수가 양수", items_ok)
	_check("⑥a 첨부를 가진 편지는 %d통뿐 — 나머지 %d통은 빈 첨부(가법 확장)"
		% [attached_ids.size(), Mailbox.LETTERS.size() - attached_ids.size()],
		attached_ids.size() == 1 and attached_ids[0] == attached)
	_check("⑧a 편지 스키마 = from·lines·note·items·gold뿐(해금 키 0 — ADR-0064 발견 게이트)", schema_ok)

	# ── ③ 진실원 대조 ──
	print("── ③ 진실원 대조 ──")
	_check("③a 리터럴 첨부 id == ItemCatalog.RARECROW_4",
		String(att[0]["id"]) == ItemCatalog.RARECROW_4)

	# ── main 통합(④⑤⑥⑦) ──
	print("── ④⑤⑥⑦ main 배선(지급·중복 방어·불변·자리 없음) ──")
	var m: Node = await _spawn_main()
	_dismiss_dialogue(m)
	_check("④pre 우편함 원장 준비됨", m.mailbox != null)
	_clear_backpack(m)

	# ⑦ 백팩이 가득이면 열리지 않고 미독으로 남는다(첨부 유실 0).
	m.mailbox.send(attached)
	m.mailbox.advance_day()
	_fill_backpack(m)
	_check("⑦pre 백팩 만석(빈 슬롯 0)", not m.inventory.add_item(ItemCatalog.SPRINKLER, 1))
	m._read_next_letter()
	_check("⑦a 만석 = 대화창 안 열림", not m.dialogue.is_open())
	_check("⑦b 만석 = 미독 유지(다시 와서 받을 수 있다)",
		not m.mailbox.is_read(attached) and m.mailbox.next_unread() == attached)
	_check("⑦c 만석 = 첨부 미지급", m.inventory.count_of(ItemCatalog.RARECROW_4) == 0)

	# ④ 자리를 비우고 읽으면 들어온다.
	_clear_backpack(m)
	m._read_next_letter()
	_dismiss_dialogue(m)
	_check("④a 읽는 순간 첨부 지급(레어크로우 ④ 1개)",
		m.inventory.count_of(ItemCatalog.RARECROW_4) == 1)
	_check("④b 기독 원장 적재", m.mailbox.is_read(attached) and m.mailbox.unread_count() == 0)

	# ⑤ 재열람·세이브 왕복에서 두 번 나오지 않는다.
	m._read_next_letter()
	_dismiss_dialogue(m)
	_check("⑤a 다시 열어도 재지급 없음(mark_read 멱등이 곧 지급 멱등)",
		m.inventory.count_of(ItemCatalog.RARECROW_4) == 1)
	m._save_game()
	m._load_game()
	_dismiss_dialogue(m)
	_check("⑤b 세이브 왕복 후 기독 유지(다시 미독으로 뜨지 않는다)",
		m.mailbox.is_read(attached) and not m.mailbox.has_unread())
	m._read_next_letter()
	_check("⑤c 왕복 뒤에도 재지급 없음", m.inventory.count_of(ItemCatalog.RARECROW_4) == 1)

	# ⑥ 무첨부 편지는 읽어도 백팩·지갑 불변.
	_dismiss_dialogue(m)
	var gold_before: int = m.wallet.gold
	var slots_before := 0
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) != "":
			slots_before += 1
	m.mailbox.send(plain)
	m.mailbox.advance_day()
	m._read_next_letter()
	_check("⑥b 무첨부 편지도 정상 열람(대화창 열림)", m.dialogue.is_open())
	_dismiss_dialogue(m)
	var slots_after := 0
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) != "":
			slots_after += 1
	_check("⑥c 무첨부 편지 = 백팩·지갑 불변",
		slots_after == slots_before and m.wallet.gold == gold_before)
	_check("⑥d 그래도 기독 처리는 된다(기존 경로 무손상)", m.mailbox.is_read(plain))

	await _despawn(m)

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(1 if _fail > 0 else 0)
