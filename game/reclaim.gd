extends Node
class_name Reclaim
# S1-8 — 안식 농원 overgrown 개간(debris 치우기). 치운 좌표 델타만 소유하는 얇은 원장(ledger).
#
# 목적: ROADMAP S1-8 — 맞는 도구(낫/곡괭이/도끼)로 debris 3종을 치우면 그 자리가 열리고(통과·경작지
#       확장) 재료가 드랍되며, 세이브로 영속하는지 헤드리스로 검증한다. 설계 = greybox-spec §10.
#
# 왜 별개 노드인가(§10.1·§10.3, Orchard/Ranch 동형 완전 분리):
#   - debris 배치는 PROP_LAYOUT_HOME 시드(설계 데이터·layout.json)에 잠겨 있다. 개간은 그 위에
#     "무엇을 치웠나"라는 플레이어 세이브 델타만 얹는 것 — Reclaim은 그 델타 집합 하나만 소유하고,
#     _prop_layouts(설계 시드)는 절대 안 건드린다(layout.json 오염 방지). main이 드로우/충돌
#     skip-filter와 farmable 판정에서 이 델타를 질의한다(디커플링 — Reclaim은 화면·지형을 모른다).
#   - 치운 좌표 = 개간 완료 = 경작 가능(단일 집합). "치움"과 "reclaimed(farmable)"를 한 집합으로 둔다.
#
# 설계 메모(§10.2·§10.3):
#   - 도구↔debris 매칭·드랍은 DebrisCatalog(정적 데이터)에 위임. Reclaim은 kind를 받아 카탈로그로
#     판정만 하고, "무슨 debris가 어느 타일에" 있는지는 모른다(그건 main이 텍스처→kind로 준다).
#   - 상태 = Vector2i 키 순수 Dictionary(값은 true 플래그) → var_to_str 그대로 라운드트립(Orchard 결).
#
# ★ [ADR-0055] 차등형 재점령(再占領, encroachment) — 옛 "advance_day 없음(1회성 개간)"을 개정한다.
#   빈 맨땅에 밤새 잡초(이승의 미련·non-solid)가 다시 돋는다(스타듀식 유지보수 정취). 단 구조물(돌·
#   그루터기=solid)을 치운 자리는 영구 성역이라 재점령하지 않고(진보=영구), 밭·작물도 절대 안 침범한다.
#   그래서 원장을 둘로 나눈다: _cleared(치운 것 = 일방향 진보) + _weeds(재점령 잡초 = 매일의 돌봄).
#   자격 빈 맨땅 후보는 main이 준다(Reclaim은 화면·지형을 모른다 — Forage/Crow 결의 디커플링).

signal changed()   # debris를 치우거나 잡초가 돋거나/베인 프레임(main이 듣고 드로우/충돌 갱신)

# 치운 debris 좌표 집합. 키 = 타일(Vector2i), 값 = true. 키가 없음 = 아직 안 치움(debris 그대로).
var _cleared: Dictionary = {}

# ★ [ADR-0055] 재점령한 잡초 좌표 집합. 키 = 타일(Vector2i), 값 = true. advance_day가 밤마다 빈 맨땅
#   후보에서 1~2칸 골라 여기 얹고, main이 낫으로 베면(clear_weed) 지운다. _cleared와 별개 레이어다.
var _weeds: Dictionary = {}

# ── 재점령 레버(ADR-0055 §3 — cozy bounded, 정밀 수치는 Phase 3 밸런싱) ──────────
const RESPAWN_MIN := 1        # 밤당 최소 새 잡초 수(§3 "1~2칸")
const RESPAWN_MAX := 2        # 밤당 최대 새 잡초 수
const RESPAWN_CAP_RATIO := 0.75  # 총상한 = 자격 빈 맨땅의 이 비율까지만(§3 "대부분까지" — 완전 도배는 막음)

# ── 질의 ────────────────────────────────────────────────────────────────────
# 이 타일의 debris를 이미 치웠는가(드로우/충돌 skip·farmable 판정이 쓴다).
func is_cleared(t: Vector2i) -> bool:
	return _cleared.has(t)

# 치운 타일 수(검증·디버그).
func cleared_count() -> int:
	return _cleared.size()

# ── 재점령 질의(ADR-0055) ─────────────────────────────────────────────────────
# 이 타일에 재점령한 잡초가 있는가(드로우·낫 디스패치·프롬프트가 쓴다).
func has_weed(t: Vector2i) -> bool:
	return _weeds.has(t)

# 재점령 잡초 타일 목록(드로우·검증).
func weed_tiles() -> Array:
	return _weeds.keys()

# 재점령 잡초 수(검증·디버그).
func weed_count() -> int:
	return _weeds.size()

# ── 개간(§10.3) ──────────────────────────────────────────────────────────────
# 조준 타일의 debris(kind)를 든 도구(tool_id)로 친다. 성공 시 {"drop":재료id, "count":수} 반환·
# changed.emit(). 실패(이미 치움 / 미지 kind / 도구 불일치)면 {} — 무동작(ADR-0024 §2). 멱등.
func clear(t: Vector2i, kind: String, tool_id: String) -> Dictionary:
	if _cleared.has(t):
		return {}                                   # 이미 개간됨(멱등)
	if not DebrisCatalog.has(kind):
		return {}                                   # 미지 debris(방어)
	if DebrisCatalog.tool_for(kind) != tool_id:
		return {}                                   # 틀린 도구 → 무동작
	_cleared[t] = true
	changed.emit()
	return {"drop": DebrisCatalog.drop_for(kind), "count": DebrisCatalog.drop_count(kind)}

# ── 재점령 잡초 낫질(ADR-0055) ────────────────────────────────────────────────
# 밤새 돋은 잡초를 낫으로 벤다(LMB). 성공 시 잡초 드랍({"drop":혼백섬유,"count":1} = WEEDS와 동일)을
# 반환하고 changed.emit(). 잡초 없음 / 틀린 도구(낫만)면 {} — 무동작(ADR-0024 §2). 멱등.
func clear_weed(t: Vector2i, tool_id: String) -> Dictionary:
	if not _weeds.has(t):
		return {}                                   # 재점령 잡초 아님
	if DebrisCatalog.tool_for(DebrisCatalog.WEEDS) != tool_id:
		return {}                                   # 낫 아님 → 무동작
	_weeds.erase(t)
	changed.emit()
	return {"drop": DebrisCatalog.drop_for(DebrisCatalog.WEEDS), "count": DebrisCatalog.drop_count(DebrisCatalog.WEEDS)}

# ── 하루 경과(재점령) — 취침 트리거(ADR-0055 §3·§4) ───────────────────────────
# 자격 빈 맨땅 후보(candidates — main이 밭·작물·구조물·프롭 성역을 이미 배제해 전달)에서 아직 잡초가 안
# 돋은 칸 중 RESPAWN_MIN~MAX개를 골라 새 잡초를 얹는다. 새로 얹은 타일 목록을 반환(부수효과 = _weeds 추가).
#   · 총상한: 후보의 RESPAWN_CAP_RATIO까지만(완전 도배 방지 — §3 "대부분까지").
#   · 결정적: day 시드 셔플(Crow 결 — 같은 날·같은 후보 → 같은 결과, 헤드리스 재현).
#   · 겨울(잿눈=is_winter)엔 멈춘다(§4 — Forage·작물 사멸과 같은 저승 겨울 성장정지 불변식).
func advance_day(candidates: Array, day: int, is_winter: bool) -> Array:
	if is_winter:
		return []                                   # 잿눈 — 재점령 정지(봄에 다시 스민다)
	if candidates.is_empty():
		return []
	var cap := int(ceil(candidates.size() * RESPAWN_CAP_RATIO))
	if _weeds.size() >= cap:
		return []                                   # 총상한 도달 — 마당이 이미 충분히 거칠어짐
	# 아직 잡초 없는 후보만 추림(이미 돋은 칸 재선정 방지).
	var pool: Array = []
	for t in candidates:
		if not _weeds.has(t):
			pool.append(t)
	if pool.is_empty():
		return []
	# 결정적 정렬(입력 순서 무관) 후 day 시드 Fisher–Yates 셔플(Crow.resolve와 동형).
	pool.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("weeds:%d" % day)
	var want := rng.randi_range(RESPAWN_MIN, RESPAWN_MAX)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	want = mini(want, mini(pool.size(), cap - _weeds.size()))   # 상한·후보 한도
	var added: Array = []
	for k in range(want):
		_weeds[pool[k]] = true
		added.append(pool[k])
	if not added.is_empty():
		changed.emit()
	return added

# ── 세이브/로드(§10.6) — Orchard 패턴 계승 ────────────────────────────────────
# _cleared는 Vector2i 키 순수 Dictionary라, 키를 [x,y] 배열 목록으로 직렬화한다(var_to_str도 되지만
# JSON·구조 안정성 위해 명시 목록). 로드는 통째 재구성 후 changed로 main이 드로우/충돌을 다시 세운다.
func to_save() -> Dictionary:
	var tiles: Array = []
	for t in _cleared:
		tiles.append([t.x, t.y])
	var weeds: Array = []      # ★ [ADR-0055] 재점령 잡초 좌표(치운 debris와 별개 레이어)
	for t in _weeds:
		weeds.append([t.x, t.y])
	return {"cleared": tiles, "weeds": weeds}

func load_save(data: Dictionary) -> void:
	_cleared = {}
	var tiles: Variant = data.get("cleared", [])
	if typeof(tiles) == TYPE_ARRAY:
		for e in tiles:
			if typeof(e) == TYPE_ARRAY and e.size() >= 2:
				_cleared[Vector2i(int(e[0]), int(e[1]))] = true
	_weeds = {}                # ★ [ADR-0055] — 키 없는 구버전 세이브는 잡초 0(하위호환)
	var weeds: Variant = data.get("weeds", [])
	if typeof(weeds) == TYPE_ARRAY:
		for e in weeds:
			if typeof(e) == TYPE_ARRAY and e.size() >= 2:
				_weeds[Vector2i(int(e[0]), int(e[1]))] = true
	changed.emit()
