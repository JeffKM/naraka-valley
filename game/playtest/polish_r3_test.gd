extends SceneTree
# ★[폴리시 3회차 · 배치 A] 버그 헌트 확정분 회귀 — 세이브 하위호환 · 시간/연출 위상 · 전환 상태 누수.
#
# polish_r2_art_test와 같은 결이되 축이 다르다: 저건 "아트가 폴백에 안 떨어진다"를 재고,
# 여기는 **"날이 바뀌는 순간·연출이 겹치는 순간에 상태가 새지 않는다"**를 잰다.
#
# 무엇을 보증하나(발견 번호 = 3회차 헌트 배치 A):
#   ① #1 밭 칸 스키마 — 비료 필드 없는 구세이브 칸이 로드에서 백필되고, remove_plant가 그 칸에서도 산다.
#   ② #2/#10 인플레이스 재로드 — 키 없는 구세이브를 F9로 다시 읽으면 아이템 원장 넷이 **비워지고**
#      (안 비우면 인벤만 롤백돼 같은 물건이 상자와 백팩 양쪽에 남는다 = 복제), 갱도 진입 층 선택도 1층으로 돌아온다.
#   ③ #3 사다리 안전판 — "마지막 돌은 반드시 열린다"가 **대흉 날에도** 선다(운 가산이 안전판을 못 깬다).
#   ④ #4 반짝이 조회 — 몹 배수를 받는다(라이브 층 배치와 같은 답을 낸다).
#   ⑤ #5 취침 ⊗ 컷신 — 취침 연출 중엔 페이드·시계의 주인이 취침이고, 컷신 재생 중엔 이동 잠금이 안 풀린다.
#   ⑥ #6/#11/#12 취침이 미니게임 세션을 접는다 — 체키·칵테일·릴 격투가 날짜를 넘어 살아남지 않는다.
#   ⑦ #8 취침 ⊗ 워프 — 워프 연출 중 들어온 강제 취침은 줄을 서고(두 트윈 겹침 0), 연출 뒤에 집행된다.
#   ⑧ #7 밀린 절기 재스폰 — 집 밖에서 절기가 바뀌면 표만 서고, 안식 농원에 다시 서는 프레임에 집행된다.
#   ⑨ #9 삽사리 이벤트 — 예약이 스테일로 남아도 **나루 마을 야외에서만** 소비된다.
#   ⑩ #13 꾸미기 모드 — 연출·모달이 서 있으면 켜지지 않고, 켜진 채로 연출이 들어오면 스스로 접힌다.
#
# 실행: ./run_tests.sh polish_r3   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

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

func _initialize() -> void:
	print("══ 폴리시 3회차 배치 A — 세이브 하위호환 · 시간 위상 · 전환 누수 회귀 ══")
	var save0 := SaveManager.slot_path(0)
	if FileAccess.file_exists(save0):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save0))
	var m := await _spawn_main()
	_dismiss_dialogue(m)

	# ── ① #1 밭 칸 스키마 백필 ────────────────────────────────────────────────
	print("── ① #1 비료 필드 없는 구세이브 칸 ──")
	var old_tile := Vector2i(9, 9)
	var crop_id: String = CropCatalog.HONRYEONGCHO
	# S1-6 이전 세이브의 칸 = 4필드(비료 없음). load_save는 이걸 통째로 갈아끼운다.
	m.farm.load_save({"tiles": {old_tile: {"planted": false, "watered": false, "crop": "", "grown_days": 0}}})
	_check("①a 로드가 비료 필드를 백필한다(키 존재 · 값 = 무비료)",
		m.farm._tiles[old_tile].has("fertilizer") and m.farm.fertilizer_of(old_tile) == "")
	_check("①b 백필 칸은 여전히 경작 상태 그대로다(심김 false · 작물 없음)",
		m.farm.is_tilled(old_tile) and not m.farm.is_planted(old_tile) and m.farm.crop_of(old_tile) == "")
	_check("①c 심기 → 제거가 성립한다(절기 사멸·까마귀·잡초 확산의 그 경로)",
		m.farm.plant(old_tile, crop_id) and m.farm.remove_plant(old_tile))
	_check("①d 제거 뒤에도 흙과 비료 칸은 남는다(스타듀 결)",
		m.farm.is_tilled(old_tile) and not m.farm.is_planted(old_tile)
		and m.farm.fertilizer_of(old_tile) == "")
	# 백필을 우회해 **원장에 직접** 옛 칸을 꽂아도 remove_plant가 산다(.get 방어 = 파일 39행 규약).
	var raw_tile := Vector2i(9, 10)
	m.farm._tiles[raw_tile] = {"planted": true, "watered": false, "crop": crop_id, "grown_days": 0}
	_check("①e 백필을 안 거친 칸에서도 remove_plant가 산다(하드 인덱싱 제거)",
		m.farm.remove_plant(raw_tile) and m.farm.crop_of(raw_tile) == "")

	# ── ② #2/#10 인플레이스 재로드(F9) ────────────────────────────────────────
	print("── ② #2/#10 키 없는 구세이브를 실행 중에 다시 읽는다 ──")
	var hid := ItemCatalog.harvest_id(crop_id)
	m._active_slot = 1
	m.chest.store(hid, 5, 0)
	m.storehouse_chest.store(hid, 2, 0)
	m.larder.add(hid, 3)
	m.inventory.add_item(hid, 1)
	var chest_before: int = m.chest.count_of(hid)
	# Phase D(상자)·S6-T1(곳간) 이전 세이브 = 인벤·지갑·시계만 든 조각(SaveManager.VERSION은 1 그대로라 정상 로드).
	var legacy := {"clock": m.clock.to_save(), "wallet": m.wallet.to_save(),
		"inventory": m.inventory.to_save()}
	m.saver.save_game(legacy, 1, {})
	m._mine_entry_pick = 25
	m._load_game()
	_dismiss_dialogue(m)
	_check("②a 적재 전엔 상자에 %s ×%d가 실제로 들어 있었다(전제 확인)" % [hid, chest_before],
		chest_before == 5)
	_check("②b 집 상자가 비워진다 — 인벤만 롤백되던 복제 벡터 봉합",
		m.chest.is_empty() and m.chest.count_of(hid) == 0)
	_check("②c 창고 상자도 같은 규율", m.storehouse_chest.is_empty()
		and m.storehouse_chest.count_of(hid) == 0)
	_check("②d 카페 곳간도 같은 규율(%s 재고 0)" % hid, m.larder.count_of(hid) == 0 and m.larder.total() == 0)
	_check("②e 출하함도 같은 규율(대기 원장 빔)", m.ship_bin.pending.is_empty())
	_check("②f #10 갱도 진입 층 선택이 1층으로 돌아온다(해금 밖 층으로 곧장 하강 봉합)",
		m._mine_entry_pick == 1 and m._mine_entry_options().has(m._mine_entry_pick))
	m.saver.delete_save(1)
	m._active_slot = 0

	# ── ③ #3 사다리 안전판 × 명부의 운 ────────────────────────────────────────
	print("── ③ #3 마지막 돌은 대흉 날에도 반드시 열린다 ──")
	var bad_luck := -DailyLuck.SPREAD * DailyLuck.W_LADDER    # 대흉 날 사다리 가산(수치 하드코딩 금지 — 상수 파생)
	_check("③a 운 0 마지막 돌 = 1.0(종전 불변)", MineFloors.ladder_chance(0) >= 1.0)
	_check("③b 대흉(%.2f) 마지막 돌 = 1.0" % bad_luck, MineFloors.ladder_chance(0, false, bad_luck) == 1.0)
	_check("③c 몹 전멸 보너스가 겹쳐도 1.0", MineFloors.ladder_chance(0, true, bad_luck) == 1.0)
	_check("③d 그래도 운은 **중간 확률을 낮춘다**(안전판만 면제 — 배선이 죽지 않았다)",
		MineFloors.ladder_chance(5, false, bad_luck) < MineFloors.ladder_chance(5)
		and MineFloors.ladder_chance(5, false, bad_luck) > 0.0)
	# 나락은 확정 하강 사다리가 없어(rocks 비었을 때만 놓인다) 이 안전판이 유일한 하강 근거다.
	var stuck: Array = []
	for i in 40:
		var t := Vector2i(3 + i % 8, 4 + i / 8)
		if not NarakFloors.roll_ladder(7, 12, t, 0, false, bad_luck):
			stuck.append(t)
	_check("③e 대흉 날 나락 마지막 돌 40칸 전부 사다리가 열린다(막다른 깊이 0 · 실패: %s)" % str(stuck),
		stuck.is_empty())

	# ── ④ #4 반짝이 조회의 몹 배수 ────────────────────────────────────────────
	print("── ④ #4 shimmers_left/shimmer_at가 층 배치와 같은 답을 낸다 ──")
	var scale: float = Weather.SOULWIND_MOB      # 혼불 바람 날 라이브 배수(수치 파생)
	var probe_day := 0
	var probe_floor := 0
	for d in range(1, 6):
		for f in range(1, 21):
			var a: Array = MineFloors.generate(d, f).get("shimmers", [])
			var b: Array = MineFloors.generate(d, f, scale).get("shimmers", [])
			if str(a) != str(b) and not b.is_empty():
				probe_day = d
				probe_floor = f
				break
		if probe_day != 0:
			break
	_check("④a 배수 1.0과 %.1f가 실제로 갈리는 층이 있다(day %d · %d층 — 조회가 배수를 알아야 하는 이유)"
		% [scale, probe_day, probe_floor], probe_day != 0)
	if probe_day != 0:
		var live: Array = MineFloors.generate(probe_day, probe_floor, scale).get("shimmers", [])
		var mf = m.mine_floors
		var listed: Array = mf.shimmers_left(probe_day, probe_floor, scale)
		var same := listed.size() == live.size()
		for e: Dictionary in live:
			var hit := false
			for l: Dictionary in listed:
				if l["tile"] == e["tile"] and String(l["id"]) == String(e["id"]):
					hit = true
					break
			same = same and hit
		_check("④b 배수를 넘긴 목록이 라이브 배치와 칸·종까지 일치(%d개)" % live.size(), same)
		var t0: Vector2i = live[0]["tile"]
		var id0 := String(live[0]["id"])
		_check("④c shimmer_at(%s, 배수 %.1f) = %s" % [str(t0), scale, id0],
			mf.shimmer_at(probe_day, probe_floor, t0, scale) == id0)
		_check("④d 주운 칸은 배수와 무관하게 빈다",
			not mf.is_picked(probe_floor, t0))
		mf.mark_picked(probe_floor, t0)
		_check("④e 줍고 나면 그 칸은 \"\"(원장이 배치보다 우선)",
			mf.shimmer_at(probe_day, probe_floor, t0, scale) == "")

	# ── ⑨ #9 삽사리 이벤트 무대 검증 ──────────────────────────────────────────
	print("── ⑨ #9 스테일 예약은 엉뚱한 무대에서 안 터진다 ──")
	m.clock.day = Pet.ADOPT_MIN_DAY + 3
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	m._indoor = "만물상"                      # 부팅 재빌드가 세운 예약이 실내 워프 끝에 소비되던 자리
	m._pet_event_armed = true
	m._fire_pet_event()
	_check("⑨a 마을 **실내**에서는 입양이 안 선다(예약만 내려간다)",
		not m.pet.is_adopted() and not m._pet_event_armed)
	m._indoor = ""
	m._rebuild_region(RegionCatalog.HWANGCHEONHAE)
	m._pet_event_armed = true
	m._fire_pet_event()
	_check("⑨b 다른 구역(황천해)에서도 안 선다", not m.pet.is_adopted() and not m._pet_event_armed)
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	m._indoor = ""
	_check("⑨c 마을을 세우는 프레임에 예약이 다시 선다(잃은 것 0)", m._pet_event_armed)
	m._fire_pet_event()
	_check("⑨d 나루 마을 야외에서 소비 = 입양", m.pet.is_adopted() and not m._pet_event_armed)

	# ── ⑧ #7 밀린 절기 대량 재스폰 ────────────────────────────────────────────
	print("── ⑧ #7 집 밖에서 절기가 바뀐 아침 ──")
	var season_day := 29                       # 절기 2번째(망연절) 첫날 — 성야가 아니라 재스폰 갈래
	_check("⑧⓪ 전제 — day %d는 절기 첫날이고 성야가 아니다" % season_day,
		GameClock.is_season_first_day(season_day) and GameClock.season_index_for_day(season_day) != 3)
	m._rebuild_region(RegionCatalog.NARU_VILLAGE)
	m._indoor = ""
	m.clock.day = season_day
	_check("⑧a 집 밖에선 후보 스캔이 비어 있다(재스폰이 소진되던 뿌리)",
		m._encroach_candidates().is_empty())
	var weeds_before: int = m.reclaim.weed_count()
	var debris_before: int = m.reclaim.respawned_debris_count()
	m._season_respawn_pending_day = 0
	m._on_day_advanced(season_day)
	_check("⑧b 마당은 아직 그대로고(잡초 %d·재스폰 debris %d 불변) 표만 선다"
		% [weeds_before, debris_before],
		m.reclaim.weed_count() == weeds_before
		and m.reclaim.respawned_debris_count() == debris_before
		and m._season_respawn_pending_day == season_day)
	m._pet_event_armed = false                 # 위 재빌드가 다시 걸었을 수 있는 예약을 접는다(이 절 밖 상태)
	m._rebuild_region(RegionCatalog.HOME)
	m._indoor = ""
	m._sleeping = false
	m._transitioning = false
	await process_frame
	_check("⑧c 안식 농원에 다시 서는 프레임에 표가 소비된다", m._season_respawn_pending_day == 0)
	var grown: int = (m.reclaim.weed_count() - weeds_before) \
		+ (m.reclaim.respawned_debris_count() - debris_before)
	_check("⑧d 그 절기 재스폰이 실제로 돋았다(잡초 %d → %d · 재스폰 debris %d → %d)"
		% [weeds_before, m.reclaim.weed_count(), debris_before, m.reclaim.respawned_debris_count()],
		grown > 0 and m.reclaim.weed_count() >= weeds_before
		and m.reclaim.respawned_debris_count() >= debris_before)

	# ── ⑩ #13 꾸미기 모드 모달 가드 ───────────────────────────────────────────
	print("── ⑩ #13 집 꾸미기(C)가 연출·모달을 얼리지 않는다 ──")
	m._region = RegionCatalog.HOME
	m._indoor = "집"
	_dismiss_dialogue(m)
	_check("⑩a 자리 게이트는 그대로(집 실내)", m._can_deco())
	_check("⑩b 평시엔 안 막힌다", not m._deco_blocked())
	m._sleeping = true
	_check("⑩c 취침 연출 중 = 막힘", m._deco_blocked())
	m._sleeping = false
	m._transitioning = true
	_check("⑩d 워프 연출 중 = 막힘", m._deco_blocked())
	m._transitioning = false
	m.dialogue.start("옥자", PackedStringArray(["시험용 한 줄"]))
	_check("⑩e 대화 중 = 막힘", m._deco_blocked())
	_dismiss_dialogue(m)
	m._open_frame(InventoryFrame.CTX_MENU)
	_check("⑩f 모달 프레임 중 = 막힘", m._deco_blocked())
	m._close_frame()
	_check("⑩g 닫으면 다시 안 막힌다", not m._deco_blocked())
	# 켜 둔 채로 연출이 들어오는 경로(취침 트윈 뒤 아침 컷신) = 스스로 접힌다.
	m._deco_mode = true
	m._sleeping = true
	await process_frame
	_check("⑩h 켜진 채로 연출이 들어오면 스스로 접힌다(프레임이 안 멎는다)", not m._deco_mode)
	m._sleeping = false

	# ── ⑤ #5 취침 ⊗ 컷신 ─────────────────────────────────────────────────────
	print("── ⑤ #5 자정을 넘긴 컷신 ──")
	m.clock.running = true
	var opened: bool = m._begin_cutscene([{"verb": "fade", "to": 1.0, "secs": 5.0}],
		"", PackedStringArray())
	_check("⑤⓪ 시험용 컷신이 열렸다(시계 스냅 = 흐름)", opened and m.cutscene != null and m._cutscene_clock_prev)
	m._sleeping = true
	m.clock.running = false
	m.fade.modulate.a = 1.0
	m._apply_cutscene_frame()
	_check("⑤a 취침 중엔 컷신이 시계를 되살리지 않는다", not m.clock.running)
	_check("⑤b 취침 중엔 컷신이 페이드를 덮지 않는다(암전이 보인다)", m.fade.modulate.a == 1.0)
	m.player.set_physics_process(false)
	m._on_sleep_done()
	_check("⑤c 컷신 재생 중이면 취침 종료가 이동 잠금을 안 푼다",
		not m.player.is_physics_processing() and not m._sleeping)
	# 반대편 — 취침이 아니면 컷신이 다시 주인이다(가드가 배선을 죽이지 않았다).
	m.clock.running = false
	m._apply_cutscene_frame()
	_check("⑤d 취침이 아니면 컷신이 시계·페이드의 주인으로 돌아온다",
		m.clock.running and m.fade.modulate.a != 1.0)
	m._end_cutscene()
	_check("⑤e 종료가 화면을 원복한다", m.cutscene == null and m.fade.modulate.a == 0.0)

	# ── ⑦ #8 취침 ⊗ 워프 ─────────────────────────────────────────────────────
	print("── ⑦ #8 워프 연출 중에 들어온 강제 취침 ──")
	m._sleeping = false
	m._sleep_pending = false
	m._transitioning = true
	m._do_sleep()
	_check("⑦a 워프 중이면 취침을 시작하지 않고 줄을 선다(두 트윈 겹침 0)",
		not m._sleeping and m._sleep_pending)
	m._sleep_pending = false
	m._transitioning = false

	# ── ⑥ #6/#11/#12 취침이 미니게임 세션을 접는다 ────────────────────────────
	print("── ⑥ #6/#11/#12 세션은 날짜를 넘어 살아남지 않는다 ──")
	m.cheki = ChekiSession.new(1234)
	m.cocktail = CocktailSession.new(5678)
	m.fishing = FishingSession.new(91011)
	_check("⑥⓪ 세 세션이 실제로 서 있다(전제 확인)",
		m.cheki != null and m.cocktail != null and m.fishing != null)
	m._sleeping = false
	m._transitioning = false
	m._do_sleep()
	_check("⑥a 체키 세션이 접힌다", m.cheki == null)
	_check("⑥b 칵테일 세션이 접힌다(닫힌 밤 장부에 매출이 오르던 벡터)", m.cocktail == null)
	_check("⑥c 릴 격투 세션이 접힌다(어제 물고기가 오늘 날짜로 결착되던 벡터)", m.fishing == null)
	_check("⑥d 취침 자체는 정상 개시(연출 플래그·시계 정지)", m._sleeping and not m.clock.running)

	if FileAccess.file_exists(save0):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save0))
	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(0 if _fail == 0 else 1)
