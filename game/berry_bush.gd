extends RefCounted
class_name BerryBushes
# ★[S4-T8 / ADR-0062 결정 9 ㉠] 채집 덤불 — "지금 어느 덤불에 열매가 달려 있나"만 소유하는 얇은 원장.
#
# 목적: 카탈로그 §2-2 ㉢(덤불 3역할 중 *열매 덤불*)의 빌드 형태. 숲 2구역의 채집 덤불을 **[F] 흔들기**로
#       털면 절기 창 안일 때만 열매가 떨어진다. 창 밖이면 덤불은 그냥 덤불이다(빈손 — 벌칙이 아니라
#       "지금은 철이 아니다"의 표현).
#
# 왜 별개 원장인가(ForageSpawns/TreeLedger/TapperLedger 동형 완전 분리):
#   - **덤불 자리는 맵이 소유하고, 열매 유무만 이 원장이 소유한다**(ForageSpawns가 "칸+종"을 통째로 드는
#     것과 갈리는 지점). 덤불은 매일 굴러 나오는 스폰이 아니라 *그 자리에 계속 서 있는 프롭*이라, 좌표는
#     상수(main의 배치 테이블)고 델타는 열매 플래그 하나뿐이다 — 세이브가 그만큼 얇다.
#   - **안식 능선의 SOLID 덤불(PR#201)과는 별개 프롭**이다(ADR-0062 결정 9 ㉠ 경고 · §2-2 역할 분리).
#     저건 순수 통행 벽이고 이건 채집 대상이다. 기존 덤불에 기능을 얹으면 "지나갈 수 없는데 털 수는
#     있는" 물건이 되어 두 역할이 뭉개진다. 그래서 이쪽은 **통행 가능**(꽃 패치 결)이다 — flood-fill
#     도달성·구역 테스트 불변식을 한 칸도 안 건드린다는 뜻이기도 하다.
#   - **RefCounted(비-Node)**: 순수 데이터라 씬 트리에 설 이유가 없다(ForageSpawns와 같은 판단).
#
# 설계 메모(어기면 ADR-0062 결정 9 ㉠ 위반):
#   - **결정 롤**: day + 구역 + 좌표 시드(ForageSpawns.advance_day 선례). 전역 randf 금지 — 같은 날
#     같은 덤불은 몇 번을 굴려도 같은 결과라 헤드리스가 정확히 재현한다.
#   - **절기 창 밖이면 롤 자체가 없다.** 그리고 창을 벗어나는 순간 남아 있던 열매도 진다(채집물 스폰의
#     "절기 전환일 전량 삭제"와 같은 결 — 철 지난 열매가 이듬해까지 매달려 있지 않게).
#   - **혼력 0**(ADR-0033 #1 "줍기는 혼력을 안 먹는다"). 흔들기는 도구 없는 맨손 동작이라 줍기 결이다
#     — 이 파일이 SoulEnergy를 모르는 것 자체가 그 불변식의 구조적 보증이다.
#   - **수량·XP는 호출 측이 정한다.** 채집 레벨 계단(1/2/3)은 ForageSkill.bush_yield가 유일 출처고,
#     이 원장은 "열매가 있었나 없었나"만 답한다(ForageSpawns.pick과 같은 디커플링 경계).

signal changed()   # 결실·흔들기·복원한 프레임(main이 듣고 드로우·프롬프트 갱신)

# ── 절기 창(ADR-0062 결정 9 ㉠ — 스타듀 salmonberry/blackberry 1:1) ────────────
# 스타듀는 연어딸기 봄 15~18일 · 블랙베리 가을 8~11일로 **한 해에 나흘씩 두 번**만 열린다. 그 희소성이
# 곧 이 시스템의 맛이라(달력에 표시해 두고 그날 숲을 훑는다) 창 폭을 그대로 상속한다.
const WINDOWS := [
	{"season": 0, "from": 15, "to": 18, "item": ItemCatalog.NEOK_DALGI},        # 피안절 15~18일 — 넋딸기
	{"season": 2, "from": 8, "to": 11, "item": ItemCatalog.JAETBIT_BOKBUNJA},   # 망연절 8~11일 — 잿빛복분자
]
const BERRY_CHANCE := 0.20   # 덤불당 하룻밤 결실 확률(스타듀 상속 — 창 나흘이면 덤불마다 한 번쯤 열린다)

# 열매 원장. { region(String) → { Vector2i → true } }. 값은 언제나 true라 사실상 집합이다
# (종은 날짜가 정하므로 칸별로 들 게 없다 — ForageSpawns가 종을 드는 것과 갈리는 지점).
var _berries: Dictionary = {}

# ── 정적 규칙 ───────────────────────────────────────────────────────────────
# 이 날의 절기 내 일차(1..28). ★[S7-T1] 옛 자체 파생(`(day-1)%28+1`)은 clock의 파생으로 수렴했다
# (S7이 절기 전환을 정식 이벤트로 올리며 일차 계산이 세 곳에 흩어져 있던 걸 한 곳으로 모음).
# 이름은 남긴다 — 아래 berry_for_day가 계속 부르는 이 파일의 읽기 좋은 창구다.
static func day_of_season(day: int) -> int:
	return GameClock.day_of_season(day)

# 이 날 덤불에 달릴 수 있는 열매 id("" = 절기 창 밖 = 결실 롤 없음).
static func berry_for_day(day: int) -> String:
	var season := GameClock.season_index_for_day(day)
	var dos := day_of_season(day)
	for w in WINDOWS:
		if int(w["season"]) == season and dos >= int(w["from"]) and dos <= int(w["to"]):
			return String(w["item"])
	return ""

# 이 날이 절기 창 안인가(프롬프트·안내 문구용 — berry_for_day의 가독 별칭).
static func in_window(day: int) -> bool:
	return berry_for_day(day) != ""

# 열매 로스터(도감·테스트 — 창 순서대로).
static func all_berries() -> Array:
	var out: Array = []
	for w in WINDOWS:
		out.append(String(w["item"]))
	return out

# ── 질의 ────────────────────────────────────────────────────────────────────
# 이 구역·이 칸의 덤불에 열매가 달려 있나.
func has_berry(region: String, t: Vector2i) -> bool:
	return _berries.has(region) and _berries[region].has(t)

# 이 구역의 열매 달린 칸 목록(드로우·검증 — 정렬해 결정적 순회).
func tiles(region: String) -> Array:
	if not _berries.has(region):
		return []
	var out: Array = _berries[region].keys()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return out

func count(region: String) -> int:
	return int(_berries[region].size()) if _berries.has(region) else 0

func total() -> int:
	var n := 0
	for region in _berries:
		n += int(_berries[region].size())
	return n

# ── 흔들기 ──────────────────────────────────────────────────────────────────
# 이 덤불을 턴다(열매 플래그를 지우고 그 날의 열매 id 반환, "" = 열매 없음). 수량·XP·인벤 적재는 전부
# 호출 측(main._shake_bush)이 채집 레벨로 정한다 — 이 원장은 그걸 모른다(ForageSpawns.pick 1:1).
# ★ 혼력 0(ADR-0033 #1): 이 파일이 SoulEnergy를 모르는 것 자체가 그 불변식의 구조적 보증이다.
func shake(region: String, t: Vector2i, day: int) -> String:
	if not has_berry(region, t):
		return ""
	var id := berry_for_day(day)
	_berries[region].erase(t)
	if _berries[region].is_empty():
		_berries.erase(region)      # 빈 구역 키는 남기지 않는다(세이브 군더더기 0 — ForageSpawns 결)
	changed.emit()
	if id == "":
		return ""                   # 창 밖인데 플래그가 남아 있던 이상 상태 — 플래그만 정리하고 빈손
	return id

# 열매 플래그를 직접 세운다/내린다. 정상 흐름은 advance_day(결실)와 shake(수확)뿐이고, 이 함수는
# **되돌리기 전용**이다 — 인벤이 가득 차 흔든 열매를 못 담았을 때 main이 덤불에 되돌린다(산출물
# 증발 방지. 게잡이통·수액 채취기가 "인벤 가득이면 원장에 그대로 둔다"로 막는 것과 같은 손실 방지).
func set_berry(region: String, t: Vector2i, on: bool) -> void:
	if on:
		if not _berries.has(region):
			_berries[region] = {}
		_berries[region][t] = true
	elif has_berry(region, t):
		_berries[region].erase(t)
		if _berries[region].is_empty():
			_berries.erase(region)
	changed.emit()

# ── 하루 경과(밤 결실 롤) — 취침 트리거 ──────────────────────────────────────
# 반환 = {"berried": [{region,tile}], "cleared": int, "item": String("" = 창 밖)}.
#   ① 절기 창 밖이면 **롤이 아예 없고**, 남아 있던 열매도 전량 진다(철 지난 열매를 안 남긴다).
#   ② 창 안이면 열매 없는 덤불마다 20% 결정 롤로 열매가 달린다.
#   · bush_map = {region → [Vector2i]} — 덤불 자리는 main(맵)이 소유하고 원장은 주입받는다.
#   · 결정적: day + 구역 + 좌표 시드. 구역·좌표는 정렬 순회라 Dictionary 키 순서에 안 기댄다.
func advance_day(day: int, bush_map: Dictionary) -> Dictionary:
	var out := {"berried": [], "cleared": 0, "item": berry_for_day(day)}
	if String(out["item"]) == "":
		out["cleared"] = total()
		if int(out["cleared"]) > 0:
			_berries = {}
			changed.emit()
		return out
	var regions: Array = bush_map.keys()
	regions.sort()
	for region: String in regions:
		var list: Variant = bush_map[region]
		if typeof(list) != TYPE_ARRAY:
			continue
		for raw in list:
			if typeof(raw) != TYPE_VECTOR2I:
				continue
			var t: Vector2i = raw
			if has_berry(region, t):
				continue                       # 이미 달렸다(안 딴 열매 위에 또 달리지 않는다)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("berry:%d:%s:%d:%d" % [day, region, t.x, t.y])
			if rng.randf() >= BERRY_CHANCE:
				continue
			if not _berries.has(region):
				_berries[region] = {}
			_berries[region][t] = true
			out["berried"].append({"region": region, "tile": t})
	if not out["berried"].is_empty():
		changed.emit()
	return out

# ── 세이브/로드(ForageSpawns 패턴 계승) — 슬라이스 키 "berry_bush" 네임스페이스 ──
# 구역별 [x, y] 2항 배열 목록. 종은 날짜가 정하므로 직렬화할 게 좌표뿐이다.
# ★ 하위호환: 키 없는 구세이브 = 열매 0(첫 취침의 advance_day가 절기 창이면 다시 단다 — 무막힘).
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for region in _berries:
		var arr: Array = []
		for t: Vector2i in _berries[region]:
			arr.append([t.x, t.y])
		out[region] = arr
	return {"berries": out}

func load_save(data: Dictionary) -> void:
	_berries = {}
	var raw: Variant = data.get("berries", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for region in raw:
			var arr: Variant = raw[region]
			if typeof(arr) != TYPE_ARRAY:
				continue
			var by_tile: Dictionary = {}
			for raw_e in arr:
				if typeof(raw_e) != TYPE_ARRAY:
					continue
				var e: Array = raw_e
				if e.size() < 2:
					continue
				by_tile[Vector2i(int(e[0]), int(e[1]))] = true
			if not by_tile.is_empty():
				_berries[String(region)] = by_tile
	changed.emit()
