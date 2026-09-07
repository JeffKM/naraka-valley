extends SceneTree
# ★[폴리시 30회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#10) + 배치 B(#11~#21).
#
# 렌즈: R29 diff 리뷰(#0·#1) · 세이브 키 생애(#2) · 래치 수명 조사(#3~#5) ·
#       SOLID 스포너 매몰 재훑기(#6~#9) · 설치물 배치 행렬(#10~#13) ·
#       오버레이 입력 소비 행렬(#14~#16) · 보상 지급 원자성(#17·#18) · 강조 배지 진실성(#19~#21).
#
# 이 배치의 태도 셋.
#   ㉠ **두 원장은 서로소여야 한다.** #0은 R29 #9가 「잡초 벤 자리」를 재점령 후보로 되돌린 뒤로
#      절기 SOLID가 그 칸에 앉을 수 있게 된 자리다 — 조회 창구 전부가 `_cleared`를 먼저 보므로
#      안 보이고·못 치우고·산출 0인 유령이 서고, 그 유령이 재점령 풀만 영구히 갉아먹었다.
#      뽑는 순간 거절해(굴림은 잡초로 내린다) 불변식을 되세우고, 로드가 그것을 재보증한다.
#   ㉡ **가드는 양방향이어야 한다.** #6·#8·#9·#10은 한 쌍의 술어 중 한쪽만 서 있던 자리다 —
#      하필 뚫린 쪽이 전부 비가역이거나(과수·설치물 매장) 되돌릴 창구가 없는 쪽이었다.
#   ㉢ **막힌 것이 칸이 아니라 통행일 수도 있다.** #7의 능선바는 타일을 한 글자도 안 건드리므로
#      칸 술어 넷 어디에도 안 잡혔다 — 그래서 판정을 칸이 아니라 **간선**에 세운다.
#
# 무엇을 보증하나(번호 = 30회차 헌트 발견 인덱스).
#   ① #0 절기 재스폰 SOLID는 개간한 칸에 안 앉는다 — 굴림은 잡초로 내려가고(스트림 불변),
#      앉은 debris는 전부 세 창구(원장·프롭 병합·개간 디스패치)에서 실재한다. 구세이브도 이행.
#   ② #1 이월 방목 방출이 «마지막 밤의 확산 뒤·파종 앞»에 선다(아침 정산과 같은 상대 순서).
#   ③ #2 손상 세이브의 이물이 원장 넷에 눕지 않고, `_load_game`이 끝까지 돈다.
#   ④ #3·#5 마구간 휘파람 — 고지가 `keep`이고, 완공 당일 이중 호출이 없다.
#   ⑤ #4 나락 열쇠 개방 고지가 **이번 개봉의 전이**를 본다(영속 플래그가 아니라).
#   ⑥ #6 숲 재출현·큰 그루터기가 설치물 위에 SOLID를 다시 세우지 않는다(무대와 무관하게).
#   ⑦ #7 능선 seam 간선이 매몰 판정에 든다(고지 동단의 «열린 퇴로» 오답 0).
#   ⑧ #8 자체 파종이 [F] 창구 좌표(우편함)를 성역으로 든다.
#   ⑨ #9·#10 묘목 사다리가 짐승·설치물을 밑동 한 칸 폭으로 든다(가드 폭 대칭).
#   ⑩ #11 괭이 AoE가 화분 밑을 갈지 않는다(무광고 과금 동사 0).
#   ⑪ #12 다 자란 화분을 화분 든 손으로 겨누면 좌클릭 동사를 함께 광고한다.
#   ⑫ #13 레어크로우 머리 칸이 두 방향 모두에서 성역이다(아트 폭 = 예약 폭).
#   ⑬ #14 비차단 마일스톤 팝업이 상시 HUD를 안 지운다.
#   ⑭ #15 두 비차단 팝업의 초가 모든 모달·연출 아래에서도 깎인다(『정지 주인 = 재개 주인』).
#   ⑮ #16 두 판이 클릭을 안 삼킨다(선언된 비차단 = 실효 비차단).
#   ⑯ #17 더비 부상이 선검사를 지난다(태그를 태우고 부상만 잠기는 갈래 0).
#   ⑰ #18 증정 창구 둘의 중복 방어가 상자까지 본다(처분 불가 사본 0).
#   ⑱ #19 퍼펙트 창 금박 테가 **딸 수 있는 창**에만 선다.
#   ⑲ #20 꾸미기 고스트의 «놓을 수 있다»가 실효 술어와 같다.
#   ⑳ #21 「서운함」 배지가 금박(행동 가능)과 다른 색이다.
#
# 판정: 배치 A CONFIRMED 11 · 배치 B CONFIRMED 11 · REFUTED·DUP·OWNER-DECISION 0.

var _fail := 0
var _src: PackedStringArray

func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text().split("\n") if f != null else PackedStringArray()

func _line_of(lines: PackedStringArray, needle: String) -> int:
	for i in lines.size():
		if lines[i].contains(needle):
			return i
	return -1

# 그 함수 본문(다음 `func ` 줄 전까지) 안에서 니들이 처음 나오는 줄(없으면 -1).
func _in_func(fn_needle: String, needle: String) -> int:
	var head := _line_of(_src, fn_needle)
	if head < 0:
		return -1
	for i in range(head + 1, _src.size()):
		if _src[i].begins_with("func "):
			return -1
		if _src[i].contains(needle):
			return i
	return -1

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

# 전이(워프·구역 재빌드)가 끝날 때까지 기다린다 — `_descend_mine`은 `_transitioning`이면 즉시
# return하므로, 이 대기가 없으면 층 레이아웃이 통째로 안 선다(polish_r8·guild_test 관례).
func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

func _spawn_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m

# 세이브 슬롯 청소 — 이 스위트는 ③에서 `_save_game`/`_load_game` 왕복을 태우므로, 앞선 실행이
# 남긴 파일이 부팅 자동 복원으로 되살아나면 다른 절의 무대가 통째로 갈린다(polish_r8 관례).
func _wipe_slot(slot: int) -> void:
	var p := SaveManager.slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

# 알림 피드에 이 문구를 담은 줄이 몇 개 있는가(중복 축출 검증이 개수를 본다).
func _notice_hits(m: Node, needle: String) -> int:
	var n := 0
	for it in m.notice_feed._items:
		if String(it["text"]).contains(needle):
			n += 1
	return n

func _notice_keep(m: Node, needle: String) -> bool:
	for it in m.notice_feed._items:
		if String(it["text"]).contains(needle):
			return bool(it.get("keep", false))
	return false

# ★[폴리시 R2 공용 · inventory_test에서 계승] 백팩을 빈 슬롯 0으로 채운다(서로 다른 종을 섞어야
#   합류할 스택이 없어 "가득"이 실효한다).
func _fill_backpack_full(inv: Inventory) -> void:
	var pool: Array = []
	for id in Museum.donatable_ids():
		pool.append(String(id))
	for i in range(inv.slots.size()):
		inv.slots[i] = {"id": String(pool[i]), "count": 1, "quality": 0} if i < pool.size() \
			else {"id": ItemCatalog.harvest_id(CropCatalog.PIANHWA), "count": 1,
				"quality": (i - pool.size()) % 4}
	inv.changed.emit()

# 열려 있는 대화를 끝까지 넘긴다(모달 잔재 청소 — polish_r29 관례).
func _dismiss_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 200:
		m.dialogue.advance()
		guard += 1

# 릴 격투까지 진행(fishing_test 관례 그대로 — BITE 프레임에만 후킹 입력을 준다).
func _advance_to_fight(sess: FishingSession, secs_cap := 30.0, step := 0.05) -> bool:
	var t := 0.0
	while sess.is_active() and sess.state != FishingSession.State.FIGHT and t < secs_cap:
		sess.tick(step, sess.state == FishingSession.State.BITE)
		t += step
	return sess.state == FishingSession.State.FIGHT

# 든 아이템 선택(없으면 인벤에 넣고 그 슬롯 선택 — garden_pot_test·sprinkler_test 결).
func _select(m: Node, id: String) -> void:
	if not m.inventory.has_item(id):
		m.inventory.add_item(id, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

func _initialize() -> void:
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R30 회귀 — 배치 A(#0~#10) ══")
	_src = _lines_of_file("res://main.gd")
	var m := await _spawn_main()

	await _sec1_ghost_debris(m)
	await _sec7_ridge_seam(m)
	await _sec8_seed_mailbox(m)
	await _sec9_sapling_ladder(m)
	await _sec6_respawn_installation(m)
	await _sec4_whistle(m)
	await _sec2_pasture_order(m)
	await _sec3_corrupt_save(m)
	await _sec5_narak_key(m)

	# ── 배치 B(#11~#21) ──
	# ⑤가 무대를 갱도 층에 두고 끝나므로 안식으로 되돌린다(배치 B는 전부 HOME 좌표계다).
	m._mine_floor = 0
	m._narak_depth = 0
	m._indoor = ""
	m._rebuild_region(RegionCatalog.HOME)
	await _settle(m)
	await _sec10_hoe_pot(m)
	await _sec11_pot_prompt(m)
	await _sec12_rarecrow_head(m)
	await _sec13_milestone_hud(m)
	await _sec14_popup_lifetime(m)
	await _sec15_popup_click(m)
	await _sec16_derby_award(m)
	await _sec17_gift_windows(m)
	_sec18_perfect_window()
	await _sec19_deco_ghost(m)
	_sec20_heart_badge()

	# ★ 끝에서도 지운다(polish_r8 관례) — ③이 남긴 세이브가 그대로 있으면 **다음 스위트**가
	#   부팅 자동 복원으로 갱도 바닥에서 시작해 무대 단언이 통째로 무너진다(실측: building_test).
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)
	print("══ 결과: %s ══" % ("전부 통과" if _fail == 0 else "%d건 실패" % _fail))
	quit(1 if _fail > 0 else 0)

# ── ① #0 절기 재스폰 SOLID가 개간한 칸에 «유령»으로 앉지 않는다 ───────────────
func _sec1_ghost_debris(m: Node) -> void:
	print("── ① #0 개간한 칸엔 절기 SOLID가 안 앉는다(유령 0) ──")
	var scythe: String = DebrisCatalog.tool_for(DebrisCatalog.WEEDS)
	# ①a 대조군 무대 — 같은 day·같은 풀에서 처녀지는 SOLID가 실제로 선다(굴림이 살아 있다).
	var pool: Array = []
	for i in range(40):
		pool.append(Vector2i(i % 8, int(i / 8.0)))
	var day := -1
	var virgin: Reclaim = null
	for d in range(1, 80):
		var rc := Reclaim.new()
		rc.season_respawn(pool, d, false)
		if rc.respawned_debris_count() >= 2:
			day = d
			virgin = rc
			break
		rc.free()
	_check("①a 무대: 처녀지 풀에서 SOLID가 서는 날 day=%d를 잡았다(업화석·석화 고목 %d칸)"
			% [day, virgin.respawned_debris_count() if virgin != null else -1],
		day > 0 and virgin != null and virgin.respawned_debris_count() >= 2)
	if virgin == null:
		return
	var v_weeds: Array = virgin.weed_tiles()
	var v_solid: Array = virgin.respawned_debris_tiles()
	# ①b 실험군 — 같은 풀의 **전 칸이 잡초 벤 자리**. 굴림 스트림은 한 톨도 안 흔들려야 한다.
	var opened := Reclaim.new()
	for t: Vector2i in pool:
		opened.clear(t, DebrisCatalog.WEEDS, scythe)
	opened.season_respawn(pool, day, false)
	_check("①b 개간한 칸엔 SOLID가 한 개도 안 앉는다(재스폰 debris %d개 — 처녀지는 %d개였다)"
			% [opened.respawned_debris_count(), v_solid.size()],
		opened.respawned_debris_count() == 0)
	_check("①c 거절된 굴림은 **잡초로 내려간다** — 잡초 %d = 처녀지 잡초 %d + 처녀지 SOLID %d"
			% [opened.weed_count(), v_weeds.size(), v_solid.size()],
		opened.weed_count() == v_weeds.size() + v_solid.size())
	var same_tiles := true
	for t: Vector2i in v_weeds:
		if not opened.has_weed(t):
			same_tiles = false
	for t: Vector2i in v_solid:
		if not opened.has_weed(t):
			same_tiles = false
	_check("①d **좌표가 한 칸도 안 갈린다**(굴림 스트림 불변 = 결정성 보존) — 두 판의 %d칸이 동일"
			% (v_weeds.size() + v_solid.size()), same_tiles)
	# ①e 구세이브 이행 — 겹쳐 실린 유령은 로드가 걷어 낸다.
	var legacy := Reclaim.new()
	legacy.load_save({"cleared": [[10, 10, DebrisCatalog.WEEDS]], "weeds": [],
		"debris": [[10, 10, DebrisCatalog.EMBER], [11, 11, DebrisCatalog.EMBER]]})
	_check("①e 구세이브 이행: `_cleared`와 겹친 유령 debris만 걷힌다((10,10) 소거 · (11,11) 생존)",
		legacy.respawned_debris_count() == 1
		and legacy.respawned_debris_kind(Vector2i(11, 11)) == DebrisCatalog.EMBER
		and legacy.respawned_debris_kind(Vector2i(10, 10)) == "")
	virgin.free()
	opened.free()
	legacy.free()

	# ①f~①i 라이브 마당 — 시드 잡초를 전량 베고 절기 재스폰을 여러 날 굴린다.
	var weeds: Array = []
	for entry in m._home_prop_entries():
		if m.DEBRIS_KIND.get(entry[0], "") != DebrisCatalog.WEEDS:
			continue
		for t: Vector2i in entry[1]:
			if m.ENCROACH_SCAN_RECT.has_point(t) and not m.reclaim.is_cleared(t):
				weeds.append(t)
	for t: Vector2i in weeds:
		m.reclaim.clear(t, DebrisCatalog.WEEDS, scythe)
	var cands: Array = m._encroach_candidates()
	var back := 0
	for t: Vector2i in weeds:
		if cands.has(t):
			back += 1
	_check("①f 무대: 벤 시드 잡초 %d칸 중 %d칸이 재점령 후보로 돌아왔다(R29 #9 계약 생존)"
			% [weeds.size(), back], weeds.size() > 0 and back > 0)
	# ①g 후보를 **벤 자리로만** 좁혀 굴린다 — 마당 전체를 후보로 두면 2,100칸 중 57칸이라
	#   SOLID 굴림이 그 칸을 안 뽑고 지나갈 수 있어, 그 판으로는 이 계약을 못 잰다.
	var only_cleared: Array = []
	for t: Vector2i in weeds:
		if cands.has(t):
			only_cleared.append(t)
	var w0: int = m.reclaim.weed_count()
	for d in range(1, 12):
		m.reclaim.season_respawn(only_cleared, d, false)
	var ghosts: Array = []
	for t: Vector2i in m.reclaim.respawned_debris_tiles():
		if m.reclaim.is_cleared(t):
			ghosts.append(t)
	_check("①g 후보가 벤 자리 %d칸뿐인 판을 11번 굴려도 SOLID가 한 칸도 안 앉는다(유령 %d칸 · 대신 잡초가 %d포기 늘었다)"
			% [only_cleared.size(), ghosts.size(), m.reclaim.weed_count() - w0],
		only_cleared.size() > 0 and ghosts.is_empty() and m.reclaim.weed_count() > w0)
	# 실제 SOLID가 서는 판(마당 전체 후보)에서 세 조회 창구가 같은 답을 내는지 잰다.
	for d in range(1, 12):
		m._run_season_respawn(d)
	var respawned: Array = m.reclaim.respawned_debris_tiles()
	var overlap: Array = []
	for t: Vector2i in respawned:
		if m.reclaim.is_cleared(t):
			overlap.append(t)
	_check("①h 마당 전체 후보로 선 재스폰 debris %d칸도 개간한 칸과 %d칸 겹친다(두 원장은 서로소)"
			% [respawned.size(), overlap.size()], respawned.size() > 0 and overlap.is_empty())
	# 세 창구가 같은 답을 낸다 = 그리기·충돌·개간 디스패치가 전부 그 칸에 도달한다.
	var merged: Dictionary = {}
	for entry in m._home_prop_entries():
		var k: String = m.DEBRIS_KIND.get(entry[0], "")
		if k == DebrisCatalog.EMBER or k == DebrisCatalog.STUMP:
			for t: Vector2i in entry[1]:
				merged[t] = k
	var ledger_ok := true
	var merge_ok := true
	var dispatch_ok := true
	for t: Vector2i in respawned:
		var kind: String = m.reclaim.respawned_debris_kind(t)
		if kind == "":
			ledger_ok = false
			continue
		if merged.get(t, "") != kind:
			merge_ok = false
		if m._debris_kind_at(t) != kind:
			dispatch_ok = false
	_check("①i 원장 창구: %d칸 전부가 `respawned_debris_kind`에서 종을 낸다(\"\" = 유령 0)"
			% respawned.size(), ledger_ok)
	_check("①j 프롭 병합 창구: 같은 %d칸이 업화석·석화 고목 텍스처 엔트리로 그려진다(드로우·충돌)"
			% respawned.size(), merge_ok)
	_check("①k 개간 디스패치 창구: `_debris_kind_at`가 같은 종을 낸다(겨누면 치울 수 있다)",
		dispatch_ok)

# ── ⑦ #7 능선 seam 간선이 매몰 판정에 든다 ────────────────────────────────────
func _sec7_ridge_seam(m: Node) -> void:
	print("── ⑦ #7 능선 seam은 칸이 아니라 «칸과 칸 사이»를 막는다 ──")
	var e: int = m.HIGHLAND_E
	var s: int = m.HIGHLAND_S
	_check("⑦a 무대: 안식 야외이고 능선 충돌바가 서 있다",
		m._region == RegionCatalog.HOME and m._indoor == "" and m._ridge_body != null)
	_check("⑦b seam(x%d↔x%d)은 **양방향** 차단이다" % [e, e + 1],
		m._ridge_seam_blocks(Vector2i(e, 10), Vector2i(e + 1, 10))
		and m._ridge_seam_blocks(Vector2i(e + 1, 10), Vector2i(e, 10)))
	_check("⑦c 바 아래(y%d — 남향 절벽 구간)는 이 항이 안 든다" % (s + 1),
		not m._ridge_seam_blocks(Vector2i(e, s + 1), Vector2i(e + 1, s + 1)))
	_check("⑦d 고지 안쪽(x%d↔x%d)·저지 안쪽(x%d↔x%d)은 그대로 통행이다" % [e - 1, e, e + 1, e + 2],
		not m._ridge_seam_blocks(Vector2i(e - 1, 10), Vector2i(e, 10))
		and not m._ridge_seam_blocks(Vector2i(e + 1, 10), Vector2i(e + 2, 10)))
	_check("⑦e 세로 이동(같은 x)은 seam이 아니다",
		not m._ridge_seam_blocks(Vector2i(e, 10), Vector2i(e, 11)))
	# 통합 — 고지 동단에 서서 퇴로가 seam 너머뿐이면 «주머니»여야 한다.
	var y := -1
	for cand in range(2, s - 1):
		var ok := true
		for t in [Vector2i(e, cand), Vector2i(e - 1, cand), Vector2i(e, cand - 1),
				Vector2i(e, cand + 1), Vector2i(e + 1, cand)]:
			if m._player_blocked_at(t):
				ok = false
		if ok:
			y = cand
			break
	_check("⑦f 무대: 고지 동단 (%d,%d)과 그 사방 네 칸이 전부 통행 가능하다(칸 술어 기준)"
			% [e, y], y > 0)
	if y < 0:
		return
	m.player.global_position = m._tile_center_px(Vector2i(e, y))
	await process_frame
	_check("⑦g 무대: 플레이어가 (%d,%d)에 섰다" % [e, y], m._player_tile() == Vector2i(e, y))
	var pending: Dictionary = {Vector2i(e - 1, y): true, Vector2i(e, y - 1): true}
	_check("⑦h 서쪽·북쪽이 곧 서고 남쪽에 SOLID를 세우면 **주머니다** — 동쪽 (%d,%d)는 seam 너머라"
			% [e + 1, y] + " 퇴로가 아니다",
		m._would_entrap_player(Vector2i(e, y + 1), pending))
	_check("⑦i 과잉 거절 0: 남쪽이 열려 있으면 고지 전체가 이어져 주머니가 아니다",
		not m._would_entrap_player(Vector2i(e - 2, y), pending))

# ── ⑧ #8 자체 파종이 [F] 창구 좌표를 성역으로 든다 ────────────────────────────
func _sec8_seed_mailbox(m: Node) -> void:
	print("── ⑧ #8 밤새 돋는 나무도 우편함 칸을 안 먹는다 ──")
	var t: Vector2i = m.MAILBOX_TILE
	var occ: Dictionary = m._home_occupied_tiles()
	# 하중 — 거절의 **유일한 근거**가 [F] 표임을 나머지 아홉 겹으로 각각 보인다.
	_check("⑧a 무대: 우편함 칸 (%d,%d)의 지형은 순수 GROUND다(밭 흙·길·벽 아님)" % [t.x, t.y],
		m._grid[t.y][t.x] == m.GROUND)
	_check("⑧b 무대: 프롭 점유 표에 없다(프롭은 한 칸 아래에 선다)", not occ.has(t))
	_check("⑧c 무대: 밭도 개간도 잡초도 아니다",
		not m.farm.is_tilled(t) and not m.farm.is_planted(t)
		and not m.reclaim.is_cleared(t) and not m.reclaim.has_weed(t))
	_check("⑧d 무대: 설치물·과수·짐승도 아니다",
		not m._installation_at(t) and not (t in m.orchard.trunk_tiles())
		and not m.ranch.has_animal_at(t))
	_check("⑧e 무대: 늘봄방 예정지도 아니고 매몰 가드에도 안 걸린다",
		not m._greenhouse_lot_reserved(t) and not m._would_entrap_player(t))
	_check("⑧f 그런데 [F] 창구 표는 그 칸을 든다", m._f_window_tile(t))
	_check("⑧g 그래서 자체 파종이 거절한다(아홉 겹을 다 통과했지만 이 한 항에서 선다)",
		not m._is_tree_seed_free(RegionCatalog.HOME, t, occ))
	# 대조 — 같은 마당의 평범한 여백은 종전대로 통과해야 한다(과잉 거절 0).
	var free_t := Vector2i(-1, -1)
	for yy in range(m.ENCROACH_SCAN_RECT.position.y, m.ENCROACH_SCAN_RECT.end.y):
		for xx in range(m.ENCROACH_SCAN_RECT.position.x, m.ENCROACH_SCAN_RECT.end.x):
			var c := Vector2i(xx, yy)
			if m._is_tree_seed_free(RegionCatalog.HOME, c, occ):
				free_t = c
				break
		if free_t.x >= 0:
			break
	_check("⑧h 과잉 거절 0: 평범한 마당 여백 (%d,%d)은 그대로 파종 자격이다" % [free_t.x, free_t.y],
		free_t.x >= 0)

# ── ⑨ #9·#10 묘목 사다리 — 짐승·설치물을 «밑동 한 칸» 폭으로 든다 ─────────────
func _sec9_sapling_ladder(m: Node) -> void:
	print("── ⑨ #9·#10 묘목 사다리의 가드 폭 대칭 ──")
	# ⑨a 사다리 순서 — 매몰 → 원장 나무 → 짐승 → 설치물 → 심기.
	var l_entrap := _in_func("func _use_tool", "if _would_entrap_player(_target):")
	var l_tree := _in_func("func _use_tool", "elif _tree_occupied_at(_target):")
	var l_animal := _in_func("func _use_tool", "elif _grazing_animal_at(_target):")
	var l_inst := _in_func("func _use_tool", "elif _installation_at(_target):")
	var l_plant := _in_func("func _use_tool", "elif inventory.has_sapling(fruit) and orchard.plant(")
	_check("⑨a 묘목 갈래가 매몰(%d) → 원장 나무(%d) → **짐승(%d)** → **설치물(%d)** → 심기(%d)"
			% [l_entrap, l_tree, l_animal, l_inst, l_plant],
		l_entrap > 0 and l_tree > l_entrap and l_animal > l_tree and l_inst > l_animal
		and l_plant > l_inst)
	_check("⑨b `_is_tree_blocked`(3×3 전수 술어)에는 설치물 항이 더 이상 없다(폭이 안 맞는 항)",
		_in_func("func _is_tree_blocked", "if _installation_at(t):") < 0)
	# ⑨c~⑨g 거동 — 심을 자리를 하나 찾아 캐노피/앵커를 갈라 잰다.
	var anchor := Vector2i(-1, -1)
	for yy in range(m.ENCROACH_SCAN_RECT.position.y + 1, m.ENCROACH_SCAN_RECT.end.y - 1):
		for xx in range(m.ENCROACH_SCAN_RECT.position.x + 1, m.ENCROACH_SCAN_RECT.end.x - 1):
			var c := Vector2i(xx, yy)
			if m.orchard.can_plant(c, m._is_tree_blocked) and m._can_place_sprinkler(c) \
					and m._can_place_sprinkler(c + Vector2i(1, 1)):
				anchor = c
				break
		if anchor.x >= 0:
			break
	_check("⑨c 무대: 마당에서 3×3 심기 자격 앵커 (%d,%d)를 잡았다(캐노피에도 설치 가능)"
			% [anchor.x, anchor.y], anchor.x >= 0)
	if anchor.x < 0:
		return
	var canopy: Vector2i = anchor + Vector2i(1, 1)
	m.sprinkler.place(canopy, Sprinkler.TIER_1)
	_check("⑨d 캐노피 칸의 스프링클러는 나무를 안 막는다(`_is_tree_blocked` 거짓)",
		m._installation_at(canopy) and not m._is_tree_blocked(canopy))
	_check("⑨e 그래서 앵커 심기가 그대로 허용된다 — 설치물 하나가 앵커 후보 아홉 개를 지우지 않는다",
		m.orchard.can_plant(anchor, m._is_tree_blocked))
	m.sprinkler.remove(canopy)
	m.sprinkler.place(anchor, Sprinkler.TIER_1)
	_check("⑨f 앵커 칸의 설치물은 **사다리가** 든다(술어가 아니라 앵커 갈래 — 폭이 밑동 한 칸)",
		m._installation_at(anchor))
	_check("⑨g 역방향도 밑동 한 칸이다: 설치물 배치 가드는 캐노피를 안 막는다(대칭)",
		not m._can_place_sprinkler(anchor) and m._can_place_sprinkler(canopy))
	m.sprinkler.remove(anchor)

# ── ⑥ #6 숲 재출현·큰 그루터기가 설치물을 매장하지 않는다 ─────────────────────
func _sec6_respawn_installation(m: Node) -> void:
	print("── ⑥ #6 나무 재출현의 설치물 거부권(무대와 무관) ──")
	var forest := RegionCatalog.MIHOK_FOREST
	var t := Vector2i(9, 9)
	var cb: Callable = m._tree_respawn_ok_cb()
	_check("⑥a 무대: 플레이어는 안식에 있고, 심사 대상은 **다른 무대**(미혹의 숲)다",
		m._region == RegionCatalog.HOME and forest != m._region)
	_check("⑥b 설치물이 없으면 종전대로 승인된다(과잉 거절 0)", bool(cb.call(forest, t)))
	m.furnace.place(forest, t)
	_check("⑥c 무대: 그 칸에 업화로가 섰다", m.furnace.has_at(forest, t))
	_check("⑥d 그 칸의 나무 재출현은 **거절**된다 — 안식에서 자는 밤에도(큰 그루터기 100%/일 갈래)",
		not bool(cb.call(forest, t)))
	_check("⑥e 구역 인자판이 남의 무대를 답한다(`_installation_at_region`)",
		m._installation_at_region(forest, t) and not m._installation_at(t))
	m.furnace.remove(forest, t)
	_check("⑥f 걷어 내면 다시 승인된다(가드가 원장을 그대로 따른다)", bool(cb.call(forest, t)))
	# 동치 — 인자판에 현재 무대를 넘기면 종전 술어와 한 칸도 안 갈린다.
	var same := true
	m.sprinkler.place(Vector2i(45, 20), Sprinkler.TIER_1)
	for yy in range(18, 26):
		for xx in range(40, 50):
			var c := Vector2i(xx, yy)
			if m._installation_at(c) != m._installation_at_region(m._region, c):
				same = false
	_check("⑥g `_installation_at(t) == _installation_at_region(_region, t)`(스프링클러 포함 80칸 표본)",
		same and m._installation_at(Vector2i(45, 20)))
	m.sprinkler.remove(Vector2i(45, 20))

# ── ④ #3·#5 마구간 휘파람 — keep 고지 · 완공 당일 이중 호출 0 ─────────────────
func _sec4_whistle(m: Node) -> void:
	print("── ④ #3·#5 마구간 휘파람 고지 ──")
	_check("④a 완공 당일 재지급 훅이 `built != Carpenter.PROJ_STABLE`로 접힌다(같은 프레임 2회 0)",
		_in_func("func _on_day_advanced", "if built != Carpenter.PROJ_STABLE:") > 0)
	m.carpenter._done[Carpenter.PROJ_STABLE] = true
	m.inventory.remove_item(ItemCatalog.MOUNT_WHISTLE,
		m.inventory.count_of(ItemCatalog.MOUNT_WHISTLE))
	_check("④b 무대: 마구간은 다 지어졌고 휘파람은 어디에도 없다",
		m.carpenter.is_done(Carpenter.PROJ_STABLE)
		and not m._stored_anywhere(ItemCatalog.MOUNT_WHISTLE))
	m.notice_feed._items.clear()
	_check("④c 증정이 성사된다", m._grant_mount_whistle()
		and m.inventory.count_of(ItemCatalog.MOUNT_WHISTLE) == 1)
	_check("④d 완공 고지가 `keep`이다(형제 완공 셋과 같은 표 — 1회성 래치)",
		_notice_keep(m, "마구간 완공"))
	# 축출 압력 — 비-keep 네 줄이 뒤이어 밀려도 그 줄은 살아남는다.
	for i in range(4):
		m._notice("아침 정산 더미 %d" % i)
	_check("④e 비-keep 네 줄이 뒤이어 밀려도 살아남는다(큐 상한 %d)" % NoticeFeed.MAX_ITEMS,
		_notice_hits(m, "마구간 완공") == 1
		and m.notice_feed._items.size() == NoticeFeed.MAX_ITEMS)
	# ④f 이중 호출의 하중 — 가방이 가득이면 같은 실패 문구가 두 줄로 겹친다(그래서 가드가 필요하다).
	m.inventory.remove_item(ItemCatalog.MOUNT_WHISTLE, 1)
	_fill_backpack_full(m.inventory)
	m.notice_feed._items.clear()
	_check("④f 무대: 휘파람 없음 + 빈 슬롯 0",
		not m._stored_anywhere(ItemCatalog.MOUNT_WHISTLE) and not m.inventory.has_free_slot())
	m._grant_mount_whistle()
	var one := _notice_hits(m, "가방을 비우면 휘파람")
	m._grant_mount_whistle()
	var two := _notice_hits(m, "가방을 비우면 휘파람")
	_check("④g 한 번 부르면 한 줄 · 두 번 부르면 두 줄(%d→%d) = 완공 당일 가드가 지우는 그 겹침"
			% [one, two], one == 1 and two == 2)
	m.carpenter._done.erase(Carpenter.PROJ_STABLE)
	for i in range(m.inventory.slots.size()):
		m.inventory.slots[i] = null
	m.inventory.changed.emit()

# ── ② #1 이월 방목 방출의 자리 ────────────────────────────────────────────────
func _sec2_pasture_order(m: Node) -> void:
	print("── ② #1 이월 방출이 «확산 뒤 · 파종 앞»에 선다 ──")
	var l_spread := _in_func("func _process", "var lost: Dictionary = _run_weed_spread(night, false)")
	var l_rel := _in_func("func _process", "pasture_tried = _try_pending_pasture_release()")
	var l_seed := _in_func("func _process", "seeded_total += tree_ledger.catch_up_seeding(")
	var l_enc := _in_func("func _process", "_run_weed_encroach(night)")
	_check("②a 이월 루프 상대 순서 = 확산(%d) → **방출(%d)** → 파종(%d) → 재점령(%d)"
			% [l_spread, l_rel, l_seed, l_enc],
		l_spread > 0 and l_rel > l_spread and l_seed > l_rel and l_enc > l_seed)
	_check("②b 방출은 **마지막 밤**에만 선다(밤마다가 아니다 — 표가 bool 하나다)",
		_in_func("func _process", "if night == last_night:") > 0
		and _in_func("func _process", "var last_night: int = int(nights[-1])") > 0)
	_check("②c 루프 뒤 블록은 `if not pasture_tried:`를 지나야 도달한다(한 프레임 2회 시도 0)",
		_in_func("func _process", "if not pasture_tried:") > l_enc)
	# 거동 — 단일 창구의 반환·표 계약.
	m._pasture_release_pending = false
	_check("②d 표가 없으면 시도 자체를 안 한다(false)", not m._try_pending_pasture_release())
	var mins0: float = m.clock.minutes
	m.clock.minutes = 10 * 60          # 낮 — 방출 창구가 열린 시각
	m._pasture_release_pending = true
	var tried: bool = m._try_pending_pasture_release()
	_check("②e 표가 있으면 시도한다(true) — 안식 야외·낮이라 창구가 열린다", tried)
	_check("②f 성공한 프레임은 표를 내린다", not m._pasture_release_pending)
	m.clock.minutes = 22 * 60          # 밤 — 방목은 낮의 일이라 방출이 거절된다
	m._pasture_release_pending = true
	var tried_night: bool = m._try_pending_pasture_release()
	_check("②g 밤에도 **시도는 한다**(창구 판정은 방출 함수 몫 — 조건 복제 0)", tried_night)
	_check("②h 그러나 실패한 프레임은 **표를 안 내린다**(R24 #19 «빚진 방출»이 살아남는다)",
		m._pasture_release_pending)
	m.clock.minutes = mins0
	m._pasture_release_pending = false

# ── ③ #2 손상 세이브의 이물이 원장 넷에 눕지 않는다 ───────────────────────────
func _sec3_corrupt_save(m: Node) -> void:
	print("── ③ #2 손상 세이브 방어 — 바깥 그릇의 타입 ──")
	var alt := ""
	for c in CropCatalog.ids():
		if String(c) != CropCatalog.HONRYEONGCHO:
			alt = String(c)
			break
	m._selected_crop = alt
	m._heart_bits = {"miho:1": 1}
	_check("③a 무대: 꼬리 키(`selected_crop`=%s)와 원장이 세이브 전에 실려 있다" % alt,
		alt != "" and not m._heart_bits.is_empty())
	_check("③b 저장 성공", m._save_game())
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	_check("③c 무대: 페이로드에 네 키가 Dictionary로 실렸다",
		raw.get("heart_bits") is Dictionary and raw.get("season_q_week") is Dictionary
		and raw.get("ever_married") is Dictionary and raw.get("jealousy") is Dictionary)
	raw["heart_bits"] = 0                 # 손으로 고친 평문 세이브가 실을 수 있는 이물 넷
	raw["season_q_week"] = "corrupt"
	raw["ever_married"] = [1, 2]
	raw["jealousy"] = 3.5
	_check("③d 손상 페이로드 기록 성공(래퍼는 그대로 — `can_load`가 참이라 [이어하기]가 뜬다)",
		m.saver.save_game(raw, m._active_slot) and m.saver.can_load(m._active_slot))
	var loaded: bool = m._load_game()
	_check("③e `_load_game`이 **끝까지 돌고 true를 낸다**(반쪽 새 게임 0)", loaded)
	_check("③f 꼬리 키까지 복원됐다(`selected_crop`=%s — 넷째 원장 아래 줄이 실제로 돌았다)"
			% m._selected_crop, m._selected_crop == alt)
	_check("③g 이물은 원장에 안 눕는다 — 네 원장이 전부 빈 채로 떨어진다(«키 없는 구세이브»와 동치)",
		m._heart_bits.is_empty() and m._season_q_week.is_empty()
		and m._ever_married.is_empty() and m._jealousy.is_empty())

# ── ⑤ #4 나락 열쇠 개방 고지가 «이번 개봉»을 본다 ─────────────────────────────
func _sec5_narak_key(m: Node) -> void:
	print("── ⑤ #4 나락 열쇠 고지 = 전이 검출 ──")
	var needle := "나락 진입로가 열렸다"
	m.mine_floors._chests = {}
	m._narak_key_found = true              # 이미 60층에서 받아 둔 세이브
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	await _settle(m)
	m.mine_floors._depth = 60
	m._descend_mine(20)
	await _settle(m)
	_check("⑤pre 무대: 20층 레이아웃에 보상 상자가 있다",
		m._mine_floor == 20 and m._mine_layout.has("chest"))
	if not m._mine_layout.has("chest"):
		return
	m.player.global_position = m._tile_center_px(Vector2i(m._mine_layout["chest"]))
	await process_frame
	_check("⑤a 무대: 열쇠는 이미 손에 넣었고(플래그 참) 지금 여는 것은 20층 상자다",
		m._narak_key_found and m._is_mine_chest(m._player_tile()))
	m.notice_feed._items.clear()
	m._open_mine_chest()
	_check("⑤b 열쇠가 안 나온 개봉은 진입로 고지를 **안 낸다**(거짓 사건 고지 0)",
		m.mine_floors.is_chest_opened(20) and _notice_hits(m, needle) == 0)
	# 대조 — 실제로 열쇠가 나오는 60층에서는 그대로 발화한다(전이 검출이 죽지 않았다).
	m._narak_key_found = false
	m._descend_mine(60)
	await _settle(m)
	m.player.global_position = m._tile_center_px(Vector2i(m._mine_layout["chest"]))
	await process_frame
	m.notice_feed._items.clear()
	m._open_mine_chest()
	_check("⑤c 열쇠를 실제로 받은 개봉은 그대로 고지한다(플래그도 선다)",
		m._narak_key_found and _notice_hits(m, needle) == 1)

# ── ⑩ #11 괭이 AoE가 화분 밑을 갈지 않는다 ───────────────────────────────────
func _sec10_hoe_pot(m: Node) -> void:
	print("── ⑩ #11 괭이 ↔ 화분(양방향 가드의 빠진 반쪽) ──")
	# 무대 = 늘봄방 경작면(실내 + SOIL이 동시에 성립하는 유일한 자리 — 두 술어가 겹치는 그 판).
	m.carpenter.load_save({"active": [], "done": [Carpenter.PROJ_GREENHOUSE]})
	m._refresh_greenhouse()
	m._region = RegionCatalog.HOME
	m._indoor = "늘봄방"
	var r: Rect2i = m.GREENHOUSE_PLOT_RECT
	var pot_t := Vector2i(r.position.x + 2, r.position.y + 2)
	var bare_t := Vector2i(r.position.x + 5, r.position.y + 2)
	_check("⑩a 무대: 경작면 두 칸이 SOIL·미경작·경작 자격이다(%s · %s)" % [str(pot_t), str(bare_t)],
		m._grid[pot_t.y][pot_t.x] == m.SOIL and m._grid[bare_t.y][bare_t.x] == m.SOIL
		and m._is_farmable(pot_t) and m._is_farmable(bare_t)
		and not m._field_at(pot_t).is_tilled(pot_t))
	_check("⑩b 무대: 그 칸에 화분을 놓을 수 있고(`_can_place_pot`) 실제로 섰다",
		m._can_place_pot(pot_t) and m.garden_pot.place(pot_t) and m._pot_at(pot_t))
	m._target = pot_t
	_check("⑩c 근거: 화면은 화분 줄만 말한다 — 좌클릭 동사 광고가 0이다(그래서 무광고 과금이었다)",
		m._pot_prompt() != "" and not m._pot_prompt().contains("좌클릭"))
	_select(m, ItemCatalog.HOE)
	var e0: int = m.energy.current
	m._use_tool()
	_check("⑩d 괭이질이 그 칸을 **안 간다**(고랑 0 · 혼력 소모 0 = 과금 없는 무동작)",
		not m._field_at(pot_t).is_tilled(pot_t) and m.energy.current == e0)
	m._target = bare_t
	m._use_tool()
	_check("⑩e 과잉 거절 0: 화분 없는 이웃 칸은 그대로 갈린다(그리고 혼력을 쓴다)",
		m._field_at(bare_t).is_tilled(bare_t) and m.energy.current < e0)
	# 티어 괭이 AoE — 겨누지도 않은 이웃 화분까지 갈던 갈래.
	m.tool_tier.set_tier(ItemCatalog.HOE, ToolTier.MAX_TIER)   # 사각 AoE(중간 티어는 일렬 = 플레이어 방향 의존)
	var aoe_center := Vector2i(pot_t.x, pot_t.y + 1)
	var neighbors: Array = []
	for at: Vector2i in m._farm_aoe_tiles(aoe_center, m.tool_aoe(ItemCatalog.HOE)):
		if at != pot_t and not m._field_at(at).is_tilled(at):
			neighbors.append(at)
	m._target = aoe_center
	m._use_tool()
	var hoed := 0
	for at: Vector2i in neighbors:
		if m._field_at(at).is_tilled(at):
			hoed += 1
	_check("⑩f 사각 AoE(%s)도 화분 칸만 건너뛴다(이웃 %d칸 중 %d칸이 갈렸고 화분 칸은 그대로)"
			% [str(m.tool_aoe(ItemCatalog.HOE)), neighbors.size(), hoed],
		pot_t in m._farm_aoe_tiles(aoe_center, m.tool_aoe(ItemCatalog.HOE))
		and neighbors.size() > 0 and hoed == neighbors.size()
		and not m._field_at(pot_t).is_tilled(pot_t))
	m.tool_tier.set_tier(ItemCatalog.HOE, 0)

# ── ⑪ #12 성숙 화분 + 화분 든 손 = 두 동사를 함께 광고 ────────────────────────
func _sec11_pot_prompt(m: Node) -> void:
	print("── ⑪ #12 화분 프롬프트 ↔ 광고되지 않은 LMB ──")
	var t: Vector2i = m.garden_pot.tiles()[0] if not m.garden_pot.tiles().is_empty() else Vector2i(-1, -1)
	_check("⑪pre 무대: ⑩이 세운 화분이 그대로 있다", t.x >= 0)
	if t.x < 0:
		return
	var crop := String(CropCatalog.ids()[0])
	m.garden_pot.plant(t, crop)
	m.garden_pot._pots[t]["grown_days"] = CropCatalog.growth_days(crop)
	m._target = t
	_check("⑪a 무대: 그 화분이 다 자랐다(%s)" % CropCatalog.name_of(crop), m.garden_pot.is_mature(t))
	_select(m, ItemCatalog.HOE)
	_check("⑪b 화분이 아닌 것을 들었으면 종전 그대로 «[우클릭] 수확» 한 줄",
		m._pot_prompt() == "[우클릭] 수확")
	_select(m, ItemCatalog.GARDEN_POT)
	var line: String = m._pot_prompt()
	_check("⑪c 화분을 든 손이면 **두 동사를 다 말한다**(수확·회수 + 소각 경고) — 「%s」" % line,
		line.contains("[우클릭] 수확") and line.contains("[좌클릭]") and line.contains("함께 사라진다"))
	# 하중 — 그 프레임의 LMB 실효가 실제로 회수다(성숙 여부를 안 본다 = 광고가 필요한 이유).
	m._remove_garden_pot(t)
	_check("⑪d 실효 확인: 좌클릭 회수는 성숙 여부를 안 보고 결실째 걷어 간다(원장 비었다)",
		not m._pot_at(t) and not m.garden_pot.is_planted(t))
	m._indoor = ""
	m.carpenter.load_save({"active": [], "done": []})
	m._refresh_greenhouse()

# ── ⑫ #13 레어크로우 머리 칸(아트 폭 = 예약 폭) ───────────────────────────────
func _sec12_rarecrow_head(m: Node) -> void:
	print("── ⑫ #13 레어크로우는 두 칸을 먹는다 ──")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	var crow_id := String(ItemCatalog.RARECROWS[0])
	var tex: Texture2D = m._prop_tex(crow_id)
	_check("⑫a 근거: 아트가 밑동 위로 한 칸 더 자란다(%s 높이 %d = TILE×%d)"
			% [crow_id, int(tex.get_size().y) if tex != null else -1,
				int(tex.get_size().y / m.TILE) if tex != null else -1],
		tex != null and int(tex.get_size().y) == m.TILE * 2 and int(tex.get_size().x) == m.TILE)
	# 마당에서 밑동·머리·대조군 셋이 전부 비어 있는 자리를 찾는다(좌표 복제 0).
	var base := Vector2i(-1, -1)
	for yy in range(m.ENCROACH_SCAN_RECT.position.y + 2, m.ENCROACH_SCAN_RECT.end.y):
		for xx in range(m.ENCROACH_SCAN_RECT.position.x, m.ENCROACH_SCAN_RECT.end.x):
			var c := Vector2i(xx, yy)
			if m._can_place_rarecrow(c) and m._can_place_sprinkler(c + Vector2i(0, -1)) \
					and m._can_place_sprinkler(c + Vector2i(0, -2)):
				base = c
				break
		if base.x >= 0:
			break
	_check("⑫b 무대: 밑동 %s와 그 위 두 칸이 지금은 전부 비어 있다" % str(base), base.x >= 0)
	if base.x < 0:
		return
	var head: Vector2i = base + Vector2i(0, -1)
	var above: Vector2i = base + Vector2i(0, -2)
	m.rarecrow.place(base, crow_id)
	_check("⑫c 밑동과 **머리 칸**이 둘 다 설치물 성역이다(원장은 밑동만 드는데 술어가 그림을 따른다)",
		m._installation_at(base) and m._installation_at(head))
	_check("⑫d 그래서 머리 칸에 스프링클러를 못 세운다(덮여 사라지던 자리) — 한 칸 위는 그대로 열림",
		not m._can_place_sprinkler(head) and m._can_place_sprinkler(above))
	var occ: Dictionary = m._home_occupied_tiles()
	_check("⑫e 자체 파종도 머리 칸을 성역으로 든다(재획득 불가 수집물을 나무가 묻던 자리)",
		not m._is_tree_seed_free(RegionCatalog.HOME, head, occ))
	# 역방향은 레어크로우를 잠시 걷고 잰다 — 머리 축**만** 남겨야 이 항이 실제로 무게를 진다.
	m.rarecrow.remove(base)
	_check("⑫f 역방향 대칭: 남이 선 칸을 머리로 덮는 배치는 거절된다(밑동 자리는 멀쩡한데도)",
		m.sprinkler.place(above, Sprinkler.TIER_1)
		and m._can_place_sprinkler(head) and not m._can_place_rarecrow(head))
	m.sprinkler.remove(above)
	m.rarecrow.place(base, crow_id)
	m.rarecrow.remove(base)
	_check("⑫g 걷어 내면 두 칸이 함께 풀린다(가드가 래치가 아니라 그 프레임의 원장이다)",
		not m._installation_at(base) and not m._installation_at(head)
		and m._can_place_sprinkler(head))

# ── ⑬ #14 비차단 마일스톤 팝업 ↔ 상시 HUD ────────────────────────────────────
func _sec13_milestone_hud(m: Node) -> void:
	print("── ⑬ #14 마일스톤 팝업은 체력 바를 안 지운다 ──")
	# 앞 절들이 남긴 모달·연출 잔재를 걷고 시작한다(이 절이 재는 것은 «마일스톤 판 하나»의 효과다).
	_dismiss_dialogue(m)
	if m.frame.is_open():
		m.frame.close()
	m.milestone_panel.visible = false
	m.mirror_panel.visible = false
	m.ending_panel.visible = false
	m._illust_id = ""
	m._sleeping = false
	await process_frame
	_check("⑬a 무대: 평소엔 상시 HUD 셋이 켜져 있다(대화 %s · 프레임 %s · 연출 %s)"
			% [str(m.dialogue.is_open()), str(m.frame.is_open()), str(m.cutscene != null)],
		m.vitals.visible and m.hotbar.visible and m.clock_hud.visible)
	if not m.calendar_panel.is_open():
		m.calendar_panel.toggle()
	m.milestone_panel.visible = true
	await process_frame
	await process_frame
	_check("⑬b 축하 팝업이 떠도 체력·핫바·시계가 그대로다(6초를 체력 바 없이 싸우지 않는다)",
		m.vitals.visible and m.hotbar.visible and m.clock_hud.visible)
	_check("⑬c 열어 둔 절기 달력도 축하 하나에 조용히 닫히지 않는다", m.calendar_panel.is_open())
	m.calendar_panel.close()
	m.milestone_panel.visible = false
	# 대조군 — 면제 사유가 남아 있는 판(메뉴 프레임: 입력을 실제로 잡는다)은 종전대로 HUD를 접는다.
	m.frame.open(InventoryFrame.CTX_MENU)
	await process_frame
	await process_frame
	_check("⑬d 대조군: 입력을 잡는 판(메뉴 프레임)은 종전대로 상시 HUD를 접는다",
		m.frame.is_open() and not m.vitals.visible and not m.hotbar.visible)
	m.frame.close()
	await process_frame

# ── ⑭ #15 비차단 팝업의 초는 모든 모달 아래에서도 깎인다 ─────────────────────
func _sec14_popup_lifetime(m: Node) -> void:
	print("── ⑭ #15 『정지 주인 = 재개 주인』 ──")
	var l_tick := _in_func("func _process", "_tick_popup_lifetimes(delta)")
	var l_edit := _in_func("func _process", "if _edit_mode:")
	var l_deco := _in_func("func _process", "if _deco_mode:")
	var l_trans := _in_func("func _process", "if _transitioning:")
	var l_dlg := _in_func("func _process", "if dialogue.is_open():")
	_check("⑭a 수명 훅(%d행)이 조기 반환 전부보다 위다 — 배치(%d)·꾸미기(%d)·전환(%d)·대화(%d)"
			% [l_tick, l_edit, l_deco, l_trans, l_dlg],
		l_tick > 0 and l_edit > l_tick and l_deco > l_tick and l_trans > l_tick and l_dlg > l_tick)
	# 거동 — 프레임을 끊는 모드 둘에서 각각 초가 실제로 깎이고 판이 거둬진다.
	for mode in ["_transitioning", "_deco_mode"]:
		m.cafe_summary_panel.visible = true
		m._cafe_summary_secs = 0.08
		m.set(mode, true)
		var guard := 0
		while m._cafe_summary_secs > 0.0 and guard < 60:
			await process_frame
			guard += 1
		m.set(mode, false)
		_check("⑭b `%s`로 프레임이 끊긴 채로도 마감 정산 판이 %d프레임 만에 거둬진다"
				% [mode, guard],
			m._cafe_summary_secs <= 0.0 and not m.cafe_summary_panel.visible and guard < 60)
	m.milestone_panel.visible = true
	m._milestone_popup_secs = 0.08
	m._transitioning = true
	var g2 := 0
	while m._milestone_popup_secs > 0.0 and g2 < 60:
		await process_frame
		g2 += 1
	m._transitioning = false
	_check("⑭c 마일스톤 판도 같은 손이 거둔다(두 판이 한 자리에서 늙는다)",
		m._milestone_popup_secs <= 0.0 and not m.milestone_panel.visible and g2 < 60)

# ── ⑮ #16 선언된 비차단 = 실효 비차단(클릭을 안 삼킨다) ──────────────────────
func _sec15_popup_click(m: Node) -> void:
	print("── ⑮ #16 두 판이 클릭을 안 삼킨다 ──")
	_check("⑮a 마감 정산·마일스톤 두 판이 마우스 입력을 통과시킨다(MOUSE_FILTER_IGNORE)",
		m.cafe_summary_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and m.milestone_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("⑮b 하중: 실제로 입력을 잡아야 하는 판은 그대로 STOP이다(무차별 IGNORE가 아니다)",
		m.mirror_panel.mouse_filter == Control.MOUSE_FILTER_STOP)
	_check("⑮c 형제 근거: 이미 통과시키던 판들과 같은 값이다(마무리 화면)",
		m.ending_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	# 꾸미기 세션 내내 남던 갈래는 ⑭가 함께 닫는다 — 그 사실을 여기서 한 번 더 잰다.
	m.cafe_summary_panel.visible = true
	m._cafe_summary_secs = 0.08
	m._deco_mode = true
	var guard := 0
	while m._cafe_summary_secs > 0.0 and guard < 60:
		await process_frame
		guard += 1
	m._deco_mode = false
	_check("⑮d 꾸미기 세션 중에도 판이 스스로 거둬진다(세션 내내 편집면을 덮던 갈래 0)",
		not m.cafe_summary_panel.visible)

# ── ⑯ #17 더비 부상 선검사 ───────────────────────────────────────────────────
func _sec16_derby_award(m: Node) -> void:
	print("── ⑯ #17 태그를 태우고 부상만 잠기는 갈래 0 ──")
	var crow := SeasonalEvent.DERBY_RARECROW
	var gold_reward: Dictionary = SeasonalEvent.derby_reward(SeasonalEvent.DERBY_RARECROW_EXCHANGES)
	_check("⑯a 근거: 문턱을 넘는 %d번째 보상은 «엽전»이라 인벤 자리를 한 칸도 안 쓴다(만재에서도 성립)"
			% SeasonalEvent.DERBY_RARECROW_EXCHANGES,
		String(gold_reward.get("kind", "")) == "gold")
	for i in range(m.inventory.slots.size()):
		m.inventory.slots[i] = null
	m.inventory.changed.emit()
	m.seasonal_event.market_bought = []
	m.rarecrow.load_save({})
	m.inventory.remove_item(crow, m.inventory.count_of(crow))
	_fill_backpack_full(m.inventory)
	_check("⑯b 무대: 빈 슬롯 0 · 부상을 아직 못 받았다",
		not m.inventory.has_free_slot() and not m.seasonal_event.has_bought(crow)
		and not m._rarecrow_owned(crow))
	_check("⑯c 선검사가 거절한다(사다리 보상은 자리를 안 먹어도 부상이 못 들어간다)",
		not m._derby_awards_fit(gold_reward))
	m.seasonal_event.derby_day = m.clock.day
	m.seasonal_event.derby_tags = 1
	m.seasonal_event.derby_exchanges = SeasonalEvent.DERBY_RARECROW_EXCHANGES - 1
	var gold0: int = m.wallet.gold
	m.notice_feed._items.clear()
	m._try_derby_exchange()
	_check("⑯d 교환 자체가 **시작되지 않는다** — 태그도 원장도 지갑도 한 칸 안 움직인다",
		m.seasonal_event.tags_on(m.clock.day) == 1 and m.wallet.gold == gold0
		and m.seasonal_event.derby_exchanges == SeasonalEvent.DERBY_RARECROW_EXCHANGES - 1)
	_check("⑯e 사유를 그 자리에서 말한다(그날 이행 가능한 지시)",
		_notice_hits(m, "낚시 더비 부상을 받을 수 없다") == 1)
	# 자리를 비우면 같은 [F]가 사다리 보상과 부상을 함께 준다.
	m.inventory.slots[0] = null
	m.inventory.changed.emit()
	m.notice_feed._items.clear()
	m._try_derby_exchange()
	_check("⑯f 한 칸을 비우면 그대로 성립한다 — 태그 소비 · 엽전 지급 · 부상 원장 기록",
		m.seasonal_event.tags_on(m.clock.day) == 0 and m.wallet.gold > gold0
		and m.seasonal_event.derby_exchanges == SeasonalEvent.DERBY_RARECROW_EXCHANGES
		and m.seasonal_event.has_bought(crow) and m.inventory.count_of(crow) == 1)
	for i in range(m.inventory.slots.size()):
		m.inventory.slots[i] = null
	m.inventory.changed.emit()

# ── ⑰ #18 증정 창구의 중복 방어가 상자까지 본다 ──────────────────────────────
func _sec17_gift_windows(m: Node) -> void:
	print("── ⑰ #18 상자에 넣으면 재발급되던 두 창구 ──")
	var rod := ItemCatalog.ROD_T1
	var sword := WeaponCatalog.SWORD_RUSTY
	for pair in [[rod, "_boatman_rod_given", "_grant_boatman_rod_lines"],
			[sword, "_mugol_sword_given", "_grant_mugol_sword_lines"]]:
		var id := String(pair[0])
		m.inventory.remove_item(id, m.inventory.count_of(id))
		m.chest.store(id, 1)                      # 백팩엔 없고 **집 상자에만** 있는 상태
		m.set(String(pair[1]), false)             # 플래그 없는 구세이브
		_check("⑰pre 무대(%s): 백팩 0 · 상자 1 · 1회성 플래그 없음" % ItemCatalog.name_of(id),
			m.inventory.count_of(id) == 0 and m._count_anywhere(id) == 1
			and not bool(m.get(String(pair[1]))))
		var lines: PackedStringArray = m.call(String(pair[2]))
		_check("⑰a %s — 두 번째 사본이 안 생기고 플래그만 접힌다(세상에 하나)"
				% ItemCatalog.name_of(id),
			lines.is_empty() and m._count_anywhere(id) == 1
			and bool(m.get(String(pair[1]))))
		# 대조군 — 어디에도 없으면 종전대로 정상 지급된다(가드가 증정 자체를 죽이지 않았다).
		while m.chest.count_of(id) > 0:
			m.chest.remove_at(m.chest._find_id(id), 1)
		m.set(String(pair[1]), false)
		var lines2: PackedStringArray = m.call(String(pair[2]))
		_check("⑰b 대조군(%s): 어디에도 없으면 그대로 증정된다(백팩 1 · 대사 %d줄)"
				% [ItemCatalog.name_of(id), lines2.size()],
			m.inventory.count_of(id) == 1 and not lines2.is_empty()
			and bool(m.get(String(pair[1]))))
		m.inventory.remove_item(id, m.inventory.count_of(id))

# ── ⑱ #19 퍼펙트 창 금박 테 = 딸 수 있는 창 ──────────────────────────────────
func _sec18_perfect_window() -> void:
	print("── ⑱ #19 퍼펙트 창 채색 술어 ↔ 실효 술어 ──")
	var soft := {"weight_class": FishingSession.WeightClass.MEDIUM, "stamina": 999.0, "tension_rise": 4.0,
		"burst_period": 1.0, "burst_len": 1.0}
	# ㉠ 줄을 **푼 채** 발버둥 시작을 맞는다 = 창은 열리지만 무장이 안 된다.
	var a := FishingSession.new(31337, soft, {"max_class": FishingSession.WeightClass.MEDIUM})
	a.cast()
	var guard := 0
	_check("⑱pre 무대 ㉠: 격투에 들어갔다", _advance_to_fight(a))
	while not a.is_bursting() and a.is_active() and guard < 800:
		a.tick(0.05, false)        # 푼 채로 발버둥을 기다린다
		guard += 1
	_check("⑱a 무대: 줄을 푼 채 발버둥이 시작됐다", a.is_bursting())
	_check("⑱b 금박 테가 **안 선다** — 무장 없는 창은 딸 수 없다(도달 불가 보상 광고 0)",
		not a.is_perfect_window())
	var before: int = a.perfect_count
	a.tick(0.05, true)
	a.tick(0.05, false)            # 창 안에서 당겼다 풀어도
	_check("⑱c 실효도 그대로 0이다(표시와 실효가 같은 답을 낸다 — %d건)" % a.perfect_count,
		a.perfect_count == before)
	# ㉡ 대조군 — 당기며 시작을 맞으면 창이 서고 실제로 딸 수 있다.
	var b := FishingSession.new(31337, soft, {"max_class": FishingSession.WeightClass.MEDIUM})
	b.cast()
	var g2 := 0
	_check("⑱pre 무대 ㉡: 대조군도 격투에 들어갔다", _advance_to_fight(b))
	while not b.is_bursting() and b.is_active() and g2 < 800:
		b.tick(0.05, true)
		g2 += 1
	_check("⑱d 대조군: 당기며 맞은 발버둥은 금박 테가 선다", b.is_bursting() and b.is_perfect_window())
	b.tick(0.05, false)
	_check("⑱e 그 창의 풀기 전환은 실제로 크리다(퍼펙트 %d건 — 광고가 참이다)" % b.perfect_count,
		b.perfect_count == 1)

# ── ⑲ #20 꾸미기 고스트의 «놓을 수 있다» ────────────────────────────────────
func _sec19_deco_ghost(m: Node) -> void:
	print("── ⑲ #20 채색 술어 ↔ 실효 술어(꾸미기) ──")
	var ids: Array = HomeDecoCatalog.set_ids()
	var locked := ""
	var unlocked := ""
	for sid in ids:
		if m.home_deco.is_unlocked(String(sid)):
			if unlocked == "":
				unlocked = String(sid)
		elif locked == "":
			locked = String(sid)
	_check("⑲a 무대: 새 게임 팔레트에 해금 세트(%s)와 **미해금 세트**(%s)가 함께 있다(순환은 전부 돈다)"
			% [unlocked, locked], unlocked != "" and locked != "" and ids.size() > 2)
	if locked == "" or unlocked == "":
		return
	# 유효 칸 하나를 바닥 레이어에서 찾는다(좌표 복제 0 — 원장에서 판다).
	m._deco_layer = m._DECO_LAYERS.find(HomeDecoCatalog.L_FLOOR)
	m._deco_item = 0
	var floor_cells: Array = m.home_deco._cells_for(HomeDecoCatalog.L_FLOOR).keys()
	_check("⑲b 무대: 집 바닥 유효 칸이 %d칸 잡혔다" % floor_cells.size(), not floor_cells.is_empty())
	if floor_cells.is_empty():
		return
	var cell: Vector2i = floor_cells[0]
	var outside := Vector2i(-99, -99)
	m._deco_set = ids.find(unlocked)
	_check("⑲c 해금 세트 + 유효 칸 = 고스트가 선다(그리고 실제로 놓인다)",
		m._deco_ghost_valid(cell)
		and m.home_deco.place(cell, m._deco_cur_set(), m._deco_cur_item(), 0))
	_check("⑲d 방 밖 칸은 고스트가 **안 선다** — 실효도 거절한다(두 답이 같다)",
		not m._deco_ghost_valid(outside)
		and not m.home_deco.place(outside, m._deco_cur_set(), m._deco_cur_item(), 0))
	m._deco_set = ids.find(locked)
	m._deco_item = 0
	_check("⑲e 미해금 세트는 유효 칸에서도 고스트가 안 선다(항상 참이던 죽은 갈래가 살아났다)",
		not m._deco_ghost_valid(cell)
		and not m.home_deco.place(cell, m._deco_cur_set(), m._deco_cur_item(), 0))
	m.notice_feed._items.clear()
	m._deco_place(cell)
	_check("⑲f 사유를 갈라 말한다 — «칸»이 아니라 «세트»가 잠긴 것이다",
		_notice_hits(m, "세트는 아직 잠겨 있다") == 1 and _notice_hits(m, "여기엔 놓을 수 없어요") == 0)
	_check("⑲g 세트 순환 알림에도 잠김이 실린다 — 「%s」" % m._deco_set_label(),
		m._deco_set_label().contains("(잠김)"))
	m._deco_set = ids.find(unlocked)
	_check("⑲h 해금 세트 줄에는 그 표기가 없다 — 「%s」" % m._deco_set_label(),
		not m._deco_set_label().contains("(잠김)"))
	# 벽지를 든 채 바닥 칸 = 그 레이어의 유효 칸이 아니다(레이어 축).
	m._deco_layer = m._DECO_LAYERS.find(HomeDecoCatalog.L_WALL)
	m._deco_item = 0
	_check("⑲i 레이어 축도 같이 든다: 벽지를 든 채 바닥 칸이면 고스트가 안 선다",
		not m.home_deco.can_place_cell(HomeDecoCatalog.L_WALL, cell)
		and not m._deco_ghost_valid(cell))
	m._deco_layer = m._DECO_LAYERS.find(HomeDecoCatalog.L_FLOOR)

# ── ⑳ #21 「서운함」 배지 색 ─────────────────────────────────────────────────
func _sec20_heart_badge() -> void:
	print("── ⑳ #21 금박이 뜻을 뒤집지 않는다 ──")
	# 로스터를 **소스에서 판다** — `_heart_badge`가 낳는 문자열 전수(하드코딩 금지).
	var head := _line_of(_src, "func _heart_badge")
	var badges: Array = []
	for i in range(head + 1, _src.size()):
		if _src[i].begins_with("func "):
			break
		var ln: String = _src[i].strip_edges()
		if ln.begins_with("return \""):
			var lit := ln.substr(8, ln.length() - 9)
			if lit != "":            # `return ""` = 배지 없음(칠할 것이 없다)
				badges.append(lit)
	_check("⑳a 무대: 배지 로스터를 소스에서 팠다(%d종 — %s)" % [badges.size(), ", ".join(badges)],
		badges.size() >= 5 and badges.has("서운함") and badges.has("진급 대기"))
	var missing: Array = []
	for b in badges:
		if String(b) != "진급 대기" and not InventoryFrame.HEART_BADGE_COLORS.has(String(b)):
			missing.append(String(b))
	_check("⑳b 「진급 대기」(=의도된 금박) 말고는 전부 전용 색을 받는다(폴백으로 새는 배지 %d종)"
			% missing.size(), missing.is_empty())
	var col: Color = InventoryFrame.HEART_BADGE_COLORS.get("서운함", HanjiUi.GOLD_SOFT)
	_check("⑳c 「서운함」이 금박과 **다른 색**이다 — 페널티가 «지금 할 수 있는 일»로 안 읽힌다",
		not col.is_equal_approx(HanjiUi.GOLD_SOFT))
	var clashes: Array = []
	for k in InventoryFrame.HEART_BADGE_COLORS:
		if String(k) != "서운함" and (InventoryFrame.HEART_BADGE_COLORS[k] as Color).is_equal_approx(col):
			clashes.append(String(k))
	_check("⑳d 관계 삼색과도 안 겹친다(색이 곧 뜻인 자리 — 충돌 %d건)" % clashes.size(),
		clashes.is_empty())
