extends SceneTree
# ★[폴리시 24회차] 버그 헌트 확정분 회귀 — 배치 A(#0~#10).
#
# 렌즈: R23 diff 리뷰(#0·#1·#2) · Dictionary/해시 결정성(#3·#4·#5) · 운의 실효 진실(#6~#10).
#
# 이 배치의 태도 셋.
#   ㉠ **판정은 축별로 묻는다.** #0은 R23이 «두 축 다 무효»라는 AND로 좁혀 놓은 술어의 사각이다 —
#      되감기 칸에서 성장촉진군이 건드릴 수 있는 축은 품질 하나이고 그쪽으로는 강등밖에 못 하므로,
#      물어야 할 것은 «양쪽 다»가 아니라 «들어오는 것의 군» 하나였다. 그래서 ①은 기존 비료가
#      품질군인 무대(R23이 못 보던 자리)에서 잰다.
#   ㉡ **통계가 아니라 순수 함수를 잰다.** #8은 종전 회귀(luck_forecast ②-③)가 부호만 보고 크기를
#      안 봐서 살아남은 결함이라, 확률을 `MobCatalog.effective_chance` 한 줄로 끌어내 **운의 눈금이
#      두 하늘에서 같은지**를 직접 잰다(⑨c). #6도 같은 이유로 `_geode_double_effective`를 잰다.
#   ㉢ **분포는 실측으로 못 박는다.** #3·#4·#5는 "믹싱을 썼다"가 아니라 «가로 줄무늬가 사라졌는가»·
#      «다섯 좌석이 다섯 얼굴이 되는 날이 있는가»·«같은 종이 둘 서는 밤이 있는가»를 잰다. 좌표·
#      로스터 크기는 전부 상수에서 판다(옮겨 적기 0).
#
# 무엇을 보증하나(번호 = 24회차 헌트 발견 인덱스).
#   ① #0 `fertilize_sealed_no_op`이 «들어오는 것도 기존 것도 STATE_NONE»이라, 되감기 칸에 깔린
#      디럭스(120냥) 위에 하이퍼(100냥)를 덮는 조합만 열려 있었다 — 속도 축은 봉인이라 이득 0,
#      품질 축은 DELUXE → NONE 강등, 알림은 침묵. R23이 막으려던 것보다 나쁜 형제였다.
#   ② #1 R23 #14의 «넘치면 접는다»가 스택 높이의 암묵적 천장(4 × ROW_H = 88px)을 없애, 3줄짜리
#      띠 넷(264px)이 예약 영역(236px)을 넘어 화면 밖·상단 HUD 위로 올라갔다.
#   ③ #2 R23 #4가 «그날 주운 책도 pool에 남긴다»로 분모를 굳힌 뒤, 그 책이 그날의 당첨이 되면
#      보부상의 **유일한** 귀물 슬롯이 «이미 되찾음»으로 잠긴 죽은 행이 됐다(그날 귀물 재고 0).
#   ④ #3 `species_at_tile`이 raw `hash % 3` — djb2 선형성 때문에 수종이 y의 함수로 굳어 안식·미혹의
#      **가로 34줄이 전부 한 종**이었다(채취기 수액·씨앗 드랍이 지도 가로 띠로 갈렸다).
#   ⑤ #4 익명 손님 상이 raw `hash % N` — 좌석 5개의 잔여가 고정 오프셋으로 잠겨 800표본에서 배치가
#      8가지뿐이고 x=11·x=19가 800일 전부 같은 얼굴, 서로 다른 상 수가 매일 정확히 4였다.
#   ⑥ #5 밤 바 잡귀가 raw `hash % 3` — 시드가 스폿 인덱스 한 글자만 달라 %3이 강제 회전했고
#      400일 중 301일(75.25%)이 같은 줄, 같은 종이 둘 서는 밤은 한 번도 없었다.
#   ⑦ #6 발굴자(lvl10 «산출 2배» = 퍼크 1.0)가 대흉 날 운에 0.95로 깎여, 형제 둘이 명문 계약으로
#      든 「운은 확정 롤을 못 깬다」가 지오드 지점에서만 없었다.
#   ⑧ #7 벌목 ④의 씨앗 축이 `luck_bonus > 0.0`이라 **길한 쪽만** 배선 — 대흉 날이 평(운 0) 날과
#      한 톨도 다르지 않아, 제로평균 보정이 아니라 대길에만 얹히는 순증이었다.
#   ⑨ #8 잡귀 드랍이 `(base + 운) × 날씨`라, 대수적으로 운이 날씨 배수에 함께 곱해졌다 — 계수 표가
#      절대 눈금으로 선언한 ±5%p가 혼불 바람 날 ±10%p로 튀었다(형제 다섯은 전부 평 가산).
#   ⑩ #9 [삽사리] 만점 여부가 **라이브**라, 우정 992로 대흉 아침에 거울을 본 뒤 낮에 쓰다듬으면
#      같은 달력 날짜가 행동 순서에 따라 두 등급을 가졌다(R22 하늘 굳히기의 운 축 형제 부재).
#   ⑪ #10 luck_forecast ⑥d의 전건(「◇ 밖 네 줄은 수치를 안 담는다」)이 R22 #13의 ※ 문턱 단서 줄에
#      깨졌고, 고정 표본이 그 줄이 뜨는 날을 통째로 빠뜨려 red가 안 났을 뿐이었다.
#
# 판정: #0~#10 **전부 CONFIRMED**(11건 전부 봉합 · REFUTED·DUP·OWNER 0).
#
# 하중 검증(**실측** — 봉합을 되돌려 실제로 뜬 red를 그대로 옮겨 적는다. 파괴 11배치 전건 확인):
#   #0  술어에 `and state_of(기존) == NONE` 복귀   → ①c·①d red(술어 false·반환 true → 비료가 「fert_hyper」로 덮이고 임계는 12 그대로)
#   #1  `layout`의 `RESERVE_TOP` 가지 삭제         → ②c·②d·②g red(큐 4개가 **4개 다** 서고 스택 264px가 예약 164px를 넘는다)
#   #2  `if not owned_books.has(bid)` 삭제         → ③c·③d red(kind가 **ped_book** 그대로 = 손에 쥔 그 책이 잠긴 채 유일 귀물 슬롯을 먹는다)
#   #3  `rand_from_seed` → raw hash 복귀           → ④a·④c·④d red(한 종만 선 가로줄 **home 34/34 · mihok 34/34** · 분포 비 1.29)
#   #4  `_anon_guest_index`를 raw hash로 복귀      → ⑤a·⑤c·⑤d·⑤e red(배치 **8가지** · 다섯 얼굴인 날 **0일** · x11≡x19 **800/800일**)
#   #5  `_jobgui_index`를 raw hash로 복귀          → ⑥a·⑥c·⑥d·⑥e red(조합 **3가지** · 최빈 **301/400 = 75.2%** · 같은 종 둘인 밤 **0밤**)
#   #6  `_geode_double_effective`의 확정 가지 삭제  → ⑦e red(대흉 날 실효 **0.9505**)
#   #7  `luck_bonus > 0.0` 복귀                    → ⑧a·⑧c·⑧e red(대흉 씨앗 합 **291 = 평 날과 같다** · 대흉 보정 0)
#   #8  `(base + luck) * scale` 복귀               → ⑨c red(운 요동 평온 0.080 ↔ 혼불 바람 **0.160**)
#   #9  `_luck_floor_on`의 굳은 가지 삭제           → ⑩e·⑩f red(같은 날 가산이 −0.0990 → **−0.0690**, 거울이 「흉」으로 갈린다)
#   #10 ⑥d 표본에서 `hint_day` 제거                → ⑪e red. 그리고 **luck_forecast ⑥d 자체**의 전건도 실증했다 —
#       ※ 스킵을 지우고 그 날을 표본에 두면 ⑥d가 「누출: day 24 — ※ … 오늘 카페 1단을 넘기면 …」으로 적색이다.
#
# ★하중 검증에서 배운 것 둘.
#   · **분포 단언은 «시드 문자열까지» 그리기와 같은 줄을 봐야 한다.** ⑤·⑥의 첫 판은 회귀가 시드를
#     스스로 조립해 `_seeded_pick`에 넣었는데, 그러면 `_draw_*`만 raw hash로 되돌려도 분포 단언 여섯이
#     **전부 초록으로 남았다**(배선 니들 하나만 빨개졌다). 뽑기를 `_anon_guest_index`·`_jobgui_index`로
#     끌어내 그리기와 회귀가 같은 한 줄을 부르게 하고 나서야 파괴가 분포까지 물었다. R23 ⑬이 폭에
#     대해 세운 «재는 값 = 그리는 값»을 시드에도 적용한 것이고, ②a가 같은 규율을 알림 피드에 건다.
#   · **유품은 분모에서 빼야 한다.** ⑦f의 첫 판은 「1.0에선 1개가 0회」였는데 400개봉 중 29회가 유품이라
#     확정 확률에서도 1개다(`open_geode`가 `_is_relic`을 먼저 뺀다 = 설계). 분모를 유품 아닌 개봉으로
#     좁히고 나서야 «0.95는 13회 · 1.0은 0회»라는 진짜 대비가 나왔다.
#
# 실행: ./run_tests.sh polish_r24   (헤드리스는 반드시 game/에서 · 순차)

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

# ── 소스 스캔 헬퍼(polish_r7~r23 관례 — 니들은 반드시 함수 안에서 센다) ──────
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

# 이름 길이를 재는 아이템 로스터 — **카탈로그 상수에서 조립한다**(polish_r23 ⑬과 같은 창구).
func _catalog_roster() -> Array:
	var out: Array = []
	out.append_array(ItemCatalog.RARECROWS)
	for d in [ItemCatalog.RELICS, ItemCatalog.FORAGEABLES, ItemCatalog.MATERIALS,
			ItemCatalog.MINERALS, ItemCatalog.POT_GOODS, ItemCatalog.PLACEABLES]:
		out.append_array(d.keys())
	return out

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ 폴리시 R24 회귀 — 배치 A(#0~#10) ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()
	_src = _lines_of_file("res://main.gd")
	_check("무대 전제: main(%d행)을 읽었다(부정 단언 공허 통과 방지)" % _src.size(), _src.size() > 1000)

	# 무대 불요(순수 상태·정적 카탈로그)를 먼저 — main 부팅 비용을 안 낸다.
	_check_fertilize_axis()          # ① #0
	_check_peddler_dead_rare()       # ③ #2
	_check_species_mixing()          # ④ #3
	_check_mob_luck_order()          # ⑨ #8
	_check_chop_seed_symmetry()      # ⑧ #7

	var m: Node = await _spawn_main()
	_check("무대: main이 섰다", m != null)
	if m == null:
		quit(1)
		return
	_dismiss_dialogue(m)

	_check_notice_stack(m)           # ② #1
	_check_guest_anon_spread(m)      # ⑤ #4
	_check_jobgui_spread(m)          # ⑥ #5
	_check_geode_certain(m)          # ⑦ #6
	_check_luck_floor_seal(m)        # ⑩ #9
	_check_mirror_hint_layer(m)      # ⑪ #10

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# ── ① #0 되감기 칸의 비료 거절은 «들어오는 군» 하나로 정해진다 ────────────────
# 순수 FarmField로 잰다(무대 불요). 수치·id는 전부 카탈로그에서 판다.
func _check_fertilize_axis() -> void:
	print("① #0 되감기 칸 ↔ 성장촉진군이 품질군을 덮는다")
	var f := FarmField.new()
	var t := Vector2i(4, 4)
	var crop := CropCatalog.BULSAGWA
	var base := CropCatalog.growth_days(crop)
	f.hoe(t)
	f.plant(t, crop)
	# 품질군(디럭스)을 깔고 성숙·수확 → 되감기 사이클 진입. R23의 무대(무비료/성장촉진)와 갈린다.
	f.fertilize(t, FertilizerCatalog.FERT_DELUXE)
	for _i in range(base + 2):
		f.water(t)
		f.advance_day()
	_check("①a 무대: 「%s」를 디럭스 비료로 키워 수확 → 되감기 사이클(넝쿨 보존)"
			% ItemCatalog.name_of(ItemCatalog.harvest_id(crop)),
		f.harvest(t) == crop and f.is_planted(t)
			and f.fertilizer_of(t) == FertilizerCatalog.FERT_DELUXE)
	var need_before: int = f.effective_growth_days(t)
	_check("①b 무대: 그 칸의 품질 축이 살아 있다 — state 「%s」(roll_quality가 읽는 그 값)"
			% FertilizerCatalog.state_of(f.fertilizer_of(t)),
		FertilizerCatalog.state_of(f.fertilizer_of(t)) == FertilizerCatalog.STATE_DELUXE)
	# 핵심: 기존 비료가 품질군이어도 성장촉진군 도포는 거절된다(R23 술어는 여기서 false를 냈다).
	var no_op: bool = f.fertilize_sealed_no_op(t, FertilizerCatalog.FERT_HYPER)
	var applied: bool = f.fertilize(t, FertilizerCatalog.FERT_HYPER)
	_check("①c 하이퍼(성장촉진군) 도포가 **거절된다** — 술어 %s · 반환 %s(호출부가 이 false로 차감을 멈춘다)"
			% [str(no_op), str(applied)], no_op and not applied)
	_check("①d 거절이라 디럭스가 살아남는다 — 비료 「%s」 · 임계 %d(도포 전 %d)"
			% [f.fertilizer_of(t), f.effective_growth_days(t), need_before],
		f.fertilizer_of(t) == FertilizerCatalog.FERT_DELUXE
			and f.effective_growth_days(t) == need_before)
	# 강등의 실체 — 두 표가 실제로 다르다(카탈로그 파생: NONE 행의 이리듐 비중은 0이다).
	var deluxe_row: Array = FertilizerCatalog.QUALITY_TABLE[FertilizerCatalog.STATE_DELUXE]
	var none_row: Array = FertilizerCatalog.QUALITY_TABLE[FertilizerCatalog.STATE_NONE]
	_check("①e 그 거절이 지킨 것 — DELUXE 표는 이리듐 %d%% · NONE 표는 %d%%(덮였다면 잃을 값)"
			% [int(deluxe_row[3]), int(none_row[3])],
		int(deluxe_row[3]) > 0 and int(none_row[3]) == 0)
	# R23이 이미 막던 형제(무비료 되감기 칸)는 그대로 거절된다 — 봉합이 범위를 좁히지 않았다.
	var f2 := FarmField.new()
	var t2 := Vector2i(5, 5)
	f2.hoe(t2)
	f2.plant(t2, crop)
	for _j in range(base + 2):
		f2.water(t2)
		f2.advance_day()
	f2.harvest(t2)
	_check("①f R23이 막던 형제(무비료 되감기 칸)도 그대로 거절된다(범위가 안 좁아졌다)",
		f2.fertilize_sealed_no_op(t2, FertilizerCatalog.FERT_HYPER)
			and not f2.fertilize(t2, FertilizerCatalog.FERT_HYPER))
	# 정상 경로 불변 — 품질군은 되감기 칸에서도 통과한다(그 축은 실효한다).
	_check("①g 품질군은 여전히 통과한다 — 무비료 되감기 칸에 디럭스가 실린다(정상 경로 불변)",
		not f2.fertilize_sealed_no_op(t2, FertilizerCatalog.FERT_DELUXE)
			and f2.fertilize(t2, FertilizerCatalog.FERT_DELUXE)
			and f2.fertilizer_of(t2) == FertilizerCatalog.FERT_DELUXE)
	f.free()
	f2.free()

# ── ② #1 알림 스택이 예약 영역을 안 넘는다(무손실) ───────────────────────────
func _check_notice_stack(m: Node) -> void:
	print("② #1 알림 스택 하한 ↔ 무손실")
	var feed: NoticeFeed = m.notice_feed
	if feed == null:
		_check("②x 무대 없음(notice_feed null)", false)
		return
	var src := _lines_of_file("res://notice_feed.gd")
	_check("②a 배선: `_draw`가 기하를 스스로 다시 재지 않고 `layout` 하나만 소비한다(재는 값 = 그리는 값)",
		_count_in(src, "func _draw()", "layout(font, view)") == 1
			and _count_in(src, "func _draw()", "_wrapped_rows(") == 0
			and _count_in(src, "func _draw()", "RESERVE_BOTTOM") == 0)
	# 문구는 손으로 안 짓는다 — main이 실제로 쏘는 형태(만재 안내 + 카탈로그 최장 이름)를 조립한다.
	var longest := ""
	for id in _catalog_roster():
		var nm := ItemCatalog.name_of(String(id))
		if nm.length() > longest.length():
			longest = nm
	var text := "발밑에 무언가 걸린다 — 백팩이 가득 차 %s 캘 수 없다 ([Tab] 가방에서 자리를 비우고 다시)" \
		% HanjiUi.with_eul(longest)
	feed._items.clear()
	for i in range(NoticeFeed.MAX_ITEMS):
		feed.push(text, 5.0)
	var font := HanjiUi.font()
	var view := Vector2(640, 360)
	var avail := NoticeFeed.MAX_W - 16.0
	var rows: int = feed._wrapped_rows(font, text, avail)
	var stack_h := NoticeFeed.ROW_H * float(rows) * float(NoticeFeed.MAX_ITEMS)
	var room := view.y - NoticeFeed.RESERVE_BOTTOM - NoticeFeed.RESERVE_TOP
	_check("②b 무대: 그 문구가 %d줄로 접히고 %d띠를 쌓으면 %.0fpx — 예약 영역 %.0fpx를 넘는다"
			% [rows, NoticeFeed.MAX_ITEMS, stack_h, room], rows >= 2 and stack_h > room)
	var slots := feed.layout(font, view)
	var top_ok := true
	var bottom_ok := true
	for s in slots:
		var p: Vector2 = s["pos"]
		if p.y < NoticeFeed.RESERVE_TOP:
			top_ok = false
		if p.y + float(s["h"]) > view.y - NoticeFeed.RESERVE_BOTTOM:
			bottom_ok = false
	_check("②c 그린 띠가 전부 예약 영역 안이다 — 위 %.0fpx 아래 %.0fpx 경계(상단 HUD·핫바 침범 0)"
			% [NoticeFeed.RESERVE_TOP, view.y - NoticeFeed.RESERVE_BOTTOM], top_ok and bottom_ok)
	_check("②d 넘치는 띠는 **안 그린다** — 큐 %d개 중 %d개만 선다"
			% [feed._items.size(), slots.size()],
		slots.size() < feed._items.size() and slots.size() > 0)
	_check("②e **무손실** — 안 그린 띠가 큐에 그대로 남아 있다(자르지도, 버리지도 않았다) — 큐 %d개"
			% feed._items.size(), feed._items.size() == NoticeFeed.MAX_ITEMS)
	_check("②f 최신(배열 끝)은 언제나 맨 아래에 선다 — 첫 슬롯 idx %d / 큐 마지막 idx %d"
			% [int(slots[0]["idx"]), feed._items.size() - 1],
		int(slots[0]["idx"]) == feed._items.size() - 1)
	# 앞의 띠가 시간으로 사라지면 밀려 있던 것이 그대로 되돌아온다(무손실의 실체).
	# 되돌아올 후보 = 숨은 것 중 **가장 최근**(스택은 최신부터 아래에서 위로 찬다).
	var hidden_idx := -1
	var shown: Dictionary = {}
	for s2 in slots:
		shown[int(s2["idx"])] = true
	for i2 in range(feed._items.size() - 1, -1, -1):
		if not shown.has(i2):
			hidden_idx = i2
			break
	feed._items.remove_at(feed._items.size() - 1)   # 최신 한 줄이 시간으로 사라진다
	var slots2 := feed.layout(font, view)
	var back := false
	for s3 in slots2:
		if int(s3["idx"]) == hidden_idx:
			back = true
	_check("②g 최신이 사라지면 밀려 있던 띠(idx %d)가 다시 선다 — 그린 %d개 → %d개(잃은 줄 0)"
			% [hidden_idx, slots.size(), slots2.size()],
		hidden_idx >= 0 and back and slots2.size() == slots.size())
	feed._items.clear()

# ── ③ #2 보부상 귀물 슬롯이 죽은 행으로 서지 않는다 ──────────────────────────
func _check_peddler_dead_rare() -> void:
	print("③ #2 보부상 귀물 슬롯 ↔ 그날 다른 창구로 주운 책")
	var all_ids := Books.all_ids()
	var book_day := -1
	for d in range(1, 400):
		if d % Peddler.APPEAR_MODULUS != 0:
			continue
		if String(Peddler.rare_row(d, [], {}).get("kind", "")) == Peddler.KIND_BOOK:
			book_day = d
			break
	_check("③a 무대: day %d의 희귀 슬롯이 책 갈래다(날짜를 손으로 안 적는다)" % book_day, book_day > 0)
	if book_day <= 0:
		return
	var morning := Peddler.rare_row(book_day, [], {})
	var win_id := String(morning.get("buy_id", ""))
	_check("③b 무대: 그 아침의 당첨 책은 「%s」다" % Books.title_of(win_id), win_id != "")
	# ㉠ 당첨 책을 그날 다른 창구(갱도 돌 드랍·미혹 채집 — 하루 한 점 잠금이 없는 곳)로 줍는다.
	var got_winner := {win_id: book_day}
	var after := Peddler.rare_row(book_day, [], got_winner)
	_check("③c 당첨 책을 손에 쥐면 그 행이 **책 갈래가 아니다** — kind 「%s」(죽은 「이미 되찾음」 행 0)"
			% String(after.get("kind", "")), String(after.get("kind", "")) != Peddler.KIND_BOOK)
	_check("③d 그 자리는 비지 않는다 — 폴백 「%s」가 선다(방문일의 유일한 귀물 슬롯이 안 사라진다)"
			% ItemCatalog.name_of(String(after.get("buy_id", ""))),
		not after.is_empty() and String(after.get("buy_id", "")) != ""
			and String(after.get("buy_id", "")) != win_id)
	# ㉡ R23 #4의 결정성 계약 — **다른** 책을 주워도 당첨 id가 안 갈린다.
	var other := ""
	for id in all_ids:
		if String(id) != win_id:
			other = String(id)
			break
	var after_other := Peddler.rare_row(book_day, [], {other: book_day})
	_check("③e R23 #4 불변 — 다른 책(「%s」)을 주워도 당첨은 그대로 「%s」(분모·인덱스 롤 불침범)"
			% [Books.title_of(other), Books.title_of(String(after_other.get("buy_id", "")))],
		String(after_other.get("buy_id", "")) == win_id)
	# ㉢ 재굴림 수단이 아니다 — 대체행은 day 순수 폴백이라 어느 책을 주웠든 답이 하나다.
	var second := ""
	for id in all_ids:
		if String(id) != win_id and String(id) != other:
			second = String(id)
			break
	var swap_a := Peddler.rare_row(book_day, [], {win_id: book_day})
	var swap_b := Peddler.rare_row(book_day, [], {win_id: book_day, second: book_day})
	_check("③f 재굴림 수단이 아니다 — 무엇을 더 주워도 대체행이 같다(day 순수 폴백) 「%s」"
			% ItemCatalog.name_of(String(swap_a.get("buy_id", ""))),
		String(swap_a.get("buy_id", "")) == String(swap_b.get("buy_id", "")))
	# ㉣ 어제까지 주운 책은 종전대로 분모에서 빠진다(과잉 고정이 아니다 — R23 ⑤e와 같은 축).
	_check("③g 어제 주운 책은 그대로 미보유 풀에서 빠진다 — 아침 풀 %d권 ↔ 어제 취득 반영 %d권"
			% [Peddler.remaining_books({other: book_day}, book_day).size(),
				Peddler.remaining_books({other: book_day - 1}, book_day).size()],
		Peddler.remaining_books({other: book_day}, book_day).size() == all_ids.size()
			and Peddler.remaining_books({other: book_day - 1}, book_day).size() == all_ids.size() - 1)

# ── ④ #3 수종이 좌표 전체에 고르게 흩어진다 ──────────────────────────────────
func _check_species_mixing() -> void:
	print("④ #3 혼의 나무 수종 ↔ 해시 믹싱")
	var src := _lines_of_file("res://tree_ledger.gd")
	_check("④a 배선: `species_at_tile`이 프로젝트 관례(`rand_from_seed` 믹싱)를 탄다 — raw `hash(...) %` 0자리",
		_count_in(src, "static func species_at_tile", "rand_from_seed(hash(") == 1
			and _count_in(src, "static func species_at_tile", "abs(hash(") == 0)
	var n_sp := TreeLedger.SPECIES.size()
	var worst_uniform := 0
	var per_region := PackedStringArray()
	var counts_all: Dictionary = {}
	# 구역 목록은 원장의 모드 규칙이 아는 셋 — 여기 이름을 손으로 안 적는다.
	for region in [RegionCatalog.HOME, RegionCatalog.JEOSEUNG_FOREST, RegionCatalog.MIHOK_FOREST]:
		var uniform := 0
		for y in range(10, 44):
			var seen: Dictionary = {}
			for x in range(0, 64):
				var sp := TreeLedger.species_at_tile(String(region), Vector2i(x, y))
				seen[sp] = true
				counts_all[sp] = int(counts_all.get(sp, 0)) + 1
			if seen.size() == 1:
				uniform += 1
		per_region.append("%s %d/34" % [String(region), uniform])
		worst_uniform = maxi(worst_uniform, uniform)
	_check("④b 무대: 종이 %d가지고 64×34 스윕을 세 구역에서 돌렸다(칸 %d개)"
			% [n_sp, int(counts_all.values().reduce(func(a, b): return a + b, 0))],
		n_sp >= 3 and counts_all.size() == n_sp)
	_check("④c **가로 줄무늬가 없다** — 한 종만 선 가로줄 %s(봉합 전 안식·미혹이 34/34였다)"
			% " · ".join(per_region), worst_uniform == 0)
	var lo := 1 << 30
	var hi := 0
	for sp2 in counts_all.keys():
		var c := int(counts_all[sp2])
		lo = mini(lo, c)
		hi = maxi(hi, c)
	_check("④d 분포가 고르다 — 최다 %d ↔ 최소 %d(비 %.2f · 봉합 전 896/640 = 1.40)"
			% [hi, lo, float(hi) / maxf(float(lo), 1.0)], float(hi) / maxf(float(lo), 1.0) < 1.20)
	_check("④e 결정성 불변 — 같은 좌표는 늘 같은 종이다(세이브 없이 재현되는 그 계약)",
		TreeLedger.species_at_tile(RegionCatalog.HOME, Vector2i(7, 13))
			== TreeLedger.species_at_tile(RegionCatalog.HOME, Vector2i(7, 13)))
	# 세이브 정합 — 이미 놓인 나무·이미 박힌 채취기는 종을 **저장**하므로 안 바뀐다.
	var tsrc := _lines_of_file("res://tapper_ledger.gd")
	_check("④f 이미 놓인 것은 안 바뀐다 — 원장은 칸마다 species를 저장하고(to_save), 채취기는 설치 시점의 종을 스냅한다",
		_count_in(src, "func to_save", "e.get(\"species\", \"\")") == 1
			and _count_in(tsrc, "func to_save", "e.get(\"species\", \"\")") == 1)

# ── ⑤ #4 카페 익명 손님 상이 좌석마다 갈린다 ─────────────────────────────────
func _check_guest_anon_spread(m: Node) -> void:
	print("⑤ #4 익명 손님 상 ↔ 좌석 간 붕괴")
	_check("⑤a 배선: 그리기와 회귀가 **같은 한 줄**을 본다 — `_draw_guest_figure`는 `_anon_guest_index`만 부르고, 그 창구가 믹싱을 탄다(raw `hash(` 0자리)",
		_count_in(_src, "func _draw_guest_figure", "_anon_guest_index(") == 1
			and _count_in(_src, "func _draw_guest_figure", "hash(") == 0
			and _count_in(_src, "func _anon_guest_index", "_seeded_pick(") == 1)
	var seats: Array = m.SEAT_TILES
	var n_anon: int = m.GUEST_ANON.size()
	var combos: Dictionary = {}
	var full_days := 0
	var twin_days := 0
	for salt in [0, 1]:
		for day in range(1, 401):
			var picks: Array = []
			for t in seats:
				picks.append(m._anon_guest_index(salt, day, t))
			combos[str(picks)] = true
			var uniq: Dictionary = {}
			for p in picks:
				uniq[p] = true
			if uniq.size() == seats.size():
				full_days += 1
			if picks[0] == picks[seats.size() - 1]:
				twin_days += 1
	_check("⑤b 무대: 좌석 %d석 · 익명 상 %d종 · 800표본(day 1..400 × salt 0/1)"
			% [seats.size(), n_anon], seats.size() == 5 and n_anon >= 6)
	_check("⑤c 배치가 흩어진다 — 800표본에서 %d가지(봉합 전 **8가지**)" % combos.size(),
		combos.size() > 500)
	_check("⑤d 다섯 좌석이 다섯 얼굴인 날이 실제로 있다 — %d일(봉합 전 **0일** · 매일 정확히 4가지였다)"
			% full_days, full_days > 0)
	_check("⑤e 첫 좌석 %s과 끝 좌석 %s이 같은 날이 800일 중 %d일(봉합 전 **800일** = 늘 같은 얼굴)"
			% [str(seats[0]), str(seats[seats.size() - 1]), twin_days],
		twin_days > 0 and twin_days < 400)

# ── ⑥ #5 밤 바 잡귀 종이 스폿마다 갈린다 ─────────────────────────────────────
func _check_jobgui_spread(m: Node) -> void:
	print("⑥ #5 밤 바 잡귀 상 ↔ 강제 회전")
	_check("⑥a 배선: 그리기와 회귀가 **같은 한 줄**을 본다 — `_draw_jobgui`는 `_jobgui_index`만 부르고, 그 창구가 믹싱을 탄다(raw `hash(` 0자리)",
		_count_in(_src, "func _draw_jobgui", "_jobgui_index(") == 1
			and _count_in(_src, "func _draw_jobgui", "hash(") == 0
			and _count_in(_src, "func _jobgui_index", "_seeded_pick(") == 1)
	var spots: Array = m.NIGHT_SPOT_TILES
	var kinds: Array = m._BAR_JOBGUI
	var combos: Dictionary = {}
	var twin_nights := 0
	for day in range(1, 401):
		var picks: Array = []
		for i in range(spots.size()):
			picks.append(m._jobgui_index(day, i))
		combos[str(picks)] = int(combos.get(str(picks), 0)) + 1
		var uniq: Dictionary = {}
		for p in picks:
			uniq[p] = true
		if uniq.size() < picks.size():
			twin_nights += 1
	_check("⑥b 무대: 스폿 %d개 · 종 %d가지(조합 상한 %d) · 400밤 표본"
			% [spots.size(), kinds.size(), int(pow(kinds.size(), spots.size()))],
		spots.size() == 3 and kinds.size() == 3)
	_check("⑥c 조합이 회전 셋에 갇히지 않는다 — %d가지(봉합 전 **3가지** = 회전뿐)" % combos.size(),
		combos.size() > 20)
	var top := 0
	for k in combos.keys():
		top = maxi(top, int(combos[k]))
	_check("⑥d 최빈 조합이 지배하지 않는다 — %d/400 = %.1f%%(봉합 전 301일 = **75.2%%**)"
			% [top, float(top) / 4.0], float(top) / 400.0 < 0.20)
	_check("⑥e 같은 종이 둘 서는 밤이 있다 — %d밤(봉합 전 400밤 동안 **0밤**)" % twin_nights,
		twin_nights > 0)

# ── ⑦ #6 확정 퍼크는 운에 안 깎인다 ─────────────────────────────────────────
func _check_geode_certain(m: Node) -> void:
	print("⑦ #6 발굴자 확정 퍼크 ↔ 명부의 운")
	# 대흉 날을 판에서 찾는다(날짜를 손으로 안 적는다).
	var bad_day := -1
	for d in range(1, 500):
		if DailyLuck.grade_for_day(d) == DailyLuck.TERRIBLE:
			bad_day = d
			break
	m.clock.day = bad_day
	var luck: float = m._luck_bonus(DailyLuck.W_GEODE)
	_check("⑦a 무대: day %d는 대흉이고 지오드 축 가산이 음수다 — %.4f" % [bad_day, luck],
		bad_day > 0 and luck < 0.0)
	# 확정 퍼크를 든 전문직을 **카탈로그에서 판다**(id·값을 손으로 안 적는다).
	var certain_id := ""
	var certain_tier := 0
	var perk := 0.0
	for prof in ProfessionCatalog.professions_for(ProfessionCatalog.MINING):
		for pk in prof.get("perks", []):
			if String(pk.get("dim", "")) == ProfessionCatalog.DIM_GEODE_DOUBLE:
				certain_id = String(prof["id"])
				certain_tier = int(prof["tier"])
				perk = float(pk.get("value", 0.0))
	_check("⑦b 무대: 「%s」(tier %d)의 지오드 퍼크 값이 카탈로그상 확정(1.0)이다 — %.2f"
			% [certain_id, certain_tier, perk], certain_id != "" and perk >= 1.0)
	# 퍼크 미보유 = 운이 그대로 실린다(음수라 실효 0으로 클램프될 뿐 — 면제가 아니다).
	var without: float = m._geode_double_effective()
	_check("⑦c 퍼크가 없으면 운은 그대로 실린다 — 실효 %.4f(면제가 아니다)" % without,
		is_equal_approx(without, m.geode_double_chance() + luck))
	# 퍼크 보유(확정) = 운이 못 깎는다.
	var prof0: Variant = m._professions.get(ProfessionCatalog.MINING, {})
	m._professions[ProfessionCatalog.MINING] = {certain_tier: certain_id}
	_check("⑦d 무대: 그 전문직을 찍어 `geode_double_chance()`가 확정 1.0이다 — %.2f"
			% m.geode_double_chance(), m.geode_double_chance() >= 1.0)
	_check("⑦e **확정은 운에 안 깎인다** — 대흉 날 실효 %.4f(봉합 전 **0.95** = 5%%의 개봉이 1개였다)"
			% m._geode_double_effective(), m._geode_double_effective() >= 1.0)
	# 그 0.95가 실제로 손해였다는 실체 — 같은 롤을 두 확률로 굴려 산출을 센다.
	# ★ 유품은 **정의상** 2개가 안 된다(`open_geode`가 `_is_relic`을 먼저 뺀다) — 그래서 분모를
	#   유품이 아닌 개봉으로 좁힌다. 그 안에서 0.95는 실제로 1개를 내고 1.0은 한 번도 안 낸다.
	var non_relic := 0
	var singles := 0
	var singles_certain := 0
	for i in range(400):
		var r095: Dictionary = MiningSkill.open_geode(ItemCatalog.GEODE_NEOKAL, i, 0.95)
		var r100: Dictionary = MiningSkill.open_geode(ItemCatalog.GEODE_NEOKAL, i, 1.0)
		if ItemCatalog._is_relic(String(r100.get("id", ""))):
			continue                       # 유품 개봉 — 두 확률 어느 쪽에서도 2개가 아니다
		non_relic += 1
		if int(r095.get("count", 0)) == 1:
			singles += 1
		if int(r100.get("count", 0)) == 1:
			singles_certain += 1
	_check("⑦f 그 5%%p가 실손해였다 — 유품 아닌 개봉 %d회 중 0.95는 %d회가 1개, 1.0은 %d회(확정은 전량 2개)"
			% [non_relic, singles, singles_certain],
		non_relic > 300 and singles > 0 and singles_certain == 0)
	# 형제 둘이 같은 가드를 든다(정렬 증거).
	var msrc := _lines_of_file("res://mine_floors.gd")
	_check("⑦g 형제 정렬 — 사다리(`c >= 1.0` 조기 반환)·잡귀 드랍(`base >= 1.0` 면제)이 같은 문법을 든다",
		_count_in(msrc, "static func ladder_chance", "if c >= 1.0:") == 1
			and _count_in(_lines_of_file("res://mob_catalog.gd"),
				"static func effective_chance", "if base >= 1.0:") == 1)
	m._professions[ProfessionCatalog.MINING] = prof0

# ── ⑧ #7 벌목 씨앗 축이 양방향이다 ──────────────────────────────────────────
func _check_chop_seed_symmetry() -> void:
	print("⑧ #7 벌목 씨앗 ↔ 대흉")
	var src := _lines_of_file("res://tree_ledger.gd")
	_check("⑧a 배선: 씨앗 갈래가 부호를 안 가린다 — `luck_bonus > 0.0` 단락이 사라졌다",
		_count_in(src, "func chop", "luck_bonus > 0.0 and rng.randf()") == 0
			and _count_in(src, "func chop", "is_zero_approx(luck_bonus)") == 1)
	var luck_up := DailyLuck.bonus_for_day(_grade_day(DailyLuck.GREAT), DailyLuck.W_CHOP)
	var luck_dn := DailyLuck.bonus_for_day(_grade_day(DailyLuck.TERRIBLE), DailyLuck.W_CHOP)
	_check("⑧b 무대: 대길 가산 %+.3f · 대흉 가산 %+.3f(계수 표 W_CHOP %.1f 파생)"
			% [luck_up, luck_dn, DailyLuck.W_CHOP], luck_up > 0.0 and luck_dn < 0.0)
	var s_zero := _chop_seeds(0.0)
	var s_up := _chop_seeds(luck_up)
	var s_dn := _chop_seeds(luck_dn)
	_check("⑧c **대흉 날엔 씨앗이 준다** — 평 %d ↔ 대흉 %d(봉합 전 두 값이 **같았다**)"
			% [s_zero, s_dn], s_dn < s_zero)
	_check("⑧d 대길 축은 그대로다(종전 거동 불변) — 평 %d ↔ 대길 %d" % [s_zero, s_up], s_up > s_zero)
	_check("⑧e 보정이 대칭에 가깝다 — 대길 +%d · 대흉 %d(한쪽만 얹히는 순증이 아니다)"
			% [s_up - s_zero, s_dn - s_zero],
		absi((s_up - s_zero) - (s_zero - s_dn)) <= maxi(1, (s_up - s_zero) / 2))
	# 하한 — 씨앗이 음수로 안 간다(운이 새 산출 규칙을 만들지 않는다).
	var floor_ok := true
	var led := TreeLedger.new()
	for i in range(120):
		var t := Vector2i(i % 30, 20 + i / 30)
		led._put(RegionCatalog.HOME, t, {"species": TreeLedger.SP_PINE, "stage": 1,
			"hp": 1, "stump": false, "moss": false})
		var res := led.chop(RegionCatalog.HOME, t, 1, 1, 0, 0.0, 0, luck_dn)
		if int(res.get("seeds", 0)) < 0:
			floor_ok = false
	_check("⑧f 하한 — 대흉에도 씨앗이 음수로 안 간다(유목 120그루 전수)", floor_ok)

# 그 등급이 서는 첫 날(날짜를 손으로 안 적는다).
func _grade_day(grade: int) -> int:
	for d in range(1, 800):
		if DailyLuck.grade_for_day(d) == grade:
			return d
	return 1

# 성숙목 N그루를 같은 시드 판에서 베어 씨앗 총합을 센다(운만 갈아 끼운다 = 순수 비교).
func _chop_seeds(luck: float) -> int:
	var led := TreeLedger.new()
	var total := 0
	for i in range(300):
		var t := Vector2i(i % 30, 5 + i / 30)
		led._put(RegionCatalog.JEOSEUNG_FOREST, t,
			{"species": TreeLedger.SP_PINE, "stage": TreeLedger.MAX_STAGE, "hp": 1,
			"stump": false, "moss": false})
		var res := led.chop(RegionCatalog.JEOSEUNG_FOREST, t, 1, TreeLedger.SEED_LEVEL, 0, 0.0, 0, luck)
		total += int(res.get("seeds", 0))
	return total

# ── ⑨ #8 운의 눈금이 날씨 배수를 안 탄다 ────────────────────────────────────
func _check_mob_luck_order() -> void:
	print("⑨ #8 잡귀 드랍 ↔ 운 × 날씨 순서")
	var src := _lines_of_file("res://mob_catalog.gd")
	_check("⑨a 배선: 확률이 `effective_chance` 한 줄에서만 나온다(계약과 코드가 갈릴 자리 0)",
		_count_in(src, "static func roll_drops", "effective_chance(base, scale, luck_bonus)") == 1
			and _count_in(src, "static func roll_drops", "(base + luck_bonus)") == 0)
	var base := 0.10
	var luck := DailyLuck.bonus_for_day(_grade_day(DailyLuck.GREAT), DailyLuck.W_MOB_DROP)
	var calm_span := MobCatalog.effective_chance(base, 1.0, luck) \
		- MobCatalog.effective_chance(base, 1.0, -luck)
	var wind_span := MobCatalog.effective_chance(base, Weather.SOULWIND_RARE, luck) \
		- MobCatalog.effective_chance(base, Weather.SOULWIND_RARE, -luck)
	_check("⑨b 무대: 대길 가산 %+.3f · 혼불 바람 희귀 배수 ×%.1f" % [luck, Weather.SOULWIND_RARE],
		luck > 0.0 and Weather.SOULWIND_RARE > 1.0)
	_check("⑨c **운의 눈금이 하늘에 안 곱해진다** — 평온 요동 %.3f ↔ 혼불 바람 요동 %.3f(봉합 전 0.10 ↔ **0.20**)"
			% [calm_span, wind_span], is_equal_approx(calm_span, wind_span))
	_check("⑨d 날씨는 여전히 base를 키운다 — base %.2f → 혼불 바람 %.2f(배수 축 불변)"
			% [base, MobCatalog.effective_chance(base, Weather.SOULWIND_RARE, 0.0)],
		is_equal_approx(MobCatalog.effective_chance(base, Weather.SOULWIND_RARE, 0.0),
			base * Weather.SOULWIND_RARE))
	_check("⑨e 확정 드랍은 운도 배수도 안 탄다 — 대흉 + 혼불 바람에서도 %.2f"
			% MobCatalog.effective_chance(1.0, Weather.SOULWIND_RARE, -luck),
		is_equal_approx(MobCatalog.effective_chance(1.0, Weather.SOULWIND_RARE, -luck), 1.0))
	_check("⑨f 무운·무배수 호출은 base 그대로(기존 결과열 불변)",
		is_equal_approx(MobCatalog.effective_chance(base, 1.0, 0.0), base))
	# 계수 표가 선언한 절대 눈금과 실제 요동이 같다(±weight × luck).
	_check("⑨g 계수 표의 약속과 실측이 같다 — W_MOB_DROP %.1f · 요동 %.3f = 2 × %+.3f"
			% [DailyLuck.W_MOB_DROP, calm_span, luck], is_equal_approx(calm_span, luck * 2.0))

# ── ⑩ #9 그날의 운은 그 아침에 굳는다 ───────────────────────────────────────
func _check_luck_floor_seal(m: Node) -> void:
	print("⑩ #9 [삽사리] 운 하한 ↔ 하루 굳히기")
	_check("⑩a 배선: 하늘을 굳히는 그 아침 자리에서 운 하한도 함께 굳는다(형제 두 칸이 나란하다)",
		_count_in(_src, "func _on_day_advanced", "_luck_floor_sealed_day = day") == 1
			and _count_in(_src, "func _on_day_advanced", "_weather_sealed_day = day") == 1)
	_check("⑩b 배선: 세이브에 실린다 — F9·재부팅 뒤에도 같은 날은 같은 답(하늘 두 칸과 같은 결)",
		_count_in(_src, "func _save_game", "\"luck_floor_sealed_day\":") == 1
			and _count_in(_src, "func _load_game", "data.get(\"luck_floor_sealed_day\"") == 1)
	var bad_day := -1
	for d in range(1, 500):
		if DailyLuck.grade_for_day(d) == DailyLuck.TERRIBLE:
			bad_day = d
			break
	m.clock.day = bad_day
	# 그 아침 = 미만점(하한 미적용)으로 굳는다.
	m.pet.load_save({"adopted": true, "friend": Pet.FRIEND_MAX - 1})
	m._luck_floor_sealed_day = bad_day
	m._luck_floor_sealed = m.pet.luck_floor_active()
	var bonus_morning: float = m._luck_bonus(DailyLuck.W_LADDER)
	var mirror_morning: String = m._mirror_forecast_text()
	_check("⑩c 무대: day %d 아침 — 대흉이고 [삽사리]는 아직 만점이 아니다(하한 미적용으로 굳었다)"
			% bad_day,
		not m._luck_floor_sealed and mirror_morning.contains(DailyLuck.GRADE_NAMES[DailyLuck.TERRIBLE]))
	# 낮에 쓰다듬어 만점을 채운다 — 라이브 입력이 실제로 뒤집힌다.
	m.pet.load_save({"adopted": true, "friend": Pet.FRIEND_MAX})
	_check("⑩d 무대: 낮에 만점이 됐다(라이브 입력은 실제로 참이 됐다)", m.pet.luck_floor_active())
	_check("⑩e **같은 날의 답이 안 바뀐다** — 가산 %+.4f 그대로(봉합 전 이 프레임부터 −0.069로 갈렸다)"
			% m._luck_bonus(DailyLuck.W_LADDER),
		is_equal_approx(m._luck_bonus(DailyLuck.W_LADDER), bonus_morning))
	_check("⑩f 거울도 아침의 등급을 말한다 — 「%s」(화면과 실제 확률이 안 어긋난다)"
			% DailyLuck.GRADE_NAMES[DailyLuck.TERRIBLE],
		m._mirror_forecast_text().contains(DailyLuck.GRADE_NAMES[DailyLuck.TERRIBLE])
			and DailyLuck.grade_for_day(bad_day, m._pet_luck_floor()) == DailyLuck.TERRIBLE)
	# 다음 아침에 굳으면 그때부터 든다(보상이 사라지지 않는다 — 하루 늦게 들 뿐).
	m._luck_floor_sealed_day = bad_day
	m._luck_floor_sealed = true
	_check("⑩g 다음 아침에 굳으면 그때부터 든다 — 등급 「%s」(보상은 사라지지 않고 하루 늦게 든다)"
			% DailyLuck.GRADE_NAMES[DailyLuck.grade_for_day(bad_day, m._pet_luck_floor())],
		DailyLuck.grade_for_day(bad_day, m._pet_luck_floor()) == DailyLuck.BAD
			and m._luck_bonus(DailyLuck.W_LADDER) > bonus_morning)
	# 다른 날(예보·미래)은 종전대로 라이브로 판다 — 굳을 것이 없다.
	_check("⑩h 다른 날을 물으면 종전대로 라이브다(예보엔 굳을 것이 없다)",
		m._luck_floor_on(bad_day + 1) == m.pet.luck_floor_active())
	# 구세이브(키 없음) 하위호환 — 굳은 값이 없으면 라이브로 떨어진다.
	m._luck_floor_sealed_day = 0
	_check("⑩i 구세이브·부팅 첫날은 라이브 폴백(거동 불변 · 다음 아침에 굳는다)",
		m._pet_luck_floor() == m.pet.luck_floor_active())

# ── ⑪ #10 ⑥d 가드의 전건이 다시 참이다 ──────────────────────────────────────
func _check_mirror_hint_layer(m: Node) -> void:
	print("⑪ #10 점괘 거울 ※ 문턱 층 ↔ ⑥d 전건")
	var hint_day := -1
	var slot := Festival.NONE
	for d in range(1, 200):
		var s: int = Festival.theme_slot_for_day(d + 1)
		if s != Festival.NONE and not m._theme_open_on(d + 1):
			hint_day = d
			slot = s
			break
	_check("⑪a ※ 문턱 단서가 실제로 뜨는 날이 있다 — day %d(비해금 테마 슬롯 전날)" % hint_day,
		hint_day > 0)
	if hint_day <= 0:
		return
	m.clock.day = hint_day
	var txt: String = m._mirror_forecast_text()
	var hint_line := ""
	var other_digits := ""
	for raw in txt.split("\n"):
		var line := String(raw)
		if line.begins_with("※"):
			hint_line = line
			continue
		if line.begins_with("◇") or line.strip_edges() == "":
			continue
		for ci in range(line.length()):
			var ch := line[ci]
			if ch >= "0" and ch <= "9" and other_digits == "":
				other_digits = line
	_check("⑪b 그 줄은 ◇로 시작하지 않는다 — 「%s」(⑥d의 «◇만 걷어내면 된다»가 깨져 있던 실체)"
			% hint_line, hint_line != "" and not hint_line.begins_with("◇"))
	var has_digit := false
	for ci2 in range(hint_line.length()):
		var c2 := hint_line[ci2]
		if c2 >= "0" and c2 <= "9":
			has_digit = true
	_check("⑪c 그 줄은 **언제나** 숫자를 문다(`Festival.unlock_hint`가 문턱을 싣는다) — 「%s」"
			% Festival.unlock_hint(slot),
		has_digit and Festival.unlock_hint(slot) != "" and hint_line.contains(Festival.unlock_hint(slot)))
	_check("⑪d 그 날에도 운은 한 글자도 안 샌다 — ◇·※ 밖 본문의 숫자 %s"
			% ("없음" if other_digits == "" else "누출: " + other_digits), other_digits == "")
	var lsrc := _lines_of_file("res://playtest/luck_forecast_test.gd")
	_check("⑪e ⑥d 표본이 그 날을 **실제로 지난다**(고정 표본이 통째로 빠뜨리던 자리)",
		_count_in(lsrc, "func _initialize", "sample_days.append(hint_day)") == 1
			and _count_in(lsrc, "func _initialize", "line.begins_with(\"※\")") == 1)
