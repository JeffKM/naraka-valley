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
# 티어(그레이박스): 티어1만. 스타듀식 상위 티어(품질=3×3·이리듐=5×5)는 후속 슬라이스에서
#   RANGE 오프셋만 티어별로 바꿔 얹는다(급수 로직·배치·세이브는 불변). 지금은 십자 고정.

signal changed()   # 설치/철거/복원한 프레임(main이 듣고 드로우·자동급수 대상 갱신)

# 설치 좌표 집합. 키 = 앵커 타일(Vector2i), 값 = true. 키 없음 = 미설치.
var _tiles: Dictionary = {}

# ── 티어1 급수 범위 = 4방 인접(십자). 앵커 기준 상대 오프셋. ─────────────────────
const CROSS_OFFSETS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# ── 질의 ────────────────────────────────────────────────────────────────────
# 이 타일에 스프링클러가 설치돼 있는가(드로우·철거·배치 충돌 판정이 쓴다).
func has_at(t: Vector2i) -> bool:
	return _tiles.has(t)

# 설치된 스프링클러 앵커 목록(드로우·검증).
func tiles() -> Array:
	return _tiles.keys()

# 설치 수(검증·디버그).
func count() -> int:
	return _tiles.size()

# 모든 스프링클러의 급수 대상 칸(십자 인접 — 중복 제거). main이 아침에 farm.sprinkle로 적신다.
func watered_targets() -> Array:
	var out: Dictionary = {}
	for anchor in _tiles:
		for d in CROSS_OFFSETS:
			out[anchor + d] = true
	return out.keys()

# ── 설치/철거 ────────────────────────────────────────────────────────────────
# 조준 타일에 스프링클러를 놓는다. 이미 있으면 false(멱등). 성공 시 changed.emit().
#   배치 가능 판정(지면·성역·프롭 겹침)은 main._can_place_sprinkler가 하고, 여기는 원장만 든다.
func place(t: Vector2i) -> bool:
	if _tiles.has(t):
		return false
	_tiles[t] = true
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
# 좌표를 [x,y] 배열 목록으로 직렬화. 로드는 통째 재구성 후 changed로 main이 드로우를 다시 세운다.
func to_save() -> Dictionary:
	var tiles: Array = []
	for t in _tiles:
		tiles.append([t.x, t.y])
	return {"tiles": tiles}

func load_save(data: Dictionary) -> void:
	_tiles = {}
	var tiles: Variant = data.get("tiles", [])   # 키 없는 구세이브 = 설치 0(하위호환)
	if typeof(tiles) == TYPE_ARRAY:
		for e in tiles:
			if typeof(e) == TYPE_ARRAY and e.size() >= 2:
				_tiles[Vector2i(int(e[0]), int(e[1]))] = true
	changed.emit()
