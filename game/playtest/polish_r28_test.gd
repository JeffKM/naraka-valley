extends SceneTree
# ★[폴리시 28회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#14).
#
# 렌즈: R27 diff 리뷰(#0~#3) · 동사 광고 정합(#4~#8) · 정수 절단/반올림(#9~#11) ·
#       상한 경계(#12·#13) · 알림 적재물의 진실(#14).
#
# 이 배치의 태도 넷.
#   ㉠ **프롬프트와 집행은 같은 표를 본다 — «표»에는 항의 수도 폭도 든다.** #0은 R27 #17이
#      새로 세운 판정자가 집행부(`FarmField.water`)의 셋 중 둘만 옮겨 적어 성숙 칸에서 갈린
#      자리고, #12는 그 판정자가 **자원 한 축**(물통 잔량)을 통째로 안 보던 자리다. 둘 다 술어를
#      한 곳으로 모아 닫는다(`can_water` 신설 · 프롬프트가 `_can_water`를 묻는다).
#   ㉡ **광고 창이 판정 창보다 좁으면 «몰래 결행»이고, 넓으면 «침묵 실패»다.** #6은 되돌릴 수
#      없는 고백이 광고 없는 프레임에서도 [F]로 결행되던 자리(좁은 광고)고, #4·#5·#8은 화면이
#      약속한 동사가 집행부에 닿지도 못하거나 아예 다른 동사가 나가던 자리(어긋난 광고)다.
#   ㉢ **관례는 선언된 것이 있으면 그것이 계약이다.** #10·#11은 저장소가 `XpBoost.scaled_by`
#      머리말에 「main의 기존 배수 처리 관례 그대로(int(round(...)))」라고 못 박아 두고 전투와
#      선물만 절단이던 자리다. #10은 그 절단이 **퍼크를 밴드 전체에서 실효 0**으로 만든다.
#   ㉣ **상한에 닿은 프레임의 처리는 형제 창구와 같아야 한다.** #13은 같은 함수·같은 낫의 형제
#      갈래가 백팩 상한에 선거절을 세우는데 여물광 상한에만 그 규율이 없던 자리고, #14는 최고
#      티어에서 «이행할 수 없는 지시»를 내던 자리다(R26 #9 장원제의 목축판).
#
# 무엇을 보증하나(번호 = 28회차 헌트 발견 인덱스).
#   ① #0  물주기 판정자가 집행부와 **같은 세 항**을 본다(성숙 미급수 이웃 칸이 화면을 안 켠다).
#   ② #12 빈 물뿌리개는 **누르기 전에** 말한다 — 티어 AoE의 침묵(알림 0)도 함께 닫힌다.
#   ③ #1  방목 이월이 아침 방출과 **같은 하늘**을 본다(잿눈 날 고립 짐승도 가산 0).
#   ④ #2  구세이브 백필의 되감기 표식은 **추정이라고 적힌다** — 화면이 «이미 열매를 냈다»고 안 한다.
#   ⑤ #3  «급여 남음» 안내가 여물광 잔량을 본다(빈 여물광이면 그 사실을 함께 말한다).
#   ⑥ #4  묘목 프롬프트의 무대 술어 = 디스패치(실내에서 안 뜬다 — 좌클릭이 닿지도 못하던 자리).
#   ⑦ #5  손 소모품 셋(명부환·곁들이·계단)이 [좌클릭] 한 줄을 갖는다 — 갱도에서 곡괭이 문법을 덮는다.
#   ⑧ #6  고백 [F]/[G]는 **제안 줄이 떠 있는 프레임에만** 받는다.
#   ⑨ #7  음소거 [M]이 키와 현재 상태로 광고된다(누른 프레임의 알림 + 옵션 탭 행).
#   ⑩ #8  방목 문 [F] 광고 폭 = 집행 폭(짐승 0마리 축사·화분 칸에서도 선다).
#   ⑪ #10 전투 정수화가 **반올림**이다 — 투사 퍼크가 시작 무기 밴드에서 실효를 갖는다.
#   ⑫ #11 선물 등급 배수도 반올림이다(라이크 채널의 0.5점 누수 소멸 · 스타듀 불변식 보존).
#   ⑬ #13 여물광 240/240이면 사료풀 낫질이 **선거절**된다(혼력·재생 노드 소진 0).
#   ⑭ #14 만석 알림이 최고 티어에서 이행 불가능한 지시를 안 낸다.
#
# 판정: CONFIRMED 14 · **OWNER-DECISION 1**(#9 — 코드 무수정) · REFUTED·DUP 0.
#   ★ #0과 #12는 **형제이되 별개 결함**이다(오케 위임 판정): 둘 다 물주기 프롬프트↔집행의
#     어긋남이지만 빠진 항이 다르다 — #0은 칸 술어의 셋째 항(`not is_mature`)이고 #12는 자원
#     축(`_can_water`)이다. 처방도 갈린다(원장에 술어 신설 / 프롬프트에 자원 질의 추가). 재현은
#     겹치는 구간이 하나 있는데(빈 통 + 티어 AoE의 완전 침묵) 그 자리는 **두 봉합이 각각** 닫는다:
#     아래 ②c는 사유 갈래가 AoE 표를 보게 된 쪽을, ②b는 프롬프트가 자원을 묻게 된 쪽을 잰다.
#   ★ #9 OWNER-DECISION(코드 무수정) — `ceili` 양자화가 하이퍼 비료(0.67)를 성장촉진(0.75)과
#     5작물 중 3종에서 **같은 임계로 접는다**(base 4 → 3/3 · base 12 → 9/9). 결함은 실재하나
#     어떤 처방이든 «100냥이 얼마나 빨라지는가»라는 눈금을 움직이므로(후보안은 커밋 본문)
#     여기서 어휘를 발명하지 않는다. 그래서 이 스위트에 #9 항목은 없다.
#
# 하중 검증(파괴 15배치 — 봉합을 되돌리면 실제로 red가 남는가 · 전건 실측).
#   #0  `_water_aoe_has_work`를 두 항으로 복귀            → ①a·①f red(성숙 이웃 칸이 다시 화면을 켠다)
#   #12 `_farm_prompt`의 `_can_water <= 0` 삭제           → ②a·②b red(빈 통이 다시 동사를 약속한다)
#       사유 갈래를 조준 칸 단독으로 복귀                 → ②c red(그 좌클릭이 다시 침묵한다)
#   #1  `advance_day`의 `pasture_grazes` 항 삭제           → ③a·③d red(잿눈 날 고립만 가산을 받는다)
#   #2  백필의 `regrown_guess` 삭제                        → ④b·④e red(첫 사이클에 «이미 열매를 냈다»)
#   #3  `_animal_prompt`의 잔량 갈래 삭제                  → ⑤b red(빈 여물광을 안 말한다)
#   #4  무대 술어를 `_region == HOME`으로 복귀             → ⑥a·⑥e red(실내에서 다시 묘목을 약속한다)
#   #5  꼬리 삽입 삭제 + `_free_use_prompt` 본문 파괴      → ⑦a·⑦c·⑦d·⑦e red
#   #6  `dialogue.line() == CONFESS_OFFER_LINE` 삭제       → ⑧a red
#   #7  알림 줄·주입 인자·옵션 행 삭제                     → ⑨a·⑨b·⑨c red
#   #8  꼬리 append를 죽은 갈래로                          → ⑩c·⑩d red(두 무대에서 [F]가 사라진다)
#   #10 `int(round(dmg))` → `int(dmg)`                     → ⑪a·⑪c·⑪d red(오른 시드 97 → **0**)
#   #11 `int(round(...))` → `int(...)`                     → ⑫a·⑫c red(은 28→27 · 이리듐 38→37)
#   #13 낫질 선거절 + 프롬프트 갈래 삭제                   → ⑬a·⑬d·⑬e·⑬f red
#   #14 만석 알림의 티어 갈래 삭제                          → ⑭a·⑭d red
#   ★ 파괴에 **안 죽는** 줄들은 전부 «무대 성립»과 «대조군»이다(①b~①e·②d·②e·③b·③c·③e·④a·④c·
#     ④f·⑤a·⑤c·⑥b~⑥d·⑦b·⑧b·⑧c·⑨d·⑩a·⑩b·⑩e·⑪a2·⑪b·⑫b·⑫d·⑫e·⑬b·⑬c·⑭b·⑭c·⑭e) — 전제를
#     재는 자리라 봉합과 독립이고, 하중은 위 목록이 든다.
#   ★ ⑨d(그린 상태 ↔ 버스 mute)는 프레임 쪽 왕복만 재므로 main 주입을 지워도 안 죽는다 — 그
#     축의 하중은 ⑨c(배선)가 든다. ⑩a도 같은 결이다(죽은 갈래로 파괴하면 니들 문자열은 남는다).
#
# 실행: ./run_tests.sh polish_r28   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0
var _src: PackedStringArray = PackedStringArray()
var _ui_src: PackedStringArray = PackedStringArray()
var _field_src: PackedStringArray = PackedStringArray()
var _ranch_src: PackedStringArray = PackedStringArray()

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

# ── 소스 스캔 헬퍼(polish_r7~r27 관례 — 니들은 반드시 함수 안에서 센다) ──────
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

func _select(m: Node, id: String) -> void:
	m.inventory.add_item(id, 1)
	for i in range(m.inventory.slots.size()):
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return

func _notice_has(m: Node, needle: String) -> bool:
	if m.notice_feed == null:
		return false
	for e in m.notice_feed._items:
		if String(e.get("text", "")).contains(needle):
			return true
	return false

func _clear_notices(m: Node) -> void:
	if m.notice_feed != null:
		m.notice_feed._items.clear()

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R28 회귀 — 배치 A(#0~#14) ══")
	SaveManager.new().delete_save()
	_src = _lines_of_file("res://main.gd")
	_ui_src = _lines_of_file("res://inv_frame.gd")
	_field_src = _lines_of_file("res://field.gd")
	_ranch_src = _lines_of_file("res://livestock.gd")
	_check("무대 전제: main(%d)·inv_frame(%d)·field(%d)·livestock(%d)행을 읽었다(부정 단언 공허 통과 방지)"
			% [_src.size(), _ui_src.size(), _field_src.size(), _ranch_src.size()],
		_src.size() > 1000 and _ui_src.size() > 500
			and _field_src.size() > 100 and _ranch_src.size() > 100)

	# ── 무대가 필요 없는 순수 계층 먼저 ──
	_check_graze_weather_gate()       # ③ #1
	_check_regrown_guess_ledger()     # ④ #2 전반(원장)
	_check_combat_rounding()          # ⑪ #10
	_check_gift_rounding()            # ⑫ #11

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

	_check_water_predicate(m)         # ① #0
	_check_empty_can_prompt(m)        # ② #12
	_check_regrown_guess_notice(m)    # ④ #2 후반(문구)
	_check_feed_prompt_silo(m)        # ⑤ #3
	_check_sapling_stage(m)           # ⑥ #4
	_check_free_use_prompt(m)         # ⑦ #5
	_check_confess_window(m)          # ⑧ #6
	_check_mute_ad(m)                 # ⑨ #7
	await _check_pasture_door_width(m)   # ⑩ #8
	await _check_forage_silo_cap(m)      # ⑬ #13
	_check_animal_cap_notice(m)          # ⑭ #14

	SaveManager.new().delete_save()
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 물주기 판정자 = 집행부의 세 항 ──────────────────────────────────────
func _check_water_predicate(m: Node) -> void:
	print("① #0 `_water_aoe_has_work` ↔ `FarmField.water`")
	_check("①a 배선: 판정도 집행도 **한 술어**를 문다(조건을 두 곳에 옮겨 적지 않는다)",
		_count_in(_src, "func _water_aoe_has_work", "can_water(at)") == 1
			and _count_in(_field_src, "func water", "can_water(t)") == 1
			and _count_in(_field_src, "func can_water", "is_mature(t)") == 1)
	# 순수 원장 — 성숙한 미급수 칸에서 두 답이 같다(종전엔 판정 true / 집행 false로 갈렸다).
	var f := FarmField.new()
	var t := Vector2i(1, 1)
	f.hoe(t)
	var crop: String = CropCatalog.ids()[0]
	f.plant(t, crop)
	var guard := 0
	while not f.is_mature(t) and guard < 60:
		f.water(t)
		f.advance_day()
		guard += 1
	_check("①b 무대: 다 자란 칸을 세웠고 아침에 흙이 말랐다(수확 안 한 작물의 상시 상태)",
		f.is_mature(t) and not f.is_watered(t))
	_check("①c 성숙 칸은 물이 안 든다 — 판정과 집행이 **같은 답**이다(false·false)",
		not f.can_water(t) and not f.water(t))
	f.free()
	# 라이브 — AoE 이웃 칸이 성숙 미급수일 때 화면이 동사를 약속하지 않는다.
	var span := _farm_row(m)
	_check("①d 무대: 조준 칸 %s와 그 앞 칸 %s가 둘 다 경작 가능하다" % [str(span[0]), str(span[1])],
		span[0].x >= 0)
	if span[0].x < 0:
		return
	var aim: Vector2i = span[0]
	var ahead: Vector2i = span[1]
	m.player.position = m._tile_center_px(aim - (ahead - aim))
	m.farm.hoe(aim)                       # 조준 칸 = 경작만 된 빈 칸
	m.farm.hoe(ahead)
	m.farm.plant(ahead, crop)
	var g2 := 0
	while not m.farm.is_mature(ahead) and g2 < 60:
		m.farm.water(ahead)
		m.farm.advance_day()
		g2 += 1
	m.farm._tiles[ahead]["watered"] = false
	m.tool_tier.set_tier(ItemCatalog.WATERING_CAN, 1)
	m._target = aim
	m._target_valid = true
	m._can_water = 30
	m.energy.refill()
	_select(m, ItemCatalog.WATERING_CAN)
	var aoe: Vector2i = m.tool_aoe(ItemCatalog.WATERING_CAN)
	_check("①e 무대: 티어 AoE %s가 조준 칸 밖으로 뻗고 이웃 칸이 성숙·미급수다" % str(aoe),
		aoe != Vector2i(1, 1) and m._farm_aoe_tiles(aim, aoe).has(ahead)
			and m.farm.is_mature(ahead) and not m.farm.is_watered(ahead))
	var p: String = m._farm_prompt()
	_check("①f 성숙 이웃 칸만 있는 AoE에 **물주기를 약속하지 않는다** — 「%s」" % p,
		not m._water_aoe_has_work() and not p.contains("[좌클릭] 물주기"))
	# 대조군 — 그 칸을 미성숙 미급수로 되돌리면 종전대로 광고한다(과소 광고 0).
	m.farm._tiles[ahead]["grown_days"] = 0
	var p2: String = m._farm_prompt()
	_check("①g 대조군: 미성숙 미급수 이웃이면 다시 말한다 — 「%s」" % p2,
		m._water_aoe_has_work() and p2.contains("[좌클릭] 물주기"))
	m.tool_tier.set_tier(ItemCatalog.WATERING_CAN, 0)

# 밭 흙 두 칸(조준 칸 + 그 아래 칸)을 지금 판에서 찾는다 — 좌표 옮겨 적기 0.
func _farm_row(m: Node) -> Array:
	for y in range(m.STARTER_PATCH_RECT.position.y + 1, m.STARTER_PATCH_RECT.end.y - 2):
		for x in range(m.STARTER_PATCH_RECT.position.x, m.STARTER_PATCH_RECT.end.x):
			var c := Vector2i(x, y)
			var d := c + Vector2i(0, 1)
			if m._is_farmable(c) and m._is_farmable(d) \
					and not m.farm.is_tilled(c) and not m.farm.is_tilled(d):
				return [c, d]
	return [Vector2i(-1, -1), Vector2i(-1, -1)]

# ── ② #12 빈 물뿌리개 ↔ 프롬프트·알림 ────────────────────────────────────────
func _check_empty_can_prompt(m: Node) -> void:
	print("② #12 물통 잔량 ↔ 화면 약속")
	_check("②a 배선: 두 프롬프트가 **자원 두 축**을 다 묻는다(혼력만 묻던 자리)",
		_count_in(_src, "func _farm_prompt", "_can_water <= 0") == 1
			and _count_in(_src, "func _pot_prompt", "_can_water <= 0") == 1)
	var span := _farm_row(m)
	if span[0].x < 0:
		_check("②b 무대: 밭 두 칸을 못 찾았다", false)
		return
	var aim: Vector2i = span[0]
	var ahead: Vector2i = span[1]
	m.player.position = m._tile_center_px(aim - (ahead - aim))
	var crop: String = CropCatalog.ids()[0]
	m.farm.hoe(aim)
	m.farm.hoe(ahead)
	m.farm.plant(ahead, crop)                 # 앞 칸 = 심겼고 마름(조준 칸은 빈 경작 칸)
	m.farm._tiles[ahead]["watered"] = false
	m.tool_tier.set_tier(ItemCatalog.WATERING_CAN, 1)
	m.energy.refill()
	_select(m, ItemCatalog.WATERING_CAN)
	m._target = aim
	m._target_valid = true
	m._can_water = 0
	var p: String = m._farm_prompt()
	_check("②b 잔량 0이면 동사를 약속하지 않고 **모자란 자원을 먼저** 말한다 — 「%s」" % p,
		p.contains("물이 없다") and not p.contains("[좌클릭] 물주기"))
	# 사유 갈래도 AoE 표를 본다 — 종전엔 조준 칸이 안 심겨 어느 갈래도 안 잡히고 알림 0이었다.
	_clear_notices(m)
	m._use_tool()
	_check("②c 그 자세에서 좌클릭이 **침묵하지 않는다**(알림 0이던 자리 — 사유 갈래가 AoE 표를 본다)",
		_notice_has(m, "물이 없다"))
	# 대조군 — 물이 있으면 종전대로 동사를 약속하고 실제로 적신다.
	m._can_water = 30
	var p2: String = m._farm_prompt()
	_check("②d 대조군: 물이 있으면 그대로 «[좌클릭] 물주기» — 「%s」" % p2, p2.contains("[좌클릭] 물주기"))
	m._use_tool()
	_check("②e 대조군: 그 좌클릭이 실제로 앞 칸을 적신다(광고와 집행이 같은 표)",
		m.farm.is_watered(ahead))
	m.tool_tier.set_tier(ItemCatalog.WATERING_CAN, 0)

# ── ③ #1 방목 이월 ↔ 잿눈 게이트 ─────────────────────────────────────────────
func _check_graze_weather_gate() -> void:
	print("③ #1 실외 고립 이월 ↔ 방목 금지일")
	_check("③a 배선: 이월이 **인자로 받은 날씨**를 보고, main이 방출과 같은 술어를 넘긴다",
		_count_in(_ranch_src, "func advance_day", "pasture_grazes and str(a.get(\"location\"")  == 1
			and _count_in(_src, "func _on_day_advanced", "ranch.advance_day(Weather.allows_grazing(") == 1)
	_check("③b 계약: 이 게임의 방목 금지는 잿눈 하나다(단일 게이트 술어)",
		not Weather.allows_grazing(Weather.SNOW) and Weather.allows_grazing(Weather.RAIN))
	var r := Ranch.new()
	var barn := "넋둥우리"
	var t := Vector2i(2, 2)
	var t2 := Vector2i(3, 3)
	r.add_animal(t, AnimalCatalog.ids()[0], barn)
	r.add_animal(t2, AnimalCatalog.ids()[0], barn)
	r.set_door(barn, true)
	r.send_to_pasture(t, Vector2i(9, 9))
	r.set_door(barn, false)
	r.settle_night()
	_check("③c 무대: 한 마리는 실외 고립·한 마리는 실내다", r.is_outside(t) and not r.is_outside(t2))
	r.advance_day(false)                       # 잿눈 아침 = 아무도 못 나가는 날
	_check("③d 방목 금지일엔 **고립 짐승도** 그날의 방목 가산을 못 받는다(실내와 같은 답)",
		not r._animals[t]["grazed"] and not r._animals[t2]["grazed"])
	r.advance_day(true)                        # 평온한 아침 = R27 #16 계약 그대로
	_check("③e 대조군: 방목이 성립하는 날엔 이월이 그대로 산다(R27 #16 불변)",
		r.is_outside(t) and r._animals[t]["grazed"] and not r._animals[t2]["grazed"])
	r.free()

# ── ④ #2 백필 추정 표식 ──────────────────────────────────────────────────────
func _check_regrown_guess_ledger() -> void:
	print("④ #2 되감기 표식 백필 ↔ 표시 정직성(원장)")
	# 되자람 작물 하나와 그 눈금을 카탈로그에서 파생한다(수 옮겨 적기 0).
	var crop := ""
	for id in CropCatalog.ids():
		if CropCatalog.regrow_cooldown(id) > 0:
			crop = id
			break
	_check("④a 무대: 되자람 작물 «%s»를 찾았다" % crop, crop != "")
	if crop == "":
		return
	var base: int = CropCatalog.growth_days(crop)
	var cd: int = CropCatalog.regrow_cooldown(crop)
	# pre-R22 세이브 모양 — `regrown` 키가 없고 grown은 첫 사이클로 자라던 중이다.
	var first_cycle: int = maxi(0, base - cd)
	var f := FarmField.new()
	f.load_save({"tiles": {Vector2i(1, 1): {
		"planted": true, "crop": crop, "grown_days": first_cycle, "need_days": base,
		"watered": false, "fertilizer": ""}}})
	var t := Vector2i(1, 1)
	_check("④b 백필은 그 칸을 되감기로 접되(임계 계약 유지) **추정이라고 적는다**",
		f.fertilize_sealed_no_op(t, FertilizerCatalog.FERT_SPEED) and f.regrow_seal_is_guess(t))
	f.free()
	# 실제 수확이 새긴 표식은 추정이 아니다 — 같은 술어가 두 출처를 가른다.
	var f2 := FarmField.new()
	f2.hoe(t)
	f2.plant(t, crop)
	var guard := 0
	while not f2.is_mature(t) and guard < 60:
		f2.water(t)
		f2.advance_day()
		guard += 1
	f2.harvest(t)
	_check("④c 수확이 새긴 표식은 **증명된 사실**이다(추정 딱지 0)",
		f2.fertilize_sealed_no_op(t, FertilizerCatalog.FERT_SPEED) and not f2.regrow_seal_is_guess(t))
	f2.free()

func _check_regrown_guess_notice(m: Node) -> void:
	print("④ #2 되감기 표식 백필 ↔ 표시 정직성(문구)")
	_check("④d 배선: 문구가 추정 여부로 갈린다(한 문장이 두 출처를 다 말하지 않는다)",
		_count_in(_src, "func _use_tool", "regrow_seal_is_guess(_target)") == 1
			and _count_in(_src, "func _use_tool", "성숙 임계가 굳은 포기엔 듣지 않는다") == 1)
	var crop := ""
	for id in CropCatalog.ids():
		if CropCatalog.regrow_cooldown(id) > 0:
			crop = id
			break
	if crop == "":
		return
	var span := _farm_row(m)
	if span[0].x < 0:
		return
	var t: Vector2i = span[0]
	var base: int = CropCatalog.growth_days(crop)
	var cd: int = CropCatalog.regrow_cooldown(crop)
	m.farm.load_save({"tiles": {t: {
		"planted": true, "crop": crop, "grown_days": maxi(0, base - cd), "need_days": base,
		"watered": false, "fertilizer": ""}}})
	m._target = t
	m._target_valid = true
	m.energy.refill()
	_select(m, FertilizerCatalog.FERT_SPEED)
	_clear_notices(m)
	m._use_tool()
	_check("④e 한 번도 거둔 적 없는 포기에 «이미 열매를 냈다»고 **단언하지 않는다**",
		_notice_has(m, "성숙 임계가 굳은 포기") and not _notice_has(m, "이미 열매를 낸 포기"))
	# 대조군 — 실제 수확으로 선 표식이면 종전 문구 그대로다(과잉 적용 0).
	m.farm.load_save({"tiles": {t: {
		"planted": true, "crop": crop, "grown_days": maxi(0, base - cd), "need_days": base,
		"watered": false, "fertilizer": "", "regrown": true}}})
	_clear_notices(m)
	m._use_tool()
	_check("④f 대조군: 증명된 되감기 칸은 종전 문구를 그대로 말한다",
		_notice_has(m, "이미 열매를 낸 포기"))
	m.farm.load_save({"tiles": {}})

# ── ⑤ #3 «급여 남음» ↔ 여물광 잔량 ───────────────────────────────────────────
func _check_feed_prompt_silo(m: Node) -> void:
	print("⑤ #3 급여 안내 ↔ 여물광")
	var beast := Vector2i(-1, -1)
	for tile in m.ranch._animals.keys():
		beast = tile
		break
	_check("⑤a 무대: 짐승 한 마리를 잡았다 %s" % str(beast), beast.x >= 0)
	if beast.x < 0:
		return
	var a: Dictionary = m.ranch._animals[beast]
	a["product"] = 0
	a["petted"] = true
	a["fed"] = false
	a["cleaned"] = true
	_select(m, ItemCatalog.HOE)               # 손에 건초가 없어야 이 갈래로 온다
	m.ranch._silo_hay = 0
	var txt: String = m._animal_prompt(beast)
	_check("⑤b 여물광이 비면 «급여 남음»이 그 사실을 함께 말한다 — 「%s」" % txt,
		txt.contains("급여") and txt.contains("여물광이 비어 급여 불가"))
	m.ranch._silo_hay = 10
	var txt2: String = m._animal_prompt(beast)
	_check("⑤c 대조군: 건초가 있으면 그 꼬리가 붙지 않는다 — 「%s」" % txt2,
		txt2.contains("급여") and not txt2.contains("여물광이 비어"))
	a["fed"] = true

# ── ⑥ #4 묘목 프롬프트 무대 술어 = 디스패치 ──────────────────────────────────
func _check_sapling_stage(m: Node) -> void:
	print("⑥ #4 과수 프롬프트 ↔ 실내")
	_check("⑥a 배선: 프롬프트가 **디스패치 술어 그대로**를 본다(무대 항 재작성 0)",
		_count_in(_src, "func _farm_prompt", "_orchard_plant_dispatch()") == 1
			and _count_in(_src, "func _farm_prompt", "_orchard_harvest_dispatch_at(_target)") == 1)
	var saps: Array = ItemCatalog.ids_in_category(ItemCatalog.CAT_SAPLING)
	var sap: String = String(saps[0]) if not saps.is_empty() else ""
	_check("⑥b 무대: 묘목 아이템 «%s»를 찾았다" % sap, sap != "")
	if sap == "":
		return
	_select(m, sap)
	m.energy.refill()
	# 바깥 — 심을 수 있는 앵커에서는 종전대로 광고한다(대조군을 먼저 세운다).
	m._indoor = ""
	var anchor := Vector2i(-1, -1)
	for y in range(6, 40):
		for x in range(30, 70):
			var c := Vector2i(x, y)
			if m.orchard.can_plant(c, m._is_tree_blocked):
				anchor = c
				break
		if anchor.x >= 0:
			break
	_check("⑥c 무대: 바깥에 심을 수 있는 앵커 %s가 있다" % str(anchor), anchor.x >= 0)
	if anchor.x < 0:
		return
	m._target = anchor
	var out_p: String = m._farm_prompt()
	_check("⑥d 대조군: 바깥에서는 그대로 «묘목 심기»를 말한다 — 「%s」" % out_p,
		out_p.contains("묘목 심기"))
	# 실내 — 집행부가 두 겹으로 배제하는 무대다(집 방 바닥은 SOLID가 아니라 can_plant가 통과한다).
	m._indoor = "집"
	var in_p: String = m._farm_prompt()
	_check("⑥e 실내에서는 **약속하지 않는다** — 좌클릭이 `_use_tool`에 닿지도 못하던 자리 「%s」" % in_p,
		not m._orchard_plant_dispatch() and not in_p.contains("묘목 심기"))
	m._indoor = ""

# ── ⑦ #5 손 소모품 셋의 [좌클릭] 광고 ────────────────────────────────────────
func _check_free_use_prompt(m: Node) -> void:
	print("⑦ #5 명부환·곁들이·계단 ↔ 동사 광고")
	_check("⑦a 배선: 사슬 세 자리(갱도·나락·꼬리)가 이 한 줄을 쓴다",
		_count_in(_src, "func _process", "_free_use_prompt() != \"\"") == 2
			and _count_in(_src, "func _process", "prompt = _free_use_prompt()") == 1)
	_check("⑦b 배선: 광고와 집행이 **같은 셋**을 든다(`_is_free_use_item`이 그 명단)",
		_count_in(_src, "func _is_free_use_item", "ItemCatalog.STAIRS") == 1)
	m.energy.refill()
	m.health.refill()
	# 명부환 — 체력이 가득이면 아껴 두라 말하고, 닳으면 동사를 말한다.
	_select(m, ItemCatalog.MYEONGBUHWAN)
	var full_line: String = m._free_use_prompt()
	m.health.damage(5)
	var heal_line: String = m._free_use_prompt()
	_check("⑦c 명부환 — 가득하면 «아껴 두자»(소모 방지) / 닳으면 [좌클릭] 동사 「%s」/「%s」"
			% [full_line, heal_line],
		full_line.contains("아껴 두자") and heal_line.contains("[좌클릭]") and heal_line.contains("체력"))
	# 곁들이 — 같은 문법의 혼력판.
	var dish: String = MenuCatalog.side_dish_ids()[0]
	_select(m, dish)
	m.energy.spend(m.energy.current / 2 + 1)
	var dish_line: String = m._free_use_prompt()
	_check("⑦d 곁들이 — [좌클릭] 동사와 회복량을 말한다 「%s」" % dish_line,
		dish_line.contains("[좌클릭]") and dish_line.contains("혼력"))
	# 계단 — 무대가 갈린다. 지상에선 조용하고(밭 안내를 안 가린다) 갱도 층에서는 동사를 말한다.
	_select(m, ItemCatalog.STAIRS)
	m._region = RegionCatalog.HOME
	m._mine_floor = 0
	var ground_line: String = m._free_use_prompt()
	m._region = RegionCatalog.EOPHWA_MINE
	m._mine_floor = 1
	var mine_line: String = m._free_use_prompt()
	m._region = RegionCatalog.HOME
	m._mine_floor = 0
	_check("⑦e 계단 — 지상에선 조용하고 갱도 층에서만 «한 층 아래로»를 말한다(종전엔 「곡괭이가 있어야」가 섰다) 「%s」"
			% mine_line,
		ground_line == "" and mine_line.contains("[좌클릭]") and mine_line.contains("계단"))
	_select(m, ItemCatalog.HOE)

# ── ⑧ #6 고백 [F]/[G]의 판정 창 ──────────────────────────────────────────────
func _check_confess_window(m: Node) -> void:
	print("⑧ #6 고백 제안 ↔ [F] 판정 창")
	_check("⑧a 배선: 입력 분기가 **지금 떠 있는 줄**을 본다(줄 인덱스를 한 항도 안 보던 자리)",
		_count_in(_src, "func _process", "dialogue.line() == CONFESS_OFFER_LINE") == 1)
	# 제안이 선 대화를 그대로 세운다(프로덕션 상수 · 프로덕션 대화 노드).
	var lines := PackedStringArray([m.CONFESS_OFFER_LINE, "…오늘은 바람이 좋네.", "…또 보자."])
	m.dialogue.start("테스트", lines)
	m._confess_rid = "miho"
	_check("⑧b 무대: 제안 줄이 화면에 떠 있다(광고 창이 열린 프레임)",
		m.dialogue.is_open() and m.dialogue.line() == m.CONFESS_OFFER_LINE)
	m.dialogue.advance()
	_check("⑧c 한 줄 넘기면 **광고가 사라진다** — 그런데 종전 판정은 `_confess_rid`만 봐 살아 있었다",
		m.dialogue.line() != m.CONFESS_OFFER_LINE and m._confess_rid != "")
	m.dialogue.advance()
	m.dialogue.advance()
	m._confess_rid = ""

# ── ⑨ #7 음소거 [M] 광고 ─────────────────────────────────────────────────────
func _check_mute_ad(m: Node) -> void:
	print("⑨ #7 [M] 음소거 ↔ 키·상태 광고")
	_check("⑨a 배선: 누른 프레임이 **상태를 말한다**(되돌릴 키까지)",
		_count_in(_src, "func _process", "음소거 %s") == 1)
	_check("⑨b 배선: 옵션 탭에 키와 현재 상태를 그리는 행이 섰다(F11 행과 같은 결)",
		_count_in(_ui_src, "func _draw_options_tab", "\"음소거\"") == 1
			and _count_in(_ui_src, "func _draw_options_tab", "\"[M]\"") == 1
			and _count_in(_ui_src, "func _draw_options_tab", "_set_muted") == 1)
	_check("⑨c 배선: main이 그 상태를 실제로 주입한다(볼륨과 직교라 바로는 알 수 없다)",
		_count_in(_src, "func _process", "audio.is_muted())") == 1)
	# 상태 왕복 — 주입한 값이 그리기 표에 실린다(버스 mute가 진실원).
	var was: bool = m.audio.is_muted()
	m.audio.set_muted(true)
	m.frame.set_settings(0.8, 0.9, false, m.audio.is_muted())
	var shown_on: bool = m.frame._set_muted
	m.audio.set_muted(false)
	m.frame.set_settings(0.8, 0.9, false, m.audio.is_muted())
	var shown_off: bool = m.frame._set_muted
	m.audio.set_muted(was)
	_check("⑨d 그린 상태가 버스 mute를 따라간다(체크박스가 «지금 어느 쪽인가»를 든다)",
		shown_on and not shown_off)

# ── ⑩ #8 방목 문 [F] 광고 폭 = 집행 폭 ───────────────────────────────────────
func _check_pasture_door_width(m: Node) -> void:
	print("⑩ #8 방목 문 광고 ↔ 집행 술어")
	_check("⑩a 배선: 꼬리 광고가 **집행부와 같은 한 항**을 본다(짐승 수·화분 항 0)",
		_count_in(_src, "func _process", "ranch != null and _indoor in ANIMAL_BUILDINGS:") == 1
			and _count_in(_src, "func _process", "_indoor in ANIMAL_BUILDINGS and Input.is_action_just_pressed") == 1)
	# 짐승 0마리 축사를 만든다 — 그 건물의 짐승을 잠시 다른 건물 이름으로 옮긴다(원장 복원).
	var barn: String = m.ANIMAL_BUILDINGS[0]
	var moved: Array = []
	for tile in m.ranch._animals.keys():
		if String(m.ranch._animals[tile].get("home_building", "")) == barn:
			m.ranch._animals[tile]["home_building"] = "__test__"
			moved.append(tile)
	_check("⑩b 무대: %s가 짐승 0마리다(축사를 짓고 짐승을 사기 전 상태)" % barn,
		m.ranch.animals_in(barn).is_empty())
	m._region = RegionCatalog.HOME
	m._indoor = barn
	m._sleeping = false
	m._transitioning = false
	m.ranch.set_door(barn, false)
	m._target = Vector2i(0, 0)
	await process_frame
	await process_frame
	var empty_txt: String = m.interact_prompt.text
	_check("⑩c 짐승 0마리 축사에서도 [F]가 키와 상태로 광고된다 — 「%s」" % empty_txt,
		empty_txt.contains("[F] 방목 문") and empty_txt.contains("지금 닫힘"))
	for tile in moved:
		m.ranch._animals[tile]["home_building"] = barn
	m.ranch.set_door(barn, true)
	await process_frame
	await process_frame
	var with_txt: String = m.interact_prompt.text
	_check("⑩d 짐승이 있어도 그대로 선다(R27 #13 계약 불변 · 상태가 따라간다) — 「%s」" % with_txt,
		with_txt.contains("[F] 방목 문") and with_txt.contains("지금 열림"))
	m.ranch.set_door(barn, false)
	m._indoor = ""
	await process_frame
	await process_frame
	_check("⑩e 대조군: 축사 밖에서는 그 줄이 안 붙는다(과잉 광고 0)",
		not m.interact_prompt.text.contains("[F] 방목 문"))

# ── ⑪ #10 전투 정수화 = 반올림 ───────────────────────────────────────────────
func _check_combat_rounding() -> void:
	print("⑪ #10 전투 피해 정수화 ↔ 배수 처리 관례")
	var csrc := _lines_of_file("res://combat_skill.gd")
	_check("⑪a 배선: `resolve_hit`이 관례대로 반올림한다(절단 0)",
		_count_in(csrc, "static func resolve_hit", "maxi(int(round(dmg)), 1)") == 1)
	# 시작 무기 밴드에서 «투사만»(+10%) 걸었을 때 한 점이라도 오르는 시드를 찾는다.
	# 퍼크 값은 **레지스트리에서 파생**한다(수 옮겨 적기 0 — 투사 한 갈래만 고른다).
	var bonus := 0.0
	for perk in ProfessionCatalog.perks_of(ProfessionCatalog.COMBAT, "fighter"):
		if String(perk.get("dim", "")) == ProfessionCatalog.DIM_DAMAGE_BONUS:
			bonus = float(perk["value"])
	_check("⑪a2 무대: 투사 피해 퍼크 값을 레지스트리에서 파생했다(+%d%%)" % int(bonus * 100.0), bonus > 0.0)
	var lifted := 0
	var five_seed := -1
	for s in range(400):
		var plain: Dictionary = CombatSkill.resolve_hit(WeaponCatalog.SWORD_RUSTY, s)
		if bool(plain["crit"]):
			continue
		var buffed: Dictionary = CombatSkill.resolve_hit(WeaponCatalog.SWORD_RUSTY, s, bonus)
		if int(buffed["damage"]) > int(plain["damage"]):
			lifted += 1
		if int(plain["base"]) == 5 and five_seed < 0:
			five_seed = s
	_check("⑪b 무대: 밴드 상단(base 5)이 나오는 시드를 찾았다(#%d)" % five_seed, five_seed >= 0)
	if five_seed >= 0:
		var p5: Dictionary = CombatSkill.resolve_hit(WeaponCatalog.SWORD_RUSTY, five_seed)
		var b5: Dictionary = CombatSkill.resolve_hit(WeaponCatalog.SWORD_RUSTY, five_seed, bonus)
		_check("⑪c base 5에 투사(+10%%)를 걸면 피해가 오른다(5 → %d — 절단이면 5로 제자리였다)"
				% int(b5["damage"]),
			int(p5["damage"]) == 5 and int(b5["damage"]) > int(p5["damage"]))
	_check("⑪d 퍼크가 이 무기에서 **실효 0이 아니다** — 오른 시드 %d개(종전 절단에선 전 밴드 0)" % lifted,
		lifted > 0)

# ── ⑫ #11 선물 등급 배수도 반올림 ────────────────────────────────────────────
func _check_gift_rounding() -> void:
	print("⑫ #11 선물 등급 배수 정수화 ↔ 같은 관례")
	var gsrc := _lines_of_file("res://gift_prefs.gd")
	_check("⑫a 배선: `points_for`가 관례대로 반올림한다(절단 0)",
		_count_in(gsrc, "static func points_for", "int(round(base * QUALITY_SCALE") == 1)
	# 품질을 싣는 물건 하나를 카탈로그에서 파생한다(id 옮겨 적기 최소).
	var it := ""
	for id in CropCatalog.ids():
		if ItemCatalog.carries_quality(id):
			it = id
			break
	_check("⑫b 무대: 품질을 싣는 물건 «%s»를 찾았다" % it, it != "")
	if it == "":
		return
	var silver: int = GiftPrefs.points_for(GiftPrefs.LIKE, it, ItemCatalog.Q_SILVER)
	var iridium: int = GiftPrefs.points_for(GiftPrefs.LIKE, it, ItemCatalog.Q_IRIDIUM)
	_check("⑫c 라이크 채널의 0.5점 누수가 사라졌다(은 %d · 이리듐 %d — 절단이면 27·37)"
			% [silver, iridium],
		silver == 28 and iridium == 38)
	_check("⑫d ★스타듀 불변식 보존: 일반 품질 러브 > 이리듐 라이크",
		GiftPrefs.points_for(GiftPrefs.LOVE, it, ItemCatalog.Q_NORMAL) > iridium)
	_check("⑫e 러브 계단은 정수라 한 톨도 안 변한다(44/50/60)",
		GiftPrefs.points_for(GiftPrefs.LOVE, it, ItemCatalog.Q_SILVER) == 44
			and GiftPrefs.points_for(GiftPrefs.LOVE, it, ItemCatalog.Q_GOLD) == 50
			and GiftPrefs.points_for(GiftPrefs.LOVE, it, ItemCatalog.Q_IRIDIUM) == 60)

# ── ⑬ #13 여물광 상한 ↔ 사료풀 낫질 ─────────────────────────────────────────
func _check_forage_silo_cap(m: Node) -> void:
	print("⑬ #13 여물광 240/240 ↔ 낫질 선거절")
	_check("⑬a 배선: 집행부가 **적재先**으로 갈린다(형제 갈래의 백팩 상한과 같은 규율)",
		_count_in(_src, "func _use_tool", "ranch.silo_full()") == 1)
	var t := Vector2i(-1, -1)
	for tile in m.forage.grown_tiles():
		t = tile
		break
	_check("⑬b 무대: 다 자란 사료풀 칸 %s를 잡았다" % str(t), t.x >= 0)
	if t.x < 0:
		return
	m._indoor = ""
	m._region = RegionCatalog.HOME
	m._sleeping = false
	m.energy.refill()
	_select(m, ItemCatalog.SCYTHE)
	m.ranch._silo_hay = Ranch.SILO_CAP
	# 화면이 그 칸을 실제로 겨누게 세운다(프롬프트는 `_process` 안이라 프레임을 태운다 —
	# `_update_target`은 발 칸 기준 인접 1칸이고 헤드리스 커서는 좌상단이라 발 칸의 ↖가 잡힌다).
	m.player.position = m._tile_center_px(t + Vector2i(1, 1))
	await process_frame
	await process_frame
	_check("⑬c 무대: 화면이 사료풀 칸 %s를 겨눈다(겨눔 %s)" % [str(t), str(m._target)], m._target == t)
	var p: String = m.interact_prompt.text
	_check("⑬d 가득이면 프롬프트가 **동사를 약속하지 않는다** — 「%s」" % p,
		not p.contains("[좌클릭] 사료풀 베기") and p.contains("가득하다"))
	var before_energy: int = m.energy.current
	_clear_notices(m)
	m._use_tool()
	_check("⑬e 좌클릭도 **베지 않는다** — 혼력도 재생 노드도 그대로다(종전엔 둘 다 날아갔다)",
		m.forage.is_grown(t) and m.energy.current == before_energy
			and _notice_has(m, "여물광이 가득하다"))
	m.ranch._silo_hay = Ranch.SILO_CAP - 1
	var before2: int = m.ranch.silo_hay()
	_clear_notices(m)
	m._use_tool()
	_check("⑬f 대조군: 자리가 있으면 그대로 베어 건초가 든다(%d → %d단)" % [before2, m.ranch.silo_hay()],
		not m.forage.is_grown(t) and m.ranch.silo_hay() == before2 + 1)
	m.ranch._silo_hay = 0

# ── ⑭ #14 만석 알림 ↔ 이행 가능성 ────────────────────────────────────────────
func _check_animal_cap_notice(m: Node) -> void:
	print("⑭ #14 짐승 정원 만석 ↔ 지시의 이행 가능성")
	_check("⑭a 배선: 만석 알림이 **티어를 묻는다**(최고 티어에 «큰 …»을 안 시킨다)",
		_count_in(_src, "func _try_buy_animal", "ranch.tier_of(bld) >= Ranch.TIER_BIG") == 1)
	var species := ""
	for id in AnimalCatalog.ids():
		if AnimalCatalog.buy_price(id) > 0:
			species = id
			break
	_check("⑭b 무대: 살 수 있는 종 «%s»를 찾았다" % species, species != "")
	if species == "":
		return
	var bld: String = m._animal_building_of(species)
	m.ranch.upgrade_building(bld)                      # 「큰 …」을 이미 지은 세이브
	var need: int = m.ranch.capacity_of(bld) - m.ranch.occupancy_of(bld)
	var placed: Array = []
	var y := 60
	while need > 0:
		var slot := Vector2i(60, y)
		if m.ranch.add_animal(slot, species, bld, 0):
			placed.append(slot)
			need -= 1
		y += 1
		if y > 90:
			break
	_check("⑭c 무대: %s가 최고 티어·만석이다 (%d/%d)"
			% [bld, m.ranch.occupancy_of(bld), m.ranch.capacity_of(bld)],
		m.ranch.tier_of(bld) >= Ranch.TIER_BIG and m.ranch.is_full(bld))
	_clear_notices(m)
	m._try_buy_animal(species)
	_check("⑭d 최고 티어에서는 **이행 불가능한 지시를 안 낸다**(«큰 …» 0 · 사실을 말한다)",
		_notice_has(m, "이미 최대 크기라") and not _notice_has(m, "「큰 "))
	for slot in placed:
		m.ranch._animals.erase(slot)
	m.ranch._tiers.erase(bld)
	_clear_notices(m)
	m.ranch.add_animal(Vector2i(60, 91), species, bld, 0)
	var need2: int = m.ranch.capacity_of(bld) - m.ranch.occupancy_of(bld)
	var placed2: Array = []
	var y2 := 92
	while need2 > 0 and y2 < 110:
		var slot2 := Vector2i(60, y2)
		if m.ranch.add_animal(slot2, species, bld, 0):
			placed2.append(slot2)
			need2 -= 1
		y2 += 1
	m._try_buy_animal(species)
	_check("⑭e 대조군: 기본 티어 만석에서는 종전 지시 그대로다(«큰 …»을 지어라)",
		_notice_has(m, "「큰 "))
	for slot in placed2:
		m.ranch._animals.erase(slot)
	m.ranch._animals.erase(Vector2i(60, 91))
