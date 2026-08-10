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

# ★ [S7-T5 / ADR-0065 결정 7] ADR-0055를 **가법으로만** 정밀화한다(밤 재점령 본체는 한 줄도 안 바뀐다).
#   ① 확산 — 이미 돋아 있는 잡초가 하룻밤에 인접 한 칸으로 번진다(잡초당 6%·혼우/절기 1일 ×2).
#      번진 자리에 작물·스프링클러가 있으면 **부순다**. 이건 성역 위반이 아니다: 성역(§2)은 "아무것도
#      없던 자리에 무에서 잡초가 스폰되는가"의 규칙이고, 확산은 "방치한 잡초가 옆으로 자라는가"라
#      플레이어가 이미 보고 있던 원인의 예고된 결과다(기습 아님 — ADR-0065 결정 7 문구 그대로).
#   ② 절기 전환 1일 대량 재스폰 — 빈 맨땅 후보(성역 규칙 그대로)에 잡초 위주 + solid debris 소량.
#      solid debris(업화석·석화 고목)는 시드 배치(_prop_layouts)에 없던 신규 개체라 여기 _debris 원장이
#      든다(시드 오염 금지 §10.1 — main이 프롭 엔트리로 병합해 그리고·막고·개간시킨다).
#   ③ 성야절 — 확산 정지·재스폰 없음 + 지상 잡초 소멸(purge_weeds).

# 치운 debris 좌표 집합. 키 = 타일(Vector2i), 값 = true. 키가 없음 = 아직 안 치움(debris 그대로).
var _cleared: Dictionary = {}

# ★ [ADR-0055] 재점령한 잡초 좌표 집합. 키 = 타일(Vector2i), 값 = true. advance_day가 밤마다 빈 맨땅
#   후보에서 1~2칸 골라 여기 얹고, main이 낫으로 베면(clear_weed) 지운다. _cleared와 별개 레이어다.
var _weeds: Dictionary = {}

# ★ [S7-T5] 절기 전환에 새로 돋은 **solid debris** 좌표 → kind(업화석·석화 고목). 잡초와 갈라 두는 이유:
#   잡초는 낫 한 번이라 좌표 집합이면 족하지만 이쪽은 종류가 둘이라 도구·드랍이 갈리고(곡괭이/도끼),
#   무엇보다 SOLID라 **통행을 막는다** — main이 프롭 엔트리로 병합해야 드로우·충돌·개간이 한 경로로 돈다.
#   치우면(clear) 여기서 빠지고 _cleared로 승격한다 = 그 자리는 영구 성역(ADR-0055 §2 불변).
var _debris: Dictionary = {}

# ── 재점령 레버(ADR-0055 §3 — cozy bounded, 정밀 수치는 Phase 3 밸런싱) ──────────
const RESPAWN_MIN := 1        # 밤당 최소 새 잡초 수(§3 "1~2칸")
const RESPAWN_MAX := 2        # 밤당 최대 새 잡초 수
const RESPAWN_CAP_RATIO := 0.75  # 총상한 = 자격 빈 맨땅의 이 비율까지만(§3 "대부분까지" — 완전 도배는 막음)

# ── ★[S7-T5] 확산 레버(ADR-0065 결정 7 — 수치 전부 잠정·owner 큐) ───────────────
const SPREAD_CHANCE := 0.06   # 잡초 한 포기가 하룻밤에 옆 칸으로 번질 확률
const SPREAD_WET_MULT := 2.0  # 혼우(비) 날·절기 1일 배수. 곱은 main이 하고 여기엔 인자로 들어온다
# 확산은 4방 중 **한 칸만** 노린다. 고른 칸이 못 쓸 자리면 그 밤은 그냥 실패다(다른 방향 재시도 없음) —
# 빽빽한 구석일수록 저절로 덜 번지는 자연 감쇠라, 별도 총상한 없이도 마당 도배가 안 난다.
const SPREAD_DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

# ── ★[S7-T5] 확산 목적지 분류 눈금 — main이 Callable로 판정해 준다(Reclaim은 지형·밭·설치물을 모른다) ─
const DEST_BLOCK := 0      # 면제 — SOLID(건물·울타리·바위)·과수·상자·기존 debris·길·물·이미 잡초
const DEST_OPEN := 1       # 빈 맨땅 / 갈아둔 흙(작물 없음) → 그냥 점유
const DEST_CROP := 2       # 작물 칸 → 작물 파괴 후 점유(파괴는 main이 farm.remove_plant로 집행)
const DEST_SPRINKLER := 3  # 스프링클러 칸 → 설치물 파괴 후 점유(파괴는 main이 sprinkler.remove로 집행)

# ── ★[S7-T5] 절기 전환 1일 대량 재스폰 레버 ────────────────────────────────────
const SEASON_RESPAWN_MIN := 8    # 절기 1일 재스폰 최소 개수
const SEASON_RESPAWN_MAX := 16   # 최대 개수
# 구성 가중(합 100) — 잡초 70 / 업화석 15 / 석화 고목 15. 대부분은 낫 한 번이고, 가끔 도구 게이트가
# 다시 선다("절기가 바뀌면 마당이 한 번 거칠어진다"는 리듬 — 개간이 완전히 끝나 버리지 않게).
const SEASON_W_WEEDS := 70
const SEASON_W_EMBER := 15
const SEASON_W_STUMP := 15

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

# ── ★[S7-T5] 절기 재스폰 solid debris 질의 ────────────────────────────────────
# 이 타일에 절기 재스폰 debris가 있으면 그 kind, 없으면 ""(이미 치운 자리도 "" — _cleared가 이긴다).
func respawned_debris_kind(t: Vector2i) -> String:
	if _cleared.has(t):
		return ""
	return str(_debris.get(t, ""))

# 절기 재스폰 debris 타일 목록(main 프롭 엔트리 병합·검증).
func respawned_debris_tiles() -> Array:
	return _debris.keys()

# 절기 재스폰 debris 수(검증·디버그).
func respawned_debris_count() -> int:
	return _debris.size()

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
	_debris.erase(t)   # ★[S7-T5] 절기 재스폰분이었다면 원장에서 뺀다(치운 자리는 _cleared 하나로 수렴)
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

# ── ★[S7-T5 / ADR-0065 결정 7] 잡초 확산 — 취침 트리거(advance_day의 짝) ────────
# 현존 잡초 각각이 SPREAD_CHANCE(×mult) 확률로 인접 4방 중 **한 칸**에 번진다. 반환은 main이 집행할
# 파괴 목록까지 함께 든 요약 = {"weeds": 새로 잡초가 앉은 칸, "crops": 삼킨 작물 칸, "sprinklers": 부순 설치 칸}.
#
# 인자(기존 advance_day 문법 계승 — Reclaim은 Weather도 farm도 sprinkler도 모른다):
#   · extra_sources — **원장 밖의 현존 잡초**. _weeds는 밤 재점령분만 담고, 처음부터 마당에 깔려 있던
#     overgrown 잡초 debris(아직 안 벤 것)는 _prop_layouts/절차 스캐터에 있어 여기가 모른다. 그래서
#     "현존 잡초 집합 = _weeds ∪ extra_sources"로 정의하고, 뒤쪽은 main이 골라 넣는다.
#   · classify — 목적지 한 칸을 DEST_* 눈금으로 답하는 Callable(main._weed_spread_cb).
#   · mult — 혼우·절기 1일이면 SPREAD_WET_MULT, 아니면 1.0(곱하는 판단은 main의 몫).
#
# 결정성: day 시드 RNG를 **"weed_spread:" 별도 네임스페이스**로 세운다(advance_day의 "weeds:" 스트림과
#   분리 — 한쪽에 롤이 하나 늘어도 다른 쪽 출목이 안 흔들린다). 소스는 좌표 정렬 후 순차 소비라
#   입력 순서가 달라도 같은 답이 나온다.
# 이번 밤에 새로 앉은 잡초는 **그 밤의 소스가 아니다**(시작 시점에 스냅샷 — 한 밤에 사슬 폭주 금지).
func spread_day(extra_sources: Array, classify: Callable, day: int, is_winter: bool,
		mult: float = 1.0) -> Dictionary:
	var out := {"weeds": [], "crops": [], "sprinklers": []}
	if is_winter:
		return out                                  # 잿눈 — 확산도 정지(재점령과 같은 겨울 불변식)
	if not classify.is_valid():
		return out                                  # 안식에 없는 프레임(다른 구역서 취침) → 그 밤은 스킵
	# 현존 잡초 스냅샷(원장 + main이 준 원장 밖 잡초) — 중복 제거 후 결정적 정렬.
	var seen: Dictionary = {}
	for t in _weeds:
		seen[t] = true
	for t in extra_sources:
		if typeof(t) == TYPE_VECTOR2I and not _cleared.has(t):
			seen[t] = true
	if seen.is_empty():
		return out
	var sources: Array = seen.keys()
	sources.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("weed_spread:%d" % day)
	var p := clampf(SPREAD_CHANCE * mult, 0.0, 1.0)
	for src: Vector2i in sources:
		if rng.randf() >= p:
			continue
		var dst: Vector2i = src + SPREAD_DIRS[rng.randi_range(0, SPREAD_DIRS.size() - 1)]
		if _weeds.has(dst):
			continue                                # 이미 잡초(같은 밤 다른 소스가 앉힌 칸 포함)
		var cls := int(classify.call(dst))
		if cls == DEST_BLOCK:
			continue                                # 면제 — 아무 일도 없다
		if cls == DEST_CROP:
			out["crops"].append(dst)
		elif cls == DEST_SPRINKLER:
			out["sprinklers"].append(dst)
		_weeds[dst] = true
		out["weeds"].append(dst)
	if not out["weeds"].is_empty():
		changed.emit()
	return out

# ── ★[S7-T5 / ADR-0065 결정 7] 절기 전환 1일 대량 재스폰 ───────────────────────
# 자격 빈 맨땅 후보(advance_day와 **같은** _encroach_candidates 산출 = 성역 규칙 그대로)에서
# SEASON_RESPAWN_MIN~MAX칸을 골라 잡초 70% · 업화석 15% · 석화 고목 15%로 채운다.
# 반환 = {"weeds": [], "ember": [], "stump": []}(main이 알림·프롭 병합에 쓴다).
#   · 성야절(is_winter) 진입 1일은 **재스폰 없음**(그날은 purge_weeds가 도는 날이다 — 결정 7).
#   · 결정적: day 시드 "season_respawn:" 네임스페이스 Fisher–Yates(advance_day와 동형).
func season_respawn(candidates: Array, day: int, is_winter: bool) -> Dictionary:
	var out := {"weeds": [], "ember": [], "stump": []}
	if is_winter or candidates.is_empty():
		return out
	# 이미 잡초/재스폰 debris가 앉은 칸은 뺀다(후보 자체가 프롭·개간 자리를 이미 걸러 왔다).
	var pool: Array = []
	for t in candidates:
		if not _weeds.has(t) and not _debris.has(t):
			pool.append(t)
	if pool.is_empty():
		return out
	pool.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("season_respawn:%d" % day)
	var want := rng.randi_range(SEASON_RESPAWN_MIN, SEASON_RESPAWN_MAX)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	want = mini(want, pool.size())
	var total := SEASON_W_WEEDS + SEASON_W_EMBER + SEASON_W_STUMP
	for k in range(want):
		var t: Vector2i = pool[k]
		var r := rng.randi_range(0, total - 1)
		if r < SEASON_W_WEEDS:
			_weeds[t] = true
			out["weeds"].append(t)
		elif r < SEASON_W_WEEDS + SEASON_W_EMBER:
			_debris[t] = DebrisCatalog.EMBER
			out["ember"].append(t)
		else:
			_debris[t] = DebrisCatalog.STUMP
			out["stump"].append(t)
	if want > 0:
		changed.emit()
	return out

# ── ★[S7-T5 / ADR-0065 결정 7] 성야절 잡초 소멸 ────────────────────────────────
# 성야 1일 아침, 지상의 재점령 잡초가 전량 사라진다(스타듀 겨울 동형 — 눈이 마당을 한 번 덮는다).
# 지운 수를 반환. **_cleared는 안 건드린다** = "치운 자리 성역"과 무관하고, 개간 진보도 안 준다.
# ★ 시드 배치 overgrown 잡초(아직 안 벤 debris)는 여기서 안 없앤다 — 그걸 지우려면 _cleared에 넣어야
#   하는데 그건 "개간 완료 = 경작 가능"을 공짜로 주는 것이라(마당 전체가 하룻밤에 열린다) 선을 넘는다.
#   눈이 덮는 건 밤새 스민 잡초지, 아직 개간 안 한 황무지가 아니다.
# ★ 재스폰 solid debris(_debris)도 안 없앤다 — 돌·그루터기는 잡초가 아니다(겨울에 사라질 물건이 아님).
func purge_weeds() -> int:
	var n := _weeds.size()
	if n == 0:
		return 0
	_weeds.clear()
	changed.emit()
	return n

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
	# ★[S7-T5] 절기 재스폰 solid debris — 종류가 갈리므로 [x, y, kind] 3튜플(가법 키, VERSION 불변).
	var debris: Array = []
	for t in _debris:
		debris.append([t.x, t.y, str(_debris[t])])
	return {"cleared": tiles, "weeds": weeds, "debris": debris}

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
	_debris = {}               # ★[S7-T5] 키 없는 구버전 세이브 = 재스폰 debris 0(하위호환)
	var debris: Variant = data.get("debris", [])
	if typeof(debris) == TYPE_ARRAY:
		for e in debris:
			if typeof(e) == TYPE_ARRAY and e.size() >= 3 and DebrisCatalog.has(str(e[2])):
				_debris[Vector2i(int(e[0]), int(e[1]))] = str(e[2])
	changed.emit()
