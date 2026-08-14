extends RefCounted
class_name CrystalariumLedger
# ★[S10-T1 / ADR-0069 결정 2] 결정기 — 보석 하나를 넣어 두면 며칠마다 같은 보석을 복제해 내는
# 설치 기계의 얇은 원장(ledger).
#
# 목적: ADR-0069 결정 2 뒷줄("보석 1종을 넣으면 일정 기간 후 같은 보석을 복제하고, 회수하면
#       반복한다")의 빌드 형태. 만렙 이후 갱도를 다시 파 내려갈 이유가 옅어진 자리에, **기다림이
#       곧 산출인 축**을 하나 세운다(업화로가 분 단위로 연 자리의 일 단위 판).
#
# 왜 별개 원장인가(FurnaceLedger·TapperLedger 동형 완전 분리):
#   - **RefCounted(비-Node)**: 설치물이되 순수 데이터라 씬 트리에 설 이유가 없다(업화로 결).
#   - 이 파일은 지형·인벤토리·지갑·혼력·전문직을 **하나도 모른다**. "여기 놓을 수 있나"는 main이
#     보고, 보석 차감·적재도 main이 한다.
#   - 상태 = 구역별 Vector2i 키 Dictionary. 구역 키가 필요한 이유는 업화로·통과 같다 — 안식 농원·
#     저승 숲·갱도 지상이 좌표 공간을 공유한다.
#
# ★ 업화로와 갈리는 축 셋:
#   ㉠ **진행 단위가 일(day)이다**(업화로는 분). 그래서 `advance_minutes`가 아니라 `advance_day`이고,
#      취침 훅에 나란히 붙는다(채취기·게잡이통과 같은 자리).
#   ㉡ **투입물이 소모되지 않는다**. 넣은 보석은 기계 안에 남고 복제본만 나온다 — 그래서 수거가
#      "다시 채우기"가 아니라 **재가동**이고, 한 번 넣으면 영구 산출이 된다(스타듀 Crystalarium 1:1).
#      이 축이 곧 "롱테일"의 정의다: 손이 아니라 시간이 버는 자리.
#   ㉢ **RNG가 한 줄도 없다**(업화로와 같은 결·통보다 강한 결정성). 헤드리스가 정확히 재현한다.
#
# 설계 메모(어기면 ADR-0069 결정 2 위반):
#   - ⚠️ **오색혼옥은 복제 불가**([ADR-0063] 초희귀 지위 보존 — 스타듀가 프리즘 조각을 결정기에서
#     배제한 것의 상속). `days_for`가 0을 돌려주고 `load_gem`이 거절하는 것이 그 규칙의 구조적
#     보증이다(복제 가능 목록을 따로 들지 않고 이 한 함수에서 갈린다 = 예외가 샐 틈 0).
#   - **혼력 0**: 설치·투입·수거·회수 어디에도 SoulEnergy가 없다(이 파일이 energy를 모르는 것 자체가
#     그 불변식의 구조적 보증 — FurnaceLedger·CrabPotLedger 주석과 같은 근거).
#   - **안 비운 결정기는 카운트다운이 멈춘다**(업화로·채취기 1:1). 수거가 곧 재가동이라 방치는
#     손실이 아니라 정지다(코지 — 벌칙 0).
#   - **복제본은 품질 무차원**이다. 광물은 원래 품질을 안 싣고(ItemCatalog.MINERALS 주석 "품질은
#     줍기와 릴 격투의 축"), 주괴만이 명시적 예외였다 — 그 예외를 여기로 넓히지 않는다.

signal changed()   # 설치·투입·완성·수거·회수·복원한 프레임(main이 듣고 드로우·프롬프트 갱신)

# 구역별 설치 원장. { region(String) → { Vector2i → {"gem","left"} } }
#   · gem  = 안에 든 보석 id("" = 빈 기계)
#   · left = 다음 복제까지 남은 일수(0 = 수거 대기 = 다 됐다)
var _units: Dictionary = {}

# ── 제작 규격(잠정 — ADR-0069 결정 1 "폴리시 이월"·owner 큐) ────────────────────
# 부품 3개 = 결정기 1대(ADR 결정 2 "잠정 3부품을 모으면 제작"). 실제 레시피 등록은 CraftCatalog가
# 들고(단일 출처), 여기 상수는 그 수치를 **읽는 쪽**(프롬프트·테스트)이 쓰는 참조다.
const PARTS_PER_UNIT := 3

# ── 복제 기간(게임 내 일 · 전부 *잠정* — owner 큐) ────────────────────────────
# ADR 결정 2가 이름 붙인 두 점은 그대로다: **하위 보석(넋수정) 2일 · 명옥 5일**. 나머지 둘(염주석·
# 명부금강)은 ADR이 값을 안 적었으므로 그 사다리를 위로 이어 붙였다 — 값이 비쌀수록 오래 걸려야
# 결정 2의 "경제 가드"(복제 시간이 채광 시세를 깨지 않는다)가 성립하기 때문이다.
#   넋수정 100냥/2일 = 50냥/일 · 명옥 200/5 = 40 · 염주석 250/6 ≈ 42 · 명부금강 750/8 ≈ 94
#   → 명부금강만 뚜렷이 우월한 것은 의도다(스타듀 다이아 결정기가 그 자리를 갖는 것과 같다).
#     그 대신 명부금강은 산출이 가장 희소해서(팬닝 0.5% · 31층+ 희귀 노드) 한 대를 세우는 것 자체가
#     사건이다 — 게이트는 시간이 아니라 **투입물의 희소성**이 진다.
# ⚠️ ADR이 값을 명시한 둘은 손대지 않았다. 넷을 다 잠그는 튜닝은 폴리시 루프 몫이다(owner 큐).
const DAYS_NEOKSUJEONG := 2          # 넋수정(석영 결 · 전층)
const DAYS_MYEONGOK := 5             # 명옥(21층+) — ADR 명시값
const DAYS_YEOMJUSEOK := 6           # 염주석(41층+)
const DAYS_MYEONGBU_GEUMGANG := 8    # 명부금강(다이아 대응 · 31층+ 희귀 노드)

# ── 복제 규칙(단일 출처) ─────────────────────────────────────────────────────
# 이 보석의 복제 일수(0 = **복제 불가**). ⚠️ 오색혼옥이 여기서 걸린다 — match에 없으므로 0으로
# 떨어지고, 그 0 하나가 곧 "초희귀는 복제하지 않는다"라는 ADR-0063 불변식의 코드 형태다.
# ★ const Dictionary 대신 match인 이유 = FurnaceLedger.ingot_for·CrabPotLedger.catch_table과 같다:
#   보석 id의 단일 출처가 ItemCatalog라 const 초기화식에서 타 클래스 상수를 참조하지 않는다.
static func days_for(gem_id: String) -> int:
	match gem_id:
		ItemCatalog.GEM_NEOKSUJEONG:
			return DAYS_NEOKSUJEONG
		ItemCatalog.GEM_MYEONGOK:
			return DAYS_MYEONGOK
		ItemCatalog.GEM_YEOMJUSEOK:
			return DAYS_YEOMJUSEOK
		ItemCatalog.GEM_MYEONGBU_GEUMGANG:
			return DAYS_MYEONGBU_GEUMGANG
	return 0

# 복제 가능한 보석인가(프롬프트·투입 게이트). 오색혼옥·비-보석 전부 false.
static func can_duplicate(gem_id: String) -> bool:
	return days_for(gem_id) > 0

# 복제 가능한 보석 목록(테스트·아트 로스터 대조 — 일수 오름 = 가치 오름 순).
static func duplicable_gems() -> Array[String]:
	return [ItemCatalog.GEM_NEOKSUJEONG, ItemCatalog.GEM_MYEONGOK,
		ItemCatalog.GEM_YEOMJUSEOK, ItemCatalog.GEM_MYEONGBU_GEUMGANG]

# ── 질의 ────────────────────────────────────────────────────────────────────
func has_at(region: String, t: Vector2i) -> bool:
	return _units.has(region) and _units[region].has(t)

# 이 구역의 설치 칸 목록(드로우·검증). 구역이 없으면 빈 배열.
func tiles(region: String) -> Array:
	return _units[region].keys() if _units.has(region) else []

# 전 구역 설치 수(검증·디버그).
func count() -> int:
	var n := 0
	for region in _units:
		n += int(_units[region].size())
	return n

# 안에 든 보석 id("" = 빈 기계 또는 없음).
func gem_at(region: String, t: Vector2i) -> String:
	return String(_units[region][t].get("gem", "")) if has_at(region, t) else ""

# 다음 복제까지 남은 일수(0 = 없음/수거 대기).
func days_left(region: String, t: Vector2i) -> int:
	return maxi(int(_units[region][t].get("left", 0)), 0) if has_at(region, t) else 0

# 복제 중인가(보석이 들었고 아직 안 됐다).
func is_growing(region: String, t: Vector2i) -> bool:
	return gem_at(region, t) != "" and days_left(region, t) > 0

# 수거 대기(복제본이 나와 있다)인가.
func is_ready(region: String, t: Vector2i) -> bool:
	return gem_at(region, t) != "" and days_left(region, t) <= 0

# 비어 있는가(보석을 받을 수 있다).
func is_idle(region: String, t: Vector2i) -> bool:
	return has_at(region, t) and gem_at(region, t) == ""

# ── 설치/회수 ────────────────────────────────────────────────────────────────
# 이 칸에 결정기를 놓는다. 이미 있으면 false(멱등 — 중복 설치 금지).
#   "여기 놓을 수 있나"는 main._can_place_crystalarium이 보고, 여긴 원장만 든다(설치물 공통 경계).
func place(region: String, t: Vector2i) -> bool:
	if has_at(region, t):
		return false
	if not _units.has(region):
		_units[region] = {}
	_units[region][t] = {"gem": "", "left": 0}
	changed.emit()
	return true

# 결정기를 걷는다(아이템 복귀는 호출 측). 반환 = {} 실패 / {"gem": 안에 들어 있던 보석 id("" = 없음)}.
# ★ **수거 대기면 거절**한다 — 걷는 걸로 다 된 복제본이 조용히 증발하면 손실이고, main의 [F] 사다리가
#   "수거 먼저"를 이미 강제한다(이중 안전 — 업화로·채취기 1:1).
# ★ 업화로와 **여기서 갈린다**: 업화로는 광석이 들면 걷기를 아예 막지만, 결정기는 투입물이 소모되지
#   않아 "다 걷을 때까지 못 빼는 보석"이 생긴다. 그래서 복제 중에도 걷되 **든 보석을 돌려준다**
#   (잃는 것은 진행뿐 — 물건은 하나도 안 사라진다. 코지 규율: 벌칙은 시간이지 재산이 아니다).
func remove(region: String, t: Vector2i) -> Dictionary:
	if not has_at(region, t) or is_ready(region, t):
		return {}
	var gem := gem_at(region, t)
	_units[region].erase(t)
	if _units[region].is_empty():
		_units.erase(region)              # 빈 구역 키는 남기지 않는다(세이브 군더더기 0)
	changed.emit()
	return {"gem": gem}

# ── 투입 ────────────────────────────────────────────────────────────────────
# 보석을 넣는다(아이템 1개 차감은 호출 측). 빈 기계 + 복제 가능한 보석일 때만 true.
# ⚠️ 오색혼옥은 여기서 막힌다(can_duplicate false) — 표를 따로 안 보고 days_for 하나로 갈린다.
func load_gem(region: String, t: Vector2i, gem_id: String) -> bool:
	if not is_idle(region, t):
		return false
	var days := days_for(gem_id)
	if days <= 0:
		return false
	_units[region][t] = {"gem": gem_id, "left": days}
	changed.emit()
	return true

# ── 수거 ────────────────────────────────────────────────────────────────────
# 다 된 복제본을 꺼낸다(인벤 적재는 호출 측). 보석 id 반환("" = 아직/없음).
# ★ 꺼내면 **같은 보석으로 즉시 재가동**한다(투입물이 남아 있으므로 — 머리말 ㉡). 이 한 줄이
#   "회수하면 반복한다"(ADR 결정 2)의 전부다.
func collect(region: String, t: Vector2i) -> String:
	if not is_ready(region, t):
		return ""
	var gem := gem_at(region, t)
	_units[region][t] = {"gem": gem, "left": days_for(gem)}
	changed.emit()
	return gem

# ── 하루 경과 — 취침 트리거 ──────────────────────────────────────────────────
# 복제 중인 기계마다 남은 일수를 하루 깎고, 0에 닿은 것들을 수거 대기로 넘긴다.
# 새로 다 된 목록을 반환한다([{region, tile, id}] — main이 알림에 쓴다).
#   · **완전 결정적**(RNG 0). 구역·좌표를 정렬해 순회한다(Dictionary 키 순서에 반환 순서를
#     기대지 않는다 = FurnaceLedger·CrabPotLedger와 같은 규율).
#   · 수거 대기(left 0)는 그냥 지나간다 — 안 비우면 카운트다운이 멈춘다(설계 메모 3항).
func advance_day() -> Array:
	var out: Array = []
	var regions: Array = _units.keys()
	regions.sort()
	for region in regions:
		var by_tile: Dictionary = _units[region]
		var tile_list: Array = by_tile.keys()
		tile_list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y if a.y != b.y else a.x < b.x)
		for t: Vector2i in tile_list:
			var e: Dictionary = by_tile[t]
			var left := int(e.get("left", 0))
			if String(e.get("gem", "")) == "" or left <= 0:
				continue                              # 빈 기계 · 안 비운 것(카운트다운 정지)
			left -= 1
			e["left"] = maxi(left, 0)
			by_tile[t] = e
			if left <= 0:
				out.append({"region": region, "tile": t, "id": String(e["gem"])})
	if not out.is_empty():
		changed.emit()
	return out

# ── 세이브/로드(FurnaceLedger 패턴 계승) — 슬라이스 키 "crystalarium" 네임스페이스 ──
# 구역별 [x, y, gem, left] 4항 배열 목록(업화로와 같은 결 — 중첩 dict보다 얇고, 항목이 늘어도
# 뒤에 붙이면 되는 형태).
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for region in _units:
		var arr: Array = []
		for t: Vector2i in _units[region]:
			var e: Dictionary = _units[region][t]
			arr.append([t.x, t.y, String(e.get("gem", "")), int(e.get("left", 0))])
		out[region] = arr
	return {"units": out}

func load_save(data: Dictionary) -> void:
	_units = {}
	var raw: Variant = data.get("units", {})   # 키 없는 구세이브 = 결정기 0(하위호환)
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
				var gem: String = String(e[2]) if e.size() >= 3 else ""
				# 손상·구버전 id 방어(업화로 load_save 결) — 복제 불가 보석이 들어 있으면 **빈 기계로**
				#   되돌린다. 기계 자체는 살린다(설치물이 사라지면 플레이어 손실이고, 비는 건 손실이 아니다).
				if gem != "" and not can_duplicate(gem):
					gem = ""
				var left: int = maxi(int(e[3]), 0) if e.size() >= 4 else 0
				if gem == "":
					left = 0
				else:
					left = mini(left, days_for(gem))   # 기간 상향 개정 시 유령 장기 대기 방지
				by_tile[Vector2i(int(e[0]), int(e[1]))] = {"gem": gem, "left": left}
			if not by_tile.is_empty():
				_units[String(region)] = by_tile
	changed.emit()
