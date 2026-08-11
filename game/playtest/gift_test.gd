extends SceneTree
# ★ [S8-T2 / ADR-0066 결정 2] 선물 머신 코어 — 헤드리스 단위검증.
#
# 무엇을 보증하나:
#   ① GiftPrefs 유니버설 계층(요리·보석 = 라이크 / 원자재·씨앗·미끼 = 디스라이크 / 쓰레기 =
#      헤이트 / 그 외 = 뉴트럴)과 선물 가능 판정(도구·열쇠는 못 건넨다).
#   ② 캐릭터별 오버라이드가 유니버설을 덮는다 · 9인 테이블의 규모·유효성(러브 4~6·헤이트 1~2,
#      전 id가 실존 아이템이고 건넬 수 있는 것) · 기존 preferred_crop 5건의 러브 승계.
#   ③ 등급 점수(40/25/15/−10/−20)와 품질 배율(러브·라이크만·품질 유차원 아이템만) ·
#      **불변식 "일반 품질 러브 > 이리듐 라이크"**.
#   ④ 라이브 선물(main): **든 아이템** 문법으로 물고기·광물·요리가 실제로 건네지고, 든 슬롯이
#      정확히 1개 준다(품질 격리) · 하루 1회 게이팅 · 빈손/도구는 무소모 반려.
#   ⑤ 음수(혐오) 채널이 실제로 깎고, 누적은 0 아래로 안 내려간다(영구 적대 없음).
#   ⑥ 채널 개방: 네오(S8-T2 신규) · 옹이·풀무·무골(작물 소진으로 선호가 비어 있던 셋)의 러브 성립.
#
# 실행: ./run_tests.sh gift   (헤드리스는 반드시 game/에서 · 순차)

var _fail := 0

func _check(label: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + label)
	if not ok:
		_fail += 1

func _new_main() -> Node:
	var m: Node = load("res://main.tscn").instantiate()
	get_root().add_child(m)
	await process_frame
	return m

# 아이템 1개를 인벤에 넣고 **그 슬롯을 손에 든다**(선물 입력 = 든 아이템 문법).
# ★ 유니크(도구)는 이미 갖고 있어 add_item이 거절한다 — 그 경우 갖고 있는 슬롯을 그냥 든다.
func _hold(m: Node, id: String, quality: int = 0) -> bool:
	if not m.inventory.add_item(id, 1, quality) and not m.inventory.has_item(id):
		return false
	for i in m.inventory.slots.size():
		if m.inventory.id_at(i) == id and m.inventory.quality_at(i) == quality:
			m.inventory.select(i)
			return m.inventory.selected_id() == id
	return false

# 그 주민에게 든 것을 건네고 오른 점수를 돌려준다(막히면 0).
func _give(m: Node, rid: String, day: int) -> int:
	var r: Resident = m._resident(rid)
	m.clock.day = day
	var before: int = r.affinity.points
	m._try_resident_gift(r)
	return r.affinity.points - before

func _initialize() -> void:
	await _run_checks()

func _run_checks() -> void:
	print("══ S8-T2 선물 머신 코어 단위검증 ══")
	var cleaner := SaveManager.new()
	cleaner.delete_save()

	# ── ① 유니버설 계층 · 선물 가능 판정(순수 단위 — 노드·씬 없이) ──
	print("── ① 유니버설 계층 ──")
	_check("①a 카페 요리 = 라이크", GiftPrefs.universal_tier(MenuCatalog.AMERICANO) == GiftPrefs.LIKE
		and GiftPrefs.universal_tier(MenuCatalog.SONGI_SOUP) == GiftPrefs.LIKE)
	_check("①b 보석 = 라이크", GiftPrefs.universal_tier(ItemCatalog.GEM_NEOKSUJEONG) == GiftPrefs.LIKE
		and GiftPrefs.universal_tier(ItemCatalog.GEM_MYEONGOK) == GiftPrefs.LIKE)
	_check("①c 원자재(원목·광석·돌·건초·잡귀 부산물) = 디스라이크",
		GiftPrefs.universal_tier(ItemCatalog.WOOD) == GiftPrefs.DISLIKE
		and GiftPrefs.universal_tier(ItemCatalog.ORE_MYEONGDONG) == GiftPrefs.DISLIKE
		and GiftPrefs.universal_tier(ItemCatalog.STONE) == GiftPrefs.DISLIKE
		and GiftPrefs.universal_tier(ItemCatalog.HAY) == GiftPrefs.DISLIKE
		and GiftPrefs.universal_tier(ItemCatalog.NEOKGARU) == GiftPrefs.DISLIKE)
	_check("①d 씨앗·묘목·비료·미끼 = 디스라이크",
		GiftPrefs.universal_tier(ItemCatalog.seed_id(CropCatalog.HONRYEONGCHO)) == GiftPrefs.DISLIKE
		and GiftPrefs.universal_tier(ItemCatalog.sapling_id(FruitTreeCatalog.HONBAEKDO)) == GiftPrefs.DISLIKE
		and GiftPrefs.universal_tier(ItemCatalog.FERT_BASIC) == GiftPrefs.DISLIKE
		and GiftPrefs.universal_tier(ItemCatalog.BAIT_BASIC) == GiftPrefs.DISLIKE)
	_check("①e 잡동사니(삭은 그물) = 헤이트", GiftPrefs.universal_tier(ItemCatalog.ROTTEN_NET) == GiftPrefs.HATE)
	_check("①f 그 외(작물·과일·채집물·어획물·수액·유품·주괴) = 뉴트럴",
		GiftPrefs.universal_tier(CropCatalog.HONRYEONGCHO) == GiftPrefs.NEUTRAL
		and GiftPrefs.universal_tier(FruitTreeCatalog.HONBAEKDO) == GiftPrefs.NEUTRAL
		and GiftPrefs.universal_tier(ItemCatalog.NEOK_GOSARI) == GiftPrefs.NEUTRAL
		and GiftPrefs.universal_tier(FishCatalog.NEOK_BUNGEO) == GiftPrefs.NEUTRAL
		and GiftPrefs.universal_tier(ItemCatalog.SOLNEOKJIN) == GiftPrefs.NEUTRAL
		and GiftPrefs.universal_tier(ItemCatalog.RELIC_BINYEO) == GiftPrefs.NEUTRAL
		and GiftPrefs.universal_tier(ItemCatalog.INGOT_MYEONGDONG) == GiftPrefs.NEUTRAL)
	# 선물 가능 — 막는 건 도구 칸(든 것이 곧 동사)과 나락 열쇠(유일 입수 경로 = 진행 봉쇄)뿐.
	_check("①g 도구·무기·낚싯대·태클은 선물 불가",
		not GiftPrefs.giftable(ItemCatalog.HOE) and not GiftPrefs.giftable(ItemCatalog.SWORD_RUSTY)
		and not GiftPrefs.giftable(ItemCatalog.ROD_T1) and not GiftPrefs.giftable(ItemCatalog.TACKLE_CORK))
	_check("①h 나락 열쇠는 선물 불가(진행 봉쇄 방지)", not GiftPrefs.giftable(ItemCatalog.NARAK_KEY))
	_check("①i 빈손·없는 id도 불가", not GiftPrefs.giftable("") and not GiftPrefs.giftable("없는아이템"))
	_check("①j 싫어하는 물건도 *건네지긴* 한다(혐오 = 반려가 아니라 음수)",
		GiftPrefs.giftable(ItemCatalog.ROTTEN_NET) and GiftPrefs.giftable(ItemCatalog.STONE))

	# ── ② 캐릭터별 오버라이드 ──
	print("── ② 캐릭터 오버라이드 ──")
	# 기존 preferred_crop 5건이 러브로 그대로 승계됐다(옛 선물 경제 보존).
	_check("②a preferred_crop 5건 러브 승계",
		GiftPrefs.tier_of("miho", CropCatalog.YEONGHON_HOBAK) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("mel", CropCatalog.PIANHWA) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("bana", CropCatalog.HONRYEONGCHO) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("mochi", CropCatalog.HWANGCHEON_PODO) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("boatman", CropCatalog.BULSAGWA) == GiftPrefs.LOVE)
	# 오버라이드가 유니버설을 **덮는다**(양방향 — 올리기도 내리기도).
	_check("②b 오버라이드가 유니버설을 올린다(풀무 혼탄: 디스라이크 → 러브)",
		GiftPrefs.universal_tier(ItemCatalog.HONTAN) == GiftPrefs.DISLIKE
		and GiftPrefs.tier_of("pulmu", ItemCatalog.HONTAN) == GiftPrefs.LOVE)
	_check("②c 오버라이드가 유니버설을 내린다(옹이 원목: 디스라이크 → 헤이트 · 멜 알돌: 디스라이크 → 헤이트)",
		GiftPrefs.tier_of("ongi", ItemCatalog.WOOD) == GiftPrefs.HATE
		and GiftPrefs.tier_of("mel", ItemCatalog.GEODE_NEOKAL) == GiftPrefs.HATE)
	_check("②d 라이크 위에도 얹힌다(미호 호박 라떼: 라이크 → 러브)",
		GiftPrefs.universal_tier(MenuCatalog.HOBAK_LATTE) == GiftPrefs.LIKE
		and GiftPrefs.tier_of("miho", MenuCatalog.HOBAK_LATTE) == GiftPrefs.LOVE)
	_check("②e 같은 물건이라도 사람마다 다르다(피안화: 멜 러브 · 무골 헤이트 · 미호 뉴트럴)",
		GiftPrefs.tier_of("mel", CropCatalog.PIANHWA) == GiftPrefs.LOVE
		and GiftPrefs.tier_of("mugol", CropCatalog.PIANHWA) == GiftPrefs.HATE
		and GiftPrefs.tier_of("miho", CropCatalog.PIANHWA) == GiftPrefs.NEUTRAL)
	# 9인 전원이 테이블을 가진다 — 규모(러브 4~6·헤이트 1~2)와 유효성(실존·건넬 수 있는 것).
	var who: Array = GiftPrefs.residents_with_prefs()
	_check("②f 관계 트랙 보유 9인 전원이 테이블 보유",
		who.size() == 9 and who.has("miho") and who.has("mel") and who.has("bana")
		and who.has("neo") and who.has("mochi") and who.has("boatman")
		and who.has("ongi") and who.has("pulmu") and who.has("mugol"))
	var size_ok := true
	var valid_ok := true
	var overlap_ok := true
	for rid in who:
		var loves: Array = GiftPrefs.loves(rid)
		var hates: Array = GiftPrefs.hates(rid)
		if loves.size() < 4 or loves.size() > 6 or hates.size() < 1 or hates.size() > 2:
			size_ok = false
		for id in loves + hates:
			if not ItemCatalog.has_item(id) or not GiftPrefs.giftable(id):
				valid_ok = false
			# 한 사람 안에서 러브와 헤이트가 겹치면 판정 순서에 결과가 인질이 된다.
			if loves.has(id) and hates.has(id):
				overlap_ok = false
	_check("②g 전원 러브 4~6종 · 헤이트 1~2종", size_ok)
	_check("②h 테이블의 전 id가 실존 아이템이고 건넬 수 있다(오타·도구 혼입 0)", valid_ok)
	_check("②i 한 사람 안에서 러브·헤이트 겹침 0", overlap_ok)
	_check("②j 테이블 없는 주민은 유니버설로 떨어진다(옥자·주방요괴)",
		GiftPrefs.tier_of("okja", CropCatalog.PIANHWA) == GiftPrefs.NEUTRAL
		and GiftPrefs.tier_of("kitchen_youkai", ItemCatalog.WOOD) == GiftPrefs.DISLIKE)

	# ── ③ 등급 점수 · 품질 배율 · 불변식 ──
	print("── ③ 점수·품질 ──")
	_check("③a 등급 점수 40/25/15/−10/−20",
		GiftPrefs.points_for(GiftPrefs.LOVE) == 40 and GiftPrefs.points_for(GiftPrefs.LIKE) == 25
		and GiftPrefs.points_for(GiftPrefs.NEUTRAL) == 15
		and GiftPrefs.points_for(GiftPrefs.DISLIKE) == -10
		and GiftPrefs.points_for(GiftPrefs.HATE) == -20)
	_check("③b 러브·뉴트럴은 Affinity 옛 눈금 승계(선물 1회급 = 의뢰 보상 눈금)",
		GiftPrefs.points_for(GiftPrefs.LOVE) == Affinity.GIFT_PREFERRED_POINTS
		and GiftPrefs.points_for(GiftPrefs.NEUTRAL) == Affinity.GIFT_POINTS)
	var hobak := CropCatalog.YEONGHON_HOBAK
	_check("③c 러브 품질 배율 ×1/×1.1/×1.25/×1.5",
		GiftPrefs.points_for(GiftPrefs.LOVE, hobak, ItemCatalog.Q_NORMAL) == 40
		and GiftPrefs.points_for(GiftPrefs.LOVE, hobak, ItemCatalog.Q_SILVER) == 44
		and GiftPrefs.points_for(GiftPrefs.LOVE, hobak, ItemCatalog.Q_GOLD) == 50
		and GiftPrefs.points_for(GiftPrefs.LOVE, hobak, ItemCatalog.Q_IRIDIUM) == 60)
	_check("③d 라이크 품질 배율(이리듐 = 37)",
		GiftPrefs.points_for(GiftPrefs.LIKE, hobak, ItemCatalog.Q_IRIDIUM) == 37)
	# ★ 스타듀 불변식 — 이게 깨지면 "그 사람이 좋아하는 것"보다 "아무거나 최고 등급"이 최적이 된다.
	_check("③e ★불변식: 일반 품질 러브(40) > 이리듐 라이크(37)",
		GiftPrefs.points_for(GiftPrefs.LOVE, hobak, ItemCatalog.Q_NORMAL)
			> GiftPrefs.points_for(GiftPrefs.LIKE, hobak, ItemCatalog.Q_IRIDIUM))
	_check("③f 뉴트럴·디스라이크·헤이트엔 배율 없음",
		GiftPrefs.points_for(GiftPrefs.NEUTRAL, hobak, ItemCatalog.Q_IRIDIUM) == 15
		and GiftPrefs.points_for(GiftPrefs.DISLIKE, hobak, ItemCatalog.Q_IRIDIUM) == -10
		and GiftPrefs.points_for(GiftPrefs.HATE, hobak, ItemCatalog.Q_IRIDIUM) == -20)
	_check("③g 품질 무차원 아이템은 배율 무시(메뉴·광물 — 슬롯이 등급을 안 싣는다)",
		GiftPrefs.points_for(GiftPrefs.LIKE, MenuCatalog.AMERICANO, ItemCatalog.Q_IRIDIUM) == 25
		and GiftPrefs.points_for(GiftPrefs.LIKE, ItemCatalog.GEM_MYEONGOK, ItemCatalog.Q_IRIDIUM) == 25)
	_check("③h gift_points = tier_of + points_for 한 창구",
		GiftPrefs.gift_points("miho", hobak, ItemCatalog.Q_GOLD) == 50
		and GiftPrefs.gift_points("mel", hobak) == 15)

	# ── ④ 라이브 선물: 든 아이템 문법(물고기·광물·요리) ──
	print("── ④ 라이브 선물 ──")
	var m: Node = await _new_main()
	var r_miho: Resident = m._resident("miho")
	r_miho.affinity.points = 0
	r_miho.affinity.last_gift_day = -1
	# ㉠ 물고기 — 옛 경로에선 **구조적으로 불가능**했던 선물이다.
	_check("④a 물고기를 들 수 있다", _hold(m, FishCatalog.NEOK_BUNGEO))
	_check("④b 물고기 선물 성립(뉴트럴 +15)", _give(m, "miho", 3) == 15)
	_check("④c 든 아이템 1개가 소모된다", m.inventory.count_of(FishCatalog.NEOK_BUNGEO) == 0)
	# ㉡ 카페 요리(라이크) · ㉢ 광물(보석 = 라이크)도 같은 경로로.
	_hold(m, MenuCatalog.AMERICANO)
	_check("④d 카페 요리 선물 성립(라이크 +25)", _give(m, "miho", 4) == 25)
	_hold(m, ItemCatalog.GEM_MYEONGOK)
	_check("④e 보석 선물 성립(라이크 +25)", _give(m, "miho", 5) == 25)
	# 품질 배율이 **든 슬롯의 등급**을 탄다.
	_hold(m, hobak, ItemCatalog.Q_IRIDIUM)
	_check("④f 이리듐 러브 = 60점(품질 배율 라이브)", _give(m, "miho", 6) == 60)
	# 품질 격리 — 일반품이 가방에 있어도 손에 든 이리듐 슬롯이 준다(remove_at 문법).
	m.inventory.add_item(hobak, 1, ItemCatalog.Q_NORMAL)
	_hold(m, hobak, ItemCatalog.Q_IRIDIUM)
	_check("④g 이리듐 러브 반복 = 60점", _give(m, "miho", 7) == 60)
	_check("④h 든 슬롯(이리듐)만 소모되고 일반품은 남는다",
		m.inventory.count_of(hobak) == 1)
	# 하루 1회 게이팅 — 막힌 선물은 **무소모**다.
	_hold(m, FishCatalog.NEOK_BUNGEO)
	var pts_before: int = r_miho.affinity.points
	m._try_resident_gift(r_miho)   # 같은 날(7) 두 번째
	_check("④i 하루 1회 게이팅(무점수)", r_miho.affinity.points == pts_before)
	_check("④j 막힌 선물은 아이템을 소모하지 않는다", m.inventory.count_of(FishCatalog.NEOK_BUNGEO) == 1)
	# 빈손·도구는 반려(무소모).
	m.inventory.select(m.inventory.slots.size() - 1)   # 마지막 칸은 비어 있다
	_check("④k 빈손이면 반려", m.inventory.selected_id() == "" and _give(m, "miho", 8) == 0)
	_hold(m, ItemCatalog.HOE)
	var hoe_held: bool = m.inventory.selected_id() == ItemCatalog.HOE
	_check("④l 도구는 반려하고 소모도 안 한다",
		hoe_held and _give(m, "miho", 9) == 0 and m.inventory.count_of(ItemCatalog.HOE) >= 1)

	# ── ⑤ 음수(혐오) 채널 · 0 하한 ──
	print("── ⑤ 음수 채널 ──")
	var r_mugol: Resident = m._resident("mugol")
	r_mugol.affinity.points = 100
	r_mugol.affinity.last_gift_day = -1
	_hold(m, CropCatalog.PIANHWA)
	_check("⑤a 헤이트 선물이 호감도를 깎는다(−20)", _give(m, "mugol", 10) == -20
		and r_mugol.affinity.points == 80)
	_hold(m, ItemCatalog.STONE)
	_check("⑤b 디스라이크 선물(−10)", _give(m, "mugol", 11) == -10 and r_mugol.affinity.points == 70)
	# 0 하한 — 영구 적대 없음(ADR-0022·ADR-0066 결정 2).
	r_mugol.affinity.points = 5
	_hold(m, CropCatalog.PIANHWA)
	m.clock.day = 12
	m._try_resident_gift(r_mugol)
	_check("⑤c 누적은 0 아래로 안 내려간다(영구 적대 없음)", r_mugol.affinity.points == 0)
	_check("⑤d 바닥에서도 아이템은 소모된다(건넨 건 사실이다)",
		m.inventory.count_of(CropCatalog.PIANHWA) == 0)

	# ── ⑥ 채널 개방: 네오 · 옹이 · 풀무 · 무골 ──
	print("── ⑥ 채널 개방 ──")
	var r_neo: Resident = m._resident("neo")
	_check("⑥a 네오 선물 채널 개방(can_gift)", r_neo.can_gift)
	r_neo.affinity.points = 0
	r_neo.affinity.last_gift_day = -1
	_hold(m, ItemCatalog.GEM_OSAEK_HONOK)
	_check("⑥b 네오 러브 선물 성립(오색혼옥 +40)", _give(m, "neo", 13) == 40)
	var r_ongi: Resident = m._resident("ongi")
	r_ongi.affinity.points = 0
	r_ongi.affinity.last_gift_day = -1
	_hold(m, ItemCatalog.MYEONGDANPUNG_KKUL)
	_check("⑥c 옹이 러브 성립(명단풍꿀 +40 — 작물 소진으로 비어 있던 선호가 채워졌다)",
		_give(m, "ongi", 14) == 40)
	_hold(m, ItemCatalog.WOOD)
	_check("⑥d 옹이 헤이트 성립(원목 −20 — 목령에게 잘린 나무)", _give(m, "ongi", 15) == -20)
	var r_pulmu: Resident = m._resident("pulmu")
	r_pulmu.affinity.points = 0
	r_pulmu.affinity.last_gift_day = -1
	_hold(m, ItemCatalog.HONTAN)
	_check("⑥e 풀무 러브 성립(혼탄 +40)", _give(m, "pulmu", 16) == 40)
	r_mugol.affinity.points = 0
	r_mugol.affinity.last_gift_day = -1
	_hold(m, ItemCatalog.NARAK_HONJEONG)
	_check("⑥f 무골 러브 성립(나락혼정 +40)", _give(m, "mugol", 17) == 40)
	# 관계 트랙 없는 주민(옥자·주방요괴)은 선물 경로 자체가 없다(가드).
	var r_okja: Resident = m._resident("okja")
	_hold(m, CropCatalog.YEONGHON_HOBAK)
	var hobak_before: int = m.inventory.count_of(CropCatalog.YEONGHON_HOBAK)
	m.clock.day = 18
	m._try_resident_gift(r_okja)
	_check("⑥g 관계 트랙 없는 주민은 선물 경로 무반응(무소모)",
		r_okja.affinity == null and not r_okja.can_gift
		and m.inventory.count_of(CropCatalog.YEONGHON_HOBAK) == hobak_before)

	m.free()
	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)
