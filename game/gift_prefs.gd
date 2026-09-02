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
			# ★[S10 폴리시] 옛 자리는 레어크로우 ①②였다 — 상인이 탐낼 물건인 건 맞지만, 건네는
			#   순간 그 종이 세상에서 사라져 8종 완주가 막히므로 `giftable`이 이제 막는다(위 ㉣).
			#   건넬 수 없는 물건을 러브 표에 두면 영영 도달 못 하는 죽은 칸이 된다 — 같은 결의
			#   "팔릴 물건"으로 갈아 끼운다(진열장 보석 하나 · 값나가는 금속 하나).
			ItemCatalog.GEM_NEOKSUJEONG,     # 넋수정 — 진열장에 놓기 좋은 결
			ItemCatalog.INGOT_HWANGCHEONGEUM,  # 황천금 주괴 — 그냥 두어도 값이 오르는 재고
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
	# ── ★[S9b-T1 / ADR-0068 결정 3] 조연 코러스 개통분 ─────────────────────────
	# 깨비 — 산이 주는 것 + 묵거리(도깨비·뒷산 야생 출신 · [narrative-bible §5.2] "메밀묵 얻어먹던
	# 단골"). 메밀은 아직 카탈로그에 없으므로 **묵의 재료인 도토리**가 그 자리를 대신한다.
	# 헤이트 = **무쇠**. 도깨비가 쇠를 못 견딘다는 설화 그대로라 캐릭터 정체성에서 곧장 나온다
	# (풀무의 러브(주괴)와 정확히 반대편 — 선물 경제가 자연히 갈린다).
	# ⚠️ 불붙은 것(혼불씨·업화석)은 **넣지 않는다**: 깨비의 불은 백스토리 한정이고(residents.md
	#   가드레일), 미호의 헤이트와 겹쳐 "불 캐릭터 둘"로 읽히는 것을 피한다.
	"kkaebi": {
		LOVE: [
			ItemCatalog.JAETBIT_DOTORI,      # 잿빛도토리 — 묵거리(산 밑에서 얻어먹던 그 접시)
			ItemCatalog.NEOK_SONGI,          # 넋송이버섯 — 뒷산이 주는 것
			ItemCatalog.SEONGYA_SOLBANGUL,   # 성야솔방울 — 주워서 던지기 좋은 것(장난)
			MenuCatalog.SONGI_SOUP,          # 넋송이 수프 — 든든한 한 그릇
			MenuCatalog.BUNGEO_PPANG,        # 붕어빵 — 장난꾸러기의 간식
		],
		HATE: [ItemCatalog.INGOT_YUCHEOL, ItemCatalog.ORE_YUCHEOL],   # 무쇠 — 도깨비 설화의 금기
	},
	# ★[S9b-T1 / ADR-0068 결정 3] 켄 — **살아 있는 약초·화초**(그날 밤 약방의 조수였고, 지금은
	# 창가에 화분 열둘을 기른다 — [narrative-bible §5.2]·[residents.md] "식물 사랑"). 손끝으로만
	# 만지는 자에게 러브는 *살아 있는 것*이다.
	# 헤이트 = **다 타고 남은 것**(혼탄·업화석 조각). 그 밤의 불이 남긴 결이라 켄의 손에 쥐여지면
	# 안 되는 물건이다. ⚠️미호 헤이트(혼불씨·업화석 = *산 불*)와는 결이 갈린다 — 미호는 아직 타는
	# 불이 무섭고, 켄은 이미 타 버린 뒤가 무섭다.
	# ★옹이(목령 = 나무)와도 겹치지 않는다: 옹이 = 수액·나무 씨앗 / 켄 = 약재·화초.
	"ken": {
		LOVE: [
			ItemCatalog.JEOSEUNG_SAM,        # 저승삼 — 약방의 으뜸 약재(그가 나르던 것)
			ItemCatalog.EONHON_PPURI,        # 언혼뿌리
			ItemCatalog.SEORI_HONBAEKCHO,    # 서리혼백초
			ItemCatalog.MIHOK_NANCHO,        # 미혹난초 — 화분에 올리고 싶은 꽃
			ItemCatalog.JEOSEUNG_IKKI,       # 저승 이끼 — 큰 손으로 기르기 가장 어려운 것
		],
		HATE: [ItemCatalog.HONTAN, ItemCatalog.EMBER_SHARD],
	},
	# ★[S9b-T2 / ADR-0068 결정 3] 설화 — **차고 맑은 것**([narrative-bible §5.3] 설녀 · 냉기 존재).
	# 러브의 축은 "그녀 손에서 상하지 않는 것" 하나다: 서리 낀 겨울 채집물·얼음 같은 결정·
	# 은비늘 어종·카페에서 가장 값싼 냉수. ★냉수를 러브에 둔 것이 이 캐릭터의 결이다 — 가장
	# 흔하고 싼 잔이 그녀에겐 가장 편한 잔이라(고고함이 사치가 아니라 결핍의 다른 이름) 선물
	# 경제에서 **초반부터 닿을 수 있는 러브**가 하나 열린다("평평 ≠ 막힘" 결).
	# 헤이트 = **김이 오르는 것**(넋 데운 우유·넋송이 수프). 미호(산 불)·켄(타 버린 재)과 결이
	# 갈린다 — 설화가 못 견디는 건 불이 아니라 *온기 그 자체*이고, 그래서 이 헤이트는 반전 로맨스
	# ([narrative-bible §5.3] "결혼 = 따뜻해지는 법을 연습")의 **출발선 표시**이기도 하다.
	"seolhwa": {
		LOVE: [
			ItemCatalog.SEORI_DONGBAEK,      # 서리동백(성야절) — ♡2 관문이 세우는 그 꽃
			ItemCatalog.SEORI_HONBAEKCHO,    # 서리혼백초(성야절 특수) — 서리가 이름에 든 약초
			ItemCatalog.GEM_NEOKSUJEONG,     # 넋수정 — 얼음과 가장 닮은 결정
			FishCatalog.EUNBINEUL_CHEONGEO,  # 은비늘청어 — 찬물의 은빛
			MenuCatalog.COLD_WATER,          # 삼도천 냉수 — 가장 싼 잔이 그녀에겐 가장 편한 잔
		],
		HATE: [MenuCatalog.HOT_MILK, MenuCatalog.SONGI_SOUP],   # 김이 오르는 것
	},
	# ★[S9b-T2 / ADR-0068 결정 3] 스칼렛 — **값나가고 고운 것**([narrative-bible §5.3] 메두사·
	# 옛 간판 타짜 · "치명적 매력"). 값을 아는 사람이라 물건의 급이 곧 예의고, 그중에서도 *맑은
	# 것*(넋수정)은 그녀가 못 하는 일(속이 다 보이는 것)이라 더 좋아한다. 서리동백 ↔ 동백 밀크티는
	# 재료-요리 한 쌍이고(미호 호박 ↔ 호박 라떼 선례), 혼정 아인슈페너는 겉이 달고 속이 쓴 잔이라
	# 그대로 이 인물의 결이다(멜 러브와 겹치지만 근거가 다르다 — 멜=카페의 간판 / 스칼렛=그 맛).
	# 헤이트 = **석화 목재**(자기가 사람에게 한 짓이 굳어 버린 형상 — §5.3 "돌처럼 가둬두고")와
	# **업화알돌**(열어 봐야 아는 것 = 남의 전 재산이 걸려 있던 그 판). ⚠️멜 헤이트(알돌)와 한 종이
	# 겹치나 결이 갈린다 — 멜은 *끊은 습관*이 무섭고, 스칼렛은 *자기가 쥐여 준 판*이 부끄럽다.
	"scarlet": {
		LOVE: [
			ItemCatalog.GEM_MYEONGOK,             # 명옥 — 매끄럽고 값진 것
			ItemCatalog.GEM_NEOKSUJEONG,          # 넋수정 — 속이 다 보이는 것(그녀가 못 하는 일)
			ItemCatalog.SEORI_DONGBAEK,           # 서리동백 — 서리 속에서 붉은 꽃(이름값·츤데레)
			MenuCatalog.DONGBAEK_MILKTEA,         # 동백 밀크티 — 그 꽃이 잔에 담겨 돌아온 것
			MenuCatalog.HONJEONG_EINSPANNER,      # 혼정 아인슈페너 — 겉은 달고 속은 쓴 잔
		],
		HATE: [ItemCatalog.PETRIFIED_WOOD, ItemCatalog.GEODE_EOPHWA],
	},
	# ★[S9b-T3 / ADR-0068 결정 3] 미르 — **오래 걸려야 되는 것**([narrative-bible §5.2] 이무기 ·
	# "천 년을 홀로 버틴" 자). 러브의 축은 시간 하나다: 오래 눌려야 나오는 구슬, 오래 묵을수록
	# 약이 되는 뿌리, 달빛을 오래 받아야 서는 버섯, 용문을 오르려 거슬러 가는 잉어(승천의 거울 —
	# 자기는 못 됐지만 저건 아직 가능성이 있다는 츤데레 러브), 그리고 오래 끓여야 나는 잔.
	# ★보리차를 러브에 둔 것이 설화의 냉수(가장 싼 잔)와 같은 결의 이행이다 — 기본 4잔 중 하나라
	#   선물 경제에서 **초반부터 닿을 수 있는 러브**가 하나 열린다("평평 ≠ 막힘"). 설화=냉수 /
	#   미르=보리차로 기본 잔이 갈려 두 사람이 겹치지도 않는다.
	# 헤이트 = **빨리 되게 하는 것**(성장촉진·하이퍼 비료). 천 년을 기다리다 조급해져 판을 벌인
	# 자에게 이건 모욕이자 자기 죄의 이름이다. ⚠️유니버설은 비료를 디스라이크로만 두는데
	# (심부름을 떠넘기는 결) 미르만 **헤이트로 끌어올린다** — 오버라이드가 유니버설을 덮는
	# 자리이고, 그 차이 자체가 이 인물의 결이다.
	# ★오색혼옥은 네오 러브와 겹치나 근거가 다르다 — 네오=진열장의 꿈 / 미르=끝내 못 문 구슬.
	"mir": {
		LOVE: [
			ItemCatalog.GEM_OSAEK_HONOK,     # 오색혼옥 — 끝내 못 문 구슬(여의주에 가장 가까운 것)
			ItemCatalog.ANGAE_DORAJI,        # 안개도라지 — 오래 묵을수록 약이 되는 뿌리
			ItemCatalog.MYEONGWOL_BEOSEOT,   # 명월버섯 — 여의주 대신 올려다본 달의 것
			FishCatalog.SANGYEOTGIL_INGEO,   # 상엿길잉어 — 용문을 거슬러 오르는 것(승천의 거울)
			MenuCatalog.BARLEY_TEA,          # 보리차 — 오래 끓여야 나는 맛(초반부터 닿는 러브)
		],
		HATE: [ItemCatalog.FERT_SPEED, ItemCatalog.FERT_HYPER],   # 빨리 되게 하는 것
	},
	# ★[S9b-T3 / ADR-0068 결정 3] 루카 — **이빨을 안 써도 되는 것 · 손에 쥐고 세는 것**
	# ([narrative-bible §5.2] 늑대인간 · "지독하게 이성적"). 러브의 축은 *충동을 가라앉히는 절차*
	# 하나다: 굽고 눌러 익힌 것(도미 파니니 — 날것의 형태가 완전히 지워진 접시), 김이 오르는 잔
	# (넋 데운 우유 — 보름밤에 자기를 재우려 마시는 것), 쓴 뿌리(안개도라지 — 씹으면 정신이 든다),
	# 손에 쥐고 알을 세는 돌(염주석 — 번뇌를 세는 그 물건), 그리고 **명월버섯**(달을 이름에 가진
	# 것 — 그가 유일하게 달을 반기는 방식은 접시 위에서다).
	# ★ 넋 데운 우유가 **설화의 헤이트와 정확히 반대편**인 것이 설계다(같은 잔이 두 사람에게 정반대
	#   의미 — 설화는 온기 자체를 못 견디고, 루카는 온기로 자기를 재운다). 선물 경제가 자연히 갈린다.
	# 헤이트 = ㉠ **먹빛장어**(아직 살아 꿈틀대는 날것 — 스스로 금한 그 입질을 손에 쥐여 주는 물건)
	#   ㉡ **미혹난초**(정신을 흐리는 꽃 — 이성을 지키는 것이 이 인물의 유일한 속죄 방식이라
	#   홀리는 것은 그에게 독이다). ⚠️미호·켄의 러브(미혹난초)와 정면으로 갈리는데, 그것이 의도다 —
	#   같은 꽃을 누구는 기르고 싶어 하고 누구는 무서워한다(캐릭터별 판정은 서로 독립이라 부작용 0).
	# ⚠️ **전투·경비 어휘의 물건은 러브에 안 넣는다** — 바나(나락 전투 곱셈기)의 도메인 침범 금지
	#   ([narrative-bible §4] 링 2 "곱셈기 없음"). 명부환·혼불씨류가 여기 없는 이유가 그것이다.
	"luca": {
		LOVE: [
			ItemCatalog.MYEONGWOL_BEOSEOT,   # 명월버섯 — 달을 이름에 가진 것(접시 위의 달)
			ItemCatalog.ANGAE_DORAJI,        # 안개도라지 — 쓴 뿌리(씹으면 정신이 든다)
			ItemCatalog.GEM_YEOMJUSEOK,      # 염주석 — 충동이 올라오면 손에 쥐고 세는 돌
			MenuCatalog.HOT_MILK,            # 넋 데운 우유 — 보름밤에 자기를 재우는 잔
			MenuCatalog.DOMI_PANINI,         # 도미 파니니 — 날것의 형태가 완전히 지워진 접시
		],
		HATE: [FishCatalog.MEOKBIT_JANGEO, ItemCatalog.MIHOK_NANCHO],
	},
	# ★[S9b-T4] 프로스티(예티) — 축은 **품에 넣어 올 수 있는 것**이다([narrative-bible §5.4]
	#   "말 못 해도 눈망울·몸짓 · 지치고 추울 때 품에 안아 푹신함"). 값나가는 것을 고를 줄 모르는
	#   존재라 러브가 전부 *싸고 손에 쥐는 것*이고, 그 싼 것들이 로스터에서 제일 비싼 취향
	#   (스칼렛의 명옥·미르의 오색혼옥)과 정확히 대척점에 선다.
	# ★ 헤이트가 **혼불씨 하나뿐**인 것도 설계다 — 싫어하는 법을 거의 모르는 존재이고, 유일하게
	#   못 견디는 것이 *털에 옮겨붙는 것*이다(설산 털뭉치의 본능. 켄의 혼탄·업화석 헤이트와는
	#   결이 다르다: 켄은 약재를 태우는 것이 싫고 프로스티는 자기 몸이 무섭다).
	"frosty": {
		LOVE: [
			CropCatalog.YEONGHON_HOBAK,      # 영혼 호박(성야절) — 두 팔로 안아 오기 딱 좋은 것
			ItemCatalog.SEONGYA_SOLBANGUL,   # 성야솔방울 — 그가 늘 놓고 가던 그것(♡1~2의 그 물건)
			ItemCatalog.EONHON_PPURI,        # 언혼뿌리 — 얼어붙은 혼이라는 이름. 자기를 가리키는 유일한 물건
			MenuCatalog.HOT_MILK,            # 넋 데운 우유 — 말이 필요 없는 잔(★설화의 헤이트와 정반대)
			MenuCatalog.DANPUNG_PANCAKE,     # 명단풍꿀 팬케이크 — 푹신하게 부푼 것(자기 몸과 같은 결)
		],
		HATE: [ItemCatalog.HONBULSSI],       # 혼불씨 — 털에 옮겨붙는 것
	},
	# ★[S9b-T5] 강림(폐직 저승사자) — 축은 **직무의 잔해와 격식**이다([narrative-bible §5.2]
	#   "규칙 뒤에 감정을 숨긴 차가운 죄" · "츤데레 가디언"). 러브 다섯이 전부 *이름에 저승의
	#   직무가 박힌 것*이거나 *격식 그 자체*이고, 그가 물건을 고르는 기준이 값이 아니라 **이름**
	#   이라는 것이 로스터에서 이 인물만의 결이다(스칼렛=값 / 미르=시간 / 프로스티=품 / 강림=이름).
	# ★ 아메리카노를 러브에 둔 것이 설화의 냉수·미르의 보리차와 같은 결의 이행이다 — 기본 4잔
	#   중 마지막으로 남아 있던 잔이라 선물 경제에서 **초반부터 닿을 수 있는 러브**가 하나 열린다
	#   ("평평 ≠ 막힘"). 검고 쓰고 아무것도 안 섞은 잔이라는 점도 그대로 이 인물이다.
	# ★ 명부금강(멜)·염주석(네오·루카)은 겹치나 근거가 전부 다르다 — 멜=값진 보석 / 네오=팔릴
	#   재고 / 루카=충동을 세는 돌 / 강림=**세는 습관 그 자체**(명부를 잃고도 아침마다 사람을
	#   센다 — GATE_HEART_1). 겹침은 gift_prefs 머리말이 명시 허용한다(판정은 캐릭터별 독립).
	# 헤이트 = **넋가루 하나뿐**이다. 흩어진 잡귀가 남기는 재 = *인도받지 못하고 흩어진 혼의
	#   잔해*이고, 그것은 이 인물에게 자기 직무의 실패를 손에 쥐여 주는 물건이다. ⚠️유니버설은
	#   원자재라 디스라이크로만 두는데 강림만 **헤이트로 끌어올린다** — 오버라이드가 유니버설을
	#   덮는 자리이고, 그 차이 자체가 이 인물의 결이다. ★무골의 러브(넋가루 = 무용담의 전리품)와
	#   **정확히 정반대 의미**인 것이 설계다(같은 재가 한쪽엔 전과, 한쪽엔 실패의 이름).
	# ⚠️ **돈·매출·장부 어휘의 물건은 러브에 안 넣는다** — 멜(마진 곱셈기·사실의 조각)의 도메인
	#   침범 금지([narrative-bible §4] 링 2 "곱셈기 없음"). 강림이 세는 것은 언제나 사람 수다.
	"gangrim": {
		LOVE: [
			MenuCatalog.AMERICANO,               # 아메리카노 — 검고 쓰고 아무것도 안 섞은 잔(기본 4잔의 마지막 자리)
			ItemCatalog.GEM_MYEONGBU_GEUMGANG,   # 명부금강 — 이름에 「명부」가 박힌 유일한 돌
			ItemCatalog.GEM_YEOMJUSEOK,          # 염주석 — 알을 세는 물건(명부를 잃고도 남은 습관)
			FishCatalog.SATGAT_OJINGEO,          # 삿갓오징어 — 제 갓과 같은 이름을 가진 것
			ItemCatalog.JEOSEUNG_SAM,            # 저승삼 — 인도만 하고 한 번도 먹여 보지 못한 약재
		],
		HATE: [ItemCatalog.NEOKGARU],            # 넋가루 — 인도받지 못하고 흩어진 것의 재
	},
	# ★[S9b-T6] 세레나(인어) — 축은 **소리**다([narrative-bible §5.3] "세상을 흔드는 목소리를
	#   나른한 무관심 속에 흘린" 방관의 죄 · "청순한 목소리로 카페 정화"). 러브 다섯이 전부
	#   *소리가 남아 있는 물건*이거나 *소리를 내게 해 주는 것*이고, 그녀가 물건을 고르는 기준이
	#   값도 쓸모도 아니라 **울리느냐**라는 것이 로스터에서 이 인물만의 결이다(스칼렛=값 /
	#   미르=시간 / 프로스티=품 / 강림=이름 / 세레나=**소리**).
	# ★ 겹침 셋(유리고둥·물비늘조개=뱃사공 / 넋수정=설화·스칼렛)은 근거가 전부 다르다 —
	#   뱃사공=물길이 주는 것 / 설화=얼음과 닮은 결정 / 스칼렛=속이 다 보이는 것 / 세레나=
	#   **귀에 대면 아직 우는 것·두드리면 우는 것**. 겹침은 gift_prefs 머리말이 명시 허용한다
	#   (판정은 캐릭터별 독립). 특히 물비늘조개는 **다물면 소리가 갇히는 것**이라 이 인물의
	#   자기 은유이기도 하다(입을 다물고 안 돌아본 죄 — ♡4).
	# ★ 저승달래·혼잎박하는 **목**의 축이다 — 「달래」는 이름이 곧 *달래다*(파도를 잠재우던 그
	#   일)이고, 박하는 목을 틔우는 잎이라 노래하는 자의 약이다. 둘 다 저승 숲 일반종이라
	#   중반부터 꾸준히 닿는다("평평 ≠ 막힘").
	# 헤이트 = **혼불씨 하나뿐**이다. 물의 존재에게 옮겨붙는 불이고, 동시에 **그 밤의 모양**이라
	#   손에 쥐여 주는 순간 목이 잠긴다(♡3 그날 밤 고백 · 일상 ♡1~2의 "목이 저절로 닫혀"가
	#   가리키는 것과 같은 결). ⚠️유니버설은 원자재라 디스라이크로만 두는데 세레나는 프로스티와
	#   함께 **헤이트로 끌어올린다** — 두 사람의 근거는 완전히 다르다(프로스티=털에 옮겨붙는 것 /
	#   세레나=물에 있어선 안 되는 것). 같은 물건이 두 사람에게 다른 이유로 미운 것이 설계다.
	# ⚠️ **낚시·물때·어획 어휘의 물건은 러브에 안 넣는다** — 어종을 하나도 안 고른 것이 그
	#   이행이다(뱃사공의 "생선가게 점주가 물고기를 받는 어색함"과는 다른 근거: 세레나에게
	#   물고기는 *노래를 듣고 온 것들*이라 선물이 아니라 기억이다).
	"serena": {
		LOVE: [
			ItemCatalog.YURI_GODUNG,         # 유리고둥 — 귀에 대면 아직 파도가 우는 껍데기
			ItemCatalog.MULBINEUL_JOGAE,     # 물비늘조개 — 다물면 소리가 갇히는 것(자기 은유)
			ItemCatalog.JEOSEUNG_DALLAE,     # 저승달래 — 이름이 곧 *달래다*(파도를 잠재우던 그 일)
			ItemCatalog.HONIP_BAKHA,         # 혼잎박하 — 목을 틔우는 잎(노래하는 자의 약)
			ItemCatalog.GEM_NEOKSUJEONG,     # 넋수정 — 두드리면 맑게 우는 돌
		],
		HATE: [ItemCatalog.HONBULSSI],       # 혼불씨 — 물에 있어선 안 되는 것(그리고 그 밤의 모양)
	},
}

# ── 조회 ──────────────────────────────────────────────────────────────────────
# 이 아이템을 선물로 건넬 수 있는가. **막는 건 네 부류**다:
#   ㉠ 도구 칸(CAT_TOOL = 괭이·낫·낚싯대·태클·무기) — 유니크 장착물이라 건네면 그 동사를 잃는다.
#   ㉡ 열쇠(나락 열쇠) — 유일 입수 경로가 60층 상자라 건네면 **진행이 봉쇄된다**(혼백관 기증
#      목록에서 열쇠를 뺀 것과 정확히 같은 판단 — item_catalog.gd KEYS 주석).
#   ㉢ ★[S9-T7] 책(CAT_BOOK) — [ADR-0034] #7. 이건 진행 봉쇄가 아니라 **톤** 때문이다: 되찾은
#      옥자의 유품 키프세이크를 남에게 건네는 것 자체가 이 게임의 결이 아니다(불태워진 사람의
#      물건을 주워다 선물로 돌리는 그림). 노트도 같이 막는다 — 남의 비밀을 건네는 것도 같은 결.
#   ㉣ ★레어크로우(8종) — ㉡과 같은 **진행 봉쇄**다: 종마다 창구가 하나뿐이고 그 창구가 전부
#      1회 한정 원장이라(마일스톤·행사·우편·보부상·시련장) 건네면 그 종이 세상에서 사라져
#      8종 완주가 영영 불가능해진다. 백팩 버리기(main `_on_frame_discard`)를 막은 것과 정확히
#      같은 판단이고, 소지∪배치 파생 원장(`_rarecrow_owned`)이 기대는 불변식이 바로 이것이다.
# 그 밖에는 전부 건넬 수 있다(싫어하는 물건도 *건네지긴* 한다 — 그게 음수 채널의 의미다).
static func giftable(id: String) -> bool:
	if id == "" or not ItemCatalog.has_item(id):
		return false
	var cat := ItemCatalog.category_of(id)
	if cat == ItemCatalog.CAT_TOOL or cat == ItemCatalog.CAT_BOOK:
		return false
	if ItemCatalog.KEYS.has(id):
		return false
	if ItemCatalog.is_rarecrow(id):
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
# 품질을 실제로 싣는 아이템에만 얹는다. 무품질 아이템은 언제나 ×1이라 quality 인자를 무시한다.
# ★[폴리시 R9] 판정을 `ItemCatalog.carries_quality`로 갈았다 — "CAT_HARVEST가 등급을 보존하는
#   유일한 카테고리"라던 옛 전제가 거짓이었다(주괴는 자재인데 price_of가 등급 배수를 얹는다).
# ★[폴리시 R10 #2 정정] R9가 함께 적어 둔 **"거동 불변"은 틀렸다.** 주괴는 어느 러브·라이크
#   목록에도 없다고 했으나, 같은 파일 OVERRIDES의 풀무 LOVE가 주괴 4종 전량을·네오 LOVE가
#   황천금 주괴를 담는다(오버라이드가 유니버설 NEUTRAL을 덮는다). 즉 그 조합에는 실제로 배율이
#   새로 얹혔다. **그 거동을 유지한다** — 이 함수가 선언한 규칙은 "품질을 *실제로 싣는* 물건에
#   러브·라이크 배율"이고, R9 이후 주괴는 그 집합에 정식으로 들어왔기 때문이다(되돌리려면 값을
#   매기는 집합과 배율을 얹는 집합을 다시 갈라 놓는 특례가 필요하다 — R9가 걷어낸 바로 그 갈림).
#   눈금 여파는 제련공(채광 lvl10) 퍼크가 주괴 등급을 +1단(은)까지만 올리므로 풀무·네오에게
#   러브 40 → 44 한 칸이고, 이 파일의 불변식(일반 러브 40 > 이리듐 라이크 37)은 그대로다.
#   ⚠️ 지급액 자체의 승인은 owner 몫으로 남긴다(관계 경제 눈금 — ADR-0066 결정 2 "포인트(잠정)").
static func points_for(tier: int, item_id: String = "", quality: int = ItemCatalog.Q_NORMAL) -> int:
	var base: int = int(POINTS.get(tier, POINTS[NEUTRAL]))
	if not (tier == LOVE or tier == LIKE):
		return base
	if not ItemCatalog.carries_quality(item_id):
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
