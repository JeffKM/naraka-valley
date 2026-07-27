extends RefCounted
class_name ToolTier
# ★[S4-T4 / ADR-0062 결정 6] 도구 티어 코어 — "지금 어느 도구가 몇 티어인가"만 소유하는 얇은 원장.
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
#   - **도끼만 실효, 나머지 3종은 키 예약.** 곡괭이·괭이·물뿌리개의 AoE·용량 배선은 S5 대장간
#     본무대 소관이다. 지금 키만 잡아 두는 이유 = 세이브 스키마가 나중에 안 흔들리게.
#   - **골드 단독 구매(잠정).** 저승 금속 재료 요구는 S5에서 정식화한다(ADR-0062 결정 6).
#   - 이 파일엔 무작위가 없다(전 판정 결정적) — 헤드리스가 정확히 재현한다.

signal changed()   # 티어가 오른 프레임(main이 듣고 프롬프트·타수 표시를 갱신)

# ── 도구 축(4종 — 도끼만 S4 실효, 나머지는 키 예약) ─────────────────────────
const AXE := "axe"
const PICKAXE := "pickaxe"
const HOE := "hoe"
const WATERING_CAN := "watering_can"
const TOOLS := [AXE, PICKAXE, HOE, WATERING_CAN]

# ── 티어 상한(S4 실효 = 2. 금·이리듐 대응 상위 2티어는 S5 대장간 본무대) ────
const MAX_TIER := 2

# ── 도끼 티어 명명·가격(ADR-0062 결정 6 — 스타듀 구리/강철 도끼 결) ──────────
# 티어 0 = 기본 도끼(ItemCatalog.AXE, 시작 도구) · 1 = 명동(冥銅) · 2 = 유철(幽鐵).
# ★ 순차 업그레이드: 0→2 직행 없음. 5000냥을 들고 있어도 명동을 먼저 거친다(가격 계단 = 경제 곡선).
const AXE_TIER_NAMES := ["도끼", "명동 도끼", "유철 도끼"]
const AXE_UPGRADES := [
	{"tier": 1, "name": "명동 도끼", "price": 2000},   # 冥銅 — 큰 그루터기 해금
	{"tier": 2, "name": "유철 도끼", "price": 5000},   # 幽鐵 — 큰 통나무 해금 = 미혹 심층 개방
]

# ── 도끼 티어 효과 ①: 성숙목 타수(스타듀 상속 — 0/1/2티어 = 10/8/6타) ────────
# TreeLedger.HP_MATURE(10)와 [0]이 반드시 같아야 한다(tool_tier_test ③이 단언).
const AXE_MATURE_HP := [10, 8, 6]

# ── 도끼 티어 효과 ②: 큰 장애물 접근 게이트(ADR-0033 "특수 채집지만 도끼 티어로 접근") ──
# ★ 의존 방향은 **한쪽뿐**이다: TreeLedger가 이 두 수치를 참조하고(종 id → 요구 티어), 이 파일은
#   TreeLedger를 모른다. 서로 참조하면 GDScript 순환 참조라 파싱이 깨진다.
const TIER_LARGE_STUMP := 1   # 큰 그루터기 = 명동 도끼(스타듀 구리 도끼 Large Stump 1:1)
const TIER_LARGE_LOG := 2     # 큰 통나무 = 유철 도끼(스타듀 강철 도끼 Large Log 1:1)

# 티어 상태. { tool(String) → int }. 전 도구 키를 미리 잡아 둔다(예약 = 세이브 스키마 고정).
var _tiers: Dictionary = {}

func _init() -> void:
	for tool_id: String in TOOLS:
		_tiers[tool_id] = 0

# ── 정적 규칙 ───────────────────────────────────────────────────────────────
# 이 도구에 업그레이드 경로가 있나(S4 = 도끼만. 나머지는 대장간에서 "준비 중"으로 뜬다).
static func is_upgradable(tool_id: String) -> bool:
	return tool_id == AXE

# 이 도구의 업그레이드 계단 전체(없으면 빈 배열).
static func upgrades_for(tool_id: String) -> Array:
	return AXE_UPGRADES.duplicate(true) if tool_id == AXE else []

# 이 도구·이 티어에서 *다음* 계단({} = 더 없음 = 최고 티어). 무대(대장간)와 테스트의 단일 출처.
static func next_upgrade(tool_id: String, tier: int) -> Dictionary:
	for u in upgrades_for(tool_id):
		if int(u["tier"]) == tier + 1:
			return u
	return {}

# 티어 이름(도끼 외 도구는 아직 계단이 없어 기본 명칭 하나뿐 — ItemCatalog 이름으로 폴백).
static func tier_name(tool_id: String, tier: int) -> String:
	if tool_id == AXE:
		return String(AXE_TIER_NAMES[clampi(tier, 0, AXE_TIER_NAMES.size() - 1)])
	return ItemCatalog.name_of(tool_id)

# 성숙목 타수(도끼 티어 → 10/8/6). TreeLedger.hp_for_stage가 이 한 줄만 참조한다(수치 복제 0).
static func axe_mature_hp(tier: int) -> int:
	return int(AXE_MATURE_HP[clampi(tier, 0, AXE_MATURE_HP.size() - 1)])

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
