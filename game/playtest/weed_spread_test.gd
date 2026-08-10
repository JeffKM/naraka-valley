extends SceneTree

# ★ [S7-T5 / ADR-0065 결정 7] 잡초 확산·파괴 + 절기 재스폰 + 성야 소멸 격리 검증.
#
# 무엇을 보나(ADR-0055 본체는 불변 — 여기서 보는 건 그 위에 얹은 가법 확장뿐):
#   ① 확산 결정성 — 같은 day·같은 소스·같은 분류 → 같은 칸(헤드리스 재현·세이브 되감기 안전).
#   ② 파괴 판정 — DEST_CROP·DEST_SPRINKLER 목적지는 파괴 목록에 실리고 그 칸이 잡초가 된다.
#   ③ 면제 — DEST_BLOCK은 아무 일도 없다(잡초 0·파괴 0).
#   ④ 혼우·절기 1일 ×2 — 같은 소스 집합에서 배수 2.0이 눈에 띄게 더 번진다.
#   ⑤ 절기 재스폰 — 규모 8~16·후보 부분집합·구성(잡초/업화석/석화고목)·결정성.
#   ⑥ 성야 — 확산 정지·재스폰 없음·purge_weeds 전량 소멸(_cleared·_debris는 불변).
#   ⑦ 세이브 왕복 — 잡초 + 재스폰 debris(kind 포함) + 치운 자리 셋 다 보존·구세이브 하위호환.
#   ⑧ clear() — 재스폰 debris를 치우면 원장에서 빠지고 _cleared로 승격(그 자리 영구 성역).
#   ⑨ (main) _weed_spread_class 분류 — 빈 맨땅·작물·스프링클러·프롭·과수·연못 여백.
#   ⑩ (main) end-to-end 확산 — 작물·스프링클러가 실제로 파괴되고 그 칸에 잡초가 앉는다.
#   ⑪ (main) 절기 재스폰 통합 — 재스폰 debris가 _debris_kind_at으로 잡히고 충돌이 서고 개간된다.
#   ⑫ (main) 성역 — 치운 자리는 후보에서 빠져 재스폰 대상이 아니다.
#
# Part A(①~⑧)는 Reclaim 단위(main 불필요), Part B(⑨~⑫)만 main 스폰(reclaim_test 결).
# 좀비 방지: 끝에 quit(). run_tests 워치독.

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

# 목적지 분류를 표(Dictionary)로 흉내내는 테스트용 Callable — 표에 없는 칸은 전부 면제(BLOCK).
func _map_cb(map: Dictionary) -> Callable:
	return func(t: Vector2i) -> int:
		return int(map.get(t, Reclaim.DEST_BLOCK))

# 넓은 빈 맨땅을 흉내내는 분류 — 어떤 칸이든 OPEN(확산 상한 없는 개활지).
func _open_cb() -> Callable:
	return func(_t: Vector2i) -> int:
		return Reclaim.DEST_OPEN

func _initialize() -> void:
	print("▶ weed_spread_test (S7-T5)")

	# ── ① 확산 결정성 ──────────────────────────────────────────────────────────
	# 소스 300개를 3칸 간격으로 흩어(이웃끼리 안 겹침) 개활지에 번지게 한다.
	var sources: Array = []
	for i in range(20):
		for j in range(15):
			sources.append(Vector2i(i * 3, j * 3))
	var r1 := Reclaim.new()
	var s1 := r1.spread_day(sources, _open_cb(), 11, false, 1.0)
	var r2 := Reclaim.new()
	var s2 := r2.spread_day(sources, _open_cb(), 11, false, 1.0)
	var w1: Array = s1["weeds"]
	var w2: Array = s2["weeds"]
	var same: bool = w1.size() == w2.size()
	for t in w1:
		if not r2.has_weed(t):
			same = false
	_check("① 같은 day·소스 → 결정적 동일", same and w1.size() > 0)
	var r3 := Reclaim.new()
	var s3 := r3.spread_day(sources, _open_cb(), 12, false, 1.0)
	_check("① 다른 day → 다른 출목(시드 유효)", s3["weeds"] != w1)
	# 확산은 소스의 4방 인접 칸으로만 간다.
	var adjacent_ok := true
	for t: Vector2i in w1:
		var near := false
		for d in Reclaim.SPREAD_DIRS:
			if (t - d) in sources:
				near = true
		if not near:
			adjacent_ok = false
	_check("① 목적지는 늘 소스의 4방 인접", adjacent_ok)
	# 기대치 ≈ 300 × 6% = 18(±). 폭주도 사장도 아님을 대략 확인한다.
	_check("① 확산 규모가 6% 근방(300소스 → 5~45)", w1.size() >= 5 and w1.size() <= 45)

	# ── ② 파괴 판정(작물·스프링클러) ────────────────────────────────────────────
	# 소스 하나를 4방 전부 작물로 둘러싸면 어느 방향으로 번져도 작물 하나가 삼켜진다(방향 무관 단언).
	var crop_src := Vector2i(10, 10)
	var crop_map: Dictionary = {}
	for d in Reclaim.SPREAD_DIRS:
		crop_map[crop_src + d] = Reclaim.DEST_CROP
	var rc := Reclaim.new()
	var sc: Dictionary = rc.spread_day([crop_src], _map_cb(crop_map), 5, false, 1.0 / Reclaim.SPREAD_CHANCE)
	var crops: Array = sc["crops"]
	_check("② 작물 칸 확산 → 파괴 목록 1건", crops.size() == 1)
	_check("② 파괴한 작물 칸이 잡초로 점유됨", crops.size() == 1 and rc.has_weed(crops[0]))
	_check("② 파괴 칸은 스프링클러 목록엔 없음", sc["sprinklers"].is_empty())
	var spr_src := Vector2i(20, 20)
	var spr_map: Dictionary = {}
	for d in Reclaim.SPREAD_DIRS:
		spr_map[spr_src + d] = Reclaim.DEST_SPRINKLER
	var rp := Reclaim.new()
	var sp: Dictionary = rp.spread_day([spr_src], _map_cb(spr_map), 5, false, 1.0 / Reclaim.SPREAD_CHANCE)
	var sprs: Array = sp["sprinklers"]
	_check("② 스프링클러 칸 확산 → 파괴 목록 1건·점유", sprs.size() == 1 and rp.has_weed(sprs[0]))

	# ── ③ 면제(BLOCK) — 아무 일도 없다 ──────────────────────────────────────────
	var rb := Reclaim.new()
	var sb: Dictionary = rb.spread_day([Vector2i(30, 30)], _map_cb({}), 5, false, 1.0 / Reclaim.SPREAD_CHANCE)
	_check("③ 면제 목적지 → 잡초 0·파괴 0", sb["weeds"].is_empty() and sb["crops"].is_empty() \
		and sb["sprinklers"].is_empty() and rb.weed_count() == 0)
	# 이미 잡초가 있는 칸은 목적지로 다시 안 쓴다(재점유 없음). ★두 번째 밤은 첫 밤에 앉은 잡초까지
	# 소스로 삼으므로 새 잡초 자체는 늘어난다 — 여기서 보는 건 "새로 앉은 칸이 기존 잡초와 안 겹침"이다.
	var rq := Reclaim.new()
	rq.spread_day(sources, _open_cb(), 11, false, 1.0)
	var snapshot: Array = rq.weed_tiles().duplicate()
	var sq: Dictionary = rq.spread_day(sources, _open_cb(), 12, false, 1.0)
	var no_reoccupy := true
	for t in sq["weeds"]:
		if t in snapshot:
			no_reoccupy = false
	_check("③ 이미 잡초인 칸은 목적지로 재사용 안 함", no_reoccupy)

	# ── ④ 혼우·절기 1일 ×2 ─────────────────────────────────────────────────────
	var r_wet := Reclaim.new()
	var s_wet := r_wet.spread_day(sources, _open_cb(), 11, false, Reclaim.SPREAD_WET_MULT)
	var w_wet: Array = s_wet["weeds"]
	_check("④ ×2 배수가 기본보다 확실히 많이 번짐", w_wet.size() > w1.size())
	_check("④ ×2도 폭주는 아님(소스 수 이하)", w_wet.size() <= sources.size())

	# ── ⑤ 절기 재스폰 ──────────────────────────────────────────────────────────
	var cands: Array = []
	for i in range(40):
		cands.append(Vector2i(50 + i, 40))
	var rr := Reclaim.new()
	var rez: Dictionary = rr.season_respawn(cands, 29, false)
	var r_w: Array = rez["weeds"]
	var r_e: Array = rez["ember"]
	var r_s: Array = rez["stump"]
	var total: int = r_w.size() + r_e.size() + r_s.size()
	_check("⑤ 규모 8~16", total >= Reclaim.SEASON_RESPAWN_MIN and total <= Reclaim.SEASON_RESPAWN_MAX)
	var in_cands := true
	for t in r_w + r_e + r_s:
		if not t in cands:
			in_cands = false
	_check("⑤ 재스폰은 후보 부분집합", in_cands)
	_check("⑤ 원장 반영(잡초 수·debris 수 일치)",
		rr.weed_count() == r_w.size() and rr.respawned_debris_count() == r_e.size() + r_s.size())
	var kinds_ok := true
	for t in r_e:
		if rr.respawned_debris_kind(t) != DebrisCatalog.EMBER:
			kinds_ok = false
	for t in r_s:
		if rr.respawned_debris_kind(t) != DebrisCatalog.STUMP:
			kinds_ok = false
	_check("⑤ debris kind가 업화석·석화고목으로 정확", kinds_ok)
	var rr2 := Reclaim.new()
	var rez2: Dictionary = rr2.season_respawn(cands, 29, false)
	_check("⑤ 같은 day → 결정적 동일", rez2["weeds"] == r_w and rez2["ember"] == r_e and rez2["stump"] == r_s)
	# 잡초 70% 가중이 실효인가 — 여러 절기를 굴려 누적 비율로 본다(단일 롤은 표본이 얕다).
	var acc_w := 0
	var acc_solid := 0
	for d in range(1, 20):
		var rx := Reclaim.new()
		var rz: Dictionary = rx.season_respawn(cands, 29 * d, false)
		var z_w: Array = rz["weeds"]
		var z_e: Array = rz["ember"]
		var z_s: Array = rz["stump"]
		acc_w += z_w.size()
		acc_solid += z_e.size() + z_s.size()
		rx.free()
	_check("⑤ 누적 구성이 잡초 우세(70% 가중 실효)", acc_w > acc_solid and acc_solid > 0)
	# 이미 잡초·debris가 앉은 칸은 다시 안 고른다.
	var rez3: Dictionary = rr.season_respawn(cands, 57, false)
	var no_dup := true
	for t in rez3["weeds"] + rez3["ember"] + rez3["stump"]:
		if t in r_w or t in r_e or t in r_s:
			no_dup = false
	_check("⑤ 이미 찬 칸 재선정 안 함", no_dup)
	_check("⑤ 후보 0 방어", Reclaim.new().season_respawn([], 29, false)["weeds"].is_empty())

	# ── ⑥ 성야절 — 확산 정지·재스폰 없음·잡초 소멸 ──────────────────────────────
	var rwin := Reclaim.new()
	var swin: Dictionary = rwin.spread_day(sources, _open_cb(), 85, true, 1.0)
	_check("⑥ 성야 확산 정지", swin["weeds"].is_empty() and rwin.weed_count() == 0)
	var rez_win: Dictionary = rwin.season_respawn(cands, 85, true)
	_check("⑥ 성야 진입 1일 재스폰 없음",
		rez_win["weeds"].is_empty() and rez_win["ember"].is_empty() and rez_win["stump"].is_empty())
	# 소멸: 잡초만 지우고 치운 자리(_cleared)·재스폰 debris는 그대로.
	var rpg := Reclaim.new()
	rpg.season_respawn(cands, 29, false)
	rpg.clear(Vector2i(3, 3), DebrisCatalog.WEEDS, ItemCatalog.SCYTHE)
	var weeds_before := rpg.weed_count()
	var debris_before := rpg.respawned_debris_count()
	var purged := rpg.purge_weeds()
	_check("⑥ purge_weeds가 잡초 전량 소멸", purged == weeds_before and rpg.weed_count() == 0 and purged > 0)
	_check("⑥ 소멸이 치운 자리·재스폰 debris는 안 건드림",
		rpg.is_cleared(Vector2i(3, 3)) and rpg.respawned_debris_count() == debris_before)
	_check("⑥ 잡초 0일 때 purge 무동작", rpg.purge_weeds() == 0)

	# ── ⑦ 세이브 왕복 ──────────────────────────────────────────────────────────
	var rs := Reclaim.new()
	rs.clear(Vector2i(50, 22), DebrisCatalog.WEEDS, ItemCatalog.SCYTHE)
	rs.season_respawn(cands, 29, false)
	rs.spread_day(sources, _open_cb(), 11, false, 1.0)
	var rs2 := Reclaim.new()
	rs2.load_save(rs.to_save())
	var round_ok := rs2.weed_count() == rs.weed_count() \
		and rs2.respawned_debris_count() == rs.respawned_debris_count() \
		and rs2.is_cleared(Vector2i(50, 22))
	for t in rs.weed_tiles():
		if not rs2.has_weed(t):
			round_ok = false
	for t in rs.respawned_debris_tiles():
		if rs2.respawned_debris_kind(t) != rs.respawned_debris_kind(t):
			round_ok = false
	_check("⑦ 잡초+재스폰debris(kind)+치운자리 왕복 보존", round_ok)
	var rs3 := Reclaim.new()
	rs3.load_save({"cleared": [[1, 1]], "weeds": [[2, 2]]})   # debris 키 없는 구세이브
	_check("⑦ 구세이브 하위호환(debris 키 없음 → 0)",
		rs3.respawned_debris_count() == 0 and rs3.has_weed(Vector2i(2, 2)) and rs3.is_cleared(Vector2i(1, 1)))

	# ── ⑧ 재스폰 debris 개간 = _cleared 승격 ────────────────────────────────────
	var rd := Reclaim.new()
	var rz_d: Dictionary = rd.season_respawn(cands, 29, false)
	var solid_tiles: Array = rz_d["ember"] + rz_d["stump"]
	if solid_tiles.is_empty():
		_check("⑧ (표본 없음 — 다른 day로 재시도)", false)
	else:
		var dt: Vector2i = solid_tiles[0]
		var dk: String = rd.respawned_debris_kind(dt)
		var got := rd.clear(dt, dk, DebrisCatalog.tool_for(dk))
		_check("⑧ 맞는 도구로 재스폰 debris 개간 성공", not got.is_empty() and rd.is_cleared(dt))
		_check("⑧ 개간 후 원장서 빠짐(kind \"\")", rd.respawned_debris_kind(dt) == "" \
			and rd.respawned_debris_count() == solid_tiles.size() - 1)

	r1.free(); r2.free(); r3.free(); rc.free(); rp.free(); rb.free(); rq.free(); r_wet.free()
	rr.free(); rr2.free(); rwin.free(); rpg.free(); rs.free(); rs2.free(); rs3.free(); rd.free()

	# ── Part B: main 통합(⑨~⑫) — 신규 게임 강제(세이브 백업·삭제) ─────────────
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	var m := await _spawn_main()

	# ⑨ _weed_spread_class 분류
	var occ: Dictionary = m._home_occupied_tiles()
	var patch: Rect2i = m.STARTER_PATCH_RECT
	var open_t := Vector2i(patch.position.x + 2, patch.position.y + 2)   # 스타터 패치 한복판(SOIL·빈 칸)
	_check("⑨ 빈 밭 흙 = OPEN(갈아둔 흙 침식 O)", m._weed_spread_class(open_t, occ) == Reclaim.DEST_OPEN)
	_check("⑨ 맵 밖 = BLOCK", m._weed_spread_class(Vector2i(-1, 5), occ) == Reclaim.DEST_BLOCK)
	_check("⑨ 하드게이트 debris 프롭 위 = BLOCK", m._weed_spread_class(Vector2i(9, 28), occ) == Reclaim.DEST_BLOCK)
	_check("⑨ 연못 물가 활동존 = BLOCK",
		m._weed_spread_class(Vector2i(m.POND_ACTIVITY_RECT.position.x + 1,
			m.POND_ACTIVITY_RECT.position.y + 1), occ) == Reclaim.DEST_BLOCK)
	# 작물 — 패치 한 칸을 갈고 심는다.
	var crop_t := Vector2i(patch.position.x, patch.position.y)
	m.farm.hoe(crop_t)
	m.farm.plant(crop_t, CropCatalog.PIANHWA)
	_check("⑨ 심긴 작물 칸 = CROP", m.farm.is_planted(crop_t) \
		and m._weed_spread_class(crop_t, occ) == Reclaim.DEST_CROP)
	# 스프링클러 — 패치 다른 칸에 설치.
	var spr_t := Vector2i(patch.position.x + 4, patch.position.y + 4)
	m.sprinkler.place(spr_t)
	_check("⑨ 스프링클러 칸 = SPRINKLER", m._weed_spread_class(spr_t, occ) == Reclaim.DEST_SPRINKLER)
	# 과수 — 3×3 풋프린트가 통째로 면제(ADR-0045 불가침).
	var tree_anchor := Vector2i(60, 30)
	var planted_tree: bool = m.orchard.plant(tree_anchor, FruitTreeCatalog.HONBAEKDO, 1,
		func(_t: Vector2i) -> bool: return false)
	_check("⑨ 과수 밑동·수관 = BLOCK(면제)", planted_tree \
		and m._weed_spread_class(tree_anchor, occ) == Reclaim.DEST_BLOCK \
		and m._weed_spread_class(tree_anchor + Vector2i(1, 1), occ) == Reclaim.DEST_BLOCK)
	# 이미 잡초인 칸.
	var weed_t := Vector2i(patch.position.x + 1, patch.position.y + 4)
	m.reclaim._weeds[weed_t] = true
	_check("⑨ 이미 잡초인 칸 = BLOCK", m._weed_spread_class(weed_t, occ) == Reclaim.DEST_BLOCK)
	m.reclaim._weeds.erase(weed_t)

	# ⑩ end-to-end 확산 — 작물 4방 포위 소스로 방향 무관 파괴 단언
	var e2e_src := Vector2i(patch.position.x + 2, patch.position.y + 2)
	for d in Reclaim.SPREAD_DIRS:
		var nt: Vector2i = e2e_src + d
		m.farm.hoe(nt)
		m.farm.plant(nt, CropCatalog.PIANHWA)
	var planted_before: int = m.farm.planted_tiles().size()
	var e2e: Dictionary = m.reclaim.spread_day([e2e_src], m._weed_spread_cb(), 7, false,
		1.0 / Reclaim.SPREAD_CHANCE)
	var e2e_crops: Array = e2e["crops"]
	_check("⑩ 확산이 작물 칸을 지목", e2e_crops.size() == 1)
	if e2e_crops.size() == 1:
		var victim: Vector2i = e2e_crops[0]
		m.farm.remove_plant(victim)   # main._on_day_advanced가 하는 집행을 그대로 흉내
		_check("⑩ 작물 파괴 후 그 칸은 잡초", not m.farm.is_planted(victim) and m.reclaim.has_weed(victim))
		_check("⑩ 심긴 칸 수가 정확히 1 줄어듦", m.farm.planted_tiles().size() == planted_before - 1)
		m.reclaim.clear_weed(victim, ItemCatalog.SCYTHE)   # 뒷정리(다음 단언 오염 방지)

	# ⑪ 절기 재스폰 통합 — 재스폰 solid debris가 조회·충돌·개간까지 기존 경로로 돈다
	var cand_main: Array = m._encroach_candidates()
	_check("⑪ 후보 비어있지 않음", cand_main.size() > 0)
	# ★ 충돌 카운트 전에 프레임을 한 번 넘긴다 — 앞 단언들이 일으킨 재구성의 queue_free가 지연 삭제라,
	#   바로 세면 "지워질 옛 노드 + 새 노드"가 겹쳐 잡혀 기준선이 부풀어 오른다(비교가 뒤집힌다).
	await process_frame
	var coll_before: int = m._prop_body.get_children().size()
	var rez_main: Dictionary = {}
	var day_try := 29
	while day_try < 29 * 12:
		rez_main = m.reclaim.season_respawn(cand_main, day_try, false)
		if not (rez_main["ember"] as Array).is_empty():
			break
		day_try += 28
	var embers: Array = rez_main["ember"]
	_check("⑪ 재스폰 표본에 업화석 있음", not embers.is_empty())
	if not embers.is_empty():
		var et: Vector2i = embers[0]
		_check("⑪ _debris_kind_at이 재스폰 업화석을 잡음", m._debris_kind_at(et) == DebrisCatalog.EMBER)
		await process_frame
		_check("⑪ SOLID 충돌이 늘어남(통행 차단)", m._prop_body.get_children().size() > coll_before)
		# 곡괭이로 개간 — 기존 _use_tool 경로 그대로.
		m.inventory.select(_slot_of(m.inventory, ItemCatalog.PICKAXE))
		var shard_before: int = m.inventory.count_of(ItemCatalog.EMBER_SHARD)
		m._target = et
		m._use_tool()
		_check("⑪ 곡괭이 개간 → is_cleared·드랍 적재",
			m.reclaim.is_cleared(et) and m.inventory.count_of(ItemCatalog.EMBER_SHARD) > shard_before)
		_check("⑪ 개간 후 _debris_kind_at \"\"", m._debris_kind_at(et) == "")
		_check("⑪ 개간한 자리는 경작 가능(진보)", m._is_farmable(et))

		# ⑫ 성역 — 치운 자리는 후보에서 빠져 재스폰 대상이 아니다
		var cand_after: Array = m._encroach_candidates()
		_check("⑫ 치운 자리가 후보에서 빠짐", not (et in cand_after))
		var seen_again := false
		for d2 in range(1, 12):
			var rx2 := Reclaim.new()
			var rz2: Dictionary = rx2.season_respawn(cand_after, 29 * d2, false)
			for t in rz2["weeds"] + rz2["ember"] + rz2["stump"]:
				if t == et:
					seen_again = true
			rx2.free()
		_check("⑫ 여러 절기를 굴려도 치운 자리엔 재스폰 0", not seen_again)

	m.queue_free()
	await process_frame
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		if FileAccess.file_exists(BAK):
			DirAccess.remove_absolute(BAK)

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# 인벤토리 슬롯에서 id의 인덱스(-1 = 없음).
func _slot_of(inv: Object, id: String) -> int:
	for i in range(inv.slots.size()):
		if inv.id_at(i) == id:
			return i
	return -1

const SAVE := "user://save.dat"
const BAK := "user://save.dat.weedspread.bak"

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
