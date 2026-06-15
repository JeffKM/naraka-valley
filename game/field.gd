extends Node
class_name FarmField
# T2.1 — 밭 칸 상호작용(괭이질 → 심기 → 물주기).
#
# 목적: 한 칸에서 괭이질→심기→물주기가 "순서대로" 되고, 칸 상태가
#       (미경작/경작/심김/젖음)으로 바뀌는지 회색 도형만으로 검증한다(ADR-0001).
#
# 설계 메모:
#   - clock.gd(GameClock)와 같은 결: 이 노드는 "밭 칸 상태"라는 단일 책임만 가진다.
#     화면 표시(오버레이 타일·커서)·입력은 main.gd가 맡고, 여기서는 상태와
#     tile_changed 시그널만 제공한다. main은 시그널로 디커플링되어 붙는다.
#   - 후속 시스템을 위한 훅을 미리 연다:
#       · T2.2 저승 작물 3종 — plant()가 지금은 작물 종류 없이 '심김'만 표시하지만,
#         crop_id 인자를 받도록 자연스럽게 확장될 자리다(지금은 그레이박스 1종).
#       · T2.3 작물 성장 — 칸별 성장 단계가 여기 _tiles에 필드로 추가되고,
#         GameClock.day_advanced에 이 노드가 연결되면 코드 흐름이 그대로 이어진다.
#       · T2.5 세이브/로드 — 상태를 순수 Dictionary로만 들고 있어 그대로 직렬화된다
#         (Vector2i 키, bool 값). 그래서 일부러 inner class를 쓰지 않는다.
#   - 완료기준의 "순서대로"는 next_action()이 강제한다: 경작 전엔 심을 수 없고,
#     심기 전엔 물을 줄 수 없다.

signal tile_changed(tile: Vector2i)  # 칸 상태가 바뀐 프레임(main이 듣고 오버레이 갱신)

# 칸 상태 저장.
#   - 키가 없음        → 미경작(맨 흙). 메모리·세이브를 아끼려 경작된 칸만 담는다.
#   - { planted, watered } → 경작된 칸. tilled 여부는 "키 존재"로 표현한다.
var _tiles: Dictionary = {}

# ── 조회 ────────────────────────────────────────────────────────────────────
func is_tilled(t: Vector2i) -> bool:
	return _tiles.has(t)

func is_planted(t: Vector2i) -> bool:
	return is_tilled(t) and _tiles[t]["planted"]

func is_watered(t: Vector2i) -> bool:
	return is_tilled(t) and _tiles[t]["watered"]

# ── 단위 동작(가능하면 수행하고 true, 이미 그 상태면 false) ─────────────────
func hoe(t: Vector2i) -> bool:
	if is_tilled(t):
		return false
	_tiles[t] = {"planted": false, "watered": false}
	tile_changed.emit(t)
	return true

func plant(t: Vector2i) -> bool:
	# 경작된 빈 칸에만 심는다(괭이질 → 심기 순서 강제).
	if not is_tilled(t) or is_planted(t):
		return false
	_tiles[t]["planted"] = true
	tile_changed.emit(t)
	return true

func water(t: Vector2i) -> bool:
	# 심은 칸에만 물을 준다(심기 → 물주기 순서 강제). T2.3에서 '물 준 칸만 성장'으로 쓰인다.
	if not is_planted(t) or is_watered(t):
		return false
	_tiles[t]["watered"] = true
	tile_changed.emit(t)
	return true

# ── 단일 키 흐름 ─────────────────────────────────────────────────────────────
# 이 칸에서 다음에 할 수 있는 동작 이름("" = 더 할 것 없음). 프롬프트·interact가 공유한다.
func next_action(t: Vector2i) -> String:
	if not is_tilled(t):
		return "괭이질"
	if not is_planted(t):
		return "심기"
	if not is_watered(t):
		return "물주기"
	return ""

# 한 번의 상호작용: 칸 상태에 맞는 다음 동작을 수행하고 그 이름을 반환한다("" = 무동작).
# main의 입력 한 키(E)가 이걸 호출 → 누를 때마다 괭이질→심기→물주기로 진행된다.
func interact(t: Vector2i) -> String:
	var action := next_action(t)
	match action:
		"괭이질":
			hoe(t)
		"심기":
			plant(t)
		"물주기":
			water(t)
	return action
