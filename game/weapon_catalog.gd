extends RefCounted
class_name WeaponCatalog
# ★[S5-T4 / ADR-0063 결정 5] 무기 로스터 — 검 단일 계열 5종(깊이 게이팅·길드 판매).
#
# 목적: "무엇을 들고 때리는가"(데미지 밴드·해금 깊이·가격·표시명)를 한 곳에 든다. GearCatalog가
#       낚시 기어의 단일 출처인 것과 **문법이 1:1**이다 — 순수 static 데이터 + 조회, ItemCatalog는
#       id 진실원 + 카테고리·판정만 위임해 온다(데이터 중복 0).
#
# 설계 메모(어기면 ADR-0063 결정 5 / ADR-0031 결정 7 위반):
#   - **검 계열만.** 단검·둔기 계열과 무기 특수동작(RMB — ADR-0024와 충돌하는 미결 입력 문제)은
#     장비 클러스터 서랍이다. 검 스윙 = LMB 호 판정 하나로 전투 코어가 완결된다.
#   - **무기 티어 ↔ 도구 티어는 완전 분리**(ADR-0031 결정 7). 무기는 *별개 아이템 5종*이고 ToolTier
#     원장에 한 줄도 안 들어간다(도구는 한 아이템의 티어 정수, 무기는 각자 다른 아이템 — 곡괭이를
#     업그레이드해도 검은 그대로고 그 역도 같다). 무기 강화(별도 축)는 서랍이다.
#   - **깊이가 유일한 해금 게이트**(`depth`). 관계·스킬 게이트 0(ADR-0031 결정 2 "채광 깊이 = 유일
#     게이트"·ADR-0008 "평평≠막힘"). base 실력으로 내려간 만큼 살 수 있다.
#   - **판매·증정은 여기 없다**: 길드 매대(무골)·첫 무기 증정은 S5-T6 소관이다. 이 파일은 값의
#     단일 출처일 뿐이고, 지금 손에 넣는 길은 디버그 지급(inventory.add_item)뿐이다
#     (GearCatalog가 T2~T4 낚싯대를 두고 같은 상태로 있었던 선례 동형).
#   - 데미지 밴드는 스타듀 검 5종 대응 1:1이고 **명명은 전부 잠정**(owner 큐 — ADR-0063 결정 5).

# ── 아이템 id(코드·세이브용 안정 id — ItemCatalog가 그대로 재수출) ────────────
const SWORD_RUSTY := "sword_rusty"                    # 녹슨 혼검(증정 — Rusty Sword 1:1)
const SWORD_MYEONGDONG := "sword_myeongdong"          # 명동검(깊이 10)
const SWORD_YUCHEOL := "sword_yucheol"                # 유철검(깊이 25)
const SWORD_HWANGCHEONGEUM := "sword_hwangcheongeum"  # 황천금검(깊이 40)
const SWORD_EOPHWADO := "sword_eophwado"              # 업화도(業火刀 — 깊이 60 · Lava Katana 1:1)

# ── 검 5종(ADR-0063 결정 5) ──────────────────────────────────────────────────
# 스키마:
#   name_ko  : 표시명(*명명 잠정* — 금속 로스터 ADR-0063 결정 2를 그대로 물려받는다)
#   tier     : 1~5(표시·정렬용. ★ToolTier의 0~4 축과는 무관한 별개 눈금)
#   dmg_min  : 데미지 밴드 하한 — 매 스윙 [min, max] 균등 롤(CombatSkill.resolve_hit)
#   dmg_max  : 데미지 밴드 상한
#   depth    : 해금 도달 깊이(0 = 무조건 — 녹슨 혼검은 길드 첫 방문 증정)
#   price    : 길드 매대가(냥). 0 = 비매(증정품)
#   color    : 그레이박스 아이콘 색(아이콘 아트 = S5-T10 — tool_color_of 폴백이 읽는다)
# 밸런스 의도: 한 축(데미지 밴드)만 오르는 순수 계단이다. 낚싯대 4티어가 체급·슬롯 두 축을 갈랐던
#   것과 달리 검은 **밴드 하나**만 갖는다 — 특수동작·리치·속도가 전부 서랍이라 다른 축이 없기
#   때문이고, 그게 곧 "검 하나로 전투 코어가 완결된다"의 대가다(ADR-0063 결정 5).
#   밴드 폭이 티어마다 다른 것(3 → 7 → 13 → 18 → 9)은 스타듀 원본의 결이다: 중간 티어는 분산이
#   커서 "운"이 느껴지고, 엔드게임 업화도는 좁고 높아 **안정적으로** 센다.
const SWORDS := {
	SWORD_RUSTY: {
		"name_ko": "녹슨 혼검", "tier": 1, "dmg_min": 2, "dmg_max": 5,
		"depth": 0, "price": 0,
		"color": Color(0.52, 0.44, 0.36),        # 녹슨 무쇠 — 흙빛 붉은 녹
	},
	SWORD_MYEONGDONG: {
		"name_ko": "명동검", "tier": 2, "dmg_min": 8, "dmg_max": 15,
		"depth": 10, "price": 750,
		"color": Color(0.78, 0.44, 0.28),        # 명동(冥銅) — 붉은 구리(광물 색 정합)
	},
	SWORD_YUCHEOL: {
		"name_ko": "유철검", "tier": 3, "dmg_min": 12, "dmg_max": 25,
		"depth": 25, "price": 2000,
		"color": Color(0.58, 0.62, 0.70),        # 유철(幽鐵) — 푸른 강철
	},
	SWORD_HWANGCHEONGEUM: {
		"name_ko": "황천금검", "tier": 4, "dmg_min": 28, "dmg_max": 46,
		"depth": 40, "price": 9000,
		"color": Color(0.90, 0.75, 0.30),        # 황천금(黃泉金) — 황금
	},
	SWORD_EOPHWADO: {
		"name_ko": "업화도", "tier": 5, "dmg_min": 55, "dmg_max": 64,
		"depth": 60, "price": 25000,
		"color": Color(0.86, 0.38, 0.22),        # 업화(業火) — 달군 칼날의 불빛
	},
}

# 티어 순 id 목록(매대 행·테스트 순회의 단일 출처 — dict 삽입 순서를 신뢰하지 않는다).
const _ORDER := [SWORD_RUSTY, SWORD_MYEONGDONG, SWORD_YUCHEOL, SWORD_HWANGCHEONGEUM, SWORD_EOPHWADO]

# ── 판정·조회(ItemCatalog가 위임해 쓴다) ─────────────────────────────────────
static func is_sword(id: String) -> bool:
	return SWORDS.has(id)

# 무기 통칭 판정(지금은 검 계열뿐 — 계열이 늘면 여기서 or로 합친다. GearCatalog.has 동형).
static func has(id: String) -> bool:
	return is_sword(id)

static func ids() -> Array:
	return _ORDER

static func name_of(id: String) -> String:
	return String(SWORDS[id]["name_ko"]) if has(id) else ""

# 길드 매대가(냥). ★파는 곳은 S5-T6 무골 매대 — 여기는 값의 단일 출처일 뿐이다.
static func price_of(id: String) -> int:
	return int(SWORDS[id]["price"]) if has(id) else 0

# 그레이박스 아이콘 색(아트 = S5-T10). 도구 색박스 폴백(tool_color_of)이 읽는다.
static func color_of(id: String) -> Color:
	return SWORDS[id]["color"] if has(id) else Color.WHITE

# 스택 가능한가 — 무기는 전부 유니크 장착물(도구·낚싯대 결). 항상 false.
static func stackable_of(_id: String) -> bool:
	return false

static func tier_of(id: String) -> int:
	return int(SWORDS[id]["tier"]) if has(id) else 0

# 해금 도달 깊이(0 = 무조건). 매대 게이팅의 단일 출처 — main은 mine_floors 최심층만 넘긴다.
static func depth_of(id: String) -> int:
	return int(SWORDS[id]["depth"]) if has(id) else 0

static func damage_min(id: String) -> int:
	return int(SWORDS[id]["dmg_min"]) if has(id) else 0

static func damage_max(id: String) -> int:
	return int(SWORDS[id]["dmg_max"]) if has(id) else 0

# "2-5" 같은 표시 문자열(매대 행·툴팁 한 줄).
static func damage_band(id: String) -> String:
	return "%d-%d" % [damage_min(id), damage_max(id)] if has(id) else ""

# 이 도달 깊이에서 살 수 있나(증정품 녹슨 혼검은 depth 0이라 늘 true — 매대 노출 여부는 T6가 정한다).
static func unlocked(id: String, reached_depth: int) -> bool:
	return has(id) and reached_depth >= depth_of(id)

# 이 도달 깊이에서 해금된 무기 id 목록(티어 순). ★S5-T6 길드 매대가 그대로 행으로 그린다.
static func unlocked_ids(reached_depth: int) -> Array:
	var out: Array = []
	for id: String in _ORDER:
		if unlocked(id, reached_depth):
			out.append(id)
	return out

# 이 밴드에서 한 대 값(균등 롤). ★크리·퍼크는 CombatSkill이 얹는다 — 여기선 순수 밴드만.
#   rng를 **인자로 받는다**: 시드 소유·순차 소비 순서가 판정 쪽(CombatSkill.resolve_hit)의 책임이라
#   카탈로그가 자체 RNG를 만들면 그 규율이 두 곳으로 갈린다.
static func roll_damage(id: String, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(damage_min(id), damage_max(id)) if has(id) else 0
