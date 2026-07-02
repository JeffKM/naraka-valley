extends SceneTree

# ★ [S1-9 / greybox-spec §11] 집 꾸미기(집 내부 3레이어 코스메틱·테마 세트) 격리 검증.
#
# 무엇을 보나(S1-9 = 바닥재·벽지·가구 3레이어 자유 배치 + 테마 세트 무한 팔레트 + 세이브 + 순수 코스메틱):
#   Part A(HomeDecoCatalog/HomeDeco 단위, main 불필요):
#     ① 카탈로그 커버리지 — 2세트 각각 3레이어 전부에 ≥1 아이템 · 모든 item layer∈{FLOOR,WALL,FURNITURE}+is_solid bool.
#     ② 해금 게이팅 — 잠긴 세트 배치 거부 · 해금 세트 수락.
#     ③ 원장 — 3레이어 배치 · 같은 레이어 같은 셀 overwrite · 레이어 간 같은 셀 공존 · 삭제 · 회전(0..3 순환).
#     ④ 배치 경계 — 룸 밖·비바닥 칸 FLOOR/FURNITURE 거부 · 벽 밴드 밖 WALL 거부(레이어별 경계).
#     ⑤ 버프 0(검증기 이빨) — 곱셈기/보너스 반환 메서드 부재 · deco_summary 순수 카운트 스칼라.
#     ⑥ 세이브 왕복 — 해금·3레이어 배치 보존.
#   Part B(main 스폰, 신규 게임 강제):
#     ⑦ START 스타터 2세트 해금 · 경계 주입 동작.
#     ⑧ 앰비언트 스텁 — 안 꾸민 집 진입 무발화 / 꾸민 집 진입 "집이 아늑하다" 발화.
#     ⑨ 세트 간 믹스 배치(혼불 가구 + 피안화 바닥) → 세이브→리로드 영속(해금+3레이어).
#     ⑩ 버프 0 end-to-end — 배치 전후 energy·wallet·farming_xp 불변.
#
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
	print("▶ home_deco_test (S1-9)")
	var Cat := HomeDecoCatalog
	var L_F := Cat.L_FLOOR
	var L_W := Cat.L_WALL
	var L_U := Cat.L_FURNITURE

	# ── ① 카탈로그 커버리지(§11.3) ──
	var cover_ok := true
	var item_ok := true
	for sid in Cat.set_ids():
		if Cat.items_of_layer(sid, L_F).is_empty() or Cat.items_of_layer(sid, L_W).is_empty() \
				or Cat.items_of_layer(sid, L_U).is_empty():
			cover_ok = false
		for key in Cat.SETS[sid]["items"]:
			var it: Dictionary = Cat.SETS[sid]["items"][key]
			if not Cat.is_layer(str(it.get("layer", ""))) or typeof(it.get("is_solid")) != TYPE_BOOL:
				item_ok = false
	_check("① 2세트 각 3레이어 전부 커버", cover_ok and Cat.set_ids().size() == 2)
	_check("① 모든 item layer 유효 + is_solid bool", item_ok)
	_check("① 스타터 2세트 = 정의 세트", Cat.STARTER_SETS.size() == 2 \
		and Cat.has_set(Cat.STARTER_SETS[0]) and Cat.has_set(Cat.STARTER_SETS[1]))
	_check("① 미지 세트/아이템 방어", not Cat.has_set("VOID") and Cat.layer_of("VOID", "x") == "" \
		and Cat.item("SOULFIRE", "nope").is_empty())

	# ── HomeDeco 스크래치 원장(스크래치 경계 주입) ──
	var h := HomeDeco.new()
	var fc := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]   # 바닥/가구 유효 칸
	var wc := [Vector2i(0, 5), Vector2i(1, 5)]                                    # 벽지 유효 칸
	h.set_bounds(fc, wc)

	# ── ② 해금 게이팅(§11.4) ──
	_check("② 미해금 세트 배치 거부", not h.place(Vector2i(0, 0), "SOULFIRE", "sf_floor"))
	h.unlock("SOULFIRE")
	h.unlock("HIGANBANA")
	_check("② 해금 후 배치 수락", h.place(Vector2i(0, 0), "SOULFIRE", "sf_floor"))
	_check("② 미지 세트 unlock 무시", not h.is_unlocked("VOID"))

	# ── ③ 원장(§11.2·§11.7) ──
	_check("③ 바닥재 배치 조회", h.item_at(L_F, Vector2i(0, 0))["item"] == "sf_floor")
	# 같은 레이어 같은 셀 overwrite
	h.place(Vector2i(0, 0), "HIGANBANA", "hb_floor")
	_check("③ 같은 레이어 같은 셀 overwrite", h.item_at(L_F, Vector2i(0, 0))["item"] == "hb_floor" \
		and h.layer_dict(L_F).size() == 1)
	# 레이어 간 같은 셀 공존
	_check("③ 가구 배치(같은 셀)", h.place(Vector2i(0, 0), "SOULFIRE", "sf_bed", 2))
	_check("③ 레이어 간 같은 셀 공존", not h.item_at(L_F, Vector2i(0, 0)).is_empty() \
		and not h.item_at(L_U, Vector2i(0, 0)).is_empty())
	# 벽지 배치(벽 밴드 칸)
	_check("③ 벽지 배치(벽 밴드)", h.place(Vector2i(0, 5), "SOULFIRE", "sf_wall"))
	# 삭제(현재 레이어만)
	_check("③ 바닥재 삭제", h.remove(L_F, Vector2i(0, 0)) and h.item_at(L_F, Vector2i(0, 0)).is_empty())
	_check("③ 삭제 후 가구는 잔존", not h.item_at(L_U, Vector2i(0, 0)).is_empty())
	_check("③ 없는 칸 삭제 false", not h.remove(L_F, Vector2i(9, 9)))
	# 회전(가구, 0..3 순환) — sf_bed는 rot 2로 놓임
	_check("③ 회전 2→3", h.rotate_furniture(Vector2i(0, 0)) == 3)
	_check("③ 회전 3→0 순환", h.rotate_furniture(Vector2i(0, 0)) == 0)
	_check("③ 가구 없는 칸 회전 -1", h.rotate_furniture(Vector2i(3, 0)) == -1)

	# ── ④ 배치 경계(§11.2) ──
	_check("④ 바닥 밖 칸 거부", not h.place(Vector2i(9, 9), "SOULFIRE", "sf_floor"))
	_check("④ 가구 밖 칸 거부", not h.place(Vector2i(9, 9), "SOULFIRE", "sf_bed"))
	_check("④ 벽지를 바닥 칸에 거부(레이어별 경계)", not h.place(Vector2i(1, 0), "SOULFIRE", "sf_wall"))
	_check("④ 바닥재를 벽 밴드 칸에 거부", not h.place(Vector2i(0, 5), "SOULFIRE", "sf_floor"))

	# ── ⑤ 버프 0(검증기 이빨, §11.6) ──
	_check("⑤ 곱셈기/보너스 반환 메서드 부재", not h.has_method("multiplier") and not h.has_method("bonus") \
		and not h.has_method("rate") and not h.has_method("apply_buff"))
	var sm := h.deco_summary()
	_check("⑤ deco_summary 순수 카운트 스칼라", typeof(sm["total"]) == TYPE_INT and typeof(sm["floor"]) == TYPE_INT \
		and typeof(sm["sets"]) == TYPE_INT and not sm.has("multiplier"))
	_check("⑤ is_decorated 참", h.is_decorated())

	# ── ⑥ 세이브 왕복(§11.7) ──
	var saved := h.to_save()
	var h2 := HomeDeco.new()
	h2.set_bounds(fc, wc)
	h2.load_save(saved)
	_check("⑥ 해금 보존", h2.is_unlocked("SOULFIRE") and h2.is_unlocked("HIGANBANA"))
	_check("⑥ 벽지 배치 보존", h2.item_at(L_W, Vector2i(0, 5))["item"] == "sf_wall")
	_check("⑥ 가구 배치·회전 보존", h2.item_at(L_U, Vector2i(0, 0))["item"] == "sf_bed" \
		and int(h2.item_at(L_U, Vector2i(0, 0))["rot"]) == 0)
	h.free()
	h2.free()

	# ── Part B: main 통합(⑦~⑩) — 신규 게임 강제(세이브 백업·삭제) ──
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	var m := await _spawn_main()

	# ⑦ START 스타터 2세트 해금 + 경계 주입
	_check("⑦ home_deco 노드 스폰", m.home_deco != null)
	_check("⑦ START 스타터 2세트 해금", m.home_deco.is_unlocked("SOULFIRE") and m.home_deco.is_unlocked("HIGANBANA"))
	var vf := Vector2i(10, 70)   # 집 룸 유효 바닥 칸
	var vw := Vector2i(10, 67)   # 집 룸 유효 벽 밴드 칸
	_check("⑦ 경계 주입 — 유효 바닥/벽 배치", m.home_deco.place(vf, "SOULFIRE", "sf_floor") \
		and m.home_deco.place(vw, "HIGANBANA", "hb_wall"))
	_check("⑦ 경계 주입 — 룸 밖 거부", not m.home_deco.place(Vector2i(0, 0), "SOULFIRE", "sf_floor"))
	# 다음 앰비언트-네거티브를 위해 방금 배치를 걷어내 '안 꾸민' 상태로 되돌린다.
	m.home_deco.remove("floor", vf)
	m.home_deco.remove("wall", vw)
	_check("⑦ 원복 후 안 꾸밈", not m.home_deco.is_decorated())

	# ⑧ 앰비언트 스텁(§11.6) — _maybe_toggle_building이 집 진입 시 발화
	m._indoor = ""
	m._transitioning = false
	m._sleeping = false
	m.player.position = m._tile_center_px(m.HOUSE_EXT_DOOR)
	m._maybe_toggle_building()
	_check("⑧ 안 꾸민 집 진입 — 앰비언트 무발화", not _has_notice(m, "집이 아늑하다"))
	# 이제 꾸미고 다시 진입
	m.home_deco.place(vf, "SOULFIRE", "sf_floor")
	m._indoor = ""
	m._transitioning = false
	m.player.position = m._tile_center_px(m.HOUSE_EXT_DOOR)
	m._maybe_toggle_building()
	_check("⑧ 꾸민 집 진입 — 앰비언트 발화", _has_notice(m, "집이 아늑하다"))

	# ⑨ 세트 간 믹스 배치 + 세이브→리로드 영속
	m._transitioning = false
	m.home_deco.place(Vector2i(12, 71), "SOULFIRE", "sf_bed", 1)     # 혼불 가구
	m.home_deco.place(Vector2i(11, 70), "HIGANBANA", "hb_rug")        # 피안화 바닥(세트 간 믹스)
	var sm2: Dictionary = m.home_deco.deco_summary()
	_check("⑨ 세트 간 믹스(서로 다른 세트 ≥2)", sm2["sets"] >= 2)
	m._save_game()
	m.home_deco.load_save({})   # 원장 비우기(리로드가 되살리는지 검증)
	_check("⑨ 비운 뒤 배치 0", not m.home_deco.is_decorated() and m.home_deco.unlocked_sets().is_empty())
	m._load_game()
	_check("⑨ 리로드 — 해금 복원", m.home_deco.is_unlocked("SOULFIRE") and m.home_deco.is_unlocked("HIGANBANA"))
	_check("⑨ 리로드 — 바닥재 복원", m.home_deco.item_at("floor", vf)["item"] == "sf_floor")
	_check("⑨ 리로드 — 피안화 러그 복원(세트 믹스)", m.home_deco.item_at("floor", Vector2i(11, 70))["item"] == "hb_rug")
	_check("⑨ 리로드 — 가구·회전 복원", m.home_deco.item_at("furniture", Vector2i(12, 71))["item"] == "sf_bed" \
		and int(m.home_deco.item_at("furniture", Vector2i(12, 71))["rot"]) == 1)

	# ⑩ 버프 0 end-to-end — 배치 전후 능력치·경제 불변
	var e0: int = m.energy.current
	var g0: int = m.wallet.gold
	var xp0: int = m._farming_xp
	m.home_deco.place(Vector2i(13, 72), "SOULFIRE", "sf_lamp")
	m.home_deco.remove("furniture", Vector2i(12, 71))
	m.home_deco.rotate_furniture(Vector2i(13, 72))
	_check("⑩ 배치·삭제·회전 후 energy 불변", m.energy.current == e0)
	_check("⑩ wallet 불변", m.wallet.gold == g0)
	_check("⑩ farming_xp 불변", m._farming_xp == xp0)

	m.queue_free()
	await process_frame
	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		if FileAccess.file_exists(BAK):
			DirAccess.remove_absolute(BAK)

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(1 if _fail > 0 else 0)

# notice_feed 큐에 부분일치 텍스트가 있는가(앰비언트 발화 검사).
func _has_notice(m: Node, needle: String) -> bool:
	for item in m.notice_feed._items:
		if str(item.get("text", "")).find(needle) >= 0:
			return true
	return false

const SAVE := "user://save.dat"
const BAK := "user://save.dat.homedeco.bak"

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
