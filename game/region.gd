extends RefCounted
class_name RegionCatalog
# M1.1 — Region 데이터 모델 + 레지스트리(8구역 세계의 정적 참조 데이터).
#
# 목적: ROADMAP Phase 2.5(맵 확장, ADR-0015) — 검증된 단일 무대를 8개 분리 구역의
#       세계로 확장하기 위해, 먼저 그 구역들이 "데이터로" 정의되게 한다.
#       각 구역의 id·표시명·크기(타일)·스폰 칸·워프(인접 구역 연결) 한 곳.
#       (CONTEXT '지리' 용어 + docs/design/world-map.md 토폴로지를 그대로 박는다.)
#
# 설계 메모:
#   - 이건 crops.gd(CropCatalog)와 같은 결의 "정적 참조 데이터"다. 세이브 상태가
#     아니라 카탈로그라, 씬 노드로 두지 않고 static const로 들고 class_name으로
#     어디서든 RegionCatalog.get_region("home")으로 읽는다(오토로드 불필요).
#   - ★ M1.1 범위 = 데이터만, 동작 없음(ADR-0001 그레이박스). 아직 전환·렌더는
#     안 바꾼다. main은 var _region := HOME 한 줄만 추가하고(미사용) 기존 단일
#     무대를 그대로 굴린다 — 회귀 0. 빌드·렌더 일반화는 M1.2, 워프 동작은 M1.3,
#     카페 이주는 M1.4, 세이브 추적은 M1.5에서 이 카탈로그 위에 얹는다.
#   - ★ 실데이터 vs stub: "빌드는 한 구역씩"(ADR-0015 빈 맵·번아웃 통제)이라
#     지금 실제로 굴러가는 건 홈베이스(묵정 농원) 한 구역뿐이다. HOME만 실size·
#     실spawn을 갖고, 나머지 7개는 stub(size·spawn = ZERO = "아직 안 지어짐").
#     is_built()가 이 차이를 파생한다 — 한 구역씩 지어질 때 size·spawn을 채운다.
#   - 식별자(영문 id)와 표시명(name_ko) 분리: id는 코드·세이브용(가볍고 안정적),
#     name_ko는 화면 표시용(CONTEXT 지리 용어). M1.5 세이브엔 영문 id만 저장한다.
#   - 토폴로지(warps)는 world-map.md §2 구역 그래프를 따른다. M1.1에선 "어느 구역이
#     어느 구역과 이어지나"(to)만 실데이터였고, M1.3 워프 시스템이 각 구역이 *자기 쪽*에서
#     아는 좌표(at = 이 구역 가장자리의 발동 칸)를 채운다. dest(도착 구역 안의 칸)는 그 구역이
#     지어져야 정해지므로 해당 구역 빌드 시 채운다 — 미정이면 TILE_TBD, 워프 실행기가 목적
#     구역의 기본 스폰으로 폴백한다. ★ M1.3 현재 실데이터는 홈베이스 at 하나뿐(나루 마을이
#     아직 stub이라 그 워프는 휴면 — main `_maybe_warp_edge`의 is_built 가드. M1.4가 점등).

# ── 구역 식별자(영문 id) ─────────────────────────────────────────────────────
# id = 코드·세이브 키. 표시명은 CATALOG의 name_ko(CONTEXT 지리 용어).
const HOME := "home"                    # 묵정 농원(홈베이스·농사) — 검증된 기존 무대
const NARU_VILLAGE := "naru_village"    # 나루 마을(허브·카페·서비스·거주, 강+다리 동/서 분할)
const SAMDOCHEON := "samdocheon"        # 삼도천(강 낚시·혼백관)
const HWANGCHEONHAE := "hwangcheonhae"  # 황천해(바다 낚시·생선가게)
const JEOSEUNG_FOREST := "jeoseung_forest"  # 저승 숲(채집·목공방)
const MIHOK_FOREST := "mihok_forest"    # 미혹의 숲(깊은 숲·옥자 집·특수 채집)
const EOPHWA_MINE := "eophwa_mine"      # 업화 갱도(채광 + 끝 전투 던전·대장간·길드)
const NARAK := "narak"                  # 나락(독립 전투 던전 — 진입로 빌드 시 확정)

# 워프 트리거/도착 칸의 PLACEHOLDER. M1.3 워프 시스템이 실좌표로 채우기 전까지
# "아직 안 정해짐"을 뜻한다(무대 레이아웃이 지어져야 가장자리 칸이 정해짐).
const TILE_TBD := Vector2i(-1, -1)

# ── 카탈로그 ─────────────────────────────────────────────────────────────────
# 키 = 영문 id, 값 = 구역 데이터(아래 필드).
#   name_ko : 화면 표시명(CONTEXT 지리 용어)
#   size    : 구역 크기(타일, Vector2i). 실데이터면 실제 맵 크기, stub면 ZERO.
#             ★ HOME = (MAP_W 40 × OUTDOOR_H 24) — main.gd 외부 무대 크기와 같다(seam).
#   spawn   : 구역 진입/도착 기본 칸(타일, Vector2i). 실데이터면 실칸, stub면 ZERO.
#             ★ HOME = main.gd SPAWN_TILE(20, 21)과 같다(도착 지점·seam).
#   warps   : 인접 구역 연결 목록(Array of Dict). 각 워프 = {to, at, dest}.
#             to   = 목적 구역 id(★ M1.1 실데이터 — world-map.md 토폴로지)
#             at   = 이 구역에서 워프가 발동하는 가장자리 칸(M1.3 — 이 구역이 지어졌으면 실좌표)
#             dest = 도착 구역에서 플레이어가 놓일 칸(목적 구역 빌드 시 확정, 미정이면 TILE_TBD
#                    → 워프 실행기가 목적 구역 기본 스폰으로 폴백)
# 주의: const 중첩 Dictionary는 런타임 변경 가능하니 읽기 전용으로 다룬다(수정 금지).
const CATALOG := {
	# ── 홈베이스(유일한 실데이터) — 검증된 기존 무대를 그대로 한 구역으로 등록 ──
	HOME: {
		"name_ko": "묵정 농원",
		"size": Vector2i(40, 24),     # = main.MAP_W × main.OUTDOOR_H (외부 무대)
		"spawn": Vector2i(20, 21),    # = main.SPAWN_TILE (도착 지점)
		# 묵정 농원 ──(길)── 나루 마을. at = 동쪽 가로 복도(y=16) 끝 칸(main `_carve_paths`가
		# 동쪽 끝까지 길을 잇고, 그 가장자리 칸에 닿으면 워프 — 스타듀식 가장자리/길 워프).
		# dest는 나루 마을이 지어지는 M1.4에서 채운다(지금은 TBD → 목적 구역 스폰 폴백).
		# ★ 나루 마을이 아직 stub이라 이 워프는 휴면 상태다(is_built 가드, 회귀 0). M1.4가 점등.
		"warps": [
			{"to": NARU_VILLAGE, "at": Vector2i(38, 16), "dest": TILE_TBD},
		],
	},
	# ── 이하 7개 = stub(아직 안 지어짐). size·spawn = ZERO, 토폴로지(to)만 실데이터 ──
	NARU_VILLAGE: {
		"name_ko": "나루 마을",
		"size": Vector2i.ZERO,
		"spawn": Vector2i.ZERO,
		# 허브 — 모든 길이 통과(world-map.md §2). 농원·갱도·삼도천과 이어진다.
		"warps": [
			{"to": HOME, "at": TILE_TBD, "dest": TILE_TBD},
			{"to": EOPHWA_MINE, "at": TILE_TBD, "dest": TILE_TBD},
			{"to": SAMDOCHEON, "at": TILE_TBD, "dest": TILE_TBD},
		],
	},
	SAMDOCHEON: {
		"name_ko": "삼도천",
		"size": Vector2i.ZERO,
		"spawn": Vector2i.ZERO,
		# 나루 마을 ──(나룻터)── 삼도천 ──(하구)── 황천해.
		"warps": [
			{"to": NARU_VILLAGE, "at": TILE_TBD, "dest": TILE_TBD},
			{"to": HWANGCHEONHAE, "at": TILE_TBD, "dest": TILE_TBD},
		],
	},
	HWANGCHEONHAE: {
		"name_ko": "황천해",
		"size": Vector2i.ZERO,
		"spawn": Vector2i.ZERO,
		# 삼도천 ──(하구)── 황천해(막다른 바다 무대).
		"warps": [
			{"to": SAMDOCHEON, "at": TILE_TBD, "dest": TILE_TBD},
		],
	},
	JEOSEUNG_FOREST: {
		"name_ko": "저승 숲",
		"size": Vector2i.ZERO,
		"spawn": Vector2i.ZERO,
		# 업화 갱도 ──(숲길)── 저승 숲 ──(숲 안쪽)── 미혹의 숲.
		"warps": [
			{"to": EOPHWA_MINE, "at": TILE_TBD, "dest": TILE_TBD},
			{"to": MIHOK_FOREST, "at": TILE_TBD, "dest": TILE_TBD},
		],
	},
	MIHOK_FOREST: {
		"name_ko": "미혹의 숲",
		"size": Vector2i.ZERO,
		"spawn": Vector2i.ZERO,
		# 저승 숲 ──(숲 안쪽)── 미혹의 숲(막다른 깊은 숲, 옥자 집).
		"warps": [
			{"to": JEOSEUNG_FOREST, "at": TILE_TBD, "dest": TILE_TBD},
		],
	},
	EOPHWA_MINE: {
		"name_ko": "업화 갱도",
		"size": Vector2i.ZERO,
		"spawn": Vector2i.ZERO,
		# 나루 마을 ──(산길)── 업화 갱도 ──(숲길)── 저승 숲.
		"warps": [
			{"to": NARU_VILLAGE, "at": TILE_TBD, "dest": TILE_TBD},
			{"to": JEOSEUNG_FOREST, "at": TILE_TBD, "dest": TILE_TBD},
		],
	},
	NARAK: {
		"name_ko": "나락",
		"size": Vector2i.ZERO,
		"spawn": Vector2i.ZERO,
		# 독립 전투 던전 — 진입로는 빌드 시 확정(world-map.md §2·§5 서랍). 지금은 연결 없음.
		"warps": [],
	},
}

# ── 조회 ──────────────────────────────────────────────────────────────────────
# 구역 id 목록(카탈로그 정의 순서 = 토폴로지 인접 순). 허브 나루 마을 중심.
static func ids() -> Array:
	return [
		HOME, NARU_VILLAGE, SAMDOCHEON, HWANGCHEONHAE,
		JEOSEUNG_FOREST, MIHOK_FOREST, EOPHWA_MINE, NARAK,
	]

static func has_region(id: String) -> bool:
	return CATALOG.has(id)

# 구역 데이터(읽기 전용). 없는 id면 빈 Dictionary(미지 id 방어).
static func get_region(id: String) -> Dictionary:
	return CATALOG.get(id, {})

# 표시명(CONTEXT 지리 용어). 없는 id면 "".
static func name_of(id: String) -> String:
	return CATALOG[id]["name_ko"] if CATALOG.has(id) else ""

# 구역 크기(타일). 없는 id면 ZERO(stub과 같은 값 — 호출부가 안전하게 "안 지어짐" 처리).
static func size_of(id: String) -> Vector2i:
	return CATALOG[id]["size"] if CATALOG.has(id) else Vector2i.ZERO

# 진입/도착 기본 칸(타일). 없는 id면 ZERO.
static func spawn_of(id: String) -> Vector2i:
	return CATALOG[id]["spawn"] if CATALOG.has(id) else Vector2i.ZERO

# 워프 목록(읽기 전용). 없는 id면 빈 Array.
static func warps_of(id: String) -> Array:
	return CATALOG[id]["warps"] if CATALOG.has(id) else []

# 인접 구역 id 목록(워프의 to만 뽑은 토폴로지 이웃). 없는 id면 빈 Array.
static func neighbors(id: String) -> Array:
	var out: Array = []
	for w in warps_of(id):
		out.append(w["to"])
	return out

# ★ 실제로 지어진(굴러가는) 구역인가 = size가 ZERO가 아님. M1.1에선 HOME만 참.
# 한 구역씩 빌드될 때(M1.4~) size·spawn이 채워지며 참이 된다("빌드는 한 구역씩").
static func is_built(id: String) -> bool:
	return size_of(id) != Vector2i.ZERO
