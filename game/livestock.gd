extends Node
class_name Ranch
# S1-7 — 혼의 짐승 목축 데일리 돌봄 루프. FarmField(작물)·Orchard(나무)와 완전 분리된 자체 좌표계 엔티티.
#
# 목적: ROADMAP S1-7 — 짐승을 하늘 목장에 두고 매일 급여·쓰다듬·방목·야간 격리·청결로 돌보면
#       우정·기분이 오르내리고, 그에 따라 산물(품질·대형)이 나오는 데일리 루프가 굴러가고 세이브로
#       복원되는지를 헤드리스로 검증한다. 설계·수치 = greybox-spec §4.1 · §8(S1-7 착수).
#
# 왜 별개 노드인가(§8.1 = Orchard와 동형 (A) 완전 분리):
#   - 짐승은 밭 칸의 crop도, 3×3 나무도 아니다 — "매일 돌봄으로 우정·기분이 오르고 산물을 내는"
#     데일리 엔티티다(작물=며칠·나무=절기 vs 짐승=매일). FarmField/Orchard의 상태 모델과 안 맞아
#     한 줄도 안 건드린다(회귀-0 계약 계승). main이 배치·돌봄·수집·드로우·세이브를 배선한다(디커플링).
#
# 설계 메모(§8.5):
#   - 짐승 1마리 = 타일 키(Vector2i, 정적 위치) → 상태 Dict. 상태는 순수 {String/int/bool}라 그대로
#     직렬화된다(FarmField/Orchard와 같은 결 — inner class 안 씀). 짐승은 통과 가능(비-SOLID)이라
#     Orchard 같은 밑동 충돌 재구성이 없다(더 단순).
#   - 데일리 케어 플래그(fed/petted/grazed/penned/cleaned)는 낮 동안 플레이어 액션이 세우고,
#     advance_day(취침)가 그 플래그로 우정·기분을 정산 → 산물 생성 → 플래그 리셋한다(하루 리듬).
#   - 품질은 §3.1 확률표 엔진(FertilizerCatalog)을 재활용한다 — 우정 하트로 확률표 행(state)을 스왑.
#     대형 산물은 별 축(P_large = 하트 비례). 둘 다 순수 파생 함수로 빼 헤드리스에서 결정적 검증.
#   - ⚠️ 비살상 불변식(§4.1 하드 바운더리): 어떤 방치(미급여·야간 노출·오물)도 짐승을 제거·소멸시키지
#     않는다. advance_day는 절대 _animals에서 키를 지우지 않는다 — 페널티는 우정·기분 감산으로만.

signal changed()   # 짐승이 추가되거나 돌봄·산물·수집·복원된 프레임(main이 듣고 화면·HUD 갱신)

# ── 우정·기분 규격(§4.1) ─────────────────────────────────────────────────────
const FRIEND_MAX := 1000          # 우정 상한(200/하트 → 0~5하트)
const FRIEND_PER_HEART := 200
const MOOD_MAX := 255             # 기분 상한(매일 가산·감산, 캐리)
const MOOD_START := 128           # 새 짐승 초기 기분(중립 — 돌보면 오르고 방치하면 내림)

# 우정 가산/감산(§4.1) — advance_day 정산 시 하루치 델타.
const F_PET := 15                 # 쓰다듬기
const F_FEED := 5                 # 급여
const F_GRAZE := 8                # 주간 방목
const F_PEN := 5                  # 야간 격리
const F_NO_FEED := -20            # 미급여
const F_NEGLECT := -2             # 방치 자연감소(쓰다듬 안 함)

# 기분 가산/감산(§4.1) — advance_day 정산 시 하루치 델타(캐리에 누적, clamp 0..255).
const M_FEED := 40
const M_PET := 30
const M_PEN := 40
const M_GRAZE := 30
const M_CLEAN := 20
const M_NO_FEED := -60
const M_NIGHT_EXPOSED := -40      # 야간 실외 노출(격리 실패)
const M_MUCK := -30               # 오물 방치(청소 안 함)

const DELUXE_MOOD_GATE := 200     # DELUXE 산물 = 5하트 + 당일 기분 ≥200(§4.1)

# ── B1-a.2 pathing(실내↔방목 왕래) 위치 상태 ─────────────────────────────────
# 짐승은 실내(건물 방)에 거주하고, 문이 열린 낮엔 방목지로 나가 풀을 뜯다가(F_GRAZE) 밤에 자동
# 귀가한다(F_PEN). 문을 닫아 두면 실내에 머문다(=야간 안전 격리, penned). 나간 뒤 귀가 전 문을
# 닫으면 실외 고립(비살상 — 짐승 유지, penned 미설정 → advance_day가 M_NIGHT_EXPOSED, §4.1 엣지①).
const LOC_INDOOR := "indoor"      # 실내 거주(기본) — 소속 건물 방 안
const LOC_PASTURE := "pasture"    # 방목 중 — 문 아래 고지 방목지(pasture_tile 좌표)

# 방목 문 상태. 키 = 건물 id, 값 = bool(열림). 키 없음/false = 닫힘(기본 — 스타듀 헛간 문 결).
# 세이브 왕복(to_save/load_save)으로 보존한다(문 열어 둔 채 자면 다음 아침도 열림).
var _doors: Dictionary = {}

# 짐승 상태. 키 = 타일(Vector2i, 정적 실내 위치 = 소속 건물 방 바닥), 값 = 아래 필드 Dict.
# 키 없음 = 그 자리에 짐승 없음. 키 타일은 "집(실내)" 앵커이고, 방목 나가면 pasture_tile에 그려진다.
#   species    : 종 id(AnimalCatalog)
#   home_building : 소속 건물 id(넋둥우리/넋우릿간 — B1-a "진입 실내"). "" = 미소속(구버전 세이브 방어).
#   location   : 현재 위치(LOC_INDOOR/LOC_PASTURE — B1-a.2 pathing). 없음 = 실내(구버전 방어).
#   pasture_tile : 방목 나갔을 때 서 있는 방목지 타일(main이 배정). 실내면 무의미(키 타일과 동일 default).
#   friendship : 우정 pts(0..1000)
#   mood       : 기분(0..255, 캐리)
#   fed/petted/grazed/penned/cleaned : 오늘의 데일리 케어 플래그(advance_day가 정산 후 리셋).
#     ★ B1-a.2: grazed=아침 방출 시·penned=밤 귀가/실내잔류 시 자동으로 선다(수동 tend 아님). cleaned만 수동.
#   product    : 대기 중인 미수집 산물 수(0/1 — 한 번에 1개, 수집 전엔 새로 안 뱀)
#   product_quality : 대기 산물 품질 등급(0..3)
#   product_large   : 대기 산물이 대형인가
var _animals: Dictionary = {}

# ── 배치·조회 ────────────────────────────────────────────────────────────────
# 타일에 짐승을 추가한다(유효 종 + 빈 타일). 초기 우정 0·기분 중립·케어 플래그 전부 false·산물 0.
# home_building = 소속 건물 id(넋둥우리/넋우릿간). B1-a "진입 실내" — 짐승은 실내에 거주하고 돌봄도
# 실내에서 이뤄진다(방목 왕래 pathing은 B1-a.2). 미지정("")도 허용(단위 테스트·구버전 방어).
func add_animal(tile: Vector2i, species: String, home_building: String = "") -> bool:
	if not AnimalCatalog.has(species) or _animals.has(tile):
		return false
	_animals[tile] = {
		"species": species,
		"home_building": home_building,
		"location": LOC_INDOOR,      # ★ B1-a.2 — 새 짐승은 실내 거주로 시작(문 열고 아침 방출돼야 방목).
		"pasture_tile": tile,        # 방목 배정 전 default = 키 타일(실내 앵커). main이 방출 시 실좌표로 덮는다.
		"friendship": 0,
		"mood": MOOD_START,
		"fed": false, "petted": false, "grazed": false, "penned": false, "cleaned": false,
		"product": 0, "product_quality": 0, "product_large": false,
	}
	changed.emit()
	return true

func has_animal(tile: Vector2i) -> bool:
	return _animals.has(tile)

func species_at(tile: Vector2i) -> String:
	return str(_animals[tile]["species"]) if _animals.has(tile) else ""

# 짐승의 소속 건물 id("" = 미소속). B1-a 건물별 돌봄·방목 왕래(B1-a.2)의 앵커.
func building_of(tile: Vector2i) -> String:
	return str(_animals[tile].get("home_building", "")) if _animals.has(tile) else ""

# 특정 건물 소속 짐승 타일 목록(건물별 돌봄·드로우·pathing이 순회).
func animals_in(building: String) -> Array:
	var out: Array = []
	for tile in _animals.keys():
		if str(_animals[tile].get("home_building", "")) == building:
			out.append(tile)
	return out

# 짐승이 있는 타일 목록(main의 _draw_ranch·프롬프트가 순회). 순수 상태 질의(화면은 main이 앎).
func animal_tiles() -> Array:
	return _animals.keys()

func count() -> int:
	return _animals.size()

func friendship_of(tile: Vector2i) -> int:
	return int(_animals[tile]["friendship"]) if _animals.has(tile) else 0

func mood_of(tile: Vector2i) -> int:
	return int(_animals[tile]["mood"]) if _animals.has(tile) else 0

# 우정 하트(0..5) = 우정 pts / 200(내림). 품질 state·P_large의 입력.
func hearts_of(tile: Vector2i) -> int:
	return friendship_of(tile) / FRIEND_PER_HEART

func is_fed(tile: Vector2i) -> bool:
	return _animals.has(tile) and bool(_animals[tile]["fed"])

func is_petted(tile: Vector2i) -> bool:
	return _animals.has(tile) and bool(_animals[tile]["petted"])

# 대기 중인 미수집 산물이 있는가(수집 프롬프트·드로우가 쓴다).
func has_product(tile: Vector2i) -> bool:
	return _animals.has(tile) and int(_animals[tile]["product"]) > 0

# ── B1-a.2 방목 문(건물별 토글) ────────────────────────────────────────────────
# 방목 문 = 그 건물 짐승을 낮에 방목지로 내보낼지 여부(스타듀 헛간 문). 기본 닫힘(false).
# 플레이어가 실내에서 여닫고(main), 세이브로 보존된다. 짐승 출입 pathing의 게이트.
func door_open(building: String) -> bool:
	return bool(_doors.get(building, false))

func set_door(building: String, open: bool) -> void:
	if building == "":
		return
	_doors[building] = open
	changed.emit()

# 방목 문을 뒤집고 새 상태(열림=true)를 반환한다. main의 실내 F 토글이 쓴다.
func toggle_door(building: String) -> bool:
	set_door(building, not door_open(building))
	return door_open(building)

# ── B1-a.2 위치(실내/방목) 조회 ─────────────────────────────────────────────────
func location_of(tile: Vector2i) -> String:
	return str(_animals[tile].get("location", LOC_INDOOR)) if _animals.has(tile) else LOC_INDOOR

# 방목지에 나가 있는가(main의 _draw_ranch가 실내 앵커 대신 방목 타일에 그릴지 판정).
func is_outside(tile: Vector2i) -> bool:
	return location_of(tile) == LOC_PASTURE

# 방목 나갔을 때 서 있는 타일(실내면 키 타일과 동일). main이 방목지에 그린다.
func pasture_tile_of(tile: Vector2i) -> Vector2i:
	return _animals[tile].get("pasture_tile", tile) if _animals.has(tile) else tile

# ── B1-a.2 방목 방출/귀가 ────────────────────────────────────────────────────
# 지금 방목지로 내보낼 수 있는 짐승 타일(실내 거주 + 소속 건물 문 열림). main이 방목 목적지를
# 배정해 send_to_pasture로 실제 이동시킨다(지형 좌표는 main이 앎 — 디커플링). 평온·낮 게이트는 main.
func releasable() -> Array:
	var out: Array = []
	for tile in _animals.keys():
		var a: Dictionary = _animals[tile]
		if str(a.get("location", LOC_INDOOR)) == LOC_INDOOR and door_open(str(a.get("home_building", ""))):
			out.append(tile)
	return out

# 짐승을 방목지 dest 타일로 내보낸다(아침 방출·문 여는 즉시 방출). 방목=F_GRAZE라 grazed 플래그를 세운다.
func send_to_pasture(tile: Vector2i, dest: Vector2i) -> bool:
	if not _animals.has(tile):
		return false
	var a: Dictionary = _animals[tile]
	a["location"] = LOC_PASTURE
	a["pasture_tile"] = dest
	if not bool(a["grazed"]):
		a["grazed"] = true
	changed.emit()
	return true

# 밤 pathing 정산(취침 → advance_day 직전에 호출). 각 짐승:
#   · 방목 중 + 문 열림 → 자동 귀가(실내 복귀 + penned=격리 성공, F_PEN/M_PEN).
#   · 방목 중 + 문 닫힘 → 실외 고립(비살상 — 짐승 유지·penned 미설정 → advance_day가 M_NIGHT_EXPOSED, 엣지①).
#   · 실내 잔류(방목 안 나감/문 닫아 둠) → penned(야간 안전 격리 — 닫힌 건물도 은신처다).
# 반환 {penned, exposed} 카운트(main의 알림·디버그). ⚠️ 비살상: 어떤 경우도 짐승 키를 지우지 않는다.
func settle_night() -> Dictionary:
	var penned_ct := 0
	var exposed_ct := 0
	for tile in _animals.keys():
		var a: Dictionary = _animals[tile]
		if str(a.get("location", LOC_INDOOR)) == LOC_PASTURE:
			if door_open(str(a.get("home_building", ""))):
				a["location"] = LOC_INDOOR
				a["penned"] = true
				penned_ct += 1
			else:
				exposed_ct += 1   # 실외 고립 — penned 미설정 유지(방목 위치도 유지, 익일 문 열면 귀가).
		else:
			a["penned"] = true    # 실내 잔류 = 야간 격리 성공.
			penned_ct += 1
	if penned_ct > 0 or exposed_ct > 0:
		changed.emit()
	return {"penned": penned_ct, "exposed": exposed_ct}

# ── 데일리 케어 액션(낮 동안 플레이어가 세우는 플래그) ─────────────────────────
# 각 액션은 짐승이 있고 그 플래그가 아직 안 섰을 때만 세우고 true(중복 방지 — 하루 1회 실효).
# 급여의 건초 소모·수집물 인벤토리 적재는 호출 측(main)이 맡는다(디커플링 — 이 노드는 재화를 모름).
func feed(tile: Vector2i) -> bool:
	return _set_flag(tile, "fed")

func pet(tile: Vector2i) -> bool:
	return _set_flag(tile, "petted")

func graze(tile: Vector2i) -> bool:
	return _set_flag(tile, "grazed")

func pen(tile: Vector2i) -> bool:
	return _set_flag(tile, "penned")

func clean(tile: Vector2i) -> bool:
	return _set_flag(tile, "cleaned")

# 일괄 돌봄(방목·격리·청결) — 전체 짐승. 하나라도 새로 서면 true. (단위 테스트·전역 리추얼용)
func tend_all() -> bool:
	return _tend_flags(_animals.keys())

# 건물별 일괄 돌봄(방목·격리·청결) — B1-a "진입 실내": 그 건물 안의 짐승만 돌본다(SDV처럼 건물마다
# 따로 돌봄). ⚠️ B1-a.2 이후 main의 실내 돌봄은 clean_all_in(청소만)만 쓴다 — 방목/격리는 pathing이
# 자동으로 세운다(문 방출→grazed·밤 귀가→penned). 이 3플래그 일괄은 단위 테스트·전역 리추얼 잔존 API.
func tend_all_in(building: String) -> bool:
	return _tend_flags(animals_in(building))

# ★ B1-a.2 실내 청소(청결)만 — 건물 안 짐승의 cleaned 플래그만 세운다. 방목(grazed)·격리(penned)는
# pathing이 자동으로 세우므로, 실내 돌봄 리추얼(main RMB)은 잠자리 청소만 담당한다(M_CLEAN vs M_MUCK).
func clean_all_in(building: String) -> bool:
	var any := false
	for tile in animals_in(building):
		var a: Dictionary = _animals[tile]
		if not bool(a["cleaned"]):
			a["cleaned"] = true
			any = true
	if any:
		changed.emit()
	return any

# 주어진 타일들의 방목·격리·청결 플래그를 세운다(공통 구현). 하나라도 새로 서면 changed·true.
func _tend_flags(tiles: Array) -> bool:
	var any := false
	for tile in tiles:
		if not _animals.has(tile):
			continue
		var a: Dictionary = _animals[tile]
		for flag in ["grazed", "penned", "cleaned"]:
			if not bool(a[flag]):
				a[flag] = true
				any = true
	if any:
		changed.emit()
	return any

func _set_flag(tile: Vector2i, flag: String) -> bool:
	if not _animals.has(tile) or bool(_animals[tile][flag]):
		return false
	_animals[tile][flag] = true
	changed.emit()
	return true

# ── 산물 수집(§4.1) ──────────────────────────────────────────────────────────
# 대기 산물을 거둔다. 있으면 {product_id, quality, is_large}를 반환하고 대기를 0으로 비운다.
# 없으면 빈 Dictionary({}). main이 반환을 인벤토리에 적재한다(대형 = "<산물>_large" 아이템, ×2가).
func collect(tile: Vector2i) -> Dictionary:
	if not has_product(tile):
		return {}
	var a: Dictionary = _animals[tile]
	var out := {
		"product_id": AnimalCatalog.product_of(a["species"]),
		"quality": int(a["product_quality"]),
		"is_large": bool(a["product_large"]),
	}
	a["product"] = 0
	a["product_large"] = false
	changed.emit()
	return out

# ── 품질·대형 파생(§3.1 재활용) — 순수 함수. 헤드리스 결정적 검증 ────────────────
# 우정 하트 + 당일 기분 → 품질 확률표 state(§4.1). NONE(0~1하트)·BASIC(2~3)·QUALITY(4)·
# DELUXE(5하트 + 기분≥200). FertilizerCatalog.QUALITY_TABLE 행 키와 1:1(엔진 재활용).
static func quality_state_for(hearts: int, mood: int) -> String:
	if hearts >= 5 and mood >= DELUXE_MOOD_GATE:
		return FertilizerCatalog.STATE_DELUXE
	if hearts >= 4:
		return FertilizerCatalog.STATE_QUALITY
	if hearts >= 2:
		return FertilizerCatalog.STATE_BASIC
	return FertilizerCatalog.STATE_NONE

# 대형 산물 확률 = (하트/5) × 0.5 → 만렙(5하트) 최대 0.5. clamp로 방어(0..0.5).
static func large_chance(hearts: int) -> float:
	return clampf((float(hearts) / 5.0) * 0.5, 0.0, 0.5)

# ── 하루 경과(§4.1 데일리 정산) — 취침 트리거(GameClock.day_advanced) ────────────
# 각 짐승: ①케어 플래그로 우정·기분 델타 정산(clamp) ②급여했으면 산물 생성(품질=하트·기분 state roll,
# 대형=P_large) ③케어 플래그 리셋. ⚠️ 절대 짐승 키를 지우지 않는다(비살상 불변식, §4.1).
func advance_day() -> void:
	if _animals.is_empty():
		return
	for tile in _animals.keys():
		var a: Dictionary = _animals[tile]
		# ① 우정·기분 정산(하루치 델타 → clamp).
		var df := (F_PET if a["petted"] else F_NEGLECT) + (F_FEED if a["fed"] else F_NO_FEED)
		df += F_GRAZE if a["grazed"] else 0
		df += F_PEN if a["penned"] else 0
		var dm := (M_FEED if a["fed"] else M_NO_FEED) + (M_PET if a["petted"] else 0)
		dm += M_PEN if a["penned"] else M_NIGHT_EXPOSED
		dm += M_GRAZE if a["grazed"] else 0
		dm += M_CLEAN if a["cleaned"] else M_MUCK
		a["friendship"] = clampi(int(a["friendship"]) + df, 0, FRIEND_MAX)
		a["mood"] = clampi(int(a["mood"]) + dm, 0, MOOD_MAX)
		# ② 산물 생성 — 급여한 짐승만(스타듀 결), 대기 산물이 없을 때만(수집 전 중복 방지).
		if bool(a["fed"]) and int(a["product"]) <= 0:
			var hearts := int(a["friendship"]) / FRIEND_PER_HEART
			var state := quality_state_for(hearts, int(a["mood"]))
			a["product"] = 1
			a["product_quality"] = FertilizerCatalog.roll_quality(state)
			a["product_large"] = AnimalCatalog.large_capable(a["species"]) and randf() < large_chance(hearts)
		# ③ 데일리 케어 플래그 리셋(새 하루).
		for flag in ["fed", "petted", "grazed", "penned", "cleaned"]:
			a[flag] = false
	changed.emit()

# ── 세이브/로드(§8.9) — FarmField/Orchard 패턴 계승 ───────────────────────────
# _animals는 Vector2i 키 + String/int/bool 값 순수 Dictionary라 var_to_str가 그대로 라운드트립한다.
# 깊은 복사로 넘겨 호출 측이 들고 있어도 상태가 새지 않게 한다.
func to_save() -> Dictionary:
	return {"animals": _animals.duplicate(true), "doors": _doors.duplicate(true)}   # ★ B1-a.2: 방목 문 상태도 보존.

# 복원: _animals·_doors를 통째로 갈아끼운다. changed로 main이 화면·HUD를 다시 세우게 한다(디커플링).
# ★ B1-a: home_building이 없는 구버전 세이브는 ""로 백필한다(building_of/animals_in 방어).
# ★ B1-a.2: location(→실내)·pasture_tile(→키 타일)·doors(→닫힘) 없는 구버전도 안전 default로 백필.
func load_save(data: Dictionary) -> void:
	var animals: Variant = data.get("animals", {})
	_animals = animals.duplicate(true) if typeof(animals) == TYPE_DICTIONARY else {}
	var doors: Variant = data.get("doors", {})
	_doors = doors.duplicate(true) if typeof(doors) == TYPE_DICTIONARY else {}
	for tile in _animals.keys():
		var a: Dictionary = _animals[tile]
		if not a.has("home_building"):
			a["home_building"] = ""
		if not a.has("location"):
			a["location"] = LOC_INDOOR
		if not a.has("pasture_tile"):
			a["pasture_tile"] = tile
	changed.emit()
