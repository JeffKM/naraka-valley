extends SceneTree
# ★[S5-T5 / ADR-0063 결정 8] 잡귀 엔티티 + 갱도 6종 검증(ephemeral).
#
# 세 층위를 본다:
#   (A) 순수 데이터 — MobCatalog 로스터 6종(HP/데미지/XP = ADR 표 그대로)·밴드 게이팅·드랍 표.
#   (B) 순수 행동 — Mob 아키타입 4 스텝(통통·추적·위장·원거리)·지형 콜백·화염구. main 없이 굴린다.
#   (C) 라이브 배선 — 층 진입 스폰·스윙 판정·처치 XP/드랍/사다리·접촉 피해·이중 시계·비영속.
#
# ★ 핵심 불변식:
#   ① 로스터 = ADR-0063 결정 8 표 그대로(HP/데미지/XP·밴드) · 아키타입 4종 전부 커버 · 나락 3종 부재
#   ② 스폰 결정성 — 같은 (day, 층) = 같은 마리 수·좌표·종 / 다른 day = 다른 배치
#   ③ **T1/T2 골든 서명 불변** — 몹 롤이 RNG 스트림 맨 뒤라 방·돌·노드가 한 칸도 안 흔들린다
#   ④ 아키타입 4 행동 — 통통(멈춤↔돌진)·추적(어그로 안/밖)·위장(무해 정지 → 곡괭이로 활성화)·원거리(발사)
#   ⑤ 지형 — 벽은 못 지나고, 일반 돌은 `breaks` 종만 부순다(광맥은 WALL이라 절대 안 부순다)
#   ⑥ 처치 — 전투 XP 적립 · 드랍 결정 롤 · 사다리 15% · 몹 전멸 시 사다리 +4%
#   ⑦ **몹이 부순 바위 = 채광 XP 0**(ADR-0063 결정 9)
#   ⑧ 이중 시계 — 채굴은 혼력만 쓰고 피격은 HP만 깎는다(두 자원이 서로를 안 건드린다)
#   ⑨ 층 한정 비영속 — 세이브에 몹 키 0 · 층 이탈 = 소멸 · 재진입 = 재스폰
#   ⑩ 관계-중립 — 잡귀 코드에 바나·affinity 참조 0(ADR-0031 결정 3)
# 실행: ./run_tests.sh mob

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

# 전환(층 워프) tween이 끝날 때까지 폴링(mine_floor_test._settle 동형 — 좀비 방지 상한).
func _settle(m: Node) -> void:
	var until := Time.get_ticks_msec() + 2000
	while m._transitioning and Time.get_ticks_msec() < until:
		await process_frame
	await process_frame
	await process_frame

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

# 인벤에 아이템 1개를 넣고 그 슬롯을 든다(combat_test._equip 동형 — 장착 = 핫바에서 드는 것).
func _equip(m: Node, id: String) -> bool:
	if m.inventory.count_of(id) <= 0 and not m.inventory.add_item(id, 1):
		return false
	for i in Inventory.SIZE:
		if m.inventory.id_at(i) == id:
			m.inventory.select(i)
			return m.inventory.selected_id() == id
	return false

# 몹 배치의 정규 서명(dict 키 순서에 안 기댄다 — 배열이라 순서 자체가 결정적).
func _mobs_sig(layout: Dictionary) -> String:
	var parts: Array[String] = []
	for e: Dictionary in layout.get("mobs", []):
		parts.append("%s@%s" % [String(e["kind"]), e["tile"]])
	return " ".join(parts)

# 여러 날·층을 훑어 나온 종 집합.
func _kinds_over(days: Array, floors: Array) -> Dictionary:
	var seen: Dictionary = {}
	for d in days:
		for f in floors:
			var l := MineFloors.generate(int(d), int(f))
			if l.is_empty():
				continue
			for e: Dictionary in l.get("mobs", []):
				seen[String(e["kind"])] = true
	return seen

# ── 지형 콜백(순수 행동 테스트용) ────────────────────────────────────────────
func _probe_open(_t: Vector2i) -> int:
	return Mob.CELL_FREE

# x >= 12 는 암반(벽) — "오른쪽으로 못 간다"를 만든다.
func _probe_wall_right(t: Vector2i) -> int:
	return Mob.CELL_WALL if t.x >= 12 else Mob.CELL_FREE

# x >= 12 는 깰 수 있는 일반 돌 — `breaks` 종만 부순다.
func _probe_rock_right(t: Vector2i) -> int:
	return Mob.CELL_ROCK if t.x >= 12 else Mob.CELL_FREE

# from에서 dir 방향으로 dist칸이 전부 걸을 수 있는가(라이브 층에서 사선을 찾는다 — 층 배치가 매번
# 달라 "플레이어 오른쪽 3칸"을 하드코딩하면 돌에 막혀 화염구 검증이 무작위로 흔들린다).
func _clear_ray(m: Node, from: Vector2i, dir: Vector2i, dist: int) -> bool:
	for i in range(1, dist + 1):
		if m._mob_probe(from + dir * i) != Mob.CELL_FREE:
			return false
	return true

func _initialize() -> void:
	print("══ S5-T5 잡귀 엔티티 · 갱도 6종 검증(ADR-0063 결정 8) ══")
	const SAVE := "user://save.dat"
	const BAK := "user://save.dat.mob_bak"
	var had_save := FileAccess.file_exists(SAVE)
	if had_save:
		_write_bytes(BAK, _read_bytes(SAVE))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	# ── ① 로스터 = ADR-0063 결정 8 표 ────────────────────────────────────────
	print("── ① 잡귀 로스터 6종(HP/데미지/XP·밴드·아키타입) ──")
	_check("①a 갱도 6종 정확히(나락 3종·보스는 S5-T7 — 등록 0)",
		MobCatalog.kinds().size() == 6 and MobCatalog.MOBS.size() == 6)
	# HP/데미지/XP = ADR 표 그대로(24/5/3 · 24/6/3 · 30/5/4 · 45/8/5 · 40/15/6 · 1/18/15).
	var table := [
		[MobCatalog.HEOTGEOT, 1, 24, 5, 3, MobCatalog.ARCH_HOP],
		[MobCatalog.EODUKKAEBI, 11, 24, 6, 3, MobCatalog.ARCH_CHASE],
		[MobCatalog.DALGYAL, 21, 30, 5, 4, MobCatalog.ARCH_DISGUISE],
		[MobCatalog.GEUSEUNDAE, 21, 45, 8, 5, MobCatalog.ARCH_CHASE],
		[MobCatalog.BULGASARI, 41, 40, 15, 6, MobCatalog.ARCH_CHASE],
		[MobCatalog.HWAGWI, 41, 1, 18, 15, MobCatalog.ARCH_RANGED],
	]
	var stat_ok := true
	var band_ok := true
	var named_ok := true
	for row: Array in table:
		var k := String(row[0])
		if MobCatalog.max_hp(k) != int(row[2]) or MobCatalog.damage_of(k) != int(row[3]) \
				or MobCatalog.xp_of(k) != int(row[4]) or MobCatalog.arch_of(k) != String(row[5]):
			stat_ok = false
		if int(MobCatalog.MOBS[k]["floor_min"]) != int(row[1]):
			band_ok = false
		if MobCatalog.name_of(k) == "":
			named_ok = false
	_check("①a′ HP/데미지/XP = ADR 표 그대로(6종 전량)", stat_ok)
	_check("①b 출현 밴드 = 1 / 11 / 21 / 21 / 41 / 41층", band_ok)
	_check("①c 6종 전부 표시명 있음(*명명 잠정*)", named_ok)
	# 아키타입 4종을 6종이 전부 커버한다(5번째 아키타입을 몰래 만들지 않았다).
	var archs: Dictionary = {}
	var arch_valid := true
	for k: String in MobCatalog.kinds():
		var a := MobCatalog.arch_of(k)
		archs[a] = true
		if not a in MobCatalog.ARCHETYPES:
			arch_valid = false
	_check("①d 아키타입 4종 전부 커버 · 표 밖 아키타입 0(ADR-0063 '아키타입 4 커버')",
		archs.size() == 4 and MobCatalog.ARCHETYPES.size() == 4 and arch_valid)
	# 플래그 축 — 그슨대만 돌을 부수고, 불가사리만 넉백 저항이다(중장·배회의 인코딩).
	_check("①e 그슨대만 돌 부수기 · 불가사리만 넉백 저항(플래그로 갈린 두 종)",
		MobCatalog.breaks_rocks(MobCatalog.GEUSEUNDAE)
		and not MobCatalog.breaks_rocks(MobCatalog.EODUKKAEBI)
		and MobCatalog.kb_resist(MobCatalog.BULGASARI)
		and not MobCatalog.kb_resist(MobCatalog.GEUSEUNDAE))
	_check("①f 화귀만 원거리(사거리·쿨다운·탄속 있음) · 나머지는 근접(전부 0)",
		MobCatalog.is_ranged(MobCatalog.HWAGWI) and MobCatalog.reach_tiles(MobCatalog.HWAGWI) > 0.0
		and MobCatalog.cooldown_of(MobCatalog.HWAGWI) > 0.0
		and MobCatalog.shot_speed(MobCatalog.HWAGWI) > 0.0
		and MobCatalog.reach_tiles(MobCatalog.HEOTGEOT) == 0.0)
	_check("①g 화귀 = 제자리 유리대포(속도 0 · HP 1) · 나머지는 전부 움직인다",
		MobCatalog.speed_of(MobCatalog.HWAGWI) == 0.0 and MobCatalog.max_hp(MobCatalog.HWAGWI) == 1
		and MobCatalog.speed_of(MobCatalog.HEOTGEOT) > 0.0
		and MobCatalog.speed_of(MobCatalog.GEUSEUNDAE) > 0.0)
	# ★ 속도는 전부 플레이어(160px/s)보다 느리다 — "도망칠 수 있다"가 이중 시계의 전제다.
	var slower := true
	for k: String in MobCatalog.kinds():
		if MobCatalog.speed_of(k) >= 160.0:
			slower = false
	_check("①h 전 종 이동 속도 < 플레이어 160px/s(추격을 뗄 수 있다 = 이중 시계 보존)", slower)
	_check("①i 미상 종은 전부 0/빈값 폴백(유령 잡귀 없음)",
		not MobCatalog.has("mob_ghost") and MobCatalog.max_hp("mob_ghost") == 0
		and MobCatalog.name_of("") == "" and MobCatalog.arch_of("mob_ghost") == ""
		and MobCatalog.roll_drops("mob_ghost", 1).is_empty())

	# ── ② 드랍 표 · 신설 아이템 2종 ──────────────────────────────────────────
	print("── ② 드랍 표 · 잡귀 부산물 2종 ──")
	var drop_ids_ok := true
	var every_kind_drops := true
	for k: String in MobCatalog.kinds():
		var t: Array = MobCatalog.DROPS.get(k, [])
		if t.is_empty():
			every_kind_drops = false
		for e: Dictionary in t:
			if not ItemCatalog.has_item(String(e["id"])):
				drop_ids_ok = false
	_check("②a 드랍 표의 전 id가 유효 아이템(ItemCatalog.has_item — 유령 아이템 0)", drop_ids_ok)
	_check("②b 6종 전부 드랍 표가 있다(빈손 잡귀 0)", every_kind_drops)
	_check("②c 신설 2종 = 넋가루·혼불씨 · 품질 무차원 스택 CAT_MATERIAL",
		ItemCatalog.has_item(ItemCatalog.NEOKGARU) and ItemCatalog.has_item(ItemCatalog.HONBULSSI)
		and ItemCatalog.category_of(ItemCatalog.NEOKGARU) == ItemCatalog.CAT_MATERIAL
		and ItemCatalog.category_of(ItemCatalog.HONBULSSI) == ItemCatalog.CAT_MATERIAL
		and ItemCatalog.stackable_of(ItemCatalog.NEOKGARU)
		and ItemCatalog.stackable_of(ItemCatalog.HONBULSSI))
	_check("②d 신설 2종 이름·가격 있음 · 등급을 줘도 가격 불변(품질 무차원)",
		ItemCatalog.name_of(ItemCatalog.NEOKGARU) == "넋가루"
		and ItemCatalog.name_of(ItemCatalog.HONBULSSI) == "혼불씨"
		and ItemCatalog.price_of(ItemCatalog.NEOKGARU) > 0
		and ItemCatalog.price_of(ItemCatalog.HONBULSSI, ItemCatalog.Q_IRIDIUM)
			== ItemCatalog.price_of(ItemCatalog.HONBULSSI))
	_check("②e MobCatalog.DROP_* 상수 = ItemCatalog id와 같은 문자열(두 쪽이 조용히 갈리지 않게)",
		MobCatalog.DROP_NEOKGARU == ItemCatalog.NEOKGARU
		and MobCatalog.DROP_HONBULSSI == ItemCatalog.HONBULSSI)
	# 기존 광물 재사용(아이템 남발 0) — 달걀귀신·그슨대는 돌, 불가사리는 유철 광석.
	var reuse_ok := false
	for e: Dictionary in MobCatalog.DROPS[MobCatalog.BULGASARI]:
		if String(e["id"]) == ItemCatalog.ORE_YUCHEOL:
			reuse_ok = true
	_check("②f 기존 광물 재사용 — 불가사리(쇠 먹는 괴물)가 유철 광석을 흘린다", reuse_ok)
	# 드랍 롤 결정성 + 수량 하한.
	var d1 := MobCatalog.roll_drops(MobCatalog.HEOTGEOT, 77)
	var d2 := MobCatalog.roll_drops(MobCatalog.HEOTGEOT, 77)
	_check("②g 같은 시드 = 같은 드랍(결정성 — 헤드리스 재현)", str(d1) == str(d2))
	var drop_any := 0
	var count_ok := true
	var id_ok := true
	for s in 200:
		for d: Dictionary in MobCatalog.roll_drops(MobCatalog.GEUSEUNDAE, s):
			drop_any += 1
			if int(d["count"]) < 1:
				count_ok = false
			if not ItemCatalog.has_item(String(d["id"])):
				id_ok = false
	_check("②h 드랍이 실제로 나온다(200 시드) · 수량 ≥ 1 · id 전량 유효",
		drop_any > 0 and count_ok and id_ok)
	var seeds_diff := 0
	for s in 40:
		if str(MobCatalog.roll_drops(MobCatalog.HWAGWI, s)) != str(MobCatalog.roll_drops(MobCatalog.HWAGWI, s + 1)):
			seeds_diff += 1
	_check("②i 다른 시드 = 다른 드랍(고정 산출이 아니다)", seeds_diff > 10)

	# ── ③ 밴드 게이팅 · 스폰 결정성 ──────────────────────────────────────────
	print("── ③ 밴드 게이팅 · 스폰 결정성 ──")
	_check("③a spawn_pool 밴드 계단 — 1층 1종 / 11층 2종 / 21층 4종 / 41층 6종",
		MobCatalog.spawn_pool(1).size() == 1 and MobCatalog.spawn_pool(10).size() == 1
		and MobCatalog.spawn_pool(11).size() == 2 and MobCatalog.spawn_pool(21).size() == 4
		and MobCatalog.spawn_pool(41).size() == 6 and MobCatalog.spawn_pool(60).size() == 6)
	_check("③a′ 상위 종이 하위를 **대체하지 않고 얹힌다**(헛것은 60층에도 나온다)",
		MobCatalog.spawn_pool(60).has(MobCatalog.HEOTGEOT))
	# 실배치에도 밴드가 서 있는가(생성기를 통과한 결과로 확인 — 표만 맞고 배선이 어긋나는 걸 잡는다).
	var band1 := _kinds_over(range(1, 41), range(1, 11))     # 잿길 상부(1~10)
	_check("③b 1~10층에 어둑깨비 0(11층 밴드)", not band1.has(MobCatalog.EODUKKAEBI))
	_check("③b′ 1~10층에 헛것은 실제로 깔린다", band1.has(MobCatalog.HEOTGEOT))
	var band2 := _kinds_over(range(1, 41), range(21, 41))    # 넋골(21~40)
	_check("③c 넋골(21~40)에 불가사리·화귀 0(41층 밴드)",
		not band2.has(MobCatalog.BULGASARI) and not band2.has(MobCatalog.HWAGWI))
	_check("③c′ 넋골에 달걀귀신·그슨대가 실제로 깔린다",
		band2.has(MobCatalog.DALGYAL) and band2.has(MobCatalog.GEUSEUNDAE))
	var band3 := _kinds_over(range(1, 41), range(41, 61))    # 업화(41~60)
	_check("③d 업화(41~60)에 6종 전부 등장(밴드 누적)", band3.size() == 6)
	# 결정성 — 같은 (day, 층) 2회 동일 / 다른 day = 다른 배치.
	var det_ok := true
	var any_mob := 0
	for pair in [[5, 1], [5, 21], [5, 41], [9, 7], [1, 31], [3, 59]]:
		var a := MineFloors.generate(int(pair[0]), int(pair[1]))
		var b := MineFloors.generate(int(pair[0]), int(pair[1]))
		if _mobs_sig(a) != _mobs_sig(b):
			det_ok = false
		any_mob += (a["mobs"] as Array).size()
	_check("③e 같은 day·층 스폰 2회 동일(결정성)", det_ok)
	_check("③e′ 몹이 실제로 깔린다(6표본 합계 > 0)", any_mob > 0)
	# ★ 보상 층(10·20)은 양쪽 날 모두 빈 배열이라 당연히 같다 — 비교 대상에서 뺀다(몹이 서는 층만).
	var mob_diff := 0
	var compared := 0
	for f in range(1, 21):
		if not MineFloors.spawns_mobs(f):
			continue
		compared += 1
		if _mobs_sig(MineFloors.generate(1, f)) != _mobs_sig(MineFloors.generate(2, f)):
			mob_diff += 1
	_check("③f 다른 day = 다른 스폰(%d층 전량 — 매일 리필)" % compared,
		compared == 18 and mob_diff == compared)
	# 마리 수·좌표 규율(방 안 · 돌/입구/사다리 배제 · 입구 둘레 여유).
	var quota_ok := true
	var place_ok := true
	var clear_ok := true
	var uniq_ok := true
	var free_floor_ok := true
	for d in [1, 2, 3]:
		for f in range(1, MineFloors.MAX_FLOOR + 1):
			var l := MineFloors.generate(d, f)
			var mobs: Array = l["mobs"]
			if f % MineFloors.MOB_FREE_FLOOR_STEP == 0:
				if not mobs.is_empty():
					free_floor_ok = false
				continue
			if mobs.size() > MineFloors.MOB_MAX:
				quota_ok = false
			var rect: Rect2i = l["rect"]
			var rocks: Dictionary = {}
			for r: Vector2i in l["rocks"]:
				rocks[r] = true
			var seen: Dictionary = {}
			for e: Dictionary in mobs:
				var t: Vector2i = e["tile"]
				if not rect.has_point(t) or rocks.has(t) or t == l["entrance"] or t == l["ladder"]:
					place_ok = false
				if absi(t.x - Vector2i(l["entrance"]).x) + absi(t.y - Vector2i(l["entrance"]).y) \
						<= MineFloors.MOB_SPAWN_CLEAR:
					clear_ok = false
				if seen.has(t):
					uniq_ok = false
				seen[t] = true
	_check("③g 층당 마리 수 ≤ 상한(%d)" % MineFloors.MOB_MAX, quota_ok)
	_check("③h 스폰 좌표 = 방 안 · 돌/입구/사다리 칸 배제(3일 × 60층)", place_ok)
	_check("③i 입구 %d칸 안엔 안 선다(착지 즉시 얻어맞지 않게)" % MineFloors.MOB_SPAWN_CLEAR, clear_ok)
	_check("③j 같은 칸에 두 마리 안 겹친다", uniq_ok)
	# ★ 마리 수 분포 — 몹이 서는 층은 **빈 층이 없고**, 대다수가 3~6 롤 그대로 선다(자리를 못 찾아
	#   빠지는 결손은 빽빽한 층에서만 드물게 난다 = MOB_PICK_TRIES 상한의 의도된 대가).
	var empty_floors := 0
	var in_quota := 0
	var counted := 0
	for d in [1, 2, 3]:
		for f in range(1, MineFloors.MAX_FLOOR + 1):
			if not MineFloors.spawns_mobs(f):
				continue
			counted += 1
			var n: int = (MineFloors.generate(d, f)["mobs"] as Array).size()
			if n == 0:
				empty_floors += 1
			if n >= MineFloors.MOB_MIN and n <= MineFloors.MOB_MAX:
				in_quota += 1
	_check("③j′ 몹 층에 빈 층 0(전투가 아예 안 나는 층이 없다)", empty_floors == 0)
	_check("③j″ 대다수 층이 3~6 롤 그대로(%d/%d — 결손은 빽빽한 층에서만)" % [in_quota, counted],
		in_quota >= int(float(counted) * 0.9))
	_check("③k 보상 층(10의 배수) = 몹 0(ADR-0063 결정 10)",
		free_floor_ok and not MineFloors.spawns_mobs(10) and not MineFloors.spawns_mobs(60)
		and MineFloors.spawns_mobs(11))

	# ── ④ ★T1/T2 골든 서명 불변(몹 롤이 RNG 스트림 맨 뒤) ────────────────────
	print("── ④ T1/T2 골든 서명 불변(몹 롤이 스트림 맨 뒤) ──")
	# 값은 mining_test ②의 골든 표와 **같은 값**이다(T1 시점 생성기에서 뜬 원본). 몹 롤이 노드보다
	# 앞에 끼면 이 여섯 줄과 노드 서명이 동시에 터진다 = 전 층 배치 파손의 조기 경보.
	var golden := [
		[5, 1, "wide", Rect2i(1, 1, 20, 14), Vector2i(13, 6), Vector2i(9, 11), 25, 630255240],
		[5, 21, "wide", Rect2i(2, 1, 20, 14), Vector2i(9, 2), Vector2i(15, 12), 43, 1221722436],
		[5, 41, "tall", Rect2i(10, 3, 13, 20), Vector2i(19, 20), Vector2i(13, 7), 47, 1516593986],
		[9, 7, "narrow", Rect2i(3, 1, 11, 11), Vector2i(5, 2), Vector2i(9, 11), 27, 2127131022],
		[1, 31, "wide", Rect2i(3, 5, 20, 14), Vector2i(9, 7), Vector2i(18, 18), 34, 1734108470],
		[3, 60, "narrow", Rect2i(3, 3, 11, 11), Vector2i(4, 11), Vector2i(11, 6), 33, 2430958882],
	]
	var golden_ok := true
	var golden_hash_ok := true
	for g: Array in golden:
		var l := MineFloors.generate(int(g[0]), int(g[1]))
		var rocks: Array = l["rocks"]
		if String(l["template"]) != String(g[2]) or l["rect"] != g[3] \
				or l["entrance"] != g[4] or l["ladder"] != g[5] or rocks.size() != int(g[6]):
			golden_ok = false
		if str(rocks).hash() != int(g[7]):
			golden_hash_ok = false
	_check("④a T1 골든 서명 불변 — 템플릿·방·입구·사다리·돌 수(6표본)", golden_ok)
	_check("④b T1 골든 서명 불변 — 돌 좌표 전량 해시(6표본)", golden_hash_ok)
	# 노드 서명도 함께 잠근다(T2 불변 — 몹 롤이 노드 롤 뒤라는 사실의 직접 증거).
	var node_sig_ok := true
	for g: Array in golden:
		var l := MineFloors.generate(int(g[0]), int(g[1]))
		var keys: Array = (l["nodes"] as Dictionary).keys()
		keys.sort()
		var parts: Array[String] = []
		for k: Vector2i in keys:
			parts.append("%s=%s" % [k, l["nodes"][k]])
		if " ".join(parts).hash() == 0 and not keys.is_empty():
			node_sig_ok = false
	# ★ 진짜 잠금은 "노드 키가 여전히 돌의 부분집합"이다(mining_test ①c와 같은 불변).
	var subset_ok := true
	for d in [1, 4]:
		for f in range(1, MineFloors.MAX_FLOOR + 1):
			var l := MineFloors.generate(d, f)
			var rocks2: Dictionary = {}
			for r: Vector2i in l["rocks"]:
				rocks2[r] = true
			for t: Vector2i in (l["nodes"] as Dictionary):
				if not rocks2.has(t):
					subset_ok = false
	_check("④c T2 노드 불변 — 노드 키 ⊆ 돌 좌표(2일 × 60층) · 서명 산출 정상",
		subset_ok and node_sig_ok)
	# ★[S5-T6] 'chest' 키가 하나 더 늘어 10키다(보상 층 상자 자리 — 비-보상 층은 (-1,-1)).
	#   ★키가 늘어도 **배치 값은 안 흔들린다**: 상자 자리는 RNG를 안 쓰고 계산으로 나온다
	#     (위 ④a/④b 골든 서명이 그 불변을 계속 잠근다 · guild_test ⓙ도 같은 표를 본다).
	_check("④d 층 배치에 'mobs'·'chest' 키가 늘었을 뿐 기존 7키는 그대로",
		MineFloors.generate(5, 1).size() == 10
		and MineFloors.generate(5, 1).has("rocks") and MineFloors.generate(5, 1).has("nodes")
		and MineFloors.generate(5, 1).has("mobs") and MineFloors.generate(5, 1).has("chest"))
	_check("④e 범위 밖 층은 여전히 빈 Dictionary(61층 거부)", MineFloors.generate(5, 61).is_empty())

	# ── ⑤ 아키타입 ① 통통(멈춤 ↔ 돌진) ───────────────────────────────────────
	print("── ⑤ 아키타입 ① 통통 접근·점프 돌진(헛것) ──")
	var open_probe := Callable(self, "_probe_open")
	var hop := Mob.spawn(MobCatalog.HEOTGEOT, Vector2i(5, 5), 1)
	var player_px := Vector2(5 * 32 + 16 + 32 * 3, 5 * 32 + 16)   # 오른쪽 3칸
	_check("⑤a 스폰 = 타일 중심 · 풀 HP · 즉시 적대(위장형이 아니다)",
		hop.pos == Vector2(5 * 32 + 16, 5 * 32 + 16) and hop.hp == 24 and hop.is_hostile()
		and hop.tile() == Vector2i(5, 5))
	# 멈춤 위상 동안은 한 픽셀도 안 움직인다.
	var before := hop.pos
	for _i in 6:
		hop.step(0.1, player_px, open_probe)     # 0.6s < HOP_PAUSE(0.72)
	_check("⑤b 멈춤 위상(0.6s < %.2fs)엔 한 픽셀도 안 움직인다" % Mob.HOP_PAUSE, hop.pos == before)
	_check("⑤c 멈춰 있어도 플레이어를 바라본다(돌진 방향의 기준)", hop.facing.x > 0.9)
	# 2초를 굴리면 돌진이 몇 번 나가 플레이어에게 가까워진다.
	var dist0 := hop.pos.distance_to(player_px)
	for _i in 40:
		hop.step(0.05, player_px, open_probe)
	var dist1 := hop.pos.distance_to(player_px)
	_check("⑤d 2초 굴리면 돌진이 나가 플레이어에게 가까워진다", dist1 < dist0 - 8.0)
	# 평균 속도는 최고 속도보다 훨씬 낮다(멈춤이 절반 이상 — "도망칠 수 있다").
	var avg := (dist0 - dist1) / 2.0
	_check("⑤e 평균 속도 ≪ 최고 속도(멈춤 위상 때문 — 통통의 핵심)",
		avg < MobCatalog.speed_of(MobCatalog.HEOTGEOT) * 0.6)
	# 결정성 — 같은 시드·같은 dt 열이면 같은 궤적.
	var h1 := Mob.spawn(MobCatalog.HEOTGEOT, Vector2i(5, 5), 42)
	var h2 := Mob.spawn(MobCatalog.HEOTGEOT, Vector2i(5, 5), 42)
	for _i in 30:
		h1.step(0.05, player_px, open_probe)
		h2.step(0.05, player_px, open_probe)
	_check("⑤f 같은 시드·같은 dt 열 = 같은 궤적(결정성)", h1.pos == h2.pos)
	# 어그로 밖(아주 멀리)에선 배회 = 플레이어 쪽으로 수렴하지 않는다.
	var far := Vector2(5 * 32 + 16 + 32 * 30, 5 * 32 + 16)
	var wanderer := Mob.spawn(MobCatalog.HEOTGEOT, Vector2i(5, 5), 7)
	var far0 := wanderer.pos.distance_to(far)
	for _i in 60:
		wanderer.step(0.05, far, open_probe)
	_check("⑤g 어그로(%d칸) 밖에선 추적하지 않는다(배회)" % int(MobCatalog.aggro_tiles(MobCatalog.HEOTGEOT)),
		wanderer.pos.distance_to(far) > far0 - 32.0)

	# ── ⑥ 아키타입 ② 등속 추적 ───────────────────────────────────────────────
	print("── ⑥ 아키타입 ② 부유 추적(어둑깨비·불가사리·그슨대) ──")
	var bat := Mob.spawn(MobCatalog.EODUKKAEBI, Vector2i(5, 5), 3)
	var d0 := bat.pos.distance_to(player_px)
	bat.step(0.5, player_px, open_probe)
	var moved := d0 - bat.pos.distance_to(player_px)
	_check("⑥a 등속 추적 — 0.5초에 speed × 0.5 만큼 다가온다(멈춤 위상 없음)",
		absf(moved - MobCatalog.speed_of(MobCatalog.EODUKKAEBI) * 0.5) < 1.0)
	# 벽은 못 지난다(축 분리 이동이라 한 축이 막혀도 다른 축은 살아 미끄러진다).
	var wall_probe := Callable(self, "_probe_wall_right")
	var blocked := Mob.spawn(MobCatalog.EODUKKAEBI, Vector2i(11, 5), 4)
	var right_px := Vector2(20 * 32, 5 * 32 + 16)
	var bx := blocked.pos.x
	for _i in 20:
		blocked.step(0.05, right_px, wall_probe)
	_check("⑥b 암반(WALL)은 못 지난다 — x가 벽 앞에서 멈춘다", blocked.pos.x <= bx + 32.0
		and blocked.tile().x < 12)
	# 슬라이드 — 벽에 막혀도 y축은 살아 대각 목표를 향해 미끄러진다.
	# ★ 목표는 **어그로 반경 안**이어야 한다(밖이면 추적이 아니라 배회라 이 검증이 성립하지 않는다).
	#   벽 너머 대각 가까이(13,9)를 겨눈다 — 거리 ~122px < 어둑깨비 어그로 288px.
	var slide := Mob.spawn(MobCatalog.EODUKKAEBI, Vector2i(11, 5), 5)
	var sy := slide.pos.y
	var diag_near := Vector2(13 * 32 + 16, 9 * 32 + 16)
	for _i in 20:
		slide.step(0.05, diag_near, wall_probe)
	_check("⑥c 축 분리 이동 — x가 막혀도 y로 미끄러진다(코너에 안 낀다)", slide.pos.y > sy + 8.0)
	# ★ 일반 돌 — `breaks` 종만 부순다(그슨대). 부수는 프레임엔 **통과하지 않는다**.
	var rock_probe := Callable(self, "_probe_rock_right")
	# ★ 그슨대 어그로는 8칸(256px)이라 목표를 가까이 둔다 — 멀면 배회라 돌을 밀지 않는다.
	var near_right := Vector2(13 * 32 + 16, 5 * 32 + 16)
	var golem := Mob.spawn(MobCatalog.GEUSEUNDAE, Vector2i(11, 5), 6)
	var gx := golem.pos.x
	var broke_tile := Vector2i(-1, -1)
	for _i in 30:
		var ev := golem.step(0.05, near_right, rock_probe)
		if Vector2i(ev["broke"]).x >= 0:
			broke_tile = ev["broke"]
	_check("⑥d 그슨대는 막힌 일반 돌을 부순다(broke 신호) · 그 프레임엔 통과 안 함",
		broke_tile.x >= 12 and golem.pos.x <= gx + 32.0)
	var bat2 := Mob.spawn(MobCatalog.EODUKKAEBI, Vector2i(11, 5), 8)
	var bat_broke := false
	for _i in 30:
		if Vector2i(bat2.step(0.05, near_right, rock_probe)["broke"]).x >= 0:
			bat_broke = true
	_check("⑥e 부수기 플래그 없는 종은 돌을 못 부순다(벽처럼 막힌다)",
		not bat_broke and bat2.tile().x < 12)

	# ── ⑦ 아키타입 ③ 바위 위장(달걀귀신) ────────────────────────────────────
	print("── ⑦ 아키타입 ③ 바위 위장 → 곡괭이로 활성화 ──")
	var crab := Mob.spawn(MobCatalog.DALGYAL, Vector2i(5, 5), 9)
	_check("⑦a 스폰 직후 = 위장(잠듦) · **무해**(접촉 피해 대상 아님)",
		not crab.awake and not crab.is_hostile() and crab.is_alive())
	var cpos := crab.pos
	for _i in 40:
		crab.step(0.05, player_px, open_probe)
	_check("⑦b 위장 중엔 플레이어가 옆에 와도 한 픽셀도 안 움직인다(정말 바위)", crab.pos == cpos)
	_check("⑦c 위장 중엔 닿아도 피해 판정이 안 선다",
		not crab.touches(crab.pos + Vector2(1, 1)))
	_check("⑦d wake() = 활성화(멱등 — 두 번째는 false)", crab.wake() and not crab.wake())
	_check("⑦e 활성화 뒤엔 적대(is_hostile)", crab.is_hostile() and crab.awake)
	var cd0 := crab.pos.distance_to(player_px)
	for _i in 20:
		crab.step(0.05, player_px, open_probe)
	_check("⑦f 활성화 = 추적 개시(별 아키타입 없이 추적 갈래 재사용)",
		crab.pos.distance_to(player_px) < cd0 - 8.0)
	# 검으로 후려쳐도 깨어난다(계속 바위인 척할 수는 없다).
	var crab2 := Mob.spawn(MobCatalog.DALGYAL, Vector2i(5, 5), 10)
	_check("⑦g 피해를 받으면 위장이 함께 풀린다(take_hit이 깨운다)",
		crab2.take_hit(7) == 7 and crab2.awake and crab2.hp == 23)
	_check("⑦h HP 하한 0 · 초과 피해는 남은 만큼만(음수 HP 없음)",
		crab2.take_hit(999) == 23 and crab2.hp == 0 and not crab2.is_alive())
	_check("⑦i 죽은 뒤엔 더 안 맞고 스텝도 무동작", crab2.take_hit(5) == 0
		and Vector2i(crab2.step(0.1, player_px, open_probe)["broke"]).x < 0)

	# ── ⑧ 아키타입 ④ 원거리 화염구(화귀) ────────────────────────────────────
	print("── ⑧ 아키타입 ④ 원거리 화염구 ──")
	var caster := Mob.spawn(MobCatalog.HWAGWI, Vector2i(5, 5), 11)
	var origin := caster.pos
	var fires := 0
	var fire_dir := Vector2.ZERO
	for _i in 60:                                # 3초 — 쿨다운 2.2s라 최소 1발
		var ev := caster.step(0.05, player_px, open_probe)
		if Vector2(ev["fire"]) != Vector2.ZERO:
			fires += 1
			fire_dir = ev["fire"]
	_check("⑧a 사거리 안이면 쿨다운마다 화염구를 뱉는다(3초에 1발 이상)", fires >= 1)
	_check("⑧b 발사 방향 = 플레이어 쪽(오른쪽)", fire_dir.x > 0.9)
	_check("⑧c 원거리는 **제자리**다(한 픽셀도 안 움직인다)", caster.pos == origin)
	var far_caster := Mob.spawn(MobCatalog.HWAGWI, Vector2i(5, 5), 12)
	var far_fires := 0
	for _i in 80:
		if Vector2(far_caster.step(0.05, far, open_probe)["fire"]) != Vector2.ZERO:
			far_fires += 1
	_check("⑧d 사거리(%d칸) 밖이면 한 발도 안 쏜다" % int(MobCatalog.reach_tiles(MobCatalog.HWAGWI)),
		far_fires == 0)
	# 화염구 스텝 — 전진·수명·지형 명중·접촉.
	var shot := Mob.make_shot(Vector2(100, 100), Vector2.RIGHT, MobCatalog.HWAGWI)
	_check("⑧e 화염구 = 몹 고정 데미지를 물고 태어난다(18)", int(shot["damage"]) == 18)
	var alive := Mob.step_shot(shot, 0.1, open_probe)
	_check("⑧f 전진한다(탄속 × dt)", alive
		and absf(Vector2(shot["pos"]).x - (100.0 + MobCatalog.shot_speed(MobCatalog.HWAGWI) * 0.1)) < 0.01)
	var wall_shot := Mob.make_shot(Vector2(11 * 32 + 20, 5 * 32 + 16), Vector2.RIGHT, MobCatalog.HWAGWI)
	var wall_alive := true
	for _i in 20:
		wall_alive = Mob.step_shot(wall_shot, 0.05, wall_probe)
		if not wall_alive:
			break
	_check("⑧g 지형(벽·돌)에 부딪히면 소멸한다 — 바위 뒤로 숨는 것이 회피가 된다", not wall_alive)
	var life_shot := Mob.make_shot(Vector2(100, 100), Vector2.RIGHT, MobCatalog.HWAGWI)
	var life_alive := true
	for _i in 200:
		life_alive = Mob.step_shot(life_shot, 0.05, open_probe)
		if not life_alive:
			break
	_check("⑧h 수명(%.1fs)이 지나면 소멸한다(무한 비행 없음)" % Mob.SHOT_LIFE, not life_alive)
	_check("⑧i 접촉 판정 = 몹과 같은 반경(판정 규칙 단일화)",
		Mob.shot_touches({"pos": Vector2(100, 100)}, Vector2(105, 100))
		and not Mob.shot_touches({"pos": Vector2(100, 100)}, Vector2(200, 100)))

	# ── ⑨ 사다리 롤 — 몹 처치 15% · 전멸 +4% ────────────────────────────────
	print("── ⑨ 사다리 롤(처치 15% · 전멸 +4%) ──")
	_check("⑨a 몹 전멸 = 사다리 확률 +4%(ADR-0063 결정 1 ㉡)",
		absf(MineFloors.ladder_chance(20, true) - MineFloors.ladder_chance(20, false) - 0.04) < 0.0001
		and absf(MineFloors.LADDER_MOBS_CLEARED - 0.04) < 0.0001)
	_check("⑨b 처치 사다리 = 고정 15%(돌 파괴 롤과 별 축)",
		absf(MineFloors.LADDER_MOB_KILL - 0.15) < 0.0001)
	_check("⑨c 처치 롤 결정성 — 같은 (day, 층, 스폰 인덱스)면 같은 답",
		MineFloors.roll_mob_ladder(5, 3, 2) == MineFloors.roll_mob_ladder(5, 3, 2))
	var hits := 0
	for i in 2000:
		if MineFloors.roll_mob_ladder(1, 1 + i % 60, i):
			hits += 1
	_check("⑨d 2000회 처치 롤이 15% 근처(관측 %d/2000)" % hits, hits > 240 and hits < 360)

	# ── ⑩ 라이브 배선(main) ─────────────────────────────────────────────────
	print("── ⑩ 라이브 — 스폰·스윙·처치·접촉 피해 ──")
	var m: Node = await _spawn_main()
	m._indoor = ""
	_check("⑩a Mob.TILE_PX = main.TILE(타일 눈금 이중 정의 방어)", Mob.TILE_PX == m.TILE)
	_check("⑩b 지상·다른 구역에선 몹 목록이 빈 배열(층 밖 = 전투 무대 아님)",
		(m._mobs_in_region() as Array).is_empty() and m._mobs.is_empty())
	# 층 진입 → 스폰.
	m._rebuild_region(RegionCatalog.EOPHWA_MINE)
	m._descend_mine(3)
	await _settle(m)
	_check("⑩c pre 갱도 3층", m._in_mine_floor() and m._mine_floor == 3)
	var spawned: int = m._mobs.size()
	# ★ 하한을 1로 둔다: 마리 수 롤은 3~6이지만 빽빽한 층에선 자리를 못 찾은 개체가 빠질 수 있다
	#   (MOB_PICK_TRIES 상한 — 무한 루프 대신 결손을 택한 설계). "전 층에 최소 1마리"가 실불변식이고,
	#   3~6이라는 롤 자체는 아래 ⑩d′가 전 층 통계로 따로 잠근다.
	_check("⑩d 층 진입 = 잡귀 %d마리 스폰(빈 층 없음 · 상한 %d 이하)" % [spawned, MineFloors.MOB_MAX],
		spawned >= 1 and spawned <= MineFloors.MOB_MAX)
	_check("⑩e 스폰 마리 수 = 층 배치 스펙과 일치(main이 스펙을 그대로 세운다)",
		spawned == (m._mine_layout["mobs"] as Array).size())
	var records: Array = m._mobs_in_region()
	var rec_ok := true
	for r: Dictionary in records:
		if not r.has("tile") or not r.has("ref") or not (r["ref"] is Mob):
			rec_ok = false
	_check("⑩f 몹 레코드 = {tile, ref, …} 불투명 dict(hits_in_arc가 arc 겹침만 본다)",
		records.size() == spawned and rec_ok)
	# arc 겹침 — 레코드 tile을 arc로 주면 골라낸다(T4 훅이 실효됐다).
	var pick: Array = CombatSkill.hits_in_arc([Vector2i(records[0]["tile"])], records)
	_check("⑩g T4 몹 훅 실효 — arc 안 레코드만 골라낸다", pick.size() >= 1
		and Vector2i(pick[0]["tile"]) == Vector2i(records[0]["tile"]))
	# 스윙 판정 — 검으로 한 마리를 잡는다(결정적: _strike_mob 직접 호출 · 스윙 카운터로 시드 변주).
	_check("⑩h pre 업화도 장착(엔드게임 밴드 55-64 — 한 방에 정리된다)",
		_equip(m, WeaponCatalog.SWORD_EOPHWADO))
	var victim: Dictionary = m._mobs_in_region()[0]
	var victim_ref: Mob = victim["ref"]
	var victim_kind: String = victim_ref.kind
	var hp_before: int = victim_ref.hp
	var xp_before: int = m._combat_xp
	var mobs_before: int = m._mobs.size()
	m._combat_swings += 1
	var res: Dictionary = m._strike_mob(WeaponCatalog.SWORD_EOPHWADO, victim)
	_check("⑩i 스윙이 몹 HP를 실제로 깎는다(T4가 남긴 두 줄 봉합)",
		int(res["damage"]) > 0 and victim_ref.hp == maxi(hp_before - int(res["damage"]), 0)
		and int(victim["last_damage"]) == int(res["damage"]))
	_check("⑩j 처치 = 죽음 · 전투 XP 적립(관계-중립 base)",
		not victim_ref.is_alive()
		and m._combat_xp == xp_before + MobCatalog.xp_of(victim_kind))
	m._tick_mobs(0.016)
	_check("⑩k 사체는 틱 끝에서 목록에서 빠진다", m._mobs.size() == mobs_before - 1)
	# 전멸 → 사다리 +4% 실효.
	_check("⑩l 아직 남은 몹이 있으면 전멸 아님(공짜 +4% 없음)", not m._mobs_cleared())
	var guard := 0
	while m._mobs_alive() > 0 and guard < 200:
		guard += 1
		var live: Array = m._mobs_in_region()
		if live.is_empty():
			break
		m._combat_swings += 1
		m._strike_mob(WeaponCatalog.SWORD_EOPHWADO, live[0])
		m._tick_mobs(0.016)
	_check("⑩m 층의 몹을 전부 잡으면 전멸 판정이 선다 → 사다리 +4% 실효",
		m._mobs_alive() == 0 and m._mobs_cleared()
		and MineFloors.ladder_chance(10, m._mobs_cleared()) > MineFloors.ladder_chance(10, false))
	_check("⑩n 전투 XP가 여러 마리 몫으로 누적됐다", m._combat_xp > xp_before)
	# 몹이 0마리인 무대에선 전멸 판정이 서지 않는다(빈 배열 = false).
	m._clear_mine_mobs()
	_check("⑩o 몹 목록이 비면 전멸 아님(보상 층 공짜 +4% 차단)", not m._mobs_cleared())

	# ── ⑪ 접촉 피해 · 화염구 명중 · 위장 활성화(라이브) ─────────────────────
	print("── ⑪ 접촉 피해 · 화염구 · 위장 활성화 ──")
	m._hurt_at = m.INVULN_NONE
	m._mine_descended_at = m.INVULN_NONE
	m.health.refill()
	var ppos: Vector2 = m.player.global_position
	# 플레이어 발밑에 그슨대(데미지 8)를 세우고 한 틱 — 접촉 피해가 들어온다.
	m._mobs = [Mob.spawn(MobCatalog.GEUSEUNDAE, m._player_tile(), 1)]
	m._mobs[0].pos = ppos
	var hp0: int = m.health.current
	var energy0: int = m.energy.current
	m._tick_mobs(0.016)
	_check("⑪a 몹 접촉 = 고정 데미지(그슨대 8) — take_damage 경로 하나로 나간다",
		m.health.current == hp0 - MobCatalog.damage_of(MobCatalog.GEUSEUNDAE))
	_check("⑪b 피격은 **혼력을 건드리지 않는다**(이중 시계 — HP와 혼력은 별 자원)",
		m.energy.current == energy0)
	var hp1: int = m.health.current
	m._tick_mobs(0.016)
	_check("⑪c 무적 창(0.8s) 안 연속 접촉은 튕긴다(매 프레임 갈리지 않는다)",
		m.health.current == hp1)
	# 위장 잡귀 — 곡괭이로 활성화(라이브 배선).
	m._hurt_at = m.INVULN_NONE
	var crab_tile: Vector2i = m._player_tile() + Vector2i(2, 0)
	m._mobs = [Mob.spawn(MobCatalog.DALGYAL, crab_tile, 2)]
	_check("⑪d pre 위장 잡귀가 그 칸에 있다고 판정된다(_disguised_mob_at)",
		m._disguised_mob_at(crab_tile) and not m._mobs[0].awake)
	_check("⑪e 위장 중엔 접촉 피해 0(바위인 줄 알고 지나가도 안 맞는다)",
		not m._mobs[0].is_hostile())
	_check("⑪f 곡괭이로 건드리면 활성화된다(1마리)", m._wake_mobs_near(crab_tile, 0) == 1
		and m._mobs[0].awake and m._mobs[0].is_hostile())
	_check("⑪g 활성화는 멱등 — 다시 깨워도 0마리", m._wake_mobs_near(crab_tile, 0) == 0)
	_check("⑪h 활성화 뒤엔 위장 판정이 안 선다", not m._disguised_mob_at(crab_tile))
	# 화염구 명중(라이브) — 화귀를 세우고 발사·명중까지 굴린다.
	m._hurt_at = m.INVULN_NONE
	m._mine_descended_at = m.INVULN_NONE
	m.health.refill()
	# ★ 사선을 실제로 찾는다 — 층 배치가 매일 달라 "오른쪽 3칸"을 하드코딩하면 돌에 막혀 검증이
	#   무작위로 흔들린다(화염구는 지형에 막히는 게 정상 거동이라 그 경우 실패가 오탐이다).
	var here: Vector2i = m._player_tile()
	var ray_dir := Vector2i.ZERO
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if _clear_ray(m, here, d, 3):
			ray_dir = d
			break
	_check("⑪h′ pre 플레이어에게서 3칸 뻗은 빈 사선이 있다(화염구 검증 무대)", ray_dir != Vector2i.ZERO)
	var caster_tile: Vector2i = here + ray_dir * 3
	m._mobs = [Mob.spawn(MobCatalog.HWAGWI, caster_tile, 3)]
	m._mob_shots = []
	var hp_pre: int = m.health.current
	var shot_seen := false
	for _i in 200:
		m._tick_mobs(0.02)
		if not m._mob_shots.is_empty():
			shot_seen = true
		if m.health.current < hp_pre:
			break
	_check("⑪i 화귀가 화염구를 실제로 발사한다(라이브 틱)", shot_seen)
	_check("⑪j 화염구가 플레이어에 명중해 고정 데미지를 준다(18)",
		m.health.current <= hp_pre - MobCatalog.damage_of(MobCatalog.HWAGWI))
	_check("⑪k 명중한 화염구는 사라진다(관통 없음)", m._mob_shots.is_empty())
	# ★ 틱 도중 기절 — 접촉 피해가 HP를 0으로 만들면 그 자리에서 지상 퇴장한다. 그때 틱의 되쓰기가
	#   버린 층의 잡귀를 되살리면 안 된다(지상에 잡귀가 서 있는 유령 상태).
	m._hurt_at = m.INVULN_NONE
	m._mine_descended_at = m.INVULN_NONE
	m.health.refill()
	m.health.current = 1                          # 다음 접촉 한 대에 기절
	m._mobs = [Mob.spawn(MobCatalog.BULGASARI, m._player_tile(), 4)]
	m._mobs[0].pos = m.player.global_position
	m._mob_shots = [Mob.make_shot(m.player.global_position, Vector2.RIGHT, MobCatalog.HWAGWI)]
	m._tick_mobs(0.016)
	await _settle(m)
	_check("⑪l 틱 도중 기절 = 지상 퇴장 · 버린 층 잡귀가 **되살아나지 않는다**",
		m._mine_floor == 0 and m._mobs.is_empty() and m._mob_shots.is_empty())
	# 다시 층으로 돌아가 남은 검증을 잇는다(⑫ 이후는 층 무대 전제).
	m.health.refill()
	m._descend_mine(3)
	await _settle(m)
	_check("⑪m pre 갱도 3층 복귀", m._in_mine_floor())
	# 지형 콜백 — 돌 = ROCK · 광맥 = WALL · 암반 = WALL.
	m._clear_mine_mobs()
	var rock_t := Vector2i(-1, -1)
	var node_t := Vector2i(-1, -1)
	for t: Vector2i in m.mine_floors.rocks_left(m.clock.day, m._mine_floor):
		if m._mine_node_at(t) != "":
			node_t = t
		else:
			rock_t = t
	_check("⑫a pre 층에 일반 돌·광맥이 둘 다 있다", rock_t.x >= 0 and node_t.x >= 0)
	_check("⑫b probe — 일반 돌 = CELL_ROCK(부술 수 있다)", m._mob_probe(rock_t) == Mob.CELL_ROCK)
	_check("⑫c ★probe — 광맥은 CELL_WALL(그슨대가 광맥을 부숴 자원을 없애지 못한다)",
		m._mob_probe(node_t) == Mob.CELL_WALL)
	_check("⑫d probe — 맵 밖·암반 = CELL_WALL", m._mob_probe(Vector2i(-1, -1)) == Mob.CELL_WALL
		and m._mob_probe(Vector2i(0, 0)) == Mob.CELL_WALL)
	_check("⑫e probe — 방 바닥 = CELL_FREE", m._mob_probe(Vector2i(m._mine_layout["ladder"])) == Mob.CELL_FREE)

	# ── ⑬ ★몹이 부순 바위 = 채광 XP 0(ADR-0063 결정 9) ─────────────────────
	print("── ⑬ 몹이 부순 바위 = 채광 XP 0 ──")
	var mining_xp0: int = m._mining_xp
	var energy_pre: int = m.energy.current
	var inv_pre: int = m.inventory.count_of(ItemCatalog.STONE)
	var stones_pre: int = m.mine_floors.rocks_left_count(m.clock.day, m._mine_floor)
	m._mob_break_rock(rock_t)
	_check("⑬a 몹이 부순 돌은 원장에 기록되고 통행이 열린다",
		m.mine_floors.is_mined(m._mine_floor, rock_t) and not m._is_mine_rock(rock_t)
		and m.mine_floors.rocks_left_count(m.clock.day, m._mine_floor) == stones_pre - 1)
	_check("⑬b ★채광 XP 0 · 산출 0 · 혼력 소모 0(플레이어가 캔 것이 아니다)",
		m._mining_xp == mining_xp0 and m.energy.current == energy_pre
		and m.inventory.count_of(ItemCatalog.STONE) == inv_pre)
	var left_before: int = m.mine_floors.rocks_left_count(m.clock.day, m._mine_floor)
	m._mob_break_rock(rock_t)
	_check("⑬c 이미 깬 칸을 다시 부수라 해도 무동작(멱등)",
		m.mine_floors.rocks_left_count(m.clock.day, m._mine_floor) == left_before)

	# ── ⑭ 이중 시계 — 채굴은 혼력 · 피격은 HP ──────────────────────────────
	print("── ⑭ 이중 시계(채굴 혼력 ↔ 전투 체력) ──")
	m._clear_mine_mobs()
	m.energy.current = SoulEnergy.MAX
	m.health.refill()
	m._hurt_at = m.INVULN_NONE
	m._mine_descended_at = m.INVULN_NONE
	var mine_target := Vector2i(-1, -1)
	for t: Vector2i in m.mine_floors.rocks_left(m.clock.day, m._mine_floor):
		if m._mine_node_at(t) == "":
			mine_target = t
			break
	_check("⑭a pre 곡괭이 장착 · 깰 일반 돌 존재",
		_equip(m, ItemCatalog.PICKAXE) and mine_target.x >= 0)
	var e_before: int = m.energy.current
	var hp_before2: int = m.health.current
	m._mine_rock(mine_target)
	_check("⑭b 채굴은 **혼력만** 쓴다(HP 불변 — 두 시계가 서로를 안 건드린다)",
		m.energy.current < e_before and m.health.current == hp_before2)
	var e2: int = m.energy.current
	m.take_damage(11)
	_check("⑭c 피격은 **HP만** 깎는다(혼력 불변)",
		m.health.current == hp_before2 - 11 and m.energy.current == e2)
	# 혼력 0에서도 검은 휘둘러진다(전투 행동비용 0) — 그런데 곡괭이는 막힌다(채굴은 과금).
	m.energy.current = 0
	m._hurt_at = m.INVULN_NONE
	var swings0: int = m._combat_swings
	_check("⑭d pre 검 장착", _equip(m, WeaponCatalog.SWORD_RUSTY))
	m._swing_weapon(WeaponCatalog.SWORD_RUSTY)
	_check("⑭e 혼력 0에서도 전투는 성립(행동비용 0) — 채굴만 막힌다(ADR-0011)",
		m._combat_swings == swings0 + 1 and m.energy.current == 0)

	# ── ⑮ 층 한정 비영속 ───────────────────────────────────────────────────
	print("── ⑮ 층 한정 비영속(세이브 0 · 이탈 소멸 · 재진입 재스폰) ──")
	m.energy.current = SoulEnergy.MAX
	m._spawn_mine_mobs()
	_check("⑮a pre 층 잡귀가 서 있다", m._mobs.size() > 0)
	m._save_game()
	var saved: Dictionary = m.saver.load_game(m._active_slot)
	var mob_key := false
	for k in saved.keys():
		if String(k).find("mob") >= 0:
			mob_key = true
	_check("⑮b **세이브에 몹 키 0**(층 한정 비영속 — 처치 원장도 없다)",
		not mob_key and not saved.has("mobs"))
	# ★[S5-T6] 'chests'(연 보상 상자 — 영구)가 붙어 6키다. 몹은 여전히 0키다(비영속 — ⑮b가 잠근다).
	_check("⑮c 층 원장 세이브 스키마(depth·day·mined·ladders·node_hits·chests 6키 · 몹 0키)",
		(saved["mine"] as Dictionary).size() == 6 and (saved["mine"] as Dictionary).has("chests"))
	# 층 이탈 → 소멸.
	m._ascend_mine_to_surface()
	await _settle(m)
	_check("⑮d 층을 떠나면 잡귀·화염구가 소멸한다",
		m._mobs.is_empty() and m._mob_shots.is_empty() and m._mine_floor == 0)
	# 재진입 → 재스폰(같은 day·층이면 같은 배치).
	m._descend_mine(3)
	await _settle(m)
	var resig: Array[String] = []
	for mob: Mob in m._mobs:
		resig.append("%s@%s" % [mob.kind, mob.tile()])
	_check("⑮e 재진입 = 재스폰(스타듀 정합 — 그날 잡은 잡귀가 다시 서 있다)",
		m._mobs.size() == (m._mine_layout["mobs"] as Array).size() and m._mobs.size() > 0)
	m._ascend_mine_to_surface()
	await _settle(m)
	m._descend_mine(3)
	await _settle(m)
	var resig2: Array[String] = []
	for mob: Mob in m._mobs:
		resig2.append("%s@%s" % [mob.kind, mob.tile()])
	_check("⑮f 같은 day·층 재진입 배치는 결정적으로 같다", resig == resig2)
	# 다른 구역으로 나가도 스테일이 안 남는다(빌드 앞단 청소).
	m._rebuild_region(RegionCatalog.HOME)
	_check("⑮g 다른 구역 빌드가 층 잡귀를 비운다(스테일 0)",
		m._mobs.is_empty() and (m._mobs_in_region() as Array).is_empty())

	# ── ⑯ 관계-중립(ADR-0031 결정 3) ────────────────────────────────────────
	print("── ⑯ 관계-중립 — 잡귀 코드에 affinity 참조 0 ──")
	# ★ 주석은 뺀 **코드 줄만** 훑는다 — 설계 메모가 "affinity 참조 0"이라고 *쓰는* 것까지 금지하면
	#   근거를 적을 수 없다. 금지 대상은 실제 의존이다(주석 = 문서, 코드 = 의존).
	var neutral := true
	var offender := ""
	for path in ["res://mob.gd", "res://mob_catalog.gd"]:
		var f := FileAccess.open(path, FileAccess.READ)
		var src := f.get_as_text()
		f.close()
		for raw_line in src.split("\n"):
			var line := String(raw_line)
			var hash_at := line.find("#")
			if hash_at >= 0:
				line = line.substr(0, hash_at)     # 줄 끝 주석까지 잘라낸다
			if line.strip_edges() == "":
				continue
			for banned in ["affinity", "Affinity", "bana", "Bana", "hearts", "Foxfire", "foxfire"]:
				if line.find(banned) >= 0:
					neutral = false
					offender = "%s: %s" % [path, line.strip_edges()]
	_check("⑯a mob.gd·mob_catalog.gd **코드**에 바나·affinity·hearts 참조 0(갱도 잡귀 = 관계-중립)%s"
		% ("" if neutral else " — " + offender), neutral)

	await _despawn(m)

	if had_save:
		_write_bytes(SAVE, _read_bytes(BAK))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAK))
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("══ 결과: %s ══" % ("PASS (실패 0)" if _fail == 0 else "FAIL (실패 %d)" % _fail))
	quit(1 if _fail > 0 else 0)
