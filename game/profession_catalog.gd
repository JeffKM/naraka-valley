extends RefCounted
class_name ProfessionCatalog
# ADR-0052 — 활동 스킬 5종 전문직 트리(비-가치 차원 한정) 순수 규칙·데이터.
#
# 목적: ADR-0052 로스터를 한 곳에 데이터로 잠근다. FarmSkill(XP 곡선)과 같은 결 —
#       무상태 static 함수만, 전문직 *선택 상태*(어느 걸 골랐나)는 main이 스칼라 dict로
#       들고(_professions) 저장한다(FarmSkill↔_farming_xp 관계와 동일).
#
# 구조: 스킬당 lvl5 2갈래 → lvl10 각 2분기(총 6전문직). tier10은 requires=부모 lvl5 id.
#       퍼크 = 비-가치 4차원(품질·수량·효율·편의)만. +판매가/마진은 관계 곱셈기 전용이라
#       *여기 없음*(ADR-0052 §1 — 숫자 슬롯 분리). 로더(loop)가 _perk_value로 읽어 base 위에 얹는다.
#
# ★그레이박스 범위(2026-07-05): 채집(FORAGING)이 파일럿 — 퍼크 시맨틱 완비. 나머지 4스킬은
#   트리 *구조*(id·이름·tier·requires·설명)만 잠그고 perks=[](각 스킬 빌드 슬라이스에서 채움).
#   프레임워크가 5스킬에 일반적임을 증명하되 투기적 수치는 미리 안 박는다("한 시스템씩").
#   ★갱신(2026-07-27 · S3-T6 / ADR-0061 결정 6): **낚시(FISHING) 퍼크 완비** — 예고대로 그 스킬의
#   빌드 슬라이스에서 채웠다("각 스킬 빌드 슬라이스에서 채움" 이행). 남은 구조-only = 농사·채광·전투 3.

# ── 스킬 id ───────────────────────────────────────────────────────────────────
const FARMING := "farming"
const FORAGING := "foraging"
const MINING := "mining"
const FISHING := "fishing"
const COMBAT := "combat"
const SKILLS := [FARMING, FORAGING, MINING, FISHING, COMBAT]

# ── 퍼크 차원(비-가치 4차원, ADR-0052 §1) — 문자열 키(조회·세이브 안정) ──────────────
const DIM_QUALITY_FLOOR := "quality_floor"  # 품질: 산출물 등급 하한(약초학자 → Q_IRIDIUM=3)
const DIM_DOUBLE_DROP := "double_drop"      # 수량: 2배 드롭 확률(0..1)
const DIM_WOOD_BONUS := "wood_bonus"        # 수량: 벌목 원목 +N
const DIM_HARDWOOD := "hardwood"            # 자원: 모든 나무 단단한 원목 확률(flag=1)
const DIM_TAP_QUALITY := "tap_quality"      # 품질: 수액 등급↑(flag=1)
const DIM_DETECT := "detect"               # 편의: 채집물 감지 범위(flag/range)
const DIM_TRACK := "track"                 # 발견: 채집물 위치 화면 표시(flag=1)
# ── ★[S3-T6 / ADR-0061 결정 6] 낚시 퍼크 차원 6종 ─────────────────────────────
# 전부 비-가치 4차원 안에 든다(품질·수량·효율·편의) — +판매가/마진은 여기 없다(ADR-0052 §1).
const DIM_FISH_QUALITY := "fish_quality"       # 품질: 어획 등급 판정 축 상향(0..1 — 퀄리티 보버와 같은 눈금)
const DIM_FISH_TOP_QUALITY := "fish_top_quality"  # 품질: 최고 등급(이리듐) 확률 포인트(퍼펙트 2회 게이트 보존)
const DIM_SALVAGE_DOUBLE := "salvage_double"   # 수량: 인양물 동반 롤 확률 2배(flag=1 — ADR-0061 보물잡이 재해석)
const DIM_TRAP_SAVE := "trap_save"             # 효율: 게잡이통 자원/미끼 소모↓(0..1 비율) ★S3-T7 소비
const DIM_TRAP_NO_JUNK := "trap_no_junk"       # 품질: 게잡이통에 잡동사니 안 걸림(flag=1) ★S3-T7 소비
const DIM_TRAP_NO_BAIT := "trap_no_bait"       # 편의: 게잡이통 미끼 불필요(flag=1) ★S3-T7 소비

# ── 트리 데이터: 스킬 → [전문직...] ────────────────────────────────────────────────
# profession = {id, tier(5/10), requires(tier10만=부모 lvl5 id / tier5=""), name, desc, perks:[{dim,value}]}
const _TREE := {
	# ── 채집(파일럿, 퍼크 완비 — ADR-0052 §채집) ──────────────────────────────
	FORAGING: [
		{"id": "detector", "tier": 5, "requires": "", "name": "감지자",
			"desc": "혼 감지 범위↑ + 벌목 원목 +1",
			"perks": [{"dim": DIM_DETECT, "value": 1.0}, {"dim": DIM_WOOD_BONUS, "value": 1.0}]},
		{"id": "gatherer", "tier": 5, "requires": "", "name": "채집꾼",
			"desc": "채집물 20% 확률 2배",
			"perks": [{"dim": DIM_DOUBLE_DROP, "value": 0.20}]},
		{"id": "lumberjack", "tier": 10, "requires": "detector", "name": "벌목꾼",
			"desc": "모든 나무에서 단단한 원목 확률",
			"perks": [{"dim": DIM_HARDWOOD, "value": 1.0}]},
		{"id": "tapper", "tier": 10, "requires": "detector", "name": "수액꾼",
			"desc": "수액 품질 등급↑ + 채취 주기 단축",
			"perks": [{"dim": DIM_TAP_QUALITY, "value": 1.0}]},
		{"id": "botanist", "tier": 10, "requires": "gatherer", "name": "약초학자",
			"desc": "모든 채집물 최고 등급(이리듐) 고정",
			"perks": [{"dim": DIM_QUALITY_FLOOR, "value": 3.0}]},
		{"id": "tracker", "tier": 10, "requires": "gatherer", "name": "추적자",
			"desc": "채집물 위치 화면 표시",
			"perks": [{"dim": DIM_TRACK, "value": 1.0}]},
	],
	# ── 농사(구조만·퍼크 후행 — 각 스킬 슬라이스에서 시맨틱 인코딩) ──────────────
	FARMING: [
		{"id": "tiller", "tier": 5, "requires": "", "name": "경작자", "desc": "작물 품질 등급 확률↑", "perks": []},
		{"id": "rancher", "tier": 5, "requires": "", "name": "목축가", "desc": "축산물 품질 등급↑", "perks": []},
		{"id": "artisan", "tier": 10, "requires": "tiller", "name": "장인", "desc": "가공품 품질 등급↑ + 가공 속도↑", "perks": []},
		{"id": "agriculturist", "tier": 10, "requires": "tiller", "name": "재배가", "desc": "작물 성장 10% 빠름", "perks": []},
		{"id": "coopmaster", "tier": 10, "requires": "rancher", "name": "둥우리지기", "desc": "가축 우정 가속 + 부화 시간 절반", "perks": []},
		{"id": "shepherd", "tier": 10, "requires": "rancher", "name": "목자", "desc": "가축 우정 가속 + 산물 주기 단축", "perks": []},
	],
	# ── 채광(구조만) ──────────────────────────────────────────────────────────
	MINING: [
		{"id": "miner", "tier": 5, "requires": "", "name": "광부", "desc": "광맥당 광석 +1", "perks": []},
		{"id": "geologist", "tier": 5, "requires": "", "name": "지질사", "desc": "보석이 쌍으로 나올 확률", "perks": []},
		{"id": "blacksmith", "tier": 10, "requires": "miner", "name": "제련공", "desc": "제련 시간↓ + 잉곳 품질 티어", "perks": []},
		{"id": "prospector", "tier": 10, "requires": "miner", "name": "탐광자", "desc": "석탄/혼탄 2배 확률", "perks": []},
		{"id": "excavator", "tier": 10, "requires": "geologist", "name": "발굴자", "desc": "지오드 2배 확률", "perks": []},
		{"id": "gemologist", "tier": 10, "requires": "geologist", "name": "보석사", "desc": "보석 품질 등급↑", "perks": []},
	],
	# ── ★[S3-T6 / ADR-0061 결정 6] 낚시(퍼크 완비 — 채집에 이은 두 번째 실효 트리) ──────
	# 낚시꾼 갈래 = **릴 격투 산출물**(품질·인양) · 덫꾼 갈래 = **게잡이통**(패시브 어획, ★S3-T7 실배선).
	# 후자 3종은 여기서 *퍼크 메타데이터만* 잠근다 — 게잡이통이 아직 없어 소비처가 없기 때문이고,
	# S3-T7이 `has_profession(FISHING,"trapper")`/`_perk_value(...DIM_TRAP_*)`로 그대로 읽어 간다.
	FISHING: [
		{"id": "fisher", "tier": 5, "requires": "", "name": "낚시꾼",
			"desc": "어획 품질 등급 확률↑",
			# 판정 축을 +0.10 위로(퀄리티 보버 0.15와 같은 눈금 = 계단 반 칸 — 품질의 주인은 여전히 퍼펙트 릴).
			"perks": [{"dim": DIM_FISH_QUALITY, "value": 0.10}]},
		{"id": "trapper", "tier": 5, "requires": "", "name": "덫꾼",
			"desc": "게잡이통 자원/미끼 소모↓",
			"perks": [{"dim": DIM_TRAP_SAVE, "value": 0.50}]},   # ★S3-T7 소비(소모 −50% 잠정)
		{"id": "angler", "tier": 10, "requires": "fisher", "name": "명조사",
			"desc": "최고 등급 어획 확률 대폭↑",
			# 이리듐 몫 +20포인트(퍼펙트 2회 = 5%→25% · 3회 = 15%→35%). 퍼펙트 게이트는 그대로.
			"perks": [{"dim": DIM_FISH_TOP_QUALITY, "value": 20.0}]},
		{"id": "pirate", "tier": 10, "requires": "fisher", "name": "보물잡이",
			"desc": "포획 시 인양물 확률 2배",   # ★ADR-0061 결정 6 재해석(옛 "보물 상자" 표현 폐기)
			"perks": [{"dim": DIM_SALVAGE_DOUBLE, "value": 1.0}]},
		{"id": "mariner", "tier": 10, "requires": "trapper", "name": "뱃사람",
			"desc": "게잡이통에 잡동사니 안 걸림",
			"perks": [{"dim": DIM_TRAP_NO_JUNK, "value": 1.0}]},   # ★S3-T7 소비
		{"id": "luremaster", "tier": 10, "requires": "trapper", "name": "미끼장인",
			"desc": "게잡이통 미끼 불필요",
			"perks": [{"dim": DIM_TRAP_NO_BAIT, "value": 1.0}]},   # ★S3-T7 소비
	],
	# ── 전투(구조만) ──────────────────────────────────────────────────────────
	COMBAT: [
		{"id": "fighter", "tier": 5, "requires": "", "name": "투사", "desc": "피해 +10% + 최대 체력 +15", "perks": []},
		{"id": "scout", "tier": 5, "requires": "", "name": "척후", "desc": "크리 확률 +50%", "perks": []},
		{"id": "brute", "tier": 10, "requires": "fighter", "name": "광전사", "desc": "피해 +15%", "perks": []},
		{"id": "defender", "tier": 10, "requires": "fighter", "name": "수호자", "desc": "최대 체력 +25", "perks": []},
		{"id": "acrobat", "tier": 10, "requires": "scout", "name": "곡예사", "desc": "특수기 쿨다운 −50%", "perks": []},
		{"id": "desperado", "tier": 10, "requires": "scout", "name": "결사", "desc": "크리 위력↑", "perks": []},
	],
}

# ── 조회(무상태) ──────────────────────────────────────────────────────────────
# 스킬의 전 전문직 목록(dict 배열). 미지 스킬은 빈 배열.
static func professions_for(skill: String) -> Array:
	return _TREE.get(skill, [])

# 스킬 skill·tier(5/10)의 전문직만.
static func tier_profs(skill: String, tier: int) -> Array:
	var out: Array = []
	for p in professions_for(skill):
		if int(p["tier"]) == tier:
			out.append(p)
	return out

# (skill,id) 전문직 dict — 없으면 빈 dict.
static func get_prof(skill: String, id: String) -> Dictionary:
	for p in professions_for(skill):
		if p["id"] == id:
			return p
	return {}

static func is_valid(skill: String, id: String) -> bool:
	return not get_prof(skill, id).is_empty()

static func tier_of(skill: String, id: String) -> int:
	var p := get_prof(skill, id)
	return int(p.get("tier", 0))

# tier10 전문직의 선행 lvl5 부모 id(tier5·미지는 "").
static func requires_of(skill: String, id: String) -> String:
	return String(get_prof(skill, id).get("requires", ""))

static func name_of(skill: String, id: String) -> String:
	return String(get_prof(skill, id).get("name", id))

static func desc_of(skill: String, id: String) -> String:
	return String(get_prof(skill, id).get("desc", ""))

static func perks_of(skill: String, id: String) -> Array:
	return get_prof(skill, id).get("perks", [])
