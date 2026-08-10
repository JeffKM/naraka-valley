extends RefCounted
class_name MineFloors
# ★[S5-T1 / ADR-0063 결정 1] 업화 갱도 층 시스템 — "몇 층이 어떻게 생겼나 + 오늘 무엇을 캤나"만
# 소유하는 얇은 원장(ledger) + 결정적 층 생성기.
#
# 목적: ADR-0063 결정 1("60층·3밴드·엘리베이터 5층·day-한정 층 상태")의 빌드 형태. 층 배치는
#       (day, floor) 시드에서 순수하게 파생되고, 그날 깬 돌만 원장에 남는다. 날이 바뀌면 전 층이
#       리필된다(스타듀 정합 — 층 상태 영속은 ADR-0063 "폐기한 대안"에서 명시적으로 기각).
#
# 왜 별개 원장인가(ForageSpawns/TreeLedger/TapperLedger 동형 완전 분리):
#   - **RefCounted(비-Node)**: 설치물이 아니라 순수 데이터라 씬 트리에 설 이유가 없다. main이
#     참조로 들고 질의한다(ADR-0062에서 굳은 "순수 원장" 관례 그대로).
#   - 이 파일은 지형·타일 id·충돌·혼력·인벤토리·도구 티어·전투를 **하나도 모른다**. 층을 실제
#     그리드로 세우는 것(WALL/PATH/ROCK 배선)도, 곡괭이 타수·혼력 소모도 전부 main이 한다.
#     여기가 아는 건 "논리 좌표 위의 방·돌·사다리"뿐이다(원장은 무대를 모른다).
#
# 설계 메모(어기면 ADR-0063 결정 1 위반):
#   - **층 생성 = 결정적 순수 함수**. 시드 `hash("mine:<day>:<floor>")`로 RNG 하나를 만들고
#     **순차 소비**한다. 좌표별 해시(ForageSpawns 스폰 롤 방식)를 쓰면 이웃 칸이 연속된 값을 받아
#     겹침·줄무늬가 생긴다(미혹 안개 교훈 — ADR-0063이 명시적으로 금지). 그래서 여기선 "RNG 하나를
#     정해진 순서로 소비"가 유일한 규칙이다: 템플릿 → 방 위치 → 입구 → 사다리 → 돌 스캐터 순.
#   - **day-한정 채굴 원장**: 그날 깬 돌 좌표만 남는다. 같은 날 같은 층에 다시 내려가면 배치는
#     동일하고 깬 돌만 빠져 있다(재파밍 차단). `advance_day`가 day를 갈면 전량 소멸한다.
#   - **`mine_depth`(도달 최심층)만 영구**다. 엘리베이터 체크포인트가 이 값에서 파생된다.
#   - **HP는 여기 없다**(T4 소관). 사다리 롤의 `luck_bonus`는 운 시스템이 붙을 **인자 자리**다.
#   - ★[S5-T5] **잡귀 스폰도 여기 합류**했다(아래 "잡귀 스폰" 절) — 노드와 정확히 같은 이유다:
#     "논리 좌표 위에 무엇이 서는가"의 주인은 이 파일이다. 다만 개체 상태(HP·행동 위상)·틱 이동·
#     피해는 여전히 밖이다(Mob·main). 그리고 롤은 **노드 뒤·스트림 맨 끝**이라 T1/T2 골든 서명이
#     한 칸도 안 흔들린다(mining_test ②가 그 불변을 잠근다).
#   - ★[S5-T2] **광석 노드는 여기 합류**했다(아래 "노드 로스터" 절) — 노드도 결국 "논리 좌표 위의
#     돌"이라 배치의 주인은 이 파일이다. 다만 드랍·XP·혼력은 여전히 밖이다(MiningSkill·main).

# ── 층 구조(ADR-0063 결정 1 — 스타듀 120층의 1/2 큐레이션) ────────────────────
const MAX_FLOOR := 60        # 갱도 총 층수(*잠정* — ADR-0063 "층수 60은 owner 큐 잠정")
const BAND_SPAN := 20        # 밴드당 층수(20 × 3밴드)
const BAND_JAETGIL := "jaetgil"   # 잿길(1~20 · 잿빛 흙)
const BAND_NEOKGOL := "neokgol"   # 넋골(21~40 · 뼈·그림자)
const BAND_EOPHWA := "eophwa"     # 업화(41~60 · 용암)
const BANDS := [BAND_JAETGIL, BAND_NEOKGOL, BAND_EOPHWA]
const BAND_NAMES := {BAND_JAETGIL: "잿길", BAND_NEOKGOL: "넋골", BAND_EOPHWA: "업화"}

# ── 층 그리드(갱도 지상 64×44보다 작은 별도 그리드 — ADR-0063 "지상 구역 재배치 없음") ──
# 층은 지상 무대와 좌표를 공유하지 않는다. 지상 구역·건물·워프 좌표는 한 칸도 안 움직인다
# (eophwa_mine_test의 좌표 단언 전량 불변 — 이 분리가 그 보증이다).
const FLOOR_W := 24
const FLOOR_H := 24

# ── 엘리베이터(스타듀 1:1 — 5층 간격 체크포인트) ──────────────────────────────
const ELEVATOR_STEP := 5

# ── 돌 파괴 사다리 롤(스타듀 상속 — ADR-0063 결정 1 ㉡) ───────────────────────
# chance = base 2% + 1/(남은 돌 + 1) + (몹 전멸 시 +4%) + 명부의 운 가산.
# 남은 돌이 줄수록 단조 증가해 "마지막 돌까지 캐면 반드시 열린다"는 스타듀의 안전판이 된다.
const LADDER_BASE := 0.02          # base 2%
const LADDER_MOBS_CLEARED := 0.04  # ★[S5-T5] 층의 몹을 전멸시켰을 때 가산(실배선 완료 — main._mobs_cleared)
# ★[S5-T5 / ADR-0063 결정 1 ㉢] 몹 처치 시 사다리 15%. 돌 파괴 롤(남은 돌 역수)과 **별 축**이다 —
#   싸워서 내려가는 길과 캐서 내려가는 길이 각자 열린다(스타듀 1:1).
const LADDER_MOB_KILL := 0.15

# ── 층 템플릿 풀(그레이박스 4종 — ADR-0063 "방 템플릿 풀 3~5종 결정 롤") ──────
# 그레이박스라 형태는 전부 직사각 방이고 **크기·바위 밀도**만 갈린다(층마다 "좁고 빽빽" / "넓고
# 성김"이 번갈아 나와 리듬이 생긴다). 굴곡진 동굴 형태·감염층·보물방 같은 층 변형은 ADR-0063이
# S5 스코프 밖으로 명시했다(폴리시/후속 후보).
static func templates() -> Array:
	return [
		{"id": "wide", "size": Vector2i(20, 14), "density": 0.10},    # 넓고 성긴 홀
		{"id": "tall", "size": Vector2i(13, 20), "density": 0.14},    # 좁고 긴 수직 갱
		{"id": "square", "size": Vector2i(17, 17), "density": 0.18},  # 정방 채굴장
		{"id": "narrow", "size": Vector2i(11, 11), "density": 0.24},  # 작고 빽빽한 포켓
	]

# ── ★[S5-T2 / ADR-0063 결정 2] 광물 노드 로스터 ───────────────────────────────
# 노드 = **특별한 돌**이다. 별도 좌표계를 새로 깔지 않고, 일반 돌(`rocks`) 스캐터가 끝난 *뒤*
# 그 목록의 일부를 승격시켜 만든다. 그래서:
#   · `rocks`는 S5-T1과 한 칸도 안 달라진다(RNG 순차 소비의 **맨 뒤**에 붙었다 — mining_test ②가
#     T1 시점 골든 서명으로 이 불변을 잠근다). 앞에 끼워 넣으면 전 층 배치가 통째로 갈린다.
#   · `nodes`의 키는 항상 `rocks`의 부분집합이다 = 노드도 곡괭이로 깨는 돌이고, 남은 돌 수·사다리
#     확률·통행 판정이 전부 기존 경로로 그대로 통용된다(신규 분기 0).
#
# ★ **노드 id = 드랍 아이템 id**(ItemCatalog 상수와 *같은 문자열*). 이 파일은 그래도 ItemCatalog를
#   참조하지 않는다(의존 방향 보존 — 원장은 인벤토리를 모른다). 대신 mining_test ⑧이
#   `ItemCatalog.has_item(node_id)`로 전 종을 대조해 두 로스터가 조용히 갈라지는 걸 막는다.
#   덕분에 main에 "노드 → 아이템" 매핑 테이블이 아예 없다.
#
# ★ 나락철(奈落鐵)·오색혼옥은 **여기 없다** — 갱도 미출현이고(나락 전용 깊이 비례 / 초희귀 드랍),
#   ADR-0063 결정 2가 그렇게 못 박았다. 아이템 등록만 돼 있고 출현은 S5-T7(나락) 소관이다.

# 노드 부류(타수·드랍 규칙의 축 — 개별 id가 아니라 이 부류로 갈린다).
const NODE_ORE := "ore"       # 금속 광맥(명동·유철·황천금) — 1~3개 드랍·크리 채굴 대상
const NODE_COAL := "coal"     # 혼탄 광맥 — 광석과 같은 결(연료 자재)
const NODE_GEM := "gem"       # 보석 노드 — 1개(지질사 퍼크로 쌍)
const NODE_GEODE := "geode"   # 지오드(알돌) 노드 — 1개(개봉은 T3 대장간)

# 노드 종 id(= 아이템 id · *명명 전부 잠정* — ADR-0063 결정 2 owner 큐).
const N_MYEONGDONG := "ore_myeongdong"            # 명동 광석(전층)
const N_YUCHEOL := "ore_yucheol"                  # 유철 광석(21층+)
const N_HWANGCHEONGEUM := "ore_hwangcheongeum"    # 황천금 광석(41층+)
const N_HONTAN := "hontan"                        # 혼탄(전층 — 제련 연료)
const N_GEODE_NEOKAL := "geode_neokal"            # 넋알돌(1~40층)
const N_GEODE_EOPHWA := "geode_eophwa"            # 업화알돌(41층+)
const N_GEM_NEOKSUJEONG := "gem_neoksujeong"      # 넋수정(전층)
const N_GEM_MYEONGOK := "gem_myeongok"            # 명옥(21층+)
const N_GEM_YEOMJUSEOK := "gem_yeomjuseok"        # 염주석(41층+)
const N_GEM_MYEONGBU := "gem_myeongbu_geumgang"   # 명부금강(31층+ 희귀 — 다이아 대응)

# 노드 타수 — **0티어 기준값**(도끼 `TreeLedger.HP_MATURE` 선례와 같은 자리).
# ★[S5-T3] 곡괭이 티어 감산이 `node_hits(node_id, tier)`로 이 위에 얹혔다. 감산 규칙표의 단일
#   출처는 `ToolTier.PICK_ORE_HITS`/`PICK_GEM_HITS`이고, 그 [0]이 아래 두 상수와 같아야 한다
#   (tool_tier_test ⑨가 단언 — TreeLedger.HP_MATURE ↔ AXE_MATURE_HP[0] 관계와 정확히 동형).
const ROCK_HITS := 1    # 일반 돌 = 즉발(티어 무관 — 이미 1타라 깎을 게 없다)
const ORE_HITS := 3     # 광석·혼탄 광맥(0티어)
const GEM_HITS := 5     # 보석·지오드 노드(0티어)

# 층당 노드 총수(*잠정*) — 3~7개. 가중치상 대부분이 광석이라 "층당 광석 노드 2~5 + 보석/지오드는
# 가끔"이라는 스타듀 체감에 맞는다. 돌이 그보다 적은 층은 돌 수가 상한이다.
const NODE_MIN := 3
const NODE_MAX := 7
const NODE_PICK_TRIES := 8   # 좌표 중복 회피 재시도 상한(무한 루프 방지 — 결정성엔 영향 없음)

# 노드 테이블 — {id, cls, floor_min, floor_max(0=무제한), weight}. 밴드 게이팅의 단일 출처다.
# 가중치(*잠정*): 광석 40 : 혼탄 18 : 지오드 10 : 보석 6 : 명부금강 2. 밴드가 깊어질수록 상위
# 광석이 하위 광석을 **대체하지 않고 얹힌다**(명동은 60층에서도 나온다 — 스타듀 동형).
const NODE_TABLE := [
	{"id": N_MYEONGDONG, "cls": NODE_ORE, "floor_min": 1, "floor_max": 0, "weight": 40},
	{"id": N_HONTAN, "cls": NODE_COAL, "floor_min": 1, "floor_max": 0, "weight": 18},
	{"id": N_GEODE_NEOKAL, "cls": NODE_GEODE, "floor_min": 1, "floor_max": 40, "weight": 10},
	{"id": N_GEM_NEOKSUJEONG, "cls": NODE_GEM, "floor_min": 1, "floor_max": 0, "weight": 6},
	{"id": N_YUCHEOL, "cls": NODE_ORE, "floor_min": 21, "floor_max": 0, "weight": 40},
	{"id": N_GEM_MYEONGOK, "cls": NODE_GEM, "floor_min": 21, "floor_max": 0, "weight": 6},
	{"id": N_GEM_MYEONGBU, "cls": NODE_GEM, "floor_min": 31, "floor_max": 0, "weight": 2},
	{"id": N_HWANGCHEONGEUM, "cls": NODE_ORE, "floor_min": 41, "floor_max": 0, "weight": 40},
	{"id": N_GEM_YEOMJUSEOK, "cls": NODE_GEM, "floor_min": 41, "floor_max": 0, "weight": 6},
	{"id": N_GEODE_EOPHWA, "cls": NODE_GEODE, "floor_min": 41, "floor_max": 0, "weight": 10},
]

# 이 층에 깔릴 수 있는 노드 종 목록(밴드 게이트 적용 — 테이블 순서 보존 = 결정적).
static func node_pool(floor_no: int) -> Array:
	var out: Array = []
	if not is_valid_floor(floor_no):
		return out
	for e: Dictionary in NODE_TABLE:
		if floor_no < int(e["floor_min"]):
			continue
		var fmax := int(e["floor_max"])
		if fmax > 0 and floor_no > fmax:
			continue
		out.append(e)
	return out

# 노드 종 id → 부류("" = 노드가 아님 = 일반 돌).
static func node_class(node_id: String) -> String:
	for e: Dictionary in NODE_TABLE:
		if String(e["id"]) == node_id:
			return String(e["cls"])
	return ""

# 노드 종 id인가(로스터 대조·손상 방어).
static func is_node_kind(node_id: String) -> bool:
	return node_class(node_id) != ""

# 전 노드 종 id 목록(테스트·아트 로스터 대조용).
static func node_kinds() -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in NODE_TABLE:
		out.append(String(e["id"]))
	return out

# 이 칸을 부수는 데 드는 타수. ""(일반 돌) = 1 · 광석/혼탄 = 3~1 · 보석/지오드 = 5~2.
# ★[S5-T3 / ADR-0063 결정 3] **곡괭이 티어 감산의 유일한 접점**이다. 도끼가
#   `TreeLedger._effective_hp(e, tier)` 하나로 접힌 것과 동형이라, main 배선은 인자 하나만 늘었다.
#   감산 규칙표는 ToolTier가 들고(수치 복제 0) 여기선 부류 → 어느 표인지만 가른다.
# ★ tier 기본값 0이라 **인자 없는 기존 호출은 거동 불변**이다(mining_test·드로우 호출부 회귀 0).
static func node_hits(node_id: String, tier: int = 0) -> int:
	match node_class(node_id):
		NODE_ORE, NODE_COAL: return ToolTier.pickaxe_ore_hits(tier)
		NODE_GEM, NODE_GEODE: return ToolTier.pickaxe_gem_hits(tier)
	return ROCK_HITS

# ── 층·밴드 조회(순수 상수 함수) ─────────────────────────────────────────────
static func is_valid_floor(floor_no: int) -> bool:
	return floor_no >= 1 and floor_no <= MAX_FLOOR

# 이 층이 속한 밴드 id("" = 범위 밖). 경계는 20/21·40/41이다(ADR-0063 결정 1).
static func band_of(floor_no: int) -> String:
	var i := band_index(floor_no)
	return String(BANDS[i]) if i >= 0 else ""

# 밴드 인덱스(0=잿길 / 1=넋골 / 2=업화, -1 = 범위 밖).
static func band_index(floor_no: int) -> int:
	if not is_valid_floor(floor_no):
		return -1
	return mini((floor_no - 1) / BAND_SPAN, BANDS.size() - 1)

static func band_name(band: String) -> String:
	return String(BAND_NAMES.get(band, ""))

# 도달 깊이 이하의 엘리베이터 체크포인트 목록(오름차순). depth 17 → [5, 10, 15].
# 1층은 갱도 입구 자체라 목록에 없다(입구 = 항상 열린 기본 진입).
static func elevator_floors(depth: int) -> Array[int]:
	var out: Array[int] = []
	var d := clampi(depth, 0, MAX_FLOOR)
	var f := ELEVATOR_STEP
	while f <= d:
		out.append(f)
		f += ELEVATOR_STEP
	return out

# ── 층 생성(결정적 순수 함수 — 이 파일의 심장) ────────────────────────────────
# 반환 = {"floor", "band", "template", "rect", "entrance", "ladder", "rocks"}.
#   · rect     = 방 사각(그리드 안, 테두리 벽 최소 1칸 확보)
#   · entrance = 올라가는 사다리(= 이 층에 착지하는 칸)
#   · ladder   = 내려가는 사다리 1개 **확정 배치**(스타듀 95%→100% 단순화 — 갇힘 방지)
#   · rocks    = 깰 수 있는 돌 좌표(★S5-T2에서도 **불변** — 노드는 이 목록 위의 오버레이다)
#   · nodes    = ★[S5-T2] {Vector2i: 노드 종 id} — `rocks`의 부분집합만 키로 갖는다
#   · shimmers = ★[S5-T8] [{"id","tile"}] 바닥 반짝이 0~2개(돌·사다리·입구·상자 칸과 배타)
# 범위 밖 층은 **빈 Dictionary**를 돌려준다(61층 거부 — 호출 측이 is_empty로 가른다).
# ★[S7-T3 / ADR-0065 결정 4] `mob_scale` = 잡귀 마리 수 배수(기본 1.0 = 정확히 중립). 혼불 바람이
#   부는 날 main이 1.5를 넘긴다. **기본값 호출의 결과열은 한 비트도 안 변한다** — 마리 수 롤 자체는
#   배수와 무관하게 같은 자리에서 한 번 굴러가고(⑧ 참조), 배수는 그 결과에 곱해질 뿐이다.
#   ⚠️ 배수가 1.0이 아니면 몹 루프의 소비 횟수가 갈려 ⑩ 반짝이 배치가 함께 흔들린다. 이건 사고가
#     아니라 정의다 — 날씨도 day 파생이라 "그날의 층"은 여전히 완전 결정적이다.
static func generate(day: int, floor_no: int, mob_scale: float = 1.0) -> Dictionary:
	if not is_valid_floor(floor_no):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mine:%d:%d" % [day, floor_no])
	# ① 템플릿 롤(순차 소비 1)
	var pool := templates()
	var tpl: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var sz: Vector2i = tpl["size"]
	# ② 방 위치 지터(순차 소비 2·3) — 사방에 최소 1칸 벽을 남긴다.
	var slack_x := maxi(FLOOR_W - sz.x - 2, 0)
	var slack_y := maxi(FLOOR_H - sz.y - 2, 0)
	var rect := Rect2i(1 + rng.randi_range(0, slack_x), 1 + rng.randi_range(0, slack_y), sz.x, sz.y)
	# ③ 입구(올라가는 사다리) 롤(순차 소비 4·5)
	var entrance := Vector2i(rect.position.x + rng.randi_range(0, sz.x - 1),
		rect.position.y + rng.randi_range(0, sz.y - 1))
	# ④ 내려가는 사다리 = 입구를 방 중심에 대해 점대칭시킨 자리 + 소폭 지터(순차 소비 6·7).
	#    재롤 루프 대신 대칭을 쓰는 이유: 입구와 사다리가 항상 방 반대편에 서서 "층을 가로질러
	#    내려간다"는 동선이 보장되고, 루프 없는 고정 소비라 결정성 추론이 쉽다.
	var mirror := Vector2i(rect.position.x + rect.end.x - 1 - entrance.x,
		rect.position.y + rect.end.y - 1 - entrance.y)
	var ladder := Vector2i(
		clampi(mirror.x + rng.randi_range(-2, 2), rect.position.x, rect.end.x - 1),
		clampi(mirror.y + rng.randi_range(-2, 2), rect.position.y, rect.end.y - 1))
	if ladder == entrance:
		# 방 중앙에 입구가 떨어진 축퇴 케이스 — 한 칸 밀어 겹침을 없앤다(무작위 아님, 결정적).
		ladder.x = entrance.x + 1 if entrance.x + 1 < rect.end.x else entrance.x - 1
	# ⑤ 돌 스캐터(순차 소비 8~) — 방 칸을 좌→우·위→아래 고정 순서로 훑으며 밀도 롤.
	#    입구·사다리와 그 십자 인접 칸은 비운다(사다리를 돌로 봉하지 않는다).
	var density: float = float(tpl["density"]) + float(band_index(floor_no)) * 0.03  # 깊을수록 촘촘(*잠정*)
	var rocks: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t := Vector2i(x, y)
			if _near(t, entrance) or _near(t, ladder):
				continue
			if rng.randf() < density:
				rocks.append(t)
	# ⑥ 도달성 보증 — 입구에서 사다리까지 걸어갈 수 없으면 L자 복도의 돌만 걷어낸다.
	#    (밀도가 낮아 대개 이미 연결돼 있고, 이 보정은 드물게만 발동한다 = 직선 복도가 눈에 안 띈다.)
	if not _connected(rect, entrance, ladder, rocks):
		rocks = _carve_corridor(entrance, ladder, rocks)
	# ⑦ ★[S5-T2] 노드 승격(순차 소비 **맨 뒤** — 앞 롤을 한 번도 안 건드린다).
	#    ⑥의 복도 파기는 RNG를 소비하지 않으므로, 여기가 rocks 확정 직후다.
	var nodes := _scatter_nodes(rng, floor_no, rocks)
	# ⑧ ★[S5-T5] 잡귀 스폰(순차 소비 **맨 뒤** — T2 노드 롤 뒤에 붙었다. 앞에 끼우면 노드·돌·방이
	#    통째로 갈린다: mining_test ②/②b 골든 서명이 그 즉시 터진다 = 조기 경보).
	var mobs := _scatter_mobs(rng, floor_no, rect, rocks, entrance, ladder, mob_scale)
	var out := {
		"floor": floor_no,
		"band": band_of(floor_no),
		"template": String(tpl["id"]),
		"rect": rect,
		"entrance": entrance,
		"ladder": ladder,
		"rocks": rocks,
		"nodes": nodes,
		"mobs": mobs,
	}
	# ⑨ ★[S5-T6] 보상 층 상자 자리 — **RNG를 안 쓴다**(방 중심 최근접 빈 칸 계산. chest_tile 주석 참조).
	#    비-보상 층은 (-1,-1)이라 "상자 없음"이 값 하나로 표현된다.
	out["chest"] = chest_tile(out)
	# ⑩ ★[S5-T8] 바닥 반짝이(줍기 광물) — 순차 소비 **맨 뒤**다. T2 노드·T5 몹이 각자 "맨 뒤 승격"으로
	#    붙은 그 규율 그대로라, T1/T2/T5 골든 서명(mining_test ②·②b, mob_test ④)이 한 칸도 안 흔들린다.
	#    ⑨는 RNG를 안 쓰므로 몹 롤 직후가 곧 여기다(상자 자리를 알고 나서 굴려야 상자 칸을 피한다).
	out["shimmers"] = _scatter_shimmers(rng, floor_no, rect, rocks, entrance, ladder, out["chest"])
	return out

# ── ★[S5-T5 / ADR-0063 결정 8] 잡귀 스폰 ─────────────────────────────────────
# 층 생성 시 3~6마리 결정 롤. 종 데이터·밴드 게이팅은 MobCatalog가 들고(수치 복제 0 — ToolTier에
# 타수 표를 위임한 것과 같은 자리) 이 파일은 **어디에 서는가**만 정한다.
#
# ★ 왜 층 한정 비영속인가(ADR-0063 결정 8): 스타듀도 층 재진입 시 몹을 재생성한다. 그래서
#   day-한정 *처치 원장*조차 없다 — 그날 다 잡은 층에 다시 내려가면 새 잡귀가 서 있는 게 맞고,
#   그게 "몹 전멸 +4%"를 재파밍 exploit으로 만들지도 않는다(층을 나갔다 오는 왕복 비용이 더 크다).
#   ⇒ 그래서 `_mined`/`_node_hits` 같은 원장 필드가 몹에는 **없다**(to_save에 한 줄도 안 늘었다).
const MOB_MIN := 3
const MOB_MAX := 6
const MOB_PICK_TRIES := 8         # 좌표 중복·부적격 회피 재시도 상한(무한 루프 방지)
const MOB_SPAWN_CLEAR := 3        # 입구에서 이 칸 수 안에는 안 세운다(착지 즉시 얻어맞지 않게)
# ★ 보상 층(10의 배수) = **몹 없음**(ADR-0063 결정 10 "10의 배수 층 = 몹 없음·1회성 상자").
#   상자 본체는 후속(T7/T10)이지만 "몹이 안 나온다"는 스폰 쪽 불변식이라 여기서 지킨다 — 5층마다
#   엘리베이터, 10층마다 숨 돌리는 층이라는 리듬이 몹 배치와 함께 성립해야 의미가 있다.
const MOB_FREE_FLOOR_STEP := 10

# 이 층에 몹이 스폰되는 층인가(보상 층 제외).
static func spawns_mobs(floor_no: int) -> bool:
	return is_valid_floor(floor_no) and not is_reward_floor(floor_no)

# ── ★[S5-T6 / ADR-0063 결정 10] 보상 층 상자 ─────────────────────────────────
# 10의 배수 층 = 몹 0(위 `spawns_mobs`가 이미 보장) + **1회성 상자 1개**. "5층마다 엘리베이터,
# 10층마다 숨 돌리는 층"이라는 리듬의 나머지 반쪽이다.
#
# ★ **RNG를 한 번도 안 굴린다.** 상자 자리는 방 중심에서 가장 가까운 빈 칸으로 *계산*한다:
#   ㉠ 스트림을 안 건드리니 T1/T2/T5 골든 서명(mining_test ②·mob_test ④)이 정의상 안전하다
#   ㉡ 보물방의 상자는 한가운데 있는 게 읽히는 배치다(찾아 헤매는 층이 아니라 숨 돌리는 층이다)
#   ㉢ 결정성 추론이 "정렬 규칙 하나"로 끝난다(재롤 루프 없음).
# ★ 개봉 원장은 **영구**다(day-한정 아님 — `_chests`). 층 배치는 매일 리필되지만 상자는 한 번뿐이라
#   `advance_day`가 이 기록만 안 지운다(재파밍 차단의 유일한 방어선).
const REWARD_FLOOR_STEP := MOB_FREE_FLOOR_STEP   # 보상 층 간격 = 몹 없는 층 간격과 **같은 축**(10)

# 보상 내용물의 아이템 id — ★ItemCatalog 상수와 *같은 문자열*이다(노드 id 규약 동형: 원장은
# 인벤토리를 모르지만 문자열은 공유한다. guild_test가 `ItemCatalog.has_item`으로 전량 대조해
# 두 로스터가 조용히 갈라지는 걸 막는다).
const REWARD_SWORD := "sword_myeongdong"    # 명동검(깊이 10 해금분 — 10층 상자가 **대체 입수**를 준다)
const REWARD_POTION := "myeongbuhwan"       # 명부환(회복 소모품 — 20~50층 상자의 뼈대)
const REWARD_KEY := "narak_key"             # 나락 열쇠(60층 — Skull Key 1:1)

# 층 → 보상 행 목록. 행 = {"kind": "item", "id": String, "count": int} 또는 {"kind": "gold", "amount": int}.
# *구성·수치 전부 잠정*(owner 큐 — ADR-0063 결정 10 "내용 잠정 · 부츠·반지는 서랍이라 무기·소모품·
# 골드로 대체"). 곡선 의도: 10층은 **물건**(다음 티어 검을 사는 대신 얻는다), 20~50층은 다음 밴드로
# 내려갈 **연료**(환약)와 다음 검 값의 마중물(골드), 60층은 오직 열쇠 하나(엔드게임 문).
const REWARD_TABLE := {
	10: [{"kind": "item", "id": REWARD_SWORD, "count": 1}],
	20: [{"kind": "item", "id": REWARD_POTION, "count": 3}, {"kind": "gold", "amount": 500}],
	30: [{"kind": "item", "id": REWARD_POTION, "count": 5}, {"kind": "gold", "amount": 1000}],
	40: [{"kind": "item", "id": REWARD_POTION, "count": 5}, {"kind": "gold", "amount": 2500}],
	50: [{"kind": "item", "id": REWARD_POTION, "count": 8}, {"kind": "gold", "amount": 4000}],
	60: [{"kind": "item", "id": REWARD_KEY, "count": 1}],
}

# 이 층이 보상 층(10의 배수)인가.
static func is_reward_floor(floor_no: int) -> bool:
	return is_valid_floor(floor_no) and floor_no % REWARD_FLOOR_STEP == 0

# 이 층 상자의 내용물(보상 층이 아니면 빈 배열). 사본을 돌려준다 — 호출 측이 골드 대체(10층 중복
# 방지) 같은 변형을 얹어도 상수 테이블이 오염되지 않게.
static func chest_rewards(floor_no: int) -> Array:
	if not is_reward_floor(floor_no):
		return []
	var out: Array = []
	for row: Dictionary in REWARD_TABLE.get(floor_no, []):
		out.append(row.duplicate())
	return out

# 상자가 놓이는 칸 — 방 중심에 가장 가까운 빈 칸(돌·입구·사다리 제외). 후보를 (중심거리, y, x)로
# 정렬해 첫 칸을 고르므로 **완전 결정적**이고 RNG 소비가 0이다. 보상 층이 아니거나 빈 칸이 하나도
# 없으면 Vector2i(-1, -1)(= 상자 없음 — 호출 측이 그 값으로 가른다).
static func chest_tile(layout: Dictionary) -> Vector2i:
	if layout.is_empty() or not is_reward_floor(int(layout.get("floor", 0))):
		return Vector2i(-1, -1)
	var rect: Rect2i = layout["rect"]
	var entrance: Vector2i = layout["entrance"]
	var ladder: Vector2i = layout["ladder"]
	var blocked: Dictionary = {entrance: true, ladder: true}
	for r: Vector2i in layout["rocks"]:
		blocked[r] = true
	# 중심은 짝수 폭에서 반 칸이 뜨므로 정수로 내린다(결정적 — 부동소수 비교를 안 만든다).
	var cx := rect.position.x + rect.size.x / 2
	var cy := rect.position.y + rect.size.y / 2
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t := Vector2i(x, y)
			if blocked.has(t):
				continue
			var d := absi(x - cx) + absi(y - cy)
			if d < best_d:      # 동률이면 먼저 만난 칸(위→아래·왼→오른) = y·x 순 tie-break
				best_d = d
				best = t
	return best

# 잡귀 배치 = [{"kind": String, "tile": Vector2i}] — 순수 스펙이다(개체는 main이 Mob.spawn으로 세운다).
#   ① 마리 수 롤(3~6) ② 마리마다 좌표 롤(돌·사다리·입구 둘레 배제) ③ 종 가중 롤.
#   ②③을 마리 단위로 번갈아 소비한다(좌표 전부 → 종 전부 순서가 아니다 — 마리 수가 갈리면
#   스트림이 어긋나는 건 어느 쪽이든 같고, 마리 단위가 읽기 쉽다).
static func _scatter_mobs(rng: RandomNumberGenerator, floor_no: int, rect: Rect2i,
		rocks: Array, entrance: Vector2i, ladder: Vector2i, mob_scale: float = 1.0) -> Array:
	var out: Array = []
	if not spawns_mobs(floor_no):
		return out
	var pool := MobCatalog.spawn_pool(floor_no)
	if pool.is_empty():
		return out
	var blocked: Dictionary = {}
	for r: Vector2i in rocks:
		blocked[r] = true
	blocked[entrance] = true
	blocked[ladder] = true
	# ★[S7-T3] 마리 수 롤은 배수와 **무관하게 먼저** 굴린다(스트림 고정) — 배수는 그 뒤에 곱한다.
	var quota := int(round(float(rng.randi_range(MOB_MIN, MOB_MAX)) * maxf(mob_scale, 0.0)))
	var used: Dictionary = {}
	for _i in range(quota):
		var tile := Vector2i(-1, -1)
		for _try in range(MOB_PICK_TRIES):
			var t := Vector2i(rect.position.x + rng.randi_range(0, rect.size.x - 1),
				rect.position.y + rng.randi_range(0, rect.size.y - 1))
			if blocked.has(t) or used.has(t):
				continue
			if absi(t.x - entrance.x) + absi(t.y - entrance.y) <= MOB_SPAWN_CLEAR:
				continue
			tile = t
			break
		var kind := MobCatalog.roll_kind(pool, rng)   # ★자리를 못 찾아도 **롤은 굴린다**(스트림 고정)
		if tile == Vector2i(-1, -1) or kind == "":
			continue
		used[tile] = true
		out.append({"kind": kind, "tile": tile})
	return out

# ── ★[S5-T8 / ADR-0063 결정 10] 바닥 반짝이(줍기 광물) ───────────────────────
# ADR-0033이 배정해 두고 S4에서 이연된 "갱도 바닥 광물 줍기"의 무대 형태. 곡괭이가 아니라 **손**으로
# 줍는 물건이라 축이 통째로 다르다:
#   · 혼력 0 · **채집 XP 7**(채광 XP 아님 — ADR-0033/0063이 명시적으로 ForageSkill 축에 뒀다.
#     "허리 굽혀 줍는 것"은 전부 채집이라는 이 코드베이스의 일관된 문법 — 꽃 패치·덤불과 같은 값이다)
#   · 돌이 아니라 **바닥 위 물건**이라 그리드(WALL/PATH/ROCK)에 한 칸도 안 들어간다(사다리·상자 결)
#
# ★ 품목은 **기존 MINERALS 로스터에서만** 고른다(신규 아이템 0). ADR-0063 원문 "품목 = 혼탄·석영
#   결 잡광물"의 이행이고, 넋수정이 ItemCatalog에서 이미 "석영 결"로 정의돼 있다. 돌이 섞이는 건
#   계단(돌 99개) 사슬의 바닥을 조금 깔아 주기 위해서다(*가중치 전부 잠정 — owner 큐*).
# ★ 반짝이 id도 **아이템 id와 같은 문자열**이다(노드 id 규약 동형 — 원장은 인벤토리를 모르지만
#   문자열은 공유한다. mine_extras_test가 ItemCatalog.has_item으로 전량 대조한다).
const S_HONTAN := "hontan"                    # 혼탄(= ItemCatalog.HONTAN)
const S_STONE := "stone"                      # 돌(= ItemCatalog.STONE)
const S_QUARTZ := "gem_neoksujeong"           # 넋수정 — 석영 결(= ItemCatalog.GEM_NEOKSUJEONG)

const SHIMMER_MIN := 0                        # 층당 0~2개(ADR-0063 결정 10 원문)
const SHIMMER_MAX := 2
const SHIMMER_PICK_TRIES := 8                 # 좌표 중복·부적격 회피 재시도 상한(무한 루프 방지)
const SHIMMER_TABLE := [
	{"id": S_HONTAN, "weight": 45},
	{"id": S_STONE, "weight": 35},
	{"id": S_QUARTZ, "weight": 20},
]

# 반짝이 종 id 목록(테스트·아트 로스터 대조용).
static func shimmer_kinds() -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in SHIMMER_TABLE:
		out.append(String(e["id"]))
	return out

static func is_shimmer_kind(id: String) -> bool:
	return shimmer_kinds().has(id)

# 반짝이 배치 = [{"id": String, "tile": Vector2i}] — 몹 스캐터와 같은 문법이다(마리 단위 좌표→종
# 번갈아 소비, 자리를 못 찾아도 종 롤은 굴려 스트림을 고정). 돌·입구·사다리·상자 칸은 배제한다
# (상자 칸을 비우는 이유: 한 칸에서 [F]가 둘로 갈리면 어느 쪽이 먼저인지 규칙이 하나 더 는다).
static func _scatter_shimmers(rng: RandomNumberGenerator, floor_no: int, rect: Rect2i,
		rocks: Array, entrance: Vector2i, ladder: Vector2i, chest: Vector2i) -> Array:
	var out: Array = []
	if not is_valid_floor(floor_no):
		return out
	var blocked: Dictionary = {}
	for r: Vector2i in rocks:
		blocked[r] = true
	blocked[entrance] = true
	blocked[ladder] = true
	if chest.x >= 0:
		blocked[chest] = true
	var total_w := 0
	for e: Dictionary in SHIMMER_TABLE:
		total_w += int(e["weight"])
	var quota := rng.randi_range(SHIMMER_MIN, SHIMMER_MAX)
	var used: Dictionary = {}
	for _i in range(quota):
		var tile := Vector2i(-1, -1)
		for _try in range(SHIMMER_PICK_TRIES):
			var t := Vector2i(rect.position.x + rng.randi_range(0, rect.size.x - 1),
				rect.position.y + rng.randi_range(0, rect.size.y - 1))
			if blocked.has(t) or used.has(t):
				continue
			tile = t
			break
		var roll := rng.randi_range(0, total_w - 1)   # ★자리를 못 찾아도 **롤은 굴린다**(스트림 고정)
		var pick := String(SHIMMER_TABLE[SHIMMER_TABLE.size() - 1]["id"])
		for e: Dictionary in SHIMMER_TABLE:
			roll -= int(e["weight"])
			if roll < 0:
				pick = String(e["id"])
				break
		if tile == Vector2i(-1, -1):
			continue
		used[tile] = true
		out.append({"id": pick, "tile": tile})
	return out

# ★[S5-T2] 확정된 돌 목록 일부를 노드로 승격 — {Vector2i: 노드 종 id}. rocks는 읽기만 한다.
#   ① 노드 개수 롤(3~7, 돌 수 상한) ② 승격할 돌 인덱스 뽑기(중복은 건너뜀·재시도 상한 있음)
#   ③ 인덱스 오름차순으로 종 가중 롤. 전 단계가 같은 rng를 정해진 순서로 소비한다(결정적).
static func _scatter_nodes(rng: RandomNumberGenerator, floor_no: int, rocks: Array) -> Dictionary:
	var nodes: Dictionary = {}
	var pool := node_pool(floor_no)
	if rocks.is_empty() or pool.is_empty():
		return nodes
	var quota := mini(rng.randi_range(NODE_MIN, NODE_MAX), rocks.size())
	var total_w := 0
	for e: Dictionary in pool:
		total_w += int(e["weight"])
	if total_w <= 0:
		return nodes
	var chosen: Dictionary = {}
	var tries := 0
	while chosen.size() < quota and tries < quota * NODE_PICK_TRIES:
		tries += 1
		chosen[rng.randi_range(0, rocks.size() - 1)] = true
	var idx: Array = chosen.keys()
	idx.sort()   # 좌표 순서를 dict 키 순서에 안 기댄다(결정성)
	for i: int in idx:
		var roll := rng.randi_range(0, total_w - 1)
		var pick: String = String(pool[pool.size() - 1]["id"])   # 폴백(부동소수 없음 — 도달 안 함)
		for e: Dictionary in pool:
			roll -= int(e["weight"])
			if roll < 0:
				pick = String(e["id"])
				break
		nodes[rocks[i]] = pick
	return nodes

# 두 칸이 같거나 십자 인접인가(입구·사다리 둘레 비우기 판정).
static func _near(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) <= 1

# 방 안에서 from → to가 4방향으로 이어지는가(돌 = 벽). 층 생성 안에서만 쓰는 flood-fill.
static func _connected(rect: Rect2i, from: Vector2i, to: Vector2i, rocks: Array) -> bool:
	var blocked := {}
	for r in rocks:
		blocked[r] = true
	var seen := {from: true}
	var stack: Array[Vector2i] = [from]
	while not stack.is_empty():
		var t: Vector2i = stack.pop_back()
		if t == to:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + d
			if seen.has(n) or blocked.has(n) or not rect.has_point(n):
				continue
			seen[n] = true
			stack.append(n)
	return seen.has(to)

# L자 복도(가로 먼저 → 세로) 위의 돌만 걷어낸 새 목록. 원본 순서는 보존한다(결정적).
static func _carve_corridor(from: Vector2i, to: Vector2i, rocks: Array) -> Array[Vector2i]:
	var corridor := {}
	var step_x := 1 if to.x >= from.x else -1
	for x in range(from.x, to.x + step_x, step_x):
		corridor[Vector2i(x, from.y)] = true
	var step_y := 1 if to.y >= from.y else -1
	for y in range(from.y, to.y + step_y, step_y):
		corridor[Vector2i(to.x, y)] = true
	var out: Array[Vector2i] = []
	for r: Vector2i in rocks:
		if not corridor.has(r):
			out.append(r)
	return out

# ── 돌 파괴 사다리 롤(순수 함수 + 결정적 롤) ──────────────────────────────────
# 확률만 계산한다(테스트가 단조성을 직접 단언할 수 있게 롤과 분리).
#   stones_left  = 이 층에 **아직 안 깬** 돌 수(깨고 난 뒤 기준)
#   mobs_cleared = 층의 몹을 전부 잡았나(몹 본체 = S5-T5 — 지금 호출부는 false 고정)
#   luck_bonus   = 명부의 운 가산(운 시스템 실배선 = 해당 시스템 빌드 시 — 지금은 0.0)
static func ladder_chance(stones_left: int, mobs_cleared: bool = false, luck_bonus: float = 0.0) -> float:
	var c := LADDER_BASE + 1.0 / float(maxi(stones_left, 0) + 1)
	if mobs_cleared:
		c += LADDER_MOBS_CLEARED
	c += luck_bonus
	return clampf(c, 0.0, 1.0)

# 이 돌을 깼을 때 사다리가 열리는가. 시드에 **돌 좌표를 포함**해 같은 (day,층,칸)이면 몇 번을
# 굴려도 같은 결과다(헤드리스 재현성). 확률만 stones_left에 따라 움직인다.
static func roll_ladder(day: int, floor_no: int, tile: Vector2i, stones_left: int,
		mobs_cleared: bool = false, luck_bonus: float = 0.0) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mine_ladder:%d:%d:%d:%d" % [day, floor_no, tile.x, tile.y])
	return rng.randf() < ladder_chance(stones_left, mobs_cleared, luck_bonus)

# ★[S5-T5 / ADR-0063 결정 1 ㉢] 몹을 잡았을 때 사다리가 열리는가 — 고정 15%.
#   시드에 **스폰 인덱스**를 넣는다(좌표가 아니다): 몹은 죽는 자리가 매번 다르므로 좌표 시드면 같은
#   몹을 다른 자리에서 잡아 리롤하는 exploit이 생긴다. 스폰 인덱스는 층 배치가 정한 불변값이라
#   "저 잡귀를 잡으면 사다리가 나온다"가 그날 그 층에 대해 한 번 정해진다(결정성 + exploit 0).
#   ★ 돌 파괴 롤(`roll_ladder`)과 별 축이라 `stones_left`·`mobs_cleared`가 여기 안 낀다.
static func roll_mob_ladder(day: int, floor_no: int, spawn_index: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mine_mob_ladder:%d:%d:%d" % [day, floor_no, spawn_index])
	return rng.randf() < LADDER_MOB_KILL

# ── 원장 상태 ────────────────────────────────────────────────────────────────
signal changed()   # 채굴·사다리 개통·깊이 갱신·리셋·복원한 프레임(main이 드로우·HUD 갱신)

var _day: int = 0              # 원장이 붙어 있는 날(이 값이 갈리면 day-한정 기록 전량 소멸)
var _mined: Dictionary = {}    # {floor(int) → {Vector2i: true}} 그날 깬 돌
var _ladders: Dictionary = {}  # {floor(int) → {Vector2i: true}} 돌을 깨 열린 추가 사다리
# ★[S5-T2] {floor(int) → {Vector2i: 누적 타수}} 다타수 노드의 진행. `_mined`(깼나)와 **별개 축**이다
#   — 노드는 3~5타라 "아직 안 깼지만 두 대 맞은" 중간 상태가 존재한다(TreeLedger의 나무 hp 선례).
#   day-한정(깬 돌과 같은 결 — 날이 갈리면 층이 리필되므로 진행도 함께 소멸한다).
var _node_hits: Dictionary = {}
# ★[S5-T8] {floor(int) → {Vector2i: true}} 그날 주운 바닥 반짝이. **day-한정**이다(깬 돌과 정확히
#   같은 수명 — 층이 매일 리필되면 바닥의 물건도 새로 놓인다). 배치는 순수 함수가 다시 파생하므로
#   여기 남는 건 "무엇을 이미 주웠나"뿐이다(`_mined`와 완전 동형 — 재파밍 차단의 같은 문법).
var _picked: Dictionary = {}
var _depth: int = 0            # 도달 최심층(영구 — 엘리베이터 체크포인트의 유일 파생원)
# ★[S5-T6] {floor(int) → true} 이미 연 보상 상자. **영구**다(day-한정 아님 — `advance_day`가 안 지운다).
#   층 배치·채굴 기록은 매일 리필되지만 상자는 세이브 전체를 통틀어 한 번뿐이라, 이 dict가 재파밍의
#   유일한 차단선이다(그래서 `_mined`·`_ladders`·`_node_hits`와 **같은 자리에 두되 다른 수명**이다).
var _chests: Dictionary = {}

# ── 하루 경과(day 리셋 훅) ───────────────────────────────────────────────────
# 날이 바뀌면 전 층이 리필된다 = day-한정 기록(깬 돌·열린 사다리)이 전량 소멸한다. 배치 자체는
# 시드가 day를 물고 있어 저절로 갈린다(원장이 배치를 들지 않는 이유).
func advance_day(day: int) -> void:
	if day == _day:
		return
	_day = day
	_mined = {}
	_ladders = {}
	_node_hits = {}   # ★[S5-T2] 반쯤 쪼갠 광맥도 함께 리셋(층 리필 = 노드도 새 판)
	_picked = {}      # ★[S5-T8] 주운 반짝이도 리셋(바닥의 물건도 매일 새로 놓인다)
	# ★[S5-T6] `_chests`는 **여기서 안 지운다** — 보상 상자는 영구 1회성이다(ADR-0063 결정 10).
	changed.emit()

func current_day() -> int:
	return _day

# ── 채굴 기록 ────────────────────────────────────────────────────────────────
func is_mined(floor_no: int, tile: Vector2i) -> bool:
	return _mined.has(floor_no) and _mined[floor_no].has(tile)

func mark_mined(floor_no: int, tile: Vector2i) -> void:
	if not _mined.has(floor_no):
		_mined[floor_no] = {}
	_mined[floor_no][tile] = true
	if _node_hits.has(floor_no):
		_node_hits[floor_no].erase(tile)   # ★[S5-T2] 다 깬 노드의 진행 기록은 남길 이유가 없다
	changed.emit()

func mined_count(floor_no: int) -> int:
	return int(_mined[floor_no].size()) if _mined.has(floor_no) else 0

# ── ★[S5-T2] 다타수 노드 진행(day-한정) ──────────────────────────────────────
# 이 칸에 지금까지 몇 대 맞았나(0 = 손 안 댐).
func node_hits_done(floor_no: int, tile: Vector2i) -> int:
	if not _node_hits.has(floor_no):
		return 0
	return int(_node_hits[floor_no].get(tile, 0))

# 한 대 친다 → 누적 타수를 돌려준다. "몇 대면 깨지나"는 호출 측이 안다(node_hits) — 원장은
# 세기만 하고 파괴 판정을 안 한다(mark_mined가 그 사건의 유일한 기록자 = 책임 분리).
func add_node_hit(floor_no: int, tile: Vector2i) -> int:
	if not _node_hits.has(floor_no):
		_node_hits[floor_no] = {}
	var n := int(_node_hits[floor_no].get(tile, 0)) + 1
	_node_hits[floor_no][tile] = n
	changed.emit()
	return n

# ── ★[S5-T8] 바닥 반짝이 줍기 원장(day-한정) ─────────────────────────────────
func is_picked(floor_no: int, tile: Vector2i) -> bool:
	return _picked.has(floor_no) and _picked[floor_no].has(tile)

func mark_picked(floor_no: int, tile: Vector2i) -> void:
	if not _picked.has(floor_no):
		_picked[floor_no] = {}
	_picked[floor_no][tile] = true
	changed.emit()

# 이 층에 **아직 안 주운** 반짝이 목록([{"id","tile"}] — 배치 − 그날 주운 것). `rocks_left` 동형.
func shimmers_left(day: int, floor_no: int) -> Array:
	var out: Array = []
	var layout := generate(day, floor_no)
	if layout.is_empty():
		return out
	for e: Dictionary in layout.get("shimmers", []):
		if not is_picked(floor_no, e["tile"]):
			out.append(e)
	return out

# 이 칸의 반짝이 종("" = 없거나 이미 주웠다). 라이브 경로는 main이 층 배치 캐시에서 직접 읽는다.
func shimmer_at(day: int, floor_no: int, tile: Vector2i) -> String:
	if is_picked(floor_no, tile):
		return ""
	var layout := generate(day, floor_no)
	if layout.is_empty():
		return ""
	for e: Dictionary in layout.get("shimmers", []):
		if e["tile"] == tile:
			return String(e["id"])
	return ""

# 이 칸의 노드 종("" = 일반 돌이거나 층 밖). 배치는 순수 함수에서 다시 파생한다(rocks_left 결).
func node_at(day: int, floor_no: int, tile: Vector2i) -> String:
	var layout := generate(day, floor_no)
	if layout.is_empty():
		return ""
	return String((layout["nodes"] as Dictionary).get(tile, ""))

# 이 층에 **아직 남아 있는** 돌 좌표(배치 − 그날 깬 것). 배치는 순수 함수에서 다시 파생한다.
func rocks_left(day: int, floor_no: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var layout := generate(day, floor_no)
	if layout.is_empty():
		return out
	for t: Vector2i in layout["rocks"]:
		if not is_mined(floor_no, t):
			out.append(t)
	return out

func rocks_left_count(day: int, floor_no: int) -> int:
	return rocks_left(day, floor_no).size()

# ── 돌을 깨 열린 추가 사다리(day-한정) ───────────────────────────────────────
func add_ladder(floor_no: int, tile: Vector2i) -> void:
	if not _ladders.has(floor_no):
		_ladders[floor_no] = {}
	_ladders[floor_no][tile] = true
	changed.emit()

func has_ladder(floor_no: int, tile: Vector2i) -> bool:
	return _ladders.has(floor_no) and _ladders[floor_no].has(tile)

# 이 층의 내려가는 사다리 전부(확정 배치 1개 + 돌을 깨 열린 것들). 정렬해 결정적으로 돌려준다.
func ladders(day: int, floor_no: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var layout := generate(day, floor_no)
	if layout.is_empty():
		return out
	out.append(layout["ladder"])
	if _ladders.has(floor_no):
		var extra: Array = _ladders[floor_no].keys()
		extra.sort()
		for t: Vector2i in extra:
			if t != layout["ladder"]:
				out.append(t)
	return out

# ── 도달 깊이(영구) ──────────────────────────────────────────────────────────
func depth() -> int:
	return _depth

func reach_floor(floor_no: int) -> void:
	if not is_valid_floor(floor_no) or floor_no <= _depth:
		return
	_depth = floor_no
	changed.emit()

# 지금 열려 있는 엘리베이터 체크포인트(도달 깊이 파생).
func unlocked_elevators() -> Array[int]:
	return elevator_floors(_depth)

# ── ★[S5-T6] 보상 상자 개봉 원장(영구) ───────────────────────────────────────
func is_chest_opened(floor_no: int) -> bool:
	return _chests.has(floor_no)

# 상자를 연 것으로 기록한다 → **처음 여는 것이었으면 true**. 이미 열었거나 보상 층이 아니면 false다
# (mark_mined처럼 "기록만" 하는 게 아니라 판정까지 여기서 접는 이유: 개봉은 되돌릴 수 없는 1회성
#  사건이라 "확인 후 기록" 두 걸음 사이에 끼어들 틈을 아예 안 만드는 게 안전하다).
func open_chest(floor_no: int) -> bool:
	if not is_reward_floor(floor_no) or _chests.has(floor_no):
		return false
	_chests[floor_no] = true
	changed.emit()
	return true

# 지금까지 연 보상 층 목록(오름차순 — HUD·테스트·후속 슬라이스 조회용).
func opened_chests() -> Array[int]:
	var out: Array[int] = []
	var keys: Array = _chests.keys()
	keys.sort()
	for f: int in keys:
		out.append(f)
	return out

# ── 세이브/로드(ForageSpawns·TapperLedger 패턴 계승) — 슬라이스 키 "mine" ──────
# depth = 영구 / day·mined·ladders = day-한정. day를 **함께** 저장해, 로드 뒤 첫 advance_day가
# 날이 같으면 기록을 살리고 다르면 버린다(구세이브·손상 방어 = 지상 0층·depth 0, 무막힘).
func to_save() -> Dictionary:
	return {
		"depth": _depth,
		"day": _day,
		"mined": _dump_tiles(_mined),
		"ladders": _dump_tiles(_ladders),
		"node_hits": _dump_counts(_node_hits),   # ★[S5-T2] 반쯤 쪼갠 광맥(키 없는 구세이브 = 진행 0)
		"chests": opened_chests(),               # ★[S5-T6] 연 보상 상자(영구 — 키 없는 구세이브 = 전부 미개봉)
		"picked": _dump_tiles(_picked),          # ★[S5-T8] 주운 반짝이(day-한정 — 키 없는 구세이브 = 전부 미획득)
	}

func load_save(data: Dictionary) -> void:
	_depth = clampi(int(data.get("depth", 0)), 0, MAX_FLOOR)
	_day = maxi(int(data.get("day", 0)), 0)
	_mined = _read_tiles(data.get("mined", {}))
	_ladders = _read_tiles(data.get("ladders", {}))
	_node_hits = _read_counts(data.get("node_hits", {}))
	_chests = _read_chests(data.get("chests", []))
	_picked = _read_tiles(data.get("picked", {}))   # ★[S5-T8] 주운 반짝이(깬 돌과 같은 직렬화 결)
	changed.emit()

# ★[S5-T6] 개봉 원장 복원 — 보상 층 번호(10의 배수)만 받는다. 손상·구버전 값은 조용히 버린다
#   (_read_tiles와 같은 방어). 버리는 쪽이 안전한 이유: 못 읽은 상자는 다시 열 수 있을 뿐이지만,
#   엉뚱한 층을 "열림"으로 읽으면 되돌릴 수 없이 보상이 사라진다.
static func _read_chests(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_ARRAY:
		return out
	for e in raw:
		var floor_no := int(e)
		if is_reward_floor(floor_no):
			out[floor_no] = true
	return out

static func _dump_tiles(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for floor_no in src:
		var arr: Array = []
		for t: Vector2i in src[floor_no]:
			arr.append([t.x, t.y])
		out[str(floor_no)] = arr   # 키는 문자열(세이브 왕복에서 int 키가 흔들리지 않게)
	return out

static func _read_tiles(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for key in raw:
		var floor_no := int(str(key).to_int())
		if not is_valid_floor(floor_no):
			continue          # 손상·구버전 층 번호는 조용히 버린다(inventory._sanitize 결)
		var arr: Variant = raw[key]
		if typeof(arr) != TYPE_ARRAY:
			continue
		var by_tile: Dictionary = {}
		for raw_e in arr:
			if typeof(raw_e) != TYPE_ARRAY:
				continue
			var e: Array = raw_e
			if e.size() < 2:
				continue
			by_tile[Vector2i(int(e[0]), int(e[1]))] = true
		if not by_tile.is_empty():
			out[floor_no] = by_tile
	return out

# ★[S5-T2] 타수 진행 직렬화 — 좌표 집합(_dump_tiles)과 달리 **[x, y, 누적타수] 3원소**다.
static func _dump_counts(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for floor_no in src:
		var arr: Array = []
		for t: Vector2i in src[floor_no]:
			arr.append([t.x, t.y, int(src[floor_no][t])])
		if not arr.is_empty():
			out[str(floor_no)] = arr   # 키는 문자열(_dump_tiles와 같은 규약)
	return out

static func _read_counts(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for key in raw:
		var floor_no := int(str(key).to_int())
		if not is_valid_floor(floor_no):
			continue          # 손상·구버전 층 번호는 조용히 버린다(_read_tiles와 같은 방어)
		var arr: Variant = raw[key]
		if typeof(arr) != TYPE_ARRAY:
			continue
		var by_tile: Dictionary = {}
		for raw_e in arr:
			if typeof(raw_e) != TYPE_ARRAY:
				continue
			var e: Array = raw_e
			if e.size() < 3:
				continue
			var n := int(e[2])
			if n <= 0:
				continue      # 0타·음수 기록은 의미가 없다(손상 방어 — 조용히 버린다)
			by_tile[Vector2i(int(e[0]), int(e[1]))] = n
		if not by_tile.is_empty():
			out[floor_no] = by_tile
	return out
