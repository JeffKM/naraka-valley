extends SceneTree
# ★[폴리시 16회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#7).
#
# 렌즈: R15 diff 리뷰 · 이벤트 재진입 · 단위/스케일 정합.
#
# 이 회차의 태도: **표시(display) 항목은 반드시 그리기 경로를 태운다.** R16 #0이 폭로한 함정이
# 정확히 그것이다 — R15 ㉑a~㉑e는 `store_bulk` 값·`kind_takes_bulk`·라이브 Shift 구매만 재고
# 헤더를 한 번도 안 그려 봐서, 새로 붙인 안내가 `elide`에 통째로 잘려 나가는 것을 못 잡았다.
# 그래서 아래 ①은 문자열이 아니라 **배치 계산(store_header_layout)**을 재고, ②는 실제로 모드를
# 켜서 알림 큐에 들어간 줄을 재며, ③은 배너가 만드는 판 기하를 전 단계·양 갈래로 다시 계산한다.
#
# 무엇을 보증하나(번호 = 16회차 헌트 발견 인덱스):
#   ① #0 Shift 대량 구매 안내가 **네 매대 전부에서 한 글자도 안 뜨고** 있었다(꼬리 잇기 → elide).
#        덤으로 만물상 ♡1 헤더가 13px→10px로 깎인 뒤 그마저 말줄임됐다.
#   ② #1 꾸미기 안내 한 줄이 819px이라 「,」「.」 아이템·[R] 회전이 화면 밖(640px)으로 나갔다.
#   ③ #2 MEET_MIHO 출근 갈래 배너 판(675px)이 뷰포트보다 넓어 양끝이 잘렸다.
#   ④ #3 제작 실패 알림의 "[Tab] 가방에서"가 **이미 가방을 연 상태**에서 떴다(그 Tab은 닫는다).
#   ⑤ #4 에필로그 […돌아간다] 닫기가 `_swallow_input_once`를 안 세워 같은 프레임 LMB가 월드로 샜다.
#   ⑥ #5 짐승 칸에 놓인 화분이 RMB 한 번에 `_try_harvest()`를 두 번 돌려 혼력을 이중 차감했다.
#   ⑦ #6 위장 잡귀의 '바위'가 진짜 바위보다 정확히 3.2px 위에 그려져 위장이 눈으로 들켰다.
#   ⑧ #7 **OWNER-DECISION 기록** — 몹의 판정 타일(pos=중심)과 몸 발치(pos+TILE*0.40)가 갈리는
#        사실을 수치로 남긴다. 코드는 안 고쳤다(아래 판정 주석).
#
# 판정: #0~#6 CONFIRMED(봉합). **#7은 OWNER-DECISION** — 어느 축을 옮겨도 대가가 있다:
#   ㉠ 판정을 발치로 옮기면 R10 #3이 깨진다. 추적형은 접촉 시 정지가 없어 플레이어 **픽셀 좌표로
#      수렴**하고, 그때 `m.tile() == _player_tile()`이 되는 것이 "겹친 적을 벤다"의 성립 근거다
#      (`_weapon_arc`가 origin을 arc 맨 앞에 담는 이유). 발치 타일은 그 등식을 한 행 깬다.
#   ㉡ 렌더를 올려 발치를 pos에 맞추면 **전 몹이 12.8px 뜨고**(화면상 25.6px) 32px 몹이 제 칸
#      위쪽 절반에 걸쳐 뜬 스티커로 읽힌다 — S5-T10이 "발치선은 한 픽셀도 안 바뀐다"고 못 박은 축이다.
#   ㉢ 판정을 몸 rect 겹침으로 바꾸면 히트박스가 커져 전투 밸런스가 바뀐다.
#   셋 다 폴리시 회차가 단독으로 정할 자리가 아니다(전투 감·아트 규약 결정). ⑧이 사실만 기록한다.
#
# 하중 검증(계약을 일부러 깨고 빨개지는지 본 뒤 원복):
#   #0 안내를 다시 마지막 줄 꼬리에 잇기 → ①b·①d red · #1 두 push를 옛 한 줄로 되돌림 → ②b red ·
#   #2 옛 출근 문구 복귀 → ③a red · #3 "[Tab] " 되돌림 → ④a red · #4 `_swallow_input_once = true`
#   삭제 → ⑤a red · #5 `_pot_dispatch_at`의 `and not _animal_dispatch_at(t)` 삭제 → ⑥b red ·
#   #6 위장 분기를 옛 `m.pos − (rsz.x*0.5, rsz.y − TILE*0.40)` 식으로 되돌림 → ⑦c red.
#
# 실행: ./run_tests.sh polish_r16   (헤드리스는 반드시 game/에서 · 순차)

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

# ── 소스 스캔 헬퍼(polish_r7~r15의 그 관례) ─────────────────────────────────
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

# 그 함수 몸통에서 니들이 처음 나오는 **코드** 줄(주석 줄은 건너뛴다 · 없으면 −1).
func _line_in_func(lines: PackedStringArray, fn_needle: String, needle: String) -> int:
	var head := -1
	for i in range(lines.size()):
		if lines[i].begins_with(fn_needle):
			head = i
			break
	if head < 0:
		return -1
	for i in range(head + 1, lines.size()):
		if lines[i].begins_with("func "):
			return -1
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			return i
	return -1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R16 회귀 — 배치 A(#0~#7) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_check("무대 전제: main.gd를 읽었다(부정 단언이 공허 통과하지 않게)", _src.size() > 1000)

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)

	_check_store_header(m)
	_check_deco_notice(m)
	_check_onboarding_plate(m)
	_check_craft_notice(m)
	_check_epilogue_swallow(m)
	_check_animal_pot_dispatch(m)
	_check_disguise_rock(m)
	_record_mob_foot_axis(m)

	print("── 결과: %s (실패 %d) ──" % ["통과" if _fail == 0 else "실패", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 매대 헤더 — Shift 안내가 네 매대 전부에서 온전히 그려진다 ──────────
# 재는 것은 문자열이 아니라 **그리기가 실제로 쓰는 배치**다: `_draw_store_header`는
# `store_header_layout`이 돌려준 원소를 그대로 `HanjiUi.draw_text_fit`에 넘기므로,
# 각 원소가 "줄지도 잘리지도 않는가"를 여기서 그 함수와 같은 식으로 판정하면 곧 화면 결과다.
func _check_store_header(m: Node) -> void:
	print("① #0 매대 헤더 Shift 안내(그리기 경로)")
	var frame = m.frame
	var keep_ctx: int = frame.context
	var keep_text: String = frame.store_text
	var keep_bulk: int = frame.store_bulk

	# 무대 재현 — 옛 "마지막 줄 꼬리에 잇기"가 실제로 안내를 통째로 지웠다(만물상 ♡0 실측).
	var old_tail := "   ·   Shift+클릭 = 한 번에 %d개 (낱개 품목)" % m.STORE_BULK
	var old_line: String = String(m._store_text().split("\n")[1]) + old_tail
	var old_max: float = frame._panel_rect().size.x - frame.PAD * 2.0
	var old_size := 13
	while old_size > 10 and HanjiUi.text_width(old_line, old_size) > old_max:
		old_size -= 1
	var old_drawn := HanjiUi.elide(old_line, old_size, old_max)
	_check("①a 무대: 옛 꼬리 잇기는 %.0fpx > 가용 %.0fpx라 안내가 elide로 소멸했다(그려진 꼬리 = 「%s」)"
			% [HanjiUi.text_width(old_line, old_size), old_max, old_drawn.right(6)],
		not old_drawn.contains("Shift"))

	# 네 매대 — store_text·store_bulk는 main에서 파생한다(테스트가 문자열을 베끼지 않는다).
	var stores := [
		["만물상", frame.CTX_STORE, m._store_text()],
		["생선가게", frame.CTX_FISHSHOP, m._fishshop_text()],
		["목공방", frame.CTX_WOODSHOP, m._woodshop_text()],
		["길드", frame.CTX_GUILD, m._guild_text()],
	]
	var all_intact := true
	var all_said := true
	var report: Array = []
	for s in stores:
		frame.context = int(s[1])
		frame.store_text = String(s[2])
		frame.store_bulk = m.STORE_BULK
		var hint: Dictionary = _hint_element(frame)
		if hint.is_empty():
			all_intact = false
			all_said = false
			report.append("%s=없음" % String(s[0]))
			continue
		var t := String(hint["text"])
		var sz := int(hint["size"])
		var mw := float(hint["max_w"])
		# draw_text_fit이 하는 일 그대로: 줄일 필요가 없고(폭 ≤ max_w) 잘릴 것도 없다(elide 항등).
		var intact := HanjiUi.text_width(t, sz) <= mw and HanjiUi.elide(t, sz, mw) == t
		if not intact:
			all_intact = false
		if not (t.contains(str(m.STORE_BULK)) and t.contains("낱개") and t.contains("Shift")):
			all_said = false
		report.append("%s=%.0f/%.0f" % [String(s[0]), HanjiUi.text_width(t, sz), mw])
	_check("①b 네 매대 전부 안내가 줄지도 잘리지도 않는다(폭/가용: %s)" % ", ".join(report), all_intact)
	_check("①c 안내가 값과 범위를 함께 말한다(Shift · %d · 낱개 — 1회성 행엔 거짓이 안 되게)"
			% m.STORE_BULK, all_said)

	# 이웃 줄이 아무리 길어져도 안내 슬롯은 안 흔들린다 = "예약 슬롯"의 계약.
	frame.context = frame.CTX_STORE
	frame.store_bulk = m.STORE_BULK
	frame.store_text = m._store_text()
	var slot_a: Dictionary = _hint_element(frame)
	var keep_gold: int = m.wallet.gold
	m.wallet.gold = 999999999
	frame.store_text = m._store_text()
	var slot_b: Dictionary = _hint_element(frame)
	m.wallet.gold = keep_gold
	_check("①d 이웃 줄이 길어져도 안내 자리·폭이 그대로다(x %.0f→%.0f · max_w %.0f→%.0f)"
			% [float(slot_a.get("x", -1.0)), float(slot_b.get("x", -2.0)),
				float(slot_a.get("max_w", -1.0)), float(slot_b.get("max_w", -2.0))],
		not slot_a.is_empty() and not slot_b.is_empty()
			and is_equal_approx(float(slot_a["x"]), float(slot_b["x"]))
			and is_equal_approx(float(slot_a["max_w"]), float(slot_b["max_w"])))

	# 낱개 행이 하나도 없는 매대(store_bulk=0)엔 안내 자체가 없다 — #18류의 거짓 광고 방지.
	frame.store_bulk = 0
	_check("①e 낱개 품목이 없는 매대(store_bulk=0)엔 안내 원소가 아예 없다",
		_hint_element(frame).is_empty() and frame.store_bulk_hint() == "")

	# 본문 줄도 회귀 없이 산다 — 만물상 ♡0은 두 줄 다 온전해야 한다(안내가 자리를 뺏지 않았다).
	frame.store_bulk = m.STORE_BULK
	frame.store_text = m._store_text()
	var body_ok := true
	var body_report: Array = []
	for e in frame.store_header_layout(frame._panel_rect(), frame.store_header_pad()):
		if bool(e["hint"]):
			continue
		var bt := String(e["text"])
		var bs := _fit_size(bt, int(e["size"]), float(e["max_w"]))
		body_report.append("%dpx %.0f/%.0f" % [bs, HanjiUi.text_width(bt, bs), float(e["max_w"])])
		if HanjiUi.elide(bt, bs, float(e["max_w"])) != bt:
			body_ok = false
	_check("①f 만물상 ♡0 본문 두 줄이 말줄임 없이 온전히 그려진다(축소는 draw_text_fit 규약: %s)"
			% ", ".join(body_report), body_ok)

	# 서브탭 폭 양보는 **제목 줄에만**(판이 세로로 겹치는 줄이 거기뿐이다).
	frame.context = frame.CTX_FISHSHOP
	frame.store_text = m._fishshop_text()
	var fs: Array = frame.store_header_layout(frame._panel_rect(), frame.store_header_pad())
	var full: float = frame._panel_rect().size.x - frame.PAD * 2.0
	var head_limit := -1.0
	var tail_limit := -1.0
	for e in fs:
		if bool(e["hint"]):
			continue
		if head_limit < 0.0:
			head_limit = float(e["max_w"])
		else:
			tail_limit = float(e["max_w"])
	var fs_hint: Dictionary = _hint_element(frame)
	var fs_reserve: float = (float(fs_hint["max_w"]) + frame.STORE_HINT_GAP) if not fs_hint.is_empty() else 0.0
	_check("①g 서브탭 양보(%.0f)는 제목 줄만 먹는다 — 제목 %.0f = 판폭−양보 · 둘째 줄 %.0f ="
			% [frame.store_header_pad(), head_limit, tail_limit]
			+ " 판폭(%.0f)−안내슬롯(%.0f)이라 양보가 안 실린다" % [full, fs_reserve],
		is_equal_approx(head_limit, full - frame.store_header_pad())
			and is_equal_approx(tail_limit, full - fs_reserve)
			and frame.store_header_pad() > 0.0)

	# 그리기 경로가 배치와 갈리지 않는다(옛 함정: 그리기 쪽이 자기 문자열을 따로 합성했다).
	var iv := _lines_of_file("res://inv_frame.gd")
	var uses := _line_in_func(iv, "func _draw_store_header", "store_header_layout(")
	var recompose := _line_in_func(iv, "func _draw_store_header", "store_bulk")
	_check("①h 그리기(%d행)가 배치 함수 하나만 쓰고 문구를 따로 합성하지 않는다"
			% (uses + 1), uses >= 0 and recompose < 0)

	frame.context = keep_ctx
	frame.store_text = keep_text
	frame.store_bulk = keep_bulk

# `HanjiUi.draw_text_fit`의 축소 루프 그대로 — 그 폭에서 실제로 쓰이는 글자 크기.
func _fit_size(text: String, size: int, max_w: float, min_size := 10) -> int:
	var s := size
	while s > min_size and HanjiUi.text_width(text, s) > max_w:
		s -= 1
	return s

# 지금 프레임 상태에서 헤더 배치의 안내 원소({} = 없음).
func _hint_element(frame) -> Dictionary:
	for e in frame.store_header_layout(frame._panel_rect(), frame.store_header_pad()):
		if bool(e["hint"]):
			return e
	return {}

# ── ② #1 꾸미기 안내가 화면 안에 든다(라이브 — 실제로 모드를 켠다) ──────────
func _check_deco_notice(m: Node) -> void:
	print("② #1 꾸미기 안내 폭")
	var feed = m.notice_feed
	feed._items.clear()
	var was: bool = m._deco_mode
	if was:
		m._toggle_deco_mode()
		feed._items.clear()
	m._toggle_deco_mode()
	var wide: Array = []
	for it in feed._items:
		if bool(it.get("wide", false)):
			wide.append(String(it["text"]))
	if m._deco_mode:
		m._toggle_deco_mode()
	feed._items.clear()

	# 알림 띠 기하 — notice_feed._draw가 쓰는 그 식(글자는 pos.x + 8, wide 한계는 view.x − MARGIN*2).
	var view: Vector2 = feed._view()
	var start_x: float = feed.MARGIN + 8.0
	var limit: float = view.x - feed.MARGIN * 2.0
	var widest := 0.0
	var over := false
	for t in wide:
		var w := HanjiUi.text_width(t, 14)
		widest = maxf(widest, w)
		if start_x + w > view.x or w > limit:
			over = true
	_check("②a 꾸미기 진입 안내가 여러 줄로 선다(줄 수 %d · 피드 상한 %d)"
			% [wide.size(), feed.MAX_ITEMS], wide.size() >= 2 and wide.size() <= feed.MAX_ITEMS)
	_check("②b 각 줄이 화면(%.0fpx)·wide 한계(%.0fpx) 안에 든다(최장 %.0fpx, 시작 x %.0f)"
			% [view.x, limit, widest, start_x], not over and widest > 0.0)
	# 정보 보존 — R15가 광고하던 키가 한 자리도 안 빠졌다(짧게 만드느라 잃으면 #18과 같은 실패).
	var joined := " ".join(wide)
	var keys := ["[C]", "[Q]/[E]", "「[」「]」", "「,」「.」", "[R]"]
	var missing: Array = []
	for k in keys:
		if not joined.contains(k):
			missing.append(k)
	_check("②c 키 광고가 하나도 안 빠졌다(누락: %s)"
			% ("없음" if missing.is_empty() else ", ".join(missing)), missing.is_empty())

# ── ③ #2 온보딩 배너 판이 뷰포트 안에 든다(전 단계 · 양 갈래) ────────────────
# 표본이 아니라 **레지스트리 전수**다: 단계는 0..Onboarding.DONE, 갈래는 miho_away 두 값.
func _check_onboarding_plate(m: Node) -> void:
	print("③ #2 온보딩 배너 판 폭")
	var ob = m.onboarding
	var banner = m.onboarding_banner
	var view: Vector2 = banner._view()
	var keep: int = ob.step
	var worst := 0.0
	var worst_text := ""
	var over: Array = []
	for st in range(Onboarding.DONE + 1):
		ob.step = st
		for away in [false, true]:
			var g: String = ob.guidance(away)
			if g == "":
				continue
			var plate: float = HanjiUi.text_width(g, banner.FONT_SIZE) + banner.PAD_X * 2.0
			if plate > worst:
				worst = plate
				worst_text = g
			if plate > view.x:
				over.append("step%d/%s=%.0f" % [st, "away" if away else "home", plate])
	ob.step = keep
	_check("③a 전 단계·양 갈래의 배너 판이 뷰포트(%.0fpx) 안에 든다(최대 %.0fpx · 넘침: %s)"
			% [view.x, worst, "없음" if over.is_empty() else ", ".join(over)], over.is_empty())
	_check("③b 최장 줄도 판이 화면 왼쪽 밖으로 안 나간다(x = %.2f)"
			% ((view.x - worst) * 0.5), (view.x - worst) * 0.5 >= 0.0)
	ob.step = Onboarding.MEET_MIHO
	var away_text: String = ob.guidance(true)
	ob.step = keep
	_check("③c 출근 갈래가 목적지·방향·두 키를 다 남겼다 — 「%s」" % away_text,
		away_text.contains("카페") and away_text.contains("동쪽")
			and away_text.contains("[방향키]") and away_text.contains("[우클릭]"))

# ── ④ #3 제작 실패 알림이 프레임 안에서 거짓 키를 안 말한다 ──────────────────
func _check_craft_notice(m: Node) -> void:
	print("④ #3 제작 실패 알림의 [Tab]")
	# 프레임 시그널 핸들러(`_on_frame_*`) 안에서 발화하는 "가방 비우기" 알림엔 [Tab]이 없어야 한다.
	# 밖(월드 동작)에는 그대로 있어야 한다 — 거기선 참인 안내다. 두 쪽을 한 스캔으로 가른다.
	var in_frame: Array = []
	var outside := 0
	var cur := ""
	for i in range(_src.size()):
		var line := _src[i]
		if line.begins_with("func "):
			cur = line.substr(5, line.find("(") - 5)
		if line.strip_edges().begins_with("#"):
			continue
		if not (line.contains("_notice(") and line.contains("가방")):
			continue
		if cur.begins_with("_on_frame_"):
			if line.contains("[Tab]"):
				in_frame.append("%s:%d" % [cur, i + 1])
		elif line.contains("[Tab]"):
			outside += 1
	_check("④a 프레임 핸들러 안에서 [Tab]을 광고하는 가방 알림이 0줄(위반: %s)"
			% ("없음" if in_frame.is_empty() else ", ".join(in_frame)), in_frame.is_empty())
	_check("④b 월드 동작 쪽 형제 알림은 그대로 [Tab]을 말한다(%d줄 — 거기선 참이다)" % outside,
		outside >= 10)
	# 그 Tab이 실제로 무엇을 하는가 — "가방으로 간다"가 아니라 "프레임을 닫는다".
	var closes := _line_in_func(_src, "func _process", "if frame.context == InventoryFrame.CTX_MENU:")
	_check("④c 근거: 프레임이 열린 상태의 Tab은 `_close_frame()`이다(%d행 — 안내대로면 정반대)"
			% (closes + 1), closes >= 0)
	# 봉합된 문구가 갈 곳을 여전히 말한다(키만 지우고 방법을 잃으면 #19의 재발이다).
	var craft := _line_in_func(_src, "func _on_frame_craft", "만들지 못했다")
	var craft_line := _src[craft] if craft >= 0 else ""
	var lit := craft_line.substr(craft_line.find("\"") + 1)
	lit = lit.substr(0, maxi(lit.find("\""), 0))
	_check("④d 봉합 문구가 갈 곳을 그대로 말한다(같은 프레임 아래 백팩 그리드) — 「%s」" % lit,
		craft >= 0 and lit.contains("가방") and not lit.contains("[Tab]"))

# ── ⑤ #4 에필로그 닫기가 그 프레임 입력을 삼킨다(라이브) ────────────────────
func _check_epilogue_swallow(m: Node) -> void:
	print("⑤ #4 에필로그 닫기 입력 삼킴")
	var keep_open: bool = m._epilogue_open
	m._swallow_input_once = false
	m._epilogue_open = true
	m.ending_panel.visible = true
	m._on_ending_button()
	_check("⑤a 에필로그 닫기가 게이트를 내리고 그 프레임 입력을 삼킨다(열림 %s · 표 %s)"
			% [str(m._epilogue_open), str(m._swallow_input_once)],
		not m._epilogue_open and m._swallow_input_once)
	# `_process`가 그 표를 **에필로그 게이트보다 먼저** 소비해야 뜻이 산다(순서가 곧 봉합이다).
	var eat := _line_in_func(_src, "func _process", "if _swallow_input_once:")
	var gate := _line_in_func(_src, "func _process", "if _epilogue_open:")
	_check("⑤b 삼킴 소비(%d행)가 에필로그 게이트(%d행)보다 먼저 흐른다" % [eat + 1, gate + 1],
		eat >= 0 and gate >= 0 and eat < gate)
	m._swallow_input_once = false
	m._epilogue_open = false
	m.ending_panel.visible = false
	_check("⑤c 기록: 라우터의 다른 축은 오동작이 성립하지 않는다 — 키보드 닫기는 패널을 통째로"
			+ " 숨기고 버튼은 그 자식이라 도달 불가다(패널 %s · 버튼 %s)"
			% [str(m.ending_panel.visible), str(m.ending_restart.is_visible_in_tree())],
		not m.ending_panel.visible and not m.ending_restart.is_visible_in_tree()
			and m.ending_restart.get_parent() == m.ending_panel)
	m._epilogue_open = keep_open

# ── ⑥ #5 짐승 칸 화분은 도구·수확 디스패치를 한 번만 연다(라이브) ────────────
func _check_animal_pot_dispatch(m: Node) -> void:
	print("⑥ #5 짐승 칸 화분 이중 디스패치")
	var adult := Vector2i(-1, -1)
	for at in m.ranch.animal_tiles():
		if m.ranch.is_adult(at):
			adult = at
			break
	_check("⑥ 무대: 성체 스타터 짐승이 실내 제 칸에 서 있다(%s)" % str(adult),
		adult != Vector2i(-1, -1) and m.ranch.has_animal_at(adult))
	if adult == Vector2i(-1, -1):
		return
	# 전제 — 배치 가드가 짐승 칸을 안 막는다(그래서 이 겹침이 정상 플레이로 성립한다).
	# ★ 이 배제는 **배치 B(#15) 몫**이라 여기서 안 고쳤다. 여기 봉합한 것은 이중 실행뿐이다.
	m._region = RegionCatalog.HOME
	var keep_indoor: String = m._indoor
	m._indoor = m.ranch.building_of(adult)
	_check("⑥a 전제: `_can_place_pot`이 짐승 칸을 배제하지 않는다(배치 B 몫 — 여기선 미수정)",
		m._can_place_pot(adult))
	m._indoor = keep_indoor

	# 빈 실내 칸 하나 — 짐승이 없는 화분 칸은 여전히 디스패치가 열려야 한다(과잉 배제 방지).
	var free_tile := adult + Vector2i(0, -1)
	var guard := 0
	while m.ranch.has_animal_at(free_tile) and guard < 8:
		free_tile += Vector2i(1, 0)
		guard += 1
	m.garden_pot.place(adult)
	m.garden_pot.place(free_tile)
	_check("⑥b 짐승 칸 화분은 도구·수확 디스패치를 안 연다 / 짐승 없는 화분 칸은 연다(%s·%s)"
			% [str(m._pot_dispatch_at(adult)), str(m._pot_dispatch_at(free_tile))],
		not m._pot_dispatch_at(adult) and m._pot_dispatch_at(free_tile))
	_check("⑥c 회수 창구는 안 막힌다 — 그 칸의 `_pot_at`은 여전히 참이다(매몰 방지)",
		m._pot_at(adult) and m._pot_at(free_tile))

	# 왜 한 번이어야 하는가 — 같은 칸에 두 번 들어가면 혼력이 두 번 나간다(실해 재현).
	m.ranch.feed(adult)
	m.ranch.advance_day()
	_check("⑥ 무대: 급여→advance로 산물이 대기 중", m.ranch.has_product(adult))
	var keep_target: Vector2i = m._target
	m._target = adult
	m.energy.refill()
	var e0: int = m.energy.current
	var first: bool = m._try_harvest()
	var e1: int = m.energy.current
	var second: bool = m._try_harvest()
	var e2: int = m.energy.current
	m._target = keep_target
	_check("⑥d 실해: 한 칸에 두 번 들어가면 혼력이 두 번 나간다(%d→%d→%d · 산물 %s → 쓰다듬 %s)"
			% [e0, e1, e2, str(first), str(second)],
		first and second and e1 < e0 and e2 < e1)
	# 그래서 두 게이트가 짐승 칸을 뺀 술어를 본다(옛 `pot_at_target`이 그 자리에 남아 있으면 안 된다).
	var lmb := _line_in_func(_src, "func _process", "or holding_weapon or pot_dispatch or")
	var rmb := _line_in_func(_src, "func _process", "(_target_valid or pot_dispatch)")
	_check("⑥e 도구(%d행)·수확(%d행) 게이트가 짐승 칸을 뺀 술어를 본다" % [lmb + 1, rmb + 1],
		lmb >= 0 and rmb >= 0)
	m.garden_pot.remove(adult)
	m.garden_pot.remove(free_tile)

# ── ⑦ #6 위장 잡귀가 진짜 돌과 같은 자리에 그려진다 ─────────────────────────
func _check_disguise_rock(m: Node) -> void:
	print("⑦ #6 위장 잡귀 좌표")
	var tile := Vector2i(7, 9)
	var mob: Mob = Mob.spawn(MobCatalog.DALGYAL, tile, 1234, 0)
	_check("⑦ 무대: 달걀귀신은 위장형이라 잠들어 스폰된다(awake %s)" % str(mob.awake),
		MobCatalog.is_disguise(MobCatalog.DALGYAL) and not mob.awake)
	# 위장형은 step이 첫 줄에서 반환하므로 pos가 스폰값 그대로다 → tile()이 곧 그 칸이다.
	for i in 10:
		mob.step(0.1, Vector2(999.0, 999.0), func(_t: Vector2i) -> bool: return false)
	_check("⑦a 위장 중엔 한 픽셀도 안 움직인다 → `m.tile()`이 스폰 칸 그대로다(%s)" % str(mob.tile()),
		mob.tile() == tile and is_equal_approx(mob.pos.y, float(tile.y * Mob.TILE_PX) + 16.0))

	# 두 규약의 어긋남을 수치로 못 박는다 — 옛 몹 발치 식은 타일 좌상단보다 정확히 3.2px 위였다.
	var rsz: Vector2 = m.MINE_TEX_ROCK.get_size()
	var real_top := Vector2(tile.x * m.TILE, tile.y * m.TILE)
	var old_rp := mob.pos - Vector2(rsz.x * 0.5, rsz.y - float(m.TILE) * 0.40)
	_check("⑦b 옛 발치 규약은 진짜 돌(%s)보다 정확히 %.1fpx 위였다(x는 일치)"
			% [str(real_top), real_top.y - old_rp.y],
		rsz == Vector2(32.0, 32.0) and is_equal_approx(old_rp.x, real_top.x)
			and is_equal_approx(real_top.y - old_rp.y, 3.2))

	# 지금은 진짜 돌과 **같은 함수·같은 인자**를 탄다(그림자까지 한 출처).
	var uses := _line_in_func(_src, "func _draw_mine_mobs", "_draw_mine_prop(MINE_TEX_ROCK, m.tile()")
	var old_form := _line_in_func(_src, "func _draw_mine_mobs", "rsz.y - TILE * 0.40")
	var real_call := _line_in_func(_src, "func _draw_mine_prop", "Rect2(Vector2(t.x * TILE, t.y * TILE)")
	_check("⑦c 위장 분기(%d행)가 진짜 돌의 헬퍼를 그대로 부르고, 옛 pos 식은 사라졌다(%d)"
			% [uses + 1, old_form], uses >= 0 and old_form < 0)
	_check("⑦d 그 헬퍼가 타일 좌상단 blit다(%d행) — 두 그림이 한 식에서 나온다" % (real_call + 1),
		real_call >= 0)

# ── ⑧ #7 OWNER-DECISION 기록 — 판정 타일(중심) vs 몸 발치 ───────────────────
# 고치지 않았다. 여기서는 **사실만** 잰다: 언제 두 축이 갈리는지, 그리고 어느 축을 옮겨도 무엇이
# 깨지는지. owner가 결정할 재료를 회귀가 들고 있게 한다(R15 ㉔d가 WASD 비대칭을 남긴 그 방식).
func _record_mob_foot_axis(m: Node) -> void:
	print("⑧ #7 몹 판정 타일 vs 몸 발치 — OWNER-DECISION 기록")
	var tile := Vector2i(11, 10)
	var mob: Mob = Mob.spawn(MobCatalog.HEOTGEOT, tile, 77, 0)
	var foot_off := float(m.TILE) * 0.40
	var spawn_foot_row := floori((mob.pos.y + foot_off) / float(m.TILE))
	_check("⑧a 사실: 스폰 직후엔 두 축이 일치한다(판정 행 %d = 발치 행 %d)"
			% [mob.tile().y, spawn_foot_row], mob.tile().y == spawn_foot_row)
	# 움직인 몹 — 발견이 든 그 좌표(pos.y = 348)에서 두 축이 한 행 갈린다.
	mob.pos = Vector2(336.0, 348.0)
	var judged := mob.tile()
	var seen := Vector2i(floori(mob.pos.x / float(m.TILE)), floori((mob.pos.y + foot_off) / float(m.TILE)))
	_check("⑧b 사실: 움직이면 갈린다 — 판정 %s / 눈에 보이는 발치 %s(어긋남 %.1fpx · 40%% 구간)"
			% [str(judged), str(seen), foot_off], judged != seen and judged.y + 1 == seen.y)
	# ㉠의 대가 — 판정을 발치로 옮기면 "겹친 적을 벤다"(R10 #3)가 깨진다. 그 계약을 여기서 확인한다.
	var origin: Vector2i = m._player_tile()
	var arc: Array = m._weapon_arc()
	var overlap: Mob = Mob.spawn(MobCatalog.HEOTGEOT, origin, 78, 1)
	overlap.pos = m.player.global_position
	_check("⑧c 사실: 겹친 적은 판정 타일이 곧 선 자리(%s = %s)라 베인다 — R10 #3이 arc 맨 앞에"
			% [str(overlap.tile()), str(origin)] + " origin을 담은 근거가 이 등식이다(arc 포함 %s)"
			% str(arc.has(origin)), overlap.tile() == origin and arc.has(origin))
	# 그 등식이 발치 축에서 깨지는 자리 — 플레이어가 제 칸 아래쪽 40%(y%%32 ≥ 19.2)에 서면 그렇다.
	var low := Vector2(m.player.global_position.x, float(origin.y * m.TILE) + 24.0)
	overlap.pos = low
	var low_foot := Vector2i(floori(low.x / float(m.TILE)), floori((low.y + foot_off) / float(m.TILE)))
	_check("⑧c' 대가㉠: 같은 칸 아래쪽(y%%32 = 24)에 겹치면 발치 축은 한 행 아래(%s ≠ %s)를 가리켜"
			% [str(low_foot), str(overlap.tile())] + " R10 #3의 등식(겹친 적 = 선 자리)이 깨진다 —"
			+ " 그 행이 부채꼴 밖이면 겹친 적을 못 벤다(바라보는 쪽에 달렸다)",
		overlap.tile() == origin and low_foot.y == origin.y + 1 and low_foot != origin)
	_check("⑧d 대가㉡: 렌더를 pos에 맞추면 전 몹이 %.1fpx 뜬다(화면상 %.1fpx — S5-T10이 못 박은 축)"
			% [foot_off, foot_off * 2.0], foot_off > 0.0)
