extends SceneTree
# ★[폴리시 23회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#12).
#
# 렌즈: R22 diff 리뷰(#0·#1·#2·#3) · 굳은 값 ↔ 라이브 드리프트(#4·#5) · 신규 세이브 정적 상태
#       스윕(#6) · 곱셈기 적층 감사(#7·#8·#9) · 지급 창구 정합(#10·#11·#12).
#
# 이 배치의 태도 셋.
#   ㉠ **형제 창구가 판정의 자[尺]다.** 열세 건 중 아홉이 "같은 일을 하는 형제가 저장소 안에 이미
#      있고, 그 형제만 규율을 지킨다"는 꼴이다 — 수확 4창구 중 과수만 점수판을 안 올리고(#10),
#      매출 4창구 중 낮 서빙만 멜 하트를 올리며(#11), 더블드랍 4창구 중 덤불만 XP가 수량 파생이고
#      (#7), 예산 두 밭 중 여우불만 각각 전액을 쓴다(#9). 그래서 단언도 «형제와 같아졌는가»를
#      잰다(형제 목록은 코드에서 파생 — 이름을 손으로 안 적는다).
#   ㉡ **파괴 지점 ≠ 봉합 지점.** #0은 R22 #3이 판정을 넓히면서 그 입력(pending)을 안 넓힌 자리라
#      «판정»이 아니라 «입력»을 잰다. 그래서 ①은 `_would_entrap_player`가 아니라
#      `_tree_seed_pending_solid`의 원소를 직접 센다 — 4방 밖 칸 하나가 곧 red-catcher다.
#   ㉢ **좌표·수치를 옮겨 적지 않는다.** ①의 원장 칸은 `tree_ledger.tiles()`에서, ③의 평온한 날은
#      판을 훑어서, ⑤의 책 갈래가 서는 day도 훑어서, ⑫의 증정 무기는 `WeaponCatalog`의 price 0
#      술어에서 판다.
#
# 무엇을 보증하나(번호 = 23회차 헌트 발견 인덱스).
#   ① #0 `_tree_seed_pending_solid`가 **플레이어 4방 네 칸만** 담아, 폭 우선(반경 12)으로 넓어진
#      `_would_entrap_player`의 pending이 미달했다 — 같은 아침 패스에서 먼저 승인된 씨앗이 열린
#      칸으로 세어져 발밑이 봉해졌다(R20 #2가 닫은 «순차 재평가» 사각의 재개방).
#   ② #1 `regrown` 표식이 되감기 사이클 내내 남는데 `fertilize`는 다른 id면 true를 내, 성장촉진군
#      비료가 **소모만 되고 아무 일도 안 하는** 침묵 실패였다(임계는 봉인·품질은 STATE_NONE).
#   ③ #2·#5 밀린 아침 방목 방출만 «굳은 하늘»이 아니라 **낮의 하늘**을 다시 팠다 — 테마 해금이
#      낮에 뒤집히면 같은 아침이 «잿눈인 밤»(잡초)과 «평온한 날»(방목) 두 세계로 갈려 결산됐다.
#   ④ #3 `_pot_harvest_yield`의 «한 프레임 양보»가 백팩 만재에서 무기한 양보가 되어, 주민 상주
#      칸의 화분 앞에서 동행 혼·배우자 대화가 통째로 봉쇄됐다(수확 창구가 원장을 안 비운다).
#   ⑤ #4 보부상 희귀 슬롯의 책 갈래가 뽑기 분모를 **라이브 Books 원장**에서 파, 낮에 다른 경로로
#      책을 한 권 주우면 아침에 본 귀물이 갈아 끼워졌다(거꾸로 재굴림 수단이기도 했다).
#   ⑥ #6 주민 호감도만 `data.has(save_key)` 가드가 남아, 키 없는 세이브를 F9로 읽으면 버린
#      타임라인의 ♡가 살아남고 형제인 `_heart_bits`만 되감겼다.
#   ⑦ #7 채집꾼 퍼크(수량 ×2)가 덤불 **채집 XP까지** 2배로 밀어, 비-가치 퍼크가 스킬 곡선을
#      가속했다(형제 3창구는 전부 고정 XP · `mining_skill`은 같은 경계를 명시로 지킨다).
#   ⑧ #8 멜 활동→하트 채널이 «멜 마진이 이미 곱해진» 매출을 눈금으로 써, 곱셈기가 자기 입력을
#      가속하는 폐루프였다(♡5면 같은 서빙이 하트를 정확히 2배로 준다).
#   ⑨ #11 밤 응대·칵테일·체키 매출이 `_credit_mel_revenue`를 안 타, 같은 매출이 멜 deed 관문은
#      통과시키면서 활동 하트 채널엔 한 점도 안 넣었다.
#   ⑩ #9 여우불 «범위»(하루 칸 수 예산)가 노지·늘봄방 두 밭에 각각 전액 적용돼 예산이 2배가 됐다
#      (같은 함수 안 형제인 배우자 물주기는 한 몫을 나눠 쓴다).
#   ⑪ #10 과수 수확만 `_count_run_harvest()` 누락 — 미호 관문 deed·카페 사다리·앵커 deed에 0 기여.
#   ⑫ #12 휴지통 폐기 차단 표가 «매대 가격 0인 증정품» 중 낚싯대만 덮어, 녹슨 혼검은 버리면
#      영구 소실이었다(유일 지급처가 세이브 영속 플래그 · 매대 재구매 불가).
#
# 판정: #0·#1·#2·#3·#4·#6·#7·#8·#9·#10·#11·#12 CONFIRMED(전부 봉합) · #5 = **DUP**(#2와 동뿌리 —
#   같은 한 줄이 두 렌즈에 잡혔다. #5가 덧붙인 «집에서 맞은 아침은 방출 0 + 재시도 훅 없음»
#   비대칭도 같은 봉합으로 닫힌다: 두 경로가 이제 한 하늘을 본다). REFUTED·OWNER-DECISION 0건.
#
# 봉합 축(근거 전문은 커밋 본문·각 함수 머리말):
#   · #0 = 차집합의 범위를 **원장 전체**로(비용은 HOME_CAP에 묶인다 — `tiles()`가 그 구역만 준다).
#   · #1 = `fertilize`가 «두 축 다 무효»인 도포를 거절하고(아이템 불변) main이 사유를 말한다.
#   · #2·#5 = `_release_open_buildings(sealed_day)` — 하루 경계 소비처 둘은 굳은 하늘, 문 토글은 지금 하늘.
#   · #3 = 양보 술어가 **적재 자리까지** 묻는다(`_pot_harvest_room` — 수확 창구의 그 판정 그대로).
#   · #4 = `remaining_books(owned, day)` — `Books.acquired`가 이미 든 «주운 day»에서 그 아침을 파생한다
#          (새 세이브 키 0 · F9 왕복도 자동으로 옳다).
#   · #6 = `has` 가드 철거 + `data.get(key, {})`(R13 판별식 "부팅으로 시드되는가"의 마지막 전파).
#   · #7 = XP의 자[尺]를 **퍼크 곱 전의 수량**(`base_n`)으로.
#   · #8 = `_unmargined_revenue` — 멜 자신의 마진만 벗긴다(테마·메뉴·체키 등급은 그대로 탄다).
#   · #9·#11 = 형제 매출 창구 셋에 `_credit_mel_revenue` 한 줄씩(밤 축은 마진이 없어 안 벗긴다).
#   · #10 = `FarmField.advance_day`가 쓴 칸 수를 돌려주고, 늘봄방은 **남은 몫**만 받는다.
#   · #12 = 표에 «매대 가격 0인 무기» 항 하나(id 복제 0 — 값이 붙으면 저절로 풀린다).
#
# 하중 검증(**실측** — 봉합을 되돌려 실제로 뜬 red를 그대로 옮겨 적는다. 파괴 4배치·전건 확인):
#   #0 원장 순회를 4방 루프로 복귀          → ①c·①f red(pending 1칸 → **0칸** = 2칸 밖 «곧 설 SOLID»가 빠진다)
#   #1 `fertilize`의 거절 가지 삭제          → ②d·②e·②g red(비료가 fert_hyper로 갈리고 2개 → **1개**로 태워진다)
#   #1 main의 사유 알림 삭제                 → ②f red(거절만 하고 화면은 침묵)
#   #2 `sealed_day` 갈래 삭제(라이브 복귀)    → ③c·③d red(굳은 잿눈 아침에 **4마리가 방목지로 나간다**)
#   #3 `_pot_harvest_room` 항 삭제           → ④d red(만재에서 양보가 안 접혀 대화가 영영 안 돌아온다)
#   #4 `remaining_books`의 day 항 삭제        → ⑤d·⑤e red(같은 날 오후 귀물이 book_okja_1 → **book_okja_4**로 갈린다)
#   #6 `has` 가드 복귀                        → ⑥d·⑥e red(버린 타임라인의 ♡5·points 300이 살아남는다)
#   #7 XP 자[尺]를 `n`으로 복귀               → ⑦d red(3 XP → **6 XP** = 퍼크가 스킬 곡선을 2배로 민다)
#   #8 `_unmargined_revenue` 벗기기 삭제      → ⑧b red(♡5 눈금 35 → **70** = ♡0의 정확히 2배)
#   #9 `FarmField.advance_day` 반환 삭제      → ⑩c·⑩d·⑩e red(**자란 칸이 노지 5 + 늘봄방 5 = 10칸** = 예산 2배)
#   #9 늘봄방 인자를 전액으로 복귀            → ⑩f red(배선)
#   #11 세 창구의 크레딧 삭제                 → ⑨a·⑨b·⑨c red
#   #10 과수 갈래의 `_count_run_harvest` 삭제 → ⑪c·⑪d red(수확이 집행됐는데 점수판은 0에 머문다)
#   #12 무기 항 삭제                          → ⑫b·⑫c red(녹슨 혼검이 0자루 = 그대로 버려진다)
#
# ★하중 검증에서 배운 것 둘.
#   · **⑩의 진짜 red-catcher는 «반환 계약»이지 «main 배선»이 아니다.** 예산 분할은 두 조각으로
#     이뤄지는데(field가 쓴 몫을 돌려주고 · main이 남은 몫만 넘긴다) 거동 단언(⑩c~⑩e)은 앞쪽
#     조각에만 하중이 걸린다 — 뒤쪽은 `_on_day_advanced` 한 판을 통째로 굴려야 재므로 배선
#     단언(⑩f)이 그 몫을 든다. 두 항을 나란히 두는 이유가 R22 ⑧e/⑧f와 같다(거동과 배선은
#     서로를 못 대신한다). 반환을 0으로 죽였을 때 **⑩e가 «노지 5 + 늘봄방 5 = 10칸»** 을 실측한
#     것이 이 결함의 실체 그 자체다.
#   · **②g는 ②d의 중복이 아니다.** ②d는 «field가 거절하는가»를, ②g는 «호출부가 그 false로 실제로
#     차감을 멈추는가»를 잰다 — 결함의 손해는 임계가 아니라 **사라진 100냥**이라, 거절 술어만
#     초록이고 차감이 살아 있으면 아무것도 안 고친 것이 된다.
#
# 실행: ./run_tests.sh polish_r23   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _src: PackedStringArray = PackedStringArray()

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

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

# ── 소스 스캔 헬퍼(polish_r7~r22 관례 — 니들은 반드시 함수 안에서 센다) ──────
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _count_in_func(lines: PackedStringArray, fn_needle: String, needle: String) -> int:
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

# 그 함수 **안**에서 니들이 처음 나오는 행 번호(1-based · -1 = 없음). 순서 단언의 창구다.
func _line_of(lines: PackedStringArray, fn_needle: String, needle: String) -> int:
	var head := -1
	for i in range(lines.size()):
		if lines[i].begins_with(fn_needle):
			head = i
			break
	if head < 0:
		return -1
	for i in range(head + 1, lines.size()):
		if lines[i].begins_with("func ") or lines[i].begins_with("static func "):
			return -1
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			return i + 1
	return -1

func _feed_has(m: Node, needle: String) -> bool:
	if m.notice_feed == null:
		return false
	for e in m.notice_feed._items:
		if String(e.get("text", "")).contains(needle):
			return true
	return false

func _feed_clear(m: Node) -> void:
	if m.notice_feed != null:
		m.notice_feed._items.clear()

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
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R23 회귀 — 배치 A(#0~#12) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_check("무대 전제: main(%d행)을 읽었다(부정 단언 공허 통과 방지)" % _src.size(), _src.size() > 1000)

	_check_regrow_fertilize()       # ② 앞절 — 순수 FarmField(무대 불요)
	_check_foxfire_budget()         # ⑩ — 순수 FarmField 둘
	_check_peddler_book_pool()      # ⑤ — 순수 static
	_check_unmargined_scale()       # ⑧ — 순수 Cafe(무대 불요)

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)

	_check_seed_pending_range(m)    # ①
	_check_fertilize_notice(m)      # ② 뒷절(거절 + 사유)
	_check_pot_yield_room(m)        # ④
	_check_bush_xp(m)               # ⑦
	_check_mel_windows(m)           # ⑨
	_check_orchard_scoreboard(m)    # ⑪
	_check_trash_gift_weapon(m)     # ⑫
	_check_pasture_sealed_sky(m)    # ③ — 짐승 위치를 갈아 두므로 뒤쪽
	await _check_resident_affinity_rewind(m)   # ⑥ — 세이브 파일을 갈아 두므로 맨 끝

	print("══ 폴리시 R23 회귀 — 배치 B(#13~#25) ══")
	_check_notice_wrap(m)           # ⑬ #14
	_check_prompt_fit(m)            # ⑭ #15·#16
	_check_popup_layout(m)          # ⑮ #17·#18
	_check_tree_installation(m)     # ⑯ #19
	_check_sprinkler_resident(m)    # ⑰ #20
	_check_refill_session(m)        # ⑱ #21
	_check_pasture_trunk(m)         # ⑲ #22
	_check_onboarding_seed(m)       # ⑳ #23
	_check_banner_resume(m)         # ㉑ #24
	await _check_intro_clock(m)     # ㉒ #25 — 통보를 열고 닫으므로 맨 끝

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 자체 파종 pending = 원장 전체 차집합 ────────────────────────────────
# 좌표를 한 톨도 안 적는다: 원장 칸은 `tree_ledger.tiles()`에서, 앵커는 `_home_tree_anchors()`에서
# 판다. 무대는 «원장에 점유돼 있는데 물리엔 아직 안 선 칸»을 실제 경합 그대로 만든다 —
# `_prop_blocked_tiles`에서 그 칸을 잠시 지우면 그것이 곧 «패스 중간의 아침»이다.
func _check_seed_pending_range(m: Node) -> void:
	print("① #0 자체 파종 pending 범위 ↔ 매몰 판정 반경")
	if m.tree_ledger == null:
		_check("①x 무대 없음(tree_ledger null)", false)
		return
	var anchors: Dictionary = m._home_tree_anchor_set()
	# 무대 = **자체 파종 패스의 중간**을 그대로 재현한다: `_seed_pass`가 승인한 씨앗은 `_put`으로
	#   원장에 곧장 서지만(`is_occupied` 참) 충돌 재구성은 패스가 **끝난 뒤 한 번**이라
	#   `_prop_blocked_tiles`엔 아직 없다. 그래서 원장에만 한 그루를 심고 물리 원장은 안 건드린다
	#   (`changed`도 안 쏜다 — 쏘면 재구성이 돌아 그 중간 상태가 사라진다).
	var here: Vector2i = m._player_tile()
	var subject := Vector2i(-1, -1)
	for dist in range(2, 6):
		var cand: Vector2i = here + Vector2i(dist, dist)
		if not m.tree_ledger.has_slot(RegionCatalog.HOME, cand) and not anchors.has(cand):
			subject = cand
			break
	_check("①a 무대: 원장 슬롯이 없는 빈 칸 %s를 잡았다(앵커 %d개는 별도 축)"
			% [str(subject), anchors.size()],
		subject != Vector2i(-1, -1) and not anchors.is_empty())
	if subject == Vector2i(-1, -1):
		return
	var cheb: int = maxi(absi(here.x - subject.x), absi(here.y - subject.y))
	_check("①b 무대: 플레이어 %s ↔ 대상 %s 체비셰프 거리 %d ≥ 2 (종전 4방 루프의 사각)"
			% [str(here), str(subject), cheb], cheb >= 2)
	var pending_before: Dictionary = m._tree_seed_pending_solid()
	m.tree_ledger._trees[RegionCatalog.HOME][subject] = {
		"species": "", "stage": 1, "hp": 1, "stump": false, "moss": false}
	_check("①b' 무대: 그 칸이 «원장 점유 ∧ 물리 미등재»가 됐다(= 패스 중간의 씨앗 S1)",
		m.tree_ledger.is_occupied(RegionCatalog.HOME, subject)
			and not m._prop_blocked_tiles.has(subject))
	var pending: Dictionary = m._tree_seed_pending_solid()
	_check("①c 4방 밖 «곧 설 SOLID» %s가 pending에 든다 — pending %d칸 (R20 #2의 순차 재평가가 반경 12에서도 성립)"
			% [str(subject), pending.size()], pending.has(subject))
	# 앵커는 여전히 예외다(R22 #1 계약 보존 — 캐노피 칸은 의도적 통행 가능).
	var occupied_anchor := Vector2i(-1, -1)
	for a in m._home_tree_anchors():
		var at: Vector2i = a
		if m.tree_ledger.is_occupied(RegionCatalog.HOME, at) and not m._prop_blocked_tiles.has(at):
			occupied_anchor = at
			break
	_check("①d 손저작 앵커 %s는 «점유 ∧ 물리 미등재»인데도 pending에서 빠진다(R22 #1 계약 불변)"
			% str(occupied_anchor),
		occupied_anchor != Vector2i(-1, -1) and not pending.has(occupied_anchor))
	# 공허 통과 방지 — 원장 밖 칸은 절대 안 든다.
	var outsider := subject + Vector2i(0, 3)
	_check("①e 원장에 없는 칸 %s는 pending에 안 든다(모든 칸이 pending인 공허 통과가 아니다)"
			% str(outsider),
		not m.tree_ledger.is_occupied(RegionCatalog.HOME, outsider) and not pending.has(outsider))
	# 늘어난 것이 **그 한 칸뿐**이다 — 차집합이 원장 전체를 훑으면서도 앵커·물리 등재분을 그대로
	# 걸러 내는지(넓히기가 곧 «전부 pending»이 아닌지)를 구성으로 잰다.
	_check("①f 늘어난 pending이 정확히 그 한 칸이다 — %d칸 → %d칸(앵커·물리 등재분은 그대로 걸러진다)"
			% [pending_before.size(), pending.size()],
		pending.size() == pending_before.size() + 1 and not pending_before.has(subject))
	m.tree_ledger._trees[RegionCatalog.HOME].erase(subject)   # 무대 원복

# ── ② #1 되감기 사이클에서 성장촉진 비료 = 정직한 거절 ───────────────────────
# 앞절은 순수 FarmField로 잰다(무대 불요). 수치는 전부 카탈로그에서 판다.
func _check_regrow_fertilize() -> void:
	print("② #1 되감기 사이클 ↔ 성장촉진 비료(FarmField 순수)")
	var f := FarmField.new()
	var t := Vector2i(3, 3)
	var crop := CropCatalog.BULSAGWA
	var base := CropCatalog.growth_days(crop)
	var cd := CropCatalog.regrow_cooldown(crop)
	f.hoe(t)
	f.plant(t, crop)
	_check("②a 무대: 「%s」는 REGROW(base %d일 · cd %d일)이고 무비료로 심었다"
			% [ItemCatalog.name_of(ItemCatalog.harvest_id(crop)), base, cd],
		CropCatalog.growth_mode(crop) == "REGROW" and base > 0 and cd > 0
			and f.effective_growth_days(t) == base)
	# 첫 사이클: 성장촉진이 그대로 통과한다(거동 불변 — 거절 범위가 넓지 않다).
	var first_ok: bool = f.fertilize(t, FertilizerCatalog.FERT_SPEED)
	var need_after_speed: int = f.effective_growth_days(t)
	_check("②b 첫 사이클엔 성장촉진이 통과한다 — 임계 %d → %d (봉합이 정상 경로를 안 막는다)"
			% [base, need_after_speed], first_ok and need_after_speed < base)
	# 성숙시켜 수확 → 되감기 사이클 진입.
	for _i in range(base + 2):
		f.water(t)
		f.advance_day()
	_check("②c 무대: 성숙 후 수확으로 되감기 사이클에 들었다(넝쿨 보존)",
		f.harvest(t) == crop and f.is_planted(t))
	var need_before: int = f.effective_growth_days(t)
	var no_op: bool = f.fertilize_sealed_no_op(t, FertilizerCatalog.FERT_HYPER)
	var applied: bool = f.fertilize(t, FertilizerCatalog.FERT_HYPER)
	_check("②d 되감기 칸의 하이퍼 도포가 **거절된다**(술어 %s · 반환 %s) — 호출부가 이 false로 차감을 멈춘다"
			% [str(no_op), str(applied)], no_op and not applied)
	_check("②e 거절이라 칸이 한 톨도 안 바뀐다 — 비료 「%s」 · 임계 %d(도포 전 %d)"
			% [f.fertilizer_of(t), f.effective_growth_days(t), need_before],
		f.fertilizer_of(t) == FertilizerCatalog.FERT_SPEED
			and f.effective_growth_days(t) == need_before)
	# 품질군은 되감기 칸에서도 통과한다(그쪽은 실효하므로 거절할 이유가 없다).
	_check("②e' 같은 칸에서 품질군(디럭스)은 통과한다 — 거절은 «두 축 다 무효»일 때만이다",
		not f.fertilize_sealed_no_op(t, FertilizerCatalog.FERT_DELUXE)
			and f.fertilize(t, FertilizerCatalog.FERT_DELUXE))
	_check("②e'' 그 통과가 임계를 안 건드린다(R22 #2 봉인 계약 불변) — 임계 %d"
			% f.effective_growth_days(t), f.effective_growth_days(t) == need_before)
	f.free()

# ② 뒷절 — main 배선: 거절에는 사유가 붙고, 아이템은 안 준다.
func _check_fertilize_notice(m: Node) -> void:
	print("② #1 뒷절 — 거절 사유 알림 ↔ 아이템 불변(main 배선)")
	var t := Vector2i(-1, -1)
	for tile in m.farm.tilled_tiles():
		t = tile
		break
	if t == Vector2i(-1, -1):
		t = m._player_tile()
		m.farm.hoe(t)
	var crop := CropCatalog.HWANGCHEON_PODO
	m.farm.hoe(t)
	m.farm.plant(t, crop)
	for _i in range(CropCatalog.growth_days(crop) + 2):
		m.farm.water(t)
		m.farm.advance_day()
	m.farm.harvest(t)
	_clear_backpack(m)
	m.inventory.add_item(FertilizerCatalog.FERT_HYPER, 2)
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == FertilizerCatalog.FERT_HYPER:
			m.inventory.select(i)
			break
	m._target = t
	m._region = RegionCatalog.HOME
	m._indoor = ""
	var held0: int = m.inventory.count_of(FertilizerCatalog.FERT_HYPER)
	_feed_clear(m)
	m._use_tool()
	_check("②f 거절 사유가 화면에 뜬다 — «이미 열매를 낸 포기엔 듣지 않는다»(집행 0인데 소모만 되던 침묵의 반대편)",
		_feed_has(m, "이미 열매를 낸 포기엔 듣지 않는다"))
	_check("②g 하이퍼 비료가 %d개 그대로다(차감 0 — 거절은 아이템을 안 태운다)"
			% m.inventory.count_of(FertilizerCatalog.FERT_HYPER),
		m.inventory.count_of(FertilizerCatalog.FERT_HYPER) == held0 and held0 > 0)
	m.farm.untill(t)

# ── ③ #2·#5 밀린 방목 방출 = 그 아침에 굳은 하늘 ────────────────────────────
func _check_pasture_sealed_sky(m: Node) -> void:
	print("③ #2·#5 밀린 방목 방출 ↔ 굳은 하늘")
	if m.ranch == null:
		_check("③x 무대 없음(ranch null)", false)
		return
	m._region = RegionCatalog.HOME
	m._indoor = ""
	m._rebuild_region(RegionCatalog.HOME)
	# **라이브 하늘이 평온한 날**을 판에서 찾는다(수치·날짜 복제 0).
	var calm_day: int = -1
	for d in range(m.clock.day, m.clock.day + 60):
		if Weather.allows_grazing(m._weather_on(d)):
			calm_day = d
			break
	if calm_day < 0:
		_check("③x 무대 없음(60일 안에 평온한 날이 없다)", false)
		return
	m.clock.day = calm_day
	m.clock.minutes = 10 * 60          # 낮(밤 게이트 회피)
	for b in m.ANIMAL_BUILDINGS:
		m.ranch.set_door(b, true)
	for tile in m.ranch._animals.keys():
		var a: Dictionary = m.ranch._animals[tile]
		a["location"] = Ranch.LOC_INDOOR
		a["grazed"] = false
		a.erase("pasture_tile")
	# 그 아침의 하늘만 **잿눈으로 굳힌다** = 미해금 테마 슬롯 아침의 재현.
	m._weather_sealed_day = calm_day
	m._weather_sealed = Weather.SNOW
	_check("③a 무대: 짐승 %d마리가 문 열린 실내에 있고 낮이다(방출 게이트 중 날씨만 남는다)"
			% m.ranch.releasable().size(),
		m.ranch.releasable().size() >= 1 and m.clock.phase() != "밤"
			and m.ranch.occupied_pasture_tiles().is_empty()
			and not m._free_pasture_tiles().is_empty())
	_check("③b 무대: 두 하늘이 실제로 갈린다 — 굳은 값 「%s」(방목 %s) ↔ 라이브 「%s」(방목 %s)"
			% [Weather.NAMES[m._weather_sealed_on(calm_day)],
				str(Weather.allows_grazing(m._weather_sealed_on(calm_day))),
				Weather.NAMES[m._weather_today()], str(m._weather_calm())],
		not Weather.allows_grazing(m._weather_sealed_on(calm_day)) and m._weather_calm())
	_check("③c 밀린 소비처가 **굳은 하늘**을 본다 — 방출 0(잿눈 아침의 몫은 잿눈으로 결산된다)",
		not m._release_open_buildings(calm_day))
	_check("③d 짐승이 한 마리도 안 나갔다(방목지 점유 %d칸 · grazed 표 0)"
			% m.ranch.occupied_pasture_tiles().size(),
		m.ranch.occupied_pasture_tiles().is_empty())
	# 대조군: 문 토글(지금 이 프레임의 동작)은 여전히 라이브 하늘을 본다 → 나간다.
	_check("③e 대조군 — 문 토글 경로(인자 없음)는 지금의 하늘을 봐 방출이 선다(게이트가 날씨 축 하나뿐임의 증거)",
		m._release_open_buildings())
	_check("③f 그때는 실제로 나갔다 — 방목지 점유 %d칸"
			% m.ranch.occupied_pasture_tiles().size(),
		not m.ranch.occupied_pasture_tiles().is_empty())
	_check("③g 배선: 밀린 표 소비처가 인자를 넘긴다(형제 둘이 R22에서 받은 그 창구)",
		_count_in_func(_src, "func _process", "_release_open_buildings(clock.day") >= 1)
	m._weather_sealed_day = 0

# ── ④ #3 화분 양보 ↔ 적재 자리 ───────────────────────────────────────────────
func _check_pot_yield_room(m: Node) -> void:
	print("④ #3 화분 «한 프레임 양보» ↔ 백팩 자리")
	if m.garden_pot == null:
		_check("④x 무대 없음(garden_pot null)", false)
		return
	var soul: Vector2i = m.SOUL_CHILD_TILE
	var crop := CropCatalog.HWANGCHEON_PODO
	m.garden_pot.remove(soul)
	m.garden_pot.place(soul)
	m.garden_pot.plant(soul, crop)
	m.garden_pot._pots[soul]["grown_days"] = CropCatalog.growth_days(crop)
	m._region = RegionCatalog.HOME
	m._indoor = "집"
	_clear_backpack(m)
	_check("④a 무대: 주민 상주 칸 %s에 다 자란 화분이 서 있다(R22 #7이 양보를 세운 그 자리)"
			% str(soul),
		m.garden_pot.is_mature(soul) and m._resident_tile(soul))
	_check("④b 자리가 있으면 양보가 선다 — RMB가 화분 수확으로 간다(R22 #7 계약 불변)",
		m._pot_harvest_room(soul) and m._pot_harvest_yield(soul))
	_fill_backpack(m)
	_check("④c 무대: 백팩이 가득하고 그 작물이 담기지 않는다(빈 슬롯 %s)"
			% str(m.inventory.has_free_slot()),
		not m.inventory.has_free_slot() and not m._pot_harvest_room(soul))
	_check("④d 자리가 없으면 양보가 **접힌다** — 대화가 그 칸에서 돌아온다(무기한 봉쇄의 반대편)",
		not m._pot_harvest_yield(soul))
	_check("④e 그래도 화분은 여전히 다 자란 채다(수확 창구가 원장을 안 비운 그 상태 그대로)",
		m.garden_pot.is_mature(soul))
	_clear_backpack(m)
	_check("④f 자리를 비우면 양보가 곧장 돌아온다(래치가 아니라 그 프레임의 상태다)",
		m._pot_harvest_yield(soul))
	m.garden_pot.remove(soul)
	m._indoor = ""

# ── ⑤ #4 보부상 희귀 슬롯 = 그 아침의 Books 원장 ────────────────────────────
func _check_peddler_book_pool() -> void:
	print("⑤ #4 보부상 책 갈래 ↔ 그날 아침 원장(static 순수)")
	var all_ids := Books.all_ids()
	_check("⑤a 무대: Books 로스터 %d점(분모의 진실원)" % all_ids.size(), all_ids.size() >= 3)
	# 책 갈래가 실제로 서는 출현일을 판에서 찾는다(퍼밀 상수·날짜를 안 적는다).
	var book_day := -1
	for d in range(1, 400):
		if d % Peddler.APPEAR_MODULUS != 0:
			continue
		var row := Peddler.rare_row(d, [], {})
		if String(row.get("kind", "")) == Peddler.KIND_BOOK:
			book_day = d
			break
	_check("⑤b 무대: day %d의 희귀 슬롯이 책 갈래다" % book_day, book_day > 0)
	if book_day <= 0:
		return
	var morning := Peddler.rare_row(book_day, [], {})
	var morning_id := String(morning.get("buy_id", ""))
	# 그날 **낮에** 다른 경로로 책 한 권을 줍는다(채굴·낚시·채집·개간엔 하루 한 점 잠금이 없다).
	var picked := ""
	for id in all_ids:
		if String(id) != morning_id:
			picked = String(id)
			break
	var owned := {picked: book_day}
	var afternoon := Peddler.rare_row(book_day, [], owned)
	_check("⑤c 무대: 아침 귀물 「%s」 · 낮에 다른 책 「%s」를 주웠다(취득일 = 그날)"
			% [morning_id, picked], morning_id != "" and picked != "" and picked != morning_id)
	_check("⑤d 오후에도 **같은 귀물**이 서 있다 — 「%s」(분모가 낮에 줄어 갈아 끼워지던 자리)"
			% String(afternoon.get("buy_id", "")),
		String(afternoon.get("buy_id", "")) == morning_id)
	# 어제까지 주운 책은 정상적으로 분모에서 빠진다(과잉 고정이 아니다).
	var yesterday := {picked: book_day - 1}
	_check("⑤e 어제 주운 책은 그대로 미보유 풀에서 빠진다 — 아침 풀 %d권 ↔ 어제 취득 반영 %d권"
			% [Peddler.remaining_books(owned, book_day).size(),
				Peddler.remaining_books(yesterday, book_day).size()],
		Peddler.remaining_books(owned, book_day).size() == all_ids.size()
			and Peddler.remaining_books(yesterday, book_day).size() == all_ids.size() - 1)
	_check("⑤f day 0(옛 시그니처)은 종전대로 라이브 원장을 판다(가법 확장 · 호출부 하위호환)",
		Peddler.remaining_books(owned).size() == all_ids.size() - 1)

# ── ⑥ #6 F9 인플레이스 로드가 주민 호감도를 되감는다 ────────────────────────
func _check_resident_affinity_rewind(m: Node) -> void:
	print("⑥ #6 주민 호감도 F9 되감기")
	# 세이브 키가 있는 주민 하나를 레지스트리에서 판다(이름을 손으로 안 적는다).
	var target = null
	for r in m._residents:
		if r.affinity != null and r.save_key != "":
			target = r
			break
	_check("⑥a 무대: 세이브 키를 든 주민 「%s」를 레지스트리에서 찾았다"
			% (target.save_key if target != null else "-"), target != null)
	if target == null:
		return
	var ok_save: bool = m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	_check("⑥b 무대: 세이브가 서고(%s) 그 주민 키 「%s」가 그 안에 있다"
			% [str(ok_save), target.save_key], ok_save and raw.has(target.save_key))
	# ① 그 키를 지운다 = 그 주민이 없던 구버전 세이브의 재현(VERSION은 1 고정이라 그대로 읽힌다).
	raw.erase(target.save_key)
	m.saver.save_game(raw, m._active_slot)
	# ② 직전 세션 값을 더럽힌다 — 호감도는 오직 플레이가 쌓는 누적이다.
	target.affinity.points = Affinity.MAX_POINTS
	target.affinity.stage = Affinity.MAX_HEARTS
	_check("⑥c 무대: 직전 세션 값이 섰다 — 「%s」 ♡%d · points %d"
			% [target.save_key, target.affinity.hearts(), target.affinity.points],
		target.affinity.hearts() > 0)
	var ok_load: bool = m._load_game()
	await process_frame
	_check("⑥c' 로드가 섰다(%s)" % str(ok_load), ok_load)
	_check("⑥d 키 없는 구세이브를 F9로 읽으면 ♡가 **되감긴다** — 「%s」 ♡%d · points %d (버린 타임라인의 하트가 살아남던 자리)"
			% [target.save_key, target.affinity.hearts(), target.affinity.points],
		target.affinity.hearts() == 0 and target.affinity.points == 0)
	# 판별식이 남는다: 호감도는 **부팅으로 시드되지 않는다**(플레이가 채운다) → 로드는 무조건 되감는다.
	_check("⑥e `has` 가드가 걷혔다 — 로드 루프가 `data.get(r.save_key, {})`로 무조건 부른다",
		_count_in_func(_src, "func _load_game", "data.has(r.save_key)") == 0
			and _count_in_func(_src, "func _load_game", "data.get(r.save_key, {})") == 1)
	m.saver.delete_save(m._active_slot)

# ── ⑦ #7 덤불 XP = 퍼크 곱 **전**의 수량 ─────────────────────────────────────
func _check_bush_xp(m: Node) -> void:
	print("⑦ #7 덤불 채집 XP ↔ 채집꾼 퍼크")
	var region := RegionCatalog.JEOSEUNG_FOREST
	var bushes: Array = m.bush_tiles_for(region)
	if bushes.is_empty() or m.berry_bushes == null:
		_check("⑦x 무대 없음(덤불 0)", false)
		return
	var region0: String = m._region
	m._region = region
	m._foraging_xp = 1_000_000                                  # 만렙(bush_yield 상단 계단)
	m._professions[ProfessionCatalog.FORAGING] = {5: "gatherer"}
	var lvl: int = m._skill_level(ProfessionCatalog.FORAGING)
	var base_n: int = ForageSkill.bush_yield(lvl)
	_check("⑦a 무대: 채집 L%d(수량 %d) · 채집꾼 확률 %.2f (퍼크가 실제로 켜졌다)"
			% [lvl, base_n, m.forage_double_drop_chance()],
		base_n >= 2 and m.forage_double_drop_chance() > 0.0)
	# 퍼크 롤이 **참이 되는 (day, 칸)** 을 판에서 찾는다(시드는 day·구역·칸 결정 — 값 강제 0).
	var day0: int = m.clock.day
	var hot := Vector2i(-1, -1)
	for d in range(day0, day0 + 400):
		if not BerryBushes.in_window(d):
			continue          # 절기 창 밖이면 `shake`가 빈손이라 무대가 안 선다
		m.clock.day = d
		for t in bushes:
			if m._forage_double_drop("bush", t):
				hot = t
				break
		if hot != Vector2i(-1, -1):
			break
	_check("⑦b 무대: day %d(절기 창 안 — 열매 「%s」)의 덤불 칸 %s에서 퍼크가 터진다(덤불 %d칸)"
			% [m.clock.day, ItemCatalog.name_of(BerryBushes.berry_for_day(m.clock.day)),
				str(hot), bushes.size()],
		hot != Vector2i(-1, -1) and BerryBushes.in_window(m.clock.day))
	if hot == Vector2i(-1, -1):
		m._region = region0
		m.clock.day = day0
		return
	_clear_backpack(m)
	m.berry_bushes.set_berry(region, hot, true)
	var xp0: int = m._foraging_xp
	var shook: bool = m._shake_bush(hot)
	var gained: int = m._foraging_xp - xp0
	_check("⑦c 흔들었고(%s) 퍼크가 실제로 수량을 2배로 냈다 — 적재 %d개(base %d)"
			% [str(shook), _total_new_items(m), base_n],
		shook and _total_new_items(m) == base_n * 2)
	_check("⑦d XP는 **퍼크 전 수량**으로 잰다 — %d XP (기대 %d = 개당 %d × base %d · 퍼크 반영이면 %d였다)"
			% [gained, ForageSkill.BUSH_SHAKE_XP * base_n, ForageSkill.BUSH_SHAKE_XP, base_n,
				ForageSkill.BUSH_SHAKE_XP * base_n * 2],
		gained == ForageSkill.BUSH_SHAKE_XP * base_n)
	_check("⑦e 형제 세 창구는 여전히 **고정 XP**다(수량 파생이 덤불 하나만이던 비대칭의 반대편)",
		_count_in_func(_src, "func _pick_flower", "_gain_forage_xp(ForageSkill.PICK_XP)") == 1
			and _count_in_func(_src, "func _pick_forage", "_gain_forage_xp(ForageSkill.PICK_XP)") == 1
			and _count_in_func(_src, "func _harvest_wild", "_gain_forage_xp(ForageSkill.PICK_XP)") == 1)
	m._region = region0
	m.clock.day = day0

# 백팩에 지금 들어 있는 아이템 총 개수(⑦의 적재량 판정 — 스택 구성까지 훑는다).
func _total_new_items(m: Node) -> int:
	var n := 0
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) != "":
			n += m.inventory.count_at(i)
	return n

# ── ⑧ #8 멜 활동 눈금 = 마진을 벗긴 매출 ─────────────────────────────────────
func _check_unmargined_scale() -> void:
	print("⑧ #8 멜 마진 폐루프(Cafe 순수)")
	var c := Cafe.new()
	var menu := ""
	c.margin = CafeMargin.margin(0)
	var at0: int = c.serve_price(menu)
	c.margin = CafeMargin.margin(Affinity.MAX_HEARTS)
	var at5: int = c.serve_price(menu)
	_check("⑧a 무대: 같은 한 잔이 ♡0에 %d냥 · ♡%d에 %d냥이다(마진 ×%.1f — 지갑엔 이 값이 그대로 든다)"
			% [at0, Affinity.MAX_HEARTS, at5, CafeMargin.margin(Affinity.MAX_HEARTS)],
		at5 == at0 * 2 and at0 > 0)
	c.free()

# ⑧ 뒷절은 main 무대에서 — 벗긴 값이 ♡와 무관하게 상수인가.
func _check_mel_windows(m: Node) -> void:
	print("⑧·⑨ #8·#11 멜 활동 채널 — 눈금과 창구")
	var h0: int = m.mel_affinity.hearts()
	m.cafe.margin = CafeMargin.margin(0)
	var rev0: int = m.cafe.serve_price("")
	var scale0: int = m._unmargined_revenue(rev0)
	m.cafe.margin = CafeMargin.margin(Affinity.MAX_HEARTS)
	var rev5: int = m.cafe.serve_price("")
	var scale5: int = m._unmargined_revenue(rev5)
	_check("⑧b 벗긴 눈금이 ♡와 무관하게 같다 — ♡0 %d냥→%d · ♡%d %d냥→%d (곱셈기가 자기 입력을 가속하던 폐루프)"
			% [rev0, scale0, Affinity.MAX_HEARTS, rev5, scale5],
		scale0 == scale5 and scale0 > 0)
	_check("⑧c 지갑·마일스톤 축은 **안 벗긴다** — 매출 자체는 ♡5에서 여전히 2배다(관계=곱셈기, ADR-0008 불변)",
		rev5 == rev0 * 2)
	# ⑨ 형제 매출 창구 셋이 같은 채널에 합류했다(배선이 곧 계약 — ⑧f 관례).
	_check("⑨a 낮 서빙은 **벗겨서** 넣는다(체키도 같다 — 둘 다 서빙가 파생이라 마진이 실려 있다)",
		_count_in_func(_src, "func _try_serve", "_credit_mel_revenue(_unmargined_revenue(revenue))") == 1
			and _count_in_func(_src, "func _finish_cheki", "_credit_mel_revenue(_unmargined_revenue(revenue))") == 1)
	_check("⑨b 밤 응대가 합류했다(`cafe_milestone`이 이 축을 «서빙 매출 = 카페 서빙 + 밤 바 응대»로 정의한다)",
		_count_in_func(_src, "func _try_night_serve", "_credit_mel_revenue(revenue)") == 1)
	_check("⑨c 칵테일이 합류했다(밤 응대 사슬의 둘째 단)",
		_count_in_func(_src, "func _finish_cocktail", "_credit_mel_revenue(revenue)") == 1)
	_check("⑨d 밤 축은 **안 벗긴다** — night_bar에 멜 마진 축이 없어 벗길 것이 없다",
		_count_in_func(_src, "func _try_night_serve", "_unmargined_revenue") == 0
			and _count_in_func(_src, "func _finish_cocktail", "_unmargined_revenue") == 0)
	# 실거동 — 크레딧이 실제로 활동 점수를 낳는다(창구 배선이 죽은 줄이 아님의 증거).
	m.mel_affinity.activity_day = m.clock.day
	m.mel_affinity.activity_today = 0
	m._mel_revenue_carry = 0
	var pts0: int = m.mel_affinity.points
	m._credit_mel_revenue(m.MEL_REVENUE_PER_POINT)
	_check("⑨e 크레딧 1점이 실제로 멜 활동 채널에 들어간다 — points %d → %d(잔돈 %d)"
			% [pts0, m.mel_affinity.points, m._mel_revenue_carry],
		m.mel_affinity.points > pts0 and m._mel_revenue_carry == 0)
	m.cafe.margin = CafeMargin.margin(h0)

# ── ⑩ #9 여우불 «범위» = 하루 예산(두 밭이 나눠 쓴다) ────────────────────────
func _check_foxfire_budget() -> void:
	print("⑩ #9 여우불 범위 예산(FarmField 둘 · 순수)")
	var reach: int = Foxfire.reach(Affinity.MAX_HEARTS)
	var accel: int = Foxfire.accel(Affinity.MAX_HEARTS)
	_check("⑩a 무대: ♡%d의 범위는 %d칸이다(foxfire.gd — «하루에 돌볼 최대 칸 수»)"
			% [Affinity.MAX_HEARTS, reach], reach >= 2)
	var outdoor := FarmField.new()
	var green := FarmField.new()
	var crop := CropCatalog.HWANGCHEON_PODO
	for i in range(reach + 2):
		var t := Vector2i(i, 1)
		outdoor.hoe(t); outdoor.plant(t, crop)
		green.hoe(t); green.plant(t, crop)
	_check("⑩b 무대: 두 밭에 각각 물 안 준 미성숙 칸 %d개(예산 %d보다 많다)"
			% [reach + 2, reach],
		outdoor.planted_tiles().size() == reach + 2 and green.planted_tiles().size() == reach + 2)
	var used_out: int = outdoor.advance_day(accel, reach, true)
	var used_green: int = green.advance_day(accel, maxi(reach - used_out, 0), true)
	_check("⑩c 노지가 예산을 다 쓴다 — %d칸(반환 계약: 실제로 돌본 칸 수)" % used_out, used_out == reach)
	_check("⑩d 늘봄방은 **남은 몫**만 받는다 — %d칸 · 합계 %d ≤ 예산 %d (종전엔 각각 전액이라 %d칸이었다)"
			% [used_green, used_out + used_green, reach, reach * 2],
		used_green == 0 and used_out + used_green == reach)
	# 실제로 자란 칸 수로도 확인한다(반환값만 믿지 않는다 — 카운트 단언의 그 함정).
	var grown_out := 0
	var grown_green := 0
	for t in outdoor.planted_tiles():
		if outdoor.growth_stage(t) > 0:
			grown_out += 1
	for t in green.planted_tiles():
		if green.growth_stage(t) > 0:
			grown_green += 1
	_check("⑩e 실측: 자란 칸이 노지 %d · 늘봄방 %d = %d칸(예산 %d — 원장으로도 같은 답)"
			% [grown_out, grown_green, grown_out + grown_green, reach],
		grown_out + grown_green == reach)
	_check("⑩f 배선: 늘봄방 호출이 **남은 몫**을 넘긴다(같은 함수 안 형제 = 배우자 물주기의 그 문법)",
		_count_in_func(_src, "func _on_day_advanced", "maxi(Foxfire.reach(h) - foxfire_used, 0)") == 1)
	outdoor.free()
	green.free()

# ── ⑪ #10 과수 수확이 누적 점수판에 합류 ─────────────────────────────────────
func _check_orchard_scoreboard(m: Node) -> void:
	print("⑪ #10 과수 수확 ↔ 누적 수확 점수판")
	if m.orchard == null:
		_check("⑪x 무대 없음(orchard null)", false)
		return
	var fruit := String(FruitTreeCatalog.ids()[0])
	var anchor := Vector2i(-1, -1)
	for tile in m.farm.tilled_tiles():
		anchor = tile
		break
	if anchor == Vector2i(-1, -1):
		anchor = m._player_tile() + Vector2i(0, 2)
	# 원장에 직접 심는다(지형 게이트는 이 단언의 축이 아니다 — 축은 «수확이 점수판을 올리는가»다).
	m.orchard._trees[anchor] = {"fruit_id": fruit,
		"planted_day": m.clock.day - FruitTreeCatalog.mature_days(fruit), "fruit_count": 2}
	m._region = RegionCatalog.HOME
	m._indoor = ""
	m._target = anchor
	_clear_backpack(m)
	m.energy.current = SoulEnergy.MAX
	_check("⑪a 무대: 성숙 나무 %s에 과일 %d개가 달렸다(종 「%s」)"
			% [str(anchor), m.orchard.fruit_count_of(anchor), fruit],
		m.orchard.is_mature(anchor, m.clock.day) and m.orchard.fruit_count_of(anchor) == 2)
	var run0: int = m._run_harvested
	var xp0: int = m._farming_xp
	var took: bool = m._try_harvest()
	_check("⑪b 과수 수확이 실제로 집행됐다(%s) — 과일 %d개가 남았고 농사 XP가 %d 올랐다"
			% [str(took), m.orchard.fruit_count_of(anchor), m._farming_xp - xp0],
		took and m.orchard.fruit_count_of(anchor) == 0 and m._farming_xp > xp0)
	_check("⑪c 누적 수확 점수판이 **한 번** 올랐다 — %d → %d(수확 액션당 1 · 과일 개수가 아니다)"
			% [run0, m._run_harvested], m._run_harvested == run0 + 1)
	_check("⑪d 창구는 넷이다 — 밭·화분·야생·과수 전부 `_count_run_harvest`로 모인다",
		_count_in_func(_src, "func _try_harvest", "_count_run_harvest()") == 2
			and _count_in_func(_src, "func _harvest_pot", "_count_run_harvest()") == 1
			and _count_in_func(_src, "func _harvest_wild", "_count_run_harvest()") == 1)
	m.orchard._trees.erase(anchor)

# ── ⑫ #12 휴지통 = «매대 가격 0인 증정품» 전량 ───────────────────────────────
func _check_trash_gift_weapon(m: Node) -> void:
	print("⑫ #12 휴지통 폐기 차단 ↔ 증정 무기")
	# 증정 무기(= 매대 가격 0)와 매대에 서는 무기를 **카탈로그에서** 판다(id 복제 0).
	var gift_sword := ""
	var sold_sword := ""
	for id in WeaponCatalog.ids():
		var sid := String(id)
		if WeaponCatalog.price_of(sid) <= 0 and gift_sword == "":
			gift_sword = sid
		elif WeaponCatalog.price_of(sid) > 0 and sold_sword == "":
			sold_sword = sid
	_check("⑫a 무대: 증정 무기 「%s」(price %d) ↔ 매대 무기 「%s」(price %d)"
			% [ItemCatalog.name_of(gift_sword), WeaponCatalog.price_of(gift_sword),
				ItemCatalog.name_of(sold_sword), WeaponCatalog.price_of(sold_sword)],
		gift_sword != "" and sold_sword != "")
	_clear_backpack(m)
	m.inventory.add_item(gift_sword, 1)
	var slot := -1
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == gift_sword:
			slot = i
			break
	_feed_clear(m)
	m._on_frame_discard(slot)
	_check("⑫b 증정 무기를 버릴 수 없다 — 백팩에 %d자루 그대로(유일 지급처가 세이브 영속 플래그다)"
			% m.inventory.count_of(gift_sword), m.inventory.count_of(gift_sword) == 1)
	_check("⑫c 사유가 화면에 뜬다 — «다시 구할 곳이 없다»",
		_feed_has(m, "다시 구할 곳이 없다"))
	# 과잉 차단이 아니다 — 값이 붙어 매대에 서는 무기는 그대로 버려진다(표가 파생인 근거).
	_clear_backpack(m)
	m.inventory.add_item(sold_sword, 1)
	var slot2 := -1
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == sold_sword:
			slot2 = i
			break
	m._on_frame_discard(slot2)
	_check("⑫d 매대 무기 「%s」는 그대로 버려진다 — 표가 id가 아니라 **가격 0 술어**에서 파생한다"
			% ItemCatalog.name_of(sold_sword), m.inventory.count_of(sold_sword) == 0)
	_clear_backpack(m)

# ══════════ 배치 B(#13~#25) ══════════════════════════════════════════════════
#
# 렌즈: 문구 폭·창 넘침(#14·#15·#16·#17·#18) · 상호작용 우선순위 사다리(#19·#20·#21·#22) ·
#       첫날 온보딩 진실(#23·#24·#25) · 지급 창구 정합(#13 — OWNER).
#
# 이 배치의 태도 둘.
#   ㉠ **표시 단언은 그리기 경로를 태운다**(R15가 세운 규약). ⑬은 NoticeFeed에 실제로 push하고
#      `_draw`가 쓰는 그 폭 산식으로 줄 수를 재고, ⑭는 Label에 실제 문구를 넣어 폰트로 접어 보며,
#      ⑮는 판·라벨의 **실측 size**를 본다. "상수가 크다"를 재는 항은 하나도 없다.
#   ㉡ **무손실을 잰다.** 잘렸는지가 아니라 «한 글자도 안 잃었는지»가 축이라, ⑬·⑭는 접힌 뒤의
#      가용 면적이 전문(全文)을 담는가를 묻는다(말줄임·축소로 고쳤다면 이 항이 빨개진다).
#
# 무엇을 보증하나(번호 = 23회차 헌트 발견 인덱스).
#   ⑬ #14 알림 띠가 320px 하드 밴드라 non-wide 알림의 실 그리기 폭이 **308px 고정**이었고
#      elide도 축소도 안 탔다 — 문자열 리터럴 330개 중 129개가 그 폭을 넘어 꼬리(「[Tab] 가방을
#      비우고 다시」 같은 *해법*)가 통째로 사라졌다.
#   ⑭ #15·#16 InteractPrompt Label(폭 624·중앙 정렬·wrap/clip 없음)에 대장간 벼리기(최대 776px)와
#      게시판 일일+중기 병기(792~1088px)가 그대로 나가, 양끝이 **동시에** 화면 밖으로 잘렸다.
#   ⑮ #17·#18 두 팝업이 고정 기하라 조건부로 늘어난 본문이 라벨·판을 넘어 한지 9-slice 테두리
#      위·판 바깥 월드 위에 그려졌다(마감 정산 6줄 111px vs 라벨 80px · 2단 달성 7줄 130px vs 120px).
#   ⑯ #19 `_is_tree_blocked`에 `_installation_at`이 없어 **설치물 위에 영구 SOLID 밑동**을 심을 수
#      있었다(orchard remove API 0 — 반대 방향 셋은 전부 `_orchard_trunk_at`으로 거절한다).
#   ⑰ #20 `_can_place_sprinkler`(가드 15개)에만 `_resident_tile`이 없어 주민 상주 칸에 설치되고,
#      프롬프트 사슬이 주민 갈래에서 먼저 끊겨 회수 안내가 도달 불가였다(레어크로우가 상속).
#   ⑱ #21 `on_refill`에 `session_lmb` 가드가 없어 릴 격투 중 매 당김이 리필을 함께 실행했다.
#   ⑲ #22 `_free_pasture_tiles`가 `_orchard_trunk_at`을 안 봐 방목 짐승이 밑동 위에 배정됐다.
#   ⑳ #23 PLANT 배너가 시작 절기에 **어디서도 못 구하는** 씨앗을 이름으로 지목했다.
#   ㉑ #24 모달이 한 번 덮으면 그 단계의 안내 배너가 영구히 다시 안 떴다.
#   ㉒ #25 오프닝 통보 중에 시계가 흘러(45실초 = 15:00) 옥자의 「밭에 있으니 가서 말 걸어」가
#      대화가 닫히는 순간 거짓이 됐다 — 형제 셋(컷신·내면·에필로그)은 전부 시계를 세운다.
#
# 판정: #14·#15·#16·#17·#18·#19·#20·#21·#22·#23·#24·#25 CONFIRMED(전부 봉합) ·
#   #13 = **OWNER-DECISION**(코드 불변 — 근거는 커밋 본문).
#
# 하중 검증(**실측** — 봉합을 되돌려 실제로 뜬 red를 그대로 옮겨 적는다. 파괴 3배치·전건 확인):
#   #14 `_wrapped_rows`를 상수 1로 죽임       → ⑬b·⑬c red(3줄 → **1줄** = 가용 304px가 전문 714px를 못 담는다)
#   #14 `draw_multiline_string` → `draw_string` → ⑬d red(그리기가 다시 잘라 그린다)
#   #15·#16 `_fit_interact_prompt` 무력화       → ⑭c red(대장간 640px 줄에 판이 **18px 한 줄**로 남는다)
#   #17 `_layout_popup_panel` 호출 삭제         → ⑮c·⑮d red(**라벨 111 + 여백 24 > 판 104** = 판 밖으로 나간다)
#   #18 같은 호출 삭제(마일스톤 세 단계)         → ⑮f red(배선) · ⑮g red(라벨 134 + 24 > 판 144)
#   #19 `_installation_at` 항 삭제              → ⑯c red(스프링클러 위에 영구 밑동이 선다)
#   #20 `_resident_tile` 항 삭제                → ⑰c·⑰d red(미호 자리에 스프링클러·레어크로우가 선다)
#   #21 `not session_lmb` 삭제                  → ⑱a·⑱c red(같은 술어 6자리 → **5자리**)
#   #22 `_orchard_trunk_at` 항 삭제             → ⑲c red(슬롯 61 → **61** = 밑동 칸이 안 빠진다)
#   #23 `seed_name` 갈래 삭제(하드코딩 복귀)     → ⑳a·⑳d red(씨앗 0에서도·다른 씨앗을 들어도 혼령초를 지목)
#   #24 `_forget_onboarding_guide` 무력화        → ㉑c·㉑d red(래치가 그대로라 배너가 영영 안 뜬다)
#   #25 `clock.running = false` 삭제            → ㉒c·㉒d·㉒e red(통보 중 **602분 → 1440분** = 하루가 통째로 흐른다)
#
# ★하중 검증에서 배운 것 셋.
#   · **Godot Label은 접힌 본문에 맞춰 스스로 자란다.** 그래서 ⑮의 「본문 ≤ 라벨」만으로는 판이
#     그대로여도 초록이 된다(파괴 실측에서 라벨이 tscn 80이 아니라 111로 잡혔다). 진짜 불변식은
#     **「라벨 + 여백 ≤ 판」**(⑮d·⑮g)이고, 그 1px 차이가 봉합 자체도 정정했다 — `_layout_popup_panel`은
#     우리 식으로 판을 재면 안 되고 라벨을 세운 뒤 그 높이를 **되읽어** 재야 한다.
#   · **느슨한 니들은 형제에게 걸려 통과한다.** ⑱a의 첫 니들("and not session_lmb \\")은 리필이 아니라
#     게잡이통 줄에 매칭돼 파괴에도 초록이었다. 형제 다섯이 같은 술어를 쓰는 사슬에서는 니들이
#     **그 갈래의 변수명까지** 물어야 한다(`var on_refill := …`).
#   · **⑭d는 ⑭c의 red-catcher가 아니다.** `_prompt_line_count`는 순수 측정이라 접기를 죽여도 여전히
#     2줄을 답한다 — 접혔는가를 재는 항은 ⑭c(autowrap + 판 높이)이고, ⑭d가 재는 것은 «접히면
#     전문이 남는가»라는 무손실 쪽이다. 두 축을 한 항으로 묶으면 하중이 반만 걸린다(R22 ①c의 그 교훈).

# ── ⑬ #14 알림 띠 = 무손실 접힘 ──────────────────────────────────────────────
# 문구를 손으로 안 짓는다: main이 실제로 쏘는 그 형태(최장 아이템명 + 만재 안내)를 카탈로그에서
# 조립하고, 폭 산식도 `_draw`가 쓰는 그것(MAX_W − 16 − 아이콘)을 그대로 쓴다.
func _check_notice_wrap(m: Node) -> void:
	print("⑬ #14 알림 띠 ↔ 긴 문구")
	var feed: NoticeFeed = m.notice_feed
	if feed == null:
		_check("⑬x 무대 없음(notice_feed null)", false)
		return
	# 카탈로그에서 **가장 긴 이름**을 판다(문자열을 옮겨 적지 않는다).
	var longest := ""
	for id in _catalog_roster():
		var nm := ItemCatalog.name_of(String(id))
		if nm.length() > longest.length():
			longest = nm
	var text := "백팩이 가득 차 %s 거둘 수 없다 — [Tab] 가방에서 자리를 비우고 다시" \
		% HanjiUi.with_eul(longest)
	var font := HanjiUi.font()
	var full_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var avail := NoticeFeed.MAX_W - 16.0
	_check("⑬a 무대: 최장 이름 「%s」로 지은 그 알림이 %.0fpx — 띠 가용 폭 %.0fpx의 %.1f배다"
			% [longest, full_w, avail, full_w / maxf(avail, 1.0)], full_w > avail)
	var rows: int = feed._wrapped_rows(font, text, avail)
	_check("⑬b 그 문구가 %d줄로 접힌다(한 줄에 안 들어가는 것을 원장이 인정한다)" % rows, rows >= 2)
	# 무손실 판정 = 접힌 뒤의 **가용 면적**이 전문을 담는가(말줄임·축소로 고쳤다면 여기서 빨개진다).
	_check("⑬c 접힌 면적이 전문을 담는다 — %d줄 × %.0fpx = %.0fpx ≥ %.0fpx(한 글자도 안 잃는다)"
			% [rows, avail, float(rows) * avail, full_w], float(rows) * avail >= full_w)
	_check("⑬d 그리기가 접는 창구를 실제로 탄다(`draw_multiline_string` — 잘라 그리는 `draw_string` 아님)",
		_count_in_func(_feed_src(), "func _draw", "draw_multiline_string(") == 1
			and _count_in_func(_feed_src(), "func _draw", "draw_string(") == 0)
	# 짧은 알림은 종전대로 한 줄이다(과잉 접힘이 아니다 = 좌측 컬럼 결 보존).
	_check("⑬e 짧은 알림은 여전히 한 줄이다 — 「저장됨」 %d줄(접힘이 필요할 때만 일어난다)"
			% feed._wrapped_rows(font, "저장됨", avail),
		feed._wrapped_rows(font, "저장됨", avail) == 1)

# 이름 길이를 재는 아이템 로스터 — **카탈로그 상수에서 조립한다**(이름을 손으로 안 적는다).
func _catalog_roster() -> Array:
	var out: Array = []
	out.append_array(ItemCatalog.RARECROWS)
	for d in [ItemCatalog.RELICS, ItemCatalog.FORAGEABLES, ItemCatalog.MATERIALS,
			ItemCatalog.MINERALS, ItemCatalog.POT_GOODS, ItemCatalog.PLACEABLES]:
		out.append_array(d.keys())
	return out

func _feed_src() -> PackedStringArray:
	return _lines_of_file("res://notice_feed.gd")

# ── ⑭ #15·#16 프롬프트 = 무손실 접힘 ─────────────────────────────────────────
func _check_prompt_fit(m: Node) -> void:
	print("⑭ #15·#16 프롬프트 폭 ↔ 긴 한 줄")
	var w: float = m._prompt_max_width()
	var fs: int = m._prompt_font_size()
	_check("⑭a 무대: InteractPrompt 폭 %.0fpx · 글자 %dpx(레이아웃·테마에서 파생 — 상수 복제 0)"
			% [w, fs], w > 0.0 and fs > 0)
	# 대장간 최악 조합을 **카탈로그에서** 만든다(티어 이름·주괴 이름·가격을 손으로 안 적는다).
	var smithy: String = m._tool_upgrade_prompt(ItemCatalog.WATERING_CAN)
	var board := "[F] 일일 — %s   [G] 중기 — %s" % [
		QuestBoard.summary({"item_id": ItemCatalog.harvest_id(CropCatalog.HWANGCHEON_PODO),
			"count": 3, "client": "미호", "due_day": 9, "gold": 800}),
		QuestBoard.summary({"item_id": ItemCatalog.harvest_id(CropCatalog.YEONGHON_HOBAK),
			"count": 2, "client": "세레나", "due_day": 12, "gold": 1200})]
	var smithy_w := HanjiUi.text_width(smithy, fs)
	var board_w := HanjiUi.text_width(board, fs)
	_check("⑭b 무대: 대장간 한 줄 %.0fpx · 게시판 병기 %.0fpx — 둘 다 Label 폭 %.0f를 넘는다"
			% [smithy_w, board_w, w], board_w > w)
	m.interact_prompt.text = smithy
	m._fit_interact_prompt()
	var smithy_lines: int = m._prompt_line_count(smithy)
	_check("⑭c 대장간 줄이 %d줄로 접히고 판이 %.0fpx로 자란다(양끝이 화면 밖으로 나가던 자리)"
			% [smithy_lines, m.interact_prompt.size.y],
		m.interact_prompt.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
			and m.interact_prompt.size.y >= m.PROMPT_LINE_H * float(smithy_lines))
	m.interact_prompt.text = board
	m._fit_interact_prompt()
	var board_lines: int = m._prompt_line_count(board)
	_check("⑭d 게시판 병기가 %d줄로 접힌다 — 접힌 면적 %.0fpx ≥ 전문 %.0fpx(F↔G와 보상액이 다 남는다)"
			% [board_lines, float(board_lines) * w, board_w],
		board_lines >= 2 and float(board_lines) * w >= board_w)
	# 짧은 프롬프트는 종전 한 줄·기본 높이 그대로다(과잉 확장이 아니다).
	m.interact_prompt.text = "[F] 시련패 매대 (보유 0패)"
	m._fit_interact_prompt()
	_check("⑭e 짧은 프롬프트는 한 줄·%.0fpx 그대로다(내용 파생이지 상시 확장이 아니다)"
			% m.interact_prompt.size.y, m.interact_prompt.size.y == m.PROMPT_LINE_H)
	# ★배선 단언 — 위 넷은 테스트가 직접 부르므로 «사슬이 실제로 부르는가»를 못 잰다(R22 ⑧f 관례).
	_check("⑭f 배선: 프롬프트 사슬이 끝에서 **한 번** 맞춘다(마흔 갈래 어느 것을 골랐든 지나는 자리)",
		_count_in_func(_src, "func _process", "_fit_interact_prompt()") == 1)

# ── ⑮ #17·#18 팝업 판 = 내용 파생 기하 ───────────────────────────────────────
func _check_popup_layout(m: Node) -> void:
	print("⑮ #17·#18 팝업 판 ↔ 본문")
	# 마감 정산 — 최대 본문(아는 얼굴·체키 줄이 둘 다 붙는 날)을 실제 창구로 띄운다.
	var summary := "\n".join(["── 오늘 카페 영업 마감 ──", "매출  +1200냥", "서빙한 손님  8명",
		"놓친 손님  2명", "아는 얼굴  3명", "체키  2장"])
	m._show_cafe_summary(summary)
	var body_h: float = m._label_body_height(m.cafe_summary_text, summary, m.cafe_summary_text.size.x)
	_check("⑮a 무대: 마감 정산 6줄 본문이 %.0fpx다(라벨 폭 %.0f에서 접힌 실측)"
			% [body_h, m.cafe_summary_text.size.x], body_h > 0.0)
	_check("⑮b 판이 본문에 맞춰 섰다 — 판 %.0fpx · 라벨 %.0fpx"
			% [m.cafe_summary_panel.size.y, m.cafe_summary_text.size.y],
		m.cafe_summary_panel.size.y > 0.0 and m.cafe_summary_text.size.y > 0.0)
	_check("⑮c 본문이 라벨 안에 든다 — %.0f ≤ %.0f(종전엔 111 > 80이라 첫 줄·막줄이 테두리 위에 깔렸다)"
			% [body_h, m.cafe_summary_text.size.y], body_h <= m.cafe_summary_text.size.y + 0.5)
	_check("⑮d 라벨이 판 안에 든다 — 라벨 %.0f + 여백 %.0f×2 ≤ 판 %.0f"
			% [m.cafe_summary_text.size.y, m.cafe_summary_text.position.y, m.cafe_summary_panel.size.y],
		m.cafe_summary_text.size.y + m.cafe_summary_text.position.y * 2.0
			<= m.cafe_summary_panel.size.y + 0.5)
	m.cafe_summary_panel.visible = false
	# 마일스톤 — 2단 달성(막줄이 폭 408에서 접혀 7줄이 되는 그 문구).
	m._show_milestone2_reached()
	var m_body: float = m._label_body_height(m.milestone_text, m.milestone_text.text, m.milestone_text.size.x)
	_check("⑮e 2단 달성 본문 %.0fpx가 라벨 %.0fpx 안에 든다(래치라 세이브당 한 번뿐인 그 팝업)"
			% [m_body, m.milestone_text.size.y], m_body <= m.milestone_text.size.y + 0.5)
	# ★진짜 불변식은 «라벨이 판 안에 드는가»다 — Godot Label은 접힌 본문에 맞춰 **스스로 자라므로**
	#   「본문 ≤ 라벨」만 재면 판이 그대로여도 초록이 된다(실측으로 배운 것 — 아래 ★ 항 참조).
	#   판이 안 따라 자란 상태가 곧 «첫 줄·막줄이 한지 테두리 위에 그려진다»의 정의다.
	_check("⑮g 라벨이 판 안에 든다 — 라벨 %.0f + 여백 %.0f×2 ≤ 판 %.0f"
			% [m.milestone_text.size.y, m.milestone_text.position.y, m.milestone_panel.size.y],
		m.milestone_text.size.y + m.milestone_text.position.y * 2.0
			<= m.milestone_panel.size.y + 0.5)
	_check("⑮f 세 단계가 전부 판을 다시 세운다(2단만 고치면 다음 문구가 같은 자리에서 다시 넘친다)",
		_count_in_func(_src, "func _show_milestone_reached", "_layout_popup_panel(") == 1
			and _count_in_func(_src, "func _show_milestone2_reached", "_layout_popup_panel(") == 1
			and _count_in_func(_src, "func _show_milestone3_reached", "_layout_popup_panel(") == 1)
	m.milestone_panel.visible = false

# ── ⑯ #19 설치물 칸 = 나무의 성역 ────────────────────────────────────────────
func _check_tree_installation(m: Node) -> void:
	print("⑯ #19 혼의 나무 심기 ↔ 설치물")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	# 심을 수 있는 빈 칸을 판에서 찾는다(좌표를 옮겨 적지 않는다).
	var spot := Vector2i(-1, -1)
	for y in range(m._grid.size()):
		for x in range(m._grid[y].size()):
			var t := Vector2i(x, y)
			if m._is_tree_blocked(t) or m._installation_at(t) or not m._can_place_sprinkler(t):
				continue
			spot = t
			break
		if spot != Vector2i(-1, -1):
			break
	_check("⑯a 무대: 빈 칸 %s는 지금 나무도 설치물도 막지 않는다" % str(spot),
		spot != Vector2i(-1, -1) and not m._is_tree_blocked(spot))
	if spot == Vector2i(-1, -1):
		return
	m.sprinkler.place(spot)
	_check("⑯b 무대: 그 칸에 스프링클러가 섰다(설치물 원장이 그 칸을 든다)",
		m._installation_at(spot))
	_check("⑯c 이제 나무 심기가 그 칸을 **거절한다** — 되돌릴 창구가 orchard에 0이라 유일하게 비가역인 방향이었다",
		m._is_tree_blocked(spot))
	_check("⑯d 반대 방향은 종전대로다 — 밑동이 선 칸은 설치물이 거절한다(양방향 가드가 이제 대칭)",
		not m._can_place_sprinkler(spot))
	m.sprinkler.remove(spot)
	_check("⑯e 회수하면 그 칸이 다시 열린다(가드가 래치가 아니라 그 프레임의 원장이다)",
		not m._is_tree_blocked(spot) and not m._installation_at(spot))

# ── ⑰ #20 주민 상주 칸 = 설치 금지 ───────────────────────────────────────────
func _check_sprinkler_resident(m: Node) -> void:
	print("⑰ #20 스프링클러·레어크로우 ↔ 주민 상주 칸")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	var seat: Vector2i = m.MIHO_FIELD_TILE
	_check("⑰a 무대: 미호 자리 %s는 주민 상주 칸이다(형제 가드 넷이 이미 보는 그 술어)"
			% str(seat), m._resident_tile(seat))
	_check("⑰b 무대: 그 칸이 지형·프롭 축으로는 멀쩡하다(가드 열다섯을 통과하던 자리)",
		not m._home_occupied_tiles().has(seat) and not m.sprinkler.has_at(seat))
	_check("⑰c 스프링클러가 그 칸을 **거절한다**(형제 넷 `_can_place_pot`·`_can_place_crab_pot`·"
			+ "`_can_place_crystalarium`·`_can_place_furnace`와 정렬)",
		not m._can_place_sprinkler(seat))
	var crow := String(ItemCatalog.RARECROWS[0])
	_check("⑰d 레어크로우도 함께 거절된다(그 함수를 통째로 재사용하므로 구멍도 함께 닫힌다) — 표본 「%s」"
			% ItemCatalog.name_of(crow), crow != "" and not m._can_place_rarecrow(seat))

# ── ⑱ #21 릴 격투 중의 LMB는 리필이 아니다 ───────────────────────────────────
func _check_refill_session(m: Node) -> void:
	print("⑱ #21 물뿌리개 리필 ↔ LMB 세션")
	# 니들은 **리필 갈래 그 줄**이다 — 형제 넷도 같은 술어를 쓰므로 느슨한 니들은 그쪽에 걸려 통과한다.
	_check("⑱a 배선: 리필 갈래가 `session_lmb`를 문다(형제 넷·도구 갈래가 R19 #10·R10 #5에 받은 그 가드)",
		_count_in_func(_src, "func _process", "var on_refill := not _sleeping and not session_lmb") == 1)
	# 선언이 리필 갈래보다 **앞**이어야 한다(뒤면 파싱조차 안 된다 — 순서가 곧 계약이다).
	var decl := _line_of(_src, "func _process", "var session_lmb :=")
	var use := _line_of(_src, "func _process", "var on_refill :=")
	_check("⑱b 배선 순서: 선언(%d행)이 리필 갈래(%d행)보다 앞이다" % [decl, use],
		decl > 0 and use > 0 and decl < use)
	_check("⑱c 리필을 포함해 같은 술어를 쓰는 갈래가 `_process` 안에 %d자리다(설치 넷·도구·리필)"
			% _count_in_func(_src, "func _process", "not session_lmb"),
		_count_in_func(_src, "func _process", "not session_lmb") >= 6)

# ── ⑲ #22 방목 슬롯 ↔ 혼의 나무 밑동 ─────────────────────────────────────────
func _check_pasture_trunk(m: Node) -> void:
	print("⑲ #22 방목 배정 ↔ 밑동")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	var slots: Array = m._free_pasture_tiles()
	_check("⑲a 무대: 방목 슬롯이 %d칸 있다" % slots.size(), not slots.is_empty())
	if slots.is_empty():
		return
	var anchor: Vector2i = slots[0]
	var fruit := String(FruitTreeCatalog.ids()[0])
	m.orchard._trees[anchor] = {"fruit_id": fruit,
		"planted_day": m.clock.day, "fruit_count": 0}
	_check("⑲b 무대: 그 슬롯 %s에 혼의 나무 밑동이 섰다(방목지는 `_is_tree_blocked`가 예약하지 않는다)"
			% str(anchor), m._orchard_trunk_at(anchor))
	var after: Array = m._free_pasture_tiles()
	_check("⑲c 그 칸이 슬롯에서 빠진다 — %d칸 → %d칸(짐승이 밑동 콜라이더 안에 서던 자리)"
			% [slots.size(), after.size()], not after.has(anchor) and after.size() == slots.size() - 1)
	m.orchard._trees.erase(anchor)
	_check("⑲d 밑동을 걷으면 슬롯이 돌아온다 — %d칸(다음 아침 방출이 다시 고른다 = 자가 회복)"
			% m._free_pasture_tiles().size(), m._free_pasture_tiles().has(anchor))

# ── ⑳ #23 PLANT 배너 = 실제로 심을 수 있는 것 ────────────────────────────────
func _check_onboarding_seed(m: Node) -> void:
	print("⑳ #23 온보딩 PLANT 배너 ↔ 손에 든 씨앗")
	var step0: int = m.onboarding.step
	m.onboarding.step = Onboarding.PLANT
	_clear_backpack(m)
	_check("⑳a 씨앗이 하나도 없으면 배너가 **구하는 법**을 말한다(없는 물건을 지목하지 않는다) — 「%s」"
			% m.onboarding.guidance(false, m._onboarding_seed_name()),
		m._onboarding_seed_name() == ""
			and m.onboarding.guidance(false, "").contains("출하함"))
	# 시작 절기에 실제로 안 서는 스타터 씨앗(유화절 작물)이 그 함정의 실체다.
	var starter := String(Inventory.START_SEEDS.keys()[0])
	var start_season := GameClock.season_index_for_day(1)
	_check("⑳b 무대: 스타터 씨앗 「%s」는 시작 절기(%d)에 제철이 아니다 — 매대가 통째로 거른다"
			% [CropCatalog.name_of(starter), start_season],
		not CropCatalog.in_season(starter, start_season))
	m.inventory.add_item(ItemCatalog.seed_id(starter), 1)
	var g1: String = m.onboarding.guidance(false, m._onboarding_seed_name())
	_check("⑳c 씨앗을 가지면 **그 이름**을 지목한다 — 「%s」" % g1,
		g1.contains(CropCatalog.name_of(starter)) and g1.contains("[좌클릭]"))
	# 다른 씨앗으로 갈아 들면 문구도 따라간다(이름이 하드코딩이 아님의 증거).
	_clear_backpack(m)
	var other := ""
	for cid in CropCatalog.ids():
		if String(cid) != starter and ItemCatalog.has_item(ItemCatalog.seed_id(String(cid))):
			other = String(cid)
			break
	m.inventory.add_item(ItemCatalog.seed_id(other), 1)
	var g2: String = m.onboarding.guidance(false, m._onboarding_seed_name())
	_check("⑳d 다른 씨앗을 들면 문구가 따라간다 — 「%s」(카탈로그 파생 · id 복제 0)" % g2,
		other != "" and g2.contains(CropCatalog.name_of(other))
			and not g2.contains(CropCatalog.name_of(starter)))
	# ★ 두 갈래 다 **배너 판이 뷰포트 안**이어야 한다(R16 #2가 세운 그 판 — 첫 판은 707px이라
	#   좌우로 33px씩 화면 밖으로 나갔다). R16 ③은 인자 없는 호출만 훑으므로 지목 갈래는 여기서 잰다.
	var banner_view: Vector2 = m.onboarding_banner._view()
	var named_plate: float = HanjiUi.text_width(g2, m.onboarding_banner.FONT_SIZE) \
		+ m.onboarding_banner.PAD_X * 2.0
	var empty_plate: float = HanjiUi.text_width(m.onboarding.guidance(false, ""),
		m.onboarding_banner.FONT_SIZE) + m.onboarding_banner.PAD_X * 2.0
	_check("⑳e 두 갈래의 배너 판이 뷰포트(%.0fpx) 안에 든다 — 지목 %.0fpx · 씨앗 0 %.0fpx"
			% [banner_view.x, named_plate, empty_plate],
		named_plate <= banner_view.x and empty_plate <= banner_view.x)
	m.onboarding.step = step0
	_clear_backpack(m)

# ── ㉑ #24 모달이 덮었으면 모달이 닫힐 때 재개한다 ───────────────────────────
func _check_banner_resume(m: Node) -> void:
	print("㉑ #24 안내 배너 ↔ 모달")
	var step0: int = m.onboarding.step
	m.onboarding.step = Onboarding.TILL
	m._last_onboarding_guide = m.onboarding.guidance(false, m._onboarding_seed_name())
	_check("㉑a 무대: TILL 단계 배너가 한 번 떴다(래치에 그 문구가 실렸다) — 「%s」"
			% m._last_onboarding_guide, m._last_onboarding_guide != "")
	m.onboarding_banner.hide_now()
	_check("㉑b 무대: 모달이 배너를 즉시 지웠다(남은 유지시간을 통째로 버린다)",
		m.onboarding_banner._secs == 0.0 and m.onboarding_banner.modulate.a == 0.0)
	m._forget_onboarding_guide()
	_check("㉑c 덮은 쪽이 래치를 되감았다 — 래치 「%s」" % m._last_onboarding_guide,
		m._last_onboarding_guide == "")
	# 모달이 닫힌 첫 프레임의 그 비교가 다시 참이 되어 배너가 되돌아온다.
	var guide: String = m.onboarding.guidance(false, m._onboarding_seed_name())
	_check("㉑d 같은 단계 문구가 래치와 달라 배너가 다시 뜬다(종전엔 같아서 영영 안 떴다)",
		guide != "" and guide != m._last_onboarding_guide)
	m.onboarding_banner.show_guide(guide)
	_check("㉑e 실제로 다시 떴다 — 알파 %.1f · 남은 %.1f초"
			% [m.onboarding_banner.modulate.a, m.onboarding_banner._secs],
		m.onboarding_banner.modulate.a > 0.0 and m.onboarding_banner._secs > 0.0)
	_check("㉑f 배선: 배너를 지우는 세 모달(컷신·대화·프레임)이 전부 래치를 되감는다",
		_count_in_func(_src, "func _process", "_forget_onboarding_guide()") == 3)
	m.onboarding.step = step0
	m.onboarding_banner.hide_now()

# ── ㉒ #25 오프닝 통보 중에는 시간이 흐르지 않는다 ───────────────────────────
func _check_intro_clock(m: Node) -> void:
	print("㉒ #25 오프닝 통보 ↔ 시계")
	var step0: int = m.onboarding.step
	var running0: bool = m.clock.running
	var minutes0: float = m.clock.minutes
	_dismiss_dialogue(m)
	m.clock.running = true
	m.onboarding.step = Onboarding.NOTICE
	m._maybe_start_intro()
	_check("㉒a 무대: 통보가 실제로 열렸다(대화 %s · 옥자 %s)"
			% [str(m.dialogue.is_open()), str(m.okja.visible)],
		m.dialogue.is_open() and m.okja.visible)
	_check("㉒b 이동이 잠긴다(종전에도 있던 그 잠금 — 거동 불변)",
		not m.player.is_physics_processing())
	_check("㉒c **시계도 멈춘다** — running %s(형제 셋 컷신·내면·에필로그가 든 그 문법)"
			% str(m.clock.running), not m.clock.running)
	# 미호가 카페로 출근하는 그 시각까지 흐를 만큼 틱을 굴려도 분침이 안 움직인다.
	var ticks := 0
	while ticks < 200:
		m.clock._process(1.0)   # 시간이 실제로 흐르는 그 경로(running 게이트를 그대로 탄다)
		ticks += 1
	_check("㉒d 통보를 읽는 동안 분침이 한 칸도 안 간다 — %.0f분 그대로(옥자의 「밭에 있으니」가 참으로 남는다)"
			% m.clock.minutes, is_equal_approx(m.clock.minutes, minutes0))
	_dismiss_dialogue(m)
	await process_frame
	_check("㉒e 통보가 끝나면 시계가 스냅값으로 되돌아온다 — running %s" % str(m.clock.running),
		m.clock.running)
	m.onboarding.step = step0
	m.clock.running = running0
