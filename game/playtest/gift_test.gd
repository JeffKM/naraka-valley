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
# ★ [S8-T3 / ADR-0066 결정 3] 주간·생일이 같은 파일에 이어 붙는다(선물의 *리듬* 축이라 한 스위트):
#   ⑦ 주 파생(week_of)과 인당 주 2회 상한(같은 주 세 번째 거절·주가 바뀌면 재허용).
#   ⑧ 9인 생일 배치 전수 — 테마 데이(25일)·절기 행사일(12/20/16/15) 무충돌 · 같은 날 중복 0.
#   ⑨ 생일 ×8(러브 40→320 · 헤이트 −20→−160) · 주 상한 면제 + 카운터 미소모 · 하루 1회는 유지.
#   ⑩ 달력 birthday 키·범례 줄 · ⑪ 주간 키 없는 구세이브 로드 무결 · ⑫ 생일 대사 placeholder.
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

# ★[S9-T4] 열린 대화를 끝까지 넘겨 닫는다(넘긴 횟수를 돌려준다). 절기 물음 선택지가 떠 있으면
# 첫 항을 고른다 — 넘기기로는 못 지나가기 때문이다(DialogueBox.advance의 선택지 가드).
func _drain(m: Node) -> int:
	var n := 0
	while m.dialogue.is_open() and n < 64:
		if m.dialogue.has_choice():
			m.dialogue.choose(0)
		else:
			m.dialogue.advance()
		n += 1
	return n

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
# ★[S8-T3] `isolate=true`면 **주간 카운터를 먼저 되감는다** — 이 헬퍼를 쓰는 옛 절(④~⑥)은 "한 번
#   건네면 무슨 일이 일어나는가"만 보는데, S8-T3의 주 2회 상한이 끼면 세 번째 호출부터 그 관심사와
#   무관하게 막혀 버린다. 상한 자체는 아래 ⑦절이 격리 없이(isolate=false) 직접 본다.
func _give(m: Node, rid: String, day: int, isolate: bool = true) -> int:
	var r: Resident = m._resident(rid)
	m.clock.day = day
	if isolate:
		r.affinity.gift_week = -1
		r.affinity.gifts_this_week = 0
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
	# 관계 트랙 보유자 전원이 테이블을 가진다 — 규모(러브 4~6·헤이트 1~2)와 유효성(실존·건넬 수
	# 있는 것). ★[S9b-T1 / ADR-0068 결정 3] 9 → 11: 깨비·켄(조연 코러스 첫 2인)이 붙었다.
	# ★ 이 스위트는 씬 없이 도는 구간이라 레지스트리를 못 읽는다(m은 아래 ⑤부터 산다) — 트랙
	#   보유자와의 대응은 ⑧a가 레지스트리를 들고 다시 잰다.
	# ★[S9b-T2] 총원 등식(== 11)을 뺐다 — 조연이 한 명씩 붙는 슬라이스에서 이 숫자를 박아 두면
	#   인물 태스크마다 같은 줄을 고치게 되고(병렬 결합 충돌원), 정작 재고 싶은 계약은 "몇 명인가"가
	#   아니라 **"트랙 보유자 전원이 테이블을 가진다"**이다. 총원-집합 대응은 ⑧a가 레지스트리를
	#   들고 재고, 여기서는 하한 + 개별 보유만 본다(gift_test ⑧a·frame_test ③a와 같은 전환).
	var who: Array = GiftPrefs.residents_with_prefs()
	_check("②f 관계 트랙 보유자 전원이 테이블 보유",
		who.size() >= 11 and who.has("miho") and who.has("mel") and who.has("bana")
		and who.has("neo") and who.has("mochi") and who.has("boatman")
		and who.has("ongi") and who.has("pulmu") and who.has("mugol")
		and who.has("kkaebi") and who.has("ken") and who.has("seolhwa") and who.has("scarlet"))
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

	# ══════════ 여기서부터 S8-T3(주간·생일 — ADR-0066 결정 3) ══════════
	# ── ⑦ 주(week) 파생 · 인당 주 2회 상한 ──
	print("── ⑦ 주 2회 제한 ──")
	_check("⑦a week = (day-1)/7 순수 파생(1~7=0주 · 8=1주 · 15=2주 · 29=4주)",
		GameClock.week_of(1) == 0 and GameClock.week_of(7) == 0 and GameClock.week_of(8) == 1
		and GameClock.week_of(15) == 2 and GameClock.week_of(29) == 4)
	_check("⑦b 절기(28일) = 정확히 4주라 주 경계가 절기 경계와 어긋나지 않는다",
		GameClock.DAYS_PER_SEASON % GameClock.DAYS_PER_WEEK == 0
		and GameClock.week_of(29) - GameClock.week_of(1) == 4)
	_check("⑦c 0·음수 day는 0주로 접힌다(손상 방어)",
		GameClock.week_of(0) == 0 and GameClock.week_of(-5) == 0)
	# 라이브 — 같은 주(50~56) 안에서 세 번째가 막히고, 주가 넘어가면(57) 다시 열린다.
	var r_mochi: Resident = m._resident("mochi")
	r_mochi.affinity.points = 0
	r_mochi.affinity.last_gift_day = -1
	r_mochi.affinity.gift_week = -1
	r_mochi.affinity.gifts_this_week = 0
	_hold(m, FishCatalog.NEOK_BUNGEO)
	_check("⑦d 그 주 첫 번째 선물(+15)", _give(m, "mochi", 50, false) == 15)
	_hold(m, FishCatalog.NEOK_BUNGEO)
	_check("⑦e 두 번째도 통과(+15)", _give(m, "mochi", 51, false) == 15)
	_check("⑦f 이제 이번 주 잔여 0", r_mochi.affinity.gifts_left_in_week(52) == 0)
	_hold(m, FishCatalog.NEOK_BUNGEO)
	var fish_n: int = m.inventory.count_of(FishCatalog.NEOK_BUNGEO)
	_check("⑦g 같은 주 세 번째는 막힌다(무점수)", _give(m, "mochi", 52, false) == 0)
	_check("⑦h 막힌 선물은 아이템을 소모하지 않는다",
		m.inventory.count_of(FishCatalog.NEOK_BUNGEO) == fish_n)
	_check("⑦i 주가 바뀌면 다시 열린다(day 57 = 8주차, +15)", _give(m, "mochi", 57, false) == 15)
	_check("⑦j 새 주의 카운터는 1부터(잔여 1)",
		r_mochi.affinity.gifts_used_in_week(57) == 1
		and r_mochi.affinity.gifts_left_in_week(57) == 1)

	# ── ⑧ 생일 테이블(9인 배치 전수 — 회피일·중복) ──
	print("── ⑧ 생일 배치 ──")
	var tracked: Array = []
	for r in m._residents:
		if r.affinity != null:
			tracked.append(r.id)
	# ★[S9b-T1] 총원 상수를 **레지스트리 파생 불변식**으로 바꿨다 — 재고 싶은 계약은 "9"라는
	#   숫자가 아니라 *관계 트랙 보유자 집합 == 생일 테이블 집합*이다(조연이 한 명씩 붙어도
	#   이 단언이 그대로 이빨을 유지한다).
	_check("⑧a 관계 트랙 보유자 전원에게 생일이 있다(그리고 그들뿐)",
		tracked.size() == Resident.BIRTHDAYS.size() and tracked.size() >= 11
		and tracked.all(func(rid: String) -> bool: return Resident.BIRTHDAYS.has(rid)))
	var range_ok := true       # 절기 0..3 · 일차 1..28
	var avoid_theme := true    # 25일(테마 데이 고정 슬롯) 회피
	var avoid_event := true    # 절기 행사일(12/20/16/15) 회피
	var uniq: Array = []
	var dup_ok := true
	for rid in Resident.BIRTHDAYS:
		var b: Array = Resident.birthday_of(String(rid))
		var s := int(b[0])
		var dos := int(b[1])
		if s < 0 or s > 3 or dos < 1 or dos > GameClock.DAYS_PER_SEASON:
			range_ok = false
		if dos == Festival.DAY_OF_SEASON:
			avoid_theme = false
		if dos == int(SeasonalEvent.DAY_OF_SEASON[s]):
			avoid_event = false
		var key := "%d:%d" % [s, dos]
		if uniq.has(key):
			dup_ok = false
		uniq.append(key)
	_check("⑧b 전원 절기 0~3 · 일차 1~28 범위", range_ok)
	_check("⑧c 테마 데이(각 절기 25일) 무충돌", avoid_theme)
	_check("⑧d 절기 행사일(12/20/16/15) 무충돌", avoid_event)
	_check("⑧e 같은 날 생일 둘 없음(달력 마커 1칸 1인)", dup_ok)
	# 절대 날짜 조회 — 해마다 돌아온다(절기·일차로 비교하므로 112일 주기).
	var miho_bday := 35      # 유화절 7일 = 28 + 7
	var mugol_bday := 77     # 망연절 21일 = 56 + 21
	_check("⑧f is_birthday = 절기·일차 일치(미호 day 35)",
		Resident.is_birthday("miho", miho_bday)
		and not Resident.is_birthday("miho", miho_bday - 1)
		and not Resident.is_birthday("miho", miho_bday + 1))
	_check("⑧g 해가 바뀌어도 같은 날 돌아온다(35 + 112)",
		Resident.is_birthday("miho", miho_bday + 112))
	_check("⑧h 역방향 조회(birthday_on_day)",
		Resident.birthday_on_day(miho_bday) == "miho"
		and Resident.birthday_on_day(mugol_bday) == "mugol"
		and Resident.birthday_on_day(1) == "")
	_check("⑧i 트랙 없는 주민·잘못된 id는 생일 없음",
		not Resident.is_birthday("okja", miho_bday) and Resident.birthday_of("없는사람").is_empty())

	# ── ⑨ 생일 ×8 · 주 상한 면제(카운터 미소모) · 하루 1회 유지 ──
	print("── ⑨ 생일 선물 ──")
	# 단위 — 반환은 **명목** 점수(플레이어가 본 "+320"이 사실이어야 한다).
	var a_bd := Affinity.new()
	_check("⑨a-1 러브 40 × 생일 8 = 320(명목 반환)",
		a_bd.gift(Affinity.GIFT_PREFERRED_POINTS, miho_bday, true) == 320)
	# ★잠정 경보(owner 큐): 우리 5-스케일에선 만렙이 300점이라 **생일 러브 선물 한 번이 미터를
	#   통째로 채운다**(스타듀는 640/2500 ≈ 2.5하트). ADR-0066이 "×8 스타듀 동형"으로 확정한 값을
	#   그대로 태웠고, 눈금 재조정은 곡선 소관(S8-T4)이라 여기선 사실만 단언해 박아 둔다.
	_check("⑨a-2 ×8이 5-스케일 만렙(300)을 넘어 clamp된다 — 잠정 경보로 박제",
		a_bd.points == Affinity.MAX_POINTS and 320 > Affinity.MAX_POINTS)
	a_bd.free()
	var r_miho2: Resident = m._resident("miho")
	r_miho2.affinity.points = 0
	r_miho2.affinity.last_gift_day = -1
	# 그 주 두 번을 이미 다 썼는데도(면제) 생일 선물이 통과한다.
	r_miho2.affinity.gift_week = GameClock.week_of(miho_bday)
	r_miho2.affinity.gifts_this_week = Affinity.GIFTS_PER_WEEK
	_hold(m, CropCatalog.YEONGHON_HOBAK)
	var bday_gain: int = _give(m, "miho", miho_bday, false)
	_check("⑨b 주 2회를 소진했어도 생일은 통과한다(면제 · 만렙까지 채움)",
		bday_gain > Affinity.GIFT_PREFERRED_POINTS
		and r_miho2.affinity.points == Affinity.MAX_POINTS)
	_check("⑨c 생일 선물은 주 카운터를 소모하지 않는다",
		r_miho2.affinity.gifts_this_week == Affinity.GIFTS_PER_WEEK)
	# 하루 1회는 생일에도 유지된다(여덟 배를 하루 두 번 받는 날은 없다).
	_hold(m, CropCatalog.YEONGHON_HOBAK)
	var pts_bday: int = r_miho2.affinity.points
	var hobak_n: int = m.inventory.count_of(CropCatalog.YEONGHON_HOBAK)
	m._try_resident_gift(r_miho2)
	_check("⑨d 생일에도 하루 1회는 유지(두 번째 무점수·무소모)",
		r_miho2.affinity.points == pts_bday
		and m.inventory.count_of(CropCatalog.YEONGHON_HOBAK) == hobak_n)
	# 비생일 날은 배율이 안 붙는다(회귀 — ×8이 새지 않는지).
	r_miho2.affinity.points = 0
	_hold(m, CropCatalog.YEONGHON_HOBAK)
	_check("⑨e 비생일은 배율 없음(러브 40)", _give(m, "miho", miho_bday + 1) == 40)
	# 음수도 ×8(러브~헤이트 전 등급 — 스타듀 동형)이되 0 하한은 그대로.
	r_mugol.affinity.points = Affinity.MAX_POINTS      # 만렙에서 시작(clamp에 안 걸리게)
	r_mugol.affinity.last_gift_day = -1
	_hold(m, CropCatalog.PIANHWA)
	_check("⑨f 헤이트 −20 × 생일 8 = −160", _give(m, "mugol", mugol_bday, false) == -160
		and r_mugol.affinity.points == Affinity.MAX_POINTS - 160)
	r_mugol.affinity.points = 100
	r_mugol.affinity.last_gift_day = -1
	_hold(m, CropCatalog.PIANHWA)
	m.clock.day = mugol_bday + 112     # 이듬해 같은 생일
	m._try_resident_gift(r_mugol)
	_check("⑨g 생일 ×8 음수도 0 아래로는 못 내려간다(영구 적대 없음)",
		r_mugol.affinity.points == 0)

	# ── ⑩ 달력 birthday 키 · 범례 ──
	print("── ⑩ 달력 생일 마커 ──")
	var cal := CalendarPanel.new()
	get_root().add_child(cal)
	cal.setup()
	cal.set_resident_names({"miho": "미호", "mochi": "모찌"})
	cal.set_state(miho_bday, 1, 0)     # 유화절 7일
	var cal_cells: Array = cal.cells()
	_check("⑩a 28칸 전부 birthday 키를 가진다(가법 1키)",
		cal_cells.size() == GameClock.DAYS_PER_SEASON
		and cal_cells.all(func(c: Dictionary) -> bool: return c.has("birthday")))
	var bday_cells: Array = []
	for c in cal_cells:
		if String(c["birthday"]) != "":
			bday_cells.append(c)
	# ★[S9b-T1] 2 → 3칸: 깨비(유화절 13일 — 잠정)가 같은 절기에 붙었다.
	# ★[S9b-T5] **레지스트리 파생으로 전환**한다(옛 하드코딩 "3칸"은 S9b-T3이 루카 15일·미르 17일을
	#   유화절에 배정하면서 stale이 됐고, 그 절기를 안 건드린 T4·T5까지 이 자리를 물려받았다).
	#   달력 마커는 `Resident.BIRTHDAYS`의 **파생**이지 사본이 아니므로, 재는 것도 파생이어야 한다 —
	#   resident_test ⑧a가 총원 단일 출처에서 배운 것과 같은 교훈이다. 이제 생일이 늘어도 이 줄은
	#   안 깨지고, 대신 **달력이 레지스트리를 그대로 비추는가**라는 진짜 계약만 남는다.
	_check("⑩b 유화절 생일 칸 = 레지스트리의 그 절기 생일 수와 정확히 같다",
		bday_cells.size() == _season_birthday_count(1))
	_check("⑩c 7일 칸이 미호",
		String(cal_cells[6]["birthday"]) == "miho" and int(cal_cells[6]["dos"]) == 7)
	_check("⑩d 생일 칸엔 행사·테마가 겹치지 않는다",
		bday_cells.all(func(c: Dictionary) -> bool:
			return int(c["event"]) == SeasonalEvent.NONE and int(c["theme"]) == Festival.NONE))
	# ★[S8-T10] 머리표 "♥ "가 문자열에서 빠졌다 — 폰트에 그 글리프가 없어 두부로 떴고, 이제
	#   렌더가 `_draw_heart_mark`로 **그린다**(calendar_panel._legend_rows 주석). 텍스트 단언은
	#   날짜·이름만 본다(머리표는 그림이라 문자열에 안 섞인다).
	_check("⑩e 범례에 생일 줄", "7일 — 미호 생일" in str(cal.legend())
		and "26일 — 모찌 생일" in str(cal.legend()))
	# ★[S9b-T5] 여기도 파생으로 전환(⑩b와 같은 근거). 범례 = 행사 1줄 + 테마 1줄 + **생일 N줄**
	#   이고(calendar_panel._legend_rows 순서 그대로), 재는 것은 "생일이 그 뒤에 붙는다"는 구조지
	#   N의 값이 아니다.
	_check("⑩f 기존 범례(행사 1줄·테마 1줄)는 그대로 · 생일이 뒤에 붙는다",
		cal.legend().size() == 2 + _season_birthday_count(1)
		and "월광 혼불해파리 창구" in str(cal.legend()))
	cal.set_state(1, 1, 0)             # 피안절 — 옹이 4일·뱃사공 11일·네오 19일
	_check("⑩g 이름 미주입 주민은 id로 폴백(범례가 죽지 않는다)",
		"4일 — ongi 생일" in str(cal.legend()))
	cal.queue_free()

	# ── ⑪ 구세이브 로드 무결(가법 키) ──
	print("── ⑪ 세이브 하위호환 ──")
	var a_old := Affinity.new()
	a_old.load_save({"points": 100, "last_talk_day": 3, "last_gift_day": 4})   # 주간 키 없는 구세이브
	_check("⑪a 주간 키 없는 딕셔너리도 크래시 없이 로드",
		a_old.points == 100 and a_old.last_gift_day == 4)
	_check("⑪b 기본값 = '이 주엔 아직 안 건넸다'(아무것도 안 막힌다)",
		a_old.gift_week == -1 and a_old.gifts_this_week == 0
		and a_old.can_gift(10) and a_old.gifts_left_in_week(10) == Affinity.GIFTS_PER_WEEK)
	a_old.gift(15, 10)
	a_old.gift(15, 11)
	var round_trip: Dictionary = a_old.to_save()
	var a_new := Affinity.new()
	a_new.load_save(round_trip)
	_check("⑪c 왕복 저장이 주간 카운터를 보존",
		a_new.gift_week == GameClock.week_of(11) and a_new.gifts_this_week == 2
		and not a_new.can_gift(12))
	var a_bad := Affinity.new()
	a_bad.load_save({"gifts_this_week": 99, "gift_week": 1})
	_check("⑪d 손상값은 상한으로 잘린다", a_bad.gifts_this_week == Affinity.GIFTS_PER_WEEK)
	a_old.free()
	a_new.free()
	a_bad.free()

	# ── ⑫ 생일 당일 대사 플레이버(placeholder 1줄) ──
	print("── ⑫ 생일 대사 ──")
	# 부팅 직후엔 옥자 통보 대화가 이미 열려 있다 — DialogueBox.start는 열린 상태를 거절하므로
	# (원문 가드) 먼저 끝까지 넘겨 닫아 둔다(플레이어 조작과 같은 경로).
	var drain := 0
	while m.dialogue.is_open() and drain < 64:
		m.dialogue.advance()
		drain += 1
	# ★[S9-T4 / ADR-0067 결정 11 재작성] 미호가 birthday_lines 훅을 갖게 되어 placeholder
	#   **동일성**은 미호 경로에서 성립하지 않는다. 계약("생일엔 평소 대사 앞에 한 줄이 선다")은
	#   그대로 두고 출처만 캐릭터 본문으로 바꾼다 — placeholder 폴백 경로는 훅 없는 다른 주민이
	#   계속 지킨다(생일 판정식은 한 줄도 안 바뀌었다).
	m.clock.day = miho_bday
	m._start_resident_dialogue(r_miho2)
	_check("⑫a 생일엔 평소 대사 앞에 한 줄이 선다(캐릭터 본문)",
		m.dialogue.is_open() and m.dialogue.line() == String(r_miho2.node.birthday_lines()[0])
		and m.dialogue.line() != m.BIRTHDAY_PLACEHOLDER_LINE)
	# ★[S9-T4] 절기 물음(주 첫날)이 마지막 줄에 붙으면 넘기기로는 못 지나간다 — 플레이어와 같이
	#   첫 항을 고른다(DialogueBox.advance의 선택지 가드).
	var guard := _drain(m)
	_check("⑫b 끝까지 넘기면 닫힌다(평소 묶음이 뒤에 이어졌다)",
		not m.dialogue.is_open() and guard > 1)
	m.clock.day = miho_bday + 1
	m._start_resident_dialogue(r_miho2)
	_check("⑫c 비생일엔 그 줄이 없다",
		m.dialogue.line() != String(r_miho2.node.birthday_lines()[0]))
	_drain(m)

	m.free()
	cleaner.delete_save()
	cleaner.free()

	print("══ 결과: %s (실패 %d) ══" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(_fail)

# ★[S9b-T5] 그 절기에 생일이 배정된 주민 수 — 달력 마커 단언의 **단일 출처 파생**(⑩b·⑩f).
# 하드코딩한 칸 수는 조연이 한 명 붙을 때마다 stale이 된다(S9b-T3이 실증). 재야 하는 계약은
# "달력이 `Resident.BIRTHDAYS`를 그대로 비추는가"이지 그때그때의 수가 아니다.
func _season_birthday_count(season: int) -> int:
	var n := 0
	for rid in Resident.BIRTHDAYS:
		var b := Resident.birthday_of(String(rid))
		if b.size() == 2 and int(b[0]) == season:
			n += 1
	return n
