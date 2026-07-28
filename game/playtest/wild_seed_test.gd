extends SceneTree
# ★[S4-T5 / ADR-0062 결정 5 · ADR-0033 #4] 야생·혼합 씨앗 재배 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ① CropCatalog wild 표면 — is_wild/is_mixed/wild_season/wild_species·ids() 밖(매대 미노출)·
#     씨앗 아이템 파생("혼합 씨앗" 명명 그대로).
#   ② 야생 작물 성장 — 7일(물 주며)·SINGLE.
#   ③ 야생 수확 = 채집 축(스타듀 "밭에서 길러도 채집") — 수확물이 그 절기 일반종 3종 중 하나·
#     채집 XP +7(농사 XP 0)·수확 후 칸 비움·발견 원장 기록.
#   ④ 수확 롤 결정성 — day+칸 해시(테스트가 같은 공식으로 예측한 종과 일치).
#   ⑤ 희소종 모종 — 수확물 = 그 종 단일(미혹난초).
#   ⑥ 까마귀 면역 — _crow_target_tiles()가 야생 작물을 제외하고 일반 작물은 남긴다.
#   ⑦ 혼합 씨앗 — 치환 롤 결정성(_mixed_crop_for 절기 매핑) + 잡초 낫질 드랍 롤 결정성.
#
# 실행: ./run_tests.sh wild_seed   (헤드리스는 반드시 game/에서 · 순차)

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

func _despawn(m: Node) -> void:
	m.queue_free()
	await process_frame
	await process_frame

# 밭 한 칸을 심고 물 주며 days일 굴린다(여우불 0 — 순수 성장).
func _grow_tile(farm: Node, t: Vector2i, crop: String, days: int) -> void:
	farm.hoe(t)
	farm.plant(t, crop)
	for _d in days:
		farm.water(t)
		farm.advance_day()

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S4-T5 야생·혼합 씨앗 재배 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ① CropCatalog wild 표면 ──
	print("── ① wild 표면 ──")
	_check("①a is_wild — 야생 8종 true·기존 5작물 false",
		CropCatalog.is_wild(CropCatalog.WILD_PIAN) and CropCatalog.is_wild(CropCatalog.WILD_MIHOK_NANCHO)
		and not CropCatalog.is_wild(CropCatalog.PIANHWA) and not CropCatalog.is_wild(CropCatalog.BULSAGWA))
	_check("①b is_mixed — 혼합만 true", CropCatalog.is_mixed(CropCatalog.MIXED)
		and not CropCatalog.is_mixed(CropCatalog.WILD_PIAN))
	_check("①c wild_season — 절기 모둠 0~3·희소/비-wild -1",
		CropCatalog.wild_season(CropCatalog.WILD_PIAN) == 0 and CropCatalog.wild_season(CropCatalog.WILD_SEONGYA) == 3
		and CropCatalog.wild_season(CropCatalog.WILD_MIHOK_NANCHO) == -1 and CropCatalog.wild_season(CropCatalog.PIANHWA) == -1)
	_check("①d wild_species — 희소종 id·모둠은 \"\"",
		CropCatalog.wild_species(CropCatalog.WILD_MIHOK_NANCHO) == ItemCatalog.MIHOK_NANCHO
		and CropCatalog.wild_species(CropCatalog.WILD_PIAN) == "")
	_check("①e ids() 밖(매대 미노출)", not CropCatalog.ids().has(CropCatalog.MIXED)
		and not CropCatalog.ids().has(CropCatalog.WILD_PIAN) and not CropCatalog.ids().has(CropCatalog.WILD_MIHOK_NANCHO))
	_check("①f 씨앗 아이템 파생 — \"혼합 씨앗\"·야생 씨앗 유효",
		ItemCatalog.name_of(ItemCatalog.seed_id(CropCatalog.MIXED)) == "혼합 씨앗"
		and ItemCatalog.has_item(ItemCatalog.seed_id(CropCatalog.WILD_PIAN))
		and ItemCatalog.category_of(ItemCatalog.seed_id(CropCatalog.WILD_PIAN)) == ItemCatalog.CAT_SEED)

	# ── ② 야생 작물 성장 ──
	print("── ② 성장 7일 ──")
	var m: Node = await _new_main()
	var farm: Node = m.farm
	var t := Vector2i(30, 20)
	_grow_tile(farm, t, CropCatalog.WILD_PIAN, 6)
	_check("②a 6일 = 미성숙", not farm.is_mature(t))
	farm.water(t)
	farm.advance_day()
	_check("②b 7일 = 성숙", farm.is_mature(t))

	# ── ③④ 야생 수확 = 채집 축 ──
	print("── ③④ 야생 수확 ──")
	m._foraging_xp = 0
	var farm_xp_before: int = m._farming_xp
	m._target = t
	# 롤 예측(main._harvest_wild와 같은 공식 — 결정성의 실증).
	var pool: Array = ForageSpawns.species_for(ForageSpawns.KIND_COMMON, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wildharvest:%d:%d:%d" % [m.clock.day, t.x, t.y])
	var expected: String = pool[rng.randi_range(0, pool.size() - 1)]
	m._try_harvest()
	var inv: Node = m.inventory
	_check("③a 수확물 = 예측된 피안 일반종(결정 롤)", inv.count_of(expected) >= 1)
	_check("③b 채집 XP +7·농사 XP 불변",
		m._foraging_xp == ForageSkill.PICK_XP and m._farming_xp == farm_xp_before)
	_check("③c 수확 후 칸 비움(SINGLE)", not farm.is_planted(t))
	_check("③d 발견 원장 기록(재배 수확도 발견)", bool(m._forage_found.get(expected, false)))

	# ── ⑤ 희소종 모종 ──
	print("── ⑤ 희소종 모종 ──")
	var t2 := Vector2i(31, 20)
	_grow_tile(farm, t2, CropCatalog.WILD_MIHOK_NANCHO, 7)
	m._target = t2
	var before: int = inv.count_of(ItemCatalog.MIHOK_NANCHO)
	m._try_harvest()
	_check("⑤a 수확물 = 미혹난초 단일", inv.count_of(ItemCatalog.MIHOK_NANCHO) > before)

	# ── ⑥ 까마귀 면역 ──
	print("── ⑥ 까마귀 면역 ──")
	var tw := Vector2i(32, 20)
	var tr := Vector2i(33, 20)
	farm.hoe(tw)
	farm.plant(tw, CropCatalog.WILD_YUHWA)
	farm.hoe(tr)
	farm.plant(tr, CropCatalog.PIANHWA)
	var targets: Array = m._crow_target_tiles()
	_check("⑥a 야생 제외·일반 포함", not targets.has(tw) and targets.has(tr))

	# ── ⑦ 혼합 씨앗 ──
	print("── ⑦ 혼합 씨앗 ──")
	var c1: String = m._mixed_crop_for(1, Vector2i(5, 5))
	var c2: String = m._mixed_crop_for(1, Vector2i(5, 5))
	_check("⑦a 치환 롤 결정성(같은 day·칸 = 같은 작물)", c1 == c2 and CropCatalog.has_crop(c1) and not CropCatalog.is_wild(c1))
	_check("⑦b 절기 매핑 — 피안(1일)=피안화·성야(85일)=영혼 호박",
		m._mixed_crop_for(1, Vector2i(5, 5)) == CropCatalog.PIANHWA
		and m._mixed_crop_for(85, Vector2i(5, 5)) == CropCatalog.YEONGHON_HOBAK)
	# 드랍 롤 결정성 — 같은 공식으로 통과/실패 칸을 예측해 인벤 증감을 대조.
	var mixed_seed: String = ItemCatalog.seed_id(CropCatalog.MIXED)
	var hit := Vector2i(-1, -1)
	var miss := Vector2i(-1, -1)
	for x in 60:
		var tt := Vector2i(x, 7)
		var r2 := RandomNumberGenerator.new()
		r2.seed = hash("mixdrop:%d:%d:%d" % [m.clock.day, tt.x, tt.y])
		if r2.randf() < m.MIXED_SEED_DROP_CHANCE:
			if hit.x < 0:
				hit = tt
		elif miss.x < 0:
			miss = tt
	var before_seed: int = inv.count_of(mixed_seed)
	if hit.x >= 0:
		m._roll_mixed_seed_drop(hit)
	_check("⑦c 통과 칸 → 혼합 씨앗 +1", hit.x >= 0 and inv.count_of(mixed_seed) == before_seed + 1)
	if miss.x >= 0:
		m._roll_mixed_seed_drop(miss)
	_check("⑦d 실패 칸 → 무드랍", miss.x >= 0 and inv.count_of(mixed_seed) == before_seed + 1)

	await _despawn(m)
	cleaner.delete_save()
	print("══ 결과: %s ══" % ("전체 통과" if _fail == 0 else "%d개 실패" % _fail))
	quit(0 if _fail == 0 else 1)
