extends RefCounted
class_name ItemCatalog
# Phase 2.7 C1 — 아이템·도구 정적 카탈로그(ADR-0020 데이터 주도 아이템 / ADR-0024 마우스 조작).
#
# 목적: 인벤토리 슬롯에 담기는 "무엇"(도구·씨앗·수확물)을 한 곳에서 정의한다. CropCatalog가
#       "작물이 어떻게 자라나"(성장일수·단계)를 들듯, ItemCatalog는 "아이템이 무엇인가"
#       (표시명·카테고리·스택여부·가격)를 든다. 둘은 역할이 갈린다 — 씨앗·수확물 아이템은
#       CropCatalog의 작물군을 *참조*하고(이름·가격 파생), CropCatalog는 성장 데이터 전용으로
#       잔존한다(데이터 중복 0, 단일 출처).
#
# 설계 메모:
#   - crops.gd(CropCatalog)와 같은 결: 정적 참조 데이터다. 세이브 상태가 아니라 카탈로그라
#     씬 노드로 두지 않고 static 헬퍼 + class_name으로 어디서든 ItemCatalog.name_of("...")로 읽는다.
#   - 아이템 id 체계(코드·세이브용 영문 id, 안정적):
#       도구    : "hoe" / "watering_can" (유니크 — 슬롯에 1개, 스택 불가)
#       씨앗    : "<작물군>_seed" (예: "honryeongcho_seed") — 스택. crop_of로 작물군 역참조.
#       수확물  : "<작물군>"      (예: "honryeongcho")      — 스택. 작물 id = 수확물 아이템 id.
#     씨앗·수확물 엔트리는 CropCatalog에서 *파생*하므로(상수에 박지 않음) 작물이 늘면 자동 따라온다.
#   - 카테고리(ADR-0020): 도구/씨앗/수확물·산물/재료/소모품. 이 슬라이스(C1)는 앞 셋만 실제로
#     쓰고, 재료(MATERIAL)·소모품(CONSUMABLE)은 자리만 예약한다(Phase 3 가공·조리).
#   - quality(품질): S1-6(§8.3)에서 슬롯 {id,count}에 quality가 더해졌다(예약 실현, ADR-0020).
#     수확물·과일만 등급을 실고(Q_NORMAL..Q_IRIDIUM), 판매가는 price_of(id, quality)로 배수를 받는다.
#     도구·씨앗·묘목·비료는 품질 무차원(항상 Q_NORMAL).
#   - 아이콘은 뷰(main) 책임이다 — 씨앗·수확물은 CROP_SPRITES(작물 도트) 재사용, 도구는 임시
#     색박스(tool_color_of). 카탈로그는 텍스처를 들지 않아(데이터/표시 분리) 헤드리스에서도 가볍다.

# ── 카테고리(ADR-0020) ──────────────────────────────────────────────────────
const CAT_TOOL := "tool"           # 도구(괭이·물뿌리개) — 유니크, 비매(price 0)
const CAT_SEED := "seed"           # 씨앗 — 심으면 작물, 스택
const CAT_SAPLING := "sapling"     # 묘목 — 심으면 혼의 나무(과수), 스택(S1-5b)
const CAT_HARVEST := "harvest"     # 수확물·산물(작물 + 과일) — 팔거나 서빙·선물, 스택
const CAT_FERTILIZER := "fertilizer"  # 비료(품질·성장촉진) — 밭 칸에 뿌림, 스택(S1-6)
const CAT_MATERIAL := "material"   # 재료 — 자리 예약(Phase 3 가공)
const CAT_CONSUMABLE := "consumable"  # 소모품 — 자리 예약(Phase 3 조리)
const CAT_PLACEABLE := "placeable"  # 설치물(스프링클러 등) — 지면 칸에 설치·회수, 스택(S1R-T9)
const CAT_RELIC := "relic"         # ★[S2-T5] 유품 — 망자의 물건. 혼백관 기증 대상(안식 괭이질 발굴), 스택
# ★[S9-T7 / ADR-0034 · ADR-0067 결정 8] 책 — [옥자의 잃어버린 책들] 8 + [비밀 노트] 15.
#   유품과 **가르는 이유**: 유품은 판다(중복 발굴분 price>0)·건넨다(선물 가능)이지만, 책은
#   **비매(price 0)·선물 불가**(되찾은 옥자의 유품 키프세이크 — ADR-0034 #7)·**스택 불가**
#   (세상에 한 권씩)라 세 성질이 전부 다르다. 데이터는 Books가 단일 출처(MenuCatalog 위임 관례).
const CAT_BOOK := "book"           # 책·비밀 노트 — 인라인 즉독 + 혼백관 전시(책만) + 집 책장 재읽기

# ── 품질 등급(S1-6, §8.2) — 단일 진실원(orchard 나이·field 비료가 같은 enum·배수로 수렴) ──
# 수확물·과일 슬롯에 실리는 등급. 도구·씨앗·묘목·비료는 항상 Q_NORMAL(품질 무차원).
const Q_NORMAL := 0    # 일반
const Q_SILVER := 1    # 은
const Q_GOLD := 2      # 금
const Q_IRIDIUM := 3   # 이리듐
const QUALITY_MULT := [1.0, 1.25, 1.5, 2.0]     # §3.1 판매가 배수(등급 인덱스)
const QUALITY_NAMES := ["일반", "은", "금", "이리듐"]

# 등급 → 판매가 배수(clamp 0..3 방어). shipping_bin·price_of가 raw 판매가에 곱한다.
static func quality_mult(q: int) -> float:
	return QUALITY_MULT[clampi(q, 0, 3)]

# 등급 → 표시명("일반/은/금/이리듐"). HUD 품질 배지·툴팁이 쓴다.
static func quality_name(q: int) -> String:
	return QUALITY_NAMES[clampi(q, 0, 3)]

# ── 비료 아이템 id(S1-6, §8.4) — 데이터는 FertilizerCatalog, 여기는 id 진실원(도구 결) ──
const FERT_BASIC := "fert_basic"       # 기초 비료(품질군 → BASIC)
const FERT_QUALITY := "fert_quality"   # 품질 비료(품질군 → QUALITY)
const FERT_DELUXE := "fert_deluxe"     # 디럭스 비료(품질군 → DELUXE)
const FERT_SPEED := "fert_speed"       # 성장촉진 비료(성장촉진군 −25%)
const FERT_HYPER := "fert_hyper"       # 하이퍼 비료(성장촉진군 −33%)

# ── 도구 id ─────────────────────────────────────────────────────────────────
const HOE := "hoe"                 # 괭이 — 미경작 칸을 경작(LMB)
const WATERING_CAN := "watering_can"  # 물뿌리개 — 심은 칸에 물주기(LMB)
# ★ S1-8 개간 도구 3종(§10.2) — overgrown debris를 맞는 도구로 치운다(든 도구=동사, ADR-0024).
const SCYTHE := "scythe"           # 낫 — 이승의 미련(잡초) 제거
const PICKAXE := "pickaxe"         # 곡괭이 — 업화석(돌) 제거
const AXE := "axe"                 # 도끼 — 석화 고목(그루터기) 제거
# ★[S3-T4 / ADR-0061 결정 4] 낚시 기어 10종 — 낚싯대 4티어 + 미끼 3 + 태클 3.
#   데이터(이름·가격·줄 강도·슬롯·효과)는 **GearCatalog가 단일 출처**로 들고, 여기는 id 진실원 +
#   판정/표시 위임만 한다(FertilizerCatalog·FishCatalog 위임 관례 동형 — 데이터 중복 0).
#   분류: 낚싯대·태클 = CAT_TOOL(유니크 장착물) · 미끼 = CAT_CONSUMABLE(스택 소모품 — 예약 자리 실사용 개시).
#   ★ 획득 경로(매대 판매·T1 증정)는 S3-T5 소관 — 지금은 디버그 지급(삼도천 진입 T1 자동 지급)뿐이다.
const ROD_T1 := GearCatalog.ROD_T1   # 낡은 낚싯대(T1 — 소 체급·슬롯 0)
const ROD_T2 := GearCatalog.ROD_T2   # 삼줄 낚싯대(T2 — 중 체급·미끼 슬롯)
const ROD_T3 := GearCatalog.ROD_T3   # 놋쇠 낚싯대(T3 — 대 체급·태클 1)
const ROD_T4 := GearCatalog.ROD_T4   # 만장 낚싯대(T4 — 전설 체급·태클 2)
const BAIT_BASIC := GearCatalog.BAIT_BASIC        # 일반 미끼(입질 대기 −40%)
const BAIT_LURE := GearCatalog.BAIT_LURE          # 유인 미끼(체급 가중 한 계단 위로)
const BAIT_PLEDGE := GearCatalog.BAIT_PLEDGE      # 보장 미끼(가용 최고 체급 확정)
const TACKLE_CORK := GearCatalog.TACKLE_CORK      # 코르크 보버(텐션 안전 여유)
const TACKLE_SINKER := GearCatalog.TACKLE_SINKER  # 납추(발버둥 완화)
const TACKLE_QUALITY := GearCatalog.TACKLE_QUALITY  # 퀄리티 보버(품질 보정)
# ★[S5-T4 / ADR-0063 결정 5] 무기 5종(검 단일 계열) — 낚시 기어와 **정확히 같은 위임 문법**이다.
#   데이터(이름·데미지 밴드·해금 깊이·가격·색)는 **WeaponCatalog가 단일 출처**이고 여기는 id 진실원 +
#   판정/표시 위임만 한다. 분류 = CAT_TOOL(유니크 장착물 — 낚싯대와 같은 칸. 장착 전환 = 핫바에서
#   드는 것이 곧 그 동사라는 ADR-0024 관례를 그대로 쓰므로 새 카테고리가 필요 없다).
#   ★ 획득 경로(길드 매대·첫 방문 증정)는 S5-T6 소관 — 지금은 디버그 지급뿐이다.
const SWORD_RUSTY := WeaponCatalog.SWORD_RUSTY                    # 녹슨 혼검(증정 · 2-5)
const SWORD_MYEONGDONG := WeaponCatalog.SWORD_MYEONGDONG          # 명동검(깊이 10 · 8-15)
const SWORD_YUCHEOL := WeaponCatalog.SWORD_YUCHEOL                # 유철검(깊이 25 · 12-25)
const SWORD_HWANGCHEONGEUM := WeaponCatalog.SWORD_HWANGCHEONGEUM  # 황천금검(깊이 40 · 28-46)
const SWORD_EOPHWADO := WeaponCatalog.SWORD_EOPHWADO              # 업화도(깊이 60 · 55-64)

# ── 목축(S1-7) — 건초·대형 산물(§8.6) ────────────────────────────────────────
# 건초(feed): 짐승 급여 재료(1마리/일 1개, §4.1). 품질 무차원 스택 아이템(CAT_MATERIAL 실사용 개시).
const HAY := "hay"
const HAY_COST := 10               # 건초 기준가 — ★[S2-T4] 만물상 매대 입고 완료(수풀 베기 입수는 하류)

# ── 개간(S1-8) — debris 드랍 재료(§10.2) ──────────────────────────────────────
# 개간으로 나오는 재료 3종. 품질 무차원 스택·CAT_MATERIAL(HAY 결 — Phase 3 가공 예약). name/가격은 아래 표에서.
const SOUL_FIBER := "soul_fiber"        # 혼백 섬유 — 이승의 미련(잡초·낫) 드랍
const EMBER_SHARD := "ember_shard"      # 업화석 조각 — 업화석(돌·곡괭이) 드랍
const PETRIFIED_WOOD := "petrified_wood"  # 석화 목재 — 석화 고목(그루터기·도끼) 드랍
const RARECROW_1 := "rarecrow_1"        # ★[S2-T5] 레어크로우 ① — 혼백관 마일스톤 보상([ADR-0051] B 수집 트랙 최초 획득처)
# ★[S7-T7 / ADR-0065 결정 9] 레어크로우 ② — **저승 야시장 한정 물품**(성야 15일, 1회 한정).
#   ①과 같은 결의 수집물이라 같은 규칙을 그대로 탄다(품질 무차원·비매 price 0). 획득처가 갈리는
#   것이 요점이다: ①은 혼백관 기증 이력(수집 활동)에서, ②는 절기 행사 매대(달력)에서 나온다 —
#   ADR-0051 B 트랙(8종 수집 → 디럭스 허수아비)의 두 번째 입구다. **배치 메카닉은 여전히 서랍**
#   (①이 그러하듯 지금은 소지까지가 실효 범위 — 신규 시스템 0).
const RARECROW_2 := "rarecrow_2"        # 레어크로우 ② — 저승 야시장 한정
# ★[S3-T6 / ADR-0061 결정 6] 삭은 그물 — 낚시 인양물 잡동사니(SalvageTable). 개간 드랍은 아니지만
#   같은 결의 품질 무차원 재료라 여기 합류한다(카테고리 신설 0). ★S3-T7 게잡이통 잡동사니 표적으로도
#   재사용된다(뱃사람 퍼크 = "게잡이통에 잡동사니 안 걸림"의 그 잡동사니 — 신규 아이템 남발 0).
const ROTTEN_NET := "rotten_net"
# ── ★[S4-T3 / ADR-0062 결정 3] 벌목 산출 6종 — 원목·단단한 원목·수액 + 나무 씨앗 3 ──────────
# **원목(WOOD)은 이 게임의 기축 자재**다(제작·건축의 통화 — 결정 4 수액 채취기 40개, 결정 7 목공방
# 건축 지불). 개간 드랍(석화 목재)과 **역할이 갈린다**: 석화 고목은 1회성 debris이고 살아있는 나무는
# 재성장하는 자원이라, PETRIFIED_WOOD를 재사용하지 않고 별 아이템으로 둔다(ADR-0062 "역할 분리").
# 전부 품질 무차원 스택 CAT_MATERIAL(건초·개간 드랍 결 — 벌목은 품질 축이 없다. 품질은 *줍기*의 축이다).
# ★ 가격 밴드(잠정 — owner 큐): 스타듀 wood 2 / hardwood 15 / sap 2의 비율(1 : 7.5 : 1)을 엽전
#   스케일(개간 드랍 4~15)에 얹었다. 씨앗 3종은 심기(파종)가 아직 없어 판매만 되는 상태다(S4 후속).
const WOOD := "wood"                    # 원목 — 범용 자재(기축 통화)
const HARDWOOD := "hardwood"            # 단단한 원목 — 벌목꾼(DIM_HARDWOOD) 퍼크·심층 그루터기 산출
const SAP := "sap"                      # 수액 — 벌목 부산물(채취기 정기 수확은 S4-T6)
const SEED_JEOSEUNGSOL := "seed_jeoseungsol"      # 저승솔 방울(잠정 명명 — ADR-0062 결정 3)
const SEED_MYEONGDANPUNG := "seed_myeongdanpung"  # 명단풍 씨
const SEED_NEOKCHAM := "seed_neokcham"            # 넋참나무 도토리
# ── ★[S4-T8 / ADR-0062 결정 9 ㉡] 저승 이끼 — 성숙 나무에서 낫 1회 채취 ────────────
# §1-C 기결정("저비용 상시 자원")의 이행. **품질 무차원 CAT_MATERIAL**로 두는 이유는 원목·수액과
# 정확히 같다: 품질은 *줍기*의 축(채집 레벨 → 등급)이지 자재의 축이 아니다(ADR-0052 §채집).
# 가격 8(잠정 — owner 큐): 원목 5 ~ 석화 목재 15 사이 저가 밴드. 나무마다 며칠에 한 번씩 끼는
# 상시 자원이라 개당 값이 크면 벌목·수액의 경제적 이유가 흐려진다.
const JEOSEUNG_IKKI := "jeoseung_ikki"            # 저승 이끼 — 성숙목 낫 채취(TreeLedger.has_moss)
# ── ★[S5-T5 / ADR-0063 결정 8] 잡귀 부산물 2종 — 갱도 잡귀 처치 드랍 ────────────────
# "잡귀를 잡으면 무엇이 남는가"의 자리. **품질 무차원 스택 CAT_MATERIAL**(원목·수액·이끼·광물과
# 같은 판단 — 품질은 줍기·릴 격투의 축이지 자재의 축이 아니다). id 상수의 진실원은 여기이고
# MobCatalog.DROP_*가 같은 문자열을 리터럴로 든다(const 초기화식 관례 — mob_test가 두 쪽을 대조).
# ★ 하류 소비처(카페 메뉴·제작 레시피)는 S6 소관이다 — 지금은 소지·판매까지가 실효 범위다
#   (벌목 씨앗 3종이 "팔리기만 하는 상태"로 S4를 넘긴 선례 동형).
# ★ 가격(*잠정* — owner 큐): 넋가루 14 · 혼불씨 26. 근거 = 스타듀 Slime 5 / Bat Wing 15 / Bone
#   Fragment 상당의 비율을 엽전 스케일(개간 드랍 4~15 · 이끼 8 · 혼탄 15)에 얹었다. 잡귀 한 마리가
#   광맥 한 칸(명동 5 × 1~3)보다 값이 나가면 "채굴 대신 사냥"이 최적이 되어 이중 시계가 무너진다 —
#   그래서 드랍률(55~80%)을 함께 계산해 기대값이 광맥 한 칸 근처에 앉게 잡았다.
const NEOKGARU := "neokgaru"                      # 넋가루 — 흩어진 잡귀가 남기는 회백색 가루(범용)
const HONBULSSI := "honbulssi"                    # 혼불씨 — 잡귀 속에 남은 불씨(심층 종 산출)
# ★[S5-T7 / ADR-0063 결정 7] 관문 보스 확정 드랍 — 카페 프리미엄 소재. *명명 잠정*(owner 큐):
#   「나락혼정(奈落魂精)」 = 혼탄·혼불씨의 혼(魂) 계열 위에 얹은 최상위 등급(불씨 → 정수).
#   ★ **소비처는 S6**(카페 가공)이라 지금 실효 범위는 소지·판매까지다 — 벌목 씨앗 3종이 "팔리기만
#     하는 상태"로 S4를 넘긴 선례 동형. 값 480은 보스 한 기의 시간 대가(수십 층 하강 + 500~1200 HP)를
#     혼불씨 26의 십수 배로 잡은 *잠정치*이고, 지금은 판매 외 쓰임이 없어 되돌리기가 상수 수준이다.
const NARAK_HONJEONG := "narak_honjeong"          # 나락혼정 — 관문 보스 확정 드랍(카페 프리미엄 소재)
const MATERIALS := {                    # 재료 id → {name_ko, price}(HAY는 별 상수라 여기 제외)
	SOUL_FIBER: {"name_ko": "혼백 섬유", "price": 4},
	EMBER_SHARD: {"name_ko": "업화석 조각", "price": 12},
	PETRIFIED_WOOD: {"name_ko": "석화 목재", "price": 15},
	ROTTEN_NET: {"name_ko": "삭은 그물", "price": 5},   # ★S3-T6 인양 잡동사니(팔면 푼돈)
	RARECROW_1: {"name_ko": "레어크로우 ① — 갓 쓴 허수아비", "price": 0},   # 비매품(수집물 — 배치·8종 디럭스는 후속 ADR-0051 B)
	RARECROW_2: {"name_ko": "레어크로우 ② — 등롱 든 허수아비", "price": 0},  # ★S7-T7 야시장 한정(①과 같은 비매 수집물)
	# ★[S4-T3] 벌목 산출 6종
	WOOD: {"name_ko": "원목", "price": 5},
	HARDWOOD: {"name_ko": "단단한 원목", "price": 35},
	SAP: {"name_ko": "수액", "price": 3},
	SEED_JEOSEUNGSOL: {"name_ko": "저승솔 방울", "price": 12},
	SEED_MYEONGDANPUNG: {"name_ko": "명단풍 씨", "price": 12},
	SEED_NEOKCHAM: {"name_ko": "넋참나무 도토리", "price": 12},
	# ★[S4-T8] 저승 이끼(낫 채취 상시 자원)
	JEOSEUNG_IKKI: {"name_ko": "저승 이끼", "price": 8},
	# ★[S5-T5] 잡귀 부산물 2종(갱도 잡귀 처치 드랍)
	NEOKGARU: {"name_ko": "넋가루", "price": 14},
	HONBULSSI: {"name_ko": "혼불씨", "price": 26},
	# ★[S5-T7] 관문 보스 드랍(나락 — 카페 프리미엄 소재. 소비처 S6)
	NARAK_HONJEONG: {"name_ko": "나락혼정", "price": 480},
}

# ── ★[S5-T2 / ADR-0063 결정 2] 광물 로스터 — 금속 4티어·혼탄·돌·보석 4+1·지오드 2 ────
# 갱도 광맥(MineFloors 노드)을 곡괭이로 부숴 얻는 자재군. **전부 품질 무차원 CAT_MATERIAL**이다
# — 품질은 *줍기*(채집 레벨)와 *릴 격투*(퍼펙트)의 축이지 광맥의 축이 아니다(원목·수액과 같은
# 판단). ADR-0052 보석사 퍼크가 말하는 "보석 등급"은 판매가가 아니라 **별 축**이라 S5-T8 인코딩
# 시점에 재론한다(지금 품질 등급을 실으면 그 결정이 미리 굳어 버린다).
# ★ 왜 MATERIALS에 합치지 않고 별 dict인가: 이 로스터는 **제련(S5-T3)·지오드 개봉·전문직 퍼크가
#   종별로 순회할 데이터**다(광석 → 주괴 매핑, 보석 등급, 알돌 개봉 표). 개간 드랍·벌목 산출이
#   섞인 MATERIALS 안에 두면 "무엇이 광물인가"를 매번 하드코딩 목록으로 다시 세워야 한다
#   (POT_GOODS·SAP_GOODS를 FORAGEABLES에서 가른 것과 같은 판단).
# ★ 가격 밴드(*전부 잠정* — owner 큐): 스타듀 copper 5 / iron 10 / gold 25 / iridium 100 · coal 15 ·
#   stone 2 · quartz~diamond · geode 50/150을 엽전 스케일에 1:1로 얹었다(광물은 제련 사슬의 입력이라
#   원가 비율이 흔들리면 주괴·도구 업그레이드 곡선이 통째로 흔들린다 — 스타듀 비율 보존이 안전).
# ★ 명명 전부 잠정(ADR-0063 결정 2가 "상위 2티어·보석·지오드 명명 전부 잠정"으로 owner 큐 적재).
const ORE_MYEONGDONG := "ore_myeongdong"            # 명동(冥銅) 광석 — 구리 대응(전층)
const ORE_YUCHEOL := "ore_yucheol"                  # 유철(幽鐵) 광석 — 철 대응(21층+)
const ORE_HWANGCHEONGEUM := "ore_hwangcheongeum"    # 황천금(黃泉金) 광석 — 금 대응(41층+)
# ★ 나락철은 **아이템 등록만**이다 — 갱도 미출현·나락 전용 깊이 비례 산출(ADR-0063 결정 2·7).
#   노드 테이블(MineFloors.NODE_TABLE)에 없고, 출현·드랍 배선은 S5-T7 나락 소관이다.
const ORE_NARAKCHEOL := "ore_narakcheol"            # 나락철(奈落鐵) 광석 — 이리듐 대응(나락 전용)
const HONTAN := "hontan"                            # 혼탄(魂炭) — 석탄 대응(제련 연료)
const STONE := "stone"                              # 돌 — 범용 자재(계단·업화로 재료)
# 보석 4 + 초희귀 1(ADR-0063 결정 2 "보석 4+1").
const GEM_NEOKSUJEONG := "gem_neoksujeong"          # 넋수정 — 석영 결(전층)
const GEM_MYEONGOK := "gem_myeongok"                # 명옥(冥玉) — 21층+
const GEM_YEOMJUSEOK := "gem_yeomjuseok"            # 염주석 — 41층+
const GEM_MYEONGBU_GEUMGANG := "gem_myeongbu_geumgang"  # 명부금강 — 다이아 대응(31층+ 희귀 노드)
# ★ 오색혼옥도 **등록만**이다 — 프리즈마틱 대응 초희귀 드랍이라 일반 노드 스캐터에 안 들어간다
#   (소비처·획득 경로는 후속 — 혼백관 전시 후보, ADR-0063 결정 2).
const GEM_OSAEK_HONOK := "gem_osaek_honok"          # 오색혼옥 — 프리즈마틱 대응(초희귀)
# 지오드 2종 — 개봉(대장간 서비스 개당 25냥)은 S5-T3 소관. 지금은 드랍·소지·판매만 산다.
const GEODE_NEOKAL := "geode_neokal"                # 넋알돌(1~40층)
const GEODE_EOPHWA := "geode_eophwa"                # 업화알돌(41층+·나락)
const MINERALS := {                      # 광물 id → {name_ko, price(품질 무차원 고정가)}
	ORE_MYEONGDONG: {"name_ko": "명동 광석", "price": 5},
	ORE_YUCHEOL: {"name_ko": "유철 광석", "price": 10},
	ORE_HWANGCHEONGEUM: {"name_ko": "황천금 광석", "price": 25},
	ORE_NARAKCHEOL: {"name_ko": "나락철 광석", "price": 100},
	HONTAN: {"name_ko": "혼탄", "price": 15},
	STONE: {"name_ko": "돌", "price": 2},
	GEM_NEOKSUJEONG: {"name_ko": "넋수정", "price": 100},
	GEM_MYEONGOK: {"name_ko": "명옥", "price": 200},
	GEM_YEOMJUSEOK: {"name_ko": "염주석", "price": 250},
	GEM_MYEONGBU_GEUMGANG: {"name_ko": "명부금강", "price": 750},
	GEM_OSAEK_HONOK: {"name_ko": "오색혼옥", "price": 2000},
	GEODE_NEOKAL: {"name_ko": "넋알돌", "price": 50},
	GEODE_EOPHWA: {"name_ko": "업화알돌", "price": 150},
}

# ── ★[S5-T3 / ADR-0063 결정 3] 주괴 4종 — 업화로 제련 산출 ─────────────────────
# 광석 5 + 혼탄 1을 업화로에 넣고 기다리면 나오는 금속 덩이. 도구 업그레이드(ToolTier)의 재료이자
# 이 게임의 첫 **가공품**이다(투입 → 시간 경과 → 산출 — 손 제작 CraftCatalog와 다른 축).
#
# ★ **품질 유차원 CAT_MATERIAL 예외**(ADR-0063 결정 2 마지막 항이 명시적으로 기록한 그 예외다):
#   자재는 원칙적으로 품질 무차원이다(원목·수액·이끼·광물 — "품질은 줍기의 축"). 주괴만 등급을
#   싣는 근거는 [ADR-0052] 확정 로스터의 **제련공 퍼크 "잉곳 품질 티어"** 하나뿐이다 — 그 퍼크가
#   실효할 자리가 아이템에 없으면 S5-T8이 배선할 곳 자체가 사라진다. 그래서 MINERALS(품질 무차원
#   고정가)와 **별 dict로 가른다**(같은 dict에 넣으면 price_of의 등급 분기가 광물까지 물든다).
# ★ 가격 = 스타듀 copper bar 60 / iron 120 / gold 250 / iridium 1000을 엽전 스케일에 1:1로 얹었다.
#   광석(5/10/25/100)의 12배·12배·10배·10배라 "5개 녹여 1개"의 손실이 없다(제련 = 순수 상승 가공).
# ★ 나락철 주괴도 **등록만**이 아니다 — 도구 4티어(ToolTier)의 최종 재료라 소지·제련·소모가 전부
#   지금 산다. 다만 나락철 광석의 *출현*은 S5-T7(나락) 소관이다(광석 등록만 돼 있는 상태 계승).
const INGOT_MYEONGDONG := "ingot_myeongdong"            # 명동 주괴 — 구리 주괴 대응
const INGOT_YUCHEOL := "ingot_yucheol"                  # 유철 주괴 — 철 주괴 대응
const INGOT_HWANGCHEONGEUM := "ingot_hwangcheongeum"    # 황천금 주괴 — 금 주괴 대응
const INGOT_NARAKCHEOL := "ingot_narakcheol"            # 나락철 주괴 — 이리듐 주괴 대응
const INGOTS := {                        # 주괴 id → {name_ko, price(기준가 — 등급 배수가 얹힌다)}
	INGOT_MYEONGDONG: {"name_ko": "명동 주괴", "price": 60},
	INGOT_YUCHEOL: {"name_ko": "유철 주괴", "price": 120},
	INGOT_HWANGCHEONGEUM: {"name_ko": "황천금 주괴", "price": 250},
	INGOT_NARAKCHEOL: {"name_ko": "나락철 주괴", "price": 1000},
}

# ── ★[S5-T6 / ADR-0063 결정 6] 회복 소모품 — 명부환(冥府丸) ────────────────────
# 길드(무골) 상시 품목. **HP를 즉시 회복하는 유일한 물건**이다 — 취침 풀회복 말고는 회복원이 없어
# (ADR-0063 결정 4) S6 요리가 붙기 전까지 갱도 런의 유일한 연장 수단이다. 스타듀 길드는 회복템을
# 안 팔지만 결정 6이 명시적으로 이 예외를 뒀다.
#
# ★ 카테고리 = **CAT_CONSUMABLE**(미끼가 먼저 쓰던 그 칸). 근거: 미끼와 같이 "들고 쓰면 사라지는
#   스택 물건"이고, 핫바·인벤·아이콘 경로가 이미 그 카테고리를 통째로 처리한다(신규 분기 0).
# ★ 혼력(에너지)이 아니라 **체력(HP)**을 채운다 — 두 자원은 완전 별개다(ADR-0011). 혼력 회복
#   소모품은 여기 없다(음식 = S6 요리 소관).
# ★ 값·회복량 전부 *잠정*(owner 큐 — ADR-0063 결정 6 원문 "150냥·HP+40").
const MYEONGBUHWAN := "myeongbuhwan"        # 명부환 — HP 회복 환약(길드 판매)
const MYEONGBUHWAN_HEAL := 40               # 1회 회복량(HP) — 회복 수치의 **단일 출처**
const POTIONS := {                          # 소모품 id → {name_ko, price(고정 매입가), heal(HP), color}
	MYEONGBUHWAN: {
		"name_ko": "명부환", "price": 150, "heal": MYEONGBUHWAN_HEAL,
		"color": Color(0.72, 0.24, 0.30),   # 검붉은 환약(아이콘 아트 = S5-T10 — 색박스 폴백이 읽는다)
	},
}

# ── ★[S5-T8 / ADR-0063 결정 10] 계단 — 층을 건너뛰는 1회용 소모품 ──────────────
# 돌 99개로 만드는 스타듀 Staircase 1:1. 든 채 LMB로 놓으면 그 자리에서 한 층 아래로 내려간다
# (사다리를 찾지 않는다) — **나락에서도 쓴다**(해골동굴 1:1. 결정 7의 리셋 런에서 계단은 사실상
# 유일한 가속 수단이라, 갱도 전용으로 막으면 나락의 깊이 곡선이 통째로 손 채굴에 인질이 된다).
#
# ★ 카테고리 = CAT_CONSUMABLE(미끼·명부환이 쓰는 그 칸 — "들고 쓰면 사라지는 스택 물건"). 설치물
#   (CAT_PLACEABLE)이 아닌 이유는 **원장에 남지 않기 때문**이다: 놓는 순간 층이 갈려 그 무대가
#   사라진다(스프링클러·게잡이통처럼 회수할 대상이 없다).
# ★ price 0 = **비매**(나락 열쇠와 같은 표현). 돌 99개(198냥 상당)를 굳혀 만드는 물건이라 값을
#   매기면 재료 차익 판정이 하나 더 생기고, 스타듀도 계단은 팔 수 없다. *잠정(owner 큐)*.
const STAIRS := "stairs"                    # 계단 — 층 스킵 1회용(채광 Lv2 제작 해금)
const UTILITIES := {                        # 소모 장치 id → {name_ko, color}(비매·스택)
	STAIRS: {
		"name_ko": "계단",
		"color": Color(0.62, 0.60, 0.58),   # 잿빛 석재(아이콘 아트 = S5-T10 — 색박스 폴백이 읽는다)
	},
}

# ── ★[S5-T6 / ADR-0063 결정 7·10] 열쇠 — 나락 열쇠 ────────────────────────────
# 갱도 60층 보상 상자에서 나오는 단 하나의 물건(Skull Key 1:1). 지상 `NARAK_GATE`(나락 진입로)의
# 게이트 키다 — **점등 배선 자체는 S5-T7 소관**이고, 여기는 아이템 등록까지만 한다(결정 7의
# "채광 깊이 = 유일 게이트"가 실물로 존재해야 T7이 그걸 볼 수 있다).
#
# ★ 왜 유품(RELICS)이 아닌가: 유품은 **혼백관 기증 대상**이라 그 dict에 넣는 순간 열쇠가 기증
#   목록에 뜨고 기증하면 사라진다(진행 봉쇄 = 치명). 그래서 별 dict로 가른다.
# ★ 카테고리 = CAT_MATERIAL(자재 칸)이되 **스택 불가**다 — 세상에 한 자루뿐인 물건이라 개수가
#   의미 없고, 스택 뱃지 "×1"이 붙는 게 오히려 이상하다(도구·무기와 같은 유니크 취급).
# ★ price 0 = **비매**(팔 수 없고 살 수도 없다 — 유일 입수 경로는 60층 상자다).
const NARAK_KEY := "narak_key"              # 나락 열쇠 — 60층 보상 상자 산출(나락 진입로 해금 키)
# ★[S8-T7 / ADR-0066 결정 8] 혼례 부적 — 결혼의 정표(스타듀 인어 펜던트 동가 5,000냥 잠정).
#   옥자 의뢰로만 입수(연애 상태 노출 — main의 옥자 [F] 훅)하고, 연인에게 [G]로 건네는 것이
#   청혼이다(선물 경로 인터셉트 — GiftPrefs.giftable의 KEYS 배제가 일반 선물 오발을 막는다).
#   KEYS인 이유 = 나락 열쇠와 같은 결(비매·유니크·스택 불가·기증 불가)이라 새 dict가 필요 없다.
const WEDDING_CHARM := "wedding_charm"      # 혼례 부적 — 소울-바인딩 정표(청혼 = 연인에게 건넴)
const KEYS := {                             # 열쇠 id → {name_ko}(비매·유니크·스택 불가)
	NARAK_KEY: {"name_ko": "나락 열쇠"},
	WEDDING_CHARM: {"name_ko": "혼례 부적"},
}

# ── ★[S6-T1 / ADR-0064 결정 2·9] 카페 메뉴 — 기본 4 + 융합 12 ────────────────
# 데이터(이름·시그니처 재료·가격·색)는 **MenuCatalog가 단일 출처**이고 여기는 판정/표시 위임만
# 한다(GearCatalog·WeaponCatalog·FishCatalog 위임 관례 동형 — 데이터 중복 0). id 상수도 안 박는다:
# 메뉴 id를 코드에서 부르는 쪽은 카페·곳간이고 그쪽은 MenuCatalog를 직접 보는 게 정배다.
#
# ★ 카테고리 = **CAT_CONSUMABLE**(미끼·명부환·계단이 쓰는 그 칸 — 결정 9). 신규 카테고리 0.
# ★ **품질 무차원**이다(메뉴는 품질 무영향 — catalog §1-B). 그래서 price_of가 등급 배수를 안 얹는다.
# ★ 가격은 MenuCatalog가 시그니처 기본가 ×2.5로 파생한다(잠정 — owner 큐).
# ★ 지금 실효 범위: 카탈로그 등록 + 곳간·메뉴 UI 열거까지다. **주문 롤·융합 매출·혼력 회복은
#   T2 이후 소관**이라 아직 인벤토리에 실제로 들어오는 경로가 없다(광석·씨앗이 "등록만" 된 채
#   슬라이스를 넘긴 선례 동형).

# ── ★[S2-T5 / ADR-0060 결정 5] 유품(relic) — 혼백관 기증 수집물 ─────────────────────
# 망자가 이승에 남긴 물건. 안식 괭이질 저확률 발굴(Museum.relic_roll — 스타듀 Artifact 대응)로 얻고
# 혼백관에 기증한다(종당 1회 — 중복 발굴분은 판매 가능). 서사(누구의 유품인가)는 Slice 9 소관(봉인 법칙).
const RELIC_BINYEO := "relic_binyeo"      # 은비녀 유품
const RELIC_SPOON := "relic_spoon"        # 놋숟가락 유품
const RELIC_KKOTSIN := "relic_kkotsin"    # 꽃신 유품
const RELICS := {                          # 유품 id → {name_ko, price}(중복 발굴분 판매가)
	RELIC_BINYEO: {"name_ko": "은비녀 유품", "price": 30},
	RELIC_SPOON: {"name_ko": "놋숟가락 유품", "price": 20},
	RELIC_KKOTSIN: {"name_ko": "꽃신 유품", "price": 25},
}

# ── 채집물(ADR-0052 §118 · ADR-0033) — 안식 꽃 패치 손수확 산출(품질 실림) ──────────────
# 야생 채집물. 작물·과일·산물처럼 품질 등급(Q_NORMAL..Q_IRIDIUM)을 싣고 판매가에 배수를 받는
# CAT_HARVEST 아이템(선물·서빙·정렬 동일 취급). 다만 소스는 밭(비료 roll)이 아니라 채집 레벨/전문직
# (main._forage_base_quality + 약초학자 하한 = ADR-0052). 재료(HAY·개간)와 달리 품질 유차원이라
# MATERIALS와 분리한다. 지금은 피안화 1종(파일럿) — 종 확장은 숲 채집 슬라이스에서(ADR-0033 무대).
const SPIRIT_FLOWER := "spirit_flower"  # 피안화(彼岸花) — 안식 꽃 패치 채집물
# ── ★[S4-T1 / ADR-0062 결정 2] 숲·해변 채집물 로스터 22종 — 정식 편입 ──────────────
# 피안화(안식 파일럿) 옆에 **저승 숲 12 + 미혹 희소 4 + 미혹 심층 2 + 황천해 해변 4**를 얹는다.
# 전부 같은 결의 품질 유차원 CAT_HARVEST라 판매·서빙·선물·정렬·출하·의뢰 보상이 기존 경로로
# 자동 통용된다(신규 분기 0 — 어획물·통용물 편입과 같은 판단).
# ★ 여기는 **id·이름·가격의 단일 출처**이고, "언제·어디서 돋나"(절기·존 매핑)는 ForageSpawns가
#   든다(FishCatalog 위임 관례의 역방향 — 로스터 스키마가 얇아 이름·가격은 여기 사는 게 맞다).
# ★ 명명 = CONTEXT 저승 결(넋/혼/잿빛/저승/안개/서리/미혹 수식어 합성 — 어종 로스터 PR#279 선례).
#   **불사과만 CONTEXT 기정의 명칭 그대로**이고, 그 종은 `CropCatalog.BULSAGWA`로 **이미 존재해 재사용**
#   한다(신규 등록 21 + 재사용 1 = 로스터 22).
# ★ 가격 밴드(잠정 — owner 큐): 일반 30~90 · 희소 130~250 · 불사과 600(500+) · 해변 22~55 엽전.
#
#   ┌ 로스터 표(절기 · 구역/존 · 기준가) ────────────────────────────────────────┐
#   │ 넋고사리        피안절  저승 숲 빈터    35 │ 저승산딸기      유화절 저승 숲 35 │
#   │ 잿빛냉이        피안절  저승 숲 빈터    30 │ 혼잎박하        유화절 저승 숲 45 │
#   │ 저승달래        피안절  저승 숲 빈터    45 │ 잿빛더덕        유화절 저승 숲 70 │
#   │ 잿빛도토리      망연절  저승 숲 빈터    30 │ 언혼뿌리        성야절 저승 숲 50 │
#   │ 안개도라지      망연절  저승 숲 빈터    55 │ 서리동백        성야절 저승 숲 80 │
#   │ 넋송이버섯      망연절  저승 숲 빈터    90 │ 성야솔방울      성야절 저승 숲 40 │
#   │ 미혹난초        피안절  미혹 빈터      130 │ 유령초          유화절 미혹    170 │
#   │ 명월버섯        망연절  미혹 빈터      210 │ 서리혼백초      성야절 미혹    250 │
#   │ 불사과★재사용   무관    미혹 심층      600 │ 저승삼          무관   미혹 심층 420 │
#   │ 황천산호        무관    황천해 해변     55 │ 넋성게          무관   황천해     45 │
#   │ 유리고둥        무관    황천해 해변     35 │ 물비늘조개      무관   황천해     22 │
#   └──────────────────────────────────────────────────────────────────────────┘
#   ⚠️ 해변 4종은 **아이템 등록만** — 백사장 스폰 존 배선은 S4-T8 소관이다(무대 재사용).
# 저승 숲 일반 12(절기당 3)
const NEOK_GOSARI := "neok_gosari"              # 넋고사리(피안절)
const JAETBIT_NAENGI := "jaetbit_naengi"        # 잿빛냉이(피안절)
const JEOSEUNG_DALLAE := "jeoseung_dallae"      # 저승달래(피안절)
const JEOSEUNG_SANDALGI := "jeoseung_sandalgi"  # 저승산딸기(유화절)
const HONIP_BAKHA := "honip_bakha"              # 혼잎박하(유화절)
const JAETBIT_DEODEOK := "jaetbit_deodeok"      # 잿빛더덕(유화절)
const JAETBIT_DOTORI := "jaetbit_dotori"        # 잿빛도토리(망연절)
const ANGAE_DORAJI := "angae_doraji"            # 안개도라지(망연절)
const NEOK_SONGI := "neok_songi"                # 넋송이버섯(망연절)
const EONHON_PPURI := "eonhon_ppuri"            # 언혼뿌리(성야절)
const SEORI_DONGBAEK := "seori_dongbaek"        # 서리동백(성야절)
const SEONGYA_SOLBANGUL := "seongya_solbangul"  # 성야솔방울(성야절)
# 미혹 희소 4(절기당 1)
const MIHOK_NANCHO := "mihok_nancho"            # 미혹난초(피안절)
const YURYEONGCHO := "yuryeongcho"              # 유령초(유화절)
const MYEONGWOL_BEOSEOT := "myeongwol_beoseot"  # 명월버섯(망연절)
const SEORI_HONBAEKCHO := "seori_honbaekcho"    # 서리혼백초(성야절)
# 미혹 심층 2(절기 무관 — 도끼 티어 게이트는 S4-T4/T5)
# ★ 불사과는 **여기 신규 등록하지 않는다** — `CropCatalog.BULSAGWA`("bulsagwa")로 S1-4에 이미 존재하고
#   (crops.gd 주석 "다절기 프레스티지(미혹의 숲 채집)"), 수확물 아이템 id = 작물 id라 그 자체가 이미
#   유효한 CAT_HARVEST 아이템이다. 같은 id를 FORAGEABLES에 또 박으면 name/price 조회가 CropCatalog에
#   먼저 걸려 **죽은 중복 항목**이 된다. ADR-0062 "CONTEXT 기정의 훼손 없음 — 획득 경로만 먼저 실존화"
#   의 정확한 이행 = 기존 종을 그대로 쓰고 채집 산출로 잇는 것이다(판매가 상향은 crops.gd에서).
const JEOSEUNG_SAM := "jeoseung_sam"            # 저승삼(冥蔘)
# 황천해 해변 4(절기 무관 — 존 배선 S4-T8)
const HWANGCHEON_SANHO := "hwangcheon_sanho"    # 황천산호
const NEOK_SEONGGAE := "neok_seonggae"          # 넋성게
const YURI_GODUNG := "yuri_godung"              # 유리고둥
const MULBINEUL_JOGAE := "mulbineul_jogae"      # 물비늘조개
# ── ★[S4-T8 / ADR-0062 결정 9 ㉠] 덤불 열매 2종(절기 창 나흘씩) ────────────────
# 스폰 로스터 22종과 **다른 축**이다: 빈터에 돋는 게 아니라 *덤불을 흔들어* 얻는다(BerryBushes 소관).
# 그래서 `ForageSpawns.all_species()`엔 안 들어가고(로스터 22종 불변) 여기 아이템으로만 산다.
# ★ id 충돌 확인 — 기존 `JEOSEUNG_SANDALGI`(저승산딸기·유화절 일반종)와 이름이 닮았지만 id·종·획득
#   경로가 전부 다르다(저건 빈터 스폰, 이건 덤불). 그 외 작물·과일·어종·산물·재료와도 id 교집합 0
#   (forage_extras_test ①f가 실제로 대조한다).
# ★ 가격(잠정 — owner 큐): 스타듀 salmonberry 5g / blackberry 20g의 *상대비*는 살리되, 흔들기가
#   나흘 창 한정이라 채집 일반종 최저(잿빛냉이 30)보다 낮은 20/30 밴드에 둔다(상시 소득이 아니라
#   철 이벤트 소득 — 절기 창의 희소성이 총량을 이미 제한한다).
const NEOK_DALGI := "neok_dalgi"                # 넋딸기(피안절 15~18일 — salmonberry 대응)
const JAETBIT_BOKBUNJA := "jaetbit_bokbunja"    # 잿빛복분자(망연절 8~11일 — blackberry 대응)
const FORAGEABLES := {                   # 채집물 id → {name_ko, price(기준 판매가)}
	SPIRIT_FLOWER: {"name_ko": "피안화", "price": 30},
	# 저승 숲 일반 12
	NEOK_GOSARI: {"name_ko": "넋고사리", "price": 35},
	JAETBIT_NAENGI: {"name_ko": "잿빛냉이", "price": 30},
	JEOSEUNG_DALLAE: {"name_ko": "저승달래", "price": 45},
	JEOSEUNG_SANDALGI: {"name_ko": "저승산딸기", "price": 35},
	HONIP_BAKHA: {"name_ko": "혼잎박하", "price": 45},
	JAETBIT_DEODEOK: {"name_ko": "잿빛더덕", "price": 70},
	JAETBIT_DOTORI: {"name_ko": "잿빛도토리", "price": 30},
	ANGAE_DORAJI: {"name_ko": "안개도라지", "price": 55},
	NEOK_SONGI: {"name_ko": "넋송이버섯", "price": 90},
	EONHON_PPURI: {"name_ko": "언혼뿌리", "price": 50},
	SEORI_DONGBAEK: {"name_ko": "서리동백", "price": 80},
	SEONGYA_SOLBANGUL: {"name_ko": "성야솔방울", "price": 40},
	# 미혹 희소 4
	MIHOK_NANCHO: {"name_ko": "미혹난초", "price": 130},
	YURYEONGCHO: {"name_ko": "유령초", "price": 170},
	MYEONGWOL_BEOSEOT: {"name_ko": "명월버섯", "price": 210},
	SEORI_HONBAEKCHO: {"name_ko": "서리혼백초", "price": 250},
	# 미혹 심층 2(고가 — 도끼 티어 게이트 너머). 불사과는 CropCatalog 기존 종 재사용(위 주석).
	JEOSEUNG_SAM: {"name_ko": "저승삼", "price": 420},
	# 황천해 해변 4
	HWANGCHEON_SANHO: {"name_ko": "황천산호", "price": 55},
	NEOK_SEONGGAE: {"name_ko": "넋성게", "price": 45},
	YURI_GODUNG: {"name_ko": "유리고둥", "price": 35},
	MULBINEUL_JOGAE: {"name_ko": "물비늘조개", "price": 22},
	# ★[S4-T8] 덤불 열매 2종(빈터 스폰 아님 — 덤불 흔들기 전용)
	NEOK_DALGI: {"name_ko": "넋딸기", "price": 20},
	JAETBIT_BOKBUNJA: {"name_ko": "잿빛복분자", "price": 30},
}
# ── ★[S3-T7 / ADR-0061 결정 7] 게잡이통 통용물 3종 — 게·조개류(패시브 어획) ──────────
# 채집물(FORAGEABLES)·어획물(FishCatalog)과 **정확히 같은 결**의 품질 유차원 CAT_HARVEST다. 즉
# 판매·서빙·선물·정렬·출하·의뢰 보상 계산이 전부 기존 경로로 자동 통용된다(신규 분기 0).
# ★ 왜 FishCatalog가 아니라 여기인가: FishCatalog는 **캐스팅으로 걸리는 로스터**(서식지·절기·시간
#   잠금·체급·격투 파라미터)의 단일 출처다. 통용물은 격투도 체급도 절기 잠금도 없는 *덫의 산물*이라
#   그 스키마의 필드를 대부분 못 채운다 — 넣으면 로스터가 "안 낚이는 어종"으로 오염된다(그리고
#   roll_fish 가중 분모까지 흔든다). 채집물이 밭 작물과 분리돼 있는 것과 같은 판단이다.
# ★ 명명(CONTEXT 저승 결 · FishCatalog 명명 규약 계승 — "넋/잿빛" 수식어 합성, 잠정·owner 큐):
#   넋게(넋붕어·넋멸치 결) · 혼조개 · 잿빛소라(잿빛송사리 결).
# ★ 가격 밴드 = 소 체급 물고기 결(30~60G — 넋붕어 32 / 초롱치 52 근방). 패시브 산출이 손 낚시
#   중·대 체급(78~190G)을 넘지 않게 잠근다(ADR-0008 "관계·자동화는 곱셈기지 대체가 아니다"의 결).
const NEOK_GE := "neok_ge"              # 넋게
const HON_JOGAE := "hon_jogae"          # 혼조개
const JAETBIT_SORA := "jaetbit_sora"    # 잿빛소라
const POT_GOODS := {                     # 통용물 id → {name_ko, price(기준 판매가)}
	NEOK_GE: {"name_ko": "넋게", "price": 45},
	HON_JOGAE: {"name_ko": "혼조개", "price": 32},
	JAETBIT_SORA: {"name_ko": "잿빛소라", "price": 58},
}
# ── ★[S4-T6 / ADR-0062 결정 4] 수액 3종 — 수액 채취기 정기 산출 ─────────────────
# 통용물(POT_GOODS)과 **정확히 같은 자리**의 아이템군이다: 손이 아니라 설치물이 벌어다 주는 패시브
# 산출이고, 품질 유차원 CAT_HARVEST라 판매·서빙·선물·정렬·출하·의뢰가 기존 경로로 자동 통용된다.
# ★ 벌목 부산물 `SAP`("수액", 3엽전)와 **별 아이템으로 갈린다**: 그건 나무를 *쓰러뜨릴 때* 딸려
#   나오는 잡부산물이고, 이쪽은 살아 있는 나무에서 *주기적으로 받는* 산물이다(원목:석화 목재의
#   역할 분리와 같은 판단 — 같은 id로 합치면 "패시브 수입"의 값을 벌목이 대체해 버린다).
# ★ 종 대응(TreeLedger 종 3 · 결정 3 명명과 1:1): 저승솔→솔넋진(5일) · 넋참나무→넋수지(7일) ·
#   명단풍→명단풍꿀(9일). 주기·매핑의 단일 출처는 TapperLedger다(여긴 id·이름·가격만).
# ★ 가격 밴드(잠정 — owner 큐): 스타듀 pine tar 100 / oak resin 150 / maple syrup 200의 비율을
#   엽전 스케일에 얹되, **하루당 기대 수입이 세 종 거의 같게**(≈18엽전/일) 맞췄다. 게잡이통
#   (≈32엽전/밤)보다 얇다 — 채취기는 미끼도 매일 들르기도 없는 더 느슨한 패시브라 그만큼 덜 준다.
const SOLNEOKJIN := "solneokjin"                  # 솔넋진(저승솔 · 5일)
const NEOKSUJI := "neoksuji"                      # 넋수지(넋참나무 · 7일)
const MYEONGDANPUNG_KKUL := "myeongdanpung_kkul"  # 명단풍꿀(명단풍 · 9일)
const SAP_GOODS := {                     # 수액 id → {name_ko, price(기준 판매가)}
	SOLNEOKJIN: {"name_ko": "솔넋진", "price": 90},
	NEOKSUJI: {"name_ko": "넋수지", "price": 130},
	MYEONGDANPUNG_KKUL: {"name_ko": "명단풍꿀", "price": 170},
}
# ── ★[S3-T3 / ADR-0061 결정 3] 어획물(물고기 18종) — 정식 편입 ────────────────
# 채집물(FORAGEABLES)과 같은 결로 품질 유차원 CAT_HARVEST다 — 판매·서빙·선물·정렬이 작물 수확물과
# 동급이고, 퍼펙트 릴 → 등급 매핑(FishCatalog.quality_for)이 그 위에 얹힌다.
# ★ 다만 로스터 dict를 여기 복제하지 않는다 — 데이터는 FishCatalog가 단일 출처로 들고, ItemCatalog는
#   FruitTreeCatalog·AnimalCatalog·FertilizerCatalog와 **정확히 같은 위임 패턴**으로 판정·이름·가격만
#   빌려 온다(이 파일 머리말 "데이터 중복 0, 단일 출처"). 어종 id = 아이템 id다(과일 종 id : 과일
#   아이템 id 관례 동형 — 접미사 없음).
# ★ S3-T2 스텁 4종(fish_stub_*) 제거 — 마이그레이션 코드 없음. 근거: 스텁은 S3-T2가 만든 *같은 슬라이스
#   안의 미공개 중간물*이라 owner 릴리스·세이브 배포를 거친 적이 없고, 설령 개발 세이브에 남아 있어도
#   Inventory._sanitize / ShippingBin.load_save가 "ItemCatalog.has_item 실패 = 조용히 버림"으로 이미
#   방어한다(구세이브 방어 관례 — inventory.gd:434). 남는 건 스텁 물고기가 사라진 슬롯 하나뿐이라
#   치환 매핑을 유지할 값이 없다(ADR-0024 "구포맷 마이그레이션 안 함"과 같은 판단).

# id가 어획물인가(ADR-0061 "영향" 항의 `_is_fish` 헬퍼 — _is_fruit 결). 뱃사공 환전·낚시 의뢰가 이걸 본다.
static func _is_fish(id: String) -> bool:
	return FishCatalog.has(id)

# ★[S3-T4] id가 낚시 기어(낚싯대·미끼·태클)인가. 데이터·판정은 GearCatalog 위임(_is_fish 결).
static func _is_gear(id: String) -> bool:
	return GearCatalog.has(id)

# 낚싯대만(캐스팅 가능 판정 — main._can_cast이 "든 도구 = 동사"로 읽는다).
static func _is_rod(id: String) -> bool:
	return GearCatalog.is_rod(id)

# ★[S5-T4] id가 무기(검 5종)인가. 데이터·판정은 WeaponCatalog 위임(_is_gear 결).
#   main._use_tool이 이 술어 하나로 "휘두르기 동사"를 가른다("든 것이 곧 동사" — ADR-0024).
static func _is_weapon(id: String) -> bool:
	return WeaponCatalog.has(id)

# 대형 산물 접미("<산물>_large"). 산물 아이템 id + 이 접미 = 대형 변이(판매가 ×2, §4.1). 씨앗:수확물 결.
const LARGE_SUFFIX := "_large"

# ── 설치물(S1R-T9, 카탈로그 §1-B) — 저승 스프링클러 티어1(그레이박스) ────────────────
# 지면 칸에 설치해 4방 인접 4칸을 아침에 자동 급수하는 설치물. 스택 가능·상점 구매(그레이박스
# 획득 경로 — 카탈로그의 정식 제작 게이트는 채광 재료가 Slice 5 의존이라 여기선 구매로 대체).
# 배치·급수·세이브는 Sprinkler 노드(sprinkler.gd)가, 아이템 정의는 여기가 든다(도구:재료 결).
# ★[S3-T7 / ADR-0061 결정 7] 게잡이통 — 물가 인접 칸에 놓고 미끼를 넣어 두면 밤새 어획하는 패시브
#   설치물(스프링클러 결). **생선가게 전용·낚시 숙련 lvl3 해금**(스타듀 Crab Pot 레시피 1:1 — 잠정).
#   배치·장전·수거·일일 롤·세이브는 CrabPotLedger(crab_pot.gd)가, 아이템 정의는 여기가 든다.
const CRAB_POT := "crab_pot"
const SPRINKLER := "sprinkler"
const TAPPER := "sap_tapper"   # ★[S4-T5] 수액 채취기 — 제작 전용(CraftCatalog). 설치·원장은 S4-T6
# ★[S5-T3 / ADR-0063 결정 3] 업화로 — 광석 5 + 혼탄 1을 넣고 **게임 내 분**만큼 기다리면 주괴가
#   나오는 설치물. 수액 채취기 선례(제작 전용 CAT_PLACEABLE)를 그대로 따르되, 원장 축이 *일*이
#   아니라 *분*이다(FurnaceLedger 머리말 참조). 아이템 정의는 여기, 원장은 furnace.gd.
const FURNACE := "furnace"
const PLACEABLES := {                    # 설치물 id → {name_ko, price(구매가)}
	SPRINKLER: {"name_ko": "저승 스프링클러", "price": 60},
	# 600G(잠정) — 스프링클러(60G) 10배. 낚시 lvl3까지 굴린 플레이어의 한나절 벌이 규모라
	# "해금 직후 하나, 이후 천천히 늘린다"가 되게 잡았다(패시브 수입의 초기 투자 게이트).
	CRAB_POT: {"name_ko": "게잡이통", "price": 600},
	# ★[S4-T5] 수액 채취기 — 비매(제작 전용·CraftCatalog TAPPER 레시피). price = 잔가(출하 시).
	TAPPER: {"name_ko": "수액 채취기", "price": 50},
	# ★[S5-T3] 업화로 — 비매(제작 전용·CraftCatalog FURNACE 레시피). price = 잔가(돌 25 + 명동 광석
	#   20의 원가 150엽전보다 낮게 둬 "만들어 팔기"가 차익이 되지 않게 한다 — ADR-0052 비-가치 원칙).
	FURNACE: {"name_ko": "업화로", "price": 80},
}

# 씨앗 아이템 id 접미사("<작물군>_seed"). 작물군 id와 1:1 매핑.
const SEED_SUFFIX := "_seed"
# 묘목 아이템 id 접미사("<과일종>_sapling"). FruitTreeCatalog 종 id와 1:1(S1-5b).
# 수확된 과일 아이템 id = 과일 종 id 그대로(harvest_id와 같은 결 — 씨앗:수확물 = 묘목:과일).
const SAPLING_SUFFIX := "_sapling"

# 도구 카탈로그(유니크·비매). 씨앗·수확물은 CropCatalog 파생이라 상수에 없다(아래 헬퍼).
#   name_ko  : 표시명
#   color    : 그레이박스 임시 아이콘 색(도구만 — 씨앗·수확물은 작물 스프라이트 재사용)
const TOOLS := {
	HOE: {"name_ko": "괭이", "color": Color(0.62, 0.45, 0.30)},          # 흙빛 손잡이
	WATERING_CAN: {"name_ko": "물뿌리개", "color": Color(0.35, 0.55, 0.70)},  # 물빛 통
	SCYTHE: {"name_ko": "낫", "color": Color(0.72, 0.70, 0.42)},          # ★S1-8 마른 풀빛 날
	PICKAXE: {"name_ko": "곡괭이", "color": Color(0.55, 0.52, 0.56)},     # ★S1-8 회청 강철
	AXE: {"name_ko": "도끼", "color": Color(0.68, 0.40, 0.34)},           # ★S1-8 붉은 자루
	# ★[S3-T4] 낚싯대·태클은 여기 없다 — GearCatalog가 이름·색·가격의 단일 출처이고(4티어·3태클),
	#   아래 조회 함수들이 CAT_TOOL 취급을 그대로 얹는다(도구:기어 = 같은 카테고리·다른 출처).
}

# ── id 변환(작물군 ↔ 아이템 id) ─────────────────────────────────────────────
# 작물군 id → 씨앗 아이템 id("honryeongcho" → "honryeongcho_seed").
static func seed_id(crop_id: String) -> String:
	return crop_id + SEED_SUFFIX

# 작물군 id → 수확물 아이템 id(수확물 id = 작물 id 그대로).
static func harvest_id(crop_id: String) -> String:
	return crop_id

# 과일 종 id → 묘목 아이템 id("honbaekdo" → "honbaekdo_sapling"). S1-5b 심기 재료.
static func sapling_id(fruit_id: String) -> String:
	return fruit_id + SAPLING_SUFFIX

# ── 분류 판정(내부) ─────────────────────────────────────────────────────────
# id가 씨앗 아이템인가 = "_seed"로 끝나고 그 앞부분이 실제 작물군인가(오타·손상 방어).
static func _is_seed(id: String) -> bool:
	return id.ends_with(SEED_SUFFIX) and CropCatalog.has_crop(_seed_crop(id))

# 씨앗 아이템 id → 작물군 id("honryeongcho_seed" → "honryeongcho"). 씨앗 아님이면 "".
static func _seed_crop(id: String) -> String:
	return id.trim_suffix(SEED_SUFFIX) if id.ends_with(SEED_SUFFIX) else ""

# id가 묘목 아이템인가 = "_sapling"로 끝나고 그 앞부분이 실제 과일 종인가(오타·손상 방어).
static func _is_sapling(id: String) -> bool:
	return id.ends_with(SAPLING_SUFFIX) and FruitTreeCatalog.has(_sapling_fruit(id))

# 묘목 아이템 id → 과일 종 id("honbaekdo_sapling" → "honbaekdo"). 묘목 아님이면 "".
static func _sapling_fruit(id: String) -> String:
	return id.trim_suffix(SAPLING_SUFFIX) if id.ends_with(SAPLING_SUFFIX) else ""

# id가 수확된 과일 아이템인가(과일 종 id 그대로). 판매·스택은 작물 수확물과 동급(CAT_HARVEST).
static func _is_fruit(id: String) -> bool:
	return FruitTreeCatalog.has(id)

# id가 비료 아이템인가(S1-6). 데이터·판정은 FertilizerCatalog에 위임(_is_fruit 결).
static func _is_fertilizer(id: String) -> bool:
	return FertilizerCatalog.has(id)

# ── 목축 산물 판정(S1-7, §8.6 — _is_fruit 결) ────────────────────────────────
# id가 짐승 산물(기준 변이)인가. 데이터·판정은 AnimalCatalog에 위임.
static func _is_animal_base(id: String) -> bool:
	return AnimalCatalog.has_product(id)

# 대형 산물 아이템 id → 기준 산물 id("honbaek_ran_large" → "honbaek_ran"). 대형 아님이면 "".
static func _large_base(id: String) -> String:
	return id.trim_suffix(LARGE_SUFFIX) if id.ends_with(LARGE_SUFFIX) else ""

# id가 대형 산물 변이인가 = "_large"로 끝나고 그 앞부분이 실제 산물인가(오타·손상 방어).
static func _is_large_product(id: String) -> bool:
	return id.ends_with(LARGE_SUFFIX) and AnimalCatalog.has_product(_large_base(id))

# id가 짐승 산물(기준 or 대형)인가. 판매·스택은 작물 수확물과 동급(CAT_HARVEST).
static func _is_animal_product(id: String) -> bool:
	return _is_animal_base(id) or _is_large_product(id)

# id가 건초(급여 재료)인가.
static func _is_hay(id: String) -> bool:
	return id == HAY

# id가 개간 드랍 재료인가(S1-8, §10.2). 건초와 함께 CAT_MATERIAL(Phase 3 가공 예약).
static func _is_material(id: String) -> bool:
	return MATERIALS.has(id)

static func _is_relic(id: String) -> bool:
	return RELICS.has(id)   # ★[S2-T5] 유품 — 혼백관 기증 대상

# ★[S9-T7] id가 책·비밀 노트인가. 데이터(제목·본문)는 **Books가 단일 출처**라 여기는 판정/표시
#   위임만 한다(MenuCatalog·FishCatalog 위임 관례 동형 — 중복 0). id 상수도 안 박는다: 책 id를
#   코드에서 부르는 쪽은 books.gd·혼백관이고 그쪽은 Books를 직접 보는 게 정배다.
static func _is_book(id: String) -> bool:
	return Books.has_text(id)

# ★[S5-T2] id가 광물(광석·혼탄·돌·보석·지오드)인가. 개간 드랍(MATERIALS)과 같은 품질 무차원
#   CAT_MATERIAL이지만 dict를 가르는 이유는 위 로스터 주석 참조(제련·개봉·퍼크가 종별로 순회한다).
static func _is_mineral(id: String) -> bool:
	return MINERALS.has(id)

# ★[S5-T3] id가 주괴(제련 산출 4종)인가. 광물과 같은 CAT_MATERIAL이지만 **등급을 싣는다**
#   (위 INGOTS 주석의 명시적 예외 — price_of가 quality_mult를 곱하는 유일한 자재군).
static func _is_ingot(id: String) -> bool:
	return INGOTS.has(id)

# ★[S5-T6] id가 회복 소모품(명부환)인가. 미끼(GearCatalog)와 같은 CAT_CONSUMABLE이지만 dict를 가르는
#   이유는 소비 동사가 다르기 때문이다 — 미끼는 캐스팅이 소모하고, 환약은 든 채 LMB가 소모한다.
static func _is_potion(id: String) -> bool:
	return POTIONS.has(id)

# ★[S5-T6] id가 열쇠(나락 열쇠)인가. 자재와 같은 CAT_MATERIAL이지만 **스택 불가·비매**라 별 dict다.
static func _is_key(id: String) -> bool:
	return KEYS.has(id)

# ★[S5-T8] id가 소모 장치(계단)인가. 환약과 같은 CAT_CONSUMABLE이되 dict를 가르는 이유는 환약과
#   같다 — 소비 동사가 다르다(환약은 체력을 채우고, 계단은 무대를 바꾼다).
static func _is_utility(id: String) -> bool:
	return UTILITIES.has(id)

# ★[S6-T1] id가 카페 메뉴(기본 4 + 융합 12)인가. 환약·계단과 같은 CAT_CONSUMABLE이되 데이터는
#   MenuCatalog가 든다(위 메뉴 블록 주석 — 위임 관례). 소비 동사는 *서빙*이라 또 갈린다.
static func _is_menu(id: String) -> bool:
	return MenuCatalog.has(id)

# ★[S5-T6] 이 소모품 1개가 채우는 HP("" · 소모품 아님 = 0). 회복 수치의 단일 조회 창구다
#   (main이 POTIONS dict를 직접 뒤지지 않게 — 카탈로그가 값의 주인).
static func potion_heal(id: String) -> int:
	return int(POTIONS[id]["heal"]) if _is_potion(id) else 0

# id가 채집물인가(ADR-0052 §118). 품질 유차원 CAT_HARVEST(작물 수확물 결 — 판매·서빙·선물 동급).
static func _is_forageable(id: String) -> bool:
	return FORAGEABLES.has(id)

# ★[S3-T7] id가 게잡이통 통용물인가(넋게·혼조개·잿빛소라). 채집물과 같은 품질 유차원 CAT_HARVEST.
static func _is_pot_good(id: String) -> bool:
	return POT_GOODS.has(id)

# ★[S4-T6] id가 수액(채취기 산출 3종)인가. 통용물과 같은 품질 유차원 CAT_HARVEST — 다만 취급 창구는
#   생선가게가 아니라 일반 판매·출하다(_is_seafood에 넣지 않는다 — 수액은 바다 물목이 아니다).
static func _is_sap_good(id: String) -> bool:
	return SAP_GOODS.has(id)

# ★[S3-T7] 생선가게가 **취급하는 물목**인가 = 어획물 + 통용물. 뱃사공 환전 창구가 이걸 본다
#   ("상점 중 물고기를 취급하는 유일한 얼굴" — ADR-0061 결정 5). 게·조개를 잡화점에 팔러 가는 건
#   어색하고, 통용물의 유일한 소스가 낚시 계열이라 환전 창구를 공유하는 게 정배다.
#   ★ `_is_fish`와 갈라 둔 이유: 어종 로스터(18종)는 캐스팅 롤·의뢰·도감의 축이라 통용물이
#     섞이면 안 된다. "낚이는 것"과 "생선가게가 사 주는 것"은 다른 집합이다.
static func _is_seafood(id: String) -> bool:
	return _is_fish(id) or _is_pot_good(id)

# id가 설치물인가(S1R-T9 — 스프링클러). 품질 무차원 스택·CAT_PLACEABLE(구매·설치).
static func _is_placeable(id: String) -> bool:
	return PLACEABLES.has(id)

# 기준 산물 id → 대형 변이 아이템 id("honbaek_ran" → "honbaek_ran_large"). livestock 대형 수집이 쓴다.
static func large_product_id(product_id: String) -> String:
	return product_id + LARGE_SUFFIX

# ── 조회 ────────────────────────────────────────────────────────────────────
# 카탈로그에 있는 유효 아이템인가(도구·씨앗·묘목·수확물·과일·비료·건초·산물 어느 하나). 슬롯 add/load 검증에 쓴다.
static func has_item(id: String) -> bool:
	return TOOLS.has(id) or _is_seed(id) or _is_sapling(id) or CropCatalog.has_crop(id) or _is_fruit(id) \
		or _is_fertilizer(id) or _is_hay(id) or _is_material(id) or _is_animal_product(id) or _is_forageable(id) \
		or _is_placeable(id) or _is_relic(id) or _is_fish(id) or _is_gear(id) or _is_pot_good(id) \
		or _is_sap_good(id) or _is_mineral(id) or _is_ingot(id) or _is_weapon(id) \
		or _is_potion(id) or _is_key(id) or _is_utility(id) or _is_menu(id) or _is_book(id)

# 카테고리("" = 알 수 없는 id). 인벤토리가 수확물/씨앗을 가르거나 main이 동사를 정할 때 쓴다.
# 과일(수확된 혼백도 등)은 작물 수확물과 동급 CAT_HARVEST(판매·서빙·정렬 동일 취급).
static func category_of(id: String) -> String:
	if TOOLS.has(id):
		return CAT_TOOL
	# ★[S3-T4] 낚시 기어 — 낚싯대·태클은 유니크 장착물이라 도구와 같은 칸(CAT_TOOL), 미끼는 스택
	#   소모품(CAT_CONSUMABLE — Phase 3 조리용으로 예약만 돼 있던 카테고리의 첫 실사용).
	if GearCatalog.is_rod(id) or GearCatalog.is_tackle(id):
		return CAT_TOOL
	if GearCatalog.is_bait(id):
		return CAT_CONSUMABLE
	# ★[S5-T6] 명부환 = 미끼와 같은 스택 소모품 칸(든 채 LMB로 마신다 — main._drink_potion).
	# ★[S5-T8] 계단도 같은 칸(든 채 LMB로 놓는다 — main._use_stairs).
	# ★[S6-T1] 카페 메뉴도 같은 칸(결정 9 — 들고 쓰면 사라지는 스택 물건. 소비 동사만 서빙으로 다르다).
	if _is_potion(id) or _is_utility(id) or _is_menu(id):
		return CAT_CONSUMABLE
	# ★[S5-T4] 무기 = 유니크 장착물이라 도구·낚싯대와 같은 칸(CAT_TOOL). 새 카테고리를 안 만드는 이유는
	#   "든 것이 곧 동사"(ADR-0024)라 핫바·인벤·툴팁·정렬이 도구와 완전히 같은 취급을 하면 되기 때문이다.
	if _is_weapon(id):
		return CAT_TOOL
	if _is_seed(id):
		return CAT_SEED
	if _is_sapling(id):
		return CAT_SAPLING
	if CropCatalog.has_crop(id) or _is_fruit(id) or _is_animal_product(id) or _is_forageable(id) \
			or _is_fish(id) or _is_pot_good(id) or _is_sap_good(id):
		return CAT_HARVEST   # 채집물(ADR-0052)·어획물(★S3-T2)·통용물(★S3-T7)·수액(★S4-T6)도 수확물 결 — 품질·판매·서빙 동급
	if _is_fertilizer(id):
		return CAT_FERTILIZER
	if _is_hay(id) or _is_material(id) or _is_mineral(id) or _is_ingot(id) or _is_key(id):
		# 건초(S1-7)·개간 드랍(S1-8)·★광물(S5-T2)·★주괴(S5-T3)·★열쇠(S5-T6) = 재료 카테고리.
		# ★열쇠만 스택 불가다(stackable_of 참조) — 카테고리는 같아도 개수 축이 없다.
		return CAT_MATERIAL
	if _is_placeable(id):
		return CAT_PLACEABLE  # 설치물(S1R-T9 스프링클러) — 지면 설치·회수
	if _is_relic(id):
		return CAT_RELIC      # ★[S2-T5] 유품 — 혼백관 기증 대상
	if _is_book(id):
		return CAT_BOOK       # ★[S9-T7] 책·비밀 노트 — 즉독·전시(책)·재읽기
	return ""

# 표시명(HUD·상점·툴팁). 씨앗="<작물명> 씨앗"·묘목="<과일명> 묘목"·수확물=작물명·과일=과일명·도구=도구명. 없으면 "".
static func name_of(id: String) -> String:
	if TOOLS.has(id):
		return TOOLS[id]["name_ko"]
	if _is_gear(id):
		return GearCatalog.name_of(id)   # ★S3-T4 낚시 기어 10종(단일 출처 = GearCatalog)
	if _is_weapon(id):
		return WeaponCatalog.name_of(id)   # ★S5-T4 무기 5종(단일 출처 = WeaponCatalog)
	if _is_seed(id):
		return "%s 씨앗" % CropCatalog.name_of(_seed_crop(id))
	if _is_sapling(id):
		return "%s 묘목" % FruitTreeCatalog.name_of(_sapling_fruit(id))
	if CropCatalog.has_crop(id):
		return CropCatalog.name_of(id)
	if _is_fruit(id):
		return FruitTreeCatalog.name_of(id)
	if _is_fertilizer(id):
		return FertilizerCatalog.name_of(id)
	if _is_hay(id):
		return "건초"
	if _is_material(id):
		return MATERIALS[id]["name_ko"]
	if _is_mineral(id):
		return MINERALS[id]["name_ko"]   # ★S5-T2 광물 13종(광석 4·혼탄·돌·보석 5·지오드 2)
	if _is_ingot(id):
		return INGOTS[id]["name_ko"]     # ★S5-T3 주괴 4종(제련 산출)
	if _is_potion(id):
		return POTIONS[id]["name_ko"]    # ★S5-T6 회복 소모품(명부환 — 길드 판매)
	if _is_utility(id):
		return UTILITIES[id]["name_ko"]  # ★S5-T8 소모 장치(계단 — 손 제작)
	if _is_menu(id):
		return MenuCatalog.name_of(id)   # ★S6-T1 카페 메뉴 16종(단일 출처 = MenuCatalog)
	if _is_key(id):
		return KEYS[id]["name_ko"]       # ★S5-T6 열쇠(나락 열쇠 — 60층 보상 상자)
	if _is_forageable(id):
		return FORAGEABLES[id]["name_ko"]
	if _is_fish(id):
		return FishCatalog.name_of(id)   # ★S3-T3 어획물 18종(로스터 단일 출처 = FishCatalog)
	if _is_pot_good(id):
		return POT_GOODS[id]["name_ko"]   # ★S3-T7 게잡이통 통용물 3종
	if _is_sap_good(id):
		return SAP_GOODS[id]["name_ko"]   # ★S4-T6 수액 3종(솔넋진·넋수지·명단풍꿀)
	if _is_placeable(id):
		return PLACEABLES[id]["name_ko"]
	if _is_book(id):
		return Books.title_of(id)      # ★[S9-T7] 책·비밀 노트(단일 출처 = Books)
	if _is_relic(id):
		return RELICS[id]["name_ko"]   # ★[S2-T5] 유품
	if _is_large_product(id):
		return "큰 %s" % AnimalCatalog.product_name(_large_base(id))
	if _is_animal_base(id):
		return AnimalCatalog.product_name(id)
	return ""

# 스택 가능한가. 도구=유니크(false), 씨앗·묘목·수확물·과일·비료·건초·산물=스택(true). 인벤토리 add가 합칠지 가른다.
static func stackable_of(id: String) -> bool:
	if TOOLS.has(id):
		return false
	if _is_gear(id):
		return GearCatalog.stackable_of(id)   # ★S3-T4 미끼만 스택(낚싯대·태클 = 유니크 장착물)
	if _is_weapon(id):
		return false   # ★S5-T4 무기 = 전부 유니크 장착물(검 5종 — 스택 0)
	if _is_key(id):
		return false   # ★S5-T6 열쇠 = 세상에 한 자루(개수 축 없음 — 도구·무기 결)
	if _is_book(id):
		return false   # ★S9-T7 책·노트 = 세상에 한 권씩(중복 입수 0이라 개수 축이 없다)
	if _is_potion(id) or _is_utility(id) or _is_menu(id):
		return true    # ★S5-T6 환약 · ★S5-T8 계단 · ★S6-T1 메뉴 = 스택 소모품(미끼 결)
	return _is_seed(id) or _is_sapling(id) or CropCatalog.has_crop(id) or _is_fruit(id) \
		or _is_fertilizer(id) or _is_hay(id) or _is_material(id) or _is_animal_product(id) or _is_forageable(id) \
		or _is_placeable(id) or _is_relic(id) or _is_fish(id) or _is_pot_good(id) or _is_sap_good(id) \
		or _is_mineral(id) or _is_ingot(id)

# 기준 가격(골드). 도구=비매(0), 씨앗=구매가(seed_cost), 묘목=구매가(sapling_cost), 비료=구매가(buy_cost),
# 수확물/과일=판매가. 없으면 0. 상점은 이 값으로 사고팔되, 할인 등 변형은 호출 측(store_discount 등)이 얹는다.
# ★ S1-6(§8.7): quality 인자로 수확물·과일 판매가에 등급 배수를 얹는다(floor, 스타듀 정합). 기본 Q0라
#   무인자 기존 호출은 회귀 0. 품질 무차원 아이템(도구·씨앗·묘목·비료)은 등급을 무시(항상 기준가).
static func price_of(id: String, quality: int = Q_NORMAL) -> int:
	if TOOLS.has(id):
		return 0
	# ★[S3-T4] 낚시 기어 = 품질 무차원 고정 매입가(T1 = 0 — 뱃사공 증정, S3-T5). 파는 곳은 매대다.
	if _is_gear(id):
		return GearCatalog.price_of(id)
	# ★[S5-T4] 무기 = 품질 무차원 고정 매입가(녹슨 혼검 = 0 — 길드 첫 방문 증정, S5-T6).
	if _is_weapon(id):
		return WeaponCatalog.price_of(id)
	# ★[S5-T6] 환약 = 품질 무차원 고정 매입가(파는 곳은 길드 매대). 열쇠는 **비매**라 여기 없다 — 등록
	#   되지 않은 id로 떨어져 0을 돌려받는다(팔 수도 살 수도 없다는 뜻이 값 0으로 표현된다).
	if _is_potion(id):
		return int(POTIONS[id]["price"])
	# ★[S6-T1] 카페 메뉴 = **품질 무차원** 판매가(메뉴는 품질 무영향 — catalog §1-B). 융합 메뉴가는
	#   MenuCatalog가 시그니처 기본가 ×2.5로 파생한다(단일 출처 — 여기서 배수를 또 얹지 않는다).
	if _is_menu(id):
		return MenuCatalog.price_of(id)
	if _is_seed(id):
		return CropCatalog.seed_cost(_seed_crop(id))
	if _is_sapling(id):
		return FruitTreeCatalog.sapling_cost(_sapling_fruit(id))
	if _is_fertilizer(id):
		return FertilizerCatalog.buy_cost(id)
	if CropCatalog.has_crop(id):
		return int(CropCatalog.sell_price(id) * quality_mult(quality))
	if _is_fruit(id):
		return int(FruitTreeCatalog.fruit_sell(id) * quality_mult(quality))
	if _is_hay(id):
		return HAY_COST   # 건초 = 품질 무차원 고정가(급여 재료)
	if _is_material(id):
		return int(MATERIALS[id]["price"])   # ★S1-8 개간 드랍 = 품질 무차원 고정가(Phase 3 가공 예약)
	if _is_mineral(id):
		return int(MINERALS[id]["price"])    # ★S5-T2 광물 = 품질 무차원 고정가(등급 배수 없음)
	if _is_ingot(id):
		# ★S5-T3 주괴 = **자재 중 유일하게** 등급 배수를 받는다(INGOTS 주석의 명시적 예외).
		return int(INGOTS[id]["price"] * quality_mult(quality))
	if _is_forageable(id):
		return int(FORAGEABLES[id]["price"] * quality_mult(quality))   # ★ADR-0052 채집물 = 기준가 × 등급 배수(수확물 결)
	if _is_fish(id):
		return int(FishCatalog.price_of(id) * quality_mult(quality))   # ★S3-T3 어획물 = 기준가 × 등급 배수(채집물 결)
	if _is_pot_good(id):
		return int(POT_GOODS[id]["price"] * quality_mult(quality))   # ★S3-T7 통용물 = 기준가 × 등급 배수(어획물 결)
	if _is_sap_good(id):
		return int(SAP_GOODS[id]["price"] * quality_mult(quality))   # ★S4-T6 수액 = 기준가 × 등급 배수(통용물 결)
	if _is_placeable(id):
		return int(PLACEABLES[id]["price"])   # ★S1R-T9 설치물 = 품질 무차원 고정 구매가(스프링클러)
	if _is_book(id):
		# ★S9-T7 책·노트 = **비매**. 값 0이 곧 "팔 수도 살 수도 없다"의 표현이다(열쇠와 같은 결).
		#   유품과 갈리는 지점이기도 하다 — 유품은 중복 발굴분을 팔지만 책은 애초에 중복이 없다.
		return 0
	if _is_relic(id):
		return int(RELICS[id]["price"])   # ★S2-T5 유품 = 품질 무차원 고정가(중복 발굴분 판매)
	# ★ S1-7(§8.6): 대형 산물은 기준 판매가 ×2에 품질 배수를 얹는다(대형 = 품질과 별 축). 기준 산물은 품질 배수만.
	if _is_large_product(id):
		return int(AnimalCatalog.product_sell(_large_base(id)) * 2.0 * quality_mult(quality))
	if _is_animal_base(id):
		return int(AnimalCatalog.product_sell(id) * quality_mult(quality))
	return 0

# ★[S6-T1 / ADR-0064 결정 11 ②] 그 카테고리에 속한 전 아이템 id(선언 순). 곳간·메뉴 UI가 "무엇을
# 담을 수 있나 / 무엇을 파나"를 열거할 때 쓴다 — 지금까지는 그런 창구가 없어 호출 측이 로스터
# dict를 하드코딩 목록으로 다시 세워야 했다(FORAGEABLES를 밖에서 순회하던 그 패턴의 해소).
#
# ★ 왜 dict 하나를 순회하지 않고 소스를 모아 붙이나: 이 카탈로그는 데이터를 **위임**해서 든다
#   (작물=CropCatalog · 어종=FishCatalog · 기어=GearCatalog …). "전 아이템"이라는 단일 컬렉션이
#   애초에 없으므로, 여기서 소스별로 모아 category_of로 거른다(단일 출처 원칙 불변).
# ★ 도구·씨앗·묘목처럼 **파생 id**를 갖는 군은 파생해서 넣는다(씨앗 = 작물군 × _seed).
# ★ 비용: 호출당 전 로스터 1회 순회다. 매 프레임 도는 자리(_draw·_process)에서 부르지 말고
#   패널을 여는 순간처럼 이벤트 시점에 한 번 부른다.
static func ids_in_category(category: String) -> Array:
	var out: Array = []
	var pools: Array = [
		TOOLS.keys(), GearCatalog.RODS.keys(), GearCatalog.BAITS.keys(),
		GearCatalog.TACKLES.keys(), WeaponCatalog.ids(),
		MATERIALS.keys(), MINERALS.keys(), INGOTS.keys(), POTIONS.keys(),
		UTILITIES.keys(), KEYS.keys(), RELICS.keys(), FORAGEABLES.keys(),
		POT_GOODS.keys(), SAP_GOODS.keys(), PLACEABLES.keys(),
		FertilizerCatalog.ids(), FishCatalog.ids(), MenuCatalog.ids(),
		Books.all_ids(),   # ★S9-T7 책 8 + 비밀 노트 15(수집 트래커·전시 UI 열거)
		[HAY],
	]
	for pool in pools:
		for id in pool:
			var sid := str(id)
			if category_of(sid) == category and not out.has(sid):
				out.append(sid)
	# 파생 id 군(씨앗·묘목·과일·짐승 산물) — 원본 로스터에 그 id로는 안 들어 있어 따로 만든다.
	for crop_id in CropCatalog.ids():
		for sid in [harvest_id(crop_id), seed_id(crop_id)]:
			if category_of(sid) == category and not out.has(sid):
				out.append(sid)
	for fruit_id in FruitTreeCatalog.ids():
		for sid in [fruit_id, sapling_id(fruit_id)]:
			if category_of(sid) == category and not out.has(sid):
				out.append(sid)
	for product_id in AnimalCatalog.product_ids():
		for sid in [product_id, large_product_id(product_id)]:
			if category_of(sid) == category and not out.has(sid):
				out.append(sid)
	return out

# 씨앗 아이템 → 작물군 id("" = 씨앗 아님). main이 "이 씨앗을 심으면 무슨 작물"을 알 때 쓴다.
static func crop_of(id: String) -> String:
	return _seed_crop(id) if _is_seed(id) else ""

# 묘목 아이템 → 과일 종 id("" = 묘목 아님). main이 "이 묘목을 심으면 무슨 혼의 나무"를 알 때 쓴다.
static func fruit_of(id: String) -> String:
	return _sapling_fruit(id) if _is_sapling(id) else ""

# 그레이박스 도구 아이콘 색(도구 외엔 흰색 폴백 — 씨앗·수확물은 작물 스프라이트를 쓰므로 미사용).
static func tool_color_of(id: String) -> Color:
	if TOOLS.has(id):
		return TOOLS[id]["color"]
	if _is_gear(id):
		return GearCatalog.color_of(id)   # ★S3-T4 기어 색박스(아이콘 아트 = S3-T10)
	if _is_weapon(id):
		return WeaponCatalog.color_of(id)   # ★S5-T4 무기 색박스(아이콘 아트 = S5-T10)
	if _is_potion(id):
		return POTIONS[id]["color"]         # ★S5-T6 환약 색박스(CAT_CONSUMABLE 아이콘 폴백이 읽는다)
	if _is_utility(id):
		return UTILITIES[id]["color"]       # ★S5-T8 계단 색박스(환약과 같은 폴백 경로)
	if _is_menu(id):
		return MenuCatalog.color_of(id)     # ★S6-T1 메뉴 색박스(아이콘 아트 = S6 후속)
	if _is_book(id):
		# ★S9-T7 책 색박스(아이콘 아트 = T9). 책 = 그을린 남색 표지 / 노트 = 바랜 종이색으로
		#   두 형태가 한눈에 갈린다(그레이박스 단계의 최소 가독).
		return Color(0.28, 0.24, 0.36) if Books.is_book(id) else Color(0.78, 0.72, 0.58)
	return Color.WHITE
