extends Node
class_name HomeDeco
# S1-9 — 집 꾸미기. 플레이어의 집 내부 3레이어 코스메틱 배치 델타를 소유하는 얇은 원장(ledger).
#
# 목적: ROADMAP S1-9 — 집 내부 바닥재·벽지·가구를 칸 단위로 자유 배치(회전)하고, 해금한 테마 세트만
#       팔레트로 열리며, 세이브로 영속하는지 헤드리스로 검증한다. 설계 = greybox-spec §11.
#
# 왜 별개 노드인가(§11.1, Reclaim/Orchard/Ranch 동형 완전 분리):
#   - 기존 F10 배치 모드(ADR-0025·layout.json·_prop_layouts)는 **개발자가 월드 가구를 저작하는 시드**다.
#     플레이어 집 꾸미기는 세이브별·집 내부 한정·순수 코스메틱으로 의미가 달라, layout.json 시드를
#     한 줄도 안 건드리고(회귀 0) 이 노드가 **플레이어 세이브 델타**(3레이어 + 해금 세트)만 소유한다.
#   - HomeDeco는 화면·지형·기하를 모른다(Reclaim이 그렇듯). 유효 배치 칸(바닥/벽 밴드)은 main이 구역
#     빌드 때 set_bounds로 주입하고, main이 드로우/충돌 훅에서 이 델타를 질의한다(디커플링).
#
# 순수 코스메틱 불변식(§11.6, 어겨선 안 됨):
#   - 이 노드엔 곱셈기·확률·XP·골드·에너지를 반환하는 API가 **없다**. deco_summary()는 순수 카운트뿐.
#   - 배치/삭제 동사는 경제·능력치 노드(energy/wallet/affinity/skill)를 호출하지 않는다(버프0/게이트0).
#     "잘 꾸민 집 = 더 강함"은 꾸미기를 의무로 만들어 코지를 죽인다(ADR-0008 평평≠막힘·ADR-0019 +가치 배제).

const Cat := preload("res://home_deco_catalog.gd")

signal changed()   # 배치·삭제·회전·해금·복원 프레임(main이 듣고 드로우/충돌 훅 갱신)

# ── 3레이어 배치 델타(§11.2) — 각 레이어 자체 Vector2i-키 Dictionary. 같은 레이어 셀당 1(overwrite),
#    레이어 간 같은 셀 공존(다른 dict). 값 = {set, item}(가구는 +rot). ────────────────────────────
var _floor: Dictionary = {}       # Vector2i → {set, item}
var _wall: Dictionary = {}        # Vector2i → {set, item}
var _furniture: Dictionary = {}   # Vector2i → {set, item, rot}

# 해금된 세트 집합(§11.4). key = set_id, 값 = true. 배치는 해금 세트 아이템만 허용.
var _unlocked: Dictionary = {}

# ── 배치 경계(main 주입, §11.2) — HomeDeco는 기하를 모르므로 유효 칸 집합을 받는다. 테스트는
#    스크래치 칸을 주입한다(cliff_test 결). key=Vector2i, 값=true. ──────────────────────────────
var _floor_cells: Dictionary = {}   # 바닥재·가구가 놓일 수 있는 룸 바닥 칸
var _wall_cells: Dictionary = {}    # 벽지가 놓일 수 있는 벽 밴드 칸

# ── 경계 주입 ────────────────────────────────────────────────────────────────
# main이 구역 빌드 때 유효 배치 칸을 주입한다(바닥 = FLOOR·FURNITURE / 벽 밴드 = WALL).
func set_bounds(floor_cells: Array, wall_cells: Array) -> void:
	_floor_cells = {}
	for c in floor_cells:
		_floor_cells[c] = true
	_wall_cells = {}
	for c in wall_cells:
		_wall_cells[c] = true

# 레이어별 유효 칸 집합(FLOOR·FURNITURE=바닥 / WALL=벽 밴드).
func _cells_for(layer: String) -> Dictionary:
	return _wall_cells if layer == Cat.L_WALL else _floor_cells

# 이 레이어의 배치 dict.
func _dict_for(layer: String) -> Dictionary:
	match layer:
		Cat.L_WALL: return _wall
		Cat.L_FURNITURE: return _furniture
		_: return _floor

# ── 해금(§11.4) ──────────────────────────────────────────────────────────────
func unlock(set_id: String) -> void:
	if Cat.has_set(set_id):
		_unlocked[set_id] = true
		changed.emit()

func is_unlocked(set_id: String) -> bool:
	return _unlocked.has(set_id)

func unlocked_sets() -> Array:
	return _unlocked.keys()

# ── 배치(§11.2) ──────────────────────────────────────────────────────────────
# 셀에 (set_id, item_key)를 배치한다. 아이템 layer는 카탈로그가 정한다(레이어 인자 불요). 회전은 가구만
# 유의미(rot 0..3, 다른 레이어는 무시). 성공 시 true·changed. 실패(미지 아이템 / 미해금 세트 / 경계 밖)면
# false — 무동작(멱등적 실패). 같은 레이어 같은 셀은 overwrite(§11.7).
func place(cell: Vector2i, set_id: String, item_key: String, rot: int = 0) -> bool:
	if not Cat.has_item(set_id, item_key):
		return false                                   # 미지 아이템(방어)
	if not is_unlocked(set_id):
		return false                                   # 미해금 세트 → 배치 불가(해금=팔레트 게이트)
	var layer := Cat.layer_of(set_id, item_key)
	if not _cells_for(layer).has(cell):
		return false                                   # 룸 rect 밖·해당 레이어 비유효 칸 → 거부
	var d := _dict_for(layer)
	if layer == Cat.L_FURNITURE:
		d[cell] = {"set": set_id, "item": item_key, "rot": posmod(rot, 4)}
	else:
		d[cell] = {"set": set_id, "item": item_key}    # 바닥재·벽지는 회전 없음(칠)
	changed.emit()
	return true

# 이 레이어의 셀 배치를 지운다. 지웠으면 true·changed, 없었으면 false.
func remove(layer: String, cell: Vector2i) -> bool:
	if not Cat.is_layer(layer):
		return false
	var d := _dict_for(layer)
	if not d.has(cell):
		return false
	d.erase(cell)
	changed.emit()
	return true

# 가구를 시계방향 한 칸 회전(rot = (rot+1)%4). 회전 후 rot 반환(가구 없으면 -1). 바닥재·벽지는 회전 없음.
func rotate_furniture(cell: Vector2i) -> int:
	if not _furniture.has(cell):
		return -1
	var r: int = posmod(int(_furniture[cell].get("rot", 0)) + 1, 4)
	_furniture[cell]["rot"] = r
	changed.emit()
	return r

# ── 질의(드로우·검증) ────────────────────────────────────────────────────────
# 이 레이어 셀의 배치({} = 없음). 드로우가 set/item/rot을 읽는다.
func item_at(layer: String, cell: Vector2i) -> Dictionary:
	if not Cat.is_layer(layer):
		return {}
	var d := _dict_for(layer)
	return d.get(cell, {})

func layer_dict(layer: String) -> Dictionary:
	return _dict_for(layer)

func has_any(layer: String, cell: Vector2i) -> bool:
	return _dict_for(layer).has(cell)

# ── 디제시스 최소 스텁(§11.6) — 읽기 전용 조회 표면(순수 카운트 스칼라뿐). Slice 8 NPC/배우자
#    대사가 이 훅을 읽어 "집이 아늑하다" 류 한 줄을 낼 것이다. 곱셈기·버프는 여기에도 없다. ────────
func deco_summary() -> Dictionary:
	var sets := {}
	for d in [_floor, _wall, _furniture]:
		for cell in d:
			sets[d[cell]["set"]] = true
	return {
		"floor": _floor.size(),
		"wall": _wall.size(),
		"furniture": _furniture.size(),
		"total": _floor.size() + _wall.size() + _furniture.size(),
		"sets": sets.size(),   # 배치에 쓰인 서로 다른 세트 수(세트 간 믹스 신호)
	}

# 무언가 하나라도 배치돼 있는가(앰비언트 한 줄 게이트 — 꾸며진 집 진입 시 발화).
func is_decorated() -> bool:
	return not (_floor.is_empty() and _wall.is_empty() and _furniture.is_empty())

# ── 세이브/로드(§11.7) — Reclaim/Orchard 패턴. Vector2i를 [x,y,...] 배열로(JSON 안정) ──────────
func to_save() -> Dictionary:
	var floor_a: Array = []
	for c in _floor:
		floor_a.append([c.x, c.y, _floor[c]["set"], _floor[c]["item"]])
	var wall_a: Array = []
	for c in _wall:
		wall_a.append([c.x, c.y, _wall[c]["set"], _wall[c]["item"]])
	var furn_a: Array = []
	for c in _furniture:
		furn_a.append([c.x, c.y, _furniture[c]["set"], _furniture[c]["item"], int(_furniture[c].get("rot", 0))])
	return {
		"unlocked_sets": _unlocked.keys(),
		"floor": floor_a,
		"wall": wall_a,
		"furniture": furn_a,
	}

func load_save(data: Dictionary) -> void:
	_floor = {}
	_wall = {}
	_furniture = {}
	_unlocked = {}
	var us: Variant = data.get("unlocked_sets", [])
	if typeof(us) == TYPE_ARRAY:
		for sid in us:
			if Cat.has_set(str(sid)):
				_unlocked[str(sid)] = true
	_load_paint(data.get("floor", []), _floor)
	_load_paint(data.get("wall", []), _wall)
	_load_furniture(data.get("furniture", []))
	changed.emit()

# 바닥재·벽지 = [x,y,set,item]. 미지 아이템은 방어적으로 건너뛴다(구세이브·손상).
func _load_paint(arr: Variant, into: Dictionary) -> void:
	if typeof(arr) != TYPE_ARRAY:
		return
	for e in arr:
		if typeof(e) == TYPE_ARRAY and e.size() >= 4 and Cat.has_item(str(e[2]), str(e[3])):
			into[Vector2i(int(e[0]), int(e[1]))] = {"set": str(e[2]), "item": str(e[3])}

# 가구 = [x,y,set,item,rot].
func _load_furniture(arr: Variant) -> void:
	if typeof(arr) != TYPE_ARRAY:
		return
	for e in arr:
		if typeof(e) == TYPE_ARRAY and e.size() >= 5 and Cat.has_item(str(e[2]), str(e[3])):
			_furniture[Vector2i(int(e[0]), int(e[1]))] = {"set": str(e[2]), "item": str(e[3]), "rot": posmod(int(e[4]), 4)}
