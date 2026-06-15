extends RefCounted
class_name CropCatalog
# T2.2 — 저승 작물 3종 데이터 정의(혼령초 · 피안화 · 영혼 호박).
#
# 목적: ROADMAP T2.2 — 세 작물이 "데이터로" 정의되고, 성장일수가
#       빠름 < 중간 < 느림으로 구분되는지를 한 곳에서 보장한다.
#       (CONTEXT '저승 작물' 용어 그대로: 혼령초 / 피안화 / 영혼 호박.)
#
# 설계 메모:
#   - 이건 "정적 참조 데이터"다. 세이브 상태(밭 칸·날짜 등)가 아니라 카탈로그다.
#     그래서 clock.gd·field.gd처럼 씬 노드로 두지 않고, static const로 들고
#     class_name으로 어디서든 CropCatalog.get_crop("...")로 읽는다(오토로드 불필요).
#   - field.gd가 미리 연 훅(plant()의 crop_id 자리)과 맞물린다. T2.3 작물 성장은
#     이 growth_days를 GameClock.day_advanced 카운트와 비교해 단계를 올릴 것이다.
#     여기서는 "데이터만" 정의하고, 성장 로직·밭 연결은 T2.3에서 붙인다(범위 분리).
#   - 식별자(영문 id)와 표시명(name_ko)을 분리한다: id는 코드·세이브용(가볍고
#     안정적), name_ko는 화면 표시용. T2.5 세이브엔 영문 id만 저장하면 된다.
#   - seed_cost / sell_price는 ROADMAP 정의의 '저수익 / 고수익'을 데이터로 박은
#     값이다(빠름=저수익, 느림=고수익). 그레이박스 기준값이며 밸런싱은 후속.
#   - 속죄 테마(ADR-0004): 작물 양육은 미호(방화 → 작물 양육)의 영역이고,
#     작물명은 저승 세계관 용어를 따른다.

# 작물 식별자(영문 id) — 빠른 성장 순으로 둔다. ids()의 정렬 기준이자 세이브 키.
const HONRYEONGCHO := "honryeongcho"   # 혼령초
const PIANHWA := "pianhwa"             # 피안화
const YEONGHON_HOBAK := "yeonghon_hobak"  # 영혼 호박

# 카탈로그. 키 = 영문 id, 값 = 작물 데이터(아래 필드).
#   name_ko      : 화면 표시명(CONTEXT 용어)
#   growth_days  : 심은 날부터 다 자라기까지 걸리는 '날 수'(빠름 < 중간 < 느림) ★완료기준
#   stages       : 씨앗→수확 사이 시각 성장 단계 수(T2.3 비주얼 훅; 느린 작물일수록 많게)
#   seed_cost    : 씨앗 구매가(골드) — T3.1 경제
#   sell_price   : 수확물 판매가(골드) — 저수익 < 중간 < 고수익을 데이터로 표현
# 주의: const 중첩 Dictionary는 런타임에 변경 가능하니 읽기 전용으로 다룬다(수정 금지).
const CATALOG := {
	HONRYEONGCHO: {
		"name_ko": "혼령초",
		"growth_days": 3,    # 빠름
		"stages": 2,
		"seed_cost": 10,
		"sell_price": 20,    # 저수익(순익 +10)
	},
	PIANHWA: {
		"name_ko": "피안화",
		"growth_days": 5,    # 중간
		"stages": 3,
		"seed_cost": 25,
		"sell_price": 60,    # 중간(순익 +35)
	},
	YEONGHON_HOBAK: {
		"name_ko": "영혼 호박",
		"growth_days": 8,    # 느림
		"stages": 4,
		"seed_cost": 50,
		"sell_price": 160,   # 고수익(순익 +110)
	},
}

# ── 조회 ──────────────────────────────────────────────────────────────────
# 작물 id 목록(빠른 성장 순). 카탈로그 정의 순서 = 표시·정렬 순서.
static func ids() -> Array:
	return [HONRYEONGCHO, PIANHWA, YEONGHON_HOBAK]

static func has_crop(id: String) -> bool:
	return CATALOG.has(id)

# 작물 데이터(읽기 전용). 없는 id면 빈 Dictionary.
static func get_crop(id: String) -> Dictionary:
	return CATALOG.get(id, {})

# 표시명. 없는 id면 "".
static func name_of(id: String) -> String:
	return CATALOG[id]["name_ko"] if CATALOG.has(id) else ""

# 성장일수(완료기준의 핵심 값). 없는 id면 -1.
static func growth_days(id: String) -> int:
	return CATALOG[id]["growth_days"] if CATALOG.has(id) else -1
