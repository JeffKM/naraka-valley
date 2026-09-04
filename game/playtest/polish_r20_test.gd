extends SceneTree
# ★[폴리시 20회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#8).
#
# 렌즈: R19 diff 리뷰(#0) · 에너지 0 경계(#1·#2·#3) · 해금 첫 프레임(#4·#5·#6) ·
#       컷신/사건 재진입(#7) · 다중 로맨스 교차(#8).
#
# 이 배치의 태도 셋.
#   ㉠ **세 결함이 한 술어에 걸려 있다.** #1·#8은 `_player_blocked_at`이 `_grid`만 읽어 프롭
#      충돌을 못 보던 한 뿌리이고(그래서 #8은 DUP), #2는 그 술어를 *배치* 소비처가 한 장의
#      스냅샷으로만 쓰던 자리다. 그래서 ②·③·⑨는 같은 무대를 이어 쓰며 서로 다른 창구에서 잰다.
#   ㉡ **비료 삼형제도 한 뿌리다.** #4·#5·#6은 전부 "성숙 임계가 실시간으로 재파생된다"는 한
#      사실의 세 방향(즉시 성숙 · 역행 · 쿨다운 침식)이고, 봉합도 한 곳(`need_days` 스냅샷)이다.
#      그래서 ⑤⑥⑦은 세 방향을 각각 **수치로** 못 박는다.
#   ㉢ **좌표를 옮겨 적지 않는다.** ①의 과수 존은 orchard 원장에서, ②의 열린 칸은
#      `_encroach_candidates()`에서, ⑦의 쿨다운은 CropCatalog에서 판다.
#
# 무엇을 보증하나(번호 = 20회차 헌트 발견 인덱스):
#   ① #0 재점령·절기 재스폰 후보의 성역 여덟 겹에 **혼의 나무(과수) 원장을 묻는 줄이 없어**,
#      심어 둔 과수 밑동 위에 업화석·석화 고목이 겹쳐 섰다(스무 줄 아래 `_weed_spread_class`가
#      확산 쪽에서 지키는 「과수 = 면제」 불변식을 정면으로 깨던 단방향 가드).
#   ② #1 `_player_blocked_at`이 `_tile_blocked`(=`_grid`)·작물·과수 셋만 봐서, `_grid`를 한 글자도
#      안 건드리는 프롭 충돌(업화석·석화 고목·통나무·울타리·덤불·돌담·나무 발치)을 전부
#      "통행 가능"으로 답했다 — R19 #15/#16/#17이 세운 매몰 가드가 안식 마당에서 헛돌았다.
#   ③ #2 절기 재스폰은 8~16칸을 **한 배치로** 세우는데 매몰 가드는 스폰 전 상태 한 장으로만
#      판정해 형제들을 못 봤다(퇴로가 A·B 둘뿐이면 둘 다 통과 → 같은 아침에 사방이 막힌다).
#   ④ #3 점괘 거울이 «예보가 곧 내일의 실제 하늘(빗나감 0)»이라 못 박는데, R19 #13 이후
#      `_forecast_on`이 카페 진척을 읽어 순수하지 않다 — 오늘 낮 매출이 문턱을 넘으면 내일 하늘이
#      뒤집힌다(혼우의 자동 급수를 믿은 밭이 마른다).
#   ⑤ #4 다 자라기 직전 칸에 성장촉진 비료를 뿌리면 임계가 grown_days 아래로 내려앉아
#      **날이 안 바뀌었는데 그 자리에서 즉시 성숙**했다(3일 건너뜀).
#   ⑥ #5 반대 방향 — 성장촉진 위에 품질 비료를 덮으면 임계가 base로 되돌아가 **수확 대기 중이던
#      작물이 미성숙으로 역행**했다(경고 0).
#   ⑦ #6 REGROW 되감기는 base로 재고 성숙 판정만 유효 임계로 재서, −25%짜리 비료가 재결실
#      주기를 −43%까지 깎았다(불사과 명목 7일 → 실제 4일).
#   ⑧ #7 F9 인플레이스 로드가 Books·경지·우편함 원장을 안 되감아, 되찾은 책이 영구 소실되고
#      유물 재수령·서사 편지 재발송이 그 세이브에서 영구 차단됐다.
#   ⑨ #8 = **DUP(#1)**. 시나리오 축이 같은 술어의 같은 구멍이라 별건으로 안 센다. 다만 #1이
#      파종 창구에서 재는 것을 여기서는 **재점령 후보 창구**에서 재, 한 봉합이 두 입구를 닫았음을
#      실증한다(#13도 같은 뿌리 — 배치 B 몫).
#
# 판정: #0~#7 CONFIRMED(전부 봉합) · #8 DUP(#1). REFUTED·OWNER 0건.
#
# 봉합 축(근거 전문은 커밋 본문·각 함수 머리말):
#   · #0 = `_encroach_candidates`에 `orchard.tree_at(t) != Orchard.TREE_NONE` 한 줄. 폭·술어를
#          `_weed_spread_class`(확산 입구)에서 그대로 가져와 두 입구가 한 규칙을 읽는다.
#   · #1 = `_prop_blocked_tiles` — `_rebuild_prop_collision`이 물리에 넘긴 **그 사각**을
#          `_register_prop_blocked`로 되받아 적는 칸 원장. 풋프린트가 아니라 실제 충돌에서
#          파생하므로 캐노피 칸은 여전히 통행 가능이다(머리말이 경계한 과잉 거절 0).
#   · #2 = `_would_entrap_player(t, pending)` — 배치가 이미 세우기로 한 칸을 실은 판정.
#          `Reclaim.season_respawn`이 `solid_ok` Callable로 **뽑는 순간마다** 물어보고, 거절된
#          굴림은 잡초로 내린다(비-SOLID라 매몰 0 · 굴림 스트림 불변 = 결정성 보존).
#   · #3 = 예보 밑에 조건 단서 한 줄. 진척은 줄지 않으니 어긋남의 방향이 하나뿐이라(잠김→열림)
#          그 갈래에서만 붙는다.
#   · #4·#5·#6 = `need_days` 스냅샷. 계산식은 fertilizer_catalog가 스스로 적어 둔 계약
#          ("speed군의 **잔여** 성숙일 곱")이고, REGROW 되감기도 같은 임계를 기준으로 잰다.
#          구세이브는 `load_save`가 종전 값 그대로 백필한다(진행 중 작물 손해 0).
#   · #7 = `has` 가드 셋을 걷고 `.get(key, {})`로 무조건 되감는다(R3·R6·R13·R18의 형제 전파).
#
# 하중 검증(계약을 일부러 깨서 red 확인 후 원복 — 아래는 **실측 결과** 그대로다):
#   #0 `_encroach_candidates`의 orchard 행 삭제 → ①c red(3×3 아홉 칸을 전부 이름으로 되돌려준다) ·
#   #1 `_player_blocked_at`의 `or _prop_blocked_tiles.has(t)` 삭제 → ②d·②e·②f·③a·③c·③e·⑨b red
#      (②f의 알림이 빈 문자열로 떨어져 «거절이 아예 없었다»가 드러난다) ·
#   #2 `season_respawn`의 `solid_ok` 갈래 삭제 → ③e red(239일 중 22일이 A·B를 함께 세운다) ·
#   #3 거울 단서 두 줄 삭제 → ④b red ·
#   #4·#5 `effective_growth_days`의 스냅샷 조회 삭제(= 종전 실시간 재파생) → ⑤c·⑤d·⑥c·⑥d red
#      (⑤d가 「is_mature true · grown_days 9」로 즉시 성숙을, ⑥d가 harvest 「」로 역행을 잡는다) ·
#   #6 REGROW 되감기를 `base - cd`로 되돌림 → ⑦b·⑦c red(grown 5로 되감겨 4일 만에 재성숙) ·
#   #7 세 `.get` 되감기를 `if data.has(...)`로 되돌림 → ⑧c·⑧d·⑧e·⑧f red.
#
# ★하중 검증에서 배운 것: **파괴 지점이 봉합 지점과 같지 않을 수 있다.** #5의 첫 파괴는
#   `_reseal_need`의 계산식을 옛 base 곱으로 되돌리는 것이었는데 ⑥은 초록이었다 — 그 무대의 칸은
#   이미 성숙(잔여 0)이라 `_reseal_need`의 앞 가지에서 되돌아가고, ⑥을 실제로 지키는 것은
#   `need_days` **스냅샷 자체**였다. 계산식이 아니라 축을 무력화해야 red가 뜬다.
#
# 실행: ./run_tests.sh polish_r20   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _src: PackedStringArray = PackedStringArray()
var _rec_src: PackedStringArray = PackedStringArray()
var _field_src: PackedStringArray = PackedStringArray()

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

# ── 소스 스캔 헬퍼(polish_r7~r19의 그 관례 — 니들은 반드시 함수 안에서 센다) ──
func _lines_of_file(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

func _line_in(lines: PackedStringArray, needle: String) -> int:
	for i in range(lines.size()):
		if lines[i].strip_edges().begins_with("#"):
			continue
		if lines[i].contains(needle):
			return i
	return -1

func _line_in_func(lines: PackedStringArray, fn_needle: String, needle: String) -> int:
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
			return i
	return -1

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R20 회귀 — 배치 A(#0~#8) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_rec_src = _lines_of_file("res://reclaim.gd")
	_field_src = _lines_of_file("res://field.gd")
	_check("무대 전제: main(%d행)·reclaim(%d)·field(%d)를 읽었다(부정 단언 공허 통과 방지)"
			% [_src.size(), _rec_src.size(), _field_src.size()],
		_src.size() > 1000 and _rec_src.size() > 100 and _field_src.size() > 100)

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)

	_check_orchard_sanctuary(m)
	var stage: Dictionary = _build_entrap_stage(m)
	_check_prop_blindness(m, stage)
	_check_batch_cumulative(m, stage)
	_check_encroach_dup(m, stage)
	_teardown_entrap_stage(m, stage)
	_check_mirror_forecast_caveat(m)
	_check_speed_fert_no_jump()
	_check_quality_overwrite_no_regress()
	_check_regrow_cooldown_nominal()
	await _check_ledger_rewind(m)

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 과수 밑동은 재점령·재스폰 후보가 아니다 ────────────────────────────
# 공허 통과 방지: ①a가 «그 칸이 봉합 전 실제로 후보였다»를 먼저 세운다 — 애초에 후보가 아닌
# 자리에 나무를 심으면 ①c가 무엇도 증명하지 못한다.
func _check_orchard_sanctuary(m: Node) -> void:
	print("① #0 과수 = 재점령 성역")
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	# 사람이 선 칸도 성역이라(R19 #16) 플레이어를 과수원 존에서 멀리 치운다 — 안 그러면 ①a가
	# 「후보였다」를 못 세우고 ①c의 초록이 다른 이유로 뜬다.
	m.player.global_position = m._tile_center_px(m.SPAWN_TILE)
	var before: Dictionary = {}
	for t in m._encroach_candidates():
		before[t] = true
	var zone: Rect2i = m.ORCHARD_ZONE_RECT
	var anchor := Vector2i(-1, -1)
	for y in range(zone.position.y + 1, zone.end.y - 1):
		for x in range(zone.position.x + 1, zone.end.x - 1):
			var a := Vector2i(x, y)
			if before.has(a) and m.orchard.can_plant(a, m._is_tree_blocked):
				anchor = a
				break
		if anchor.x >= 0:
			break
	_check("①a 무대: 과수원 존 %s 안의 %s는 **봉합 전 재점령 후보였다**(성역 여덟 겹을 전부 통과) · `_grid`도 GROUND"
			% [str(zone), str(anchor)],
		anchor.x >= 0 and before.has(anchor) and m._grid[anchor.y][anchor.x] == m.GROUND)
	if anchor.x < 0:
		return
	var fruit: String = FruitTreeCatalog.ids()[0]
	var planted: bool = m.orchard.plant(anchor, fruit, m.clock.day, m._is_tree_blocked)
	_check("①b 무대: 그 자리에 혼의 나무(%s)를 심었다 — 밑동 SOLID의 실체는 `_orchard_body`뿐이고 `_grid`는 여전히 GROUND(%s)"
			% [fruit, str(m._grid[anchor.y][anchor.x] == m.GROUND)],
		planted and m._grid[anchor.y][anchor.x] == m.GROUND)
	var after: Dictionary = {}
	for t in m._encroach_candidates():
		after[t] = true
	# 3×3 풋프린트 전체 — 카운트가 아니라 **칸을 이름으로** 센다.
	var still: Array = []
	for t in m.orchard.footprint_of(anchor):
		if after.has(t):
			still.append(str(t))
	_check("①c 3×3 풋프린트 9칸이 전부 후보에서 빠졌다(남은 칸: %s) — 밑동 위에 업화석·석화 고목이 안 돋는다"
			% ("없음" if still.is_empty() else " ".join(still)),
		still.is_empty())
	_check("①d 확산 입구도 같은 답이다 — `_weed_spread_class(%s)` = DEST_BLOCK(두 입구가 한 규칙을 읽는다)"
			% str(anchor),
		m._weed_spread_class(anchor, m._home_occupied_tiles()) == Reclaim.DEST_BLOCK)
	# 과잉이 아니다 — 나무를 걷으면 그 칸이 그대로 돌아온다(가드가 칸을 영구히 죽이지 않는다).
	m.orchard.load_save({})
	var back: Dictionary = {}
	for t in m._encroach_candidates():
		back[t] = true
	_check("①e 나무를 걷어내면 %s가 후보로 돌아온다 — 가드가 칸을 영구히 죽이지 않는다" % str(anchor),
		back.has(anchor))

# ── ②③⑨ 공용 무대: 프롭 충돌만으로 3방이 막힌 칸 ───────────────────────────
# 왜 debris를 손으로 놓나: 이 결함의 조건은 «`_grid`는 GROUND인데 물리는 막힌다»이고, 그런 칸을
# 결정적으로 세우는 가장 짧은 길이 재스폰 debris다(업화석 = SOLID_PROPS · FOOT_BAR 밖 = 풀타일).
# 좌표는 `_encroach_candidates()`에서 파낸다 — 순수 빈 GROUND·프롭 미점유가 그 함수의 계약이라
# 무대 전제를 옮겨 적을 필요가 없다.
func _build_entrap_stage(m: Node) -> Dictionary:
	m._indoor = ""
	if m._region != RegionCatalog.HOME:
		m._rebuild_region(RegionCatalog.HOME)
	m.player.global_position = m._tile_center_px(m.SPAWN_TILE)
	var open_set: Dictionary = {}
	for t in m._encroach_candidates():
		open_set[t] = true
	var here := Vector2i(-1, -1)
	for t: Vector2i in open_set.keys():
		var all_open := true
		for d in DIRS:
			if not open_set.has(t + d):
				all_open = false
				break
		if all_open:
			here = t
			break
	if here.x < 0:
		return {"here": here}
	# 북·동·서에 업화석을 놓고 남쪽 한 칸만 남긴다.
	var blocked: Array = [here + DIRS[0], here + DIRS[1], here + DIRS[3]]
	var free_tile: Vector2i = here + DIRS[2]
	for t in blocked:
		m.reclaim._debris[t] = DebrisCatalog.EMBER
	m._on_reclaim_changed()
	m.player.global_position = m._tile_center_px(here)
	return {"here": here, "blocked": blocked, "free": free_tile}

func _teardown_entrap_stage(m: Node, stage: Dictionary) -> void:
	if not stage.has("blocked"):
		return
	for t in stage["blocked"]:
		m.reclaim._debris.erase(t)
	m._on_reclaim_changed()
	m.player.global_position = m._tile_center_px(m.SPAWN_TILE)

# ── ② #1 매몰 술어가 프롭 충돌을 본다 ───────────────────────────────────────
func _check_prop_blindness(m: Node, stage: Dictionary) -> void:
	print("② #1 `_player_blocked_at` ↔ 프롭 충돌")
	var here: Vector2i = stage["here"]
	_check("②a 무대: 4방이 전부 열린 마당 칸 %s를 찾았다(재점령 후보 = 순수 빈 GROUND·프롭 미점유)"
			% str(here), here.x >= 0)
	if here.x < 0:
		return
	var blocked: Array = stage["blocked"]
	var free_tile: Vector2i = stage["free"]
	# ㉠ 그리드는 이들을 모른다 — 결함 조건이 실제로 성립한다는 증거.
	var grid_names: Array = []
	var grid_blind := true
	for t: Vector2i in blocked:
		grid_names.append("%s(grid=%d·_tile_blocked=%s)" % [str(t), m._grid[t.y][t.x], str(m._tile_blocked(t))])
		if m._grid[t.y][t.x] != m.GROUND or m._tile_blocked(t):
			grid_blind = false
	_check("②b 무대: 업화석 세 칸의 `_grid`가 전부 GROUND이고 `_tile_blocked`는 false다 — %s"
			% " ".join(grid_names), grid_blind)
	# ㉡ 그런데 물리는 막는다 — 원장이 실제 충돌 사각에서 파생됐다.
	var phys_names: Array = []
	var phys_all := true
	for t: Vector2i in blocked:
		phys_names.append("%s=%s" % [str(t), str(m._prop_blocked_tiles.has(t))])
		if not m._prop_blocked_tiles.has(t):
			phys_all = false
	_check("②c 프롭 충돌 원장이 그 세 칸을 쥔다 — %s (`_rebuild_prop_collision`이 세운 사각에서 직접 파생)"
			% " ".join(phys_names), phys_all)
	var pred_names: Array = []
	var pred_all := true
	for t: Vector2i in blocked:
		pred_names.append("%s=%s" % [str(t), str(m._player_blocked_at(t))])
		if not m._player_blocked_at(t):
			pred_all = false
	_check("②d 매몰 술어가 그 셋을 막힘으로 답한다 — %s" % " ".join(pred_names), pred_all)
	_check("②e 그래서 마지막 퇴로 %s가 지목된다 — `_would_entrap_player` %s"
			% [str(free_tile), str(m._would_entrap_player(free_tile))],
		m._would_entrap_player(free_tile))
	# ㉢ 라이브: 그 칸에 트렐리스를 심으려 하면 거절되고 **왜인지 말한다**.
	var trellis := ""
	for c in CropCatalog.ids():
		if CropCatalog.is_trellis(c):
			trellis = c
			break
	var farm_snap: Dictionary = m.farm.to_save()
	var prev_slot: Variant = m.inventory.slots[m.inventory.selected_index]
	m.inventory.slots[m.inventory.selected_index] = {"id": ItemCatalog.seed_id(trellis), "count": 99, "quality": 0}
	m._field_at(free_tile).hoe(free_tile)
	m._target = free_tile
	m._target_valid = m._is_farmable(free_tile)
	m.notice_feed._items.clear()
	m._use_tool()
	var told := ""
	for it in m.notice_feed._items:
		told = String(it["text"])
	_check("②f 라이브: %s(%s) 씨앗이 %s에 안 심긴다 · 화면이 이유를 말한다 — 「%s」"
			% [CropCatalog.name_of(trellis), trellis, str(free_tile), told],
		not m.farm.is_planted(free_tile) and told.contains("갇힌다"))
	# ㉣ 과잉이 아니다 — 한 칸을 치우면 퇴로가 둘이 되어 그대로 심긴다.
	var lifted: Vector2i = blocked[0]
	m.reclaim._debris.erase(lifted)
	m._on_reclaim_changed()
	_check("②g 업화석 하나(%s)를 치우면 그 칸이 다시 통행 가능이다 — 원장 %s · 술어 %s"
			% [str(lifted), str(m._prop_blocked_tiles.has(lifted)), str(m._player_blocked_at(lifted))],
		not m._prop_blocked_tiles.has(lifted) and not m._player_blocked_at(lifted))
	m.notice_feed._items.clear()
	m._target = free_tile
	m._target_valid = m._is_farmable(free_tile)
	m._use_tool()
	_check("②h 그 상태에서는 %s에 그대로 심긴다 — 가드가 과잉이 아니다" % str(free_tile),
		m.farm.is_planted(free_tile))
	m.farm.load_save(farm_snap)
	m.inventory.slots[m.inventory.selected_index] = prev_slot
	m.reclaim._debris[lifted] = DebrisCatalog.EMBER
	m._on_reclaim_changed()
	# ㉤ 캐노피는 여전히 통과 가능하다 — 머리말이 경계한 과잉 거절이 안 생겼다는 증거.
	var canopy := Vector2i(-1, -1)
	var foot := Vector2i(-1, -1)
	for entry in m._home_prop_entries():
		if not (entry[0] in m.FOOT_BAR_PROPS):
			continue
		var th: int = maxi(int(round(entry[0].get_size().y / float(m.TILE))), 1)
		if th < 2:
			continue
		for a: Vector2i in entry[1]:
			var f := a + Vector2i(0, th - 1)
			if m._prop_blocked_tiles.has(f) and not m._prop_blocked_tiles.has(a):
				canopy = a
				foot = f
				break
		if canopy.x >= 0:
			break
	_check("②i 발치 바 프롭은 **밑행만** 막는다 — 발치 %s는 원장에 들고 캐노피 %s는 안 든다(풋프린트 통째 거절 0)"
			% [str(foot), str(canopy)], canopy.x >= 0)

# ── ③ #2 배치 스포너가 뽑을 때마다 다시 판정한다 ────────────────────────────
func _check_batch_cumulative(m: Node, stage: Dictionary) -> void:
	print("③ #2 절기 재스폰 배치 ↔ 누적 매몰")
	if not stage.has("blocked"):
		_check("③ 무대 없음 — 건너뜀", false)
		return
	var here: Vector2i = stage["here"]
	var blocked: Array = stage["blocked"]
	# 업화석 하나를 치워 **퇴로를 정확히 둘로** 만든다(A·B가 서로를 못 보던 그 조건).
	var a_tile: Vector2i = blocked[0]
	m.reclaim._debris.erase(a_tile)
	m._on_reclaim_changed()
	var b_tile: Vector2i = stage["free"]
	var open_n: Array = []
	for d in DIRS:
		if not m._player_blocked_at(here + d):
			open_n.append(str(here + d))
	_check("③a 무대: %s에 선 사람의 퇴로가 정확히 둘이다 — %s" % [str(here), " ".join(open_n)],
		open_n.size() == 2)
	_check("③b 후보 필터는 **둘 다 통과시킨다**(각자 상대가 남는다고 본다) — %s=%s · %s=%s"
			% [str(a_tile), str(m._would_entrap_player(a_tile)),
				str(b_tile), str(m._would_entrap_player(b_tile))],
		not m._would_entrap_player(a_tile) and not m._would_entrap_player(b_tile))
	_check("③c 그런데 pending을 실은 같은 술어는 두 번째를 막는다 — `_would_entrap_player(%s, {%s})` %s"
			% [str(b_tile), str(a_tile), str(m._would_entrap_player(b_tile, {a_tile: true}))],
		m._would_entrap_player(b_tile, {a_tile: true}))
	# 라이브 배치: 진짜 Reclaim.season_respawn을 두 칸 풀로 여러 날 돌린다.
	var pool: Array = [a_tile, b_tile]
	var both_unguarded := 0
	var both_guarded := 0
	var single_guarded := 0
	for d in range(1, 240):
		var r0 := Reclaim.new()
		var o0: Dictionary = r0.season_respawn(pool.duplicate(), d, false, Callable())
		if o0["ember"].size() + o0["stump"].size() == 2:
			both_unguarded += 1
		r0.free()
		var r1 := Reclaim.new()
		var pending: Dictionary = {}
		var guard := func(t: Vector2i) -> bool:
			if m._would_entrap_player(t, pending):
				return false
			pending[t] = true
			return true
		var o1: Dictionary = r1.season_respawn(pool.duplicate(), d, false, guard)
		var solids: int = o1["ember"].size() + o1["stump"].size()
		if solids == 2:
			both_guarded += 1
		elif solids == 1:
			single_guarded += 1
		r1.free()
	_check("③d 무대가 그 갈래를 태운다 — 무가드로 돌리면 239일 중 %d일이 A·B를 **함께** SOLID로 세운다"
			% both_unguarded, both_unguarded > 0)
	_check("③e 가드를 물리면 그런 날이 0이다(실측 %d일) — 같은 아침에 사방이 막히지 않는다" % both_guarded,
		both_guarded == 0)
	_check("③f 과잉이 아니다 — 한쪽만 SOLID인 날은 그대로 남는다(실측 %d일 · 거절된 굴림은 잡초로 내린다)"
			% single_guarded, single_guarded > 0)
	_check("③g 배선: `_run_season_respawn`이 그 Callable을 실제로 넘긴다(니들은 함수 안에서)",
		_line_in_func(_src, "func _run_season_respawn", "solid_ok)") >= 0 \
			and _line_in_func(_src, "func _run_season_respawn", "pending[t] = true") >= 0)
	m.reclaim._debris[a_tile] = DebrisCatalog.EMBER
	m._on_reclaim_changed()

# ── ⑨ #8(DUP of #1) 같은 봉합이 재점령 후보 창구도 닫는다 ────────────────────
func _check_encroach_dup(m: Node, stage: Dictionary) -> void:
	print("⑨ #8 DUP(#1) — 같은 술어를 재점령 후보 창구에서 잰다")
	if not stage.has("blocked"):
		_check("⑨ 무대 없음 — 건너뜀", false)
		return
	var free_tile: Vector2i = stage["free"]
	var cands: Dictionary = {}
	for t in m._encroach_candidates():
		cands[t] = true
	_check("⑨a 무대: 사람이 %s에 서 있고 세 이웃이 업화석이다(그리드는 GROUND · 물리만 막는다)"
			% str(stage["here"]),
		m._player_tile() == stage["here"] and m._prop_blocked_tiles.has(stage["blocked"][0]))
	_check("⑨b 마지막 퇴로 %s가 재점령 후보에서 빠졌다 — #1의 한 봉합이 파종·재스폰 두 입구를 함께 닫는다"
			% str(free_tile), not cands.has(free_tile))

# ── ④ #3 거울 예보가 어긋날 수 있는 갈래를 밝힌다 ───────────────────────────
func _check_mirror_forecast_caveat(m: Node) -> void:
	print("④ #3 거울 예보 ↔ 카페 진척")
	var d0: int = m.clock.day
	var rev0: int = m._cafe_revenue_total
	m._cafe_revenue_total = 0
	# 무대를 세 겹으로 좁힌다 — 안 좁히면 ④c·④d가 공허하게 초록이 된다:
	#   ㉠ 지금 잠겨 있고 ㉡ **매출만으로** 열리는 슬롯이며(단계 게이트 슬롯은 매출을 올려도 안 열린다)
	#   ㉢ 잠긴 상태의 롤이 비-평온이라 뒤집힘이 화면에 실제로 드러난다.
	var cstage: int = m._cafe_stage()
	var target := -1
	for d in range(1, 900):
		var slot: int = Festival.theme_slot_for_day(d + 1)
		if slot == Festival.NONE or Festival.is_unlocked(slot, cstage, 0):
			continue
		if not Festival.is_unlocked(slot, cstage, 999999):
			continue
		if Weather.weather_for_day(d + 1, false) == Weather.CALM:
			continue
		target = d
		break
	_check("④a 무대: %d일 밤의 다음 날이 **아직 안 열린 매출 문턱 슬롯**(%s)이고, 잠긴 상태의 롤은 비-평온(%s)이다"
			% [target, Festival.name_of(Festival.theme_slot_for_day(target + 1)) if target > 0 else "-",
				Weather.name_of(Weather.weather_for_day(target + 1, false)) if target > 0 else "-"],
		target > 0)
	if target < 0:
		m._cafe_revenue_total = rev0
		return
	m.clock.day = target
	m._open_mirror()          # 표시 단언은 그리기 경로를 태운다(라벨 갱신 + 판 레이아웃)
	var text: String = m.mirror_text.text
	var theme_name: String = Festival.name_of(Festival.theme_slot_for_day(target + 1))
	_check("④b 거울 본문에 조건 단서가 뜬다 — 테마명(%s) 포함 %s · 「문턱」 포함 %s"
			% [theme_name, str(text.contains(theme_name)), str(text.contains("문턱"))],
		text.contains(theme_name) and text.contains("문턱"))
	# 어긋남이 실제로 성립한다 — 문턱을 넘기면 같은 날의 예보 답이 뒤집힌다.
	var w_locked: int = m._forecast_on(target)
	m._cafe_revenue_total = 999999
	var w_open: int = m._forecast_on(target)
	m._open_mirror()
	var text2: String = m.mirror_text.text
	_check("④c 근거: 같은 날 매출만 올려도 예보가 「%s」 → 「%s」로 뒤집힌다 — `_forecast_on`은 순수하지 않다"
			% [Weather.name_of(w_locked), Weather.name_of(w_open)],
		w_locked != Weather.CALM and w_open == Weather.CALM)
	_check("④d 열린 뒤에는 단서가 사라진다 — 어긋날 갈래가 없으면 말하지 않는다(방향은 잠김→열림 하나뿐)",
		not text2.contains("문턱"))
	m._cafe_revenue_total = rev0
	m.clock.day = d0
	m.mirror_panel.visible = false

# ── ⑤ #4 성장촉진 비료는 지나간 날을 못 깎는다 ──────────────────────────────
func _check_speed_fert_no_jump() -> void:
	print("⑤ #4 수확 직전 성장촉진 도포")
	var f := FarmField.new()
	var t := Vector2i(1, 1)
	var crop: String = CropCatalog.YEONGHON_HOBAK
	var base: int = CropCatalog.growth_days(crop)
	f.hoe(t)
	f.plant(t, crop)
	for i in range(base - 3):
		f.water(t)
		f.advance_day()
	_check("⑤a 무대: %s(base %d) 무비료로 %d일 키웠다 — grown %d · 임계 %d · 미성숙 %s"
			% [CropCatalog.name_of(crop), base, base - 3, f.grown_days_of(t),
				f.effective_growth_days(t), str(not f.is_mature(t))],
		f.grown_days_of(t) == base - 3 and f.effective_growth_days(t) == base and not f.is_mature(t))
	var ok: bool = f.fertilize(t, ItemCatalog.FERT_SPEED)
	_check("⑤b 성장촉진 비료가 그 칸에 실제로 깔렸다(%s) — 심긴 칸 도포는 계속 허용된다" % str(ok),
		ok and f.fertilizer_of(t) == ItemCatalog.FERT_SPEED)
	_check("⑤c 임계는 **잔여 3일에만** 곱해진다 — %d(= grown %d + ceil(3×0.75)) · base 곱이던 종전 %d가 아니다"
			% [f.effective_growth_days(t), f.grown_days_of(t), ceili(base * 0.75)],
		f.effective_growth_days(t) == f.grown_days_of(t) + ceili(3 * 0.75))
	_check("⑤d 그래서 **날이 안 바뀌었는데 성숙하지 않는다** — is_mature %s · grown_days %d(불변)"
			% [str(f.is_mature(t)), f.grown_days_of(t)],
		not f.is_mature(t) and f.grown_days_of(t) == base - 3)
	# 이득이 사라진 것은 아니다 — 심을 때 깔면 종전 그대로 −25%다.
	var f2 := FarmField.new()
	var u := Vector2i(2, 2)
	f2.hoe(u)
	f2.fertilize(u, ItemCatalog.FERT_SPEED)
	f2.plant(u, crop)
	_check("⑤e 심을 때 깔면 종전 그대로다 — 임계 %d = ceil(%d×0.75) (비료의 값어치는 보존)"
			% [f2.effective_growth_days(u), base],
		f2.effective_growth_days(u) == ceili(base * 0.75))
	f.free()
	f2.free()

# ── ⑥ #5 비료를 갈아 뿌려도 다 자란 작물이 되돌아가지 않는다 ────────────────
func _check_quality_overwrite_no_regress() -> void:
	print("⑥ #5 성장촉진 → 품질 비료 덮어쓰기")
	var f := FarmField.new()
	var t := Vector2i(3, 3)
	var crop: String = CropCatalog.HWANGCHEON_PODO
	var base: int = CropCatalog.growth_days(crop)
	f.hoe(t)
	f.fertilize(t, ItemCatalog.FERT_HYPER)
	f.plant(t, crop)
	var need0: int = f.effective_growth_days(t)
	for i in range(need0):
		f.water(t)
		f.advance_day()
	_check("⑥a 무대: %s(base %d)에 하이퍼 비료 → 임계 %d · %d일 키워 성숙 %s"
			% [CropCatalog.name_of(crop), base, need0, need0, str(f.is_mature(t))],
		need0 == ceili(base * 0.67) and f.is_mature(t))
	var ok: bool = f.fertilize(t, ItemCatalog.FERT_DELUXE)
	_check("⑥b 품질 비료로 덮어썼다(%s) — 단일 필드 XOR 문법은 그대로다(비료 %s)"
			% [str(ok), f.fertilizer_of(t)],
		ok and f.fertilizer_of(t) == ItemCatalog.FERT_DELUXE)
	_check("⑥c 임계가 안 되돌아간다 — %d(불변) · base %d로 튀지 않는다 · 여전히 성숙 %s"
			% [f.effective_growth_days(t), base, str(f.is_mature(t))],
		f.effective_growth_days(t) == need0 and f.is_mature(t))
	var got: String = f.harvest(t)
	_check("⑥d 그래서 그 자리에서 그대로 거둬진다 — harvest 「%s」(빈 문자열이 아니다)" % got,
		got == crop)
	f.free()

# ── ⑦ #6 REGROW 쿨다운이 명목값 그대로 선다 ─────────────────────────────────
func _check_regrow_cooldown_nominal() -> void:
	print("⑦ #6 성장촉진 ↔ 재결실 쿨다운")
	var f := FarmField.new()
	var t := Vector2i(4, 4)
	var crop: String = CropCatalog.BULSAGWA
	var base: int = CropCatalog.growth_days(crop)
	var cd: int = CropCatalog.regrow_cooldown(crop)
	f.hoe(t)
	f.fertilize(t, ItemCatalog.FERT_SPEED)
	f.plant(t, crop)
	var need: int = f.effective_growth_days(t)
	for i in range(need):
		f.water(t)
		f.advance_day()
	_check("⑦a 무대: %s(base %d·cd %d)에 성장촉진 → 임계 %d · 성숙 %s · 성장 모드 %s"
			% [CropCatalog.name_of(crop), base, cd, need, str(f.is_mature(t)),
				CropCatalog.growth_mode(crop)],
		need == ceili(base * 0.75) and f.is_mature(t) and CropCatalog.growth_mode(crop) == "REGROW")
	var got: String = f.harvest(t)
	_check("⑦b 수확 후 되감기가 **그 칸의 임계**를 기준으로 돈다 — grown %d(= 임계 %d − cd %d) · 나무는 그대로(%s)"
			% [f.grown_days_of(t), need, cd, str(f.is_planted(t))],
		got == crop and f.is_planted(t) and f.grown_days_of(t) == need - cd)
	for i in range(cd - 1):
		f.water(t)
		f.advance_day()
	_check("⑦c cd−1일(%d)에는 아직 미성숙이다 — grown %d < 임계 %d(종전엔 이 시점에 이미 열렸다)"
			% [cd - 1, f.grown_days_of(t), need], not f.is_mature(t))
	f.water(t)
	f.advance_day()
	_check("⑦d 정확히 cd일(%d)에 다시 성숙한다 — 명목 쿨다운이 비료와 무관하게 선다" % cd, f.is_mature(t))
	f.free()

# ── ⑧ #7 F9 인플레이스 로드가 누적 원장 셋을 되감는다 ───────────────────────
func _check_ledger_rewind(m: Node) -> void:
	print("⑧ #7 Books·경지·우편함 F9 되감기")
	_check("⑧a 무대: 셋이 부팅 1회 생성 노드다(세션 내 로드가 인스턴스를 안 갈아끼운다)",
		m.books != null and m.mastery != null and m.mailbox != null)
	if m.books == null or m.mastery == null or m.mailbox == null:
		return
	# ① 지금 상태를 저장한 뒤 **그 키 셋을 지운다** = 그 기능 도입 이전 세이브의 재현.
	var ok_save: bool = m._save_game()
	var raw: Dictionary = m.saver.load_game(m._active_slot)
	_check("⑧b 무대: 세이브가 서고(%s) 세 조각이 그 안에 있다" % str(ok_save),
		ok_save and raw.has("books") and raw.has("mastery") and raw.has("mailbox"))
	raw.erase("books")
	raw.erase("mastery")
	raw.erase("mailbox")
	m.saver.save_game(raw, m._active_slot)
	# ② 직전 세션 값을 더럽힌다 — 플레이로만 쌓이는 세 누적 원장.
	var book_id: String = m.books.BOOKS.keys()[0]
	m.books.acquire(book_id, m.clock.day)
	var art_id: String = m.mastery.ARTIFACTS.keys()[0]
	m.mastery.load_save({"claimed": [art_id]})
	var letter_id: String = m.mailbox.LETTERS.keys()[0]
	m.mailbox.load_save({"outbox": [letter_id], "inbox": [], "read": {}})
	_check("⑧b' 무대: 직전 세션 값이 섰다 — 책 「%s」 주움 %s · 유물 「%s」 수령 %s · 편지 「%s」 발송이력 %s"
			% [book_id, str(m.books.has_acquired(book_id)), art_id, str(m.mastery.has_claimed(art_id)),
				letter_id, str(m.mailbox.ever_sent(letter_id))],
		m.books.has_acquired(book_id) and m.mastery.has_claimed(art_id) \
			and m.mailbox.ever_sent(letter_id))
	# ③ 그 구세이브를 로드한다(F9).
	var ok_load: bool = m._load_game()
	await process_frame
	_check("⑧b'' 로드가 섰다(%s)" % str(ok_load), ok_load)
	_check("⑧c Books 원장이 되감겼다 — 「%s」 주움 %s · 누적 %d권 (네 원천과 보부상 희귀 슬롯에서 영구 제외되던 자리)"
			% [book_id, str(m.books.has_acquired(book_id)), m.books.acquired_count()],
		not m.books.has_acquired(book_id))
	_check("⑧d 경지 수령 이력이 되감겼다 — 「%s」 수령 %s (유물 재수령 영구 차단 해소)"
			% [art_id, str(m.mastery.has_claimed(art_id))], not m.mastery.has_claimed(art_id))
	_check("⑧e 우편함 원장이 되감겼다 — 「%s」 발송이력 %s (`Mailbox.send`의 `ever_sent` 거절 해소)"
			% [letter_id, str(m.mailbox.ever_sent(letter_id))], not m.mailbox.ever_sent(letter_id))
	# 판별식이 남는다: 셋은 **부팅으로 시드되지 않는다**(플레이가 채운다) → 로드는 무조건 되감는다.
	var guarded := _line_in(_src, "if data.has(\"books\")") >= 0 \
		or _line_in(_src, "if data.has(\"mastery\")") >= 0 \
		or _line_in(_src, "if data.has(\"mailbox\")") >= 0
	_check("⑧f `has` 가드가 셋 다 걷혔다(잔존 %s) — R3·R6·R13·R18이 형제들에 쓴 그 처방의 마지막 전파"
			% str(guarded), not guarded)
	m.saver.delete_save(m._active_slot)
