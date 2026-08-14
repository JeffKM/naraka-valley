extends SceneTree
# ★[S10-T10] 엔드게임 세로 스모크 — **한 세이브가 Slice 10 전 사슬을 관통**한다.
#
# 선례를 둘 승계한다: S8-T10(`s8_relationship_smoke_test.gd`)이 관계 사슬을, S9b-T10
# (`s9b_spine_smoke_test.gd`)이 척추 사슬을 각각 "한 판에서 결정적으로" 굴린 그 규범이다.
# 이번에 관통하는 축은 **엔드게임 롱테일**이다 — 서로 다른 아홉 태스크(T1~T9)가 붙인 층들이
# *같은 저장 파일 위에서* 순서대로 서는가.
#
# 무엇을 보증하나(이음매 전용 — 개별 계약의 상세 단언은 각 스위트가 소유한다):
#   ① 팬닝·결정기(T1) — 물가에서 인 사금이 지갑에 얹히고, 세운 결정기가 **날을 건너** 여문다.
#   ② 보부상(T3) — 7의 배수 아침에 봇짐이 서고, 표시가 = 결제가로 물건이 손에 들어온다.
#   ③ 마구간·먹갈기(T4) — 목공방 주문 → 완공 아침 휘파람 → [F] 승마 → 계수가 플레이어에 실린다.
#   ④ 삽사리(T4) — 마을 진입 이벤트 1회 → 집 앞 두 창구가 **혼력 0**으로 우정을 올린다.
#   ⑤ 카페 3단(T5) — 누적 매출이 문턱을 넘으면 「저승의 명소」가 서고 **늘봄방 잠금이 걷힌다**.
#   ⑥ 늘봄방·스프링클러 상위 티어(T5·T2) — 3단이 연 그 건축이 서고, 티어3이 5×5를 적신다.
#   ⑦ 화분(T5) — 실내 소품이 서고 그 안에서 작물이 자란다(스프링클러가 못 닿는 별개 층).
#   ⑧ ★절기 전환 관통 — 같은 아침에 **늘봄방 작물은 살고 노지 대조군은 스러진다**(㉠ 면제 실증).
#   ⑨ 동행 혼(T4) — 혼례 → 14일 → 취침 프레임 형상화. **14일이 실제로 흐른다**(하루씩 정산).
#   ⑩ 우편 첨부·레어크로우(T2) — 2종을 모으면 전령이 큐잉 → 다음 아침 도착 → 열면 ④가 들어온다.
#   ⑪ 도감(T6) — 출하함에 넣은 것이 **정산 아침에** 스스로 이름을 얻는다.
#   ⑫ 반딧넋(T7) — 라이브 [F] 안치 1 + 원장 충전으로 문턱 30 → 시련장 문이 그 자리에서 열린다.
#   ⑬ 시련장(T8) — 주간 시련을 다섯 주 연속 완주해 시련패를 벌고, 그 시련패로 레어크로우 ⑧을
#      산다 → **8종 완성 = 디럭스 반경**(획득처 8슬롯이 실제 세이브에서 닫힌다).
#   ⑭ 경지(T8) — 5스킬 만렙 위에 쌓인 초과 XP가 포인트가 되고 유물 5점이 백팩에 들어온다.
#   ⑮ 아트 패스(T9) — 이 세이브가 만든 물건들의 아이콘이 **색박스 폴백에 도달하지 않는다**.
#   ⑯ 세이브 왕복 — 위 열다섯 층이 전부 부팅을 건넌다(한 파일이 엔드게임을 통째로 기억한다).
#
# ★ 관례(기존 스모크 상속 — 어기지 말 것):
#   · 단언은 **카운트만 세지 않는다** — 구성 요소를 이름으로 짚는다(캠페인 교훈).
#   · 분모·총원은 레지스트리에서 파생한다(하드코딩 stale 금지).
#   · 하루를 넘길 땐 `_pass_day`(clock + `_on_day_advanced` + 판 비우기) 한 문을 쓴다.
#   · 헤드리스는 반드시 game/에서 · 순차 실행(save.dat 전역 공유).
#
# 실행: TIMEOUT=300 ./run_tests.sh s10_endgame_smoke   (실측 ~65초 — 기본 60초로는 아슬아슬하다)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	await process_frame
	return m

# 판을 비운다 — 컷신 재생 → 선택지는 첫 항 → 나머지는 넘기기(플레이어와 같은 경로).
func _drain(m: Node) -> void:
	var guard := 0
	while (m.cutscene != null or m.dialogue.is_open()) and guard < 3000:
		if m.cutscene != null:
			m._tick_cutscene(0.2)
		elif m.dialogue.has_choice():
			m.dialogue.choose(0)
		else:
			m.dialogue.advance()
		guard += 1

# 컷신만 끝까지 굴린다(뒤따르는 첫 줄을 재야 하므로 대화는 안 닫는다).
func _settle(m: Node) -> void:
	var guard := 0
	while m.cutscene != null and guard < 400:
		m._tick_cutscene(0.2)
		guard += 1

# 하루를 넘긴다 — 아침 정산 전량을 실제로 태우고 뜬 대화·컷신을 비운다.
func _pass_day(m: Node) -> void:
	m.clock.day += 1
	m._on_day_advanced(m.clock.day)
	_drain(m)

func _walk_to(m: Node, day: int) -> void:
	while m.clock.day < day:
		_pass_day(m)

# 다음 절기 첫날(greenhouse_test와 같은 파생식 — 날짜 하드코딩 0).
func _next_season_first(m: Node) -> int:
	return m.clock.day + (GameClock.DAYS_PER_SEASON - GameClock.day_of_season(m.clock.day) + 1)

func _slot_of(m: Node, id: String) -> int:
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == id:
			return i
	return -1

# 그 아이템을 손에 쥔다(없으면 하나 넣고 그 슬롯을 고른다).
func _hold(m: Node, id: String) -> bool:
	if not m.inventory.has_item(id):
		m.inventory.add_item(id, 1)
	var i := _slot_of(m, id)
	if i < 0:
		return false
	m.inventory.select(i)
	return true

# 지정한 것만 남기고 백팩을 비운다. ⚠️ 이게 없으면 스모크가 **오탐으로 실패한다**: 가방은
# Inventory.SIZE(16)칸뿐이고, 사슬이 길어지면 중간에 가득 차 "자리가 없으면 안 준다"는 각 시스템의
# **정상 계약**(경지 유물·시련패 매대·우편 첨부가 전부 그 규율을 공유한다)이 발동한다. 그러면
# 실패가 이음매의 결함이 아니라 가방 관리 문제를 가리키게 된다 — 관심사 밖의 물건은 쓰임이
# 끝난 자리에서 내려놓고, 자리 없음 계약 자체는 각 스위트가 따로 소유한다.
func _clear_except(m: Node, keep: Array) -> void:
	for i in Inventory.SIZE:
		var id: String = m.inventory.id_at(i)
		if id == "" or keep.has(id):
			continue
		m.inventory.remove_item(id, m.inventory.count_of(id))

func _free_slots(m: Node) -> int:
	var n := 0
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == "":
			n += 1
	return n

func _walkable(m: Node, t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= m._grid_w or t.y >= m._outdoor_h:
		return false
	return not m.is_solid(m._grid[t.y][t.x])

# 5스킬을 만렙(+초과)으로 세운다 — "엔드게임 세이브"의 전제. 적립 경로는 각 스킬 스위트 소관이다.
func _max_all_skills(m: Node, overflow_each: int) -> void:
	var xp := Mastery.max_level_xp() + overflow_each
	m._farming_xp = xp
	m._foraging_xp = xp
	m._fishing_xp = xp
	m._mining_xp = xp
	m._combat_xp = xp
	m._refresh_max_hp()

# 오늘 이후 첫 보부상 출현일 중 일반 슬롯에 그 kind 행이 실린 날(-1 = 못 찾음).
func _peddler_day_with(from_day: int, kind: String) -> int:
	var d: int = Peddler.next_open_day(from_day)
	for _i in 60:
		for r in Peddler.general_rows(d):
			if String((r as Dictionary)["kind"]) == kind:
				return d
		d += Peddler.APPEAR_MODULUS
	return -1

# 결정기·레어크로우를 놓을 수 있는 첫 칸(-1,-1 = 없음).
func _first_tile(m: Node, pred: String) -> Vector2i:
	for y in range(m._outdoor_h):
		for x in range(m._grid_w):
			var t := Vector2i(x, y)
			if bool(m.call(pred, t)):
				return t
	return Vector2i(-1, -1)


func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S10-T10 엔드게임 세로 스모크 — 팬닝 → … → 시련장 → 경지 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	var m: Node = await _new_main()
	_drain(m)                                  # 신규 시작의 앵커 통보 대화
	m.onboarding.step = Onboarding.DONE
	m._sleeping = false
	m.clock.minutes = 10 * 60                  # 영업창 밖(카페 틱이 판을 안 흔들게)

	# ── ⓪ 셋업 = 만렙 근접 엔드게임 세이브 ────────────────────────────────────
	print("── ⓪ 셋업(5스킬 만렙 · 자산) ──")
	_max_all_skills(m, 0)
	m.wallet.gold = 500000
	m.inventory.add_item(ItemCatalog.WOOD, 900)
	m.inventory.add_item(ItemCatalog.INGOT_YUCHEOL, 10)
	# 보부상 출현일이자 삽사리 문턱(%d일) 이후인 첫 아침으로 시계를 세운다 — 이후로는 하루씩만 흐른다.
	var start_day := _peddler_day_with(Pet.ADOPT_MIN_DAY, Peddler.KIND_ITEM)
	_check("⓪a 시작일 = 보부상 출현일이면서 삽사리 문턱 이후다(day %d)" % start_day,
		start_day > 0 and Peddler.is_open_day(start_day) and start_day >= Pet.ADOPT_MIN_DAY)
	m.clock.day = start_day
	_check("⓪b 5스킬 전부 만렙 = [경지]가 열려 있다(초과 XP 0이라 포인트는 아직 0)",
		m.mastery_open() and m.mastery_overflow() == 0
		and Mastery.pending_skills(m._skill_level_map()).is_empty())
	_check("⓪c 아직 아무 층도 안 섰다 — 늘봄방·시련장·먹갈기·삽사리·동행 혼 전부 0",
		not m._greenhouse_built() and not m.trial_ground_open()
		and not m.mount.is_mounted() and not m.pet.is_adopted() and not m._soul_born
		and m.codex.shipped_count() == 0 and m.fireflies.collected_count() == 0)

	# ── ① 팬닝 · 결정기(T1) ───────────────────────────────────────────────────
	print("── ① 팬닝 · 결정기 ──")
	m._rebuild_region(RegionCatalog.SAMDOCHEON)
	m._indoor = ""
	var spot: Vector2i = PanningSpots.candidates(RegionCatalog.SAMDOCHEON)[0]
	m.panning.load_save({"spots": {RegionCatalog.SAMDOCHEON: [[spot.x, spot.y]]}})
	m.energy.current = SoulEnergy.MAX
	var gold_before: int = m.wallet.gold
	var e_before: int = m.energy.current
	_check("①a 삼도천 물가에 사금 자리가 섰다(걸을 수 있고 물가다)",
		m.panning.has_at(RegionCatalog.SAMDOCHEON, spot)
		and _walkable(m, spot) and m._is_waterside(spot))
	m._pan_spot(spot)
	_check("①b [F] 채취 — 혼력 %d 차감 · 자리 소진 · 산출이 지갑이나 가방에 얹혔다"
			% PanningSpots.PAN_ENERGY,
		m.energy.current == e_before - PanningSpots.PAN_ENERGY
		and not m.panning.has_at(RegionCatalog.SAMDOCHEON, spot))
	_check("①c 채취가 조용히 사라지지 않았다(냥이 늘었거나 원장이 자리를 지웠다)",
		m.wallet.gold >= gold_before and m.panning.total() == 0)
	# 결정기 — 안식 농원에 세우고 넋수정을 물린다(여무는 것은 아래 아침들이 확인한다).
	m._rebuild_region(RegionCatalog.HOME)
	var cry_tile := _first_tile(m, "_can_place_crystalarium")
	_check("①d 결정기를 놓을 빈 지면이 있다", cry_tile != Vector2i(-1, -1))
	m.inventory.add_item(ItemCatalog.CRYSTALARIUM, 1)
	m._place_crystalarium(cry_tile)
	m.inventory.add_item(ItemCatalog.GEM_NEOKSUJEONG, 1)
	_hold(m, ItemCatalog.GEM_NEOKSUJEONG)
	m._use_crystalarium(cry_tile)
	_check("①e 넋수정 투입 — %d일 카운트다운이 걸렸다"
			% CrystalariumLedger.days_for(ItemCatalog.GEM_NEOKSUJEONG),
		m.crystalarium.is_growing(RegionCatalog.HOME, cry_tile)
		and m.crystalarium.gem_at(RegionCatalog.HOME, cry_tile) == ItemCatalog.GEM_NEOKSUJEONG)

	# ── ② 저승 보부상(T3) ────────────────────────────────────────────────────
	print("── ② 저승 보부상 ──")
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	m._indoor = ""
	m._sleeping = false
	m._target = m.get_script().get_script_constant_map()["PEDDLER_TILE"]
	_check("②a 출현일 · 나루 마을 야외 · 그 칸 = 좌판이 선다", m._facing_peddler())
	var ped_rows: Array = m._peddler_items()
	var buy_row: Dictionary = {}
	for r in ped_rows:
		if String((r as Dictionary)["kind"]) == Peddler.KIND_ITEM:
			buy_row = r
			break
	_check("②b 봇짐이 %d행(일반 %d + 가구 1 + 희귀 1)이고 그중 일반 품목이 잡힌다"
			% [ped_rows.size(), Peddler.STOCK_SLOTS],
		ped_rows.size() == Peddler.TOTAL_ROWS and not buy_row.is_empty())
	var ped_id := String(buy_row["buy_id"])
	var ped_price := int(buy_row["price"])
	var ped_have: int = m.inventory.count_of(ped_id)
	var ped_gold: int = m.wallet.gold
	m._on_frame_buy_store_item(ped_id, Peddler.KIND_ITEM, false)
	_check("②c ★표시가 = 결제가 — %s 를 %d냥에 샀다(웃돈 얹은 값 그대로)"
			% [ItemCatalog.name_of(ped_id), ped_price],
		m.inventory.count_of(ped_id) == ped_have + 1 and m.wallet.gold == ped_gold - ped_price)

	# ── ③ 마구간 · 먹갈기(T4) ────────────────────────────────────────────────
	print("── ③ 마구간 → 휘파람 → 승마 ──")
	m._rebuild_region(RegionCatalog.HOME)
	m._indoor = ""
	var wid := ItemCatalog.MOUNT_WHISTLE
	var ingot_before: int = m.inventory.count_of(ItemCatalog.INGOT_YUCHEOL)
	_check("③a 마구간 주문 성립 — 골드·원목·주괴 전액 즉시 지불",
		m._try_order_build(Carpenter.PROJ_STABLE)
		and m.carpenter.active_id() == Carpenter.PROJ_STABLE
		and m.inventory.count_of(ItemCatalog.INGOT_YUCHEOL)
			== ingot_before - Carpenter.ingot_cost(Carpenter.PROJ_STABLE))
	_check("③b 완공 전에는 휘파람이 없다", not m.inventory.has_item(wid))
	for _i in Carpenter.build_days(Carpenter.PROJ_STABLE):
		_pass_day(m)
	_check("③c 완공 아침 = 원장 done + 휘파람 증정(안방 확장과 같은 자리의 id 분기)",
		m.carpenter.is_done(Carpenter.PROJ_STABLE) and m.inventory.has_item(wid))
	# ★ 같은 아침들이 결정기도 굴렸다 — 세운 기계가 날을 건너 여문다(①의 지연 확인).
	_check("①f ★결정기가 날을 건너 여물었다(아침 정산이 카운트다운을 실제로 깎는다)",
		m.crystalarium.is_ready(RegionCatalog.HOME, cry_tile))
	var gem_before: int = m.inventory.count_of(ItemCatalog.GEM_NEOKSUJEONG)
	m._use_crystalarium(cry_tile)
	_check("①g 수거 = 복제본 1개 · 원본은 남아 즉시 재가동",
		m.inventory.count_of(ItemCatalog.GEM_NEOKSUJEONG) == gem_before + 1
		and m.crystalarium.is_growing(RegionCatalog.HOME, cry_tile))
	# 승마 — 야외에서 [F], 계수가 플레이어에 실린다.
	m._region = RegionCatalog.HOME
	m._indoor = ""
	_hold(m, wid)
	var e_ride: int = m.energy.current
	m._toggle_mount()
	m._sync_mount()
	_check("③d [F] 소환 — 탔고 속도 계수 ×%.1f가 플레이어에 실렸다 · 혼력 무과금"
			% Mount.SPEED_SCALE,
		m.mount.is_mounted() and is_equal_approx(m.player.speed_scale, Mount.SPEED_SCALE)
		and m.energy.current == e_ride)

	# ── ④ 삽사리(T4) ─────────────────────────────────────────────────────────
	print("── ④ 삽사리 입양 · 돌봄 ──")
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	_check("④a 마을을 세우는 프레임에 이벤트가 예약된다(문턱 이후)", m._pet_event_armed)
	m._fire_pet_event()
	_check("④b 워프 연출이 걷힌 뒤 소비 = 입양(예약은 내려간다)",
		m.pet.is_adopted() and not m._pet_event_armed)
	m._rebuild_region(RegionCatalog.HOME)
	m._indoor = ""
	m._sleeping = false
	var e_pet: int = m.energy.current
	m._target = m.PET_TILE
	_check("④c 삽사리 칸을 겨누면 창구가 선다", m._facing_pet())
	m._pet_sapsari()
	m._target = m.PET_BOWL_TILE
	m._fill_pet_bowl()
	_check("④d 쓰다듬 +%d · 물그릇 +%d = 우정 %d · ★혼력 한 톨도 안 든다(코지 리추얼)"
			% [Pet.F_PET, Pet.F_BOWL, m.pet.friendship()],
		m.pet.friendship() == Pet.F_PET + Pet.F_BOWL and m.energy.current == e_pet)
	# 승마 상태는 구역을 옮겨도 야외인 한 살아 있다(③의 지속 확인).
	m._sync_mount()
	_check("③e 구역을 옮겨도 야외면 계속 타고 있다(강제 하차 0)", m.mount.is_mounted())

	# ── ⑤ 카페 3단 「저승의 명소」(T5) ────────────────────────────────────────
	print("── ⑤ 카페 3단 ──")
	var rows_before: Array = m._build_rows()
	var gh_locked_before := false
	for r in rows_before:
		if String((r as Dictionary)["buy_id"]) == Carpenter.PROJ_GREENHOUSE:
			gh_locked_before = bool((r as Dictionary).get("locked", false))
	_check("⑤a 3단 전 — 늘봄방 행이 '카페 3단 필요'로 잠겨 있다", gh_locked_before)
	_check("⑤b 3단 전 결제 경로도 막는다(프레임 신호 불신)",
		not m._try_order_build(Carpenter.PROJ_GREENHOUSE) and not m.carpenter.is_active())
	m._run_harvested = CafeMilestone.S2_TARGET_HARVEST
	m._cafe_revenue_total = CafeMilestone.S3_TARGET_REVENUE
	m.affinity.stage = 5
	m.affinity.points = 5 * Affinity.POINTS_PER_HEART
	m.mel_affinity.stage = 5
	m.mel_affinity.points = 5 * Affinity.POINTS_PER_HEART
	_check("⑤c 누적 매출 %d 도달 → 3단 「저승의 명소」(축 = 서빙 매출 단독)"
			% CafeMilestone.S3_TARGET_REVENUE,
		m._cafe_stage() == CafeMilestone.STAGE_3 and m._milestone_stage3_complete()
		and CafeMilestone.greenhouse_unlocked(m._cafe_stage()))

	# ── ⑥ 늘봄방 + 스프링클러 상위 티어(T5·T2) ───────────────────────────────
	print("── ⑥ 늘봄방 건축 · 티어3 스프링클러 ──")
	_check("⑥a 3단이 열자 곧바로 주문이 성립한다(같은 매대·같은 결제 경로)",
		m._try_order_build(Carpenter.PROJ_GREENHOUSE)
		and m.carpenter.active_id() == Carpenter.PROJ_GREENHOUSE)
	for _i in Carpenter.build_days(Carpenter.PROJ_GREENHOUSE):
		_pass_day(m)
	_check("⑥b 완공 — 건물 카탈로그에 늘봄방이 서고 둘째 경작면이 살아난다",
		m._greenhouse_built() and m._buildings.has("늘봄방")
		and m.greenhouse_farm != null and m.greenhouse_farm != m.farm)
	# 다음 절기에 스러질 작물을 고른다(대조군의 씨앗 — greenhouse_test와 같은 파생 선택).
	var next_season := (GameClock.season_index_for_day(m.clock.day) + 1) % 4
	var off_crop := ""
	for cid in CropCatalog.ids():
		var c := String(cid)
		if CropCatalog.is_multi_seasonal(c) or CropCatalog.is_wild(c):
			continue
		if not CropCatalog.in_season(c, next_season):
			off_crop = c
			break
	_check("⑥c 다음 절기에 스러질 작물을 하나 찾았다(%s)" % off_crop, off_crop != "")
	var gh_tile: Vector2i = m.GREENHOUSE_PLOT_RECT.position + Vector2i(1, 1)
	_check("⑥d 늘봄방 칸을 괭이질하고 **절기와 무관하게** 파종한다",
		m.greenhouse_farm.hoe(gh_tile) and m.greenhouse_farm.plant(gh_tile, off_crop))
	# 티어3 스프링클러 — 5×5가 늘봄방 경작면을 적신다.
	var spr_tile: Vector2i = m.GREENHOUSE_PLOT_RECT.position + Vector2i(3, 3)
	m.inventory.add_item(ItemCatalog.SPRINKLER_T3, 1)
	_hold(m, ItemCatalog.SPRINKLER_T3)
	m._region = RegionCatalog.HOME
	_check("⑥e 늘봄방 경작면에 스프링클러를 세울 수 있다", m._can_place_sprinkler(spr_tile))
	m._place_sprinkler(spr_tile, ItemCatalog.SPRINKLER_T3)
	_check("⑥f ★든 아이템이 티어를 정한다 — 원장 티어3 · 급수 범위 %d칸(5×5)"
			% Sprinkler.range_size(Sprinkler.TIER_3),
		m.sprinkler.tier_at(spr_tile) == Sprinkler.TIER_3
		and m.sprinkler.targets_of(spr_tile).size() == Sprinkler.range_size(Sprinkler.TIER_3))
	_check("⑥g ★티어3 사거리가 늘봄방 파종 칸에 실제로 닿는다(티어1 십자로는 못 닿는 거리)",
		m.sprinkler.targets_of(spr_tile).has(gh_tile)
		and not Sprinkler.offsets_for(Sprinkler.TIER_1).has(gh_tile - spr_tile))

	# ── ⑦ 화분(T5) ───────────────────────────────────────────────────────────
	print("── ⑦ 화분 ──")
	var pot_tile := Vector2i(11, 72)          # 본가 실내 바닥(garden_pot_test와 같은 좌표)
	m._indoor = "집"
	m.inventory.add_item(ItemCatalog.GARDEN_POT, 1)
	m._target = pot_tile
	m._place_garden_pot(pot_tile)
	_check("⑦a 집 안 바닥에 화분이 섰다(실내 소품 — 바깥엔 못 놓는다)",
		m.garden_pot.has_at(pot_tile))
	_hold(m, ItemCatalog.seed_id(CropCatalog.HONRYEONGCHO))
	m._use_tool()
	_check("⑦b 씨앗을 들고 좌클릭 → 화분에 심긴다",
		m.garden_pot.crop_of(pot_tile) == CropCatalog.HONRYEONGCHO)
	_check("⑦c ★화분은 스프링클러 사슬 밖이다(그 칸엔 세울 수 없다 — 매일 손 물주기)",
		not m._can_place_sprinkler(pot_tile))
	m._indoor = ""

	# ── ⑧⑨⑩ 혼례 → 절기 전환 → 14일 → 형상화 · 그 사이에 전령이 다녀간다 ─────
	print("── ⑧⑨⑩ 혼례 · 절기 전환 · 동행 혼 · 우편 첨부 ──")
	# 여기까지의 자재·부산물은 쓰임이 끝났다 — 휘파람만 남기고 가방을 비운다(위 `_clear_except` 주석).
	_clear_except(m, [ItemCatalog.MOUNT_WHISTLE])
	_check("⑩⓪ 가방을 정리했다 — 남은 자리가 넉넉하다(%d칸 · 휘파람만 보존)" % _free_slots(m),
		_free_slots(m) >= 10 and m.inventory.has_item(ItemCatalog.MOUNT_WHISTLE))
	# 레어크로우 2종을 손에 넣는다(전령 큐잉 문턱 = %d종) — 획득처 상세는 rarecrow_test 소관.
	m.inventory.add_item(ItemCatalog.RARECROW_1, 1)
	m.inventory.add_item(ItemCatalog.RARECROW_2, 1)
	_check("⑩a 레어크로우 %d종 보유 = 전령 큐잉 문턱에 닿았다(수집 판정 = 소지 ∪ 배치)"
			% m.RARECROW_HERALD_THRESHOLD,
		m._rarecrow_collected() >= m.RARECROW_HERALD_THRESHOLD
		and m._rarecrow_owned(ItemCatalog.RARECROW_1) and m._rarecrow_owned(ItemCatalog.RARECROW_2))
	var wed_day: int = m.clock.day
	m._romance_partner = "mochi"
	m._wedding_day = wed_day
	m._advance_wedding(wed_day)
	_check("⑨a 혼례 아침 — 배우자가 서고 동행 혼 예정이 %d일 뒤로 잡힌다"
			% m.SOUL_CHILD_WAIT_DAYS,
		m._spouse_id == "mochi" and m._soul_due_day == wed_day + m.SOUL_CHILD_WAIT_DAYS)
	# 절기 전환일 하루 전까지 걸어가 **노지 대조군**을 심는다(까마귀·잡초에 먼저 먹히지 않게
	# 전환 직전에 심는 것이 대조의 정밀도다 — "스러졌다"의 사유를 절기 하나로 잠근다).
	var flip_day := _next_season_first(m)
	_walk_to(m, flip_day - 1)
	var ctl_tile: Vector2i = m.STARTER_PATCH_RECT.position
	m.farm.hoe(ctl_tile)
	_check("⑧a 전환 전날 — 노지 대조군을 같은 작물로 심었다(늘봄방 작물도 아직 살아 있다)",
		m.farm.plant(ctl_tile, off_crop) and m.greenhouse_farm.is_planted(gh_tile))
	_pass_day(m)
	_check("⑧b 오늘이 실제 절기 전환일이다(전제)", GameClock.is_season_first_day(m.clock.day))
	_check("⑧c ★같은 아침 — 늘봄방 작물은 **살아남고**(㉠ 면제) 노지 대조군은 스러진다",
		m.greenhouse_farm.is_planted(gh_tile)
		and m.greenhouse_farm.crop_of(gh_tile) == off_crop
		and not m.farm.is_planted(ctl_tile))
	# 전령 — 위 아침들 중 하나가 편지를 큐잉했고 그다음 아침에 꽂혔다. 열면 첨부가 들어온다.
	var crow4_before: int = m.inventory.count_of(ItemCatalog.RARECROW_4)
	_check("⑩b 전령이 다녀갔다 — 첨부 편지가 우편함에 미독으로 꽂혀 있다",
		m.mailbox.ever_sent(m.RARECROW_HERALD_LETTER)
		and not m.mailbox.is_read(m.RARECROW_HERALD_LETTER)
		and m.mailbox.has_unread())
	# 미독을 차례로 연다(가장 오래된 것부터 — 첨부 편지가 나올 때까지). 아직 안 꽂혔으면 아침을
	# 하루 더 흘린다(전령은 "오늘 큐 → 내일 도착"이라 도착 시점이 사슬 길이에 따라 하루 흔들린다).
	var guard_mail := 0
	while not m.mailbox.is_read(m.RARECROW_HERALD_LETTER) and guard_mail < 60:
		if m.mailbox.has_unread():
			m._read_next_letter()
			_drain(m)
		else:
			_pass_day(m)
		guard_mail += 1
	_check("⑩c ★읽는 순간 첨부가 백팩에 들어온다 — 레어크로우 ④(획득처 ④의 실효)",
		m.mailbox.is_read(m.RARECROW_HERALD_LETTER)
		and m.inventory.count_of(ItemCatalog.RARECROW_4) == crow4_before + 1)
	m._read_next_letter()
	_drain(m)
	_check("⑩d 재열람으로 두 번 나오지 않는다(기독 원장이 곧 지급 원장)",
		m.inventory.count_of(ItemCatalog.RARECROW_4) == crow4_before + 1)
	# 남은 날을 마저 걸어 예정일에 닿는다.
	_walk_to(m, wed_day + m.SOUL_CHILD_WAIT_DAYS)
	_check("⑨b 예정일 아침 = **예약만** 선다(재생은 눈뜨는 프레임 — B4·B7과 같은 두 단계)",
		m._soul_birth_armed and not m._soul_born and m.cutscene == null)
	m._sleeping = true
	m._on_sleep_done()
	_check("⑨c 눈을 뜨는 프레임에 형상화가 재생된다(탄생 확정 · 예약 소진)",
		m._soul_born and m.cutscene != null and not m._soul_birth_armed
		and m._soul_due_day == 0)
	_drain(m)
	var r_soul: Resident = m._resident(m.SOUL_CHILD_RID)
	m._region = RegionCatalog.HOME
	m._indoor = "집"
	m._sleeping = false
	m._update_resident_stations(0.0)
	m._target = m.SOUL_CHILD_TILE
	_check("⑨d 깃든 뒤 = 몸이 집 안에 서고 말을 걸 수 있다(관계 트랙 0 · 인사 한 종)",
		r_soul.node.visible and m._facing_resident() == r_soul and r_soul.affinity == null)
	m._indoor = ""

	# ── ⑪ 명부 도감(T6) ──────────────────────────────────────────────────────
	print("── ⑪ 명부 도감 등재 ──")
	m.ship_bin.pending.clear()
	var dex_crop := CropCatalog.HONRYEONGCHO
	m.inventory.add_harvest(dex_crop, 2)
	m._on_frame_deposit(_slot_of(m, ItemCatalog.harvest_id(dex_crop)))
	m.inventory.add_item(ItemCatalog.GEM_NEOKSUJEONG, 1)
	m._on_frame_deposit(_slot_of(m, ItemCatalog.GEM_NEOKSUJEONG))
	_check("⑪a 출하함에 작물·광물이 담겼다(정산 전에는 미등재 — 롤백 창이 아직 열려 있다)",
		m.ship_bin.count_of(ItemCatalog.harvest_id(dex_crop)) == 2
		and m.ship_bin.count_of(ItemCatalog.GEM_NEOKSUJEONG) == 1
		and not m.codex.is_shipped(ItemCatalog.harvest_id(dex_crop)))
	var dex_day: int = m.clock.day + 1
	_pass_day(m)
	_check("⑪b ★정산 아침에 두 칸이 스스로 이름을 얻는다(작물 · 광물) · 첫 출하 day 기록",
		m.codex.is_shipped(ItemCatalog.harvest_id(dex_crop))
		and m.codex.is_shipped(ItemCatalog.GEM_NEOKSUJEONG)
		and m.codex.category_shipped(Codex.CAT_CROP) >= 1
		and m.codex.category_shipped(Codex.CAT_MINERAL) >= 1
		and m.codex.first_day_of(ItemCatalog.GEM_NEOKSUJEONG) == dex_day)
	_check("⑪c 등재 이름이 도감 본문에 실제로 뜬다(카운트가 아니라 이름으로)",
		m.codex.category_names_shipped(Codex.CAT_CROP).has(CropCatalog.name_of(dex_crop))
		and m.codex.category_names_shipped(Codex.CAT_MINERAL).has(
			ItemCatalog.name_of(ItemCatalog.GEM_NEOKSUJEONG)))

	# ── ⑫ 반딧넋 45 → 문턱 30(T7) ────────────────────────────────────────────
	print("── ⑫ 반딧넋 안치 → 시련장 문턱 ──")
	m._rebuild_region(RegionCatalog.SAMDOCHEON)
	m._indoor = ""
	var ff_rows: Array = FireflySouls.spots_in(RegionCatalog.SAMDOCHEON)
	var ff_tile: Vector2i = (ff_rows[0] as Dictionary)["tile"]
	var ff_id := String((ff_rows[0] as Dictionary)["id"])
	var e_ff: int = m.energy.current
	m._gather_firefly(ff_tile)
	_check("⑫a 라이브 [F] 안치 — 원장에 즉시 앉는다 · 혼력 0(아이템 경유 0)",
		m.fireflies.is_collected(ff_id) and m.fireflies.collected_count() == 1
		and m.energy.current == e_ff)
	_check("⑫b 한 개로는 문이 안 열린다(문턱 %d — 남은 %d)"
			% [FireflySouls.GATE_COUNT, m.fireflies.remaining_to_gate()],
		not m.trial_ground_open() and not m._buildings.has("시련장"))
	# 나머지를 원장에 채운다(각 스폿의 실그리드 검증은 firefly_soul_test 소관 — 여기선 문턱만 넘긴다).
	for fid in FireflySouls.all_ids():
		if m.fireflies.collected_count() >= FireflySouls.GATE_COUNT:
			break
		m.fireflies.collect(String(fid), m.clock.day)
	m._refresh_trial_gate()
	_check("⑫c ★문턱 %d 도달 — 라이브 안치분을 **포함해** 문이 열리고 방이 카탈로그에 선다"
			% FireflySouls.GATE_COUNT,
		m.fireflies.collected_count() == FireflySouls.GATE_COUNT
		and m.fireflies.is_collected(ff_id)
		and m.trial_ground_open() and m._buildings.has("시련장"))
	var trial_b: Dictionary = m._buildings["시련장"]
	_check("⑫d 방 레코드 = 갱도 구역 · kind=trial · 2칸 문",
		String(trial_b["region"]) == RegionCatalog.EOPHWA_MINE
		and String(trial_b["kind"]) == "trial" and trial_b.has("ext_door2"))

	# ── ⑬ 명부 시련장 — 주간 시련 완주 → 시련패 → 레어크로우 ⑧(T8) ───────────
	print("── ⑬ 명부 시련장 · 시련패 상점 ──")
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	m._indoor = "시련장"
	var crow8_price := TrialGround.price_of(ItemCatalog.RARECROW_8)
	var fert_price := TrialGround.price_of(ItemCatalog.FERT_DELUXE)
	var weeks_needed: int = int(ceil(float(crow8_price + fert_price) / float(TrialGround.TOKEN_REWARD)))
	var kinds_seen: Dictionary = {}
	var week := TrialGround.week_of(m.clock.day) + 1
	for _w in weeks_needed:
		# ★ 주 경계만 건너뛴다 — 하루 정산은 위 사슬이 이미 관통했고, 시련 원장은 순수 day 파생이다.
		m.clock.day = week * 7 + 1
		m._use_trial_board()
		if not m.trial.is_active():
			week += 1
			continue
		kinds_seen[m.trial.kind_of_active()] = true
		var need: int = m.trial.required_count()
		if m.trial.kind_of_active() == TrialGround.KIND_SLAY:
			for _k in need:
				m._note_trial_kill()
		else:
			m.inventory.add_item(m.trial.required_item(), need)
		m._use_trial_board()
		week += 1
	_check("⑬a %d주 연속 완주 — 시련패 %d패 적립(주당 %d) · 완료 이력 %d건"
			% [weeks_needed, m.trial.tokens, TrialGround.TOKEN_REWARD, m.trial.completed_count()],
		m.trial.completed_count() == weeks_needed
		and m.trial.tokens == weeks_needed * TrialGround.TOKEN_REWARD
		and not m.trial.is_active())
	_check("⑬b ★두 유형이 실제로 등장했다(처치·납품 — 한쪽만 돌면 사슬의 절반이 안 굴러간 것)",
		kinds_seen.has(TrialGround.KIND_SLAY) and kinds_seen.has(TrialGround.KIND_DELIVER))
	_clear_except(m, [ItemCatalog.MOUNT_WHISTLE] + ItemCatalog.RARECROWS)
	var tok_before: int = m.trial.tokens
	m._try_buy_trial_item(ItemCatalog.FERT_DELUXE)
	_check("⑬c 편의 소모품은 반복 구매다(−%d패 · 이력 안 남김)" % fert_price,
		m.inventory.has_item(ItemCatalog.FERT_DELUXE)
		and m.trial.tokens == tok_before - fert_price
		and not m.trial.has_bought(ItemCatalog.FERT_DELUXE))
	m._try_buy_trial_item(ItemCatalog.RARECROW_8)
	_check("⑬d ★획득처 ⑧ — 벌어들인 시련패로 레어크로우 ⑧을 받았다(1회성 소진)",
		m.inventory.has_item(ItemCatalog.RARECROW_8)
		and m.trial.has_bought(ItemCatalog.RARECROW_8))
	m._try_buy_trial_item(ItemCatalog.RARECROW_8)
	_check("⑬e 재구매 차단(세상에 한 마리뿐)",
		m.inventory.count_of(ItemCatalog.RARECROW_8) == 1)
	# 8슬롯 완주 — 남은 종은 각 획득처 스위트 소관이라 직접 채운다. 여기서 재는 것은 **완성의 실효**다.
	for cid in ItemCatalog.RARECROWS:
		if not m._rarecrow_owned(String(cid)):
			m.inventory.add_item(String(cid), 1)
	_check("⑬f ★8종 완성 = 디럭스 반경 발효(%d → %d — 분모는 RARECROWS %d종 파생)"
			% [CrowRaid.BASE_RADIUS, CrowRaid.DELUXE_RADIUS, ItemCatalog.RARECROWS.size()],
		m._rarecrow_collected() == ItemCatalog.RARECROWS.size()
		and m._rarecrow_complete() and m._scarecrow_radius() == CrowRaid.DELUXE_RADIUS)

	# ── ⑭ 경지(T8) ───────────────────────────────────────────────────────────
	print("── ⑭ 경지 — 초과 XP → 포인트 → 유물 ──")
	# 유물 다섯 점이 들어올 자리를 비운다(수집물 8종·휘파람은 ⑯이 왕복으로 다시 잰다).
	_clear_except(m, [ItemCatalog.MOUNT_WHISTLE] + ItemCatalog.RARECROWS)
	var energy_cost_before: int = m._farming_energy_cost()
	var th: Array = Mastery.THRESHOLDS
	m._farming_xp = Mastery.max_level_xp() + int(th[th.size() - 1])
	_check("⑭a 만렙 위에 초과 XP가 쌓여 문턱 %d단을 넘겼다(가용 포인트 %d)"
			% [th.size(), m.mastery.available_points(m.mastery_overflow())],
		m.mastery_open()
		and Mastery.earned_points(m.mastery_overflow()) == Mastery.artifact_count())
	var got_names := PackedStringArray()
	var claim_ok := true
	for s in ProfessionCatalog.SKILLS:
		var art := Mastery.artifact_of(String(s))
		var rid := String(art["reward_id"])
		var had: int = m.inventory.count_of(rid)
		m._on_frame_mastery(String(s))
		if not m.mastery.has_claimed(String(s)) or m.inventory.count_of(rid) != had + int(art["n"]):
			claim_ok = false
		else:
			got_names.append("%s=%s" % [String(s), String(art["name"])])
	_check("⑭b ★스킬 다섯 칸 유물이 **전부** 백팩에 들어왔다 — %s" % " · ".join(got_names),
		claim_ok and m.mastery.is_complete()
		and m.mastery.claimed_count() == ProfessionCatalog.SKILLS.size())
	_check("⑭c 파리티 — 다 받고 나면 남는 포인트가 0(문턱 %d단 = 유물 %d점)"
			% [th.size(), Mastery.artifact_count()],
		m.mastery.available_points(m.mastery_overflow()) == 0)
	_check("⑭d ⚠️[ADR-0008] 경지가 기존 스킬 계수를 한 톨도 안 건드렸다(혼력 감산 %d 불변)"
			% energy_cost_before, m._farming_energy_cost() == energy_cost_before)

	# ── ⑮ 아트 패스(T9) — 이 세이브가 만든 물건들이 색박스로 안 떨어진다 ─────────
	print("── ⑮ 아트 패스 폴백 미도달 ──")
	var icon_miss := PackedStringArray()
	for iid in [ItemCatalog.RARECROW_8, ItemCatalog.MOUNT_WHISTLE, ItemCatalog.GARDEN_POT,
			ItemCatalog.SPRINKLER_T3, ItemCatalog.CRYSTALARIUM]:
		if m._item_icon(String(iid)) == null:
			icon_miss.append(String(iid))
	_check("⑮a 이 사슬이 만든 아이콘 5종이 전부 텍스처를 돌려준다(누락: %s)"
			% ("없음" if icon_miss.is_empty() else ", ".join(icon_miss)), icon_miss.is_empty())
	_check("⑮b 시련패 화폐 아이콘이 엽전 폴백에 안 떨어진다", m._trial_token_icon() != null)

	# ── ⑯ 세이브 왕복 — 한 파일이 엔드게임을 통째로 기억한다 ────────────────────
	print("── ⑯ 세이브 왕복 ──")
	m._indoor = ""
	m._rebuild_region(RegionCatalog.HOME)
	var live := {
		"tokens": m.trial.tokens,
		"trials": m.trial.completed_count(),
		"friend": m.pet.friendship(),
		"fireflies": m.fireflies.collected_count(),
		"dex": m.codex.shipped_count(),
		"crows": m._rarecrow_collected(),
		"claimed": m.mastery.claimed_count(),
		"revenue": m._cafe_revenue_total,
	}
	m._save_game()
	m.free()
	var m2: Node = await _new_main()
	_drain(m2)
	_check("⑯a 건축 두 채가 부팅을 건넌다(늘봄방 · 마구간 휘파람)",
		m2._greenhouse_built() and m2._buildings.has("늘봄방")
		and m2.carpenter.is_done(Carpenter.PROJ_STABLE)
		and m2.inventory.has_item(ItemCatalog.MOUNT_WHISTLE))
	_check("⑯b 늘봄방 작물·티어3 스프링클러·화분 작물이 전부 복원된다",
		m2.greenhouse_farm.crop_of(gh_tile) == off_crop
		and m2.sprinkler.tier_at(spr_tile) == Sprinkler.TIER_3
		and m2.garden_pot.crop_of(pot_tile) == CropCatalog.HONRYEONGCHO)
	_check("⑯c 삽사리·먹갈기·동행 혼이 복원된다(우정 %d · 승마 · 깃든 몸)" % int(live["friend"]),
		m2.pet.is_adopted() and m2.pet.friendship() == int(live["friend"])
		and m2.mount.is_mounted() and m2._soul_born and m2._spouse_id == "mochi"
		and m2._resident(m2.SOUL_CHILD_RID).node.visible)
	_check("⑯d 카페 3단이 그대로 서 있고 재팝업이 안 터진다(래치가 미리 켜진다)",
		m2._cafe_stage() == CafeMilestone.STAGE_3 and m2._milestone3_celebrated
		and m2._cafe_revenue_total == int(live["revenue"]))
	_check("⑯e 반딧넋 %d · 시련장 문 열린 채 · 시련패 %d · 완료 이력 %d · 1회성 구매"
			% [int(live["fireflies"]), int(live["tokens"]), int(live["trials"])],
		m2.fireflies.collected_count() == int(live["fireflies"])
		and m2.trial_ground_open() and m2._buildings.has("시련장")
		and m2.trial.tokens == int(live["tokens"])
		and m2.trial.completed_count() == int(live["trials"])
		and m2.trial.has_bought(ItemCatalog.RARECROW_8))
	_check("⑯f 도감 %d칸 · 레어크로우 %d종(디럭스 반경 유지) · 경지 유물 %d점"
			% [int(live["dex"]), int(live["crows"]), int(live["claimed"])],
		m2.codex.shipped_count() == int(live["dex"])
		and m2._rarecrow_collected() == int(live["crows"])
		and m2._scarecrow_radius() == CrowRaid.DELUXE_RADIUS
		and m2.mastery.claimed_count() == int(live["claimed"]) and m2.mastery.is_complete())
	_check("⑯g 로드 직후 연출 상태는 언제나 0이다(예약·컷신 — 세이브 대상 아님)",
		not m2._soul_birth_armed and not m2._pet_event_armed and m2.cutscene == null)
	_pass_day(m2)
	_check("⑯h ★관통이 끝난 뒤에도 하루가 그냥 흘러간다(코지 샌드박스 — 엔드게임이 게임을 안 닫는다)",
		m2.clock.running and not m2._run_over and m2._greenhouse_built()
		and m2.trial_ground_open())
	m2.free()

	cleaner.delete_save()
	cleaner.free()

	if _fail == 0:
		print("══ s10_endgame_smoke_test 전체 통과 ══")
	else:
		print("══ s10_endgame_smoke_test 실패 %d건 ══" % _fail)
	quit(1 if _fail > 0 else 0)
