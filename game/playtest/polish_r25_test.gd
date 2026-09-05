extends SceneTree
# ★[폴리시 25회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#12).
#
# 렌즈: R24 diff 리뷰(#0~#3) · 이월 큐 소비 계약(#4~#7) · affinity 축 정합(#8~#12).
#
# 이 배치의 태도 셋.
#   ㉠ **표의 폭은 형제끼리 같아야 한다.** R24 #18이 밀린 밤 표를 누적 배열로 넓히면서, 그 표를
#      읽는 형제 둘(굳은 하늘 · 절기 재스폰)이 스칼라 1칸으로 남았다. #1·#5는 그래서 «가장 최근
#      밤만 자기 아침의 답을 받는» 절름발이가 됐고, #3은 «1회성 절기 패스가 통째로 증발하는»
#      자리로 남았다. 이 스위트는 세 표를 같은 폭·같은 창구·같은 왕복으로 재고, 그 등가성을
#      **판을 실제로 굴려** 잰다(수치가 아니라 칸 집합이 같은지).
#   ㉡ **순서는 «집에서 잤을 때»와의 등가성으로만 잰다.** #4는 «재스폰이 위에 있다»가 아니라
#      «귀가 프레임의 판이 집에서 잔 판과 한 칸이라도 다르다»가 결함이다. ③은 두 세계를 각각
#      굴려 잡초·debris 칸 집합을 통째로 비교하고, **옛 순서로 굴린 셋째 세계**가 실제로 다르다는
#      것까지 잰다(다르지 않으면 등가성 단언이 공허하다).
#   ㉢ **축을 묻는다.** #8~#12는 전부 «지나간 사건을 라이브 칸으로 물었다»의 변주다. ADR-0066의
#      points/stage 절연은 계약이므로 되돌리지 않고, **소비처가 어느 축을 읽는가**만 갈랐다.
#      그래서 ⑥·⑦은 `reset_hearts()`(이혼이 하는 그 한 줄)를 실제로 때린 뒤 게이트를 다시 묻는다.
#
# 무엇을 보증하나(번호 = 25회차 헌트 발견 인덱스).
#   ① #0 `layout`이 접은 띠의 secs까지 `_process`가 깎아, 같은 프레임에 같은 secs로 밀린 줄들이
#      **동시에** 만료됐다 — 숨은 띠에는 되돌아올 프레임이 0이고, 완공 래치처럼 재발화 경로가
#      없는 줄은 그 세이브에서 영영 안 떴다(R11 keep 계약이 그리기 단계에서 재발).
#   ② #1·#5(**#5 = #1의 DUP** — 같은 뿌리·한 봉합) 굳은 하늘이 하루치 스칼라라, 밀린 밤이 여럿이면
#      가장 최근 밤만 굳은 답을 받고 나머지는 **살아 있는** 카페 진척을 다시 팠다.
#   ③ #3·#4 절기 재스폰 표만 스칼라 덮어쓰기로 남아 1회성 패스가 증발했고(#3), 그 소비가 밀린
#      밤들보다 **위**에 있어 귀가 프레임의 판이 집에서 잔 판과 갈렸다(#4).
#   ④ #7 이월 루프가 파종 알림만 합치고 잡초 파괴 두 줄은 밤마다 쏴, 세 밤이면 한 프레임에 최대
#      여섯 줄이 상한 4를 스스로 밀어냈다.
#   ⑤ #6 `_free_pasture_tiles`가 런타임 나무 원장을 안 봐, 자체 파종목 위에 짐승이 배정됐다
#      (형제 `_encroach_candidates`는 R6에서 이미 그 한 줄을 받았다).
#   ⑥ #8 척추 B5 게이트가 메인 3인만 라이브 stage로 읽어, 이혼 한 번이 엔드게임 관문을 재잠금했다.
#   ⑦ #9 조연 ♡3 소프트 게이트가 «씨앗 컷신을 봤나»를 라이브 stage로 물어, 이혼이 목격을 취소했다.
#   ⑧ #10 앵커 관계 탭 효과 줄이 잠금을 안 봐, ♡0 옆에 «되찾음 5/5 · 돌봄 600»을 나란히 그렸다.
#   ⑨ #11 의뢰 완료 알림이 점수 천장을 안 봐, 만충 상대에게 «호감도↑»를 무조건 광고했다.
#   ⑩ #12 구세이브 stage 소급이 비트 원장을 안 낳아, 그 세이브의 청혼이 영구 거절됐다.
#
# 판정: #0~#4·#6~#12 **CONFIRMED**(12건 봉합) · **#5 = #1 DUP**(같은 봉합으로 죽는다).
#   ★ 배치 B 몫 둘의 명시 판정도 여기 남긴다(그쪽 워커가 중복 봉합하지 않게):
#     · **#23 = #1의 DUP** — 같은 «굳은 하늘 스칼라 vs 밀린 밤 배열» 뿌리다. ②가 그 봉합을 잠근다.
#     · **#21 = #4의 DUP** — 같은 «절기 재스폰 pending이 밀린 밤보다 먼저 소비된다» 뿌리다.
#       ③이 그 봉합을 잠근다(#21이 든 «새 절기 잡초가 지난 밤 확산의 소스가 된다»는 순서가
#       바로잡히는 순간 성립하지 않는다 — 재스폰이 그 밤 뒤로 내려간다).
#
# 하중 검증(**실측** — 봉합을 되돌려 실제로 뜬 red를 그대로 옮겨 적는다. 파괴 12배치 전건 확인):
#   #0  `_process`의 `shown` 게이트 삭제(전원 감산 복귀) → ①c·①d red · **polish_r24 ②g red**
#       (숨은 띠가 그려지기 전에 만료돼 큐가 0이 된다 — R24 ②g의 무대를 실제 타임라인으로 고친 뒤
#        비로소 그 항이 이 축을 문다. 옛 ②g는 최신 항목을 손으로 지워 어떤 타임라인도 안 재현했다)
#   #1  `_weather_sealed_on`을 «표의 마지막 한 칸만» 보게 축소 → ②b·②c red(오래된 밤이 라이브 답으로 떨어져
#       두 하늘이 같은 판을 낸다)
#   #3  `_queue_pending_night(_season_respawn_pending_days, day)` → 무조건 대입 복귀 → ③a·③b' red
#   #4  `_run_season_respawn(night)`을 밤 루프 **앞**으로 되돌림 → ③c·③e red(판이 실제로 갈린다 —
#       잡초 25칸·재스폰 debris 4칸이 집에서 잔 판과 다른 집합이 된다)
#   #6  `_free_pasture_tiles`의 `tree_ledger.is_occupied` 가지 삭제 → ⑤c red(형제 ⑤d는 자기 술어를 따로
#       들고 있어 안 빨개진다 — 그 비대칭이 이 결함의 실체다)
#   #7  이월 루프의 `announce=false`를 지움 → ④a·④d·④e red(「잡초가 작물」 줄이 **4개** 서고 큐가
#       상한 4를 그대로 채운다 = 그 프레임의 다른 피드백이 축출된다)
#   #8  `_spine_main_stages`를 `r.affinity.stage`로 복귀 → ⑥c·⑥d red(게이트 keys 항이 false로 돌아서고
#       라벨이 「옥자 집 (잠김 — 미결의 죄 해결 후)」로 되감긴다)
#   #9  `_chorus_gate_ok`를 `r.affinity.stage`로 복귀 → ⑦b·⑦c red(이혼 뒤 조연 진급이 칸 2·비트 false로
#       물러난다 = 영구 «진급 대기». 대조군 ⑦d는 그대로 초록 — 게이트 자체는 살아 있다)
#   #10 `effect_fn`의 `_okja_track_open()` 삼항 삭제 → ⑧c·⑧d'·⑧d'' red(♡0 옆에 «돌봄 N»이 선다)
#   #11 `is_gift_no_op` 갈래 삭제 → ⑨b red(점수 300 → 300인데 「네오 호감도↑」)
#   #12 로드 소급 루프 삭제 → ⑩a·⑩b·⑩c' red(비트 1~3이 영영 0이라 아크가 안 닫힌다)
#
# 실행: ./run_tests.sh polish_r25   (헤드리스는 반드시 game/에서 · 순차)

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

# ── 소스 스캔 헬퍼(polish_r7~r24 관례 — 니들은 반드시 함수 안에서 센다) ──────
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _count_in(lines: PackedStringArray, fn_needle: String, needle: String) -> int:
	var head := -1
	for i in range(lines.size()):
		if lines[i].begins_with(fn_needle):
			head = i
			break
	if head < 0:
		return -1
	var n := 0
	for i in range(head + 1, lines.size()):
		if lines[i].begins_with("func ") or lines[i].begins_with("static func "):
			break
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			n += 1
	return n

func _line_in(lines: PackedStringArray, fn_needle: String, needle: String) -> int:
	var head := -1
	for i in range(lines.size()):
		if lines[i].begins_with(fn_needle):
			head = i
			break
	if head < 0:
		return -1
	for i in range(head + 1, lines.size()):
		if lines[i].begins_with("func ") or lines[i].begins_with("static func "):
			break
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			return i + 1
	return -1

# 알림 큐의 지금 문구들(그리기 큐 그대로 — 내부 상태를 새로 만들지 않는다).
func _notice_texts(m: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for it in m.notice_feed._items:
		out.append(String(it["text"]))
	return out

func _notices_with(m: Node, needle: String) -> int:
	var n := 0
	for t in _notice_texts(m):
		if t.contains(needle):
			n += 1
	return n

# 이 판의 잡초·재스폰 debris 칸 집합(정렬된 문자열 — 두 세계를 통째로 비교하는 지문).
func _yard_print(m: Node) -> String:
	var w: Array = []
	for t: Vector2i in m.reclaim.weed_tiles():
		w.append("%d,%d" % [t.x, t.y])
	var d: Array = []
	for t2: Vector2i in m.reclaim.respawned_debris_tiles():
		d.append("%d,%d|%s" % [t2.x, t2.y, m.reclaim.respawned_debris_kind(t2)])
	w.sort()
	d.sort()
	return "W[" + ";".join(w) + "] D[" + ";".join(d) + "]"

# 테마 슬롯 날 찾기(polish_r22 `_find_theme_day`와 같은 판정 — 비해금이면 want, 해금이면 평온).
func _find_theme_day(want: int, revenue_axis: bool) -> int:
	for d in range(2, 2000):
		var slot := Festival.theme_slot_for_day(d)
		if slot == Festival.NONE:
			continue
		if (int(Festival.UNLOCK_REVENUE[slot]) > 0) != revenue_axis:
			continue
		if Weather.weather_for_day(d, false) != want:
			continue
		if Weather.weather_for_day(d, true) != Weather.CALM:
			continue
		return d
	return -1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R25 회귀 — 배치 A(#0~#12) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_check("무대 전제: main(%d행)을 읽었다(부정 단언 공허 통과 방지)" % _src.size(), _src.size() > 1000)

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	m._indoor = ""
	m._sleeping = false
	m._transitioning = false

	_check_notice_lossless(m)        # ① #0
	_check_sealed_weather_table(m)   # ② #1(= #5 DUP · 배치 B #23 DUP)
	await _check_respawn_carry(m)    # ③ #3·#4(= 배치 B #21 DUP)
	await _check_weed_notice_merge(m)   # ④ #7
	_check_pasture_tree(m)           # ⑤ #6
	_check_chorus_gate_axis(m)       # ⑦ #9
	_check_spine_gate_axis(m)        # ⑥ #8 — 미혹 숲을 세우므로 ⑦ 뒤에(끝나면 안식 복귀)
	_check_okja_effect_lock(m)       # ⑧ #10
	_check_quest_affinity_notice(m)  # ⑨ #11
	_check_old_save_heart_bits(m)    # ⑩ #12 — 세이브 파일을 쓰므로 맨 끝

	# ★ 이 스위트는 ②·⑩에서 세이브를 **쓴다**(굳은 하늘 표 왕복·구세이브 소급이 파일 경로를 타야
	#   하는 검증이라 무대가 곧 파일이다). 끝나면 지운다 — polish_r24 ⑮·⑯이 세운 그 관례.
	SaveManager.new().delete_save()
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 접힌 알림 띠는 «시간도 안 쓴다»(무손실의 실체) ──────────────────────
func _check_notice_lossless(m: Node) -> void:
	print("① #0 알림 무손실 — 접힌 띠 ↔ 시간")
	var feed: NoticeFeed = m.notice_feed
	if feed == null:
		_check("①x 무대 없음(notice_feed null)", false)
		return
	var nsrc := _lines_of_file("res://notice_feed.gd")
	_check("①a 배선: `_process`가 기하를 스스로 다시 재지 않고 `layout` 하나만 소비한다(재는 값 = 시간을 쓰는 값)",
		_count_in(nsrc, "func _process(", "layout(") == 1
			and _count_in(nsrc, "func _process(", "RESERVE_TOP") == 0
			and _count_in(nsrc, "func _process(", "_wrapped_rows(") == 0)
	# 문구는 손으로 안 짓는다 — main이 실제로 쏘는 긴 안내를 조립해 «접히는» 띠를 만든다.
	var text := "발밑에 무언가 걸린다 — 백팩이 가득 차 %s 캘 수 없다 ([Tab] 가방에서 자리를 비우고 다시)" \
		% HanjiUi.with_eul(ItemCatalog.name_of(ItemCatalog.WEDDING_CHARM))
	var secs := 5.0
	feed._items.clear()
	for _i in range(NoticeFeed.MAX_ITEMS):
		feed.push(text, secs)
	var font := HanjiUi.font()
	var view := Vector2(640, 360)
	var slots := feed.layout(font, view)
	_check("①b 무대: 큐 %d개 중 %d개만 서고 나머지는 접힌다(넘침이 실제로 벌어진다)"
			% [feed._items.size(), slots.size()],
		slots.size() > 0 and slots.size() < feed._items.size())
	var hidden := feed._items.size() - slots.size()
	var tick := 0.5
	feed._process(tick)
	var shown_secs: Array = []
	var hidden_secs: Array = []
	for i in feed._items.size():
		var s: float = float(feed._items[i]["secs"])
		if i < hidden:
			hidden_secs.append(s)
		else:
			shown_secs.append(s)
	var hidden_intact := true
	for s2 in hidden_secs:
		if not is_equal_approx(float(s2), secs):
			hidden_intact = false
	var shown_ticked := true
	for s3 in shown_secs:
		if not is_equal_approx(float(s3), secs - tick):
			shown_ticked = false
	_check("①c **시간은 그려진 띠에게만 흐른다** — 한 틱(%.1f초) 뒤 그린 %d개는 %.1f초·접힌 %d개는 %.1f초 그대로"
			% [tick, shown_secs.size(), secs - tick, hidden_secs.size(), secs],
		hidden > 0 and hidden_intact and shown_ticked)
	# 그린 띠가 시간으로 전부 사라지면 접혀 있던 것이 **남은 시간 전부를 들고** 내려온다.
	var guard := 0
	while feed._items.size() > hidden and guard < 40:
		feed._process(tick)
		guard += 1
	var back := feed.layout(font, view)
	var survivors_full := feed._items.size() == hidden
	for it in feed._items:
		if not is_equal_approx(float(it["secs"]), secs):
			survivors_full = false
	_check("①d **잃은 줄 0** — 앞의 띠가 만료된 뒤 접혀 있던 %d개가 %.1f초를 그대로 들고 서 있다(그린 %d개)"
			% [hidden, secs, back.size()],
		survivors_full and back.size() == hidden and hidden > 0)
	# 그리기 계약도 그대로다 — 되돌아온 띠가 예약 영역을 안 넘는다.
	var in_room := back.size() > 0
	for sl in back:
		var p: Vector2 = sl["pos"]
		if p.y < NoticeFeed.RESERVE_TOP or p.y + float(sl["h"]) > view.y - NoticeFeed.RESERVE_BOTTOM:
			in_room = false
	_check("①e 되돌아온 띠도 예약 영역(위 %.0f · 아래 %.0f) 안에 선다(R24 #1 계약 불변)"
			% [NoticeFeed.RESERVE_TOP, view.y - NoticeFeed.RESERVE_BOTTOM], in_room)
	feed._items.clear()

# ── ② #1(= #5) 굳은 하늘이 밀린 밤 표와 같은 폭이 됐다 ───────────────────────
func _check_sealed_weather_table(m: Node) -> void:
	print("② #1(=#5 DUP · 배치B #23 DUP) 굳은 하늘 표 ↔ 밀린 밤 여럿")
	# ★ 매출 축 슬롯을 고른다 — 낮의 `_cafe_revenue_total`이 그 자리에서 답을 뒤집는 유일한 축이다
	#   (단계 축은 카페 단계가 문턱이라 이 무대에서 못 뒤집는다).
	var d := _find_theme_day(Weather.RAIN, true)
	_check("②a 무대: 비해금이면 혼우·해금이면 평온인 테마 슬롯 날 %d를 판에서 찾았다(두 답이 실제로 갈린다)"
			% d, d > 1)
	if d <= 1:
		return
	var d2 := d + 1
	var day0: int = m.clock.day
	var rev0: int = m._cafe_revenue_total
	var pend0: Array = m._weed_pending_days.duplicate()
	var sealed0: Dictionary = m._weather_sealed_days.duplicate()
	var snap: Dictionary = m.reclaim.to_save()
	# 두 밤이 밀렸다 — 오래된 밤(d)이 혼우 아침, 최신 밤(d2)이 평온 아침으로 굳는다.
	m._weed_pending_days = [d, d2]
	m._weather_sealed_days = {}
	m._seal_weather_for(d, Weather.RAIN)
	m._seal_weather_for(d2, Weather.CALM)
	m._cafe_revenue_total = 999999                  # 낮에 문턱을 넘겼다 — 살아 있는 답이 뒤집힌다
	_check("②a' 무대 전제: 그 날의 **살아 있는** 답이 평온으로 뒤집혔다(굳은 답과 갈린다)",
		m._weather_on(d) == Weather.CALM)
	_check("②b **오래된 밤도 자기 아침의 답을 받는다** — 굳은 답 d=「%s」 · d+1=「%s」(종전엔 d가 라이브로 떨어졌다)"
			% [Weather.NAMES[m._weather_sealed_on(d)], Weather.NAMES[m._weather_sealed_on(d2)]],
		m._weather_sealed_on(d) == Weather.RAIN and m._weather_sealed_on(d2) == Weather.CALM)
	_check("②b' 가지치기가 살아 있는 표를 안 지운다 — 밀린 두 밤 %s이 표에 그대로 있다"
			% str(m._weather_sealed_days.keys()),
		m._weather_sealed_days.has(d) and m._weather_sealed_days.has(d2))
	# 하중 — 그 답이 실제로 그 밤의 판을 가른다(두 하늘에서 확산 칸 수가 갈린다).
	var counts: Array[int] = []
	for sky in [Weather.RAIN, Weather.CALM]:
		m.reclaim.load_save(snap)
		var sources: Array = []
		for c: Vector2i in m._encroach_candidates():
			sources.append(c)
			if sources.size() >= 60:
				break
		for c2 in sources:
			m.reclaim._weeds[c2] = true
		var before: int = m.reclaim.weed_count()
		# ★ 표에 **두 밤**을 함께 둔다 — 굳히기가 «가장 최근 한 칸»으로 좁아지면(스칼라 시절) 이
		#   오래된 밤이 라이브 답으로 떨어져 두 하늘이 같은 판을 내므로, 그때 이 항이 빨개진다.
		m._weather_sealed_days = {d: sky, d2: Weather.CALM}
		m._run_weed_spread(d, false)
		counts.append(m.reclaim.weed_count() - before)
	_check("②c 하중: 그 굳은 답이 판을 가른다 — 혼우 아침 %d칸 ↔ 평온 아침 %d칸(젖은 밤 배수 ×%.1f가 실린다)"
			% [counts[0], counts[1], Reclaim.SPREAD_WET_MULT],
		counts[0] > counts[1] and counts[0] != counts[1])
	# 가지치기 — 아무도 안 묻는 옛 날은 떨어진다(세이브가 판 길이만큼 안 자란다).
	m._weed_pending_days = []
	m._tree_seed_pending_days = []
	m._season_respawn_pending_days = []
	m._weather_sealed_days = {}
	m._seal_weather_for(d, Weather.RAIN)
	m._seal_weather_for(d2, Weather.CALM)
	_check("②d 밀린 밤이 없으면 옛 칸은 떨어진다 — 표 %s(오늘 한 칸만)" % str(m._weather_sealed_days.keys()),
		m._weather_sealed_days.size() == 1 and m._weather_sealed_days.has(d2))
	# 세이브 왕복 — 표가 통째로 실리고 통째로 돌아온다.
	m._weed_pending_days = [d]
	m._weather_sealed_days = {d: Weather.RAIN, d2: Weather.SNOW}
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	var raw_tbl: Dictionary = raw.get("weather_sealed_days", {})
	_check("②e 세이브가 표를 **통째로** 적는다 — %d칸(d=%s · d+1=%s)"
			% [raw_tbl.size(), str(raw_tbl.get(d, -1)), str(raw_tbl.get(d2, -1))],
		raw_tbl.size() == 2 and int(raw_tbl.get(d, -1)) == Weather.RAIN
			and int(raw_tbl.get(d2, -1)) == Weather.SNOW)
	m._weather_sealed_days = {}
	var ok_load: bool = m._load_game()
	_check("②e' 로드가 그 표를 통째로 되살린다 — %s" % str(m._weather_sealed_days),
		ok_load and m._weather_sealed_days.size() == 2
			and int(m._weather_sealed_days.get(d, -1)) == Weather.RAIN
			and int(m._weather_sealed_days.get(d2, -1)) == Weather.SNOW)
	_check("②f 하위호환 — 키 없는 구세이브는 빈 표, **구 키 쌍**(스칼라 day/weather)은 한 칸 표로 읽힌다",
		m._sealed_weather_from({}).is_empty()
			and str(m._sealed_weather_from({"weather_sealed_day": d, "weather_sealed": Weather.SNOW}))
				== str({d: Weather.SNOW}))
	m.reclaim.load_save(snap)
	m._weather_sealed_days = sealed0
	m._weed_pending_days = pend0
	m._cafe_revenue_total = rev0
	m.clock.day = day0

# ── ③ #3·#4 절기 재스폰 표 — 누적 + 밤 루프 안의 제자리 ─────────────────────
func _check_respawn_carry(m: Node) -> void:
	print("③ #3·#4(배치B #21 DUP) 절기 재스폰 — 누적 표 ↔ 소비 순서")
	_check("③a 배선: 세 표가 **같은 창구**로 선다(대입이 아니라 누적 — 형제 3인방)",
		_count_in(_src, "func _on_day_advanced", "_queue_pending_night(_season_respawn_pending_days, day)") == 1
			and _count_in(_src, "func _on_day_advanced", "_queue_pending_night(_weed_pending_days, day)") == 1
			and _count_in(_src, "func _on_day_advanced",
				"_queue_pending_night(_tree_seed_pending_days, day)") == 1)
	# 창구 계약 — 연속 두 절기를 집 밖에서 맞아도 앞 절기가 안 덮인다.
	var tbl: Array = []
	m._queue_pending_night(tbl, 29)
	m._queue_pending_night(tbl, 57)
	m._queue_pending_night(tbl, 29)
	_check("③b 표가 두 절기를 다 든다(같은 날 중복은 안 든다) — %s(종전엔 57이 29를 덮었다)" % str(tbl),
		str(tbl) == str([29, 57]))
	# 라이브 — 집 밖에서 연속 두 절기를 맞아도 앞 절기가 안 덮인다(창구 계약의 실동작 판).
	var snap0: Dictionary = m.reclaim.to_save()
	var region_b: String = m._region
	var day_b: int = m.clock.day
	var s1 := GameClock.DAYS_PER_SEASON + 1
	var s2 := s1 + GameClock.DAYS_PER_SEASON
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	m._indoor = ""
	m._season_respawn_pending_days = []
	m.clock.day = s1
	m._on_day_advanced(s1)
	m.clock.day = s2
	m._on_day_advanced(s2)
	_check("③b' 라이브: 집 밖에서 **연속 두 절기**를 맞으면 표가 둘 다 든다 — %s(종전엔 뒤 절기가 앞을 덮어 그 절기치가 증발했다)"
			% str(m._season_respawn_pending_days),
		str(m._season_respawn_pending_days) == str([s1, s2]))
	m._season_respawn_pending_days = []
	m._weed_pending_days = []
	m._tree_seed_pending_days = []
	m.clock.day = day_b
	m._rebuild_region(region_b if region_b != "" else RegionCatalog.HOME)
	m._indoor = ""
	m.reclaim.load_save(snap0)
	m.notice_feed._items.clear()
	# 소비가 **밤 루프 안**이고, 한 밤 안에서 아침 정산과 같은 상대 순서다.
	var resp := _line_in(_src, "func _process", "_run_season_respawn(night)")
	var spread := _line_in(_src, "func _process", "_run_weed_spread(night")
	var seed := _line_in(_src, "func _process", "catch_up_seeding(night")
	var enc := _line_in(_src, "func _process", "_run_weed_encroach(night")
	_check("③c 이월 소비가 한 밤 안에서 **재스폰(%d) → 확산(%d) → 파종(%d) → 재점령(%d)** 순이다(아침 정산과 같다)"
			% [resp, spread, seed, enc],
		resp > 0 and spread > resp and seed > spread and enc > seed
			and _count_in(_src, "func _process", "nights.sort()") == 1)
	_check("③c' 별도 블록이 남아 있지 않다 — `_process`에 `_run_season_respawn`이 그 한 줄뿐이다",
		_count_in(_src, "func _process", "_run_season_respawn(") == 1)
	# ── 하중: 두 세계의 판을 통째로 비교한다(집에서 잔 판 ↔ 귀가 프레임의 판 ↔ 옛 순서의 판).
	var season_day := -1
	for dd in range(30, 400):
		if GameClock.is_season_first_day(dd) and GameClock.season_index_for_day(dd) != 3:
			season_day = dd
			break
	var night_a := season_day - 1
	_check("③d 무대: 성야절이 아닌 절기 첫날 %d를 판에서 찾았다(그 전날 밤 %d이 함께 밀린다)"
			% [season_day, night_a], season_day > 0 and night_a > 0)
	if season_day <= 0:
		return
	var snap: Dictionary = m.reclaim.to_save()
	var sealed0: Dictionary = m._weather_sealed_days.duplicate()
	m._weather_sealed_days = {night_a: Weather.CALM, season_day: Weather.CALM}
	# 세계 A — 집에서 두 밤을 잔 순서(아침 정산의 상대 순서를 손으로 편다).
	m.reclaim.load_save(snap)
	m._run_weed_spread(night_a, false)
	m._run_weed_encroach(night_a)
	m._run_season_respawn(season_day)
	m._run_weed_spread(season_day, false)
	m._run_weed_encroach(season_day)
	var world_home := _yard_print(m)
	# 세계 C — 옛 순서(재스폰이 밀린 밤들보다 먼저).
	m.reclaim.load_save(snap)
	m._run_season_respawn(season_day)
	m._run_weed_spread(night_a, false)
	m._run_weed_encroach(night_a)
	m._run_weed_spread(season_day, false)
	m._run_weed_encroach(season_day)
	var world_old := _yard_print(m)
	_check("③d' 무대 전제: 순서가 **관측 가능한 다른 세계**를 만든다(옛 순서 ≠ 집에서 잔 순서 — 같으면 ③e가 공허하다)",
		world_old != world_home)
	# 세계 B — 세 표를 얹고 귀가 프레임 하나로 소비한다(실제 경로).
	m.reclaim.load_save(snap)
	m._weed_pending_days = [night_a, season_day]
	m._season_respawn_pending_days = [season_day]
	m._tree_seed_pending_days = []
	await process_frame
	var world_carry := _yard_print(m)
	_check("③e **귀가 프레임의 판이 집에서 잔 판과 한 칸도 안 갈린다**(이월 손실 0 등가성) — 잡초 %d칸 · 재스폰 debris %d칸"
			% [m.reclaim.weed_count(), m.reclaim.respawned_debris_count()],
		world_carry == world_home)
	_check("③f 세 표가 전부 비었다(스킵 0) — 재스폰 %s · 잡초 %s · 파종 %s"
			% [str(m._season_respawn_pending_days), str(m._weed_pending_days),
				str(m._tree_seed_pending_days)],
		m._season_respawn_pending_days.is_empty() and m._weed_pending_days.is_empty()
			and m._tree_seed_pending_days.is_empty())
	# 세이브 왕복 — 형제 둘과 같은 계약.
	m._season_respawn_pending_days = [29, 57]
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	_check("③g 세이브가 밀린 절기를 **전부** 적는다 — %s" % str(raw.get("season_respawn_pending_days", [])),
		str(raw.get("season_respawn_pending_days", [])) == str([29, 57]))
	_check("③h 하위호환 — 구 키(스칼라 29)는 한 칸 표로 읽히고, 키가 없으면 빈 표다",
		str(m._pending_nights_from({"season_respawn_pending_day": 29},
			"season_respawn_pending_days", "season_respawn_pending_day")) == str([29])
			and m._pending_nights_from({}, "season_respawn_pending_days",
				"season_respawn_pending_day").is_empty())
	m._season_respawn_pending_days = []
	m.reclaim.load_save(snap)
	m._weather_sealed_days = sealed0

# ── ④ #7 밀린 밤의 잡초 파괴 보고가 한 줄로 합쳐진다 ────────────────────────
func _check_weed_notice_merge(m: Node) -> void:
	print("④ #7 잡초 파괴 알림 ↔ 밀린 밤 여럿")
	_check("④a 배선: 이월 루프는 **침묵 인자**로 부르고, 합계 두 줄은 루프 밖에 각 1회다",
		_count_in(_src, "func _process", "_run_weed_spread(night, false)") == 1
			and _count_in(_src, "func _process", "WEED_ATE_CROPS_NOTICE %") == 1
			and _count_in(_src, "func _process", "WEED_BROKE_SPRINKLERS_NOTICE %") == 1)
	_check("④a' 문구의 주인은 상수 하나다 — 아침 정산과 이월이 **같은 문자열**을 쓴다(복제 0)",
		_count_in(_src, "func _run_weed_spread", "WEED_ATE_CROPS_NOTICE %") == 1
			and _count_in(_src, "func _run_weed_spread", "WEED_BROKE_SPRINKLERS_NOTICE %") == 1)
	var snap: Dictionary = m.reclaim.to_save()
	var sealed0: Dictionary = m._weather_sealed_days.duplicate()
	var sources := _seed_crop_ring_stage(m, 48)
	_check("④b 무대: 잡초 소스 %d칸을 깔고 그 4방을 전부 작물로 채웠다(어느 방향으로 번져도 작물이 죽는다)"
			% sources, sources >= 12)
	if sources < 12:
		m.reclaim.load_save(snap)
		return
	# 침묵 계약 — 파괴가 실제로 벌어져도 announce=false면 큐가 안 자란다.
	m.notice_feed._items.clear()
	var silent_lost := 0
	var day_s := 2
	while silent_lost == 0 and day_s < 60:
		m._weather_sealed_days = {day_s: Weather.CALM}
		var r: Dictionary = m._run_weed_spread(day_s, false)
		silent_lost += int(r["crops"])
		day_s += 1
	_check("④c **침묵이 실효다** — 작물 %d포기가 실제로 사라졌는데 알림 큐는 %d줄(0)"
			% [silent_lost, m.notice_feed._items.size()],
		silent_lost > 0 and m.notice_feed._items.size() == 0)
	# 대조군 — 아침 정산(밤 하나)은 여전히 말한다.
	_seed_crop_ring_stage(m, 48)
	m.notice_feed._items.clear()
	var loud_lost := 0
	while loud_lost == 0 and day_s < 120:
		m._weather_sealed_days = {day_s: Weather.CALM}
		var r2: Dictionary = m._run_weed_spread(day_s, true)
		loud_lost += int(r2["crops"])
		day_s += 1
	_check("④c' 대조군: 아침 정산은 그대로 말한다 — 작물 %d포기 · 「%s」"
			% [loud_lost, m.WEED_ATE_CROPS_NOTICE % loud_lost],
		loud_lost > 0 and _notices_with(m, "잡초가 작물") == 1)
	# 실동작 — 세 밤을 밀린 표로 소비하면 그 줄이 **한 줄**이고 수치가 합계다.
	_seed_crop_ring_stage(m, 48)
	m._weather_sealed_days = {}
	for nd in [day_s, day_s + 1, day_s + 2]:
		m._weather_sealed_days[nd] = Weather.CALM
	m._weed_pending_days = [day_s, day_s + 1, day_s + 2]
	m._season_respawn_pending_days = []
	m._tree_seed_pending_days = []
	var planted_before: int = m.farm.planted_tiles().size()
	m.notice_feed._items.clear()
	await process_frame
	var lost_total: int = planted_before - m.farm.planted_tiles().size()
	var lines := _notices_with(m, "잡초가 작물")
	var merged_ok := lines <= 1
	if lost_total > 0:
		merged_ok = lines == 1 and _notice_texts(m).has(m.WEED_ATE_CROPS_NOTICE % lost_total)
	_check("④d 밀린 세 밤이 **한 줄**로 합쳐진다 — 사라진 작물 %d포기 · 「잡초가 작물」 줄 %d개(종전엔 밤마다 한 줄씩 최대 3줄)"
			% [lost_total, lines], lost_total >= 2 and merged_ok)
	_check("④e 그래서 상한 %d짜리 큐가 그 프레임의 다른 피드백을 안 밀어낸다 — 지금 큐 %d줄"
			% [NoticeFeed.MAX_ITEMS, m.notice_feed._items.size()],
		m.notice_feed._items.size() < NoticeFeed.MAX_ITEMS)
	m.reclaim.load_save(snap)
	m._weather_sealed_days = sealed0
	m._weed_pending_days = []
	m.notice_feed._items.clear()

# 잡초 소스 n칸 + 그 4방 작물이라는 무대를 깐다(반환 = 실제로 깐 소스 수).
# 좌표는 전부 `_encroach_candidates`(빈 맨땅)에서 판다 — 옮겨 적기 0.
func _seed_crop_ring_stage(m: Node, want: int) -> int:
	var cand: Dictionary = {}
	for c: Vector2i in m._encroach_candidates():
		cand[c] = true
	var used: Dictionary = {}
	var n := 0
	for c2: Vector2i in cand.keys():
		if n >= want:
			break
		if used.has(c2):
			continue
		var ring: Array = []
		var ok := true
		for dvec in Reclaim.SPREAD_DIRS:
			var nt: Vector2i = c2 + dvec
			if not cand.has(nt) or used.has(nt):
				ok = false
				break
			ring.append(nt)
		if not ok:
			continue
		used[c2] = true
		m.reclaim._weeds[c2] = true
		for rt: Vector2i in ring:
			used[rt] = true
			m.farm.hoe(rt)
			m.farm.plant(rt, CropCatalog.PIANHWA)
		n += 1
	return n

# ── ⑤ #6 방목 슬롯이 자체 파종목을 안 덮는다 ────────────────────────────────
func _check_pasture_tree(m: Node) -> void:
	print("⑤ #6 방목 슬롯 ↔ 런타임 나무 원장")
	# 좌표 근거는 상수·레이아웃에서 판다(옮겨 적기 0) — 마당 앵커의 자체 파종 반경이 방목지와 겹친다.
	var overlap: Array = []
	for a: Vector2i in m._home_tree_anchors():
		for dy in range(-TreeLedger.SEED_RADIUS, TreeLedger.SEED_RADIUS + 1):
			for dx in range(-TreeLedger.SEED_RADIUS, TreeLedger.SEED_RADIUS + 1):
				var t := a + Vector2i(dx, dy)
				if m.PASTURE_SCAN_RECT.has_point(t) and not overlap.has(t):
					overlap.append(t)
	_check("⑤a 무대: 마당 나무 앵커의 자체 파종 반경(체비쇼프 %d)이 방목지와 %d칸에서 겹친다(이 결함의 좌표 근거)"
			% [TreeLedger.SEED_RADIUS, overlap.size()], overlap.size() > 0)
	var free0: Array = m._free_pasture_tiles()
	var target := Vector2i(-1, -1)
	for t2: Vector2i in overlap:
		if free0.has(t2):
			target = t2
			break
	_check("⑤b 무대: 그 겹치는 칸 중 **지금 방목 슬롯인** 칸 %s을 찾았다(슬롯 %d개)"
			% [target, free0.size()], target.x >= 0)
	if target.x < 0:
		return
	# 원장에 직접 유목 한 그루를 놓는다(자체 파종이 밤에 하는 그 `_put` 그대로 — 좌표·단계만 고정).
	m.tree_ledger._put(RegionCatalog.HOME, target, {
		"species": TreeLedger.SP_PINE, "stage": 1, "hp": TreeLedger.hp_for_stage(1),
		"stump": false, "moss": false, "large": "", "gone": false})
	_check("⑤b' 무대 전제: 그 칸이 원장에서 «차 있다»로 읽힌다(=통행 불가·도끼 대상)",
		m.tree_ledger.is_occupied(RegionCatalog.HOME, target))
	var free1: Array = m._free_pasture_tiles()
	_check("⑤c **자체 파종목 칸이 슬롯에서 빠진다** — 슬롯 %d개 → %d개(그 칸 포함 %s)"
			% [free0.size(), free1.size(), str(free1.has(target))],
		not free1.has(target) and free1.size() == free0.size() - 1)
	_check("⑤d 형제 후보 함수도 **같은 규칙**을 든다 — 재점령 후보에도 그 칸이 없다(두 입구가 한 규칙)",
		not m._encroach_candidates().has(target))
	# 원장에서 빼면 그대로 돌아온다(영구 성역이 아니라 «나무가 선 동안만»).
	m.tree_ledger.clear_slot(RegionCatalog.HOME, target)
	_check("⑤e 나무가 사라지면 슬롯이 그대로 돌아온다 — 슬롯 %d개(배제가 영구 성역이 아니다)"
			% m._free_pasture_tiles().size(), m._free_pasture_tiles().has(target))

# ── ⑦ #9 조연 소프트 게이트가 «지나간 목격»을 영속 축에서 판다 ──────────────
func _check_chorus_gate_axis(m: Node) -> void:
	print("⑦ #9 조연 ♡3 소프트 게이트 ↔ 이혼 리셋")
	var probe := ""
	for rid in m.CHORUS_GATE_ROSTER:
		var rr: Resident = m._resident(String(rid))
		if rr != null and rr.affinity != null:
			probe = String(rid)
			break
	_check("⑦a 무대: 조연 로스터에서 레코드가 있는 사람 「%s」을 찾았다" % probe, probe != "")
	if probe == "":
		return
	var witness: String = String(m.CHORUS_GATE_MAINS[0])
	var wr: Resident = m._resident(witness)
	var saved_pts: int = wr.affinity.points
	var saved_stage: int = wr.affinity.stage
	var saved_bits: int = int(m._heart_bits.get(witness, 0))
	# 씨앗 컷신을 봤다 = 그 사람의 ♡3 관문을 지났다(진급이 비트를 찍는다).
	wr.affinity.stage = m.CHORUS_GATE_MAIN_STAGE
	for h in range(1, m.CHORUS_GATE_MAIN_STAGE + 1):
		m._mark_heart_bit(witness, h)
	_check("⑦a' 무대 전제: 증인 %s의 관문 %d이 라이브·원장 양쪽에 서 있다"
			% [witness, m.CHORUS_GATE_MAIN_STAGE],
		m._chorus_gate_ok(probe, m.CHORUS_GATE_HEART))
	# 이혼이 하는 그 한 줄을 그대로 때린다.
	wr.affinity.reset_hearts()
	_check("⑦b **이혼이 목격을 취소하지 않는다** — 라이브 칸은 %d로 떨어졌는데 게이트는 열려 있다"
			% wr.affinity.stage,
		wr.affinity.stage == 0 and m._chorus_gate_ok(probe, m.CHORUS_GATE_HEART))
	# 실동작 — 그 상태에서 조연 진급이 실제로 성사된다(발화·비트가 0이 아니다).
	var pr: Resident = m._resident(probe)
	var pr_pts: int = pr.affinity.points
	var pr_stage: int = pr.affinity.stage
	var pr_bits: int = int(m._heart_bits.get(probe, 0))
	pr.affinity.stage = m.CHORUS_GATE_HEART - 1
	pr.affinity.points = Affinity.MAX_POINTS
	var lines: PackedStringArray = m._try_heart_promotion(pr)
	_check("⑦c 그래서 조연 ♡%d 진급이 성사된다 — 칸 %d · 비트 %s(종전엔 빈 배열로 물러나 영구 «진급 대기»)"
			% [m.CHORUS_GATE_HEART, pr.affinity.stage,
				str(m._heart_bit_seen(probe, m.CHORUS_GATE_HEART))],
		pr.affinity.stage == m.CHORUS_GATE_HEART and m._heart_bit_seen(probe, m.CHORUS_GATE_HEART)
			and lines.size() > 0)
	# 공허 아님 — 증인이 애초에 없으면(칸도 비트도 0) 여전히 닫힌다.
	for w2 in m.CHORUS_GATE_MAINS:
		var r2: Resident = m._resident(String(w2))
		if r2 != null and r2.affinity != null:
			r2.affinity.stage = 0
		m._heart_bits.erase(String(w2))
	_check("⑦d 대조군: 증인이 **한 명도 없으면** 여전히 닫힌다(게이트가 사라진 게 아니다)",
		not m._chorus_gate_ok(probe, m.CHORUS_GATE_HEART))
	# 원복
	wr.affinity.points = saved_pts
	wr.affinity.stage = saved_stage
	if saved_bits != 0:
		m._heart_bits[witness] = saved_bits
	pr.affinity.points = pr_pts
	pr.affinity.stage = pr_stage
	if pr_bits != 0:
		m._heart_bits[probe] = pr_bits
	else:
		m._heart_bits.erase(probe)

# ── ⑥ #8 척추 B5 게이트가 «지나간 조각»을 영속 축에서 판다 ──────────────────
func _check_spine_gate_axis(m: Node) -> void:
	print("⑥ #8 척추 해결 게이트 ↔ 이혼 리셋")
	var bits0: Dictionary = m._heart_bits.duplicate()
	var spine0: int = m._spine_bits
	var region0: String = m._region
	# 게이트 세 항을 전부 채운다 — 메인 3인 ♡4(칸 + 관문 비트) · 조연 11인 ♡3 비트 · B4.
	for rid in Spine.MAIN_ROSTER:
		var r: Resident = m._resident(String(rid))
		if r != null and r.affinity != null:
			r.affinity.stage = Spine.MAIN_STAGE
		for h in range(1, Spine.MAIN_STAGE + 1):
			m._mark_heart_bit(String(rid), h)
	for rid2 in Spine.T1_ROSTER:
		m._mark_heart_bit(String(rid2), Spine.CHORUS_HEART)
	m._mark_spine_bit(m.SPINE_B4)
	_check("⑥a 무대: 세 항이 다 차 게이트가 열렸다(keys·void·chorus)", m._spine_gate_ok())
	m._rebuild_region(RegionCatalog.MIHOK_FOREST)
	var label_open := _label_with(m, "옥자 집")
	_check("⑥a' 그리기 경로: 미혹 숲 라벨이 열림을 말한다 — 「%s」" % label_open,
		label_open.contains("문이 열려 있다"))
	# 이혼이 하는 그 한 줄 — 배우자 칸이 0으로 떨어진다.
	var spouse: String = String(Spine.MAIN_ROSTER[0])
	var sr: Resident = m._resident(spouse)
	sr.affinity.reset_hearts()
	_check("⑥b 무대 전제: %s의 라이브 칸이 %d로 떨어졌다(관문 비트는 잔존 — 별도 축)"
			% [spouse, sr.affinity.stage],
		sr.affinity.stage == 0 and m._heart_bit_seen(spouse, Spine.MAIN_STAGE))
	_check("⑥c **이혼이 엔드게임 관문을 재잠금하지 않는다** — 게이트 keys 항 %s · 전체 %s"
			% [str(bool(Spine.gate_terms(m._spine_main_stages(), true, m._heart_bits)["keys"])),
				str(m._spine_gate_ok())],
		m._spine_gate_ok())
	m._rebuild_region(RegionCatalog.MIHOK_FOREST)
	var label_after := _label_with(m, "옥자 집")
	_check("⑥d 그리기 경로: 라벨도 안 되돌아간다 — 「%s」(종전엔 «잠김 — 미결의 죄 해결 후»로 되감겼다)"
			% label_after, label_after == label_open and not label_after.contains("잠김"))
	# 공허 아님 — 관문을 **애초에 안 지난** 사람이 있으면 여전히 닫힌다.
	m._heart_bits.erase(spouse)
	_check("⑥e 대조군: 그 사람의 관문 원장까지 비면 여전히 닫힌다(게이트가 사라진 게 아니다)",
		not m._spine_gate_ok())
	# 원복
	m._heart_bits = bits0
	m._spine_bits = spine0
	for rid3 in Spine.MAIN_ROSTER:
		var r3: Resident = m._resident(String(rid3))
		if r3 != null and r3.affinity != null:
			r3.affinity.stage = r3.affinity.points_hearts()
	m._rebuild_region(region0 if region0 != "" else RegionCatalog.HOME)
	m._indoor = ""

func _label_with(m: Node, needle: String) -> String:
	for lbl in m._labels:
		if String(lbl.text).contains(needle):
			return String(lbl.text)
	return ""

# ── ⑧ #10 앵커 관계 탭이 «잠김»을 말한다(자기모순 0) ────────────────────────
func _check_okja_effect_lock(m: Node) -> void:
	print("⑧ #10 앵커 효과 줄 ↔ 배우자 잠금")
	var spine0: int = m._spine_bits
	var spouse0: String = m._spouse_id
	m._mark_spine_bit(m.SPINE_B4)
	m._mark_spine_bit(m.SPINE_B5)
	m._mark_spine_bit(m.SPINE_B6)
	m._open_okja_track()            # 개통은 멱등
	var okja: Resident = m._resident(m.OKJA_RID)
	_check("⑧a 무대: 앵커 트랙이 열렸다(effect 줄 훅이 붙었다)",
		okja != null and okja.affinity != null and okja.effect_fn.is_valid())
	if okja == null or okja.affinity == null or not okja.effect_fn.is_valid():
		m._spine_bits = spine0
		return
	m._spouse_id = ""
	m._refresh_okja_track()
	var free_line := String(okja.effect_fn.call())
	_check("⑧b 미혼이면 효과 줄이 진행을 그대로 말한다(잠금 문구 없음) — ♡%d · 「%s」"
			% [okja.affinity.hearts(), free_line],
		not free_line.begins_with(m.OKJA_TRACK_LOCKED_PREFIX))
	# 곁에 다른 이가 있으면 트랙이 잠기고 ♡가 0으로 내려간다 — 효과 줄이 그 이유를 말해야 한다.
	m._spouse_id = String(Spine.MAIN_ROSTER[0])
	m._refresh_okja_track()
	var locked_line := String(okja.effect_fn.call())
	_check("⑧c **♡%d 옆에 «잠김»이 함께 선다** — 「%s」(종전엔 ♡0 옆에 진행 수치만 서서 한 행이 자기모순을 그렸다)"
			% [okja.affinity.hearts(), locked_line],
		okja.affinity.hearts() == 0 and locked_line.begins_with(m.OKJA_TRACK_LOCKED_PREFIX))
	# 그리기 경로 — 관계 탭 레이아웃이 그 줄을 실제로 들고, 말줄임에도 «잠김»이 살아남는다.
	var frame = m.frame
	_check("⑧d 무대: 관계 탭 프레임을 찾았다", frame != null)
	if frame != null:
		frame.context = InventoryFrame.CTX_MENU
		frame.menu_tab = InventoryFrame.TAB_REL
		frame.set_hearts(m._heart_rows())
		var idx := 0
		for r in m._residents:
			if r.affinity == null:
				continue
			if r.id == m.OKJA_RID:
				break
			idx += 1
		var drawn := ""
		var filled := -1
		for row in frame._rel_layout():
			if int(row["i"]) == idx:
				drawn = String(row["effect"])
		var rows: Array = m._heart_rows()
		if idx < rows.size():
			filled = int((rows[idx] as Dictionary)["filled"])
		_check("⑧d' 그리기 레이아웃(`_rel_layout`)이 그 줄을 든다 — ♡%d · 「%s」" % [filled, drawn],
			filled == 0 and drawn.begins_with(m.OKJA_TRACK_LOCKED_PREFIX))
		var panel: Rect2 = frame._panel_rect()
		var eff_max: float = panel.size.x - InventoryFrame.PAD * 2.0 - 12.0
		var shown := HanjiUi.elide(drawn, 12, eff_max)
		_check("⑧d'' 말줄임(폭 %.0fpx) 뒤에도 «잠김»이 남는다 — 「%s」" % [eff_max, shown],
			shown.contains("잠김"))
	# 잠금이 풀리면 문구도 걷힌다(진행은 그대로 — 잠금이 진행을 지우지 않는다).
	m._spouse_id = ""
	m._refresh_okja_track()
	var back_line := String(okja.effect_fn.call())
	_check("⑧e 곁이 비면 문구가 걷히고 진행이 그대로 돌아온다 — 「%s」" % back_line,
		not back_line.begins_with(m.OKJA_TRACK_LOCKED_PREFIX) and back_line == free_line)
	m._spouse_id = spouse0
	m._spine_bits = spine0
	m._refresh_okja_track()

# ── ⑨ #11 의뢰 완료 알림이 점수 천장을 본다 ────────────────────────────────
func _check_quest_affinity_notice(m: Node) -> void:
	print("⑨ #11 의뢰 완료 알림 ↔ 호감도 천장")
	_check("⑨a 배선: 형제 채널(선물)이 쓰는 **그 술어**를 그대로 탄다(판정 복제 0)",
		_count_in(_src, "func _try_deliver_quest", "is_gift_no_op(") == 1)
	var qb = m.quest_board
	var day: int = m.clock.day
	var q: Dictionary = qb.offer(day, QuestBoard.KIND_DAILY)
	_check("⑨a' 무대: 오늘의 일일 의뢰를 게시했다 — %s" % QuestBoard.summary(q), not q.is_empty())
	if q.is_empty():
		return
	var client := String(q["client"])
	var af = m._quest_client_affinity(client)
	if af == null:
		_check("⑨x 의뢰인 「%s」의 affinity 다리가 없다" % client, false)
		return
	var pts0: int = af.points
	var item_id := String(q["item_id"])
	var need := int(q["count"])
	# ㉠ 만충 상대 — 실효 0이므로 «이미 가득하다»를 말해야 한다.
	af.points = Affinity.MAX_POINTS
	qb.active = {}
	qb.completed = []
	qb.completed_total = 0
	qb.accept(q, day)
	m.inventory.add_item(item_id, need)
	m.notice_feed._items.clear()
	m._try_deliver_quest()
	var maxed_text := ""
	for t in _notice_texts(m):
		if t.begins_with("의뢰 완료"):
			maxed_text = t
	_check("⑨b **만충 상대에게 상승을 광고하지 않는다** — 「%s」(점수 %d → %d = 실효 0)"
			% [maxed_text, Affinity.MAX_POINTS, af.points],
		af.points == Affinity.MAX_POINTS and maxed_text.contains("호감도는 이미 가득하다")
			and not maxed_text.contains("호감도↑"))
	# ㉡ 대조군 — 실효가 있으면 종전 문구 그대로다(새 거짓말을 안 세운다).
	af.points = 0
	qb.active = {}
	qb.completed = []          # 같은 키를 한 번 더 쓰는 무대 — `offer`가 완료 이력을 보므로 먼저 비운다
	qb.completed_total = 0
	var q2: Dictionary = qb.offer(day, QuestBoard.KIND_DAILY)
	_check("⑨c' 무대: 대조군 의뢰를 다시 게시했다 — %s" % QuestBoard.summary(q2), not q2.is_empty())
	if q2.is_empty():
		return
	qb.accept(q2, day)
	m.inventory.add_item(String(q2["item_id"]), int(q2["count"]))
	m.notice_feed._items.clear()
	m._try_deliver_quest()
	var gain_text := ""
	for t2 in _notice_texts(m):
		if t2.begins_with("의뢰 완료"):
			gain_text = t2
	_check("⑨c 대조군: 실효가 있으면 종전 문구 그대로다 — 「%s」(점수 0 → %d)" % [gain_text, af.points],
		af.points > 0 and gain_text.contains("호감도↑")
			and not gain_text.contains("이미 가득하다"))
	_check("⑨d 납품 자체는 한 글자도 안 바뀐다 — 골드·차감은 종전 경로 그대로(알림만 갈렸다)",
		_count_in(_src, "func _try_deliver_quest", "af.add_points(int(done[\"affinity\"]))") == 1
			and _count_in(_src, "func _try_deliver_quest", "wallet.earn(gold)") == 1)
	af.points = pts0
	qb.active = {}
	m.notice_feed._items.clear()

# ── ⑩ #12 구세이브 stage 소급이 관문 비트 원장을 함께 낳는다 ────────────────
func _check_old_save_heart_bits(m: Node) -> void:
	print("⑩ #12 구세이브 stage 소급 ↔ 관문 비트 원장")
	var rid := String(Spine.MAIN_ROSTER[0])
	var r: Resident = m._resident(rid)
	if r == null or r.affinity == null:
		_check("⑩x 무대 없음(%s 레코드)" % rid, false)
		return
	_check("⑩a 배선: 소급은 **키가 아예 없을 때만**·`ROMANCE_OPEN`에만 건다(원장이 실려 있으면 그것이 진실원 · 앵커는 대상 밖)",
		_count_in(_src, "func _load_game", "if not data.has(\"heart_bits\"):") == 1
			and _count_in(_src, "func _load_game", "for rid in ROMANCE_OPEN:") == 1
			and not m.ROMANCE_OPEN.has(m.OKJA_RID))
	# 관문 도입 전 세이브 = stage 키가 없고 heart_bits도 없다. 점수만 있는 그 파일을 만든다.
	var want_stage := 3
	r.affinity.points = 0
	r.affinity.stage = 0
	m._heart_bits.erase(rid)
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	var aff: Dictionary = raw.get(r.save_key, {})
	# 옛 파생식이 want_stage를 내는 점수를 판에서 판다(문턱 수치를 옮겨 적지 않는다).
	var probe := Affinity.new()
	var pts := 0
	for p in range(0, Affinity.MAX_POINTS + 1):
		probe.points = p
		if probe.points_hearts() >= want_stage:
			pts = p
			break
	probe.free()
	aff["points"] = pts
	aff.erase("stage")
	raw[r.save_key] = aff
	raw.erase("heart_bits")
	m.saver.save_game(raw, m._active_slot)
	var ok: bool = m._load_game()
	_check("⑩a' 무대: 그 구세이브가 읽히고 points %d가 stage %d로 소급됐다(affinity.gd의 그 기본값)"
			% [pts, r.affinity.stage],
		ok and pts > 0 and r.affinity.stage == want_stage)
	var bits_ok := true
	for h in range(1, want_stage + 1):
		if not m._heart_bit_seen(rid, h):
			bits_ok = false
	_check("⑩b **비트 원장도 함께 선다** — 관문 1..%d %s(종전엔 전부 0이라 어떤 경로로도 다시 설 수 없었다)"
			% [want_stage, str(bits_ok)], bits_ok)
	_check("⑩b' 소급은 «지나온 칸까지»다 — 아직 안 지난 관문 %d은 안 선다(과잉 소급 0)"
			% (want_stage + 1), not m._heart_bit_seen(rid, want_stage + 1))
	# 그래서 남은 관문만 지나면 아크가 닫힌다(청혼이 영구 거절되지 않는다).
	_check("⑩c 무대 전제: 아직은 아크가 안 닫혔다(관문 %d이 남았다)" % m.HEART_GATE_MAX,
		not m._redemption_arc_complete(rid))
	for h2 in range(want_stage + 1, m.HEART_GATE_MAX + 1):
		m._mark_heart_bit(rid, h2)
	_check("⑩c' **남은 관문을 지나면 아크가 닫힌다** — `_redemption_arc_complete(%s)` = %s(종전엔 1~3이 영영 0이라 영구 거절)"
			% [rid, str(m._redemption_arc_complete(rid))], m._redemption_arc_complete(rid))
	# 공허 아님 — 칸이 0인 사람은 소급도 0이다.
	var zero_rid := ""
	for rid2 in m.ROMANCE_OPEN:
		var r2: Resident = m._resident(String(rid2))
		if r2 != null and r2.affinity != null and r2.affinity.stage == 0:
			zero_rid = String(rid2)
			break
	_check("⑩d 대조군: 칸이 0인 사람(%s)은 비트도 0이다(소급이 무조건이 아니다)" % zero_rid,
		zero_rid != "" and int(m._heart_bits.get(zero_rid, 0)) == 0)
	# 원장이 실린 세이브는 **한 톨도 안 보탠다** — 소급이 잘 형성된 파일의 권위를 안 덮는다.
	var rid2: String = String(Spine.MAIN_ROSTER[1])
	var r2b: Resident = m._resident(rid2)
	r2b.affinity.stage = m.HEART_GATE_MAX
	m._heart_bits[rid2] = 0
	m._save_game()
	var ok2: bool = m._load_game()
	_check("⑩e 원장이 실린 세이브는 소급을 안 받는다 — %s의 칸 %d인데 비트 %d(파일이 진실원)"
			% [rid2, r2b.affinity.stage, int(m._heart_bits.get(rid2, 0))],
		ok2 and int(m._heart_bits.get(rid2, 0)) == 0 and r2b.affinity.stage == m.HEART_GATE_MAX)
