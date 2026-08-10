extends RefCounted
class_name CropCatalog
# S1-4 — 저승 작물 5작물 + 5메카닉 아키타입 합성 데이터 모델.
#   (초판 T2.2 = 혼령초·피안화·영혼 호박 3종 단순 growth_days 모델을 확장.)
#
# 목적: ROADMAP S1-4 — 단발·재성장·거대·트렐리스·다수확 5아키타입 + 다절기 프레스티지가
#       "데이터로" 정의되고 헤드리스 검증을 통과하는지 한 곳에서 보장한다.
#       설계 근거·수치 = docs/design/homestead-farming-greybox-spec.md §2·§5.
#
# 설계 메모:
#   - 이건 "정적 참조 데이터"다. 세이브 상태(밭 칸·날짜)가 아니라 카탈로그다. 그래서 씬 노드가
#     아니라 static const로 들고, class_name으로 어디서든 CropCatalog.get_crop("...")로 읽는다.
#   - ★ S1-4 스코프(greybox-spec §5.1): 이 파일(데이터+접근자)만 바꾼다. field.gd 등 라이브
#     농사 액션 코드는 한 줄도 안 건드린다(회귀 0). 확장 플래그(regrow_cooldown·is_trellis·
#     giant_capable 등)는 정의만 되고, 실제 재성장 수확·트렐리스 충돌·거대화·품질 roll은
#     S1-5/S1-6/S1-8이 이 표면을 읽어 붙인다(데이터/메카닉 분리).
#   - ★ 하위호환(§5.2): 신규 필드를 CATALOG에 "추가"하고, 낡은 표면은 별칭으로 보존한다.
#     growth_days(id)는 base_growth_days의 얇은 별칭이고, missing은 -1 sentinel을 엄수한다
#     (field.gd is_mature의 need>=0 계약 — 0을 반환하면 미지 작물이 즉시 수확가능해지는 회귀).
#     stages(int)·seed_cost·sell_price·id 상수는 불변(flavor/main/affinity/inventory/
#     item_catalog/crop_preview가 광범위 참조).
#   - 식별자(영문 id)와 표시명(name_ko)을 분리한다: id는 코드·세이브용, name_ko는 화면용.

# ── 작물 식별자(영문 id) — 성장 빠른 순 ─────────────────────────────────────
# ⚠️ 기존 3상수는 절대 이름/값 불변(광범위 참조). 신규 2종만 추가.
const HONRYEONGCHO := "honryeongcho"       # 혼령초 (유화절)
const PIANHWA := "pianhwa"                 # 피안화 (피안절)
const YEONGHON_HOBAK := "yeonghon_hobak"   # 영혼 호박 (성야절)
const HWANGCHEON_PODO := "hwangcheon_podo" # 황천포도 (망연절) — 트렐리스+재성장+다수확
const BULSAGWA := "bulsagwa"               # 불사과 — 다절기 프레스티지(미혹의 숲 채집)

# ── 카탈로그. 키 = 영문 id, 값 = 작물 데이터 ───────────────────────────────
# 필드(greybox-spec §2.1 데이터 모델):
#   [표시·경제·비주얼 — 초판 표면, 불변]
#     name_ko      : 화면 표시명(CONTEXT 용어)
#     stages       : 씨앗→수확 시각 성장 단계 수(int, 비주얼 훅) ⚠️ 배열 아님
#     seed_cost    : 씨앗 구매가(골드)
#     sell_price   : 수확물 판매가(골드)
#   [Base 성장 모드 — 상호배타 핵심 축]
#     growth_mode      : "SINGLE" | "REGROW"
#     base_growth_days : int  — FAST=4 | MID=7 | SLOW=12 타임 밴드(엄격 3밴드)
#     regrow_cooldown  : int  — REGROW일 때 재수확 쿨다운. SINGLE=0 고정.
#                              공식 = max(2, int(round(base*0.4))) → 4→2·7→3·12→5.
#                              단 다절기 프레스티지는 손수 예외(§2.3, cd=7).
#   [메카닉 합성 플래그 — 아키타입은 enum이 아니라 플래그 합성. 포도=트렐리스+재성장 등 겹침]
#     is_trellis   : bool  — 격자 충돌체 통과불가 + 인접 수확(S1-5)
#     giant_capable: bool  — 3×3 성숙 시 확률적 거대화 합체(S1-5)
#     yield_min/max: int   — yield_max>1이면 '다수확' 활성
#   [직교 속성 태그 — 아키타입 아님]
#     multi_seasonal : bool — 절기 전환 사멸 제외 프레스티지(§2.3, Slice 7 사멸 판정이 읽음)
#     seasons        : Array — ★[S7-T2] 재배 절기 인덱스 배열(0 피안·1 유화·2 망연·3 성야).
#                              **빈 배열 = 사철**(FishCatalog.seasons 동형 — 어종 표면을 그대로 상속해
#                              읽는 쪽이 새 문법을 배울 게 없다). 절기 첫날 아침 사멸 패스와
#                              만물상 제철 매대·카페 메뉴 로테이션이 이 한 필드를 읽는다.
#
# ── ★[S7-T2 / ADR-0065 결정 2] 작물 ↔ 절기 배정표(근거) ─────────────────────
#   피안화       → 피안(0)  이름이 곧 절기다(피안화 = 피안절의 꽃). 중간 밴드(7일)라 절기의 허리.
#   혼령초       → 유화(1)  ★ADR 앵커. FAST 4일 = 절기가 열리자마자 회전하는 진입 작물.
#   황천포도     → 망연(2)  ★ADR 앵커. 트렐리스+재성장+다수확 = 거두는 절기(수확기)의 결.
#   영혼 호박    → 성야(3)  ★ADR 앵커. SLOW 12일 대작이 절기 하나를 통째로 쓴다(겨울결 농사 존치 —
#                            스타듀 "겨울 농사 불가"는 비채택, CONTEXT "성야절=영혼 호박이 어울림").
#   불사과       → [] 사철  ★ADR 앵커. multi_seasonal 프레스티지라 **사멸 자체를 안 탄다**
#                            (씨앗은 만물상 미판매 — 매대 필터와 무관).
#   ⇒ 절기당 재배 가능 작물 **최소 1종**(다절기 제외) 보장: 0/1/2/3 각 1종 + 사철 1종.
#   야생·혼합(제작 전용) = WILD_INFO의 절기와 **같은 값을 되쓴다**(모둠 4 + 희소종 모종 4).
#     야생 모둠은 그 절기 숲 일반종을, 희소종 모종은 그 절기 희소종을 내므로 재배 창도 같은 절기다
#     (ForageSpawns.species_for 절기 풀과 1:1 — 모순 0). 혼합 씨앗은 심는 순간 치환되는 유령
#     엔트리라 사철([])로 둬 어떤 절기에 심어도 판정에 안 걸린다.
# 주의: const 중첩 Dictionary는 런타임에 변경 가능하니 읽기 전용으로 다룬다(수정 금지).
const CATALOG := {
	HONRYEONGCHO: {
		"name_ko": "혼령초",
		"stages": 2,
		"seed_cost": 10,
		"sell_price": 20,        # 저수익(순익 +10)
		"growth_mode": "SINGLE",
		"base_growth_days": 4,   # FAST
		"regrow_cooldown": 0,
		"is_trellis": false,
		"giant_capable": false,
		"yield_min": 1,
		"yield_max": 1,
		"multi_seasonal": false,
		"seasons": [1],         # 유화절 — FAST 진입 작물(배정표 참조)
	},
	PIANHWA: {
		"name_ko": "피안화",
		"stages": 3,
		"seed_cost": 25,
		"sell_price": 60,        # 중간(순익 +35)
		"growth_mode": "SINGLE",
		"base_growth_days": 7,   # MID
		"regrow_cooldown": 0,
		"is_trellis": false,
		"giant_capable": false,
		"yield_min": 1,
		"yield_max": 1,
		"multi_seasonal": false,
		"seasons": [0],         # 피안절 — 이름이 곧 절기
	},
	YEONGHON_HOBAK: {
		"name_ko": "영혼 호박",
		"stages": 4,
		"seed_cost": 50,
		"sell_price": 160,       # 고수익(순익 +110)
		"growth_mode": "SINGLE",
		"base_growth_days": 12,  # SLOW
		"regrow_cooldown": 0,
		"is_trellis": false,
		"giant_capable": true,   # 거대 아키타입 — 성숙 3×3 확률 합체(§2.2)
		"yield_min": 1,
		"yield_max": 1,
		"multi_seasonal": false,
		"seasons": [3],         # 성야절 — SLOW 12일 대작이 절기를 통째로 쓴다
	},
	HWANGCHEON_PODO: {
		"name_ko": "황천포도",
		"stages": 3,
		"seed_cost": 80,
		"sell_price": 40,        # 재성장·다수확 볼륨형 저단가
		"growth_mode": "REGROW",
		"base_growth_days": 7,   # MID → cd3
		"regrow_cooldown": 3,    # max(2, round(7*0.4)) = 3
		"is_trellis": true,      # 트렐리스 아키타입(§2.1 정준 예시)
		"giant_capable": false,
		"yield_min": 2,          # 다수확 아키타입(송이 2~3)
		"yield_max": 3,
		"multi_seasonal": false,
		"seasons": [2],         # 망연절 — 거두는 절기(트렐리스·재성장·다수확)
	},
	BULSAGWA: {
		"name_ko": "불사과",
		"stages": 4,
		"seed_cost": 200,        # ⚠️ 채집 전용(만물상 미판매) — 카탈로그 균일성용 placeholder·미사용
		# ★[S4-T1 / ADR-0062 결정 2] 100 → 600. 불사과의 **획득 경로가 미혹 심층 채집으로 실존화**되면서
		#   (도끼 2티어 게이트 너머 = 이 슬라이스 최고 난도 보상) 판매가가 미혹 희소종 최고가(서리혼백초
		#   250)를 넘어야 게이트가 값을 한다. ADR-0062 "불사과 500+" 밴드. 씨앗은 만물상 미판매(채집
		#   전용)라 재배 익스플로잇 경로가 없다 — 다절기 재배 연동은 Slice 7 소관. **잠정(owner 큐)**.
		"sell_price": 600,       # 희소 프레스티지(심층 채집 보상 밴드)
		"growth_mode": "REGROW",
		"base_growth_days": 12,  # §2.3 고정
		"regrow_cooldown": 7,    # §2.3 손수 예외(공식 밖)
		"is_trellis": false,
		"giant_capable": false,
		"yield_min": 1,
		"yield_max": 1,
		"multi_seasonal": true,  # 다절기 프레스티지 — 절기 전환 사멸 제외
		"seasons": [],           # ★사철 — 빈 배열이자 multi_seasonal이라 사멸 패스가 두 번 비껴간다
	},
	# ── ★[S4-T5] 야생·혼합(제작 씨앗 전용 — ids() 밖, 위 WILD_INFO 주석 참조) ──
	# 공통: 성장 7일(스타듀 Wild Seeds 3+4 상속)·SINGLE·sell_price 0(수확은 wild 분기가 치환).
	# seed_cost = 씨앗 아이템 파생 price(제작 전용이라 상점가 아님 — 출하 판매 시 잔가).
	MIXED: {"name_ko": "혼합", "stages": 2, "seed_cost": 5, "sell_price": 0,
		"growth_mode": "SINGLE", "base_growth_days": 7, "regrow_cooldown": 0,
		"is_trellis": false, "giant_capable": false, "yield_min": 1, "yield_max": 1, "multi_seasonal": false, "seasons": []},
	WILD_PIAN: {"name_ko": "야생 모둠(피안)", "stages": 2, "seed_cost": 12, "sell_price": 0,
		"growth_mode": "SINGLE", "base_growth_days": 7, "regrow_cooldown": 0,
		"is_trellis": false, "giant_capable": false, "yield_min": 1, "yield_max": 1, "multi_seasonal": false, "seasons": [0]},
	WILD_YUHWA: {"name_ko": "야생 모둠(유화)", "stages": 2, "seed_cost": 12, "sell_price": 0,
		"growth_mode": "SINGLE", "base_growth_days": 7, "regrow_cooldown": 0,
		"is_trellis": false, "giant_capable": false, "yield_min": 1, "yield_max": 1, "multi_seasonal": false, "seasons": [1]},
	WILD_MANGYEON: {"name_ko": "야생 모둠(망연)", "stages": 2, "seed_cost": 12, "sell_price": 0,
		"growth_mode": "SINGLE", "base_growth_days": 7, "regrow_cooldown": 0,
		"is_trellis": false, "giant_capable": false, "yield_min": 1, "yield_max": 1, "multi_seasonal": false, "seasons": [2]},
	WILD_SEONGYA: {"name_ko": "야생 모둠(성야)", "stages": 2, "seed_cost": 12, "sell_price": 0,
		"growth_mode": "SINGLE", "base_growth_days": 7, "regrow_cooldown": 0,
		"is_trellis": false, "giant_capable": false, "yield_min": 1, "yield_max": 1, "multi_seasonal": false, "seasons": [3]},
	WILD_MIHOK_NANCHO: {"name_ko": "미혹난초", "stages": 2, "seed_cost": 40, "sell_price": 0,
		"growth_mode": "SINGLE", "base_growth_days": 7, "regrow_cooldown": 0,
		"is_trellis": false, "giant_capable": false, "yield_min": 1, "yield_max": 1, "multi_seasonal": false, "seasons": [0]},
	WILD_YURYEONGCHO: {"name_ko": "유령초", "stages": 2, "seed_cost": 40, "sell_price": 0,
		"growth_mode": "SINGLE", "base_growth_days": 7, "regrow_cooldown": 0,
		"is_trellis": false, "giant_capable": false, "yield_min": 1, "yield_max": 1, "multi_seasonal": false, "seasons": [1]},
	WILD_MYEONGWOL: {"name_ko": "명월버섯", "stages": 2, "seed_cost": 40, "sell_price": 0,
		"growth_mode": "SINGLE", "base_growth_days": 7, "regrow_cooldown": 0,
		"is_trellis": false, "giant_capable": false, "yield_min": 1, "yield_max": 1, "multi_seasonal": false, "seasons": [2]},
	WILD_SEORI_HONBAEK: {"name_ko": "서리혼백초", "stages": 2, "seed_cost": 40, "sell_price": 0,
		"growth_mode": "SINGLE", "base_growth_days": 7, "regrow_cooldown": 0,
		"is_trellis": false, "giant_capable": false, "yield_min": 1, "yield_max": 1, "multi_seasonal": false, "seasons": [3]},
}

# ── ★[S4-T5 / ADR-0062 결정 5 · ADR-0033 #4] 야생·혼합 작물(제작 씨앗 전용) ────
# 스타듀 Wild Seeds/Mixed Seeds의 나라카판. 셋 다 **ids()에 넣지 않는다** — ids()는 만물상 매대·표시
# 목록이고 이 씨앗들은 *제작·드랍 전용*이라 상점에 안 선다(획득 경로 분리가 곧 정체성).
#   - 야생 모둠 4종(절기별): 수확물이 작물 id가 아니라 **그 절기 저승 숲 일반종 3종 중 결정 롤 1종**
#     (main._try_harvest가 wild 분기에서 치환 — ADR-0033 #4 "밭에서 길러도 채집": XP·품질 전부 채집 축).
#   - 희소종 모종 4종: 미혹 희소종을 **주워 본 뒤에야**(종 발견 게이트) 씨앗을 제작해 재배한다.
#     수확물 = 그 희소종 단일(발견 정체성 보존 + 자급 양립).
#   - 혼합 씨앗: 심는 순간 그 절기 일반 작물로 **치환**된다(main이 파종 디스패치에서 롤 — 이 "honhap"
#     작물 자체는 심기지 않는 유령 엔트리다. 씨앗 아이템 파생("혼합 씨앗")과 has_crop 통과용).
#   - 심층 2종(불사과·저승삼)은 씨앗이 없다(재배 불가 — 불사과 재배는 S7 프레스티지 소관).
# 스키마 값은 기존 필드 그대로(하위호환 — 미지 필드 0). sell_price 0 = wild 분기가 가로채 직접 판매
# 경로가 없다는 표식(혹시 새 나가도 0냥이라 무해).
const MIXED := "honhap"                       # 혼합 씨앗("혼합 씨앗" = 파생 명명 그대로)
const WILD_PIAN := "yasaeng_pian"             # 야생 모둠(피안)
const WILD_YUHWA := "yasaeng_yuhwa"           # 야생 모둠(유화)
const WILD_MANGYEON := "yasaeng_mangyeon"     # 야생 모둠(망연)
const WILD_SEONGYA := "yasaeng_seongya"       # 야생 모둠(성야)
const WILD_MIHOK_NANCHO := "mihok_nancho_wild"      # 미혹난초 모종(재배)
const WILD_YURYEONGCHO := "yuryeongcho_wild"        # 유령초 모종
const WILD_MYEONGWOL := "myeongwol_beoseot_wild"    # 명월버섯 모종
const WILD_SEORI_HONBAEK := "seori_honbaekcho_wild" # 서리혼백초 모종

# wild 작물 부가 정보. kind: "season"=절기 모둠(수확 롤은 main이 ForageSpawns.species_for로) /
# "single"=희소종 단일(species = ItemCatalog 채집물 id 리터럴 — 클래스 참조 순환 회피용 문자열).
const WILD_INFO := {
	WILD_PIAN: {"kind": "season", "season": 0, "species": ""},
	WILD_YUHWA: {"kind": "season", "season": 1, "species": ""},
	WILD_MANGYEON: {"kind": "season", "season": 2, "species": ""},
	WILD_SEONGYA: {"kind": "season", "season": 3, "species": ""},
	WILD_MIHOK_NANCHO: {"kind": "single", "season": 0, "species": "mihok_nancho"},
	WILD_YURYEONGCHO: {"kind": "single", "season": 1, "species": "yuryeongcho"},
	WILD_MYEONGWOL: {"kind": "single", "season": 2, "species": "myeongwol_beoseot"},
	WILD_SEORI_HONBAEK: {"kind": "single", "season": 3, "species": "seori_honbaekcho"},
}

static func is_wild(id: String) -> bool:
	return WILD_INFO.has(id)

static func is_mixed(id: String) -> bool:
	return id == MIXED

# wild 작물의 절기 인덱스(-1 = wild 아님). "season"형의 수확 롤 풀 선택에 쓴다.
static func wild_season(id: String) -> int:
	return int(WILD_INFO[id]["season"]) if WILD_INFO.has(id) and WILD_INFO[id]["kind"] == "season" else -1

# wild 작물의 단일 종("" = 절기 모둠형/비-wild). 희소종 모종의 수확물이다.
static func wild_species(id: String) -> String:
	return String(WILD_INFO[id]["species"]) if WILD_INFO.has(id) else ""

# ── 조회(초판 표면 — 불변 계약) ────────────────────────────────────────────
# 작물 id 목록(성장 빠른 순). 카탈로그 정의 순서 = 표시·정렬 순서.
# ⚠️ wild·혼합 작물은 여기 없다(★S4-T5 — 매대·표시 목록 밖, 위 주석).
static func ids() -> Array:
	return [HONRYEONGCHO, PIANHWA, HWANGCHEON_PODO, YEONGHON_HOBAK, BULSAGWA]

static func has_crop(id: String) -> bool:
	return CATALOG.has(id)

# 작물 데이터(읽기 전용). 없는 id면 빈 Dictionary.
static func get_crop(id: String) -> Dictionary:
	return CATALOG.get(id, {})

# 표시명. 없는 id면 "".
static func name_of(id: String) -> String:
	return CATALOG[id]["name_ko"] if CATALOG.has(id) else ""

# 성장일수(초판 완료기준의 핵심 값). ★ base_growth_days의 얇은 별칭(§5.2).
# ⚠️ 없는 id면 -1 sentinel 엄수 — field.gd is_mature의 need>=0 계약(0 반환 시 조기수확 회귀).
static func growth_days(id: String) -> int:
	return CATALOG[id]["base_growth_days"] if CATALOG.has(id) else -1

# 씨앗 구매가. 없는 id면 -1.
static func seed_cost(id: String) -> int:
	return CATALOG[id]["seed_cost"] if CATALOG.has(id) else -1

# 수확물 판매가. 없는 id면 0(판매 합산에 안전).
static func sell_price(id: String) -> int:
	return CATALOG[id]["sell_price"] if CATALOG.has(id) else 0

# ── 조회(S1-4 신규 아키타입 표면 — S1-5/S1-6이 읽음) ──────────────────────
# 기존 관례대로 get_ 접두 없이. 없는 id는 SINGLE 그레이박스 기본값으로 폴백(안전).
static func growth_mode(id: String) -> String:
	return CATALOG[id]["growth_mode"] if CATALOG.has(id) else "SINGLE"

static func regrow_cooldown(id: String) -> int:
	return CATALOG[id]["regrow_cooldown"] if CATALOG.has(id) else 0

static func is_trellis(id: String) -> bool:
	return CATALOG[id]["is_trellis"] if CATALOG.has(id) else false

static func giant_capable(id: String) -> bool:
	return CATALOG[id]["giant_capable"] if CATALOG.has(id) else false

static func is_multi_seasonal(id: String) -> bool:
	return CATALOG[id]["multi_seasonal"] if CATALOG.has(id) else false

# ── ★[S7-T2 / ADR-0065 결정 2] 절기 표면(FishCatalog.seasons 조회 동형) ───────
# 이 작물의 재배 절기 인덱스 배열(빈 배열 = 사철). 없는 id면 빈 배열 = 사철로 떨어진다
# (미지 작물이 절기 전환에 조용히 사라지지 않는 안전 방향 — 사멸은 *명시된* 제철에만 근거한다).
static func seasons_of(id: String) -> Array:
	return CATALOG[id]["seasons"] if CATALOG.has(id) else []

# 이 작물을 이 절기에 기를 수 있나. **빈 배열 = 항상 true**(사철). 사멸 패스·만물상 제철 매대·
# 카페 메뉴 로테이션이 전부 이 하나를 읽는다(판정의 단일 출처 — FishCatalog.in_season 1:1).
static func in_season(id: String, season_idx: int) -> bool:
	var seasons: Array = seasons_of(id)
	return seasons.is_empty() or seasons.has(season_idx)

# 절기 표기 문자열("" = 사철). 만물상 매대 표시명이 씨앗 뒤에 붙인다("혼령초 씨앗 (유화절)").
# 이름의 주인이 GameClock(SEASON_NAMES 단일 출처)이라 여기선 잇기만 한다(문자열 중복 0).
static func season_label(id: String) -> String:
	var parts: Array = []
	for s in seasons_of(id):
		parts.append(GameClock.season_name(int(s)))
	return "·".join(parts)

# 수확 산출 범위(min,max). 없는 id면 (1,1). yield_max>1 = 다수확.
static func yield_range(id: String) -> Vector2i:
	if CATALOG.has(id):
		return Vector2i(CATALOG[id]["yield_min"], CATALOG[id]["yield_max"])
	return Vector2i(1, 1)
