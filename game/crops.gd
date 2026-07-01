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
	},
	BULSAGWA: {
		"name_ko": "불사과",
		"stages": 4,
		"seed_cost": 200,        # ⚠️ 채집 전용(만물상 미판매) — 카탈로그 균일성용 placeholder·미사용
		"sell_price": 100,       # 희소 프레스티지
		"growth_mode": "REGROW",
		"base_growth_days": 12,  # §2.3 고정
		"regrow_cooldown": 7,    # §2.3 손수 예외(공식 밖)
		"is_trellis": false,
		"giant_capable": false,
		"yield_min": 1,
		"yield_max": 1,
		"multi_seasonal": true,  # 다절기 프레스티지 — 절기 전환 사멸 제외
	},
}

# ── 조회(초판 표면 — 불변 계약) ────────────────────────────────────────────
# 작물 id 목록(성장 빠른 순). 카탈로그 정의 순서 = 표시·정렬 순서.
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

# 수확 산출 범위(min,max). 없는 id면 (1,1). yield_max>1 = 다수확.
static func yield_range(id: String) -> Vector2i:
	if CATALOG.has(id):
		return Vector2i(CATALOG[id]["yield_min"], CATALOG[id]["yield_max"])
	return Vector2i(1, 1)
