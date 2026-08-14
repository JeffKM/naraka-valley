extends RefCounted
class_name PanningSpots
# ★[S10-T1 / ADR-0069 결정 2] 팬닝(사금) 스폿 원장 — "오늘 어느 물가가 반짝이나"만 소유하는 얇은 원장.
#
# 목적: ADR-0069 결정 2 앞줄("물가 사금 스폿을 삼도천·황천해 한정으로 둔다 — 카탈로그 §1-E '낚시터
#       부수 채취로 흡수' 자구의 이행")의 빌드 형태. 낚시하러 간 물가에서 **낚시가 아닌 두 번째
#       동사**가 하나 열린다: 반짝이는 자리를 [F]로 일어 광석·냥·보석·결정기 부품을 건진다.
#
# 왜 별개 원장인가(ForageSpawns/CrabPotLedger/TreeLedger 동형 완전 분리):
#   - **RefCounted(비-Node)**: 설치물이 아니라 순수 데이터라 씬 트리에 설 이유가 없다(ForageSpawns 결).
#   - 이 파일은 지형·화면·인벤토리·지갑·혼력·전문직을 **하나도 모른다**. "여기가 정말 물가인가"는
#     main의 `_is_waterside`가 실그리드로 보고(panning_test ⑨가 그 일치를 단언한다), 산출 적재·혼력
#     과금도 전부 main이 한다. 이 원장은 "오늘 어느 칸이 스폿이고, 일면 무엇이 나오나"만 안다.
#   - 상태 = 구역별 Vector2i 키 Dictionary(CrabPotLedger의 다구역 원장 템플릿 1:1). 삼도천(56×40)·
#     황천해(64×44)가 좌표 공간을 공유해서, 구역을 안 나누면 두 구역의 같은 칸이 한 스폿으로 뭉개진다.
#
# ★ ForageSpawns와 갈리는 **단 하나의 축**: 채집물은 *쌓이고*(상한 6·7일 주기 리셋) 스폿은 *매일
#   새로 깔린다*. advance_day가 맨 앞에서 전량을 지우고 그날 것만 굴린다 — 스타듀의 사금 자리
#   (하루 한 자리·다음 날이면 옮겨간다) 문법 그대로다. 그래서 "어제 못 간 자리"가 쌓여 물가가
#   반짝이 밭이 되는 일이 없고, 방치해도 손실이 아니라 그냥 오늘 것을 놓친 것뿐이다(코지 — 벌칙 0).
#
# 설계 메모(어기면 ADR-0069 결정 2 위반):
#   - **삼도천·황천해 한정**. zones()에 그 둘만 있는 것이 그 한정의 구조적 보증이다(안식 연못·나루
#     배후 강엔 안 돋는다 — "낚시터 부수 채취"라는 자리매김이 무대로 표현된다).
#   - **day-해시 결정적 · 구역당 0~2**. 전역 randf 금지 — 같은 날 같은 구역은 몇 번을 굴려도 같은
#     자리·같은 산출이라 헤드리스가 정확히 재현한다(CrabPotLedger.advance_day·CrowRaid.resolve 선례).
#   - **오색혼옥은 산출표에 없다**([ADR-0063] 결정 2 초희귀 지위 보존). 결정기가 오색혼옥을 거부하는
#     것과 같은 규율의 앞단이다 — 초희귀는 *들어오는 길*도 좁아야 한다.
#   - **혼력은 소량 과금**(PAN_ENERGY). 값의 단일 출처는 여기지만 *소모*는 main이 한다 — 이 파일이
#     SoulEnergy를 모르는 것 자체가 원장 순수성의 보증이다(TreeLedger가 XP를 반환만 하는 것과 같은 결).

signal changed()   # 일일 재배치·채취·복원한 프레임(main이 듣고 드로우·프롬프트 갱신)

# 오늘의 스폿 원장. { region(String) → { Vector2i → true } }
#   값이 bool뿐인 이유: 스폿에는 종류가 없다("반짝이는 자리" 하나뿐). 무엇이 나오나는 *일 때*
#   좌표·day 해시로 결정되므로 원장에 실어 둘 상태가 아니다(미리 굴려 두면 세이브가 답을 안다).
var _spots: Dictionary = {}

# ── 채취 규격(전부 *잠정* — ADR-0069 결정 1 "폴리시 이월"·owner 큐) ─────────────
const SPOT_MAX := 2          # 구역당 하루 최대 스폿 수(ADR 결정 2 "구역당 0~2")
const PAN_ENERGY := 4        # 한 번 이는 데 드는 혼력(ADR 결정 2 "혼력 소량 · 잠정 4")
const PAN_GOLD := 40         # 사금 한 줌이 바로 되는 냥(산출표의 "냥" 행 — 잠정)

# 그날 스폿 개수의 가중 분포(합 100). 0이 4분의 1인 것이 "구역당 0~2"의 0을 실존하게 한다 —
# 어떤 날은 강가가 그냥 조용하다(매일 보장되면 리추얼이 아니라 일과가 된다).
const COUNT_WEIGHTS := [25, 50, 25]   # [0개, 1개, 2개] — 기대 1.0개/구역·일(잠정)

# ── 스폿 존(물가 밴드) ───────────────────────────────────────────────────────
# ★ 정적 const 대신 static func인 이유 = ForageSpawns.zones()·CrabPotLedger.catch_table()과 동일:
#   구역 id의 단일 출처가 RegionCatalog라 const 초기화식에서 타 클래스 상수를 참조하지 않는다.
# ★ 두 rect 모두 **물 밴드 바로 옆 한 줄**이다. 그래서 존 칸 전량이 main의 `_is_waterside` 판정을
#   통과하고(panning_test ⑨가 실그리드로 단언한다) 걸어서 닿는다:
#   · 삼도천 = 남안 스트립 y37(강 밴드 y30~36 바로 아래). 잔교 스파인 x28에서 서쪽으로 걸어 붙는다.
#     잔교 열(x28)과 나룻배·말뚝 프롭 자리를 전부 비껴간다.
#   · 황천해 = 백사장 남단 y27(바다 y28~ 바로 위). 부두 스파인 x28·생선가게(x8~14)·백사장 채집 존
#     (ForageSpawns Rect2i(40,20,7,5) = y20~24)과 한 칸도 겹치지 않는다.
static func zones() -> Dictionary:
	return {
		RegionCatalog.SAMDOCHEON: [Rect2i(18, 37, 10, 1)],       # x18..27, y37(남안 물가)
		RegionCatalog.HWANGCHEONHAE: [Rect2i(38, 27, 10, 1)],    # x38..47, y27(백사장 남단)
	}

# 이 구역·이 칸이 스폿 존 안인가(스폰 필터·검증). ForageSpawns.zone_kind_at의 bool판.
static func in_zone(region: String, t: Vector2i) -> bool:
	for r in zones().get(region, []):
		if Rect2i(r).has_point(t):
			return true
	return false

# 이 구역의 스폰 후보 칸 전체(존 rect 안, 좌→우·위→아래 정렬). 결정적 순회의 축이자
# 테스트의 "존 밖 스폰 0"·"전 후보가 물가" 판정 기준이다.
static func candidates(region: String) -> Array:
	var out: Array = []
	for z in zones().get(region, []):
		var r: Rect2i = z
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				out.append(Vector2i(x, y))
	return out

# 사금 스폿이 도는 구역 목록(정렬 — 결정적 순회).
static func spawn_regions() -> Array:
	var out: Array = zones().keys()
	out.sort()
	return out

# ── 산출표(가중 합 1000 — CrabPotLedger.catch_table·SalvageTable 결) ──────────
# 읽는 법: 스폿 하나를 일면 무엇이 나오나의 분포. 행은 전부 같은 모양이라 호출부가 분기 없이 읽는다
#   {"id": 아이템 id("" = 순수 사금 = 냥만), "count": 개수, "gold": 냥, "weight": 가중}
# ★ 광석·혼탄 55% / 냥 25% / 보석 13% / 결정기 부품 5.5% — "채광을 안 해도 광물이 조금씩 들어오는
#   물가의 부수입"이 이 표의 자리다(갱도 시세를 대체하지 않는다: 명동 2개 = 10냥 남짓이고, 하루
#   기대 스폿이 두 구역 합쳐 2개라 하루 벌이가 100냥 안팎이다 — 결정 2 "경제 가드"의 실수치).
# ★ **오색혼옥은 없다**(ADR-0063 결정 2 초희귀 지위 보존 — panning_test가 부재를 단언한다).
# ★ 정적 const 대신 static func인 이유 = catch_table()과 동일(항목 id의 단일 출처 = ItemCatalog).
static func yield_table() -> Array:
	return [
		{"id": ItemCatalog.ORE_MYEONGDONG, "count": 2, "gold": 0, "weight": 240},   # 명동 광석 2(전층 흔한 것)
		{"id": ItemCatalog.ORE_YUCHEOL, "count": 1, "gold": 0, "weight": 140},      # 유철 광석 1
		{"id": ItemCatalog.ORE_HWANGCHEONGEUM, "count": 1, "gold": 0, "weight": 55},# 황천금 광석 1
		{"id": ItemCatalog.HONTAN, "count": 1, "gold": 0, "weight": 130},           # 혼탄(제련 연료)
		{"id": "", "count": 0, "gold": PAN_GOLD, "weight": 250},                    # 사금 한 줌 = 냥
		{"id": ItemCatalog.GEM_NEOKSUJEONG, "count": 1, "gold": 0, "weight": 70},   # 넋수정
		{"id": ItemCatalog.GEM_MYEONGOK, "count": 1, "gold": 0, "weight": 35},      # 명옥
		{"id": ItemCatalog.GEM_YEOMJUSEOK, "count": 1, "gold": 0, "weight": 20},    # 염주석
		{"id": ItemCatalog.GEM_MYEONGBU_GEUMGANG, "count": 1, "gold": 0, "weight": 5},   # 명부금강(최희소)
		{"id": ItemCatalog.CRYSTALARIUM_PART, "count": 1, "gold": 0, "weight": 55}, # 결정기 부품
	]

# ── 질의 ────────────────────────────────────────────────────────────────────
func has_at(region: String, t: Vector2i) -> bool:
	return _spots.has(region) and _spots[region].has(t)

# 이 구역의 스폿 칸 목록(드로우·검증). 구역이 없으면 빈 배열.
func tiles(region: String) -> Array:
	return _spots[region].keys() if _spots.has(region) else []

func count(region: String) -> int:
	return int(_spots[region].size()) if _spots.has(region) else 0

# 전 구역 스폿 수(검증·디버그).
func total() -> int:
	var n := 0
	for region in _spots:
		n += int(_spots[region].size())
	return n

# ── 하루 경과(일일 재배치) — 취침 트리거 ─────────────────────────────────────
# 오늘의 사금 자리를 새로 깐다. **어제 것은 전량 지운다**(머리말 ★ — 쌓이지 않는다).
# 반환 = [{region, tile}] (main이 알림·검증에 쓴다).
#   · 결정적: day + 구역 시드 하나로 개수와 자리를 함께 뽑는다(CrabPotLedger.advance_day 동형).
#     같은 날 두 번 불러도 결과가 같다 — 취침이 두 번 굴러도 판이 안 흔들린다(로드 직후 방어).
#   · 구역은 정렬 순회라 Dictionary 키 순서에 반환 순서를 안 기댄다.
func advance_day(day: int) -> Array:
	var out: Array = []
	_spots = {}
	for region: String in spawn_regions():
		var pool: Array = candidates(region)
		if pool.is_empty():
			continue                                  # 존 없는 구역 방어(도달 불가)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("panning:%d:%s" % [day, region])
		var n := _roll_count(rng)
		for i in n:
			if pool.is_empty():
				break                                 # 후보보다 많이 뽑을 수는 없다(도달 불가)
			var idx := rng.randi_range(0, pool.size() - 1)
			var t: Vector2i = pool[idx]
			pool.remove_at(idx)                       # 뽑은 칸은 후보에서 뺀다(중복 자리 0)
			if not _spots.has(region):
				_spots[region] = {}
			_spots[region][t] = true
			out.append({"region": region, "tile": t})
	changed.emit()
	return out

# 그날 그 구역의 스폿 개수(COUNT_WEIGHTS 가중 추첨 — 0..SPOT_MAX).
static func _roll_count(rng: RandomNumberGenerator) -> int:
	var total_w := 0
	for w in COUNT_WEIGHTS:
		total_w += int(w)
	if total_w <= 0:
		return 0
	var roll := rng.randi_range(0, total_w - 1)
	var acc := 0
	for i in COUNT_WEIGHTS.size():
		acc += int(COUNT_WEIGHTS[i])
		if roll < acc:
			return mini(i, SPOT_MAX)
	return 0

# ── 채취([F]) ───────────────────────────────────────────────────────────────
# 이 칸을 일어 산출 한 건을 뽑는다. 스폿은 **소진된다**(하루 한 번씩 자리마다 — 무한 자판기 방지).
# 반환 = {"id","count","gold"}({} = 스폿 없음). 인벤 적재·지갑·혼력·알림은 전부 호출 측(main)이 한다.
#   · 산출 롤 = day + 구역 + 좌표 해시라 **스폿 자리마다 답이 이미 정해져 있다**. 세이브/로드로
#     되감아도 같은 것이 나오므로 재롤 exploit이 구조적으로 막힌다(지오드 개봉 카운터 시드와 같은 규율).
func pan(day: int, region: String, t: Vector2i) -> Dictionary:
	if not has_at(region, t):
		return {}
	_spots[region].erase(t)
	if _spots[region].is_empty():
		_spots.erase(region)         # 빈 구역 키는 남기지 않는다(세이브 군더더기 0 — CrabPotLedger 결)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("panning:yield:%d:%s:%d:%d" % [day, region, t.x, t.y])
	var row := _pick(yield_table(), rng)
	changed.emit()
	return row

# 가중 추첨(CrabPotLedger._pick 결 — 주입 RNG만 쓴다). 빈 표면 {}.
static func _pick(rows: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total_w := 0
	for e in rows:
		total_w += int(e["weight"])
	if total_w <= 0:
		return {}
	var roll := rng.randi_range(0, total_w - 1)
	var acc := 0
	for e in rows:
		acc += int(e["weight"])
		if roll < acc:
			return {"id": String(e["id"]), "count": int(e["count"]), "gold": int(e["gold"])}
	var last: Dictionary = rows[rows.size() - 1]     # 잔차 방어(도달 불가)
	return {"id": String(last["id"]), "count": int(last["count"]), "gold": int(last["gold"])}

# ── 세이브/로드(ForageSpawns 패턴 계승) — 슬라이스 키 "panning" 네임스페이스 ──
# 구역별 [x, y] 2항 배열 목록. 상태가 좌표뿐이라 이보다 얇을 수 없다.
# ★ 하위호환: 키 없는 구세이브 = 스폿 0(다음 취침의 advance_day가 그날 판을 깐다 — 무막힘).
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for region in _spots:
		var arr: Array = []
		for t: Vector2i in _spots[region]:
			arr.append([t.x, t.y])
		out[region] = arr
	return {"spots": out}

func load_save(data: Dictionary) -> void:
	_spots = {}
	var raw: Variant = data.get("spots", {})
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
				var t := Vector2i(int(e[0]), int(e[1]))
				if not in_zone(String(region), t):
					continue      # 존 밖 좌표는 조용히 버린다(구버전 존·손상 방어 — inventory._sanitize 결)
				by_tile[t] = true
			if not by_tile.is_empty():
				_spots[String(region)] = by_tile
	changed.emit()
