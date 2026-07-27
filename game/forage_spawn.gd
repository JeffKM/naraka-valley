extends RefCounted
class_name ForageSpawns
# ★[S4-T1 / ADR-0062 결정 1·2] 채집물 스폰 원장 — "지금 숲 어느 칸에 무엇이 돋아 있나"만 소유하는
# 얇은 원장(ledger).
#
# 목적: ADR-0062 결정 2("채집물 로스터 22종 + 스타듀 스폰 문법 상속")의 빌드 형태. 저승 숲·미혹의
#       숲 빈터(클리어링)에 매일 소량의 채집물이 돋고, 7일마다 판이 갈리며, 절기가 바뀌면 전량
#       사라지고 그 절기의 종으로 다시 채워진다. 그 하루 사이클 상태 전부를 이 파일이 든다.
#
# 왜 별개 원장인가(CrabPotLedger/FlowerPatch/Reclaim 동형 완전 분리):
#   - 배치는 **설계 시드가 아니라 매일 굴러 나오는 델타**다(꽃 패치처럼 layout.json에 박히지 않는다).
#     이 원장은 "어느 구역·어느 칸에 어떤 종이 있나"만 알고, 지형·화면·인벤토리·혼력·전문직·품질을
#     하나도 모른다. 줍기의 품질·수량·XP는 main이 채집 레벨/전문직으로 정해 *주입*한다(디커플링 —
#     FlowerPatch가 등급을 안 정하는 것과 같은 결).
#   - 상태 = 구역별 Vector2i 키 Dictionary(CrabPotLedger의 다구역 원장 템플릿 1:1 복제). 저승 숲
#     (60×44)·미혹의 숲(64×44)이 좌표 공간을 공유해서, 구역을 안 나누면 두 구역의 같은 칸이 한
#     채집물로 뭉개진다.
#   - **RefCounted(비-Node)**: 게잡이통과 달리 이 원장은 "설치물"이 아니라 순수 데이터라 씬 트리에
#     설 이유가 없다. main이 참조로 들고 질의한다(ADR-0062 "순수 원장").
#
# 설계 메모(어기면 ADR-0062 결정 2 위반):
#   - **결정 롤**: day + 구역 + 좌표 시드(CrabPotLedger.advance_day·CrowRaid.resolve 선례). 전역
#     randf 금지 — 같은 날 같은 칸은 몇 번을 굴려도 같은 결과라 헤드리스가 정확히 재현한다.
#   - **구역당 상한 6**(스타듀 상속) · **7일 주기 리셋**(미수집분 삭제 후 재시드) · **절기 전환일
#     전량 삭제**(그 절기 종으로 갈아탐). 셋 다 스타듀 위키 채집 스폰 규칙 그대로다.
#   - **빈터 존 안에서만** 돋는다. 존 rect는 기존 채집지 라벨 좌표(ADR-0062 결정 1 ㉠ "라벨 → 빈터
#     승격")를 앵커로 감싼 사각이고, 전부 GROUND 빈터라 나무·연못·건물에 안 묻힌다(forage_spawn_test
#     ⑩·⑪이 실그리드로 단언). 심층 존은 심층 2종 전용, 미혹 빈터는 희소종 전용이다.
#   - **성야절(겨울) 정지 없음** — 절기마다 전용 종이 있다(ADR-0008 "평평≠막힘"의 절기판).
#   - **황천해 해변 존은 여기 없다** — 아이템(해변 4종)만 등록돼 있고 존 배선은 S4-T8 소관이다
#     (무대 재사용 = 백사장. 지금 배선하면 T8이 두 번 손댄다).

# ── 존 종류 ─────────────────────────────────────────────────────────────────
const KIND_COMMON := "common"   # 저승 숲 빈터 — 일반종 12(절기당 3)
const KIND_RARE := "rare"       # 미혹의 숲 빈터 — 희소종 4(절기당 1)
const KIND_DEEP := "deep"       # 미혹 심층(큰 통나무 봉쇄 예정 — 봉쇄 프롭은 S4-T4) — 심층 2(절기 무관)
const KIND_BEACH := "beach"     # 황천해 백사장 — 해변 4(절기 무관). ★존 배선은 S4-T8

# ── 스폰 규칙 상수(스타듀 상속 — ADR-0062 결정 2) ────────────────────────────
const REGION_CAP := 6        # 구역당 동시 존재 상한(스타듀 forage cap 1:1)
const RESET_DAYS := 7        # 주기 리셋 간격(일) — 미수집분을 버리고 판을 새로 깐다
const SPAWN_CHANCE := 0.015  # 후보 칸 1개가 하루에 돋을 확률. 존 3곳×35칸 ≈ 105후보라 기대 ~1.6개/일
                             #   → 7일이면 상한 6에 자연히 근접한다(매일 소량 = 스타듀 결).

signal changed()   # 스폰·줍기·리셋·복원한 프레임(main이 듣고 드로우·프롬프트 갱신)

# 채집물 원장. { region(String) → { Vector2i → species_id(String) } }
var _tiles: Dictionary = {}

# ── 빈터 존 정의(ADR-0062 결정 1 ㉠ — 채집지 라벨 좌표 앵커 보존) ──────────────
# ★ 정적 const 대신 static func인 이유 = CrabPotLedger.catch_table()과 동일: 구역 id의 단일 출처가
#   RegionCatalog라 const 초기화식에서 타 클래스 상수를 참조하지 않는다(로드 순서 의존 0).
# ★ rect는 전부 7×5(앵커를 중심에 두고 ±3/±2). 기존 라벨 좌표는 **한 칸도 안 움직인다**
#   (jeoseung_forest_test·mihok_forest_test의 좌표 단언 불변 — ADR-0062 "앵커 전량 보존").
static func zones() -> Dictionary:
	return {
		RegionCatalog.JEOSEUNG_FOREST: [
			{"rect": Rect2i(17, 6, 7, 5), "kind": KIND_COMMON},    # 빈터①(20,8 북)
			{"rect": Rect2i(42, 8, 7, 5), "kind": KIND_COMMON},    # 빈터②(45,10 북동)
			{"rect": Rect2i(39, 32, 7, 5), "kind": KIND_COMMON},   # 빈터③(42,34 남)
		],
		RegionCatalog.MIHOK_FOREST: [
			{"rect": Rect2i(47, 4, 7, 5), "kind": KIND_RARE},      # 특수 채집지①(50,6 북동 깊은 빈터)
			{"rect": Rect2i(27, 34, 7, 5), "kind": KIND_RARE},     # 특수 채집지②(30,36 남 깊은 빈터)
			# 심층 구획(ADR-0062 결정 1 ㉡) — 동북부. 큰 통나무·큰 그루터기 물리 봉쇄와 도끼 티어
			# 게이트는 S4-T4/T5 소관이고, 여기선 **존만** 정의한다(종 배타 = 심층 2종).
			{"rect": Rect2i(53, 10, 6, 6), "kind": KIND_DEEP},     # 미혹 심층(동북부 — 옥자 집 앞마당과 별개 구획)
		],
	}

# ── 로스터 22종 매핑(종명·가격의 단일 출처 = ItemCatalog.FORAGEABLES) ──────────
# 여기가 드는 건 **"언제·어디서 돋나"**(절기·존)뿐이다. 이름·판매가는 ItemCatalog가 든다
# (FishCatalog·GearCatalog 위임 관례 동형 — 데이터 중복 0).
# 절기 인덱스 = GameClock.season_index_for_day (0 피안 / 1 유화 / 2 망연 / 3 성야).
static func species_for(kind: String, season: int) -> Array:
	var s := clampi(season, 0, 3)
	match kind:
		KIND_COMMON:
			return [
				[ItemCatalog.NEOK_GOSARI, ItemCatalog.JAETBIT_NAENGI, ItemCatalog.JEOSEUNG_DALLAE],       # 피안절
				[ItemCatalog.JEOSEUNG_SANDALGI, ItemCatalog.HONIP_BAKHA, ItemCatalog.JAETBIT_DEODEOK],    # 유화절
				[ItemCatalog.JAETBIT_DOTORI, ItemCatalog.ANGAE_DORAJI, ItemCatalog.NEOK_SONGI],           # 망연절
				[ItemCatalog.EONHON_PPURI, ItemCatalog.SEORI_DONGBAEK, ItemCatalog.SEONGYA_SOLBANGUL],    # 성야절
			][s]
		KIND_RARE:
			return [
				[ItemCatalog.MIHOK_NANCHO],        # 피안절
				[ItemCatalog.YURYEONGCHO],         # 유화절
				[ItemCatalog.MYEONGWOL_BEOSEOT],   # 망연절
				[ItemCatalog.SEORI_HONBAEKCHO],    # 성야절
			][s]
		KIND_DEEP:
			# ★ 불사과 = CropCatalog 기존 종 재사용(CONTEXT 기정의 "미혹의 숲 심층 채집" 실존화 —
			#   신규 아이템 등록 없음. 수확물 아이템 id = 작물 id라 그대로 인벤에 들어간다).
			return [CropCatalog.BULSAGWA, ItemCatalog.JEOSEUNG_SAM]        # 절기 무관(심층은 사철)
		KIND_BEACH:
			return [ItemCatalog.HWANGCHEON_SANHO, ItemCatalog.NEOK_SEONGGAE,
				ItemCatalog.YURI_GODUNG, ItemCatalog.MULBINEUL_JOGAE]      # 절기 무관(조개·산호)
	return []

# 전 로스터 id 목록(검증·도감·테스트용 — 22종). 절기·존을 가로질러 한 벌로 편다.
static func all_species() -> Array:
	var out: Array = []
	for kind in [KIND_COMMON, KIND_RARE]:
		for s in 4:
			for id in species_for(kind, s):
				out.append(id)
	out.append_array(species_for(KIND_DEEP, 0))
	out.append_array(species_for(KIND_BEACH, 0))
	return out

# ── 존 질의 ─────────────────────────────────────────────────────────────────
# 이 구역·이 칸이 속한 빈터 존의 종류("" = 존 밖). 스폰 필터·프롬프트·테스트가 쓴다.
static func zone_kind_at(region: String, t: Vector2i) -> String:
	for z in zones().get(region, []):
		if Rect2i(z["rect"]).has_point(t):
			return String(z["kind"])
	return ""

# 이 구역의 스폰 후보 칸 전체(존 rect 안, 좌→우·위→아래 정렬). 결정적 순회의 축이자
# 테스트의 "존 밖 스폰 0" 판정 기준이다.
static func candidates(region: String) -> Array:
	var out: Array = []
	for z in zones().get(region, []):
		var r: Rect2i = z["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				out.append(Vector2i(x, y))
	return out

# 채집물이 돋는 구역 목록(정렬 — 결정적 순회).
static func spawn_regions() -> Array:
	var out: Array = zones().keys()
	out.sort()
	return out

# ── 원장 질의 ───────────────────────────────────────────────────────────────
func has_at(region: String, t: Vector2i) -> bool:
	return _tiles.has(region) and _tiles[region].has(t)

# 이 칸의 채집물 id("" = 없음). 프롬프트·드로우·줍기 분기가 쓴다.
func species_at(region: String, t: Vector2i) -> String:
	return String(_tiles[region][t]) if has_at(region, t) else ""

# 이 구역의 채집물 칸 목록(드로우·검증). 구역이 없으면 빈 배열.
func tiles(region: String) -> Array:
	return _tiles[region].keys() if _tiles.has(region) else []

func count(region: String) -> int:
	return int(_tiles[region].size()) if _tiles.has(region) else 0

# 전 구역 채집물 수(검증·디버그).
func total() -> int:
	var n := 0
	for region in _tiles:
		n += int(_tiles[region].size())
	return n

# ── 줍기 ────────────────────────────────────────────────────────────────────
# 이 칸의 채집물을 집어 든다(원장에서 제거하고 종 id 반환, "" = 없음). 품질·수량·XP·인벤 적재는
# 전부 호출 측(main._pick_forage)이 채집 레벨/전문직으로 정한다 — 이 원장은 그걸 모른다.
# ★ 혼력 0(ADR-0033 #1): 이 파일이 SoulEnergy를 모르는 것 자체가 그 불변식의 구조적 보증이다.
func pick(region: String, t: Vector2i) -> String:
	var id := species_at(region, t)
	if id == "":
		return ""
	_tiles[region].erase(t)
	if _tiles[region].is_empty():
		_tiles.erase(region)      # 빈 구역 키는 남기지 않는다(세이브 군더더기 0 — CrabPotLedger 결)
	changed.emit()
	return id

# ── 하루 경과(일일 스폰 롤) — 취침 트리거 ────────────────────────────────────
# 새 날의 채집물 판을 세운다. 반환 = {"spawned": [{region,tile,id}], "cleared": int,
#   "reset": bool, "season_reset": bool} — main이 알림·검증에 쓴다.
#   ① **절기 전환일**((day-1)%28==0)이면 전량 삭제(그 절기 종으로 갈아타야 하므로).
#   ② **7일 주기일**((day-1)%7==0)이면 미수집분 삭제 후 재시드(스타듀 forage 주기 1:1).
#      ★ 절기 전환일은 7일 주기일이기도 하다(28 = 7×4) — 두 규칙이 충돌하지 않고 겹칠 뿐이다.
#   ③ 그 뒤 후보 칸을 결정 롤로 훑어 상한(6)까지 소량 스폰한다.
#   · 결정적: day + 구역 + 좌표 시드. 구역·후보는 정렬 순회라 Dictionary 키 순서에 안 기댄다.
func advance_day(day: int, season: int) -> Dictionary:
	var out := {"spawned": [], "cleared": 0, "reset": false, "season_reset": false}
	var season_reset := (day - 1) % GameClock.DAYS_PER_SEASON == 0
	var cycle_reset := (day - 1) % RESET_DAYS == 0
	if season_reset or cycle_reset:
		out["cleared"] = total()
		out["reset"] = cycle_reset
		out["season_reset"] = season_reset
		_tiles = {}
	for region: String in spawn_regions():
		var n := count(region)
		for t: Vector2i in candidates(region):
			if n >= REGION_CAP:
				break
			if has_at(region, t):
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("forage:%d:%s:%d:%d" % [day, region, t.x, t.y])
			if rng.randf() >= SPAWN_CHANCE:
				continue
			var pool: Array = species_for(zone_kind_at(region, t), season)
			if pool.is_empty():
				continue                       # 종 없는 존 방어(도달 불가 — 전 절기에 종이 있다)
			var id := String(pool[rng.randi_range(0, pool.size() - 1)])
			if not _tiles.has(region):
				_tiles[region] = {}
			_tiles[region][t] = id
			n += 1
			out["spawned"].append({"region": region, "tile": t, "id": id})
	if out["cleared"] > 0 or not out["spawned"].is_empty():
		changed.emit()
	return out

# ── 세이브/로드(CrabPotLedger 패턴 계승) — 슬라이스 키 "forage_spawn" 네임스페이스 ──
# 구역별 [x, y, species_id] 3항 배열 목록. 로드는 통째 재구성 후 changed(드로우 갱신).
# ★ 하위호환: 키 없는 구세이브 = 채집물 0(첫 취침의 advance_day가 판을 깐다 — 무막힘).
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for region in _tiles:
		var arr: Array = []
		for t: Vector2i in _tiles[region]:
			arr.append([t.x, t.y, String(_tiles[region][t])])
		out[region] = arr
	return {"tiles": out}

func load_save(data: Dictionary) -> void:
	_tiles = {}
	var raw: Variant = data.get("tiles", {})
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
				var id := String(e[2])
				if not ItemCatalog.has_item(id):
					continue      # 손상·구버전 종 id는 조용히 버린다(inventory._sanitize 결)
				by_tile[Vector2i(int(e[0]), int(e[1]))] = id
			if not by_tile.is_empty():
				_tiles[String(region)] = by_tile
	changed.emit()
