extends SceneTree
# ★[S9-T3 / ADR-0067 결정 7] 편지(저승식 전령) 채널 — 헤드리스 검증.
#
# 무엇을 보증하나:
#   ① 발송 큐 — 보낸 날엔 안 오고 **다음 날 아침**에 도착한다(advance_day 한 번 = 한 아침).
#   ② 열람 = 기독 — 읽으면 원장에 오르고, 보관함에는 그대로 남는다(재열람의 토대).
#   ③ 미독 카운트·시각 신호 술어 — has_unread가 곧 우편함 깃발의 조건이다.
#   ④ 세이브 왕복 — 큐 중이던 편지도, 기독 원장도 이어하기에 살아남는다.
#   ⑤ 구세이브 하위호환 — "mailbox" 키 없는 세이브는 **빈 우편함**으로 조용히 시작(마이그레이션 0).
#   ⑥ 중복 발송 방어 — 같은 id는 큐 중·도착·기독 어느 상태에서도 두 번 오지 않는다(멱등).
#   ⑦ 샘플 데이터 유효성 — 테이블의 모든 행이 발신인·본문을 갖추었다(빈 대화창 차단).
#   ⑧ main 배선 — 우편함 칸 판정(구역·실내 가드)·[F] 열람 경로·프롬프트·day 훅 도착.
#
# 실행: TIMEOUT=180 ./run_tests.sh mailbox   (헤드리스는 반드시 game/에서 · 순차)

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

# 신규 시작의 옥자 통보 대화를 끝까지 넘겨 닫는다(편지 대화창 검증 전에 무대를 비운다).
func _dismiss_intro(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 50:
		m.dialogue.advance()
		guard += 1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S9-T3 편지 채널(mailbox.gd) 검증 ══")
	const SAVE := "user://save.dat"
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var sample := "herald_notice"   # T3 샘플 1통(중립 프레임워크 문구)

	# ── ⑦ 데이터 테이블 유효성(다른 검증의 전제라 맨 앞) ──
	print("── ⑦ 편지 테이블 유효성 ──")
	_check("⑦a 샘플 1통이 테이블에 있다", Mailbox.has_letter(sample))
	_check("⑦b 없는 id는 조회도 빈값",
		not Mailbox.has_letter("__nope__") and Mailbox.sender_of("__nope__") == ""
		and Mailbox.lines_of("__nope__").is_empty())
	var table_ok := true
	for id in Mailbox.LETTERS:
		var row: Dictionary = Mailbox.LETTERS[id]
		if Mailbox.sender_of(str(id)) == "" or Mailbox.lines_of(str(id)).is_empty() \
				or not row.has("note"):
			table_ok = false
		for ln in Mailbox.lines_of(str(id)):
			if ln.strip_edges() == "":
				table_ok = false
	_check("⑦c 전 행이 발신인·본문·트리거 메모를 갖췄다(빈 줄 0)", table_ok)

	# ── ① 발송 큐 → 다음 날 아침 도착 ──
	print("── ① 발송 큐·익일 도착 ──")
	var mb := Mailbox.new()
	_check("①a 처음엔 큐·보관함·미독 전부 0",
		mb.pending_count() == 0 and mb.inbox.is_empty() and mb.unread_count() == 0
		and not mb.has_unread() and mb.next_unread() == "")
	_check("①b 테이블에 없는 id는 발송 거절", not mb.send("__nope__") and mb.pending_count() == 0)
	_check("①c 발송 = 큐에만 든다", mb.send(sample) and mb.pending_count() == 1)
	_check("①d 같은 날엔 도착하지 않는다(보관함 빔·미독 0·열 것 없음)",
		mb.inbox.is_empty() and mb.unread_count() == 0 and mb.next_unread() == "")
	var arrived := mb.advance_day()
	_check("①e 다음 날 아침 도착 = 도착분 id를 돌려준다",
		arrived.size() == 1 and arrived[0] == sample)
	_check("①f 도착 후 큐는 비고 보관함에 든다",
		mb.pending_count() == 0 and mb.inbox.size() == 1 and mb.inbox[0] == sample)
	_check("①g 도착분은 미독이다", mb.unread_count() == 1 and mb.next_unread() == sample)
	_check("①h 무소식 아침은 빈 배열(중복 도착 없음)",
		mb.advance_day().is_empty() and mb.inbox.size() == 1)

	# ── ③ 미독 카운트·시각 신호 술어 ──
	print("── ③ 미독 술어 ──")
	_check("③a 미독이 있으면 깃발 조건 성립", mb.has_unread() and mb.unread_count() == 1)

	# ── ② 열람 = 기독 ──
	print("── ② 열람·기독 ──")
	_check("②a 미지 id 열람 거절", not mb.mark_read("__nope__"))
	_check("②b 열람 = 기독 원장 적재", mb.mark_read(sample) and mb.is_read(sample))
	_check("②c 기독 후 미독 0·깃발 접힘·열 것 없음",
		mb.unread_count() == 0 and not mb.has_unread() and mb.next_unread() == "")
	_check("②d 읽은 편지도 보관함에 남는다(재열람의 토대)",
		mb.inbox.size() == 1 and mb.inbox[0] == sample)
	_check("②e 재열람 처리는 멱등(원장 중복 없음)",
		not mb.mark_read(sample) and mb.read_ledger.size() == 1)

	# ── ⑥ 중복 발송 방어(세 상태 전부) ──
	print("── ⑥ 중복 발송 방어 ──")
	_check("⑥a 기독 상태에서 재발송 거절", not mb.send(sample) and mb.pending_count() == 0)
	var mb2 := Mailbox.new()
	mb2.send(sample)
	_check("⑥b 큐 중 재발송 거절(큐가 안 불어난다)",
		not mb2.send(sample) and mb2.pending_count() == 1)
	mb2.advance_day()
	_check("⑥c 도착·미독 상태에서 재발송 거절",
		not mb2.send(sample) and mb2.inbox.size() == 1)
	_check("⑥d ever_sent = 큐·보관함 둘 다 본다",
		mb2.ever_sent(sample) and not mb2.ever_sent("__nope__"))
	mb2.free()

	# ── ③b 순차 열람 순서(FIFO) — 화이트박스 ──
	# 테이블에 편지가 한 통뿐이라 공개 API(send)로는 두 통을 만들 수 없다(T3 스코프 = 샘플 1통).
	# 그래서 보관함 배열을 직접 세워 "오래된 것부터"만 확인한다 — T4~T6이 행을 더하면 이 검증은
	# 자연히 공개 API로 승격된다.
	print("── ③b 순차 열람(FIFO) ──")
	var mb3 := Mailbox.new()
	mb3.inbox = PackedStringArray(["old", "mid", "new"])
	_check("③b1 가장 오래된 것부터 열린다", mb3.next_unread() == "old")
	mb3.mark_read("old")
	_check("③b2 읽으면 다음 것이 선다", mb3.next_unread() == "mid" and mb3.unread_count() == 2)
	mb3.mark_read("mid")
	mb3.mark_read("new")
	_check("③b3 전부 읽으면 깃발이 접힌다", not mb3.has_unread() and mb3.next_unread() == "")
	mb3.free()

	# ── 손상 방어(load_save 정제) ──
	print("── ⑤a load_save 정제 ──")
	var mb4 := Mailbox.new()
	mb4.load_save({"outbox": [sample, sample, "__nope__"], "inbox": [sample, 42],
		"read": {"__nope__": true}})
	_check("⑤a1 중복·미지 id는 걸러진다(큐 1통)",
		mb4.pending_count() == 1 and mb4.outbox[0] == sample)
	_check("⑤a2 큐가 이미 든 id는 보관함에 겹쳐 들지 않는다", mb4.inbox.is_empty())
	_check("⑤a3 보관함에 없는 기독 기록은 버린다", mb4.read_ledger.is_empty())
	mb4.load_save({"outbox": "쓰레기", "inbox": 7, "read": "형식오류"})
	_check("⑤a4 형식 손상 = 빈 우편함(예외 없이)",
		mb4.pending_count() == 0 and mb4.inbox.is_empty() and mb4.read_ledger.is_empty())
	mb4.free()
	mb.free()

	# ── ⑧ main 배선 ──
	print("── ⑧ main 배선 ──")
	var m: Node = await _spawn_main()
	_dismiss_intro(m)
	_check("⑧a 우편함 노드가 붙어 있다", m.mailbox != null)
	# 칸 판정 — 구역·실내·대상 칸 3중 가드.
	m._sleeping = false
	m._region = RegionCatalog.HOME
	m._indoor = ""
	m._target = m.MAILBOX_TILE
	var faced: bool = m._facing_mailbox()
	_check("⑧b 안식 야외에서 우편함 칸을 보면 창구가 선다", faced)
	m._indoor = "집"
	var faced_indoor: bool = m._facing_mailbox()
	m._indoor = ""
	_check("⑧c 실내에선 같은 좌표라도 무반응", not faced_indoor)
	m._region = RegionCatalog.NARU_VILLAGE
	var faced_village: bool = m._facing_mailbox()
	m._region = RegionCatalog.HOME
	_check("⑧d 다른 구역의 같은 좌표도 무반응", not faced_village)
	m._target = m.MAILBOX_TILE + Vector2i(3, 0)
	var faced_off: bool = m._facing_mailbox()
	m._target = m.MAILBOX_TILE
	_check("⑧e 다른 칸을 보면 무반응", not faced_off)
	# 빈 우편함에서 [F] = 대화창이 열리지 않는다(빈 대화창 차단).
	m._read_next_letter()
	_check("⑧f 읽을 것이 없으면 대화창을 안 연다", not m.dialogue.is_open())
	# day 훅 — 보낸 편지가 다음 아침에 도착한다.
	_check("⑧g 공용 발송 창구 한 줄", m.mailbox.send(sample) and m.mailbox.pending_count() == 1)
	_check("⑧h 보낸 그 날엔 우편함이 비어 있다", not m.mailbox.has_unread())
	m._on_day_advanced(m.clock.day + 1)
	_check("⑧i day 훅이 도착을 굴린다(미독 1)",
		m.mailbox.unread_count() == 1 and m.mailbox.next_unread() == sample)
	# [F] 열람 — 대화창에 발신인이 화자로 서고 기독 처리된다.
	m._read_next_letter()
	_check("⑧j 열람 = 대화창(발신인이 화자·본문 첫 줄)",
		m.dialogue.is_open() and m.dialogue.speaker() == Mailbox.sender_of(sample)
		and m.dialogue.line() == Mailbox.lines_of(sample)[0])
	_check("⑧k 읽는 동안 이동 잠금", not m.player.is_physics_processing())
	_check("⑧l 여는 순간 기독(중간에 닫아도 배지가 남지 않는다)",
		m.mailbox.is_read(sample) and not m.mailbox.has_unread())
	var guard := 0
	while m.dialogue.is_open() and guard < 20:
		m.dialogue.advance()
		guard += 1
	_check("⑧m 끝까지 넘기면 닫히고 이동 잠금 해제",
		not m.dialogue.is_open() and m.player.is_physics_processing())

	# ── ④ 세이브 왕복 ──
	print("── ④ 세이브 왕복 ──")
	# ④-A 큐 중이던 편지(아직 안 온 편지)가 살아남는가 — 새 우편함에 다른 편지를 큐에 넣어 저장.
	var m_queue: Node = await _spawn_main()
	m_queue.mailbox.outbox = PackedStringArray([sample])
	m_queue.mailbox.inbox = PackedStringArray()
	m_queue.mailbox.read_ledger = {}
	m_queue._save_game()
	var m2: Node = await _spawn_main()   # _ready가 자동 로드
	_check("④a 큐 중이던 편지가 이어하기에 살아 있다(자면 사라지는 예고 0)",
		m2.mailbox.pending_count() == 1 and m2.mailbox.inbox.is_empty())
	_check("④b 큐 중이라 아직 미독도 아니다", m2.mailbox.unread_count() == 0)
	# ④-B 도착·기독 원장 왕복.
	m2.mailbox.advance_day()
	m2.mailbox.mark_read(sample)
	m2._save_game()
	var m3: Node = await _spawn_main()
	_check("④c 보관함·기독 원장 복원",
		m3.mailbox.inbox.size() == 1 and m3.mailbox.is_read(sample)
		and m3.mailbox.unread_count() == 0)
	_check("④d 복원 후 재발송도 여전히 거절(원장이 살아 있다는 증거)",
		not m3.mailbox.send(sample))

	# ── ⑤ 구세이브 하위호환("mailbox" 키 없음) ──
	print("── ⑤ 구세이브 하위호환 ──")
	var payload: Dictionary = m3.saver.load_game(m3._active_slot)
	_check("⑤b 세이브에 mailbox 조각이 실제로 있다(다음 단언의 전제)", payload.has("mailbox"))
	payload.erase("mailbox")
	m3.saver.save_game(payload, m3._active_slot, {})
	var m4: Node = await _spawn_main()
	_check("⑤c 키 없는 구세이브 = 빈 우편함으로 조용히 시작",
		m4.mailbox != null and m4.mailbox.pending_count() == 0
		and m4.mailbox.inbox.is_empty() and m4.mailbox.unread_count() == 0)
	_check("⑤d 빈 우편함이라도 발송은 정상 동작(막히는 것 0)", m4.mailbox.send(sample))

	m.free()
	m_queue.free()
	m2.free()
	m3.free()
	m4.free()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)
