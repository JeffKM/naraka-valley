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
#     지금 실제로 굴러가는 건 홈베이스(안식 농원) 한 구역뿐이다. HOME만 실size·
#     실spawn을 갖고, 나머지 7개는 stub(size·spawn = ZERO = "아직 안 지어짐").
#     is_built()가 이 차이를 파생한다 — 한 구역씩 지어질 때 size·spawn을 채운다.
#   - 식별자(영문 id)와 표시명(name_ko) 분리: id는 코드·세이브용(가볍고 안정적),
#     name_ko는 화면 표시용(CONTEXT 지리 용어). M1.5 세이브엔 영문 id만 저장한다.
#   - 토폴로지(warps)는 world-map.md §2 구역 그래프를 따른다. M1.1에선 "어느 구역이
#     어느 구역과 이어지나"(to)만 실데이터였고, M1.3 워프 시스템이 각 구역이 *자기 쪽*에서
#     아는 좌표(at = 이 구역 가장자리의 발동 칸)를 채운다. dest(도착 구역 안의 칸)는 그 구역이
#     지어져야 정해지므로 해당 구역 빌드 시 채운다 — 미정이면 TILE_TBD, 워프 실행기가 목적
#     구역의 기본 스폰으로 폴백한다. ★ M5.2 현재 8구역 전부 실데이터(stub 0) — 안식 농원·나루 마을·
#     삼도천·황천해·저승 숲·미혹의 숲·업화 갱도가 워프 그래프로 다 이어져 있고(at·dest 실좌표 = 살아 있음),
#     나락만 독립(진입로 '서랍' = 업화 갱도의 잠긴 외관, 라이브 워프 없음 — Phase 3 전투에서 점등).

# ── 구역 식별자(영문 id) ─────────────────────────────────────────────────────
# id = 코드·세이브 키. 표시명은 CATALOG의 name_ko(CONTEXT 지리 용어).
const HOME := "home"                    # 안식 농원(홈베이스·농사) — 검증된 기존 무대
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
		"name_ko": "안식 농원",
		"size": Vector2i(40, 24),     # = main.MAP_W × main.OUTDOOR_H (외부 무대)
		"spawn": Vector2i(20, 21),    # = main.SPAWN_TILE (도착 지점)
		# 안식 농원 ──(길)── 나루 마을. at = 동쪽 가로 복도(y=16) 끝 칸(main `_carve_paths`가
		# 동쪽 끝까지 길을 잇고, 그 가장자리 칸에 닿으면 워프 — 스타듀식 가장자리/길 워프).
		# ★ M1.4: 나루 마을이 지어져 이 워프가 점등했다(is_built=true). dest = 마을 도착 칸(서쪽
		# 복도, 마을 워프 가장자리 (1,16)에서 한 칸 안 — 즉시 재발동 방지). 두 구역 다 빌드라 실좌표.
		"warps": [
			{"to": NARU_VILLAGE, "at": Vector2i(38, 16), "dest": Vector2i(3, 16)},
		],
	},
	# ── 나루 마을(M1.4 빌드 — 카페 이주) ─────────────────────────────────────────
	# ★ M1.4: 두 번째 실데이터 구역. 안식 농원에서 검증된 카페(옥자·미호·멜·바나·서빙·정산·밤
	#   바)를 이 마을로 옮겨 담는다("최소 그레이박스 마을 = 카페 + 워프만", 전체 레이아웃은 다음 묶음).
	#   size = (40, 24)(안식 농원과 같은 외부 무대 크기 — 카메라 격리 seam, main.MAP_W×OUTDOOR_H).
	#   spawn = (3, 16)(서쪽 복도, 안식 농원에서 도착하는 칸). 카페 내부 좌표는 안식 농원 시절과
	#   동일하게 유지하고(좌표 대이동 최소화·회귀 0), 마을 그리드의 같은 칸(y38~47)에 카페 방을 둔다.
	NARU_VILLAGE: {
		"name_ko": "나루 마을",
		"size": Vector2i(40, 24),     # = main.MAP_W × main.OUTDOOR_H (안식 농원과 같은 외부 무대)
		"spawn": Vector2i(3, 16),     # 서쪽 복도(안식 농원 → 마을 도착 칸)
		# 허브 — 모든 길이 통과(world-map.md §2). 농원·갱도·삼도천과 이어진다. 마을이 지어졌으므로
		# 자기 쪽 가장자리 발동 칸(at)은 셋 다 실좌표다(region.gd 설계: at = 이 구역이 지어지면 확정).
		# dest는 *목적 구역*이 지어져야 정해진다 — 안식 농원만 빌드라 그쪽만 실좌표, 갱도·삼도천은
		# 아직 stub이라 TBD(그 구역 빌드 시 확정). 갱도·삼도천 워프는 목적지 미빌드라 휴면이다.
		# ★ M2.1 — 마을 본격 레이아웃(강+다리 동/서 분할)이 지어져 워프 발동 칸(at)이 실좌표로
		# 확정됐다: 서워프(1,16)=서편 복도 / 산길(38,8)=동편 가장자리 / 나룻터(22,1)=동편 강변로
		# 북단(강 상류 → 삼도천·혼백관). 갱도·삼도천은 목적지 stub이라 여전히 휴면(그 구역 빌드 시 점등).
		# ★ M3.1 — 삼도천이 지어져 나룻터 워프 dest가 실좌표로 확정됐다(목적 구역 빌드 시 채움).
		"warps": [
			{"to": HOME, "at": Vector2i(1, 16), "dest": Vector2i(37, 16)},   # 서쪽 가장자리 → 안식 농원
			# ★ M5.1 — 정규 토폴로지 복원(M4.1 임시 직결 종료): 산길은 업화 갱도로 간다(갱도가 지어져 점등).
			# 나루 마을→갱도→저승 숲이 정규 경로. dest = 갱도 남단 spawn(20,22).
			{"to": EOPHWA_MINE, "at": Vector2i(38, 8), "dest": Vector2i(20, 22)},  # 동쪽 산길 → 업화 갱도(남단 spawn) — M5.1 점등
			{"to": SAMDOCHEON, "at": Vector2i(22, 1), "dest": Vector2i(20, 22)},  # 북동 나룻터 → 삼도천(혼백관) — M3.1 점등
		],
	},
	# ── 삼도천(M3.1 빌드 — 강 낚시 무대·혼백관) ──────────────────────────────────
	# ★ M3.1: 셋째 실데이터 구역. 나루 마을 나룻터(22,1)에서 휴면이던 워프를 점등해, 강 낚시(Phase 3)가
	#   들어올 무대를 그레이박스로 깐다(낚시 메카닉은 만들지 않는다 — 무대·혼백관 빈 방까지, ADR-0015).
	#   size=(40,24)(외부 무대 = main.MAP_W×OUTDOOR_H, 카메라 seam). spawn=(20,22)(남단 나룻터 — 나루
	#   마을에서 배로 건너 닿는 칸). 하구(→황천해) 워프는 at만 실좌표·dest TBD(목적지 stub이라 휴면, M3.2 점등).
	SAMDOCHEON: {
		"name_ko": "삼도천",
		"size": Vector2i(40, 24),     # = main.MAP_W × main.OUTDOOR_H (안식 농원·나루 마을과 같은 외부 무대)
		"spawn": Vector2i(20, 22),    # 남단 나룻터(나루 마을 → 삼도천 도착 칸)
		# 나루 마을 ──(나룻터)── 삼도천 ──(하구)── 황천해.
		"warps": [
			{"to": NARU_VILLAGE, "at": Vector2i(20, 23), "dest": Vector2i(22, 2)},  # 남단 나룻터 → 나루 마을(22,1 한 칸 안)
			{"to": HWANGCHEONHAE, "at": Vector2i(38, 16), "dest": Vector2i(2, 16)},  # 동단 하구 → 황천해 — M3.2 점등
		],
	},
	# ── 황천해(M3.2 빌드 — 바다 낚시 무대·생선가게) ──────────────────────────────
	# ★ M3.2: 넷째 실데이터 구역(막다른 바다 무대). 삼도천 하구(38,16)에서 휴면이던 워프를 점등해, 바다 낚시
	#   (Phase 3)가 들어올 무대를 그레이박스로 깐다(낚시 메카닉은 만들지 않는다 — 바다·부두·생선가게 빈 방까지).
	#   size=(40,24)(외부 무대 = main.MAP_W×OUTDOOR_H, 카메라 seam). spawn=(2,16)(서단 — 삼도천 하구에서 도착).
	#   막다른 구역이라 워프는 하나(삼도천 복귀). 부두·바다 낚시터는 무대만(라벨), 생선가게 서비스는 후속.
	HWANGCHEONHAE: {
		"name_ko": "황천해",
		"size": Vector2i(40, 24),     # = main.MAP_W × main.OUTDOOR_H (다른 구역과 같은 외부 무대)
		"spawn": Vector2i(2, 16),     # 서단(삼도천 하구 → 황천해 도착 칸)
		# 삼도천 ──(하구)── 황천해(막다른 바다 무대).
		"warps": [
			{"to": SAMDOCHEON, "at": Vector2i(1, 16), "dest": Vector2i(37, 16)},  # 서단 → 삼도천 하구(38,16 한 칸 안)
		],
	},
	# ── 저승 숲(M4.1 빌드 — 채집 무대·목공방) ────────────────────────────────────
	# ★ M4.1: 다섯째 실데이터 구역. 채집(Phase 3)이 들어올 숲 무대를 그레이박스로 깐다(채집 메카닉은
	#   만들지 않는다 — 나무 무대·채집지 라벨·목공방 enterable 빈 방까지, ADR-0015 "빌드는 한 구역씩").
	#   size=(40,24)(외부 무대 = main.MAP_W×OUTDOOR_H, 카메라 seam). spawn=(20,22)(남단 — 나루 마을
	#   산길에서 임시 직결로 도착). 정규 토폴로지: 업화 갱도 ──(숲길)── 저승 숲 ──(숲 안쪽)── 미혹의 숲.
	#   ★ M5.1 도달성: 정규 이웃 업화 갱도가 지어져, 저승 숲은 남단 숲길로 갱도와 직접 잇는다(임시 우회 종료).
	JEOSEUNG_FOREST: {
		"name_ko": "저승 숲",
		"size": Vector2i(40, 24),     # = main.MAP_W × main.OUTDOOR_H (다른 구역과 같은 외부 무대)
		"spawn": Vector2i(20, 22),    # 남단(업화 갱도 북단 숲길 → 저승 숲 도착 칸)
		"warps": [
			{"to": EOPHWA_MINE, "at": Vector2i(20, 23), "dest": Vector2i(20, 2)},   # 남단 숲길 → 업화 갱도(북단 20,1 한 칸 안) — ★M5.1 점등
			{"to": MIHOK_FOREST, "at": Vector2i(38, 16), "dest": Vector2i(2, 16)},  # 동단 숲 안쪽 → 미혹의 숲 — M4.2 점등
			# ★ M5.1 — M4.1 임시 우회 워프(서단 1,16 → 나루 마을) 제거. 갱도가 지어져 정규 경로(나루 마을→갱도→숲)로 복귀.
		],
	},
	# ── 미혹의 숲(M4.2 빌드 — 특수 채집 무대·옥자 집) ────────────────────────────
	# ★ M4.2: 여섯째 실데이터 구역(막다른 깊은 숲). 저승 숲 동단(38,16)에서 휴면이던 워프를 점등해, 특수
	#   채집(Phase 3)이 들어올 더 깊은 숲을 그레이박스로 깐다(채집 메카닉은 만들지 않는다 — 나무·연못 무대·
	#   특수 채집지 라벨까지). size=(40,24)(외부 무대 = main.MAP_W×OUTDOOR_H). spawn=(2,16)(서단 — 저승 숲
	#   동단에서 도착). 막다른 구역이라 워프는 저승 숲 복귀 하나(world-map.md 토폴로지).
	#   ★ 옥자 집(마녀의 오두막)은 세계관상 '숨겨진·게이트(미결의 죄 해결 후)' — 그레이박스에선 잠긴 외관
	#     (비-enterable, 카탈로그 미등록)으로만 둔다(축사 결). 실내·게이트 해제는 Phase 3 시나리오.
	MIHOK_FOREST: {
		"name_ko": "미혹의 숲",
		"size": Vector2i(40, 24),     # = main.MAP_W × main.OUTDOOR_H (다른 구역과 같은 외부 무대)
		"spawn": Vector2i(2, 16),     # 서단(저승 숲 동단 → 미혹의 숲 도착 칸)
		# 저승 숲 ──(숲 안쪽)── 미혹의 숲(막다른 깊은 숲, 옥자 집).
		"warps": [
			{"to": JEOSEUNG_FOREST, "at": Vector2i(1, 16), "dest": Vector2i(37, 16)},  # 서단 → 저승 숲 동단(38,16 한 칸 안)
		],
	},
	# ── 업화 갱도(M5.1 빌드 — 채광/전투 무대·대장간·길드) ────────────────────────
	# ★ M5.1: 일곱째 실데이터 구역. 채광(Phase 3)이 들어올 갱도 무대를 그레이박스로 깐다(채광·전투 메카닉은
	#   만들지 않는다 — 바위(ROCK)·호수(WATER) 무대·대장간·길드(enterable 빈 방)·갱도 끝 전투 던전 입구(잠긴
	#   외관)까지, ADR-0015 "빌드는 한 구역씩"). size=(40,24)·spawn=(20,22)(남단 — 나루 마을 산길에서 도착).
	#   정규 토폴로지 복원: 나루 마을 ──(산길)── 업화 갱도 ──(숲길)── 저승 숲. 양쪽 다 빌드라 at·dest 실좌표.
	EOPHWA_MINE: {
		"name_ko": "업화 갱도",
		"size": Vector2i(40, 24),     # = main.MAP_W × main.OUTDOOR_H (다른 구역과 같은 외부 무대)
		"spawn": Vector2i(20, 22),    # 남단(나루 마을 산길 → 업화 갱도 도착 칸)
		"warps": [
			{"to": NARU_VILLAGE, "at": Vector2i(20, 23), "dest": Vector2i(37, 8)},     # 남단 산길 → 나루 마을(산길 38,8 한 칸 안)
			{"to": JEOSEUNG_FOREST, "at": Vector2i(20, 1), "dest": Vector2i(20, 22)},  # 북단 숲길 → 저승 숲(남단 spawn)
		],
	},
	# ── 나락(M5.2 빌드 — 독립 전투 던전 스테이지) ───────────────────────────────
	# ★ M5.2: 여덟째 실데이터 구역(독립 전투 전용). 전투(Phase 3)가 들어올 빈 전투장 스테이지를 그레이박스로
	#   깐다(전투 메카닉은 만들지 않는다 — 심연·업화·봉인 모티프 무대까지). size=(40,24)·spawn=(20,12).
	#   ★ 진입로 = '서랍'(world-map §5): 나락 진입로는 업화 갱도 그리드의 *잠긴 외관*(비-enterable)이라
	#     라이브 워프가 없다 → warps=[]. 스테이지는 헤드리스 테스트가 _region 직접 세팅해 빌드·검증하고,
	#     인게임 진입은 Phase 3 전투에서 점등한다(독립 — world_test "나락=이웃 0" 불변식 유지).
	NARAK: {
		"name_ko": "나락",
		"size": Vector2i(40, 24),     # = main.MAP_W × main.OUTDOOR_H (다른 구역과 같은 외부 무대)
		"spawn": Vector2i(20, 12),    # 전투장 중앙(헤드리스 빌드·검증 — 인게임 진입은 잠긴 외관, Phase 3)
		"warps": [],                  # 진입로 잠김(서랍) — 라이브 워프 없음(이웃 0, 독립 전투 던전)
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
