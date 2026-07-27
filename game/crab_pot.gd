extends Node
class_name CrabPotLedger
# ★[S3-T7 / ADR-0061 결정 7] 게잡이통 — 설치 좌표·미끼 장전·수거 대기 어획물만 소유하는 얇은 원장(ledger).
#
# 목적: 카탈로그 §1-D 게잡이통 행("패시브 · 혼력 0 · 미끼 + 매일 수거")의 빌드 구체화. 릴 격투가
#       "손으로 잡는 낚시"라면 게잡이통은 **손을 안 쓰는 낚시**다 — 물가에 놓고 미끼를 넣어 두면
#       밤새 뭔가 걸리고, 아침에 들러 비운다. 그 하루 사이클의 상태 전부를 이 파일이 든다.
#
# 왜 별개 노드인가(Sprinkler/Reclaim/Orchard 동형 완전 분리):
#   - 게잡이통 배치는 **플레이어 세이브 델타**다(설계 시드가 아님 — 매대 구매 후 자유 설치).
#     이 원장은 "어디에 통이 있고 · 미끼가 들었고 · 무엇이 걸려 있나"만 알고, 지형·화면·인벤토리·
#     혼력·전문직을 하나도 모른다. 배치 가능 판정(물가 인접·구역 한정)은 main이 하고, 퍼크 값은
#     advance_day 인자로 *주입*된다(디커플링 — Reclaim이 후보 칸을 main에서 받는 것과 같은 결).
#   - 상태 = 구역별 Vector2i 키 Dictionary. **구역 키가 필요한 이유**: 삼도천(56×40)·황천해(64×44)가
#     좌표 공간을 공유해서, 구역을 안 나누면 두 구역의 같은 칸이 한 통으로 뭉개진다(Sprinkler는
#     안식 전용이라 이 축이 없었다 — 첫 다구역 설치물이다).
#
# 설계 메모(어기면 ADR-0061 결정 7 위반):
#   - **혼력 0**: 설치·장전·수거·회수 어디에도 SoulEnergy가 없다. 이 파일이 energy를 모르는 것 자체가
#     그 불변식의 구조적 보증이고, main 쪽 호출부에도 spend가 없다(패시브 = 무과금이 정의).
#   - **미끼 장전된 통만 어획**(스타듀 문법). 예외는 미끼장인(bait_free) 하나 — "장전이 불요"지
#     "미끼 없이도 잘 잡힌다"가 아니라서, 어획 테이블·확률은 동일하다(퍼크 = 편의 차원, ADR-0052).
#   - **결정적**: day + 구역 + 좌표 시드(CrowRaid/Reclaim.advance_day 선례). 같은 날 같은 통은 몇 번을
#     굴려도 같은 결과다 — 헤드리스가 정확히 재현한다(전역 randf 금지).
#   - **안 비운 통은 다음 어획을 안 받는다**(스타듀 1:1). 수거가 곧 재가동 조건이라 "매일 들른다"는
#     리추얼이 생기고, 방치해도 손실이 아니라 정지일 뿐이다(코지 — 벌칙 0).
#   - **신규 아이템은 통용물 3종 + 통 1개뿐**(ADR-0001 큐레이션). 잡동사니는 인양물이 이미 만든
#     「삭은 그물」을 그대로 재사용한다(salvage.gd 주석 "S3-T7 게잡이통 잡동사니 표적으로도 재사용").

signal changed()   # 설치·장전·수거·회수·일일 롤·복원한 프레임(main이 듣고 드로우·프롬프트 갱신)

# 구역별 설치 원장. { region(String) → { Vector2i → {"baited": bool, "catch": String} } }
#   · baited = 미끼가 들어 있나(다음 밤 어획 자격)
#   · catch  = 수거 대기 아이템 id("" = 비어 있음)
var _pots: Dictionary = {}

# ── 어획 테이블(가중 합 1000 — SalvageTable 결) ──────────────────────────────
# 읽는 법: 미끼 든 통 하나가 하룻밤에 무엇을 무는가의 분포. 통용물 3종 75% · 잡동사니 25%.
#   · 잡동사니 25%는 "그물 걷어 보니 그물뿐"이라는 낚시의 정직한 정취다(스타듀 crab pot도 쓰레기가
#     흔하다). 그 25%를 지우는 게 뱃사람(no_junk) 퍼크의 실효다 — 지우면 남은 셋의 상대 가중이
#     그대로 재정규화돼 **통용물로 대체**된다(ADR-0061 결정 7 문구 그대로).
#   · 희소할수록 비싸다(잿빛소라 170/58G ← 혼조개 280/32G). 기대값 ≈ 32G/통·밤(잡동사니 포함),
#     뱃사람이면 ≈ 42G — 소 체급 물고기 한 마리 근방이라 "패시브는 손 낚시보다 얇다"가 유지된다.
# ★ 정적 const 대신 static func인 이유 = SalvageTable.table()과 동일: 항목 id의 단일 출처가
#   ItemCatalog라 const 초기화식에서 타 클래스 상수를 참조하지 않는다(id가 어긋날 여지 0).
static func catch_table(no_junk: bool = false) -> Array:
	var rows: Array = [
		{"id": ItemCatalog.NEOK_GE, "weight": 300},        # 넋게 — 통의 표준 어획(45G)
		{"id": ItemCatalog.HON_JOGAE, "weight": 280},      # 혼조개 — 가장 흔한 조개류(32G)
		{"id": ItemCatalog.JAETBIT_SORA, "weight": 170},   # 잿빛소라 — 가장 귀한 통용물(58G)
	]
	if not no_junk:
		rows.append({"id": ItemCatalog.ROTTEN_NET, "weight": 250})   # 삭은 그물(인양물 재사용 — 5G)
	return rows

# ── 질의 ────────────────────────────────────────────────────────────────────
# 이 구역·이 칸에 게잡이통이 있는가(드로우·설치 겹침·상호작용 판정이 쓴다).
func has_at(region: String, t: Vector2i) -> bool:
	return _pots.has(region) and _pots[region].has(t)

# 이 구역의 설치 칸 목록(드로우·검증). 구역이 없으면 빈 배열.
func tiles(region: String) -> Array:
	return _pots[region].keys() if _pots.has(region) else []

# 전 구역 설치 수(검증·디버그).
func count() -> int:
	var n := 0
	for region in _pots:
		n += int(_pots[region].size())
	return n

# 미끼가 들어 있나(프롬프트·드로우 색 구분).
func is_baited(region: String, t: Vector2i) -> bool:
	return has_at(region, t) and bool(_pots[region][t].get("baited", false))

# 수거 대기 어획물 id("" = 없음). 프롬프트·드로우 표식·수거 분기가 쓴다.
func pending_catch(region: String, t: Vector2i) -> String:
	return String(_pots[region][t].get("catch", "")) if has_at(region, t) else ""

# ── 설치/회수 ────────────────────────────────────────────────────────────────
# 이 칸에 빈 통을 놓는다. 이미 있으면 false(멱등 — 중복 설치 금지). 성공 시 changed.emit().
#   배치 가능 판정(물가 인접·구역 한정·지면 종류)은 main._can_place_crab_pot이 하고, 여긴 원장만 든다.
func place(region: String, t: Vector2i) -> bool:
	if has_at(region, t):
		return false
	if not _pots.has(region):
		_pots[region] = {}
	_pots[region][t] = {"baited": false, "catch": ""}
	changed.emit()
	return true

# 이 칸의 통을 회수한다(아이템 복귀는 호출 측). **수거 대기 어획물이 있으면 거절**한다 —
#   회수로 어획물이 조용히 증발하면 손실이고, main의 F 체인이 "수거 먼저"를 이미 강제한다(이중 안전).
#   없거나 어획 대기면 false(무동작). 성공 시 changed.emit().
func remove(region: String, t: Vector2i) -> bool:
	if not has_at(region, t):
		return false
	if pending_catch(region, t) != "":
		return false                      # 먼저 수거해야 한다(어획물 증발 방지)
	_pots[region].erase(t)
	if _pots[region].is_empty():
		_pots.erase(region)               # 빈 구역 키는 남기지 않는다(세이브 군더더기 0)
	changed.emit()
	return true

# ── 미끼 장전 / 수거 ─────────────────────────────────────────────────────────
# 통에 미끼를 넣는다(아이템 1개 소모는 호출 측). 통이 없거나 이미 장전됐으면 false(멱등 — 미끼 낭비 방지).
func load_bait(region: String, t: Vector2i) -> bool:
	if not has_at(region, t) or is_baited(region, t):
		return false
	_pots[region][t]["baited"] = true
	changed.emit()
	return true

# 수거 대기 어획물을 꺼낸다(인벤 적재는 호출 측). 아이템 id 반환("" = 없음). 꺼내면 통이 다시
#   가동 대기가 된다("안 비운 통은 안 문다"의 짝 — 수거가 곧 재가동).
func collect(region: String, t: Vector2i) -> String:
	var id := pending_catch(region, t)
	if id == "":
		return ""
	_pots[region][t]["catch"] = ""
	changed.emit()
	return id

# ── 하루 경과(일일 롤) — 취침 트리거 ─────────────────────────────────────────
# 미끼 든 통마다 어획을 하나 굴려 수거 대기에 얹는다. 새로 걸린 목록을 반환한다
# ([{region, tile, id}] — main이 알림·토스트에 쓴다). 부수효과 = _pots 갱신.
#   · no_junk   = 뱃사람(lvl10) — 잡동사니 배제(테이블에서 삭은 그물 제거 → 통용물로 재정규화)
#   · bait_free = 미끼장인(lvl10) — 미끼 불요(장전 안 된 통도 어획 · 소모도 없음)
#   · cost_save = 덫꾼(lvl5) — 미끼 소모 절감 **확률**(0..1). 걸리면 이번 밤 미끼가 안 닳는다
#     (0.5 = 절반은 그대로 남는다 = "소모 ½"의 확률 구현 — 퍼크 dim 이름 그대로 '비율').
#   · 결정적: day + 구역 + 좌표 시드(CrowRaid.resolve 동형). 구역·좌표는 정렬해 순회한다
#     (Dictionary 키 순서에 의존하면 결과 목록 순서가 흔들린다 = 결정성의 구멍).
func advance_day(day: int, no_junk: bool = false, bait_free: bool = false,
		cost_save: float = 0.0) -> Array:
	var out: Array = []
	var regions: Array = _pots.keys()
	regions.sort()
	for region in regions:
		var by_tile: Dictionary = _pots[region]
		var tile_list: Array = by_tile.keys()
		tile_list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y if a.y != b.y else a.x < b.x)
		for t: Vector2i in tile_list:
			var e: Dictionary = by_tile[t]
			if String(e.get("catch", "")) != "":
				continue                                  # 안 비운 통 — 다음 어획을 안 받는다
			var baited := bool(e.get("baited", false))
			if not baited and not bait_free:
				continue                                  # 미끼 없음 = 어획 0(스타듀 문법)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("crabpot:%d:%s:%d:%d" % [day, region, t.x, t.y])
			var id := _pick(catch_table(no_junk), rng)
			if id == "":
				continue                                  # 테이블 손상 방어(도달 불가)
			e["catch"] = id
			# 미끼 소모 — 미끼장인은 애초에 안 썼고(bait_free), 덫꾼은 확률로 아낀다(cost_save).
			if baited and not bait_free and rng.randf() >= cost_save:
				e["baited"] = false
			by_tile[t] = e
			out.append({"region": region, "tile": t, "id": id})
	if not out.is_empty():
		changed.emit()
	return out

# 가중 추첨(SalvageTable 결 — 주입 RNG만 쓴다). 빈 테이블이면 "".
static func _pick(rows: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for e in rows:
		total += int(e["weight"])
	if total <= 0:
		return ""
	var roll := rng.randi_range(0, total - 1)
	var acc := 0
	for e in rows:
		acc += int(e["weight"])
		if roll < acc:
			return String(e["id"])
	return String(rows[rows.size() - 1]["id"])   # 잔차 방어(도달 불가)

# ── 세이브/로드(Sprinkler·Reclaim 패턴 계승) — 슬라이스 키 "crab_pot" 네임스페이스 ──
# 구역별 [x, y, baited(0/1), catch_id] 4항 배열 목록으로 직렬화한다(중첩 dict보다 얇고, 항목이
# 늘어도 뒤에 붙이면 되는 형태). 로드는 통째 재구성 후 changed로 main이 드로우를 다시 세운다.
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for region in _pots:
		var arr: Array = []
		for t: Vector2i in _pots[region]:
			var e: Dictionary = _pots[region][t]
			arr.append([t.x, t.y, 1 if bool(e.get("baited", false)) else 0, String(e.get("catch", ""))])
		out[region] = arr
	return {"pots": out}

func load_save(data: Dictionary) -> void:
	_pots = {}
	var raw: Variant = data.get("pots", {})   # 키 없는 구세이브 = 설치 0(하위호환)
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
				var baited: bool = e.size() >= 3 and int(e[2]) != 0
				var got: String = String(e[3]) if e.size() >= 4 else ""
				if got != "" and not ItemCatalog.has_item(got):
					got = ""            # 손상·구버전 id는 조용히 버린다(inventory._sanitize 결)
				by_tile[Vector2i(int(e[0]), int(e[1]))] = {"baited": baited, "catch": got}
			if not by_tile.is_empty():
				_pots[String(region)] = by_tile
	changed.emit()
