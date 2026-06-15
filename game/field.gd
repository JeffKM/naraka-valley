extends Node
class_name FarmField
# T2.1 — 밭 칸 상호작용(괭이질 → 심기 → 물주기) + T2.3 — 작물 성장(일수 경과).
#
# 목적:
#   - T2.1: 한 칸에서 괭이질→심기→물주기가 "순서대로" 되고, 칸 상태가
#     (미경작/경작/심김/젖음)으로 바뀌는지 회색 도형만으로 검증한다(ADR-0001).
#   - T2.3: 심은 작물이 날이 지나며 단계가 오르고, 다 자라면 수확 가능해진다.
#     성장 규칙은 스타듀식: "물 준 칸만 다음 날 자라고, 매일 아침 흙이 마른다."
#
# 설계 메모:
#   - clock.gd(GameClock)와 같은 결: 이 노드는 "밭 칸 상태"라는 단일 책임만 가진다.
#     화면 표시(오버레이 타일·커서)·입력은 main.gd가 맡고, 여기서는 상태와
#     tile_changed 시그널만 제공한다. main은 시그널로 디커플링되어 붙는다.
#   - 작물 정의는 CropCatalog(crops.gd, 정적 참조 데이터)에서 읽는다. 이 노드는
#     "어떤 작물이 어디에 심겼고 며칠 자랐나"라는 세이브 상태만 들고, 성장일수
#     같은 카탈로그 값은 CropCatalog로 조회한다(데이터/상태 분리).
#   - 성장 트리거: GameClock.day_advanced에 main이 advance_day()를 연결한다.
#     시계는 코드 수정 없이 이 노드를 구동한다(시그널 디커플링).
#   - T2.5 세이브/로드 — 상태를 순수 Dictionary로만 들고 있어 그대로 직렬화된다
#     (Vector2i 키, bool/String/int 값). 그래서 일부러 inner class를 쓰지 않는다.
#   - 완료기준의 "순서대로"는 next_action()이 강제한다: 경작 전엔 심을 수 없고,
#     심기 전엔 물을 줄 수 없으며, 다 자라기 전엔 수확할 수 없다.

signal tile_changed(tile: Vector2i)  # 칸 상태가 바뀐 프레임(main이 듣고 오버레이 갱신)

# 칸 상태 저장.
#   - 키가 없음 → 미경작(맨 흙). 메모리·세이브를 아끼려 경작된 칸만 담는다.
#   - 값 Dictionary 필드:
#       planted    : 작물이 심겼는가
#       watered    : 오늘 물을 줬는가(매일 아침 advance_day에서 false로 마름)
#       crop       : 심은 작물 id(CropCatalog의 영문 id, "" = 없음)
#       grown_days : 물 주고 잔 날의 누적(성장 진행도). growth_days 도달 시 수확 가능
var _tiles: Dictionary = {}

# ── 조회 ────────────────────────────────────────────────────────────────────
func is_tilled(t: Vector2i) -> bool:
	return _tiles.has(t)

func is_planted(t: Vector2i) -> bool:
	return is_tilled(t) and _tiles[t]["planted"]

func is_watered(t: Vector2i) -> bool:
	return is_tilled(t) and _tiles[t]["watered"]

# 심긴 작물 id("" = 없음). T2.5 세이브·T3 경제(판매가 조회)가 쓴다.
func crop_of(t: Vector2i) -> String:
	return _tiles[t]["crop"] if is_planted(t) else ""

# 누적 성장 일수(물 준 날만 쌓인다). 안 심긴 칸은 0.
func grown_days_of(t: Vector2i) -> int:
	return _tiles[t]["grown_days"] if is_planted(t) else 0

# 다 자라 수확 가능한가 = 심김 + 누적 성장일수 ≥ 작물 성장일수.
func is_mature(t: Vector2i) -> bool:
	if not is_planted(t):
		return false
	var need := CropCatalog.growth_days(_tiles[t]["crop"])
	return need >= 0 and _tiles[t]["grown_days"] >= need

# 시각 성장 단계(오버레이용): -1=작물없음 / 0=씨앗 / 1=새싹 / 2=수확가능.
# 작물별 stages 수와 무관한 그레이박스 3단계(외형). 속도 차이는 growth_days가 낸다.
func growth_stage(t: Vector2i) -> int:
	if not is_planted(t):
		return -1
	if is_mature(t):
		return 2
	return 0 if _tiles[t]["grown_days"] == 0 else 1

# ── 단위 동작(가능하면 수행하고 true, 이미 그 상태면 false) ─────────────────
func hoe(t: Vector2i) -> bool:
	if is_tilled(t):
		return false
	_tiles[t] = {"planted": false, "watered": false, "crop": "", "grown_days": 0}
	tile_changed.emit(t)
	return true

func plant(t: Vector2i, crop_id: String) -> bool:
	# 경작된 빈 칸에, 카탈로그에 있는 작물만 심는다(괭이질 → 심기 순서 강제).
	if not is_tilled(t) or is_planted(t):
		return false
	if not CropCatalog.has_crop(crop_id):
		return false
	_tiles[t]["planted"] = true
	_tiles[t]["crop"] = crop_id
	_tiles[t]["grown_days"] = 0
	tile_changed.emit(t)
	return true

func water(t: Vector2i) -> bool:
	# 다 자라지 않은, 심은 마른 칸에만 물을 준다(심기 → 물주기 순서 강제).
	# 물 준 칸만 advance_day에서 자란다.
	if not is_planted(t) or is_watered(t) or is_mature(t):
		return false
	_tiles[t]["watered"] = true
	tile_changed.emit(t)
	return true

# 수확: 다 자란 칸을 거두고 빈 경작 칸으로 되돌린다. 거둔 작물 id를 반환("" = 실패).
# 골드 지급(T3.1 경제)은 이 반환값(작물 id)으로 호출 측이 처리한다(범위 분리).
func harvest(t: Vector2i) -> String:
	if not is_mature(t):
		return ""
	var crop_id: String = _tiles[t]["crop"]
	_tiles[t]["planted"] = false
	_tiles[t]["crop"] = ""
	_tiles[t]["grown_days"] = 0
	tile_changed.emit(t)
	return crop_id

# ── 하루 경과(취침 트리거) ───────────────────────────────────────────────────
# GameClock.day_advanced에 연결된다. 스타듀 규칙 + T3.4 여우불 도움:
#   1) 물 준(watered) 칸은 성장일수가 +1 된다(아직 다 자라기 전까지만).
#      T3.4: 여기에 여우불 가속(accel)을 더해 더 빨리 자란다(+1+accel).
#   2) T3.4 여우불 범위(reach): 물을 못 준 심긴 칸도 reach개까지 여우불이 대신
#      돌봐 +1 자란다('넓게'). 어느 칸을 돌볼지는 (y,x) 정렬 순으로 정해 결정적이다
#      (헤드리스 검증 재현성). 아침 마름 전 상태로 고르므로, 오늘 물 준 칸은 후보가
#      아니다(가속으로 이미 자람 — 이중 적용 방지).
#   3) 모든 경작 칸의 흙은 아침에 마른다(watered → false).
# accel/reach 기본 0 = 여우불 잠듦(순수 스타듀 성장 — 기존 동작·T2.3 그대로). 세기
# 매핑은 Foxfire(foxfire.gd)가 호감도 하트에서 파생하고, main이 값으로 넘긴다(디커플링).
# 상태가 바뀐 칸마다 tile_changed를 발화해 main이 오버레이를 갱신한다.
func advance_day(accel: int = 0, reach: int = 0) -> void:
	# 여우불 범위 후보를 마름 전(밤 상태)에 먼저 고른다 — 물 안 준 심긴 미성숙 칸.
	var foxfire_targets := _foxfire_targets(reach)
	# 1) 물 준 칸: 기본 +1 에 여우불 가속을 더해 자란다(성장일수는 작물 한계까지만).
	for t in _tiles.keys():
		var tile: Dictionary = _tiles[t]
		var changed := false
		if tile["planted"] and tile["watered"] and not is_mature(t):
			_grow(t, 1 + maxi(accel, 0))
			changed = true
		# 흙은 아침에 마른다.
		if tile["watered"]:
			tile["watered"] = false
			changed = true
		if changed:
			tile_changed.emit(t)
	# 2) 여우불 범위: 물 못 준 칸을 reach개까지 +1 돌본다(양육의 불, ADR-0004).
	for t in foxfire_targets:
		_grow(t, 1)
		tile_changed.emit(t)

# 한 칸의 성장일수를 n만큼 올리되 작물 성장일수(완성)까지만 잰다(가속 과성장 방지).
func _grow(t: Vector2i, n: int) -> void:
	var need := CropCatalog.growth_days(_tiles[t]["crop"])
	_tiles[t]["grown_days"] = mini(_tiles[t]["grown_days"] + n, need)

# T3.4 여우불 범위가 돌볼 칸 목록(물 못 준 심긴 미성숙 칸 중 (y,x) 정렬 순 limit개).
# 정렬로 결정적이라 헤드리스 검증이 재현 가능하다. limit ≤ 0이면 빈 배열.
func _foxfire_targets(limit: int) -> Array:
	if limit <= 0:
		return []
	var cands: Array = []
	for t in _tiles.keys():
		if _tiles[t]["planted"] and not _tiles[t]["watered"] and not is_mature(t):
			cands.append(t)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return cands.slice(0, limit)

# ── T2.5 세이브/로드 ──────────────────────────────────────────────────────
# 밭 상태(_tiles)는 Vector2i 키 + bool/String/int 값의 순수 Dictionary라,
# SaveManager의 var_to_str가 키 타입까지 그대로 라운드트립한다(이 노드가 inner
# class를 안 쓴 이유). 깊은 복사로 넘겨, 호출 측이 들고 있어도 상태가 새지 않게 한다.
func to_save() -> Dictionary:
	return {"tiles": _tiles.duplicate(true)}

# 복원: _tiles를 통째로 갈아끼우고, 칸마다 tile_changed를 발화해 main이 오버레이를
# 다시 그리게 한다(시각 동기화도 디커플링 유지). 로드 전 옛 오버레이 타일 제거는
# 호출 측(main) 책임이다 — 이 노드는 상태만 알고 화면 레이어를 모르기 때문.
func load_save(data: Dictionary) -> void:
	var tiles: Variant = data.get("tiles", {})
	_tiles = tiles.duplicate(true) if typeof(tiles) == TYPE_DICTIONARY else {}
	for t in _tiles.keys():
		tile_changed.emit(t)

# ── 단일 키 흐름 ─────────────────────────────────────────────────────────────
# 이 칸에서 다음에 할 수 있는 동작 이름("" = 더 할 것 없음). 프롬프트·interact가 공유한다.
func next_action(t: Vector2i) -> String:
	if not is_tilled(t):
		return "괭이질"
	if not is_planted(t):
		return "심기"
	if is_mature(t):
		return "수확"
	if not is_watered(t):
		return "물주기"
	return ""  # 심겼고 물도 줬으나 아직 덜 자람 → 내일을 기다린다

# 한 번의 상호작용: 칸 상태에 맞는 다음 동작을 수행하고 그 이름을 반환한다("" = 무동작).
# main의 입력 한 키(E)가 이걸 호출 → 누를 때마다 괭이질→심기→물주기→(성장)→수확.
# crop_id는 "심기" 단계에서만 쓰인다(main이 현재 선택한 작물을 넘긴다).
func interact(t: Vector2i, crop_id: String) -> String:
	var action := next_action(t)
	match action:
		"괭이질":
			hoe(t)
		"심기":
			plant(t, crop_id)
		"물주기":
			water(t)
		"수확":
			harvest(t)
	return action
