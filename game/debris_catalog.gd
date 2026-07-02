extends RefCounted
class_name DebrisCatalog
# S1-8 — 개간 debris 정적 카탈로그(3종). greybox-spec §10.2.
#
# 목적: ROADMAP S1-8 — overgrown debris 3종(이승의 미련·업화석·석화 고목)이 각자 맞는 도구·드랍
#       재료·통과 규칙으로 데이터 정의되고, 도구 매칭·드랍 조회가 헤드리스 검증을 통과하는지 한 곳에서
#       보장한다. FertilizerCatalog/AnimalCatalog와 같은 결의 정적 참조 데이터(class_name, 세이브 상태
#       아님 — 치운 좌표 델타는 Reclaim 노드가 소유).
#
# 설계 메모(§10.2):
#   - kind = debris 종류 키("weeds"/"ember"/"stump"). main이 debris 텍스처 → kind로 매핑하고(배치는
#     PROP_LAYOUT_HOME 시드에 잠김), Reclaim이 이 카탈로그로 "맞는 도구인가·무엇이 드랍되나"를 판정한다.
#   - 맞는 도구만 그 debris를 연다(틀린 도구=무동작, ADR-0024). 드랍 수는 결정적(roll 없음, 그레이박스).
#   - solid = 통과 불가 여부(업화석·석화 고목=SOLID 장애물·하드게이트 / 미련=통과 O 장식). 드로우/충돌
#     skip-filter가 참조하진 않지만(그건 Reclaim.is_cleared), 카탈로그 자기기술로 둔다(검증·문서성).
#   - drop id는 ItemCatalog.*(단방향 참조 — ItemCatalog는 DebrisCatalog를 모른다, 순환 없음).

# ── debris 종류 키 ───────────────────────────────────────────────────────────
const WEEDS := "weeds"    # 이승의 미련(잡초) — 낫
const EMBER := "ember"    # 업화석(돌) — 곡괭이
const STUMP := "stump"    # 석화 고목(그루터기) — 도끼

# ── 카탈로그(§10.2) — kind → {tool, drop, count, solid} ───────────────────────
const CATALOG := {
	WEEDS: {"tool": ItemCatalog.SCYTHE,  "drop": ItemCatalog.SOUL_FIBER,     "count": 1, "solid": false},
	EMBER: {"tool": ItemCatalog.PICKAXE, "drop": ItemCatalog.EMBER_SHARD,    "count": 2, "solid": true},
	STUMP: {"tool": ItemCatalog.AXE,     "drop": ItemCatalog.PETRIFIED_WOOD, "count": 2, "solid": true},
}

# ── 조회 ────────────────────────────────────────────────────────────────────
# 유효 debris 종류인가.
static func has(kind: String) -> bool:
	return CATALOG.has(kind)

# 이 debris를 여는 도구 id("" = 미지 kind).
static func tool_for(kind: String) -> String:
	return str(CATALOG[kind]["tool"]) if CATALOG.has(kind) else ""

# 이 debris 드랍 재료 id("" = 미지 kind).
static func drop_for(kind: String) -> String:
	return str(CATALOG[kind]["drop"]) if CATALOG.has(kind) else ""

# 이 debris 드랍 수(0 = 미지 kind).
static func drop_count(kind: String) -> int:
	return int(CATALOG[kind]["count"]) if CATALOG.has(kind) else 0

# 통과 불가(SOLID) debris인가(미지 kind=false).
static func is_solid(kind: String) -> bool:
	return bool(CATALOG[kind]["solid"]) if CATALOG.has(kind) else false

# tool_id가 개간 도구인가(낫·곡괭이·도끼 중 하나). main 디스패치 게이트가 쓴다.
static func is_reclaim_tool(tool_id: String) -> bool:
	for kind in CATALOG:
		if CATALOG[kind]["tool"] == tool_id:
			return true
	return false
