extends Node
class_name FlowerPatch
# ADR-0052 §118 · ADR-0033 — 안식 꽃 패치(피안화) 채집 표면. 라이브 채집 루프의 XP 소스.
#
# 목적: ADR-0052 채집 파일럿을 실제로 굴린다. 안식에 뿌려진 꽃 패치를 손수확(RMB, 혼력0 — ADR-0033
#       #1 "줍기=혼력0")하면 main이 채집물(피안화) + 채집 XP를 준다. 다 딴 자리는 며칠 뒤 다시 핀다
#       (재생). 수확 등급은 여기서 안 정한다 — 채집 레벨/전문직이 소스라 main이 주입한다(디커플링).
#
# 왜 별개 노드인가(Forage(사료풀)/Orchard/Reclaim 동형):
#   - 꽃 패치 배치는 main이 안식 여백에 시드한다(seed). FlowerPatch는 "어디에 패치가 있고 지금 폈나"
#     라는 상태 델타만 소유하고, 화면·재화·품질을 모른다. main이 수확 결과를 인벤토리·채집 XP에 잇고
#     (경제 양끝 잇기), 드로우는 main이 이 상태를 질의해 그린다.
#   - Forage(사료풀·낫 베기)와 좌표·레이어가 완전히 갈린다: 사료풀=낫(도구·혼력 소모·여물광), 꽃 패치=
#     맨손 채집(혼력0·인벤토리·채집 XP). 둘은 안 섞인다(class_name Forage는 사료풀이 선점 — 여긴 FlowerPatch).
#   - 재생이 있어 advance_day를 가진다(Forage 결). ⚠️ 사료풀과 달리 절기 게이트 없음 — 피안화는 저승
#     꽃이라 잿눈에도 핀다(그레이박스 단순화, 절기 사멸은 후속 채집 슬라이스에서 재고).

signal changed()   # 패치가 따이거나 다시 피거나 복원된 프레임(main이 듣고 드로우 갱신)

const REGROW_DAYS := 5   # 딴 뒤 다시 필 때까지 걸리는 날 수(작물보다 느슨 — 채집 = 이완 발견)
const BLOOMED := -1      # picked_day 센티넬 — 활짝 핌(안 땄거나 재생 완료). 그 외 = 딴 날(정수).

# 꽃 패치 상태. 키 = 타일(Vector2i), 값 = picked_day(int, BLOOMED=-1이면 폄). 키 없음 = 패치 아님.
var _tiles: Dictionary = {}

# ── 시드·질의 ─────────────────────────────────────────────────────────────────
# main이 안식 여백 타일을 꽃 패치로 등록한다(신규·부팅 멱등). 이미 있으면 상태 보존(재시드 무해).
func seed(tile: Vector2i) -> void:
	if not _tiles.has(tile):
		_tiles[tile] = BLOOMED
		changed.emit()

func has_patch(tile: Vector2i) -> bool:
	return _tiles.has(tile)

# 활짝 펴 딸 수 있는가(main의 수확 디스패치·드로우가 쓴다).
func is_bloomed(tile: Vector2i) -> bool:
	return _tiles.has(tile) and int(_tiles[tile]) == BLOOMED

func all_tiles() -> Array:
	return _tiles.keys()

# 활짝 핀 패치 타일 목록(드로우·검증).
func bloomed_tiles() -> Array:
	var out: Array = []
	for t in _tiles.keys():
		if int(_tiles[t]) == BLOOMED:
			out.append(t)
	return out

func bloomed_count() -> int:
	return bloomed_tiles().size()

# ── 따기(손수확) ──────────────────────────────────────────────────────────────
# 활짝 핀 패치를 딴다(맨손 RMB). 성공 시 picked_day를 새겨 재생 타이머를 걸고 true(main이 채집물+XP 지급).
# 안 폈거나 패치 아니면 false(무동작). day = 현재 날(재생 기준). 품질·수량은 main이 채집 레벨로 정한다.
func pick(tile: Vector2i, day: int) -> bool:
	if not is_bloomed(tile):
		return false
	_tiles[tile] = day
	changed.emit()
	return true

# ── 하루 경과(재생) — 취침 트리거 ────────────────────────────────────────────
# 딴 지 REGROW_DAYS 지난 패치를 다시 활짝 피게 한다(절기 무관 — 저승 꽃). day = 새 날.
func advance_day(day: int) -> void:
	var any := false
	for t in _tiles.keys():
		var pd := int(_tiles[t])
		if pd != BLOOMED and day - pd >= REGROW_DAYS:
			_tiles[t] = BLOOMED
			any = true
	if any:
		changed.emit()

# ── 세이브/로드 — Forage(사료풀) 패턴 계승 ───────────────────────────────────
# _tiles는 Vector2i 키 + int 값 순수 Dictionary라, [x, y, picked_day] 삼중 목록으로 명시 직렬화한다.
# 로드는 통째 재구성 후 changed(드로우 갱신).
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
