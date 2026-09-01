extends RefCounted
class_name FurnaceLedger
# ★[S5-T3 / ADR-0063 결정 3] 업화로 — 광석을 넣고 **게임 내 분**을 기다리면 주괴가 되는 얇은 원장.
#
# 목적: ADR-0052 제련공 퍼크가 전제하는 제련 메카닉이 어느 문서에도 없던 공백(ADR-0063 결정 3이
#       "착수 리서치가 확인한 진짜 공백"으로 기록)의 빌드 형태. 광석 5 + 혼탄 1 → 주괴 1이고,
#       기다리는 시간이 금속 티어를 가른다(명동 30분 / 유철 2시간 / 황천금 5시간 / 나락철 8시간 —
#       스타듀 1:1).
#
# 왜 별개 원장인가(CrabPotLedger·TapperLedger 동형 완전 분리):
#   - **RefCounted(비-Node)**: 설치물이 아니라 순수 데이터라 씬 트리에 설 이유가 없다.
#   - 이 파일은 지형·인벤토리·지갑·혼력·전문직을 **하나도 모른다**. "여기 놓을 수 있나"는 main이
#     보고, 재료 차감·적재도 main이 하고, 제련공 퍼크(시간 −50%·품질 티어)는 인자로 *주입*된다.
#
# ★ 채취기·게잡이통과 갈리는 **단 하나의 축**: 이건 `advance_day`가 없다 — **분 단위**다.
#   ㉠ 진행의 주인이 취침(하루)이 아니라 시계다. main이 매 프레임 흐른 게임 분을 흘려 넣는다
#      (`advance_minutes`). 그래서 "낮에 넣고 30분 뒤에 와서 꺼낸다"가 성립한다.
#   ㉡ **밤에도 제련은 돈다**(스타듀 정합). 취침 = 다음 날 아침으로의 시간 점프니, main이 그
#      점프 폭(현재 시각→24:00→06:00)을 그대로 분으로 흘려 넣으면 여기선 특별 분기가 없다.
#      그 계산은 main의 절대 분(day·minutes 합성) 델타 하나로 자동 처리된다 — 이 파일엔 day가 없다.
#   ㉢ 그래서 **RNG가 한 줄도 없다**(채취기와 같은 결·통보다 강한 결정성). 헤드리스가 정확히 재현한다.
#
# 설계 메모(어기면 ADR-0063 결정 3 위반):
#   - **혼력 0**: 투입·수거·회수 어디에도 SoulEnergy가 없다(이 파일이 energy를 모르는 것 자체가 그
#     불변식의 구조적 보증 — CrabPotLedger·TapperLedger 주석과 같은 근거).
#   - **안 비운 업화로는 다음 광석을 안 받는다**(채취기 1:1). 수거가 곧 재가동이라 방치는 손실이
#     아니라 정지다(코지 — 벌칙 0).
#   - **주괴는 품질을 싣는다**(ItemCatalog.INGOTS의 명시적 예외). 등급은 *투입 시점*의 제련공 계단으로
#     스냅샷된다(수액 등급이 생산 시점 스냅샷인 것과 같은 결).
#   - 상태 = 구역별 Vector2i 키 Dictionary. 구역 키가 필요한 이유는 통·채취기와 같다 — 안식 농원·
#     저승 숲·갱도 지상이 좌표 공간을 공유한다.

signal changed()   # 설치·투입·완성·수거·회수·복원한 프레임(main이 듣고 드로우·프롬프트 갱신)

# 구역별 설치 원장. { region(String) → { Vector2i → {"ore","product","left","quality"} } }
#   · ore     = 넣은 광석 id("" = 빈 화덕)
#   · product = 나올(또는 나온) 주괴 id("" = 빈 화덕)
#   · left    = 남은 제련 분(0 이하 = 완성 = 수거 대기)
#   · quality = 그 주괴의 등급(투입 시점 스냅샷 — Q_NORMAL..Q_GOLD)
var _forges: Dictionary = {}

# ── 투입 규격(스타듀 1:1 — ADR-0063 결정 3) ───────────────────────────────────
const ORE_PER_BATCH := 5      # 광석 5개
const FUEL_PER_BATCH := 1     # 혼탄 1개
const FUEL_ITEM := ItemCatalog.HONTAN

# ── 제련 시간(게임 내 분 · 스타듀 1:1) ────────────────────────────────────────
const MIN_MYEONGDONG := 30        # 30분
const MIN_YUCHEOL := 120          # 2시간
const MIN_HWANGCHEONGEUM := 300   # 5시간
const MIN_NARAKCHEOL := 480       # 8시간
const MIN_FLOOR := 1              # 퍼크 단축이 0분(즉발)으로 떨어지지 않게 하는 바닥

# 주괴 등급 상한 = 금. 근거는 수액(TapperLedger.MAX_QUALITY)과 같다 — 이리듐은 *손 노동*의 최고치
# (약초학자 하한·퍼펙트 릴 2회)에 예약된 자리이고, 기다리면 나오는 가공품이 그걸 넘지 않는다.
const MAX_QUALITY := ItemCatalog.Q_GOLD

# ── 광석 → 주괴(제련 매핑의 단일 출처) ───────────────────────────────────────
# ★ const Dictionary 대신 match인 이유 = TapperLedger.product_for·CrabPotLedger.catch_table과 같다:
#   광석 id의 단일 출처가 ItemCatalog라 const 초기화식에서 타 클래스 상수를 참조하지 않는다.
# ★ 나락철도 여기 있다 — 광석의 *출현*은 S5-T7(나락) 소관이지만 제련 규칙은 금속 4티어 전량이
#   지금 완결돼야 도구 4티어(ToolTier)가 재료 사슬을 다 갖춘다.
static func ingot_for(ore_id: String) -> String:
	match ore_id:
		ItemCatalog.ORE_MYEONGDONG:
			return ItemCatalog.INGOT_MYEONGDONG
		ItemCatalog.ORE_YUCHEOL:
			return ItemCatalog.INGOT_YUCHEOL
		ItemCatalog.ORE_HWANGCHEONGEUM:
			return ItemCatalog.INGOT_HWANGCHEONGEUM
		ItemCatalog.ORE_NARAKCHEOL:
			return ItemCatalog.INGOT_NARAKCHEOL
	return ""

# 제련 가능한 광석인가(프롬프트·투입 게이트).
static func is_smeltable(ore_id: String) -> bool:
	return ingot_for(ore_id) != ""

# 제련 가능한 광석 목록(테스트·아트 로스터 대조 — ItemCatalog 순서 = 티어 순서).
static func smeltable_ores() -> Array[String]:
	return [ItemCatalog.ORE_MYEONGDONG, ItemCatalog.ORE_YUCHEOL,
		ItemCatalog.ORE_HWANGCHEONGEUM, ItemCatalog.ORE_NARAKCHEOL]

# 이 광석의 제련 분. time_cut = 제련공 퍼크 단축 비율(0.0~1.0 — 0.5 = −50%).
# ★ 퍼크 값 인코딩은 S5-T8 소관이라 지금 호출부는 항상 0.0을 넘긴다(인자 자리만 열어 둔다).
static func smelt_minutes(ore_id: String, time_cut: float = 0.0) -> int:
	var base := 0
	match ore_id:
		ItemCatalog.ORE_MYEONGDONG:
			base = MIN_MYEONGDONG
		ItemCatalog.ORE_YUCHEOL:
			base = MIN_YUCHEOL
		ItemCatalog.ORE_HWANGCHEONGEUM:
			base = MIN_HWANGCHEONGEUM
		ItemCatalog.ORE_NARAKCHEOL:
			base = MIN_NARAKCHEOL
		_:
			return 0
	var cut := clampf(time_cut, 0.0, 0.9)
	return maxi(int(round(float(base) * (1.0 - cut))), MIN_FLOOR)

# 투입 시점 등급 = 제련공 "잉곳 품질 티어" 계단, 금에서 클램프(TapperLedger.quality_for 대칭).
static func quality_for(step: int) -> int:
	return clampi(ItemCatalog.Q_NORMAL + maxi(step, 0), ItemCatalog.Q_NORMAL, MAX_QUALITY)

# ── 질의 ────────────────────────────────────────────────────────────────────
func has_at(region: String, t: Vector2i) -> bool:
	return _forges.has(region) and _forges[region].has(t)

# 이 구역의 설치 칸 목록(드로우·검증). 구역이 없으면 빈 배열.
func tiles(region: String) -> Array:
	return _forges[region].keys() if _forges.has(region) else []

# 전 구역 설치 수(검증·디버그).
func count() -> int:
	var n := 0
	for region in _forges:
		n += int(_forges[region].size())
	return n

# 넣어 둔 광석 id("" = 빈 화덕 또는 없음).
func ore_at(region: String, t: Vector2i) -> String:
	return String(_forges[region][t].get("ore", "")) if has_at(region, t) else ""

# 나올(또는 나온) 주괴 id("" = 빈 화덕 또는 없음).
func product_at(region: String, t: Vector2i) -> String:
	return String(_forges[region][t].get("product", "")) if has_at(region, t) else ""

# 남은 제련 분(0 = 없음/완성). 프롬프트가 "n분 남음"으로 보인다.
func minutes_left(region: String, t: Vector2i) -> int:
	return maxi(int(_forges[region][t].get("left", 0)), 0) if has_at(region, t) else 0

# 제련 중인가(광석이 들었고 아직 안 익었다).
func is_smelting(region: String, t: Vector2i) -> bool:
	return product_at(region, t) != "" and minutes_left(region, t) > 0

# 수거 대기(다 익었다)인가.
func is_ready(region: String, t: Vector2i) -> bool:
	return product_at(region, t) != "" and minutes_left(region, t) <= 0

# 비어 있는가(광석을 받을 수 있다).
func is_idle(region: String, t: Vector2i) -> bool:
	return has_at(region, t) and product_at(region, t) == ""

# 수거 대기 주괴의 등급(대기 없으면 Q_NORMAL).
func pending_quality(region: String, t: Vector2i) -> int:
	return int(_forges[region][t].get("quality", ItemCatalog.Q_NORMAL)) if has_at(region, t) else ItemCatalog.Q_NORMAL

# ── 설치/회수 ────────────────────────────────────────────────────────────────
# 이 칸에 업화로를 놓는다. 이미 있으면 false(멱등 — 중복 설치 금지).
#   "여기 놓을 수 있나"는 main._can_place_furnace가 보고, 여긴 원장만 든다(설치물 공통 경계).
func place(region: String, t: Vector2i) -> bool:
	if has_at(region, t):
		return false
	if not _forges.has(region):
		_forges[region] = {}
	_forges[region][t] = {"ore": "", "product": "", "left": 0, "quality": ItemCatalog.Q_NORMAL}
	changed.emit()
	return true

# 업화로를 걷는다(아이템 복귀는 호출 측). **광석이 들어 있으면 거절**한다 — 걷는 걸로 광석 5개가
#   조용히 증발하면 손실이라, main의 F 체인이 "수거 먼저"를 강제하는 것과 이중 안전(채취기 1:1).
func remove(region: String, t: Vector2i) -> bool:
	if not has_at(region, t) or not is_idle(region, t):
		return false
	_forges[region].erase(t)
	if _forges[region].is_empty():
		_forges.erase(region)              # 빈 구역 키는 남기지 않는다(세이브 군더더기 0)
	changed.emit()
	return true

# ★[폴리시 R5] 강제 회수 — **무대가 그 칸을 삼킬 때**만 쓰는 진입점이다(늘봄방 완공이 예정지를
#   벽으로 덮는 자리). `remove`가 달구는 중·수거 대기 화덕을 거절하는 것은 옳다("먼저 꺼내라") —
#   그러나 그 칸이 곧 사라지는 상황에선 그 거절이 곧 영구 매장이라, 안에 든 것을 **돌려주면서**
#   걷는 길을 따로 연다(Crystalarium.remove가 보석을 함께 돌려주는 계약과 같은 결).
#   반환: {} = 없는 칸 / {"ore": 넣은 광석 id, "product": 다 익은 주괴 id(""=미완), "quality": 등급}.
#   ★ 무엇을 돌려줄지는 호출 측이 정한다 — 이 원장은 인벤토리를 모른다(머리말 경계 불변).
func evict(region: String, t: Vector2i) -> Dictionary:
	if not has_at(region, t):
		return {}
	var out := {"ore": ore_at(region, t),
		"product": product_at(region, t) if is_ready(region, t) else "",
		"quality": pending_quality(region, t)}
	_forges[region].erase(t)
	if _forges[region].is_empty():
		_forges.erase(region)
	changed.emit()
	return out

# ── 투입 ────────────────────────────────────────────────────────────────────
# 광석을 넣는다(재료 차감은 호출 측). 빈 화덕 + 제련 가능한 광석일 때만 true.
#   · time_cut     = 제련공 퍼크 시간 단축 비율(0.0~0.9 — S5-T8까지 0.0)
#   · quality_step = 제련공 "잉곳 품질 티어" 계단(S5-T8까지 0)
func load_ore(region: String, t: Vector2i, ore_id: String, time_cut: float = 0.0,
		quality_step: int = 0) -> bool:
	if not is_idle(region, t):
		return false
	var ingot := ingot_for(ore_id)
	if ingot == "":
		return false
	_forges[region][t] = {"ore": ore_id, "product": ingot,
		"left": smelt_minutes(ore_id, time_cut), "quality": quality_for(quality_step)}
	changed.emit()
	return true

# ── 수거 ────────────────────────────────────────────────────────────────────
# 다 익은 주괴를 꺼낸다(인벤 적재는 호출 측). {"id","quality"} 반환({} = 아직/없음).
# 꺼내면 화덕이 다시 빈다("안 비운 업화로는 안 받는다"의 짝 — 수거가 곧 재가동).
func collect(region: String, t: Vector2i) -> Dictionary:
	if not is_ready(region, t):
		return {}
	var id := product_at(region, t)
	var q := pending_quality(region, t)
	_forges[region][t] = {"ore": "", "product": "", "left": 0, "quality": ItemCatalog.Q_NORMAL}
	changed.emit()
	return {"id": id, "quality": q}

# ── 시간 경과 — 시계 분 진행 트리거(★이 원장의 축) ──────────────────────────
# 흐른 게임 분만큼 전 업화로의 남은 분을 깎고, 0에 닿은 것들을 수거 대기로 넘긴다.
# 새로 익은 목록을 반환한다([{region, tile, id, quality}] — main이 알림에 쓴다).
#   · **완전 결정적**(RNG 0). 구역·좌표를 정렬해 순회한다(Dictionary 키 순서에 반환 순서를
#     기대지 않는다 = CrabPotLedger·TapperLedger와 같은 규율).
#   · 취침 점프도 그냥 큰 minutes 하나다 — 밤에도 제련이 돈다(스타듀 정합·머리말 ㉡).
#   · minutes <= 0이면 무동작(정지·역행 방어).
func advance_minutes(minutes: float) -> Array:
	var out: Array = []
	if minutes <= 0.0:
		return out
	var step := int(floor(minutes))
	if step <= 0:
		return out
	var regions: Array = _forges.keys()
	regions.sort()
	for region in regions:
		var by_tile: Dictionary = _forges[region]
		var tile_list: Array = by_tile.keys()
		tile_list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y if a.y != b.y else a.x < b.x)
		for t: Vector2i in tile_list:
			var e: Dictionary = by_tile[t]
			var left := int(e.get("left", 0))
			if String(e.get("product", "")) == "" or left <= 0:
				continue                              # 빈 화덕 · 이미 익어 안 비운 것(카운트다운 정지)
			left -= step
			e["left"] = maxi(left, 0)
			by_tile[t] = e
			if left <= 0:
				out.append({"region": region, "tile": t, "id": String(e["product"]),
					"quality": int(e.get("quality", ItemCatalog.Q_NORMAL))})
	if not out.is_empty():
		changed.emit()
	return out

# ── 세이브/로드(TapperLedger 패턴 계승) — 슬라이스 키 "furnace" 네임스페이스 ──
# 구역별 [x, y, ore, product, left, quality] 6항 배열 목록으로 직렬화한다(통·채취기와 같은 결 —
# 중첩 dict보다 얇고, 항목이 늘어도 뒤에 붙이면 되는 형태).
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for region in _forges:
		var arr: Array = []
		for t: Vector2i in _forges[region]:
			var e: Dictionary = _forges[region][t]
			arr.append([t.x, t.y, String(e.get("ore", "")), String(e.get("product", "")),
				int(e.get("left", 0)), int(e.get("quality", ItemCatalog.Q_NORMAL))])
		out[region] = arr
	return {"forges": out}

func load_save(data: Dictionary) -> void:
	_forges = {}
	var raw: Variant = data.get("forges", {})   # 키 없는 구세이브 = 설치 0(하위호환)
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
				var ore: String = String(e[2]) if e.size() >= 3 else ""
				var got: String = String(e[3]) if e.size() >= 4 else ""
				# 손상·구버전 id 방어(inventory._sanitize 결) — 짝이 안 맞으면 **빈 화덕으로 되돌린다**.
				#   화덕 자체는 살린다(설치물이 사라지면 플레이어 손실이고, 비는 건 손실이 아니다).
				if got != "" and not ItemCatalog._is_ingot(got):
					ore = ""
					got = ""
				if ore != "" and ingot_for(ore) != got:
					ore = ""
					got = ""
				var left: int = maxi(int(e[4]), 0) if e.size() >= 5 else 0
				var q: int = int(e[5]) if e.size() >= 6 else ItemCatalog.Q_NORMAL
				if got == "":
					left = 0
				by_tile[Vector2i(int(e[0]), int(e[1]))] = {"ore": ore, "product": got,
					"left": left, "quality": clampi(q, ItemCatalog.Q_NORMAL, MAX_QUALITY)}
			if not by_tile.is_empty():
				_forges[String(region)] = by_tile
	changed.emit()
