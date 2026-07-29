extends RefCounted
class_name TapperLedger
# ★[S4-T6 / ADR-0062 결정 4] 수액 채취기 — 성숙 나무에 박아 두면 주기마다 수액이 고이는 얇은 원장.
#
# 목적: [ADR-0033] "수액 = 게잡이통식 패시브(혼력 0)"의 빌드 형태. ADR-0062 결정 4가 그 구현을
#       **`crab_pot.gd` 구조 1:1 복제**로 못 박았고(구역별 원장 · 혼력 0 · 결정 롤 · 미수거 시 생산
#       정지 · 퍼크 주입), **설치 판정만 "물가 인접" → "성숙 나무"** 로 갈린다. 즉 이 파일은
#       CrabPotLedger를 읽어 본 사람이면 그대로 읽히도록 일부러 같은 뼈대로 썼다.
#
# 게잡이통과 갈리는 세 지점(나머지는 전부 동형):
#   ① **미끼가 없다.** 통은 "미끼를 넣어야 논다"가 리추얼이지만, 채취기는 한 번 박으면 계속 돈다
#      — 대신 **주기가 길다**(5/7/9일). 통이 *매일 들르는* 리듬이라면 채취기는 *잊고 지내다 들르는*
#      리듬이다(같은 패시브라도 질감을 가른다 — ADR-0033 "이완형" 결).
#   ② **어획 테이블이 없다.** 무엇이 나오는지는 박은 나무의 종이 정한다(저승솔→솔넋진 5일 /
#      넋참나무→넋수지 7일 / 명단풍→명단풍꿀 9일 — 결정 3 명명과 1:1). 뽑기가 없으므로 **RNG가
#      한 줄도 없다** — 통보다 더 강한 결정성이다(day 시드조차 불요).
#   ③ **품질이 실린다.** 수액 3종은 품질 유차원 CAT_HARVEST고, 등급은 *생산 시점*의 채집 레벨 +
#      수액꾼 퍼크(TAP_QUALITY)로 스냅샷된다(줍기 품질과 같은 소스, ADR-0052).
#
# 설계 메모(어기면 ADR-0062 결정 4 위반):
#   - **혼력 0**: 설치·수거·회수 어디에도 SoulEnergy가 없다(이 파일이 energy를 모르는 것 자체가
#     그 불변식의 구조적 보증 — CrabPotLedger 주석과 같은 근거).
#   - **안 비운 채취기는 다음 수액을 안 받는다**(게잡이통 1:1). 수거가 곧 재가동이라, 방치는 손실이
#     아니라 정지다(코지 — 벌칙 0). 카운트다운도 그 동안 멈춘다(고인 채로 날짜만 흐르지 않는다).
#   - **원장은 지형·인벤·혼력·전문직을 모른다.** 설치 가능 판정(성숙 나무인가)은 main이 하고,
#     종·품질·주기 단축은 인자로 *주입*된다(TreeLedger·CrabPotLedger와 같은 디커플링 경계).
#   - 상태 = 구역별 Vector2i 키 Dictionary. 구역 키가 필요한 이유는 통과 같다 — 저승 숲(60×44)·
#     미혹의 숲(64×44)·안식 농원이 좌표 공간을 공유한다(안식 나무 16그루도 벌목·채취 대상, 결정 3).

signal changed()   # 설치·수거·회수·일일 진행·복원한 프레임(main이 듣고 드로우·프롬프트 갱신)

# 구역별 설치 원장. { region(String) → { Vector2i → {"species","days","product","quality"} } }
#   · species = 박은 나무의 종(TreeLedger.SP_*) — 산출물·주기의 유일한 결정자
#   · days    = 다음 수액까지 남은 날(1 이상). product가 차 있으면 이 값은 **얼지 않고 멈춘다**
#   · product = 수거 대기 아이템 id("" = 아직 고이는 중)
#   · quality = 그 산출물의 등급(생산 시점 스냅샷 — Q_NORMAL..Q_GOLD)
var _taps: Dictionary = {}

# ── 주기·산출(결정 3 명명과 1:1) ─────────────────────────────────────────────
# 스타듀 tapper 주기(단풍 9일 / 참나무 7일 / 소나무 5일)를 그대로 상속한다. 짧을수록 싼 수액이라
# 하루당 기대 수입은 세 종이 거의 같다(솔넋진 90/5 ≈ 넋수지 130/7 ≈ 명단풍꿀 170/9 ≈ 18엽전/일)
# — "어느 나무에 박아도 손해가 아니고, 대신 들르는 리듬이 다르다"가 되게 잡은 밴드다.
const CYCLE_PINE := 5
const CYCLE_OAK := 7
const CYCLE_MAPLE := 9
const MIN_CYCLE := 1          # 퍼크 단축이 주기를 0 이하로 끌지 않게 하는 바닥
# 수액 등급 상한 = 금([ADR-0052] 수액꾼 "일반→은→금"). 이리듐은 *줍기*의 약초학자 하한 전용이라
# 패시브 산출로는 닿지 않는다(패시브가 손 노동의 최고치를 넘지 않는다 — ADR-0008 결).
const MAX_QUALITY := ItemCatalog.Q_GOLD

# 종 → 채취 주기(일). cut = 수액꾼 퍼크 단축분(일). 모르는 종이면 참나무 주기(중앙값)로 방어.
# ★ const Dictionary 대신 match인 이유 = CrabPotLedger.catch_table()과 같다: 종 id의 단일 출처가
#   TreeLedger라 const 초기화식에서 타 클래스 상수를 참조하지 않는다(id가 어긋날 여지 0).
static func cycle_for(species: String, cut: int = 0) -> int:
	var base := CYCLE_OAK
	match species:
		TreeLedger.SP_PINE:
			base = CYCLE_PINE
		TreeLedger.SP_MAPLE:
			base = CYCLE_MAPLE
		TreeLedger.SP_OAK:
			base = CYCLE_OAK
	return maxi(base - maxi(cut, 0), MIN_CYCLE)

# 종 → 수액 아이템 id(""=모르는 종). ItemCatalog가 이름·가격의 단일 출처다.
static func product_for(species: String) -> String:
	match species:
		TreeLedger.SP_PINE:
			return ItemCatalog.SOLNEOKJIN
		TreeLedger.SP_MAPLE:
			return ItemCatalog.MYEONGDANPUNG_KKUL
		TreeLedger.SP_OAK:
			return ItemCatalog.NEOKSUJI
	return ""

# 생산 등급 = 채집 레벨 기본 등급 + 수액꾼 계단, 금에서 클램프(ForageSkill이 계단을 해석하고
# 상한은 소비처인 여기가 잠근다 — ForageSkill.TAP_QUALITY_STEP 주석의 "상한은 소비처가 클램프").
static func quality_for(base_quality: int, step: int) -> int:
	return clampi(base_quality + maxi(step, 0), ItemCatalog.Q_NORMAL, MAX_QUALITY)

# ── 질의 ────────────────────────────────────────────────────────────────────
# 이 구역·이 칸에 채취기가 있는가(드로우·프롬프트·벌목 차단 판정이 쓴다).
func has_at(region: String, t: Vector2i) -> bool:
	return _taps.has(region) and _taps[region].has(t)

# 이 구역의 설치 칸 목록(드로우·검증). 구역이 없으면 빈 배열.
func tiles(region: String) -> Array:
	return _taps[region].keys() if _taps.has(region) else []

# 전 구역 설치 수(검증·디버그).
func count() -> int:
	var n := 0
	for region in _taps:
		n += int(_taps[region].size())
	return n

# 박힌 나무의 종("" = 채취기 없음).
func species_at(region: String, t: Vector2i) -> String:
	return String(_taps[region][t].get("species", "")) if has_at(region, t) else ""

# 다음 수액까지 남은 날(0 = 채취기 없음 · 수거 대기 중이면 멈춘 값 그대로).
func days_left(region: String, t: Vector2i) -> int:
	return int(_taps[region][t].get("days", 0)) if has_at(region, t) else 0

# 수거 대기 산출물 id("" = 없음). 프롬프트·드로우 표식·수거 분기가 쓴다.
func pending_product(region: String, t: Vector2i) -> String:
	return String(_taps[region][t].get("product", "")) if has_at(region, t) else ""

# 수거 대기 산출물의 등급(대기 없으면 Q_NORMAL).
func pending_quality(region: String, t: Vector2i) -> int:
	return int(_taps[region][t].get("quality", ItemCatalog.Q_NORMAL)) if has_at(region, t) else ItemCatalog.Q_NORMAL

# ── 설치/회수 ────────────────────────────────────────────────────────────────
# 이 칸의 나무에 채취기를 박는다. 이미 있거나 종을 모르면 false(멱등 — 중복 설치 금지).
#   "성숙 나무인가"는 main._can_place_tapper가 보고, 여긴 원장만 든다(게잡이통 물가 판정과 같은 경계).
func place(region: String, t: Vector2i, species: String, cycle_cut: int = 0) -> bool:
	if has_at(region, t) or product_for(species) == "":
		return false
	if not _taps.has(region):
		_taps[region] = {}
	_taps[region][t] = {"species": species, "days": cycle_for(species, cycle_cut),
		"product": "", "quality": ItemCatalog.Q_NORMAL}
	changed.emit()
	return true

# 채취기를 뽑는다(아이템 복귀는 호출 측). **수거 대기 수액이 있으면 거절**한다 — 뽑는 걸로 산출물이
#   조용히 증발하면 손실이라, main의 F 체인이 "수거 먼저"를 강제하는 것과 이중 안전(게잡이통 1:1).
func remove(region: String, t: Vector2i) -> bool:
	if not has_at(region, t):
		return false
	if pending_product(region, t) != "":
		return false
	_taps[region].erase(t)
	if _taps[region].is_empty():
		_taps.erase(region)                # 빈 구역 키는 남기지 않는다(세이브 군더더기 0)
	changed.emit()
	return true

# ── 수거 ────────────────────────────────────────────────────────────────────
# 고인 수액을 꺼낸다(인벤 적재는 호출 측). {"id","quality"} 반환({} = 없음). 꺼내면 멈춰 있던
#   카운트다운이 다시 흐른다("안 비운 채취기는 안 고인다"의 짝 — 수거가 곧 재가동).
func collect(region: String, t: Vector2i) -> Dictionary:
	var id := pending_product(region, t)
	if id == "":
		return {}
	var q := pending_quality(region, t)
	_taps[region][t]["product"] = ""
	_taps[region][t]["quality"] = ItemCatalog.Q_NORMAL
	changed.emit()
	return {"id": id, "quality": q}

# ── 하루 경과 — 취침 트리거 ─────────────────────────────────────────────────
# 채취기마다 남은 날을 하루 줄이고, 0이 되면 그 종의 수액을 수거 대기에 얹는다. 새로 고인 목록을
# 반환한다([{region, tile, id, quality}] — main이 알림·토스트에 쓴다). 부수효과 = _taps 갱신.
#   · base_quality = 지금 채집 레벨의 기본 등급(ForageSkill.base_quality — main이 뽑아 주입)
#   · quality_step = 수액꾼(TAP_QUALITY) 계단 · cycle_cut = 수액꾼 주기 단축(일)
#   · **완전 결정적**: 뽑기가 없어 RNG를 아예 안 쓴다. 구역·좌표는 정렬해 순회한다(Dictionary 키
#     순서에 의존하면 반환 목록 순서가 흔들린다 = CrabPotLedger와 같은 규율).
func advance_day(base_quality: int = 0, quality_step: int = 0, cycle_cut: int = 0) -> Array:
	var out: Array = []
	var regions: Array = _taps.keys()
	regions.sort()
	for region in regions:
		var by_tile: Dictionary = _taps[region]
		var tile_list: Array = by_tile.keys()
		tile_list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y if a.y != b.y else a.x < b.x)
		for t: Vector2i in tile_list:
			var e: Dictionary = by_tile[t]
			if String(e.get("product", "")) != "":
				continue                                  # 안 비운 채취기 — 카운트다운도 멈춘다
			var species := String(e.get("species", ""))
			var id := product_for(species)
			if id == "":
				continue                                  # 손상 종 방어(도달 불가)
			var days := int(e.get("days", 0)) - 1
			if days > 0:
				e["days"] = days
				by_tile[t] = e
				continue                                  # 아직 고이는 중
			e["product"] = id
			e["quality"] = quality_for(base_quality, quality_step)
			e["days"] = cycle_for(species, cycle_cut)     # 다음 주기는 지금 퍼크로 다시 잰다
			by_tile[t] = e
			out.append({"region": region, "tile": t, "id": id, "quality": int(e["quality"])})
	if not out.is_empty():
		changed.emit()
	return out

# ── 세이브/로드(CrabPotLedger 패턴 계승) — 슬라이스 키 "tapper" 네임스페이스 ──
# 구역별 [x, y, species, days, product, quality] 6항 배열 목록으로 직렬화한다(중첩 dict보다 얇고,
# 항목이 늘어도 뒤에 붙이면 되는 형태 — 통과 같은 결).
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for region in _taps:
		var arr: Array = []
		for t: Vector2i in _taps[region]:
			var e: Dictionary = _taps[region][t]
			arr.append([t.x, t.y, String(e.get("species", "")), int(e.get("days", 1)),
				String(e.get("product", "")), int(e.get("quality", ItemCatalog.Q_NORMAL))])
		out[region] = arr
	return {"taps": out}

func load_save(data: Dictionary) -> void:
	_taps = {}
	var raw: Variant = data.get("taps", {})   # 키 없는 구세이브 = 설치 0(하위호환)
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
				if e.size() < 3:
					continue
				var species := String(e[2])
				if product_for(species) == "":
					continue          # 모르는 종 = 통째 버린다(산출물을 못 정하는 채취기는 무의미)
				var days: int = int(e[3]) if e.size() >= 4 else cycle_for(species)
				var got: String = String(e[4]) if e.size() >= 5 else ""
				if got != "" and not ItemCatalog.has_item(got):
					got = ""          # 손상·구버전 id는 조용히 버린다(inventory._sanitize 결)
				var q: int = int(e[5]) if e.size() >= 6 else ItemCatalog.Q_NORMAL
				by_tile[Vector2i(int(e[0]), int(e[1]))] = {"species": species,
					"days": maxi(days, MIN_CYCLE), "product": got,
					"quality": clampi(q, ItemCatalog.Q_NORMAL, MAX_QUALITY)}
			if not by_tile.is_empty():
				_taps[String(region)] = by_tile
	changed.emit()
