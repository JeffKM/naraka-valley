extends Node
class_name Forage
# B1-a.3 — 사료풀(낫으로 베어 건초를 얻는 고지 풀). FarmField/Orchard/Ranch/Reclaim와 완전 분리된
# 자체 좌표 원장(ledger). 벤 자리는 며칠 뒤 다시 자라고(재생), 겨울(잿눈)엔 성장이 멎는다(Q7).
#
# 목적: ROADMAP B1-a.3 — 낫 풀베기 → 여물광 건초 경제. 사료풀 타일을 낫으로 베면(cut) 다 자란 것만
#       베이고, main이 그 수확을 여물광(Ranch.store_hay)에 넣는다. advance_day가 벤 지 REGROW_DAYS
#       지난 타일을 다시 자라게 하되, 겨울엔 재생을 멈춰 "겨울엔 새 건초가 안 난다 → 미리 쌓아 둬야
#       한다"는 굶음 긴장을 만든다(비살상 — 짐승은 안 죽고 기분만 상한다, Ranch가 정산).
#
# 왜 별개 노드인가(Reclaim 동형):
#   - 사료풀 배치는 main이 고지 자유 풀밭에서 시드한다(seed). Forage는 "무엇이 어디에 있고 다 자랐나"
#     라는 상태 델타만 소유하고, 화면·지형·재화(건초)를 모른다(디커플링). main이 벤 결과를 여물광에
#     적재하고(경제 양끝 잇기), 드로우/충돌은 main이 이 상태를 질의해 그린다.
#   - Reclaim(1회성 개간)과 달리 재생이 있어 advance_day를 가진다(작물처럼 하루 리듬). Debris와 ID/
#     레이어가 완전히 갈려(Q7 "Debris와 격리") 개간과 안 섞인다.

signal changed()   # 사료풀이 베이거나 다시 자라거나 복원된 프레임(main이 듣고 드로우 갱신)

const REGROW_DAYS := 3   # 벤 뒤 다시 다 자랄 때까지 걸리는 날 수(겨울엔 멈춤)
const GROWN := -1        # cut_day 센티넬 — 다 자람(안 벴거나 재생 완료). 그 외 = 벤 날(정수).

# 사료풀 상태. 키 = 타일(Vector2i), 값 = cut_day(int, GROWN=-1이면 다 자람). 키 없음 = 사료풀 아님.
var _tiles: Dictionary = {}

# ── 시드·질의 ─────────────────────────────────────────────────────────────────
# main이 고지 자유 풀밭 타일을 사료풀로 등록한다(신규 게임·부팅 멱등). 이미 있으면 상태 보존(재시드 무해).
func seed(tile: Vector2i) -> void:
	if not _tiles.has(tile):
		_tiles[tile] = GROWN
		changed.emit()

func has_forage(tile: Vector2i) -> bool:
	return _tiles.has(tile)

# 다 자라 벨 수 있는가(main의 낫 디스패치·드로우가 쓴다).
func is_grown(tile: Vector2i) -> bool:
	return _tiles.has(tile) and int(_tiles[tile]) == GROWN

func all_tiles() -> Array:
	return _tiles.keys()

# 다 자란 사료풀 타일 목록(드로우·검증).
func grown_tiles() -> Array:
	var out: Array = []
	for t in _tiles.keys():
		if int(_tiles[t]) == GROWN:
			out.append(t)
	return out

func grown_count() -> int:
	return grown_tiles().size()

# ── 베기(§Q7) ─────────────────────────────────────────────────────────────────
# 다 자란 사료풀을 벤다(낫 LMB). 성공 시 cut_day를 새겨 재생 타이머를 걸고 true(main이 여물광에 +1).
# 안 자랐거나 사료풀 아니면 false(무동작). day = 현재 날(재생 기준).
func cut(tile: Vector2i, day: int) -> bool:
	if not is_grown(tile):
		return false
	_tiles[tile] = day
	changed.emit()
	return true

# ── 하루 경과(재생) — 취침 트리거 ────────────────────────────────────────────
# 벤 지 REGROW_DAYS 지난 타일을 다시 다 자라게 한다. ⚠️ 겨울(잿눈)이면 재생을 멈춘다(Q7 성장정지 →
# 겨울 굶음 긴장). day = 새 날, is_winter = 현재 절기가 겨울(성야절)인가(main이 GameClock에서 파생).
func advance_day(day: int, is_winter: bool) -> void:
	if is_winter:
		return   # 잿눈 — 사료풀 성장 정지(재생 없음). 미리 쌓아 둔 여물광 건초로 버텨야 한다.
	var any := false
	for t in _tiles.keys():
		var cd := int(_tiles[t])
		if cd != GROWN and day - cd >= REGROW_DAYS:
			_tiles[t] = GROWN
			any = true
	if any:
		changed.emit()

# ── 세이브/로드 — Reclaim 패턴 계승 ──────────────────────────────────────────
# _tiles는 Vector2i 키 + int 값 순수 Dictionary라, [x, y, cut_day] 삼중 목록으로 명시 직렬화한다
# (구조 안정성 — var_to_str도 되지만 Reclaim처럼 배열 목록으로). 로드는 통째 재구성 후 changed.
func to_save() -> Dictionary:
	var tiles: Array = []
	for t in _tiles.keys():
		tiles.append([t.x, t.y, int(_tiles[t])])
	return {"tiles": tiles}

func load_save(data: Dictionary) -> void:
	_tiles = {}
	var tiles: Variant = data.get("tiles", [])
	if typeof(tiles) == TYPE_ARRAY:
		for e in tiles:
			if typeof(e) == TYPE_ARRAY and e.size() >= 3:
				_tiles[Vector2i(int(e[0]), int(e[1]))] = int(e[2])
	changed.emit()
