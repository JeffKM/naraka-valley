extends RefCounted
class_name GiftPrefs
# ★ [S8-T2 / ADR-0066 결정 2] 선물 선호 테이블 — "누가 무엇을 받으면 얼마나 기뻐하나"의 단일 출처.
#
# 목적: 선물이 *수확 작물 5종*에 갇혀 있던 구조를 걷어낸다. S8-T2 이전의 선호는
#       `Affinity.preferred_crop`(캐릭터당 작물 **한 종**)이 전부라, ㉠ 물고기·광물·요리는
#       구조적으로 선물이 안 됐고 ㉡ 실존 작물 5종이 미호·멜·바나·모찌·뱃사공에 소진돼
#       옹이·풀무·무골은 선호를 배정할 자리 자체가 없었다(main.gd 옛 주석 "남은 작물 0").
#       든 아이템 문법으로 입력을 바꾸면 대상 집합이 전 아이템으로 넓어지고, 그 넓어진
#       집합에 등급을 매기는 것이 이 파일이다.
#
# 구조(스타듀 1:1 — ADR-0066 결정 2):
#   ㉠ **유니버설 계층** = 아이템의 *결*로 갈리는 기본값(요리·보석 = 라이크 / 원자재·씨앗·미끼 =
#      디스라이크 / 쓰레기 = 헤이트 / 그 외 = 뉴트럴). 새 아이템이 카탈로그에 늘어도 이 계층이
#      자동으로 덮으므로 테이블을 매번 손보지 않아도 선물이 성립한다("평평 ≠ 막힘" — ADR-0008).
#   ㉡ **캐릭터별 개별 오버라이드** = 그 사람만의 러브 4~6종·헤이트 1~2종. 유니버설을 덮는다.
#
# ★★ **실제 인물 취향 소싱 시 이 테이블만 교체하면 된다(코드 0줄)** — 아래 OVERRIDES dict의
#    아이템 id 배열을 갈아 끼우는 것이 반영의 전부다(ADR-0066 결정 2 "owner 큐 1순위",
#    ADR-0032 §6). 판정·점수·품질 배율·알림 문구는 이 테이블을 데이터로만 읽는다.
#    지금 값은 **전부 잠정**이고, 근거는 각 캐릭터 블록의 한 줄 주석(도메인·속죄 테마 파생)이다.
#
# 설계 메모:
#   - crops.gd·item_catalog.gd와 같은 결의 **정적 참조 데이터**다(세이브 상태 0·노드 0).
#     class_name + static 헬퍼로 어디서든 GiftPrefs.tier_of("miho", id)로 읽는다.
#   - 데이터를 **복제하지 않는다**: 아이템 id는 ItemCatalog·CropCatalog·MenuCatalog 상수를 그대로
#     참조한다(단일 출처 — 오타 시 파스 에러로 즉시 드러난다).
#   - 점수의 두 눈금(뉴트럴 15 · 러브 40)은 **Affinity의 기존 상수를 승계**한다. 옛 "일반 선물 /
#     선호 선물"이 그대로 뉴트럴 / 러브가 된 것이라, 기존 세이브·기존 곡선이 그대로 굴러간다.

# ── 등급(tier) ────────────────────────────────────────────────────────────────
# 정수로 두는 이유: 대소 비교가 곧 "더 좋아함"이라 정렬·단언이 자연스럽고, 음수가 그대로
# "싫어함"의 방향을 뜻한다(포인트 부호와 같은 방향 = 읽는 사람이 부호를 두 번 해석하지 않는다).
const LOVE := 2
const LIKE := 1
const NEUTRAL := 0
const DISLIKE := -1
const HATE := -2

# 등급 → 획득 점수(ADR-0066 결정 2 "포인트(잠정)").
# ★ 러브 40 = Affinity.GIFT_PREFERRED_POINTS 승계 · 뉴트럴 15 = Affinity.GIFT_POINTS 승계.
#   두 값을 여기 다시 박지 않고 참조하는 이유는 quest_board가 GIFT_POINTS를 "선물 1회급"의
#   눈금으로 계속 쓰기 때문이다 — 눈금이 둘로 갈리면 의뢰 보상이 조용히 어긋난다.
const POINTS := {
	LOVE: Affinity.GIFT_PREFERRED_POINTS,   # +40
	LIKE: 25,
	NEUTRAL: Affinity.GIFT_POINTS,          # +15
	DISLIKE: -10,
	HATE: -20,
}

# 품질 배율(러브·라이크만 — ADR-0066 결정 2). 일반/은/금/이리듐.
# ★ **불변식: 일반 품질 러브(40) > 이리듐 라이크(int(25×1.5)=37)** — 스타듀가 지키는 그 성질이다.
#   이게 깨지면 "그 사람이 정말 좋아하는 것"보다 "아무거나 최고 등급"이 최적이 되어, 선호 테이블이
#   존재할 이유가 사라진다. gift_test가 이 부등식을 직접 단언한다.
# ★ 싫어하는 선물에 배율을 안 얹는 이유: 이리듐 쓰레기가 *덜* 미운 것도, *더* 미운 것도 어색하다
#   (혐오는 물건의 등급이 아니라 종류의 문제다).
const QUALITY_SCALE := [1.0, 1.1, 1.25, 1.5]

# 알림 문구에 붙는 꼬리표. 러브는 T3.3 원문 "(선호!)"를 그대로 승계한다(거동·문구 보존).
const TAGS := {
	LOVE: "(선호!) ",
	LIKE: "(좋아함) ",
	NEUTRAL: "",
	DISLIKE: "(시큰둥) ",
	HATE: "(질색!) ",
}

# ── 유니버설 계층 ─────────────────────────────────────────────────────────────
# 쓰레기(헤이트) — 인양물 잡동사니. 스타듀의 Trash/Driftwood 자리다.
const TRASH := [ItemCatalog.ROTTEN_NET]

# 보석(라이크) — 광물 중 유일한 예외군이다. 광석·돌·혼탄은 원자재라 디스라이크로 떨어지지만
# 보석은 "그 자체로 아름다운 물건"이라 결이 다르다(스타듀 Gems = Universal Like 1:1).
const GEMS := [
	ItemCatalog.GEM_NEOKSUJEONG, ItemCatalog.GEM_MYEONGOK, ItemCatalog.GEM_YEOMJUSEOK,
	ItemCatalog.GEM_MYEONGBU_GEUMGANG, ItemCatalog.GEM_OSAEK_HONOK,
]

# ── 캐릭터별 오버라이드(전 9인 — 관계 트랙 보유자 전원) ────────────────────────
# ★ 전부 **잠정**(owner 큐 1순위 — 실제 인물 취향 소싱분으로 교체). 근거는 캐릭터의 도메인과
#   속죄 테마(ADR-0004)에서 파생했고, 기존 preferred_crop 5건은 러브로 그대로 승계했다.
# ★ 러브 4~6종 · 헤이트 1~2종(스타듀 후보 중앙값 5~8 준용). 겹침은 허용한다 — 두 사람이 같은
#   물건을 좋아하는 것은 자연스럽고, 캐릭터별 판정이 서로 독립이라 부작용이 0이다.
const OVERRIDES := {
	# 미호 — 기른 것에 애착(방화 → 작물 양육). 헤이트 = 불의 잔재(생전의 죄를 떠올리는 것).
	"miho": {
		LOVE: [
			CropCatalog.YEONGHON_HOBAK,      # ★기존 preferred_crop 승계(영혼 호박)
			FruitTreeCatalog.HONBAEKDO,      # 혼백도 — 자기가 기른 혼의 나무 열매
			ItemCatalog.MIHOK_NANCHO,        # 미혹난초 — 여우가 홀리는 숲의 꽃
			ItemCatalog.SEORI_DONGBAEK,      # 서리동백
			MenuCatalog.HOBAK_LATTE,         # 호박 라떼 — 자기 호박이 잔에 담겨 돌아온 것
		],
		HATE: [ItemCatalog.EMBER_SHARD, ItemCatalog.HONBULSSI],   # 업화석 조각·혼불씨(불)
	},
	# 멜 — 카페의 값진 것(도박·사채 → 카페 운영). 헤이트 = 알돌(열어 봐야 아는 것 = 끊은 습관).
	"mel": {
		LOVE: [
			CropCatalog.PIANHWA,                  # ★기존 preferred_crop 승계(피안화)
			MenuCatalog.HONJEONG_EINSPANNER,      # 혼정 아인슈페너 — 카페의 간판
			MenuCatalog.DONGBAEK_MILKTEA,
			ItemCatalog.GEM_MYEONGBU_GEUMGANG,    # 명부금강
			ItemCatalog.NARAK_HONJEONG,           # 나락혼정 — 프리미엄 소재
		],
		HATE: [ItemCatalog.GEODE_NEOKAL, ItemCatalog.GEODE_EOPHWA],
	},
	# 바나 — 밤의 것(주거침입·흡혈 → 밤 경비). 헤이트 = 붉은 즙(피를 떠올리는 것).
	"bana": {
		LOVE: [
			CropCatalog.HONRYEONGCHO,        # ★기존 preferred_crop 승계(혼령초)
			ItemCatalog.HONBULSSI,           # 혼불씨 — 밤을 밝히는 불씨
			ItemCatalog.MYEONGBUHWAN,        # 명부환 — 경비의 상비약
			ItemCatalog.SEORI_HONBAEKCHO,    # 서리혼백초
			FishCatalog.CHORONG_CHI,         # 초롱치 — 밤에만 무는 물고기
		],
		HATE: [ItemCatalog.NEOK_DALGI, ItemCatalog.JAETBIT_BOKBUNJA],
	},
	# 네오 — 팔릴 물건(만물상 점주). 헤이트 = 재고만 차지하는 것.
	"neo": {
		LOVE: [
			ItemCatalog.GEM_OSAEK_HONOK,     # 오색혼옥 — 진열장의 꿈
			ItemCatalog.GEM_YEOMJUSEOK,
			ItemCatalog.HARDWOOD,            # 단단한 원목 — 좋은 재고
			ItemCatalog.RARECROW_1,          # 레어크로우 ①·② — 상인이 탐내는 수집물(비매품)
			ItemCatalog.RARECROW_2,
		],
		HATE: [ItemCatalog.STONE],
	},
	# 모찌 — 달고 물렁한 것(카페 과일·푸딩에서 난 존재). 헤이트 = 쓰고 비린 것.
	"mochi": {
		LOVE: [
			CropCatalog.HWANGCHEON_PODO,     # ★기존 preferred_crop 승계(황천포도)
			ItemCatalog.NEOK_DALGI,
			ItemCatalog.JAETBIT_BOKBUNJA,
			ItemCatalog.JEOSEUNG_SANDALGI,
			MenuCatalog.PODO_SMOOTHIE,
			MenuCatalog.BULSAGWA_TART,
		],
		HATE: [ItemCatalog.JEOSEUNG_SAM, ItemCatalog.NEOK_SEONGGAE],
	},
	# 뱃사공 — 물길이 주는 것(생선가게 점주). 헤이트 = 뱃바닥에 끼는 것.
	# ★물고기를 선물로 받는 생선가게 점주는 어색하다는 옛 판단은 유지 — 어종은 러브에 안 넣는다
	#   (유니버설 뉴트럴로 받되 기뻐하지는 않는다).
	"boatman": {
		LOVE: [
			CropCatalog.BULSAGWA,            # ★기존 preferred_crop 승계(불사과)
			ItemCatalog.HWANGCHEON_SANHO,
			ItemCatalog.YURI_GODUNG,
			ItemCatalog.MULBINEUL_JOGAE,
			MenuCatalog.HAEPARI_ADE,
		],
		HATE: [ItemCatalog.JEOSEUNG_IKKI],
	},
	# 옹이 — 살아 있는 나무가 주는 것(목령·목공방). 헤이트 = **잘린 나무**(동족의 주검).
	# ★main.gd 옛 주석 "비-작물 선물이 편입되면 옹이 선호는 명단풍꿀 결"의 정확한 이행이다.
	"ongi": {
		LOVE: [
			ItemCatalog.MYEONGDANPUNG_KKUL, ItemCatalog.SOLNEOKJIN, ItemCatalog.NEOKSUJI,
			ItemCatalog.SEED_JEOSEUNGSOL, ItemCatalog.SEED_MYEONGDANPUNG, ItemCatalog.SEED_NEOKCHAM,
		],
		HATE: [ItemCatalog.WOOD, ItemCatalog.HARDWOOD],
	},
	# 풀무 — 화덕에 들어가는 것(도깨비 대장장이). 헤이트 = 얼어붙은 것.
	# ★main.gd 옛 주석 "풀무 선호는 혼탄·주괴 결"의 이행.
	"pulmu": {
		LOVE: [
			ItemCatalog.HONTAN,
			ItemCatalog.INGOT_MYEONGDONG, ItemCatalog.INGOT_YUCHEOL,
			ItemCatalog.INGOT_HWANGCHEONGEUM, ItemCatalog.INGOT_NARAKCHEOL,
		],
		HATE: [ItemCatalog.SEORI_DONGBAEK, ItemCatalog.EONHON_PPURI],
	},
	# 무골 — 무용담의 전리품(백골 무사·길드). 헤이트 = 피안화(죽은 자에게 바치는 꽃 —
	# 이미 백골인 무사에게는 성급한 조문이다).
	# ★무기는 애초에 선물 불가(giftable — 도구 칸)라 러브에 못 넣는다.
	"mugol": {
		LOVE: [
			ItemCatalog.NARAK_HONJEONG, ItemCatalog.NEOKGARU,
			ItemCatalog.GEODE_EOPHWA, ItemCatalog.GEM_MYEONGBU_GEUMGANG,
		],
		HATE: [CropCatalog.PIANHWA],
	},
}

# ── 조회 ──────────────────────────────────────────────────────────────────────
# 이 아이템을 선물로 건넬 수 있는가. **막는 건 딱 두 부류**다:
#   ㉠ 도구 칸(CAT_TOOL = 괭이·낫·낚싯대·태클·무기) — 유니크 장착물이라 건네면 그 동사를 잃는다.
#   ㉡ 열쇠(나락 열쇠) — 유일 입수 경로가 60층 상자라 건네면 **진행이 봉쇄된다**(혼백관 기증
#      목록에서 열쇠를 뺀 것과 정확히 같은 판단 — item_catalog.gd KEYS 주석).
# 그 밖에는 전부 건넬 수 있다(싫어하는 물건도 *건네지긴* 한다 — 그게 음수 채널의 의미다).
static func giftable(id: String) -> bool:
	if id == "" or not ItemCatalog.has_item(id):
		return false
	if ItemCatalog.category_of(id) == ItemCatalog.CAT_TOOL:
		return false
	if ItemCatalog.KEYS.has(id):
		return false
	return true

# 그 사람에게 이 아이템은 몇 등급인가(오버라이드 → 유니버설 순).
static func tier_of(resident_id: String, item_id: String) -> int:
	var ov: Dictionary = OVERRIDES.get(resident_id, {})
	for tier in [LOVE, LIKE, DISLIKE, HATE]:   # 개별 지정이 유니버설을 덮는다
		var list: Array = ov.get(tier, [])
		if list.has(item_id):
			return tier
	return universal_tier(item_id)

# 아이템의 결로만 갈리는 기본 등급(캐릭터 무관).
static func universal_tier(id: String) -> int:
	if TRASH.has(id):
		return HATE
	if MenuCatalog.has(id):
		return LIKE        # 카페 요리 — 손수 낸 한 잔(스타듀 Cooking = Universal Like)
	if GEMS.has(id):
		return LIKE        # 보석
	if ItemCatalog.INGOTS.has(id):
		return NEUTRAL     # 주괴 = 가공품이라 원자재(디스라이크)까지 내려가진 않는다
	if GearCatalog.is_bait(id):
		return DISLIKE     # 미끼 — 벌레·떡밥을 사람에게 건네는 결
	var cat := ItemCatalog.category_of(id)
	if cat == ItemCatalog.CAT_MATERIAL:
		return DISLIKE     # 원자재(건초·개간 드랍·벌목 산출·광석·돌·혼탄·잡귀 부산물)
	if cat == ItemCatalog.CAT_SEED or cat == ItemCatalog.CAT_SAPLING or cat == ItemCatalog.CAT_FERTILIZER:
		return DISLIKE     # 심을 것·뿌릴 것 — 선물이 아니라 심부름을 떠넘기는 결
	return NEUTRAL         # 수확물·과일·채집물·어획물·통용물·수액·산물·유품·설치물·환약·계단

# 그 선물이 주는 호감도 점수(음수 = 혐오 채널). 품질 배율은 **러브·라이크에만**, 그리고
# 품질을 실제로 싣는 아이템(CAT_HARVEST — 인벤 슬롯이 등급을 보존하는 유일한 카테고리)에만
# 얹는다. 무품질 아이템은 언제나 ×1이라 quality 인자를 무시한다.
static func points_for(tier: int, item_id: String = "", quality: int = ItemCatalog.Q_NORMAL) -> int:
	var base: int = int(POINTS.get(tier, POINTS[NEUTRAL]))
	if not (tier == LOVE or tier == LIKE):
		return base
	if ItemCatalog.category_of(item_id) != ItemCatalog.CAT_HARVEST:
		return base
	return int(base * QUALITY_SCALE[clampi(quality, 0, 3)])

# 그 사람에게 이 아이템(이 품질)을 건넸을 때의 점수 — tier_of + points_for의 한 창구.
static func gift_points(resident_id: String, item_id: String, quality: int = ItemCatalog.Q_NORMAL) -> int:
	return points_for(tier_of(resident_id, item_id), item_id, quality)

# 알림 문구 꼬리표("" = 뉴트럴).
static func tag_of(tier: int) -> String:
	return String(TAGS.get(tier, ""))

# 그 사람의 러브/헤이트 목록(테스트·후속 UI가 테이블을 밖에서 읽는 창구 — dict를 직접 뒤지지
# 않게 한다. 관계 탭에 "좋아하는 선물"을 띄우게 되면 이 창구를 그대로 쓴다).
static func loves(resident_id: String) -> Array:
	return Array(OVERRIDES.get(resident_id, {}).get(LOVE, []))

static func hates(resident_id: String) -> Array:
	return Array(OVERRIDES.get(resident_id, {}).get(HATE, []))

# 오버라이드를 가진 주민 id 전부(선언 순 = 등록 순). 테스트가 전 캐릭터를 순회할 때 쓴다.
static func residents_with_prefs() -> Array:
	return OVERRIDES.keys()
