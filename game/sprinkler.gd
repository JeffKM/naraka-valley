extends Node
class_name Sprinkler
# S1R-T9 — 저승 스프링클러 티어1(그레이박스). 설치 좌표만 소유하는 얇은 원장(ledger).
#
# 목적: 카탈로그 §1-B(스프링클러) — 물만 자동, 심기/수확은 손. 덮은 칸 물주기 혼력 0.
#       ADR-0059 결정4로 가치 상승(물뿌리개 용량·리필 도입 → 유한 물이라 자동화 편익이 실효).
#       티어1 = 4방 인접(십자) 4칸 자동 급수. 아침 day-advance 시(성장 판정 *전*) 뿌린다.
#
# 왜 별개 노드인가(Reclaim/Orchard/Ranch 동형 완전 분리):
#   - 스프링클러 배치는 플레이어 세이브 델타다(설계 시드가 아님 — 상점 구매 후 자유 설치).
#     Sprinkler는 "어디에 설치됐나"라는 좌표 집합 하나만 소유하고, 지형·화면·물뿌리개 잔량·
#     혼력을 모른다. main이 드로우/자동급수/세이브에서 질의한다(디커플링).
#   - 상태 = Vector2i 키 순수 Dictionary(값 true) → var_to_str 그대로 라운드트립(Reclaim 결).
#
# 티어: **★[S10-T2 / ADR-0069 결정 3] 상위 2티어가 얹혔다** — 위 예약 주석("RANGE 오프셋만 티어별로
#   바꿔 얹는다·급수 로직·배치·세이브는 불변")의 자구 그대로다. 바뀐 것은 두 줄뿐이다:
#     ㉠ 원장 값이 `true` → **티어 정수**가 됐다(키 집합·질의 API는 그대로).
#     ㉡ `watered_targets`가 고정 CROSS_OFFSETS 대신 `offsets_for(tier)`를 읽는다.
#   급수 시점(아침·성장 판정 전)·배치 규칙(main)·세이브 네임스페이스는 한 줄도 안 바뀌었다.
# ★ 구세이브 하위호환: 옛 세이브는 좌표를 [x,y] 2원소로 적었다 → **티어1로 읽는다**(load_save).
#   새 세이브는 [x,y,tier] 3원소다. 마이그레이션 코드 0(읽는 쪽에서 길이로 가른다).

signal changed()   # 설치/철거/복원한 프레임(main이 듣고 드로우·자동급수 대상 갱신)

# 설치 좌표 집합. 키 = 앵커 타일(Vector2i), 값 = **티어 정수**(1~3). 키 없음 = 미설치.
var _tiles: Dictionary = {}

# ── 티어 눈금(잠정 명명 — ADR-0069 결정 3) ──────────────────────────────────────
const TIER_1 := 1   # 저승 스프링클러 — 4방 인접(십자) 4칸
const TIER_2 := 2   # 넋비 스프링클러 — 3×3(8칸)
const TIER_3 := 3   # 단비 스프링클러 — 5×5(24칸)
const TIERS := [TIER_1, TIER_2, TIER_3]
const TIER_NAMES := {TIER_1: "저승 스프링클러", TIER_2: "넋비 스프링클러", TIER_3: "단비 스프링클러"}

# ── 티어1 급수 범위 = 4방 인접(십자). 앵커 기준 상대 오프셋. ─────────────────────
# ★ 이름을 그대로 둔다(드로우·기존 테스트가 참조하는 표면 — 티어1의 뜻도 안 변했다).
const CROSS_OFFSETS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
# 티어2 = 3×3(앵커 제외 8칸). 스타듀 Quality Sprinkler 1:1.
const BOX3_OFFSETS := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]
# 티어3 = 5×5(앵커 제외 24칸). 스타듀 Iridium Sprinkler 1:1.
const BOX5_OFFSETS := [
	Vector2i(-2, -2), Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2), Vector2i(2, -2),
	Vector2i(-2, -1), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
	Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(-2, 2), Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
]

# 티어별 급수 오프셋(범위의 단일 출처 — 드로우·급수·테스트가 전부 여기만 읽는다).
# 범위 밖 티어는 티어1로 접는다(손상 세이브·잘못된 호출 방어 — "물이 아예 안 나가는" 침묵보다 낫다).
static func offsets_for(tier: int) -> Array:
	match tier:
		TIER_2: return BOX3_OFFSETS
		TIER_3: return BOX5_OFFSETS
	return CROSS_OFFSETS

# 이 티어가 적시는 칸 수(4/8/24) — 표시·검증용 파생.
static func range_size(tier: int) -> int:
	return offsets_for(tier).size()

# 티어 표시명("" = 범위 밖). ItemCatalog가 아이템 이름의 진실원이지만, 원장 쪽에서도 알림 문구를
# 만들 수 있게 같은 문자열을 둔다(sprinkler_tier_test가 두 쪽을 대조한다).
static func tier_name(tier: int) -> String:
	return String(TIER_NAMES.get(tier, ""))

# 유효 티어인가(1~3).
static func is_tier(tier: int) -> bool:
	return TIER_NAMES.has(tier)

# ── 질의 ────────────────────────────────────────────────────────────────────
# 이 타일에 스프링클러가 설치돼 있는가(드로우·철거·배치 충돌 판정이 쓴다).
func has_at(t: Vector2i) -> bool:
	return _tiles.has(t)

# 이 타일에 선 스프링클러의 티어(0 = 미설치). 철거 시 "어느 아이템을 돌려주나"의 근거이기도 하다.
func tier_at(t: Vector2i) -> int:
	return int(_tiles.get(t, 0))

# 설치된 스프링클러 앵커 목록(드로우·검증).
func tiles() -> Array:
	return _tiles.keys()

# 설치 수(검증·디버그).
func count() -> int:
	return _tiles.size()

# 그 티어로 설치된 수(검증·디버그 — 티어별 분포).
func count_of_tier(tier: int) -> int:
	var n := 0
	for t in _tiles:
		if int(_tiles[t]) == tier:
			n += 1
	return n

# 한 스프링클러가 적시는 칸 목록(앵커 기준 — 드로우가 범위를 그릴 때 쓴다).
func targets_of(t: Vector2i) -> Array:
	if not _tiles.has(t):
		return []
	var out: Array = []
	for d in offsets_for(tier_at(t)):
		out.append(t + d)
	return out

# 모든 스프링클러의 급수 대상 칸(티어별 범위 합집합 — 중복 제거). main이 아침에 farm.sprinkle로 적신다.
func watered_targets() -> Array:
	var out: Dictionary = {}
	for anchor in _tiles:
		for d in offsets_for(int(_tiles[anchor])):
			out[anchor + d] = true
	return out.keys()

# ── 설치/철거 ────────────────────────────────────────────────────────────────
# 조준 타일에 스프링클러를 놓는다. 이미 있으면 false(멱등). 성공 시 changed.emit().
#   배치 가능 판정(지면·성역·프롭 겹침)은 main._can_place_sprinkler가 하고, 여기는 원장만 든다.
# ★ tier 기본값 = TIER_1이라 **기존 1인자 호출은 거동 불변**이다(회귀 스위트 전량 그대로 통과).
func place(t: Vector2i, tier: int = TIER_1) -> bool:
	if _tiles.has(t):
		return false
	_tiles[t] = tier if is_tier(tier) else TIER_1
	changed.emit()
	return true

# 조준 타일의 스프링클러를 회수한다. 없으면 false(무동작). 성공 시 changed.emit().
func remove(t: Vector2i) -> bool:
	if not _tiles.has(t):
		return false
	_tiles.erase(t)
	changed.emit()
	return true

# ── 세이브/로드(Reclaim 패턴 계승) — 슬라이스 키 "sprinkler" 네임스페이스 ──────────
# 좌표를 **[x,y,tier]** 배열 목록으로 직렬화. 로드는 통째 재구성 후 changed로 main이 드로우를 다시 세운다.
# ★[S10-T2] 3원소로 늘렸다. 옛 세이브의 [x,y] 2원소는 **티어1**로 읽는다(아래 길이 분기 한 줄이
#   마이그레이션의 전부다 — 스프링클러를 깔아 둔 구세이브가 그대로 살아난다).
func to_save() -> Dictionary:
	var tiles: Array = []
	for t in _tiles:
		tiles.append([t.x, t.y, int(_tiles[t])])
	return {"tiles": tiles}

func load_save(data: Dictionary) -> void:
	_tiles = {}
	var tiles: Variant = data.get("tiles", [])   # 키 없는 구세이브 = 설치 0(하위호환)
	if typeof(tiles) == TYPE_ARRAY:
		for e in tiles:
			if typeof(e) != TYPE_ARRAY or e.size() < 2:
				continue
			# 3원소 = 신세이브(티어 실림) · 2원소 = 구세이브(티어1). 손상 티어는 is_tier가 접는다.
			var tier := int(e[2]) if e.size() >= 3 else TIER_1
			_tiles[Vector2i(int(e[0]), int(e[1]))] = tier if is_tier(tier) else TIER_1
	changed.emit()
