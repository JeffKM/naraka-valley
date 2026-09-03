extends SceneTree
# ★[폴리시 8회차] 버그 헌트 확정분 회귀 — 배치 A(#1~#11: R7 diff 리뷰 · 낚시/채광 사슬 · 컷신 러너)
# + 배치 B(#12~#23: 컷신 무대 · 날씨 행렬 · 행사 무대 · 도감/기증 · 편지 채널).
#
# polish_r7_test가 "R6이 세운 가드가 옛 세이브를 어떻게 버리는가"를 쟀다면, 여기는 **R7이 세운
# 좌표 해석·창 라우팅이 무엇을 새로 가렸는가 · 한 칸에 둘이 서면 누가 먼저 잡는가 · 화면은 언제
# 다시 그려지는가**를 잰다.
#
# 무엇을 보증하나(발견 번호 = 8회차 헌트 배치 A):
#   ① #1  방목 슬롯 라운드로빈이 매 호출 0에서 다시 돌아, 두 번째 방출이 첫 번째와 같은 칸을
#         그대로 다시 집었다. R7의 `animal_key_at`은 겹친 두 마리 중 **첫 매치 하나만** 돌려주므로
#         나머지 한 마리는 그날 급여·쓰다듬·수집이 전부 막히고(실내 앵커도 has_animal_at이 false)
#         산물은 다음 advance_day에 덮여 사라졌다.
#   ② #2  절기 물음은 **거는 순간** 원장에 찍히는데, 같은 대화의 고백 [F]가 `replace_lines`로
#         대사를 갈면 선택지 예약이 함께 버려진다 — 화면에 뜨지도 못한 물음이 그 주를 통째로 닫았다
#         (R7 #8이 되살린 바로 그 채널이 새 경로로 한 주씩 소실).
#   ③ #3  **REFUTED** — "방목 칸에 경작하면 짐승이 작물을 가린다"는 시나리오는 좌표상 성립하지 않는다.
#         PASTURE_SCAN_RECT는 밭도 debris도 재점령 후보도 아니라 `_is_farmable`가 한 칸도 통과시키지
#         않는다. 그 사실을 술어로 못 박아 둔다(나중에 방목 평면에 개간 대상이 생기면 여기서 걸린다).
#   ④ #4  출하함·곳간 상단 휠 분기가 품목 수를 안 봐, 넘길 것이 없어도 패널 상단 절반의 휠을
#         통째로 삼켰다(그 자리에서 백팩 16칸이 안 굴러갔다).
#   ⑤ #5  게잡이통 배치만 `_installation_at` 가드가 없어 업화로·결정기 위에 겹쳐 놓였고, 그 칸의
#         [F]는 사다리에서 통이 먼저 잡아 화덕이 영영 안 열렸다(가드가 단방향이었다).
#   ⑥ #6  같은 칸을 두고 **[F] 사다리와 프롬프트 사슬의 순서가 반대**라, "[F] 사금 일기"를 보고
#         눌렀는데 미끼가 타거나 통이 회수됐다(팬닝 존·반딧넋 자리는 둘 다 통을 놓을 수 있는 물가다).
#   ⑦ #7  캐스팅 LMB를 놓지 않고 쥐고 있으면 입질 첫 프레임에 자동 후킹돼, BITE_WINDOW의 반응
#         판정도 missed_bite 경로도 그 플레이 패턴에서 한 번도 실행되지 않았다.
#   ⑧ #8  처치 시드로 쓰는 "스폰 인덱스"가 실은 `_mobs` **배열 위치**라, 틱 끝의 사체 청소가
#         배열을 압축하면 두 번째로 잡는 놈이 다시 0번이 됐다 — 사다리 15%가 층 단위
#         all-or-nothing이 되고 같은 종의 드랍이 글자 그대로 복제됐다.
#   ⑨ #9  보상 상자의 유니크 중복 판정이 백팩만 봐서, 상자에 넣어 둔 명동검이 있으면 검이 두 자루가
#         되고 750냥 골드 대체가 통째로 불발됐다.
#   ⑩ #10 갱도 상자 골드·팬닝 사금이 `_total_income`에 안 잡혀, 지갑은 늘었는데 정보패널의 누적
#         총수입은 그대로였다(다른 골드 수입은 예외 없이 짝을 이룬다 — 환불만 의도적 제외).
#   ⑪ #11 `_apply_cutscene_frame`이 `queue_redraw()`를 안 불러, S등급 일러스트(B6·B7)가 알파 1.0에
#         올라도 화면에 한 번도 안 그려졌다(컷신 중 _process는 그 자리에서 프레임을 끊는다).
#
# 배치 B(#12~#23) — **"화면이 말하는 것과 원장이 아는 것이 언제 갈리는가"**를 잰다:
#   ⑫ #12 컷신이 배우를 세울 때 얼어붙은 `walk_offset`을 안 지워, 논리 칸은 무대 위인데 그림은
#         최대 1,900px 밖에 굳어 있었다(반쯤 밝아진 광장이 텅 빔 — "이동은 암전 뒤에서만" 위반).
#   ⑬ #13 동행 혼 형상화를 암전 *전에* 세워, 환한 안방에서 0.7초 팝인한 뒤에야 암전이 내려왔다.
#   ⑭ #14 도깨비메기의 성야절 태그가 **구조적으로 도달 불가**였다(그 절기 혼우 확률이 0) —
#         실효 창이 연 2~3일로 좁아져 도감 완주가 한 종에 병목되고 체급 대비 희귀도가 역전됐다.
#   ⑮ #15 혼우 자동 급수가 `advance_day` **앞**에 있어 비가 "어제 몫"을 대신하고 그날 밭은 종일
#         말라 있었다 — HUD·점괘가 "밭이 스스로 젖는다"고 말하는데 따르면 성장 하루를 잃었다.
#   ⑯ #16 행사 예고가 28일만 내다봐, 최대 간격 36일(피안 12일 → 유화 20일) 구간인 매년 피안
#         13~19일 7일 동안 ◇ 줄이 통째로 사라졌다(달력도 다음 절기를 안 그린다 = 표면 0).
#   ⑰ #17 테마 데이가 낮에 해금되면 카페 장식·프리미엄만 켜지고 **4인 의상만** 그날 내내 꺼져
#         있었다(의상 주입 지점만 아침 세 자리에 묶여 있었다).
#   ⑱ #18 기증이 옥자 deed 트랙을 안 다시 파, 원장은 "다 갚음"인데 ♡는 stale로 남아 「명부 혼례
#         부적」 게이트가 이유 없이 잠겨 보였다(관계 탭 한 행 안에서 두 값이 어긋난다).
#   ⑲ #19 생선가게 즉시 환전이 도감에 안 올라, 그 창구만 쓰면 전 어종을 낚아 팔아도 완주 불가였다
#         (도감이 전제한 "판매 창구 단일"이 S3-T5부터 이미 거짓이었다).
#   ⑳ #20 "중복 발굴분은 판매 가능"이라 문서화된 유품에 매입 창구가 코드에 한 곳도 없었다.
#   ㉑ #21 우편함 [F]가 같은 칸의 업화로·결정기 [F]를 사다리에서 가려, 그 칸에 세운 설치물과 안에
#         든 광석이 **영구 유실**됐다(프롬프트도 우편함 것이라 무엇을 잃었는지도 안 보였다).
#   ㉒ #22 본문이 물건을 건네는 편지 셋(호박씨·화분·엽전)의 첨부가 비어 있어 백팩·지갑이 안 움직였다.
#   ㉓ #23 채널 개통 안내 `herald_notice`를 보내는 코드가 한 줄도 없어 영영 도착하지 않았다.

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

func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

func _dismiss_dialogue(m: Node) -> void:
	var guard := 0
	while m.dialogue.is_open() and guard < 60:
		m.dialogue.advance()
		guard += 1

# main.gd 소스에서 needle이 든 줄의 인덱스(-1 = 없음) — polish_r7_test의 그 헬퍼.
func _line_of(needle: String) -> int:
	for i in _src.size():
		if _src[i].contains(needle):
			return i
	return -1

func _in_func(fn_needle: String, needle: String) -> bool:
	var head := _line_of(fn_needle)
	if head < 0:
		return false
	for i in range(head + 1, _src.size()):
		if _src[i].begins_with("func "):
			return false
		if _src[i].contains(needle):
			return true
	return false

func _wipe_slot(slot: int) -> void:
	var p := SaveManager.slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _initialize() -> void:
	print("══ 폴리시 8회차 — A(#1~#11: R7 diff · 낚시/채광 · 컷신) + B(#12~#23: 무대 · 날씨 · 행사 · 도감 · 편지) ══")
	_src = FileAccess.open("res://main.gd", FileAccess.READ).get_as_text().split("\n")
	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)

	var m := await _spawn_main()
	_dismiss_dialogue(m)
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)

	# ── ① #1 두 번 나눠 방출해도 짐승이 한 칸에 겹치지 않는다 ─────────────────
	print("── ① #1 나눠 방출한 짐승이 같은 방목 칸을 물려받지 않는다 ──")
	# 무대: 평온한 낮 + 문 닫힌 두 건물(스타터 짐승 4마리 = 건물당 2).
	var calm_day: int = m.clock.day
	for d in range(m.clock.day, m.clock.day + 40):
		if Weather.allows_grazing(Weather.weather_for_day(d)):
			calm_day = d
			break
	m.clock.day = calm_day
	m.clock.minutes = 10 * 60          # 낮(밤 게이트 회피)
	for b in m.ANIMAL_BUILDINGS:
		m.ranch.set_door(b, false)
	for tile in m.ranch._animals.keys():
		var a: Dictionary = m.ranch._animals[tile]
		a["location"] = Ranch.LOC_INDOOR
		a.erase("pasture_tile")
	var barn: String = m.ANIMAL_BUILDINGS[0]
	var coop: String = m.ANIMAL_BUILDINGS[1]
	_check("①pre 무대: 두 건물 문이 닫혀 있고 짐승 %d마리가 전부 실내다(방출 전)"
			% m.ranch.count(),
		m.ranch.count() >= 4 and m.ranch.releasable().is_empty()
		and m.ranch.occupied_pasture_tiles().is_empty()
		and Weather.allows_grazing(Weather.weather_for_day(m.clock.day))
		and m.clock.phase() != "밤")
	m.ranch.set_door(barn, true)
	_check("①a 1차 방출 — %s 짐승이 방목지에 선다" % barn, m._release_open_buildings())
	var after_first: Dictionary = m.ranch.occupied_pasture_tiles().duplicate()
	m.ranch.set_door(coop, true)
	_check("①b 2차 방출 — 낮에 %s 문을 열면 그 짐승도 나간다" % coop, m._release_open_buildings())
	# 겹침 판정 = 방목 나간 짐승 수 ↔ 서로 다른 방목 칸 수(수만 세지 않고 구성까지 본다).
	var out_keys: Array = []
	var out_tiles: Dictionary = {}
	for tile in m.ranch._animals.keys():
		if m.ranch.is_outside(tile):
			out_keys.append(tile)
			out_tiles[m.ranch.pasture_tile_of(tile)] = true
	_check("①c 나간 짐승 %d마리가 **전부 다른 칸**에 선다(겹침 0)" % out_keys.size(),
		out_keys.size() >= 4 and out_tiles.size() == out_keys.size())
	_check("①d 2차 방출이 1차의 칸을 다시 집지 않았다(라운드로빈 인덱스 리셋의 그 자리)",
		after_first.size() >= 2 and out_tiles.size() > after_first.size())
	# 겹침이 없으면 R7의 좌표 해석이 **모든** 짐승에 닿는다 = 그날 돌봄이 한 마리도 안 죽는다.
	var resolved := 0
	for tile: Vector2i in out_keys:
		if m.ranch.animal_key_at(m.ranch.pasture_tile_of(tile)) == tile:
			resolved += 1
	_check("①e 방목 칸을 겨누면 **그 짐승 자신**이 해석된다(첫 매치에 먹히는 마리 0)",
		resolved == out_keys.size())
	_check("①f 후보 계산이 이미 나간 짐승의 칸을 뺀다(원장 파생 — main이 좌표를 따로 안 센다)",
		_in_func("func _release_open_buildings", "ranch.occupied_pasture_tiles()"))

	# ── ③ #3 REFUTED — 방목 평면은 경작 대상이 아니다 ─────────────────────────
	print("── ③ #3 방목 칸과 밭은 좌표상 겹치지 않는다(반박 근거 고정) ──")
	var farmable_in_pasture: Array = []
	for y in range(m.PASTURE_SCAN_RECT.position.y, m.PASTURE_SCAN_RECT.end.y):
		for x in range(m.PASTURE_SCAN_RECT.position.x, m.PASTURE_SCAN_RECT.end.x):
			if m._is_farmable(Vector2i(x, y)):
				farmable_in_pasture.append(Vector2i(x, y))
	_check("③a PASTURE_SCAN_RECT %s 안에 경작 가능 칸이 하나도 없다(밭도 debris도 재점령 후보도 아님)"
			% str(m.PASTURE_SCAN_RECT), farmable_in_pasture.is_empty())
	var slots_farmable := 0
	for t: Vector2i in m._free_pasture_tiles():
		if m._is_farmable(t):
			slots_farmable += 1
	_check("③b 실제 방목 슬롯 %d칸도 전부 비-경작지 — 짐승이 작물을 가릴 무대가 없다"
			% (m._free_pasture_tiles() as Array).size(), slots_farmable == 0)

	# ── ② #2 버려진 절기 물음은 원장에서도 되감긴다 ───────────────────────────
	print("── ② #2 화면에 뜨지도 못한 물음을 \"물었다\"로 세지 않는다 ──")
	# 무대: 주 첫날 + 물음 훅을 가진 주민(생일이 그날이 아닌 사람) — 전원 순회로 고른다.
	m.clock.day = m._week_first_day(m.clock.day) + GameClock.DAYS_PER_WEEK
	m._season_q_week = {}
	# 물음이 **실제로 서는** 주민을 술어 자신으로 고른다(훅 유무만 보면 손상 방어에 걸린 사람이 섞인다).
	var qr: Resident = null
	var other_rid := ""
	var q0: Dictionary = {}
	for r: Resident in m._residents:
		if r.node == null or not r.node.has_method("season_question"):
			continue
		var mate := ""
		for r2: Resident in m._residents:
			if r2.id != r.id:
				mate = r2.id
				break
		m._romance_partner = mate     # 연애 슬롯이 남에게 잡힌 상태 = 제안이 **상시**로 서는 그 상태
		m._confess_rid = r.id
		var cand: Dictionary = m._pending_season_question(r, PackedStringArray())
		if not cand.is_empty():
			qr = r
			other_rid = mate
			q0 = cand
			break
	_check("②pre 오늘이 주 첫날이고, 슬롯이 남에게 잡힌 채로도 물음이 서는 주민을 확보(%s)"
			% ("없음" if qr == null else qr.id),
		qr != null and other_rid != "" and (m.clock.day - 1) % GameClock.DAYS_PER_WEEK == 0)
	_check("②a 슬롯이 남에게 잡혀 있어도 물음은 선다(R7 #8이 되살린 채널 — 불변)", not q0.is_empty())
	m.dialogue.start(qr.display_name, PackedStringArray([String(q0["line"])]))
	m._pose_season_question(qr, q0)
	_check("②b 물음을 건 순간 원장이 이번 주로 찍히고 선택지가 화면에 떠 있다",
		int(m._season_q_week.get(qr.id, -1)) == GameClock.week_of(m.clock.day)
		and m.dialogue.has_choice() and m._season_q_posed_rid == qr.id)
	m._resolve_confession(qr.id)        # 거절 갈래 — replace_lines가 선택지 예약을 버린다
	_check("②c 고백 [F]가 대사를 갈아 물음이 사라졌다(선택지 예약 소멸 — dialogue 계약)",
		not m.dialogue.has_choice())
	_check("②d 버려진 물음은 **원장에서도 되감긴다** — 그 주가 통째로 닫히지 않는다",
		not m._season_q_week.has(qr.id) and m._season_q_posed_rid == "")
	m._confess_rid = qr.id
	_check("②e 같은 주 다음 대화에 물음이 다시 선다(잃은 것이 없다)",
		not m._pending_season_question(qr, PackedStringArray()).is_empty())
	# 반대 방향 — **고른** 물음은 되감기지 않는다(정상 소비를 되돌리면 같은 주에 두 번 묻는다).
	_dismiss_dialogue(m)
	m._season_q_week = {}
	m.dialogue.start(qr.display_name, PackedStringArray([String(q0["line"])]))
	m._pose_season_question(qr, q0)
	m.dialogue.choose(0)
	_check("②f 고른 물음은 소비로 남는다(원장 유지 · 되감기 대상 아님)",
		int(m._season_q_week.get(qr.id, -1)) == GameClock.week_of(m.clock.day)
		and m._season_q_posed_rid == "")
	m._confess_rid = qr.id
	m._resolve_confession(qr.id)
	_check("②g 그 뒤의 고백 [F]는 남의 원장을 건드리지 않는다(되감기 대상은 안 골라진 물음뿐)",
		int(m._season_q_week.get(qr.id, -1)) == GameClock.week_of(m.clock.day))
	m._romance_partner = ""
	m._confess_rid = ""
	_dismiss_dialogue(m)

	# ── ④ #4 넘길 것이 없으면 상단 밴드가 휠을 안 삼킨다 ──────────────────────
	print("── ④ #4 빈 출하함 위의 휠은 백팩으로 흐른다 ──")
	var frame: InventoryFrame = m.frame
	_check("④pre 인벤 프레임 확보 · 백팩이 스크롤 가능한 칸 수다(16칸 / %d행 창)"
			% frame.BP_VIS_ROWS,
		frame != null and frame._bp_max_first_row() > 0)
	frame.context = InventoryFrame.CTX_BIN
	frame._top_area_rect = Rect2(0, 0, 200, 100)
	frame._top_scroll = 0
	frame._bp_first_row = 0
	frame._top_rows_total = 0                 # 창에 다 들어간다 = 넘길 것이 없다
	frame._gui_input(_wheel_down(Vector2(10, 10)))
	_check("④a 넘길 것이 없으면 상단 밴드의 휠이 **백팩**을 굴린다(R7 이전 거동 복귀)",
		frame._top_scroll == 0 and frame._bp_first_row == 1)
	frame._bp_first_row = 0
	frame._top_rows_total = frame.top_rows_visible() + 3   # 창을 넘치는 재고
	frame._gui_input(_wheel_down(Vector2(10, 10)))
	_check("④b 넘칠 때는 그대로 내역을 넘긴다(백팩은 안 건드린다 — R7의 그 창구 불변)",
		frame._top_scroll == 1 and frame._bp_first_row == 0)
	frame._gui_input(_wheel_up(Vector2(10, 10)))
	_check("④c 위로도 같은 표(휠 ±1 · 클램프는 그리기 시점)", frame._top_scroll == 0)
	frame.context = InventoryFrame.CTX_NONE

	# ── ⑤⑥ #5·#6 게잡이통 — 설치 가드와 안내 순서 ────────────────────────────
	print("── ⑤ #5 설치물 위에는 통을 못 놓는다(가드 양방향) ──")
	m._region = RegionCatalog.SAMDOCHEON
	m._rebuild_region(RegionCatalog.SAMDOCHEON)
	m._indoor = ""
	var pot_t := Vector2i(-1, -1)
	for y in range(m._outdoor_h):
		for x in range(m._grid_w):
			if m._can_place_crab_pot(Vector2i(x, y)):
				pot_t = Vector2i(x, y)
				break
		if pot_t.x >= 0:
			break
	_check("⑤pre 삼도천에 통을 놓을 수 있는 물가 칸 확보 %s" % str(pot_t), pot_t.x >= 0)
	m.furnace.place(RegionCatalog.SAMDOCHEON, pot_t)
	_check("⑤a 업화로가 선 칸엔 통을 못 놓는다(화덕 [F]를 가로채는 겹침이 원천 차단)",
		not m._can_place_crab_pot(pot_t) and m._installation_at(pot_t))
	m.furnace.remove(RegionCatalog.SAMDOCHEON, pot_t)
	_check("⑤b 화덕을 걷으면 다시 놓을 수 있다(좁히기만 했다 — 정상 배치 불변)",
		m._can_place_crab_pot(pot_t))
	m.crystalarium.place(RegionCatalog.SAMDOCHEON, pot_t)
	_check("⑤c 결정기도 같다(같은 술어 하나가 전 설치물을 덮는다)",
		not m._can_place_crab_pot(pot_t))
	m.crystalarium.remove(RegionCatalog.SAMDOCHEON, pot_t)
	_check("⑤d 가드가 **양방향**이다 — 반대편(업화로·결정기)이 통을 막던 그 술어를 통도 쓴다",
		_in_func("func _can_place_crab_pot", "_installation_at(t)")
		and _in_func("func _can_place_furnace", "_installation_at(t)"))

	print("── ⑥ #6 안내 사슬의 순서가 [F] 사다리와 같다 ──")
	var f_pot := _line_of("crab_pot.has_at(_region, _target) \\")
	var f_pan := _line_of("if on_pan_spot and Input.is_action_just_pressed(\"shop_toggle\")")
	var f_ff := _line_of("if on_firefly and Input.is_action_just_pressed(\"shop_toggle\")")
	var p_pot := _line_of("interact_prompt.text = _crab_pot_prompt(_target)")
	var p_furnace := _line_of("interact_prompt.text = _furnace_prompt(_target)")
	var p_pan := _line_of("[F] 사금 일기 (혼력 %d)")
	var p_ff := _line_of("[F] 반딧넋 거두기 (%d/%d)")
	_check("⑥pre 두 사슬의 지점이 전부 소스에 있다(needle 유효성)",
		f_pot > 0 and f_pan > 0 and f_ff > 0 and p_pot > 0 and p_furnace > 0
		and p_pan > 0 and p_ff > 0)
	_check("⑥a [F] 사다리에서 통이 팬닝·반딧넋보다 먼저 잡는다(종전 그대로 — 이쪽이 기준)",
		f_pot < f_pan and f_pan < f_ff)
	_check("⑥b 안내 사슬도 같은 순서다 — 통 > 팬닝 > 반딧넋(화면이 실제 동사를 말한다)",
		p_pot < p_pan and p_pan < p_ff)
	# ★[폴리시 R17 #1] R16 #13이 기계 안내를 사슬 맨 앞으로 올리면서 이 줄 순서가 뒤집혔고, 그
	#   뒤로 이 단언은 줄곧 빨간 채였다(같은 클래스의 역전이 통·채취기·부스 세 칸에서 새로 생겼다).
	#   봉합은 순서를 되돌리는 대신 **기계 갈래에 양보 절**을 달았다(반대 축 = 실행을 미루기는 그
	#   칸의 기계를 영영 매몰시킨다 — R16 #13이 그 근거를 이미 적어 두었다). 그래서 여기서 재는 것을
	#   줄 순서(대리 지표)에서 **계약 자체**로 옮긴다: 기계 안내가 앞에 있어도 통에게 자리를 내주는가.
	var yields := p_furnace > 0 and _line_of("elif _furnace_at(_target) and not _f_taken_before_machine(_target):") > 0
	_check("⑥c 화덕·결정기 안내가 통보다 앞이면 **통에 양보한다**([F] 사다리의 그 순서 1:1)",
		p_pot < p_furnace or yields)

	# ── ⑦ #7 입질은 쥐고 있는다고 채이지 않는다 ───────────────────────────────
	print("── ⑦ #7 캐스팅 LMB를 홀드해도 자동 후킹되지 않는다 ──")
	var S := FishingSession.State
	var held := FishingSession.new(20260901, {"weight_class": FishingSession.WeightClass.SMALL})
	held.cast()
	var ht := 0.0
	while held.is_active() and ht < 30.0:
		held.tick(0.05, true)          # 캐스팅부터 한 번도 안 놓는다
		ht += 0.05
	_check("⑦a 내내 쥐고만 있으면 입질 창이 흐르고 놓친다(BITE_WINDOW·missed_bite 도달)",
		held.state == S.ESCAPED and held.missed_bite and not held.line_broke)
	var struck := FishingSession.new(20260901, {"weight_class": FishingSession.WeightClass.SMALL})
	struck.cast()
	var st := 0.0
	var released := false
	while struck.is_active() and st < 30.0:
		# 캐스팅부터 쥐고 있다가 입질에 **한 프레임 놓고 다시 누른다** = 챈다(그 뒤 격투는 홀드).
		var reel := true
		if struck.state == S.BITE and not released:
			reel = false
			released = true
		struck.tick(0.05, reel)
		st += 0.05
	_check("⑦b 놓았다 다시 누르면 그대로 후킹된다(정상 조작 불변 — 포획까지 간다)",
		struck.state == S.LANDED and not struck.missed_bite)
	var idle_then := FishingSession.new(20260901, {"weight_class": FishingSession.WeightClass.SMALL})
	idle_then.cast()
	var it := 0.0
	while idle_then.is_active() and it < 30.0:
		idle_then.tick(0.05, idle_then.state == S.BITE or idle_then.state == S.FIGHT)
		it += 0.05
	_check("⑦c 손을 뗀 채 기다리다 입질에 누르는 기존 조작열도 그대로 잡힌다(회귀 불변)",
		idle_then.state == S.LANDED)

	# ── ⑧ #8 처치 시드는 스폰 인덱스다(사체 청소에 안 밀린다) ─────────────────
	print("── ⑧ #8 사체 청소가 처치 시드를 밀지 않는다 ──")
	m.mine_floors._chests = {}
	m._narak_key_found = false
	m.mine_floors._depth = 60
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	m._descend_mine(21)
	await _settle(m)
	var recs0: Array = m._mobs_in_region()
	var idx0: Array = []
	for r3: Dictionary in recs0:
		idx0.append(int(r3["index"]))
	idx0.sort()
	var idx_seq: Array = []
	for i in recs0.size():
		idx_seq.append(i)
	_check("⑧pre 21층 잡귀 %d마리 · 스폰 인덱스가 0..n-1로 온전하다" % recs0.size(),
		recs0.size() >= 2 and idx0 == idx_seq)
	var victim: Dictionary = recs0[0]
	var victim_idx := int(victim["index"])
	var victim_ref: Mob = victim["ref"]
	while victim_ref.is_alive():
		m._combat_swings += 1
		m._strike_mob(WeaponCatalog.SWORD_EOPHWADO, victim)
	m._tick_mobs(0.016)                 # 여기서 배열이 압축된다(그 결함의 방아쇠)
	var idx1: Array = []
	for r4: Dictionary in m._mobs_in_region():
		idx1.append(int(r4["index"]))
	idx1.sort()
	var expect_idx: Array = idx0.duplicate()
	expect_idx.erase(victim_idx)
	_check("⑧a 청소 뒤 남은 인덱스 = 처음 목록에서 죽은 %d번만 빠진 것(위치 재사용 0)" % victim_idx,
		idx1 == expect_idx and not idx1.has(victim_idx))
	_check("⑧b 인덱스는 개체가 든다(main이 배열 위치를 시드로 넘기지 않는다)",
		_in_func("func _mobs_in_region", "\"index\": m.spawn_index"))
	var spawn_idx_ok := true
	for r5: Dictionary in m._mobs_in_region():
		if int(r5["index"]) != (r5["ref"] as Mob).spawn_index:
			spawn_idx_ok = false
	_check("⑧c 레코드의 index ↔ 개체의 spawn_index가 항상 같다(단일 출처)", spawn_idx_ok)

	# ── ⑨⑩ #9·#10 보상 상자 — 유니크 판정과 누적 총수입 ──────────────────────
	print("── ⑨ #9 상자에 넣어 둔 유니크도 \"가진 것\"이다 ──")
	m.mine_floors._chests = {}
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	m._descend_mine(10)
	await _settle(m)
	m.player.global_position = m._tile_center_px(Vector2i(m._mine_layout["chest"]))
	await process_frame
	var sword: String = WeaponCatalog.SWORD_MYEONGDONG
	m.inventory.remove_item(sword, m.inventory.count_of(sword))
	m.chest.store(sword, 1)             # 백팩엔 없고 **집 상자에만** 있는 상태
	_check("⑨pre 무대: 명동검이 집 상자에만 있다(백팩 0 · _stored_anywhere 참)",
		m.inventory.count_of(sword) == 0 and m.chest.count_of(sword) == 1
		and m._stored_anywhere(sword))
	var gold_b: int = m.wallet.gold
	var income_b: int = m._total_income
	m._open_mine_chest()
	_check("⑨a 두 자루가 되지 않는다(백팩에 안 실린다)", m.inventory.count_of(sword) == 0)
	_check("⑨b 대신 길드 판매가 %d냥이 골드로 대체된다(1회성 보상이 빈손이 되지 않는다)"
			% WeaponCatalog.price_of(sword),
		m.wallet.gold == gold_b + WeaponCatalog.price_of(sword))
	print("── ⑩ #10 상자 골드·사금이 누적 총수입에 잡힌다 ──")
	_check("⑩a 상자 골드가 지갑과 **같은 만큼** 누적 총수입을 올린다",
		m._total_income - income_b == m.wallet.gold - gold_b
		and m._total_income > income_b)
	m._ascend_mine_to_surface()
	await _settle(m)
	m._region = RegionCatalog.SAMDOCHEON
	m._rebuild_region(RegionCatalog.SAMDOCHEON)
	m._indoor = ""
	m.energy.current = SoulEnergy.MAX
	var all_spots: Array = []
	for t: Vector2i in PanningSpots.candidates(RegionCatalog.SAMDOCHEON):
		all_spots.append([t.x, t.y])
	m.panning.load_save({"spots": {RegionCatalog.SAMDOCHEON: all_spots}})
	# 금화가 나오는 자리를 고른다(산출이 아이템뿐인 자리는 이 결함의 무대가 아니다).
	var pan_t := Vector2i(-1, -1)
	var pan_row: Dictionary = {}
	for t2: Vector2i in PanningSpots.candidates(RegionCatalog.SAMDOCHEON):
		var row: Dictionary = m.panning.peek(m.clock.day, RegionCatalog.SAMDOCHEON, t2)
		if int(row.get("gold", 0)) > 0:
			pan_t = t2
			pan_row = row
			break
	_check("⑩pre 금화 산출 스폿 확보 %s" % str(pan_t), pan_t.x >= 0)
	var gold_c: int = m.wallet.gold
	var income_c: int = m._total_income
	m._pan_spot(pan_t)
	_check("⑩b 사금 %d냥도 같은 짝을 이룬다(골드만 늘고 총수입은 그대로이던 자리)"
			% int(pan_row.get("gold", 0)),
		m.wallet.gold - gold_c == int(pan_row.get("gold", 0))
		and m._total_income - income_c == m.wallet.gold - gold_c)

	# ── ⑪ #11 컷신 프레임은 화면을 다시 그린다 ────────────────────────────────
	print("── ⑪ #11 컷신 일러스트가 실제로 그려질 기회를 받는다 ──")
	_check("⑪a `_apply_cutscene_frame`이 재그리기를 요청한다(_illust_*를 읽는 곳은 _draw뿐)",
		_in_func("func _apply_cutscene_frame", "queue_redraw()"))
	_check("⑪b 프레임 적용은 진행(_tick_cutscene)과 시작(_begin_cutscene) 양쪽이 부른다 —"
			+ " 첫 프레임도 그려진다",
		_in_func("func _tick_cutscene", "_apply_cutscene_frame()")
		and _in_func("func _begin_cutscene", "_apply_cutscene_frame()"))
	# 러너가 실제로 그 값을 세우는지까지 본다(단언이 소스 스캔에만 매달리지 않게).
	var runner := CutsceneRunner.new([{"verb": "illust", "id": "b7_release"}])
	var clock_prev: bool = m.clock.running
	m.cutscene = runner
	m._cutscene_clock_prev = clock_prev
	runner.start()
	runner.advance(0.0)                 # 즉시 스텝 = 이 프레임에 알파가 끝값까지 간다
	m._apply_cutscene_frame()
	_check("⑪c illust 스텝이 열리면 main의 그림 상태가 실제로 선다(id·알파 > 0)",
		m._illust_id == "b7_release" and m._illust_a > 0.0)
	m.cutscene = null
	m._illust_id = ""
	m._illust_a = 0.0
	m.clock.running = clock_prev

	# ── ⑫ #12 컷신 배우는 얼어붙은 걷기 오프셋을 끌고 오지 않는다 ─────────────
	print("── ⑫ #12 컷신이 배우를 세울 때 stale walk_offset을 지운다 ──")
	var ken: Resident = m._resident("ken")
	_check("⑫pre 켄 레코드와 노드가 있고 걷기 오프셋 훅을 든다",
		ken != null and ken.node != null and ken.node.has_method("set_walk_offset"))
	if ken != null and ken.node != null:
		# 진행 중인 마을 걷기를 만든다 — 스포크가 길수록 오프셋이 크다(켄의 09:00 이동 재현).
		if ken.walk == null:
			ken.walk = ResidentWalk.new()
		var far := Vector2(89.0 * m.TILE, 36.0 * m.TILE)
		ken.walk.start(far, PackedVector2Array([Vector2(48.0 * m.TILE, 36.0 * m.TILE),
			Vector2(48.0 * m.TILE, 39.0 * m.TILE)]))
		ken.walk.advance(0.5)
		ken.node.set_walk_offset(ken.walk.offset())
		var stale: Vector2 = ken.node.walk_offset
		_check("⑫pre 걷기가 진행 중이고 그림 오프셋이 실제로 얹혀 있다(%dpx)" % int(stale.length()),
			ken.walk.is_walking() and stale.length() > 100.0)
		var steps: Array = [{"verb": "npc", "id": "ken", "tile": Vector2i(48, 39), "secs": 0.0}]
		var began: bool = m._begin_cutscene(steps, "", PackedStringArray())
		_check("⑫a 켄을 세우는 컷신이 실제로 시작된다(cast에 켄이 든다)",
			began and m.cutscene != null and "ken" in m.cutscene.cast_ids())
		_check("⑫b 재생 개시가 걷기를 끄고 그림 오프셋을 0으로 되돌린다"
				+ " — 배우가 화면 밖에서 연기하지 않는다",
			not ken.walk.is_walking() and ken.node.walk_offset == Vector2.ZERO)
		m._end_cutscene()
		_check("⑫c 종료가 원위치를 되돌리고 재생 상태를 비운다",
			m.cutscene == null and m._cutscene_npc_prev.is_empty())

	# ── ⑬ #13 동행 혼의 몸은 암전이 다 내려온 뒤에 선다 ──────────────────────
	print("── ⑬ #13 형상화가 밝은 방에서 팝인하지 않는다 ──")
	_check("⑬a `_fire_soul_birth`는 몸을 **예약만** 한다(직접 세우는 줄이 없다)",
		_in_func("func _fire_soul_birth", "_soul_body_pending = true"))
	_check("⑬b 소비는 `_apply_cutscene_frame`의 암전 판정이 진다",
		_in_func("func _apply_cutscene_frame", "cutscene.fade_alpha() >= 1.0"))
	var soul: Resident = m._resident(m.SOUL_CHILD_RID)
	_check("⑬pre 동행 혼 레코드·노드가 있다", soul != null and soul.node != null)
	if soul != null and soul.node != null:
		var born_prev: bool = m._soul_born
		m._soul_born = true
		soul.node.visible = false
		m._soul_body_pending = true
		# 탄생 컷신의 첫 페이드(0 → 1.0, 0.7초)를 그대로 흉내 낸다.
		var fade_runner := CutsceneRunner.new([{"verb": "fade", "to": 1.0, "secs": 0.7}])
		m.cutscene = fade_runner
		m._cutscene_clock_prev = m.clock.running
		fade_runner.start()
		fade_runner.advance(0.2)
		m._apply_cutscene_frame()
		_check("⑬c 암전이 내려오는 중(알파 %.2f)에는 몸이 아직 안 선다"
				% m.cutscene.fade_alpha(),
			m.cutscene.fade_alpha() < 1.0 and m._soul_body_pending and not soul.node.visible)
		fade_runner.advance(1.0)
		m._apply_cutscene_frame()
		_check("⑬d 알파가 1.0에 닿는 프레임에 몸이 선다(암전이 걷힐 땐 이미 거기 있다)",
			m.cutscene.fade_alpha() >= 1.0 and not m._soul_body_pending and soul.node.visible)
		m.cutscene = null
		m._soul_born = born_prev
		m._refresh_soul_child_body()
		m.clock.running = m._cutscene_clock_prev

	# ── ⑭ #14 어종의 (절기 × 날씨) 조합이 전부 도달 가능하다 ─────────────────
	print("── ⑭ #14 날씨 한정 어종의 절기 태그가 죽은 데이터가 아니다 ──")
	# 분모·절기 수는 전부 레지스트리 파생이다(FishCatalog.ids · Weather.DISTRIBUTION).
	var dead_tags: Array = []
	for fid in FishCatalog.ids():
		var wx: Array = FishCatalog.FISH[fid]["weather"]
		if wx.is_empty():
			continue                        # 날씨 무관 어종은 이 검사의 대상이 아니다
		var fs: Array = FishCatalog.FISH[fid]["seasons"]
		var seasons: Array = fs if not fs.is_empty() else range(Weather.DISTRIBUTION.size())
		for s in seasons:
			var reachable := false
			for w in wx:
				if int(Weather.DISTRIBUTION[int(s)][int(w)]) > 0:
					reachable = true
			if not reachable:
				dead_tags.append("%s@%s" % [FishCatalog.name_of(fid), GameClock.SEASON_NAMES[int(s)]])
	_check("⑭a 날씨 한정 어종의 절기 태그 중 확률 0인 조합이 없다(죽은 태그: %s)" % str(dead_tags),
		dead_tags.is_empty())
	_check("⑭b 도깨비메기는 성야절(혼우 0)이 아니라 실제로 비가 오는 절기에 산다",
		not (FishCatalog.FISH[FishCatalog.DOKKAEBI_MEGI]["seasons"] as Array).has(3)
		and FishCatalog.is_available(FishCatalog.DOKKAEBI_MEGI, FishCatalog.HABITAT_RIVER,
			0, "밤", Weather.RAIN))
	_check("⑭c 로스터 밀도는 그대로 — 성야절 강 비-전설 종이 여전히 3종 이상",
		FishCatalog.season_roster(FishCatalog.HABITAT_RIVER, 3).size() >= 3)

	# ── ⑮ #15 혼우는 그날 하루 밭을 적신다 ──────────────────────────────────
	print("── ⑮ #15 비 오는 날 밭이 실제로 젖어 있다 ──")
	m._region = RegionCatalog.HOME
	m._rebuild_region(RegionCatalog.HOME)
	var till_targets: Array = []
	for ty in range(12, 16):
		for tx in range(40, 44):
			var tt := Vector2i(tx, ty)
			if m._is_farmable(tt) and m.farm.hoe(tt):
				till_targets.append(tt)
			if till_targets.size() >= 4:
				break
		if till_targets.size() >= 4:
			break
	_check("⑮pre 경작 칸 %d개 확보" % till_targets.size(), till_targets.size() >= 2)
	var rain_day := -1
	var calm_day2 := -1
	for d in range(m.clock.day + 1, m.clock.day + 200):
		if rain_day < 0 and Weather.weather_for_day(d) == Weather.RAIN:
			rain_day = d
		if calm_day2 < 0 and Weather.weather_for_day(d) == Weather.CALM:
			calm_day2 = d
	_check("⑮pre 혼우일 %d · 평온일 %d 확보" % [rain_day, calm_day2],
		rain_day > 0 and calm_day2 > 0)
	if rain_day > 0 and calm_day2 > 0 and till_targets.size() >= 2:
		m.clock.day = calm_day2
		m._on_day_advanced(calm_day2)
		var calm_wet := 0
		for tt: Vector2i in m.farm.tilled_tiles():
			if m.farm.is_watered(tt):
				calm_wet += 1
		_check("⑮a 평온일 아침 정산 뒤 밭은 마른 상태다(대조군 — 젖은 칸 %d)" % calm_wet,
			calm_wet == 0)
		m.clock.day = rain_day
		m._on_day_advanced(rain_day)
		var tilled: Array = m.farm.tilled_tiles()
		var dry: Array = []
		for tt: Vector2i in tilled:
			if not m.farm.is_watered(tt):
				dry.append(tt)
		_check("⑮b 혼우일 아침 정산 뒤 경작 %d칸이 **전부 젖어 있다**(마른 칸: %s)"
				% [tilled.size(), str(dry)],
			tilled.size() >= 2 and dry.is_empty())
		_check("⑮c 그래서 점괘 거울의 안내가 참이 된다 — '%s'" % m._weather_hint(Weather.RAIN),
			m._weather_hint(Weather.RAIN) != "")

	# ── ⑯ #16 절기 행사 예고가 한 해의 모든 날에 선다 ────────────────────────
	print("── ⑯ #16 점괘 거울의 ◇ 행사 줄에 빈 구간이 없다 ──")
	# 왜 28일 창이 모자랐는지를 **표에서 파생해** 못 박는다(눈금 하드코딩 없음).
	var max_gap := 0
	var events_per_year: Array = []
	for s in SeasonalEvent.DAY_OF_SEASON.size():
		events_per_year.append(s * GameClock.DAYS_PER_SEASON + int(SeasonalEvent.DAY_OF_SEASON[s]))
	for i in events_per_year.size():
		var nxt: int = int(events_per_year[(i + 1) % events_per_year.size()])
		var cur: int = int(events_per_year[i])
		var gap: int = nxt - cur if nxt > cur else nxt + events_per_year.size() * GameClock.DAYS_PER_SEASON - cur
		max_gap = maxi(max_gap, gap)
	_check("⑯a 연속 두 행사의 최대 간격 %d일이 한 절기(%d일)를 넘는다 — 28일 창이 모자랐던 이유"
			% [max_gap, GameClock.DAYS_PER_SEASON],
		max_gap > GameClock.DAYS_PER_SEASON)
	var day_prev: int = m.clock.day
	var blank_days: Array = []
	for d in range(1, events_per_year.size() * GameClock.DAYS_PER_SEASON + 1):
		m.clock.day = d
		if m._event_upcoming_line() == "":
			blank_days.append(d)
	_check("⑯b 한 해 %d일 어느 날에도 예고 줄이 비지 않는다(빈 날: %s)"
			% [events_per_year.size() * GameClock.DAYS_PER_SEASON, str(blank_days)],
		blank_days.is_empty())
	m.clock.day = day_prev

	# ── ⑰ #17 하루 중 테마 데이가 해금되면 의상이 그 프레임에 켜진다 ─────────
	print("── ⑰ #17 낮에 문턱을 넘으면 4인 의상도 따라붙는다 ──")
	# 힙합 데이를 쓰는 이유: 해금 축이 **누적 매출 하나뿐**이라(UNLOCK_STAGE 0) 하트·수확을 안 건드리고
	# 문턱을 넘는 순간만 재현할 수 있다. 슬롯 날짜·문턱은 전부 Festival 표에서 파생한다.
	var hip_day: int = Festival.HIPHOP * GameClock.DAYS_PER_SEASON + Festival.DAY_OF_SEASON
	var rev_prev: int = m._cafe_revenue_total
	m.clock.day = hip_day
	m._cafe_revenue_total = 0
	m._refresh_festival()
	_check("⑰pre %d일 = 힙합 데이 슬롯인데 매출 0이라 아직 평일이다(평상복)" % hip_day,
		Festival.theme_slot_for_day(hip_day) == Festival.HIPHOP
		and m._festival_theme() == Festival.NONE
		and not m.miho.festive and not m.mel.festive
		and not m.bana.festive and not m.okja.festive)
	m._cafe_revenue_total = int(Festival.UNLOCK_REVENUE[Festival.HIPHOP])
	_check("⑰a 문턱을 넘는 순간 테마는 곧장 열린다(파생값이라 즉시)",
		m._festival_theme() == Festival.HIPHOP)
	m._sync_festive_costumes()
	_check("⑰b 같은 프레임의 동기화가 **메인 4인 전원**에게 축제 의상을 입힌다",
		m.miho.festive and m.mel.festive and m.bana.festive and m.okja.festive)
	_check("⑰c 동기화는 `_process`가 사다리 주입과 같은 자리에서 부른다",
		_in_func("func _process", "_sync_festive_costumes()"))
	m._cafe_revenue_total = rev_prev
	m.clock.day = day_prev
	m._refresh_festival()

	# ── ⑱ #18 기증이 앵커 트랙을 그 자리에서 다시 판다 ───────────────────────
	print("── ⑱ #18 기증 직후의 ♡가 원장과 어긋나지 않는다 ──")
	m._mark_spine_bit(m.SPINE_B4)
	m._mark_spine_bit(m.SPINE_B5)
	m._mark_spine_bit(m.SPINE_B6)
	m._open_okja_track()
	var okja_r: Resident = m._resident(m.OKJA_RID)
	_check("⑱pre 앵커 트랙이 열려 있다(B6 이후·배우자 없음)",
		m._okja_track_open() and okja_r != null and okja_r.affinity != null)
	if okja_r != null and okja_r.affinity != null:
		m._refresh_okja_track()
		var pts_before: int = okja_r.affinity.points
		var donated_before: int = m.museum.donated_count()
		# 아직 안 바친 기증감 하나를 손에 들고 기증대 동사를 그대로 태운다(⑳이 쓸 유품으로 고른다).
		var target_relic := ""
		for rid2 in Museum.donatable_ids():
			var sid2 := String(rid2)
			if not m.museum.is_donated(sid2) \
					and ItemCatalog.category_of(sid2) == ItemCatalog.CAT_RELIC:
				target_relic = sid2
				break
		m.inventory.add_item(target_relic, 1)
		for i in range(m.inventory.slots.size()):
			if m.inventory.id_at(i) == target_relic:
				m.inventory.select(i)
				break
		_check("⑱pre 기증감 %s를 들었다" % target_relic, m.inventory.selected_id() == target_relic)
		m._try_donate_selected()
		_check("⑱a 기증이 원장에 실제로 올랐다(%d → %d)"
				% [donated_before, m.museum.donated_count()],
			m.museum.donated_count() == donated_before + 1)
		_check("⑱b 그 프레임에 트랙 점수가 원장과 다시 맞는다(♡ %d — 취침을 안 기다린다)"
				% okja_r.affinity.hearts(),
			okja_r.affinity.points == Spine.okja_deed_points(true,
				m.museum.donated_count(), Museum.donatable_ids().size(), m._run_harvested)
			and okja_r.affinity.points > pts_before)
		_check("⑱c 관계 탭의 하트도 파생과 같은 값이다(effect 줄만 앞서가지 않는다)",
			okja_r.affinity.hearts() == okja_r.affinity.points_hearts())

	# ── ⑲ #19 생선가게 즉시 환전도 도감에 등재된다 ──────────────────────────
	print("── ⑲ #19 두 판매 창구가 같은 도감 원장으로 온다 ──")
	var fish_id := ""
	for f2 in FishCatalog.ids():
		if Codex.is_tracked(String(f2)):
			fish_id = String(f2)
			break
	_check("⑲pre 도감 추적 어종 %s 확보" % fish_id,
		fish_id != "" and not m.codex.is_shipped(fish_id))
	m.inventory.add_item(fish_id, 1)
	var sold: Dictionary = m._sell_fish_n(fish_id, 0, 1, true)
	_check("⑲a 환전이 실제로 성사됐다(%d마리 · %d냥)" % [int(sold["count"]), int(sold["gold"])],
		int(sold["count"]) == 1 and int(sold["gold"]) > 0)
	_check("⑲b 그 어획이 도감에 이름을 올린다 — 환전 탭만 쓰는 플레이어도 완주에 닿는다",
		m.codex.is_shipped(fish_id))

	# ── ⑳ #20 중복 유품에 실제 판매 창구가 있다 ────────────────────────────
	print("── ⑳ #20 '중복 발굴분은 판매 가능'이 코드에서도 참이다 ──")
	var relic_done := ""
	var relic_todo := ""
	for rid3 in Museum.donatable_ids():
		var sid3 := String(rid3)
		if ItemCatalog.category_of(sid3) != ItemCatalog.CAT_RELIC:
			continue
		if m.museum.is_donated(sid3) and relic_done == "":
			relic_done = sid3
		elif not m.museum.is_donated(sid3) and relic_todo == "":
			relic_todo = sid3
	_check("⑳pre 전시된 유품 %s · 미전시 유품 %s 확보" % [relic_done, relic_todo],
		relic_done != "" and relic_todo != "")
	if relic_done != "" and relic_todo != "":
		_check("⑳a 미전시 유품은 여전히 출하 거절 — 하나뿐인 수집물이 안 새어 나간다",
			not m._relic_sellable(relic_todo))
		_check("⑳b 전시가 끝난 종의 중복분은 출하 대상이다(카탈로그 판매가 %d냥)"
				% ItemCatalog.price_of(relic_done),
			m._relic_sellable(relic_done) and ItemCatalog.price_of(relic_done) > 0)
		m.inventory.add_item(relic_done, 1)
		var relic_slot := -1
		for i in range(m.inventory.slots.size()):
			if m.inventory.id_at(i) == relic_done:
				relic_slot = i
				break
		var bin_before: int = m.ship_bin.count_of(relic_done)
		m._on_frame_deposit(relic_slot)
		_check("⑳c 출하함이 실제로 받는다(%d → %d) — 처분 경로가 휴지통뿐이 아니게 됐다"
				% [bin_before, m.ship_bin.count_of(relic_done)],
			m.ship_bin.count_of(relic_done) == bin_before + 1)

	# ── ㉑ #21 [F] 창구 좌표에는 설치물을 세울 수 없다 ───────────────────────
	print("── ㉑ #21 우편함 칸의 [F]를 설치물이 가로채지 못한다 ──")
	m._region = RegionCatalog.HOME
	m._indoor = ""
	m._rebuild_region(RegionCatalog.HOME)
	var f_tiles: Array = [m.MAILBOX_TILE, m.PET_TILE, m.PET_BOWL_TILE]
	var leaks: Array = []
	for ft: Vector2i in f_tiles:
		if m._can_place_furnace(ft) or m._can_place_crystalarium(ft) \
				or m._can_place_sprinkler(ft) or m._can_place_pot(ft):
			leaks.append(ft)
	_check("㉑a [F] 창구 칸 %d개에 업화로·결정기·스프링클러·화분이 전부 안 놓인다(새는 칸: %s)"
			% [f_tiles.size(), str(leaks)],
		leaks.is_empty())
	_check("㉑b 레어크로우도 같은 가드를 받는다(`_can_place_sprinkler` 경유)",
		not m._can_place_rarecrow(m.MAILBOX_TILE))
	# 가드가 과하지 않다 — 우편함 **옆** 평범한 GROUND 칸은 여전히 설치 가능해야 한다.
	var neighbor: Vector2i = m.MAILBOX_TILE + Vector2i(-1, 0)
	_check("㉑c 바로 옆 칸(%s)은 그대로 설치 가능하다 — 가드가 좌표 셋에만 걸린다" % str(neighbor),
		m._can_place_furnace(neighbor) or m._can_place_crystalarium(neighbor))
	_check("㉑d 술어는 구역·실내 축을 함께 든다(다른 무대의 같은 좌표는 무관)",
		_in_func("func _f_window_tile", "_region != RegionCatalog.HOME"))

	# ── ㉒ #22 본문이 건넨 물건이 실제로 봉투에서 나온다 ─────────────────────
	print("── ㉒ #22 편지 첨부가 본문과 어긋나지 않는다 ──")
	_check("㉒a 물건을 명시적으로 건네는 관문 편지 셋에 첨부가 섰다",
		Mailbox.has_attachment("miho_gate3_pumpkin")
		and Mailbox.has_attachment("ken_gate1_pot")
		and Mailbox.has_attachment("scarlet_gate2_coin"))
	_check("㉒b 호박씨 = 실재 작물의 씨앗 id(진실원 대조 — 리터럴이 카탈로그와 맞는다)",
		String(Mailbox.attachment_items_of("miho_gate3_pumpkin")[0]["id"])
			== ItemCatalog.seed_id(CropCatalog.YEONGHON_HOBAK)
		and String(Mailbox.attachment_items_of("ken_gate1_pot")[0]["id"]) == ItemCatalog.GARDEN_POT)
	# 백팩을 비운다 — `_read_next_letter`는 첨부가 안 들어가면 편지를 **안 연다**(자리 가드).
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) != "":
			m.inventory.remove_at(i, m.inventory.count_at(i))
	m.mailbox.send("ken_gate1_pot")
	m.mailbox.advance_day()
	var pot_before: int = m.inventory.count_of(ItemCatalog.GARDEN_POT)
	while m.mailbox.next_unread() != "" and m.mailbox.next_unread() != "ken_gate1_pot":
		m._read_next_letter()
		_dismiss_dialogue(m)
	m._read_next_letter()
	_dismiss_dialogue(m)
	_check("㉒c 켄의 편지를 읽으면 화분이 실제로 백팩에 들어온다(%d → %d)"
			% [pot_before, m.inventory.count_of(ItemCatalog.GARDEN_POT)],
		m.inventory.count_of(ItemCatalog.GARDEN_POT) == pot_before + 1)

	# ── ㉓ #23 채널 개통 안내가 실제로 도착한다 ─────────────────────────────
	print("── ㉓ #23 우편함 사용 설명이 영영 안 오던 자리 ──")
	_check("㉓pre herald_notice가 테이블에 있고 본문을 든다",
		m.mailbox.has_letter(m.HERALD_NOTICE_LETTER)
		and not Mailbox.lines_of(m.HERALD_NOTICE_LETTER).is_empty())
	_check("㉓a 발송 조건이 없다 — 하루 정산이 무조건 큐에 넣는다(멱등)",
		m.mailbox.ever_sent(m.HERALD_NOTICE_LETTER))
	# 도착 증명 = ㉒에서 우편함을 비우며 이 통이 실제로 열렸다는 사실(기독 원장은 도착분에만 선다).
	_check("㉓b 다음 아침 우편함에 실제로 꽂혀 열린다(기독 원장에 올랐다)",
		m.mailbox.is_read(m.HERALD_NOTICE_LETTER))
	_check("㉓c 두 번 보내지 않는다(ever_sent 멱등)",
		not m.mailbox.send(m.HERALD_NOTICE_LETTER))

	for s in SaveManager.SLOT_COUNT:
		_wipe_slot(s)
	print("── 결과: %s (실패 %d)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

func _wheel_down(p: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.position = p
	return e

func _wheel_up(p: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	e.position = p
	return e
