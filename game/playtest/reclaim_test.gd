extends SceneTree

# ★ [S1-8 / greybox-spec §10] 안식 농원 overgrown 개간(debris 치우기) 격리 검증.
#
# 무엇을 보나(S1-8 = 맞는 도구로 debris 치움 → 통과·경작지 확장 → 드랍 적립 · 세이브 · 소프트락 0):
#   ① DebrisCatalog 매핑 — 3종 도구·드랍·수·solid / is_reclaim_tool / 미지 kind 방어.
#   ② 맞는 도구 개간 성공 — clear가 드랍 반환(정확한 재료·수) · is_cleared 세움.
#   ③ 틀린 도구 무동작 — {} 반환 · is_cleared 안 세움.
#   ④ 멱등 — 이미 치운 것 재개간 {} · cleared_count 불변.
#   ⑤ 미지 kind 방어 — clear {} .
#   ⑥ 세이브 왕복 — 치운 집합 보존.
#   ⑦ (main) START_TOOLS 개간 3종 존재(소프트락 0).
#   ⑧ (main) 하드게이트 debris kind 조회 — (24,14)=업화석·(24,16)=석화고목.
#   ⑨ (main) end-to-end _use_tool — 곡괭이로 하드게이트 개간 → is_cleared·충돌 제거(통과)·
#      _is_farmable true(경작지 확장)·드랍 인벤토리 적재·_debris_kind_at "" .
#   ⑩ (main) 스타터 패치(40,12,5,5) debris 0.
#
# ★ [ADR-0055] 차등 재점령(encroachment):
#   ⑪ advance_day — 밤당 1~2칸 재점령·후보 안에서만·day 시드 결정적.
#   ⑫ 겨울(잿눈) 게이트 — 재점령 정지.  ⑬ 후보 0 방어.
#   ⑭ 총상한(cap=ceil(후보×0.75))·이미 돋은 칸 재선정 안 함·후보 부분집합.
#   ⑮ clear_weed — 낫 성공(혼백섬유×1)·has_weed 해제 / 틀린 도구·무잡초 무동작.
#   ⑯ 세이브 왕복 — 치운 것 + 재점령 잡초 둘 다 보존.
#   ⑰ (main) _encroach_candidates — GROUND·스캔 안·프롭/SOIL/개간 자리 배제.
#   ⑱ (main) end-to-end — advance_day 재점령 → 낫 _use_tool 베기 → 드랍 적립·has_weed 해제.
#
# Part A(①~⑥,⑪~⑯)는 Reclaim/DebrisCatalog 단위(main 불필요), Part B(⑦~⑩,⑰~⑱)만 main 스폰(livestock_test 결).
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

func _initialize() -> void:
	print("▶ reclaim_test (S1-8)")
	var WEEDS := DebrisCatalog.WEEDS
	var EMBER := DebrisCatalog.EMBER
	var STUMP := DebrisCatalog.STUMP

	# ── ① DebrisCatalog 매핑(§10.2) ──
	_check("① weeds→낫·혼백섬유·1·통과", DebrisCatalog.tool_for(WEEDS) == ItemCatalog.SCYTHE \
		and DebrisCatalog.drop_for(WEEDS) == ItemCatalog.SOUL_FIBER \
		and DebrisCatalog.drop_count(WEEDS) == 1 and not DebrisCatalog.is_solid(WEEDS))
	_check("① ember→곡괭이·업화석조각·2·SOLID", DebrisCatalog.tool_for(EMBER) == ItemCatalog.PICKAXE \
		and DebrisCatalog.drop_for(EMBER) == ItemCatalog.EMBER_SHARD \
		and DebrisCatalog.drop_count(EMBER) == 2 and DebrisCatalog.is_solid(EMBER))
	_check("① stump→도끼·석화목재·2·SOLID", DebrisCatalog.tool_for(STUMP) == ItemCatalog.AXE \
		and DebrisCatalog.drop_for(STUMP) == ItemCatalog.PETRIFIED_WOOD \
		and DebrisCatalog.drop_count(STUMP) == 2 and DebrisCatalog.is_solid(STUMP))
	_check("① is_reclaim_tool 3종 참", DebrisCatalog.is_reclaim_tool(ItemCatalog.SCYTHE) \
		and DebrisCatalog.is_reclaim_tool(ItemCatalog.PICKAXE) and DebrisCatalog.is_reclaim_tool(ItemCatalog.AXE))
	_check("① is_reclaim_tool 괭이·물뿌리개 거짓", not DebrisCatalog.is_reclaim_tool(ItemCatalog.HOE) \
		and not DebrisCatalog.is_reclaim_tool(ItemCatalog.WATERING_CAN))
	_check("① 미지 kind 방어", DebrisCatalog.tool_for("void") == "" and DebrisCatalog.drop_count("void") == 0 \
		and not DebrisCatalog.has("void"))

	# ── ItemCatalog 드랍 재료 통합(§10.2) ──
	_check("① 드랍 3종 CAT_MATERIAL", ItemCatalog.category_of(ItemCatalog.SOUL_FIBER) == ItemCatalog.CAT_MATERIAL \
		and ItemCatalog.category_of(ItemCatalog.EMBER_SHARD) == ItemCatalog.CAT_MATERIAL \
		and ItemCatalog.category_of(ItemCatalog.PETRIFIED_WOOD) == ItemCatalog.CAT_MATERIAL)
	_check("① 드랍 스택·이름·가격", ItemCatalog.stackable_of(ItemCatalog.EMBER_SHARD) \
		and ItemCatalog.name_of(ItemCatalog.SOUL_FIBER) == "혼백 섬유" and ItemCatalog.price_of(ItemCatalog.EMBER_SHARD) > 0)
	_check("① 개간 도구 3종 CAT_TOOL·비매", ItemCatalog.category_of(ItemCatalog.SCYTHE) == ItemCatalog.CAT_TOOL \
		and ItemCatalog.price_of(ItemCatalog.PICKAXE) == 0 and not ItemCatalog.stackable_of(ItemCatalog.AXE))

	# ── ② 맞는 도구 개간 성공(§10.3) ──
	var r := Reclaim.new()
	var tw := Vector2i(50, 22)
	var res := r.clear(tw, WEEDS, ItemCatalog.SCYTHE)
	_check("② 낫으로 잡초 개간 성공", not res.is_empty() and str(res["drop"]) == ItemCatalog.SOUL_FIBER \
		and int(res["count"]) == 1 and r.is_cleared(tw))
	var te := Vector2i(9, 28)   # ★[단계3] 남향 게이트 업화석(옛 동향 24,14 → 90° 회전)
	var res_e := r.clear(te, EMBER, ItemCatalog.PICKAXE)
	_check("② 곡괭이로 업화석 개간 드랍 2", not res_e.is_empty() and int(res_e["count"]) == 2 and r.is_cleared(te))

	# ── ③ 틀린 도구 무동작 ──
	var tw2 := Vector2i(56, 38)
	_check("③ 곡괭이로 잡초 무동작", r.clear(tw2, WEEDS, ItemCatalog.PICKAXE).is_empty() and not r.is_cleared(tw2))
	_check("③ 낫으로 석화고목 무동작", r.clear(Vector2i(9, 30), STUMP, ItemCatalog.SCYTHE).is_empty())

	# ── ④ 멱등(이미 치운 것 재개간) ──
	var cnt := r.cleared_count()
	_check("④ 이미 치운 것 재개간 {}", r.clear(tw, WEEDS, ItemCatalog.SCYTHE).is_empty())
	_check("④ cleared_count 불변", r.cleared_count() == cnt)

	# ── ⑤ 미지 kind 방어 ──
	_check("⑤ 미지 kind clear {}", r.clear(Vector2i(1, 1), "void", ItemCatalog.SCYTHE).is_empty())

	# ── ⑥ 세이브 왕복 ──
	var saved := r.to_save()
	var r2 := Reclaim.new()
	r2.load_save(saved)
	_check("⑥ 세이브 왕복 집합 보존", r2.cleared_count() == r.cleared_count() \
		and r2.is_cleared(tw) and r2.is_cleared(te) and not r2.is_cleared(tw2))
	r.free()
	r2.free()

	# ── ⑪~⑯ 차등 재점령(ADR-0055) 단위 검증 ──────────────────────────────────────
	var SCY := ItemCatalog.SCYTHE
	# 후보 8칸(main이 걸러 준 자격 빈 맨땅을 흉내). cap = ceil(8×0.75) = 6.
	var cands := [Vector2i(30, 20), Vector2i(31, 20), Vector2i(32, 20), Vector2i(33, 20),
		Vector2i(30, 21), Vector2i(31, 21), Vector2i(32, 21), Vector2i(33, 21)]

	# ⑪ 밤당 1~2칸 재점령·후보 안에서만·결정적
	var ra := Reclaim.new()
	var added := ra.advance_day(cands, 1, false)
	var all_in := true
	for t in added:
		if not t in cands:
			all_in = false
	_check("⑪ 밤당 1~2칸 재점령", added.size() >= Reclaim.RESPAWN_MIN and added.size() <= Reclaim.RESPAWN_MAX)
	_check("⑪ 재점령은 후보 안에서만", all_in and ra.weed_count() == added.size())
	var rb := Reclaim.new()
	var added_b := rb.advance_day(cands, 1, false)
	var same := added.size() == added_b.size()
	for t in added:
		if not rb.has_weed(t):
			same = false
	_check("⑪ 같은 날·후보 → 결정적 동일", same)

	# ⑫ 겨울(잿눈) 게이트 — 재점령 정지
	var rw := Reclaim.new()
	_check("⑫ 겨울엔 재점령 정지(빈 배열)", rw.advance_day(cands, 1, true).is_empty() and rw.weed_count() == 0)

	# ⑬ 후보 없음 방어
	_check("⑬ 후보 0 → 무동작", Reclaim.new().advance_day([], 1, false).is_empty())

	# ⑭ 총상한(cap=6)·이미 돋은 칸 재선정 안 함 — 여러 밤 누적
	var rc := Reclaim.new()
	for d in range(1, 40):
		rc.advance_day(cands, d, false)
	var cap := int(ceil(cands.size() * Reclaim.RESPAWN_CAP_RATIO))
	var weeds_in := true
	for t in rc.weed_tiles():
		if not t in cands:
			weeds_in = false
	_check("⑭ 총상한 초과 안 함(≤ cap=6)", rc.weed_count() <= cap)
	_check("⑭ 누적 재점령이 상한 도달", rc.weed_count() == cap)
	_check("⑭ 재점령은 늘 후보 부분집합", weeds_in)

	# ⑮ 낫으로 잡초 베기 — 드랍·has_weed·틀린 도구·무잡초 방어
	var wtile: Vector2i = rc.weed_tiles()[0]
	var wres := rc.clear_weed(wtile, SCY)
	_check("⑮ 낫으로 잡초 베기 성공(혼백섬유×1)", not wres.is_empty() and str(wres["drop"]) == ItemCatalog.SOUL_FIBER \
		and int(wres["count"]) == 1 and not rc.has_weed(wtile))
	var wtile2: Vector2i = rc.weed_tiles()[0]
	_check("⑮ 곡괭이로 잡초 무동작(낫만)", rc.clear_weed(wtile2, ItemCatalog.PICKAXE).is_empty() and rc.has_weed(wtile2))
	_check("⑮ 잡초 없는 칸 clear_weed {}", rc.clear_weed(Vector2i(99, 99), SCY).is_empty())

	# ⑯ 세이브 왕복 — 치운 것 + 재점령 잡초 둘 다 보존
	var rs := Reclaim.new()
	rs.clear(Vector2i(50, 22), WEEDS, SCY)                # _cleared 하나
	rs.advance_day([Vector2i(40, 40), Vector2i(41, 40)], 7, false)  # _weeds 채움
	var wsaved := rs.weed_tiles().duplicate()
	var rs2 := Reclaim.new()
	rs2.load_save(rs.to_save())
	var weeds_ok := rs2.weed_count() == rs.weed_count()
	for t in wsaved:
		if not rs2.has_weed(t):
			weeds_ok = false
	_check("⑯ 세이브 왕복 잡초+개간 둘 다 보존", weeds_ok and rs2.is_cleared(Vector2i(50, 22)))
	ra.free(); rb.free(); rw.free(); rc.free(); rs.free(); rs2.free()

	# ── Part B: main 통합(⑦~⑩) — 신규 게임 강제(세이브 백업·삭제) ──
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	var m := await _spawn_main()

	# ⑦ START_TOOLS 개간 3종(소프트락 0)
	_check("⑦ reclaim 노드 스폰", m.reclaim != null)
	_check("⑦ START 개간 도구 3종", m.inventory.has_item(ItemCatalog.SCYTHE) \
		and m.inventory.has_item(ItemCatalog.PICKAXE) and m.inventory.has_item(ItemCatalog.AXE))

	# ⑧ 하드게이트 debris kind 조회
	var gate_e := Vector2i(9, 28)    # ★[단계3] 남향 게이트 업화석 발치(옛 동향 24,14 → 90° 회전)
	var gate_s := Vector2i(9, 30)    # ★[단계3] 남향 게이트 석화고목 접근로(옛 동향 24,16)
	_check("⑧ 하드게이트 (9,28)=업화석", m._debris_kind_at(gate_e) == DebrisCatalog.EMBER)
	_check("⑧ 하드게이트 (9,30)=석화고목", m._debris_kind_at(gate_s) == DebrisCatalog.STUMP)

	# ⑨ end-to-end — 곡괭이 선택 후 _use_tool로 하드게이트 업화석 개간
	var pick_idx := _slot_of(m.inventory, ItemCatalog.PICKAXE)
	m.inventory.select(pick_idx)
	var farmable_before: bool = m._is_farmable(gate_e)
	var coll_before: int = m._prop_body.get_children().size()
	var shard_before: int = m.inventory.count_of(ItemCatalog.EMBER_SHARD)
	m._target = gate_e
	m._use_tool()
	_check("⑨ 곡괭이 선택 확인", m.inventory.selected_id() == ItemCatalog.PICKAXE)
	_check("⑨ 개간 후 is_cleared", m.reclaim.is_cleared(gate_e))
	_check("⑨ 개간 전 비-farmable → 후 farmable(경작지 확장)", not farmable_before and m._is_farmable(gate_e))
	_check("⑨ 드랍 업화석조각 ×2 적재", m.inventory.count_of(ItemCatalog.EMBER_SHARD) == shard_before + 2)
	_check("⑨ 개간 후 debris_kind_at \"\"", m._debris_kind_at(gate_e) == "")
	# 충돌 재구성은 _rebuild_prop_collision의 queue_free(지연)라 프레임을 넘겨 구 노드가 빠진 뒤 카운트한다.
	await process_frame
	_check("⑨ 충돌 제거(통과 가능)", m._prop_body.get_children().size() < coll_before)

	# ⑨' 개간한 타일 괭이질(경작지 확장 실사용) — farm.hoe 통과
	_check("⑨' 개간 타일 괭이질 성공", m.farm.hoe(gate_e) and m.farm.is_tilled(gate_e))

	# ⑩ 스타터 패치 debris 0
	var patch: Rect2i = m.STARTER_PATCH_RECT
	var patch_clean := true
	for y in range(patch.position.y, patch.position.y + patch.size.y):
		for x in range(patch.position.x, patch.position.x + patch.size.x):
			if m._debris_kind_at(Vector2i(x, y)) != "":
				patch_clean = false
	_check("⑩ 스타터 패치 debris 0", patch_clean)

	# ── ⑰~⑱ 재점령 main 통합(ADR-0055) ──────────────────────────────────────────
	# ⑰ _encroach_candidates — 자격 빈 맨땅만(SOIL·프롭·개간 자리·밭 배제)
	var cand: Array = m._encroach_candidates()
	var scan: Rect2i = m.ENCROACH_SCAN_RECT
	var cand_ok := cand.size() > 0
	for t in cand:
		if m._grid[t.y][t.x] != m.GROUND or not scan.has_point(t):
			cand_ok = false
	_check("⑰ 후보 비어있지 않음·전부 GROUND·스캔 안", cand_ok)
	_check("⑰ debris 잡초 자리(50,22) 후보 아님(프롭 점유)", not (Vector2i(50, 22) in cand))
	_check("⑰ 스타터 패치(40,12) 후보 아님(SOIL/밖)", not (Vector2i(40, 12) in cand))

	# ⑱ end-to-end — advance_day로 잡초 재점령 → 낫으로 베기(드랍 적립·has_weed 해제)
	var weeds_added: Array = m.reclaim.advance_day(cand, 3, false)
	_check("⑱ advance_day 잡초 1개 이상 재점령", weeds_added.size() >= 1)
	if weeds_added.size() >= 1:
		var wt: Vector2i = weeds_added[0]
		var scy_idx := _slot_of(m.inventory, ItemCatalog.SCYTHE)
		m.inventory.select(scy_idx)
		var fiber_before: int = m.inventory.count_of(ItemCatalog.SOUL_FIBER)
		m._target = wt
		m._use_tool()
		_check("⑱ 낫으로 재점령 잡초 베기 → has_weed 해제", not m.reclaim.has_weed(wt))
		_check("⑱ 혼백섬유 ×1 적재", m.inventory.count_of(ItemCatalog.SOUL_FIBER) == fiber_before + 1)

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
const BAK := "user://save.dat.reclaim.bak"

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
