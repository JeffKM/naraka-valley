extends Node
class_name Inventory
# T3.1 → Phase 2.7 C1 — 인벤토리(단일 슬롯 배열). 도구·씨앗·수확물을 한 그릇에.
#
# 목적: 경제 순환의 재고(밭에서 거둔 수확물·카페에서 산 씨앗)에 더해, 농사 도구(괭이·물뿌리개)까지
#       하나의 슬롯 배열에 담는다(ADR-0020 데이터 주도 아이템 / ADR-0024 핫바 선택). 슬롯이 곧 핫바라
#       플레이어는 숫자키·휠로 든 것을 고르고, 든 것이 LMB의 동사를 정한다(괭이→갈기·씨앗→심기).
#
# 설계 메모:
#   - 이전 모델(harvested/seeds 2-Dictionary)을 단일 슬롯 배열로 갈아엎었다(C1·C2 병합 — 임시
#     어댑터 비계 없이 한 번에 피벗). 슬롯 = null(빈칸) 또는 {id, count}. 위치 고정 + 수동 정리
#     (자동 압축 X — 스타듀처럼 빈칸이 그 자리에 남는다). 시작 12칸, 확장은 SIZE만 키우면 된다.
#   - 도구=유니크(스택 불가·중복 거절), 씨앗·수확물=스택(같은 id는 한 슬롯에 합친다). 어느 쪽인지는
#     ItemCatalog.stackable_of가 가른다(인벤토리는 카테고리를 모르고 카탈로그에 위임 — 디커플링).
#   - 기존 의미 API(add_seed/has_seed/take_seed/add_harvest/harvest_count/total_harvest/…)는
#     슬롯 위에 *재구현*한다. 씨앗·수확물은 작물군 id로 부르되 내부에선 ItemCatalog.seed_id/
#     harvest_id로 아이템 id에 매핑한다 — 호출 측(main·테스트·bot)은 작물군 id 그대로 쓴다(회귀 0).
#   - selected_index(핫바 선택 슬롯). 든 아이템 id를 selected_id로 노출해 main이 LMB 동사를 고른다.
#   - 카탈로그에 없는 id는 받지 않아(add 검증) 손상·오타가 재고로 새지 않게 한다.
#   - START_KIT: 새 게임의 종잣돈 — 도구 2종(괭이·물뿌리개) + 가장 싸고 빠른 혼령초 씨앗 몇 개.
#     _ready에서 슬롯이 비어 있을 때만(=새 게임) 지급한다. 세이브를 불러오면 load_save가 통째로
#     덮어쓰므로 새 게임에만 적용된다. (씬에 붙지 않는 .new() 사용처는 _ready가 안 돌아 직접 지급.)
#   - 새 세이브 포맷(슬롯 배열). 구버전 2-Dictionary 세이브 마이그레이션은 하지 않는다(ADR-0024 —
#     Phase 2.7 새 포맷). load_save가 슬롯 형태가 아니면 빈 인벤토리로 방어한다.

signal changed()  # 재고·선택이 바뀐 프레임(main이 HUD·핫바 갱신)

const SIZE := 12                  # 시작 슬롯 수(= 핫바 칸). 확장은 이 값만 키운다(슬롯 위치 보존).

# 새 게임 시작 지급물. 도구는 유니크라 1개씩, 씨앗은 작물군 id → 개수.
const START_TOOLS := [ItemCatalog.HOE, ItemCatalog.WATERING_CAN]
const START_SEEDS := {CropCatalog.HONRYEONGCHO: 3}
# S1-5b — 혼의 나무 묘목(최소 배선, greybox-spec §7.8). 정식 판매처(만물상=Slice 2·온실)는 하류라
# 새 게임 종잣돈으로 몇 그루 준다(과수 루프를 HOME에서 바로 체험). 과일 종 id → 개수.
const START_SAPLINGS := {FruitTreeCatalog.HONBAEKDO: 2}
# S1-6 — 비료 종잣돈(greybox-spec §8.10). 정식 상점 노출(만물상=Slice 2)·전 5종 판매는 하류라
# 품질군·성장촉진군 대표 1종씩 소량 지급해 HOME에서 품질/성장촉진 루프를 즉시 체험한다. 비료 id → 개수.
const START_FERTILIZER := {ItemCatalog.FERT_BASIC: 3, ItemCatalog.FERT_SPEED: 3}

# 슬롯 배열. 각 원소 = null(빈칸) 또는 {"id": String, "count": int, "quality": int}. 위치 고정(자동 압축 X).
# ★ S1-6(§8.3): quality 차원 추가(ADR-0020 예약 실현). 스택 키 = (id, quality) — 같은 작물이라도
#   품질이 다르면 별 슬롯(은 감자 ≠ 금 감자, 스타듀 정합). 품질 무차원(도구·씨앗·묘목·비료)은 항상 0.
var slots: Array = []
# 핫바에서 선택된 슬롯 인덱스(0..SIZE-1). 빈 슬롯을 가리켜도 무방(selected_id가 "" 반환).
var selected_index: int = 0

# .new()/씬 인스턴스 모두에서 슬롯이 항상 SIZE칸으로 존재하게 한다(_ready 전 접근 방어).
func _init() -> void:
	slots.resize(SIZE)  # null로 채워진다

func _ready() -> void:
	# 새 게임(슬롯이 전부 빔)이면 시작 키트를 지급한다. main이 세이브를 불러오면 그 뒤
	# load_save가 이 값을 덮어쓰므로, 이어하기에는 영향이 없다.
	if _is_empty():
		_grant_start_kit()
		changed.emit()

func _is_empty() -> bool:
	for s in slots:
		if s != null:
			return false
	return true

# 시작 키트 지급(도구 2종 + 혼령초 씨앗). _ready·테스트 셋업이 공유한다(.new() 사용처 대비 public).
func grant_start_kit() -> void:
	_grant_start_kit()
	changed.emit()

func _grant_start_kit() -> void:
	for tool_id in START_TOOLS:
		add_item(tool_id)
	for crop_id in START_SEEDS:
		add_seed(crop_id, START_SEEDS[crop_id])
	for fruit_id in START_SAPLINGS:   # S1-5b 혼의 나무 묘목
		add_sapling(fruit_id, START_SAPLINGS[fruit_id])
	for fert_id in START_FERTILIZER:  # S1-6 비료 종잣돈(품질·성장촉진 대표 1종씩)
		add_item(fert_id, START_FERTILIZER[fert_id])

# ── 슬롯 핵심(S1-6 — (id, quality) 스택 키) ───────────────────────────────────
# id의 슬롯 인덱스(품질 무관 첫 일치, -1 = 없음). 유니크(도구) 중복 판정·has_item에 쓴다.
func _find_id(id: String) -> int:
	for i in slots.size():
		var s: Variant = slots[i]
		if s != null and s["id"] == id:
			return i
	return -1

# (id, quality) 정확 일치 스택 인덱스(-1 = 없음). add_item이 합칠 스택을 찾는 데 쓴다.
func _find_stack(id: String, quality: int) -> int:
	for i in slots.size():
		var s: Variant = slots[i]
		if s != null and s["id"] == id and int(s.get("quality", 0)) == quality:
			return i
	return -1

# id 슬롯들 중 가장 낮은 품질(있고 count>0)의 인덱스(-1 = 없음). remove_item worst-first가 쓴다.
func _lowest_quality_slot(id: String) -> int:
	var best := -1
	var best_q := 2147483647
	for i in slots.size():
		var s: Variant = slots[i]
		if s != null and s["id"] == id and int(s["count"]) > 0:
			var q := int(s.get("quality", 0))
			if q < best_q:
				best_q = q
				best = i
	return best

# 아이템 id의 품질을 정규화(수확물·과일만 등급 실음 0..3, 그 외 품질 무차원=0). add/_sanitize가 쓴다.
func _norm_quality(id: String, quality: int) -> int:
	if ItemCatalog.category_of(id) == ItemCatalog.CAT_HARVEST:
		return clampi(quality, 0, 3)
	return 0

# 첫 빈 슬롯 인덱스(-1 = 가득 참).
func _first_empty() -> int:
	for i in slots.size():
		if slots[i] == null:
			return i
	return -1

# 아이템 id의 보유 개수(전 품질 합산 — 선물·서빙·판매 가용 판정 불변). 도구는 0/1.
func count_of(id: String) -> int:
	var sum := 0
	for s in slots:
		if s != null and s["id"] == id:
			sum += int(s["count"])
	return sum

# 아이템을 (품질 무관) 하나라도 들고 있는가.
func has_item(id: String) -> bool:
	return _find_id(id) >= 0

# 아이템 n개 추가(quality 지정 — 수확물·과일만 실효, 그 외 0 강제). 스택은 (id,quality) 일치 슬롯에
# 합치거나 새 빈 슬롯에, 유니크(도구)는 중복 거절·1개만. 빈 슬롯이 없으면 거절. 추가했으면 true.
func add_item(id: String, n: int = 1, quality: int = 0) -> bool:
	if n <= 0 or not ItemCatalog.has_item(id):
		return false
	if not ItemCatalog.stackable_of(id):
		# 유니크(도구): 이미 있으면 거절, 없으면 빈 슬롯에 1개(개수·품질 인자 무시).
		if _find_id(id) >= 0:
			return false
		var e := _first_empty()
		if e < 0:
			return false
		slots[e] = {"id": id, "count": 1, "quality": 0}
		changed.emit()
		return true
	# 스택(씨앗·수확물·묘목·비료): (id, quality) 일치 슬롯에 합치거나 새 빈 슬롯에.
	var q := _norm_quality(id, quality)
	var i := _find_stack(id, q)
	if i >= 0:
		slots[i]["count"] += n
		changed.emit()
		return true
	var empty := _first_empty()
	if empty < 0:
		return false
	slots[empty] = {"id": id, "count": n, "quality": q}
	changed.emit()
	return true

# 아이템 n개 제거(전 품질 합산 원자적 — 모자라면 무변경 false). 소비는 ★최저 품질 우선(worst-first):
# 플레이어가 프리미엄은 팔고 잡템을 서빙·선물로 소모하는 스타듀 결. 0이 된 슬롯은 빈칸으로 남는다.
func remove_item(id: String, n: int = 1) -> bool:
	if n <= 0 or count_of(id) < n:
		return false
	var remaining := n
	while remaining > 0:
		var idx := _lowest_quality_slot(id)
		if idx < 0:
			break   # count_of가 보장하므로 도달 X(방어)
		var take := mini(remaining, int(slots[idx]["count"]))
		slots[idx]["count"] -= take
		remaining -= take
		if int(slots[idx]["count"]) <= 0:
			slots[idx] = null
	changed.emit()
	return true

# 특정 슬롯 인덱스에서 n개 제거(품질 무관 — 그 슬롯의 (id,quality)를 그대로 소진). 출하함 드롭처럼
# "이 슬롯을 통째로" 빼낼 때 쓴다(worst-first가 다른 품질 슬롯을 건드리지 않게). 모자라면 false.
func remove_at(index: int, n: int = 1) -> bool:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return false
	if n <= 0 or int(slots[index]["count"]) < n:
		return false
	slots[index]["count"] -= n
	if int(slots[index]["count"]) <= 0:
		slots[index] = null
	changed.emit()
	return true

# ── 핫바 선택 ────────────────────────────────────────────────────────────────
# 현재 선택 슬롯의 아이템 id("" = 빈 슬롯 선택). main이 LMB 동사·HUD를 정하는 입구.
func selected_id() -> String:
	return id_at(selected_index)

# 슬롯 i의 아이템 id("" = 빈칸/범위 밖). 핫바 그리기·선택 질의.
func id_at(i: int) -> String:
	if i < 0 or i >= slots.size() or slots[i] == null:
		return ""
	return slots[i]["id"]

# 슬롯 i의 개수(0 = 빈칸/범위 밖). 핫바 개수 배지 그리기.
func count_at(i: int) -> int:
	if i < 0 or i >= slots.size() or slots[i] == null:
		return 0
	return slots[i]["count"]

# 슬롯 i의 품질 등급(0 = 빈칸/범위 밖/무차원). HUD가 등급 색·글자로 표시(S1-6 §8.3), 출하함이 배수 조회.
func quality_at(i: int) -> int:
	if i < 0 or i >= slots.size() or slots[i] == null:
		return 0
	return int(slots[i].get("quality", 0))

# 슬롯 i를 선택한다(범위 밖이면 무시). 숫자키·휠·초기화가 호출한다.
func select(i: int) -> void:
	if i < 0 or i >= slots.size() or i == selected_index:
		return
	selected_index = i
	changed.emit()

# 핫바 선택을 한 칸 옮긴다(휠). 빈 슬롯도 포함해 단순 순환(스타듀와 동일 — 빈칸도 선택된다).
func select_next() -> void:
	select((selected_index + 1) % slots.size())

func select_prev() -> void:
	select((selected_index - 1 + slots.size()) % slots.size())

# ── 슬롯 재배치(클릭 이동·정리, Phase 2.7 C2 공통 백팩) ────────────────────────
# 슬롯 from을 슬롯 to로 옮긴다(백팩 클릭 이동). 같은 스택 아이템이면 합치고(병합),
# 아니면 자리를 맞바꾼다(스왑). 도구(유니크)는 합치지 않고 스왑만 한다. 범위 밖·같은 칸·
# 빈 from은 무동작. 백팩 UI가 "집어서 다른 칸에 놓기"를 이 한 메서드로 처리한다(드래그/클릭 공통).
func move_slot(from: int, to: int) -> void:
	if from < 0 or from >= slots.size() or to < 0 or to >= slots.size() or from == to:
		return
	if slots[from] == null:
		return
	var src: Variant = slots[from]
	var dst: Variant = slots[to]
	# 빈 칸으로 옮기기 = 그대로 이동.
	if dst == null:
		slots[to] = src
		slots[from] = null
		changed.emit()
		return
	# 같은 스택 아이템 + 같은 품질이면 합친다(도구는 stackable=false·품질 다르면 별 스택 → 스왑).
	if src["id"] == dst["id"] and int(src.get("quality", 0)) == int(dst.get("quality", 0)) \
			and ItemCatalog.stackable_of(src["id"]):
		slots[to]["count"] += src["count"]
		slots[from] = null
		changed.emit()
		return
	# 그 외엔 자리 맞바꿈(스왑).
	slots[to] = src
	slots[from] = dst
	changed.emit()

# 정리(스타듀 'Organize'): 빈칸을 없애 앞으로 당기고, 카테고리(도구→씨앗→수확물)·id 순으로
# 정렬한 뒤 같은 스택 id를 한 슬롯으로 합친다. 슬롯 위치가 바뀌므로 선택 인덱스는 그대로 두되
# (빈칸 선택 가능), 메뉴 인벤토리 탭의 [정리] 버튼이 호출한다. 도구는 유니크라 합쳐지지 않는다.
func sort() -> void:
	# 1) 비지 않은 슬롯을 (id, quality) 스택 키로 합산한다(품질 다르면 별 스택 유지 — 은/금 분리).
	var merged: Dictionary = {}   # "id#q" → {id, quality, count}
	var order: Array = []         # 처음 등장 순서 보존(안정적 — 같은 키 정렬 전 베이스)
	for s in slots:
		if s == null:
			continue
		var id: String = s["id"]
		var q := int(s.get("quality", 0))
		var key := "%s#%d" % [id, q]
		if merged.has(key):
			merged[key]["count"] += int(s["count"])
		else:
			merged[key] = {"id": id, "quality": q, "count": int(s["count"])}
			order.append(key)
	# 2) 카테고리(도구→씨앗→묘목→수확물→비료→그 외) 우선, 그다음 id, 그다음 품질(낮은 등급 먼저).
	order.sort_custom(func(a: String, b: String) -> bool:
		var ea: Dictionary = merged[a]
		var eb: Dictionary = merged[b]
		var ca := _cat_rank(ea["id"])
		var cb := _cat_rank(eb["id"])
		if ca != cb:
			return ca < cb
		if ea["id"] != eb["id"]:
			return ea["id"] < eb["id"]
		return int(ea["quality"]) < int(eb["quality"]))
	# 3) 슬롯을 비우고 앞에서부터 다시 채운다(빈칸 제거 = 앞으로 당김).
	var fresh: Array = []
	fresh.resize(SIZE)
	var i := 0
	for key in order:
		if i >= SIZE:
			break  # 칸을 넘는 분(이론상 정리로 늘지 않음)은 합쳐졌으므로 발생 X
		var e: Dictionary = merged[key]
		fresh[i] = {"id": e["id"], "count": e["count"], "quality": e["quality"]}
		i += 1
	slots = fresh
	changed.emit()

# 카테고리 정렬 순위(도구 0 → 씨앗 1 → 묘목 2 → 수확물 3 → 비료 4 → 그 외 5). sort 비교자가 쓴다.
func _cat_rank(id: String) -> int:
	match ItemCatalog.category_of(id):
		ItemCatalog.CAT_TOOL: return 0
		ItemCatalog.CAT_SEED: return 1
		ItemCatalog.CAT_SAPLING: return 2
		ItemCatalog.CAT_HARVEST: return 3
		ItemCatalog.CAT_FERTILIZER: return 4
		_: return 5

# ── 씨앗(작물군 id 기반 — 내부적으로 "<작물군>_seed" 아이템에 매핑) ──────────────
func add_seed(crop_id: String, n: int = 1) -> void:
	if not CropCatalog.has_crop(crop_id):
		return
	add_item(ItemCatalog.seed_id(crop_id), n)

func seed_count(crop_id: String) -> int:
	return count_of(ItemCatalog.seed_id(crop_id))

func has_seed(crop_id: String) -> bool:
	return seed_count(crop_id) > 0

# 씨앗 1개를 꺼내 쓴다(심기). 없으면 false. 0이 되면 슬롯이 빈칸으로 남는다.
func take_seed(crop_id: String) -> bool:
	return remove_item(ItemCatalog.seed_id(crop_id), 1)

# ── 묘목(과일 종 id 기반 — 내부적으로 "<과일종>_sapling" 아이템에 매핑, S1-5b) ──────
func add_sapling(fruit_id: String, n: int = 1) -> void:
	if not FruitTreeCatalog.has(fruit_id):
		return
	add_item(ItemCatalog.sapling_id(fruit_id), n)

func sapling_count(fruit_id: String) -> int:
	return count_of(ItemCatalog.sapling_id(fruit_id))

func has_sapling(fruit_id: String) -> bool:
	return sapling_count(fruit_id) > 0

# 묘목 1개를 꺼내 쓴다(나무 심기). 없으면 false.
func take_sapling(fruit_id: String) -> bool:
	return remove_item(ItemCatalog.sapling_id(fruit_id), 1)

# ── 수확물(작물군 id = 수확물 아이템 id) ──────────────────────────────────────
# ★ S1-6(§8.3): quality 인자로 등급을 실는다(기본 Q0라 무인자 기존 호출 회귀 0). 밭 수확 품질 roll이
#   주 수확분에만 등급을 붙이고 다수확 추가분은 Q0로 넘긴다(§8.5 다수확 격리 — main이 조율).
func add_harvest(crop_id: String, n: int = 1, quality: int = 0) -> void:
	if not CropCatalog.has_crop(crop_id):
		return
	add_item(ItemCatalog.harvest_id(crop_id), n, quality)

func harvest_count(crop_id: String) -> int:
	return count_of(ItemCatalog.harvest_id(crop_id))

# 거둔 수확물 n개를 꺼내 쓴다(선물·서빙·약탈). 모자라면 false.
func take_harvest(crop_id: String, n: int = 1) -> bool:
	return remove_item(ItemCatalog.harvest_id(crop_id), n)

# 보유한 모든 수확물 개수의 합(판매·서빙 가능 판단·HUD용). 카테고리로 슬롯을 가른다.
func total_harvest() -> int:
	var sum := 0
	for s in slots:
		if s != null and ItemCatalog.category_of(s["id"]) == ItemCatalog.CAT_HARVEST:
			sum += s["count"]
	return sum

# 보유한 수확물 작물군 id 목록(수확물 카테고리 슬롯의 id = 작물 id). 판매·약탈·서빙이 순회한다.
# ★ S1-6: 같은 작물이 품질별로 여러 슬롯에 나뉠 수 있어 id를 중복 제거한다(작물 "종류" 목록 —
#   count_of가 전 품질을 합산하므로 종류당 1회만 순회해야 이중 처리가 없다).
func harvest_ids() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for s in slots:
		if s != null and ItemCatalog.category_of(s["id"]) == ItemCatalog.CAT_HARVEST and not seen.has(s["id"]):
			seen[s["id"]] = true
			out.append(s["id"])
	return out

# 수확물 슬롯을 통째로 비운다(전량 판매 후). 변화가 있을 때만 알린다(도구·씨앗은 보존).
func clear_harvest() -> void:
	var any := false
	for i in slots.size():
		var s: Variant = slots[i]
		if s != null and ItemCatalog.category_of(s["id"]) == ItemCatalog.CAT_HARVEST:
			slots[i] = null
			any = true
	if any:
		changed.emit()

# ── T2.5 세이브/로드(슬롯 배열 직렬화 — 새 포맷, 마이그레이션 X) ──────────────────
# 슬롯 배열을 그대로 직렬화한다. 각 슬롯은 null 또는 {id:String, count:int}의 순수 자료라
# var_to_str가 라운드트립한다. 깊은 복사로 넘겨, 호출 측이 들고 있어도 재고가 새지 않게 한다.
func to_save() -> Dictionary:
	return {
		"slots": slots.duplicate(true),
		"selected_index": selected_index,
	}

# 복원: 슬롯 배열을 정제해 갈아끼운다. 손상된 세이브(배열 아님·이상 슬롯)는 빈칸으로 방어하고,
# 카탈로그에 없는 id·음수 개수는 걸러 안전하게 만든다. 항상 SIZE칸으로 정규화한다.
func load_save(data: Dictionary) -> void:
	slots = _sanitize(data.get("slots", []))
	selected_index = clampi(int(data.get("selected_index", 0)), 0, slots.size() - 1)
	changed.emit()

# 슬롯 배열 정제: 길이를 SIZE로 맞추고, 각 슬롯은 유효 아이템 + 양수 개수만 남긴다(손상·버전 방어).
# 유니크(도구)는 개수를 1로 자르고, 같은 id가 두 번 나오면 둘째부터 버린다(중복 슬롯 방지).
func _sanitize(raw: Variant) -> Array:
	var clean: Array = []
	clean.resize(SIZE)
	if typeof(raw) != TYPE_ARRAY:
		return clean
	var seen_unique := {}
	for i in mini(raw.size(), SIZE):
		var s: Variant = raw[i]
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var id: String = str(s.get("id", ""))
		var n := int(s.get("count", 0))
		if not ItemCatalog.has_item(id) or n <= 0:
			continue
		# ★ S1-6: 구세이브(quality 무) → 0 기본, 수확물만 등급 실음·그 외 무차원 0(스키마 정규화).
		var q := _norm_quality(id, int(s.get("quality", 0)))
		if not ItemCatalog.stackable_of(id):
			if seen_unique.has(id):
				continue  # 유니크 중복 슬롯 버림
			seen_unique[id] = true
			n = 1
			q = 0
		clean[i] = {"id": id, "count": n, "quality": q}
	return clean
