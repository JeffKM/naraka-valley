extends RefCounted
class_name ToolTier
# ★[S4-T4 / ADR-0062 결정 6 → S5-T3 / ADR-0063 결정 3 정식화] 도구 티어 코어 —
# "지금 어느 도구가 몇 티어인가" + "그 티어가 무엇을 바꾸나"를 소유하는 얇은 원장.
#
# ── ★[S5-T3] 개정 요지(ADR-0063 결정 3이 ADR-0062 결정 6의 잠정을 대체한다) ──────────
#   ㉠ **MAX_TIER 2 → 4**: 금속 4티어(명동·유철·황천금·나락철)가 곧 도구 4티어다.
#   ㉡ **전 도구 4티어 실효**: 도끼만 열려 있던 계단이 곡괭이·괭이·물뿌리개로 넓어진다
#      (ADR-0027 "도구 티어 = 범위·접근·용량"의 실배치 — S4에서 이연됐던 그 자리다).
#   ㉢ **재료 = 골드 + 해당 주괴 5개**(스타듀 1:1). ADR-0062의 "골드 단독(잠정)"을 대체한다.
#      ★**소급 없음**: 이미 산 티어(도끼 1·2)는 그대로 남고, *다음* 계단부터 주괴를 요구한다.
#        원장이 티어 정수만 들고 "무엇으로 샀나"를 기억하지 않으므로 이 성질은 구조적으로 공짜다.
#   ㉣ 티어 효과가 도구마다 갈린다: 도끼=타수·큰 장애물 / 곡괭이=타수·큰 바위 / 괭이=AoE /
#      물뿌리개=AoE + 용량. **혼력 감산은 여전히 여기 없다**(스킬 축 — ADR-0027 경계 불변).
#
# 목적: ADR-0027("도구 티어 = 범위·접근·용량 / 스킬 = 효율")이 코드에 처음 존재하게 한다. ADR-0062
#       결정 6이 그 무대(업화 대장간)를 Slice 5에서 앞당긴 이유는 하나다 — 미혹 심층 구획(결정 1 ㉡)이
#       도끼 티어에 의존하는데 그게 다음 슬라이스에 인질로 잡혀 있었다.
#
# 왜 별개 파일인가(TreeLedger/ForageSpawns/CrabPotLedger 동형 완전 분리):
#   - 티어는 **플레이어 세이브 상태**지만 규칙(가격·명칭·타수·게이트)은 정적 데이터다. 이 파일이
#     둘을 한 곳에 들고, 인벤토리·지갑·혼력·나무 원장·UI를 하나도 모른다. 골드 차감은 main이 하고
#     (Wallet), 큰 장애물 게이트 판정은 TreeLedger가 `required_tier`로 *질의*만 한다.
#   - **RefCounted(비-Node)**: 설치물이 아니라 순수 데이터라 씬 트리에 설 이유가 없다.
#
# 설계 메모(어기면 ADR-0027 / ADR-0062 결정 6 위반):
#   - **접근 게이트는 *경제* 게이트다.** 관계·스킬 게이트가 아니다 — 냥만 모으면 누구나 산다
#     (ADR-0008 "평평≠막힘"의 도구판). 순차 강제(0→1→2)는 *가격 계단*이지 잠금이 아니다.
#   - **기본 벌목은 0티어에서도 된다.** 티어가 막는 건 *큰 장애물*(큰 그루터기·큰 통나무)뿐이고,
#     보통 나무는 0티어로 (느려도) 전부 벨 수 있다(ADR-0027 불변).
#   - **전 도구 4티어 실효(★S5-T3)**. 계단 데이터는 도구별 배열이 아니라 **티어 축 하나**에서
#     파생된다(가격·주괴·접두사가 도구를 안 가린다 — 스타듀도 네 도구가 같은 가격표를 쓴다).
#     도구마다 갈리는 건 *효과*뿐이고, 그건 아래 효과 절이 도구별 배열로 든다.
#   - **재료 = 골드 + 주괴 5(★S5-T3)**. 다만 이 원장은 **지갑도 인벤토리도 모른다** — 계단이
#     "무엇이 얼마나 필요한지"를 데이터로 알려주고, 있는지 보고 차감하는 건 main의 몫이다.
#   - 이 파일엔 무작위가 없다(전 판정 결정적) — 헤드리스가 정확히 재현한다.

signal changed()   # 티어가 오른 프레임(main이 듣고 프롬프트·타수 표시를 갱신)

# ── 도구 축(4종 — ★S5-T3에서 전부 실효) ────────────────────────────────────
const AXE := "axe"
const PICKAXE := "pickaxe"
const HOE := "hoe"
const WATERING_CAN := "watering_can"
const TOOLS := [AXE, PICKAXE, HOE, WATERING_CAN]

# ── 티어 상한(★S5-T3: 2 → 4. 금속 4티어와 1:1) ──────────────────────────────
const MAX_TIER := 4

# ── 티어 계단(★S5-T3 — 네 도구가 같은 가격·재료표를 쓴다) ────────────────────
# 티어 0 = 기본 도구(시작 지급) · 1 = 명동(冥銅) · 2 = 유철(幽鐵) · 3 = 황천금(黃泉金) ·
# 4 = 나락철(奈落鐵). 명명은 금속 로스터(ADR-0063 결정 2)를 그대로 물려받는다.
# ★ 순차 업그레이드: 0→2 직행 없음. 25,000냥을 들고 있어도 명동부터 거친다(가격 계단 = 경제 곡선).
# ★ 가격·주괴 수량은 스타듀 1:1(2,000/5,000/10,000/25,000 + 각 티어 주괴 5개).
const TIER_PREFIXES := ["", "명동", "유철", "황천금", "나락철"]
const TIER_PRICES := [0, 2000, 5000, 10000, 25000]
const INGOT_PER_UPGRADE := 5
# 티어 → 요구 주괴 아이템 id(티어 0은 없음). ItemCatalog가 이름·가격의 단일 출처다.
const TIER_INGOTS := ["", ItemCatalog.INGOT_MYEONGDONG, ItemCatalog.INGOT_YUCHEOL,
	ItemCatalog.INGOT_HWANGCHEONGEUM, ItemCatalog.INGOT_NARAKCHEOL]

# ── 도끼 티어 효과 ①: 성숙목 타수(스타듀 상속 — 10/8/6/5/4타) ────────────────
# TreeLedger.HP_MATURE(10)와 [0]이 반드시 같아야 한다(tool_tier_test ③이 단언).
# ★[S5-T3] 상위 2티어(5/4타)는 *잠정*이다 — 6타에서 등차를 유지하면 3타가 되어 벌목이 거의
#   즉발이 된다. 감산 폭을 줄여(−1/−1) 곡선을 눕혔다(owner 큐).
const AXE_MATURE_HP := [10, 8, 6, 5, 4]

# ── 도끼 티어 효과 ②: 큰 장애물 접근 게이트(ADR-0033 "특수 채집지만 도끼 티어로 접근") ──
# ★ 의존 방향은 **한쪽뿐**이다: TreeLedger가 이 두 수치를 참조하고(종 id → 요구 티어), 이 파일은
#   TreeLedger를 모른다. 서로 참조하면 GDScript 순환 참조라 파싱이 깨진다.
const TIER_LARGE_STUMP := 1   # 큰 그루터기 = 명동 도끼(스타듀 구리 도끼 Large Stump 1:1)
const TIER_LARGE_LOG := 2     # 큰 통나무 = 유철 도끼(스타듀 강철 도끼 Large Log 1:1)

# ── ★[S5-T3] 곡괭이 티어 효과 ①: 광맥 타수 감산 ─────────────────────────────
# 도끼:성숙목과 **정확히 같은 자리**다 — 여기가 규칙표의 단일 출처이고, `MineFloors.node_hits`가
# 이 두 함수만 참조한다(수치 복제 0·배선 손질 0. TreeLedger.hp_for_stage 선례 동형).
# ★ [0]이 MineFloors.ORE_HITS(3)·GEM_HITS(5)와 반드시 같아야 한다(tool_tier_test ⑨가 단언).
# ★ 감산 폭(*잠정* — owner 큐): 광석 3→2→2→1→1 · 보석/지오드 5→4→3→2→1. 같은 티어가 두 번
#   같은 값인 구간을 남긴 이유는 "1타(즉발)에 너무 빨리 닿으면 광맥과 일반 돌의 질감이 같아진다"
#   — 다타수가 곧 광맥의 정체성이라 바닥을 1로 두고 계단을 눕혔다.
# ★[폴리시 R10] **최고 티어의 실효 이득 0을 봉합**했다(옛 보석 표 [5,4,3,2,2]). 곡괭이 티어가
#   바꾸는 축은 이 두 표와 아래 `TIER_LARGE_BOULDER`뿐인데, 옛 표에서는 티어 3→4가 광석 1==1 ·
#   보석 2==2 · 바위 게이트(이미 티어 2에서 열림)라 **셋 다 그대로**였다 — 25,000냥 + 나락철 주괴 5,
#   게임에서 가장 비싼 업그레이드가 아무것도 바꾸지 않았다. 폴리시 2회차가 옛 `HOE_AOE`
#   [1×1, 1×1, 1×3, 1×3, 3×3]의 같은 결함(명동 괭이 이득 0)을 단조 사다리로 교정한 그 판정을
#   여기 그대로 적용한다.
# ★ 왜 광석이 아니라 보석 축인가 — 광석은 티어 3에서 이미 바닥(1타)이라 더 깎을 자리가 **구조적으로**
#   없다(0타 = 안 쳐도 캐진다). 그래서 나락철의 이득은 "가장 단단한 것(보석·지오드)까지 즉발"이
#   되고, 이는 광석이 티어 3에서 받은 것과 같은 계단이다(스타듀 이리듐 곡괭이 정합).
# ★ 일반 돌(node_id "")은 티어 무관 1타다 — 이미 즉발이라 깎을 게 없다.
const PICK_ORE_HITS := [3, 2, 2, 1, 1]
const PICK_GEM_HITS := [5, 4, 3, 2, 1]

# ── ★[S5-T3] 곡괭이 티어 효과 ②: 큰 바위 접근 게이트(도끼 큰 장애물 문법 동형) ──
# 갱도의 **큰 바위**(스타듀 Boulder 1:1 — 유철 곡괭이로만 깨지는 통행 차단물). 아트·배치는
# S5-T9/후속 소관이라 지금은 **게이트 함수만** 존재한다(죽은 코드 아님 — 층 배치가 큰 바위를
# 깔기 시작하면 `MineFloors`가 이 상수를 읽으면 끝이다. TIER_LARGE_LOG와 같은 자리).
const TIER_LARGE_BOULDER := 2

# ── ★[S5-T3] 괭이·물뿌리개 티어 효과: AoE(ADR-0027 "범위" 축의 실배치) ───────
# 값 = Vector2i(폭, 길이). (1,1) = 조준 칸 하나 · (1,N) = 바라보는 방향으로 N칸 일렬 ·
# (3,3) = 조준 칸을 중심으로 한 3×3. ADR-0063 결정 3의 "1×1→1×3→3×3"이 이 표의 척추다.
#
# ★[폴리시 2회차] **단조 사다리로 교정**(옛 표 = [1×1, 1×1, 1×3, 1×3, 3×3]). 옛 표는 티어 1과
#   티어 3이 바로 아래 티어와 같은 범위라, 명동 괭이(2,000냥 + 주괴 5)의 실효 이득이 **정확히 0**
#   이었다(그 자리에 "★owner 큐 1순위 재검토"가 박혀 있었다). 이제 다섯 티어가 전부 늘어난다:
#     1칸 → 3칸 → 5칸 → 7칸 → 9칸(3×3)
# ★ 왜 (1,5)·(1,7)인가 — **표현 형식을 하나도 안 늘린 유일한 단조 해**다. `_tool_aoe_tiles`의
#   형태 어휘는 ㉠1칸 ㉡폭 1의 일렬(길이 자유) ㉢정사각(홀수)뿐이고, 사각 분기는 *바라보는 방향을
#   안 본다*(항상 x폭·y길이). 그래서 3×5 같은 비정사각을 넣으면 옆을 볼 때 길이축이 엉킨다 —
#   새 형태를 발명하지 않는 선에서 중간 눈금은 "더 긴 일렬"뿐이다. 스타듀도 1×3→1×5로 줄부터
#   늘린 뒤 사각으로 넘어간다(우리는 티어가 하나 더 많아 1×7이 한 칸 더 낀다).
# ★ 마지막 계단이 7칸→9칸으로 폭이 좁은 건 **의도**다: 늘어난 칸 수보다 "줄에서 판으로" 바뀌는
#   형태 변화(정렬이 필요 없어진다)가 나락철의 실효 이득이다.
const HOE_AOE := [Vector2i(1, 1), Vector2i(1, 3), Vector2i(1, 5), Vector2i(1, 7), Vector2i(3, 3)]
const CAN_AOE := [Vector2i(1, 1), Vector2i(1, 3), Vector2i(1, 5), Vector2i(1, 7), Vector2i(3, 3)]

# ── ★[S5-T3] 물뿌리개 티어 효과: 용량(ADR-0059 결정 4 유한 물 축의 티어 배선) ──
# [0] = 20은 **기존 구현값**(main._CAN_CAPACITY)이라 0티어 거동이 픽셀 단위로 불변이다.
# ★ 상위 계단(*잠정* — owner 큐): 스타듀 40/55/70/85/100의 *증분 비율*을 20 기준에 얹었다.
#   3×3(9칸)에 닿는 4티어에서 70/9 ≈ 7.7회라 "한 통으로 밭 한 판"이 성립한다.
# ★[폴리시 2회차] AoE 사다리를 단조로 교정한 뒤(1/3/5/7/9칸) 이 표와의 정합이 **더 좋아졌다** —
#   한 통으로 적시는 *횟수*가 20 / 10 / 8 / 7.8 / 7.7회로 티어 내내 8회 언저리에 머물고, 한 통이
#   덮는 *총 칸 수*만 20→30→40→55→70으로 오른다. 위 4티어 근거가 계단 전체로 넓어진 셈이다.
const CAN_CAPACITY := [20, 30, 40, 55, 70]

# 티어 상태. { tool(String) → int }. 전 도구 키를 미리 잡아 둔다(예약 = 세이브 스키마 고정).
var _tiers: Dictionary = {}

func _init() -> void:
	for tool_id: String in TOOLS:
		_tiers[tool_id] = 0

# ── 정적 규칙 ───────────────────────────────────────────────────────────────
# 이 도구에 업그레이드 경로가 있나(★S5-T3 = 도구 4종 전부. 미지 id만 false).
static func is_upgradable(tool_id: String) -> bool:
	return tool_id in TOOLS

# 이 도구의 업그레이드 계단 전체(없으면 빈 배열). 티어 축 하나에서 파생한다 —
# {tier, name, price, ingot, ingot_count}. main·테스트·프롬프트의 단일 출처다.
static func upgrades_for(tool_id: String) -> Array:
	if not is_upgradable(tool_id):
		return []
	var out: Array = []
	for t in range(1, MAX_TIER + 1):
		out.append({"tier": t, "name": tier_name(tool_id, t), "price": int(TIER_PRICES[t]),
			"ingot": String(TIER_INGOTS[t]), "ingot_count": INGOT_PER_UPGRADE})
	return out

# 이 도구·이 티어에서 *다음* 계단({} = 더 없음 = 최고 티어). 무대(대장간)와 테스트의 단일 출처.
static func next_upgrade(tool_id: String, tier: int) -> Dictionary:
	for u in upgrades_for(tool_id):
		if int(u["tier"]) == tier + 1:
			return u
	return {}

# 티어 이름("도끼" / "명동 도끼" / … / "나락철 물뿌리개"). 기본 명칭은 ItemCatalog가 단일 출처다
# (도구 표시명을 두 곳에 두지 않는다 — 개명하면 티어 이름이 저절로 따라온다).
static func tier_name(tool_id: String, tier: int) -> String:
	var base := ItemCatalog.name_of(tool_id)
	var pre := String(TIER_PREFIXES[clampi(tier, 0, TIER_PREFIXES.size() - 1)])
	return base if pre == "" or base == "" else "%s %s" % [pre, base]

# 성숙목 타수(도끼 티어 → 10/8/6/5/4). TreeLedger.hp_for_stage가 이 한 줄만 참조한다(수치 복제 0).
static func axe_mature_hp(tier: int) -> int:
	return int(AXE_MATURE_HP[clampi(tier, 0, AXE_MATURE_HP.size() - 1)])

# ★[S5-T3] 광맥 타수(곡괭이 티어 → 3/2/2/1/1). MineFloors.node_hits가 이 한 줄만 참조한다.
static func pickaxe_ore_hits(tier: int) -> int:
	return int(PICK_ORE_HITS[clampi(tier, 0, PICK_ORE_HITS.size() - 1)])

# ★[S5-T3] 보석·지오드 노드 타수(곡괭이 티어 → 5/4/3/2/2).
static func pickaxe_gem_hits(tier: int) -> int:
	return int(PICK_GEM_HITS[clampi(tier, 0, PICK_GEM_HITS.size() - 1)])

# ★[S5-T3] 이 곡괭이 티어로 갱도 큰 바위를 깰 수 있나(도끼 큰 장애물 게이트 문법 동형).
#   배치가 아직 없어 지금 호출부는 없다 — 게이트 규칙의 자리를 못 박아 두는 함수다.
static func pickaxe_breaks_boulder(tier: int) -> bool:
	return tier >= TIER_LARGE_BOULDER

# ★[S5-T3] 이 도구·티어의 AoE(폭, 길이). 계단 없는 도구(도끼·곡괭이)는 항상 (1,1)이다 —
#   그쪽 티어는 타수·접근 축이고, 범위 축은 괭이·물뿌리개 전용이다(ADR-0027 차원 분리).
static func aoe_of(tool_id: String, tier: int) -> Vector2i:
	var t := clampi(tier, 0, MAX_TIER)
	match tool_id:
		HOE:
			return HOE_AOE[t]
		WATERING_CAN:
			return CAN_AOE[t]
	return Vector2i(1, 1)

# ★[S5-T3] 물뿌리개 용량(티어 → 20/30/40/55/70). main의 잔량 상한 단일 출처.
static func can_capacity(tier: int) -> int:
	return int(CAN_CAPACITY[clampi(tier, 0, CAN_CAPACITY.size() - 1)])

# ── 상태 질의/조작 ──────────────────────────────────────────────────────────
func tier_of(tool_id: String) -> int:
	return int(_tiers.get(tool_id, 0))

func set_tier(tool_id: String, tier: int) -> void:
	if not tool_id in TOOLS:
		return
	var t := clampi(tier, 0, MAX_TIER)
	if int(_tiers.get(tool_id, 0)) == t:
		return
	_tiers[tool_id] = t
	changed.emit()

# 지금 이 도구에 걸린 다음 계단({} = 최고 티어 도달 또는 계단 없는 도구).
func pending_upgrade(tool_id: String) -> Dictionary:
	return next_upgrade(tool_id, tier_of(tool_id))

# 다음 티어로 한 계단 올린다(가격 판정·골드 차감은 호출 측 = main의 몫 — 이 원장은 지갑을 모른다).
# 반환 = 올랐나. 최고 티어면 false(무동작).
func upgrade(tool_id: String) -> bool:
	var nxt := pending_upgrade(tool_id)
	if nxt.is_empty():
		return false
	set_tier(tool_id, int(nxt["tier"]))
	return true

# ── 세이브/로드 — 슬라이스 키 "tool_tiers" 네임스페이스 ──────────────────────
# ★ 하위호환: 키 없는 구세이브 = 전 도구 티어 0(기본 도구 그대로 — 무막힘). 미지 도구 키는 버린다.
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for tool_id: String in TOOLS:
		out[tool_id] = tier_of(tool_id)
	return {"tiers": out}

func load_save(data: Dictionary) -> void:
	for tool_id: String in TOOLS:
		_tiers[tool_id] = 0
	var raw: Variant = data.get("tiers", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for k in raw:
			var tool_id := String(k)
			if not tool_id in TOOLS:
				continue                      # 미지 도구 id는 조용히 버린다(inventory._sanitize 결)
			_tiers[tool_id] = clampi(int(raw[k]), 0, MAX_TIER)
	changed.emit()
