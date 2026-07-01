extends Node
class_name Orchard
# S1-5b — 혼의 나무 과수(영속·품질=나이). FarmField(작물)와 완전 분리된 자체 좌표계 엔티티.
#
# 목적: ROADMAP S1-5b — 묘목을 심어 28일(1절기) 성숙 → 제철 매일 결실 → 절기 넘어 영속하고,
#       나이별 품질이 파생되는지를 헤드리스로 검증한다. 설계 = greybox-spec §7 · ADR-0045.
#
# 왜 별개 노드인가(greybox-spec §7.1, Q2 = (A) 완전 분리):
#   - 나무는 밭 칸의 crop이 아니라 3×3 영속 엔티티다. FarmField의 per-tile {planted,watered,
#     crop,grown_days} 모델과 근본적으로 안 맞아(물주기 없음·달력 구동·나이 품질) FarmField를
#     한 줄도 안 건드린다(S1-4/5a 회귀-0 계약 계승). main이 심기·수확·충돌을 배선한다(디커플링).
#
# 설계 메모(§7.3):
#   - 나무 1그루 = 앵커(중심 Vector2i) → 3필드 Dict {fruit_id, planted_day, fruit_count(0..cap)}.
#     ★ 나이 = clock.day − planted_day 파생(누적기 없음) → 품질·영속·세이브가 전부 파생이라 상태 최소.
#     planted_day는 절기 경계에서 절대 리셋 안 된다 → 영속·나이 증가가 자명.
#   - 상태를 Vector2i 키 + int/String 값 순수 Dictionary로만 들어 그대로 직렬화된다(FarmField와
#     같은 결 — inner class 안 씀). 세이브는 fruit_count만 가변, 나머지는 불변 상수.
#   - 절기 판정은 GameClock.season_index_for_day(day)를 매 틱 무상태로 재계산한다(세이브 캐시 아님,
#     ADR-0045) — 로드-틱 유령과일 차단. 사멸 트리거를 심지 않아 영속이 성립(Slice 7 불가침).

signal changed()   # 나무가 심기거나 결실·수확된 프레임(main이 듣고 화면 갱신)

const FOOTPRINT_RADIUS := 1        # 3×3 예약 풋프린트 = 앵커 ±1(중심 앵커 모델, §7.4)
const TREE_NONE := Vector2i(-2147483648, -2147483648)   # tree_at 실패 sentinel(맵 밖 좌표)

# 나무 상태. 키 = 앵커(중심 칸 Vector2i), 값 = {fruit_id, planted_day, fruit_count}.
# 키가 없음 = 그 자리에 나무 없음. 심긴 나무만 담는다(FarmField._tiles와 같은 결).
var _trees: Dictionary = {}

# ── 기하(§7.4) ──────────────────────────────────────────────────────────────
# 앵커의 3×3 예약 풋프린트 9칸 목록(앵커 ±1). 심기 판정·수확 역추적이 쓴다.
static func footprint_of(anchor: Vector2i) -> Array:
	var out: Array = []
	for dy in range(-FOOTPRINT_RADIUS, FOOTPRINT_RADIUS + 1):
		for dx in range(-FOOTPRINT_RADIUS, FOOTPRINT_RADIUS + 1):
			out.append(anchor + Vector2i(dx, dy))
	return out

# 두 중심 앵커의 3×3 풋프린트가 겹치는가 = 체비쇼프 거리 ≤ 2(각 축 ≤2). 심기 판정 ④가 쓴다.
static func _footprints_overlap(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) <= 2 * FOOTPRINT_RADIUS and absi(a.y - b.y) <= 2 * FOOTPRINT_RADIUS

# ── 심기(§7.4) ──────────────────────────────────────────────────────────────
# 앵커에 나무를 심을 수 있는가(§7.4 판정). is_blocked = Callable(Vector2i)->bool로 지형 게이팅을
# 호출 측(main)이 주입한다 — 맵 밖·is_solid·is_crop_solid를 main/farm이 알기 때문(orchard는 지형을
# 모른다, 디커플링). 9칸 전수 평가 + 타 나무 풋프린트 미교차.
func can_plant(anchor: Vector2i, is_blocked: Callable) -> bool:
	for t in footprint_of(anchor):
		if is_blocked.call(t):        # ①맵 밖 ②is_solid(절벽·프롭) ③is_crop_solid(트렐리스) — main이 합성
			return false
	for existing in _trees.keys():    # ④타 나무 예약 풋프린트와 미교차
		if _footprints_overlap(anchor, existing):
			return false
	return true

# 묘목을 심는다. 유효 종 + can_plant 통과 시 앵커에 나무 생성(planted_day=day). 성공 시 true.
func plant(anchor: Vector2i, fruit_id: String, day: int, is_blocked: Callable) -> bool:
	if not FruitTreeCatalog.has(fruit_id):
		return false
	if not can_plant(anchor, is_blocked):
		return false
	_trees[anchor] = {"fruit_id": fruit_id, "planted_day": day, "fruit_count": 0}
	changed.emit()
	return true

# ── 조회 ────────────────────────────────────────────────────────────────────
func has_tree(anchor: Vector2i) -> bool:
	return _trees.has(anchor)

# 심긴 나무 앵커(=밑동 SOLID 칸) 목록. main의 _rebuild_orchard_collision이 순회한다.
func trunk_tiles() -> Array:
	return _trees.keys()

# 나무 나이(일) = 현재 day − planted_day. 없는 앵커면 -1.
func age_of(anchor: Vector2i, day: int) -> int:
	return day - int(_trees[anchor]["planted_day"]) if _trees.has(anchor) else -1

# 성숙했는가 = 나이 ≥ mature_days(순수 달력, 물주기 무관). need<0(미지 종) 방어.
func is_mature(anchor: Vector2i, day: int) -> bool:
	if not _trees.has(anchor):
		return false
	var need := FruitTreeCatalog.mature_days(_trees[anchor]["fruit_id"])
	return need >= 0 and (day - int(_trees[anchor]["planted_day"])) >= need

# 지금이 이 나무의 결실 절기인가(§7.5 제철 판정). 매 틱 무상태 재계산(ADR-0045).
func in_season(anchor: Vector2i, day: int) -> bool:
	if not _trees.has(anchor):
		return false
	return GameClock.season_index_for_day(day) == FruitTreeCatalog.season(_trees[anchor]["fruit_id"])

# 앵커의 익은 과일 수(0 = 없음/미존재).
func fruit_count_of(anchor: Vector2i) -> int:
	return int(_trees[anchor]["fruit_count"]) if _trees.has(anchor) else 0

# ── 품질=나이(§7.7) — 파생 함수만. 인벤토리 배선·판매가는 S1-6이 이 함수를 소비 ─────
# 나이(일) → 품질 등급 0..3. 절기당 +1등급(28일 입도): 28(갓 성숙)→0 · 56→1 · 84→2 · 112(1년생)→3.
func quality_tier_for_age(age: int) -> int:
	return clampi((age - 28) / 28, 0, 3)

# ── 수확(§7.6) ──────────────────────────────────────────────────────────────
# 조준 칸이 어느 나무의 3×3 풋프린트에 드는지 역추적(체비쇼프 ≤1). 없으면 TREE_NONE.
func tree_at(tile: Vector2i) -> Vector2i:
	for anchor in _trees.keys():
		if maxi(absi(tile.x - anchor.x), absi(tile.y - anchor.y)) <= FOOTPRINT_RADIUS:
			return anchor
	return TREE_NONE

# 나무를 수확한다. 성숙 + fruit_count>0이면 매달린 과일 전량을 반환하고 0으로 리셋한다.
# 반환 = {fruit_id, count, quality_tier}(나이서 산출) / 조건 불충족이면 빈 Dictionary({}).
# ★ quality_tier는 지금 계산만 하고 인벤토리엔 안 붙는다(§7.7 — S1-6이 소비). count만 main이 적재.
func harvest(anchor: Vector2i, day: int) -> Dictionary:
	if not is_mature(anchor, day) or fruit_count_of(anchor) <= 0:
		return {}
	var tree: Dictionary = _trees[anchor]
	var n := int(tree["fruit_count"])
	var q := quality_tier_for_age(day - int(tree["planted_day"]))
	tree["fruit_count"] = 0
	changed.emit()
	return {"fruit_id": tree["fruit_id"], "count": n, "quality_tier": q}

# ── 하루 경과(§7.5) — 취침 트리거(GameClock.day_advanced) ──────────────────────
# 성숙 + 제철인 나무는 fruit_count가 매일 +1 되고 cap에서 멈춘다. 비제철이면 정지(매달린 과일 유지).
# 절기 경계를 넘겨도 사멸 판정에 참여하지 않아 나무는 그대로 살아 나이가 계속 증가한다(영속).
func advance_day(day: int) -> void:
	var any := false
	for anchor in _trees.keys():
		var tree: Dictionary = _trees[anchor]
		var cap := FruitTreeCatalog.fruit_cap(tree["fruit_id"])
		if is_mature(anchor, day) and in_season(anchor, day) and int(tree["fruit_count"]) < cap:
			tree["fruit_count"] = int(tree["fruit_count"]) + 1
			any = true
	if any:
		changed.emit()

# ── 세이브/로드(§7.9) — FarmField 패턴 계승 ───────────────────────────────────
# _trees는 Vector2i 키 + int/String 값 순수 Dictionary라 var_to_str가 그대로 라운드트립한다.
# 깊은 복사로 넘겨 호출 측이 들고 있어도 상태가 새지 않게 한다.
func to_save() -> Dictionary:
	return {"trees": _trees.duplicate(true)}

# 복원: _trees를 통째로 갈아끼운다. changed로 main이 충돌·화면을 다시 세우게 한다(디커플링).
func load_save(data: Dictionary) -> void:
	var trees: Variant = data.get("trees", {})
	_trees = trees.duplicate(true) if typeof(trees) == TYPE_DICTIONARY else {}
	changed.emit()
