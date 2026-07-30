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
#   - **몹·HP는 여기 없다**(T4 HP / T5 몹 소관). 사다리 롤의 `mobs_cleared`·`luck_bonus`는 그
#     시스템들이 붙을 자리를 미리 연 **인자 자리**일 뿐이다.
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
const LADDER_MOBS_CLEARED := 0.04  # 층의 몹을 전멸시켰을 때 가산(몹 본체는 S5-T5 — 지금은 인자만)

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
# 범위 밖 층은 **빈 Dictionary**를 돌려준다(61층 거부 — 호출 측이 is_empty로 가른다).
static func generate(day: int, floor_no: int) -> Dictionary:
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
	#    ⑥의 복도 파기는 RNG를 소비하지 않으므로, 여기가 rocks 확정 직후이자 스트림의 끝이다.
	return {
		"floor": floor_no,
		"band": band_of(floor_no),
		"template": String(tpl["id"]),
		"rect": rect,
		"entrance": entrance,
		"ladder": ladder,
		"rocks": rocks,
		"nodes": _scatter_nodes(rng, floor_no, rocks),
	}

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

# ── 원장 상태 ────────────────────────────────────────────────────────────────
signal changed()   # 채굴·사다리 개통·깊이 갱신·리셋·복원한 프레임(main이 드로우·HUD 갱신)

var _day: int = 0              # 원장이 붙어 있는 날(이 값이 갈리면 day-한정 기록 전량 소멸)
var _mined: Dictionary = {}    # {floor(int) → {Vector2i: true}} 그날 깬 돌
var _ladders: Dictionary = {}  # {floor(int) → {Vector2i: true}} 돌을 깨 열린 추가 사다리
# ★[S5-T2] {floor(int) → {Vector2i: 누적 타수}} 다타수 노드의 진행. `_mined`(깼나)와 **별개 축**이다
#   — 노드는 3~5타라 "아직 안 깼지만 두 대 맞은" 중간 상태가 존재한다(TreeLedger의 나무 hp 선례).
#   day-한정(깬 돌과 같은 결 — 날이 갈리면 층이 리필되므로 진행도 함께 소멸한다).
var _node_hits: Dictionary = {}
var _depth: int = 0            # 도달 최심층(영구 — 엘리베이터 체크포인트의 유일 파생원)

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
	}

func load_save(data: Dictionary) -> void:
	_depth = clampi(int(data.get("depth", 0)), 0, MAX_FLOOR)
	_day = maxi(int(data.get("day", 0)), 0)
	_mined = _read_tiles(data.get("mined", {}))
	_ladders = _read_tiles(data.get("ladders", {}))
	_node_hits = _read_counts(data.get("node_hits", {}))
	changed.emit()

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
