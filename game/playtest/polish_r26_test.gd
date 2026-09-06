extends SceneTree
# ★[폴리시 26회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#5) + 배치 B(#6~#9).
#
# 렌즈: R25 diff 리뷰(#0~#3) · 세이브/로드 고정점(#4) · 중복 술어 표류(#5) ·
#       기계 시간 원장(#6·#7) · 문↔워프 대칭(#8) · 거절 경로 무결성(#9).
#
# 이 두 배치의 태도 넷.
#   ㉠ **계약을 뒤집으면 그 계약의 소비처를 전수로 세워야 한다.** #0·#1은 같은 뿌리다 — R25 #17이
#      약탈 집계를 «노드는 계약만 쏘고 소비처가 실손실을 되돌린다»로 갈랐는데, main 말고
#      NightBar를 직접 굴리는 무대 둘(cocktail_test의 맨몸 바 · 밸런스 시뮬 봇)이 소비처를 안
#      세워 한쪽은 red로, 다른 한쪽은 **조용히 0인 수치**로 남았다. 프로덕션 계약은 옳으므로
#      되돌리지 않고 무대를 계약에 맞춘다.
#   ㉡ **좁히는 봉합은 «무엇까지 좁혔나»를 되물어야 한다.** #3은 R25 #22가 막으려던 것(다음 절기
#      전용 종)과 함께 **그날 실제로 돋아 있는 현 절기 종까지** 지운 자리다. 그래서 ④는 하한
#      (다음 절기 종은 여전히 빠진다)과 회복(현 절기 종이 후보 풀에 실제로 산다)을 같이 잰다.
#   ㉢ **가드는 양방향이어야 하고, 우연히 막힌 것은 막힌 게 아니다.** #5는 반대 방향
#      (`_is_tree_seed_free` → 밑동)이 이미 서 있는데 과수 방향만 원장을 안 봐 단방향이던 자리고,
#      #8은 건물 문 열두 칸 중 열한 칸이 «풋프린트가 facade 벽을 문다»는 **우연**으로만 막혀 있던
#      자리다(실측). ⑥·⑨는 그 둘을 규칙으로 바꾼 뒤 양쪽을 나란히 묻는다.
#   ㉣ **굳는 값과 살아 있는 값을 한 식에 섞지 않는다.** #6은 분자(투입 시점 스냅샷)와 분모(매
#      프레임 다시 판 퍼크)가 서로 다른 시점을 봐서 띠 폭이 음수가 된 자리다 — 원장이 자기 눈금의
#      두 끝을 다 들게 해 갈릴 자리를 없앤다.
#
# 무엇을 보증하나(번호 = 26회차 헌트 발견 인덱스).
#   ① #0 소비처 0인 맨몸 NightBar는 돌파해도 `_raided`가 안 오른다(R25 #17 계약) — cocktail_test의
#      guard가 그 사실을 모른 채 `tonight_raided()` 증분을 재 red였다.
#   ② #1 같은 미배선이 밸런스 시뮬에서는 **실패 없이 수치만 거짓**으로 남았다(약탈 사슬 증발).
#   ③ #2 출하함 행이 고정 150px이라 R25 #14가 붙인 등급 앞머리가 개수(`×N`)를 밀어냈다.
#   ④ #3 절기 경계 게시분에서 채집물 갈래가 통째로 사라졌다(연 4일 — 폴백이 작물로 덮어 조용했다).
#   ⑤ #4 `"greenhouse"` 키만 `has` 가드가 남아, 버린 타임라인의 늘봄방 작물이 구세이브에 굳었다.
#   ⑥ #5 `_is_tree_blocked`만 자체 파종 원장을 안 봐, 밑동이 마당 파종목 위에 겹쳐 섰다(비가역).
#   ⑦ #6 업화로 진행 띠의 분모가 살아 있는 퍼크값이라, 제련 중 [제련공] 선택이 폭을 음수로 만들었다.
#   ⑧ #7 목공방 요약의 «내일 아침 완공»이 **어떤 날짜로도 안 뜨는** 죽은 문구였다(문턱 0).
#   ⑨ #8 건물 문·퇴장 착지 칸이 나무 술어에 한 줄도 없어, 넋둥우리 착지 칸에 밑동이 섰다(영구 SOLID).
#   ⑩ #9 장원제 래치가 부상 지급보다 앞서, 만재 시 연 1회 기회와 부상이 함께 증발했다.
#
# 판정: #0~#9 **전건 CONFIRMED**(10건 봉합) · REFUTED·DUP·OWNER 0.
#   ★ #5와 #8은 **형제이되 별개 결함**이다(배치 A 판정을 배치 B가 실측으로 확인): 둘 다
#     `_is_tree_blocked`의 누락 항이지만 항이 다르다 — #5는 런타임 나무 원장(`_tree_occupied_at`),
#     #8은 건물 문·착지 칸(`_building_door_reserved`)이고, 어느 한 줄도 다른 쪽 칸을 안 막는다.
#     ⑥f가 두 항이 각자 서 있음을 든다.
#
# 하중 검증(파괴 10배치 — 봉합을 되돌리면 실제로 red가 남는가 · 전건 확인):
#   #0 cocktail_test guard 소비처의 `record_raid` 삭제 → cocktail ⓔe red(0 == 3) · ①d red
#   #1 `_run_night`의 sink 배선 삭제·옛 `attempted := night.tonight_raided()` 복귀 → ②a·②b red
#   #2 좌측 폭을 `150.0` 고정으로 복귀            → ③a' red(그리는 줄이 파생 예산을 안 쓴다)
#      ★ ③b·③c는 **파괴에 안 죽는다**(헬퍼는 그대로라 값이 안 흔들린다) — 그 둘은 «얼마나
#        넘쳤나/들어가나»를 실측하는 무대 단언이고, 하중은 ③a'가 든다(파괴 실측으로 갈랐다).
#   #3 기한 절기 항(`and …due_day`) 부활          → ④a·④b·④d red(경계 게시분 **절기 전용** 채집물 0종)
#      ★ ④d는 사철종을 세면 파괴에 안 죽는다(그쪽은 교집합도 통과시켰다) — 절기 전용 갈래만 센다.
#   #4 `data.get("greenhouse", {})`를 `has` 가드로 복귀 → ⑤a·⑤d red(버린 밭이 살아남는다)
#   #5 `_is_tree_blocked`의 `_tree_occupied_at` 줄 삭제 → ⑥a·⑥c·⑥f red(파종목 위에 밑동이 선다)
#   #6 분모를 `smelt_minutes(ore, smelt_time_cut())`로 복귀 → ⑦a red · `load_ore`의 total 삭제 →
#      ⑦b·⑦c'·⑦d·⑦e red(굳은 총 분이 0이 되어 비율이 무너진다)
#   #7 문턱을 `left <= 0`으로 복귀                → ⑧a·⑧b·⑧c·⑧d red(전 프로젝트에서 0/N 도달)
#   #8 `_building_door_reserved` 줄 삭제          → ⑨a·⑨b·⑨c·⑥f red(착지 칸이 다시 `can_plant`)
#   #9 `_grange_awards_fit` 선검사 삭제           → ⑩a·⑩b·⑩c red(만재인데 래치가 찍히고 부상이 증발)
#
# 실행: ./run_tests.sh polish_r26   (헤드리스는 반드시 game/에서 · 순차)

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

# ── 소스 스캔 헬퍼(polish_r7~r25 관례 — 니들은 반드시 함수 안에서 센다) ──────
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

# 그 함수 안에서 니들이 처음 나오는 **줄 번호**(−1 = 없음). 두 줄의 선후를 재는 자리에 쓴다
# (polish_r11 이후 관례 — «어느 쪽이 먼저 도는가»가 계약인 봉합의 회귀 도구).
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

# 맨몸 NightBar(트리에 안 붙이므로 스폿 초기화를 직접 부른다 — night_bar_test·cocktail_test 관례).
func _new_bar() -> NightBar:
	var b := NightBar.new()
	b._ready()
	return b

# 그 바를 한 번 돌파시킨다(자동 차단은 끄고 — 순수 약탈 갈래).
func _force_breach(b: NightBar) -> void:
	b._auto_blocks_left = 0
	b._spots[0] = {"active": true, "approach": 0.05, "max_approach": 5.0}
	b.tick(0.1, 20 * 60)

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R26 회귀 — 배치 A(#0~#5) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_check("무대 전제: main(%d행)을 읽었다(부정 단언 공허 통과 방지)" % _src.size(), _src.size() > 1000)

	_check_raid_consumer_stage()     # ① #0(무대 불요 — 순수 NightBar)
	_check_bot_raid_model()          # ② #1(봇은 SceneTree라 배선 + 등가 모델로 잰다)
	_check_quest_season_edge()       # ④ #3(무대 불요 — 순수 카탈로그)

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

	await _check_bin_row_width(m)    # ③ #2
	_check_tree_ledger_sanctuary(m)  # ⑥ #5

	print("══ 폴리시 R26 회귀 — 배치 B(#6~#9) ══")
	_check_furnace_scale()           # ⑦ #6(무대 불요 — 순수 FurnaceLedger)
	_check_carpenter_summary()       # ⑧ #7(무대 불요 — 순수 Carpenter)
	_check_building_door_sanctuary(m)   # ⑨ #8
	_check_grange_award_order(m)     # ⑩ #9
	await _check_greenhouse_rewind(m)   # ⑤ #4 — 세이브 파일을 쓰므로 맨 끝

	# ★ 이 스위트는 ⑤에서 세이브를 **쓴다**(구세이브 되감기가 파일 경로를 타야 하는 검증이라
	#   무대가 곧 파일이다). 끝나면 지운다 — polish_r24 ⑮·polish_r25 ⑩이 세운 그 관례.
	SaveManager.new().delete_save()
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 «소비처 없는 바는 약탈을 집계하지 않는다»가 계약이다 ────────────────
func _check_raid_consumer_stage() -> void:
	print("① #0 R25 #17 계약 ↔ 맨몸 NightBar 무대")
	# ㉠ 계약 자체 — 노드는 돌파 사실만 쏘고, 집계는 한 톨도 안 한다.
	var bare := _new_bar()
	bare.open_bar(20 * 60)
	var got: Array = []
	bare.resolved.connect(func(r): got.append(r))
	_force_breach(bare)
	_check("①a 돌파 계약은 그대로 온다 — %d건 {repelled:%s, raided:%d}(요구량 = raid_amount %d)"
			% [got.size(), str(got[0]["repelled"]) if got.size() > 0 else "-",
				int(got[0]["raided"]) if got.size() > 0 else -1, bare.raid_amount],
		got.size() == 1 and not bool(got[0]["repelled"])
			and int(got[0]["raided"]) == bare.raid_amount and bare.raid_amount > 0)
	_check("①b **소비처가 `record_raid`를 안 부르면 집계는 0이다** — `tonight_raided()` = %d(R25 #17 계약)"
			% bare.tonight_raided(), bare.tonight_raided() == 0)
	bare.free()
	# ㉡ 무대를 계약에 맞추면 종전 수치가 그대로 돌아온다(재고가 넉넉한 소비처 = 요구량 전량 확정).
	var wired := _new_bar()
	wired.open_bar(20 * 60)
	wired.resolved.connect(func(r):
		if not bool(r.get("repelled", false)):
			wired.record_raid(int(r.get("raided", 0))))
	_force_breach(wired)
	_check("①c 소비처를 세우면 그 돌파가 집계된다 — %d개(= raid_amount %d · cocktail_test guard가 선 무대)"
			% [wired.tonight_raided(), wired.raid_amount],
		wired.tonight_raided() == wired.raid_amount)
	wired.free()
	# ㉢ 그 무대가 실제로 cocktail_test 안에 서 있는가(니들은 함수 안에서).
	var csrc := _lines_of_file("res://playtest/cocktail_test.gd")
	_check("①d 배선: cocktail_test의 guard 소비처가 실손실을 되돌린다(`record_raid` 1창구)",
		_count_in(csrc, "func _run_checks", "guard.record_raid(int(r.get(\"raided\", 0)))") == 1)

# ── ② #1 밸런스 시뮬의 약탈 사슬이 실제로 굴러간다 ──────────────────────────
func _check_bot_raid_model() -> void:
	print("② #1 밸런스 시뮬 ↔ 밤 약탈 모델")
	var bsrc := _lines_of_file("res://playtest/playtest_bot.gd")
	# 배선 — 소비처를 세우고(connect), 실손실을 되돌리고(record_raid), 밤이 끝나면 끊는다(21일 재사용).
	_check("②a 배선: `_run_night`이 소비처를 세우고 실손실을 되돌린다(connect 1 · record_raid 1 · disconnect 1)",
		_count_in(bsrc, "func _run_night", "night.resolved.connect(sink)") == 1
			and _count_in(bsrc, "func _run_night", "night.record_raid(_deduct_raid(inv, want))") == 1
			and _count_in(bsrc, "func _run_night", "night.resolved.disconnect(sink)") == 1)
	_check("②b 배선: 옛 «밤이 끝난 뒤 `tonight_raided()`를 요구량으로 읽는» 줄이 없다(그 값은 이제 실손실이다)",
		_count_in(bsrc, "func _run_night", "var attempted: int = night.tonight_raided()") == 0
			and _count_in(bsrc, "func _run_night", "\"raid_actual\": night.tonight_raided()") == 1)
	# 등가 모델 — 봇은 SceneTree라 여기서 인스턴스로 못 세운다. 같은 배선을 세워 두 칸의 뜻을 잰다.
	# 재고가 요구량보다 적으면 «노린 양»과 «실제로 빠진 양»이 갈린다(ADR-0010 이중 손실 ㉮의 무막힘).
	var inv := Inventory.new()
	var crop := String(CropCatalog.ids()[0])
	inv.add_harvest(crop, 1)
	var bar := _new_bar()
	bar.raid_amount = 3
	bar.open_bar(20 * 60)
	var tally := {"attempted": 0}
	bar.resolved.connect(func(r):
		if bool(r.get("repelled", false)):
			return
		var want: int = int(r.get("raided", 0))
		tally["attempted"] = int(tally["attempted"]) + want
		var removed := 0
		while removed < want and inv.take_harvest(crop):
			removed += 1
		bar.record_raid(removed))
	_force_breach(bar)
	_check("②c 모자란 재고에선 두 칸이 갈린다 — 노린 %d개 ↔ 실제 %d개(재고 1개 · 무막힘)"
			% [int(tally["attempted"]), bar.tonight_raided()],
		int(tally["attempted"]) == 3 and bar.tonight_raided() == 1
			and inv.total_harvest() == 0)
	# 넉넉하면 두 칸이 같다 — 사슬이 «항상 0»이 아니라 재고에 실제로 반응한다는 대조군.
	inv.add_harvest(crop, 9)
	tally["attempted"] = 0
	_force_breach(bar)
	_check("②d 넉넉한 재고에선 두 칸이 같다 — 노린 %d개 = 실제 증분(재고 9→%d개)"
			% [int(tally["attempted"]), inv.total_harvest()],
		int(tally["attempted"]) == 3 and bar.tonight_raided() == 4 and inv.total_harvest() == 6)
	bar.free()

# ── ③ #2 출하함 행 폭이 판 기하에서 파생한다(등급 앞머리가 개수를 안 민다) ───
func _check_bin_row_width(m: Node) -> void:
	print("③ #2 출하함 행 폭 ↔ 등급 앞머리")
	var frame: InventoryFrame = m.frame
	if frame == null or m.ship_bin == null:
		_check("③ 무대: 출하함 패널·원장이 있다", false)
		return
	# 최악 조합을 **로스터에서** 판다(id·이름 옮겨 적기 0) — 최고 등급 × 출하되는 최장 이름.
	var top_q: int = ItemCatalog.Q_IRIDIUM
	var longest := ""
	var longest_id := ""
	var roster: Array = []
	roster.append_array(FishCatalog.ids())
	roster.append_array(CropCatalog.ids())
	roster.append_array(ItemCatalog.FORAGEABLES.keys())
	for id0 in roster:
		var nm := ItemCatalog.name_of(String(id0))
		if nm.length() > longest.length():
			longest = nm
			longest_id = String(id0)
	_check("③a 무대: 출하되는 최장 이름 「%s」(%d자 · %d종에서)을 로스터에서 찾았다"
			% [longest, longest.length(), roster.size()],
		longest.length() >= 5 and longest_id != "")
	var worst := "%s %s ×%d" % [ItemCatalog.quality_name(top_q), longest, 3]
	var subs := "+%d" % 9999
	var panel: Rect2 = frame._panel_rect()
	var budget: float = frame.bin_row_left_budget(panel, subs)
	# 배선 — **그리는 줄이 그 예산을 실제로 쓴다**(헬퍼만 있고 그리기가 옛 상수를 쓰면 초록이 공허하다).
	var isrc := _lines_of_file("res://inv_frame.gd")
	_check("③a' 배선: 그리는 줄이 파생 예산을 쓴다(고정 폭 리터럴 0 · 말줄임 경유 1)",
		_count_in(isrc, "func _draw_bin_top", "var left_budget := bin_row_left_budget(panel, subs)") == 1
			and _count_in(isrc, "func _draw_bin_top", "150.0") == 0
			and _count_in(isrc, "func _draw_bin_top", "HanjiUi.elide(left_txt, 13, left_budget)") == 1)
	_check("③b **종전 고정 150px에선 넘쳤다** — 「%s」 = %.0fpx > 150px(개수가 폭 밖으로 밀렸다)"
			% [worst, HanjiUi.text_width(worst, 13)],
		HanjiUi.text_width(worst, 13) > 150.0)
	_check("③c 새 예산에는 들어간다 — %.0fpx ≤ %.0fpx(판 기하 파생 · 우측 정산액 자리를 뺀 나머지)"
			% [HanjiUi.text_width(worst, 13), budget],
		HanjiUi.text_width(worst, 13) <= budget
			and HanjiUi.elide(worst, 13, budget) == worst)
	# ★[폴리시 R15 규약] 표시 단언은 **그리기 경로를 태운다** — 실물을 넣고 판을 열어 행을 그린다.
	var ship_id := longest_id
	m.ship_bin.add(ship_id, 3, top_q)
	m._open_frame(InventoryFrame.CTX_BIN)
	await process_frame
	await process_frame
	var rows: Array = frame.bin_rows()
	var drawn: int = frame._bin_rects.size()
	_check("③d 그리기 경로가 그 행을 실제로 그린다 — 행 %d개 · 회수 히트 %d개(등급 %d 「%s」 ×3)"
			% [rows.size(), drawn, top_q, ItemCatalog.name_of(ship_id)],
		rows.size() >= 1 and drawn == mini(rows.size(), frame.top_rows_visible()))
	# 그 행의 문구가 등급·이름·개수 셋을 **다** 말한다(잘리는 쪽이 개수였던 자리).
	var label := ""
	for r in rows:
		if String(r["id"]) == ship_id and int(r["quality"]) == top_q:
			label = frame.bin_row_label(r)
	_check("③e 행 문구가 셋을 다 말한다 — 「%s」(등급 앞머리 + 이름 + ×3 · 말줄임 0)" % label,
		label.contains(ItemCatalog.quality_name(top_q)) and label.contains(ItemCatalog.name_of(ship_id))
			and label.ends_with("×3") and not label.contains("…")
			and HanjiUi.elide(label, 13, frame.bin_row_left_budget(panel, "+%d" % 999)) == label)
	m._close_frame()
	m.ship_bin.take_back(ship_id, 3, top_q)

# ── ④ #3 절기 경계 게시분에서 «그날 돋아 있는» 채집물이 산다 ─────────────────
func _check_quest_season_edge() -> void:
	print("④ #3 절기 경계 의뢰 ↔ 게시일 축")
	var qsrc := _lines_of_file("res://quest_board.gd")
	_check("④a 배선: 판정 축은 **게시일 하나**다(기한 절기 항으로 통과하는 창구도, 거절하는 창구도 0)",
		_count_in(qsrc, "static func _obtainable_between",
			"return s == GameClock.season_index_for_day(post_day)") == 1
			and _count_in(qsrc, "static func _obtainable_between",
				"s == GameClock.season_index_for_day(due_day)") == 0)
	var edge := GameClock.DAYS_PER_SEASON            # 절기 마지막 날 = 게시일(기한은 다음 절기 첫날)
	var post_s := GameClock.season_index_for_day(edge)
	var due_s := GameClock.season_index_for_day(edge + 1)
	_check("④b' 무대: day %d 게시분의 기한이 다음 절기다(게시 절기 %d ↔ 기한 절기 %d)"
			% [edge, post_s, due_s], post_s != due_s)
	var next_only := ""
	var same_season := ""
	var deep := ""
	for sp in ForageSpawns.all_species():
		var id := String(sp)
		if not ItemCatalog.FORAGEABLES.has(id):
			continue
		if ForageSpawns.is_deep_gated(id):
			if deep == "":
				deep = id
			continue
		var s := ForageSpawns.season_of(id)
		if s == due_s and next_only == "":
			next_only = id
		elif s == post_s and same_season == "":
			same_season = id
	_check("④b'' 무대: 다음 절기 전용 「%s」 · 그 절기 종 「%s」을 로스터에서 찾았다"
			% [ItemCatalog.name_of(next_only), ItemCatalog.name_of(same_season)],
		next_only != "" and same_season != "")
	if next_only == "" or same_season == "":
		return
	_check("④b **그 절기 종이 경계 게시분에 산다** — 「%s」(게시일에 실제로 돋아 있다 · R25 교집합이 지웠던 갈래)"
			% ItemCatalog.name_of(same_season),
		QuestBoard._obtainable_between(same_season, edge, edge + 1))
	_check("④c 하한 유지: 다음 절기 전용 종은 여전히 빠진다 — 「%s」(게시일 세계에 한 톨도 없다)"
			% ItemCatalog.name_of(next_only),
		not QuestBoard._obtainable_between(next_only, edge, edge + 1))
	# 하중 — 후보 풀에 **그 절기 전용 채집물이 몇 종 사는가**. 사철종(season_of < 0)은 교집합에서도
	#   통과했으므로 그것까지 세면 단언이 공허하다(파괴해도 안 죽는다) — 갈린 것은 절기 전용 갈래다.
	var pool: Array = QuestBoard.item_pool_for(edge, edge + 1)
	var season_forage := 0
	var evergreen_forage := 0
	var crops_in_pool := 0
	for pid in pool:
		var pids := String(pid)
		if not ItemCatalog.FORAGEABLES.has(pids):
			crops_in_pool += 1
		elif ForageSpawns.season_of(pids) == post_s:
			season_forage += 1
		else:
			evergreen_forage += 1
	_check("④d 경계 게시분 후보 풀에 **그 절기 전용 채집물**이 산다 — 절기종 %d + 사철종 %d + 작물 %d(종전엔 절기종 0 = 연 4일 갈래 소실)"
			% [season_forage, evergreen_forage, crops_in_pool],
		season_forage > 0 and crops_in_pool > 0 and pool.size() < QuestBoard.item_pool().size())
	# R20 #14 불변 — 심층 게이트 종은 어느 날짜에도 안 선다(축을 좁힌 것이 이 가드를 안 건드렸다).
	if deep != "":
		_check("④e R20 #14 불변: 심층 게이트 종은 그대로 빠진다 — 「%s」(경계 · 절기 한복판 둘 다)"
				% ItemCatalog.name_of(deep),
			not QuestBoard._obtainable_between(deep, edge, edge + 1)
				and not QuestBoard._obtainable_between(deep, edge - 2, edge - 1))
	_check("④f 경계가 아닌 날은 종전 그대로다(거동 축소 0) — 「%s」 day %d~%d"
			% [ItemCatalog.name_of(same_season), edge - 2, edge - 1],
		QuestBoard._obtainable_between(same_season, edge - 2, edge - 1))

# ── ⑤ #4 늘봄방 경작면도 로드가 되감는다(has 가드 잔여) ─────────────────────
func _check_greenhouse_rewind(m: Node) -> void:
	print("⑤ #4 늘봄방 경작면 ↔ 구세이브 되감기")
	_check("⑤a 배선: `_load_game`이 늘봄방 밭을 **무조건** 되감는다(`has` 가드 0 · `.get(키, {})` 1)",
		_count_in(_src, "func _load_game", "if data.has(\"greenhouse\"):") == 0
			and _count_in(_src, "func _load_game",
				"greenhouse_farm.load_save(data.get(\"greenhouse\", {}))") == 1)
	# 판별식의 근거 — 이 밭엔 부팅 시드가 없다(생성 한 줄뿐이고 `_refresh_greenhouse`는 안 건드린다).
	_check("⑤b 근거: 늘봄방 밭을 채우는 부팅 시드가 없다(`_refresh_greenhouse`가 그 밭을 안 건드린다)",
		_count_in(_src, "func _refresh_greenhouse", "greenhouse_farm") == 0)
	# 판별식의 반대쪽은 그대로 둔다 — 맵에서 다시 시드하는 여섯은 가드 유지(거동 축소 0).
	var still_guarded := 0
	for key in ["forage", "flower_patch", "forage_spawn", "berry_bush", "panning", "tree_ledger"]:
		if _count_in(_src, "func _load_game", "if data.has(\"%s\"):" % key) == 1:
			still_guarded += 1
	_check("⑤c 판별식의 반대쪽은 그대로 — 맵에서 다시 까는 여섯은 가드 유지(%d/6)" % still_guarded,
		still_guarded == 6)
	# 거동 — 늘봄방 경작면을 실제로 채우고, 그 키만 뺀 «구세이브»를 F9로 읽는다.
	# 무대 조립 — 늘봄방을 세운다(경작면은 완공 파생이라 안 지으면 그 좌표가 그냥 VOID다).
	m.carpenter._done[Carpenter.PROJ_GREENHOUSE] = 1
	m._refresh_greenhouse()
	# 경작면 칸은 **술어에서** 찾는다(좌표 옮겨 적기 0 — 부지가 옮겨 가면 이 무대도 따라간다).
	var gt: Vector2i = Vector2i(-1, -1)
	for y in range(0, 96):        # 늘봄방 경작면은 **실내 밴드**라 노지보다 아래에 있다(좌표 공간 분리)
		for x in range(0, 100):
			if m._in_greenhouse_plot(Vector2i(x, y)):
				gt = Vector2i(x, y)
				break
		if gt.x >= 0:
			break
	_check("⑤d° 무대: 늘봄방 경작면 칸 (%d,%d)를 술어에서 찾았다" % [gt.x, gt.y], gt.x >= 0)
	if gt.x < 0:
		return
	var crop := String(CropCatalog.ids()[0])
	m.greenhouse_farm.hoe(gt)
	m.greenhouse_farm.plant(gt, crop)
	m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	_check("⑤d' 무대: 늘봄방 경작면에 「%s」이 서 있고 그것이 파일에도 실렸다" % ItemCatalog.name_of(crop),
		m.greenhouse_farm.is_planted(gt) and raw.has("greenhouse")
			and m.greenhouse_farm.planted_tiles().size() >= 1)
	raw.erase("greenhouse")               # S10-T5 이전 구세이브 = 그 키가 아예 없다
	m.saver.save_game(raw, m._active_slot)
	var ok: bool = m._load_game()
	await process_frame
	_check("⑤d'' 그 구세이브가 정상적으로 읽힌다(무대 전제 — 로드 실패가 아니라 되감기를 잰다)", ok)
	_check("⑤d **경작면이 되감긴다** — 심긴 칸 %d개 · 괭이질 칸 %d개(종전엔 버린 타임라인의 밭이 살아남아 재세이브에 굳었다)"
			% [m.greenhouse_farm.planted_tiles().size(), m.greenhouse_farm.tilled_tiles().size()],
		m.greenhouse_farm.planted_tiles().is_empty() and m.greenhouse_farm.tilled_tiles().is_empty())
	# 대조군 — 키가 있는 세이브는 그대로 돌아온다(왕복이 편도가 아니다).
	m.greenhouse_farm.hoe(gt)
	m.greenhouse_farm.plant(gt, crop)
	m._save_game()
	var ok2: bool = m._load_game()
	await process_frame
	_check("⑤e 대조군: 키가 있는 세이브는 그 밭을 그대로 되살린다(왕복 — 「%s」 %d칸)"
			% [ItemCatalog.name_of(crop), m.greenhouse_farm.planted_tiles().size()],
		ok2 and m.greenhouse_farm.is_planted(gt) and m.greenhouse_farm.crop_of(gt) == crop)

# ── ⑥ #5 자체 파종 원장 칸은 혼의 나무에도 성역이다(가드가 양방향) ───────────
func _check_tree_ledger_sanctuary(m: Node) -> void:
	print("⑥ #5 과수 심기 ↔ 자체 파종 원장")
	# ★[폴리시 R27 #0] **항의 자리가 옮겨졌다 — 폭이 틀렸기 때문이다.** R26이 넣은 자리
	#   (`_is_tree_blocked`)는 `orchard.can_plant`가 풋프린트 **아홉 칸 전부**에 부르는 술어라
	#   캐노피 여덟 칸까지 함께 거절했는데, R26이 스스로 선언한 결함은 앵커 한 칸의 것이다
	#   (「한 칸을 두 원장이 쥔 채 두 재구성이 **같은 칸에** 콜라이더를 세웠다」 — 밑동 콜라이더는
	#   앵커에만 서고, 마당 원장 나무 쪽도 발치 행만 막는다). 그래서 항은 `_would_entrap_player`와
	#   같은 앵커 갈래(`_use_tool` 묘목 가지)로 갔다. 재는 계약은 그대로 «파종목 칸엔 밑동을 못
	#   세운다»이고, **폭**이 앵커로 좁혀졌다.
	_check("⑥a 배선: 원장 항은 3×3 전수 술어가 아니라 **앵커 갈래**가 든다(R19 #17이 같은 이유로 세운 그 자리)",
		_count_in(_src, "func _is_tree_blocked", "_tree_occupied_at(t)") == 0
			and _count_in(_src, "func _use_tool", "elif _tree_occupied_at(_target):") == 1)
	_check("⑥b 배선: 반대 방향 짝이 그대로다 — `_is_tree_seed_free`가 밑동을 거절한다(양방향)",
		_count_in(_src, "func _is_tree_seed_free", "orchard.trunk_tiles()") == 1)
	# 무대 — 지금 판에서 **실제로 심을 수 있는** 앵커를 찾는다(좌표 옮겨 적기 0).
	var anchor := Vector2i(-1, -1)
	for y in range(6, 40):
		for x in range(30, 70):
			var a := Vector2i(x, y)
			if m.orchard.can_plant(a, m._is_tree_blocked):
				anchor = a
				break
		if anchor.x >= 0:
			break
	_check("⑥b' 무대: 지금 마당에 심을 수 있는 앵커 (%d,%d)를 찾았다" % [anchor.x, anchor.y],
		anchor.x >= 0)
	if anchor.x < 0:
		return
	# 그 칸에 밤새 나무가 돋았다고 치고(`_seed_pass`가 쓰는 그 항목 모양) 다시 묻는다.
	m.tree_ledger._put(RegionCatalog.HOME, anchor,
		{"species": TreeLedger.species_at_tile(RegionCatalog.HOME, anchor), "stage": 1,
		"hp": TreeLedger.hp_for_stage(1), "stump": false, "moss": false})
	# ★[폴리시 R27 #0] 판정 창구가 `_is_tree_blocked`에서 앵커 술어로 바뀌었다. 재는 것은 같다 —
	#   그 칸에 밑동이 **서지 않는다**(원장이 한 칸을 둘로 쥐지 않는다).
	_check("⑥c **파종목 칸엔 밑동이 안 선다** — `_tree_occupied_at` %s(종전엔 뚫려 두 원장이 한 칸을 쥐었다)"
			% str(m._tree_occupied_at(anchor)),
		m._tree_occupied_at(anchor) and not m.orchard.has_tree(anchor))
	# ★[폴리시 R27 #0] **캐노피는 성역이 아니다** — 앵커에서 한 칸 비켜선 자리는 그 원장 나무를
	#   이유로 막히지 않는다(형제 술어 `_orchard_trunk_at` 머리말이 못 박은 그 원칙의 짝).
	#   R26 직후엔 이 여덟 칸이 전부 «못 심음»이었다.
	var canopy_ok := false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var cand: Vector2i = anchor + d
		if not m._tree_occupied_at(cand) and Orchard.footprint_of(cand).has(anchor) \
				and m.orchard.can_plant(cand, m._is_tree_blocked):
			canopy_ok = true
			break
	_check("⑥c' 캐노피가 그 나무를 덮는 이웃 앵커는 여전히 심긴다(막는 폭 = 밑동 한 칸)", canopy_ok)
	# 형제 배치 가드 셋도 같은 칸을 거절한다 — 이 술어가 그 표의 단일 출처라는 증거.
	_check("⑥d 형제 셋도 같은 칸을 거절한다(같은 술어 하나에서 파생 — 스프링클러·업화로·결정기)",
		not m._can_place_sprinkler(anchor) and not m._can_place_furnace(anchor)
			and not m._can_place_crystalarium(anchor))
	# 성역은 **영구가 아니다** — 벌목해 원장이 비면 그 자리는 다시 열린다(거동 축소 0).
	m.tree_ledger.clear_slot(RegionCatalog.HOME, anchor)
	_check("⑥e 원장이 비면 그 자리는 다시 열린다(막는 것은 새로 심는 것뿐 — 구세이브 탈출구)",
		not m._tree_occupied_at(anchor) and m.orchard.can_plant(anchor, m._is_tree_blocked))
	# ★ 배치 B #8 비커버 명문화 — 이 봉합이 더한 것은 **원장 항 하나**다. #8이 요구하는 건물 문·
	#   퇴장 착지 칸 항은 이 술어에 아직 없고, 그 칸들은 PATH라 원장에도 안 실린다 — 즉 ⑥의 초록은
	#   #8의 초록이 아니다(그쪽 워커가 따로 봉합한다).
	# ★[배치 B에서 갱신] 배치 A 때 이 자리는 «#8 비커버»를 못 박는 단언이었다(원장 항 하나만 더한
	#   봉합이 건물 문 칸을 안 막는다는 사실). 배치 B가 #8을 별도 항으로 봉합했으므로 **커버 단언**
	#   으로 뒤집는다 — 두 결함이 별개라는 사실은 그대로고(항이 둘), 이제 둘 다 서 있다.
	# ★[폴리시 R27 #0] 원장 항은 앵커 갈래로 이사했고, 건물 문 항은 폭이 맞아 제자리다(완공·워프가
	#   3×3을 통째로 덮으므로 그쪽은 전수 평가가 계약이다 — polish_r19 ⑧e가 같은 폭을 명시로 잰다).
	_check("⑥f 두 누락 항이 **모두** 섰다 — 원장(#5)은 앵커 갈래에 · 건물 문·착지 칸(#8)은 3×3 전수 술어에",
		_count_in(_src, "func _use_tool", "elif _tree_occupied_at(_target):") == 1
			and _count_in(_src, "func _is_tree_blocked", "_building_door_reserved(t)") == 1)

# ── ⑦ #6 업화로 진행 눈금의 분모가 «투입 시점에 굳은 총 분»이다 ─────────────
func _check_furnace_scale() -> void:
	print("⑦ #6 업화로 진행 띠 ↔ 굳은 분모")
	_check("⑦a 배선: 분모가 원장의 굳은 총 분이다(살아 있는 퍼크로 다시 파는 창구 0)",
		_count_in(_src, "func _draw_furnaces", "furnace.minutes_total(_region, t)") == 1
			and _count_in(_src, "func _draw_furnaces",
				"FurnaceLedger.smelt_minutes(ore, smelt_time_cut())") == 0)
	# 로스터에서 광석을 판다(id 옮겨 적기 0) — 단축이 실제로 값을 바꾸는 종이어야 무대가 선다.
	var ore := ""
	for o in FurnaceLedger.smeltable_ores():
		var oid := String(o)
		if FurnaceLedger.smelt_minutes(oid, 0.5) < FurnaceLedger.smelt_minutes(oid, 0.0):
			ore = oid
			break
	_check("⑦b' 무대: 단축이 실효인 광석 「%s」을 로스터에서 찾았다(base %d분 → −50%% %d분)"
			% [ItemCatalog.name_of(ore), FurnaceLedger.smelt_minutes(ore, 0.0),
				FurnaceLedger.smelt_minutes(ore, 0.5)],
		ore != "" and FurnaceLedger.smelt_minutes(ore, 0.5) < FurnaceLedger.smelt_minutes(ore, 0.0))
	if ore == "":
		return
	var f := FurnaceLedger.new()
	var t := Vector2i(3, 4)
	var rg := RegionCatalog.HOME
	f.place(rg, t)
	f.load_ore(rg, t, ore, 0.0)      # 퍼크 없이 투입 — left·total 둘 다 base
	var base_total := FurnaceLedger.smelt_minutes(ore, 0.0)
	_check("⑦b 투입이 총 분을 함께 굳힌다 — total %d = left %d = base %d"
			% [f.minutes_total(rg, t), f.minutes_left(rg, t), base_total],
		f.minutes_total(rg, t) == base_total and f.minutes_left(rg, t) == base_total)
	# ★핵심 — 제련 중에 [제련공]을 골라도(= `smelt_time_cut()`이 0.0→0.5) 분모가 안 흔들린다.
	f.advance_minutes(float(int(base_total / 4)))
	var left := f.minutes_left(rg, t)
	var live_total := FurnaceLedger.smelt_minutes(ore, 0.5)   # 종전 코드가 매 프레임 파던 그 값
	var old_w := float(live_total - left) / float(maxi(live_total, 1))
	var new_w := float(f.minutes_total(rg, t) - left) / float(maxi(f.minutes_total(rg, t), 1))
	_check("⑦c **종전 분모는 음수 폭을 냈다** — 살아 있는 퍼크 %d분 vs 남은 %d분 → 비율 %.2f(음수)"
			% [live_total, left, old_w], live_total < left and old_w < 0.0)
	_check("⑦c' 굳은 분모는 실제 진행을 그린다 — %d/%d = %.2f(0~1 · 단조)"
			% [f.minutes_total(rg, t) - left, f.minutes_total(rg, t), new_w],
		new_w > 0.0 and new_w < 1.0 and f.minutes_total(rg, t) >= left
			and is_equal_approx(new_w, float(base_total - left) / float(base_total)))
	# 퍼크 아래 **새로** 투입하면 그때의 값으로 다시 굳는다(소급이 아니라 시점 계약).
	f.advance_minutes(float(base_total))     # 다 익히고
	f.collect(rg, t)
	f.load_ore(rg, t, ore, 0.5)
	_check("⑦d 퍼크 아래 새로 투입하면 그 시점 값으로 굳는다 — total %d = left %d(= −50%% %d분)"
			% [f.minutes_total(rg, t), f.minutes_left(rg, t), live_total],
		f.minutes_total(rg, t) == live_total and f.minutes_left(rg, t) == live_total)
	# 세이브 왕복 — 총 분이 파일을 건넌다(7항).
	var raw: Dictionary = f.to_save()
	var g := FurnaceLedger.new()
	g.load_save(raw)
	_check("⑦e 세이브 왕복이 총 분을 보존한다 — total %d · left %d"
			% [g.minutes_total(rg, t), g.minutes_left(rg, t)],
		g.minutes_total(rg, t) == f.minutes_total(rg, t)
			and g.minutes_left(rg, t) == f.minutes_left(rg, t))
	# 구세이브 백필 — 6항 배열(총 분 항 없음)은 남은 분을 총량으로 삼는다(보수적 · 음수 폭 0).
	var arr: Array = raw["forges"][rg]
	var six: Array = Array(arr[0]).slice(0, 6)
	var h := FurnaceLedger.new()
	h.load_save({"forges": {rg: [six]}})
	_check("⑦f 구세이브(6항) 백필: 남은 분을 총량으로 삼는다 — total %d = left %d(과대보고 0 · 폭 음수 0)"
			% [h.minutes_total(rg, t), h.minutes_left(rg, t)],
		h.minutes_total(rg, t) == h.minutes_left(rg, t)
			and h.minutes_total(rg, t) >= h.minutes_left(rg, t))

# ── ⑧ #7 목공방 요약의 «내일 아침 완공»이 제 날짜에 뜬다 ────────────────────
func _check_carpenter_summary() -> void:
	print("⑧ #7 목공방 진행 요약 ↔ 도달 가능성")
	var csrc := _lines_of_file("res://carpenter.gd")
	_check("⑧a 배선: 문턱이 1이다(0이면 그 프레임이 존재하지 않는다)",
		_count_in(csrc, "func summary", "if left <= 1:") == 1
			and _count_in(csrc, "func summary", "if left <= 0:") == 0)
	# 근거 — `advance_day`가 예정일 아침에 곧바로 비우므로 `left == 0`인 활성 프레임이 없다.
	_check("⑧a' 근거: 완공은 `day >= due_day`인 아침에 일어나 `_active`를 비운다(요약이 그 프레임부터 \"\")",
		_count_in(csrc, "func advance_day", "if not is_active() or day < due_day():") == 1)
	# 거동 — **전 프로젝트**를 실제로 굴려 문구 수열을 모은다(days 하드코딩 0 · 레지스트리 파생).
	var reached := 0
	var projects: Array = Carpenter.PROJECTS.keys()
	var sample := ""
	for pid0 in projects:
		var pid := String(pid0)
		var c := Carpenter.new()
		var day := 10
		c.order(pid, day)
		var seen: Array = []
		var guard := 0
		while c.is_active() and guard < 12:
			seen.append(c.summary(day))       # 그날 낮의 요약(아침 완공 처리 뒤)
			day += 1
			guard += 1
			c.advance_day(day)                # 다음 아침
		var said := false
		for s in seen:
			if String(s).contains("내일 아침 완공"):
				said = true
		if said:
			reached += 1
		if pid == String(projects[0]):
			sample = " · ".join(PackedStringArray(seen))
	_check("⑧b **모든 프로젝트에서 그 문구가 뜬다** — %d/%d(종전엔 0/%d = 어떤 날짜로도 도달 불가)"
			% [reached, projects.size(), projects.size()],
		reached == projects.size() and projects.size() > 0)
	_check("⑧c 수열이 «N일 남음 → 내일 아침 완공 → 완공»이다 — 「%s」(남음 갈래도 안 죽는다)" % sample,
		sample.contains("일 남음") and sample.contains("내일 아침 완공")
			and sample.find("일 남음") < sample.find("내일 아침 완공"))
	# 그 문구가 **참**인가 — 다음 아침에 실제로 완공된다(R15 «광고는 언제나 참»).
	var pid2 := String(projects[0])
	var c2 := Carpenter.new()
	c2.order(pid2, 10)
	var d := 10
	while c2.is_active() and not c2.summary(d).contains("내일 아침 완공") and d < 20:
		d += 1
		c2.advance_day(d)
	var done_id := c2.advance_day(d + 1)
	_check("⑧d 그 문구는 **참이다** — day %d에 뜬 뒤 day %d 아침에 「%s」이 실제로 완공됐다"
			% [d, d + 1, Carpenter.name_of(pid2)],
		done_id == pid2 and c2.is_done(pid2) and not c2.is_active())

# ── ⑨ #8 건물 문·퇴장 착지 칸도 나무에 성역이다 ─────────────────────────────
func _check_building_door_sanctuary(m: Node) -> void:
	print("⑨ #8 혼의 나무 ↔ 건물 문·착지 칸")
	_check("⑨a 배선: 술어가 서 있고 `_is_tree_blocked`이 그것을 든다",
		_count_in(_src, "func _is_tree_blocked", "_building_door_reserved(t)") == 1
			and _count_in(_src, "func _building_door_reserved", "for id in _buildings:") == 1)
	_check("⑨a' 배선: 좌표를 옮겨 적지 않는다(표에서 파생 — 리터럴 Vector2i 0 · 실내 좌표 0)",
		_count_in(_src, "func _building_door_reserved", "Vector2i(") == 0
			and _count_in(_src, "func _building_door_reserved", "\"in_tile\"") == 0)
	# 실측 — 지금 무대의 건물 문·착지 칸을 **표에서** 전수로 판다(분모 하드코딩 0).
	var tiles: Array = []
	var out_tiles: Dictionary = {}
	for id in m._buildings:
		var b: Dictionary = m._buildings[id]
		if b.get("region", "") != m._region:
			continue
		for key in ["ext_door", "ext_door2", "out_tile"]:
			if b.has(key):
				tiles.append(b[key])
		out_tiles[String(id)] = b["out_tile"]
	var blocked := 0
	var plantable := 0
	for t0 in tiles:
		var t: Vector2i = t0
		if m._is_tree_blocked(t):
			blocked += 1
		if m.orchard.can_plant(t, m._is_tree_blocked):
			plantable += 1
	_check("⑨b 문·착지 칸 %d개가 **전부** 막힌 칸이고 밑동을 못 받는다(심을 수 있는 칸 %d개)"
			% [blocked, plantable],
		tiles.size() > 0 and blocked == tiles.size() and plantable == 0)
	# ★ 종전에 유일하게 뚫려 있던 칸 — 넋둥우리 퇴장 착지(문이 rect 동단이라 3×3이 벽을 안 문다).
	var coop: Vector2i = out_tiles.get("넋둥우리", Vector2i(-1, -1))
	_check("⑨c 종전 유일한 구멍이 막혔다 — 넋둥우리 착지 칸 (%d,%d) blocked=%s(실측 12칸 중 이 한 칸만 `can_plant`였다)"
			% [coop.x, coop.y, str(m._is_tree_blocked(coop))],
		coop.x >= 0 and m._building_door_reserved(coop) and m._is_tree_blocked(coop))
	# 성역이 문 주변으로 번지지 않는다(과잉 확장 0) — 표에 없는 칸은 이 술어가 안 든다.
	var near := coop + Vector2i(0, 3)
	_check("⑨d 성역은 표에 있는 칸뿐이다 — 이웃 칸 (%d,%d)는 이 술어가 안 든다(과잉 확장 0)"
			% [near.x, near.y], not m._building_door_reserved(near))
	# 근거 재검증 — R19 #7의 문장이 건물에도 1:1로 성립한다(그 칸에 서야 발동 · 착지 좌표 강제).
	_check("⑨e 근거: 출입은 **그 칸에 서야** 발동하고(`_player_tile` 비교) 퇴장은 착지 칸 좌표를 강제한다",
		_count_in(_src, "func _maybe_toggle_building", "var t := _player_tile()") == 1
			and _count_in(_src, "func _maybe_toggle_building", "t == b[\"ext_door\"]") == 1
			and _count_in(_src, "func _maybe_toggle_building", "_transition_to(\"\", ib[\"out_tile\"])") == 1)

# ── ⑩ #9 장원제 부상은 «받을 수 있을 때만» 기회를 소비한다 ──────────────────
func _check_grange_award_order(m: Node) -> void:
	print("⑩ #9 장원제 래치 ↔ 부상 지급 순서")
	var fit_line := _line_in(_src, "func _try_grange_entry", "_grange_awards_fit(rank)")
	var latch_line := _line_in(_src, "func _try_grange_entry", "seasonal_event.record_grange(")
	_check("⑩a 배선: 자리 선검사(%d행)가 래치(%d행)보다 **위**다(형제 창구의 「적재 먼저·기록 나중」)"
			% [fit_line, latch_line],
		fit_line > 0 and latch_line > 0 and fit_line < latch_line)
	# 무대 — 곳간을 채워 장원 등급을 만들고, 백팩을 꽉 채운다.
	var champion: int = SeasonalEvent.GRANGE_TIER_NAMES.size() - 1
	m.larder.stock.clear()
	var pool: Array = []
	for cid in CropCatalog.ids():
		pool.append(String(cid))
	for fid in ItemCatalog.FORAGEABLES.keys():
		pool.append(String(fid))
	pool.sort_custom(func(a, b): return ItemCatalog.price_of(a) > ItemCatalog.price_of(b))
	for pid in pool:
		if SeasonalEvent.grange_rank(SeasonalEvent.score_entries(m._grange_entries())) >= champion:
			break
		m.larder.add(String(pid), 1)
	var rank: int = SeasonalEvent.grange_rank(SeasonalEvent.score_entries(m._grange_entries()))
	_check("⑩b' 무대: 곳간 %d종으로 장원 등급이 나온다(점수 %d ≥ 문턱 %d)"
			% [m.larder.ids().size(), SeasonalEvent.score_entries(m._grange_entries()),
				int(SeasonalEvent.GRANGE_TIER_SCORES[champion])],
		rank == champion)
	# 백팩을 만재로(합칠 스택도 없게 — 비료·레어크로우 둘 다 새 칸을 요구하는 최악 상태).
	for i in range(m.inventory.slots.size()):
		m.inventory.slots[i] = null
	var filler: Array = []
	for cid2 in CropCatalog.ids():
		filler.append(String(cid2))
	var fi := 0
	for i2 in range(m.inventory.slots.size()):
		m.inventory.slots[i2] = {"id": String(filler[fi % filler.size()]), "count": 1,
			"quality": ItemCatalog.Q_NORMAL}
		fi += 1
	m.seasonal_event.grange_day = -1
	var day: int = m.clock.day
	_check("⑩b'' 무대: 백팩이 만재고 품질 비료 스택이 없다(자리 %s · 부상 적재 불가)"
			% str(m.inventory.has_free_slot()),
		not m.inventory.has_free_slot()
			and not m.inventory.has_stack(FertilizerCatalog.FERT_QUALITY)
			and not m._grange_awards_fit(rank))
	m.notice_feed._items.clear()
	var ok1: bool = m._try_grange_entry()
	var said := ""
	for tx in _notice_texts(m):
		if tx.contains("장원 부상"):
			said = tx
	_check("⑩b **만재면 기회를 안 쓴다** — 출품 %s · 오늘 래치 %s · 알림 「%s」"
			% [str(ok1), str(m.seasonal_event.grange_entered(day)), said],
		not ok1 and not m.seasonal_event.grange_entered(day)
			and said.contains("자리를 비우고") and not m.seasonal_event.has_bought(SeasonalEvent.GRANGE_RARECROW))
	# 자리를 비우고 **같은 날** 다시 — 이제 그 지시가 이행 가능하다(종전엔 「이미 마쳤다」로 막혔다).
	m.inventory.slots[0] = null
	m.inventory.slots[1] = null
	m.notice_feed._items.clear()
	var gold0: int = m.wallet.gold
	var ok2: bool = m._try_grange_entry()
	_check("⑩c 자리를 비우면 **같은 날** 출품이 성립한다 — %s · 래치 %s · 품질 비료 %d개 · 레어크로우 %s(+%d냥)"
			% [str(ok2), str(m.seasonal_event.grange_entered(day)),
				m.inventory.count_of(FertilizerCatalog.FERT_QUALITY),
				str(m.seasonal_event.has_bought(SeasonalEvent.GRANGE_RARECROW)),
				m.wallet.gold - gold0],
		ok2 and m.seasonal_event.grange_entered(day)
			and m.inventory.count_of(FertilizerCatalog.FERT_QUALITY) == SeasonalEvent.GRANGE_CHAMPION_FERT
			and m.seasonal_event.has_bought(SeasonalEvent.GRANGE_RARECROW)
			and m.wallet.gold - gold0 == SeasonalEvent.grange_gold(rank))
	# 하루 1회 계약은 그대로 — 성립한 뒤엔 같은 날 다시 안 열린다(거동 축소 0).
	_check("⑩d 성립한 뒤엔 하루 1회 계약이 그대로 닫는다", not m._try_grange_entry())
	# 부상 없는 등급은 만재여도 그대로 출품된다(선검사가 새 문턱을 만들지 않는다).
	for i3 in range(m.inventory.slots.size()):
		m.inventory.slots[i3] = {"id": String(filler[i3 % filler.size()]), "count": 1,
			"quality": ItemCatalog.Q_NORMAL}
	m.seasonal_event.grange_day = -1
	m.larder.stock.clear()
	m.larder.add(String(pool[0]), 1)
	var low: int = SeasonalEvent.grange_rank(SeasonalEvent.score_entries(m._grange_entries()))
	_check("⑩e 부상 없는 등급은 만재여도 그대로 출품된다 — 등급 %d(「%s」 · 물건 부상이 0이라 선검사가 늘 참)"
			% [low, SeasonalEvent.grange_rank_name(low)],
		low < SeasonalEvent.GRANGE_TIER_NAMES.size() - 1 and m._grange_awards_fit(low)
			and m._try_grange_entry())
	# 형제 규율 재확인 — 다른 지급 창구는 여전히 «적재 먼저».
	_check("⑩f 형제 창구의 규율이 그대로다(적재 실패 시 기록 안 함 · 편지는 열기 전에 자리를 묻는다)",
		_count_in(_src, "func _claim_museum_milestones", "if not inventory.add_item(") >= 1
			and _count_in(_src, "func _read_next_letter", "_letter_attachment_fits(") >= 1)
	m.larder.stock.clear()
